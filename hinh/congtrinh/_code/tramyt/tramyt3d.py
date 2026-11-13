# Nông Trại Chung: Trạm y tế cấp 1 (game id tramyt 3x3, mirror tramyt2) as a real 3D model (kho kit + nhà ba gian roof/walls).
# Link 2026-11-09 06:08 "check tiếp trạm y tế"; sơ cấp = tre, gỗ tràm, lá, simple (Link 03:58). Cấp 2 (tramyt_l2) stays old.
# A trạm y tế xã in the countryside, readable at a glance:
#  - a nhà lá with a hip lá roof; the vách phên are trát vôi trắng (white-washed: the one thing that says "trạm y tế")
#  - a big red cross painted on a white board on the right end wall; one door with a white curtain, song tre windows
#  - a hiên on 2 tràm columns: a long băng ghế tre for the sick waiting, a thau rửa tay on a stand + lu nước, đèn bão
#  - inside: a giường khám tre with a white sheet, a tủ thuốc tre with bottles, đèn dầu
#  - the yard: a TRẠM Y TẾ board on 2 tre posts (the game paints the words), a vườn thuốc nam (sả, ngải cứu, lá lốt)
#   python3 tramyt3d.py prev OUT.png [n]        python3 tramyt3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'bagian'))
import bagian3d as B
from bagian3d import (K, SP, W3, T, nv, UP, Scene, hexc, vnoise, plane, tube, disc, lathe, extrude, rrect, rrect_top, box, obox,
                      mat_flat, MATS, M_EARTHSIDE, M_BAMBOO, M_WEAVE_F, M_GLAZE, M_LID, M_PLANK, M_RATTAN, M_OLDBAMBOO,
                      M_FLOOR, M_WOOD, M_BARK, M_SOOT, M_COCO, M_WATER, M_CHIEU, M_STONE, M_TIN, bam, ell)

K.BB = (-104, -150, 104, 56)
K.OX, K.OY = 0, -48                           # at.P(3,3)
ZF, ZH = 2.4, 7.4
U0, U1, V0, V1 = 0.3, 2.7, 0.3, 1.55          # the walls
ZW = 58.0
PV = 1.86                                     # 2 tràm columns at the hiên ends (a column at depth d covers the wall d to its left)
CU = (0.4, 2.6)
EU0, EU1, BV, EV, EZ = 0.14, 2.86, 0.14, 2.02, 50.0   # eaves; the front one carries on over the hiên
RA, RB, RV, RZ = 0.95, 2.05, 1.0, 84.0                 # lower: the roof must not swamp the white walls
DOOR = (1.3, 1.72); DZ = ZH + 28.0
FWIN = ((0.52, 0.98),); RWIN = ((0.48, 0.92),); WZ = (ZH + 11.0, ZH + 29.0)
CROSS = (0.98, 1.42, ZH + 12.0, ZH + 38.0)    # the white board with the red cross on the right end wall (v0, v1, z0, z1)
SIGN = (0.16, 1.5, 2.80, 2.83, 13.0, 23.5)    # TRẠM Y TẾ board (game text at (1.02, 2.836, 18.0), right of the cross)
LAMP = (0.6, 1.9, 40.0)                       # over the bench (critique 6: not crowded with the washstand)
OIL = (0.82, 1.22, ZH + 13.0 + 4.2)           # đèn dầu on the table by the giường khám
FLAGP = (0.12, 2.36)                           # cờ chữ thập đỏ on a tre pole: says trạm y tế from afar (critique 2)
BANNER = (0.72, 1.18, 1.875, 35.5, 47.0)       # white board with a red cross hung from the hiên beam (u0, u1, v, z0, z1)

for k_, v_ in dict(ZF=ZF, ZH=ZH, U0=U0, U1=U1, V0=V0, V1=V1, ZW=ZW, PV=PV, EU0=EU0, EU1=EU1, BV=BV, EV=EV, EZ=EZ,
                   RA=RA, RB=RB, RV=RV, RZ=RZ, DZ=DZ, WZ=WZ).items():
    setattr(B, k_, v_)
K.ZW, K.ZF = ZW, ZF
K.RZ, K.EZ = RZ, EZ
K.WU0, K.WU1, K.WV0, K.WV1 = U0, U1, V0, V1
K.INSIDE_K = 0.3
K.FOOT = (0.06, 2.94, 0.06, 2.94, 0.08)
K.GROUND_SHADOW = False                       # no baked ground shadow (real sun shadows come later)
K.SHEET = 'tramyt.webp'
K.SEED = 7100
K.RIDGE_R, K.BATTEN_R, K.POLE_R, K.TIE_R = 2.0, 0.5, 0.4, 0.22
K.NIGHT_EMIT = {}

