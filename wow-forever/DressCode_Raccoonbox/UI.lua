-- Dress Code [Raccoonbox] for WoW Forever - the window. A lookbook: your character on a stage in the
-- middle, the two-outfit doll around it, the finder (or browse / outfits) on the left.
local ADDON, DC = ...
local T = DC.T

local f -- the main window (built the first time it opens, after the saved theme is known)
local list, details, model, show_stage, status
local rows, entries, offset = {}, {}, 0
local mode, browse_cat, browse_list = "find", nil, nil
local shown = {} -- slot -> outfit cell shown on the model (nil = the active outfit)
local cells = {}
local chips, refresh = {}, nil

local DOLL_LEFT = { 1, 3, 15, 5, 4, 19, 9 }
local DOLL_RIGHT = { 10, 6, 7, 8, 16, 17, 18 }
local SLOT_ART = { [1] = "Head", [3] = "Shoulder", [15] = "Chest", [5] = "Chest", [4] = "Shirt", [19] = "Tabard", [9] = "Wrists",
	[10] = "Hands", [6] = "Waist", [7] = "Legs", [8] = "Feet", [16] = "MainHand", [17] = "SecondaryHand", [18] = "Ranged" }
local DOLL_SLOT = {}
for _, s in ipairs(DOLL_LEFT) do DOLL_SLOT[s] = true end
for _, s in ipairs(DOLL_RIGHT) do DOLL_SLOT[s] = true end

