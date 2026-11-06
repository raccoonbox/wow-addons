-- Valor Plates: lifts enemy nameplates higher above the mob, leaving room for your damage
-- numbers (which the game draws at head height and an addon can't move on Forever).
local db
local function Print(msg) print("|cff33ff99Valor Plates:|r " .. msg) end

local function Lift(unit)
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	local uf = plate and plate.UnitFrame
	if not uf or (uf.IsForbidden and uf:IsForbidden()) then return end
	local up = (UnitCanAttack("player", unit) and db.enabled) and db.lift or 0
	uf:ClearAllPoints()
	uf:SetPoint("TOPLEFT", plate, "TOPLEFT", 0, up)
	uf:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", 0, up)
end

-- Health/mana numbers on unit frames (yours, target, party) - uses the game's own settings.
local TEXT_MODES = {
	numeric = { on = "1", display = "NUMERIC", label = "current / max (always shown)" },
	percent = { on = "1", display = "PERCENT", label = "percent (always shown)" },
	both    = { on = "1", display = "BOTH",    label = "percent and number (always shown)" },
	hover   = { on = "0", display = "NUMERIC", label = "only when you hover the bar" },
}

local function ApplyBarText(mode)
	local m = TEXT_MODES[mode]
	if not m then return end
	SetCVar("statusText", m.on)
	SetCVar("statusTextDisplay", m.display)
end

local function LiftAll()
	for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
		local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if unit then Lift(unit) end
	end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, arg)
	if event == "ADDON_LOADED" then
		if arg ~= "ValorPlates" then return end
		ValorPlatesDB = ValorPlatesDB or {}
		db = ValorPlatesDB
		if db.lift == nil then db.lift = 40 end
		if db.enabled == nil then db.enabled = true end
		self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
		self:RegisterEvent("PLAYER_LOGIN")
		return
	end
	if event == "PLAYER_LOGIN" then
		if db.text then ApplyBarText(db.text) end -- keep the player's choice even if something reset it
		return
	end
	-- NAME_PLATE_UNIT_ADDED: run right after Blizzard has set the plate up
	C_Timer.After(0, function() if UnitExists(arg) then Lift(arg) end end)
end)

SLASH_VALORPLATES1 = "/vplates"
SlashCmdList.VALORPLATES = function(msg)
	local cmd, n = (msg or ""):lower():match("^(%S*)%s*(%S*)$")
	if cmd == "text" then
		if not TEXT_MODES[n] then
			Print("/vplates text numeric | percent | both | hover  (now: " .. (db.text or "game default") .. ")")
			return
		end
		db.text = n
		ApplyBarText(n)
		Print("health/mana bar text: " .. TEXT_MODES[n].label .. ".")
	elseif cmd == "lift" and tonumber(n) then
		db.lift = tonumber(n); db.enabled = true; LiftAll()
		Print("enemy plates lifted by " .. db.lift .. " pixels.")
	elseif cmd == "off" or cmd == "on" then
		db.enabled = (cmd == "on"); LiftAll()
		Print("lift " .. (db.enabled and "on" or "off") .. ".")
	else
		Print("/vplates text numeric|percent|both|hover - health/mana numbers on your and your target's bars")
		Print("/vplates lift <pixels> (now " .. db.lift .. "), /vplates on, /vplates off - enemy nameplate height")
	end
end

---------------------------------------------------------------------------- options page
if RaccoonboxOptions then
	RaccoonboxOptions.AddPanel({
		name = "Valor Plates",
		about = "Nameplate tweaks. Lifts enemy nameplates higher above the mob so your damage numbers show below the "
			.. "plate instead of behind it. Health/mana numbers on your bars are on the main Raccoonbox page.",
		commands = {
			{ "/vplates lift 60", "how many pixels to lift enemy nameplates" },
			{ "/vplates on | off", "turn the lift on or off" },
			{ "/vplates text numeric", "health/mana numbers: numeric, percent, both or hover" },
		},
		build = function(b)
			b:Check("Lift enemy nameplates", nil,
				function() return db and db.enabled end,
				function(v) db.enabled = v; LiftAll() end)
			b:Stepper("How high:", 0, 150, 10,
				function() return db and db.lift end,
				function(v) db.lift = v; db.enabled = true; LiftAll() end, " px")
		end,
	})
end
