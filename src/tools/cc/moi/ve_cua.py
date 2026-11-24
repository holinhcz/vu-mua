#!/usr/bin/env python3
# CUA ĐỒNG + GHẸ (11-24 Link "vẽ thêm cua + ghẹ"): cùng kiểu vẽ với cá câu (tô từng điểm ảnh, sáng trên-trái,
# viền mảnh màu tối của chỗ đó). Nhìn từ trên xuống, càng chĩa lên trên.
#  cua: mai tròn bè ngang, rãnh chữ H, lấm tấm hạt ở mép trước, càng mập (càng phải to hơn), 4 cặp chân bò có khớp
#  ghẹ: mai rộng có gai dài 2 bên + răng cưa mép trước, càng dài mảnh có gai, xanh tím đốm trắng, cặp chân cuối là mái chèo
# Dùng bộ vẽ moi_ve.py ở cỡ x2.4.   python3 ve_cua.py OUTDIR [cua ghe]
import os, sys, math
os.environ.setdefault('MOI_SC', '2.4')
OUTDIR = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/moi/f'
WHO = sys.argv[2:] or ['cua', 'ghe']
sys.argv = [sys.argv[0], OUTDIR]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from moi_ve import *          # noqa
import numpy as np
from scipy import ndimage as ndi


def seg_leg(P, pts, rads, col, dark, seed, spots=None, tipcol=None, contact=.3):
    """chân nhiều đốt: mỗi đốt 1 ống riêng (khớp thắt lại, đốt sau đè đốt trước)"""
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        r0, r1 = rads[i], rads[i + 1]
        m, h, s, sd = tube([a, mid, b], [r0 * .85, max(r0, r1) * 1.02, r1 * .85])
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        base = lerpc(col, col * 1.12, sstep(-1, 1, -sd))
        if tipcol is not None and i == len(pts) - 2:
            base = lerpc(base, tipcol, sstep(.45, .95, s / L))
        if spots is not None:
            sp = specks(seed + i, int(L / 6), min(a[0], b[0]) - 20, min(a[1], b[1]) - 20, max(a[0], b[0]) + 20, max(a[1], b[1]) + 20, 1.6, 3.6, inside=m)
            base = lerpc(base, spots, sp * .85)
        base = base * (1 + .05 * noise(1.2, seed + 40 + i))[..., None]
        c, _ = P.shade(h, base, amb=.42, dif=.74, spec=.12, sp_pow=22)
        P.put(m, c, edge=dark, contact=contact if i == 0 else .22, cblur=4)


def carapace_mask(pts):
    return poly_mask(cr_path(pts + [pts[0]], 10))


def eyes(P, xs, y, stalk, col):
    for x in xs:
        m, h, _, _ = tube([(x, y + 14), (x + (x - 256) * .08, y - stalk)], [6.5, 5.5])
        c, _ = P.shade(h, col, amb=.45, dif=.7)
        P.put(m, c, contact=.2)
        ex, ey = x + (x - 256) * .08, y - stalk - 3
        m, h = ellipse(ex, ey, 8.5, 8.5)
        c, _ = P.shade(h, hexc('#1a1410'), amb=.6, dif=.4, spec=.35, sp_pow=30)
        P.put(m, c, edge=hexc('#0c0806'), contact=.2)


