#!/usr/bin/env python3
# RƯƠNG MỞ QUÀ 4 BẬC (11-25 Link "giờ tao muốn làm mấy cái rương mở quà 4 bậc cho phác thảo đi"; game chưa có rương).
# Cùng bộ bắn tia + đèn icon của đồ câu (do3d -> ghe3d -> bay3d), nền trong suốt.
#   python3 ruong3d.py OUTDIR [r1 r2 r3 r4]          (env PXU, SSA)  -> <id>.webp
# Bậc:  1 rương tre đan, nan mây buộc, chốt gỗ   | 2 rương gỗ tràm ván ghép, đai sắt, khoá móc sắt
#       3 rương gỗ sơn đỏ, bọc góc + đai đồng, khoá tròn đồng, quai đồng 2 bên, chân gỗ
#       4 rương sơn mài đen khảm xà cừ, viền + đai thếp vàng, khoá vàng hột đỏ, chân vàng
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import do3d as D
B = D.B
from bay3d import V, nz, hexc, sstep, vnoise, Tube, Torus, Line, Ball, Box, M, Scene, F32
from ghe3d import Cut
import numpy as np

Z = V(0, 0, 1)
_a = math.radians(32)
FN = nz(D.HF * math.cos(_a) + D.RT * math.sin(_a))       # mặt trước rương (quay về camera, lệch 32°)
LN = nz(np.cross(FN, Z))                                  # chiều dài rương
if float(LN @ D.RT) < 0: LN = -LN
AX = (LN, FN, Z)
hsh = B.hsh


def W(x, y, z):
    """toạ độ rương -> thế giới: x dọc thân, y ra mặt trước, z lên"""
    return LN * x + FN * y + Z * z


def loc(P):
    return P @ LN, P @ FN, P[:, 2]


# ------------------------------------------------------------ chất liệu
_pd = D.albedo_do


def panels(obj, x, y, z, lid, inset):
    """điểm nằm trong ô (đã thụt vào inset) của các ô trang trí; trả (trong ô, nét chỉ viền ô)"""
    ins = np.zeros(len(x), bool); ln = np.zeros(len(x), bool)
    pa = getattr(obj, 'panels', None)
    if not pa: return ins, ln
    L, Dp, H, Rl, xr, zr, lv = pa
    if lid is not None:
        zl, R = lid; v = R * np.arctan2(z - zl, y)
        endc = np.abs(np.abs(x) - L) < .08
        for (u0, u1) in xr:
            i = (x > u0 + inset) & (x < u1 - inset) & (v > lv[0] + inset) & (v < lv[1] - inset) & ~endc
            o_ = (x > u0 + inset - .14) & (x < u1 - inset + .14) & (v > lv[0] + inset - .14) & (v < lv[1] - inset + .14) & ~endc
            ins |= i; ln |= o_ & ~i
        return ins, ln
    fb = np.abs(np.abs(y) - Dp) < .12; sd = np.abs(np.abs(x) - L) < .12
    for (u0, u1) in xr:
        i = fb & (x > u0 + inset) & (x < u1 - inset) & (z > zr[0] + inset) & (z < zr[1] - inset)
        o_ = fb & (x > u0 + inset - .14) & (x < u1 - inset + .14) & (z > zr[0] + inset - .14) & (z < zr[1] - inset + .14)
        ins |= i; ln |= o_ & ~i
    i = sd & (np.abs(y) < Dp - .9 - inset) & (z > zr[0] + inset) & (z < zr[1] - inset)
    o_ = sd & (np.abs(y) < Dp - .9 - inset + .14) & (z > zr[0] + inset - .14) & (z < zr[1] - inset + .14)
    ins |= i; ln |= o_ & ~i
    return ins, ln


def scratches(P, seed, dens=.75, k=34.0):
    """vết trầy mảnh: các nét ngắn nhiều hướng, chỉ hiện ở chỗ nhiễu cao"""
    out = np.zeros(len(P), F32)
    for i, d in enumerate(((1, .3, .2), (-.4, 1, .5), (.6, -.7, 1), (.9, .9, -.3))):
        d = nz(V(*d)); w = vnoise(P, 1.1, seed + 7 * i)
        line = np.abs(np.sin((P @ d) * k + w * 9)) > .985
        out = np.maximum(out, (line & (vnoise(P, 2.3, seed + 3 * i) > 1 - dens * .5)).astype(F32))
    return out


def edge_dist(obj, x, y, z):
    pa = getattr(obj, 'panels', None) or getattr(obj, 'ext', None)
    if not pa: return None
    L, Dp, H = pa[0], pa[1], pa[2]
    if getattr(obj, 'lid', None) is not None:
        zl, R = obj.lid; v = R * np.arctan2(z - zl, y); rr = np.hypot(y, z - zl)
        endc = np.abs(np.abs(x) - L) < .08
        e = np.minimum(np.abs(L - np.abs(x)), np.minimum(np.abs(v), np.abs(math.pi * R - v)))
        return np.where(endc, np.maximum(R - rr, 0) + 9 * (R - rr > .6), e)
    d = np.sort(np.stack([np.abs(L - np.abs(x)), np.abs(Dp - np.abs(y)), np.abs(z), np.abs(H - z)], 1), 1)
    return d[:, 1]


