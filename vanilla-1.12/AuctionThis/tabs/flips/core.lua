module 'aux.tabs.flips'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local flips = require 'aux.core.flips'
local search_tab = require 'aux.tabs.search'

local tab = aux.tab 'Flips'

mode = flips.VENDOR

function tab.OPEN()
	frame:Show()
	refresh()
end

function tab.CLOSE()
	frame:Hide()
end

function M.set_mode(m)
	mode = m
	refresh()
end

local function price(amount)
	return money.to_string(amount, true, true)
end

function update_status()
	if flips.full_scan_running() then
		scan_button:SetText('Stop')
		quick_button:SetText('Stop')
		return
	end
	scan_button:SetText('Full Scan')
	quick_button:SetText('Quick Scan')
	local last = flips.last_full_scan()
	if last and last.time then
		status_bar:update_status(1, 1)
		status_bar:set_text(format('%s scan %s ago, %d auctions', last.quick and 'Quick' or 'Full', flips.age_string(last.time), last.auctions or 0))
	else
		status_bar:update_status(0, 0)
		status_bar:set_text('No full scan yet - press Full Scan')
	end
end

-- column sorting: sort_state[mode] = { col = column number, desc = true/false }; nil = best first
sort_state = {}

-- the value each column sorts by
local function sort_value(e, col)
	if col == 1 then return strlower(e.name or ('item ' .. e.item_id))
	elseif col == 2 then return e.quantity
	elseif col == 3 then return mode == flips.GAPS and e.cost or e.price
	elseif col == 4 then return e.compare
	elseif col == 5 then return mode == flips.CHEAP and e.price / e.compare or e.gain
	else return -e.time end -- "Seen": newest first when descending
end

function M.sort_by(col)
	local st = sort_state[mode]
	if st and st.col == col then
		st.desc = not st.desc
	else
		-- names A-Z first, numbers biggest first
		sort_state[mode] = {col = col, desc = col ~= 1}
	end
	refresh()
end

-- column headers with the sort arrow, and make them clickable
local function columns(base)
	local st = sort_state[mode]
	local cols = {}
	for i, c in ipairs(base) do
		local copy = {}
		for k, v in pairs(c) do copy[k] = v end
		if st and st.col == i then copy.name = c.name .. (st.desc and ' v' or ' ^') end
		cols[i] = copy
	end
	listing:SetColInfo(cols)
	for i, head in ipairs(listing.headCols) do
		if not head.sortable then
			head.sortable = true
			head:EnableMouse(true)
			local index = i
			head:SetScript('OnMouseUp', function() sort_by(index) end)
			head:SetScript('OnEnter', function() this.text:SetTextColor(1, 1, 1) end)
			head:SetScript('OnLeave', function() this.text:SetTextColor(aux.color.label.enabled()) end)
		end
	end
end

function M.refresh()
	vendor_button:SetAlpha(mode == flips.VENDOR and 1 or .5)
	cheap_button:SetAlpha(mode == flips.CHEAP and 1 or .5)
	gaps_button:SetAlpha(mode == flips.GAPS and 1 or .5)
	if mode == flips.GAPS then
		hint:SetText('Cheap auctions well below the rest: buy, relist under the next price (profit after 5% AH cut). You have ' .. price(GetMoney()) .. '.')
		columns(gaps_columns)
	elseif mode == flips.VENDOR then
		hint:SetText('Buy on AH, sell to vendor. Click a row to search it.')
		columns(vendor_columns)
	else
		hint:SetText(format('Under %d%% of usual price. Click a row to search it.', flips.CHEAP_RATIO * 100))
		columns(cheap_columns)
	end
	if not flips.full_scan_running() then update_status() end

	local entries = flips.find(mode)
	for _, e in ipairs(entries) do
		e.item_info = info.item(e.item_id, e.suffix_id)
		e.name = e.item_info and e.item_info.name
	end
	local st = sort_state[mode]
	if st then
		sort(entries, function(a, b)
			local x, y = sort_value(a, st.col), sort_value(b, st.col)
			if x == y then return a.score > b.score end
			if st.desc then return x > y else return x < y end
		end)
	end

	local rows = T.acquire()
	for _, e in ipairs(entries) do
		local item_info = e.item_info
		e.itemstring = item_info and item_info.itemstring or ('item:' .. e.item_id .. ':0:' .. e.suffix_id .. ':0')
		local name = e.name and (aux.select(4, GetItemQualityColor(item_info.quality)) .. e.name .. FONT_COLOR_CODE_CLOSE) or ('item ' .. e.item_id)
		local third
		if mode == flips.GAPS then
			third = aux.color.green('+' .. price(e.gain))
			-- gray out what you can't afford
			if e.cost > GetMoney() then name = '|cff808080' .. (e.name or ('item ' .. e.item_id)) .. '|r' end
		elseif mode == flips.VENDOR then
			third = aux.color.green('+' .. price(e.gain))
		else
			third = aux.color.green(aux.round(e.price / e.compare * 100) .. '%')
		end
		tinsert(rows, T.map(
			'cols', T.list(
				T.map('value', name),
				T.map('value', e.quantity),
				T.map('value', mode == flips.GAPS and price(e.cost) or price(e.price)),
				T.map('value', price(e.compare)),
				T.map('value', third),
				T.map('value', flips.age_string(e.time))
			),
			'record', e
		))
	end
	listing:SetData(rows)
	local known, fresh, vendor = flips.stats()
	count_label:SetText(format('%d found  |  %d prices, %d fresh (<3h), %d with vendor price', getn(rows), known, fresh, vendor))
