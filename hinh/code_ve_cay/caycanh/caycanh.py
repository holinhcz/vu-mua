# The big flowers and ornamental plants of the build menu's "Hoa cỏ" tab for Nông Trại Nhỏ (v759): each one fills a
# whole tile (og item, b:1, vars 4), like the hibiscus. Built as small 3D models in flat game tones with the thin
# same-colour edge (../chuoi SOFT), the hibiscus/mai greens, the banana kit's camera, sun and night.
# Drawn from the real plants:
#   cc_bong_trang  bông trang (Ixora): a rounded shrub of dark glossy oblong leaves, flat-topped balls of many small
#                  4-petal star florets at the branch tips; seed = colour (đỏ cam, đỏ, cam vàng, hồng)
#   cc_lai         hoa lài (Jasminum sambac): a loose shrub of glossy oval leaves, small white double flowers and buds
#   cc_huong_duong hướng dương: a patch of 4-6 tall sunflowers, big heads turned to the sun
#   cc_luoi_ho     lưỡi hổ (Sansevieria): 2-4 clumps of stiff banded sword leaves with yellow margins
#   cc_nha_dam     nha đam (Aloe vera): a big rosette of thick spotted leaves and its pups
#   cc_xuong_rong  xương rồng tai thỏ (Opuntia microdasys): pads growing out of pads, glochid dots, red flowers
#   cc_sa          bụi sả (lemongrass): 2-3 tussocks of arching blue-green blades on pale purple stalks
# The patch kinds are built from the quarter-tile models of ../hoaco (hoaco.Mini) placed and scaled as sub-plants.
# Frames: <id><seed>, d (day) and n (night).
import math, os, sys
import numpy as np, cairo
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'co', 'dambut', 'hoaco'):
    sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM
import co
from co import ground_shadow, Plant
import dambut as db
import hoaco as hc
from hoaco import Mini, UP, shade, pick

MINI_KU = 58.0                     # the scale hoaco's models were drawn for
KU = 29.0 * 1.12                   # like the fern: a shade over the hibiscus scale
IDS = ['cc_bong_trang', 'cc_lai', 'cc_huong_duong', 'cc_luoi_ho', 'cc_nha_dam', 'cc_xuong_rong', 'cc_sa']


class Sub:
    """a painter seen through a move + scale: a hoaco model drawn as part of a bigger plant"""
    def __init__(self, pa, off, sc, wk=1.0):
        self._pa = pa; self._off = np.asarray(off, float); self._sc = sc
        self._us = sc * KU / MINI_KU * wk
        self.k = pa.k * sc

    def P(self, p): return self._pa.P(self._off + self._sc * np.asarray(p))
    def u(self, w): return self._pa.u(w * self._us)
    def __getattr__(self, n): return getattr(self._pa, n)


