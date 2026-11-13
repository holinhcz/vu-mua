# Nông Trại Chung: Đình làng (game id dinh 4x3, mirror dinh2, one level) as a real 3D model, built with the kho kit.
# Link 2026-11-09: sketch approved ("dựng đình đi"); a sơ cấp building = tre, gỗ tràm, lá: simple, no fine ornament.
#  - nền đất đắp with a tre edge and earth steps
#  - VÕ CA in front: open hall on 2 rows of tràm columns, hip lá roof; trống chầu on a tre rack, hương án with đèn dầu,
#    đèn bão on the front beam
#  - CHÁNH ĐIỆN behind: vách lá, 3 door openings, a song tre window on the end wall, bàn thờ Thành hoàng inside;
#    TỨ TRỤ (4 tràm trunks) carry a CHỒNG DIÊM roof: lower lá skirt, a vented diêm band, upper hip lá roof, a clay hồ lô
#  - yard: cột cờ tre with the cờ ngũ sắc, a lư hương on an earth block
#   python3 dinh3d.py prev OUT.png [n]        python3 dinh3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'kho')); sys.path.insert(0, os.path.join(HERE, '..', 'sap'))
import kho3d as K
import sap3d as SP
from kho3d import (W3, T, nv, UP, Scene, X3, hexc, vnoise, smooth, plane, tube, disc, lathe, extrude, rrect, rrect_top, box, obox,
                   mat_flat, MATS, GLOSS, M_EARTHSIDE, M_BAMBOO, M_WEAVE_F, M_GLAZE, M_LID, M_PLANK, M_LEAF, M_THEND, M_RIDGE,
                   M_RATTAN, M_OLDBAMBOO, M_FLOOR, M_WOOD, M_BARK, M_SOOT, M_COCO, M_WATER, M_CHIEU, M_STONE,
                   M_GRAIN, M_JUTE, M_TIN)
from sap3d import lathe2, bam, ell, M_GOLD, M_ORANGE, M_REDFRUIT

M_TERRA, M_HIDE = 219, 222
MATS[M_TERRA] = mat_flat('#9a5434'); MATS[M_HIDE] = mat_flat('#d2b98c')
MATS_HIDE2 = 228; MATS[MATS_HIDE2] = mat_flat('#b89a6a')       # the worn centre of the drum head
M_ROPE_ = K.M_ROPE

K.BB = (-136, -200, 136, 66)
K.OX, K.OY = -16, -56                        # at.P(4,3)
ZF, ZH = 2.4, 11.0                           # yard, nền đình
CU0, CU1, CV0, CV1 = 0.7, 3.3, 0.25, 1.5     # chánh điện walls
ZW = ZH + 48.0                               # its wall plate
CDOORS = ((1.6, 2.4), (0.95, 1.3), (2.7, 3.05)); DZ = ZH + 28.0   # a wide middle door: the altar shows
RWIN = (0.62, 1.12); WZ = (ZH + 12.0, ZH + 30.0)
SKO, SKI, SKE, SKT = (0.5, 3.5, 0.08, 1.66), (1.0, 3.0, 0.52, 1.18), 58.0, 80.0       # lower skirt
DMZ = (79.0, 110.0)                                                                    # diêm band (top hides under the roof)
UPE, UPZ = (0.82, 3.18, 0.36, 1.34), 102.0; UPR = (1.5, 2.5, 0.85, 134.0)            # upper roof eaves box, ridge
TU = ((1.0, 0.56), (3.0, 0.56), (1.0, 0.95), (3.0, 0.95))  # wide: none stands in the door view                          # tứ trụ
VCU = (0.55, 1.5, 2.5, 3.45); VCV = (1.85, 2.45)                              # võ ca columns
VCE, VCZ = (0.34, 3.66, 1.68, 2.56), 54.0; VCR = (1.05, 2.95, 2.12, 80.0)   # short high front eave            # võ ca roof
LAMP = (2.65, 2.47, 43.0)                    # đèn bão hung from the front beam, clear of the drum, altar, gong
OIL = (1.56, 2.11, ZH + 13.0 + 4.2)          # đèn dầu on the hương án (võ ca, middle bay)
OIL2 = (1.62, 1.07, ZH + 17.0 + 4.2)         # đèn dầu on the bàn thờ Thành hoàng
K.ZW, K.ZF = ZW, ZF
K.RZ, K.EZ = 134.0, 54.0
K.WU0, K.WU1, K.WV0, K.WV1 = CU0, CU1, CV0, CV1
K.INSIDE_K = 0.3
K.FOOT = (0.06, 3.94, 0.06, 2.94, 0.08)
K.SHEET = 'dinh.webp'
K.SEED = 7400
K.PATCH = None
K.WEATHER = True
K.RIDGE_R, K.BATTEN_R, K.POLE_R, K.TIE_R = 2.8, 0.6, 0.45, 0.26
M_VACH, M_DOORW = 213, 211


def mat_vach(uv, prm, pos, nrm):
    """vách lá dừa nước dried for years, greyer than the roof"""
    col, n = K.mat_gable(uv, prm, pos, nrm)
    w = 0.5 + 0.5 * vnoise(pos[:, 0] * 0.05 + pos[:, 1] * 0.05, pos[:, 2] * 0.08, 21.0)
    col = col * 0.8 * (1 - 0.32 * w[:, None]) + hexc('#7e6a4c')[None] * 0.32 * w[:, None] * 0.8 + hexc('#7e6a4c')[None] * 0.06
    return np.clip(col, 0, 1), n


MATS[M_VACH] = mat_vach
MATS.update({M_DOORW: mat_flat('#2a1c12')})
M_INCENSE, M_CLOTH = 214, 215
MATS.update({M_INCENSE: mat_flat('#b8862e'), M_CLOTH: mat_flat('#9c2a1e')})
M_FLAG = 216
FLAG_L, FLAG_H = 24.0, 16.0
_a = np.arange(10) * math.pi / 5 - math.pi / 2
_r = np.where(np.arange(10) % 2 == 0, 1.0, 0.382)
STAR = np.stack([np.cos(_a) * _r, np.sin(_a) * _r], 1)        # unit star, a point straight up (y down = up on the flag)


def mat_flag(uv, prm, pos, nrm):
    """cờ đỏ sao vàng: red field, a yellow five-pointed star in the middle (outer radius 0.3 of the height)"""
    R = 0.3 * FLAG_H
    x = (uv[:, 0] - 0.5) * FLAG_L / R; y = (uv[:, 1] - 0.5) * FLAG_H / R
    ins = np.zeros(len(x), bool)
    for i in range(10):
        x1, y1 = STAR[i]; x2, y2 = STAR[(i + 1) % 10]
        c = ((y1 > y) != (y2 > y)) & (x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-12) + x1)
        ins ^= c
    col = np.where(ins[:, None], hexc('#ffd83a')[None], hexc('#d42a1e')[None])
    return col, nrm


MATS[M_FLAG] = mat_flag
M_LEAF_OLD, M_LEAF_VC, M_TANG, M_DIEMBG = 223, 224, 225, 226