def albedo_r(obj, P):
    if obj.mat != 'ruong': return _pd(obj, P)
    c = albedo_r0(obj, P)
    x, y, z = loc(P); k = obj.rk; n = len(P)
    if k == 'kl':                             # kim loại: mặt búa gõ lấm tấm, trầy sáng, gỉ/xỉn ở chỗ khuất
        dimp = vnoise(P, 5.5, 91); fine = vnoise(P, 13.0, 93)
        c = c * (.74 + .34 * dimp + .14 * fine)[:, None]
        sc = scratches(P, 95, .7, 40.0)
        c = c * (1 - .55 * sc)[:, None] + np.minimum(obj.col * 1.45, 1)[None] * (.55 * sc)[:, None]
        pat = sstep(.6, .85, vnoise(P, 2.4, 92)) * .45 * (.5 + .5 * vnoise(P, 7, 94))
        pc = getattr(obj, 'pat', None)
        if pc is not None: c = c * (1 - pat)[:, None] + pc[None] * pat[:, None]
        if obj.col[0] > .8 and obj.col[1] > .55:   # vàng / đồng vàng: chấm đột (punch) li ti + vệt đánh bóng sáng
            dots = sstep(.72, .8, vnoise(P, 22.0, 108))
            c = c * (1 - .22 * dots)[:, None]
            eng = (np.abs(np.sin((x + y) * 2.6 + z * 1.3)) > .955) | (np.abs(np.sin((x - y) * 2.6 - z * 1.3)) > .955)   # chạm chéo trám
            c = np.where(eng[:, None], c * .66, c)
            amb = vnoise(P, .8, 110)
            c = c * (1 - .18 * amb)[:, None] + hexc('#b8741c')[None] * (.18 * amb)[:, None]
            pol = sstep(.55, .9, vnoise(P * V(1, 1, 3), 1.2, 109))
            c = c * (1 - .18 * pol)[:, None] + np.minimum(obj.col * 1.25, 1)[None] * (.18 * pol)[:, None]
        if getattr(obj, 'crack', False):      # vàng thếp: rạn chân chim mảnh
            cr = (np.abs(vnoise(P, 14.0, 96) - .5) < .025) & (vnoise(P, 2.0, 107) > .5)
            c = np.where(cr[:, None], c * .62, c)
        return c
    if k in ('son', 'xacu', 'van', 'hoivan'):
        if k in ('son', 'xacu'):              # sơn: thớ gỗ hằn dưới sơn, rạn nhỏ, bụi đọng
            g = .5 + .5 * np.sin(x * .9 + vnoise(P * V(1, 1, 4), .8, 97) * 7 + z * .3)
            c = c * (.92 + .12 * g)[:, None]
            cr = (np.abs(vnoise(P, 16.0, 98) - .5) < .02) & (vnoise(P, 2.5, 106) > .55)
            c = np.where(cr[:, None], c * .78, c)
        sc = scratches(P, 99, .45, 30.0)
        c = c * (1 - .22 * sc)[:, None]
        ed = edge_dist(obj, x, y, z)
        if ed is not None:                    # mòn cạnh: sơn sờn lộ gỗ / gỗ bóng sáng ở cạnh
            wn = vnoise(P, 2.2, 100)
            wear = sstep(.42, .05, ed + .2 * (wn - .5)) * sstep(.45, .7, wn)
            wc = getattr(obj, 'wearc', None)
            if wc is not None: c = c * (1 - .6 * wear)[:, None] + wc[None] * (.6 * wear)[:, None]
        sp = sstep(.72, .86, vnoise(P, 6.5, 101)) * .18                                   # đốm xỉn nhỏ
        return c * (1 - sp)[:, None]
    if k == 'dan':                            # nan tre: sợi xơ dọc nan, đầu nan sờn
        fib = vnoise(P * V(1, 1, 1), 9.0, 102)
        c = c * (.9 + .16 * fib)[:, None]
        burn = sstep(.68, .85, vnoise(P, 1.6, 103)) * .2                                   # nan ám khói / ngả màu
        return c * (1 - burn)[:, None]
    if k == 'tre':                            # cây tre tròn: mắt tre mỗi đốt, sọc xơ dọc, đầu đốt ngả vàng
        _, sl = obj.seg(P); seg = getattr(obj, 'node', 3.2)
        f = (sl / seg) % 1.0; i = np.floor(sl / seg)
        node = np.exp(-((f - .02) / .03) ** 2) + np.exp(-((f - .98) / .03) ** 2)
        fib = vnoise(P * V(3, 3, 3), 4.0, 104)
        c = c * (.88 + .14 * fib + .08 * (hsh(i * 3.7 + 1) - .5))[:, None]
        yel = sstep(.6, .95, np.abs(f - .5) * 2) * .25
        c = c * (1 - yel)[:, None] + hexc('#c8b050')[None] * yel[:, None]
        return c * (1 - .38 * np.clip(node, 0, 1))[:, None] + hexc('#e8e0a0')[None] * (.12 * np.exp(-((f - .06) / .03) ** 2))[:, None]
    if k == 'may2':                           # dây mây quấn: vòng quấn chéo, khe tối
        _, sl = obj.seg(P)
        w = (sl * 2.6 + vnoise(P, 2, 105) * .6) % 1.0
        return c * (.72 + .36 * np.sin(np.pi * w) - .2 * (w < .12))[:, None]
    if getattr(obj, 'linec', None) is not None and getattr(obj, 'panels', None) and obj.rk != 'hoivan':
        x, y, z = loc(P); _, ln = panels(obj, x, y, z, getattr(obj, 'lid', None), .55)
        c = np.where(ln[:, None], obj.linec[None] * (.92 + .1 * vnoise(P, 3, 85))[:, None], c)    # chỉ viền ô (vẽ vàng / khắc sẫm)
    return c


