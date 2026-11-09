-- Keep Tracking: dying switches off Find Herbs / Find Minerals. This remembers what minimap
-- tracking you had on while alive and turns it back on as soon as you're alive again.
local db

local function Print(msg) print("|cff33ff99Keep Tracking:|r " .. msg) end

-- name, active for tracking entry i (handles both the table and the old multi-value form)
local function Info(i)
	local a, _, c = C_Minimap.GetTrackingInfo(i)
	if type(a) == "table" then return a.name, a.active end
	return a, c
end

local function ActiveNames()
	local on = {}
	for i = 1, C_Minimap.GetNumTrackingTypes() do
		local name, active = Info(i)
		if name and active then on[#on + 1] = name end
	end
	return on
end

local function Save()
	if UnitIsDeadOrGhost("player") then return end -- death clears tracking; don't remember that
	db.tracking = ActiveNames()
end

local function Restore()
	if UnitIsDeadOrGhost("player") or not db.tracking or #db.tracking == 0 then return end
	local want = {}
	for _, n in ipairs(db.tracking) do want[n] = true end
	local turnedOn = {}
	for i = 1, C_Minimap.GetNumTrackingTypes() do
		local name, active = Info(i)
		if name and want[name] and not active then
			local ok = pcall(C_Minimap.SetTracking, i, true)
			if ok then turnedOn[#turnedOn + 1] = name end
		end
	end
	if #turnedOn > 0 then Print("back on: " .. table.concat(turnedOn, ", ")) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, arg)
	if event == "ADDON_LOADED" then
		if arg ~= "KeepTracking_Raccoonbox" then return end
		KeepTrackingDB = KeepTrackingDB or {}
		db = KeepTrackingDB
		self:RegisterEvent("MINIMAP_UPDATE_TRACKING")
		self:RegisterEvent("PLAYER_ALIVE")     -- released or resurrected before releasing
		self:RegisterEvent("PLAYER_UNGHOST")   -- back in your body after a corpse run / spirit healer
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		return
	end
	if event == "MINIMAP_UPDATE_TRACKING" then
		Save()
	else
		-- give the game a moment to finish bringing you back
		C_Timer.After(1, Restore)
		C_Timer.After(3, Restore)
	end
end)

SLASH_KEEPTRACKING1 = "/keeptracking"
SlashCmdList.KEEPTRACKING = function()
	local list = db and db.tracking or {}
	Print(#list > 0 and ("remembering: " .. table.concat(list, ", ")) or "nothing remembered yet - switch on Find Herbs once.")
end

---------------------------------------------------------------------------- options page
if RaccoonboxOptions then
	RaccoonboxOptions.AddPanel({
		name = "Keep Tracking",
		about = "Dying switches off Find Herbs / Find Minerals. Keep Tracking remembers the minimap tracking you had on "
			.. "and switches it back on as soon as you are alive again. Turn your tracking on once and it just works.",
		commands = { { "/keeptracking", "show which tracking is remembered" } },
		build = function(b)
			b:Buttons({ { "Show remembered tracking", function() SlashCmdList.KEEPTRACKING("") end } })
		end,
	})
end
