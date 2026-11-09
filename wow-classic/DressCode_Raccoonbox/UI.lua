-- Dress Code [Raccoonbox] - window
--  left:  stat checklist + text search -> items that beat what you wear; Browse; saved outfits
--  right: paper doll like the character window. Visible slots have two cells (outfit 1 and 2),
--         each cell can be locked; switch the whole outfit or put on single cells.
local DC = DressCode
local game_dressup = DressUpItemLink -- the game's dressing-room function (works on OctoWoW, a plain TryOn doesn't)

local ROWS, ROW_H, CELL, GAP = 8, 28, 30, 4
local QUALITY = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }
local AHEAD = { 0, 1, 3, 5 }

local mode = "find"
local entries = {}
local browse_cat, browse_list
local pending, load_queue = {}, {}
local shown = {} -- slot -> cell currently on the model (nil = follows the active outfit)

local function say(text) DEFAULT_CHAT_FRAME:AddMessage("|cffff9900Dress Code:|r " .. text) end

---------------------------------------------------------------------------- main frame

local f = CreateFrame("Frame", "DressCodeFrame", UIParent)
f:SetWidth(960) f:SetHeight(650)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
f:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
local f_bg = f:CreateTexture(nil, "BACKGROUND")
f_bg:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -11)
f_bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -11, 11)
f_bg:SetTexture(.05, .05, .07, .94)
f:SetMovable(true) f:EnableMouse(true) f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function() this:StartMoving() end)
f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
f:SetFrameStrata("HIGH")
f:Hide()
tinsert(UISpecialFrames, "DressCodeFrame")

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -18)
title:SetText("Dress Code")
local by = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
by:SetPoint("LEFT", title, "RIGHT", 6, -1)
by:SetText("by Raccoonbox")
local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
-- one click always closes, even with the dressing room drawn above Dress Code
close:SetFrameStrata("FULLSCREEN_DIALOG")
close:SetScript("OnClick", function() f:Hide() end)

local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 22, 18)
status:SetWidth(860) status:SetJustifyH("LEFT")

local refresh -- forward

---------------------------------------------------------------------------- slot dropdown + look-ahead

local SLOT_CHOICES = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 13, 16, 17, 18 }
local slot_drop = CreateFrame("Frame", "DressCodeSlotDrop", f, "UIDropDownMenuTemplate")
slot_drop:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -42)

local function init_slot()
	local info = {}
	info.text = "All slots"
	info.func = function() DressCodeChar.slot = nil UIDropDownMenu_SetText("All slots", slot_drop) refresh() end
	info.checked = DressCodeChar.slot == nil
	UIDropDownMenu_AddButton(info)
	for _, s in ipairs(SLOT_CHOICES) do
		local slot = s
		info = {}
		info.text = DC.SLOTS[slot]
		info.func = function() DressCodeChar.slot = slot UIDropDownMenu_SetText(DC.SLOTS[slot], slot_drop) refresh() end
		info.checked = DressCodeChar.slot == slot
		UIDropDownMenu_AddButton(info)
	end
end

-- levels: "Now" = only items you can wear at your level; or type how many levels above you to show
local now_btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
now_btn:SetWidth(50) now_btn:SetHeight(22)
now_btn:SetPoint("LEFT", slot_drop, "RIGHT", -6, 2)
now_btn:SetText("Now")
local ahead_label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ahead_label:SetPoint("LEFT", now_btn, "RIGHT", 8, 0)
ahead_label:SetText("+ levels:")
local ahead_box = CreateFrame("EditBox", "DressCodeAhead", f, "InputBoxTemplate")
ahead_box:SetWidth(32) ahead_box:SetHeight(20)
ahead_box:SetPoint("LEFT", ahead_label, "RIGHT", 8, 0)
ahead_box:SetAutoFocus(false)
ahead_box:SetMaxLetters(2)
ahead_box:SetNumeric(true)
local function update_ahead()
	local a = DressCodeChar.ahead or 0
	if not ahead_box.focused then ahead_box:SetText(a > 0 and tostring(a) or "") end
	if a == 0 then now_btn:LockHighlight() else now_btn:UnlockHighlight() end
end
local function set_ahead(n)
	DressCodeChar.ahead = math.max(0, math.min(60, n or 0))
	update_ahead()
	refresh()
end
now_btn:SetScript("OnClick", function() ahead_box:ClearFocus() set_ahead(0) end)
now_btn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText("Now")
	GameTooltip:AddLine("Only items you can wear at your level (" .. UnitLevel("player") .. ").", 1, 1, 1, 1)
	GameTooltip:Show()
end)
now_btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
ahead_box:SetScript("OnEnterPressed", function() this:ClearFocus() end)
ahead_box:SetScript("OnEscapePressed", function() this:ClearFocus() end)
ahead_box:SetScript("OnEditFocusGained", function() this.focused = true end)
-- apply while typing (no need to press Enter)
ahead_box:SetScript("OnTextChanged", function()
	if this.focused then set_ahead(tonumber(this:GetText()) or 0) end
end)
ahead_box:SetScript("OnEditFocusLost", function() this.focused = nil set_ahead(tonumber(this:GetText())) end)
ahead_box:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText("Levels above you")
	GameTooltip:AddLine("Type how many levels above your own to show items for (60 = everything), then press Enter.", 1, 1, 1, 1)
	GameTooltip:Show()
end)
ahead_box:SetScript("OnLeave", function() GameTooltip:Hide() end)

local clear_btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
clear_btn:SetWidth(90) clear_btn:SetHeight(22)
clear_btn:SetPoint("LEFT", ahead_box, "RIGHT", 10, 0)
clear_btn:SetText("Clear ticks")

---------------------------------------------------------------------------- stat checklist + text search

local checks = {}
for i, stat in ipairs(DC.STATS) do
	local s = stat
	local col = math.mod(i - 1, 3)
	local row = math.floor((i - 1) / 3)
	local cb = CreateFrame("CheckButton", "DressCodeStat" .. i, f, "UICheckButtonTemplate")
	cb:SetWidth(22) cb:SetHeight(22)
	cb:SetPoint("TOPLEFT", f, "TOPLEFT", 20 + col * 132, -72 - row * 21)
	local label = getglobal("DressCodeStat" .. i .. "Text")
	label:SetText(s.label)
	label:SetFontObject(GameFontHighlightSmall)
	cb:SetScript("OnClick", function()
		DressCodeChar.keys[s.key] = this:GetChecked() and true or nil
		refresh()
	end)
	checks[s.key] = cb
end

local search_label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
search_label:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -206)
search_label:SetText("Text:")
local search = CreateFrame("EditBox", "DressCodeSearch", f, "InputBoxTemplate")
search:SetWidth(220) search:SetHeight(20)
search:SetPoint("LEFT", search_label, "RIGHT", 10, 0)
search:SetAutoFocus(false)
search:SetScript("OnEnterPressed", function() this:ClearFocus() end)
search:SetScript("OnEscapePressed", function() this:ClearFocus() end)
search:SetScript("OnTextChanged", function()
	DressCodeChar.search = strlower(this:GetText() or "")
	if this.ready then refresh() end
end)
local search_hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
search_hint:SetPoint("LEFT", search, "RIGHT", 8, 0)
search_hint:SetText("e.g. vampir, chance on hit")

clear_btn:SetScript("OnClick", function()
	DressCodeChar.keys = {}
	for _, cb in pairs(checks) do cb:SetChecked(nil) end
	search:SetText("")
	refresh()
end)

---------------------------------------------------------------------------- list

local list = CreateFrame("Frame", nil, f)
list:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -230)
list:SetWidth(400) list:SetHeight(ROWS * ROW_H)
local scroll = CreateFrame("ScrollFrame", "DressCodeScroll", list, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)