def mat_leaf_old(uv, prm, pos, nrm):
    """the chánh điện's lá: years older than the võ ca's, grey-brown (the two halls read apart, and not glaring)"""
    col, n = K.mat_leaf(uv, prm, pos, nrm)
    return np.clip(col * 0.6 + hexc('#86714f')[None] * 0.27, 0, 1), n


def mat_leaf_vc(uv, prm, pos, nrm):
    col, n = K.mat_leaf(uv, prm, pos, nrm)
    return np.clip(col * 0.8 + hexc('#a48c5c')[None] * 0.12, 0, 1), n


def mat_tang(uv, prm, pos, nrm):
    col, n = MATS[M_STONE](uv, prm, pos, nrm)
    return np.clip(col * 0.62 + hexc('#5e5a4e')[None] * 0.12, 0, 1), n


MATS.update({M_LEAF_OLD: mat_leaf_old, M_LEAF_VC: mat_leaf_vc, M_TANG: mat_tang, M_DIEMBG: mat_flat('#24180f')})
K.NIGHT_EMIT = {M_DIEMBG: '#7a4a20'}         # the lit inside seen through the diêm at night
LEAFMAT = [M_LEAF]
M_RIDGE_OLD = 227


def mat_ridge_old(uv, prm, pos, nrm):
    col, n = MATS[M_RIDGE](uv, prm, pos, nrm)
    return np.clip(col * 0.6 + hexc('#86714f')[None] * 0.27, 0, 1), n


MATS[M_RIDGE_OLD] = mat_ridge_old
RIDGEMAT = [M_RIDGE]


# ---------------------------------------------------------------- helpers
def post(S, rng, u, v, z0, z1, r=1.7):
    tube(S, W3(u, v, z0), W3(u, v, z1), r, M_BARK, prm=(rng.random(), 0, 0), nr=12, nl=14, taper=0.9)


def biglamp(S, c):
    lb = c - np.array([0, 0, 2.6])
    lathe(S, lb, [(0, 1.5), (0.3, 1.7), (1.2, 1.6), (1.5, 0.9)], M_SOOT)
    lathe(S, lb + np.array([0, 0, 1.5]), [(0, 0.9), (0.8, 1.35), (2.0, 1.45), (3.2, 1.2), (3.9, 0.8)], K.M_LAMPGLASS)
    lathe(S, lb + np.array([0, 0, 5.3]), [(0, 1.2), (0.6, 1.25), (1.2, 0.6), (1.8, 0.3)], M_SOOT)
    for sg in (-1, 1):
        tube(S, lb + np.array([1.55 * sg, 0, 0.6]), lb + np.array([1.2 * sg, 0, 6.6]), 0.16, M_SOOT, nr=4, nl=2)
    ell(S, c, 0.35, 0.35, 0.8, K.M_FLAME, nu=6, nvv=8)


def oillamp(S, c):
    b = c - np.array([0, 0, 4.2])
    lathe(S, b, [(0, 1.3), (0.4, 1.5), (1.4, 1.6), (2.4, 1.0), (2.6, 0.6)], K.M_LAMPGLASS, na=16)
    lathe(S, b + np.array([0, 0, 2.5]), [(0, 0.75), (0.7, 0.75), (0.8, 0.5)], M_TIN, na=12)
    lathe(S, b + np.array([0, 0, 3.2]), [(0, 0.5), (0.8, 0.9), (2.2, 0.95), (3.2, 0.55), (4.4, 0.5)], K.M_LAMPGLASS, na=14)
    ell(S, c, 0.28, 0.28, 0.7, K.M_FLAME, nu=6, nvv=8)


def wall_u(S, u0, u1, z0, z1, v, mat=M_VACH):
    if u1 - u0 < 1e-3 or z1 - z0 < 1e-3: return
    def F(U, V): return np.stack([U, np.full_like(U, v * T), ZH + V], -1)
    S.grid(F, max(2, int((u1 - u0) * 30)), max(2, int((z1 - z0) * 0.7)), mat, (0, 0, 0), 0.0, uvr=((u0 * T, u1 * T), (z0 - ZH, z1 - ZH)))


def wall_v(S, v0, v1, z0, z1, u, mat=M_VACH):
    if v1 - v0 < 1e-3 or z1 - z0 < 1e-3: return
    def F(U, V): return np.stack([np.full_like(U, u * T), U, ZH + V], -1)
    S.grid(F, max(2, int((v1 - v0) * 30)), max(2, int((z1 - z0) * 0.7)), mat, (0, 0, 0), 0.0, uvr=((v0 * T, v1 * T), (z0 - ZH, z1 - ZH)))


def holed(a0, a1, holes, put, ztop):
    cuts = sorted(set([a0, a1] + [h[0] for h in holes] + [h[1] for h in holes]))
    for a, b in zip(cuts[:-1], cuts[1:]):
        hs = sorted((h[2], h[3]) for h in holes if h[0] <= a + 1e-6 and h[1] >= b - 1e-6)
        z = ZH
        for (z0, z1) in hs:
            put(a, b, z, z0); z = z1
        put(a, b, z, ztop)


# ---------------------------------------------------------------- lá roofs (the bagian slope kit)
def tslope(S, rng, e, su, n_out, LB, ax, Lu, c0, c1, th=2.4, course=3.3):
    def lo(b): return c0 * np.clip(b, 0, LB) / LB
    def hi(b): return Lu - c1 * np.clip(b, 0, LB) / LB
    def Fu(U, V):
        b = V * LB; x = lo(b) + U * (hi(b) - lo(b))
        return e[None, None] + ax[None, None] * x[..., None] + su[None, None] * b[..., None] - n_out[None, None] * th
    S.grid(Fu, 12, 10, M_THEND, (0, 0, 0), 0.0)
    nC = int(LB / course) + 2
    for i in range(nC):
        b0 = i * course * rng.uniform(0.96, 1.04) - 1.2
        bm = b0 + course * 1.0
        xl, xh = lo(bm), hi(bm)
        if xh - xl < 0.6: continue
        a = xl - 1.0 - rng.uniform(0, 0.6)
        while a < xh + 0.6:
            w = rng.uniform(1.0, 1.6); Lf = course * rng.uniform(1.9, 2.3); tip = b0 - rng.uniform(0.0, 0.9) - (0.8 if i == 0 else 0)
            sag = 0.9 * math.sin(math.pi * min(1, max(0, (a - xl) / max(xh - xl, 1)))) * (1 - max(0, b0) / LB)
            tip -= sag
            tone = rng.integers(5); seed = rng.random(); lift = 1.45 + rng.uniform(-0.25, 0.25); sk = rng.uniform(-0.25, 0.25)
            tq = rng.uniform(0.62, 0.9)
            def F(U, V, aa=a, w=w, Lf=Lf, tip=tip, lift=lift, sk=sk, tq=tq):
                q = U / Lf
                width = w * 0.5 * np.where(q < tq, 1.0, np.clip((1 - q) / (1 - tq), 0, 1) ** 0.8)
                bb = np.minimum(tip + Lf * (1 - q), LB - 0.4)
                x = aa + w * 0.5 + V * width + sk * q
                nn = lift * q + 0.1 + 0.18 * (1 - V ** 2)
                return e[None, None] + ax[None, None] * x[..., None] + su[None, None] * bb[..., None] + n_out[None, None] * nn[..., None]
            S.grid(F, 6, 3, LEAFMAT[0], (tone, Lf, seed), 0.0, uvr=((0, Lf), (-1, 1)))
            a += w * rng.uniform(0.62, 0.8)


