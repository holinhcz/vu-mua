# Nhà tranh (hut, 3x2: 3 bays, porch, kitchen lean-to) built as a real 3D model like ../choi/choi3d.py and shaded pixel by pixel (Link 2026-11-08: "tạo khung 3D vẽ",
# "vẽ như thật chi tiết từng pixel"). Same footprint, size, camera, sun and frame layout as choi.py, so the game hook
# (patch_choi.py) and atlas format stay the same.
#
# World: X = u*T, Y = v*T, Z = z (game units; u,v tiles as in choi.py). Camera = the game's iso exactly:
#   screen x = (X-Y)*32/T, screen y = (X+Y)*16/T - Z; depth along TOCAM = nv(1, 1, 32/T).
# Every leaflet of thatch, every bamboo, the woven walls, the props are geometry; each pixel gets its own normal,
# real sun shadow (shadow map), occlusion in the gaps, a per-pixel surface texture, and a thin darker edge where one
# part passes over another (the game's crisp sprite edge).
# Usage: python3 nha3d.py prev OUT.png [t] [n]       python3 choi3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'pxr'))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'choi'))
import pxr_3d as X3
from pxr_3d import Scene, _raster, _shadow_lookup, box_blur, hash1, vnoise, hexc, smooth
import choi as B
from choi import T
# Nhà tranh (game id hut, 3x2 tiles): 3-bay house, ridge along u, shallow front porch (hiên), kitchen lean-to (chái bếp) on the right
U0, U1, V0, V1 = 0.3, 2.3, 0.28, 1.2          # walls
ZF, ZW = 2.4, 47.0                            # floor top, wall plate
RV, RZ = 0.72, 68.0                           # ridge
EV, EZ = 1.78, 42.5                           # front (porch) eave
BV = 0.06; BZ = RZ - (RZ - EZ) / (EV - RV) * (RV - BV)   # back eave, same pitch
RU0, RU1 = 0.1, 2.5                           # roof ends
SMOKE_U = -9.0                                # no ridge lift
PL = (0.08, 2.92, 0.1, 1.93)                   # earth platform
PV = 1.74                                     # porch post line
GAP = (0.97, 1.63)                            # bay posts besides U0, U1
DOOR = (1.1, 1.5, ZF + 25.5)
WIN = [(0.5, 0.8), (1.83, 2.13)]; WZ = (ZF + 10.0, ZF + 21.0)
KU = 2.76; KZ0, KZ1 = 44.0, 30.5              # lean-to outer post line, roof height at the house wall / at the outer eave
OX, OY = -16, -40                             # at.P(3,2) offset
BB = (-104, -124, 104, 46)
def nv(v): v = np.asarray(v, float); return v / np.linalg.norm(v)
TOCAM = nv([1.0, 1.0, 32 / T])
LIGHT = nv([0.3, 0.72, 0.62])
MIRL = bool(os.environ.get('MIRL'))   # Link 14:10: frames for the mirrored (xoay) build: render with u/v swapped sun, the game flips them back
if MIRL: LIGHT = nv([LIGHT[1], LIGHT[0], LIGHT[2]])
HALF = nv(LIGHT + TOCAM)
UP = np.array([0.0, 0.0, 1.0])


def W3(u, v, z): return np.array([u * T, v * T, z], float)


# ------------------------------------------------------------------ geometry helpers
def plane(S, O, A, Bv, nu, nvv, mat, prm=(0, 0, 0), ao=0.0, off=None):
    """quad O + a*A + b*B, a,b in 0..1; uv in game units along A and B. off(U,V)->(nu,nv) offset along the normal"""
    O = np.asarray(O, float); A = np.asarray(A, float); Bv = np.asarray(Bv, float)
    la, lb = np.linalg.norm(A), np.linalg.norm(Bv); n = nv(np.cross(A, Bv))
    def F(U, V):
        p = O + A * (U / la)[..., None] + Bv * (V / lb)[..., None]
        if off is not None: p = p + n * off(U, V)[..., None]
        return p
    S.grid(F, nu, nvv, mat, prm, ao, uvr=((0, la), (0, lb)))


def tube(S, p0, p1, r, mat, prm=(0, 0, 0), nr=10, nl=6, ao=0.0, taper=1.0):
    p0 = np.asarray(p0, float); p1 = np.asarray(p1, float); d = p1 - p0; L = np.linalg.norm(d); d = d / L
    ref = UP if abs(d[2]) < 0.9 else np.array([1.0, 0, 0])
    a = nv(np.cross(d, ref)); b = np.cross(d, a)
    def F(U, V):
        t = (U / L)[..., None]; th = (V * 2 * math.pi)[..., None]; rr = r * (1 + (taper - 1) * t)
        return p0 + d * U[..., None] + (a * np.cos(th) + b * np.sin(th)) * rr
    S.grid(F, nl, nr, mat, prm, ao, uvr=((0, L), (0, 1)), close_v=True, flip=True)


def disc(S, c, f, R, mat, prm=(0, 0, 0), nr=6, na=24, dome=0.0):
    f = nv(f); a = nv(np.cross(f, UP)) if abs(f[2]) < 0.9 else np.array([1.0, 0, 0]); b = np.cross(f, a)
    c = np.asarray(c, float)
    def F(U, V):
        rr = (U * R)[..., None]; th = (V * 2 * math.pi)[..., None]
        return c + (a * np.cos(th) + b * np.sin(th)) * rr + f * dome * R * (1 - U[..., None] ** 2)
    S.grid(F, nr, na, mat, prm, 0.0, uvr=((0, 1), (0, 1)), close_v=True, flip=True)


def lathe(S, c, prof, mat, prm=(0, 0, 0), na=28):
    """surface of revolution round +Z: prof = [(z, r), ...] from the bottom up"""
    zs = np.array([p[0] for p in prof]); rs = np.array([p[1] for p in prof]); c = np.asarray(c, float)
    def F(U, V):
        z = np.interp(U, np.linspace(0, 1, len(zs)), zs); r = np.interp(U, np.linspace(0, 1, len(zs)), rs)
        th = V * 2 * math.pi
        return np.stack([c[0] + r * np.cos(th), c[1] + r * np.sin(th), c[2] + z], -1)
    S.grid(F, len(prof) * 3, na, mat, prm, 0.0, uvr=((0, 1), (0, 1)), close_v=True, flip=True)


def extrude(S, pts, z0, z1, mat, prm=(0, 0, 0), flare=0.0, nz=4):
    """vertical wall along a closed outline (list of (X,Y)), from z0 up to z1; flare pushes the foot outward"""
    P = np.array(pts + [pts[0]], float); seg = np.linalg.norm(np.diff(P, axis=0), axis=1); s = np.concatenate([[0], np.cumsum(seg)])
    cen = P[:-1].mean(0)
    def F(U, V):
        x = np.interp(U, s, P[:, 0]); y = np.interp(U, s, P[:, 1])
        dx, dy = x - cen[0], y - cen[1]; ln = np.maximum(np.hypot(dx, dy), 1e-6)
        k = flare * (1 - (V - z0) / (z1 - z0))
        return np.stack([x + dx / ln * k, y + dy / ln * k, V], -1)
    S.grid(F, len(P) * 2, nz, mat, prm, 0.0, uvr=((0, s[-1]), (z0, z1)))


def rrect(u0, u1, v0, v1, r, n=8):
    out = []
    for (cx, cy, a0) in [(u1 - r, v1 - r, 0), (u0 + r, v1 - r, 0.5 * math.pi), (u0 + r, v0 + r, math.pi), (u1 - r, v0 + r, 1.5 * math.pi)]:
        for j in range(n):
            an = a0 + 0.5 * math.pi * j / (n - 1); out.append(((cx + math.cos(an) * r) * T, (cy + math.sin(an) * r) * T))
    return out


def rrect_top(S, u0, u1, v0, v1, r, z, mat, prm=(0, 0, 0)):
    cx, cy = (u0 + u1) / 2 * T, (v0 + v1) / 2 * T; hx, hy = (u1 - u0) / 2 * T, (v1 - v0) / 2 * T; R = r * T
    def F(U, V):
        x = U * hx; y = V * hy
        qx = np.clip(np.abs(x) - (hx - R), 0, None); qy = np.clip(np.abs(y) - (hy - R), 0, None); q = np.hypot(qx, qy)
        k = np.where(q > R, R / np.maximum(q, 1e-9), 1.0)
        x = np.sign(x) * ((hx - R) + qx * k) * (np.abs(x) > hx - R) + x * (np.abs(x) <= hx - R)
        y = np.sign(y) * ((hy - R) + qy * k) * (np.abs(y) > hy - R) + y * (np.abs(y) <= hy - R)
        return np.stack([cx + x, cy + y, np.full_like(x, z)], -1)
    S.grid(F, 40, 40, mat, prm, 0.0, uvr=((-1, 1), (-1, 1)))


# ------------------------------------------------------------------ materials: id -> fn(uv, prm, pos, nrm) -> alb, nrm
M_EARTH, M_EARTHSIDE, M_BAMBOO, M_WEAVE_F, M_WEAVE_R, M_LEAF, M_THEND, M_DARK, M_WOOD, M_BARK, M_GLAZE, M_LID, \
    M_NIA, M_CORN, M_HUSK, M_CHILLI, M_GABLE, M_STONE, M_RATTAN, M_INSIDE, M_GLOW, M_VERGE = range(22)
THATCH = [['#e2bb62', '#d6ab52', '#ebc872', '#cfa04b', '#dcb35c'], ['#d8a957', '#cc9c4b', '#e2b665', '#c49446', '#d2a555'],
          ['#e6c67a', '#dbb96a', '#efd388', '#d3b062', '#e1c174'], ['#d3ae6a', '#c8a25f', '#ddb978', '#bf985a', '#cfa966']]
VARIANT = 0
WEATHER = True
PXU = 9            # sheet px per game unit (Link: every sprite >= 9 px/unit, 4K sharp on his phone)


def pal(hexes, i):
    C = np.array([hexc(h) for h in hexes]); return C[np.asarray(i, int) % len(C)]


def bump(nrm, t, s, k):
    """tilt normals by k*s along tangent t (per pixel)"""
    n = nrm + t * (k * s)[:, None]
    return n / np.linalg.norm(n, axis=1, keepdims=True)


def mat_earth(uv, prm, pos, nrm):
    x, y = pos[:, 0], pos[:, 1]
    n1 = vnoise(x * 0.18, y * 0.18, 3.0); n2 = vnoise(x * 0.9, y * 0.9, 7.0)
    base = hexc('#c9a273') * (0.94 + 0.08 * n1 + 0.04 * n2)[:, None]
    # trodden smoother darker patch from the door out
    d = np.hypot((x - 1.3 * T) / 14, (y - 1.62 * T) / 7)
    base = base * (1 - 0.06 * np.clip(1 - d, 0, 1))[:, None]
    # sparse grit
    g = hash1(np.floor(x * 2.2), np.floor(y * 2.2), 11.0)
    base = np.where((g > 0.995)[:, None], base * 0.88, base)
    ex = np.minimum(np.minimum(x - PL[0] * T, PL[1] * T - x), np.minimum(y - PL[2] * T, PL[3] * T - y))
    rim = smooth(3.0, 0.0, ex) * (0.7 + 0.3 * vnoise(x * 0.5, y * 0.5, 8.0))
    base = base * (1 - 0.16 * rim)[:, None]
    return base, nrm


