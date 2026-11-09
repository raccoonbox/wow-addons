-- Dress Code [Raccoonbox] for WoW Forever - the item catalog. Everything comes from the game client:
--  * every equippable item the client knows (instant item lookups, scanned once per game patch)
--  * stats, required level, class limits, reputation/PvP requirements (item info + tooltip data)
--  * where items come from: Encounter Journal bosses, appearance sources, vendors you visited,
--    recipes, and quests learned in game (Core.lua)
local ADDON, DC = ...
DressCode = DC

local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetStats = (C_Item and C_Item.GetItemStats) or GetItemStats
local RequestLoad = (C_Item and C_Item.RequestLoadItemDataByID) or function() end

DC.BUILD = tostring((select(2, GetBuildInfo())))

function DC.Print(msg) print("|cffff9900Dress Code:|r " .. msg) end

function DC.ItemID(link)
	if type(link) == "number" then return link end
	return link and tonumber(link:match("item:(%d+)"))
end

-- equip slot -> inventory slots
DC.EQUIP_SLOTS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 }, INVTYPE_CHEST = { 5 },
	INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
	INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
	INVTYPE_WEAPON = { 16 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_SHIELD = { 17 },
	INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
	INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 }, INVTYPE_TABARD = { 19 },
}
DC.SLOT_NAMES = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest", [6] = "Waist", [7] = "Legs",
	[8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket",
	[15] = "Back", [16] = "Main hand", [17] = "Off hand", [18] = "Ranged", [19] = "Tabard" }

function DC.EquipLoc(id)
	local _, _, _, loc = GetInstant(id)
	return loc
end

---------------------------------------------------------------------------- 1. the catalog scan
-- walks item IDs with instant lookups (client data, no server queries) a few milliseconds per frame
local SCAN_MAX, SCAN_EXTEND, SCAN_BUDGET = 300000, 50000, 6

local scanner = CreateFrame("Frame")
scanner:Hide()

