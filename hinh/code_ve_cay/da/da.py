# Village banyan trees (cây đa đầu làng) for Nông Trại Nhỏ, built as small 3D models and painted in flat game tones
# with the thin same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun and night.
# A tree: a massive trunk of several stems grown into each other (each one bends out into a main limb), surface roots
# snaking over the ground, a wide crown built as tiers of leaf clumps (a skirt round the bottom, a middle ring, a top),
# every clump a dark inner mass covered in glossy oval leaves; a curtain of aerial roots hanging under the crown, a
# few of them grown into pillar roots that reach the ground; the red cloth tied round the trunk and a small stone
# stand with an incense bowl and three burning sticks at its foot.
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
SQ = math.sqrt(0.5)


def tones():
    return dict(
        green=[C('#235d2b'), C('#2e7233'), C('#3d8a3b'), C('#53a346'), C('#71bd57')],
        und=[C('#30613a'), C('#3e7340'), C('#50874a')],
        inner=C('#1a4522'),
        bark=dict(lit=C('#a8957e'), mid=C('#83705c'), dk=C('#5c4c3e'), fis=C('#4f4134')),
        aroot=dict(lit=C('#a48d72'), mid=C('#7c6852'), tip=C('#caa688')),
        sash=dict(lit=C('#ee4c38'), mid=C('#d2302a'), dk=C('#9e1f1d'), fold=C('#8a1a18')),
        stone=dict(top=C('#d8cdb5'), left=C('#bcae94'), right=C('#988c76'), line=C('#8a7f6a')),
        bowl=dict(lit=C('#9a6538'), mid=C('#7a4d2a'), dk=C('#57361e')), ash=C('#ece4cf'),
        stick=C('#b8402a'),
    )


def bez(p0, p1, p2, p3, t):
    a = 1 - t
    return a * a * a * p0 + 3 * a * a * t * p1 + 3 * a * t * t * p2 + t * t * t * p3


