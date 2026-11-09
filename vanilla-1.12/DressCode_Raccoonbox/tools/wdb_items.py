"""Parse a 1.12 (build 5875) itemcache.wdb into item records with stats."""
import struct, sys, json

STATS = {0: 'mana', 1: 'health', 3: 'agi', 4: 'str', 5: 'int', 6: 'spi', 7: 'sta'}
INVTYPE = {1: 'Head', 2: 'Neck', 3: 'Shoulder', 4: 'Shirt', 5: 'Chest', 6: 'Waist', 7: 'Legs', 8: 'Feet',
           9: 'Wrist', 10: 'Hands', 11: 'Finger', 12: 'Trinket', 13: 'One-Hand', 14: 'Shield', 15: 'Ranged',
           16: 'Back', 17: 'Two-Hand', 18: 'Bag', 19: 'Tabard', 20: 'Chest', 21: 'Main Hand', 22: 'Off Hand',
           23: 'Held In Off-hand', 24: 'Ammo', 25: 'Thrown', 26: 'Ranged', 28: 'Relic'}


def cstr(b, o):
    e = b.index(b'\0', o)
    return b[o:e].decode('utf-8', 'replace'), e + 1


def parse(path):
    b = open(path, 'rb').read()
    off, items = 20, {}
    while off + 8 <= len(b):
        iid, size = struct.unpack_from('<II', b, off)
        rec = b[off + 8: off + 8 + size]
        off += 8 + size
        if size < 100:
            continue
        try:
            o = 0
            cls, sub = struct.unpack_from('<II', rec, o); o += 8
            name, o = cstr(rec, o)
            for _ in range(3):
                _, o = cstr(rec, o)
            (display, quality, flags, buy, sell, invtype, aclass, arace, ilvl, reqlvl, reqskill, reqskillrank,
             reqspell, reqhonor, reqcity, reqfac, reqfacrank, maxcount, stack, slots) = struct.unpack_from('<IIIIIIiiIIIIIIIIIIII', rec, o)
            o += 80
            stats = {}
            for _ in range(10):
                t, v = struct.unpack_from('<Ii', rec, o); o += 8
                if v and t in STATS:
                    stats[STATS[t]] = stats.get(STATS[t], 0) + v
            dmin = dmax = 0.0
            for i in range(5):
                lo, hi, dt = struct.unpack_from('<ffI', rec, o); o += 12
                if i == 0:
                    dmin, dmax = lo, hi
            armor = struct.unpack_from('<I', rec, o)[0]; o += 4
            res = struct.unpack_from('<6I', rec, o); o += 24
            delay = struct.unpack_from('<I', rec, o)[0]; o += 4
            o += 8  # ammo type, ranged mod
            spells = []
            for _ in range(5):
                sid, trig, charges, cd, cat, catcd = struct.unpack_from('<IIiiII', rec, o); o += 24
                if sid:
                    spells.append((sid, trig))
            bonding = struct.unpack_from('<I', rec, o)[0]; o += 4
            desc, o = cstr(rec, o)
            items[iid] = dict(id=iid, name=name, cls=cls, sub=sub, quality=quality, slot=INVTYPE.get(invtype, str(invtype)),
                              invtype=invtype, aclass=aclass, arace=arace, ilvl=ilvl, req=reqlvl, stats=stats,
                              armor=armor, dmin=dmin, dmax=dmax, speed=delay / 1000.0, spells=spells, bonding=bonding,
                              res=list(res), reqskill=reqskill, reqhonor=reqhonor)
        except (struct.error, ValueError):
            continue
    return items


if __name__ == '__main__':
    items = parse(sys.argv[1])
    json.dump(items, open(sys.argv[2], 'w'))
    print('parsed', len(items), 'items')
