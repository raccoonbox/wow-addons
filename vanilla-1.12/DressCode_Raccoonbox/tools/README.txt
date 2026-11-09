Refresh Dress Code's item data (run with the game closed, from the OctoWoW folder):

  python Interface/AddOns/DressCode_Raccoonbox/tools/dresscode_gen.py WDB Interface/AddOns/AtlasLoot/Database Interface/AddOns/DressCode_Raccoonbox/Data.lua Interface/AddOns/Atlas-CFM/Locales/enUS/QuestData.lua

Uses: WDB/itemcache.wdb (item stats), WDB/questcache.wdb (quests you have opened), AtlasLoot (drops, browse lists),
Atlas-CFM (dungeon quests with quest giver, location, notes). The more your client has seen, the more Dress Code knows.
