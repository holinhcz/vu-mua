# Lò gạch cấp 1 (game id logach 2x2, mirror logach2) as a real 3D model in the kho kit (kho3d.py): same renderer, sun,
# materials and sheet layout (bd bn). Link 2026-11-09: "giờ tới công trình con đi" (đợt 1: lò gạch, miếu, giếng).
# Sơ cấp: a small country brick kiln, not a factory:
#  - lò bầu: a squat dome of brick trát đất sét (clay plaster flaking off the bricks), soot over the fire mouth and the crown
#  - the fire mouth (miệng lò) faces the left-front side: a brick arch, glowing coals inside (the game adds the flicker)
#  - a square brick chimney at the back-right (the game puffs the smoke at its top), joined to the dome by a low flue
#  - a lean-to lá shed on 4 tre posts (right side): gạch mộc drying in open lattice stacks + one stack of fired red bricks
#  - fuel: a đống trấu by the mouth (the miền Tây kiln fuel) and a small pile of củi; a đèn bão on the shed post
#   python3 logach3d.py prev OUT.png [n]        python3 logach3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'kho'))
import kho3d as K
from kho3d import (W3, T, nv, UP, Scene, X3, hexc, smooth, vnoise, hash1, plane, tube, disc, lathe, extrude, rrect, rrect_top,
                   box, obox, mat_flat, MATS, GLOSS, M_EARTHSIDE, M_BAMBOO, M_OLDBAMBOO, M_RATTAN, M_FLOOR, M_WOOD, M_BARK,
                   M_SOOT, M_FIRE, M_EMBER, M_HUSK, M_PLANK)

K.BB = (-84, -132, 84, 48)
K.OX, K.OY = 0, -32                          # at.P(2,2)
ZF = 2.4
K.ZF = ZF
SHU0, SHU1, SHV0, SHV1 = 1.34, 1.82, 1.0, 1.62    # all inside the pad (Link: the right posts poked out)   # the drying shed (posts)
K.WU0, K.WU1, K.WV0, K.WV1 = SHU0, SHU1 + 0.06, SHV0, SHV1
K.ZW = 40.0
K.INSIDE_K = 0.3                             # Link 14:07: every building lit like the đình (was)
K.FOOT = (0.06, 1.94, 0.06, 1.94, 0.08)
K.SHEET = 'logach.webp'
K.SEED = 6300
K.WEATHER = True
K.PATCH = None
K.GROUND_SHADOW = False                      # no baked ground shadow (the chimney's ran onto the grass); the game casts real ones

KC = (0.7, 0.7)                              # dome centre (u, v)
KR = 22.0                                    # dome radius at the foot (units)
KH = 40.0                                    # dome height above the pad
MU, MV0, MV1 = 0.7, 1.16, 1.5                # fire mouth: centre u, tunnel from v0 (inside the dome) to the front face v1
WI, WO, HS = 4.8, 8.2, 5.4                   # arch: inner / outer half width, spring height above the pad
CH = (1.37, 1.53, 0.21, 0.37, 58.0)           # chimney u0 u1 v0 v1 top
LAMP = (1.34, 1.66, 33.0)                     # đèn bão (flame centre) on the front-left shed post


# ---------------------------------------------------------------- materials
def _brick(a, b, H=1.6, L=3.8, seed=7.0):
    r = np.floor(b / H); fb = b / H - r
    c = np.floor(a / L + (r % 2) * 0.5); fa = a / L + (r % 2) * 0.5 - c
    h = hash1(c, r, seed)
    mort = (fb < 0.13) | (fa < 0.045)
    return h, mort


BRICK = ['#9a4a33', '#8a412d', '#a3553b', '#7e3b29', '#9c5238']


