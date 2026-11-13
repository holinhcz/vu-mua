# Quán cơm (game id quancom, 3x2, mirror quancom2) as a real 3D model in the kit of the kho/sạp (kho3d.py, sap3d.py helpers).
# Link 2026-11-08 13:10: "tiếp quán cơm đi". Redesigned, not a copy of the old canvas one (Link: never copy the old 100%):
#  - back: a small nhà tranh kitchen, ridge along u, open front (bếp lò đất with two pots and fire, củi, lu nước,
#    a quầy with nồi cơm, mâm cơm and a lồng bàn, chén bát on a shelf), đèn bão under the eave, QUÁN CƠM board on the eave
#  - front: an open earth yard with two tables (.75/2.25, 1.25; the game's seats are moved to match) and bamboo benches at the seats (v .95 / 1.55)
#    so the customers the game seats there sit on real benches; a potted plant (menu board dropped: Link 13:44 'sơ khai').
# The dining yard has no roof on purpose: seated customers (drawn by the game) are never hidden under thatch.
# Frames: 'b' = everything behind the back-seat customers (kitchen hut, yard, back benches), 'f' = tables, front benches, front props.
# Usage: python3 quancom3d.py prev OUT.png b|f|all [n]      python3 quancom3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'kho')); sys.path.insert(0, os.path.join(HERE, '..', 'sap'))
import kho3d as K
import sap3d as SP
from kho3d import (W3, T, nv, UP, Scene, X3, hexc, vnoise, plane, tube, disc, lathe, extrude, rrect, rrect_top, box,
                   mat_flat, MATS, GLOSS, M_EARTHSIDE, M_BAMBOO, M_WEAVE_F, M_WEAVE_R, M_GLAZE, M_POT, M_LID, M_PLANK, M_ROPE,
                   M_RATTAN, M_OLDBAMBOO, M_FLOOR, M_STRAW, M_BOWL, M_HANDLE, M_WOOD, M_BARK, M_TEAPOT, M_GABLE, M_SOOT,
                   M_FIRE, M_EMBER, M_COCO)
from sap3d import lathe2, bam, ell, cone, M_BOTTLE, M_CAP, M_RICE
from sap3d import M_GOLD

K.BB = (-104, -128, 104, 50)
K.OX, K.OY = -16, -40                        # at.P(3,2)
K.WU0, K.WU1, K.WV0, K.WV1 = 0.2, 2.8, 0.18, 0.86      # under the kitchen roof
K.ZW = 44.0
K.ZF = 2.4
K.INSIDE_K = 0.3                             # Link 14:07: every building lit like the đình (was)
K.SUN_DAY = 1.0                              # Link 17:05: own sun, not the sạp's (import sap3d set K.SUN_DAY/WEATHER for every kit)
K.WEATHER = False                            # as published v960 (no grey patches)
K.FOOT = (0.06, 2.94, 0.06, 1.94, 0.08)
K.SHEET = 'quancom.webp'
K.SEED = 6100
K.PATCH = None
K.NIGHT_EMIT = {}
# kitchen roof (kho3d.roof works in roof space: ridge along x = game u at y = RV)
K.RV, K.RZ = 0.47, 55.0                      # vòng 4: was 62, too tall and heavy for the shallow kitchen
K.EV, K.EZ = 0.9, 43.0                      # front eave
K.BV, K.BZ = 0.06, 43.0                    # back eave
K.RU0, K.RU1 = 0.12, 2.88
K.SMOKE_U = 2.4
ZF = 2.4
ZH = 4.0                                     # the kitchen floor: a raised earth platform
ZW = 43.0
LAMP = (1.12, 0.88, 31.0)                    # vòng 4: hangs over the quầy, not in front of the middle post
KU0, KU1, KV0 = 0.2, 2.8, 0.18                # kitchen posts (vòng 5: in from the pad edge)
TU = (0.75, 2.25)                            # table centres, evenly spaced (Link 13:44); patch_quancom moves the game's seats to match
CR = ((2.06, 0.4), (2.42, 0.4))                # the two cà ràng on the bệ bếp
ZB = 8.4                                     # bệ bếp top above the kitchen floor
FIRES = tuple((u, v + 0.15, ZB + 1.6) for (u, v) in CR)
SV = 0.97                                    # sign plane (game text at SV + .04, z 52.5)

# ---------------------------------------------------------------- materials
def mat_signr(uv, prm, pos, nrm):
    a, b = uv[:, 0], uv[:, 1]
    g = 0.9 + 0.08 * vnoise(a * 0.5, b * 5, 2.0) + 0.05 * np.sin(b * 7 + vnoise(a * 0.25, b, 5.0) * 4)
    base = hexc('#b33a28')[None] * g[:, None]                                    # vòng 4: clean painted planks (worn patches read as mud)
    gap = np.abs(((b / 5.0) % 1) - 0.5) > 0.47
    return np.clip(np.where(gap[:, None], hexc('#5e1e12')[None], base), 0, 1), nrm


def mat_chalk(uv, prm, pos, nrm):
    """bảng thực đơn: dark board, chalk lines of dishes (a title line, then rows with a price)"""
    a, b = uv[:, 0], uv[:, 1]                     # a across 0..W, b up 0..H (units)
    W = prm[:, 0]; H = prm[:, 1]
    base = np.tile(hexc('#2f3b33'), (len(a), 1)) * (0.92 + 0.12 * vnoise(a * 0.7, b * 0.7, 3.0))[:, None]
    row = np.floor((H - b) / 2.4); fr = ((H - b) / 2.4) % 1
    L = np.where(row == 0, W * 0.72, W * (0.42 + 0.18 * np.abs(np.sin(row * 2.7))))
    x0 = np.where(row == 0, W * 0.14, W * 0.12)
    line = (row >= 0) & (row <= 4) & (np.abs(fr - 0.5) < np.where(row == 0, 0.2, 0.13)) & (a > x0) & (a < x0 + L)
    price = (row >= 1) & (row <= 4) & (np.abs(fr - 0.5) < 0.13) & (a > W * 0.74) & (a < W * 0.88)
    chalk = (line | price) & (vnoise(a * 3, b * 3, 11.0) > 0.18)
    base = np.where(chalk[:, None], hexc('#e9e6d6')[None], base)
    return np.clip(base, 0, 1), nrm


