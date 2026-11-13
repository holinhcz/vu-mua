# Bến ghe (game id ben 2x3, mirror ben2; ben3 2x3 facing the other way, mirror ben4) as a real 3D model in the kho
# kit, same family as the giếng / miếu / lò gạch (Link 2026-11-09 17:47: "vẽ tiếp bến ghe đi, 4 hướng, vẽ lại cho hợp
# lí từng điểm ảnh"). Sơ cấp, miền Tây: gỗ tràm + tre only.
#  - a narrow walkway of round tre laid across two tràm stringers, on pairs of round tràm posts standing in the water,
#    a tre ladder (nấc thang tre) up from the bank at the land end
#  - a wider landing at the water end, a tre handrail on one side, two tall tràm mooring posts with rope wound on them,
#    tre rungs down to the water off the end
#  - no boat (Link 2026-11-10)
#  - on the landing: a nón lá, a giỏ tre, a coil of rope; a đèn bão hanging off a tràm pole at the land end
# D = 0: land at v 0, water toward +v (front-left, the old bến).  D = 1: land at v 3, water toward -v (back).
#   python3 benghe3d.py prev OUT.png D [n]        python3 benghe3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'kho'))
import kho3d as K
from kho3d import (W3, T, nv, UP, Scene, X3, hexc, smooth, vnoise, plane, tube, disc, lathe, mat_flat, MATS,
                   M_RATTAN, M_WOOD, M_BARK, M_OLDBAMBOO, M_PLANK, M_SOOT, M_BAMBOO, M_EARTH, M_EARTHSIDE,
                   M_LAMPGLASS, M_FLAME)

K.BB = (-112, -104, 112, 70)
K.OX, K.OY = 16, -40                         # at.P(2,3)
ZF = 0.0
K.ZF = ZF
K.WU0, K.WU1, K.WV0, K.WV1 = -9, -9, -9, -9   # nothing is under a roof
K.FOOT = ('ben',)                            # nhận xét 9: the water under the deck in shade, the deck's own outline (see foot())
_rrect = K.rrect


def foot(*a):
    """K.render draws its ground shade from rrect(*FOOT); for the bến that is the deck outline (walkway + landing)"""
    if a != ('ben',): return _rrect(*a)
    pts = [(WA0 - 0.03, BK), (WA1 + 0.03, BK), (WA1 + 0.03, PB0), (PA1 + 0.03, PB0), (PA1 + 0.03, PB1 + 0.04),
           (PA0 - 0.03, PB1 + 0.04), (PA0 - 0.03, PB0), (WA0 - 0.03, PB0)]
    out = []
    for a_, b_ in pts:
        q = P(a_, b_, 0); out.append((q[0], q[1]))
    return out


K.rrect = foot
K.SHEET = 'benghe.webp'
K.SEED = 9300
K.GS_K, K.FOOT_K = 0.22, 0.16                # nhận xét 2026-11-10 03:00 #3: the shade under the deck was a black patch
K.GROUND_SHADOW = True                       # nhận xét 9: the deck, posts and xuồng throw their shade on the water
K.NOSHADOW = set()
D = 0
ZD = 10.0                                    # deck top: high enough that the stilts read (nhận xét 3)
WA0, WA1 = 0.79, 1.21                        # walkway across a: one person wide (nhận xét 1)
PA0, PA1, PB0, PB1 = 0.52, 1.48, 2.15, 2.86  # landing at the water end
BK = 0.44                                    # the walkway starts at BK on two posts; the tre ladder runs from b 0 up to it
LAMP = (1.12, 0.5, 23.0)                     # đèn bão flame centre, hung over the walkway from the first rail post


def P(a, b, z):
    """local (a across, b from the bank out to the water, z) -> world for direction D"""
    return W3(a, b if D == 0 else 3.0 - b, z)


