# Builds the two sheets from the per-pixel plants:
#   python3 atlas.py OUTDIR [OLD_HOACO.webp OLD_HOACO.json]
# -> OUTDIR/caycanh2.webp + caycanh2.json (7 one-tile kinds x 4 seeds, d/n)
# -> OUTDIR/hoaco2.webp + hoaco2.json (the 7 new minis re-rendered; every other mini frame copied from the old sheet)
import sys, os, json, time
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cay

RS = 5


def crop(im, bb):
    a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 3)
    x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
    return im.crop((x0, y0, x1, y1)), bb[0] + x0 / RS, bb[1] + y0 / RS


def pack(crops, path, tab, cols):
    x = y = rowh = 0; pos = {}
    for k, (name, im, dx, dy) in enumerate(crops):
        if k and k % cols == 0: x = 0; y += rowh + 2; rowh = 0
        pos[name] = (x, y); x += im.width + 2; rowh = max(rowh, im.height)
    Wt = max(pos[n][0] + im.width for n, im, _, _ in crops); Ht = y + rowh
    out = Image.new('RGBA', (Wt, Ht), (0, 0, 0, 0)); table = {}
    for name, im, dx, dy in crops:
        sx, sy = pos[name]; out.paste(im, (sx, sy))
        table[name] = [sx, sy, im.width, im.height, round(dx, 2), round(dy, 2), round(im.width / RS, 2), round(im.height / RS, 2)]
    out.save(path, 'WEBP', quality=90, alpha_quality=100, method=6)
    json.dump(table, open(tab, 'w'), separators=(',', ':'))
    print(path, out.size, os.path.getsize(path))


def frames(kinds, bb):
    out = []
    for night in (False, True):
        for k in kinds:
            for s in range(4):
                t = time.time()
                im, dx, dy = crop(cay.render(k, s, night), cay.BB_KIND.get(k, bb) if hasattr(cay, 'BB_KIND') else bb)
                out.append(('nd'[not night] + k + str(s), im, dx, dy))
                print(k, s, night, '%.1fs' % (time.time() - t), flush=True)
    return out


if __name__ == '__main__':
    od = sys.argv[1]
    which = sys.argv[4] if len(sys.argv) > 4 else 'both'
    if which in ('both', 'big'):
        pack(frames(cay.BIG, cay.BB_BIG), os.path.join(od, 'caycanh4.webp'), os.path.join(od, 'caycanh4.json'), 10)
    if which in ('both', 'small') and len(sys.argv) > 3:
        old = Image.open(sys.argv[2]).convert('RGBA'); ot = json.load(open(sys.argv[3]))
        cr = []
        for name, v in ot.items():
            if name[1:-1] in cay.SMALL: continue
            cr.append((name, old.crop((v[0], v[1], v[0] + v[2], v[1] + v[3])), v[4], v[5]))
        cr += frames(cay.SMALL, cay.BB_SMALL)
        cr.sort(key=lambda z: (z[0][0], z[0][1:]))
        pack(cr, os.path.join(od, 'hoaco5.webp'), os.path.join(od, 'hoaco5.json'), 16)
