-- Shared Raccoonbox file (WoW Forever version): welcome message + "new version" check.
-- Every Raccoonbox addon ships this exact same file; each copy reads its addon's name and version
-- from that addon's .toc, so nothing in here changes between addons.
--
-- Every copy registers its addon. The newest copy of the shared code (LIB) does the work; older
-- copies step aside, so players get one welcome message and one version check however many
-- Raccoonbox addons they use.
-- Version check: the addons tell each other their versions over addon messages (guild, party, raid,
-- battleground/instance). When a copy hears a higher version of an addon you have, it prints one
-- line. Only version numbers are sent; the text shown is always this file's own, never something
-- received.
local ADDON_FOLDER = ...
local LIB = 2

local function meta(field)
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	return get and get(ADDON_FOLDER, field)
end

-- "Valor Chat |cffff9900[Raccoonbox]|r" -> "Valor Chat"
local title = (meta("Title") or ADDON_FOLDER):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
title = title:gsub("%s*%[Raccoonbox%]%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
-- "ValorChat_Raccoonbox" -> "valorchat"
local id = ADDON_FOLDER:gsub("_Raccoonbox$", ""):lower()

RaccoonboxAddons = RaccoonboxAddons or {}
RaccoonboxAddons[id] = { name = title, version = meta("Version") or "0" }

if RaccoonboxWelcome and (RaccoonboxWelcome.lib or 1) >= LIB then return end
if RaccoonboxWelcome then
	-- an older copy loaded first: take over from it (the old one only had the welcome message)
	RaccoonboxWelcome:UnregisterAllEvents()
	RaccoonboxWelcome:SetScript("OnEvent", nil)
	RaccoonboxWelcome:SetScript("OnUpdate", nil)
end

local DELAY = 20          -- seconds after entering the world before the welcome message
local SEND_DELAY = 25     -- ... and before telling others our versions
local THROTTLE = 600      -- tell the same channel at most every 10 minutes
local PREFIX = "RBXV"
local SITE = "|cff33ccffraccoonbox.com|r"
local DOWNLOAD = "|cff33ccffgithub.com/raccoonbox/wow-addons|r"

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end

local f = CreateFrame("Frame")
RaccoonboxWelcome = f
f.lib = LIB

local function say(text)
	local c = ChatTypeInfo and ChatTypeInfo["SYSTEM"] or { r = 1, g = 1, b = 0 }
	DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[Raccoonbox]|r " .. text, c.r, c.g, c.b)
end

-- "1.10.2" -> { 1, 10, 2 }; nil when it isn't a plain version number
local function parse(v)
	if type(v) ~= "string" or not v:find("^%d+[%.%d]*$") then return nil end
	local out = {}
	for n in v:gmatch("%d+") do out[#out + 1] = tonumber(n) end
	return out
end
local function newer(a, b) -- is version a higher than version b?
	local x, y = parse(a), parse(b)
	if not x or not y then return false end
	for i = 1, math.max(#x, #y) do
		local p, q = x[i] or 0, y[i] or 0
		if p ~= q then return p > q end
	end
	return false
end

-- the channels we can talk on right now
local function channels()
	local out = {}
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then out[#out + 1] = "INSTANCE_CHAT"
	elseif IsInRaid() then out[#out + 1] = "RAID"
	elseif IsInGroup() then out[#out + 1] = "PARTY" end
	if IsInGuild() then out[#out + 1] = "GUILD" end
	return out
end

-- our versions as messages of at most 240 characters: "1:valorchat=2.1.1,craftwell=0.1.0"
local function messages()
	local out, cur = {}, ""
	for key, a in pairs(RaccoonboxAddons) do
		if parse(a.version) then
			local part = key .. "=" .. a.version
			if cur ~= "" and #cur + #part + 1 > 236 then out[#out + 1] = "1:" .. cur cur = "" end
			cur = cur == "" and part or (cur .. "," .. part)
		end
	end
	if cur ~= "" then out[#out + 1] = "1:" .. cur end
	return out
end

local last_sent = {}
local function send(channel)
	if last_sent[channel] and GetTime() - last_sent[channel] < THROTTLE then return end
	last_sent[channel] = GetTime()
	for _, msg in ipairs(messages()) do
		-- addon messages can be blocked (e.g. during boss fights); never let that break anything
		pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, channel)
	end
end

local send_at -- time to tell everyone (nil = nothing planned)
local function plan_send(delay)
	local t = GetTime() + delay
	if not send_at or t < send_at then send_at = t end
end

local told = {}    -- addon id -> true once we printed its new version this session
local replies = {} -- channel -> true when someone there has an older version than ours
local function heard(msg, channel, sender)
	if issecretvalue and (issecretvalue(msg) or issecretvalue(sender)) then return end
	if type(msg) ~= "string" or type(sender) ~= "string" then return end
	if Ambiguate(sender, "none") == UnitName("player") then return end
	local body = msg:match("^1:(.*)$")
	if not body then return end
	for key, version in body:gmatch("([%w_]+)=([%d%.]+)") do
		local mine = RaccoonboxAddons[key]
		if mine and parse(version) then
			if newer(version, mine.version) and not told[key] then
				told[key] = true
				say(mine.name .. " " .. version .. " is out (you have " .. mine.version .. "). Get it at " .. DOWNLOAD .. ".")
			elseif newer(mine.version, version) then
				replies[channel] = true -- they'll learn about ours
			end
		end
	end
	if next(replies) then plan_send(5) end
end

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_GUILD_UPDATE")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender)
	if event == "CHAT_MSG_ADDON" then
		if prefix == PREFIX then heard(msg, channel, sender) end
	elseif event == "PLAYER_ENTERING_WORLD" then
		if not self.welcome_at and not self.welcomed then self.welcome_at = GetTime() + DELAY end
		plan_send(SEND_DELAY) -- also every time you enter a battleground or an instance
	else
		plan_send(10) -- joined a group or raid, or a guild
	end
end)
f:SetScript("OnUpdate", function(self)
	local now = GetTime()
	if self.welcome_at and now >= self.welcome_at then
		self.welcome_at, self.welcomed = nil, true
		say("Hey there, you're using Raccoonbox add-on(s)! Check out what other good design " .. SITE .. " is producing."
			.. (RaccoonboxOptions and " Type |cffffd100/raccoonbox|r to see what your add-ons can do." or "")
			.. " Thanks and peace <3")
	end
	if send_at and now >= send_at then
		send_at = nil
		for _, channel in ipairs(channels()) do send(channel) end
		wipe(replies)
	end
end)
