# Kho hàng (game id kho, 3x3, level 1 thatch) built as a real 3D model in the kit of the Nhà tranh nhỏ (choi3d.py); and shaded pixel by pixel (Link 2026-11-08: "tạo khung 3D vẽ",
# "vẽ như thật chi tiết từng pixel"). Same footprint, size, camera, sun and frame layout as choi.py, so the game hook
# (patch_choi.py) and atlas format stay the same.
#
# World: X = u*T, Y = v*T, Z = z (game units; u,v tiles as in choi.py). Camera = the game's iso exactly:
#   screen x = (X-Y)*32/T, screen y = (X+Y)*16/T - Z; depth along TOCAM = nv(1, 1, 32/T).
# Every leaflet of thatch, every bamboo, the woven walls, the props are geometry; each pixel gets its own normal,
# real sun shadow (shadow map), occlusion in the gaps, a per-pixel surface texture, and a thin darker edge where one
# part passes over another (the game's crisp sprite edge).
# Usage: python3 choi3d.py prev OUT.png [t] [n]       python3 choi3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'pxr'))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'choi'))
import pxr_3d as X3
from pxr_3d import Scene, _raster, _shadow_lookup, box_blur, hash1, vnoise, hexc, smooth
import choi as B
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'den'))
import den
from choi import T
# Kho hàng cấp 1 (game id kho / kho_b / kho_f, 3x3, mirror kho2*): thatched rice store, woven walls on a timber frame,
# door in the front gable (v = 2.05) where the game draws the stock icons, windows on the right wall, props on the apron.
# The roof is built in "roof space" (ridge along u) by roof() and then turned (x <-> y) so the ridge runs along v.
ZF = 4.5                                        # earth floor top (cấp 1: low rammed earth pad)
ZD = ZF
ZW = 64.0                                       # wall plate
RV, RZ = 1.5, 100.0                             # roof space: ridge at game u 1.5
EV, EZ = 3.02, 60.0                             # roof space: right eave (game u)
BV = -0.02; BZ = EZ
RU0, RU1 = -0.06, 2.3                           # roof space: roof ends (game v); front gable overhang to v 2.3
SMOKE_U = -9.0

BB = (-104, -166, 104, 58)
OX, OY = 0, -48
DOOR = (0, 0, 0)
WIN = []; WZ = (0, 0); NBAR = 5
LAMP = None
LIGHTS = []
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
TARGET_DAY = 0.42   # day frames: mean-lum lift target (a building whose roof faces away from the sun sets it higher)
SUN_DAY = 1.0       # day frames: sun strength (direct light only, so cast shadows keep their depth)
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
    d = np.hypot((x - 0.64 * T) / 12, (y - 1.66 * T) / 6)
    base = base * (1 - 0.06 * np.clip(1 - d, 0, 1))[:, None]
    # sparse grit
    g = hash1(np.floor(x * 2.2), np.floor(y * 2.2), 11.0)
    base = np.where((g > 0.995)[:, None], base * 0.88, base)
    ex = np.minimum(np.minimum(x - 0.12 * T, 1.88 * T - x), np.minimum(y - 0.14 * T, 1.88 * T - y))
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
    return np.tile(hexc('#902418'), (len(uv), 1)), nrm


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


def mat_pot(uv, prm, pos, nrm):
    U, V = uv[:, 0], uv[:, 1]
    base = hexc('#3b2c24') * (0.9 + 0.15 * vnoise(V * 30, U * 8, 2.0))[:, None]
    lip = smooth(0.82, 0.9, U)
    base = base * (1 + 0.25 * lip)[:, None]
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



M_POT, M_SOOT, M_PLANK, M_WATER, M_COCO, M_CHIEU, M_LAMPBASE, M_LAMPGLASS, M_FLAME, M_RIDGE, M_OLDBAMBOO, M_FIRE, M_EMBER = range(22, 35)
MATS.update({M_POT: mat_pot, M_SOOT: mat_flat('#1c140e'), M_PLANK: mat_plank, M_WATER: mat_water, M_COCO: mat_coco, M_CHIEU: mat_chieu,
             M_LAMPBASE: mat_flat('#5a6a4a'), M_LAMPGLASS: mat_flat('#e8e2c8'), M_FLAME: mat_flat('#ffd070'), M_RIDGE: mat_ridge,
             M_OLDBAMBOO: mat_oldbamboo, M_FIRE: mat_flat('#ff9a3a'), M_EMBER: mat_flat('#ff5a14')})
GLOSS.update({M_POT: (0.18, 30.0), M_WATER: (0.6, 60.0), M_LAMPGLASS: (0.5, 50.0)})



# ------------------------------------------------------------------ the model
def mat_su(uv, prm, pos, nrm):
    U = uv[:, 0]
    base = np.tile(hexc('#ece6d6'), (len(U), 1))
    band = (U > 0.66) & (U < 0.8)
    base = np.where(band[:, None], hexc('#3a5a8c')[None], base)
    return base, nrm


def mat_teapot(uv, prm, pos, nrm):
    """unglazed clay: warm brown, fine streaks"""
    U, V = uv[:, 0], uv[:, 1]
    base = hexc('#8a4a2c') * (0.9 + 0.1 * vnoise(V * 30, U * 8, 2.0))[:, None]
    return np.clip(base, 0, 1), nrm


def mat_mound(uv, prm, pos, nrm):
    """packed field mud round a post foot"""
    x, y = pos[:, 0], pos[:, 1]
    n1 = vnoise(x * 0.5, y * 0.5, 3.0); n2 = vnoise(x * 1.6, y * 1.6, 7.0)
    base = hexc('#9a7a56') * (0.88 + 0.1 * n1 + 0.06 * n2)[:, None]
    return np.clip(base, 0, 1), nrm


def mat_tin(uv, prm, pos, nrm):
    """old tin can: dull grey, a printed label band gone pale, rust spots"""
    U, V = uv[:, 0], uv[:, 1]
    base = np.tile(hexc('#a9aca6'), (len(U), 1)) * (0.9 + 0.1 * np.sin(U * 40))[:, None]
    lab = (U > 0.3) & (U < 0.7)
    base = np.where(lab[:, None], hexc('#b49a84')[None] * (0.85 + 0.15 * vnoise(V * 9, U * 3, 5.0))[:, None], base)
    rust = vnoise(V * 14 + prm[:, 0] * 7, U * 5, 3.0) > 0.72
    base = np.where(rust[:, None], hexc('#8a4a24')[None], base)
    return np.clip(base, 0, 1), nrm


def mat_khan(uv, prm, pos, nrm):
    """khăn rằn: black and white check, soft weave"""
    a, b = uv[:, 0], uv[:, 1] * 3.6
    ca = np.floor(a / 0.9) % 2; cb = np.floor(b / 0.9) % 2
    k = (ca + cb)
    base = np.where((k == 0)[:, None], hexc('#ece6da')[None], np.where((k == 2)[:, None], hexc('#1e1c1c')[None], hexc('#6a6662')[None]))
    edge = smooth(0.0, 0.25, np.minimum(a, uv[:, 0].max() - a + 9))
    return np.clip(base * (0.92 + 0.08 * np.sin(a * 30) * np.sin(b * 30))[:, None], 0, 1), nrm


def mat_handle(uv, prm, pos, nrm):
    L = uv[:, 0]
    base = hexc('#9a7448') * (0.88 + 0.12 * vnoise(L * 0.6, uv[:, 1] * 12, 2.0))[:, None]
    return np.clip(base, 0, 1), nrm


M_SU, M_TEAPOT, M_MOUND, M_TIN, M_KHAN, M_HANDLE, M_IRON, M_ROPE, M_SPLIT = 60, 61, 62, 63, 64, 65, 66, 67, 68
MATS.update({M_SU: mat_su, M_TEAPOT: mat_teapot, M_MOUND: mat_mound, M_TIN: mat_tin, M_KHAN: mat_khan, M_HANDLE: mat_handle,
             M_IRON: mat_flat('#55524c'), M_ROPE: mat_flat('#9a8458'), M_SPLIT: mat_split})
def mat_ca(uv, prm, pos, nrm):
    """red Duy Tân plastic: fine vertical ribs, slightly milky"""
    V = uv[:, 1]
    rib = 0.93 + 0.07 * np.cos(V * 2 * math.pi * 24)
    return np.clip(hexc('#c92a26') * rib[:, None], 0, 1), nrm
M_CA, M_CALID = 69, 70
MATS.update({M_CA: mat_ca, M_CALID: mat_flat('#f1eee6')})
GLOSS.update({M_CA: (0.45, 40.0), M_CALID: (0.4, 40.0)})
GLOSS.update({M_SU: (0.4, 50.0), M_TEAPOT: (0.15, 25.0), M_TIN: (0.35, 30.0), M_IRON: (0.3, 30.0)})
# ------------------------------------------------------------------ kho hàng: materials
def mat_timber(uv, prm, pos, nrm):
    """sawn timber: grain along uv a, weathered"""
    a, b = uv[:, 0], uv[:, 1]
    g = 0.86 + 0.1 * vnoise(a * 0.12 + prm[:, 0] * 9, b * 2.6, 2.0) + 0.05 * np.sin(b * 9 + vnoise(a * 0.2, b, 5.0) * 5)
    base = hexc('#8a6440') * g[:, None]
    if LEVEL == 2: base = hexc('#7a4a2c') * g[:, None]
    return np.clip(base, 0, 1), nrm


def mat_board(uv, prm, pos, nrm):
    """vertical boards (ván) with dark gaps and battens: a along the wall, b up"""
    a, b = uv[:, 0], uv[:, 1]
    W = 2.7; i = np.floor(a / W); f = a / W - i
    h = hash1(i, prm[:, 0] * 3 + 1, 4.0)
    base = hexc('#86522e') * (0.82 + 0.22 * h)[:, None]
    grain = 0.9 + 0.08 * vnoise(a * 3.5, b * 0.09 + h * 9, 2.0) + 0.04 * np.sin(a * 22 + vnoise(a, b * 0.1, 3.0) * 6)
    base = base * grain[:, None]
    gap = smooth(0.0, 0.05, f) * smooth(1.0, 0.95, f)
    base = base * (0.35 + 0.65 * gap)[:, None]
    base = base * (1 - 0.22 * np.clip(1 - (pos[:, 2] - ZF) / 10, 0, 1))[:, None]        # splash at the foot
    s = (f - 0.5) * 2
    n = bump(nrm, np.where(np.abs(nrm[:, 0:1]) > 0.5, np.array([[0, 1.0, 0]]), np.array([[1.0, 0, 0]])), -s, 0.25)
    return np.clip(base, 0, 1), n


def mat_brick(uv, prm, pos, nrm):
    a, b = uv[:, 0], uv[:, 1]
    H, L = 1.55, 3.6
    r = np.floor(b / H); fb = b / H - r
    sh = (r % 2) * 0.5
    c = np.floor(a / L + sh); fa = a / L + sh - c
    h = hash1(c, r, 7.0)
    base = pal(['#9a4a32', '#8e442e', '#a4563c', '#844028', '#9a5038'], h * 5) * (0.92 + 0.1 * vnoise(a * 2, b * 2, 3.0))[:, None]
    mort = (fb < 0.12) | (fa < 0.05)
    base = np.where(mort[:, None], hexc('#c4b49c')[None] * 0.92, base)
    return np.clip(base, 0, 1), nrm


