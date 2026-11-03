# ShaguPlates_Raccoonbox: changes

Based on [ShaguPlates](https://github.com/shagu/ShaguPlates) by Shagu (MIT licence). This list covers only what Raccoonbox changed.

## Raccoonbox 1.0.0

### New
- **Hide pets completely:** pet, guardian and companion nameplates can be made fully invisible and click-through, not just their health bars. Pet names are learned automatically from your target, mouseover, party and raid pets, and (with Nampower) from pets casting abilities.
- **Still show friendly pets:** option to keep friendly pets visible while enemy pets stay hidden.
- **Hide low level companions completely:** hides vanity pets and other very low level companions. **Companion max level** sets the cutoff (default 1).
- All four options are in the ShaguPlates settings (`/splates`) under nameplates. **Hiding pets and low level companions is on by default**; untick them there if you want to see pet nameplates. Totems are never hidden by these options.

### Changed
- **Chat bubbles are shown above nameplates** instead of being covered by them.
- **Raid target icons** use the original Blizzard icons and always sit above the name.

### Technical
- Renamed to `ShaguPlates_Raccoonbox` so it can be installed alongside the original. The addon detects its own folder name.
- Adds the shared Raccoonbox welcome message (`RaccoonboxWelcome.lua`).
