# Banana clumps (bụi chuối) for Nông Trại Nhỏ, drawn as small 3D models and painted in flat game tones.
# Each plant: a tall pseudostem of wrapped sheaths, long paddle leaves that rise, arch and droop, torn into strips
# along their veins, a dead leaf hanging down the trunk, a bunch (buồng) with hands of fingers curving upward and
# the purple heart (bắp chuối) at the end, and suckers (chuối con) at the foot.
# Camera = the game's 2:1 iso view (30 deg down). Output is in game units: 1 unit = 1 px at zoom 1.
import math
import numpy as np, cairo

E = math.radians(30)
CE, SE = math.cos(E), math.sin(E)
TOCAM = np.array([0.0, CE, SE])


def nv(v):
    v = np.asarray(v, float); n = np.linalg.norm(v)
    return v / n if n > 0 else v


LIGHT = nv([-0.6, 0.45, 0.72])          # sun from the upper left, like the game's lit sides
SLIGHT = nv([-0.75, -0.66])             # the same light in screen space

# day -> night colour transform, least-squares fit over the game's own v(day, night) colour pairs
_NG = np.array([[0.6838, 0.0272, 0.0097], [0.0358, 0.71, 0.0707], [-0.0163, -0.065, 0.5548], [-0.0528, -0.0317, -0.0055]])
_NG_GREEN = np.array([[0.6475, 0.0297, -0.0727], [-0.002, 0.8864, 0.2652], [-0.0511, -0.1777, 0.3976], [-0.0025, -0.0939, -0.0255]])
NIGHT = False
# dark edge outlines round leaves, stems, fruit (all three kits read this). Off since 2026-10-31: Link wants none,
# the game's own trees are flat colour without outlines. Inner details (veins, midribs, scars, nodes) stay.
EDGE = False
# soft edge (v619, Link: "viền mỏng nhỏ nhạt gần màu lá"): a thin line round each shape in its own fill colour,
# only a little darker, so shapes read apart without a drawn outline. Width in game units, colour = fill * SOFT_K.
SOFT = True
SOFT_W = 0.26
SOFT_K = 0.8


def soft(col, k=None):
    return tuple(c * (SOFT_K if k is None else k) for c in col)


def C(h, k=1.0):
    """hex colour -> rgb tuple, darkened/lightened by k, through the night transform when painting the night set"""
    c = np.array([int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]) * k
    c = np.clip(c, 0, 1)
    if NIGHT:
        g = c[1] > c[0] and c[1] > c[2]
        M = _NG_GREEN if g else _NG
        c = np.clip(np.append(c, 1.0) @ M, 0, 1)
    return tuple(float(v) for v in c)


def mixc(a, b, t): return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def depth(p): return p[1] * CE + p[2] * SE