def face(e, top, ax):
    up = top - e; LB = np.linalg.norm(up); su = up / LB
    n = nv(np.cross(ax, su))
    if n[2] < 0: n = -n
    return su, n, LB


def roll(S, rng, p0, p1, R=1.5, tie=True):
    d = p1 - p0; L = np.linalg.norm(d); dn = d / L
    side = nv(np.cross(dn, UP)); upn = nv(np.cross(side, dn))
    def F(U, V):
        th = V * math.pi
        return (p0[None, None] + dn[None, None] * U[..., None] + side[None, None] * (np.cos(th) * R * 1.1)[..., None]
                + upn[None, None] * (np.sin(th) * R * 0.9)[..., None])
    S.grid(F, 40, 9, M_THEND, (0, 0, 0), 0.0, uvr=((0, L), (0, 1)))
    x = 0.0
    while x < L - 0.8:
        w = rng.uniform(1.0, 1.5); tone = rng.integers(5); seed = rng.random(); arc = math.pi * R * 1.1
        def Fs(U, V, x=x, w=w):
            th = -0.35 + U / arc * (math.pi + 0.7); rr = R * 1.05 + 0.15 * (1 - V ** 2)
            return (p0[None, None] + dn[None, None] * (x + V * w * 0.5)[..., None] + side[None, None] * (np.cos(th) * rr * 1.12)[..., None]
                    + upn[None, None] * (np.sin(th) * rr - 0.8 * np.clip(np.abs(th - math.pi / 2) - math.pi / 2, 0, None))[..., None])
        S.grid(Fs, 14, 3, RIDGEMAT[0], (tone, arc, seed), 0.0, uvr=((0, arc), (-1, 1)))
        x += w * rng.uniform(0.7, 0.9)
    if tie:
        c = p0 + d * (0.45 + rng.uniform(-0.04, 0.04))
        pts = [c + side * math.cos(a) * (R * 1.2 + 0.4) + upn * math.sin(a) * (R + 0.7) for a in np.linspace(0.05, math.pi - 0.05, 9)]
        for i in range(8): tube(S, pts[i], pts[i + 1], 0.26, M_RATTAN, nr=5, nl=2)


def ridge(S, rng, RA, RB, RV, RZ):
    R = K.RIDGE_R; x0 = RA * T - 1.0; Lr = (RB - RA) * T + 2.0
    def Fr(U, V):
        th = V * math.pi
        return np.stack([x0 + U, RV * T + np.cos(th) * R, RZ + 0.6 + np.sin(th) * R * 0.92], -1)
    S.grid(Fr, 40, 9, M_THEND, (0, 0, 0), 0.0, uvr=((0, Lr), (0, 1)))
    x = x0 - 0.4; A0, A1 = -0.55, math.pi + 0.55; arc = (A1 - A0) * R * 1.05
    while x < x0 + Lr + 0.4:
        w = rng.uniform(1.0, 1.5); lift = rng.uniform(0.0, 0.25); lean = rng.uniform(-0.45, 0.45); tone = rng.integers(5); seed = rng.random()
        t0, t1 = rng.uniform(1.4, 2.8), rng.uniform(1.4, 2.8)
        def Fs(U, V, x=x, w=w, lift=lift, lean=lean, t0=t0, t1=t1):
            th = A0 + U / arc * (A1 - A0)
            tp = np.clip(np.minimum(U / t0, (arc - U) / t1), 0, 1) ** 0.7
            over = np.clip(np.abs(th - math.pi / 2) - math.pi / 2, 0, None)
            rr = R * 1.04 + lift + 0.15 * (1 - V ** 2)
            y = RV * T + np.cos(th) * rr * 1.08 * (1 + 0.5 * over)
            z = RZ + 0.6 + np.sin(th) * rr - over * 2.2
            return np.stack([x + V * w * 0.55 * tp + lean * np.sin(th), y, z], -1)
        S.grid(Fs, 18, 3, RIDGEMAT[0], (tone, arc, seed), 0.0, uvr=((0, arc), (-1, 1)))
        x += w * rng.uniform(0.7, 0.9)
    zp = RZ + 0.6 + R * 1.04 + 0.45
    tube(S, (x0 - 0.5, RV * T, zp), (x0 + Lr + 0.5, RV * T, zp - 0.2), K.POLE_R, M_OLDBAMBOO, prm=(0.4, 0.3, 0), nr=8, nl=16)
    for xl in np.linspace(x0 + Lr * 0.2, x0 + Lr * 0.8, 3 if Lr > 50 else 2):
        for dx in (0.0, 0.75):
            pts = [np.array([xl + dx, RV * T + math.cos(a) * (R * 1.12 + 0.5), RZ + 0.6 + math.sin(a) * (R * 1.06 + 0.6)]) for a in np.linspace(0.05, math.pi - 0.05, 11)]
            for i in range(10): tube(S, pts[i], pts[i + 1], K.TIE_R, M_RATTAN, nr=5, nl=2)
    return zp


def hiproof(S, rng, E, EZ, R, battens=True, rr=1.5):
    """hip lá roof: eaves box E=(u0,u1,v0,v1) at EZ, ridge R=(ra,rb,rv,rz)"""
    EU0, EU1, BV, EV = E; RA, RB, RV, RZ = R
    X = np.array([1.0, 0, 0]); Y = np.array([0, 1.0, 0])
    Lu = (EU1 - EU0) * T; Lv = (EV - BV) * T
    e = W3(EU0, EV, EZ); su, n, LB = face(e, W3(EU0, RV, RZ), X)
    tslope(S, rng, e, su, n, LB, X, Lu, (RA - EU0) * T, (EU1 - RB) * T)
    front = (e, su, n, LB)
    e = W3(EU0, BV, EZ); su, n, LB = face(e, W3(EU0, RV, RZ), X)
    tslope(S, rng, e, su, n, LB, X, Lu, (RA - EU0) * T, (EU1 - RB) * T)
    for (eu, ru) in ((EU1, RB), (EU0, RA)):
        e = W3(eu, BV, EZ)
        up = W3(ru, RV, RZ) - W3(eu, RV, EZ); LB = np.linalg.norm(up); su = up / LB
        n = nv(np.cross(Y, su)); n = -n if n[2] < 0 else n
        tslope(S, rng, e, su, n, LB, Y, Lv, (RV - BV) * T, (EV - RV) * T)
    if battens:
        e, su, n, LB = front
        for fr in (0.4, 0.74):
            b = LB * fr; x0 = (RA - EU0) * T * fr + 1.5; x1 = Lu - (EU1 - RB) * T * fr - 1.5
            p0 = e + su * b + n * 2.1
            tube(S, p0 + X * x0, p0 + X * x1, K.BATTEN_R, M_OLDBAMBOO, prm=(rng.random(), 0.5, 0), nr=8, nl=14)
    for (ru, eu) in ((RA, EU0), (RB, EU1)):
        for ev in (BV, EV):
            p_top = W3(ru, RV, RZ + 0.6); p_eave = W3(eu, ev, EZ + 0.4)
            roll(S, rng, p_top, p_eave + (p_top - p_eave) * 0.03, R=rr)
    return ridge(S, rng, RA, RB, RV, RZ)


