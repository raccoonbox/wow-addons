module 'aux.core.flips'

-- Auction This: flip finder.
--  * remembers the current lowest buyout of every item seen in any search (and in the full scan)
--  * finds items that a vendor pays more for than they cost on the AH (vendor flips)
--  * finds items listed much cheaper than their usual price (aux's historical value)
--  * fast full scan: reads every AH page with no tooltip parsing and no result table, so it only
--    waits for the server
--  * price gaps: keeps the cheapest 12 price levels of every item and finds a few cheap auctions
--    sitting well below the rest of the market (buy them, relist just under the next price)
-- Data: aux.faction[...].flips[item_key] = 'unit_price#quantity#time#price:qty,price:qty,...'

local aux = require 'aux'
local info = require 'aux.util.info'
local history = require 'aux.core.history'
local scan = require 'aux.core.scan'

M.VENDOR, M.CHEAP, M.GAPS = 1, 2, 3
M.GAP_RATIO = 1.25      -- the next price must be at least 25% above everything you'd buy
M.GAP_MIN_PROFIT = 1000 -- 10 silver, after the AH cut
local AH_CUT = .05            -- the auction house keeps 5% of every sale
local GAP_MAX_OVER_VALUE = 1.1 -- never relist more than 10% above the usual (historical) price
local GAP_MIN_DAYS = 2         -- fewer days of price history than this: the listings must back the relist price
local GAP_MAX_BUY = 40  -- don't suggest buying more than this many items of one kind
local LEVELS = 12
M.MAX_AGE = 3 * 60 * 60 -- prices older than this are not used for flips
M.CHEAP_RATIO = .65 -- "cheaper than usual" = below 65% of the historical value
local KEEP_DAYS = 7
local PAGE_SIZE = 50

local generation, seen = 0, {}
local levels = {} -- item_key -> { gen = scan generation, list = { {p = unit price, q = quantity}, ... } } cheapest first

function aux.handle.LOAD2()
	data = aux.faction_data.flips
	meta = aux.faction_data.flip_scan
	local now = time()
	for item_key in data do
		local _, _, t = get(item_key)
		if not t or now - t > KEEP_DAYS * 24 * 60 * 60 then
			data[item_key] = nil
		end
	end
end

function M.get(item_key)
	local s = data and data[item_key]
	if s then
		local _, _, m, q, t = strfind(s, '^(%d+)#(%d+)#(%d+)')
		if m then return tonumber(m), tonumber(q), tonumber(t) end
	end
end

local function serialize(list)
	local parts = {}
	for _, l in ipairs(list) do tinsert(parts, l.p .. ':' .. l.q) end
	return table.concat(parts, ',')
end

local function stored_levels(s)
	return s and aux.select(3, strfind(s, '^%d+#%d+#%d+#(.*)$'))
end

local function put(item_key, unit_price, quantity)
	local L = levels[item_key]
	if L and L.gen == generation then
		data[item_key] = format('%d#%d#%d#%s', unit_price, quantity, time(), serialize(L.list))
	else
		-- keep the stored price levels if this update didn't collect new ones
		local old = stored_levels(data[item_key])
		data[item_key] = format('%d#%d#%d', unit_price, quantity, time()) .. (old and ('#' .. old) or '')
	end
end

-- the cheapest price levels of an item from its last complete scan, cheapest first
function M.get_levels(item_key)
	local rest = stored_levels(data and data[item_key])
	if not rest or rest == '' then return end
	local list = {}
	for p, q in string.gfind(rest, '(%d+):(%d+)') do
		tinsert(list, {p = tonumber(p), q = tonumber(q)})
	end
	return list
end

local function add_level(item_key, unit_price, quantity)
	local L = levels[item_key]
	if not L or L.gen ~= generation then
		L = {gen = generation, list = {}}
		levels[item_key] = L
	end
	local list = L.list
	for i, l in ipairs(list) do
		if l.p == unit_price then l.q = l.q + quantity return end
		if unit_price < l.p then
			tinsert(list, i, {p = unit_price, q = quantity})
			if getn(list) > LEVELS then tremove(list) end
			return
		end
	end
	if getn(list) < LEVELS then tinsert(list, {p = unit_price, q = quantity}) end
end

-- worth the walk to a vendor: at least 5 copper and 10% profit per item
function M.is_vendor_flip(ah_price, vendor)
	return vendor and ah_price and vendor - ah_price >= max(5, ah_price * .1)
end

-- every scan starts a new generation: the first auction of an item in a scan replaces the old price,
-- later auctions of the same item in the same scan only lower it
function M.new_scan()
	generation = generation + 1
end

function M.record(item_key, unit_price, quantity, partial)
	if not data or not unit_price or unit_price <= 0 then return end
	unit_price = ceil(unit_price)
	-- price levels only from scans that saw every page of the item
	if not partial then add_level(item_key, unit_price, quantity) end
	if seen[item_key] == generation then
		local m, q = get(item_key)
		if m then
			put(item_key, min(m, unit_price), q + quantity)
			return
		end
	elseif partial then
		-- a scan of only some pages may miss the cheapest auction: keep a recent lower price
		local m, _, t = get(item_key)
		if m and m < unit_price and time() - t < MAX_AGE then return end
	end
	seen[item_key] = generation
	put(item_key, unit_price, quantity)
end

function M.process_auction(auction_record)
	if auction_record.query_type ~= 'list' or auction_record.buyout_price <= 0 then return end
	local query = auction_record.blizzard_query
	local partial = query and (query.first_page or query.last_page)
	record(auction_record.item_key, auction_record.buyout_price / auction_record.aux_quantity, auction_record.aux_quantity, partial)
end

function M.vendor_price(item_id)
	local price = info.merchant_info(item_id)
	if not price and ShaguTweaks and ShaguTweaks.SellValueDB then
		price = ShaguTweaks.SellValueDB[item_id]
		if price then
			price = price / (info.max_item_charges(item_id) or 1)
		end
	end
	if price and price > 0 then return price end
end

function M.age_string(t)
	local s = time() - t
	if s < 60 * 60 then return max(0, floor(s / 60)) .. 'm' end
	if s < 24 * 60 * 60 then return floor(s / (60 * 60)) .. 'h' end
	return floor(s / (24 * 60 * 60)) .. 'd'
end

-- a price gap: buy the cheapest levels when the next price is well above all of them.
-- returns { quantity, cost, price (most expensive bought), compare (relist price), gain, score }
function M.find_gap(item_key)
	local L = get_levels(item_key)
	if not L or getn(L) < 2 then return end
	local value = history.value(item_key)
	local days = value and getn(history.data_points(item_key)) or 0
	local best
	local cost, qty = 0, 0
	for k = 1, getn(L) - 1 do
		cost, qty = cost + L[k].p * L[k].q, qty + L[k].q
		if qty > GAP_MAX_BUY then break end
		local next_price = L[k + 1].p
		local relist = next_price - 1
		-- the next listing must be the real market, not one silly price: never relist above the usual
		-- price, and unless there are enough days of history, more listings must follow close behind it
		local believable = not value or relist <= value * GAP_MAX_OVER_VALUE
		if believable and days < GAP_MIN_DAYS then
			believable = (L[k + 2] and L[k + 2].p <= next_price * 1.3) or L[k + 1].q >= 3
		end
		if believable and relist >= L[k].p * GAP_RATIO then
			local gain = floor(relist * (1 - AH_CUT)) * qty - cost
			if gain >= GAP_MIN_PROFIT and (not best or gain > best.gain) then
				best = {quantity = qty, cost = cost, price = L[k].p, compare = relist, gain = gain, score = gain}
			end
		end
	end
	return best
end

function M.find(mode)
	local out = {}
	if not data then return out end
	local now = time()
	for item_key in data do
		local m, q, t = get(item_key)
		if m and now - t < MAX_AGE then
			local _, _, item_id, suffix_id = strfind(item_key, '^(%d+):(%d+)$')
			item_id, suffix_id = tonumber(item_id), tonumber(suffix_id)
			if item_id then
				if mode == GAPS then
					local gap = find_gap(item_key)
					if gap then
						gap.item_key, gap.item_id, gap.suffix_id, gap.time = item_key, item_id, suffix_id, t
						tinsert(out, gap)
					end
				elseif mode == VENDOR then
					local vendor = vendor_price(item_id)
					if is_vendor_flip(m, vendor) then
						tinsert(out, {
							item_key = item_key, item_id = item_id, suffix_id = suffix_id,
							price = m, quantity = q, time = t, compare = vendor,
							gain = vendor - m, score = (vendor - m) * min(q, 20),
						})
					end
				else
					local value = history.value(item_key)
					-- needs at least two days of price history, otherwise "usual" is just today's price
					if value and m < value * CHEAP_RATIO and getn(history.data_points(item_key)) >= 2 then
						tinsert(out, {
							item_key = item_key, item_id = item_id, suffix_id = suffix_id,
							price = m, quantity = q, time = t, compare = value,
							gain = value - m, score = value - m,
						})
					end
				end
			end
		end
	end
	sort(out, function(a, b) return a.score > b.score end)
	return out
end

-- known: prices remembered, fresh: younger than MAX_AGE, vendor: fresh ones with a vendor price,
-- best: the fresh item closest to being a vendor flip (largest vendor price minus AH price)
function M.stats()
	local known, fresh, vendor, best, best_gain = 0, 0, 0, nil, nil
	local now = time()
	for item_key in data or {} do
		known = known + 1
		local m, _, t = get(item_key)
		if m and now - t < MAX_AGE then
			fresh = fresh + 1
			local _, _, item_id = strfind(item_key, '^(%d+):')
			local v = vendor_price(tonumber(item_id))
			if v then
				vendor = vendor + 1
				if not best_gain or v - m > best_gain then best, best_gain = item_key, v - m end
			end
		end
	end
	return known, fresh, vendor, best, best_gain
end

---------------------------------------------------------------------------- fast full scan

local scan_frame = CreateFrame('Frame')
local state -- nil when no full scan is running
local history_record = {}

function M.full_scan_running() return state ~= nil end
function M.last_full_scan() return meta end

function aux.handle.CLOSE()
	stop_full_scan('the auction house was closed')
end

local function finish(reason)
	local s = state
	state = nil
	scan_frame:SetScript('OnUpdate', nil)
	scan_frame:UnregisterEvent('AUCTION_ITEM_LIST_UPDATE')
	return s
end

function M.stop_full_scan(reason)
	if not state then return end
	local s = finish()
	do (s.callbacks.on_stop or pass)(reason, s.auctions) end
end

local function page_ready(batch)
	for i = 1, batch do
		if not GetAuctionItemLink('list', i) then return false end
	end
	return true
end

-- a cheap fingerprint of the page, to notice the server sending the previous page again
local function page_signature(batch)
	local first, last = GetAuctionItemLink('list', 1), GetAuctionItemLink('list', batch)
	local _, _, _, _, _, _, _, _, b1 = GetAuctionItemInfo('list', 1)
	local _, _, _, _, _, _, _, _, b2 = GetAuctionItemInfo('list', batch)
	return batch .. (first or '') .. (b1 or '') .. (last or '') .. (b2 or '')
end

local function read_page(batch, total)
	local s = state
	for i = 1, batch do
		local link = GetAuctionItemLink('list', i)
		if link then
			local _, _, count, _, _, _, _, _, buyout = GetAuctionItemInfo('list', i)
			local item_id, suffix_id = info.parse_link(link)
			-- items with charges need the tooltip to get the real quantity; the normal search handles those
			if buyout and buyout > 0 and count and count > 0 and not info.max_item_charges(item_id) then
				local item_key = item_id .. ':' .. suffix_id
				record(item_key, buyout / count, count)
				history_record.item_key, history_record.buyout_price, history_record.aux_quantity = item_key, buyout, count
				history.process_auction(history_record)
			end
		end
	end
	local now = GetTime()
	s.t_items = s.t_items + (now - s.updated)
	s.auctions = s.auctions + batch
	s.pages = max(1, ceil(total / PAGE_SIZE))
	s.page = s.page + 1
	s.done = s.done + 1
	s.retries = 0
	s.query_since = now
	if s.page >= s.pages then
		-- category finished
		s.category = s.category + 1
		s.page, s.pages = 0, 1
	end
	do (s.callbacks.on_progress or pass)(s) end
	if s.category > getn(s.classes) then
		finish()
		meta.time, meta.auctions, meta.seconds, meta.quick = time(), s.auctions, floor(now - s.started + .5), s.quick
		do (s.callbacks.on_complete or pass)(s) end
	else
		s.step = 'query'
	end
end

local function send_query(s, now)
	s.forced = not CanSendAuctionQuery()
	s.t_throttle = s.t_throttle + (now - s.query_since)
	s.updated, s.sent, s.step = nil, now, 'wait'
	QueryAuctionItems('', nil, nil, nil, s.classes[s.category] or nil, nil, s.page, nil, nil)
end

local function force_failed(s, now, why)
	s.force = false
	s.forced = false
	aux.account_data.flip_fast = false
	aux.print('fast mode does not work on this server (' .. why .. '), continuing at normal speed. Fast mode is now off.')
	s.query_since = now
	s.step = 'query'
end

local function on_update()
	local s = state
	if not s then return end
	local now = GetTime()
	if s.step == 'query' then
		if CanSendAuctionQuery() or s.force and now - s.query_since > .25 then
			send_query(s, now)
		end
	elseif s.step == 'wait' then
		if s.updated then
			-- take the page as soon as every auction on it has its item link; items the client has never
			-- seen get at most 0.3s to arrive, the rest are skipped (a normal search picks them up later)
			local batch, total = GetNumAuctionItems('list')
			if page_ready(batch) or now - s.updated > .3 then
				local signature = page_signature(batch)
				if s.forced and s.page > 0 and signature == s.signature then
					return force_failed(s, now, 'the server sent the same page again')
				end
				s.signature = signature
				if s.forced then s.forced_ok = s.forced_ok + 1 end
				read_page(batch, total)
			end
		elseif s.forced and now - s.sent > 1.5 then
			return force_failed(s, now, 'no answer to an early query')
		elseif now - s.sent > 8 then
			s.retries = s.retries + 1
			if s.retries > 3 then
				stop_full_scan('the server stopped answering')
			else
				s.query_since = now
				s.step = 'query'
			end
		end
	end
end

-- average seconds per page: total, waiting for permission to query, waiting for the server, waiting for item data
function M.timing(s)
	local pages = max(1, s.done)
	return (GetTime() - s.started) / pages, s.t_throttle / pages, s.t_server / pages, s.t_items / pages
end

scan_frame:SetScript('OnEvent', function()
	if state and state.step == 'wait' and not state.updated then
		state.updated = GetTime()
		state.t_server = state.t_server + (state.updated - state.sent)
	end
end)

-- options: quick = skip the Weapon and Armor categories, force = don't wait for CanSendAuctionQuery
function M.start_full_scan(callbacks, options)
	options = options or {}
	if not (aux.frame and aux.frame:IsVisible()) then
		aux.print('open the auction house first.')
		return
	end
	local classes = {}
	if options.quick then
		-- the 1.12 categories are Weapon, Armor, Container, Consumable, Trade Goods, Projectile, Quiver, Recipe, Reagent, Misc.
		local names = {GetAuctionItemClasses()}
		for i = 3, getn(names) do tinsert(classes, i) end
	else
		classes[1] = false -- one query over everything
	end
	scan.abort()
	new_scan()
	state = {page = 0, pages = 1, category = 1, classes = classes, quick = options.quick, force = options.force,
		done = 0, auctions = 0, retries = 0, forced_ok = 0, started = GetTime(), query_since = GetTime(), step = 'query',
		callbacks = callbacks or {}, t_throttle = 0, t_server = 0, t_items = 0}
	scan_frame:RegisterEvent('AUCTION_ITEM_LIST_UPDATE')
	scan_frame:SetScript('OnUpdate', on_update)
end
