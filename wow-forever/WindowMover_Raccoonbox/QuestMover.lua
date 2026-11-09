-- Window Mover: drag game windows anywhere; positions are remembered.
-- Started with the quest windows, now covers most windows (spellbook, professions, character...).
-- Any other window: hover it and type /wmover this.
local FRAMES = {
	-- quests & NPCs
	"QuestFrame", "GossipFrame", "QuestLogFrame", "QuestLogDetailFrame", "ItemTextFrame",
	"MerchantFrame", "ClassTrainerFrame", "TaxiFrame", "FlightMapFrame", "TabardFrame", "PetStableFrame",
	-- your character
	"CharacterFrame", "SpellBookFrame", "PlayerSpellsFrame", "ProfessionsBookFrame", "PlayerTalentFrame",
	"TalentFrame", "ClassTalentFrame", "InspectFrame", "DressUpFrame", "ItemSocketingFrame",
	-- professions
	"ProfessionsFrame", "TradeSkillFrame", "CraftFrame",
	-- social, mail, trading
	"FriendsFrame", "GuildFrame", "CommunitiesFrame", "ChannelFrame", "MailFrame", "OpenMailFrame",
	"TradeFrame", "BankFrame", "GuildBankFrame", "AuctionHouseFrame", "AuctionFrame",
	-- collections, groups, misc
	"AchievementFrame", "CollectionsJournal", "EncounterJournal", "PVEFrame", "LFGParentFrame",
	"HonorFrame", "PVPFrame", "MacroFrame", "AddonList",
}

local hooked = {}
local db

local function Blocked(frame)
	-- windows with secure buttons (spellbook, talents...) can't be moved during combat
	return InCombatLockdown() and frame:IsProtected()
end

local function Restore(frame)
	local p = db and db[frame:GetName()]
	if not p or Blocked(frame) then return end
	frame:ClearAllPoints()
	frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function Save(frame)
	local point, _, relPoint, x, y = frame:GetPoint(1)
	db[frame:GetName()] = { point, relPoint, x, y }
end

local function Hook(name)
	local frame = _G[name]
	if not frame or hooked[name] or type(frame) ~= "table" or not frame.SetMovable then return end
	if frame.IsForbidden and frame:IsForbidden() then return end
	hooked[name] = true
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:HookScript("OnDragStart", function(self) if not Blocked(self) then self:StartMoving() end end)
	frame:HookScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		Save(self)
	end)
	frame:HookScript("OnShow", Restore)
end

local function HookAll()
	for _, name in ipairs(FRAMES) do Hook(name) end
	for name in pairs(db and db._added or {}) do Hook(name) end
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
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event, addon)
	if event == "PLAYER_REGEN_ENABLED" then RestoreShown() return end -- catch up after combat
	if addon == "WindowMover_Raccoonbox" then
		QuestMoverDB = QuestMoverDB or {}
		db = QuestMoverDB
		db._added = db._added or {}
		if UpdateUIPanelPositions then hooksecurefunc("UpdateUIPanelPositions", RestoreShown) end
	end
	HookAll() -- also catches load-on-demand Blizzard windows as they load
end)

-- the top-level window under the mouse
local function WindowUnderMouse()
	local f = GetMouseFoci and GetMouseFoci()[1] or (GetMouseFocus and GetMouseFocus())
	while f and f.GetParent and f:GetParent() and f:GetParent() ~= UIParent do f = f:GetParent() end
	return f
end

local function P(msg) print("|cff33ff99Window Mover:|r " .. msg) end

SLASH_QUESTMOVER1 = "/wmover"
SLASH_QUESTMOVER2 = "/qmover"
SlashCmdList.QUESTMOVER = function(msg)
	msg = (msg or ""):lower()
	if msg == "reset" then
		local added = db._added
		wipe(db)
		db._added = added
		P("positions reset. /reload to put windows back in place.")
	elseif msg == "this" then
		local f = WindowUnderMouse()
		local name = f and f.GetName and f:GetName()
		if not name or f == UIParent or f == WorldFrame then
			P("hover over a window first, then type /wmover this.")
			return
		end
		db._added[name] = true
		Hook(name)
		P(name .. " can now be dragged. It's remembered.")
	else
		P("drag windows by their edge or title. /wmover this (while hovering a window) makes any other window movable. /wmover reset puts them back.")
	end
end

---------------------------------------------------------------------------- options page
if RaccoonboxOptions then
	RaccoonboxOptions.AddPanel({
		name = "Window Mover",
		about = "Drag game windows anywhere by their edge or title: quest and gossip windows, spellbook, professions, "
			.. "character, talents, merchants, mail, auction house and more. They open in the same spot next time. "
			.. "Windows with spell buttons can't be moved during combat.",
		commands = {
			{ "/wmover this", "hover over any other window and type this to make it movable too" },
			{ "/wmover reset", "put all windows back to the game's default spot" },
		},
		build = function(b)
			b:Buttons({ { "Reset window positions", function() SlashCmdList.QUESTMOVER("reset") end } })
		end,
	})
end
