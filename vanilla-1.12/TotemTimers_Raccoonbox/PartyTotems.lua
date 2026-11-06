--[[
PartyTotems.lua - shows totems dropped by shamans in your party (Raccoonbox)
Each party shaman gets a row of icons below the TotemTimers buttons.
Requires Nampower (SPELL_GO_OTHER, GUIDs from UnitExists).
Commands: /ttparty on | off
]]

local ELEMENT = {
  ["Earthbind"] = "Earth", ["Stoneclaw"] = "Earth", ["Stoneskin"] = "Earth",
  ["Strength of Earth"] = "Earth", ["Tremor"] = "Earth",
  ["Searing"] = "Fire", ["Fire Nova"] = "Fire", ["Magma"] = "Fire",
  ["Flametongue"] = "Fire", ["Frost Resistance"] = "Fire",
  ["Healing Stream"] = "Water", ["Mana Spring"] = "Water", ["Mana Tide"] = "Water",
  ["Poison Cleansing"] = "Water", ["Disease Cleansing"] = "Water", ["Fire Resistance"] = "Water",
  ["Grace of Air"] = "Air", ["Grounding"] = "Air", ["Nature Resistance"] = "Air",
  ["Windfury"] = "Air", ["Windwall"] = "Air", ["Sentry"] = "Air", ["Tranquil Air"] = "Air",
}

-- same sizes as the TotemTimers buttons and their time text
local ICON_SIZE = 30
local ROW_HEIGHT = ICON_SIZE + 16

local party = {}    -- guid -> unit name of party members
local shamans = {}  -- guid -> { name = "", totems = { [element] = { name, icon, expires } } }

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff7f7fff[Party Totems]|r " .. msg)
end

local function GetGuid(unit)
  local exists, guid = UnitExists(unit)
  return exists and guid or nil
end

local function GetSpellIcon(spellId)
  if not GetSpellRecField or not GetSpellIconTexture then return nil end
  local iconId = GetSpellRecField(spellId, "spellIconID")
  local tex = iconId and GetSpellIconTexture(iconId)
  if not tex then return nil end
  if string.find(tex, "\\") then return tex end
  return "Interface\\Icons\\" .. tex
end

--[[ rows below the TotemTimers buttons ]]

local rows = {}

local function GetRow(r)
  if rows[r] then return rows[r] end

  local row = { icons = {} }
  for c = 1, 4 do
    local icon = CreateFrame("Frame", nil, UIParent)
    icon:SetFrameStrata("LOW")
    icon:SetWidth(ICON_SIZE)
    icon:SetHeight(ICON_SIZE)
    icon:SetPoint("TOP", getglobal("TotemTimer" .. c), "BOTTOM", 0, -16 - (r - 1) * ROW_HEIGHT)
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetAllPoints()
    icon.time = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icon.time:SetWidth(36)
    icon.time:SetPoint("CENTER", icon, "CENTER", -1, -20)
    icon.time:SetTextColor(1, 1, 1)
    icon:Hide()
    row.icons[c] = icon
  end

  row.name = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.name:SetTextColor(0, .44, .87)
  row.name:SetJustifyH("LEFT")

  rows[r] = row
  return row
end

local function HideRow(row)
  for c = 1, 4 do row.icons[c]:Hide() end
  row.name:Hide()
end

-- each element keeps its own column, in the same order and alignment as TotemTimers
local function ShowRow(row, shaman, now)
  local order = TTData and TTData[TT_ORDER] or { TT_AIR, TT_WATER, TT_FIRE, TT_EARTH }
  local left = not TTData or TTData[TT_ALIGN] == TT_LEFT

  HideRow(row)

  for num, element in pairs(order) do
    local totem = shaman.totems[element]
    local c = left and 5 - num or num
    if totem and c >= 1 and c <= 4 then
      local icon = row.icons[c]
      icon.tex:SetTexture(totem.icon)
      icon.time:SetText(TTData and TotemTimer_FormatTime and TotemTimer_FormatTime(totem.expires - now)
        or string.format("%02d:%02d", math.floor((totem.expires - now) / 60), math.mod(totem.expires - now, 60)))
      icon:Show()
    end
  end

  -- name on the right side of the row (TotemTimer1 is the rightmost button)
  row.name:ClearAllPoints()
  row.name:SetPoint("LEFT", row.icons[1], "RIGHT", 4, 0)
  row.name:SetText(shaman.name)
  row.name:Show()
