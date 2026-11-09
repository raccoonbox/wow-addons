-- Dress Code [Raccoonbox] - core: item data, who can use what, scoring, sources.
-- Item stats come from Data.lua (generated from the WoW item cache), equip effects ("+healing",
-- "mana per 5", crit...) are read from item tooltips in game, drop/vendor sources come from
-- AtlasLoot (baked into Data.lua) and pfQuest (read live when pfQuest is loaded).

DressCode = {}
local DC = DressCode

---------------------------------------------------------------------------- helpers

local function hasbit(mask, bit)
	if not mask or mask == -1 or mask == 0 then return true end
	if mask < 0 then mask = mask + 4294967296 end
	return math.mod(math.floor(mask / bit), 2) == 1
end

local function item_id(link)
	local _, _, id = strfind(link or "", "item:(%d+)")
	return tonumber(id)
end
DC.item_id = item_id

---------------------------------------------------------------------------- item records

local cache = {}

-- fields: invtype,cls,sub,quality,req,ilvl,armor,dmin,dmax,speed*100,sta,int,spi,agi,str,classmask,racemask,sources,name
function DC.Item(id)
	if not id then return end
	local c = cache[id]
	if c ~= nil then return c or nil end
	local s = DressCodeItems and DressCodeItems[id]
	if not s and DressCodeDB and DressCodeDB.learned then s = DressCodeDB.learned[id] end
	if not s or s == "x" then cache[id] = false return end
	local f, pos = {}, 1
	for k = 1, 18 do
		local e = strfind(s, ",", pos, true)
		f[k] = strsub(s, pos, e - 1)
		pos = e + 1
	end
	local item = {
		id = id, invtype = tonumber(f[1]), cls = tonumber(f[2]), sub = tonumber(f[3]), quality = tonumber(f[4]),
		req = tonumber(f[5]), ilvl = tonumber(f[6]), armor = tonumber(f[7]),
		dmin = tonumber(f[8]), dmax = tonumber(f[9]), speed = tonumber(f[10]) / 100,
		stats = { sta = tonumber(f[11]), int = tonumber(f[12]), spi = tonumber(f[13]), agi = tonumber(f[14]), str = tonumber(f[15]) },
		aclass = tonumber(f[16]), arace = tonumber(f[17]), src = f[18], name = strsub(s, pos),
	}
	cache[id] = item
	return item
end

---------------------------------------------------------------------------- who can use what

-- armor subclasses: 1 cloth 2 leather 3 mail 4 plate 6 shield 7 libram 8 idol 9 totem
-- weapon subclasses: 0 axe 1 2h axe 2 bow 3 gun 4 mace 5 2h mace 6 polearm 7 sword 8 2h sword
--                    10 staff 13 fist 15 dagger 16 thrown 18 crossbow 19 wand
local PROF = {
	WARRIOR = { armor = { 1, 2, 3, 6 }, armor40 = { 4 }, weapon = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 } },
	PALADIN = { armor = { 1, 2, 3, 6, 7 }, armor40 = { 4 }, weapon = { 0, 1, 4, 5, 6, 7, 8 } },
	HUNTER  = { armor = { 1, 2 }, armor40 = { 3 }, weapon = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 } },
	ROGUE   = { armor = { 1, 2 }, weapon = { 2, 3, 4, 7, 13, 15, 16, 18 } },
	PRIEST  = { armor = { 1 }, weapon = { 4, 10, 15, 19 } },
	SHAMAN  = { armor = { 1, 2, 6, 9 }, armor40 = { 3 }, weapon = { 0, 1, 4, 5, 10, 13, 15 } },
	MAGE    = { armor = { 1 }, weapon = { 7, 10, 15, 19 } },
	WARLOCK = { armor = { 1 }, weapon = { 7, 10, 15, 19 } },
	DRUID   = { armor = { 1, 2, 8 }, weapon = { 4, 5, 10, 13, 15 } },
}
local CLASS_BIT = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024 }
local RACE_BIT = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128, Goblin = 256, BloodElf = 512 }

local player = {}
local function refresh_player()
	local _, class = UnitClass("player")
	local _, race = UnitRace("player")
	player.class, player.level = class, UnitLevel("player")
	player.classbit, player.racebit = CLASS_BIT[class] or 0, RACE_BIT[race]
	local p = PROF[class] or { armor = { 1 }, weapon = {} }
	player.armor, player.weapon = {}, {}
	for _, s in ipairs(p.armor) do player.armor[s] = true end
	if player.level >= 40 then for _, s in ipairs(p.armor40 or {}) do player.armor[s] = true end end
	for _, s in ipairs(p.weapon) do player.weapon[s] = true end
end
DC.player = player
DC.refresh_player = refresh_player

-- the level an item can be worn from: its normal level requirement (item data, or the tooltip's
-- "Requires Level"), otherwise the level at which you can pick up its quest. Second value: "quest"
function DC.ReqLevel(item)
	if item.req > 0 then return item.req end
	local text = DC.Text and DC.Text(item.id)
	if text then
		local _, _, n = strfind(text, "requires level (%d+)")
		if n then return tonumber(n) end
	end
	-- the quest's pick-up level: your own faction's version if there is one, else any version
	local mine, any
	for _, q in ipairs(DC.Quests and DC.Quests(item.id) or {}) do
		if q.minlevel > 0 then
			if DC.QuestForMe(q) and (not mine or q.minlevel < mine) then mine = q.minlevel end
			if not any or q.minlevel < any then any = q.minlevel end
		end
	end
	if mine or any then return mine or any, "quest" end
	return 0
end

