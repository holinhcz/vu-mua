# Nông Trại Chung: Quán cà phê võng (game id cafe 3x2, mirror cafe2) as a real 3D model, built with the kho kit.
# Redesign (Link 2026-11-08 17:47 "check tiếp quán cafe"): a low chòi lá at the back (the quầy, a bench with a cờ tướng
# game, a lồng chim) and in front a giàn mướp of tre: sparse vine leaves, yellow flowers, hanging mướp, so the võng lưới
# under it show (v1 put one big roof over everything and hid them). Three knotted cord hammocks front to back, low
# bamboo tables with ly cà phê sữa đá; the quầy: bamboo slat counter, phin on glasses, bình thủy, hũ đường, lon sữa,
# bếp than with an ấm nhôm, a wooden thùng đá; a kho-size đèn bão on the giàn's front beam (orange light, den.py glow);
# the CÀ PHÊ VÕNG board stands on the giàn's front beam (the game paints the words).
# Frames: one per variant (hammock colours) and day/night: d0 n0 d1 n1 d2 n2.
#   python3 cafe3d.py prev OUT.png [t] [n]     python3 cafe3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'kho')); sys.path.insert(0, os.path.join(HERE, '..', 'sap'))
import kho3d as K
import sap3d as SP
from kho3d import (W3, T, nv, UP, Scene, X3, hexc, vnoise, smooth, plane, tube, disc, lathe, extrude, rrect, rrect_top, box, obox,
                   mat_flat, MATS, GLOSS, M_EARTHSIDE, M_BAMBOO, M_WEAVE_F, M_WEAVE_R, M_GLAZE, M_LID, M_PLANK,
                   M_RATTAN, M_OLDBAMBOO, M_FLOOR, M_BOWL, M_WOOD, M_BARK, M_GABLE, M_SOOT, M_COCO)
from sap3d import lathe2, bam, ell
from pxr_3d import hash1

K.BB = (-104, -136, 104, 50)
K.OX, K.OY = -16, -40                        # at.P(3,2)
ZF = 2.4                                     # the huts' pad height
ZW = 38.0                                    # the chòi's plates: low, so the quầy shows under the front eave
K.ZW, K.ZF = ZW, ZF
PU = (0.22, 1.08, 1.92, 2.78)                # post rows (chòi and giàn)
PV0, PV1 = 0.16, 0.92                        # the chòi's back and front posts
GV, GZ0, GZ1 = 1.8, 39.4, 41.2               # the giàn: front posts at v GV, top from z GZ0 (on the chòi plate) to GZ1
CU = PU[:3]                                  # v3: the chòi covers only the two left bays; the right bay is all giàn
K.WU0, K.WU1, K.WV0, K.WV1 = 0.1, 2.0, 0.06, 1.0        # under the chòi roof: less sky
K.INSIDE_K = 0.3                             # Link 14:07: every building lit like the đình (was)
K.SUN_DAY = 1.0                              # Link 17:05: own sun, not the sạp's (import sap3d set K.SUN_DAY/WEATHER for every kit)
K.WEATHER = False                            # as published v960 (no grey patches)
K.FOOT = (0.06, 2.94, 0.06, 1.94, 0.08)
K.SHEET = 'cafe.webp'
K.SEED = 6900
K.PATCH = None
K.RU0, K.RU1 = 0.06, 2.08
K.BV, K.BZ = 0.03, 36.6
K.EV, K.EZ = 1.05, 36.6
K.RV, K.RZ = 0.54, 56.0
K.RIDGE_R, K.BATTEN_R, K.POLE_R, K.TIE_R = 1.9, 0.42, 0.4, 0.22   # thin ridge like the chòi lá
K.SMOKE_U = -9.0
SV, SZ0, SZ1 = 0.6, 59.0, 68.0                # sign on the ridge (game text at (SU, SV + .04, 63.5))
SU = 1.07                                    # the chòi's middle
OIL = (2.82, 0.27, 2.4 + 18.0 + 2.6)          # đèn dầu flame on the counter
LAMP = (1.5, 1.79, 31.0)                     # đèn bão hung from the giàn's front beam, over the middle table
CV = 0                                       # variant: which colour goes on which hammock
VCOL = ('#3f8a6e', '#5f86b8', '#c0543e')     # võng lưới: teal green, faded blue, faded red (v2 natural cord vanished on the sand)

# ---------------------------------------------------------------- materials
M_CORD0, M_CORD1, M_CORD2, M_SIGNC, M_THERMOS, M_ALU, M_MILK, M_CAFE, M_ICE, M_LAMPTIN, M_CHAR, M_TERRA, M_CUPW, M_CAP2 = range(180, 194)
M_VLEAF, M_MUOP, M_FLOWER, M_VINE, M_BIRD, M_CORED, M_COBLK, M_CHESS = range(194, 202)


def mat_cord(col):
    c0 = hexc(col)
    def f(uv, prm, pos, nrm):
        base = c0 * (0.86 + 0.16 * prm[:, :1] + 0.06 * np.sin(uv[:, :1] * 6.0 + uv[:, 1:2] * 20))
        return np.clip(base, 0, 1), nrm
    return f


def mat_signc(uv, prm, pos, nrm):
    """a board of dark-stained planks (cream words painted by the game)"""
    a, b = uv[:, 0], uv[:, 1]
    g = 0.9 + 0.08 * vnoise(a * 0.5, b * 5, 2.0) + 0.05 * np.sin(b * 7 + vnoise(a * 0.25, b, 5.0) * 4)
    gap = np.abs(((b / 3.2) % 1) - 0.5) > 0.46
    base = hexc('#5b3a22')[None] * g[:, None]
    base = np.where(gap[:, None], hexc('#33200f')[None], base)
    return np.clip(base, 0, 1), nrm


