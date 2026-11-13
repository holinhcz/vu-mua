# Chuồng gà (game pen "ga", 2x2) as a real 3D model in the kho kit, same family and light as the bến ghe / cầu khỉ
# (Link 2026-11-10 04:31: "giờ làm lại chuồng gà đi"). Sơ cấp, miền Tây: tre + tràm + lá only.
#  - sân đất nện inside, a little rơm scattered, trodden darker by the gate and the máng
#  - rào tre: split-tre stakes set close (gà không chui lọt), two round tre rails, round tràm posts at the corners and
#    the middles, a tre gate (khung tre, giằng chéo) on the front side, hung on mây loops
#  - the chuồng ngủ in the back corner: a little house on four tràm stilts, floor of round tre, walls of phên tre
#    (woven back + left, slats with gaps on the right + front), a door with a tre cầu thang gà down to the yard, a lá
#    roof sloping to the front; a thúng ổ đẻ with rơm and two eggs beside it
#  - a máng ăn (half a big tre, split) along the left fence and a lu nước sành
#  - night: a small đèn dầu hung under the front eave by the door, its light on the cầu thang and the yard in front
# The game draws chickens walking inside, so the sheet is cut in layers by depth (see LAYERS): ground (under
# everything), back (fence back sides + the house, before the chickens), and the front fence in four one-tile pieces,
# each sorted with the game's objects at its own depth.
#   python3 chuongga3d.py prev OUT.png [n]          python3 chuongga3d.py atlas OUTDIR atlas.json
import math, sys, os, json
os.environ.setdefault('LADINH', '1')               # the đình's lá on every 3D building (live v964 rule)
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'benghe'))
import benghe3d as BG                              # imports kho3d, registers M_TRAM, M_TCUT, M_DECK, M_ROPE ...
K = BG.K
from kho3d import (W3, T, Scene, X3, hexc, smooth, vnoise, hash1, plane, tube, disc, lathe, mat_flat, MATS, box, obox,
                   M_RATTAN, M_LEAF, M_THEND, M_WEAVE_F, M_WEAVE_R, M_OLDBAMBOO, M_LAMPGLASS, M_FLAME)
import den

BG.D = 0
K.rrect = BG._rrect
K.BB = (-72, -56, 72, 74)                          # world (0,0,0) = the pen's back tile corner = en(gx, gy)
K.OX, K.OY = 0, 0
K.WU0, K.WU1, K.WV0, K.WV1 = -9, -9, -9, -9
K.SHEET = 'chuongga.webp'
K.SEED = 9500
if os.environ.get('CG_PXU'): K.PXU = int(os.environ['CG_PXU'])
K.GS_K, K.FOOT_K = 0.22, 0.1
K.GROUND_SHADOW = True
K.NOSHADOW = set()
K.PATCH = None
K.ZF = 0.0
P = W3
M_TRAM, M_TCUT, M_DECK, M_ROPE, M_TIN = BG.M_TRAM, BG.M_TCUT, BG.M_DECK, BG.M_ROPE, BG.M_TIN

# --- layout (tiles)
F0, F1 = 0.05, 1.95                                # fence line
HU0, HU1, HV0, HV1 = 0.14, 1.06, 0.13, 0.62        # chuồng ngủ footprint (stilt centres)
ZS = 13.0                                          # its floor top (a chicken walks under it)
ZE_F, ZE_B = 38.0, 32.5                            # Link 08:47 fix: 5 chuồng cùng cao (= bò/cừu/dê)                            # wall tops: front high, back low (Link 05:20: mái ngược lại, see inside)
DOOR = (0.62, 0.84)                                # door in the front wall (u)
GATE = (1.0, 1.4)                                # gate in the front fence (u, on v = F1)
FH = 14.0                                          # fence stake height
LAMP = (0.5, HV1 + 0.09, 25.0)
K.RZ, K.EZ = ZE_F + 3.0, ZE_B - 1.0                # mat_leaf weathering: sun-bleached near the top, rain-dark at the eave
K.FOOT = (HU0 - 0.04, HU1 + 0.04, HV0 - 0.04, HV1 + 0.06, 0.06)


def mat_yard(uv, prm, pos, nrm):
    """sân đất nện of a chicken run: grey-brown packed earth, scratched, trodden darker by the gate and the máng"""
    x, y = pos[:, 0] / T, pos[:, 1] / T
    n1 = vnoise(x * 5, y * 5, 3.0); n2 = vnoise(x * 24, y * 24, 7.0); n3 = vnoise(x * 70, y * 70, 9.0)
    base = hexc('#b49a76')[None] * (0.9 + 0.1 * n1 + 0.06 * n2 + 0.04 * n3)[:, None]
    tr = np.exp(-((x - 1.42) ** 2 / 0.05 + (y - 1.8) ** 2 / 0.06)) + 0.8 * np.exp(-((x - 0.42) ** 2 / 0.03 + (y - 1.2) ** 2 / 0.12))
    base = base * (1 - 0.1 * np.clip(tr, 0, 1))[:, None]
    sc = smooth(0.82, 0.9, vnoise(x * 40 + y * 9, y * 40 - x * 9, 5.0)) * 0.12            # chicken scratch marks
    base = base * (1 - sc)[:, None]
    g = hash1(np.floor(x * 90), np.floor(y * 90), 11.0)
    base = np.where((g > 0.992)[:, None], base * 0.84, base)
    ex = np.minimum(np.minimum(x - F0, F1 - x), np.minimum(y - F0, F1 - y))               # a little grass creeps in under the fence
    gr = smooth(0.06, 0.0, ex) * smooth(0.45, 0.65, vnoise(x * 18, y * 18, 4.0))
    base = base * (1 - 0.5 * gr)[:, None] + hexc('#7d8a4a')[None] * (0.5 * gr)[:, None]
    return np.clip(base, 0, 1), nrm


