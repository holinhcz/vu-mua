#!/usr/bin/env python3
# ĐỒ CÂU 4 BẬC dựng 3D (11-25 Link "vẽ lại cước + phao + lưỡi câu mỗi loại 4 bậc, rọ đựng 4 bậc, vẽ chi tiết"):
# cùng bộ bắn tia bay3d.py / ghe3d.py (góc nhìn vườn xoay 45 nghiêng 30, bóng đổ mềm, AO, viền mảnh), ảnh nền trong.
#   python3 do3d.py OUTDIR [line1 .. line4 flo1 .. flo4 hook1 .. hook4 cage1 .. cage4]     (env PXU, SSA)
#   ra <id>.webp (nền trong suốt)
# Bậc (theo cc_data.gd LINE / FLO / CAGE; lưỡi câu là món mới):
#   line: 1 Cước 0.2 ống gỗ mộc dây trong | 2 Cước 0.35 ống sơn đỏ dây xanh nhạt | 3 Cước 0.5 ống gỗ sẫm viền đồng dây xanh lá |
#         4 Dây dù bện: ống gỗ chạm, nắp đồng, dây bện 2 màu
#   flo:  1 lông nhím khoang đen trắng đầu đỏ | 2 lông công: mắt công + bấc sơn | 3 đèn đêm: bấc sơn, cần trong, đầu sáng xanh |
#         4 sơn mài khảm xà cừ, khoanh vàng
#   hook: 1 sắt rèn tay, buộc chỉ đỏ | 2 thép trắng có ngạnh, chì, dây cước | 3 lưỡi đôi đồng + khoá xoay | 4 lưỡi chùm 3 mạ vàng + khoá + hạt
#   cage: 1 giỏ tre nhỏ có hom | 2 giỏ tre lớn, đai mây, quai dây | 3 lồng lưới khoanh vòng | 4 rọ mây sơn dầu, đai đồng, nắp gỗ
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ghe3d as G                      # nạp bộ tăng tốc + chất liệu ghe (go2, dco, cam ...) + LT sáng
B = G.B
from bay3d import V, nz, hexc, sstep, vnoise, Tube, Torus, Line, Ball, Box, M, Scene, F32
from ghe3d import Ell, grp
import numpy as np

Z = V(0, 0, 1)
RT = B.RT                                # ngang màn hình (nằm ngang)
HF = nz(np.cross(Z, RT))                 # pháp tuyến ngang quay về camera
HF = HF if float(HF @ (-B.FWD)) > 0 else -HF


def pl(x, z, o=(0, 0, 0)):
    """điểm trong mặt phẳng đứng quay về camera"""
    return V(*o) + RT * x + Z * z


# ------------------------------------------------------------ chất liệu riêng đồ câu
_prev = B.albedo
hsh_ = B.hsh
GOLD = hexc('#d8a830')