function DC.CanUse(item, level)
	level = level or player.level
	if item.req > level then return false end
	local need = DC.ReqLevel(item)
	if need > level then return false end
	if not hasbit(item.aclass, player.classbit) then return false end
	if player.racebit and not hasbit(item.arace, player.racebit) then return false end
	if DC.QuestBlocked and DC.QuestBlocked(item) then return false end
	if item.cls == 4 then
		return item.sub == 0 or player.armor[item.sub] or false
	elseif item.cls == 2 then
		return player.weapon[item.sub] or false
	end
	return false
end

---------------------------------------------------------------------------- roles and scoring

DC.ROLES = {
	{ key = "heal",   name = "Healer",          w = { sta = .8, int = 1, spi = .7, heal = 1.1, mp5 = 2.5, spellcrit = 8, armor = .005 } },
	{ key = "caster", name = "Caster damage",   w = { sta = .8, int = .9, spi = .3, spelldmg = 1.2, spellcrit = 10, spellhit = 10, armor = .005 } },
	{ key = "melee",  name = "Melee",           w = { sta = .8, str = 1, agi = 1, ap = .5, crit = 12, hit = 10, armor = .01, dps = 3, slow = 2 } },
	{ key = "tank",   name = "Tank",            w = { sta = 1.5, agi = .8, str = .5, armor = .06, defense = 1.5, dodge = 12, parry = 12, block = 6, dps = 1 } },
	{ key = "ranged", name = "Ranged (hunter)", w = { agi = 1.2, sta = .8, int = .3, ap = .5, rap = .5, crit = 12, hit = 10, armor = .005, rdps = 3 } },
}
local DEFAULT_ROLE = { PRIEST = "heal", DRUID = "heal", SHAMAN = "heal", PALADIN = "heal", MAGE = "caster",
	WARLOCK = "caster", WARRIOR = "melee", ROGUE = "melee", HUNTER = "ranged" }

function DC.Role()
	local key = DressCodeChar and DressCodeChar.role or DEFAULT_ROLE[player.class] or "melee"
	for _, r in ipairs(DC.ROLES) do if r.key == key then return r end end
	return DC.ROLES[1]
end

-- equip effects, read once per item from its tooltip (only for items the client has cached)
local scanner = CreateFrame("GameTooltip", "DressCodeScanTip", nil, "GameTooltipTemplate")
scanner:SetOwner(WorldFrame, "ANCHOR_NONE")

local EFFECTS = {
	{ "increases damage and healing done by magical spells and effects by up to (%d+)", "spelldmg", "heal" },
	{ "increases healing done by spells and effects by up to (%d+)", "heal" },
	{ "increases damage done by %a+ spells and effects by up to (%d+)", "schooldmg" },
	{ "restores (%d+) mana per 5 sec", "mp5" },
	{ "critical strike with spells by (%d+)", "spellcrit" },
	{ "chance to hit with spells by (%d+)", "spellhit" },
	{ "critical strike by (%d+)", "crit" },
	{ "chance to hit by (%d+)", "hit" },
	{ "%+(%d+) ranged attack power", "rap" },
	{ "%+(%d+) attack power", "ap" },
	{ "increased defense %+(%d+)", "defense" },
	{ "chance to dodge an attack by (%d+)", "dodge" },
	{ "chance to parry an attack by (%d+)", "parry" },
	{ "chance to block attacks with a shield by (%d+)", "block" },
}

local effects_cache = {}
function DC.Effects(id)
	local e = effects_cache[id]
	if e then return e end
	e = {}
	if GetItemInfo(id) then
		scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
		scanner:ClearLines()
		scanner:SetHyperlink("item:" .. id .. ":0:0:0")
		for i = 2, scanner:NumLines() do
			local line = getglobal("DressCodeScanTipTextLeft" .. i)
			local text = line and line:GetText()
			if text then
				text = strlower(text)
				local matched
				-- OctoWoW bonus lines like "Health +50" / "Mana +30"
				local _, _, hp = strfind(text, "^health %+(%d+)")
				local _, _, mana = strfind(text, "^mana %+(%d+)")
				if hp then e.health = (e.health or 0) + tonumber(hp) matched = true end
				if mana then e.mana = (e.mana or 0) + tonumber(mana) matched = true end
				-- only real effects count: "Equip:" lines (set bonuses you may not have are ignored)
				if not matched and strfind(text, "^chance on hit") then e.proc = 1 matched = true end
				if not matched and not strfind(text, "^equip:") then matched = true end
				for _, p in ipairs(matched and {} or EFFECTS) do
					local _, _, v = strfind(text, p[1])
					if v then
						v = tonumber(v)
						for k = 2, table.getn(p) do e[p[k]] = (e[p[k]] or 0) + v end
						matched = true
						break
					end
				end
			end
		end
		-- only remember a real read (an empty tooltip means "try again later")
		if scanner:NumLines() > 1 then effects_cache[id] = e end
	end
	return e
end

local MELEE_TYPES = { [13] = true, [17] = true, [21] = true }
local RANGED_TYPES = { [15] = true, [25] = true, [26] = true }

-- how good an item is for a role (higher is better)
function DC.Score(item, role)
	if not item then return 0 end
	local w = (role or DC.Role()).w
	local s = 0
	for k, v in pairs(item.stats) do s = s + (w[k] or 0) * v end
	s = s + (w.armor or 0) * item.armor
	local e = DC.Effects(item.id)
	for k, v in pairs(e) do
		if k == "schooldmg" then s = s + (w.spelldmg or 0) * v * .5
		elseif k == "health" then s = s + (w.sta or 0) * v / 10   -- 10 health = 1 stamina
		elseif k == "mana" then s = s + (w.int or 0) * v / 15     -- 15 mana = 1 intellect
		elseif k == "proc" then s = s + (w.dps and 4 or 0)
		else s = s + (w[k] or 0) * v end
	end
	if item.cls == 2 and item.speed > 0 then
		local dps = (item.dmin + item.dmax) / 2 / item.speed
		if MELEE_TYPES[item.invtype] then
			local scale = item.invtype == 17 and 1.6 or 1   -- a two-hander replaces main and off hand
			s = s + (w.dps or 0) * dps / scale + (w.slow or 0) * math.max(0, item.speed - 2)
		elseif RANGED_TYPES[item.invtype] then
			s = s + (w.rdps or 0) * dps
		end
	end
	return s