def albedo_r0(obj, P):
    x, y, z = loc(P); k = obj.rk; col = obj.col; n = len(P)
    lid = getattr(obj, 'lid', None)
    if lid is not None:                       # nắp vòm: u dọc thân, v theo cung
        zl, R = lid; u = x; v = R * np.arctan2(z - zl, y)
        endc = np.abs(np.abs(x) - obj.hl) < .08                      # 2 đầu nắp: mặt phẳng, như hông thân
        u = np.where(endc, y, u); v = np.where(endc, z, v)
    else:
        u = x + y; v = z
    if k == 'hoivan':                         # gờ miệng / đế có hồi văn chạy quanh (rãnh chữ khoá)
        z0, z1 = obj.zr; b = np.clip((z - z0) / (z1 - z0), 0, 1); uu = (x + y) / 1.5; a = uu % 1.0
        key = ((b < .2) & (a < .82)) | ((a > .64) & (a < .82) & (b < .8)) | ((b > .62) & (b < .8) & (a > .28) & (a < .82)) | \
              ((a > .28) & (a < .46) & (b > .38) & (b < .8)) | ((b > .38) & (b < .54) & (a > .28) & (a < .64))
        edge = (b < .07) | (b > .93)
        c = col[None] * (.93 + .08 * vnoise(P, 2, 84))[:, None]
        lc = obj.linec[None] * np.ones((n, 1), F32)
        return np.where((key | edge)[:, None], lc, c)
    if k == 'dan':                            # tre đan lóng mốt, mỗi nan một tông
        c_ = .95; iu = np.floor(u / c_); iv = np.floor(v / c_); fu = u / c_ - iu; fv = v / c_ - iv
        over = ((np.floor(iu / 2) + iv) % 2) == 0
        tone = np.where(over, hsh(iv * 7.1 + 3), hsh(iu * 3.3 + 1)) - .5
        sh = np.where(over, .8 + .24 * np.sin(np.pi * fv), .74 + .22 * np.sin(np.pi * fu))
        gap = np.where(over, np.exp(-(fv / .08) ** 2) + np.exp(-((1 - fv) / .08) ** 2), np.exp(-(fu / .1) ** 2) + np.exp(-((1 - fu) / .1) ** 2))
        c = col[None] * (sh * (1 + .2 * tone))[:, None]
        return c * (1 - .42 * np.clip(gap, 0, 1))[:, None]
    if k == 'van':                            # ván gỗ ghép ngang: thớ dọc ván, khe ván sẫm, mỗi ván một tông
        pw = 2.6; iv = np.floor(v / pw); fv = v / pw - iv
        g = vnoise(np.stack([u * .25, v * 2.2 + iv * 5, iv], 1).astype(F32), 1.0, 81)
        g2 = .5 + .5 * np.sin(u * 1.1 + g * 6 + iv * 2)
        gl = np.abs(np.sin(v * 9.0 + g * 2.2 + iv * 3.1 + .9 * np.sin(u * .45 + iv)))          # vân gỗ chạy dọc ván, uốn quanh mắt
        dark = sstep(.93, .995, gl) * .2 + sstep(.6, .9, vnoise(np.stack([u * .6, v * 6 + iv * 9, iv], 1).astype(F32), 1.0, 86)) * .12
        c = col[None] * ((.84 + .22 * (hsh(iv * 5.3 + 2) - .5)) * (.88 + .16 * g2 + .1 * g) * (1 - dark))[:, None]
        gap = np.exp(-(fv / .05) ** 2) + np.exp(-((1 - fv) / .05) ** 2)
        knot = np.exp(-(((u - 3 - iv * 4.7) % 11 - 5.5) ** 2 + ((fv - .5) * pw) ** 2) / .35)
        c = c * (1 - .5 * np.clip(gap, 0, 1))[:, None] * (1 - .35 * knot)[:, None]
        return c
    if k == 'son':                            # sơn đỏ trên gỗ: mịn, hơi thấy thớ, khe ván rất mờ
        pw = 2.6; fv = (v / pw) % 1.0
        g = vnoise(np.stack([u * .3, v * 2, u * 0], 1).astype(F32), 1.0, 82)
        c = col[None] * (.94 + .08 * g)[:, None]
        return c * (1 - .12 * (np.exp(-(fv / .04) ** 2) + np.exp(-((1 - fv) / .04) ** 2)))[:, None]
    if k == 'xacu':                           # sơn mài đen, khảm xà cừ: hoa 4 cánh so le, nhị vàng, trong khung
        c = np.broadcast_to(col, (n, 3)).copy() * (.93 + .1 * vnoise(P, 2, 83))[:, None]
        cu, cv = 2.05, 2.0
        uu = u / cu; vv = v / cv; row = np.floor(vv); uu = uu + .5 * (row % 2)
        du = ((uu % 1.0) - .5) * cu; dv = ((vv % 1.0) - .5) * cv
        pa = np.arctan2(dv, du); pr = np.hypot(du, dv)
        petal = pr < .56 * (.5 + .5 * np.abs(np.cos(pa * 2)))
        dot = pr < .2
        lf = (np.abs(np.abs(du) - np.abs(dv)) < .08) & (pr > .66) & (pr < .9)       # 4 lá nhỏ giữa các hoa
        w = .5 + .5 * np.sin(u * .9 + v * 1.3)
        pearl = hexc('#f4f2ea')[None] * (1 - .45 * w)[:, None] + hexc('#f0c8dc')[None] * (.3 * w)[:, None] + hexc('#c4ecdc')[None] * (.18 * w)[:, None]
        inl, _ = panels(obj, x, y, z, lid, .8)
        c = np.where((petal & inl)[:, None], pearl, c)
        c = np.where((lf & inl)[:, None], pearl * .85, c)
        c = np.where((dot & inl)[:, None], D.GOLD[None], c)
        return c
    return col[None] * np.ones((n, 1), F32)