def albedo_do(obj, P):
    m = obj.mat
    n = len(P)
    if m == 'cuon':     # cước quấn ống: vòng quấn ngang mịn, ánh dọc
        z, q, th = obj.local(P)
        k = getattr(obj, 'k', 3.0)
        col = obj.col
        ring = .5 + .5 * np.sin(z * 2 * np.pi * k)
        c = col[None] * (.84 + .16 * ring + .08 * (vnoise(P, 2, 61) - .5))[:, None]
        cr = np.exp(-((((z * 1.3 + th * .5) % 1.0) - .5) / .06) ** 2)     # lớp quấn chéo
        return c * (1 - .1 * cr)[:, None]
    if m == 'ben':      # dây dù bện: các vòng dây nằm ngang, mỗi vòng sợi bện chữ V hai màu, rãnh giữa vòng tối
        z, q, th = obj.local(P)
        k = getattr(obj, 'k', 1.4)
        zz = z * k
        f = zz % 1.0
        sgn = np.where((np.floor(zz) % 2) == 0, 1.0, -1.0)
        st = ((th / (2 * np.pi) * 10 + sgn * f * .8) % 1.0) < .5
        c = np.where(st[:, None], obj.col[None], obj.dk[None])
        groove = np.exp(-((f - .5) / .09) ** 2)
        c = c * (1 - .1 * (np.abs(f - .5) > .42))[:, None]
        return c * (1 - .35 * (1 - np.minimum(1, np.abs(f - .0) / .12) * np.minimum(1, np.abs(f - 1) / .12)))[:, None]
    if m == 'dan2':     # đan lóng mốt: nan ngang luồn trên-dưới nan dọc, mỗi nan một tông
        z, q, th = obj.local(P)
        N_ = obj.wv[0] if obj.wv else 40
        u = th / (2 * np.pi) * N_; v = z * getattr(obj, 'kv', 1.5)
        iu = np.floor(u); iv = np.floor(v); fu = u - iu; fv = v - iv
        over = ((iu + iv) % 2) == 0
        base = getattr(obj, 'col', B.TRE)
        tone = np.where(over, hsh_(iv * 7.1), hsh_(iu * 3.3)) - .5
        sh = np.where(over, .8 + .25 * np.sin(np.pi * fv), .74 + .22 * np.sin(np.pi * fu))
        gap = np.where(over, np.exp(-((fv - 0) / .07) ** 2) + np.exp(-((fv - 1) / .07) ** 2), np.exp(-((fu - 0) / .08) ** 2) + np.exp(-((fu - 1) / .08) ** 2))
        c = base[None] * (sh * (1 + .18 * tone))[:, None]
        c = c * (1 - .45 * np.clip(gap, 0, 1))[:, None]
        return c * (1 - .12 * sstep(.6, .9, vnoise(P, 1.4, 73)))[:, None]
    if m == 'gox':      # gỗ có vân: mặt vành ống thấy vòng tuổi, hông thấy thớ dọc
        col = obj.col
        if isinstance(obj, Tube):
            z, q, th = obj.local(P)
            w = vnoise(P, .9, 70)
            ring = .5 + .5 * np.sin(q * 5.5 + w * 3)
            grain = .5 + .5 * np.sin(th * 3 + q * 2 + w * 5)
            top = (np.abs(z) < .05) | (np.abs(z - obj.L) < .05)
            v = np.where(top, ring, grain)
        else:
            v = vnoise(P * V(1, 1, 3), 1.2, 71)
        return col[None] * (.82 + .26 * v + .06 * (vnoise(P, 4, 72) - .5))[:, None]
    if m == 'band':     # cọng / cần có khoanh màu theo chiều dài (bands: [(t0, t1, màu)])
        _, sl = obj.seg(P)
        t = sl / max(float(obj.cum[-1]), 1e-3)
        c = np.broadcast_to(obj.col, (n, 3)).copy()
        for t0, t1, cc in obj.bands:
            c = np.where(((t >= t0) & (t < t1))[:, None], hexc(cc)[None], c)
        return c * (.92 + .12 * (vnoise(P, 4, 63) - .5))[:, None]
    if m == 'bandz':    # khối (elip / ống) khoanh màu theo độ cao thế giới
        c = np.broadcast_to(obj.col, (n, 3)).copy()
        for z0, z1, cc in obj.bands:
            c = np.where(((P[:, 2] >= z0) & (P[:, 2] < z1))[:, None], hexc(cc)[None], c)
        return c * (.9 + .14 * (vnoise(P, 3, 64) - .5))[:, None]
    if m == 'congeye':  # mắt lông công
        q = obj.local(P)
        r = np.sqrt((q[:, 0] / obj.R[0]) ** 2 + (q[:, 1] / obj.R[1]) ** 2)
        r = r + .05 * np.sin(np.arctan2(q[:, 1], q[:, 0]) * 3)
        c = np.broadcast_to(hexc('#8aa83a'), (n, 3)).copy()
        for rr, cc in ((.78, '#3f9a4a'), (.58, '#a8822e'), (.42, '#2a9a96'), (.26, '#1c2c72')):
            c = np.where((r < rr)[:, None], hexc(cc)[None], c)
        fib = .5 + .5 * np.sin(np.arctan2(q[:, 1], q[:, 0]) * 46)
        return c * np.where(r > .6, .82 + .25 * fib, 1.0)[:, None]
    if m == 'xacu':     # sơn mài đen bóng khảm xà cừ: hàng hoa 4 cánh đều nhau giữa các khoanh vàng
        c = np.broadcast_to(hexc('#1c1616'), (n, 3)).copy()
        q = obj.local(P)
        ang = np.arctan2(q[:, 2], q[:, 1])
        rr = np.hypot(q[:, 1], q[:, 2])
        u = ang / (2 * np.pi) * 9
        v = q[:, 0] / 1.25
        row = np.floor(v)
        u = u + .5 * (row % 2)
        du = ((u % 1.0) - .5) * (2 * np.pi * np.maximum(rr, .3) / 9); dv = ((v % 1.0) - .5) * 1.25
        pa = np.arctan2(dv, du); pr = np.hypot(du, dv)
        petal = pr < .36 * (.55 + .45 * np.abs(np.cos(pa * 2)))
        dot = pr < .12
        w = .5 + .5 * np.sin(ang * 3 + q[:, 0] * 2)
        pearl = hexc('#eef4f2')[None] * (1 - w * .5)[:, None] + hexc('#f0d0e4')[None] * (w * .3)[:, None] + hexc('#c8eedc')[None] * (w * .2)[:, None]
        c = np.where(petal[:, None], pearl, c)
        c = np.where(dot[:, None], GOLD[None], c)
        for z0, z1 in obj.gold:
            c = np.where(((P[:, 2] >= z0) & (P[:, 2] < z1))[:, None], GOLD[None] * (.9 + .2 * vnoise(P, 3, 67))[:, None], c)
        return c
    if m == 'luoi':     # lưới cước mắt thoi: sợi xanh, lỗ thấy lòng tối
        z, q, th = obj.local(P)
        R = float(obj.pr.max())
        u = th * R / 1.1; v = z / 1.1
        a = np.abs(((u + v) % 1.0) - .5); b = np.abs(((u - v) % 1.0) - .5)
        st = (np.maximum(a, b) > .40)
        knot = (a > .40) & (b > .40)
        c = np.where(st[:, None], obj.col[None], hexc('#3e6a52')[None])
        return np.where(knot[:, None], obj.col[None] * .8, c)
    if m == 'met':      # kim loại có màu riêng (sắt, thép, đồng, vàng)
        return obj.col[None] * (.86 + .28 * vnoise(P, getattr(obj, 'ns', 1.5), 68))[:, None]
    return _prev(obj, P)


# 11-25 08:47 Link "vẽ màu sáng lên chứ không phải tăng đèn": nâng màu sơn (albedo) tươi + sáng, đèn giữ nguyên
CLIFT = float(os.environ.get("CLIFT", ".87")); CSAT = float(os.environ.get("CSAT", "1.2"))
def albedo_lift(obj, P):
    c = np.clip(albedo_do(obj, P), 0, 1)
    l = (c * np.array([.299, .587, .114], dtype=c.dtype)).sum(1, keepdims=True)
    c = np.clip(l + (c - l) * CSAT, 0, 1)
    return (c ** CLIFT).astype(F32)
