# Rank14losSA_Raccoonbox: changes

Based on the Rank14losSA Nampower edition (3.0.0) by Meow ([me0wg4ming](https://github.com/me0wg4ming)), itself based on [Rank14losSA](https://github.com/Fiskehatt/Rank14losSA) by Nogall. This list covers only what Raccoonbox changed.

## Raccoonbox 1.0.0

### New
- **New voice for every alert:** all 111 voice alerts were re-voiced with the open [Kokoro](https://huggingface.co/hexgrad/Kokoro-82M) text-to-speech model (voice "af_heart", Apache 2.0 licence), so the whole pack sounds consistent and clear.
- **Earth Shock alert:** a voice alert when an enemy shaman casts Earth Shock (all ranks). It can be switched off in the menu like the other alerts.
- **Divine Shield and Divine Protection:** all ranks now trigger the bubble alert, including low level Divine Protection.
- **Alert range setting:** choose how far away enemies trigger alerts, from 10 to 100 yards (default 40). Use the new slider in the menu, or type `/rsa range 30`. `/rsa range` on its own shows the current range.

### Changed
- **Clearer callouts:** some alerts now say the full ability name instead of an abbreviation: "Death coil" (was "DC"), "Nature's swiftness" (was "NS"), "Power infusion" (was "PI"), "Presence of mind" (was "POM"), "Polymorph!" and "Free action" / "Free action down" (was "Free action pot").
- **Reworded callouts:** Divine Shield says "Bubble", Trinket says "Trinketed", and Flash Bomb says "Flash bomb" (was "Bomb").
- **Works without UnitXP:** if UnitXP isn't installed, alerts still respect range using the game's interact distance checks (about 10 or 28 yards), instead of turning the range check off.
- Clearer chat messages about which range check is active.

### Technical
- Renamed to `Rank14losSA_Raccoonbox` so it can be installed alongside the original. The addon detects its own folder name for its sound files.
- Adds the shared Raccoonbox welcome message (`RaccoonboxWelcome.lua`).
