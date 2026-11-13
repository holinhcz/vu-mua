# pxr: a small per-pixel plant renderer for Nông Trại Nhỏ (v8xx, 2026-11-08, Link: "vẽ thực từng điểm ảnh").
# Plants are built as 3D meshes (leaves with width curvature and folds, thick fleshy leaves, tubes, discs, ellipsoids),
# rasterised with a depth buffer, and every pixel is shaded on its own:
#   - its own normal (smooth across a leaf, so a leaf is light on one side of its fold and dark on the other)
#   - real cast shadows from the sun (shadow map along chuoi.LIGHT, soft PCF): leaves shade the leaves under them
#   - ambient occlusion in the gaps (screen-space, from the depth buffer) and a per-vertex inner darkness
#   - gloss highlights (Blinn), light coming through thin leaves when the sun is behind them
#   - surface detail drawn from the surface coordinates (veins, bands, spots, seed spirals, areoles) per material
#   - the ground shadow: the shadow map cast onto the ground plane plus a soft contact shade under the plant
#   - a thin edge a shade darker where one surface passes in front of another (the game's crisp sprite look)
# Same camera, sun and night transform as the cairo kits (../chuoi): x right, y toward the viewer, z up.
# Needs numpy, numba (pip install numba) and PIL.
import math
import numpy as np
from numba import njit
from PIL import Image
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'chuoi'))
import chuoi as ch
from chuoi import nv, LIGHT, TOCAM, CE, SE

UP = np.array([0.0, 0.0, 1.0])
VIEW = TOCAM
HALF = nv(LIGHT + VIEW)


def hexc(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)])


def ramp(cols, t):
    """cols: list of hex, t array 0..1 -> (n,3)"""
    C = np.array([hexc(c) for c in cols]); t = np.clip(np.asarray(t, float), 0, 1) * (len(C) - 1)
    i = np.minimum(t.astype(int), len(C) - 2); f = (t - i)[..., None]
    return C[i] * (1 - f) + C[i + 1] * f


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0, 1)
    return t * t * (3 - 2 * t)


def hash1(*a):
    """cheap per-pixel hash noise 0..1"""
    x = np.zeros_like(np.asarray(a[0], float))
    for k, v in enumerate(a):
        x = x + np.asarray(v, float) * (12.9898 + 31.4 * k)
    return np.modf(np.abs(np.sin(x) * 43758.5453))[0]


def vnoise(x, y, seed=0.0):
    """smooth value noise"""
    xi = np.floor(x); yi = np.floor(y); fx = x - xi; fy = y - yi
    ux = fx * fx * (3 - 2 * fx); uy = fy * fy * (3 - 2 * fy)
    a = hash1(xi, yi, seed); b = hash1(xi + 1, yi, seed); c = hash1(xi, yi + 1, seed); d = hash1(xi + 1, yi + 1, seed)
    return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy


# ------------------------------------------------------------------ raster kernel
@njit(cache=True)
def _raster(X, Y, Z, T, W, H, zb, tb, b1, b2):
    for t in range(T.shape[0]):
        i0, i1, i2 = T[t, 0], T[t, 1], T[t, 2]
        x0, y0, x1, y1, x2, y2 = X[i0], Y[i0], X[i1], Y[i1], X[i2], Y[i2]
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if abs(area) < 1e-12:
            continue
        xa = int(max(0.0, math.floor(min(x0, min(x1, x2)))))
        xb = int(min(W - 1.0, math.ceil(max(x0, max(x1, x2)))))
        ya = int(max(0.0, math.floor(min(y0, min(y1, y2)))))
        yb = int(min(H - 1.0, math.ceil(max(y0, max(y1, y2)))))
        inv = 1.0 / area
        for py in range(ya, yb + 1):
            cy = py + 0.5
            for px in range(xa, xb + 1):
                cx = px + 0.5
                w1 = ((cx - x0) * (y2 - y0) - (x2 - x0) * (cy - y0)) * inv
                w2 = ((x1 - x0) * (cy - y0) - (cx - x0) * (y1 - y0)) * inv
                w0 = 1.0 - w1 - w2
                if w0 < -1e-6 or w1 < -1e-6 or w2 < -1e-6:
                    continue
                z = w0 * Z[i0] + w1 * Z[i1] + w2 * Z[i2]
                if z > zb[py, px]:
                    zb[py, px] = z; tb[py, px] = t; b1[py, px] = w1; b2[py, px] = w2


