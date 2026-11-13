# v843 bụi sen (Nelumbo nucifera) for Nông Trại Nhỏ, redrawn per pixel (Link: "chi tiết từng điểm đâu sao toàn mảng màu
# thế / làm 4 màu trắng hồng tím vàng"). Every part is a real 3D surface sampled densely, lit pixel by pixel from its own
# normal, with painted detail on top, then given the kit's thin edge in its own colour (fill * 0.8), at 9 px per unit.
#   - floating pads: wavy notched discs, radial veins forking near the rim, a pale navel, grain and mottling, water beads;
#     one old yellowing pad with brown blotches and a ragged rim; a soft shadow on the water
#   - raised leaves: shallow glaucous cups on tall prickly stalks, veins, the paler underside where the wavy rim turns over,
#     a bead of water rolling in the cup
#   - flowers: three rings of cupped petals, colour flushing from the base to the tip, fine veins, a golden ring of stamens
#     with white anther tips round the flat seed pod with its stigma holes; buds with petal seams; one nodding seed pod
# Colours by seed: 0 hồng, 1 trắng, 2 tím, 3 vàng. Frames lotus0-3, d and n. Sheet drawn by patch_sen.py.
import math, os, sys
import numpy as np, cairo
from scipy.ndimage import gaussian_filter, binary_closing, distance_transform_edt
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'co', 'dambut', 'hoaco'):
    sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import C, nv, mixc, depth, LIGHT, TOCAM
import co
from co import ground_shadow, Plant
from hoaco import Mini, UP, basis

KU = 29.0 * 1.45
SS = 2                      # supersampling of every surface (on top of the kit's own 2x)
HALF = nv(LIGHT + TOCAM)    # for the small wet highlights

PETALS = {   # base (inside, at the heart), mid, tip, deep (shadow tone), vein
    0: ('#fff6f2', '#ffc6da', '#e8508e', '#a82464', '#d0487e'),       # hồng
    1: ('#f2f4dc', '#fffefa', '#fbf9f0', '#bdb8a4', '#d6d4bc'),       # trắng
    2: ('#fbf2fc', '#d6b0ec', '#9256c8', '#55247e', '#8a4cba'),       # tím
    3: ('#fff8dc', '#ffe682', '#f4c020', '#b47c08', '#d8a018'),       # vàng
}


def A_(c): return np.array(c, float)


def ramp(stops, s):
    S = np.array(stops, float); n = len(S)
    x = np.clip(s, 0, 1) * (n - 1); i = np.clip(np.floor(x).astype(int), 0, n - 2); f = (x - i)[..., None]
    return S[i] * (1 - f) + S[i + 1] * f


def vnoise(x, y, seed=0):
    """smooth value noise, about one bump per unit of x, y"""
    xi = np.floor(x).astype(np.int64); yi = np.floor(y).astype(np.int64)
    fx = x - xi; fy = y - yi; fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
    def h(i, j):
        v = (i * 374761393 + j * 668265263 + seed * 1013904223) & 0xffffffff
        v = ((v ^ (v >> 13)) * 1274126177) & 0xffffffff
        return ((v ^ (v >> 16)) & 0xffff) / 65535.0
    a = h(xi, yi); b = h(xi + 1, yi); c = h(xi, yi + 1); d = h(xi + 1, yi + 1)
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy


def fbm(x, y, seed=0, oct=3):
    s = 0; amp = 0.5; tot = 0
    for o in range(oct):
        s = s + amp * vnoise(x, y, seed + o * 17); tot += amp; x = x * 2.03 + 3.1; y = y * 2.03 + 1.7; amp *= 0.5
    return s / tot


def mix(a, b, t):
    t = np.asarray(t, float)
    if t.ndim: t = t[..., None]
    return a + (b - a) * t


