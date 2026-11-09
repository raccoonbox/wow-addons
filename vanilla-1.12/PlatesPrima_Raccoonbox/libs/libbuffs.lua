-- load ShaguPlates environment
setfenv(1, ShaguPlates:GetEnvironment())

--[[ libbuffs (Plates Prima) ]]--
-- Knows the buffs of players and NPCs around you, for the buff row above nameplates.
--  * live: reads UnitBuff on your target and mouseover (the 1.12 client allows nothing else)
--  * combat log: "X gains Y." / "Y fades from X." keeps enemy players' buffs up to date while
--    they are in combat log range, even when they are not your target
--  * icons: learned from every buff you see (saved), with a built-in list for big PvP buffs
--  * purge alerts: after you cast Purge / Dispel Magic / Devour Magic, shows what was removed
--
--  libbuffs:GetBuffs(name, unitstr, isplayer)
--    returns a list of { name, texture, stacks, magic, ends } for the unit, or nil

if ShaguPlates.client > 11200 then return end
if ShaguPlates.api.libbuffs then return end

local libbuffs = CreateFrame("Frame", "PlatesPrimaBuffs", UIParent)
local scanner = libtipscan:GetScanner("libbuffs")
local ICON = "Interface\\Icons\\"
local UNKNOWN_ICON = ICON .. "INV_Misc_QuestionMark"
local DEFAULT_DURATION = 300 -- forget a buff we haven't confirmed for this long
local LOG_DURATION = 120     -- buffs only known from the combat log, unknown duration

-- magic buffs that Purge / Dispel Magic can remove
local purgeable = {}
for _, n in pairs({
  "Power Word: Shield", "Power Word: Fortitude", "Prayer of Fortitude", "Divine Spirit", "Prayer of Spirit",
  "Shadow Protection", "Prayer of Shadow Protection", "Inner Fire", "Renew", "Fear Ward", "Power Infusion",
  "Blessing of Freedom", "Blessing of Protection", "Blessing of Sacrifice", "Blessing of Might",
  "Blessing of Wisdom", "Blessing of Kings", "Blessing of Salvation", "Blessing of Light", "Blessing of Sanctuary",
  "Greater Blessing of Might", "Greater Blessing of Wisdom", "Greater Blessing of Kings",
  "Greater Blessing of Salvation", "Greater Blessing of Light", "Greater Blessing of Sanctuary",
  "Divine Favor", "Holy Shield", "Mark of the Wild", "Gift of the Wild", "Thorns", "Rejuvenation", "Regrowth",
  "Innervate", "Barkskin", "Nature's Swiftness", "Abolish Poison", "Arcane Intellect", "Arcane Brilliance",
  "Ice Barrier", "Mana Shield", "Frost Armor", "Ice Armor", "Mage Armor", "Arcane Power", "Presence of Mind",
  "Amplify Magic", "Dampen Magic", "Fire Ward", "Frost Ward", "Demon Armor", "Demon Skin", "Shadow Ward",
  "Unending Breath", "Detect Invisibility", "Detect Lesser Invisibility", "Sacrifice", "Lightning Shield",
  "Water Walking", "Water Breathing", "Elemental Mastery", "Spirit Tap", "Levitate", "Slow Fall",
}) do purgeable[n] = true end