class Da:
    """seed picks the shape; seed & 1 puts the incense stand on the right instead of the left"""
    def __init__(self, seed, pa):
        self.pa = pa; self.seed = seed
        r = self.rng = np.random.default_rng(seed * 7919 + 13)
        self.items = []
        self.T = tones()
        q = seed % 4
        self.side = 1 if seed % 2 else -1
        self.ce = np.array([[0.04, -0.05], [-0.06, -0.02], [0.02, -0.08], [-0.03, -0.04]][q] + [3.02])
        self.ra = [1.96, 2.0, 1.92, 1.98][q]
        self.ry = self.ra * 0.9
        self.rb = 1.3
        self._clumps(r)
        self._trunk(r)
        self._ground_roots(r)
        self._aerial(r)
        self._sash()
        self._altar()
        for c in self.cl: self._clump_leaves(r, c)

    # ------------------------------------------------------------- crown layout
    def _clumps(self, r):
        ce, ra, ry, rb = self.ce, self.ra, self.ry, self.rb
        cl = []
        n0 = 7
        az0 = math.pi / 2 + math.pi / n0 + r.normal(0, 0.06)      # a notch in front shows the trunk going up
        for k in range(n0):
            az = az0 + k * 2 * math.pi / n0 + r.normal(0, 0.1)
            d = 0.72 * r.uniform(0.95, 1.05)
            c = ce + np.array([math.cos(az) * ra * d, math.sin(az) * ry * d, -0.42 * rb + r.normal(0, 0.05)])
            rc = r.uniform(0.8, 0.92)
            cl.append(dict(c=c, rc=rc, rz=rc * 0.56, tier=0))
        n1 = 5
        az1 = r.uniform(0, 2 * math.pi)
        for k in range(n1):
            az = az1 + k * 2 * math.pi / n1 + r.normal(0, 0.12)
            d = 0.4 * r.uniform(0.9, 1.1)
            c = ce + np.array([math.cos(az) * ra * d, math.sin(az) * ry * d, 0.14 * rb + r.normal(0, 0.05)])
            rc = r.uniform(0.86, 0.98)
            cl.append(dict(c=c, rc=rc, rz=rc * 0.6, tier=1))
        n2 = [3, 2, 3, 2][self.seed % 4]
        az2 = r.uniform(0, 2 * math.pi)
        for k in range(n2):
            az = az2 + k * 2 * math.pi / n2
            d = 0.14 if n2 > 1 else 0.0
            c = ce + np.array([math.cos(az) * ra * d, math.sin(az) * ry * d, 0.56 * rb + r.normal(0, 0.04)])
            rc = r.uniform(0.74, 0.86)
            cl.append(dict(c=c, rc=rc, rz=rc * 0.62, tier=2))
        for c in cl:
            c['lumps'] = [(nv(r.normal(0, 1, 3)), r.uniform(1.4, 2.4), r.uniform(0, 6.28), r.uniform(0.05, 0.08)) for _ in range(4)]
            c['tv'] = r.uniform(-0.035, 0.035)
        self.cl = cl

    def lump(self, c, d):
        return 1.0 + sum(a * math.cos(fr * (d @ kk) * math.pi + ph) for kk, fr, ph, a in c['lumps'])

    def env(self, c, d, f=1.0):
        return c['c'] + np.array([d[0] * c['rc'], d[1] * c['rc'], d[2] * c['rz']]) * f * self.lump(c, d)

    def inside(self, c, p, f=0.92):
        e = (p - c['c']) / np.array([c['rc'], c['rc'], c['rz']])
        return np.linalg.norm(e) < f

    # ------------------------------------------------------------- wood
    def _tube(self, pts, rads, key, fiss=0, r=None, lit=True, col=None, soft=True):
        pa = self.pa; T = self.T
        fl = []
        if fiss and r is not None:
            for _ in range(fiss):
                i0 = int(r.integers(0, max(1, len(pts) // 3))); i1 = int(r.integers(len(pts) // 2, len(pts)))
                fl.append((i0, i1, r.uniform(-0.6, 0.6), r.uniform(0.45, 0.75)))
        def draw():
            P = pa.P; B = T['bark']
            c0 = B['mid'] if col is None else col
            sp = np.array([P(q) for q in pts]); n = len(sp)
            Lp, Rp, Cn = [], [], []
            ul = None
            for i in range(n):
                a = sp[max(0, i - 1)]; b = sp[min(n - 1, i + 1)]
                d = nv(b - a); nrm = np.array([-d[1], d[0]])
                w = rads[i] * pa.k
                Lp.append(sp[i] + nrm * w); Rp.append(sp[i] - nrm * w)
                off = SLIGHT - (SLIGHT @ d) * d
                if np.linalg.norm(off) > 0.25 or ul is None: ul = nv(off) if np.linalg.norm(off) > 1e-6 else nrm
                Cn.append((sp[i], nrm, w, ul))
            body = [tuple(q) for q in Lp] + [tuple(q) for q in Rp[::-1]]
            pa.fill(body, c0)
            pa.ctx.save(); pa.path(body); pa.ctx.clip()
            if lit:
                pa.line([tuple(p + u * w * 0.55) for (p, nr, w, u) in Cn], B['lit'], max(pa.u(0.4), np.mean(rads) * 0.62 * pa.k), 0.9)
                pa.line([tuple(p - u * w * 0.72) for (p, nr, w, u) in Cn], B['dk'], max(pa.u(0.4), np.mean(rads) * 0.5 * pa.k), 0.85)
            for (i0, i1, f, al) in fl:
                ln = [tuple(Cn[i][0] + Cn[i][1] * Cn[i][2] * f) for i in range(i0, i1)]
                if len(ln) > 1: pa.line(ln, B['fis'], pa.u(0.32), al)
            pa.ctx.restore()
            if soft:
                pa.soft_edge([tuple(q) for q in Lp], c0, close=False); pa.soft_edge([tuple(q) for q in Rp], c0, close=False)
        self.items.append((key, draw))

    def _trunk(self, r):
        q = self.seed % 4
        n = [5, 6, 5, 6][q]
        a0 = r.uniform(0, 2 * math.pi)
        # the trunk's stems: each goes up, then bends out into a main limb to a clump at the bottom of the crown
        tgt = [c for c in self.cl if c['tier'] == 0] + [c for c in self.cl if c['tier'] == 1]
        used = set()
        self.stems = []
        for i in range(n):
            a = a0 + i * 2 * math.pi / n + r.normal(0, 0.15)
            ro = r.uniform(0.2, 0.3)
            B = np.array([math.cos(a) * ro, math.sin(a) * ro, 0.0])
            r0 = r.uniform(0.2, 0.25)
            # the clump most in this stem's direction
            best, bs = None, -9
            for j, c in enumerate(tgt):
                if j in used: continue
                v = c['c'][:2] - self.ce[:2]
                s = (np.array([math.cos(a), math.sin(a)]) @ nv(v)) - 0.25 * c['tier']
                if s > bs: best, bs = j, s
            used.add(best); c = tgt[best]
            zs = r.uniform(1.15, 1.55)
            Tp = c['c'] - UP * c['rz'] * 0.2
            tw = 0.55 * (1 if self.seed % 2 else -1)
            def rot(v, t): return np.array([v[0] * math.cos(t) - v[1] * math.sin(t), v[0] * math.sin(t) + v[1] * math.cos(t), v[2]])
            p0 = B - UP * 0.05
            p1 = rot(B, tw * 0.5) * 1.05 + UP * zs * 0.7
            B2 = rot(B, tw)
            hz = np.array([Tp[0] - B2[0], Tp[1] - B2[1], 0.0])
            p2 = B2 * 1.2 + UP * zs + hz * 0.22
            ss = np.linspace(0, 1, 26)
            pts = [bez(p0, p1, p2, Tp, t) for t in ss]
            rads = [r0 * (1 - 0.6 * t) + 0.17 * math.exp(-max(0.0, p[2]) / 0.16) for t, p in zip(ss, pts)]
            key = np.array([B[0], B[1], 0.7])
            Bk = self.T['bark']
            col = mixc(Bk['mid'], Bk['lit'], 0.18) if i % 2 == 0 else mixc(Bk['mid'], Bk['dk'], 0.14)
            self._tube(pts, rads, key, fiss=3, r=r, col=col)
            self.stems.append((pts, rads, c))
            # one or two smaller limbs off the bend, up into the middle and top of the crown
            for k in range(int(r.integers(1, 3))):
                cands = [cc for cc in self.cl if cc['tier'] >= 1 and cc is not c]
                cc = cands[int(r.integers(0, len(cands)))]
                ib = int(r.integers(14, 19)); b0 = pts[ib]
                T2 = cc['c'] - UP * cc['rz'] * 0.3
                m = (b0 + T2) / 2 + UP * 0.25
                lp = [bez(b0, b0 + (m - b0) * 0.6, m, T2, t) for t in np.linspace(0, 1, 12)]
                lr = [rads[ib] * 0.6 * (1 - 0.5 * t) for t in np.linspace(0, 1, 12)]
                self._tube(lp, lr, (b0 + T2) / 2 - TOCAM * 0.6, r=r)
        # where the trunk stands, for the cloth and the roots
        zc = 0.78
        P2 = []
        for pts, rads, c in self.stems:
            i = min(range(len(pts)), key=lambda j: abs(pts[j][2] - zc))
            P2.append((pts[i][:2], rads[i]))
        cen = np.mean([p for p, _ in P2], axis=0)
        self.tc = cen
        self.tR = max(np.linalg.norm(p - cen) + rr for p, rr in P2)

    def _ground_roots(self, r):
        n = 7
        a0 = r.uniform(0, 2 * math.pi)
        for k in range(n):
            a = a0 + k * 2 * math.pi / n + r.normal(0, 0.2)
            A = np.array([math.cos(a), math.sin(a), 0.0]); S = np.array([-A[1], A[0], 0.0])
            L = r.uniform(0.5, 0.95); w0 = r.uniform(0.13, 0.17)
            if math.sin(a) > 0.4: L *= 0.75                      # the ones toward the viewer stay short
            alt = math.atan2(0.95, 0.8 * self.side)
            if abs((a - alt + math.pi) % (2 * math.pi) - math.pi) < 0.4: L = min(L, 0.5)
            ph = r.uniform(0, 6.28); amp = r.uniform(0.04, 0.09)
            ss = np.linspace(0, 1, 16)
            pts = [A * (0.3 + L * t) + S * amp * math.sin(ph + t * 5.0) * t + UP * (0.1 * (1 - t) ** 1.2 + 0.025 * math.sin(t * math.pi)) for t in ss]
            rads = [w0 * (1 - 0.85 * t) for t in ss]
            self._tube(pts, rads, np.array([0, 0, 0.0]) + A * 0.2 - TOCAM * 0.8 + UP * 0.0, r=r)

    def _aerial(self, r):
        """the curtain of aerial roots under the crown; a few reach the ground as pillar roots"""
        T = self.T
        tc, tR = self.tc, self.tR
        roots = []
        for c in self.cl:
            if c['tier'] != 0: continue
            nr = int(r.integers(11, 15))
            for j in range(nr):
                a = r.uniform(0, 2 * math.pi); rr = c['rc'] * 0.78 * math.sqrt(r.uniform(0.15, 1))
                p0 = c['c'] + np.array([math.cos(a) * rr, math.sin(a) * rr, -c['rz'] * 0.62])
                # keep the front of the trunk and its red cloth clear
                if abs(p0[0] - tc[0]) < 0.62 and p0[1] > tc[1]: continue
                if np.linalg.norm(p0[:2] - tc) < tR + 0.12: continue
                roots.append(p0)
        # from the limbs too
        for pts, rads, c in self.stems:
            for i in (16, 20):
                p0 = pts[i] - UP * rads[i]
                if abs(p0[0] - tc[0]) < 0.62 and p0[1] > tc[1]: continue
                if r.random() < 0.6: roots.append(p0)
        r.shuffle(roots)
        npill = 0
        for p0 in roots:
            dist = np.linalg.norm(p0[:2] - tc)
            front = p0[1] > tc[1] + 0.3 and abs(p0[0] - tc[0]) < 1.0
            if npill < [3, 2, 3, 2][self.seed % 4] and dist > 1.2 and not front and r.random() < 0.5:
                npill += 1
                self._pillar(r, p0)
                continue
            # a hanging bundle: long, thin, wavy, the growing tip pale
            z0 = p0[2]
            x = r.random()
            reach = r.uniform(0.1, 0.3) if x < 0.45 else r.uniform(0.3, 0.8) if x < 0.85 else r.uniform(0.8, 0.95)
            strands = []
            for j in range(int(r.integers(1, 4))):
                z1 = max(0.1, z0 * (1 - reach * r.uniform(0.75, 1.0)))
                m = 12
                ph = r.uniform(0, 6.28); wx = r.normal(0, 0.04); wy = r.normal(0, 0.04)
                o = np.array([r.normal(0, 0.025), r.normal(0, 0.025), 0])
                pts = [p0 + o * (0.4 + t) + np.array([wx * t + 0.015 * math.sin(ph + t * 7), wy * t + 0.015 * math.cos(ph + t * 6), -(z0 - z1) * t])
                       for t in np.linspace(0, 1, m)]
                strands.append((pts, r.uniform(0.013, 0.018)))
            def draw(strands=strands):
                pa = self.pa; P = pa.P; A = T['aroot']
                for pts, w0 in strands:
                    sp = [P(q) for q in pts]
                    pa.line(sp, A['mid'], w0 * 2 * pa.k)
                    tip = [tuple(np.array(sp[-2]) + (np.array(sp[-1]) - np.array(sp[-2])) * t) for t in (0.2, 1.0)]
                    pa.line(tip, A['tip'], w0 * 1.5 * pa.k)
            key = p0 + np.array([0, 0, -0.5]) + TOCAM * 0.05
            self.items.append((key, draw))

    def _pillar(self, r, p0):
        """an aerial root grown down into the ground and thickened into a pillar"""
        g = np.array([p0[0] + r.normal(0, 0.06), p0[1] + r.normal(0, 0.06), 0.0])
        ss = np.linspace(0, 1, 16)
        tw = r.uniform(0, 6.28)
        pts = [p0 + (g - p0) * t + np.array([0.04 * math.sin(tw + t * 4), 0.03 * math.cos(tw + t * 3), 0]) * math.sin(t * math.pi) for t in ss]
        w = r.uniform(0.07, 0.095)
        rads = [w * (0.7 + 0.3 * t) + 0.06 * math.exp(-max(0.0, q[2]) / 0.1) for t, q in zip(ss, pts)]
        self._tube(pts, rads, (p0 + g) / 2 - TOCAM * 0.2 + UP * 0.0, fiss=2, r=r)
        # it splits into a few strands at the top where it leaves the limb
        for k in range(2):
            a = r.uniform(0, 6.28)
            s0 = pts[2]; s1 = p0 + np.array([math.cos(a) * 0.12, math.sin(a) * 0.12, 0.08])
            self._tube([s0, (s0 + s1) / 2 + np.array([0.02, 0, 0]), s1], [w * 0.45, w * 0.4, w * 0.3], (s0 + s1) / 2 - TOCAM * 0.3, lit=False,
                       col=self.T['aroot']['mid'])

    # ------------------------------------------------------------- the red cloth round the trunk
    def _sash(self):
        T = self.T; S = T['sash']
        tc, R = self.tc, self.tR * 1.03
        z0 = 0.78
        phs = np.linspace(math.pi * 1.03, -math.pi * 0.03, 40)
        def ztop(ph): return z0 + 0.035 * math.sin(2 * ph + 0.4)
        top = [np.array([tc[0] + R * math.cos(ph), tc[1] + R * math.sin(ph), ztop(ph)]) for ph in phs]
        bot = [np.array([tc[0] + R * math.cos(ph), tc[1] + R * math.sin(ph), ztop(ph) - 0.13]) for ph in phs]
        kph = math.radians(55) if self.side < 0 else math.radians(125)
        knot = np.array([tc[0] + R * 1.04 * math.cos(kph), tc[1] + R * 1.04 * math.sin(kph), ztop(kph) - 0.065])
        def draw():
            pa = self.pa; P = pa.P
            poly = [P(q) for q in top] + [P(q) for q in bot[::-1]]
            pa.fill(poly, S['mid'])
            pa.ctx.save(); pa.path(poly); pa.ctx.clip()
            for i in range(len(phs) - 1):
                ph = (phs[i] + phs[i + 1]) / 2
                lam = np.array([math.cos(ph), math.sin(ph), 0.0]) @ LIGHT
                col = S['lit'] if lam > 0.3 else S['mid'] if lam > -0.15 else S['dk']
                q = [P(top[i]), P(top[i + 1]), P(bot[i + 1]), P(bot[i])]
                pa.fill(q, col, seam=True)
            # folds: short slanted creases
            for i in range(3, len(phs) - 3, 5):
                a = top[i] - UP * 0.025; b = bot[i + 2] + UP * 0.02
                pa.line([P(a), P(b)], S['fold'], pa.u(0.35), 0.55)
            pa.ctx.restore()
            pa.soft_edge(poly, S['mid'])
            # the knot and its two tails
            k = pa.k
            kx, ky = P(knot)
            sg = 1 if self.side < 0 else -1
            for (dx, ln, sw) in ((-0.03, 0.34, -0.06), (0.04, 0.27, 0.07)):
                a = np.array(P(knot + np.array([dx * sg, 0, 0])))
                ax = np.array([sw * sg * k, 0.5 * k]); ax = ax / np.linalg.norm(ax)
                sx = np.array([ax[1], -ax[0]])
                L = ln * k * 0.866
                prof = [(0, 0.04), (0.3, 0.05), (0.7, 0.058), (1.0, 0.066)]
                tail = [tuple(a + ax * L * t + sx * w * k * 0.5 + np.array([math.sin(t * 3) * 0.02 * k * sg, 0])) for t, w in prof] + \
                       [tuple(a + ax * L * 1.0 - sx * 0.066 * k * 0.5 + ax * 0.03 * k * 0.0)] + \
                       [tuple(a + ax * L * t - sx * w * k * 0.5 + np.array([math.sin(t * 3) * 0.02 * k * sg, 0])) for t, w in prof[::-1]]
                tail[len(prof)] = tuple(a + ax * (L + 0.03 * k) + np.array([math.sin(3) * 0.02 * k * sg, 0]))
                col = S['mid'] if dx * sg < 0 else S['dk']
                pa.fill(tail, col); pa.soft_edge(tail, col)
                pa.line([tuple(a + ax * L * 0.15), tuple(a + ax * L * 0.85 + np.array([math.sin(2.5) * 0.02 * k * sg, 0]))], S['fold'], pa.u(0.3), 0.45)
            pa.ctx.save(); pa.ctx.translate(kx, ky); pa.ctx.scale(0.075 * k, 0.06 * k)
            pa.ctx.new_path(); pa.ctx.arc(0, 0, 1, 0, 2 * math.pi); pa.ctx.restore()
            pa.ctx.set_source_rgb(*S['mid']); pa.ctx.fill_preserve(); pa.ctx.set_source_rgb(*ch.soft(S['mid'])); pa.ctx.set_line_width(pa.u(ch.SOFT_W)); pa.ctx.stroke()
            pa.ctx.save(); pa.ctx.translate(kx - 0.02 * k, ky - 0.015 * k); pa.ctx.scale(0.035 * k, 0.025 * k)
            pa.ctx.new_path(); pa.ctx.arc(0, 0, 1, 0, 2 * math.pi); pa.ctx.restore(); pa.ctx.set_source_rgb(*S['lit']); pa.ctx.fill()
        self.items.append((np.array([tc[0], tc[1] + R + 0.05, 0.9]), draw))

    # ------------------------------------------------------------- the incense stand at the foot
    def _altar(self):
        T = self.T; St = T['stone']
        c = np.array([0.8 * self.side, 0.95, 0.0])
        a = 0.12; h = 0.32
        u1 = np.array([SQ, SQ, 0]); u2 = np.array([SQ, -SQ, 0])
        def corner(s1, s2, z): return c + u1 * a * s1 + u2 * a * s2 + UP * z
        night = ch.NIGHT
        def draw():
            pa = self.pa; P = pa.P; k = pa.k
            def box(sc, z0, z1):
                cr = lambda s1, s2, z: P(c + u1 * a * sc * s1 + u2 * a * sc * s2 + UP * z)
                top = [cr(1, 1, z1), cr(1, -1, z1), cr(-1, -1, z1), cr(-1, 1, z1)]
                left = [cr(-1, -1, z1), cr(1, -1, z1), cr(1, -1, z0), cr(-1, -1, z0)]
                right = [cr(1, -1, z1), cr(1, 1, z1), cr(1, 1, z0), cr(1, -1, z0)]
                for poly, col in ((left, St['left']), (right, St['right']), (top, St['top'])):
                    pa.fill(poly, col); pa.soft_edge(poly, col)
                return cr
            box(1.25, 0.0, 0.04)                      # foot
            cr = box(0.85, 0.04, h - 0.045)          # shaft
            box(1.3, h - 0.045, h)                   # cap slab
            pa.line([cr(-1, -1, h * 0.7), cr(1, -1, h * 0.7), cr(1, 1, h * 0.7)], St['line'], pa.u(0.3), 0.55)
            # moss at the foot of the shaft
            pa.line([cr(-1, -1, 0.06), cr(1, -1, 0.07), cr(1, 1, 0.05)], C('#7d8a52'), pa.u(0.8), 0.55)
            # the incense bowl
            bc = c + UP * h
            cx, cy = P(bc + UP * 0.075)
            rx, ry = 0.085 * k, 0.042 * k
            Bw = T['bowl']
            body = [(cx + rx * math.cos(t), cy + ry * math.sin(t)) for t in np.linspace(0, math.pi, 13)]
            body += [(cx + rx * 0.72 * math.cos(t), cy + 0.075 * k * 0.866 + ry * 0.6 * math.sin(t)) for t in np.linspace(math.pi, 0, 13)]
            pa.fill(body, Bw['mid'])
            pa.line([(cx + rx * 0.85 * math.cos(t), cy + ry * math.sin(t) + 0.03 * k * (1 - abs(math.cos(t)))) for t in np.linspace(math.radians(110), math.radians(175), 8)], Bw['lit'], pa.u(0.45), 0.9)
            pa.soft_edge(body, Bw['mid'])
            rim = [(cx + rx * math.cos(t), cy + ry * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 25)]
            pa.fill(rim, Bw['dk'])
            ash = [(cx + rx * 0.8 * math.cos(t), cy + ry * 0.75 * math.sin(t) + ry * 0.1) for t in np.linspace(0, 2 * math.pi, 25)]
            pa.fill(ash, T['ash'])
            # three sticks, the burning tips and a thread of smoke
            glow = (1.0, 0.83, 0.42)
            for j, dx in enumerate((-0.03, 0.0, 0.03)):
                b = np.array([cx + dx * k, cy + ry * 0.1])
                tlen = (0.25 + (0.02 if j == 1 else 0)) * k * 0.866
                t = b + np.array([dx * k * 0.35, -tlen])
                pa.line([tuple(b), tuple(t)], T['stick'], pa.u(0.42))
                if night:
                    pa.ctx.new_path(); pa.ctx.arc(t[0], t[1], pa.u(1.6), 0, 2 * math.pi)
                    pa.ctx.set_source_rgba(*glow, 0.28); pa.ctx.fill()
                pa.ctx.new_path(); pa.ctx.arc(t[0], t[1], pa.u(0.45), 0, 2 * math.pi)
                pa.ctx.set_source_rgb(*glow); pa.ctx.fill()
            t0 = np.array([cx, cy - 0.27 * k * 0.866])
            sm = [tuple(t0 + np.array([math.sin(i * 0.9) * 0.025 * k, -i * 0.05 * k])) for i in range(7)]
            pa.line(sm, (0.93, 0.93, 0.9) if not night else (0.75, 0.78, 0.8), pa.u(0.4), 0.35)
        self.items.append((c + UP * 0.1 + TOCAM * 0.1, draw))

    # ------------------------------------------------------------- leaves
    def _clump_leaves(self, r, c):
        T = self.T; pa = self.pa
        n = int(185 * (c['rc'] / 0.9) ** 2)
        ga = math.pi * (3 - math.sqrt(5))
        spots = []
        zmin = -0.62 if c['tier'] == 0 else -0.4
        for i in range(n):
            zz = 1 - 2 * (i + 0.5) / n; rr = math.sqrt(max(0.0, 1 - zz * zz))
            if zz < zmin: continue
            d = np.array([rr * math.cos(i * ga), rr * math.sin(i * ga), zz])
            p = self.env(c, d, r.uniform(0.94, 1.03) if i % 4 else r.uniform(0.82, 0.9))
            if any(self.inside(o, p, 0.86) for o in self.cl if o is not c and depth(o['c']) > depth(c['c'])): continue
            spots.append((p, d))
        G = (c['c'][2] - self.ce[2]) / self.rb
        clusters = []
        for p, d in spots:
            nrm = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            clusters.append(self._cluster(r, c, p, nrm, d[2], G))
        # the clump's dark inner mass, slightly smaller than its leaves
        mass = []
        for th in np.linspace(0, math.pi, 19):
            for ph in np.linspace(0, 2 * math.pi, 29):
                d = np.array([math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)])
                if d[2] < zmin - 0.1: continue
                mass.append(self.env(c, d, 0.9))
        under = [self.env(c, np.array([math.cos(ph), math.sin(ph), zmin - 0.05]) / np.linalg.norm([1, zmin - 0.05]), 0.92)
                 for ph in np.linspace(0, 2 * math.pi, 29)]
        def draw():
            P = pa.P
            hm = hull([P(q) for q in mass])
            # the clump's shade on whatever is already drawn behind it (other clumps, the wood), never on the ground
            off = -SLIGHT * 0.2 * pa.k
            pa.ctx.save(); pa.ctx.set_operator(cairo.OPERATOR_ATOP)
            pa.path([(x + off[0], y + off[1]) for x, y in hm]); pa.ctx.set_source_rgba(0.02, 0.08, 0.03, 0.36); pa.ctx.fill()
            pa.ctx.restore()
            pa.fill(hm, T['inner'])
            # the flat underside, a shade darker still where it faces down
            pa.fill(hull([P(q) for q in under]), mixc(T['inner'], (0, 0, 0), 0.12))
            allv = [z for cl in clusters for z in cl]
            allv.sort(key=lambda z: depth(z['mid']))
            for z in allv:
                poly = [P(q) for q in z['poly']]
                col = z['col']
                pa.fill(poly, col); pa.soft_edge(poly, col)
                pa.line([P(z['rib'][0]), P(z['rib'][1])], mixc(col, C('#dfe8b0'), 0.3), pa.u(0.2), 0.7)
                if z['gloss']:
                    a3, b3 = z['rib']; m3 = a3 + (b3 - a3) * 0.28; e3 = a3 + (b3 - a3) * 0.6
                    pa.line([P(m3), P(e3)], mixc(col, (1, 1, 1), 0.25), pa.u(0.5), 0.5)
        self.items.append((c['c'], draw))

    def _cluster(self, r, c, p, ns, hc, G):
        T = self.T
        nrm0 = nv(ns + UP * 0.8)
        t1 = np.cross(nrm0, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(nrm0, t1)
        sun = float(ns @ LIGHT)
        ao = 0.72 + 0.32 * max(-1.0, min(1.0, hc)) + 0.12 * G
        nl = int(r.integers(5, 7))
        az0 = r.uniform(0, 2 * math.pi)
        leaves = []
        for k in range(nl):
            az = az0 + k * 2 * math.pi / nl + r.normal(0, 0.5)
            A = math.cos(az) * t1 + math.sin(az) * t2
            el = r.uniform(0.05, 0.5)
            ld = nv(A * math.cos(el) + nrm0 * math.sin(el) - UP * 0.12)
            sd = nv(np.cross(nrm0, ld))
            Ll = 0.17 * r.uniform(0.88, 1.12); Wl = Ll * 0.58
            pt = p + (r.normal(0, 1, 3) * np.array([1, 1, 0.5])) * 0.03 + ld * 0.015
            prof = [(0.0, 0.18), (0.1, 0.62), (0.3, 0.95), (0.5, 1.0), (0.7, 0.86), (0.87, 0.55), (0.97, 0.2), (1.0, 0.0)]
            Lp_, Rp_ = [], []
            for (t, w) in prof:
                q = pt + ld * Ll * t - UP * Ll * 0.12 * t * t
                Lp_.append(q + sd * Wl * 0.5 * w); Rp_.append(q - sd * Wl * 0.5 * w)
            nn = nv(np.cross(ld, sd))
            if nn @ nrm0 < 0: nn = -nn
            topv = nn @ TOCAM > 0
            lam = float((nn if topv else -nn) @ LIGHT)
            v = (0.62 + 0.3 * max(-0.3, lam)) * ao + 0.2 * sun - 0.06
            leaves.append(dict(poly=Lp_ + Rp_[::-1], top=topv, v=v, lam=lam, mid=pt + ld * Ll * 0.5,
                               rib=(pt, pt + ld * Ll * 0.86 - UP * Ll * 0.1)))
        vm = float(np.mean([z['v'] for z in leaves]))
        for z in leaves:
            v = 0.6 * vm + 0.4 * z['v'] + c['tv']
            if not z['top']:
                z['col'] = T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            else:
                z['col'] = T['green'][0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4]
            z['gloss'] = z['top'] and z['lam'] > 0.5 and v > 0.7
        return leaves

    def shadow(self):
        pa = self.pa; c = pa.ctx
        cx, cy = pa.P(np.array([self.ce[0], self.ce[1], 0.0]))
        fx, fy = pa.P(np.array([self.tc[0], self.tc[1], 0.0]))
        rx = (self.ra + 0.35) * pa.k; e = 0.5
        for grow, al in ((1.0, 0.12),):
            c.save(); c.translate(cx, cy); c.scale(rx * grow, rx * grow * e); c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
            c.set_source_rgba(0, 0, 0, al); c.fill()
        rf = (self.tR + 0.5) * pa.k
        c.save(); c.translate(fx, fy); c.scale(rf, rf * e); c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
        c.set_source_rgba(0, 0, 0, 0.1); c.fill()

    def paint(self):
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()
        # the ground shadow goes in under everything at the end, so the clumps' shade never falls on the ground
        self.pa.ctx.save(); self.pa.ctx.set_operator(cairo.OPERATOR_DEST_OVER); self.shadow(); self.pa.ctx.restore()


FRAMES = [dict(seed=s) for s in range(4)]
BB = (-95, -135, 95, 50)


def render(fr, night=False, bb=BB):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    f = dict(fr); seed = f.pop('seed')
    Da(seed, pa, **f).paint()
    surf.flush(); ch.NIGHT = False
    return surf, bb


def to_image(surf):
    w, h = surf.get_width(), surf.get_height()
    a = np.ndarray((h, w, 4), np.uint8, surf.get_data()).copy()
    im = Image.frombuffer('RGBa', (w, h), a[:, :, [2, 1, 0, 3]].tobytes(), 'raw', 'RGBa', 0, 1)
    return im.resize((w // SS, h // SS), Image.LANCZOS).convert('RGBA')


def atlas(outdir, tabpath):
    """4 frames, day and night, cropped and packed into one webp; writes the frame table json"""
    import json
    crops = []
    for night in (False, True):
        for k, fr in enumerate(FRAMES):
            surf, bb = render(fr, night)
            im = to_image(surf)
            a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            crops.append(('nd'[not night] + str(k), im.crop((x0, y0, x1, y1)), bb[0] + x0 / RS, bb[1] + y0 / RS))
    cols = 4; x = y = rowh = 0; pos = {}
    for k, (name, im, dx, dy) in enumerate(crops):
        if k and k % cols == 0: x = 0; y += rowh + 2; rowh = 0
        pos[name] = (x, y); x += im.width + 2; rowh = max(rowh, im.height)
    Wt = max(pos[n][0] + im.width for n, im, _, _ in crops); Ht = y + rowh
    sheet = Image.new('RGBA', (Wt, Ht), (0, 0, 0, 0)); table = {}
    for name, im, dx, dy in crops:
        sx, sy = pos[name]; sheet.paste(im, (sx, sy))
        table[name] = [sx, sy, im.width, im.height, round(dx, 2), round(dy, 2), round(im.width / RS, 2), round(im.height / RS, 2)]
    path = os.path.join(outdir, 'da.webp')
    sheet.save(path, 'WEBP', quality=88, alpha_quality=100, method=6)
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
        sheet.save('/tmp/claude-0/g/da_%s.png' % tag); print(sheet.size)