def mat_earthside(uv, prm, pos, nrm):
    z = pos[:, 2]; s = uv[:, 0]
    lay = 0.5 + 0.5 * np.sin(z * 2.6 + vnoise(s * 0.3, z, 2.0) * 2)
    base = hexc('#9c7650') * (0.9 + 0.08 * lay + 0.06 * vnoise(s * 0.8, z * 0.8, 5.0))[:, None]
    return base, nrm


def mat_bamboo(uv, prm, pos, nrm):
    L = uv[:, 0]; th = uv[:, 1]
    tone = prm[:, 0]
    base = hexc('#c9a45c') * (0.92 + 0.12 * tone)[:, None]
    streak = vnoise(th * 40, L * 0.08, 1.0)
    base = base * (0.94 + 0.1 * streak)[:, None]
    sp = 9.0 + 2 * tone; ph = (L + prm[:, 1] * 5) / sp; f = ph - np.floor(ph)
    ring = np.exp(-((f - 0.5) / 0.03) ** 2); ridge = np.exp(-((f - 0.46) / 0.025) ** 2)
    base = base * (1 - 0.35 * ring)[:, None] + 0.12 * ridge[:, None]
    foot = np.clip(1 - pos[:, 2] / 6, 0, 1) * prm[:, 2]
    base = base * (1 - 0.18 * foot)[:, None] + hexc('#8a8270') * (0.18 * foot)[:, None]
    return np.clip(base, 0, 1), nrm


def weave_tex(a, b, P, tang_a, tang_b, nrm, cell=1.45):
    """2/2 twill of split bamboo, a/b in game units across/up the wall"""
    i = np.floor(a / cell); j = np.floor(b / cell); fa = a / cell - i; fb = b / cell - j
    over_h = ((i + j) % 4) < 2
    stripj = np.where(over_h, j, i)
    hs = hash1(stripj, over_h * 7.0, 3.0); tone = 0.86 + 0.2 * hs
    across = np.where(over_h, fb, fa); along = np.where(over_h, fa, fb)
    gap = smooth(0.0, 0.08, across) * smooth(1.0, 0.92, across)
    start_h = ((i + j) % 4) == 0; start_v = ((i + j) % 4) == 2
    dive = np.where(over_h, np.where(start_h, 1 - smooth(0.0, 0.5, along), np.where(((i + j) % 4) == 1, 1 - smooth(1.0, 0.5, along), 0)),
                    np.where(start_v, 1 - smooth(0.0, 0.5, along), np.where(((i + j) % 4) == 3, 1 - smooth(1.0, 0.5, along), 0)))
    grain = 0.96 + 0.06 * vnoise(np.where(over_h, a * 0.6, a * 8), np.where(over_h, b * 8, b * 0.6), 9.0)
    lit = P[0] * tone * grain
    hue = hexc('#e8c88a')[None] * (1 - hs[:, None]) + hexc('#d9b274')[None] * hs[:, None]       # strips cut from different culms
    alb = lit[:, None] * hue * (1 - 0.3 * dive)[:, None]
    alb = alb * (0.45 + 0.55 * gap)[:, None] + hexc('#6a4a26')[None] * (1 - gap)[:, None] * 0.4
    # each strip is slightly round across: bump the normal across the strip
    s = (across - 0.5) * 2
    t = np.where(over_h[:, None], tang_b, tang_a)
    n = bump(nrm, t, -s, 0.45)
    # foot of the wall: dust and rain splash
    alb = alb * (1 - 0.25 * np.clip(1 - b / 6, 0, 1))[:, None]
    return np.clip(alb, 0, 1), n


def mat_weave_f(uv, prm, pos, nrm):
    return weave_tex(uv[:, 0], uv[:, 1], [1.0], np.array([1.0, 0, 0]), np.array([0, 0, 1.0]), nrm)


def mat_weave_r(uv, prm, pos, nrm):
    return weave_tex(uv[:, 0], uv[:, 1], [0.97], np.array([0, 1.0, 0]), np.array([0, 0, 1.0]), nrm)


def mat_leaf(uv, prm, pos, nrm):
    """one dried nipa leaflet: U along its length 0 root .. L tip, V across -1..1; prm = (tone idx, leaf len, seed)"""
    U, V = uv[:, 0], uv[:, 1]; L = prm[:, 1]; q = U / np.maximum(L, 1e-6)
    base = pal(THATCH[VARIANT], prm[:, 0])
    old = hash1(prm[:, 2], 5.0) < 0.05
    base = np.where(old[:, None], hexc('#a8844c')[None], base)
    base = base * (0.9 + 0.2 * hash1(prm[:, 2], 9.0))[:, None]         # each leaf its own shade
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    if WEATHER:
        a = vnoise(x * 0.055 + 3.0, y * 0.055 + 7.0, 11.0) * 0.7 + vnoise(x * 0.16, y * 0.16, 13.0) * 0.3
        g = (smooth(0.5, 0.8, a) * 0.5 * (prm[:, 0] < 10))[:, None]      # old leaves gone grey-brown in patches
        base = base * (1 - g) + hexc('#978767')[None] * g
        b_ = (smooth(RZ - 16, RZ - 2, z) * 0.22)[:, None]                 # sun-bleached near the ridge
        base = base * (1 - b_) + hexc('#e8dcae')[None] * b_
        base = base * (1 - 0.2 * smooth(EZ + 9, EZ - 1, z))[:, None]      # rain-darkened along the eave
        f = ((prm[:, 0] >= 10) * 0.55)[:, None]                         # whole leaves of a newer patch (set in slope())
        base = base * (1 - f) + hexc('#d4c072')[None] * f
    k = 0.56 + 0.52 * smooth(0.4, 0.86, q)                              # root tucked in shade, tip in the light
    vein = 1 - 0.2 * np.exp(-(V / 0.1) ** 2) - 0.08 * np.exp(-((np.abs(V) - 0.55) / 0.06) ** 2)
    streak = 0.95 + 0.08 * vnoise(V * 6 + prm[:, 2] * 3, U * 0.4, 4.0)
    alb = base * (k * vein * streak)[:, None]
    # fold: the two halves face slightly different ways
    return np.clip(alb, 0, 1), nrm


def mat_thend(uv, prm, pos, nrm):
    """thatch seen end-on (verge, eave thickness): packed straw ends"""
    a, b = uv[:, 0], uv[:, 1]
    n = vnoise(a * 2.2, b * 2.2, 2.0); m = vnoise(a * 7, b * 7, 6.0)
    base = pal(THATCH[VARIANT], 3) * (0.62 + 0.25 * n + 0.15 * m)[:, None]
    return np.clip(base, 0, 1), nrm


def mat_verge(uv, prm, pos, nrm):
    """thatch verge seen end-on: stacked layers of cut nipa leaves, each layer a thin band with its own tone"""
    a, b = uv[:, 0], uv[:, 1]
    lay = np.floor(b / 0.55); fb = b / 0.55 - lay
    seg = np.floor(a / 1.7 + hash1(lay, 1.0) * 3); fa = a / 1.7 + hash1(lay, 1.0) * 3 - seg
    h = hash1(lay, seg, 5.0)
    base = pal(THATCH[VARIANT], h * 5) * (0.72 + 0.22 * h)[:, None]
    line = (1 - 0.4 * smooth(0.78, 1.0, fb) - 0.08 * np.exp(-(fa / 0.05) ** 2)) * (0.9 + 0.12 * vnoise(a * 9, b * 1.5, 6.0))
    deep = 0.8 + 0.2 * smooth(0.0, 3.0, b)                           # underside darker
    return np.clip(base * (line * deep)[:, None], 0, 1), nrm


def mat_flat(col):
    c = hexc(col)
    def f(uv, prm, pos, nrm): return np.tile(c, (len(uv), 1)), nrm
    return f


def mat_wood(uv, prm, pos, nrm):
    """sawn log end: dark heartwood, pale sapwood, faint rings, saw scuffs, 2-3 radial checks, thin bark ring"""
    r = uv[:, 0]; th = uv[:, 1]; sd = prm[:, 0]
    wob = vnoise(th * 5 + sd * 9, sd * 3, 2.0) * 0.06
    rr = r + wob
    heart = hexc('#b98a52') * (0.9 + 0.12 * sd)[:, None]; sap = hexc('#e6c890') * (0.95 + 0.06 * sd)[:, None]
    base = heart + (sap - heart) * smooth(0.35, 0.62, rr)[:, None]
    rings = 0.5 + 0.5 * np.sin(rr * 30)
    base = base * (0.95 + 0.05 * rings)[:, None]
    saw = 0.97 + 0.04 * np.sin((pos[:, 1] * 0.9 + pos[:, 2] * 0.5) * 6 + sd * 7)
    base = base * saw[:, None]
    ang = th * 2 * math.pi
    chk = np.zeros_like(r)
    for k in range(3):
        a0 = (sd * 7.3 + k * 2.1) % (2 * math.pi)
        d = np.abs(np.angle(np.exp(1j * (ang - a0))))
        chk = np.maximum(chk, np.exp(-(d * np.maximum(rr, 0.05) / 0.018) ** 2) * smooth(0.12, 0.3, rr) * (k < 2 + (sd > 0.5)))
    base = base * (1 - 0.5 * chk)[:, None]
    bark = rr > 0.9
    base = np.where(bark[:, None], hexc('#4e3420')[None] * (0.85 + 0.25 * hash1(np.floor(th * 40), sd, 1.0))[:, None], base)
    cam = (rr > 0.86) & ~bark
    base = np.where(cam[:, None], base * 0.8, base)
    return np.clip(base, 0, 1), nrm


def mat_bark(uv, prm, pos, nrm):
    """rough bark along the log: long fissures, lighter plates, a few grey lichen spots"""
    L, th = uv[:, 0], uv[:, 1]
    fis = np.abs(np.sin(th * math.pi * 22 + vnoise(L * 0.25, th * 3, 3.0) * 3))
    plate = smooth(0.05, 0.4, fis)
    base = hexc('#73502f') * (0.55 + 0.5 * plate)[:, None]
    base = base * (0.92 + 0.12 * vnoise(L * 0.8, th * 20, 5.0))[:, None]
    lich = vnoise(L * 0.9 + 3, th * 22, 9.0) > 0.86
    base = np.where(lich[:, None], base * 0.75 + hexc('#8c8a74')[None] * 0.25, base)
    return np.clip(base, 0, 1), nrm


def mat_glaze(uv, prm, pos, nrm):
    U, V = uv[:, 0], uv[:, 1]
    base = hexc('#7a4224') * (0.95 + 0.08 * vnoise(V * 30, U * 10, 1.0))[:, None]
    foot = U < 0.14
    base = np.where(foot[:, None], hexc('#a87a58')[None], base)
    drip = (U > 0.13) & (U < 0.14 + 0.03 * (0.5 + 0.5 * np.sin(V * 2 * math.pi * 9)))
    base = np.where(drip[:, None], hexc('#6a3820')[None], base)
    return base, nrm