end

function search(e)
	if not e.name then return end
	aux.set_tab(1)
	search_tab.set_filter(strlower(e.name) .. '/exact')
	search_tab.execute(nil, false)
end

function M.toggle_full_scan(quick)
	if flips.full_scan_running() then
		flips.stop_full_scan('stopped')
		return
	end
	local last = flips.last_full_scan()
	local fast = aux.account_data.flip_fast
	status_bar:update_status(0, 0)
	status_bar:set_text('Waiting for the server...')
	flips.start_full_scan({
		on_progress = function(st)
			local per_page, throttle, server, items = flips.timing(st)
			local categories = getn(st.classes)
			local frac = (st.category - 1 + (st.page > 0 and st.page / st.pages or 0)) / categories
			local text
			if st.quick then
				local class_name = aux.select(st.classes[min(st.category, categories)] or 1, GetAuctionItemClasses()) or '?'
				text = format('%s %d/%d, p%d/%d', class_name, min(st.category, categories), categories, st.page, st.pages)
			else
				local eta = floor(per_page * (st.pages - st.page))
				text = format('Page %d/%d, %.1fs, ~%dm left', st.page, st.pages, per_page, ceil(eta / 60))
			end
			status_bar:update_status(frac, 0)
			status_bar:set_text(text)
			if mod(st.done, 10) == 0 and frame:IsVisible() then refresh() end
			if mod(st.done, 25) == 0 then
				aux.print(format('scan speed: %.2fs per page = waiting to be allowed to query %.2fs + server answer %.2fs + item data %.2fs', per_page, throttle, server, items))
			end
		end,
		on_complete = function(st)
			local per_page, throttle, server, items = flips.timing(st)
			local seconds = floor(GetTime() - st.started + .5)
			aux.print(format('%s scan done: %d auctions, %d pages in %dm %02ds (%.2fs per page: query wait %.2fs, server %.2fs, item data %.2fs).',
				st.quick and 'quick' or 'full', st.auctions, st.done, floor(seconds / 60), mod(seconds, 60), per_page, throttle, server, items))
			if st.force then aux.print(format('fast mode worked: %d pages were sent early.', st.forced_ok)) end
			update_status()
			if frame:IsVisible() then refresh() end
		end,
		on_stop = function(reason, auctions)
			aux.print(format('scan stopped (%s) after %d auctions. Prices read so far are kept.', reason or '?', auctions or 0))
			status_bar:update_status(1, 1)
			status_bar:set_text('Stopped: ' .. (reason or '?'))
			update_status()
			if frame:IsVisible() then refresh() end
		end,
	}, {quick = quick, force = fast})
	if flips.full_scan_running() then
		update_status()
		aux.print((quick and 'quick scan (no weapons/armor)' or 'full scan') .. ' started' .. (fast and ', fast mode on' or '')
			.. (last and last.seconds and format(' (last scan took %dm %02ds)', floor(last.seconds / 60), mod(last.seconds, 60)) or '') .. '.')
	end
end