def mat_yardside(uv, prm, pos, nrm):
    return np.tile(hexc('#9a8262')[None], (len(uv), 1)) * (0.9 + 0.1 * vnoise(pos[:, 0] * 0.3, pos[:, 2] * 2, 2.0))[:, None], nrm


def mat_slat(uv, prm, pos, nrm):
    """nẹp tre (split bamboo stake): the outer skin, greyed by sun, each stake its own tone"""
    col, n = MATS[M_DECK](uv, prm, pos, nrm)
    t = 0.9 + 0.16 * prm[:, 0][:, None]
    return np.clip(col * t, 0, 1), n


def mat_straw(uv, prm, pos, nrm):
    t = 0.85 + 0.25 * hash1(prm[:, 0] * 97, 3.0)
    return np.clip(hexc('#c4ad78')[None] * t[:, None], 0, 1), nrm


def mat_egg(uv, prm, pos, nrm):
    return np.tile(hexc('#efe2c8')[None], (len(uv), 1)), nrm


def mat_sanh(uv, prm, pos, nrm):
    """lu sành: dark brown glaze, a paler lip"""
    z = pos[:, 2]
    col = hexc('#5a3e28')[None] * (0.9 + 0.12 * vnoise(pos[:, 0] * 0.4, z * 0.8, 3.0))[:, None]
    return np.clip(col, 0, 1), nrm


def mat_water(uv, prm, pos, nrm):
    """clear water like the ao/sông (Link 06:17: trong xanh, not murky): the river's mid colour, a pale sky glint"""
    x, y = pos[:, 0], pos[:, 1]
    col = hexc('#3f86b8')[None] * (0.95 + 0.08 * vnoise(x * 2, y * 2, 3.0))[:, None]   # Link 08:47: xanh dương như ao (= cừu/dê)
    gl = smooth(0.66, 0.84, vnoise(x * 1.3 + y, y * 0.6, 5.0))[:, None] * 0.35
    return np.clip(col * (1 - gl) + hexc('#bfe2f4')[None] * gl, 0, 1), nrm


def mat_grain(uv, prm, pos, nrm):
    """lúa / tấm in the máng"""
    x, y = pos[:, 0], pos[:, 1]
    return np.clip(hexc('#9a8656')[None] * (0.8 + 0.3 * vnoise(x * 3, y * 3, 6.0))[:, None], 0, 1), nrm


M_YARD, M_YARDSIDE, M_SLAT, M_STRAW, M_EGG, M_SANH, M_WATER2, M_GRAIN2, M_GDARK = range(190, 199)
MATS.update({M_YARD: mat_yard, M_YARDSIDE: mat_yardside, M_SLAT: mat_slat, M_STRAW: mat_straw, M_EGG: mat_egg,
             M_SANH: mat_sanh, M_WATER2: mat_water, M_GRAIN2: mat_grain, M_GDARK: mat_flat('#3a2c1e')})
K.GLOSS[M_SANH] = (0.35, 30.0)
K.GLOSS[M_WATER2] = (0.6, 60.0)

def mat_tram_doc(uv, prm, pos, nrm):
    """Link 08:47: one tràm for all 5 chuồng = the bò/cừu/dê post (bark streaks along the pole, no spotted bands)"""
    L, A = uv[:, 0], uv[:, 1] * 6.0 + prm[:, 0] * 40
    st = vnoise(L * 0.09, A, 3.0); fine = vnoise(L * 0.3, A * 3.0, 7.0)
    bark = hexc('#b4ab96')[None] * (0.86 + 0.16 * st + 0.07 * fine)[:, None]
    crack = smooth(0.7, 0.8, fine) * 0.22
    bark = bark * (1 - crack[:, None]) + hexc('#4a3f33')[None] * crack[:, None]
    peel = smooth(0.74, 0.8, vnoise(L * 0.05 + 3, A * 0.7, 9.0))
    bark = bark * (1 - 0.14 * peel[:, None]) + hexc('#a57a55')[None] * (0.14 * peel[:, None])
    return np.clip(bark, 0, 1), nrm


MATS[M_TRAM] = mat_tram_doc



def lash(S, c, r=0.7):
    X3.ellipsoid(S, c, r, r, r * 0.8, M_ROPE, nu=4, nvv=5)


def tram(S, rng, u, v, z1, r=1.2, z0=0.0):
    top = P(u, v, z1)                                   # straight post (Link 08:47)
    tube(S, P(u, v, z0), top, r, M_TRAM, prm=(rng.random(), 0, 0), nr=9, nl=6, taper=0.9)
    disc(S, top, (0, 0, 1), r * 0.88, M_TCUT, nr=2, na=10)
    return top


