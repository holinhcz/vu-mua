# Nông Trại Chung: Nhà ba gian cổ cấp 1 (game id bagian 3x3, mirror bagian2) as a real 3D model, built with the kho kit.
# Link 2026-11-09 01:48 ("tao bảo đẹp thì làm lại ... nhà 3 gian gian đâu"): a real nhà ba gian hai chái miền Nam,
# redesigned from scratch, not the old canvas one:
#  - the body is 3 gian between 4 tràm columns (the only wood) with a chái at each end, filling the 3x3 lot
#  - a hip roof of lá: the ridge spans the 3 gian, the two chái slopes come down at the ends, rolls on the hips
#  - every gian has its own door: the middle one a double phên door wide open on the bàn thờ (đèn dầu, lư hương,
#    chân đèn, bình bông, mâm trái cây); the side gian single phên doors open on a bộ ván and a lu gạo
#  - the chái have cửa sổ chống (phên propped out on a stick), one more in the right end wall
#  - a narrow front yard only: a bàn thiên on its pole, a lu nước with a gáo dừa, a chổi tre; đèn bão on a column
#   python3 bagian3d.py prev OUT.png [n]        python3 bagian3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'kho')); sys.path.insert(0, os.path.join(HERE, '..', 'sap'))
import kho3d as K
import sap3d as SP
from kho3d import (W3, T, nv, UP, Scene, X3, hexc, vnoise, smooth, plane, tube, disc, lathe, extrude, rrect, rrect_top, box, obox,
                   mat_flat, MATS, GLOSS, M_EARTHSIDE, M_BAMBOO, M_WEAVE_F, M_GLAZE, M_LID, M_PLANK, M_LEAF, M_THEND, M_RIDGE,
                   M_RATTAN, M_OLDBAMBOO, M_FLOOR, M_WOOD, M_BARK, M_SOOT, M_COCO, M_WATER, M_CHIEU, M_STONE,
                   M_GRAIN, M_JUTE, M_TIN)
from sap3d import lathe2, bam, ell, M_GOLD, M_ORANGE, M_REDFRUIT

K.BB = (-104, -148, 104, 56)
K.OX, K.OY = 0, -48                          # at.P(3,3)
ZF = 2.4                                     # the yard
ZH = 7.4                                     # the house platform
U0, U1, V0, V1 = 0.2, 2.8, 0.24, 2.0         # the walls: the house fills the lot (Link 01:32)
G = (0.5, 0.5 + 2 / 3, 0.5 + 4 / 3, 2.5)     # the 4 columns: 3 gian between them, a chái (.3) at each end
ZW = 59.0                                    # wall plate (eaves raised: the vách must not look squashed)
PV = V1 + 0.07                               # the tràm columns stand just out from the wall (deeper ones would hide the doors
                                             # in this camera: a column at depth d covers the wall d to its left)
EU0, EU1, BV, EV, EZ = 0.04, 2.96, 0.06, 2.2, 54.0       # eaves (all at one height round the hip roof)
RA, RB, RV, RZ = 0.82, 2.18, 1.13, 95.0                  # ridge ends, ridge line
DOORS = ((1.26, 1.72), (0.64, 0.98), (1.97, 2.31)); DZ = ZH + 27.0       # middle gian first
CWIN = ((0.25, 0.45), (2.55, 2.75)); RWINS = ((0.45, 0.92), (1.30, 1.77)); WZ = (ZH + 9.0, ZH + 32.0)   # big windows (Link 02:33)
K.ZW, K.ZF = ZW, ZF
K.RZ, K.EZ = RZ, EZ                          # the leaves' weathering (bleached near the ridge, darker at the eave)
K.WU0, K.WU1, K.WV0, K.WV1 = U0, U1, V0, V1
K.INSIDE_K = 0.3
K.SUN_DAY = 1.0                              # Link 17:05: own sun, not the sạp's (import sap3d set K.SUN_DAY/WEATHER for every kit)
K.WEATHER = False                            # as published v960 (no grey patches)
K.FOOT = (0.06, 2.94, 0.06, 2.94, 0.08)
K.SHEET = 'bagian.webp'
K.SEED = 7300
K.PATCH = None
K.RIDGE_R, K.BATTEN_R, K.POLE_R, K.TIE_R = 2.8, 0.6, 0.45, 0.26
LAMP = (1.31, 2.12, 42.0)                    # đèn bão hung from the beam above the left corner of the middle door
OIL = (1.27, 1.84, ZH + 13.0 + 4.2)          # đèn dầu on the bàn thờ
M_VACH, M_DOORW = 213, 211


def mat_vach(uv, prm, pos, nrm):
    """vách lá dừa nước dried for years: the kho leaf rows, weathered greyer and browner than the newer roof"""
    col, n = K.mat_gable(uv, prm, pos, nrm)
    w = 0.5 + 0.5 * vnoise(pos[:, 0] * 0.05 + pos[:, 1] * 0.05, pos[:, 2] * 0.08, 21.0)
    col = col * 0.8 * (1 - 0.32 * w[:, None]) + hexc('#7e6a4c')[None] * 0.32 * w[:, None] * 0.8 + hexc('#7e6a4c')[None] * 0.06
    return np.clip(col, 0, 1), n


MATS[M_VACH] = mat_vach
MATS.update({M_DOORW: mat_flat('#2a1c12')})
M_INCENSE, M_CLOTH, M_FLOWER, M_LEAFG, M_PHEN = 214, 215, 216, 217, 218


