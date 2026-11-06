-- HideLockedSlots: hide the authenticator-locked backpack slots and the "+" upsell button.
-- A slot counts as locked only when it belongs to the backpack (bag 0) and its slot number is
-- beyond the backpack's real size. This is checked live every time, because WoW reuses slot
-- buttons: a button that showed a locked slot a moment ago can hold a normal item later.
local pending = false

local function BagFrames()
	local list = {}
	for i = 1, (NUM_CONTAINER_FRAMES or 13) do
		local f = _G["ContainerFrame" .. i]
		if f then list[#list + 1] = f end
	end
	if ContainerFrameCombinedBags then list[#list + 1] = ContainerFrameCombinedBags end
	return list
end

local function IsLocked(button)
	if not (button.GetBagID and button.GetID) then return false end
	local ok, bag = pcall(button.GetBagID, button)
	if not ok or bag ~= 0 then return false end
	local real = C_Container.GetContainerNumSlots(0) or 16
	return button:GetID() > real
end

local function OnButtonShow(self)
	if not InCombatLockdown() and IsLocked(self) then self:Hide() end
end

local function Clean(frame)
	local add = frame.AddSlotsButton
	if add then
		add:Hide()
		if not add.hlsHooked then
			add.hlsHooked = true
			hooksecurefunc(add, "Show", function(self) self:Hide() end)
		end
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		if child.GetBagID then
			if not child.hlsHooked then
				child.hlsHooked = true
				child:HookScript("OnShow", OnButtonShow)
			end
			if child:IsShown() and IsLocked(child) then child:Hide() end
		end
	end
end

local reported = false
local function CleanAll()
	pending = false
	if InCombatLockdown() then return end -- try again after combat
	for _, f in ipairs(BagFrames()) do
		local ok, err = pcall(Clean, f)
		if not ok and not reported then
			reported = true
			print("|cffff4040Hide Locked Slots error:|r " .. tostring(err))
		end
	end
end

local function Queue()
	if pending then return end
	pending = true
	C_Timer.After(0, CleanAll)
	C_Timer.After(0.2, CleanAll) -- second pass after Blizzard finishes laying out slots
end

for _, f in ipairs(BagFrames()) do
	f:HookScript("OnShow", Queue)
	for _, method in ipairs({ "Update", "UpdateItems", "UpdateItemLayout", "UpdateExtendedSlots" }) do
		if type(f[method]) == "function" then hooksecurefunc(f, method, Queue) end
	end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", Queue)

-- /hls : show which backpack buttons the addon considers locked (open your bags first)
SLASH_HIDELOCKEDSLOTS1 = "/hls"
SlashCmdList.HIDELOCKEDSLOTS = function()
	CleanAll()
	print("HLS: backpack real slots =", C_Container.GetContainerNumSlots(0))
	for _, f in ipairs(BagFrames()) do
		for _, c in ipairs({ f:GetChildren() }) do
			if c.GetBagID then
				local ok, bag = pcall(c.GetBagID, c)
				if ok and bag == 0 then
					print(("  %s id=%d locked=%s shown=%s"):format(f:GetName() or "?", c:GetID(),
						tostring(IsLocked(c)), tostring(c:IsShown())))
				end
			end
		end
	end
end

---------------------------------------------------------------------------- options page
if RaccoonboxOptions then
	RaccoonboxOptions.AddPanel({
		name = "Hide Locked Slots",
		about = "Hides the 4 locked \"secure your account\" backpack slots and the green + button, so your backpack "
			.. "only shows the slots you can use. Nothing to set up.",
		commands = { { "/hls", "list which backpack slots are hidden (open your bags first) - for bug reports" } },
	})
end
