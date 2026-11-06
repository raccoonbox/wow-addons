-- Quick lines: typing just "gg" or "gz" sends a friendlier message instead.
-- Also /gg with a keybind, and /vc gg ... / /vc gz ... to manage the lines.

local VC = ValorChat

VC.quickLines = {
	gg = {
		label = "GG",
		triggers = { ["gg"] = true, ["ggwp"] = true, ["gg wp"] = true, ["gg!"] = true, ["gg all"] = true },
		defaults = {
			"GG everyone, well played!",
			"Good game all, thanks for the fight!",
			"GG! That was a fun one, well played everybody.",
			"GG WP - thanks for the game, see you next round!",
			"Good game everyone, great teamwork out there!",
			"GG! Respect to both teams.",
			"GG all, that was a good match. Thanks!",
			"Well played everyone, GG!",
		},
	},
	gz = {
		label = "GZ",
		triggers = { ["gz"] = true, ["gz!"] = true, ["gratz"] = true, ["grats"] = true, ["grz"] = true },
		defaults = {
			"Congratulations!",
			"Congrats, well deserved!",
			"Gratz, that's awesome!",
			"Congrats, nicely done!",
			"Well done, congratulations!",
			"Big congrats!",
			"Congratulations, so happy for you!",
			"Gratz, great job!",
		},
	},
	gj = {
		label = "GJ",
		triggers = { ["gj"] = true, ["gj!"] = true, ["nj"] = true, ["gjob"] = true },
		defaults = {
			"Good job!",
			"Great job, well done!",
			"Nice work!",
			"Good job, that was great!",
			"Well done, nicely played!",
			"Great work, keep it up!",
			"Nice one, good job!",
			"Excellent work!",
		},
	},
	thx = {
		label = "THX",
		triggers = { ["thx"] = true, ["thx!"] = true, ["ty"] = true, ["tyvm"] = true, ["thnx"] = true, ["thanx"] = true },
		defaults = {
			"Thank you so much!",
			"Thanks a lot, really appreciate it!",
			"Thank you, you're the best!",
			"Many thanks!",
			"Thanks, that's very kind of you!",
			"Thank you, much appreciated!",
			"Thanks a bunch!",
			"Thank you, that helps a lot!",
		},
	},
}

local lastIndex = {}
function VC.RandomLine(kind)
	local q = VC.quickLines[kind]
	local list = VC.db[kind .. "Msgs"]
	if #list == 0 then list = q.defaults end
	local n = #list
	local i = math.random(1, n)
	if n > 1 and i == lastIndex[kind] then i = i % n + 1 end
	lastIndex[kind] = i
	return list[i]
end

function VC.RandomGG()
	return VC.RandomLine("gg")
end

-- Runs first (position 1), before shorthand expansion turns "thx" into "thanks".
table.insert(VC.sendFilters, 1, function(text)
	local trimmed = (text:match("^%s*(.-)%s*$") or ""):lower()
	for kind, q in pairs(VC.quickLines) do
		if VC.db[kind] and q.triggers[trimmed] then
			return VC.RandomLine(kind)
		end
	end
	return text
end)

function ValorChat_SendGG()
	VC.SendGroup(VC.RandomLine("gg"), true)
end

SLASH_VALORGG1 = "/gg"
SlashCmdList.VALORGG = function() ValorChat_SendGG() end

-- /vc gg ... and /vc gz ...
function VC.QuickLineCommand(kind, rest)
	local q = VC.quickLines[kind]
	local key = kind .. "Msgs"
	local sub, arg = (rest or ""):match("^(%S*)%s*(.-)$")
	sub = (sub or ""):lower()
	arg = arg or ""
	local list = VC.db[key]
	if sub == "on" or sub == "off" or sub == "" then
		if sub == "" then VC.db[kind] = not VC.db[kind] else VC.db[kind] = (sub == "on") end
		VC.Print(q.label .. " messages: " .. (VC.db[kind] and "|cff00ff00on|r" or "|cffff0000off|r"))
	elseif sub == "add" then
		if arg == "" then VC.Print("usage: /vc " .. kind .. " add <message>") return end
		table.insert(list, arg)
		VC.Print("Added. You now have " .. #list .. " " .. q.label .. " messages of your own.")
	elseif sub == "list" then
		local shown = list
		if #list == 0 then
			VC.Print("Using the built-in " .. q.label .. " messages (add your own with /vc " .. kind .. " add):")
			shown = q.defaults
		end
		for i = 1, #shown do
			DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ". " .. shown[i])
		end
	elseif sub == "del" then
		local i = tonumber(arg)
		if not i or not list[i] then VC.Print("usage: /vc " .. kind .. " del <number from /vc " .. kind .. " list>") return end
		table.remove(list, i)
		VC.Print("Removed message " .. i .. ".")
	elseif sub == "reset" then
		VC.db[key] = {}
		VC.Print("Back to the built-in " .. q.label .. " messages.")
	else
		VC.Print("usage: /vc " .. kind .. " on|off | add <message> | list | del <number> | reset")
	end
end

function VC.GGCommand(rest)
	VC.QuickLineCommand("gg", rest)
end
