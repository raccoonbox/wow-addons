-- HideButtons: keep chosen buttons hidden.
-- /hidebtn          hide the button under the mouse (hover it, then type this)
-- /hidebtn list     show hidden buttons
-- /hidebtn clear    unhide everything (takes effect after /reload)

local AUTO_PATTERNS = { "radio" } -- any minimap child whose name contains these is hidden

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99HideButtons:|r " .. msg)
end

local function KeepHidden(frame)
	if not frame or frame == Minimap or frame == UIParent or frame == WorldFrame then return end
	frame:Hide()
	frame:SetScript("OnShow", function() this:Hide() end)
end

local function ApplyAll()
	for name in pairs(HideButtonsDB.names) do
		KeepHidden(getglobal(name))
	end
	local parents = { Minimap, MinimapCluster }
	for _, parent in ipairs(parents) do
		local kids = { parent:GetChildren() }
		for i = 1, table.getn(kids) do
			local n = kids[i]:GetName()
			if n then
				local lower = string.lower(n)
				for _, pat in ipairs(AUTO_PATTERNS) do
					if string.find(lower, pat, 1, true) then KeepHidden(kids[i]) end
				end
			end
		end
	end
end

-- Some buttons are created a few seconds after login, so re-apply for a while.
local f = CreateFrame("Frame")
local elapsedTotal, nextRun = 0, 0
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	HideButtonsDB = HideButtonsDB or {}
	HideButtonsDB.names = HideButtonsDB.names or {}
	elapsedTotal, nextRun = 0, 0
	f:SetScript("OnUpdate", function()
		elapsedTotal = elapsedTotal + arg1
		if elapsedTotal >= nextRun then
			nextRun = nextRun + 1
			ApplyAll()
		end
		if elapsedTotal > 15 then f:SetScript("OnUpdate", nil) end
	end)
end)

SLASH_HIDEBUTTONS1 = "/hidebtn"
SlashCmdList["HIDEBUTTONS"] = function(msg)
	msg = string.lower(msg or "")
	if msg == "list" then
		local any = false
		for name in pairs(HideButtonsDB.names) do Print(name); any = true end
		if not any then Print("nothing hidden yet.") end
	elseif msg == "clear" then
		HideButtonsDB.names = {}
		Print("list cleared. Type /reload to bring the buttons back.")
	else
		local frame = GetMouseFocus()
		-- if the mouse is over a texture/child of the button, climb to a named frame
		while frame and not frame:GetName() and frame:GetParent() do
			frame = frame:GetParent()
		end
		local name = frame and frame:GetName()
		if not name or frame == Minimap or frame == UIParent or frame == WorldFrame then
			Print("hover your mouse over the button first, then type /hidebtn.")
			return
		end
		HideButtonsDB.names[name] = true
		KeepHidden(frame)
		Print("hidden " .. name .. ". It will stay hidden.")
	end
end
