# (b49) Link 11-13 "xuất 4k 9px hết rồi sao không lấy": every village tree/flower/house picture that has a split export in
# godot/ (matched by content size +-3 px and alpha-weighted colour, tools audit aud.json) is replaced by that export, pixel for pixel.
#   scenery n/sc/<j>.webp: the export cropped to its content, same top-left; sc.json v w,h follow the new size
#   objects d/o*.wasm: level 0 = the export pasted at the old picture's content corner on the old canvas; levels 1-4 made once from
#   it with Lanczos (as pko.py); bundles rewritten, identical pictures shared (dshare), info.json bh updated
# usage: python3 expswap.py SITE aud.json MAXDIFF
import sys, os, json, struct, io, zlib, hashlib
from PIL import Image
import numpy as np
SITE, AUD, MX = sys.argv[1], sys.argv[2], float(sys.argv[3])
G = '/mnt/project-files/nong-trai-chung/godot/'
R = json.load(open(AUD)); I = json.load(open(SITE + '/info.json')); S = json.load(open(SITE + '/n/sc.json'))
OLEV, Q = 5, 90
def enc(im, l):
    a = np.asarray(im)[..., 3]
    if a.max() == 0: return None
    b = io.BytesIO()
    if l < 2: im.save(b, 'WEBP', lossless=True, quality=100, method=6, exact=False)
    else: (im.convert('RGB') if a.min() == 255 else im).save(b, 'WEBP', quality=Q, method=4, **({} if a.min() == 255 else {'exact': False}))
    return b.getvalue()
def shrink(im0, l):
    if l == 0: return im0
    w, h = max(1, round(im0.width / 2 ** l)), max(1, round(im0.height / 2 ** l))
    return im0.convert('RGBa').resize((w, h), Image.LANCZOS).convert('RGBA')
def ex(f):
    im = Image.open(G + f).convert('RGBA'); return im.crop(im.getbbox())
done = []; newent = {}
for k, j, sz, *rest in R:
    b = rest[0] if rest else None
    if not b or b[1] > MX or b[1] < 0.05: continue
    if k == 'sc':
        p = '%s/n/sc/%d.webp' % (SITE, j); old = Image.open(p); e = ex(b[0])
        v = S['v'][j]; sx = v[2] / old.width; sy = v[3] / old.height
        if os.path.islink(p): os.remove(p)
        e.save(p, 'WEBP', lossless=True, quality=100, method=6, exact=False)
        S['v'][j] = [v[0], v[1], e.width * sx, e.height * sy]; done.append(('sc', j, b[0], b[1]))
    else:
        o = I['objs'][j]; old = Image.open('aud/o%d.webp' % j).convert('RGBA'); ob = old.getbbox(); e = ex(b[0])
        cv = Image.new('RGBA', old.size, (0, 0, 0, 0)); cv.alpha_composite(e.crop((0, 0, min(e.width, old.width - ob[0]), min(e.height, old.height - ob[1]))), (ob[0], ob[1]))
        for l in range(OLEV):
            nm = 'o%d_%d_%d' % (l, o[4], o[5]) if l < 2 else 'o%d' % l
            newent.setdefault(nm, {})[j] = enc(shrink(cv, l), l)
        done.append(('obj', j, o[6], b[0], b[1]))
json.dump(S, open(SITE + '/n/sc.json', 'w'))
for nm, E in newent.items():
    p = SITE + '/d/' + nm + '.wasm'; b = open(p, 'rb').read(); n = struct.unpack('<I', b[4:8])[0]
    ents = []
    for q in range(n):
        a, c, off, ln = struct.unpack('<hhII', b[8 + q * 12:20 + q * 12])
        ents.append((a, c, E[a] if (c == 0 and a in E) else b[off:off + ln]))
    ents = [x for x in ents if x[2]]
    hdr = bytearray(b'NTB1' + struct.pack('<I', len(ents))); base = 8 + 12 * len(ents); body = bytearray(); seen = {}
    for a, c, d in ents:
        h = hashlib.md5(d).digest()
        if h not in seen: seen[h] = base + len(body); body += d
        hdr += struct.pack('<hhII', a, c, seen[h], len(d))
    nb = bytes(hdr) + bytes(body)
    if os.path.islink(p): os.remove(p)
    open(p, 'wb').write(nb); I['bh'][nm] = '%08x' % zlib.crc32(nb)
json.dump(I, open(SITE + '/info.json', 'w'), separators=(',', ':'), ensure_ascii=False)
json.dump(done, open(SITE + '/expswap_done.json', 'w'), ensure_ascii=False)
print('replaced', len(done), 'bundles rewritten', len(newent))