def mat_gachtau(uv, prm, pos, nrm):
    """gạch tàu: square terracotta floor tiles"""
    x, y = pos[:, 0], pos[:, 1]; S_ = 4.4
    i = np.floor(x / S_); j = np.floor(y / S_); fx = x / S_ - i; fy = y / S_ - j
    h = hash1(i, j, 5.0)
    base = pal(['#a8664a', '#9e5c42', '#b07052', '#985640'], h * 4) * (0.9 + 0.1 * vnoise(x * 1.2, y * 1.2, 2.0))[:, None]
    gr = (np.minimum(fx, 1 - fx) < 0.045) | (np.minimum(fy, 1 - fy) < 0.045)
    base = np.where(gr[:, None], hexc('#8a6a52')[None], base)
    base = base * (1 - 0.12 * smooth(0.6, 0.85, vnoise(x * 0.12, y * 0.12, 8.0)))[:, None]    # worn dark patches
    return np.clip(base, 0, 1), nrm


def mat_floor(uv, prm, pos, nrm):
    """packed earth (sân đất nện)"""
    x, y = pos[:, 0], pos[:, 1]
    n1 = vnoise(x * 0.16, y * 0.16, 3.0); n2 = vnoise(x * 0.9, y * 0.9, 7.0)
    base = hexc('#c3a274') * (0.92 + 0.08 * n1 + 0.05 * n2)[:, None]
    g = hash1(np.floor(x * 2.2), np.floor(y * 2.2), 11.0)
    base = np.where((g > 0.994)[:, None], base * 0.86, base)
    return np.clip(base, 0, 1), nrm


def mat_tile(uv, prm, pos, nrm):
    """ngói đỏ: a course of curved clay tiles; uv a along the eave, b up the course"""
    a, b = uv[:, 0], uv[:, 1]
    W = 2.6; c = np.floor(a / W); f = a / W - c
    h = hash1(c, prm[:, 0], 3.0)
    base = pal(['#b4502c', '#a8482a', '#c0603a', '#9c4428', '#b85a34'], h * 5) * (0.9 + 0.12 * vnoise(a * 1.5, b * 1.5 + prm[:, 0] * 3, 2.0))[:, None]
    groove = 1 - 0.28 * (1 - np.abs(np.sin(np.pi * f)))
    lip = 1 + 0.12 * smooth(0.8, 1.0, b / np.maximum(prm[:, 1], 1e-6))
    base = base * (groove * lip)[:, None]
    x, y = pos[:, 0], pos[:, 1]
    d = smooth(0.55, 0.8, vnoise(x * 0.07 + 2, y * 0.07, 9.0) * 0.7 + vnoise(x * 0.3, y * 0.3, 4.0) * 0.3)
    base = base * (1 - 0.3 * d[:, None]) + hexc('#5a5040')[None] * (0.3 * d[:, None])        # old tiles gone dark in patches
    moss = (vnoise(x * 0.5, y * 0.5, 6.0) > 0.8) & (pos[:, 2] < EZ + 14)
    base = np.where(moss[:, None], base * 0.6 + hexc('#5e6a3a')[None] * 0.4, base)
    return np.clip(base, 0, 1), nrm


def mat_jute(uv, prm, pos, nrm):
    a, b = uv[:, 0], uv[:, 1]
    w = 0.9 + 0.1 * (np.sin(a * 60) * np.sin(b * 60 * 0.5) > 0)
    base = hexc('#bfa274') * (0.88 + 0.12 * prm[:, 0])[:, None] * w[:, None]
    stripe = (np.abs(b - 0.62) < 0.035) & (prm[:, 1] > 0.5)
    base = np.where(stripe[:, None], hexc('#3a5a8a')[None], base)
    return np.clip(base, 0, 1), nrm


def mat_grain(uv, prm, pos, nrm):
    x, y = pos[:, 0], pos[:, 1]
    k = hash1(np.floor(x * 4), np.floor(y * 4), 2.0)
    return np.clip(hexc('#d8ae48') * (0.8 + 0.3 * k)[:, None], 0, 1), nrm


def mat_crate(uv, prm, pos, nrm):
    """slatted crate: horizontal slats with dark gaps (uv b up)"""
    a, b = uv[:, 0], uv[:, 1]
    s = np.floor(b / 1.25); f = b / 1.25 - s
    base = hexc('#c9a26a') * (0.85 + 0.15 * hash1(s, prm[:, 0] * 7, 3.0))[:, None] * (0.94 + 0.06 * vnoise(a * 0.6, b * 4, 2.0))[:, None]
    gap = f > 0.82
    return np.clip(np.where(gap[:, None], base * 0.35, base), 0, 1), nrm


def mat_dial(uv, prm, pos, nrm):
    r, th = uv[:, 0], uv[:, 1]
    base = np.tile(hexc('#f2efe4'), (len(r), 1))
    tick = (r > 0.78) & (r < 0.92) & (np.abs(((th * 24) % 1) - 0.5) < 0.12)
    base = np.where(tick[:, None], hexc('#3a3630')[None], base)
    base = np.where((r > 0.92)[:, None], hexc('#c23a2a')[None], base)
    return base, nrm


M_TIMBER, M_BOARD, M_BRICK, M_GACH, M_FLOOR, M_TILE, M_JUTE, M_GRAIN, M_CRATE, M_DIAL = range(80, 90)
M_STEEL, M_RUBBER, M_SIGN1, M_SIGN2, M_SIGNRIM, M_BULB, M_SHADE = range(90, 97)
MATS.update({M_TIMBER: mat_timber, M_BOARD: mat_board, M_BRICK: mat_brick, M_GACH: mat_gachtau, M_FLOOR: mat_floor, M_TILE: mat_tile,
             M_JUTE: mat_jute, M_GRAIN: mat_grain, M_CRATE: mat_crate, M_DIAL: mat_dial, M_STEEL: mat_flat('#5f7a6c'),
             M_RUBBER: mat_flat('#2a2826'), M_SIGN1: mat_flat('#4e3220'), M_SIGN2: mat_flat('#a8321f'), M_SIGNRIM: mat_flat('#e8b22e'),
             M_BULB: mat_flat('#fff0c0'), M_SHADE: mat_flat('#3e5a4c')})
M_PUMPKIN, M_GARLIC, M_ONION, M_STRAW, M_BOWL = range(97, 102)
MATS.update({M_PUMPKIN: mat_flat('#d4802c'), M_GARLIC: mat_flat('#eee4d0'), M_ONION: mat_flat('#9c4a34'),
             M_STRAW: mat_flat('#c9a55a'), M_BOWL: mat_flat('#e6e0d2')})
GLOSS.update({M_BOWL: (0.25, 30.0)})
GLOSS.update({M_STEEL: (0.35, 30.0), M_TILE: (0.06, 20.0), M_SHADE: (0.4, 40.0), M_DIAL: (0.3, 50.0)})
LEVEL = 1
LIGHTS2 = []          # (pos, colour, radius, intensity, 'in'|'out'|'all')
INSIDE_K = 0.32       # skylight kept under the roof
FOOT = (0.08, 2.92, 0.08, 2.95, 0.1)   # contact shade footprint (u0,u1,v0,v1,r)
GAMMA_FIX = {}        # {night: gamma} forced brightness lift (tiled renders)
GAMMA_LOG = {}        # {night: gamma} the last render's lift
GROUND_SPILL = []     # night: (lamp world point, reach out from the door wall, alpha, (door plane v, u0, u1, z0, z1) world units)
GROUND_GLOW = []      # night: warm light pools on the ground under lamps: (u, v, radius in world units, alpha)
NOSHADOW = set()      # materials that cast no baked sun shadow (trees: the game casts real shadows later)
NORECV = set()        # materials that receive no sun shadow / occlusion (a pad the game shades itself)
KEEP_POS = False      # True: R3.run keeps the world position of every pixel in self.pos
FIRE_UNLIT = False    # True: LIGHTS2 do not add to M_FIRE/M_EMBER (lò bánh mì, Link 10:47)
FIRE_COLS = {False: ('#f0501a', '#ffd25a', 0.75), True: ('#ff7a2a', '#fff0a0', 0.7)}   # M_FIRE/M_EMBER colour base -> tip (+ where the tip colour is reached), per night; a kit may override
EMIT = {}             # {mat: fn(uv, prm, pos, night, lit colour) -> colour}: self-lit materials (lò nướng coals/flames): glow mixed over the lit colour
NOEDGE = []           # [(o0, o1)] object id ranges drawn without the black edge/rim (small fine parts: the lò bánh mì đèn bão, Link 08:12)
GROUND_SHADOW = True  # False: no baked sun shadow / contact shade on the ground (the game will cast real ones)
NIGHT_EMIT = {}       # material -> hex colour at night (glowing things)
GLOWS = []            # night: (world point, halo, core) of lamps seen from outside, see den.lampglow
SHEET = 'kho.webp'
SEED = 7700


def box(S, c0, c1, mat, prm=(0, 0, 0), top=True):
    """axis-aligned box from c0 to c1 (world units); uv of each face in units, the box's long axis first"""
    c0 = np.asarray(c0, float); c1 = np.asarray(c1, float); d = c1 - c0
    ex = [np.array([d[0], 0, 0]), np.array([0, d[1], 0]), np.array([0, 0, d[2]])]
    L = int(np.argmax(np.abs(d)))
    def face(O, A, B):
        la, lb = np.linalg.norm(A), np.linalg.norm(B)
        if la < 1e-6 or lb < 1e-6: return
        nu = max(2, min(40, int(la / 1.5) + 2)); nvv = max(2, min(40, int(lb / 1.5) + 2))
        plane(S, O, A, B, nu, nvv, mat, prm)
    for k in range(3):
        o = [x for x in range(3) if x != k]
        A, B = ex[o[0]], ex[o[1]]
        if L in o and o[0] != L: A, B = B, A
        for side in (0, 1):
            if k == 2 and side == 0: continue
            if k == 2 and side == 1 and not top: continue
            face(c0 + ex[k] * side, A, B)


def obox(S, o, a, b, c, mat, prm=(0, 0, 0)):
    """parallelepiped from corner o along edges a (long), b, c"""
    o = np.asarray(o, float); a = np.asarray(a, float); b = np.asarray(b, float); c = np.asarray(c, float)
    for (O, A, B) in ((o, a, b), (o + c, a, b), (o, a, c), (o + b, a, c), (o, c, b), (o + a, c, b)):
        la, lb = np.linalg.norm(A), np.linalg.norm(B)
        plane(S, O, A, B, max(2, min(40, int(la / 1.5) + 2)), max(2, min(40, int(lb / 1.5) + 2)), mat, prm)


def merge_all(S, o):
    """Scene.merge offsets each part by the running count, which is only right for one-part scenes; this keeps all parts"""
    base = S.nv
    for k in range(len(o.P)):
        S.P.append(o.P[k]); S.N.append(o.N[k]); S.UV.append(o.UV[k]); S.A.append(o.A[k])
        S.T.append(o.T[k] + base); S.M.append(o.M[k]); S.Q.append(o.Q[k])
        S.O.append(np.full(len(o.T[k]), S.ns, np.int64)); S.ns += 1
    S.nv += sum(len(x) for x in o.P)


