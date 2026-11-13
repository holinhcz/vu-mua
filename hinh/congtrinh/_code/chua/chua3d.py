# Nông Trại Chung: Chùa làng cấp 1 (game id chua 4x4, mirror chua2) as a real 3D model, built with the kho kit.
# Link 2026-11-09: bản vẽ xem/cong-trinh/chua-ban-ve.jpg approved ("dựng đi"); sơ cấp = tre, gỗ tràm, lá dừa nước, đất đắp.
#  1 nền đất đắp 8 high with a đá ong edge          2 chánh điện 3 gian, vách lá, tre frame, 4 tràm corner posts
#  3 hiên on 4 tràm columns on stone feet          4 middle door open: the gold Phật on the bàn thờ shows through it
#  5 bàn thờ: đèn dầu + bình bông                  6 earth step + 1 stone slab        7 stepping stones from the yard
#  8 bronze lư hương on a đá ong bệ (the game draws the incense smoke at (2, 3.55))
#  9 gác chuông tre lá: bronze bell + a chày log on ropes      10 cây bồ đề, heart leaves, no baked shadow
# 11 cột tre: the game draws the Buddhist flag (chuaco.webp frames)  12 CHÙA LÀNG board on the eave (game writes the words)
# 13 chồng diêm roof, a chữ Vạn board on the diêm (the game draws the 卍 so a mirror never turns it into 卐)
# 14 pháp luân of wood on the ridge   15 2 đèn lồng giấy on the hiên (glow like the nhà tranh)   16 2 bông trang bushes
#   python3 chua3d.py prev OUT.png [n]     python3 chua3d.py flag OUTDIR     python3 chua3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'dinh'))
import dinh3d as D
from dinh3d import (K, W3, T, nv, UP, Scene, hexc, vnoise, plane, tube, disc, lathe, extrude, rrect, rrect_top, box,
                    mat_flat, MATS, GLOSS, M_EARTHSIDE, M_BAMBOO, M_PLANK, M_RATTAN, M_OLDBAMBOO, M_FLOOR, M_WOOD, M_BARK,
                    M_SOOT, M_STONE, M_TIN, bam, ell, M_GOLD, M_ORANGE, M_REDFRUIT, M_TANG, M_CLOTH, M_INCENSE, M_DOORW)

K.BB = (-134, -170, 134, 72)
K.OX, K.OY = 0, -64                          # at.P(4,4)
ZF, ZH = 2.4, 8.0                            # yard, nền chùa (higher than the trường: the chùa sits up)
CU0, CU1, CV0, CV1 = 0.35, 3.65, 0.4, 2.0   # chánh điện walls (Link 09:06 nới rộng 2 bên; 09:21 to ra phía sân)
NV1 = 2.62                                   # front edge of the nền
ZW = ZH + 66.0
DOOR = (1.72, 2.28); DZ = ZH + 40.0          # the open middle door (top 48: the skirt eave hides the wall above 48)
FWIN = ((0.6, 1.06), (2.94, 3.4)); WZ = (ZH + 15.0, ZH + 36.0)
RWIN = (0.96, 1.44)                           # between the 2 wall posts at v .88/1.52 (Link: no tre across the window)
HU = (0.35, 1.3, 2.7, 3.65); HV = 2.38      # hiên columns (a column at depth d hides the wall d to its left: clear of the door)
SKO, SKI, SKE, SKT = (0.08, 3.92, 0.02, 2.53), (0.7, 3.3, 0.72, 1.8), 66.0, 84.0
DMZ = (83.0, 104.0)
UPE, UPZ = (0.52, 3.48, 0.57, 1.95), 102.0; UPR = (1.4, 2.6, 1.26, 125.0)
TU = ((0.7, 0.72), (3.3, 0.72), (0.7, 1.8), (3.3, 1.8))
SIGN = (1.38, 2.62, 2.57, SKE + 3.0, SKE + 14.0)          # CHÙA LÀNG board on the eave (u0, u1, v, z0, z1)
VAN = (1.86, 2.14, SKI[3] + 0.03, 85.0, 95.0)           # chữ Vạn board on the diêm front (u0, u1, v, z0, z1)
ALTAR = (1.43, 1.95, 1.49, 1.69, ZH + 5.0)               # bàn thờ deeper in (critique 13: it read as standing in the door)
BUDDHA = (1.62, 1.61)                                    # seen through the door at u + depth: 2.01; head below the eave
OIL = (1.48, 1.63, ALTAR[4] + 4.2)
LANT = ((0.82, HV, 53.0), (3.18, HV, 53.0))             # đèn lồng giấy under the hiên beam
GAC = (0.2, 0.64, 3.5)                                   # gác chuông: 2 tre posts (u0, u1) on v; front-LEFT: tả chung hữu cổ
LUH = (2.0, 3.55)                                        # lư hương (the game's incense smoke rises from here)
TREE = (3.72, 3.3)                                       # cây bồ đề, front-right, away from the cột cờ
FLAGP = (1.25, 3.62); FLAG_H = 96.0                      # cột cờ
for k_, v_ in dict(ZF=ZF, ZH=ZH, ZW=ZW, SKO=SKO, SKI=SKI, SKE=SKE, SKT=SKT, DMZ=DMZ, UPE=UPE, UPZ=UPZ, UPR=UPR, TU=TU,
                   CU0=CU0, CU1=CU1, CV0=CV0, CV1=CV1, DZ=DZ, WZ=WZ, RWIN=RWIN).items():
    setattr(D, k_, v_)
K.ZW, K.ZF = ZW, ZF
K.RZ, K.EZ = UPR[3], SKE
K.WU0, K.WU1, K.WV0, K.WV1 = CU0, CU1, CV0, CV1
K.INSIDE_K = 0.3                             # Link 14:07: every building lit like the đình (was)
K.FOOT = (0.06, 3.94, 0.06, 3.94, 0.08)
K.GROUND_SHADOW = False
K.SHEET = 'chua.webp'
K.SEED = 7700
K.PATCH = None
K.WEATHER = True
K.RIDGE_R, K.BATTEN_R, K.POLE_R, K.TIE_R = 2.6, 0.55, 0.42, 0.24

M_ONG, M_SIGNC, M_VANB, M_BRONZE, M_LANTERN, M_LANTR, M_HALO, M_BUDDHA, M_LOTUS = range(300, 309)
M_BODE, M_BODE2, M_BODEBARK, M_TRANG, M_TRANGL, M_GRASS, M_BFLAG, M_ASH, M_VASE, M_FLOWER, M_YARD = range(309, 320)
M_ROBE, M_HAIR, M_PETAL, M_MANDO, M_BODEY, M_MO = range(320, 326)
K.NOSHADOW = {M_BODE, M_BODE2, M_BODEBARK, M_GRASS, M_BODEY}
K.NIGHT_EMIT = {D.M_DIEMBG: '#7a4a20', M_LANTERN: '#ffcf70'}


