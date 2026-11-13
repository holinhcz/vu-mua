# The Hoa cỏ plants of v760 rebuilt for the per-pixel renderer (pxr.py, materials vat.py).
# Big kinds (one tile, KU 29*1.12): cc_bong_trang, cc_lai, cc_huong_duong, cc_luoi_ho, cc_nha_dam, cc_xuong_rong, cc_sa
# Small kinds (quarter tile, KU 58): h_da_yen, h_mai_dia, h_mong_tay, h_cuc_la_nho, k_ot, k_hung_que, k_lan_chi
import math, sys, os
import numpy as np
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import pxr
from pxr import Scene, leaf, tube, ellipsoid, disc, petal, basis, frame_of, UP, nv
from vat import *
from chuoi import TOCAM, LIGHT

BIG = ['cc_bong_trang', 'cc_lai', 'cc_huong_duong', 'cc_luoi_ho', 'cc_nha_dam', 'cc_xuong_rong', 'cc_sa']
SMALL = ['h_da_yen', 'h_mai_dia', 'h_mong_tay', 'h_cuc_la_nho', 'k_ot', 'k_hung_que', 'k_lan_chi',
         'c_xanh', 'c_lau', 'bui_la', 'h_cuc_vang', 'h_cuc_trang', 'h_muoi_gio', 'h_sao_nhai', 'h_dua_can', 'h_tim',
         'h_ngu_sac', 'h_mong_ga', 'h_van_tho']
KU_BIG = 29.0 * 1.12
KU_SMALL = 58.0
TOON = True     # v827 (Link): the 3D shapes, painted as 2D cel (flat tones, outline, round ground shadow)
BB_BIG = (-58, -118, 58, 26)
BB_SMALL = (-22, -76, 22, 10)
BB_KIND = {'c_lau': (-22, -76, 40, 10), 'h_sao_nhai': (-22, -76, 34, 10)}


def rng_for(kind, seed):
    return np.random.default_rng((BIG + SMALL).index(kind) * 7919 + seed * 104729 + 3)


def fib_dirs(n, zmin=-0.5):
    ga = math.pi * (3 - math.sqrt(5)); out = []
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        if z < zmin: continue
        r = math.sqrt(max(0, 1 - z * z)); out.append(np.array([r * math.cos(i * ga), r * math.sin(i * ga), z]))
    return out


# ------------------------------------------------------------------ a shrub dome (bông trang, lài)
class Dome:
    def __init__(self, r, ra, ry, rb, lift=0.12):
        self.ra, self.ry, self.rb = ra, ry, rb
        self.ce = np.array([r.uniform(-0.03, 0.03), r.uniform(-0.03, 0.03), rb * 0.72 + lift])
        self.lumps = [(nv(r.normal(0, 1, 3)), r.uniform(1.6, 2.6), r.uniform(0, 6.28), r.uniform(0.05, 0.09)) for _ in range(5)]

    def lump(self, d):
        return 1.0 + sum(a * math.cos(fr * (d @ kk) * math.pi + ph) for kk, fr, ph, a in self.lumps)

    def env(self, d, f=1.0):
        return self.ce + np.array([d[0] * self.ra, d[1] * self.ry, d[2] * self.rb]) * f * self.lump(d)

    def normal(self, p):
        return nv((p - self.ce) / np.array([self.ra, self.ry, self.rb]) ** 2)


def shrub(S, r, D, nclu, leafL, leafW, style, prof, pairs=True, stems=5):
    # woody stems out of the ground into the dome
    for k in range(stems):
        az = r.uniform(0, 2 * math.pi); A = np.array([math.cos(az), math.sin(az), 0])
        p = A * r.uniform(0.02, 0.07); d = nv(UP + A * r.uniform(0.4, 0.8)); pts = [p]
        for j in range(6):
            d = nv(d + r.normal(0, 0.12, 3) + UP * 0.05); pts.append(pts[-1] + d * 0.1)
        tube(S, pts, 0.026, 0.012, STEM, (1, r.uniform(), 0), ao=0.5)
    # the inner mass the gaps show
    ellipsoid(S, D.ce, D.ra * 0.84, D.ry * 0.84, D.rb * 0.84, INNER, (0, 0, 0), ao=0.75, zmin=0.18, nu=12, nvv=24)
    spots = []
    for d in fib_dirs(nclu):
        f = r.uniform(0.93, 1.04) if r.uniform() < 0.6 else r.uniform(0.78, 0.9)
        c = D.env(d, f); ns = D.normal(c)
        if ns @ TOCAM < -0.35: continue          # never seen
        spots.append((c, ns, f))
        nrm0 = nv(ns + UP * 0.8)
        t1 = np.cross(nrm0, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0]); t2 = np.cross(nrm0, t1)
        az0 = r.uniform(0, 2 * math.pi)
        nl = int(r.integers(4, 7)) if pairs else int(r.integers(4, 7))
        inner = max(0.0, min(0.7, (1.0 - f) * 3.5))
        for k in range(nl):
            az = az0 + k * 2 * math.pi / nl + r.normal(0, 0.18)
            A = math.cos(az) * t1 + math.sin(az) * t2
            el = r.uniform(0.0, 0.45)
            ld = nv(A * math.cos(el) + nrm0 * math.sin(el) - UP * 0.12)
            L = leafL * r.uniform(0.85, 1.12)
            leaf(S, c + ld * 0.015, ld, L, L * leafW, droop=0.18, prof=prof, fold=0.28, curl=0.04,
                 twist=r.normal(0, 0.25), mat=LEAF, prm=(style, r.uniform(), 0), ao=inner, nu=9, nvv=5)
    return spots


def pick_spots(spots, n, gap, r, zmin=0.2, vmin=0.05):
    cand = [(s[1] @ TOCAM * 0.6 + r.uniform(0, 0.7), s) for s in spots if s[1] @ TOCAM > vmin and s[0][2] > zmin and s[2] > 0.92]
    cand.sort(key=lambda z: -z[0]); out = []
    for _, s in cand:
        if len(out) >= n: break
        sp = np.array([s[0][0], 0.5 * s[0][1] - 0.866 * s[0][2]])
        if any(np.linalg.norm(sp - q) < gap for q, _ in out): continue
        out.append((sp, s))
    return [s for _, s in out]