-- durations (seconds) of the buffs that matter in PvP, for countdowns and expiry
local durations = {
  ["Power Word: Shield"] = 30, ["Blessing of Freedom"] = 10, ["Blessing of Protection"] = 10,
  ["Blessing of Sacrifice"] = 30, ["Divine Shield"] = 12, ["Divine Protection"] = 8, ["Ice Block"] = 10,
  ["Ice Barrier"] = 60, ["Mana Shield"] = 60, ["Arcane Power"] = 15, ["Evasion"] = 15, ["Sprint"] = 15,
  ["Recklessness"] = 15, ["Shield Wall"] = 10, ["Retaliation"] = 15, ["Death Wish"] = 30,
  ["Berserker Rage"] = 10, ["Innervate"] = 20, ["Barkskin"] = 15, ["Dash"] = 15, ["Power Infusion"] = 15,
  ["Renew"] = 15, ["Rejuvenation"] = 12, ["Regrowth"] = 21, ["Deterrence"] = 10, ["Rapid Fire"] = 15,
  ["Adrenaline Rush"] = 15, ["Blade Flurry"] = 15, ["Sacrifice"] = 30, ["Elemental Mastery"] = 30,
  ["Fire Ward"] = 30, ["Frost Ward"] = 30, ["Shadow Ward"] = 30, ["Will of the Forsaken"] = 5,
  ["Perception"] = 20, ["Stoneform"] = 8, ["Free Action"] = 30, ["Living Free Action"] = 5,
}

