-- CraftWell: queue crafts in the profession window, remember them across sessions, and show
-- what materials are still missing - with one-click buying at vendors and quick search at the AH.
local ADDON = "CraftWell_Raccoonbox"
local db                                   -- CraftWellDB (per character)
local MAX_QUEUE_ROWS, MAX_SHOP_ROWS = 10, 14
local W = 320

local function Print(msg) print("|cff66ccffCraft Well:|r " .. msg) end

---------------------------------------------------------------------------- item helpers
local function ItemName(id)
	local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
	if not n and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
	return n or ("item " .. id)
end

local function ItemIcon(id)
	return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or 134400
end

local function CountBags(id) return C_Item.GetItemCount(id) or 0 end
local function CountAll(id) return C_Item.GetItemCount(id, true) or 0 end -- bags + bank

local function Money(c)
	c = math.floor(c + 0.5)
	if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then return C_CurrencyInfo.GetCoinTextureString(c) end
	if GetCoinTextureString then return GetCoinTextureString(c) end
	return string.format("%dg %ds %dc", c / 10000, (c / 100) % 100, c % 100)
end

---------------------------------------------------------------------------- recipe scanning
local function Schematic(recipeID)
	local ok, s = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
	if not ok or not s then return nil end
	local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
	local reagents = {}
	for _, slot in ipairs(s.reagentSlotSchematics or {}) do
		local r = slot.reagents and slot.reagents[1]
		if r and r.itemID and (basic == nil or slot.reagentType == basic) then
			reagents[#reagents + 1] = { r.itemID, slot.quantityRequired or 1 }
		end
	end
	local prof
	local okp, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
	if okp and info then prof = info.professionName end
	return {
		name = s.name, icon = s.icon, out = s.outputItemID,
		qty = math.max(1, s.quantityMin or 1), reagents = reagents, prof = prof,
	}
end

local function Remember(recipeID)
	local r = Schematic(recipeID)
	if not r then return nil end
	db.recipes[recipeID] = r
	if r.out then db.producer[r.out] = recipeID end
	return r
end

-- full = re-read every learned recipe (on opening the window); otherwise only new ones
local scanning, scanFull = false, false
local function ScanProfession(full)
	scanFull = scanFull or full
	if scanning or not C_TradeSkillUI.GetAllRecipeIDs then return end
	scanning = true
	C_Timer.After(0.3, function()
		scanning = false
		local doFull = scanFull
		scanFull = false
		local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
		if not ok or not ids then return end
		for _, id in ipairs(ids) do
			if doFull or not db.recipes[id] then
				local okI, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
				if okI and info and info.learned then Remember(id) end
			end
		end
	end)
end

local lastRecipe
local function SelectedRecipe()
	local pf = ProfessionsFrame
	local form = pf and pf.CraftingPage and pf.CraftingPage.SchematicForm
	if form and form.GetRecipeInfo then
		local ok, info = pcall(form.GetRecipeInfo, form)
		if ok and info and info.recipeID then return info.recipeID end
	end
	local tsf = TradeSkillFrame
	if tsf and tsf.RecipeList and tsf.RecipeList.GetSelectedRecipeID then
		local ok, id = pcall(tsf.RecipeList.GetSelectedRecipeID, tsf.RecipeList)
		if ok and id then return id end
	end
	return lastRecipe
end

local function CraftableNow(recipeID)
	if C_TradeSkillUI.GetCraftableCount then
		local ok, n = pcall(C_TradeSkillUI.GetCraftableCount, recipeID)
		if ok and type(n) == "number" then return n end
	end
	local r = db.recipes[recipeID]
	if not r then return 0 end
	local n = math.huge
	for _, rg in ipairs(r.reagents) do n = math.min(n, math.floor(CountBags(rg[1]) / rg[2])) end
	return n == math.huge and 0 or n
end

---------------------------------------------------------------------------- shopping list
-- Returns missing raw materials {itemID = count} and intermediate crafts {recipeID = casts}.
local function Compute()
	local inv, missing, crafts = {}, {}, {}
	local function have(id)
		if inv[id] == nil then inv[id] = CountAll(id) end
		return inv[id]
	end
	local function need(id, n, depth)
		local h = have(id)
		local take = math.min(h, n)
		inv[id] = h - take
		local short = n - take
		if short <= 0 then return end
		local rid = db.expand and db.producer[id]
		local r = rid and db.recipes[rid]
		if r and depth < 4 then
			local casts = math.ceil(short / r.qty)
			crafts[rid] = (crafts[rid] or 0) + casts
			for _, rg in ipairs(r.reagents) do need(rg[1], rg[2] * casts, depth + 1) end
			inv[id] = (inv[id] or 0) + casts * r.qty - short -- leftover from the extra craft
		else
			missing[id] = (missing[id] or 0) + short
		end
	end
	for _, q in ipairs(db.queue) do
		local r = db.recipes[q.id]
		if r then for _, rg in ipairs(r.reagents) do need(rg[1], rg[2] * q.n, 0) end end
	end
	return missing, crafts
end

---------------------------------------------------------------------------- merchant helpers
local function MerchantItemID(i)
	if GetMerchantItemID then
		local id = GetMerchantItemID(i)
		if id then return id end
	end
	local link = GetMerchantItemLink and GetMerchantItemLink(i)
	return link and tonumber(link:match("item:(%d+)"))
end

local function MerchantInfo(i)
	if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
		local ok, t = pcall(C_MerchantFrame.GetItemInfo, i)
		if ok and t then return t.price or 0, t.stackCount or 1, t.numAvailable or -1, t.hasExtendedCost end
	end
	if GetMerchantItemInfo then
		local _, _, price, stack, avail, _, _, ext = GetMerchantItemInfo(i)
		return price or 0, stack or 1, avail or -1, ext
	end
end

-- itemID -> { index, price, stack } for what the open merchant sells (gold only)
local function MerchantOffers()
	local offers = {}
	if not (MerchantFrame and MerchantFrame:IsShown()) then return offers end
	for i = 1, GetMerchantNumItems() do
		local id = MerchantItemID(i)
		local price, stack, avail, ext = MerchantInfo(i)
		if id and price and not ext and avail ~= 0 then
			offers[id] = { index = i, price = price, stack = stack }
			db.vendor[id] = true
		end
	end
	return offers
end

---------------------------------------------------------------------------- UI
local F = CreateFrame("Frame", "CraftWellFrame", UIParent, "BackdropTemplate")
F:SetSize(W, 200)
F:SetFrameStrata("HIGH")
F:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 14,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
F:SetMovable(true); F:EnableMouse(true); F:RegisterForDrag("LeftButton"); F:SetClampedToScreen(true)
F:SetScript("OnDragStart", function(self) if not self.anchoredTo then self:StartMoving() end end)
F:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
F:Hide()

local title = F:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 12, -10)
title:SetText("Craft Well")
local byline = F:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
byline:SetPoint("LEFT", title, "RIGHT", 6, -1)
byline:SetText("by Raccoonbox")
local close = CreateFrame("Button", nil, F, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 0, 0)
close:SetScript("OnClick", function() F.manual = false; F:Hide() end)