@njit(cache=True)
def _shadow_lookup(SX, SY, SZ, sm, W, H, bias, rad):
    n = SX.shape[0]
    out = np.ones(n)
    for i in range(n):
        tot = 0.0; cnt = 0.0
        for dy in range(-rad, rad + 1):
            for dx in range(-rad, rad + 1):
                x = int(SX[i]) + dx; y = int(SY[i]) + dy
                cnt += 1.0
                if x < 0 or y < 0 or x >= W or y >= H:
                    tot += 1.0
                elif sm[y, x] <= SZ[i] + bias:
                    tot += 1.0
        out[i] = tot / cnt
    return out


def box_blur(a, r):
    if r < 1: return a
    k = 2 * r + 1
    p = np.pad(a, r, mode='edge').astype(np.float64)
    c = np.cumsum(np.cumsum(p, 0), 1)
    c = np.pad(c, ((1, 0), (1, 0)))
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)


# ------------------------------------------------------------------ scene
class Scene:
    def __init__(self):
        self.P, self.N, self.UV, self.A = [], [], [], []      # per vertex: pos, normal, uv, ao(0 lit..1 dark)
        self.T, self.M, self.Q, self.O = [], [], [], []         # per tri: idx, material id, params(3), surface id
        self.nv = 0; self.ns = 0

    def grid(self, F, nu, nv_, mat, prm=(0, 0, 0), ao=None, uvr=((0, 1), (0, 1)), close_v=False, flip=False):
        """F(U,V) -> (nu,nv,3) positions over U in uvr[0], V in uvr[1]. Normals by differences."""
        u = np.linspace(uvr[0][0], uvr[0][1], nu); v = np.linspace(uvr[1][0], uvr[1][1], nv_, endpoint=not close_v)
        U, V = np.meshgrid(u, v, indexing='ij')
        Pp = F(U, V)
        du = np.gradient(Pp, axis=0) if nu > 1 else np.zeros_like(Pp)
        if close_v:
            dv = (np.roll(Pp, -1, 1) - np.roll(Pp, 1, 1)) / 2
        else:
            dv = np.gradient(Pp, axis=1)
        n = np.cross(du, dv)
        if flip: n = -n
        ln = np.linalg.norm(n, axis=2, keepdims=True)
        bad = ln[..., 0] < 1e-12
        n = n / np.maximum(ln, 1e-12)
        if bad.any():
            # degenerate rows (tips, poles): take the neighbour's normal
            for i in np.argwhere(bad):
                a, b = i
                j = a - 1 if a > 0 else a + 1
                n[a, b] = n[j, b]
        A = np.zeros((nu, nv_)) if ao is None else (ao(U, V) if callable(ao) else np.full((nu, nv_), float(ao)))
        base = self.nv
        idx = np.arange(nu * nv_).reshape(nu, nv_) + base
        a = idx[:-1, :(None if close_v else -1)]
        b = idx[1:, :(None if close_v else -1)]
        c = np.roll(idx, -1, 1)[1:, :(None if close_v else -1)]
        d = np.roll(idx, -1, 1)[:-1, :(None if close_v else -1)]
        tris = np.concatenate([np.stack([a, b, c], -1).reshape(-1, 3), np.stack([a, c, d], -1).reshape(-1, 3)])
        self.P.append(Pp.reshape(-1, 3)); self.N.append(n.reshape(-1, 3)); self.UV.append(np.stack([U, V], -1).reshape(-1, 2))
        self.A.append(A.reshape(-1)); self.T.append(tris)
        self.M.append(np.full(len(tris), mat, np.int32)); self.Q.append(np.tile(np.asarray(prm, float), (len(tris), 1)))
        self.O.append(np.full(len(tris), self.ns, np.int64)); self.ns += 1
        self.nv += nu * nv_

    def merge(self, o, off=(0, 0, 0), sc=1.0):
        for k in range(len(o.P)):
            self.P.append(o.P[k] * sc + np.asarray(off)); self.N.append(o.N[k]); self.UV.append(o.UV[k]); self.A.append(o.A[k])
            self.T.append(o.T[k] + self.nv); self.M.append(o.M[k]); self.Q.append(o.Q[k])
            self.O.append(np.full(len(o.T[k]), self.ns, np.int64)); self.ns += 1
            self.nv += len(o.P[k])

    def arrays(self):
        return (np.concatenate(self.P), np.concatenate(self.N), np.concatenate(self.UV), np.concatenate(self.A),
                np.concatenate(self.T).astype(np.int64), np.concatenate(self.M), np.concatenate(self.Q), np.concatenate(self.O))