def mat_ong(uv, prm, pos, nrm):
    """đá ong: ochre-brown laterite, honeycomb pits, uneven blocks (critique 12: not a red brick wall)"""
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    a = x + y
    n1 = vnoise(a * 0.9, z * 0.9, 81.0); n2 = vnoise(a * 0.2, z * 0.5, 82.0)
    col = hexc('#9c7a52')[None] * (0.78 + 0.2 * n2 + 0.1 * n1)[:, None]
    col = col * (1 - 0.25 * n2[:, None]) + hexc('#8a5e3a')[None] * 0.25 * n2[:, None]
    pit = np.clip((vnoise(a * 2.6, z * 2.6, 83.0) - 0.6) * 3, 0, 1)
    col = col * (1 - 0.35 * pit[:, None])
    bw = 4.0 + 2.5 * vnoise(np.floor(z / 2.6), a * 0.0, 84.0)
    seam = np.abs(((a / bw + 0.37 * np.floor(z / 2.6)) % 1) - 0.5) > 0.465
    return np.clip(np.where(seam[:, None], col * 0.82, col), 0, 1), nrm


def mat_yard(uv, prm, pos, nrm):
    """sân đất nện quét sạch: big soft patches, the trodden way along the stones, a darker ring under the bồ đề"""
    col, n = MATS[M_FLOOR](uv, prm, pos, nrm)
    u, v = pos[:, 0] / T, pos[:, 1] / T
    big = vnoise(u * 1.6, v * 1.6, 31.0); mid = vnoise(u * 4.5, v * 4.5, 33.0)
    col = col * (0.92 + 0.1 * big + 0.05 * mid)[:, None]
    def spot(cu, cv, ru, rv):
        return np.clip(1 - np.hypot((u - cu) / ru, (v - cv) / rv), 0, 1) ** 0.8
    tr = np.maximum.reduce([spot(2.0, 3.2, 0.25, 0.6), spot(FLAGP[0], FLAGP[1], 0.25, 0.25), spot(0.42, 3.5, 0.35, 0.3)])
    col = col * (1 - 0.1 * tr[:, None]) + hexc('#a8835a')[None] * 0.1 * tr[:, None]
    return np.clip(col, 0, 1), n


def mat_signc(uv, prm, pos, nrm):
    """the name board: old dark-brown lacquer, a worn gold border line (the game paints the words)"""
    x, z = pos[:, 0], pos[:, 2]
    u0, u1, v, z0, z1 = SIGN
    a = (x - u0 * T) / ((u1 - u0) * T); b = (z - z0) / (z1 - z0)
    g = vnoise(x * 0.25, z * 3.0, 3.0)
    base = hexc('#4a2a1c')[None] * (0.85 + 0.2 * g)[:, None]
    edge = np.clip(1 - np.minimum(np.minimum(a, 1 - a) * 14, np.minimum(b, 1 - b) * 5), 0, 1)
    worn = np.clip((vnoise(x * 0.35, z * 0.9, 7.0) - 0.64) * 3 + edge * 0.6, 0, 1) * 0.6
    base = base * (1 - worn[:, None]) + hexc('#6e5236')[None] * worn[:, None]
    line = (np.abs(np.minimum(a, 1 - a) - 0.03) < 0.007) | (np.abs(np.minimum(b, 1 - b) - 0.1) < 0.022)
    base = np.where(line[:, None], hexc('#c9a24a')[None] * 0.9, base)
    return np.clip(base, 0, 1), nrm


def mat_vanb(uv, prm, pos, nrm):
    """the plank behind the chữ Vạn: dark red-brown, the game draws the gold 卍 on it"""
    g = vnoise(pos[:, 0] * 0.3, pos[:, 2] * 1.5, 9.0)
    return np.clip(hexc('#5a2a1a')[None] * (0.85 + 0.2 * g)[:, None], 0, 1), nrm


def mat_bronze(uv, prm, pos, nrm):
    n1 = vnoise(pos[:, 0] * 0.6, pos[:, 1] * 0.6 + pos[:, 2] * 0.6, 91.0)
    pat = np.clip((vnoise(pos[:, 0] * 0.25, pos[:, 1] * 0.25 + pos[:, 2] * 0.3, 92.0) - 0.55) * 3, 0, 1)   # verdigris
    col = hexc('#8a5e2c')[None] * (0.8 + 0.3 * n1)[:, None]
    col = col * (1 - 0.5 * pat[:, None]) + hexc('#5e7a62')[None] * 0.5 * pat[:, None]
    return np.clip(col, 0, 1), nrm


def mat_lantern(uv, prm, pos, nrm):
    """paper lantern: yellow paper, darker bamboo ribs every 1.1 high"""
    rib = np.abs(((pos[:, 2] / 1.1) % 1) - 0.5) > 0.4
    col = np.where(rib[:, None], hexc('#c88a2a')[None], hexc('#f2c650')[None])
    return col, nrm


def mat_buddha(uv, prm, pos, nrm):
    """old gilded statue: warm gold, slightly worn to bronze in the hollows"""
    n1 = vnoise(pos[:, 0] * 0.8, pos[:, 1] * 0.8 + pos[:, 2] * 0.8, 93.0)
    col = hexc('#f2c24c')[None] * (0.92 + 0.12 * n1)[:, None]
    return np.clip(col, 0, 1), nrm


def mat_bode(uv, prm, pos, nrm):
    n1 = vnoise(pos[:, 0] * 0.4, pos[:, 1] * 0.4 + pos[:, 2] * 0.3, 94.0); n2 = vnoise(pos[:, 0] * 0.07, pos[:, 1] * 0.07, 95.0)
    col = hexc('#3c6e24')[None] * (0.78 + 0.3 * n1 + 0.12 * n2)[:, None]
    return np.clip(col, 0, 1), nrm


def mat_bodebark(uv, prm, pos, nrm):
    n1 = vnoise(pos[:, 0] * 0.3, pos[:, 2] * 0.9, 96.0); n2 = vnoise(pos[:, 1] * 1.4, pos[:, 2] * 0.2, 97.0)
    col = hexc('#857a68')[None] * (0.8 + 0.25 * n1 - 0.12 * (n2 > 0.6))[:, None]
    return np.clip(col, 0, 1), nrm


def mat_bflag(uv, prm, pos, nrm):
    """cờ Phật giáo: 5 vertical bands xanh, vàng, đỏ, trắng, cam; the 6th band = the 5 colours in horizontal stripes"""
    C = np.array([hexc(h) for h in ('#1f5fb4', '#f6c428', '#d8302a', '#f4f2ea', '#f08a24')])
    x = np.clip(uv[:, 0], 0, 0.9999); y = np.clip(uv[:, 1], 0, 0.9999)
    k = (x * 6).astype(int)
    col = C[np.minimum(k, 4)]
    last = k >= 5
    col[last] = C[(y[last] * 5).astype(int)]
    return col, nrm


def mat_petal(uv, prm, pos, nrm):
    q = np.clip(uv[:, 0], 0, 1)
    col = hexc('#f4d2c4')[None] * (1 - q[:, None] ** 2 * 0.5) + hexc('#d8705e')[None] * (q[:, None] ** 2 * 0.5)
    return np.clip(col, 0, 1), nrm


