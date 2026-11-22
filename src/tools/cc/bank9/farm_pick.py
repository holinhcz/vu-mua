# Bờ bên kia kênh (câu cá) = ghép ẢNH 9px CÓ SẴN của Nông trại (godot/caytrai, caylang, caydai, hoaco, thuysinh, congtrinh),
# KHÔNG vẽ lại. Mỗi khung 1 file (ngày + đêm), chỉ bỏ cái bóng tròn dưới gốc (game nông trại nhìn từ trên xuống,
# bờ kênh nhìn ngang) và cắt bớt lề trống. Chỗ đứng từng món lấy theo bố cục bờ cũ (rec9 = bank2.py hạt giống 21).
# Bờ đất + mép cỏ do Godot vẽ bằng code với ảnh nền n2_co / dg2_dat của Nông trại.
#   python3 farm_pick.py OUT
import sys, os, json, math, random
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import numpy as np
from PIL import Image
import rec9
from bank2 import WL, BW, BH, ground, CREEK

G = '/mnt/project-files/nong-trai-chung/godot/'
NT = '/mnt/project-files/nong-trai-chung/img/'
OUT = sys.argv[1]
NHA = sys.argv[2] if len(sys.argv) > 2 else None     # nha_ngang.py OUT: nhà tranh nhìn ngang
os.makedirs(OUT, exist_ok=True)

def night_key(k):
    if k.startswith('d'):
        return 'n' + k[1:]
    if k.endswith('d'):
        return k[:-1] + 'n'
    return k

def unshadow(a, ax, ay, rx, ry):
    """bóng đổ của nông trại = vệt gần đen, mờ (alpha 25..80) quanh gốc -> bỏ; chỉ trong vùng bầu dục quanh gốc
    (mép lá viền tối ở trên tán giữ nguyên)"""
    al = a[..., 3].astype(np.int32)
    lum = a[..., :3].astype(np.int32).max(-1)
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    near = ((xx - ax) / rx) ** 2 + ((yy - ay) / ry) ** 2 < 1.0
    m = (al < 120) & (lum < 48) & near
    a = a.copy(); a[m, 3] = 0
    return a

used = {}
def frame(dir_, key):
    nm = dir_.split('/')[-1] + '_' + key
    if nm in used:
        return nm
    at = json.load(open(G + dir_ + '/atlas.json'))
    fr = at['frames']; ppu = float(at.get('px_per_unit', 9))
    f = fr[key]; nk = night_key(key)
    ax0, ay0 = -f['ox'] * ppu, -f['oy'] * ppu
    rx, ry = f['gw'] * ppu * .62, f['gw'] * ppu * .33
    d = unshadow(np.asarray(Image.open(G + dir_ + '/' + f['file']).convert('RGBA')), ax0, ay0, rx, ry)
    n = unshadow(np.asarray(Image.open(G + dir_ + '/' + fr[nk]['file']).convert('RGBA')), ax0, ay0, rx, ry) if nk in fr else d
    if n.shape != d.shape:
        n = d
    al = np.maximum(d[..., 3], n[..., 3])
    ys, xs = np.nonzero(al > 0)
    x0, x1, y0, y1 = max(0, xs.min() - 2), min(d.shape[1], xs.max() + 3), max(0, ys.min() - 2), min(d.shape[0], ys.max() + 3)
    Image.fromarray(d[y0:y1, x0:x1], 'RGBA').save(os.path.join(OUT, nm + '_d.webp'), lossless=True, quality=100, method=4)
    Image.fromarray(n[y0:y1, x0:x1], 'RGBA').save(os.path.join(OUT, nm + '_n.webp'), lossless=True, quality=100, method=4)
    used[nm] = dict(w=int(x1 - x0), h=int(y1 - y0), ax=round(-f['ox'] * ppu - x0, 1), ay=round(-f['oy'] * ppu - y0, 1), ppu=ppu,
                    gh=f['gh'], gw=f['gw'])
    print(nm, used[nm]['w'], used[nm]['h'], flush=True)
    return nm

FOL = {'dua', 'xoai', 'chomchom', 'mit', 'chuoi2', 'dambut', 'bui_cay', 'dien_dien', 'duanuoc2', 'luc_binh', 'bui_co', 'c_xanh', 'c_lau', 'tre'}
place = []
def put(L, dir_, key, x, y, k, flip=False):
    """k = số đơn vị bờ cho 1 đơn vị game nông trại"""
    nm = frame(dir_, key)
    sc = k / used[nm]['ppu']
    place.append([L, nm, round(x, 1), round(y, 1), round(-sc if flip else sc, 4), 1 if dir_.split('/')[-1] in FOL else 0])

nm_meta = json.load(open(os.path.join(NHA, 'nha.json'))) if NHA else {}
def put_nha(L, nm, x, y, k, flip=False):
    if nm not in used:
        for m in ('d', 'n'):
            Image.open(os.path.join(NHA, '%s_%s.webp' % (nm, m))).save(os.path.join(OUT, '%s_%s.webp' % (nm, m)), lossless=True, quality=100, method=4)
        mm = nm_meta[nm]; used[nm] = dict(w=mm['w'], h=mm['h'], ax=mm['ax'], ay=mm['ay'], ppu=mm['ppu'])
    sc = k / used[nm]['ppu']
    place.append([L, nm, round(x, 1), round(y, 1), round(-sc if flip else sc, 4), 0])