# ------------------------------------------------------------------ shrubs on the hibiscus dome
class Bush(db.Dambut, Mini):
    LEAF_L = 0.2; LEAF_W = 0.4
    PROF = [(0.0, 0.12), (0.1, 0.55), (0.25, 0.86), (0.45, 1.0), (0.65, 0.92), (0.82, 0.62), (0.94, 0.28), (1.0, 0.0)]
    DOME = [(1.0, 0.92, 0.64), (0.92, 1.0, 0.7), (1.04, 0.9, 0.6), (0.96, 0.96, 0.66)]
    NLEAF = 170
    DARK = 0.0

    def __init__(self, kind, seed, pa):
        self.pa = pa; self.seed = seed; self.kind = kind
        r = self.rng = self.r = np.random.default_rng(seed * 6151 + IDS.index(kind) * 977 + 41)
        self.items = []
        self.T = db.tones(); self.G = hc.greens()
        q = seed % 4
        self.ra, ry, self.rb = self.DOME[q]
        self.ry = self.ra * ry
        self.ce = np.array([[0.02, 0.0], [-0.03, 0.02], [0.03, -0.02], [0.0, 0.03]][q] + [self.rb * 0.72 + 0.14])
        self.lumps = [(nv(r.normal(0, 1, 3)), r.uniform(1.6, 2.6), r.uniform(0, 6.28), r.uniform(0.05, 0.09)) for _ in range(5)]
        self._stems(r)
        self._mass()
        self._leaves(r)
        self._flowers(r)

    def _leaves(self, r):
        n = self.NLEAF; ga = math.pi * (3 - math.sqrt(5))
        spots = []
        for i in range(n):
            zz = 1 - 2 * (i + 0.5) / n; rr = math.sqrt(max(0.0, 1 - zz * zz))
            if zz < -0.5: continue
            d = np.array([rr * math.cos(i * ga), rr * math.sin(i * ga), zz])
            f = r.uniform(0.93, 1.03) if i % 4 else r.uniform(0.8, 0.9)
            spots.append(self.env(d, f))
        self.nmain = len(spots)
        for k in range(7):
            az = r.uniform(-0.3, math.pi + 0.3); zz = r.uniform(0.15, 0.8); rr = math.sqrt(1 - zz * zz)
            spots.append(self.env(np.array([rr * math.cos(az), rr * math.sin(az), zz]), r.uniform(1.05, 1.12)))
        self.spots = spots
        for p in spots:
            self._cluster(r, p)

    def _cluster(self, r, c):
        """a whorl of 4-6 entire glossy leaves at one spot of the dome (dambut's, with this shrub's leaf)"""
        T = self.T; pa = self.pa
        ns = self.norm_at(c)
        nrm0 = nv(ns + UP * 0.9)
        t1 = np.cross(nrm0, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(nrm0, t1)
        hcz = (c[2] - self.ce[2]) / self.rb
        sun = float(ns @ LIGHT)
        ao = 0.78 + 0.22 * max(-1.0, min(1.0, hcz + 0.1))
        if math.dist(c, self.ce) < 0.88 * min(self.ra, self.rb * 1.4): ao -= 0.12
        nl = int(r.integers(4, 7)); az0 = r.uniform(0, 2 * math.pi)
        leaves = []
        for k in range(nl):
            az = az0 + k * 2 * math.pi / nl + r.normal(0, 0.25)
            A = math.cos(az) * t1 + math.sin(az) * t2
            el = r.uniform(0.05, 0.55)
            ld = nv(A * math.cos(el) + nrm0 * math.sin(el) - UP * 0.15)
            sd = nv(np.cross(nrm0, ld))
            Ll = self.LEAF_L * r.uniform(0.85, 1.12); Wl = Ll * self.LEAF_W
            pt = c + ld * 0.02
            Lp_, Rp_ = [], []
            for t, w in self.PROF:
                q = pt + ld * Ll * t - UP * Ll * 0.14 * t * t
                Lp_.append(q + sd * Wl * 0.5 * w); Rp_.append(q - sd * Wl * 0.5 * w)
            poly = Lp_ + Rp_[::-1]
            n = nv(np.cross(ld, sd))
            if n @ nrm0 < 0: n = -n
            topv = n @ TOCAM > 0
            lam = float((n if topv else -n) @ LIGHT)
            v = (0.55 + 0.45 * max(-0.3, lam)) * ao + 0.13 * sun - 0.05 - self.DARK
            leaves.append(dict(poly=poly, top=topv, v=v, mid=pt + ld * Ll * 0.5, rib=(pt, pt + ld * Ll * 0.86 - UP * Ll * 0.1),
                               gloss=topv and lam > 0.4))
        vm = float(np.mean([z['v'] for z in leaves]))
        for z in leaves: z['v'] = 0.55 * vm + 0.45 * z['v']
        leaves.sort(key=lambda z: depth(z['mid']))
        def col_of(z):
            v = z['v']; ramp = T['green']
            if not z['top']: return T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            return ramp[0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4]
        cols = [col_of(z) for z in leaves]
        def draw(leaves=leaves, cols=cols):
            P = pa.P
            for z, col in zip(leaves, cols):
                poly = [P(q) for q in z['poly']]
                pa.fill(poly, col); pa.soft_edge(poly, col)
                pa.line([P(z['rib'][0]), P(z['rib'][1])], mixc(col, C('#d8e6a0'), 0.3), pa.u(0.2), 0.75)
                if z['gloss']:
                    a3, b3 = z['rib']; m3 = a3 + (b3 - a3) * 0.3; e3 = a3 + (b3 - a3) * 0.62
                    pa.line([P(m3), P(e3)], mixc(col, (1, 1, 1), 0.3), pa.u(0.45), 0.55)
        self.items.append((c, draw))

    def pick_spots(self, r, n, gap, zmin=0.25, vmin=0.1):
        cand = []
        for p in self.spots[:self.nmain]:
            nn = self.norm_at(p); vis = nn @ TOCAM
            if vis < vmin or p[2] < zmin: continue
            cand.append((vis * 0.6 + r.uniform(0, 0.7), p, nn))
        cand.sort(key=lambda z: -z[0])
        out = []
        for s, p, nn in cand:
            if len(out) >= n: break
            sp = np.array(self.pa.P(p)) / self.pa.k
            if any(np.linalg.norm(sp - q) < gap for q, _, _ in out): continue
            out.append((sp, p, nn))
        return [(p, nn) for _, p, nn in out]

    def paint(self):
        self.shadow()
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()


IXORA = [('#a8200e', '#d23a14', '#ee5a22', '#ff8446'),      # đỏ cam, the common hedge one
         ('#980c1a', '#c41a24', '#e2363a', '#f86060'),      # đỏ
         ('#c86a08', '#e88c12', '#f8aa26', '#ffc85a'),      # cam vàng
         ('#b8326a', '#dc5088', '#f074a4', '#ff9cc2')]      # hồng


class BongTrang(Bush):
    LEAF_L = 0.2; LEAF_W = 0.36; DARK = 0.22

    def _flowers(self, r):
        cols = tuple(C(c) for c in IXORA[self.seed % 4])
        n = [10, 11, 10, 12][self.seed % 4]
        for p, nn in self.pick_spots(r, n, 0.4, zmin=0.2, vmin=0.05):
            self._ball(r, p, nn, cols)

    def _ball(self, r, p, nn, cols):
        """a flat-topped ball of florets at a branch tip, a little out of the leaves"""
        f = nv(nn + UP * 1.1 + r.normal(0, 0.15, 3))
        rc = 0.18 * r.uniform(0.9, 1.1)
        c = p + nn * 0.05 + f * 0.02
        # the ball's own body (the florets' tubes), its far side darker
        self.blob(c, rc * 0.8, rc * 0.8, rc * 0.45, (mixc(cols[0], C('#5a0a08'), 0.25), cols[0], cols[1]), key=0.03)
        u, v = hc.basis(f)
        m = 20; ga = math.pi * (3 - math.sqrt(5))
        for i in range(m):
            t = (i + 0.5) / m
            th = math.acos(1 - t * (1 - math.cos(math.radians(82))))     # the cap down to 82 deg from its top
            ph = i * ga
            d = math.cos(th) * f + math.sin(th) * (math.cos(ph) * u + math.sin(ph) * v)
            if d @ TOCAM < -0.15: continue
            q = c + d * rc * (0.62 if th < 0.9 else 0.72) + f * rc * 0.12
            self.flower(q, nv(d + f * 0.6), 4, 0.1 * r.uniform(0.9, 1.08), 0.06, cols, eye=C('#ffe2a0'), eye_r=0.006,
                        cup=-0.05, ph0=r.uniform(0, 6.28), key=0.06 + 0.02 * float(d @ TOCAM),
                        prof=[(0.0, 0.2), (0.3, 0.85), (0.6, 1.0), (0.85, 0.6), (1.0, 0.0)])
        # a few closed buds, little red stars not yet open
        for k in range(4):
            a = r.uniform(0, 6.28); q = c + f * rc * 0.62 + (math.cos(a) * u + math.sin(a) * v) * rc * 0.3
            self.blob(q, 0.011, 0.011, 0.016, cols[:3], key=0.1)


class Lai(Bush):
    LEAF_L = 0.17; LEAF_W = 0.58; DARK = 0.1
    PROF = [(0.0, 0.15), (0.12, 0.6), (0.3, 0.92), (0.48, 1.0), (0.66, 0.86), (0.84, 0.5), (1.0, 0.0)]
    DOME = [(0.9, 0.94, 0.6), (0.84, 1.0, 0.66), (0.95, 0.9, 0.56), (0.88, 0.96, 0.62)]
    NLEAF = 150

    def _flowers(self, r):
        cols = (C('#cfd3da'), C('#e6e9ee'), C('#f7f8fa'), C('#ffffff'))
        bud = (C('#d6d8d0'), C('#eceee6'), C('#ffffff'))
        n = [15, 17, 16, 18][self.seed % 4]
        for p, nn in self.pick_spots(r, n, 0.24, zmin=0.18, vmin=0.0):
            f0 = nv(nn + UP * 0.8)
            u, v = hc.basis(f0)
            k = int(r.integers(1, 4))
            for j in range(k):
                a = r.uniform(0, 6.28); q = p + nn * 0.05 + (math.cos(a) * u + math.sin(a) * v) * (0.05 if k > 1 else 0)
                f = nv(f0 + (math.cos(a) * u + math.sin(a) * v) * 0.35 + r.normal(0, 0.12, 3))
                if j == 2 or (j == 1 and r.uniform() < 0.3):
                    self.blob(q + f * 0.02, 0.024, 0.024, 0.046, bud, key=0.1)      # a pointed white bud
                else:
                    self.flower(q, f, 8, 0.1, 0.065, cols, eye=C('#f0e4a0'), eye_r=0.009, cup=0.35, layers=2,
                                ph0=r.uniform(0, 6.28), key=0.1)


# ------------------------------------------------------------------ patches of scaled hoaco models
class Big(Plant):
    def __init__(self, kind, seed, pa):
        self.pa = pa; self.kind = kind; self.seed = seed
        self.r = np.random.default_rng(seed * 4241 + IDS.index(kind) * 331 + 5)
        self.items = []; self.R = 0.7
        getattr(self, '_' + kind)(self.r)

    def sub(self, kind, seed, off, sc, cls=Mini, wk=1.0):
        off = np.array([off[0], off[1], 0.0])
        m = cls(kind, seed, Sub(self.pa, off, sc, wk))
        self.items += [(off + sc * np.asarray(p), fn) for p, fn in m.items]
        return m

    def ring(self, r, n, R0, jit=0.25):
        a0 = r.uniform(0, 6.28)
        return [(math.cos(a0 + k * 6.283 / n + r.normal(0, jit)) * R0 * r.uniform(0.8, 1.15),
                 math.sin(a0 + k * 6.283 / n + r.normal(0, jit)) * R0 * r.uniform(0.8, 1.15) * 0.85) for k in range(n)]

    def _cc_huong_duong(self, r):
        n = [5, 4, 6, 5][self.seed % 4]
        pos = [(0.0, 0.0)] + self.ring(r, n - 1, 0.34)
        # back ones taller: sort far (small y) first and lift them
        for k, (x, y) in enumerate(pos):
            sc = 2.1 * r.uniform(0.92, 1.08) * (1.06 if y < 0 else 0.94)
            self.sub('h_huong_duong', self.seed * 10 + k, (x, y), sc)
        for x, y in self.ring(r, 5, 0.3):        # a few low leaves round the feet
            self.sub('c_xanh', int(r.integers(0, 99)), (x, y), 1.6)
        self.R = 0.62

    def _cc_luoi_ho(self, r):
        n = [4, 3, 5, 4][self.seed % 4]
        pos = [(0.0, -0.06)] + self.ring(r, n - 1, 0.4)
        mx = sum(p[0] for p in pos) / len(pos); my = sum(p[1] for p in pos) / len(pos)
        pos = [(x - mx, y - my - 0.03) for x, y in pos]     # v831: centred on its shadow
        for k, (x, y) in enumerate(pos):
            self.sub('k_luoi_ho', self.seed * 10 + k, (x, y), (3.2 if k == 0 else 2.6) * r.uniform(0.92, 1.08), wk=0.6)
        self.R = 0.68

    def _cc_nha_dam(self, r):
        self.sub('k_nha_dam', self.seed, (0.0, -0.04), 3.7 * r.uniform(0.95, 1.05))
        n = [2, 3, 2, 3][self.seed % 4]
        for k, (x, y) in enumerate(self.ring(r, n, 0.66)):
            self.sub('k_nha_dam', self.seed * 10 + k + 1, (x, y), r.uniform(1.3, 1.7))
        self.R = 0.72

    def _cc_sa(self, r):
        n = [3, 2, 3, 2][self.seed % 4]
        pos = [(0.0, -0.05)] + self.ring(r, n - 1, 0.26)
        mx = sum(p[0] for p in pos) / len(pos); my = sum(p[1] for p in pos) / len(pos)
        pos = [(x - mx, y - my - 0.03) for x, y in pos]     # v831: centred on its shadow
        for k, (x, y) in enumerate(pos):
            self.sub('k_sa', self.seed * 10 + k, (x, y), (1.9 if k == 0 else 1.6) * r.uniform(0.94, 1.06))
        self.R = 0.6

    def _cc_xuong_rong(self, r):
        """pads out of pads, 3 tiers; seeds 1 and 3 have a second small plant beside"""
        pa = self.pa
        pal = [C('#3a7436'), C('#4a8a42'), C('#5ea04e'), C('#78b660')]
        dotc = C('#ece4ac')
        tips = []
        def pad(base, up, R, lvl):
            c = base + up * R
            side = np.cross(up, np.array([0.0, 1.0, 0.0]))
            side = nv(side) if np.linalg.norm(side) > 1e-3 else np.array([1.0, 0, 0])
            nrm = nv(np.cross(side, up))
            if nrm @ TOCAM < 0: nrm = -nrm
            # a pad is thick: a lit face and a darker rim on the far side
            pts3 = [c + up * R * math.sin(t) + side * R * 0.74 * math.cos(t) for t in np.linspace(0, 2 * math.pi, 36, endpoint=False)]
            rim3 = [q - nrm * R * 0.12 for q in pts3]
            v = shade(nrm, 0.35, 0.6)
            col = pick(pal, v); dk = pick(pal, v - 0.3)
            m = max(3, int(R / 0.07))
            dots = [c + up * R * uu * 0.8 + side * R * 0.55 * ww for uu in np.linspace(-0.82, 0.82, m) for ww in np.linspace(-0.82, 0.82, max(2, m - 1))
                    if uu * uu + ww * ww < 0.95]
            hi = [c + up * R * (0.35 + 0.35 * math.sin(t)) + side * R * (-0.3 + 0.3 * math.cos(t)) for t in np.linspace(0, 2 * math.pi, 18, endpoint=False)]
            def draw():
                P = pa.P
                rim = [P(q) for q in rim3]; pa.fill(rim, dk); pa.soft_edge(rim, dk)
                poly = [P(q) for q in pts3]; pa.fill(poly, col); pa.soft_edge(poly, col)
                pa.ctx.save(); pa.path(poly); pa.ctx.clip()
                pa.fill([P(q) for q in hi], mixc(col, pal[3], 0.5), seam=False)
                pa.ctx.restore()
                for q in dots:
                    x, y = P(q); pa.ctx.new_path(); pa.ctx.arc(x, y, pa.u(0.5), 0, 2 * math.pi)
                    pa.ctx.set_source_rgb(*dotc); pa.ctx.fill()
            self.items.append((c + TOCAM * 0.02 * lvl, draw))
            return c + up * R * 0.92, side
        def plant(base, R0, tiers):
            az0 = r.uniform(-0.3, 0.3)
            top, side = pad(base, nv(np.array([math.sin(az0) * 0.25, 0.06, 1.0])), R0, 0)
            level = [(top, side, R0, az0)]
            for t in range(1, tiers):
                nxt = []
                for tp, sd, Rp, az in level:
                    kids = int(r.integers(1, 3)) if t > 1 else 2
                    for j in range(kids):
                        ang = (-0.75 + 1.5 * j / max(1, kids - 1) if kids > 1 else r.uniform(-0.4, 0.4)) + r.normal(0, 0.15)
                        up = nv(np.array([math.sin(ang), r.uniform(-0.25, 0.25), math.cos(ang)]))
                        Rk = Rp * r.uniform(0.7, 0.82)
                        b = tp - UP * Rk * 0.3 + sd * ang * Rp * 0.35
                        q, s2 = pad(b, up, Rk, t)
                        nxt.append((q, s2, Rk, ang))
                level = nxt; tips.extend(q for q, _, _, _ in nxt)
            return top
        plant(np.zeros(3), 0.42, 3)
        if self.seed % 2:
            plant(np.array([0.56, 0.3, 0.0]), 0.24, 2)
        cols = (C('#b0142a'), C('#d42a36'), C('#ee4a46'), C('#ff7a68'))
        for k, tp in enumerate(tips[:[3, 4, 2, 5][self.seed % 4]]):
            self.flower(tp, nv(np.array([0.1, 0.35, 1.0])), 9, 0.08, 0.055, cols, eye=C('#f2d24a'), eye_r=0.014, cup=0.6, ph0=k, key=0.12)
        self.R = 0.62

    # flowers come from hoaco's model
    flower = Mini.flower
    disc = Mini.disc

    def shadow(self):
        ground_shadow(self.pa, 0.0, 0.02, self.R, self.R * 0.86, 0.14)
        ground_shadow(self.pa, 0.0, 0.0, self.R * 0.5, self.R * 0.44, 0.1)


class Frame:
    def __init__(self, pa, kind, seed):
        cls = {'cc_bong_trang': BongTrang, 'cc_lai': Lai}.get(kind, Big)
        self.m = cls(kind, seed, pa)
    def paint(self): self.m.paint()


FRAMES = [dict(key='%s%d' % (k, s), kind=k, seed=s) for k in IDS for s in range(4)]
BB = (-58, -118, 58, 26)

co.KU = KU
if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'atlas':
        co.atlas(Frame, FRAMES, BB, sys.argv[2], 'caycanh.webp', sys.argv[3], cols=10)
    else:
        from PIL import Image
        sel = sys.argv[1].split(',') if len(sys.argv) > 1 and sys.argv[1] != 'all' else IDS
        night = len(sys.argv) > 2 and sys.argv[2] == 'n'
        rows = [[co.to_image(co.render(Frame, dict(kind=k, seed=s), BB, night)) for s in range(4)] for k in sel]
        w, h = rows[0][0].size
        o = Image.new('RGBA', (w * 4, h * len(rows)), (40, 58, 52, 255) if night else (176, 168, 112, 255))
        for j, ims in enumerate(rows):
            for i, im in enumerate(ims): o.alpha_composite(im, (i * w, j * h))
        o.save(sys.argv[3] if len(sys.argv) > 3 else '/tmp/claude-0/g/caycanh.png'); print(o.size)
