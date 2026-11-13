# Chuồng heo (game pen "heo", 2x2) in 3D, same kit, light and depth layers as the chuồng gà (chuongga3d.py)
# (Link 2026-11-10 06:33: "tới chuồng heo"). Only the building: the pigs are the game's own and are not touched
# (their wander area, size and drawing stay as they are, so the back layer sorts at 0.15 like the old shed).
#  - sân đất nện (no vũng bùn: Link 06:34 'dơ'), trampled darker by the máng and the gate, hoof prints
#  - rào: round tràm posts, three round tràm rails lashed with mây (heo húc, so heavier than the gà's stakes),
#    a tre gate on the front side
#  - chái lá: an open lean-to over the back strip on tràm posts, roof high at the front, lá laid flat; rơm bed under it
#  - máng ăn: a tràm log split and hollowed, along the left rail; a gáo dừa on it
#   python3 chuongheo3d.py prev OUT.png [n]          python3 chuongheo3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import chuongga3d as CG
from chuongga3d import (K, BG, P, T, Scene, X3, hexc, smooth, vnoise, plane, tube, disc, lathe, mat_flat, MATS, obox,
                        M_TRAM, M_TCUT, M_DECK, M_ROPE, M_STRAW, M_RATTAN, M_OLDBAMBOO, lash, tram)

K.SHEET = 'chuongheo.webp'
K.SEED = 9600
if os.environ.get('CG_PXU'): K.PXU = int(os.environ['CG_PXU'])
F0, F1 = CG.F0, CG.F1
SU0, SU1, SV0, SV1 = 0.92, 1.84, 0.1, 0.66        # chái lá footprint (post centres); Link 09:14: same spot/size as the bò shed so heo = bò on screen
ZH_F, ZH_B = 38.0, 32.5                           # roof edge heights front/back; Link 08:47 fix: = bò/cừu/dê (was 23/18.5)
RAILS = (3.6, 7.6, 11.6)
FH = 14.0
GATE = (1.0, 1.4)
K.RZ, K.EZ = ZH_F + 3.0, ZH_B - 1.0
K.FOOT = (SU0 - 0.04, SU1 + 0.04, SV0 - 0.04, SV1 + 0.04, 0.06)
LAMP = (SU0 + (SU1 - SU0) * 0.27, SV1, ZH_F - 9.5)
ROMBED = True
RAILR = (0.55, 0.7)
STRAIGHT = True                                    # Link 08:47: rào ngay ngắn hết 5 chuồng
NOMID = True                                       # Link 07:48 bò, 09:00 heo: no middle chái posts
PHEN = True
HOOF = (26.0, 0.18, 0.16)                         # hoof print grid, density, depth


def mat_rail(uv, prm, pos, nrm):
    """tràm rail lying down (nhận xét 3): the bark streaks run along the pole (uv U = length), not in bands across it"""
    L, A = uv[:, 0], uv[:, 1] * 6.0 + prm[:, 0] * 40
    st = vnoise(L * 0.09, A, 3.0); fine = vnoise(L * 0.3, A * 3.0, 7.0)
    bark = hexc('#b4ab96')[None] * (0.86 + 0.16 * st + 0.07 * fine)[:, None]
    crack = smooth(0.7, 0.8, fine) * 0.22
    bark = bark * (1 - crack[:, None]) + hexc('#4a3f33')[None] * crack[:, None]
    peel = smooth(0.74, 0.8, vnoise(L * 0.05 + 3, A * 0.7, 9.0))
    bark = bark * (1 - 0.14 * peel[:, None]) + hexc('#a57a55')[None] * (0.14 * peel[:, None])
    return np.clip(bark, 0, 1), nrm


