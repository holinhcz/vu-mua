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


def albedo_r(obj, P):
    if obj.mat != 'ruong': return _pd(obj, P)
    x, y, z = loc(P); k = obj.rk; col = obj.col; n = len(P)
    lid = getattr(obj, 'lid', None)
    if lid is not None:                       # nắp vòm: u dọc thân, v theo cung
        zl, R = lid; u = x; v = R * np.arctan2(z - zl, y)
        endc = np.abs(np.abs(x) - obj.hl) < .08                      # 2 đầu nắp: mặt phẳng, như hông thân
        u = np.where(endc, y, u); v = np.where(endc, z, v)
    else:
        u = x + y; v = z
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
        c = col[None] * ((.84 + .22 * (hsh(iv * 5.3 + 2) - .5)) * (.9 + .12 * g2 + .08 * g))[:, None]
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
        c = np.broadcast_to(hexc('#221a1a'), (n, 3)).copy() * (.95 + .08 * vnoise(P, 2, 83))[:, None]
        cu, cv = 2.7, 2.6
        uu = u / cu; vv = v / cv; row = np.floor(vv); uu = uu + .5 * (row % 2)
        du = ((uu % 1.0) - .5) * cu; dv = ((vv % 1.0) - .5) * cv
        pa = np.arctan2(dv, du); pr = np.hypot(du, dv)
        petal = pr < .66 * (.5 + .5 * np.abs(np.cos(pa * 2)))
        dot = pr < .2
        lf = (np.abs(np.abs(du) - np.abs(dv)) < .1) & (pr > .82) & (pr < 1.1)       # 4 lá nhỏ giữa các hoa
        w = .5 + .5 * np.sin(u * .9 + v * 1.3)
        pearl = hexc('#d8e2de')[None] * (1 - .45 * w)[:, None] + hexc('#e2bcd2')[None] * (.3 * w)[:, None] + hexc('#acd8c4')[None] * (.18 * w)[:, None]
        c = np.where((petal & obj.inlay(x, y, z, lid))[:, None], pearl, c)
        c = np.where((lf & obj.inlay(x, y, z, lid))[:, None], pearl * .85, c)
        c = np.where((dot & obj.inlay(x, y, z, lid))[:, None], D.GOLD[None], c)
        return c
    return col[None] * np.ones((n, 1), F32)


D.albedo_do = albedo_r


def R(o, k, col, lid=None, **kw):
    o = M(o, col=col, **kw); o.mat = 'ruong'; o.rk = k
    if lid is not None: o.lid = lid
    return o


def cut(o, P0, n):
    c = Cut(o, P0, n)
    for k_ in ('rk', 'lid', 'inlay', 'ns', 'hl'):
        if hasattr(o, k_): setattr(c, k_, getattr(o, k_))
    return c


def met(o, col, ns=1.5):
    o = M(o, col=col, sp=.45, pw=50); o.mat = 'met'; o.ns = ns
    return o


# ------------------------------------------------------------ phần dựng chung
def body(o, L, Dp, H, mat, col, lidmat=None, lidcol=None, Rl=None, **kw):
    """thân hộp (nửa dài L, nửa sâu Dp, cao H) + nắp vòm nửa trụ bán kính Rl (mặc định = Dp) dọc thân"""
    Rl = Rl or Dp
    o.append(R(Box(tuple(W(0, 0, H / 2)), AX, (L, Dp, H / 2), 'ruong', rr=.35), mat, hexc(col), **kw))
    lid = Tube(tuple(W(-L, 0, H)), tuple(LN), 2 * L, [(0, Rl), (1, Rl)], 'ruong')
    lid = R(lid, lidmat or mat, hexc(lidcol or col), lid=(H, Rl), **kw); lid.hl = L
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
    for sx in (1, -1):
        c = W(sx * (L + .35), 0, H * .62)
        o.append(met(Box(tuple(c), AX, (.2, .9, .7), 'met', rr=.1), hexc(col)))
        tor = Torus(tuple(W(sx * (L + .55), 0, H * .62 - r * .7)), tuple(LN), r, rr, 'met')
        o.append(met(tor, hexc(col)))


