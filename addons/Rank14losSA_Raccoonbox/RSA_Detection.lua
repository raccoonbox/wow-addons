--[[
RSA_Detection.lua - Nampower Detection and Event Handling
Part of Rank14losSA addon

Replaces SuperWoW (UNIT_CASTEVENT + tooltip scanning) with:
  - SPELL_GO_OTHER   → buff detection + item use detection
  - SPELL_START_OTHER → cast detection (target = player)
  - AURA_CAST_ON_OTHER → buff on friendly (debuff detection replacement)
  - BUFF_REMOVED_OTHER → fade detection
  - DEBUFF_ADDED_OTHER → debuff on friendly player
  Requires NP_EnableSpellGoEvents=1
]]

local GetTime = GetTime

-- Cooldown settings
local COOLDOWN_BUFF  = 2.0
local COOLDOWN_DEBUFF = 1.0
local COOLDOWN_FADE  = 3.0
local COOLDOWN_USE   = 0.5

RSA_NP = {
  enabled     = false,
  debugMode   = false,
  inInstance  = false,
  lastAlerts  = {},
  lastCleanup = 0,
  CLEANUP_INTERVAL = 30,
}

--[[===========================================================================
  Icon Helper
=============================================================================]]

local function GetIconPath(tex)
  if not tex then return "Interface\\Icons\\INV_Misc_QuestionMark" end
  if string.find(tex, "\\") then return tex end
  return "Interface\\Icons\\" .. tex
end

local function GetSpellIcon(spellId)
  if not spellId or not GetSpellRecField then return nil end
  local iconId = GetSpellRecField(spellId, "spellIconID")
  if not iconId then return nil end
  local tex = GetSpellIconTexture(iconId)
  return tex and GetIconPath(tex) or nil
end

local function GetItemIcon(itemId)
  if not itemId or itemId == 0 then return nil end
  if not GetItemStatsField then return nil end
  local dispId = GetItemStatsField(itemId, "displayInfoID")
  if not dispId then return nil end
  local tex = GetItemIconTexture(dispId)
  return tex and GetIconPath(tex) or nil
end

-- Returns best icon: item icon preferred for item-triggered casts, else spell icon
function RSA_GetIcon(spellId, itemId)
  if itemId and itemId ~= 0 then
    local icon = GetItemIcon(itemId)
    if icon then return icon end
  end
  return GetSpellIcon(spellId) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

--[[===========================================================================
  Distance Check (UnitXP)
=============================================================================]]

local UnitXP_GetDistance = nil
local distanceCheckAvailable = false

function InitializeDistanceCheck()
  if UnitXP_GetDistance then return true end
  if not UnitXP then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[RSA]|r UnitXP not found - range limited to ~10yd or ~28yd interact checks")
    return false
  end
  local success, result = pcall(function()
    return UnitXP and UnitXP("distanceBetween", "player", "player")
  end)
  if success and type(result) == "number" then
    UnitXP_GetDistance = function(unit1, unit2)
      return UnitXP("distanceBetween", unit1, unit2)
    end
    distanceCheckAvailable = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RSA]|r UnitXP distance check ACTIVE (" .. RSA_GetMaxRange() .. "yd limit, /rsa range <yards>)")
    return true
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[RSA]|r UnitXP not available - range limited to ~10yd or ~28yd interact checks")
  return false
end

function RSA_GetMaxRange()
  return (RSAConfig and tonumber(RSAConfig.range)) or 40
end

local function IsWithinRange(guid, maxYards)
  if not guid or not UnitExists(guid) then return false end
  if distanceCheckAvailable then
    local success, distance = pcall(function()
      return UnitXP_GetDistance("player", guid)
    end)
    if success and distance then return distance <= maxYards end
    return false
  end
  -- fallback without UnitXP: duel distance (~10yd) or follow distance (~28yd)
  local success, inRange = pcall(CheckInteractDistance, guid, maxYards <= 10 and 3 or 4)
  if success then return inRange and true or false end
  return true
end

--[[===========================================================================
  Helper Functions
=============================================================================]]

local function IsEnemy(guid)
  if not UnitExists(guid) then return false end
  if not UnitIsPlayer(guid) then return false end
  local classification = UnitClassification(guid)
  if classification == "elite" or classification == "worldboss"
  or classification == "rare" or classification == "rareelite" then
    return false
  end
  return UnitCanAttack("player", guid)
end

local function IsFriendly(guid)
  if not UnitExists(guid) then return false end
  if not UnitIsPlayer(guid) then return false end
  local classification = UnitClassification(guid)
  if classification == "elite" or classification == "worldboss"
  or classification == "rare" or classification == "rareelite" then
    return false
  end
  return not UnitCanAttack("player", guid)