# ------------------------------------------------------------------ primitives (all return via Scene.grid)
def frame_of(d):
    d = nv(d)
    s = np.cross(UP, d)
    s = nv(s) if np.linalg.norm(s) > 1e-4 else np.array([1.0, 0, 0])
    n = nv(np.cross(d, s))
    if n[2] < 0: n = -n
    return d, s, n


def interp_prof(prof, U):
    us = np.array([p[0] for p in prof]); ws = np.array([p[1] for p in prof])
    return np.interp(U, us, ws)


def leaf(S, base, d, L, W, droop=0.3, prof=None, fold=0.15, curl=0.0, twist=0.0, mat=1, prm=(0, 0, 0), ao=0.0,
         nu=14, nvv=7, side_tilt=0.0, wave=0.0, sag=0.0):
    """a thin leaf blade: centre line from base along d, falling by droop*L*u^2; width W*prof(u);
    fold > 0 lifts the edges (a V/U channel), twist rolls it along its length, sag bends the tip back down."""
    d, s0, n0 = frame_of(d)
    prof = prof or [(0, 0.12), (0.12, 0.6), (0.32, 0.95), (0.5, 1.0), (0.7, 0.82), (0.88, 0.42), (1.0, 0.0)]
    base = np.asarray(base, float)
    if side_tilt:
        s0 = nv(s0 * math.cos(side_tilt) + n0 * math.sin(side_tilt)); n0 = nv(np.cross(d, s0))
        if n0[2] < 0: n0 = -n0

    def F(U, V):
        Uc = U[..., None]
        c = base + d * L * Uc - UP * droop * L * Uc ** 2 - UP * sag * L * np.maximum(0, Uc - 0.6) ** 2 * 2.5
        w = (W * 0.5 * interp_prof(prof, U))[..., None]
        ang = (twist * U)[..., None]
        s = s0 * np.cos(ang) + n0 * np.sin(ang)
        nn = n0 * np.cos(ang) - s0 * np.sin(ang)
        Vc = V[..., None]
        off = s * w * Vc + nn * (fold * w * Vc ** 2 - curl * w * (1 - Vc ** 2)) + nn * wave * w * np.sin(U[..., None] * 9 + Vc * 2) * 0.4
        return c + off
    S.grid(F, nu, nvv, mat, prm, ao, uvr=((0, 1), (-1, 1)))


def tube(S, pts, r0, r1, mat=8, prm=(0, 0, 0), ao=0.0, nr=7, caps=False):
    """a round stalk along a polyline, radius r0 -> r1"""
    pts = np.asarray(pts, float); n = len(pts)
    tg = np.gradient(pts, axis=0); tg = tg / np.maximum(np.linalg.norm(tg, axis=1, keepdims=True), 1e-9)
    ref = np.array([1.0, 0, 0]) if abs(tg[0][0]) < 0.9 else np.array([0, 1.0, 0])
    B1 = []; b = nv(np.cross(tg[0], ref))
    for k in range(n):
        b = nv(b - tg[k] * (b @ tg[k])); B1.append(b)
    B1 = np.array(B1); B2 = np.cross(tg, B1)

    def F(U, V):
        i = np.clip((U * (n - 1)).round().astype(int), 0, n - 1)
        r = (r0 + (r1 - r0) * U)[..., None]
        th = (V * 2 * math.pi)[..., None]
        return pts[i] + (B1[i] * np.cos(th) + B2[i] * np.sin(th)) * r
    S.grid(F, n, nr, mat, prm, ao, uvr=((0, 1), (0, 1)), close_v=True, flip=True)


