-- Chat Buttons [Raccoonbox]
-- Small buttons above the chat window. One click opens the chat box already set to that channel,
-- and the channel stays selected for your next messages (no more surprise /say in a battleground).
--  * dimmed: you can't use that channel right now (not in a group, battleground, guild, ...)
--  * highlighted: the channel the chat box is currently set to
--  * Shift + drag to move the row, /chatbuttons reset to put it back above the chat
--  * layout: /chatbuttons horizontal | vertical | columns <n> | rows <n>

local BUTTONS = {
	{ label = "S",  cmd = "/s ",  info = "SAY",          tip = "Say" },
	{ label = "Y",  cmd = "/y ",  info = "YELL",         tip = "Yell" },
	{ label = "P",  cmd = "/p ",  info = "PARTY",        tip = "Party",
		usable = function() return GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 end },
	{ label = "R",  cmd = "/ra ", info = "RAID",         tip = "Raid",
		usable = function() return GetNumRaidMembers() > 0 end },
	{ label = "RW", cmd = "/rw ", info = "RAID_WARNING", tip = "Raid warning (raid leader or assist)",
		usable = function() return GetNumRaidMembers() > 0 and (IsRaidLeader() or IsRaidOfficer()) end },
	{ label = "BG", cmd = "/bg ", info = "BATTLEGROUND", tip = "Battleground",
		usable = function()
			for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
				if GetBattlefieldStatus(i) == "active" then return true end
			end
		end },
	{ label = "G",  cmd = "/g ",  info = "GUILD",        tip = "Guild",
		usable = function() return IsInGuild() end },
	{ label = "O",  cmd = "/o ",  info = "OFFICER",      tip = "Officer",
		usable = function() return IsInGuild() end },
	{ label = "W",  cmd = "/r ",  info = "WHISPER",      tip = "Reply to the last whisper", reply = true },
	-- found by name, so they work even when another channel took their number
	{ label = "Gen", info = "CHANNEL1", tip = "General", channelname = "General" },
	{ label = "Tr",  info = "CHANNEL2", tip = "Trade (capital cities only)", channelname = "Trade" },
}

-- the current number of a channel whose name starts with `name` ("Trade - City" -> Trade)
local function channel_id(name)
	for i = 1, 10 do
		local id, full = GetChannelName(i)
		if id and id > 0 and full and string.find(full, "^" .. name) then return id, full end
	end
end

local SIZE_W, SIZE_H, GAP = 24, 18, 2

-- these chat types stay selected after you send a message (yell doesn't, on purpose)
for _, t in ipairs({ "SAY", "PARTY", "RAID", "RAID_WARNING", "BATTLEGROUND", "GUILD", "OFFICER", "WHISPER", "CHANNEL" }) do
	if ChatTypeInfo[t] then ChatTypeInfo[t].sticky = 1 end
end

local row = CreateFrame("Frame", "ChatButtonsRaccoonbox", UIParent)
row:SetWidth(table.getn(BUTTONS) * (SIZE_W + GAP) - GAP)
row:SetHeight(SIZE_H)
row:SetMovable(true)
row:SetClampedToScreen(true)

local function default_position()
	row:ClearAllPoints()
	-- above the chat tabs of the main chat window
	row:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 28)
end

local function save_position()
	local point, _, relpoint, x, y = row:GetPoint()
	ChatButtonsDB.pos = { point, relpoint, x, y }
end

local function open(def)
	local box = ChatFrameEditBox
	if def.reply and ChatFrame_ReplyTell then
		ChatFrame_ReplyTell()
		return
	end
	local cmd = def.cmd
	if def.channelname then
		local id = channel_id(def.channelname)
		if not id then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff9900Chat Buttons:|r you're not in " .. def.channelname .. " right now"
				.. (def.channelname == "Trade" and " (it only exists in capital cities)." or "."))
			return
		end
		cmd = "/" .. id .. " "
	end
	-- exactly what typing "/bg " does: the chat box switches to that channel
	ChatFrame_OpenChat(cmd)
	if box:GetText() == cmd and ChatEdit_ParseText then
		ChatEdit_ParseText(box, 0)
	end
end

local buttons = {}
local show_menu -- right-click layout menu, defined below
local alpha_frame -- idle transparency slider window, defined below

local function color(def)
	local c = ChatTypeInfo[def.info]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