M_VOI, M_CLOTHW, M_REDX, M_SIGNW, M_SIGNF, M_SA, M_NGAI, M_LOT, M_BOTTLE, M_BOTTLE2, M_CURT, M_FLAGX, M_BANX = range(250, 263)


def mat_voi(uv, prm, pos, nrm):
    """vách phên trát đất, quét vôi trắng: lime gone creamy, rain-splashed brown at the foot, flaked in patches"""
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    a = x + y
    n1 = vnoise(a * 0.09, z * 0.09, 3.0); n2 = vnoise(a * 0.5, z * 0.5, 7.0)
    base = hexc('#ece5d3')[None] * (0.93 + 0.06 * n1 + 0.03 * n2)[:, None]
    stain = np.clip(1 - (z - ZH) / 7.0, 0, 1) ** 1.3 * (0.6 + 0.4 * vnoise(a * 0.3, z * 0.1, 9.0))      # splash at the foot
    base = base * (1 - 0.42 * stain[:, None]) + hexc('#8c7254')[None] * 0.42 * stain[:, None]
    streak = np.clip((vnoise(a * 0.6, z * 0.02, 13.0) - 0.62) * 4, 0, 1) * np.clip((ZW - z) / 12, 0, 1) ** 0.3   # drips under the eave
    base = base * (1 - 0.12 * streak[:, None])
    flake = np.clip((vnoise(a * 0.16, z * 0.16, 17.0) - 0.74) * 6, 0, 1)                             # lime fallen off: mud
    base = base * (1 - flake[:, None]) + hexc('#a68a64')[None] * flake[:, None]
    return np.clip(base, 0, 1), nrm


def mat_signw(uv, prm, pos, nrm):
    """the yard board: white paint, a red cross at its left end (the game paints the words)"""
    x, z = pos[:, 0], pos[:, 2]
    u0, u1, _, _, z0, z1 = SIGN
    cx = u0 * T + 6.0; cz = (z0 + z1) / 2
    cr = ((np.abs(x - cx) < 1.2) & (np.abs(z - cz) < 3.6)) | ((np.abs(x - cx) < 3.6) & (np.abs(z - cz) < 1.2))
    base = hexc('#f2eee2')[None] * (0.95 + 0.05 * vnoise(x * 0.3, z * 0.3, 4.0))[:, None]
    base = np.where(cr[:, None], hexc('#c9241c')[None], base)
    return np.clip(base, 0, 1), nrm


def mat_flagx(uv, prm, pos, nrm):
    """white cotton flag with a red cross (uv in 0..1 over the cloth)"""
    a, b = uv[:, 0], uv[:, 1]
    cr = ((np.abs(a - 0.5) < 0.09) & (np.abs(b - 0.5) < 0.32)) | ((np.abs(a - 0.5) < 0.24) & (np.abs(b - 0.5) < 0.12))
    base = hexc('#f0ece0')[None] * (0.94 + 0.06 * vnoise(a * 4, b * 4, 3.0))[:, None]
    return np.clip(np.where(cr[:, None], hexc('#c9241c')[None], base), 0, 1), nrm


def mat_banx(uv, prm, pos, nrm):
    """the hiên board: a red cross on white, the paint a bit worn"""
    x, z = pos[:, 0], pos[:, 2]
    u0, u1, v, z0, z1 = BANNER
    cx = (u0 + u1) / 2 * T; cz = (z0 + z1) / 2; w = 1.6; L = 4.4
    cr = ((np.abs(x - cx) < w) & (np.abs(z - cz) < L)) | ((np.abs(x - cx) < L) & (np.abs(z - cz) < w))
    base = hexc('#efeadc')[None] * (0.93 + 0.07 * vnoise(x * 0.4, z * 0.4, 8.0))[:, None]
    return np.clip(np.where(cr[:, None], hexc('#c9241c')[None], base), 0, 1), nrm


def mat_cross(uv, prm, pos, nrm):
    """the end-wall board: a red cross on white"""
    y, z = pos[:, 1], pos[:, 2]
    v0, v1, z0, z1 = CROSS
    cy = (v0 + v1) / 2 * T; cz = (z0 + z1) / 2; w = 2.0; L = 7.2
    cr = ((np.abs(y - cy) < w) & (np.abs(z - cz) < L)) | ((np.abs(y - cy) < L) & (np.abs(z - cz) < w))
    base = hexc('#f1ede0')[None] * (0.94 + 0.06 * vnoise(y * 0.3, z * 0.3, 6.0))[:, None]
    base = np.where(cr[:, None], hexc('#c9241c')[None], base)
    return np.clip(base, 0, 1), nrm