M_SIGNR, M_CHALK, M_CAKHO, M_RAU, M_EGG, M_THIT, M_PLEAF, M_PFLOW, M_TERRA, M_CLAY = range(130, 140)
M_LEAFD1, M_LEAFD2, M_LEAFD3, M_PATH = range(140, 144)


def mat_path(uv, prm, pos, nrm):
    a, b = uv[:, 0], uv[:, 1]
    edge = np.clip((1 - np.abs(b)) / 0.6, 0, 1)
    base = hexc('#ceb184')[None] * (0.96 + 0.06 * vnoise(a * 0.4, b * 2.0, 5.0))[:, None]
    return np.clip(base, 0, 1), nrm


M_BEP, M_NOI, M_GRASS1, M_GRASS2, M_GRASS3, M_PFLOW2, M_LAMPTIN, M_ALU, M_CARANG, M_ASH = range(144, 154)


def mat_bep(uv, prm, pos, nrm):
    """bếp lò đất: hand-smoothed clay, hairline cracks, soot licking up from each fire mouth, darker at the hot top"""
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    n1 = vnoise(x * 0.3, (y + z) * 0.3, 4.0); n2 = vnoise(x * 1.3, (y + z) * 1.3, 9.0)
    base = hexc('#a9744a')[None] * (0.88 + 0.12 * n1 + 0.05 * n2)[:, None]
    soot = np.zeros_like(x)
    for (u, v, zf) in FIRES:
        dx = (x - u * T) / (2.6 + 0.35 * np.clip(z - ZH - 3.4, 0, None)); dz = z - (ZH + 3.4)
        soot = np.maximum(soot, np.exp(-dx ** 2) * np.clip(1 - np.maximum(dz, 0) / 6.0, 0, 1) * (dz > -3.4))
    soot = np.maximum(soot, 0.6 * K.smooth(ZH + 6.0, ZH + 8.6, z))
    soot = soot * (0.75 + 0.35 * n2)
    crack = np.abs(vnoise(x * 0.5, (y + z) * 0.5, 13.0) - 0.5) < 0.005
    base = base * (1 - 0.72 * np.clip(soot, 0, 1))[:, None]
    base = np.where(crack[:, None], base * 0.86, base)
    return np.clip(base, 0, 1), nrm


def mat_noi(uv, prm, pos, nrm):
    """a pot on the fire: prm0 = foot z, prm1 = height, prm2 = 0 aluminium / 1 clay; soot from the foot fading up"""
    z = pos[:, 2]; t = np.clip((z - prm[:, 0]) / np.maximum(prm[:, 1], 1e-3), 0, 1)
    top = np.where(prm[:, 2:3] > 0.5, hexc('#b5643a')[None], hexc('#8e897e')[None])
    k = K.smooth(0.25, 0.9, t)[:, None]
    n = vnoise(pos[:, 0] * 0.8, (pos[:, 1] + z) * 0.8, 6.0)
    base = (hexc('#262220')[None] * (1 - k) + top * k) * (0.9 + 0.14 * n)[:, None]
    return np.clip(base, 0, 1), nrm


def mat_carang(uv, prm, pos, nrm):
    """fired clay of the cà ràng: orange terracotta, smoke-blackened round the rim and above the mouth, ash-grey on the tongue"""
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    n1 = vnoise(x * 0.5, (y + z) * 0.5, 4.0); n2 = vnoise(x * 1.6, (y + z) * 1.6, 9.0)
    base = hexc('#b9673c')[None] * (0.86 + 0.12 * n1 + 0.06 * n2)[:, None]
    t = (z - prm[:, 0]) / 5.6
    soot = 0.55 * K.smooth(0.6, 1.05, t)
    dm = np.exp(-((x - prm[:, 1]) / 3.0) ** 2) * (y > prm[:, 2] + 2.0) * K.smooth(0.0, 0.5, t)
    soot = np.clip(np.maximum(soot, 0.75 * dm) * (0.8 + 0.3 * n2), 0, 1)
    tongue = (y > prm[:, 2] + 3.7) & (t < 0.32)
    base = np.where(tongue[:, None], base * 0.8 + hexc('#8c8378')[None] * 0.2, base)
    return np.clip(base * (1 - 0.75 * soot)[:, None], 0, 1), nrm


def mat_ash(uv, prm, pos, nrm):
    x, y = pos[:, 0], pos[:, 1]
    n1 = vnoise(x * 0.4, y * 0.4, 3.0); n2 = vnoise(x * 1.5, y * 1.5, 8.0)
    base = hexc('#8f8478')[None] * (0.86 + 0.12 * n1 + 0.08 * n2)[:, None]
    return np.clip(base, 0, 1), nrm


MATS.update({M_CARANG: mat_carang, M_ASH: mat_ash})
MATS.update({M_BEP: mat_bep, M_NOI: mat_noi, M_GRASS1: mat_flat('#6b9a3e'), M_GRASS2: mat_flat('#5a8a34'), M_GRASS3: mat_flat('#82ac4c'),
             M_PFLOW2: mat_flat('#f06aa2'), M_LAMPTIN: mat_flat('#7c3826'), M_ALU: mat_flat('#a29d92')})
GLOSS.update({M_NOI: (0.25, 30.0), M_LAMPTIN: (0.3, 30.0), M_ALU: (0.45, 40.0)})
MATS.update({M_LEAFD1: mat_flat('#b8863a'), M_LEAFD2: mat_flat('#8c5a2c'), M_LEAFD3: mat_flat('#c9a64c'), M_PATH: mat_path})
MATS.update({M_SIGNR: mat_signr, M_CHALK: mat_chalk, M_CAKHO: mat_flat('#7a3c18'), M_RAU: mat_flat('#4c8c2c'),
             M_EGG: mat_flat('#efc23e'), M_THIT: mat_flat('#b5532c'), M_PLEAF: mat_flat('#3d8530'), M_PFLOW: mat_flat('#d2306e'),
             M_TERRA: mat_flat('#b8643a'), M_CLAY: mat_flat('#a8784e')})
GLOSS.update({M_CAKHO: (0.4, 40.0), M_THIT: (0.35, 40.0), M_EGG: (0.2, 30.0), M_PLEAF: (0.25, 30.0), M_TERRA: (0.1, 20.0)})