# ------------------------------------------------------------------ parts
def ground(S, rng):
    """the sân: a thin pad of packed earth just above the game ground, a few wisps of rơm and a feather or two"""
    def F(U, V):
        return np.stack([U * T, V * T, 0.5 + 0.35 * np.sin(U * 7.1 + V * 3.3) * np.sin(V * 5.3) * (U > 0.08) * (U < 1.92) * (V > 0.08) * (V < 1.92)], -1)
    S.grid(F, 70, 70, M_YARD, (0, 0, 0), 0.0, uvr=((0.02, 1.98), (0.02, 1.98)))
    for (a, b, c) in ((P(0.02, 1.98, 0), np.array([T * 1.96, 0, 0]), None), (P(1.98, 0.02, 0), np.array([0, T * 1.96, 0]), None)):
        plane(S, a, b, np.array([0, 0, 0.5]), 40, 2, M_YARDSIDE)
    for k in range(45):                                  # rơm wisps, mostly near the house, the máng and the fence
        zone = rng.random()
        if zone < 0.45: u, v = rng.uniform(0.12, 1.2), rng.uniform(0.6, 0.95)
        elif zone < 0.7: u, v = rng.uniform(0.12, 0.5), rng.uniform(0.9, 1.75)
        else: u, v = rng.uniform(0.1, 1.9), rng.uniform(0.1, 1.9)
        a = rng.uniform(0, math.pi); L = rng.uniform(1.2, 2.6)
        c = P(u, v, 0.75)
        d = np.array([math.cos(a), math.sin(a), 0]) * L / 2
        tube(S, c - d, c + d + np.array([0, 0, 0.1]), 0.11, M_STRAW, prm=(rng.random(), 0, 0), nr=3, nl=2)


def fence_side(S, rng, a0, b0, a1, b1, gate=None, seg_posts=True):
    """one side of the rào from (a0,b0) to (a1,b1) in tiles: stakes + two rails; gate=(t0,t1) along the side leaves a gap"""
    A, B = np.array([a0, b0], float), np.array([a1, b1], float)
    L = np.linalg.norm(B - A) * T
    d = (B - A) / np.linalg.norm(B - A); nrm2 = np.array([-d[1], d[0]])
    sp = 2.55
    t = 0.0 + rng.uniform(0.6, 1.2)
    while t < L - 0.6:
        tt = t / L
        if gate and gate[0] - 0.01 < (A + (B - A) * tt) @ d - A @ d + (A @ d) - (A @ d) + (A + (B - A) * tt - A) @ d / T * 0 + 0 and False: pass
        p = A + (B - A) * tt
        along = (p - A) @ d * 1.0                         # tiles along the side
        if gate and gate[0] - 0.02 < along < gate[1] + 0.02:
            t += sp; continue
        h = FH + rng.uniform(-0.4, 0.4)                  # Link 08:47: rào ngay ngắn, cùng cao 14 như 4 chuồng kia
        lean = rng.uniform(-0.06, 0.06); lean2 = rng.uniform(-0.05, 0.05)
        wdt = rng.uniform(1.0, 1.35)
        base = P(p[0], p[1], 0.2)
        top = base + np.array([0, 0, h]) + np.array([d[0], d[1], 0]) * lean + np.array([nrm2[0], nrm2[1], 0]) * lean2
        # a flat split stake: a thin box along its height, skin facing out
        ax = top - base
        w = np.array([d[0], d[1], 0]) * wdt; th = np.array([nrm2[0], nrm2[1], 0]) * 0.45
        obox(S, base - w / 2 - th / 2, ax, w, th, M_SLAT, prm=(rng.random() * (0.45 if rng.random() < 0.18 else 1.0), 0.3, 0))
        cut = rng.uniform(0.6, 1.5)                       # slanted cut top
        tri = Scene()
        q0 = top - w / 2 - th / 2; q1 = top + w / 2 - th / 2
        plane(S, q0, w, np.array([0, 0, cut]) * 0 + th, 2, 2, M_TCUT)
        t += sp * rng.uniform(0.75, 1.3)
    for z in (4.6, 11.4):                                 # round tre rails, outside the stakes, lashed
        off = np.array([nrm2[0], nrm2[1], 0]) * 0.9 / T * T
        segs = [(0.0, gate[0]), (gate[1], np.linalg.norm(B - A))] if gate else [(0.0, np.linalg.norm(B - A))]
        for s0, s1 in segs:
            p0 = P(*(A + d * s0), z) + off * 1.0; p1 = P(*(A + d * s1), z) + off * 1.0
            tube(S, p0, p1, 0.62, M_DECK, prm=(rng.random(), 0.5, 0), nr=6, nl=max(3, int((s1 - s0) * 8)))
            for s in np.arange(s0 + 0.18, s1 - 0.05, 0.36):
                lash(S, P(*(A + d * s), z) + off * 0.6, 0.55)


def gate(S, rng):
    """cổng tre on the front fence: a frame of round tre, a cross brace, stakes like the fence; hung on mây loops"""
    v = F1; u0, u1 = GATE[0] + 0.02, GATE[1] - 0.02
    for u in (GATE[0], GATE[1]):
        tram(S, rng, u, v, FH + 0.3, r=0.95)
    zb, zt = 1.4, FH - 0.5
    for z in (zb, zt, (zb + zt) / 2):
        tube(S, P(u0, v + 0.02, z), P(u1, v + 0.02, z), 0.7, M_DECK, prm=(rng.random(), 0.5, 0), nr=6, nl=5)
    for u in (u0 + 0.01, u1 - 0.01):
        tube(S, P(u, v + 0.02, zb - 0.6), P(u, v + 0.02, zt + 0.8), 0.72, M_DECK, prm=(rng.random(), 0.5, 0), nr=6, nl=5)
    tube(S, P(u0 + 0.01, v + 0.025, zb), P(u1 - 0.01, v + 0.025, zt), 0.55, M_DECK, prm=(rng.random(), 0.5, 0), nr=6, nl=6)
    for u in np.arange(u0 + 0.075, u1 - 0.04, 0.072):
        tube(S, P(u, v + 0.012, zb - 0.2), P(u, v + 0.012, zt + rng.uniform(-0.3, 0.4)), 0.42, M_SLAT, prm=(rng.random(), 0.3, 0), nr=5, nl=3)
    for z in (zb + 1.5, zt - 1.0):                       # mây hinge loops on the left post
        lathe(S, P(GATE[0], v, z), [(0, 1.7), (0.6, 1.75)], M_ROPE, na=12)
    lathe(S, P(GATE[1], v, (zb + zt) / 2), [(0, 1.7), (0.9, 1.75)], M_ROPE, na=12)   # the rope latch on the right post