def mat_tram(uv, prm, pos, nrm):
    """tràm post standing in the river: bark greyed, dark wet band and a little slime up from the waterline"""
    col, n = MATS[M_BARK](uv, prm, pos, nrm)
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    # nhận xét 10: tràm bark is pale grey and papery, peeling in long vertical strips with dark cracks between
    w = (x + y) * 0.9 + prm[:, 0] * 40
    st = vnoise(w, z * 0.09, 3.0); fine = vnoise(w * 3.0, z * 0.25, 7.0)
    bark = hexc('#b8af9a')[None] * (0.84 + 0.2 * st + 0.08 * fine)[:, None]     # 03:00 #2: pale silver tràm, not brown
    crack = smooth(0.64, 0.74, fine) * 0.4
    bark = bark * (1 - crack[:, None]) + hexc('#4a3f33')[None] * crack[:, None]
    peel = smooth(0.7, 0.78, vnoise(w * 0.7 + 3, z * 0.05, 9.0))
    bark = bark * (1 - 0.45 * peel[:, None]) + hexc('#a57a55')[None] * (0.45 * peel[:, None])   # the red-brown under the paper
    col = col * 0.12 + bark * 0.88
    wet = 1 - smooth(ZF + 1.5, ZF + 4.0 + 1.2 * vnoise(x * 0.6, y * 0.6, 2.0), z)
    col = col * (1 - 0.4 * wet)[:, None] + hexc('#3a3f2a')[None] * (0.12 * wet)[:, None]
    return np.clip(col, 0, 1), n


def mat_tcut(uv, prm, pos, nrm):
    x, y = pos[:, 0], pos[:, 1]
    base = hexc('#a89a82')[None] * (0.82 + 0.22 * vnoise(x * 3, y * 3, 4.0))[:, None]
    return np.clip(base, 0, 1), nrm


def mat_non(uv, prm, pos, nrm):
    """nón lá: pale palm leaf, fine radial ribs, the rings of the frame showing through"""
    r, th = uv[:, 0], uv[:, 1]
    g = 0.92 + 0.06 * np.sin(th * 2 * math.pi * 40) + 0.04 * vnoise(th * 30, r * 4, 3.0)
    ring = 1 - 0.08 * (np.abs(np.sin(r * math.pi * 7)) < 0.15)
    return np.clip(hexc('#c4b285')[None] * (g * ring)[:, None], 0, 1), nrm   # nhận xét 7: an old nón, not white


def mat_gio(uv, prm, pos, nrm):
    """giỏ tre: woven split bamboo, diagonal weave"""
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    a = (x - y) * 1.1; b = z * 1.1
    w = (np.floor(a + b) + np.floor(a - b)) % 2
    col = hexc('#a88a5a')[None] * (0.74 + 0.3 * w + 0.05 * vnoise(a, b * 9, 2.0))[:, None]
    return np.clip(col, 0, 1), nrm


def mat_deck(uv, prm, pos, nrm):
    """the deck tre: old and sun-bleached, pale straw (Link 03:00: it read too dark next to the cầu tre and the đình)"""
    col, n = MATS[M_BAMBOO](uv, prm, pos, nrm)
    g = col.mean(axis=1, keepdims=True)
    col = (col * 0.62 + g * 0.38) * 0.8 + hexc('#c8b890')[None] * 0.1     # 03:00 #1 + 03:21 one tone down: sun-bleached straw, at the đình's brightness
    return np.clip(col, 0, 1), n


def mat_rip(uv, prm, pos, nrm):
    """the little ring of disturbed water round a post or the hull"""
    return np.tile(hexc('#8fb2ac')[None], (len(uv), 1)), nrm


def mat_tin(uv, prm, pos, nrm):
    """đèn bão tin: old dark tin, rust on it"""
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    r = smooth(0.55, 0.75, vnoise(x * 2, y * 2 + z * 2, 5.0))
    col = hexc('#3e3a34')[None] * (1 - r[:, None]) + hexc('#7a4a2a')[None] * r[:, None]
    return np.clip(col, 0, 1), nrm