local rows = {}
local render -- forward
for i = 1, ROWS do
	local r = CreateFrame("Button", nil, list)
	r:SetWidth(380) r:SetHeight(ROW_H)
	r:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * ROW_H)
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetWidth(24) r.icon:SetHeight(24)
	r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
	r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.right:SetPoint("TOPRIGHT", r, "TOPRIGHT", -4, -3)
	r.right:SetJustifyH("RIGHT")
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, 0)
	r.name:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
	r.name:SetJustifyH("LEFT")
	r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 6, 0)
	r.sub:SetPoint("RIGHT", r, "RIGHT", -4, 0)
	r.sub:SetJustifyH("LEFT")
	rows[i] = r
end
scroll:SetScript("OnVerticalScroll", function() FauxScrollFrame_OnVerticalScroll(ROW_H, render) end)

---------------------------------------------------------------------------- details panel

local details = CreateFrame("Frame", nil, f)
details:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -6)
details:SetWidth(400) details:SetHeight(92)
details:SetBackdrop({
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
details:SetBackdropColor(0, 0, 0, .6)
details:SetBackdropBorderColor(.4, .4, .4, 1)
local d_title = details:CreateFontString(nil, "OVERLAY", "GameFontNormal")
d_title:SetPoint("TOPLEFT", details, "TOPLEFT", 8, -7)
d_title:SetPoint("RIGHT", details, "RIGHT", -8, 0)
d_title:SetJustifyH("LEFT")
d_title:SetText("Click an item to see where to get it.")
local d_text = details:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
d_text:SetPoint("TOPLEFT", d_title, "BOTTOMLEFT", 0, -3)
d_text:SetWidth(384) d_text:SetHeight(58)
d_text:SetJustifyH("LEFT") d_text:SetJustifyV("TOP")
-- OctoWoW database links: WoW can't open web pages, so the link is shown selected, ready for Ctrl+C
local DB_URL = "https://octowow.st/db/?"
StaticPopupDialogs["DRESSCODE_DB_LINK"] = {
	text = "%s\n\nPress Ctrl+C to copy, then paste it in your browser.",
	button1 = OKAY,
	hasEditBox = 1, hasWideEditBox = 1, maxLetters = 200, timeout = 0, whileDead = 1, hideOnEscape = 1,
	OnShow = function()
		local box = getglobal(this:GetName() .. "WideEditBox") or getglobal(this:GetName() .. "EditBox")
		box:SetText(DressCode.db_link or "")
		box:SetFocus()
		box:HighlightText()
	end,
	EditBoxOnEscapePressed = function() this:GetParent():Hide() end,
	EditBoxOnEnterPressed = function() this:GetParent():Hide() end,
}

local function show_link(what, url)
	DressCode.db_link = url
	StaticPopup_Show("DRESSCODE_DB_LINK", what)
end

local quest_link_btn = CreateFrame("Button", nil, details, "UIPanelButtonTemplate")
quest_link_btn:SetWidth(110) quest_link_btn:SetHeight(18)
quest_link_btn:SetPoint("BOTTOMRIGHT", details, "BOTTOMRIGHT", -6, 6)
quest_link_btn:SetText("Quest in DB")
quest_link_btn:Hide()
quest_link_btn:SetScript("OnClick", function()
	show_link("OctoWoW database: " .. this.label, DB_URL .. "quest=" .. this.qid)
end)

local item_link_btn = CreateFrame("Button", nil, details, "UIPanelButtonTemplate")
item_link_btn:SetWidth(110) item_link_btn:SetHeight(18)
item_link_btn:SetText("Item in DB")
item_link_btn:Hide()
item_link_btn:SetScript("OnClick", function()
	show_link("OctoWoW database: " .. this.label, DB_URL .. "item=" .. this.id)
end)

function DC.ShowDetails(id, gaintext)
	local item = DC.Item(id)
	local name = item and item.name or (GetItemInfo(id)) or ("item " .. id)
	d_title:SetText(name .. (gaintext and gaintext ~= "" and ("  |cff33ff33" .. gaintext .. "|r") or ""))
	local lines, link_quest = {}, nil
	local quests = DC.Quests(id)
	for _, q in ipairs(quests) do
		local mine = DC.QuestForMe(q)
		tinsert(lines, (mine and "|cffffd100" or "|cffff5555") .. "Quest: " .. q.title .. " (L" .. (q.level > 0 and q.level or "?")
			.. (q.minlevel and q.minlevel > 0 and (", from L" .. q.minlevel) or "")
			.. (q.instance ~= "" and (", " .. q.instance) or "") .. (q.faction ~= "" and (", " .. q.faction) or "") .. ")|r"
			.. (q.classes ~= "" and (" - " .. q.classes .. " only") or ""))
		if q.giver ~= "" then tinsert(lines, "From: " .. q.giver) end
		if q.note ~= "" then
			local note = q.note
			if strlen(note) > 140 then note = strsub(note, 1, 137) .. "..." end
			tinsert(lines, "|cffaaaaaa" .. note .. "|r")
		end
		if q.id and q.id > 0 and (mine or not link_quest) then link_quest = q end
	end
	for _, src in ipairs(DC.Sources(id)) do
		if not strfind(src, "^Quest") or table.getn(quests) == 0 then tinsert(lines, src) end
	end
	d_text:SetText(table.concat(lines, "\n"))
	-- database buttons: the item, and its quest when there is one
	item_link_btn.id, item_link_btn.label = id, name
	item_link_btn:ClearAllPoints()
	if link_quest then
		quest_link_btn.qid, quest_link_btn.label = link_quest.id, link_quest.title
		quest_link_btn:Show()
		item_link_btn:SetPoint("RIGHT", quest_link_btn, "LEFT", -4, 0)
	else
		quest_link_btn:Hide()
		item_link_btn:SetPoint("BOTTOMRIGHT", details, "BOTTOMRIGHT", -6, 6)
	end
	item_link_btn:Show()
end

---------------------------------------------------------------------------- paper doll

-- the model area. Dress Code borrows the game's own dressing-room model (DressUpModel) while the
-- window is open - that one reliably shows tried-on items - and gives it back when the window closes.
local holder = CreateFrame("Frame", nil, f)
holder:SetWidth(326) holder:SetHeight(400)
holder:SetPoint("TOPLEFT", f, "TOPLEFT", 528, -60)
holder:EnableMouse(true)
local model_bg = holder:CreateTexture(nil, "BACKGROUND")
model_bg:SetAllPoints(holder)
model_bg:SetTexture(0, 0, 0, 0)

local own_model = CreateFrame("DressUpModel", "DressCodeModel", holder)
own_model:SetAllPoints(holder)
local model = own_model -- the model in use
own_model:Hide()
local holder_note = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
holder_note:SetPoint("CENTER", holder, "CENTER", 0, 0)
holder_note:SetWidth(190)
holder_note:SetText("")

-- the game's dressing room: opened next to Dress Code, items are put on like a normal Ctrl-click
local opened_room
local borrow_model -- forward (defined below)
local room_saved -- the dressing room's own strata/scale, restored when Dress Code closes

-- drag to turn: an invisible area over the dressing room's character (the model itself is left
-- untouched - changing it breaks trying items on). The top strip stays free for the turn buttons.
local turner
local function make_turner()
	if turner or not (DressUpFrame and DressUpModel) then return end
	turner = CreateFrame("Frame", "DressCodeTurner", DressUpFrame)
	turner:SetPoint("TOPLEFT", DressUpModel, "TOPLEFT", 0, -40)
	turner:SetPoint("BOTTOMRIGHT", DressUpModel, "BOTTOMRIGHT", 0, 0)
	turner:SetFrameLevel(DressUpModel:GetFrameLevel() + 5)
	turner:EnableMouse(true)
	turner:SetScript("OnMouseDown", function() this.x = GetCursorPosition() end)
	turner:SetScript("OnMouseUp", function() this.x = nil end)
	turner:SetScript("OnHide", function() this.x = nil end)
	turner:SetScript("OnUpdate", function()
		if not this.x then return end
		local x = GetCursorPosition()
		DressUpModel:SetFacing(DressUpModel:GetFacing() + (x - this.x) / 80)
		this.x = x
	end)
end

local fit_scene -- defined below

-- where the visible scene (background pictures, or the model) sits inside the dressing room window,
-- in the window's own units: { cx, cy = centre offset from the window centre, w, h = size }
local function scene_geometry()
	local fl, fb = DressUpFrame:GetLeft(), DressUpFrame:GetBottom()
	local fw, fh = DressUpFrame:GetWidth(), DressUpFrame:GetHeight()
	if not (fl and fb and fw and fw > 0) then return end
	local fs = DressUpFrame:GetEffectiveScale()
	local l, r, b, t
	for _, part in ipairs(room_saved.backgrounds or { DressUpModel }) do
		-- textures have no scale of their own in 1.12: they use their window's
		local k = (part.GetEffectiveScale and part:GetEffectiveScale() or fs) / fs
		local pl, pr, pb, pt = part:GetLeft(), part:GetRight(), part:GetBottom(), part:GetTop()
		if pl and pr and pb and pt then
			pl, pr, pb, pt = pl * k - fl, pr * k - fl, pb * k - fb, pt * k - fb
			l = l and math.min(l, pl) or pl
			r = r and math.max(r, pr) or pr
			b = b and math.min(b, pb) or pb
			t = t and math.max(t, pt) or pt
		end
	end
	if not (l and r > l and t > b) then return end
	return { cx = (l + r) / 2 - fw / 2, cy = (b + t) / 2 - fh / 2, w = r - l, h = t - b }
end

fit_scene = function()
	if not room_saved then return end
	room_saved.geom = room_saved.geom or scene_geometry()
	local g = room_saved.geom
	if not g then return end
	local hs = holder:GetEffectiveScale()
	local parent = DressUpFrame:GetParent()
	local ps = parent and parent:GetEffectiveScale() or UIParent:GetEffectiveScale()
	-- the scene fills the middle (in screen pixels) without covering the slot columns
	local pixels = math.min(holder:GetWidth() * hs / g.w, holder:GetHeight() * hs / g.h)
	DressUpFrame:SetScale(pixels / ps)
	DressUpFrame:ClearAllPoints()
	DressUpFrame:SetPoint("CENTER", holder, "CENTER", -g.cx, -g.cy) -- offsets in the window's own units
end

local function dressing_room()
	if not (DressUpFrame and DressUpModel) then own_model:Show() return own_model end
	if not DressUpFrame:IsVisible() then
		ShowUIPanel(DressUpFrame)
		opened_room = true
	end
	if not room_saved then
		room_saved = { strata = DressUpFrame:GetFrameStrata(), scale = DressUpFrame:GetScale(), hidden = {} }
		-- keep only the scene: hide the frame art, portrait, title and text (background pictures stay)
		for _, region in ipairs({ DressUpFrame:GetRegions() }) do
			local name = region:GetName() or ""
			if region:IsShown() and not strfind(name, "Background") then
				tinsert(room_saved.hidden, region)
				region:Hide()
			elseif region:IsShown() then
				room_saved.backgrounds = room_saved.backgrounds or {}
				tinsert(room_saved.backgrounds, region)
			end
		end
		-- and its buttons (Reset, Close, X); the model with its turn buttons stays
		for _, child in ipairs({ DressUpFrame:GetChildren() }) do
			if child ~= DressUpModel and child ~= turner and child:IsShown() then
				tinsert(room_saved.hidden, child)
				child:Hide()
			end
		end
	end
	DressUpFrame:SetFrameStrata("DIALOG")
	-- its invisible frame is bigger than the scene: let clicks through to the slot cells
	-- (the model's turn buttons and the drag area are separate frames and still work)
	DressUpFrame:EnableMouse(false)
	-- size and place it; never let a problem here stop the outfit from showing
	local ok = pcall(fit_scene)
	if not ok or not room_saved.geom then holder.refit = true end
	make_turner()
	return DressUpModel
end

local function close_dressing_room()
	if not room_saved then return end
	for _, part in ipairs(room_saved.hidden or {}) do part:Show() end
	DressUpFrame:EnableMouse(true)
	DressUpFrame:SetFrameStrata(room_saved.strata)
	DressUpFrame:SetScale(room_saved.scale)
	if opened_room and DressUpFrame:IsVisible() then HideUIPanel(DressUpFrame) end
	opened_room, room_saved = nil, nil
end

-- try an item on: full item link first (what a bag/chat Ctrl-click passes), short code as fallback
local borrowed -- the game's dressing-room model while Dress Code holds it
local function item_link(id)
	local name, itemstring, quality = GetItemInfo(id)
	if not (name and itemstring) then return "item:" .. id .. ":0:0:0" end
	local _, _, _, hex = GetItemQualityColor(quality or 1)
	return (hex or "|cffffffff") .. "|H" .. itemstring .. "|h[" .. name .. "]|h|r"
end

local function try_item(m, id)
	if m == DressUpModel and game_dressup then
		game_dressup(item_link(id)) -- exactly what a normal Ctrl-click does (once: twice can take it off)
	else
		m:TryOn(item_link(id))
	end
end

borrow_model = function()
	if borrowed or not DressUpModel then return end
	borrowed = { parent = DressUpModel:GetParent(), scale = DressUpModel:GetScale(),
		w = DressUpModel:GetWidth(), h = DressUpModel:GetHeight(), points = {} }
	for i = 1, 4 do
		local ok, point, rel, relpoint, x, y = pcall(DressUpModel.GetPoint, DressUpModel, i)
		if ok and point then tinsert(borrowed.points, { point, rel, relpoint, x, y }) end
	end
	if table.getn(borrowed.points) == 0 then
		local point, rel, relpoint, x, y = DressUpModel:GetPoint()
		if point then tinsert(borrowed.points, { point, rel, relpoint, x, y }) end
	end
	if DressUpFrame and DressUpFrame:IsVisible() then HideUIPanel(DressUpFrame) end
	DressUpModel:SetParent(holder)
	DressUpModel:SetScale(1)
	DressUpModel:ClearAllPoints()
	DressUpModel:SetAllPoints(holder)
	DressUpModel:SetFrameLevel(holder:GetFrameLevel() + 1)
	DressUpModel:EnableMouse(false) -- turning is done by the holder
	DressUpModel:Show()
	borrowed.children = {}
	for _, child in ipairs({ DressUpModel:GetChildren() }) do
		if child:IsShown() then tinsert(borrowed.children, child) child:Hide() end
	end
	own_model:Hide()
	model = DressUpModel
	model.loaded = nil
end

local function give_back_model()
	if not borrowed then return end
	DressUpModel:SetParent(borrowed.parent)
	DressUpModel:SetScale(borrowed.scale)
	DressUpModel:ClearAllPoints()
	for _, pt in ipairs(borrowed.points) do DressUpModel:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
	DressUpModel:SetWidth(borrowed.w) DressUpModel:SetHeight(borrowed.h)
	DressUpModel:EnableMouse(true)
	for _, child in ipairs(borrowed.children or {}) do child:Show() end
	DressUpModel:SetUnit("player")
	borrowed = nil
	own_model:Show()
	model = own_model
	model.loaded = nil
end

holder:SetScript("OnMouseDown", function() this.rotating = GetCursorPosition() end)
holder:SetScript("OnMouseUp", function() this.rotating = nil end)
holder:SetScript("OnUpdate", function()
	if this.refit and room_saved then
		this.refit = nil
		local ok = pcall(fit_scene)
		if not ok or not room_saved.geom then this.refit = true end
	end
	if model.reapply and GetTime() >= model.reapply[1] then
		tremove(model.reapply, 1)
		for _, id in ipairs(model.wear or {}) do try_item(model, id) end
		if table.getn(model.reapply) == 0 then model.reapply = nil end
	end
	if this.rotating then
		local x = GetCursorPosition()
		model:SetFacing(model:GetFacing() + (x - this.rotating) / 80)
		this.rotating = x
	end
end)

-- slot layout like the character window; double = two cells (outfit 1 and 2)
local DOLL = {
	-- only slots you can see on the character (neck, rings and trinkets never show)
	{ slot = 1, col = "L", row = 1, double = true, tex = "Head" },
	{ slot = 3, col = "L", row = 2, double = true, tex = "Shoulder" },
	{ slot = 15, col = "L", row = 3, double = true, tex = "Chest" },
	{ slot = 5, col = "L", row = 4, double = true, tex = "Chest" },
	{ slot = 4, col = "L", row = 5, double = true, tex = "Shirt" },
	{ slot = 19, col = "L", row = 6, double = true, tex = "Tabard" },
	{ slot = 9, col = "L", row = 7, double = true, tex = "Wrists" },
	{ slot = 10, col = "R", row = 1, double = true, tex = "Hands" },
	{ slot = 6, col = "R", row = 2, double = true, tex = "Waist" },
	{ slot = 7, col = "R", row = 3, double = true, tex = "Legs" },
	{ slot = 8, col = "R", row = 4, double = true, tex = "Feet" },
	{ slot = 16, col = "B", row = 1, double = true, tex = "MainHand" },
	{ slot = 17, col = "B", row = 2, double = true, tex = "SecondaryHand" },
	{ slot = 18, col = "B", row = 3, double = true, tex = "Ranged" },
}
local SLOT_NAMES = { [4] = "Shirt", [19] = "Tabard" }
local function slot_name(slot) return DC.SLOTS[slot] or SLOT_NAMES[slot] or ("slot " .. slot) end

local EQUIPLOC_SLOTS = { INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5,
	INVTYPE_ROBE = 5, INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
	INVTYPE_FINGER = 11, INVTYPE_TRINKET = 13, INVTYPE_CLOAK = 15, INVTYPE_WEAPON = 16, INVTYPE_SHIELD = 17,
	INVTYPE_2HWEAPON = 16, INVTYPE_WEAPONMAINHAND = 16, INVTYPE_WEAPONOFFHAND = 17, INVTYPE_HOLDABLE = 17,
	INVTYPE_RANGED = 18, INVTYPE_THROWN = 18, INVTYPE_RANGEDRIGHT = 18, INVTYPE_RELIC = 18, INVTYPE_TABARD = 19 }

local function slot_for(id)
	local item = DC.Item(id)
	if item then
		local slots = DC.INVTYPE_SLOTS[item.invtype]
		if slots then return slots[1] end
	end
	local _, _, _, _, _, _, _, equiploc = GetItemInfo(id)
	return EQUIPLOC_SLOTS[equiploc or ""]
end

local function doll() return DressCodeChar.doll end
local function cell_item(slot, n) local d = doll()[slot] return d and d[n] end
local function cell_locked(slot, n) local l = DressCodeChar.locks[slot] return l and l[n] end

local function item_icon(id)
	local _, _, _, _, _, _, _, _, texture = GetItemInfo(id)
	return texture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local cells = {} -- [slot] = { [1] = button, [2] = button }
local outfit1_btn, outfit2_btn
local rebuild_model -- forward

local function update_cells()
	local active = DressCodeChar.active
	for _, d in ipairs(DOLL) do
		for n = 1, (d.double and 2 or 1) do
			local b = cells[d.slot][n]
			local id = cell_item(d.slot, n)
			if id then
				b.icon:SetTexture(item_icon(id))
				b.icon:SetVertexColor(1, 1, 1)
			else
				b.icon:SetTexture("Interface\\Paperdoll\\UI-PaperDoll-Slot-" .. d.tex)
				b.icon:SetVertexColor(.6, .6, .6)
			end
			local on_model = (shown[d.slot] or active) == n and id
			if on_model then b:SetBackdropBorderColor(1, .82, 0, 1) else b:SetBackdropBorderColor(.3, .3, .3, 1) end
			if cell_locked(d.slot, n) then
				-- locked: bright key, gold frame
				b.lock.tex:SetVertexColor(1, 1, 1)
				b.lock:SetBackdropBorderColor(1, .82, 0, 1)
				b.lock:Show()
			elseif id then
				-- unlocked: gray key, plain frame
				b.lock.tex:SetVertexColor(.45, .45, .45)
				b.lock:SetBackdropBorderColor(.5, .5, .5, 1)
				b.lock:Show()
			else
				b.lock:Hide()
			end
		end
	end
	outfit1_btn:SetAlpha(active == 1 and 1 or .55)
	outfit2_btn:SetAlpha(active == 2 and 1 or .55)
end

rebuild_model = function(reload)
	model = dressing_room()
	-- same as the game's dressing room: SetUnit loads you in your own gear, then items are tried on
	model:SetUnit("player")
	if DressCodeChar.undressed and model.Undress then model:Undress() end
	local wear = {}
	for _, d in ipairs(DOLL) do
		local n = shown[d.slot] or DressCodeChar.active
		if not d.double then n = 1 end
		local id = cell_item(d.slot, n)
		if id then tinsert(wear, id) end
	end
	for _, id in ipairs(wear) do try_item(model, id) end
	model.wear, model.reapply = wear, nil
	update_cells()
end

-- adding one item: just put it on top, no reset of the model
local function wear_one(id)
	model = dressing_room()
	try_item(model, id)
	model.wear = model.wear or {}
	tinsert(model.wear, id)
	update_cells()
end

-- put an item into the doll: the active outfit's cell for its slot (rings/trinkets: a free one of the pair)
local function add_to_doll(id, want_cell, want_slot)
	local slot = slot_for(id)
	if not slot then say("that item can't be worn.") return end
	if want_slot and want_slot ~= slot then
		-- dropped on another slot: only a one-hander may go into the off hand
		local item = DC.Item(id)
		if not (want_slot == 17 and item and item.invtype == 13) then
			say("that goes in the " .. slot_name(slot) .. " slot.")
			return
		end
		slot = want_slot
	end
	local double
	for _, d in ipairs(DOLL) do if d.slot == slot then double = d.double end end
	if double == nil then
		say("necks, rings and trinkets don't show on the character, so they aren't part of outfits.")
		return
	end
	local n = 1
	if double and want_cell then
		n = want_cell
		if cell_locked(slot, n) then say(slot_name(slot) .. " (outfit " .. n .. "): locked.") return end
	elseif double then
		n = DressCodeChar.active
		if cell_locked(slot, n) then n = 3 - n end
		if cell_locked(slot, n) then say(slot_name(slot) .. ": both cells are locked.") return end
	elseif slot == 11 or slot == 13 then
		-- pair: fill the free one, else the unlocked one
		local other = slot + 1
		if cell_item(slot, 1) and not cell_item(other, 1) and not cell_locked(other, 1) then slot = other
		elseif cell_locked(slot, 1) then slot = other end
		if cell_locked(slot, 1) then say(slot_name(slot) .. ": locked.") return end
	end
	doll()[slot] = doll()[slot] or {}
	local replacing = doll()[slot][n] ~= nil
	doll()[slot][n] = id
	local was_shown = (shown[slot] or DressCodeChar.active) == n
	shown[slot] = double and n or nil
	if was_shown and not replacing then wear_one(id) else rebuild_model() end
end
DC.AddToDoll = add_to_doll

local function make_cell(d, n)
	local b = CreateFrame("Button", nil, f)
	b:SetWidth(CELL) b:SetHeight(CELL)
	b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	b:SetBackdropColor(0, 0, 0, .6)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	-- lock toggle in the corner
	local lock = CreateFrame("Button", nil, b)
	lock:SetWidth(16) lock:SetHeight(16)
	lock:SetPoint("TOPRIGHT", b, "TOPRIGHT", 6, 6)
	lock:SetFrameLevel(b:GetFrameLevel() + 3)
	lock:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	lock:SetBackdropColor(0, 0, 0, .85)
	local lt = lock:CreateTexture(nil, "OVERLAY")
	lt:SetPoint("TOPLEFT", lock, "TOPLEFT", 1, -1)
	lt:SetPoint("BOTTOMRIGHT", lock, "BOTTOMRIGHT", -1, 1)
	lt:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
	lt:SetTexCoord(.08, .92, .08, .92)
	lock.tex = lt
	lock:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	lock:Hide()
	b.lock = lock
	local slot, cell = d.slot, n
	lock:SetScript("OnClick", function()
		DressCodeChar.locks[slot] = DressCodeChar.locks[slot] or {}
		DressCodeChar.locks[slot][cell] = not DressCodeChar.locks[slot][cell] or nil
		update_cells()
	end)
	lock:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(cell_locked(slot, cell) and "Locked" or "Lock")
		GameTooltip:AddLine("A locked item stays when you press Reset or load an outfit.", 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	lock:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function()
		local id = cell_item(slot, cell)
		if arg1 == "RightButton" then
			if cell_locked(slot, cell) then say("unlock it first (the key icon).") return end
			if doll()[slot] then doll()[slot][cell] = nil end
			rebuild_model()
			return
		end
		if not id then return end
		if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
			local name, itemstring, quality = GetItemInfo(id)
			if name then ChatFrameEditBox:Insert((QUALITY[quality] or "") .. "|H" .. itemstring .. "|h[" .. name .. "]|h|r") end
			return
		end
		shown[slot] = cell
		rebuild_model()
		DC.ShowDetails(id)
	end)
	b:SetScript("OnEnter", function()
		local id = cell_item(slot, cell)
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		if id and GetItemInfo(id) then
			GameTooltip:SetHyperlink("item:" .. id .. ":0:0:0")
		else
			GameTooltip:SetText(slot_name(slot) .. (d.double and (" - outfit " .. cell) or ""))
			GameTooltip:AddLine(id and ("item " .. id) or "Empty: Ctrl-click an item to put it here.", 1, 1, 1, 1)
		end
		GameTooltip:AddLine("Click: put on. Right-click: remove. Key: lock.", .6, .6, .6)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

for _, d in ipairs(DOLL) do
	cells[d.slot] = {}
	for n = 1, (d.double and 2 or 1) do
		local b = make_cell(d, n)
		if d.col == "L" then
			b:SetPoint("TOPLEFT", f, "TOPLEFT", 456 + (n - 1) * (CELL + GAP), -72 - (d.row - 1) * (CELL + GAP + 7))
		elseif d.col == "R" then
			b:SetPoint("TOPLEFT", f, "TOPLEFT", 862 + (n - 1) * (CELL + GAP), -72 - (d.row - 1) * (CELL + GAP + 7))
		else
			b:SetPoint("TOPLEFT", f, "TOPLEFT", 582 + (d.row - 1) * (2 * CELL + GAP + 12) + (n - 1) * (CELL + GAP), -472)
		end
		cells[d.slot][n] = b
	end
end

local head1 = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
head1:SetPoint("BOTTOM", cells[1][1], "TOP", 0, 2) head1:SetText("1")
local head2 = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
head2:SetPoint("BOTTOM", cells[1][2], "TOP", 0, 2) head2:SetText("2")
local head3 = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
head3:SetPoint("BOTTOM", cells[10][1], "TOP", 0, 2) head3:SetText("1")
local head4 = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
head4:SetPoint("BOTTOM", cells[10][2], "TOP", 0, 2) head4:SetText("2")

-- outfit switch and doll buttons
outfit1_btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
outfit1_btn:SetWidth(100) outfit1_btn:SetHeight(22)
outfit1_btn:SetPoint("TOPLEFT", f, "TOPLEFT", 456, -518)
outfit1_btn:SetText("Outfit 1")
outfit2_btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
outfit2_btn:SetWidth(100) outfit2_btn:SetHeight(22)
outfit2_btn:SetPoint("LEFT", outfit1_btn, "RIGHT", 4, 0)
outfit2_btn:SetText("Outfit 2")
local function set_outfit(n)
	DressCodeChar.active = n
	shown = {}
	rebuild_model()
end
outfit1_btn:SetScript("OnClick", function() set_outfit(1) end)
outfit2_btn:SetScript("OnClick", function() set_outfit(2) end)

local reset_btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
reset_btn:SetWidth(70) reset_btn:SetHeight(22)
reset_btn:SetPoint("LEFT", outfit2_btn, "RIGHT", 4, 0)
reset_btn:SetText("Reset")
reset_btn:SetScript("OnClick", function()
	for slot, d in pairs(doll()) do
		for n = 1, 2 do if not cell_locked(slot, n) then d[n] = nil end end
	end
	shown = {}
	DressCodeChar.undressed = nil
	rebuild_model()
end)
reset_btn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText("Reset")
	GameTooltip:AddLine("Removes every item that isn't locked from both outfits.", 1, 1, 1, 1)
	GameTooltip:Show()
end)
reset_btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local undress_btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
undress_btn:SetWidth(70) undress_btn:SetHeight(22)
undress_btn:SetPoint("LEFT", reset_btn, "RIGHT", 4, 0)
undress_btn:SetText("Undress")
undress_btn:SetScript("OnClick", function()
	DressCodeChar.undressed = not DressCodeChar.undressed or nil
	this:SetText(DressCodeChar.undressed and "Dress" or "Undress")
	rebuild_model()
end)
undress_btn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText("Undress / Dress")
	GameTooltip:AddLine("Show only the outfit's items, or the outfit over the gear you wear.", 1, 1, 1, 1)
	GameTooltip:Show()
end)
undress_btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local save_btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
save_btn:SetWidth(70) save_btn:SetHeight(22)
save_btn:SetPoint("TOPLEFT", outfit1_btn, "BOTTOMLEFT", 0, -6)
save_btn:SetText("Save")

local doll_hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
doll_hint:SetPoint("LEFT", save_btn, "RIGHT", 8, 0)
doll_hint:SetWidth(300) doll_hint:SetJustifyH("LEFT")
doll_hint:SetText("Drag items onto a slot (or Shift: outfit 1, Alt: outfit 2). Drag the character to turn.")

StaticPopupDialogs["DRESSCODE_SAVE_OUTFIT"] = {
	text = "Name these outfits:",
	button1 = ACCEPT, button2 = CANCEL,
	hasEditBox = 1, maxLetters = 40, timeout = 0, whileDead = 1, hideOnEscape = 1,
	OnAccept = function() DC.SaveOutfit(getglobal(this:GetParent():GetName() .. "EditBox"):GetText()) end,
	EditBoxOnEnterPressed = function() DC.SaveOutfit(this:GetText()) this:GetParent():Hide() end,
}
save_btn:SetScript("OnClick", function() StaticPopup_Show("DRESSCODE_SAVE_OUTFIT") end)

function DC.SaveOutfit(name)
	if not name or name == "" then name = "Outfit " .. (table.getn(DressCodeChar.outfits) + 1) end
	local copy, count = {}, 0
	for slot, d in pairs(doll()) do
		copy[slot] = { d[1], d[2] }
		if d[1] then count = count + 1 end
		if d[2] then count = count + 1 end
	end
	tinsert(DressCodeChar.outfits, { name = name, doll = copy })
	say("saved \"" .. name .. "\" (" .. count .. " items).")
	if mode == "outfits" then refresh() end
end

local function load_outfit(o)
	for slot, d in pairs(doll()) do
		for n = 1, 2 do if not cell_locked(slot, n) then d[n] = nil end end
	end
	if o.doll then
		for slot, d in pairs(o.doll) do
			doll()[slot] = doll()[slot] or {}
			for n = 1, 2 do
				if d[n] and not cell_locked(slot, n) then doll()[slot][n] = d[n] end
			end
		end
	else -- outfits saved by the first version: a plain item list, goes into the active outfit
		for _, id in ipairs(o.items or {}) do add_to_doll(id) end
	end
	shown = {}
	rebuild_model()
end

---------------------------------------------------------------------------- tabs

local tabs = {}
local function make_tab(key, label, x)
	local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	b:SetWidth(80) b:SetHeight(22)
	b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 40)
	b:SetText(label)
	b:SetScript("OnClick", function() mode = key FauxScrollFrame_SetOffset(scroll, 0) refresh() end)
	tabs[key] = b