-- icons for buffs we may only ever see in the combat log (learned icons take priority)
local builtin_icons = {
  ["Power Word: Shield"] = "Spell_Holy_PowerWordShield", ["Blessing of Freedom"] = "Spell_Holy_SealOfValor",
  ["Blessing of Protection"] = "Spell_Holy_SealOfProtection", ["Blessing of Sacrifice"] = "Spell_Holy_SealOfSacrifice",
  ["Divine Shield"] = "Spell_Holy_DivineIntervention", ["Divine Protection"] = "Spell_Holy_Restoration",
  ["Ice Block"] = "Spell_Frost_Frost", ["Ice Barrier"] = "Spell_Ice_Lament",
  ["Mana Shield"] = "Spell_Shadow_DetectLesserInvisibility", ["Arcane Power"] = "Spell_Nature_Lightning",
  ["Presence of Mind"] = "Spell_Nature_EnchantArmor", ["Evasion"] = "Spell_Shadow_ShadowWard",
  ["Sprint"] = "Ability_Rogue_Sprint", ["Recklessness"] = "Ability_CriticalStrike",
  ["Berserker Rage"] = "Spell_Nature_AncestralGuardian", ["Shield Wall"] = "Ability_Warrior_ShieldWall",
  ["Retaliation"] = "Ability_Warrior_Challange", ["Death Wish"] = "Spell_Shadow_DeathPact",
  ["Innervate"] = "Spell_Nature_Lightning", ["Barkskin"] = "Spell_Nature_StoneClawTotem",
  ["Nature's Swiftness"] = "Spell_Nature_RavenForm", ["Rejuvenation"] = "Spell_Nature_Rejuvenation",
  ["Regrowth"] = "Spell_Nature_ResistNature", ["Renew"] = "Spell_Holy_Renew",
  ["Power Infusion"] = "Spell_Holy_PowerInfusion", ["Fear Ward"] = "Spell_Holy_Excorcism",
  ["Inner Fire"] = "Spell_Holy_InnerFire", ["Dash"] = "Ability_Druid_Dash",
  ["Deterrence"] = "Ability_Whirlwind", ["Rapid Fire"] = "Ability_Hunter_RunningShot",
  ["Adrenaline Rush"] = "Spell_Shadow_ShadowWordDominate", ["Blade Flurry"] = "Ability_Warrior_PunishingBlow",
  ["Elemental Mastery"] = "Spell_Nature_WispHeal", ["Lightning Shield"] = "Spell_Nature_LightningShield",
  ["Sacrifice"] = "Spell_Shadow_SacrificialShield", ["Will of the Forsaken"] = "Spell_Shadow_RaiseDead",
  ["Stoneform"] = "Spell_Shadow_UnholyStrength", ["Perception"] = "Spell_Nature_Sleep",
  -- common long buffs, so players seen only in the combat log rarely show a question mark
  ["Blessing of Might"] = "Spell_Holy_FistOfJustice", ["Greater Blessing of Might"] = "Spell_Holy_GreaterBlessingofKings",
  ["Blessing of Wisdom"] = "Spell_Holy_SealOfWisdom", ["Greater Blessing of Wisdom"] = "Spell_Holy_GreaterBlessingofWisdom",
  ["Blessing of Kings"] = "Spell_Magic_MageArmor", ["Greater Blessing of Kings"] = "Spell_Magic_GreaterBlessingofKings",
  ["Blessing of Salvation"] = "Spell_Holy_SealOfSalvation", ["Greater Blessing of Salvation"] = "Spell_Holy_GreaterBlessingofSalvation",
  ["Blessing of Light"] = "Spell_Holy_PrayerOfHealing02", ["Blessing of Sanctuary"] = "Spell_Nature_LightningShield",
  ["Power Word: Fortitude"] = "Spell_Holy_WordFortitude", ["Prayer of Fortitude"] = "Spell_Holy_PrayerOfFortitude",
  ["Divine Spirit"] = "Spell_Holy_DivineSpirit", ["Prayer of Spirit"] = "Spell_Holy_PrayerofSpirit",
  ["Shadow Protection"] = "Spell_Shadow_AntiShadow", ["Prayer of Shadow Protection"] = "Spell_Holy_PrayerofShadowProtection",
  ["Inner Focus"] = "Spell_Frost_WindWalkOn", ["Mark of the Wild"] = "Spell_Nature_Regeneration",
  ["Gift of the Wild"] = "Spell_Nature_Regeneration", ["Thorns"] = "Spell_Nature_Thorns",
  ["Arcane Intellect"] = "Spell_Holy_MagicalSentry", ["Arcane Brilliance"] = "Spell_Holy_ArcaneIntellect",
  ["Frost Armor"] = "Spell_Frost_FrostArmor02", ["Ice Armor"] = "Spell_Frost_FrostArmor02", ["Mage Armor"] = "Spell_MageArmor",
  ["Dampen Magic"] = "Spell_Nature_AbolishMagic", ["Amplify Magic"] = "Spell_Holy_FlashHeal",
  ["Demon Skin"] = "Spell_Shadow_RagingScream", ["Demon Armor"] = "Spell_Shadow_RagingScream",
  ["Blood Pact"] = "Spell_Shadow_BloodBoil", ["Unending Breath"] = "Spell_Shadow_DemonBreath",
  ["Battle Shout"] = "Ability_Warrior_BattleShout", ["Bloodrage"] = "Ability_Racial_BloodRage",
  ["Sweeping Strikes"] = "Ability_Rogue_SliceDice", ["Slice and Dice"] = "Ability_Rogue_SliceDice",
  ["Stealth"] = "Ability_Stealth", ["Prowl"] = "Ability_Ambush", ["Vanish"] = "Ability_Vanish",
  ["Seal of Righteousness"] = "Ability_ThunderBolt", ["Seal of the Crusader"] = "Spell_Holy_HolySmite",
  ["Seal of Command"] = "Ability_Warrior_InnerRage", ["Seal of Light"] = "Spell_Holy_HealingAura",
  ["Seal of Wisdom"] = "Spell_Holy_RighteousnessAura", ["Seal of Justice"] = "Spell_Holy_SealOfWrath",
  ["Devotion Aura"] = "Spell_Holy_DevotionAura", ["Retribution Aura"] = "Spell_Holy_AuraOfLight",
  ["Concentration Aura"] = "Spell_Holy_MindSooth", ["Sanctity Aura"] = "Spell_Holy_MindVision",
  ["Trueshot Aura"] = "Ability_TrueShot", ["Aspect of the Hawk"] = "Spell_Nature_RavenForm",
  ["Aspect of the Cheetah"] = "Ability_Mount_JungleTiger", ["Aspect of the Pack"] = "Ability_Mount_WhiteTiger",
  ["Aspect of the Monkey"] = "Ability_Hunter_AspectOfTheMonkey", ["Aspect of the Wild"] = "Spell_Nature_ProtectionformNature",
  ["Bear Form"] = "Ability_Racial_BearForm", ["Dire Bear Form"] = "Ability_Racial_BearForm",
  ["Cat Form"] = "Ability_Druid_CatForm", ["Travel Form"] = "Ability_Druid_TravelForm",
  ["Aquatic Form"] = "Ability_Druid_AquaticForm", ["Moonkin Form"] = "Spell_Nature_ForceOfNature",
  ["Ghost Wolf"] = "Spell_Nature_SpiritWolf", ["Water Walking"] = "Spell_Frost_WindWalkOn",
  ["Water Breathing"] = "Spell_Shadow_DemonBreath", ["Enrage"] = "Ability_Druid_Enrage",
  ["Frenzied Regeneration"] = "Ability_BullRush", ["Tiger's Fury"] = "Ability_Mount_JungleTiger",
  ["Ice Barrier"] = "Spell_Ice_Lament", ["Fire Ward"] = "Spell_Fire_FireArmor", ["Frost Ward"] = "Spell_Frost_FrostWard",
  ["Shadow Ward"] = "Spell_Shadow_AntiShadow", ["Spirit Tap"] = "Spell_Shadow_Requiem",
  ["Clearcasting"] = "Spell_Shadow_ManaBurn", ["Abolish Poison"] = "Spell_Nature_NullifyPoison_02",
  ["Fade"] = "Spell_Magic_LesserInvisibilty", ["Levitate"] = "Spell_Holy_LayOnHands",
  ["Slow Fall"] = "Spell_Magic_FeatherFall", ["First Aid"] = "Spell_Holy_Heal",
}

