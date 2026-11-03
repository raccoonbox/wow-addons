local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T

-- all tracking spells that can be cast from the spellbook
local tracking = {
  "Find Herbs", "Find Minerals", "Find Treasure", "Find Fish",
  "Sense Undead", "Sense Demons",
  "Track Beasts", "Track Humanoids", "Track Undead", "Track Hidden",
  "Track Elementals", "Track Demons", "Track Giants", "Track Dragonkin",
}

local function GetKnownSpells()
  local known = {}
  local i = 1
  while true do
    local name = GetSpellName(i, BOOKTYPE_SPELL)
    if not name then break end
    known[name] = true
    i = i + 1
  end
  return known
end

local function GetKnownTracking()
  local known = GetKnownSpells()
  local values = { { text = T["None"], value = "None" } }
  for _, spell in pairs(tracking) do
    if known[spell] then
      table.insert(values, { text = spell, value = spell })
    end
  end
  return values
end

-- the selected tracking, or the first known one when the selected spell
-- is no longer known (e.g. after switching from Herbalism to Mining)
local function GetSpellToCast()
  local spell = ShaguTweaks_config["autotracking"]
  if not spell or spell == "None" then return nil end

  local known = GetKnownSpells()
  if known[spell] then return spell end

  for _, fallback in pairs(tracking) do
    if known[fallback] then return fallback end
  end
end

local module = ShaguTweaks:register({
  title = T["Auto Tracking"],
  description = T["Keeps the selected tracking ability (Find Herbs, Find Minerals, ...) active: turns it back on after death, out of combat. Falls back to a known tracking ability if the selected one is not known."],
  expansions = { ["vanilla"] = true, ["tbc"] = true },
  category = T["General"],
  enabled = nil,
  dropdown = { key = "autotracking", default = "None", values = GetKnownTracking },
})

local function IsShapeshifted()
  for i = 1, GetNumShapeshiftForms() do
    local _, _, active = GetShapeshiftFormInfo(i)
    if active then return true end
  end
  return false
end

local function IsCasting()
  return CastingBarFrame and (CastingBarFrame.casting or CastingBarFrame.channeling)
end

local function IsOnCooldown(spell)
  local i = 1
  while true do
    local name = GetSpellName(i, BOOKTYPE_SPELL)
    if not name then return false end
    if name == spell then
      local start, duration = GetSpellCooldown(i, BOOKTYPE_SPELL)
      return start and start > 0 and duration and duration > 0
    end
    i = i + 1
  end
end

module.enable = function(self)
  -- Check every second instead of relying on resurrection events, which do
  -- not fire reliably for battleground spirit healers. Only cast out of
  -- combat so it never steals a global cooldown in a fight.
  local watcher = CreateFrame("Frame")
  watcher.next = 0
  watcher.fails = 0
  watcher:SetScript("OnUpdate", function()
    if this.next > GetTime() then return end
    this.next = GetTime() + 1

    if GetTrackingTexture() then
      this.fails = 0
      return
    end

    local spell = GetSpellToCast()
    if not spell then return end
    if UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then return end
    if UnitAffectingCombat("player") or IsShapeshifted() or IsCasting() then return end
    if IsOnCooldown(spell) then return end

    CastSpellByName(spell)

    -- if casting keeps failing, slow down instead of spamming errors
    this.fails = this.fails + 1
    this.next = GetTime() + (this.fails >= 3 and 30 or 3)
  end)
end