def pad_outline(rng):
    """the yard edge: a rounded rect resampled and pushed in and out a little, so it reads as trodden earth, not a tray"""
    P = np.array(rrect(0.07, 2.93, 0.07, 1.93, 0.14, n=10), float)
    seg = np.linalg.norm(np.diff(np.vstack([P, P[:1]]), axis=0), axis=1); s = np.concatenate([[0], np.cumsum(seg)])
    L = s[-1]; t = np.linspace(0, L, 260, endpoint=False)
    Q = np.stack([np.interp(t, s, np.append(P[:, 0], P[0, 0])), np.interp(t, s, np.append(P[:, 1], P[0, 1]))], -1)
    tg = np.roll(Q, -1, 0) - np.roll(Q, 1, 0); nrm = np.stack([tg[:, 1], -tg[:, 0]], -1); nrm /= np.linalg.norm(nrm, axis=1, keepdims=True)
    cen = Q.mean(0)
    if ((Q - cen) * nrm).sum(1).mean() < 0: nrm = -nrm
    off = np.zeros(len(t))
    for k, a in ((3, 0.5), (7, 0.45), (13, 0.35), (23, 0.25)):
        off += a * np.sin(2 * math.pi * k * t / L + rng.uniform(0, 6.3))
    off = off * 0.95 - 0.2
    back = Q[:, 1] < 0.9 * T                                             # under the kitchen: keep the edge straight
    off[back] *= 0.2
    Q = Q + nrm * off[:, None]
    return [tuple(q) for q in Q]


def pad_top(S, pts, z, mat):
    P = np.array(pts + [pts[0]], float); cen = P[:-1].mean(0); n = len(P)
    def F(U, V):
        x = np.interp(U, np.arange(n), P[:, 0]); y = np.interp(U, np.arange(n), P[:, 1])
        return np.stack([cen[0] + V * (x - cen[0]), cen[1] + V * (y - cen[1]), np.full_like(U, z)], -1)
    U, V = np.meshgrid(np.linspace(0, n - 1, 5), np.linspace(0, 1, 3), indexing='ij'); Pp = F(U, V)
    nz = np.cross(np.gradient(Pp, axis=0), np.gradient(Pp, axis=1))[..., 2].mean()
    S.grid(F, n * 2, 30, mat, (0, 0, 0), 0.0, uvr=((0, n - 1), (0, 1)), flip=nz < 0)


def tufts(S, rng, pts):
    """grass growing up to the yard edge (Link's ground is lawn): small tufts of blades, more at the corners"""
    P = np.array(pts, float); cen = P.mean(0)
    i = 0
    while i < len(P):
        x, y = P[i]
        if y > 0.9 * T or x > 2.85 * T:
            d = np.array([x - cen[0], y - cen[1]]); d /= np.linalg.norm(d)
            c = np.array([x, y, 0.0]) + np.append(d, 0) * rng.uniform(-0.6, 1.6)
            for k in range(rng.integers(5, 10)):
                a = rng.uniform(0, 2 * math.pi); r0 = rng.uniform(0, 1.0)
                b = c + np.array([math.cos(a) * r0, math.sin(a) * r0, 0.0])
                lean = np.append(d * rng.uniform(0.2, 0.8) + rng.normal(0, 0.3, 2), 1.0)
                cone(S, b, lean, rng.uniform(0.28, 0.42), rng.uniform(2.2, 4.8), (M_GRASS1, M_GRASS2, M_GRASS3)[k % 3], na=5, nu=4)
        i += int(rng.integers(3, 7))


def post(S, rng, u, v, z1, r=1.7):
    tube(S, W3(u, v, -0.3), W3(u, v, z1), r, M_BARK, prm=(rng.random(), 0, 0), nr=12, nl=12, taper=0.88)


def zroof(v):
    return np.where(v < K.RV, K.BZ + (v - K.BV) / (K.RV - K.BV) * (K.RZ - K.BZ), K.EZ + (K.EV - v) / (K.EV - K.RV) * (K.RZ - K.EZ))


def gable(S, u, sgn):
    """leaf infill between the tie beam and the roof at the end frame u (sgn: which way it faces)"""
    v0, v1 = KV0, 0.86
    def F(U, V):
        v = v0 + U / T; zt = zroof(v) - 2.4
        return np.stack([np.full_like(U, u * T), v * T, ZW + V * np.clip(zt - ZW, 0, None)], -1)
    S.grid(F, 40, 12, M_GABLE, (0, 0, 0), 0.0, uvr=((0, (v1 - v0) * T), (0, 1)), flip=sgn < 0)


def bench(S, rng, cu, cv, L=0.74):
    """băng ghế tre: a split-bamboo seat on two leg frames (seat top z 5.8: the game seats its customers at that height)"""
    h = L / 2
    for k in range(4):
        y = cv - 0.06 + 0.04 * k
        tube(S, W3(cu - h, y, 5.2), W3(cu + h, y, 5.2), 0.62, M_BAMBOO if k % 3 else M_OLDBAMBOO, prm=(rng.random(), 0.4, 0), nr=8, nl=10)
    for s in (-1, 1):
        u = cu + s * (h - 0.06)
        for d in (-1, 1):
            bam(S, rng, W3(u, cv + d * 0.05, 0), W3(u, cv + d * 0.05, 4.7), 0.55, nl=3)
        bam(S, rng, W3(u, cv - 0.08, 4.4), W3(u, cv + 0.08, 4.4), 0.45, nl=2)
    bam(S, rng, W3(cu - h + 0.06, cv, 1.8), W3(cu + h - 0.06, cv, 1.8), 0.4, nl=6)


