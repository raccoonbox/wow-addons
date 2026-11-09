-- Valor Chat options page (Esc > Options > AddOns > Raccoonbox > Valor Chat)
if not RaccoonboxOptions then return end
local VC = ValorChat

local function Flag(key)
	return function() return VC.db and VC.db[key] end, function(v) VC.db[key] = v end
end

RaccoonboxOptions.AddPanel({
	name = "Valor Chat",
	about = "Makes chat friendlier: fixes typos when you press Enter, writes out shorthand, turns a typed \"gg\" or "
		.. "\"ty\" into a friendly line, lets you use the arrow keys and Up/Down history in the chat box and makes "
		.. "web addresses clickable so you can copy them.",
	commands = {
		{ "/vc", "list all Valor Chat commands" },
		{ "/vc fix teh the", "add your own correction" },
		{ "/vc unfix word", "stop correcting a word" },
		{ "/vc gg add <message>", "add your own GG line (also gz, gj, thx)" },
		{ "/vc gg list", "show the GG lines (also gz, gj, thx)" },
		{ "/gg", "send a random GG line to your group (can be bound to a key)" },
	},
	build = function(b)
		local g, s
		g, s = Flag("spell");     b:Check("Fix typos when you send (teh -> the, dont -> don't)", nil, g, s)
		g, s = Flag("showFixes"); b:Check("Show me what was fixed (only you see it)", nil, g, s)
		g, s = Flag("expand");    b:Check("Write out shorthand (brb -> be right back, rdy -> ready)", nil, g, s)
		g, s = Flag("gg");        b:Check("Typing just \"gg\" sends a friendly GG line", nil, g, s)
		g, s = Flag("gz");        b:Check("Typing just \"gz\" sends a congratulations line", nil, g, s)
		g, s = Flag("gj");        b:Check("Typing just \"gj\" sends a good-job line", nil, g, s)
		g, s = Flag("thx");       b:Check("Typing just \"thx\" or \"ty\" sends a thank-you line", nil, g, s)
		b:Check("Arrow keys move the cursor, Up/Down bring back earlier messages", nil,
			function() return VC.db and VC.db.arrows end,
			function(v) VC.ChatTweakCommand("arrows", v and "on" or "off") end)
		g, s = Flag("links");     b:Check("Make web addresses in chat clickable to copy them", nil, g, s)
	end,
})