def mat_kiln(uv, prm, pos, nrm):
    """lò bầu: bricks under a flaking clay plaster, soot on the crown and over the mouth"""
    a, b = uv[:, 1], uv[:, 0]                # round, up the profile (units)
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    h, mort = _brick(a, b)
    brick = K.pal(BRICK, h * 5) * (0.9 + 0.12 * vnoise(a * 2, b * 2, 3.0))[:, None]
    brick = np.where(mort[:, None], hexc('#7a5444')[None], brick)
    n1 = vnoise(a * 0.12, b * 0.16, 11.0) + 0.35 * vnoise(a * 0.5, b * 0.5, 4.0)
    plaster = smooth(0.74, 0.8, n1) * (1 - smooth(KH * 0.55, KH * 0.8, z - ZF))   # coat left in patches, low down
    cl = hexc('#a9694a')[None] * (0.9 + 0.1 * vnoise(a * 0.9, b * 0.9, 6.0) + 0.05 * vnoise(a * 4, b * 4, 2.0))[:, None]
    base = brick * (1 - plaster[:, None]) + cl * plaster[:, None]
    edge = (np.abs(n1 - 0.77) < 0.02) & (plaster > 0.02)        # a thin lip where the coat broke off
    base = np.where(edge[:, None], base * 0.9, base)
    # crack lines in the coat
    base = base * (1 - 0.18 * (1 - smooth(0, 5.0, z - ZF)))[:, None]          # mud splash at the foot
    # soot: the crown and a plume over the mouth
    cx, cy = KC[0] * T, KC[1] * T
    crown = smooth(KH * 0.7, KH + 2, z - ZF) * (0.85 + 0.15 * vnoise(a * 0.15, b * 0.15, 2.0))
    fy = (y - cy) / KR; dx = np.abs(x - MU * T)
    plume = smooth(0.6, 0.88, fy) * (1 - smooth(4.0 + (z - ZF) * 0.2, 7.5 + (z - ZF) * 0.3, dx)) * (1 - smooth(16, 27, z - ZF))
    sk = np.clip(np.maximum(crown * 0.7, plume * 0.8), 0, 1) * (0.88 + 0.12 * vnoise(a * 0.3, b * 0.3, 8.0))
    base = base * (1 - sk[:, None]) + hexc('#2e241f')[None] * sk[:, None]
    return np.clip(base, 0, 1), nrm


def mat_brickw(uv, prm, pos, nrm):
    """brickwork on flat faces (chimney, flue, arch): courses by world height, joints along the face"""
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    s = np.where(np.abs(nrm[:, 0]) > np.abs(nrm[:, 1]), y, x)
    h, mort = _brick(s, z, seed=13.0)
    base = K.pal(BRICK, h * 5) * (0.9 + 0.12 * vnoise(s * 2, z * 2, 3.0))[:, None]
    base = np.where(mort[:, None], hexc('#7a5444')[None], base)
    top = CH[4]
    sk = 0.55 * smooth(top - 12, top + 1, z) * ((x > CH[0] * T - 1) & (x < CH[1] * T + 1) & (y > CH[2] * T - 1) & (y < CH[3] * T + 1))
    sk = np.maximum(sk, prm[:, 0])            # prm[0]: extra soot (the mouth arch)
    sk = np.clip(sk * (0.8 + 0.3 * vnoise(s * 0.6, z * 0.6, 5.0)), 0, 1)
    base = base * (1 - sk[:, None]) + hexc('#2b221d')[None] * sk[:, None]
    return np.clip(base, 0, 1), nrm


def mat_moc(uv, prm, pos, nrm):
    """gạch mộc: sun-dried raw clay bricks, pale grey-tan, each a touch different"""
    t = prm[:, 0]
    c0, c1 = hexc('#c6a676'), hexc('#b59466')
    base = c0[None] * (1 - t[:, None]) + c1[None] * t[:, None]
    base = base * (0.93 + 0.08 * vnoise(pos[:, 0] * 1.3, pos[:, 1] * 1.3 + pos[:, 2], 3.0))[:, None]
    return np.clip(base, 0, 1), nrm