end
make_tab("find", "Find", 20)
make_tab("browse", "Browse", 104)
make_tab("outfits", "Outfits", 188)

local load_btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
load_btn:SetWidth(80) load_btn:SetHeight(22)
load_btn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 272, 40)
load_btn:SetText("Load list")
load_btn:Hide()
load_btn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText("Load list")
	GameTooltip:AddLine("Asks the server about the items in this list your game hasn't seen yet (a few per second), so Dress Code can learn their stats.", 1, 1, 1, 1)
	GameTooltip:Show()
end)
load_btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------------------------- share learned quests
-- the quests Dress Code learned in game, as a code to copy (Ctrl+C) and send to the addon's author,
-- who merges the codes into the next version (tools/dresscode_gen.py). Long lists come in parts.
local SHARE_WHERE = "Paste it where Raccoonbox collects Dress Code data."
local SHARE_PART = 3000 -- characters per code
local share_parts, share_index, share_next = {}, 0, nil

local function share_code(part)
	local texts = {}
	for _, e in ipairs(part) do tinsert(texts, e.text) end
	return "DC1:" .. table.concat(texts, "~")
end

StaticPopupDialogs["DRESSCODE_SHARE"] = {
	text = "%s",
	button1 = "Copied", button2 = CANCEL,
	hasEditBox = 1, hasWideEditBox = 1, maxLetters = SHARE_PART + 500, timeout = 0, whileDead = 1, hideOnEscape = 1,
	OnShow = function()
		local box = getglobal(this:GetName() .. "WideEditBox") or getglobal(this:GetName() .. "EditBox")
		box:SetMaxLetters(SHARE_PART + 500)
		box:SetText(DressCode.share_code or "")
		box:SetFocus()
		box:HighlightText()
	end,
	OnAccept = function()
		-- this part was copied: don't offer its quests again, then show the next part (next frame: the
		-- popup closes itself after this function)
		DC.MarkShared(share_parts[share_index] or {})
		if share_index < table.getn(share_parts) then share_next = true end
	end,
	EditBoxOnEscapePressed = function() this:GetParent():Hide() end,
}

