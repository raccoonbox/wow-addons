-- Mail Keeper: one button to collect all gold and items from your mailbox, and a record of every
-- auction house mail (sold, won, expired, cancelled, outbid) in My Market.
-- Mails with cash on delivery (COD) are never opened automatically.
local db
local function Print(msg) print("|cff33ff99Mail Keeper:|r " .. msg) end
local function Money(c)
	if MyMarket and MyMarket.Money then return MyMarket.Money(c) end
	c = math.floor(c + 0.5)
	return (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString and C_CurrencyInfo.GetCoinTextureString(c))
		or string.format("%dg %ds %dc", c / 10000, (c / 100) % 100, c % 100)
end

---------------------------------------------------------------------------- recording (also when you click mails yourself)
-- What a mail is, read before it is taken.
local function Describe(i)
	local _, _, sender, subject, money, cod, _, itemCount = GetInboxHeaderInfo(i)
	local e = { from = sender, sub = subject, money = money, items = itemCount, cod = cod }
	local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(i)
	if invoiceType then
		e.inv, e.itemName, e.who, e.bid, e.buyout, e.deposit, e.cut = invoiceType, itemName, playerName, bid, buyout, deposit, consignment
	end
	if itemCount and itemCount > 0 then
		e.got = {}
		for a = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
			local name, itemID, _, count = GetInboxItem(i, a)
			if name then e.got[#e.got + 1] = { itemID, count, name } end
		end
	end
	return e
end

local function Record(i, what) -- what: "money", "items" or "all"
	if not MyMarket then return end
	local e = Describe(i)
	if (what == "money" or what == "all") and e.money and e.money > 0 then
		local p = { kind = "mail_money", sign = 1 }
		for k, v in pairs(e) do p[k] = v end
		if e.got and e.got[1] then p.item = e.got[1][1] end
		MyMarket.Pending(p)
	end
	if (what == "items" or what == "all") and e.got and #e.got > 0 then
		for _, g in ipairs(e.got) do
			MyMarket.Log("mail_item", { item = g[1], n = g[2], from = e.from, sub = e.sub, inv = e.inv })
		end
	end
end

local lastAutoLoot = { i = nil, t = 0 }
hooksecurefunc("TakeInboxMoney", function(i) Record(i, "money") end)
hooksecurefunc("AutoLootMailItem", function(i) lastAutoLoot.i, lastAutoLoot.t = i, GetTime(); Record(i, "all") end)
hooksecurefunc("TakeInboxItem", function(i, a)
	if not MyMarket then return end
	-- "take all" uses this internally too; it's already recorded
	if lastAutoLoot.i == i and GetTime() - lastAutoLoot.t < 2 then return end
	local name, itemID, _, count = GetInboxItem(i, a)
	local _, _, sender, subject = GetInboxHeaderInfo(i)
	if itemID then MyMarket.Log("mail_item", { item = itemID, n = count, from = sender, sub = subject }) end
end)

---------------------------------------------------------------------------- collect all
local running, startMoney, taken, skippedCOD, waitUntil = false, 0, 0, 0, 0
local stepFrame = CreateFrame("Frame")

local function FreeSlots()
	local free = 0
	for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
		free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
	end
	return free
end

local function Finish(reason)
	running = false
	stepFrame:SetScript("OnUpdate", nil)
	local gained = GetMoney() - startMoney
	local msg = "collected " .. taken .. " mail" .. (taken == 1 and "" or "s")
	if gained > 0 then msg = msg .. ", " .. Money(gained) end
	if skippedCOD > 0 then msg = msg .. " (" .. skippedCOD .. " COD mail left alone)" end
	Print(msg .. (reason and (" - " .. reason) or "") .. ".")
end

local function Step()
	if GetTime() < waitUntil then return end
	if not (MailFrame and MailFrame:IsShown()) then Finish("mailbox closed") return end
	skippedCOD = 0
	local onlyGold = db and db.goldOnly
	for i = GetInboxNumItems(), 1, -1 do
		local _, _, _, _, money, cod, _, itemCount = GetInboxHeaderInfo(i)
		if cod and cod > 0 then
			skippedCOD = skippedCOD + 1
		elseif money and money > 0 and (onlyGold or not itemCount or itemCount == 0 or FreeSlots() == 0) then
			TakeInboxMoney(i); taken = taken + 1; waitUntil = GetTime() + 0.6
			return
		elseif not onlyGold and itemCount and itemCount > 0 then
			if FreeSlots() == 0 then Finish("bags are full") return end
			AutoLootMailItem(i); taken = taken + 1; waitUntil = GetTime() + 0.8
			return
		end
	end
	Finish()
end

local function CollectAll()
	if running then return end
	if not (MailFrame and MailFrame:IsShown()) then Print("open your mailbox first.") return end
	running, startMoney, taken, waitUntil = true, GetMoney(), 0, 0
	stepFrame:SetScript("OnUpdate", Step)
end

local button
local function MakeButton()
	if button or not InboxFrame then return end
	button = CreateFrame("Button", nil, InboxFrame, "UIPanelButtonTemplate")
	button:SetSize(120, 24)
	button:SetText("Collect all")
	-- top of the inbox, next to the page arrows area
	button:SetPoint("TOPRIGHT", InboxFrame, "TOPRIGHT", -40, -40)
	button:SetFrameStrata("HIGH")
	button:SetScript("OnClick", CollectAll)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Mail Keeper")
		GameTooltip:AddLine(db and db.goldOnly and "Takes the gold from every mail." or "Takes gold and items from every mail.", 1, 1, 1)
		GameTooltip:AddLine("Mails with cash on delivery (COD) are left alone.", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
end

---------------------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, a1)
	if event == "ADDON_LOADED" then
		if a1 ~= "MailKeeper_Raccoonbox" then return end
		MailKeeperDB = MailKeeperDB or {}
		db = MailKeeperDB
		self:RegisterEvent("MAIL_SHOW")
		self:RegisterEvent("MAIL_INBOX_UPDATE")
		return
	end
	if event == "MAIL_SHOW" then
		MakeButton()
		if db.autoCollect then C_Timer.After(1, CollectAll) end
	end
end)

