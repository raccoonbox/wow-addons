-- Auction This: auction house prices and flips.
--  * remembers the lowest price of everything you see at the auction house (every search you do)
--  * "Scan whole AH" takes one snapshot of every auction (the server may ignore scans less than 15 min apart)
--  * item tooltips show the auction price, the vendor price and whether it's a flip
--  * the flip finder lists items that sell to a vendor for more than they cost on the AH, and items
--    that are much cheaper than usual right now; click one to search it
--  * your buys, bids, posts and cancels go into My Market
-- Data: WTF\Account\<account>\SavedVariables\AuctionThis.lua
local db, R, P -- AuctionThisDB, this realm+faction, its prices
local MM = function() return MyMarket end

local function Print(msg) print("|cff33ff99Auction This:|r " .. msg) end
local function Money(c)
	if MyMarket and MyMarket.Money then return MyMarket.Money(c) end
	c = math.floor(c + 0.5)
	return (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString and C_CurrencyInfo.GetCoinTextureString(c))
		or string.format("%dg %ds %dc", c / 10000, (c / 100) % 100, c % 100)
end
local function Ago(t)
	local s = time() - t
	if s < 3600 then return math.floor(s / 60) .. " min ago" end
	if s < 86400 then return math.floor(s / 3600) .. " h ago" end
	return math.floor(s / 86400) .. " d ago"
end
local function SellPrice(id)
	local sell = select(11, C_Item.GetItemInfo(id))
	return sell
end