_leaf0, _ridge0 = MATS[K.M_LEAF], MATS[K.M_RIDGE]


def mat_leaf_t(uv, prm, pos, nrm):
    col, n = _leaf0(uv, prm, pos, nrm)
    w = vnoise(pos[:, 0] * 0.07, pos[:, 1] * 0.07 + pos[:, 2] * 0.05, 31.0)
    old = np.clip((w - 0.45) * 3.0, 0, 1)[:, None]
    c = col * 0.72 + hexc('#9a8458')[None] * 0.2
    return np.clip(c * (1 - 0.3 * old) + hexc('#6f6248')[None] * 0.22 * old, 0, 1), n


def mat_ridge_t(uv, prm, pos, nrm):
    col, n = _ridge0(uv, prm, pos, nrm)
    return np.clip(col * 0.7 + hexc('#8a7550')[None] * 0.2, 0, 1), n


MATS.update({K.M_LEAF: mat_leaf_t, K.M_RIDGE: mat_ridge_t})
MATS.update({M_CURT: mat_flat('#9fb0ad'), M_FLAGX: mat_flagx, M_BANX: mat_banx})
MATS.update({M_VOI: mat_voi, M_CLOTHW: mat_flat('#efebe0'), M_REDX: mat_cross, M_SIGNW: mat_signw,
             M_SIGNF: mat_flat('#2f5d8f'), M_SA: mat_flat('#6f8f3c'), M_NGAI: mat_flat('#8a9c76'), M_LOT: mat_flat('#2e5e26'),
             M_BOTTLE: mat_flat('#6e4420'), M_BOTTLE2: mat_flat('#e8e4d8')})


# ---------------------------------------------------------------- house
def walls(S, rng):
    e = 0.004
    holes = [(DOOR[0], DOOR[1], ZH, DZ)] + [(a, b, WZ[0], WZ[1]) for (a, b) in FWIN]
    B.holed(S, U0, U1, holes, lambda a, b, z0, z1: B.wall_u(S, a, b, z0, z1, V1))
    B.wall_u(S, U0, U1, ZH, ZW, V0)
    B.holed(S, V0, V1, [(a, b, WZ[0], WZ[1]) for (a, b) in RWIN], lambda a, b, z0, z1: B.wall_v(S, a, b, z0, z1, U1))
    B.wall_v(S, V0, V1, ZH, ZW, U0)
    B.wall_v(S, V0, V1 - 0.02, ZH, ZW, 1.75)                                          # vách ngăn: phòng khám | phòng thuốc
    for (u, v) in ((U0, V0), (U0, V1), (U1, V0), (U1, V1), (1.75, V1)):
        bam(S, rng, W3(u, v, ZH - 0.5), W3(u, v, ZW + 1.0), 1.25, nl=12, mat=M_OLDBAMBOO)
    for v in (V0, V1):
        bam(S, rng, W3(U0 - 0.05, v, ZW), W3(U1 + 0.05, v, ZW), 1.2, nl=20, mat=M_OLDBAMBOO)
    for u in (U0, U1):
        bam(S, rng, W3(u, V0 - 0.05, ZW - 0.9), W3(u, V1 + 0.05, ZW - 0.9), 1.1, nl=14, mat=M_OLDBAMBOO)
    # the door: tre frame, lintel, ngạch; a white curtain on a string, drawn to the right, gathered
    d0, d1 = DOOR
    for u in (d0, d1):
        bam(S, rng, W3(u, V1 + e, ZH), W3(u, V1 + e, DZ + 0.6), 0.85, nl=6)
    bam(S, rng, W3(d0 - 0.03, V1 + e, DZ), W3(d1 + 0.03, V1 + e, DZ), 0.85, nl=6)
    box(S, W3(d0 - 0.02, V1 - 0.03, ZH), W3(d1 + 0.02, V1 + 0.03, ZH + 0.9), M_WOOD, prm=(0.4, 0, 0))
    tube(S, W3(d0, V1 + 0.02, DZ - 1.6), W3(d1, V1 + 0.02, DZ - 1.6), 0.15, M_SOOT, nr=4, nl=2)
    ua, ub = d1 - 0.2, d1 - 0.01                                                      # rèm trắng: a pleated panel, right half
    def Fc(U, V):
        u = ua * T + U * (ub - ua) * T
        return np.stack([u, (V1 + 0.03) * T + 0.55 * np.sin(U * 9 * math.pi) + 0.25 * V, DZ - 1.6 - V * (DZ - ZH - 2.5)], -1)
    S.grid(Fc, 36, 8, M_CURT, (0, 0, 0), 0.0)
    for (a, b) in FWIN:
        B.window(S, rng, a, b, WZ[0], WZ[1], 'u')
    for (a, b) in RWIN:
        B.window(S, rng, a, b, WZ[0], WZ[1], 'v')
    # red cross board on the right end wall, framed in tre
    v0, v1, z0, z1 = CROSS
    plane(S, W3(U1 + 0.012, v0, z0), W3(0, v1, 0) - W3(0, v0, 0), np.array([0, 0, z1 - z0]), 12, 12, M_REDX)
    for (p, q) in ((W3(U1 + 0.016, v0, z0), W3(U1 + 0.016, v1, z0)), (W3(U1 + 0.016, v0, z1), W3(U1 + 0.016, v1, z1)),
                   (W3(U1 + 0.016, v0, z0), W3(U1 + 0.016, v0, z1)), (W3(U1 + 0.016, v1, z0), W3(U1 + 0.016, v1, z1))):
        tube(S, p, q, 0.6, M_BAMBOO, prm=(rng.random(), 0.3, 0), nr=6, nl=4)