-- "N x Queue selected" controls (profession window only)
local countBox = CreateFrame("EditBox", nil, F, "InputBoxTemplate")
countBox:SetSize(36, 20); countBox:SetAutoFocus(false); countBox:SetNumeric(true); countBox:SetMaxLetters(3)
countBox:SetText("1")
countBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

local function SetCount(n)
	countBox:SetText(tostring(math.min(999, math.max(1, n))))
end
local function GetCount() return tonumber(countBox:GetText()) or 1 end
countBox:EnableMouseWheel(true)
countBox:SetScript("OnMouseWheel", function(_, d) SetCount(GetCount() + d) end)

-- arrow buttons: one triangle = +/-1, two triangles = +/-5
local ARROW = "Interface\\Buttons\\Arrow-Up-Up"
local function ArrowButton(step)
	local double = math.abs(step) > 1
	local b = CreateFrame("Button", nil, F)
	b:SetSize(double and 20 or 16, 20)
	for i = 1, double and 2 or 1 do
		local t = b:CreateTexture(nil, "ARTWORK")
		t:SetTexture(ARROW); t:SetSize(16, 16)
		-- the texture points up: turn it to point right, and make the left arrow an exact
		-- mirror image of the right one so both double arrows overlap the same way
		if step > 0 then t:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
		else t:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1) end
		t:SetPoint("CENTER", double and ((i == 1 and -2 or 2)) or 0, 0) -- close enough to overlap a little
		-- draw the rear triangle on top of the front one, on both sides (the look of the left << button)
		local rear = (step > 0 and i == 1) or (step < 0 and i == 2)
		t:SetDrawLayer("ARTWORK", rear and 1 or 0)
	end
	b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	b:SetScript("OnClick", function()
		countBox:ClearFocus()
		local n = GetCount()
		if double then
			-- snap to the 5-grid: 1 -> 5 -> 10 -> 15, and back 15 -> 10 -> 5 -> 1
			if step > 0 then n = math.floor(n / 5) * 5 + 5 else n = math.ceil(n / 5) * 5 - 5 end
		else
			n = n + step
		end
		SetCount(n)
	end)
	b:SetScript("OnMouseDown", function(self) self:SetAlpha(0.6) end)
	b:SetScript("OnMouseUp", function(self) self:SetAlpha(1) end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText((step > 0 and "+" or "") .. step); GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	return b
end
local down5, down1, up1, up5 = ArrowButton(-5), ArrowButton(-1), ArrowButton(1), ArrowButton(5)
local arrows = { down5, down1, up1, up5 }

local queueBtn = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
queueBtn:SetSize(70, 22); queueBtn:SetText("Queue")
local craftBtn = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
craftBtn:SetSize(90, 22); craftBtn:SetText("Craft next")
local buyBtn = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
buyBtn:SetSize(W - 24, 22)

local queueHeader = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
local shopHeader = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
local hint = F:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetWidth(W - 24); hint:SetJustifyH("LEFT")

local function MakeRow(withRemove)
	local row = CreateFrame("Button", nil, F)
	row:SetSize(W - 24, 18)
	row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(16, 16); row.icon:SetPoint("LEFT")
	row.left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.left:SetPoint("LEFT", row.icon, "RIGHT", 4, 0); row.left:SetJustifyH("LEFT")
	row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.right:SetJustifyH("RIGHT")
	if withRemove then
		row.remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
		row.remove:SetSize(18, 18); row.remove:SetPoint("RIGHT", 2, 0)
		row.right:SetPoint("RIGHT", row.remove, "LEFT", -2, 0)
	else
		row.right:SetPoint("RIGHT")
	end
	row.left:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	row:SetScript("OnEnter", function(self)
		if self.itemID then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetItemByID(self.itemID); GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)
	return row
end

local qRows, sRows = {}, {}
for i = 1, MAX_QUEUE_ROWS do qRows[i] = MakeRow(true) end
for i = 1, MAX_SHOP_ROWS do sRows[i] = MakeRow(false) end

local function ProfessionOpen()
	return (ProfessionsFrame and ProfessionsFrame:IsShown()) or (TradeSkillFrame and TradeSkillFrame:IsShown())
end
local function AuctionOpen() return AuctionHouseFrame and AuctionHouseFrame:IsShown() end

local function SearchAH(name)
	local ah = AuctionHouseFrame
	if not ah then return end
	if ah.SetDisplayMode and AuctionHouseFrameDisplayMode then pcall(ah.SetDisplayMode, ah, AuctionHouseFrameDisplayMode.Buy) end
	local bar = ah.SearchBar
	if bar and bar.SetSearchText and bar.StartSearch then
		bar:SetSearchText(name); bar:StartSearch()
	else
		Print("search the AH for: " .. name)
	end
end

local Refresh -- forward

local function RemoveQueue(i)
	table.remove(db.queue, i)
	Refresh()
end

local function Layout()
	local y = -32
	local function place(widget, h, x)
		widget:ClearAllPoints(); widget:SetPoint("TOPLEFT", x or 12, y); y = y - h
	end

	local prof = ProfessionOpen()
	countBox:SetShown(prof); queueBtn:SetShown(prof); craftBtn:SetShown(prof and #db.queue > 0)
	for _, a in ipairs(arrows) do a:SetShown(prof) end
	if prof then
		down5:ClearAllPoints(); down5:SetPoint("TOPLEFT", 10, y)
		down1:ClearAllPoints(); down1:SetPoint("LEFT", down5, "RIGHT", 0, 0)
		countBox:ClearAllPoints(); countBox:SetPoint("LEFT", down1, "RIGHT", 8, 0)
		up1:ClearAllPoints(); up1:SetPoint("LEFT", countBox, "RIGHT", 2, 0)
		up5:ClearAllPoints(); up5:SetPoint("LEFT", up1, "RIGHT", 0, 0)
		queueBtn:ClearAllPoints(); queueBtn:SetPoint("LEFT", up5, "RIGHT", 6, 0)
		craftBtn:ClearAllPoints(); craftBtn:SetPoint("LEFT", queueBtn, "RIGHT", 4, 0)
		y = y - 28
	end

	-- queue
	queueHeader:SetText(#db.queue > 0 and "Queue" or "Queue is empty. Pick a recipe, set the amount, press Queue.")
	place(queueHeader, 16)
	for i, row in ipairs(qRows) do
		local q = db.queue[i]
		if q then
			local r = db.recipes[q.id] or {}
			row.itemID = r.out
			row.icon:SetTexture(r.icon or ItemIcon(r.out or 0))
			row.left:SetText(q.n .. " x " .. (r.name or ("recipe " .. q.id)))
			local can = prof and CraftableNow(q.id) or nil
			row.right:SetText(can and ((can >= q.n and "|cff33ff33" or "|cffffcc00") .. "can make " .. can .. "|r") or (r.prof or ""))
			row.remove:SetScript("OnClick", function() RemoveQueue(i) end)
			row:SetScript("OnClick", nil)
			place(row, 18); row:Show()
		else
			row:Hide()
		end
	end
	if #db.queue > MAX_QUEUE_ROWS then
		hint:SetText("+" .. (#db.queue - MAX_QUEUE_ROWS) .. " more in queue"); place(hint, 14); hint:Show()
	else
		hint:Hide()
	end
	y = y - 6

	-- shopping list
	local missing, crafts = Compute()
	local offers = MerchantOffers()
	local list = {}
	for rid, casts in pairs(crafts) do
		local r = db.recipes[rid]
		list[#list + 1] = { craft = true, id = r.out, n = casts * r.qty, name = r.name, icon = r.icon }
	end
	for id, n in pairs(missing) do list[#list + 1] = { id = id, n = n, name = ItemName(id), icon = ItemIcon(id) } end
	table.sort(list, function(a, b)
		if (a.craft or false) ~= (b.craft or false) then return a.craft end
		return a.name < b.name
	end)

	local ah = AuctionOpen()
	shopHeader:SetText(#list > 0 and ("Shopping list" .. (ah and "  (click to search)" or ""))
		or (#db.queue > 0 and "|cff33ff33You have everything for the queue.|r" or ""))
	shopHeader:SetShown(#db.queue > 0)
	if #db.queue > 0 then place(shopHeader, 16) end

	local buyCost, buyCount = 0, 0
	for i, row in ipairs(sRows) do
		local e = list[i]
		if e then
			row.itemID = e.id
			row.icon:SetTexture(e.icon)
			local offer = not e.craft and offers[e.id]
			if e.craft then
				row.left:SetText("|cffaaaaffcraft first:|r " .. e.name)
				row.right:SetText("x" .. e.n)
			else
				row.left:SetText(e.name)
				local tag = ""
				if offer then
					local cost = offer.price * math.ceil(e.n / offer.stack)
					buyCost = buyCost + cost; buyCount = buyCount + 1
					tag = "  " .. Money(cost)
				elseif db.vendor[e.id] then
					tag = "  |cff999999vendor|r"
				end
				row.right:SetText("need " .. e.n .. tag)
			end
			row:SetScript("OnClick", (ah and not e.craft) and function() SearchAH(e.name) end or nil)
			place(row, 18); row:Show()
		else
			row:Hide()
		end
	end

	buyBtn:SetShown(buyCount > 0)
	if buyCount > 0 then
		y = y - 4
		buyBtn:SetText("Buy " .. buyCount .. " missing here  (" .. Money(buyCost) .. ")")
		place(buyBtn, 26)
	end
	F:SetHeight(-y + 10)
	return #list
end

local function AnchorTo(target)
	F:ClearAllPoints()
	if target then
		if target == ProfessionsFrame or target == TradeSkillFrame then
			-- under the profession window, right edges lined up (keeps the profession tabs free)
			F:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", 0, -4)
		else
			F:SetPoint("BOTTOMLEFT", target, "BOTTOMRIGHT", 4, 0)
		end
		F.anchoredTo = target
	else
		F:SetPoint("CENTER")
		F.anchoredTo = nil
	end
end

Refresh = function()
	if not db then return end
	local target
	if ProfessionOpen() then target = ProfessionsFrame or TradeSkillFrame
	elseif MerchantFrame and MerchantFrame:IsShown() then target = MerchantFrame
	elseif AuctionOpen() then target = AuctionHouseFrame end

	if not target and not F.manual then F:Hide() return end
	local shopping = Layout()
	-- at vendors / the AH only pop up when there is something to buy
	if not F.manual and target ~= ProfessionsFrame and target ~= TradeSkillFrame and shopping == 0 then
		F:Hide() return
	end
	if target ~= F.anchoredTo then AnchorTo(target) end
	F:Show()
end

local pending = false
local function QueueRefresh()
	if pending then return end
	pending = true
	C_Timer.After(0.15, function() pending = false; Refresh() end)
end

---------------------------------------------------------------------------- buttons
queueBtn:SetScript("OnClick", function()
	local id = SelectedRecipe()
	if not id then Print("select a recipe in the profession window first.") return end
	local r = db.recipes[id] or Remember(id)
	if not r then Print("couldn't read that recipe.") return end
	local n = math.max(1, tonumber(countBox:GetText()) or 1)
	for _, q in ipairs(db.queue) do
		if q.id == id then q.n = q.n + n; Refresh(); return end
	end
	db.queue[#db.queue + 1] = { id = id, n = n }
	Refresh()
end)

craftBtn:SetScript("OnClick", function()
	for _, q in ipairs(db.queue) do
		local can = CraftableNow(q.id)
		if can > 0 then
			local n = math.min(can, q.n)
			local ok, err = pcall(C_TradeSkillUI.CraftRecipe, q.id, n)
			if not ok then Print("couldn't start crafting: " .. tostring(err)) end
			return
		end
	end
	Print("nothing in the queue can be made with what you carry (or it belongs to another profession).")
end)

buyBtn:SetScript("OnClick", function()
	local missing = Compute()
	local offers = MerchantOffers()
	local spent = 0
	for id, n in pairs(missing) do
		local o = offers[id]
		if o then
			if o.stack > 1 then
				for _ = 1, math.ceil(n / o.stack) do BuyMerchantItem(o.index) end
			else
				local maxStack = (GetMerchantItemMaxStack and GetMerchantItemMaxStack(o.index)) or 20
				local left = n
				while left > 0 do
					local q = math.min(left, maxStack)
					BuyMerchantItem(o.index, q)
					left = left - q
				end
			end
			spent = spent + o.price * math.ceil(n / o.stack)
		end
	end
	Print("bought the missing vendor materials for " .. Money(spent) .. ".")
	C_Timer.After(0.6, Refresh)
end)

---------------------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... ~= ADDON then return end
		CraftWellDB = CraftWellDB or {}
		db = CraftWellDB
		db.queue = db.queue or {}
		db.recipes = db.recipes or {}
		db.producer = db.producer or {}
		db.vendor = db.vendor or {}
		if db.expand == nil then db.expand = true end
		for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE",
			"MERCHANT_SHOW", "MERCHANT_CLOSED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
			"BAG_UPDATE_DELAYED", "UNIT_SPELLCAST_SUCCEEDED", "GET_ITEM_INFO_RECEIVED" }) do
			pcall(self.RegisterEvent, self, e)
		end
		if EventRegistry and EventRegistry.RegisterCallback then
			pcall(EventRegistry.RegisterCallback, EventRegistry, "ProfessionsRecipeListMixin.Event.OnRecipeSelected",
				function(_, info) if info and info.recipeID then lastRecipe = info.recipeID; QueueRefresh() end end, F)
		end
		return
	end

	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, _, spellID = ...
		if unit ~= "player" then return end
		for i, q in ipairs(db.queue) do
			if q.id == spellID then
				q.n = q.n - 1
				if q.n <= 0 then table.remove(db.queue, i) end
				QueueRefresh()
				return
			end
		end
		return
	end

	if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then ScanProfession(event == "TRADE_SKILL_SHOW") end
	if event == "TRADE_SKILL_CLOSE" or event == "MERCHANT_CLOSED" or event == "AUCTION_HOUSE_CLOSED" then
		C_Timer.After(0.05, Refresh) -- let the window finish hiding first
		return
	end
	QueueRefresh()
end)

---------------------------------------------------------------------------- slash
SLASH_CRAFTWELL1 = "/craftwell"
SLASH_CRAFTWELL2 = "/cwell"
SlashCmdList.CRAFTWELL = function(msg)
	msg = (msg or ""):lower()
	if msg == "clear" then
		wipe(db.queue); Print("queue cleared."); Refresh()
	elseif msg == "expand" then
		db.expand = not db.expand
		Print("split self-crafted materials into ingredients: " .. (db.expand and "ON" or "OFF")); Refresh()
	else
		F.manual = not F:IsShown()
		if F.manual then AnchorTo(nil) end
		Refresh()
		if not F.manual then F:Hide() end
	end
end

---------------------------------------------------------------------------- options page
if RaccoonboxOptions then
	RaccoonboxOptions.AddPanel({
		name = "Craft Well",
		about = "Queue crafts in the profession window and Craft Well remembers them. It shows the materials you still miss, "
			.. "lets you buy them at a vendor with one click and search them at the auction house with one click.",
		commands = {
			{ "/craftwell", "open or close the Craft Well panel anywhere (also /cwell)" },
			{ "/craftwell clear", "empty the queue" },
			{ "/craftwell expand", "turn splitting self-crafted materials on or off" },
		},
		build = function(b)
			b:Check("Split materials you can craft yourself into their ingredients",
				"Example: a potion that needs another potion you make yourself shows the herbs and vials for that one too.",
				function() return db and db.expand end,
				function(v) if db then db.expand = v; Refresh() end end)
			b:Buttons({
				{ "Open Craft Well", function() SlashCmdList.CRAFTWELL("") end },
				{ "Clear queue", function() SlashCmdList.CRAFTWELL("clear") end },
			})
		end,
	})
end
