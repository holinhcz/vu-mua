# Tạp hóa đầu ngõ cấp 1 (game id taphoa, 2x2, mirror taphoa2) as a real 3D model in the kho/sạp/quán kit.
# Link 2026-11-08 14:35: "check tới tiếp tạp hoá". Redesigned, not a copy of the old flat canvas one (OP level 1):
#  - a small nhà lá shop, ridge along u, woven phên walls, a side window with its own propped flap
#  - the whole front opens under a big plank shutter (cửa chống) propped out on two bamboo poles: the shop's awning
#  - a plank counter with a row of candy jars (hũ kẹo), a stack of bánh tráng, a rổ trứng vịt; a kệ of bottles, cans and
#    boxes behind it; strings of snack packets and a nải chuối hung from the shutter edge; a đèn bão for the night
#  - in front: two crates of glass bottles (két nước ngọt), an open bao gạo with a tin scoop, a khạp
#  - TẠP HÓA board standing on the roof's front edge (the game paints the words)
# One layer (no customers at the shop). Usage: python3 taphoa3d.py prev OUT.png [n]    python3 taphoa3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'kho')); sys.path.insert(0, os.path.join(HERE, '..', 'sap'))
import kho3d as K
import sap3d as SP
from kho3d import (W3, T, nv, UP, Scene, X3, hexc, vnoise, plane, tube, disc, lathe, extrude, rrect, rrect_top, box, obox,
                   mat_flat, MATS, GLOSS, M_EARTHSIDE, M_BAMBOO, M_WEAVE_F, M_WEAVE_R, M_GLAZE, M_LID, M_PLANK,
                   M_RATTAN, M_OLDBAMBOO, M_FLOOR, M_BOWL, M_WOOD, M_BARK, M_GABLE, M_SOOT, M_COCO)
from sap3d import lathe2, bam, ell, cone, M_BOTTLE, M_CAP, M_RICE

K.BB = (-72, -112, 72, 42)
K.OX, K.OY = 0, -32                          # at.P(2,2)
U0, U1, V0, V1 = 0.18, 1.82, 0.16, 1.2       # the shop walls
K.WU0, K.WU1, K.WV0, K.WV1 = U0, U1, V0, V1
ZF = 2.4                                     # the huts' pad height (Link 14:20 on the quán)
ZW = 40.0
K.ZW = ZW
K.ZF = ZF
K.INSIDE_K = 0.3                             # Link 14:07: every building lit like the đình (was)
K.SUN_DAY = 1.0                              # Link 17:05: own sun, not the sạp's (import sap3d set K.SUN_DAY/WEATHER for every kit)
K.WEATHER = False                            # as published v960 (no grey patches)
K.FOOT = (0.06, 1.94, 0.06, 1.94, 0.08)
K.SHEET = 'taphoa.webp'
K.SEED = 6200
K.PATCH = None
K.RV, K.RZ = 0.68, 58.0
K.EV, K.EZ = 1.3, 38.5
K.BV, K.BZ = 0.06, 38.5
K.RU0, K.RU1 = 0.1, 1.9
K.RIDGE_R, K.BATTEN_R, K.POLE_R, K.TIE_R = 1.9, 0.42, 0.4, 0.22   # Link 14:53: nóc nhỏ như chòi lá
K.SMOKE_U = -9.0
SV = 1.35                                    # sign plane (game text at SV + .04, z 47)
SZ0, SZ1 = 42.5, 51.5
SH_V, SH_Z = 0.44, 8.5                       # the shutter reaches V1 + SH_V and drops SH_Z
LAMP = (1.52, V1 + 0.42, 22.0)                # hung from the shutter's outer edge, in sight
JARC = ('#e2453a', '#f2c230', '#3aa860', '#ee7a22', '#c84a9a')

# ---------------------------------------------------------------- materials
M_SIGNB, M_CANDY, M_SN1, M_SN2, M_SN3, M_SN4, M_SN5, M_EGG2, M_TRANG, M_CAN, M_OIL, M_LAMPTIN, M_CRATE2, M_DARK2 = range(160, 174)