def b_bong_trang(S, r, seed):
    D = Dome(r, *[(1.0, 0.92, 0.64), (0.92, 0.92, 0.7), (1.04, 0.94, 0.6), (0.96, 0.92, 0.66)][seed % 4])
    prof = [(0.0, 0.12), (0.1, 0.55), (0.25, 0.86), (0.45, 1.0), (0.65, 0.92), (0.82, 0.62), (0.94, 0.28), (1.0, 0.0)]
    spots = shrub(S, r, D, 320, 0.2, 0.36, 1, prof)
    col = seed % 4
    for c, ns, f in pick_spots(spots, [10, 11, 10, 12][seed % 4], 0.38, r):
        fdir = nv(ns + UP * 1.1 + r.normal(0, 0.12, 3))
        rc = 0.17 * r.uniform(0.9, 1.1)
        cc = c + ns * 0.04 + fdir * 0.02
        u, v = basis(fdir)
        # the ball's body: tubes of the florets, deep colour
        ellipsoid(S, cc, rc * 0.78, rc * 0.78, rc * 0.4, PETAL, (col, 0.1, 0), ao=0.75,
                  axes=(u, v, fdir), zmin=0.3)
        m = 30; ga = math.pi * (3 - math.sqrt(5))
        for i in range(m):
            t = (i + 0.5) / m
            th = math.acos(1 - t * (1 - math.cos(math.radians(80))))
            ph = i * ga
            d = math.cos(th) * fdir + math.sin(th) * (math.cos(ph) * u + math.sin(ph) * v)
            if d @ TOCAM < -0.25: continue
            q = cc + d * rc * 0.62 + fdir * rc * 0.1
            fd = nv(d + fdir * 0.5)
            a0 = r.uniform(0, 6.28)
            R = 0.06 * r.uniform(0.9, 1.08)
            for k in range(4):
                petal(S, q, fd, a0 + k * math.pi / 2, R, R * 0.62, cup=-0.05, mat=PETAL, prm=(col, r.uniform(), 0),
                      prof=[(0, 0.15), (0.3, 0.8), (0.6, 1.0), (0.85, 0.65), (1.0, 0.05)], nu=5, nvv=3, ao=0.15 * th)
        for k in range(5):     # unopened buds in the middle
            a = r.uniform(0, 6.28); q = cc + fdir * rc * 0.62 + (math.cos(a) * u + math.sin(a) * v) * rc * 0.25
            ellipsoid(S, q, 0.012, 0.012, 0.02, PETAL, (col, 0.0, 0), axes=(u, v, fdir), nu=5, nvv=8)
    return 0.95


def b_lai(S, r, seed):
    D = Dome(r, *[(0.9, 0.94, 0.6), (0.84, 1.0, 0.66), (0.95, 0.9, 0.56), (0.88, 0.96, 0.62)][seed % 4])
    prof = [(0.0, 0.15), (0.12, 0.6), (0.3, 0.92), (0.48, 1.0), (0.66, 0.86), (0.84, 0.5), (1.0, 0.0)]
    spots = shrub(S, r, D, 300, 0.17, 0.6, 2, prof)
    for c, ns, f in pick_spots(spots, [15, 17, 16, 18][seed % 4], 0.24, r, zmin=0.15, vmin=0.0):
        f0 = nv(ns + UP * 0.8); u, v = basis(f0)
        for j in range(int(r.integers(1, 4))):
            a = r.uniform(0, 6.28); q = c + ns * 0.05 + (math.cos(a) * u + math.sin(a) * v) * (0.05 if j else 0)
            fd = nv(f0 + (math.cos(a) * u + math.sin(a) * v) * 0.35 + r.normal(0, 0.12, 3))
            if j == 2 or (j == 1 and r.uniform() < 0.35):
                bu, bv = basis(fd)
                ellipsoid(S, q + fd * 0.03, 0.02, 0.02, 0.042, WHITE, (0, 0, 0), axes=(bu, bv, fd), nu=6, nvv=10)
                continue
            a0 = r.uniform(0, 6.28)
            for ly, (R, cup, n) in enumerate(((0.075, 0.25, 8), (0.055, 0.6, 7), (0.035, 1.0, 5))):
                for k in range(n):
                    petal(S, q + fd * 0.008 * ly, fd, a0 + (k + 0.5 * ly) * 2 * math.pi / n, R, R * 0.62, cup=cup,
                          mat=PETAL, prm=(4, r.uniform(), 0), nu=5, nvv=3, ao=0.15 * ly)
    return 0.9


def b_huong_duong(S, r, seed):
    n = [5, 4, 6, 5][seed % 4]
    pos = [(0.0, 0.0)] + [(math.cos(a) * 0.3 * r.uniform(0.8, 1.2), math.sin(a) * 0.26 * r.uniform(0.8, 1.2))
                          for a in np.linspace(0, 2 * math.pi, n - 1, endpoint=False) + r.uniform(0, 6.28)]
    sun = nv(np.array([-0.45, 0.8, 0.38]))
    for k, (x, y) in enumerate(pos):
        H = r.uniform(1.55, 2.05) * (1.06 if y < 0 else 0.94)
        base = np.array([x, y, 0.0]); top = base + np.array([r.normal(0, 0.05), r.normal(0, 0.05), H])
        mid = (base + top) / 2 + np.array([r.normal(0, 0.04), r.normal(0, 0.04), 0])
        pts = [(1 - t) ** 2 * base + 2 * (1 - t) * t * mid + t * t * top for t in np.linspace(0, 1, 12)]
        tube(S, pts, 0.03, 0.018, STEM, (0, r.uniform(), 0), nr=8)
        for j in range(9):
            s = 0.12 + 0.09 * j; q = pts[int(s * 11)]
            az = j * 2.4 + k
            d = np.array([math.cos(az), math.sin(az), 0.25])
            L = 0.3 * (1.2 - 0.6 * s)
            leaf(S, q, d, L, L * 0.85, droop=0.55, fold=0.12, sag=0.2, mat=LEAF, prm=(7, r.uniform(), 0),
                 prof=[(0, 0.05), (0.08, 0.5), (0.25, 0.95), (0.42, 1.0), (0.65, 0.78), (0.85, 0.4), (1, 0)], nu=10, nvv=7,
                 ao=0.3 * (1 - s))
        f = nv(sun + r.normal(0, 0.12, 3) - UP * 0.15 * r.uniform())
        Rh = 0.13 * r.uniform(0.85, 1.1)
        hc = top + f * 0.03
        u, v = basis(f)
        disc(S, hc - f * 0.03, -f, Rh * 0.9, LEAF, (7, 0.2, 0), dome=0.35)        # the green back
        disc(S, hc, f, Rh, DISC, (0, 0, 0), dome=0.12, nr=10, na=40)
        for ly, (R, tilt) in enumerate(((0.12, -0.05), (0.105, 0.05))):
            for i in range(21):
                a = (i + 0.5 * ly) * 2 * math.pi / 21 + r.normal(0, 0.05)
                e = math.cos(a) * u + math.sin(a) * v
                petal(S, hc + e * Rh * 0.92 - f * 0.005 * (1 - ly), f, a, R * r.uniform(0.85, 1.1), 0.038, cup=tilt,
                      reflex=r.uniform(0, 0.12), mat=PETAL, prm=(5, r.uniform(), 0), nu=6, nvv=3,
                      prof=[(0, 0.4), (0.25, 0.95), (0.6, 1.0), (0.85, 0.6), (1, 0)])
    return 0.62