def mat_phen(uv, prm, pos, nrm):
    """old phên of fine split bamboo, smoked brown: the window flaps"""
    col, n = K.weave_tex(uv[:, 0], uv[:, 1], [0.8], np.array([1.0, 0, 0]), np.array([0, 0, 1.0]), nrm, cell=0.75)
    col = col * 0.72 + hexc('#6e5232')[None] * 0.14
    return np.clip(col, 0, 1), n


MATS[M_PHEN] = mat_phen
MATS.update({M_INCENSE: mat_flat('#b8862e'), M_CLOTH: mat_flat('#9c2a1e'), M_FLOWER: mat_flat('#f0b828'), M_LEAFG: mat_flat('#4e7a34')})
K.NIGHT_EMIT = {}


# ---------------------------------------------------------------- helpers
def post(S, rng, u, v, z0, z1, r=1.7):
    tube(S, W3(u, v, z0), W3(u, v, z1), r, M_BARK, prm=(rng.random(), 0, 0), nr=12, nl=14, taper=0.9)


def biglamp(S, c):
    lb = c - np.array([0, 0, 2.6])
    lathe(S, lb, [(0, 1.5), (0.3, 1.7), (1.2, 1.6), (1.5, 0.9)], SP.M_LAMPTIN if hasattr(SP, 'M_LAMPTIN') else M_SOOT)
    lathe(S, lb + np.array([0, 0, 1.5]), [(0, 0.9), (0.8, 1.35), (2.0, 1.45), (3.2, 1.2), (3.9, 0.8)], K.M_LAMPGLASS)
    lathe(S, lb + np.array([0, 0, 5.3]), [(0, 1.2), (0.6, 1.25), (1.2, 0.6), (1.8, 0.3)], SP.M_LAMPTIN if hasattr(SP, 'M_LAMPTIN') else M_SOOT)
    for sg in (-1, 1):
        tube(S, lb + np.array([1.55 * sg, 0, 0.6]), lb + np.array([1.2 * sg, 0, 6.6]), 0.16, M_SOOT, nr=4, nl=2)
    ell(S, c, 0.35, 0.35, 0.8, K.M_FLAME, nu=6, nvv=8)


def oillamp(S, c):
    """đèn dầu hột vịt; c = flame centre"""
    b = c - np.array([0, 0, 4.2])
    lathe(S, b, [(0, 1.3), (0.4, 1.5), (1.4, 1.6), (2.4, 1.0), (2.6, 0.6)], K.M_LAMPGLASS, na=16)
    lathe(S, b + np.array([0, 0, 2.5]), [(0, 0.75), (0.7, 0.75), (0.8, 0.5)], M_TIN, na=12)
    lathe(S, b + np.array([0, 0, 3.2]), [(0, 0.5), (0.8, 0.9), (2.2, 0.95), (3.2, 0.55), (4.4, 0.5)], K.M_LAMPGLASS, na=14)
    ell(S, c, 0.28, 0.28, 0.7, K.M_FLAME, nu=6, nvv=8)


def stool(S, rng, c, top=8.0, h=3.0):
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        bam(S, rng, c + np.array([sx * h, sy * h, 0.0]), c + np.array([sx * h, sy * h, top - 0.6]), 0.6, nl=3)
    for i in range(5):
        y = -h - 0.3 + (2 * h + 0.6) * (i + 0.5) / 5
        bam(S, rng, c + np.array([-h - 0.6, y, top - 0.5]), c + np.array([h + 0.6, y, top - 0.5]), 0.55, nl=3)


# ---------------------------------------------------------------- the house


# ---------------------------------------------------------------- walls
def wall_u(S, u0, u1, z0, z1, v):
    """vách lá along u at v; uv in world units so the leaf rows run on across pieces"""
    if u1 - u0 < 1e-3 or z1 - z0 < 1e-3: return
    def F(U, V):
        return np.stack([U, np.full_like(U, v * T), ZH + V], -1)
    S.grid(F, max(2, int((u1 - u0) * 30)), max(2, int((z1 - z0) * 0.7)), M_VACH, (0, 0, 0), 0.0,
           uvr=((u0 * T, u1 * T), (z0 - ZH, z1 - ZH)))


def wall_v(S, v0, v1, z0, z1, u):
    if v1 - v0 < 1e-3 or z1 - z0 < 1e-3: return
    def F(U, V):
        return np.stack([np.full_like(U, u * T), U, ZH + V], -1)
    S.grid(F, max(2, int((v1 - v0) * 30)), max(2, int((z1 - z0) * 0.7)), M_VACH, (0, 0, 0), 0.0,
           uvr=((v0 * T, v1 * T), (z0 - ZH, z1 - ZH)))


def zroof(u, v):
    """underside of the hip roof over (u, v)"""
    zf = EZ + (EV - v) / (EV - RV) * (RZ - EZ); zb = EZ + (v - BV) / (RV - BV) * (RZ - EZ)
    ze = np.minimum(EZ + (u - EU0) / (RA - EU0) * (RZ - EZ), EZ + (EU1 - u) / (EU1 - RB) * (RZ - EZ))
    return np.minimum(np.minimum(np.where(v > RV, zf, zb), ze), RZ) - 2.6


