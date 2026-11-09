-- Buff Watch: big reminders like "SHIELD OFF" when one of your own buffs (or your weapon enchant /
-- poison) is missing, so you never forget to rebuff. Every class gets sensible defaults; only
-- spells you have learned are watched. Drag the text where you want it (/buffwatch move).
local db
local function Print(msg) print("|cff33ff99Buff Watch:|r " .. msg) end

-- spells = any of these counts as "on"; weapon = main-hand enchant (shaman weapons, rogue poisons)
local CLASS_DEFAULTS = {
	SHAMAN = {
		{ spells = { "Lightning Shield", "Water Shield", "Earth Shield" }, text = "SHIELD OFF" },
		{ weapon = true, needs = { "Rockbiter Weapon", "Flametongue Weapon", "Frostbrand Weapon", "Windfury Weapon" }, text = "WEAPON OFF" },
	},
	MAGE = {
		{ spells = { "Arcane Intellect", "Arcane Brilliance" }, text = "INTELLECT OFF" },
		{ spells = { "Frost Armor", "Ice Armor", "Mage Armor", "Molten Armor" }, text = "ARMOR OFF" },
	},
	PRIEST = {
		{ spells = { "Power Word: Fortitude", "Prayer of Fortitude" }, text = "FORTITUDE OFF" },
		{ spells = { "Inner Fire" }, text = "INNER FIRE OFF" },
	},
	WARRIOR = { { spells = { "Battle Shout" }, text = "SHOUT OFF" } },
	DRUID = {
		{ spells = { "Mark of the Wild", "Gift of the Wild" }, text = "MARK OFF" },
		{ spells = { "Thorns" }, text = "THORNS OFF" },
	},
	WARLOCK = { { spells = { "Demon Skin", "Demon Armor", "Fel Armor" }, text = "ARMOR OFF" } },
	HUNTER = {
		{ spells = { "Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Cheetah", "Aspect of the Pack",
			"Aspect of the Wild", "Aspect of the Beast", "Aspect of the Viper" }, text = "ASPECT OFF" },
	},
	PALADIN = {
		{ spells = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Salvation",
			"Blessing of Light", "Blessing of Sanctuary", "Greater Blessing of Might", "Greater Blessing of Wisdom",
			"Greater Blessing of Kings" }, text = "BLESSING OFF" },
		{ spells = { "Devotion Aura", "Retribution Aura", "Concentration Aura", "Shadow Resistance Aura",
			"Frost Resistance Aura", "Fire Resistance Aura", "Sanctity Aura" }, text = "AURA OFF" },
	},
	ROGUE = { { weapon = true, minLevel = 20, text = "POISON OFF" } },
}

---------------------------------------------------------------------------- checks
-- learned = in your spellbook (so a level-1 priest isn't nagged about Inner Fire)
local function Knows(name)
	if C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell then
		local ok, slot = pcall(C_SpellBook.FindSpellBookSlotForSpell, name)
		if ok then return slot ~= nil end
	end
	if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(name) ~= nil end
	return GetSpellInfo and GetSpellInfo(name) ~= nil
end

local function KnowsAny(list)
	for _, n in ipairs(list or {}) do if Knows(n) then return true end end
	return false
end

-- Three ways to ask the game; returns true (have it), false (don't) or nil (the game won't say -
-- then the reminder stays hidden rather than nagging wrongly).
local function ByName(n)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return nil end
	local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", n, "HELPFUL")
	if not ok then return nil end
	return aura ~= nil
end

local function ByList(n)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
	local ok, found = pcall(function()
		for i = 1, 40 do
			local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
			if not a then return false end
			if a.name == n then return true end
		end
		return false
	end)
	if not ok then return nil end
	return found
end

local function BySpellID(n)
	if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and C_Spell and C_Spell.GetSpellInfo) then return nil end
	local info = C_Spell.GetSpellInfo(n)
	if not (info and info.spellID) then return nil end
	local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, info.spellID)
	if not ok then return nil end
	return aura ~= nil
end

-- true as soon as any check finds the buff; false if at least one check clearly says "not there";
-- nil only when every check stayed silent (then the reminder stays hidden).
-- Spells you haven't learned are skipped (e.g. Water Shield for a young shaman).
local function HasBuff(w)
	local answered = false
	for _, n in ipairs(w.spells) do
		if Knows(n) then
			for _, ask in ipairs({ ByName, ByList, BySpellID }) do
				local r = ask(n)
				if r == true then return true end
				if r == false then answered = true end
			end
		end
	end
	if answered then return false end
	return nil
