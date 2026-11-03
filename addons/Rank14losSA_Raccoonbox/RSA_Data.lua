--[[
RSA_Data.lua - Spell ID Tables, Durations, and Menu Data
Part of Rank14losSA addon
]]

-- Spell ID mappings for UNIT_CASTEVENT (casted spells)
RSA_CAST_SPELL_IDS = {
	[339] = "EntanglingRoots",
	[1062] = "EntanglingRoots",
	[5195] = "EntanglingRoots",
	[5196] = "EntanglingRoots",
	[9852] = "EntanglingRoots",
	[9853] = "EntanglingRoots",
	[20484] = "EscapeArtist",
	[5782] = "Fear",
	[6213] = "Fear",
	[6215] = "Fear",
	[8068] = "Hearthstone",
	[2637] = "Hibernate",
	[18657] = "Hibernate",
	[18658] = "Hibernate",
	[5484] = "HowlofTerror",
	[17928] = "HowlofTerror",
	[605] = "MindControl",
	[10911] = "MindControl",
	[10912] = "MindControl",
	[118] = "Polymorph",
	[12824] = "Polymorph",
	[12825] = "Polymorph",
	[12826] = "Polymorph",
	[982] = "RevivePet",
	[1513] = "ScareBeast",
	[14326] = "ScareBeast",
	[14327] = "ScareBeast",
	[20549] = "WarStomp",
}

-- Buff Spell IDs
RSA_BUFF_SPELL_IDS = {
	[13750] = "AdrenalineRush",
	[12042] = "ArcanePower",
	[22812] = "Barkskin",
	[51401] = "Barkskin",  -- Barkskin (Feral) Rank 1 - Turtle WoW
	[51451] = "Barkskin",  -- Barkskin (Feral) Rank 2 - Turtle WoW
	[51452] = "Barkskin",  -- Barkskin (Feral) Rank 3 - Turtle WoW
	[2687] = "BattleStance",
	[18499] = "BerserkerRage",
	[2458] = "BerserkerStance",
	[19574] = "BestialWrath",
	[13877] = "BladeFlurry",
	[1044] = "BlessingofFreedom",
	[1022] = "BlessingofProtection",
	[5599] = "BlessingofProtection",
	[10278] = "BlessingofProtection",
	[20577] = "Cannibalize",
	[14177] = "ColdBlood",
	[11129] = "Combustion",
	[1850] = "Dash",
	[9821] = "Dash",
	[12292] = "DeathWish",
	[71] = "DefensiveStance",
	[19296] = "Deterrence",
	[20216] = "DivineFavor",
	[642] = "DivineShield",
	[1020] = "DivineShield",   -- Divine Shield Rank 2
	[498] = "DivineShield",    -- Divine Protection Rank 1 (low-level bubble, same sounds)
	[5573] = "DivineShield",   -- Divine Protection Rank 2
	[16166] = "ElementalMastery",
	[5277] = "Evasion",
	[26669] = "Evasion",
	[6346] = "FearWard",
	[22842] = "FrenziedRegeneration",
	[22895] = "FrenziedRegeneration",
	[22896] = "FrenziedRegeneration",
	[45438] = "IceBlock",
	[14751] = "InnerFocus",
	[29166] = "Innervate",
	[12975] = "LastStand",
	[16689] = "Nature'sGrasp",
	[16810] = "Nature'sGrasp",
	[16811] = "Nature'sGrasp",
	[16812] = "Nature'sGrasp",
	[16813] = "Nature'sGrasp",
	[17116] = "Nature'sGrasp",
	[16188] = "Nature'sSwiftness",
	[10060] = "PowerInfusion",
	[12043] = "PresenceofMind",
	[3045] = "RapidFire",
	[1719] = "Recklessness",
	[23920] = "Reflector",
	[20230] = "Retaliation",
	[7812] = "Sacrifice",
	[871] = "ShieldWall",
	[2983] = "Sprint",
	[8696] = "Sprint",
	[11305] = "Sprint",
	[20594] = "Stoneform",
	[12328] = "SweepingStrikes",
	[7744] = "WilloftheForsaken",
	[6615] = "FreeAction",
}

-- Item/Ability Use Spell IDs
RSA_USE_SPELL_IDS = {
	[5134] = "FlashBomb",
	[1766] = "Kick",
	[1767] = "Kick",
	[1768] = "Kick",
	[1769] = "Kick",
	[38768] = "Kick",
	[19236] = "DesperatePrayer",
	[19238] = "DesperatePrayer",
	[19240] = "DesperatePrayer",
	[19241] = "DesperatePrayer",
	[19242] = "DesperatePrayer",
	[19243] = "DesperatePrayer",
	[2484] = "EarthbindTotem",
	[12051] = "Evocation",
	[1499] = "FreezingTrap",
	[8178] = "GroundingTotem",
	[19577] = "Intimidation",
	[16190] = "ManaTideTotem",
	[740] = "Tranquility",
	[8918] = "Tranquility",
	[9862] = "Tranquility",
	[9863] = "Tranquility",
	[8143] = "TremorTotem",
	[8042] = "EarthShock",   -- Earth Shock Rank 1-7
	[8044] = "EarthShock",
	[8045] = "EarthShock",
	[8046] = "EarthShock",
	[10412] = "EarthShock",
	[10413] = "EarthShock",
	[10414] = "EarthShock",
	[23505] = "Trinket",
	[52317] = "Trinket",  -- PvP Trinket - Turtle WoW
}

