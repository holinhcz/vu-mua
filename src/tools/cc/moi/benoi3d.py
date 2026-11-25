# Bè nổi (nhà bè trên sông, 2x2 ô) dựng bằng ĐÚNG bộ vẽ công trình/xưởng của game (kho3d + bến ghe + chuồng + lò bánh):
# Link 2026-11-25 "dm mày đã đúng style vẽ của công trình nhà xưởng của game chưa?" (bản nháp trước vẽ bằng bộ ghe câu cá, sai).
# CHẠY Ở: nong-trai-chung/src/benoi/benoi3d.py (cần các bộ src/lobanh, coixay, lobanhmi, chuongga, benghe, kho, dendau, ruongmuoi, pxr, choi, den cạnh nó); đây là bản chép.
#  - phao: 4 hàng phuy sắt cũ nằm dọc u, nửa chìm dưới nước (mặt nước z 0)
#  - đà tràm tròn gác ngang phuy, sàn = từng ống tre tròn (như bến ghe)
#  - chòi lá: 4 cột tràm, vách phên tre đan + nẹp tre, mái lá 2 mái (K.roof: từng lá, nẹp tre, bó nóc buộc mây), đầu hồi lá
#  - ít đồ, đồ TO: lu nước nắp gỗ + gáo (lò bánh), chõng ống tre + nón lá, ô lồng cá có lan can tre, giỏ cá,
#    đèn dầu treo cột, 2 cọc tràm neo bè có quấn dây, thang tre xuống nước
#   python3 benoi3d.py prev OUT.png [n]
import math, sys, os
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
for d in ('lobanh', 'coixay', 'lobanhmi', 'chuongga', 'benghe', 'kho'):
    sys.path.insert(0, os.path.join(HERE, '..', d))
import lobanh3d as LQ                        # kéo theo coixay (CX), chuồng (CG), bến ghe (BG), lò bánh mì (LB), kho (K)
import coixay3d as CX
import chuongga3d as CG
import benghe3d as BG
import lobanhmi3d as LB
import kho3d as K
from kho3d import (W3, T, Scene, X3, hexc, smooth, vnoise, hash1, plane, tube, disc, lathe, MATS, mat_flat,
                   M_BAMBOO, M_OLDBAMBOO, M_WEAVE_F, M_WEAVE_R, M_GABLE, M_INSIDE, M_RATTAN, M_SOOT, M_THEND)

P = W3
ctube = CX.ctube
M_TRAM, M_TCUT, M_ROPE, M_DECK, M_RIP = CG.M_TRAM, CG.M_TCUT, BG.M_ROPE, BG.M_DECK, BG.M_RIP

# ------------------------------------------------------------------ sheet / camera (2x2 ô, gốc = góc sau, tâm màn = tâm chân)
K.BB = (-86, -96, 86, 48)
K.OX, K.OY = 0, -32
K.SHEET = 'benoi.webp'
K.SEED = 9925
K.PXU = int(os.environ.get('BE_PXU', '9'))
K.GS_K, K.FOOT_K = 0.22, 0.16
K.GROUND_SHADOW = True
K.NOSHADOW = set()
K.PATCH = None
K.ZF = 0.0
K.INSIDE_K = 0.3
K.FOOT = (0.05, 1.95, 0.05, 1.95, 0.04)
BG.D = 0