def mat_signb(uv, prm, pos, nrm):
    a, b = uv[:, 0], uv[:, 1]
    g = 0.9 + 0.08 * vnoise(a * 0.5, b * 5, 2.0) + 0.05 * np.sin(b * 7 + vnoise(a * 0.25, b, 5.0) * 4)
    tw = ((np.floor((a + b) / 1.3) + np.floor((a - b) / 1.3)) % 2)                    # a phên tre painted blue: faint twill
    g = g * (0.9 + 0.1 * tw)
    base = hexc('#2c5d96')[None] * g[:, None]
    return np.clip(base, 0, 1), nrm


def mat_candy(uv, prm, pos, nrm):
    """a glass hũ full of candy: prm0 = foot z, prm1 = height, prm2 = colour; speckled sweets under a pale glass shoulder"""
    z = pos[:, 2]; t = np.clip((z - prm[:, 0]) / np.maximum(prm[:, 1], 1e-3), 0, 1)
    ci = np.clip(prm[:, 2].astype(int), 0, len(JARC) - 1)
    cols = np.array([hexc(c) for c in JARC])[ci]
    n = vnoise(pos[:, 0] * 1.4, (pos[:, 1] + z) * 1.4, 7.0)
    sp = (n > 0.62)[:, None]
    sweets = np.where(sp, np.clip(cols * 1.25 + 0.15, 0, 1), cols * (0.85 + 0.2 * n)[:, None])
    glass = hexc('#dfe8e6')[None] * np.ones_like(sweets)
    base = np.where((t > 0.74)[:, None], glass, sweets * 0.82 + 0.18 * glass)
    return np.clip(base, 0, 1), nrm


def mat_crate2(uv, prm, pos, nrm):
    a, b = uv[:, 0], uv[:, 1]
    g = 0.88 + 0.1 * vnoise(a * 0.4, b * 2.0, 4.0)
    base = hexc('#b88a52')[None] * g[:, None]
    gap = np.abs(((b / 2.4) % 1) - 0.5) > 0.44
    return np.clip(np.where(gap[:, None], base * 0.6, base), 0, 1), nrm


MATS.update({M_SIGNB: mat_signb, M_CANDY: mat_candy, M_SN1: mat_flat('#d8342c'), M_SN2: mat_flat('#f2c230'), M_SN3: mat_flat('#ee7a22'),
             M_SN4: mat_flat('#2f78c4'), M_SN5: mat_flat('#3a9a48'), M_EGG2: mat_flat('#eee3cc'), M_TRANG: mat_flat('#efe2bf'),
             M_CAN: mat_flat('#c8342a'), M_OIL: mat_flat('#e8b42a'), M_LAMPTIN: mat_flat('#7c3826'), M_CRATE2: mat_crate2,
             M_DARK2: mat_flat('#2a2018')})
K.NIGHT_EMIT = {K.M_LAMPGLASS: '#ffa236'}     # lamp glass burns warm at night (Link 15:05: the lamp itself must glow)
INLAMP = (1.7, 0.64, 14.6)                   # đèn dầu on the side shelf inside, seen through the window
GLOSS.update({M_CANDY: (0.55, 60.0), M_SN1: (0.5, 50.0), M_SN2: (0.5, 50.0), M_SN3: (0.5, 50.0), M_SN4: (0.5, 50.0), M_SN5: (0.5, 50.0),
              M_CAN: (0.5, 50.0), M_OIL: (0.45, 50.0), M_LAMPTIN: (0.3, 30.0), M_EGG2: (0.15, 30.0)})


def rwall(S, va, vb, za, zb):
    O = W3(U1 - 0.01, V1, ZF); A = W3(0, V0, 0) - W3(0, V1, 0); Bv = np.array([0, 0, ZW - ZF]); la, lb = np.linalg.norm(A), ZW - ZF
    F = lambda U, V: O + A * (U / la)[..., None] + Bv * (V / lb)[..., None]
    S.grid(F, max(2, int((vb - va) * 26)), max(2, int((zb - za) * 0.7)), M_WEAVE_R, (0, 0, 0), 0.0, uvr=(((V1 - vb) * T, (V1 - va) * T), (za - ZF, zb - ZF)))


