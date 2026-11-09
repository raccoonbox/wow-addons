-- Dress Code [Raccoonbox] for WoW Forever - the stage behind the character. Game fashion: the character
-- must pop off the background, so the player picks what stands behind them:
--  * colours: the three primaries, the three secondaries, black, white, grey and a muddy brown-grey
--  * homelands: the game's own dressing-room paintings (Elwynn, Teldrassil, Mulgore, ...)
--  * dungeons & raids: the artwork of every Encounter Journal instance (Blackwing Lair, Molten Core, ...)
-- Nothing is drawn by us; everything comes from the game.
local _, DC = ...

-- name, top colour, bottom colour (a soft vertical gradient)
DC.STAGE_COLOURS = {
	{ "Red", { 0.62, 0.16, 0.14 }, { 0.22, 0.05, 0.05 } },
	{ "Yellow", { 0.78, 0.66, 0.25 }, { 0.36, 0.28, 0.08 } },
	{ "Blue", { 0.20, 0.34, 0.58 }, { 0.06, 0.10, 0.22 } },
	{ "Green", { 0.24, 0.46, 0.26 }, { 0.07, 0.16, 0.08 } },
	{ "Orange", { 0.80, 0.42, 0.14 }, { 0.32, 0.13, 0.04 } },
	{ "Purple", { 0.42, 0.24, 0.56 }, { 0.14, 0.07, 0.20 } },
	{ "Black", { 0.12, 0.12, 0.13 }, { 0.02, 0.02, 0.02 } },
	{ "White", { 0.96, 0.95, 0.93 }, { 0.74, 0.73, 0.71 } },
	{ "Grey", { 0.50, 0.50, 0.52 }, { 0.22, 0.22, 0.23 } },
	{ "Mud", { 0.44, 0.38, 0.30 }, { 0.17, 0.14, 0.10 } },
}

-- race file name, place it shows
DC.STAGE_HOMELANDS = {
	{ "Human", "Stormwind" }, { "NightElf", "Teldrassil" }, { "Dwarf", "Dun Morogh" }, { "Gnome", "Gnomeregan" },
	{ "Orc", "Durotar" }, { "Scourge", "Tirisfal Glades" }, { "Tauren", "Mulgore" }, { "Troll", "Echo Isles" },
}

-- stage key: "c:<colour>", "h:<race>", "i:<instance name>"
function DC.StageLabel(key)
	local kind, name = (key or ""):match("^(%a):(.+)$")
	if kind == "h" then
		for _, h in ipairs(DC.STAGE_HOMELANDS) do if h[1] == name then return h[2] end end
	end
	return name or "Grey"
end