def table(S, rng, cu, cv, kind):
    """bàn gỗ: plank top z 10.6 (the game's table height), bamboo legs and stretchers, a few things at the ends"""
    hu, hv = 0.36, 0.19
    box(S, W3(cu - hu, cv - hv, 9.6), W3(cu + hu, cv + hv, 10.6), M_PLANK, prm=(rng.random(), 0, 0))
    for su in (-1, 1):
        for sv in (-1, 1):
            bam(S, rng, W3(cu + su * (hu - 0.05), cv + sv * (hv - 0.05), 0), W3(cu + su * (hu - 0.05), cv + sv * (hv - 0.05), 9.6), 0.75, nl=4)
        bam(S, rng, W3(cu + su * (hu - 0.05), cv - hv + 0.04, 3.0), W3(cu + su * (hu - 0.05), cv + hv - 0.04, 3.0), 0.45, nl=3)
    bam(S, rng, W3(cu - hu + 0.05, cv, 3.0), W3(cu + hu - 0.05, cv, 3.0), 0.45, nl=6)
    zt = 10.6
    if kind == 0:
        c = W3(cu + 0.27, cv - 0.05, zt)                                             # ống đũa
        lathe(S, c, [(0, 1.3), (3.6, 1.3), (3.7, 1.15)], M_BAMBOO, na=14)
        for k in range(6):
            an = k * 1.05
            tube(S, c + np.array([0.5 * math.cos(an), 0.5 * math.sin(an), 2.0]), c + np.array([0.9 * math.cos(an), 0.9 * math.sin(an), 6.4]), 0.16, M_WOOD, nr=4, nl=2)
        c = W3(cu - 0.27, cv - 0.06, zt)                                             # chai nước mắm + hũ ớt
        lathe(S, c, [(0, 1.0), (4.4, 1.0), (5.2, 0.45), (6.6, 0.38), (6.9, 0.45)], M_BOTTLE, na=14)
        lathe(S, c + np.array([0, 0, 6.8]), [(0, 0.48), (0.8, 0.48), (0.9, 0.0)], M_CAP, na=10)
        c = W3(cu - 0.27, cv + 0.07, zt)
        lathe(S, c, [(0, 0.9), (1.6, 1.15), (2.2, 0.9), (2.4, 0.95)], M_GLAZE, na=14)
        disc(S, c + np.array([0, 0, 2.2]), (0, 0, 1), 0.85, K.M_CHILLI, nr=2, na=12)
    else:
        c = W3(cu + 0.24, cv - 0.02, zt)                                             # bình trà + chén
        lathe(S, c, [(0, 1.6), (1.4, 2.4), (3.0, 2.3), (3.8, 1.3), (4.3, 1.0)], M_TEAPOT, na=18)
        disc(S, c + np.array([0, 0, 4.3]), (0, 0, 1), 1.0, M_LID, nr=2, na=12, dome=0.4)
        tube(S, c + np.array([2.0, 0, 1.6]), c + np.array([3.6, 0, 3.6]), 0.4, M_TEAPOT, nr=6, nl=2, taper=0.7)
        for (dx, dy) in ((-2.8, 1.6), (-2.6, -1.8)):
            lathe(S, c + np.array([dx, dy, 0]), [(0, 0.6), (0.2, 0.9), (1.4, 1.2), (1.45, 1.2)], K.M_SU if hasattr(K, 'M_SU') else M_BOWL, na=14)
        c = W3(cu - 0.27, cv - 0.04, zt)
        lathe(S, c, [(0, 1.3), (3.6, 1.3), (3.7, 1.15)], M_BAMBOO, na=14)
        for k in range(6):
            an = k * 1.05
            tube(S, c + np.array([0.5 * math.cos(an), 0.5 * math.sin(an), 2.0]), c + np.array([0.9 * math.cos(an), 0.9 * math.sin(an), 6.4]), 0.16, M_WOOD, nr=4, nl=2)


def dish(S, c, food, r=2.6, h=1.0):
    lathe(S, c, [(0, r * 0.55), (0.3, r * 0.9), (0.7, r), (0.8, r)], M_BOWL, na=18)
    ell(S, c + np.array([0, 0, 0.6]), r * 0.8, r * 0.8, h, food, nu=6, nvv=12)