M_TRAM, M_TCUT, M_NON, M_GIO, M_ROPE, M_DECK, M_DARK, M_RIP, M_TIN = range(170, 179)
MATS.update({M_TRAM: mat_tram, M_TCUT: mat_tcut, M_NON: mat_non, M_GIO: mat_gio,
             M_ROPE: mat_flat('#8e7048'), M_DECK: mat_deck, M_DARK: mat_flat('#2a2218'), M_RIP: mat_rip, M_TIN: mat_tin})
K.NORECV = getattr(K, 'NORECV', set()) | {M_RIP}


def post(S, rng, a, b, z1, r=1.35, ring=True):
    q = P(a, b, ZF)
    lean = (rng.random() - 0.5) * 0.6
    top = P(a + lean / T, b + (rng.random() - 0.5) * 0.5 / T, z1)
    tube(S, q, top, r, M_TRAM, prm=(rng.random(), 0, 0), nr=9, nl=8, taper=0.92)
    disc(S, top, (0, 0, 1), r * 0.88, M_TCUT, nr=2, na=10)
    if ring: ripple(S, q, r + 0.9)
    return top


def ripple(S, c, R, n=18):
    """a thin pale ring on the water round something standing in it (nhận xét 3)"""
    for k in range(n):
        t0 = 2 * math.pi * k / n; t1 = 2 * math.pi * (k + 1.05) / n
        tube(S, c + np.array([R * math.cos(t0), R * math.sin(t0), 0.12]), c + np.array([R * math.cos(t1), R * math.sin(t1), 0.12]),
             0.17, M_RIP, nr=3, nl=2)


def wind(S, c, r, z0, n, mat=M_ROPE):
    """a few turns of rope round a post"""
    for k in range(n):
        lathe(S, c + np.array([0, 0, z0 + k * 0.42]), [(0, r), (0.4, r + 0.05)], mat, na=14)


def quad(S, p00, p10, p01, p11, mat, nu=4, nv_=4, prm=(0, 0, 0), flip=False):
    p00, p10, p01, p11 = (np.asarray(p, float) for p in (p00, p10, p01, p11))
    def F(U, V):
        U = U[..., None]; V = V[..., None]
        return (1 - U) * (1 - V) * p00 + U * (1 - V) * p10 + (1 - U) * V * p01 + U * V * p11
    S.grid(F, nu, nv_, mat, prm, 0.0, flip=flip)


def rope(S, p0, p1, sag, r=0.22, n=10):
    """a rope hanging between two points (nhận xét 5: not a stiff stick)"""
    pts = [p0 + (p1 - p0) * (k / n) - np.array([0, 0, sag * 4 * (k / n) * (1 - k / n)]) for k in range(n + 1)]
    for k in range(n):
        tube(S, pts[k], pts[k + 1], r, M_ROPE, nr=4, nl=2)