def b_luoi_ho(S, r, seed):
    n = [4, 3, 5, 4][seed % 4]
    cl = [(0.0, -0.05)] + [(math.cos(a) * 0.36, math.sin(a) * 0.3) for a in np.linspace(0, 2 * math.pi, n - 1, endpoint=False) + r.uniform(0, 6.28)]
    for k, (x, y) in enumerate(cl):
        m = int(r.integers(9, 13)); big = 1.0 if k == 0 else 0.82
        for j in range(m):
            a = 2 * math.pi * j / m + r.uniform(-0.3, 0.3); out = r.uniform(0, 0.07)
            b = np.array([x + math.cos(a) * out, y + math.sin(a) * out, 0.0])
            lean = r.uniform(0.08, 0.3)
            d = nv(np.array([math.cos(a) * lean, math.sin(a) * lean, 1.0]))
            L = r.uniform(0.85, 1.25) * big * (1.1 - out * 3)
            leaf(S, b, d, L, r.uniform(0.12, 0.15), droop=0.0, fold=0.3, twist=r.normal(0, 0.5), mat=SANS,
                 prm=(0, r.uniform(), 0), prof=[(0, 0.55), (0.1, 0.9), (0.45, 1.0), (0.78, 0.78), (0.94, 0.3), (1, 0)],
                 nu=18, nvv=7, ao=0.0)
    return 0.62


def thick_leaf(S, base, d, L, W, Tk, droop, mat, prm, teeth=0.0, nu=16, nr=10, ao=0.0, concave=0.5):
    d, s0, n0 = frame_of(d)
    base = np.asarray(base, float)
    def F(U, V):
        Uc = U[..., None]; th = (V * 2 * math.pi)[..., None]
        c = base + d * L * Uc - UP * droop * L * Uc ** 2
        taper = (1 - Uc) ** 0.8
        w = W * 0.5 * taper * (1 + teeth * np.maximum(0, np.sin(U[..., None] * 60)) ** 8 * (np.abs(np.cos(th)) > 0.9))
        t = Tk * 0.5 * taper
        st = np.sin(th)
        up = np.where(st > 0, st * (1 - concave) - concave * (1 - np.cos(th) ** 2) * 0.0 + st * concave * 0.2, st)
        return c + s0 * w * np.cos(th) + n0 * t * up
    S.grid(F, nu, nr, mat, prm, ao, uvr=((0, 1), (0, 1)), close_v=True, flip=True)


def rosette(S, r, c, sc, n, mat, prm_k=0):
    for k in range(n):
        a = 2 * math.pi * k / n * 2.618; ring = k / n
        e = math.radians(82 - 42 * ring + r.normal(0, 4))
        d = np.array([math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)])
        L = (0.3 + 0.32 * ring) * sc
        thick_leaf(S, np.asarray(c) + np.array([math.cos(a), math.sin(a), 0]) * 0.02 * sc, d, L, 0.13 * sc, 0.065 * sc,
                   0.14 * ring, mat, (prm_k, r.uniform(), 0), teeth=0.18, ao=0.4 * (1 - ring))


def b_nha_dam(S, r, seed):
    rosette(S, r, (0, -0.04, 0), 1.75 * r.uniform(0.95, 1.05), 22, ALOE)
    n = [2, 3, 2, 3][seed % 4]
    for k, a in enumerate(np.linspace(0, 2 * math.pi, n, endpoint=False) + r.uniform(0, 6.28)):
        rosette(S, r, (math.cos(a) * 0.72, math.sin(a) * 0.55, 0), r.uniform(0.6, 0.8), 13, ALOE)
    return 0.75


def b_xuong_rong(S, r, seed):
    tips = []
    def pad(base, up, R, lvl):
        # v831: the foot pad faces the viewer and stands firm; upper pads turn a little, so their thickness shows
        fa = r.uniform(-0.25, 0.25) if lvl == 0 else r.uniform(-0.7, 0.7)
        side = np.cross(up, np.array([math.sin(fa), math.cos(fa), 0.0])); side = nv(side) if np.linalg.norm(side) > 1e-3 else np.array([1.0, 0, 0])
        nrm = nv(np.cross(side, up))
        c = base + up * R
        ellipsoid(S, c, R * 0.76, R * 0.21, R, CACT, (0, r.uniform(), 0), axes=(side, nrm, up), nu=14, nvv=26, ao=0.1 * lvl)
        return c + up * R * 0.9, side
    def plant(base, R0, tiers):
        az0 = r.uniform(-0.3, 0.3)
        top, side = pad(base, nv(np.array([math.sin(az0) * 0.25, 0.06, 1.0])), R0, 0)
        level = [(top, side, R0)]
        for t in range(1, tiers):
            nxt = []
            for tp, sd, Rp in level:
                kids = 2 if t == 1 else int(r.integers(1, 3))
                for j in range(kids):
                    ang = (-0.75 + 1.5 * j / max(1, kids - 1) if kids > 1 else r.uniform(-0.4, 0.4)) + r.normal(0, 0.15)
                    up = nv(np.array([math.sin(ang), r.uniform(-0.3, 0.3), math.cos(ang)]))
                    Rk = Rp * r.uniform(0.7, 0.82)
                    q, s2 = pad(tp - UP * Rk * 0.5 + sd * ang * Rp * 0.25, up, Rk, t)
                    nxt.append((q, s2, Rk))
            level = nxt; tips.extend(q for q, _, _ in nxt)
    plant(np.zeros(3), 0.42, 3)
    if seed % 2: plant(np.array([0.55, 0.3, 0.0]), 0.23, 2)
    for k, tp in enumerate(tips[:[3, 4, 2, 5][seed % 4]]):
        f = nv(np.array([0.1, 0.4, 1.0]) + r.normal(0, 0.15, 3))
        for i in range(12):     # v831: a real cup of petals, not a red speck
            petal(S, tp + f * 0.04, f, i * 2 * math.pi / 12 + r.normal(0, 0.1), 0.16, 0.085, cup=0.8, mat=PETAL, prm=(19, r.uniform(), 0), nu=6, nvv=3)
        disc(S, tp + f * 0.07, f, 0.045, FRUIT, (1, 0, 0), dome=0.4, nr=4, na=12)
    return 0.65


def b_sa(S, r, seed):
    n = [3, 2, 3, 2][seed % 4]
    cl = [(0.0, -0.05)] + [(math.cos(a) * 0.3, math.sin(a) * 0.26) for a in np.linspace(0, 2 * math.pi, n - 1, endpoint=False) + r.uniform(0, 6.28)]
    for k, (x, y) in enumerate(cl):
        sc = 1.0 if k == 0 else 0.85
        for j in range(14):
            a = 2 * math.pi * j / 14 + r.uniform(-0.2, 0.2); o = r.uniform(0.01, 0.04)
            b = np.array([x + math.cos(a) * o * sc, y + math.sin(a) * o * sc, 0])
            tube(S, [b, b + np.array([math.cos(a) * 0.03, math.sin(a) * 0.03, r.uniform(0.12, 0.18) * sc])], 0.014 * sc, 0.004 * sc, STEM, (3, 0, 0), nr=6)
        m = int(r.integers(38, 46))
        for j in range(m):
            az = 2 * math.pi * (j + r.uniform(-0.4, 0.4)) / m; out = r.uniform(0, 1) ** 0.8
            e = math.radians(84 - 26 * out + r.normal(0, 4))
            d = np.array([math.cos(az) * math.cos(e), math.sin(az) * math.cos(e), math.sin(e)])
            b = np.array([x + math.cos(az) * 0.03 * sc, y + math.sin(az) * 0.03 * sc, r.uniform(0.06, 0.13) * sc])
            L = (0.95 + 0.45 * out) * r.uniform(0.88, 1.1) * sc
            leaf(S, b, d, L, 0.045 * sc, droop=0.25 + 0.6 * out, fold=0.45, twist=r.normal(0, 0.4), mat=BLADE,
                 prm=(0, r.uniform(), 0), prof=[(0, 0.7), (0.15, 1.0), (0.6, 0.85), (0.9, 0.4), (1, 0)], nu=18, nvv=3,
                 ao=0.4 * (1 - out))
    return 0.62