end

local function CanAlert(guid, ability, alertType)
  if not IsWithinRange(guid, RSA_GetMaxRange()) then return false end
  local now = GetTime()
  if not RSA_NP.lastAlerts[guid] then
    RSA_NP.lastAlerts[guid] = {}
  end
  local lastAlert = RSA_NP.lastAlerts[guid][ability]
  local cooldown = COOLDOWN_BUFF
  if alertType == "use"    then cooldown = COOLDOWN_USE
  elseif alertType == "debuff" then cooldown = COOLDOWN_DEBUFF
  elseif alertType == "fade"   then cooldown = COOLDOWN_FADE
  end
  if lastAlert and (now - lastAlert) < cooldown then return false end
  RSA_NP.lastAlerts[guid][ability] = now
  return true
end

--[[===========================================================================
  Memory Cleanup
=============================================================================]]

function RSA_NP:CleanupMemory()
  local now = GetTime()
  for guid, abilities in pairs(self.lastAlerts) do
    for ability, timestamp in pairs(abilities) do
      if now - timestamp > 60 then
        abilities[ability] = nil
      end
    end
    if not next(abilities) then
      self.lastAlerts[guid] = nil
    end
  end
  self.lastCleanup = now
end

--[[===========================================================================
  Instance Check
=============================================================================]]

function RSA_NP:UpdateInstanceStatus()
  local inInstance, instanceType = IsInInstance()
  local zone = GetZoneText()
  local isWinterVeilVale = (zone == "Winter Veil Vale")
  if inInstance and not isWinterVeilVale
  and (instanceType == "party" or instanceType == "raid") then
    self.inInstance = true
  else
    self.inInstance = false
  end
end

--[[===========================================================================
  Alert trigger
=============================================================================]]

local function FireAlert(configKey, casterGuid, spellId, itemId, castDuration)
  local casterName = UnitName(casterGuid) or "Unknown"
  RSA_PlaySoundFile(configKey, casterName, casterGuid, castDuration, spellId, itemId)
end

-- Active cast tracking: casterGuid -> spellId (set on SPELL_START_OTHER, cleared on SPELL_GO_OTHER or SPELL_FAILED_OTHER)
local activeCasts = {}

--[[===========================================================================
  SPELL_GO_OTHER → Buffs + Item Uses
=============================================================================]]

local function OnSpellGoOther(spellId, itemId, casterGuid, targetGuid)
  -- Clear active cast
  activeCasts[casterGuid] = nil

  if RSA_NP.inInstance then return end
  if not spellId or not casterGuid then return end
  if not UnitIsPlayer(casterGuid) then return end

  local now = GetTime()
  if now - RSA_NP.lastCleanup > RSA_NP.CLEANUP_INTERVAL then
    RSA_NP:CleanupMemory()
  end

  -- Item use detection (itemId != 0)
  if itemId and itemId ~= 0 then
    local useConfigKey = RSA_USE_ITEM_IDS and RSA_USE_ITEM_IDS[itemId]
    if useConfigKey then
      if IsEnemy(casterGuid) and RSAConfig.use
      and RSAConfig.use.enabled and RSAConfig.use[useConfigKey]
      and CanAlert(casterGuid, useConfigKey, "use") then
        FireAlert(useConfigKey, casterGuid, spellId, itemId, nil)
      end
      return
    end
  end

  -- Buff detection via spellId
  local buffConfigKey = RSA_BUFF_SPELL_IDS[spellId]
  if buffConfigKey then
    if IsEnemy(casterGuid) and RSAConfig.buffs
    and RSAConfig.buffs.enabled and RSAConfig.buffs[buffConfigKey]
    and CanAlert(casterGuid, buffConfigKey, "buff") then
      FireAlert(buffConfigKey, casterGuid, spellId, itemId, nil)
    end
    return
  end

  -- Ability use detection via spellId (instant abilities, interrupts etc.)
  local useConfigKey = RSA_USE_SPELL_IDS[spellId]
  if useConfigKey then
    if IsEnemy(casterGuid) and RSAConfig.use
    and RSAConfig.use.enabled and RSAConfig.use[useConfigKey]
    and CanAlert(casterGuid, useConfigKey, "use") then
      FireAlert(useConfigKey, casterGuid, spellId, itemId, nil)
    end
    return
  end
end

--[[===========================================================================
  SPELL_START_OTHER → Cast detection (only if targeting player)
=============================================================================]]

