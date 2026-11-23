# Bờ bên này (câu cá, sát người câu) = ghép ẢNH 9px CÓ SẴN của Nông trại (caydai/bui_co, hoaco/*), KHÔNG vẽ lại.
# Mỗi khung 1 file (ảnh ngày; đêm do Godot nhân màu giờ như bờ cũ), chỉ bỏ cái bóng tròn dưới gốc + cắt lề.
# Nền cỏ = ảnh n2_co của nông trại do Godot vẽ (đa giác có mép trên cong theo `edge`).
#   python3 gan_pick.py OUT     -> OUT/*.webp + gan.json (toạ độ khung 2800 x 420 như ảnh fg cũ)
import sys, os, json, math, random
import numpy as np
from PIL import Image
G = '/mnt/project-files/nong-trai-chung/godot/'
NT = '/mnt/project-files/nong-trai-chung/img/'
OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
W, H = 2800, 420

def edge(x):          # mép cỏ (y) theo x: 2 bên cao, giữa trũng, gợn nhẹ
    u = x / W
    return H * (0.30 + 0.20 * (1 - (2 * u - 1) ** 2) + 0.025 * math.sin(u * 23.0) + 0.015 * math.sin(u * 61.0))

def unshadow(a, ax, ay, rx, ry):
    al = a[..., 3].astype(np.int32); lum = a[..., :3].astype(np.int32).max(-1)
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    near = ((xx - ax) / rx) ** 2 + ((yy - ay) / ry) ** 2 < 1.0
    a = a.copy(); a[(al < 140) & (lum < 60) & near, 3] = 0
    return a

used = {}
def frame(dir_, key):
    nm = dir_.split('/')[-1] + '_' + key
    if nm in used: return nm
    at = json.load(open(G + dir_ + '/atlas.json')); f = at['frames'][key]; ppu = float(at.get('px_per_unit', 9))
    ax0, ay0 = -f['ox'] * ppu, -f['oy'] * ppu
    d = unshadow(np.asarray(Image.open(G + dir_ + '/' + f['file']).convert('RGBA')), ax0, ay0, f['gw'] * ppu * .62, f['gw'] * ppu * .33)
    ys, xs = np.nonzero(d[..., 3] > 0)
    x0, x1, y0, y1 = max(0, xs.min() - 2), min(d.shape[1], xs.max() + 3), max(0, ys.min() - 2), min(d.shape[0], ys.max() + 3)
    Image.fromarray(d[y0:y1, x0:x1], 'RGBA').save(os.path.join(OUT, nm + '.webp'), lossless=True, quality=100, method=4)
    used[nm] = dict(w=int(x1 - x0), h=int(y1 - y0), ax=round(float(ax0 - x0), 1), ay=round(float(ay0 - y0), 1), ppu=ppu)
    return nm

place = []
def put(dir_, key, x, y, k, flip=False):
    nm = frame(dir_, key)
    place.append([nm, round(x, 1), round(y, 1), round(k / used[nm]['ppu'] * (-1 if flip else 1), 4)])

R = random.Random(11)
TUFT = [('caydai/bui_co', 'd%d', 4, 1.45, 1.9), ('hoaco/c_xanh', 'dc_xanh%d', 4, 2.0, 2.6), ('hoaco/c_lau', 'dc_lau%d', 4, 1.5, 1.9),
        ('hoaco/bui_la', 'dbui_la%d', 4, 2.4, 3.0)]
FLO = ['h_da_yen', 'h_mai_dia', 'h_muoi_gio', 'h_cuc_trang', 'h_ngu_sac', 'h_dua_can', 'h_cuc_vang', 'h_cuc_la_nho', 'h_van_tho', 'h_sao_nhai']
# hàng bụi cỏ dọc mép bờ (sau), vài hàng cỏ thấp + hoa lấm tấm trên bãi cỏ (trước)
x = -20
while x < W + 20:
    t = TUFT[0 if R.random() < .38 else 1 if R.random() < .7 else 2 if R.random() < .5 else 3]
    put(t[0], t[1] % R.randint(0, t[2] - 1), x, edge(x) + R.uniform(6, 16), R.uniform(t[3], t[4]), R.random() < .5)
    x += R.uniform(28, 55)
# cụm hoa: ÍT cụm mà TO (Link 11-23 "hoa cỏ bên đây nhỏ bé xíu"): bờ này sát mắt nên hoa to ~2.5 lần hoa bờ bên kia,
# càng xuống mép dưới màn càng to (phối cảnh). Rải đều theo bề ngang, mỗi cụm 2-3 bụi cùng loại + vài cọng cỏ.
NC = 15
for i in range(NC):
    cx = (i + .5) / NC * W + R.uniform(-55, 55); y0 = edge(cx) + 40
    if y0 > H - 40: continue
    cy = R.uniform(y0, H - 10); f = FLO[(i * 3 + R.randint(0, 2)) % len(FLO)]
    dep = (cy - y0) / max(1.0, H - 10 - y0)
    k = 5.2 + 2.0 * dep
    for j in range(R.randint(2, 3)):
        put('hoaco/' + f, 'd%s%d' % (f, R.randint(0, 3)), cx + R.uniform(-60, 60), cy + R.uniform(-10, 14), k * R.uniform(.9, 1.1), R.random() < .5)
    for j in range(R.randint(1, 2)):
        put('hoaco/c_xanh', 'dc_xanh%d' % R.randint(0, 3), cx + R.uniform(-95, 95), cy + R.uniform(-12, 22), k * .75 * R.uniform(.9, 1.1), R.random() < .5)
for i in range(4):                       # bụi vạn thọ thấp cho góc phải màn dọc (Godot đặt theo màn)
    frame('hoaco/h_van_tho', 'dh_van_tho%d' % i)
place.sort(key=lambda p: p[2])
Image.open(NT + 'n2_co.webp').convert('RGB').save(os.path.join(OUT, 'n2_co.webp'), lossless=True, quality=100, method=4)
ex = list(range(0, W + 1, 20))
json.dump(dict(W=W, H=H, edge=[round(edge(x), 1) for x in ex], edx=20, items=used, place=place), open(os.path.join(OUT, 'gan.json'), 'w'), separators=(',', ':'))
print('place', len(place), 'files', len(used))
