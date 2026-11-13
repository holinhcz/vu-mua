# Potted yellow apricot (chậu mai vàng) for Nông Trại Nhỏ, built as a small 3D model and painted in flat game tones
# with the thin same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun and night.
# A terracotta pot with a rolled rim and an incised band, dark soil with a few surface roots; an old gnarled trunk
# (thick flared foot, an S twist, pale lichen spots) that splits into three main limbs, side branches and fine twigs.
# Four looks follow the game's season: 0 spring in full bloom (five-petal yellow flowers, bright young leaves),
# 1 summer green leaves, 2 autumn leaves turning yellow, 3 winter bare (leaves stripped) with buds along the twigs.
import math, os, sys
import numpy as np, cairo
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'chuoi'))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'dambut'))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM
from dambut import hull

RS, SS = 9, 2
PX = RS * SS
KU = 29.0
UP = np.array([0, 0, 1.0])
MASS = False  # True brings back the v629 dark round mass inside the summer/autumn crown
SUNXY = nv(np.array([LIGHT[0], LIGHT[1]]))


def tones():
    return dict(
        green=[C('#1f5326'), C('#2b6c2e'), C('#3b883a'), C('#54a346'), C('#72bc58')],
        und=[C('#3e6c35'), C('#4f8041'), C('#62964d')],
        young=[C('#5e9a2a'), C('#7ab232'), C('#98c844'), C('#b4da5c'), C('#cbe67a')],
        turn=[C('#7a8a26'), C('#9aa22e'), C('#b9b63a'), C('#d4c64c'), C('#e6d466')],
        yel=[C('#a88a1a'), C('#c8a424'), C('#dcbc32'), C('#ead04a'), C('#f4e070')],
        inner=C('#1b4521'),
        bark=dict(lit=C('#9c8672'), mid=C('#6f5a49'), dk=C('#4b3b2f'), moss=C('#b9b597')),
        pot=dict(lit=C('#dc8458'), mid=C('#bd6440'), dk=C('#8f4630'), rim=C('#cc7048'), rimdk=C('#a4553a'),
                 inner=C('#6a3424'), band=C('#9c4c32'), hi=C('#eda27a')),
        soil=C('#4a3324'), soil2=C('#5c4130'), root=dict(lit=C('#8c7462'), mid=C('#664f40')),
        petal=[C('#e09208'), C('#f4ae12'), C('#ffc61e'), C('#ffd84a')], eye=C('#f0961e'), stamen=C('#cc6a1c'),
        bud=dict(dk=C('#5f8a2a'), mid=C('#7ea836'), lit=C('#a0c24c')), budtip=C('#f2c43a'),
    )