# kho3d.slope with the leaves laid flat (copied, kho3d stays as it is for the other buildings)
def slope_flat(S, rng, e, su, n_out, LB, ax, Lu, th=2.4, course=3.3):
    """one roof slope from eave e up along su: underlay slab, end face at e + ax*Lu, eave lip, courses of nipa leaflets"""
    Lc = Lu - 1.8                                                      # underlay stops short: the leaves' own ragged ends make the verge
    plane(S, e - n_out * th + ax * 2.0 + su * 1.5, ax * (Lu - 4.0), su * (LB - 3.5), 8, 8, M_THEND)   # nhận xét 1: underlay well inside the leaves
    plane(S, e - n_out * th + su * 1.5 + ax * 2.0, ax * (Lu - 4.0), n_out * (th + 0.4), 20, 2, M_THEND)
    nC = int(LB / course) + 2
    for i in range(nC):
        b0 = i * course * rng.uniform(0.96, 1.04) - 1.2
        a = -1.4 - rng.uniform(0, 0.8)
        while a < Lu + 1.2:
            w = rng.uniform(1.0, 1.6); Lf = course * rng.uniform(1.9, 2.3); tip = b0 - rng.uniform(0.0, 0.9) - (0.8 if i == 0 else 0)
            sag = 1.1 * math.sin(math.pi * min(1, max(0, a / Lu))) * (1 - max(0, b0) / LB)
            tip -= sag
            tone = rng.integers(5); seed = rng.random(); lift = 1.2 + rng.uniform(-0.2, 0.2); sk = rng.uniform(-0.25, 0.25)
            if K.PATCH and K.PATCH[0] < a < PATCH[1] and PATCH[2] < b0 < PATCH[3] and abs(su[2]) > 0.3 and su[1] < 0: tone += 10
            tq = rng.uniform(0.62, 0.9)
            def F(U, V, aa=a, w=w, Lf=Lf, tip=tip, lift=lift, sk=sk, tq=tq):
                q = U / Lf
                width = w * 0.5 * np.where(q < tq, 1.0, np.clip((1 - q) / (1 - tq), 0, 1) ** 0.8)
                bb = np.minimum(tip + Lf * (1 - q), LB - 0.4)
                x = aa + w * 0.5 + V * width + sk * q
                nn = lift * np.sin(np.pi * np.clip(q, 0, 1) * 0.85) + 0.1 + 0.12 * (1 - V ** 2)   # lies flat, tip bends down onto the course below (Link 05:42)
                return e[None, None] + ax[None, None] * x[..., None] + su[None, None] * bb[..., None] + n_out[None, None] * nn[..., None]
            S.grid(F, 6, 3, M_LEAF, (tone, Lf, seed), 0.0, uvr=((0, Lf), (-1, 1)))
            a += w * rng.uniform(0.62, 0.8)



def inside(S, rng):
    """inside the chuồng ngủ (Link 05:20: 'chi tiết phía trong đâu'): rơm on the floor, two tre roost bars (sào đậu) across,
    two ổ đẻ (little rổ of rơm, eggs in one) along the back wall, an ống tre of water"""
    for k in range(60):                                          # rơm lót sàn
        u, v = rng.uniform(HU0 + 0.04, HU1 - 0.04), rng.uniform(HV0 + 0.04, HV1 - 0.04)
        a = rng.uniform(0, math.pi); L = rng.uniform(1.4, 2.8)
        c = P(u, v, ZS + 0.1 + rng.uniform(0, 0.25)); d = np.array([math.cos(a), math.sin(a), 0]) * L / 2
        tube(S, c - d, c + d, 0.13, M_STRAW, prm=(rng.random(), 0, 0), nr=3, nl=2)
    # nhận xét 4: one sào high along the back wall, over the nests; one along the right wall, clear of them
    z = ZS + 12.5
    tube(S, P(HU0 + 0.01, HV0 + 0.07, z), P(HU1 - 0.01, HV0 + 0.07, z - 0.3), 0.62, M_OLDBAMBOO, prm=(rng.random(), 0.4, 0), nr=7, nl=10)
    for u in (HU0 + 0.03, HU1 - 0.03): lash(S, P(u, HV0 + 0.07, z), 0.7)
    z = ZS + 8.0
    tube(S, P(HU1 - 0.12, HV0 + 0.02, z), P(HU1 - 0.12, HV1 - 0.04, z - 0.2), 0.6, M_OLDBAMBOO, prm=(rng.random(), 0.4, 0), nr=7, nl=8)
    for v in (HV0 + 0.04, HV1 - 0.06): lash(S, P(HU1 - 0.12, v, z), 0.7)
    for (u, eggs) in ((HU0 + 0.16, 3), (HU0 + 0.42, 2)):         # ổ đẻ: shallow rổ tre of rơm against the back wall
        c = P(u, HV0 + 0.12, ZS + 0.2)
        lathe(S, c, [(0, 2.2), (0.5, 3.0), (1.8, 3.4), (2.2, 3.45)], BG.M_GIO, na=20)
        lathe(S, c + np.array([0, 0, 2.1]), [(0, 3.5), (0.4, 3.5)], M_RATTAN, na=20)
        for k in range(18):
            a = rng.uniform(0, 2 * math.pi); r = rng.uniform(0, 2.8); a2 = rng.uniform(0, math.pi)
            q = c + np.array([r * math.cos(a), r * math.sin(a), 1.9 + rng.uniform(0, 0.5)])
            d = np.array([math.cos(a2), math.sin(a2), rng.uniform(-0.2, 0.3)]) * rng.uniform(0.8, 1.5)
            tube(S, q - d, q + d, 0.15, M_STRAW, prm=(rng.random(), 0, 0), nr=3, nl=2)
        for k in range(eggs):
            a = k * 2.1 + 0.4
            X3.ellipsoid(S, c + np.array([1.0 * math.cos(a), 1.0 * math.sin(a), 2.5]), 0.9, 0.7, 0.65, M_EGG, nu=6, nvv=6)
    c0, c1 = P(HU1 - 0.28, HV1 - 0.1, ZS + 1.0), P(HU1 - 0.08, HV1 - 0.1, ZS + 1.0)   # ống tre nước: a tre split open, on the floor
    def Fm(U, V):
        th = math.pi + V * math.pi
        x = c0 + (c1 - c0) * U[..., None]
        return x + np.stack([np.zeros_like(U), np.cos(th) * 1.1, np.sin(th) * 1.1 + 1.1], -1)
    S.grid(Fm, 8, 6, M_DECK, (0.5, 0.4, 0), 0.0, uvr=((0, 1), (0, 1)))
    plane(S, c0 + np.array([0, -0.9, 1.6]), c1 - c0, np.array([0, 1.8, 0]), 6, 2, M_WATER2)