def mat_red(uv, prm, pos, nrm):
    """fired bricks: red, a few dark burnt ones"""
    t = prm[:, 0]
    base = K.pal(BRICK + ['#7a3626', '#b8603e'], t * 7)
    base = base * (0.92 + 0.1 * vnoise(pos[:, 0] * 1.5, pos[:, 1] * 1.5 + pos[:, 2], 3.0))[:, None]
    return np.clip(base, 0, 1), nrm


def mat_husk(uv, prm, pos, nrm):
    """trấu: rice husk, golden brown, grainy"""
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    g = vnoise(x * 5.0, y * 5.0 + z * 5.0, 7.0); g2 = vnoise(x * 0.5, y * 0.5 + z, 3.0)
    base = hexc('#c99a52')[None] * (0.86 + 0.16 * g + 0.08 * g2)[:, None]
    dk = hash1(np.floor(x * 6), np.floor(y * 6 + z * 6), 5.0) > 0.9
    base = np.where(dk[:, None], base * 0.8, base)
    return np.clip(base, 0, 1), nrm


def mat_clay(uv, prm, pos, nrm):
    """đất sét ướt: grey-brown, smooth with spade marks"""
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    base = hexc('#6a5442')[None] * (0.88 + 0.12 * vnoise(x * 0.7, y * 0.7, 4.0) + 0.05 * vnoise(x * 3, y * 3 + z, 2.0))[:, None]
    return np.clip(base, 0, 1), nrm


def mat_ash(uv, prm, pos, nrm):
    x, y = pos[:, 0], pos[:, 1]
    k = (1 - smooth(0.25, 1.0, uv[:, 0])) * (0.75 + 0.35 * vnoise(x * 0.5, y * 0.5, 3.0))
    k = np.clip(k, 0, 1)
    base = hexc('#c3a274')[None] * (1 - k[:, None]) + hexc('#4e423a')[None] * k[:, None]
    base = base * (0.94 + 0.08 * vnoise(x * 1.6, y * 1.6, 9.0))[:, None]
    return np.clip(base, 0, 1), nrm


M_KILN, M_BRICKW, M_MOC, M_RED, M_TRAU, M_ASH, M_HOLE, M_CLAY = range(140, 148)
MATS.update({M_KILN: mat_kiln, M_BRICKW: mat_brickw, M_MOC: mat_moc, M_RED: mat_red, M_TRAU: mat_husk, M_ASH: mat_ash,
             M_HOLE: mat_flat('#1a100b'), M_CLAY: mat_clay})


# ---------------------------------------------------------------- helpers
def lathe2(S, c, prof, mat, prm=(0, 0, 0), na=30):
    """surface of revolution with uv in game units (along the profile, round the foot)"""
    zs = np.array([p[0] for p in prof], float); rs = np.array([p[1] for p in prof], float); c = np.asarray(c, float)
    sl = np.concatenate([[0], np.cumsum(np.hypot(np.diff(zs), np.diff(rs)))]); C = 2 * math.pi * rs.max()
    def F(U, V):
        z = np.interp(U, sl, zs); r = np.interp(U, sl, rs); th = V / C * 2 * math.pi
        return np.stack([c[0] + r * np.cos(th), c[1] + r * np.sin(th), c[2] + z], -1)
    S.grid(F, max(len(prof) * 3, int(sl[-1] / 0.7) + 2), na, mat, prm, 0.0, uvr=((0, sl[-1]), (0, C)), close_v=True, flip=True)


def bam(S, rng, a, b, r, nl=6, mat=M_BAMBOO):
    tube(S, a, b, r, mat, prm=(rng.random(), rng.random(), 0), nr=8, nl=nl)


def arch_pts(w, hs, n=14):
    """arch outline (x across, z up) from the left foot over the top to the right foot"""
    pts = [(-w, 0.0)]
    for k in range(n + 1):
        t = math.pi * (1 - k / n); pts.append((w * math.cos(t), hs + w * math.sin(t)))
    pts.append((w, 0.0))
    return np.array(pts)