cnt = {}
for L, key, a, kw in rec9.rec:
    n = cnt[key] = cnt.get(key, -1) + 1
    if key == 'dua':
        x, y, h, ln = a[0], a[1], a[2], a[3]
        put(L, 'caytrai/dua', ['d00', 'd10', 'd01', 'd11'][n % 4], x, y, 1.2 * h / 160.8, ln < 0)
    elif key == 'bui':
        x, y, rx = a[0], a[1], a[2]
        put(L, 'caydai/bui_cay', 'd%d' % (n % 4), x, y + (12 if L == 0 else 14), 2.3 * rx / 67.3, n % 2 == 1)
    elif key == 'cay':
        x, y, h, fr = a[0], a[1], a[2], a[4]
        if fr == 'xoai': put(L, 'caytrai/xoai', 'dx0%d' % (n % 2), x, y, 1.2 * h / 77.1, n % 2 == 1)
        elif fr == 'chom': put(L, 'caytrai/chomchom', 'd00', x, y, 1.2 * h / 79.1, n % 2 == 1)
        else: put(L, 'caytrai/mit', 'd01', x, y, 1.2 * h / 90.7)
    elif key == 'chuoi':
        x, y, s = a[0], a[1], a[2]
        put(L, 'caytrai/chuoi2', ['d00', 'd10'][n % 2], x, y, 240 * s / 105.3, n % 3 == 1)
    elif key == 'dambut':
        x, y, w = a[0], a[1], a[2]
        put(L, 'caylang/dambut', 'd%d' % (n % 4), x, y, 1.25 * w / 74, n % 2 == 1)
    elif key == 'diendien':
        x, y, s = a[0], a[1], a[2]
        put(L, 'thuysinh/dien_dien', ['ddd1a', 'ddd2a', 'ddd1b'][n % 3], x, y, 190 * s / 60.2, n % 2 == 1)
    elif key == 'duanuoc':
        x, y, s = a[0], a[1], a[2]
        put(L, 'caylang/duanuoc2', 'd%d' % (n % 2), x, y + 6, 230 * s / 80.6, n % 3 == 1)
    elif key == 'lucbinh':
        x, y, s = a[0], a[1], a[2]; fl = a[3] if len(a) > 3 else True
        put(L, 'thuysinh/luc_binh', ('dlbf%d' % (n % 3)) if fl else ('dlb%d' % (n % 6)), x, y + 4, 4.2 * s, n % 2 == 1)
    elif key == 'nha':
        x, y, s = a[0], a[1], a[2]
        if s > 1:   # nhà chính bên kênh + bến ghe
            put_nha(L, 'nha_lon', x, ground(x) + 7, 3.3)
        else:
            put_nha(L, 'nha_nho', x, y + 2, 4.3 * s, n % 2 == 1)
    elif key == 'mieu':
        put(L, 'congtrinh/shrine', 'bd', a[0], a[1] - 8, 2.2)
    elif key == 'bo':
        place.append([L, '#bo', 0, 0, 0, 0])            # bờ đất + mép cỏ do code vẽ, đúng thứ tự này
        R = random.Random(8)
        x = -30
        while x < BW + 30:                             # bụi cỏ, cỏ lau trên mép bờ
            if not (CREEK[0] - 20 < x < CREEK[1] + 20) or True:
                r = R.random()
                if r < .45: put(L, 'caydai/bui_co', 'd%d' % R.randint(0, 3), x, ground(x) + 12, R.uniform(.9, 1.25), R.random() < .5)
                elif r < .85: put(L, 'hoaco/c_xanh', 'dc_xanh%d' % R.randint(0, 3), x, ground(x) + 10, R.uniform(1.1, 1.5), R.random() < .5)
                else: put(L, 'hoaco/c_lau', 'dc_lau%d' % R.randint(0, 3), x, ground(x) + 10, R.uniform(1.0, 1.3), R.random() < .5)
            x += R.uniform(28, 62)
        put(L, 'congtrinh/ben', '0d', 2650 + 250, WL + 14, 2.3)

# ảnh nền bờ đất / mép cỏ của nông trại (lặp)
for nm in ('n2_co', 'dg2_dat'):
    Image.open(NT + nm + '.webp').convert('RGB').save(os.path.join(OUT, nm + '.webp'), lossless=True, quality=100, method=4)

# lớp bờ: nhà + miếu đứng sau mép cỏ, rồi bờ đất, cỏ, cuối cùng bến ghe dưới nước
def ord3(p):
    if p[0] != 3: return 0
    n = p[1]
    return 0 if n.startswith(('nha_', 'shrine')) else 1 if n == '#bo' else 3 if n.startswith('ben') else 2
place = sorted(place, key=lambda p: (p[0], ord3(p)))
gx = list(range(-40, BW + 41, 10))
lay = dict(W=BW, H=BH, WL=WL, far=[[round(x, 1), round(y, 1)] for x, y in rec9.FAR],
           ground=[round(ground(x), 2) for x in gx], gx0=-40, gdx=10,
           hz=[.30, .09, 0, 0, 0], items=used, place=place)
json.dump(lay, open(os.path.join(OUT, 'bo.json'), 'w'), separators=(',', ':'))
print('place', len(place), 'files', len(used))