class Mai:
    """seed picks the shape; look 0 spring bloom, 1 summer leaves, 2 autumn turning, 3 winter bare with buds"""
    def __init__(self, seed, pa, look=0):
        self.pa = pa; self.seed = seed; self.look = look
        r = self.rng = np.random.default_rng(seed * 5413 + 29)
        self.items = []
        self.T = tones()
        q = seed % 4
        self.PH = 0.56                                        # pot height
        self.H = [0.3, 0.24, 0.34, 0.27][q]                   # trunk height above the soil before it splits
        self.crown = [1.0, 1.05, 0.95, 1.02][q]
        self.lean = [0.08, -0.1, 0.06, -0.07][q]
        self.ce = np.array([self.lean * 1.6, 0.0, self.PH + self.H + 1.3 * self.crown])
        self.ra = [1.12, 1.2, 1.06, 1.16][q] * self.crown
        self.ry = self.ra * 0.92
        self.rb = [0.74, 0.7, 0.78, 0.72][q] * self.crown
        self.lumps = [(nv(r.normal(0, 1, 3)), r.uniform(1.6, 2.6), r.uniform(0, 6.28), r.uniform(0.06, 0.1)) for _ in range(5)]
        self._pot(r)
        self._trunk(r)
        self._limbs(r)
        self._crown(r)

    def lump(self, d):
        return 1.0 + sum(a * math.cos(fr * (d @ kk) * math.pi + ph) for kk, fr, ph, a in self.lumps)

    def env(self, d, f=1.0):
        return self.ce + np.array([d[0] * self.ra, d[1] * self.ry, d[2] * self.rb]) * f * self.lump(d)

    def norm_at(self, p):
        return nv((p - self.ce) / np.array([self.ra, self.ry, self.rb]) ** 2)

    # ------------------------------------------------------------- pot
    def prof(self, t):
        """pot radius at height fraction t (0 foot, 1 rim)"""
        return 0.31 + 0.15 * math.sin(min(1.0, t * 1.15) * math.pi * 0.72) - 0.02 * t

    def _pot(self, r):
        pa = self.pa; T = self.T; Pt = T['pot']; PH = self.PH
        ts = np.linspace(0, 0.9, 19)
        roots = []
        for k in range(4):
            a = r.uniform(0, 2 * math.pi)
            roots.append((a, r.uniform(0.16, 0.26), r.uniform(0.035, 0.05)))
        def ell(z, rr, a0=0, a1=2 * math.pi, n=37):
            return [pa.P(np.array([rr * math.cos(a), rr * math.sin(a), z])) for a in np.linspace(a0, a1, n)]
        def draw():
            P = pa.P; k = pa.k
            # the body: left and right silhouettes from the profile
            Lp = [P(np.array([-self.prof(t), 0, t * PH])) for t in ts]
            Rp = [P(np.array([self.prof(t), 0, t * PH])) for t in ts]
            foot = ell(0.0, self.prof(0), 0, math.pi, 19)            # front half of the foot
            body = Lp[::-1] + foot[::-1][1:-1] + Rp
            body = [tuple(q) for q in Rp[::-1]] + [tuple(q) for q in ell(0.0, self.prof(0), 0, math.pi, 19)] + [tuple(q) for q in Lp]
            pa.fill(body, Pt['mid'])
            pa.ctx.save(); pa.path(body); pa.ctx.clip()
            # light from the left: bands follow the curve of the front surface
            def strip(p0, p1, f=1.003):
                A = [P(np.array([math.cos(p0) * self.prof(t) * f, math.sin(p0) * self.prof(t) * f, t * PH])) for t in ts]
                B = [P(np.array([math.cos(p1) * self.prof(t) * f, math.sin(p1) * self.prof(t) * f, t * PH])) for t in ts[::-1]]
                # close along the foot so the band reaches the bottom edge
                F = [P(np.array([math.cos(p) * self.prof(0) * f, math.sin(p) * self.prof(0) * f, 0.0])) for p in np.linspace(p1, p0, 9)]
                return A[::-1] + [P(np.array([math.cos(p) * self.prof(ts[-1]) * f, math.sin(p) * self.prof(ts[-1]) * f, ts[-1] * PH])) for p in np.linspace(p0, p1, 9)] + B[1:] + F
            pa.fill(strip(math.pi * 0.6, math.pi * 1.02), Pt['lit'], seam=False)
            pa.fill(strip(math.pi * 0.7, math.pi * 0.8), Pt['hi'], seam=False)
            pa.fill(strip(-0.05, math.pi * 0.28), Pt['dk'], seam=False)
            # the incised band round the shoulder, two thin rings with a row of small stamped marks between
            for z0 in (0.64, 0.74):
                rr = self.prof(z0 / 0.9 * 0.9) * 1.0
                pa.line(ell(z0 * PH, self.prof(z0) + 0.003, 0.05, math.pi - 0.05, 25), Pt['band'], pa.u(0.35), 0.8)
            for a in np.linspace(0.25, math.pi - 0.25, 9):
                q = np.array([math.cos(a), math.sin(a), 0]) * (self.prof(0.69) + 0.004) + UP * 0.69 * PH
                x, y = P(q); pa.ctx.new_path(); pa.ctx.arc(x, y, pa.u(0.45) * (0.4 + 0.6 * math.sin(a)), 0, 2 * math.pi)
                pa.ctx.set_source_rgb(*Pt['band']); pa.ctx.fill()
            # a darker foot ring
            pa.line(ell(0.03, self.prof(0.03) + 0.002, 0, math.pi, 25), Pt['dk'], pa.u(0.7), 0.6)
            pa.ctx.restore()
            pa.soft_edge(body, Pt['mid'])
            # the rolled rim: a thick ring seen from above
            zr = 0.9 * PH; Rr = self.prof(0.9) + 0.045
            outer = ell(zr + 0.05, Rr)
            outer_lo = ell(zr - 0.02, Rr, 0, math.pi, 19)
            rim_band = outer_lo + ell(zr + 0.05, Rr, math.pi, 0, 19)
            pa.fill(rim_band, Pt['rimdk'])
            pa.fill(outer, Pt['rim'])
            pa.ctx.save(); pa.path(outer); pa.ctx.clip()
            pa.fill(ell(zr + 0.05, Rr * 1.02, math.pi * 0.55, math.pi * 1.25, 13) + [P(np.array([0, 0, zr + 0.05]))], Pt['hi'], seam=False)
            pa.ctx.restore()
            pa.soft_edge(outer, Pt['rim'])
            # the opening and the soil a little below the rim
            inner = ell(zr + 0.05, Rr - 0.06)
            pa.fill(inner, Pt['inner'])
            soil = ell(zr + 0.01, Rr - 0.075)
            pa.ctx.save(); pa.path(inner); pa.ctx.clip()
            sc = [(x, y + pa.u(0.6)) for x, y in soil]
            pa.fill(sc, T['soil'])
            for j in range(14):
                a = (j * 2.39) % (2 * math.pi); rr = (Rr - 0.11) * math.sqrt((j * 0.37) % 1)
                x, y = P(np.array([rr * math.cos(a), rr * math.sin(a), zr + 0.01]))
                pa.ctx.new_path(); pa.ctx.arc(x, y + pa.u(0.6), pa.u(0.5), 0, 2 * math.pi)
                pa.ctx.set_source_rgb(*T['soil2']); pa.ctx.fill()
            pa.ctx.restore()
            # surface roots spreading from the trunk foot over the soil
            for a, L, w in roots:
                d = np.array([math.cos(a), math.sin(a), 0])
                pts = [P(np.array([0, 0, zr + 0.02]) + d * L * t + UP * 0.03 * (1 - t) ** 2) for t in np.linspace(0, 1, 6)]
                pts = [(x, y + pa.u(0.6) * t) for (x, y), t in zip(pts, np.linspace(0, 1, 6))]
                pa.taper(pts, w * 2 * k, w * 0.4 * k, T['root']['mid'], outline=T['root']['mid'])
        self.items.append((np.array([0, 0, 0.0]) - TOCAM * 5.0, draw))

    # ------------------------------------------------------------- trunk and limbs
    def X(self, s):
        """trunk axis, s from the soil (0) to the split (1): an S twist"""
        z0 = self.PH * 0.9
        return np.array([self.lean * (math.sin(s * math.pi * 1.2) * 0.9 + s * 0.6),
                         0.05 * math.sin(s * math.pi * 1.6 + 0.6), z0 + self.H * s])

    def rad(self, s):
        return 0.095 + 0.03 * (1 - s) + 0.07 * math.exp(-s / 0.14)

    def _tube(self, pts, w0, w1, key, moss=None, lit=True, col=None):
        pa = self.pa; T = self.T
        def draw(pts=pts):
            P = pa.P; B = T['bark']
            c0 = B['mid'] if col is None else col
            sp = [P(q) for q in pts]
            pa.taper(sp, w0 * 2 * pa.k, w1 * 2 * pa.k, c0, outline=c0)
            arr = np.array(sp); n = len(arr); L, R = [], []
            for i in range(n):
                a = arr[max(0, i - 1)]; b = arr[min(n - 1, i + 1)]
                dd = nv(b - a); nr = np.array([-dd[1], dd[0]])
                if nr @ SLIGHT < 0: nr = -nr
                w = (w0 + (w1 - w0) * i / (n - 1)) * pa.k
                L.append(tuple(arr[i] + nr * w * 0.5)); R.append(tuple(arr[i] - nr * w * 0.55))
            if lit:
                pa.line(L, B['lit'], max(pa.u(0.3), (w0 + w1) * 0.42 * pa.k), 0.85)
                pa.line(R, B['dk'], max(pa.u(0.3), (w0 + w1) * 0.32 * pa.k), 0.7)
            if moss:
                for (i, off, sz) in moss:
                    i = min(n - 1, i)
                    a = arr[max(0, i - 1)]; b = arr[min(n - 1, i + 1)]
                    dd = nv(b - a); nr = np.array([-dd[1], dd[0]])
                    w = (w0 + (w1 - w0) * i / (n - 1)) * pa.k
                    x, y = arr[i] + nr * w * off
                    pa.ctx.save(); pa.ctx.translate(x, y); pa.ctx.rotate(math.atan2(dd[1], dd[0])); pa.ctx.scale(w * sz * 1.4, w * sz * 0.7)
                    pa.ctx.new_path(); pa.ctx.arc(0, 0, 1, 0, 2 * math.pi); pa.ctx.restore()
                    pa.ctx.set_source_rgba(*B['moss'], 0.75); pa.ctx.fill()
        self.items.append((key, draw))

    def _trunk(self, r):
        ss = np.linspace(0, 1, 13)
        pts = [self.X(s) for s in ss]
        moss = [(int(r.integers(2, 11)), r.uniform(-0.5, 0.5), r.uniform(0.25, 0.4)) for _ in range(4)]
        # the trunk tapers from a flared foot; drawn as a tube with per-point width via pieces
        pa = self.pa
        def wfun(s): return self.rad(s)
        segs = []
        for i in range(len(pts) - 1):
            segs.append((pts[i], pts[i + 1], wfun(ss[i]), wfun(ss[i + 1])))
        # one ribbon whose width follows rad(): build it by hand
        T = self.T
        def draw():
            P = pa.P; B = T['bark']
            sp = np.array([P(q) for q in pts]); n = len(sp)
            Lp, Rp, Cn = [], [], []
            for i in range(n):
                a = sp[max(0, i - 1)]; b = sp[min(n - 1, i + 1)]
                d = nv(b - a); nrm = np.array([-d[1], d[0]])
                if nrm @ SLIGHT < 0: nrm = -nrm
                w = wfun(ss[i]) * pa.k
                Lp.append(sp[i] + nrm * w); Rp.append(sp[i] - nrm * w); Cn.append((sp[i], nrm, w))
            body = [tuple(q) for q in Lp] + [tuple(q) for q in Rp[::-1]]
            pa.fill(body, B['mid'])
            pa.ctx.save(); pa.path(body); pa.ctx.clip()
            band = lambda f0, f1: [tuple(p + nr * w * f0) for (p, nr, w) in Cn] + [tuple(p + nr * w * f1) for (p, nr, w) in Cn[::-1]]
            pa.fill(band(1.05, 0.2), B['lit'], seam=False)
            pa.fill(band(-1.05, -0.5), B['dk'], seam=False)
            # gnarls: a few short dark ridges across the trunk, pale lichen spots
            for j in range(6):
                i = 1 + (j * 5) % (n - 2)
                p, nr, w = Cn[i]; d = np.array([nr[1], -nr[0]])
                off = ((j * 0.37) % 1 - 0.5) * 1.2
                a = p + nr * w * off
                pa.line([tuple(a - nr * w * 0.25), tuple(a + d * pa.u(0.8) + nr * w * 0.2)], B['dk'], pa.u(0.35), 0.6)
            for (i, off, sz) in moss:
                p, nr, w = Cn[min(n - 1, i)]
                x, y = p + nr * w * off
                pa.ctx.save(); pa.ctx.translate(x, y); pa.ctx.scale(w * sz * 0.9, w * sz * 0.5)
                pa.ctx.new_path(); pa.ctx.arc(0, 0, 1, 0, 2 * math.pi); pa.ctx.restore()
                pa.ctx.set_source_rgba(*B['moss'], 0.8); pa.ctx.fill()
            pa.ctx.restore()
            pa.soft_edge([tuple(q) for q in Lp], B['mid'], close=False); pa.soft_edge([tuple(q) for q in Rp], B['mid'], close=False)
        self.items.append((self.X(0.3) - TOCAM * 2.5, draw))

    def _limbs(self, r):
        top = self.X(1.0)
        rf = self.rad(1.0)
        self.bpts = []; self.wood = []; self.tips = []
        az0 = r.uniform(0, 2 * math.pi)
        for k in range(3):
            az = az0 + k * 2.09 + r.normal(0, 0.2)
            tilt = (0.18 if k == 0 else 0.5) + r.normal(0, 0.06)
            d = nv(UP * math.cos(tilt) + np.array([math.cos(az), math.sin(az), 0]) * math.sin(tilt))
            L = (1.45 if k == 0 else 1.25) * r.uniform(0.94, 1.06) * self.crown
            self._branch(r, top - UP * 0.03, d, L, rf * (0.8 if k == 0 else 0.7), 0)

    def _branch(self, r, p0, d, L, w0, lev):
        m = 8
        pts = [p0]; dd = d.copy()
        hz = np.array([dd[0], dd[1], 0.0])
        bend = nv(hz + r.normal(0, 0.3, 3) * np.array([1, 1, 0])) if np.linalg.norm(hz) > 1e-3 else np.array([1.0, 0, 0])
        sc = np.array([1 / self.ra, 1 / self.ry, 1 / self.rb])
        inside = np.linalg.norm((p0 - self.ce) * sc) < 0.86
        for k in range(m):
            # mai wood zigzags: each node turns a little
            dd = nv(dd + bend * 0.035 + UP * 0.01 + r.normal(0, 0.08, 3))
            nx = pts[-1] + dd * L / m
            e = (nx - self.ce) * sc
            if not inside:
                # the limbs start below the crown: steer only once they are in it
                inside = np.linalg.norm(e) < 0.86
            elif np.linalg.norm(e) > 0.86:
                g = nv(e * sc)
                dd = nv(dd - g * max(0.0, dd @ g) * 1.1 + UP * 0.03)
                nx = pts[-1] + dd * L / m
                if np.linalg.norm((nx - self.ce) * sc) > 0.98 and k >= 2: break
            pts.append(nx)
        w1 = w0 * 0.5
        moss = [(int(r.integers(1, len(pts))), r.uniform(-0.4, 0.4), r.uniform(0.3, 0.5))] if lev == 0 and r.random() < 0.7 else None
        key = (pts[0] + pts[-1]) / 2 - TOCAM * (0.35 if lev > 0 else 0.15)
        self._tube(pts, w0, w1, key, moss=moss, lit=lev < 2)
        for q in pts[2:]: self.bpts.append((q, lev, (w0 + w1) / 2))
        if lev >= 1: self.tips.append(pts[-1])
        if lev < 2:
            nk = int(r.integers(3, 5)) if lev == 0 else int(r.integers(2, 4))
            for j in range(nk):
                t = r.uniform(0.35, 0.85) if j < nk - 1 else 1.0
                mm = len(pts) - 1; i = min(mm, max(1, int(round(t * mm))))
                base = pts[i]
                dir0 = nv(pts[min(mm, i + 1)] - pts[max(0, i - 1)])
                out = np.array([base[0] - self.ce[0], base[1] - self.ce[1], 0.0])
                az = r.uniform(0, 2 * math.pi)
                side = np.array([math.cos(az), math.sin(az), 0.0])
                if np.linalg.norm(out) > 0.05: side = nv(side * 0.9 + nv(out) * 0.8)
                cd = nv(dir0 * math.cos(0.6) + nv(side - (side @ dir0) * dir0) * math.sin(0.6) + UP * 0.1)
                self._branch(r, base, cd, L * r.uniform(0.5, 0.66), w1 * (0.9 if t > 0.95 else 0.72), lev + 1)

    # ------------------------------------------------------------- crown
    def _crown(self, r):
        look = self.look
        n = 150 if look != 3 else 80
        ga = math.pi * (3 - math.sqrt(5))
        spots = []
        for i in range(n):
            zz = 1 - 2 * (i + 0.5) / n; rr = math.sqrt(max(0.0, 1 - zz * zz))
            if zz < -0.5: continue
            d = np.array([rr * math.cos(i * ga), rr * math.sin(i * ga), zz])
            spots.append(self.env(d, r.uniform(0.92, 1.02) if i % 4 else r.uniform(0.78, 0.88)))
        # every branch end carries a cluster too, so no bare stick pokes out of the crown
        spots += [p for p in self.tips]
        # no dark round mass behind the leaves any more (Link 2026-10-31): thin spots show what is behind
        if look in (1, 2) and MASS: self._mass()
        cand = [b for b in self.bpts if b[1] >= 1 or b[0][2] > self.ce[2] - 0.2]
        B = np.array([b[0] for b in cand])
        cap = 0.34 if look == 3 else 0.45
        for sp in spots:
            # a twig from the nearest branch out to the spot, zigzagging node to node
            j = int(np.argmin(np.linalg.norm(B - sp, axis=1)))
            bp, lev, w = cand[j]
            v = sp - bp; L = float(np.linalg.norm(v))
            if L > 0.05:
                d = nv(v); sd = nv(np.cross(d, UP)) if abs(d[2]) < 0.99 else np.array([1.0, 0, 0])
                tw = [bp + d * L * t + sd * (0.025 * (-1) ** i if 0 < i < 4 else 0) + UP * 0.03 * math.sin(t * math.pi)
                      for i, t in enumerate(np.linspace(0, 1, 5))]
                tw_w = (max(0.01, w * 0.5) if look == 3 else 0.008) * (1.4 if L > cap else 1.0)
                self._tube(tw, tw_w, 0.006, (bp + sp) / 2 - TOCAM * 0.6, lit=False,
                           col=mixc(self.T['bark']['mid'], self.T['bark']['dk'], 0.3 if look == 3 else 0.0))
                if look == 3:
                    # side twiglets carry buds too
                    for t in (0.4, 0.7):
                        q0 = bp + d * L * t
                        e = nv(d + sd * (1 if t < 0.5 else -1) * 0.9 + UP * 0.4)
                        tw2 = [q0, q0 + e * 0.09, q0 + e * 0.17 + UP * 0.02]
                        self._tube(tw2, 0.007, 0.005, q0 - TOCAM * 0.5, lit=False, col=mixc(self.T['bark']['mid'], self.T['bark']['dk'], 0.3))
                        self._buds(r, tw2[-1], q0, n=2)
            if look == 0: self._blooms(r, sp)
            elif look == 3: self._buds(r, sp, bp if L > 0.05 else sp)
            else: self._leaves(r, sp, look)

    def _mass(self):
        pa = self.pa; T = self.T
        pts = []
        for th in np.linspace(0, math.pi, 25):
            for ph in np.linspace(0, 2 * math.pi, 37):
                d = np.array([math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)])
                if d[2] < -0.4: continue
                pts.append(self.env(d, 0.76))
        def draw():
            pa.fill(hull([pa.P(p) for p in pts]), T['inner'])
        self.items.append((self.ce - TOCAM * 2.0, draw))

    def _leaf_set(self, r, c, n, fams, L0, key_bias=0.0):
        T = self.T; pa = self.pa
        ns = self.norm_at(c)
        nrm0 = nv(ns + UP * 0.9)
        t1 = np.cross(nrm0, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(nrm0, t1)
        hc = (c[2] - self.ce[2]) / self.rb
        sun = float(ns @ LIGHT)
        ao = 0.78 + 0.22 * max(-1.0, min(1.0, hc + 0.1))
        az0 = r.uniform(0, 2 * math.pi)
        leaves = []
        for k in range(n):
            az = az0 + k * 2 * math.pi / n + r.normal(0, 0.7)
            A = math.cos(az) * t1 + math.sin(az) * t2
            el = r.uniform(0.05, 0.6)
            ld = nv(A * math.cos(el) + nrm0 * math.sin(el) - UP * 0.15)
            sd = nv(np.cross(nrm0, ld))
            Ll = L0 * r.uniform(0.8, 1.15); Wl = Ll * 0.48
            c_k = c + (r.normal(0, 1, 3) * np.array([1, 1, 0.5])) * 0.05
            prof = [(0.0, 0.15), (0.1, 0.6), (0.3, 0.95), (0.45, 1.0), (0.65, 0.82), (0.85, 0.42), (1.0, 0.0)]
            pt = c_k + ld * 0.015
            Lp_, Rp_ = [], []
            for (t, w) in prof:
                q = pt + ld * Ll * t - UP * Ll * 0.14 * t * t
                Lp_.append(q + sd * Wl * 0.5 * w); Rp_.append(q - sd * Wl * 0.5 * w)
            nn = nv(np.cross(ld, sd))
            if nn @ nrm0 < 0: nn = -nn
            topv = nn @ TOCAM > 0
            lam = float((nn if topv else -nn) @ LIGHT)
            v = (0.55 + 0.45 * max(-0.3, lam)) * ao + 0.13 * sun - 0.05
            fam = fams[k % len(fams)] if len(fams) > 1 else fams[0]
            leaves.append(dict(poly=Lp_ + Rp_[::-1], top=topv, v=v, mid=pt + ld * Ll * 0.5, fam=fam,
                               rib=(pt, pt + ld * Ll * 0.85 - UP * Ll * 0.1)))
        vm = float(np.mean([z['v'] for z in leaves]))
        for z in leaves: z['v'] = 0.55 * vm + 0.45 * z['v']
        leaves.sort(key=lambda z: depth(z['mid']))
        def col_of(z):
            v = z['v']
            if z['fam'] == 'green' and not z['top']: return T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            i = 0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4
            if not z['top']: i = max(0, i - 1)
            return T[z['fam']][i]
        cols = [col_of(z) for z in leaves]
        def draw(leaves=leaves, cols=cols):
            P = pa.P
            for z, col in zip(leaves, cols):
                poly = [P(q) for q in z['poly']]
                pa.fill(poly, col); pa.soft_edge(poly, col)
                pa.line([P(z['rib'][0]), P(z['rib'][1])], mixc(col, C('#e8eeb0'), 0.3), pa.u(0.2), 0.7)
        self.items.append((c + TOCAM * key_bias, draw))

    def _leaves(self, r, c, look):
        if look == 1: fams = ['green']
        else:
            x = r.random()
            fams = ['green', 'turn'] if x < 0.4 else ['turn', 'turn', 'yel'] if x < 0.8 else ['yel', 'turn']
        self._leaf_set(r, c, int(r.integers(6, 10)), fams, 0.19)

    def _blooms(self, r, c):
        """a cluster of open yellow flowers round the twig end, a few bright young leaves among them"""
        T = self.T; pa = self.pa
        if r.random() < 0.45: self._leaf_set(r, c - UP * 0.02, int(r.integers(2, 4)), ['young'], 0.14, key_bias=-0.05)
        ns = self.norm_at(c)
        t1 = np.cross(ns, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(ns, t1)
        hc = (c[2] - self.ce[2]) / self.rb
        ao = 0.74 + 0.26 * max(-1.0, min(1.0, hc + 0.15))      # the underside of the crown in its own shade
        sun = float(ns @ LIGHT)
        fl = []
        nf = int(r.integers(4, 7))
        for j in range(nf):
            a = r.uniform(0, 2 * math.pi); rr = 0.17 * math.sqrt(r.uniform(0.05, 1))
            p = c + (math.cos(a) * t1 + math.sin(a) * t2) * rr + ns * r.uniform(-0.02, 0.04)
            f = nv(ns + UP * 0.6 + TOCAM * 0.3 + r.normal(0, 0.35, 3))
            u = np.cross(f, UP); u = nv(u) if np.linalg.norm(u) > 1e-3 else np.array([1.0, 0, 0])
            v = np.cross(f, u)
            R = 0.11 * r.uniform(0.88, 1.1)
            ph0 = r.uniform(0, 2 * math.pi)
            petals = []
            for k in range(5):
                pk = ph0 + k * 2 * math.pi / 5
                e = math.cos(pk) * u + math.sin(pk) * v
                s = -math.sin(pk) * u + math.cos(pk) * v
                prof = [(0.0, 0.2), (0.2, 0.7), (0.45, 1.0), (0.7, 0.95), (0.88, 0.7), (1.0, 0.0)]
                pts = [p + e * R * t + s * R * 0.32 * w + f * R * 0.12 * t for t, w in prof] + \
                      [p + e * R * t - s * R * 0.32 * w + f * R * 0.12 * t for t, w in prof[::-1]]
                petals.append((pts, p + e * R * 0.5))
            front = f @ TOCAM > 0
            lam = float((f if front else -f) @ LIGHT)
            vv = (0.6 + 0.4 * max(-0.2, lam)) * ao + 0.16 * sun + (0 if front else -0.15)
            fl.append(dict(p=p, f=f, petals=petals, v=vv, R=R, front=front))
        fl.sort(key=lambda z: depth(z['p']))
        def draw(fl=fl):
            P = pa.P; Pc = T['petal']
            for z in fl:
                v = z['v']
                col = Pc[0] if v < 0.45 else Pc[1] if v < 0.62 else Pc[2] if v < 0.8 else Pc[3]
                ps = sorted(z['petals'], key=lambda q: depth(q[1]))
                for pts, mid in ps:
                    poly = [P(q) for q in pts]
                    pa.fill(poly, col); pa.soft_edge(poly, col)
                if z['front']:
                    x, y = P(z['p'] + z['f'] * 0.01)
                    pa.ctx.new_path(); pa.ctx.arc(x, y, pa.u(0.5), 0, 2 * math.pi)
                    pa.ctx.set_source_rgb(*T['eye']); pa.ctx.fill()
                    for k in range(5):
                        a = k * 1.2566 + 0.4
                        pa.ctx.new_path(); pa.ctx.arc(x + math.cos(a) * pa.u(0.85), y + math.sin(a) * pa.u(0.62), pa.u(0.2), 0, 2 * math.pi)
                        pa.ctx.set_source_rgb(*T['stamen']); pa.ctx.fill()
        self.items.append((c + TOCAM * 0.12, draw))

    def _buds(self, r, c, bp, n=None):
        """winter: the leaves are stripped, the twigs carry green buds in pairs, a few already showing yellow"""
        T = self.T; pa = self.pa
        buds = []
        for j in range(int(r.integers(3, 6)) if n is None else n):
            t = r.uniform(0.35, 1.0)
            p = bp + (c - bp) * t
            d = nv(nv(c - bp) * 0.6 + UP * 0.6 + r.normal(0, 0.4, 3))
            buds.append((p, d, r.random() < 0.18))
        def draw(buds=buds):
            P = pa.P; Bd = T['bud']
            for p, d, op in buds:
                a = np.array(P(p)); b = np.array(P(p + d * 0.06))
                ax = b - a; ln = max(1e-3, np.linalg.norm(ax)); ax /= ln; sx = np.array([ax[1], -ax[0]])
                W = pa.k * 0.042
                body = [tuple(a + ax * ln * t + sx * W * 0.5 * w) for t, w in ((0, 0.4), (0.3, 1.0), (0.65, 0.85), (1, 0))] + \
                       [tuple(a + ax * ln * t - sx * W * 0.5 * w) for t, w in ((1, 0), (0.65, 0.85), (0.3, 1.0), (0, 0.4))]
                pa.fill(body, Bd['mid'])
                sl = 1 if sx @ SLIGHT > 0 else -1
                pa.fill([tuple(a + ax * ln * t + sx * sl * W * 0.5 * w) for t, w in ((0.1, 0.6), (0.35, 0.95), (0.7, 0.7), (0.95, 0.1))] +
                        [tuple(a + ax * ln * t) for t in (0.95, 0.7, 0.35, 0.1)], Bd['lit'], seam=False)
                if op:
                    x, y = a + ax * ln * 0.95
                    pa.ctx.new_path(); pa.ctx.arc(x, y, W * 0.38, 0, 2 * math.pi); pa.ctx.set_source_rgb(*T['budtip']); pa.ctx.fill()
                pa.soft_edge(body, Bd['mid'])
        self.items.append((c + TOCAM * 0.05, draw))

    def shadow(self):
        pa = self.pa; c = pa.ctx
        cx, cy = pa.P(np.array([self.ce[0], self.ce[1], 0.0]))
        fx, fy = pa.P(np.array([0.0, 0.0, 0.0]))
        k = 0.55 if self.look == 3 else 1.0
        rx = 0.9 * self.ra * pa.k * k; e = 0.42; rf = 0.5 * pa.k
        for grow, al in ((1.1, 0.06 * k + 0.03), (1.0, 0.11 * k + 0.05)):
            c.new_path()
            for (x, y, rr) in ((cx, cy, rx), (fx, fy, rf)):
                c.save(); c.translate(x, y); c.scale(rr * grow, rr * grow * e); c.new_sub_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
            c.set_fill_rule(cairo.FILL_RULE_WINDING); c.set_source_rgba(0, 0, 0, al); c.fill()

    def paint(self):
        self.shadow()
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()


# frames: seed 0-3 within each look (0 spring bloom, 1 summer, 2 autumn, 3 winter)
FRAMES = [dict(seed=s, look=lk) for lk in range(4) for s in range(4)]


def render(fr, night=False, bb=(-60, -110, 60, 20)):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    f = dict(fr); seed = f.pop('seed')
    Mai(seed, pa, **f).paint()
    surf.flush(); ch.NIGHT = False
    return surf, bb


def to_image(surf):
    w, h = surf.get_width(), surf.get_height()
    a = np.ndarray((h, w, 4), np.uint8, surf.get_data()).copy()
    im = Image.frombuffer('RGBa', (w, h), a[:, :, [2, 1, 0, 3]].tobytes(), 'raw', 'RGBa', 0, 1)
    return im.resize((w // SS, h // SS), Image.LANCZOS).convert('RGBA')


def atlas(outdir, tabpath):
    """16 frames, day and night, cropped and packed into one webp; writes the frame table json"""
    import json
    crops = []
    for night in (False, True):
        for k, fr in enumerate(FRAMES):
            surf, bb = render(fr, night)
            im = to_image(surf)
            a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            crops.append(('nd'[not night] + str(k), im.crop((x0, y0, x1, y1)), bb[0] + x0 / RS, bb[1] + y0 / RS))
    cols = 8; x = y = rowh = 0; pos = {}
    for k, (name, im, dx, dy) in enumerate(crops):
        if k and k % cols == 0: x = 0; y += rowh + 2; rowh = 0
        pos[name] = (x, y); x += im.width + 2; rowh = max(rowh, im.height)
    Wt = max(pos[n][0] + im.width for n, im, _, _ in crops); Ht = y + rowh
    sheet = Image.new('RGBA', (Wt, Ht), (0, 0, 0, 0)); table = {}
    for name, im, dx, dy in crops:
        sx, sy = pos[name]; sheet.paste(im, (sx, sy))
        table[name] = [sx, sy, im.width, im.height, round(dx, 2), round(dy, 2), round(im.width / RS, 2), round(im.height / RS, 2)]
    path = os.path.join(outdir, 'mai.webp')
    sheet.save(path, 'WEBP', quality=86, alpha_quality=100, method=6)
    open(tabpath, 'w').write(json.dumps(table, separators=(',', ':')))
    print(sheet.size, os.path.getsize(path))
    return table


if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == 'atlas':
        atlas(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else 'atlas.json')
    else:
        which = [int(x) for x in sys.argv[1].split(',')] if len(sys.argv) > 1 else range(len(FRAMES))
        night = len(sys.argv) > 2 and sys.argv[2] == 'n'
        tag = sys.argv[3] if len(sys.argv) > 3 else 'a'
        ims = [to_image(render(FRAMES[k], night)[0]) for k in which]
        w = sum(i.width for i in ims); h = ims[0].height
        sheet = Image.new('RGBA', (w, h), (40, 58, 52, 255) if night else (155, 191, 106, 255)); x = 0
        for im in ims:
            sheet.alpha_composite(im, (x, 0)); x += im.width
        sheet.save('/tmp/claude-0/g/mai_%s.png' % tag); print(sheet.size)