B.albedo = albedo_lift
# 11-25 Link "icon chỗ khuất tối sáng lên chút": icon sáng hơn ghe - nền cao, bóng đổ nhạt, lòng ống bớt tối
B.LT.update(amb=.56, sky=.14, dif=.42, shmin=.65, aop=.45, expo=1.0, inner=.3, spec=.3, tone=.8)   # 11-25 08:09 Link "vẽ cùng 1 độ sáng, bên sáng đéo gì sáng lóe": ánh sáng dịu, không cháy trắng


def met(o, col, sp=.6, pw=40, ns=1.5):
    o = M(o, col=col, sp=sp, pw=pw); o.ns = ns
    return o


def arc(a, b, h, n=14, side=None):
    """quai cong mềm từ a tới b, đỉnh cao thêm h (theo trục z)"""
    a = V(*a); b = V(*b)
    return [tuple(a + (b - a) * t + Z * (h * math.sin(math.pi * t))) for t in np.linspace(0, 1, n)]


def soft(p0, p1, n=16, amp=.35, waves=.55, ph=0.0):
    """dây cước mềm: cong nhẹ hình sin theo ngang màn hình"""
    p0 = V(*p0); p1 = V(*p1)
    return [tuple(p0 + (p1 - p0) * t + RT * (amp * math.sin(t * math.pi * 2 * waves + ph) * math.sin(math.pi * t))) for t in np.linspace(0, 1, n)]


# ------------------------------------------------------------ lưỡi câu
def hook_pts(sc=1.0, o=(0, 0, 0), rot=0.0, flip=1.0):
    """đường lưỡi câu chữ J trong mặt phẳng đứng (xoay rot quanh trục đứng): thân, bụng cong, mũi"""
    ax = RT * math.cos(rot) + HF * math.sin(rot)
    O = V(*o)

    def p(x, z):
        return O + ax * (x * sc * flip) + Z * (z * sc)
    pts = [p(0, 7), p(0, 3.5), p(0, .4)]
    for a in np.linspace(math.pi, 2 * math.pi, 9)[1:]:
        pts.append(p(1.9 + 1.9 * math.cos(a), .4 + 1.9 * math.sin(a)))
    pts += [p(3.85, 1.6), p(3.6, 2.9)]
    rr = [.34, .34, .33] + [.33 - .02 * i for i in range(8)] + [.16, .05]
    barb = [p(3.66, 2.3), p(3.15, 1.55)]
    return pts, [r * sc for r in rr], barb, p


def hook(t):
    o = []
    if t == 1:      # sắt rèn tay: đen xám, đầu dẹt, buộc chỉ đỏ + dây cước
        pts, rr, barb, p = hook_pts(1.25)
        o.append(met(Line([tuple(q) for q in pts], rr, 'met'), hexc('#6e6a62'), sp=.18, pw=18, ns=4))
        o.append(met(Ball(tuple(p(0, 7.2)), .55 * 1.25, 'met', sq=(1, 1, .6)), hexc('#6e6a62'), sp=.18, pw=18))
        for k in range(6):
            o.append(M(Torus(tuple(p(0, 5.2 + k * .32)), (0, 0, 1), .48, .2, 'day'), col='#c83228'))
        o.append(M(Line(soft(p(0, 7.3), p(0, 15.5)), .12, 'day'), col='#e8ecea'))
    elif t == 2:    # thép trắng, có ngạnh, khoen tròn, chì + cước
        pts, rr, barb, p = hook_pts(1.3)
        o.append(met(Line([tuple(q) for q in pts], rr, 'met'), hexc('#c4ccd2'), sp=.8, pw=60))
        o.append(met(Line([tuple(q) for q in barb], [.18 * 1.3, .04], 'met'), hexc('#c4ccd2'), sp=.8, pw=60))
        o.append(met(Torus(tuple(p(0, 7.55)), tuple(HF), .55, .17, 'met'), hexc('#c4ccd2'), sp=.8, pw=60))
        o.append(M(Line(soft(p(0, 8.1), p(0, 16.5), ph=.8), .11, 'day'), col='#a8d4e8'))
        o.append(met(Ball(tuple(p(0, 12.6)), .75, 'met', sq=(1, 1, 1.3)), hexc('#7a7e80'), sp=.3, pw=24, ns=3))
    elif t == 3:    # lưỡi đôi đồng: 2 lưỡi quay lưng chung thân, khoá xoay
        for fl in (1, -1):
            pts, rr, barb, p = hook_pts(1.25, flip=fl)
            o.append(met(Line([tuple(q) for q in pts], rr, 'met'), hexc('#c87a30'), sp=.7, pw=50))
            o.append(met(Line([tuple(q) for q in barb], [.2, .04], 'met'), hexc('#c87a30'), sp=.7, pw=50))
        o.append(met(Torus(tuple(p(0, 7.45)), tuple(HF), .6, .17, 'met'), hexc('#c87a30'), sp=.7, pw=50))
        o.append(met(Ball(tuple(p(0, 8.75)), .5, 'met', sq=(1, 1, 1.8)), hexc('#9aa0a4'), sp=.8, pw=60))   # khoá xoay
        for zz in (7.95, 9.55):
            o.append(met(Torus(tuple(p(0, zz)), tuple(RT), .4, .13, 'met'), hexc('#9aa0a4'), sp=.8, pw=60))
        o.append(M(Line(soft(p(0, 9.85), p(0, 14.2), amp=.25), .13, 'day'), col='#6aa86a'))
    else:           # lưỡi chùm 3 mạ vàng + khoá xoay + hạt đỏ + dây bện
        for k in range(3):
            pts, rr, barb, p0 = hook_pts(1.2, rot=k * 2 * math.pi / 3 - math.pi / 6 + .15)
            o.append(met(Line([tuple(q) for q in pts], rr, 'met'), hexc('#e2b43a'), sp=.9, pw=70))
            o.append(met(Line([tuple(q) for q in barb], [.2, .04], 'met'), hexc('#e2b43a'), sp=.9, pw=70))
        p = lambda x, z: pl(x, z)
        o.append(met(Line([tuple(p(0, 0)), tuple(p(0, 8.8))], .42, 'met'), hexc('#e2b43a'), sp=.9, pw=70))
        o.append(met(Torus(tuple(p(0, 9.5)), tuple(HF), .62, .18, 'met'), hexc('#e2b43a'), sp=.9, pw=70))
        o.append(M(Ball(tuple(p(0, 10.6)), .62, 'cam'), col='#d42a20', sp=.8, pw=60))
        o.append(met(Ball(tuple(p(0, 12.2)), .55, 'met', sq=(1, 1, 2.0)), hexc('#d8a838'), sp=.9, pw=70))
        for zz in (11.1, 13.4):
            o.append(met(Torus(tuple(p(0, zz)), tuple(RT), .45, .14, 'met'), hexc('#d8a838'), sp=.9, pw=70))
        o.append(M(Line(soft(p(0, 13.8), p(0, 19), amp=.3, ph=1.5), .2, 'band'), col='#c8a060'))
        o[-1].bands = [(i / 20, (i + .5) / 20, '#2e4a26') for i in range(20)]
    return Scene(o)