def top_v(S, v0, v1, u):
    """the part of a vách ngăn above the wall plate, cut to the roof"""
    zmax = float(zroof(u, RV)); vv = np.linspace(v0, v1, 80); zt = zroof(u, vv)
    def F(U, V):
        z = ZH + np.minimum(V, zroof(u, U / T) - ZH)
        return np.stack([np.full_like(U, u * T), U, np.maximum(z, ZW - 0.5)], -1)
    S.grid(F, 60, max(2, int((zmax - ZW) * 0.6)), M_VACH, (0, 0, 0), 0.0, uvr=((v0 * T, v1 * T), (ZW - 0.5 - ZH, zmax - ZH)))


def holed(S, a0, a1, holes, put):
    """a wall from a0 to a1 (ZH..ZW) with rectangular holes [(a, b, z0, z1)]"""
    cuts = sorted(set([a0, a1] + [h[0] for h in holes] + [h[1] for h in holes]))
    for a, b in zip(cuts[:-1], cuts[1:]):
        hs = sorted((h[2], h[3]) for h in holes if h[0] <= a + 1e-6 and h[1] >= b - 1e-6)
        z = ZH
        for (z0, z1) in hs:
            put(a, b, z, z0); z = z1
        put(a, b, z, ZW)


def window(S, rng, a, b, z0, z1, axis):
    """a big window: tre frame, song tre bars, a plank sill; open to the room (the lamp inside shows through at night)"""
    if axis == 'u':
        P = lambda t, z, o=0.0: W3(t, V1 + 0.006 + o, z); out = np.array([0, 1.0, 0])
    else:
        P = lambda t, z, o=0.0: W3(U1 + 0.006 + o, t, z); out = np.array([1.0, 0, 0])
    for (p, q) in ((P(a, z0), P(b, z0)), (P(a, z1), P(b, z1)), (P(a, z0 - 0.6), P(a, z1 + 0.6)), (P(b, z0 - 0.6), P(b, z1 + 0.6))):
        tube(S, p, q, 0.75, M_BAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=4)
    n = max(2, int(round((b - a) * T / 3.4)))
    for k in range(1, n + 1):
        t = a + (b - a) * k / (n + 1)
        tube(S, P(t, z0), P(t, z1), 0.42, M_BAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=3)
    al = P(b, z0) - P(a, z0)
    obox(S, P(a, z0 - 0.9, -0.02) - al / np.linalg.norm(al) * 0.8, al + al / np.linalg.norm(al) * 1.6, out * 1.6, np.array([0, 0, 0.8]), M_PLANK)


def walls(S, rng):
    e = 0.004
    holes = [(d0, d1, ZH, DZ) for (d0, d1) in DOORS] + [(c0, c1, WZ[0], WZ[1]) for (c0, c1) in CWIN]
    holed(S, U0, U1, holes, lambda a, b, z0, z1: wall_u(S, a, b, z0, z1, V1))
    wall_u(S, U0, U1, ZH, ZW, V0)                                                       # back wall (seen from inside)
    holed(S, V0, V1, [(r0, r1, WZ[0], WZ[1]) for (r0, r1) in RWINS], lambda a, b, z0, z1: wall_v(S, a, b, z0, z1, U1))
    wall_v(S, V0, V1, ZH, ZW, U0)
    # inner partitions between the gian and the chái (seen through the doors), and the walls' tre frame
    for u in G:
        wall_v(S, V0, V1 - 0.02, ZH, ZW, u)
        top_v(S, V0, V1 - 0.02, u)                                                     # the vách ngăn go on up to the roof
    for u in (U0,) + G + (U1,):
        for v in ((V0, V1) if u in (U0, U1) else (V0,)):                               # front gian lines: the columns mark them
            bam(S, rng, W3(u, v, ZH - 0.5), W3(u, v, ZW + 1.0), 1.3, nl=12)
    bam(S, rng, W3(U1, 1.11, ZH - 0.5), W3(U1, 1.11, ZW), 1.1, nl=10)                 # mid post between the end windows
    for v in (V0, V1):
        bam(S, rng, W3(U0 - 0.05, v, ZW), W3(U1 + 0.05, v, ZW), 1.3, nl=20)
    for u in (U0, U1):
        bam(S, rng, W3(u, V0 - 0.05, ZW - 0.9), W3(u, V1 + 0.05, ZW - 0.9), 1.15, nl=14)
    for z in (ZH + 2.0, ZH + 33.0, ZH + 44.0):                                        # nẹp tre across the vách
        cuts = [U0] + sorted(x for d in (DOORS if z < DZ else ()) for x in d) + [U1]
        for k in range(0, len(cuts), 2):
            bam(S, rng, W3(cuts[k], V1 + e * 3, z), W3(cuts[k + 1], V1 + e * 3, z), 0.55, nl=10, mat=M_OLDBAMBOO)
        bam(S, rng, W3(U1 + e * 3, V0, z), W3(U1 + e * 3, V1, z), 0.55, nl=12, mat=M_OLDBAMBOO)
    # the doors: frames, lintels, phên leaves swung in (both in the middle gian, one in each side gian)
    for i, (d0, d1) in enumerate(DOORS):
        for u in (d0, d1):
            bam(S, rng, W3(u, V1 + e, ZH), W3(u, V1 + e, DZ + 0.6), 0.85, nl=6)
        bam(S, rng, W3(d0 - 0.03, V1 + e, DZ), W3(d1 + 0.03, V1 + e, DZ), 0.85, nl=6)
        box(S, W3(d0 - 0.02, V1 - 0.03, ZH), W3(d1 + 0.02, V1 + 0.03, ZH + 0.9), M_WOOD, prm=(0.4, 0, 0))   # ngạch cửa
        leaves = ((d0, 1, (d1 - d0) / 2), (d1, -1, (d1 - d0) / 2)) if i == 0 else ((d0, 1, d1 - d0),)
        for (u, s, wd) in leaves:
            w = wd * T * 0.95; ang = math.radians(166 if i == 0 else 150)   # folded back inside, out of the view
            A = np.array([s * w * math.cos(ang), -w * math.sin(ang), 0.0])
            o = W3(u, V1 - 0.02, ZH + 1.0)
            obox(S, o, A, np.array([0, 0, DZ - ZH - 1.8]), np.array([0, 0.4, 0]), M_WEAVE_F)
            for f in (0.0, 1.0):
                tube(S, o + A * f, o + A * f + np.array([0, 0, DZ - ZH - 1.8]), 0.45, M_BAMBOO, prm=(0.2, 0.3, 0), nr=6, nl=4)
            for zz in (2.0, (DZ - ZH) * 0.5, DZ - ZH - 3.0):
                tube(S, o + np.array([0, 0, zz]), o + A + np.array([0, 0, zz]), 0.4, M_BAMBOO, prm=(0.6, 0.3, 0), nr=5, nl=4)
    for (c0, c1) in CWIN:
        window(S, rng, c0, c1, WZ[0], WZ[1], 'u')
    for (r0, r1) in RWINS:
        window(S, rng, r0, r1, WZ[0], WZ[1], 'v')
    c = W3(U1 + 0.03, 1.11, ZH + 21.0)                                                 # a nón lá on the mid post
    SP.cone(S, c + np.array([0.3, 0, 0]), (1, 0, 0), 5.2, 3.6, SP.M_HAT, na=32, nu=8)
    tube(S, c + np.array([0, 0, 5.4]), c + np.array([1.2, 0, 6.6]), 0.3, M_WOOD, nr=5, nl=2)