D.albedo_do = albedo_r


def R(o, k, col, lid=None, **kw):
    o = M(o, col=col, **kw); o.mat = 'ruong'; o.rk = k
    if lid is not None: o.lid = lid
    return o


def cut(o, P0, n):
    c = Cut(o, P0, n)
    for k_ in ('rk', 'lid', 'inlay', 'ns', 'hl', 'panels', 'linec', 'zr', 'wearc', 'ext', 'pat', 'crack'):
        if hasattr(o, k_): setattr(c, k_, getattr(o, k_))
    return c


PAT = {}                                   # màu xỉn theo màu kim loại (đặt theo bậc)
CRACK = set()


def met(o, col, ns=1.5):
    o = M(o, col=col, sp=.4, pw=50); o.mat = 'ruong'; o.rk = 'kl'; o.ns = ns
    key = tuple(np.round(o.col, 3)); o.pat = PAT.get(key); o.crack = key in CRACK
    return o


# ------------------------------------------------------------ phần dựng chung
def body(o, L, Dp, H, mat, col, lidmat=None, lidcol=None, Rl=None, deco=None, wearc=None, **kw):
    """thân hộp (nửa dài L, nửa sâu Dp, cao H) + nắp vòm nửa trụ bán kính Rl (mặc định = Dp) dọc thân"""
    Rl = Rl or Dp
    bx = R(Box(tuple(W(0, 0, H / 2)), AX, (L, Dp, H / 2), 'ruong', rr=.35), mat, hexc(col), **kw)
    if deco: bx.panels, bx.linec = deco
    bx.ext = (L, Dp, H)
    if wearc: bx.wearc = hexc(wearc)
    o.append(bx)
    lid = Tube(tuple(W(-L, 0, H)), tuple(LN), 2 * L, [(0, Rl), (1, Rl)], 'ruong')
    lid = R(lid, lidmat or mat, hexc(lidcol or col), lid=(H, Rl), **kw); lid.hl = L
    if deco: lid.panels, lid.linec = deco
    lid.ext = (L, Dp, H)
    if wearc: lid.wearc = hexc(wearc)
    o.append(cut(lid, tuple(W(0, 0, H + .02)), tuple(-Z)))
    return Rl


def strap_lid(o, x, H, Rl, r, col, mat='met', n=24, lift=.2):
    pts = [tuple(W(x, (Rl + lift) * math.cos(t), H + (Rl + lift) * math.sin(t))) for t in np.linspace(0, math.pi, n)]
    s = Line(pts, r, mat)
    o.append(met(s, hexc(col)) if mat == 'met' else M(s, col=col))


def strap_body(o, x, Dp, H, w, col, t=.22):
    """đai dẹt ôm mặt trước + 2 hông? (chỉ mặt trước và mặt sau, quấn qua đáy)"""
    for sy in (1, -1):
        o.append(met(Box(tuple(W(x, sy * (Dp + t * .5), H / 2)), AX, (w, t, H / 2 + .05), 'met', rr=.08), hexc(col)))


def corner_caps(o, L, Dp, H, col, s=1.6, t=.25):
    """bọc góc kim loại: 4 góc đứng của thân, mỗi góc 2 miếng chữ L"""
    for sx in (1, -1):
        for sy in (1, -1):
            for zc in (s * .5 + .1, H - s * .5 - .05):
                o.append(met(Box(tuple(W(sx * (L - s * .45), sy * (Dp + t * .5), zc)), AX, (s * .5, t, s * .5), 'met', rr=.1), hexc(col)))
                o.append(met(Box(tuple(W(sx * (L + t * .5), sy * (Dp - s * .45), zc)), AX, (t, s * .5, s * .5), 'met', rr=.1), hexc(col)))