local purge_spells = { ["Purge"] = true, ["Dispel Magic"] = true, ["Devour Magic"] = true }

libbuffs.units = {} -- unit name -> { [buff name] = { name, texture, stacks, magic, seen, expires, ends } }

local function icons()
  _G.PlatesPrima_db = _G.PlatesPrima_db or {}
  _G.PlatesPrima_db.icons = _G.PlatesPrima_db.icons or {}
  return _G.PlatesPrima_db.icons
end

function libbuffs:Icon(buff)
  local learned = icons()[buff]
  if learned then return learned end
  if builtin_icons[buff] then return ICON .. builtin_icons[buff] end
  return UNKNOWN_ICON
end

-- short label for buffs we don't have an icon for yet: "Blessing of Might" -> "BoM",
-- "Power Word: Fortitude" -> "PWF"
function libbuffs:Initials(buff)
  local out = ""
  for word in string.gfind(buff or "", "[%a']+") do
    if word == "of" or word == "the" then
      out = out .. (word == "of" and "o" or "")
    else
      out = out .. string.upper(string.sub(word, 1, 1))
    end
  end
  return string.sub(out, 1, 3)
end

function libbuffs:IsUnknownIcon(texture)
  return texture == UNKNOWN_ICON
end

function libbuffs:IsPurgeable(buff)
  return purgeable[buff] and true or nil
end

local function now() return GetTime() end

-- read all buffs of a unit the client can see; replaces what we knew about it
local function read_unit(unit)
  local list = {}
  for i = 1, 32 do
    local texture, stacks = UnitBuff(unit, i)
    if not texture then break end
    scanner:SetUnitBuff(unit, i)
    local buff, kind = scanner:Line(1)
    if buff then
      tinsert(list, { name = buff, texture = texture, stacks = stacks, magic = purgeable[buff] or kind == "Magic" })
    end
  end
  return list
end

function libbuffs:ReadUnit(unit)
  local unitname = UnitName(unit)
  if not unitname then return end

  -- only rescan tooltips when the set of buff icons changed (or every 2s)
  local sig = ""
  for i = 1, 32 do
    local texture, stacks = UnitBuff(unit, i)
    if not texture then break end
    sig = sig .. texture .. (stacks or "")
  end
  local known = self.units[unitname]
  local t = now()
  if known and known.sig == sig and t - (known.read or 0) < 2 then return known end

  local old = known or {}
  local fresh = { sig = sig, read = t }
  for _, b in pairs(read_unit(unit)) do
    local previous = old[b.name]
    b.seen = t
    b.ends = previous and previous.ends
    if not b.ends and not previous and old.read and t - old.read < 3 and durations[b.name] then
      -- it appeared while we were watching: we know when it started
      b.ends = t + durations[b.name]
    end
    b.expires = t + (durations[b.name] or DEFAULT_DURATION)
    fresh[b.name] = b
    icons()[b.name] = b.texture
  end
  self.units[unitname] = fresh
  return fresh