def swapxy(Sub):
    for k in range(len(Sub.P)):
        Sub.P[k] = Sub.P[k][:, [1, 0, 2]].copy(); Sub.N[k] = Sub.N[k][:, [1, 0, 2]].copy()
    return Sub


# walls in game coordinates
WU0, WU1, WV0, WV1 = 0.2, 2.8, 0.2, 2.05
DU0, DU1, DZ = 1.0, 2.0, 50.0                  # door
WINS = [(0.62, 1.0), (1.3, 1.68)]; WZ0, WZ1 = 31.4, 49.7
YARD = 2.4                                      # front yard top = every building's pad height
KHO_RZ = 86.0                                   # Link 2026-11-09: roof was too tall (100)
APV = 2.86                                      # apron front edge


def zr_gable(u):
    return RZ - 2.6 - abs(u - RV) * (RZ - EZ) / (EV - RV)


def walls(S, rng):
    lv2 = LEVEL == 2
    WM_F = M_BOARD if lv2 else M_WEAVE_F
    WM_R = M_BOARD if lv2 else M_WEAVE_R
    # plinth: L1 rammed earth with an earth face, L2 brick; floor top ZF; apron in front (top ZF-1)
    if lv2:
        box(S, W3(0.12, 0.12, 0), W3(2.88, 2.13, ZF), M_BRICK, top=False)
        box(S, W3(0.18, 2.13, 0), W3(2.82, APV, ZF - 1), M_BRICK, top=False)
        plane(S, W3(0.18, 2.13, ZF - 1), W3(2.82, 2.13, 0) - W3(0.18, 2.13, 0), W3(0, APV, 0) - W3(0, 2.13, 0), 40, 14, M_GACH)
        plane(S, W3(0.12, 0.12, ZF), W3(2.88, 0.12, 0) - W3(0.12, 0.12, 0), W3(0, 2.13, 0) - W3(0, 0.12, 0), 40, 30, M_GACH)
        for (u0, u1, v0, v1, z) in ((1.12, 1.88, APV, 2.93, 5.3), (1.12, 1.88, 2.93, 3.0, 2.6)):
            box(S, W3(u0, v0, 0), W3(u1, v1, z), M_BRICK)
    else:
        extrude(S, rrect(0.12, 2.88, 0.12, 2.13, 0.06), 0.0, ZF, M_EARTHSIDE, flare=0.5)
        box(S, W3(0.16, 2.13, 0), W3(2.84, APV, ZF - 1), M_BRICK, top=False)                 # sân gạch in front
        plane(S, W3(0.16, 2.13, ZF - 1), W3(2.84, 2.13, 0) - W3(0.16, 2.13, 0), W3(0, APV, 0) - W3(0, 2.13, 0), 40, 14, M_GACH)
        plane(S, W3(0.12, 0.12, ZF), W3(2.88, 0.12, 0) - W3(0.12, 0.12, 0), W3(0, 2.13, 0) - W3(0, 0.12, 0), 40, 30, M_FLOOR)
        for (u0, u1, v0, v1, z) in ((1.14, 1.86, APV - 0.01, 2.94, 5.0),):
            box(S, W3(1.16, APV, 0), W3(1.84, 2.93, 5.0), M_BRICK); box(S, W3(1.16, 2.93, 0), W3(1.84, 2.99, 2.5), M_BRICK)
    # wall panels (inset a little behind the posts)
    e = 0.012
    def pf(u0, u1, z0, z1):                       # front wall v = WV1
        plane(S, W3(u0, WV1 - e, z0), W3(u1, 0, 0) - W3(u0, 0, 0), np.array([0, 0, z1 - z0]), max(2, int((u1 - u0) * 24)), max(2, int((z1 - z0) / 1.5)), WM_F)
    def pr(v0, v1, z0, z1):                       # right wall u = WU1
        plane(S, W3(WU1 - e, v1, z0), W3(0, v0, 0) - W3(0, v1, 0), np.array([0, 0, z1 - z0]), max(2, int((v1 - v0) * 24)), max(2, int((z1 - z0) / 1.5)), WM_R)
    pf(WU0, DU0, ZF, ZW); pf(DU1, WU1, ZF, ZW); pf(DU0, DU1, DZ, ZW)
    pr(WV0, WINS[0][0], ZF, ZW); pr(WINS[0][1], WINS[1][0], ZF, ZW); pr(WINS[1][1], WV1, ZF, ZW)
    for (a, b) in WINS: pr(a, b, ZF, WZ0); pr(a, b, WZ1, ZW)
    plane(S, W3(WU0 + e, WV1, ZF), W3(0, WV0, 0) - W3(0, WV1, 0), np.array([0, 0, ZW - ZF]), 44, 36, WM_R)     # back-left wall
    plane(S, W3(WU0, WV0 + e, ZF), W3(WU1, 0, 0) - W3(WU0, 0, 0), np.array([0, 0, ZW - ZF]), 60, 36, WM_F)   # back-right wall
    # front gable above the wall plate: hanging nipa leaves (L1) or boards (L2)
    def gF(U, Vv):
        u = WU0 + U / T; ztop = np.array([zr_gable(x) for x in u.ravel()]).reshape(u.shape)
        return np.stack([u * T, np.full_like(U, WV1 * T - 0.4), ZW + Vv * (ztop - ZW)], -1)
    S.grid(gF, 60, 14, M_BOARD if lv2 else M_GABLE, (0, 0, 0), 0.0, uvr=((0, (WU1 - WU0) * T), (0, 1)))
    if lv2:                                       # board uv: the grid's V is 0..1, so give it real heights through a second pass
        pass
    # timber frame: corner posts, door jambs, mid post, sills, wall plates, lintel, window frames and bars
    p = 0.75
    for (u, v) in ((WU0, WV1), (WU1, WV1), (WU1, WV0), (WU0, WV0)):
        box(S, W3(u, v, ZF) - [p, p, 0], W3(u, v, ZW + 1.2) + [p, p, 0], M_TIMBER, prm=(rng.random(), 0, 0))
    box(S, W3(WU1, 1.12, ZF) - [p, p, 0], W3(WU1, 1.12, ZW) + [p, p, 0], M_TIMBER, prm=(rng.random(), 0, 0))
    for u in (DU0, DU1):
        box(S, W3(u, WV1, ZF) - [0.6, 0.7, 0], W3(u, WV1, DZ + 1.8) + [0.6, 0.7, 0], M_TIMBER, prm=(rng.random(), 0, 0))
    box(S, W3(DU0 - 0.03, WV1, DZ) - [0, 0.7, 0], W3(DU1 + 0.03, WV1, DZ + 2.0) + [0, 0.7, 0], M_TIMBER, prm=(rng.random(), 0, 0))
    box(S, W3(WU0, WV1, ZW - 1.2) - [p, 0.6, 0], W3(WU1, WV1, ZW + 0.6) + [p, 0.6, 0], M_TIMBER, prm=(rng.random(), 0, 0))
    box(S, W3(WU1, WV0, ZW - 1.2) - [0.6, p, 0], W3(WU1, WV1, ZW + 0.6) + [0.6, p, 0], M_TIMBER, prm=(rng.random(), 0, 0))
    for (u0, u1) in ((WU0, DU0), (DU1, WU1)):
        box(S, W3(u0, WV1, ZF) - [0, 0.55, 0], W3(u1, WV1, ZF + 1.6) + [0, 0.55, 0], M_TIMBER, prm=(rng.random(), 0, 0))
    box(S, W3(WU1, WV0, ZF) - [0.55, 0, 0], W3(WU1, WV1, ZF + 1.6) + [0.55, 0, 0], M_TIMBER, prm=(rng.random(), 0, 0))
    for (a, b) in WINS:
        for v in (a, b):
            box(S, W3(WU1, v, WZ0 - 1.0) - [0.6, 0.45, 0], W3(WU1, v, WZ1 + 1.0) + [0.6, 0.45, 0], M_TIMBER, prm=(rng.random(), 0, 0))
        for z in (WZ0 - 1.0, WZ1):
            box(S, W3(WU1, a - 0.03, z) - [0.7, 0, 0], W3(WU1, b + 0.03, z + 1.0) + [0.7, 0, 0], M_TIMBER, prm=(rng.random(), 0, 0))
        for i in range(1, 5):
            v = a + (b - a) * i / 5
            tube(S, W3(WU1 - 0.004, v, WZ0), W3(WU1 - 0.004, v, WZ1), 0.45, M_TIMBER, prm=(rng.random(), 0, 0), nr=6, nl=3)
    # gable: a small round vent with spokes, high up
    vc = W3(RV, WV1 + 0.004, ZW + 15.0)
    disc(S, vc + np.array([0, 0.08, 0]), (0, 1, 0), 3.4, M_DARK, nr=2, na=24)
    for k in range(6):
        an = k * math.pi / 3
        tube(S, vc + np.array([0, 0.25, 0]), vc + np.array([math.cos(an) * 3.3, 0.25, math.sin(an) * 3.3]), 0.32, M_TIMBER, nr=4, nl=2)
    pts = [vc + np.array([math.cos(a) * 3.5, 0.25, math.sin(a) * 3.5]) for a in np.linspace(0, 2 * math.pi, 17)]
    for i in range(16): tube(S, pts[i], pts[i + 1], 0.42, M_TIMBER, nr=5, nl=2)
    # sign board above the door (the game paints the words "KHO HÀNG" on it)
    sz0, sz1 = 53.2, 61.8
    if lv2:
        box(S, W3(1.02, WV1 + 0.03, sz0), W3(1.98, WV1 + 0.075, sz1), M_SIGNRIM)
        box(S, W3(1.05, WV1 + 0.075, sz0 + 0.9), W3(1.95, WV1 + 0.09, sz1 - 0.9), M_SIGN2)
    else:
        box(S, W3(1.04, WV1 + 0.03, sz0), W3(1.96, WV1 + 0.08, sz1), M_SIGN1)
    # door leaves swung open against the wall: planks with a Z brace
    for (hu, sg) in ((DU0, -1), (DU1, 1)):
        ang = math.radians(7)
        a = np.array([sg * math.cos(ang), math.sin(ang), 0]) * (0.47 * T)
        o = W3(hu, WV1 + 0.03, ZF + 0.5)
        obox(S, o, a, np.array([0, 0, DZ - ZF - 1.2]), nv(np.cross(a, UP)) * 0.9, M_BOARD if lv2 else M_PLANK, prm=(rng.random(), 0, 0))
        nn = nv(np.cross(UP, a)); nn = nn if nn[1] > 0 else -nn
        for z in (ZF + 5, DZ - 6):
            obox(S, o + nn * 0.9 + a * 0.05 + np.array([0, 0, z - ZF]), a * 0.9, np.array([0, 0, 2.2]), nn * 0.5, M_TIMBER)
        p0 = o + nn * 0.9 + a * 0.1 + np.array([0, 0, 7.0]); p1 = o + nn * 0.9 + a * 0.9 + np.array([0, 0, DZ - ZF - 8])
        tube(S, p0 + nn * 0.4, p1 + nn * 0.4, 0.7, M_TIMBER, nr=4, nl=2)


