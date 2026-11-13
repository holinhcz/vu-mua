# Chuồng dê (game pen "de", 2x2) in 3D: same kit, light and layers as the chuồng cừu (chuongcuu3d.py)
# (Link 2026-11-10 08:24: "rồi làm chuồng dê"). Only the building: the goats are the game's own and are not touched
# (their wander area, size and drawing stay; the back layer sorts at 0.15).
#  - chuồng sàn on the back-right like the cừu's (dê sleep off the ground), cầu dốc, diềm, mái as tall as the bò's
#  - dê love to climb: two tràm gốc of different heights with a split-log bridge between them, a small pile of logs
#  - giá cỏ khô front-left, máng nước xanh dương front-right, rào tràm ngay ngắn (5 rails: dê nhảy)
#   python3 chuongde3d.py prev OUT.png [n]          python3 chuongde3d.py atlas OUTDIR atlas.json
import math, sys, os
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import chuongcuu3d as C
from chuongcuu3d import H, B, CG, K, P, T, Scene, plane, tube, lathe, lash, hexc, MATS

K.SHEET = 'chuongde.webp'
K.SEED = 9900
H.SU0, H.SU1, H.SV0, H.SV1 = 0.7, 1.84, 0.1, 0.72
H.FH = 14.0
H.RAILS = (3.2, 5.9, 8.6, 11.3, 13.6)
H.LAMP = (H.SU0 + (H.SU1 - H.SU0) * 0.72, H.SV1 + 0.01, H.ZH_F - 12.5)
K.RZ, K.EZ = H.ZH_F + 3.0, H.ZH_B - 1.0
K.FOOT = (H.SU0 - 0.04, H.SU1 + 0.04, H.SV0 - 0.04, H.SV1 + 0.04, 0.06)
C.RAMP = (0.9, 1.14)
tram = B.my_tram


def goc(S, rng, u, v, h, r):
    """a sawn tràm gốc: bark round the side, pale cut top with rings"""
    tube(S, P(u, v, 0.3), P(u, v, h), r, K.M_BARK, prm=(rng.random(), 0, 0), nr=16, nl=4, taper=0.94)
    H.disc(S, P(u, v, h), (0, 0, 1), r * 0.94, H.M_TCUT, nr=3, na=20)
    for k in range(5):                                   # roots flaring into the ground
        a = k / 5 * 2 * math.pi + rng.uniform(-0.3, 0.3)
        p0 = P(u, v, 1.6) + np.array([math.cos(a), math.sin(a), 0]) * r * 0.8
        p1 = P(u, v, 0.4) + np.array([math.cos(a), math.sin(a), 0]) * r * 1.35
        tube(S, p0, p1, r * 0.28, K.M_BARK, prm=(rng.random(), 0, 0), nr=6, nl=3, taper=0.6)


def cho_leo(S, rng):
    """chỗ leo for the dê (left side, in the open): a tall and a low gốc, a split-log bridge from one to the other, a log pile"""
    g1, g2 = (0.3, 0.5, 9.5, 3.8), (0.52, 0.86, 4.8, 3.2)
    goc(S, rng, *g1); goc(S, rng, *g2)
    a = P(g1[0], g1[1], g1[2] + 0.6); b = P(g2[0], g2[1], g2[2] + 0.6)
    tube(S, a, b, 1.25, K.M_BARK, prm=(rng.random(), 0, 0), nr=10, nl=8)
    d = (b - a) / np.linalg.norm(b - a); sd = np.cross(d, [0, 0, 1.0]); sd /= np.linalg.norm(sd)
    plane(S, a - sd * 1.1 + np.array([0, 0, 1.05]), b - a, sd * 2.2, 10, 2, H.M_TCUT)       # flat sawn top to stand on
    for f in (0.2, 0.8): lash(S, a + (b - a) * f + np.array([0, 0, 0.2]), 1.2)
    for i, (u, v, z) in enumerate(((0.2, 0.22, 1.5), (0.33, 0.24, 1.5), (0.265, 0.23, 3.9))):   # log pile
        tube(S, P(u, v - 0.14, z), P(u, v + 0.14, z), 1.45, K.M_BARK, prm=(rng.random(), 0, 0), nr=10, nl=5)
        for vv in (v - 0.14, v + 0.14): H.disc(S, P(u, vv, z), (0, 1, 0), 1.4, H.M_TCUT, nr=2, na=14)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear(); K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
    R = {}; F0, F1, FH = H.F0, H.F1, H.FH
    s0 = S.ns; H.ground(S, rng); R["g"] = (s0, S.ns)
    s0 = S.ns
    H.rail_side(S, rng, F0, F0, F1, F0)
    H.rail_side(S, rng, F0, F0, F0, F1)
    tram(S, rng, F0, F0, FH + 1.5, r=1.25)
    H.chai(S, rng); C.san(S, rng)
    H.mang(S, rng, P(1.5, 1.04, 3.0), P(1.5, 1.66, 3.0), R=2.8, fill=C.water_fill)
    C.gia_co(S, rng); cho_leo(S, rng)
    R['b'] = (s0, S.ns)
    s0 = S.ns; H.rail_side(S, rng, F1, F0, F1, 1.0); tram(S, rng, F1, F0, FH + 1.5, r=1.25); R['r0'] = (s0, S.ns)
    s0 = S.ns; H.rail_side(S, rng, F1, 1.0, F1, F1); tram(S, rng, F1, 1.0, FH + 1.5, r=1.25); tram(S, rng, F1, F1, FH + 1.5, r=1.25); R['r1'] = (s0, S.ns)
    s0 = S.ns; H.rail_side(S, rng, F0, F1, 1.0, F1); tram(S, rng, F0, F1, FH + 1.5, r=1.25); R['f0'] = (s0, S.ns)
    s0 = S.ns; H.rail_side(S, rng, 1.0, F1, F1, F1, gate=(H.GATE[0] - 1.0, H.GATE[1] - 1.0)); H.gate(S, rng); R['f1'] = (s0, S.ns)
    build.R = R
    return S, (S.ns, S.ns)


CG.build = build; CG.ground = H.ground; K.build = build
CG.KEYS = {'b': 0.15, 'r0': 2.495, 'r1': 3.495, 'f0': 2.495, 'f1': 3.495}   # goats walk all over the pen (game range kept)

if __name__ == '__main__':
    CG.main(sys.argv)
