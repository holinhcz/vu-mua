# Chòi nghỉ mát (pavilion) built as a real 3D model in the kit of the Nhà tranh nhỏ (choi3d.py); and shaded pixel by pixel (Link 2026-11-08: "tạo khung 3D vẽ",
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
# Chòi canh ruộng (game id choi, 1x1, mirror choi2): a field watch hut on four tràm stilts, split-bamboo floor,
# woven half walls at the back, a bamboo ladder at the front-left, small steep nipa roof.
U0, U1, V0, V1 = 0.2, 0.8, 0.2, 0.8           # posts
ZF = 0.0
ZP = 20.0                                       # platform floor top
ZD = ZP
ZW = 41.0                                       # roof plate
RV, RZ = 0.5, 52.5                              # ridge along u
EV, EZ = 0.9, 41.0                             # front eave
BV = 0.1; BZ = EZ
RU0, RU1 = 0.08, 0.92
SMOKE_U = -9.0

BB = (-60, -112, 60, 40)
OX, OY = 0, -16
PL = (0.1, 0.9, 0.1, 0.9)
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
LAMP = W3(U1 - 0.05, 0.44, 30.0)
FEET = [(U0, V0, 2.6), (U1, V0, 2.6), (U0, V1, 2.6), (U1, V1, 2.6), (0.41, 1.24, 1.6), (0.6, 1.24, 1.6)]


