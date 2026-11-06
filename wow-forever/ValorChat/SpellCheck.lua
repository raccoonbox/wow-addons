-- Spell checker: fixes common typos in your message when you press Enter.

local VC = ValorChat

local function Lookup(word)
	local key = word:lower()
	if VC.db.ignore[key] then return nil end
	local fix = VC.db.fixes[key] or VC.spellData[key]
	if not fix and VC.db.expand then fix = VC.shorthandData[key] end
	return fix
end

-- Keep the shape of what was typed: "Teh" -> "The", "TEH" -> "THE".
local function MatchCase(typed, fix)
	if #typed > 1 and typed == typed:upper() then
		return fix:upper()
	end
	local first = typed:sub(1, 1)
	if first ~= first:lower() then
		return fix:sub(1, 1):upper() .. fix:sub(2)
	end
	return fix
end

-- Fixes one piece of plain text. Bytes 128-255 count as letters so words with
-- ä/ö/å (UTF-8) stay whole and are never split into fake "words".
local function FixWords(text, fixed)
	return (text:gsub("([%a'\128-\255]+)", function(word)
		local fix = Lookup(word)
		if not fix then return word end
		fix = MatchCase(word, fix)
		if fix ~= word then fixed[#fixed + 1] = word .. " -> " .. fix end
		return fix
	end))
end

-- Web addresses are left exactly as typed (no "u" -> "you" inside a link).
local function LooksLikeUrl(tok)
	return tok:find("://", 1, true) or tok:lower():find("^www%.") or tok:find("%.%a%a+/")
end

local function FixPlain(text, fixed)
	return (text:gsub("%S+", function(tok)
		if LooksLikeUrl(tok) then return tok end
		return FixWords(tok, fixed)
	end))
end

-- Fixes a whole message but leaves item/spell/quest links untouched.
function VC.SpellFix(text)
	local fixed = {}
	local out, pos = "", 1
	while true do
		local s, e = text:find("|c%x%x%x%x%x%x%x%x|H.-|h.-|h|r", pos)
		if not s then
			out = out .. FixPlain(text:sub(pos), fixed)
			break
		end
		out = out .. FixPlain(text:sub(pos, s - 1), fixed) .. text:sub(s, e)
		pos = e + 1
	end
	return out, fixed
end

table.insert(VC.sendFilters, function(text)
	if not VC.db.spell then return text end
	local newText, fixed = VC.SpellFix(text)
	if VC.db.showFixes and #fixed > 0 then
		VC.Print("fixed: " .. table.concat(fixed, ", "))
	end
	return newText
end)