_leaf0, _ridge0 = MATS[K.M_LEAF], MATS[K.M_RIDGE]


def mat_leaf_c(uv, prm, pos, nrm):
    """lá dừa nước years old (critique 3): grey-brown, sun-bleached, a fresher re-thatched patch, dark wet patches"""
    col, n = _leaf0(uv, prm, pos, nrm)
    w = vnoise(pos[:, 0] * 0.045, pos[:, 1] * 0.045 + pos[:, 2] * 0.04, 41.0)
    w2 = vnoise(pos[:, 0] * 0.15, pos[:, 1] * 0.15 + pos[:, 2] * 0.12, 43.0)
    old = np.clip((w - 0.42) * 2.6, 0, 1)[:, None]
    c = col * 0.5 + hexc('#7a6c52')[None] * 0.32
    c = c * (0.84 + 0.22 * w2[:, None])
    c = c * (1 - 0.32 * old) + hexc('#5e5644')[None] * 0.26 * old
    pn = vnoise(pos[:, 0] * 0.025, pos[:, 1] * 0.03 + pos[:, 2] * 0.03, 47.0)
    newp = np.clip((pn - 0.64) * 5, 0, 1)[:, None]
    darkp = np.clip((0.3 - pn) * 5, 0, 1)[:, None]
    c = c * (1 - 0.45 * newp) + hexc('#b49a5e')[None] * 0.45 * newp
    c = c * (1 - 0.25 * darkp)
    return np.clip(c, 0, 1), n


def mat_ridge_c(uv, prm, pos, nrm):
    col, n = _ridge0(uv, prm, pos, nrm)
    return np.clip(col * 0.55 + hexc('#6e624a')[None] * 0.28, 0, 1), n


MATS.update({D.M_LEAF_OLD: mat_leaf_c, D.M_RIDGE_OLD: mat_ridge_c, M_ROBE: mat_flat('#c98a2a'), M_HAIR: mat_flat('#2e2a34'),
             M_PETAL: mat_petal, M_MANDO: mat_flat('#6e2a1c'), M_BODEY: mat_flat('#9a8048'), M_MO: mat_flat('#c08a45')})
GLOSS.update({M_ROBE: (0.35, 24.0)})
_roll = D.roll
def _thinroll(S, rng, p0, p1, R=1.5, tie=True):                     # critique 4: the hip rolls read as pipes
    return _roll(S, rng, p0, p1, R * 0.62, tie)
D.roll = _thinroll
MATS.update({M_YARD: mat_yard, M_ONG: mat_ong, M_SIGNC: mat_signc, M_VANB: mat_vanb, M_BRONZE: mat_bronze, M_LANTERN: mat_lantern,
             M_LANTR: mat_flat('#a8322a'), M_HALO: mat_flat('#e89a38'), M_BUDDHA: mat_buddha, M_LOTUS: mat_flat('#e6a0a0'),
             M_BODE: mat_bode, M_BODE2: mat_flat('#5e8a2e'), M_BODEBARK: mat_bodebark, M_TRANG: mat_flat('#e2382c'),
             M_TRANGL: mat_flat('#2f5a24'), M_GRASS: mat_flat('#6e9a3a'), M_BFLAG: mat_bflag, M_ASH: mat_flat('#9a948a'),
             M_VASE: mat_flat('#e8e4dc'), M_FLOWER: mat_flat('#f0d040')})
GLOSS.update({M_BRONZE: (0.35, 30.0), M_BUDDHA: (0.45, 26.0), M_VASE: (0.3, 40.0)})


# ---------------------------------------------------------------- house
def platform(S, rng):
    rrect_top(S, 0.06, 3.94, 0.06, 3.94, 0.06, ZF, M_YARD)
    extrude(S, rrect(0.06, 3.94, 0.06, 3.94, 0.06), 0.0, ZF, M_EARTHSIDE, flare=0.6)
    rrect_top(S, 0.15, 3.85, 0.2, NV1, 0.04, ZH, M_FLOOR, prm=(0.5, 0, 0))             # nền đất đắp
    extrude(S, rrect(0.15, 3.85, 0.2, NV1, 0.04), ZF - 0.1, ZH - 2.6, M_EARTHSIDE, flare=0.15)
    # one course of rough đá ong blocks along the front and right edges (critique 12)
    def course(p0, p1, n_):
        d = p1 - p0; L = np.linalg.norm(d); t = 0.0
        while t < L - 0.5:
            w = min(rng.uniform(3.6, 6.0), L - t); a, b = p0 + d * (t / L), p0 + d * ((t + w - 0.35) / L)
            h = rng.uniform(-0.25, 0.2)
            lo = np.minimum(a, b) - n_ * 0.55; hi = np.maximum(a, b) + n_ * 0.35
            box(S, np.array([lo[0], lo[1], ZH - 2.9]), np.array([hi[0], hi[1], ZH + 0.15 + h]), M_ONG)
            t += w
    course(W3(0.15, NV1, 0), W3(3.85, NV1, 0), np.array([0, 1.0, 0]))
    course(W3(3.85, 0.2, 0), W3(3.85, NV1, 0), np.array([1.0, 0, 0]))
    # one rough stone block as the step (critique 7: not a doormat)
    zs = ZF + (ZH - ZF) / 2 + 0.4
    rrect_top(S, 1.78, 2.22, NV1, NV1 + 0.18, 0.05, zs, M_TANG)
    extrude(S, rrect(1.78, 2.22, NV1, NV1 + 0.18, 0.05), zs - 1.2, zs, M_TANG, flare=0.02)
    extrude(S, rrect(1.78, 2.22, NV1, NV1 + 0.18, 0.05), ZF - 0.2, zs - 1.2, M_EARTHSIDE, flare=0.08)


def songtre(S, rng, P, a, b, z0, z1):
    for (p, q) in ((P(a, z0), P(b, z0)), (P(a, z1), P(b, z1)), (P(a, z0 - 0.6), P(a, z1 + 0.6)), (P(b, z0 - 0.6), P(b, z1 + 0.6))):
        tube(S, p, q, 0.75, M_BAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=4)
    n = max(2, int(round((b - a) * T / 3.4)))
    for k in range(1, n + 1):
        t = a + (b - a) * k / (n + 1); tube(S, P(t, z0), P(t, z1), 0.42, M_BAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=3)