def arch_shell(S, w, v0, v1, mat, prm=(0, 0, 0), inward=False):
    P = arch_pts(w, HS); s = np.concatenate([[0], np.cumsum(np.hypot(*np.diff(P, axis=0).T))])
    def F(U, V):
        x = np.interp(U, s, P[:, 0]); z = np.interp(U, s, P[:, 1])
        return np.stack([MU * T + x, V * T, ZF + z], -1)
    S.grid(F, len(P) * 2, 6, mat, prm, 0.0, uvr=((0, s[-1]), (v0, v1)), flip=inward)


def arch_ring(S, v, mat, prm=(0, 0, 0)):
    Pi = arch_pts(WI, HS); Po = arch_pts(WO, HS)
    def F(U, V):
        k = np.clip(np.round(U).astype(int), 0, len(Pi) - 1)
        x = Pi[k, 0] + (Po[k, 0] - Pi[k, 0]) * V; z = Pi[k, 1] + (Po[k, 1] - Pi[k, 1]) * V
        return np.stack([MU * T + x, np.full_like(x, v * T), ZF + z], -1)
    S.grid(F, len(Pi), 3, mat, prm, 0.0, uvr=((0, len(Pi) - 1), (0, 1)))


def flame(S, c, r, h, ph):
    def F(U, V):
        th = V * 2 * math.pi; rr = r * (1 - U) ** 0.8 * (1 + 0.15 * np.sin(th * 3 + ph))
        sway = 0.6 * np.sin(U * 3 + ph) * U
        return np.stack([c[0] + rr * np.cos(th) + sway, c[1] + rr * np.sin(th) * 0.7, c[2] + U * h], -1)
    S.grid(F, 7, 12, M_FIRE, (0, 0, 0), 0.0, uvr=((0, 1), (0, 1)), close_v=True, flip=True)


def brick_box(S, c, along_u, L, W, H, mat, t):
    hx, hy = (L / 2, W / 2) if along_u else (W / 2, L / 2)
    box(S, c + np.array([-hx, -hy, 0]), c + np.array([hx, hy, H]), mat, prm=(t, 0, 0))


# ---------------------------------------------------------------- the model
def pad(S):
    rrect_top(S, 0.06, 1.94, 0.06, 1.94, 0.06, ZF, M_FLOOR)
    extrude(S, rrect(0.06, 1.94, 0.06, 1.94, 0.06), 0.0, ZF, M_EARTHSIDE, flare=0.6)
    # ash and a few coals raked out in front of the mouth (irregular, flat)
    c = W3(MU, MV1 + 0.08, ZF + 0.08)
    def F(U, V):
        th = V * 2 * math.pi; rr = U * (7.5 + 1.4 * np.sin(th * 3 + 1.0) + 0.8 * np.sin(th * 5))
        return np.stack([c[0] + rr * np.cos(th) * 1.4, c[1] + rr * np.sin(th), np.full_like(rr, c[2])], -1)
    S.grid(F, 8, 36, M_ASH, (0, 0, 0), 0.0, uvr=((0, 1), (0, 1)), close_v=True)


