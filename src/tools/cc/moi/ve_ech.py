#!/usr/bin/env python3
# ẾCH ĐỒNG (11-24 Link "vẽ ếch cá chép với tép"): con ếch của lọp lươn trong vườn, cùng kiểu vẽ với cá câu
# (tô từng điểm ảnh, sáng trên-trái, viền mảnh màu tối của chỗ đó). Nhìn ngang, quay mặt sang phải như cá,
# ngồi bệt (11-25: mông + bụng chạm đất, đầu ngóc, tay trước ngắn chống thẳng): đùi sau gập chữ Z sát hông, bàn chân sau có màng, tay trước chống, lưng có gờ da + mụn, đốm sẫm, chân có vằn ngang,
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

OLIVE = hexc('#8c9c4a'); OLIVE_D = hexc('#647233'); BROWN = hexc('#7d683a'); SPOT = hexc('#444d24')   # (11-24 Link: xuống 1 tone, rồi "đậm lên 0.5 tone" -> giữa 2 bản)
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


def dy(x):
    """(11-25 Link "ngồi xuống luôn, không thấy nó đang chồm hổm à"): thân hạ xuống, mông + bụng chạm đất, đầu ngóc lên:
    mỗi điểm của thân/đầu dời xuống dy(x) (sau mông 58, tới mõm 44 -> ngực sát đất, đầu hơi ngóc)"""
    return 58 - (x - 96) * 14 / 370


def SH(x, y):
    return (x, y + dy(x))