# ------------------------------------------------------------ cuộn cước
def spool(t):
    """cuộn cước lên bậc: ống to dần, vành dày + chi tiết hơn; đầu dây gài khía vành, không móc lưỡi"""
    o = []
    R, H, rc, ft = {1: (4.2, 6.0, 3.2, .6), 2: (4.7, 6.6, 3.6, .7), 3: (5.2, 7.0, 4.0, .8), 4: (5.8, 7.6, 4.5, .95)}[t]
    fl, ln, k, lr = {1: ('#c08a4e', '#e4ecee', 4.0, .1), 2: ('#c0442e', '#94c4de', 3.4, .13),
                     3: ('#9a6a40', '#5aa060', 2.8, .17), 4: ('#d4aa72', '#9a6a3c', 1.4, .26)}[t]
    for z0 in (0.0, H + ft):    # 2 vành ống
        o.append(M(Tube((0, 0, z0), (0, 0, 1), ft, [(0, R), (1, R)], 'gox'), col=fl))
        o.append(M(Torus((0, 0, z0 + ft / 2), (0, 0, 1), R, ft / 2, 'gox'), col=fl))
        if t == 2:   # vành sơn có chỉ kem
            o.append(M(Torus((0, 0, z0 + ft / 2), (0, 0, 1), R + .05, .12, 'cam'), col='#f0e4c0'))
        if t >= 3:   # viền đồng + đinh tán
            o.append(met(Torus((0, 0, z0 + ft / 2), (0, 0, 1), R + .08, .24, 'met'), hexc('#d8a838'), sp=.8, pw=50))
            for a in range(8 if t == 4 else 4):
                aa = a * 2 * math.pi / (8 if t == 4 else 4) + .4
                o.append(met(Ball((math.cos(aa) * (R - .8), math.sin(aa) * (R - .8), H + 2 * ft + .02), .28, 'met', sq=(1, 1, .5)), hexc('#e2bc52'), sp=.9, pw=60))
    zt = H + 2 * ft
    o.append(M(Tube((0, 0, zt - .05), (0, 0, 1), .1, [(0, .9), (1, .9)], 'toi'), col='#2e2214'))   # lỗ trục
    if t == 4:      # nắp đồng có 2 vòng chạm
        o.append(met(Tube((0, 0, zt), (0, 0, 1), .25, [(0, 2.6), (1, 2.4)], 'met'), hexc('#b8902e'), sp=.85, pw=60, ns=3))
        for rr in (1.3, 2.1):
            o.append(met(Torus((0, 0, zt + .25), (0, 0, 1), rr, .12, 'met'), hexc('#e8c45a'), sp=.9, pw=70))
        o.append(M(Tube((0, 0, zt + .2), (0, 0, 1), .15, [(0, .8), (1, .8)], 'toi'), col='#2e2214'))
    c = Tube((0, 0, ft), (0, 0, 1), H, [(0, rc), (.5, rc + .15), (1, rc)], 'cuon' if t < 4 else 'ben')
    c.col = hexc(ln); c.k = k
    if t == 4:
        c.dk = hexc('#5a3a1e')
    o.append(c)
    # đầu dây: từ mặt cuộn phía trước vòng xuống, gài vô khía mép vành dưới, có gút nhỏ
    a0 = math.atan2(float(HF[1]), float(HF[0])) + .35
    s0 = V(math.cos(a0) * (rc + .1), math.sin(a0) * (rc + .1), ft + H * .7)
    a1 = a0 + .55
    e = V(math.cos(a1) * (R + .1), math.sin(a1) * (R + .1), ft * .5)
    mid = (s0 + e) / 2 + HF * 1.8 + RT * .6 + V(0, 0, -.4)
    pts = [tuple(s0 + (mid - s0) * u * 2) if u < .5 else tuple(mid + (e - mid) * (u - .5) * 2) for u in np.linspace(0, 1, 10)]
    if t < 4:
        o.append(M(Line(pts, lr, 'day'), col=ln))
    else:
        b = M(Line(pts, lr, 'band'), col=ln)
        b.bands = [(i / 10, (i + .5) / 10, '#7a5e34') for i in range(10)]
        o.append(b)
    o.append(M(Ball(tuple(e), lr * 2.4, 'day'), col=ln))
    o.append(M(Box(tuple(V(math.cos(a1) * R, math.sin(a1) * R, ft * .5)), (V(math.cos(a1), math.sin(a1), 0), V(-math.sin(a1), math.cos(a1), 0), Z), (.35, .14, ft * .52), 'gox', rr=.05), col=hexc(fl) * .7))   # khía nhỏ gài dây
    return Scene(o)