# ------------------------------------------------------------------ layout (ô / đơn vị)
PR, PZ = 4.8, 1.1                              # phuy: bán kính, tâm trên mặt nước
ZB = PZ + PR + 0.85                            # tâm đà tràm
ZD = ZB + 0.85 + 1.15                          # mặt sàn tre
ROWS = (0.2, 0.72, 1.3, 1.8)                   # hàng phuy (v)
BEAMS = (0.1, 0.62, 1.14, 1.74, 1.9)           # đà tràm (u)
HO = (1.2, 1.68, 1.16, 1.62)                   # ô lồng cá u0 u1 v0 v1
HU0, HU1, HV0, HV1 = 0.14, 1.12, 0.14, 0.96    # chòi
ZW = ZD + 24.0                                 # đầu vách
DU0, DU1, DZ = 0.46, 0.78, ZD + 18.0           # cửa
WN = (0.4, 0.7, ZD + 9.5, ZD + 18.0)           # cửa sổ vách phải v0 v1 z0 z1
K.ZW = ZW
K.WU0, K.WU1, K.WV0, K.WV1 = HU0, HU1, HV0, HV1
K.RU0, K.RU1 = HU0 - 0.14, HU1 + 0.16          # mái: đầu mái (u)
K.RV, K.RZ = (HV0 + HV1) / 2, ZW + 13.0        # nóc
K.EV, K.EZ = HV1 + 0.15, ZW - 2.4               # diềm trước
K.BV, K.BZ = HV0 - 0.15, ZW - 2.4               # diềm sau
K.SMOKE_U = -9.0
K.RIDGE_R, K.BATTEN_R, K.POLE_R, K.TIE_R = 2.1, 0.6, 0.4, 0.22
LAMP = (HU1 + 0.13, HV1 + 0.02, ZD + 13.0)


def zroof(v):
    if v >= K.RV: return K.EZ + (K.RZ - K.EZ) * (K.EV - v) / (K.EV - K.RV)
    return K.BZ + (K.RZ - K.BZ) * (v - K.BV) / (K.RV - K.BV)


# ------------------------------------------------------------------ materials
def mat_phuy(uv, prm, pos, nrm):
    """phuy sắt cũ sơn xanh: sơn bạc nắng, loang gỉ, 2 gân nổi, chân ướt sẫm + rong sát mặt nước (không bóng)"""
    L, A = uv[:, 0], uv[:, 1]; s = prm[:, 0]; z = pos[:, 2]
    n1 = vnoise(L * 0.22 + s * 17, A * 5.0, 3.0); n2 = vnoise(L * 1.1 + s * 5, A * 21.0, 7.0)
    col = hexc('#3d6682')[None] * (0.86 + 0.2 * n1 + 0.06 * n2)[:, None]
    sun = smooth(PZ + 1.5, PZ + PR, z)                                  # lưng phuy bạc màu
    col = col * (1 - 0.2 * sun)[:, None] + hexc('#86a2b0')[None] * (0.2 * sun)[:, None]
    f = L / np.maximum(prm[:, 1], 1e-6)
    rib = np.exp(-((f - 0.3) / 0.022) ** 2) + np.exp(-((f - 0.7) / 0.022) ** 2)
    col = col * (1 - 0.2 * rib)[:, None]
    rust = smooth(0.6, 0.78, vnoise(L * 0.5 + s * 9, A * 9.0 + s * 3, 11.0)) * 0.75
    rust = np.clip(rust + 0.5 * rib * smooth(0.4, 0.7, n2) + 0.5 * smooth(0.06, 0.0, np.minimum(f, 1 - f)), 0, 0.85)
    col = col * (1 - rust)[:, None] + hexc('#8e5a36')[None] * ((0.85 + 0.3 * n2) * rust)[:, None]
    wet = 1 - smooth(0.5, 2.0 + 0.8 * vnoise(L * 0.4, s * 9, 2.0), z)
    col = col * (1 - 0.42 * wet)[:, None] + hexc('#3c4a30')[None] * (0.16 * wet)[:, None]
    return np.clip(col, 0, 1), nrm


def mat_phuycap(uv, prm, pos, nrm):
    """đáy phuy: vành gỉ, tâm sơn xanh cũ, nút phuy"""
    y, z = pos[:, 1] - prm[:, 1], pos[:, 2] - PZ; r = np.hypot(y, z) / PR; s = prm[:, 0]
    n = vnoise(y * 0.8 + s * 7, z * 0.8, 5.0)
    col = hexc('#3a607a')[None] * (0.84 + 0.2 * n)[:, None]
    ring = np.exp(-((r - 0.62) / 0.03) ** 2) * 0.16 + np.exp(-((r - 0.3) / 0.03) ** 2) * 0.1
    col = col * (1 - ring)[:, None]
    rust = np.clip(smooth(0.86, 0.97, r) + smooth(0.62, 0.8, n) * 0.6, 0, 0.85)
    col = col * (1 - rust)[:, None] + hexc('#86522f')[None] * rust[:, None]
    bung = (np.hypot(y - PR * 0.45, z - PR * 0.3) < 0.55)
    col = np.where(bung[:, None], hexc('#2b2a28')[None] * np.ones_like(col), col)
    wet = 1 - smooth(0.5, 2.0, pos[:, 2])
    col = col * (1 - 0.42 * wet)[:, None] + hexc('#3c4a30')[None] * (0.16 * wet)[:, None]
    return np.clip(col, 0, 1), nrm