def mat_thermos(uv, prm, pos, nrm):
    """bình thủy: painted tin body, red with a band of flowers, chrome neck"""
    z = uv[:, 0] if False else pos[:, 2]
    zz = (z - prm[:, 0]) / np.maximum(prm[:, 1], 1e-3)
    base = np.tile(hexc('#c8342a'), (len(z), 1))
    band = (zz > 0.35) & (zz < 0.55)
    ang = np.arctan2(pos[:, 1] - prm[:, 2], pos[:, 0] - prm[:, 2] * 0)
    flw = band & (np.sin(ang * 9) > 0.3)
    base = np.where(band[:, None], hexc('#f0e2c0')[None], base)
    base = np.where(flw[:, None], hexc('#3a8a4a')[None], base)
    base = np.where((zz > 0.86)[:, None], hexc('#c8c8c0')[None], base)
    return np.clip(base, 0, 1), nrm


def mat_milk(uv, prm, pos, nrm):
    """lon sữa đặc: white tin with a red band"""
    zz = (pos[:, 2] - prm[:, 0]) / np.maximum(prm[:, 1], 1e-3)
    base = np.tile(hexc('#ece8dc'), (len(zz), 1))
    base = np.where(((zz > 0.3) & (zz < 0.62))[:, None], hexc('#cc2f28')[None], base)
    return np.clip(base, 0, 1), nrm


def mat_cafe(uv, prm, pos, nrm):
    """ly cà phê sữa đá seen through the glass: caramel coffee, paler at the top"""
    zz = (pos[:, 2] - prm[:, 0]) / np.maximum(prm[:, 1], 1e-3)
    base = hexc('#7a4a26')[None] * (1 - zz[:, None]) + hexc('#c99a62')[None] * zz[:, None]
    return np.clip(base, 0, 1), nrm


VLPAL = ('#456a2c', '#4f7334', '#3d5f27', '#587b38', '#4a6d30', '#8f9a46', '#a98b4c')   # 5 yellowing, 6 dry


def mat_vleaf(uv, prm, pos, nrm):
    """mướp leaf, five lobes: U angle (lobe axes at 0, ±72°, ±144°, the stalk notch at 180°), V 0 centre .. 1 rim"""
    th, V = uv[:, 0], uv[:, 1]; R = prm[:, 1]
    base = np.stack([hexc(c) for c in VLPAL])[np.clip(prm[:, 0].astype(int), 0, len(VLPAL) - 1)]
    base = base * (0.9 + 0.18 * hash1(prm[:, 2], 3.0))[:, None]
    a = ((th + math.pi / 5) % (2 * math.pi / 5)) - math.pi / 5
    vein = np.exp(-(a * V * R / 0.22) ** 2) * (V > 0.06)
    k = (0.84 + 0.2 * V) * (1 + 0.16 * vein) * (0.96 + 0.08 * vnoise(pos[:, 0] * 0.9, pos[:, 1] * 0.9, 7.0))
    alb = base * k[:, None]
    y = smooth(0.8, 1.0, V) * 0.25 * (prm[:, 0] == 5)
    alb = alb * (1 - y[:, None]) + hexc('#b7a24a')[None] * y[:, None]
    return np.clip(alb, 0, 1), nrm


def mat_muop(uv, prm, pos, nrm):
    """mướp hương: pale green with darker stripes down its length; prm = (axis x, axis y, tone)"""
    ang = np.arctan2(pos[:, 1] - prm[:, 1], pos[:, 0] - prm[:, 0])
    st = 0.5 + 0.5 * np.sin(ang * 5 + 0.3 * np.sin(pos[:, 2] * 0.6))
    base = hexc('#7fa44a')[None] * (1 - 0.28 * st[:, None]) * (0.92 + 0.1 * prm[:, 2:3])
    return np.clip(base, 0, 1), nrm


def mat_flower(uv, prm, pos, nrm):
    V = uv[:, 1]
    base = hexc('#f4c418')[None] * (0.92 + 0.12 * V[:, None])
    base = np.where((V < 0.22)[:, None], hexc('#d98a10')[None], base)
    return np.clip(base, 0, 1), nrm


def mat_soil(uv, prm, pos, nrm):
    """dug earth with straw mulch round the mướp roots"""
    n1 = vnoise(pos[:, 0] * 0.8, pos[:, 1] * 0.8, 3.0); n2 = vnoise(pos[:, 0] * 5.0, pos[:, 1] * 5.0, 9.0)
    base = hexc('#7d5d3e')[None] * (0.88 + 0.2 * n1[:, None])
    straw = (n2 > 0.8)[:, None]
    return np.clip(np.where(straw, hexc('#b89a5a')[None] * (0.9 + 0.2 * n1[:, None]), base), 0, 1), nrm


M_SOIL = 202
MATS[M_SOIL] = mat_soil
MATS.update({M_VLEAF: mat_vleaf, M_MUOP: mat_muop, M_FLOWER: mat_flower, M_VINE: mat_flat('#5d6b2c'), M_BIRD: mat_flat('#6b5a3a'),
             M_CORED: mat_flat('#b5352a'), M_COBLK: mat_flat('#2a2a28'), M_CHESS: mat_flat('#e8dcb8')})
GLOSS.update({M_VLEAF: (0.1, 12.0), M_MUOP: (0.3, 25.0)})
MATS.update({M_CORD0: mat_cord(VCOL[0]), M_CORD1: mat_cord(VCOL[1]), M_CORD2: mat_cord(VCOL[2]), M_SIGNC: mat_signc,
             M_THERMOS: mat_thermos, M_ALU: mat_flat('#b4b0a6'), M_MILK: mat_milk, M_CAFE: mat_cafe, M_ICE: mat_flat('#e8eef0'),
             M_LAMPTIN: mat_flat('#7c3826'), M_CHAR: mat_flat('#2a201a'), M_TERRA: mat_flat('#b0603a'), M_CUPW: mat_flat('#efece4'),
             M_CAP2: mat_flat('#2f6a3a')})
GLOSS.update({M_THERMOS: (0.5, 50.0), M_ALU: (0.5, 40.0), M_MILK: (0.4, 40.0), M_CAFE: (0.6, 60.0), M_ICE: (0.6, 60.0),
              M_LAMPTIN: (0.3, 30.0), M_CUPW: (0.4, 40.0)})
K.NIGHT_EMIT = {}