def ellipsoid(S, c, rx, ry, rz, mat, prm=(0, 0, 0), ao=0.0, axes=None, nu=10, nvv=14, zmin=None, bulge=None):
    """axes = (a, b, c) unit vectors (default world); zmin cuts the bottom (seen from above it never shows)"""
    c = np.asarray(c, float)
    ax = axes or (np.array([1.0, 0, 0]), np.array([0, 1.0, 0]), UP)

    def F(U, V):
        th = (U * math.pi - math.pi / 2)[..., None]; ph = (V * 2 * math.pi)[..., None]
        x = np.cos(th) * np.cos(ph) * rx; y = np.cos(th) * np.sin(ph) * ry; z = np.sin(th) * rz
        if bulge is not None:
            z = z + bulge(U, V)[..., None]
        return c + ax[0] * x + ax[1] * y + ax[2] * z
    S.grid(F, nu, nvv, mat, prm, ao, uvr=((0 if zmin is None else zmin, 1), (0, 1)), close_v=True, flip=True)


def disc(S, c, f, R, mat, prm=(0, 0, 0), dome=0.0, nr=8, na=28, ao=0.0, r0=0.0):
    """a round disc facing f, domed by dome*R in the middle"""
    u, v = basis(f)
    c = np.asarray(c, float)

    def F(U, V):
        r = (U * R)[..., None]; th = (V * 2 * math.pi)[..., None]
        return c + (u * np.cos(th) + v * np.sin(th)) * r + f * dome * R * (1 - U[..., None] ** 2)
    S.grid(F, nr, na, mat, prm, ao, uvr=((r0, 1), (0, 1)), close_v=True, flip=True)


def basis(f):
    f = nv(f)
    u = np.cross(f, UP); u = nv(u) if np.linalg.norm(u) > 1e-3 else np.array([1.0, 0, 0])
    return u, nv(np.cross(f, u))


def petal(S, c, f, a, R, W, cup=0.3, mat=3, prm=(0, 0, 0), prof=None, tilt=0.0, reflex=0.0, nu=7, nvv=5, ao=0.0, notch=0.0):
    """one petal of a flower facing f, pointing at angle a round it; cup lifts it toward f, reflex bends the tip back"""
    u, v = basis(f)
    e = math.cos(a) * u + math.sin(a) * v
    s = -math.sin(a) * u + math.cos(a) * v
    e = nv(e + f * tilt)
    prof = prof or [(0, 0.25), (0.25, 0.8), (0.55, 1.0), (0.8, 0.85), (1.0, 0.0)]
    c = np.asarray(c, float)

    def F(U, V):
        Uc = U[..., None]; Vc = V[..., None]
        w = (W * 0.5 * interp_prof(prof, U))[..., None]
        if notch: w = w * (1 - notch * smooth(0.85, 1.0, Uc) * (1 - np.abs(Vc)))
        lift = cup * R * Uc ** 2 - reflex * R * np.maximum(0, Uc - 0.55) ** 2 * 3
        return c + e * R * Uc + s * w * Vc + f * (lift + 0.12 * W * Vc ** 2)
    S.grid(F, nu, nvv, mat, prm, ao, uvr=((0, 1), (-1, 1)))


