# Rank14losSA Reborn

A complete rewrite of the classic Rank14losSA addon for WoW 1.12.1 with **SuperWoW** integration. This addon verbally warns you when enemies use important spells (Blind, Shield Wall, Trinket, etc.) - now with proactive GUID-based detection instead of reactive combat log parsing.

## 📜 Changelog

### v2.1 - Reborn (splitup of files)

- Added Free Action potion to list
- Resized the alert frame to be a bit smaller
- moved bar right of icon (it was behind the icon before so cast bar not been fully shown)

![alt text](image.jpg)

## 📜 Changelog

### v2.0 - Reborn (splitup of files)

<img width="719" height="284" alt="grafik" src="https://github.com/user-attachments/assets/ce1cb387-21e5-46ad-b825-2142996a36f8" />

- Pfui support
- Shows buff-fade timer on target frame now.
- always tracks cooldowns-fadeing of all enemy players in a 50yards radius.

## 🎯 What's New in Reborn

### SuperWoW Integration (Required)
- **Proactive Detection**: Uses GUID scanning and `UNIT_CASTEVENT` to detect abilities BEFORE they appear in combat log
- **50 Yard Range Check**: Only alerts for enemies within 50 yards (no more alerts from across the map)
- **Spell ID Based**: Direct spell ID detection instead of unreliable text parsing
- **Buff Scanning**: Periodically scans enemy buffs for abilities that don't trigger events

### Visual Alert Frame
- **On-Screen Alerts**: Visual notification with spell icon and text
- **Format**: `[Icon] PlayerName casts SpellName` / `[Icon] PlayerName's SpellName fades`
- **Target Priority**: Your current target's alerts always take priority over other players
- **Fully Customizable**:
  - Movable (drag to any position)
  - Adjustable background opacity (0-100%)
  - Click-through when not in edit mode
  - Position saved between sessions

### New Menu Options (`/rsa`)
- **Enabled** - Toggle addon on/off
- **Enabled outside of Battlegrounds** - Auto-enable in BGs only
- **Show Alert Frame** - Toggle visual alerts
- **Move Alert Frame** - Enter drag mode to reposition
- **Background Opacity Slider** - 0% (transparent) to 100% (visible)

### Additional Improvements
- **Barkskin (Feral)** support for Turtle WoW (Spell IDs 51401, 51451, 51452)
- **Flash Bomb** detection added
- **MP3 audio format** (smaller file sizes)
- **Movable config windows** - Both menu frames can be dragged
- **Performance optimized** - Cached functions, efficient lookups
- **Memory leak fixes** - Proper cleanup and event handling

## 📋 Requirements

- **SuperWoW** - https://github.com/balakethelock/SuperWoW
  - This addon will NOT function without SuperWoW
  - Provides GUID scanning, `UNIT_CASTEVENT`, and `UnitXP` distance functions

## 📦 Installation

1. Install SuperWoW first (follow instructions on their GitHub)
2. Download Rank14losSA Reborn
3. Extract to `World of Warcraft/Interface/AddOns/Rank14losSA/`
4. Ensure folder structure:
   ```
   AddOns/
   └── Rank14losSA/
       ├── Rank14losSA.toc
       ├── RSA.lua
       ├── RSA.xml
       └── Voice/
           ├── Barkskin.mp3
           ├── Evasion.mp3
           └── ... (other sound files)
   ```
5. Restart WoW or `/reload`

## 🎮 Usage

| Command | Description |
|---------|-------------|
| `/rsa` | Open configuration menu |
| `/rsa save` | Show saved alert frame position |

### Alert Frame Controls
1. Open menu with `/rsa`
2. Check **"Move Alert Frame"** to enter edit mode
3. Drag the frame to desired position
4. Uncheck **"Move Alert Frame"** to lock position
5. Adjust **Background Opacity** slider as needed

## 🔊 Tracked Abilities