def chanhdien(S, rng):
    e = 0.004
    holes = [(DOOR[0], DOOR[1], ZH, DZ)] + [(a, b, WZ[0], WZ[1]) for (a, b) in FWIN]
    D.holed(CU0, CU1, holes, lambda a, b, z0, z1: D.wall_u(S, a, b, z0, z1, CV1), ZW)
    D.wall_u(S, CU0, CU1, ZH, ZW, CV0)
    D.holed(CV0, CV1, [(RWIN[0], RWIN[1], WZ[0], WZ[1])], lambda a, b, z0, z1: D.wall_v(S, a, b, z0, z1, CU1), ZW)
    D.wall_v(S, CV0, CV1, ZH, ZW, CU0)
    for (u, v) in ((CU0, CV0), (CU1, CV0), (CU0, CV1), (CU1, CV1)):                    # 4 tràm corner posts
        lathe(S, W3(u, v, ZH - 0.4), [(0, 2.8), (0.8, 2.8), (1.4, 2.3), (1.7, 0.0)], M_TANG, na=14)
        D.post(S, rng, u, v, ZH + 1.2, ZW + 1.0, r=1.6)
    for u in (1.35, 2.65):                                                             # the gian divisions: tre
        bam(S, rng, W3(u, CV1 + e, ZH - 0.5), W3(u, CV1 + e, ZW), 1.1, nl=10)
    for v in (0.88, 1.52):                                                             # wall posts either side of the window
        bam(S, rng, W3(CU1 + e, v, ZH - 0.5), W3(CU1 + e, v, ZW), 1.1, nl=10)
    for v in (CV0, CV1):
        bam(S, rng, W3(CU0 - 0.05, v, ZW), W3(CU1 + 0.05, v, ZW), 1.25, nl=24)
    for u in (CU0, CU1):
        bam(S, rng, W3(u, CV0 - 0.05, ZW - 0.9), W3(u, CV1 + 0.05, ZW - 0.9), 1.1, nl=14)
    for z in (ZH + 2.0, ZH + 39.0):                                                    # nẹp tre across the vách
        cuts = [CU0] + (sorted([DOOR[0], DOOR[1]]) if z < DZ else []) + [CU1]
        for k in range(0, len(cuts), 2):
            bam(S, rng, W3(cuts[k], CV1 + e * 3, z), W3(cuts[k + 1], CV1 + e * 3, z), 0.55, nl=10, mat=M_OLDBAMBOO)
        bam(S, rng, W3(CU1 + e * 3, CV0, z), W3(CU1 + e * 3, CV1, z), 0.55, nl=12, mat=M_OLDBAMBOO)
    for u in DOOR:                                                                     # tràm door frame
        tube(S, W3(u, CV1 + e, ZH), W3(u, CV1 + e, DZ + 0.8), 1.0, M_WOOD, prm=(rng.random(), 0, 0), nr=6, nl=4)
    tube(S, W3(DOOR[0] - 0.04, CV1 + e, DZ), W3(DOOR[1] + 0.04, CV1 + e, DZ), 1.0, M_WOOD, nr=6, nl=4)
    box(S, W3(DOOR[0], CV1 - 0.02, ZH - 0.2), W3(DOOR[1], CV1 + 0.03, ZH + 1.0), M_WOOD)         # ngạch cửa
    for (a, b) in FWIN:
        songtre(S, rng, lambda t, z: W3(t, CV1 + 0.006, z), a, b, *WZ)
    songtre(S, rng, lambda t, z: W3(CU1 + 0.006, t, z), RWIN[0], RWIN[1], *WZ)
    for (u, v) in TU:                                                                  # tứ trụ up to the upper roof
        lathe(S, W3(u, v, ZH - 0.4), [(0, 3.0), (0.8, 3.0), (1.4, 2.5), (1.7, 0.0)], M_TANG, na=14)
        D.post(S, rng, u, v, ZH + 1.2, DMZ[1] + 2.0, r=2.0)
    altar(S, rng)


def hien(S, rng):
    zt = SKE - 1.6
    for u in HU:
        lathe(S, W3(u, HV, ZH - 0.4), [(0, 3.0), (0.8, 3.0), (1.6, 2.5), (1.9, 0.0)], M_STONE, na=16)
        D.post(S, rng, u, HV, ZH + 1.6, zt - 0.6)
        bam(S, rng, W3(u, HV, zt - 0.6), W3(u, CV1, ZW - 3.0), 0.8, nl=4)
    bam(S, rng, W3(HU[0] - 0.12, HV, zt - 0.4), W3(HU[-1] + 0.12, HV, zt - 0.4), 1.2, nl=24)
    for c in LANT:                                                                     # đèn lồng giấy
        p = W3(*c)
        tube(S, W3(c[0], HV, zt - 1.4), p + np.array([0, 0, 3.4]), 0.12, M_SOOT, nr=4, nl=2)
        lathe(S, p + np.array([0, 0, 2.8]), [(0, 1.0), (0.6, 1.0)], M_LANTR, na=12)
        lathe(S, p - np.array([0, 0, 2.6]), [(0, 2.0), (0.4, 2.6), (1.6, 3.0), (2.8, 3.1), (4.0, 2.9), (5.0, 2.3), (5.4, 1.2)], M_LANTERN, na=18)
        lathe(S, p - np.array([0, 0, 3.2]), [(0, 1.1), (0.6, 1.1)], M_LANTR, na=12)
        tube(S, p - np.array([0, 0, 3.2]), p - np.array([0, 0, 6.4]), 0.35, M_LANTR, nr=4, nl=2, taper=0.3)   # tua
    sign(S, rng)


def sign(S, rng):
    """the CHÙA LÀNG board stands on the eave pole on 2 tre legs, tied with mây"""
    u0, u1, v, z0, z1 = SIGN
    box(S, W3(u0, v - 0.02, z0), W3(u1, v + 0.02, z1), M_SIGNC)
    for u in (u0 + 0.06, u1 - 0.06):
        bam(S, rng, W3(u, v + 0.03, SKE + 1.4), W3(u, v + 0.03, z1 + 2.0), 0.85, nl=10)
        tube(S, W3(u, v + 0.03, z1 + 2.0), W3(u, v + 0.03, z1 + 2.6), 0.95, M_BAMBOO, nr=6, nl=2)
        for zz in (z0 + 1.0, z1 - 1.0):
            pts = [W3(u, v + 0.03, zz) + np.array([math.cos(t_) * 1.25, math.sin(t_) * 1.25, 0.25 * math.sin(t_ * 2)]) for t_ in np.linspace(0, 2 * math.pi, 9)]
            for i in range(8): tube(S, pts[i], pts[i + 1], 0.22, M_RATTAN, nr=4, nl=2)


def vanboard(S, rng):
    u0, u1, v, z0, z1 = VAN
    box(S, W3(u0, v - 0.02, z0), W3(u1, v + 0.015, z1), M_VANB)
    for (a, b) in ((W3(u0, v + 0.02, z0), W3(u1, v + 0.02, z0)), (W3(u0, v + 0.02, z1), W3(u1, v + 0.02, z1)),
                   (W3(u0, v + 0.02, z0), W3(u0, v + 0.02, z1)), (W3(u1, v + 0.02, z0), W3(u1, v + 0.02, z1))):
        tube(S, a, b, 0.5, M_BAMBOO, prm=(rng.random(), 0.3, 0), nr=6, nl=4)