# ------------------------------------------------------------ phao
def float_(t):
    o = []
    if t == 1:      # lông nhím: cọng khoang đen trắng, đầu sơn đỏ, đuôi buộc chỉ + khoen
        b = M(Line([(0, 0, 0), (0, 0, 3), (0, 0, 8), (0, 0, 13), (0, 0, 17), (0, 0, 20)], [.18, .55, .72, .62, .36, .14], 'band'), col='#efe9da')
        b.bands = [(.0, .05, '#2a2420'), (.09, .12, '#4a3c30'), (.2, .27, '#2a2420'), (.31, .33, '#4a3c30'), (.45, .5, '#2a2420'), (.58, .6, '#4a3c30'),
                   (.66, .72, '#2a2420'), (.8, 1.0, '#d8422a'), (.87, .9, '#f6f0e0')]
        o.append(b)
        for k in range(4):
            o.append(M(Torus((0, 0, 1.0 + k * .28), (0, 0, 1), .42, .15, 'day'), col='#c83228'))
        bq = Ell((0, 0, 6.6), (Z, RT, HF), (2.9, 1.15, 1.15), 'bandz'); bq.col = hexc('#d29a5a')   # bấc
        bq.bands = [(4.0, 4.5, '#3a2a1e'), (8.7, 9.2, '#3a2a1e')]
        o.append(M(bq, sp=.3, pw=30))
        for zz in (3.85, 9.35):   # chỉ quấn 2 đầu bấc
            o.append(M(Torus((0, 0, zz), (0, 0, 1), .62, .16, 'day'), col='#2a2420'))
        o.append(met(Torus((0, 0, -.5), tuple(HF), .45, .13, 'met'), hexc('#c4ccd2'), sp=.8, pw=60))
    elif t == 2:    # lông công: cọng lông tuốt sạch, dài mảnh màu ngà; bấc sơn xanh công khoanh vàng; đỉnh sơn khoanh đỏ vàng
        b = M(Line([(0, 0, 0), (0, 0, 2.5), (0, 0, 7), (0, 0, 12), (0, 0, 17), (0, 0, 22)], [.16, .3, .42, .34, .24, .15], 'band'), col='#e8dcbc')
        b.bands = [(.0, .06, '#2a2420'), (.74, .79, '#d8422a'), (.79, .84, '#f2d02a'), (.84, .89, '#d8422a'), (.89, .94, '#f2d02a'), (.94, 1.0, '#d8422a')]
        o.append(b)
        for k in range(4):     # chỉ quấn chân
            o.append(M(Torus((0, 0, 1.4 + k * .26), (0, 0, 1), .34, .13, 'day'), col='#2a6a8a'))
        bq = Ell((0, 0, 7.0), (Z, RT, HF), (3.2, 1.25, 1.25), 'bandz'); bq.col = hexc('#2a9a88')   # bấc sơn xanh lông công
        bq.bands = [(4.0, 4.4, '#d8a838'), (6.0, 6.25, '#1e3a7a'), (7.0, 7.4, '#d8a838'), (7.75, 8.0, '#1e3a7a'), (9.6, 10.0, '#d8a838')]
        o.append(M(bq, sp=.3, pw=30))
        for zz in (3.75, 10.25):
            o.append(M(Torus((0, 0, zz), (0, 0, 1), .5, .15, 'day'), col='#2a2420'))
        o.append(met(Torus((0, 0, -.4), tuple(HF), .45, .13, 'met'), hexc('#c4ccd2'), sp=.8, pw=60))
    elif t == 3:    # đèn đêm: bấc sơn cam trắng, cần nhựa trong, đầu đèn xanh tự sáng
        bq = Ell((0, 0, 6.5), (Z, RT, HF), (4.2, 1.6, 1.6), 'bandz'); bq.col = hexc('#e8782a')
        bq.bands = [(5.0, 5.8, '#f2ede0'), (7.6, 8.4, '#f2ede0'), (2.3, 3.6, '#2a2a2a')]
        o.append(M(bq, sp=.6, pw=50))
        o.append(M(Line([(0, 0, 0), (0, 0, 2.5)], .3, 'met'), col=hexc('#2a2a2a'), sp=.4, pw=30))
        o.append(M(Line([(0, 0, 10.4), (0, 0, 18.5)], .34, 'kinh'), sp=.9, pw=80))
        o.append(M(Tube((0, 0, 17.6), (0, 0, 1), 1.0, [(0, .5), (1, .5)], 'met'), col=hexc('#2a2a2a'), sp=.5, pw=40))
        o.append(M(Ball((0, 0, 19.6), 1.15, 'cam', sq=(1, 1, 1.25)), col='#9cff5a', emit=.85))
        o.append(met(Torus((0, 0, -.4), tuple(HF), .45, .13, 'met'), hexc('#c4ccd2'), sp=.8, pw=60))
    else:           # sơn mài khảm xà cừ, khoanh vàng, đầu vàng
        bq = Ell((0, 0, 7.0), (Z, RT, HF), (4.6, 1.9, 1.9), 'xacu')
        bq.gold = [(2.7, 3.1), (5.3, 5.6), (8.4, 8.7), (11.0, 11.4)]
        o.append(M(bq, sp=.9, pw=70))
        b = M(Line([(0, 0, 11.2), (0, 0, 19.6)], [.4, .3], 'band'), col='#c8342a', sp=.7, pw=50)
        b.bands = [(.25, .32, '#d8a830'), (.5, .57, '#d8a830'), (.75, .82, '#d8a830')]
        o.append(b)
        # đầu đèn như bậc 3 (giữ đèn câu đêm), sang hơn: khâu đồng 2 khoanh, bóng đèn vàng ấm to, nắp đồng nhỏ
        o.append(met(Tube((0, 0, 19.3), (0, 0, 1), 1.1, [(0, .42), (1, .62)], 'met'), hexc('#d8a838'), sp=.5, pw=40))
        o.append(met(Torus((0, 0, 20.35), (0, 0, 1), .62, .14, 'met'), hexc('#e8c45a'), sp=.5, pw=40))
        o.append(M(Ball((0, 0, 21.75), 1.35, 'cam', sq=(1, 1, 1.25)), col='#ffe27a', emit=.85))
        o.append(met(Ball((0, 0, 23.35), .42, 'met', sq=(1, 1, .7)), hexc('#d8a838'), sp=.5, pw=40))
        o.append(met(Line([(0, 0, -.2), (0, 0, 2.6)], .34, 'met'), hexc('#d8a838'), sp=.9, pw=70))
        o.append(met(Torus((0, 0, -.8), tuple(HF), .5, .15, 'met'), hexc('#d8a838'), sp=.9, pw=70))
    return Scene(o)