# ---------------------------------------------------------------- the hip roof
def tslope(S, rng, e, su, n_out, LB, ax, Lu, c0, c1, th=2.4, course=3.3):
    """one roof slope from eave e up along su, cut to a trapezoid (or a triangle) by the hips: at height b the slope runs
    from c0*b/LB to Lu - c1*b/LB along ax; underlay slab + courses of nipa leaflets (kho slope(), clipped)"""
    def lo(b): return c0 * np.clip(b, 0, LB) / LB
    def hi(b): return Lu - c1 * np.clip(b, 0, LB) / LB
    def Fu(U, V):
        b = V * LB; x = lo(b) + U * (hi(b) - lo(b))
        return e[None, None] + ax[None, None] * x[..., None] + su[None, None] * b[..., None] - n_out[None, None] * th
    S.grid(Fu, 12, 10, M_THEND, (0, 0, 0), 0.0)
    nC = int(LB / course) + 2
    for i in range(nC):
        b0 = i * course * rng.uniform(0.96, 1.04) - 1.2
        bm = b0 + course * 1.0
        xl, xh = lo(bm), hi(bm)
        if xh - xl < 0.6: continue
        a = xl - 1.0 - rng.uniform(0, 0.6)
        while a < xh + 0.6:
            w = rng.uniform(1.0, 1.6); Lf = course * rng.uniform(1.9, 2.3); tip = b0 - rng.uniform(0.0, 0.9) - (0.8 if i == 0 else 0)
            sag = 0.9 * math.sin(math.pi * min(1, max(0, (a - xl) / max(xh - xl, 1)))) * (1 - max(0, b0) / LB)
            tip -= sag
            tone = rng.integers(5); seed = rng.random(); lift = 1.45 + rng.uniform(-0.25, 0.25); sk = rng.uniform(-0.25, 0.25)
            tq = rng.uniform(0.62, 0.9)
            def F(U, V, aa=a, w=w, Lf=Lf, tip=tip, lift=lift, sk=sk, tq=tq):
                q = U / Lf
                width = w * 0.5 * np.where(q < tq, 1.0, np.clip((1 - q) / (1 - tq), 0, 1) ** 0.8)
                bb = np.minimum(tip + Lf * (1 - q), LB - 0.4)
                x = aa + w * 0.5 + V * width + sk * q
                nn = lift * q + 0.1 + 0.18 * (1 - V ** 2)
                return e[None, None] + ax[None, None] * x[..., None] + su[None, None] * bb[..., None] + n_out[None, None] * nn[..., None]
            S.grid(F, 6, 3, M_LEAF, (tone, Lf, seed), 0.0, uvr=((0, Lf), (-1, 1)))
            a += w * rng.uniform(0.62, 0.8)


def face(e, apex_foot, ax):
    up = apex_foot - e; LB = np.linalg.norm(up); su = up / LB
    n = nv(np.cross(ax, su))
    if n[2] < 0: n = -n
    return su, n, LB


