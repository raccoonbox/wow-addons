-- Chat tweaks:
--  * arrow keys move the cursor inside the chat box (no Alt needed); Up / Down bring back
--    the messages you sent before
--  * web addresses in chat become clickable; clicking one opens a box to copy it (Ctrl+C)

local VC = ValorChat

---------------------------------------------------------------------------- arrow keys
local function FixArrows(eb)
	if eb and eb.SetAltArrowKeyMode and VC.db and VC.db.arrows then eb:SetAltArrowKeyMode(false) end
end

local function AllEditBoxes(fn)
	for _, name in ipairs(CHAT_FRAMES or {}) do fn(_G[name .. "EditBox"]) end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do fn(_G["ChatFrame" .. i .. "EditBox"]) end
end

if ChatEdit_ActivateChat then hooksecurefunc("ChatEdit_ActivateChat", FixArrows) end

---------------------------------------------------------------------------- sent-line history
-- Up = older line, Down = newer line. Remembers the last 50 lines you sent (also slash
-- commands and pasted text), kept between sessions.
local HISTORY_MAX = 50
local histPos = 0 -- 0 = not browsing; 1 = newest line

local function Remember(line)
	local h = VC.db.history
	if not line or line == "" or h[#h] == line then return end
	h[#h + 1] = line
	while #h > HISTORY_MAX do table.remove(h, 1) end
end

local function SetupHistory(eb)
	if not eb or eb.vcHistory then return end
	eb.vcHistory = true
	-- keep the last non-empty text: Blizzard clears the box before our "after Enter" hook runs
	eb:HookScript("OnTextChanged", function(self, userInput)
		local t = self:GetText()
		if t ~= "" and (userInput or not self.vcBrowsing) then self.vcLastTyped = t end
		if userInput then histPos = 0 end
	end)
	eb:HookScript("OnEnterPressed", function(self)
		if VC.db.arrows then Remember(self.vcLastTyped) end
		self.vcLastTyped, histPos = nil, 0
	end)
	eb:HookScript("OnEscapePressed", function(self) self.vcLastTyped, histPos = nil, 0 end)
	eb:HookScript("OnArrowPressed", function(self, key)
		if not VC.db.arrows or (key ~= "UP" and key ~= "DOWN") then return end
		local h = VC.db.history
		if #h == 0 then return end
		if key == "UP" then histPos = math.min(histPos + 1, #h) else histPos = math.max(histPos - 1, 0) end
		self.vcBrowsing = true
		self:SetText(histPos > 0 and h[#h - histPos + 1] or "")
		self.vcBrowsing = false
		self:SetCursorPosition(#self:GetText())
	end)
end

---------------------------------------------------------------------------- clickable links
local TLDS = {}
for t in ("com net org io gg tv eu fi se no dk de nl be fr es it uk co me info app dev ly gl tk ru pl us ca"):gmatch("%a+") do
	TLDS[t] = true
end

local LINK = "|cff66bbff|Hgarrmission:valorurl:%s|h[%s]|h|r"

local function IsUrl(word)
	if word:find("|", 1, true) then return false end -- part of an item/player link
	if word:match("^%a[%w+.-]*://%S+$") then return true end
	if word:lower():match("^www%.[%w_-]+%.%S+$") then return true end
	-- bare address like raccoonbox.com or konstantin.fi/blog: the ending must be a known one
	local host = word:match("^([%w_%-%.]+%.%a%a+)/%S*$") or word:match("^([%w_%-%.]+%.%a%a+)$")
	if not host then return false end
	local tld = host:match("%.(%a+)$")
	return tld ~= nil and TLDS[tld:lower()] == true
end

local function Linkify(msg)
	if type(msg) ~= "string" or not VC.db or not VC.db.links then return msg end
	local changed = false
	local out = msg:gsub("%S+", function(word)
		-- keep trailing punctuation out of the link: "see raccoonbox.com!" -> link + "!"
		local core, tail = word:match("^(.-)([%.,!?;:%)]*)$")
		if core ~= "" and IsUrl(core) then
			changed = true
			return LINK:format(core, core) .. tail
		end
		return word
	end)
	return changed and out or msg
end

local function Filter(_, _, msg, ...)
	local new = Linkify(msg)
	if new ~= msg then return false, new, ... end
	return false
end

for _, e in ipairs({ "SAY", "YELL", "WHISPER", "WHISPER_INFORM", "BN_WHISPER", "BN_WHISPER_INFORM",
	"PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
	"GUILD", "OFFICER", "CHANNEL", "EMOTE", "COMMUNITIES_CHANNEL", "SYSTEM" }) do
	ChatFrame_AddMessageEventFilter("CHAT_MSG_" .. e, Filter)
end

StaticPopupDialogs.VALORCHAT_URL = {
	text = "Copy the link with Ctrl+C:",
	button1 = OKAY or "OK",
	hasEditBox = true,
	editBoxWidth = 360,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
	OnShow = function(self, data)
		local eb = self.editBox or self.EditBox
		if eb then eb:SetText(data or ""); eb:HighlightText(); eb:SetFocus() end
	end,
	EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

-- Catch clicks on our links before Blizzard's own link handling sees them.
local wrapped = {}
local function WrapChatFrame(cf)
	if not cf or wrapped[cf] then return end
	local orig = cf:GetScript("OnHyperlinkClick")
	if not orig then return end
	wrapped[cf] = true
	cf:SetScript("OnHyperlinkClick", function(self, link, text, button, ...)
		local url = type(link) == "string" and link:match("^garrmission:valorurl:(.+)$")
		if url then
			StaticPopup_Show("VALORCHAT_URL", nil, nil, url)
			return
		end
		return orig(self, link, text, button, ...)
	end)
end

local function WrapAll()
	for _, name in ipairs(CHAT_FRAMES or {}) do WrapChatFrame(_G[name]) end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do WrapChatFrame(_G["ChatFrame" .. i]) end
	AllEditBoxes(SetupHistory)
	AllEditBoxes(FixArrows)
end
if FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", WrapAll) end -- pop-out whisper windows

---------------------------------------------------------------------------- setup
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
	AllEditBoxes(FixArrows)
	WrapAll()
end)

function VC.ChatTweakCommand(cmd, rest)
	local key = cmd == "arrows" and "arrows" or "links"
	if rest == "on" then VC.db[key] = true elseif rest == "off" then VC.db[key] = false else VC.db[key] = not VC.db[key] end
	if key == "arrows" then
		AllEditBoxes(function(eb) if eb and eb.SetAltArrowKeyMode then eb:SetAltArrowKeyMode(not VC.db.arrows) end end)
	end
	VC.Print((key == "arrows" and "Arrow keys in chat box" or "Clickable web links") .. ": "
		.. (VC.db[key] and "|cff00ff00on|r" or "|cffff0000off|r"))
end