def build(t, rng):
    S = Scene(); LIGHTS.clear()
    LIGHTS.append((LAMP + np.array([0, 0, -1.0]), hexc('#ff9645'), 10.0, 2.5))
    def bam(a, b, r, nl=8, foot=0):
        tube(S, a, b, r, M_BAMBOO, prm=(rng.random(), rng.random(), foot), nr=8, nl=nl)
    def lash(c, r, axis='z', n=2):
        """rattan lashing: a couple of turns round a pole at c"""
        for k in range(n):
            o = (k - (n - 1) / 2) * 0.55
            pts = []
            for a in np.linspace(0, 2 * math.pi, 13):
                if axis == 'z': pts.append(c + np.array([math.cos(a) * r, math.sin(a) * r, o]))
                elif axis == 'u': pts.append(c + np.array([o, math.cos(a) * r, math.sin(a) * r]))
                else: pts.append(c + np.array([math.cos(a) * r, o, math.sin(a) * r]))
            for i in range(12): tube(S, pts[i], pts[i + 1], 0.3, M_RATTAN, nr=4, nl=2)
    # four tràm stilts, feet splayed a little, in small mounds of packed mud
    for (u, v) in ((U0, V0), (U1, V0), (U0, V1), (U1, V1)):
        du = 1 if u > 0.5 else -1; dv = 1 if v > 0.5 else -1
        tube(S, W3(u + du * 0.022, v + dv * 0.022, -0.3), W3(u, v, ZW + 1.4), 1.6, M_BARK, prm=(rng.random(), 0, 0), nr=12, nl=10, taper=0.84)
    # platform: two bearers along u, split-bamboo slats along v, clamp poles on top at both ends
    for v in (V0, V1):
        bam(W3(U0 - 0.09, v, ZP - 2.2), W3(U1 + 0.09, v, ZP - 2.2), 1.15, nl=10)
        for u in (U0, U1): lash(W3(u, v, ZP - 2.2), 1.95)
    for u in (U0 + 0.06, 0.5, U1 - 0.06):
        bam(W3(u, V0 - 0.07, ZP - 1.05), W3(u, V1 + 0.07, ZP - 1.05), 0.0001 + 0.5, nl=4)
    u = 0.135
    while u < 0.865:
        r = rng.uniform(0.52, 0.62); v0 = 0.13 + rng.uniform(-0.01, 0.01); v1 = 0.87 + rng.uniform(-0.012, 0.01)
        tube(S, W3(u, v0, ZP - 0.45), W3(u, v1, ZP - 0.45 + rng.uniform(-0.12, 0.12)), r, M_BAMBOO, prm=(rng.random(), rng.random(), 0), nr=7, nl=6)
        u += (2 * r + rng.uniform(0.02, 0.1)) / T
    for v in (0.15, 0.85):
        bam(W3(0.12, v, ZP + 0.35), W3(0.88, v, ZP + 0.35), 0.62, nl=10)
    # X braces under the floor on all four sides, lashed where they cross
    for (a, b) in (((U0, V1), (U1, V1)), ((U1, V0), (U1, V1)), ((U0, V0), (U1, V0)), ((U0, V0), (U0, V1))):
        pa = np.array(a); pb = np.array(b); n = np.array([pb[1] - pa[1], -(pb[0] - pa[0])]) * 0.0
        out = (0.5 - (pa + pb) / 2); out = -out / max(np.linalg.norm(out), 1e-6) * 0.03
        A0 = W3(pa[0] + out[0], pa[1] + out[1], 3.5); A1 = W3(pb[0] + out[0], pb[1] + out[1], ZP - 4.2)
        B0 = W3(pb[0] + out[0], pb[1] + out[1], 3.5); B1 = W3(pa[0] + out[0], pa[1] + out[1], ZP - 4.2)
        bam(A0, A1, 0.72, nl=8); bam(B0, B1, 0.72, nl=8)
        lash((A0 + A1) / 2, 0.95, axis='u' if abs(pa[1] - pb[1]) < 1e-6 else 'v', n=2)
    # the two back sides: open bamboo railings with vertical bars (song tre), no walls (Link: cho thoáng)
    for (pa, pb) in ((W3(U0 - 0.02, V0 - 0.012, 0), W3(U1 + 0.02, V0 - 0.012, 0)), (W3(U0 - 0.012, V0 - 0.02, 0), W3(U0 - 0.012, V1 + 0.02, 0))):
        for z, r in ((ZP + 10.5, 0.85), (ZP + 5.0, 0.6)):
            bam(pa + np.array([0, 0, z]), pb + np.array([0, 0, z]), r, nl=8)
        L = np.linalg.norm(pb - pa); d = (pb - pa) / L; k = 9
        for i in range(1, k):
            q = pa + d * (L * i / k)
            tube(S, q + np.array([0, 0, ZP]), q + np.array([0, 0, ZP + 10.9]), 0.5, M_BAMBOO, prm=(rng.random(), rng.random(), 0), nr=6, nl=3)
    # front-right side: rail + mid rail + three balusters; front-left: rails each side of the ladder gap
    for z, r in ((ZP + 10.5, 0.85), (ZP + 5.0, 0.6)):
        bam(W3(U1 + 0.012, V0 - 0.02, z), W3(U1 + 0.012, V1 + 0.02, z), r, nl=8)
    for v in (0.35, 0.5, 0.65):
        tube(S, W3(U1 + 0.012, v, ZP), W3(U1 + 0.012, v, ZP + 10.9), 0.55, M_BAMBOO, prm=(rng.random(), rng.random(), 0), nr=6, nl=3)
    for (ua, ub) in ((U0 - 0.02, 0.37), (0.65, U1 + 0.02)):
        bam(W3(ua, V1 + 0.012, ZP + 10.5), W3(ub, V1 + 0.012, ZP + 10.5), 0.85, nl=6)
        bam(W3(ua, V1 + 0.012, ZP + 5.0), W3(ub, V1 + 0.012, ZP + 5.0), 0.6, nl=6)
    for u in (0.37, 0.65):
        tube(S, W3(u, V1 + 0.012, ZP), W3(u, V1 + 0.012, ZP + 10.9), 0.6, M_BAMBOO, prm=(rng.random(), rng.random(), 0), nr=6, nl=3)
    # roof plate, gable king posts, gable infill of hanging nipa leaves
    for v in (V0, V1): bam(W3(U0 - 0.08, v, ZW), W3(U1 + 0.08, v, ZW), 1.05, nl=10)
    for u in (U0, U1): bam(W3(u, V0 - 0.08, ZW - 1.6), W3(u, V1 + 0.08, ZW - 1.6), 1.0, nl=10)
    for u in (U0, U1):
        tube(S, W3(u, RV, ZW - 1.6), W3(u, RV, RZ - 1.0), 1.0, M_BAMBOO, prm=(rng.random(), rng.random(), 0), nr=8, nl=6)
    for (u, v, du, dv) in ((U0, V1, 1, 0), (U1, V1, -1, 0), (U1, V1, 0, -1), (U1, V0, 0, 1)):
        bam(W3(u, v, ZW - 7.0), W3(u + du * 0.14, v + dv * 0.14, ZW - 0.8), 0.5, nl=4)
    zr = lambda v: RZ - 2.0 - abs(RV - v) * (RZ - EZ) / (EV - RV)
    for X in (U0 * T, U1 * T):
        def gF(U, Vv, X=X):
            v = V0 + U / T; ztop = np.array([zr(x) for x in v.ravel()]).reshape(v.shape)
            return np.stack([np.full_like(U, X), v * T, ZW + Vv * (ztop - ZW)], -1)
        S.grid(gF, 20, 8, M_GABLE, (0, 0, 0), 0.0, uvr=((0, (V1 - V0) * T), (0, 1)))
    # bamboo ladder leaning on the front bearer, rungs lashed, a flat stone at its foot
    lu = (0.405, 0.605); top_v, top_z = V1 + 0.035, ZP + 3.0; foot_v = 1.24
    for u in lu:
        tube(S, W3(u, foot_v, -0.2), W3(u, top_v, top_z), 0.78, M_BAMBOO, prm=(rng.random(), rng.random(), 1), nr=8, nl=8)
    nR = 6
    for i in range(nR):
        f = (i + 0.7) / (nR + 0.3); v = foot_v + (top_v - foot_v) * f; z = -0.2 + (top_z + 0.2) * f
        bam(W3(lu[0] - 0.03, v, z + 0.4), W3(lu[1] + 0.03, v, z + 0.4), 0.5, nl=4)
    # on the floor: a rolled mat at the back, a clay water jug and a cup
    tube(S, W3(0.27, 0.3, ZP + 1.7), W3(0.62, 0.3, ZP + 1.7), 1.7, M_CHIEU, nr=12, nl=6)
    for uu in (0.27, 0.62): disc(S, W3(uu, 0.3, ZP + 1.7), (1 if uu > 0.5 else -1, 0, 0), 1.7, M_CHIEU, nr=3, na=16)
    jg = W3(0.47, 0.6, ZP)
    # ca nhựa Duy Tân đựng đá (Link): red plastic jug, ribbed body, white lid, red D handle
    lathe(S, jg, [(0, 1.45), (0.12, 1.6), (3.9, 1.72), (4.1, 1.78)], M_CA, na=28)
    disc(S, jg + np.array([0, 0, 0.02]), (0, 0, -1), 1.45, M_CA, nr=2, na=20)
    lathe(S, jg + np.array([0, 0, 4.0]), [(0, 1.9), (0.35, 1.92), (0.55, 1.75), (0.75, 1.2), (0.85, 0.5), (0.9, 0.0)], M_CALID, na=28)
    S0 = Scene(); X3.ellipsoid(S0, jg + np.array([0.0, 0.0, 4.95]), 0.45, 0.45, 0.3, M_CALID, nu=6, nvv=10); S.merge(S0)
    ha = nv([-0.6, 1.0, 0])                                                          # handle on the side toward the viewer, left
    hp = [jg + ha * (1.7 + 1.25 * math.sin(a)) + np.array([0, 0, 2.0 + 1.55 * math.cos(a)]) for a in np.linspace(0, math.pi, 9)]
    for i in range(8): tube(S, hp[i], hp[i + 1], 0.36, M_CA, nr=6, nl=2)
    lathe(S, jg + np.array([-2.9, -0.8, 0]), [(0, 0.45), (0.2, 0.6), (1.1, 0.85), (1.3, 0.88)], M_SU, na=16)
    # hurricane lamp hung from the right tie beam (lit at night)
    hk = W3(LAMP[0] / T, LAMP[1] / T, ZW - 2.6)
    tube(S, hk, LAMP + np.array([0, 0, 4.6]), 0.16, M_SOOT, nr=4, nl=2)
    lb = LAMP - np.array([0, 0, 3.6])
    lathe(S, lb, [(0, 1.5), (0.3, 1.7), (1.2, 1.6), (1.5, 0.9)], M_LAMPBASE)
    lathe(S, lb + np.array([0, 0, 1.5]), [(0, 0.9), (0.8, 1.35), (2.0, 1.45), (3.2, 1.2), (3.9, 0.8)], M_LAMPGLASS)
    lathe(S, lb + np.array([0, 0, 5.3]), [(0, 1.2), (0.6, 1.25), (1.2, 0.6), (1.8, 0.3)], M_LAMPBASE)
    for sg in (-1, 1):
        tube(S, lb + np.array([0, 1.55 * sg, 0.6]), lb + np.array([0, 1.2 * sg, 6.6]), 0.14, M_SOOT, nr=4, nl=2)
    S0 = Scene(); X3.ellipsoid(S0, LAMP - np.array([0, 0, 1.0]), 0.35, 0.35, 0.8, M_FLAME, nu=6, nvv=8); S.merge(S0)
    # a hoe leaning on the right post under the floor
    h0 = W3(U1 + 0.07, 0.33, 0.0); h1 = W3(U1 + 0.02, 0.24, 15.5)
    tube(S, h0 + np.array([0, 0, 2.2]), h1, 0.55, M_HANDLE, nr=6, nl=6)
    d = nv(h1 - h0); bl = h0 + d * 2.2
    a_ = nv(np.cross(d, UP)); out_ = nv(np.array([1.0, 0.3, 0]))
    plane(S, bl - a_ * 1.9, a_ * 3.8, -d * 2.6 + out_ * 0.9, 4, 3, M_IRON)
    def non(c, f, R=3.3):
        f = nv(f); a2 = nv(np.cross(f, UP)) if abs(f[2]) < 0.95 else np.array([1.0, 0, 0]); b2 = np.cross(f, a2)
        def Fn(U, V):
            r = U * R; th = V * 2 * math.pi
            return c[None, None] + (a2 * np.cos(th)[..., None] + b2 * np.sin(th)[..., None]) * r[..., None] + f * (R - r[..., None]) * 1.05
        S.grid(Fn, 7, 28, M_HUSK, (0, 0, 0), 0.0, uvr=((0, 1), (0, 1)), close_v=True, flip=True)
    if t % 2 == 0:
        non(W3(0.36, 0.64, ZP + 0.3), (0.15, 0.1, 1.0))                                # nón lá left on the floor
        # khăn rằn thrown over the front-right rail
        zr_ = ZP + 10.5 + 0.85
        def Fk(U, V):
            v = 0.44 + U / T; s = V                                                    # s -1 .. 1 across the rail
            hang = 4.2 + 0.9 * np.sin(U * 1.3) * 0.4 + np.where(s > 0, 0.8, 0.0)
            x = U1 * T + 0.4 + np.sign(s) * (0.95 + 0.35 * np.abs(s)) * np.minimum(np.abs(s) * 3, 1)
            z = zr_ - np.clip(np.abs(s) * 3 - 0.6, 0, None) / 2.4 * hang + 0.25 * (1 - np.minimum(np.abs(s) * 3, 1))
            return np.stack([x, v * T + 0.2 * np.sin(V * 4 + U), z], -1)
        S.grid(Fk, 10, 16, M_KHAN, (0, 0, 0), 0.0, uvr=((0, 5.2), (-1, 1)))
    else:
        c = W3(U0, V1, ZP - 6.0) + nv([-0.3, 1.0, 0]) * 2.0                            # nón lá hung on the front-left post
        tube(S, W3(U0, V1, ZP - 2.0) + nv([-0.3, 1.0, 0]) * 1.4, W3(U0, V1, ZP - 2.0) + nv([-0.3, 1.0, 0]) * 3.0, 0.3, M_BAMBOO, prm=(0.4, 0.2, 0), nr=5, nl=2)
        non(c, (-0.3, 1.0, 0.3))
        # dây khua lon: a rope from the right rail down to a stake, old tin cans hung on it to scare the birds off the rice
        p0 = W3(U1 + 0.02, 0.27, ZP + 10.6); st = W3(1.04, 0.1, 0.0); p1 = st + np.array([0, 0, 10.0])
        tube(S, st - np.array([0, 0, 0.5]), p1 + np.array([0, 0, 0.8]), 0.6, M_BAMBOO, prm=(0.7, 0.3, 1), nr=6, nl=4)
        pts = [p0 + (p1 - p0) * f - np.array([0, 0, 3.2 * math.sin(math.pi * f)]) for f in np.linspace(0, 1, 9)]
        for i in range(8): tube(S, pts[i], pts[i + 1], 0.22, M_ROPE, nr=4, nl=2)
        for j, f in enumerate((0.3, 0.55, 0.8)):
            q = p0 + (p1 - p0) * f - np.array([0, 0, 3.2 * math.sin(math.pi * f)])
            tube(S, q, q - np.array([0, 0, 1.6]), 0.12, M_ROPE, nr=3, nl=2)
            cb = q - np.array([0, 0, 1.6 + 2.6])
            lathe(S, cb, [(0, 1.0), (0.15, 1.08), (2.45, 1.08), (2.6, 1.0)], M_TIN, prm=(j * 0.3, 0, 0), na=16)
            disc(S, cb, (0, 0, -1), 1.0, M_DARK, nr=2, na=12)
    roof(S, rng, t)
    return S


