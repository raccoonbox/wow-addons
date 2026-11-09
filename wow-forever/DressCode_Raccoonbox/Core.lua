-- Dress Code [Raccoonbox] for WoW Forever - the rules: what beats what you wear, who can use what,
-- the level an item makes sense at, outfits, and quests learned in game (shared between players).
-- Same rules as the OctoWoW version, ported to the modern client.
local ADDON, DC = ...

---------------------------------------------------------------------------- saved data
local function init()
	DressCodeDB = DressCodeDB or {}
	DressCodeChar = DressCodeChar or {}
	local db, ch = DressCodeDB, DressCodeChar
	if not db.items or db.items.build ~= DC.BUILD then db.items = { build = DC.BUILD } end
	db.quests = db.quests or {}
	db.vendors = db.vendors or {}
	db.crafted = db.crafted or {}
	if db.tooltip == nil then db.tooltip = true end
	if db.share == nil then db.share = true end
	ch.keys = ch.keys or {}
	ch.doll = ch.doll or {}
	ch.locks = ch.locks or {}
	ch.outfits = ch.outfits or {}
	ch.active = ch.active or 1
	ch.prof = ch.prof or {}
	ch.ahead = ch.ahead or 0
	DC.ApplyTheme(db.theme or "dark")
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and name == ADDON then
		init()
		if DC.OnInit then DC.OnInit() end
	elseif event == "PLAYER_LOGIN" then
		DC.RefreshPlayer()
		DC.ScanCatalog()
		C_Timer.After(5, function() pcall(DC.ScanDungeons) end)
		C_Timer.After(15, function() DC.ScanJournal() end)
	end
end)

---------------------------------------------------------------------------- the player
local player = {}
DC.player = player
function DC.RefreshPlayer(level)
	local localized, token, classID = UnitClass("player")
	player.class, player.className, player.classID = token, localized, classID or 0
	player.level = level or UnitLevel("player")
	player.faction = UnitFactionGroup("player")
	player.classbit = classID and 2 ^ (classID - 1) or 0
end

---------------------------------------------------------------------------- stats

DC.STATS = {
	{ key = "str", label = "Strength", short = "Str" }, { key = "agi", label = "Agility", short = "Agi" },
	{ key = "sta", label = "Stamina", short = "Sta" }, { key = "int", label = "Intellect", short = "Int" },
	{ key = "spi", label = "Spirit", short = "Spi" }, { key = "armor", label = "Armor", short = "Armor" },
	{ key = "spelldmg", label = "Spell damage", short = "SpDmg" }, { key = "heal", label = "Healing", short = "Heal" },
	{ key = "spellcrit", label = "Spell crit", short = "SpCrit" }, { key = "spellhit", label = "Spell hit", short = "SpHit" },
	{ key = "crit", label = "Crit", short = "Crit" }, { key = "hit", label = "Hit", short = "Hit" },
	{ key = "ap", label = "Attack power", short = "AP" }, { key = "mp5", label = "Mana / 5 sec", short = "Mp5" },
	{ key = "defense", label = "Defense", short = "Def" }, { key = "dodge", label = "Dodge", short = "Dodge" },
	{ key = "dps", label = "Weapon DPS", short = "DPS" }, { key = "health", label = "Health", short = "HP" },
}

-- the stats of what you wear in an inventory slot
local function worn(slot)
	local id = GetInventoryItemID("player", slot)
	local r = id and DC.Record(id)
	return r and r.v or {}
end

local function sum(v, keys)
	local s = 0
	for k in pairs(keys) do s = s + (v[k] or 0) end
	return s
end

-- what an item would be compared against: the slot's item, the weaker ring/trinket, main + off hand for a two-hander
function DC.CurrentVector(loc, keys)
	local slots = DC.EQUIP_SLOTS[loc]
	if not slots then return {} end
	if loc == "INVTYPE_2HWEAPON" then
		local v = {}
		for k, n in pairs(worn(16)) do v[k] = n end
		for k, n in pairs(worn(17)) do if k ~= "dps" then v[k] = (v[k] or 0) + n end end
		return v
	end
	if #slots == 2 then
		local a, b = worn(slots[1]), worn(slots[2])
		return sum(a, keys or {}) <= sum(b, keys or {}) and a or b
	end
	return worn(slots[1])