def roll(S, rng, p0, p1, R=1.5):
    """thatch roll over a hip: leaves folded over it one beside the next (like the ridge), one rattan tie"""
    d = p1 - p0; L = np.linalg.norm(d); dn = d / L
    side = nv(np.cross(dn, UP)); upn = nv(np.cross(side, dn))
    def F(U, V):
        th = V * math.pi
        return (p0[None, None] + dn[None, None] * U[..., None] + side[None, None] * (np.cos(th) * R * 1.1)[..., None]
                + upn[None, None] * (np.sin(th) * R * 0.9)[..., None])
    S.grid(F, 40, 9, M_THEND, (0, 0, 0), 0.0, uvr=((0, L), (0, 1)))
    x = 0.0
    while x < L - 0.8:
        w = rng.uniform(1.0, 1.5); tone = rng.integers(5); seed = rng.random(); arc = math.pi * R * 1.1
        def Fs(U, V, x=x, w=w):
            th = -0.35 + U / arc * (math.pi + 0.7); rr = R * 1.05 + 0.15 * (1 - V ** 2)
            return (p0[None, None] + dn[None, None] * (x + V * w * 0.5)[..., None] + side[None, None] * (np.cos(th) * rr * 1.12)[..., None]
                    + upn[None, None] * (np.sin(th) * rr - 0.8 * np.clip(np.abs(th - math.pi / 2) - math.pi / 2, 0, None))[..., None])
        S.grid(Fs, 14, 3, M_RIDGE, (tone, arc, seed), 0.0, uvr=((0, arc), (-1, 1)))
        x += w * rng.uniform(0.7, 0.9)
    for f in (0.45,):
        c = p0 + d * (f + rng.uniform(-0.04, 0.04))
        pts = [c + side * math.cos(a) * (R * 1.2 + 0.4) + upn * math.sin(a) * (R + 0.7) for a in np.linspace(0.05, math.pi - 0.05, 9)]
        for i in range(8): tube(S, pts[i], pts[i + 1], 0.26, M_RATTAN, nr=5, nl=2)


def roof(S, rng):
    X = np.array([1.0, 0, 0]); Y = np.array([0, 1.0, 0])
    Lu = (EU1 - EU0) * T; Lv = (EV - BV) * T
    # front and back: trapezoids from the eaves up to the ridge (RA..RB)
    e = W3(EU0, EV, EZ); su, n, LB = face(e, W3(EU0, RV, RZ), X)
    tslope(S, rng, e, su, n, LB, X, Lu, (RA - EU0) * T, (EU1 - RB) * T)
    fr_front = (e, su, n, LB)
    e = W3(EU0, BV, EZ); su, n, LB = face(e, W3(EU0, RV, RZ), X)
    tslope(S, rng, e, su, n, LB, X, Lu, (RA - EU0) * T, (EU1 - RB) * T)
    # the two chái: triangles from the end eaves up to the ridge ends
    for (eu, ru) in ((EU1, RB), (EU0, RA)):
        e = W3(eu, BV, EZ)
        up = W3(ru, RV, RZ) - W3(eu, RV, EZ); LB = np.linalg.norm(up); su = up / LB
        n = nv(np.cross(Y, su)); n = -n if n[2] < 0 else n
        tslope(S, rng, e, su, n, LB, Y, Lv, (RV - BV) * T, (EV - RV) * T)
    # two battens across the front slope (old grey bamboo), a pole clamping the front eave
    e, su, n, LB = fr_front
    for fr in (0.4, 0.74):
        b = LB * fr; x0 = (RA - EU0) * T * fr + 1.5; x1 = Lu - (EU1 - RB) * T * fr - 1.5
        p0 = e + su * b + n * 2.1
        tube(S, p0 + X * x0, p0 + X * x1, K.BATTEN_R, M_OLDBAMBOO, prm=(rng.random(), 0.5, 0), nr=8, nl=14)
    p0 = e + su * 1.0 + n * 1.8
    tube(S, p0 + X * 1.0, p0 + X * (Lu - 1.0), 0.8, M_OLDBAMBOO, prm=(0.4, 0.3, 0), nr=8, nl=20)
    # rolls over the 4 hips, the ridge roll between RA and RB
    for (ru, eu) in ((RA, EU0), (RB, EU1)):
        for ev in (BV, EV):
            p_top = W3(ru, RV, RZ + 0.6); p_eave = W3(eu, ev, EZ + 0.4)
            roll(S, rng, p_top, p_eave + (p_top - p_eave) * 0.03)
    ridge(S, rng)