# ---------------------------------------------------------------- helpers
def post(S, rng, u, v, z1, r=1.6):
    tube(S, W3(u, v, -0.3), W3(u, v, z1), r, M_BARK, prm=(rng.random(), 0, 0), nr=12, nl=14, taper=0.88)


def zroof(v):
    return np.where(v < K.RV, K.BZ + (v - K.BV) / (K.RV - K.BV) * (K.RZ - K.BZ), K.EZ + (K.EV - v) / (K.EV - K.RV) * (K.RZ - K.EZ))


def gable(S, u, sgn):
    """hanging leaf infill between the tie beam and the roof at an end frame"""
    v0, v1 = PV0 - 0.12, PV1 + 0.12
    def F(U, V):
        v = v0 + U / T; zt = zroof(v) - 2.4
        return np.stack([np.full_like(U, u * T), v * T, ZW + V * np.clip(zt - ZW, 0, None)], -1)
    S.grid(F, 40, 12, M_GABLE, (0, 0, 0), 0.0, uvr=((0, (v1 - v0) * T), (0, 1)), flip=sgn < 0)


def slats(S, rng, u0, u1, v0, v1, z):
    n = max(3, int(round((v1 - v0) * T / 1.25)))
    for i in range(n):
        v = v0 + (v1 - v0) * (i + 0.5) / n
        bam(S, rng, W3(u0, v, z - 0.55), W3(u1, v, z - 0.55 + rng.uniform(-0.08, 0.08)), 0.6, nl=10)
    for u in (u0 + 0.03, (u0 + u1) / 2, u1 - 0.03):
        tube(S, W3(u, v0 - 0.01, z + 0.05), W3(u, v1 + 0.01, z + 0.05), 0.2, M_RATTAN, nr=4, nl=2)


def lamp(S, c):
    """đèn bão, kho size, rust-red tin like the quán cơm's; c = flame centre"""
    lb = c - np.array([0, 0, 2.6])
    lathe(S, lb, [(0, 1.5), (0.3, 1.7), (1.2, 1.6), (1.5, 0.9)], M_LAMPTIN)
    lathe(S, lb + np.array([0, 0, 1.5]), [(0, 0.9), (0.8, 1.35), (2.0, 1.45), (3.2, 1.2), (3.9, 0.8)], K.M_LAMPGLASS)
    lathe(S, lb + np.array([0, 0, 5.3]), [(0, 1.2), (0.6, 1.25), (1.2, 0.6), (1.8, 0.3)], M_LAMPTIN)
    for sg in (-1, 1):
        tube(S, lb + np.array([1.55 * sg, 0, 0.6]), lb + np.array([1.2 * sg, 0, 6.6]), 0.16, M_SOOT, nr=4, nl=2)
    ell(S, c, 0.35, 0.35, 0.8, K.M_FLAME, nu=6, nvv=8)


def vong(S, rng, p0, p1, mat, sag=17.0):
    """võng lưới: a knotted cord net hammock slung between two posts (the nhà tranh's, Link 07:34: never striped nylon)"""
    L = np.linalg.norm(p1 - p0); d = (p1 - p0) / L
    side = nv(np.cross(UP, d))
    def P(q, V):
        s = sag * np.sin(math.pi * q) ** 0.85
        w = 0.15 + 3.1 * smooth(0.05, 0.32, q) * smooth(0.95, 0.68, q)
        curl = 1.7 * V ** 2 * w / 3.25
        return p0 + d * (q * L) + side * (V * w) + UP * (-s + curl)
    def cord(qs, Vs, r):
        pts = [P(q, v) for q, v in zip(qs, Vs)]
        for a, b in zip(pts[:-1], pts[1:]): tube(S, a, b, r, mat, prm=(rng.random(), 0, 0), nr=5, nl=2)
    qs = np.linspace(0.0, 1.0, 64)
    n, Kk = 6, 4.0
    tri = lambda x: 2 * np.abs(2 * (x - np.floor(x)) - 1) - 1
    for i in range(n):
        cord(qs, tri(qs * Kk + i / n), 0.2)
        cord(qs, tri(-qs * Kk + i / n + 0.5 / n), 0.2)
    for e in (-1, 1): cord(qs, np.full_like(qs, e), 0.32)
    for p in (p0, p1):                                                # rope gathered and tied round the post
        tube(S, p + np.array([0, 0, 0.9]), p - np.array([0, 0, 0.7]), 1.8, mat, nr=8, nl=2)


def glass(S, c, full=True):
    """ly cà phê sữa đá: a tall glass, coffee and ice, a spoon"""
    h = 5.8                                                                           # v3: bigger, so they read in the game
    lathe(S, c, [(0, 1.3), (0.4, 1.38), (h, 1.72)], M_CAFE, prm=(c[2], h, 0), na=16)
    if full:
        for k in range(3):
            ell(S, c + np.array([0.55 * math.cos(k * 2.1), 0.55 * math.sin(k * 2.1), h - 0.1]), 0.7, 0.7, 0.45, M_ICE, nu=4, nvv=6)
    tube(S, c + np.array([0.4, 0.3, h - 0.8]), c + np.array([0.95, 0.55, h + 3.0]), 0.16, M_ALU, nr=4, nl=2)


def phin(S, c):
    """phin cà phê on a short glass: tin filter cup with its lid"""
    lathe(S, c, [(0, 0.9), (2.4, 1.05)], M_CAFE, prm=(c[2], 2.4, 0), na=14)
    lathe(S, c + np.array([0, 0, 2.4]), [(0, 1.6), (0.2, 1.6), (0.25, 1.0), (2.0, 1.15), (2.1, 1.2)], M_ALU, na=16)
    lathe(S, c + np.array([0, 0, 4.5]), [(0, 1.25), (0.3, 1.2), (0.6, 0.5), (0.8, 0.0)], M_ALU, na=14)