# ------------------------------------------------------------------ quarter-tile minis (KU 58)
def mound(S, r, n, L, W, style, R=0.12, el=(15, 55), droop=0.3, z0=0.0, prof=None, ao=0.45, fold=0.25):
    for j in range(n):
        az = 2 * math.pi * (j + r.uniform(-0.3, 0.3)) / n * 2.618
        out = r.uniform(0.2, 1.0)
        e = math.radians(el[1] - (el[1] - el[0]) * out + r.normal(0, 6))
        d = np.array([math.cos(az) * math.cos(e), math.sin(az) * math.cos(e), math.sin(e)])
        b = np.array([math.cos(az) * R * out * 0.5, math.sin(az) * R * out * 0.5, z0 + (1 - out) * R * 0.6])
        leaf(S, b, d, L * r.uniform(0.8, 1.15), W * r.uniform(0.85, 1.1), droop=droop, fold=fold, prof=prof,
             mat=LEAF, prm=(style, r.uniform(), 0), ao=ao * (1 - out), nu=9, nvv=5, twist=r.normal(0, 0.2))


def flower5(S, r, p, f, n, R, W, col, cup, prof=None, reflex=0.0):
    a0 = r.uniform(0, 6.28)
    for k in range(n):
        petal(S, p, f, a0 + k * 2 * math.pi / n, R, W, cup=cup, mat=PETAL, prm=(col, r.uniform(), 0), prof=prof,
              reflex=reflex, nu=6, nvv=4)


def b_da_yen(S, r, seed):
    col = [6, 7, 8, 9][seed % 4]
    prof = [(0, 0.2), (0.2, 0.75), (0.45, 1.0), (0.75, 0.75), (1.0, 0.0)]
    mound(S, r, 24, 0.12, 0.065, 4, R=0.13, el=(0, 25), droop=0.3, prof=prof)
    mound(S, r, 16, 0.1, 0.06, 4, R=0.1, el=(20, 50), droop=0.25, prof=prof, z0=0.05)
    n = 8
    for k in range(n):
        a = 2.4 * k + r.uniform(0, 0.4); out = 0.17 * math.sqrt((k + 0.5) / n)
        p = np.array([math.cos(a) * out, math.sin(a) * out * 0.9, 0.12 - out * 0.35])
        f = nv(np.array([math.cos(a) * out * 6, math.sin(a) * out * 6 + 0.3, 1.0]))
        flower5(S, r, p, f, 5, 0.055, 0.075, col, 0.55, prof=[(0, 0.3), (0.4, 0.85), (0.8, 1.0), (1.0, 0.75)])
    return 0.27


def b_mai_dia(S, r, seed):
    col = [10, 11, 12, 13][seed % 4]
    prof = [(0, 0.15), (0.15, 0.6), (0.4, 1.0), (0.65, 0.92), (0.88, 0.45), (1.0, 0.0)]
    mound(S, r, 24, 0.11, 0.058, 5, R=0.12, el=(8, 35), droop=0.2, prof=prof)
    mound(S, r, 16, 0.1, 0.052, 5, R=0.1, el=(25, 60), droop=0.2, prof=prof, z0=0.06)
    n = 11
    for k in range(n):
        a = 2.4 * k + r.uniform(0, 0.5); out = 0.15 * math.sqrt((k + 0.5) / n)
        p = np.array([math.cos(a) * out, math.sin(a) * out * 0.9, 0.15 - out * 0.4])
        f = nv(np.array([math.cos(a) * out * 5, math.sin(a) * out * 5 + 0.3, 1.0]))
        flower5(S, r, p, f, 5, 0.042, 0.046, col, 0.05, prof=[(0, 0.3), (0.3, 0.9), (0.65, 1.0), (0.9, 0.75), (1.0, 0.35)])
    return 0.26


def b_mong_tay(S, r, seed):
    col = [14, 15, 16, 17][seed % 4]
    prof = [(0, 0.1), (0.2, 0.7), (0.45, 1.0), (0.75, 0.6), (1.0, 0.0)]
    for k in range(int(r.integers(3, 5))):
        a = 2 * math.pi * k / 4 + r.uniform(-0.4, 0.4); out = r.uniform(0.03, 0.09)
        top = np.array([math.cos(a) * out, math.sin(a) * out * 0.85, r.uniform(0.4, 0.52)])
        pts = [top * t for t in np.linspace(0, 1, 8)]
        tube(S, pts, 0.016, 0.009, STEM, (4, 0, 0), nr=6)
        for j in range(11):
            s = 0.3 + 0.7 * j / 11; q = top * s
            az = j * 2.4 + k
            d = np.array([math.cos(az), math.sin(az), 0.6 + s])
            leaf(S, q, d, 0.11 * (1.1 - 0.4 * s), 0.03, droop=0.3, prof=prof, mat=LEAF, prm=(5, r.uniform(), 0), nu=7, nvv=3)
            if 0.4 < s < 0.88 and j % 2 == 0:
                f = nv(np.array([math.cos(az + 1), math.sin(az + 1) + 0.3, 0.3]))
                flower5(S, r, q + f * 0.022, f, 5, 0.032, 0.034, col, 0.6)
    return 0.22


def b_cuc_la_nho(S, r, seed):
    prof = [(0, 0.2), (0.2, 0.8), (0.3, 0.7), (0.45, 1.0), (0.6, 0.8), (0.7, 0.75), (1.0, 0.0)]
    mound(S, r, 16, 0.15, 0.09, 6, R=0.1, el=(10, 45), droop=0.3, prof=prof)
    for k in range(int(r.integers(4, 6))):
        a = 2 * math.pi * k / 5 + r.uniform(-0.4, 0.4); out = r.uniform(0.04, 0.12)
        top = np.array([math.cos(a) * out, math.sin(a) * out * 0.85, 0.36 * r.uniform(0.85, 1.15)])
        pts = [np.array([0, 0, 0.03]) + (top - np.array([0, 0, 0.03])) * t + np.array([0, 0, 0]) for t in np.linspace(0, 1, 7)]
        tube(S, pts, 0.008, 0.006, STEM, (0, 0, 0), nr=5)
        f = nv(np.array([math.cos(a) * 0.4, math.sin(a) * 0.4 + 0.35, 1.0]))
        flower5(S, r, top, f, 13, 0.058, 0.022, 18, 0.08, prof=[(0, 0.4), (0.3, 1.0), (0.85, 0.9), (1, 0.3)])
        disc(S, top + f * 0.006, f, 0.02, DISC, (0, 0, 0), dome=0.4, nr=4, na=16)
    return 0.24