def skirt(S, rng):
    """the lower roof of the chồng diêm: 4 trapezoid lá slopes from the eaves box SKO (z SKE) up to SKI (z SKT)"""
    ou0, ou1, ov0, ov1 = SKO; iu0, iu1, iv0, iv1 = SKI
    X = np.array([1.0, 0, 0]); Y = np.array([0, 1.0, 0])
    Lu = (ou1 - ou0) * T; Lv = (ov1 - ov0) * T
    for (ev, iv) in ((ov1, iv1), (ov0, iv0)):
        e = W3(ou0, ev, SKE); su, n, LB = face(e, W3(ou0, iv, SKT), X)
        tslope(S, rng, e, su, n, LB, X, Lu, (iu0 - ou0) * T, (ou1 - iu1) * T)
        if ev == ov1:
            for fr in (0.5,):
                b = LB * fr; x0 = (iu0 - ou0) * T * fr + 1.5; x1 = Lu - (ou1 - iu1) * T * fr - 1.5
                p0 = e + su * b + n * 2.1
                tube(S, p0 + X * x0, p0 + X * x1, K.BATTEN_R, M_OLDBAMBOO, prm=(rng.random(), 0.5, 0), nr=8, nl=14)
    for (eu, iu) in ((ou1, iu1), (ou0, iu0)):
        e = W3(eu, ov0, SKE); su, n, LB = face(e, W3(iu, ov0, SKT), Y)
        tslope(S, rng, e, su, n, LB, Y, Lv, (iv0 - ov0) * T, (ov1 - iv1) * T)
    for (ou, iu) in ((ou0, iu0), (ou1, iu1)):
        for (ov, iv) in ((ov0, iv0), (ov1, iv1)):
            p_top = W3(iu, iv, SKT + 0.6); p_eave = W3(ou, ov, SKE + 0.4)
            roll(S, rng, p_top, p_eave + (p_top - p_eave) * 0.03)
    # the flashing roll where the skirt meets the diêm (front and right seen)
    roll(S, rng, W3(iu0 - 0.02, iv1 + 0.02, SKT + 0.3), W3(iu1 + 0.02, iv1 + 0.02, SKT + 0.3), R=1.3, tie=False)
    roll(S, rng, W3(iu1 + 0.02, iv0 - 0.02, SKT + 0.3), W3(iu1 + 0.02, iv1 + 0.02, SKT + 0.3), R=1.3, tie=False)


def diem(S, rng):
    """the diêm band between the two roofs: a dark gap behind song tre (smoke and heat out), tre rails"""
    u0, u1, v0, v1 = SKI; z0, z1 = DMZ
    def Fu(U, V, v=v1 - 0.05): return np.stack([U, np.full_like(U, v * T), V], -1)
    S.grid(Fu, 4, 4, M_DIEMBG, (0, 0, 0), 0.0, uvr=((u0 * T, u1 * T), (z0, z1)))
    def Fv(U, V, u=u1 - 0.05): return np.stack([np.full_like(U, u * T), U, V], -1)
    S.grid(Fv, 4, 4, M_DIEMBG, (0, 0, 0), 0.0, uvr=((v0 * T, v1 * T), (z0, z1)))
    n = 18
    for k in range(n + 1):
        u = u0 + (u1 - u0) * k / n
        bam(S, rng, W3(u, v1, z0), W3(u, v1, z1), 0.55, nl=4)
    for k in range(8):
        v = v0 + (v1 - v0) * k / 7
        bam(S, rng, W3(u1, v, z0), W3(u1, v, z1), 0.55, nl=4)
    for z in (z0 + 1.0, z0 + 9.0):
        bam(S, rng, W3(u0, v1 + 0.01, z), W3(u1 + 0.02, v1 + 0.01, z), 0.8, nl=16)
        bam(S, rng, W3(u1 + 0.01, v0, z), W3(u1 + 0.01, v1 + 0.02, z), 0.8, nl=10)


def hoxlo(S, rng, zp):
    """a fired-clay hồ lô on a tied straw collar mid ridge; the ridge roll ends tied off in short upturned straw tufts"""
    m = W3((UPR[0] + UPR[1]) / 2, UPR[2], zp - 0.8)
    lathe(S, m, [(0, 2.9), (0.9, 3.1), (1.6, 2.6)], M_THEND, na=16)
    for z in (0.5, 1.2):
        lathe(S, m + np.array([0, 0, z]), [(0, 3.15), (0.3, 3.15)], M_RATTAN, na=16)
    lathe(S, m + np.array([0, 0, 1.6]), [(0, 1.6), (0.6, 2.4), (2.4, 2.9), (4.0, 2.3), (5.0, 1.2), (5.8, 1.1), (6.8, 1.8),
                                         (8.0, 1.7), (9.0, 0.9), (9.6, 0.5), (10.4, 0.6), (10.8, 0.0)], K.M_POT, prm=(0.6, 0, 0), na=20)


# ---------------------------------------------------------------- nền, chánh điện, võ ca, yard
def platform(S, rng):
    rrect_top(S, 0.06, 3.94, 0.06, 2.94, 0.06, ZF, M_FLOOR)
    extrude(S, rrect(0.06, 3.94, 0.06, 2.94, 0.06), 0.0, ZF, M_EARTHSIDE, flare=0.6)
    rrect_top(S, 0.2, 3.8, 0.1, 2.66, 0.04, ZH, M_FLOOR, prm=(0.5, 0, 0))                # nền đất đắp
    extrude(S, rrect(0.2, 3.8, 0.1, 2.66, 0.04), ZF - 0.1, ZH, M_EARTHSIDE, flare=0.25)
    bam(S, rng, W3(0.2, 2.67, ZH - 0.9), W3(3.8, 2.67, ZH - 0.9), 0.7, nl=26, mat=M_OLDBAMBOO)
    bam(S, rng, W3(3.81, 0.1, ZH - 0.9), W3(3.81, 2.67, ZH - 0.9), 0.7, nl=20, mat=M_OLDBAMBOO)
    # 2 broad earth steps across the võ ca's middle bay, each tread laid with flat dark stone slabs
    for (v1, z) in ((2.92, ZF + (ZH - ZF) / 3), (2.8, ZF + 2 * (ZH - ZF) / 3)):
        rrect_top(S, 1.5, 2.5, 2.6, v1, 0.03, z - 0.8, M_FLOOR, prm=(0.5, 0, 0))
        extrude(S, rrect(1.5, 2.5, 2.6, v1, 0.03), ZF - 0.1, z - 0.8, M_EARTHSIDE, flare=0.12)
        for k in range(4):
            a = 1.53 + k * 0.24
            box(S, W3(a + rng.uniform(0, 0.02), 2.6, z - 0.9), W3(a + 0.22 - rng.uniform(0, 0.02), v1 - 0.015, z + 0.4), M_TANG)


