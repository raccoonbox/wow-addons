-- Shared Raccoonbox options pages (WoW Forever). Every Raccoonbox addon ships this same file.
-- The newest copy wins. Each addon calls RaccoonboxOptions.AddPanel{...}; at login all pages are
-- put under Esc > Options > AddOns > Raccoonbox. The main "Raccoonbox" page holds a few useful
-- hidden game settings and lists what every installed Raccoonbox addon can do. /raccoonbox opens it.
local VERSION = 3
local ADDON_NAME = ... -- the folder this copy was loaded from (it ships RaccoonboxLogo.tga)
if RaccoonboxOptions and (RaccoonboxOptions.version or 0) >= VERSION then return end

local old = RaccoonboxOptions
local RB = { version = VERSION, defs = old and old.defs or {}, ready = false } -- keep pages added through an older copy
RaccoonboxOptions = RB

local WIDTH = 580
local GOLD = "|cffffd100"

---------------------------------------------------------------------------- page builder
local B = {}
B.__index = B

local function NewBuilder(f) return setmetatable({ f = f, x = 16, y = -16, widgets = {} }, B) end

function B:Title(text)
	local fs = self.f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	fs:SetPoint("TOPLEFT", self.x, self.y); fs:SetText(text)
	self.y = self.y - 30
end

function B:Header(text)
	self.y = self.y - 8
	local fs = self.f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fs:SetPoint("TOPLEFT", self.x, self.y); fs:SetText(text)
	self.y = self.y - 22
end

function B:Text(text, small)
	local fs = self.f:CreateFontString(nil, "ARTWORK", small and "GameFontHighlightSmall" or "GameFontHighlight")
	fs:SetWidth(WIDTH - self.x); fs:SetJustifyH("LEFT"); fs:SetText(text)
	fs:SetPoint("TOPLEFT", self.x, self.y)
	self.y = self.y - math.max(14, fs:GetStringHeight()) - 6
end