---------------------------------------------------------------------------- price memory
-- P[itemID] = { n = name, m = lowest unit buyout now, q = quantity up, t = when,
--               h = { {time, lowest, quantity}, ... } one point per hour, last 60 }
-- source: "scan" (whole-AH scan) or "search" (real buyouts) are trusted; "browse" (the overview
-- list) can include bid-only auctions, so it never overwrites a trusted price from the last 30 min
-- and is never used for flips.
local function Record(id, unit, qty, name, source)
	if not (P and id and unit and unit > 0) then return end
	local p = P[id]
	if not p then p = { h = {} }; P[id] = p end
	if name and name ~= "" then p.n = name end
	if not p.n and MyMarket and MyMarket.Name then MyMarket.Name(id) end
	source = source or "browse"
	if source == "browse" and p.s and p.s ~= "browse" and time() - (p.t or 0) < 1800 then return end
	p.m, p.q, p.t, p.s = math.floor(unit), qty, time(), source
	local sell = select(11, C_Item.GetItemInfo(id)) -- vendor price, saved so flips can be checked outside the game
	if sell then p.v = sell end
	local last = p.h[#p.h]
	if last and time() - last[1] < 3600 then
		last[2], last[3] = p.m, qty
	else
		p.h[#p.h + 1] = { p.t, p.m, qty }
		if #p.h > 60 then table.remove(p.h, 1) end
	end
end

local function Median(p)
	if not (p and p.h and #p.h >= 3) then return nil end
	local v = {}
	for _, h in ipairs(p.h) do v[#v + 1] = h[2] end
	table.sort(v)
	return v[math.floor((#v + 1) / 2)]
end

---------------------------------------------------------------------------- what you see while searching
local lastItemKey
local function OnBrowse()
	for _, r in ipairs(C_AuctionHouse.GetBrowseResults() or {}) do
		if r.itemKey and r.minPrice then Record(r.itemKey.itemID, r.minPrice, r.totalQuantity) end
	end
end

local function OnCommoditySearch(itemID)
	local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, 1)
	if r and r.unitPrice then
		Record(itemID, r.unitPrice, C_AuctionHouse.GetCommoditySearchResultsQuantity and C_AuctionHouse.GetCommoditySearchResultsQuantity(itemID), nil, "search")
	end
end

local function OnItemSearch(itemKey)
	if type(itemKey) ~= "table" then return end
	lastItemKey = itemKey
	local best, qty
	for i = 1, (C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0) do
		local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
		if r and r.buyoutAmount and r.buyoutAmount > 0 then
			local unit = r.buyoutAmount / math.max(1, r.quantity or 1)
			if not best or unit < best then best = unit end
			qty = (qty or 0) + (r.quantity or 1)
		end
	end
	if best then Record(itemKey.itemID, best, qty, nil, "search") end
end

---------------------------------------------------------------------------- whole-AH scan
local SCAN_COOLDOWN = 15 * 60
local scanPhase, scanFrame = nil, CreateFrame("Frame") -- scanPhase: nil, "wait" (server sending), "read" (reading it)
local scanStart -- GetTime() when the scan was requested
local Refresh, Flips, ShowProgress -- forward (panel, flip finder, progress bar)

local function Num(n)
	return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
end

local function ScanReadyIn()
	local last = R and R.scanRequested or 0
	return math.max(0, SCAN_COOLDOWN - (time() - last))
end

local SCAN_SLOW, SCAN_TIMEOUT = 30, 120 -- seconds without an answer: warn, then give up
local StopScan -- forward
local scanLate -- gave up waiting, but still accept the server's answer if it comes

-- step 1: waiting for the server. Only the clock is used here (the auction data is not touched
-- until the server says it's ready), compared with how long the last scan took.
local function WaitTick(self, elapsed)
	self.acc = (self.acc or 0) + elapsed
	if self.acc < 0.5 then return end
	self.acc = 0
	local secs = math.floor(GetTime() - scanStart)
	if secs >= SCAN_TIMEOUT then
		StopScan()
		scanLate = true -- if the answer still comes, use it
		Print(("no answer from the server after %ds - it probably didn't go through. If the data still arrives it will be "
			.. "used; otherwise press Scan again."):format(secs))
		return
	end
	if secs >= SCAN_SLOW and not self.warned then
		self.warned = true
		Print("the server hasn't answered yet. Keep the auction house open; giving up after " .. SCAN_TIMEOUT .. "s.")
	end
	local lastWait = R.lastScanWait
	local frac = lastWait and lastWait > 0 and secs / lastWait or secs / SCAN_TIMEOUT
	local line2 = secs .. "s" .. (lastWait and (" (last scan took ~" .. lastWait .. "s)") or "")
	if ShowProgress then ShowProgress("1/2 Waiting for the server...\n" .. line2, math.min(frac, 0.99)) end
end

StopScan = function()
	scanPhase = nil
	scanFrame:SetScript("OnUpdate", nil)
	if ShowProgress then ShowProgress(nil) end
end

local function StartScan()
	if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then Print("open the auction house first.") return end
	if ScanReadyIn() > 0 then Print("note: less than 15 min since the last scan - the server may ignore this one.") end
	scanPhase, scanStart, scanLate = "wait", GetTime(), nil
	R.scanRequested = time()
	C_AuctionHouse.ReplicateItems()
	Print("scanning the whole auction house..." .. (R.lastScanAuctions and (" (last time: " .. Num(R.lastScanAuctions)
		.. " auctions" .. (R.lastScanWait and (", ~" .. R.lastScanWait .. "s") or "") .. ")") or ""))
	scanFrame.acc, scanFrame.warned = 1, nil
	scanFrame:SetScript("OnUpdate", WaitTick)
	if Refresh then Refresh() end
end

local function ProcessScan()
	if not (scanPhase == "wait" or (scanLate and not scanPhase)) then return end
	scanPhase, scanLate = "read", nil
	local n = C_AuctionHouse.GetNumReplicateItems() or 0
	local waited = math.floor(GetTime() - scanStart + 0.5)
	R.lastScanWait = waited
	Print(("server sent %s auctions after %ds, reading them..."):format(Num(n), waited))
	local agg, i = {}, 0
	scanFrame:SetScript("OnUpdate", function(self)
		local stop = math.min(i + 1500, n)
		while i < stop do
			local name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
			if itemID and buyout and buyout > 0 and count and count > 0 then
				local unit = buyout / count
				local a = agg[itemID]
				if not a then a = { m = unit, q = 0, a = 0 }; agg[itemID] = a end
				if unit < a.m then a.m = unit end
				a.q, a.a = a.q + count, a.a + 1
				if name and name ~= "" then a.n = name end
			end
			i = i + 1
		end
		if ShowProgress then
			ShowProgress(("2/2 Reading: %s / %s\n%d%%"):format(Num(i), Num(n), n > 0 and math.floor(i / n * 100) or 100),
				n > 0 and i / n or 1)
		end
		if i >= n then
			StopScan()
			local items = 0
			for id, a in pairs(agg) do Record(id, a.m, a.q, a.n, "scan"); items = items + 1 end
			R.lastScan, R.lastScanAuctions = time(), n
			Print(("scan done: %d auctions, %d different items. Checking vendor prices..."):format(n, items))
			if Refresh then Refresh() end
			-- vendor prices load a moment after they're asked for; report the flips once they're in
			C_Timer.After(4, function()
				local flips = Flips("vendor")
				Print(#flips > 0 and (#flips .. " vendor flip" .. (#flips == 1 and "" or "s") .. " found - see the Auction This panel.")
					or "no vendor flips right now. Prices are saved; scan again later to build the price history.")
				if Refresh then Refresh() end
			end)
		end
	end)
end

---------------------------------------------------------------------------- your buys, bids, posts, cancels -> My Market
local function Pending(t) if MM() and MM().Pending then MM().Pending(t) end end
local function Log(k, t) if MM() and MM().Log then MM().Log(k, t) end end

if C_AuctionHouse then
	hooksecurefunc(C_AuctionHouse, "ConfirmCommoditiesPurchase", function(itemID, qty)
		Pending({ kind = "ah_buy", sign = -1, item = itemID, n = qty })
	end)
	hooksecurefunc(C_AuctionHouse, "PlaceBid", function(auctionID, bid)
		local entry = { kind = "ah_bid", sign = -1, auction = auctionID, bid = bid }
		if lastItemKey then
			for i = 1, (C_AuctionHouse.GetNumItemSearchResults(lastItemKey) or 0) do
				local r = C_AuctionHouse.GetItemSearchResultInfo(lastItemKey, i)
				if r and r.auctionID == auctionID then
					entry.item, entry.n, entry.link = r.itemKey.itemID, r.quantity, r.itemLink
					if r.buyoutAmount and bid >= r.buyoutAmount then entry.kind = "ah_buy" end
					break
				end
			end
		end
		Pending(entry)
	end)
	local function Posted(kind)
		return function(loc, duration, qty, a, b)
			local okI, id = pcall(C_Item.GetItemID, loc)
			local okL, link = pcall(C_Item.GetItemLink, loc)
			local e = { item = okI and id or nil, link = okL and link or nil, n = qty, dur = duration }
			if kind == "commodity" then e.unit = a else e.bid, e.buyout = a, b end
			Log("ah_post", e)
			Pending({ kind = "ah_deposit", sign = -1, item = e.item, n = qty })
		end
	end
	hooksecurefunc(C_AuctionHouse, "PostItem", Posted("item"))
	hooksecurefunc(C_AuctionHouse, "PostCommodity", Posted("commodity"))
	hooksecurefunc(C_AuctionHouse, "CancelAuction", function(auctionID) Log("ah_cancel", { auction = auctionID }) end)
end

-- your own auctions, for reading later
local function OnOwned()
	if not (db and C_AuctionHouse.GetOwnedAuctions) then return end
	local list = {}
	for _, a in ipairs(C_AuctionHouse.GetOwnedAuctions() or {}) do
		list[#list + 1] = { item = a.itemKey and a.itemKey.itemID, n = a.quantity, buyout = a.buyoutAmount,
			bid = a.bidAmount, status = a.status, left = a.timeLeftSeconds }
	end
	db.owned = db.owned or {}
	db.owned[UnitName("player")] = { t = time(), list = list }
end

---------------------------------------------------------------------------- flip finder
Flips = function(mode)
	local out = {}
	for id, p in pairs(P or {}) do
		-- only trusted prices (scan or real search), and not older than 3 hours
		if p.m and p.s and p.s ~= "browse" and time() - (p.t or 0) < 3 * 3600 then
			if mode == "vendor" then
				local sell = SellPrice(id)
				if sell == nil then C_Item.RequestLoadItemDataByID(id)
				-- worth the walk: at least 10% and 5 copper profit per item
				elseif sell - p.m >= math.max(5, p.m * 0.1) then
					out[#out + 1] = { id = id, p = p, gain = sell - p.m, score = (sell - p.m) * math.min(p.q or 1, 20),
						right = "+" .. Money(sell - p.m) .. " each" }
				end
			else
				local med = Median(p)
				if med and p.m < med * 0.65 then
					out[#out + 1] = { id = id, p = p, gain = med - p.m, score = (med - p.m),
						right = Money(p.m) .. " (usually " .. Money(med) .. ")" }
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.score > b.score end)
	return out
end

local function SearchAH(name)
	local ah = AuctionHouseFrame
	if not (ah and name) then return end
	if ah.SetDisplayMode and AuctionHouseFrameDisplayMode then pcall(ah.SetDisplayMode, ah, AuctionHouseFrameDisplayMode.Buy) end
	local bar = ah.SearchBar
	if bar and bar.SetSearchText and bar.StartSearch then bar:SetSearchText(name); bar:StartSearch() end
end

local ROWS = 14
local panel = CreateFrame("Frame", "AuctionThisPanel", UIParent, "BackdropTemplate")
panel:SetSize(330, 120); panel:Hide()
panel:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 14,
	insets = { left = 3, right = 3, top = 3, bottom = 3 } })
local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 12, -10); title:SetText("Auction This")
local by = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
by:SetPoint("LEFT", title, "RIGHT", 6, -1); by:SetText("by Raccoonbox")
local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT"); close:SetScript("OnClick", function() panel.userHidden = true; panel:Hide() end)

local scanBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
scanBtn:SetSize(120, 22); scanBtn:SetPoint("TOPLEFT", 10, -32); scanBtn:SetText("Scan whole AH")
scanBtn:SetScript("OnClick", StartScan)
local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("LEFT", scanBtn, "RIGHT", 8, 0); status:SetWidth(180); status:SetJustifyH("LEFT")

local mode = "vendor"
local tabV = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
tabV:SetSize(150, 22); tabV:SetPoint("TOPLEFT", 10, -58); tabV:SetText("Sell to vendor")
local tabC = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
tabC:SetSize(150, 22); tabC:SetPoint("LEFT", tabV, "RIGHT", 6, 0); tabC:SetText("Cheaper than usual")
local bar = CreateFrame("StatusBar", nil, panel)
bar:SetSize(306, 8); bar:SetPoint("TOPLEFT", 12, -85)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(0.2, 0.8, 0.4)
bar:SetMinMaxValues(0, 1); bar:SetValue(0)
local barBg = bar:CreateTexture(nil, "BACKGROUND"); barBg:SetAllPoints(); barBg:SetColorTexture(0, 0, 0, 0.6)
bar:Hide()
local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("TOPLEFT", 12, -98); hint:SetWidth(306); hint:SetJustifyH("LEFT")

-- scan progress: text next to the scan button and the bar under the tabs. nil text = scan over.
local progressText
ShowProgress = function(text, frac)
	progressText = text
	if not text then bar:Hide(); if Refresh then Refresh() end return end
	if not panel:IsShown() then return end
	status:SetText(text)
	scanBtn:SetEnabled(false)
	if frac then bar:SetValue(frac); bar:Show() else bar:Hide() end
end

local rows = {}
for i = 1, ROWS do
	local r = CreateFrame("Button", nil, panel)
	r:SetSize(306, 18); r:SetPoint("TOPLEFT", 12, -128 - (i - 1) * 18)
	r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(16, 16); r.icon:SetPoint("LEFT")
	r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.right:SetPoint("RIGHT")
	r.left = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.left:SetPoint("LEFT", r.icon, "RIGHT", 4, 0); r.left:SetPoint("RIGHT", r.right, "LEFT", -4, 0); r.left:SetJustifyH("LEFT")
	r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	r:SetScript("OnClick", function(self) SearchAH(self.name) end)
	r:SetScript("OnEnter", function(self)
		if self.id then GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetItemByID(self.id); GameTooltip:Show() end
	end)
	r:SetScript("OnLeave", GameTooltip_Hide)
	rows[i] = r
end

Refresh = function(statusText)
	if not panel:IsShown() then return end
	statusText = statusText or progressText
	if statusText then status:SetText(statusText)
	elseif R and R.lastScan then status:SetText("Last full scan " .. Ago(R.lastScan) .. (R.lastScanAuctions and ("\n" .. Num(R.lastScanAuctions) .. " auctions") or ""))
	else status:SetText("No full scan yet") end
	scanBtn:SetEnabled(not scanPhase)
	tabV:SetEnabled(mode ~= "vendor"); tabC:SetEnabled(mode ~= "cheap")
	hint:SetText(mode == "vendor" and "Buy these on the AH and sell them to any vendor. Click to search."
		or "Much cheaper than their usual price right now. Click to search.")
	local list = Flips(mode)
	for i, r in ipairs(rows) do
		local e = list[i]
		if e then
			r.id, r.name = e.id, e.p.n or C_Item.GetItemNameByID(e.id)
			r.icon:SetTexture(C_Item.GetItemIconByID(e.id))
			r.left:SetText(r.name or ("item " .. e.id))
			r.right:SetText(e.right)
			r:Show()
		else
			r:Hide()
		end
	end
	if #list == 0 then rows[1]:Show(); rows[1].id = nil; rows[1].name = nil; rows[1].icon:SetTexture(nil)
		rows[1].left:SetText("|cff999999Nothing yet. Search the AH or scan it.|r"); rows[1].right:SetText("") end
	panel:SetHeight(136 + math.max(1, math.min(#list, ROWS)) * 18)
end
tabV:SetScript("OnClick", function() mode = "vendor"; Refresh() end)
tabC:SetScript("OnClick", function() mode = "cheap"; Refresh() end)

local function ShowPanel()
	if not AuctionHouseFrame then return end
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 4, 0)
	panel:SetFrameStrata("HIGH")
	if not (db and db.hidePanel) then panel:Show(); Refresh() end
end

---------------------------------------------------------------------------- tooltips
local function TooltipLines(tt, id)
	if not (id and P) then return end
	local p, sell = P[id], SellPrice(id)
	if not p and not (sell and sell > 0) then return end
	tt:AddLine(" ")
	if p and p.m then
		tt:AddDoubleLine("|cff33ff99Auction This|r  AH lowest", Money(p.m) .. " |cff999999(" .. Ago(p.t) .. ")|r", 1, 1, 1, 1, 1, 1)
		local med = Median(p)
		if med then tt:AddDoubleLine("   usual price", Money(med), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8) end
	end
	if sell and sell > 0 then tt:AddDoubleLine("   vendor pays", Money(sell), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8) end
	if p and p.m and p.s ~= "browse" and sell and sell > p.m then
		tt:AddLine("   |cff33ff33Flip: buy on AH, sell to vendor (+" .. Money(sell - p.m) .. " each)|r")
	elseif p and p.s == "browse" then
		tt:AddLine("   |cff999999(from the browse list - click the item at the AH for exact prices)|r")
	end
	tt:Show()
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
		if (tt == GameTooltip or tt == ItemRefTooltip) and data and data.id then TooltipLines(tt, data.id) end
	end)
end

---------------------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, a1)
	if event == "ADDON_LOADED" then
		if a1 ~= "AuctionThis_Raccoonbox" then return end
		AuctionThisDB = AuctionThisDB or {}
		db = AuctionThisDB
		db.realms = db.realms or {}
		local key = (GetRealmName() or "?") .. "-" .. (UnitFactionGroup("player") or "?")
		db.realms[key] = db.realms[key] or { prices = {} }
		R = db.realms[key]; P = R.prices
		for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
			"COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "REPLICATE_ITEM_LIST_UPDATE",
			"OWNED_AUCTIONS_UPDATED", "GET_ITEM_INFO_RECEIVED" }) do pcall(self.RegisterEvent, self, e) end
		return
	end
	if event == "AUCTION_HOUSE_SHOW" then
		panel.userHidden = nil
		C_Timer.After(0.1, ShowPanel)
		if C_AuctionHouse.QueryOwnedAuctions then pcall(C_AuctionHouse.QueryOwnedAuctions, {}) end
	elseif event == "AUCTION_HOUSE_CLOSED" then
		panel:Hide()
		if scanPhase == "wait" then StopScan(); Print("scan stopped: the auction house was closed before the server sent the data.") end
	elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then OnBrowse(); Refresh()
	elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then OnCommoditySearch(a1); Refresh()
	elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then OnItemSearch(a1); Refresh()
	elseif event == "REPLICATE_ITEM_LIST_UPDATE" then ProcessScan()
	elseif event == "OWNED_AUCTIONS_UPDATED" then OnOwned()
	elseif event == "GET_ITEM_INFO_RECEIVED" and panel:IsShown() and not self.infoPending then
		-- vendor prices arriving: refresh the flip list at most twice a second
		self.infoPending = true
		C_Timer.After(0.5, function() self.infoPending = nil; Refresh() end)
	end
end)

