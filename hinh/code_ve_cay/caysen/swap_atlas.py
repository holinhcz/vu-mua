# Re-ship a new caysen sheet on a build that already has /*cs0*/ and /*cs1*/: swap the G table and the lua/bap wG box.
#   python3 swap_atlas.py in.html atlas.json out.html     (then publish out.html + img/caysen.webp)
import sys, json, re
src, atl, out = sys.argv[1:4]
s = open(src).read(); G = json.load(open(atl))
assert '/*cs0*/' in s and '/*cs1*/' in s

def obj_end(s, i):
    d = 0; j = i
    while True:
        c = s[j]
        if c == '{': d += 1
        elif c == '}':
            d -= 1
            if d == 0: return j + 1
        j += 1

i = s.index('/*cs0*/'); j = s.index(',G=', i) + 3; e = obj_end(s, j)
s = s[:j] + json.dumps(G, separators=(',', ':')) + s[e:]
fr = [v for k, v in G.items() if k[1:4] in ('lua', 'bap')]
LX = int(max(max(-v[4], v[4] + v[6]) for v in fr) + 2)
m = re.search(r'var o=LU\?-\d+:-26,l=-\(ou\[a\]\+30\),c=LU\?\d+:52,', s); assert m
s = s[:m.start()] + 'var o=LU?-%d:-26,l=-(ou[a]+30),c=LU?%d:52,' % (LX, 2 * LX) + s[m.end():]
open(out, 'w').write(s); print('ok LX', LX, len(s))