def oillamp(S, c):
    """đèn dầu hột vịt: a small glass lamp with a tin burner and a tall glass chimney"""
    lathe(S, c, [(0, 1.3), (0.4, 1.5), (1.4, 1.6), (2.4, 1.0), (2.6, 0.6)], K.M_LAMPGLASS, na=16)
    lathe(S, c + np.array([0, 0, 2.5]), [(0, 0.75), (0.7, 0.75), (0.8, 0.5)], K.M_TIN, na=12)
    lathe(S, c + np.array([0, 0, 3.2]), [(0, 0.5), (0.8, 0.9), (2.2, 0.95), (3.2, 0.55), (4.4, 0.5)], K.M_LAMPGLASS, na=14)
    ell(S, c + np.array([0, 0, 4.2]), 0.28, 0.28, 0.7, K.M_FLAME, nu=6, nvv=8)


def post(S, rng, u, v, z1, r=1.6):
    tube(S, W3(u, v, -0.3), W3(u, v, z1), r, M_BARK, prm=(rng.random(), 0, 0), nr=12, nl=12, taper=0.88)


def zroof(v):
    return np.where(v < K.RV, K.BZ + (v - K.BV) / (K.RV - K.BV) * (K.RZ - K.BZ), K.EZ + (K.EV - v) / (K.EV - K.RV) * (K.RZ - K.EZ))


def gable(S, u, sgn):
    def F(U, V):
        v = V0 + U / T; zt = zroof(v) - 2.4
        return np.stack([np.full_like(U, u * T), v * T, ZW + V * np.clip(zt - ZW, 0, None)], -1)
    S.grid(F, 36, 12, M_GABLE, (0, 0, 0), 0.0, uvr=((0, (V1 - V0) * T), (0, 1)), flip=sgn < 0)


def jar(S, c, ci):
    """hũ kẹo: a squat glass jar of sweets with a red screw lid"""
    h = 5.2
    lathe(S, c, [(0, 1.7), (0.3, 1.95), (3.6, 2.0), (4.4, 1.6), (4.9, 1.3), (h, 1.3)], M_CANDY, prm=(c[2], h, ci), na=20)
    lathe(S, c + np.array([0, 0, h - 0.1]), [(0, 1.45), (0.9, 1.45), (1.0, 0.0)], M_CAP, na=16)


def packet(S, c, col, w=1.7, h=2.5):
    """one snack packet (bịch bánh) hanging on a string: a puffed, crimped bag facing the yard"""
    ell(S, c, w * 0.5, 0.42, h * 0.5, col, nu=6, nvv=10)
    for s in (-1, 1):
        box(S, c + np.array([-w * 0.48, -0.15, s * h * 0.5 - (0.35 if s > 0 else 0)]), c + np.array([w * 0.48, 0.15, s * h * 0.5 + (0 if s > 0 else 0.35)]), col)


def snack_string(S, top, n, k0):
    cols = (M_SN1, M_SN2, M_SN3, M_SN4, M_SN5)
    tube(S, top, top - np.array([0, 0, 3.0 * n + 0.6]), 0.1, M_RATTAN, nr=4, nl=2)
    for j in range(n):
        packet(S, top - np.array([0, 0, 1.9 + 3.0 * j]), cols[(k0 + j) % 5])


def biglamp(S, c, k=1.5):
    lb = c - np.array([0, 0, 2.6 * k])
    lathe(S, lb, [(0, 1.5 * k), (0.3 * k, 1.7 * k), (1.2 * k, 1.6 * k), (1.5 * k, 0.9 * k)], M_LAMPTIN)
    lathe(S, lb + np.array([0, 0, 1.5 * k]), [(0, 0.9 * k), (0.8 * k, 1.35 * k), (2.0 * k, 1.45 * k), (3.2 * k, 1.2 * k), (3.9 * k, 0.8 * k)], K.M_LAMPGLASS)
    lathe(S, lb + np.array([0, 0, 5.3 * k]), [(0, 1.2 * k), (0.6 * k, 1.25 * k), (1.2 * k, 0.6 * k), (1.8 * k, 0.3 * k)], M_LAMPTIN)
    for sg in (-1, 1):
        tube(S, lb + np.array([1.55 * k * sg, 0, 0.6 * k]), lb + np.array([1.2 * k * sg, 0, 6.6 * k]), 0.16 * k, M_SOOT, nr=4, nl=2)
    ell(S, c, 0.35 * k, 0.35 * k, 0.8 * k, K.M_FLAME, nu=6, nvv=8)


