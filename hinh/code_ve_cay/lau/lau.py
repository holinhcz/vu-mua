# Reeds (cỏ lau) for Nông Trại Nhỏ: the tall wild cane grass of the Mekong delta's banks, in flower, its silky white
# plumes bending in the wind. Built as a small 3D model and painted in flat game tones with the thin same-colour edge
# of the other new plants (ch.SOFT), with the banana kit's camera, sun and night (../chuoi); grass blades from ../co.
# A clump: a fountain of long narrow arching leaves at the foot; 6-9 tall slim canes, all leaning a little the same
# way, each with a node or two and a long leaf peeling off it; on top of each cane a long plume (a feather of silk)
# that bends over with the wind, lit white on the sunny half and a soft beige-grey on the other, silk strands showing.
import math, os, sys
import numpy as np, cairo
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'co'): sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM
import co
from co import blade, ground_shadow

UP = np.array([0, 0, 1.0])


def tones():
    return dict(
        leaf=[C('#2d6a33'), C('#3a7c3a'), C('#4b8f42'), C('#61a24c'), C('#7cb75a'), C('#98c96a')],
        dry=[C('#8f8048'), C('#a89957'), C('#c0b16a'), C('#d4c784')],
        cane=dict(lo=C('#5f8a3e'), hi=C('#a7a462'), node=C('#6f6438')),
        plume=dict(sh=C('#bcb1a3'), mid=C('#e0d9cb'), lit=C('#f6f2e8'), hi=C('#fffefa'),
                   silk=C('#d2c8b2'), silk_lit=C('#fffdf6'), base=C('#a99c86')),
    )


