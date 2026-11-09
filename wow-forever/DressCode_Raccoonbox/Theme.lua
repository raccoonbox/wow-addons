-- Dress Code [Raccoonbox] for WoW Forever - every visual decision lives here (colours, fonts, spacing,
-- shapes), so the look can follow the style board without touching the logic. Neutral "Lookbook" for now:
-- calm, spacious, thin lines, the character as the star. UI.lua only reads these tokens.
local _, DC = ...

local THEMES = {
	dark = {
		bg = { 0.075, 0.075, 0.085, 0.97 },  -- window
		surface = { 0.12, 0.12, 0.13, 1 },   -- cards
		hover = { 0.17, 0.17, 0.18, 1 },
		stage = { 0.10, 0.10, 0.11, 1 },     -- behind the character
		line = { 1, 1, 1, 0.08 },
		text = { 0.94, 0.94, 0.94, 1 },
		muted = { 0.60, 0.60, 0.62, 1 },
		accent = { 1, 0.60, 0, 1 },          -- Raccoonbox orange ff9900
		good = { 0.45, 0.85, 0.50, 1 },
		bad = { 0.92, 0.38, 0.38, 1 },
	},
	light = {
		bg = { 0.97, 0.96, 0.94, 0.98 },
		surface = { 1, 1, 1, 1 },
		hover = { 0.93, 0.92, 0.90, 1 },
		stage = { 0.92, 0.91, 0.89, 1 },
		line = { 0, 0, 0, 0.10 },
		text = { 0.13, 0.13, 0.13, 1 },
		muted = { 0.45, 0.45, 0.47, 1 },
		accent = { 0.90, 0.50, 0, 1 },
		good = { 0.15, 0.60, 0.25, 1 },
		bad = { 0.80, 0.20, 0.20, 1 },
	},
}

local T = { space = 8, pad = 10, row = 46, cell = 34, chip = 20 }
DC.T = T

-- fonts: built-in for now; the style board's own (OFL) font files go in Fonts/ and are named here
local FONT_BODY = "Fonts\\FRIZQT__.TTF" -- the game's own font, like its menus
local FONT_TITLE = "Fonts\\FRIZQT__.TTF"
local function font(name, file, size, flags)
	local f = CreateFont(name)
	f:SetFont(file, size, flags or "")
	return f
end
T.fontTitle = font("DressCodeFontTitle", FONT_TITLE, 20)
T.fontHeading = font("DressCodeFontHeading", FONT_BODY, 14)
T.fontBody = font("DressCodeFontBody", FONT_BODY, 12)
T.fontSmall = font("DressCodeFontSmall", FONT_BODY, 10)
T.gold = { 1, 0.82, 0, 1 } -- the game's gold (titles, headings)

-- apply the chosen colour set (DressCodeDB.theme = "dark" | "light")
function DC.ApplyTheme(name)
	local c = THEMES[name] or THEMES.dark
	for k, v in pairs(c) do T[k] = v end
	T.name = THEMES[name] and name or "dark"
	for _, f in ipairs({ T.fontBody, T.fontSmall }) do f:SetTextColor(unpack(T.text)) end
	T.fontTitle:SetTextColor(unpack(T.gold))
	T.fontHeading:SetTextColor(unpack(T.gold))
end
DC.ApplyTheme("dark")

---------------------------------------------------------------------------- small building blocks

-- a flat colour texture (shapes from Media/ replace these once the style board is in)
function DC.Fill(frame, color, layer, sub)
	local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
	t:SetColorTexture(unpack(color))
	t:SetAllPoints(frame)
	return t
end

-- a one-pixel line along an edge of a frame ("TOP", "BOTTOM", "LEFT", "RIGHT")
function DC.Edge(frame, edge, color)
	local t = frame:CreateTexture(nil, "BORDER")
	t:SetColorTexture(unpack(color or T.line))
	if edge == "TOP" or edge == "BOTTOM" then
		t:SetPoint(edge .. "LEFT") t:SetPoint(edge .. "RIGHT") t:SetHeight(1)
	else
		t:SetPoint("TOP" .. edge) t:SetPoint("BOTTOM" .. edge) t:SetWidth(1)
	end
	return t