def b_ot(S, r, seed):
    prof = [(0, 0.1), (0.2, 0.7), (0.45, 1.0), (0.75, 0.6), (1.0, 0.0)]
    mound(S, r, 26, 0.09, 0.032, 8, R=0.1, el=(10, 50), droop=0.25, prof=prof)
    mound(S, r, 18, 0.08, 0.03, 8, R=0.08, el=(35, 70), droop=0.2, prof=prof, z0=0.08)
    mix = [[0, 1, 2, 3], [0, 0, 3, 1], [0, 2, 4, 1], [0, 3, 1, 2]][seed % 4]
    n = 16
    for k in range(n):
        a = 2.4 * k; out = 0.14 * math.sqrt((k + 0.5) / n)
        p = np.array([math.cos(a) * out, math.sin(a) * out * 0.9, 0.19 - out * 0.4 + r.uniform(0, 0.02)])
        d = nv(np.array([math.cos(a) * 0.3, math.sin(a) * 0.3, 1.0]) + r.normal(0, 0.15, 3))
        u, v = basis(d)
        ellipsoid(S, p + d * 0.018, 0.011, 0.011, 0.028, FRUIT, (mix[k % 4], 0, 0), axes=(u, v, d), nu=7, nvv=10,
                  bulge=lambda U, V: -0.008 * np.clip(U - 0.6, 0, 1) * 0)
    return 0.22


def b_hung_que(S, r, seed):
    prof = [(0, 0.15), (0.15, 0.65), (0.4, 1.0), (0.65, 0.9), (0.88, 0.45), (1.0, 0.0)]
    mound(S, r, 24, 0.1, 0.062, 3, R=0.12, el=(10, 45), droop=0.3, prof=prof, fold=0.4)
    mound(S, r, 16, 0.09, 0.056, 3, R=0.1, el=(30, 70), droop=0.25, prof=prof, z0=0.08, fold=0.4)
    for k in range(int(r.integers(4, 6))):
        a = 2 * math.pi * k / 5 + r.uniform(-0.4, 0.4); out = r.uniform(0.03, 0.12)
        base = np.array([math.cos(a) * out, math.sin(a) * out * 0.85, 0.12]); top = base + UP * r.uniform(0.11, 0.15)
        tube(S, [base, top], 0.006, 0.004, STEM, (2, 0, 0), nr=5)
        for j in range(6):
            q = base + (top - base) * (0.2 + 0.15 * j)
            for i in range(3):
                aa = i * 2.1 + j
                ellipsoid(S, q + np.array([math.cos(aa), math.sin(aa), 0]) * 0.009, 0.007, 0.007, 0.007, FRUIT, (5, 0, 0), nu=4, nvv=6)
    return 0.24


def b_lan_chi(S, r, seed):
    for k in range(28):
        a = 2 * math.pi * k / 28 * 2.618; out = r.uniform(0, 1) ** 0.8
        e = math.radians(80 - 45 * out + r.normal(0, 4))
        d = np.array([math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)])
        leaf(S, np.array([math.cos(a), math.sin(a), 0]) * 0.02, d, r.uniform(0.17, 0.25), 0.03, droop=0.45 + 0.45 * out,
             fold=0.3, mat=BLADE, prm=(1, r.uniform(), 0), prof=[(0, 0.6), (0.2, 1.0), (0.6, 0.85), (0.9, 0.4), (1.0, 0.0)],
             nu=12, nvv=5, ao=0.35 * (1 - out))
    for k in range(1 + seed % 2):
        a = r.uniform(0, 2 * math.pi); dh = np.array([math.cos(a), math.sin(a) * 0.8, 0])
        tip = dh * 0.18 + UP * 0.07; b = UP * 0.08; mid = (b + tip) / 2 + UP * 0.12
        pts = [(1 - t) ** 2 * b + 2 * (1 - t) * t * mid + t * t * tip for t in np.linspace(0, 1, 8)]
        tube(S, pts, 0.004, 0.003, STEM, (4, 0, 0), nr=4)
        for j in range(6):
            az = r.uniform(0, 2 * math.pi)
            leaf(S, tip, np.array([math.cos(az), math.sin(az), 0.8]), 0.065, 0.022, droop=0.4, mat=BLADE, prm=(1, r.uniform(), 0),
                 prof=[(0, 0.6), (0.2, 1.0), (0.6, 0.85), (1.0, 0.0)], nu=7, nvv=3)
    return 0.25



# ------------------------------------------------------------------ the 12 older Hoa cỏ minis (were cairo in hoaco.py)
def grass(S, r, n, L, W, R=0.06, el=(50, 85), dry=0.08, z0=0.0, droop=(0.25, 0.7)):
    for j in range(n):
        az = 2 * math.pi * (j + r.uniform(-0.4, 0.4)) / n * 2.618; out = r.uniform(0, 1) ** 0.7
        e = math.radians(el[1] - (el[1] - el[0]) * out + r.normal(0, 5))
        d = np.array([math.cos(az) * math.cos(e), math.sin(az) * math.cos(e), math.sin(e)])
        b = np.array([math.cos(az) * R * out, math.sin(az) * R * out * 0.85, z0])
        leaf(S, b, d, L * r.uniform(0.75, 1.15) * (1.1 - 0.3 * out), W * r.uniform(0.85, 1.1),
             droop=droop[0] + (droop[1] - droop[0]) * out, fold=0.4, twist=r.normal(0, 0.5), mat=BLADE,
             prm=(3 if r.uniform() < dry else 2, r.uniform(), 0),
             prof=[(0, 0.7), (0.15, 1.0), (0.6, 0.8), (0.9, 0.35), (1, 0)], nu=12, nvv=3, ao=0.4 * (1 - out))


def b_c_xanh(S, r, seed):
    grass(S, r, [30, 34, 28, 32][seed % 4], 0.42, 0.034, R=0.09)
    return 0.3


def b_c_lau(S, r, seed):
    grass(S, r, 20, 0.36, 0.03, R=0.07, dry=0.15)
    wind = np.array([1.0, 0.25, 0.0])
    for k in range(2 + seed % 2):
        a = r.uniform(0, 6.28); b = np.array([math.cos(a) * 0.03, math.sin(a) * 0.03, 0])
        H = r.uniform(0.6, 0.72) * (1 - 0.08 * k)
        lean = r.uniform(0.05, 0.16) * (1 if k % 2 == 0 else -0.6)
        top = b + np.array([lean, r.normal(0, 0.03), H])
        mid = (b + top) / 2 + np.array([-lean * 0.3, 0, 0])
        pts = [(1 - t) ** 2 * b + 2 * (1 - t) * t * mid + t * t * top for t in np.linspace(0, 1, 10)]
        tube(S, pts, 0.007, 0.004, STEM, (4, 0, 0), nr=5)
        L = r.uniform(0.28, 0.34)
        d0 = nv(np.array([0.35, 0.05, 1.0]) + wind * 0.1)
        for j in range(24):
            q = top - d0 * L * 0.35 * j / 24
            dd = nv(d0 + wind * r.uniform(0.15, 0.55) + r.normal(0, 0.16, 3))
            leaf(S, q, dd, L * r.uniform(0.6, 1.0) * (1 - 0.015 * j), 0.022, droop=r.uniform(0.3, 0.6), fold=0.6,
                 twist=r.normal(0, 1.2), mat=PLUME, prm=(0, r.uniform(), 0),
                 prof=[(0, 0.3), (0.25, 0.9), (0.55, 1.0), (0.85, 0.6), (1, 0)], nu=12, nvv=3, ao=0.25 * j / 24)
    return 0.3