def mat_nia(uv, prm, pos, nrm):
    r, th = uv[:, 0], uv[:, 1]
    x = r * np.cos(th * 2 * math.pi) * 10; y = r * np.sin(th * 2 * math.pi) * 10
    a = (x + y) * 0.7; b = (y - x) * 0.7
    alb, _ = weave_tex(a + 50, b + 50, [1.0], np.array([0, 1.0, 0]), UP, nrm, cell=1.25)
    alb = alb * hexc('#e4b878')[None] / hexc('#e2c48a')[None]
    alb = alb * (1 - 0.3 * smooth(0.55, 1.0, r) + 0.08 * smooth(0.3, 0.0, r))[:, None]
    return alb, nrm


def mat_corn(uv, prm, pos, nrm):
    U, V = uv[:, 0], uv[:, 1]
    rows = np.abs(np.sin(U * 40)) ; cols = np.abs(np.sin(V * 2 * math.pi * 7))
    k = np.clip(rows * cols * 1.6, 0, 1)
    base = hexc('#f0b42a') * (0.7 + 0.35 * k)[:, None]
    return base, nrm


def mat_chilli(uv, prm, pos, nrm):
    h = hash1(np.floor(pos[:, 0] * 0.7), np.floor(pos[:, 2] * 0.45), 3.0)
    base = hexc('#902418') * (0.8 + 0.25 * h)[:, None] + hexc('#4a1006') * (0.2 * (h < 0.3))[:, None]
    return np.clip(base, 0, 1), nrm


def mat_gable_old(uv, prm, pos, nrm):
    """vách lá on the gable: vertical nipa leaves in rows of 8.5 units, bamboo battens"""
    a, b = uv[:, 0], uv[:, 1]
    row = np.floor(b / 8.5); f = b / 8.5 - row
    col = np.floor(a / 1.15 + row * 0.37); fa = a / 1.15 + row * 0.37 - col
    base = pal(THATCH[VARIANT], hash1(col, row, 2.0) * 5) * 0.85
    k = 0.7 + 0.35 * smooth(0.0, 0.9, f)
    edge = 1 - 0.3 * np.exp(-((fa - 0.02) / 0.05) ** 2)
    alb = base * (k * edge)[:, None]
    bat = np.abs(f - 0.36) < 0.08
    alb = np.where(bat[:, None], hexc('#b8955a')[None] * 0.95, alb)
    return np.clip(alb, 0, 1), nrm


def mat_gable(uv, prm, pos, nrm):
    """vách lá on the gable: rows of nipa leaves hanging down (pointed tips), tied on a batten at the top of each row"""
    a, b = uv[:, 0], uv[:, 1]
    RH = 6.5
    row = np.floor(b / RH); f = b / RH - row; fd = 1 - f                     # fd 0 top of row .. 1 tip
    wid = 1.1
    col = np.floor(a / wid + row * 0.43); fa = a / wid + row * 0.43 - col
    h = hash1(col, row, 2.0)
    tipcut = np.where(fd > 0.72, np.abs(fa - 0.5) > 0.5 * np.clip((1 - fd) / 0.28, 0, 1) * (0.9 + 0.2 * h), False)
    base = pal(THATCH[VARIANT], h * 5)
    k = 0.66 + 0.42 * smooth(0.05, 0.85, fd)                                 # top tucked under the row above, tip in light
    rib = 1 - 0.16 * np.exp(-((fa - 0.5) / 0.05) ** 2) - 0.22 * np.exp(-(np.minimum(fa, 1 - fa) / 0.035) ** 2)
    streak = 0.95 + 0.08 * vnoise(a * 5, b * 0.5, 4.0)
    alb = base * (k * rib * streak)[:, None]
    under = pal(THATCH[VARIANT], hash1(col, row - 1, 2.0) * 5) * 0.62           # the next row's tucked top shows between tips
    alb = np.where(tipcut[:, None], under, alb)
    bat = (f > 0.88) & (f < 0.95)
    alb = np.where(bat[:, None], hexc('#b8955a')[None] * (0.85 + 0.15 * smooth(0.88, 0.95, f))[:, None], alb)
    return np.clip(alb, 0, 1), nrm


def mat_stone(uv, prm, pos, nrm):
    return hexc('#a8a092') * (0.9 + 0.15 * vnoise(pos[:, 0] * 1.5, pos[:, 1] * 1.5, 4.0))[:, None], nrm


MATS = {M_EARTH: mat_earth, M_EARTHSIDE: mat_earthside, M_BAMBOO: mat_bamboo, M_WEAVE_F: mat_weave_f, M_WEAVE_R: mat_weave_r,
        M_LEAF: mat_leaf, M_THEND: mat_thend, M_DARK: mat_flat('#21160c'), M_WOOD: mat_wood, M_BARK: mat_bark, M_GLAZE: mat_glaze,
        M_LID: mat_flat('#a8804c'), M_NIA: mat_nia, M_CORN: mat_corn, M_HUSK: mat_flat('#e8d8a8'), M_CHILLI: mat_chilli,
        M_GABLE: mat_gable, M_STONE: mat_stone, M_RATTAN: mat_flat('#6a4422'), M_INSIDE: mat_flat('#4a3420'), M_GLOW: mat_flat('#3a2614'), M_VERGE: mat_verge}
GLOSS = {M_GLAZE: (0.35, 40.0), M_CHILLI: (0.3, 30.0)}


# ------------------------------------------------------------------ extra materials (big hut)
M_CLAY, M_POT, M_VONG, M_NON, M_FIRE, M_SOOT = range(22, 28)
VONG = [['#3d5f7a', '#a8483c', '#d8b860', '#3f6e58'], ['#7a4a5c', '#c89848', '#4a6a88', '#ddd2b8'],
        ['#3f6e58', '#ddd0a0', '#a8483c', '#4a5a80'], ['#a8483c', '#d8b860', '#3d5f7a', '#ddd2b8']]


def mat_clay(uv, prm, pos, nrm):
    """unglazed terracotta cà ràng: warm red-brown, hand-smoothed streaks, soot round the top"""
    U, V = uv[:, 0], uv[:, 1]
    base = hexc('#b0643a') * (0.9 + 0.1 * vnoise(V * 24, U * 6, 3.0) + 0.05 * vnoise(V * 80, U * 30, 7.0))[:, None]
    soot = smooth(0.55, 1.0, U)
    base = base * (1 - 0.55 * soot)[:, None] + hexc('#2a1c14') * (0.3 * soot)[:, None]
    return np.clip(base, 0, 1), nrm


def mat_pot(uv, prm, pos, nrm):
    U, V = uv[:, 0], uv[:, 1]
    base = hexc('#3b2c24') * (0.9 + 0.15 * vnoise(V * 30, U * 8, 2.0))[:, None]
    lip = smooth(0.82, 0.9, U)
    base = base * (1 + 0.25 * lip)[:, None]
    return np.clip(base, 0, 1), nrm


def mat_vong(uv, prm, pos, nrm):
    """võng dù: woven nylon in long colour stripes; U along the hammock, V across -1..1"""
    U, V = uv[:, 0], uv[:, 1]
    cols = np.array([hexc(h) for h in VONG[VARIANT]])
    band = np.floor((V + 1) * 4.5).astype(int)
    pick = np.array([0, 1, 0, 2, 3, 2, 0, 1, 0, 0])[np.clip(band, 0, 9)]
    base = cols[pick]
    fine = 0.94 + 0.08 * (np.sin(U * 9.0) * np.sin(V * 60.0) > 0)
    edge = 1 - 0.18 * smooth(0.82, 1.0, np.abs(V))
    return np.clip(base * (fine * edge)[:, None], 0, 1), nrm


def mat_non(uv, prm, pos, nrm):
    """nón lá: pale palm leaf with the ring frames showing as fine lines"""
    U, V = uv[:, 0], uv[:, 1]
    base = hexc('#ece0b6') * (0.94 + 0.06 * vnoise(V * 90, U * 3, 4.0))[:, None]
    ring = np.abs(np.sin(U * math.pi * 12))
    base = base * (0.86 + 0.14 * smooth(0.0, 0.25, ring))[:, None]
    seam = np.abs(np.sin(V * math.pi * 36))
    base = base * (0.95 + 0.05 * smooth(0.0, 0.3, seam))[:, None]
    return np.clip(base, 0, 1), nrm


def mat_cord(uv, prm, pos, nrm):
    base = hexc('#cbb487') * (0.86 + 0.16 * prm[:, :1] + 0.06 * np.sin(uv[:, :1] * 6.0 + uv[:, 1:2] * 20))
    return np.clip(base, 0, 1), nrm


def mat_plank(uv, prm, pos, nrm):
    a, b = uv[:, 0], uv[:, 1]
    g = 0.9 + 0.08 * vnoise(a * 0.6 + prm[:, 0] * 9, b * 6, 2.0) + 0.05 * np.sin(b * 9 + vnoise(a * 0.3, b, 5.0) * 4)
    return np.clip(hexc('#8a6440') * g[:, None], 0, 1), nrm


def mat_water(uv, prm, pos, nrm):
    r = uv[:, 0]; th = uv[:, 1] * 2 * math.pi
    y = r * np.sin(th - math.pi / 4)                        # toward the back rim the water mirrors the sky
    base = hexc('#25403e') * (1 - 0.15 * r)[:, None] + hexc('#9fb8b8') * (0.35 * smooth(0.1, 0.95, -y) * r)[:, None]
    ring = np.exp(-((r - 0.55 + 0.04 * np.sin(th * 3)) / 0.03) ** 2) * 0.12
    return np.clip(base + ring[:, None], 0, 1), nrm


def mat_coco(uv, prm, pos, nrm):
    U, V = uv[:, 0], uv[:, 1]
    fib = 0.85 + 0.2 * vnoise(V * 60, U * 4, 3.0) + 0.08 * np.sin(V * 2 * math.pi * 24 + U * 6)
    rim = smooth(0.85, 1.0, U)
    return np.clip(hexc('#5e3a20') * (fib * (1 + 0.35 * rim))[:, None], 0, 1), nrm


def mat_chieu(uv, prm, pos, nrm):
    a, b = uv[:, 0], uv[:, 1]
    st = np.floor(b / 1.4)
    red = (st % 6 == 1) | (st % 6 == 2); grn = st % 6 == 4
    base = np.where(red[:, None], hexc('#a83a2c')[None], np.where(grn[:, None], hexc('#4a6a3c')[None], hexc('#d8c48e')[None]))
    weave = 0.9 + 0.1 * (np.sin(a * 7.0) * np.sin(b * 22.0) > 0)
    edge = 1 - 0.25 * (np.sin(b * math.pi / 1.4) ** 2 < 0.04)
    return np.clip(base * (weave * edge)[:, None], 0, 1), nrm