local function OnSpellStartOther(spellId, casterGuid, targetGuid, castTime)
  -- Track active cast
  if casterGuid and spellId then
    activeCasts[casterGuid] = spellId
  end

  if RSA_NP.inInstance then return end
  if not spellId or not casterGuid then return end
  if not IsEnemy(casterGuid) then return end

  local _, playerGuid = UnitExists("player")
  if targetGuid ~= playerGuid then return end

  local castConfigKey = RSA_CAST_SPELL_IDS[spellId]
  if not castConfigKey then return end
  if not RSAConfig.casts or not RSAConfig.casts.enabled then return end
  if not RSAConfig.casts[castConfigKey] then return end

  FireAlert(castConfigKey, casterGuid, spellId, nil, castTime)
end

--[[===========================================================================
  BUFF_REMOVED_OTHER → Fade detection
=============================================================================]]

local function OnBuffRemovedOther(guid, spellId)
  if RSA_NP.inInstance then return end
  if not IsEnemy(guid) then return end
  if not spellId then return end

  local buffConfigKey = RSA_BUFF_SPELL_IDS[spellId]
  if not buffConfigKey then return end
  if not RSAConfig.fadingBuffs or not RSAConfig.fadingBuffs.enabled then return end
  if not RSAConfig.fadingBuffs[buffConfigKey] then return end
  if not CanAlert(guid, buffConfigKey .. "_fade", "fade") then return end

  FireAlert(buffConfigKey .. "down", guid, spellId, nil, nil)
end

--[[===========================================================================
  DEBUFF_ADDED_OTHER → Debuff on friendly player
=============================================================================]]

local function OnDebuffAddedOther(guid, luaSlot, spellId)
  if RSA_NP.inInstance then return end
  if not IsFriendly(guid) then return end
  if not spellId then return end

  local debuffConfigKey = RSA_DEBUFF_SPELL_IDS and RSA_DEBUFF_SPELL_IDS[spellId]
  if not debuffConfigKey then return end
  if not RSAConfig.debuffs or not RSAConfig.debuffs.enabled then return end
  if not RSAConfig.debuffs[debuffConfigKey] then return end
  if not CanAlert(guid, debuffConfigKey, "debuff") then return end

  FireAlert(debuffConfigKey, guid, spellId, nil, nil)
end

--[[===========================================================================
  SPELL_FAILED_OTHER → Cast cancelled/interrupted
=============================================================================]]

local function OnSpellFailedOther(casterGuid, spellId)
  if not casterGuid then return end
  -- Only cancel if we were actually tracking this cast
  if activeCasts[casterGuid] then
    activeCasts[casterGuid] = nil
    RSA_CancelCast(casterGuid)
  end
end

--[[===========================================================================
  Initialization
=============================================================================]]

function RSA_NP:Initialize()
  if not RSAConfig then return false end
  if not GetNampowerVersion then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RSA]|r Nampower not found!")
    return false
  end

  if GetCVar("NP_EnableSpellGoEvents") ~= "1" then
    SetCVar("NP_EnableSpellGoEvents", "1")
  end

  self.enabled = true

  local f = CreateFrame("Frame")
  f:RegisterEvent("SPELL_GO_OTHER")
  f:RegisterEvent("SPELL_START_OTHER")
  f:RegisterEvent("SPELL_FAILED_OTHER")
  f:RegisterEvent("BUFF_REMOVED_OTHER")
  f:RegisterEvent("DEBUFF_ADDED_OTHER")
  f:SetScript("OnEvent", function()
    if not RSA_NP.enabled then return end
    if event == "SPELL_GO_OTHER" then
      OnSpellGoOther(arg2, arg1, arg3, arg4)
    elseif event == "SPELL_START_OTHER" then
      OnSpellStartOther(arg2, arg3, arg4, arg6)
    elseif event == "SPELL_FAILED_OTHER" then
      -- arg1=casterGuid, arg2=spellId
      OnSpellFailedOther(arg1, arg2)
    elseif event == "BUFF_REMOVED_OTHER" then
      OnBuffRemovedOther(arg1, arg3)
    elseif event == "DEBUFF_ADDED_OTHER" then
      OnDebuffAddedOther(arg1, arg2, arg3)
    end
  end)

  local a, b, c = GetNampowerVersion()
  DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[RSA]|r Nampower v%d.%d.%d active", a, b, c))
  return true
end

function RSA_NP:Enable()
  self.enabled = true
end

function RSA_NP:Disable()
  self.enabled = false
end

--[[===========================================================================
  Zone / Instance Events
=============================================================================]]

local zoneFrame = CreateFrame("Frame")
zoneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
zoneFrame:RegisterEvent("ZONE_CHANGED")
zoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
zoneFrame:SetScript("OnEvent", function()
  RSA_NP:UpdateInstanceStatus()
end)