for i, def in ipairs(BUTTONS) do
	local b = CreateFrame("Button", nil, row)
	b:SetWidth(SIZE_W)
	b:SetHeight(SIZE_H)
	b:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = false, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	b:SetBackdropColor(0, 0, 0, .6)
	b:SetBackdropBorderColor(.25, .25, .25, 1)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.text:SetText(def.label)
	b.def = def
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnClick", function()
		if arg1 == "RightButton" then show_menu() else open(this.def) end
	end)
	b:SetScript("OnDragStart", function() if IsShiftKeyDown() then row:StartMoving() end end)
	b:SetScript("OnDragStop", function() row:StopMovingOrSizing() save_position() end)
	b:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		local tip = this.def.tip
		if this.def.channelname then
			local id, full = channel_id(this.def.channelname)
			tip = id and (id .. ". " .. full) or (this.def.tip .. " - not joined right now")
		end
		GameTooltip:SetText(tip, color(this.def))
		if this.def.reply and ChatEdit_GetLastTellTarget then
			local who = ChatEdit_GetLastTellTarget(ChatFrameEditBox)
			if who and who ~= "" then GameTooltip:AddLine("to " .. who, 1, 1, 1) end
		end
		GameTooltip:AddLine("Shift + drag to move, right-click for layout", .6, .6, .6)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	buttons[i] = b
end

-- arrange the buttons: `per_line` buttons per row (all of them = horizontal, 1 = vertical)
local function layout()
	local n = table.getn(buttons)
	local per_line = ChatButtonsDB and ChatButtonsDB.per_line or n
	per_line = math.max(1, math.min(n, per_line))
	local lines = math.ceil(n / per_line)
	for i, b in ipairs(buttons) do
		local col = math.mod(i - 1, per_line)
		local line = math.floor((i - 1) / per_line)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", row, "TOPLEFT", col * (SIZE_W + GAP), -line * (SIZE_H + GAP))
	end
	row:SetWidth(per_line * (SIZE_W + GAP) - GAP)
	row:SetHeight(lines * (SIZE_H + GAP) - GAP)
end

-- set how many buttons go in one row and redo the layout
local function set_per_line(per_line)
	local n = table.getn(buttons)
	ChatButtonsDB.per_line = math.max(1, math.min(n, per_line))
	layout()
end

-- right-click menu: layout choices, reset position, hide
local menu = CreateFrame("Frame", "ChatButtonsRaccoonboxMenu", UIParent, "UIDropDownMenuTemplate")

local function menu_init()
	local n = table.getn(buttons)
	local current = ChatButtonsDB.per_line or n
	local function add(text, func, checked, title)
		local info = {}
		info.text = text
		info.func = func
		info.checked = checked
		info.isTitle = title
		info.notCheckable = title
		UIDropDownMenu_AddButton(info)
	end
	add("Chat Buttons", nil, nil, true)
	add("Horizontal (one row)", function() set_per_line(n) end, current == n)
	add("Vertical (one column)", function() set_per_line(1) end, current == 1)
	for _, rows in ipairs({ 2, 3 }) do
		local per = math.ceil(n / rows)
		add(rows .. " rows", function() set_per_line(per) end, current == per and current ~= n and current ~= 1)
	end
	for _, c in ipairs({ 2, 3, 4 }) do
		-- Lua 5.0: the loop variable is nil once the loop ends, so the click handler needs its own copy
		local cols = c
		local is_rows = current == math.ceil(n / 2) or current == math.ceil(n / 3)
		add(cols .. " columns", function() set_per_line(cols) end, current == cols and not is_rows)
	end
	add("Idle transparency...", function()
		alpha_frame:ClearAllPoints()
		alpha_frame:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 0, 8)
		alpha_frame:Show()
	end)
	add("Reset position", function()
		ChatButtonsDB.pos = nil
		row:ClearAllPoints()
		row:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 28)
	end)
	add("Hide (/chatbuttons show)", function()
		row:Hide()
		ChatButtonsDB.hidden = true
	end)
end