def mat_ridge(uv, prm, pos, nrm):
    U, V = uv[:, 0], uv[:, 1]
    base = pal(THATCH[VARIANT], prm[:, 0]) * (0.72 + 0.26 * hash1(prm[:, 2], 7.0))[:, None]
    base = base * 0.62 + hexc('#958564')[None] * 0.38
    streak = 0.88 + 0.1 * vnoise(V * 9 + prm[:, 2] * 5, U * 0.6, 4.0) + 0.07 * np.sin(V * 19 + prm[:, 2] * 7)
    vein = 1 - 0.18 * np.exp(-(V / 0.12) ** 2)
    edge = (1 - 0.45 * smooth(0.35, 1.0, V)) * (1 - 0.15 * smooth(0.6, 1.0, -V)) * vein   # the +V side tucks under the next leaf
    return np.clip(base * (streak * edge * (0.92 + 0.12 * hash1(prm[:, 2], 3.0)))[:, None], 0, 1), nrm


def mat_oldbamboo(uv, prm, pos, nrm):
    a, n = mat_bamboo(uv, prm, pos, nrm)
    return np.clip(a * 0.62 + hexc('#8a8270')[None] * 0.3, 0, 1), n


def mat_split(uv, prm, pos, nrm):
    a, b = uv[:, 0], uv[:, 1]
    g = 0.88 + 0.1 * vnoise(a * 0.5, b * 30 + prm[:, 0] * 9, 2.0) + 0.04 * np.sin(b * 70)
    return np.clip(hexc('#c9a272') * g[:, None], 0, 1), nrm


def mat_grass(uv, prm, pos, nrm):
    q = np.clip(uv[:, 0] / np.maximum(prm[:, 1], 1e-3), 0, 1)
    base = hexc('#5d7f32') * (1 - q)[:, None] + hexc('#a6b85a') * q[:, None]
    return np.clip(base * (0.85 + 0.25 * prm[:, :1]), 0, 1), nrm


def mat_dryleaf(uv, prm, pos, nrm):
    c = hexc('#9a6a34') * (1 - prm[:, :1]) + hexc('#c8a050') * prm[:, :1]
    return np.clip(c * (0.9 + 0.1 * vnoise(pos[:, 0] * 2, pos[:, 1] * 2, 1.0))[:, None], 0, 1), nrm


M_RIDGE, M_OLDBAMBOO, M_SPLIT, M_EMBER, M_GRASS, M_DRYLEAF = range(36, 42)
MATS.update({M_RIDGE: mat_ridge, M_OLDBAMBOO: mat_oldbamboo, M_SPLIT: mat_split, M_EMBER: mat_flat('#ff5a14'), M_GRASS: mat_grass, M_DRYLEAF: mat_dryleaf})
M_CORD, M_PLANK, M_WATER, M_COCO = range(28, 32)
M_CHIEU, M_LAMPBASE, M_LAMPGLASS, M_FLAME = range(32, 36)
MATS.update({M_CHIEU: mat_chieu, M_LAMPBASE: mat_flat('#5a6a4a'), M_LAMPGLASS: mat_flat('#e8e2c8'), M_FLAME: mat_flat('#ffd070')})
GLOSS.update({M_LAMPGLASS: (0.5, 50.0)})
MATS.update({M_CORD: mat_cord, M_PLANK: mat_plank, M_WATER: mat_water, M_COCO: mat_coco})
GLOSS.update({M_WATER: (0.6, 60.0)})
MATS.update({M_CLAY: mat_clay, M_POT: mat_pot, M_VONG: mat_vong, M_NON: mat_non, M_FIRE: mat_flat('#ff9a3a'), M_SOOT: mat_flat('#1c140e')})
GLOSS.update({M_POT: (0.18, 30.0)})


# ------------------------------------------------------------------ the model
def wall(S, Y, u0, u1, z0, z1, holes, mat):
    """woven wall in the plane Y between u0..u1, z0..z1, cut by rectangular holes [(a0, a1, h0, h1)]"""
    cuts = sorted(set([u0, u1] + [h[0] for h in holes] + [h[1] for h in holes]))
    for a, b in zip(cuts[:-1], cuts[1:]):
        zs = [z0, z1]
        for h in holes:
            if h[0] <= a and b <= h[1]: zs += [h[2], h[3]]
        zs = sorted(zs); spans = []
        hs = [h for h in holes if h[0] <= a and b <= h[1]]
        lo = z0
        for h in sorted(hs, key=lambda h: h[2]):
            if h[2] > lo: spans.append((lo, h[2]))
            lo = h[3]
        if z1 > lo: spans.append((lo, z1))
        for (za, zb) in spans:
            plane(S, (a * T, Y, za), ((b - a) * T, 0, 0), (0, 0, zb - za), max(2, int((b - a) * T / 3)), max(2, int((zb - za) / 3)), mat)


def roof_z(v):
    """top of the main roof's underlay at v"""
    return RZ - abs(v - RV) * ((RZ - EZ) / (EV - RV) if v > RV else (RZ - BZ) / (RV - BV))


def build(t, rng):
    S = Scene(); LIGHTS.clear()
    LIGHTS.append((LAMP, hexc('#ffb45a'), 13.0, 2.4))                 # the oil lamp inside: lights the room, spills out of door and windows
    rrect_top(S, PL[0], PL[1], PL[2], PL[3], 0.12, ZF, M_EARTH)
    extrude(S, rrect(PL[0], PL[1], PL[2], PL[3], 0.12), 0.0, ZF, M_EARTHSIDE, flare=0.9)
    Y1 = V1 * T; X1 = U1 * T
    da0, da1, dh = DOOR; wb0, wb1 = WZ
    holes = [(da0, da1, ZF, dh)] + [(w0, w1, wb0, wb1) for (w0, w1) in WIN]
    wall(S, Y1, U0, U1, ZF, ZW, holes, M_WEAVE_F)
    interior(S, rng)
    for (w0, w1) in WIN:
        for i in range(1, 6):                                          # song cửa: round bamboo bars
            u = w0 + (w1 - w0) * i / 6
            tube(S, W3(u, V1 + 0.01, wb0), W3(u, V1 + 0.01, wb1), 0.55, M_BAMBOO, prm=(rng.random(), rng.random(), 0), nr=8, nl=3)
    # right wall (inside the kitchen) and the gable above the lean-to
    plane(S, (X1, V0 * T, ZF), (0, (V1 - V0) * T, 0), (0, 0, ZW - ZF), 26, 14, M_WEAVE_R)
    def gF(U, Vv):
        v = V0 + U / T; ztop = np.array([roof_z(x) - 3.6 for x in v.ravel()]).reshape(v.shape)
        return np.stack([np.full_like(U, X1), v * T, ZW + Vv * (ztop - ZW)], -1)
    S.grid(gF, 34, 8, M_GABLE, (0, 0, 0), 0.0, uvr=((0, (V1 - V0) * T), (0, 1)))
    # frame: corner and bay posts, door and window posts, rails
    def post(u, v, r, zt, z0=ZF):
        uo = 0.012 if u == U1 else 0.0; vo = 0.015 if v == V1 else 0.0
        tube(S, W3(u + uo, v + vo, z0), W3(u + uo, v + vo, zt), r, M_BAMBOO, prm=(rng.random(), rng.random(), 1), taper=0.9)
    for u in (U0,) + GAP + (U1,): post(u, V1, 1.35, ZW)
    post(U1, V0, 1.35, ZW)
    post(U1, (V0 + V1) / 2, 1.2, ZW)
    for u in (da0, da1): post(u - 0.0, V1, 0.95, dh + 1.5)
    for (w0, w1) in WIN:
        for u in (w0, w1): post(u, V1, 0.8, wb1 + 1.2)
    def rail(a, b, r):
        tube(S, a, b, r, M_BAMBOO, prm=(rng.random(), rng.random(), 0), nr=8, nl=8)
    rail(W3(U0, V1 + 0.02, 13), W3(da0 - 0.02, V1 + 0.02, 13), 0.75); rail(W3(da1 + 0.02, V1 + 0.02, 13), W3(U1, V1 + 0.02, 13), 0.75)
    rail(W3(da0 - 0.03, V1 + 0.02, dh + 0.8), W3(da1 + 0.03, V1 + 0.02, dh + 0.8), 0.8)
    for (w0, w1) in WIN:
        rail(W3(w0 - 0.01, V1 + 0.02, wb0 - 0.4), W3(w1 + 0.01, V1 + 0.02, wb0 - 0.4), 0.75)
        rail(W3(w0 - 0.01, V1 + 0.02, wb1 + 0.5), W3(w1 + 0.01, V1 + 0.02, wb1 + 0.5), 0.7)
    rail(W3(U0, V1 + 0.02, ZW), W3(U1, V1 + 0.02, ZW), 0.9); rail(W3(U1 + 0.02, V0, ZW), W3(U1 + 0.02, V1, ZW), 0.9)
    rail(W3(U1 + 0.02, V0, 13), W3(U1 + 0.02, V1, 13), 0.75)
    # porch posts on stones, eave beam
    for u in (U0, U1):                                                 # only the two corner posts: open porch (Link)
        S0 = Scene(); X3.ellipsoid(S0, W3(u, PV, ZF), 2.8, 2.4, 1.2, M_STONE, zmin=0.5); S.merge(S0)
        tube(S, W3(u, PV, ZF + 0.6), W3(u, PV, EZ + 0.5), 1.6, M_BAMBOO, prm=(rng.random(), rng.random(), 1), taper=0.9)
    # the long span carried by a doubled bamboo beam (đòn đôi), lashed at the posts and twice along the span
    rail(W3(RU0 + 0.05, PV, EZ - 0.5), W3(RU1 - 0.05, PV, EZ - 0.5), 1.15)
    rail(W3(RU0 + 0.05, PV + 0.005, EZ - 2.75), W3(RU1 - 0.05, PV + 0.005, EZ - 2.75), 1.05)
    for u in (U0, (U0 + U1) / 2 - 0.33, (U0 + U1) / 2 + 0.33, U1):
        for k in range(4):
            a0 = k * 1.6
            c = W3(u + 0.03 * (k - 1.5), PV, EZ - 1.6)
            tube(S, c + np.array([0, 1.3 * math.cos(a0), 1.9 * math.sin(a0) - 0.3 * k]), c + np.array([0, 1.3 * math.cos(a0 + 2.7), 1.9 * math.sin(a0 + 2.7) - 0.3 * k]), 0.3, M_RATTAN, nr=5, nl=2)
    kitchen(S, rng)
    vong(S, rng, t); chong(S, rng); jar(S, rng, W3(2.5, 1.56, ZF), 0.9)
    hang(S, rng, t, W3(0.18, PV + 0.03, EZ - 3.5))
    roof(S, rng, t)
    return S


LIGHTS = []