def mat_yard_heo(uv, prm, pos, nrm):
    """the sân of the chuồng gà, trodden harder by the máng and the gate, small paired hoof prints (nhận xét 9)"""
    col, n = CG.mat_yard(uv, prm, pos, nrm)
    x, y = pos[:, 0] / T, pos[:, 1] / T
    tr = np.maximum(smooth(0.5, 0.1, np.hypot((x - 0.42) / 1.2, (y - 1.26) / 0.55)),
                    smooth(0.45, 0.1, np.hypot((x - 1.2) / 0.8, (y - 1.75) / 0.6)))
    tr = tr * (0.75 + 0.35 * vnoise(x * 9, y * 9, 5.0))
    col = col * (1 - 0.12 * tr)[:, None] + hexc('#7d6448')[None] * (0.06 * tr)[:, None]
    gx, gy = x * HOOF[0], y * HOOF[0]                                   # hoof prints: little paired dents on a jittered grid
    cx, cy = np.floor(gx), np.floor(gy)
    h1 = np.sin(cx * 12.99 + cy * 78.23) * 43758.5; h1 = h1 - np.floor(h1)
    h2 = np.sin(cx * 39.35 + cy * 11.13) * 24634.6; h2 = h2 - np.floor(h2)
    fx, fy = gx - cx - 0.5 - (h2 - 0.5) * 0.4, gy - cy - 0.5
    d = np.minimum(np.hypot(fx - 0.09, fy / 1.4), np.hypot(fx + 0.09, fy / 1.4))
    hoof = smooth(0.11, 0.06, d) * (h1 < HOOF[1] + 0.3 * tr) * (y > 0.62)
    col = col * (1 - HOOF[2] * hoof)[:, None]
    return np.clip(col, 0, 1), n


def mat_rom(uv, prm, pos, nrm):
    """rơm of the bed (nhận xét 6): duller, older than the chuồng gà's fresh wisps"""
    col, n = MATS[M_STRAW](uv, prm, pos, nrm)
    g = col.mean(1, keepdims=True)
    return np.clip((col * 0.85 + g * 0.15) * 0.92, 0, 1), n


def mat_log(uv, prm, pos, nrm):
    """the hollowed tràm log inside: worn pale wood, dark wet bottom"""
    col = hexc('#a88e6a')[None] * (0.85 + 0.15 * vnoise(uv[:, 0] * 0.6, uv[:, 1] * 6, 4.0))[:, None]
    return np.clip(col, 0, 1), nrm


M_RAIL, M_LOG, M_SLOP, M_YARDH, M_ROM = range(200, 205)
MATS.update({M_RAIL: mat_rail, M_LOG: mat_log, M_SLOP: mat_flat('#8f7f5c'), M_YARDH: mat_yard_heo, M_ROM: mat_rom})


def rail_side(S, rng, a0, b0, a1, b1, gate=None, posts=True):
    """one side of the rào: tràm posts every ~half tile, three round tràm rails lashed on the outside"""
    A, B = np.array([a0, b0], float), np.array([a1, b1], float)
    Lt = np.linalg.norm(B - A); d = (B - A) / Lt; n2 = np.array([-d[1], d[0]])
    if posts:
        for s in np.linspace(0, Lt, max(2, int(round(Lt / 0.48)) + 1))[1:-1]:
            if gate and gate[0] - 0.13 < s < gate[1] + 0.13: continue
            p = A + d * s; dh = rng.uniform(-1.8, 1.3); rr = rng.uniform(0.95, 1.2)
            if STRAIGHT: dh, rr = 0.0, 1.08
            tram(S, rng, p[0], p[1], FH + dh, r=rr)
    segs = [(0.0, gate[0]), (gate[1], Lt)] if gate else [(0.0, Lt)]
    for z in RAILS:
        for s0, s1 in segs:
            off = np.array([n2[0], n2[1], 0]) * 1.1
            jz = rng.uniform(-0.9, 0.9); zz = z + rng.uniform(-0.4, 0.4)
            if STRAIGHT: jz, zz = 0.0, z                  # Link 08:04 (cừu): rào ngay ngắn
            p0 = P(*(A + d * (s0 - (0.008 if s0 == 0 else 0))), zz + jz) + off; p1 = P(*(A + d * (s1 + (0.008 if s1 == Lt else 0))), zz - jz) + off
            tube(S, p0, p1, rng.uniform(*RAILR), M_RAIL, prm=(rng.random(), 0, 0), nr=8, nl=max(3, int((s1 - s0) * 8)), taper=(0.97 if STRAIGHT else rng.uniform(0.8, 0.95)))
            for s in np.linspace(s0, s1, max(2, int(round((s1 - s0) / 0.48)) + 1)):
                if 0 < s < Lt: lash(S, P(*(A + d * s), z) + off * 0.5, 0.7)