# ------------------------------------------------------------ 4 bậc
def ruong(t):
    o = []
    if t == 1:      # tre đan, nắp đan, 2 nẹp tre + mây buộc, quai mây, chốt gỗ xỏ khuy mây
        L, Dp, H = 8.0, 5.4, 7.2
        Rl = body(o, L, Dp, H, 'dan', '#d6b874', lidcol='#ceae68', sp=.05, pw=10)
        for sy in (1, -1):        # nẹp tre ôm miệng thân + mép nắp
            o.append(M(Line([tuple(W(-L - .1, sy * (Dp + .15), H - .35)), tuple(W(L + .1, sy * (Dp + .15), H - .35))], .42, 'gox'), col='#c09a58'))
            o.append(M(Line([tuple(W(-L - .1, sy * (Dp + .15), .35)), tuple(W(L + .1, sy * (Dp + .15), .35))], .42, 'gox'), col='#b08c4c'))
        for x in (-L * .55, L * .55):
            pts = [tuple(W(x, (Rl + .22) * math.cos(a), H + (Rl + .22) * math.sin(a))) for a in np.linspace(0, math.pi, 22)]
            o.append(M(Line(pts, .3, 'may')))
            for sy in (1, -1):
                o.append(M(Line([tuple(W(x, sy * (Dp + .25), H - .1)), tuple(W(x, sy * (Dp + .25), .2))], .3, 'may')))
        lid_trim(o, L, H, Rl, '#b8924e', r=.38, mat='gox')
        o.append(M(Torus(tuple(W(0, Rl + .5, H + .35)), tuple(LN), .75, .2, 'may')))                 # khuy mây trên nắp
        o.append(M(Torus(tuple(W(0, Dp + .5, H - 1.2)), tuple(LN), .7, .2, 'may')))                  # khuy mây trên thân
        o.append(M(Line([tuple(W(-1.3, Dp + .95, H - .45)), tuple(W(1.3, Dp + .95, H - .45))], .3, 'gox'), col='#8a6234'))   # chốt gỗ xỏ ngang
        for sx in (1, -1):      # quai mây 2 đầu
            pts = [tuple(W(sx * (L + .3 + 1.0 * math.sin(a)), 1.6 * math.cos(a), H * .66 + .4 * math.sin(a))) for a in np.linspace(0, math.pi, 12)]
            o.append(M(Line(pts, .3, 'may')))
    elif t == 2:    # gỗ tràm ván ghép, 2 đai sắt ôm thân + nắp, bọc góc sắt, bản lề, khoá móc sắt
        L, Dp, H = 8.6, 5.6, 7.6
        Rl = body(o, L, Dp, H, 'van', '#b4854e', sp=.08, pw=12)
        IRON = '#5c5a56'
        for x in (-L * .55, L * .55):
            strap_body(o, x, Dp, H, .55, IRON)
            strap_lid(o, x, H, Rl, .34, IRON)
            for zz in (1.4, H - 1.0):
                for sy in (1, 1):
                    o.append(met(Ball(tuple(W(x, Dp + .4, zz)), .26, 'met'), hexc('#3e3c38')))      # đinh tán
        corner_caps(o, L, Dp, H, IRON)
        lid_trim(o, L, H, Rl, '#4e4c48', r=.3)
        o.append(met(Box(tuple(W(0, Dp + .3, H - .6)), AX, (1.1, .2, 1.3), 'met', rr=.12), hexc(IRON)))       # bản khoá
        o.append(met(Box(tuple(W(0, Rl + .35, H + .45)), AX, (.5, .22, 1.0), 'met', rr=.1), hexc(IRON)))      # tai khoá trên nắp
        o.append(met(Torus(tuple(W(0, Dp + .75, H - 1.4)), tuple(FN), .8, .22, 'met'), hexc('#4a4844')))      # khoen
        o.append(met(Box(tuple(W(0, Dp + .8, H - 2.6)), AX, (.85, .4, .75), 'met', rr=.25), hexc('#4a4844')))   # ổ khoá móc
        o.append(M(Box(tuple(W(0, Dp + 1.22, H - 2.75)), AX, (.12, .05, .3), 'met', rr=.03), col='#1a1816'))
        handle(o, L, H, '#4e4c48', r=1.1)
    elif t == 3:    # sơn đỏ, bọc góc + đai đồng, khoá tròn đồng, quai đồng, chân gỗ
        L, Dp, H = 9.0, 5.8, 7.8
        feet(o, L, Dp, '#6a3820')
        Rl = body(o, L, Dp, H, 'son', '#b0322a', sp=.18, pw=30)
        BR = '#b88a3c'
        for x in (-L * .6, L * .6):
            strap_body(o, x, Dp, H, .6, BR)
            strap_lid(o, x, H, Rl, .36, BR)
        corner_caps(o, L, Dp, H, BR, s=2.0)
        lid_trim(o, L, H, Rl, BR, r=.34)
        for sy in (1, -1):
            o.append(met(Box(tuple(W(0, sy * (Dp + .12), .35)), AX, (L - .2, .14, .32), 'met', rr=.08), hexc(BR)))     # nẹp chân đồng
        c = W(0, Dp + .32, H - 1.4)
        o.append(met(Tube(tuple(c), tuple(FN), .35, [(0, 2.0), (1, 1.85)], 'met'), hexc('#c8983e')))        # khoá tròn
        o.append(met(Torus(tuple(c + FN * .35), tuple(FN), 1.6, .2, 'met'), hexc('#987030')))
        o.append(M(Box(tuple(c + FN * .4 + Z * .25), AX, (.22, .05, .3), 'met', rr=.1), col='#2a1a10'))      # lỗ khoá
        o.append(M(Box(tuple(c + FN * .4 - Z * .35), AX, (.1, .05, .4), 'met', rr=.04), col='#2a1a10'))
        o.append(met(Box(tuple(W(0, Rl + .3, H + .35)), AX, (.6, .2, .9), 'met', rr=.12), hexc(BR)))        # tai nắp
        handle(o, L, H, BR, r=1.3)
    else:           # sơn mài đen khảm xà cừ, viền + đai thếp vàng, khoá vàng hột đỏ, chân vàng
        L, Dp, H = 9.4, 6.0, 8.0
        GD = '#f0c448'
        feet(o, L, Dp, '#c89a30', metal=True)
        Rl = body(o, L, Dp, H, 'xacu', '#221a1a', sp=.15, pw=40)
        def inl(x, y, z, lid):          # vùng khảm: trong khung vàng ở thân, giữa 2 đai ở nắp
            if lid is not None: return ((np.abs(x) < L * .5 - .9) | ((np.abs(x) > L * .5 + .9) & (np.abs(x) < L - .9))) & ~((np.abs(x) < 1.3) & (y > 0) & (z < H + Rl * .7))
            band = (z > 1.75) & (z < H - 1.55)
            return band & (((np.abs(x) < L * .5 - 1.0) & ~((np.abs(x) < 2.3) & (z > H - 4.2))) | ((np.abs(x) > L * .5 + 1.0) & (np.abs(x) < L - 1.6)) | (np.abs(np.abs(x) - L) < .1) & (np.abs(y) < Dp - 1.6))
        Rl = Dp
        for ob in o:
            if getattr(ob, 'rk', None) == 'xacu': ob.inlay = inl
        for x in (-L * .5, L * .5):
            strap_body(o, x, Dp, H, .65, GD)
            strap_lid(o, x, H, Rl, .4, GD)
        corner_caps(o, L, Dp, H, GD, s=2.2)
        lid_trim(o, L, H, Rl, GD, r=.36)
        for sy in (1, -1):              # khung chỉ vàng quanh ô khảm
            for zz in (1.2, H - 1.0):
                o.append(met(Box(tuple(W(0, sy * (Dp + .1), zz)), AX, (L - .3, .12, .16), 'met', rr=.06), hexc(GD)))
        c = W(0, Dp + .32, H - 1.5)
        o.append(met(Box(tuple(c), AX, (1.6, .3, 1.9), 'met', rr=.5), hexc('#e6bc48')))                    # bản khoá vàng
        o.append(M(Ball(tuple(c + FN * .45 + Z * .55), .55, 'cam', sq=(1, .6, 1)), col='#c42a2a', sp=.4, pw=60))   # hột đỏ
        o.append(M(Box(tuple(c + FN * .35 - Z * .7), AX, (.16, .05, .35), 'met', rr=.06), col='#2a1a10'))
        o.append(met(Box(tuple(W(0, Rl + .3, H + .4)), AX, (.7, .22, 1.0), 'met', rr=.15), hexc(GD)))
        o.append(met(Ball(tuple(W(0, 0, H + Rl + .55)), .7, 'met', sq=(1, 1, .8)), hexc(GD)))               # núm vàng trên đỉnh nắp
        handle(o, L, H, GD, r=1.4)
    return Scene(o)


if __name__ == '__main__':
    OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
    for key in sys.argv[2:]:
        sc = ruong(int(key[1:]))
        outs, anc = B.render(sc, key, water=False)
        outs[0].save(os.path.join(OUT, key + '.webp'), lossless=True, quality=100, method=6)
        print(key, outs[0].size, flush=True)