def feet(o, L, Dp, col, h=1.0, metal=False):
    for sx in (1, -1):
        for sy in (1, -1):
            b = Ball(tuple(W(sx * (L - 1.0), sy * (Dp - 1.0), -h * .45)), 1.0, 'met' if metal else 'gox', sq=(1, 1, .7))
            o.append(met(b, hexc(col)) if metal else M(b, col=col))


def lid_trim(o, L, H, Rl, col, r=.32, mat='met'):
    """viền 2 đầu nắp (cung) + mép nắp trước/sau"""
    for sx in (1, -1):
        strap_lid(o, sx * (L - .05), H, Rl, r, col, mat, lift=.05)
    for sy in (1, -1):
        e = Line([tuple(W(-L, sy * (Rl + .1), H + .1)), tuple(W(L, sy * (Rl + .1), H + .1))], r, mat)
        o.append(met(e, hexc(col)) if mat == 'met' else M(e, col=col))


def handle(o, L, H, col, r=1.3, rr=.26):
    """quai hông: đĩa hoa thị 8 múi + 2 chốt, quai chữ U thả xuống"""
    for sx in (1, -1):
        c = W(sx * (L + .3), 0, H * .62)
        o.append(met(Tube(tuple(c - LN * sx * .1), tuple(LN * sx), .3, [(0, 1.25 * r / 1.3), (1, 1.1 * r / 1.3)], 'met'), hexc(col)))
        for k in range(8):
            a = 2 * math.pi * k / 8
            o.append(met(Ball(tuple(c + LN * sx * .25 + (FN * math.cos(a) + Z * math.sin(a)) * .95 * r / 1.3), .28 * r / 1.3, 'met'), hexc(col)))
        for sy in (1, -1):
            o.append(met(Ball(tuple(c + LN * sx * .4 + FN * sy * .75 * r / 1.3), .3, 'met'), hexc(col)))
        pts = [tuple(c + LN * sx * .55 + FN * (.75 * r / 1.3) * math.cos(t) - Z * (1.5 * r / 1.3) * math.sin(t)) for t in np.linspace(0, math.pi, 16)]
        o.append(met(Line(pts, rr, 'met'), hexc(col)))


# ------------------------------------------------------------ gờ, rãnh, logo hoa sen (v3 11-25 Link "logo hoa sen đâu / màu trơn trụi / gờ rãnh đâu")
D.CLIFT, D.CSAT = 1.0, 1.3          # Link "màu tái nhạt": màu sơn đậm + tươi hơn (không đụng đèn)


def layout(L, Dp, H, xs):
    """các ô trang trí: (L, Dp, H, Rl, khoảng x các ô, khoảng z ô thân, khoảng cung ô nắp)"""
    xr = [(-xs + .75, xs - .75), (xs + .75, L - .7), (-L + .7, -xs - .75)]
    return (L, Dp, H, Dp, xr, (1.25, H - .85), (1.0, math.pi * Dp - 1.0))


def ledges(o, L, Dp, H, col, linec=None, hv=True, base=True):
    """đế 2 tầng + gờ miệng thân (có hồi văn), mỗi tầng lồi ra tạo rãnh bóng"""
    def strip(C, h, zr, cc):
        b = R(Box(tuple(C), AX, h, 'ruong', rr=.12), 'hoivan' if (hv and linec is not None) else 'son', hexc(cc), sp=.15, pw=30)
        b.zr = zr; b.linec = hexc(linec) if linec else hexc(cc)
        o.append(b)
    if base:
        strip(W(0, 0, .2), (L + .42, Dp + .42, .22), (0, .42), col)
        strip(W(0, 0, .78), (L + .25, Dp + .25, .38), (.4, 1.16), col)
    strip(W(0, 0, H - .36), (L + .22, Dp + .22, .36), (H - .72, H), col)


def frames(o, lay, col, r=.17, mat='met', lidf=True):
    """khung nổi (gờ) quanh từng ô: thân trước + sau + 2 hông, và ô trên nắp"""
    L, Dp, H, Rl, xr, zr, lv = lay
    def ln(pts):
        e = Line([tuple(p) for p in pts], r, mat)
        o.append(met(e, hexc(col)) if mat == 'met' else M(e, col=col))
    for sy in (1, -1):
        for (u0, u1) in xr:
            y = sy * (Dp + .1)
            ln([W(u0, y, zr[0]), W(u1, y, zr[0]), W(u1, y, zr[1]), W(u0, y, zr[1]), W(u0, y, zr[0])])
    for sx in (1, -1):
        x = sx * (L + .1); y0 = Dp - .9
        ln([W(x, -y0, zr[0]), W(x, y0, zr[0]), W(x, y0, zr[1]), W(x, -y0, zr[1]), W(x, -y0, zr[0])])
    if lidf:
        for (u0, u1) in xr:
            for vv in lv:
                th = vv / Rl; p = lambda xx: W(xx, (Rl + .1) * math.cos(th), H + (Rl + .1) * math.sin(th))
                ln([p(u0), p(u1)])
            for uu in (u0, u1):
                ln([W(uu, (Rl + .1) * math.cos(t), H + (Rl + .1) * math.sin(t)) for t in np.linspace(lv[0] / Rl, lv[1] / Rl, 14)])