def table(S, rng, u, v, cups):
    """bàn tre thấp: four bamboo legs, a slat top, glasses and an ấm trà on it"""
    zt = ZF + 9.0; du, dv = 0.13, 0.11
    for (a, b) in ((u - du, v - dv), (u + du, v - dv), (u - du, v + dv), (u + du, v + dv)):
        bam(S, rng, W3(a, b, ZF), W3(a, b, zt - 0.6), 0.55, nl=3)
    for b in (v - dv, v + dv):
        bam(S, rng, W3(u - du - 0.02, b, zt - 1.6), W3(u + du + 0.02, b, zt - 1.6), 0.45, nl=3)
    slats(S, rng, u - du - 0.03, u + du + 0.03, v - dv - 0.03, v + dv + 0.03, zt)
    for k, (du_, dv_) in enumerate(cups):
        glass(S, W3(u + du_, v + dv_, zt + 0.1), full=(k % 2 == 0))
    c = W3(u - 0.06, v - 0.04, zt + 0.1)                                                  # ấm trà đất + a small cup
    lathe(S, c, [(0, 1.2), (0.4, 1.8), (1.6, 2.0), (2.6, 1.6), (3.0, 0.9), (3.2, 1.0)], M_TERRA, na=18)
    lathe(S, c + np.array([0, 0, 3.1]), [(0, 1.05), (0.3, 1.0), (0.8, 0.4), (1.1, 0.0)], M_TERRA, na=14)
    tube(S, c + np.array([1.4, 0.5, 1.4]), c + np.array([2.9, 1.0, 2.8]), 0.32, M_TERRA, nr=5, nl=3, taper=0.6)


def stool(S, rng, c):
    """ghế đẩu tre"""
    top = 8.0; h = 3.4
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        bam(S, rng, c + np.array([sx * h, sy * h, 0.0]), c + np.array([sx * h, sy * h, top - 0.6]), 0.65, nl=3)
    for sy in (-1, 1):
        bam(S, rng, c + np.array([-h - 0.7, sy * h, top - 1.2]), c + np.array([h + 0.7, sy * h, top - 1.2]), 0.5, nl=3)
    for i in range(6):
        y = -h - 0.3 + (2 * h + 0.6) * (i + 0.5) / 6
        bam(S, rng, c + np.array([-h - 0.6, y, top - 0.5]), c + np.array([h + 0.6, y, top - 0.5]), 0.55, nl=3)


# ---------------------------------------------------------------- the shed
def frame(S, rng):
    rrect_top(S, 0.06, 2.94, 0.06, 1.94, 0.06, ZF, M_FLOOR)
    extrude(S, rrect(0.06, 2.94, 0.06, 1.94, 0.06), 0.0, ZF, M_EARTHSIDE, flare=0.6)
    # the chòi lá over the two left bays: four tràm posts at its corners, tre to in the middle (sơ khai: only four of wood)
    for u in CU:
        for v in (PV0, PV1):
            if u in (CU[0], CU[-1]): post(S, rng, u, v, ZW + 1.6)
            else: bam(S, rng, W3(u, v, -0.3), W3(u, v, ZW + 1.4), 1.35, nl=12)
    for v in (PV0, PV1):                                                              # plates along the front and back
        bam(S, rng, W3(CU[0] - 0.08, v, ZW), W3(CU[-1] + 0.08, v, ZW), 1.2, nl=14)
    for u in CU:                                                                      # tie beams front to back
        bam(S, rng, W3(u, PV0 - 0.1, ZW - 0.9), W3(u, PV1 + 0.1, ZW - 0.9), 1.0, nl=8)
    for u in (CU[0], CU[-1]):                                                         # king posts under the ridge at the ends
        bam(S, rng, W3(u, K.RV, ZW - 0.6), W3(u, K.RV, K.RZ - 2.0), 0.8, nl=6)
    gable(S, CU[0] - 0.012, -1); gable(S, CU[-1] + 0.012, 1)
    K.roof(S, rng, 0)


def tie(S, rng, c, r=0.9):
    """a few turns of rattan where two poles cross"""
    for k in range(2):
        a0 = rng.uniform(0, 6.28)
        pts = [c + np.array([r * math.cos(a0 + t), r * math.sin(a0 + t) * 0.5, 0.35 * math.sin(2 * t) + k * 0.3]) for t in np.linspace(0, 2 * math.pi, 9)]
        for p0, p1 in zip(pts[:-1], pts[1:]): tube(S, p0, p1, 0.16, M_RATTAN, nr=3, nl=2)


def zg(v):
    return GZ0 + (min(max(v, PV1), GV) - PV1) / (GV - PV1) * (GZ1 - GZ0)


def gian(S, rng):
    """giàn mướp tied by hand: tre posts along the front, rafters from the chòi's front plate out to the front beam,
    over the right bay it runs back to the rear; crooked thin poles on top, rattan ties at the crossings"""
    J = lambda: np.array([rng.normal(0, 0.6), rng.normal(0, 0.6), rng.normal(0, 0.5)])
    for u in PU:
        bam(S, rng, W3(u, GV, -0.3), W3(u, GV, GZ1 - 0.4) + J() * [1, 1, 0], 1.15, nl=10)
        bam(S, rng, W3(u, PV1 - 0.04, GZ0 - 0.8) + J(), W3(u, GV + 0.06, GZ1 - 0.2) + J(), 0.75, nl=8)  # rafter onto the front beam
    for v in (PV0, PV1):                                                              # the right bay: tre posts at the back
        bam(S, rng, W3(PU[-1], v, -0.3), W3(PU[-1], v, GZ0 - 0.4), 1.15, nl=10)
    for u in (2.35, PU[-1]):
        bam(S, rng, W3(u, PV0 - 0.08, GZ0 - 0.6) + J(), W3(u, PV1 + 0.02, GZ0 - 0.6) + J(), 0.7, nl=8)
    for v in (PV0, PV1):
        bam(S, rng, W3(CU[-1], v, GZ0 - 1.4) + J(), W3(PU[-1] + 0.1, v, GZ0 - 1.4) + J(), 0.85, nl=10)
    bam(S, rng, W3(PU[0] - 0.1, GV, GZ1 - 0.9) + J(), W3(PU[-1] + 0.1, GV, GZ1 - 0.9) + J(), 1.0, nl=16)  # front beam
    XS = []
    for v in (1.12, 1.34, 1.57):                                                      # thin crooked poles across, tied on
        a, b = W3(PU[0] - 0.07, v, zg(v) + 0.5) + J(), W3(PU[-1] + 0.07, v, zg(v) + 0.5) + J()
        mid = (a + b) / 2 + np.array([rng.normal(0, 1.2), rng.normal(0, 1.2), rng.uniform(-0.8, 0.2)])
        bam(S, rng, a, mid, 0.42, nl=8); bam(S, rng, mid, b, 0.42, nl=8)
        XS.append(v)
    for v in (0.38, 0.62):
        bam(S, rng, W3(CU[-1] - 0.05, v, GZ0 + 0.2) + J(), W3(PU[-1] + 0.08, v, GZ0 + 0.2) + J(), 0.4, nl=8)
    for u in (0.65, 1.5, 2.35):
        bam(S, rng, W3(u, PV1 + 0.02, zg(PV1) + 1.0) + J(), W3(u, GV + 0.03, zg(GV) + 1.0) + J(), 0.38, nl=8)
    for u in PU + (0.65, 1.5, 2.35):                                                  # ties where poles cross the rafters
        for v in XS + [GV]:
            if rng.random() < 0.7: tie(S, rng, W3(u, v, zg(v) + 0.7))
    return zg