def phapluan(S, rng, zp):
    """a sturdy wooden dharma wheel on the ridge (critique 5): double rim, 8 thick spokes, a big hub, on a clay đế"""
    R = 7.0; c = W3(2.0, UPR[2], zp + R + 3.4)
    ax, az = np.array([1.0, 0, 0]), np.array([0, 0, 1.0])
    lathe(S, W3(2.0, UPR[2], zp - 1.4), [(0, 3.0), (1.0, 3.1), (2.0, 2.2), (3.0, 1.6), (3.6, 2.0), (4.2, 1.9)], K.M_POT, prm=(0.6, 0, 0), na=18)
    tube(S, W3(2.0, UPR[2], zp + 2.6), c - az * (R - 0.6), 1.0, M_WOOD, nr=8, nl=3)
    for (r_, t_) in ((R, 1.05), (R - 1.5, 0.6)):
        pts = [c + ax * math.cos(a) * r_ + az * math.sin(a) * r_ for a in np.linspace(0, 2 * math.pi, 33)]
        for i in range(32): tube(S, pts[i], pts[i + 1], t_, M_WOOD, nr=7, nl=2)
    for k in range(8):
        a = k * math.pi / 4 + math.pi / 8
        d = ax * math.cos(a) + az * math.sin(a)
        tube(S, c + d * 1.4, c + d * (R - 0.4), 0.55, M_WOOD, nr=6, nl=2, taper=0.8)
        ell(S, c + d * (R + 1.2), 0.85, 0.75, 0.85, M_WOOD, nu=6, nvv=6)
    ell(S, c, 2.0, 1.0, 2.0, M_WOOD, nu=10, nvv=8)
    ell(S, c + np.array([0, 0.9, 0]), 0.9, 0.4, 0.9, K.M_POT, nu=8, nvv=6)


def roofs(S, rng):
    D.LEAFMAT[0], D.RIDGEMAT[0] = D.M_LEAF_OLD, D.M_RIDGE_OLD
    D.skirt(S, rng)
    D.diem(S, rng)
    vanboard(S, rng)
    zp = D.hiproof(S, rng, UPE, UPZ, UPR)
    phapluan(S, rng, zp)


# ---------------------------------------------------------------- inside: bàn thờ + tượng Phật
def petal(S, c, d, L, Wd, tilt):
    """one pointed lotus petal from c outward along d, tilted up by tilt"""
    up = np.array([0, 0, 1.0]); out = nv(d * math.cos(tilt) + up * math.sin(tilt)); side = nv(np.cross(up, d))
    nrm_ = nv(np.cross(side, out))
    def F(U, V):
        w = np.sin(np.pi * np.clip(U, 0, 1) ** 0.75) * (1 - np.clip(U - 0.7, 0, 1) / 0.3 * 0.9) * Wd * 0.5
        return c[None, None] + out[None, None] * (U * L)[..., None] + side[None, None] * (V * w)[..., None] + nrm_[None, None] * (0.5 * (1 - V ** 2) - 0.6 * U * U)[..., None]
    S.grid(F, 6, 4, M_PETAL, (0, 0, 0), 0.0, uvr=((0, 1), (-1, 1)))


def altar(S, rng):
    u0, u1, v0, v1, zt = ALTAR
    box(S, W3(u0, v0, ZH), W3(u1, v1, zt), M_PLANK)
    D.clothfront(S, u0 + 0.01, u1 - 0.01, v1 + 0.004, ZH + 0.4, zt - 0.3)
    bu, bv = BUDDHA
    b = W3(bu, bv, zt)
    # the dark wooden mandorla behind the statue frames the gold (critique 1)
    ell(S, b + np.array([0, -2.8, 10.0]), 6.0, 0.35, 10.0, M_MANDO, nu=16, nvv=12)
    # đài sen: a drum and 2 rings of pointed pale petals with rosy tips
    lathe(S, b, [(0, 3.0), (1.2, 3.3), (1.8, 3.0)], M_ROBE, na=18)
    for ring, (rr, zz, n, L, tl) in enumerate(((2.6, 1.0, 12, 3.0, 0.55), (2.2, 1.9, 10, 2.6, 0.95))):
        for k in range(n):
            a = 2 * math.pi * (k + 0.5 * ring) / n
            d_ = np.array([math.cos(a), math.sin(a), 0.0])
            petal(S, b + d_ * rr + np.array([0, 0, zz]), d_, L, 2.2, tl)
    # the seated Phật in dhyana: wide crossed legs in the robe, torso, the robe over the left shoulder, bare right shoulder
    g = b + np.array([0, 0, 2.6])
    ell(S, g + np.array([0, 0.4, 1.4]), 4.7, 2.8, 1.7, M_ROBE, nu=12, nvv=12)
    for s_ in (-1, 1):
        ell(S, g + np.array([s_ * 2.0, 1.6, 1.8]), 1.0, 0.8, 0.6, M_BUDDHA, nu=6, nvv=6)       # the soles, up
    ell(S, g + np.array([0, -0.3, 5.6]), 2.6, 1.7, 3.9, M_ROBE, nu=12, nvv=12)
    ell(S, g + np.array([0.9, 0.2, 7.2]), 1.4, 1.5, 1.6, M_BUDDHA, nu=8, nvv=8)                 # bare right chest/shoulder
    tube(S, g + np.array([-2.5, -0.1, 8.0]), g + np.array([1.8, 1.0, 3.2]), 0.8, M_ROBE, nr=8, nl=4)   # the robe's fold
    for s_ in (-1, 1):
        m_ = M_BUDDHA if s_ > 0 else M_ROBE
        ell(S, g + np.array([s_ * 2.5, -0.2, 7.6]), 1.25, 1.2, 1.35, m_, nu=7, nvv=8)
        tube(S, g + np.array([s_ * 2.9, -0.1, 7.3]), g + np.array([s_ * 2.8, 0.7, 3.8]), 0.95, m_, nr=8, nl=3)
        tube(S, g + np.array([s_ * 2.8, 0.7, 3.8]), g + np.array([s_ * 0.7, 1.5, 2.9]), 0.8, m_, nr=8, nl=3)
    ell(S, g + np.array([0, 1.5, 2.9]), 1.6, 1.0, 0.6, M_BUDDHA, nu=8, nvv=8)                  # hands in the lap
    tube(S, g + np.array([0, -0.3, 9.0]), g + np.array([0, -0.3, 10.2]), 0.9, M_BUDDHA, nr=8, nl=2)
    h = g + np.array([0, -0.2, 11.4])
    ell(S, h, 1.6, 1.6, 1.9, M_BUDDHA, nu=12, nvv=12)
    ell(S, h + np.array([0, -0.3, 0.55]), 1.68, 1.6, 1.55, M_HAIR, nu=12, nvv=12)               # dark curled hair
    ell(S, h + np.array([0, -0.3, 2.0]), 0.85, 0.85, 0.75, M_HAIR, nu=8, nvv=8)                # ushnisha
    for s_ in (-1, 1):
        ell(S, h + np.array([s_ * 1.6, -0.1, -0.5]), 0.35, 0.5, 1.3, M_BUDDHA, nu=5, nvv=6)
    n_ = np.array([0, 1.0, 0])
    disc(S, h - np.array([0, 2.5, 0]), n_, 3.4, M_HALO, na=28)                                  # hào quang
    disc(S, h - np.array([0, 2.55, 0]), n_, 4.0, M_BUDDHA, na=28)
    # đèn dầu (left), bình bông (right), a small lư hương in front
    D.oillamp(S, W3(*OIL))
    # mõ + chuông gia trì on red cushions on the floor in front of the bàn thờ (Link 09:38 fix 6)
    for (cu, kind) in ((1.6, 'mo'), (1.9, 'chuong')):
        q = W3(cu, 1.8, ZH)
        lathe(S, q, [(0, 2.0), (0.5, 2.2), (1.1, 1.9), (1.3, 0.0)], M_CLOTH, na=16)
        q = q + np.array([0, 0, 1.3])
        if kind == 'mo':
            ell(S, q + np.array([0, 0, 1.3]), 1.7, 1.5, 1.3, M_MO, nu=12, nvv=10)
            box(S, q + np.array([-1.2, 1.25, 1.2]), q + np.array([1.2, 1.55, 1.45]), M_DOORW)
            tube(S, q + np.array([1.2, 1.8, 0.2]), q + np.array([3.2, 1.0, 0.5]), 0.25, M_WOOD, nr=5, nl=2)
        else:
            lathe(S, q, [(0, 0.0), (0.2, 1.0), (0.8, 1.55), (1.8, 1.7), (2.2, 1.65)], M_BRONZE, na=20)
            disc(S, q + np.array([0, 0, 2.0]), (0, 0, 1), 1.45, M_SOOT, na=16)
    vp = W3(1.86, 1.63, zt)
    lathe(S, vp, [(0, 0.8), (0.6, 1.2), (2.2, 1.0), (3.2, 0.5), (3.8, 0.7)], M_VASE, na=14)
    for k in range(5):
        a = k * 2 * math.pi / 5; q = vp + np.array([math.cos(a) * 0.9, math.sin(a) * 0.6, 5.2 + 0.6 * (k % 2)])
        tube(S, vp + np.array([0, 0, 3.6]), q, 0.12, M_TRANGL, nr=3, nl=2)
        ell(S, q, 0.8, 0.8, 0.6, M_FLOWER, nu=5, nvv=6)
    lathe(S, W3(1.66, 1.67, zt), [(0, 0.9), (0.4, 1.2), (1.2, 1.3), (1.5, 1.2)], M_BRONZE, na=12)
    for k in range(3):
        p = W3(1.66, 1.67, zt + 1.4) + np.array([(k - 1) * 0.35, 0, 0])
        tube(S, p, p + np.array([(k - 1) * 0.2, 0, 3.0]), 0.1, M_CLOTH, nr=3, nl=2)