def back(S, rng):
    # yard: one earth pad; the kitchen stands on a raised earth platform at the back
    rrect_top(S, 0.06, 2.94, 0.06, 1.94, 0.06, ZF, M_FLOOR)                  # vòng 5 (Link 14:20): the plain pad again, hut height
    extrude(S, rrect(0.06, 2.94, 0.06, 1.94, 0.06), 0.0, ZF, M_EARTHSIDE, flare=0.6)
    rrect_top(S, KU0 - 0.06, KU1 + 0.06, KV0 - 0.06, 0.9, 0.04, ZH, M_FLOOR)
    extrude(S, rrect(KU0 - 0.06, KU1 + 0.06, KV0 - 0.06, 0.9, 0.04), ZF - 0.2, ZH, M_EARTHSIDE, flare=0.5)
    # walls: woven back wall, left end full, right end half high (the bếp shows through), leaf gables
    e = 0.01
    plane(S, W3(KU0, KV0 + e, ZH), W3(KU1, 0, 0) - W3(KU0, 0, 0), np.array([0, 0, ZW - ZH]), 70, 28, M_WEAVE_F)
    plane(S, W3(KU0 + e, 0.86, ZH), W3(0, KV0, 0) - W3(0, 0.86, 0), np.array([0, 0, ZW - ZH]), 20, 28, M_WEAVE_R)
    plane(S, W3(KU1 - e, 0.86, ZH), W3(0, KV0, 0) - W3(0, 0.86, 0), np.array([0, 0, 17.0 - ZH]), 20, 10, M_WEAVE_R)
    gable(S, KU0, -1); gable(S, KU1, 1)
    for (u, v) in ((KU0, KV0), (KU1, KV0), (KU0, 0.84), (KU1, 0.84), (1.5, 0.84), (1.5, KV0)):
        post(S, rng, u, v, ZW + 1.8)
    bam(S, rng, W3(KU0 - 0.06, 0.84, ZW), W3(KU1 + 0.06, 0.84, ZW), 1.3, nl=16)              # front plate
    bam(S, rng, W3(KU0 - 0.06, KV0, ZW), W3(KU1 + 0.06, KV0, ZW), 1.2, nl=16)
    for u in (KU0, KU1):
        bam(S, rng, W3(u, KV0 - 0.06, ZW - 0.8), W3(u, 0.9, ZW - 0.8), 1.15, nl=10)
        bam(S, rng, W3(u, KV0, 17.0), W3(u, 0.86, 17.0), 0.6, nl=8)
    for z in (ZH + 1.0, 22.0):
        bam(S, rng, W3(KU0 + 0.02, KV0 + 0.012, z), W3(KU1 - 0.02, KV0 + 0.012, z), 0.55, nl=14)
    K.roof(S, rng, 0)
    # inside: shelf with chén bát, a lu nước with a gáo dừa, the bếp lò đất, củi, the quầy with rice and food
    box(S, W3(0.5, KV0 + 0.01, ZH + 13.2), W3(1.4, KV0 + 0.16, ZH + 14.0), M_PLANK)
    for u in (0.6, 1.3): bam(S, rng, W3(u, KV0 + 0.02, ZH + 9.4), W3(u, KV0 + 0.14, ZH + 13.2), 0.4, nl=2)
    for (u, kind) in ((0.62, 'bowl'), (0.8, 'bowl'), (0.98, 'jar'), (1.14, 'bot'), (1.28, 'bot')):
        c = W3(u, KV0 + 0.09, ZH + 14.0)
        if kind == 'bowl':
            for j in range(5): lathe(S, c + np.array([0, 0, 0.6 * j]), [(0, 1.2), (0.55, 2.4), (0.6, 2.45)], M_BOWL, na=20)
        elif kind == 'jar':
            lathe(S, c, [(0, 1.6), (2.0, 2.6), (4.2, 2.4), (5.4, 1.5), (5.8, 1.6)], M_GLAZE, na=18)
            disc(S, c + np.array([0, 0, 5.8]), (0, 0, 1), 1.6, M_LID, nr=2, na=14, dome=0.3)
        else:
            lathe(S, c, [(0, 1.0), (4.0, 1.0), (4.8, 0.45), (6.2, 0.38), (6.5, 0.45)], M_BOTTLE, na=14)
            lathe(S, c + np.array([0, 0, 6.4]), [(0, 0.48), (0.8, 0.48), (0.9, 0.0)], M_CAP, na=10)
    c = W3(0.38, 0.4, ZH)                                                           # lu nước
    lathe(S, c, [(0, 2.6), (1.8, 3.9), (5.4, 4.5), (8.6, 3.6), (9.6, 2.7), (10.1, 2.9)], M_GLAZE, na=30)     # vòng 4: ~2/3 size
    disc(S, c + np.array([0, 0, 10.1]), (0, 0, 1), 3.2, M_PLANK, nr=3, na=24, dome=0.05)
    g = c + np.array([0.7, 0.5, 10.6])
    lathe(S, g, [(0, 0.0), (0.3, 1.2), (1.1, 1.9), (1.5, 2.0)], M_COCO, na=18)
    tube(S, g + np.array([1.8, 0.2, 1.1]), g + np.array([6.0, 1.1, 2.1]), 0.28, M_WOOD, nr=5, nl=3)
    bep(S, rng)
    # quầy: a bamboo serving table along the open front
    zq = ZH + 8.6
    for (u, v) in ((0.46, 0.52), (1.14, 0.52), (0.46, 0.78), (1.14, 0.78)):
        bam(S, rng, W3(u, v, ZH), W3(u, v, zq - 0.6), 0.7, nl=4)
    for i in range(7):
        v = 0.5 + 0.3 * i / 6
        tube(S, W3(0.42, v, zq - 0.3), W3(1.18, v, zq - 0.3), 0.62, M_BAMBOO, prm=(rng.random(), 0.4, 0), nr=8, nl=8)
    bam(S, rng, W3(0.46, 0.52, 4.6), W3(1.14, 0.52, 4.6), 0.45, nl=6); bam(S, rng, W3(0.46, 0.78, 4.6), W3(1.14, 0.78, 4.6), 0.45, nl=6)
    c = W3(0.62, 0.64, zq)                                                           # nồi cơm lớn with a wooden ladle
    lathe(S, c, [(0, 3.2), (1.0, 4.4), (4.6, 4.6), (5.2, 4.2), (5.6, 4.4)], M_POT, na=26)
    disc(S, c + np.array([0, 0, 5.5]), (0, 0, 1), 4.3, M_RICE, nr=3, na=22, dome=0.2)
    tube(S, c + np.array([1.2, 0.4, 5.6]), c + np.array([3.8, 1.2, 10.4]), 0.35, M_WOOD, nr=5, nl=3)
    c = W3(0.97, 0.64, zq)                                                           # mâm cơm: four dishes on a tray
    disc(S, c + np.array([0, 0, 0.4]), (0, 0, 1), 5.6, M_GOLD, nr=4, na=28, dome=0.02)
    lathe(S, c, [(0, 5.4), (0.6, 5.8), (0.7, 5.6)], M_GOLD, na=28)
    for (dx, dy, f) in ((-2.2, -2.1, M_CAKHO), (2.2, -2.1, M_RAU), (-2.2, 2.1, M_EGG), (2.2, 2.1, M_THIT)):
        dish(S, c + np.array([dx, dy, 0.6]), f, r=2.2)
    # hung at the front: đèn bão in the middle, dried chillies and garlic on the left post
    tube(S, W3(LAMP[0], 0.85, ZW - 0.5), W3(LAMP[0], LAMP[1], LAMP[2] + 4.4), 0.16, M_SOOT, nr=4, nl=2)
    biglamp(S, W3(*LAMP), k=1.0)                                                   # kho size (Link 15:51 "đèn vẽ nhỏ lại")
    SP.hang_chilli(S, W3(KU0 + 0.07, 0.9, ZW - 1.0), L=14.0, n=22)
    SP.hang_garlic(S, W3(KU0 + 0.2, 0.9, ZW - 1.0), n=7)
    # QUÁN CƠM board standing on the front plate (the game paints the words)
    for u in (1.0, 2.0):                                                             # vòng 4: board stands clear of the thatch
        bam(S, rng, W3(u, 0.87, 38.5), W3(u, SV - 0.02, 59.0), 0.6, nl=6)
        tube(S, W3(u - 0.03, 0.865, ZW + 0.2), W3(u + 0.03, 0.875, ZW + 0.5), 0.8, M_RATTAN, nr=6, nl=2)
    Z0, Z1 = 47.5, 57.5
    box(S, W3(0.84, SV, Z0), W3(2.16, SV + 0.03, Z1), M_SIGNR)
    for (a, b) in ((W3(0.84, SV + 0.035, Z0), W3(2.16, SV + 0.035, Z0)), (W3(0.84, SV + 0.035, Z1), W3(2.16, SV + 0.035, Z1)),
                   (W3(0.84, SV + 0.035, Z0), W3(0.84, SV + 0.035, Z1)), (W3(2.16, SV + 0.035, Z0), W3(2.16, SV + 0.035, Z1))):
        tube(S, a, b, 0.5, M_PLANK, nr=6, nl=4)
    yard(S, rng)
    # back benches (behind the tables: the game seats customers at v .95)
    for cu in TU:
        bench(S, rng, cu, 0.95)


