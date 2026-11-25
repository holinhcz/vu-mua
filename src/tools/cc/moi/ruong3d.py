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
from ghe3d import Cut, Ell
import numpy as np
B.INNER_LN = 1.0   # Link 11-25: "viền đen là gì" -> rương không nét tối trong
B.RING_K = .82     # viền ngoài cùng tông, chỉ hơi đậm

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
        c = c * (.92 + .08 * dimp + .06 * fine)[:, None]
        sc = scratches(P, 95, .7, 40.0)
        c = c * (1 - .55 * sc)[:, None] + np.minimum(obj.col * 1.45, 1)[None] * (.55 * sc)[:, None]
        pat = sstep(.6, .85, vnoise(P, 2.4, 92)) * .45 * (.5 + .5 * vnoise(P, 7, 94))
        pat = 0
        if obj.col[0] > .8 and obj.col[1] > .55:   # vàng / đồng vàng: chấm đột (punch) li ti + vệt đánh bóng sáng
            dots = sstep(.72, .8, vnoise(P, 22.0, 108))
            c = c * (1 - .22 * dots)[:, None]
            amb = vnoise(P, .8, 110)

            pol = sstep(.55, .9, vnoise(P * V(1, 1, 3), 1.2, 109))
            c = c * (1 - .18 * pol)[:, None] + np.minimum(obj.col * 1.25, 1)[None] * (.18 * pol)[:, None]
        if getattr(obj, 'crack', False):      # vàng thếp: rạn chân chim mảnh
            cr = (np.abs(vnoise(P, 14.0, 96) - .5) < .025) & (vnoise(P, 2.0, 107) > .5)
            pass
        return c
    if k in ('son', 'xacu', 'van', 'hoivan'):
        if k in ('son', 'xacu'):              # sơn: thớ gỗ hằn dưới sơn, rạn nhỏ, bụi đọng
            g = .5 + .5 * np.sin(x * .9 + vnoise(P * V(1, 1, 4), .8, 97) * 7 + z * .3)
            c = c * (.96 + .06 * g)[:, None]

        ed = edge_dist(obj, x, y, z)
        if ed is not None:                    # mòn cạnh: sơn sờn lộ gỗ / gỗ bóng sáng ở cạnh
            wn = vnoise(P, 2.2, 100)
            wear = sstep(.42, .05, ed + .2 * (wn - .5)) * sstep(.45, .7, wn)
            wc = getattr(obj, 'wearc', None)
            if wc is not None and wc.mean() > c.mean() * .9: c = c * (1 - .5 * wear)[:, None] + wc[None] * (.5 * wear)[:, None]
        return c
    if k == 'dan':                            # nan tre: sợi xơ dọc nan, đầu nan sờn
        fib = vnoise(P * V(1, 1, 1), 9.0, 102)
        c = c * (.9 + .16 * fib)[:, None]
        return c
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
        dark = sstep(.93, .995, gl) * .2 
        c = col[None] * ((.84 + .22 * (hsh(iv * 5.3 + 2) - .5)) * (.9 + .12 * g2) * (1 - dark))[:, None]
        gap = np.exp(-(fv / .05) ** 2) + np.exp(-((1 - fv) / .05) ** 2)
        knot = np.exp(-(((u - 3 - iv * 4.7) % 11 - 5.5) ** 2 + ((fv - .5) * pw) ** 2) / .35)
        c = c * (1 - .5 * np.clip(gap, 0, 1))[:, None]
        return c
    if k == 'son':                            # sơn đỏ trên gỗ: mịn, hơi thấy thớ, khe ván rất mờ
        pw = 2.6; fv = (v / pw) % 1.0
        g = vnoise(np.stack([u * .3, v * 2, u * 0], 1).astype(F32), 1.0, 82)
        c = col[None] * (.94 + .08 * g)[:, None]
        return c * (1 - .12 * (np.exp(-(fv / .04) ** 2) + np.exp(-((1 - fv) / .04) ** 2)))[:, None]
    if k == 'xacu' and getattr(obj, 'noinlay', False):
        return col[None] * (.95 + .05 * vnoise(P, 2, 83))[:, None]
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
    for k_ in ('rk', 'lid', 'inlay', 'ns', 'hl', 'panels', 'linec', 'zr', 'wearc', 'ext', 'pat', 'crack', 'noinlay'):
        if hasattr(o, k_): setattr(c, k_, getattr(o, k_))
    return c