# ------------------------------------------------------------ rọ / giỏ đựng cá
def cage(t):
    o = []
    if t == 1:      # giỏ tre nhỏ dáng bầu, cổ thắt, hom tre ở miệng, dây đeo
        L = 13.0
        o.append(M(Tube((0, 0, 0), (0, 0, 1), L, [(0, 3.6), (.12, 4.9), (.42, 5.4), (.7, 4.3), (.85, 2.3), (1, 2.7)], 'dan2', shell=.4, open1=True, wv=(40, .05)), col=hexc('#d0b46c')))
        o.append(Tube((0, 0, L - 2.6), (0, 0, 1), 2.7, [(0, .7), (1, 2.5)], 'hom', shell=.25, open0=True, open1=True, wv=(16, .1)))
        for zz, rr in ((.3, 3.75), (L - .2, 2.7), (L * .85, 2.3)):
            o.append(M(Torus((0, 0, zz), (0, 0, 1), rr, .32, 'may')))
        for s_ in (1, -1):
            o.append(M(Torus(tuple(V(0, 0, L * .85) + RT * s_ * 2.35), tuple(HF), .45, .15, 'may')))
        o.append(M(Line(arc(V(0, 0, L * .85) + RT * 2.6, V(0, 0, L * .85) - RT * 2.6, 4.2), .22, 'day'), col='#c8b07a'))
    elif t == 2:    # giỏ tre lớn: bụng rộng, 3 đai mây, hom, quai dây gai
        L = 15.0
        o.append(M(Tube((0, 0, 0), (0, 0, 1), L, [(0, 5.0), (.15, 6.8), (.45, 7.3), (.72, 6.0), (.86, 3.2), (1, 3.6)], 'dan2', shell=.45, open1=True, wv=(52, .05)), col=hexc('#b8864a')))
        o.append(Tube((0, 0, L - 3.0), (0, 0, 1), 3.1, [(0, .9), (1, 3.4)], 'hom', shell=.28, open0=True, open1=True, wv=(18, .1)))
        for zz, rr in ((.3, 5.15), (L * .45, 7.45), (L * .86, 3.25), (L - .2, 3.6)):
            o.append(M(Torus((0, 0, zz), (0, 0, 1), rr, .36, 'may')))
        for s in (1, -1):
            o.append(M(Torus(tuple(V(0, 0, L * .86) + RT * s * 3.3), tuple(HF), .6, .2, 'may')))
        o.append(M(Line(arc(V(0, 0, L * .86) + RT * 3.7, V(0, 0, L * .86) - RT * 3.7, 5.2), .3, 'day'), col='#b89a62'))
    elif t == 3:    # lồng lưới: lưới cước xanh, khoanh vòng nhựa, dây rút miệng
        L = 16.0
        n = M(Tube((0, 0, 0), (0, 0, 1), L, [(0, 5.4), (1, 5.4)], 'luoi', shell=.18, open1=True), col=hexc('#5abc7c'))
        o.append(n)
        for zz in (.15, L * .33, L * .66, L - .1):
            o.append(M(Torus((0, 0, zz), (0, 0, 1), 5.5, .3, 'cam'), col='#2e7a4a', sp=.5, pw=40))
        o.append(M(Tube((0, 0, -.2), (0, 0, 1), .3, [(0, 5.5), (1, 5.5)], 'cam'), col='#2a6a42'))
        o.append(M(Torus(tuple(V(0, 0, L + .2)), (0, 0, 1), 5.5, .16, 'day'), col='#e8e0c8'))
        for s in (1, -1):
            o.append(M(Line([tuple(V(0, 0, L + .2) + RT * s * 5.3 + HF * .6), tuple(V(0, 0, L + 2.4) + RT * s * 4.2 + HF * 2.0)], .16, 'day'), col='#e8e0c8'))
        o.append(M(Ball(tuple(V(0, 0, L + .2) + HF * 5.5), .5, 'cam', sq=(1, 1, 1.3)), col='#d8a838'))   # chốt dây rút
    else:           # rọ mây sơn dầu: thân trống đan, 3 đai đồng, nắp gỗ có núm, khoá đồng, quai mây
        L = 13.5
        o.append(M(Tube((0, 0, 0), (0, 0, 1), L, [(0, 5.6), (.2, 6.6), (.5, 7.0), (.8, 6.6), (1, 5.9)], 'dan2', shell=.5, open1=True, wv=(60, .05)), col=hexc('#b67a46'), sp=.3, pw=40))
        for zz, rr in ((.4, 5.75), (L * .5, 7.12), (L - .3, 6.0)):
            o.append(met(Torus((0, 0, zz), (0, 0, 1), rr, .34, 'met'), hexc('#d8a838'), sp=.85, pw=60))
        o.append(M(Tube((0, 0, L - .1), (0, 0, 1), .9, [(0, 6.25), (.6, 6.25), (1, 5.4)], 'gox'), col='#a8743e', sp=.2, pw=30))   # nắp gỗ có vân
        o.append(M(Torus((0, 0, L + .3), (0, 0, 1), 6.25, .3, 'gox'), col='#7a5030'))   # gờ nắp sẫm
        o.append(M(Tube((0, 0, L + .8), (0, 0, 1), .8, [(0, 2.4), (1, 2.2)], 'gox'), col='#7a4c28', sp=.2, pw=30))
        o.append(met(Ball((0, 0, L + 1.9), .9, 'met', sq=(1, 1, .7)), hexc('#d8a838'), sp=.9, pw=70))      # núm nắp
        o.append(met(Box(tuple(V(0, 0, L - 1.0) + HF * 6.15), (RT, HF, Z), (.8, .18, 1.2), 'met', rr=.12), hexc('#d8a838'), sp=.9, pw=70))   # khoá
        for s in (1, -1):
            o.append(met(Torus(tuple(V(0, 0, L * .82) + RT * s * 6.5), tuple(HF), .7, .22, 'met'), hexc('#d8a838'), sp=.85, pw=60))
        o.append(M(Line(arc(V(0, 0, L * .82) + RT * 6.9, V(0, 0, L * .82) - RT * 6.9, 8.0), .8, 'may'), col='#c89858'))
    return Scene(o)