class Lau(co.Plant):
    def __init__(self, seed, pa):
        self.pa = pa; self.seed = seed
        r = np.random.default_rng(seed * 5153 + 41)
        self.items = []
        T = self.T = tones()
        q = seed % 4
        ncane = [9, 10, 8, 11][q]
        wind = math.radians([10, 170, -15, 185][q] + r.normal(0, 8))      # which way the clump leans
        self.wd = np.array([math.cos(wind), math.sin(wind) * 0.6, 0.0])
        self.R = 0.5
        # the leafy foot: long narrow leaves standing up and arching over, a few dry ones
        nb = [36, 40, 34, 42][q]
        dry = set(r.choice(nb, 3, replace=False).tolist())
        for j in range(nb):
            az = 2 * math.pi * (j + r.uniform(-0.4, 0.4)) / nb
            ring = r.uniform(0.2, 1)
            base = np.array([math.cos(az) * 0.09 * ring, math.sin(az) * 0.07 * ring, 0.0])
            outer = r.uniform(0, 1) ** 0.8
            el0 = math.radians(84 - 20 * outer + r.normal(0, 3))
            L = (1.0 + 0.55 * outer) * r.uniform(0.88, 1.1)
            droop = math.radians(35 + 75 * outer) * r.uniform(0.85, 1.15)
            # leaves on the lee side lean with the wind a little more
            az2 = az + 0.25 * math.sin(wind - az)
            blade(pa, self.items, base, az2, el0, L, r.uniform(0.05, 0.06), droop, T['dry'] if j in dry else T['leaf'], r,
                  ao_in=(1 - outer) * 0.7, twist=r.normal(0, 0.35), fold=r.uniform(0.4, 0.6), key_push=0.12 * outer)
        # canes
        for k in range(ncane):
            self._cane(r, k, ncane)

    def _cane(self, r, k, n):
        T = self.T; pa = self.pa; Cn = T['cane']
        a = 2 * math.pi * (k + r.uniform(-0.3, 0.3)) / n
        b0 = np.array([math.cos(a) * 0.07, math.sin(a) * 0.05, 0.0])
        H = r.uniform(2.05, 2.55)
        spread = np.array([math.cos(a), math.sin(a) * 0.6, 0.0]) * r.uniform(0.12, 0.3)
        lean = self.wd * r.uniform(0.18, 0.36) + spread
        ts = np.linspace(0, 1, 16)
        pts = [b0 + lean * (t ** 1.8) + UP * H * t for t in ts]
        top = pts[-1]
        # a leaf or two peeling off the cane at a node
        nodes = sorted(r.uniform(0.18, 0.55, int(r.integers(1, 3))).tolist())
        for zf in nodes:
            i = int(zf * 15); p = pts[i]
            az = math.atan2(*(self.wd[1::-1])) + r.normal(0, 0.9)
            blade(pa, self.items, p, az, math.radians(r.uniform(40, 62)), r.uniform(0.7, 0.95), 0.032,
                  math.radians(r.uniform(70, 110)), T['leaf'], r, ao_in=0.1, fold=0.5, zmin=0.08)
        def draw():
            P = pa.P
            sp = [P(q) for q in pts]
            # lower cane green, ripening to straw up toward the plume
            # a thin edge a shade darker, then the cane: green low down, straw toward the plume
            segs = [(0, 6), (5, 9), (8, 12), (11, 16)]
            for k, (i0, i1) in enumerate(segs):
                col = mixc(Cn['lo'], Cn['hi'], k / 3)
                pa.line(sp[i0:i1], ch.soft(col), pa.u(0.85 - 0.06 * k + 0.3))
            for k, (i0, i1) in enumerate(segs):
                col = mixc(Cn['lo'], Cn['hi'], k / 3)
                pa.line(sp[i0:i1], col, pa.u(0.85 - 0.06 * k))
            for zf in nodes:
                i = int(zf * 15); x, y = P(pts[i])
                pa.line([(x - pa.u(0.5), y), (x + pa.u(0.5), y)], Cn['node'], pa.u(0.3))
        self.items.append((pts[6] - TOCAM * 0.1, draw))
        self._plume(r, top, nv(pts[-1] - pts[-2]))

    def _plume(self, r, top, t0):
        """a long silky plume streaming downwind, built of fine wisps of silk like the barbs of a feather: they leave
        the stem at a slant toward the tip, the ones at the edge part a little so the plume's outline is loose and
        fluffy; white on the sunny side, a soft beige-grey on the other"""
        T = self.T; pa = self.pa; Pl = T['plume']
        L = r.uniform(0.62, 0.76)
        bend = r.uniform(0.6, 1.0)
        side = nv(self.wd - t0 * (self.wd @ t0))
        m = 24
        ax = []; p = top.copy()
        for i in range(m + 1):
            s = i / m
            d = nv(t0 * math.cos(bend * s ** 1.4) + nv(side - UP * 0.2) * math.sin(bend * s ** 1.4))
            ax.append(p.copy()); p = p + d * L / m
        W = r.uniform(0.1, 0.115)
        rr = np.random.default_rng(int(r.integers(1, 1 << 30)))
        wisps = []
        for k in range(40):
            s0 = min(0.8, 0.03 + (k + rr.uniform(0, 1)) / 40 * 0.78)
            sd = 1 if k % 2 else -1
            wisps.append((s0, sd, rr.uniform(0.2, 0.34), rr.uniform(0.75, 1.15), rr.uniform(0.0, 1.0)))
        def draw():
            P = pa.P; c = pa.ctx
            A = [np.array(P(q)) for q in ax]; n = len(A)
            def at(s):
                s = min(1.0, max(0.0, s))
                f = s * (n - 1); i = min(int(f), n - 2); fr = f - i
                d = A[i + 1] - A[i]; d = d / (np.linalg.norm(d) + 1e-9)
                return A[i] * (1 - fr) + A[i + 1] * fr, d, np.array([-d[1], d[0]])
            prof = lambda s: (math.sin(math.pi * min(1.0, 0.02 + s * 0.98)) ** 0.75) * (1 - 0.45 * s ** 1.4)
            Wp = pa.u(W * 29)
            sunv = np.array([-0.6, -0.8])
            q, d, nr = at(0.4)
            sg = 1 if nr @ sunv > 0 else -1               # the side of the stem that faces the sun
            def wisp(s0, sd, la, ln, tone, near):
                # a long slim strand of silk: it leaves the stem, runs along toward the tip and out to the edge
                q0, d0, n0 = at(s0)
                s1 = min(1.0, s0 + la)
                q1, d1, n1 = at(s1)
                e = q1 + n1 * sd * Wp * prof(s1) * ln
                m = at((s0 + s1) / 2)
                mid = m[0] + m[2] * sd * Wp * prof((s0 + s1) / 2) * ln * 0.85
                pts = [(1 - t) ** 2 * q0 + 2 * (1 - t) * t * mid + t * t * e for t in np.linspace(0, 1, 9)]
                w0 = pa.u(1.15 if near else 1.3)
                Lp, Rp = [], []
                for i, p2 in enumerate(pts):
                    t = i / 8
                    dd = pts[min(i + 1, 8)] - pts[max(i - 1, 0)]; dd = dd / (np.linalg.norm(dd) + 1e-9)
                    nn = np.array([-dd[1], dd[0]]); w = w0 * (1 - t) ** 0.7
                    Lp.append(tuple(p2 + nn * w)); Rp.append(tuple(p2 - nn * w))
                poly = Lp + Rp[::-1]
                if near: col = Pl['hi'] if tone > 0.6 else Pl['lit']
                else: col = Pl['sh'] if tone > 0.4 else Pl['mid']
                pa.fill(poly, col)
                if not near: pa.soft_edge(poly, col, w=0.16)
            # the far (shaded) strands, the plume's body, then the sunny strands over them
            for s0, sd, la, ln, tone in wisps:
                if sd != sg: wisp(s0, sd, la, ln, tone, False)
            body_l, body_r = [], []
            for s in np.linspace(0, 1, 40):
                q, d, nr = at(s); w = Wp * 0.6 * prof(s)
                body_l.append(tuple(q + nr * w)); body_r.append(tuple(q - nr * w))
            tip = tuple(A[-1] + (A[-1] - A[-2]) / (np.linalg.norm(A[-1] - A[-2]) + 1e-9) * pa.u(1.6))
            body = body_l + [tip] + body_r[::-1]
            pa.fill(body, Pl['mid'])
            pa.soft_edge(body, Pl['mid'], w=0.16)
            for s0, sd, la, ln, tone in wisps:
                if sd == sg: wisp(s0, sd, la, ln, tone, True)
            # a few strands lying along the middle catch the light
            for s0, sd, la, ln, tone in wisps[::5]:
                wisp(s0, sg, la * 1.2, 0.3, 1.0, True)
            pa.line([tuple(q) for q in A[:3]], Pl['base'], pa.u(0.4))
        self.items.append((top + TOCAM * 0.4, draw))

    def shadow(self):
        ground_shadow(self.pa, 0.0, 0.0, self.R + 0.12, self.R, 0.15)
        ground_shadow(self.pa, 0.0, 0.0, 0.26, 0.22, 0.12)


FRAMES = [dict(key=str(s), seed=s) for s in range(4)]
BB = (-50, -100, 50, 22)

if __name__ == '__main__':
    co.main(Lau, FRAMES, BB, 'lau.webp', 'lau')