PAT = {}                                   # màu xỉn theo màu kim loại (đặt theo bậc)
CRACK = set()


def met(o, col, ns=1.5):
    o = M(o, col=col, sp=.4, pw=50); o.mat = 'ruong'; o.rk = 'kl'; o.ns = ns
    key = tuple(np.round(o.col, 3)); o.pat = PAT.get(key); o.crack = key in CRACK
    return o


# ------------------------------------------------------------ phần dựng chung
# v8 11-25 Link "góc cạnh hơn": gờ, khung, đai = thanh VUÔNG cạnh sắc (không ống tròn)
def bars(o, pts, nrm, w, h, col, mat='met'):
    """thanh tiết diện chữ nhật nối các điểm; nrm(p) = pháp tuyến hướng ra; w = nửa bề ngang, h = nửa dày"""
    pts = [V(*p) for p in pts]
    for a, b in zip(pts[:-1], pts[1:]):
        d = b - a; ln_ = float(np.linalg.norm(d))
        if ln_ < 1e-4: continue
        t = d / ln_; n = nrm((a + b) / 2); n = nz(n - t * float(np.dot(n, t))); bb = nz(np.cross(n, t))
        bx = Box(tuple((a + b) / 2 + n * h), (tuple(t), tuple(bb), tuple(n)), (ln_ / 2 + w * .35, w, h), mat, rr=.025)
        o.append(met(bx, hexc(col)) if mat == 'met' else M(bx, col=col))


def radial(H):
    return lambda p: V(0, 0, 0) + nz(p - W(0, 0, H) - LN * float(np.dot(p - W(0, 0, H), LN)))

def body(o, L, Dp, H, mat, col, lidmat=None, lidcol=None, Rl=None, deco=None, wearc=None, **kw):
    """thân hộp (nửa dài L, nửa sâu Dp, cao H) + nắp vòm nửa trụ bán kính Rl (mặc định = Dp) dọc thân"""
    Rl = Rl or Dp
    bx = R(Box(tuple(W(0, 0, H / 2)), AX, (L, Dp, H / 2), 'ruong', rr=.12), mat, hexc(col), **kw)
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
    pts = [W(x, (Rl + lift - r * .5) * math.cos(t), H + (Rl + lift - r * .5) * math.sin(t)) for t in np.linspace(0, math.pi, n)]
    bars(o, pts, radial(H), r * 1.25, r * .5, col, mat)


def strap_body(o, x, Dp, H, w, col, t=.22):
    """đai dẹt ôm mặt trước + 2 hông? (chỉ mặt trước và mặt sau, quấn qua đáy)"""
    for sy in (1, -1):
        o.append(met(Box(tuple(W(x, sy * (Dp + t * .5), H / 2)), AX, (w, t, H / 2 + .05), 'met', rr=.02), hexc(col)))


def corner_caps(o, L, Dp, H, col, s=1.6, t=.25):
    """bọc góc kim loại: 4 góc đứng của thân, mỗi góc 2 miếng chữ L"""
    for sx in (1, -1):
        for sy in (1, -1):
            for zc in (s * .5 + .1, H - s * .5 - .05):
                o.append(met(Box(tuple(W(sx * (L - s * .45), sy * (Dp + t * .5), zc)), AX, (s * .5, t, s * .5), 'met', rr=.025), hexc(col)))
                o.append(met(Box(tuple(W(sx * (L + t * .5), sy * (Dp - s * .45), zc)), AX, (t, s * .5, s * .5), 'met', rr=.025), hexc(col)))


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
        bars(o, [W(-L, sy * (Rl - r * .2), H + r * .6), W(L, sy * (Rl - r * .2), H + r * .6)], lambda p, sy=sy: FN * sy, r * .8, r * .55, col, mat)


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
        b = R(Box(tuple(C), AX, h, 'ruong', rr=.03), 'hoivan' if (hv and linec is not None) else 'son', hexc(cc), sp=.15, pw=30)
        b.zr = zr; b.linec = hexc(linec) if linec else hexc(cc)
        o.append(b)
    if base:
        strip(W(0, 0, .2), (L + .42, Dp + .42, .22), (0, .42), col)
        strip(W(0, 0, .78), (L + .25, Dp + .25, .38), (.4, 1.16), col)
    strip(W(0, 0, H - .36), (L + .22, Dp + .22, .36), (H - .72, H), col)