def mat_luoi(uv, prm, pos, nrm):
    return np.tile(hexc('#4d5a48')[None], (len(uv), 1)), nrm


M_PHUY, M_PHUYCAP, M_LUOI = 880, 881, 882
MATS.update({M_PHUY: mat_phuy, M_PHUYCAP: mat_phuycap, M_LUOI: mat_luoi})
K.NORECV = getattr(K, 'NORECV', set()) | {M_RIP}


# ------------------------------------------------------------------ parts
def rip_line(S, p0, p1, n=None):
    """vệt nước nhạt mảnh quanh vật nằm trên nước (như vòng gợn quanh cột bến ghe), đứt đoạn"""
    p0 = np.asarray(p0, float); p1 = np.asarray(p1, float); L = np.linalg.norm(p1 - p0); n = n or max(2, int(L / 2.2))
    tube(S, p0, p1, 0.17, M_RIP, nr=3, nl=max(2, n))


def phuy(S, rng, u0, u1, v):
    x0, x1, y = u0 * T, u1 * T, v * T; L = x1 - x0; th0 = -math.asin(PZ / PR); s = rng.random()
    def F(U, V):
        th = th0 + V * (math.pi - 2 * th0); f = U / L
        rr = PR * (1 + 0.035 * (np.exp(-((f - 0.3) / 0.02) ** 2) + np.exp(-((f - 0.7) / 0.02) ** 2)) + 0.02 * (np.exp(-(f / 0.02) ** 2) + np.exp(-((1 - f) / 0.02) ** 2)))
        return np.stack([x0 + U, y + rr * np.cos(th), PZ + rr * np.sin(th)], -1)
    S.grid(F, 44, 18, M_PHUY, (s, L, 0), 0.0, uvr=((0, L), (0, 1)))
    for xe in (x0 + 0.45, x1 - 0.45):
        def Fc(U, V, xe=xe):
            th = th0 + V * (math.pi - 2 * th0)
            return np.stack([np.full_like(U, xe), y + U * PR * np.cos(th), U * (PZ + PR * np.sin(th))], -1)
        S.grid(Fc, 6, 18, M_PHUYCAP, (s, y, 0), 0.0, uvr=((0, 1), (0, 1)))
    w = PR * math.cos(th0) + 0.5
    for sg in (-1, 1): rip_line(S, (x0, y + sg * w, 0.12), (x1, y + sg * w, 0.12))
    rip_line(S, (x1 + 0.4, y - w, 0.12), (x1 + 0.4, y + w, 0.12), n=4)


def floats(S, rng):
    for v in ROWS:
        segs = ((0.08, 0.66), (0.71, 1.29), (1.34, 1.92)) if v != ROWS[2] else ((0.08, 0.54), (0.59, 1.08))
        for (a, b) in segs: phuy(S, rng, a, b, v)
    for u in BEAMS:                                             # đà tràm gác ngang các hàng phuy
        ctube(S, P(u, 0.03, ZB), P(u, 1.97, ZB + 0.1 * (rng.random() - 0.5)), 0.85, M_TRAM, prm=(rng.random(), 0, 0), nr=8, nl=14)
    for v in (ROWS[0], ROWS[3]):                                # dây buộc phuy vào đà (mây) ở 2 hàng ngoài
        for u in BEAMS[:1] + BEAMS[1:4]:
            c = P(u, v, 0)
            for k in range(8):
                a0 = 0.15 + k * (math.pi - 0.3) / 8; a1 = a0 + (math.pi - 0.3) / 8
                rr = PR + 0.3
                tube(S, (c[0] + 0.9, c[1] + rr * math.cos(a0), PZ + rr * math.sin(a0)), (c[0] + 0.9, c[1] + rr * math.cos(a1), PZ + rr * math.sin(a1)), 0.2, M_ROPE, nr=4, nl=2)


