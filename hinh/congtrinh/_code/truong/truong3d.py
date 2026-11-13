# Nông Trại Chung: Trường làng cấp 1 (game id truong 4x4, mirror truong2) as a real 3D model (kho kit + nhà ba gian walls).
# Link 2026-11-09 06:49 "check tiếp trường học"; sơ cấp = tre, gỗ tràm, lá, simple (Link 03:58). Cấp 2 (truong_l2) stays old.
# A one-room trường làng miền Tây, readable at a glance (not a copy of the old L-shaped canvas one):
#  - a long nhà lá with a GABLE roof (not the hip roof of the nhà ba gian / trạm y tế), vách lá, big song tre windows
#  - a hiên on 3 tràm columns; the TRƯỜNG LÀNG board stands on the eave (the game paints the words)
#  - a bảng đen on the front wall with chalk writing; the trống trường hung under the hiên with its dùi
#  - inside: rows of bàn ghế tre with vở on them, seen through the windows; a đèn dầu for the lớp học đêm
#  - the sân: cột cờ tre in front (the game waves the đình's cờ đỏ sao vàng frames on it), a lò cò and an ô ăn quan
#    scratched in the dirt with sỏi, a bed of bông mười giờ, a lu nước uống with a gáo; a low hàng rào tre with a gap
#   python3 truong3d.py prev OUT.png [n]        python3 truong3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'bagian'))
import bagian3d as B
from bagian3d import (K, SP, W3, T, nv, UP, Scene, hexc, vnoise, plane, tube, disc, lathe, extrude, rrect, rrect_top, box, obox,
                      mat_flat, MATS, M_EARTHSIDE, M_BAMBOO, M_WEAVE_F, M_GLAZE, M_LID, M_PLANK, M_RATTAN, M_OLDBAMBOO,
                      M_FLOOR, M_WOOD, M_BARK, M_SOOT, M_COCO, M_WATER, M_CHIEU, M_STONE, M_TIN, bam, ell)

K.BB = (-134, -152, 134, 72)
K.OX, K.OY = 0, -64                           # at.P(4,4)
ZF, ZH = 2.4, 6.4
U0, U1, V0, V1 = 0.35, 3.25, 0.35, 1.6        # the classroom walls
ZW = 56.0
PV = 2.0                                      # hiên columns
CU = (0.45, 1.85, 3.15)
EU0, EU1, EV, EZ = 0.22, 3.38, 2.18, 48.0     # gable roof: eaves along u, the gables overhang the end walls
RV, RZ = 1.17, 80.0                           # lower ridge (critique 1: the roof swamped the picture)
BV = 2 * RV - EV
RA, RB = EU0, EU1
DOOR = (2.44, 2.84); DZ = ZH + 27.0
FWIN = ((0.86, 1.38),); RWIN = ((0.4, 1.0),); WZ = (ZH + 5.5, ZH + 24.0)
BOARD = (1.76, 2.26, ZH + 9.0, ZH + 22.5)     # bảng đen on the front wall (u0, u1, z0, z1)
SIGN = (1.05, 2.55, EV + 0.04, EZ + 3.0, EZ + 15.0)   # TRƯỜNG LÀNG board on the eave (u0, u1, v, z0, z1)
DRUM = (1.24, 2.74, ZF + 13.0)                # trống trường on a tre giá in the sân, beside the cột cờ (Link 07:33)
LAMP = (1.56, 1.94, 38.0)                      # đèn bão under the hiên
OIL = (2.45, 0.6, ZH + 12.4 + 4.2)            # đèn dầu on the teacher's table (lớp học đêm)
FLAG = (0.95, 3.12); FLAG_H = 100.0           # cột cờ: the game draws the waving cloth at its top
PATHU = (2.44, 2.84)                          # the trodden path from the gate gap to the door

for k_, v_ in dict(ZF=ZF, ZH=ZH, U0=U0, U1=U1, V0=V0, V1=V1, ZW=ZW, PV=PV, EU0=EU0, EU1=EU1, BV=BV, EV=EV, EZ=EZ,
                   RA=RA, RB=RB, RV=RV, RZ=RZ, DZ=DZ, WZ=WZ).items():
    setattr(B, k_, v_)
K.ZW, K.ZF = ZW, ZF
K.RZ, K.EZ = RZ, EZ
K.WU0, K.WU1, K.WV0, K.WV1 = U0, U1, V0, V1
K.INSIDE_K = 0.3                             # Link 14:07: every building lit like the đình (was                         # brighter classroom: the bàn ghế read through the windows)
K.FOOT = (0.06, 3.94, 0.06, 3.94, 0.08)
K.GROUND_SHADOW = False
K.SHEET = 'truong.webp'
K.SEED = 7400
K.RIDGE_R, K.BATTEN_R, K.POLE_R, K.TIE_R = 2.4, 0.55, 0.42, 0.24
K.NIGHT_EMIT = {}

M_BB, M_SIGNB, M_DRUM, M_SKIN, M_YARD, M_MUOI, M_MUOIL, M_BOOK, M_BOOK2, M_PEBBLE, M_VACHG = range(270, 281)
M_CAP, M_DEP, M_SOAP, M_KHAN2, M_LEAFD = range(281, 286)
M_BANG, M_BANGR, M_BARKB, M_GRASS, M_UNDER, M_WATERG = range(286, 292)
K.NOSHADOW = {M_BANG, M_BANGR, M_BARKB, M_GRASS}   # no baked shadow under the tree / grass (sun shadows come later)
TREE = (0.5, 3.45)                           # cây bàng in the front-right corner of the sân (critique 8)
LOCO = (1.55, 1.89)                           # lò cò (u0, u1), moved right of the drum
WASH = (3.66, 1.42, 1.84)                     # chỗ rửa tay (u, v0, v1) by the right wall (replaces the lu, Link)


def mat_bb(uv, prm, pos, nrm):
    """bảng đen: old black paint gone grey-green, chalk lines (a b c, 1 + 1 = 2 written as strokes), chalk dust smudges"""
    x, z = pos[:, 0], pos[:, 2]
    u0, u1, z0, z1 = BOARD
    a = (x - u0 * T) / ((u1 - u0) * T); b = (z - z0) / (z1 - z0)
    base = hexc('#2c3a33')[None] * (0.9 + 0.1 * vnoise(x * 0.2, z * 0.2, 5.0))[:, None]
    dust = np.clip(vnoise(x * 0.12, z * 0.25, 9.0) - 0.45, 0, 1) * 0.5
    base = base * (1 - dust[:, None]) + hexc('#7c8a82')[None] * dust[:, None]
    M = _chalk()
    xi = np.clip((a * M.shape[1]).astype(int), 0, M.shape[1] - 1); yi = np.clip(((1 - b) * M.shape[0]).astype(int), 0, M.shape[0] - 1)
    ch = M[yi, xi] * (0.75 + 0.25 * vnoise(x * 3.0, z * 3.0, 4.0))
    base = base * (1 - 0.85 * ch[:, None]) + hexc('#e8e6dc')[None] * 0.85 * ch[:, None]
    frame = (a < 0.03) | (a > 0.97) | (b < 0.05) | (b > 0.95)
    base = np.where(frame[:, None], hexc('#6b4a2c')[None], base)
    return np.clip(base, 0, 1), nrm