def interior(S, rng):
    """what shows through the door and windows: shelves under the game's stock icons, sacks, a lamp"""
    for z in (20.3, 33.6):
        box(S, W3(1.03, 1.62, z), W3(1.97, 1.98, z + 0.7), M_PLANK, prm=(rng.random(), 0, 0))
    for (u, v) in ((1.04, 1.64), (1.96, 1.64), (1.04, 1.96), (1.96, 1.96)):
        box(S, W3(u, v, ZF) - [0.45, 0.45, 0], W3(u, v, 36.0) + [0.45, 0.45, 0], M_TIMBER)
    for (u, v, z) in ((0.5, 1.2, ZF + 1.8), (0.5, 1.5, ZF + 1.8), (0.75, 1.35, ZF + 1.8), (0.55, 1.35, ZF + 5.2), (2.4, 0.6, ZF + 1.8), (2.4, 0.9, ZF + 1.8)):
        sack(S, W3(u, v, z), rng.uniform(-0.3, 0.3), rng)
    tube(S, W3(1.5, 1.25, ZW), W3(1.5, 1.25, 50.0), 0.15, M_SOOT, nr=4, nl=2)
    lathe(S, W3(1.5, 1.25, 47.0), [(0, 2.2), (0.6, 1.6), (1.5, 0.8), (2.4, 0.4), (3.0, 0.3)], M_SHADE)
    S0 = Scene(); X3.ellipsoid(S0, W3(1.5, 1.25, 46.6), 0.8, 0.8, 0.9, M_BULB, nu=6, nvv=8); S.merge(S0)


def sack(S, c, yaw, rng, big=1.0):
    """a filled jute sack lying down, tied ear at one end"""
    ax = np.array([math.cos(yaw), math.sin(yaw), 0]); ay = np.array([-math.sin(yaw), math.cos(yaw), 0])
    rx, ry, rz = 4.1 * big, 2.7 * big, 1.9 * big
    tone = rng.random(); st = float(rng.random() < 0.4)
    S0 = Scene()
    X3.ellipsoid(S0, c, rx, ry, rz, M_JUTE, prm=(tone, st, 0), axes=(ax, ay, UP), nu=10, nvv=18,
                 bulge=lambda U, V: 0.35 * np.cos(V * 2 * math.pi * 2) * np.sin(U * math.pi) * 0)
    S.merge(S0)
    e = c + ax * (rx * 0.92)
    S0 = Scene(); X3.ellipsoid(S0, e + ax * 0.6, 0.9, 0.7, 0.7, M_JUTE, prm=(tone, 0, 0), axes=(ax, ay, UP), nu=6, nvv=10); S.merge(S0)
    tube(S, e - ay * 0.8, e + ay * 0.8, 0.28, M_ROPE, nr=4, nl=2)


def props(S, rng):
    """everything in front of the door (the game's front layer); K = prop scale so they read at game size"""
    za = ZF - 1; K = 1.6
    # rice sacks stacked left of the door
    for (u, v, z) in ((0.42, 2.27, 1), (0.42, 2.53, 1), (0.78, 2.27, 1), (0.42, 2.4, 2), (0.74, 2.3, 2)):
        sack(S, W3(u, v, za + 1.9 * K * 0.95 + (z - 1) * 3.4 * K * 0.9), rng.uniform(-0.08, 0.08), rng, big=K)
    # two cần xé (bamboo baskets) of paddy
    for (u, v, r) in ((0.3, 2.74, 2.5 * K), (0.6, 2.75, 2.3 * K)):
        c = W3(u, v, za)
        lathe(S, c, [(0, r * 0.72), (0.3, r * 0.78), (4.0 * K, r), (4.4 * K, r * 1.02)], M_WEAVE_F, na=28)
        disc(S, c + np.array([0, 0, 4.3 * K]), (0, 0, 1), r * 0.98, M_GRAIN, nr=4, na=24, dome=0.18)
        lathe(S, c + np.array([0, 0, 4.5 * K]), [(0, r * 1.04), (0.5, r * 1.06)], M_BAMBOO, na=28)
    # platform scale (cân bàn) with its dial
    c = W3(0.92, 2.68, za); k = K
    box(S, c + np.array([-3.2, -2.3, 0]) * k, c + np.array([3.2, 2.3, 1.1]) * k, M_STEEL)
    box(S, c + np.array([-3.0 * k, -2.1 * k, 1.1 * k]), c + np.array([3.0 * k, 2.1 * k, 1.1 * k + 0.4]), M_RUBBER)
    tube(S, c + np.array([0, -1.9 * k, 1.1 * k]), c + np.array([0, -1.9 * k, 10.0 * k]), 0.45 * k, M_STEEL, nr=6, nl=3)
    dc = c + np.array([0, -1.6 * k, 11.6 * k])
    fd = nv([0.45, 1.0, 0.0])
    tube(S, dc - fd * 1.0 * k, dc + fd * 0.2 * k, 2.2 * k, M_STEEL, nr=16, nl=2)
    disc(S, dc - fd * 1.0 * k, -fd, 2.2 * k, M_STEEL, nr=2, na=20)
    dc = dc + fd * 0.25 * k
    disc(S, dc, fd, 2.2 * k, M_DIAL, nr=4, na=28)
    tube(S, dc + fd * 0.1, dc + fd * 0.15 + (np.array([0.0, 0, 1.5]) + nv(np.cross(UP, fd)) * 0.6) * k, 0.14, M_SIGN2, nr=4, nl=2)
    # wheelbarrow (xe rùa) with paddy in the tray
    wc = W3(1.62, 2.55, za); ax = nv([-1.0, -0.3, 0]); ay = np.cross(UP, ax)
    def Ft(U, V):
        a = (3.6 + 1.1 * U) * K; b = (2.3 + 0.8 * U) * K; th = V * 2 * math.pi
        return wc[None, None] + ax * (a * np.cos(th))[..., None] + ay * (b * np.sin(th))[..., None] + UP * ((3.0 + U * 3.2) * K)[..., None]
    S.grid(Ft, 5, 28, M_STEEL, (0, 0, 0), 0.0, uvr=((0, 1), (0, 1)), close_v=True, flip=True)
    disc(S, wc + UP * 3.0 * K, (0, 0, 1), 2.3 * K, M_STEEL, nr=2, na=16)
    def Fg(U, V):
        a = 4.5 * K * U; th = V * 2 * math.pi
        return wc[None, None] + ax * (a * np.cos(th))[..., None] + ay * (a * 0.71 * np.sin(th))[..., None] + UP * ((5.6 + 1.1 * (1 - U ** 2)) * K)[..., None]
    S.grid(Fg, 5, 24, M_GRAIN, (0, 0, 0), 0.0, uvr=((0, 1), (0, 1)), close_v=True, flip=True)
    whc = wc - ax * 5.4 * K + UP * 2.2 * K
    pts = [whc + ax * (2.1 * K * math.cos(a)) + UP * (2.1 * K * math.sin(a)) for a in np.linspace(0, 2 * math.pi, 17)]
    for i in range(16): tube(S, pts[i], pts[i + 1], 0.55 * K, M_RUBBER, nr=6, nl=2)
    disc(S, whc + ay * 0.3, ay, 1.6 * K, M_STEEL, nr=2, na=16)
    for s_ in (-1, 1):
        tube(S, whc + ay * s_ * 0.6 * K, wc + (ax * 3.0 + ay * s_ * 2.0 + UP * 3.2) * K, 0.42 * K, M_STEEL, nr=6, nl=4)
        tube(S, wc + (ax * 3.0 + ay * s_ * 2.0 + UP * 3.2) * K, wc + (ax * 9.0 + ay * s_ * 2.3 + UP * 5.0) * K, 0.42 * K, M_STEEL, nr=6, nl=4)
        tube(S, wc + (ax * 7.8 + ay * s_ * 2.3 + UP * 4.7) * K, wc + (ax * 9.4 + ay * s_ * 2.35 + UP * 5.2) * K, 0.6 * K, M_RUBBER, nr=6, nl=2)
        tube(S, wc + (ax * 2.4 + ay * s_ * 1.9 + UP * 3.2) * K, wc + (ax * 2.9 + ay * s_ * 1.9) * K, 0.38 * K, M_STEEL, nr=5, nl=2)
    # crates and a jar at the right
    for (u, v, z, h) in ((2.55, 2.3, za, 4.0 * 1.5), (2.6, 2.6, za, 4.0 * 1.5), (2.57, 2.45, za + 6.0, 3.6 * 1.5)):
        c = W3(u, v, z)
        box(S, c + np.array([-2.8, -2.2, 0]) * 1.5, c + np.array([2.8 * 1.5, 2.2 * 1.5, h]), M_CRATE, prm=(rng.random(), 0, 0))
    c = W3(2.27, 2.77, za); k = 1.45
    lathe(S, c, [(0, 1.6 * k), (0.4 * k, 2.3 * k), (2.5 * k, 3.0 * k), (4.5 * k, 2.6 * k), (5.6 * k, 1.7 * k), (6.0 * k, 1.6 * k), (6.3 * k, 1.8 * k)], M_GLAZE, na=28)
    disc(S, c + np.array([0, 0, 6.3 * k]), (0, 0, 1), 1.9 * k, M_LID, nr=3, na=20, dome=0.2)


# ------------------------------------------------------------------ cấp 1: sơ khai (Link 2026-11-08: nền đất, tre lá như mấy nhà đã vẽ)
def hlamp(S, c):
    """đèn bão: hurricane lamp, c = flame centre"""
    lb = c - np.array([0, 0, 2.6])
    lathe(S, lb, [(0, 1.5), (0.3, 1.7), (1.2, 1.6), (1.5, 0.9)], M_LAMPBASE)
    lathe(S, lb + np.array([0, 0, 1.5]), [(0, 0.9), (0.8, 1.35), (2.0, 1.45), (3.2, 1.2), (3.9, 0.8)], M_LAMPGLASS)
    lathe(S, lb + np.array([0, 0, 5.3]), [(0, 1.2), (0.6, 1.25), (1.2, 0.6), (1.8, 0.3)], M_LAMPBASE)
    for sg in (-1, 1):
        tube(S, lb + np.array([1.55 * sg, 0, 0.6]), lb + np.array([1.2 * sg, 0, 6.6]), 0.14, M_SOOT, nr=4, nl=2)
    S0 = Scene(); X3.ellipsoid(S0, c, 0.35, 0.35, 0.8, M_FLAME, nu=6, nvv=8); S.merge(S0)