def chanhdien(S, rng):
    e = 0.004
    holes = [(d0, d1, ZH, DZ) for (d0, d1) in CDOORS]
    holed(CU0, CU1, holes, lambda a, b, z0, z1: wall_u(S, a, b, z0, z1, CV1), ZW)
    wall_u(S, CU0, CU1, ZH, ZW, CV0)
    holed(CV0, CV1, [(RWIN[0], RWIN[1], WZ[0], WZ[1])], lambda a, b, z0, z1: wall_v(S, a, b, z0, z1, CU1), ZW)
    wall_v(S, CV0, CV1, ZH, ZW, CU0)
    for (u, v) in ((CU0, CV0), (CU1, CV0), (CU0, CV1), (CU1, CV1), (CU1, 0.88)):
        bam(S, rng, W3(u, v, ZH - 0.5), W3(u, v, ZW + 1.0), 1.3, nl=12)
    for v in (CV0, CV1):
        bam(S, rng, W3(CU0 - 0.05, v, ZW), W3(CU1 + 0.05, v, ZW), 1.3, nl=24)
    for u in (CU0, CU1):
        bam(S, rng, W3(u, CV0 - 0.05, ZW - 0.9), W3(u, CV1 + 0.05, ZW - 0.9), 1.15, nl=14)
    for z in (ZH + 2.0, ZH + 33.0):                                                    # nẹp tre across the vách
        cuts = [CU0] + sorted(x for d in (CDOORS if z < DZ else ()) for x in d) + [CU1]
        for k in range(0, len(cuts), 2):
            bam(S, rng, W3(cuts[k], CV1 + e * 3, z), W3(cuts[k + 1], CV1 + e * 3, z), 0.55, nl=10, mat=M_OLDBAMBOO)
        bam(S, rng, W3(CU1 + e * 3, CV0, z), W3(CU1 + e * 3, CV1, z), 0.55, nl=12, mat=M_OLDBAMBOO)
    for (d0, d1) in CDOORS:                                                            # tre door frames, no leaves
        for u in (d0, d1):
            bam(S, rng, W3(u, CV1 + e, ZH), W3(u, CV1 + e, DZ + 0.6), 0.85, nl=6)
        bam(S, rng, W3(d0 - 0.03, CV1 + e, DZ), W3(d1 + 0.03, CV1 + e, DZ), 0.85, nl=6)
    a, b = RWIN; z0, z1 = WZ                                                           # song tre window, end wall
    P = lambda t, z: W3(CU1 + 0.006, t, z)
    for (p, q) in ((P(a, z0), P(b, z0)), (P(a, z1), P(b, z1)), (P(a, z0 - 0.6), P(a, z1 + 0.6)), (P(b, z0 - 0.6), P(b, z1 + 0.6))):
        tube(S, p, q, 0.75, M_BAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=4)
    n = max(2, int(round((b - a) * T / 3.4)))
    for k in range(1, n + 1):
        t = a + (b - a) * k / (n + 1); tube(S, P(t, z0), P(t, z1), 0.42, M_BAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=3)
    for (u, v) in TU:                                                                  # tứ trụ: 4 tràm trunks up to the upper roof
        lathe(S, W3(u, v, ZH - 0.4), [(0, 3.4), (0.8, 3.4), (1.6, 2.9), (1.9, 0.0)], M_TANG, na=16)
        post(S, rng, u, v, ZH + 1.6, DMZ[1] + 2.0, r=2.3)
    altar(S, rng)


def clothfront(S, u0, u1, v, z0, z1):
    """a red altar cloth with a yellow trim band and a fringe of scallops"""
    plane(S, W3(u0, v, z1), W3(u1, 0, 0) - W3(u0, 0, 0), np.array([0, 0, z0 - z1]), 8, 4, M_CLOTH)
    plane(S, W3(u0, v + 0.003, z1 - 0.2), W3(u1, 0, 0) - W3(u0, 0, 0), np.array([0, 0, -1.6]), 8, 2, M_GOLD)
    plane(S, W3(u0, v + 0.003, z0 + 2.4), W3(u1, 0, 0) - W3(u0, 0, 0), np.array([0, 0, -0.8]), 8, 2, M_GOLD)


def altar(S, rng):
    """seen through the wide middle door (objects deeper by d show d to the right, so they sit left of centre):
    the bàn thờ Thành hoàng with its khám, and in front of it the hương án with lư hương, chân đèn, đèn dầu, fruit, flowers"""
    # bàn thờ Thành hoàng
    u0, u1, v0, v1, zt = 1.4, 1.96, 0.98, 1.16, ZH + 17.0
    box(S, W3(u0, v0, ZH), W3(u1, v1, zt), M_PLANK)
    clothfront(S, u0 + 0.01, u1 - 0.01, v1 + 0.004, ZH + 0.5, zt - 0.3)
    k0, k1 = 1.5, 1.86                                                              # the khám: a red shrine box, dark inside
    box(S, W3(k0, 1.0, zt), W3(k1, 1.1, zt + 10.0), M_CLOTH)
    plane(S, W3(k0 + 0.05, 1.104, zt + 8.6), W3(k1 - 0.05, 0, 0) - W3(k0 + 0.05, 0, 0), np.array([0, 0, -7.4]), 4, 4, M_DOORW)
    for zz in (zt + 0.2, zt + 9.6):
        box(S, W3(k0 - 0.02, 1.0, zz), W3(k1 + 0.02, 1.12, zz + 0.8), M_GOLD)
    oillamp(S, W3(*OIL2))
    lathe(S, W3(1.78, 1.12, zt), [(0, 1.0), (0.5, 1.4), (1.6, 1.5), (2.0, 1.4)], M_INCENSE, na=14)
    # hương án in the võ ca's middle bay: the chánh điện front is behind the võ ca eave in this camera (an eave at depth d
    # hides the wall above eave_z - 32 d), so the altar the player sees stands here, left of centre (column at u 2.5, depth
    # .3, covers u 2.2 on its plane)
    u0, u1, v0, v1, zt = 1.36, 1.96, 2.03, 2.2, ZH + 13.0
    # Link 2026-11-09: sơ cấp = a plain bàn tre (no red lacquer, no cloth): slatted tre top, 4 tre legs, 2 rails
    n_ = 6
    for k in range(n_):
        vv = v0 + 0.012 + (v1 - v0 - 0.024) * k / (n_ - 1)
        bam(S, rng, W3(u0 - 0.02, vv, zt - 0.55), W3(u1 + 0.02, vv, zt - 0.55), 0.55, nl=8)
    for uu in (u0 + 0.03, u1 - 0.03):
        bam(S, rng, W3(uu, v0 - 0.02, zt - 1.5), W3(uu, v1 + 0.02, zt - 1.5), 0.5, nl=4)
        for vv in (v0 + 0.02, v1 - 0.02):
            bam(S, rng, W3(uu, vv, ZH - 0.2), W3(uu, vv, zt - 1.0), 0.62, nl=6)
    for vv in (v0 + 0.02, v1 - 0.02):
        bam(S, rng, W3(u0 + 0.03, vv, ZH + 4.0), W3(u1 - 0.03, vv, ZH + 4.0), 0.42, nl=8)
    c = W3(1.66, 2.11, zt)
    lathe(S, c, [(0, 1.5), (0.6, 2.2), (2.0, 2.4), (2.6, 2.2)], M_INCENSE, na=18)        # lư hương + nhang
    for k in range(3):
        p = c + np.array([(k - 1) * 0.5, 0, 2.4]); tube(S, p, p + np.array([(k - 1) * 0.3, 0.1, 4.6]), 0.13, M_CLOTH, nr=3, nl=2)
    for s_ in (-1, 1):                                                              # chân đèn
        lathe(S, c + np.array([s_ * 5.6, -1.0, 0]), [(0, 1.2), (0.5, 0.9), (1.0, 0.35), (4.6, 0.35), (5.0, 1.0), (5.4, 0.8)], M_INCENSE, na=14)
    oillamp(S, W3(*OIL))
    p = c + np.array([-6.4, 2.0, 0])                                                # mâm trái cây
    disc(S, p + np.array([0, 0, 0.3]), (0, 0, 1), 2.2, M_TIN, nr=2, na=18, dome=0.05)
    for k, (dx, dy, dz) in enumerate(((-0.8, 0.0, 1.2), (0.8, 0.2, 1.2), (0.0, -0.8, 1.2), (0.0, 0.4, 2.3))):
        ell(S, p + np.array([dx, dy, dz]), 1.0, 1.0, 0.95, M_ORANGE if k % 2 else M_REDFRUIT, nu=7, nvv=9)