-- Debuff Spell IDs
RSA_DEBUFF_SPELL_IDS = {
	[19503] = "ScatterShot",
	[2094] = "Blind",
	[12809] = "ConcussionBlow",
	[6789] = "DeathCoil",
	[17925] = "DeathCoil",
	[17926] = "DeathCoil",
	[676] = "Disarm",
	[853] = "HammerofJustice",
	[5588] = "HammerofJustice",
	[5589] = "HammerofJustice",
	[10308] = "HammerofJustice",
	[5246] = "IntimidatingShout",
	[8122] = "PsychicScream",
	[8124] = "PsychicScream",
	[10888] = "PsychicScream",
	[10890] = "PsychicScream",
	[15487] = "Silence",
	[19244] = "SpellLock",
	[19647] = "SpellLock",
	[19386] = "WyvernSting",
	[24132] = "WyvernSting",
	[24133] = "WyvernSting",
	[18469] = "Counterspell-Silenced",
	[20066] = "Repetance",
	[6358] = "Seduction",
	[6359] = "Seduction",
	[20407] = "Seduction",
}

-- Debuff name mappings
RSA_DEBUFF_NAMES = {
	["counterspell"] = "Counterspell-Silenced",
	["repentance"] = "Repetance",
	["seduction"] = "Seduction",
}

-- Buff fade patterns
RSA_FADE_BUFF_PATTERNS = {
	["Barkskin"] = "barkskin",
	["BlessingofProtection"] = "blessing of protection",
	["BlessingofFreedom"] = "blessing of freedom",
	["Deterrence"] = "deterrence",
	["DivineShield"] = "divine shield",
	["Evasion"] = "evasion",
	["IceBlock"] = "ice block",
	["ShieldWall"] = "shield wall",
	["Sprint"] = "sprint",
	["Dash"] = "dash",
	["BestialWrath"] = "bestial wrath",
	["AdrenalineRush"] = "adrenaline rush",
	["BladeFlurry"] = "blade flurry",
	["RapidFire"] = "rapid fire",
	["BerserkerRage"] = "berserker rage",
	["Recklessness"] = "recklessness",
	["Retaliation"] = "retaliation",
	["DeathWish"] = "death wish",
	["LastStand"] = "last stand",
	["Innervate"] = "innervate",
	["Combustion"] = "combustion",
	["ArcanePower"] = "arcane power",
	["FrenziedRegeneration"] = "frenzied regeneration",
	["Nature'sGrasp"] = "nature's grasp",
	["Stoneform"] = "stoneform",
	["WilloftheForsaken"] = "will of the forsaken",
	["FreeAction"] = "free action",
}

-- Item Icons
RSA_ITEM_ICONS = {
	[5134] = "Interface\\Icons\\INV_Misc_Ammo_Bullet_01",
	[23505] = "Interface\\Icons\\INV_Jewelry_TrinketPVP_02",
	[52317] = "Interface\\Icons\\INV_Jewelry_TrinketPVP_02",
}

-- Buff durations (nil = until consumed)
RSA_BUFF_DURATIONS = {
	["Evasion"] = 15,
	["IceBlock"] = 10,
	["DivineShield"] = 12,
	["ShieldWall"] = 10,
	["Barkskin"] = 15,
	["Deterrence"] = 10,
	["BlessingofProtection"] = 10,
	["Recklessness"] = 15,
	["Retaliation"] = 15,
	["Sprint"] = 15,
	["Dash"] = 15,
	["BestialWrath"] = 18,
	["AdrenalineRush"] = 15,
	["BladeFlurry"] = 15,
	["RapidFire"] = 15,
	["BerserkerRage"] = 10,
	["LastStand"] = 20,
	["Innervate"] = 20,
	["WilloftheForsaken"] = 5,
	["Stoneform"] = 8,
	["DeathWish"] = 30,
	["Combustion"] = 15,
	["ArcanePower"] = 15,
	["FrenziedRegeneration"] = 10,
	["BlessingofFreedom"] = 10,
	["Nature'sGrasp"] = 45,
	["FreeAction"] = 30,
}