def yard(S, rng):
    """grass at the foot of the earth platform, a few dry leaves, a straw broom against the left porch post"""
    edge = rrect(PL[0] - 0.02, PL[1] + 0.02, PL[2] - 0.02, PL[3] + 0.03, 0.3, n=14)
    P = np.array(edge + [edge[0]]); seg = np.linalg.norm(np.diff(P, axis=0), axis=1); cs = np.concatenate([[0], np.cumsum(seg)])
    cen = P[:-1].mean(0)
    for s_ in np.sort(rng.uniform(0, cs[-1], 70)):
        x = np.interp(s_, cs, P[:, 0]); y = np.interp(s_, cs, P[:, 1])
        if x + y < cen[0] + cen[1] - 30 and rng.random() < 0.6: continue    # mostly on the front sides (the back is hidden)
        o = nv([x - cen[0], y - cen[1], 0]); base = np.array([x, y, 0.0]) + o * rng.uniform(0.3, 1.6)
        for b in range(rng.integers(4, 8)):
            h = rng.uniform(2.0, 4.6); d = nv(o * rng.uniform(0.2, 0.7) + np.array([rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 1.0]))
            tip = base + d * h + o * 0.6
            tube(S, base + np.array([rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0]), tip, 0.32, M_GRASS, prm=(rng.random(), h, 0), nr=4, nl=2, taper=0.15)
    for (u, v) in ((0.62, 1.86), (0.95, 1.5), (1.55, 1.82), (1.92, 1.72), (2.66, 1.85), (2.86, 1.42), (0.22, 1.35), (1.25, 1.66)):
        c = W3(u + rng.uniform(-0.03, 0.03), v + rng.uniform(-0.03, 0.03), ZF + 0.15); an = rng.uniform(0, math.pi)
        ax_ = (np.array([math.cos(an), math.sin(an), 0]), np.array([-math.sin(an), math.cos(an), 0]), UP)
        S0 = Scene(); X3.ellipsoid(S0, c, 1.4, 0.65, 0.18, M_DRYLEAF, prm=(rng.random(), 0, 0), axes=ax_, nu=6, nvv=10); S.merge(S0)
    # chổi rơm leaning on the left porch post
    foot = W3(U0 + 0.1, PV + 0.07, ZF + 0.2); top = W3(U0 + 0.02, PV + 0.035, ZF + 24)
    d = nv(top - foot); bind = foot + d * 6.5
    tube(S, bind, top, 0.4, M_PLANK, prm=(0.3, 0, 0), nr=6, nl=3)
    side = nv(np.cross(d, UP))
    for i in range(16):
        sp = (i / 15 - 0.5) * 3.4
        tube(S, bind + side * sp * 0.15, foot + side * sp + np.array([0, 0, rng.uniform(-0.1, 0.3)]), 0.3, M_HUSK, nr=4, nl=2)
    for k in (0.0, 0.8):
        c = bind + d * k
        pts = [c + (side * math.cos(a) + nv(np.cross(side, d)) * math.sin(a)) * 0.75 for a in np.linspace(0, 2 * math.pi, 9)]
        for i in range(8): tube(S, pts[i], pts[i + 1], 0.2, M_RATTAN, nr=4, nl=2)


LAMP = W3(1.06, 0.97, ZF + 12.6)


def splitlog(S, rng, xa, xb, y, z, R):
    a0 = rng.uniform(0, 2 * math.pi); sw = rng.uniform(1.6, 2.2)              # sector start and width (rad)
    c = np.array([0.0, y, z]) - np.array([0, math.cos(a0 + sw / 2), math.sin(a0 + sw / 2)]) * R * 0.45   # centre the slice on its slot
    def Fa(U, V):
        th = a0 + V * sw
        return np.stack([xa + U * 0 + U, c[1] + np.cos(th) * R + U * 0, c[2] + np.sin(th) * R + U * 0], -1)
    S.grid(lambda U, V: np.stack([U, c[1] + np.cos(a0 + V * sw) * R + U * 0, c[2] + np.sin(a0 + V * sw) * R + U * 0], -1),
           2, 10, M_BARK, (0, 0, 0), 0.0, uvr=((xa, xb), (0, 1)))
    for th in (a0, a0 + sw):
        d = np.array([0, math.cos(th), math.sin(th)])
        plane(S, (xa, c[1], c[2]), (xb - xa, 0, 0), d * R, 4, 2, M_SPLIT, prm=(rng.random(), 0, 0))
    S.grid(lambda U, V: np.stack([np.full_like(U, xb), c[1] + np.cos(a0 + V * sw) * U * R, c[2] + np.sin(a0 + V * sw) * U * R], -1),
           4, 10, M_WOOD, (rng.random(), 0, 0), 0.0, uvr=((0, 1), ((a0) / (2 * math.pi), (a0 + sw) / (2 * math.pi))))


def interior(S, rng):
    """the room seen through the door and windows: back and end walls, bộ ván with a sedge mat, a low table with an
    oil lamp, a rice jar in the right bay"""
    plane(S, (U0 * T, V0 * T, ZF), ((U1 - U0) * T, 0, 0), (0, 0, ZW - ZF), 26, 14, M_WEAVE_F)
    plane(S, (U0 * T, V0 * T, ZF), (0, (V1 - V0) * T, 0), (0, 0, ZW - ZF), 14, 14, M_WEAVE_R)
    for u in GAP:                                                     # inner bay posts
        tube(S, W3(u, V0 + 0.01, ZF), W3(u, V0 + 0.01, ZW), 1.2, M_BAMBOO, prm=(rng.random(), rng.random(), 1), nr=8, nl=4)
    # bộ ván: thick planks on a frame, a red-striped sedge mat on it
    u0, u1, v0, v1, zt = 0.4, 0.98, 0.36, 0.98, ZF + 6.5
    for (u, v) in ((u0 + 0.03, v0 + 0.03), (u1 - 0.03, v0 + 0.03), (u0 + 0.03, v1 - 0.03), (u1 - 0.03, v1 - 0.03)):
        tube(S, W3(u, v, ZF), W3(u, v, zt - 1.2), 0.9, M_PLANK, prm=(rng.random(), 0, 0), nr=6, nl=2)
    plane(S, (u0 * T, v0 * T, zt), ((u1 - u0) * T, 0, 0), (0, (v1 - v0) * T, 0), 10, 10, M_PLANK, prm=(0.3, 0, 0))
    plane(S, (u0 * T, v1 * T, zt - 1.4), ((u1 - u0) * T, 0, 0), (0, 0, 1.4), 10, 2, M_PLANK, prm=(0.6, 0, 0))
    plane(S, (u1 * T, v0 * T, zt - 1.4), (0, (v1 - v0) * T, 0), (0, 0, 1.4), 10, 2, M_PLANK, prm=(0.8, 0, 0))
    plane(S, ((u0 + 0.06) * T, (v0 + 0.04) * T, zt + 0.12), ((u1 - u0 - 0.12) * T, 0, 0), (0, (v1 - v0 - 0.2) * T, 0), 10, 10, M_CHIEU)
    S0 = Scene(); X3.ellipsoid(S0, W3(0.6, 0.48, zt + 1.4), 3.2, 1.8, 1.3, M_HUSK, zmin=0.45); S.merge(S0)   # pillow
    # low round table, oil lamp on it (glass chimney, glowing flame), a teapot
    tc = W3(1.06, 0.97, ZF)
    for a in (0.25 * math.pi, 0.75 * math.pi, 1.25 * math.pi, 1.75 * math.pi):   # four straight legs, square under the top
        p = tc + np.array([2.0 * math.cos(a), 2.0 * math.sin(a), 0])
        tube(S, p, p + np.array([0, 0, 7.5]), 0.42, M_PLANK, prm=(0.2, 0, 0), nr=6, nl=2)
    for a in (0.25 * math.pi, 0.75 * math.pi, 1.25 * math.pi, 1.75 * math.pi):   # stretchers between the legs
        p = tc + np.array([2.0 * math.cos(a), 2.0 * math.sin(a), 2.2]); q = tc + np.array([2.0 * math.cos(a + math.pi / 2), 2.0 * math.sin(a + math.pi / 2), 2.2])
        tube(S, p, q, 0.28, M_PLANK, prm=(0.2, 0, 0), nr=5, nl=2)
    lathe(S, tc + np.array([0, 0, 7.4]), [(0, 3.4), (0.5, 3.5), (0.8, 3.4)], M_PLANK)
    disc(S, tc + np.array([0, 0, 8.2]), (0, 0, 1), 3.4, M_PLANK, nr=3, na=24)
    lb = LAMP - np.array([0, 0, 4.2])
    lathe(S, lb, [(0, 1.3), (0.4, 1.4), (1.2, 1.2), (1.6, 0.5), (1.9, 0.45)], M_LAMPBASE)
    lathe(S, lb + np.array([0, 0, 1.9]), [(0, 0.5), (0.9, 0.95), (2.0, 1.05), (3.0, 0.7), (4.4, 0.55)], M_LAMPGLASS)
    S0 = Scene(); X3.ellipsoid(S0, LAMP - np.array([0, 0, 0.9]), 0.32, 0.32, 0.75, M_FLAME, nu=6, nvv=8); S.merge(S0)
    lathe(S, tc + np.array([-1.9, 1.0, 8.2]), [(0, 0.8), (0.8, 1.3), (1.6, 1.1), (2.0, 0.6), (2.3, 0.65)], M_POT)
    # rice jar in the right bay, seen through the right window
    jc = W3(1.78, 0.86, ZF)
    lathe(S, jc, [(z, r) for z, r in [(0, 3.4), (1.5, 4.8), (5, 5.6), (10, 5.2), (13, 3.9), (14, 3.6), (14.5, 3.9)]], M_GLAZE)
    disc(S, jc + np.array([0, 0, 14.6]), (0, 0, 1), 3.9, M_NIA, nr=3, na=24, dome=0.1)