def b_bui_la(S, r, seed):
    prof = [(0, 0.15), (0.12, 0.62), (0.35, 0.98), (0.55, 1.0), (0.75, 0.8), (0.92, 0.38), (1, 0)]
    for cx, cy, sc in ((-0.06, 0.02, 1.0), (0.09, -0.03, 0.85)):
        S0 = Scene()
        mound(S0, r, 18, 0.19 * sc, 0.1 * sc, [0, 1, 0, 3][seed % 4], R=0.12 * sc, el=(5, 45), droop=0.35, prof=prof)
        S.merge(S0, off=(cx, cy, 0))
    for k in range(4):
        a = r.uniform(-1.2, 1.2); b = np.array([math.sin(a) * 0.05, 0.0, 0.12])
        leaf(S, b, np.array([math.sin(a) * 0.4, 0.1, 1.0]), 0.15, 0.07, droop=0.15, fold=0.35, prof=prof,
             mat=LEAF, prm=(3, 0.9, 0), nu=9, nvv=5)
    return 0.28


def daisy_base(S, r, n=16, L=0.11, W=0.045, style=0):
    mound(S, r, n, L, W, style, R=0.1, el=(5, 40), droop=0.3,
          prof=[(0, 0.1), (0.2, 0.55), (0.45, 1.0), (0.7, 0.85), (0.9, 0.4), (1, 0)])


def stems_to(S, r, n, H, spread, mat=(0, 0, 0)):
    tops = []
    for k in range(n):
        a = 2 * math.pi * k / n + r.uniform(-0.35, 0.35); out = spread * r.uniform(0.35, 1.0)
        top = np.array([math.cos(a) * out, math.sin(a) * out * 0.85, H * r.uniform(0.82, 1.12)])
        b = np.array([math.cos(a) * 0.02, math.sin(a) * 0.02, 0.02]); mid = (b + top) / 2 + UP * 0.03
        pts = [(1 - t) ** 2 * b + 2 * (1 - t) * t * mid + t * t * top for t in np.linspace(0, 1, 7)]
        tube(S, pts, 0.007, 0.005, STEM, mat, nr=5)
        tops.append((top, nv(np.array([math.cos(a) * out * 2.5, math.sin(a) * out * 2.5 + 0.35, 1.0]))))
    return tops


def b_cuc_vang(S, r, seed):
    daisy_base(S, r)
    for top, f in stems_to(S, r, 5 + seed % 2, 0.3, 0.13):
        a0 = r.uniform(0, 6.28)
        for ly, (R, cup, n) in enumerate(((0.06, 0.18, 16), (0.048, 0.5, 14), (0.034, 0.85, 11), (0.02, 1.3, 7))):
            for k in range(n):
                petal(S, top + f * 0.006 * ly, f, a0 + (k + 0.5 * ly) * 2 * math.pi / n, R, 0.018 + 0.004 * (3 - ly),
                      cup=cup, mat=PETAL, prm=(20, r.uniform(), 0), nu=5, nvv=3, ao=0.12 * ly, notch=0.2,
                      prof=[(0, 0.4), (0.3, 0.9), (0.8, 1.0), (1, 0.5)])
    return 0.25


def b_cuc_trang(S, r, seed):
    daisy_base(S, r, 18, 0.1, 0.04)
    for top, f in stems_to(S, r, 5 + seed % 2, 0.24, 0.13):
        a0 = r.uniform(0, 6.28)
        for k in range(18):
            petal(S, top, f, a0 + k * 2 * math.pi / 18 + r.normal(0, 0.04), 0.058 * r.uniform(0.9, 1.05), 0.016,
                  cup=0.08, reflex=r.uniform(0, 0.1), mat=PETAL, prm=(21, r.uniform(), 0), nu=6, nvv=3, notch=0.3,
                  prof=[(0, 0.4), (0.2, 0.9), (0.8, 1.0), (1, 0.6)])
        disc(S, top + f * 0.004, f, 0.019, FRUIT, (1, 0, 0), dome=0.6, nr=4, na=14)
    return 0.25


def b_muoi_gio(S, r, seed):
    pal = [[22, 23, 24, 25, 26], [22, 22, 26, 25], [24, 25, 23], [23, 26, 22, 24]][seed % 4]
    tips = []
    for k in range(10):
        a = 2 * math.pi * k / 10 + r.uniform(-0.25, 0.25); L = r.uniform(0.14, 0.22)
        A = np.array([math.cos(a), math.sin(a) * 0.9, 0])
        pts = [A * L * t + UP * (0.02 + 0.09 * math.sin(t * 2.4) * r.uniform(0.6, 1.2)) for t in np.linspace(0, 1, 8)]
        tube(S, pts, 0.008, 0.005, STEM, (2, 0, 0), nr=5)
        for j in range(16):
            t = 0.15 + 0.85 * j / 16; q = pts[min(7, int(t * 7.99))]
            az = j * 2.4 + k
            d = nv(np.array([math.cos(az), math.sin(az), 1.2]))
            u, v = basis(d)
            ellipsoid(S, q + d * 0.02, 0.0065, 0.0065, 0.024, LEAF, (5, r.uniform(), 0), axes=(u, v, d), nu=5, nvv=7)
        tips.append(pts[-1] + UP * 0.02)
    for k, tp in enumerate(tips[::2] + tips[1::4]):
        f = nv(np.array([r.normal(0, 0.2), 0.45 + r.normal(0, 0.1), 1.0]))
        flower5(S, r, tp, f, 5, 0.05, 0.05, pal[k % len(pal)], 0.4,
                prof=[(0, 0.3), (0.35, 0.9), (0.7, 1.0), (0.95, 0.8), (1, 0.3)])
        disc(S, tp + f * 0.008, f, 0.009, FRUIT, (1, 0, 0), dome=0.6, nr=3, na=10)
    return 0.25


