-- Plates Prima: raid target marker (skull, cross, ...) on the target and target-of-target frames.
-- The OctoWoW target frame has its own marker, but it only shows some of the time. Ours sits on the
-- same spot (on top of the round portrait) and the original is made invisible so there's never two.
-- Adjust with /platesprima (or /platesp) marker left|right|up|down [pixels].
ShaguPlates:RegisterModule("targetmarker", "vanilla", function ()
  if not TargetFrame or not GetRaidTargetIndex then return end

  -- the client's own target frame marker: we take its spot and hide it
  local native = _G.TargetRaidTargetIcon or _G.TargetFrameRaidTargetIcon or _G.TargetFrameTextureFrameRaidTargetIcon
  if native then native:SetAlpha(0) end

  -- offsets from the original marker's centre, or (if the client has none) from the frame's top right
  local DEFAULT = native and { x = 0, y = 4, size = 24 } or { x = -71, y = 1, size = 24 }
  local KEY = native and "marker_native" or "marker"

  local function settings()
    _G.PlatesPrima_db = _G.PlatesPrima_db or {}
    _G.PlatesPrima_db[KEY] = _G.PlatesPrima_db[KEY] or { x = DEFAULT.x, y = DEFAULT.y, size = DEFAULT.size }
    return _G.PlatesPrima_db[KEY]
  end

  local function create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetFrameLevel(parent:GetFrameLevel() + 10)
    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.icon:SetAllPoints(frame)
    frame.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    frame:Hide()
    return frame
  end

  local target = create(TargetFrame)
  local tot = TargetofTargetFrame and create(TargetofTargetFrame)

  local function place()
    local s = settings()
    target:ClearAllPoints()
    if native then
      target:SetPoint("CENTER", native, "CENTER", s.x, s.y)
    else
      target:SetPoint("CENTER", TargetFramePortrait or TargetFrame, "TOPRIGHT", s.x, s.y)
    end
    target:SetWidth(s.size)
    target:SetHeight(s.size)
    if tot then
      tot:ClearAllPoints()
      tot:SetPoint("BOTTOM", TargetofTargetPortrait or TargetofTargetFrame, "TOP", 0, 1)
      tot:SetWidth(14)
      tot:SetHeight(14)
    end
  end

  local markers = { { unit = "target", frame = target } }
  if tot then tinsert(markers, { unit = "targettarget", frame = tot }) end

  local function update()
    for _, m in pairs(markers) do
      local index = UnitExists(m.unit) and GetRaidTargetIndex(m.unit)
      if index then
        SetRaidTargetIconTexture(m.frame.icon, index)
        m.frame:Show()
      else
        m.frame:Hide()
      end
    end
  end

  place()

  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("RAID_TARGET_UPDATE")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:SetScript("OnEvent", update)

  -- target-of-target changes without an event in 1.12: check a few times per second
  local elapsed = 0
  events:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1
    if elapsed < .25 then return end
    elapsed = 0
    update()
  end)

  _G.SLASH_PLATESPRIMA1 = "/platesprima"
  _G.SLASH_PLATESPRIMA2 = "/platesp"
  -- size of one screen pixel in the target frame's coordinates
  local function pixel()
    local _, _, height = string.find(GetCVar("gxResolution") or "", "%d+x(%d+)")
    height = tonumber(height) or GetScreenHeight()
    return 768 / height / TargetFrame:GetEffectiveScale()
  end

  _G.SlashCmdList.PLATESPRIMA = function(msg)
    local _, _, cmd, a, b, c = string.find(msg or "", "^(%S*)%s*(%S*)%s*(%S*)%s*(%S*)")
    local s = settings()
    local say = function(text) DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccPlates Prima:|r " .. text) end
    if cmd == "marker" and a == "reset" then
      s.x, s.y, s.size = DEFAULT.x, DEFAULT.y, DEFAULT.size
    elseif cmd == "marker" and tonumber(a) and tonumber(b) then
      s.x, s.y = tonumber(a), tonumber(b)
      if tonumber(c) then s.size = tonumber(c) end
    elseif cmd == "marker" and (a == "left" or a == "right" or a == "up" or a == "down") then
      -- the step is in screen pixels: convert to the target frame's own units
      local step = (tonumber(b) or 5) * pixel()
      if a == "left" then s.x = s.x - step elseif a == "right" then s.x = s.x + step
      elseif a == "up" then s.y = s.y + step else s.y = s.y - step end
      s.x, s.y = floor(s.x * 100 + .5) / 100, floor(s.y * 100 + .5) / 100
    elseif cmd == "" then
      -- no arguments: open/close the settings window
      SlashCmdList.SHAGUPLATES("")
      return
    else
      say("/platesprima or /platesp  - open the settings")
      say("/platesp marker left|right|up|down [pixels]  - nudge the target frame raid marker (default 5 pixels)")
      say("/platesp marker <x> <y> [size]  - set it exactly (now " .. s.x .. " " .. s.y .. " " .. s.size .. ")")
      say("/platesp marker reset  - back to default")
      return
    end
    place()
    say("raid marker at " .. s.x .. " " .. s.y .. ", size " .. s.size
      .. (native and " (relative to the game's own marker spot)" or " (relative to the target frame corner)"))
  end
end)