function B:Check(label, tip, get, set)
	local cb = CreateFrame("CheckButton", nil, self.f, "UICheckButtonTemplate")
	cb:SetSize(26, 26)
	cb:SetPoint("TOPLEFT", self.x - 4, self.y)
	local t = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	t:SetPoint("LEFT", cb, "RIGHT", 4, 1); t:SetText(label)
	cb:SetScript("OnClick", function(s) set(s:GetChecked() and true or false); RB.RefreshAll() end)
	if tip then
		cb:SetScript("OnEnter", function(s)
			GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(tip, 1, 1, 1, 1, true); GameTooltip:Show()
		end)
		cb:SetScript("OnLeave", GameTooltip_Hide)
	end
	cb.Refresh = function() cb:SetChecked(get() and true or false) end
	self.widgets[#self.widgets + 1] = cb
	self.y = self.y - 28
end

-- a row of buttons; the one matching get() is highlighted. options = { {value, text}, ... }
function B:Choice(label, options, get, set)
	local fs = self.f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	fs:SetPoint("TOPLEFT", self.x, self.y); fs:SetText(label)
	self.y = self.y - 20
	local btns, prev = {}, nil
	for i, o in ipairs(options) do
		local b = CreateFrame("Button", nil, self.f, "UIPanelButtonTemplate")
		b:SetText(o[2])
		b:SetSize(math.max(64, b:GetFontString():GetStringWidth() + 24), 22)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", self.x + 4, self.y) end
		b:SetScript("OnClick", function() set(o[1]); RB.RefreshAll() end)
		btns[i], prev = b, b
	end
	self.widgets[#self.widgets + 1] = { Refresh = function()
		local cur = get()
		for i, o in ipairs(options) do
			local on = (o[1] == cur)
			if on then btns[i]:LockHighlight() else btns[i]:UnlockHighlight() end
			btns[i]:GetFontString():SetTextColor(on and 1 or 0.85, on and 0.82 or 0.85, on and 0 or 0.85)
		end
	end }
	self.y = self.y - 30
end

-- label  [-]  value  [+]
function B:Stepper(label, min, max, step, get, set, suffix)
	local fs = self.f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	fs:SetPoint("TOPLEFT", self.x, self.y - 4); fs:SetText(label)
	local minus = CreateFrame("Button", nil, self.f, "UIPanelButtonTemplate")
	minus:SetSize(26, 22); minus:SetText("-"); minus:SetPoint("TOPLEFT", self.x + 300, self.y)
	local val = self.f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	val:SetWidth(70); val:SetPoint("LEFT", minus, "RIGHT", 4, 0)
	local plus = CreateFrame("Button", nil, self.f, "UIPanelButtonTemplate")
	plus:SetSize(26, 22); plus:SetText("+"); plus:SetPoint("LEFT", val, "RIGHT", 4, 0)
	local function change(d)
		local v = math.min(max, math.max(min, (get() or 0) + d))
		set(v); RB.RefreshAll()
	end
	minus:SetScript("OnClick", function() change(-step) end)
	plus:SetScript("OnClick", function() change(step) end)
	self.widgets[#self.widgets + 1] = { Refresh = function() val:SetText(tostring(get() or 0) .. (suffix or "")) end }
	self.y = self.y - 30
end

-- buttons = { {text, onClick}, ... } on one row
function B:Buttons(buttons)
	local prev
	for _, d in ipairs(buttons) do
		local b = CreateFrame("Button", nil, self.f, "UIPanelButtonTemplate")
		b:SetText(d[1]); b:SetSize(b:GetFontString():GetStringWidth() + 30, 22)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", self.x, self.y) end
		b:SetScript("OnClick", function() d[2](); RB.RefreshAll() end)
		prev = b
	end
	self.y = self.y - 30
end

-- commands = { {"/cmd", "what it does"}, ... }
function B:Commands(commands, noHeader)
	if not commands or #commands == 0 then return end
	if not noHeader then self:Header("Commands  |cff999999(click one to put it in your chat)|r") end
	for _, c in ipairs(commands) do
		local w = WIDTH - self.x
		local btn = CreateFrame("Button", nil, self.f)
		local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		fs:SetWidth(w); fs:SetJustifyH("LEFT"); fs:SetPoint("TOPLEFT")
		fs:SetText(GOLD .. c[1] .. "|r  " .. c[2])
		btn:SetSize(w, math.max(14, fs:GetStringHeight()))
		btn:SetPoint("TOPLEFT", self.x, self.y)
		btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		-- "/vplates on | off" -> "/vplates on", "/vc gg add <message>" -> "/vc gg add "
		local cmd = c[1]:gsub("%s*|.*$", ""):gsub("<.*$", "")
		btn:SetScript("OnClick", function()
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
			ChatFrame_OpenChat(cmd:match("%s$") and cmd or (cmd .. " "))
		end)
		btn:SetScript("OnEnter", function(s)
			GameTooltip:SetOwner(s, "ANCHOR_TOPLEFT"); GameTooltip:SetText("Click: put |cffffd100" .. cmd .. "|r in your chat"); GameTooltip:Show()
		end)
		btn:SetScript("OnLeave", GameTooltip_Hide)
		self.y = self.y - btn:GetHeight() - 6
	end
end

---------------------------------------------------------------------------- pages
local pages = {}

local function MakePage(name, build)
	local frame = CreateFrame("Frame")
	frame.name = name
	local sf = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", 0, -4); sf:SetPoint("BOTTOMRIGHT", -28, 4)
	local child = CreateFrame("Frame", nil, sf)
	child:SetSize(WIDTH + 20, 10)
	sf:SetScrollChild(child)
	local b = NewBuilder(child)
	local ok, err = pcall(build, b)
	if not ok then b:Text("|cffff4040This page failed to load:|r " .. tostring(err)) end
	child:SetHeight(-b.y + 20)
	frame.widgets = b.widgets
	frame:SetScript("OnShow", function() RB.RefreshAll() end)
	pages[#pages + 1] = frame
	return frame
end

function RB.RefreshAll()
	for _, p in ipairs(pages) do
		for _, w in ipairs(p.widgets) do pcall(w.Refresh) end
	end
end

-- hidden game settings on the main page (the game itself saves these)
local BAR_MODES = {
	{ "numeric", "Current / max" }, { "percent", "Percent" }, { "both", "Both" }, { "hover", "Only on hover" },
}
local function BarModeGet()
	if GetCVar("statusText") ~= "1" then return "hover" end
	return (GetCVar("statusTextDisplay") or ""):lower()
end
local function BarModeSet(v)
	if SlashCmdList.VALORPLATES then SlashCmdList.VALORPLATES("text " .. v) return end -- keeps Valor Plates in sync
	SetCVar("statusText", v == "hover" and "0" or "1")
	SetCVar("statusTextDisplay", v == "hover" and "NUMERIC" or v:upper())
end

local function BuildMain(b)
	local logo = b.f:CreateTexture(nil, "ARTWORK")
	logo:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\RaccoonboxLogo")
	logo:SetSize(40, 40); logo:SetPoint("TOPLEFT", b.x, b.y + 6)
	b.x = b.x + 48
	b:Title("Raccoonbox")
	b.x = b.x - 48
	b.y = b.y - 12
	b:Text("Free add-ons made by Raccoonbox. Every add-on has its own page in the list on the left. "
		.. "The Raccoonbox button on your minimap opens this page (right-click it to jump to an add-on). "
		.. "Click any gold command to put it in your chat. More at raccoonbox.com.")
	b:Header("Useful hidden game settings")
	b:Check("Hear game sounds from the camera, not from your character",
		"Sounds get louder or quieter based on where your camera is, not where your character stands.",
		function() return GetCVar("Sound_ListenerAtCharacter") == "0" end,
		function(v) SetCVar("Sound_ListenerAtCharacter", v and "0" or "1") end)
	b:Check("Track quests by hand (no automatic tracking)",
		"New quests no longer jump onto the objective tracker. Shift+click a quest in the quest log (L) to track it.",
		function() return GetCVar("autoQuestWatch") == "0" end,
		function(v) SetCVar("autoQuestWatch", v and "0" or "1"); SetCVar("autoQuestProgress", v and "0" or "1") end)
	b:Choice("Health and mana numbers on your, your target's and party bars:", BAR_MODES, BarModeGet, BarModeSet)

	b:Header("Your Raccoonbox add-ons")
	table.sort(RB.defs, function(a, c) return a.name < c.name end)
	for _, d in ipairs(RB.defs) do
		b:Text(GOLD .. d.name .. "|r - " .. (d.about or ""))
		b.x = b.x + 16
		b:Commands(d.commands, true)
		b.x = b.x - 16
		b.y = b.y - 4
	end
end

local function BuildAddon(d)
	return function(b)
		b:Title(d.name)
		if d.about then b:Text(d.about) end
		if d.build then
			b:Header("Settings")
			d.build(b)
		end
		b:Commands(d.commands)
	end
end

---------------------------------------------------------------------------- registration
local mainCategory, mainFrame
local subCategories, subFrames = {}, {}

local function RegisterAll()
	if RB.ready then return end
	RB.ready = true
	mainFrame = MakePage("Raccoonbox", BuildMain)
	local subs = {}
	for _, d in ipairs(RB.defs) do
		local f = MakePage(d.name, BuildAddon(d))
		subs[#subs + 1] = { d.name, f }
		subFrames[d.name] = f
	end

	if Settings and Settings.RegisterCanvasLayoutCategory then
		mainCategory = Settings.RegisterCanvasLayoutCategory(mainFrame, "Raccoonbox")
		for _, s in ipairs(subs) do
			subCategories[s[1]] = Settings.RegisterCanvasLayoutSubcategory(mainCategory, s[2], s[1])
		end
		Settings.RegisterAddOnCategory(mainCategory)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(mainFrame)
		for _, s in ipairs(subs) do s[2].parent = "Raccoonbox"; InterfaceOptions_AddCategory(s[2]) end
	end
end

-- def = { name = "Craft Well", about = "...", commands = { {"/cmd", "desc"} }, build = function(b) ... end }
function RB.AddPanel(def)
	RB.defs[#RB.defs + 1] = def
end

-- name = an add-on page ("Craft Well"), or nil for the main Raccoonbox page
function RB.Open(name)
	if not RB.ready then RegisterAll() end
	local cat = name and subCategories[name] or mainCategory
	if Settings and Settings.OpenToCategory and cat then
		Settings.OpenToCategory(cat:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory then
		local f = name and subFrames[name] or mainFrame
		InterfaceOptionsFrame_OpenToCategory(f); InterfaceOptionsFrame_OpenToCategory(f)
	end
end

---------------------------------------------------------------------------- minimap button
-- One Raccoonbox button, however many Raccoonbox add-ons are installed.
-- Left-click: settings & help. Right-click: jump to an add-on's page. Drag: move it.
local shared -- RaccoonboxSharedDB (every Raccoonbox add-on lists it in its TOC)
local mmButton

local function PlaceButton()
	local a = math.rad(shared.angle or 225)
	local r = Minimap:GetWidth() / 2 + 10
	mmButton:ClearAllPoints()
	mmButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function ShowMenu(owner)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner, function(_, root)
			root:CreateTitle("Raccoonbox add-ons")
			root:CreateButton("Settings & help", function() RB.Open() end)
			for _, d in ipairs(RB.defs) do
				root:CreateButton(d.name, function() RB.Open(d.name) end)
			end
			root:CreateDivider()
			root:CreateButton("|cff999999Hide this button (/raccoonbox button)|r", function()
				shared.hideButton = true; mmButton:Hide()
			end)
		end)
	else
		RB.Open()
	end
end

local function MakeButton()
	if mmButton or not Minimap then return end
	RaccoonboxSharedDB = RaccoonboxSharedDB or {}
	shared = RaccoonboxSharedDB
	local b = CreateFrame("Button", "RaccoonboxMinimapButton", Minimap)
	mmButton = b
	b:SetSize(31, 31)
	b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	-- drawn above the gold frame so the frame's inner shadow doesn't darken the white logo;
	-- sized to end at the gold ring
	local icon = b:CreateTexture(nil, "OVERLAY", nil, 2)
	icon:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\RaccoonboxLogo")
	icon:SetSize(20, 20); icon:SetPoint("CENTER", b, "TOPLEFT", 16.5, -15.5)
	-- round it off so the white logo square fits the round minimap button frame
	if icon.SetMask then icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53); border:SetPoint("TOPLEFT")

	local dragged = false
	b:SetScript("OnMouseDown", function() dragged = false end)
	b:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local s = Minimap:GetEffectiveScale()
			shared.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
			PlaceButton()
		end)
	end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil); dragged = true end)
	b:SetScript("OnClick", function(self, mouse)
		if dragged then dragged = false return end
		GameTooltip:Hide()
		if mouse == "RightButton" then ShowMenu(self) else RB.Open() end
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("|cffff9900Raccoonbox|r add-ons")
		for _, d in ipairs(RB.defs) do GameTooltip:AddLine(d.name, 1, 1, 1) end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Click: settings & help", 0.6, 1, 0.6)
		GameTooltip:AddLine("Right-click: go to an add-on", 0.6, 1, 0.6)
		GameTooltip:AddLine("Drag: move button", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	PlaceButton()
	b:SetShown(not shared.hideButton)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
	if RaccoonboxOptions ~= RB then return end -- a newer copy took over
	local ok, err = pcall(RegisterAll)
	if not ok then print("|cffff9900[Raccoonbox]|r options pages failed: " .. tostring(err)) end
	ok, err = pcall(MakeButton)
	if not ok then print("|cffff9900[Raccoonbox]|r minimap button failed: " .. tostring(err)) end
end)

SLASH_RACCOONBOX1 = "/raccoonbox"
SLASH_RACCOONBOX2 = "/rbox"
SlashCmdList.RACCOONBOX = function(msg)
	if (msg or ""):lower() == "button" and mmButton then
		shared.hideButton = not shared.hideButton
		mmButton:SetShown(not shared.hideButton)
		return
	end
	RB.Open()
end