def vleaf(S, rng, c, n, R, tone=None):
    """one mướp leaf, five shallow lobes and a notch at the stalk, cupped a little; n = which way it faces"""
    n = nv(n); a1 = nv(np.cross(n, np.array([0.31, 0.77, 0.12]) if abs(n[1]) < 0.9 else np.array([1.0, 0, 0])))
    a2 = np.cross(n, a1); r0 = rng.uniform(0, 2 * math.pi)
    a1, a2 = a1 * math.cos(r0) + a2 * math.sin(r0), -a1 * math.sin(r0) + a2 * math.cos(r0)
    tone = rng.integers(0, 5) if tone is None else tone
    cup = rng.uniform(0.15, 0.35); droop = rng.uniform(0.0, 0.3)
    def F(U, V):
        rr = R * (0.86 + 0.14 * np.cos(5 * U) + 0.025 * np.cos(31 * U)) * (1 - 0.3 * np.exp(-((U - math.pi) / 0.32) ** 2))
        x = (np.cos(U) * a1[:, None, None] + np.sin(U) * a2[:, None, None]) * (V * rr)
        lift = (cup * R * V ** 2 - droop * R * (V * np.cos(U)) ** 2)
        return np.moveaxis(c[:, None, None] + x + n[:, None, None] * lift, 0, -1)
    S.grid(F, 31, 5, M_VLEAF, (tone, R, rng.random()), 0.0, uvr=((0, 2 * math.pi), (0, 1)), flip=True)


def flower(S, rng, c, n):
    n = nv(n); a1 = nv(np.cross(n, np.array([0.3, 0.8, 0.1]))); a2 = np.cross(n, a1)
    def F(U, V):
        rr = 1.25 * (0.55 + 0.45 * np.abs(np.cos(2.5 * U)))
        x = (np.cos(U) * a1[:, None, None] + np.sin(U) * a2[:, None, None]) * (V * rr)
        return np.moveaxis(c[:, None, None] + x + n[:, None, None] * (0.35 * V ** 2), 0, -1)
    S.grid(F, 26, 4, M_FLOWER, (0, 0, 0), 0.0, uvr=((0, 2 * math.pi), (0, 1)), flip=True)


def muop(S, rng, top, L):
    """a mướp hanging from the lattice on its stalk"""
    lean = np.array([rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0.0])
    tube(S, top, top - np.array([0, 0, 2.2]) + lean * 0.3, 0.22, M_VINE, nr=4, nl=2)
    b = top - np.array([0, 0, 2.0 + L]) + lean
    prof = [(0, 0.0), (0.4, 0.7), (1.5, 1.15), (L * 0.55, 1.05), (L * 0.85, 0.8), (L, 0.35)]
    lathe(S, b, prof, M_MUOP, prm=(b[0], b[1], rng.random()), na=14)


