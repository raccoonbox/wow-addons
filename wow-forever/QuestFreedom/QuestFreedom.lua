-- Quest Freedom: quest without spoilers.
--  * a quest you just accepted is not focused (highlighted) automatically
--  * the highlighted search areas are hidden on the minimap and the big map, and so are the markers of
--    unfinished quests - the "?" of quests ready to hand in stays, so you still find the quest giver
--  * quests are not added to the tracker automatically; tracking a quest yourself shows its objectives
--    in the list, but still no search area
-- Stuck? /qfree hint shows the areas until you type it again.
local db
local function Print(msg) print("|cff33ff99Quest Freedom:|r " .. msg) end

local hinting = false -- /qfree hint: temporarily show everything
local function HideAreas() return db and db.hideAreas and not hinting end

---------------------------------------------------------------------------- game settings
local function MarkersShown() return GetCVar("questPOI") == "1" end
local function SetMarkers(on) SetCVar("questPOI", on and "1" or "0") end
local function ManualTracking() return GetCVar("autoQuestWatch") == "0" end
local function SetManualTracking(on)
	SetCVar("autoQuestWatch", on and "0" or "1")
	SetCVar("autoQuestProgress", on and "0" or "1")
end

---------------------------------------------------------------------------- minimap: search areas
local function ApplyMinimap()
	if not Minimap or not Minimap.SetQuestBlobInsideAlpha then return end
	local a = HideAreas() and 0 or 1
	Minimap:SetQuestBlobInsideAlpha(a)
	Minimap:SetQuestBlobOutsideAlpha(HideAreas() and 0 or 0.4)
	Minimap:SetQuestBlobRingAlpha(a)
	if Minimap.SetTaskBlobInsideAlpha then
		Minimap:SetTaskBlobInsideAlpha(a)
		Minimap:SetTaskBlobOutsideAlpha(HideAreas() and 0 or 0.4)
		Minimap:SetTaskBlobRingAlpha(a)
	end
end

---------------------------------------------------------------------------- big map: areas and unfinished-quest markers
local function IsDone(questID)
	return questID and C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID)
end

local function FilterMap()
	local map = WorldMapFrame
	if not (map and map:IsShown() and map.EnumeratePinsByTemplate) then return end
	local hide = HideAreas()
	for _, tpl in ipairs({ "QuestBlobPinTemplate", "BonusObjectivePinTemplate" }) do
		for pin in map:EnumeratePinsByTemplate(tpl) do pin:SetAlpha(hide and 0 or 1) end
	end
	for pin in map:EnumeratePinsByTemplate("QuestPinTemplate") do
		local keep = not hide or IsDone(pin.questID)
		pin:SetAlpha(keep and 1 or 0)
		if pin.EnableMouse then pin:EnableMouse(keep) end
	end
end

---------------------------------------------------------------------------- quest log only (L hides the map)
local openedBy, wantMap = nil, false
local mapButton

local function MapParts()
	local m = WorldMapFrame
	local parts = { m.NavBar }
	for _, f in ipairs(m.overlayFrames or {}) do parts[#parts + 1] = f end
	return parts
end

local function LogOnlyActive()
	return db and db.logOnly and not wantMap and openedBy ~= "map"
		and QuestMapFrame and QuestMapFrame:IsShown() and WorldMapFrame and WorldMapFrame:IsShown()
end

local function ApplyLogOnly()
	local m = WorldMapFrame
	if not (m and m.ScrollContainer) then return end
	local hide = LogOnlyActive()
	m.ScrollContainer:SetAlpha(hide and 0 or 1)
	m.ScrollContainer:EnableMouse(not hide)
	for _, f in ipairs(MapParts()) do
		if f then if hide then f:Hide() else f:Show() end end
	end
	if mapButton then
		mapButton:SetShown(db and db.logOnly and QuestMapFrame and QuestMapFrame:IsShown())
		mapButton:SetText(hide and "Show map" or "Hide map")
	end
end

local function MakeMapButton()
	if mapButton or not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
	mapButton = CreateFrame("Button", nil, WorldMapFrame, "UIPanelButtonTemplate")
	mapButton:SetSize(100, 24)
	mapButton:SetPoint("TOPLEFT", WorldMapFrame.ScrollContainer, "TOPLEFT", 10, -10)
	mapButton:SetFrameStrata("HIGH")
	mapButton:SetScript("OnClick", function()
		if LogOnlyActive() then wantMap = true else wantMap = false; openedBy = "log" end
		ApplyLogOnly()
	end)
	mapButton:Hide()
end

-- Which key opened the window? Checked the moment it opens, so the map can be hidden before the
-- first frame is drawn (no flash). Your own key bindings are used, modifiers ignored.
local function BindingDown(action)
	for _, key in ipairs({ GetBindingKey(action) }) do
		local base = key and key:match("([^%-]+)$")
		if base and IsKeyDown(base) then return true end
	end
	return false
end

local function GuessOpener()
	if BindingDown("TOGGLEWORLDMAP") then return "map" end
	if BindingDown("TOGGLEQUESTLOG") then return "log" end
	return openedBy
end

-- backups in case the key was already released: correct it right after the game's own handling
if ToggleQuestLog then hooksecurefunc("ToggleQuestLog", function() openedBy = "log"; wantMap = false; ApplyLogOnly() end) end
if ToggleWorldMap then hooksecurefunc("ToggleWorldMap", function() openedBy = "map"; ApplyLogOnly() end) end

local mapHooked = false
local function HookMap()
	if mapHooked or not WorldMapFrame then return end
	mapHooked = true
	MakeMapButton()
	WorldMapFrame:HookScript("OnHide", function()
		openedBy, wantMap = nil, false
		ApplyLogOnly() -- leave the map normal for next time
	end)
	if QuestMapFrame then
		QuestMapFrame:HookScript("OnShow", ApplyLogOnly)
		QuestMapFrame:HookScript("OnHide", ApplyLogOnly)
	end
	local elapsed = 0
	-- the map rebuilds its pins often (zooming, hovering the quest list); keep them filtered while it's open
	WorldMapFrame:HookScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed > 0.2 then elapsed = 0; FilterMap() end
	end)
	WorldMapFrame:HookScript("OnShow", function()
		openedBy = GuessOpener()
		ApplyLogOnly() -- right away, before the first frame is drawn
		FilterMap()
		C_Timer.After(0, ApplyLogOnly) -- once more after the game has finished opening the window
	end)