end

function libbuffs:GetBuffs(unitname, unitstr, isplayer)
  if not unitname then return nil end
  local known
  if unitstr and UnitName(unitstr) == unitname then
    known = self:ReadUnit(unitstr)
  elseif isplayer then
    -- players have unique names, so what we learned earlier or from the combat log applies
    known = self.units[unitname]
  end
  if not known then return nil end

  local t = now()
  local list = {}
  for key, b in pairs(known) do
    if type(b) == "table" then
      if b.expires and b.expires < t or b.ends and b.ends < t then
        known[key] = nil
      else
        tinsert(list, b)
      end
    end
  end
  -- purgeable first, then by name, so icons don't jump around
  table.sort(list, function(a, b)
    if (a.magic and 1 or 0) ~= (b.magic and 1 or 0) then return a.magic and true or false end
    return a.name < b.name
  end)
  return list
end

---------------------------------------------------------------------------- combat log

-- turn a GlobalStrings format like "%s gains %s." (or "%1$s ...") into a capture pattern
local function pattern(fmt)
  fmt = string.gsub(fmt, "%%%d?%$?s", "\001")
  fmt = string.gsub(fmt, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  fmt = string.gsub(fmt, "\001", "(.+)")
  return "^" .. fmt .. "$"
end

local GAIN = pattern(AURAADDEDOTHERHELPFUL or "%s gains %s.")
local FADE = pattern(AURAREMOVEDOTHER or "%s fades from %s.")
local RESIST = pattern(SPELLRESISTSELFOTHER or "Your %s was resisted by %s.")
local IMMUNE = pattern(SPELLIMMUNESELFOTHER or "Your %s failed. %s is immune.")

local purge -- { target, time, before = {buff names} } while waiting for the result of a purge

local function clean(buff)
  return (string.gsub(buff, " %(%d+%)$", ""))
end

function libbuffs:Gain(unitname, buff)
  if string.find(buff, "^%d") then return end -- "X gains 10 Mana from ..." is not a buff
  buff = clean(buff)
  local known = self.units[unitname] or {}
  self.units[unitname] = known
  local t = now()
  local b = known[buff] or { name = buff }
  b.texture = self:Icon(buff)
  b.magic = purgeable[buff]
  b.seen = t
  b.ends = durations[buff] and t + durations[buff] or nil
  b.expires = t + (durations[buff] or LOG_DURATION)
  known[buff] = b
end

function libbuffs:Fade(unitname, buff)
  buff = clean(buff)
  -- only a buff the target had when you cast counts as purged: "X fades from Y" is also
  -- what the combat log says when a debuff (like a bleed) simply runs out
  if purge and purge.target == unitname and now() - purge.time < 1.5 and purge.before[buff] then
    purge.before[buff] = nil
    self:Purged(unitname, buff)
  end
  local known = self.units[unitname]
  if known then known[buff] = nil end
end

---------------------------------------------------------------------------- purge alerts

local alert = CreateFrame("Frame", "PlatesPrimaPurgeAlert", UIParent)
alert:SetWidth(400) alert:SetHeight(40)
alert:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
alert:SetFrameStrata("HIGH")
alert:Hide()
alert.icon = alert:CreateTexture(nil, "ARTWORK")
alert.icon:SetWidth(32) alert.icon:SetHeight(32)
alert.icon:SetTexCoord(.078, .92, .079, .937)
alert.text = alert:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
alert.text:SetPoint("CENTER", alert, "CENTER", 18, 0)
alert.icon:SetPoint("RIGHT", alert.text, "LEFT", -6, 0)
alert:SetScript("OnUpdate", function()
  local left = this.until_time - GetTime()
  if left <= 0 then this:Hide() return end
  this:SetAlpha(left < .7 and left / .7 or 1)
end)

local function show_alert(text, r, g, b, texture)
  alert.text:SetText(text)
  alert.text:SetTextColor(r, g, b)
  if texture then alert.icon:SetTexture(texture) alert.icon:Show() else alert.icon:Hide() end
  alert.until_time = GetTime() + 3
  alert:SetAlpha(1)
  alert:Show()
end

local shown = {} -- "target:buff" -> time, so the log and the aura scan don't report the same purge twice

function libbuffs:Purged(unitname, buff)
  local key = unitname .. ":" .. buff
  if shown[key] and now() - shown[key] < 2 then return end
  shown[key] = now()
  show_alert("Purged: " .. buff, .3, .8, 1, self:Icon(buff))
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccPlates Prima:|r purged |cff66ccff" .. buff .. "|r from " .. unitname)
end

local function purge_cast(spell)
  if not spell then return end
  spell = string.gsub(spell, "%(.-%)", "")
  spell = string.gsub(spell, "^%s+", "")
  spell = string.gsub(spell, "%s+$", "")
  if not purge_spells[spell] then return end
  local target = UnitName("target")
  if not target or UnitIsFriend("player", "target") then return end
  local before = {}
  for _, b in pairs(read_unit("target")) do before[b.name] = true end
  purge = { target = target, time = now(), before = before, spell = spell }
end

local function check_purge_scan()
  if not purge or now() - purge.time > 1.5 or UnitName("target") ~= purge.target then return end
  local after = {}
  for _, b in pairs(read_unit("target")) do after[b.name] = true end
  for buff in pairs(purge.before) do
    if not after[buff] then libbuffs:Purged(purge.target, buff) end
  end
  purge.before = after
end

hooksecurefunc("CastSpellByName", function(spell) purge_cast(spell) end, true)
hooksecurefunc("CastSpell", function(id, bookType) purge_cast((GetSpellName(id, bookType))) end, true)
hooksecurefunc("UseAction", function(slot)
  if GetActionText(slot) then return end
  scanner:SetAction(slot)
  purge_cast((scanner:Line(1)))
end, true)

---------------------------------------------------------------------------- events

for _, e in pairs({
  "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS", "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS",
  "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS", "CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS",
  "CHAT_MSG_SPELL_AURA_GONE_OTHER", "CHAT_MSG_SPELL_AURA_GONE_PARTY",
  "CHAT_MSG_SPELL_SELF_DAMAGE", "UNIT_AURA", "PLAYER_TARGET_CHANGED",
}) do libbuffs:RegisterEvent(e) end

libbuffs:SetScript("OnEvent", function()
  if event == "UNIT_AURA" then
    if arg1 == "target" then
      check_purge_scan()
      libbuffs:ReadUnit("target")
    end
    return
  elseif event == "PLAYER_TARGET_CHANGED" then
    if UnitExists("target") then libbuffs:ReadUnit("target") end
    return
  end

  local msg = arg1
  if not msg then return end
  local _, _, a, b

  if event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
    if not purge or now() - purge.time > 1.5 then return end
    _, _, a, b = string.find(msg, RESIST)
    if a and purge_spells[a] then show_alert(a .. " resisted", 1, .4, .4) purge = nil return end
    _, _, a, b = string.find(msg, IMMUNE)
    if a and purge_spells[a] then show_alert(b .. " is immune", 1, .4, .4) purge = nil end
    return
  end

  _, _, a, b = string.find(msg, GAIN)
  if a then libbuffs:Gain(a, b) return end
  _, _, a, b = string.find(msg, FADE)
  if a then libbuffs:Fade(b, a) end
end)

-- add libbuffs to ShaguPlates API
ShaguPlates.api.libbuffs = libbuffs