local function show_share_part()
	local part = share_parts[share_index]
	DressCode.share_code = share_code(part)
	local count = table.getn(share_parts)
	StaticPopup_Show("DRESSCODE_SHARE", "Dress Code quests" .. (count > 1 and (", code " .. share_index .. " of " .. count) or "")
		.. " (" .. table.getn(part) .. " quests).\nPress Ctrl+C to copy it, then press Copied.\n" .. SHARE_WHERE)
end

-- all = also quests shared before
function DC.Share(all)
	local entries = DC.ShareEntries(all)
	if table.getn(entries) == 0 then
		say("nothing new to share. Dress Code learns a quest's rewards when you open the quest at an NPC or have it in your quest log.")
		return
	end
	share_parts = {} -- a new table: in Lua 5.0 a cleared table keeps its old length
	local part, size = {}, 0
	for _, e in ipairs(entries) do
		if size + strlen(e.text) > SHARE_PART and table.getn(part) > 0 then tinsert(share_parts, part) part, size = {}, 0 end
		tinsert(part, e)
		size = size + strlen(e.text) + 1
	end
	tinsert(share_parts, part)
	share_index = 1
	show_share_part()
end

local share_btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
share_btn:SetWidth(80) share_btn:SetHeight(22)
share_btn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 356, 40)
share_btn:SetText("Share")
share_btn:SetScript("OnClick", function() DC.Share(IsShiftKeyDown()) end)
share_btn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText("Share quests")
	GameTooltip:AddLine("Dress Code learns which quests give which items when you open quests in game. Share gives you a code to send to Raccoonbox, so the next version knows them for everyone.", 1, 1, 1, 1)
	GameTooltip:AddLine(table.getn(DC.ShareEntries()) .. " new to share. Shift-click: share everything again.", .6, .6, .6)
	GameTooltip:Show()
