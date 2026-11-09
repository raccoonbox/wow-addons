"""Parse a 1.12 (build 5875) questcache.wdb: quest title, level and reward item ids."""
import struct, sys


def parse(path):
    b = open(path, 'rb').read()
    off, quests = 20, {}
    while off + 8 <= len(b):
        qid, size = struct.unpack_from('<II', b, off)
        rec = b[off + 8: off + 8 + size]
        off += 8 + size
        if size < 160:
            continue
        try:
            v = struct.unpack_from('<39i', rec, 0)
            # 0 id 1 method 2 level 3 zone 4 type 5-8 rep 9 next 10 money 11 money@max 12 spell 13 srcitem 14 flags
            # 15-22 reward item/count x4, 23-34 choice item/count x6, 35 map 36-37 x,y (floats) 38 opt
            o = 39 * 4
            e = rec.index(b'\0', o)
            title = rec[o:e].decode('utf-8', 'replace')
            rewards = [v[i] for i in range(15, 23, 2) if v[i] > 0]
            choices = [v[i] for i in range(23, 35, 2) if v[i] > 0]
            quests[qid] = dict(id=qid, level=v[2], title=title, rewards=rewards, choices=choices)
        except (struct.error, ValueError):
            continue
    return quests


if __name__ == '__main__':
    import json
    q = parse(sys.argv[1])
    print(len(q), 'quests')
    for x in list(q.values())[:6]:
        print(x)
