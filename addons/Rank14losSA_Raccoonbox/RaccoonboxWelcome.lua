-- Shared Raccoonbox welcome message.
-- Every Raccoonbox addon ships this same file. The first one to load creates
-- the RaccoonboxWelcome frame and shows the message; the others see the frame
-- already exists and skip it, so players only get the message once.
-- The message waits 20 seconds after entering the world, so it lands after
-- the other addons' login messages.
if not RaccoonboxWelcome then
	local DELAY = 20
	RaccoonboxWelcome = CreateFrame("Frame")
	RaccoonboxWelcome:RegisterEvent("PLAYER_ENTERING_WORLD")
	RaccoonboxWelcome:SetScript("OnEvent", function()
		this:UnregisterEvent("PLAYER_ENTERING_WORLD")
		local waited = 0
		this:SetScript("OnUpdate", function()
			waited = waited + arg1
			if waited < DELAY then return end
			this:SetScript("OnUpdate", nil)
			local c = ChatTypeInfo and ChatTypeInfo["SYSTEM"] or { r = 1, g = 1, b = 0 }
			DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[Raccoonbox]|r Hey there, you're using Raccoonbox add-on(s)! Check out what other cool stuff |cff33ccffraccoonbox.com|r is cooking. Thanks and peace <3", c.r, c.g, c.b)
		end)
	end)
end