def shelf_goods(S, rng, u0, u1, v, z):
    """a row of shop goods on a board: fish sauce and oil bottles, cans of sữa đặc, boxes of mì gói and matches"""
    u = u0
    while u < u1 - 0.04:
        kind = int(rng.choice([0, 0, 1, 1, 2, 3, 3])); c = W3(u, v, z)
        if kind == 0:
            lathe(S, c, [(0, 1.0), (4.0, 1.0), (4.8, 0.45), (6.2, 0.38), (6.5, 0.45)], M_BOTTLE, na=12)
            lathe(S, c + np.array([0, 0, 6.4]), [(0, 0.48), (0.8, 0.48), (0.9, 0.0)], M_CAP, na=8); u += 0.075
        elif kind == 1:
            lathe(S, c, [(0, 1.1), (4.6, 1.1), (5.4, 0.5), (6.0, 0.5)], M_OIL, na=12)
            lathe(S, c + np.array([0, 0, 5.9]), [(0, 0.55), (0.6, 0.55), (0.7, 0.0)], M_SN5, na=8); u += 0.075
        elif kind == 2:
            for j in range(1):                                                        # lon sữa đặc: short, white band
                lathe(S, c + np.array([0, 0, 2.0 * j]), [(0, 1.15), (0.5, 1.15)], M_CAN, na=12)
                lathe(S, c + np.array([0, 0, 2.0 * j + 0.5]), [(0, 1.15), (1.1, 1.15)], M_TRANG, na=12)
                lathe(S, c + np.array([0, 0, 2.0 * j + 1.6]), [(0, 1.15), (0.35, 1.15), (0.4, 0.0)], M_CAN, na=12)
            u += 0.07
        else:
            col = (M_SN2, M_SN4, M_SN1)[int(rng.integers(3))]
            box(S, c + np.array([-1.3, -1.0, 0]), c + np.array([1.3, 1.0, 3.2]), col); box(S, c + np.array([-1.2, -0.9, 3.2]), c + np.array([1.2, 0.9, 5.6]), col)
            u += 0.09


