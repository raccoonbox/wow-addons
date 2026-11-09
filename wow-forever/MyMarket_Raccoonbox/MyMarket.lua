-- My Market: records where your gold comes from and goes to, so profit can be worked out.
-- Every gold change is logged with what was open at the time (auction house, mail, vendor, loot,
-- quest...). Auction This and Mail Keeper add details (which item, how many) to those entries.
-- Data: WTF\Account\<account>\SavedVariables\MyMarket.lua (written on logout or /reload).
MyMarket = MyMarket or {}
local TL = MyMarket
local db, me
local MAX_LOG = 20000

local function Print(msg) print("|cff33ff99My Market:|r " .. msg) end
local function Money(c)
	local neg = c < 0
	c = math.abs(math.floor(c + 0.5))
	local s = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString and C_CurrencyInfo.GetCoinTextureString(c))
		or string.format("%dg %ds %dc", c / 10000, (c / 100) % 100, c % 100)
	return (neg and "-" or "") .. s
end
TL.Money = Money

---------------------------------------------------------------------------- item names (for reading the data)
function TL.Name(id, link)
	if not (db and id) then return end
	local n = link and link:match("%[(.-)%]") or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
	if n then db.names[id] = n end
end

---------------------------------------------------------------------------- log
function TL.Log(kind, entry)
	if not me then return end
	entry = entry or {}
	entry.k = kind
	entry.t = time()
	if entry.item then TL.Name(entry.item, entry.link) end
	local log = me.log
	log[#log + 1] = entry
	if #log > MAX_LOG then table.remove(log, 1) end
	return entry
end

-- What window is open decides what a gold change probably was.
local open = {}
local function Context()
	-- trust the real windows over the remembered open/close events (a missed "closed" event
	-- once made looted coins count as "mail")
	local frames = { ah = AuctionHouseFrame, vendor = MerchantFrame, mail = MailFrame, trade = TradeFrame }
	for c, f in pairs(frames) do
		if f and f.IsShown then open[c] = f:IsShown() or nil end
	end
	-- vendor before mail: a vendor standing next to the mailbox means both can be open at once
	for _, c in ipairs({ "ah", "vendor", "mail", "trade", "trainer", "taxi", "loot" }) do
		if open[c] then return c end
	end
	if open.questUntil and GetTime() < open.questUntil then return "quest" end
	return "other"
end

-- Details waiting for their gold change: { kind=..., sign=1 or -1, item=..., n=... }.
-- The first waiting entry with the same direction (+/-) gets merged into the next gold change.
local pending = {}
function TL.Pending(p)
	p.expires = GetTime() + 6
	pending[#pending + 1] = p
end
local function TakePending(delta)
	local now = GetTime()
	for i = #pending, 1, -1 do if pending[i].expires < now then table.remove(pending, i) end end
	for i, p in ipairs(pending) do
		if (delta > 0) == (p.sign > 0) then table.remove(pending, i) return p end
	end
end

local lastMoney
local function OnMoney()
	local g = GetMoney()
	if not lastMoney then lastMoney = g return end
	local d = g - lastMoney
	lastMoney = g
	if d == 0 then return end
	local e = { d = d, g = g, c = Context() }
	local p = TakePending(d)
	local kind = "money"
	if p then
		kind = p.kind
		for k, v in pairs(p) do if k ~= "kind" and k ~= "sign" and k ~= "expires" then e[k] = v end end
	end
	TL.Log(kind, e)
end

local function GoldSnapshot(where)
	if not me then return end
	me.gold[#me.gold + 1] = { time(), GetMoney(), where }
	if #me.gold > 5000 then table.remove(me.gold, 1) end
end
TL.GoldSnapshot = GoldSnapshot

---------------------------------------------------------------------------- bags
local function ScanBags()
	if not me then return end
	local bags = {}
	local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	for bag = 0, last do
		for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID then
				bags[info.itemID] = (bags[info.itemID] or 0) + (info.stackCount or 1)
				if not db.names[info.itemID] then TL.Name(info.itemID, info.hyperlink) end
			end
		end
	end
	me.bags, me.bagsTime = bags, time()
end

local bagTimer
local function QueueBagScan()
	if bagTimer then return end
	bagTimer = true
	C_Timer.After(3, function() bagTimer = nil; ScanBags() end)
end

---------------------------------------------------------------------------- vendor buys and sells
hooksecurefunc("BuyMerchantItem", function(index, qty)
	local id = GetMerchantItemID and GetMerchantItemID(index)
	local link = GetMerchantItemLink and GetMerchantItemLink(index)
	TL.Pending({ kind = "vendor_buy", sign = -1, item = id, link = link, n = qty or 1 })
end)

if C_Container and C_Container.UseContainerItem then
	hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
		if not open.vendor then return end
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if info and info.itemID then
			TL.Pending({ kind = "vendor_sell", sign = 1, item = info.itemID, link = info.hyperlink, n = info.stackCount })
		end
	end)
end

---------------------------------------------------------------------------- summary
local KIND_LABEL = {
	ah_buy = "Auction house buys", ah_deposit = "Auction house deposits", mail_money = "Mail gold (sales etc.)",
	vendor_buy = "Vendor buys", vendor_sell = "Vendor sells", money = "Other gold changes",
}

function TL.Summary(days)
	if not me then return end
	local since = time() - (days or 1) * 86400
	local byKind, total = {}, 0
	for i = #me.log, 1, -1 do
		local e = me.log[i]
		if e.t < since then break end
		if e.d then
			local key = (e.k == "money") and ("money:" .. (e.c or "other")) or e.k
			byKind[key] = (byKind[key] or 0) + e.d
			total = total + e.d
		end
	end
	Print(((days or 1) == 1 and "last 24 hours" or ("last " .. days .. " days")) .. ":")
	local keys = {}
	for k in pairs(byKind) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local label = KIND_LABEL[k] or ("Other (" .. k:gsub("^money:", "") .. ")")
		print("   " .. label .. ": " .. Money(byKind[k]))
	end
	print("   |cffffd100Net change: " .. Money(total) .. "|r   (now " .. Money(GetMoney()) .. ")")
end

---------------------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= "MyMarket_Raccoonbox" then return end
		MyMarketDB = MyMarketDB or {}
		db = MyMarketDB
		db.version = 1
		db.names = db.names or {}
		db.chars = db.chars or {}
		local key = UnitName("player") .. "-" .. (GetRealmName() or "?")
		db.chars[key] = db.chars[key] or { log = {}, gold = {} }
		me = db.chars[key]
		me.class = select(2, UnitClass("player"))
		for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "PLAYER_MONEY", "BAG_UPDATE_DELAYED",
			"AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "MERCHANT_SHOW", "MERCHANT_CLOSED",
			"TRADE_SHOW", "TRADE_CLOSED", "TRAINER_SHOW", "TRAINER_CLOSED", "TAXIMAP_OPENED", "TAXIMAP_CLOSED",
			"LOOT_OPENED", "LOOT_CLOSED", "QUEST_TURNED_IN" }) do
			pcall(self.RegisterEvent, self, e)
		end
		return
	end
	if event == "PLAYER_MONEY" then OnMoney() return end
	if event == "BAG_UPDATE_DELAYED" then QueueBagScan() return end
	if event == "PLAYER_ENTERING_WORLD" then
		lastMoney = GetMoney(); GoldSnapshot("login"); QueueBagScan() return
	end
	if event == "PLAYER_LOGOUT" then GoldSnapshot("logout"); ScanBags() return end
	if event == "QUEST_TURNED_IN" then open.questUntil = GetTime() + 2 return end

	local map = {
		AUCTION_HOUSE_SHOW = { "ah", true }, AUCTION_HOUSE_CLOSED = { "ah", false },
		MAIL_SHOW = { "mail", true }, MAIL_CLOSED = { "mail", false },
		MERCHANT_SHOW = { "vendor", true }, MERCHANT_CLOSED = { "vendor", false },
		TRADE_SHOW = { "trade", true }, TRADE_CLOSED = { "trade", false },
		TRAINER_SHOW = { "trainer", true }, TRAINER_CLOSED = { "trainer", false },
		TAXIMAP_OPENED = { "taxi", true }, TAXIMAP_CLOSED = { "taxi", false },
		LOOT_OPENED = { "loot", true }, LOOT_CLOSED = { "loot", false },
	}
	local m = map[event]
	if m then
		-- loot closes before its gold arrives, so keep it "open" a moment longer
		if m[1] == "loot" and not m[2] then C_Timer.After(1, function() open.loot = nil end)
		else open[m[1]] = m[2] or nil end
		if m[1] ~= "loot" then GoldSnapshot(m[1] .. (m[2] and "_open" or "_close")) end
	end
end)

SLASH_MYMARKET1 = "/mymarket"
SLASH_MYMARKET2 = "/market"
SlashCmdList.MYMARKET = function(msg)
	local n = tonumber((msg or ""):match("%d+"))
	TL.Summary(n or 1)
end

---------------------------------------------------------------------------- options page
if RaccoonboxOptions then
	RaccoonboxOptions.AddPanel({
		name = "My Market",
		about = "Keeps a diary of your gold: every gain and loss, with where it happened (auction house, mail, vendor, "
			.. "loot, quests) and which item, plus what's in your bags. Works together with Auction This and Mail Keeper. "
			.. "Use it to see what really makes you money.",
		commands = {
			{ "/mymarket", "your gold in and out for the last 24 hours" },
			{ "/mymarket 7", "the same for the last 7 days" },
		},
		build = function(b)
			b:Buttons({
				{ "Last 24 hours", function() TL.Summary(1) end },
				{ "Last 7 days", function() TL.Summary(7) end },
			})
		end,
	})
end