def platform(S, rng):
    rrect_top(S, 0.06, 2.94, 0.06, 2.94, 0.06, ZF, M_FLOOR)
    extrude(S, rrect(0.06, 2.94, 0.06, 2.94, 0.06), 0.0, ZF, M_EARTHSIDE, flare=0.6)
    rrect_top(S, 0.16, 2.84, 0.16, 2.06, 0.04, ZH, M_FLOOR, prm=(0.5, 0, 0))              # nền đất đắp under house + hiên
    extrude(S, rrect(0.16, 2.84, 0.16, 2.06, 0.04), ZF - 0.1, ZH, M_EARTHSIDE, flare=0.25)
    bam(S, rng, W3(0.16, 2.07, ZH - 0.9), W3(2.84, 2.07, ZH - 0.9), 0.7, nl=22, mat=M_OLDBAMBOO)
    bam(S, rng, W3(2.85, 0.16, ZH - 0.9), W3(2.85, 2.07, ZH - 0.9), 0.7, nl=20, mat=M_OLDBAMBOO)
    zs = (ZF + ZH) / 2
    rrect_top(S, 1.3, 1.72, 2.04, 2.22, 0.05, zs, M_FLOOR, prm=(0.5, 0, 0))
    extrude(S, rrect(1.3, 1.72, 2.04, 2.22, 0.05), ZF - 0.1, zs, M_EARTHSIDE, flare=0.2)


def columns(S, rng):
    zt = EZ - 1.2
    for u in CU:
        c = W3(u, PV, ZH - 0.4)
        lathe(S, c, [(0, 3.0), (0.8, 3.0), (1.6, 2.5), (1.9, 0.0)], B.D_TANG if hasattr(B, 'D_TANG') else M_STONE, na=16)
        B.post(S, rng, u, PV, ZH + 1.6, zt - 0.6)
    bam(S, rng, W3(CU[0] - 0.1, PV, zt - 0.4), W3(CU[1] + 0.1, PV, zt - 0.4), 1.2, nl=20)
    for u in CU:
        bam(S, rng, W3(u, PV, zt - 0.4), W3(u, V1, ZW - 4.0), 0.8, nl=4)


# ---------------------------------------------------------------- hiên, inside, yard
def bench(S, rng, u0, u1, v):
    """băng ghế tre: a long slatted seat, a back rail against the wall"""
    zs = ZH + 8.0
    for u in (u0 + 0.04, (u0 + u1) / 2, u1 - 0.04):
        for dv in (-0.07, 0.07):
            bam(S, rng, W3(u, v + dv, ZH), W3(u, v + dv, zs - 0.5), 0.55, nl=3)
    for k in range(6):
        vv = v - 0.09 + 0.18 * (k + 0.5) / 6
        bam(S, rng, W3(u0, vv, zs - 0.4), W3(u1, vv, zs - 0.4), 0.5, nl=10)
    for z in (zs + 4.0, zs + 7.5):
        bam(S, rng, W3(u0, v - 0.1, z), W3(u1, v - 0.1, z), 0.5, nl=10)
    for u in (u0 + 0.04, u1 - 0.04):
        bam(S, rng, W3(u, v - 0.1, zs - 0.5), W3(u, v - 0.1, zs + 8.0), 0.5, nl=4)