def back(S, rng):
    rrect_top(S, 0.06, 1.94, 0.06, 1.94, 0.06, ZF, M_FLOOR)
    extrude(S, rrect(0.06, 1.94, 0.06, 1.94, 0.06), 0.0, ZF, M_EARTHSIDE, flare=0.6)
    e = 0.01
    # walls: woven phên all round, the front open between two posts (shop opening u .3 - 1.7, under a phên lintel)
    plane(S, W3(U0, V0 + e, ZF), W3(U1, 0, 0) - W3(U0, 0, 0), np.array([0, 0, ZW - ZF]), 44, 26, M_WEAVE_F)
    plane(S, W3(U0 + e, V1, ZF), W3(0, V0, 0) - W3(0, V1, 0), np.array([0, 0, ZW - ZF]), 28, 26, M_WEAVE_R)
    for (va, vb, za, zb) in ((V0, 0.46, ZF, ZW), (0.86, V1, ZF, ZW), (0.46, 0.86, ZF, 17.0), (0.46, 0.86, 28.0, ZW)):
        rwall(S, va, vb, za, zb)                                                      # right wall, a real hole for the window
    plane(S, W3(U0, V1 - e, 33.5), W3(U1, 0, 0) - W3(U0, 0, 0), np.array([0, 0, ZW - 33.5]), 44, 5, M_WEAVE_F)
    # the dark shop inside (floor and back) shows through the opening
    gable(S, U0, -1); gable(S, U1, 1)
    for (u, v) in ((U0, V0), (U1, V0), (U0, V1), (U1, V1)):
        post(S, rng, u, v, ZW + 1.6)
    bam(S, rng, W3(U0 - 0.06, V1, ZW), W3(U1 + 0.06, V1, ZW), 1.25, nl=14)
    bam(S, rng, W3(U0 - 0.06, V0, ZW), W3(U1 + 0.06, V0, ZW), 1.15, nl=14)
    for u in (U0, U1):
        bam(S, rng, W3(u, V0 - 0.06, ZW - 0.8), W3(u, V1 + 0.06, ZW - 0.8), 1.1, nl=10)
        for z in (14.0, 28.0):
            bam(S, rng, W3(u + (0.012 if u > 1 else -0.012), V0, z), W3(u + (0.012 if u > 1 else -0.012), V1, z), 0.5, nl=8)
    bam(S, rng, W3(U0, V1 + 0.012, 33.5), W3(U1, V1 + 0.012, 33.5), 0.7, nl=10)          # lintel over the opening
    K.roof(S, rng, 0)
    # side window on the right wall: a bamboo frame and bars, no flap (Link 14:53); the inside shows through it (Link 15:05)
    wu = U1 + 0.004
    for (a, b) in ((W3(wu, 0.46, 17.0), W3(wu, 0.86, 17.0)), (W3(wu, 0.46, 28.0), W3(wu, 0.86, 28.0)),
                   (W3(wu, 0.46, 17.0), W3(wu, 0.46, 28.0)), (W3(wu, 0.86, 17.0), W3(wu, 0.86, 28.0))):
        tube(S, a, b, 0.55, M_BAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=4)
    for v in (0.56, 0.66, 0.76):
        tube(S, W3(wu, v, 17.0), W3(wu, v, 28.0), 0.35, M_BAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=3)
    # inside, against the right wall: a small bamboo kệ with a đèn dầu, jars and goods, seen through the window
    for v in (0.4, 0.92):
        for u in (1.6, 1.76):
            bam(S, rng, W3(u, v, ZF), W3(u, v, 22.0), 0.5, nl=4)
    for z in (6.4, 14.0, 21.4):
        for uu in (1.6, 1.65, 1.7, 1.75):
            bam(S, rng, W3(uu, 0.38, z - 0.55), W3(uu, 0.94, z - 0.55), 0.6, nl=8)
    oillamp(S, W3(*INLAMP))
    for (v, k) in ((0.48, 0), (0.82, 3)):
        jar(S, W3(1.68, v, 14.0), k)
    for (v, kind) in ((0.46, 0), (0.56, 1), (0.66, 2), (0.76, 0), (0.86, 1)):
        c = W3(1.68, v, 21.4)
        if kind == 0:
            lathe(S, c, [(0, 1.0), (4.0, 1.0), (4.8, 0.45), (6.2, 0.38), (6.5, 0.45)], M_BOTTLE, na=12)
        elif kind == 1:
            lathe(S, c, [(0, 1.1), (4.6, 1.1), (5.4, 0.5), (6.0, 0.5)], M_OIL, na=12)
        else:
            box(S, c + np.array([-1.0, -1.3, 0]), c + np.array([1.0, 1.3, 5.0]), M_SN2)
    for (v, col) in ((0.5, M_SN4), (0.7, M_SN1), (0.85, M_SN5)):                    # boxes and a sack on the floor
        box(S, W3(1.62, v - 0.05, ZF), W3(1.76, v + 0.05, ZF + 3.6), col)
    # inside: shelves of goods along the back wall (mostly in shade)
    for z in (13.0, 21.0, 29.0):
        slats(S, rng, 0.3, 1.7, V0 + 0.03, V0 + 0.2, z)
        shelf_goods(S, rng, 0.36, 1.66, V0 + 0.1, z)
    # kệ behind the counter: two boards on bamboo legs, goods on them (seen above the counter, under the shutter)
    kv = 1.08
    for u in (0.36, 1.0, 1.64):
        bam(S, rng, W3(u, kv, ZF), W3(u, kv, 21.0), 0.55, nl=4)
    for z in (14.6, 20.6):
        slats(S, rng, 0.33, 1.67, kv - 0.07, kv + 0.07, z)
        shelf_goods(S, rng, 0.38, 1.64, kv, z)
    # counter (quầy): plank top, woven front, jars of sweets, bánh tráng, rổ trứng vịt
    zc = 12.0; cv0, cv1 = 1.25, 1.42
    for (u, v) in ((0.36, cv0 + 0.02), (1.64, cv0 + 0.02), (0.36, cv1 - 0.02), (1.64, cv1 - 0.02)):
        bam(S, rng, W3(u, v, ZF), W3(u, v, zc + 0.4), 0.6, nl=5)
    for v in (cv0 + 0.02, cv1 - 0.02):
        bam(S, rng, W3(0.31, v, zc - 0.1), W3(1.69, v, zc - 0.1), 0.55, nl=10)
    slats(S, rng, 0.33, 1.67, cv0, cv1, zc + 1.2)
    bam(S, rng, W3(0.34, cv1 + 0.004, 5.0), W3(1.66, cv1 + 0.004, 5.0), 0.5, nl=10)
    zt = zc + 1.2
    for k, u in enumerate((0.46, 0.6, 0.74, 0.88, 1.02)):
        jar(S, W3(u, 1.33, zt), k)
    c = W3(1.18, 1.32, zt)                                                            # bánh tráng stack
    for j in range(7):
        disc(S, c + np.array([0.15 * math.sin(j * 2.1), 0.15 * math.cos(j * 1.7), 0.22 * j + 0.1]), (0, 0, 1), 3.6, M_TRANG, nr=3, na=22, dome=0.02)
    c = W3(1.48, 1.33, zt)                                                            # rổ trứng vịt
    lathe2(S, c, [(0, 2.4), (0.4, 3.4), (2.2, 4.1), (2.4, 4.2)], M_WEAVE_R, na=28)
    for k in range(11):
        an = k * 2.4; rr = 0.6 + 2.0 * ((k * 0.37) % 1)
        ell(S, c + np.array([rr * math.cos(an), rr * math.sin(an), 2.4 + 0.25 * (k % 3)]), 1.05, 0.85, 0.8, M_EGG2,
            axes=(np.array([math.cos(an), math.sin(an), 0.0]), np.array([-math.sin(an), math.cos(an), 0.0]), UP), nu=5, nvv=8)
    # cửa chống: a tấm phên tre on a bamboo frame hinged at the front plate, propped out on two bamboo poles
    h0 = W3(U0 + 0.03, V1 + 0.02, ZW - 1.0); A = W3(U1 - 0.03, 0, 0) - W3(U0 + 0.03, 0, 0); B = np.array([0, SH_V * T, -SH_Z])
    LBs = np.linalg.norm(B); su = -B / LBs; ax = A / np.linalg.norm(A); n_up = nv(np.cross(ax, su))
    if n_up[2] < 0: n_up = -n_up
    obox(S, h0 + n_up * 0.5, A, B, n_up * 0.5, M_WEAVE_F)                              # tấm phên tre
    for f in (0.0, 1.0):                                                              # the frame: two side rails, front and back bars
        bam(S, rng, h0 + A * f, h0 + A * f + B, 0.5, nl=6)
    bam(S, rng, h0 + B, h0 + A + B, 0.55, nl=12)
    for f in (0.33, 0.67):
        bam(S, rng, h0 + A * f - n_up * 0.4, h0 + A * f + B - n_up * 0.4, 0.4, nl=6)
    edge = h0 + B
    for f in (0.03, 0.97):
        p = edge + A * f - n_up * 0.6
        bam(S, rng, np.array([p[0], p[1], ZF - 0.3]), p - np.array([0, 0, 0.6]), 0.62, nl=8)
    for (f, n, k0) in ((0.2, 4, 0), (0.38, 3, 2), (0.62, 3, 1), (0.8, 4, 3)):      # snack strings along the edge
        snack_string(S, edge + A * f - np.array([0, 0.4, 0.3]), n, k0)
    tube(S, W3(LAMP[0], LAMP[1], ZW - 1.0 - SH_Z * (LAMP[1] - V1 - 0.02) / SH_V), W3(LAMP[0], LAMP[1], LAMP[2] + 4.4), 0.16, M_SOOT, nr=4, nl=2)
    biglamp(S, W3(*LAMP), k=1.0)                                                   # kho size (Link 15:51)
    # TẠP HÓA board standing on the roof's front edge (the game paints the words)
    for u in (0.62, 1.38):
        bam(S, rng, W3(u, V1 + 0.03, ZW - 0.6), W3(u, SV - 0.02, SZ1 + 1.6), 0.55, nl=6)
        tube(S, W3(u - 0.03, V1 + 0.03, ZW + 0.3), W3(u + 0.03, V1 + 0.04, ZW + 0.6), 0.75, M_RATTAN, nr=6, nl=2)
    box(S, W3(0.45, SV, SZ0), W3(1.55, SV + 0.03, SZ1), M_SIGNB)
    for (a, b) in ((W3(0.45, SV + 0.035, SZ0), W3(1.55, SV + 0.035, SZ0)), (W3(0.45, SV + 0.035, SZ1), W3(1.55, SV + 0.035, SZ1)),
                   (W3(0.45, SV + 0.035, SZ0), W3(0.45, SV + 0.035, SZ1)), (W3(1.55, SV + 0.035, SZ0), W3(1.55, SV + 0.035, SZ1))):
        tube(S, a, b, 0.5, M_BAMBOO, prm=(rng.random(), 0.3, 0), nr=6, nl=4)
    front_props(S, rng)