_CH = []


def _chalk():
    """chalk writing on the bảng đen: a date line, a b c, a sum (critique 3: real letters, not a repeated squiggle)"""
    if _CH: return _CH[0]
    from PIL import ImageDraw, ImageFont
    W_, H_ = 360, 260
    im = Image.new('L', (W_, H_), 0); d = ImageDraw.Draw(im)
    f1 = ImageFont.truetype('/usr/share/fonts/truetype/freefont/FreeSansOblique.ttf', 54)
    f2 = ImageFont.truetype('/usr/share/fonts/truetype/freefont/FreeSansOblique.ttf', 62)
    # the readable words are drawn by the game (P5) so the mirrored truong2 does not read backwards;
    # here only the half-erased ghost of yesterday's lesson + the underline under the title
    d.text((30, 20), "Bài 4", font=f1, fill=70)
    d.text((200, 150), "5 - 2", font=f2, fill=55)
    d.line((20, 84, 200, 80), fill=200, width=4)
    from PIL import ImageFilter
    im = im.filter(ImageFilter.GaussianBlur(5)); d = ImageDraw.Draw(im)
    d.line((20, 84, 200, 80), fill=200, width=4)
    _CH.append(np.asarray(im, float) / 255.0)
    return _CH[0]


def mat_signb(uv, prm, pos, nrm):
    """the name board: 3 tràm planks, painted dark blue long ago, the paint worn at the edges (the game paints the words)"""
    x, z = pos[:, 0], pos[:, 2]
    u0, u1, v, z0, z1 = SIGN
    b = (z - z0) / (z1 - z0)
    seam = (np.abs(b - 1 / 3) < 0.02) | (np.abs(b - 2 / 3) < 0.02)
    a = (x - u0 * T) / ((u1 - u0) * T)
    g = vnoise(x * 0.25, z * 3.0, 3.0)
    base = hexc('#34495a')[None] * (0.82 + 0.18 * g)[:, None]                          # sơn xanh đen cũ, bạc màu
    grain = 0.5 + 0.5 * np.sin(x * 1.7 + 3.0 * vnoise(x * 0.1, z * 0.8, 5.0))
    base = base * (0.94 + 0.06 * grain)[:, None]
    edge = np.clip(1 - np.minimum(np.minimum(a, 1 - a) * 14, np.minimum(b, 1 - b) * 5), 0, 1)
    worn = np.clip((vnoise(x * 0.35, z * 0.9, 7.0) - 0.62) * 3 + edge * 0.8, 0, 1) * 0.7
    base = base * (1 - worn[:, None]) + hexc('#6e5a40')[None] * worn[:, None]          # the tràm wood shows through
    line = (np.abs(np.minimum(a, 1 - a) - 0.025) < 0.006) | (np.abs(np.minimum(b, 1 - b) - 0.09) < 0.02)
    base = np.where(line[:, None], hexc('#cfc4a2')[None] * 0.92, base)
    base = np.where(seam[:, None], base * 0.6, base)
    return np.clip(base, 0, 1), nrm


def mat_drum(uv, prm, pos, nrm):
    """trống thân gỗ mít ghép mảnh (staves), sơn son đã bạc: the staves' seams, wood showing where hands rub"""
    c = W3(*DRUM); x = pos[:, 0] - c[0]
    ang = np.arctan2(pos[:, 2] - c[2], pos[:, 1] - c[1])
    st = (ang / (2 * math.pi) * 16) % 1.0
    seam = (np.minimum(st, 1 - st) < 0.05).astype(float)
    sid = np.floor(ang / (2 * math.pi) * 16)
    col = hexc('#7c2e20')[None] * (0.84 + 0.1 * np.sin(sid * 2.3)[:, None] + 0.08 * vnoise(x * 0.4, ang * 3, 4.0)[:, None])
    worn = np.clip((vnoise(x * 0.5, ang * 2.5, 9.0) - 0.5) * 3, 0, 1) * 0.8 + np.clip(np.abs(x) / 4.75 - 0.86, 0, 1) * 3
    col = col * (1 - np.clip(worn, 0, 1)[:, None]) + hexc('#7a5434')[None] * np.clip(worn, 0, 1)[:, None]
    col = col * (1 - 0.45 * seam[:, None])
    return np.clip(col, 0, 1), nrm


def mat_skin(uv, prm, pos, nrm):
    r = np.hypot(pos[:, 1] - DRUM[1] * T, pos[:, 2] - DRUM[2])
    m = vnoise(pos[:, 1] * 0.9, pos[:, 2] * 0.9, 2.0); m2 = vnoise(pos[:, 1] * 2.4, pos[:, 2] * 2.4, 6.0)
    col = hexc('#cdb58a')[None] * (0.82 + 0.12 * m + 0.06 * m2)[:, None]               # da trâu, mottled
    col = col * (1 - 0.3 * np.clip(1 - r / 2.4, 0, 1))[:, None]                       # the beaten middle, darker
    col = col * (1 - 0.35 * np.clip((r - 3.6) / 1.2, 0, 1))[:, None]                 # darker rim where the hide folds
    return np.clip(col, 0, 1), nrm