local function scan_step()
	local cat = DC.catalog
	local stop = debugprofilestop() + SCAN_BUDGET
	local id = cat.pos
	while id <= cat.max and debugprofilestop() < stop do
		local itemID, _, _, loc, _, classID = GetInstant(id)
		if itemID then
			cat.last = id
			if (classID == 2 or classID == 4) and DC.EQUIP_SLOTS[loc] then cat.ids[#cat.ids + 1] = id end
		end
		id = id + 1
	end
	cat.pos = id
	if id > cat.max then
		if (cat.last or 0) > cat.max - SCAN_EXTEND / 2 then
			cat.max = cat.max + SCAN_EXTEND -- items near the end: there may be more
		else
			cat.done, cat.pos = true, nil
			scanner:Hide()
			DC.Print(#cat.ids .. " wearable items found. Reading their stats in the background...")
			DC.QueueAll()
			if DC.OnCatalog then DC.OnCatalog() end
		end
	end
	if DC.OnProgress then DC.OnProgress() end
end
scanner:SetScript("OnUpdate", function() local ok, err = pcall(scan_step) if not ok then scanner:Hide() DC.Print("scan stopped: " .. tostring(err)) end end)

-- force = scan again even when this patch was scanned before
function DC.ScanCatalog(force)
	local cat = DressCodeDB.catalog
	if not force and cat and cat.build == DC.BUILD and cat.done then
		DC.catalog = cat
		DC.QueueAll()
		return
	end
	if force or not (cat and cat.build == DC.BUILD) then
		cat = { build = DC.BUILD, ids = {}, pos = 1, max = SCAN_MAX }
		DressCodeDB.catalog = cat
		DressCodeDB.items = { build = DC.BUILD } -- item data can change with a patch
	end
	DC.catalog = cat
	cat.pos = cat.pos or 1
	scanner:Show()
end

function DC.ScanProgress()
	local cat = DC.catalog
	if not cat then return 0, 0 end
	if cat.done then return 1, #cat.ids end
	return (cat.pos or 1) / cat.max, #cat.ids
end

---------------------------------------------------------------------------- 2. item records

-- tooltip patterns made from the game's own strings (works in every client language)
local function pattern(fmt)
	if not fmt then return nil end
	fmt = fmt:gsub("%%%d?%$?d", "\1"):gsub("%%%d?%$?s", "\2")
	fmt = fmt:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%0")
	return "^" .. fmt:gsub("\1", "(%%d+)"):gsub("\2", "(.+)") .. "$"
end
local P_LEVEL = pattern(ITEM_MIN_LEVEL or "Requires Level %d")
local P_CLASSES = pattern(ITEM_CLASSES_ALLOWED or "Classes: %s")
local P_REP = pattern(ITEM_REQ_REPUTATION or "Requires %s - %s")
local P_SKILL = pattern(ITEM_MIN_SKILL or "Requires %s (%d)")
local P_REQ = pattern(ITEM_REQ_SKILL or "Requires %s")

local PVP_RANKS = {}
for i = 1, 19 do
	for f = 0, 1 do
		local name = _G[("PVP_RANK_%d_%d"):format(i, f)]
		if name and name ~= "" then PVP_RANKS[name] = i end
	end
end

-- stat keys of GetItemStats -> Dress Code stats (first match wins: specific names first)
local STAT_KEYS = {
	{ "SPELL_HEALING", "heal" }, { "SPELL_DAMAGE", "spelldmg" }, { "SPELL_POWER", "spelldmg" },
	{ "SPELL_CRIT", "spellcrit" }, { "SPELL_HIT", "spellhit" }, { "RANGED_ATTACK_POWER", "ap" },
	{ "ATTACK_POWER", "ap" }, { "CRIT", "crit" }, { "HIT", "hit" }, { "STRENGTH", "str" }, { "AGILITY", "agi" },
	{ "STAMINA", "sta" }, { "INTELLECT", "int" }, { "SPIRIT", "spi" }, { "RESISTANCE0", "armor" },
	{ "MANA_REGENERATION", "mp5" }, { "POWER_REGEN0", "mp5" }, { "DEFENSE", "defense" }, { "DODGE", "dodge" },
	{ "DAMAGE_PER_SECOND", "dps" }, { "ITEM_MOD_HEALTH_SHORT", "health" },
}
local function stat_key(name)
	if name:find("REGEN") and not name:find("MANA") and not name:find("POWER_REGEN0") then return nil end
	for _, p in ipairs(STAT_KEYS) do
		if name:find(p[1], 1, true) then return p[2] end
	end
end

-- "Equip:" effects the stats call may not list (ported from the OctoWoW version)
local EFFECTS = {
	{ "increases damage and healing done by magical spells and effects by up to (%d+)", "spelldmg", "heal" },
	{ "increases healing done by spells and effects by up to (%d+)", "heal" },
	{ "restores (%d+) mana per 5 sec", "mp5" },
	{ "critical strike with spells by (%d+)", "spellcrit" },
	{ "chance to hit with spells by (%d+)", "spellhit" },
	{ "critical strike by (%d+)", "crit" },
	{ "chance to hit by (%d+)", "hit" },
	{ "%+(%d+) ranged attack power", "ap" },
	{ "%+(%d+) attack power", "ap" },
	{ "increased defense %+(%d+)", "defense" },
	{ "chance to dodge an attack by (%d+)", "dodge" },
}

local function surface(data)
	if data and TooltipUtil and TooltipUtil.SurfaceArgs then
		pcall(TooltipUtil.SurfaceArgs, data)
		for _, l in ipairs(data.lines or {}) do pcall(TooltipUtil.SurfaceArgs, l) end
	end
	return data
end

local function is_red(c)
	if not c then return false end
	local r, g, b = c.r, c.g, c.b
	if not r and c.GetRGB then r, g, b = c:GetRGB() end
	return r and r > 0.9 and g < 0.35 and b < 0.35
end

-- proficiency per character: can you use this armour / weapon type? (nil = not known yet)
local function prof_key(c, s) return c .. ":" .. s end
function DC.Proficient(c, s)
	return DressCodeChar.prof and DressCodeChar.prof[prof_key(c, s)]
end

-- read an item's tooltip: requirement texts, effects, and (for you) whether you can use its type
local function read_tooltip(id, subType, c, s, loc, v)
	local data = C_TooltipInfo and surface(C_TooltipInfo.GetItemByID(id))
	if not data or not data.lines then return {} end
	local out = {}
	for i = 2, #data.lines do
		local line = data.lines[i]
		local L, R = line.leftText or "", line.rightText or ""
		local n = L:match(P_LEVEL)
		if n then out.rl = tonumber(n)
		elseif L:match(P_CLASSES) then out.cl = L:match(P_CLASSES)
		elseif P_REP and L:match(P_REP) then
			local fac, standing = L:match(P_REP)
			out.rep = fac .. " - " .. standing
		elseif P_REQ and not (P_SKILL and L:match(P_SKILL)) and L:match(P_REQ) then
			local what = L:match(P_REQ)
			if PVP_RANKS[what] then out.pvp = what end
		end
		-- the armour/weapon type line ("Chest   Plate"): red = you can't use this type
		if subType and R == subType and loc ~= "INVTYPE_CLOAK" then
			DressCodeChar.prof = DressCodeChar.prof or {}
			DressCodeChar.prof[prof_key(c, s)] = not is_red(line.rightColor)
		end
		-- effects not listed by the stats call
		if v then
			local low = L:lower()
			if low:find("^equip:") then
				for _, p in ipairs(EFFECTS) do
					local val = low:match(p[1])
					if val then
						for k = 2, #p do
							if not v[p[k]] then out.eff = out.eff or {} out.eff[p[k]] = (out.eff[p[k]] or 0) + tonumber(val) end
						end
						break
					end
				end
			end
			if not v.dps then
				local dps = low:match("%(([%d%.]+) damage per second%)")
				if dps then out.dps = tonumber(dps) end
			end
		end
	end
	return out
end

-- packed record in DressCodeDB.items: name^quality^itemlevel^req^class^subclass^set^equiploc^classes^rep^pvp^k:v,k:v
local function clean(s) return (tostring(s or ""):gsub("[%^,:]", " ")) end

local function pack(r)
	local stats = {}
	for k, n in pairs(r.v) do stats[#stats + 1] = k .. ":" .. n end
	return table.concat({ clean(r.n), r.q, r.il, r.req, r.c, r.s, r.set or 0, r.loc, clean(r.cl), clean(r.rep), clean(r.pvp),
		table.concat(stats, ",") }, "^")
end

local function unpack_record(id, s)
	local f = { strsplit("^", s) }
	if #f < 12 then return nil end
	local r = { id = id, n = f[1], q = tonumber(f[2]), il = tonumber(f[3]), req = tonumber(f[4]), c = tonumber(f[5]),
		s = tonumber(f[6]), set = tonumber(f[7]), loc = f[8], cl = f[9] ~= "" and f[9] or nil,
		rep = f[10] ~= "" and f[10] or nil, pvp = f[11] ~= "" and f[11] or nil, v = {} }
	for k, n in f[12]:gmatch("(%w+):([%d%.%-]+)") do r.v[k] = tonumber(n) end
	return r
end

DC.records = {} -- id -> record (this session)

-- build a record from the client (nil when the client doesn't have the item yet)
local function build(id)
	local name, link, q, il, req, _, subType, _, loc, _, _, c, s, _, _, set = GetInfo(id)
	if not name then return nil end
	local v = {}
	local stats = link and GetStats(link)
	for key, n in pairs(stats or {}) do
		local k = stat_key(key)
		if k and n ~= 0 then v[k] = (v[k] or 0) + n end
	end
	local t = read_tooltip(id, subType, c, s, loc, v)
	for k, n in pairs(t.eff or {}) do v[k] = n end
	if t.dps and not v.dps then v.dps = t.dps end
	if v.dps then v.dps = math.floor(v.dps * 10 + 0.5) / 10 end
	local r = { id = id, n = name, q = q or 1, il = il or 0, req = math.max(req or 0, t.rl or 0), c = c or 4, s = s or 0,
		set = set, loc = loc or "", cl = t.cl, rep = t.rep, pvp = t.pvp, v = v }
	DressCodeDB.items[id] = pack(r)
	return r
end

-- the record of an item; queues it for loading when the client doesn't have it yet.
-- lazy = don't read an unread item now (searches over thousands of items): queue it instead
function DC.Record(id, lazy)
	if not id then return nil end
	local r = DC.records[id]
	if r then return r end
	local s = DressCodeDB.items and DressCodeDB.items[id]
	if s then r = unpack_record(id, s) end
	if not r and lazy then DC.Want(id) return nil end
	if not r then r = build(id) end
	if r then
		DC.records[id] = r
		-- this character's proficiency for the type isn't known yet: one tooltip read tells
		if DC.Proficient(r.c, r.s) == nil and r.loc ~= "INVTYPE_CLOAK" and (r.c == 2 or r.s > 0) then
			local _, _, _, _, _, _, subType = GetInfo(id)
			read_tooltip(id, subType, r.c, r.s, r.loc, nil)
		end
	else
		DC.Want(id)
	end
	return r
end

-- forget proficiencies (level-ups and new weapon skills change them)
function DC.ResetProficiency() DressCodeChar.prof = {} end

---------------------------------------------------------------------------- 3. loading items in the background
local queue, queued, waiting, nwaiting = {}, {}, {}, 0
local MAX_WAITING, LOAD_BUDGET, LOAD_TIMEOUT = 100, 4, 10

function DC.Want(id)
	if queued[id] or DC.records[id] then return end
	queued[id] = true
	queue[#queue + 1] = id
end

function DC.QueueAll()
	local items = DressCodeDB.items or {}
	for _, id in ipairs(DC.catalog and DC.catalog.ids or {}) do
		if not items[id] then DC.Want(id) end
	end
end

function DC.LoadProgress() return #queue + nwaiting end

local loader = CreateFrame("Frame")
-- the answer comes as one of these (which one depends on the client)
loader:RegisterEvent("ITEM_DATA_LOAD_RESULT")
loader:RegisterEvent("GET_ITEM_INFO_RECEIVED")
loader:SetScript("OnEvent", function(_, _, id, ok)
	if waiting[id] then
		waiting[id], nwaiting = nil, nwaiting - 1
		if ok ~= false then queue[#queue + 1] = id else queued[id] = nil end -- read next (the loader takes from the end)
	end
end)
-- questions without an answer: give the slot back after a while (and skip the item for now)
local last_sweep = 0
local function sweep()
	local now = GetTime()
	if now - last_sweep < 2 then return end
	last_sweep = now
	for id, t in pairs(waiting) do
		if now - t > LOAD_TIMEOUT then waiting[id], nwaiting, queued[id] = nil, nwaiting - 1, nil end
	end
end
local learned_since = 0
loader:SetScript("OnUpdate", function(_, elapsed)
	sweep()
	if #queue == 0 or not (DressCodeDB and DressCodeDB.items) then return end
	local stop = debugprofilestop() + LOAD_BUDGET
	while #queue > 0 and debugprofilestop() < stop do
		local id = table.remove(queue)
		local ok, r = pcall(build, id)
		if ok and r then
			DC.records[id] = r
			queued[id] = nil
			learned_since = learned_since + 1
		elseif ok and not waiting[id] and nwaiting < MAX_WAITING then
			waiting[id], nwaiting = GetTime(), nwaiting + 1
			RequestLoad(id)
		elseif ok then
			table.insert(queue, 1, id) -- too many questions out: ask later
			break
		else
			queued[id] = nil -- a broken item: skip it
		end
	end
	if learned_since >= 400 or (#queue == 0 and learned_since > 0) then
		learned_since = 0
		if DC.OnItemsLearned then DC.OnItemsLearned() end
	end
end)

---------------------------------------------------------------------------- 4. sources

-- 4a. Encounter Journal: every instance's bosses and loot (once per patch; never while the journal is open)
local journal_job
local function journal_scan()
	local j = { build = DC.BUILD, instances = {}, items = {} }
	local oldTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
	local fc, fs
	if EJ_GetLootFilter then fc, fs = EJ_GetLootFilter() end
	-- entry levels of dungeons and raids (by name) from the game's dungeon list
	local levels = {}
	if GetLFGDungeonInfo then
		for d = 1, 3000 do
			local name, _, _, minLevel = GetLFGDungeonInfo(d)
			if name and minLevel and minLevel > 0 and (not levels[name] or minLevel < levels[name]) then levels[name] = minLevel end
		end
	end
	for tier = 1, EJ_GetNumTiers() do
		EJ_SelectTier(tier)
		for _, raid in ipairs({ false, true }) do
			local index = 1
			while true do
				local instanceID, name = EJ_GetInstanceByIndex(index, raid)
				if not instanceID then break end
				-- one instance at a time: a problem with one never stops the others
				local inst = { name = name, raid = raid, level = levels[name], bosses = {} }
				local ok, err = pcall(function()
				EJ_SelectInstance(instanceID)
				if EJ_ResetLootFilter then EJ_ResetLootFilter() end
				-- the instance's own artwork doubles as a backdrop ("stage") behind the character
				local _, _, bgImage, _, loreImage = EJ_GetInstanceInfo(instanceID)
				inst.art = loreImage or bgImage
				local bossIndex = {}
				for i = 1, (EJ_GetNumLoot and EJ_GetNumLoot() or 0) do
					local info = C_EncounterJournal.GetLootInfoByIndex(i)
					if info and info.itemID then
						local boss = info.encounterID and info.encounterID > 0 and EJ_GetEncounterInfo(info.encounterID) or "Other loot"
						local b = bossIndex[boss]
						if not b then
							b = { name = boss, items = {} }
							inst.bosses[#inst.bosses + 1] = b
							bossIndex[boss] = b
						end
						b.items[#b.items + 1] = info.itemID
						j.items[info.itemID] = j.items[info.itemID] or {}
						table.insert(j.items[info.itemID], #j.instances + 1)
					end
				end
				end)
				if not ok then j.errors = (j.errors or 0) + 1 j.lastError = tostring(err) end
				if #inst.bosses > 0 or inst.art then j.instances[#j.instances + 1] = inst end
				index = index + 1
				coroutine.yield()
			end
		end
	end
	-- give the journal back the player's own loot filter (0 = all classes: reset instead)
	pcall(function()
		if fc and fc > 0 and EJ_SetLootFilter then EJ_SetLootFilter(fc, fs or 0)
		elseif EJ_ResetLootFilter then EJ_ResetLootFilter() end
		if oldTier and oldTier > 0 and EJ_SelectTier then EJ_SelectTier(oldTier) end
	end)
	j.done = true
	DressCodeDB.journal = j
	DC.Print(#j.instances .. " dungeons and raids read from the Encounter Journal."
		.. (j.errors and (" (" .. j.errors .. " could not be read: " .. j.lastError .. ")") or ""))
	if DC.OnCatalog then DC.OnCatalog() end
end

local journal_frame = CreateFrame("Frame")
journal_frame:Hide()
journal_frame:SetScript("OnUpdate", function(self)
	if EncounterJournal and EncounterJournal:IsShown() then return end -- wait: don't change what the player looks at
	local ok, err = coroutine.resume(journal_job)
	if not ok then self:Hide() DC.Print("Encounter Journal could not be read: " .. tostring(err)) return end
	if coroutine.status(journal_job) == "dead" then self:Hide() end
end)

-- the journal's data may only be there once the game's own journal addon is loaded
local function load_journal_addon()
	local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal")
	if loaded == false and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal") return true end
end

function DC.ScanJournal(force)
	if not (EJ_GetNumTiers and EJ_SelectInstance and C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex) then return end
	load_journal_addon()
	if (EJ_GetNumTiers() or 0) == 0 then return end -- a journal without content (Classic-based clients)
	local j = DressCodeDB.journal
	if not force and j and j.build == DC.BUILD and j.done and #j.instances > 0 then return end
	local function start()
		journal_job = coroutine.create(journal_scan)
		journal_frame:Show()
	end
	if load_journal_addon() then C_Timer.After(2, start) else start() end
end

-- /dresscode ej: what the journal API answers (to find out why nothing is read)
function DC.JournalReport()
	load_journal_addon()
	local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal")
	DC.Print("Encounter Journal: journal addon loaded " .. tostring(loaded) .. ", tiers " .. tostring(EJ_GetNumTiers and EJ_GetNumTiers())
		.. ", current tier " .. tostring(EJ_GetCurrentTier and EJ_GetCurrentTier()))
	for tier = 1, math.min(3, EJ_GetNumTiers and EJ_GetNumTiers() or 0) do
		EJ_SelectTier(tier)
		local d1, dn = EJ_GetInstanceByIndex(1, false)
		local r1, rn = EJ_GetInstanceByIndex(1, true)
		print(("  tier %d (%s): first dungeon %s %s, first raid %s %s"):format(tier, tostring(EJ_GetTierInfo and EJ_GetTierInfo(tier)),
			tostring(d1), tostring(dn), tostring(r1), tostring(rn)))
		if d1 then
			EJ_SelectInstance(d1)
			print("    loot in " .. tostring(dn) .. ": " .. tostring(EJ_GetNumLoot and EJ_GetNumLoot()))
		end
	end
	local j = DressCodeDB.journal
	print("  saved: " .. (j and (#j.instances .. " instances, build " .. tostring(j.build) .. (j.lastError and (", last error: " .. j.lastError) or "")) or "nothing"))
end

---------------------------------------------------------------------------- 4a'. dungeons from the game's dungeon list
-- name -> { level = entry level, raid = true/false, art = background picture (only pictures that exist) }
local art_test = UIParent:CreateTexture(nil, "BACKGROUND")
art_test:Hide()

local function file_exists(path)
	if GetFileIDFromPath then return GetFileIDFromPath(path) ~= nil end
	return art_test:SetTexture(path) and true or false
end

-- a dungeon's picture: the game's artwork folders, by name ("Wailing Caverns" -> WailingCaverns / WAILINGCAVERNS)
local function find_art(name, texture)
	local camel = name:gsub("^The ", ""):gsub("[%s'%-:,]", "")
	local full = name:gsub("[%s'%-:,]", "")
	local candidates = {}
	if texture and texture ~= "" then
		candidates[#candidates + 1] = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-" .. texture
	end
	for _, n in ipairs({ camel, full }) do
		candidates[#candidates + 1] = "Interface\\EncounterJournal\\UI-EJ-LOREBG-" .. n
		candidates[#candidates + 1] = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-" .. n
		candidates[#candidates + 1] = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-" .. n:upper()
		candidates[#candidates + 1] = "Interface\\Glues\\LoadingScreens\\LoadScreen" .. n
	end
	for _, path in ipairs(candidates) do
		if file_exists(path) then return path end
	end
end
function DC.ScanDungeons()
	if not GetLFGDungeonInfo then return end
	-- read at every login (a few thousand quick lookups), so improvements and patches always show
	local d = { build = DC.BUILD, list = {} }
	local count = 0
	for id = 1, 3000 do
		local name, typeID, _, minLevel, _, _, _, _, _, _, texture, _, maxPlayers = GetLFGDungeonInfo(id)
		if name and name ~= "" and minLevel and minLevel > 0 then
			local e = d.list[name]
			if not e then
				e = { level = minLevel, raid = (maxPlayers or 5) > 5 or typeID == 2 }
				d.list[name] = e
				count = count + 1
			elseif minLevel < e.level then
				e.level = minLevel
			end
			if not e.art then e.art = find_art(name, texture) end
		end
	end
	DressCodeDB.dungeons = d
	DC.Print(count .. " dungeons and raids found in the game's dungeon list.")
end

-- /dresscode dungeons: the raw answers of the dungeon list (to find the pictures)
function DC.DungeonReport()
	local shown = 0
	for id = 1, 3000 do
		local r = { GetLFGDungeonInfo(id) }
		if r[1] and r[1] ~= "" then
			local parts = {}
			for i = 1, math.min(#r, 16) do parts[#parts + 1] = i .. "=" .. tostring(r[i]) end
			print("  " .. id .. ": " .. table.concat(parts, "  "))
			shown = shown + 1
			if shown >= 3 then break end
		end
	end
	print("  GetFileIDFromPath: " .. tostring(GetFileIDFromPath ~= nil))
end

-- dungeon info of an item: "Instance - Boss" lines and the lowest entry level (journal, else appearance drops)
local drop_cache = {}
function DC.DungeonInfo(id)
	local lines, level = DC.JournalSources(id)
	if #lines > 0 then return lines, level end
	local c = drop_cache[id]
	if not c then
		c = { lines = {} }
		local _, drops = DC.AppearanceSource(id)
		local list = DressCodeDB.dungeons and DressCodeDB.dungeons.list or {}
		for _, line in ipairs(drops or {}) do
			c.lines[#c.lines + 1] = line
			local e = list[line:match("^(.-) %- ") or line]
			if e and (not c.level or e.level < c.level) then c.level = e.level end
		end
		drop_cache[id] = c
	end
	return c.lines, c.level
end

-- "Instance - Boss" lines for an item
function DC.JournalSources(id)
	local j = DressCodeDB.journal
	local out = {}
	if not (j and j.items[id]) then return out, nil end
	local level
	for _, idx in ipairs(j.items[id]) do
		local inst = j.instances[idx]
		if inst then
			for _, b in ipairs(inst.bosses) do
				for _, item in ipairs(b.items) do
					if item == id then out[#out + 1] = inst.name .. " - " .. b.name break end
				end
			end
			if inst.level and (not level or inst.level < level) then level = inst.level end
		end
	end
	return out, level
end

-- 4b. appearance source: "Boss Drop", "Quest", "Vendor", ... and where it drops
function DC.AppearanceSource(id)
	if not (C_TransmogCollection and C_TransmogCollection.GetItemInfo) then return nil end
	local ok, _, sourceID = pcall(C_TransmogCollection.GetItemInfo, id)
	if not ok or not sourceID then return nil end
	local res = { pcall(C_TransmogCollection.GetAppearanceSourceInfo, sourceID) }
	local sourceType
	if res[1] then
		if type(res[2]) == "table" then sourceType = res[2].sourceType else sourceType = res[9] end
	end
	local label = sourceType and _G["TRANSMOG_SOURCE_" .. sourceType]
	local drops = {}
	if C_TransmogCollection.GetAppearanceSourceDrops then
		local ok2, list = pcall(C_TransmogCollection.GetAppearanceSourceDrops, sourceID)
		for _, d in ipairs(ok2 and list or {}) do
			if d.instance and d.encounter then drops[#drops + 1] = d.instance .. " - " .. d.encounter end
		end
	end
	return label, drops
end

-- 4c. vendors you visit and 4d. recipes you know (remembered per account)
local sources = CreateFrame("Frame")
sources:RegisterEvent("MERCHANT_SHOW")
sources:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
sources:SetScript("OnEvent", function(_, event)
	if event == "MERCHANT_SHOW" then
		local npc, zone = UnitName("npc") or "?", GetZoneText() or ""
		DressCodeDB.vendors = DressCodeDB.vendors or {}
		for i = 1, GetMerchantNumItems() do
			local id = DC.ItemID(GetMerchantItemLink(i))
			if id and DC.EQUIP_SLOTS[DC.EquipLoc(id) or ""] then
				local price
				if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
					local info = C_MerchantFrame.GetItemInfo(i)
					price = info and info.price
				else
					price = select(3, GetMerchantItemInfo(i))
				end
				DressCodeDB.vendors[id] = { npc = npc, zone = zone, price = price or 0 }
			end
		end
	elseif event == "TRADE_SKILL_LIST_UPDATE" and C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
		local ok, base = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
		local prof = ok and base and base.professionName or "Crafting"
		DressCodeDB.crafted = DressCodeDB.crafted or {}
		for _, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
			local ok2, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
			local id = ok2 and schematic and schematic.outputItemID
			if id and DC.EQUIP_SLOTS[DC.EquipLoc(id) or ""] then DressCodeDB.crafted[id] = prof end
		end
	end
end)

-- every known source of an item, as readable lines (gear only: where to get it, nothing about objectives)
function DC.Sources(id)
	local out = {}
	local drops = DC.DungeonInfo(id)
	for _, s in ipairs(drops) do out[#out + 1] = s end
	for _, q in ipairs(DC.QuestsFor and DC.QuestsFor(id) or {}) do
		out[#out + 1] = "Quest: " .. q.title .. (q.zone ~= "" and (" (" .. q.zone .. ")") or "")
	end
	local v = DressCodeDB.vendors and DressCodeDB.vendors[id]
	if v then
		out[#out + 1] = "Vendor: " .. v.npc .. (v.zone ~= "" and (" (" .. v.zone .. ")") or "")
			.. (v.price > 0 and ("  " .. ((C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString)(v.price)) or "")
	end
	local craft = DressCodeDB.crafted and DressCodeDB.crafted[id]
	if craft then out[#out + 1] = "Crafted: " .. craft end
	if #out == 0 then
		local label = DC.AppearanceSource(id)
		if label then out[#out + 1] = label end
	end
	return out
end
