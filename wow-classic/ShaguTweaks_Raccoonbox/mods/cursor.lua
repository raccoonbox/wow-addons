local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T

local CURSOR = "Interface\\Cursor\\"

local shake = ShaguTweaks:register({
  title = T["Shake To Find Cursor"],
  description = T["Quickly shake the mouse to temporarily enlarge the cursor."],
  expansions = { ["vanilla"] = true, ["tbc"] = true },
  category = T["General"],
  enabled = true,
})

-- guess the cursor the game currently shows
local function TooltipLine(i)
  local line = _G["GameTooltipTextLeft" .. i]
  return line and line:IsShown() and line:GetText() or nil
end

local function TooltipHas(word)
  for i = 1, GameTooltip:NumLines() do
    local text = TooltipLine(i)
    if text and strfind(text, word) then return true end
  end
end

local function Unable(name, unit)
  if unit and not CheckInteractDistance(unit, 3) then
    return "Unable" .. name
  end
  return name
end

local function GetCursorName()
  if SpellIsTargeting() then return "Cast" end

  -- interface frames show the default cursor (nameplates belong to the world)
  local frame = GetMouseFocus()
  while frame and frame ~= WorldFrame do
    if frame == UIParent then return "Point" end
    frame = frame:GetParent()
  end

  if UnitExists("mouseover") then
    if UnitIsDead("mouseover") then
      if not UnitIsPlayer("mouseover") and UnitIsTappedByPlayer("mouseover") then
        return Unable("Pickup", "mouseover")
      end
      return "Point"
    elseif UnitCanAttack("player", "mouseover") then
      return "Attack"
    elseif UnitIsPlayer("mouseover") or UnitPlayerControlled("mouseover") then
      return "Point"
    end

    -- friendly npc: read the <subtitle> from the tooltip
    local subtitle = TooltipLine(2)
    if subtitle and strfind(subtitle, "^<") then
      if strfind(subtitle, "Flight Master") or strfind(subtitle, "Gryphon Master")
        or strfind(subtitle, "Wind Rider Master") or strfind(subtitle, "Hippogryph Master")
        or strfind(subtitle, "Bat Handler") then
        return Unable("Taxi", "mouseover")
      elseif strfind(subtitle, "Innkeeper") then
        return Unable("Innkeeper", "mouseover")
      elseif strfind(subtitle, "Trainer") then
        return Unable("Trainer", "mouseover")
      elseif strfind(subtitle, "Repair") then
        return Unable("Repair", "mouseover")
      end
      return Unable("Buy", "mouseover")
    end
    return Unable("Speak", "mouseover")
  end

  -- world objects (herbs, ore, chests, mailboxes, ...)
  if GameTooltip:IsShown() and GameTooltip:GetAlpha() > .99 and GameTooltip:NumLines() > 0 then
    if TooltipHas("Herbalism") then return "Gatherherbs"
    elseif TooltipHas("Mining") then return "Mine"
    elseif TooltipHas("Locked") or TooltipHas("Lockpicking") then return "PickLock"
    elseif TooltipHas("Mailbox") then return "Mail"
    end
    return "Interact"
  end

  return "Point"
end

-- size of one hardware cursor in screen units
local function GetBaseSize()
  local _, _, height = strfind(GetCVar("gxResolution") or "", "%d+x(%d+)")
  height = tonumber(height) or 768
  return 32 * WorldFrame:GetHeight() / height
end

local cursor = CreateFrame("Frame", nil)
cursor:SetFrameStrata("TOOLTIP")
cursor:SetFrameLevel(128)
cursor:Hide()
cursor.tex = cursor:CreateTexture(nil, "OVERLAY")
cursor.tex:SetAllPoints()

-- fall back to the plain or default cursor if a texture is missing
local checks = true
local function SetCursorTexture(name)
  if cursor.tex:SetTexture(CURSOR .. name) or not checks then return end

  -- client doesn't report texture success at all: trust the name
  if not cursor.tex:SetTexture(CURSOR .. "Point") then
    checks = nil
    cursor.tex:SetTexture(CURSOR .. name)
    return
  end

  local plain = string.gsub(name, "^Unable", "")
  if plain ~= name and cursor.tex:SetTexture(CURSOR .. plain) then return end
  cursor.tex:SetTexture(CURSOR .. "Point")
end

local driver = CreateFrame("Frame")
driver.scale = 1
driver.reversals = {}
driver.seglen = 0

driver:SetScript("OnUpdate", function()
  local now = GetTime()
  local dt = now - (this.last or now)
  this.last = now

  local x, y = GetCursorPosition()
  local base = GetBaseSize()

  -- shake detection: count fast direction changes within one second
  if this.shake then
    local dx = x - (this.x or x)
    if dx ~= 0 then
      local dir = dx > 0 and 1 or -1
      if dir ~= this.dir then
        if this.seglen > base * 1.5 then table.insert(this.reversals, now) end
        this.seglen = 0
        this.dir = dir
      end
      this.seglen = this.seglen + math.abs(dx)
    end

    while this.reversals[1] and now - this.reversals[1] > 1 do
      table.remove(this.reversals, 1)
    end

    if table.getn(this.reversals) >= 4 then this.shaking = now end
  end
  this.x = x

  -- grow fast while shaking, shrink slowly afterwards
  local target = 1
  if this.shaking and now - this.shaking < .6 then target = math.max(target, 4) end
  if this.scale < target then
    this.scale = math.min(target, this.scale + dt * 12)
  else
    this.scale = math.max(target, this.scale - dt * 4)
  end

  -- keep the real cursor while dragging items or turning the camera
  if this.scale <= 1.01 or IsMouselooking() or CursorHasItem() or CursorHasSpell() or CursorHasMoney() then
    cursor:Hide()
    return
  end

  local name = GetCursorName()
  if cursor.name ~= name then
    cursor.name = name
    SetCursorTexture(name)
  end

  local size = base * this.scale
  cursor:SetWidth(size)
  cursor:SetHeight(size)
  cursor:ClearAllPoints()
  cursor:SetPoint("TOPLEFT", WorldFrame, "BOTTOMLEFT", x, y)
  cursor:Show()
end)

shake.enable = function(self)
  driver.shake = true
end