def deck(S, rng):
    """sàn: từng ống tre tròn nằm dọc u, mỗi ống dài ngắn khác nhau chút (như bến ghe); chừa ô lồng cá"""
    step = 1.3 / T; v = 0.045
    while v < 1.96:
        a0 = 0.035 - 0.03 * rng.random(); a1 = 1.965 + 0.03 * rng.random()
        r = 0.6 + 0.12 * (rng.random() - 0.5); dz = 0.16 * (rng.random() - 0.5); zc = ZD - 0.55
        segs = [(a0, a1)]
        if HO[2] - 0.005 < v < HO[3] + 0.005: segs = [(a0, HO[0]), (HO[1], a1)]
        for (b0, b1) in segs:
            tube(S, P(b0, v, zc + dz), P(b1, v + 0.004 * (rng.random() - 0.5), zc - dz), r, M_DECK, prm=(rng.random(), rng.random(), 0), nr=6, nl=max(4, int((b1 - b0) * 6)))
            for b in (b0, b1): disc(S, P(b, v, zc), (1 if b == b1 else -1, 0, 0), r, M_TCUT, nr=2, na=8)
        v += step * (0.94 + 0.12 * rng.random())
    for u in BEAMS:                                             # nút mây buộc sàn vào đà
        for vv in np.arange(0.18, 1.9, 0.29):
            if HU0 < u < HU1 and HV0 < vv < HV1: continue
            if HO[0] - 0.02 < u < HO[1] + 0.02 and HO[2] - 0.02 < vv < HO[3] + 0.02: continue
            X3.ellipsoid(S, P(u, vv, ZD + 0.05), 0.45, 0.45, 0.45, M_RATTAN, nu=4, nvv=5)


def long_ca(S, rng):
    """ô lồng cá: khung tre quanh miệng ô, 4 trụ tràm thấp + lan can tre, lưới thả xuống nước"""
    u0, u1, v0, v1 = HO
    z = ZD + 0.55
    ctube(S, P(u0 - 0.04, v0, z), P(u1 + 0.04, v0, z), 0.75, M_BAMBOO, prm=(rng.random(), 0.2, 0), nr=8, nl=8)
    ctube(S, P(u0 - 0.04, v1, z), P(u1 + 0.04, v1, z), 0.75, M_BAMBOO, prm=(rng.random(), 0.6, 0), nr=8, nl=8)
    ctube(S, P(u0, v0 - 0.04, z + 0.9), P(u0, v1 + 0.04, z + 0.9), 0.7, M_BAMBOO, prm=(rng.random(), 0.4, 0), nr=8, nl=8)
    ctube(S, P(u1, v0 - 0.04, z + 0.9), P(u1, v1 + 0.04, z + 0.9), 0.7, M_BAMBOO, prm=(rng.random(), 0.8, 0), nr=8, nl=8)
    for (u, v) in ((u0, v0), (u1, v0), (u0, v1), (u1, v1)):
        CG.lash(S, P(u, v, z + 0.5), 0.95)
    # lưới: 2 vách trong (phía xa máy) thả từ khung xuống nước, mắt lưới quả trám
    for (pa, pb) in ((P(u0 + 0.01, v0, 0), P(u1 - 0.01, v0, 0)), (P(u0, v0 + 0.01, 0), P(u0, v1 - 0.01, 0))):
        Lw = np.linalg.norm(pb - pa); d = (pb - pa) / Lw; H = ZD - 1.2; n = int(Lw / 2.4)
        for k in range(-int(H / 2.4) - 1, n + 1):
            for sg in (1, -1):
                a = k * 2.4 if sg == 1 else k * 2.4 + H; b = a + sg * H
                t0, t1 = 0.0, 1.0
                if a < 0: t0 = -a / (b - a)
                if b < 0: t1 = -a / (b - a)
                if a > Lw: t0 = (Lw - a) / (b - a)
                if b > Lw: t1 = (Lw - a) / (b - a)
                if t1 - t0 < 0.05: continue
                q0 = pa + d * (a + (b - a) * t0) + np.array([0, 0, H * t0 + 0.2]); q1 = pa + d * (a + (b - a) * t1) + np.array([0, 0, H * t1 + 0.2])
                tube(S, q0, q1, 0.14, M_LUOI, nr=3, nl=2)
    for (pa, pb) in ((P(u0, v0, 0.12), P(u1, v0, 0.12)), (P(u0, v0, 0.12), P(u0, v1, 0.12))): rip_line(S, pa, pb)