def walls1(S, rng):
    def bam(a, b, r, nl=8, foot=0):
        tube(S, a, b, r, M_BAMBOO, prm=(rng.random(), rng.random(), foot), nr=8, nl=nl)
    # nền đất: a rammed earth pad and a packed earth yard in front, a log as the step
    rrect_top(S, 0.12, 2.88, 0.12, 2.16, 0.06, ZF, M_FLOOR)
    extrude(S, rrect(0.12, 2.88, 0.12, 2.16, 0.06), 0.0, ZF, M_EARTHSIDE, flare=0.8)
    rrect_top(S, 0.16, 2.84, 2.1, APV, 0.1, YARD, M_FLOOR)                  # yard = the other buildings' pad (Link 2026-11-09)
    extrude(S, rrect(0.16, 2.84, 2.1, APV, 0.1), 0.0, YARD, M_EARTHSIDE, flare=0.6)
    tube(S, W3(1.12, 2.24, YARD + 1.0), W3(1.88, 2.24, YARD + 0.95), 1.15, M_BARK, prm=(rng.random(), 0, 0), nr=12, nl=10)
    for uu in (1.12, 1.88): disc(S, W3(uu, 2.24, YARD + 0.97), (1 if uu > 1.5 else -1, 0, 0), 1.15, M_WOOD, prm=(rng.random(), 0, 0), nr=4, na=20)
    # woven walls (phên)
    e = 0.012
    def pf(u0, u1, z0, z1):
        plane(S, W3(u0, WV1 - e, z0), W3(u1, 0, 0) - W3(u0, 0, 0), np.array([0, 0, z1 - z0]), max(2, int((u1 - u0) * 24)), max(2, int((z1 - z0) / 1.5)), M_WEAVE_F)
    def pr(v0, v1, z0, z1):
        plane(S, W3(WU1 - e, v1, z0), W3(0, v0, 0) - W3(0, v1, 0), np.array([0, 0, z1 - z0]), max(2, int((v1 - v0) * 24)), max(2, int((z1 - z0) / 1.5)), M_WEAVE_R)
    pf(WU0, DU0, ZF, ZW); pf(DU1, WU1, ZF, ZW); pf(DU0, DU1, DZ, ZW)
    pr(WV0, WINS[0][0], ZF, ZW); pr(WINS[0][1], WINS[1][0], ZF, ZW); pr(WINS[1][1], WV1, ZF, ZW)
    for (a, b) in WINS: pr(a, b, ZF, WZ0); pr(a, b, WZ1, ZW)
    plane(S, W3(WU0 + e, WV1, ZF), W3(0, WV0, 0) - W3(0, WV1, 0), np.array([0, 0, ZW - ZF]), 44, 36, M_WEAVE_R)
    plane(S, W3(WU0, WV0 + e, ZF), W3(WU1, 0, 0) - W3(WU0, 0, 0), np.array([0, 0, ZW - ZF]), 60, 36, M_WEAVE_F)
    def gF(U, Vv):
        u = WU0 + U / T; ztop = np.array([zr_gable(x) for x in u.ravel()]).reshape(u.shape)
        return np.stack([u * T, np.full_like(U, WV1 * T - 0.4), ZW + Vv * (ztop - ZW)], -1)
    S.grid(gF, 60, 14, M_GABLE, (0, 0, 0), 0.0, uvr=((0, (WU1 - WU0) * T), (0, 1)))
    # frame: tràm log posts, bamboo plates, sills, door frame, window frames and bars, all lashed
    for (u, v) in ((WU0, WV1), (WU1, WV1), (WU1, WV0), (WU0, WV0)):
        tube(S, W3(u, v, -0.3), W3(u, v, ZW + 1.8), 1.9, M_BARK, prm=(rng.random(), 0, 0), nr=12, nl=12, taper=0.88)
    tube(S, W3(WU1, 1.12, ZF - 1), W3(WU1, 1.12, ZW + 0.5), 1.6, M_BARK, prm=(rng.random(), 0, 0), nr=12, nl=12, taper=0.9)
    bam(W3(WU0 - 0.06, WV1, ZW), W3(WU1 + 0.06, WV1, ZW), 1.3, nl=16)
    bam(W3(WU1, WV0 - 0.06, ZW - 0.6), W3(WU1, WV1 + 0.06, ZW - 0.6), 1.3, nl=16)
    for (u0, u1) in ((WU0, DU0), (DU1, WU1)): bam(W3(u0, WV1 + 0.004, ZF + 1.0), W3(u1, WV1 + 0.004, ZF + 1.0), 0.9, nl=8)
    bam(W3(WU1 + 0.004, WV0, ZF + 1.0), W3(WU1 + 0.004, WV1, ZF + 1.0), 0.9, nl=12)
    for z in (ZF + 20, ZF + 38):                                       # nẹp: split bamboo holding the phên
        for (u0, u1) in ((WU0, DU0), (DU1, WU1)): bam(W3(u0, WV1 + 0.006, z), W3(u1, WV1 + 0.006, z), 0.55, nl=8)
        for (v0, v1) in ((WV0, WINS[0][0]), (WINS[0][1], WINS[1][0]), (WINS[1][1], WV1)):
            bam(W3(WU1 + 0.006, v0, z), W3(WU1 + 0.006, v1, z), 0.55, nl=6)
    for u in (DU0, DU1): bam(W3(u, WV1 + 0.01, ZF - 0.5), W3(u, WV1 + 0.01, DZ + 2.5), 1.25, nl=8, foot=1)
    bam(W3(DU0 - 0.06, WV1 + 0.012, DZ + 0.6), W3(DU1 + 0.06, WV1 + 0.012, DZ + 0.6), 1.15, nl=8)
    for (a, b) in WINS:
        for v in (a, b): bam(W3(WU1 + 0.008, v, WZ0 - 1.5), W3(WU1 + 0.008, v, WZ1 + 1.5), 0.8, nl=4)
        for z in (WZ0 - 0.6, WZ1 + 0.6): bam(W3(WU1 + 0.008, a - 0.05, z), W3(WU1 + 0.008, b + 0.05, z), 0.8, nl=4)
        for i in range(1, 6):
            v = a + (b - a) * i / 6
            bam(W3(WU1 - 0.002, v, WZ0), W3(WU1 - 0.002, v, WZ1), 0.5, nl=3)
    # sign plank hung from the wall plate on two cords (the game paints KHO HÀNG on it)
    box(S, W3(1.04, WV1 + 0.03, 53.2), W3(1.96, WV1 + 0.08, 61.8), M_SIGN1)
    for u in (1.14, 1.86): tube(S, W3(u, WV1 + 0.06, 61.8), W3(u, WV1 + 0.05, ZW - 0.6), 0.22, M_ROPE, nr=4, nl=2)
    # hurricane lamp on a bamboo peg right of the door
    tube(S, W3(2.24, WV1, 52.0), W3(2.24, WV1 + 0.1, 52.4), 0.4, M_BAMBOO, nr=6, nl=2)
    tube(S, W3(2.24, WV1 + 0.1, 52.2), W3(2.24, WV1 + 0.1, 48.6), 0.14, M_SOOT, nr=4, nl=2)
    hlamp(S, W3(2.24, WV1 + 0.1, 44.6))


def interior1(S, rng):
    """bamboo shelves full of goods (the game's stock icons are painted over them), a paddy bin, sacks, an oil lamp"""
    def bam(a, b, r, nl=6):
        tube(S, a, b, r, M_BAMBOO, prm=(rng.random(), rng.random(), 0), nr=7, nl=nl)
    for (u, v) in ((1.04, 1.64), (1.96, 1.64), (1.04, 1.96), (1.96, 1.96)):
        bam(W3(u, v, ZF), W3(u, v, 37.0), 0.65)
    for z in (20.3, 33.6):
        for v in (1.64, 1.96): bam(W3(1.0, v, z - 0.6), W3(2.0, v, z - 0.6), 0.55)
        for i in range(7):
            v = 1.65 + 0.31 * i / 6
            bam(W3(1.02, v, z), W3(1.98, v, z), 0.42)
    zt, zb = 34.0, 20.7
    # top shelf: clay jars, a basket of corn cobs, a bundle of garlic
    for (u, r, h) in ((1.1, 1.5, 3.4), (1.28, 1.9, 4.2), (1.92, 1.6, 3.6)):
        lathe(S, W3(u, 1.86, zt), [(0, r * 0.7), (h * 0.35, r), (h * 0.8, r * 0.75), (h, r * 0.55), (h + 0.3, r * 0.65)], M_GLAZE if r > 1.7 else M_TEAPOT, na=20)
    c = W3(1.55, 1.82, zt)
    lathe(S, c, [(0, 2.4), (2.8, 3.2), (3.1, 3.3)], M_WEAVE_F, na=24)
    for k in range(6):
        an = k * 1.05 + 0.3
        S0 = Scene(); X3.ellipsoid(S0, c + np.array([math.cos(an) * 1.7, math.sin(an) * 1.5, 3.4 + 0.4 * (k % 2)]), 2.2, 0.75, 0.75, M_CORN,
                                   axes=(nv([math.cos(an + 1.3), math.sin(an + 1.3), 0.25]), nv([-math.sin(an + 1.3), math.cos(an + 1.3), 0]), UP), nu=6, nvv=10); S.merge(S0)
    # top shelf, filled: a stack of bowls, two more jars, a basket of chillies
    for (u, v, r, h) in ((1.72, 1.78, 1.3, 2.8), (1.42, 1.9, 1.2, 2.6)):
        lathe(S, W3(u, v, zt), [(0, r * 0.7), (h * 0.4, r), (h * 0.85, r * 0.7), (h, r * 0.5), (h + 0.3, r * 0.6)], M_TEAPOT, na=18)
    for k in range(5):
        lathe(S, W3(1.84, 1.72, zt + 0.55 * k), [(0, 0.8), (0.55, 1.6), (0.6, 1.62)], M_BOWL, na=20)
    c = W3(1.12, 1.72, zt)
    lathe(S, c, [(0, 1.4), (1.3, 1.9), (1.45, 2.0)], M_WEAVE_R, na=20)
    for k in range(7):
        an = k * 0.9; rr = 0.9 * (k % 3) / 2
        S0 = Scene(); X3.ellipsoid(S0, c + np.array([math.cos(an) * rr, math.sin(an) * rr, 1.6]), 0.9, 0.3, 0.3, M_CHILLI,
                                   axes=(nv([math.cos(an), math.sin(an), 0.2]), nv([-math.sin(an), math.cos(an), 0]), UP), nu=5, nvv=6); S.merge(S0)
    # bottom shelf, filled: a pile of coconuts, pumpkins, dried gourds, a sack, a basket of red onions
    for (u, v, z) in ((1.1, 1.78, 0), (1.2, 1.9, 0), (1.08, 1.92, 0), (1.22, 1.74, 0), (1.15, 1.84, 2.6)):
        S0 = Scene(); X3.ellipsoid(S0, W3(u, v, zb + 1.5 + z), 1.5, 1.5, 1.55, M_COCO, nu=8, nvv=12); S.merge(S0)
    for (u, v, r) in ((1.38, 1.8, 2.1), (1.38, 1.92, 1.7)):
        S0 = Scene(); X3.ellipsoid(S0, W3(u, v, zb + r * 0.62), r, r, r * 0.62, M_PUMPKIN, nu=10, nvv=12); S.merge(S0)
        tube(S, W3(u, v, zb + r * 1.18), W3(u, v, zb + r * 1.18 + 0.9), 0.22, M_HANDLE, nr=4, nl=2)
    for (u, v) in ((1.55, 1.82), (1.64, 1.9)):
        S0 = Scene(); X3.ellipsoid(S0, W3(u, v, zb + 2.0), 1.7, 1.7, 2.0, M_HUSK, nu=8, nvv=12); S.merge(S0)
        S0 = Scene(); X3.ellipsoid(S0, W3(u, v, zb + 4.8), 1.0, 1.0, 1.3, M_HUSK, nu=6, nvv=10); S.merge(S0)
    c = W3(1.76, 1.72, zb)
    lathe(S, c, [(0, 1.5), (1.4, 2.0), (1.55, 2.1)], M_WEAVE_R, na=20)
    for k in range(8):
        an = k * 0.8; rr = 1.1 * (k % 3) / 2
        S0 = Scene(); X3.ellipsoid(S0, c + np.array([math.cos(an) * rr, math.sin(an) * rr, 1.8 + 0.2 * (k % 2)]), 0.6, 0.6, 0.55, M_ONION, nu=6, nvv=8); S.merge(S0)
    sack(S, W3(1.88, 1.88, zb + 1.6), 0.0, rng, big=0.75)
    # under the bottom shelf: a big lu, a sack, a basket of sweet potatoes
    c = W3(1.23, 1.82, ZF); k = 1.6
    lathe(S, c, [(0, 1.6 * k), (0.4 * k, 2.3 * k), (2.5 * k, 3.0 * k), (4.5 * k, 2.6 * k), (5.6 * k, 1.7 * k), (6.0 * k, 1.6 * k), (6.3 * k, 1.8 * k)], M_GLAZE, na=24)
    disc(S, c + np.array([0, 0, 6.3 * k]), (0, 0, 1), 1.9 * k, M_LID, nr=3, na=20, dome=0.2)
    sack(S, W3(1.5, 1.82, ZF + 2.6), 0.1, rng, big=1.2)
    c = W3(1.84, 1.8, ZF)
    lathe(S, c, [(0, 2.4), (3.4, 3.2), (3.6, 3.3)], M_WEAVE_F, na=24)
    for k in range(7):
        an = k * 0.9 + 0.2; rr = 1.6 * (k % 3) / 2
        S0 = Scene(); X3.ellipsoid(S0, c + np.array([math.cos(an) * rr, math.sin(an) * rr, 3.9]), 1.3, 0.7, 0.7, M_ONION,
                                   axes=(nv([math.cos(an), math.sin(an), 0.1]), nv([-math.sin(an), math.cos(an), 0]), UP), nu=6, nvv=8); S.merge(S0)
    # a tall woven paddy bin (bồ lúa) and sacks on the floor
    c = W3(0.62, 1.15, ZF)
    lathe(S, c, [(0, 7.0), (2, 8.6), (20, 9.0), (22, 9.2)], M_WEAVE_F, na=32)
    disc(S, c + np.array([0, 0, 21.0]), (0, 0, 1), 8.9, M_GRAIN, nr=4, na=28, dome=0.12)
    for (u, v, z) in ((2.35, 0.6, ZF + 2.5), (2.35, 0.95, ZF + 2.5), (2.38, 0.78, ZF + 7.0), (1.3, 0.6, ZF + 2.5)):
        sack(S, W3(u, v, z), rng.uniform(-0.3, 0.3), rng, big=1.3)
    tube(S, W3(1.5, 1.25, ZW), W3(1.5, 1.25, 50.5), 0.15, M_SOOT, nr=4, nl=2)
    hlamp(S, W3(1.5, 1.25, 46.4))