def b_sao_nhai(S, r, seed):
    col = 27 if seed % 2 == 0 else 28
    for k in range(14):
        a = r.uniform(0, 6.28)
        leaf(S, np.array([math.cos(a), math.sin(a), 0]) * 0.03, np.array([math.cos(a), math.sin(a), 0.9]), 0.12, 0.05,
             droop=0.35, fold=0.2, mat=LEAF, prm=(0, r.uniform(), 0), nu=8, nvv=5,
             prof=[(0, 0.2), (0.2, 0.8), (0.35, 0.3), (0.5, 0.9), (0.65, 0.3), (0.8, 0.7), (1, 0)])
    for top, f in stems_to(S, r, 5 + seed % 2, 0.66, 0.22):
        for j in range(4):           # thread leaves up the stem
            q = top * (0.25 + 0.15 * j); az = r.uniform(0, 6.28)
            for i in range(3):
                leaf(S, q, np.array([math.cos(az + i * 0.5), math.sin(az + i * 0.5), 0.6]), 0.07, 0.008, droop=0.3,
                     fold=0.0, mat=LEAF, prm=(0, r.uniform(), 0), nu=5, nvv=2)
        f = nv(np.array([r.normal(0, 0.25), 0.55 + r.uniform(0, 0.3), 1.0]))
        a0 = r.uniform(0, 6.28)
        for k in range(8):
            petal(S, top, f, a0 + k * 2 * math.pi / 8 + r.normal(0, 0.05), 0.062, 0.036, cup=0.12, mat=PETAL,
                  prm=(col, r.uniform(), 0), notch=0.45, nu=6, nvv=4,
                  prof=[(0, 0.25), (0.3, 0.75), (0.7, 1.0), (1, 0.95)])
        disc(S, top + f * 0.006, f, 0.016, FRUIT, (1, 0, 0), dome=0.7, nr=4, na=14)
    return 0.25


def b_dua_can(S, r, seed):
    col = 29 if seed % 2 == 0 else 30
    prof = [(0, 0.15), (0.15, 0.65), (0.4, 1.0), (0.65, 0.9), (0.88, 0.45), (1, 0)]
    mound(S, r, 24, 0.11, 0.055, 1, R=0.12, el=(5, 35), droop=0.25, prof=prof, fold=0.2)
    mound(S, r, 14, 0.1, 0.05, 1, R=0.09, el=(25, 55), droop=0.2, prof=prof, z0=0.07, fold=0.2)
    n = 7 - seed % 2
    for k in range(n):
        a = 2.4 * k + r.uniform(0, 0.4); out = 0.15 * math.sqrt((k + 0.5) / n)
        p = np.array([math.cos(a) * out, math.sin(a) * out * 0.9, 0.17 - out * 0.4])
        f = nv(np.array([math.cos(a) * out * 4, math.sin(a) * out * 4 + 0.35, 1.0]))
        a0 = r.uniform(0, 6.28)
        for i in range(5):   # pinwheel: each petal turned a little off its spoke
            petal(S, p, f, a0 + i * 2 * math.pi / 5, 0.046, 0.05, cup=0.04, tilt=0.0, mat=PETAL,
                  prm=(col, r.uniform(), 0), nu=6, nvv=4, prof=[(0, 0.2), (0.3, 0.7), (0.65, 1.0), (0.9, 0.85), (1, 0.4)])
        disc(S, p + f * 0.004, f, 0.006, FRUIT, (4, 0, 0), dome=0.4, nr=2, na=8)
    return 0.25


def b_tim(S, r, seed):
    mound(S, r, 18, 0.13, 0.03, 0, R=0.08, el=(25, 65), droop=0.3,
          prof=[(0, 0.2), (0.2, 0.8), (0.45, 1.0), (0.75, 0.6), (1, 0)])
    for top, f in stems_to(S, r, 3 + seed % 2, 0.56, 0.08):
        base = top * 0.45
        for j in range(16):        # small four-petal flowers round the upper stem, buds at the tip
            t = j / 16; q = base + (top - base) * t; az = j * 2.4 + r.uniform(-0.3, 0.3)
            e = np.array([math.cos(az), math.sin(az), 0])
            if t > 0.75:
                ellipsoid(S, q + e * 0.008, 0.008, 0.008, 0.013, FRUIT, (2, 0, 0), nu=4, nvv=6)
                continue
            fd = nv(e + UP * 0.4 + np.array([0, 0.3, 0]))
            pc = q + e * 0.014
            for i in range(4):
                petal(S, pc, fd, i * math.pi / 2 + az, 0.022, 0.02, cup=0.3, mat=PETAL, prm=(31, r.uniform(), 0), nu=4, nvv=3)
    return 0.25


def b_ngu_sac(S, r, seed):
    ring = [32, 33, 34, 35][seed % 4]
    prof = [(0, 0.2), (0.12, 0.7), (0.22, 0.6), (0.34, 0.95), (0.46, 0.8), (0.58, 0.95), (0.7, 0.7), (0.82, 0.6), (1, 0)]
    mound(S, r, 26, 0.1, 0.06, 6, R=0.12, el=(8, 40), droop=0.25, prof=prof)
    mound(S, r, 14, 0.09, 0.055, 6, R=0.09, el=(25, 55), droop=0.2, prof=prof, z0=0.07)
    n = 6 - seed % 2
    for k in range(n):
        a = 2.4 * k + r.uniform(0, 0.4); out = 0.14 * math.sqrt((k + 0.5) / n)
        c = np.array([math.cos(a) * out, math.sin(a) * out * 0.9, 0.18 - out * 0.35])
        f0 = nv(np.array([math.cos(a) * out * 3, math.sin(a) * out * 3 + 0.35, 1.0])); u, v = basis(f0)
        m = 24
        for i in range(m):
            t = (i + 0.5) / m; th = math.acos(1 - t * (1 - math.cos(math.radians(70)))); ph = i * 2.39996
            d = math.cos(th) * f0 + math.sin(th) * (math.cos(ph) * u + math.sin(ph) * v)
            q = c + d * 0.045; col = ring if th > math.radians(35) else 36
            a0 = r.uniform(0, 6.28)
            for j in range(4):
                petal(S, q, d, a0 + j * math.pi / 2, 0.018, 0.018, cup=0.1, mat=PETAL, prm=(col, r.uniform(), 0), nu=3, nvv=3)
    return 0.25


def b_mong_ga(S, r, seed):
    col = 39 if seed % 2 == 0 else 40
    mound(S, r, 22, 0.12, 0.05, 0, R=0.1, el=(10, 45), droop=0.3)
    for k in range(2 + seed % 2):
        a = 2 * math.pi * k / 3 + r.uniform(-0.4, 0.4); out = r.uniform(0.03, 0.08)
        b = np.array([math.cos(a) * out, math.sin(a) * out * 0.8, 0.02])
        H = r.uniform(0.16, 0.24) * (1 - 0.1 * k); top = b + np.array([r.normal(0, 0.015), 0.0, H])
        tube(S, [b, (b + top) / 2, top], 0.012, 0.02, STEM, (0, 0, 0), nr=7)
        W = r.uniform(0.17, 0.21) * (1 - 0.1 * k); Hc = r.uniform(0.08, 0.1); fa = r.uniform(-0.35, 0.35)
        sx = nv(np.array([math.cos(fa), math.sin(fa) * 0.6, 0])); sy = nv(np.cross(UP, sx))
        if sy[1] < 0: sy = -sy
        ph = r.uniform(0, 6.28)
        def ctr(U, V):
            Uc = U[..., None]; Vc = V[..., None]
            wid = W * 0.5 * (0.15 + 0.85 * Uc ** 0.5)
            rise = Hc * Uc * (1 - 0.3 * Vc ** 2)
            ruff = 0.02 * Uc ** 1.3 * np.sin(Vc * 9 + ph)
            return top + sx * wid * Vc + UP * rise + sy * (ruff - 0.01 * Uc)
        # the flat fan, both faces
        for side in (-1, 1):
            S.grid(lambda U, V, side=side: ctr(U, V) + sy * side * 0.012 * U[..., None] ** 0.5, 12, 36, PETAL,
                   (col, r.uniform(), 0), 0.35, uvr=((0, 0.8), (-1, 1)))
        # the rolled crest along the top: a fat wrinkled tube, folded over and over
        pts = []
        for t in np.linspace(-1, 1, 60):
            U = np.array(1.0); V = np.array(t)
            p = ctr(U, V)
            pts.append(p + UP * 0.012 * math.sin(t * 23 + ph) + sy * 0.015 * math.sin(t * 17 + ph * 2))
        tube(S, pts, 0.026, 0.02, PETAL, (col, 0.95, 0), nr=10)
        for t in np.linspace(-0.95, 0.95, 26):
            p = ctr(np.array(0.97), np.array(t)) + UP * 0.015
            ellipsoid(S, p + r.normal(0, 0.006, 3), 0.016, 0.016, 0.012, PETAL, (col, 0.9, 0), nu=5, nvv=8)
    return 0.25


