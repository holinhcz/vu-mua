#!/usr/bin/env python3
# LỤC BÌNH (11-25 Link: ô Kho lục bình chưa có hình thật). Cùng kiểu tô từng điểm ảnh của mồi/cá (moi_ve.py),
# sáng trên-trái, mờ không bóng loáng, viền mảnh màu tối của chỗ đó. Màu khớp lục bình trên bản đồ (thuysinh/luc_binh):
# lá tròn xanh tươi có gân cong, cuống phình bọng xanh nhạt, chùm hoa tím nhạt (cánh trên có đốm tím đậm + chấm vàng),
# 11-25 Link: ICON thì không vẽ sáng tối 3D, viền mảnh, không vẽ rễ -> Flat: tô màu thật phẳng (không đổ sáng, không bóng
# tiếp xúc), chi tiết chỉ bằng màu (gân lá, đốm hoa), viền mảnh màu tối của chỗ đó.
# python3 ve_lucbinh.py OUTDIR   -> OUTDIR/luc_binh.webp (+ .png)
import os, sys, math
os.environ.setdefault('MOI_SC', '3.6')      # 6px chuẩn (như cá RES 3.6)
OUTDIR = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/lb'
sys.argv = [sys.argv[0], OUTDIR]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from moi_ve import *          # noqa
import numpy as np
from scipy import ndimage as ndi


class Merge:
    """gộp nhiều ống thành 1 lớp (1 lần đặt): phủ = max, mặt cao theo ống phủ nhiều nhất (gộp dần, không giữ danh sách: đỡ tốn bộ nhớ)"""
    def __init__(s):
        s.m = np.zeros((N, N), np.float32); s.h = np.zeros((N, N), np.float32)

    def append(s, mh):
        mm, hh = mh
        k = mm > s.m
        s.h[k] = hh[k]; np.maximum(s.m, mm, out=s.m)


def merge(g):
    return g.m, g.h


def roots(P, rs):
    # khối rễ chùm (lông tơ dày) phía sau
    m, h = ellipse(256, 404, 46, 62, 0, hk=.5)
    m = m * (.55 + .45 * sstep(-.3, .4, noise(1.4, 21, 2)))
    m = ndi.gaussian_filter(m, 1.2 * PX) * sstep(340, 352, Y)
    fb = hexc('#5e4050') * (1 + .15 * noise(.9, 22, 2))[..., None]
    c, _ = P.shade(h, fb, amb=.5, dif=.5)
    P.put(m, c, edge=hexc('#2e1e26'), line=0, contact=0)
    parts = Merge(); hair = Merge()
    for k in range(40):
        x0 = 256 + rs.uniform(-36, 36); y0 = 350 + rs.uniform(-6, 8)
        L = rs.uniform(60, 128); sw = rs.uniform(-1, 1)
        pts = [(x0 + sw * L * .35 * (t ** 1.4) + 6 * math.sin(t * 5 + k), y0 + L * t) for t in np.linspace(0, 1, 7)]
        m, h, s, sd = tube(pts, list(np.linspace(3.8, 1.3, 7)))
        parts.append((m, h))
        for j in range(14):              # lông rễ xiên xuống 2 bên
            t = rs.uniform(.15, .95); i = int(t * 6)
            px, py = pts[i]; sx = 1 if j % 2 else -1
            l = rs.uniform(6, 14)
            m, h, _, _ = tube([(px, py), (px + sx * l * .8, py + l * .7)], [1.0, .5])
            hair.append((m, h * .6))
    m, h = merge(hair)
    c, _ = P.shade(h, hexc('#6a4a5a'), amb=.45, dif=.6)
    P.put(m, c, edge=hexc('#2e1e26'), line=.3, lw=.8, contact=0)
    m, h = merge(parts)
    base = hexc('#5a3a4a') * (1 + .08 * noise(2, 31))[..., None]
    c, _ = P.shade(h, base, amb=.42, dif=.72, spec=.04)
    P.put(m, c, edge=hexc('#24161e'), line=.4, lw=.9, contact=0)


def petiole(P, a, b, r, seed):
    """cuống phình bọng: ống cong, phình giữa"""
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    pts = bez(a, (a[0] + (mx - a[0]) * .6, a[1] + (my - a[1]) * .2 + 8), (mx + (b[0] - mx) * .4, my), b, 14)
    rad = [r * (.45 + .6 * math.sin(math.pi * min(1, t * 1.15)) ** .8) for t in np.linspace(0, 1, len(pts))]
    m, h, s, sd = tube(pts, rad)
    base = np.broadcast_to(hexc('#9cc858'), sd.shape + (3,)).copy()
    stri = (.5 + .5 * np.cos(sd * 9)) ** 6                       # sọc dọc mảnh trên bọng
    c, _ = P.shade(h, base, amb=.44, dif=.74, spec=.06, sp_pow=20)
    P.put(m, c, edge=hexc('#3e6a1e'), contact=.3, cblur=4)


