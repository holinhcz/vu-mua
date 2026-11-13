# Sạp bán hàng (game id sap / sap_b / sap_f, 4x2, mirror sap2*) as a real 3D model, in the kit of the kho (kho3d.py):
# same renderer, materials, sun and frame layout (bd bn fd fn). Link 2026-11-08: "check tiếp Sạp bán hàng".
# v3 (Link 11:55 "đừng có theo cái cũ 100%", 12:00 "1 mái như hiện tại để mặt trước thoáng"): one lean-to roof, high and
# open at the front (2 battens, clamp poles); the SẠP QUÊ board stands on the roof's front edge (no longer hides the goods);
# nia/rổ lined with banana leaf; produce piled on the ground in front (bí đỏ, dừa, dưa hấu, cam); bamboo stool (v4);
# hanging goods only at the two ends, clear of the trays. A gable-roof try is kept in sap3d_v2_gable.py.
# Usage: python3 sap3d.py prev OUT.png b|f|all [n]      python3 sap3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'kho'))
import kho3d as K
from kho3d import (W3, T, nv, UP, Scene, X3, hexc, smooth, vnoise, plane, tube, disc, lathe, extrude, rrect, rrect_top, box,
                   sack, slope, mat_flat, MATS, GLOSS, M_EARTHSIDE, M_BAMBOO, M_WEAVE_F, M_WEAVE_R, M_NIA, M_CORN, M_HUSK,
                   M_CHILLI, M_GLAZE, M_POT, M_LID, M_PLANK, M_ROPE, M_RATTAN, M_OLDBAMBOO, M_FLOOR, M_JUTE, M_GRAIN, M_CRATE,
                   M_DIAL, M_STEEL, M_SIGN2, M_PUMPKIN, M_GARLIC, M_STRAW, M_BOWL, M_HANDLE, M_WOOD, M_BARK, M_TEAPOT)

K.BB = (-104, -150, 104, 52)
K.OX, K.OY = -32, -48                       # at.P(4,2)
K.WU0, K.WU1, K.WV0, K.WV1 = 0.06, 3.94, 0.12, 1.96   # under the roof (skylight cut)
K.ZF = 2.4                       # pad = every building (Link 2026-11-09, was 1.2)
K.INSIDE_K = 0.55                            # an open stall (Link 16:28: roof as bright as the đình's at EXPO .95)
K.FOOT = (0.06, 3.94, 0.06, 1.94, 0.08)
K.SHEET = 'sap.webp'
K.SEED = 5100
K.PATCH = None
K.TARGET_DAY = 0.42                          # no gamma lift: it flattened every shadow (Link 03:05)
K.SUN_DAY = float(os.environ.get('SAPS', '1.4'))   # stronger sun by day: lit parts brighter, shadows stay dark (Link 02:50/03:05)
K.WEATHER = os.environ.get('SAPW', '0') == '1'   # no grey weathering patches on this roof
K.ZW = 77.0
ZF = 2.4

# ---------------------------------------------------------------- materials
def mat_melon(uv, prm, pos, nrm):
    v = uv[:, 1]; u = uv[:, 0]
    s = np.sin(v * 2 * math.pi * 13 + 0.9 * np.sin(u * 23 + v * 40) + 0.5 * np.sin(u * 61))
    k = smooth(-0.15, 0.25, s)
    base = hexc('#86b257')[None] * (1 - k)[:, None] + hexc('#2c5a22')[None] * k[:, None]
    return base * (0.92 + 0.12 * vnoise(u * 30, v * 60, 3.0))[:, None], nrm

def mat_hat(uv, prm, pos, nrm):
    u = uv[:, 0]
    ring = np.abs(((u * 11) % 1) - 0.5) < 0.06
    base = np.tile(hexc('#e4d4a2'), (len(u), 1)) * (0.94 + 0.08 * vnoise(u * 40, uv[:, 1] * 80, 2.0))[:, None]
    base = np.where(ring[:, None], hexc('#b9a26a')[None], base)
    return base, nrm

def mat_bottle(uv, prm, pos, nrm):
    u = uv[:, 0]
    lab = (u > 0.18) & (u < 0.42)
    base = np.where(lab[:, None], hexc('#efe3c4')[None], hexc('#3b2614')[None])
    base = np.where(((u > 0.25) & (u < 0.3))[:, None], hexc('#c0332a')[None], base)
    return base, nrm