def gate(S, rng):
    """cổng tre (nhận xét 4): two tall tràm posts with a cap pole, a leaf of close vertical tre slats, two rails and a
    diagonal brace, hung on mây loops; lighter yellow-green tre so it reads apart from the grey tràm rào"""
    v = F1; u0, u1 = GATE[0] + 0.035, GATE[1] - 0.035
    for u in GATE: tram(S, rng, u, v, FH + 4.5, r=1.4)
    tube(S, P(GATE[0] - 0.03, v, FH + 3.6), P(GATE[1] + 0.03, v, FH + 3.9), 0.75, M_RAIL, prm=(rng.random(), 0, 0), nr=7, nl=6)
    for u in GATE: lash(S, P(u, v, FH + 3.7), 0.9)
    zb, zt = 1.4, FH - 0.8
    n = 13
    for i in range(n):
        u = u0 + (u1 - u0) * (i + 0.5) / n
        tube(S, P(u, v + 0.03, zb - 0.6), P(u, v + 0.03, zt + rng.uniform(-0.3, 0.6)), 0.5, M_OLDBAMBOO, prm=(rng.random(), 0.15, 0), nr=6, nl=4)
    for z in (zb + 1.2, zt - 1.6):
        tube(S, P(u0 - 0.01, v + 0.045, z), P(u1 + 0.01, v + 0.045, z), 0.55, M_OLDBAMBOO, prm=(rng.random(), 0.15, 0), nr=6, nl=6)
    tube(S, P(u0 + 0.01, v + 0.05, zb + 1.2), P(u1 - 0.01, v + 0.05, zt - 1.6), 0.5, M_OLDBAMBOO, prm=(rng.random(), 0.15, 0), nr=6, nl=6)
    for z in (zb + 1.2, zt - 1.6): lathe(S, P(GATE[0], v, z), [(0, 1.9), (0.7, 1.95)], M_ROPE, na=12)
    lathe(S, P(GATE[1], v, (zb + zt) / 2), [(0, 1.9), (1.0, 1.95)], M_ROPE, na=12)


