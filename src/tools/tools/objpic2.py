# (b51) second pass of objpic.py: every object that still has its own village picture gets the closest DAY frame of its
# kind's export folder in godot/ (size within TOL px at 9 px/unit, then smallest alpha-weighted colour difference).
# The export keeps its own size; it stands on the same foot point (bottom centre of the content box) as before.
# Objects drawn live by Godot code (hives) get op = ["~hive", ...]. Pictures no placement uses any more are deleted.
# usage: python3 objpic2.py SITE OBJPICDIR
import sys, os, json, io, glob
import numpy as np
from PIL import Image
SITE, OD = sys.argv[1:3]
G = '/mnt/project-files/nong-trai-chung/godot/'
KF = {'banana': 'caytrai/chuoi', 'areca': 'caylang/cau', 'bamboo': 'caylang/tre', 'coconut': 'caytrai/dua', 'papaya': 'caytrai/dudu',
      'reed': 'caydai/co_lau', 'haystack': 'caylang/rom', 'shrine': 'congtrinh/shrine', 'banyan': 'caylang/da', 'lotus': 'thuysinh/sen',
      'lantern': 'congtrinh/lantern', 'dao': 'kieng/dao', 'boat': 'congtrinh/ghe', 'bridge2': 'congtrinh/caukhi'}
TOL = 40
I = json.load(open(SITE + '/info.json'))
def pm(a):
    a = a.astype(np.float32); a[..., :3] *= a[..., 3:4] / 255.0; return a
def frames(fd):
    A = json.load(open(G + fd + '/atlas.json')); ppu = A.get('px_per_unit', 9); out = []
    for k, f in A['frames'].items():
        day = (k.startswith('d') and not k.startswith('dw')) or (len(k) == 2 and k[1] == 'd')
        if not day: continue
        if fd == 'kieng/dao' and not (4 <= int(k[1:]) <= 7): continue   # dao: the hạ (summer) frames; seasons come later
        im = Image.open(G + fd + '/' + f['file']).convert('RGBA'); im = im.crop(im.getbbox())
        if ppu != 9: im = im.resize((round(im.width * 9 / ppu), round(im.height * 9 / ppu)), Image.LANCZOS)
        out.append((fd + '/' + f['file'], im, ppu))
    return out
FC = {}
op = I['op']; rep = []
for j, o in enumerate(I['objs']):
    r = op[j]
    if not r: continue
    kind = str(o[6]).split(':')[0]
    if kind in ('plot', 'parcel'): op[j] = None; continue
    if kind not in ('lantern', 'dao', '') and r[0].split('-')[0] in ('caytrai', 'caylang', 'caydai', 'kieng', 'congtrinh', 'thuysinh', 'hoaco', 'caytrong'): continue
    if kind == '':
        if r[3] > 60: kind = 'bridge2'
        else:
            # hive anchor = centre of the comb (the web's ellipse 5.4 x 9): centroid of its honey-coloured pixels
            v = np.asarray(Image.open('%s/o%d.webp' % (OD, j)).convert('RGBA')).astype(int)
            m = (abs(v[..., 0] - 201) < 12) & (abs(v[..., 1] - 138) < 12) & (abs(v[..., 2] - 46) < 12) & (v[..., 3] > 250)
            yy, xx = np.nonzero(m)
            op[j] = ['~hive', round(o[0] + xx.mean() / 9.0, 2), round(o[1] + yy.mean() / 9.0, 2), 0, 0]; continue
    fd = KF.get(kind)
    if not fd: print('NO EXPORT FOLDER', j, kind); continue
    if fd not in FC: FC[fd] = frames(fd)
    v = Image.open('%s/o%d.webp' % (OD, j)).convert('RGBA'); vb = v.getbbox(); v = v.crop(vb)
    r = [None, o[0] + vb[0] / 9.0, o[1] + vb[1] / 9.0, v.width / 9.0, v.height / 9.0]   # the village copy's content box
    best = None
    clip = kind in ('lantern', 'dao')   # the village's copies of these were cut off at the bottom: compare the top part only
    for path, im, ppu in FC[fd]:
        if clip:
            if abs(im.width - v.width) > 120 or im.height < v.height: continue
            a = pm(np.asarray(v)); B = pm(np.asarray(im)); bx = None
            for x0 in range(0, max(1, im.width - v.width + 1)):
                dd = float(np.abs(a - B[:v.height, x0:x0 + v.width]).mean()) if x0 + v.width <= im.width else 1e9
                if bx is None or dd < bx[0]: bx = (dd, x0)
            if best is None or bx[0] < best[0]: best = (bx[0], path, im, ppu, bx[1])
            continue
        else:
            if abs(im.width - v.width) > TOL or abs(im.height - v.height) > TOL: continue
            a = pm(np.asarray(v.resize(im.size, Image.LANCZOS))); b = pm(np.asarray(im))
        d = float(np.abs(a - b).mean())
        if best is None or d < best[0]: best = (d, path, im, ppu, 0)
        d = float(np.abs(a - b[:, ::-1]).mean())   # placed mirrored (the web flips some bridges)
        if d < best[0]: best = (d, path, im, ppu, -1)
    if not best: print('NO SIZE MATCH', j, kind, v.size, [x[1].size for x in FC[fd]]); continue
    d, path, im, ppu, cx0 = best
    name = path[:-4].replace('/', '-')
    fn = '%s/n/op/%s.webp' % (SITE, name)
    if not os.path.exists(fn):
        e = Image.open(G + path).convert('RGBA'); e = e.crop(e.getbbox())
        bio = io.BytesIO(); e.save(bio, 'WEBP', lossless=True, quality=100, method=6, exact=False); open(fn, 'wb').write(bio.getvalue())
    w, h = im.width / 9.0, im.height / 9.0
    fx = r[1] + r[3] / 2; fy = r[2] + r[4]
    tx, ty = fx - w / 2, fy - h
    if clip: tx, ty = r[1] - cx0 / 9.0, r[2]   # same top-left as the cut copy, full picture
    op[j] = [name, round(tx, 3), round(ty, 3), round(w, 3), round(h, 3)] + ([1] if cx0 == -1 else [])
    rep.append((j, kind, name, round(d, 1)))
used = set(x[0] for x in op if x)
for f in glob.glob(SITE + '/n/op/*.webp'):
    if os.path.basename(f)[:-5] not in used: os.remove(f)
# opb: name -> [ox, oy, gw, gh] of the stored (content-cropped) picture, game units from the export's anchor (for the shop)
opb = {}
for nm in used:
    if nm.startswith('~'): continue
    p = nm.split('-'); fd = p[0] + '/' + p[1]; fk = '-'.join(p[2:])
    if len(p) < 3 or not os.path.exists(G + fd + '/atlas.json'): print('NOT AN EXPORT', nm); continue
    A = json.load(open(G + fd + '/atlas.json')); f = A['frames'].get(fk); ppu = A.get('px_per_unit', 9)
    if not f: continue
    e = Image.open(G + fd + '/' + f['file']).convert('RGBA'); bb = e.getbbox()
    opb[nm] = [round(f['ox'] + bb[0] / ppu, 3), round(f['oy'] + bb[1] / ppu, 3), round((bb[2] - bb[0]) / ppu, 3), round((bb[3] - bb[1]) / ppu, 3)]
I['opb'] = opb
json.dump(I, open(SITE + '/info.json', 'w'), separators=(',', ':'), ensure_ascii=False)
for x in rep: print(*x)
print('files', len(used), 'hives', sum(1 for x in op if x and x[0] == '~hive'))
