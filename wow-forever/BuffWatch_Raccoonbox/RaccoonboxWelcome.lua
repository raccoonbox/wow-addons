-- Shared Raccoonbox welcome message (WoW Forever version).
-- Every Raccoonbox addon ships this same file. The first one to load creates the
-- RaccoonboxWelcome frame and shows the message; the others see it already exists and
-- skip it, so players get the message only once. It waits 20 seconds after entering the
-- world so it lands after the other addons' login messages.
if not RaccoonboxWelcome then
	local DELAY = 20
	RaccoonboxWelcome = CreateFrame("Frame")
	RaccoonboxWelcome:RegisterEvent("PLAYER_ENTERING_WORLD")
	RaccoonboxWelcome:SetScript("OnEvent", function(self)
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		C_Timer.After(DELAY, function()
			local c = ChatTypeInfo and ChatTypeInfo["SYSTEM"] or { r = 1, g = 1, b = 0 }
			DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[Raccoonbox]|r Hey there, you're using Raccoonbox add-on(s)! Check out what other good design |cff33ccffraccoonbox.com|r is producing." .. (RaccoonboxOptions and " Type |cffffd100/raccoonbox|r to see what your add-ons can do." or "") .. " Thanks and peace <3", c.r, c.g, c.b)
		end)
	end)
end