def mat_yard(uv, prm, pos, nrm):
    """sân đất nện, with a lò cò and an ô ăn quan scratched into it and the bare trodden path"""
    col, n = MATS[M_FLOOR](uv, prm, pos, nrm)
    u, v = pos[:, 0] / T, pos[:, 1] / T
    line = np.zeros_like(u)
    uw = u + 0.012 * (vnoise(u * 6, v * 6, 21.0) - 0.5); vw = v + 0.012 * (vnoise(u * 6, v * 6, 23.0) - 0.5)
    brk = np.clip((vnoise(u * 14, v * 14, 27.0) - 0.18) * 4, 0.35, 1)                # scuffed: lines half rubbed out
    def seg(u0, v0, u1, v1, w=0.014):
        du, dv = u1 - u0, v1 - v0; L2 = du * du + dv * dv
        t = np.clip(((uw - u0) * du + (vw - v0) * dv) / L2, 0, 1)
        d = np.hypot(uw - u0 - t * du, vw - v0 - t * dv)
        return np.clip((w - d) / 0.006, 0, 1) * brk
    # lò cò: a ladder of squares along v, a pair of side-by-side squares in the middle, a half-round "trời" at the end
    lu0, lu1 = LOCO
    vs = [2.62, 2.84, 3.06, 3.28, 3.5, 3.72]
    for vv in vs: line = np.maximum(line, seg(lu0, vv, lu1, vv))
    line = np.maximum(line, seg(lu0, vs[0], lu0, vs[-1])); line = np.maximum(line, seg(lu1, vs[0], lu1, vs[-1]))
    line = np.maximum(line, seg((lu0 + lu1) / 2, vs[2], (lu0 + lu1) / 2, vs[3]))
    r = np.hypot((uw - (lu0 + lu1) / 2) / 0.17, (vw - vs[0]) / 0.14)
    line = np.maximum(line, ((np.abs(r - 1) < 0.07) & (v < vs[0])).astype(float) * brk)
    # ô ăn quan: 2 x 5 squares, a half-round quan at each end
    qu0, qu1, qv0, qv1 = 3.0, 3.58, 2.72, 2.98
    for k in range(6):
        uu = qu0 + (qu1 - qu0) * k / 5; line = np.maximum(line, seg(uu, qv0, uu, qv1))
    for vv in (qv0, (qv0 + qv1) / 2, qv1): line = np.maximum(line, seg(qu0, vv, qu1, vv))
    for (cu, sg) in ((qu0, -1), (qu1, 1)):
        r = np.hypot((uw - cu) / 0.13, (vw - (qv0 + qv1) / 2) / 0.13)
        line = np.maximum(line, ((np.abs(r - 1) < 0.08) & ((u - cu) * sg > 0)).astype(float) * brk)
    col = col * (1 - 0.5 * line[:, None]) + hexc('#6a4c2e')[None] * 0.34 * line[:, None]
    # big soft patches: dustier pale ground and darker packed ground (critique 5: not one flat colour)
    big = vnoise(u * 1.6, v * 1.6, 31.0); mid = vnoise(u * 4.5, v * 4.5, 33.0)
    col = col * (0.93 + 0.1 * big + 0.04 * mid)[:, None]
    # trodden spots: round the cột cờ + trống, under the bench, the path; a damp dark patch under the chỗ rửa tay
    def spot(cu, cv, ru, rv):
        return np.clip(1 - np.hypot((u - cu) / ru, (v - cv) / rv), 0, 1) ** 0.8
    tr = np.maximum.reduce([spot(FLAG[0], FLAG[1], 0.34, 0.34), spot(DRUM[0] + 0.1, DRUM[1] + 0.18, 0.4, 0.3),
                            spot(3.38, 3.6, 0.45, 0.25), spot(2.64, 2.6, 0.3, 0.5)])
    col = col * (1 - 0.12 * tr[:, None]) + hexc('#a8835a')[None] * 0.12 * tr[:, None]
    wet = spot(WASH[0] - 0.12, (WASH[1] + WASH[2]) / 2, 0.22, 0.4) * (0.6 + 0.4 * vnoise(u * 8, v * 8, 35.0))
    col = col * (1 - 0.35 * wet[:, None])
    # the path: smoother, a touch paler, worn edges
    pa = np.clip(np.minimum(u - PATHU[0], PATHU[1] - u) / 0.06, 0, 1) * (v > 2.05)
    pa = pa * (0.7 + 0.3 * vnoise(u * 9, v * 9, 3.0))
    col = col * (1 + 0.08 * pa[:, None])
    return np.clip(col, 0, 1), n


_leaf0, _ridge0 = MATS[K.M_LEAF], MATS[K.M_RIDGE]


def mat_leaf_s(uv, prm, pos, nrm):
    """lá dừa nước a couple of years old: the kho leaf, a little greyer and browner (not the trạm's older roof)"""
    col, n = _leaf0(uv, prm, pos, nrm)
    w = vnoise(pos[:, 0] * 0.045, pos[:, 1] * 0.045 + pos[:, 2] * 0.04, 41.0)
    w2 = vnoise(pos[:, 0] * 0.15, pos[:, 1] * 0.15 + pos[:, 2] * 0.12, 43.0)
    old = np.clip((w - 0.42) * 2.6, 0, 1)[:, None]
    c = col * 0.56 + hexc('#7e6e50')[None] * 0.3                                       # sun-bleached, greyer: lá dừa nước cũ
    c = c * (0.86 + 0.2 * w2[:, None])
    c = c * (1 - 0.3 * old) + hexc('#6a5e46')[None] * 0.24 * old
    pn = vnoise(pos[:, 0] * 0.022, pos[:, 1] * 0.03 + pos[:, 2] * 0.03, 47.0)
    newp = np.clip((pn - 0.62) * 5, 0, 1)[:, None]                                    # a re-thatched patch: fresher leaf
    darkp = np.clip((0.3 - pn) * 5, 0, 1)[:, None]                                    # an old wet patch
    c = c * (1 - 0.45 * newp) + hexc('#b89c5c')[None] * 0.45 * newp
    c = c * (1 - 0.22 * darkp)
    return np.clip(c, 0, 1), n


def mat_ridge_s(uv, prm, pos, nrm):
    col, n = _ridge0(uv, prm, pos, nrm)
    return np.clip(col * 0.6 + hexc('#72644a')[None] * 0.26, 0, 1), n


MATS.update({K.M_LEAF: mat_leaf_s, K.M_RIDGE: mat_ridge_s})
MATS.update({M_CAP: mat_flat('#3e6e8a'), M_DEP: mat_flat('#c8453a'), M_SOAP: mat_flat('#e8d48a'), M_KHAN2: mat_flat('#e8e2d2'),
             M_LEAFD: mat_flat('#8a6a3a')})
def mat_bang(uv, prm, pos, nrm):
    n1 = vnoise(pos[:, 0] * 0.5, pos[:, 1] * 0.5 + pos[:, 2] * 0.3, 61.0); n2 = vnoise(pos[:, 0] * 0.08, pos[:, 1] * 0.08, 62.0)
    col = hexc('#4c7a2e')[None] * (0.78 + 0.3 * n1 + 0.12 * n2)[:, None]
    col = col * (1 - 0.25 * n2[:, None]) + hexc('#7a9a34')[None] * 0.25 * n2[:, None]
    return np.clip(col, 0, 1), nrm


def mat_bangr(uv, prm, pos, nrm):
    n1 = vnoise(pos[:, 0] * 0.6, pos[:, 1] * 0.6, 63.0)
    return np.clip(hexc('#b4542c')[None] * (0.85 + 0.25 * n1)[:, None], 0, 1), nrm


def mat_barkb(uv, prm, pos, nrm):
    n1 = vnoise(pos[:, 0] * 0.3, pos[:, 2] * 0.9, 64.0); n2 = vnoise(pos[:, 1] * 1.4, pos[:, 2] * 0.2, 65.0)
    col = hexc('#7d7466')[None] * (0.8 + 0.25 * n1 - 0.12 * (n2 > 0.6))[:, None]
    return np.clip(col, 0, 1), nrm


def mat_under(uv, prm, pos, nrm):
    """the underside of the lá dừa nước thatch: leaf ribs running down the slope, darker in the gaps"""
    x = pos[:, 0]
    r = 0.5 + 0.5 * np.sin(x * 2.6 + 3.0 * vnoise(x * 0.3, pos[:, 2] * 0.4, 66.0))
    n = vnoise(x * 0.15, pos[:, 1] * 0.2 + pos[:, 2] * 0.2, 67.0)
    col = hexc('#8a7650')[None] * (0.62 + 0.28 * r + 0.15 * n)[:, None]
    return np.clip(col, 0, 1), nrm


MATS.update({M_BANG: mat_bang, M_BANGR: mat_bangr, M_BARKB: mat_barkb, M_GRASS: mat_flat('#6e9a3a'), M_UNDER: mat_under,
             M_WATERG: mat_flat('#93a7a0')})