end

function DC.Text(parent, fontObject, color)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(fontObject or T.fontBody)
	if color then fs:SetTextColor(unpack(color)) end
	fs:SetJustifyH("LEFT")
	return fs
end

-- the game's own panel look (like its menus and tooltips): dark background, soft rounded border
local PANEL = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
function DC.Panel(frame, alpha)
	if not frame.SetBackdrop and BackdropTemplateMixin then
		Mixin(frame, BackdropTemplateMixin)
		frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
	end
	if not frame.SetBackdrop then return DC.Fill(frame, T.bg) end
	frame:SetBackdrop(PANEL)
	frame:SetBackdropColor(0.06, 0.06, 0.07, alpha or 0.95)
	frame:SetBackdropBorderColor(0.55, 0.55, 0.58, 1)
end

-- the game's gold highlight bar (hover and "selected"), hidden until used
function DC.Highlight(frame)
	local t = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
	t:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	t:SetBlendMode("ADD")
	t:SetPoint("TOPLEFT", 2, -1)
	t:SetPoint("BOTTOMRIGHT", -2, 1)
	t:Hide()
	return t
end

-- a text button in the game's menu style: kind = "plain" | "accent" (always lit) | "chip" (toggle: lit when on)
function DC.Button(parent, label, kind, width, height)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 80, height or 24)
	b.bg = DC.Fill(b, { 0, 0, 0, 0.35 })
	b.lit = DC.Highlight(b)
	b.label = DC.Text(b, kind == "chip" and T.fontSmall or T.fontBody)
	b.label:SetPoint("CENTER")
	b.label:SetJustifyH("CENTER")
	b.label:SetText(label)
	b.kind = kind or "plain"
	if not width then b:SetWidth(math.max(height or 24, b.label:GetStringWidth() + 22)) end
	function b:SetOn(on)
		self.on = on
		local lit = self.kind == "accent" or on
		self.lit:SetShown(lit)
		self.lit:SetAlpha(1)
		if self.kind == "accent" then self.label:SetTextColor(unpack(T.gold))
		elseif lit then self.label:SetTextColor(1, 1, 1, 1)
		else self.label:SetTextColor(unpack(self.kind == "chip" and T.muted or T.text)) end
	end
	b:SetScript("OnEnter", function(self)
		if not (self.on or self.kind == "accent") then self.lit:SetAlpha(0.55) self.lit:Show() self.label:SetTextColor(1, 1, 1, 1) end
		if self.tip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.tip[1], 1, 1, 1)
			if self.tip[2] then GameTooltip:AddLine(self.tip[2], nil, nil, nil, true) end
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self) self:SetOn(self.on) GameTooltip_Hide() end)
	b:SetOn(false)
	return b
end

-- a simple single-line input box in the theme
function DC.Input(parent, width, numeric)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetSize(width, 24)
	e:SetAutoFocus(false)
	e:SetFontObject(T.fontBody)
	e:SetTextInsets(10, 10, 0, 0)
	if numeric then e:SetNumeric(true) e:SetMaxLetters(2) end
	DC.Panel(e, 0.9)
	e:SetScript("OnEscapePressed", e.ClearFocus)
	e:SetScript("OnEnterPressed", e.ClearFocus)
	-- the border turns gold while typing
	e:SetScript("OnEditFocusGained", function(self) if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(T.gold)) end end)
	e:SetScript("OnEditFocusLost", function(self) if self.SetBackdropBorderColor then self:SetBackdropBorderColor(0.55, 0.55, 0.58, 1) end end)
	return e
end

-- item quality colour as r, g, b
function DC.QualityColor(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end