end

local function HasWeaponEnchant()
	local hasMain = GetWeaponEnchantInfo()
	return hasMain and true or false
end

local function Relevant(w)
	if w.off then return false end
	if w.minLevel and UnitLevel("player") < w.minLevel then return false end
	if w.weapon then
		if not GetInventoryItemID("player", 16) then return false end -- no main-hand weapon
		return not w.needs or KnowsAny(w.needs)
	end
	return KnowsAny(w.spells)
end

local function ShouldShowNow()
	if UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then return false end
	if db.when == "combat" then return UnitAffectingCombat("player") end
	if db.when == "rest" then return not UnitAffectingCombat("player") end
	return true
end

---------------------------------------------------------------------------- display
local frame = CreateFrame("Frame", "BuffWatchFrame", UIParent, "BackdropTemplate")
frame:SetSize(300, 40)
frame:SetMovable(true); frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) if db.unlocked then self:StartMoving() end end)
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local p, _, rp, x, y = self:GetPoint(1)
	db.pos = { p, rp, x, y }
end)
local lines = {}

local function Line(i)
	if not lines[i] then
		local fs = frame:CreateFontString(nil, "OVERLAY")
		lines[i] = fs
	end
	local fs = lines[i]
	fs:SetFont(STANDARD_TEXT_FONT, db.size, "THICKOUTLINE")
	fs:ClearAllPoints()
	fs:SetPoint("TOP", frame, "TOP", 0, -(i - 1) * (db.size + 4))
	local c = db.color
	fs:SetTextColor(c[1], c[2], c[3])
	return fs
end

local function Place()
	frame:ClearAllPoints()
	local p = db.pos
	if p then frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else frame:SetPoint("CENTER", UIParent, "CENTER", 0, 160) end
end

-- When a buff goes missing its reminder pops up, stays db.showSecs seconds, then fades out over
-- FADE seconds. It comes back when the buff drops off again, or after db.repeatMins (0 = never).
-- db.showSecs = 0 means "stay until rebuffed".
local FADE = 1.5      -- fade after the reminder's time is up
local FADE_FIXED = 0.5 -- quick fade when you rebuff
local since = {}  -- [watch index] = GetTime() when its reminder started
local fixedAt = {} -- [watch index] = GetTime() when the buff came back (reminder fading out)
-- [watch] = true once that buff has been on you this session (since login or /reload). Until then
-- its reminder stays quiet, so logging in without the buff doesn't nag.
local seen = {}

local function AlphaFor(i)
	local a = 1
	if db.showSecs ~= 0 then
		local age = GetTime() - since[i]
		if age >= db.showSecs then a = math.max(0, 1 - (age - db.showSecs) / FADE) end
	end
	if fixedAt[i] then a = math.min(a, math.max(0, 1 - (GetTime() - fixedAt[i]) / FADE_FIXED)) end
	return a
end

local Render
local function Update()
	if not db then return end
	local active = ShouldShowNow()
	for i, w in ipairs(db.watches) do
		local missing = false
		if active and Relevant(w) then
			local has
			if w.weapon then has = HasWeaponEnchant() else has = HasBuff(w) end
			if has == true then seen[w] = true end
			missing = (has == false) and seen[w] -- nil = the game won't say: stay quiet
		end
		if missing then
			fixedAt[i] = nil
			local repeatAfter = (db.repeatMins or 0) * 60
			if not since[i] or (repeatAfter > 0 and GetTime() - since[i] > repeatAfter) then since[i] = GetTime() end
		elseif since[i] then
			-- rebuffed (or not relevant right now): fade out in half a second if it's still on screen,
			-- then forget it so the next drop reminds again
			if AlphaFor(i) > 0 then
				fixedAt[i] = fixedAt[i] or GetTime()
			end
			if AlphaFor(i) <= 0 then since[i], fixedAt[i] = nil, nil end
		end
	end
	Render()
end