MATS.update({M_BB: mat_bb, M_SIGNB: mat_signb, M_DRUM: mat_drum, M_SKIN: mat_skin, M_YARD: mat_yard,
             M_MUOI: mat_flat('#e0306a'), M_MUOIL: mat_flat('#5d8a34'), M_BOOK: mat_flat('#ece6d4'), M_BOOK2: mat_flat('#5a86b8'),
             M_PEBBLE: mat_flat('#d8d0c0'), M_VACHG: MATS[B.M_VACH]})


# ---------------------------------------------------------------- house
def zgable(v):
    return RZ - 2.6 - np.abs(v - RV) * (RZ - EZ) / (EV - RV)


def gable(S, u, sgn):
    """the vách lá triangle above the wall plate, cut to the roof"""
    def F(U, V):
        v = U / T; zt = zgable(v)
        return np.stack([np.full_like(U, u * T + sgn * 0.3), U, ZW - 0.5 + V * (np.maximum(zt, ZW) - ZW + 0.5)], -1)
    S.grid(F, 60, 16, B.M_VACH, (0, 0, 0), 0.0, uvr=((V0 * T, V1 * T), (0, 1)))


def walls(S, rng):
    e = 0.004
    holes = [(DOOR[0], DOOR[1], ZH, DZ)] + [(a, b, WZ[0], WZ[1]) for (a, b) in FWIN]
    B.holed(S, U0, U1, holes, lambda a, b, z0, z1: B.wall_u(S, a, b, z0, z1, V1))
    B.wall_u(S, U0, U1, ZH, ZW, V0)
    B.holed(S, V0, V1, [(a, b, WZ[0], WZ[1]) for (a, b) in RWIN], lambda a, b, z0, z1: B.wall_v(S, a, b, z0, z1, U1))
    B.wall_v(S, V0, V1, ZH, ZW, U0)
    gable(S, U1, 1); gable(S, U0, -1)
    for (u, v) in ((U0, V0), (U0, V1), (U1, V0), (U1, V1)):
        bam(S, rng, W3(u, v, ZH - 0.5), W3(u, v, ZW + 1.0), 1.3, nl=12, mat=M_OLDBAMBOO)
    bam(S, rng, W3(U1, RV, ZH - 0.5), W3(U1, RV, RZ - 3.0), 1.2, nl=16, mat=M_OLDBAMBOO)          # the gable's king post
    for v in (V0, V1):
        bam(S, rng, W3(U0 - 0.05, v, ZW), W3(U1 + 0.05, v, ZW), 1.25, nl=24, mat=M_OLDBAMBOO)
    for u in (U0, U1):
        bam(S, rng, W3(u + 0.01, V0 - 0.05, ZW - 0.9), W3(u + 0.01, V1 + 0.05, ZW - 0.9), 1.15, nl=14, mat=M_OLDBAMBOO)
    for z in (ZH + 2.0,):                                                               # a nẹp tre along the foot
        for (a, b) in ((U0, DOOR[0]), (DOOR[1], U1)):
            bam(S, rng, W3(a, V1 + e * 3, z), W3(b, V1 + e * 3, z), 0.55, nl=12, mat=M_OLDBAMBOO)
        bam(S, rng, W3(U1 + e * 3, V0, z), W3(U1 + e * 3, V1, z), 0.55, nl=12, mat=M_OLDBAMBOO)
    # door: frame, lintel, ngạch, one phên leaf swung in
    d0, d1 = DOOR
    for u in (d0, d1):
        bam(S, rng, W3(u, V1 + e, ZH), W3(u, V1 + e, DZ + 0.6), 0.85, nl=6)
    bam(S, rng, W3(d0 - 0.03, V1 + e, DZ), W3(d1 + 0.03, V1 + e, DZ), 0.85, nl=6)
    box(S, W3(d0 - 0.02, V1 - 0.03, ZH), W3(d1 + 0.02, V1 + 0.03, ZH + 0.9), M_WOOD, prm=(0.4, 0, 0))
    w = (d1 - d0) * T * 0.95; ang = math.radians(152)
    A = np.array([w * math.cos(ang), -w * math.sin(ang), 0.0]); o = W3(d0, V1 - 0.02, ZH + 1.0)
    obox(S, o, A, np.array([0, 0, DZ - ZH - 1.8]), np.array([0, 0.4, 0]), M_WEAVE_F)
    for f in (0.0, 1.0):
        tube(S, o + A * f, o + A * f + np.array([0, 0, DZ - ZH - 1.8]), 0.45, M_BAMBOO, prm=(0.2, 0.3, 0), nr=6, nl=4)
    for (a, b) in FWIN:
        B.window(S, rng, a, b, WZ[0], WZ[1], 'u')
    for (a, b) in RWIN:                                                                 # wide, only 3 song tre (critique 4)
        P_ = lambda t, z: W3(U1 + 0.006, t, z)
        for (p, q) in ((P_(a, WZ[0]), P_(b, WZ[0])), (P_(a, WZ[1]), P_(b, WZ[1])), (P_(a, WZ[0] - 0.6), P_(a, WZ[1] + 0.6)),
                       (P_(b, WZ[0] - 0.6), P_(b, WZ[1] + 0.6))):
            tube(S, p, q, 0.75, M_BAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=4)
        for k in range(1, 4):
            t = a + (b - a) * k / 4
            tube(S, P_(t, WZ[0]), P_(t, WZ[1]), 0.42, M_BAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=3)
        obox(S, W3(U1 + 0.004, a - 0.02, WZ[0] - 0.9), W3(0, b - a + 0.04, 0), np.array([1.6, 0, 0]), np.array([0, 0, 0.8]), M_PLANK)
    # the gable: a triangular lỗ thông gió under the ridge with song tre, two nẹp tre braces (critique 11)
    gu = U1 + 0.012; zt = float(zgable(RV)); zb = ZW + 3.0
    vent = [(RV - 0.26, zb + 6.0), (RV + 0.26, zb + 6.0), (RV, zt - 3.0)]
    plane(S, W3(gu - 0.004, RV - 0.22, zb + 6.5), W3(0, 0.44, 0), np.array([0, 0, 1.0]), 2, 2, M_SOOT)
    def Fv(U, V):
        vv = RV + (U - 0.5) * 0.5 * (1 - V); zz = zb + 6.3 + V * (zt - 3.4 - zb - 6.3)
        return np.stack([np.full_like(U, gu * T - 0.05), vv * T, zz], -1)
    S.grid(Fv, 6, 6, K.M_DARK, (0, 0, 0), 0.0)
    for (p0, p1) in zip(vent, vent[1:] + vent[:1]):
        tube(S, W3(gu, p0[0], p0[1]), W3(gu, p1[0], p1[1]), 0.55, M_BAMBOO, prm=(rng.random(), 0.3, 0), nr=6, nl=4)
    for k in (-2, -1, 1, 2):
        vv = RV + k * 0.07; ztop = zb + 6.0 + (zt - 3.0 - zb - 6.0) * (1 - abs(vv - RV) / 0.26)
        tube(S, W3(gu, vv, zb + 6.0), W3(gu, vv, ztop), 0.32, M_BAMBOO, prm=(rng.random(), 0.3, 0), nr=5, nl=3)
    for (v_a, v_b) in ((V0 + 0.05, RV - 0.3), (V1 - 0.05, RV + 0.3)):
        tube(S, W3(gu, v_a, ZW + 0.5), W3(gu, v_b, float(zgable(v_b)) - 3.0), 0.5, M_OLDBAMBOO, prm=(rng.random(), 0.3, 0), nr=6, nl=6)
    bam(S, rng, W3(gu, V0 - 0.02, zb), W3(gu, V1 + 0.02, zb), 0.5, nl=12, mat=M_OLDBAMBOO)
    # bảng đen on the front wall, in a tre frame, a chalk ledge under it
    u0, u1, z0, z1 = BOARD
    plane(S, W3(u0, V1 + 0.02, z0), W3(u1, 0, 0) - W3(u0, 0, 0), np.array([0, 0, z1 - z0]), 24, 14, M_BB)
    box(S, W3(u0 + 0.02, V1 + 0.02, z0 - 0.9), W3(u1 - 0.02, V1 + 0.09, z0 - 0.1), M_PLANK)
    for k in range(3):                                                                  # chalk sticks + a rag on the ledge
        c = W3(u0 + 0.12 + k * 0.05, V1 + 0.055, z0 - 0.05)
        tube(S, c, c + np.array([1.4, 0.2, 0.15]), 0.22, M_BOOK, nr=4, nl=2)
    ell(S, W3(u1 - 0.14, V1 + 0.055, z0 + 0.3), 1.6, 0.9, 0.5, M_CHIEU, nu=6, nvv=8)