def kiln(S, rng):
    c = W3(KC[0], KC[1], ZF)
    f = KH / 37.0
    prof = [(0, KR + 0.8), (1.2, KR + 0.4), (6.0 * f, KR), (13.0 * f, KR * 0.95), (20.0 * f, KR * 0.85), (26.0 * f, KR * 0.7),
            (31.0 * f, KR * 0.5), (34.6 * f, KR * 0.28), (36.4 * f, KR * 0.1), (KH, 0.0)]
    lathe2(S, c, prof, M_KILN, na=72)
    # a small vent on the crown (lỗ thăm lửa) with a brick lip
    lathe2(S, c + np.array([0, 0, KH - 0.6]), [(0, 3.2), (1.2, 2.8), (1.5, 2.0), (1.3, 0.0)], M_BRICKW, prm=(0.7, 0, 0), na=20)
    disc(S, c + np.array([0, 0, KH + 1.0]), (0, 0, 1), 1.9, M_HOLE, nr=2, na=16)
    # fire mouth: brick arch tunnel out of the dome, sooty
    arch_shell(S, WO, MV0, MV1, M_BRICKW, prm=(0.45, 0, 0))
    arch_ring(S, MV1, M_BRICKW, prm=(0.55, 0, 0))
    arch_shell(S, WI, MV1 - 0.2, MV1, M_BRICKW, prm=(0.9, 0, 0), inward=True)
    vb = MV1 - 0.2
    plane(S, W3(MU, vb, ZF) + np.array([-WI, 0, 0]), np.array([2 * WI, 0, 0]), np.array([0, 0, HS + WI]), 6, 6, M_HOLE)
    disc(S, W3(MU, MV1 - 0.1, ZF + 0.1), (0, 0, 1), WI, M_HOLE, nr=2, na=16)
    # coals + small flames in the mouth
    for k in range(6):
        e = W3(MU, vb + 0.03 + 0.025 * (k % 3), ZF + 0.6) + np.array([(k - 2.5) * 1.3, 0, 0])
        X3.ellipsoid(S, e, 1.0, 0.8, 0.7, M_EMBER, nu=5, nvv=8)
    for k, (dx, h) in enumerate(((-2.2, 4.2), (0.0, 6.0), (2.1, 4.8))):
        flame(S, W3(MU, vb + 0.06, ZF + 0.8) + np.array([dx, 0, 0]), 1.5, h, k * 1.7)
    # threshold bricks
    for k in range(4):
        brick_box(S, W3(MU, MV1 + 0.03, ZF) + np.array([-5.4 + k * 3.6, 0, 0]), True, 3.4, 1.8, 1.1, M_RED, rng.random())
    # flue to the chimney and the chimney
    u0, u1, v0, v1, top = CH
    box(S, W3(1.1, 0.22, ZF), W3(u0 + 0.02, 0.36, ZF + 10.0), M_BRICKW)
    box(S, W3(u0, v0, ZF), W3(u1, v1, top - 3.0), M_BRICKW)
    box(S, W3(u0 - 0.012, v0 - 0.012, top - 1.8), W3(u1 + 0.012, v1 + 0.012, top), M_BRICKW)   # one cap course
    plane(S, W3(u0 + 0.05, v0 + 0.05, top - 0.1), W3(u1 - 0.05, 0, 0) - W3(u0 + 0.05, 0, 0),
          W3(0, v1 - 0.05, 0) - W3(0, v0 + 0.05, 0), 3, 3, M_HOLE)


