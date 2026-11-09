module 'aux.tabs.flips'

local aux = require 'aux'
local info = require 'aux.util.info'
local gui = require 'aux.gui'
local listing_util = require 'aux.gui.listing'
local flips = require 'aux.core.flips'

frame = CreateFrame('Frame', nil, aux.frame)
frame:SetAllPoints()
frame:Hide()

hint = gui.label(frame, gui.font_size.medium)
hint:SetPoint('TOPLEFT', frame, 'TOPLEFT', 12, -14)
hint:SetJustifyH('LEFT')

count_label = gui.label(frame, gui.font_size.medium)
count_label:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -12, -14)
count_label:SetJustifyH('RIGHT')

frame.listing = gui.panel(frame)
frame.listing:SetPoint('TOP', frame, 'TOP', 0, -34)
frame.listing:SetPoint('BOTTOMLEFT', aux.frame.content, 'BOTTOMLEFT', 0, 0)
frame.listing:SetPoint('BOTTOMRIGHT', aux.frame.content, 'BOTTOMRIGHT', 0, 0)

vendor_columns = {
	{name='Item', width=.37, align='LEFT', headAlign='LEFT'},
	{name='Qty\nup', width=.07, align='CENTER'},
	{name='AH lowest\n(each)', width=.16, align='RIGHT'},
	{name='Vendor pays\n(each)', width=.16, align='RIGHT'},
	{name='Profit\n(each)', width=.16, align='RIGHT'},
	{name='Seen', width=.08, align='CENTER'},
}
cheap_columns = {
	{name='Item', width=.37, align='LEFT', headAlign='LEFT'},
	{name='Qty\nup', width=.07, align='CENTER'},
	{name='AH lowest\n(each)', width=.16, align='RIGHT'},
	{name='Usual price\n(each)', width=.16, align='RIGHT'},
	{name='% of\nusual', width=.16, align='CENTER'},
	{name='Seen', width=.08, align='CENTER'},
}

gaps_columns = {
	{name='Item', width=.34, align='LEFT', headAlign='LEFT'},
	{name='Buy\n(qty)', width=.07, align='CENTER'},
	{name='Cost\n(total)', width=.16, align='RIGHT'},
	{name='Relist at\n(each)', width=.16, align='RIGHT'},
	{name='Profit\n(total)', width=.16, align='RIGHT'},
	{name='Seen', width=.08, align='CENTER'},
}

listing = listing_util.new(frame.listing)
listing:SetColInfo(vendor_columns)
listing:SetHandler('OnClick', function(st, data, row, button)
	if data.record then search(data.record) end
end)
listing:SetHandler('OnEnter', function(st, data, row)
	if data.record and data.record.itemstring then
		info.set_tooltip(data.record.itemstring, row, 'ANCHOR_RIGHT')
	end
end)
listing:SetHandler('OnLeave', function()
	GameTooltip:Hide()
end)

do
	status_bar = gui.status_bar(frame)
	status_bar:SetWidth(230)
	status_bar:SetHeight(25)
	status_bar:SetPoint('TOPLEFT', aux.frame.content, 'BOTTOMLEFT', 0, -6)
	status_bar:update_status(1, 1)
	status_bar:set_text('')
end
do
	local btn = gui.button(frame, gui.font_size.medium)
	btn:SetPoint('TOPLEFT', status_bar, 'TOPRIGHT', 5, 0)
	gui.set_size(btn, 72, 24)
	btn:SetText('Full Scan')
	btn:SetScript('OnClick', function() toggle_full_scan(false) end)
	scan_button = btn
end
do
	local btn = gui.button(frame, gui.font_size.medium)
	btn:SetPoint('TOPLEFT', scan_button, 'TOPRIGHT', 5, 0)
	gui.set_size(btn, 72, 24)
	btn:SetText('Quick Scan')
	btn:SetScript('OnClick', function() toggle_full_scan(true) end)
	quick_button = btn
end
do
	local btn = gui.button(frame, gui.font_size.medium)
	btn:SetPoint('TOPLEFT', quick_button, 'TOPRIGHT', 5, 0)
	gui.set_size(btn, 60, 24)
	btn:SetText('Vendor')
	btn:SetScript('OnClick', function() set_mode(flips.VENDOR) end)
	vendor_button = btn
end
do
	local btn = gui.button(frame, gui.font_size.medium)
	btn:SetPoint('TOPLEFT', vendor_button, 'TOPRIGHT', 5, 0)
	gui.set_size(btn, 80, 24)
	btn:SetText('Under usual')
	btn:SetScript('OnClick', function() set_mode(flips.CHEAP) end)
	cheap_button = btn
end
do
	local btn = gui.button(frame, gui.font_size.medium)
	btn:SetPoint('TOPLEFT', cheap_button, 'TOPRIGHT', 5, 0)
	gui.set_size(btn, 60, 24)
	btn:SetText('Gaps')
	btn:SetScript('OnClick', function() set_mode(flips.GAPS) end)
	gaps_button = btn
end