def washstand(S, rng):
    """thau rửa tay on a tre stand by the door, a lu nước beside it with a gáo dừa, a khăn on the rail"""
    c = W3(1.9, 1.76, ZH); h = 12.0
    for (dx, dy) in ((-2.4, -2.0), (2.4, -2.0), (-2.4, 2.0), (2.4, 2.0)):
        bam(S, rng, c + np.array([dx, dy, 0]), c + np.array([dx * 0.8, dy * 0.8, h]), 0.45, nl=4)
    lathe(S, c + np.array([0, 0, h]), [(0, 1.8), (0.4, 2.2), (2.0, 3.6), (2.3, 3.8)], M_TIN, na=20)
    disc(S, c + np.array([0, 0, h + 1.6]), (0, 0, 1), 3.2, M_WATER, nr=2, na=18)
    plane(S, c + np.array([-2.6, 2.3, h - 1.0]), np.array([3.4, 0, 0]), np.array([0, 0, -5.5]), 4, 4, M_CLOTHW)
    c = W3(2.16, 1.74, ZH); k_ = 0.8
    lathe(S, c, [(z * k_, r * k_) for z, r in [(0, 3.6), (1.5, 5.2), (5, 6.3), (9, 6.0), (12, 4.4), (13, 3.9), (13.5, 4.1)]], M_GLAZE)
    disc(S, c + np.array([0, 0, 12.0 * k_]), (0, 0, 1), 3.7 * k_, M_WATER, nr=3, na=20)
    g = c + np.array([1.0, 0.0, 13.5 * k_ + 0.3])
    lathe(S, g, [(0, 0.0), (0.4, 1.2), (1.4, 1.7), (1.6, 1.75)], M_COCO, na=16)
    tube(S, g + np.array([1.5, 0, 1.2]), g + np.array([5.0, 2.2, 2.2]), 0.28, M_BAMBOO, nr=4, nl=3)


def inside(S, rng):
    # giường khám: a tre bed with a white sheet, left of the door (deeper things show to the right of the opening)
    zb = ZH + 9.0
    u0, u1, v0, v1 = 1.02, 1.5, 0.86, 1.3                                             # behind the door (shows d to the right)
    for (u, v) in ((u0 + 0.02, v0 + 0.02), (u1 - 0.02, v0 + 0.02), (u0 + 0.02, v1 - 0.02), (u1 - 0.02, v1 - 0.02)):
        bam(S, rng, W3(u, v, ZH), W3(u, v, zb - 0.6), 0.7, nl=4)
    for i in range(12):
        v = v0 + (v1 - v0) * (i + 0.5) / 12
        bam(S, rng, W3(u0, v, zb - 0.5), W3(u1, v, zb - 0.5), 0.6, nl=8)
    plane(S, W3(u0 + 0.02, v0 + 0.02, zb + 0.3), W3(u1 - 0.02, 0, 0) - W3(u0 + 0.02, 0, 0), W3(0, v1 - 0.02, 0) - W3(0, v0 + 0.02, 0), 10, 8, M_CLOTHW)
    ell(S, W3(u0 + 0.08, (v0 + v1) / 2, zb + 1.4), 3.0, 4.6, 1.2, M_CLOTHW, nu=8, nvv=8)          # gối
    # a small table with the đèn dầu, a hộp thuốc
    c = W3(OIL[0], OIL[1], ZH)
    for (dx, dy) in ((-2.6, -2.6), (2.6, -2.6), (-2.6, 2.6), (2.6, 2.6)):
        bam(S, rng, c + np.array([dx, dy, 0]), c + np.array([dx, dy, 12.4]), 0.5, nl=3)
    box(S, c + np.array([-3.2, -3.2, 12.4]), c + np.array([3.2, 3.2, 13.0]), M_PLANK)
    B.oillamp(S, W3(*OIL))
    # tủ thuốc in the right room: tre shelves of brown and white bottles (seen through the right windows)
    v0, v1 = 0.4, 1.0
    for (v, du) in ((v0, 0.0), (v1, 0.0), (v0, 0.16), (v1, 0.16)):
        bam(S, rng, W3(2.5 + du, v, ZH), W3(2.5 + du, v, ZH + 30.0), 0.6, nl=6)
    for z in (ZH + 10.0, ZH + 19.0, ZH + 28.0):
        box(S, W3(2.49, v0, z), W3(2.68, v1, z + 0.7), M_PLANK)
    for zz in (ZH + 10.7, ZH + 19.7):
        for k in range(7):
            v = v0 + 0.05 + k * 0.075
            mt = M_BOTTLE if (k + int(zz)) % 3 else M_BOTTLE2
            lathe(S, W3(2.59, v, zz), [(0, 0.9), (2.4, 1.0), (3.0, 0.5), (3.8, 0.45), (4.0, 0.55)], mt, na=10)
    lathe(S, W3(2.4, 1.32, ZH), [(0, 3.4), (1.5, 4.8), (5, 5.6), (8, 5.2), (10, 3.8), (10.6, 3.6)], M_GLAZE)