def vines(S, rng, zg):
    """the mướp: two stems from mulched mounds at the front corners, up the posts, then along the poles; every leaf grows
    from the stem on a stalk, big and small together; thin over the middle bays so the hammocks show through"""
    for u in (PU[0], PU[-1]):
        c = W3(u + (0.07 if u < 1.5 else -0.07), GV + 0.06, ZF)
        pts = [W3(u, GV, 0) + np.array([1.5 * math.cos(z * 0.32), 1.5 * math.sin(z * 0.32), z]) for z in np.linspace(ZF + 1.2, GZ1 + 0.6, 26)]
        for a, b in zip(pts[:-1], pts[1:]): tube(S, a, b, 0.42, M_VINE, nr=5, nl=2)
        for z in np.linspace(ZF + 9, GZ1 - 6, 5):                                       # a few leaves up the post
            a = rng.uniform(0, 2 * math.pi); d = np.array([math.cos(a), math.sin(a), 0.0])
            if d[0] + d[1] < -0.3: d = -d
            p = W3(u, GV, z) + d * 1.5
            tube(S, p, p + d * 1.8 + np.array([0, 0, 0.8]), 0.18, M_VINE, nr=3, nl=2)
            vleaf(S, rng, p + d * 3.6 + np.array([0, 0, 0.4]), d + np.array([0, 0, 0.6]), rng.uniform(2.0, 3.4))
    # stems along the poles; density = leaves per stem point (thick on the front beam and the ends)
    segs = [((PU[0] - 0.05, GV), (PU[-1] + 0.05, GV), 0.8)]
    segs += [((PU[0], PV1 + 0.08), (PU[0], GV), 0.7), ((PU[-1], PV1 + 0.02), (PU[-1], GV), 0.6)]
    segs += [((u, PV1 + 0.08), (u, GV), 0.32) for u in PU[1:-1]]
    segs += [((PU[0] + 0.05, 1.34), (1.0, 1.34), 0.3), ((1.9, 1.12), (2.9, 1.12), 0.3), ((1.1, 1.57), (1.9, 1.57), 0.25)]
    segs += [((PU[-1], PV0 + 0.04), (PU[-1], PV1), 0.2), ((CU[-1] + 0.05, PV0), (2.6, PV0), 0.35)]   # the right bay, kept off the quầy
    segs += [((CU[-1] + 0.05, 0.62), (2.42, 0.62), 0.45), ((2.35, PV0 + 0.04), (2.35, GV), 0.35), ((1.95, GV), (PU[-1] + 0.05, GV), 0.5)]
    for (u0, v0), (u1, v1), dens in segs:
        Ls = math.hypot(u1 - u0, v1 - v0) * T; ph = rng.uniform(0, 6)
        qs = np.linspace(0, 1, max(8, int(Ls / 2.0)))
        pts = [W3(u0 + (u1 - u0) * q, v0 + (v1 - v0) * q, 0) + np.array([0, 0, zg(v0 + (v1 - v0) * q) + 1.1])
               + np.array([0.9 * math.sin(q * Ls / 4.5 + ph), 0.9 * math.cos(q * Ls / 4.5 + ph), 0.5 * math.sin(q * Ls / 3.1)]) for q in qs]
        for p0, p1 in zip(pts[:-1], pts[1:]): tube(S, p0, p1, 0.3, M_VINE, nr=4, nl=2)
        for p in pts:
            if abs(p[0] / T - LAMP[0]) < 0.1 and p[1] / T > GV - 0.15: continue          # keep the lamp clear
            k = dens * rng.uniform(0.3, 1.7)
            for j in range(int(k) + (rng.random() < k - int(k))):
                a = rng.uniform(0, 2 * math.pi); d = np.array([math.cos(a), math.sin(a), 0.0])
                big = rng.random() < 0.7; Rl = rng.uniform(3.0, 4.6) if big else rng.uniform(1.6, 2.4)
                q = p + d * (Rl * 0.9 + 0.6) + np.array([0, 0, rng.uniform(0.3, 1.6)])
                tube(S, p, q - d * Rl * 0.75, 0.16, M_VINE, nr=3, nl=2)                  # leaf stalk from the stem
                vleaf(S, rng, q, np.array([rng.normal(0, 0.35), rng.normal(0, 0.35), 1.0]), Rl)
    # leaves hanging over the front edge, facing out
    for i in range(18):
        u = rng.uniform(PU[0] - 0.05, PU[-1] + 0.05)
        if abs(u - LAMP[0]) < 0.12: continue
        p = W3(u, GV + 0.04, GZ1 + 0.4); q = p + np.array([0.5, 2.6, -rng.uniform(1.0, 2.6)])
        tube(S, p, q + np.array([-0.2, -1.6, 0.9]), 0.16, M_VINE, nr=3, nl=2)
        vleaf(S, rng, q, np.array([0.25, 1.0, 0.35]), rng.uniform(2.0, 3.4))
    for i in range(10):                                                                # yellow flowers on top
        u = rng.uniform(0.15, 2.85); v = rng.choice([GV, 1.12, 1.34, 1.57, PV1 + 0.1])
        flower(S, rng, W3(u, v, zg(v) + 2.8) + np.array([rng.normal(0, 1.5), rng.normal(0, 1.5), 0]), np.array([0.2, 0.3, 1.0]))
    for (u, v, L) in ((0.48, 1.34, 10.0), (1.3, 1.57, 12.0), (1.72, 1.12, 9.0), (2.55, 1.57, 11.5), (2.62, 1.34, 8.0), (2.2, 0.38, 10.5)):
        muop(S, rng, W3(u, v, zg(v) + 0.2), L)