def carang(S, rng, u, v, z0):
    """cà ràng (miền Tây clay stove): a flared terracotta body, a horseshoe mouth facing the yard with a tongue (lưỡi) where the
    firewood rests, three ông táo knobs on the rim holding the pot"""
    c = W3(u, v, z0); R0 = 3.9; H = 5.6
    lathe(S, c, [(0, 3.3), (0.5, 3.7), (2.8, 4.0), (4.6, 3.8), (5.0, 4.15), (H, 4.15)], M_CARANG, prm=(z0, u * T, v * T), na=30)
    disc(S, c + np.array([0, 0, H - 0.4]), (0, 0, 1), 3.75, M_SOOT, nr=2, na=20)
    disc(S, c + np.array([0, 0, 0.05]), (0, 0, -1), 3.3, M_CARANG, prm=(z0, u * T, v * T), nr=2, na=20)
    m = c + np.array([0, R0 - 0.2, 2.0])                                             # the mouth: dark arch with glowing coals
    ell(S, m, 2.3, 0.7, 2.1, M_SOOT, nu=8, nvv=12)
    ell(S, m + np.array([0, 0.35, -1.2]), 1.9, 0.5, 0.7, M_EMBER, nu=6, nvv=10)
    # lưỡi: the clay tongue in front of the mouth, with a raised rim
    t0 = c + np.array([0, R0 - 0.3, 0])
    box(S, t0 + np.array([-2.5, 0, 0]), t0 + np.array([2.5, 3.0, 0.9]), M_CARANG, prm=(z0, u * T, v * T))
    for sg in (-1, 1):
        box(S, t0 + np.array([sg * 2.5 - (0.6 if sg > 0 else 0), 0, 0.9]), t0 + np.array([sg * 2.5 + (0.6 if sg < 0 else 0), 3.0, 1.6]), M_CARANG, prm=(z0, u * T, v * T))
    box(S, t0 + np.array([-2.5, 2.4, 0.9]), t0 + np.array([2.5, 3.0, 1.4]), M_CARANG, prm=(z0, u * T, v * T))
    for k in range(4):                                                               # coals and ash on the tongue
        ell(S, t0 + np.array([-1.5 + k, 1.0 + 0.4 * (k % 2), 1.0]), 0.7, 0.55, 0.4, M_EMBER if k % 2 else M_ASH, nu=5, nvv=8)
    for k, dx in enumerate((-1.1, 0.0, 1.1)):                                        # three sticks into the fire, ends out over the rim
        a = t0 + np.array([dx * 0.6, 0.8, 1.3]); b = t0 + np.array([dx * 1.5, 6.0 + 0.6 * k, 2.4 + 0.4 * (k % 2)])
        tube(S, a, b, 0.62, M_BARK if k != 1 else M_WOOD, prm=(rng.random(), 0, 0), nr=7, nl=3)
    cone(S, m + np.array([0, 0.9, -0.6]), (0.0, 0.35, 1.0), 1.4, 3.4, M_FIRE, na=12, nu=5)
    for k in range(3):                                                               # ông táo
        an = -math.pi / 2 + k * 2 * math.pi / 3
        ell(S, c + np.array([3.4 * math.cos(an), 3.4 * math.sin(an), H + 0.5]), 1.1, 1.1, 1.3, M_CARANG, prm=(z0, u * T, v * T), nu=6, nvv=10)
    return z0 + H + 1.2


def bep(S, rng):
    """bệ bếp: a waist-high plank box filled with packed earth on four legs, củi stacked underneath, two cà ràng on top,
    a pot of rice and a clay pot of cá kho, an ống thổi lửa and a pair of đũa bếp"""
    u0, u1, v0, v1 = 1.86, 2.6, 0.24, 0.62
    zt = ZH + ZB
    for (u, v) in ((u0 + 0.03, v0 + 0.03), (u1 - 0.03, v0 + 0.03), (u0 + 0.03, v1 - 0.03), (u1 - 0.03, v1 - 0.03)):
        box(S, W3(u - 0.025, v - 0.025, ZH), W3(u + 0.025, v + 0.025, zt - 2.4), K.M_TIMBER, prm=(rng.random(), 0, 0))
    box(S, W3(u0, v0, zt - 2.6), W3(u1, v1, zt - 0.2), M_PLANK, prm=(rng.random(), 0, 0))       # the plank box
    for (a, b) in ((W3(u0 - 0.01, v1 + 0.002, zt - 2.6), W3(u1 + 0.01, v1 + 0.02, zt - 2.2)), (W3(u0 - 0.01, v1 + 0.002, zt - 0.6), W3(u1 + 0.01, v1 + 0.02, zt - 0.1))):
        box(S, a, b, K.M_TIMBER, prm=(rng.random(), 0, 0))                               # rails on the front face
    rrect_top(S, u0 + 0.015, u1 - 0.015, v0 + 0.015, v1 - 0.015, 0.01, zt, M_ASH)               # packed earth + ash on top
    for (u, z, n) in ((0, 0, 4), (0, 1.7, 3), (0, 3.4, 2)):                         # củi under the bệ
        for j in range(n):
            vv = v0 + 0.08 + 0.09 * j + 0.045 * (4 - n)
            a = W3(u0 + 0.08, vv, ZH + 0.9 + z); b = W3(u1 - 0.08, vv + rng.uniform(-0.01, 0.01), ZH + 0.9 + z)
            tube(S, a, b, 0.85, M_BARK, prm=(rng.random(), 0, 0), nr=8, nl=3)
            disc(S, b + np.array([0.02, 0, 0]), (1, 0, 0), 0.85, M_WOOD, nr=2, na=10)
    tops = [carang(S, rng, u, v, zt) for (u, v) in CR]
    zp = tops[0]
    c = W3(CR[0][0], CR[0][1], zp)                                                   # nồi cơm nhôm, sooty from the fire up
    lathe(S, c, [(0, 2.8), (1.2, 4.3), (4.4, 4.7), (5.0, 4.4), (5.5, 4.9), (5.8, 4.9)], M_NOI, prm=(zp, 5.8, 0), na=26)
    disc(S, c + np.array([0, 0, 5.6]), (0, 0, 1), 4.6, M_ALU, nr=3, na=22, dome=0.12)
    lathe(S, c + np.array([0, 0, 6.1]), [(0, 0.9), (0.5, 0.9), (0.9, 0.5), (1.1, 0.0)], M_SOOT, na=12)
    for sg in (-1, 1):
        a = c + np.array([sg * 4.8, 0, 4.8]); tube(S, a, a + np.array([sg * 1.3, 0, 0.5]), 0.45, M_ALU, nr=6, nl=2)
    zp = tops[1]
    c = W3(CR[1][0], CR[1][1], zp)                                                   # nồi đất kho cá
    lathe(S, c, [(0, 2.4), (1.6, 4.0), (3.8, 4.2), (4.6, 3.6), (5.0, 3.8)], M_NOI, prm=(zp, 5.0, 1), na=24)
    disc(S, c + np.array([0, 0, 4.9]), (0, 0, 1), 3.6, M_TERRA, nr=3, na=20, dome=0.25)
    lathe(S, c + np.array([0, 0, 5.6]), [(0, 0.7), (0.5, 0.7), (0.8, 0.0)], M_TERRA, na=12)
    a = W3(u1 - 0.06, v0 + 0.06, zt + 0.4); tube(S, a, a + np.array([-1.0, 12.0, 0.8]), 0.5, M_BAMBOO, prm=(0.3, 0.2, 0), nr=8, nl=4)   # ống thổi lửa
    for k in range(2):                                                                 # đũa bếp
        a = W3(u0 + 0.06 + 0.012 * k, v1 - 0.06, zt + 0.3); tube(S, a, a + np.array([0.6, -9.0, 0.3]), 0.22, M_WOOD, nr=5, nl=2)