SLASH_MAILKEEPER1 = "/mailkeeper"
SLASH_MAILKEEPER2 = "/mkeep"
SlashCmdList.MAILKEEPER = function(msg)
	msg = (msg or ""):lower()
	if msg == "gold" then
		db.goldOnly = not db.goldOnly
		Print("Collect all takes " .. (db.goldOnly and "only gold." or "gold and items."))
	elseif msg == "auto" then
		db.autoCollect = not db.autoCollect
		Print("collect automatically when the mailbox opens: " .. (db.autoCollect and "on" or "off"))
	else
		CollectAll()
	end
end

---------------------------------------------------------------------------- options page
if RaccoonboxOptions then
	RaccoonboxOptions.AddPanel({
		name = "Mail Keeper",
		about = "Adds a Collect all button to your mailbox: it takes the gold and items from every mail. Mails with "
			.. "cash on delivery (COD) are left alone. Every auction house mail (sold, won, expired, cancelled) is "
			.. "recorded in My Market, even when you open mails yourself.",
		commands = {
			{ "/mailkeeper", "collect all mail now (mailbox open), also /mkeep" },
			{ "/mailkeeper gold", "Collect all takes only gold, or gold and items" },
			{ "/mailkeeper auto", "collect automatically when you open the mailbox" },
		},
		build = function(b)
			b:Check("Collect all takes only gold (leaves items in the mail)", nil,
				function() return db and db.goldOnly end, function(v) db.goldOnly = v end)
			b:Check("Collect automatically when I open the mailbox", nil,
				function() return db and db.autoCollect end, function(v) db.autoCollect = v end)
		end,
	})
end