def drum(S, rng, c):
    """trống chầu lying on a tre cradle, its heads to the sides (the right head faces the viewer): a red lacquered
    barrel with two dark bands, a ring of brass studs round each head, a pale hide head with a darker rim; two dùi"""
    ax = np.array([1.0, 0, 0]); L, R0, R1 = 13.0, 6.4, 7.3
    ref = np.array([0, 1.0, 0]); up = np.array([0, 0, 1.0])
    def F(U, V):
        r = R0 + (R1 - R0) * np.sin(np.pi * U) ** 0.8
        return (c[None, None] + ax[None, None] * ((U - 0.5) * L)[..., None]
                + ref[None, None] * (np.cos(V) * r)[..., None] + up[None, None] * (np.sin(V) * r)[..., None])
    S.grid(F, 14, 28, M_CLOTH, (0, 0, 0), 0.0, uvr=((0, 1), (0, 2 * math.pi)), close_v=True, flip=True)
    for t in (0.2, 0.8):
        r = R0 + (R1 - R0) * math.sin(math.pi * t) ** 0.8
        tube(S, c + ax * ((t - 0.5) * L - 0.35), c + ax * ((t - 0.5) * L + 0.35), r + 0.12, M_SOOT, nr=24, nl=2)
    for s_ in (-1, 1):
        h = c + ax * (s_ * L / 2)
        disc(S, h, ax * s_, R0 - 0.1, M_HIDE, na=28)
        disc(S, h + ax * s_ * 0.02, ax * s_, R0 * 0.42, MATS_HIDE2, na=20)
        for k in range(18):
            a = 2 * math.pi * k / 18
            ell(S, h - ax * s_ * 0.9 + ref * math.cos(a) * (R0 + 0.15) + up * math.sin(a) * (R0 + 0.15), 0.45, 0.45, 0.45, M_GOLD, nu=4, nvv=5)
    for s_ in (-1, 1):                                                              # the cradle: crossed tre legs
        for d in (-1, 1):
            bam(S, rng, c + np.array([s_ * 4.5, d * 7.0, -16.0]), c + np.array([s_ * 4.5, -d * 3.0, -2.0]), 0.8, nl=4)
        bam(S, rng, c + np.array([s_ * 4.5, -6.0, -6.2]), c + np.array([s_ * 4.5, 6.0, -6.2]), 0.7, nl=4)
    for k in (-1, 1):                                                               # dùi trống on the cradle
        tube(S, c + np.array([7.0, 4.0 + k, -6.2]), c + np.array([1.0, 5.2 + k, -5.8]), 0.38, M_WOOD, nr=5, nl=2)


def gong(S, rng, c):
    """chiêng hung on a tre frame, its face to the front"""
    for s_ in (-1, 1):
        bam(S, rng, c + np.array([s_ * 7.0, 0, -22.0]), c + np.array([s_ * 7.0, 0, 9.0]), 0.8, nl=6)
    bam(S, rng, c + np.array([-8.0, 0, 8.4]), c + np.array([8.0, 0, 8.4]), 0.75, nl=6)
    for s_ in (-1, 1):
        tube(S, c + np.array([s_ * 2.6, 0, 8.0]), c + np.array([s_ * 1.6, 0, 4.4]), 0.12, M_ROPE_, nr=4, nl=2)
    n = np.array([0, 1.0, 0])
    tube(S, c - n * 0.6, c + n * 0.3, 4.9, M_GOLD, nr=28, nl=2)
    disc(S, c + n * 0.3, n, 4.9, M_GOLD, na=28)
    ell(S, c + n * 0.45, 1.5, 0.7, 1.5, M_GOLD, nu=8, nvv=10)
    disc(S, c - n * 0.6, -n, 4.9, M_SOOT, na=20)
    tube(S, c + np.array([5.6, 1.0, -21.0]), c + np.array([5.0, 1.4, -11.0]), 0.35, M_WOOD, nr=5, nl=2)   # dùi chiêng leaning


def voca(S, rng):
    zt = VCZ - 1.6
    for v in VCV:
        for u in VCU:
            lathe(S, W3(u, v, ZH - 0.4), [(0, 3.0), (0.8, 3.0), (1.6, 2.5), (1.9, 0.0)], M_TANG, na=16)
            post(S, rng, u, v, ZH + 1.6, zt - 0.6)
        bam(S, rng, W3(VCU[0] - 0.12, v, zt - 0.4), W3(VCU[-1] + 0.12, v, zt - 0.4), 1.25, nl=24)
    for u in VCU:
        bam(S, rng, W3(u, VCV[0] - 0.12, zt + 1.6), W3(u, VCV[1] + 0.12, zt + 1.6), 1.0, nl=8)
    hiproof(S, rng, VCE, VCZ, VCR)
    drum(S, rng, W3(0.62, 2.12, ZH + 16.0))
    gong(S, rng, W3(2.84, 2.12, ZH + 22.0))
    # đèn bão
    c = W3(*LAMP)
    tube(S, W3(LAMP[0], VCV[1], zt - 1.6), c + np.array([0, 0, 4.4]), 0.16, M_SOOT, nr=4, nl=2)
    biglamp(S, c)


FLAG = {'mode': 'static', 'ph': 0.4}          # 'none': the building sheet (the game draws the cloth); 'only': a flag frame
FLAG_N = 12                                   # frames of one wave cycle


def flagtop():
    return W3(0.42, 2.84, ZF) + np.array([0, 0, 112.0])