def groof(S, rng):
    X = np.array([1.0, 0, 0]); Lu = (EU1 - EU0) * T
    fr = None
    for ev in (EV, BV):
        e = W3(EU0, ev, EZ); su, n, LB = B.face(e, W3(EU0, RV, RZ), X)
        B.tslope(S, rng, e, su, n, LB, X, Lu, 0.0, 0.0)
        for x in (0.0, Lu):                                                            # the thatch edge at the gables
            plane(S, e + X * x - n * 2.4, su * (LB - 0.6), n * 4.0, 10, 3, K.M_THEND)
        if ev == EV: fr = (e, su, n, LB)
        else: bk = (e, su, n, LB)
    eb, sub, nb, LBb = bk
    plane(S, eb - nb * 2.65, X * Lu, sub * LBb, 30, 10, M_UNDER)                       # the thatch underside, not a flat slab
    for x in np.arange(1.5, Lu, 6.0):                                                  # tre rafters under it
        tube(S, eb + X * x - nb * 3.3, eb + X * x + sub * (LBb - 2.0) - nb * 3.3, 0.5, M_OLDBAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=6)
    tube(S, eb + X * 0.3 + sub * 1.2 - nb * 3.9, eb + X * (Lu - 0.3) + sub * 1.2 - nb * 3.9, 0.7, M_OLDBAMBOO, prm=(0.3, 0.4, 0), nr=6, nl=16)
    e, su, n, LB = fr
    for f in (0.42, 0.76):
        p0 = e + su * LB * f + n * 2.1
        tube(S, p0 + X * 1.0, p0 + X * (Lu - 1.0), K.BATTEN_R, M_OLDBAMBOO, prm=(rng.random(), 0.5, 0), nr=8, nl=16)
    p0 = e + su * 1.0 + n * 1.8
    tube(S, p0 + X * 0.5, p0 + X * (Lu - 0.5), 0.8, M_OLDBAMBOO, prm=(0.4, 0.3, 0), nr=8, nl=22)
    # verge poles (gác đầu hồi) along both gable edges of the front slope, the right one is seen
    for x in (0.6, Lu - 0.6):
        for (ee, ss, nn, LL) in (fr,):
            tube(S, ee + X * x + nn * 1.6, ee + X * x + ss * (LL - 1.0) + nn * 1.6, 0.6, M_OLDBAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=10)
    B.ridge(S, rng)
    R = K.RIDGE_R
    for f_ in (0.1, 0.5, 0.9):                                                         # 3 more mây ties on the ridge roll
        xl = EU0 * T + (EU1 - EU0) * T * f_
        for dx in (0.0, 0.75):
            pts = [np.array([xl + dx, RV * T + math.cos(a) * (R * 1.12 + 0.5), RZ + 0.6 + math.sin(a) * (R * 1.06 + 0.6)]) for a in np.linspace(0.05, math.pi - 0.05, 11)]
            for i in range(10): tube(S, pts[i], pts[i + 1], K.TIE_R, M_RATTAN, nr=5, nl=2)
    for xe in (EU0 * T - 1.0, EU1 * T + 1.0):                                         # cut ends of the ridge roll
        def Fc(U, V, xe=xe):
            th = V * math.pi
            return np.stack([np.full_like(U, xe), RV * T + np.cos(th) * U * 1.1, RZ + 0.6 + np.sin(th) * U], -1)
        S.grid(Fc, 4, 10, K.M_THEND, (0, 0, 0), 0.0, uvr=((0, R * 1.05), (0, 1)))


def platform(S, rng):
    rrect_top(S, 0.06, 3.94, 0.06, 3.94, 0.06, ZF, M_YARD)
    extrude(S, rrect(0.06, 3.94, 0.06, 3.94, 0.06), 0.0, ZF, M_EARTHSIDE, flare=0.6)
    rrect_top(S, 0.2, 3.4, 0.2, 2.12, 0.04, ZH, M_FLOOR, prm=(0.5, 0, 0))              # nền đất đắp: room + hiên
    extrude(S, rrect(0.2, 3.4, 0.2, 2.12, 0.04), ZF - 0.1, ZH, M_EARTHSIDE, flare=0.25)
    bam(S, rng, W3(0.2, 2.13, ZH - 0.8), W3(3.4, 2.13, ZH - 0.8), 0.65, nl=24, mat=M_OLDBAMBOO)
    bam(S, rng, W3(3.41, 0.2, ZH - 0.8), W3(3.41, 2.13, ZH - 0.8), 0.65, nl=20, mat=M_OLDBAMBOO)


def columns(S, rng):
    zt = EZ - 1.2
    for u in CU:
        c = W3(u, PV, ZH - 0.4)
        lathe(S, c, [(0, 3.0), (0.8, 3.0), (1.6, 2.5), (1.9, 0.0)], M_STONE, na=16)
        B.post(S, rng, u, PV, ZH + 1.6, zt - 0.6)
    bam(S, rng, W3(CU[0] - 0.12, PV, zt - 0.4), W3(CU[-1] + 0.12, PV, zt - 0.4), 1.2, nl=24)
    for u in CU:
        bam(S, rng, W3(u, PV, zt - 0.4), W3(u, V1, ZW - 4.0), 0.8, nl=4)