### Buffs (Enemy gains)
Adrenaline Rush, Arcane Power, Barkskin, Battle Stance, Berserker Rage, Berserker Stance, Bestial Wrath, Blade Flurry, Blessing of Freedom, Blessing of Protection, Cannibalize, Cold Blood, Combustion, Dash, Death Wish, Defensive Stance, Desperate Prayer, Deterrence, Divine Favor, Divine Shield, Earthbind Totem, Elemental Mastery, Evasion, Evocation, Fear Ward, First Aid, Frenzied Regeneration, Freezing Trap, Grounding Totem, Ice Block, Inner Focus, Innervate, Intimidation, Last Stand, Mana Tide Totem, Nature's Grasp, Nature's Swiftness, Power Infusion, Presence of Mind, Rapid Fire, Recklessness, Reflector, Retaliation, Sacrifice, Shield Wall, Sprint, Stoneform, Sweeping Strikes, Tranquility, Tremor Totem, Trinket, Will of the Forsaken

### Casts (Enemy starts casting)
Entangling Roots, Escape Artist, Fear, Hearthstone, Hibernate, Howl of Terror, Mind Control, Polymorph, Revive Pet, Scare Beast, War Stomp

### Debuffs (Applied to you/friendlies)
Blind, Concussion Blow, Counterspell-Silenced, Death Coil, Disarm, Hammer of Justice, Intimidating Shout, Psychic Scream, Repentance, Scatter Shot, Seduction, Silence, Spell Lock, Wyvern Sting

### Fading Buffs (Enemy buff expires)
Barkskin, Blessing of Protection, Deterrence, Divine Shield, Evasion, Ice Block, Shield Wall

### Item Uses
Kick, Flash Bomb

## 🔧 Technical Details

### Detection Methods
1. **UNIT_CASTEVENT** - Instant detection of spell casts via SuperWoW
2. **GUID Buff Scanning** - Periodic scan of enemy buffs (every 0.5s when enemies nearby)
3. **Combat Log Fallback** - Legacy detection if SuperWoW unavailable (limited functionality)

### Alert Priority System
- Alerts from your **current target** always override alerts from other players
- Non-target alerts won't interrupt a target alert for 1 second
- Ensures you never miss important info about your focus target

### SavedVariables
- `RSAConfig` - All addon settings
- `RSA_AlertFrameX` / `RSA_AlertFrameY` - Alert frame position
- `RSA_AlertFrameEnabled` - Visual alerts toggle
- `RSA_AlertFrameBgAlpha` - Background opacity

## 📜 Changelog

### v1.0 - Reborn (Complete Rewrite)
- Complete rewrite with SuperWoW integration
- Added GUID-based proactive detection
- Added 50 yard range limiting
- Added visual alert frame with icons
- Added target priority system
- Added background opacity slider
- Added movable config frames
- Added Barkskin (Feral) for Turtle WoW
- Added Flash Bomb detection
- Switched to MP3 audio format
- Fixed memory leaks
- Performance optimizations

### v0.2 - Original
- Original release by Nogall of Feenix Warsong
- Combat log based detection

## 🙏 Credits

- **Original Addon**: Nogall of Feenix Warsong - https://github.com/Fiskehatt/Rank14losSA
- **Reborn Version**: Complete rewrite with SuperWoW integration
- **SuperWoW**: balakethelock - https://github.com/balakethelock/SuperWoW
- **Based on**: GladiatorlosSA (Cataclysm addon)

## ⚠️ Troubleshooting

**"SuperWoW NOT DETECTED" error:**
- Make sure SuperWoW is installed correctly
- Check that SuperWoW's DLL is in your WoW folder
- Restart WoW completely (not just /reload)

**No alerts showing:**
- Check `/rsa` menu - ensure "Enabled" is checked
- Ensure "Show Alert Frame" is checked
- Verify enemy is within 50 yards
- Check individual spell toggles in "Sound files" menu

**Alert frame not visible:**
- Click "Move Alert Frame" in `/rsa` menu
- The frame might be off-screen - check edges
- Try adjusting Background Opacity slider

**Sounds not playing:**
- Enable game sounds in WoW settings
- Check Master volume is not muted
- Verify .mp3 files exist in Voice folder
