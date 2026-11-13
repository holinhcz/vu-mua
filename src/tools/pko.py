# objects (houses, sheds, plots...) for the native Godot village at the export's own px/unit: NO downscale
# (2026-11-12 Link: everything was blurry because pk.py cut the 8 px export to 6). Level 0 = OBJ_PXU (9), levels 1..4 = halves.
# usage: python3 pko.py OBJDIR GDDIR   (rewrites GDDIR/d/o*.wasm and objs/bundles/bh in GDDIR/info.json)
import sys, os, json, glob, zlib
from PIL import Image
import io, struct
import numpy as np
OD, GD = sys.argv[1:3]
OLEV, Q = 5, int(os.environ.get('Q', '90'))
def enc(im, l):
    a = np.asarray(im)[..., 3]
    if a.max() == 0: return None
    b = io.BytesIO()
    # sharp levels (0, 1) keep every pixel and colour exactly (lossless); only far-away levels are lossy
    if l < 2:
        im.save(b, 'WEBP', lossless=True, quality=100, method=6, exact=False)
    else:
        (im.convert('RGB') if a.min() == 255 else im).save(b, 'WEBP', quality=Q, method=4, **({} if a.min() == 255 else {'exact': False}))
    return b.getvalue()
def shrink(im0, l):
    # every level made ONCE from the 9 px original with Lanczos (Link 11-12 'chưa nét như web'): no chained box halves
    if l == 0: return im0
    w, h = max(1, round(im0.width / 2 ** l)), max(1, round(im0.height / 2 ** l))
    return im0.convert('RGBa').resize((w, h), Image.LANCZOS).convert('RGBA')
def bundle(path, ents):
    ents = [e for e in ents if e[2]]
    hdr = b'NTB1' + struct.pack('<I', len(ents)); off = 8 + 12 * len(ents); body = b''
    for a, b_, d in ents:
        hdr += struct.pack('<hhII', a, b_, off + len(body), len(d)); body += d
    open(path, 'wb').write(hdr + body)
    return len(hdr) + len(body)
info = json.load(open(f'{GD}/info.json'))
X0, Y0 = info['X0'], info['Y0']
for f in glob.glob(f'{GD}/d/o*.wasm'):
    os.remove(f)
L = json.load(open(f'{OD}/list.json'))
objs = []; og = {}
for r_ in L:
    if r_.get('e'):
        continue
    j = len(objs)
    im = Image.open(f'{OD}/{r_["f"]}').convert('RGBA')
    cx = int((r_['x'] + r_['w'] / 2 - X0) // 2048); cy = int((r_['y'] + r_['h'] / 2 - Y0) // 2048)
    objs.append([r_['x'], r_['y'], r_['w'], r_['h'], cx, cy, r_.get('kind', '')] + ([r_['pc']] if r_.get('pc') else []))   # 8th: lot that must be bought first (web tc())
    for l in range(OLEV):
        nm = f'o{l}_{cx}_{cy}' if l < 2 else f'o{l}'
        og.setdefault(nm, []).append((j, 0, enc(shrink(im, l), l)))
osz = {nm: bundle(f'{GD}/d/{nm}.wasm', e) for nm, e in og.items()}
info['objs'] = objs
info['bundles'] = sorted(og)
info['bh'] = {nm: format(zlib.crc32(open(f'{GD}/d/{nm}.wasm', 'rb').read()), '08x') for nm in info['bundles']}
json.dump(info, open(f'{GD}/info.json', 'w'))
print('objects', len(objs), 'bundles', len(og), 'MB', round(sum(osz.values()) / 1e6, 1))