def b_van_tho(S, r, seed):
    col = 37 if seed % 2 == 0 else 38
    for k in range(13):              # feathery pinnate fronds
        a = 2 * math.pi * k / 13 + r.uniform(-0.2, 0.2); e = math.radians(r.uniform(15, 50))
        d = np.array([math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)])
        L = r.uniform(0.12, 0.17); b = np.array([math.cos(a), math.sin(a), 0]) * 0.02 + UP * 0.03
        pts = [b + d * L * t - UP * 0.25 * L * t * t for t in np.linspace(0, 1, 6)]
        tube(S, pts, 0.003, 0.002, STEM, (5, 0, 0), nr=3)
        side = nv(np.cross(d, UP))
        for j in range(6):
            t = 0.2 + 0.8 * j / 6; q = b + d * L * t - UP * 0.25 * L * t * t
            for sg in (-1, 1):
                leaf(S, q, nv(side * sg + d * 0.8 + UP * 0.2), 0.04 * (1.1 - 0.5 * t), 0.014, droop=0.2, fold=0.2,
                     mat=LEAF, prm=(8, r.uniform(), 0), nu=5, nvv=3, ao=0.3 * (1 - t))
    n = 4 + seed % 3
    for k in range(n):
        a = 2.4 * k + r.uniform(0, 0.4); out = 0.12 * math.sqrt((k + 0.5) / n)
        c = np.array([math.cos(a) * out, math.sin(a) * out * 0.9, 0.12 - out * 0.3])
        tube(S, [c * np.array([0.3, 0.3, 0]), c], 0.006, 0.006, STEM, (5, 0, 0), nr=5)
        f0 = nv(np.array([math.cos(a) * out * 3, math.sin(a) * out * 3 + 0.3, 1.0])); u, v = basis(f0)
        R = r.uniform(0.04, 0.05)
        ellipsoid(S, c + f0 * R * 0.3, R * 0.75, R * 0.75, R * 0.55, PETAL, (col, 0.05, 0), axes=(u, v, f0), zmin=0.3, ao=0.5)
        m = 44
        for i in range(m):
            t = (i + 0.5) / m; th = math.acos(1 - t * (1 - math.cos(math.radians(100)))); ph = i * 2.39996
            dd = math.cos(th) * f0 + math.sin(th) * (math.cos(ph) * u + math.sin(ph) * v)
            if dd @ TOCAM < -0.3: continue
            q = c + f0 * R * 0.3 + dd * R * 0.55
            fd = nv(dd + f0 * 0.4)
            petal(S, q, fd, r.uniform(0, 6.28), R * 0.62, R * 0.7, cup=r.uniform(-0.3, 0.5), mat=PETAL,
                  prm=(col, r.uniform(), 0), notch=0.35, nu=4, nvv=4, ao=0.25 * (1 - th / 1.75),
                  prof=[(0, 0.3), (0.4, 0.9), (0.8, 1.0), (1, 0.85)])
    return 0.25


BUILD = {'cc_bong_trang': b_bong_trang, 'cc_lai': b_lai, 'cc_huong_duong': b_huong_duong, 'cc_luoi_ho': b_luoi_ho,
         'cc_nha_dam': b_nha_dam, 'cc_xuong_rong': b_xuong_rong, 'cc_sa': b_sa,
         'h_da_yen': b_da_yen, 'h_mai_dia': b_mai_dia, 'h_mong_tay': b_mong_tay, 'h_cuc_la_nho': b_cuc_la_nho,
         'k_ot': b_ot, 'k_hung_que': b_hung_que, 'k_lan_chi': b_lan_chi,
         'c_xanh': b_c_xanh, 'c_lau': b_c_lau, 'bui_la': b_bui_la, 'h_cuc_vang': b_cuc_vang, 'h_cuc_trang': b_cuc_trang,
         'h_muoi_gio': b_muoi_gio, 'h_sao_nhai': b_sao_nhai, 'h_dua_can': b_dua_can, 'h_tim': b_tim, 'h_ngu_sac': b_ngu_sac,
         'h_mong_ga': b_mong_ga, 'h_van_tho': b_van_tho}


def render(kind, seed, night=False, ss=3, rs=5):
    big = kind in BIG
    S = Scene(); r = rng_for(kind, seed)
    BUILD[kind](S, r, seed)
    R = pxr.Render(BB_BIG if big else BB_KIND.get(kind, BB_SMALL), KU_BIG if big else KU_SMALL, rs * ss)
    tg = {'cc_luoi_ho': 0.38, 'cc_huong_duong': 0.47, 'cc_bong_trang': 0.4, 'cc_lai': 0.42}.get(kind, 0.45 if big else 0.47)
    img = R.run(S, MATS, night=night, look={'target': tg, 'toon': TOON}, shadow_k={'h_sao_nhai': 0.55}.get(kind, 1.0))
    return pxr.Render.to_image(img, ss)


if __name__ == '__main__':
    import time
    from PIL import Image
    kinds = sys.argv[1].split(',')
    seeds = [int(x) for x in sys.argv[2].split(',')] if len(sys.argv) > 2 else [0, 1, 2, 3]
    night = len(sys.argv) > 4 and sys.argv[4] == 'n'
    rows = []
    for k in kinds:
        row = []
        for s in seeds:
            t = time.time(); row.append(render(k, s, night)); print(k, s, '%.1fs' % (time.time() - t), flush=True)
        rows.append(row)
    w, h = rows[0][0].size
    o = Image.new('RGBA', (w * len(seeds), h * len(rows)), (40, 58, 52, 255) if night else (176, 168, 112, 255))
    for j, row in enumerate(rows):
        for i, im in enumerate(row): o.alpha_composite(im, (i * w, j * h))
    o.save(sys.argv[3] if len(sys.argv) > 3 else '/tmp/claude-0/g/px.png')