end

---------------------------------------------------------------------------- equipped gear

-- inventory slot -> name, and which inventory slots an item type goes into
DC.SLOTS = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [15] = "Back", [5] = "Chest", [9] = "Wrist", [10] = "Hands",
	[6] = "Waist", [7] = "Legs", [8] = "Feet", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket",
	[16] = "Main hand", [17] = "Off hand", [18] = "Ranged" }
DC.SLOT_ORDER = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }
local INVTYPE_SLOTS = { [1] = { 1 }, [2] = { 2 }, [3] = { 3 }, [5] = { 5 }, [20] = { 5 }, [6] = { 6 }, [7] = { 7 },
	[8] = { 8 }, [9] = { 9 }, [10] = { 10 }, [11] = { 11, 12 }, [12] = { 13, 14 }, [16] = { 15 }, [13] = { 16 },
	[21] = { 16 }, [17] = { 16 }, [14] = { 17 }, [22] = { 17 }, [23] = { 17 }, [15] = { 18 }, [25] = { 18 },
	[26] = { 18 }, [28] = { 18 } }
DC.INVTYPE_SLOTS = INVTYPE_SLOTS

function DC.Equipped(slot)
	local link = GetInventoryItemLink("player", slot)
	local id = item_id(link)
	return id, link
end

-- value of what you wear in an inventory slot (0 when empty or unknown)
local function slot_score(slot, role)
	local id = DC.Equipped(slot)
	return id and DC.Score(DC.Item(id), role) or 0
end
DC.SlotScore = slot_score

-- what an item would replace, and the value of that
function DC.CurrentFor(item, role)
	local slots = INVTYPE_SLOTS[item.invtype]
	if not slots then return 0 end
	if item.invtype == 17 then return slot_score(16, role) + slot_score(17, role) end
	if table.getn(slots) == 2 then
		return math.min(slot_score(slots[1], role), slot_score(slots[2], role))
	end
	return slot_score(slots[1], role)
end

---------------------------------------------------------------------------- upgrades

-- every usable item that beats what you wear, best gain first
-- opts: ahead = extra levels to look ahead, slot = only this inventory slot
function DC.Upgrades(opts)
	opts = opts or {}
	refresh_player()
	local role, level = DC.Role(), player.level + (opts.ahead or 0)
	local out, current_cache = {}, {}
	local ids = {}
	for id in pairs(DressCodeItems) do tinsert(ids, id) end
	for id, s in pairs(DressCodeDB and DressCodeDB.learned or {}) do
		if s ~= "x" and not DressCodeItems[id] then tinsert(ids, id) end
	end
	for _, id in ipairs(ids) do
		local item = DC.Item(id)
		if item and DC.CanUse(item, level) then
			local slots = INVTYPE_SLOTS[item.invtype]
			local wanted = not opts.slot
			if opts.slot and slots then
				for _, s in ipairs(slots) do if s == opts.slot then wanted = true end end
			end
			if wanted then
				local cur = current_cache[item.invtype]
				if not cur then cur = DC.CurrentFor(item, role) current_cache[item.invtype] = cur end
				local score = DC.Score(item, role)
				if score > cur + .5 then
					tinsert(out, { item = item, score = score, gain = score - cur })
				end
			end
		end
	end
	sort(out, function(a, b) return a.gain > b.gain end)
	-- one entry per item name (the cache can hold copies)
	local seen, unique = {}, {}
	for _, u in ipairs(out) do
		if not seen[u.item.name] then seen[u.item.name] = true tinsert(unique, u) end
		if table.getn(unique) >= 300 then break end
	end
	return unique
end

-- the best upgrade for one inventory slot
function DC.BestFor(slot, ahead)
	local list = DC.Upgrades({ slot = slot, ahead = ahead })
	return list[1]
end

---------------------------------------------------------------------------- sources

local src_cache = {}
function DC.Sources(id)
	if src_cache[id] then return src_cache[id] end
	local out = {}
	local item = DC.Item(id)
	if item and item.src ~= "" then
		for n in string.gfind(item.src, "(%d+)") do
			local name = DressCodeSources[tonumber(n)]
			if name then tinsert(out, name) end
		end
	end
	-- pfQuest: drops and vendors (live data, includes pfQuest-turtle)
	if pfDB and pfDB.items and pfDB.items.data and pfDB.items.data[id] then
		local d = pfDB.items.data[id]
		local units = pfDB.units and pfDB.units.loc
		local zones = pfDB.zones and pfDB.zones.loc
		local function where(uid)
			local u = pfDB.units.data and pfDB.units.data[uid]
			local c = u and u.coords and u.coords[1]
			return c and zones and zones[c[3]]
		end
		if d.V then
			for uid in pairs(d.V) do
				local zone = where(uid)
				tinsert(out, "Vendor: " .. (units and units[uid] or "?") .. (zone and (" (" .. zone .. ")") or ""))
				break
			end
		end
		if d.U then
			local best, chance
			for uid, c in pairs(d.U) do
				if not chance or c > chance then best, chance = uid, c end
			end
			if best then
				local zone = where(best)
				tinsert(out, "Drop: " .. (units and units[best] or "?") .. (zone and (" (" .. zone .. ")") or "")
					.. format(" %.1f%%", chance))
			end
		end
	end
	if table.getn(out) == 0 then tinsert(out, "Quest, crafted or world drop") end
	src_cache[id] = out
	return out
end

---------------------------------------------------------------------------- learning new items in game