end)
share_btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------------------------- filling the list

local function item_name(item) return (QUALITY[item.quality] or "") .. item.name .. "|r" end

local function build()
	entries = {} -- a new table: in Lua 5.0 a cleared table keeps its old length
	local keys, text = DressCodeChar.keys, DressCodeChar.search
	local ticked = false
	for _ in pairs(keys) do ticked = true end
	if mode == "find" then
		if not ticked and (not text or text == "") then
			status:SetText("Tick the stats you want more of (and pick a slot), or type text.")
		else
			local found, total = DC.Find({ slot = DressCodeChar.slot, keys = keys, search = text, ahead = DressCodeChar.ahead })
			for _, u in ipairs(found) do
				tinsert(entries, { kind = "item", id = u.item.id, item = u.item, gains = u.gains })
			end
			status:SetText(total .. " items beat what you wear" .. (total > 300 and " (showing 300)" or "")
				.. ". Click: details. Shift: outfit 1, Alt: outfit 2, or drag to a slot.")
		end
	elseif mode == "browse" then
		if browse_cat then tinsert(entries, { kind = "back" }) end
		if not browse_cat then
			for _, c in ipairs(DC.BrowseCategories()) do
				tinsert(entries, { kind = "category", index = c.index, name = c.name, count = c.count })
			end
			status:SetText("Browse dungeons, professions, factions, PvP and sets.")
		elseif not browse_list then
			for _, l in ipairs(DC.BrowseLists(browse_cat)) do tinsert(entries, { kind = "list", index = l.index, name = l.name }) end
			status:SetText(DressCodeBrowse[browse_cat][1] .. ": " .. (table.getn(entries) - 1) .. " lists.")
		else
			local unknown = 0
			for _, b in ipairs(DC.BrowseItems(browse_cat, browse_list)) do
				local e = { kind = "browse", id = b.id, icon = b.icon, quality = b.quality, name = b.name, extra = b.extra }
				local item = b.id and DC.Item(b.id)
				if item then
					e.item = item
					e.usable = DC.CanUse(item, UnitLevel("player") + 60)
					if e.usable and (ticked or (text and text ~= "")) then e.gains = DC.Compare(item, keys, text) end
				elseif b.id then
					unknown = unknown + 1
				end
				tinsert(entries, e)
			end
			local t = DressCodeBrowse[browse_cat][2][browse_list]
			status:SetText(t[1] .. (unknown > 0 and (": " .. unknown .. " items not known yet (hover or Load list).") or ""))
		end
	else
		for i, o in ipairs(DressCodeChar.outfits) do tinsert(entries, { kind = "outfit", index = i, outfit = o }) end
		status:SetText(table.getn(entries) .. " saved outfits. Click: load, right-click: delete.")
	end
	for key, b in pairs(tabs) do
		if key == mode then b:LockHighlight() else b:UnlockHighlight() end
	end
	if mode == "browse" and browse_list then load_btn:Show() else load_btn:Hide() end