def flagcloth(S, ph):
    """the cờ đỏ sao vàng in the wind: a travelling wave from the pole to the free end, growing toward the end"""
    top = flagtop()
    def F(U, V):
        a = U ** 0.85
        w = 4.6 * U - ph + 0.5 * V
        x = U * FLAG_L * (1 - 0.05 * (1 - np.cos(w)) * a)
        y = 3.6 * a * np.sin(w) + 0.9 * a * np.sin(2 * w + 0.7) - 0.6 * U
        z = -V * FLAG_H - 1.4 * U + 0.9 * a * np.sin(w * 0.8 + 1.3)
        return top[None, None] + np.stack([0.9 + x, y, z], -1)
    S.grid(F, 30, 18, M_FLAG, (0, 0, 0), 0.0)


def flagbox():
    """game-unit box (x0, y0, x1, y1) round every flag frame"""
    top = flagtop(); pts = []
    for dx in (0.0, FLAG_L + 2.0):
        for dy in (-4.0, 4.0):
            for dz in (2.0, -FLAG_H - 6.0):
                p = top + np.array([dx, dy, dz]); pts.append(((p[0] - p[1]) * 32 / T + K.OX, (p[0] + p[1]) * 16 / T + K.OY - p[2]))
    xs = [q[0] for q in pts]; ys = [q[1] for q in pts]
    return (math.floor(min(xs)) - 2, math.floor(min(ys)) - 2, math.ceil(max(xs)) + 2, math.ceil(max(ys)) + 2)


def yard(S, rng):
    # cột cờ tre with the cờ đỏ sao vàng (Link 04:20)
    p = W3(0.42, 2.84, ZF)
    lathe(S, p - np.array([0, 0, 0.3]), [(0, 3.2), (1.2, 3.0), (2.4, 1.6), (2.6, 0.0)], M_EARTHSIDE, na=14)
    bam(S, rng, p, p + np.array([0, 0, 118.0]), 1.0, nl=24)
    if FLAG['mode'] != 'none':
        flagcloth(S, FLAG['ph'])
    # lư hương: a fired-clay censer on 3 feet, on a low swept earth mound right of the steps
    q = W3(3.3, 2.81, ZF)
    lathe(S, q, [(0, 5.2), (1.6, 4.4), (3.2, 2.8), (3.6, 0.0)], M_EARTHSIDE, na=24)
    top = q + np.array([0, 0, 3.4])
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        tube(S, top + np.array([math.cos(a) * 2.4, math.sin(a) * 2.4, 0]), top + np.array([math.cos(a) * 2.6, math.sin(a) * 2.6, 1.8]), 0.5, K.M_POT, nr=5, nl=2)
    lathe(S, top + np.array([0, 0, 1.4]), [(0, 2.0), (0.6, 3.0), (2.4, 3.5), (3.6, 3.2), (4.2, 3.6), (4.6, 3.5)], K.M_POT, prm=(0.6, 0, 0), na=22)
    disc(S, top + np.array([0, 0, 5.4]), (0, 0, 1), 3.2, K.M_MOUND, na=18)
    for k in range(5):
        pp = top + np.array([(k - 2) * 0.6, (k % 2) * 0.5, 5.5])
        tube(S, pp, pp + np.array([(k - 2) * 0.35, 0.1, 6.0]), 0.14, M_CLOTH, nr=3, nl=2)


M_SUBARK, M_SULEAF, M_SULEAF2, M_SUFLOWER, M_SUEYE = 229, 230, 231, 232, 233
K.NOSHADOW = set(K.NOSHADOW) | {M_SUBARK, M_SULEAF, M_SULEAF2, M_SUFLOWER, M_SUEYE}   # Link 2026-11-09: no baked tree shadow (like the trường + chùa trees)


def mat_subark(uv, prm, pos, nrm):
    col, n = MATS[M_BARK](uv, prm, pos, nrm)
    return np.clip(col * 0.45 + hexc('#8e8a7c')[None] * 0.5, 0, 1), n


MATS.update({M_SUBARK: mat_subark, M_SULEAF: mat_flat('#2e4a20'), M_SULEAF2: mat_flat('#3d5a26'),
             M_SUFLOWER: mat_flat('#f6f0e2'), M_SUEYE: mat_flat('#f2c43a')})
MIEU = (3.6, 0.55)                            # miễu Thần Nông under the bông sứ, right of the end-wall window
MIEU_OIL = (3.6, 0.57, ZH + 14.0 + 3.4)


def sutree(S, rng, base):
    """cây bông sứ (đại): a short thick grey trunk forking into blunt limbs, a rosette of long leaves at each tip,
    clusters of white flowers with yellow eyes"""
    def limb(p, d, L, r, depth):
        q = p + d * L
        tube(S, p, q, r, M_SUBARK, prm=(rng.random(), 0, 0), nr=10, nl=6, taper=0.85)
        ell(S, q, r * 0.85, r * 0.85, r * 0.85, M_SUBARK, nu=6, nvv=8)
        if depth == 0:
            rosette(q, d); return
        k = 2
        for i in range(k):
            a = rng.uniform(0, 2 * math.pi) if k == 2 else 2 * math.pi * i / k + rng.uniform(-0.3, 0.3)
            nd = nv(d * 0.55 + np.array([math.cos(a), math.sin(a), 0]) * 0.6 + np.array([0, 0, 0.35]))
            limb(q, nd, L * rng.uniform(0.62, 0.78), r * 0.68, depth - 1)
    def rosette(q, d):
        for i in range(10):
            a = 2 * math.pi * i / 10 + rng.uniform(-0.2, 0.2)
            out = np.array([math.cos(a), math.sin(a), 0.0])
            ld = nv(out * 0.75 + np.array([0, 0, rng.uniform(0.35, 0.8)]))
            Lf = rng.uniform(7.0, 9.0)
            c = q + ld * (Lf * 0.55)
            side = nv(np.cross(ld, UP)) if abs(ld[2]) < 0.95 else np.array([1.0, 0, 0]); up_ = np.cross(side, ld)
            ell(S, c, Lf * 0.55, 1.5, 0.3, M_SULEAF if i % 3 else M_SULEAF2, axes=(ld, side, up_), nu=8, nvv=6)
        for j in range(rng.integers(3, 6)):                           # flowers
            a = rng.uniform(0, 2 * math.pi); fc = q + np.array([math.cos(a) * 1.4, math.sin(a) * 1.4, 1.6 + rng.uniform(0, 1.2)])
            for pidx in range(5):
                b = a + 2 * math.pi * pidx / 5
                ell(S, fc + np.array([math.cos(b) * 0.75, math.sin(b) * 0.75, 0.2]), 0.75, 0.5, 0.22, M_SUFLOWER,
                    axes=(np.array([math.cos(b), math.sin(b), 0.0]), np.array([-math.sin(b), math.cos(b), 0.0]), UP), nu=5, nvv=5)
            ell(S, fc + np.array([0, 0, 0.35]), 0.4, 0.4, 0.25, M_SUEYE, nu=4, nvv=5)
    lathe(S, base - np.array([0, 0, 0.2]), [(0, 3.4), (0.6, 2.6), (1.2, 0.0)], M_EARTHSIDE, na=14)
    p = base + np.array([0, 0, 0.6])
    tube(S, p, p + np.array([0.4, -0.3, 17.0]), 2.3, M_SUBARK, prm=(0.3, 0, 0), nr=12, nl=8, taper=0.8)
    fork = p + np.array([0.4, -0.3, 17.0])
    for i, a in enumerate((0.3, 2.3, 4.2)):
        d = nv(np.array([math.cos(a), math.sin(a), 0]) * 0.55 + np.array([0, 0, 0.8]))
        limb(fork, d, rng.uniform(10.0, 12.0), 1.6, 2)