-- items not in Data.lua get learned from GetItemInfo + their tooltip once the client has them,
-- and are kept in DressCodeDB.learned (so the data grows while you play)
local EQUIPLOC = { INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 20,
	INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11,
	INVTYPE_TRINKET = 12, INVTYPE_CLOAK = 16, INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14, INVTYPE_2HWEAPON = 17,
	INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22, INVTYPE_HOLDABLE = 23, INVTYPE_RANGED = 15,
	INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26, INVTYPE_RELIC = 28 }
local SUBCLASS = { Cloth = 1, Leather = 2, Mail = 3, Plate = 4, Shields = 6, Librams = 7, Idols = 8, Totems = 9,
	Miscellaneous = 0, ["One-Handed Axes"] = 0, ["Two-Handed Axes"] = 1, Bows = 2, Guns = 3, ["One-Handed Maces"] = 4,
	["Two-Handed Maces"] = 5, Polearms = 6, ["One-Handed Swords"] = 7, ["Two-Handed Swords"] = 8, Staves = 10,
	["Fist Weapons"] = 13, Daggers = 15, Thrown = 16, Crossbows = 18, Wands = 19 }
local STAT_WORDS = { Stamina = "sta", Intellect = "int", Spirit = "spi", Agility = "agi", Strength = "str" }

function DC.Known(id)
	return (DressCodeItems[id] or (DressCodeDB.learned and DressCodeDB.learned[id])) and true or false
end

-- returns true when the item is known now (learned or not equippable), false while still unknown
function DC.Learn(id)
	if DC.Known(id) then return true end
	local name, _, quality, minlevel, class, subclass, _, equiploc = GetItemInfo(id)
	if not name then return false end
	DressCodeDB.learned = DressCodeDB.learned or {}
	local invtype = EQUIPLOC[equiploc or ""]
	if not invtype then DressCodeDB.learned[id] = "x" return true end
	local st = { sta = 0, int = 0, spi = 0, agi = 0, str = 0 }
	local armor, dmin, dmax, speed = 0, 0, 0, 0
	scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
		scanner:ClearLines()
	scanner:SetHyperlink("item:" .. id .. ":0:0:0")
	for i = 2, scanner:NumLines() do
		local left = getglobal("DressCodeScanTipTextLeft" .. i)
		local right = getglobal("DressCodeScanTipTextRight" .. i)
		local l, r = left and left:GetText() or "", right and right:IsVisible() and right:GetText() or ""
		local _, _, v, word = strfind(l, "^%+(%d+) (%a+)$")
		if v and STAT_WORDS[word] then st[STAT_WORDS[word]] = st[STAT_WORDS[word]] + tonumber(v) end
		local _, _, a = strfind(l, "^(%d+) Armor$")
		if a then armor = tonumber(a) end
		local _, _, lo, hi = strfind(l, "^(%d+) %- (%d+)")
		if lo and dmax == 0 then dmin, dmax = tonumber(lo), tonumber(hi) end
		local _, _, sp = strfind(r, "Speed (%d+%.%d+)")
		if sp then speed = tonumber(sp) end
	end
	local cls = class == "Weapon" and 2 or 4
	local fields = { invtype, cls, SUBCLASS[subclass or ""] or 0, quality or 1, minlevel or 0, minlevel or 0, armor,
		dmin, dmax, math.floor(speed * 100 + .5), st.sta, st.int, st.spi, st.agi, st.str, -1, -1, "" }
	local parts = {}
	for k = 1, 18 do parts[k] = tostring(fields[k]) end
	DressCodeDB.learned[id] = table.concat(parts, ",") .. "," .. string.gsub(name, ",", " ")
	cache[id] = nil
	return true
end

-- ask the server about an item the client doesn't have yet (the answer arrives a moment later)
function DC.Request(id)
	if GetItemInfo(id) then return end
	scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
		scanner:ClearLines()
	scanner:SetHyperlink("item:" .. id .. ":0:0:0")
end

---------------------------------------------------------------------------- browse lists

function DC.BrowseCategories()
	local out = {}
	for i, c in ipairs(DressCodeBrowse or {}) do tinsert(out, { index = i, name = c[1], count = table.getn(c[2]) }) end
	return out
end

function DC.BrowseLists(cat)
	local out = {}
	local c = DressCodeBrowse[cat]
	for i, t in ipairs(c and c[2] or {}) do tinsert(out, { index = i, name = t[1] }) end
	return out
end

-- entries of one list: { id = item id (or made item for recipes), spell = recipe spell, icon, quality, name, extra }
function DC.BrowseItems(cat, list)
	local out = {}
	local t = DressCodeBrowse[cat] and DressCodeBrowse[cat][2][list]
	if not t then return out end
	for entry in string.gfind(t[2], "([^~]+)") do
		local _, _, id, icon, quality, name, extra = strfind(entry, "^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^?(.*)$")
		if id then
			local e = { icon = icon, quality = tonumber(quality) or 1, name = name, extra = extra }
			local _, _, spell, made = strfind(id, "^s(%d+)/(%d+)$")
			if spell then
				e.spell, e.id = tonumber(spell), tonumber(made)
				if e.id == 0 then e.id = nil end
			else
				e.id = tonumber(id)
			end
			tinsert(out, e)
		end
	end
	return out
end

---------------------------------------------------------------------------- dungeon quests (from Atlas-CFM)