def lotus(o, c, s, col, mat='met', vein=None, gem=None, plate=None, plate_r=None, ring=None):
    """LOGO HOA SEN nổi: 7 cánh nhọn xoè (giữa cao nhất), 2 lá đế cong, cuống; tuỳ chọn đĩa nền, hột giữa, vòng ngọc"""
    c = V(*c)
    def part(o_):
        return met(o_, hexc(col)) if mat == 'met' else M(o_, col=col, sp=.1, pw=20)
    if plate:
        pr = plate_r or s * 1.55
        if mat == 'met':
            dk = R(Tube(tuple(c - FN * .15), tuple(FN), .32, [(0, pr), (1, pr * .96)], 'ruong'), 'son', hexc(plate), sp=.15, pw=30)
            dk.ext = None
            o.append(dk)
            for rr_, ww in ((pr * .99, s * .1), (pr * .82, s * .05)):
                o.append(met(Torus(tuple(c + FN * .17), tuple(FN), rr_, ww, 'met'), hexc(col)))
        else:
            o.append(M(Tube(tuple(c - FN * .15), tuple(FN), .35, [(0, pr), (1, pr * .94)], 'gox'), col=plate))
            o.append(M(Torus(tuple(c + FN * .2), tuple(FN), pr * .97, s * .09, 'gox'), col=col))
    base = c - Z * s * .55 + FN * .25
    for ang, ln_, w, dz in ((0, 1.05, .30, .0), (24, .95, .27, .02), (-24, .95, .27, .02), (50, .8, .24, .05), (-50, .8, .24, .05), (78, .6, .2, .08), (-78, .6, .2, .08)):
        a = math.radians(ang); d = nz(Z * math.cos(a) + LN * math.sin(a)); pp = nz(np.cross(FN, d))
        cc = base + d * s * ln_ * .55 + FN * (dz * s - .02 * abs(ang) / 78)
        o.append(part(Ell(tuple(cc), (tuple(d), tuple(pp), tuple(FN)), (s * ln_ * .58, s * w, s * .14), 'met' if mat == 'met' else 'gox')))
        if vein:                                          # gân cánh (rãnh khắc)
            o.append(M(Line([tuple(base + d * s * .15 + FN * s * .13), tuple(base + d * s * ln_ * .85 + FN * s * .13)], s * .035, 'met'), col=vein))
    for sx in (1, -1):                                    # 2 lá đế cong ngửa
        d = nz(LN * sx + Z * .18); pp = nz(np.cross(FN, d))
        o.append(part(Ell(tuple(base + LN * sx * s * .62 - Z * s * .12), (tuple(d), tuple(pp), tuple(FN)), (s * .62, s * .17, s * .12), 'met' if mat == 'met' else 'gox', bend=-.35 / s)))
    o.append(part(Ell(tuple(base - Z * s * .38), (tuple(Z), tuple(LN), tuple(FN)), (s * .3, s * .09, s * .1), 'met' if mat == 'met' else 'gox')))
    if gem:
        o.append(M(Ball(tuple(base + Z * s * .42 + FN * s * .22), s * .2, 'cam'), col=gem, sp=.35, pw=50))
    if ring:
        pr = plate_r or s * 1.55
        for k in range(14):
            a = 2 * math.pi * k / 14
            o.append(M(Ball(tuple(c + FN * .25 + (LN * math.cos(a) + Z * math.sin(a)) * pr * 1.1), s * .11, 'cam'), col=ring, sp=.3, pw=40))


def keyhole(o, c, s=1.0):
    o.append(M(Ball(tuple(c + Z * .18 * s), .2 * s, 'met', sq=(1, 1, 1)), col='#1c120a'))
    o.append(M(Box(tuple(c - Z * .15 * s), AX, (.09 * s, .06, .28 * s), 'met', rr=.03), col='#1c120a'))


def lid_ribs(o, L, H, Rl, col, angs=(.62, 2.52), r=.2, mat='met'):
    for a in angs:
        p = lambda xx: W(xx, (Rl + .08) * math.cos(a), H + (Rl + .08) * math.sin(a))
        e = Line([tuple(p(-L + .2)), tuple(p(L - .2))], r, mat)
        o.append(met(e, hexc(col)) if mat == 'met' else M(e, col=col))


def TRE(o_, col, node=3.2):
    o_ = M(o_, col=col, sp=.12, pw=25); o_.mat = 'ruong'; o_.rk = 'tre'; o_.node = node
    return o_


def MAY(o_, col='#8a4a24'):
    o_ = M(o_, col=col, sp=.05, pw=10); o_.mat = 'ruong'; o_.rk = 'may2'
    return o_


# ------------------------------------------------------------ 4 bậc
from ghe3d import Ell