def frames(o, lay, col, r=.17, mat='met', lidf=True):
    """khung nổi (gờ) quanh từng ô: thân trước + sau + 2 hông, và ô trên nắp"""
    L, Dp, H, Rl, xr, zr, lv = lay
    w, h = r * 1.15, r * .8
    def ln(pts, nf):
        bars(o, pts, nf, w, h, col, mat)
    for sy in (1, -1):
        for (u0, u1) in xr:
            y = sy * Dp
            ln([W(u0, y, zr[0]), W(u1, y, zr[0]), W(u1, y, zr[1]), W(u0, y, zr[1]), W(u0, y, zr[0])], lambda p, sy=sy: FN * sy)
    for sx in (1, -1):
        x = sx * L; y0 = Dp - .9
        ln([W(x, -y0, zr[0]), W(x, y0, zr[0]), W(x, y0, zr[1]), W(x, -y0, zr[1]), W(x, -y0, zr[0])], lambda p, sx=sx: LN * sx)
    if lidf:
        for (u0, u1) in xr:
            for vv in lv:
                th = vv / Rl; p = lambda xx: W(xx, (Rl - .02) * math.cos(th), H + (Rl - .02) * math.sin(th))
                ln([p(u0), p(u1)], radial(H))
            for uu in (u0, u1):
                ln([W(uu, (Rl - .02) * math.cos(t), H + (Rl - .02) * math.sin(t)) for t in np.linspace(lv[0] / Rl, lv[1] / Rl, 14)], radial(H))


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



# ------------------------------------------------------------ CHẠM NỔI đề tài miền Tây (v6 11-25 Link "trơn, không hoa văn chạm khắc, không liên quan miền Nam")
# mỗi mặt ô = hàm F(u, v) -> (điểm trên mặt, trục u, trục v, pháp tuyến); hoa văn là KHỐI nổi thật (có bóng, AO), không vẽ nét
def F_front(Dp, sy=1):
    def F(u, v): return W(u, sy * (Dp + .06), v), LN, Z, FN * sy
    return F


def F_side(L, sx=-1):
    def F(u, v): return W(sx * (L + .06), u, v), FN * (-sx), Z, LN * sx
    return F


def F_lid(H, Rl):
    def F(u, v):
        th = v / Rl; n = FN * math.cos(th) + Z * math.sin(th); tv = -FN * math.sin(th) + Z * math.cos(th)
        return W(u, (Rl + .06) * math.cos(th), H + (Rl + .06) * math.sin(th)), LN, tv, n
    return F


