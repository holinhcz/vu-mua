# Chuồng cừu (game pen "cuu", 2x2) in 3D: same kit, light and layers as the chuồng heo / bò
# (Link 2026-11-10 07:53: "tới chuồng cừu"). Only the building: the sheep are the game's own and are not touched
# (their wander area, size and drawing stay; the back layer sorts at 0.15).
#  - chuồng sàn: the cừu sleep on a slatted tre floor raised on tràm stilts (dry, droppings fall through), vách tre on the
#    back and sides, a low lan can in front, a tre cầu dốc down to the sân; mái lá high in front like the bò's
#  - rào tràm, 4 lower rails (cừu are small), cổng tre
#  - máng nước: a hollowed tràm log of clear water along the right rail; a giá cỏ khô at the left
#   python3 chuongcuu3d.py prev OUT.png [n]          python3 chuongcuu3d.py atlas OUTDIR atlas.json
import math, sys, os
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import chuongbo3d as B                               # brings my_tram (tràm posts with bark along them) into H
from chuongbo3d import H, CG, K, P, T, Scene, plane, tube, lathe, lash, hexc, MATS, M_ROPE, vnoise, smooth

K.SHEET = 'chuongcuu.webp'
K.SEED = 9800
H.SU0, H.SU1, H.SV0, H.SV1 = 0.14, 1.44, 0.1, 0.72
H.ZH_F, H.ZH_B = 38.0, 32.5                     # Link 07:58: as tall as the chuồng bò
H.FH = 14.0                                    # Link 08:47: 5 chuồng rào cùng cao 14
H.RAILS = (3.4, 6.6, 9.8, 13.0)
H.RAILR = (0.44, 0.54)
H.STRAIGHT = True                                  # Link 08:04: rào ngay ngắn, không quặt quẹo
H.LAMP = (H.SU0 + (H.SU1 - H.SU0) * 0.74, H.SV1 + 0.01, H.ZH_F - 12.5)   # nhận xét 9: below the diềm
H.ROMBED = False
H.NOMID = True                                      # Link 07:48 (bò): no middle post in the front
H.PHEN = False
H.HOOF = (24.0, 0.22, 0.16)
K.RZ, K.EZ = H.ZH_F + 3.0, H.ZH_B - 1.0
K.FOOT = (H.SU0 - 0.04, H.SU1 + 0.04, H.SV0 - 0.04, H.SV1 + 0.04, 0.06)
tram = B.my_tram
ZS = 7.0                                            # sàn height
RAMP = (0.5, 0.74)                                  # cầu dốc between these u, going down in +v


def vach(S, rng, a0, b0, a1, b1, z0, h0, h1, step=1.5, out=None, girts=None):
    """vách of split tre culms standing side by side (nhận xét 3: culms of different age/tone, two tràm nẹp outside)"""
    A, Bv = np.array([a0, b0]), np.array([a1, b1]); L = np.linalg.norm(Bv - A); d = (Bv - A) / L
    n = int(L * T / step)
    for i in range(n):
        t = (i + 0.5) / n; q = A + d * t * L; ht = h0 + (h1 - h0) * t
        tube(S, P(q[0], q[1], z0), P(q[0], q[1], ht + rng.uniform(-0.6, 0.4)), rng.uniform(0.62, 0.8), H.M_OLDBAMBOO, prm=(rng.random(), rng.uniform(0.05, 0.95), 0), nr=6, nl=4)
    if out is not None:
        o = np.array([out[0], out[1], 0.0]) * 1.05
        for z in (girts or (z0 + (min(h0, h1) - z0) * 0.3, z0 + (min(h0, h1) - z0) * 0.78)):
            tube(S, P(a0, b0, z) + o, P(a1, b1, z) + o, 0.6, H.M_RAIL, prm=(rng.random(), 0, 0), nr=6, nl=8)
            for t in (0.03, 0.5, 0.97): lash(S, P(*(A + d * t * L), z) + o * 0.6, 0.7)