-- dungeon/raid stages: Encounter Journal art when the client has a journal, else the pictures of the
-- game's dungeon list (group finder backgrounds); only pictures that exist
function DC.InstanceStages()
	local out, seen = {}, {}
	local j = DressCodeDB and DressCodeDB.journal
	for _, inst in ipairs(j and j.instances or {}) do
		if inst.art and inst.art ~= "" and inst.art ~= 0 then out[#out + 1] = inst seen[inst.name] = true end
	end
	local d = DressCodeDB and DressCodeDB.dungeons
	for name, e in pairs(d and d.list or {}) do
		if e.art and not seen[name] then out[#out + 1] = { name = name, art = e.art, raid = e.raid, wide = true } end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

-- builds the stage textures on a frame; returns a function that shows a stage by key
function DC.MakeStage(frame)
	local grad = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	grad:SetAllPoints()
	local art = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
	art:SetAllPoints()
	-- the old four-piece dressing-room paintings (top left/right, bottom left/right of a 320x384 picture)
	local tiles = {}
	for i = 1, 4 do tiles[i] = frame:CreateTexture(nil, "BACKGROUND", nil, 2) end
	-- sized from the stage's current size, and again whenever the stage changes size.
	-- The old dressing-room window hid the lower part of its bottom pieces behind its frame, so only their
	-- painted top part is used (BOTTOM_USE), and the picture is stretched to fill the stage top to bottom.
	local BOTTOM_USE, RIGHT_USE = 0.6, 62 / 64
	local function place_tiles()
		local w, h = frame:GetWidth(), frame:GetHeight()
		if not w or w < 10 then return end
		local lw = w * 256 / (256 + 64 * RIGHT_USE)
		local th = h * 256 / (256 + 128 * BOTTOM_USE)
		tiles[1]:SetTexCoord(0, 1, 0, 1)
		tiles[2]:SetTexCoord(0, RIGHT_USE, 0, 1)
		tiles[3]:SetTexCoord(0, 1, 0, BOTTOM_USE)
		tiles[4]:SetTexCoord(0, RIGHT_USE, 0, BOTTOM_USE)
		for _, t in ipairs(tiles) do t:ClearAllPoints() end
		tiles[1]:SetPoint("TOPLEFT") tiles[1]:SetSize(lw, th)
		tiles[2]:SetPoint("TOPLEFT", tiles[1], "TOPRIGHT") tiles[2]:SetSize(w - lw, th)
		tiles[3]:SetPoint("TOPLEFT", tiles[1], "BOTTOMLEFT") tiles[3]:SetSize(lw, h - th)
		tiles[4]:SetPoint("TOPLEFT", tiles[3], "TOPRIGHT") tiles[4]:SetSize(w - lw, h - th)
	end
	frame:HookScript("OnSizeChanged", place_tiles)

	-- dungeon pictures (the game's old loading screens): the scene sits inside an ornate frame in the
	-- upper part of the file. Show a window centred on the scene, just inside that frame, in the stage's
	-- own proportions (nothing stretched). ART_CX/CY = scene centre, ART_H = window height (file units).
	local ART_CX, ART_CY, ART_H = 0.5, 0.33, 0.46
	local function place_art()
		if not art.wide then art:SetTexCoord(0.15, 0.85, 0, 1) return end
		local w, h = frame:GetWidth(), frame:GetHeight()
		if not w or w < 10 or not h or h < 10 then return end
		local tw = math.min(1, ART_H * w / h)
		art:SetTexCoord(ART_CX - tw / 2, ART_CX + tw / 2, ART_CY - ART_H / 2, ART_CY + ART_H / 2)
	end
	frame:HookScript("OnSizeChanged", function() if art:IsShown() then place_art() end end)
	-- a soft shade at the bottom so feet stand on something
	local floor = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
	floor:SetPoint("BOTTOMLEFT") floor:SetPoint("BOTTOMRIGHT") floor:SetHeight(90)
	floor:SetColorTexture(1, 1, 1, 1)
	pcall(floor.SetGradient, floor, "VERTICAL", CreateColor(0, 0, 0, 0.45), CreateColor(0, 0, 0, 0))

	local function gradient(top, bottom)
		grad:SetColorTexture(1, 1, 1, 1)
		local ok = pcall(grad.SetGradient, grad, "VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], 1),
			CreateColor(top[1], top[2], top[3], 1))
		if not ok then grad:SetColorTexture(top[1], top[2], top[3], 1) end
	end

	return function(key)
		local kind, name = (key or "c:Grey"):match("^(%a):(.+)$")
		art:Hide()
		for _, t in ipairs(tiles) do t:Hide() end
		gradient({ 0.30, 0.30, 0.31 }, { 0.10, 0.10, 0.11 })
		if kind == "c" then
			for _, c in ipairs(DC.STAGE_COLOURS) do
				if c[1] == name then gradient(c[2], c[3]) end
			end
		elseif kind == "h" then
			-- the modern atlas if the client has it, else the classic four-piece painting
			local atlas = "dressingroom-background-" .. name:lower()
			if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
				art:SetAtlas(atlas)
				art.wide = nil
				art:SetTexCoord(0, 1, 0, 1)
				art:Show()
			else
				for i, t in ipairs(tiles) do
					t:SetTexture("Interface\\DressUpFrame\\DressUpBackground-" .. name .. i)
					t:Show()
				end
				place_tiles() -- after the textures: sizes and the cropping of the bottom pieces
			end
		elseif kind == "i" then
			for _, inst in ipairs(DC.InstanceStages()) do
				if inst.name == name then
					art:SetTexture(inst.art)
					art.wide = inst.wide
					place_art()
					art:Show()
				end
			end
		end
	end
end