-- idle transparency: a small window with a slider (how visible the buttons are when the mouse is away)
alpha_frame = CreateFrame("Frame", "ChatButtonsRaccoonboxAlpha", UIParent)
alpha_frame:SetWidth(220)
alpha_frame:SetHeight(70)
alpha_frame:SetFrameStrata("DIALOG")
alpha_frame:SetClampedToScreen(true)
alpha_frame:EnableMouse(true)
alpha_frame:SetBackdrop({
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
alpha_frame:SetBackdropColor(0, 0, 0, .9)
alpha_frame:Hide()

local alpha_close = CreateFrame("Button", nil, alpha_frame, "UIPanelCloseButton")
alpha_close:SetPoint("TOPRIGHT", alpha_frame, "TOPRIGHT", 2, 2)

local alpha_slider = CreateFrame("Slider", "ChatButtonsRaccoonboxAlphaSlider", alpha_frame, "OptionsSliderTemplate")
alpha_slider:SetPoint("BOTTOM", alpha_frame, "BOTTOM", 0, 14)
alpha_slider:SetWidth(180)
alpha_slider:SetMinMaxValues(0, 100)
alpha_slider:SetValueStep(5)
getglobal("ChatButtonsRaccoonboxAlphaSliderLow"):SetText("0%")
getglobal("ChatButtonsRaccoonboxAlphaSliderHigh"):SetText("100%")
alpha_slider:SetScript("OnValueChanged", function()
	local v = floor(this:GetValue() / 5 + .5) * 5
	ChatButtonsDB.idle_alpha = v / 100
	getglobal("ChatButtonsRaccoonboxAlphaSliderText"):SetText("Visible when idle: " .. v .. "%")
end)
alpha_frame:SetScript("OnShow", function()
	alpha_slider:SetValue((ChatButtonsDB.idle_alpha or 1) * 100)
end)

show_menu = function()
	UIDropDownMenu_Initialize(menu, menu_init, "MENU")
	ToggleDropDownMenu(1, nil, menu, "cursor")
end

-- dim unusable buttons, highlight the channel the chat box is set to
local function current_type()
	local box = ChatFrameEditBox
	local t = box.chatType
	if t == "CHANNEL" and box.channelTarget then return "CHANNEL" .. box.channelTarget end
	return t
end

local function update()
	local active = current_type()
	for _, b in ipairs(buttons) do
		local def = b.def
		local usable = true
		if def.usable then usable = def.usable() end
		local channel_type
		if def.channelname then
			local id = channel_id(def.channelname)
			usable = id ~= nil
			channel_type = id and ("CHANNEL" .. id)
		end
		local r, g, bl = color(def)
		if usable then
			b.text:SetTextColor(r, g, bl)
			b:SetAlpha(1)
		else
			b.text:SetTextColor(.5, .5, .5)
			b:SetAlpha(.5)
		end
		if active == (channel_type or (not def.channelname and def.info)) then
			b:SetBackdropBorderColor(r, g, bl, 1)
			b:SetBackdropColor(r * .3, g * .3, bl * .3, .8)
		else
			b:SetBackdropBorderColor(.25, .25, .25, 1)
			b:SetBackdropColor(0, 0, 0, .6)
		end
	end
end

local elapsed = 0
row:SetScript("OnUpdate", function()
	-- fade: fully visible while hovered or while the menu/slider is open, else the idle level
	local idle = ChatButtonsDB and ChatButtonsDB.idle_alpha or 1
	local active = MouseIsOver(this) or alpha_frame:IsShown() or (DropDownList1 and DropDownList1:IsShown())
	local want = active and 1 or idle
	local now = this:GetAlpha()
	if now ~= want then
		local step = arg1 * 4
		if now < want then now = math.min(want, now + step) else now = math.max(want, now - step) end
		this:SetAlpha(now)
	end

	elapsed = elapsed + arg1
	if elapsed < .3 then return end
	elapsed = 0
	update()
end)

row:RegisterEvent("VARIABLES_LOADED")
row:SetScript("OnEvent", function()
	ChatButtonsDB = ChatButtonsDB or {}
	layout()
	if ChatButtonsDB.hidden then row:Hide() end
	local p = ChatButtonsDB.pos
	if p then
		row:ClearAllPoints()
		row:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		default_position()
	end
	update()
end)

SLASH_CHATBUTTONS1 = "/chatbuttons"
SLASH_CHATBUTTONS2 = "/cbuttons"
SlashCmdList.CHATBUTTONS = function(msg)
	msg = string.lower(msg or "")
	local _, _, word, num = string.find(msg, "^(%a+)%s*(%d*)")
	num = tonumber(num)
	local n = table.getn(buttons)
	local say = function(text) DEFAULT_CHAT_FRAME:AddMessage("|cffff9900Chat Buttons:|r " .. text) end
	if word == "horizontal" or word == "vertical" or (word == "columns" and num) or (word == "rows" and num) then
		local per_line
		if word == "horizontal" then per_line = n
		elseif word == "vertical" then per_line = 1
		elseif word == "columns" then per_line = num
		else per_line = math.ceil(n / math.max(1, num)) end
		set_per_line(per_line)
		local per = ChatButtonsDB.per_line
		say(format("%d per row, %d row%s.", per, math.ceil(n / per), math.ceil(n / per) == 1 and "" or "s"))
		return
	end
	if msg == "reset" then
		ChatButtonsDB.pos = nil
		default_position()
		DEFAULT_CHAT_FRAME:AddMessage("|cffff9900Chat Buttons:|r back above the chat window.")
	elseif msg == "hide" or msg == "show" then
		if msg == "hide" then row:Hide() else row:Show() end
		ChatButtonsDB.hidden = msg == "hide" or nil
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffff9900Chat Buttons:|r Shift + drag a button to move the row.")
		DEFAULT_CHAT_FRAME:AddMessage("  /chatbuttons horizontal | vertical - one row or one column")
		DEFAULT_CHAT_FRAME:AddMessage("  /chatbuttons columns <n> | rows <n> - a grid, e.g. columns 4 or rows 2")
		DEFAULT_CHAT_FRAME:AddMessage("  /chatbuttons reset - put it back above the chat   /chatbuttons hide | show")
	end
end