def ridge(S, rng):
    """the ridge roll (kho roof() ridge) from RA to RB"""
    R = K.RIDGE_R; x0 = RA * T - 1.0; Lr = (RB - RA) * T + 2.0
    def Fr(U, V):
        th = V * math.pi
        return np.stack([x0 + U, RV * T + np.cos(th) * R, RZ + 0.6 + np.sin(th) * R * 0.92], -1)
    S.grid(Fr, 40, 9, M_THEND, (0, 0, 0), 0.0, uvr=((0, Lr), (0, 1)))
    x = x0 - 0.4; A0, A1 = -0.55, math.pi + 0.55; arc = (A1 - A0) * R * 1.05
    while x < x0 + Lr + 0.4:
        w = rng.uniform(1.0, 1.5); lift = rng.uniform(0.0, 0.25); lean = rng.uniform(-0.45, 0.45); tone = rng.integers(5); seed = rng.random()
        t0, t1 = rng.uniform(1.4, 2.8), rng.uniform(1.4, 2.8)
        def Fs(U, V, x=x, w=w, lift=lift, lean=lean, t0=t0, t1=t1):
            th = A0 + U / arc * (A1 - A0)
            tp = np.clip(np.minimum(U / t0, (arc - U) / t1), 0, 1) ** 0.7
            over = np.clip(np.abs(th - math.pi / 2) - math.pi / 2, 0, None)
            rr = R * 1.04 + lift + 0.15 * (1 - V ** 2)
            y = RV * T + np.cos(th) * rr * 1.08 * (1 + 0.5 * over)
            z = RZ + 0.6 + np.sin(th) * rr - over * 2.2
            return np.stack([x + V * w * 0.55 * tp + lean * np.sin(th), y, z], -1)
        S.grid(Fs, 18, 3, M_RIDGE, (tone, arc, seed), 0.0, uvr=((0, arc), (-1, 1)))
        x += w * rng.uniform(0.7, 0.9)
    zp = RZ + 0.6 + R * 1.04 + 0.45
    tube(S, (x0 - 0.5, RV * T, zp), (x0 + Lr + 0.5, RV * T, zp - 0.2), K.POLE_R, M_OLDBAMBOO, prm=(0.4, 0.3, 0), nr=8, nl=16)
    for xl in (x0 + Lr * 0.33, x0 + Lr * 0.67):
        for dx in (0.0, 0.75):
            pts = [np.array([xl + dx, RV * T + math.cos(a) * (R * 1.12 + 0.5), RZ + 0.6 + math.sin(a) * (R * 1.06 + 0.6)]) for a in np.linspace(0.05, math.pi - 0.05, 11)]
            for i in range(10): tube(S, pts[i], pts[i + 1], K.TIE_R, M_RATTAN, nr=5, nl=2)


# ---------------------------------------------------------------- platform, columns, inside, yard
def platform(S, rng):
    rrect_top(S, 0.06, 2.94, 0.06, 2.94, 0.06, ZF, M_FLOOR)                           # the swept yard
    extrude(S, rrect(0.06, 2.94, 0.06, 2.94, 0.06), 0.0, ZF, M_EARTHSIDE, flare=0.6)
    rrect_top(S, 0.1, 2.9, 0.1, 2.42, 0.04, ZH, M_FLOOR, prm=(0.5, 0, 0))              # nền đất đắp
    extrude(S, rrect(0.1, 2.9, 0.1, 2.42, 0.04), ZF - 0.1, ZH, M_EARTHSIDE, flare=0.25)
    bam(S, rng, W3(0.1, 2.43, ZH - 0.9), W3(2.9, 2.43, ZH - 0.9), 0.7, nl=22, mat=M_OLDBAMBOO)          # a tre edge along the front
    bam(S, rng, W3(2.91, 0.1, ZH - 0.9), W3(2.91, 2.43, ZH - 0.9), 0.7, nl=20, mat=M_OLDBAMBOO)
    zs = (ZF + ZH) / 2                                                                 # a packed-earth step, half way up
    rrect_top(S, 1.28, 1.70, 2.40, 2.58, 0.05, zs, M_FLOOR, prm=(0.5, 0, 0))
    extrude(S, rrect(1.28, 1.70, 2.40, 2.58, 0.05), ZF - 0.1, zs, M_EARTHSIDE, flare=0.2)


def columns(S, rng):
    """4 tràm columns on đá tảng at the gian lines, a beam on them under the eave"""
    zt = EZ - 1.2
    for u in G:
        c = W3(u, PV, ZH - 0.4)
        lathe(S, c, [(0, 3.0), (0.8, 3.0), (1.6, 2.5), (1.9, 0.0)], M_STONE, na=16)
        post(S, rng, u, PV, ZH + 1.6, zt - 0.6)
    bam(S, rng, W3(G[0] - 0.1, PV, zt - 0.4), W3(G[3] + 0.1, PV, zt - 0.4), 1.25, nl=20)
    for u in G:                                                                        # ties beam -> wall plate
        bam(S, rng, W3(u, PV, zt - 0.4), W3(u, V1, ZW - 1.0), 0.8, nl=4)