def hut(S, rng):
    """chòi lá: cột tràm, vách phên tre đan + nẹp, cửa + cửa sổ song tre, đầu hồi lá, mái lá K.roof"""
    def bam(a, b, r, nl=8):
        tube(S, a, b, r, M_BAMBOO, prm=(rng.random(), rng.random(), 0), nr=8, nl=nl)
    e = 0.012
    def pf(u0, u1, z0, z1):
        plane(S, P(u0, HV1 - e, z0), P(u1, 0, 0) - P(u0, 0, 0), np.array([0, 0, z1 - z0]), max(2, int((u1 - u0) * 24)), max(2, int((z1 - z0) / 1.5)), M_WEAVE_F)
    def pr(v0, v1, z0, z1):
        plane(S, P(HU1 - e, v1, z0), P(0, v0, 0) - P(0, v1, 0), np.array([0, 0, z1 - z0]), max(2, int((v1 - v0) * 24)), max(2, int((z1 - z0) / 1.5)), M_WEAVE_R)
    pf(HU0, DU0, ZD, ZW); pf(DU1, HU1, ZD, ZW); pf(DU0, DU1, DZ, ZW)
    pr(HV0, WN[0], ZD, ZW); pr(WN[1], HV1, ZD, ZW); pr(WN[0], WN[1], ZD, WN[2]); pr(WN[0], WN[1], WN[3], ZW)
    plane(S, P(HU0 + e, HV1, ZD), P(0, HV0, 0) - P(0, HV1, 0), np.array([0, 0, ZW - ZD]), 24, 16, M_WEAVE_R)
    plane(S, P(HU0, HV0 + e, ZD), P(HU1, 0, 0) - P(HU0, 0, 0), np.array([0, 0, ZW - ZD]), 28, 16, M_WEAVE_F)
    plane(S, P(DU0 - 0.5, HV1 - 0.34, ZD), P(DU1 + 0.06, 0, 0) - P(DU0 - 0.5, 0, 0), np.array([0, 0, DZ + 1 - ZD]), 6, 6, M_INSIDE)   # trong nhà tối
    plane(S, P(HU1 - 0.34, WN[1] + 0.06, WN[2] - 9), P(0, WN[0] - 0.5, 0) - P(0, WN[1] + 0.06, 0), np.array([0, 0, WN[3] - WN[2] + 10]), 6, 6, M_INSIDE)
    def gF(U, Vv):                                              # đầu hồi lá (vách phải)
        v = HV0 + U / T; zt = np.array([zroof(x) for x in v.ravel()]).reshape(v.shape) - 2.2
        return np.stack([np.full_like(U, HU1 * T + 0.35), v * T, ZW + Vv * (zt - ZW)], -1)
    S.grid(gF, 50, 12, M_GABLE, (0, 0, 0), 0.0, uvr=((0, (HV1 - HV0) * T), (0, 1)))
    for (u, v) in ((HU0, HV1), (HU1, HV1), (HU1, HV0), (HU0, HV0)):          # cột tràm tròn
        tube(S, P(u, v, ZD - 0.3), P(u, v, ZW + 1.4), 1.5, M_TRAM, prm=(rng.random(), 0, 0), nr=10, nl=10, taper=0.9)
    bam(P(HU0 - 0.06, HV1, ZW), P(HU1 + 0.07, HV1, ZW), 1.05, nl=14)          # xà đầu vách
    bam(P(HU1, HV0 - 0.06, ZW - 0.5), P(HU1, HV1 + 0.07, ZW - 0.5), 1.05, nl=12)
    for (u0, u1) in ((HU0, DU0), (DU1, HU1)):
        bam(P(u0, HV1 + 0.004, ZD + 0.9), P(u1, HV1 + 0.004, ZD + 0.9), 0.8, nl=6)
        for z in (ZD + 9.0, ZD + 17.0): bam(P(u0, HV1 + 0.006, z), P(u1, HV1 + 0.006, z), 0.5, nl=6)       # nẹp tre giữ phên
    bam(P(HU1 + 0.004, HV0, ZD + 0.9), P(HU1 + 0.004, HV1, ZD + 0.9), 0.8, nl=10)
    bam(P(HU1 + 0.006, HV0, ZD + 4.6), P(HU1 + 0.006, HV1, ZD + 4.6), 0.5, nl=8)
    bam(P(HU1 + 0.006, HV0, ZD + 21.5), P(HU1 + 0.006, HV1, ZD + 21.5), 0.5, nl=8)
    for u in (DU0, DU1): bam(P(u, HV1 + 0.01, ZD - 0.2), P(u, HV1 + 0.01, DZ + 2.0), 1.0, nl=8)   # khung cửa
    bam(P(DU0 - 0.05, HV1 + 0.012, DZ + 0.5), P(DU1 + 0.05, HV1 + 0.012, DZ + 0.5), 0.95, nl=6)
    a, b, z0, z1 = WN                                           # cửa sổ: khung + song tre
    for v in (a, b): bam(P(HU1 + 0.008, v, z0 - 1.3), P(HU1 + 0.008, v, z1 + 1.3), 0.7, nl=4)
    for z in (z0 - 0.5, z1 + 0.5): bam(P(HU1 + 0.008, a - 0.04, z), P(HU1 + 0.008, b + 0.04, z), 0.7, nl=4)
    for i in range(1, 5):
        v = a + (b - a) * i / 5
        bam(P(HU1 - 0.002, v, z0), P(HU1 - 0.002, v, z1), 0.45, nl=3)
    K.roof(S, rng, 0)
    for u in (HU0, HU1):                                        # kèo tre lộ ra dưới diềm trước
        tube(S, P(u, K.EV - 0.02, K.EZ - 2.6), P(u, K.RV, K.RZ - 2.9), 0.55, M_OLDBAMBOO, prm=(rng.random(), 0.5, 0), nr=6, nl=6)
    # đèn dầu treo cột trước-phải (chuẩn xưởng)
    tube(S, P(HU1, HV1, LAMP[2] + 5.4), P(LAMP[0], LAMP[1], LAMP[2] + 5.8), 0.3, M_BAMBOO, nr=6, nl=2)
    tube(S, P(LAMP[0], LAMP[1], LAMP[2] + 5.6), P(LAMP[0], LAMP[1], LAMP[2] + 2.4), 0.14, M_SOOT, nr=4, nl=2)
    K.hlamp(S, P(*LAMP))