end

local function ApplyAll() ApplyMinimap(); FilterMap() end

---------------------------------------------------------------------------- no automatic focus
local justAccepted, focusedBefore
local function Unfocus()
	if not (db and db.noFocus and justAccepted and C_SuperTrack) then return end
	local cur = C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
	if cur and cur == justAccepted and cur ~= focusedBefore then
		if C_SuperTrack.SetSuperTrackedQuestID then C_SuperTrack.SetSuperTrackedQuestID(0) end
	end
end

---------------------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, arg1, arg2)
	if event == "ADDON_LOADED" then
		if arg1 == "Blizzard_WorldMap" then HookMap() end
		if arg1 ~= "QuestFreedom" then return end
		QuestFreedomDB = QuestFreedomDB or {}
		db = QuestFreedomDB
		if db.noFocus == nil then db.noFocus = true end
		if db.version ~= 2 then
			-- v2: hide only the search areas, keep quest markers (the "?" to hand in) visible
			db.version = 2
			db.hideAreas = true
			SetMarkers(true)
			SetManualTracking(true)
		end
		self:RegisterEvent("QUEST_ACCEPTED")
		self:RegisterEvent("SUPER_TRACKING_CHANGED")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		HookMap()
		return
	end
	if event == "QUEST_ACCEPTED" then
		justAccepted = (arg2 and type(arg2) == "number" and arg2 > 0) and arg2 or arg1
		focusedBefore = nil
		C_Timer.After(0.1, Unfocus)
		C_Timer.After(0.6, Unfocus)
		C_Timer.After(1.5, function() Unfocus(); justAccepted = nil end)
	elseif event == "SUPER_TRACKING_CHANGED" then
		Unfocus()
	else -- entering the world / new zone: the minimap can reset its settings
		HookMap()
		C_Timer.After(1, ApplyAll)
	end
end)

SLASH_QUESTFREEDOM1 = "/qfree"
SLASH_QUESTFREEDOM2 = "/questfreedom"
SlashCmdList.QUESTFREEDOM = function(msg)
	msg = (msg or ""):lower()
	if msg == "hint" then
		hinting = not hinting
		if hinting and not MarkersShown() then SetMarkers(true) end
		ApplyAll()
		Print(hinting and "hint ON: search areas show on the map and minimap. /qfree hint again hides them."
			or "hint OFF: search areas hidden again.")
	elseif msg == "log" then
		db.logOnly = not db.logOnly
		ApplyLogOnly()
		Print(db.logOnly and "L opens only the quest log; use the Show map button to see the map."
			or "L opens the quest log with the map (game default).")
	elseif msg == "focus" then
		db.noFocus = not db.noFocus
		Print("new quests " .. (db.noFocus and "are NOT focused automatically." or "get focused automatically (game default)."))
	elseif msg == "track" then
		SetManualTracking(not ManualTracking())
		Print(ManualTracking() and "you track quests yourself (Shift+click in the quest log)."
			or "new quests are tracked automatically (game default).")
	else
		Print("/qfree hint - show/hide search areas when you're stuck")
		Print("/qfree focus - automatic focus on new quests on/off   /qfree track - automatic tracking on/off")
	end
end

---------------------------------------------------------------------------- options page
if RaccoonboxOptions then
	RaccoonboxOptions.AddPanel({
		name = "Quest Freedom",
		about = "Quest without spoilers. New quests aren't focused or tracked by themselves. The glowing search areas "
			.. "and the markers of unfinished quests stay off your map and minimap, but the \"?\" of quests ready to hand "
			.. "in stays, so you still find your way back. You can track quests to see their objectives in the list, "
			.. "without areas. Stuck? Type /qfree hint, and /qfree hint again to hide them.",
		commands = {
			{ "/qfree hint", "show or hide the search areas for a moment" },
			{ "/qfree log", "L opens only the quest log, or the quest log with the map" },
			{ "/qfree focus", "turn automatic focus on new quests on or off" },
			{ "/qfree track", "turn automatic quest tracking on or off" },
		},
		build = function(b)
			b:Check("Don't focus (highlight) quests I just accepted", nil,
				function() return db and db.noFocus end, function(v) db.noFocus = v end)
			b:Check("Hide search areas and unfinished-quest markers (keep the \"?\" to hand in)", nil,
				function() return db and db.hideAreas end, function(v) db.hideAreas = v; ApplyAll() end)
			b:Check("Hide ALL quest markers on the maps, also the \"?\"", "The game's \"Show Quest POIs\" setting, switched off.",
				function() return not MarkersShown() end, function(v) SetMarkers(not v) end)
			b:Check("Track quests by hand (Shift+click in the quest log)", nil, ManualTracking, SetManualTracking)
			b:Check("L opens only the quest log (map hidden, with a Show map button)",
				"The map key (M) still opens the map as usual.",
				function() return db and db.logOnly end, function(v) db.logOnly = v; ApplyLogOnly() end)
		end,
	})
end
