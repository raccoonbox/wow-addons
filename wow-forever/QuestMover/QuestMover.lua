-- QuestMover: drag quest-related windows anywhere; positions are remembered.
local FRAMES = { "QuestFrame", "GossipFrame", "QuestLogFrame", "QuestLogDetailFrame", "ItemTextFrame" }

local hooked = {}

local function Restore(frame)
	local p = QuestMoverDB and QuestMoverDB[frame:GetName()]
	if not p then return end
	frame:ClearAllPoints()
	frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function Save(frame)
	local point, _, relPoint, x, y = frame:GetPoint(1)
	QuestMoverDB[frame:GetName()] = { point, relPoint, x, y }
end

local function Hook(name)
	local frame = _G[name]
	if not frame or hooked[name] then return end
	hooked[name] = true
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:HookScript("OnDragStart", function(self) self:StartMoving() end)
	frame:HookScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		Save(self)
	end)
	frame:HookScript("OnShow", Restore)
end

local function HookAll()
	for _, name in ipairs(FRAMES) do Hook(name) end
end

-- The game re-centers side panels when windows open or close; put ours back afterwards.
local function RestoreShown()
	for name in pairs(hooked) do
		local f = _G[name]
		if f and f:IsShown() then Restore(f) end
	end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, _, addon)
	if addon == "QuestMover" then
		QuestMoverDB = QuestMoverDB or {}
		if UpdateUIPanelPositions then hooksecurefunc("UpdateUIPanelPositions", RestoreShown) end
	end
	HookAll() -- also catches load-on-demand Blizzard UI addons
end)

SLASH_QUESTMOVER1 = "/qmover"
SlashCmdList.QUESTMOVER = function(msg)
	if msg == "reset" then
		wipe(QuestMoverDB)
		print("|cff33ff99Quest Mover:|r positions reset. /reload to put windows back in place.")
	else
		print("|cff33ff99Quest Mover:|r drag a quest window by its edge or title. /qmover reset puts them back.")
	end
end