end

render = function()
	local n = table.getn(entries)
	FauxScrollFrame_Update(scroll, n, ROWS, ROW_H)
	local offset = FauxScrollFrame_GetOffset(scroll)
	for i = 1, ROWS do
		local r, e = rows[i], entries[i + offset]
		r.entry = e
		if not e then
			r:Hide()
		else
			r:Show()
			r.right:SetText("")
			if e.kind == "item" then
				r.icon:SetTexture(item_icon(e.id))
				r.name:SetText(item_name(e.item))
				r.right:SetText("|cff33ff33" .. DC.GainText(e.gains) .. "|r")
				local slots = DC.INVTYPE_SLOTS[e.item.invtype]
				r.sub:SetText((slots and slot_name(slots[1]) or "") .. " (" .. DC.LevelText(e.item) .. ")  " .. DC.Sources(e.id)[1])
			elseif e.kind == "back" then
				r.icon:SetTexture("Interface\\Icons\\Spell_ChargeNegative")
				r.name:SetText("Back") r.sub:SetText("")
			elseif e.kind == "category" then
				r.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
				r.name:SetText(e.name) r.sub:SetText(e.count .. " lists")
			elseif e.kind == "list" then
				r.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
				r.name:SetText(e.name) r.sub:SetText("")
			elseif e.kind == "browse" then
				local tex = e.icon ~= "" and ("Interface\\Icons\\" .. e.icon) or (e.id and item_icon(e.id))
				r.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
				r.name:SetText((QUALITY[e.quality] or "") .. e.name .. "|r")
				if e.gains then r.right:SetText("|cff33ff33" .. DC.GainText(e.gains) .. "|r") end
				local sub = e.extra or ""
				if e.item then
					local slots = DC.INVTYPE_SLOTS[e.item.invtype]
					sub = (slots and slot_name(slots[1]) or "") .. " (" .. DC.LevelText(e.item) .. ")"
						.. (e.usable and "" or "  |cffff5555can't use|r") .. (e.extra ~= "" and ("  " .. e.extra) or "")
				elseif e.id then
					sub = "not known yet - hover to load" .. (e.extra ~= "" and ("  " .. e.extra) or "")
				end
				r.sub:SetText(sub)
			else
				r.icon:SetTexture("Interface\\Icons\\INV_Chest_Cloth_17")
				r.name:SetText(e.outfit.name)
				local count = 0
				for _, d in pairs(e.outfit.doll or {}) do
					if d[1] then count = count + 1 end
					if d[2] then count = count + 1 end
				end
				r.sub:SetText((e.outfit.doll and count or table.getn(e.outfit.items or {})) .. " items")
			end
		end
	end