local quest_cache = {}
-- quests that reward an item: { title, level, instance, faction, classes, giver, note }
function DC.Quests(id)
	if quest_cache[id] then return quest_cache[id] end
	local out = {}
	local list = DressCodeItemQuests and DressCodeItemQuests[id]
	if list then
		for n in string.gfind(list, "(%d+)") do
			local s = DressCodeQuests[tonumber(n)]
			if s then
				local _, _, title, level, minlevel, qid, inst, faction, classes, giver, note =
					strfind(s, "^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^?(.*)$")
				if title then
					tinsert(out, { title = title, level = tonumber(level) or 0, minlevel = tonumber(minlevel) or 0, id = tonumber(qid),
						instance = inst, faction = faction, classes = classes, giver = giver, note = note })
				end
			end
		end
	end
	-- quests learned in game on this PC (not in Data.lua yet): skip ones Data.lua already has
	for _, q in ipairs(DC.LearnedQuests and DC.LearnedQuests(id) or {}) do
		local dup
		for _, o in ipairs(out) do
			if strlower(o.title) == strlower(q.title) and (o.faction == "" or o.faction == q.faction) then dup = true end
		end
		if not dup then tinsert(out, q) end
	end
	quest_cache[id] = out
	return out
end

-- can this player do the quest? (faction and "<Class> ONLY" notes)
function DC.QuestForMe(q)
	local faction = UnitFactionGroup("player")
	if q.faction ~= "" and faction and q.faction ~= faction then return false end
	if q.classes ~= "" then
		local _, class = UnitClass("player")
		if not strfind(strupper(q.classes), class or "", 1, true) then return false end
	end
	return true
end

-- an item that only comes from quests this player can't do
function DC.QuestBlocked(item)
	local quests = DC.Quests(item.id)
	if table.getn(quests) == 0 then return false end
	for _, q in ipairs(quests) do
		if DC.QuestForMe(q) then return false end
	end
	-- other ways to get it? (AtlasLoot drop tables or pfQuest drops/vendors)
	for _, s in ipairs(DC.Sources(item.id)) do
		if not strfind(s, "^Quest") and s ~= "Quest, crafted or world drop" then return false end
	end
	return true
end

---------------------------------------------------------------------------- quests learned in game
-- When you open a quest at an NPC, finish one, or have it in your quest log, its reward items are
-- remembered: being offered the quest proves its rewards are within reach. Kept in
-- DressCodeDB.quests[key] = { t = title, l = quest level (0 = not known yet), i = { [item id] = true },
--   f = { Alliance = lowest player level it was seen at, Horde = ... }, c = class bits of the players who saw it,
--   g = quest giver, z = zone }
-- The Share button turns them into a code players paste for the addon's author (tools/dresscode_gen.py merges them).

local learned_index -- item id -> list of learned quests (DC.Quests format); rebuilt after something new is learned

local function clean_text(s)
	s = string.gsub(s or "", "[~%^|]", " ")
	s = string.gsub(s, "^%s+", "")
	return (string.gsub(s, "%s+$", ""))
end

-- a quest only heard from other players counts once two different players reported it
-- (learned yourself: r.heard is nil)
local MAX_NAMES = 3
local function trusted(r)
	if not r.heard then return true end
	local n = 0
	for _ in pairs(r.n or {}) do n = n + 1 end
	return n >= 2
end

function DC.LearnedQuests(id)
	if not learned_index then
		learned_index = {}
		for _, r in pairs(DressCodeDB and DressCodeDB.quests or {}) do
			for faction, seen in pairs(trusted(r) and r.f or {}) do
				local q = { title = r.t, level = r.l, minlevel = seen, instance = r.z or "", faction = faction, classes = "",
					giver = r.g or "", note = "Learned in game: seen from level " .. seen .. ".", learned = true }
				for item in pairs(r.i) do
					learned_index[item] = learned_index[item] or {}
					tinsert(learned_index[item], q)
				end
			end
		end
	end
	return learned_index[id]
end