def ech():
    P = Pic()
    DY = dy(X)
    GY = 414                                    # mặt đất (bàn chân, bàn tay, bụng chạm)
    # ---- tay trước phía xa (sau thân, tối hơn): ngắn, chống thẳng xuống đất dưới ngực
    pa = cr_path([(370, 360), (368, 378), (376, 394), (384, 404)], 8)
    m, h, s, _ = tube(pa, [11 - 4 * i / (len(pa) - 1) for i in range(len(pa))])
    P.put(m, skin(P, h, m, 5, base=OLIVE_D, spots=.3, warts=False) * .8, contact=0)
    for k in range(3):
        p2 = (386 + (k - 1) * 17, GY - 2)
        m, h, _, _ = tube([(384, 402), p2], [5, 4])
        c, _ = P.shade(h, OLIVE_D * .85, amb=.45, dif=.6)
        P.put(m, c, contact=.1)
    # ---- chân sau phía xa: chỉ thấy mũi bàn chân ló ra trước dưới bụng
    m, h, s, _ = tube([(200, 410), (246, 412), (286, 414)], [9, 8, 6])
    P.put(m, skin(P, h, m, 7, base=OLIVE_D, spots=.3, warts=False) * .82, contact=0)
    # ---- thân + đầu: 1 khối, hạ xuống ngồi bệt (mông, bụng sát đất), đầu ngóc
    up = cr_path([SH(*p) for p in [(96, 318), (110, 262), (146, 222), (194, 202), (252, 208), (310, 216), (360, 212), (414, 212), (450, 228), (466, 246)]], 10)
    dn = cr_path([SH(*p) for p in [(466, 246), (462, 262), (440, 280), (404, 298), (360, 318), (300, 340), (230, 352), (160, 352), (110, 338), (96, 318)]], 10)
    bm = poly_mask(up + dn[1:])
    m, h = puff(bm, 62, .9)
    h = ndi.gaussian_filter(h, 2 * PX)
    ridge = np.zeros_like(h)
    for k, (d0, a) in enumerate([(18, 1.0), (40, .6)]):
        yr = np.interp(X, [100, 200, 300, 400, 440], [300, 214 + d0, 226 + d0, 226 + d0 * .6, 236]) + DY
        g = np.exp(-((Y - yr) / 3.2) ** 2) * sstep(150, 200, X) * (1 - sstep(380, 420, X))
        brk = sstep(-.2, .3, noise(7, 60 + k, 1))
        ridge += g * brk * a
    h = h + ridge * 3.5 * m
    c = skin(P, h, m, 11)
    c = lerpc(c, lerpc(c, YEL, .55), ridge * .55)
    yb = np.interp(X, [96, 200, 300, 400, 466], [330, 335, 322, 292, 256]) + DY
    t = sstep(yb - 34, yb + 6, Y)
    cb, _ = P.shade(h, BELLY * (1 + .05 * noise(1.5, 12))[..., None], amb=.86, dif=.22)
    c = lerpc(c, cb, t * .95)
    yv = np.interp(X, [110, 150, 200, 300, 400, 450], [276, 226, 206, 220, 216, 230]) + DY
    vs = np.exp(-((Y - yv) / 2.4) ** 2) * sstep(130, 170, X) * (1 - sstep(400, 440, X))
    c = lerpc(c, hexc('#d4c870'), vs * .7)
    my = np.interp(X, [300, 340, 400, 440, 466], [276, 270, 266, 260, 252]) + DY
    mouth = np.exp(-((Y - my) / 1.6) ** 2) * sstep(296, 310, X) * (1 - sstep(462, 468, X))
    c = c * (1 - .6 * mouth * m)[..., None]
    c = lerpc(c, lerpc(c, BELLY, .5), np.exp(-((Y - my - 5) / 3) ** 2) * sstep(300, 320, X) * m * .5)
    nx, ny = SH(446, 228)
    nm, _ = ellipse(nx, ny, 4.5, 3, .3 - .08)
    c = c * (1 - .7 * nm)[..., None]
    P.put(m, c, contact=.3)
    # ---- màng nhĩ sau mắt
    tx, ty = SH(352, 248)
    m, h = ellipse(tx, ty, 15, 14, hk=.25)
    d = np.hypot(X - tx, Y - ty) / 15
    tb = lerpc(hexc('#7a7a3a'), hexc('#4e4a22'), sstep(.6, 1, d))
    tb = tb * (1 + .06 * noise(1, 13))[..., None]
    c, _ = P.shade(h, tb, amb=.45, dif=.66, spec=.08)
    c = lerpc(c, hexc('#b8b070'), np.exp(-((d - .3) / .12) ** 2) * .3)
    P.put(m, c, edge=hexc('#3a3a14'), line=.45, contact=.12)
    # ---- mắt lồi
    ex, ey = SH(400, 200)
    m, h = ellipse(ex - 2, ey + 4, 36, 31, hk=.9)
    P.put(m, skin(P, h, m, 14, spots=.2, warts=False), contact=.25)
    m, h = ellipse(ex, ey, 26, 24)
    d = np.hypot(X - ex, Y - ey) / 26
    iris = lerpc(hexc('#f0cc5a'), hexc('#9a6a20'), sstep(.4, 1, d))
    vein = sstep(.25, .6, noise(.6, 15, 2))
    iris = lerpc(iris, hexc('#6a4414'), vein * .35 * sstep(.3, .9, d))
    pm, _ = ellipse(ex + 1, ey + 1, 14, 7)
    iris = lerpc(iris, hexc('#120c06'), pm)
    c, _ = P.shade(h, iris, amb=.55, dif=.55, spec=.32, sp_pow=34)
    P.put(m, c, edge=hexc('#2a2008'), line=.85, lw=1.4, contact=.2)
    lid = np.exp(-((np.hypot(X - ex, (Y - ey - 3) * 1.08) - 27) / 2.2) ** 2) * (Y < ey - 4)
    P.paint(OLIVE_D * .8, lid * .65)
    # ---- chân sau gần, gập sát hông: đùi từ mông chạy tới trước (gối ở giữa bụng) -> ống chân gập ngược về sau
    #      sát đất -> bàn chân dài có màng nằm dưới đùi, ngón xoè tới trước
    m, h = ellipse(196, 366, 80, 36, .1, hk=.95)
    xs = (X - 196) * math.cos(.1) + (Y - 366) * math.sin(.1)
    P.put(m, skin(P, h, m, 20, bars=xs + 200), contact=.35)
    shin = [(268, 388), (226, 396), (176, 400), (136, 400)]
    m, h, s, _ = tube(shin, [22, 19, 15, 12])
    P.put(m, skin(P, h, m, 21, bars=s), contact=.38)
    m, h, s, _ = tube([(132, 404), (176, 409), (222, 411)], [11, 9.5, 8])
    P.put(m, skin(P, h, m, 22, bars=s, spots=.3, warts=False), contact=.3)
    toes = []
    for k in range(5):
        ang = math.radians(-12 + k * 7)
        L = [36, 48, 58, 50, 34][k]
        toes.append((222 + math.cos(ang) * L, 411 + math.sin(ang) * L * .3 + k * 1.5))
    web = poly_mask([(214, 404)] + toes + [(214, 418)])
    m, h = puff(web, 3, .5)
    c, _ = P.shade(h, lerpc(OLIVE_D, YEL, .35) * .9, amb=.5, dif=.55)
    P.put(m * .9, c, line=.35, lw=1, contact=.2)
    for k, tp in enumerate(toes):
        m, h, _, _ = tube([(218, 411), tp], [5.5, 4])
        c, _ = P.shade(h, OLIVE * .95, amb=.45, dif=.65)
        P.put(m, c, line=.5, lw=1, contact=.15)
        m, h = ellipse(tp[0], tp[1], 5, 4.5)
        c, _ = P.shade(h, lerpc(OLIVE, YEL, .5), amb=.5, dif=.6)
        P.put(m, c, line=.4, lw=1, contact=.1)
    # ---- tay trước gần: ngắn, chống thẳng xuống đất ngay dưới ngực
    arm = cr_path([(350, 358), (346, 378), (356, 394), (366, 404)], 8)
    m, h, s, _ = tube(arm, [13 - 5 * i / (len(arm) - 1) for i in range(len(arm))])
    P.put(m, skin(P, h, m, 30, bars=s, spots=.4, warts=False), contact=.35)
    for k in range(4):
        tp = (366 + (k - 1.5) * 15, GY + abs(k - 1.5) * -1.5)
        m, h, _, _ = tube([(366, 404), tp], [6, 4.5])
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