end

refresh = function()
	if not f:IsVisible() then return end
	DC.refresh_player()
	update_ahead()
	build()
	render()
end
DC.Refresh = refresh

---------------------------------------------------------------------------- row interaction

local function show_item_tooltip(owner, id, gaintext)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	if GetItemInfo(id) then
		GameTooltip:SetHyperlink("item:" .. id .. ":0:0:0")
	else
		local item = DC.Item(id)
		GameTooltip:SetText(item and item.name or ("item " .. id))
	end
	GameTooltip:AddLine(" ")
	if gaintext and gaintext ~= "" then GameTooltip:AddLine("Dress Code: " .. gaintext, .2, 1, .2) end
	for _, s in ipairs(DC.Sources(id)) do GameTooltip:AddLine(s, 1, .82, 0) end
	GameTooltip:Show()
end

local drag = CreateFrame("Frame", nil, UIParent)
drag:SetWidth(32) drag:SetHeight(32)
drag:SetFrameStrata("TOOLTIP")
drag.icon = drag:CreateTexture(nil, "OVERLAY")
drag.icon:SetAllPoints(drag)
drag:Hide()
drag:SetScript("OnUpdate", function()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	this:ClearAllPoints()
	this:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end)

local function drop_target()
	for slot, list in pairs(cells) do
		for n, b in pairs(list) do
			if MouseIsOver(b) then return slot, n end
		end
	end
end