PATCH = (10.0, 20.0, 3.0, 11.0)                                     # a newer patch on the front slope: along-eave units, up-slope units


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
        p0 = e_front + su * LB * fr + n_out * 1.35 + ax * 1.0
        tube(S, p0, p0 + ax * (Lu - 1.6), 0.42, M_OLDBAMBOO, prm=(rng.random(), 0.5, 0), nr=8, nl=14)
    R = 1.9                                                             # small hut: small ridge (Link)
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
    tube(S, (RU0 * T - 0.5, RV * T, zp), (RU0 * T + Lu + 0.5, RV * T, zp - 0.2), 0.45, M_OLDBAMBOO, prm=(0.4, 0.3, 0), nr=8, nl=20)
    xs = np.array([RU0 * T + Lu * 0.3, RU0 * T + Lu * 0.68]) + rng.uniform(-1.5, 1.5, 2)
    xs = xs[np.abs(xs - SMOKE_U * T) > 6]
    for xl in np.concatenate([xs, xs + 0.75]):                          # rattan ties round pole and ridge, uneven, two turns each
        xl += rng.uniform(-0.15, 0.15); tl = rng.uniform(-0.2, 0.2)
        pts = [np.array([xl + tl * math.cos(a), RV * T + math.cos(a) * (R * 1.12 + 0.5), RZ + 0.6 + math.sin(a) * (R * 1.06 + 0.6) + 0.35 * math.sin(a) ** 8]) for a in np.linspace(0.05, math.pi - 0.05, 11)]
        for i in range(10): tube(S, pts[i], pts[i + 1], 0.26, M_RATTAN, nr=5, nl=2)
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
        inside = np.zeros(len(pos), bool)                         # open pavilion: no walls
        sky = sky * (1 - 0.35 * ((pos[:, 2] > ZD - 1) & (pos[:, 2] < ZW) & (pos[:, 0] > U0 * T) & (pos[:, 0] < U1 * T) & (pos[:, 1] > V0 * T) & (pos[:, 1] < V1 * T)))
        sky = sky * (1 - 0.2 * ((pos[:, 2] < ZP - 1) & (pos[:, 0] > U0 * T) & (pos[:, 0] < U1 * T) & (pos[:, 1] > V0 * T) & (pos[:, 1] < V1 * T)))   # under the floor   # under the roof: half the sky
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
                Lin = False
                if Lin:                                              # lamp indoors: the walls stop it except at door and windows
                    vis = inside.astype(float)
                    out = pos[:, 1] > V1 * T + 0.3
                    t_ = (V1 * T - pL[1]) / np.where(out, pos[:, 1] - pL[1], 1.0)
                    Xc = (pL[0] + t_ * (pos[:, 0] - pL[0])) / T; Zc = pL[2] + t_ * (pos[:, 2] - pL[2])
                    ok = (Xc > DOOR[0]) & (Xc < DOOR[1]) & (Zc > ZF) & (Zc < DOOR[2])
                    for (w0, w1) in WIN:
                        inw = (Xc > w0) & (Xc < w1) & (Zc > WZ[0]) & (Zc < WZ[1])
                        for i in range(1, NBAR):                     # the bamboo bars cast stripes
                            inw &= np.abs(Xc - (w0 + (w1 - w0) * i / NBAR)) * T > 0.6
                        ok |= inw
                    vis = np.maximum(vis, (out & ok).astype(float))
                    I = inten / (1 + (dd / rad) ** 2) * (0.1 + 0.9 * facing) * vis
                else:
                    I = inten / (1 + (dd / rad) ** 2) * (0.25 + 0.75 * facing) * (~inside)
                I[fire | lamp] = 0
                col += alb * cL[None] * I[:, None]
            col[mat == M_LAMPGLASS] = hexc(den.GLASS_NIGHT)
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
        from PIL import ImageDraw
        im = Image.new('L', (W, H), 0); dr = ImageDraw.Draw(im)
        for (u, v, r) in FEET:
            cx = ((u - v) * 32 + OX - BB[0]) * self.px; cy = ((u + v) * 16 + OY - BB[1]) * self.px
            dr.ellipse([cx - r * 2 * self.px, cy - r * self.px, cx + r * 2 * self.px, cy + r * self.px], fill=255)
        foot = box_blur(np.asarray(im, float) / 255, int(self.px * 1.2))
        ga = np.clip(gs * 0.32 + foot * 0.35, 0, 0.55) * (1 - img[..., 3])
        img[..., :3] *= img[..., 3:4]
        shc = np.array([10, 8, 4]) / 255 if not night else np.array([4, 6, 14]) / 255
        img[..., :3] += shc * ga[..., None]
        img[..., 3] += ga
        return img