def chai(S, rng):
    """open lean-to of lá on tràm posts over the back strip, a rơm bed under it"""
    def zr(v): return ZH_B + (ZH_F - ZH_B) * (v - SV0) / (SV1 - SV0)
    for u in ((SU0 + 0.04, SU1) if NOMID else (SU0 + 0.04, (SU0 + SU1) / 2, SU1)):
        for v in (SV0 + 0.04, SV1):
            tram(S, rng, u, v, zr(v) - 1.6, r=1.65)
    for v in (SV0 + 0.04, SV1):                          # xà along u on the post tops
        tube(S, P(SU0 - 0.02, v, zr(v) - 1.9), P(SU1 + 0.05, v, zr(v) - 1.9), 0.9, M_TRAM, prm=(rng.random(), 0, 0), nr=7, nl=10)
    ax = np.array([1.0, 0, 0]); u0r, u1r = SU0 - 0.1, SU1 + 0.12
    e = P(u0r, SV0 - 0.1, ZH_B - 1.2); top = P(u0r, SV1 + 0.12, ZH_F + 1.2)
    up = top - e; LB = np.linalg.norm(up); su = up / LB
    n_out = K.nv(np.cross(ax, su))
    if n_out[2] < 0: n_out = -n_out
    CG.slope_flat(S, rng, e, su, n_out, LB, ax, (u1r - u0r) * T, th=2.8, course=2.1)
    for uu in (SU0 + 0.04, (SU0 + SU1) / 2, SU1):
        tube(S, P(uu, SV1 + 0.1, ZH_F + 0.4), P(uu, SV0 - 0.08, ZH_B - 1.4), 0.55, M_OLDBAMBOO, prm=(rng.random(), 0.5, 0), nr=6, nl=6)
    pt = top + n_out * 1.4 + su * -0.6
    def Fb(U, V, pt=pt):
        th_ = V * 2 * math.pi
        rr = 1.25 + 0.12 * np.sin(U * 1.7 + V * 13) + 0.08 * np.sin(U * 5.1)
        return pt[None, None] - n_out * 0.9 - su * 0.3 + ax[None, None] * U[..., None] + (np.cos(th_)[..., None] * su[None, None] + np.sin(th_)[..., None] * n_out[None, None]) * rr[..., None]
    S.grid(Fb, 60, 12, K.M_VERGE, (0, 0, 0), 0.0, uvr=((-1.6, (u1r - u0r) * T + 1.6), (0, 1)), close_v=True)
    tube(S, pt - ax * 1.2, pt + ax * ((u1r - u0r) * T + 1.2), 0.75, M_OLDBAMBOO, prm=(0.4, 0.3, 0), nr=7, nl=12)
    for f in (0.1, 0.5, 0.9): lash(S, pt + ax * (u1r - u0r) * T * f, 0.95)
    # back wall of the chái: phên tre woven, against the back rail (wind and rain), up to the roof
    if PHEN:
        plane(S, P(SU0, SV0 - 0.0, 0.4), P(SU1, SV0, 0.4) - P(SU0, SV0, 0.4), np.array([0, 0, ZH_B - 2.5]), 30, 12, K.M_WEAVE_F)
        S.UV[-1] = S.UV[-1] * 1.9
    # rơm bed under it
    if ROMBED:
        X3.ellipsoid(S, P((SU0 + SU1) / 2, (SV0 + SV1) / 2 - 0.03, 0.2), (SU1 - SU0) * T / 2 * 0.93, (SV1 - SV0) * T / 2 * 0.85, 1.3, M_ROM, nu=10, nvv=24)
        for k in range(360):
            u, v = rng.uniform(SU0 + 0.04, SU1 - 0.04), rng.uniform(SV0 + 0.05, SV1 - 0.06)
            du = (u - (SU0 + SU1) / 2) / ((SU1 - SU0) / 2); dv = (v - (SV0 + SV1) / 2 + 0.03) / ((SV1 - SV0) / 2)
            a = rng.uniform(0, math.pi); L = rng.uniform(1.6, 3.2); z = 0.35 + 1.3 * math.sqrt(max(0.0, 1 - du * du - dv * dv)) + rng.uniform(-0.1, 0.15)
            c = P(u, v, z); dd = np.array([math.cos(a), math.sin(a), rng.uniform(-0.04, 0.04)]) * L / 2
            tube(S, c - dd, c + dd, 0.13, M_ROM, prm=(rng.random(), 0, 0), nr=3, nl=2)
    # a đèn bão on the front post at night
    lp = P(*LAMP)
    tube(S, P(LAMP[0], SV1, ZH_F - 1.6), lp + np.array([0, 0, 2.2]), 0.2, M_ROPE, nr=5, nl=3)
    lash(S, P(LAMP[0], SV1, ZH_F - 1.9), 1.0)
    BG.lamp(S, lp)
    K.LIGHTS2.append((lp, hexc('#ff9645'), 12.0, 1.9, 'all'))
    K.GLOWS[:] = [(lp, 0.14, 0.75)]
    K.GROUND_GLOW[:] = [(LAMP[0], LAMP[1] + 0.3, 20.0, 0.14)]


def mang(S, rng, m0=None, m1=None, R=3.0, fill=None):
    """máng ăn: a tràm log split lengthwise and hollowed, lying on two short chocks; cám in it (or fill(S, rng, m0, m1, side, R))"""
    if m0 is None: m0, m1 = P(0.36, 0.86, 3.2), P(0.36, 1.66, 3.2)
    L = np.linalg.norm(m1 - m0); dl = (m1 - m0) / L
    sd = np.cross(dl, np.array([0, 0, 1.0])); sd = sd / np.linalg.norm(sd); up = np.array([0, 0, 1.0])
    def Fo(U, V):                                      # outer bark, the lower half of the log
        th = (math.pi + V * math.pi)[..., None]
        x = m0 + (m1 - m0) * U[..., None]
        return x + np.cos(th) * R * sd + np.sin(th) * R * up
    S.grid(Fo, 14, 10, M_TRAM, (0.3, 0, 0), 0.0, uvr=((0, 1), (0, 1)))
    def Fi(U, V):                                      # the hollow
        th = (math.pi + V * math.pi)[..., None]
        x = m0 + (m1 - m0) * (0.04 + 0.92 * U[..., None])
        return x + np.cos(th) * R * 0.72 * sd + (np.sin(th) * R * 0.72 + 0.1) * up
    S.grid(Fi, 14, 8, M_LOG, (0, 0, 0), 0.0, uvr=((0, 1), (0, 1)), flip=True)
    S.UV[-1] = np.stack([S.UV[-1][:, 0] * L, S.UV[-1][:, 1] * 4], -1)
    for x in (m0, m1):                                  # sawn ends, flat rim
        disc(S, x, dl, R, M_TCUT, nr=3, na=14)
    for sg in (-1, 1):
        plane(S, m0 + sd * (sg * R * 0.86 - 0.3) + up * 0.05, m1 - m0, sd * 0.6, 12, 2, M_TCUT)
    if fill: fill(S, rng, m0, m1, sd, R)
    else: plane(S, m0 + sd * (-R * 0.6) - up * 0.9, (m1 - m0) * 0.98, sd * (R * 1.2), 12, 2, M_SLOP)  # cám
    for f in (0.15, 0.85):                               # chocks under it
        c = m0 + (m1 - m0) * f
        tube(S, c + sd * (-R * 1.1) - up * (R + 0.2), c + sd * (R * 1.1) - up * (R + 0.2), 0.8, M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=3)