-- Buffs that show for 5s without timer (instant/consume abilities)
RSA_NO_TIMER_BUFFS = {
	["ColdBlood"] = true,
	["PresenceofMind"] = true,
	["ElementalMastery"] = true,
	["Nature'sSwiftness"] = true,
	["DivineFavor"] = true,
	["InnerFocus"] = true,
	["BattleStance"] = true,
	["BerserkerStance"] = true,
	["DefensiveStance"] = true,
	["Cannibalize"] = true,
	["FearWard"] = true,
	["PowerInfusion"] = true,
	["Reflector"] = true,
	["Sacrifice"] = true,
	["SweepingStrikes"] = true,
}

-- SpellID-based duration overrides
RSA_SPELLID_DURATIONS = {
	[51401] = 12,  -- Barkskin (Feral) Rank 1
	[51451] = 12,  -- Barkskin (Feral) Rank 2
	[51452] = 12,  -- Barkskin (Feral) Rank 3
	[642] = 10,    -- Divine Shield Rank 1
	[1020] = 12,   -- Divine Shield Rank 2
	[498] = 6,     -- Divine Protection Rank 1
	[5573] = 8,    -- Divine Protection Rank 2
}

-- Menu constants
RSA_BUFF = 44
RSA_CAST = 57
RSA_DEBUFF = 73
RSA_FADING = 102

RSA_MENU_TEXT = { "Enabled", "Enabled outside of Battlegrounds", "Show Alert Frame", "Move Alert Frame", "Circular Portrait Icon", }
RSA_MENU_SETS = { "enabled", "outside", "alertFrame", "moveAlert", "portraitIconShape", }

RSA_MENU_WHITE = {}
RSA_MENU_WHITE[1] = true

RSA_SOUND_OPTION_NOBUTTON = {}
RSA_SOUND_OPTION_NOBUTTON[RSA_BUFF] = true
RSA_SOUND_OPTION_NOBUTTON[RSA_CAST] = true
RSA_SOUND_OPTION_NOBUTTON[RSA_DEBUFF] = true
RSA_SOUND_OPTION_NOBUTTON[RSA_FADING] = true

RSA_SOUND_OPTION_WHITE = {}
RSA_SOUND_OPTION_WHITE[1] = true
RSA_SOUND_OPTION_WHITE[RSA_BUFF + 1] = true
RSA_SOUND_OPTION_WHITE[RSA_CAST + 1] = true
RSA_SOUND_OPTION_WHITE[RSA_DEBUFF + 1] = true
RSA_SOUND_OPTION_WHITE[RSA_FADING + 1] = true

RSA_SOUND_OPTION_TEXT = {
	"When an enemy recieves a buff:",
	"Adrenaline Rush", "Arcane Power", "Barkskin", "Battle Stance", "Berserker Rage",
	"Berserker Stance", "Bestial Wrath", "Blade Flurry", "Blessing of Freedom",
	"Blessing of Protection", "Cannibalize", "Cold Blood", "Combustion", "Dash",
	"Death Wish", "Defensive Stance", "Deterrence", "Divine Favor",
	"Divine Shield", "Elemental Mastery", "Evasion", "Fear Ward",
	"Frenzied Regeneration", "Ice Block", "Inner Focus", "Innervate", "Last Stand",
	"Nature's Grasp", "Nature's Swiftness", "Power Infusion", "Presence of Mind",
	"Rapid Fire", "Recklessness", "Reflector", "Retaliation", "Sacrifice",
	"Shield Wall", "Sprint", "Stone form", "Sweeping Strikes", "Will of the Forsaken", "Free Action",
	"",
	"When an enemy starts casting:",
	"Entangling Roots", "Escape Artist", "Fear", "Hearthstone", "Hibernate",
	"Howl of Terror", "Mind Control", "Polymorph", "Revive Pet", "Scare Beast", "War Stomp",
	"",
	"When a friendly player recieves a debuff:",
	"Blind", "Concussion Blow", "Counterspell - Silenced", "Death Coil", "Disarm",
	"Hammer of Justice", "Intimidating Shout", "Psychic Scream", "Repetance",
	"Scatter Shot", "Seduction", "Silence", "Spell Lock", "Wyvern Sting",
	"",
	"When a buff fades:",
	"Adrenaline Rush", "Arcane Power", "Barkskin", "Berserker Rage", "Bestial Wrath",
	"Blade Flurry", "Blessing of Freedom", "Blessing of Protection", "Combustion",
	"Dash", "Death Wish", "Deterrence", "Divine Shield", "Evasion",
	"Frenzied Regeneration", "Ice Block", "Innervate", "Last Stand", "Nature's Grasp",
	"Rapid Fire", "Recklessness", "Retaliation", "Shield Wall", "Sprint",
	"Stoneform", "Will of the Forsaken", "Free Action",
	"",
	"When an enemy uses an ability:",
	"Kick", "Flash Bomb", "Desperate Prayer", "Earthbind Totem", "Evocation",
	"Freezing Trap", "Grounding Totem", "Intimidation", "Mana Tide Totem",
	"Tranquility", "Tremor Totem", "Trinket", "Earth Shock",
}