class Carve:
    def __init__(s, o, col, mat='met', metal=True):
        s.o, s.col, s.mat, s.metal = o, col, mat, metal

    def put(s, ob, col=None):
        col = col or s.col
        if s.metal and col == s.col: s.o.append(met(ob, hexc(col)))
        else: s.o.append(M(ob, col=col, sp=.12, pw=25))

    def leaf(s, F, u, v, ang, ln, wd, th=.2, col=None, bend=-.06):
        p, tu, tv, n = F(u, v); t = nz(tu * math.cos(ang) + tv * math.sin(ang)); b = nz(np.cross(n, t))
        s.put(Ell(tuple(p + t * ln * .5 + n * th * .35), (tuple(t), tuple(b), tuple(n)), (ln * .52, wd, th), s.mat, bend=bend / max(ln, .3)), col)

    def stem(s, F, pts, r=.13, col=None):
        q = []
        for (u, v) in pts:
            p, tu, tv, n = F(u, v); q.append(tuple(p + n * r * .6))
        s.put(Line(q, r, s.mat), col)

    def ball(s, F, u, v, r, sq=.55, col=None):
        p, tu, tv, n = F(u, v)
        s.put(Ell(tuple(p + n * r * sq * .5), (tuple(tu), tuple(tv), tuple(n)), (r, r, r * sq), s.mat), col)

    # --- đề tài
    def frond(s, F, u0, v0, u1, v1, bow=.6, n=9, ln=1.5, col=None):
        """tàu lá dừa nước: sống lá cong, lá chét 2 bên xiên ra, nhỏ dần về ngọn"""
        pts = [(u0 + (u1 - u0) * t, v0 + (v1 - v0) * t + bow * math.sin(math.pi * t)) for t in np.linspace(0, 1, 14)]
        s.stem(F, pts, .14, col)
        for i in range(1, n + 1):
            t = i / (n + 1); k = int(t * 13)
            (ua, va), (ub, vb) = pts[k], pts[min(k + 1, 13)]
            a0 = math.atan2(vb - va, ub - ua); l = ln * (1 - .55 * t)
            for sg in (1, -1):
                s.leaf(F, ua, va, a0 + sg * .95, l, .2, .16, col)

    def dua(s, F, u, v, sc=1.0, col=None, nut=None):
        """chùm dừa 3 trái + tàu lá xoè phía trên"""
        for a in (-.8, .8):
            s.frond(F, u, v + .3 * sc, u + a * 2.3 * sc, v + 1.3 * sc, bow=.35 * sc, n=6, ln=1.0 * sc, col=col)
        s.frond(F, u, v + .3 * sc, u + .15, v + 2.0 * sc, bow=.1, n=6, ln=.9 * sc, col=col)
        for (du, dv) in ((-.55, -.15), (.55, -.15), (0, -.75)):
            s.ball(F, u + du * sc, v + dv * sc, .6 * sc, .6, nut)
            p, tu, tv, n = F(u + du * sc, v + dv * sc + .45 * sc)
            s.ball(F, u + du * sc, v + dv * sc + .5 * sc, .14 * sc, .5, col)

    def fish(s, F, u, v, d=1, sc=1.0, col=None, eye='#1a1208'):
        """cá lóc: thân dài cong nhẹ, đầu bẹt to, vảy theo hàng gờ, vây lưng + vây hậu môn chạy dài có tia, đuôi tròn có tia, vây ngực, mắt"""
        def P(du, dv):
            return F(u + d * du * sc, v + dv * sc)
        def bod(du):          # thân uốn sóng nhẹ
            return .18 * math.sin(du * 1.4)
        # thân: 1 khối dài thon dẹt (không chia đốt, đỡ giống con sâu), uốn theo đường cong
        p, tu, tv, n = P(-.25, bod(-.25)); t = tu * d; b = nz(np.cross(n, t))
        s.put(Ell(tuple(p + n * .12 * sc), (tuple(t), tuple(b), tuple(n)), (1.75 * sc, .46 * sc, .2 * sc), s.mat, bend=-.03), col)
        p, tu, tv, n = P(-1.6, bod(-1.6)); t = tu * d; b = nz(np.cross(n, t))
        s.put(Ell(tuple(p + n * .08 * sc), (tuple(t), tuple(b), tuple(n)), (.6 * sc, .26 * sc, .13 * sc), s.mat), col)
        # đầu bẹt + miệng
        p, tu, tv, n = P(1.55, bod(1.55)); t = tu * d; b = nz(np.cross(n, t))
        s.put(Ell(tuple(p + n * .16 * sc), (tuple(t), tuple(b), tuple(n)), (.5 * sc, .44 * sc, .26 * sc), s.mat), col)
        s.stem(F, [(u + d * 1.7 * sc, v + (bod(1.7) - .12) * sc), (u + d * 2.02 * sc, v + bod(1.9) * sc), (u + d * 1.7 * sc, v + (bod(1.7) + .1) * sc)], .05 * sc, col)
        # nắp mang
        s.stem(F, [(u + d * (1.15 + .18 * math.cos(a)) * sc, v + (bod(1.1) + .4 * math.sin(a)) * sc) for a in np.linspace(-1.2, 1.2, 7)], .06 * sc, col)
        # vảy: hàng vòng cung nhỏ
        for du in np.arange(.85, -1.4, -.3):
            for dv in (-.25, 0, .25):
                if abs(dv) > .3 - abs(du + .2) * .05: continue
                c0 = v + (bod(du) + dv) * sc
                s.stem(F, [(u + d * (du + .12 * math.cos(a)) * sc, c0 + .13 * math.sin(a) * sc) for a in np.linspace(-1.4, 1.4, 5)], .035 * sc, col)
        # vây lưng + vây hậu môn: màng + tia
        for side, du0, du1, h in ((1, .8, -1.55, .42), (-1, -.1, -1.55, .32)):
            for du in np.linspace(du0, du1, 9):
                y0 = bod(du) + side * .45 * (1 - .4 * abs(du + .3) / 1.3)
                s.stem(F, [(u + d * du * sc, v + y0 * sc), (u + d * (du - .15) * sc, v + (y0 + side * h) * sc)], .045 * sc, col)
            pts = [(u + d * (du - .15) * sc, v + (bod(du) + side * (.45 * (1 - .4 * abs(du + .3) / 1.3) + h)) * sc) for du in np.linspace(du0, du1, 9)]
            s.stem(F, pts, .06 * sc, col)
        # đuôi tròn có tia
        tb = -1.95; y = bod(tb)
        for a in np.linspace(-.9, .9, 7):
            s.stem(F, [(u + d * tb * sc, v + y * sc), (u + d * (tb - .7 * math.cos(a)) * sc, v + (y + .7 * math.sin(a)) * sc)], .06 * sc, col)
        s.stem(F, [(u + d * (tb - .7 * math.cos(a)) * sc, v + (y + .7 * math.sin(a)) * sc) for a in np.linspace(-.95, .95, 9)], .07 * sc, col)
        # vây ngực
        s.leaf(F, u + d * .85 * sc, v + (bod(.85) - .15) * sc, math.atan2(-.8, -d), .55 * sc, .16 * sc, .07 * sc, col)
        p, tu, tv, n = P(1.45, bod(1.45) + .14)
        s.o.append(M(Ball(tuple(p + n * .42 * sc), .11 * sc, 'cam'), col=eye))

    def waves(s, F, u0, u1, v, sc=1.0, col=None):
        """sóng nước cuộn: 2 lớp vòng cung + xoáy cuộn ở đỉnh, kiểu sóng chạm gỗ Nam Bộ"""
        w = 1.2 * sc; u = u0
        while u + w <= u1 + .01:
            for k, (dv, amp, rr) in enumerate(((0, .5, .12), (-.4, .3, .08))):
                s.stem(F, [(u + w * t, v + dv * sc + amp * sc * math.sin(math.pi * t)) for t in np.linspace(0, 1, 9)], rr * sc, col)
            cx, cy = u + w * .62, v + .45 * sc
            s.stem(F, [(cx + .3 * sc * (1 - a / 7) * math.cos(a), cy + .3 * sc * (1 - a / 7) * math.sin(a)) for a in np.linspace(0, 5.5, 11)], .08 * sc, col)
            s.ball(F, cx, cy, .08 * sc, .8, col)
            u += w

    def flower(s, F, u, v, sc=1.0, col=None, petal=None):
        """bông sen nở 2 tầng cánh có gân giữa, gương sen có hạt"""
        pc = petal or col
        for ang, l, w in ((90, 1.25, .38), (55, 1.12, .36), (125, 1.12, .36), (22, .9, .32), (158, .9, .32), (-5, .62, .26), (185, .62, .26)):
            s.leaf(F, u, v, math.radians(ang), l * sc, w * sc, .2 * sc, pc, bend=-.15)
            a = math.radians(ang)
            s.stem(F, [(u + .25 * sc * math.cos(a), v + .25 * sc * math.sin(a)), (u + l * .85 * sc * math.cos(a), v + l * .85 * sc * math.sin(a))], .04 * sc, col)
        for ang in (72, 108, 40, 140):          # tầng cánh trong
            s.leaf(F, u, v + .05 * sc, math.radians(ang), .7 * sc, .24 * sc, .3 * sc, pc, bend=-.2)
        s.ball(F, u, v + .1 * sc, .34 * sc, .55, col)
        for a in np.linspace(0, 2 * math.pi, 6, endpoint=False):
            s.ball(F, u + .17 * sc * math.cos(a), v + .1 * sc + .14 * sc * math.sin(a), .07 * sc, 1.0, '#8a5a14' if s.metal else None)
        s.leaf(F, u, v - .1 * sc, math.radians(-90), .5 * sc, .22 * sc, .14 * sc, col)  # đài

    def pad(s, F, u, v, r, col=None):
        """lá sen: đĩa có khía chữ V, mép cuộn nổi, gân toả dày từ rốn lá"""
        p, tu, tv, n = F(u, v)
        s.put(Ell(tuple(p + n * .04), (tuple(tu), tuple(tv), tuple(n)), (r, r * .8, .06), s.mat), col)
        gap = .35
        rim = [(u + r * .97 * math.cos(a), v + r * .78 * math.sin(a)) for a in np.linspace(math.pi * 1.5 + gap, math.pi * 3.5 - gap, 26)]
        s.stem(F, rim, .15, col)
        s.stem(F, [rim[0], (u, v)], .12, col); s.stem(F, [rim[-1], (u, v)], .12, col)
        for a in np.linspace(math.pi * 1.5 + gap + .3, math.pi * 3.5 - gap - .3, 9):
            s.stem(F, [(u, v), (u + r * .55 * math.cos(a) - .08 * math.sin(a), v + r * .44 * math.sin(a)), (u + r * .92 * math.cos(a), v + r * .74 * math.sin(a))], .11, col)
        s.ball(F, u, v, .16, .8, col)

    def vine(s, F, pts, col=None, leafc=None, r=.16, every=2):
        """dây sen uốn: cọng uốn mềm, lá nhỏ + tua cuộn xoắn mọc so le"""
        q = []
        for i in range(len(pts) - 1):
            (ua, va), (ub, vb) = pts[i], pts[i + 1]
            for t in np.linspace(0, 1, 7)[:-1]:
                q.append((ua + (ub - ua) * t, va + (vb - va) * t + .25 * math.sin(math.pi * t) * (1 if i % 2 else -1)))
        q.append(pts[-1])
        s.stem(F, q, r, col)
        for i in range(2, len(q) - 2, every):
            (ua, va), (ub, vb) = q[i], q[i + 1]
            a0 = math.atan2(vb - va, ub - ua); sg = 1 if (i // every) % 2 else -1
            if (i // every) % 3 == 0:
                cx, cy = ua + .35 * math.cos(a0 + sg * 1.4), va + .35 * math.sin(a0 + sg * 1.4)
                s.stem(F, [(ua, va)] + [(cx + .3 * (1 - k / 9) * math.cos(a0 + sg * (3.5 - k * .7)), cy + .3 * (1 - k / 9) * math.sin(a0 + sg * (3.5 - k * .7))) for k in range(9)], .06, col)
            else:
                s.leaf(F, ua, va, a0 + sg * 1.0, .75, .22, .14, leafc or col, bend=-.1)

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
        Rl = body(o, L, Dp, H, 'van', '#c8783a', sp=.08, pw=12, deco=(lay, hexc('#d89050')), wearc='#e0a868')
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
        C = Carve(o, '#eeae62', mat='gox', metal=False)                    # chạm nổi gỗ: chùm dừa + tàu lá dừa nước
        Ff, Fs, Fl = F_front(Dp), F_side(L), F_lid(H, Rl)
        for sx in (1, -1):
            C.dua(Ff, sx * (xs + L) / 2, 3.2, sc=.62, nut='#6a3214')
            C.dua(Fl, sx * (xs + L) / 2, 4.2, sc=.6, nut='#6a3214')
        C.frond(Fs, -4.4, 1.8, 4.4, 2.4, bow=.5, n=9, ln=1.2)
        C.frond(Fl, -4.0, 2.6, 4.0, 3.2, bow=1.0, n=10, ln=1.6)
        C.frond(Fl, 4.0, 6.8, -4.0, 6.2, bow=-1.0, n=10, ln=1.6)
    elif t == 3:    # sơn xanh ngọc, ô khung nổi vàng + chỉ vàng vẽ trong ô, gờ hồi văn vàng, đai vàng đồng, LOGO SEN VÀNG hột đỏ trên đĩa
        L, Dp, H = 9.0, 5.8, 7.8
        xs = L * .6; lay = layout(L, Dp, H, xs)
        feet(o, L, Dp, '#d8a038', metal=True)
        BR = '#c98c2c'; GB = '#f8c848'
        PAT[tuple(np.round(hexc(BR), 3))] = hexc('#8a7a3a'); PAT[tuple(np.round(hexc('#c89030'), 3))] = hexc('#8a7a3a'); PAT[tuple(np.round(hexc('#d8a038'), 3))] = hexc('#8a7a3a')
        PAT[tuple(np.round(hexc(GB), 3))] = hexc('#a07a2a')
        Rl = body(o, L, Dp, H, 'son', '#14947f', sp=.18, pw=30, deco=(lay, hexc(BR)), wearc='#7cc8b8')
        ledges(o, L, Dp, H, '#0e7466', linec=BR)
        frames(o, lay, '#b87c24')
        for x in (-xs, xs):
            strap_body(o, x, Dp, H, .62, BR)
            strap_lid(o, x, H, Rl, .38, BR)
        corner_caps(o, L, Dp, H, BR, s=2.0)
        lid_trim(o, L, H, Rl, BR, r=.36)
        c = W(0, Dp + .25, H - 1.3)
        lotus(o, c, 2.25, GB, vein='#9a6a1c', gem='#e0302a', plate='#8a1c16', plate_r=2.9)
        keyhole(o, c + FN * .5 - Z * 1.85, .8)
        o.append(met(Box(tuple(W(0, Rl + .3, H + .45)), AX, (.6, .22, .9), 'met', rr=.12), hexc(BR)))
        handle(o, L, H, BR, r=1.3)
        C = Carve(o, GB)                                                     # chạm nổi sơn màu: cá lóc vàng vượt sóng, sen hồng, lá sen xanh
        Ff, Fs, Fl = F_front(Dp), F_side(L), F_lid(H, Rl)
        PK, LF, SG, WV = '#f2789a', '#46a84e', '#2e7e3a', '#e6f6ee'
        for sx in (1, -1):
            C.stem(Ff, [(sx * (xs + L) / 2, 4.2), (sx * (xs + L) / 2 + .25, 3.1), (sx * (xs + L) / 2, 2.3)], .14, col=SG)
            C.pad(Ff, sx * (xs + L) / 2, 2.2, 1.1, col=LF)
            C.flower(Ff, sx * (xs + L) / 2, 4.5, sc=1.15, petal=PK)
        C.waves(Fs, -4.6, 4.6, 1.5, sc=.95, col=WV)
        C.waves(Fl, -4.0, 4.0, 2.2, sc=1.1, col=WV)
        C.fish(Fl, -.4, 4.0, d=1, sc=1.25); C.fish(Fl, .6, 6.4, d=-1, sc=1.05)
        for sx in (1, -1):
            C.stem(Fl, [(sx * (xs + L) / 2, 5.0), (sx * (xs + L) / 2 - sx * .3, 4.0), (sx * (xs + L) / 2, 3.0)], .12, col=SG)
            C.pad(Fl, sx * (xs + L) / 2, 3.0, 1.1, col=LF); C.flower(Fl, sx * (xs + L) / 2, 5.4, sc=1.0, petal=PK)
    else:           # sơn son ĐỎ thếp vàng: ô khung vàng khảm xà cừ, gờ hồi văn vàng, LOGO SEN VÀNG TO hột ruby trên đĩa đỏ + vòng ngọc, núm búp sen
        L, Dp, H = 9.4, 6.0, 8.0
        xs = L * .5; lay = layout(L, Dp, H, xs)
        GD = '#d8982a'; GB = '#ffd24a'
        feet(o, L, Dp, GD, metal=True)
        PAT[tuple(np.round(hexc(GD), 3))] = hexc('#a87420'); PAT[tuple(np.round(hexc(GB), 3))] = hexc('#c89a30')
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
        lotus(o, c, 2.6, GB, vein='#b07a18', gem='#d81c3a', plate='#10302a', plate_r=3.3, ring='#f4f0e6')
        keyhole(o, c + FN * .55 - Z * 2.15, .9)
        o.append(met(Box(tuple(W(0, Rl + .3, H + .5)), AX, (.8, .24, 1.1), 'met', rr=.15), hexc(GD)))
        top = W(0, 0, H + Rl + .25)
        o.append(met(Tube(tuple(top - Z * .2), tuple(Z), .5, [(0, 1.3), (1, 1.0)], 'met'), hexc(GD)))
        o.append(met(Ell(tuple(top + Z * 1.2), (tuple(LN), tuple(FN), tuple(Z)), (.55, .55, 1.25), 'met'), hexc(GB)))
        for k in range(6):                                       # cánh búp sen ôm nụ
            a = 2 * math.pi * k / 6; d = LN * math.cos(a) + FN * math.sin(a)
            ax_ = nz(Z + d * .35); pp = nz(np.cross(ax_, d))
            o.append(met(Ell(tuple(top + Z * .95 + d * .5), (tuple(ax_), tuple(pp), tuple(d)), (1.05, .42, .2), 'met'), hexc(GB)))
        handle(o, L, H, GD, r=1.4)
        for ob in o:
            if getattr(ob, 'rk', None) == 'xacu': ob.noinlay = True
        C = Carve(o, GB)                                                       # chạm lộng kiểu tủ thờ Nam Bộ: dây sen vàng, lá ngọc bích, bông sen xà cừ hồng phấn
        Ff, Fs, Fl = F_front(Dp), F_side(L), F_lid(H, Rl)
        PE, JD = '#f7b2c4', '#22a878'
        for sx in (1, -1):
            uc = sx * (xs + L) / 2
            C.vine(Ff, [(uc, 2.3), (uc - sx * .4, 3.3), (uc, 4.2)], leafc=JD, r=.12, every=3)
            C.pad(Ff, uc, 2.3, .9, col=JD)
            C.flower(Ff, uc, 4.7, sc=1.1, petal=PE)
        C.vine(Fs, [(-4.6, 1.9), (-2.5, 2.6), (0, 2.0), (2.5, 2.6), (4.6, 1.9)], leafc=JD, r=.13)
        C.vine(Fl, [(-4.2, 3.4), (-2.6, 4.6), (-1.2, 3.0), (0, 3.6), (1.2, 3.0), (2.6, 4.6), (4.2, 3.4)], leafc=JD, r=.16)
        C.flower(Fl, -2.6, 5.3, sc=1.2, petal=PE); C.flower(Fl, 2.6, 5.3, sc=1.2, petal=PE)
        C.pad(Fl, 0, 5.6, 1.0, col=JD); C.pad(Fl, -3.9, 6.6, .8, col=JD); C.pad(Fl, 3.9, 6.6, .8, col=JD)
        for sx in (1, -1):
            uc = sx * (xs + L) / 2
            C.flower(Fl, uc, 5.0, sc=.85, petal=PE); C.pad(Fl, uc, 2.6, .8, col=JD)
    return Scene(o)


if __name__ == '__main__':
    OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
    for key in sys.argv[2:]:
        sc = ruong(int(key[1:]))
        outs, anc = B.render(sc, key, water=False)
        outs[0].save(os.path.join(OUT, key + '.webp'), lossless=True, quality=100, method=6)
        print(key, outs[0].size, flush=True)
