-- Shared Raccoonbox file: welcome message + "new version" check. Every Raccoonbox addon ships this file;
-- only the next line differs (which addon it belongs to; version nil = read it from the addon's .toc).
local ADDON_ID, ADDON_NAME, ADDON_FOLDER, ADDON_VERSION = "outfitter", "Outfitter", "Outfitter_Raccoonbox", "1.0.0"

-- Every copy registers its addon. The newest copy of the shared code (LIB) does the work; older copies
-- step aside, so players get one welcome message and one version check however many addons they use.
-- Version check: the addons tell each other their versions over addon messages (guild, party, raid,
-- battleground). When a copy hears a higher version of an addon you have, it prints one line. Only
-- version numbers are sent; the text shown is always this file's own, never something received.
local LIB = 3
RaccoonboxAddons = RaccoonboxAddons or {}
RaccoonboxAddons[ADDON_ID] = { name = ADDON_NAME,
	version = ADDON_VERSION or GetAddOnMetadata(ADDON_FOLDER, "Version") or "0" }

if RaccoonboxWelcome and (RaccoonboxWelcome.lib or 1) >= LIB then return end
if RaccoonboxWelcome then
	-- an older copy loaded first: take over from it
	RaccoonboxWelcome:UnregisterAllEvents()
	RaccoonboxWelcome:SetScript("OnEvent", nil)
	RaccoonboxWelcome:SetScript("OnUpdate", nil)
end

local DELAY = 20          -- seconds after entering the world before the welcome message
local SEND_DELAY = 25     -- ... and before telling others our versions
local THROTTLE = 600      -- tell the same channel at most every 10 minutes
local PREFIX = "RBXV"
local SITE = "|cff33ccffraccoonbox.com|r"
local DOWNLOAD = "|cff33ccffgithub.com/raccoonbox/wow-addons/releases|r"

local f = CreateFrame("Frame")
RaccoonboxWelcome = f
f.lib = LIB

local function say(text)
	local c = ChatTypeInfo and ChatTypeInfo["SYSTEM"] or { r = 1, g = 1, b = 0 }
	DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[Raccoonbox]|r " .. text, c.r, c.g, c.b)
end

-- "1.10.2" -> compare part by part; nil when it isn't a plain version number
local function parse(v)
	local out = {}
	for n in string.gfind(v or "", "(%d+)") do tinsert(out, tonumber(n)) end
	if table.getn(out) == 0 or not string.find(v, "^%d+[%.%d]*$") then return nil end
	return out
end
local function newer(a, b) -- is version a higher than version b?
	local x, y = parse(a), parse(b)
	if not x or not y then return false end
	for i = 1, math.max(table.getn(x), table.getn(y)) do
		local p, q = x[i] or 0, y[i] or 0
		if p ~= q then return p > q end
	end
	return false
end

local function in_battleground()
	for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
		if GetBattlefieldStatus(i) == "active" then return true end
	end
end

-- the channels we can talk on right now
local function channels()
	local out = {}
	if IsInGuild() then tinsert(out, "GUILD") end
	if GetNumRaidMembers() > 0 then tinsert(out, "RAID")
	elseif GetNumPartyMembers() > 0 then tinsert(out, "PARTY") end
	if in_battleground() then tinsert(out, "BATTLEGROUND") end
	return out
end

-- our versions as messages of at most 240 characters: "1:dresscode=1.0.0,chatbuttons=1.0.0"
local function messages()
	local out, cur = {}, ""
	for id, a in pairs(RaccoonboxAddons) do
		if parse(a.version) then
			local part = id .. "=" .. a.version
			if cur ~= "" and strlen(cur) + strlen(part) + 1 > 236 then tinsert(out, "1:" .. cur) cur = "" end
			cur = cur == "" and part or (cur .. "," .. part)
		end
	end
	if cur ~= "" then tinsert(out, "1:" .. cur) end
	return out
end

local last_sent = {}
local function send(channel)
	if last_sent[channel] and GetTime() - last_sent[channel] < THROTTLE then return end
	last_sent[channel] = GetTime()
	for _, msg in ipairs(messages()) do SendAddonMessage(PREFIX, msg, channel) end
end

local send_at -- time to tell everyone (nil = nothing planned)
local function plan_send(delay)
	local t = GetTime() + delay
	if not send_at or t < send_at then send_at = t end
end

local told = {}   -- addon id -> true once we printed its new version this session
local replies = {} -- channel -> true when someone there has an older version than ours
local function heard(msg, channel, sender)
	if sender == UnitName("player") then return end
	local _, _, body = string.find(msg, "^1:(.*)$")
	if not body then return end
	for id, version in string.gfind(body, "([%w_]+)=([%d%.]+)") do
		local mine = RaccoonboxAddons[id]
		if mine and parse(version) then
			if newer(version, mine.version) and not told[id] then
				told[id] = true
				say(mine.name .. " " .. version .. " is out (you have " .. mine.version .. "). Get it at " .. DOWNLOAD .. ".")
			elseif newer(mine.version, version) then
				replies[channel] = true -- they'll learn about ours
			end
		end
	end
	if next(replies) then plan_send(5) end
end

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function()
	if event == "CHAT_MSG_ADDON" then
		if arg1 == PREFIX then heard(arg2, arg3, arg4) end
	elseif event == "PLAYER_ENTERING_WORLD" then
		if not this.welcome_at and not this.welcomed then this.welcome_at = GetTime() + DELAY end
		plan_send(SEND_DELAY) -- also every time you enter a battleground or an instance
	else
		plan_send(10) -- joined a group or raid
	end
end)
f:SetScript("OnUpdate", function()
	local now = GetTime()
	if this.welcome_at and now >= this.welcome_at then
		this.welcome_at, this.welcomed = nil, true
		say("Hey there, you're using Raccoonbox add-on(s)! Check out what other good design " .. SITE .. " is producing. Thanks and peace <3")
	end
	if send_at and now >= send_at then
		send_at = nil
		for _, channel in ipairs(channels()) do send(channel) end
		replies = {} -- a new table: in Lua 5.0 a cleared table keeps its old length
	end
end)

-- /raccoonbox: which Raccoonbox addons and versions you have
SLASH_RACCOONBOX1 = "/raccoonbox"
SlashCmdList.RACCOONBOX = function()
	local names = {}
	for _, a in pairs(RaccoonboxAddons) do tinsert(names, a.name .. " " .. a.version) end
	sort(names)
	say("your add-ons: " .. table.concat(names, ", ") .. ". New versions: " .. DOWNLOAD)
end
