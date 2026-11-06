-- Quest Freedom: quest without spoilers.
--  * a quest you just accepted is not focused (highlighted) automatically
--  * quest search areas and markers stay off the map and minimap (the game's "Show Quest POIs" setting)
--  * quests are not added to the tracker automatically
-- When you're stuck: /qfree hint shows the areas until you type it again, or focus a quest yourself.
local db
local function Print(msg) print("|cff33ff99Quest Freedom:|r " .. msg) end

local function HintsShown() return GetCVar("questPOI") == "1" end
local function SetHints(on) SetCVar("questPOI", on and "1" or "0") end

local function ManualTracking() return GetCVar("autoQuestWatch") == "0" end
local function SetManualTracking(on)
	SetCVar("autoQuestWatch", on and "0" or "1")
	SetCVar("autoQuestProgress", on and "0" or "1")
end

-- Un-focus a quest the game focused by itself right after you accepted it.
local justAccepted, focusedBefore
local function Unfocus()
	if not (db and db.noFocus and justAccepted and C_SuperTrack) then return end
	local cur = C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
	if cur and cur == justAccepted and cur ~= focusedBefore then
		if C_SuperTrack.SetSuperTrackedQuestID then C_SuperTrack.SetSuperTrackedQuestID(0) end
	end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, arg1, arg2)
	if event == "ADDON_LOADED" then
		if arg1 ~= "QuestFreedom" then return end
		QuestFreedomDB = QuestFreedomDB or {}
		db = QuestFreedomDB
		if db.noFocus == nil then db.noFocus = true end
		if not db.setUp then
			-- first run: switch on the spoiler-free settings once; the player can change them later
			db.setUp = true
			SetHints(false)
			SetManualTracking(true)
		end
		self:RegisterEvent("QUEST_ACCEPTED")
		self:RegisterEvent("SUPER_TRACKING_CHANGED")
		return
	end
	if event == "QUEST_ACCEPTED" then
		-- the quest ID is the 1st argument on new clients, the 2nd on older ones
		justAccepted = (arg2 and type(arg2) == "number" and arg2 > 0) and arg2 or arg1
		focusedBefore = nil
		C_Timer.After(0.1, Unfocus)
		C_Timer.After(0.6, Unfocus)
		C_Timer.After(1.5, function() Unfocus(); justAccepted = nil end)
	elseif event == "SUPER_TRACKING_CHANGED" then
		Unfocus()
	end
end)

SLASH_QUESTFREEDOM1 = "/qfree"
SLASH_QUESTFREEDOM2 = "/questfreedom"
SlashCmdList.QUESTFREEDOM = function(msg)
	msg = (msg or ""):lower()
	if msg == "hint" then
		SetHints(not HintsShown())
		Print(HintsShown() and "hint ON: quest areas show on the map and minimap. /qfree hint again hides them."
			or "hints OFF: quest areas hidden again.")
	elseif msg == "focus" then
		db.noFocus = not db.noFocus
		Print("new quests " .. (db.noFocus and "are NOT focused automatically." or "get focused automatically (game default)."))
	elseif msg == "track" then
		SetManualTracking(not ManualTracking())
		Print(ManualTracking() and "you track quests yourself (Shift+click in the quest log)."
			or "new quests are tracked automatically (game default).")
	else
		Print("/qfree hint - show/hide quest areas when you're stuck")
		Print("/qfree focus - automatic focus on new quests on/off   /qfree track - automatic tracking on/off")
	end
end

---------------------------------------------------------------------------- options page
if RaccoonboxOptions then
	RaccoonboxOptions.AddPanel({
		name = "Quest Freedom",
		about = "Quest without spoilers. New quests aren't focused or tracked by themselves and the glowing search "
			.. "areas stay off your map and minimap, so you read the quest text and explore. Stuck? Type /qfree hint "
			.. "to see the areas, then /qfree hint again to hide them.",
		commands = {
			{ "/qfree hint", "show or hide quest areas on the map and minimap" },
			{ "/qfree focus", "turn automatic focus on new quests on or off" },
			{ "/qfree track", "turn automatic quest tracking on or off" },
		},
		build = function(b)
			b:Check("Don't focus (highlight) quests I just accepted",
				"The game normally highlights a new quest and shows where to go. You can still click a quest yourself to focus it.",
				function() return db and db.noFocus end, function(v) db.noFocus = v end)
			b:Check("Hide quest areas and markers on the map and minimap",
				"The game's \"Show Quest POIs\" setting, switched off.",
				function() return not HintsShown() end, function(v) SetHints(not v) end)
			b:Check("Track quests by hand (Shift+click in the quest log)", nil,
				ManualTracking, SetManualTracking)
		end,
	})
end