class Painter:
    """wraps a cairo context and the projection: ground (x right, y toward viewer), z up, metres -> pixels"""
    def __init__(self, ctx, ku, px, ox, oy):
        self.ctx, self.ku, self.px, self.ox, self.oy = ctx, ku, px, ox, oy
        self.k = ku * px                      # pixels per metre

    def P(self, p):
        return (self.ox + p[0] * self.k, self.oy + (0.5 * p[1] - 0.866 * p[2]) * self.k)

    def u(self, units):                       # game units -> pixels
        return units * self.px

    def path(self, pts, close=True):
        c = self.ctx; c.new_path(); c.move_to(*pts[0])
        for q in pts[1:]: c.line_to(*q)
        if close: c.close_path()

    def fill(self, pts, col, seam=True, grow=0.0):
        """grow: also stroke the edge in the fill colour this wide, so a shape keeps the size it had with an outline"""
        self.path(pts); self.ctx.set_source_rgb(*col)
        if seam or grow:
            self.ctx.fill_preserve(); self.ctx.set_line_width(max(0.7, grow)); self.ctx.set_line_join(cairo.LINE_JOIN_ROUND); self.ctx.stroke()
        else: self.ctx.fill()

    def line(self, pts, col, w, a=1.0, cap=cairo.LINE_CAP_ROUND):
        c = self.ctx; self.path(pts, False)
        c.set_source_rgba(*col, a); c.set_line_width(w); c.set_line_cap(cap); c.set_line_join(cairo.LINE_JOIN_ROUND); c.stroke()

    def soft_edge(self, pts, col, close=True, w=None, k=None):
        """the thin edge in a shade of the shape's own colour (nothing when SOFT is off)"""
        if not SOFT or EDGE: return
        c = self.ctx; self.path(pts, close)
        c.set_source_rgb(*soft(col, k)); c.set_line_width(self.u(SOFT_W if w is None else w))
        c.set_line_cap(cairo.LINE_CAP_ROUND); c.set_line_join(cairo.LINE_JOIN_ROUND); c.stroke()

    def taper(self, pts, w0, w1, col, outline=None, ow=0.0):
        """a stroke whose width runs from w0 to w1 (pixels), drawn as a filled ribbon"""
        pts = np.array(pts, float); n = len(pts)
        L, R = [], []
        for i in range(n):
            a = pts[max(0, i - 1)]; b = pts[min(n - 1, i + 1)]
            d = nv(b - a); nrm = np.array([-d[1], d[0]])
            w = (w0 + (w1 - w0) * i / (n - 1)) / 2
            L.append(pts[i] + nrm * w); R.append(pts[i] - nrm * w)
        poly = L + R[::-1]
        if outline is not None and EDGE:
            self.path(poly); self.ctx.set_source_rgb(*outline); self.ctx.set_line_width(ow); self.ctx.set_line_join(cairo.LINE_JOIN_ROUND); self.ctx.stroke_preserve()
            self.ctx.set_source_rgb(*col); self.ctx.fill()
        else:
            self.fill(poly, col)
            if outline is not None:          # long sides only: a stalk drawn in pieces shows no joints
                self.soft_edge(L, col, close=False); self.soft_edge(R, col, close=False)


# ------------------------------------------------------------------ palettes
def leaf_pal(age):
    # age 0 young (bright, yellow-green) .. 1 mature .. 2 yellowing .. 3 dead (brown)
    if age == 3:
        return dict(top=[C('#bfa26c'), C('#a08451'), C('#80663c')], und=[C('#b39a68'), C('#927a4e')],
                    rib=C('#d9c899'), out=C('#54401f'), vein=C('#6b5530'))
    if age == 2:
        return dict(top=[C('#a9cb55'), C('#8cb143'), C('#6f9535')], und=[C('#bcd27a'), C('#98b25c')],
                    rib=C('#dfeaa4'), out=C('#3f5a1c'), vein=C('#567226'), edge=C('#a98a44'))
    if age == 0:
        return dict(top=[C('#9ad957'), C('#7cc544'), C('#5ea836')], und=[C('#a3d36a'), C('#7fb550')],
                    rib=C('#def3a8'), out=C('#2f6b22'), vein=C('#3f8a2c'))
    return dict(top=[C('#80cc46'), C('#5fb236'), C('#46952f')], und=[C('#8dc75a'), C('#6aa544')],
                rib=C('#d3ec9c'), out=C('#2a6220'), vein=C('#357d27'))


