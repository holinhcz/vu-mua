# Chuồng bò (game pen "bo", 2x2) in 3D: same kit, light and layers as the chuồng heo (chuongheo3d.py)
# (Link 2026-11-10 06:59: "tiếp chuồng bò"). Only the building: the cows are the game's own and are not touched
# (their wander area, size and drawing stay; the back layer sorts at 0.15).
#  - rào tràm taller than the heo's (bò), 3 rails, cổng tre
#  - chái lá on the back-right, open, roof high in front; a máng cỏ (split tràm log heaped with cỏ khô) along its back wall
#  - cây rơm: the miền Tây haystack round a tràm pole in the back-left corner, a cọc cột bò with a thừng coil
#   python3 chuongbo3d.py prev OUT.png [n]          python3 chuongbo3d.py atlas OUTDIR atlas.json
import math, sys, os
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import chuongheo3d as H
from chuongheo3d import CG, K, P, T, Scene, plane, tube, lathe, lash, tram, hexc, vnoise, smooth, MATS, M_TRAM, M_ROPE, M_STRAW

K.SHEET = 'chuongbo.webp'
K.SEED = 9700
H.SU0, H.SU1, H.SV0, H.SV1 = 0.92, 1.84, 0.1, 0.66
H.ZH_F, H.ZH_B = 38.0, 32.5                     # Link 07:07: mái cao, back posts twice the rào (FH 15.5)
H.FH = 14.0                                    # Link 08:47: 5 chuồng rào cùng cao 14
H.RAILS = (3.6, 7.6, 11.6)
H.LAMP = (H.SU0 + (H.SU1 - H.SU0) * 0.27, H.SV1, H.ZH_F - 9.5)   # nhận xét 7: hangs from the front xà, clear of the posts
H.ROMBED = False
H.NOMID = True
H.PHEN = False                                     # nhận xét 2/3: own vách cây instead of the flat phên
H.HOOF = (15.0, 0.26, 0.24)                        # nhận xét 10: bigger, more cow prints
K.RZ, K.EZ = H.ZH_F + 3.0, H.ZH_B - 1.0
K.FOOT = (H.SU0 - 0.04, H.SU1 + 0.04, H.SV0 - 0.04, H.SV1 + 0.04, 0.06)
RS = (0.36, 0.36)                                   # cây rơm centre (u, v)


def mat_rom2(uv, prm, pos, nrm):
    """the cây rơm body: sun-faded rơm, long strands running down the slope, darker in the folds"""
    col, n = MATS[M_ROMV](uv, prm, pos, nrm)
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    a = np.arctan2(y - RS[1] * T, x - RS[0] * T) * 9.0
    st = vnoise(a * 4.0, z * 0.18, 4.0); fine = vnoise(a * 14.0, z * 0.5, 6.0)
    col = col * (0.82 + 0.16 * st + 0.08 * fine)[:, None]
    return np.clip(col, 0, 1), n


def mat_romv(uv, prm, pos, nrm):
    """rơm vàng (Link 07:26: vàng hơn, không trắng): golden straw, strand to strand tone"""
    t = prm[:, 0]
    col = hexc('#c99e48')[None] * (1 - t)[:, None] + hexc('#dcbb68')[None] * t[:, None]
    return np.clip(col * (0.9 + 0.12 * vnoise(uv[:, 0] * 2, uv[:, 1] * 9, 5.0))[:, None], 0, 1), nrm


def mat_co(uv, prm, pos, nrm):
    """cỏ khô in the máng: dry grass, olive to straw"""
    t = prm[:, 0]
    col = hexc('#aab062')[None] * (1 - t)[:, None] + hexc('#cdb872')[None] * t[:, None]   # nhận xét 5
    col = col * (0.85 + 0.2 * vnoise(uv[:, 0] * 3, uv[:, 1] * 2, 2.0))[:, None]
    return np.clip(col, 0, 1), nrm


M_ROM2, M_CO, M_ROMV = 210, 211, 212
MATS.update({M_ROM2: mat_rom2, M_CO: mat_co, M_ROMV: mat_romv})


