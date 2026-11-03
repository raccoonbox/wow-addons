-- WindowToggle: click the minimap button to switch between a maximised window
-- and a small window (1024 wide by default, same shape as your screen).
-- Drag the button to move it around the minimap.
-- /wt size <W>x<H>  sets the small window size, e.g. /wt size 1280x720
-- /wt size auto     back to the default (1024 wide, your screen's shape)
-- /wt list          shows the sizes the client accepts
-- /wt reset         puts the button back to its default position

local defaults = { angle = 200, small = "auto" }

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99WindowToggle:|r " .. msg)
end

-- Largest resolution the client offers = the screen's native size.
local function NativeSize()
	local bestW, bestH = 0, 0
	local list = { GetScreenResolutions() }
	for i = 1, table.getn(list) do
		local _, _, w, h = string.find(list[i], "(%d+)x(%d+)")
		w, h = tonumber(w), tonumber(h)
		if w and h and w * h > bestW * bestH then
			bestW, bestH = w, h
		end
	end
	if bestW == 0 then
		local _, _, w, h = string.find(GetCVar("gxResolution") or "", "(%d+)x(%d+)")
		bestW, bestH = tonumber(w) or 1920, tonumber(h) or 1080
	end
	return bestW, bestH
end

local function IsMaximised()
	return GetCVar("gxWindow") == "1" and GetCVar("gxMaximize") == "1"
end

local function SetMaximised()
	local w, h = NativeSize()
	SetCVar("gxWindow", "1")
	SetCVar("gxMaximize", "1")
	SetCVar("gxResolution", w .. "x" .. h)
	RestartGx()
end

-- Use the chosen small size if the client lists it. Otherwise fall back to the
-- closest listed size with the same shape as the screen, so the UI only
-- scales down evenly and nothing shifts sideways.
local function SmallSize()
	local nw, nh = NativeSize()
	local aspect = nw / nh
	local tw, th
	if WindowToggleDB.small == "auto" then
		-- 1024 wide, height from this screen's own shape (16:9 -> 576, 16:10 -> 640, 21:9 -> ~438)
		tw = 1024
		th = math.floor(1024 / aspect / 2 + 0.5) * 2
	else
		local _, _, w, h = string.find(WindowToggleDB.small, "(%d+)x(%d+)")
		tw, th = tonumber(w) or 1024, tonumber(h) or 576
	end
	local bestW, bestH, bestDiff
	local list = { GetScreenResolutions() }
	for i = 1, table.getn(list) do
		local _, _, lw, lh = string.find(list[i], "(%d+)x(%d+)")
		lw, lh = tonumber(lw), tonumber(lh)
		if lw == tw and lh == th and math.abs(lw / lh - aspect) < 0.02 then
			return tw, th
		end
		if lw and lh and math.abs(lw / lh - aspect) < 0.02 then
			local diff = math.abs(lw * lh - tw * th)
			if not bestDiff or diff < bestDiff then
				bestW, bestH, bestDiff = lw, lh, diff
			end
		end
	end
	-- A size you typed yourself is used as-is if the client lists it, even with a
	-- different shape. Otherwise prefer a listed size with the screen's shape.
	if WindowToggleDB.small ~= "auto" then
		for i = 1, table.getn(list) do
			if list[i] == tw .. "x" .. th then return tw, th end
		end
	end
	if bestW then
		return bestW, bestH
	end
	return tw, th
end

local function SetSmall()
	local sw, sh = SmallSize()
	Print("switching to " .. sw .. "x" .. sh .. " window.")
	SetCVar("gxWindow", "1")
	SetCVar("gxMaximize", "0")
	SetCVar("gxResolution", sw .. "x" .. sh)
	RestartGx()
end

local function Toggle()
	if IsMaximised() then
		SetSmall()
	else
		SetMaximised()
	end
end

-- Minimap button -----------------------------------------------------------

local button = CreateFrame("Button", "WindowToggleMinimapButton", Minimap)
button:SetWidth(31)
button:SetHeight(31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
button:RegisterForClicks("LeftButtonUp")
button:RegisterForDrag("LeftButton")
button:SetMovable(true)

local icon = button:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(53)
border:SetHeight(53)
border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

local function UpdatePosition()
	local a = math.rad(WindowToggleDB.angle)
	local x, y = math.cos(a) * 80, math.sin(a) * 80
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function DragUpdate()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	cx, cy = cx / scale, cy / scale
	WindowToggleDB.angle = math.deg(math.atan2(cy - my, cx - mx))
	UpdatePosition()
end

local justDragged = false

button:SetScript("OnDragStart", function()
	this:SetScript("OnUpdate", DragUpdate)
end)
button:SetScript("OnDragStop", function()
	this:SetScript("OnUpdate", nil)
	justDragged = true
end)
button:SetScript("OnClick", function()
	if justDragged then
		justDragged = false
		return
	end
	Toggle()
end)
button:SetScript("OnMouseDown", function()
	justDragged = false
end)
button:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:AddLine("WindowToggle")
	if IsMaximised() then
		local sw, sh = SmallSize()
		GameTooltip:AddLine("Click: small window (" .. sw .. "x" .. sh .. ")", 1, 1, 1)
	else
		GameTooltip:AddLine("Click: maximised window", 1, 1, 1)
	end
	GameTooltip:AddLine("Drag: move button", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

-- Saved settings + slash command ---------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("VARIABLES_LOADED")
loader:SetScript("OnEvent", function()
	WindowToggleDB = WindowToggleDB or {}
	for k, v in pairs(defaults) do
		if WindowToggleDB[k] == nil then WindowToggleDB[k] = v end
	end
	-- older versions saved the fixed 16:9 default; switch those to auto
	if WindowToggleDB.small == "1024x576" then WindowToggleDB.small = "auto" end
	UpdatePosition()
end)

SLASH_WINDOWTOGGLE1 = "/wt"
SlashCmdList["WINDOWTOGGLE"] = function(msg)
	local _, _, cmd, arg = string.find(msg or "", "^(%S*)%s*(.*)$")
	cmd = string.lower(cmd or "")
	if cmd == "size" then
		local _, _, w, h = string.find(arg or "", "^(%d+)%s*[xX]%s*(%d+)$")
		if string.lower(arg or "") == "auto" then
			WindowToggleDB.small = "auto"
			Print("small window back to default (1024 wide, your screen's shape).")
		elseif w and h then
			WindowToggleDB.small = w .. "x" .. h
			Print("small window set to " .. WindowToggleDB.small .. ".")
		else
			Print("usage: /wt size 1024x576")
		end
	elseif cmd == "list" then
		local list = { GetScreenResolutions() }
		Print("available sizes: " .. table.concat(list, ", "))
		Print("current: " .. (GetCVar("gxResolution") or "?") .. ", window " .. (GetCVar("gxWindow") or "?") .. ", maximise " .. (GetCVar("gxMaximize") or "?"))
	elseif cmd == "reset" then
		WindowToggleDB.angle = defaults.angle
		UpdatePosition()
		Print("button position reset.")
	elseif cmd == "" then
		Toggle()
	else
		Print("/wt (toggle), /wt size 1024x576, /wt list, /wt reset")
	end
end