def mat_blue(uv, prm, pos, nrm):
    """Link 08:04: nước xanh dương như ao hồ (same as the cừu/dê máng)"""
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


def ground(S, rng):
    """sân đất nện like the chuồng gà's, its own trampled/hoof material, only a few rơm wisps near the chái"""
    def F(U, V):
        return np.stack([U * T, V * T, 0.5 + 0.35 * np.sin(U * 7.1 + V * 3.3) * np.sin(V * 5.3) * (U > 0.08) * (U < 1.92) * (V > 0.08) * (V < 1.92)], -1)
    S.grid(F, 70, 70, M_YARDH, (0, 0, 0), 0.0, uvr=((0.02, 1.98), (0.02, 1.98)))
    for (a, b) in ((P(0.02, 1.98, 0), np.array([T * 1.96, 0, 0])), (P(1.98, 0.02, 0), np.array([0, T * 1.96, 0]))):
        plane(S, a, b, np.array([0, 0, 0.5]), 40, 2, CG.M_YARDSIDE)
    for k in range(12):
        u, v = rng.uniform(SU0 + 0.05, SU1), rng.uniform(SV1 - 0.02, SV1 + 0.16)
        a = rng.uniform(0, math.pi); L = rng.uniform(1.2, 2.4); c = P(u, v, 0.72)
        d = np.array([math.cos(a), math.sin(a), 0]) * L / 2
        tube(S, c - d, c + d, 0.11, M_ROM, prm=(rng.random(), 0, 0), nr=3, nl=2)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear(); K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
    R = {}
    s0 = S.ns; ground(S, rng); R["g"] = (s0, S.ns)
    s0 = S.ns
    rail_side(S, rng, F0, F0, F1, F0)
    rail_side(S, rng, F0, F0, F0, F1)
    tram(S, rng, F0, F0, FH + 1.5, r=1.25)
    chai(S, rng); mang(S, rng)
    mang(S, rng, P(1.5, 1.04, 3.0), P(1.5, 1.66, 3.0), R=2.8, fill=water_fill)   # Link 09:02: máng nước như cừu/dê
    R['b'] = (s0, S.ns)
    s0 = S.ns; rail_side(S, rng, F1, F0, F1, 1.0); tram(S, rng, F1, F0, FH + 1.5, r=1.25); R['r0'] = (s0, S.ns)
    s0 = S.ns; rail_side(S, rng, F1, 1.0, F1, F1); tram(S, rng, F1, 1.0, FH + 1.5, r=1.25); tram(S, rng, F1, F1, FH + 1.5, r=1.25); R['r1'] = (s0, S.ns)
    s0 = S.ns; rail_side(S, rng, F0, F1, 1.0, F1); tram(S, rng, F0, F1, FH + 1.5, r=1.25); R['f0'] = (s0, S.ns)
    s0 = S.ns; rail_side(S, rng, 1.0, F1, F1, F1, gate=(GATE[0] - 1.0, GATE[1] - 1.0)); gate(S, rng); R['f1'] = (s0, S.ns)
    build.R = R
    return S, (S.ns, S.ns)


CG.build = build; CG.ground = ground; K.build = build
CG.KEYS = {'b': 0.15, 'r0': 2.495, 'r1': 3.495, 'f0': 2.495, 'f1': 3.495}   # pigs walk all over the pen (game range kept)

if __name__ == '__main__':
    CG.main(sys.argv)