def cay_rom(S, rng):
    """cây rơm: rơm stacked round a tràm pole, belly wider than the foot, a rounded cap, strands hanging down the sides"""
    c = P(RS[0], RS[1], 0.3)
    prof = [(0, 9.6), (2, 11.0), (5, 11.8), (8, 11.5), (11, 10.2), (14, 7.8), (16.5, 4.8), (18, 2.3), (18.8, 0.6)]   # Link 07:26: tròn thấp
    lathe(S, c, prof, M_ROM2, na=40)
    zs = np.array([p[0] for p in prof]); rs = np.array([p[1] for p in prof])
    for k in range(1300):                              # loose strands lying on the surface, pointing downhill
        z = rng.uniform(0.5, 18.3); th = rng.uniform(0, 2 * math.pi)
        r = np.interp(z, zs, rs) + 0.15
        dz = 0.6; dr = np.interp(z - dz, zs, rs) - np.interp(z, zs, rs)
        L = rng.uniform(2.2, 4.6); dv = np.array([dr * math.cos(th), dr * math.sin(th), -dz]); dv /= np.linalg.norm(dv)
        tw = np.array([-math.sin(th), math.cos(th), 0]) * rng.uniform(-0.3, 0.3)
        p0 = c + np.array([r * math.cos(th), r * math.sin(th), z]); p1 = p0 + (dv + tw) * L
        tube(S, p0, p1, 0.14, M_ROMV, prm=(rng.random(), 0, 0), nr=3, nl=2)
    tube(S, c + np.array([0, 0, 20]), c + np.array([0.2, 0.1, 25.0]), 0.75, M_TRAM, prm=(0.3, 0, 0), nr=8, nl=4, taper=0.6)
    lathe(S, c + np.array([0, 0, 17.6]), [(0, 1.9), (0.8, 1.7), (1.4, 1.0)], M_ROPE, na=14)   # bó rơm tied on top
    for k in range(40):                               # rơm pulled out at the foot
        a = rng.uniform(0, 2 * math.pi); r = rng.uniform(10.0, 13.5)
        q = c + np.array([r * math.cos(a), r * math.sin(a), 0.45]); b = rng.uniform(0, math.pi)
        d = np.array([math.cos(b), math.sin(b), 0]) * rng.uniform(0.8, 1.4)
        tube(S, q - d, q + d, 0.12, M_ROMV, prm=(rng.random(), 0, 0), nr=3, nl=2)


def coc(S, rng):
    """cọc cột bò (nhận xét 6): a tràm stake clear of the cây rơm, a thừng tied round it, the rest lying in a loose flat coil"""
    u, v = 0.8, 0.78
    tram(S, rng, u, v, 11.0, r=1.35)
    lathe(S, P(u, v, 7.0), [(0, 1.6), (1.4, 1.6)], M_ROPE, na=14)
    c = P(u + 0.07, v + 0.03, 0.75)
    pts = []
    for i in range(80):                               # one rope spiralling in, flat on the ground
        t = i / 79; a = t * 2.6 * 2 * math.pi; r = 3.0 - 1.6 * t
        pts.append(c + np.array([r * math.cos(a), r * math.sin(a), 0.15 * math.sin(a * 0.5)]))
    for p0, p1 in zip(pts[:-1], pts[1:]): tube(S, p0, p1, 0.36, M_ROPE, nr=5, nl=2)
    tube(S, P(u, v, 7.0) + np.array([0.9, 0.6, 0]), pts[0] + np.array([0, 0, 0.2]), 0.36, M_ROPE, nr=5, nl=5)


def my_tram(S, rng, u, v, z1, r=1.2, z0=0.0):
    """tràm post with the bark running along it (nhận xét 9: no repeated dark ovals)"""
    lean = (rng.random() - 0.5) * 0.5; lv = (rng.random() - 0.5) * 0.4
    if H.STRAIGHT: lean = lv = 0.0
    top = P(u + lean / T, v + lv / T, z1)
    tube(S, P(u, v, z0), top, r, H.M_RAIL, prm=(rng.random(), 0, 0), nr=9, nl=6, taper=0.9)
    H.disc(S, top, (0, 0, 1), r * 0.88, H.M_TCUT, nr=2, na=10)
    return top


H.tram = my_tram; tram = my_tram


def frame(S, rng):
    """nhận xét 3/8: the chái as a nhà: xà ngang across each post pair, knee braces, vách cây (split tre on two tràm girts)
    on the back, the right side and the back half of the left side"""
    SU0, SU1, SV0, SV1, ZF, ZB = H.SU0, H.SU1, H.SV0, H.SV1, H.ZH_F, H.ZH_B
    def zr(v): return ZB + (ZF - ZB) * (v - SV0) / (SV1 - SV0)
    us = (SU0 + 0.04, SU1)                             # Link 07:48: no middle post
    for u in us:
        tube(S, P(u, SV0 + 0.02, zr(SV0) - 2.6), P(u, SV1 + 0.03, zr(SV1) - 2.6), 0.85, H.M_RAIL, prm=(rng.random(), 0, 0), nr=7, nl=8)
        for v in (SV0 + 0.04, SV1): lash(S, P(u, v, zr(v) - 2.6), 1.0)
        tube(S, P(u, SV1, zr(SV1) - 10.0), P(u, SV1 - 0.2, zr(SV1 - 0.2) - 2.9), 0.6, H.M_RAIL, prm=(rng.random(), 0, 0), nr=6, nl=4)
    for u in us:                                       # knee braces on the front xà
        for sg in (-1, 1):
            if (u == us[0] and sg < 0) or (u == us[-1] and sg > 0): continue
            tube(S, P(u, SV1, zr(SV1) - 10.0), P(u + sg * 0.2, SV1, zr(SV1) - 2.3), 0.6, H.M_RAIL, prm=(rng.random(), 0, 0), nr=6, nl=4)
    def wall(a0, b0, a1, b1, h0, h1):
        A, B = np.array([a0, b0]), np.array([a1, b1]); L = np.linalg.norm(B - A); d = (B - A) / L
        n = int(L * T / 1.5)
        for i in range(n):
            q = A + d * (i + 0.5) / n * L; t = (i + 0.5) / n; ht = h0 + (h1 - h0) * t
            tube(S, P(q[0], q[1], 0.3), P(q[0], q[1], ht + rng.uniform(-0.6, 0.4)), 0.72, H.M_OLDBAMBOO, prm=(rng.random(), rng.uniform(0.1, 0.5), 0), nr=6, nl=4)
    wall(SU0 + 0.04, SV0 + 0.015, SU1, SV0 + 0.015, ZB - 2.0, ZB - 2.0)
    wall(SU1 + 0.015, SV0 + 0.04, SU1 + 0.015, SV1, zr(SV0 + 0.04) - 2.4, zr(SV1) - 2.4)
    wall(SU0 + 0.025, SV0 + 0.04, SU0 + 0.025, (SV0 + SV1) / 2, zr(SV0 + 0.04) - 2.4, zr((SV0 + SV1) / 2) - 2.4)
    for k in range(70):                                # rơm lót under the roof
        u, v = rng.uniform(SU0 + 0.05, SU1 - 0.05), rng.uniform(SV0 + 0.05, SV1 - 0.05)
        a = rng.uniform(0, math.pi); L = rng.uniform(1.4, 2.8); c = P(u, v, 0.75)
        d = np.array([math.cos(a), math.sin(a), 0]) * L / 2
        tube(S, c - d, c + d, 0.12, H.M_ROM, prm=(rng.random(), 0, 0), nr=3, nl=2)