def lamp(S, c):
    """đèn bão, small: old dark tin base and cap, glass chimney, flame (nhận xét 6)"""
    k = 0.72
    lb = c - np.array([0, 0, 2.6 * k])
    lathe(S, lb, [(0, 1.5 * k), (0.3 * k, 1.7 * k), (1.2 * k, 1.6 * k), (1.5 * k, 0.9 * k)], M_TIN)
    lathe(S, lb + np.array([0, 0, 1.5 * k]), [(0, 0.9 * k), (0.8 * k, 1.35 * k), (2.0 * k, 1.45 * k), (3.2 * k, 1.2 * k), (3.9 * k, 0.8 * k)], M_LAMPGLASS)
    lathe(S, lb + np.array([0, 0, 5.3 * k]), [(0, 1.2 * k), (0.6 * k, 1.25 * k), (1.2 * k, 0.6 * k), (1.8 * k, 0.3 * k)], M_TIN)
    for sg in (-1, 1):
        tube(S, lb + np.array([1.55 * k * sg, 0, 0.6 * k]), lb + np.array([1.2 * k * sg, 0, 6.6 * k]), 0.12, M_TIN, nr=4, nl=2)
    S0 = Scene(); X3.ellipsoid(S0, c, 0.28, 0.28, 0.62, M_FLAME, nu=6, nvv=8); S.merge(S0)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear(); K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
    # --- the land end (Link 2026-11-10 02:46: "bỏ bệ đất, thay bằng nấc thang tre"): two tràm posts on the bank carry the
    #     walkway end; a tre ladder (two cây tre side rails, round tre rungs lashed across) leans from the ground up to the deck
    for a in (WA0 + 0.03, WA1 - 0.03):
        post(S, rng, a, BK + 0.02, ZD - 1.7, r=1.25, ring=False)
    tube(S, P(WA0 - 0.05, BK + 0.02, ZD - 2.0), P(WA1 + 0.05, BK + 0.02, ZD - 2.0), 0.75, M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=4)
    LB0, LB1 = 0.15, BK - 0.02                                                    # ladder foot on the ground .. top at the deck
    la0, la1 = WA0 + 0.07, WA1 - 0.07
    for a in (la0, la1):                                                           # side rails, ends poke past the top
        tube(S, P(a, LB0 - 0.02, ZF), P(a, LB1 + 0.03, ZD + 1.6), 0.68, M_DECK, prm=(rng.random(), 0.5, 0), nr=7, nl=8)
    NR = 4
    for k in range(NR):                                                            # nấc thang: round tre rungs, a bit uneven
        t = (k + 0.8) / (NR + 0.35)
        bb = LB0 - 0.02 + (LB1 + 0.03 - LB0 + 0.02) * t; z = ZF + (ZD + 1.6 - ZF) * t - 0.1
        jt = (rng.random() - 0.5) * 0.35
        tube(S, P(la0 - 0.035, bb, z + jt), P(la1 + 0.035, bb, z - jt), 0.5, M_DECK, prm=(rng.random(), 0.5, 0), nr=6, nl=4)
        for a in (la0, la1):                                                       # mây lashing at each joint
            tube(S, P(a, bb - 0.012, z - 0.5), P(a, bb + 0.012, z + 0.6), 0.66, M_ROPE, nr=5, nl=2)
    # --- posts: walkway pairs, landing rows, all pale round tràm standing in the water
    WP = (0.78, 1.26, 1.74)
    for b in WP:
        for a in (WA0 + 0.03, WA1 - 0.03):
            post(S, rng, a, b, ZD - 1.7)
    LP = (PB0 + 0.05, 2.5, PB1 - 0.04)
    for b in LP:
        for a in (PA0 + 0.04, PA1 - 0.04):
            post(S, rng, a, b, ZD - 1.7)
    post(S, rng, 1.0, PB1 - 0.04, ZD - 1.7)
    # tall mooring posts at the two outer corners of the landing, rope wound round them
    m1 = post(S, rng, PA0 - 0.05, PB1 + 0.07, 26.0, r=1.45); wind(S, m1 - np.array([0, 0, 26.0 - 17.0]), 1.65, 0, 4)
    m2 = post(S, rng, PA1 + 0.05, PB1 + 0.07, 22.0, r=1.45); wind(S, m2 - np.array([0, 0, 22.0 - 14.0]), 1.65, 0, 3)
    # cross beams on each post row, stringers along b
    for b in WP:
        tube(S, P(WA0 - 0.05, b, ZD - 2.0), P(WA1 + 0.05, b, ZD - 2.0), 0.75, M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=4)
    for b in LP:
        tube(S, P(PA0 - 0.04, b, ZD - 2.0), P(PA1 + 0.04, b, ZD - 2.0), 0.75, M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=4)
    for a in (WA0 + 0.035, WA1 - 0.035):
        tube(S, P(a, BK - 0.04, ZD - 1.15), P(a, PB0 + 0.12, ZD - 1.15), 0.72, M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=10)
    for a in (PA0 + 0.04, 0.84, 1.16, PA1 - 0.04):
        tube(S, P(a, PB0 - 0.02, ZD - 1.15), P(a, PB1 + 0.02, ZD - 1.15), 0.72, M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=6)
    # giằng chéo (nhận xét 3): X braces between the walkway posts on both sides, and across the landing rows
    for a in (WA0 + 0.03, WA1 - 0.03):
        for b0, b1 in zip(WP, WP[1:]):
            tube(S, P(a, b0, 1.2), P(a, b1, ZD - 2.4), 0.42, M_TRAM, prm=(rng.random(), 0, 0), nr=5, nl=4)
    for b in (WP[1], LP[1]):
        aa0, aa1 = (WA0 + 0.03, WA1 - 0.03) if b == WP[1] else (PA0 + 0.04, PA1 - 0.04)
        tube(S, P(aa0, b, 1.4), P(aa1, b, ZD - 2.6), 0.42, M_TRAM, prm=(rng.random(), 0, 0), nr=5, nl=4)
    # --- the deck: round tre across, one continuous run (nhận xét 2), each one a little different in length, size, set
    step = 1.3 / T
    b = BK - 0.01
    while b < PB1 + 0.03:
        land = b >= PB0 - 0.005
        aa0, aa1 = (PA0 - 0.03, PA1 + 0.03) if land else (WA0 - 0.04, WA1 + 0.04)
        aa0 -= 0.035 * rng.random(); aa1 += 0.035 * rng.random()
        r = 0.6 + 0.12 * (rng.random() - 0.5)
        dz = 0.18 * (rng.random() - 0.5)
        tube(S, P(aa0, b, ZD - 0.5 + dz), P(aa1, b + 0.006 * (rng.random() - 0.5), ZD - 0.5 - dz), r, M_DECK,
             prm=(rng.random(), rng.random(), 0), nr=6, nl=4)
        b += step * (0.94 + 0.12 * rng.random())
    for bb in np.arange(BK + 0.12, PB1, 0.3):                                     # mây lashings on the stringers
        for a in ((WA0 + 0.035, WA1 - 0.035) if bb < PB0 else (PA0 + 0.04, PA1 - 0.04)):
            X3.ellipsoid(S, P(a, bb, ZD + 0.05), 0.45, 0.45, 0.45, M_RATTAN, nu=4, nvv=5)
    # --- handrail (nhận xét 4): one straight tre rail on the right of the walkway only, on short tràm posts
    RB = (0.5, 1.02, 1.54, 2.06)
    for bb in RB:
        tube(S, P(WA1 + 0.02, bb, ZD - 1.0), P(WA1 + 0.02, bb, (ZD + 26.0) if bb == RB[0] else (ZD + 10.5)), 0.68,
             M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=6)
        if bb != RB[0]: disc(S, P(WA1 + 0.02, bb, ZD + 10.5), (0, 0, 1), 0.6, M_TCUT, nr=2, na=8)
    tube(S, P(WA1 + 0.02, RB[0] - 0.02, ZD + 9.6), P(WA1 + 0.02, RB[-1] + 0.03, ZD + 9.6), 0.72, M_DECK, prm=(0.4, 0.3, 0), nr=6, nl=10)
    for bb in RB:
        X3.ellipsoid(S, P(WA1 + 0.02, bb, ZD + 9.6), 0.75, 0.75, 0.6, M_RATTAN, nu=4, nvv=5)
    # --- đèn bão (nhận xét 6): small, hung from a short tre arm off the first rail post, over the walkway
    tp = P(WA1 + 0.02, RB[0], ZD + 26.0)
    disc(S, tp, (0, 0, 1), 0.6, M_TCUT, nr=2, na=8)
    tube(S, P(WA1 + 0.02, RB[0], ZD + 24.5), P(LAMP[0], LAMP[1], ZD + 24.8), 0.38, M_DECK, prm=(0.6, 0.2, 0), nr=5, nl=3)
    tube(S, P(LAMP[0], LAMP[1], ZD + 24.6), P(*LAMP) + np.array([0, 0, 2.6]), 0.11, M_TIN, nr=4, nl=2)
    lamp(S, P(*LAMP))
    K.LIGHTS2.append((P(*LAMP), hexc('#ff9645'), 13.0, 2.0, 'all'))
    K.GLOWS[:] = [(P(*LAMP), 0.16, 0.8)]
    # --- on the landing, spread out (nhận xét 7): an old nón lá, a giỏ cá, a loose coil of rope by the left post
    nc = P(0.78, 2.36, ZD + 0.2)
    lathe(S, nc, [(0, 4.3), (0.25, 4.0), (2.9, 0.25), (3.05, 0.0)], M_NON, na=28)
    gc = P(1.3, 2.66, ZD + 0.2)
    lathe(S, gc, [(0, 1.5), (0.5, 2.5), (2.4, 2.9), (3.8, 1.7), (4.4, 1.3), (5.0, 1.7), (5.2, 1.85)], M_GIO, na=22)  # bầu giỏ, cổ thắt, miệng loe
    disc(S, gc + np.array([0, 0, 4.9]), (0, 0, 1), 1.45, M_DARK, nr=2, na=14)
    lathe(S, gc + np.array([0, 0, 4.95]), [(0, 1.8), (0.3, 1.9), (0.5, 1.8)], M_RATTAN, na=16)
    rc = P(0.66, 2.74, ZD + 0.35)
    prev = None
    for k in range(61):
        th = k / 60 * 2 * math.pi * 2.6; r = 1.0 + 2.1 * k / 60
        q = rc + np.array([r * math.cos(th), r * math.sin(th), 0.1 * math.sin(k * 0.7)])
        if prev is not None: tube(S, prev, q, 0.36, M_ROPE, nr=4, nl=2)
        prev = q
    rope(S, prev, m1 - np.array([0, 0, 26.0 - 16.6]), 1.2, r=0.3, n=6)
    # tre rungs down to the water off the end, between the landing's middle posts
    for z in (6.5, 3.5):
        tube(S, P(0.88, PB1 + 0.05, z), P(1.12, PB1 + 0.05, z), 0.5, M_DECK, prm=(rng.random(), 0.4, 0), nr=5, nl=3)
    for a in (0.88, 1.12):
        tube(S, P(a, PB1 + 0.06, ZF), P(a, PB1 + 0.06, ZD - 1.0), 0.45, M_TRAM, prm=(rng.random(), 0, 0), nr=5, nl=3)
    # (no xuồng: Link 2026-11-10 'bến ghe bỏ con thuyền')
    return S, (S.ns, S.ns)