def lu(S, rng):
    """lu nước của lò bánh quê (nắp gỗ + thanh gác + gáo dừa), dời ra sàn bè cạnh chòi"""
    old = LQ.P; c = (1.52, 0.44)
    LQ.P = lambda u, v, z: W3(u - 1.66 + c[0], v - 1.12 + c[1], z - 0.4 + ZD + 0.05)
    try: LQ.lu_nuoc(S, rng)
    finally: LQ.P = old


def chong(S, rng):
    """chõng tre: mặt = ống tre tròn nằm sát nhau (chuẩn bàn ghế xưởng), 4 chân tre; nón lá cũ để trên"""
    u0, u1, v0, v1 = 0.2, 0.8, 1.32, 1.68; zt = ZD + 6.6; r = 0.62
    n = int(round((v1 - v0) * T / (2 * r)))
    for k in range(n):
        v = v0 + (v1 - v0) * (k + 0.5) / n
        ctube(S, P(u0 - 0.01, v, zt - r), P(u1 + 0.01, v, zt - r), r, M_OLDBAMBOO, prm=(rng.random(), 0.4, 0), nr=8, nl=7)
    for u in (u0 + 0.05, u1 - 0.05):
        ctube(S, P(u, v0 - 0.01, zt - 2 * r - 0.5), P(u, v1 + 0.01, zt - 2 * r - 0.5), 0.55, M_OLDBAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=4)
        for v in (v0 + 0.03, v1 - 0.03):
            ctube(S, P(u, v, ZD - 0.1), P(u, v, zt - 2 * r - 0.2), 0.75, M_BAMBOO, prm=(rng.random(), 0.3, 0), nr=8, nl=4)
            CG.lash(S, P(u, v, zt - 2 * r - 0.5), 0.85)
    for v in (v0 + 0.03, v1 - 0.03):
        ctube(S, P(u0 + 0.05, v, ZD + 2.2), P(u1 - 0.05, v, ZD + 2.2), 0.45, M_OLDBAMBOO, prm=(rng.random(), 0.4, 0), nr=6, nl=5)
    lathe(S, P(0.62, 1.5, zt + 0.05), [(0, 4.3), (0.25, 4.0), (2.9, 0.25), (3.05, 0.0)], BG.M_NON, na=28)