class Sen(Mini):
    EDGE_DZ = 1e-4      # how far behind a neighbour must be to draw the edge (Kit raises it: no lines where leaves cross)
    def __init__(self, seed, pa):
        self.pa = pa; self.seed = seed; self.kind = 'sen'
        self.r = r = np.random.default_rng(seed * 5051 + 77)
        self.items = []
        self.R = 0.8
        import hoaco; self.G = hoaco.greens()
        q = seed % 4
        self.pad_pal = [A_(C(h)) for h in ('#163f22', '#22592c', '#2f7236', '#468c40', '#64a650', '#8cc06a')]
        self.cup_pal = [A_(C(h)) for h in ('#143a26', '#1e5030', '#2a683c', '#3e8248', '#5e9e5c', '#86ba7a')]
        self.und = [A_(C(h)) for h in ('#4e7254', '#68886a', '#86a482', '#a6c09c')]
        self.bloom = A_(C('#b4d0b8'))
        self.old = [A_(C(h)) for h in ('#5a4618', '#76621e', '#96842e', '#b8a444', '#d4c068', '#e4d488')]
        self.brown = A_(C('#6e4a1c'))
        self.water_sh = C('#0e2a30')
        self.stem_pal = [A_(C(h)) for h in ('#28461c', '#3c6226', '#527e32', '#6e9a40', '#8cb456')]
        self.prick = A_(C('#3a3a18'))
        pb, pm, pt, pd, pv = PETALS[q]
        self.pet = dict(base=A_(C(pb)), mid=A_(C(pm)), tip=A_(C(pt)), deep=A_(C(pd)), vein=A_(C(pv)),
                        heart=A_(C('#f2eca8')), green=A_(C('#b8cc80')))
        self.gold = [A_(C(h)) for h in ('#8a5a08', '#c88a10', '#f0b828', '#ffd850', '#fff2b0')]
        self.podc = [A_(C(h)) for h in ('#4a6a1c', '#7a9a30', '#a8c444', '#cadc6a', '#e4ee9a')]
        self.stig = A_(C('#f0d040'))
        # ---- layout: pads spread on the water, raised cups behind, flowers and buds standing up among them
        npad = [7, 6, 8, 7][q]
        a0 = r.uniform(0, 6.28)
        for k in range(npad):
            a = a0 + k * 2.4 + r.normal(0, 0.25); d = 0.2 + 0.48 * math.sqrt((k + 0.5) / npad)
            c = np.array([math.cos(a) * d, math.sin(a) * d * 0.8, 0.0])
            self.pad(c, r.uniform(0.17, 0.26) * (1.1 - 0.3 * d), r.uniform(0, 6.28), old=(k == npad - 2 and q != 1))
        ncup = [3, 4, 3, 2][q]
        for k in range(ncup):
            a = a0 + 0.9 + k * 2.1 + r.normal(0, 0.3); d = r.uniform(0.1, 0.45)
            b = np.array([math.cos(a) * d, math.sin(a) * d * 0.7 - 0.12, 0.0])
            H = r.uniform(0.38, 0.7); top = b + np.array([math.cos(a) * 0.08, math.sin(a) * 0.05, H])
            self.cup(b, top, r.uniform(0.24, 0.32), nv(np.array([math.cos(a) * 0.35, math.sin(a) * 0.25 + 0.15, 1.0])), bead=(k == 0))
        nfl = [2, 2, 3, 1][q]
        for k in range(nfl):
            a = a0 + 2.0 + k * 2.3 + r.normal(0, 0.3); d = r.uniform(0.05, 0.35)
            b = np.array([math.cos(a) * d, math.sin(a) * d * 0.7, 0.0])
            H = r.uniform(0.62, 0.9); top = b + np.array([math.cos(a) * 0.06, 0.03, H])
            self.stalk_line(b, top)
            self.lotus_flower(top, nv(np.array([math.cos(a) * 0.25, 0.45, 1.0])), r.uniform(0.2, 0.25), k)
        for k in range([2, 1, 2, 2][q]):
            a = a0 + 3.5 + k * 1.7; d = r.uniform(0.1, 0.4)
            b = np.array([math.cos(a) * d, math.sin(a) * d * 0.7, 0.0])
            top = b + np.array([math.cos(a) * 0.04, 0.0, r.uniform(0.55, 0.8)])
            self.stalk_line(b, top)
            self.bud(top, nv(np.array([math.cos(a) * 0.15, 0.1, 1.0])), r.uniform(0.07, 0.09))
        if q in (1, 2):
            a = a0 + 5.0; b = np.array([math.cos(a) * 0.3, math.sin(a) * 0.2, 0.0])
            top = b + np.array([0.05, 0.02, 0.7])
            self.stalk_line(b, top, bend=np.array([0.12, 0.0, -0.05]))
            self.pod(top + np.array([0.06, 0.0, -0.02]), nv(np.array([0.6, 0.35, 0.7])), 0.07, ripe=(q == 2))

    # ------------------------------------------------------------------ the per-pixel surface painter
    def splat(self, geo, shade_fn, key_pt, closed=False, edge_k=0.8, edge_w=1.0, zflat=None, zk=0.02):
        """geo(A, B) -> (n, m, 3) world points over A, B in [0, 1]; shade_fn(P, N, front, A, B) -> rgb (n, m, 3) or
        (rgb, mask). The surface is sampled finer than the supersampled pixel, lit per sample from its normal, and
        merged into one z-buffer shared by the whole clump (so stalks, cups and petals cross each other correctly).
        paint() then gives every surface the kit's thin edge in its own colour where it meets something behind it."""
        pa = self.pa
        def draw():
            k = pa.k
            def proj(P): return pa.ox + P[..., 0] * k, pa.oy + (0.5 * P[..., 1] - 0.866 * P[..., 2]) * k
            a = np.linspace(0, 1, 33); A, B = np.meshgrid(a, a, indexing='ij')
            X, Y = proj(geo(A, B))
            da = np.hypot(np.diff(X, axis=0), np.diff(Y, axis=0)).max(); db = np.hypot(np.diff(X, axis=1), np.diff(Y, axis=1)).max()
            na = int(min(2400, max(8, da * 32 * SS * 1.5))); nb = int(min(4000, max(8, db * 32 * SS * 1.5)))
            A, B = np.meshgrid(np.linspace(0, 1, na), np.linspace(0, 1, nb), indexing='ij')
            P = geo(A, B)
            dA = np.gradient(P, axis=0); dB = np.gradient(P, axis=1)
            N = np.cross(dA, dB); ln = np.linalg.norm(N, axis=-1, keepdims=True)
            bad = ln[..., 0] < 1e-12
            N = N / np.maximum(ln, 1e-12)
            if bad.any():                     # a pole of a polar grid: borrow the neighbour's normal
                bi, bj = np.nonzero(bad)
                N[bi, bj] = N[np.minimum(bi + 1, na - 1), bj]
            facing = (N @ TOCAM) > 0
            Nf = np.where(facing[..., None], N, -N)
            res = shade_fn(P, Nf, facing, A, B)
            col, msk = res if isinstance(res, tuple) else (res, None)
            X, Y = proj(P)
            Hg, Wg = self.gz.shape
            x0 = max(0, int(math.floor(X.min() * SS)) - 4); y0 = max(0, int(math.floor(Y.min() * SS)) - 4)
            x1 = min(Wg, int(math.ceil(X.max() * SS)) + 5); y1 = min(Hg, int(math.ceil(Y.max() * SS)) + 5)
            if x1 <= x0 or y1 <= y0: return
            dz = P @ TOCAM
            if zflat is not None:             # a floating pad: one depth for the whole pad, so pads overlap cleanly
                dz = zflat @ TOCAM + zk * (dz - zflat @ TOCAM)
            ix = (X * SS).astype(np.int64) - x0; iy = (Y * SS).astype(np.int64) - y0
            keep = (ix >= 0) & (iy >= 0) & (ix < x1 - x0) & (iy < y1 - y0)
            if msk is not None: keep = keep & msk
            ix, iy, dz, cc = ix[keep], iy[keep], dz[keep], col[keep]
            o = np.argsort(dz, kind='stable')
            h, w = y1 - y0, x1 - x0
            buf = np.zeros((h, w, 3)); m = np.zeros((h, w), bool); zb = np.full((h, w), -1e9)
            buf[iy[o], ix[o]] = cc[o]; m[iy[o], ix[o]] = True; zb[iy[o], ix[o]] = dz[o]
            m2 = binary_closing(m, np.ones((3, 3), bool)) | m
            hole = m2 & ~m
            if hole.any():                    # pinholes between samples: fill from the neighbours
                bm = gaussian_filter(m.astype(float), 1.0) + 1e-6
                for c_ in range(3):
                    buf[..., c_] = np.where(hole, gaussian_filter(buf[..., c_] * m, 1.0) / bm, buf[..., c_])
                zb = np.where(hole, gaussian_filter(np.where(m, zb, 0), 1.0) / bm, zb)
            gz = self.gz[y0:y1, x0:x1]
            win = m2 & (zb > gz)
            self.gc[y0:y1, x0:x1][win] = buf[win]; gz[win] = zb[win]
            self.gid[y0:y1, x0:x1][win] = len(self.gek)
            self.gek.append((edge_k, edge_w))
        self.items.append((key_pt, draw))

    def paint(self):
        tgt = self.pa.ctx.get_target(); W, H = tgt.get_width(), tgt.get_height()
        self.gz = np.full((H * SS, W * SS), -1e9); self.gc = np.zeros((H * SS, W * SS, 3))
        self.gid = np.full((H * SS, W * SS), -1, np.int32); self.gek = []
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()
        # the kit's thin edge: where a surface meets empty water or a surface behind it, darken its own colour
        ids = self.gid; z = self.gz; filled = ids >= 0
        ek = np.array([e for e, _ in self.gek] + [1.0]); ewid = np.array([w for _, w in self.gek] + [1.0])
        EW = self.pa.u(0.11) * SS                         # edge width inside the shape, in buffer pixels
        rr = int(math.ceil(EW)) + 1
        amt = np.zeros(ids.shape)
        wloc = ewid[ids] * EW
        for dy in range(-rr, rr + 1):
            for dx in range(-rr, rr + 1):
                d = math.hypot(dx, dy)
                if d == 0 or d > rr: continue
                nid = np.roll(np.roll(ids, dy, 0), dx, 1); nz = np.roll(np.roll(z, dy, 0), dx, 1)
                other = (nid != ids) & ((nid < 0) | (nz < z - self.EDGE_DZ))
                amt = np.maximum(amt, other * np.clip((wloc - d) / (0.6 * SS) + 0.5, 0, 1))
        col = self.gc * (1 - amt * (1 - ek[ids]))[..., None]
        a = filled.astype(float)
        col = col * a[..., None]
        col = col.reshape(H, SS, W, SS, 3).mean((1, 3)); a = a.reshape(H, SS, W, SS).mean((1, 3))
        out = np.zeros((H, W, 4), np.uint8)
        out[..., 0] = np.round(np.clip(col[..., 2], 0, 1) * 255); out[..., 1] = np.round(np.clip(col[..., 1], 0, 1) * 255)
        out[..., 2] = np.round(np.clip(col[..., 0], 0, 1) * 255); out[..., 3] = np.round(a * 255)
        stride = cairo.ImageSurface.format_stride_for_width(cairo.FORMAT_ARGB32, W)
        bb = np.zeros((H, stride // 4, 4), np.uint8); bb[:, :W] = out
        surf = cairo.ImageSurface.create_for_data(memoryview(bb).cast('B'), cairo.FORMAT_ARGB32, W, H, stride)
        cx = self.pa.ctx; cx.save(); cx.set_source_surface(surf, 0, 0); cx.paint(); cx.restore()
        cx.save(); cx.set_operator(cairo.OPERATOR_DEST_OVER); self.shadow(); cx.restore()

    def lam(self, N):
        return np.clip(N @ LIGHT, 0, 1)

    def grain(self, P, sc, seed, amp):
        """fine grain at about sc world units, centred on 1"""
        return 1 + amp * (vnoise(P[..., 0] / sc + P[..., 2] / sc * 0.7, P[..., 1] / sc - P[..., 2] / sc * 0.4, seed) - 0.5) * 2

    # ------------------------------------------------------------------ parts
    def stalk_line(self, b, top, bend=None):
        bend = np.array([0.0, 0.0, 0.0]) if bend is None else bend
        d = nv(top - b); n1 = nv(np.cross(d, np.array([0.3, 1.0, 0.0]))); n2 = nv(np.cross(d, n1))
        sd = int(self.r.integers(1000)); pal = self.stem_pal; pk = self.prick
        def geo(A, B):
            t = A[..., None]; th = B[..., None] * 2 * math.pi
            c = b + (top - b) * t + bend * np.sin(math.pi * t)
            rad = 0.0105 - 0.0025 * t
            return c + (np.cos(th) * n1 + np.sin(th) * n2) * rad
        def sh(P, N, F, A, B):
            lam = self.lam(N)
            rim = 1 - np.abs(N @ TOCAM)
            s = 0.18 + 0.72 * lam + 0.12 * rim
            s = s * self.grain(P, 0.006, sd, 0.06)
            col = ramp(pal, s)
            pr = vnoise(A * 70, B * 9, sd + 5)              # prickles: small dark points
            col = mix(col, pk, np.clip((pr - 0.86) / 0.06, 0, 1) * 0.85)
            col = col * (1 + 0.05 * np.sin(B * 2 * math.pi * 7))[..., None]     # faint lengthwise ribs
            return col
        self.splat(geo, sh, (b + top) / 2 + TOCAM * -0.05)

    def pad(self, c, R, rot, old=False):
        """a floating pad on the water: a notched wavy disc, veins from the navel, grain, mottling, water beads"""
        r = self.r; pa = self.pa
        pal = self.old if old else self.pad_pal
        notch = 0.32; ph = r.uniform(0, 6.28); ph2 = r.uniform(0, 6.28); sd = int(r.integers(1000))
        nvein = int(r.integers(17, 22))
        beads = [] if old else [(r.uniform(0.3, 0.75), r.uniform(0.3, 5.9), r.uniform(0.045, 0.075)) for _ in range(r.integers(0, 3))]
        def rimf(th):
            w = 1 + 0.015 * np.sin(th * 5 + ph)
            if old: w = w + 0.035 * np.sin(th * 13 + ph) + 0.02 * np.sin(th * 29 + ph2) - 0.24 * np.clip(np.sin(th * 3 + ph2) - 0.7, 0, 1)
            return w
        def geo(A, B):
            rho = 0.004 + 0.996 * A; th = notch / 2 + (2 * math.pi - notch) * B
            rr = R * rho * rimf(th)
            z = 0.004 + R * (0.028 * (1 - rho ** 2) + 0.03 * np.sin(th * 3 + ph) * rho ** 2 + 0.05 * np.clip(rho - 0.9, 0, 1))
            return np.stack([c[0] + np.cos(th + rot) * rr, c[1] + np.sin(th + rot) * rr, c[2] + z], -1)
        def sh(P, N, F, A, B):
            rho = 0.004 + 0.996 * A; th = notch / 2 + (2 * math.pi - notch) * B
            lam = self.lam(N)
            s = 0.52 + 1.25 * (lam - 0.55)
            s = s + 0.09 * (fbm(P[..., 0] / (R * 0.35), P[..., 1] / (R * 0.35), sd) - 0.5)       # broad mottling
            s = s * self.grain(P, R * 0.03, sd + 3, 0.05)                                       # fine grain
            col = ramp(pal, s)
            ang = th * nvein / (2 * math.pi)                                                    # radial veins
            dv = np.abs(ang - np.round(ang)) * (2 * math.pi / nvein) * rho * R
            wv = R * (0.010 + 0.008 * (1 - rho))
            vein = np.exp(-(dv / wv) ** 2) * np.clip((rho - 0.07) / 0.08, 0, 1)
            fk = np.clip((rho - 0.5) / 0.15, 0, 1)                                              # forks past the middle
            ang2 = ang + 0.5
            dv2 = np.abs(ang2 - np.round(ang2)) * (2 * math.pi / nvein) * rho * R
            v = np.clip(vein + np.exp(-(dv2 / (wv * 0.75)) ** 2) * fk * 0.7, 0, 1)
            net = np.abs(np.sin(ang * math.pi * 3 + rho * 40)) * np.abs(np.sin(rho * R * 160))  # the fine net
            col = col * (1 - 0.05 * (net < 0.12))[..., None]
            col = mix(col, pal[5], v * (0.42 if not old else 0.3))
            col = mix(col, pal[1], np.exp(-(dv / (wv * 2.6)) ** 2) * 0.12 * (1 - v))
            col = mix(col, pal[1], np.exp(-((rho - 0.075) / 0.02) ** 2) * 0.5)                  # navel ring
            col = mix(col, pal[5], np.clip((0.06 - rho) / 0.02, 0, 1))
            lip = np.clip((rho - 0.93) / 0.07, 0, 1)                                            # rim curls up
            near = np.sin(th + rot) > 0
            col = mix(col, np.where(near[..., None], pal[5], pal[0]), lip * 0.45)
            if old:
                bl = fbm(P[..., 0] / (R * 0.22), P[..., 1] / (R * 0.22), sd + 9)
                col = mix(col, self.brown, np.clip((bl - 0.55) / 0.12, 0, 1) * 0.75)
                col = mix(col, self.brown * 0.7, np.clip((bl - 0.68) / 0.05, 0, 1) * 0.6)
                col = mix(col, self.brown, np.clip((rho - 0.86) / 0.14, 0, 1) * 0.55)
            for (br, bt, bs) in beads:            # beads of water: dark rim, clear body, a sharp highlight
                bx = c[0] + math.cos(bt + rot) * br * R; by = c[1] + math.sin(bt + rot) * br * R
                dd = np.hypot(P[..., 0] - bx, P[..., 1] - by) / (bs * R)
                inb = dd < 1
                col = mix(col, pal[1], np.clip((dd - 1) / 0.1, 0, 1) * np.clip((1.4 - dd) / 0.3, 0, 1) * 0.4 * ((P[..., 1] - by) > 0))
                col = mix(col, pal[0], np.clip((dd - 0.72) / 0.28, 0, 1) * inb * 0.6)
                col = mix(col, pal[5], np.clip(1 - dd, 0, 1) ** 0.5 * 0.35 * inb)
                hd = np.hypot(P[..., 0] - bx + bs * R * 0.3, P[..., 1] - by + bs * R * 0.4) / (bs * R)
                col = mix(col, pal[5] * 1.35, np.clip((0.3 - hd) / 0.1, 0, 1))
            return np.clip(col, 0, 1)
        wsh = self.water_sh
        def shadow():
            P = pa.P
            poly = [P(c + np.array([math.cos(t + rot), math.sin(t + rot), 0]) * R) for t in np.linspace(notch / 2, 2 * math.pi - notch / 2, 40)] + [P(c)]
            sh_ = [(x + pa.u(0.6), y + pa.u(0.9)) for x, y in poly]
            pa.path(sh_); pa.ctx.set_source_rgba(*wsh, 0.28); pa.ctx.fill()
        self.items.append((c + TOCAM * -0.31, shadow))
        self.splat(geo, sh, c + TOCAM * -0.3, zflat=c)

    def cup(self, b, top, R, f, bead=False):
        """a raised leaf: a shallow glaucous cup tilted to f, veins, the pale underside where the wavy rim turns over"""
        r = self.r
        u, v = basis(f)
        self.stalk_line(b, top)
        ph = r.uniform(0, 6.28); ph2 = r.uniform(0, 6.28); dep = R * 0.3; sd = int(r.integers(1000))
        nvein = int(r.integers(19, 24))
        pal = self.cup_pal; und = self.und
        def geo(A, B):
            rho = 0.004 + 0.996 * A; th = B * 2 * math.pi
            w = 1 + 0.05 * np.sin(th * 6 + ph) + 0.03 * np.sin(th * 11 + ph2)
            lift = 0.1 * R * np.sin(th * 6 + ph) + 0.05 * R * np.sin(th * 3 + ph2)
            rad = np.cos(th)[..., None] * u + np.sin(th)[..., None] * v
            # a bowl whose outer rim turns back down a little, so its underside shows
            prof = dep * rho ** 1.7 + lift * rho ** 4 - R * 0.35 * np.clip(rho - 0.84, 0, 1) ** 1.3
            return top + rad * (R * rho * w)[..., None] + f * prof[..., None]
        def sh(P, N, F, A, B):
            rho = 0.004 + 0.996 * A; th = B * 2 * math.pi
            lam = self.lam(N)
            view = np.abs(N @ TOCAM)
            s = 0.08 + 0.95 * lam
            s = s + 0.08 * (fbm(P[..., 0] / (R * 0.4), (P[..., 1] + P[..., 2]) / (R * 0.4), sd) - 0.5)
            s = s * self.grain(P, R * 0.03, sd + 1, 0.045)
            ctop = ramp(pal, s)
            cund = ramp(und, 0.1 + 0.95 * lam)
            ang = th * nvein / (2 * math.pi)
            dv = np.abs(ang - np.round(ang)) * (2 * math.pi / nvein) * rho * R
            wv = R * (0.010 + 0.009 * (1 - rho))
            vein = np.exp(-(dv / wv) ** 2) * np.clip((rho - 0.08) / 0.08, 0, 1)
            fk = np.clip((rho - 0.55) / 0.15, 0, 1)
            ang2 = ang + 0.5; dv2 = np.abs(ang2 - np.round(ang2)) * (2 * math.pi / nvein) * rho * R
            vein = np.clip(vein + np.exp(-(dv2 / (wv * 0.75)) ** 2) * fk * 0.7, 0, 1)
            ctop = mix(ctop, pal[5], vein * 0.38)
            ctop = mix(ctop, pal[0], np.exp(-(dv / (wv * 2.6)) ** 2) * 0.14 * (1 - vein))
            ctop = mix(ctop, self.bloom, (1 - view) ** 2 * 0.45 + 0.06)       # waxy bloom where it turns from us
            ctop = mix(ctop, und[3], np.clip((0.07 - rho) / 0.02, 0, 1))      # navel
            ctop = mix(ctop, pal[0], np.exp(-((rho - 0.085) / 0.02) ** 2) * 0.45)
            cund = mix(cund, und[3], vein * 0.6)                               # raised pale ribs underneath
            cund = mix(cund, und[0], np.exp(-(dv / (wv * 2.2)) ** 2) * 0.25 * (1 - vein))
            col = np.where(F[..., None], ctop, cund)
            if bead:          # a bead of water rolling near the bottom of the cup
                q = top + f * dep * 0.06 + u * R * 0.16 + v * R * 0.1
                dd = np.linalg.norm(P - q, axis=-1) / (R * 0.075)
                inb = (dd < 1) & F
                col = mix(col, pal[0], np.clip((dd - 0.7) / 0.3, 0, 1) * inb * 0.6)
                col = mix(col, pal[5], np.clip(1 - dd, 0, 1) ** 0.6 * 0.5 * inb)
                hq = q - u * R * 0.025 + v * R * 0.03
                hd = np.linalg.norm(P - hq, axis=-1) / (R * 0.075)
                col = mix(col, np.maximum(pal[5], und[3]) * 1.2, np.clip((0.35 - hd) / 0.12, 0, 1) * inb)
            return np.clip(col, 0, 1)
        self.splat(geo, sh, top + f * dep + TOCAM * 0.02)

    def _petal(self, p, f, e, s, L, W, cup, key, outer):
        """one broad pointed petal from p along e (side s), cupped up along f, inside and outside"""
        pc = self.pet
        prof_t = np.array([0, 0.15, 0.4, 0.66, 0.84, 0.95, 1.0]); prof_w = np.array([0.28, 0.72, 1.0, 0.95, 0.66, 0.3, 0.0])
        nin = nv(f - e * cup * 1.6)               # the inner face looks this way
        sd = int(self.r.integers(1000)); tw = self.r.normal(0, 0.06)
        nveins = int(self.r.integers(9, 13))
        def geo(A, B):
            t = A; w = B * 2 - 1
            pw = np.interp(t, prof_t, prof_w)
            x = (e * (L * t)[..., None] + s * (W * 0.5 * w * pw)[..., None] + f * (L * cup * t * t)[..., None]
                 + nin * (L * (0.16 * w * w * pw + 0.07 * t ** 3 + tw * w * t))[..., None])
            return p + x
        def sh(P, N, F, A, B):
            t = A; w = B * 2 - 1
            lam = self.lam(N)
            g = np.clip(t ** 1.35 + 0.22 * np.abs(w) ** 3 * t, 0, 1)
            base = ramp([pc['heart'], pc['base'], pc['mid'], pc['tip']], np.clip(0.12 + g * 0.88, 0, 1))
            base = mix(base, pc['heart'], np.clip((0.12 - t) / 0.1, 0, 1) * 0.8)
            vv = np.abs(np.cos(w * math.pi * nveins * 0.5 * (1 - 0.15 * t)))     # veins fan from the base
            vein = np.clip((vv - 0.82) / 0.18, 0, 1) ** 1.5 * np.clip((t - 0.04) / 0.1, 0, 1) * (1 - t ** 3)
            vk = np.where(F, 0.22, 0.38) * (1 - 0.4 * g)
            base = mix(base, pc['vein'], vein * vk)
            base = mix(base, pc['tip'], (~F) * 0.18 * (0.4 + 0.6 * g))          # the outside is a little deeper
            sv = np.clip(0.38 + 0.75 * lam + 0.14 * (~F), 0, 1.08) * self.grain(P, L * 0.02, sd, 0.025)
            sv = sv * (1 - np.clip((0.22 - t) / 0.22, 0, 1) * (0.2 if outer else 0.35))
            col = mix(pc['deep'], base, np.clip(sv, 0, 1))                       # a tinted shadow, never grey
            col = col + np.clip(sv - 1, 0, 0.1)[..., None] * 0.6
            spec = np.clip(N @ HALF, 0, 1) ** 24 * 0.25 * F
            return np.clip(col + spec[..., None], 0, 1)
        self.splat(geo, sh, p + e * L * 0.55 + f * L * cup * 0.3 + TOCAM * key, edge_k=0.84)

    def lotus_flower(self, p, f, R, k):
        r = self.r
        u, v = basis(f)
        rings = [(6, 1.0, 1.25, 0.9, 0.0), (6, 0.84, 1.1, 1.3, 0.03), (5, 0.56, 0.95, 1.6, 0.06)]
        for ri, (n, Ls, Ws, cup, key) in enumerate(rings):
            for j in range(n):
                a = (j + 0.5 * ri) * 2 * math.pi / n + k + r.normal(0, 0.08)
                e = math.cos(a) * u + math.sin(a) * v; s = -math.sin(a) * u + math.cos(a) * v
                e2 = nv(e * (1 - 0.2 * ri) + f * (0.25 + 0.27 * ri))
                base = p + e * R * (0.2 - 0.03 * ri) - f * R * (0.04 - 0.02 * ri)
                self._petal(base, f, e2, s, R * Ls, R * 0.62 * Ws, cup * 0.35, 0.06 + key + 0.002 * j, ri == 0)
        # the heart: a ring of stamens, then the flat seed pod
        gold = self.gold; podc = self.podc; sd = int(r.integers(1000))
        nst = 54; lens = r.uniform(0.7, 1.0, nst)
        def geo_st(A, B):
            th = B * 2 * math.pi
            rad = np.cos(th)[..., None] * u + np.sin(th)[..., None] * v
            return p + f * (R * (0.16 + 0.16 * A))[..., None] + rad * (R * (0.13 + 0.16 * A))[..., None]
        def sh_st(P, N, F, A, B):
            fi = B * nst; i = np.floor(fi).astype(int) % nst; fr = fi - np.floor(fi)
            Lc = lens[i]
            on = (np.abs(fr - 0.5) < 0.36) & (A < Lc)
            lam = self.lam(N)
            across = 1 - ((fr - 0.5) / 0.36) ** 2         # a round filament: lit along its middle
            sv = 0.25 + 0.45 * lam + 0.35 * across
            col = ramp(gold[:4], sv)
            col = mix(col, ramp(gold[1:], sv), np.clip((A - (Lc - 0.32)) / 0.05, 0, 1))     # anther
            col = mix(col, gold[4], np.clip((A - (Lc - 0.07)) / 0.03, 0, 1))                 # white tip
            col = mix(col, gold[0], np.clip((0.12 - A) / 0.12, 0, 1) * 0.6)                  # deep at the base
            return col, on
        self.splat(geo_st, sh_st, p + f * 0.1 + TOCAM * 0.19, edge_k=0.9, edge_w=0.4)
        holes = [(0.0, 0.0)] + [(0.55, i * 2 * math.pi / 7 + 0.3) for i in range(7)]
        def geo_pod(A, B):
            rho = 0.004 + 0.996 * A; th = B * 2 * math.pi
            rad = np.cos(th)[..., None] * u + np.sin(th)[..., None] * v
            z = R * (0.31 + 0.012 * (1 - rho ** 2) - 0.07 * np.clip(rho - 0.82, 0, 1) / 0.18)
            return p + f * z[..., None] + rad * (R * 0.16 * rho)[..., None]
        def sh_pod(P, N, F, A, B):
            rho = 0.004 + 0.996 * A; th = B * 2 * math.pi
            lam = self.lam(N)
            sv = (0.3 + 0.7 * lam) * self.grain(P, R * 0.012, sd, 0.05) + 0.12 * np.clip(0.5 - rho, 0, 1)
            col = ramp(podc, sv)
            x = rho * np.cos(th); y = rho * np.sin(th)
            for hr, ht in holes:
                hx, hy = hr * math.cos(ht), hr * math.sin(ht)
                dd = np.hypot(x - hx, y - hy) / 0.17
                col = mix(col, podc[0], np.clip((1 - dd) / 0.15, 0, 1) * 0.8)                       # the hole
                lit = np.clip(((x - hx) * 0.6 - (y - hy) * 0.8) / 0.17, 0, 1)
                col = mix(col, podc[4], np.clip(1 - np.abs(dd - 1.08) / 0.1, 0, 1) * 0.7 * lit)       # its lit lip
                col = mix(col, self.stig, np.clip((0.42 - dd) / 0.12, 0, 1))                        # yellow stigma
            return col
        self.splat(geo_pod, sh_pod, p + f * 0.12 + TOCAM * 0.2, edge_k=0.75)
        for sd_ in (-1, 1):
            self.sepal(p - f * 0.01, nv(-f * 0.4 + u * sd_), R * 0.35, R * 0.18)

    def sepal(self, b, d, L, W):
        """a small green sepal hanging under the flower"""
        side = nv(np.cross(UP, d)) if np.linalg.norm(np.cross(UP, d)) > 1e-3 else np.array([1.0, 0, 0])
        pal = [A_(C(h)) for h in ('#2a4e20', '#3c6a2c', '#4e7e36', '#629440', '#7aa850')]
        sd = int(self.r.integers(1000))
        def geo(A, B):
            t = A; w = B * 2 - 1
            pw = np.sin(np.pi * np.clip(t * 0.85 + 0.08, 0, 1)) ** 0.8
            return b + d * (L * t)[..., None] + side * (W * 0.5 * w * pw)[..., None] + UP * (-L * 0.25 * t * t + W * 0.15 * w * w)[..., None]
        def sh(P, N, F, A, B):
            lam = self.lam(N)
            col = ramp(pal, (0.1 + 0.85 * lam) * self.grain(P, L * 0.08, sd, 0.05))
            return mix(col, pal[4], np.exp(-((B * 2 - 1) / 0.08) ** 2) * 0.35 * (1 - A))
        self.splat(geo, sh, b + d * L * 0.5 + TOCAM * -0.01)

    def bud(self, p, f, R):
        """a closed bud: a pointed egg, pale green at the base, coloured to the tip, the seams of three outer petals"""
        pc = self.pet; u, v = basis(f); sd = int(self.r.integers(1000)); ph = self.r.uniform(0, 6.28)
        def geo(A, B):
            h = A; th = B * 2 * math.pi
            w = np.sin(np.pi * np.clip(h, 0, 1)) ** 0.75 * (1 - 0.38 * h) * (1 + 0.03 * np.sin(th * 3 + ph))
            rad = np.cos(th)[..., None] * u + np.sin(th)[..., None] * v
            return p + f * (R * 2.2 * h)[..., None] + rad * (R * w)[..., None]
        def sh(P, N, F, A, B):
            h = A; th = B * 2 * math.pi
            lam = self.lam(N)
            g = np.clip(h ** 1.1, 0, 1)
            base = ramp([pc['green'], pc['base'], pc['mid'], pc['tip']], np.clip(g * 1.05, 0, 1))
            sa = (th - ph) * 3 / (2 * math.pi); fr = sa - np.floor(sa)
            on = np.clip((h - 0.15) / 0.2, 0, 1)
            seam = np.exp(-(fr / 0.02) ** 2) * on
            lip = np.exp(-((fr - 0.04) / 0.03) ** 2) * on
            vein = np.clip((np.abs(np.cos(th * 13)) - 0.85) / 0.15, 0, 1) * (1 - h) * 0.6
            base = mix(base, pc['vein'], vein * 0.3)
            sv = np.clip(0.35 + 0.78 * lam, 0, 1.05) * self.grain(P, R * 0.05, sd, 0.025)
            col = mix(pc['deep'], base, np.clip(sv, 0, 1))
            col = mix(col, pc['deep'], seam * 0.55)
            col = mix(col, np.maximum(pc['mid'], pc['base']), lip * 0.35)
            spec = np.clip(N @ HALF, 0, 1) ** 20 * 0.2
            return np.clip(col + spec[..., None], 0, 1)
        self.splat(geo, sh, p + f * R + TOCAM * 0.08, closed=False, edge_k=0.84)

    def pod(self, p, f, R, ripe=False):
        """a seed pod (gương sen): an upturned cone, the flat face pocked with seed holes"""
        u, v = basis(f); sd = int(self.r.integers(1000))
        cols = [A_(C(h)) for h in (('#3a2a12', '#5a4a24', '#7e6a34', '#a08a4a', '#c0aa6a') if ripe else
                                   ('#2a4416', '#4e7a2a', '#6e9a3a', '#9cbe56', '#c0d880'))]
        def geo_cone(A, B):
            h = A; th = B * 2 * math.pi
            rad = np.cos(th)[..., None] * u + np.sin(th)[..., None] * v
            w = R * (0.12 + 0.88 * h ** 0.8)
            return p + f * (R * (-0.3 + 1.1 * h))[..., None] + rad * w[..., None]
        def sh_cone(P, N, F, A, B):
            lam = self.lam(N)
            col = ramp(cols, (0.15 + 0.8 * lam) * self.grain(P, R * 0.05, sd, 0.06))
            rib = np.abs(np.cos(B * 2 * math.pi * 9)); col = col * (1 - 0.08 * (rib > 0.9))[..., None]
            return col
        self.splat(geo_cone, sh_cone, p + TOCAM * 0.09)
        holes = [(0.0, 0.0)] + [(0.6, i * 2 * math.pi / 8) for i in range(8)]
        def geo_face(A, B):
            rho = 0.004 + 0.996 * A; th = B * 2 * math.pi
            rad = np.cos(th)[..., None] * u + np.sin(th)[..., None] * v
            return p + f * (R * (0.81 + 0.02 * (1 - rho ** 2)))[..., None] + rad * (R * rho)[..., None]
        def sh_face(P, N, F, A, B):
            rho = 0.004 + 0.996 * A; th = B * 2 * math.pi
            lam = self.lam(N)
            col = ramp(cols, (0.4 + 0.6 * lam) * self.grain(P, R * 0.04, sd + 2, 0.06))
            x = rho * np.cos(th); y = rho * np.sin(th)
            for hr, ht in holes:
                dd = np.hypot(x - hr * math.cos(ht), y - hr * math.sin(ht)) / 0.15
                col = mix(col, cols[0], np.clip((1 - dd) / 0.15, 0, 1) * 0.9)
                col = mix(col, cols[4], np.clip(1 - np.abs(dd - 1.1) / 0.12, 0, 1) * 0.5)
                if not ripe: col = mix(col, self.stig * 0.85, np.clip((0.35 - dd) / 0.12, 0, 1) * 0.8)
            return col
        self.splat(geo_face, sh_face, p + TOCAM * 0.1)

    def shadow(self):
        ground_shadow(self.pa, 0.0, 0.05, 0.4, 0.32, 0.07)


class Frame:
    def __init__(self, pa, kind, seed): self.m = Sen(seed, pa)
    def paint(self): self.m.paint()


FRAMES = [dict(key='lotus%d' % s, kind='lotus', seed=s) for s in range(4)]
BB = (-48, -72, 48, 26)
co.KU = KU

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'atlas':
        co.atlas(Frame, FRAMES, BB, sys.argv[2], 'sen.webp', sys.argv[3], cols=4)
    else:
        from PIL import Image
        night = len(sys.argv) > 1 and sys.argv[1] == 'n'
        only = [int(x) for x in sys.argv[3].split(',')] if len(sys.argv) > 3 else range(4)
        ims = [co.to_image(co.render(Frame, FRAMES[i], BB, night)) for i in only]
        w, h = ims[0].size
        o = Image.new('RGBA', (w * len(ims), h), (40, 70, 80, 255) if night else (70, 120, 140, 255))
        for i, im in enumerate(ims): o.alpha_composite(im, (i * w, 0))
        o.save(sys.argv[2] if len(sys.argv) > 2 else '/tmp/claude-0/g/sen.png'); print(o.size)