def altar(S, rng):
    """bàn thờ in the middle gian, just inside the door: a tre table with a red cloth front, lư hương, two chân đèn,
    an đèn dầu, a bình bông of yellow flowers, a mâm of fruit"""
    u0, u1, v0, v1, zt = 1.22, 1.58, 1.70, 1.90, ZH + 13.0   # left of centre: seen through the door at this depth
    for (u, v) in ((u0 + 0.02, v0 + 0.02), (u1 - 0.02, v0 + 0.02), (u0 + 0.02, v1 - 0.02), (u1 - 0.02, v1 - 0.02)):
        bam(S, rng, W3(u, v, ZH), W3(u, v, zt - 0.4), 0.7, nl=4)
    box(S, W3(u0, v0, zt - 0.8), W3(u1, v1, zt), M_WOOD, prm=(0.7, 0, 0))
    plane(S, W3(u0 + 0.02, v1 + 0.004, zt - 0.4), W3(u1 - 0.02, 0, 0) - W3(u0 + 0.02, 0, 0), np.array([0, 0, -7.0]), 8, 4, M_CLOTH)
    c = W3((u0 + u1) / 2, (v0 + v1) / 2, zt)
    lathe(S, c, [(0, 1.4), (0.6, 2.0), (2.0, 2.2), (2.6, 2.0)], M_INCENSE, na=18)        # lư hương + nhang
    for k in range(3):
        p = c + np.array([(k - 1) * 0.5, 0, 2.4]); tube(S, p, p + np.array([(k - 1) * 0.3, 0.1, 4.2]), 0.12, M_CLOTH, nr=3, nl=2)
    for s in (-1, 1):                                                                 # chân đèn
        p = c + np.array([s * 4.6, -1.0, 0])
        lathe(S, p, [(0, 1.2), (0.5, 0.9), (1.0, 0.35), (4.0, 0.35), (4.4, 0.9), (4.8, 0.7)], M_INCENSE, na=14)
    p = c + np.array([-3.0, 2.2, 0])                                                  # bình bông
    lathe(S, p, [(0, 0.9), (1.2, 1.3), (2.6, 0.7), (3.4, 0.6), (3.8, 0.9)], M_GLAZE, na=14)
    for k in range(7):
        a = k * 0.9; r_ = 0.6 + 0.9 * (k % 3) / 2
        q = p + np.array([r_ * math.cos(a), r_ * math.sin(a), 6.0 + (k % 2) * 1.4])
        tube(S, p + np.array([0, 0, 3.4]), q, 0.14, M_LEAFG, nr=3, nl=2)
        ell(S, q, 0.75, 0.75, 0.6, M_FLOWER, nu=5, nvv=7)
    p = c + np.array([3.2, 2.4, 0])                                                   # mâm trái cây
    disc(S, p + np.array([0, 0, 0.3]), (0, 0, 1), 2.4, M_TIN, nr=2, na=18, dome=0.05)
    for k, (dx, dy, dz) in enumerate(((-0.8, 0.0, 1.2), (0.8, 0.2, 1.2), (0.0, -0.8, 1.2), (0.0, 0.5, 2.3))):
        ell(S, p + np.array([dx, dy, dz]), 1.0, 1.0, 0.95, M_ORANGE if k % 2 else M_REDFRUIT, nu=7, nvv=9)
    oillamp(S, W3(*OIL))


def inside(S, rng):
    altar(S, rng)
    # left gian: bộ ván tre with a chiếu, behind its door
    zb = ZH + 9.0
    for (u, v) in ((0.6, 1.42), (1.06, 1.42), (0.6, 1.9), (1.06, 1.9)):
        bam(S, rng, W3(u, v, ZH), W3(u, v, zb - 0.6), 0.7, nl=4)
    for i in range(14):
        v = 1.40 + 0.52 * (i + 0.5) / 14
        bam(S, rng, W3(0.58, v, zb - 0.5), W3(1.08, v, zb - 0.5), 0.62, nl=8)
    plane(S, W3(0.62, 1.44, zb + 0.25), W3(1.04, 0, 0) - W3(0.62, 0, 0), W3(0, 1.88, 0) - W3(0, 1.44, 0), 12, 10, M_CHIEU)
    # right gian: lu gạo with a lid, a bao lúa
    c = W3(2.06, 1.72, ZH)
    lathe(S, c, [(0, 3.6), (1.5, 5.2), (5, 6.3), (9, 6.0), (12, 4.4), (13, 3.9), (13.5, 4.1)], M_GLAZE)
    disc(S, c + np.array([0, 0, 13.4]), (0, 0, 1), 4.1, M_LID, nr=3, na=20, dome=0.2)
    c = W3(2.3, 1.8, ZH)
    lathe(S, c, [(0, 2.8), (0.6, 3.4), (4.4, 3.6), (6.4, 3.1), (7.0, 2.6)], M_JUTE, prm=(0.3, 0, 0), na=24)
    disc(S, c + np.array([0, 0, 6.8]), (0, 0, 1), 2.7, M_GRAIN, nr=3, na=18, dome=0.25)


def chai_inside(S, rng):
    """what the big windows look into: a chạn tre with bowls and hũ in the right chái, a khạp; a lu in the left chái"""
    v0, v1 = 0.36, 0.86
    for (v, du) in ((v0, 0.0), (v1, 0.0), (v0, 0.16), (v1, 0.16)):
        bam(S, rng, W3(2.53 + du, v, ZH), W3(2.53 + du, v, ZH + 30.0), 0.6, nl=6)
    for z in (ZH + 9.0, ZH + 18.0, ZH + 27.0):
        box(S, W3(2.52, v0, z), W3(2.70, v1, z + 0.7), M_PLANK)
    for k in range(5):
        v = v0 + 0.06 + k * 0.1
        lathe(S, W3(2.61, v, ZH + 18.7), [(0, 0.9), (1.4, 1.8), (1.6, 1.9)], K.M_SU, na=12)
        if k % 2 == 0:
            lathe(S, W3(2.61, v + 0.03, ZH + 9.7), [(0, 1.4), (2.0, 2.0), (4.6, 2.2), (5.6, 1.6), (6.0, 1.7)], M_GLAZE, na=12)
    c = W3(2.62, 1.52, ZH)
    lathe(S, c, [(0, 3.4), (1.5, 4.8), (5, 5.6), (8, 5.2), (10, 3.8), (10.6, 3.6)], M_GLAZE)
    disc(S, c + np.array([0, 0, 10.5]), (0, 0, 1), 3.7, M_LID, nr=3, na=20, dome=0.2)
    c = W3(0.34, 1.62, ZH)
    lathe(S, c, [(0, 3.4), (1.5, 4.8), (5, 5.6), (8, 5.2), (10, 3.8), (10.6, 3.6)], M_GLAZE)