def biglamp(S, c, k=1.7):
    """đèn bão, k times the kho's: c = flame centre"""
    lb = c - np.array([0, 0, 2.6 * k])
    lathe(S, lb, [(0, 1.5 * k), (0.3 * k, 1.7 * k), (1.2 * k, 1.6 * k), (1.5 * k, 0.9 * k)], M_LAMPTIN)
    lathe(S, lb + np.array([0, 0, 1.5 * k]), [(0, 0.9 * k), (0.8 * k, 1.35 * k), (2.0 * k, 1.45 * k), (3.2 * k, 1.2 * k), (3.9 * k, 0.8 * k)], K.M_LAMPGLASS)
    lathe(S, lb + np.array([0, 0, 5.3 * k]), [(0, 1.2 * k), (0.6 * k, 1.25 * k), (1.2 * k, 0.6 * k), (1.8 * k, 0.3 * k)], M_LAMPTIN)
    for sg in (-1, 1):
        tube(S, lb + np.array([1.55 * k * sg, 0, 0.6 * k]), lb + np.array([1.2 * k * sg, 0, 6.6 * k]), 0.16 * k, M_SOOT, nr=4, nl=2)
    ell(S, c, 0.35 * k, 0.35 * k, 0.8 * k, K.M_FLAME, nu=6, nvv=8)


def yard(S, rng):
    """the yard is used: fallen leaves, a few pebbles, a worn patch where people walk in, a chổi tre on the post"""
    for k in range(10):
        u = rng.uniform(0.2, 2.8); v = rng.uniform(1.0, 1.85)
        if abs(v - 1.25) < 0.4 and (abs(u - TU[0]) < 0.45 or abs(u - TU[1]) < 0.45): continue
        a = rng.uniform(0, math.pi); ax = np.array([math.cos(a), math.sin(a), 0.0]); ay = np.array([-math.sin(a), math.cos(a), 0.0])
        ell(S, W3(u, v, ZF + 0.15), 1.3, 0.55, 0.12, (M_LEAFD1, M_LEAFD2, M_LEAFD3)[k % 3], axes=(ax, ay, UP), nu=4, nvv=8)
    # chổi tre leaning on the front left post
    a = W3(KU0 + 0.14, 0.98, ZF); b = W3(KU0 + 0.03, 0.885, 25.0)
    tube(S, a + np.array([0, 0, 5.0]), b, 0.45, M_BAMBOO, nr=6, nl=4)
    for k in range(11):
        f = (k - 5) / 5.0
        tube(S, a + np.array([0, 0, 5.4]), a + np.array([f * 3.2, f * 0.6 + 0.4, 0.15]), 0.2, M_STRAW, nr=4, nl=2)
    tube(S, a + np.array([-1.0, 0.1, 4.0]), a + np.array([1.0, 0.3, 4.0]), 0.35, M_RATTAN, nr=5, nl=2)


def plant(S, rng, c):
    """bông giấy in a clay pot: woody stems arching out, small leaves along them, clusters of magenta bracts (vòng 4: no ball)"""
    lathe(S, c, [(0, 2.8), (5.0, 4.0), (5.6, 4.4), (6.2, 4.4), (6.4, 4.0)], M_TERRA, na=24)
    disc(S, c + np.array([0, 0, 6.0]), (0, 0, 1), 3.9, K.M_EARTH, nr=2, na=18)
    base = c + np.array([0, 0, 5.6])
    for i in range(8):
        az = i * 2 * math.pi / 8 + rng.uniform(-0.3, 0.3); out = rng.uniform(0.35, 0.8); L = rng.uniform(9.0, 14.0)
        if math.cos(az) > 0.3 and math.sin(az) < 0.2: L *= 0.65                       # shorter towards the bench
        pts = [base + np.array([rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0])]
        for j in range(4):
            t = (j + 1) / 4.0
            d = np.array([math.cos(az) * out * (0.4 + t), math.sin(az) * out * (0.4 + t), 1.2 - 1.1 * t * t])
            pts.append(pts[-1] + nv(d) * L / 4)
        for j in range(4):
            tube(S, pts[j], pts[j + 1], 0.42 - 0.07 * j, M_BARK, prm=(rng.random(), 0, 0), nr=6, nl=2)
        for j in range(1, 5):
            for k in range(3 if j < 4 else 2):
                d = nv(rng.normal(0, 1, 3) + np.array([0, 0, 0.6])); a1 = nv(np.cross(d, UP) + 1e-6); a2 = nv(np.cross(d, a1))
                ell(S, pts[j] + d * 1.2, 1.5, 0.85, 0.25, M_PLEAF, axes=(a1, a2, d), nu=4, nvv=8, prm=(rng.random(), 0, 0))
        for j in ((3, 4) if i % 2 else (2, 4)):                                        # bract clusters
            cc = pts[j] + np.array([0, 0, 0.8])
            for k in range(rng.integers(7, 11)):
                d = nv(rng.normal(0, 1, 3) + np.array([0, 0, 0.8])); a1 = nv(np.cross(d, UP) + 1e-6); a2 = nv(np.cross(d, a1))
                ell(S, cc + d * rng.uniform(0.9, 1.9), 1.0, 0.8, 0.22, M_PFLOW if k % 3 else M_PFLOW2, axes=(a1, a2, d), nu=4, nvv=8)