def gio(S, rng):
    gc = P(1.0, 1.8, ZD + 0.1); k = 1.15
    lathe(S, gc, [(0, 1.5 * k), (0.5 * k, 2.5 * k), (2.4 * k, 2.9 * k), (3.8 * k, 1.7 * k), (4.4 * k, 1.3 * k), (5.0 * k, 1.7 * k), (5.2 * k, 1.85 * k)], BG.M_GIO, na=22)
    disc(S, gc + np.array([0, 0, 4.9 * k]), (0, 0, 1), 1.45 * k, BG.M_DARK, nr=2, na=14)
    lathe(S, gc + np.array([0, 0, 4.95 * k]), [(0, 1.8 * k), (0.3 * k, 1.9 * k), (0.5 * k, 1.8 * k)], M_RATTAN, na=16)


def neo(S, rng):
    """2 cọc tràm cắm dưới sông neo bè, quấn dây, dây chùng nối vào đà; thang tre xuống nước"""
    m1 = BG.post(S, rng, -0.1, 1.84, 25.0, r=1.5); BG.wind(S, m1 - np.array([0, 0, 25.0 - 15.0]), 1.7, 0, 4)
    m2 = BG.post(S, rng, 1.84, -0.1, 22.0, r=1.5); BG.wind(S, m2 - np.array([0, 0, 22.0 - 13.0]), 1.7, 0, 3)
    BG.rope(S, m1 - np.array([0, 0, 25.0 - 15.6]), P(0.1, 1.97, ZB + 0.6), 1.6, r=0.3, n=8)
    BG.rope(S, m2 - np.array([0, 0, 22.0 - 13.6]), P(1.9, 0.03, ZB + 0.9), 1.4, r=0.3, n=8)
    BG.wind(S, P(0.1, 1.9, ZB - 0.85), 0.0, 0, 0)
    for v in (0.92, 1.1):                                       # thang tre ở mép phải
        tube(S, P(2.0, v, 0.0), P(1.985, v, ZD + 5.0), 0.6, M_DECK, prm=(rng.random(), 0.5, 0), nr=7, nl=6)
        BG.ripple(S, P(2.0, v, 0.0), 1.2, n=10)
    for z in (2.6, 5.4, 8.6):
        tube(S, P(2.0, 0.89, z), P(2.0, 1.13, z + 0.1), 0.48, M_DECK, prm=(rng.random(), 0.4, 0), nr=6, nl=3)
        for v in (0.92, 1.1): CG.lash(S, P(2.0, v, z), 0.7)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear(); K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
    K.LIGHTS2.append((P(*LAMP) + np.array([0, 0, 5.2 - 22.9 * LB.DD_V]), hexc('#ff9645'), 15.0, 2.1, 'out'))
    K.GLOWS[:] = [(P(*LAMP), 0.2, 0.0)]
    for i_, f_ in enumerate((floats, deck, long_ca, hut, lu, chong, gio, neo)):
        f_(S, np.random.default_rng(K.SEED + 101 * i_))
    return S, (S.ns, S.ns)


K.build = build

if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        n = 'n' in sys.argv[3:]
        K.render(1, n, 'b', ss=int(os.environ.get('BE_SS', '2'))).save(sys.argv[2])