K.build = build

if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        D = int(sys.argv[3]); n = len(sys.argv) > 4 and sys.argv[4] == 'n'
        K.render(1, n, 'b').save(sys.argv[2])
    elif sys.argv[1] == 'atlas':
        out, tab = sys.argv[2], sys.argv[3]
        G = {}; frames = {}
        for d in (0, 1):
            D = d
            for n in (0, 1):
                im = K.render(1, bool(n), 'b'); bb = im.getbbox(); frames[str(d) + ('n' if n else 'd')] = (im.crop(bb), bb)
        keys = ['0d', '0n', '1d', '1n']; sc = float(K.PXU); BB = K.BB
        Wd = sum(frames[k][0].width + 2 for k in keys[:2]); Hh = frames['0d'][0].height + frames['1d'][0].height + 2
        Wd = max(Wd, sum(frames[k][0].width + 2 for k in keys[2:]))
        sheet = Image.new('RGBA', (Wd, Hh), (0, 0, 0, 0)); y = 0
        for row in (keys[:2], keys[2:]):
            x = 0
            for k in row:
                im, bb = frames[k]; sheet.paste(im, (x, y))
                G[k] = [x, y, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
                x += im.width + 2
            y += max(frames[k][0].height for k in row) + 2
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, K.SHEET), 'WEBP', quality=92, method=6); json.dump(G, open(tab, 'w'))
        print('sheet', sheet.size)