def herbs(S, rng):
    """vườn thuốc nam: two raised beds edged with tre: sả clumps, ngải cứu, lá lốt"""
    beds = ((1.86, 2.86, 2.28, 2.52), (1.86, 2.86, 2.62, 2.88))
    for (u0, u1, v0, v1) in beds:
        rrect_top(S, u0, u1, v0, v1, 0.03, ZF + 1.6, M_FLOOR, prm=(0.8, 0, 0))
        extrude(S, rrect(u0, u1, v0, v1, 0.03), ZF - 0.1, ZF + 1.6, M_EARTHSIDE, flare=0.1)
        for v in (v0, v1):
            bam(S, rng, W3(u0, v, ZF + 0.7), W3(u1, v, ZF + 0.7), 0.55, nl=10, mat=M_OLDBAMBOO)
    z = ZF + 1.6
    for k in range(5):                                                                 # sả: tall arching blades
        c = W3(1.96 + k * 0.2, 2.4, z)
        for j in range(20):
            a = j * 2.4 + rng.uniform(-0.2, 0.2); L = rng.uniform(7.0, 11.0); lean = rng.uniform(0.25, 0.5)
            d = nv(np.array([math.cos(a) * lean, math.sin(a) * lean, 1.0]))
            p1 = c + d * L * 0.6; p2 = p1 + nv(np.array([math.cos(a) * 1.2, math.sin(a) * 1.2, 0.2])) * L * 0.5
            tube(S, c, p1, 0.28, M_SA, nr=3, nl=2, taper=0.8); tube(S, p1, p2, 0.22, M_SA, nr=3, nl=2, taper=0.2)
    for k in range(4):                                                                 # ngải cứu: upright stems, grey-green leaves
        c = W3(1.98 + k * 0.17, 2.72, z)
        for j in range(9):
            a = j * 0.9 + rng.uniform(-0.3, 0.3); top = c + np.array([math.cos(a) * 1.6, math.sin(a) * 1.6, rng.uniform(6.0, 9.0)])
            tube(S, c + np.array([math.cos(a) * 0.4, math.sin(a) * 0.4, 0]), top, 0.2, M_NGAI, nr=3, nl=3)
            for t in np.linspace(0.25, 1.0, 5):
                q = c + (top - c) * t; b = a + rng.uniform(-1.2, 1.2)
                d = nv(np.array([math.cos(b), math.sin(b), 0.5]))
                ell(S, q + d * 1.0, 1.3, 0.45, 0.18, M_NGAI, axes=(d, nv(np.cross(UP, d)), nv(np.cross(d, nv(np.cross(UP, d))))), nu=5, nvv=6)
    for k in range(4):                                                                 # lá lốt: a low dense mat of heart leaves
        c = W3(2.6 + (k % 2) * 0.15, 2.68 + (k // 2) * 0.12, z)
        for j in range(22):
            a = rng.uniform(0, 2 * math.pi); r_ = rng.uniform(0.2, 2.2); h = rng.uniform(1.5, 4.5)
            q = c + np.array([math.cos(a) * r_, math.sin(a) * r_, h])
            tube(S, c + np.array([math.cos(a) * r_ * 0.4, math.sin(a) * r_ * 0.4, 0]), q, 0.14, M_LOT, nr=3, nl=2)
            d = nv(np.array([math.cos(a), math.sin(a), 1.4]))
            ell(S, q, 1.25, 1.05, 0.15, M_LOT, axes=(nv(np.cross(UP, d)) if abs(d[2]) < 0.99 else np.array([1.0, 0, 0]), None, None) if False else None, nu=6, nvv=7)


def fence(S, rng):
    """a low hàng rào tre round the vườn thuốc (front and right side), stakes + 2 rails"""
    pts = [(1.82, 2.95), (2.92, 2.95), (2.92, 2.22)]
    for (a, b) in zip(pts[:-1], pts[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1]); n = int(L / 0.09)
        for k in range(n + 1):
            t = k / n; u = a[0] + (b[0] - a[0]) * t; v = a[1] + (b[1] - a[1]) * t
            bam(S, rng, W3(u, v, ZF - 0.5), W3(u, v, ZF + 7.0 + rng.uniform(-0.6, 0.6)), 0.42, nl=3, mat=M_OLDBAMBOO)
        for z in (ZF + 2.6, ZF + 5.6):
            bam(S, rng, W3(a[0], a[1], z), W3(b[0], b[1], z), 0.35, nl=10)


def yardbits(S, rng):
    """a trodden path from the step to the lane, and the cờ chữ thập đỏ on its tre pole"""
    rrect_top(S, 1.3, 1.72, 2.2, 2.94, 0.08, ZF + 0.06, K.M_EARTH if hasattr(K, 'M_EARTH') else M_FLOOR, prm=(0.2, 0, 0))
    c = W3(FLAGP[0], FLAGP[1], ZF); H = FLAG_H                 # Link 2026-11-09: taller pole, the cloth waves (game frames)
    bam(S, rng, c + np.array([0, 0, -1.0]), c + np.array([0, 0, H]), 0.85, nl=24)
    tube(S, c + np.array([0, 0, H]), c + np.array([0, 0, H + 1.4]), 0.9, M_BAMBOO, nr=6, nl=2)
    ell(S, c + np.array([0, 0, 0.6]), 3.0, 2.8, 1.4, K.M_MOUND, nu=8, nvv=10)
    tube(S, c + np.array([0.95, 0, 6.0]), c + np.array([0.85, 0, H - 1.0]), 0.13, M_RATTAN, nr=4, nl=10)   # the halyard
    if FLAG['mode'] == 'static': flagcloth(S, FLAG['ph'])


# ---------------------------------------------------------------- the waving flag (frames for the game: tramytco.webp)
FLAG_H = 94.0
FLAG = {'mode': 'none', 'ph': 0.0}
FLAG_N = 12
FLAG_L, FLAG_FH = 19.0, 13.0


def flagtop():
    return W3(FLAGP[0], FLAGP[1], ZF) + np.array([0, 0, FLAG_H])


def flagcloth(S, ph):
    top = flagtop()
    def F(U, V):
        a = U ** 0.85
        w = 4.6 * U - ph + 0.5 * V
        x = U * FLAG_L * (1 - 0.05 * (1 - np.cos(w)) * a)
        y = 3.0 * a * np.sin(w) + 0.8 * a * np.sin(2 * w + 0.7) - 0.6 * U
        z = -V * FLAG_FH - 1.2 * U + 0.8 * a * np.sin(w * 0.8 + 1.3)
        return top[None, None] + np.stack([0.9 + x, y, z], -1)
    S.grid(F, 36, 20, M_FLAGX, (0, 0, 0), 0.0)


def flagbox():
    top = flagtop(); pts = []
    for dx in (0.0, FLAG_L + 2.0):
        for dy in (-4.0, 4.0):
            for dz in (2.0, -FLAG_FH - 6.0):
                p = top + np.array([dx, dy, dz]); pts.append(((p[0] - p[1]) * 32 / T + K.OX, (p[0] + p[1]) * 16 / T + K.OY - p[2]))
    xs = [q[0] for q in pts]; ys = [q[1] for q in pts]
    return (math.floor(min(xs)) - 2, math.floor(min(ys)) - 2, math.ceil(max(xs)) + 2, math.ceil(max(ys)) + 2)


def banner(S, rng):
    """a red-cross board hung from the hiên beam by two mây cords"""
    u0, u1, v, z0, z1 = BANNER
    box(S, W3(u0, v - 0.015, z0), W3(u1, v + 0.015, z1), M_BANX)
    for u in (u0 + 0.05, u1 - 0.05):
        tube(S, W3(u, v, z1), W3(u, PV, EZ - 2.2), 0.2, M_RATTAN, nr=4, nl=2)


def sign(S, rng):
    u0, u1, v0, v1, z0, z1 = SIGN
    for u in (u0 + 0.06, u1 - 0.06):
        bam(S, rng, W3(u, (v0 + v1) / 2 - 0.04, ZF - 1.0), W3(u, (v0 + v1) / 2 - 0.04, z1 + 1.5), 0.85, nl=8)
    box(S, W3(u0, v0, z0), W3(u1, v1, z1), M_SIGNW)
    for (a, b) in ((W3(u0, v1 + 0.004, z0), W3(u1, v1 + 0.004, z0)), (W3(u0, v1 + 0.004, z1), W3(u1, v1 + 0.004, z1)),
                   (W3(u0, v1 + 0.004, z0), W3(u0, v1 + 0.004, z1)), (W3(u1, v1 + 0.004, z0), W3(u1, v1 + 0.004, z1))):
        tube(S, a, b, 0.55, M_SIGNF, nr=6, nl=4)


def lamp_bits(S, rng):
    c = W3(*LAMP)
    tube(S, W3(LAMP[0], PV, EZ - 2.4), c + np.array([0, 0, 4.4]), 0.16, M_SOOT, nr=4, nl=2)
    B.biglamp(S, c)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear()
    if FLAG['mode'] == 'only':
        K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
        flagcloth(S, FLAG['ph'])
        return S, (S.ns, S.ns)
    K.LIGHTS2.append((W3(*LAMP), hexc('#ff9645'), 15.0, 2.8, 'all'))
    K.LIGHTS2.append((W3(*OIL), hexc('#ff9645'), 16.0, 1.6, 'in'))
    for (p, k) in (((1.3, 1.1, ZH + 24.0), 1.5), ((2.2, 0.8, ZH + 24.0), 1.6), ((2.4, 1.3, ZH + 24.0), 1.4)):
        K.LIGHTS2.append((W3(*p), hexc('#ff9645'), 13.0, k, 'in'))
    for p in ((2.92, 0.7, ZH + 16.0), (0.75, 1.9, ZH + 12.0), (1.51, 1.95, ZH + 8.0)):
        K.LIGHTS2.append((W3(*p), hexc('#ff9645'), 9.0, 0.9, 'out'))
    K.GLOWS[:] = [(W3(*LAMP), 0.2, 0.85), (W3(*OIL), 0.06, 0.6)]
    platform(S, rng)
    walls(S, rng)
    B.roof(S, rng)
    columns(S, rng)
    bench(S, rng, 0.46, 1.2, 1.74)
    washstand(S, rng)
    inside(S, rng)
    herbs(S, rng)
    fence(S, rng)
    yardbits(S, rng)
    # banner(S, rng): the eave hid half of it and it covered the window; the flag + end-wall cross carry the sign
    sign(S, rng)
    lamp_bits(S, rng)
    return S, (S.ns, S.ns)


K.build = build


def render(n):
    return K.render(1, n, 'b')


if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        n = len(sys.argv) > 3 and sys.argv[3] == 'n'
        FLAG['mode'] = 'static' if 'f' in sys.argv[4:] else 'none'
        render(n).save(sys.argv[2])
    elif sys.argv[1] == 'flag':                     # python3 tramyt3d.py flag OUTDIR: tramytco.webp + tramytco.json
        out = sys.argv[2]; FLAG['mode'] = 'only'
        K.BB = flagbox(); K.FOOT = (-60.0, -59.9, -60.0, -59.9, 0.01)
        ims = {}
        for n in (0, 1):
            for k in range(FLAG_N):
                FLAG['ph'] = 2 * math.pi * k / FLAG_N
                ims[(n, k)] = render(bool(n))
        W_, H_ = ims[(0, 0)].size
        sheet = Image.new('RGBA', (W_ * FLAG_N, H_ * 2), (0, 0, 0, 0))
        for (n, k), im in ims.items():
            sheet.paste(im, (k * W_, n * H_))
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, 'tramytco.webp'), 'WEBP', quality=92, method=6)
        sc = float(K.PXU); bx = K.BB
        json.dump({'n': FLAG_N, 'w': W_, 'h': H_, 'box': [bx[0], bx[1], round(W_ / sc, 3), round(H_ / sc, 3)]}, open(os.path.join(out, 'tramytco.json'), 'w'))
        print('flag sheet', sheet.size, K.BB)
    elif sys.argv[1] == 'atlas':
        out, tab = sys.argv[2], sys.argv[3]
        frames = {}
        for n in (0, 1):
            im = render(bool(n)); bb = im.getbbox(); frames['b' + ('n' if n else 'd')] = (im.crop(bb), bb)
        keys = ['bd', 'bn']
        x = 0; Gt = {}; sc = float(K.PXU); H = max(f[0].height for f in frames.values()); BB = K.BB
        sheet = Image.new('RGBA', (sum(frames[k][0].width + 2 for k in keys), H), (0, 0, 0, 0))
        for k in keys:
            im, bb = frames[k]; sheet.paste(im, (x, 0))
            Gt[k] = [x, 0, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
            x += im.width + 2
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, K.SHEET), 'WEBP', quality=92, method=6); json.dump(Gt, open(tab, 'w'))
        print('sheet', sheet.size)