def shed(S, rng):
    hi, lo = 47.0, 36.0                       # lean-to: high at the kiln side (u0), eave at the front right (u1)
    zt = lambda u: hi + (lo - hi) * (u - (SHU0 - 0.06)) / ((SHU1 + 0.08) - (SHU0 - 0.06))
    for (u, v) in ((SHU0, SHV0), (SHU1, SHV0), (SHU0, SHV1), (SHU1, SHV1)):
        bam(S, rng, W3(u, v, ZF - 1.0), W3(u, v, zt(u) + 0.6), 1.05, nl=10, mat=M_OLDBAMBOO)
    for u in (SHU0, SHU1):                    # beams along v carry the rafters
        bam(S, rng, W3(u, SHV0 - 0.06, zt(u) - 0.4), W3(u, SHV1 + 0.06, zt(u) - 0.4), 0.85, nl=10, mat=M_OLDBAMBOO)
    for v in (SHV0, SHV1):                    # tie beams
        bam(S, rng, W3(SHU0 - 0.04, v, zt(SHU0) - 3.4), W3(SHU1 + 0.04, v, zt(SHU1) - 3.4), 0.7, nl=8, mat=M_OLDBAMBOO)
    # roof: one slope of lá down to the front right
    e = W3(SHU1 + 0.1, SHV0 - 0.12, lo - 1.0)
    top = W3(SHU0 - 0.02, SHV0 - 0.12, hi + 1.0)
    up = top - e; LB = np.linalg.norm(up); su = up / LB
    ax = np.array([0.0, 1.0, 0.0]); Lu = (SHV1 - SHV0 + 0.24) * T
    n_out = nv(np.cross(ax, su))
    K.slope(S, rng, e, su, n_out, LB, ax, Lu, th=1.8, course=3.0)
    for fr in (0.3, 0.72):
        p0 = e + su * LB * fr + n_out * 1.7 + ax * 1.0
        tube(S, p0, p0 + ax * (Lu - 2.0), 0.5, M_OLDBAMBOO, prm=(rng.random(), 0.5, 0), nr=8, nl=14)
    p0 = e + su * (LB - 0.5) + n_out * 1.5
    tube(S, p0 - ax * 0.5, p0 + ax * (Lu + 0.5), 0.9, M_OLDBAMBOO, prm=(0.3, 0.4, 0), nr=10, nl=16)
    # the đèn bão on a peg of the front-left post
    tube(S, W3(SHU0, SHV1, LAMP[2] + 5.4), W3(LAMP[0], LAMP[1], LAMP[2] + 5.8), 0.35, M_BAMBOO, nr=6, nl=2)
    tube(S, W3(LAMP[0], LAMP[1], LAMP[2] + 5.6), W3(LAMP[0], LAMP[1], LAMP[2] + 2.4), 0.14, M_SOOT, nr=4, nl=2)
    K.hlamp(S, W3(*LAMP))


def bricks(S, rng):
    # gạch mộc drying in open lattice stacks under the shed: even courses run along u, odd along v, gaps for the air
    L, Wd, H = 3.5, 1.7, 1.15
    for (u0, v0, nb, nr_, nz) in ((SHU0 + 0.1, SHV0 + 0.07, 3, 5, 8),):
        for k in range(nz):
            z = ZF + k * H
            if k % 2 == 0:
                for i in range(nb):
                    for j in range(nr_):
                        brick_box(S, W3(u0, v0, z) + np.array([L / 2 + i * 4.0, Wd / 2 + j * 2.7, 0]), True, L, Wd, H, M_MOC, rng.random())
            else:
                for i in range(int(nb * 4.0 / 2.7)):
                    for j in range(max(1, int(round((nr_ - 1) * 2.7 / 4.0 + 0.6)))):
                        brick_box(S, W3(u0, v0, z) + np.array([Wd / 2 + i * 2.7, L / 2 + j * 4.0, 0]), False, L, Wd, H, M_MOC, rng.random())
    # fired red bricks stacked tight at the front of the shed
    u0, v0 = SHU0 + 0.14, SHV1 - 0.15
    for k in range(6):
        for i in range(4):
            for j in range(2):
                c = W3(u0, v0, ZF + k * H) + np.array([2.0 + i * 3.7 + (0.9 if k % 2 else 0) * (i < 4), 1.0 + j * 1.85, 0])
                if k == 5 and i > 1: continue
                brick_box(S, c, True, L, Wd, H, M_RED, rng.random())