for _, r in ipairs(rows) do
	r:RegisterForDrag("LeftButton")
	r:SetScript("OnDragStart", function()
		local e = this.entry
		if not (e and e.id and (e.kind == "item" or e.kind == "browse")) then return end
		this.dragged = true
		drag.id = e.id
		drag.icon:SetTexture(item_icon(e.id))
		drag:Show()
		GameTooltip:Hide()
	end)
	r:SetScript("OnDragStop", function()
		-- remember when the drag ended: only a click in the same moment belongs to the drag
		if this.dragged then this.dragged = GetTime() end
		if not drag:IsShown() then return end
		drag:Hide()
		local slot, n = drop_target()
		if slot then add_to_doll(drag.id, n, slot) end
		drag.id = nil
	end)
	r:SetScript("OnEnter", function()
		local e = this.entry
		if not e then return end
		if e.kind == "item" then
			show_item_tooltip(this, e.id, DC.GainText(e.gains))
		elseif e.kind == "browse" and e.id then
			if not DC.Known(e.id) then DC.Request(e.id) pending[e.id] = true end
			show_item_tooltip(this, e.id, e.gains and DC.GainText(e.gains))
		end
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	r:SetScript("OnClick", function()
		local e = this.entry
		-- the mouse-up that ends a drag is not a click (true = the click came before OnDragStop);
		-- a drag dropped on a cell gets no click here, so its mark must not eat the next real click
		local dragged = this.dragged
		this.dragged = nil
		if dragged == true or (dragged and GetTime() - dragged < .2) then return end
		if not e then return end
		if e.kind == "back" then
			if browse_list then browse_list = nil else browse_cat = nil end
			FauxScrollFrame_SetOffset(scroll, 0) refresh() return
		elseif e.kind == "category" then
			browse_cat = e.index FauxScrollFrame_SetOffset(scroll, 0) refresh() return
		elseif e.kind == "list" then
			browse_list = e.index FauxScrollFrame_SetOffset(scroll, 0) refresh() return
		elseif e.kind == "outfit" then
			if arg1 == "RightButton" then
				tremove(DressCodeChar.outfits, e.index)
				say("deleted \"" .. e.outfit.name .. "\".")
				refresh()
			else
				load_outfit(e.outfit)
				say("loaded \"" .. e.outfit.name .. "\".")
			end
			return
		end
		local id = e.id
		if not id then return end
		if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
			local name, itemstring, quality = GetItemInfo(id)
			if name then ChatFrameEditBox:Insert((QUALITY[quality] or "") .. "|H" .. itemstring .. "|h[" .. name .. "]|h|r") end
			return
		end
		DC.ShowDetails(id, e.gains and DC.GainText(e.gains))
		if IsShiftKeyDown() then add_to_doll(id, 1)
		elseif IsAltKeyDown() then add_to_doll(id, 2)
		elseif IsControlKeyDown() then add_to_doll(id) end
	end)
end

load_btn:SetScript("OnClick", function()
	load_queue = {}
	for _, e in ipairs(entries) do
		if e.kind == "browse" and e.id and not DC.Known(e.id) then tinsert(load_queue, e.id) end
	end
	if table.getn(load_queue) == 0 then say("every item in this list is known already.") return end
	say("loading " .. table.getn(load_queue) .. " items...")
end)

-- learning: ask queued items slowly, learn what has arrived, refresh when something new is known
local ticker = CreateFrame("Frame")
local tick_ask, tick_learn = 0, 0
ticker:SetScript("OnUpdate", function()
	if share_next then
		share_next = nil
		share_index = share_index + 1
		show_share_part()
	end
	tick_ask = tick_ask + arg1
	tick_learn = tick_learn + arg1
	if tick_ask >= .3 and table.getn(load_queue) > 0 then
		tick_ask = 0
		local id = tremove(load_queue, 1)
		DC.Request(id)
		pending[id] = true
		if table.getn(load_queue) == 0 then say("list loaded.") end
	end
	if tick_learn >= .5 then
		tick_learn = 0
		local learned
		for id in pairs(pending) do
			if DC.Learn(id) then pending[id] = nil learned = true end
		end
		if learned and f:IsVisible() and mode == "browse" then refresh() end
	end
end)

-- Ctrl-clicking any item link in the game (bags, chat, loot) adds it to the doll while Dress Code is open
local orig_dressup = DressUpItemLink
DressUpItemLink = function(link)
	local id = DC.item_id(link)
	if id and f:IsVisible() then add_to_doll(id) return end
	return orig_dressup(link)
end

---------------------------------------------------------------------------- resize grip (scales the window)

local grip = CreateFrame("Button", nil, f)
grip:SetWidth(16) grip:SetHeight(16)
grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
local grip_tex = grip:CreateTexture(nil, "OVERLAY")
grip_tex:SetAllPoints(grip)
grip_tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetScript("OnMouseDown", function()
	local x = GetCursorPosition()
	this.start_x, this.start_scale = x, f:GetScale()
	this.left, this.top = f:GetLeft() * f:GetScale(), f:GetTop() * f:GetScale()
end)
grip:SetScript("OnMouseUp", function() this.start_x = nil DressCodeDB.scale = f:GetScale() end)
grip:SetScript("OnUpdate", function()
	if not this.start_x then return end
	local x = GetCursorPosition()
	local scale = this.start_scale + (x - this.start_x) / UIParent:GetEffectiveScale() / f:GetWidth()
	scale = math.max(.6, math.min(1.5, scale))
	f:SetScale(scale)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", this.left / scale, this.top / scale)
end)

---------------------------------------------------------------------------- show / events / slash

f:SetScript("OnHide", function() close_dressing_room() end)
f:SetScript("OnShow", function()
	UIDropDownMenu_Initialize(slot_drop, init_slot)
	UIDropDownMenu_SetWidth(110, slot_drop)
	UIDropDownMenu_SetText(DressCodeChar.slot and slot_name(DressCodeChar.slot) or "All slots", slot_drop)
	for key, cb in pairs(checks) do cb:SetChecked(DressCodeChar.keys[key] and 1 or nil) end
	search.ready = nil
	search:SetText(DressCodeChar.search or "")
	search.ready = true
	-- the 1.12 model may not be able to undress: then the button can't do anything
	if not model.Undress then
		DressCodeChar.undressed = nil
		undress_btn:Disable()
		undress_btn:SetScript("OnEnter", function()
			GameTooltip:SetOwner(this, "ANCHOR_TOP")
			GameTooltip:SetText("Undress")
			GameTooltip:AddLine("Not available in this game version: the outfit always shows over the gear you wear.", 1, 1, 1, 1)
			GameTooltip:Show()
		end)
	end
	undress_btn:SetText(DressCodeChar.undressed and "Dress" or "Undress")
	rebuild_model(true)
	refresh()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("VARIABLES_LOADED")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function()
	if event == "VARIABLES_LOADED" then
		DressCodeDB = DressCodeDB or {}
		DressCodeChar = DressCodeChar or {}
		DressCodeChar.outfits = DressCodeChar.outfits or {}
		DressCodeChar.keys = DressCodeChar.keys or {}
		DressCodeChar.doll = DressCodeChar.doll or {}
		DressCodeChar.locks = DressCodeChar.locks or {}
		DressCodeChar.active = DressCodeChar.active or 1
		if DressCodeDB.scale then f:SetScale(DressCodeDB.scale) end
		DC.refresh_player()
	elseif event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
		return
	elseif f:IsVisible() then
		refresh()
	end
end)

SLASH_DRESSCODE1 = "/dresscode"
SLASH_DRESSCODE2 = "/dress"
SlashCmdList.DRESSCODE = function(msg)
	if msg == "minimap" then
		DressCodeDB.hide_minimap = not DressCodeDB.hide_minimap or nil
		if DressCodeDB.hide_minimap then DressCodeMinimapButton:Hide() else DressCodeMinimapButton:Show() end
		say("minimap button " .. (DressCodeDB.hide_minimap and "hidden" or "shown") .. ".")
		return
	elseif msg == "share" or msg == "share all" then
		DC.Share(msg == "share all")
		return
	end
	if f:IsVisible() then f:Hide() else f:Show() end
end

---------------------------------------------------------------------------- minimap button

local mm = CreateFrame("Button", "DressCodeMinimapButton", Minimap)
mm:SetWidth(31) mm:SetHeight(31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mm:RegisterForDrag("LeftButton", "RightButton")
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local mm_icon = mm:CreateTexture(nil, "BACKGROUND")
mm_icon:SetWidth(20) mm_icon:SetHeight(20)
mm_icon:SetPoint("TOPLEFT", mm, "TOPLEFT", 6, -5)
mm_icon:SetTexture("Interface\\Icons\\INV_Chest_Cloth_04")
mm_icon:SetTexCoord(.08, .92, .08, .92)
local mm_border = mm:CreateTexture(nil, "OVERLAY")
mm_border:SetWidth(53) mm_border:SetHeight(53)
mm_border:SetPoint("TOPLEFT", mm, "TOPLEFT", 0, 0)
mm_border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- always draw above the minimap itself, even when another addon raises the minimap's layer
local function raise_minimap_button()
	mm:SetFrameStrata(Minimap:GetFrameStrata())
	mm:SetFrameLevel(Minimap:GetFrameLevel() + 8)
end

local function place_minimap_button()
	raise_minimap_button()
	local angle = math.rad(DressCodeDB and DressCodeDB.minimap or 200)
	mm:ClearAllPoints()
	mm:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(angle), 80 * math.sin(angle))
end
mm:SetScript("OnClick", function() if f:IsVisible() then f:Hide() else f:Show() end end)
mm:SetScript("OnDragStart", function() this.dragging = true end)
mm:SetScript("OnDragStop", function() this.dragging = nil end)
mm:SetScript("OnUpdate", function()
	if not this.dragging then return end
	local x, y = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = Minimap:GetCenter()
	DressCodeDB.minimap = math.deg(math.atan2(y / scale - cy, x / scale - cx))
	place_minimap_button()
end)
mm:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText("Dress Code")
	GameTooltip:AddLine("Click to open. Drag to move this button.", 1, 1, 1)
	GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
local mm_events = CreateFrame("Frame")
mm_events:RegisterEvent("VARIABLES_LOADED")
mm_events:RegisterEvent("PLAYER_ENTERING_WORLD") -- minimap addons adjust the minimap after loading
mm_events:SetScript("OnEvent", function()
	DressCodeDB = DressCodeDB or {}
	place_minimap_button()
	if DressCodeDB.hide_minimap then mm:Hide() end
end)
