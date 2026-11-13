# (b47) after pks.py: kinds whose picture file is byte-identical share one file (sc.json "f"[j] = file index), and
# pictures no placed instance uses are listed; both kinds of file are left out of the publish (the game never asks for them).
# usage: python3 scshare.py SITE/n  -> rewrites SITE/n/sc.json, writes SITE/n/sc_skip.txt (published paths to drop)
import json, sys, hashlib, collections
N = sys.argv[1]; S = json.load(open(N + '/sc.json'))
c = collections.Counter(r[0] for r in S['i'])
first = {}; F = []; skip = []
for j in range(len(S['v'])):
    if not c[j]:
        F.append(j); skip.append(j); continue
    h = hashlib.md5(open('%s/sc/%d.webp' % (N, j), 'rb').read()).hexdigest()
    if h in first: F.append(first[h]); skip.append(j)
    else: first[h] = j; F.append(j)
S['f'] = F
json.dump(S, open(N + '/sc.json', 'w'))
open(N + '/sc_skip.txt', 'w').write('\n'.join('n/sc/%d.webp' % j for j in skip))
print('kinds', len(F), 'files kept', len(first), 'dropped', len(skip))