def counter(S, rng):
    """v3 quầy out in the right bay under the giàn, long side facing the right (the customers' side) so it shows: a bamboo
    slat counter, woven skirt, the coffee things on it; behind it the seller's stool, bếp than + ấm nhôm, thùng đá"""
    u0, u1, v0, v1, zt = 2.6, 2.86, 0.24, 0.8, ZF + 18.0
    for (u, v) in ((u0, v0), (u1, v0), (u0, v1), (u1, v1)):
        bam(S, rng, W3(u, v, ZF), W3(u, v, zt - 0.6), 0.7, nl=5)
    for u in (u0, u1):
        bam(S, rng, W3(u, v0 - 0.03, zt - 1.5), W3(u, v1 + 0.03, zt - 1.5), 0.6, nl=6)
    slats(S, rng, u0 - 0.04, u1 + 0.04, v0 - 0.04, v1 + 0.04, zt)
    plane(S, W3(u1 + 0.02, v0, ZF + 1.0), W3(0, v1, 0) - W3(0, v0, 0), np.array([0, 0, zt - ZF - 3.0]), 30, 14, M_WEAVE_R)   # skirt
    bam(S, rng, W3(u1 + 0.03, v0 - 0.02, ZF + 3.0), W3(u1 + 0.03, v1 + 0.02, ZF + 3.0), 0.5, nl=6)
    for v in (0.36, 0.46, 0.56):                                                      # phin dripping on glasses, at the front edge
        phin(S, W3(2.8, v, zt + 0.1))
    c = W3(2.68, 0.7, zt + 0.1); h = 10.0                                             # bình thủy
    lathe(S, c, [(0, 2.0), (0.5, 2.2), (h * 0.8, 2.2), (h * 0.88, 1.5), (h, 1.2)], M_THERMOS, prm=(c[2], h, 0), na=20)
    lathe(S, c + np.array([0, 0, h]), [(0, 1.3), (1.2, 1.3), (1.4, 0.0)], M_CAP2, na=14)
    c = W3(2.8, 0.7, zt + 0.1)                                                        # lon sữa đặc
    lathe(S, c, [(0, 1.3), (2.9, 1.3), (3.0, 0.0)], M_MILK, prm=(c[2], 3.0, 0), na=16)
    c = W3(2.68, 0.31, zt + 0.1)                                                      # hũ đường
    lathe(S, c, [(0, 1.6), (3.4, 1.7), (3.8, 1.3), (4.2, 1.3)], M_CUPW, na=16)
    lathe(S, c + np.array([0, 0, 4.1]), [(0, 1.45), (0.8, 1.45), (0.9, 0.0)], M_LID, na=14)
    for j in range(4):                                                                # glasses stacked upside down
        lathe(S, W3(2.67, 0.46, zt + 0.1 + j * 1.4), [(0, 1.2), (2.6, 0.95)], M_ICE, na=14)
    c = W3(2.25, 0.26, ZF)                                                            # bếp than + ấm nhôm boiling
    lathe(S, c, [(0, 3.4), (0.5, 3.6), (5.6, 3.2), (6.2, 3.5), (6.6, 3.3)], M_TERRA, na=24)
    disc(S, c + np.array([0, 0, 6.5]), (0, 0, 1), 3.0, M_CHAR, nr=3, na=20, dome=0.1)
    k = c + np.array([0, 0, 6.8])
    lathe(S, k, [(0, 2.6), (0.4, 2.9), (2.8, 3.0), (3.6, 2.4), (4.4, 1.2), (4.7, 0.0)], M_ALU, na=22)
    tube(S, k + np.array([2.2, 1.2, 1.6]), k + np.array([4.6, 2.6, 4.2]), 0.4, M_ALU, nr=5, nl=3, taper=0.6)
    for a in (-1, 1):
        tube(S, k + np.array([a * 2.2, 0, 3.6]), k + np.array([0, 0, 7.4]), 0.2, M_SOOT, nr=4, nl=3)
    c = W3(2.08, 0.5, ZF)                                                             # bao than
    lathe(S, c, [(0, 2.8), (0.6, 3.4), (4.4, 3.6), (6.4, 3.1), (7.0, 2.6)], K.M_JUTE, prm=(0.3, 0, 0), na=24)
    disc(S, c + np.array([0, 0, 6.8]), (0, 0, 1), 2.7, M_CHAR, nr=3, na=18, dome=0.25)
    c0, c1 = W3(2.14, 0.66, ZF), W3(2.38, 0.88, ZF + 9.0)                              # thùng đá gỗ
    box(S, c0, c1, M_PLANK, prm=(rng.random(), 0, 0))
    box(S, c0 + np.array([-0.4, -0.4, 9.0]), c1 + np.array([0.4, 0.4, 1.0]), M_PLANK, prm=(rng.random(), 0, 0))
    stool(S, rng, W3(2.45, 0.52, ZF))
    c = W3(*OIL) - np.array([0, 0, 2.2])                                              # đèn dầu on the counter, for the quầy at night
    lathe(S, c, [(0, 1.4), (0.9, 1.5), (1.3, 0.7)], M_GLAZE, na=16)
    lathe(S, c + np.array([0, 0, 1.3]), [(0, 0.6), (0.6, 0.95), (2.0, 1.0), (3.2, 0.6), (3.6, 0.55)], K.M_LAMPGLASS, na=16)
    ell(S, W3(*OIL), 0.25, 0.25, 0.6, K.M_FLAME, nu=6, nvv=8)


def backbench(S, rng):
    """under the chòi: a long băng ghế tre at the back with a cờ tướng game left on it, a lu nước, a lồng chim on the front plate"""
    v0, v1, zs = 0.3, 0.46, ZF + 10.0
    for u in (0.5, 1.1, 1.7):
        for v in (v0, v1): bam(S, rng, W3(u, v, ZF), W3(u, v, zs - 0.6), 0.6, nl=4)
        bam(S, rng, W3(u, v0 - 0.02, zs - 2.4), W3(u, v1 + 0.02, zs - 2.4), 0.45, nl=3)
    slats(S, rng, 0.44, 1.76, v0 - 0.03, v1 + 0.03, zs)
    c = W3(0.18, 0.7, ZF); k_ = 0.75                                                   # lu nước
    lathe(S, c, [(z * k_, r * k_) for z, r in [(0, 3.6), (1.5, 5.2), (5, 6.3), (9, 6.0), (12, 4.4), (13, 3.9), (13.5, 4.1)]], M_GLAZE)
    disc(S, c + np.array([0, 0, 13.4 * k_]), (0, 0, 1), 3.9 * k_, M_LID, nr=3, na=20, dome=0.15)
    ell(S, c + np.array([0, 0, 13.4 * k_ + 0.8]), 1.6, 0.9, 0.5, M_COCO, nu=4, nvv=8)                # gáo dừa on the lid
    c0, c1 = W3(0.9, 0.32, zs + 0.2), W3(1.16, 0.44, zs + 0.9)                       # bàn cờ tướng
    box(S, c0, c1, M_CHESS)
    for k in range(9):
        cu = 0.92 + rng.uniform(0, 0.22); cv = 0.33 + rng.uniform(0, 0.1)
        disc(S, W3(cu, cv, zs + 1.0), (0, 0, 1), 0.75, M_CORED if k % 2 else M_COBLK, nr=2, na=12, dome=0.3)
    c = W3(1.4, 0.38, zs + 0.2)                                                       # ấm trà + cups beside the game
    lathe(S, c, [(0, 1.2), (0.4, 1.8), (1.6, 2.0), (2.6, 1.6), (3.0, 0.9), (3.2, 1.0)], M_TERRA, na=18)
    lathe(S, c + np.array([0, 0, 3.1]), [(0, 1.05), (0.3, 1.0), (0.8, 0.4), (1.1, 0.0)], M_TERRA, na=14)
    for d in ((2.6, 1.0), (2.9, -1.4)):
        lathe(S, c + np.array([d[0], d[1], 0]), [(0, 0.6), (1.3, 0.85)], M_CUPW, na=12)
    # lồng chim: a round bamboo bird cage hung from the front plate between the 2nd and 3rd hammocks
    top = W3(1.5, PV1, ZW - 0.8); c = top - np.array([0, 0, 9.0])
    tube(S, top, c + np.array([0, 0, 1.0]), 0.18, M_SOOT, nr=4, nl=2)
    Rc, H = 3.0, 7.4; base = c - np.array([0, 0, H])
    disc(S, base, (0, 0, 1), Rc + 0.3, M_PLANK, nr=2, na=20)
    lathe(S, base + np.array([0, 0, -0.6]), [(0, Rc + 0.35), (0.7, Rc + 0.35)], M_BAMBOO, prm=(0.4, 0.2, 0), na=20)
    for k in range(18):
        a = k / 18 * 2 * math.pi; e = np.array([math.cos(a), math.sin(a), 0.0])
        tube(S, base + e * Rc, base + e * Rc + np.array([0, 0, H * 0.78]), 0.1, M_BAMBOO, prm=(0.3, 0.2, 0), nr=3, nl=2)
        tube(S, base + e * Rc + np.array([0, 0, H * 0.78]), c + np.array([0, 0, 0.6]), 0.1, M_BAMBOO, prm=(0.3, 0.2, 0), nr=3, nl=3)
    for z in (0.3, 0.78):
        lathe(S, base + np.array([0, 0, H * z - 0.2]), [(0, Rc + 0.08), (0.4, Rc + 0.08)], M_RATTAN, na=20)
    ell(S, base + np.array([0, 0, 3.0]), 0.9, 0.7, 1.0, M_BIRD, nu=5, nvv=8)                    # a chào mào inside
    ell(S, base + np.array([0.6, 0.4, 4.1]), 0.55, 0.5, 0.55, M_COBLK, nu=4, nvv=6)
    tube(S, base + np.array([-0.4, -0.3, 2.9]), base + np.array([-1.4, -1.0, 2.2]), 0.3, M_BIRD, nr=4, nl=2, taper=0.5)
    tube(S, base + np.array([-Rc + 0.2, 0, 2.2]), base + np.array([Rc - 0.2, 0, 2.2]), 0.12, M_BAMBOO, nr=3, nl=2)