def render(t=0, night=False, ss=2):
    global VARIANT
    VARIANT = t
    rng = np.random.default_rng(6300 + t * 11)
    S = build(t, rng)
    r = R3(PXU * ss)
    img = r.run(S, night)
    a = np.clip(img, 0, 1); h, w = a.shape[:2]
    im = Image.frombuffer('RGBa', (w, h), (a * 255 + 0.5).astype(np.uint8).tobytes(), 'raw', 'RGBa', 0, 1)
    im = im.resize((w // ss, h // ss), Image.LANCZOS).convert('RGBA')
    if night:                                         # the lamp reads as burning (Link 2026-11-08: "đèn phải phát sáng")
        im = den.lampglow(im, [(LAMP - np.array([0, 0, 1.0]), 0.2, 0.85)], T, OX, OY, BB, PXU)
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
        t = int(sys.argv[3]) if len(sys.argv) > 3 else 0; n = len(sys.argv) > 4 and sys.argv[4] == 'n'
        render(t, n).save(sys.argv[2])
    elif sys.argv[1] == 'atlas':
        out, tab = sys.argv[2], sys.argv[3]
        frames = {}
        for t in range(2):
            for n in (0, 1):
                im = render(t, bool(n)); bb = im.getbbox(); frames[('n' if n else 'd') + str(t)] = (im.crop(bb), bb)
        fw = max(f[0].width for f in frames.values()); fh = max(f[0].height for f in frames.values())
        keys = ['d0', 'n0', 'd1', 'n1']
        sheet = Image.new('RGBA', (4 * (fw + 2), 1 * (fh + 2)), (0, 0, 0, 0)); G = {}; sc = float(PXU)
        for i, k in enumerate(keys):
            im, bb = frames[k]; x = (i % 4) * (fw + 2); y = (i // 4) * (fh + 2); sheet.paste(im, (x, y))
            G[k] = [x, y, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, 'choicanh.webp'), 'WEBP', quality=92, method=6); json.dump(G, open(tab, 'w'))
        print('sheet', sheet.size)