def house(S, rng):
    """chuồng ngủ on tràm stilts"""
    # stilts and sills
    for u in (HU0, HU1):
        for v in (HV0, HV1):
            tram(S, rng, u, v, ZS - 1.0, r=1.35)
    for v in (HV0, HV1):
        tube(S, P(HU0 - 0.03, v, ZS - 1.6), P(HU1 + 0.03, v, ZS - 1.6), 0.85, M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=6)
    for u in (HU0, HU1):
        tube(S, P(u, HV0 - 0.03, ZS - 2.4), P(u, HV1 + 0.03, ZS - 2.4), 0.8, M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=5)
        tube(S, P(u, HV0, ZS - 3.0), P(u, HV1, 5.5), 0.45, M_TRAM, prm=(rng.random(), 0, 0), nr=5, nl=4)     # giằng chéo
    # floor: round tre across v, a little gap between
    u = HU0 - 0.03
    while u < HU1 + 0.03:
        r = 0.58 + 0.1 * (rng.random() - 0.5)
        tube(S, P(u, HV0 - 0.035, ZS - 0.6), P(u, HV1 + 0.04 + 0.02 * rng.random(), ZS - 0.6), r, M_DECK, prm=(rng.random(), rng.random(), 0), nr=6, nl=4)
        u += 1.32 / T * (0.95 + 0.1 * rng.random())
    def zt(v):                                           # wall top along v (mono-pitch)
        return ZE_B + (ZE_F - ZE_B) * (v - HV0) / (HV1 - HV0)
    # corner posts (round tre) up to the roof
    for uu in (HU0, HU1):
        for vv in (HV0, HV1):
            tube(S, P(uu, vv, ZS - 0.5), P(uu, vv, zt(vv) + 1.0), 0.75, M_DECK, prm=(rng.random(), 0.5, 0), nr=6, nl=6)
    # back wall (v = HV0) + left wall (u = HU0): phên tre, woven, set just inside the posts
    plane(S, P(HU0, HV0 + 0.01, ZS), P(HU1, HV0 + 0.01, ZS) - P(HU0, HV0 + 0.01, ZS), np.array([0, 0, ZE_B - ZS]), 30, 14, M_WEAVE_F)
    def Fl(U, V):
        v = HV0 + (HV1 - HV0) * U
        return np.stack([np.full_like(U, HU0 * T + 0.3), v * T, ZS + V * (zt(v) - ZS)], -1)
    S.grid(Fl, 20, 14, M_WEAVE_R, (0, 0, 0), 0.0, uvr=((0, 1), (0, 1)))
    # fix the uv of the left wall to units for the weave (S.grid uv is 0..1)
    S.UV[-1] = np.stack([S.UV[-1][:, 0] * (HV1 - HV0) * T, S.UV[-1][:, 1] * (ZE_B - ZS)], -1)
    # right wall (u = HU1) and front wall (v = HV1): vertical nẹp tre with air gaps (chuồng gà cần thoáng)
    v = HV0 + 0.03
    while v < HV1 - 0.02:
        tube(S, P(HU1 + 0.01, v, ZS - 0.3), P(HU1 + 0.01, v, zt(v) + 0.2), 0.55, M_SLAT, prm=(rng.random(), 0.3, 0), nr=5, nl=4)
        v += (2.1 if zt(v) < 0 else 3.4) / T
    u = HU0 + 0.035
    while u < HU1 - 0.02:
        if not (DOOR[0] - 0.01 < u < DOOR[1] + 0.01):
            tube(S, P(u, HV1 + 0.01, ZS - 0.3), P(u, HV1 + 0.01, ZS + 6.5), 0.55, M_SLAT, prm=(rng.random(), 0.3, 0), nr=5, nl=4)
        u += 2.1 / T
    for u in np.arange(HU0 + 0.16, HU1 - 0.05, 0.16):                 # above the half-wall: a few nẹp far apart, the inside shows
        if not (DOOR[0] - 0.03 < u < DOOR[1] + 0.03):
            tube(S, P(u, HV1 + 0.01, ZS + 6.0), P(u, HV1 + 0.01, ZE_F + 0.2), 0.55, M_SLAT, prm=(rng.random(), 0.3, 0), nr=5, nl=4)
    for z in (ZS + 1.5, ZS + 6.5, ZE_F - 0.8):            # nẹp ngang holding the slats
        if z < ZS + 3:
            segs = [(HU0, DOOR[0]), (DOOR[1], HU1)]
        else:
            segs = [(HU0, HU1)] if z > ZS + 9.5 else [(HU0, DOOR[0]), (DOOR[1], HU1)]
        for a, b in segs:
            tube(S, P(a, HV1 + 0.03, z), P(b, HV1 + 0.03, z), 0.5, M_DECK, prm=(rng.random(), 0.5, 0), nr=5, nl=4)
        tube(S, P(HU1 + 0.03, HV0, z if z < ZS + 9 else zt(HV0) - 0.8), P(HU1 + 0.03, HV1, z), 0.5, M_DECK, prm=(rng.random(), 0.5, 0), nr=5, nl=4)
    # the dark inside, seen through the gaps and the door
    inside(S, rng)
    # door frame
    for uu in DOOR:
        tube(S, P(uu, HV1 + 0.02, ZS - 0.4), P(uu, HV1 + 0.02, ZS + 11.0), 0.6, M_DECK, prm=(rng.random(), 0.5, 0), nr=5, nl=4)
    tube(S, P(DOOR[0] - 0.02, HV1 + 0.025, ZS + 10.6), P(DOOR[1] + 0.02, HV1 + 0.025, ZS + 10.6), 0.6, M_DECK, prm=(rng.random(), 0.5, 0), nr=5, nl=4)
    # cầu thang gà: a split-tre board from the door sill down to the yard, with little cross cleats
    um = (DOOR[0] + DOOR[1]) / 2; w = 0.07
    a0, a1 = P(um, HV1 + 0.03, ZS - 0.4), P(um, HV1 + 0.5, 0.6)
    dd = a1 - a0
    a0 = P(um, HV1 + 0.02, ZS - 1.4)                                     # nhận xét 5: two thin tre rails, round rungs, top under the sill
    dd = a1 - a0
    for sg in (-1, 1):
        tube(S, a0 + np.array([sg * w * T, 0, 0]), a1 + np.array([sg * w * T, 0, -0.3]), 0.5, M_DECK, prm=(rng.random(), 0.5, 0), nr=6, nl=6)
    for k in range(1, 8):
        c = a0 + dd * (k / 8.0) + np.array([0, 0, 0.45])
        tube(S, c - np.array([w * T * 1.15, 0, 0]), c + np.array([w * T * 1.15, 0, 0]), 0.36, M_DECK, prm=(rng.random(), 0.5, 0), nr=5, nl=2)
        for sg in (-1, 1): lash(S, c + np.array([sg * w * T, 0, -0.1]), 0.42)
    # roof: lá, one slope falling to the front, overhanging all round
    ax = np.array([1.0, 0, 0]); u0r, u1r = HU0 - 0.12, HU1 + 0.12
    e = P(u0r, HV0 - 0.13, ZE_B - 1.4); top = P(u0r, HV1 + 0.12, ZE_F + 1.6)
    up = top - e; LB = np.linalg.norm(up); su = up / LB
    n_out = BG.K.nv(np.cross(ax, su))
    if n_out[2] < 0: n_out = -n_out
    slope_flat(S, rng, e, su, n_out, LB, ax, (u1r - u0r) * T, th=1.5, course=2.1)
    # rafters under it + a tre pole along the top edge, lashed
    for uu in (HU0, (HU0 + HU1) / 2, HU1):
        tube(S, P(uu, HV1 + 0.1, ZE_F + 0.6), P(uu, HV0 - 0.11, ZE_B - 1.5), 0.55, M_OLDBAMBOO, prm=(rng.random(), 0.5, 0), nr=6, nl=6)
    pt = top + n_out * 1.4 + su * -0.6
    # nhận xét 2: the high edge is a thick bó lá (leaf ends folded over a tre), so the roof has its thickness
    def Fb(U, V, pt=pt):
        th_ = V * 2 * math.pi
        rr = 1.25 + 0.12 * np.sin(U * 1.7 + V * 13) + 0.08 * np.sin(U * 5.1)
        return pt[None, None] - n_out * 0.9 - su * 0.3 + ax[None, None] * U[..., None] + (np.cos(th_)[..., None] * su[None, None] + np.sin(th_)[..., None] * n_out[None, None]) * rr[..., None]
    S.grid(Fb, 60, 12, K.M_VERGE, (0, 0, 0), 0.0, uvr=((-1.6, (u1r - u0r) * T + 1.6), (0, 1)), close_v=True)
    tube(S, pt - ax * 1.2, pt + ax * ((u1r - u0r) * T + 1.2), 0.75, M_OLDBAMBOO, prm=(0.4, 0.3, 0), nr=7, nl=12)
    for f in (0.12, 0.5, 0.88):
        lash(S, pt + ax * (u1r - u0r) * T * f, 0.95)
    # the lamp: a small đèn dầu hung from the front rafter end by the door, burning at night
    lp = P(*LAMP)
    tube(S, P(LAMP[0], LAMP[1], ZE_F - 2.5), lp + np.array([0, 0, 2.2]), 0.1, M_TIN, nr=4, nl=2)
    BG.lamp(S, lp)
    K.LIGHTS2.append((lp, hexc('#ff9645'), 12.0, 1.9, 'all'))
    K.GLOWS[:] = [(lp, 0.14, 0.75)]
    K.GROUND_GLOW[:] = [(LAMP[0] - 0.05, LAMP[1] + 0.32, 20.0, 0.16)]