SLASH_AUCTIONTHIS1 = "/auctionthis"
SLASH_AUCTIONTHIS2 = "/athis"
SlashCmdList.AUCTIONTHIS = function(msg)
	msg = (msg or ""):lower()
	if msg == "scan" then StartScan()
	elseif msg == "panel" then
		db.hidePanel = not db.hidePanel
		Print("panel at the auction house: " .. (db.hidePanel and "off" or "on"))
		if db.hidePanel then panel:Hide() elseif AuctionHouseFrame and AuctionHouseFrame:IsShown() then ShowPanel() end
	else
		local n = 0
		for _ in pairs(P or {}) do n = n + 1 end
		Print(n .. " items with prices. " .. (R.lastScan and ("Last full scan " .. Ago(R.lastScan) .. ".") or "No full scan yet."))
		Print("/auctionthis scan - scan the whole AH (at the AH)   /auctionthis panel - flip panel on/off")
	end
end

---------------------------------------------------------------------------- options page
if RaccoonboxOptions then
	RaccoonboxOptions.AddPanel({
		name = "Auction This",
		about = "Auction house prices and flips. It remembers the lowest price of everything you see at the auction house, "
			.. "can scan the whole AH, shows AH price, usual price and vendor price in item tooltips, "
			.. "and its panel next to the AH lists flips: items to resell to a vendor and items much cheaper than usual. "
			.. "Your buys and posts are recorded in My Market.",
		commands = {
			{ "/auctionthis", "how many prices are known, when the last scan was (also /athis)" },
			{ "/auctionthis scan", "scan the whole auction house (while it's open)" },
			{ "/auctionthis panel", "turn the flip panel at the auction house on or off" },
		},
		build = function(b)
			b:Check("Show the flip panel next to the auction house", nil,
				function() return db and not db.hidePanel end,
				function(v) db.hidePanel = not v end)
		end,
	})
end