def slats(S, rng, u0, u1, v0, v1, z):
    """a shelf / counter top of split bamboo laid side by side (no planks: Link wants it all tre lá)"""
    n = max(3, int(round((v1 - v0) * T / 1.25)))
    for i in range(n):
        v = v0 + (v1 - v0) * (i + 0.5) / n
        bam(S, rng, W3(u0, v, z - 0.55), W3(u1, v, z - 0.55 + rng.uniform(-0.08, 0.08)), 0.6, nl=10)
    for u in (u0 + 0.03, (u0 + u1) / 2, u1 - 0.03):                                   # rattan lashing over the slats
        tube(S, W3(u, v0 - 0.01, z + 0.05), W3(u, v1 + 0.01, z + 0.05), 0.2, M_RATTAN, nr=4, nl=2)


def canxe(S, rng, c):
    """cần xé: a tall woven bamboo basket full of soda bottles (instead of a wooden crate)"""
    lathe2(S, c, [(0, 3.4), (0.4, 4.1), (5.6, 4.6), (6.0, 4.8)], M_WEAVE_R, na=28)
    lathe(S, c + np.array([0, 0, 5.8]), [(0, 4.85), (0.5, 4.85)], M_BAMBOO, na=28)
    disc(S, c + np.array([0, 0, 4.6]), (0, 0, 1), 4.3, M_DARK2, nr=3, na=20, dome=0.0)
    for k in range(9):
        an = k * 2.39; rr = 0.0 if k == 0 else (1.7 if k < 4 else 3.1)
        b = c + np.array([rr * math.cos(an), rr * math.sin(an), 4.4 + 0.3 * (k % 2)])
        lathe(S, b, [(0, 0.62), (1.2, 0.62), (1.9, 0.3), (2.6, 0.27)], M_BOTTLE, na=10)
        lathe(S, b + np.array([0, 0, 2.55]), [(0, 0.33), (0.3, 0.33), (0.35, 0.0)], M_CAP, na=8)


