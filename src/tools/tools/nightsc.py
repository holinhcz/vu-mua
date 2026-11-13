# (b54) scenery pictures n/sc/<i>.webp: find the godot/ export DAY frame each one is (same size, near-identical pixels),
# then write its NIGHT frame as n/sc/<i>n.webp (same crop box) and list it in sc.json "n": {i: 1}. Unmatched ones keep
# the night formula. usage: python3 nightsc.py SITE
import sys, os, json, io, glob
import numpy as np
from PIL import Image
SITE = sys.argv[1]; G = '/mnt/project-files/nong-trai-chung/godot/'
def nkey(k):
    if k.endswith('d'): return k[:-1] + 'n'
    if '_d' in k: return k.replace('_d', '_n', 1)
    if k.startswith('d'): return 'n' + k[1:]
    return None
IDX = {}
for at in glob.glob(G + '*/*/atlas.json'):
    fd = os.path.dirname(at); A = json.load(open(at)); F = A.get('frames')
    if not isinstance(F, dict): continue
    if A.get('px_per_unit', 9) != 9: continue
    for k, f in F.items():
        nk = nkey(k)
        if not nk or nk not in F: continue
        if not isinstance(f, dict) or 'file' not in f or not isinstance(F[nk], dict): continue
        try: im = Image.open(fd + '/' + f['file']).convert('RGBA')
        except Exception: continue
        bb = im.getbbox()
        if not bb: continue
        IDX.setdefault((bb[2] - bb[0], bb[3] - bb[1]), []).append((fd, f, F[nk], bb))
print('day frames', sum(len(v) for v in IDX.values()))
S = json.load(open(SITE + '/n/sc.json')); got = {}
BYW = {}
for (w, h), L in IDX.items():
    for e in L: BYW.setdefault(w, []).append((h, e))
for fn in sorted(glob.glob(SITE + '/n/sc/*.webp')):
    b = os.path.basename(fn)[:-5]
    if not b.isdigit(): continue
    v = Image.open(fn).convert('RGBA'); va = np.asarray(v)[..., 3].astype(np.float32); best = None
    # match on the SHAPE (alpha): the scenery copy can be recoloured or padded, the outline is the export's own
    for dw in (-2, -1, 0, 1, 2):
        for h, (fd, f, nf, bb) in BYW.get(v.width + dw, []):
            if abs(h - v.height) > 130: continue
            ea = np.asarray(Image.open(fd + '/' + f['file']).convert('RGBA').crop(bb))[..., 3].astype(np.float32)
            W = min(ea.shape[1], va.shape[1])
            for oy in range(-abs(v.height - h) - 1, abs(v.height - h) + 2):
                # export row r sits at scenery row r + oy
                r0 = max(0, -oy); r1 = min(ea.shape[0], va.shape[0] - oy)
                if r1 - r0 < 0.8 * min(ea.shape[0], va.shape[0]): continue
                d = float(np.abs(ea[r0:r1, :W] - va[r0 + oy:r1 + oy, :W]).mean())
                if best is None or d < best[0]: best = (d, fd, f, nf, bb, oy)
    if best and best[0] < 4:
        d, fd, f, nf, bb, oy = best
        ni = Image.open(fd + '/' + nf['file']).convert('RGBA')
        dx = round((nf['ox'] - f['ox']) * 9); dy = round((nf['oy'] - f['oy']) * 9)
        nc = ni.crop((bb[0] - dx, bb[1] - dy, bb[2] - dx, bb[3] - dy))
        out = Image.new('RGBA', v.size, (0, 0, 0, 0)); out.paste(nc, (0, oy))
        bio = io.BytesIO(); out.save(bio, 'WEBP', lossless=True, quality=100, method=4, exact=False)
        open('%s/n/sc/%sn.webp' % (SITE, b), 'wb').write(bio.getvalue()); got[b] = 1
        print(b, os.path.relpath(fd, G), f['file'], round(d, 2), oy)
    else:
        print(b, 'NO', best and round(best[0], 1))
S['n'] = got
json.dump(S, open(SITE + '/n/sc.json', 'w'), separators=(',', ':'))
print('matched', len(got))
