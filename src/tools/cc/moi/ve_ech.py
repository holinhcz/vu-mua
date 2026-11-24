#!/usr/bin/env python3
# ẾCH ĐỒNG (11-24 Link "vẽ ếch cá chép với tép"): con ếch của lọp lươn trong vườn, cùng kiểu vẽ với cá câu
# (tô từng điểm ảnh, sáng trên-trái, viền mảnh màu tối của chỗ đó). Nhìn ngang, quay mặt sang phải như cá,
# ngồi chồm: đùi sau gập chữ Z, bàn chân sau có màng, tay trước chống, lưng có gờ da + mụn, đốm sẫm, chân có vằn ngang,
# mắt lồi tròng vàng con ngươi ngang, màng nhĩ sau mắt, bụng vàng kem.
# Dùng bộ vẽ của moi_ve.py ở cỡ x3 (khung vẽ 512 đơn vị -> ảnh ~1500 px).   python3 ve_ech.py OUTDIR
import os, sys, math
os.environ.setdefault('MOI_SC', '2.6')
OUTDIR = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/moi/f'
sys.argv = [sys.argv[0], OUTDIR]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from moi_ve import *          # noqa
import numpy as np
from scipy import ndimage as ndi

OLIVE = hexc('#7d8c3c'); OLIVE_D = hexc('#56632a'); BROWN = hexc('#6e5a2e'); SPOT = hexc('#33391a')
YEL = hexc('#c9c06a'); BELLY = hexc('#f6eec8')


def skin(P, h, m, seed, base=None, spots=.75, bars=None, warts=True):
    b = (OLIVE if base is None else base) * (1 + .08 * noise(2.5, seed))[..., None]
    b = lerpc(b, BROWN, sstep(.1, .6, noise(9, seed + 1, 2)) * .35)
    if spots:
        s = sstep(.32, .5, noise(9, seed + 2, 2)) * m
        b = lerpc(b, SPOT, s * spots)
    if bars is not None:   # vằn ngang trên chân: bars = toạ độ dọc chân (s, đơn vị)
        bb = sstep(.55, .75, .5 + .5 * np.sin(bars / 15.0))
        b = lerpc(b, SPOT, bb * .6 * m)
    hh = h
    if warts:
        w = specks(seed + 3, 90, 40, 120, 480, 430, 2.0, 4.0, inside=m)
        hh = h + ndi.gaussian_filter(w, 1.2 * PX) * 3.2
        b = lerpc(b, lerpc(b, YEL, .4), w * .35)
    c, _ = P.shade(hh, b, amb=.42, dif=.74, spec=.1, sp_pow=20)
    return c