def mieu(S, rng):
    """miễu Thần Nông: a little tre lá shrine on 4 tre legs, phên on three sides, a red tablet, lư hương, đèn dầu"""
    u, v = MIEU; h = 0.11; z0 = ZH + 14.0
    for (du, dv) in ((-h, -h), (h, -h), (-h, h), (h, h)):
        bam(S, rng, W3(u + du, v + dv, ZH), W3(u + du, v + dv, z0 + 12.0), 0.55, nl=6)
    box(S, W3(u - h - 0.02, v - h - 0.02, z0 - 0.8), W3(u + h + 0.02, v + h + 0.02, z0), M_PLANK)
    wall_u(S, u - h, u + h, z0 - ZH + ZH, z0 + 11.0, v - h)                     # back
    wall_v(S, v - h, v + h, z0, z0 + 11.0, u - h); wall_v(S, v - h, v + h, z0, z0 + 11.0, u + h)
    box(S, W3(u - 0.05, v - h + 0.01, z0), W3(u + 0.05, v - h + 0.03, z0 + 8.0), M_CLOTH)   # bài vị
    lathe(S, W3(u - 0.03, v + 0.02, z0), [(0, 0.9), (0.4, 1.2), (1.3, 1.3), (1.6, 1.2)], M_INCENSE, na=12)
    for k in range(3):
        pp = W3(u - 0.03, v + 0.02, z0 + 1.6) + np.array([(k - 1) * 0.35, 0, 0])
        tube(S, pp, pp + np.array([(k - 1) * 0.2, 0, 3.4]), 0.1, M_CLOTH, nr=3, nl=2)
    oillamp(S, W3(*MIEU_OIL) + np.array([2.4, 0.8, 0]))
    RZ_, EZ_ = K.RIDGE_R, None
    K.RIDGE_R = 1.0
    hiproof(S, rng, (u - h - 0.05, u + h + 0.05, v - h - 0.05, v + h + 0.05), z0 + 11.5, (u - 0.02, u + 0.02, v, z0 + 18.0), battens=False, rr=0.6)
    K.RIDGE_R = RZ_


def chum(S, rng):
    """chum nước rửa tay at the võ ca's right side: glazed jar, water, a plank across, a gáo dừa"""
    c = W3(3.64, 2.18, ZH); k_ = 0.8
    lathe(S, c, [(z * k_, r * k_) for z, r in [(0, 3.6), (1.5, 5.2), (5, 6.3), (9, 6.0), (12, 4.4), (13, 3.9), (13.5, 4.1)]], M_GLAZE)
    disc(S, c + np.array([0, 0, 12.0 * k_]), (0, 0, 1), 3.7 * k_, M_WATER, nr=3, na=20)
    box(S, c + np.array([-4.0, -0.6, 13.5 * k_]), c + np.array([4.0, 0.6, 13.5 * k_ + 0.5]), M_PLANK)
    g = c + np.array([1.4, 0.0, 13.5 * k_ + 0.5])
    lathe(S, g, [(0, 0.0), (0.4, 1.2), (1.4, 1.7), (1.6, 1.75)], M_COCO, na=16)
    tube(S, g + np.array([1.5, 0, 1.2]), g + np.array([5.0, 2.2, 2.2]), 0.28, M_BAMBOO, nr=4, nl=3)


def right_edge(S, rng):
    """Link 05:03 'bên mép phải còn trống': cây bông sứ in the back-right corner, miễu Thần Nông, chum nước"""
    sutree(S, rng, W3(3.7, 0.2, ZH))
    mieu(S, rng)
    chum(S, rng)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear()
    if FLAG['mode'] == 'only':
        K.GLOWS[:] = []
        flagcloth(S, FLAG['ph'])
        return S, (S.ns, S.ns)
    K.LIGHTS2.append((W3(*LAMP), hexc('#ff9645'), 15.0, 2.8, 'all'))
    K.LIGHTS2.append((W3(*OIL), hexc('#ff9645'), 14.0, 1.4, 'all'))
    K.LIGHTS2.append((W3(*OIL2), hexc('#ff9645'), 16.0, 1.6, 'in'))
    for p in ((1.2, 1.0, ZH + 24.0), (2.8, 1.0, ZH + 24.0)):
        K.LIGHTS2.append((W3(*p), hexc('#ff9645'), 13.0, 1.4, 'in'))
    for (p, r_, k_) in (((3.42, 0.87, ZH + 16.0), 9.0, 0.9), ((2.0, 1.64, ZH + 10.0), 13.0, 1.3)):
        K.LIGHTS2.append((W3(*p), hexc('#ff9645'), r_, k_, 'out'))                  # window, and the wide door onto the võ ca
    K.GLOWS[:] = [(W3(*LAMP), 0.2, 0.85), (W3(*OIL), 0.06, 0.6), (W3(*OIL2), 0.05, 0.5)]
    platform(S, rng)
    chanhdien(S, rng)
    LEAFMAT[0], RIDGEMAT[0] = M_LEAF_OLD, M_RIDGE_OLD
    skirt(S, rng)
    diem(S, rng)
    zp = hiproof(S, rng, UPE, UPZ, UPR)
    hoxlo(S, rng, zp)
    LEAFMAT[0], RIDGEMAT[0] = M_LEAF_VC, M_RIDGE
    voca(S, rng)
    yard(S, rng)
    right_edge(S, rng)
    K.LIGHTS2.append((W3(*MIEU_OIL), hexc('#ff9645'), 8.0, 0.9, 'all'))
    K.GLOWS.append((W3(*MIEU_OIL) + np.array([2.4, 0.8, 0]), 0.04, 0.5))
    return S, (S.ns, S.ns)


K.build = build


def render(n):
    return K.render(1, n, 'b')


if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        n = len(sys.argv) > 3 and sys.argv[3] == 'n'
        render(n).save(sys.argv[2])
    elif sys.argv[1] == 'flag':                     # python3 dinh3d.py flag OUTDIR: dinhco.webp + dinhco.json
        out = sys.argv[2]; FLAG['mode'] = 'only'
        BB0, FOOT0 = K.BB, K.FOOT
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
        sheet.save(os.path.join(out, 'dinhco.webp'), 'WEBP', quality=92, method=6)
        sc = float(K.PXU); bx = K.BB
        json.dump({'n': FLAG_N, 'w': W_, 'h': H_, 'box': [bx[0], bx[1], round(W_ / sc, 3), round(H_ / sc, 3)]}, open(os.path.join(out, 'dinhco.json'), 'w'))
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
