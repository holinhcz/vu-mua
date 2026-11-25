#!/usr/bin/env python3
# BÈ NỔI (11-25 Link "vẽ cái bè nổi đi" + "3D chi tiết điểm ảnh"): nhà bè miền Tây đặt trên nước, cỡ 2x2 ô.
# Dựng 3D bằng bộ bay3d/ghe3d (dò tia SDF, camera nông trại az 45 el 30), tô từng điểm theo chất liệu:
#   - phao: hàng thùng phuy nhựa xanh nằm ngang nửa chìm (đai nổi 2 đầu), đà gỗ tràm gác ngang trên phao
#   - sàn ván gỗ ghép thưa nhiều tông, nẹp mép, bậc thang tre xuống nước phía trước
#   - chòi: vách ván sơn xanh bạc màu có cửa sổ + cửa ra vào (mặt +x), mái lá dừa nước 2 mái lợp từng lớp, đầu hồi đan lá,
#     nóc buộc tre; hiên nhỏ trước cửa
#   - đồ trên bè (không người): lu nước, 2 chậu bông, dây phơi đồ, cần câu tre dựng vách, giỏ cá, lưới cuộn,
#     cọc buộc bè + dây neo
#   PXU=6 SSA=2 python3 be3d.py OUTDIR [k ...]   (k = hướng 0..3, xoay bè quanh tâm) -> be_<k>.webp + atlas.json
import os, sys, math, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ghe3d as G
B = G.B
from bay3d import V, nz, hexc, sstep, vnoise, Tube, Torus, Line, Ball, Box, M, Scene, F32
from ghe3d import TILE, ZK, Cut, Ell, leaf, clay_pot
import numpy as np

_prev = B.albedo


def albedo_be(obj, P):
    m = obj.mat
    if m == 'lala':     # mái lá dừa nước lợp từng lớp: mỗi lớp mép dưới tối, sợi lá dọc dốc mái
        q = (P - obj.C) @ obj.A.T
        h = obj.h
        jag = (vnoise(P * V(1.6, 1.6, 1.6), 1, 55) - .5) * .5           # mép lớp lá so le, không thẳng hàng
        f = ((q[:, 0] + h[0]) / 1.35 + jag) % 1.0
        row = .58 + .55 * f ** 1.4
        fib = vnoise(P * V(4, 4, 4), .5, 51) - .5
        tone = (B.hsh(np.floor((q[:, 0] + h[0]) / 1.35 + jag) * 7.3 + np.floor(q[:, 1] / 1.8) * 1.9) - .5) * .22
        col = getattr(obj, 'col', hexc('#b48c50'))
        c = col[None] * (row + .3 * fib + tone)[:, None]
        eave = sstep(h[0] - 1.2, h[0], q[:, 0])
        return c * (1 - .18 * eave)[:, None]
    if m == 'phuy':     # thùng phuy nhựa xanh, đai nổi
        col = getattr(obj, 'col', hexc('#2f6fb4'))
        z, r, th = obj.local(P)
        rib = np.exp(-(((z / obj.L) * 3 % 1.0 - .5) / .06) ** 2)
        return col[None] * (.92 - .12 * rib + .1 * (vnoise(P, 1.2, 52) - .5))[:, None]
    if m == 'danla':    # vách đầu hồi đan lá dừa nước: ô đan chéo
        b = obj.o if hasattr(obj, 'o') else obj
        while hasattr(b, 'o'): b = b.o
        q = (P - b.C) @ b.A.T
        pp = (q[:, 0] + q[:, 2]) / 1.4; qq = (q[:, 0] - q[:, 2]) / 1.4
        top = ((np.floor(pp) + np.floor(qq)) % 2) == 0
        f = np.where(top, pp % 1.0, qq % 1.0)
        e = np.exp(-((f - .5) / .38) ** 8)
        col = getattr(obj, 'col', hexc('#c8a866'))
        return col[None] * (.72 + .3 * e + .1 * (vnoise(P, .8, 54) - .5))[:, None]
    if m == 'luoi':     # lưới cuộn: sợi xanh xám, mắt lưới
        g = .5 + .5 * np.sin(P[:, 0] * 5) * np.sin(P[:, 1] * 5 + P[:, 2] * 3)
        col = getattr(obj, 'col', hexc('#7a8a6a'))
        return col[None] * (.7 + .4 * g)[:, None]
    if m == 'tram':     # gỗ tràm hộp (đà, cột): sớ dọc trục 0 của hộp, vỏ xám nâu
        q = (P - obj.C) @ obj.A.T
        base = getattr(obj, 'col', hexc('#8a7458'))
        v = vnoise(q * V(.3, 3.5, 3.5), 1, 53)
        return base[None] * (.78 + .4 * v)[:, None]
    if m == 'vai':      # đồ phơi: vải màu có nếp
        col = getattr(obj, 'col', hexc('#d85a4a'))
        if hasattr(obj, 'C'):
            q = (P - obj.C) @ obj.A.T
            fold = .5 + .5 * np.cos(q[:, 0] * 2.4)
        else:                # võng: sợi dù đan dọc
            fold = .5 + .5 * np.cos((P[:, 0] - P[:, 1]) * 3.2)
        return col[None] * (.84 + .2 * fold)[:, None]
    return _prev(obj, P)