def kitchen(S, rng):
    """chái bếp: lean-to on the right gable, woven back wall, open front and side, clay stove, pot, firewood"""
    v0, v1 = V0 + 0.02, 1.26
    zr = lambda u: KZ0 + (KZ1 - KZ0) * (u - U1) / (KU - U1)
    def bF(U, Vv):
        u = U1 + U / T; top = np.array([zr(x) - 2.0 for x in u.ravel()]).reshape(u.shape)
        return np.stack([u * T, np.full_like(U, v0 * T), ZF + Vv * (top - ZF)], -1)
    S.grid(bF, 12, 10, M_WEAVE_R, (0, 0, 0), 0.0, uvr=((0, (KU - U1) * T), (0, 1)))
    for v in (v0, v1):
        tube(S, W3(KU, v, ZF), W3(KU, v, KZ1 + 0.5), 1.25, M_BAMBOO, prm=(rng.random(), rng.random(), 1), taper=0.9)
        tube(S, W3(U1 + 0.02, v, KZ0 - 0.6), W3(KU + 0.08, v, KZ1 - 0.8), 0.9, M_BAMBOO, prm=(rng.random(), rng.random(), 0), nr=8, nl=8)
    tube(S, W3(KU, v0 - 0.08, KZ1 - 0.3), W3(KU, v1 + 0.1, KZ1 - 0.3), 0.85, M_BAMBOO, prm=(rng.random(), rng.random(), 0), nr=8, nl=8)
    # cà ràng (clay stove) with its mouth toward the open front, a black clay pot on it
    c = W3(2.47, 1.1, ZF)
    lathe(S, c, [(0, 4.0), (0.6, 3.9), (2.4, 3.5), (4.8, 3.4), (6.0, 3.7), (6.5, 3.5), (6.8, 2.7)], M_CLAY)
    f = nv([0.5, 1.0, 0.0]); mouth = c + f * 3.45 + np.array([0, 0, 2.4])
    disc(S, mouth, f, 1.9, M_SOOT, nr=3, na=18, dome=-0.3)
    disc(S, mouth + f * 0.05, f, 1.25, M_EMBER, nr=3, na=18, dome=-0.2)
    a_ = nv(np.cross(UP, f))
    def flame(base, h, r):
        lathe(S, base, [(0, r * 0.7), (h * 0.18, r), (h * 0.45, r * 0.8), (h * 0.75, r * 0.4), (h, 0.0)], M_FIRE, na=14)
    for (dx, h, r) in ((-0.55, 3.0, 0.62), (0.15, 3.8, 0.75), (0.75, 2.6, 0.55)):   # tongues licking out and up the stove's face
        flame(mouth + f * 0.9 + a_ * dx + np.array([0, 0, -1.4]), h, r)
    disc(S, c + np.array([0, 0, 6.75]), (0, 0, 1), 2.75, M_EMBER, nr=3, na=24)   # embers glowing in the gap under the pot
    LIGHTS.append((mouth + f * 1.5 + np.array([0, 0, 1.5]), hexc('#ff8a30'), 10.0, 2.2))
    for k in range(3):
        a = k * 2.1 + 0.4
        S0 = Scene(); X3.ellipsoid(S0, c + np.array([2.9 * math.cos(a), 2.9 * math.sin(a), 7.1]), 0.85, 0.85, 1.1, M_CLAY, zmin=-9); S.merge(S0)
    lathe(S, c + np.array([0, 0, 6.8]), [(0, 1.2), (0.9, 2.8), (2.4, 3.4), (3.8, 3.0), (4.5, 2.4), (4.7, 2.6)], M_POT)
    disc(S, c + np.array([0, 0, 11.4]), (0, 0, 1), 2.5, M_POT, nr=3, na=20, dome=0.12)
    # sticks fed into the mouth
    for k in range(3):
        sd = nv(np.cross(UP, f)) * (k - 1) * 0.9
        tube(S, mouth + sd + np.array([0, 0, -1.3]) - f * 0.8, mouth + sd * 2.2 + f * 5.5 + np.array([0, 0, -2.0]), 0.45, M_BARK, nr=6, nl=2)
    # firewood stacked at the back right, cut ends out to the right
    rows = [(4.2, 5), (8.0, 4), (11.6, 4), (15.0, 3)]
    for ri, (zc, n) in enumerate(rows):
        a0, a1 = v0 + 0.06, 0.7
        span = (a1 - a0) * T - ri * 1.4
        for j in range(n):
            y = a0 * T + ri * 0.7 + (j + 0.5) * span / n + rng.uniform(-0.3, 0.3)
            z = zc + rng.uniform(-0.3, 0.3); r = rng.uniform(1.35, 2.3)
            x1 = (KU + 0.05) * T + rng.uniform(-1.2, 0.6)
            if rng.random() < 0.35:                                    # củi chẻ: a quarter/third of a big log
                splitlog(S, rng, (U1 + 0.25) * T, x1, y, z, r * 1.5)
            else:
                tube(S, ((U1 + 0.25) * T, y, z), (x1, y, z), r, M_BARK, nr=12, nl=2)
                disc(S, (x1, y, z), (1, 0, 0), r, M_WOOD, prm=(rng.random(), 0, 0), nr=5, na=20)
    # lean-to roof: thatch along v, sloping down to the right
    e = W3(KU + 0.15, v0 - 0.12, KZ1 - 1.2); top = W3(U1 + 0.02, v0 - 0.12, KZ0 + 1.5)
    up = top - e; LB = np.linalg.norm(up); su = up / LB; ax = np.array([0, 1.0, 0])
    n_out = nv(np.cross(su, ax))
    if n_out[2] < 0: n_out = -n_out
    slope(S, rng, e, su, n_out, LB, ax, (v1 + 0.16 - (v0 - 0.12)) * T, th=3.2, course=3.2)


def vong(S, rng, t):
    """võng lưới đay: a knotted jute-cord net hammock, slung from the left porch post to the house's first bay post"""
    p0 = W3(U0 + 0.03, PV - 0.02, 27.0); p1 = W3(GAP[0] - 0.02, V1 + 0.05, 27.0); L = np.linalg.norm(p1 - p0); d = (p1 - p0) / L
    side = nv(np.cross(UP, d))
    def P(q, V):
        sag = 18.0 * np.sin(math.pi * q) ** 0.85
        w = 0.15 + 3.1 * smooth(0.05, 0.32, q) * smooth(0.95, 0.68, q)
        curl = 1.7 * V ** 2 * w / 3.25
        return p0 + d * (q * L) + side * (V * w) + UP * (-sag + curl)
    def cord(qs, Vs, r, mat=M_CORD):
        pts = [P(q, v) for q, v in zip(qs, Vs)]
        for a, b in zip(pts[:-1], pts[1:]): tube(S, a, b, r, mat, prm=(rng.random(), 0, 0), nr=5, nl=2)
    qs = np.linspace(0.0, 1.0, 64)
    n, K = 6, 4.0
    tri = lambda x: 2 * np.abs(2 * (x - np.floor(x)) - 1) - 1
    for i in range(n):
        cord(qs, tri(qs * K + i / n), 0.2)
        cord(qs, tri(-qs * K + i / n + 0.5 / n), 0.2)
    for e in (-1, 1): cord(qs, np.full_like(qs, e), 0.32)
    for p in (p0, p1):                                                # rope gathered and tied round the post
        tube(S, p + np.array([0, 0, 0.9]), p - np.array([0, 0, 0.7]), 1.75, M_CORD, nr=8, nl=2)


def chong(S, rng):
    """chõng tre: a low bamboo daybed in the right bay of the porch, a nón lá on it"""
    u0, u1, v0, v1, zt = 1.72, 2.2, 1.27, 1.54, ZF + 6.5
    for (u, v) in ((u0 + 0.03, v0 + 0.03), (u1 - 0.03, v0 + 0.03), (u0 + 0.03, v1 - 0.03), (u1 - 0.03, v1 - 0.03)):
        tube(S, W3(u, v, ZF), W3(u, v, zt), 0.85, M_BAMBOO, prm=(rng.random(), rng.random(), 1), nr=8, nl=3)
    for v in (v0, v1):
        tube(S, W3(u0 - 0.03, v, zt - 1.0), W3(u1 + 0.03, v, zt - 1.0), 0.95, M_BAMBOO, prm=(rng.random(), rng.random(), 0), nr=8, nl=6)
    for u in (u0, u1):
        tube(S, W3(u, v0 - 0.02, zt - 2.6), W3(u, v1 + 0.02, zt - 2.6), 0.8, M_BAMBOO, prm=(rng.random(), rng.random(), 0), nr=8, nl=4)
    n = 7
    for i in range(n):
        v = v0 + 0.02 + (v1 - v0 - 0.04) * (i + 0.5) / n
        tube(S, W3(u0 - 0.02, v, zt), W3(u1 + 0.02, v, zt), 0.62, M_BAMBOO, prm=(rng.random(), rng.random(), 0), nr=8, nl=6)
    c = W3(1.88, 1.41, zt + 0.5); R = 3.3
    lathe(S, c, [(0, R), (0.5, R * 0.85), (1.3, R * 0.62), (2.3, R * 0.38), (3.1, R * 0.15), (3.5, 0.0)], M_NON)


def jar(S, rng, c, k):
    """lu nước: glazed jar, open at the front so the water shows, two loose boards over the back, gáo dừa on the boards"""
    lathe(S, c, [(z * k, r * k) for z, r in [(0, 3.6), (1.5, 5.2), (5, 6.3), (9, 6.0), (12, 4.4), (13, 3.9), (13.5, 4.1)]], M_GLAZE)
    zt = 13.5 * k
    disc(S, c + np.array([0, 0, zt - 0.7]), (0, 0, 1), 3.75 * k, M_WATER, nr=4, na=28)
    bk = nv([-1.0, -1.0, 0]); ac = nv([1.0, -1.0, 0])
    for off, wd in ((2.35, 2.5),):                       # boards along (1,-1), the back half of the mouth
        o = c + bk * off * k + np.array([0, 0, zt + 0.15])
        plane(S, o - ac * 4.6 * k - bk * wd / 2 * k, ac * 9.2 * k, bk * wd * k, 6, 2, M_PLANK, prm=(rng.random(), 0, 0))
        plane(S, o - ac * 4.6 * k - bk * wd / 2 * k, ac * 9.2 * k, np.array([0, 0, -0.55]), 6, 2, M_PLANK, prm=(rng.random(), 0, 0))
    g = c + bk * 2.3 * k - ac * 1.0 + np.array([0, 0, zt + 0.15])           # gáo dừa: deep half coconut shell, a stick handle through its rim
    lathe(S, g, [(0, 0.3), (0.25, 0.9), (0.6, 1.3), (1.05, 1.52), (1.45, 1.58), (1.6, 1.52)], M_COCO)
    disc(S, g + np.array([0, 0, 1.5]), (0, 0, 1), 1.45, M_SOOT, nr=3, na=20, dome=-0.35)
    hd = nv(ac * 0.8 + bk * 0.6)
    tube(S, g + hd * 1.2 + np.array([0, 0, 1.25]), g + hd * 5.4 + np.array([0, 0, 3.4]), 0.36, M_PLANK, prm=(0.4, 0.1, 0), nr=6, nl=4)


def hang(S, rng, t, top):
    tube(S, top + np.array([0, 0, 2.5]), top - np.array([0, 0, 1.5]), 0.2, M_RATTAN, nr=5, nl=2)
    if t % 2 == 0:
        for (dx, dz, tl) in [(-1.6, -0.4, 0.2), (0.2, -1.0, -0.05), (1.8, -0.2, -0.22)]:
            c = top + np.array([dx, 0.6, -5.5 + dz])
            S0 = Scene(); ax = (nv([math.cos(tl), 0, math.sin(tl)]), np.array([0, 1.0, 0]), nv([-math.sin(tl), 0, math.cos(tl)]))
            X3.ellipsoid(S0, c, 1.35, 1.35, 4.2, M_CORN, axes=ax, nu=12, nvv=14); S.merge(S0)
            for hd in (-1, 1):
                tube(S, c + np.array([0, 0, 3.6]), c + np.array([hd * 1.6, 0.3, 7.0]), 0.55, M_HUSK, nr=6, nl=3, taper=0.3)
    else:
        for j in range(4):
            for k in (-1, 0, 1):
                if j == 3 and k: continue
                c = top + np.array([k * 0.6, 0.5 + 0.2 * (k == 0), -1.4 - j * 1.75])
                tube(S, c, c + np.array([k * 1.1, 0.25, -2.7]), 0.42, M_CHILLI, nr=7, nl=3, taper=0.3)


PATCH = (40.0, 58.0, 8.0, 22.0)                                     # a newer patch on the front slope: along-eave units, up-slope units


