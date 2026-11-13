# scenery sprites for the native Godot ground: one picture per variant + instance list in draw order.
# Pictures keep the export's own pixels (se2.js draws each kind at its source sheet's px/unit, 5 or 9, frames pasted 1:1):
# NO downscale (2026-11-12 Link: the old x0.75 cut made every tree blurry). The hill (thacnui) keeps the cleaned
# picture made by tools/fallrock.py (OLDDIR/sc/<j>.webp + its rect from OLDDIR/sc.json).
# usage: python3 pks.py SCDIR OUTDIR OLDDIR
import sys, json, os, io
from multiprocessing import Pool
from PIL import Image
SD, OUT, OLD = sys.argv[1:4]
OV = json.load(open(OLD + '/sc.json'))['v']
os.makedirs(OUT + '/sc', exist_ok=True)
d = json.load(open(SD + '/list.json'))
M = {k: v for k, v in d['meta'].items() if 'f' in v}
keys = sorted(M)
def one(j):
    m = M[keys[j]]
    if '|thacnui|' in keys[j]:
        import shutil; shutil.copy(f'{OLD}/sc/{j}.webp', f'{OUT}/sc/{j}.webp'); v = OV[j]
        w, h = Image.open(f'{OLD}/sc/{j}.webp').size
        return [v[0], v[1], v[2], v[3], w * h]
    im = Image.open(SD + '/' + m['f']).convert('RGBA'); w, h = im.size
    bb = im.getbbox()
    if not bb: return None
    im = im.crop(bb)
    im.save(f'{OUT}/sc/{j}.webp', 'WEBP', lossless=True, quality=100, method=6, exact=False)   # every pixel kept (Link 11-12 'nét 4k')
    sx = m['w'] / w; sy = m['h'] / h   # world units per pixel
    return [m['x'] + bb[0] * sx, m['y'] + bb[1] * sy, (bb[2] - bb[0]) * sx, (bb[3] - bb[1]) * sy, w * h]
if __name__ == '__main__':
    V = Pool(4).map(one, range(len(keys)))
    idx = {k: j for j, k in enumerate(keys)}
    I = sorted(d['inst'], key=lambda r: r['k'])
    # road verges (dg_rao) are made by the Godot code from the road map, not placed from the export; the cống (dg_cong,
    # a sluice with its own bit of channel at the ditch's end) is gone (Link 2026-11-12 "đoạn nước đó bỏ xoá code đi")
    inst = [[idx[r['v']], round(r['x'], 2), round(r['y'], 2), r['sw'], round(r['k'], 4)] for r in I if r['v'] in idx and V[idx[r['v']]] and '|dg_rao|' not in r['v'] and '|dg_cong|' not in r['v']]
    json.dump({'v': [v[:4] if v else None for v in V], 'i': inst}, open(OUT + '/sc.json', 'w'))
    print('variants', len(keys), 'inst', len(inst), 'decoded MB', round(sum(v[4] for v in V if v) * 4 / 1e6, 1))