def khap(S, rng, c, k=1.0, lid=True):
    """khạp nước mưa: glazed brown jar, wooden lid (or open, water showing)"""
    lathe(S, c, [(0, 3.0 * k), (2.0 * k, 4.4 * k), (5.6 * k, 4.8 * k), (8.6 * k, 4.0 * k), (9.6 * k, 3.2 * k), (10.1 * k, 3.4 * k)], M_GLAZE, na=28)
    if lid:
        disc(S, c + np.array([0, 0, 10.1 * k]), (0, 0, 1), 3.8 * k, M_PLANK, nr=3, na=22, dome=0.05)
    else:
        disc(S, c + np.array([0, 0, 9.6 * k]), (0, 0, 1), 3.2 * k, K.M_WATER, nr=3, na=22)


def front(S, rng):
    for (cu, kind) in ((TU[0], 0), (TU[1], 1)):
        table(S, rng, cu, 1.25, kind)
        bench(S, rng, cu, 1.55)
    plant(S, rng, W3(0.2, 1.78, ZF))
    c = W3(2.78, 1.42, ZF - 0.2)                                                      # vòng 4: rain jars in the empty front right corner
    khap(S, rng, c)
    g = c + np.array([0.6, 0.4, 10.6])
    lathe(S, g, [(0, 0.0), (0.3, 1.2), (1.1, 1.9), (1.5, 2.0)], M_COCO, na=18)
    tube(S, g + np.array([1.8, 0.2, 1.1]), g + np.array([6.0, 1.1, 2.1]), 0.28, M_WOOD, nr=5, nl=3)
    khap(S, rng, W3(2.8, 1.74, ZF - 0.2), 0.72, lid=False)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear()
    K.LIGHTS2.append((W3(*LAMP), hexc('#ff9645'), 14.0, 2.8, 'all'))           # as soft as the nhà tranh's (Link 15:51)
    K.GLOWS[:] = [(W3(*LAMP), 0.2, 0.85)]
    for (u, v, z) in FIRES:
        K.LIGHTS2.append((W3(u, v + 0.05, ZH + z), hexc('#ff8a3a'), 9.0, 1.2, 'in'))
    back(S, rng)
    ns0 = S.ns
    if with_props: front(S, rng)
    return S, (ns0, S.ns)


K.build = build


def smoke(im, night):
    """thin cooking smoke rising from the ridge over the bếp: soft, translucent wisps drifting left"""
    from PIL import Image, ImageDraw, ImageFilter
    r = K.R3(K.PXU); sx, sy, _ = r.proj(np.array([W3(2.42, K.RV, K.RZ + 3.5)]))
    x0, y0 = float(sx[0]) * im.width / r.W, float(sy[0]) * im.height / r.H; px = im.width / r.W * K.PXU
    m = Image.new('L', im.size, 0); d = ImageDraw.Draw(m)
    rs = np.random.default_rng(7)
    for i in range(26):
        t = i / 25.0
        x = x0 - t * 26 * px + math.sin(t * 5.5) * 3.5 * px; y = y0 - t * 48 * px
        rr = (1.6 + 5.5 * t) * px; a = int(150 * (1 - t) ** 1.4 * (0.6 + 0.4 * rs.random()))
        d.ellipse((x - rr, y - rr * 0.8, x + rr, y + rr * 0.8), fill=a)
    m = m.filter(ImageFilter.GaussianBlur(2.2 * px))
    col = (238, 234, 226) if not night else (128, 132, 150)
    k = 0.72 if not night else 0.5
    lay = Image.new('RGBA', im.size, col + (0,)); lay.putalpha(m.point(lambda v: int(v * k)))
    out = im.copy(); out.alpha_composite(lay); return out


def render(n, part):
    im = K.render(1, n, part)
    return smoke(im, n) if part == 'b' else im

if __name__ == '__main__':
    from PIL import Image
    if sys.argv[1] == 'prev':
        part = sys.argv[3] if len(sys.argv) > 3 else 'b'; n = len(sys.argv) > 4 and sys.argv[4] == 'n'
        if part == 'all':
            b = render(n, 'b'); f = render(n, 'f'); b.alpha_composite(f); b.save(sys.argv[2])
        else: render(n, part).save(sys.argv[2])
    elif sys.argv[1] == 'atlas':
        out, tab = sys.argv[2], sys.argv[3]
        frames = {}
        for part in ('b', 'f'):
            for n in (0, 1):
                im = render(bool(n), part); bb = im.getbbox(); frames[part + ('n' if n else 'd')] = (im.crop(bb), bb)
        keys = ['bd', 'bn', 'fd', 'fn']
        x = 0; G = {}; sc = float(K.PXU); H = max(f[0].height for f in frames.values()); BB = K.BB
        sheet = Image.new('RGBA', (sum(frames[k][0].width + 2 for k in keys), H), (0, 0, 0, 0))
        for k in keys:
            im, bb = frames[k]; sheet.paste(im, (x, 0))
            G[k] = [x, 0, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
            x += im.width + 2
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, K.SHEET), 'WEBP', quality=92, method=6); json.dump(G, open(tab, 'w'))
        print('sheet', sheet.size)