# ------------------------------------------------------------ cần câu (icon, khớp ảnh cần trong game can/can0-3 + ongcuoc0-3)
def rod(t):
    """cần xéo trong mặt phẳng quay về camera: cán dưới trái, ngọn trên phải; ống cước gắn dưới cán; dây buông từ ngọn"""
    o = []
    A = pl(-9.6, .6); Tp = pl(9.4, 19.6)
    d = nz(Tp - A); L = float(np.linalg.norm(Tp - A))
    dn = nz(RT - Z)                                   # vuông góc cần, phía dưới
    p = lambda s, off=0.0: A + d * s + dn * off
    G1 = {1: 6.0, 2: 6.2, 3: 6.6, 4: 7.2}[t]          # hết cán
    R0 = {1: .8, 2: .86, 3: .86, 4: .92}[t]
    S0 = G1 - .2
    ss = np.linspace(S0, L, 9)
    rad = lambda s: R0 * .8 - (R0 * .8 - .21) * ((s - S0) / (L - S0)) ** .85
    rr = [rad(s) for s in ss]
    LL = L - S0
    tt = lambda s: (s - S0) / LL
    if t == 1:      # cần trúc vàng ngà, đốt nổi
        col, nodes = '#dcc480', 3.3
        bands = [(tt(S0 + nodes * (k + .5)) - .006, tt(S0 + nodes * (k + .5)) + .006, '#a88a4a') for k in range(6)] + [(.975, 1, '#4a3420')]
    elif t == 2:    # tre già ám khói: nâu, đốt sẫm, loang
        col, nodes = '#a86a3a', 2.9
        bands = [(tt(S0 + nodes * (k + .5)) - .012, tt(S0 + nodes * (k + .5)) + .012, '#4e2c16') for k in range(7)] + [(.975, 1, '#2e1e14')]
    elif t == 3:    # câu lục sơn mài đỏ: khoanh đen ở mỗi khoen
        col, nodes = '#c03a2a', None
        bands = [(.975, 1, '#2a1a16')]
    else:           # cần ông Năm gỗ mun, chỉ vàng quấn từng cặp
        col, nodes = '#45322a', None
        bands = [(.975, 1, '#d8a838')]
    guides = {1: [], 2: [], 3: [.18, .36, .54, .72, .88], 4: [.14, .29, .44, .59, .74, .88]}[t]
    for g in guides:
        if t == 3:
            bands.append((g - .012, g + .012, '#2a1a16'))
        else:
            bands += [(g - .022, g - .012, '#e0b040'), (g + .012, g + .022, '#e0b040')]
    b = M(Line([tuple(p(s)) for s in ss], rr, 'band', nodes=nodes), col=col, sp=.25 if t < 3 else .4, pw=40)
    b.bands = bands
    o.append(b)
    # khoen dẫn dây (bậc 3-4)
    gc = hexc('#c4ccd2') if t == 3 else hexc('#d8a838')
    ring = []
    for g in guides:
        s = S0 + g * LL; rg = .34 - .1 * g
        c = p(s, rad(s) + .32 + rg)
        o.append(met(Line([tuple(p(s, rad(s) * .6)), tuple(c - dn * rg)], .07, 'met'), gc, sp=.5, pw=50))
        o.append(met(Torus(tuple(c), tuple(HF), rg, .065, 'met'), gc, sp=.5, pw=50))
        ring.append(c)
    # khâu đồng nối khúc
    for g in {1: [], 2: [], 3: [.27, .63], 4: [.37, .67]}[t]:
        s = S0 + g * LL
        o.append(met(Tube(tuple(p(s - .35)), tuple(d), .7, [(0, rad(s) + .09), (1, rad(s) + .07)], 'met'), hexc('#d8a838'), sp=.5, pw=40))
    # cán
    gcol, gmat, gk = {1: ('#6e4a2a', 'cuon', 3.0), 2: ('#d8b070', 'cuon', 1.7), 3: ('#8a4628', 'met', 0), 4: ('#2e2220', 'cuon', 3.2)}[t]
    gr = M(Tube(tuple(p(.6)), tuple(d), G1 - .6, [(0, R0), (.5, R0 * 1.04), (1, R0 * .9)], gmat), col=hexc(gcol), sp=.15, pw=20)
    if gk:
        gr.k = gk
    else:
        gr.ns = 3
    o.append(gr)
    if t == 3:      # cán da: đường chỉ khâu trắng dọc cán
        st = M(Line([tuple(p(s, -R0 * .96)) for s in np.linspace(1.0, G1 - .4, 2)], .07, 'band'), col='#8a4628')
        st.bands = [(k / 14, (k + .55) / 14, '#f0e6cc') for k in range(14)]
        o.append(st)
    if t == 4:      # chỉ vàng quấn cán
        for s in (1.6, 2.0, G1 - 1.0, G1 - .6):
            o.append(met(Torus(tuple(p(s)), tuple(d), R0 * 1.0, .09, 'met'), GOLD, sp=.5, pw=40))
    # đuôi cán
    if t < 3:
        o.append(M(Ball(tuple(p(.55)), R0 * 1.12, 'gox'), col=hexc('#7a4e2c' if t == 1 else '#5a3820')))
    else:
        o.append(met(Tube(tuple(p(-.2)), tuple(d), .9, [(0, R0 * 1.1), (1, R0 * 1.12)], 'met'), hexc('#d8a838'), sp=.5, pw=40))
        o.append(met(Ball(tuple(p(-.2)), R0 * 1.0, 'met', sq=(1, 1, 1)), hexc('#c89430'), sp=.5, pw=40))
    for s in ((G1,) if t < 3 else (.75, G1)):   # khâu đầu cán
        o.append(met(Torus(tuple(p(s)), tuple(d), R0 * .98, .1, 'met'), hexc('#d8a838') if t > 2 else hexc('#3a2618'), sp=.4, pw=40))
    # ống cước gắn dưới cán (ongcuoc0-3: gỗ, gỗ sẫm, bạc 6 lỗ, đồng 5 lỗ)
    Rr = {1: 2.0, 2: 2.1, 3: 1.9, 4: 2.3}[t]
    sr = G1 - 2.2
    C = p(sr, R0 + Rr * .9) + HF * .9
    rc_ = {1: '#b0743e', 2: '#6e4426', 3: '#c8d0d6', 4: '#d8a838'}[t]
    if t < 3:
        o.append(M(Tube(tuple(C - HF * .4), tuple(HF), .8, [(0, Rr), (1, Rr)], 'gox'), col=hexc(rc_)))
        o.append(M(Torus(tuple(C + HF * .4), tuple(HF), Rr - .15, .15, 'gox'), col=hexc(rc_) * .8))
    else:
        o.append(met(Tube(tuple(C - HF * .4), tuple(HF), .8, [(0, Rr), (1, Rr)], 'met'), hexc(rc_), sp=.45, pw=40))
        o.append(met(Torus(tuple(C + HF * .4), tuple(HF), Rr - .15, .15, 'met'), hexc(rc_) * .85, sp=.45, pw=40))
    nh = {1: 4, 2: 4, 3: 6, 4: 5}[t]; hr = {1: .5, 2: .5, 3: .32, 4: .42}[t]
    for k in range(nh):
        a = k / nh * 2 * math.pi + .4
        hc = C + HF * .41 + (RT * math.cos(a) + Z * math.sin(a)) * Rr * .56
        o.append(M(Tube(tuple(hc - HF * .02), tuple(HF), .04, [(0, hr), (1, hr)], 'met'), col=hexc('#3a2a1e'), sp=0, pw=10))
    o.append(met(Tube(tuple(C + HF * .4), tuple(HF), .3, [(0, Rr * .26), (1, Rr * .22)], 'met'), hexc('#e0b448' if t != 3 else '#e8c060'), sp=.5, pw=40))
    kc = C + HF * .4 + (RT * math.cos(-.5) + Z * math.sin(-.5)) * Rr * .8
    o.append(M(Line([tuple(kc), tuple(kc + HF * .7)], .13, 'met'), col=hexc('#3a2a1e')))
    o.append(M(Ball(tuple(kc + HF * .95), .36, 'gox'), col=hexc('#4a2e1c')))
    o.append(met(Line([tuple(p(sr, R0 * .7)), tuple(C - HF * .3)], .22, 'met'), hexc('#5a4a3e') if t < 3 else hexc('#d8a838'), sp=.3, pw=30))
    # dây cước: từ ống lên dọc cần (qua khoen) tới ngọn, rồi buông xuống
    lc = '#eef2f0'
    pts = [C + HF * .45 + (RT * math.cos(.9) + Z * math.sin(.9)) * Rr * .95]
    if ring:
        pts += ring
    else:
        pts += [p(s, rad(s) + .1) for s in np.linspace(G1 + 1.5, L - .5, 5)]
    pts.append(p(L))
    o.append(M(Line([tuple(q) for q in pts], .045, 'day'), col=lc))
    o.append(M(Line(soft(p(L), pl(7.6, 7.0), n=18, amp=.5, waves=.5, ph=.4), .05, 'day'), col=lc))
    if t > 2:
        o.append(met(Torus(tuple(p(L - .1, .3)), tuple(HF), .2, .06, 'met'), gc, sp=.5, pw=50))
    return Scene(o)

BUILD = {'rod': rod, 'line': spool, 'flo': float_, 'hook': hook, 'cage': cage}

if __name__ == '__main__':
    OUT = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    for key in sys.argv[2:]:
        kind = key.rstrip('1234'); t = int(key[len(kind):])
        sc = BUILD[kind](t)
        outs, anc = B.render(sc, key, water=False)
        outs[0].save(os.path.join(OUT, key + '.webp'), lossless=True, quality=100, method=6)
        print(key, outs[0].size, flush=True)