# ------------------------------------------------------------------ leaf
class Leaf:
    def __init__(self, rng, base, az, e0, droop, L, W, pet, age, tears=0, twist=0.0, fold=0.35, curl=0.35,
                 bend=0.0, p=1.5, elev=None, torn_droop=0.5, gap=0.06, shade=1.0, kink=None):
        self.rng = rng; self.base = np.array(base, float); self.age = age
        self.L, self.W, self.pet = L, W, pet
        self.twist, self.fold, self.curl = twist, fold, curl
        self.pal = leaf_pal(age); self.shade = shade
        n = 48; tot = L + pet
        self.sb = pet / tot
        pts, T, B, N = [], [], [], []
        q = self.base.copy()
        for k in range(n + 1):
            s = k / n
            e = elev(s) if elev else e0 - droop * s ** p
            a = az + bend * s
            A = np.array([math.cos(a), math.sin(a), 0.0]); Bh = np.array([-math.sin(a), math.cos(a), 0.0])
            d = A * math.cos(e) + np.array([0, 0, 1.0]) * math.sin(e)
            nn = nv(np.cross(d, Bh))
            pts.append(q.copy()); T.append(d); B.append(Bh); N.append(nn)
            q = q + d * tot / n
        self.pts, self.T, self.B, self.N = map(np.array, (pts, T, B, N))
        self.n = n
        # tears per half: (position along the blade, gap at the margin); strips droop on their own
        self.tears = {}
        self.sdroop = {}
        for side in (-1, 1):
            k = max(0, int(round(tears + rng.normal(0, 0.8)))) if tears else 0
            ts = sorted(rng.uniform(0.14, 0.93, k))
            # keep strips from getting too thin
            keep = []
            for t in ts:
                if not keep or t - keep[-1] > 0.05: keep.append(t)
            self.tears[side] = [(t, gap * rng.uniform(0.5, 1.4)) for t in keep]
            self.sdroop[side] = [rng.uniform(0, torn_droop) * (1 if keep else 0) for _ in range(len(keep) + 1)]
        self.vf = 0.32 * W / L          # how far a vein runs toward the tip, in blade fraction
        self.side0 = {-1: rng.uniform(0.0, 0.05), 1: 0.0}   # the blade base is lopsided

    def at(self, s):
        f = min(self.n - 1e-6, max(0.0, s * self.n)); i = int(f); t = f - i
        lerp = lambda a: a[i] * (1 - t) + a[i + 1] * t
        return lerp(self.pts), nv(lerp(self.T)), nv(lerp(self.B)), nv(lerp(self.N))

    def wprof(self, t, side):
        t0 = self.side0[side]
        if t < t0: return 0.0
        tt = (t - t0) / (1 - t0)
        w = 0.22 + 0.78 * math.sin(min(1.0, tt / 0.12) * math.pi / 2)
        if tt > 0.8: w *= math.sqrt(max(0.0, 1 - ((tt - 0.8) / 0.2) ** 2))
        return w

    def pt(self, side, v, u, extra):
        ramp = min(1.0, v / 0.08) * min(1.0, (1 - v) / 0.1)
        t = min(1.0, v + self.vf * u ** 1.4 * ramp)
        s = self.sb + t * (1 - self.sb)
        m, T, B, N = self.at(s)
        w = self.W * self.wprof(t, side)
        # integrate the curled cross-section out to u
        acc = np.zeros(3); steps = 4
        for j in range(steps):
            tau = (j + 0.5) / steps * u
            fa = self.fold + self.curl * tau ** 2 + extra * tau - side * self.twist
            acc += (B * side * math.cos(fa) - N * math.sin(fa)) * (u / steps)
        return m + acc * w, m, N

    def items(self, pa, out):
        pal = self.pal
        # petiole
        sp = [self.at(s)[0] for s in np.linspace(0, self.sb + 0.02, 8)]
        mid = sp[len(sp) // 2]
        def petiole(sp=sp):
            pp = [pa.P(q) for q in sp]
            pa.taper(pp, pa.u(1.35 if self.age < 3 else 0.9), pa.u(0.75 if self.age < 3 else 0.55),
                     pal['rib'] if self.age == 3 else mixc(pal['top'][1], pal['rib'], 0.35), outline=pal['out'], ow=pa.u(0.5))
        out.append((mid, petiole))
        for side in (-1, 1):
            tears = self.tears[side]
            cutsv = [0.0] + [t for t, g in tears] + [1.0]
            gaps = [0.0] + [g for t, g in tears] + [0.0]
            for si in range(len(cutsv) - 1):
                va, vb = cutsv[si], cutsv[si + 1]
                ga, gb = gaps[si] / 2, -gaps[si + 1] / 2
                extra = self.sdroop[side][si]
                nseg = max(1, int(math.ceil((vb - va) / 0.055)))
                cuts = [va + (vb - va) * j / nseg for j in range(nseg + 1)]
                for j in range(nseg):
                    first, last = j == 0, j == nseg - 1
                    self._poly_item(pa, out, side, cuts[j], cuts[j + 1], ga if first else 0.0, gb if last else 0.0,
                                    extra, first, last)

    def _poly_item(self, pa, out, side, v0, v1, g0, g1, extra, edge0, edge1):
        pal = self.pal
        us = np.linspace(0, 1, 5)
        def cross(v, g):
            return [self.pt(side, max(0.0, min(1.0, v + g * u ** 1.2)), u, extra)[0] for u in us]
        c0 = cross(v0, g0); c1 = cross(v1, g1)
        mvs = np.linspace(v0, v1, 3)
        marg = [self.pt(side, max(0.0, min(1.0, v + (g0 + (g1 - g0) * (v - v0) / max(1e-9, v1 - v0)))), 1.0, extra)[0] for v in mvs]
        rib = [self.pt(side, v, 0.0, 0)[0] for v in mvs]
        poly3 = c0 + marg[1:-1] + c1[::-1] + rib[::-1][1:-1]
        cen = np.mean(poly3, axis=0)
        # facing and light from the quad
        a, b, c = rib[0], rib[-1], marg[1]
        nrm = nv(np.cross(b - a, c - a))
        _, _, _, Nup = self.at(self.sb + (v0 + v1) / 2 * (1 - self.sb))
        if nrm @ Nup < 0: nrm = -nrm
        top = nrm @ TOCAM > 0
        vis = nrm if top else -nrm
        lam = float(vis @ LIGHT)
        if top:
            col = pal['top'][0] if lam > 0.58 else pal['top'][1] if lam > 0.2 else pal['top'][2]
        else:
            col = pal['und'][0] if lam > 0.3 else pal['und'][1]
        col = tuple(min(1, x * self.shade) for x in col)
        # veins at fixed spacing along the blade
        vs = [v for v in np.arange(0.03, 1.0, 0.04) if v0 + 0.01 < v < v1 - 0.01]
        veins = [[self.pt(side, v, u, extra)[0] for u in np.linspace(0.06, 0.95, 5)] for v in vs]
        age = self.age
        def draw():
            P = pa.P
            poly = [P(q) for q in poly3]
            pa.fill(poly, col)
            if veins:
                pa.ctx.save(); pa.path(poly); pa.ctx.clip()
                for vn in veins: pa.line([P(q) for q in vn], mixc(col, pal['vein'], 0.55), pa.u(0.2), 0.55)
                pa.ctx.restore()
            if EDGE:
                if age == 2 and 'edge' in pal:
                    pa.line([P(q) for q in marg], pal['edge'], pa.u(0.75))
                ow = pa.u(0.48)
                pa.line([P(q) for q in marg], pal['out'], ow)
                tc = mixc(pal['out'], col, 0.25)
                if edge0: pa.line([P(q) for q in c0], tc if v0 > 0 else pal['out'], pa.u(0.34) if v0 > 0 else ow)
                if edge1: pa.line([P(q) for q in c1], tc if v1 < 1 else pal['out'], pa.u(0.34) if v1 < 1 else ow)
            else:
                pa.soft_edge([P(q) for q in marg], col, close=False)
                if edge0: pa.soft_edge([P(q) for q in c0], col, close=False)
                if edge1: pa.soft_edge([P(q) for q in c1], col, close=False)
            # midrib, a pale band that thins toward the tip
            wv = pa.u(0.5 * (1 - (v0 + v1) / 2) + 0.2)
            # v620 (critique 8, "a chalk line"): the midrib only a few shades lighter than its leaf
            pa.line([P(q) for q in rib], pal['rib'] if EDGE else mixc(col, pal['rib'], 0.5), wv)
        out.append((cen, draw))


# ------------------------------------------------------------------ pseudostem
def stem_items(pa, out, rng, base, H, r0, young=False, dry_sheaths=3):
    bx, by = base
    lit, mid, dk = (C('#b2cc68'), C('#8eac4f'), C('#6a883a')) if not young else (C('#c3e07e'), C('#9fc35c'), C('#7b9f44'))
    out_c = C('#3e5a22')
    zs = np.linspace(0, H, 26)
    rr = np.array([r0 * (1.0 - 0.34 * z / H) + r0 * 0.4 * max(0.0, 1 - z / (0.22 * H)) ** 2 for z in zs])
    # quantised light bands round the front of the column
    phis = np.linspace(-math.pi / 2, math.pi / 2, 61)
    lam = np.array([nv([math.sin(f), math.cos(f), 0.12]) @ LIGHT for f in phis])
    band = np.where(lam > 0.42, 0, np.where(lam > 0.0, 1, 2))
    runs = []
    s = 0
    for i in range(1, len(phis) + 1):
        if i == len(phis) or band[i] != band[s]:
            runs.append((phis[s], phis[min(i, len(phis) - 1)], band[s])); s = i
    sheath = []
    for k in range(5):
        sheath.append((rng.uniform(-1.3, 1.3), rng.uniform(-0.25, 0.25)))
    blots = []
    for k in range(int(rng.integers(4, 8))):
        blots.append((rng.uniform(0.15, 0.9) * H, rng.uniform(-1.1, 1.1), rng.uniform(0.6, 1.4)))
    drys = []
    for k in range(dry_sheaths):
        f0 = rng.uniform(-1.5, 0.9); fw = rng.uniform(0.35, 0.8); top = rng.uniform(0.18, 0.42) * H
        drys.append((f0, min(1.55, f0 + fw), top, rng.uniform(0.8, 1.05)))

    def X(phi, i): return np.array([bx + rr[i] * math.sin(phi), by + rr[i] * math.cos(phi), zs[i]])

    def draw():
        P = pa.P
        for (f0, f1, b) in runs:
            col = (lit, mid, dk)[b]
            poly = [P(X(f0, i)) for i in range(len(zs))] + [P(X(f1, i)) for i in range(len(zs))][::-1]
            # round foot: the band continues round the bottom ellipse
            poly += [P(X(f, 0)) for f in np.linspace(f0, f1, 6)]
            pa.fill(poly, col)
        outline = [P(X(-math.pi / 2, i)) for i in range(len(zs))][::-1] + [P(X(f, 0)) for f in np.linspace(-math.pi / 2, math.pi / 2, 16)] + [P(X(math.pi / 2, i)) for i in range(len(zs))]
        pa.ctx.save()
        pa.path(outline); pa.ctx.clip()
        # sheath edges climbing the column, each a dark line with a light lip beside it
        for f0, sp in sheath:
            ptsd = [P(X(f0 + sp * zs[i] / H, i)) for i in range(len(zs))]
            ptsl = [P(X(f0 + sp * zs[i] / H - 0.09, i)) for i in range(len(zs))]
            pa.line(ptsl, lit, pa.u(0.35), 0.8)
            pa.line(ptsd, out_c, pa.u(0.28), 0.45)
        # the crown shades the top of the trunk: a flat shadow with a ragged lower edge
        if not young:
            zc = H - 0.3
            sh = [P(X(f, len(zs) - 1) + [0, 0, 0.02]) for f in np.linspace(-math.pi / 2, math.pi / 2, 12)]
            fs = np.linspace(math.pi / 2, -math.pi / 2, 24)
            for k2, f in enumerate(fs):
                i = int(np.searchsorted(zs, zc + 0.07 * math.sin(k2 * 1.9) + 0.05 * (k2 % 3 == 0)))
                sh.append(P(X(f, min(i, len(zs) - 1))))
            pa.path(sh); pa.ctx.set_source_rgba(*mixc(dk, out_c, 0.35), 0.8); pa.ctx.fill()
        for (z, f, s) in blots:
            i = int(np.searchsorted(zs, z)); c = P(X(f, i))
            if EDGE:
                pa.ctx.save(); pa.ctx.translate(*c); pa.ctx.scale(pa.u(0.55) * s, pa.u(1.3) * s)
                pa.ctx.arc(0, 0, 1, 0, 6.3); pa.ctx.set_source_rgba(*C('#5a4030'), 0.6); pa.ctx.fill(); pa.ctx.restore()
            else:
                # v621 (critique 6, "bullet holes"): a long thin streak along the sheath, brown blended into the stem
                pa.ctx.save(); pa.ctx.translate(*c); pa.ctx.scale(pa.u(0.32) * s, pa.u(2.6) * s)
                pa.ctx.arc(0, 0, 1, 0, 6.3); pa.ctx.set_source_rgba(*mixc(dk, C('#6b4a2e'), 0.45), 0.45); pa.ctx.fill(); pa.ctx.restore()
        # old sheaths dried brown, hugging the foot, ragged at the top and peeling outward
        for (f0, f1, top, kk) in drys:
            i1 = int(np.searchsorted(zs, top))
            fs = np.linspace(f0, f1, 6)
            L = [P(X(f0, i) + [0, 0, 0]) for i in range(i1 + 1)]
            R = [P(X(f1, i)) for i in range(i1 + 1)]
            rag = []
            for j, f in enumerate(fs[::-1]):
                q = X(f, i1); q = q + np.array([math.sin(f), math.cos(f), 0]) * 0.03 * (j % 2)
                q[2] += (0.06 if j % 2 else -0.02) * H / 2
                rag.append(P(q))
            poly = R + rag + L[::-1]
            dc = C('#b08a55', kk)
            pa.fill(poly, dc)
            for j in range(1, 3):
                f = f0 + (f1 - f0) * j / 3
                pa.line([P(X(f, i)) for i in range(i1)], C('#7c5c33'), pa.u(0.25), 0.8)
            if EDGE: pa.path(poly); pa.ctx.set_source_rgb(*C('#5a3f1e')); pa.ctx.set_line_width(pa.u(0.4)); pa.ctx.stroke()
            pa.soft_edge(poly, dc)
        pa.ctx.restore()
        # top ellipse (mostly hidden by the crown)
        top = [P(X(f, len(zs) - 1)) for f in np.linspace(-math.pi / 2, 3 * math.pi / 2, 20)]
        pa.fill(top, mid)
        if EDGE: pa.line(outline, out_c, pa.u(0.5))
        pa.soft_edge(outline, mid, close=False)
    return draw


# ------------------------------------------------------------------ bunch
def bunch_items(pa, out, rng, p0, az, ripe, hands=5, scale=1.0):
    d = np.array([math.cos(az), math.sin(az), 0.0])
    up = np.array([0, 0, 1.0])
    p0 = np.array(p0, float)
    p1 = p0 + d * 0.40 * scale + up * 0.20 * scale
    p2 = p0 + d * 0.56 * scale - up * 0.76 * scale
    bez = lambda t: (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2
    dbez = lambda t: nv(2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1))
    stalk_c, stalk_o = C('#86a043'), C('#3a521c')
    if ripe:
        fp = dict(lit=C('#ffe468'), mid=C('#f7c934'), dk=C('#d99c22'), out=C('#7a5410'), tip=C('#4a3218'))
    else:
        fp = dict(lit=C('#c4e66e'), mid=C('#8fc040'), dk=C('#5b8d29'), out=C('#2c4f16'), tip=C('#3a4620'))
    # stalk in pieces so fingers can sit in front of and behind it
    ts = np.linspace(0, 1, 16)
    for k in range(len(ts) - 1):
        a, b = bez(ts[k]), bez(ts[k + 1] + 0.01)
        def seg(a=a, b=b, k=k):
            w = pa.u(1.25 - 0.4 * k / 15)
            pa.taper([pa.P(a), pa.P(b)], w, w, stalk_c, outline=stalk_o, ow=pa.u(0.45))
        out.append(((a + b) / 2 + np.array([0, -0.001, 0]), seg))
    # hands of fingers (nải). v620 (critique 9, "a lumpy green corn cob"): fewer, bigger hands, each one a fan of
    # long fingers on the outer side of the stalk only, curving up toward the sky, with bare stalk between hands,
    # so the bunch reads as stacked crescents
    nh = max(2, int(round(hands * 0.7)))
    t0, t1 = 0.3, 0.74
    yv = np.array([0.0, 1.0, 0.0])                       # toward the viewer
    for h in range(nh):
        t = t0 + (t1 - t0) * h / max(1, nh - 1)
        c = bez(t); T = dbez(t)
        # horizontal frame round the stalk
        X1 = nv(np.cross(T, up)) if abs(T[2]) < 0.99 else np.array([1.0, 0, 0])
        Y1 = nv(np.cross(X1, T)); Y1 = nv(Y1 - (Y1 @ T) * T)
        nf = int(rng.integers(5, 7)) if h < nh - 1 else int(rng.integers(4, 5))
        Lf = (0.27 - 0.04 * h / max(1, nh - 1)) * scale
        rf = 0.04 * scale
        # the fan faces the viewer, turning a little from hand to hand like the real spiral
        cdir = nv(yv - (yv @ T) * T); cdir = nv(cdir + X1 * (0.45 if h % 2 else -0.45))
        cside = nv(np.cross(T, cdir))
        # v621 (critique 8, "straight parallel fingers like a comb"): the fan opens sideways across the view and
        # each finger bends up along its whole length, tips spreading wider than the bases
        span = 2.7 + rng.uniform(-0.15, 0.15)
        for j in range(nf):
            fj = j / max(1, nf - 1) - 0.5
            phi = fj * span
            rad = cdir * math.cos(phi) + cside * math.sin(phi)
            b0 = c + rad * 0.045 * scale
            Lj = Lf * (1.0 - 0.22 * abs(fj) * 2)
            cl = []
            for tau in np.linspace(0, 1, 9):
                q = b0 + rad * Lj * (0.75 * tau - 0.12 * tau * tau) + cside * Lj * 0.35 * fj * tau * tau + up * Lj * 0.62 * tau ** 1.35 - T * Lj * 0.06 * tau
                cl.append(q)
            cen = cl[4]
            def finger(cl=cl, rf=rf):
                pts = np.array([pa.P(q) for q in cl])
                n = len(pts); Lp, Rp = [], []
                for i in range(n):
                    a = pts[max(0, i - 1)]; b = pts[min(n - 1, i + 1)]
                    dd = nv(b - a); nrm = np.array([-dd[1], dd[0]])
                    tt = i / (n - 1)
                    w = pa.k * rf * (0.5 + 0.5 * math.sin(math.pi * min(1, 0.12 + tt * 0.92)) ** 0.6)
                    Lp.append(pts[i] + nrm * w); Rp.append(pts[i] - nrm * w)
                dd = nv(pts[-1] - pts[0]); nrm = np.array([-dd[1], dd[0]])
                litside = Lp if nrm @ SLIGHT > 0 else Rp
                body = Lp + Rp[::-1]
                pa.fill([tuple(q) for q in body], fp['mid'])
                inner = [pts[i] * 0.5 + litside[i] * 0.5 for i in range(n)]
                hl = [tuple(q) for q in litside[1:-1]] + [tuple(q) for q in inner[1:-1][::-1]]
                pa.fill(hl, fp['lit'], seam=False)
                shd = Rp if litside is Lp else Lp
                sh = [tuple(q) for q in shd[1:]] + [tuple(pts[i] * 0.65 + shd[i] * 0.35) for i in range(1, n)][::-1]
                pa.fill(sh, fp['dk'], seam=False)
                if EDGE: pa.path([tuple(q) for q in body]); pa.ctx.set_source_rgb(*fp['out']); pa.ctx.set_line_width(pa.u(0.4)); pa.ctx.stroke()
                pa.soft_edge([tuple(q) for q in body], fp['mid'])
                # a small dark flower end at the tip
                tip = pts[-1]; pa.ctx.arc(tip[0], tip[1], pa.k * rf * (0.42 if EDGE else 0.28), 0, 6.3)
                pa.ctx.set_source_rgb(*(fp['tip'] if EDGE else mixc(fp['tip'], fp['dk'], 0.45))); pa.ctx.fill()
            out.append((cen, finger))
    # the heart hanging at the end of the bare stalk
    hc = p2 + np.array([0, 0, -0.13 * scale]); Th = dbez(1.0)
    def heart():
        top = np.array(pa.P(p2)); bot = np.array(pa.P(p2 + nv(Th * 0.4 + np.array([0, 0, -1.0])) * 0.36 * scale))
        ax = nv(bot - top); nrm = np.array([-ax[1], ax[0]]); Lh = np.linalg.norm(bot - top)
        Wh = 0.085 * scale * pa.k
        def shape(w, t0=0.0, t1=1.0, off=0.0):
            L, R = [], []
            for t in np.linspace(t0, t1, 14):
                prof = math.sin(math.pi * min(1, t ** 0.75)) ** 0.8 * (1 - 0.15 * t)
                c = top + ax * Lh * t + nrm * off * Wh
                L.append(tuple(c + nrm * w * Wh * prof)); R.append(tuple(c - nrm * w * Wh * prof))
            return L + R[::-1]
        litdir = 1 if nrm @ SLIGHT > 0 else -1
        pa.fill(shape(1.0), C('#7d2248'))
        pa.fill(shape(0.55, 0.05, 0.95, 0.38 * litdir), C('#a8396b'), seam=False)
        pa.fill(shape(0.22, 0.12, 0.8, 0.55 * litdir), C('#c75b8c'), seam=False)
        if EDGE: pa.path(shape(1.0)); pa.ctx.set_source_rgb(*C('#3f0c22')); pa.ctx.set_line_width(pa.u(0.45)); pa.ctx.stroke()
        pa.soft_edge(shape(1.0), C('#7d2248'))
        # bract lines
        for t in (0.35, 0.6):
            a = top + ax * Lh * t
            pa.line([tuple(a - nrm * Wh * 0.8), tuple(a + ax * Lh * 0.12), tuple(a + nrm * Wh * 0.8)], C('#4e1230'), pa.u(0.3), 0.8)
    out.append((hc + np.array([0, 0.001, 0]), heart))