def mat_signw(uv, prm, pos, nrm):
    a, b = uv[:, 0], uv[:, 1]
    g = 0.92 + 0.07 * vnoise(a * 0.5, b * 5, 2.0) + 0.04 * np.sin(b * 7 + vnoise(a * 0.25, b, 5.0) * 4)
    gap = np.abs(((b / 5.3) % 1) - 0.5) > 0.47
    base = hexc('#cfa572')[None] * g[:, None]
    base = np.where(gap[:, None], hexc('#8a6440')[None], base)
    return np.clip(base, 0, 1), nrm

def mat_banleaf(uv, prm, pos, nrm):
    """a banana leaf blade: uv = (s along the blade, w -1..1 across); pale midrib, fine lateral veins slanting to the tip"""
    sl, w = uv[:, 0], uv[:, 1]; Wd = prm[:, 0]; aw = np.abs(w)
    t = np.abs(sl)
    vein = np.abs(((t * 1.25 - aw * Wd * 0.3) % 1) - 0.5) < 0.1
    nz = vnoise(sl * 0.5, w * 3.0, 4.0)
    c0 = hexc('#3f8a26'); c1 = hexc('#79b443')
    base = c0[None] + (c1 - c0)[None] * ((0.25 + 0.55 * aw) ** 1.5)[:, None]
    base = base * (0.92 + 0.14 * nz)[:, None]
    base = np.where(vein[:, None], base * 1.08 + 0.02, base)
    base = np.where((aw < 0.075)[:, None], hexc('#c3d27c')[None] * (0.95 + 0.05 * nz)[:, None], base)
    base = np.where((aw > 0.93)[:, None], base * 0.82, base)                     # a darker torn edge
    return np.clip(base, 0, 1), nrm


M_SIGNW = 121
M_BANLEAF, M_PLASTIC, M_COCOG = 122, 123, 124
M_MELON, _M_FREE, M_GOLD, M_BANANA, M_HAT, M_ORANGE, M_REDFRUIT, M_RICE, M_BOTTLE, M_CAP, M_BANSTEM = range(110, 121)
MATS.update({M_MELON: mat_melon, M_GOLD: mat_flat('#d9a63a'), M_BANANA: mat_flat('#e9c43c'),
             M_HAT: mat_hat, M_ORANGE: mat_flat('#ef9126'), M_REDFRUIT: mat_flat('#c8302a'), M_RICE: mat_flat('#f1ece0'),
             M_BOTTLE: mat_bottle, M_CAP: mat_flat('#c0332a'), M_BANSTEM: mat_flat('#7c8a3a')})
GLOSS.update({M_MELON: (0.3, 30.0), M_GOLD: (0.4, 30.0), M_REDFRUIT: (0.35, 30.0), M_ORANGE: (0.2, 20.0),
              M_BOTTLE: (0.5, 50.0)})
MATS[M_SIGNW] = mat_signw
MATS.update({M_BANLEAF: mat_banleaf, M_PLASTIC: mat_flat('#d6302a'), M_COCOG: mat_flat('#6e9a34')})
GLOSS.update({M_PLASTIC: (0.35, 40.0), M_BANLEAF: (0.25, 30.0)})
M_LAMPTIN = 125
MATS[M_LAMPTIN] = mat_flat('#7c3826'); GLOSS[M_LAMPTIN] = (0.3, 30.0)
K.NIGHT_EMIT = {}

LANT = (1.22, 1.79, 40.0)                 # đèn bão (flame centre), like the quán cơm's (Link 15:51: no red lantern), over the counter


def lathe2(S, c, prof, mat, prm=(0, 0, 0), na=30):
    """like lathe, but uv in game units (along the profile, round the widest girth): woven baskets keep a real weave"""
    zs = np.array([p[0] for p in prof], float); rs = np.array([p[1] for p in prof], float); c = np.asarray(c, float)
    sl = np.concatenate([[0], np.cumsum(np.hypot(np.diff(zs), np.diff(rs)))]); C = 2 * math.pi * rs.max()
    def F(U, V):
        z = np.interp(U, sl, zs); r = np.interp(U, sl, rs); th = V / C * 2 * math.pi
        return np.stack([c[0] + r * np.cos(th), c[1] + r * np.sin(th), c[2] + z], -1)
    S.grid(F, max(len(prof) * 3, int(sl[-1] / 0.7) + 2), na, mat, prm, 0.0, uvr=((0, sl[-1]), (0, C)), close_v=True, flip=True)


def bam(S, rng, a, b, r, nl=6, mat=M_BAMBOO):
    tube(S, a, b, r, mat, prm=(rng.random(), rng.random(), 0), nr=8, nl=nl)


