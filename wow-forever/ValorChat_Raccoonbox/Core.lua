-- Valor Chat (WoW Forever): shared helpers, saved settings, the chat send hook and slash commands.

ValorChat = {}
local VC = ValorChat

VC.defaults = {
	spell = true,       -- autocorrect messages on send
	showFixes = true,   -- print what was corrected (only you see it)
	expand = true,      -- expand shorthand: inc -> incoming, rdy -> ready...
	gg = true,          -- turn a plain "gg" into a friendlier message
	fixes = {},         -- your own corrections: wrong -> right
	ignore = {},        -- built-in corrections you switched off
	ggMsgs = {},        -- your own GG messages (empty = use the built-in list)
	gz = true,          -- turn a plain "gz" into a congratulations message
	gzMsgs = {},
	gj = true,          -- turn a plain "gj" into a good-job message
	gjMsgs = {},
	thx = true,         -- turn a plain "thx" / "ty" into a thank-you message
	thxMsgs = {},
	arrows = true,      -- arrow keys move the cursor in the chat box, Up/Down = sent-message history
	links = true,       -- web addresses in chat are clickable and copyable
	history = {},       -- last lines you sent, for Up/Down in the chat box
}

BINDING_HEADER_VALORCHAT = "Valor Chat"
BINDING_NAME_VALORCHAT_GG = "Send a GG message"

function VC.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffff9900Valor Chat:|r " .. msg)
end

-- Best channel to reach the team, or nil when solo.
function VC.GroupChannel()
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end -- battlegrounds, dungeon finder
	if IsInRaid() then return "RAID" end
	if IsInGroup() then return "PARTY" end
	return nil
end

VC.lastSend = 0
local function Throttled()
	local now = GetTime()
	if now - VC.lastSend < 1 then
		VC.Print("Slow down a little (anti-spam).")
		return true
	end
	VC.lastSend = now
	return false
end

function VC.SendGroup(msg, sayWhenSolo)
	local channel = VC.GroupChannel()
	if not channel then
		if not sayWhenSolo then
			VC.Print("Not in a group. Would send: " .. msg)
			return
		end
		channel = "SAY"
	end
	if Throttled() then return end
	SendChatMessage(msg, channel)
end

-- Filters run on every message you type, right before it is sent.
-- Each takes the text and returns the (possibly changed) text.
VC.sendFilters = {}

-- Blizzard's send code first parses the edit box ("/p hi" becomes "hi", slash commands are
-- handled), then reads the text again and sends it. We hook in right after the parse, so
-- changing the text there changes what gets sent. It is a post-hook, not a replacement,
-- so typed /cast, /target etc. keep working.
local function AfterParse(editBox, send)
	if not send or send == 0 then return end
	local text = editBox:GetText()
	if not text or text == "" or text:sub(1, 1) == "/" then return end
	local newText = text
	for _, filter in ipairs(VC.sendFilters) do
		newText = filter(newText) or newText
	end
	if newText ~= text then editBox:SetText(newText) end
end

local hooked = false
if ChatEdit_ParseText then
	hooksecurefunc("ChatEdit_ParseText", AfterParse)
	hooked = true
end
-- newer clients may parse through the edit box's own method instead
for i = 1, (NUM_CHAT_WINDOWS or 10) do
	local eb = _G["ChatFrame" .. i .. "EditBox"]
	if eb and type(eb.ParseText) == "function" and not hooked then
		hooksecurefunc(eb, "ParseText", AfterParse)
	end
end

local function SetFlag(key, value, label)
	if value == "on" then VC.db[key] = true
	elseif value == "off" then VC.db[key] = false
	else VC.db[key] = not VC.db[key] end
	VC.Print(label .. ": " .. (VC.db[key] and "|cff00ff00on|r" or "|cffff0000off|r"))
end

local function Help()
	VC.Print("commands:")
	local lines = {
		"  /vc spell on|off  - fix typos when you send a message",
		"  /vc expand on|off  - write out shorthand (inc -> incoming, rdy -> ready...)",
		"  /vc quiet  - toggle the 'fixed: teh -> the' notices",
		"  /vc fix <wrong> <right>  - add your own correction",
		"  /vc unfix <word>  - stop correcting a word",
		"  /vc gg on|off  - turn a typed 'gg' into a friendly message",
		"  /vc gg add <message> | gg list | gg del <number> | gg reset",
		"  /gg  - send a random GG message to your group",
		"  /vc gz ... | /vc gj ... | /vc thx ...  - same for 'gz', 'gj', 'thx' / 'ty'",
		"  /vc arrows on|off  - arrow keys move the cursor in the chat box, Up/Down = earlier messages",
		"  /vc links on|off  - make web addresses in chat clickable to copy them",
	}
	for _, l in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage(l) end
end

SLASH_VALORCHAT1 = "/vc"
SLASH_VALORCHAT2 = "/valorchat"
SlashCmdList.VALORCHAT = function(msg)
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	rest = rest or ""
	if cmd == "spell" then
		SetFlag("spell", rest, "Spell check")
	elseif cmd == "expand" then
		SetFlag("expand", rest, "Shorthand expansion")
	elseif cmd == "quiet" then
		SetFlag("showFixes", nil, "Show corrections")
	elseif cmd == "fix" then
		local wrong, right = rest:match("^(%S+)%s+(.+)$")
		if not wrong then VC.Print("usage: /vc fix <wrong> <right>") return end
		wrong = wrong:lower()
		VC.db.fixes[wrong] = right
		VC.db.ignore[wrong] = nil
		VC.Print("Will correct '" .. wrong .. "' to '" .. right .. "'.")
	elseif cmd == "unfix" then
		if rest == "" then VC.Print("usage: /vc unfix <word>") return end
		local word = rest:lower()
		VC.db.fixes[word] = nil
		VC.db.ignore[word] = true
		VC.Print("Will no longer correct '" .. word .. "'.")
	elseif cmd == "gg" or cmd == "gz" or cmd == "gj" or cmd == "thx" then
		VC.QuickLineCommand(cmd, rest)
	elseif (cmd == "arrows" or cmd == "links") and VC.ChatTweakCommand then
		VC.ChatTweakCommand(cmd, rest)
	else
		Help()
	end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
	if name ~= "ValorChat_Raccoonbox" then return end
	ValorChatDB = ValorChatDB or {}
	for k, v in pairs(VC.defaults) do
		if ValorChatDB[k] == nil then
			ValorChatDB[k] = type(v) == "table" and {} or v
		end
	end
	VC.db = ValorChatDB
	self:UnregisterEvent("ADDON_LOADED")
	if not hooked and not (ChatFrame1EditBox and ChatFrame1EditBox.ParseText) then
		VC.Print("|cffff4040couldn't find the chat send code - autocorrect is off.|r")
	end
end)