Render = function()
	local shown = {}
	if db.unlocked then
		shown[1] = { "BUFF WATCH (drag me)", 1 }
	else
		for i, w in ipairs(db.watches) do
			if since[i] then
				local a = AlphaFor(i)
				if a > 0 then shown[#shown + 1] = { w.text, a }
				elseif fixedAt[i] then since[i], fixedAt[i] = nil, nil end -- rebuff fade done: ready for the next drop
			end
		end
	end
	local visible = false
	for i, s in ipairs(shown) do
		local fs = Line(i); fs:SetText(s[1]); fs:SetAlpha(s[2]); fs:Show()
		if not db.unlocked then visible = true end
	end
	for i = #shown + 1, #lines do lines[i]:Hide() end
	frame:SetSize(300, math.max(1, #shown) * (db.size + 4))
	frame:EnableMouse(db.unlocked and true or false)
	if db.unlocked then
		frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
		frame:SetBackdropColor(0, 0, 0, 0.5)
	else
		frame:SetBackdrop(nil)
	end
	frame:SetShown(#shown > 0)
	-- While a reminder is on screen: redraw every frame (for the fade) and check the buff 4 times a
	-- second, so it vanishes the moment you rebuff. Nothing runs while nothing is shown.
	if visible then
		if not frame:GetScript("OnUpdate") then frame:SetScript("OnUpdate", frame.Tick) end
	else
		frame:SetScript("OnUpdate", nil)
	end
end

local tickElapsed = 0
frame.Tick = function(_, dt)
	tickElapsed = tickElapsed + dt
	if tickElapsed >= 0.25 then tickElapsed = 0; Update() else Render() end
end

---------------------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= "BuffWatch_Raccoonbox" then return end
		BuffWatchDB = BuffWatchDB or {}
		db = BuffWatchDB
		db.size = db.size or 28
		db.color = db.color or { 1, 0.2, 0.2 }
		db.when = db.when or "always"
		if db.showSecs == nil then db.showSecs = 5 end
		if db.repeatMins == nil then db.repeatMins = 0 end
		if not db.watches then
			db.watches = {}
			for _, w in ipairs(CLASS_DEFAULTS[select(2, UnitClass("player"))] or {}) do
				local copy = {}
				for k, v in pairs(w) do copy[k] = v end
				db.watches[#db.watches + 1] = copy
			end
		end
		for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UNIT_AURA", "UNIT_INVENTORY_CHANGED", "SPELLS_CHANGED",
			"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_DEAD",
			"PLAYER_LEVEL_UP", "PLAYER_CONTROL_GAINED", "UNIT_SPELLCAST_SUCCEEDED" }) do pcall(self.RegisterEvent, self, e) end
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then Place() end
	if (event == "UNIT_AURA" or event == "UNIT_INVENTORY_CHANGED" or event == "UNIT_SPELLCAST_SUCCEEDED")
		and arg1 ~= "player" then return end
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		-- you just cast something (maybe the missing buff): check now and again a moment later
		Update(); C_Timer.After(0.2, Update) return
	end
	Update()
end)
-- weapon enchants run out on a timer without an event; check every 2 seconds
C_Timer.NewTicker(2, function() if db then Update() end end)

---------------------------------------------------------------------------- slash
local function FindWatch(name)
	name = name:lower()
	for i, w in ipairs(db.watches) do
		if (w.text or ""):lower() == name then return i end
		for _, s in ipairs(w.spells or {}) do if s:lower() == name then return i end end
	end
end

SLASH_BUFFWATCH1 = "/buffwatch"
SLASH_BUFFWATCH2 = "/bwatch"
SlashCmdList.BUFFWATCH = function(msg)
	msg = msg or ""
	local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	if cmd == "move" then
		db.unlocked = not db.unlocked
		Print(db.unlocked and "drag the text where you want it, then /buffwatch move again to lock it." or "locked.")
		Update()
	elseif cmd == "add" then
		local spell, text = rest:match("^(.-)%s*=%s*(.+)$")
		spell = spell or rest
		if spell == "" then Print("usage: /buffwatch add Spell Name = TEXT   e.g. /buffwatch add Inner Fire = FIRE OFF") return end
		db.watches[#db.watches + 1] = { spells = { spell }, text = text or (spell:upper() .. " OFF") }
		Print("watching " .. spell .. ".")
		Update()
	elseif cmd == "weapon" then
		db.watches[#db.watches + 1] = { weapon = true, text = rest ~= "" and rest or "WEAPON OFF" }
		Print("watching your main-hand weapon enchant.")
		Update()
	elseif cmd == "remove" then
		local i = FindWatch(rest)
		if not i then Print("not found. /buffwatch list shows what's watched.") return end
		table.remove(db.watches, i); Print("removed."); Update()
	elseif cmd == "list" then
		for _, w in ipairs(db.watches) do
			print("   " .. (w.off and "|cff999999(off)|r " or "") .. "|cffffd100" .. w.text .. "|r  "
				.. (w.weapon and "weapon enchant" or table.concat(w.spells, " / ")))
		end
	elseif cmd == "debug" then
		local function s(v) return v == nil and "|cffffcc00no answer|r" or (v and "|cff33ff33yes|r" or "|cffff4040no|r") end
		Print("what the game says (in combat: " .. tostring(UnitAffectingCombat("player")) .. "):")
		for _, w in ipairs(db.watches) do
			if w.weapon then
				print("   " .. w.text .. ": weapon enchant " .. s(HasWeaponEnchant()))
			else
				for _, n in ipairs(w.spells) do
					if Knows(n) then
						print(("   %s: by name %s, by list %s, by spell ID %s"):format(n, s(ByName(n)), s(ByList(n)), s(BySpellID(n))))
					end
				end
			end
		end
	elseif cmd == "reset" then
		db.watches = nil; Print("back to the defaults for your class after /reload.")
	else
		Print("/buffwatch move | list | add Spell = TEXT | weapon [TEXT] | remove <spell or text> | reset")
	end
end

---------------------------------------------------------------------------- options page
if RaccoonboxOptions then
	RaccoonboxOptions.AddPanel({
		name = "Buff Watch",
		about = "Shows a big reminder, like SHIELD OFF, when one of your own buffs or your weapon enchant/poison "
			.. "drops off (only once you've had it on this session, so logging in without it is quiet). It stays a few seconds and fades away, and comes back the next time the buff drops (or "
			.. "after the minutes you choose). Comes with the usual buffs for your class; only spells you know are "
			.. "watched. Drag the reminder anywhere with \"Move the reminder\".",
		commands = {
			{ "/buffwatch list", "show what is watched" },
			{ "/buffwatch add Inner Fire = FIRE OFF", "watch another buff with your own text" },
			{ "/buffwatch weapon WEAPON OFF", "watch your main-hand weapon enchant" },
			{ "/buffwatch remove SHIELD OFF", "stop watching something (spell name or its text)" },
			{ "/buffwatch reset", "back to the defaults for your class" },
		},
		build = function(b)
			b:Buttons({ { "Move the reminder", function() SlashCmdList.BUFFWATCH("move") end } })
			b:Choice("Show reminders:", { { "always", "Always" }, { "combat", "Only in combat" }, { "rest", "Only out of combat" } },
				function() return db and db.when end, function(v) db.when = v; Update() end)
			b:Stepper("Show each reminder for (0 = until rebuffed):", 0, 60, 1,
				function() return db and db.showSecs end, function(v) db.showSecs = v; Update() end, " s")
			b:Stepper("Remind again after (0 = never):", 0, 30, 1,
				function() return db and db.repeatMins end, function(v) db.repeatMins = v; Update() end, " min")
			b:Stepper("Text size:", 14, 60, 2, function() return db and db.size end,
				function(v) db.size = v; Update() end)
			b:Choice("Colour:", { { "red", "Red" }, { "yellow", "Yellow" }, { "white", "White" } },
				function()
					local c = db and db.color or {}
					if c[2] == 0.2 then return "red" elseif c[3] == 0 then return "yellow" else return "white" end
				end,
				function(v)
					db.color = (v == "red" and { 1, 0.2, 0.2 }) or (v == "yellow" and { 1, 0.85, 0 }) or { 1, 1, 1 }
					Update()
				end)
			b:Header("Watched")
			for _, w in ipairs(db and db.watches or {}) do
				b:Check(w.text .. "  |cff999999(" .. (w.weapon and "weapon enchant" or table.concat(w.spells, " / ")) .. ")|r", nil,
					function() return not w.off end, function(v) w.off = not v; Update() end)
			end
		end,
	})
end