def hammocks(S, rng):
    mats = (M_CORD0, M_CORD1, M_CORD2)
    for i, u in enumerate(PU[1:]):
        p0 = W3(u, PV1 + 0.03, 29.0); p1 = W3(u, GV - 0.03, 30.0)
        vong(S, rng, p0, p1, mats[(i + CV) % 3], sag=14.0)
    # tables and stools between them, out under the giàn
    table(S, rng, 1.5, 1.38, ((0.07, 0.05), (0.1, -0.06)))
    table(S, rng, 2.35, 1.42, ((0.08, 0.04), (-0.02, 0.08), (0.11, -0.05)))
    stool(S, rng, W3(1.5, 1.72, ZF))


def sign(S, rng):
    """CÀ PHÊ VÕNG board standing on the chòi's ridge, lashed to two poles (the game paints the words)"""
    for u in (SU - 0.55, SU + 0.55):
        bam(S, rng, W3(u, K.RV + 0.01, K.RZ - 4.0), W3(u, SV - 0.005, SZ1 + 1.2), 0.5, nl=6)
        tube(S, W3(u - 0.03, K.RV + 0.02, K.RZ + 2.4), W3(u + 0.03, K.RV + 0.03, K.RZ + 2.7), 0.75, M_RATTAN, nr=6, nl=2)
    a0, a1 = SU - 0.78, SU + 0.78
    box(S, W3(a0, SV, SZ0), W3(a1, SV + 0.03, SZ1), M_SIGNC)
    for (a, b) in ((W3(a0, SV + 0.035, SZ0), W3(a1, SV + 0.035, SZ0)), (W3(a0, SV + 0.035, SZ1), W3(a1, SV + 0.035, SZ1)),
                   (W3(a0, SV + 0.035, SZ0), W3(a0, SV + 0.035, SZ1)), (W3(a1, SV + 0.035, SZ0), W3(a1, SV + 0.035, SZ1))):
        tube(S, a, b, 0.5, M_BAMBOO, prm=(rng.random(), 0.3, 0), nr=6, nl=4)


def lamp_and_bits(S, rng):
    tube(S, W3(LAMP[0], GV, GZ1 - 1.6), W3(*LAMP) + np.array([0, 0, 4.4]), 0.16, M_SOOT, nr=4, nl=2)
    lamp(S, W3(*LAMP))
    for k in range(5):                                                                # a few fallen mướp leaves, dry
        u = rng.uniform(0.2, 2.8); v = rng.uniform(1.1, 1.9); a = rng.uniform(0, math.pi)
        vleaf(S, rng, W3(u, v, ZF + 0.3), np.array([rng.normal(0, 0.15), rng.normal(0, 0.15), 1.0]), rng.uniform(1.6, 2.2), tone=6)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear()
    K.LIGHTS2.append((W3(*LAMP), hexc('#ff9645'), 16.0, 3.0, 'all'))
    K.LIGHTS2.append((W3(*OIL), hexc('#ff9645'), 9.0, 1.1, 'all'))                # as warm and bright as the nhà tranh's
    K.GLOWS[:] = [(W3(*LAMP), 0.2, 0.85), (W3(*OIL), 0.12, 0.6)]
    frame(S, rng)
    zg = gian(S, rng)
    vines(S, rng, zg)
    counter(S, rng)
    backbench(S, rng)
    hammocks(S, rng)
    sign(S, rng)
    lamp_and_bits(S, rng)
    return S, (S.ns, S.ns)


K.build = build


def render(t, n):
    global CV
    CV = t
    return K.render(1, n, 'b')


if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        t = int(sys.argv[3]) if len(sys.argv) > 3 else 0; n = len(sys.argv) > 4 and sys.argv[4] == 'n'
        render(t, n).save(sys.argv[2])
    elif sys.argv[1] == 'atlas':
        out, tab = sys.argv[2], sys.argv[3]
        frames = {}
        for t in range(3):
            for n in (0, 1):
                im = render(t, bool(n)); bb = im.getbbox(); frames[('n' if n else 'd') + str(t)] = (im.crop(bb), bb)
        keys = ['d0', 'n0', 'd1', 'n1', 'd2', 'n2']
        x = 0; G = {}; sc = float(K.PXU); H = max(f[0].height for f in frames.values()); BB = K.BB
        sheet = Image.new('RGBA', (sum(frames[k][0].width + 2 for k in keys), H), (0, 0, 0, 0))
        for k in keys:
            im, bb = frames[k]; sheet.paste(im, (x, 0))
            G[k] = [x, 0, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
            x += im.width + 2
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, K.SHEET), 'WEBP', quality=92, method=6); json.dump(G, open(tab, 'w'))
        print('sheet', sheet.size)