# ---------------------------------------------------------------- hiên bits
def drum(S, rng):
    """trống trường on a tre giá in the sân next to the cột cờ (Link 07:33): a barrel of staves on its side, faces to ±u,
    hung by mây from the giá's crossbar; 2 A-frame legs at each end; the dùi leaning on a leg"""
    c = W3(*DRUM); L, R = 9.5, 5.6
    def Fb(U, V):
        x = (U - 0.5) * L; r = R * (1 - 0.13 * (2 * (U - 0.5)) ** 2); th = V * 2 * math.pi
        return np.stack([c[0] + x, c[1] + np.cos(th) * r, c[2] + np.sin(th) * r], -1)
    S.grid(Fb, 12, 40, M_DRUM, (0, 0, 0), 0.0, close_v=True)
    for sg in (-1, 1):
        disc(S, c + np.array([sg * L / 2, 0, 0]), (sg, 0, 0), R * 0.87, M_SKIN, nr=6, na=32, dome=0.15)
        for ring in (0.5, 1.4):
            for k in range(18):                                                         # 2 rows of đinh tre round each face
                a_ = k * 2 * math.pi / 18 + ring
                p = c + np.array([sg * (L / 2 - ring), math.cos(a_) * R * 0.9, math.sin(a_) * R * 0.9])
                ell(S, p, 0.26, 0.26, 0.26, M_WOOD, nu=4, nvv=4)
    # the giá: A-frames just outside each face, a crossbar on top, mây cords to 2 iron rings on the drum
    zt = c[2] + R + 6.0
    for sg in (-1, 1):
        x = c[0] + sg * (L / 2 + 1.8)
        for dy in (-1, 1):
            bam(S, rng, np.array([x + sg * 0.6, c[1] + dy * 6.0, ZF - 0.5]), np.array([x, c[1] + dy * 0.4, zt + 0.8]), 0.75, nl=10)
        bam(S, rng, np.array([x, c[1] - 4.0, ZF + 4.5]), np.array([x, c[1] + 4.0, ZF + 4.5]), 0.55, nl=6)
    bam(S, rng, np.array([c[0] - L / 2 - 3.2, c[1], zt]), np.array([c[0] + L / 2 + 3.2, c[1], zt]), 0.85, nl=12)
    for dx in (-2.4, 2.4):
        tube(S, c + np.array([dx, 0, R * 0.98]), np.array([c[0] + dx * 1.15, c[1], zt - 0.6]), 0.26, M_RATTAN, nr=4, nl=4)
        lathe(S, c + np.array([dx, 0, R * 0.96]), [(0, 0.9), (0.25, 1.0), (0.5, 0.9)], M_SOOT, na=10)


def desks(S, rng):
    """3 rows of bàn ghế tre facing the back wall (the bảng inside), vở on the desks; the teacher's table + đèn dầu"""
    zd, zs = ZH + 11.0, ZH + 6.5
    for row, v in enumerate((0.78, 1.08, 1.36)):
        for (a, b) in ((0.5, 1.35), (1.55, 2.25), (2.62, 3.12)):
            for u in (a + 0.04, b - 0.04):                                              # bàn: 2 legs each end, plank top
                for dv in (-0.05, 0.05):
                    bam(S, rng, W3(u, v + dv, ZH), W3(u, v + dv, zd - 0.6), 0.5, nl=3)
            box(S, W3(a, v - 0.08, zd - 0.6), W3(b, v + 0.08, zd), M_PLANK)
            for u in (a + 0.04, b - 0.04):                                              # ghế dài behind it
                bam(S, rng, W3(u, v + 0.16, ZH), W3(u, v + 0.16, zs - 0.4), 0.45, nl=3)
            for k in range(3):
                bam(S, rng, W3(a, v + 0.13 + k * 0.03, zs - 0.3), W3(b, v + 0.13 + k * 0.03, zs - 0.3), 0.4, nl=8)
            for k in range(3):                                                          # vở, a bút chì
                uu = a + 0.12 + k * (b - a - 0.24) / 2 + rng.uniform(-0.03, 0.03)
                c = W3(uu, v - 0.02, zd + 0.05)
                obox(S, c, np.array([3.2, 0.4, 0]), np.array([-0.3, 4.2, 0]), np.array([0, 0, 0.35]), M_BOOK if (k + row) % 2 else M_BOOK2)
    # bàn giáo viên near the door with the đèn dầu
    c = W3(OIL[0], OIL[1], ZH)
    for (dx, dy) in ((-4.0, -2.4), (4.0, -2.4), (-4.0, 2.4), (4.0, 2.4)):
        bam(S, rng, c + np.array([dx, dy, 0]), c + np.array([dx, dy, 12.4]), 0.55, nl=3)
    box(S, c + np.array([-4.6, -3.0, 12.4]), c + np.array([4.6, 3.0, 13.0]), M_PLANK)
    B.oillamp(S, W3(*OIL))


def lamp_bits(S, rng):
    c = W3(*LAMP)
    tube(S, W3(LAMP[0], PV, EZ - 2.4), c + np.array([0, 0, 4.4]), 0.16, M_SOOT, nr=4, nl=2)
    B.biglamp(S, c)


def sign(S, rng):
    """the TRƯỜNG LÀNG board stands on the eave pole, held by 2 tre struts from the hiên beam"""
    u0, u1, v, z0, z1 = SIGN
    box(S, W3(u0, v - 0.02, z0), W3(u1, v + 0.02, z1), M_SIGNB)
    for (a, b) in ((W3(u0, v + 0.024, z0), W3(u1, v + 0.024, z0)), (W3(u0, v + 0.024, z1), W3(u1, v + 0.024, z1)),
                   (W3(u0, v + 0.024, z0), W3(u0, v + 0.024, z1)), (W3(u1, v + 0.024, z0), W3(u1, v + 0.024, z1))):
        tube(S, a, b, 0.6, M_BAMBOO, prm=(rng.random(), 0.3, 0), nr=6, nl=6)
    for u in (u0 + 0.06, u1 - 0.06):                                                   # 2 tre legs: down past the eave
        bam(S, rng, W3(u, v + 0.03, EZ - 1.2), W3(u, v + 0.03, z1 + 2.0), 0.85, nl=10)  # stands on the eave pole
        tube(S, W3(u, v + 0.03, z1 + 2.0), W3(u, v + 0.03, z1 + 2.6), 0.95, M_BAMBOO, nr=6, nl=2)
        for zz in (EZ - 1.0, z0 + 1.0, z1 - 1.0):
            pts = [W3(u, v + 0.03, zz) + np.array([math.cos(t_) * 1.25, math.sin(t_) * 1.25, 0.25 * math.sin(t_ * 2)]) for t_ in np.linspace(0, 2 * math.pi, 9)]
            for i in range(8): tube(S, pts[i], pts[i + 1], 0.22, M_RATTAN, nr=4, nl=2)