# ------------------------------------------------------------------ the renderer
class Render:
    """bb in game units (x0,y0,x1,y1) round the plant's foot; ku = game units per metre; px = pixels per game unit"""
    def __init__(self, bb, ku, px):
        self.bb, self.ku, self.px = bb, ku, px
        self.W = int((bb[2] - bb[0]) * px); self.H = int((bb[3] - bb[1]) * px)
        self.k = ku * px; self.ox = -bb[0] * px; self.oy = -bb[1] * px

    def proj(self, P):
        return self.ox + P[:, 0] * self.k, self.oy + (0.5 * P[:, 1] - 0.866 * P[:, 2]) * self.k, P[:, 1] * CE + P[:, 2] * SE

    def run(self, S, materials, night=False, shadow_k=1.0, ground=True, ground_r=0.6, edge=0.78, look=None):
        look = look or {}
        P, N, UV, AOv, T, M, Q, O = S.arrays()
        W, H = self.W, self.H
        X, Y, Z = self.proj(P)
        zb = np.full((H, W), -1e9); tb = np.full((H, W), -1, np.int64); b1 = np.zeros((H, W)); b2 = np.zeros((H, W))
        _raster(X, Y, Z, T, W, H, zb, tb, b1, b2)
        cov = tb >= 0
        idx = np.nonzero(cov)
        tri = tb[idx]; w1 = b1[idx]; w2 = b2[idx]; w0 = 1 - w1 - w2
        I0, I1, I2 = T[tri, 0], T[tri, 1], T[tri, 2]
        def itp(A):
            if A.ndim == 1: return A[I0] * w0 + A[I1] * w1 + A[I2] * w2
            return A[I0] * w0[:, None] + A[I1] * w1[:, None] + A[I2] * w2[:, None]
        pos = itp(P); nrm = itp(N); uv = itp(UV); vao = itp(AOv)
        nrm = nrm / np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9)
        mat = M[tri]; prm = Q[tri]
        back = (nrm @ VIEW) < 0
        nrm[back] = -nrm[back]

        # ---- shadow map along the sun
        Lz = LIGHT; Lx = nv(np.cross(UP, Lz)); Ly = np.cross(Lz, Lx)
        sk = self.k * 0.9
        SXa = P @ Lx * sk; SYa = P @ Ly * sk
        mx, my = SXa.min() - 4, SYa.min() - 4
        SW = int(SXa.max() - mx + 8); SH = int(SYa.max() - my + 8)
        smz = np.full((SH, SW), -1e9); smt = np.full((SH, SW), -1, np.int64); s1 = np.zeros((SH, SW)); s2 = np.zeros((SH, SW))
        _raster(SXa - mx, SYa - my, P @ Lz, T, SW, SH, smz, smt, s1, s2)
        def shadow_at(pp, bias, rad):
            return _shadow_lookup(pp @ Lx * sk - mx, pp @ Ly * sk - my, pp @ Lz, smz, SW, SH, bias, rad)
        sh = shadow_at(pos + nrm * 0.004, 0.02, max(1, int(self.px * 0.25)))

        # ---- screen space occlusion from the depth buffer (world depth)
        zw = np.where(cov, zb, np.nan)
        zfill = np.where(cov, zb, np.nanmin(zw) if cov.any() else 0)
        occ = np.zeros((H, W))
        for r, wgt in ((int(self.k * 0.03), 0.5), (int(self.k * 0.09), 0.5)):
            zbl = box_blur(zfill, max(1, r)); cvb = box_blur(cov.astype(float), max(1, r))
            occ += wgt * np.clip((zbl - zfill) / 0.08, 0, 1) * np.clip(cvb * 1.4, 0, 1)
        ssao = 1 - 0.55 * occ[idx]

        # ---- materials
        alb = np.zeros((len(tri), 3)); gloss = np.zeros(len(tri)); shin = np.full(len(tri), 30.0); trans = np.zeros(len(tri))
        for m_id, fn in materials.items():
            sel = mat == m_id
            if not sel.any(): continue
            a, g, s_, t_ = fn(uv[sel, 0], uv[sel, 1], prm[sel], back[sel], pos[sel], nrm[sel])
            alb[sel] = a; gloss[sel] = g; shin[sel] = s_; trans[sel] = t_

        # ---- light
        nl = nrm @ LIGHT
        geo_back = np.where(back, -1, 1)
        diff = np.clip((nl + 0.22) / 1.22, 0, 1) * (sh * shadow_k + (1 - shadow_k))
        sky = (0.56 + 0.22 * nrm[:, 2]) * ssao * (1 - 0.55 * vao)
        sunc = np.array(look.get('sun', (1.02, 0.98, 0.88))); skyc = np.array(look.get('sky', (0.58, 0.66, 0.74)))
        col = alb * (diff[:, None] * sunc * look.get('kd', 0.9) + sky[:, None] * skyc)
        # light through the leaf: the leaf faces away from the sun but the sun is behind it
        through = np.clip(-nl, 0, 1) * sh * trans
        col += alb * np.array([1.05, 1.15, 0.55]) * through[:, None] * 0.55
        hh = np.clip(nrm @ HALF, 0, 1)
        col += (gloss * hh ** shin * sh)[:, None] * np.array([1.0, 1.0, 0.92]) * 0.6

        col = np.clip(col, 0, 1)
        if look.get('target'):
            # match the game's bright sprites: lift the plant's mean brightness to the target with a gamma
            # (shadows rise more than highlights, so the shading stays but nothing reads muddy)
            lum = np.clip(col @ np.array([0.299, 0.587, 0.114]), 1e-4, 1)
            lo, hi = 0.3, 1.0
            for _ in range(30):
                gm = (lo + hi) / 2
                if (lum ** gm).mean() > look['target']: lo = gm
                else: hi = gm
            gm = (lo + hi) / 2
            col = col * (lum ** gm / lum)[:, None]
            col = np.clip(col, 0, 1)
        img = np.zeros((H, W, 4))
        img[idx[0], idx[1], :3] = col; img[idx[0], idx[1], 3] = 1

        # ---- crisp edge where a surface passes over another (or over the ground)
        if edge:
            tid = np.where(cov, tb, -1)
            obj = np.where(cov, O[np.maximum(tb, 0)], -1)
            dz = np.zeros((H, W))
            for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
                zn = np.roll(np.roll(zfill, dy, 0), dx, 1); on = np.roll(np.roll(obj, dy, 0), dx, 1)
                cn = np.roll(np.roll(cov, dy, 0), dx, 1)
                far = (zfill - zn > 0.035) | (~cn)
                dz = np.maximum(dz, (far & ((on != obj) | (~cn) | (zfill - zn > 0.06))).astype(float))
            e = cov & (dz > 0)
            img[e, :3] *= edge

        # ---- ground: cast shadow + contact shade
        if ground:
            gy, gx = np.mgrid[0:H, 0:W]
            gp = np.stack([(gx + 0.5 - self.ox) / self.k, (gy + 0.5 - self.oy) / self.k / 0.5, np.zeros_like(gx, float)], -1).reshape(-1, 3)
            # the ground shadow uses a higher sun than the plant itself, so it stays short like the game's
            Gz = nv(np.array(look.get('gsun', (-0.42, 0.3, 1.25)))); Gx = nv(np.cross(UP, Gz)); Gy = np.cross(Gz, Gx)
            gxa = P @ Gx * sk; gya = P @ Gy * sk; gmx, gmy = gxa.min() - 4, gya.min() - 4
            GW = int(gxa.max() - gmx + 8); GH = int(gya.max() - gmy + 8)
            gz = np.full((GH, GW), -1e9); gt = np.full((GH, GW), -1, np.int64); g1 = np.zeros((GH, GW)); g2 = np.zeros((GH, GW))
            _raster(gxa - gmx, gya - gmy, P @ Gz, T, GW, GH, gz, gt, g1, g2)
            gs = 1 - _shadow_lookup(gp @ Gx * sk - gmx, gp @ Gy * sk - gmy, gp @ Gz, gz, GW, GH, 0.01, max(2, int(self.px * 0.7)))
            gs = gs.reshape(H, W)
            # contact: a soft dark where the plant stands (top-down coverage blurred)
            tx = P[:, 0] * self.k; ty = P[:, 1] * self.k * 0.5
            tz = np.full((H, W), -1e9); tt = np.full((H, W), -1, np.int64); q1 = np.zeros((H, W)); q2 = np.zeros((H, W))
            low = 1.0 / (1.0 + np.maximum(P[:, 2], 0) / 0.25)
            _raster(tx + self.ox, ty + self.oy, -P[:, 2], T, W, H, tz, tt, q1, q2)
            topc = (tt >= 0).astype(float)
            cont = box_blur(topc, int(self.k * 0.06)) * 0.6 + box_blur(topc, int(self.k * 0.14)) * 0.4
            ga = np.clip(gs * look.get('gshadow', 0.26) + cont * look.get('gcontact', 0.2), 0, 0.5)
            ga = ga * (1 - img[..., 3])
            img[..., :3] = img[..., :3] * img[..., 3:4]                # premultiplied
            img[..., 3] = img[..., 3] + ga
        else:
            img[..., :3] = img[..., :3] * img[..., 3:4]

        if night:
            rgb = img[..., :3] / np.maximum(img[..., 3:4], 1e-6)
            g = (rgb[..., 1] > rgb[..., 0]) & (rgb[..., 1] > rgb[..., 2])
            ext = np.concatenate([rgb, np.ones_like(rgb[..., :1])], -1)
            rgb = np.where(g[..., None], ext @ ch._NG_GREEN, ext @ ch._NG)
            img[..., :3] = np.clip(rgb, 0, 1) * img[..., 3:4]
        return img

    @staticmethod
    def to_image(img, ss):
        a = np.clip(img, 0, 1)
        h, w = a.shape[:2]
        im = Image.frombuffer('RGBa', (w, h), (a * 255 + 0.5).astype(np.uint8).tobytes(), 'raw', 'RGBa', 0, 1)
        return im.resize((w // ss, h // ss), Image.LANCZOS).convert('RGBA')