def claw(P, sx, k, col, dark, tip, seed, spots=None, slim=1.0, spines=False):
    """càng trái (sx=-1) / phải (1), k = cỡ. Cánh tay gập lên, bàn càng to, 2 ngón chụm vào giữa."""
    cx = 256
    X0 = lambda x: cx + sx * x
    arm = [(X0(80), 220), (X0(118 * slim + 10), 178), (X0(116 * slim + 4), 146)]
    seg_leg(P, arm, [17 * k, 15 * k, 14 * k], col, dark, seed, spots=spots)
    if spines:
        for t in (.3, .55, .8):
            px = arm[0][0] + (arm[1][0] - arm[0][0]) * t; py = arm[0][1] + (arm[1][1] - arm[0][1]) * t
            m, h = puff(poly_mask([(px - 4, py), (px + sx * 2 - 8 * sx, py - 13), (px + 4, py - 2)]), 2, .7)
            c, _ = P.shade(h, col * 1.1, amb=.45, dif=.7)
            P.put(m, c, edge=dark, contact=.1)
    # bàn càng: dài theo hướng chĩa lên trên + vào giữa (trước mặt cua), 2 ngón nối tiếp ở đầu bàn, hơi khép vào nhau
    wx, wy = arm[-1]
    dx, dy = -sx * .78, -.63
    dl = math.hypot(dx, dy); dx, dy = dx / dl, dy / dl
    rot = math.atan2(dy, dx)
    hx, hy = wx + dx * 34 * k * slim, wy + dy * 34 * k * slim
    m, h = ellipse(hx, hy, 46 * k * slim, 27 * k, rot, hk=.85)
    v = -(X - hx) * math.sin(rot) + (Y - hy) * math.cos(rot)          # ngang bàn càng
    base = lerpc(col * 1.1, col * .86, sstep(-20, 20, v * sx))
    gran = specks(seed + 20, 40, hx - 50, hy - 50, hx + 50, hy + 50, 1.4, 2.6, inside=m)
    h = h + gran * 1.4
    if spots is not None:
        sp = specks(seed + 21, 28, hx - 50, hy - 50, hx + 50, hy + 50, 2, 4.5, inside=m)
        base = lerpc(base, spots, sp * .85)
    c, _ = P.shade(h, base, amb=.42, dif=.75, spec=.14, sp_pow=22)
    P.put(m, c, edge=dark, contact=.32)
    ex, ey = wx + dx * 70 * k * slim, wy + dy * 70 * k * slim
    px_, py_ = -dy, dx                                                  # pháp tuyến
    for j, side in enumerate((1, -1)):          # ngón cố định (phía ngoài) rồi ngón động
        o = side * 9 * k
        sx0, sy0 = ex - dx * 10 * k + px_ * o, ey - dy * 10 * k + py_ * o
        L = 66 * k * slim
        pts = [(sx0, sy0)]
        for t in (.35, .7, 1.0):
            bend = side * .3 * t * t
            ca, sa = math.cos(bend), math.sin(bend)
            ddx, ddy = dx * ca - dy * sa, dx * sa + dy * ca
            pts.append((sx0 + ddx * L * t, sy0 + ddy * L * t))
        rr = [11.5 * k, 10 * k, 7 * k, 2.6]
        m, h, s2, sd = tube(pts, rr)
        b = lerpc(col * 1.05, tip, sstep(.5, .92, s2 / L))
        teeth = (np.cos(s2 / 4.2 * 2 * math.pi) > .6) * (np.abs(sd) > .55) * .5
        b = b * (1 - .25 * teeth * m)[..., None]
        c, _ = P.shade(h, b, amb=.42, dif=.74, spec=.14, sp_pow=22)
        P.put(m, c, edge=dark, contact=.25)


def cua():
    P = Pic()
    col = hexc('#8c6a48'); dark = hexc('#3a2418'); tip = hexc('#4a2a1c')
    # 4 cặp chân bò (sau mai): thân -> đùi chĩa ra ngoài -> ống gập xuống -> móng nhọn
    for sx in (-1, 1):
        for k in range(4):
            y0 = 236 + k * 30
            spread = [-.2, .05, .3, .55][k]
            p0 = (256 + sx * 96, y0)
            p1 = (256 + sx * (160 - k * 4), y0 - 28 + k * 22)
            p2 = (256 + sx * (206 - k * 10), y0 - 4 + k * 34)
            p3 = (256 + sx * (222 - k * 16), y0 + 30 + k * 40)
            seg_leg(P, [p0, p1, p2, p3], [15, 14, 11, 4], col * (.92 + .03 * k), dark, 100 + k * 7 + (sx > 0) * 50, tipcol=tip)
    # càng (cua đồng: càng phải to hơn)
    claw(P, -1, .92, col, dark, tip, 200)
    claw(P, 1, 1.1, col, dark, tip, 300)
    # mai: bè ngang, mép trước thẳng giữa 2 mắt, mép trước-bên cong, sau thu hẹp
    cp = [(256, 182), (300, 184), (340, 196), (366, 224), (372, 258), (358, 296), (326, 326), (256, 342), (186, 326), (154, 296), (140, 258), (146, 224), (172, 196), (212, 184)]
    cm = carapace_mask(cp)
    m, h = puff(cm, 70, .85)
    h = ndi.gaussian_filter(h, 2 * PX)
    # rãnh chữ H + rãnh cổ cong
    hg = np.exp(-((np.abs(X - 256) - 26) / 3.0) ** 2) * sstep(222, 236, Y) * (1 - sstep(286, 300, Y))
    hb = np.exp(-((Y - 262) / 3.0) ** 2) * (np.abs(X - 256) < 26)
    cg = np.exp(-((Y - (232 + .006 * (X - 256) ** 2)) / 3.4) ** 2) * (np.abs(X - 256) > 30) * (np.abs(X - 256) < 92)
    groove = np.clip(hg + hb + cg, 0, 1) * m
    h = h - groove * 1.8
    gran = specks(5, 160, 150, 182, 362, 270, 1.4, 2.8, inside=cm)
    gran = gran * (1 - sstep(220, 270, Y))
    h = h + gran * 1.6
    base = lerpc(hexc('#9a7a52'), hexc('#6e4e36'), sstep(.2, 1, np.hypot((X - 256) / 116, (Y - 262) / 80)))
    base = lerpc(base, hexc('#6a3e34'), sstep(.1, .7, noise(8, 6)) * .35)       # ánh tím nâu loang
    base = base * (1 - .14 * groove)[..., None]
    c, _ = P.shade(h, base, amb=.42, dif=.76, spec=.14, sp_pow=22)
    P.put(m, c, edge=dark, contact=.42, cblur=8)
    eyes(P, (226, 286), 184, 12, col)
    im = P.save('cua_tmp', ow=2.2)
    os.replace(os.path.join(OUTDIR, 'ic-cua_tmp.webp'), os.path.join(OUTDIR, 'cua.webp'))
    im.save(os.path.join(OUTDIR, 'cua.png'))