-- remember a quest and its reward item ids; level = quest level (0 when the game doesn't say)
function DC.LearnQuest(title, level, items, giver, zone)
	if not DressCodeDB then return end
	-- quest log addons may put "[14] " in front of titles
	title = clean_text(string.gsub(title or "", "^%[[^%]]*%]%s*", ""))
	local faction = UnitFactionGroup("player")
	if title == "" or table.getn(items) == 0 or not faction then return end
	refresh_player()
	DressCodeDB.quests = DressCodeDB.quests or {}
	local db, key = DressCodeDB.quests, title
	level = level or 0
	local r = db[key]
	if r and r.l ~= 0 and level ~= 0 and r.l ~= level then
		-- another quest with the same title
		key = title .. "#" .. level
		r = db[key]
	end
	local changed
	if not r then r = { t = title, l = level, i = {}, f = {}, c = 0 } db[key] = r changed = true end
	if r.heard then r.heard = nil changed = true end -- seen with your own eyes now
	if r.l == 0 and level ~= 0 then r.l = level changed = true end
	for _, id in ipairs(items) do
		if not r.i[id] then r.i[id] = true changed = true end
		DC.Learn(id) -- the client has the item now: learn its stats if Data.lua doesn't have them
	end
	if not r.f[faction] or player.level < r.f[faction] then r.f[faction] = player.level changed = true end
	local bit = player.classbit
	if bit > 0 and math.mod(math.floor(r.c / bit), 2) == 0 then r.c = r.c + bit changed = true end
	giver, zone = clean_text(giver), clean_text(zone)
	if not r.g and giver ~= "" then r.g = giver changed = true end
	if not r.z and zone ~= "" then r.z = zone changed = true end
	if changed then
		learned_index = nil
		quest_cache = {} -- a new table: in Lua 5.0 a cleared table keeps its old length
	end
	return changed
end

-- one quest for one faction as text: faction^seen^level^classes^title^giver^zone^ids
local function entry_text(r, faction, short)
	local ids = {}
	for id in pairs(r.i) do tinsert(ids, id) end
	sort(ids)
	return strsub(faction, 1, 1) .. "^" .. r.f[faction] .. "^" .. r.l .. "^" .. r.c .. "^" .. r.t .. "^"
		.. (short and "" or (r.g or "")) .. "^" .. (short and "" or (r.z or "")) .. "^" .. table.concat(ids, ".")
end

-- share entries not shared yet (or all): { key, text }
function DC.ShareEntries(all)
	local out = {}
	if not DressCodeDB then return out end
	DressCodeDB.shared = DressCodeDB.shared or {}
	for key, r in pairs(DressCodeDB.quests or {}) do
		for faction in pairs(r.f) do
			local text = entry_text(r, faction)
			local skey = key .. "@" .. faction
			if all or DressCodeDB.shared[skey] ~= text then tinsert(out, { key = skey, text = text }) end
		end
	end
	sort(out, function(a, b) return a.key < b.key end)
	return out
end

function DC.MarkShared(entries)
	DressCodeDB.shared = DressCodeDB.shared or {}
	for _, e in ipairs(entries) do DressCodeDB.shared[e.key] = e.text end
end

---------------------------------------------------------------------------- spreading learned quests between players
-- Dress Code copies tell each other the quests they know over addon messages (battleground, raid,
-- party, guild): what one player learns reaches everyone they meet, and what those players know
-- reaches you. A quest heard from others counts once two different players reported it, and only
-- quests that count are passed on, so one player can't spread made-up data.
local SYNC_PREFIX = "RBXDC"
local SYNC_RATE = 1.5     -- seconds between two messages we send
local SYNC_MAX = 100      -- quests told per channel per visit (a battleground, a raid, a login)
local SYNC_START = 30     -- seconds after entering the world / joining a group before telling
local GROUP_RESET = 600   -- a changed group hears everything again at most every 10 minutes
local GUILD_RESET = 3600  -- the guild hears everything again at most every hour

local function add_bits(a, b) -- a OR b for the 1.12 class masks (no bit library in Lua 5.0)
	local bit = 1
	for _ = 1, 11 do
		if math.mod(math.floor(b / bit), 2) == 1 and math.mod(math.floor(a / bit), 2) == 0 then a = a + bit end
		bit = bit * 2
	end
	return a
end

-- a quest told by another player
function DC.HearQuest(text, sender)
	if not DressCodeDB or not sender then return end
	local _, _, fc, seen, level, classes, title, giver, zone, ids =
		strfind(text, "^([AH])%^(%d+)%^(%d+)%^(%d+)%^([^%^]+)%^([^%^]*)%^([^%^]*)%^([%d%.]+)$")
	if not fc then return end
	seen, level, classes = tonumber(seen), tonumber(level), tonumber(classes)
	title = clean_text(title)
	if title == "" or seen < 1 or seen > 60 or level > 63 then return end
	-- a pick-up level far below the quest's level is not believable
	if level > 0 and seen < level - 10 then return end
	local faction = fc == "A" and "Alliance" or "Horde"
	DressCodeDB.quests = DressCodeDB.quests or {}
	local db, key = DressCodeDB.quests, title
	local r = db[key]
	if r and r.l ~= 0 and level ~= 0 and r.l ~= level then key = title .. "#" .. level r = db[key] end
	local changed, was_trusted
	if not r then r = { t = title, l = level, i = {}, f = {}, c = 0, heard = true, n = {} } db[key] = r changed = true end
	was_trusted = trusted(r)
	if r.heard then
		r.n = r.n or {}
		local count = 0
		for _ in pairs(r.n) do count = count + 1 end
		if not r.n[sender] and count < MAX_NAMES then r.n[sender] = true changed = true end
	end
	if r.l == 0 and level ~= 0 then r.l = level changed = true end
	for id in string.gfind(ids, "(%d+)") do
		id = tonumber(id)
		if not r.i[id] then r.i[id] = true changed = true end
	end
	if not r.f[faction] or seen < r.f[faction] then r.f[faction] = seen changed = true end
	local c = add_bits(r.c, classes)
	if c ~= r.c then r.c = c changed = true end
	giver, zone = clean_text(giver), clean_text(zone)
	if not r.g and giver ~= "" then r.g = giver changed = true end
	if not r.z and zone ~= "" then r.z = zone changed = true end
	if changed and (was_trusted or trusted(r)) then
		learned_index = nil
		quest_cache = {}
	end
	return key, faction
end

local sync = CreateFrame("Frame")
sync.told = {}     -- channel -> { ["key@faction"] = text told or heard there }
sync.count = {}    -- channel -> quests told this visit
sync.reset_at = {} -- channel -> when it last started a new visit
sync.start_at = nil

local function sync_channels()
	local out = {}
	local bg
	for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
		if GetBattlefieldStatus(i) == "active" then bg = true end
	end
	if bg then
		tinsert(out, "BATTLEGROUND") -- the whole team (the raid group is part of it)
	elseif GetNumRaidMembers() > 0 then
		tinsert(out, "RAID")
	elseif GetNumPartyMembers() > 0 then
		tinsert(out, "PARTY")
	end
	if IsInGuild() then tinsert(out, "GUILD") end
	return out
end

-- start a new visit on a channel: everything may be told there again
local function new_visit(channel, min_gap)
	local last = sync.reset_at[channel]
	if last and GetTime() - last < min_gap then return end
	sync.reset_at[channel] = GetTime()
	sync.told[channel] = {}
	sync.count[channel] = 0
end

-- the next quest this channel hasn't heard (told by us or by someone else) this visit
local function next_entry(channel)
	local told = sync.told[channel]
	for key, r in pairs(DressCodeDB and DressCodeDB.quests or {}) do
		if trusted(r) then
			for faction in pairs(r.f) do
				local skey = key .. "@" .. faction
				local text = entry_text(r, faction)
				if strlen(text) > 230 then text = entry_text(r, faction, true) end -- without giver and zone
				if told[skey] ~= text and strlen(text) <= 230 then return skey, text end
			end
		end
	end
end

sync:RegisterEvent("PLAYER_ENTERING_WORLD")
sync:RegisterEvent("PARTY_MEMBERS_CHANGED")
sync:RegisterEvent("RAID_ROSTER_UPDATE")
sync:RegisterEvent("PLAYER_GUILD_UPDATE")
sync:RegisterEvent("CHAT_MSG_ADDON")
sync:SetScript("OnEvent", function()
	if event == "CHAT_MSG_ADDON" then
		if arg1 ~= SYNC_PREFIX or arg4 == UnitName("player") then return end
		local _, _, text = strfind(arg2 or "", "^1:(.+)$")
		if not text then return end
		local key, faction = DC.HearQuest(text, arg4)
		-- the channel has heard this one now: don't tell it again unless ours is different
		if key and sync.told[arg3] then
			local r = DressCodeDB.quests[key]
			if entry_text(r, faction) == text or entry_text(r, faction, true) == text then
				sync.told[arg3][key .. "@" .. faction] = text
			end
		end
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		-- a new battleground / instance / login: new people to tell
		new_visit("BATTLEGROUND", 0) new_visit("RAID", 0) new_visit("PARTY", 0)
		new_visit("GUILD", GUILD_RESET)
	else
		new_visit("RAID", GROUP_RESET) new_visit("PARTY", GROUP_RESET)
		if event == "PLAYER_GUILD_UPDATE" then new_visit("GUILD", GUILD_RESET) end
	end
	local t = GetTime() + SYNC_START
	if not sync.start_at or sync.start_at < GetTime() then sync.start_at = t end
end)

local sync_elapsed = 0
sync:SetScript("OnUpdate", function()
	sync_elapsed = sync_elapsed + arg1
	if sync_elapsed < SYNC_RATE then return end
	sync_elapsed = 0
	if not sync.start_at or GetTime() < sync.start_at or not DressCodeDB then return end
	-- one message per tick, taking turns between the channels
	local list = sync_channels()
	local n = table.getn(list)
	for k = 1, n do
		sync.turn = math.mod(sync.turn or 0, n) + 1
		local channel = list[sync.turn]
		if not sync.told[channel] then new_visit(channel, 0) end
		if sync.count[channel] < SYNC_MAX then
			local skey, text = next_entry(channel)
			if skey then
				SendAddonMessage(SYNC_PREFIX, "1:" .. text, channel)
				sync.told[channel][skey] = text
				sync.count[channel] = sync.count[channel] + 1
				return
			end
		end
	end
end)

-- reading quests: the quest window (offered / turn-in) and the quest log
local function frame_rewards()
	local items = {}
	for i = 1, GetNumQuestRewards() do
		local id = item_id(GetQuestItemLink("reward", i))
		if id then tinsert(items, id) end
	end
	for i = 1, GetNumQuestChoices() do
		local id = item_id(GetQuestItemLink("choice", i))
		if id then tinsert(items, id) end
	end
	return items
end

local scanning_log
local function scan_log()
	if scanning_log or not DressCodeDB then return end
	scanning_log = true
	local selected = GetQuestLogSelection()
	for i = 1, GetNumQuestLogEntries() do
		local title, level, _, header = GetQuestLogTitle(i)
		if title and not header then
			SelectQuestLogEntry(i)
			local items = {}
			for j = 1, GetNumQuestLogRewards() do
				local id = item_id(GetQuestLogItemLink("reward", j))
				if id then tinsert(items, id) end
			end
			for j = 1, GetNumQuestLogChoices() do
				local id = item_id(GetQuestLogItemLink("choice", j))
				if id then tinsert(items, id) end
			end
			DC.LearnQuest(title, level, items)
		end
	end
	-- give the quest log back its own selection
	SelectQuestLogEntry(selected or 0)
	scanning_log = nil
end

local quest_events = CreateFrame("Frame")
quest_events:RegisterEvent("QUEST_DETAIL")
quest_events:RegisterEvent("QUEST_COMPLETE")
quest_events:RegisterEvent("QUEST_LOG_UPDATE")
quest_events:SetScript("OnEvent", function()
	if event == "QUEST_LOG_UPDATE" then
		-- the log changes often: read it at most every 5 seconds, a moment after the change
		if not scanning_log and not this.log_at then this.log_at = math.max(GetTime() + 1, this.next_log or 0) end
		return
	end
	-- offered (QUEST_DETAIL) or being turned in (QUEST_COMPLETE): no quest level in 1.12's quest window;
	-- the NPC is the quest giver only when the quest is offered
	DC.LearnQuest(GetTitleText(), 0, frame_rewards(), event == "QUEST_DETAIL" and UnitName("npc") or nil, GetZoneText())
end)
quest_events:SetScript("OnUpdate", function()
	if this.log_at and GetTime() >= this.log_at then
		this.log_at, this.next_log = nil, GetTime() + 5
		scan_log()
	end
end)

---------------------------------------------------------------------------- stat search (replaces roles and points)

DC.STATS = {
	{ key = "str", label = "Strength", short = "Str" },
	{ key = "agi", label = "Agility", short = "Agi" },
	{ key = "sta", label = "Stamina", short = "Sta" },
	{ key = "int", label = "Intellect", short = "Int" },
	{ key = "spi", label = "Spirit", short = "Spi" },
	{ key = "armor", label = "Armor", short = "Armor" },
	{ key = "spelldmg", label = "Spell damage", short = "SpDmg" },
	{ key = "heal", label = "Healing", short = "Heal" },
	{ key = "spellcrit", label = "Spell crit", short = "SpCrit" },
	{ key = "spellhit", label = "Spell hit", short = "SpHit" },
	{ key = "crit", label = "Crit", short = "Crit" },
	{ key = "hit", label = "Hit", short = "Hit" },
	{ key = "ap", label = "Attack power", short = "AP" },
	{ key = "mp5", label = "Mana / 5 sec", short = "Mp5" },
	{ key = "defense", label = "Defense", short = "Def" },
	{ key = "dodge", label = "Dodge", short = "Dodge" },
	{ key = "dps", label = "Weapon DPS", short = "DPS" },
	{ key = "health", label = "Health", short = "HP" },
}

-- every searchable number of an item
function DC.Vector(item)
	local v = {}
	if not item then return v end
	for k, n in pairs(item.stats) do if n ~= 0 then v[k] = n end end
	if item.armor > 0 then v.armor = item.armor end
	if item.cls == 2 and item.speed > 0 and item.dmax > 0 then
		v.dps = math.floor((item.dmin + item.dmax) / 2 / item.speed * 10 + .5) / 10
	end
	for k, n in pairs(DC.Effects(item.id)) do
		if k == "rap" then k = "ap" end
		if k ~= "proc" and k ~= "schooldmg" then v[k] = (v[k] or 0) + n end
	end
	return v
end

local function vector_of_slot(slot)
	local id = DC.Equipped(slot)
	if not id then return {} end
	if not DC.Item(id) then DC.Learn(id) end
	return DC.Vector(DC.Item(id))
end

local function sum_keys(v, keys)
	local s = 0
	for k in pairs(keys) do s = s + (v[k] or 0) end
	return s
end

-- what an item would be compared against: the slot's item, the weaker ring/trinket, main + off hand for a two-hander
function DC.CurrentVector(item, keys)
	local slots = DC.INVTYPE_SLOTS[item.invtype]
	if not slots then return {} end
	if item.invtype == 17 then
		local a, b, v = vector_of_slot(16), vector_of_slot(17), {}
		for k, n in pairs(a) do v[k] = n end
		for k, n in pairs(b) do if k ~= "dps" then v[k] = (v[k] or 0) + n end end
		return v
	end
	if table.getn(slots) == 2 then
		local a, b = vector_of_slot(slots[1]), vector_of_slot(slots[2])
		if sum_keys(a, keys) <= sum_keys(b, keys) then return a end
		return b
	end
	return vector_of_slot(slots[1])
end

-- whole tooltip text of an item, lower case (for the text search); only for items the client has
local text_cache = {}
function DC.Text(id)
	if text_cache[id] then return text_cache[id] end
	if not GetItemInfo(id) then return nil end
	scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
		scanner:ClearLines()
	scanner:SetHyperlink("item:" .. id .. ":0:0:0")
	local parts = {}
	for i = 1, scanner:NumLines() do
		local left = getglobal("DressCodeScanTipTextLeft" .. i)
		local right = getglobal("DressCodeScanTipTextRight" .. i)
		if left and left:GetText() then tinsert(parts, left:GetText()) end
		if right and right:IsVisible() and right:GetText() then tinsert(parts, right:GetText()) end
	end
	local text = strlower(table.concat(parts, " "))
	if scanner:NumLines() > 1 then text_cache[id] = text end
	return text
end

-- does an item beat what you wear? every ticked stat at least as high, at least one higher.
-- returns the gains table (or nil when it doesn't qualify)
function DC.Compare(item, keys, search)
	local vec = DC.Vector(item)
	local cur = DC.CurrentVector(item, keys)
	local gains, better, any = {}, false, false
	for k in pairs(keys) do
		any = true
		local a, b = vec[k] or 0, cur[k] or 0
		if a < b then return nil end
		if a > b then better = true gains[k] = a - b end
	end
	if search and search ~= "" then
		local text = DC.Text(item.id)
		if not text or not strfind(text, search, 1, true) then return nil end
		better = true
	end
	if not any and not (search and search ~= "") then return nil end
	if not better then return nil end
	return gains
end

-- readable summary of gains in the order of DC.STATS, e.g. "+4 Sta +2 Int"
function DC.GainText(gains)
	local parts = {}
	for _, s in ipairs(DC.STATS) do
		local g = gains[s.key]
		if g then
			local n = (math.floor(g) == g) and format("%d", g) or format("%.1f", g)
			tinsert(parts, "+" .. n .. " " .. s.short)
		end
	end
	return table.concat(parts, " ")
end

-- the search: usable items for a slot (or all slots) that beat what you wear
-- opts: slot, keys = { str = true, ... }, search = lower case text, ahead = levels
function DC.Find(opts)
	refresh_player()
	local level = player.level + (opts.ahead or 0)
	local out, seen = {}, {}
	local ids = {}
	for id in pairs(DressCodeItems) do tinsert(ids, id) end
	for id, s in pairs(DressCodeDB and DressCodeDB.learned or {}) do
		if s ~= "x" and not DressCodeItems[id] then tinsert(ids, id) end
	end
	for _, id in ipairs(ids) do
		local item = DC.Item(id)
		if item and not seen[item.name] and DC.CanUse(item, level) then
			local slots = DC.INVTYPE_SLOTS[item.invtype]
			local wanted = not opts.slot
			for _, s in ipairs(slots or {}) do if s == opts.slot then wanted = true end end
			if wanted then
				local gains = DC.Compare(item, opts.keys, opts.search)
				if gains then
					seen[item.name] = true
					local total = 0
					for _, g in pairs(gains) do total = total + g end
					tinsert(out, { item = item, gains = gains, total = total })
				end
			end
		end
	end
	sort(out, function(a, b)
		if a.total ~= b.total then return a.total > b.total end
		return a.item.ilvl > b.item.ilvl
	end)
	local limited = {}
	for i = 1, math.min(300, table.getn(out)) do limited[i] = out[i] end
	return limited, table.getn(out)
end

-- "L19", "L15, quest" or "any level" for the item lists
function DC.LevelText(item)
	local need, why = DC.ReqLevel(item)
	if need == 0 then return "any level" end
	return "L" .. need .. (why and (", " .. why) or "")
end
