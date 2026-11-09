"""Generate Dress Code's Data.lua.

Sources:
  * WDB/itemcache.wdb  - stats of every item the client has seen
  * WDB/questcache.wdb - quest titles and reward items of every quest the client has viewed
  * AtlasLoot Database - where items drop, and browse lists (dungeons, professions, factions, PvP, sets)
  * learned quests     - quests players learned in game, from any number of files after the Atlas-CFM file:
                         - Dress Code's saved data (WTF/Account/<name>/SavedVariables/DressCode_Raccoonbox.lua):
                           what your client learned itself and heard from other players in game
                         - text files with "DC1:..." codes from the Share button (anything else is ignored)

usage: python dresscode_gen.py <WDB dir> <AtlasLoot/Database dir> <out Data.lua>
                               [Atlas-CFM/Locales/enUS/QuestData.lua] [saved data .lua | codes .txt ...]
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wdb_items import parse as parse_items
from wdb_quests import parse as parse_quests

EQUIP_TYPES = {1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 20, 21, 22, 23, 25, 26, 28}
BROWSE_FILES = [('Instances.lua', 'Dungeons & Raids'), ('WorldBosses.lua', 'World bosses'),
                ('Crafting.lua', 'Professions'), ('Factions.lua', 'Factions'), ('PvP.lua', 'PvP'), ('Sets.lua', 'Sets')]

wdb_dir, atlas_dir, out = sys.argv[1], sys.argv[2], sys.argv[3]
items = parse_items(os.path.join(wdb_dir, 'itemcache.wdb'))
qpath = os.path.join(wdb_dir, 'questcache.wdb')
quests = parse_quests(qpath) if os.path.exists(qpath) else {}

# --- AtlasLoot: loot table key -> readable "Instance - Boss"
names = {}
reg = open(os.path.join(atlas_dir, 'TableRegister.lua'), encoding='utf-8-sig', errors='replace').read()
for key, body in re.findall(r'\["(\w+)"\]\s*=\s*\{(.*?)\},?\s*$', reg, re.M):
    parts = re.findall(r'AL\["([^"]+)"\]', body)
    if not parts:
        continue
    boss, place = parts[0], (parts[-1] if len(parts) > 1 else '')
    label = (place + ' - ' + boss) if place and place != boss else boss
    if key not in names or (' - ' in label and ' - ' not in names[key]):
        names[key] = label

# --- AtlasLoot: item sources, and the browse lists
sources = {}
browse = []  # [(category, [(table label, [(id, icon, quality, name, extra)])])]
by_name = {}
for iid, i in items.items():
    if i['cls'] in (2, 4) or i['name'] not in by_name:
        by_name.setdefault(i['name'], iid)

def clean_name(text):
    return re.sub(r'=\w+=', '', text).replace('^', ' ').replace('~', ' ').strip()

FULL = re.compile(r'^\s*\{\s*(\d+)\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"')           # { id, "icon", "=q4=Name", ... }
SHORT = re.compile(r'^\s*\{\s*(\d+)\s*,\s*"([^"]*)"\s*\}')                      # { id, "=ds=..." }
SPELL = re.compile(r'^\s*\{\s*"s(\d+)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,?\s*"?([^"]*)')  # { "s2329", "icon", "=q1=Name", "=ds=... =so1=1" }
for fn, category in BROWSE_FILES:
    path = os.path.join(atlas_dir, fn)
    if not os.path.exists(path):
        continue
    tables, table, entries = [], None, None
    for line in open(path, encoding='utf-8-sig', errors='replace'):
        m = re.match(r'\s*(\w+)\s*=\s*\{\s*(\{\s*)?$', line)
        if m:
            if table and entries:
                tables.append((names.get(table, table), entries))
            table, entries = m.group(1), []
            continue
        if table is None:
            continue
        label = names.get(table)
        m = SPELL.match(line)
        if m:
            spell, icon, text, rest = m.group(1), m.group(2), m.group(3), m.group(4)
            q = re.match(r'=q(\d)=', text)
            name = clean_name(text)
            skill = re.search(r'=so1=(\d+)', rest or '')
            made = by_name.get(name)
            entries.append(('s%s/%s' % (spell, made or 0), icon, int(q.group(1)) if q else 1, name,
                            ('skill %s' % skill.group(1)) if skill else ''))
            if made:
                sources.setdefault(made, []).append('Crafted: %s%s' % (label or table, (' (skill %s)' % skill.group(1)) if skill else ''))
            continue
        m = FULL.match(line)
        if m:
            iid, icon, text = int(m.group(1)), m.group(2), m.group(3)
            q = re.match(r'=q(\d)=', text)
            quality, name = (int(q.group(1)) if q else 1), clean_name(text)
        else:
            m = SHORT.match(line)
            if not m:
                continue
            iid, icon = int(m.group(1)), ''
            known = items.get(iid)
            quality, name = (known['quality'], known['name']) if known else (1, '')
        if iid <= 0:
            continue
        entries.append((iid, icon, quality, name or ('item %d' % iid), ''))
        if label:
            sources.setdefault(iid, []).append(label)
    if table and entries:
        tables.append((names.get(table, table), entries))
    if tables:
        browse.append((category, tables))

# --- Atlas-CFM dungeon quests: title, level, quest giver/location, notes, class limits, rewards
CLASSES = ['Warrior', 'Paladin', 'Hunter', 'Rogue', 'Priest', 'Shaman', 'Mage', 'Warlock', 'Druid']
cfm_quests = []        # [(title, level, instance, faction, classes, giver, note)]
item_quests = {}       # item id -> [index into cfm_quests]
cfm_path = sys.argv[4] if len(sys.argv) > 4 else None

def lua_strings(expr):
    parts = re.findall(r'"((?:[^"\\]|\\.)*)"', expr)
    text = ''.join(parts).replace('\\"', '"').replace('\\n', ' ').replace("\\'", "'")
    return re.sub(r'\s+', ' ', text).strip()

def field_expr(body, name):
    m = re.search(r'\n\s*' + name + r'\s*=\s*(.*?)(?=,\s*\n\s*\w+\s*=|\n\})', body, re.S)
    return m.group(1) if m else ''

if cfm_path and os.path.exists(cfm_path):
    text = open(cfm_path, encoding='utf-8-sig', errors='replace').read()
    blocks = {}
    for m in re.finditer(r'^kQuestInstanceData\.(\w+)\.(Horde|Alliance)\[(\d+)\]\s*=\s*\{(.*?)^\}', text, re.M | re.S):
        blocks[(m.group(1), m.group(2), m.group(3))] = m.group(4)
    # copies: kQuestInstanceData.X.Alliance[1] = kQuestInstanceData.X.Horde[1]
    for m in re.finditer(r'^kQuestInstanceData\.(\w+)\.(Horde|Alliance)\[(\d+)\]\s*=\s*kQuestInstanceData\.(\w+)\.(Horde|Alliance)\[(\d+)\]', text, re.M):
        src = blocks.get((m.group(4), m.group(5), m.group(6)))
        if src:
            blocks[(m.group(1), m.group(2), m.group(3))] = src
    for (inst, faction, _), body in blocks.items():
        t = re.search(r'Title\s*=\s*"((?:[^"\\]|\\.)*)"', body)
        if not t:
            continue
        lvl = re.search(r'Level\s*=\s*(\d+)', body)
        att = re.search(r'Attain\s*=\s*(\d+)', body)
        qid = re.search(r'\bId\s*=\s*(\d+)', body)
        note = lua_strings(field_expr(body, 'Note'))
        only = re.search(r'([A-Za-z ,]+?)\s+ONLY', note)
        classes = ','.join(c for c in CLASSES if only and c.lower() in only.group(1).lower())
        rew = re.search(r'Rewards\s*=\s*\{(.*?)\n\s*\}', body, re.S)
        ids = [int(x) for x in re.findall(r'id\s*=\s*(\d+)', rew.group(1))] if rew else []
        if not ids:
            continue
        place = re.sub(r'(?<=[a-z])(?=[A-Z])', ' ', inst)
        if place.startswith('BG') and len(place) > 2:
            place = place[2:] + ' (battleground)'
        idx = len(cfm_quests) + 1
        cfm_quests.append((t.group(1).replace('\\"', '"'), int(lvl.group(1)) if lvl else 0, place, faction, classes,
                           lua_strings(field_expr(body, 'Location')), note, int(att.group(1)) if att else 0, int(qid.group(1)) if qid else 0))
        for iid in ids:
            item_quests.setdefault(iid, []).append(idx)
            label = 'Quest: %s (L%d, %s)' % (cfm_quests[-1][0], cfm_quests[-1][1], place)
            if label not in sources.get(iid, []):
                sources.setdefault(iid, []).insert(0, label)

# --- quests players learned in game (shared codes)
# code: "DC1:" + entries joined by "~"; entry: faction(A/H)^lowest player level seen^quest level (0 = unknown)^
#       class bits of the players who saw it^title^quest giver^zone^reward item ids joined by "."
learned_paths = sys.argv[5:]
shared, bad_entries = {}, 0

def add_shared(entry, reports=1):
    global bad_entries
    f = entry.split('^')
    if (len(f) != 8 or f[0] not in ('A', 'H') or not all(x.isdigit() for x in f[1:4])
            or not f[4].strip() or not re.match(r'^\d+(\.\d+)*$', f[7])):
        bad_entries += 1
        return
    faction = 'Alliance' if f[0] == 'A' else 'Horde'
    s = shared.setdefault((f[4].strip().lower(), faction), dict(
        title=f[4].strip(), faction=faction, seen=int(f[1]), level=0, giver='', zone='', ids=set(), reports=0))
    s['seen'] = min(s['seen'], int(f[1]))
    s['level'] = max(s['level'], int(f[2]))
    s['giver'] = s['giver'] or f[5].strip()
    s['zone'] = s['zone'] or f[6].strip()
    s['ids'].update(int(x) for x in f[7].split('.'))
    s['reports'] += reports

def lua_table(text, pos):
    """read a SavedVariables table literal starting at text[pos] == '{'; returns (dict, end position)"""
    tok = re.compile(r'\s*(?:--[^\n]*\n\s*)*(\{|\}|=|,|\[|\]|"(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?(?:e[-+]?\d+)?|true|false|nil)', re.S)
    def value(p):
        m = tok.match(text, p)
        t = m.group(1)
        if t == '{':
            return table(m.end())
        if t.startswith('"'):
            return bytes(t[1:-1], 'utf-8').decode('unicode_escape').encode('latin-1').decode('utf-8', 'replace'), m.end()
        if t in ('true', 'false', 'nil'):
            return {'true': True, 'false': False, 'nil': None}[t], m.end()
        return (float(t) if '.' in t or 'e' in t else int(t)), m.end()
    def table(p):
        out, n = {}, 1
        while True:
            m = tok.match(text, p)
            if m.group(1) == '}':
                return out, m.end()
            if m.group(1) == ',':
                p = m.end()
                continue
            if m.group(1) == '[':
                key, p = value(m.end())
                p = tok.match(text, p).end()      # ]
                p = tok.match(text, p).end()      # =
                out[key], p = value(p)
            else:
                v, p2 = value(p)
                eq = tok.match(text, p2)
                if eq and eq.group(1) == '=':   # bare name keys don't occur in SavedVariables, but be safe
                    out[v], p = value(eq.end())
                else:
                    out[n], p, n = v, p2, n + 1
    return value(pos)

for path in learned_paths:
    if not os.path.exists(path):
        print('not found:', path)
        continue
    text = open(path, encoding='utf-8-sig', errors='replace').read()
    m = re.search(r'^DressCodeDB\s*=\s*\{', text, re.M)
    if m:
        db, _ = lua_table(text, m.end() - 1)
        for r in (db.get('quests') or {}).values():
            names = len(r.get('n') or {})
            if r.get('heard') and names < 2:
                continue  # heard from only one player: not believable yet
            ids = '.'.join(str(i) for i in sorted(k for k, v in (r.get('i') or {}).items() if v))
            for faction, seen in (r.get('f') or {}).items():
                add_shared('^'.join(str(x) for x in (faction[0], seen, r.get('l', 0), r.get('c', 0), r.get('t', ''),
                                                     r.get('g', ''), r.get('z', ''), ids)), max(1, names))
        continue
    for line in text.splitlines():
        for code in re.findall(r'DC1:(.*)$', line):
            for entry in code.strip().strip('`').split('~'):
                add_shared(entry)
cfm_index = {(q[0].lower(), q[3]): i for i, q in enumerate(cfm_quests, 1)}
for (key, faction), s in sorted(shared.items()):
    idx = cfm_index.get((key, faction))
    if idx is None:
        # a quest Atlas-CFM doesn't know: its pick-up level is at most the lowest level players saw it at
        cfm_quests.append((s['title'], s['level'], s['zone'] or 'Unknown zone', faction, '', s['giver'],
                           'Seen in game by players from level %d (%d report%s).' % (s['seen'], s['reports'], '' if s['reports'] == 1 else 's'),
                           s['seen'], 0))
        idx = len(cfm_quests)
    for iid in sorted(s['ids']):
        if idx not in item_quests.get(iid, []):
            item_quests.setdefault(iid, []).append(idx)
        q = cfm_quests[idx - 1]
        label = 'Quest: %s (L%s, %s)' % (q[0], q[1] or '?', q[2])
        if label not in sources.get(iid, []):
            sources.setdefault(iid, []).insert(0, label)
if learned_paths:
    print('learned quests: %d merged, %d bad entries skipped' % (len(shared), bad_entries))

# --- quest rewards
for q in quests.values():
    label = 'Quest: %s (L%d)' % (q['title'], q['level'])
    for iid in q['rewards'] + q['choices']:
        sources.setdefault(iid, []).insert(0, label)

# --- Browse > Quests: one list per dungeon (Atlas-CFM), plus quests the client has opened
def entry_for(iid, extra):
    it = items.get(iid)
    return (iid, '', it['quality'] if it else 1, it['name'] if it else 'item %d' % iid, extra.replace('^', ' ').replace('~', ' '))

quest_rewards = {}
for iid, idxs in item_quests.items():
    for idx in idxs:
        quest_rewards.setdefault(idx, []).append(iid)
by_place = {}
for idx, q in enumerate(cfm_quests, 1):
    title, level, place, faction, classes = q[0], q[1], q[2], q[3], q[4]
    tag = 'Quest: %s (L%s%s%s)' % (title, level or '?', ', ' + faction if faction else '', ', ' + classes + ' only' if classes else '')
    for iid in quest_rewards.get(idx, []):
        by_place.setdefault(place, []).append(entry_for(iid, tag))
quest_lists = [(place + ' quests', entries) for place, entries in sorted(by_place.items())]
opened = []
for q in sorted(quests.values(), key=lambda q: q['level']):
    for iid in q['rewards'] + q['choices']:
        opened.append(entry_for(iid, 'Quest: %s (L%d)' % (q['title'], q['level'])))
if opened:
    quest_lists.insert(0, ('Quests you have opened', opened))
if quest_lists:
    browse.insert(1, ('Quests', quest_lists))

src_index, src_list = {}, []
def src_id(name):
    if name not in src_index:
        src_index[name] = len(src_list) + 1
        src_list.append(name)
    return src_index[name]

def lua_str(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

rows = []
for iid, i in sorted(items.items()):
    if i['cls'] not in (2, 4) or i['invtype'] not in EQUIP_TYPES:
        continue
    st = i['stats']
    srcs = []
    for s in sources.get(iid, []):
        sid = src_id(s)
        if sid not in srcs:
            srcs.append(sid)
    fields = [i['invtype'], i['cls'], i['sub'], i['quality'], i['req'], i['ilvl'], i['armor'],
              int(round(i['dmin'])), int(round(i['dmax'])), int(round(i['speed'] * 100)),
              st.get('sta', 0), st.get('int', 0), st.get('spi', 0), st.get('agi', 0), st.get('str', 0),
              i['aclass'], i['arace'], ';'.join(map(str, srcs[:4]))]
    rows.append('[%d]=%s,' % (iid, lua_str(','.join(map(str, fields)) + ',' + i['name'].replace(',', ' '))))

with open(out, 'w', encoding='utf-8', newline='\n') as f:
    f.write('-- Dress Code item data, generated from the WoW item and quest caches and AtlasLoot.\n')
    f.write('-- Items: id = "invtype,class,subclass,quality,reqlevel,itemlevel,armor,dmgmin,dmgmax,speed*100,'
            'sta,int,spi,agi,str,classmask,racemask,sources,name"\n')
    f.write('-- Browse: { category, { { list name, "id^icon^quality^name^extra~..." }, ... } }  (id "s<spell>/<made item>" = recipe)\n')
    f.write('DressCodeSources = {\n')
    for s in src_list:
        f.write('  %s,\n' % lua_str(s))
    f.write('}\nDressCodeItems = {\n')
    f.write('\n'.join(rows))
    f.write('\n}\nDressCodeBrowse = {\n')
    for category, tables in browse:
        f.write('  { %s, {\n' % lua_str(category))
        for label, entries in tables:
            packed = '~'.join('%s^%s^%d^%s^%s' % e for e in entries)
            f.write('    { %s, %s },\n' % (lua_str(label), lua_str(packed)))
        f.write('  } },\n')
    f.write('}\n')
    # quests: "title^level^instance^faction^classes^quest giver and location^note"
    f.write('DressCodeQuests = {\n')
    for q in cfm_quests:
        q = (q[0], q[1], q[7], q[8], q[2], q[3], q[4], q[5], q[6])  # title^level^minlevel^questid^instance^faction^classes^giver^note
        f.write('  %s,\n' % lua_str('^'.join(str(x).replace('^', ' ') for x in q)))
    f.write('}\nDressCodeItemQuests = {\n')
    for iid, idxs in sorted(item_quests.items()):
        f.write('[%d]="%s",\n' % (iid, ';'.join(map(str, sorted(set(idxs))))))
    f.write('}\n')
print('items', len(rows), 'sources', len(src_list), 'quests', len(quests),
      'browse', ', '.join('%s: %d lists' % (c, len(t)) for c, t in browse))