def slope(S, rng, e, su, n_out, LB, ax, Lu, th=4.4, course=3.6):
    """one roof slope from eave e up along su: underlay slab, end face at e + ax*Lu, eave lip, courses of nipa leaflets"""
    Lc = Lu - 1.8                                                      # underlay stops short: the leaves' own ragged ends make the verge
    plane(S, e - n_out * th, ax * Lc, su * LB, 8, 8, M_THEND)
    plane(S, e + ax * Lc - n_out * th, su * LB, n_out * (th + 0.4), 10, 3, M_THEND)
    plane(S, e - n_out * th + su * 1.2, ax * Lc, n_out * (th + 0.4), 20, 2, M_THEND)
    nC = int(LB / course) + 2
    for i in range(nC):
        b0 = i * course * rng.uniform(0.96, 1.04) - 1.2
        a = -1.4 - rng.uniform(0, 0.8)
        while a < Lu + 1.2:
            w = rng.uniform(1.0, 1.6); Lf = course * rng.uniform(1.9, 2.3); tip = b0 - rng.uniform(0.0, 0.9) - (0.8 if i == 0 else 0)
            sag = 1.1 * math.sin(math.pi * min(1, max(0, a / Lu))) * (1 - max(0, b0) / LB)
            tip -= sag
            tone = rng.integers(5); seed = rng.random(); lift = 1.45 + rng.uniform(-0.25, 0.25); sk = rng.uniform(-0.25, 0.25)
            if PATCH and PATCH[0] < a < PATCH[1] and PATCH[2] < b0 < PATCH[3] and abs(su[2]) > 0.3 and su[1] < 0: tone += 10
            tq = rng.uniform(0.62, 0.9)
            def F(U, V, aa=a, w=w, Lf=Lf, tip=tip, lift=lift, sk=sk, tq=tq):
                q = U / Lf
                width = w * 0.5 * np.where(q < tq, 1.0, np.clip((1 - q) / (1 - tq), 0, 1) ** 0.8)
                bb = np.minimum(tip + Lf * (1 - q), LB - 0.4)
                x = aa + w * 0.5 + V * width + sk * q
                nn = lift * q + 0.1 + 0.18 * (1 - V ** 2)
                return e[None, None] + ax[None, None] * x[..., None] + su[None, None] * bb[..., None] + n_out[None, None] * nn[..., None]
            S.grid(F, 6, 3, M_LEAF, (tone, Lf, seed), 0.0, uvr=((0, Lf), (-1, 1)))
            a += w * rng.uniform(0.62, 0.8)


def roof(S, rng, t):
    ax = np.array([1.0, 0, 0]); Lu = (RU1 - RU0) * T
    e_front = W3(RU0, EV, EZ); up = W3(RU0, RV, RZ) - e_front; LB = np.linalg.norm(up); su = up / LB
    n_out = nv(np.cross(ax, su))
    if n_out[2] < 0: n_out = -n_out
    slope(S, rng, e_front, su, n_out, LB, ax, Lu)
    e_back = W3(RU0, BV, BZ); up_b = W3(RU0, RV, RZ) - e_back; LBb = np.linalg.norm(up_b); sub = up_b / LBb
    nb = nv(np.cross(sub, ax))
    if nb[2] < 0: nb = -nb
    slope(S, rng, e_back, sub, nb, LBb, ax, Lu)
    for fr in (0.42, 0.78):                                            # two battens where they were before (Link), old grey bamboo
        p0 = e_front + su * LB * fr + n_out * 1.9 + ax * 1.0
        tube(S, p0, p0 + ax * (Lu - 1.6), 0.8, M_OLDBAMBOO, prm=(rng.random(), 0.5, 0), nr=8, nl=14)
    R = 3.1                                                             # ridge as slim as the old roll (Link)
    def Fr(U, V):
        th = V * math.pi
        y = RV * T + np.cos(th) * R * 1.0; z = RZ + 0.6 + np.sin(th) * R * 0.92
        return np.stack([RU0 * T - 1 + U, y, z], -1)
    S.grid(Fr, 60, 9, M_THEND, (0, 0, 0), 0.0, uvr=((0, Lu + 2), (0, 1)))
    x = RU0 * T - 1.4
    A0, A1 = -0.55, math.pi + 0.55; arc = (A1 - A0) * R * 1.05
    while x < RU0 * T + Lu + 1.2:                                       # nipa leaves folded over the ridge, one beside the next
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
        S.grid(Fs, 18, 3, M_RIDGE, (tone, arc, seed), 0.0, uvr=((0, arc), (-1, 1)))
        x += w * rng.uniform(0.7, 0.9)
    zp = RZ + 0.6 + R * 1.04 + 0.75
    tube(S, (RU0 * T - 0.5, RV * T, zp), (RU0 * T + Lu + 0.5, RV * T, zp - 0.2), 0.75, M_OLDBAMBOO, prm=(0.4, 0.3, 0), nr=8, nl=20)
    xs = np.sort(rng.uniform(RU0 * T + 4, RU0 * T + Lu - 4, 6))
    for xl in np.concatenate([xs, xs + 0.75]):                          # rattan ties round pole and ridge, uneven, two turns each
        xl += rng.uniform(-0.15, 0.15); tl = rng.uniform(-0.2, 0.2)
        pts = [np.array([xl + tl * math.cos(a), RV * T + math.cos(a) * (R * 1.12 + 0.5), RZ + 0.6 + math.sin(a) * (R * 1.06 + 0.6) + 1.2 * math.sin(a) ** 8]) for a in np.linspace(0.05, math.pi - 0.05, 11)]
        for i in range(10): tube(S, pts[i], pts[i + 1], 0.38, M_RATTAN, nr=5, nl=2)
    for xe in (RU0 * T - 1, RU0 * T - 1 + Lu + 2):                 # cut ends of the ridge roll: packed straw, bound
        def Fc(U, V, xe=xe):
            r = U; th = V / (R * 3) * math.pi
            return np.stack([np.full_like(U, xe), RV * T + np.cos(th) * r * 1.1, RZ + 0.6 + np.sin(th) * r], -1)
        S.grid(Fc, 5, 12, M_THEND, (0, 0, 0), 0.0, uvr=((0, R), (0, R * 3)))
        pts = [np.array([xe + (0.6 if xe > 0 else -0.6) * 0 - (1.2 if xe < RU0 * T else -1.2) * 0, RV * T + math.cos(a) * (R * 1.1 + 0.25), RZ + 0.6 + math.sin(a) * (R + 0.25)]) for a in np.linspace(0, math.pi, 9)]
        for i in range(8): tube(S, pts[i] - np.array([1.4 if xe > 0 else -1.4, 0, 0]), pts[i + 1] - np.array([1.4 if xe > 0 else -1.4, 0, 0]), 0.4, M_RATTAN, nr=5, nl=2)
    for u in (RU0 + 0.1, RU1 - 0.08):
        tube(S, W3(u, RV + 0.3, RZ - 6.0), W3(u, RV - 0.17, RZ + 10.0), 0.85, M_BAMBOO, prm=(0.3, 0.1, 0), nr=8, nl=5)
        tube(S, W3(u, RV - 0.3, RZ - 6.0), W3(u, RV + 0.17, RZ + 10.0), 0.8, M_BAMBOO, prm=(0.6, 0.4, 0), nr=8, nl=5)
        c = W3(u, RV, RZ + 4.6)
        for k in range(5):
            a0 = k * 1.25
            tube(S, c + np.array([0.9 * math.cos(a0), 0.9 * math.sin(a0), -0.6 + 0.3 * k]), c + np.array([0.9 * math.cos(a0 + 2.5), 0.9 * math.sin(a0 + 2.5), -0.45 + 0.3 * k]), 0.3, M_RATTAN, nr=5, nl=2)