end

-- whole tooltip text of an item, lower case (for the text search)
local text_cache = {}
function DC.ItemText(id)
	local t = text_cache[id]
	if t then return t end
	local data = C_TooltipInfo and C_TooltipInfo.GetItemByID(id)
	if not data or not data.lines then return nil end
	if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, data) end
	local parts = {}
	for _, l in ipairs(data.lines) do
		if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, l) end
		parts[#parts + 1] = l.leftText or ""
		parts[#parts + 1] = l.rightText or ""
	end
	t = table.concat(parts, " "):lower()
	text_cache[id] = t
	return t
end

-- does an item beat what you wear? every ticked stat at least as high, at least one higher.
-- returns the gains table, or nil when it doesn't qualify
function DC.Compare(r, keys, search)
	local cur = DC.CurrentVector(r.loc, keys)
	local gains, better, any = {}, false, false
	for k in pairs(keys) do
		any = true
		local a, b = r.v[k] or 0, cur[k] or 0
		if a < b then return nil end
		if a > b then better = true gains[k] = a - b end
	end
	if search and search ~= "" then
		if not r.n:lower():find(search, 1, true) then
			local text = DC.ItemText(r.id)
			if not text or not text:find(search, 1, true) then return nil end
		end
		better = true
	end
	if not any and not (search and search ~= "") then return nil end
	if not better then return nil end
	return gains
end

-- every difference against what you wear (for item tooltips)
function DC.Difference(r)
	local cur = DC.CurrentVector(r.loc, r.v)
	local diff = {}
	for _, s in ipairs(DC.STATS) do
		local d = (r.v[s.key] or 0) - (cur[s.key] or 0)
		if d ~= 0 then diff[s.key] = d end
	end
	return diff
end

-- "+4 Sta +2 Int" (negative numbers too, for tooltips), in the order of DC.STATS
function DC.GainText(gains, colored)
	local parts = {}
	for _, s in ipairs(DC.STATS) do
		local g = gains[s.key]
		if g then
			local n = (math.floor(g) == g) and ("%d"):format(math.abs(g)) or ("%.1f"):format(math.abs(g))
			local txt = (g >= 0 and "+" or "-") .. n .. " " .. s.short
			if colored then txt = (g >= 0 and "|cff55dd66" or "|cffee5555") .. txt .. "|r" end
			parts[#parts + 1] = txt
		end
	end
	return table.concat(parts, "  ")
end

---------------------------------------------------------------------------- who can use what, and from which level

-- the level an item can be worn from, and why:
--  item requirement -> quest pick-up level (quests learned in game) -> dungeon/raid entry level for
--  Encounter Journal drops -> any level. Never the item level.
function DC.ReqLevel(r)
	if r.req and r.req > 0 then return r.req end
	local mine, any
	for _, q in ipairs(DC.QuestsFor(r.id)) do
		local lvl = q.seen
		if lvl and lvl > 0 then
			if q.faction == player.faction and (not mine or lvl < mine) then mine = lvl end
			if not any or lvl < any then any = lvl end
		end
	end
	if mine or any then return mine or any, "quest" end
	local _, dungeon = DC.DungeonInfo(r.id)
	if dungeon then return dungeon, "dungeon" end
	return 0
end

function DC.LevelText(r)
	local need, why = DC.ReqLevel(r)
	if need == 0 then return "any level" end
	return "L" .. need .. (why and (", " .. why) or "")
end

function DC.CanUse(r, level)
	level = level or player.level
	if (DC.ReqLevel(r)) > level then return false end
	if r.cl and player.className and not r.cl:find(player.className, 1, true) then return false end
	if DC.Proficient(r.c, r.s) == false then return false end
	return true
end

---------------------------------------------------------------------------- the search
-- opts: slot = inventory slot (nil = all), keys = { str = true, ... }, search = lower case text, ahead = levels
function DC.Find(opts)
	local level = player.level + (opts.ahead or 0)
	local out, seen = {}, {}
	for _, id in ipairs(DC.catalog and DC.catalog.ids or {}) do
		local r = DC.Record(id, true) -- only items already read; the rest are read in the background
		if r and not seen[r.n] then
			local slots = DC.EQUIP_SLOTS[r.loc]
			local wanted = not opts.slot
			for _, s in ipairs(slots or {}) do if s == opts.slot then wanted = true end end
			if wanted and DC.CanUse(r, level) then
				local gains = DC.Compare(r, opts.keys, opts.search)
				if gains then
					seen[r.n] = true
					local total = 0
					for _, g in pairs(gains) do total = total + g end
					out[#out + 1] = { r = r, gains = gains, total = total }
				end
			end
		end
	end
	table.sort(out, function(a, b)
		if a.total ~= b.total then return a.total > b.total end
		return a.r.il > b.r.il
	end)
	local limited = {}
	for i = 1, math.min(300, #out) do limited[i] = out[i] end
	return limited, #out
end

---------------------------------------------------------------------------- quests learned in game
-- When you open a quest at an NPC, finish one, or have it in your quest log, its reward items are
-- remembered: being offered the quest proves the rewards are within reach. Gear only - no objectives.
-- DressCodeDB.quests[questID] = { t = title, l = quest level (0 unknown), i = { [item] = true },
--   f = { Alliance = lowest player level seen, Horde = ... }, c = class bits, g = giver, z = zone,
--   heard = true when only heard from other players, n = { [player] = true } who told us }
local MAX_NAMES = 3
local index -- item id -> list of { title, zone, seen, faction, level, giver }

local function trusted(r)
	if not r.heard then return true end
	local n = 0
	for _ in pairs(r.n or {}) do n = n + 1 end
	return n >= 2
end

local function clean(s) return (tostring(s or ""):gsub("[~%^|]", " "):gsub("^%s+", ""):gsub("%s+$", "")) end

function DC.QuestsFor(id)
	if not index then
		index = {}
		for _, r in pairs(DressCodeDB and DressCodeDB.quests or {}) do
			if trusted(r) then
				for faction, seen in pairs(r.f) do
					local q = { title = r.t, zone = r.z or "", seen = seen, faction = faction, level = r.l, giver = r.g or "" }
					for item in pairs(r.i) do
						index[item] = index[item] or {}
						table.insert(index[item], q)
					end
				end
			end
		end
	end
	return index[id] or {}
end

local function has_bit(mask, bit) return bit > 0 and math.floor(mask / bit) % 2 == 1 end
local function add_bits(a, b)
	local bit = 1
	for _ = 1, 13 do
		if has_bit(b, bit) and not has_bit(a, bit) then a = a + bit end
		bit = bit * 2
	end
	return a
end

-- remember a quest you saw; level = quest level (0 when unknown)
function DC.LearnQuest(qid, title, level, items, giver, zone)
	title = clean(title)
	if not qid or qid == 0 or title == "" or #items == 0 or not player.faction then return end
	local r = DressCodeDB.quests[qid]
	local changed
	if not r then r = { t = title, l = level or 0, i = {}, f = {}, c = 0 } DressCodeDB.quests[qid] = r changed = true end
	if r.heard then r.heard, r.n = nil, nil changed = true end -- seen with your own eyes now
	if r.l == 0 and (level or 0) > 0 then r.l = level changed = true end
	for _, id in ipairs(items) do
		if not r.i[id] then r.i[id] = true changed = true end
	end
	if not r.f[player.faction] or player.level < r.f[player.faction] then r.f[player.faction] = player.level changed = true end
	if not has_bit(r.c, player.classbit) then r.c = add_bits(r.c, player.classbit) changed = true end
	giver, zone = clean(giver), clean(zone)
	if not r.g and giver ~= "" then r.g = giver changed = true end
	if not r.z and zone ~= "" then r.z = zone changed = true end
	if changed then index = nil end
end

local function quest_window_items()
	local items = {}
	for _, kind in ipairs({ "reward", "choice" }) do
		local n = kind == "reward" and GetNumQuestRewards() or GetNumQuestChoices()
		for i = 1, n or 0 do
			local id = DC.ItemID(GetQuestItemLink(kind, i))
			if id then items[#items + 1] = id end
		end
	end
	return items
end

local function scan_log()
	if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return end
	local selected = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		if info and not info.isHeader and info.questID and info.questID > 0 then
			local qid, items = info.questID, {}
			if C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(qid) end
			for j = 1, GetNumQuestLogRewards(qid) or 0 do
				local id = DC.ItemID(GetQuestLogItemLink("reward", j))
				if not id then id = select(6, GetQuestLogRewardInfo(j, qid)) end
				if id then items[#items + 1] = id end
			end
			for j = 1, GetNumQuestLogChoices(qid) or 0 do
				local id = DC.ItemID(GetQuestLogItemLink("choice", j))
				if id then items[#items + 1] = id end
			end
			DC.LearnQuest(qid, info.title, info.level, items)
		end
	end
	if selected and C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(selected) end
end

local quest_events = CreateFrame("Frame")
quest_events:RegisterEvent("QUEST_DETAIL")
quest_events:RegisterEvent("QUEST_COMPLETE")
quest_events:RegisterEvent("QUEST_LOG_UPDATE")
local log_pending
quest_events:SetScript("OnEvent", function(_, event)
	if not DressCodeDB then return end
	if event == "QUEST_LOG_UPDATE" then
		-- the log changes often: read it a moment after the change, at most every 5 seconds
		if not log_pending then
			log_pending = true
			C_Timer.After(5, function() log_pending = nil pcall(scan_log) end)
		end
		return
	end
	-- offered (QUEST_DETAIL) or being turned in (QUEST_COMPLETE); the NPC is the giver only when offered
	pcall(DC.LearnQuest, GetQuestID(), GetTitleText(), 0, quest_window_items(),
		event == "QUEST_DETAIL" and UnitName("npc") or nil, GetZoneText())
end)

---------------------------------------------------------------------------- sharing learned quests between players
-- Dress Code copies tell each other their quests over addon messages: battlegrounds and group
-- finder groups (INSTANCE_CHAT), raids, parties and the guild. A quest heard from others counts (and is
-- passed on) once two different players reported it. Messages start with "1:" and never contain "|".
local PREFIX, RATE, PER_VISIT, START, GROUP_RESET, GUILD_RESET = "RBXDC", 1.5, 100, 30, 600, 3600
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end

-- one quest for one faction: faction^seen^level^classes^questID^title^giver^zone^ids
local function entry(qid, r, faction, short)
	local ids = {}
	for id in pairs(r.i) do ids[#ids + 1] = id end
	table.sort(ids)
	return faction:sub(1, 1) .. "^" .. r.f[faction] .. "^" .. r.l .. "^" .. r.c .. "^" .. qid .. "^" .. r.t .. "^"
		.. (short and "" or (r.g or "")) .. "^" .. (short and "" or (r.z or "")) .. "^" .. table.concat(ids, ".")
end

function DC.HearQuest(text, sender)
	local fc, seen, level, classes, qid, title, giver, zone, ids =
		text:match("^([AH])%^(%d+)%^(%d+)%^(%d+)%^(%d+)%^([^%^]+)%^([^%^]*)%^([^%^]*)%^([%d%.]+)$")
	if not fc then return end
	seen, level, classes, qid = tonumber(seen), tonumber(level), tonumber(classes), tonumber(qid)
	title = clean(title)
	if title == "" or qid == 0 or seen < 1 or seen > 100 then return end
	if level > 0 and seen < level - 10 then return end -- a pick-up level far below the quest's: not believable
	local faction = fc == "A" and "Alliance" or "Horde"
	local r = DressCodeDB.quests[qid]
	local before = r and trusted(r)
	local changed
	if not r then r = { t = title, l = level, i = {}, f = {}, c = 0, heard = true, n = {} } DressCodeDB.quests[qid] = r changed = true end
	if r.heard then
		r.n = r.n or {}
		local count = 0
		for _ in pairs(r.n) do count = count + 1 end
		if not r.n[sender] and count < MAX_NAMES then r.n[sender] = true changed = true end
	end
	if r.l == 0 and level > 0 then r.l = level changed = true end
	for id in ids:gmatch("(%d+)") do
		id = tonumber(id)
		if not r.i[id] then r.i[id] = true changed = true end
	end
	if not r.f[faction] or seen < r.f[faction] then r.f[faction] = seen changed = true end
	local c = add_bits(r.c, classes)
	if c ~= r.c then r.c = c changed = true end
	giver, zone = clean(giver), clean(zone)
	if not r.g and giver ~= "" then r.g = giver changed = true end
	if not r.z and zone ~= "" then r.z = zone changed = true end
	if changed and (before or trusted(r)) then index = nil end
	return qid, faction
end

local sync = CreateFrame("Frame")
local told, count, reset_at, start_at = {}, {}, {}, nil

local function channels()
	local out = {}
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then out[#out + 1] = "INSTANCE_CHAT"
	elseif IsInRaid() then out[#out + 1] = "RAID"
	elseif IsInGroup() then out[#out + 1] = "PARTY" end
	if IsInGuild() then out[#out + 1] = "GUILD" end
	return out
end

local function new_visit(channel, gap)
	if reset_at[channel] and GetTime() - reset_at[channel] < gap then return end
	reset_at[channel], told[channel], count[channel] = GetTime(), {}, 0
end

local function next_entry(channel)
	local t = told[channel]
	for qid, r in pairs(DressCodeDB.quests) do
		if trusted(r) then
			for faction in pairs(r.f) do
				local key = qid .. "@" .. faction
				local text = entry(qid, r, faction)
				if #text > 230 then text = entry(qid, r, faction, true) end
				if #text <= 230 and t[key] ~= text then return key, text end
			end
		end
	end
end

sync:RegisterEvent("PLAYER_ENTERING_WORLD")
sync:RegisterEvent("GROUP_ROSTER_UPDATE")
sync:RegisterEvent("PLAYER_GUILD_UPDATE")
sync:RegisterEvent("CHAT_MSG_ADDON")
sync:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
	if not DressCodeDB then return end
	if event == "CHAT_MSG_ADDON" then
		if prefix ~= PREFIX or not sender then return end
		sender = Ambiguate(sender, "none")
		if sender == UnitName("player") then return end
		local text = msg and msg:match("^1:(.+)$")
		if not text then return end
		local qid, faction = DC.HearQuest(text, sender)
		if qid and told[channel] then
			local r = DressCodeDB.quests[qid]
			if entry(qid, r, faction) == text or entry(qid, r, faction, true) == text then told[channel][qid .. "@" .. faction] = text end
		end
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		new_visit("INSTANCE_CHAT", 0) new_visit("RAID", 0) new_visit("PARTY", 0) new_visit("GUILD", GUILD_RESET)
	else
		new_visit("RAID", GROUP_RESET) new_visit("PARTY", GROUP_RESET) new_visit("INSTANCE_CHAT", GROUP_RESET)
		if event == "PLAYER_GUILD_UPDATE" then new_visit("GUILD", GUILD_RESET) end
	end
	if not start_at or start_at < GetTime() then start_at = GetTime() + START end
end)

local elapsed, turn = 0, 0
sync:SetScript("OnUpdate", function(_, e)
	elapsed = elapsed + e
	if elapsed < RATE then return end
	elapsed = 0
	if not (start_at and GetTime() >= start_at and DressCodeDB and DressCodeDB.share) then return end
	local list = channels()
	for _ = 1, #list do
		turn = turn % #list + 1
		local channel = list[turn]
		if not told[channel] then new_visit(channel, 0) end
		if count[channel] < PER_VISIT then
			local key, text = next_entry(channel)
			if key then
				C_ChatInfo.SendAddonMessage(PREFIX, "1:" .. text, channel)
				told[channel][key] = text
				count[channel] = count[channel] + 1
				return
			end
		end
	end
end)

-- how many quests are known (yours + trusted ones heard from others) and only heard once
function DC.QuestCounts()
	local known, waiting = 0, 0
	for _, r in pairs(DressCodeDB.quests) do
		if trusted(r) then known = known + 1 else waiting = waiting + 1 end
	end
	return known, waiting
end

---------------------------------------------------------------------------- level-ups and gear changes
local watch = CreateFrame("Frame")
watch:RegisterEvent("PLAYER_LEVEL_UP")
watch:RegisterEvent("SKILL_LINES_CHANGED")
watch:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
watch:SetScript("OnEvent", function(_, event, arg)
	if event == "PLAYER_LEVEL_UP" then
		DC.RefreshPlayer(arg) -- UnitLevel can still say the old level during this event
		DC.ResetProficiency()
	elseif event == "SKILL_LINES_CHANGED" then
		DC.ResetProficiency()
	end
	if DC.Refresh then DC.Refresh() end
end)