def front_props(S, rng):
    # kept clear of the two shutter poles (u .21 / 1.79 at v 1.66) on screen: Link 14:53
    canxe(S, rng, W3(0.64, 1.74, ZF))
    c = W3(1.4, 1.76, ZF)                                                             # open bao gạo, rim rolled down, a tin scoop
    lathe(S, c, [(0, 3.2), (0.8, 4.2), (3.2, 4.8), (6.0, 4.4), (7.6, 3.7), (7.9, 4.3), (8.5, 4.6), (9.1, 4.2), (9.2, 3.6)], K.M_JUTE, prm=(0.4, 0, 0), na=30)
    ell(S, c + np.array([0, 0, 8.4]), 3.6, 3.6, 2.4, M_RICE, nu=7, nvv=20)
    s = c + np.array([1.0, -0.8, 9.6])
    lathe(S, s, [(0, 1.2), (2.4, 1.2), (2.5, 1.1)], K.M_TIN, na=14)
    c = W3(1.02, 1.84, ZF)                                                            # a khạp with a clay lid
    lathe(S, c, [(0, 2.4), (1.4, 3.3), (4.0, 3.6), (6.2, 3.0), (7.0, 2.3), (7.4, 2.5)], M_GLAZE, na=24)
    lathe(S, c + np.array([0, 0, 7.3]), [(0, 2.8), (0.3, 2.8), (0.9, 1.4), (1.3, 0.5), (1.5, 0.0)], M_GLAZE, na=20)
    for k in range(6):                                                                # a few fallen leaves
        u = rng.uniform(0.2, 1.8); v = rng.uniform(1.5, 1.88); a = rng.uniform(0, math.pi)
        ax = np.array([math.cos(a), math.sin(a), 0.0]); ay = np.array([-math.sin(a), math.cos(a), 0.0])
        ell(S, W3(u, v, ZF + 0.15), 1.2, 0.5, 0.12, K.M_RATTAN, axes=(ax, ay, UP), nu=4, nvv=8)