# ---------------------------------------------------------------- yard
def stones(S, rng):
    """4 flat stone slabs in a straight line from the step to the lư hương, evenly laid (critique 7)"""
    for v in (3.0, 3.24):
        u0, u1 = 1.9 + rng.uniform(-0.01, 0.01), 2.1 + rng.uniform(-0.01, 0.01)
        rrect_top(S, u0, u1, v - 0.075, v + 0.075, 0.03, ZF + 0.5, M_TANG)
        extrude(S, rrect(u0, u1, v - 0.075, v + 0.075, 0.03), ZF - 0.2, ZF + 0.5, M_TANG, flare=0.02)


def luhuong(S, rng):
    """a bronze đỉnh (critique 6): round belly on 3 tall legs, a wide flared rim, 2 upright ears on the rim; on a low
    đá ong bệ with a stone cap; nhang in the ash"""
    u, v = LUH; c = W3(u, v, ZF)
    box(S, c + np.array([-4.2, -4.2, -0.3]), c + np.array([4.2, 4.2, 6.0]), M_ONG)
    box(S, c + np.array([-4.8, -4.8, 6.0]), c + np.array([4.8, 4.8, 7.4]), M_TANG)
    top = c + np.array([0, 0, 7.4])
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        p = top + np.array([math.cos(a) * 2.4, math.sin(a) * 2.4, 0])
        tube(S, p, p + np.array([-math.cos(a) * 0.5, -math.sin(a) * 0.5, 4.0]), 0.55, M_BRONZE, nr=6, nl=3, taper=1.3)
        ell(S, p + np.array([0, 0, 0.3]), 0.75, 0.75, 0.4, M_BRONZE, nu=5, nvv=5)
    b = top + np.array([0, 0, 3.0])
    lathe(S, b, [(0, 0.0), (0.4, 2.0), (1.6, 3.4), (3.4, 3.8), (5.0, 3.4), (5.8, 3.0), (6.4, 3.6), (6.8, 4.1), (7.1, 4.0)], M_BRONZE, na=24)
    disc(S, b + np.array([0, 0, 6.6]), (0, 0, 1), 3.4, M_ASH, na=20)
    for s_ in (-1, 1):                                                                   # upright ears on the rim
        p = b + np.array([s_ * 3.0, 0, 6.9])
        tube(S, p, p + np.array([s_ * 0.3, 0, 2.6]), 0.42, M_BRONZE, nr=6, nl=2)
        tube(S, p + np.array([0, 0, 0]) + np.array([s_ * -1.2, 0, 0]), p + np.array([s_ * -1.0, 0, 2.6]), 0.42, M_BRONZE, nr=6, nl=2)
        tube(S, p + np.array([s_ * -1.0, 0, 2.6]), p + np.array([s_ * 0.3, 0, 2.6]), 0.42, M_BRONZE, nr=6, nl=2)
    for k in range(5):
        pp = b + np.array([(k - 2) * 0.6, (k % 2) * 0.5, 6.6])
        tube(S, pp, pp + np.array([(k - 2) * 0.35, 0.1, 6.2]), 0.14, M_CLOTH, nr=3, nl=2)


def gacchuong(S, rng):
    """gác chuông (critique 8): 2 tre posts on a stone base, a crossbeam with the bronze bell hung between them (nothing in
    front of it), a chày log on 2 ropes beside it, a small lá roof just over the frame"""
    u0, u1, v = GAC; zt = 31.0; um = (u0 + u1) / 2
    rrect_top(S, u0 - 0.06, u1 + 0.06, v - 0.12, v + 0.12, 0.03, ZF + 1.6, M_TANG)
    extrude(S, rrect(u0 - 0.06, u1 + 0.06, v - 0.12, v + 0.12, 0.03), ZF - 0.2, ZF + 1.6, M_TANG, flare=0.03)
    for u in (u0, u1):
        bam(S, rng, W3(u, v, ZF + 1.6), W3(u, v, zt + 1.0), 1.15, nl=10)
        for s_ in (-1, 1):                                                               # short braces
            bam(S, rng, W3(u, v + s_ * 0.1, ZF + 1.6), W3(u, v, ZF + 9.0), 0.6, nl=4)
    bam(S, rng, W3(u0 - 0.06, v, zt - 1.6), W3(u1 + 0.34, v, zt - 1.6), 1.0, nl=12)    # runs out over the sân for the chày
    bell = W3(um, v, 13.0)
    lathe(S, bell, [(0, 3.5), (0.5, 3.6), (1.0, 3.3), (3.0, 2.9), (6.0, 2.6), (8.4, 2.4), (9.4, 1.9), (10.0, 0.0)], M_BRONZE, na=24)
    for z in (2.0, 6.5):
        lathe(S, bell + np.array([0, 0, z]), [(0, 3.1 - z * 0.08), (0.4, 3.1 - z * 0.08)], M_BRONZE, na=20)
    tube(S, bell + np.array([0, 0, 10.0]), W3(um, v, zt - 1.6), 0.5, M_SOOT, nr=5, nl=2)
    a, b = W3(u1 + 0.3, v + 0.02, 19.0), bell + np.array([3.8, 0.6, 5.0])          # the chày hangs on the sân side
    tube(S, a, b, 1.15, M_WOOD, prm=(rng.random(), 0, 0), nr=8, nl=3)
    disc(S, b, nv(b - a), 1.15, M_PLANK, na=10)
    for t in (0.2, 0.8):
        p = a + (b - a) * t
        tube(S, p + np.array([0, 0, 1.0]), np.array([p[0], p[1], zt - 2.2]), 0.12, K.M_ROPE, nr=3, nl=2)
    K.RIDGE_R = 1.0
    D.hiproof(S, rng, (u0 - 0.05, u1 + 0.05, v - 0.15, v + 0.15), zt + 0.6, (um - 0.1, um + 0.1, v, zt + 8.0), battens=False, rr=0.6)
    K.RIDGE_R = 2.6


