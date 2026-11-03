# ShaguTweaks_Raccoonbox: changes

Based on [ShaguTweaks](https://github.com/shagu/ShaguTweaks) by Shagu (MIT licence). This list covers only what Raccoonbox changed.

## Raccoonbox 1.0.0

### New
- **Auto Tracking** (General): pick a tracking ability (Find Herbs, Find Minerals, Track Beasts and so on) from a dropdown, and it's turned back on automatically after you die, including at battleground spirit healers. It only casts out of combat, not while mounted on a flight path, shapeshifted or casting. If the chosen ability isn't known (e.g. after switching from Herbalism to Mining), it falls back to one you know.
- **Shake To Find Cursor** (General): shake the mouse quickly and the cursor briefly grows so you can spot it.
- **Unit Frame Class Portraits: Keep Own Face** (Unit Frames): with class portraits on, your own frame keeps your character's face instead of a class icon. On by default.
- **Dropdowns in the settings window:** tweaks can now have a dropdown next to their checkbox (used by Auto Tracking).

### Technical
- Renamed to `ShaguTweaks_Raccoonbox` so it can be installed alongside the original. The addon detects its own folder name for its textures.
- Adds the shared Raccoonbox welcome message (`RaccoonboxWelcome.lua`).