B.albedo = albedo_be


def rot(k):
    c, s = math.cos(k * math.pi / 2), math.sin(k * math.pi / 2)
    return lambda x, y, z: V(c * x - s * y, s * x + c * y, z)


def be(k=0):
    R = rot(k)
    c_, s_ = math.cos(k * math.pi / 2), math.sin(k * math.pi / 2)
    D = lambda x, y, z=0.0: V(c_ * x - s_ * y, s_ * x + c_ * y, z)      # hướng (xoay theo bè)
    o = []
    HX = 36.0                     # nửa cạnh sàn (2 ô = 90.5, chừa mép nước)
    ZD = 6.4                      # mặt sàn
    # ---- phao thùng phuy: 4 hàng dọc trục y, mỗi hàng 7 thùng
    for xr in (-27, -9, 9, 27):
        for j in range(7):
            yc = -33 + j * 11
            t = Tube(tuple(R(xr, yc - 4.6, .6)), tuple(D(0, 1)), 9.2, [(0, 3.0), (.06, 3.4), (.5, 3.55), (.94, 3.4), (1, 3.0)], 'phuy')
            t.col = hexc('#2f6fb4') if (j + int(xr)) % 5 else hexc('#3a7ec0')
            o.append(t)
    # ---- đà gỗ tràm gác ngang trên phao (dọc trục x), 2 đà viền dọc trục y
    for yb in (-34, -17, 0, 17, 34):
        o.append(M(Box(tuple(R(0, yb, 4.6)), (D(1, 0), D(0, 1), (0, 0, 1)), (HX + .5, .9, .9), 'tram', rr=.35), col='#8a7458'))
    for xb in (-HX, HX):
        o.append(M(Box(tuple(R(xb, 0, 5.2)), (D(1, 0), D(0, 1), (0, 0, 1)), (.9, HX + .5, 1.0), 'go2', rr=.3), col='#6e4a2c'))
    # ---- sàn ván ghép thưa (ván dọc trục y), mỗi tấm 1 tông
    n = 26
    w = 2 * HX / n
    for i in range(n):
        xc = -HX + w * (i + .5)
        tone = ['#b0844e', '#a27646', '#b98e58', '#9c7044', '#ad8150'][(i * 7) % 5]
        o.append(M(Box(tuple(R(xc, 0, ZD - .45)), (D(1, 0), D(0, 1), (0, 0, 1)), (w * .5 - .16, HX, .45), 'go2', rr=.12), col=tone))
    # nẹp mép sàn 4 bên
    for sd in (-1, 1):
        o.append(M(Box(tuple(R(0, sd * (HX + .4), ZD - .2)), (D(1, 0), D(0, 1), (0, 0, 1)), (HX + .8, .5, .65), 'go2', rr=.15), col='#7a5030'))
        o.append(M(Box(tuple(R(sd * (HX + .4), 0, ZD - .2)), (D(1, 0), D(0, 1), (0, 0, 1)), (.5, HX + .8, .65), 'go2', rr=.15), col='#7a5030'))
    # ---- chòi: góc sau (-x, -y), cửa quay ra +x
    xc, yc = -17.0, -13.0
    hx, hy, hw = 15.0, 19.0, 7.2
    zw = ZD + 2 * hw
    wall = Box(tuple(R(xc, yc, ZD + hw)), (D(1, 0), D(0, 1), (0, 0, 1)), (hx, hy, hw), 'van', rr=.3)
    wall.col = hexc('#8fb8bc'); wall.win = 6.4; wall.sh = '#3f7a5a'
    o.append(wall)
    # chân cột góc (cột tràm) lộ ở 4 góc
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(M(Box(tuple(R(xc + sx * hx, yc + sy * hy, ZD + hw + .6)), ((0, 0, 1), D(1, 0), D(0, 1)), (hw + .6, .75, .75), 'tram', rr=.3), col='#7a6448'))
    # mái lá 2 mái, nóc dọc trục y
    run, rise, ov = hx + 3.6, 9.5, 3.4
    a = math.atan2(rise, run)
    L2 = math.hypot(run, rise) / 2
    zr = zw + rise - .3
    for sx in (-1, 1):
        dn = D(sx * math.cos(a), 0, -math.sin(a))
        nr = D(sx * math.sin(a), 0, math.cos(a))
        cc = R(xc, yc, zr) + dn * L2 + nr * .55
        r_ = Box(tuple(cc), (dn, D(0, 1), nr), (L2, hy + ov, .75), 'lala', rr=.2)
        r_.col = hexc('#a8844e' if sx > 0 else '#9c7a48')
        o.append(r_)
    # đầu hồi đan lá (tam giác) 2 đầu
    for sy in (-1, 1):
        g = Box(tuple(R(xc, yc + sy * (hy - .2), zw + rise / 2)), (D(1, 0), D(0, 1), (0, 0, 1)), (hx + .2, .45, rise / 2 + .2), 'danla', rr=.1)
        g.col = hexc('#c8a866')
        for sx in (-1, 1):
            g = Cut(g, tuple(R(xc, yc, zr - .3)), tuple(D(sx * math.sin(a), 0, math.cos(a))))
        o.append(g)
    # nóc: cây tre đè nóc + dây buộc
    p0 = R(xc, yc - hy - ov, zr + 1.0); p1 = R(xc, yc + hy + ov, zr + 1.0)
    o.append(M(Line([tuple(p0), tuple(p1)], .85, 'coc', nodes=6.5), col='#a8884e', dk='#6e5430'))
    for t in np.linspace(.08, .92, 6):
        o.append(M(Torus(tuple(p0 + (p1 - p0) * t), tuple(D(0, 1)), .95, .25, 'may'), col='#6a4424'))
    # ---- hiên trước cửa: mái lá nhỏ chìa ra +x trên 2 cột tre
    ex = xc + hx
    for sy in (-1, 1):
        o.append(B.stake(*R(ex + 9.5, yc + sy * 6.5, 0)[:2], ZD, zw - 1.5, .7, nodes=5))
    hv = Box(tuple(R(ex + 5.2, yc, zw - .6)), (D(math.cos(.32), 0, -math.sin(.32)), D(0, 1), D(math.sin(.32), 0, math.cos(.32))), (5.8, 8.2, .6), 'lala', rr=.2)
    hv.col = hexc('#a8844e'); o.append(hv)
    # võng dù treo giữa 2 cột hiên (miền Tây nhà nào cũng có)
    va = R(ex + 9.5, yc - 6.5, ZD + 9.5); vb = R(ex + 9.5, yc + 6.5, ZD + 9.5)
    vp = [tuple(va + (vb - va) * t + V(0, 0, -5.5 * math.sin(math.pi * t))) for t in np.linspace(0, 1, 14)]
    o.append(M(Line(vp, 1.15, 'vai'), col='#3a8a5a'))
    vp2 = [tuple(va + (vb - va) * t + V(0, 0, -5.5 * math.sin(math.pi * t) + .9)) for t in np.linspace(.1, .9, 10)]
    o.append(M(Line(vp2, .55, 'vai'), col='#d8b040'))
    # ---- đồ trên sàn phía trước
    # lu nước sành + nắp gỗ, gáo dừa
    jx, jy = -8.0, 27.0
    o.append(M(Ball(tuple(R(jx, jy, ZD + 4.4)), 4.1, 'chum', sq=(1, 1, 1.15)), sp=.5, pw=40))
    o.append(M(Torus(tuple(R(jx, jy, ZD + 8.9)), (0, 0, 1), 2.5, .45, 'chum'), sp=.5, pw=40))
    o.append(M(Tube(tuple(R(jx, jy, ZD + 9.0)), (0, 0, 1), .7, [(0, 3.0), (1, 2.9)], 'go2'), col='#8a5a34'))
    o.append(M(Ball(tuple(R(jx + 1.4, jy + 1.0, ZD + 10.0)), 1.3, 'gao', sq=(1, 1, .55))))
    o.append(M(Line([tuple(R(jx + 1.4, jy + 1.0, ZD + 10.3)), tuple(R(jx + 4.5, jy + 2.6, ZD + 11.2))], .25, 'go2'), col='#6a4526'))
    # 2 chậu bông (bông giấy đỏ, vạn thọ vàng)
    for (px, py, fc) in ((21.0, -30.0, '#e0485a'), (30.0, -18.0, '#f0b028')):
        o += clay_pot(None, tuple(R(px, py, ZD)), r=3.0)
        cz = ZD + 4.4
        rs = np.random.RandomState(int(px))
        for j in range(7):
            an = j / 7 * 2 * math.pi
            o.append(leaf(tuple(R(px, py, cz)), tuple(D(math.cos(an), math.sin(an), .5)), 4.4, 2.2, col='#4f8a36'))
        for j in range(6):
            an = rs.uniform(0, 2 * math.pi); rr_ = rs.uniform(0, 2.2)
            o.append(M(Ball(tuple(R(px + math.cos(an) * rr_, py + math.sin(an) * rr_, cz + 1.8 + rs.uniform(0, 1.6))), 1.25, 'muoi'), col=fc))
    # dây phơi đồ: cột tre ở góc trước-phải, dây nối về cột chòi
    pa = R(-31.0, 31.0, 0)[:2]
    o.append(B.stake(pa[0], pa[1], ZD, ZD + 15, .7, nodes=5))
    q0 = R(xc - hx, yc + hy, ZD + 13.6); q1 = R(-31.0, 31.0, ZD + 13.6)
    o.append(M(Line([tuple(q0 + (q1 - q0) * s + V(0, 0, -1.4 * math.sin(math.pi * s))) for s in np.linspace(0, 1, 12)], .16, 'day'), col='#e9e3d0'))
    for s, col, ln in ((.28, '#d85a4a', 6.5), (.5, '#3f7fc0', 8.0), (.72, '#e8d058', 6.0)):
        cp = q0 + (q1 - q0) * s + V(0, 0, -1.4 * math.sin(math.pi * s))
        dd = nz(q1 - q0)
        sd_ = nz(np.cross(V(0, 0, 1), dd))
        cl = Box(tuple(cp + V(0, 0, -ln / 2)), (dd, sd_, (0, 0, 1)), (2.8, .25, ln / 2), 'vai', rr=.15)
        cl.col = hexc(col); o.append(cl)
    # cần câu tre dựng nghiêng vào vách (+y), giỏ cá dưới chân
    b0 = R(xc + 6, yc + hy + 1.3, ZD + .3); b1 = R(xc + 13, yc + hy + 2.0, zw + 9)
    o.append(M(Line([tuple(b0), tuple(b1)], [.45, .2], 'coc', nodes=6), col='#d3bf6a', dk='#8a7c44'))
    o.append(M(Line([tuple(b1), tuple(b1 + V(0, 0, -10) + D(1.5, 2.0))], .07, 'day'), col='#efe9d8'))
    gb = R(xc + 2, yc + hy + 3.6, ZD)
    o.append(M(Tube(tuple(gb), (0, 0, 1), 3.4, [(0, 2.0), (.6, 2.5), (.85, 1.5), (1, 1.7)], 'dan', shell=.25, open1=True, wv=(22, .08)), col='#c7a466'))
    o.append(M(Torus(tuple(gb + V(0, 0, 3.4)), (0, 0, 1), 1.7, .24, 'may'), col='#7a5230'))
    # lưới cuộn trên sàn
    # ô lồng cá giữa sàn trước: khung ván quanh ô nước, lưới căng mép, cá quẫy (vòng sóng)
    fx, fy, fh = 15.0, 13.0, 7.0
    o.append(M(Box(tuple(R(fx, fy, ZD - .05)), (D(1, 0), D(0, 1), (0, 0, 1)), (fh, fh, .14), 'nuoc'), col='#2e6a6a'))
    for sd in (-1, 1):
        o.append(M(Box(tuple(R(fx + sd * (fh + .7), fy, ZD + .35)), (D(1, 0), D(0, 1), (0, 0, 1)), (.75, fh + 1.45, .4), 'go2', rr=.12), col='#7a5030'))
        o.append(M(Box(tuple(R(fx, fy + sd * (fh + .7), ZD + .35)), (D(1, 0), D(0, 1), (0, 0, 1)), (fh + 1.45, .75, .4), 'go2', rr=.12), col='#7a5030'))
    for t in (-.5, .2):
        o.append(M(Torus(tuple(R(fx + t * 6, fy + t * 3 + 1, ZD + .12)), (0, 0, 1), 1.6 + abs(t) * 2, .12, 'nuoc'), col='#9cc8c8'))
    for sx_ in (-1, 1):
        for sy_ in (-1, 1):
            o.append(B.stake(*R(fx + sx_ * (fh + .7), fy + sy_ * (fh + .7), 0)[:2], ZD, ZD + 3.0, .5, nodes=5))
    # ghế tre dài cạnh hiên
    bx, by = ex + 4.0, yc + 13.5
    for sx_ in (-1, 1):
        for sy_ in (-1, 1):
            o.append(M(Line([tuple(R(bx + sx_ * 1.6, by + sy_ * 4.2, ZD)), tuple(R(bx + sx_ * 1.6, by + sy_ * 4.2, ZD + 3.6))], .4, 'coc', nodes=4), col='#cfae72', dk='#8f6c3c'))
    for j in range(5):
        o.append(M(Line([tuple(R(bx - 1.9 + j * .95, by - 5.0, ZD + 3.8)), tuple(R(bx - 1.9 + j * .95, by + 5.0, ZD + 3.8))], .42, 'coc', nodes=4), col='#d8b87a', dk='#8f6c3c'))
    # đống củi chẻ chất sát vách sau (góc phải)
    rs = np.random.RandomState(5)
    for lay in range(3):
        for j in range(5 - lay):
            yy = -31 + j * 2.6 + lay * 1.3
            zz = ZD + 1.2 + lay * 2.1
            o.append(M(Line([tuple(R(4.0 + rs.uniform(-.6, .6), yy, zz)), tuple(R(13.0 + rs.uniform(-.6, .6), yy, zz))], 1.15, 'cui'), col=['#8a6a44', '#9a7650', '#7e603c'][(j + lay) % 3]))
    # bậc thang tre xuống nước ở mép trước (+x)
    sxs = HX + 1.2
    for sy in (-1, 1):
        o.append(M(Line([tuple(R(sxs, 2 + sy * 3.2, ZD)), tuple(R(sxs + 4.5, 2 + sy * 3.2, -3))], .55, 'coc', nodes=5), col='#cfae72', dk='#8f6c3c'))
    for t in (.3, .62):
        zz = ZD + (-3 - ZD) * t; xx = sxs + 4.5 * t
        o.append(M(Line([tuple(R(xx, -1.4, zz)), tuple(R(xx, 5.4, zz))], .5, 'coc', nodes=8), col='#cfae72', dk='#8f6c3c'))
    # cọc buộc bè + dây neo (góc trước-trái và sau-phải)
    for (cx_, cy_, ax_, ay_) in ((HX + 6.5, -HX - 4.0, HX - 1, -HX + 1), (-HX - 5.0, HX + 6.0, -HX + 1, HX - 1)):
        sp = R(cx_, cy_, 0)[:2]
        o.append(B.stake(sp[0], sp[1], -6, ZD + 11, .9, nodes=5.5))
        r1 = R(cx_, cy_, ZD + 8.5); r2 = R(ax_, ay_, ZD + .6)
        o.append(M(Line([tuple(r1 + (r2 - r1) * s + V(0, 0, -2.0 * math.sin(math.pi * s))) for s in np.linspace(0, 1, 10)], .26, 'day'), col='#c8a466'))
        o.append(M(Torus(tuple(r1), (0, 0, 1), 1.0, .28, 'day'), col='#c8a466'))
    return Scene(o)


if __name__ == '__main__':
    OUT = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    pu = B.PXU
    ap = os.path.join(OUT, 'atlas.json')
    meta = json.load(open(ap)) if os.path.exists(ap) else {"px_per_unit": pu, "frames": {}}
    meta["px_per_unit"] = pu
    for ks in (sys.argv[2:] or ['0']):
        kk = int(ks); key = 'be_%d' % kk
        (im, imw), anc = B.render(be(kk), key)
        imw.save(os.path.join(OUT, key + '.webp'), lossless=True, quality=100, method=6)
        meta["frames"][key] = {"file": key + '.webp', "w": imw.width, "h": imw.height, "fw": 2, "fd": 2,
                               "ox": round(-anc[0] / pu, 2), "oy": round(-anc[1] / pu, 2), "gw": round(imw.width / pu, 2), "gh": round(imw.height / pu, 2)}
        print(key, meta["frames"][key], flush=True)
        json.dump(meta, open(ap, 'w'), indent=1)