def ghe():
    P = Pic()
    col = hexc('#4f78b4'); dark = hexc('#1c2c4a'); tip = hexc('#6a3a7a'); wspot = hexc('#dfe8f2')
    # 3 cặp chân bò + cặp chân bơi (mái chèo) phía sau
    for sx in (-1, 1):
        for k in range(3):
            y0 = 246 + k * 22
            p0 = (256 + sx * 100, y0)
            p1 = (256 + sx * (176 - k * 6), y0 - 22 + k * 22)
            p2 = (256 + sx * (236 - k * 14), y0 + 4 + k * 30)
            p3 = (256 + sx * (262 - k * 24), y0 + 50 + k * 40)
            seg_leg(P, [p0, p1, p2, p3], [12, 11, 9, 3.5], col * (.95 + .03 * k), dark, 400 + k * 7 + (sx > 0) * 50, spots=wspot, tipcol=tip)
        # chân bơi: đốt dài rồi bản dẹt hình mái chèo
        p0 = (256 + sx * 82, 312); p1 = (256 + sx * 136, 352); p2 = (256 + sx * 150, 390)
        seg_leg(P, [p0, p1, p2], [12, 10, 8], col, dark, 470 + (sx > 0) * 9, spots=wspot)
        m, h = ellipse(256 + sx * 160, 418, 22, 32, sx * .35, hk=.35)
        vein = np.exp(-(((X - (256 + sx * 160)) * math.cos(sx * .35) + (Y - 418) * math.sin(sx * .35)) / 2) ** 2)
        b = lerpc(col * 1.05, hexc('#8fb0dc'), sstep(.4, 1, np.hypot((X - 256 - sx * 160) / 22, (Y - 418) / 32)))
        b = b * (1 - .15 * vein * m)[..., None]
        c, _ = P.shade(h, b, amb=.48, dif=.66, spec=.1)
        P.put(m, c, edge=dark, contact=.25)
    # càng dài mảnh có gai, đốm trắng, mũi tím
    claw(P, -1, .9, col, dark, tip, 600, spots=wspot, slim=1.35, spines=True)
    claw(P, 1, .9, col, dark, tip, 700, spots=wspot, slim=1.35, spines=True)
    # mai: rộng, gai dài nhọn 2 bên, mép trước-bên răng cưa
    half = []
    # từ giữa mép trước ra phải: 2 răng trán, hốc mắt, 8 răng cưa, gai dài, mép sau-bên, đuôi
    half.append((256, 196)); half.append((270, 190)); half.append((278, 198)); half.append((290, 192))
    for i in range(8):
        t = (i + 1) / 9
        a = math.radians(-100 + t * 85)
        rx, ry = 150, 68
        x = 256 + math.cos(a) * rx * 1.0 + 10; y = 262 + math.sin(a) * ry * 1.0
        half.append((x - 3, y + 3)); half.append((x + 4, y - 6))
    half.append((462, 244)); half.append((404, 268))       # gai dài 2 bên
    half += [(386, 286), (350, 312), (304, 330), (256, 336)]
    pts = half + [(512 - x, y) for x, y in reversed(half[1:-1])]
    cm = poly_mask(pts)
    m, h = puff(cm, 64, .7)
    h = ndi.gaussian_filter(h, 1.6 * PX)
    # 3 gờ ngang mờ + hạt
    rid = np.zeros_like(h)
    for yy in (238, 262, 290):
        rid += np.exp(-((Y - yy - .002 * (X - 256) ** 2) / 4) ** 2) * (np.abs(X - 256) < 120)
    h = h + rid * 1.6 * m
    base = lerpc(hexc('#5a86c4'), hexc('#3c5f98'), sstep(.3, 1.1, np.hypot((X - 256) / 160, (Y - 262) / 70)))
    base = lerpc(base, hexc('#6a5a96'), sstep(.1, .6, noise(9, 8)) * .35)          # ánh tím
    # mạng đốm trắng xanh (ghẹ xanh đực)
    net = sstep(.22, .5, noise(3, 9, 2)) * (1 - sstep(.6, .95, np.hypot((X - 256) / 170, (Y - 262) / 78)))
    base = lerpc(base, wspot, net * .5)
    sp = specks(10, 90, 110, 196, 402, 330, 1.4, 3, inside=cm)
    base = lerpc(base, wspot, sp * .6)
    c, _ = P.shade(h, base, amb=.42, dif=.76, spec=.14, sp_pow=22)
    P.put(m, c, edge=dark, contact=.42, cblur=8)
    eyes(P, (232, 280), 196, 11, col)
    im = P.save('ghe_tmp', ow=2.2)
    os.replace(os.path.join(OUTDIR, 'ic-ghe_tmp.webp'), os.path.join(OUTDIR, 'ghe.webp'))
    im.save(os.path.join(OUTDIR, 'ghe.png'))


if __name__ == '__main__':
    os.makedirs(OUTDIR, exist_ok=True)
    for w in WHO:
        globals()[w]()