def ell(S, c, rx, ry, rz, mat, axes=None, nu=8, nvv=12, prm=(0, 0, 0)):
    S0 = Scene(); X3.ellipsoid(S0, c, rx, ry, rz, mat, prm=prm, axes=axes, nu=nu, nvv=nvv); S.merge(S0)


def cone(S, base, d, R, H, mat, na=28, nu=8):
    d = nv(d); a = nv(np.cross(d, UP)) if abs(d[2]) < 0.9 else np.array([1.0, 0, 0]); b = np.cross(d, a)
    base = np.asarray(base, float)
    def F(U, V):
        r = (R * (1 - U))[..., None]; th = (V * 2 * math.pi)[..., None]
        return base + d * (H * U)[..., None] + (a * np.cos(th) + b * np.sin(th)) * r
    S.grid(F, nu, na, mat, (0, 0, 0), 0.0, uvr=((0, 1), (0, 1)), close_v=True, flip=True)


# ---------------------------------------------------------------- back layer
def back(S, rng):
    # nền đất
    rrect_top(S, 0.06, 3.94, 0.06, 1.94, 0.06, ZF, M_FLOOR)
    extrude(S, rrect(0.06, 3.94, 0.06, 1.94, 0.06), 0.0, ZF, M_EARTHSIDE, flare=0.6)
    # back wall: woven phên on a bamboo frame, back posts up to the roof
    plane(S, W3(0.28, 0.3, ZF), W3(3.72, 0, 0) - W3(0.28, 0, 0), np.array([0, 0, 30.0 - ZF]), 90, 20, M_WEAVE_F)
    for u in (0.28, 2.0, 3.72):
        bam(S, rng, W3(u, 0.28, 0), W3(u, 0.28, 60.4), 1.25, nl=12)
    for z in (2.2, 16.0, 30.0):
        bam(S, rng, W3(0.24, 0.31, z), W3(3.76, 0.31, z), 0.6 if z != 30.0 else 0.75, nl=14)
    bam(S, rng, W3(0.14, 0.28, 60.0), W3(3.86, 0.28, 60.0), 1.0, nl=14)            # back beam under the eave
    for u in (0.28, 3.72):                                                          # side beams, back to front
        bam(S, rng, W3(u, 0.2, 59.6), W3(u, 1.86, 78.6), 0.9, nl=10)
    # plank shelf on the wall, with jars, bottles and bowls
    box(S, W3(0.42, 0.32, 18.6), W3(3.58, 0.5, 19.4), M_PLANK)
    for u in (0.6, 1.98, 3.4):
        bam(S, rng, W3(u, 0.31, 13.8), W3(u, 0.46, 18.6), 0.45, nl=2)
    zs = 19.4
    for (u, kind, tone) in ((0.6, 'jar', 0), (0.85, 'jar', 1), (1.15, 'bot', 0), (1.3, 'bot', 1), (1.45, 'bot', 2), (1.85, 'bowl', 0),
                            (2.35, 'jar', 1), (2.6, 'jar', 0), (2.95, 'bot', 1), (3.1, 'bot', 0), (3.38, 'bowl', 0)):
        c = W3(u, 0.41, zs)
        if kind == 'jar':
            k = 1.0 if tone else 0.86
            lathe(S, c, [(0, 1.8 * k), (2.2 * k, 3.2 * k), (5.2 * k, 3.0 * k), (7.0 * k, 1.9 * k), (7.6 * k, 1.6 * k), (8.0 * k, 1.9 * k)], M_GLAZE if tone else M_TEAPOT, na=22)
            disc(S, c + np.array([0, 0, 8.0 * k]), (0, 0, 1), 1.9 * k, M_LID, nr=3, na=18, dome=0.25)
        elif kind == 'bot':
            lathe(S, c, [(0, 1.15), (5.4, 1.15), (6.4, 0.55), (8.4, 0.42), (8.8, 0.5)], M_BOTTLE, na=16)
            lathe(S, c + np.array([0, 0, 8.7]), [(0, 0.55), (1.0, 0.55), (1.1, 0.0)], M_CAP, na=12)
        else:
            for j in range(5):
                lathe(S, c + np.array([0, 0, 0.62 * j]), [(0, 1.3), (0.6, 2.6), (0.66, 2.66)], M_BOWL, na=22)
    # the counter: a long bamboo bench (sạp tre), slat top at z ~17.3, woven skirt in front
    legs = [(u, v) for u in (0.45, 1.98, 3.55) for v in (0.92, 1.48)]
    for (u, v) in legs:
        bam(S, rng, W3(u, v, 0), W3(u, v, 15.6), 1.15, nl=6)
    for u in (0.45, 1.98, 3.55):
        bam(S, rng, W3(u, 0.88, 15.2), W3(u, 1.53, 15.2), 0.9, nl=4)
    for v in (0.92, 1.48):
        bam(S, rng, W3(0.38, v, 5.0), W3(3.62, v, 5.0), 0.7, nl=14)
    n = 12
    for i in range(n):
        v = 0.9 + 0.62 * i / (n - 1)
        bam(S, rng, W3(0.36, v, 16.4), W3(3.64, v, 16.4), 0.9, nl=16)
    plane(S, W3(0.4, 1.535, 5.4), W3(3.6, 0, 0) - W3(0.4, 0, 0), np.array([0, 0, 9.2]), 90, 8, M_WEAVE_F)
    for z in (5.4, 14.6):
        bam(S, rng, W3(0.38, 1.55, z), W3(3.62, 1.55, z), 0.55, nl=14)
    # rổ and nia at the game's product spots
    zt = 17.3
    for (u, v, kind) in ((0.72, 1.18, 'ro'), (1.17, 1.2, 'nia'), (1.62, 1.18, 'ro'), (2.07, 1.2, 'nia'), (2.52, 1.18, 'ro'), (2.97, 1.2, 'nia')):
        c = W3(u, v, zt)
        if kind == 'ro':
            lathe2(S, c, [(0, 4.4), (0.4, 5.0), (3.0, 6.4), (3.3, 6.6)], M_WEAVE_R, na=40)
            disc(S, c + np.array([0, 0, 0.35]), (0, 0, 1), 4.6, M_NIA, nr=3, na=24)
            zr = lambda r: np.where(r < 6.75, np.maximum(0.9, (r - 4.4) / 2.2 * 3.3 + 0.45), 3.9 - (r - 6.75) * 1.3)
            a0 = rng.uniform(0, math.pi)
            leaf(S, c, a0, 16.5, 7.0, zr, off=-2.2); leaf(S, c, a0 + 0.35, 15.5, 6.6, zr, lift=0.18, off=2.4)
            lathe(S, c + np.array([0, 0, 3.2]), [(0, 6.65), (0.55, 6.75), (0.6, 6.0)], M_BAMBOO, na=30)
        else:
            disc(S, c + np.array([0, 0, 0.5]), (0, 0, 1), 7.6, M_NIA, nr=6, na=32, dome=0.04)
            zr = lambda r: np.where(r < 7.3, 1.0 + 0.04 * r, np.where(r < 7.95, 1.3 + (r - 7.3) * 0.6, 1.7 - (r - 7.95) * 0.9))
            a0 = rng.uniform(0, math.pi)
            leaf(S, c, a0, 18.5, 8.0, zr, off=-2.6); leaf(S, c, a0 + 0.3, 17.5, 7.4, zr, lift=0.18, off=2.8)
            lathe(S, c + np.array([0, 0, 0.2]), [(0, 7.5), (0.9, 7.9), (1.1, 7.4)], M_BAMBOO, na=32)
    # open sacks of rice and paddy at the left end, a stool for the seller
    for (u, v, top) in ((0.2, 0.7, M_RICE), (0.21, 1.12, M_GRAIN)):
        c = W3(u, v, ZF)
        lathe(S, c, [(0, 3.6), (1.2, 4.5), (7.0, 4.7), (8.6, 4.4), (9.2, 4.9), (9.8, 5.2)], M_JUTE, na=28)
        lathe(S, c + np.array([0, 0, 9.4]), [(0, 5.25), (0.7, 5.5), (1.0, 4.9)], M_JUTE, na=28)
        disc(S, c + np.array([0, 0, 9.3]), (0, 0, 1), 4.7, top, nr=4, na=24, dome=0.25)
    c = W3(2.0, 0.66, 0)
    for (dx, dy) in ((-2.4, -2.4), (2.4, -2.4), (2.4, 2.4), (-2.4, 2.4)):
        bam(S, rng, c + np.array([dx, dy, 0]), c + np.array([dx * 0.8, dy * 0.8, 9.0]), 0.55, nl=3)
    box(S, c + np.array([-3.2, -3.2, 9.0]), c + np.array([3.2, 3.2, 10.2]), M_PLANK)
    c = W3(2.55, 0.62, ZF)                                                           # a thúng of dried fish? no: of onions
    lathe2(S, c, [(0, 3.4), (0.4, 4.2), (4.2, 5.2), (4.6, 5.3)], M_WEAVE_R, na=32)
    for k in range(9):
        an = k * 0.7; rr = 2.4 * ((k % 3) + 1) / 3
        ell(S, c + np.array([math.cos(an) * rr, math.sin(an) * rr, 4.9]), 1.1, 1.1, 1.0, M_GARLIC if k % 2 else K.M_ONION, nu=6, nvv=8)