def san(S, rng):
    SU0, SU1, SV0, SV1, ZF, ZB = H.SU0, H.SU1, H.SV0, H.SV1, H.ZH_F, H.ZH_B
    def zr(v): return ZB + (ZF - ZB) * (v - SV0) / (SV1 - SV0)
    u0, u1, v0, v1 = SU0 + 0.02, SU1 + 0.02, SV0 + 0.02, SV1 + 0.03
    for u in (SU0 + 0.04, (SU0 + SU1) / 2, SU1):       # dầm along v on the posts, under the floor
        tube(S, P(u, v0, ZS - 1.0), P(u, v1, ZS - 1.0), 0.95, H.M_RAIL, prm=(rng.random(), 0, 0), nr=7, nl=6)
        for v in (SV0 + 0.04, SV1): lash(S, P(u, v, ZS - 1.0), 1.1)
    for v in (SV0 + 0.04, (SV0 + SV1) / 2, SV1):        # đà along u
        tube(S, P(u0 - 0.02, v, ZS - 2.4), P(u1 + 0.01, v, ZS - 2.4), 0.8, H.M_RAIL, prm=(rng.random(), 0, 0), nr=7, nl=10)
    for u in ((SU0 + SU1) / 2,):                         # nhận xét 8: one row of stilts only, under the middle dầm
        for v in (SV0 + 0.04, (SV0 + SV1) / 2, SV1):
            tram(S, rng, u, v, ZS - 1.6, r=1.15)
    nS = int((v1 - v0) * T / 1.35)                       # floor: split tre slats along u with gaps
    for i in range(nS):
        v = v0 + (v1 - v0) * (i + 0.5 + rng.uniform(-0.18, 0.18)) / nS
        tube(S, P(u0 + rng.uniform(0, 0.015), v, ZS), P(u1 - rng.uniform(0, 0.015), v + rng.uniform(-0.004, 0.004), ZS + rng.uniform(-0.15, 0.15)), rng.uniform(0.45, 0.6), H.M_OLDBAMBOO, prm=(rng.random(), 0.3, 0), nr=6, nl=10)
    # vách: back full height, both sides full, front a low lan can with the ramp opening
    vach(S, rng, u0, SV0 + 0.015, u1, SV0 + 0.015, ZS - 0.3, ZB - 2.0, ZB - 2.0, out=(0, -1))
    vach(S, rng, SU0 + 0.012, v0 + 0.02, SU0 + 0.012, v1, ZS - 0.3, zr(v0) - 2.4, zr(v1) - 2.4, out=(-1, 0))
    vach(S, rng, SU1 + 0.03, v0 + 0.02, SU1 + 0.03, v1, ZS - 0.3, zr(v0) - 2.4, zr(v1) - 2.4, out=(1, 0))
    # nhận xét 1: diềm of spaced tre slats hanging under the front xà, a second xà under it; nhận xét 2: knee braces
    zt = zr(SV1) - 2.2; zd = zt - 7.5
    tube(S, P(u0 - 0.01, SV1 + 0.01, zd), P(u1 + 0.01, SV1 + 0.01, zd), 0.75, H.M_RAIL, prm=(rng.random(), 0, 0), nr=7, nl=12)
    n = int((u1 - u0) * T / 2.2)
    for i in range(n):
        u = u0 + (u1 - u0) * (i + 0.5) / n
        tube(S, P(u, SV1 + 0.015, zd - 0.6), P(u, SV1 + 0.015, zt + 0.2), 0.5, H.M_OLDBAMBOO, prm=(rng.random(), rng.uniform(0.05, 0.9), 0), nr=5, nl=3)
    for u, sg in ((SU0 + 0.04, 1), (SU1, -1)):
        tube(S, P(u, SV1 + 0.02, zd - 6.0), P(u + sg * 0.22, SV1 + 0.02, zd - 0.4), 0.62, H.M_RAIL, prm=(rng.random(), 0, 0), nr=6, nl=4)
        lash(S, P(u + sg * 0.22, SV1 + 0.02, zd - 0.4), 0.8)
    zl = ZS + 7.0
    for (a, b) in ((u0 + 0.03, RAMP[0]), (RAMP[1], u1 - 0.02)):
        tube(S, P(a, v1, zl), P(b, v1, zl), 0.62, H.M_RAIL, prm=(rng.random(), 0, 0), nr=6, nl=8)
        n = int((b - a) * T / 2.4)
        for i in range(n + 1):
            u = a + (b - a) * i / max(1, n)
            tube(S, P(u, v1, ZS), P(u, v1, zl + 0.3), 0.42, H.M_OLDBAMBOO, prm=(rng.random(), 0.3, 0), nr=5, nl=3)
    for u in RAMP: tram(S, rng, u, v1, zl + 1.5, r=1.0)
    # cầu dốc: two tràm stringers, tre slats across with cleats so the hooves grip
    vr = 0.42
    for u in (RAMP[0] + 0.03, RAMP[1] - 0.03):
        tube(S, P(u, v1, ZS - 0.4), P(u, v1 + vr, 0.6), 0.8, H.M_RAIL, prm=(rng.random(), 0, 0), nr=7, nl=6)
    nR = int(math.hypot(vr * T, ZS) / 1.3)
    for i in range(nR):
        t = (i + 0.5 + rng.uniform(-0.12, 0.12)) / nR; v = v1 + vr * t; z = ZS - 0.4 + (0.6 - ZS + 0.4) * t + 0.75
        tube(S, P(RAMP[0] + 0.01, v, z), P(RAMP[1] - 0.01, v, z), 0.5, H.M_OLDBAMBOO, prm=(rng.random(), 0.3, 0), nr=6, nl=4)
        if i % 3 == 1: tube(S, P(RAMP[0] + 0.03, v, z + 0.55), P(RAMP[1] - 0.03, v, z + 0.55), 0.3, H.M_RAIL, prm=(rng.random(), 0, 0), nr=5, nl=3)
    cl = [(rng.uniform(u0 + 0.1, u1 - 0.1), rng.uniform(v0 + 0.08, v1 - 0.12)) for _ in range(4)]
    # tay vịn on the left of the cầu dốc, a tràm log chock under its foot
    tram(S, rng, RAMP[0] + 0.01, v1 + vr * 0.62, 7.0, r=0.8)
    tube(S, P(RAMP[0] + 0.01, v1, zl), P(RAMP[0] + 0.01, v1 + vr * 0.62, 6.6), 0.48, H.M_OLDBAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=5)
    lash(S, P(RAMP[0] + 0.01, v1 + vr * 0.62, 6.6), 0.7)
    tube(S, P(RAMP[0] - 0.03, v1 + vr - 0.01, 0.9), P(RAMP[1] + 0.03, v1 + vr - 0.01, 0.9), 0.9, H.M_RAIL, prm=(rng.random(), 0, 0), nr=8, nl=4)
    for k in range(380):                                 # rơm lót on the sàn, in clumps (nhận xét 4)
        if k % 3: cu, cv = cl[k % 4]; u, v = cu + rng.normal(0, 0.09), cv + rng.normal(0, 0.06)
        else: u, v = rng.uniform(u0 + 0.03, u1 - 0.03), rng.uniform(v0 + 0.03, v1 - 0.05)
        u = min(max(u, u0 + 0.02), u1 - 0.02); v = min(max(v, v0 + 0.02), v1 - 0.04)
        a = rng.uniform(0, math.pi); L = rng.uniform(1.4, 2.8); c = P(u, v, ZS + 0.55 + rng.uniform(0, 0.25))
        d = np.array([math.cos(a), math.sin(a), 0]) * L / 2
        tube(S, c - d, c + d, 0.12, B.M_ROMV, prm=(rng.random(), 0, 0), nr=3, nl=2)