def hang1(S, rng):
    """Link 2026-11-08: dried things hung on the front wall: corn bundles, chilli strings, a garlic braid"""
    vw = WV1
    def peg(u, z):
        tube(S, W3(u, vw, z), W3(u, vw + 0.06, z + 0.3), 0.35, M_BAMBOO, nr=6, nl=2)
        return W3(u, vw + 0.055, z)
    def corn(u, z, n=5):
        p = peg(u, z)
        tie = p + np.array([0, 0, -2.4]); tube(S, p, tie, 0.14, M_ROPE, nr=3, nl=2)
        for k in range(n):
            a = (k - (n - 1) / 2) * 0.32
            d = nv([math.sin(a), 0.18 + 0.1 * (k % 2), -math.cos(a)])
            e1 = nv(np.cross(d, UP)); e2 = nv(np.cross(d, e1))
            S0 = Scene(); X3.ellipsoid(S0, tie + d * 4.0, 1.05, 1.05, 3.1, M_CORN, axes=(e1, e2, d), nu=8, nvv=12); S.merge(S0)
            for j in range(3):                       # husks pulled back up over the tie
                b = a + (j - 1) * 0.28
                dh = nv([math.sin(b) * 1.4, 0.3 + 0.15 * j, 1.0])
                f1 = nv(np.cross(dh, UP) + 1e-6); f2 = nv(np.cross(dh, f1))
                S0 = Scene(); X3.ellipsoid(S0, tie + d * 0.6 + dh * 1.9, 0.75, 0.22, 2.1, M_HUSK, axes=(f1, f2, dh), nu=6, nvv=8); S.merge(S0)
    def chilli(u, z, L=17.0, n=30):
        p = peg(u, z)
        tube(S, p, p + np.array([0, 0.25, -L]), 0.1, M_ROPE, nr=3, nl=4)
        for k in range(n):
            t = k / (n - 1); an = k * 2.4
            c = p + np.array([0, 0.25 * t, -1.2 - (L - 1.6) * t])
            d = nv([math.cos(an) * 0.9, abs(math.sin(an)) * 0.9 + 0.1, -0.45])
            e1 = nv(np.cross(d, UP)); e2 = nv(np.cross(d, e1))
            S0 = Scene(); X3.ellipsoid(S0, c + d * 1.0, 0.36, 0.36, 1.15, M_CHILLI, axes=(e1, e2, d), nu=5, nvv=7); S.merge(S0)
    def garlic(u, z, n=9):
        p = peg(u, z)
        tube(S, p, p + np.array([0, 0.3, -3.0]), 0.5, M_STRAW, nr=5, nl=3)       # the braided stems
        for k in range(n):
            c = p + np.array([(0.55 if k % 2 else -0.55), 0.95 + 0.1 * (k % 3), -3.6 - 1.25 * k])
            S0 = Scene(); X3.ellipsoid(S0, c, 0.95, 0.9, 0.82, M_GARLIC, nu=7, nvv=9); S.merge(S0)
            tube(S, c + np.array([0, 0, 0.6]), c + np.array([-0.3 if k % 2 else 0.3, -0.3, 1.6]), 0.2, M_STRAW, nr=3, nl=2)
    # left of the door
    corn(0.36, 49.0); chilli(0.56, 50.0); garlic(0.74, 49.0); chilli(0.9, 48.0, L=14.0, n=24)
    # right of the door, past the lamp
    chilli(2.44, 50.0); corn(2.62, 49.0, n=4)


def props1(S, rng):
    za = YARD; K = 1.6
    for (u, v, z) in ((0.42, 2.3, 1), (0.42, 2.56, 1), (0.78, 2.3, 1), (0.42, 2.43, 2), (0.74, 2.33, 2)):
        sack(S, W3(u, v, za + 1.9 * K * 0.95 + (z - 1) * 3.4 * K * 0.9), rng.uniform(-0.08, 0.08), rng, big=K)
    for (u, v, r) in ((0.3, 2.76, 2.5 * K), (0.64, 2.74, 2.3 * K)):
        c = W3(u, v, za)
        lathe(S, c, [(0, r * 0.72), (0.3, r * 0.78), (4.0 * K, r), (4.4 * K, r * 1.02)], M_WEAVE_F, na=28)
        disc(S, c + np.array([0, 0, 4.3 * K]), (0, 0, 1), r * 0.98, M_GRAIN, nr=4, na=24, dome=0.18)
        lathe(S, c + np.array([0, 0, 4.5 * K]), [(0, r * 1.04), (0.5, r * 1.06)], M_BAMBOO, na=28)
    # đôi quang gánh: two thúng of paddy, cords up to the carrying pole laid across
    tops = []
    for (u, v) in ((1.98, 2.4), (1.98, 2.76)):
        c = W3(u, v, za); r = 3.6
        lathe(S, c, [(0, r * 0.7), (0.4, r * 0.85), (3.2, r), (3.5, r * 1.02)], M_WEAVE_R, na=28)
        disc(S, c + np.array([0, 0, 3.2]), (0, 0, 1), r * 0.97, M_GRAIN, nr=4, na=24, dome=0.2)
        lathe(S, c + np.array([0, 0, 3.35]), [(0, r * 1.03), (0.45, r * 1.05)], M_BAMBOO, na=28)
        top = c + np.array([0, 0, 11.0]); tops.append(top)
        for k in range(4):
            an = k * math.pi / 2 + 0.4
            tube(S, c + np.array([math.cos(an) * r, math.sin(an) * r, 3.5]), top, 0.16, M_ROPE, nr=3, nl=2)
    d = nv(tops[1] - tops[0])
    tube(S, tops[0] - d * 4.0 + np.array([0, 0, 0.4]), tops[1] + d * 4.0 + np.array([0, 0, 0.4]), 0.75, M_BAMBOO, prm=(0.3, 0.6, 0), nr=8, nl=10, taper=0.8)
    # cối xay lúa: woven body packed with clay, the upper drum with its hopper and the long crank arm
    c = W3(2.5, 2.42, za)
    lathe(S, c, [(0, 5.6), (0.5, 5.8), (6.0, 5.4), (6.4, 5.6)], M_WEAVE_F, na=32)
    lathe(S, c + np.array([0, 0, 6.4]), [(0, 4.9), (4.6, 5.0), (5.0, 5.3), (5.3, 5.3)], M_WEAVE_R, na=32)
    disc(S, c + np.array([0, 0, 11.7]), (0, 0, 1), 5.0, M_GRAIN, nr=4, na=28, dome=0.0)
    lathe(S, c + np.array([0, 0, 11.4]), [(0, 5.3), (0.6, 5.4)], M_BAMBOO, na=32)
    tube(S, c + np.array([0, 4.6, 9.2]), c + np.array([0, 4.6, 9.2]) + nv([0.25, 1.0, 0.08]) * 12.5, 0.7, M_HANDLE, nr=6, nl=8)
    p = c + np.array([0, 4.6, 9.2]) + nv([0.25, 1.0, 0.08]) * 12.5
    tube(S, p, p + np.array([0, 0, 3.0]), 0.6, M_HANDLE, nr=6, nl=2)
    lathe(S, c + np.array([0, 0, -0.01]), [(0, 6.4), (1.2, 6.2)], M_EARTHSIDE, na=32)
    # lu nước at the corner, a nia leaning on the right wall
    c = W3(1.0, 2.8, za); k = 1.45
    lathe(S, c, [(0, 1.6 * k), (0.4 * k, 2.3 * k), (2.5 * k, 3.0 * k), (4.5 * k, 2.6 * k), (5.6 * k, 1.7 * k), (6.0 * k, 1.6 * k), (6.3 * k, 1.8 * k)], M_GLAZE, na=28)
    disc(S, c + np.array([0, 0, 6.3 * k]), (0, 0, 1), 1.9 * k, M_LID, nr=3, na=20, dome=0.2)


def build(level, rng, with_props=True):
    global LEVEL, RZ
    RZ = KHO_RZ                                  # kho's own ridge (the other kits keep the module default)
    LEVEL = level
    S = Scene(); LIGHTS2.clear()
    LIGHTS2.append((W3(1.5, 1.25, 46.4), hexc('#ff9645'), 26.0, 2.2, 'in'))
    LIGHTS2.append((W3(2.24, WV1 + 0.1, 44.6), hexc('#ff9645'), 15.0, 2.1, 'out'))
    GLOWS[:] = [(W3(2.24, WV1 + 0.1, 44.6), 0.2, 0.85)]
    walls1(S, rng)
    interior1(S, rng)
    hang1(S, rng)
    R = Scene(); roof(R, rng, 0)
    merge_all(S, swapxy(R))
    ns0 = S.ns
    if with_props: props1(S, rng)
    return S, (ns0, S.ns)