# ---------------------------------------------------------------- yard
def flagpole(S, rng):
    c = W3(FLAG[0], FLAG[1], ZF)
    lathe(S, c - np.array([0, 0, 0.3]), [(0, 6.4), (0.8, 6.3), (2.4, 5.6), (3.0, 4.2), (3.2, 0.0)], M_EARTHSIDE, na=24)
    disc(S, c + np.array([0, 0, 3.0]), (0, 0, 1), 4.3, M_FLOOR, nr=3, na=24)
    for k in range(11):                                                                 # đá kê round the mound
        a = k * 2 * math.pi / 11 + rng.uniform(-0.1, 0.1)
        ell(S, c + np.array([math.cos(a) * 6.4, math.sin(a) * 6.4, 0.8]), rng.uniform(1.2, 1.6), 1.0, rng.uniform(0.7, 1.0), M_STONE, nu=5, nvv=6)
    zc = c[2] + 3.0
    tube(S, np.array([c[0], c[1], zc - 0.5]), np.array([c[0], c[1], zc + FLAG_H * 0.45]), 1.15, M_OLDBAMBOO, prm=(0.4, 0.3, 0), nr=10, nl=14, taper=0.85)
    bam(S, rng, np.array([c[0], c[1], zc + FLAG_H * 0.45 - 1.0]), c + np.array([0, 0, FLAG_H]), 0.9, nl=16)
    for zz in np.linspace(zc + 6, c[2] + FLAG_H - 4, 9):                               # mắt tre (nodes)
        rr = 1.12 - 0.3 * (zz - zc) / FLAG_H
        lathe(S, np.array([c[0], c[1], zz]), [(0, rr), (0.3, rr + 0.18), (0.6, rr)], M_OLDBAMBOO, na=12)
    tube(S, c + np.array([0, 0, FLAG_H]), c + np.array([0, 0, FLAG_H + 1.6]), 0.95, M_BAMBOO, nr=6, nl=2)
    tube(S, c + np.array([1.1, 0, 6.0]), c + np.array([0.95, 0, FLAG_H - 1.0]), 0.13, M_RATTAN, nr=4, nl=10)   # the halyard
    tube(S, c + np.array([1.4, 0, 5.0]), c + np.array([1.4, 0, 7.0]), 0.4, M_WOOD, nr=5, nl=2)                 # its cleat


def flagtop():
    return W3(FLAG[0], FLAG[1], ZF) + np.array([0, 0, FLAG_H])


def muoigio(S, rng):
    """a bed of bông mười giờ at the front-right corner of the hiên, edged with tre"""
    u0, u1, v0, v1 = 3.46, 3.88, 2.2, 2.44
    rrect_top(S, u0, u1, v0, v1, 0.03, ZF + 1.2, M_FLOOR, prm=(0.8, 0, 0))
    extrude(S, rrect(u0, u1, v0, v1, 0.03), ZF - 0.1, ZF + 1.2, M_EARTHSIDE, flare=0.1)
    bam(S, rng, W3(u0, v1 + 0.01, ZF + 0.6), W3(u1, v1 + 0.01, ZF + 0.6), 0.5, nl=10, mat=M_OLDBAMBOO)
    z = ZF + 1.2
    for k in range(40):
        u = rng.uniform(u0 + 0.04, u1 - 0.04); v = rng.uniform(v0 + 0.04, v1 - 0.04)
        c = W3(u, v, z); h = rng.uniform(1.0, 2.6)
        for j in range(3):
            a = rng.uniform(0, 2 * math.pi)
            ell(S, c + np.array([math.cos(a) * 0.7, math.sin(a) * 0.7, h * 0.6]), 0.7, 0.25, 0.25, M_MUOIL,
                axes=(np.array([math.cos(a), math.sin(a), 0.3]), np.array([-math.sin(a), math.cos(a), 0]), np.array([0, 0, 1.0])), nu=4, nvv=5)
        if k % 2 == 0:
            ell(S, c + np.array([0, 0, h + 0.4]), 0.75, 0.75, 0.35, M_MUOI if k % 6 else M_BOOK, nu=5, nvv=6)


def washstand(S, rng):
    """chỗ rửa tay by the right wall (Link 07:33, replaces the lu): a short tre giá with 2 thau nhôm (kept simple, sơ cấp)"""
    u, v0, v1 = WASH; zt = ZF + 11.0
    for vv in (v0 + 0.03, (v0 + v1) / 2, v1 - 0.03):
        for du in (-0.08, 0.08):
            bam(S, rng, W3(u + du, vv, ZF - 0.3), W3(u + du, vv, zt - 0.4), 0.55, nl=4)
    for k in range(6):
        uu = u - 0.1 + 0.2 * (k + 0.5) / 6
        bam(S, rng, W3(uu, v0, zt - 0.3), W3(uu, v1, zt - 0.3), 0.5, nl=12)
    for vv in (v0 + 0.1, v0 + 0.28):                                                                   # thau nhôm with water
        cc = W3(u, vv, zt)
        lathe(S, cc, [(0, 1.6), (0.3, 2.1), (1.8, 3.4), (2.1, 3.6)], M_TIN, na=22)
        disc(S, cc + np.array([0, 0, 1.6]), (0, 0, 1), 3.0, M_WATERG, nr=2, na=20)


def pebbles(S, rng):
    """sỏi + a quan stone in the ô ăn quan, a hòn đá on the lò cò"""
    qu0, qu1, qv0, qv1 = 3.0, 3.58, 2.72, 2.98
    for k in range(10):
        col_ = k % 5; row = k // 5
        cu = qu0 + (col_ + 0.5) * (qu1 - qu0) / 5; cv = qv0 + (row + 0.5) * (qv1 - qv0) / 2
        for j in range(rng.integers(2, 5)):
            ell(S, W3(cu + rng.uniform(-0.03, 0.03), cv + rng.uniform(-0.03, 0.03), ZF + 0.3), 0.45, 0.4, 0.35, M_PEBBLE, nu=4, nvv=4)
    for cu in (qu0 - 0.07, qu1 + 0.07):
        ell(S, W3(cu, (qv0 + qv1) / 2, ZF + 0.6), 1.1, 0.9, 0.7, M_STONE, nu=5, nvv=6)
    ell(S, W3(LOCO[0] + 0.17, 3.17, ZF + 0.4), 0.9, 0.7, 0.45, M_STONE, nu=5, nvv=6)


def yardbench(S, rng):
    """a long băng ghế tre in the front-right yard where the kids wait for the trống: a cặp vải, vở, 2 đôi dép (no nón lá)"""
    u0, u1, v = 3.05, 3.72, 3.5
    zs = ZF + 7.0
    for u in (u0 + 0.04, (u0 + u1) / 2, u1 - 0.04):
        for dv in (-0.06, 0.06):
            bam(S, rng, W3(u, v + dv, ZF), W3(u, v + dv, zs - 0.5), 0.5, nl=3)
    for k in range(5):
        vv = v - 0.08 + 0.16 * (k + 0.5) / 5
        bam(S, rng, W3(u0, vv, zs - 0.4), W3(u1, vv, zs - 0.4), 0.48, nl=10)
    for k in range(2):                                                                  # 2 quyển vở on the seat
        q = W3(u0 + 0.42 + k * 0.012, v + 0.0, zs + 0.05 + k * 0.4)
        obox(S, q, np.array([4.0, 0.3 * k, 0]), np.array([-0.2 * k, 3.0, 0]), np.array([0, 0, 0.38]), M_BOOK if k else M_BOOK2)