-- poses: name, animation id (the game's standard character animations)
local POSES = { { "Idle", 0 }, { "Walk", 4 }, { "Run", 5 }, { "Wave", 67 }, { "Bow", 66 }, { "Dance", 69 },
	{ "Cheer", 68 }, { "Flex", 82 }, { "Salute", 113 }, { "Kneel", 75 }, { "Laugh", 70 }, { "Point", 84 } }

local function item_link(id)
	local _, link = C_Item.GetItemInfo(id)
	return link or ("item:" .. id)
end
local function item_icon(id) return C_Item.GetItemIconByID(id) or 134400 end
local function owned(id) return (C_Item.GetItemCount(id, true) or 0) > 0 end
local function doll() return DressCodeChar.doll end
local function cell_item(slot, n) local d = doll()[slot] return d and d[n] end
local function cell_locked(slot, n) local l = DressCodeChar.locks[slot] return l and l[n] end

---------------------------------------------------------------------------- the model: dressing, poses, preview

local function apply_pose()
	local id = DressCodeChar.pose or 0
	pcall(model.SetAnimation, model, id)
end

-- weapons go into a named hand so trying them on again never moves them to the other hand
local function try_on(id, slot)
	local link = item_link(id)
	if slot == 16 then pcall(model.TryOn, model, link, "MAINHANDSLOT")
	elseif slot == 17 then pcall(model.TryOn, model, link, "SECONDARYHANDSLOT")
	else pcall(model.TryOn, model, link) end
end

local function wear_outfit()
	if DressCodeChar.undressed then pcall(model.Undress, model) end
	for slot in pairs(DOLL_SLOT) do
		local id = cell_item(slot, shown[slot] or DressCodeChar.active)
		if id then try_on(id, slot) end
	end
	apply_pose()
end

local update_cells -- forward
local function rebuild_model()
	model:SetUnit("player")
	wear_outfit()
	if update_cells then update_cells() end
end

-- hovering an item tries it on for a moment
local previewing, restore_at
local function preview(id)
	if not (DressCodeDB.preview ~= false and id) then return end
	restore_at = nil
	local slots = DC.EQUIP_SLOTS[DC.EquipLoc(id) or ""]
	try_on(id, slots and slots[1])
	previewing = true
end
local function end_preview()
	if previewing then restore_at = GetTime() + 0.15 end
end

---------------------------------------------------------------------------- the doll

local function say(msg) DC.Print(msg) end

-- put an item into the doll: a chosen cell, or the active outfit's cell for its slot
local function add_to_doll(id, want_cell, want_slot)
	local loc = DC.EquipLoc(id)
	local slots = DC.EQUIP_SLOTS[loc or ""]
	if not slots then say("that item can't be worn.") return end
	local slot = slots[1]
	if want_slot and want_slot ~= slot then
		if not (want_slot == 17 and loc == "INVTYPE_WEAPON") then
			say("that goes in the " .. DC.SLOT_NAMES[slot] .. " slot.")
			return
		end
		slot = want_slot
	end
	if not DOLL_SLOT[slot] then say("necks, rings and trinkets don't show on the character, so they aren't part of outfits.") return end
	local n = want_cell
	if n then
		if cell_locked(slot, n) then say(DC.SLOT_NAMES[slot] .. " (outfit " .. n .. ") is locked.") return end
	else
		n = DressCodeChar.active
		if cell_locked(slot, n) then n = 3 - n end
		if cell_locked(slot, n) then say(DC.SLOT_NAMES[slot] .. ": both cells are locked.") return end
	end
	doll()[slot] = doll()[slot] or {}
	doll()[slot][n] = id
	shown[slot] = n
	rebuild_model()
end
DC.AddToDoll = add_to_doll

-- an item on the cursor (dragged from the list, bags, auction house, journal, chat ...)
local function cursor_item()
	local kind, id, link = GetCursorInfo()
	if kind == "item" then return id or DC.ItemID(link) end
end

local function make_cell(slot, n)
	local b = CreateFrame("Button", nil, f)
	b:SetSize(T.cell, T.cell)
	b.bg = DC.Fill(b, T.surface)
	b.border = b:CreateTexture(nil, "BORDER")
	b.border:SetPoint("TOPLEFT", -1, 1) b.border:SetPoint("BOTTOMRIGHT", 1, -1)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 2, -2) b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
	b.own = b:CreateTexture(nil, "OVERLAY")
	b.own:SetSize(6, 6) b.own:SetPoint("BOTTOMLEFT", 3, 3)
	b.own:SetColorTexture(unpack(T.good))
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	local lock = CreateFrame("Button", nil, b)
	lock:SetSize(14, 14)
	lock:SetPoint("TOPRIGHT", 5, 5)
	lock:SetFrameLevel(b:GetFrameLevel() + 3)
	lock.tex = lock:CreateTexture(nil, "OVERLAY")
	lock.tex:SetAllPoints()
	lock.tex:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
	lock.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	lock:SetScript("OnClick", function()
		DressCodeChar.locks[slot] = DressCodeChar.locks[slot] or {}
		DressCodeChar.locks[slot][n] = not DressCodeChar.locks[slot][n] or nil
		update_cells()
	end)
	lock:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(cell_locked(slot, n) and "Locked" or "Lock", 1, 1, 1)
		GameTooltip:AddLine("A locked item stays when you press Reset or load an outfit.", nil, nil, nil, true)
		GameTooltip:Show()
	end)
	lock:SetScript("OnLeave", GameTooltip_Hide)
	b.lock = lock
	local function receive()
		local id = cursor_item()
		if id then ClearCursor() add_to_doll(id, n, slot) return true end
	end
	b:SetScript("OnReceiveDrag", receive)
	b:SetScript("OnClick", function(_, button)
		if receive() then return end
		local id = cell_item(slot, n)
		if button == "RightButton" then
			if cell_locked(slot, n) then say("unlock it first (the key).") return end
			if doll()[slot] then doll()[slot][n] = nil end
			rebuild_model()
			return
		end
		if not id then return end
		if IsModifiedClick("CHATLINK") and ChatEdit_InsertLink(item_link(id)) then return end
		shown[slot] = n
		rebuild_model()
		DC.ShowDetails(id)
	end)
	b:SetScript("OnDragStart", function()
		local id = cell_item(slot, n)
		if id then (C_Item.PickupItem or PickupItem)(id) end
	end)
	b:SetScript("OnEnter", function(self)
		local id = cell_item(slot, n)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if id then
			GameTooltip:SetItemByID(id)
		else
			GameTooltip:SetText(DC.SLOT_NAMES[slot] .. " - outfit " .. n, 1, 1, 1)
			GameTooltip:AddLine("Empty: drag an item here (from the list, your bags, the auction house...), or Shift / Alt / Ctrl-click one.", nil, nil, nil, true)
		end
		GameTooltip:AddLine("Click: put on. Right-click: remove. Key: lock.", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	return b
end

update_cells = function()
	local active = DressCodeChar.active
	for slot, pair in pairs(cells) do
		for n, b in ipairs(pair) do
			local id = cell_item(slot, n)
			if id then
				b.icon:SetTexture(item_icon(id))
				b.icon:SetDesaturated(false)
				b.icon:SetAlpha(1)
				b.own:SetShown(owned(id))
			else
				b.icon:SetTexture("Interface\\Paperdoll\\UI-PaperDoll-Slot-" .. SLOT_ART[slot])
				b.icon:SetDesaturated(true)
				b.icon:SetAlpha(0.5)
				b.own:Hide()
			end
			local on_model = id and (shown[slot] or active) == n
			b.border:SetColorTexture(unpack(on_model and T.accent or T.line))
			if cell_locked(slot, n) then
				b.lock.tex:SetVertexColor(1, 0.82, 0) b.lock:Show()
			elseif id then
				b.lock.tex:SetVertexColor(0.5, 0.5, 0.5) b.lock:Show()
			else
				b.lock:Hide()
			end
		end
	end
	if f.outfit1 then
		f.outfit1:SetOn(active == 1)
		f.outfit2:SetOn(active == 2)
		f.undress.label:SetText(DressCodeChar.undressed and "Dress" or "Undress")
	end
end

---------------------------------------------------------------------------- outfits

local function set_outfit(n)
	DressCodeChar.active = n
	shown = {}
	rebuild_model()
end

local function reset_outfits()
	for slot, d in pairs(doll()) do
		for n = 1, 2 do if not cell_locked(slot, n) then d[n] = nil end end
	end
	shown = {}
	rebuild_model()
end

local function save_outfit(name)
	if not name or name == "" then name = "Outfit " .. (#DressCodeChar.outfits + 1) end
	local copy, count = {}, 0
	for slot, d in pairs(doll()) do
		copy[slot] = { d[1], d[2] }
		if d[1] then count = count + 1 end
		if d[2] then count = count + 1 end
	end
	table.insert(DressCodeChar.outfits, { name = name, doll = copy, stage = DressCodeChar.stage })
	say(('saved "%s" (%d items).'):format(name, count))
	if mode == "outfits" then refresh() end
end

local function load_outfit(o)
	for slot, d in pairs(doll()) do
		for n = 1, 2 do if not cell_locked(slot, n) then d[n] = nil end end
	end
	for slot, d in pairs(o.doll or {}) do
		doll()[slot] = doll()[slot] or {}
		for n = 1, 2 do
			if d[n] and not cell_locked(slot, n) then doll()[slot][n] = d[n] end
		end
	end
	if o.stage then DressCodeChar.stage = o.stage show_stage(o.stage) end
	shown = {}
	rebuild_model()
end

local function edit_box(popup) return (popup.GetEditBox and popup:GetEditBox()) or popup.editBox or popup.EditBox end
StaticPopupDialogs["DRESSCODE_SAVE"] = {
	text = "Name this look:",
	button1 = ACCEPT, button2 = CANCEL,
	hasEditBox = 1, maxLetters = 40, timeout = 0, whileDead = 1, hideOnEscape = 1,
	OnAccept = function(self) save_outfit(edit_box(self):GetText()) end,
	EditBoxOnEnterPressed = function(self) save_outfit(self:GetText()) self:GetParent():Hide() end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

---------------------------------------------------------------------------- details card

function DC.ShowDetails(id, gains)
	if not details then return end
	local r = DC.Record(id)
	local name = (r and r.n) or C_Item.GetItemNameByID(id) or ("item " .. id)
	details.title:SetText(name)
	details.title:SetTextColor(DC.QualityColor(r and r.q))
	details.icon:SetTexture(item_icon(id))
	local lines = {}
	if r then
		local slots = DC.EQUIP_SLOTS[r.loc]
		lines[#lines + 1] = (slots and DC.SLOT_NAMES[slots[1]] or "") .. "  ·  " .. DC.LevelText(r)
			.. (owned(id) and "  ·  |cff55dd66you own it|r" or "")
		local g = gains and DC.GainText(gains, true) or DC.GainText(DC.Difference(r), true)
		if g ~= "" then lines[#lines + 1] = g end
		if r.rep then lines[#lines + 1] = "Requires " .. r.rep end
		if r.pvp then lines[#lines + 1] = "Requires " .. r.pvp end
		if r.set and r.set > 0 then
			local setName = (C_Item.GetItemSetInfo and C_Item.GetItemSetInfo(r.set)) or (GetItemSetInfo and GetItemSetInfo(r.set))
			if setName then lines[#lines + 1] = "Set: " .. setName end
		end
	end
	for _, s in ipairs(DC.Sources(id)) do lines[#lines + 1] = "|cffd8c8a8" .. s .. "|r" end
	if #lines < 2 then lines[#lines + 1] = "|cff999999Where it comes from isn't known yet.|r" end
	details.text:SetText(table.concat(lines, "\n"))
	details.id = id
end

---------------------------------------------------------------------------- the list (find / browse / outfits)

local function entry_text(e)
	if e.kind == "item" then
		local r = e.r or DC.Record(e.id)
		if not r then return "loading...", "", "" end
		local slots = DC.EQUIP_SLOTS[r.loc]
		local src = DC.Sources(e.id)[1]
		local sub = (slots and DC.SLOT_NAMES[slots[1]] or "") .. "  ·  " .. DC.LevelText(r) .. (src and ("  ·  " .. src) or "")
		if e.usable == false then sub = "|cffee5555can't use|r  " .. sub end
		return r.n, sub, e.gains and DC.GainText(e.gains, true) or (e.extra or "")
	elseif e.kind == "back" then return "Back", "", ""
	elseif e.kind == "category" then return e.name, e.count and (e.count .. " lists") or "", ""
	elseif e.kind == "list" then return e.name, e.count and (e.count .. " items") or "", ""
	elseif e.kind == "outfit" then
		local count = 0
		for _, d in pairs(e.outfit.doll or {}) do
			if d[1] then count = count + 1 end
			if d[2] then count = count + 1 end
		end
		return e.outfit.name, count .. " items" .. (e.outfit.stage and ("  ·  " .. DC.StageLabel(e.outfit.stage)) or ""), ""
	end
	return "", "", ""
end

local ICONS = { back = "Interface\\Icons\\Spell_ChargeNegative", category = "Interface\\Icons\\INV_Misc_Book_09",
	list = "Interface\\Icons\\INV_Misc_Note_01", outfit = "Interface\\Icons\\INV_Chest_Cloth_17" }

local function render()
	local visible = #rows
	offset = math.max(0, math.min(offset, #entries - visible))
	for i, row in ipairs(rows) do
		local e = entries[i + offset]
		row.entry = e
		if not e then
			row:Hide()
		else
			row:Show()
			local name, sub, right = entry_text(e)
			row.name:SetText(name)
			row.sub:SetText(sub)
			row.right:SetText(right)
			if e.kind == "item" then
				local r = e.r or DC.Record(e.id)
				row.icon:SetTexture(item_icon(e.id))
				row.name:SetTextColor(DC.QualityColor(r and r.q))
			else
				row.icon:SetTexture(ICONS[e.kind] or ICONS.list)
				row.name:SetTextColor(unpack(T.text))
			end
		end
	end
	if list.bar then
		local max = math.max(0, #entries - visible)
		list.bar:SetMinMaxValues(0, max)
		list.bar:SetValue(offset)
		list.bar:SetShown(max > 0)
	end
end

local function on_row_click(row, button)
	local e = row.entry
	if not e then return end
	if e.kind == "back" then
		if browse_list then browse_list = nil else browse_cat = nil end
		offset = 0 refresh() return
	elseif e.kind == "category" then browse_cat = e.index offset = 0 refresh() return
	elseif e.kind == "list" then browse_list = e.index offset = 0 refresh() return
	elseif e.kind == "outfit" then
		if button == "RightButton" then
			table.remove(DressCodeChar.outfits, e.index)
			say(('deleted "%s".'):format(e.outfit.name))
			refresh()
		else
			load_outfit(e.outfit)
			say(('wearing "%s".'):format(e.outfit.name))
		end
		return
	end
	local id = e.id
	if not id then return end
	if IsModifiedClick("CHATLINK") and ChatEdit_InsertLink(item_link(id)) then return end
	DC.ShowDetails(id, e.gains)
	if IsShiftKeyDown() then add_to_doll(id, 1)
	elseif IsAltKeyDown() then add_to_doll(id, 2)
	elseif IsControlKeyDown() then add_to_doll(id) end
end

local function make_row(i)
	local row = CreateFrame("Button", nil, list)
	row:SetHeight(T.row)
	row:SetPoint("TOPLEFT", 0, -(i - 1) * (T.row + 2))
	row:SetPoint("RIGHT", list, "RIGHT", -10, 0)
	row.lit = DC.Highlight(row) -- menu style: no box, the gold bar on hover
	DC.Edge(row, "BOTTOM", T.line)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(T.row - 12, T.row - 12)
	row.icon:SetPoint("LEFT", 6, 0)
	row.right = DC.Text(row, T.fontSmall)
	row.right:SetPoint("TOPRIGHT", -8, -8)
	row.right:SetJustifyH("RIGHT")
	row.name = DC.Text(row, T.fontBody)
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
	row.name:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
	row.name:SetWordWrap(false)
	row.sub = DC.Text(row, T.fontSmall, T.muted)
	row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)
	row.sub:SetPoint("RIGHT", -8, 0)
	row.sub:SetWordWrap(false)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:RegisterForDrag("LeftButton")
	row:SetScript("OnClick", on_row_click)
	row:SetScript("OnDragStart", function(self)
		local e = self.entry
		if e and e.kind == "item" and e.id then (C_Item.PickupItem or PickupItem)(e.id) end
	end)
	row:SetScript("OnEnter", function(self)
		self.lit:Show()
		local e = self.entry
		if e and e.kind == "item" and e.id then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetItemByID(e.id)
			GameTooltip:Show()
			preview(e.id)
		end
	end)
	row:SetScript("OnLeave", function(self)
		self.lit:Hide()
		GameTooltip_Hide()
		end_preview()
	end)
	return row
end

-- as many rows as fit
local function layout_rows()
	local h = list:GetHeight()
	if not h or h < 10 then return end
	local need = math.max(1, math.floor((h + 2) / (T.row + 2)))
	for i = #rows + 1, need do rows[i] = make_row(i) end
	for i = need + 1, #rows do rows[i]:Hide() end
	for i = #rows, need + 1, -1 do rows[i] = nil end
	render()
end

---------------------------------------------------------------------------- filling the list

local function ticked()
	for _ in pairs(DressCodeChar.keys) do return true end
	return false
end

-- browse categories, built when opened
local function browse_categories()
	local cats = {}
	-- dungeons & raids from the Encounter Journal
	local j = DressCodeDB.journal
	if j and j.instances then
		local lists = {}
		for _, inst in ipairs(j.instances) do
			local items = {}
			for _, b in ipairs(inst.bosses) do
				for _, id in ipairs(b.items) do items[#items + 1] = { id = id, extra = b.name } end
			end
			lists[#lists + 1] = { name = inst.name .. (inst.raid and " (raid)" or "") .. (inst.level and (" - L" .. inst.level) or ""), items = items }
		end
		cats[#cats + 1] = { name = "Dungeons & raids", lists = lists }
	end
	-- learned quests by zone
	local zones = {}
	for _, r in pairs(DressCodeDB.quests) do
		local z = r.z or "Other"
		zones[z] = zones[z] or {}
		for id in pairs(r.i) do table.insert(zones[z], { id = id, extra = r.t }) end
	end
	local qlists = {}
	for z, items in pairs(zones) do qlists[#qlists + 1] = { name = z, items = items } end
	table.sort(qlists, function(a, b) return a.name < b.name end)
	if #qlists > 0 then cats[#cats + 1] = { name = "Quests (learned in game)", lists = qlists } end
	-- professions, vendors
	local function grouped(tbl, key)
		local g = {}
		for id, v in pairs(tbl or {}) do
			local k = key(v)
			g[k] = g[k] or {}
			table.insert(g[k], { id = id, extra = type(v) == "table" and v.npc or nil })
		end
		local out = {}
		for k, items in pairs(g) do out[#out + 1] = { name = k, items = items } end
		table.sort(out, function(a, b) return a.name < b.name end)
		return out
	end
	local p = grouped(DressCodeDB.crafted, function(v) return v end)
	if #p > 0 then cats[#cats + 1] = { name = "Professions", lists = p } end
	local v = grouped(DressCodeDB.vendors, function(x) return x.zone ~= "" and x.zone or "Other" end)
	if #v > 0 then cats[#cats + 1] = { name = "Vendors you visited", lists = v } end
	-- factions, PvP, sets: from the items read so far
	local fac, pvp, sets = {}, {}, {}
	for _, id in ipairs(DC.catalog and DC.catalog.ids or {}) do
		if DressCodeDB.items[id] then
			local r = DC.Record(id, true)
			if r then
				if r.rep then local k = r.rep:match("^(.-) %- ") or r.rep fac[k] = fac[k] or {} table.insert(fac[k], { id = id, extra = r.rep }) end
				if r.pvp then pvp[r.pvp] = pvp[r.pvp] or {} table.insert(pvp[r.pvp], { id = id }) end
				if r.set and r.set > 0 then sets[r.set] = sets[r.set] or {} table.insert(sets[r.set], { id = id }) end
			end
		end
	end
	local function lists_of(tbl, namer)
		local out = {}
		for k, items in pairs(tbl) do out[#out + 1] = { name = namer(k), items = items } end
		table.sort(out, function(a, b) return a.name < b.name end)
		return out
	end
	local fl = lists_of(fac, function(k) return k end)
	if #fl > 0 then cats[#cats + 1] = { name = "Factions", lists = fl } end
	local pl = lists_of(pvp, function(k) return k end)
	if #pl > 0 then cats[#cats + 1] = { name = "PvP", lists = pl } end
	local sl = lists_of(sets, function(k)
		return (C_Item.GetItemSetInfo and C_Item.GetItemSetInfo(k)) or (GetItemSetInfo and GetItemSetInfo(k)) or ("Set " .. k)
	end)
	if #sl > 0 then cats[#cats + 1] = { name = "Sets", lists = sl } end
	return cats
end

local categories_cache
local function build()
	entries = {} -- a fresh table each time
	local keys, text = DressCodeChar.keys, DressCodeChar.search
	local done, found = DC.ScanProgress()
	local loading = DC.LoadProgress()
	local busy = done < 1 and ("Finding items... " .. math.floor(done * 100) .. "%  ") or (loading > 0 and ("Reading items: " .. loading .. " left.  ") or "")
	if mode == "find" then
		if not ticked() and (not text or text == "") then
			status:SetText(busy .. "Pick the stats you want more of, or type something to search.")
		else
			local list_, total = DC.Find({ slot = DressCodeChar.slot, keys = keys, search = text, ahead = DressCodeChar.ahead })
			for _, u in ipairs(list_) do entries[#entries + 1] = { kind = "item", id = u.r.id, r = u.r, gains = u.gains } end
			status:SetText(busy .. total .. " items beat what you wear" .. (total > 300 and " (showing 300)" or "")
				.. ".  Shift: outfit 1 · Alt: outfit 2 · Ctrl: active · or drag.")
		end
	elseif mode == "browse" then
		if not categories_cache then categories_cache = browse_categories() end
		local cats = categories_cache
		if browse_cat then entries[#entries + 1] = { kind = "back" } end
		if not browse_cat then
			for i, c in ipairs(cats) do entries[#entries + 1] = { kind = "category", index = i, name = c.name, count = #c.lists } end
			status:SetText(busy .. "Browse dungeons, quests, professions, vendors, factions, PvP and sets.")
		elseif not browse_list then
			for i, l in ipairs(cats[browse_cat].lists) do entries[#entries + 1] = { kind = "list", index = i, name = l.name, count = #l.items } end
			status:SetText(cats[browse_cat].name)
		else
			local l = cats[browse_cat].lists[browse_list]
			for _, it in ipairs(l.items) do
				local e = { kind = "item", id = it.id, extra = it.extra }
				local r = DC.Record(it.id, true)
				if r then
					e.r = r
					e.usable = DC.CanUse(r, DC.player.level + 100)
					if e.usable and (ticked() or (text and text ~= "")) then e.gains = DC.Compare(r, keys, text) end
				end
				entries[#entries + 1] = e
			end
			status:SetText(l.name)
		end
	else
		for i, o in ipairs(DressCodeChar.outfits) do entries[#entries + 1] = { kind = "outfit", index = i, outfit = o } end
		status:SetText(#entries .. " saved looks. Click: wear it. Right-click: delete. Save a look under the stage.")
	end
	for key, b in pairs(f.tabs) do b:SetOn(key == mode) end
end

refresh = function()
	if not (f and f:IsShown()) then return end
	DC.RefreshPlayer(DC.player.level)
	for key, c in pairs(chips) do c:SetOn(DressCodeChar.keys[key] and true or false) end
	f.now:SetOn((DressCodeChar.ahead or 0) == 0)
	if not f.ahead:HasFocus() then f.ahead:SetText((DressCodeChar.ahead or 0) > 0 and tostring(DressCodeChar.ahead) or "") end
	local ok, err = pcall(build)
	if not ok then status:SetText("|cffee5555" .. tostring(err) .. "|r") end
	render()
end
DC.Refresh = refresh

---------------------------------------------------------------------------- building the window

local function menu(owner, fill)
	if MenuUtil and MenuUtil.CreateContextMenu then MenuUtil.CreateContextMenu(owner, fill) end
end

local function build_window()
	f = CreateFrame("Frame", "DressCodeFrame", UIParent)
	f:SetSize(DressCodeDB.w or 1010, DressCodeDB.h or 660)
	f:SetPoint("CENTER")
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:SetResizable(true)
	if f.SetResizeBounds then f:SetResizeBounds(980, 600, 1700, 1100) end
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	tinsert(UISpecialFrames, "DressCodeFrame")
	DC.Panel(f, 0.96)

	-- top bar: title, tabs, close
	local title = DC.Text(f, T.fontTitle)
	title:SetPoint("TOPLEFT", 18, -14)
	title:SetText("Dress Code")
	local by = DC.Text(f, T.fontSmall, T.muted)
	by:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
	by:SetText("by Raccoonbox")
	f.tabs = {}
	local prev
	for _, t in ipairs({ { "find", "Find" }, { "browse", "Browse" }, { "outfits", "Looks" } }) do
		local key = t[1]
		local b = DC.Button(f, t[2], "chip", nil, 22)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", by, "RIGHT", 24, 0) end
		b:SetScript("OnClick", function() mode = key offset = 0 categories_cache = nil refresh() end)
		f.tabs[key], prev = b, b
	end
	local close = DC.Button(f, "X", "plain", 26, 26)
	close:SetPoint("TOPRIGHT", -10, -10)
	close:SetScript("OnClick", function() f:Hide() end)

	-- left column: search, stat chips, slot + level, list, details
	local left = CreateFrame("Frame", nil, f)
	left:SetPoint("TOPLEFT", 16, -50)
	left:SetPoint("BOTTOMLEFT", 16, 34)
	left:SetWidth(370)

	local search = DC.Input(left, 370)
	search:SetPoint("TOPLEFT")
	search.hint = DC.Text(search, T.fontBody, T.muted)
	search.hint:SetPoint("LEFT", 8, 0)
	search.hint:SetText("Search gear: a name, or tooltip text like \"chance on hit\"")
	search:SetScript("OnTextChanged", function(self, user)
		search.hint:SetShown(self:GetText() == "")
		if not user then return end
		DressCodeChar.search = self:GetText():lower()
		self.pending = GetTime() + 0.35
	end)
	search:SetScript("OnUpdate", function(self)
		if self.pending and GetTime() >= self.pending then self.pending = nil refresh() end
	end)
	f.search = search

	-- stat chips, wrapped in rows
	local x, y = 0, -32
	for _, s in ipairs(DC.STATS) do
		local key = s.key
		local c = DC.Button(left, s.label, "chip", nil, T.chip)
		if x + c:GetWidth() > 370 then x, y = 0, y - T.chip - 4 end
		c:SetPoint("TOPLEFT", x, y)
		x = x + c:GetWidth() + 4
		c:SetScript("OnClick", function()
			DressCodeChar.keys[key] = not DressCodeChar.keys[key] or nil
			refresh()
		end)
		chips[key] = c
	end
	y = y - T.chip - 8

	local slot_btn = DC.Button(left, "Slot: All", "plain", 120, 22)
	slot_btn:SetPoint("TOPLEFT", 0, y)
	slot_btn:SetScript("OnClick", function(self)
		menu(self, function(_, root)
			root:CreateButton("All slots", function() DressCodeChar.slot = nil self.label:SetText("Slot: All") refresh() end)
			for _, slot in ipairs({ 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 13, 16, 17, 18 }) do
				root:CreateButton(DC.SLOT_NAMES[slot], function()
					DressCodeChar.slot = slot self.label:SetText("Slot: " .. DC.SLOT_NAMES[slot]) refresh()
				end)
			end
		end)
	end)
	slot_btn.label:SetText("Slot: " .. (DressCodeChar.slot and DC.SLOT_NAMES[DressCodeChar.slot] or "All"))
	local now = DC.Button(left, "Now", "chip", 50, 22)
	now:SetPoint("LEFT", slot_btn, "RIGHT", 8, 0)
	now.tip = { "Now", "Only gear you can wear at your level." }
	now:SetScript("OnClick", function() DressCodeChar.ahead = 0 f.ahead:ClearFocus() refresh() end)
	f.now = now
	local plus = DC.Text(left, T.fontSmall, T.muted)
	plus:SetPoint("LEFT", now, "RIGHT", 10, 0)
	plus:SetText("+ levels")
	local ahead = DC.Input(left, 40, true)
	ahead:SetPoint("LEFT", plus, "RIGHT", 6, 0)
	ahead:SetScript("OnTextChanged", function(self, user)
		if not user then return end
		DressCodeChar.ahead = math.max(0, math.min(60, tonumber(self:GetText()) or 0))
		refresh()
	end)
	f.ahead = ahead
	y = y - 30

	details = CreateFrame("Frame", nil, left)
	details:SetPoint("BOTTOMLEFT") details:SetPoint("BOTTOMRIGHT")
	details:SetHeight(128)
	DC.Panel(details, 0.85)
	details.icon = details:CreateTexture(nil, "ARTWORK")
	details.icon:SetSize(32, 32) details.icon:SetPoint("TOPLEFT", 8, -8)
	details.title = DC.Text(details, T.fontHeading)
	details.title:SetPoint("LEFT", details.icon, "RIGHT", 8, 0)
	details.title:SetPoint("RIGHT", -8, 0)
	details.title:SetText("Click an item to see where to get it.")
	details.text = DC.Text(details, T.fontSmall)
	details.text:SetPoint("TOPLEFT", details.icon, "BOTTOMLEFT", 0, -6)
	details.text:SetPoint("BOTTOMRIGHT", -8, 6)
	details.text:SetJustifyV("TOP")

	list = CreateFrame("Frame", nil, left)
	list:SetPoint("TOPLEFT", 0, y)
	list:SetPoint("BOTTOMRIGHT", details, "TOPRIGHT", 0, 8)
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, delta) offset = offset - delta * 3 render() end)
	list:SetScript("OnSizeChanged", function() layout_rows() end)
	local bar = CreateFrame("Slider", nil, list)
	bar:SetPoint("TOPRIGHT") bar:SetPoint("BOTTOMRIGHT")
	bar:SetWidth(6)
	bar:SetOrientation("VERTICAL")
	bar:SetObeyStepOnDrag(true)
	bar:SetValueStep(1)
	DC.Fill(bar, T.line)
	local thumb = bar:CreateTexture(nil, "OVERLAY")
	thumb:SetColorTexture(unpack(T.muted))
	thumb:SetSize(6, 30)
	bar:SetThumbTexture(thumb)
	bar:SetScript("OnValueChanged", function(_, v) if math.floor(v) ~= offset then offset = math.floor(v) render() end end)
	list.bar = bar

	-- the stage in the middle, the doll on both sides of it
	local stage = CreateFrame("Frame", nil, f)
	stage:SetPoint("TOPLEFT", left, "TOPRIGHT", 16 + 2 * T.cell + 14, 0)
	stage:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(16 + 2 * T.cell + 14), 34 + 64)
	stage:SetClipsChildren(true)
	show_stage = DC.MakeStage(stage)
	model = CreateFrame("DressUpModel", nil, stage)
	model:SetAllPoints()
	model:SetScript("OnModelLoaded", function() wear_outfit() end)
	stage:EnableMouse(true)
	stage:EnableMouseWheel(true)
	stage:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" then self.turning = GetCursorPosition() end end)
	stage:SetScript("OnMouseUp", function(self) self.turning = nil end)
	stage:SetScript("OnHide", function(self) self.turning = nil end)
	stage:SetScript("OnMouseWheel", function(_, delta)
		DressCodeChar.zoom = math.max(0.5, math.min(2.5, (DressCodeChar.zoom or 1) - delta * 0.1))
		pcall(model.SetCamDistanceScale, model, DressCodeChar.zoom)
	end)
	stage:SetScript("OnUpdate", function(self)
		if self.turning then
			local x = GetCursorPosition()
			model:SetFacing(model:GetFacing() + (x - self.turning) / 80)
			self.turning = x
		end
		if restore_at and GetTime() >= restore_at then restore_at, previewing = nil, nil rebuild_model() end
	end)
	-- items dropped on the stage go into the active outfit
	stage:SetScript("OnReceiveDrag", function() local id = cursor_item() if id then ClearCursor() add_to_doll(id) end end)
	stage:HookScript("OnMouseUp", function() local id = cursor_item() if id then ClearCursor() add_to_doll(id) end end)
	f.stage = stage

	for i, slot in ipairs(DOLL_LEFT) do
		cells[slot] = {}
		for n = 1, 2 do
			local b = make_cell(slot, n)
			b:SetPoint("TOPRIGHT", stage, "TOPLEFT", -8 - (2 - n) * (T.cell + 6), -(i - 1) * (T.cell + 10) - 8)
			cells[slot][n] = b
		end
	end
	for i, slot in ipairs(DOLL_RIGHT) do
		cells[slot] = {}
		for n = 1, 2 do
			local b = make_cell(slot, n)
			b:SetPoint("TOPLEFT", stage, "TOPRIGHT", 8 + (n - 1) * (T.cell + 6), -(i - 1) * (T.cell + 10) - 8)
			cells[slot][n] = b
		end
	end
	for _, side in ipairs({ { DOLL_LEFT[1], "1", "2" }, { DOLL_RIGHT[1], "1", "2" } }) do
		for n = 1, 2 do
			local h = DC.Text(f, T.fontSmall, T.muted)
			h:SetPoint("BOTTOM", cells[side[1]][n], "TOP", 0, 4)
			h:SetText(side[n + 1])
		end
	end

	-- under the stage: outfits, look buttons, stage and pose
	local bar1 = CreateFrame("Frame", nil, f)
	bar1:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 0, -8)
	bar1:SetPoint("TOPRIGHT", stage, "BOTTOMRIGHT", 0, -8)
	bar1:SetHeight(24)
	f.outfit1 = DC.Button(bar1, "Outfit 1", "chip", 70, 24)
	f.outfit1:SetPoint("LEFT")
	f.outfit1:SetScript("OnClick", function() set_outfit(1) end)
	f.outfit2 = DC.Button(bar1, "Outfit 2", "chip", 70, 24)
	f.outfit2:SetPoint("LEFT", f.outfit1, "RIGHT", 4, 0)
	f.outfit2:SetScript("OnClick", function() set_outfit(2) end)
	local save = DC.Button(bar1, "Save look", "accent", 80, 24)
	save:SetPoint("RIGHT")
	save:SetScript("OnClick", function() StaticPopup_Show("DRESSCODE_SAVE") end)
	local reset = DC.Button(bar1, "Reset", "plain", 60, 24)
	reset:SetPoint("RIGHT", save, "LEFT", -4, 0)
	reset.tip = { "Reset", "Removes every item that isn't locked from both outfits." }
	reset:SetScript("OnClick", reset_outfits)
	f.undress = DC.Button(bar1, "Undress", "plain", 70, 24)
	f.undress:SetPoint("RIGHT", reset, "LEFT", -4, 0)
	f.undress.tip = { "Undress / Dress", "Show only the outfit, or the outfit over the gear you wear." }
	f.undress:SetScript("OnClick", function() DressCodeChar.undressed = not DressCodeChar.undressed or nil rebuild_model() end)

	local bar2 = CreateFrame("Frame", nil, f)
	bar2:SetPoint("TOPLEFT", bar1, "BOTTOMLEFT", 0, -8)
	bar2:SetPoint("TOPRIGHT", bar1, "BOTTOMRIGHT", 0, -8)
	bar2:SetHeight(24)
	local stage_btn = DC.Button(bar2, "Stage: " .. DC.StageLabel(DressCodeChar.stage), "plain", 190, 24)
	stage_btn:SetPoint("LEFT")
	stage_btn.tip = { "Stage", "What stands behind your character. Pick a contrast: a calm colour behind a colourful look, a game place for a mood." }
	local function set_stage(key)
		DressCodeChar.stage = key
		show_stage(key)
		stage_btn.label:SetText("Stage: " .. DC.StageLabel(key))
	end
	stage_btn:SetScript("OnClick", function(self)
		menu(self, function(_, root)
			local colours = root:CreateButton("Colours")
			for _, c in ipairs(DC.STAGE_COLOURS) do
				local key = "c:" .. c[1]
				colours:CreateButton(c[1], function() set_stage(key) end)
			end
			local homes = root:CreateButton("Homelands")
			for _, h in ipairs(DC.STAGE_HOMELANDS) do
				local key = "h:" .. h[1]
				homes:CreateButton(h[2], function() set_stage(key) end)
			end
			local inst = DC.InstanceStages()
			local dungeons = root:CreateButton(#inst > 0 and "Dungeons & raids" or "Dungeons & raids (reading the journal...)")
			for _, i in ipairs(inst) do
				local key = "i:" .. i.name
				dungeons:CreateButton(i.name, function() set_stage(key) end)
			end
		end)
	end)
	local runway = DC.Button(bar2, "Runway", "chip", 70, 24)
	runway:SetPoint("RIGHT")
	runway.tip = { "Runway", "Your character walks the catwalk." }
	local pose_btn = DC.Button(bar2, "Pose", "plain", 80, 24)
	pose_btn:SetPoint("RIGHT", runway, "LEFT", -4, 0)
	local function set_pose(id)
		DressCodeChar.pose = id
		runway:SetOn(id == 4)
		apply_pose()
	end
	runway:SetScript("OnClick", function() set_pose(DressCodeChar.pose == 4 and 0 or 4) end)
	pose_btn:SetScript("OnClick", function(self)
		menu(self, function(_, root)
			for _, p in ipairs(POSES) do
				local id = p[2]
				root:CreateButton(p[1], function() set_pose(id) end)
			end
		end)
	end)
	runway:SetOn(DressCodeChar.pose == 4)

	status = DC.Text(f, T.fontSmall, T.muted)
	status:SetPoint("BOTTOMLEFT", 18, 12)
	status:SetPoint("RIGHT", -40, 0)
	status:SetWordWrap(false)

	-- resize grip
	local grip = CreateFrame("Button", nil, f)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -4, 4)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function()
		f:StopMovingOrSizing()
		DressCodeDB.w, DressCodeDB.h = f:GetWidth(), f:GetHeight()
		layout_rows()
	end)

	f:SetScript("OnShow", function()
		search:SetText(DressCodeChar.search or "")
		search.hint:SetShown((DressCodeChar.search or "") == "")
		show_stage(DressCodeChar.stage or "c:Grey")
		rebuild_model()
		pcall(model.SetCamDistanceScale, model, DressCodeChar.zoom or 1)
		layout_rows()
		refresh()
	end)
end

function DC.Toggle()
	if not f then build_window() end
	if f:IsShown() then f:Hide() return end
	-- the Options window closes everything when it closes: don't open underneath it
	if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
	f:Show()
end
function DressCode_OnAddonCompartmentClick() DC.Toggle() end

-- progress and new items: refresh the open window now and then
local last_refresh = 0
local function soon()
	if f and f:IsShown() and GetTime() - last_refresh > 2 then
		last_refresh = GetTime()
		categories_cache = nil
		refresh()
	end
end
DC.OnItemsLearned = soon
DC.OnCatalog = soon
DC.OnProgress = function()
	if f and f:IsShown() and status then
		local done = DC.ScanProgress()
		if done < 1 then status:SetText("Finding every wearable item in the game... " .. math.floor(done * 100) .. "%") end
	end
end

---------------------------------------------------------------------------- the rest of the game

-- Ctrl-click an item anywhere (bags, chat, auction house, journal) while Dress Code is open: into the outfit
hooksecurefunc("HandleModifiedItemClick", function(link)
	if not (f and f:IsShown() and link and IsModifiedClick("DRESSUP")) then return end
	local id = DC.ItemID(link)
	if id and DC.EQUIP_SLOTS[DC.EquipLoc(id) or ""] then
		add_to_doll(id)
		C_Timer.After(0, function() if DressUpFrame and DressUpFrame:IsShown() then HideUIPanel(DressUpFrame) end end)
	end
end)

-- every item tooltip: how it compares with what you wear
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
		if not (DressCodeDB and DressCodeDB.tooltip) then return end
		if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
		local id = data and data.id
		if not id or not DC.EQUIP_SLOTS[DC.EquipLoc(id) or ""] then return end
		local r = DC.Record(id)
		if not r then return end
		local diff = DC.GainText(DC.Difference(r), true)
		local need = DC.ReqLevel(r)
		local lvl = need > DC.player.level and ("  |cffee5555from L" .. need .. "|r") or ""
		tt:AddLine("|cffff9900Dress Code:|r " .. (diff ~= "" and diff or "same stats as what you wear") .. lvl)
	end)
end

---------------------------------------------------------------------------- settings page, commands

local function probe()
	local function has(v) return v and "|cff55dd66yes|r" or "|cffee5555no|r" end
	DC.Print("what this game client offers:")
	print("  item lookups " .. has(C_Item and C_Item.GetItemInfoInstant) .. ", item stats " .. has(C_Item and C_Item.GetItemStats)
		.. ", tooltip data " .. has(C_TooltipInfo and C_TooltipInfo.GetItemByID))
	print("  Encounter Journal " .. has(C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex and EJ_GetNumTiers)
		.. ", appearances " .. has(C_TransmogCollection and C_TransmogCollection.GetItemInfo)
		.. ", dungeon levels " .. has(GetLFGDungeonInfo))
	print("  addon messages " .. has(C_ChatInfo and C_ChatInfo.SendAddonMessage) .. ", menus " .. has(MenuUtil)
		.. ", tooltip hook " .. has(TooltipDataProcessor))
	local done, found = DC.ScanProgress()
	local j = DressCodeDB.journal
	local known, waiting = DC.QuestCounts()
	print(("  catalog: %d wearable items (%s), %d still being read"):format(found, done >= 1 and "complete" or (math.floor(done * 100) .. "%"), DC.LoadProgress()))
	local d, n, art = DressCodeDB.dungeons, 0, 0
	for _, e in pairs(d and d.list or {}) do n = n + 1 if e.art then art = art + 1 end end
	print(("  journal: %d instances; dungeon list: %d dungeons and raids (%d with a picture); quests: %d known, %d heard once")
		:format(j and j.instances and #j.instances or 0, n, art, known, waiting))
end

SLASH_DRESSCODE1, SLASH_DRESSCODE2 = "/dresscode", "/dress"
SlashCmdList.DRESSCODE = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "scan" then DC.ScanCatalog(true) DC.Print("finding every wearable item again...")
	elseif msg == "journal" then DC.ScanJournal(true) DC.Print("reading the Encounter Journal again...")
	elseif msg == "probe" then probe()
	elseif msg == "ej" then DC.JournalReport()
	elseif msg == "dungeons" then DC.DungeonReport()
	elseif msg == "minimap" then DC.ToggleMinimapButton()
	else DC.Toggle() end
end

DC.OnInit = function()
	if not RaccoonboxOptions then return end
	RaccoonboxOptions.AddPanel({
		name = "Dress Code",
		about = "Game fashion and gear. Find the gear that beats what you wear (tick the stats you want more of), "
			.. "see where it comes from, and dress your character in two outfits on a stage of your choice: colours, "
			.. "homelands or the art of any dungeon and raid. Learns quest rewards as you play and shares them with "
			.. "other Dress Code players you meet.",
		commands = {
			{ "/dresscode", "open or close Dress Code" },
			{ "/dresscode probe", "what your game client offers, and how much Dress Code has read" },
			{ "/dresscode scan", "find every wearable item again (after a patch it happens by itself)" },
			{ "/dresscode journal", "read the Encounter Journal again" },
			{ "/dresscode minimap", "hide or show Dress Code's minimap button" },
		},
		build = function(b)
			-- close Options first: closing Options later would also close Dress Code
			b:Buttons({ { "Open Dress Code", function()
				if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
				C_Timer.After(0, function() if not (f and f:IsShown()) then DC.Toggle() end end)
			end } })
			b:Check("Show \"Dress Code:\" on item tooltips", "Every gear tooltip shows how it compares with what you wear.",
				function() return DressCodeDB.tooltip end, function(v) DressCodeDB.tooltip = v end)
			b:Check("Try items on while hovering them", "Hovering an item in the list puts it on your character for a moment.",
				function() return DressCodeDB.preview ~= false end, function(v) DressCodeDB.preview = v end)
			b:Check("Share learned quests with other Dress Code players",
				"Quests you open teach Dress Code which gear they give; this shares them in battlegrounds, groups and your guild.",
				function() return DressCodeDB.share end, function(v) DressCodeDB.share = v end)
			b:Choice("Window colours (applies after /reload):", { { "dark", "Dark" }, { "light", "Light" } },
				function() return DressCodeDB.theme or "dark" end, function(v) DressCodeDB.theme = v end)
		end,
	})
end

---------------------------------------------------------------------------- minimap button
-- Dress Code's own button (the shared Raccoonbox button opens the settings pages instead).
-- Click: open / close Dress Code. Right-click: its settings page. Drag: move it around the minimap.
local mm
local function place_minimap()
	local a = math.rad(DressCodeDB.minimap or 160)
	local r = Minimap:GetWidth() / 2 + 10
	mm:ClearAllPoints()
	mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function make_minimap()
	if mm or not Minimap then return end
	mm = CreateFrame("Button", "DressCodeMinimapButton", Minimap)
	mm:SetSize(31, 31)
	mm:SetFrameStrata("MEDIUM")
	mm:SetFrameLevel(8)
	mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	mm:RegisterForDrag("LeftButton")
	local icon = mm:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\INV_Chest_Cloth_04")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER", mm, "TOPLEFT", 16.5, -15.5)
	if icon.SetMask then icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
	local border = mm:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	local dragged
	mm:SetScript("OnMouseDown", function() dragged = false end)
	mm:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local s = Minimap:GetEffectiveScale()
			DressCodeDB.minimap = math.deg(math.atan2(cy / s - my, cx / s - mx))
			place_minimap()
		end)
	end)
	mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) dragged = true end)
	mm:SetScript("OnClick", function(_, button)
		if dragged then dragged = false return end
		GameTooltip:Hide()
		if button == "RightButton" and RaccoonboxOptions then RaccoonboxOptions.Open("Dress Code") else DC.Toggle() end
	end)
	mm:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("|cffff9900Dress Code|r")
		GameTooltip:AddLine("Click: open / close", 0.6, 1, 0.6)
		GameTooltip:AddLine("Right-click: settings", 0.6, 1, 0.6)
		GameTooltip:AddLine("Drag: move button", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	mm:SetScript("OnLeave", GameTooltip_Hide)
	place_minimap()
	mm:SetShown(not DressCodeDB.hideMinimap)
end

local mm_events = CreateFrame("Frame")
mm_events:RegisterEvent("PLAYER_LOGIN")
mm_events:SetScript("OnEvent", function() pcall(make_minimap) end)

function DC.ToggleMinimapButton()
	DressCodeDB.hideMinimap = not DressCodeDB.hideMinimap or nil
	if mm then mm:SetShown(not DressCodeDB.hideMinimap) end
	DC.Print("minimap button " .. (DressCodeDB.hideMinimap and "hidden (/dresscode minimap shows it again)." or "shown."))
end