def roof_tile(S, rng):
    """red clay tiles in courses (roof space: ridge along u), boards under the eaves, ridge of half-round cap tiles"""
    ax = np.array([1.0, 0, 0]); Lu = (RU1 - RU0) * T
    for (eV, eZ, sg) in ((EV, EZ, 1), (BV, BZ, -1)):
        e = W3(RU0, eV, eZ); up = W3(RU0, RV, RZ) - e; LB = np.linalg.norm(up); su = up / LB
        n_out = nv(np.cross(ax, su)) if sg > 0 else nv(np.cross(su, ax))
        if n_out[2] < 0: n_out = -n_out
        plane(S, e - n_out * 2.2, ax * Lu, su * LB, 10, 8, M_TIMBER)                        # roof boards
        plane(S, e - n_out * 2.2, ax * Lu, n_out * 2.4, 30, 2, M_TIMBER)                   # fascia
        c = 3.3; nC = int(LB / c) + 1
        for i in range(nC):
            b0 = i * c - 0.4
            hgt = min(c + 1.1, LB - b0 + 0.6)
            def F(U, V, b0=b0, hgt=hgt):
                f = U / 2.6 - np.floor(U / 2.6)
                cor = 0.75 * np.sin(np.pi * f)
                h = 0.35 + 0.95 * (1 - V / hgt) + cor
                return e[None, None] + ax[None, None] * U[..., None] + su[None, None] * (b0 + V)[..., None] + n_out[None, None] * h[..., None]
            S.grid(F, int(Lu / 0.45), 5, M_TILE, (i, hgt, 0), 0.0, uvr=((0, Lu), (0, hgt)))
        # bargeboards along the two gable verges
        for x in (RU0 * T - 0.3, RU0 * T + Lu + 0.3):
            o = np.array([x, e[1], e[2]]) - n_out * 2.4
            obox(S, o, su * (LB + 0.6), n_out * 3.6, np.array([0.7 if x > 0 else -0.7, 0, 0]), M_TIMBER)
    # ridge: row of half-round cap tiles on mortar
    R = 2.3; z0 = RZ + 1.2
    tube(S, (RU0 * T - 0.8, RV * T, z0 - 1.2), (RU0 * T + Lu + 0.8, RV * T, z0 - 1.2), 2.4, M_FLOOR, nr=10, nl=20)
    x = RU0 * T - 0.6
    while x < RU0 * T + Lu + 0.6:
        L = 3.4
        def Fc(U, V, x=x):
            th = V * math.pi
            return np.stack([x + U, RV * T + np.cos(th) * R, z0 + np.sin(th) * R * 0.95 + 0.25 * U / L], -1)
        S.grid(Fc, 4, 10, M_TILE, (99, L, 0), 0.0, uvr=((0, L + 0.5), (0, R * math.pi)))
        x += L


PATCH = (30.0, 46.0, 8.0, 20.0)                                     # a newer patch on the front slope: along-eave units, up-slope units


def slope(S, rng, e, su, n_out, LB, ax, Lu, th=2.4, course=3.3):
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


RIDGE_R, BATTEN_R, POLE_R, TIE_R = 3.0, 0.75, 0.45, 0.26     # ridge roll / battens / ridge pole / ties (small buildings set thinner)


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
    for fr in (0.42, 0.78):                                            # two battens (Link), old grey bamboo
        p0 = e_front + su * LB * fr + n_out * 2.1 + ax * 1.0
        tube(S, p0, p0 + ax * (Lu - 1.6), BATTEN_R, M_OLDBAMBOO, prm=(rng.random(), 0.5, 0), nr=8, nl=14)
    R = RIDGE_R
    LIFT = lambda x: 1.2 * np.exp(-((x - SMOKE_U * T) / 6.0) ** 2)      # lifted a little over the smoke vent
    def Fr(U, V):
        th = V * math.pi
        y = RV * T + np.cos(th) * R * 1.0; z = RZ + 0.6 + np.sin(th) * R * 0.92 + LIFT(RU0 * T - 1 + U)
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
            z = RZ + 0.6 + np.sin(th) * rr - over * 2.2 + LIFT(x)
            return np.stack([x + V * w * 0.55 * tp + lean * np.sin(th), y, z], -1)
        S.grid(Fs, 18, 3, M_RIDGE, (tone, arc, seed), 0.0, uvr=((0, arc), (-1, 1)))
        x += w * rng.uniform(0.7, 0.9)
    zp = RZ + 0.6 + R * 1.04 + 0.45
    tube(S, (RU0 * T - 0.5, RV * T, zp), (RU0 * T + Lu + 0.5, RV * T, zp - 0.2), POLE_R, M_OLDBAMBOO, prm=(0.4, 0.3, 0), nr=8, nl=20)
    xs = np.array([RU0 * T + Lu * 0.3, RU0 * T + Lu * 0.68]) + rng.uniform(-1.5, 1.5, 2)
    xs = xs[np.abs(xs - SMOKE_U * T) > 6]
    for xl in np.concatenate([xs, xs + 0.75]):                          # rattan ties round pole and ridge, uneven, two turns each
        xl += rng.uniform(-0.15, 0.15); tl = rng.uniform(-0.2, 0.2)
        pts = [np.array([xl + tl * math.cos(a), RV * T + math.cos(a) * (R * 1.12 + 0.5), RZ + 0.6 + math.sin(a) * (R * 1.06 + 0.6) + 0.35 * math.sin(a) ** 8]) for a in np.linspace(0.05, math.pi - 0.05, 11)]
        for i in range(10): tube(S, pts[i], pts[i + 1], TIE_R, M_RATTAN, nr=5, nl=2)
    for xe in (RU0 * T - 1, RU0 * T - 1 + Lu + 2):                 # cut ends of the ridge roll: packed straw, bound
        def Fc(U, V, xe=xe):
            r = U; th = V / (R * 3) * math.pi
            return np.stack([np.full_like(U, xe), RV * T + np.cos(th) * r * 1.1, RZ + 0.6 + np.sin(th) * r], -1)
        S.grid(Fc, 5, 12, M_THEND, (0, 0, 0), 0.0, uvr=((0, R), (0, R * 3)))
        pts = [np.array([xe + (0.6 if xe > 0 else -0.6) * 0 - (1.2 if xe < RU0 * T else -1.2) * 0, RV * T + math.cos(a) * (R * 1.1 + 0.25), RZ + 0.6 + math.sin(a) * (R + 0.25)]) for a in np.linspace(0, math.pi, 9)]
        for i in range(8): tube(S, pts[i] - np.array([1.4 if xe > 0 else -1.4, 0, 0]), pts[i + 1] - np.array([1.4 if xe > 0 else -1.4, 0, 0]), 0.4, M_RATTAN, nr=5, nl=2)
    for u in (RU0 + 0.1, RU1 - 0.08):
        tube(S, W3(u, RV + 0.1, RZ - 3.0), W3(u, RV - 0.05, RZ + 3.6), 0.45, M_BAMBOO, prm=(0.3, 0.1, 0), nr=8, nl=5)
        tube(S, W3(u, RV - 0.1, RZ - 3.0), W3(u, RV + 0.05, RZ + 3.6), 0.42, M_BAMBOO, prm=(0.6, 0.4, 0), nr=8, nl=5)
        c = W3(u, RV, RZ + 1.8)
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
        TrS = Tr[~np.isin(Mt, list(NOSHADOW))] if NOSHADOW else Tr
        _raster(SX - mx, SY - my, P @ Lz, TrS, SW, SH, smz, smt, s1, s2)
        pp = pos + nrm * 0.25
        sh = _shadow_lookup(pp @ Lx * sk - mx, pp @ Ly * sk - my, pp @ Lz, smz, SW, SH, 0.6, max(1, int(self.px * 0.35)))
        # occlusion from the depth buffer
        zfill = np.where(cov, zb, zb[cov].min() if cov.any() else 0)
        occ = np.zeros((H, W))
        for r, wgt in ((int(self.px * 1.0), 0.5), (int(self.px * 3.0), 0.5)):
            zbl = box_blur(zfill, max(1, r)); cvb = box_blur(cov.astype(float), max(1, r))
            occ += wgt * np.clip((zbl - zfill) / 4.0, 0, 1) * np.clip(cvb * 1.4, 0, 1)
        ssao = 1 - 0.35 * occ[idx]
        if NORECV: q_ = np.isin(mat, list(NORECV)); sh[q_] = 1.0; ssao[q_] = 1.0
        nl = nrm @ LIGHT
        diff = np.clip((nl + 0.15) / 1.15, 0, 1) * (0.3 + 0.7 * sh * (1.0 if night else SUN_DAY))   # SUN_DAY: only the sunlit part
        sky = (0.66 + 0.18 * nrm[:, 2]) * ssao
        inside = (pos[:, 0] > WU0 * T + 0.2) & (pos[:, 0] < WU1 * T - 0.6) & (pos[:, 1] > WV0 * T + 0.2) & (pos[:, 1] < WV1 * T - 0.6) & (pos[:, 2] > ZF - 0.5) & (pos[:, 2] < ZW + 0.5)   # under the roof: half the sky
        if NORECV: inside &= ~np.isin(mat, list(NORECV))
        sky[inside] *= INSIDE_K                                         # under the roof: little skylight indoors
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
            gfix = GAMMA_FIX.get(bool(night))                 # tiled hi-res renders reuse the whole picture's gamma
            if gfix: lo = hi = gfix
            GAMMA_LOG[bool(night)] = (lo + hi) / 2
            col = np.clip(col * (lum ** ((lo + hi) / 2) / lum)[:, None], 0, 1)
        lum_ = (col @ np.array([0.299, 0.587, 0.114]))[:, None]; col = np.clip(lum_ + (col - lum_) * float(os.environ.get('SAT', '1.15')), 0, 1)
        fire = (mat == M_FIRE) | (mat == M_EMBER)
        qf = np.clip(uv[fire, 0], 0, 1)[:, None]; qf = np.where((mat[fire] == M_EMBER)[:, None], 0.0, qf)
        c0_, c1_, e_ = FIRE_COLS[False]; col[fire] = hexc(c0_) * (1 - smooth(0.05, e_, qf)) + hexc(c1_) * smooth(0.05, e_, qf)
        if night:
            ext = np.concatenate([col, np.ones((len(col), 1))], 1); col = np.clip(ext @ B._NG, 0, 1)
            lamp = (mat == M_FLAME) | (mat == M_LAMPGLASS)
            c0_, c1_, e_ = FIRE_COLS[True]; col[fire] = hexc(c0_) * (1 - smooth(0.05, e_, qf)) + hexc(c1_) * smooth(0.05, e_, qf)
            for (pL, cL, rad, inten, mode) in LIGHTS2:
                vv = pL[None] - pos; dd = np.maximum(np.linalg.norm(vv, axis=1), 1e-3)
                facing = np.clip((nrm * vv).sum(1) / dd, 0, 1)
                if isinstance(mode, tuple):                       # ('box', u0, u1, v0, v1, z0, z1, (vd, du0, du1, dz0, dz1)): a lamp in a closed room:
                    _, bu0, bu1, bv0, bv1, bz0, bz1, (vd, du0, du1, dz0, dz1) = mode   # it lights the room, and outside only what it sees through the door
                    inb = (pos[:, 0] > bu0) & (pos[:, 0] < bu1) & (pos[:, 1] > bv0) & (pos[:, 1] < bv1) & (pos[:, 2] > bz0) & (pos[:, 2] < bz1)
                    out_ = pos[:, 1] > vd + 0.3
                    t_ = (vd - pL[1]) / np.where(out_, pos[:, 1] - pL[1], 1.0)
                    Xc = pL[0] + t_ * (pos[:, 0] - pL[0]); Zc = pL[2] + t_ * (pos[:, 2] - pL[2])
                    vis = inb | (out_ & (Xc > du0) & (Xc < du1) & (Zc > dz0) & (Zc < dz1) & (pos[:, 2] > bz0))   # the floor blocks what is below it
                    I = inten / (1 + (dd / rad) ** 2) * (0.25 + 0.75 * facing) * vis
                else:
                    I = inten / (1 + (dd / rad) ** 2) * (0.25 + 0.75 * facing) * (inside if mode == 'in' else (~inside if mode == 'out' else np.ones_like(inside)))
                I[mat == M_BULB] = 0
                if FIRE_UNLIT: I[fire] = 0                         # the fire is its own colour, lamps don't wash it yellow
                col += alb * cL[None] * I[:, None]
            col[mat == M_LAMPGLASS] = hexc(den.GLASS_NIGHT)
            col = np.clip(col, 0, 1)
        col[mat == M_FLAME] = hexc('#fff0b0')
        for mm, fn in EMIT.items():
            s_ = mat == mm
            if s_.any(): col[s_] = np.clip(fn(uv[s_], prm[s_], pos[s_], night, col[s_]), 0, 1)
        if night: col[mat == M_BULB] = hexc('#fff4c0')
        if night: col[mat == M_LAMPGLASS] = hexc(den.GLASS_NIGHT)
        if night:
            for mm, hx in NIGHT_EMIT.items(): col[mat == mm] = hexc(hx)
        img = np.zeros((H, W, 4)); img[idx[0], idx[1], :3] = col; img[idx[0], idx[1], 3] = 1
        self.mat = np.full((H, W), -1, np.int32); self.mat[idx[0], idx[1]] = mat   # per-pixel material (fire layers cut out by it)
        if KEEP_POS: self.pos = np.full((H, W, 3), np.nan, np.float32); self.pos[idx[0], idx[1]] = pos   # world point per pixel (lò bánh mì xẻng clip)
        self.obj = np.where(cov, O[np.maximum(tb, 0)], -1)
        # crisp edge where a part passes over another, and round the silhouette
        if edge:
            obj = np.where(cov, O[np.maximum(tb, 0)], -1); dz = np.zeros((H, W), bool)
            for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0), (1, 1), (-1, -1)):
                zn = np.roll(np.roll(zfill, dy, 0), dx, 1); on = np.roll(np.roll(obj, dy, 0), dx, 1); cn = np.roll(np.roll(cov, dy, 0), dx, 1)
                dz |= (~cn) | ((zfill - zn > 2.0) & (on != obj))
            e = cov & dz
            ne = np.zeros((H, W), bool)
            for (o0, o1) in NOEDGE: ne |= (obj >= o0) & (obj < o1)
            img[e & ne, :3] *= 0.92                          # fine parts: only a faint line between their pieces
            e &= ~ne
            img[e, :3] *= edge
            sil = np.zeros((H, W), bool)                     # thin dark rim on the outer silhouette (Link: keep this old rim, 2026-11-08)
            for dy in (-2, -1, 0, 1, 2):
                for dx in (-2, -1, 0, 1, 2):
                    if dy * dy + dx * dx <= 5: sil |= ~np.roll(np.roll(cov, dy, 0), dx, 1)
            sil &= cov
            if NOEDGE: sil &= ~ne
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
        TrG = Tr[~np.isin(Mt, list(NOSHADOW))] if NOSHADOW else Tr      # NOSHADOW things (trees) cast none on the ground either
        _raster(gxa - gmx, gya - gmy, P @ Gz, TrG, GW, GH, gz, gt, g1, g2)
        gs = (1 - _shadow_lookup(gp @ Gx * sk - gmx, gp @ Gy * sk - gmy, gp @ Gz, gz, GW, GH, 0.5, max(2, int(self.px * 1.6)))).reshape(H, W) if GROUND_SHADOW else np.zeros((H, W))   # skipped when unused (slow at high px)
        foot = np.zeros((H, W))
        from PIL import ImageDraw
        im = Image.new('L', (W, H), 0); dr = ImageDraw.Draw(im)
        fx = np.array([p[0] for p in rrect(*FOOT)]); fy = np.array([p[1] for p in rrect(*FOOT)])
        sxp = ((fx - fy) * 32 / T + OX - BB[0]) * self.px; syp = ((fx + fy) * 16 / T + OY - BB[1]) * self.px
        dr.polygon(list(zip(sxp, syp)), fill=255)
        foot = box_blur(np.asarray(im, float) / 255, int(self.px * 1.2))
        ga = np.clip(gs * globals().get('GS_K', 0.32) + foot * globals().get('FOOT_K', 0.35), 0, 0.55) * (1 - img[..., 3])   # GS_K/FOOT_K: per-sheet override (bến ghe)
        if not GROUND_SHADOW: ga = ga * 0.0
        if night and GROUND_GLOW:
            gl = np.zeros(H * W)
            for (gu, gv, gr, gk) in GROUND_GLOW:
                dd = np.hypot(gp[:, 0] - gu * T, gp[:, 1] - gv * T) / gr
                gl = np.maximum(gl, gk * np.clip(1 - dd, 0, 1) ** 1.6 + (np.random.default_rng(5).random(dd.shape) - 0.5) * 0.012 * (dd < 1))   # dither: no rings
            gl = gl.reshape(H, W) * (1 - img[..., 3])
            img[..., :3] += np.array([1.0, 0.62, 0.26]) * gl[..., None]; img[..., 3] += gl
        if night and GROUND_SPILL:                        # lamp light thrown out of a door onto the ground (the door's shape, like the nhà tranh)
            gl = np.zeros(H * W)
            for (pL, rad, gk, (vd, du0, du1, dz0, dz1)) in GROUND_SPILL:
                out_ = gp[:, 1] > vd + 0.3
                t_ = (vd - pL[1]) / np.where(out_, gp[:, 1] - pL[1], 1.0)
                Xc = pL[0] + t_ * (gp[:, 0] - pL[0]); Zc = pL[2] + t_ * (gp[:, 2] - pL[2])
                ok = out_ & (Xc > du0) & (Xc < du1) & (Zc > dz0) & (Zc < dz1)
                dd = np.hypot(gp[:, 0] - (du0 + du1) / 2, gp[:, 1] - vd)   # distance from the door sill
                gl = np.maximum(gl, gk * ok * np.clip(1 - (dd - rad * 0.3) / (rad * 0.7), 0, 1) ** 1.3)   # full near the wall, gone at rad
            gl = box_blur(gl.reshape(H, W), max(1, int(self.px * 0.8))) * (1 - img[..., 3])
            a0 = img[..., 3:4]; a1 = a0 + gl[..., None]               # straight-alpha mix: the pool keeps its full colour off the pad
            img[..., :3] = (img[..., :3] * a0 + np.array([1.0, 0.66, 0.32]) * gl[..., None]) / np.maximum(a1, 1e-6); img[..., 3] = a1[..., 0]
        img[..., :3] *= img[..., 3:4]
        shc = np.array([10, 8, 4]) / 255 if not night else np.array([4, 6, 14]) / 255
        img[..., :3] += shc * ga[..., None]
        img[..., 3] += ga
        return img