def fuel(S, rng):
    # đống trấu by the mouth (left), and a scoop of it spilt toward the fire
    c = W3(0.36, 1.62, ZF)
    def F(U, V):
        th = V * 2 * math.pi; R = 8.5 * (1 + 0.08 * np.sin(th * 3 + 0.5))
        r = R * (1 - U) ; z = 12.0 * (1 - (1 - U) ** 1.6)
        return np.stack([c[0] + r * np.cos(th), c[1] + r * np.sin(th) * 0.9, c[2] + z], -1)
    S.grid(F, 10, 36, M_TRAU, (0, 0, 0), 0.0, uvr=((0, 1), (0, 1)), close_v=True, flip=True)
    X3.ellipsoid(S, W3(0.52, 1.66, ZF), 3.4, 2.6, 1.4, M_TRAU, nu=6, nvv=14)
    # củi chẻ: split firewood stacked criss-cross behind the shed, right of the chimney (clear of the mouth)
    c0 = W3(1.74, 0.6, ZF)
    for k in range(4):
        for i in range(4):
            if k % 2 == 0:
                a = c0 + np.array([-4.5, -3.6 + i * 2.4, 0.8 + k * 1.5]); b = a + np.array([9.0, 0.3 * (i % 2), 0])
            else:
                a = c0 + np.array([-3.6 + i * 2.4, -4.5, 0.8 + k * 1.5]); b = a + np.array([0.3 * (i % 2), 9.0, 0])
            tube(S, a, b, 0.75, M_BARK, prm=(rng.random(), 0, 0), nr=5, nl=4)
            disc(S, b, b - a, 0.75, M_WOOD, nr=2, na=5)
            disc(S, a, a - b, 0.75, M_WOOD, nr=2, na=5)
    # đống đất sét: the raw clay for the next batch, a low wet heap with a cuốc in it (front-right corner)
    c = W3(1.64, 1.74, ZF)
    def F(U, V):
        th = V * 2 * math.pi; R = 5.5 * (1 + 0.12 * np.sin(th * 3 + 0.7) + 0.06 * np.sin(th * 7))
        r = R * (1 - U); z = 4.2 * (1 - (1 - U) ** 1.8)
        return np.stack([c[0] + r * np.cos(th), c[1] + r * np.sin(th), c[2] + z], -1)
    S.grid(F, 8, 36, M_CLAY, (0, 0, 0), 0.0, uvr=((0, 1), (0, 1)), close_v=True, flip=True)
    tube(S, c + np.array([0.5, -0.3, 3.0]), c + np.array([4.0, -6.5, 13.0]), 0.45, M_WOOD, prm=(0.4, 0, 0), nr=6, nl=6)
    box(S, c + np.array([-0.6, -1.4, 0.6]), c + np.array([1.6, 0.8, 3.2]), K.M_TIN)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear()
    K.LIGHTS2.append((W3(MU, MV1 + 0.05, ZF + 4.0), hexc('#ff7a2a'), 16.0, 1.9, 'all'))   # the fire lights the yard
    K.LIGHTS2.append((W3(*LAMP), hexc('#ff9645'), 16.0, 2.2, 'all'))
    K.GLOWS[:] = [(W3(*LAMP), 0.2, 0.85)]
    K.GROUND_GLOW[:] = [(MU, MV1 + 0.2, 20.0, 0.22)]
    pad(S)
    kiln(S, rng)
    shed(S, rng)
    bricks(S, rng)
    fuel(S, rng)
    return S, (S.ns, S.ns)


K.build = build

if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        n = len(sys.argv) > 3 and sys.argv[3] == 'n'
        K.render(1, n, 'b').save(sys.argv[2])
    elif sys.argv[1] == 'atlas':
        out, tab = sys.argv[2], sys.argv[3]
        G = {}; frames = {}
        for n in (0, 1):
            im = K.render(1, bool(n), 'b'); bb = im.getbbox(); frames['b' + ('n' if n else 'd')] = (im.crop(bb), bb)
        keys = ['bd', 'bn']; x = 0; sc = float(K.PXU); H = max(f[0].height for f in frames.values()); BB = K.BB
        sheet = Image.new('RGBA', (sum(frames[k][0].width + 2 for k in keys), H), (0, 0, 0, 0))
        for k in keys:
            im, bb = frames[k]; sheet.paste(im, (x, 0))
            G[k] = [x, 0, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
            x += im.width + 2
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, K.SHEET), 'WEBP', quality=92, method=6); json.dump(G, open(tab, 'w'))
        print('sheet', sheet.size)