# ---------------------------------------------------------------- front layer
def hang_chilli(S, top, L=15.0, n=26):
    tube(S, top, top + np.array([0, 0.2, -L]), 0.1, M_ROPE, nr=3, nl=4)
    for k in range(n):
        t = k / (n - 1); an = k * 2.4
        c = top + np.array([0, 0.2 * t, -1.2 - (L - 1.6) * t])
        d = nv([math.cos(an) * 0.9, math.sin(an) * 0.9, -0.45]); e1 = nv(np.cross(d, UP)); e2 = nv(np.cross(d, e1))
        ell(S, c + d * 1.0, 0.36, 0.36, 1.15, M_CHILLI, axes=(e1, e2, d), nu=5, nvv=7)


def hang_garlic(S, top, n=8):
    tube(S, top, top + np.array([0, 0, -2.6]), 0.45, M_STRAW, nr=5, nl=3)
    for k in range(n):
        c = top + np.array([(0.55 if k % 2 else -0.55), 0.3 * (k % 2), -3.3 - 1.25 * k])
        ell(S, c, 0.95, 0.9, 0.82, M_GARLIC, nu=7, nvv=9)
        tube(S, c + np.array([0, 0, 0.6]), c + np.array([-0.3 if k % 2 else 0.3, -0.3, 1.6]), 0.2, M_STRAW, nr=3, nl=2)