end

local function Refresh()
  local now = GetTime()
  local r = 0

  for _, shaman in pairs(shamans) do
    local active
    for element, totem in pairs(shaman.totems) do
      if totem.expires <= now then shaman.totems[element] = nil else active = true end
    end

    if active then
      r = r + 1
      ShowRow(GetRow(r), shaman, now)
    end
  end

  for i = r + 1, table.getn(rows) do HideRow(rows[i]) end
end

--[[ tracking ]]

local function UpdateParty()
  for k in pairs(party) do party[k] = nil end
  for i = 1, 4 do
    local guid = GetGuid("party" .. i)
    if guid then party[guid] = UnitName("party" .. i) end
  end

  -- forget shamans that left the group
  for guid in pairs(shamans) do
    if not party[guid] then shamans[guid] = nil end
  end
end

local function OnSpellGo(spellId, casterGuid)
  if not party[casterGuid] or not GetSpellNameAndRankForId then return end

  local spell = GetSpellNameAndRankForId(spellId)
  local _, _, short = string.find(spell or "", "^(.+) Totem$")
  if not short then return end

  local data = TotemData and TotemData[short]
  local element = ELEMENT[short] or TT_FIRE

  shamans[casterGuid] = shamans[casterGuid] or { totems = {} }
  shamans[casterGuid].name = party[casterGuid]
  shamans[casterGuid].totems[element] = {
    name = short,
    icon = data and ("Interface\\Icons\\" .. data.icon) or GetSpellIcon(spellId) or "Interface\\Icons\\INV_Misc_QuestionMark",
    expires = GetTime() + (data and data.duration or 120),
  }
end

-- combat log has no owner, so only remove when the totem is unambiguous
local function OnTotemDeath(msg)
  local _, _, short = string.find(msg, "^(.+) Totem ?%a* is destroyed")
  if not short then return end

  local found, foundElement
  for _, shaman in pairs(shamans) do
    for element, totem in pairs(shaman.totems) do
      if totem.name == short then
        if found then return end
        found, foundElement = shaman, element
      end
    end
  end

  if found then found.totems[foundElement] = nil end
end

local events = CreateFrame("Frame")
events:RegisterEvent("VARIABLES_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PARTY_MEMBERS_CHANGED")
events:RegisterEvent("RAID_ROSTER_UPDATE")
events:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLY_DEATH")
events:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    TTPartyData = TTPartyData or {}
    if TTPartyData.enabled == nil then TTPartyData.enabled = true end

    if GetNampowerVersion then
      if GetCVar("NP_EnableSpellGoEvents") ~= "1" then SetCVar("NP_EnableSpellGoEvents", "1") end
      this:RegisterEvent("SPELL_GO_OTHER")
    else
      Print("Nampower not found - party totems disabled")
    end
  elseif event == "SPELL_GO_OTHER" then
    if TTPartyData.enabled then OnSpellGo(arg2, arg3) end
  elseif event == "CHAT_MSG_COMBAT_FRIENDLY_DEATH" then
    OnTotemDeath(arg1)
  else
    UpdateParty()
  end
end)

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
  if (this.tick or 0) > GetTime() then return end
  this.tick = GetTime() + .2
  if not TTPartyData then return end

  if TTPartyData.enabled then
    Refresh()
  else
    for i = 1, table.getn(rows) do HideRow(rows[i]) end
  end
end)

SLASH_TTPARTY1 = "/ttparty"
SlashCmdList["TTPARTY"] = function(msg)
  msg = string.lower(msg or "")
  if msg == "on" then
    TTPartyData.enabled = true
    Print("enabled")
  elseif msg == "off" then
    TTPartyData.enabled = false
    Print("disabled")
  else
    Print("/ttparty on | off")
  end
end