def props(S, rng):
    # thúng ổ đẻ: a round tre basket of rơm on the ground beside the house, two eggs in it
    if False:                                                  # nhận xét 8: no thúng in the yard (the nests are inside)
     c = P(1.36, 0.34, 0.5)
     lathe(S, c, [(0, 2.6), (0.6, 3.4), (2.4, 3.8), (3.0, 3.85)], BG.M_GIO, na=22)
     lathe(S, c + np.array([0, 0, 2.9]), [(0, 3.95), (0.5, 3.95)], M_RATTAN, na=22)
     for k in range(26):
         a = rng.uniform(0, 2 * math.pi); r = rng.uniform(0, 3.2); a2 = rng.uniform(0, math.pi)
         q = c + np.array([r * math.cos(a), r * math.sin(a), 2.6 + rng.uniform(0, 0.6)])
         d = np.array([math.cos(a2), math.sin(a2), rng.uniform(-0.2, 0.3)]) * rng.uniform(1.0, 1.8)
         tube(S, q - d, q + d, 0.17, M_STRAW, prm=(rng.random(), 0, 0), nr=3, nl=2)
     for (du, dv) in ((-0.9, 0.4), (0.8, -0.3)):
         X3.ellipsoid(S, c + np.array([du, dv, 3.25]), 0.95, 0.75, 0.7, M_EGG, nu=6, nvv=6)
    # máng ăn: half a big tre split along, on two little tre forks, along the left fence
    m0, m1 = P(0.2, 1.0, 1.9), P(0.2, 1.48, 1.9)
    def Fm(U, V):
        th = math.pi + V * math.pi
        x = m0 + (m1 - m0) * U[..., None]
        return x + np.stack([np.cos(th) * 1.15, np.zeros_like(U), np.sin(th) * 1.15 + 1.15], -1) * 1.0 * np.array([1, 0, 1]) + np.stack([np.zeros_like(U), np.zeros_like(U), np.zeros_like(U)], -1)
    S.grid(Fm, 12, 8, M_DECK, (0.6, 0.4, 0), 0.0, uvr=((0, 1), (0, 1)))
    S.UV[-1] = np.stack([S.UV[-1][:, 0] * np.linalg.norm(m1 - m0), S.UV[-1][:, 1] * 4], -1)
    plane(S, m0 + np.array([-0.8, 0, 0.7]), m1 - m0, np.array([1.6, 0, 0]), 10, 2, M_GRAIN2)
    for p in (m0, m1):
        disc(S, p + np.array([0, 0, 1.15]), (0, 1, 0), 1.15, M_TCUT, nr=2, na=10)
        for s in (-1, 1):
            tube(S, p + np.array([s * 0.9, 0, -2.2]), p + np.array([s * 1.6, 0, 1.6]), 0.3, M_DECK, prm=(0.3, 0.3, 0), nr=4, nl=2)
    for k in range(10):                                   # a few grains spilled
        q = P(0.2 + rng.uniform(0.04, 0.16), rng.uniform(0.95, 1.5), 0.8)
        X3.ellipsoid(S, q, 0.32, 0.22, 0.18, M_GRAIN2, nu=3, nvv=3)
    # (no lu nước: Link 06:17, the chickens drink from the ống tre in the chuồng)
    mang_nuoc(S, rng, P(1.38, 0.98, 2.2), P(1.38, 1.5, 2.2), 2.1)   # Link 09:02: máng nước xanh dương như cừu/dê