def bode(S, rng):
    """cây bồ đề (critique 10): a fluted grey trunk of 3 merged stems, limbs spreading wide and low, a broad lobed crown
    of heart leaves with long drip tips, hanging; a few young bronze-pink leaves"""
    c = W3(TREE[0], TREE[1], ZF)
    for k in range(6):
        a = k * 2 * math.pi / 6 + 0.3
        tube(S, c + np.array([0, 0, 4.0]), c + np.array([math.cos(a) * 5.2, math.sin(a) * 5.2, -0.3]), 1.3, M_BODEBARK, nr=6, nl=3, taper=0.35)
    fork = c + np.array([0.3, -0.2, 12.0])
    for k in range(3):                                                                  # 3 stems twisting into one trunk
        a = k * 2 * math.pi / 3
        p0 = c + np.array([math.cos(a) * 1.4, math.sin(a) * 1.4, -0.5])
        tube(S, p0, fork + np.array([math.cos(a + 1.0) * 0.8, math.sin(a + 1.0) * 0.8, 0]), 1.7, M_BODEBARK, prm=(0.3, 0, 0), nr=10, nl=8, taper=0.85)
    lobes = []
    for i, a in enumerate((0.3, 1.9, 3.4, 4.9)):
        d = nv(np.array([math.cos(a), math.sin(a), 0]) * 0.9 + np.array([0, 0, 0.5]))
        q = fork + d * rng.uniform(9.0, 10.5)
        tube(S, fork, q, 1.4, M_BODEBARK, nr=8, nl=5, taper=0.55)
        lobes.append(q + np.array([0, 0, 7.0]))
    lobes.append(fork + np.array([0, 0, 18.0]))
    for li, cen in enumerate(lobes):
        RX, RZ = (8.5, 5.2) if li < 4 else (9.5, 5.8)
        for k in range(220):
            th = rng.uniform(0, 2 * math.pi); ph = math.acos(rng.uniform(-0.45, 1.0))
            rr = rng.uniform(0.8, 1.05)
            dirn = np.array([math.sin(ph) * math.cos(th), math.sin(ph) * math.sin(th), math.cos(ph)])
            p = cen + np.array([dirn[0] * RX, dirn[1] * RX, dirn[2] * RZ]) * rr
            out = nv(dirn + np.array([0, 0, 0.2]) + rng.normal(0, 0.3, 3))
            hang = nv(np.array([rng.normal() * 0.6, rng.normal() * 0.6, -1.4]))
            side = nv(np.cross(out, hang)); hang = nv(np.cross(side, out))
            L = rng.uniform(3.0, 3.6); Wd = L * 0.78
            r_ = rng.random()
            m = M_BODEY if (r_ < 0.02 and dirn[2] > 0.5) else (M_BODE2 if r_ < 0.14 else M_BODE)
            def F(U, V, p=p, side=side, hang=hang, out=out, L=L, Wd=Wd):
                q = U
                w = np.where(q < 0.6, np.sin(np.pi * np.clip(q / 0.6, 0, 1) * 0.5 + 0.45) * (1 - 0.3 * (q < 0.1)),
                             np.clip((1 - q) / 0.4, 0, 1) ** 2.2 * 0.95)
                w = w * 0.5 * Wd
                return (p[None, None] + hang[None, None] * (q * L)[..., None] + side[None, None] * (V * w)[..., None]
                        + out[None, None] * (0.25 * (1 - V ** 2))[..., None])
            S.grid(F, 7, 3, m, (0, 0, 0), 0.0, uvr=((0, 1), (-1, 1)))


def bongtrang(S, rng, u, v):
    """a low bông trang clump (critique 9): an uneven mound of dark leaves, 4 big round heads of red flowers on top"""
    c = W3(u, v, ZF)
    for (dx, dy, r) in ((0, 0, 3.4), (2.2, -0.8, 2.6), (-2.0, 0.6, 2.4)):
        q = c + np.array([dx, dy, r * 0.9])
        ell(S, q, r, r * 0.9, r * 0.8, M_TRANGL, nu=10, nvv=8)
        for k in range(40):
            th = rng.uniform(0, 2 * math.pi); ph = math.acos(rng.uniform(-0.1, 1.0))
            d = np.array([math.sin(ph) * math.cos(th), math.sin(ph) * math.sin(th), math.cos(ph)])
            p = q + d * np.array([r, r * 0.9, r * 0.8]) * rng.uniform(0.95, 1.1)
            sd = nv(np.cross(d, UP)) if abs(d[2]) < 0.95 else np.array([1.0, 0, 0])
            ell(S, p, 1.2, 0.55, 0.18, M_TRANGL, axes=(sd, nv(np.cross(d, sd)), d), nu=4, nvv=5)
    for (dx, dy, dz) in ((0.4, 0.3, 6.6), (2.4, -0.6, 4.6), (-1.9, 0.7, 4.4), (-0.6, -1.4, 5.8)):
        h = c + np.array([dx, dy, dz])
        for j in range(16):
            a = rng.uniform(0, 2 * math.pi); ph = rng.uniform(0, 1.3)
            q = h + np.array([math.cos(a) * math.sin(ph) * 1.1, math.sin(a) * math.sin(ph) * 1.1, math.cos(ph) * 0.8])
            ell(S, q, 0.42, 0.42, 0.36, M_TRANG, nu=4, nvv=5)


