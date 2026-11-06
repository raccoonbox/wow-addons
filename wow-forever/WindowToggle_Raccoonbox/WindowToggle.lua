-- WindowToggle (WoW Forever): click the minimap button to switch between a maximised window
-- and a small window (1024 wide by default, same shape as your screen).
-- Drag the button to move it around the minimap. Right-click to pick the small size.
-- /wt              toggle
-- /wt size 1280x720 / /wt size auto
-- /wt reset        button back to its default spot
local defaults = { angle = 200, small = "auto" }
local db

local function Print(msg) print("|cff33ff99Window Toggle:|r " .. msg) end

-- the screen's real size (falls back to 1920x1080)
local function ScreenSize()
	if GetPhysicalScreenSize then
		local w, h = GetPhysicalScreenSize()
		if w and h and w > 0 and h > 0 then return w, h end
	end
	return 1920, 1080
end

local function SmallSize()
	if db.small ~= "auto" then
		local w, h = db.small:match("^(%d+)x(%d+)$")
		if w then return tonumber(w), tonumber(h) end
	end
	local sw, sh = ScreenSize()
	local w = 1024
	return w, math.floor(w * sh / sw / 2 + 0.5) * 2 -- 16:9 -> 576, 16:10 -> 640
end

local function IsMaximised() return GetCVar("gxMaximize") == "1" end

local function Apply()
	if UpdateWindow then
		local ok = pcall(UpdateWindow)
		if ok then return end
	end
	if RestartGx then RestartGx() end
end

local function SetMaximised()
	SetCVar("gxMaximize", "1")
	Apply()
end

local function SetSmall()
	local w, h = SmallSize()
	Print("switching to a " .. w .. "x" .. h .. " window.")
	SetCVar("gxWindowedResolution", w .. "x" .. h)
	SetCVar("gxMaximize", "0")
	Apply()
end

local function Toggle()
	if IsMaximised() then SetSmall() else SetMaximised() end
end

local function PickSize(value)
	db.small = value
	if not IsMaximised() then SetSmall()
	else
		local w, h = SmallSize()
		Print("small window set to " .. w .. "x" .. h .. ".")
	end
end

-- small sizes offered in the right-click menu: common widths in the screen's own shape
local function SizeChoices()
	local sw, sh = ScreenSize()
	local out = {}
	for _, w in ipairs({ 800, 1024, 1280, 1440, 1600, 1920 }) do
		if w < sw then
			out[#out + 1] = w .. "x" .. (math.floor(w * sh / sw / 2 + 0.5) * 2)
		end
	end
	return out
end

---------------------------------------------------------------------------- minimap button
local button = CreateFrame("Button", "WindowToggleMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")

local icon = button:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
icon:SetSize(20, 20)
icon:SetPoint("TOPLEFT", 7, -5)
local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")

local function UpdatePosition()
	local a = math.rad(db.angle)
	local r = (Minimap:GetWidth() / 2) + 10
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function DragUpdate()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local s = Minimap:GetEffectiveScale()
	db.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
	UpdatePosition()
end

local function ShowMenu(owner)
	local choices = SizeChoices()
	local aw, ah
	do
		local saved = db.small
		db.small = "auto"; aw, ah = SmallSize(); db.small = saved
	end
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner, function(_, root)
			root:CreateTitle("Small window size")
			root:CreateRadio("Auto (" .. aw .. "x" .. ah .. ")", function() return db.small == "auto" end,
				function() PickSize("auto") end)
			for _, c in ipairs(choices) do
				root:CreateRadio(c, function() return db.small == c end, function() PickSize(c) end)
			end
		end)
	else
		-- no menu system: step through the sizes instead
		local list = { "auto" }
		for _, c in ipairs(choices) do list[#list + 1] = c end
		local nextIdx = 1
		for i, c in ipairs(list) do if c == db.small then nextIdx = i % #list + 1 end end
		PickSize(list[nextIdx])
	end
end

local dragged = false
button:SetScript("OnMouseDown", function() dragged = false end)
button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", DragUpdate) end)
button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil); dragged = true end)
button:SetScript("OnClick", function(self, mouse)
	if dragged then dragged = false return end
	GameTooltip:Hide()
	if mouse == "RightButton" then ShowMenu(self) else Toggle() end
end)
button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("Window Toggle")
	if IsMaximised() then
		local w, h = SmallSize()
		GameTooltip:AddLine("Click: small window (" .. w .. "x" .. h .. ")", 1, 1, 1)
	else
		GameTooltip:AddLine("Click: maximised window", 1, 1, 1)
	end
	GameTooltip:AddLine("Right-click: choose small window size", 1, 1, 1)
	GameTooltip:AddLine("Drag: move button", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", GameTooltip_Hide)

---------------------------------------------------------------------------- saved settings + slash
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
	if name ~= "WindowToggle_Raccoonbox" then return end
	WindowToggleDB = WindowToggleDB or {}
	db = WindowToggleDB
	for k, v in pairs(defaults) do if db[k] == nil then db[k] = v end end
	UpdatePosition()
end)

SLASH_WINDOWTOGGLE1 = "/wt"
SlashCmdList.WINDOWTOGGLE = function(msg)
	local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "size" then
		local w, h = (arg or ""):match("^(%d+)%s*[xX]%s*(%d+)$")
		if (arg or ""):lower() == "auto" then PickSize("auto")
		elseif w then PickSize(w .. "x" .. h)
		else Print("usage: /wt size 1280x720  or  /wt size auto") end
	elseif cmd == "reset" then
		db.angle = defaults.angle; UpdatePosition(); Print("button position reset.")
	elseif cmd == "" then
		Toggle()
	else
		Print("/wt (toggle), /wt size 1280x720, /wt size auto, /wt reset")
	end
end

---------------------------------------------------------------------------- options page
if RaccoonboxOptions then
	RaccoonboxOptions.AddPanel({
		name = "Window Toggle",
		about = "A minimap button (spyglass) that switches the game between a maximised window and a small window. "
			.. "Right-click the button to choose the small size, drag it to move it around the minimap.",
		commands = {
			{ "/wt", "switch between maximised and small window" },
			{ "/wt size 1280x720", "use your own small window size" },
			{ "/wt size auto", "back to the default small size" },
			{ "/wt reset", "put the minimap button back in its default spot" },
		},
		build = function(b)
			local sw, sh = ScreenSize()
			local aw = 1024
			local options = { { "auto", "Auto (" .. aw .. "x" .. (math.floor(aw * sh / sw / 2 + 0.5) * 2) .. ")" } }
			for _, c in ipairs(SizeChoices()) do options[#options + 1] = { c, c } end
			b:Choice("Small window size:", options, function() return db and db.small end, function(v) PickSize(v) end)
			b:Buttons({
				{ "Switch window now", function() Toggle() end },
				{ "Reset minimap button", function() db.angle = defaults.angle; UpdatePosition() end },
			})
		end,
	})
end