def mang_nuoc(S, rng, m0, m1, R):
    """máng nước like the cừu/dê one, smaller for gà: a hollowed tràm log on two chocks, clear blue water in it"""
    L = np.linalg.norm(m1 - m0); dl = (m1 - m0) / L
    sd = np.cross(dl, np.array([0, 0, 1.0])); sd = sd / np.linalg.norm(sd); up = np.array([0, 0, 1.0])
    def Fo(U, V):
        th = (math.pi + V * math.pi)[..., None]
        return m0 + (m1 - m0) * U[..., None] + np.cos(th) * R * sd + np.sin(th) * R * up
    S.grid(Fo, 14, 10, M_TRAM, (0.3, 0, 0), 0.0, uvr=((0, 1), (0, 1)))
    def Fi(U, V):
        th = (math.pi + V * math.pi)[..., None]
        return m0 + (m1 - m0) * (0.04 + 0.92 * U[..., None]) + np.cos(th) * R * 0.72 * sd + (np.sin(th) * R * 0.72 + 0.1) * up
    S.grid(Fi, 14, 8, M_TCUT, (0, 0, 0), 0.0, uvr=((0, 1), (0, 1)), flip=True)
    for x in (m0, m1): disc(S, x, dl, R, M_TCUT, nr=3, na=14)
    for sg in (-1, 1): plane(S, m0 + sd * (sg * R * 0.86 - 0.3) + up * 0.05, m1 - m0, sd * 0.6, 12, 2, M_TCUT)
    plane(S, m0 + sd * (-R * 0.62) - up * 0.7, (m1 - m0) * 0.96, sd * (R * 1.24), 12, 2, M_WATER2)
    for f in (0.15, 0.85):
        c = m0 + (m1 - m0) * f
        tube(S, c + sd * (-R * 1.1) - up * (R + 0.2), c + sd * (R * 1.1) - up * (R + 0.2), 0.7, M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=3)