def yard(S, rng):
    # bàn thiên on its tre pole at the left of the yard
    c = W3(0.42, 2.72, ZF); h = 22.0
    bam(S, rng, c, c + np.array([0, 0, h]), 0.9, nl=8)
    box(S, c + np.array([-3.4, -3.4, h]), c + np.array([3.4, 3.4, h + 0.8]), M_PLANK)
    for sg in (-1, 1):
        tube(S, c + np.array([0, 0, h - 6.0]), c + np.array([sg * 3.0, 0, h - 0.1]), 0.4, M_BAMBOO, nr=5, nl=3)
    lathe(S, c + np.array([0, 0, h + 0.8]), [(0, 1.0), (0.5, 1.5), (1.6, 1.6), (2.0, 1.4)], M_INCENSE, na=14)
    for k in range(3):
        p = c + np.array([(k - 1) * 0.4, 0, h + 2.6]); tube(S, p, p + np.array([(k - 1) * 0.25, 0, 3.8]), 0.12, M_CLOTH, nr=3, nl=2)
    lathe(S, c + np.array([2.2, 1.6, h + 0.8]), [(0, 0.5), (1.4, 0.7)], K.M_SU, na=10)
    # lu nước with a board and a gáo dừa, on the hàng ba by the right chái
    c = W3(2.74, 2.25, ZH); k_ = 0.85
    lathe(S, c, [(z * k_, r * k_) for z, r in [(0, 3.6), (1.5, 5.2), (5, 6.3), (9, 6.0), (12, 4.4), (13, 3.9), (13.5, 4.1)]], M_GLAZE)
    disc(S, c + np.array([0, 0, 12.0 * k_]), (0, 0, 1), 3.7 * k_, M_WATER, nr=3, na=20)
    box(S, c + np.array([-4.0, -0.6, 13.5 * k_]), c + np.array([4.0, 0.6, 13.5 * k_ + 0.5]), M_PLANK)
    g = c + np.array([1.6, 0.0, 13.5 * k_ + 0.5])
    lathe(S, g, [(0, 0.0), (0.4, 1.3), (1.4, 1.8), (1.6, 1.85)], M_COCO, na=16)
    tube(S, g + np.array([1.6, 0, 1.3]), g + np.array([5.6, 2.4, 2.4]), 0.3, M_BAMBOO, nr=4, nl=3)
    # chổi tre leaning on the left column
    p = W3(G[0] + 0.06, PV + 0.05, ZH + 0.3)
    tube(S, p + np.array([0, 0, 2.0]), p + np.array([-1.0, -0.5, 26.0]), 0.35, M_BAMBOO, nr=5, nl=4)
    for k in range(12):
        a = (k / 11 - 0.5) * 1.2
        tube(S, p + np.array([0, 0, 3.0]), p + np.array([3.0 * math.sin(a), 0.5 * math.cos(a), -0.2]), 0.16, K.M_STRAW, nr=3, nl=2)


def lamp_bits(S, rng):
    c = W3(*LAMP)
    tube(S, W3(LAMP[0], PV, EZ - 2.4), c + np.array([0, 0, 4.4]), 0.16, M_SOOT, nr=4, nl=2)
    biglamp(S, c)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear()
    K.LIGHTS2.append((W3(*LAMP), hexc('#ff9645'), 15.0, 2.8, 'all'))
    K.LIGHTS2.append((W3(*OIL), hexc('#ff9645'), 16.0, 1.5, 'in'))
    for (p, k) in (((0.36, 1.3, ZH + 24.0), 1.6), ((0.84, 1.3, ZH + 24.0), 1.1), ((2.16, 1.3, ZH + 24.0), 1.1),
                   ((2.6, 0.7, ZH + 24.0), 1.8), ((2.6, 1.5, ZH + 24.0), 1.8)):
        K.LIGHTS2.append((W3(*p), hexc('#ff9645'), 13.0, k, 'in'))             # đèn dầu in every room: lit windows at night
    for p in ((2.92, 0.68, ZH + 16.0), (2.92, 1.54, ZH + 16.0), (0.35, 2.12, ZH + 16.0), (2.65, 2.12, ZH + 16.0)):
        K.LIGHTS2.append((W3(*p), hexc('#ff9645'), 9.0, 0.9, 'out'))           # the window light falling out on the nền
    K.GLOWS[:] = [(W3(*LAMP), 0.2, 0.85), (W3(*OIL), 0.06, 0.6)]
    platform(S, rng)
    walls(S, rng)
    roof(S, rng)
    columns(S, rng)
    inside(S, rng)
    chai_inside(S, rng)
    yard(S, rng)
    lamp_bits(S, rng)
    return S, (S.ns, S.ns)


K.build = build


def render(n):
    return K.render(1, n, 'b')


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
        x = 0; Gt = {}; sc = float(K.PXU); H = max(f[0].height for f in frames.values()); BB = K.BB
        sheet = Image.new('RGBA', (sum(frames[k][0].width + 2 for k in keys), H), (0, 0, 0, 0))
        for k in keys:
            im, bb = frames[k]; sheet.paste(im, (x, 0))
            Gt[k] = [x, 0, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
            x += im.width + 2
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, K.SHEET), 'WEBP', quality=92, method=6); json.dump(Gt, open(tab, 'w'))
        print('sheet', sheet.size)