def ech():
    P = Pic()
    # ---- tay trước phía xa (sau thân, tối hơn)
    pa = cr_path([(358, 330), (362, 354), (378, 378), (388, 396)], 8)
    m, h, s, _ = tube(pa, [11 - 4 * i / (len(pa) - 1) for i in range(len(pa))])
    P.put(m, skin(P, h, m, 5, base=OLIVE_D, spots=.3, warts=False) * .8, contact=0)
    for k in range(3):
        p2 = (384 + (k - 1) * 18, 404)
        m, h, _, _ = tube([(384, 394), p2], [5, 4])
        c, _ = P.shade(h, OLIVE_D * .85, amb=.45, dif=.6)
        P.put(m, c, contact=.1)
    # ---- chân sau phía xa: chỉ thấy bàn chân ló ra sau
    foot_far = [(150, 398), (205, 406), (262, 412)]
    m, h, s, _ = tube(foot_far, [11, 9, 7])
    P.put(m, skin(P, h, m, 7, base=OLIVE_D, spots=.3, warts=False) * .82, contact=0)
    # ---- thân + đầu: 1 khối (lưng gù nhẹ, đầu dẹt nhọn mõm)
    up = cr_path([(96, 318), (110, 262), (146, 222), (194, 202), (252, 208), (310, 216), (360, 212), (414, 212), (450, 228), (466, 246)], 10)
    dn = cr_path([(466, 246), (462, 262), (440, 280), (404, 298), (360, 318), (300, 338), (230, 352), (160, 350), (110, 336), (96, 318)], 10)
    bm = poly_mask(up + dn[1:])
    m, h = puff(bm, 62, .9)
    h = ndi.gaussian_filter(h, 2 * PX)
    # gờ da 2 bên lưng (gờ lưng-hông) + các gờ ngắn dọc lưng
    ridge = np.zeros_like(h)
    for k, (dy, a) in enumerate([(18, 1.0), (40, .6)]):
        yr = np.interp(X, [100, 200, 300, 400, 440], [300, 214 + dy, 226 + dy, 226 + dy * .6, 236])
        g = np.exp(-((Y - yr) / 3.2) ** 2) * sstep(150, 200, X) * (1 - sstep(380, 420, X))
        brk = sstep(-.2, .3, noise(7, 60 + k, 1))         # gờ đứt khúc
        ridge += g * brk * a
    h = h + ridge * 3.5 * m
    base = OLIVE
    c = skin(P, h, m, 11)
    c = lerpc(c, lerpc(c, YEL, .55), ridge * .55)
    # hông nhạt dần -> bụng vàng kem
    yb = np.interp(X, [96, 200, 300, 400, 466], [330, 335, 322, 292, 256])
    t = sstep(yb - 34, yb + 6, Y)
    cb, _ = P.shade(h, BELLY * (1 + .05 * noise(1.5, 12))[..., None], amb=.86, dif=.22)
    c = lerpc(c, cb, t * .95)
    # sọc vàng giữa lưng (ếch đồng hay có)
    yv = np.interp(X, [110, 150, 200, 300, 400, 450], [276, 226, 206, 220, 216, 230])
    vs = np.exp(-((Y - yv) / 2.4) ** 2) * sstep(130, 170, X) * (1 - sstep(400, 440, X))
    c = lerpc(c, hexc('#d4c870'), vs * .7)
    # miệng: đường dài từ mõm ra sau tới dưới màng nhĩ
    my = np.interp(X, [300, 340, 400, 440, 466], [276, 270, 266, 260, 252])
    mouth = np.exp(-((Y - my) / 1.6) ** 2) * sstep(296, 310, X) * (1 - sstep(462, 468, X))
    c = c * (1 - .6 * mouth * m)[..., None]
    c = lerpc(c, lerpc(c, BELLY, .5), np.exp(-((Y - my - 5) / 3) ** 2) * sstep(300, 320, X) * m * .5)   # môi dưới sáng
    # lỗ mũi
    nm, _ = ellipse(446, 228, 4.5, 3, .3)
    c = c * (1 - .7 * nm)[..., None]
    P.put(m, c, contact=.3)
    # ---- màng nhĩ sau mắt
    m, h = ellipse(352, 248, 15, 14, hk=.25)
    d = np.hypot(X - 352, Y - 248) / 15
    tb = lerpc(hexc('#7a7a3a'), hexc('#4e4a22'), sstep(.6, 1, d))
    tb = tb * (1 + .06 * noise(1, 13))[..., None]
    c, _ = P.shade(h, tb, amb=.45, dif=.66, spec=.08)
    c = lerpc(c, hexc('#b8b070'), np.exp(-((d - .3) / .12) ** 2) * .3)
    P.put(m, c, edge=hexc('#3a3a14'), line=.45, contact=.12)
    # ---- mắt lồi
    m, h = ellipse(398, 204, 36, 31, hk=.9)
    P.put(m, skin(P, h, m, 14, spots=.2, warts=False), contact=.25)
    m, h = ellipse(400, 200, 26, 24)
    d = np.hypot(X - 400, Y - 200) / 26
    iris = lerpc(hexc('#f0cc5a'), hexc('#9a6a20'), sstep(.4, 1, d))
    vein = sstep(.25, .6, noise(.6, 15, 2))
    iris = lerpc(iris, hexc('#6a4414'), vein * .35 * sstep(.3, .9, d))
    pm, _ = ellipse(401, 201, 14, 7)
    iris = lerpc(iris, hexc('#120c06'), pm)
    c, _ = P.shade(h, iris, amb=.55, dif=.55, spec=.32, sp_pow=34)
    P.put(m, c, edge=hexc('#2a2008'), line=.85, lw=1.4, contact=.2)
    lid = np.exp(-((np.hypot(X - 400, (Y - 203) * 1.08) - 27) / 2.2) ** 2) * (Y < 196)
    P.paint(OLIVE_D * .8, lid * .65)
    # ---- chân sau gần: đùi (gập về trước) -> ống chân (gập ra sau) -> bàn chân dài có màng (đạp tới trước)
    m, h = ellipse(186, 330, 88, 42, .32, hk=.95)
    xs = (X - 186) * math.cos(.32) + (Y - 330) * math.sin(.32)
    P.put(m, skin(P, h, m, 20, bars=xs + 200), contact=.35)
    shin = [(262, 366), (214, 378), (164, 388), (134, 394)]
    m, h, s, _ = tube(shin, [25, 21, 16, 12])
    P.put(m, skin(P, h, m, 21, bars=s), contact=.38)
    # bàn chân + 5 ngón có màng
    m, h, s, _ = tube([(132, 396), (174, 402), (214, 406)], [12, 10, 8.5])
    P.put(m, skin(P, h, m, 22, bars=s, spots=.3, warts=False), contact=.3)
    toes = []
    for k in range(5):
        ang = math.radians(-14 + k * 9)
        L = [40, 52, 64, 54, 38][k]
        toes.append((214 + math.cos(ang) * L, 406 + math.sin(ang) * L * .35 + k * 2.5))
    web = poly_mask([(206, 398)] + toes + [(206, 414)])
    m, h = puff(web, 3, .5)
    c, _ = P.shade(h, lerpc(OLIVE_D, YEL, .35) * .9, amb=.5, dif=.55)
    P.put(m * .9, c, line=.35, lw=1, contact=.2)
    for k, tp in enumerate(toes):
        m, h, _, _ = tube([(210, 406), tp], [5.5, 4])
        c, _ = P.shade(h, OLIVE * .95, amb=.45, dif=.65)
        P.put(m, c, line=.5, lw=1, contact=.15)
        m, h = ellipse(tp[0], tp[1], 5, 4.5)
        c, _ = P.shade(h, lerpc(OLIVE, YEL, .5), amb=.5, dif=.6)
        P.put(m, c, line=.4, lw=1, contact=.1)
    # ---- tay trước gần
    arm = cr_path([(340, 326), (346, 352), (362, 378), (374, 396)], 8)
    m, h, s, _ = tube(arm, [13 - 5 * i / (len(arm) - 1) for i in range(len(arm))])
    P.put(m, skin(P, h, m, 30, bars=s, spots=.4, warts=False), contact=.35)
    for k in range(4):
        tp = (372 + (k - 1.5) * 16, 408 + abs(k - 1.5) * -2)
        m, h, _, _ = tube([(372, 396), tp], [6, 4.5])
        c, _ = P.shade(h, OLIVE * .95, amb=.45, dif=.65)
        P.put(m, c, line=.5, lw=1, contact=.15)
        m, h = ellipse(tp[0], tp[1], 5.5, 4.5)
        c, _ = P.shade(h, lerpc(OLIVE, YEL, .5), amb=.5, dif=.6)
        P.put(m, c, line=.4, lw=1, contact=.1)
    im = P.save('ech_tmp', ow=2.2)
    src = os.path.join(OUTDIR, 'ic-ech_tmp.webp')
    os.replace(src, os.path.join(OUTDIR, 'ech.webp'))
    im.save(os.path.join(OUTDIR, 'ech.png'))
    return im


if __name__ == '__main__':
    os.makedirs(OUTDIR, exist_ok=True)
    ech()