def hang_corn(S, top, n=5):
    tie = top + np.array([0, 0, -2.4]); tube(S, top, tie, 0.14, M_ROPE, nr=3, nl=2)
    for k in range(n):
        a = (k - (n - 1) / 2) * 0.34
        d = nv([math.sin(a), 0.22 * math.cos(k * 1.7), -math.cos(a)]); e1 = nv(np.cross(d, UP)); e2 = nv(np.cross(d, e1))
        ell(S, tie + d * 4.0, 1.05, 1.05, 3.1, M_CORN, axes=(e1, e2, d), nu=8, nvv=12)
        for j in range(3):
            b = a + (j - 1) * 0.3
            dh = nv([math.sin(b) * 1.4, 0.35 * (j - 1), 1.0]); f1 = nv(np.cross(dh, UP) + 1e-6); f2 = nv(np.cross(dh, f1))
            ell(S, tie + d * 0.6 + dh * 1.9, 0.75, 0.22, 2.1, M_HUSK, axes=(f1, f2, dh), nu=6, nvv=8)


def hang_banana(S, top):
    stem = top + np.array([0, 0, -3.0]); tube(S, top, stem, 0.16, M_ROPE, nr=3, nl=2)
    tube(S, stem + np.array([0, 0, 0.6]), stem + np.array([0, 0.4, -3.6]), 0.75, M_BANSTEM, nr=8, nl=3)
    for row in range(2):
        for k in range(6):
            a = (k - 2.5) * 0.3
            base = stem + np.array([0, 0.35 + 0.6 * row, -1.2 - 2.1 * row])
            out = nv([math.sin(a), 0.9, -0.15])                       # fingers stick out toward the front, then curl up
            mid = base + out * 3.5 + np.array([0, 0, -0.8])
            tip = mid + nv([math.sin(a) * 0.6, 0.55, 1.0]) * 4.3
            tube(S, base, mid, 0.82, M_BANANA, nr=7, nl=3, taper=1.05)
            tube(S, mid, tip, 0.86, M_BANANA, nr=7, nl=3, taper=0.45)
            ell(S, tip, 0.25, 0.25, 0.25, M_BANSTEM, nu=4, nvv=6)


def hang_hat(S, pc):
    """nón lá hung by its quai on a nail in the front of the post (pc = post centre at nail height):
    rim flat against the post, apex out toward the viewer"""
    tube(S, pc + np.array([0, 1.2, 0]), pc + np.array([0, 2.5, 0.35]), 0.28, M_HANDLE, nr=5, nl=2)      # the nail
    d = nv([0.0, 1.0, 0.1])
    Rr = 6.8
    base = pc + np.array([0.0, 2.0, -Rr - 0.9])
    cone(S, base, d, Rr, 4.6, M_HAT, na=40, nu=10)
    tube(S, base - d * 0.1, base + d * 0.25, Rr + 0.05, M_HAT, nr=40, nl=2)
    for sx in (-1, 1):                                                  # the quai, from the nail down behind the rim
        tube(S, pc + np.array([0, 2.3, 0.2]), base + np.array([sx * 3.4, 0.1, Rr * 0.66]), 0.13, M_CAP, nr=3, nl=3)