# depth layers: (key, list of build steps). key = depth offset from gx+gy the game sorts the piece with
LAYERS = ['g', 'b', 'r0', 'r1', 'f0', 'f1']
KEYS = {'b': 1.15, 'r0': 2.495, 'r1': 3.495, 'f0': 2.495, 'f1': 3.495}


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear(); K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
    R = {}
    s0 = S.ns; ground(S, rng); R['g'] = (s0, S.ns)
    s0 = S.ns
    fence_side(S, rng, F0, F0, F1, F0)                    # back side (v = F0)
    fence_side(S, rng, F0, F0 + 0.02, F0, F1)            # left side (u = F0)
    for (u, v) in ((F0, F0), (1.0, F0), (F0, 1.0)):
        tram(S, rng, u, v, FH + 0.3, r=0.95)
    house(S, rng); props(S, rng)
    R['b'] = (s0, S.ns)
    s0 = S.ns; fence_side(S, rng, F1, F0 + 0.02, F1, 1.0); tram(S, rng, F1, F0, FH + 0.3, r=0.95); R['r0'] = (s0, S.ns)
    s0 = S.ns; fence_side(S, rng, F1, 1.0, F1, F1 - 0.02); tram(S, rng, F1, 1.0, FH + 0.3, r=0.95); tram(S, rng, F1, F1, FH + 0.3, r=0.95); R['r1'] = (s0, S.ns)
    s0 = S.ns; fence_side(S, rng, F0 + 0.02, F1, 1.0, F1); tram(S, rng, F0, F1, FH + 0.3, r=0.95); R['f0'] = (s0, S.ns)
    s0 = S.ns; fence_side(S, rng, 1.0, F1, F1 - 0.02, F1, gate=(GATE[0] - 1.0 - 0.02, GATE[1] - 1.0 + 0.02)); gate(S, rng); R['f1'] = (s0, S.ns)
    build.R = R
    return S, (S.ns, S.ns)


K.build = build


def render_layers(night, ss=2):
    """one render of the whole chuồng, then cut into the depth layers by which part each pixel shows"""
    K.VARIANT = 0
    S, _ = build(1, np.random.default_rng(K.SEED + 1))
    r = K.R3(K.PXU * ss); img = r.run(S, night, target=0.42 if night else K.TARGET_DAY)
    R = build.R; obj = r.obj
    # the ground under the parts (hidden in the full render): a ground-only render at the same tone curve, in shade,
    # so the ground layer is whole and never shows a hole if a later layer is late
    K.GAMMA_FIX[bool(night)] = K.GAMMA_LOG[bool(night)]
    S2 = Scene(); K.LIGHTS2.clear(); K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
    ground(S2, np.random.default_rng(K.SEED + 1))
    r2 = K.R3(K.PXU * ss); img2 = r2.run(S2, night, target=0.42 if night else K.TARGET_DAY)
    K.GAMMA_FIX.pop(bool(night), None)
    build(1, np.random.default_rng(K.SEED + 1))                       # restore the lights / glows of the full chuồng
    hole = (obj >= R['b'][0]) & (r2.obj >= 0)
    out = {}
    for L in LAYERS:
        a, b = R[L]
        m = (obj >= a) & (obj < b)
        if L == 'g': m |= obj < 0                       # the ground shade / lamp pool off the parts go with the ground
        li = img * m[..., None]
        if L == 'g':
            li[hole] = img2[hole] * np.array([0.78, 0.78, 0.8, 1.0])
        a_ = np.clip(li, 0, 1); h, w = a_.shape[:2]
        im = Image.frombuffer('RGBa', (w, h), (a_ * 255 + 0.5).astype(np.uint8).tobytes(), 'raw', 'RGBa', 0, 1)
        im = im.resize((w // ss, h // ss), Image.LANCZOS).convert('RGBA')
        if night and K.GLOWS and L == 'b':
            im = den.lampglow(im, K.GLOWS, T, K.OX, K.OY, K.BB, K.PXU)
        out[L] = im
    return out


def main(argv):
    if argv[1] == 'prev':
        n = 'n' in argv[3:]
        L = render_layers(n)
        im = L['g'].copy()
        for k in LAYERS[1:]: im.alpha_composite(L[k])
        im.save(argv[2])
    elif argv[1] == 'atlas':
        out, tab = argv[2], argv[3]
        G = {}; frames = []; sc = float(K.PXU); BB = K.BB
        for n in (0, 1):
            L = render_layers(bool(n))
            for k in LAYERS:
                im = L[k]; bb = im.getbbox()
                frames.append((k + ('n' if n else 'd'), im.crop(bb), bb))
        Wd = 0; rows = [[]]; x = 0
        for f in frames:                                   # pack in rows ~2048 wide
            if x + f[1].width > 2400 and rows[-1]: rows.append([]); x = 0
            rows[-1].append(f); x += f[1].width + 2
        Wd = max(sum(f[1].width + 2 for f in r_) for r_ in rows); Hh = sum(max(f[1].height for f in r_) + 2 for r_ in rows)
        sheet = Image.new('RGBA', (Wd, Hh), (0, 0, 0, 0)); y = 0
        for r_ in rows:
            x = 0
            for k, im, bb in r_:
                sheet.paste(im, (x, y))
                G[k] = [x, y, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
                x += im.width + 2
            y += max(f[1].height for f in r_) + 2
        G['_keys'] = KEYS
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, K.SHEET), 'WEBP', quality=92, method=6); json.dump(G, open(tab, 'w'))
        print('sheet', sheet.size)


if __name__ == '__main__':
    main(sys.argv)