def flagpole(S, rng):
    c = W3(FLAGP[0], FLAGP[1], ZF)
    lathe(S, c - np.array([0, 0, 0.3]), [(0, 4.4), (0.8, 4.2), (2.0, 3.0), (2.4, 0.0)], M_EARTHSIDE, na=18)
    for k in range(8):
        a = k * 2 * math.pi / 8 + rng.uniform(-0.1, 0.1)
        ell(S, c + np.array([math.cos(a) * 4.6, math.sin(a) * 4.6, 0.7]), rng.uniform(1.0, 1.3), 0.9, rng.uniform(0.6, 0.9), M_STONE, nu=5, nvv=6)
    zc = c[2] + 2.0
    tube(S, np.array([c[0], c[1], zc - 0.5]), np.array([c[0], c[1], zc + FLAG_H * 0.45]), 1.05, M_OLDBAMBOO, prm=(0.4, 0.3, 0), nr=10, nl=14, taper=0.85)
    bam(S, rng, np.array([c[0], c[1], zc + FLAG_H * 0.45 - 1.0]), c + np.array([0, 0, FLAG_H]), 0.85, nl=16)
    for zz in np.linspace(zc + 6, c[2] + FLAG_H - 4, 9):
        rr = 1.02 - 0.3 * (zz - zc) / FLAG_H
        lathe(S, np.array([c[0], c[1], zz]), [(0, rr), (0.3, rr + 0.16), (0.6, rr)], M_OLDBAMBOO, na=12)
    tube(S, c + np.array([0, 0, FLAG_H]), c + np.array([0, 0, FLAG_H + 1.5]), 0.9, M_BAMBOO, nr=6, nl=2)
    tube(S, c + np.array([1.0, 0, 6.0]), c + np.array([0.9, 0, FLAG_H - 1.0]), 0.13, M_RATTAN, nr=4, nl=10)
    tube(S, c + np.array([1.3, 0, 5.0]), c + np.array([1.3, 0, 7.0]), 0.4, M_WOOD, nr=5, nl=2)


def grass(S, rng):
    def tuft(u, v, h):
        q = W3(u, v, ZF - 0.1)
        for j in range(5):
            b_ = rng.uniform(0, 2 * math.pi)
            tube(S, q, q + np.array([math.cos(b_) * 0.8, math.sin(b_) * 0.8, h * rng.uniform(0.7, 1.1)]), 0.16, M_GRASS, nr=3, nl=2, taper=0.2)
    for k in range(22):
        t = rng.random()
        if rng.random() < 0.55: u, v = 0.15 + 3.7 * t, 3.86
        else: u, v = 3.88, 2.4 + 1.4 * t
        if abs(u - 2.0) < 0.2: continue
        for j in range(rng.integers(3, 7)):
            tuft(u + rng.uniform(-0.06, 0.06), v + rng.uniform(-0.06, 0.03), rng.uniform(1.2, 2.6))
    for k in range(10):
        a = rng.uniform(0, 2 * math.pi); r_ = rng.uniform(0.15, 0.25)
        tuft(TREE[0] + math.cos(a) * r_, TREE[1] + math.sin(a) * r_, rng.uniform(1.0, 2.0))


# ---------------------------------------------------------------- the Buddhist flag (frames for the game)
FLAG = {'mode': 'none', 'ph': 0.0}
FLAG_N = 12
FLAG_L, FLAG_FH = 24.0, 16.0


def flagtop():
    return W3(FLAGP[0], FLAGP[1], ZF) + np.array([0, 0, FLAG_H])


def flagcloth(S, ph):
    top = flagtop()
    def F(U, V):
        a = U ** 0.85
        w = 4.6 * U - ph + 0.5 * V
        x = U * FLAG_L * (1 - 0.05 * (1 - np.cos(w)) * a)
        y = 3.6 * a * np.sin(w) + 0.9 * a * np.sin(2 * w + 0.7) - 0.6 * U
        z = -V * FLAG_FH - 1.4 * U + 0.9 * a * np.sin(w * 0.8 + 1.3)
        return top[None, None] + np.stack([0.9 + x, y, z], -1)
    S.grid(F, 36, 20, M_BFLAG, (0, 0, 0), 0.0)


def flagbox():
    top = flagtop(); pts = []
    for dx in (0.0, FLAG_L + 2.0):
        for dy in (-4.0, 4.0):
            for dz in (2.0, -FLAG_FH - 6.0):
                p = top + np.array([dx, dy, dz]); pts.append(((p[0] - p[1]) * 32 / T + K.OX, (p[0] + p[1]) * 16 / T + K.OY - p[2]))
    xs = [q[0] for q in pts]; ys = [q[1] for q in pts]
    return (math.floor(min(xs)) - 2, math.floor(min(ys)) - 2, math.ceil(max(xs)) + 2, math.ceil(max(ys)) + 2)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear()
    if FLAG['mode'] == 'only':
        K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
        flagcloth(S, FLAG['ph'])
        return S, (S.ns, S.ns)
    for c in LANT:
        K.LIGHTS2.append((W3(*c), hexc('#ffb050'), 15.0, 2.4, 'all'))
    K.LIGHTS2.append((W3(*OIL), hexc('#ff9645'), 14.0, 2.0, 'in'))
    K.LIGHTS2.append((W3(1.65, 1.75, ZH + 16.0), hexc('#ff9645'), 10.0, 1.4, 'in'))
    for p in ((0.8, 1.3, ZH + 24.0), (3.2, 1.3, ZH + 24.0)):
        K.LIGHTS2.append((W3(*p), hexc('#ff9645'), 13.0, 1.3, 'in'))
    for p in ((2.0, 2.2, ZH + 8.0), (3.8, 1.2, ZH + 16.0)):
        K.LIGHTS2.append((W3(*p), hexc('#ff9645'), 10.0, 0.9, 'out'))
    K.GLOWS[:] = [(W3(*LANT[0]), 0.16, 0.7), (W3(*LANT[1]), 0.16, 0.7), (W3(*OIL), 0.05, 0.5)]
    K.GROUND_GLOW[:] = []
    platform(S, rng)
    chanhdien(S, rng)
    hien(S, rng)
    roofs(S, rng)
    stones(S, rng)
    luhuong(S, rng)
    gacchuong(S, rng)
    bode(S, rng)
    bongtrang(S, rng, 1.52, NV1 + 0.17)
    bongtrang(S, rng, 2.48, NV1 + 0.17)
    flagpole(S, rng)
    if FLAG['mode'] == 'static':
        flagcloth(S, FLAG['ph'])
    return S, (S.ns, S.ns)


K.build = build


def render(n):
    return K.render(1, n, 'b')


if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        n = len(sys.argv) > 3 and sys.argv[3] == 'n'
        FLAG['mode'] = 'static' if 'f' in sys.argv[4:] else 'none'
        render(n).save(sys.argv[2])
    elif sys.argv[1] == 'flag':                     # python3 chua3d.py flag OUTDIR: chuaco.webp + chuaco.json
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
        sheet.save(os.path.join(out, 'chuaco.webp'), 'WEBP', quality=92, method=6)
        sc = float(K.PXU); bx = K.BB
        json.dump({'n': FLAG_N, 'w': W_, 'h': H_, 'box': [bx[0], bx[1], round(W_ / sc, 3), round(H_ / sc, 3)]}, open(os.path.join(out, 'chuaco.json'), 'w'))
        print('flag sheet', sheet.size, K.BB)
    elif sys.argv[1] == 'atlas':
        FLAG['mode'] = 'none'
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