def ruong(t):
    o = []
    if t == 1:      # tre đan vàng, nẹp tre xanh, gờ tre, buộc mây, LOGO SEN GỖ khắc trên bảng gỗ tròn buộc mây
        L, Dp, H = 8.0, 5.4, 7.2
        Rl = body(o, L, Dp, H, 'dan', '#e6b850', lidcol='#e0b04a', sp=.05, pw=10)
        for sy in (1, -1):
            for zz in (H - .35, .35, H * .5):
                o.append(TRE(Line([tuple(W(-L - .1, sy * (Dp + .15), zz)), tuple(W(L + .1, sy * (Dp + .15), zz))], .34 if zz != H * .5 else .26, 'gox'), '#8c9c4a' if zz != H * .5 else '#c09a50'))
        for sx in (1, -1):
            for zz in (H - .35, .35):
                o.append(TRE(Line([tuple(W(sx * (L + .15), -Dp - .1, zz)), tuple(W(sx * (L + .15), Dp + .1, zz))], .34, 'gox'), '#8c9c4a'))
            for sy in (1, -1):         # cột tre 4 góc
                o.append(TRE(Line([tuple(W(sx * (L + .05), sy * (Dp + .05), .1)), tuple(W(sx * (L + .05), sy * (Dp + .05), H - .1))], .38, 'gox'), '#7e8c40'))
        for x in (-L * .62, L * .62):
            pts = [tuple(W(x, (Rl + .22) * math.cos(a), H + (Rl + .22) * math.sin(a))) for a in np.linspace(0, math.pi, 22)]
            o.append(MAY(Line(pts, .3, 'may'), '#8a4a24'))
            for sy in (1, -1):
                o.append(MAY(Line([tuple(W(x, sy * (Dp + .25), H - .1)), tuple(W(x, sy * (Dp + .25), .2))], .3, 'may'), '#8a4a24'))
        for sx in (1, -1):
            o.append(TRE(Line([tuple(W(sx * (L - .05), (Rl + .08) * math.cos(a), H + (Rl + .08) * math.sin(a))) for a in np.linspace(0, math.pi, 22)], .32, 'gox'), '#8c9c4a'))
        for sy in (1, -1):
            o.append(TRE(Line([tuple(W(-L, sy * (Rl + .1), H + .1)), tuple(W(L, sy * (Rl + .1), H + .1))], .32, 'gox'), '#8c9c4a'))
        for a in (.62, 2.52):
            o.append(TRE(Line([tuple(W(xx, (Rl + .08) * math.cos(a), H + (Rl + .08) * math.sin(a))) for xx in (-L + .2, L - .2)], .26, 'gox'), '#c09a50', node=4.0))
        lotus(o, W(0, Dp + .45, H - 1.5), 1.8, '#a8682e', mat='gox', vein='#6a3c18', plate='#d8a868', plate_r=2.6)
        for sz in (1, -1):              # dây mây buộc bảng gỗ
            o.append(MAY(Line([tuple(W(0, Dp + .6, H - 1.4 + sz * 2.3)), tuple(W(0, Dp + .4, H - 1.4 + sz * 3.0))], .22, 'may'), '#8a4a24'))
        o.append(M(Line([tuple(W(-.9, Dp + .7, H + .1)), tuple(W(.9, Dp + .7, H + .1))], .3, 'gox'), col='#8a6234'))   # chốt gỗ
        for sx in (1, -1):
            pts = [tuple(W(sx * (L + .4 + 1.0 * math.sin(a)), 1.6 * math.cos(a), H * .66 + .4 * math.sin(a))) for a in np.linspace(0, math.pi, 12)]
            o.append(MAY(Line(pts, .3, 'may'), '#8a4a24'))
    elif t == 2:    # gỗ tràm nâu cam, đế + gờ miệng hồi văn khắc, ô khung nổi, đai sắt, KHOÁ KHIÊN ĐỒNG có SEN nổi
        L, Dp, H = 8.6, 5.6, 7.6
        xs = L * .58; lay = layout(L, Dp, H, xs)
        PAT[tuple(np.round(hexc('#565a62'), 3))] = hexc('#7a4a2a'); PAT[tuple(np.round(hexc('#e0a23a'), 3))] = hexc('#6a7a4a')
        Rl = body(o, L, Dp, H, 'van', '#c8783a', sp=.08, pw=12, deco=(lay, hexc('#6a3a1a')), wearc='#e0a868')
        IRON, BR = '#565a62', '#e0a23a'
        ledges(o, L, Dp, H, '#a8602c', linec='#5a2e12')
        frames(o, lay, '#a05a28', mat='gox')
        for x in (-xs, xs):
            strap_body(o, x, Dp, H, .55, IRON)
            strap_lid(o, x, H, Rl, .34, IRON)
            for zz in (1.4, H * .5, H - 1.1):
                o.append(met(Ball(tuple(W(x, Dp + .38, zz)), .3, 'met'), hexc(BR)))
        corner_caps(o, L, Dp, H, IRON)
        lid_trim(o, L, H, Rl, '#4a4e56', r=.3)
        c = W(0, Dp + .3, H - 1.2)
        o.append(met(Box(tuple(c), AX, (2.5, .24, 2.6), 'met', rr=.9), hexc(BR)))
        o.append(met(Torus(tuple(c + FN * .26), tuple(FN), 2.15, .16, 'met'), hexc('#b07a28')))
        lotus(o, c + FN * .2 + Z * .45, 2.15, '#c88a2a', vein='#7a4a14')
        o.append(met(Box(tuple(W(0, Rl + .3, H + .5)), AX, (.6, .24, 1.0), 'met', rr=.12), hexc(BR)))
        o.append(met(Torus(tuple(c + FN * .95 - Z * 2.6), tuple(FN), .7, .22, 'met'), hexc('#4a4e56')))
        o.append(met(Box(tuple(c + FN * .95 - Z * 3.3), AX, (1.05, .45, .9), 'met', rr=.3), hexc('#3e4248')))
        keyhole(o, c + FN * 1.42 - Z * 3.3, .9)
        handle(o, L, H, IRON, r=1.1)
    elif t == 3:    # sơn xanh ngọc, ô khung nổi vàng + chỉ vàng vẽ trong ô, gờ hồi văn vàng, đai vàng đồng, LOGO SEN VÀNG hột đỏ trên đĩa
        L, Dp, H = 9.0, 5.8, 7.8
        xs = L * .6; lay = layout(L, Dp, H, xs)
        feet(o, L, Dp, '#d8a038', metal=True)
        BR = '#e2a83a'
        PAT[tuple(np.round(hexc(BR), 3))] = hexc('#8a7a3a'); PAT[tuple(np.round(hexc('#c89030'), 3))] = hexc('#8a7a3a'); PAT[tuple(np.round(hexc('#d8a038'), 3))] = hexc('#8a7a3a')
        Rl = body(o, L, Dp, H, 'son', '#14947f', sp=.18, pw=30, deco=(lay, hexc(BR)), wearc='#7cc8b8')
        ledges(o, L, Dp, H, '#0e7466', linec=BR)
        frames(o, lay, '#c89030')
        for x in (-xs, xs):
            strap_body(o, x, Dp, H, .62, BR)
            strap_lid(o, x, H, Rl, .38, BR)
        corner_caps(o, L, Dp, H, BR, s=2.0)
        lid_trim(o, L, H, Rl, BR, r=.36)
        c = W(0, Dp + .25, H - 1.3)
        lotus(o, c, 2.25, BR, vein='#9a6a1c', gem='#e0302a', plate='#8a1c16', plate_r=2.9)
        keyhole(o, c + FN * .5 - Z * 1.85, .8)
        o.append(met(Box(tuple(W(0, Rl + .3, H + .45)), AX, (.6, .22, .9), 'met', rr=.12), hexc(BR)))
        handle(o, L, H, BR, r=1.3)
    else:           # sơn son ĐỎ thếp vàng: ô khung vàng khảm xà cừ, gờ hồi văn vàng, LOGO SEN VÀNG TO hột ruby trên đĩa đỏ + vòng ngọc, núm búp sen
        L, Dp, H = 9.4, 6.0, 8.0
        xs = L * .5; lay = layout(L, Dp, H, xs)
        GD = '#f2b636'
        feet(o, L, Dp, GD, metal=True)
        CRACK.add(tuple(np.round(hexc(GD), 3))); PAT[tuple(np.round(hexc(GD), 3))] = hexc('#c08a28')
        Rl = body(o, L, Dp, H, 'xacu', '#c41e26', sp=.15, pw=40, deco=(lay, hexc(GD)), wearc='#7a2416')
        ledges(o, L, Dp, H, '#9a141c', linec=GD)
        frames(o, lay, GD, r=.2)
        for x in (-xs, xs):
            strap_body(o, x, Dp, H, .7, GD)
            strap_lid(o, x, H, Rl, .44, GD)
        corner_caps(o, L, Dp, H, GD, s=2.3)
        lid_trim(o, L, H, Rl, GD, r=.4)
        for sx in (1, -1):
            for zc in (1.45, H - 1.25):
                o.append(M(Ball(tuple(W(sx * (L - 1.0), Dp + .45, zc)), .42, 'cam'), col='#1aa878', sp=.35, pw=50))
        c = W(0, Dp + .28, H - 1.45)
        lotus(o, c, 2.6, GD, vein='#b07a18', gem='#d81c3a', plate='#10302a', plate_r=3.3, ring='#f4f0e6')
        keyhole(o, c + FN * .55 - Z * 2.15, .9)
        o.append(met(Box(tuple(W(0, Rl + .3, H + .5)), AX, (.8, .24, 1.1), 'met', rr=.15), hexc(GD)))
        top = W(0, 0, H + Rl + .25)
        o.append(met(Tube(tuple(top - Z * .2), tuple(Z), .5, [(0, 1.3), (1, 1.0)], 'met'), hexc(GD)))
        o.append(met(Ell(tuple(top + Z * 1.2), (tuple(LN), tuple(FN), tuple(Z)), (.55, .55, 1.25), 'met'), hexc(GD)))
        for k in range(6):                                       # cánh búp sen ôm nụ
            a = 2 * math.pi * k / 6; d = LN * math.cos(a) + FN * math.sin(a)
            ax_ = nz(Z + d * .35); pp = nz(np.cross(ax_, d))
            o.append(met(Ell(tuple(top + Z * .95 + d * .5), (tuple(ax_), tuple(pp), tuple(d)), (1.05, .42, .2), 'met'), hexc(GD)))
        handle(o, L, H, GD, r=1.4)
    return Scene(o)


if __name__ == '__main__':
    OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
    for key in sys.argv[2:]:
        sc = ruong(int(key[1:]))
        outs, anc = B.render(sc, key, water=False)
        outs[0].save(os.path.join(OUT, key + '.webp'), lossless=True, quality=100, method=6)
        print(key, outs[0].size, flush=True)