# ------------------------------------------------------------------ renderer (the game's camera)
class R3:
    def __init__(self, px):
        self.px = px; self.W = int((BB[2] - BB[0]) * px); self.H = int((BB[3] - BB[1]) * px)

    def proj(self, P):
        sx = ((P[:, 0] - P[:, 1]) * 32 / T + OX - BB[0]) * self.px
        sy = ((P[:, 0] + P[:, 1]) * 16 / T + OY - P[:, 2] - BB[1]) * self.px
        return sx, sy, P @ TOCAM

    def run(self, S, night=False, edge=0.66, target=0.42):
        P, N, UV, AOv, Tr, Mt, Q, O = S.arrays()
        W, H = self.W, self.H
        Xs, Ys, Zs = self.proj(P)
        zb = np.full((H, W), -1e9); tb = np.full((H, W), -1, np.int64); b1 = np.zeros((H, W)); b2 = np.zeros((H, W))
        _raster(Xs, Ys, Zs, Tr, W, H, zb, tb, b1, b2)
        cov = tb >= 0; idx = np.nonzero(cov)
        tri = tb[idx]; w1 = b1[idx]; w2 = b2[idx]; w0 = 1 - w1 - w2
        I0, I1, I2 = Tr[tri, 0], Tr[tri, 1], Tr[tri, 2]
        def itp(A):
            if A.ndim == 1: return A[I0] * w0 + A[I1] * w1 + A[I2] * w2
            return A[I0] * w0[:, None] + A[I1] * w1[:, None] + A[I2] * w2[:, None]
        pos = itp(P); nrm = itp(N); uv = itp(UV)
        nrm = nrm / np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9)
        back = (nrm @ TOCAM) < 0; nrm[back] = -nrm[back]
        mat = Mt[tri]; prm = Q[tri]
        # gable uv fix: height in units
        sel = mat == M_GABLE
        # materials
        alb = np.zeros((len(tri), 3)); gl = np.zeros(len(tri)); sh_ = np.full(len(tri), 30.0)
        for m, fn in MATS.items():
            s = mat == m
            if not s.any(): continue
            uvm = uv[s].copy()
            if m == M_GABLE: uvm[:, 1] = pos[s, 2] - ZW
            a, n2 = fn(uvm, prm[s], pos[s], nrm[s]); alb[s] = a; nrm[s] = n2
            if m in GLOSS: gl[s], sh_[s] = GLOSS[m]
        # sun shadow map
        Lz = LIGHT; Lx = nv(np.cross(UP, Lz)); Ly = np.cross(Lz, Lx); sk = self.px * 1.0
        SX = P @ Lx * sk; SY = P @ Ly * sk; mx, my = SX.min() - 4, SY.min() - 4
        SW = int(SX.max() - mx + 8); SH = int(SY.max() - my + 8)
        smz = np.full((SH, SW), -1e9); smt = np.full((SH, SW), -1, np.int64); s1 = np.zeros((SH, SW)); s2 = np.zeros((SH, SW))
        _raster(SX - mx, SY - my, P @ Lz, Tr, SW, SH, smz, smt, s1, s2)
        pp = pos + nrm * 0.25
        sh = _shadow_lookup(pp @ Lx * sk - mx, pp @ Ly * sk - my, pp @ Lz, smz, SW, SH, 0.6, max(1, int(self.px * 0.35)))
        # occlusion from the depth buffer
        zfill = np.where(cov, zb, zb[cov].min() if cov.any() else 0)
        occ = np.zeros((H, W))
        for r, wgt in ((int(self.px * 1.0), 0.5), (int(self.px * 3.0), 0.5)):
            zbl = box_blur(zfill, max(1, r)); cvb = box_blur(cov.astype(float), max(1, r))
            occ += wgt * np.clip((zbl - zfill) / 4.0, 0, 1) * np.clip(cvb * 1.4, 0, 1)
        ssao = 1 - 0.35 * occ[idx]
        nl = nrm @ LIGHT
        diff = np.clip((nl + 0.15) / 1.15, 0, 1) * (0.3 + 0.7 * sh)
        sky = (0.66 + 0.18 * nrm[:, 2]) * ssao
        inside = (pos[:, 0] > U0 * T + 0.2) & (pos[:, 0] < U1 * T - 0.2) & (pos[:, 1] > V0 * T + 0.2) & (pos[:, 1] < V1 * T - 0.2) & (pos[:, 2] < ZW)
        sky[inside] *= 0.32                                         # under the roof: little skylight indoors
        col = alb * (diff[:, None] * np.array([1.04, 0.99, 0.88]) * 0.82 + sky[:, None] * np.array([0.70, 0.69, 0.64]))
        col += (gl * np.clip(nrm @ HALF, 0, 1) ** sh_ * sh)[:, None] * 0.5
        if os.environ.get('DBG'):
            for m in (M_WEAVE_F, M_WEAVE_R, M_LEAF, M_EARTH):
                q = mat == m
                print(m, 'alb', alb[q].mean(0).round(2), 'diff', diff[q].mean().round(2), 'sh', sh[q].mean().round(2), 'ssao', ssao[q].mean().round(2), 'nl', nl[q].mean().round(2), 'col', col[q].mean(0).round(2))
        col = col * float(os.environ.get('EXPO', '0.95'))   # match the game's sprite brightness (old hut mean lum 0.545)
        col = col * 1.3 / (1 + 0.3 * col)            # soft shoulder: no clipped lemon highlights
        col = np.clip(col, 0, 1)
        if target:                                     # match the game's bright sprites (lift with a gamma, keep the shading)
            lum = np.clip(col @ np.array([0.299, 0.587, 0.114]), 1e-4, 1); lo, hi = 0.3, 1.0
            if os.environ.get('LUMLOG'): print('premean', float(lum.mean()), flush=True)
            if os.environ.get('TGT') and not night: target = float(os.environ['TGT'])   # Link 14:14: one brightness for every building (the đình's)
            for _ in range(30):
                gm = (lo + hi) / 2
                if (lum ** gm).mean() > target: lo = gm
                else: hi = gm
            col = np.clip(col * (lum ** ((lo + hi) / 2) / lum)[:, None], 0, 1)
        lum_ = (col @ np.array([0.299, 0.587, 0.114]))[:, None]; col = np.clip(lum_ + (col - lum_) * float(os.environ.get('SAT', '1.15')), 0, 1)
        fire = (mat == M_FIRE) | (mat == M_EMBER)
        qf = np.clip(uv[fire, 0], 0, 1)[:, None]; qf = np.where((mat[fire] == M_EMBER)[:, None], 0.0, qf)
        col[fire] = hexc('#f0501a') * (1 - smooth(0.05, 0.75, qf)) + hexc('#ffd25a') * smooth(0.05, 0.75, qf)
        if night:
            ext = np.concatenate([col, np.ones((len(col), 1))], 1); col = np.clip(ext @ B._NG, 0, 1)
            lamp = (mat == M_FLAME) | (mat == M_LAMPGLASS)
            col[fire] = hexc('#ff7a2a') * (1 - smooth(0.05, 0.7, qf)) + hexc('#fff0a0') * smooth(0.05, 0.7, qf)
            for (pL, cL, rad, inten) in LIGHTS:                   # fire and lamp light falling on what is round them
                vv = pL[None] - pos; dd = np.maximum(np.linalg.norm(vv, axis=1), 1e-3)
                facing = np.clip((nrm * vv).sum(1) / dd, 0, 1)
                Lin = U0 * T < pL[0] < U1 * T and V0 * T < pL[1] < V1 * T
                if Lin:                                              # lamp indoors: the walls stop it except at door and windows
                    vis = inside.astype(float)
                    out = pos[:, 1] > V1 * T + 0.3
                    t_ = (V1 * T - pL[1]) / np.where(out, pos[:, 1] - pL[1], 1.0)
                    Xc = (pL[0] + t_ * (pos[:, 0] - pL[0])) / T; Zc = pL[2] + t_ * (pos[:, 2] - pL[2])
                    ok = (Xc > DOOR[0]) & (Xc < DOOR[1]) & (Zc > ZF) & (Zc < DOOR[2])
                    for (w0, w1) in WIN:
                        inw = (Xc > w0) & (Xc < w1) & (Zc > WZ[0]) & (Zc < WZ[1])
                        for i in range(1, 6):                        # the bamboo bars cast stripes
                            inw &= np.abs(Xc - (w0 + (w1 - w0) * i / 6)) * T > 0.6
                        ok |= inw
                    vis = np.maximum(vis, (out & ok).astype(float))
                    I = inten / (1 + (dd / rad) ** 2) * (0.1 + 0.9 * facing) * vis
                else:
                    I = inten / (1 + (dd / rad) ** 2) * (0.25 + 0.75 * facing) * (~inside)
                I[fire | lamp] = 0
                col += alb * cL[None] * I[:, None]
            col[mat == M_LAMPGLASS] = hexc('#ffe0a0')
            col = np.clip(col, 0, 1)
        col[mat == M_FLAME] = hexc('#fff0b0')
        img = np.zeros((H, W, 4)); img[idx[0], idx[1], :3] = col; img[idx[0], idx[1], 3] = 1
        # crisp edge where a part passes over another, and round the silhouette
        if edge:
            obj = np.where(cov, O[np.maximum(tb, 0)], -1); dz = np.zeros((H, W), bool)
            for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0), (1, 1), (-1, -1)):
                zn = np.roll(np.roll(zfill, dy, 0), dx, 1); on = np.roll(np.roll(obj, dy, 0), dx, 1); cn = np.roll(np.roll(cov, dy, 0), dx, 1)
                dz |= (~cn) | ((zfill - zn > 2.0) & (on != obj))
            e = cov & dz
            img[e, :3] *= edge
            sil = np.zeros((H, W), bool)                     # thin dark rim on the outer silhouette (Link: keep this old rim, 2026-11-08)
            for dy in (-2, -1, 0, 1, 2):
                for dx in (-2, -1, 0, 1, 2):
                    if dy * dy + dx * dx <= 5: sil |= ~np.roll(np.roll(cov, dy, 0), dx, 1)
            sil &= cov
            img[sil, :3] *= 0.6
        # ground: short soft sun shadow + contact shade (the game's soft blob under things)
        gy, gx = np.mgrid[0:H, 0:W]
        sxg = (gx + 0.5) / self.px + BB[0] - OX; syg = (gy + 0.5) / self.px + BB[1] - OY
        a_ = sxg * T / 32; b_ = syg * T / 16
        gp = np.stack([(a_ + b_) / 2, (b_ - a_) / 2, np.zeros_like(a_)], -1).reshape(-1, 3)
        Gz = nv([0.32, -0.2, 1.3] if MIRL else [-0.2, 0.32, 1.3]); Gx = nv(np.cross(UP, Gz)); Gy = np.cross(Gz, Gx)
        gxa = P @ Gx * sk; gya = P @ Gy * sk; gmx, gmy = gxa.min() - 4, gya.min() - 4
        GW = int(gxa.max() - gmx + 8); GH = int(gya.max() - gmy + 8)
        gz = np.full((GH, GW), -1e9); gt = np.full((GH, GW), -1, np.int64); g1 = np.zeros((GH, GW)); g2 = np.zeros((GH, GW))
        _raster(gxa - gmx, gya - gmy, P @ Gz, Tr, GW, GH, gz, gt, g1, g2)
        gs = (1 - _shadow_lookup(gp @ Gx * sk - gmx, gp @ Gy * sk - gmy, gp @ Gz, gz, GW, GH, 0.5, max(2, int(self.px * 1.6)))).reshape(H, W)
        foot = np.zeros((H, W))
        fx = np.array([p[0] for p in rrect(PL[0] - 0.04, PL[1] + 0.04, PL[2] - 0.04, PL[3] + 0.06, 0.16)]); fy = np.array([p[1] for p in rrect(PL[0] - 0.04, PL[1] + 0.04, PL[2] - 0.04, PL[3] + 0.06, 0.16)])
        from PIL import ImageDraw
        im = Image.new('L', (W, H), 0); dr = ImageDraw.Draw(im)
        sxp = ((fx - fy) * 32 / T + OX - BB[0]) * self.px; syp = ((fx + fy) * 16 / T + OY - BB[1]) * self.px
        dr.polygon(list(zip(sxp, syp)), fill=255)
        foot = box_blur(np.asarray(im, float) / 255, int(self.px * 2.2))
        ga = np.clip(gs * 0.3 + foot * 0.3, 0, 0.55) * (1 - img[..., 3])
        img[..., :3] *= img[..., 3:4]
        shc = np.array([10, 8, 4]) / 255 if not night else np.array([4, 6, 14]) / 255
        img[..., :3] += shc * ga[..., None]
        img[..., 3] += ga
        return img


def render(t=0, night=False, ss=2):
    global VARIANT
    VARIANT = t
    rng = np.random.default_rng(5000 + t * 7)
    S = build(t, rng)
    r = R3(PXU * ss)
    img = r.run(S, night)
    a = np.clip(img, 0, 1); h, w = a.shape[:2]
    im = Image.frombuffer('RGBa', (w, h), (a * 255 + 0.5).astype(np.uint8).tobytes(), 'raw', 'RGBa', 0, 1)
    return im.resize((w // ss, h // ss), Image.LANCZOS).convert('RGBA')


if os.environ.get('LADINH'):                  # Link 16:45: the đình's lá (dinh3d mat_leaf_vc): thatch mixed duller/browner
    def _la_dinh(f):
        def g(uv, prm, pos, nrm):
            col, n = f(uv, prm, pos, nrm)
            return np.clip(col * 0.8 + hexc('#a48c5c')[None] * 0.12, 0, 1), n
        return g
    for _m in (globals().get('M_LEAF'), globals().get('M_GABLE')):
        if _m is not None and _m in MATS: MATS[_m] = _la_dinh(MATS[_m])

if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        t = int(sys.argv[3]) if len(sys.argv) > 3 else 0; n = len(sys.argv) > 4 and sys.argv[4] == 'n'
        render(t, n).save(sys.argv[2])
    elif sys.argv[1] == 'atlas':
        out, tab = sys.argv[2], sys.argv[3]
        frames = {}
        for t in range(4):
            for n in (0, 1):
                im = render(t, bool(n)); bb = im.getbbox(); frames[('n' if n else 'd') + str(t)] = (im.crop(bb), bb)
        fw = max(f[0].width for f in frames.values()); fh = max(f[0].height for f in frames.values())
        keys = ['d0', 'n0', 'd1', 'n1', 'd2', 'n2', 'd3', 'n3']
        sheet = Image.new('RGBA', (4 * (fw + 2), 2 * (fh + 2)), (0, 0, 0, 0)); G = {}; sc = float(PXU)
        for i, k in enumerate(keys):
            im, bb = frames[k]; x = (i % 4) * (fw + 2); y = (i // 4) * (fh + 2); sheet.paste(im, (x, y))
            G[k] = [x, y, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, 'nha.webp'), 'WEBP', quality=92, method=6); json.dump(G, open(tab, 'w'))
        print('sheet', sheet.size)