def mat_blue(uv, prm, pos, nrm):
    """Link 08:04: nước xanh dương như ao hồ: clear blue, deeper in the middle, pale sky glints"""
    x, y = pos[:, 0], pos[:, 1]
    col = hexc('#3f86b8')[None] * (0.95 + 0.08 * vnoise(x * 2, y * 2, 3.0))[:, None]
    gl = smooth(0.66, 0.84, vnoise(x * 1.3 + y, y * 0.6, 5.0))[:, None] * 0.35
    return np.clip(col * (1 - gl) + hexc('#bfe2f4')[None] * gl, 0, 1), nrm


M_BLUE = 220
MATS[M_BLUE] = mat_blue
K.GLOSS[M_BLUE] = (0.6, 60.0)


def water_fill(S, rng, m0, m1, sd, R):
    up = np.array([0, 0, 1.0])
    plane(S, m0 + sd * (-R * 0.62) - up * 0.7, (m1 - m0) * 0.96, sd * (R * 1.24), 12, 2, M_BLUE)


def gia_co(S, rng):
    """giá cỏ: a V rack of tre on four tràm legs by the left rail, heaped with cỏ khô"""
    u, v0, v1 = 0.3, 1.0, 1.55
    for v in (v0, v1):
        for du in (-0.07, 0.07): tram(S, rng, u + du, v, 9.5, r=0.62)
        tube(S, P(u - 0.07, v, 9.0), P(u + 0.07, v, 9.0), 0.55, H.M_RAIL, prm=(rng.random(), 0, 0), nr=6, nl=3)
    for du in (-0.07, 0.07):
        tube(S, P(u + du, v0, 9.0), P(u + du, v1, 9.0), 0.6, H.M_RAIL, prm=(rng.random(), 0, 0), nr=6, nl=8)
    n = 12
    for i in range(n):
        v = v0 + (v1 - v0) * (i + 0.5) / n
        for sg in (-1, 1):
            tube(S, P(u, v, 3.6), P(u + sg * 0.07, v, 9.2), 0.32, H.M_OLDBAMBOO, prm=(rng.random(), 0.3, 0), nr=5, nl=3)
    for k in range(520):                                 # nhận xét 6: heaped high, strands hanging over the sides
        vv = rng.uniform(v0 + 0.02, v1 - 0.02); s = rng.uniform(-0.075, 0.075); z = 7.5 + rng.uniform(0, 5.5) * (1 - (s / 0.08) ** 2)
        q = P(u + s, vv, z); a = rng.uniform(0, 2 * math.pi); L = rng.uniform(1.6, 3.2)
        d = np.array([math.cos(a), math.sin(a), rng.uniform(-0.4, 0.6)]) * L / 2
        tube(S, q - d, q + d, 0.13, B.M_CO, prm=(rng.random(), 0, 0), nr=3, nl=2)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear(); K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
    R = {}; F0, F1, FH = H.F0, H.F1, H.FH
    s0 = S.ns; H.ground(S, rng); R["g"] = (s0, S.ns)
    s0 = S.ns
    H.rail_side(S, rng, F0, F0, F1, F0)
    H.rail_side(S, rng, F0, F0, F0, F1)
    tram(S, rng, F0, F0, FH + 1.5, r=1.25)
    H.chai(S, rng); san(S, rng)
    H.mang(S, rng, P(1.48, 1.02, 3.0), P(1.48, 1.66, 3.0), R=2.8, fill=water_fill)
    gia_co(S, rng)
    R['b'] = (s0, S.ns)
    s0 = S.ns; H.rail_side(S, rng, F1, F0, F1, 1.0); tram(S, rng, F1, F0, FH + 1.5, r=1.25); R['r0'] = (s0, S.ns)
    s0 = S.ns; H.rail_side(S, rng, F1, 1.0, F1, F1); tram(S, rng, F1, 1.0, FH + 1.5, r=1.25); tram(S, rng, F1, F1, FH + 1.5, r=1.25); R['r1'] = (s0, S.ns)
    s0 = S.ns; H.rail_side(S, rng, F0, F1, 1.0, F1); tram(S, rng, F0, F1, FH + 1.5, r=1.25); R['f0'] = (s0, S.ns)
    s0 = S.ns; H.rail_side(S, rng, 1.0, F1, F1, F1, gate=(H.GATE[0] - 1.0, H.GATE[1] - 1.0)); H.gate(S, rng); R['f1'] = (s0, S.ns)
    build.R = R
    return S, (S.ns, S.ns)


CG.build = build; CG.ground = H.ground; K.build = build
CG.KEYS = {'b': 0.15, 'r0': 2.495, 'r1': 3.495, 'f0': 2.495, 'f1': 3.495}   # sheep walk all over the pen (game range kept)

if __name__ == '__main__':
    CG.main(sys.argv)