def lamp(S, c):
    """đèn bão like the quán cơm's, kho size: rust-red tin, glass chimney, wire guard; c = flame centre"""
    lb = c - np.array([0, 0, 2.6])
    lathe(S, lb, [(0, 1.5), (0.3, 1.7), (1.2, 1.6), (1.5, 0.9)], M_LAMPTIN)
    lathe(S, lb + np.array([0, 0, 1.5]), [(0, 0.9), (0.8, 1.35), (2.0, 1.45), (3.2, 1.2), (3.9, 0.8)], K.M_LAMPGLASS)
    lathe(S, lb + np.array([0, 0, 5.3]), [(0, 1.2), (0.6, 1.25), (1.2, 0.6), (1.8, 0.3)], M_LAMPTIN)
    for sg in (-1, 1):
        tube(S, lb + np.array([1.55 * sg, 0, 0.6]), lb + np.array([1.2 * sg, 0, 6.6]), 0.16, K.M_SOOT, nr=4, nl=2)
    ell(S, c, 0.35, 0.35, 0.8, K.M_FLAME, nu=6, nvv=8)


def gable(S, u):
    """leaf infill between the tie beam (z ZW) and the roof, at the end frame u"""
    def zr(v):
        return np.where(v < K.RV, K.BZ + (v - K.BV) / (K.RV - K.BV) * (K.RZ - K.BZ), K.EZ + (K.EV - v) / (K.EV - K.RV) * (K.RZ - K.EZ)) - 2.0
    v0, v1 = 0.2, 1.84
    def F(U, V):
        v = v0 + U / T; zt = zr(v)
        return np.stack([np.full_like(U, u * T), v * T, K.ZW + V * np.clip(zt - K.ZW, 0, None)], -1)
    S.grid(F, 50, 12, K.M_GABLE, (0, 0, 0), 0.0, uvr=((0, (v1 - v0) * T), (0, 1)))


def pumpkin(S, c, r, rng):
    S0 = Scene(); X3.ellipsoid(S0, c + np.array([0, 0, r * 0.68]), r, r, r * 0.68, M_PUMPKIN, nu=10, nvv=28,
                               bulge=lambda U, V: -0.3 * r / 4 * np.abs(np.sin(V * math.pi * 8)) * np.sin(U * math.pi)); S.merge(S0)
    tube(S, c + np.array([0, 0, r * 1.3]), c + np.array([0.3, 0.2, r * 1.3 + 1.4]), 0.35, M_BANSTEM, nr=6, nl=2)


def stool(S, rng, c):
    """ghế đẩu tre: four bamboo legs, rails on top, a seat of bamboo slats, low stretchers all round"""
    top = 9.6; h = 4.0
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        bam(S, rng, c + np.array([sx * h, sy * h, 0.0]), c + np.array([sx * h, sy * h, top - 0.6]), 0.75, nl=3)
    for sy in (-1, 1):
        bam(S, rng, c + np.array([-h - 0.8, sy * h, top - 1.4]), c + np.array([h + 0.8, sy * h, top - 1.4]), 0.6, nl=3)
    for sx in (-1, 1):
        bam(S, rng, c + np.array([sx * h, -h - 0.8, top - 1.9]), c + np.array([sx * h, h + 0.8, top - 1.9]), 0.55, nl=3)
    n = 7
    for i in range(n):
        y = -h - 0.3 + (2 * h + 0.6) * (i + 0.5) / n
        tube(S, c + np.array([-h - 1.1, y, top - 0.35]), c + np.array([h + 1.1, y, top - 0.35]), 0.62, M_OLDBAMBOO if i % 3 == 1 else M_BAMBOO,
             prm=(rng.random(), 0.4, 0), nr=8, nl=4)
    for (sy, z) in ((-1, 3.0), (1, 3.4)):
        bam(S, rng, c + np.array([-h - 0.2, sy * h, z]), c + np.array([h + 0.2, sy * h, z]), 0.42, nl=2)
    for (sx, z) in ((-1, 3.8), (1, 2.6)):
        bam(S, rng, c + np.array([sx * h, -h - 0.2, z]), c + np.array([sx * h, h + 0.2, z]), 0.42, nl=2)