def front(S, rng):
    pass


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear()
    K.LIGHTS2.append((W3(*LAMP), hexc('#ff9645'), 13.0, 2.6, 'all'))
    K.LIGHTS2.append((W3(INLAMP[0], INLAMP[1], INLAMP[2] + 4.2), hexc('#ff9645'), 18.0, 1.35, 'in'))   # the đèn dầu inside
    K.LIGHTS2.append((W3(U1 + 0.3, 0.66, 21.0), hexc('#ff9645'), 7.0, 0.5, 'all'))    # its light falling out of the window
    K.GLOWS[:] = [(W3(LAMP[0], LAMP[1], LAMP[2] + 0.2), 0.2, 0.85), (W3(INLAMP[0], INLAMP[1], INLAMP[2] + 4.3), 0.0, 0.8)]
    back(S, rng)
    ns0 = S.ns
    if with_props: front(S, rng)
    return S, (ns0, S.ns)


K.build = build


def glow(im, night):
    """night: the lamps are the light sources, so they must read as burning: a white-hot flame core in orange glass
    and a warm halo round the đèn bão (Link 15:05)"""
    if not night: return im
    r = K.R3(K.PXU)
    a = np.asarray(im).astype(np.float32) / 255.0
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    rgb = a[..., :3]; al = a[..., 3:4]
    for (p, halo, core) in ((W3(LAMP[0], LAMP[1], LAMP[2] + 0.2), 0.26, 0.9), (W3(INLAMP[0], INLAMP[1], INLAMP[2] + 4.3), 0.0, 0.8)):
        sx, sy, _ = r.proj(np.array([p]))
        x0, y0 = float(sx[0]) * im.width / r.W, float(sy[0]) * im.height / r.H; px = im.width / r.W * K.PXU
        d2 = ((xx - x0) ** 2 + (yy - y0) ** 2) / (px * px)
        h = halo * np.exp(-d2 / (2 * 6.0 ** 2))
        rgb = rgb + np.array([1.0, 0.62, 0.25]) * h[..., None] * al                       # warm halo on everything round it
        c = core * np.exp(-d2 / (2 * 0.75 ** 2))
        rgb = rgb * (1 - c[..., None]) + np.array([1.0, 0.97, 0.82]) * c[..., None]      # the flame core
    out = np.concatenate([np.clip(rgb, 0, 1), al], -1)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), 'RGBA')


def render(n):
    return K.render(1, n, 'b')               # the lamp glow now comes from K.GLOWS (shared den.lampglow)


if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        n = len(sys.argv) > 3 and sys.argv[3] == 'n'
        render(n).save(sys.argv[2])
    elif sys.argv[1] == 'atlas':
        out, tab = sys.argv[2], sys.argv[3]
        frames = {}
        for n in (0, 1):
            im = render(bool(n)); bb = im.getbbox(); frames['b' + ('n' if n else 'd')] = (im.crop(bb), bb)
        keys = ['bd', 'bn']
        x = 0; G = {}; sc = float(K.PXU); H = max(f[0].height for f in frames.values()); BB = K.BB
        sheet = Image.new('RGBA', (sum(frames[k][0].width + 2 for k in keys), H), (0, 0, 0, 0))
        for k in keys:
            im, bb = frames[k]; sheet.paste(im, (x, 0))
            G[k] = [x, 0, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
            x += im.width + 2
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, K.SHEET), 'WEBP', quality=92, method=6); json.dump(G, open(tab, 'w'))
        print('sheet', sheet.size)