def co_fill(S, rng, m0, m1, sd, R):
    up = np.array([0, 0, 1.0])
    for k in range(260):
        f = rng.uniform(0.04, 0.96); s = rng.uniform(-0.65, 0.65) * R
        q = m0 + (m1 - m0) * f + sd * s + up * (rng.uniform(-0.6, 0.9) + 0.8 * (1 - (s / R) ** 2))
        a = rng.uniform(0, 2 * math.pi); L = rng.uniform(1.6, 3.4)
        d = np.array([math.cos(a), math.sin(a), rng.uniform(-0.3, 0.5)]) * L / 2
        tube(S, q - d, q + d, 0.13, M_CO, prm=(rng.random(), 0, 0), nr=3, nl=2)
    for k in range(14):                               # a few fallen on the ground in front
        q = m0 + (m1 - m0) * rng.uniform(0.05, 0.95) + sd * rng.uniform(-R * 2.6, -R * 1.6)
        q = np.array([q[0], q[1], 0.75]); a = rng.uniform(0, math.pi)
        d = np.array([math.cos(a), math.sin(a), 0]) * rng.uniform(0.7, 1.4)
        tube(S, q - d, q + d, 0.12, M_CO, prm=(rng.random(), 0, 0), nr=3, nl=2)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear(); K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
    R = {}; F0, F1, FH = H.F0, H.F1, H.FH
    s0 = S.ns; H.ground(S, rng); R["g"] = (s0, S.ns)
    s0 = S.ns
    H.rail_side(S, rng, F0, F0, F1, F0)
    H.rail_side(S, rng, F0, F0, F0, F1)
    tram(S, rng, F0, F0, FH + 1.5, r=1.25)
    H.chai(S, rng)
    H.mang(S, rng, P(1.0, 0.56, 3.8), P(1.74, 0.56, 3.8), R=3.6, fill=co_fill)   # nhận xét 5: under the eave, in the light
    H.mang(S, rng, P(1.5, 1.04, 3.0), P(1.5, 1.66, 3.0), R=2.8, fill=H.water_fill)   # Link 09:02: máng nước như cừu/dê
    frame(S, rng)
    cay_rom(S, rng); coc(S, rng)                      # Link 07:48: the cọc stays, the middle chái post goes
    R['b'] = (s0, S.ns)
    s0 = S.ns; H.rail_side(S, rng, F1, F0, F1, 1.0); tram(S, rng, F1, F0, FH + 1.5, r=1.25); R['r0'] = (s0, S.ns)
    s0 = S.ns; H.rail_side(S, rng, F1, 1.0, F1, F1); tram(S, rng, F1, 1.0, FH + 1.5, r=1.25); tram(S, rng, F1, F1, FH + 1.5, r=1.25); R['r1'] = (s0, S.ns)
    s0 = S.ns; H.rail_side(S, rng, F0, F1, 1.0, F1); tram(S, rng, F0, F1, FH + 1.5, r=1.25); R['f0'] = (s0, S.ns)
    s0 = S.ns; H.rail_side(S, rng, 1.0, F1, F1, F1, gate=(H.GATE[0] - 1.0, H.GATE[1] - 1.0)); H.gate(S, rng); R['f1'] = (s0, S.ns)
    build.R = R
    return S, (S.ns, S.ns)


CG.build = build; CG.ground = H.ground; K.build = build
CG.KEYS = {'b': 0.15, 'r0': 2.495, 'r1': 3.495, 'f0': 2.495, 'f1': 3.495}   # cows walk all over the pen (game range kept)

if __name__ == '__main__':
    CG.main(sys.argv)