def leaf(P, cx, cy, rx, ry, rot, tone=1.0, seed=0):
    """lá tròn hơi hình thận: gân cong toả từ gốc (phía dưới lá), mép hơi cong lên"""
    m, h = ellipse(cx, cy, rx, ry, rot, hk=.5)
    c, s = math.cos(rot), math.sin(rot)
    u = (X - cx) * c + (Y - cy) * s; v = -(X - cx) * s + (Y - cy) * c
    # gốc lá ở mép dưới (v = +ry)
    bu, bv = 0, ry * .92
    ang = np.arctan2(u - bu, -(v - bv))
    rr = np.hypot(u - bu, v - bv)
    vein = (.5 + .5 * np.cos(ang * 17)) ** 18 * sstep(6, 26, rr) * (1 - sstep(.8, 1, np.hypot(u / rx, v / ry)))
    h = h - vein * .1
    base = np.broadcast_to(hexc('#4ea436') * tone, v.shape + (3,)).copy()
    base = lerpc(base, hexc('#82c254'), vein * .5)
    col, _ = P.shade(h, base, amb=.44, dif=.74, spec=.07, sp_pow=18)
    P.put(m, col, edge=hexc('#245414'), contact=.35, cblur=5)


def flower(P, cx, cy, R, rot, seed, rs):
    """hoa 6 cánh tím nhạt, cánh trên to có đốm tím đậm + chấm vàng giữa"""
    for k in range(6):
        a = rot - math.pi / 2 + k * math.pi / 3
        top = (k == 0)
        rr = R * (1.12 if top else 1.0)
        px, py = cx + math.cos(a) * rr * .55, cy + math.sin(a) * rr * .55
        m, h = ellipse(px, py, rr * .55, rr * .36, a, hk=.4)
        d = np.hypot((X - cx), (Y - cy)) / rr
        base = lerpc(hexc('#a892e0'), hexc('#a892e0'), d)
        u = (X - cx) * math.cos(a) + (Y - cy) * math.sin(a)
        vv = -(X - cx) * math.sin(a) + (Y - cy) * math.cos(a)
        vein = (.5 + .5 * np.cos(vv / (rr * .07))) ** 8 * sstep(.2, .9, d) * .4
        if top:
            bl, _ = ellipse(cx + math.cos(a) * rr * .5, cy + math.sin(a) * rr * .5, rr * .26, rr * .2, a)
            base = lerpc(base, hexc('#5a3aa0'), bl)
            ye, _ = ellipse(cx + math.cos(a) * rr * .5, cy + math.sin(a) * rr * .5, rr * .1, rr * .08, a)
            base = lerpc(base, hexc('#f2cc40'), ye)
        col, _ = P.shade(h, base, amb=.5, dif=.62, spec=.04)
        P.put(m, col, edge=hexc('#5e4a94'), line=.45, lw=.9, contact=.2, cblur=2.5)
    m, h = ellipse(cx, cy, R * .14, R * .14)
    c, _ = P.shade(h, hexc('#e8d07a'), amb=.5, dif=.6)
    P.put(m, c, edge=hexc('#8a7030'), line=.3, lw=.6, contact=.15, cblur=2)


class Flat(Pic):
    """icon phẳng: màu thật, không sáng tối, không bóng tiếp xúc, nét mép mảnh"""
    def shade(self, h, base, **k):
        return np.clip(np.broadcast_to(base, h.shape + (3,)), 0, 1).astype(np.float32), None

    def put(self, m, col, edge=None, line=.55, lw=1.3, contact=.38, cblur=7.0):
        super().put(m, col, edge=edge, line=min(line, .7), lw=.75, contact=0)


def luc_binh():
    P = Flat()
    rs = np.random.RandomState(7)
    # lá + cuống phía sau (cuống phình bọng lộ rõ, lá tròn ở đầu cuống)
    def plant(a, b, r, rx, ry, tone, seed):
        dx, dy = b[0] - a[0], b[1] - a[1]; L = math.hypot(dx, dy); dx, dy = dx / L, dy / L
        petiole(P, a, b, r, seed)
        rot = math.atan2(dx, -dy)                      # trục dọc lá theo hướng cuống
        leaf(P, b[0] + dx * ry * .9, b[1] + dy * ry * .9, rx, ry, rot, tone, seed + 1)
    plant((246, 346), (186, 236), 16, 34, 42, .92, 11)
    plant((268, 346), (330, 230), 16, 35, 43, .92, 12)
    # cuống hoa + chùm hoa
    m, h, s, sd = tube([(256, 340), (258, 260), (262, 180), (266, 110)], [7, 6.5, 6, 5])
    c, _ = P.shade(h, hexc('#86bc4c'))
    P.put(m, c, edge=hexc('#3e6a1e'), contact=.25, cblur=4)
    fl = [(270, 62, 24, .1), (240, 84, 26, -.25), (298, 90, 26, .3), (258, 116, 28, -.05), (288, 138, 27, .2),
          (228, 132, 25, -.4), (252, 160, 27, .05), (304, 176, 24, .35)]
    for i, (x, y, R, r) in enumerate(sorted(fl, key=lambda q: q[1])):
        flower(P, x, y, R, r, 900 + i, rs)
    # cuống + lá phía trước
    plant((248, 350), (176, 306), 18, 36, 44, 1.0, 21)
    plant((264, 350), (338, 300), 18, 36, 44, 1.0, 22)
    # 2 bọng giữa phía trước (gốc), lá nhỏ ngả ra trước
    petiole(P, (250, 356), (234, 300), 20, 31)
    plant((262, 356), (282, 296), 19, 28, 34, 1.03, 32)
    im = P.save('luc_binh_tmp', ow=1.0)
    os.replace(os.path.join(OUTDIR, 'ic-luc_binh_tmp.webp'), os.path.join(OUTDIR, 'luc_binh.webp'))
    im.save(os.path.join(OUTDIR, 'luc_binh.png'))


if __name__ == '__main__':
    os.makedirs(OUTDIR, exist_ok=True)
    luc_binh()