def hienbits(S, rng):
    """critique 10: the hiên is lived in: a băng ghế tre under the left window, a chổi tre on the middle column,
    a pair of dép at the door; the block step becomes a khúc tràm log + a flat stone"""
    u0, u1, v = 0.66, 1.52, 1.78
    zs = ZH + 7.5
    for u in (u0 + 0.04, (u0 + u1) / 2, u1 - 0.04):
        for dv in (-0.06, 0.06):
            bam(S, rng, W3(u, v + dv, ZH), W3(u, v + dv, zs - 0.5), 0.5, nl=3)
    for k in range(4):
        vv = v - 0.08 + 0.16 * (k + 0.5) / 4
        bam(S, rng, W3(u0, vv, zs - 0.4), W3(u1, vv, zs - 0.4), 0.5, nl=10)
    bam(S, rng, W3(u0 + 0.02, v - 0.1, zs + 0.2), W3(u1 - 0.02, v - 0.1, zs + 0.2), 0.36, nl=10)
    # chổi tre leaning on the middle column (its left, so the column does not hide it)
    p = W3(CU[1] - 0.07, PV + 0.03, ZH + 0.3)
    tube(S, p + np.array([0, 0, 2.0]), p + np.array([-1.2, -0.6, 25.0]), 0.35, M_BAMBOO, nr=5, nl=4)
    for k in range(12):
        a = (k / 11 - 0.5) * 1.2
        tube(S, p + np.array([0, 0, 3.0]), p + np.array([3.0 * math.sin(a), 0.5 * math.cos(a), -0.2]), 0.16, K.M_STRAW, nr=3, nl=2)
    # bậc thềm: a low step of packed earth, part of the nền (no loose log)
    zs = (ZF + ZH) / 2
    rrect_top(S, PATHU[0] + 0.02, PATHU[1] - 0.02, 2.08, 2.3, 0.07, zs, M_FLOOR, prm=(0.5, 0, 0))
    extrude(S, rrect(PATHU[0] + 0.02, PATHU[1] - 0.02, 2.08, 2.3, 0.07), ZF - 0.1, zs, M_EARTHSIDE, flare=0.7)


def tree(S, rng):
    """cây bàng in the front-left corner: short thick grey trunk, branches in whorls, 3 dense flat tiers of leaves
    (smaller upward, a few turning red); casts no baked shadow"""
    c = W3(TREE[0], TREE[1], ZF)
    H = 38.0
    tube(S, c - np.array([0, 0, 0.5]), c + np.array([0.3, -0.2, H]), 2.4, M_BARKB, prm=(0.3, 0, 0), nr=12, nl=14, taper=0.5)
    for k in range(5):                                                                  # root flare
        a = k * 2 * math.pi / 5 + 0.4
        tube(S, c + np.array([0, 0, 3.0]), c + np.array([math.cos(a) * 3.6, math.sin(a) * 3.6, -0.2]), 1.1, M_BARKB, nr=6, nl=3, taper=0.4)
    tiers = ((19.0, 16.5, 6), (28.0, 14.5, 6), (35.0, 9.5, 5), (40.0, 4.5, 0))   # wide flat tiers: a bàng, not a pine
    for ti, (zt, rad, nb) in enumerate(tiers):
        rot = rng.uniform(0, 2 * math.pi)
        cz = c + np.array([0.3 * zt / H, -0.2 * zt / H, zt])
        for j in range(nb):                                                             # whorl of horizontal branches
            a = rot + j * 2 * math.pi / nb
            tube(S, cz, cz + np.array([math.cos(a) * rad * 0.85, math.sin(a) * rad * 0.85, 1.6]), 0.75, M_BARKB, nr=5, nl=4, taper=0.35)
        nl = int(rad * rad * 1.6) + 20
        for k in range(nl):
            r_ = rad * math.sqrt(rng.uniform(0.0, 1.0)); a = rng.uniform(0, 2 * math.pi)
            dome = 1.6 * (1 - (r_ / rad) ** 2)
            p = cz + np.array([math.cos(a) * r_, math.sin(a) * r_, 1.2 + dome + rng.uniform(-1.0, 1.0)])
            d_ = np.array([math.cos(a), math.sin(a), 0.25 + rng.uniform(-0.15, 0.15)]); d_ /= np.linalg.norm(d_)
            sd = np.cross(d_, UP); sd /= np.linalg.norm(sd)
            m = M_BANGR if rng.random() < 0.04 else M_BANG
            ell(S, p, 1.5, 0.9, 0.2, m, axes=(d_, sd, np.cross(d_, sd)), nu=4, nvv=6)


def grass(S, rng):
    """cỏ along the edge of the sân and round the tree (critique 8); no baked shadow"""
    def tuft(u, v, h):
        q = W3(u, v, ZF - 0.1)
        for j in range(5):
            b_ = rng.uniform(0, 2 * math.pi)
            tube(S, q, q + np.array([math.cos(b_) * 0.8, math.sin(b_) * 0.8, h * rng.uniform(0.7, 1.1)]), 0.16, M_GRASS, nr=3, nl=2, taper=0.2)
    for k in range(26):                                                                 # clumps along the front + right edge
        t = rng.random()
        if rng.random() < 0.55: u, v = 0.15 + 3.7 * t, 3.86
        else: u, v = 3.86, 0.2 + 3.6 * t
        for j in range(rng.integers(3, 7)):
            tuft(u + rng.uniform(-0.06, 0.06), v + rng.uniform(-0.06, 0.03), rng.uniform(1.2, 2.6))
    for k in range(12):
        a = rng.uniform(0, 2 * math.pi); r_ = rng.uniform(0.08, 0.2)
        tuft(TREE[0] + math.cos(a) * r_, TREE[1] + math.sin(a) * r_, rng.uniform(1.0, 2.0))


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear()
    K.LIGHTS2.append((W3(*LAMP), hexc('#ff9645'), 15.0, 2.6, 'all'))
    K.LIGHTS2.append((W3(*OIL), hexc('#ff9645'), 18.0, 1.8, 'in'))
    for (p, k) in (((0.8, 1.0, ZH + 24.0), 1.5), ((1.8, 0.9, ZH + 24.0), 1.5), ((2.8, 1.0, ZH + 24.0), 1.5)):
        K.LIGHTS2.append((W3(*p), hexc('#ff9645'), 13.0, k, 'in'))
    for p in ((3.42, 0.9, ZH + 16.0), (0.8, 1.9, ZH + 12.0), (2.5, 2.0, ZH + 8.0)):
        K.LIGHTS2.append((W3(*p), hexc('#ff9645'), 9.0, 0.9, 'out'))
    K.GLOWS[:] = [(W3(*LAMP), 0.2, 0.85), (W3(*OIL), 0.06, 0.6)]
    K.GROUND_GLOW[:] = [(LAMP[0], 2.3, 30, 0.35)]
    platform(S, rng)
    walls(S, rng)
    groof(S, rng)
    columns(S, rng)
    desks(S, rng)
    drum(S, rng)
    lamp_bits(S, rng)
    sign(S, rng)
    flagpole(S, rng)
    muoigio(S, rng)
    washstand(S, rng)
    hienbits(S, rng)
    tree(S, rng)
    pebbles(S, rng)
    yardbench(S, rng)
    return S, (S.ns, S.ns)


K.build = build


def render(n):
    return K.render(1, n, 'b')


if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        n = len(sys.argv) > 3 and sys.argv[3] == 'n'
        render(n).save(sys.argv[2])
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