def leaf(S, c, ang, L, Wd, zf, lift=0.0, off=0.0):
    """banana leaf blade of length L, width Wd, centred on tray centre c, lying on the surface z = zf(r) (r from c)"""
    au = np.array([math.cos(ang), math.sin(ang), 0.0]); aw = np.array([-math.sin(ang), math.cos(ang), 0.0])
    def F(U, V):
        q = np.clip(np.abs(2 * U / L), 0, 1)
        hw = Wd / 2 * (1 - q ** 2.2) ** 0.5 * (1 + 0.06 * np.sin(U * 1.7 + ang * 3))
        x = U[..., None] * au + (V * hw + off)[..., None] * aw
        r = np.hypot(x[..., 0], x[..., 1])
        z = zf(r) + 0.35 * (1 - np.abs(V)) + lift
        return c + x + z[..., None] * np.array([0, 0, 1.0])
    S.grid(F, 44, 9, M_BANLEAF, (Wd, 0, 0), uvr=((-L / 2, L / 2), (-1, 1)))


def front(S, rng):
    for u in (0.28, 3.72):
        bam(S, rng, W3(u, 1.74, 0), W3(u, 1.74, 78.4), 1.4, nl=14)
    bam(S, rng, W3(0.12, 1.76, 77.4), W3(3.88, 1.76, 77.4), 1.2, nl=16)
    # lean-to thatch roof, low at the back (z 59), high at the front (z 81), two battens
    e = W3(0.0, 0.08, 58.6); top = W3(0.0, 1.98, 81.4); up = top - e; LB = np.linalg.norm(up); su = up / LB
    ax = np.array([1.0, 0, 0]); n_out = nv(np.cross(ax, su))
    if n_out[2] < 0: n_out = -n_out
    Lu = 4.0 * T
    slope(S, rng, e, su, n_out, LB, ax, Lu, th=2.0)
    for fr in (0.36, 0.7):
        p0 = e + su * LB * fr + n_out * 1.9 + ax * 1.2
        tube(S, p0, p0 + ax * (Lu - 2.4), 0.6, M_OLDBAMBOO, prm=(rng.random(), 0.5, 0), nr=8, nl=16)
    # the high front edge: two poles clamp the thatch, tied with rattan
    p0 = e + su * (LB - 0.6) + n_out * 1.7
    tube(S, p0 - ax * 0.6, p0 + ax * (Lu + 0.6), 1.1, M_OLDBAMBOO, prm=(0.3, 0.4, 0), nr=10, nl=18)
    p1 = e + su * (LB - 0.6) - n_out * 2.6
    tube(S, p1 - ax * 0.6, p1 + ax * (Lu + 0.6), 0.9, M_OLDBAMBOO, prm=(0.6, 0.2, 0), nr=10, nl=18)
    for x in np.arange(6.0, Lu, 17.0) + rng.uniform(-1.5, 1.5, len(np.arange(6.0, Lu, 17.0))):
        cc = e + su * (LB - 0.6) + ax * x - n_out * 0.45
        pts = [cc + n_out * (2.25 * math.sin(a)) + su * (2.0 * math.cos(a)) for a in np.linspace(0, 2 * math.pi, 13)]
        for i in range(12): tube(S, pts[i], pts[i + 1], 0.24, M_RATTAN, nr=4, nl=2)
    # SẠP QUÊ board standing on the high front edge of the roof (text painted by the game), clear of the trays
    SV = 2.0
    for u in (1.4, 2.6):
        bam(S, rng, W3(u, SV - 0.03, 75.0), W3(u, SV - 0.03, 97.8), 0.65, nl=6)       # two poles lashed to the eave
        for z in (79.6, 82.0):
            tube(S, W3(u - 0.02, SV - 0.06, z), W3(u + 0.02, SV - 0.06, z + 0.3), 0.85, M_RATTAN, nr=6, nl=2)
    box(S, W3(1.22, SV, 83.0), W3(2.78, SV + 0.035, 96.0), M_SIGNW)
    for (a, b) in ((W3(1.22, SV + 0.04, 83.0), W3(2.78, SV + 0.04, 83.0)), (W3(1.22, SV + 0.04, 96.0), W3(2.78, SV + 0.04, 96.0)),
                   (W3(1.22, SV + 0.04, 83.0), W3(1.22, SV + 0.04, 96.0)), (W3(2.78, SV + 0.04, 83.0), W3(2.78, SV + 0.04, 96.0))):
        tube(S, a, b, 0.55, M_PLANK, nr=6, nl=4)
    # hung at the ends only (the middle stays clear over the trays)
    vb = 1.79
    hang_chilli(S, W3(0.46, vb, 76.4), L=15.0, n=24)
    hang_garlic(S, W3(0.61, vb, 76.4), n=8)
    hang_corn(S, W3(0.76, vb, 76.4), n=4)
    hang_banana(S, W3(3.87, vb, 76.4))
    hang_chilli(S, W3(3.6, vb, 76.4), L=12.0, n=20)
    # nón lá hung on the left front post
    hang_hat(S, W3(0.28, 1.74, 38.0))
    # đèn bão hung on a wire from the front beam, over the left end of the counter
    tube(S, W3(LANT[0], LANT[1], 76.6), W3(*LANT) + np.array([0, 0, 4.4]), 0.16, K.M_SOOT, nr=4, nl=2)
    lamp(S, W3(*LANT))
    # produce on the ground in front of the counter
    for (u, v, r) in ((0.52, 1.8, 3.6), (0.7, 1.86, 3.0), (0.6, 1.66, 2.7)):
        pumpkin(S, W3(u, v, ZF), r, rng)
    c = W3(1.42, 1.82, ZF)                                                          # thúng of green coconuts
    lathe2(S, c, [(0, 4.2), (0.4, 5.0), (5.0, 6.2), (5.4, 6.3)], M_WEAVE_R, na=40)
    for k in range(7):
        an = k * 0.9 + 0.3; rr = 3.2 * ((k % 3) + 0.4) / 2.4
        ell(S, c + np.array([math.cos(an) * rr, math.sin(an) * rr, 5.6 + (k % 2) * 0.8]), 2.1, 2.1, 2.4, M_COCOG, nu=8, nvv=12)
    ell(S, c + np.array([0, 0, 8.2]), 2.0, 2.0, 2.3, M_COCOG, nu=8, nvv=12)
    for (u, v, k) in ((2.22, 1.84, 1.0), (2.42, 1.86, 0.92)):                     # dưa hấu
        ax_m = nv([0.9, 0.35 - k, 0]); ay_m = nv(np.cross(UP, ax_m))
        ell(S, W3(u, v, ZF + 3.6 * k), 3.6 * k, 3.6 * k, 4.8 * k, M_MELON, axes=(ay_m, UP, ax_m), nu=12, nvv=26)
    ell(S, W3(2.32, 1.82, ZF + 9.4), 3.2, 3.2, 4.3, M_MELON, axes=(nv([0, 1, 0]), UP, nv([1, 0, 0])), nu=12, nvv=26)
    c = W3(3.81, 1.64, 0)                                                           # crate of oranges
    box(S, c + np.array([-4.6, -4.2, 0]), c + np.array([4.6, 4.2, 10.0]), M_CRATE)
    for k in range(9):
        x = (k % 3 - 1) * 2.9; y = (k // 3 - 1) * 2.6
        ell(S, c + np.array([x + rng.uniform(-0.3, 0.3), y, 11.2 + 0.3 * (k % 2)]), 1.6, 1.6, 1.5, M_ORANGE if k % 4 else M_REDFRUIT, nu=7, nvv=10)
    ell(S, c + np.array([-1.2, 0.8, 13.6]), 1.5, 1.5, 1.4, M_ORANGE, nu=7, nvv=10)
    ell(S, c + np.array([1.5, -0.4, 13.5]), 1.5, 1.5, 1.4, M_ORANGE, nu=7, nvv=10)
    stool(S, rng, W3(3.74, 0.66, ZF))                                               # ghế đẩu tre for the seller


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear()
    K.LIGHTS2.append((W3(*LANT), hexc('#ff9645'), 16.0, 3.2, 'all'))            # as soft as the nhà tranh's (Link 15:51)
    K.GLOWS[:] = [(W3(*LANT), 0.2, 0.85)]
    back(S, rng)
    ns0 = S.ns
    if with_props: front(S, rng)
    return S, (ns0, S.ns)


K.build = build

if __name__ == '__main__':
    from PIL import Image
    if sys.argv[1] == 'prev':
        part = sys.argv[3] if len(sys.argv) > 3 else 'b'; n = len(sys.argv) > 4 and sys.argv[4] == 'n'
        if part == 'all':
            b = K.render(1, n, 'b'); f = K.render(1, n, 'f'); b.alpha_composite(f); b.save(sys.argv[2])
        else: K.render(1, n, part).save(sys.argv[2])
    elif sys.argv[1] == 'atlas':
        sys.argv = [sys.argv[0], 'atlas', sys.argv[2], sys.argv[3]]
        out, tab = sys.argv[2], sys.argv[3]
        frames = {}
        for part in ('b', 'f'):
            for n in (0, 1):
                im = K.render(1, bool(n), part); bb = im.getbbox(); frames[part + ('n' if n else 'd')] = (im.crop(bb), bb)
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