def render(level=1, night=False, part='b', ss=2):
    """part 'b': the building (back layer); 'f': the props in front, plus the shade they throw on the building, as an overlay"""
    global VARIANT
    VARIANT = 0
    S, (a, b) = build(level, np.random.default_rng(SEED + level), with_props=False)
    r = R3(PXU * ss); img = r.run(S, night, target=0.42 if night else TARGET_DAY)
    if part == 'f':
        S2, (a, b) = build(level, np.random.default_rng(SEED + level), with_props=True)
        r2 = R3(PXU * ss); full = r2.run(S2, night, target=0.42 if night else TARGET_DAY)
        pm = (r2.obj >= a) & (r2.obj < b)
        lb = img[..., :3].sum(-1) + 1e-4; lf = full[..., :3].sum(-1)
        sh = np.clip(1 - lf / lb, 0, 0.85) * (~pm) * (img[..., 3] > 0.99)
        gnd = np.clip(full[..., 3] - img[..., 3], 0, 1) * (~pm) * (img[..., 3] <= 0.99)
        out = np.zeros_like(full)
        out[pm] = full[pm]
        shc = np.array([0.04, 0.03, 0.02]) if not night else np.array([0.02, 0.025, 0.05])
        k = sh + gnd
        sel = (~pm) & (k > 0.004)
        out[sel, :3] = shc * k[sel, None]; out[sel, 3] = k[sel]
        # anti-alias the prop edge a little (premultiplied)
        img = out
    a_ = np.clip(img, 0, 1); h, w = a_.shape[:2]
    im = Image.frombuffer('RGBa', (w, h), (a_ * 255 + 0.5).astype(np.uint8).tobytes(), 'raw', 'RGBa', 0, 1)
    im = im.resize((w // ss, h // ss), Image.LANCZOS).convert('RGBA')
    if night and GLOWS:                               # lamps read as burning (Link 2026-11-08: "đèn phải phát sáng")
        gl = GLOWS if part != 'f' else [(p, hl, 0.0) for (p, hl, c) in GLOWS]
        im = den.lampglow(im, gl, T, OX, OY, BB, PXU, solid_only=(part == 'f'))
    return im


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
        part = sys.argv[3] if len(sys.argv) > 3 else 'b'; n = len(sys.argv) > 4 and sys.argv[4] == 'n'
        if part == 'all':
            b = render(1, n, 'b'); f = render(1, n, 'f'); b.alpha_composite(f); b.save(sys.argv[2])
        else: render(1, n, part).save(sys.argv[2])
    elif sys.argv[1] == 'atlas':
        out, tab = sys.argv[2], sys.argv[3]
        frames = {}
        for part in ('b', 'f'):
            for n in (0, 1):
                im = render(1, bool(n), part); bb = im.getbbox(); frames[part + ('n' if n else 'd')] = (im.crop(bb), bb)
        keys = ['bd', 'bn', 'fd', 'fn']
        x = 0; G = {}; sc = float(PXU); H = max(f[0].height for f in frames.values())
        sheet = Image.new('RGBA', (sum(frames[k][0].width + 2 for k in keys), H), (0, 0, 0, 0))
        for k in keys:
            im, bb = frames[k]; sheet.paste(im, (x, 0))
            G[k] = [x, 0, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
            x += im.width + 2
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, SHEET), 'WEBP', quality=92, method=6); json.dump(G, open(tab, 'w'))
        print('sheet', sheet.size)
