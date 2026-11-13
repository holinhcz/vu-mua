# Rubber trees (cây cao su) for Nông Trại Nhỏ, built as small 3D models and painted in flat game tones with the thin
# same-colour edge of the other new trees (ch.SOFT), with the banana kit's camera, sun and night transform (../chuoi).
# A tree: a straight grey trunk with the tapping panel on the side facing the viewer (brown renewed bark with old cut
# lines, the fresh cut with a white line of latex, the spout and a white cup on a wire), a fork into 2-3 rising limbs
# with side branches and twigs, and tufts of long-stalked three-leaflet leaves at the branch ends.
# Three seasons: green (spring, summer), turning (autumn: yellow, orange, red), bare (winter: a few dry leaves left).
import math, os, sys
import numpy as np, cairo
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'chuoi'))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM

RS, SS = 9, 2
NOSH = os.environ.get('NOSH') == '1'   # v808: sheet without the baked ground shadow
LAST = [None]
PX = RS * SS
KU = 29.0
UP = np.array([0, 0, 1.0])
SUNXY = nv(np.array([LIGHT[0], LIGHT[1]]))


def tones():
    return dict(
        green=[C('#1f5a26'), C('#2b7030'), C('#3a873a'), C('#52a046'), C('#6cb856')],
        und=[C('#4f7f3e'), C('#64964e'), C('#7dab62')],
        lime=[C('#5f7a22'), C('#7a9a2c'), C('#97b63c'), C('#b2cc54'), C('#c8dc70')],
        yellow=[C('#a87c18'), C('#c99a22'), C('#ddb22e'), C('#e9c64a'), C('#f1d666')],
        orange=[C('#a84e18'), C('#c66624'), C('#de8032'), C('#ee9c48'), C('#f6b86a')],
        red=[C('#7e2a1a'), C('#9a3a20'), C('#b44c2a'), C('#cc643a'), C('#de8050')],
        dry=[C('#7a5a34'), C('#94713f'), C('#ad8a52'), C('#c3a266'), C('#d4b77e')],
        bark=dict(lit=C('#cbc4b2'), mid=C('#a69e8b'), dk=C('#7b7465'), line=C('#8f877a')),
        panel=dict(lit=C('#bba98a'), mid=C('#9c8b6e'), dk=C('#786a55'), cut=C('#4a3a28')),
        latex=C('#fbfaf3'), cup=dict(lit=C('#f2f1ec'), mid=C('#d9d7cf'), dk=C('#b1aea5')), wire=C('#4a4a46'), spout=C('#8d9196'),
    )


class Caosu:
    """seed picks the shape; season 0 green, 1 turning, 2 bare"""
    def __init__(self, seed, pa, season=0):
        self.pa = pa; self.season = season; self.seed = seed
        r = self.rng = np.random.default_rng(seed * 4099 + 11)
        self.items = []
        self.T = tones()
        q = seed % 4
        sign = 1 if seed % 2 == 0 else -1
        lean = [0.04, 0.08, 0.06, 0.1][q]
        self.lx, self.ly = lean * sign, [0.03, -0.04, 0.05, 0.0][q]
        self.H = [2.3, 2.45, 2.15, 2.4][q]          # height of the fork
        self.crown = [1.0, 1.06, 0.94, 1.02][q]
        self.nb = [3, 2, 3, 3][q]
        self._trunk(r)
        self._limbs(r)

    # ------------------------------------------------------------- trunk
    def X(self, s):
        # s from 0 (ground) to 1 (fork); straight out of the ground, a gentle lean above
        g = s * s * (3 - 2 * s) * 0.6 + s * 0.4
        return np.array([self.lx * g, self.ly * g, self.H * s])

    def Tn(self, s):
        return nv(self.X(min(1, s + 0.01)) - self.X(max(0, s - 0.01)))

    def rad(self, s):
        z = s * self.H
        return 0.07 + 0.03 * (1 - s) + 0.04 * math.exp(-z / 0.12)

    def surf(self, z, phi, out=1.0):
        s = z / self.H
        c = self.X(s); t = self.Tn(s)
        u = nv(np.array([1.0, 0, 0]) - t[0] * t); v = nv(np.cross(t, u))
        dv = math.cos(phi) * u + math.sin(phi) * v
        return c + dv * self.rad(s) * out, dv

    def _trunk(self, r):
        pa = self.pa; T = self.T
        m = 48
        ss = np.linspace(0, 1, m + 1)
        # the tapping panel faces the viewer: the cut runs down from high on the left to low on the right
        ph0, ph1 = math.radians(150) + r.normal(0, 0.05), math.radians(32) + r.normal(0, 0.05)
        zc0, zc1 = 1.02 + r.normal(0, 0.03), 0.84 + r.normal(0, 0.03)
        zb0 = 0.5 + r.normal(0, 0.02)
        self.tap = (ph0, ph1, zc0, zc1, zb0)
        lich = [(r.uniform(0.25, 0.9), r.uniform(-0.6, 0.6) + (math.pi / 2 if k % 2 else math.pi / 2 + 2.2), r.uniform(0.6, 1.0)) for k in range(3)]
        def draw():
            P = pa.P
            pts = np.array([P(self.X(q)) for q in ss]); n = len(pts)
            Lp, Rp, Cn = [], [], []
            for i in range(n):
                a = pts[max(0, i - 1)]; b = pts[min(n - 1, i + 1)]
                d = nv(b - a); nrm = np.array([-d[1], d[0]])
                w = self.rad(ss[i]) * pa.k
                Lp.append(pts[i] + nrm * w); Rp.append(pts[i] - nrm * w); Cn.append((pts[i], nrm, w))
            litL = (Cn[n // 2][1] @ SLIGHT) > 0
            sg = 1 if litL else -1
            cb = np.array(P(self.X(0.0))); rb = self.rad(0.0) * pa.k
            foot = [tuple(cb + np.array([rb * math.cos(a), 0.5 * rb * math.sin(a)])) for a in np.linspace(math.pi, 0, 17)]
            body = [tuple(q) for q in Lp] + [tuple(q) for q in Rp[::-1]] + foot[1:-1]
            B = T['bark']
            pa.fill(body, B['mid'])
            band = lambda f0, f1, sgn: [tuple(p + nr * w * sgn * f0) for (p, nr, w) in Cn] + [tuple(p + nr * w * sgn * f1) for (p, nr, w) in Cn[::-1]]
            pa.ctx.save(); pa.path(body); pa.ctx.clip()
            pa.fill(band(1.05, 0.2, sg), B['lit'], seam=False)
            pa.fill(band(1.05, 0.48, -sg), B['dk'], seam=False)
            # a few pale lichen patches, flat shapes
            for (s0, a0, sz) in lich:
                c3, dv = self.surf(s0 * self.H, a0)
                if dv @ TOCAM < 0.2: continue
                t = self.Tn(s0); sd = nv(np.cross(t, dv))
                poly = [P(c3 + sd * 0.035 * sz * math.cos(k * math.pi / 6) * (1 + 0.25 * math.sin(k * 1.7)) + t * 0.06 * sz * math.sin(k * math.pi / 6)) for k in range(12)]
                pa.path(poly); pa.ctx.set_source_rgba(*mixc(B['lit'], C('#dfe3d0'), 0.5), 0.7); pa.ctx.fill()
            # the foot a shade darker, red soil splashed on it
            fb = [tuple(q) for q in foot]; hy = pa.u(1.8)
            pa.path([(fb[0][0] - 9, fb[0][1] - hy), (fb[-1][0] + 9, fb[-1][1] - hy), (fb[-1][0] + 9, fb[-1][1] + 9), (fb[0][0] - 9, fb[0][1] + 9)])
            pa.ctx.set_source_rgba(*C('#8a5a3c'), 0.45); pa.ctx.fill()
            self._panel_draw()
            pa.ctx.restore()
            for sd in ([tuple(q) for q in Lp], [tuple(q) for q in Rp], foot):
                pa.soft_edge(sd, B['mid'], close=False)
            self._cup_draw()
        self.items.append((self.X(0.3) - np.array([0, 0, 2.0]), draw))

    def _panel_draw(self):
        pa = self.pa; P = pa.P; T = self.T; Pn = T['panel']
        ph0, ph1, zc0, zc1, zb0 = self.tap
        phs = np.linspace(ph0, ph1, 25)
        cutz = lambda ph: zc0 + (zc1 - zc0) * (ph - ph0) / (ph1 - ph0)
        top = [self.surf(cutz(ph), ph, 1.01) for ph in phs]
        bot = [self.surf(zb0 + 0.06 * (ph - ph0) / (ph1 - ph0) * 0, ph, 1.01) for ph in phs]
        poly = [P(p) for p, _ in top] + [P(p) for p, _ in bot[::-1]]
        pa.fill(poly, Pn['mid'])
        # light and shade across the panel follow the trunk
        for (p, dv), (pb, _), ph in zip(top, bot, phs):
            pass
        litp = [P(p) for (p, dv) in top if dv @ LIGHT > 0.25]
        # the lit strip of the panel
        lit_idx = [i for i, (p, dv) in enumerate(top) if dv @ LIGHT > 0.2]
        if len(lit_idx) > 1:
            i0, i1 = lit_idx[0], lit_idx[-1]
            pl = [P(top[i][0]) for i in range(i0, i1 + 1)] + [P(bot[i][0]) for i in range(i1, i0 - 1, -1)]
            pa.path(pl); pa.ctx.set_source_rgb(*Pn['lit']); pa.ctx.fill()
        dk_idx = [i for i, (p, dv) in enumerate(top) if dv @ LIGHT < -0.15]
        if len(dk_idx) > 1:
            i0, i1 = dk_idx[0], dk_idx[-1]
            pl = [P(top[i][0]) for i in range(i0, i1 + 1)] + [P(bot[i][0]) for i in range(i1, i0 - 1, -1)]
            pa.path(pl); pa.ctx.set_source_rgb(*Pn['dk']); pa.ctx.fill()
        # old cut lines, parallel to the fresh cut, fainter going down
        for k, off in enumerate((0.09, 0.18, 0.27, 0.36)):
            ln = [P(self.surf(cutz(ph) - off, ph, 1.012)[0]) for ph in phs if cutz(ph) - off > zb0 + 0.015]
            if len(ln) > 1: pa.line(ln, Pn['dk'], pa.u(0.28), 0.55 - 0.1 * k)
        # the fresh cut: a dark groove with the white latex line just under it
        cut = [P(p) for p, _ in top]
        pa.line(cut, Pn['cut'], pa.u(0.55))
        lat = [P(self.surf(cutz(ph) - 0.022, ph, 1.015)[0]) for ph in phs]
        pa.line(lat, T['latex'], pa.u(0.38), 0.95)
        # the vertical guide line from the low end down toward the spout
        self.spout = self.surf(zc1 - 0.18, ph1 + 0.05, 1.02)[0]
        g = [P(self.surf(zc1 - 0.01 - 0.17 * k / 6, ph1 + 0.05 * k / 6, 1.015)[0]) for k in range(7)]
        pa.line(g, Pn['cut'], pa.u(0.3), 0.8)
        pa.line(g, T['latex'], pa.u(0.22), 0.9)

    def _cup_draw(self):
        pa = self.pa; P = pa.P; T = self.T
        ph0, ph1, zc0, zc1, zb0 = self.tap
        phc = ph1 + 0.15
        zc = zc1 - 0.42
        c3, dv = self.surf(zc, phc, 1.0)
        # wire round the trunk holding the cup
        wire = [P(self.surf(zc + 0.035, ph, 1.03)[0]) for ph in np.linspace(math.radians(170), math.radians(10), 15)]
        pa.line(wire, T['wire'], pa.u(0.28), 0.85)
        # spout: a short metal tongue dripping latex into the cup
        sp = self.spout
        tip = sp + dv * 0.05 - UP * 0.01
        pa.line([P(sp), P(tip)], T['spout'], pa.u(0.45))
        cc = c3 + dv * 0.075
        pa.line([P(tip), P(cc + UP * 0.04)], T['latex'], pa.u(0.18), 0.9)
        # the cup: a small white bowl, rim seen from above, latex inside
        k = pa.k; c = np.array(P(cc + UP * 0.03))
        rx, ry = 0.07 * k, 0.035 * k
        bowl = [tuple(c + np.array([rx * math.cos(a), ry * math.sin(a)])) for a in np.linspace(0, math.pi, 13)]
        bowl += [tuple(c + np.array([rx * 0.75 * math.cos(a), ry * 0.6 * math.sin(a) + 0.07 * k])) for a in np.linspace(math.pi, 0, 13)]
        pa.fill(bowl, T['cup']['mid'])
        lt = [tuple(c + np.array([rx * 0.9 * math.cos(a), ry * math.sin(a) + 0.035 * k * (1 - abs(math.cos(a)))])) for a in np.linspace(math.radians(110), math.radians(180), 8)]
        pa.line(lt, T['cup']['lit'], pa.u(0.4), 0.9)
        rim = [tuple(c + np.array([rx * math.cos(a), ry * math.sin(a)])) for a in np.linspace(0, 2 * math.pi, 25)]
        pa.fill(rim, T['cup']['dk'])
        inner = [tuple(c + np.array([rx * 0.82 * math.cos(a), ry * 0.78 * math.sin(a) + ry * 0.12])) for a in np.linspace(0, 2 * math.pi, 25)]
        pa.fill(inner, T['latex'])
        pa.soft_edge(bowl, T['cup']['mid'])

    # ------------------------------------------------------------- limbs and leaves
    def _limbs(self, r):
        top = self.X(1.0); t1 = self.Tn(1.0)
        rf = self.rad(1.0)
        limbs = []
        # the crown envelope, an upright egg the branch ends stay inside
        self.ce = np.array([top[0] * 1.4, top[1] * 1.4, top[2] + 0.72 * self.crown])
        self.ra, self.rb = [0.74, 0.7, 0.78, 0.72][self.seed % 4] * self.crown, [0.74, 0.8, 0.7, 0.78][self.seed % 4] * self.crown
        # autumn: the tree has one main colour, each limb leans to it or a neighbour of it (patches, not confetti)
        q = self.seed % 4
        self.fams = [['yellow', 'yellow', 'orange', 'lime'], ['orange', 'orange', 'red', 'yellow'],
                     ['yellow', 'lime', 'yellow', 'orange'], ['orange', 'yellow', 'orange', 'red']][q]
        # the leader carries on up, the other limbs rise and lean out around it
        az0 = r.uniform(0, 2 * math.pi)
        for k in range(self.nb):
            az = az0 + k * 2 * math.pi / self.nb + r.normal(0, 0.2)
            tilt = (0.06 if k == 0 else 0.36) + r.normal(0, 0.04)
            d = nv(t1 * math.cos(tilt) + np.array([math.cos(az), math.sin(az), 0]) * math.sin(tilt))
            L = (1.3 if k == 0 else 1.12) * r.uniform(0.94, 1.05) * self.crown
            w0 = rf * (0.8 if k == 0 else 0.62)
            fam = self.fams[k % 4]
            limbs.append(self._branch(r, top - t1 * 0.03, d, L, w0, 0, fam, 0.04 * (k % 2) - 0.02))
        self.tips = []; self.bpts = []
        for b in limbs: self._collect(b)
        if self.season < 2: self._fill(r)
        # leaf tufts at the branch tips and along the upper limbs
        for (p, d, lev, fam, tv) in self.tips:
            self._tuft(r, p, d, lev, fam, tv)

    def _branch(self, r, p0, d, L, w0, lev, fam, tv):
        """a curved branch; returns a node dict with child branches"""
        m = 8
        pts = [p0]; dd = d.copy()
        hz = np.array([dd[0], dd[1], 0.0])
        bend = nv(hz + np.array([r.normal(0, 0.2), r.normal(0, 0.2), 0])) if np.linalg.norm(hz) > 1e-3 else np.array([1.0, 0, 0])
        sc = np.array([1 / self.ra, 1 / self.ra, 1 / self.rb])
        for k in range(m):
            dd = nv(dd + bend * 0.03 + UP * 0.012 + r.normal(0, 0.025, 3))
            nx = pts[-1] + dd * L / m
            e = (nx - self.ce) * sc
            if np.linalg.norm(e) > 0.9 and self.season < 2:
                # near the edge of the crown: turn back in along the surface
                g = nv(e * sc)
                dd = nv(dd - g * max(0.0, dd @ g) * 1.1 + UP * 0.05)
                nx = pts[-1] + dd * L / m
                if np.linalg.norm((nx - self.ce) * sc) > 1.02 and k >= 2: break
            pts.append(nx)
        node = dict(pts=pts, w0=w0, w1=w0 * 0.55, lev=lev, kids=[], fam=fam, tv=tv)
        if lev < 2:
            nk = int(r.integers(3, 5)) if lev == 0 else int(r.integers(2, 4))
            for j in range(nk):
                t = r.uniform(0.35, 0.85) if j < nk - 1 else 1.0
                mm = len(pts) - 1; i = min(mm, max(1, int(round(t * mm))))
                base = pts[i]
                dir0 = nv(pts[min(mm, i + 1)] - pts[max(0, i - 1)])
                # side branches lean outward from the middle of the crown, so the crown fills into a dome
                out = np.array([base[0] - self.lx, base[1] - self.ly, 0.0])
                az = r.uniform(0, 2 * math.pi)
                side = np.array([math.cos(az), math.sin(az), 0.0])
                if np.linalg.norm(out) > 0.05: side = nv(side * 0.9 + nv(out) * 0.8)
                cd = nv(dir0 * math.cos(0.56) + nv(side - (side @ dir0) * dir0) * math.sin(0.56) + UP * 0.16)
                cl = L * r.uniform(0.5, 0.68)
                f2 = fam
                if self.season == 1 and r.random() < 0.3: f2 = self.fams[int(r.integers(0, 4))]
                node['kids'].append(self._branch(r, base, cd, cl, node['w1'] * (0.9 if t > 0.95 else 0.7), lev + 1, f2, tv + r.normal(0, 0.02)))
        return node

    def _fill(self, r):
        """the crown is an upright egg: where it has a hole, a short spur grows from the nearest branch into it"""
        ce, ra, rb = self.ce, self.ra, self.rb
        n = 90; ga = math.pi * (3 - math.sqrt(5))
        pts = []
        for i in range(n):
            zz = 1 - 2 * (i + 0.5) / n; rr = math.sqrt(1 - zz * zz)
            if zz < -0.55: continue
            f = 0.88 if i % 3 else 0.55
            pts.append(ce + np.array([rr * math.cos(i * ga) * ra, rr * math.sin(i * ga) * ra, zz * rb]) * f)
        order = r.permutation(len(pts))
        cand = [b for b in self.bpts if b[0][2] > self.H + 0.15]
        if not cand: return
        B = np.array([b[0] for b in cand])
        for oi in order:
            sp = pts[oi]
            tp = np.array([t[0] for t in self.tips])
            if len(tp) and np.min(np.linalg.norm(tp - sp, axis=1)) < 0.34: continue
            j = int(np.argmin(np.linalg.norm(B - sp, axis=1)))
            bp, lev, fam, tv, w = cand[j]
            v = sp - bp; L = float(np.linalg.norm(v))
            if L < 0.05: continue
            if L > 0.6: sp = bp + v / L * 0.6; L = 0.6
            d = nv(v)
            mid = bp + d * L * 0.5 + UP * 0.04
            spur = [bp, mid, sp]
            ww = max(0.008, w * 0.55)
            def draw(spur=spur, ww=ww):
                pa = self.pa; P = pa.P; Bk = self.T['bark']
                col = mixc(mixc(Bk['mid'], Bk['dk'], 0.3), mixc(Bk['dk'], C('#3c4a2c'), 0.3), 0.4)
                pa.taper([P(q) for q in spur], ww * 2 * pa.k, ww * 1.1 * pa.k, col, outline=col)
            self.items.append(((bp + sp) / 2, draw))
            self.tips.append((sp, d, 2, fam, tv))

    def _collect(self, node):
        pa = self.pa; T = self.T
        pts = node['pts']; w0, w1 = node['w0'], node['w1']
        def draw(pts=pts, w0=w0, w1=w1, lev=node['lev']):
            P = pa.P
            sp = [P(q) for q in pts]
            B = T['bark']
            # inside a leafy crown the wood sits in the shade of the leaves
            inner = self.season < 2 and pts[0][2] > self.H + 0.25
            col = B['mid'] if lev == 0 else mixc(B['mid'], B['dk'], 0.25)
            if inner: col = mixc(col, mixc(B['dk'], C('#3c4a2c'), 0.3), 0.4)
            pa.taper(sp, w0 * 2 * pa.k, w1 * 2 * pa.k, col, outline=col)
            if inner: return
            # lit edge on the sun side
            arr = np.array(sp, float); n = len(arr); lit = []
            for i in range(n):
                a = arr[max(0, i - 1)]; b = arr[min(n - 1, i + 1)]
                dd = nv(b - a); nr = np.array([-dd[1], dd[0]])
                if nr @ SLIGHT < 0: nr = -nr
                w = (w0 + (w1 - w0) * i / (n - 1)) * pa.k
                lit.append(tuple(arr[i] + nr * w * 0.45))
            pa.line(lit, B['lit'], max(pa.u(0.3), (w0 + w1) * 0.35 * pa.k), 0.8)
        self.items.append(((pts[0] + pts[-1]) / 2, draw))
        fam, tv = node['fam'], node['tv']
        for q in pts[2:]: self.bpts.append((q, node['lev'], fam, tv, (w0 + w1) / 2))
        if not node['kids'] or node['lev'] >= 1:
            d = nv(pts[-1] - pts[-3])
            self.tips.append((pts[-1], d, node['lev'], fam, tv))
            if node['lev'] >= 1:
                self.tips.append((pts[len(pts) // 2], d, node['lev'] + 0.5, fam, tv))
        elif node['lev'] == 0:
            d = nv(pts[-1] - pts[-3])
            self.tips.append((pts[int(len(pts) * 0.75)], d, 0.5, fam, tv))
        for k in node['kids']: self._collect(k)
        # twigs at the very ends (they carry the leaves; in the bare season they show)
        if self.season == 2 and (node['lev'] == 2 or (node['lev'] == 1 and not node['kids'])):
            p = pts[-1]; d = nv(pts[-1] - pts[-2])
            tw = []
            rr = np.random.default_rng(int(abs(p[0] * 1000 + p[1] * 7000 + p[2] * 300)) % 99991)
            az0 = rr.uniform(0, 2 * math.pi)
            for j in range(3):
                az = az0 + j * 2.1 + rr.normal(0, 0.3)
                dd = nv(d + np.array([math.cos(az), math.sin(az), 0]) * 0.75 + UP * 0.2)
                ln = rr.uniform(0.6, 1.15)
                a3 = p + dd * 0.13 * ln; b3 = a3 + nv(dd + UP * 0.35) * 0.11 * ln
                tw.append([p, a3, b3])
                if j == 0:
                    e3 = nv(dd + np.array([-math.sin(az), math.cos(az), 0]) * 0.6)
                    tw.append([a3, a3 + e3 * 0.1 + UP * 0.03])
            def tdraw(tw=tw, w=w1):
                P = pa.P
                for t3 in tw: pa.line([P(q) for q in t3], mixc(T['bark']['mid'], T['bark']['dk'], 0.35), max(pa.u(0.4), w * (1.2 if len(t3) == 3 else 0.8) * pa.k))
            self.items.append((p, tdraw))

    def _tuft(self, r, c, d, lev, fam0, tv):
        """a whorl of long-stalked three-leaflet leaves round a branch tip"""
        T = self.T; season = self.season
        nl = int(r.integers(7, 10)) if lev < 1.5 else int(r.integers(5, 8))
        if season == 2:
            nl = int(r.integers(1, 3)) if r.random() < 0.38 else 0
        if nl == 0: return
        cc = c + UP * 0.04
        leaves = []
        az0 = r.uniform(0, 2 * math.pi)
        # where the tuft sits in the crown: outer and higher tufts are lighter
        hd = math.hypot(c[0], c[1]); hz = c[2] - self.H
        hc = (hz - 0.72 * self.crown) / (0.6 * self.crown)
        ao = 0.74 + 0.16 * min(1.0, hd / 0.7) + 0.24 * max(-1.0, min(1.0, hc))
        sun = (c[0] * SUNXY[0] + c[1] * SUNXY[1]) / (hd + 1e-6) * min(1.0, hd / 0.5)
        # a tuft's colour family (autumn mixes families tuft by tuft, with a few odd leaves)
        if season == 0: fam = 'green'
        elif season == 1:
            fam = fam0 if r.random() < 0.85 else self.fams[int(r.integers(0, 4))]
        else:
            fam = 'dry' if r.random() < 0.6 else 'yellow'
        for k in range(nl):
            az = az0 + k * 2 * math.pi / nl + r.normal(0, 0.15)
            el = r.uniform(-0.15, 0.55) if k % 2 else r.uniform(-0.55, 0.2)
            A = np.array([math.cos(az), math.sin(az), 0.0])
            pd = nv(A * math.cos(el) + UP * math.sin(el))
            pl = 0.12 * r.uniform(0.85, 1.15)
            pt = cc + pd * pl
            f2 = fam
            if season == 1 and r.random() < 0.06: f2 = self.fams[int(r.integers(0, 4))]
            for j, ang in enumerate((-0.62, 0.0, 0.62)):
                Ll = (0.26 if j == 1 else 0.22) * r.uniform(0.9, 1.08)
                Wl = Ll * 0.4
                S = nv(np.cross(UP, A)) if abs(A[2]) < 0.99 else np.array([1.0, 0, 0])
                ld = nv(A * math.cos(ang) + S * math.sin(ang))
                ld = nv(ld * math.cos(el * 0.6 - 0.25) + UP * math.sin(el * 0.6 - 0.25))
                sd = nv(np.cross(UP, ld)) if abs(ld[2]) < 0.99 else S
                nrm = nv(np.cross(ld, sd))
                if nrm[2] < 0: nrm = -nrm
                prof = [(0.0, 0.0), (0.12, 0.55), (0.4, 1.0), (0.7, 0.82), (0.9, 0.36), (1.0, 0.0)]
                Lp_, Rp_ = [], []
                for (t, w) in prof:
                    q = pt + ld * Ll * t - UP * Ll * 0.22 * t * t
                    Lp_.append(q + sd * Wl * 0.5 * w); Rp_.append(q - sd * Wl * 0.5 * w)
                poly = Lp_ + Rp_[::-1][1:-1]
                topv = nrm @ TOCAM > 0
                vis = nrm if topv else -nrm
                lam = float(vis @ LIGHT)
                v = (0.55 + 0.45 * max(-0.3, lam)) * ao + 0.08 * sun - 0.06
                mid = pt + ld * Ll * 0.5
                leaves.append(dict(poly=poly, top=topv, v=v, mid=mid, fam=f2, pet=(cc, pt), rib=(pt, pt + ld * Ll * 0.85 - UP * Ll * 0.16)))
        # the tuft keeps one tone, each leaflet a little of its own
        vm = float(np.mean([z['v'] for z in leaves]))
        for z in leaves: z['v'] = 0.6 * vm + 0.4 * z['v'] + tv
        leaves.sort(key=lambda z: depth(z['mid']))
        def col_of(z):
            v = z['v']; ramp = T[z['fam']]
            if z['fam'] == 'green' and not z['top']: return T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            i = 0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4
            if not z['top']: i = max(0, min(4, i - 1))
            return ramp[i]
        cols = [col_of(z) for z in leaves]
        def draw(leaves=leaves, cols=cols):
            pa = self.pa; P = pa.P
            for z, c in zip(leaves, cols):
                a3, b3 = z['pet']
                pa.line([P(a3), P(b3)], mixc(c, T['bark']['mid'], 0.3), pa.u(0.26), 0.9)
            for z, c in zip(leaves, cols):
                poly = [P(q) for q in z['poly']]
                pa.fill(poly, c)
                pa.soft_edge(poly, c)
                pa.line([P(z['rib'][0]), P(z['rib'][1])], mixc(c, (1, 1, 1), 0.22), pa.u(0.2), 0.7)
        self.items.append((cc + UP * 0.05, draw))

    def shadow(self):
        pa = self.pa; c = pa.ctx
        cx, cy = pa.P(np.array([self.X(1.0)[0], self.X(1.0)[1], 0.0]))
        fx, fy = pa.P(np.array([0.0, 0.0, 0.0]))
        k = 1.0 if self.season < 2 else 0.55
        rx = 0.74 * self.crown * pa.k * k; e = 0.42; rf = 0.22 * pa.k
        # v808: the shadow parameters are kept so the game can draw one merged shade for touching trees (NOSH sheet)
        self.sh = (cx, cy, rx, fx, fy, rf, e, 0.07 * k + 0.02, 0.12 * k + 0.03)
        if NOSH: return
        for grow, al in ((1.12, 0.07 * k + 0.02), (1.0, 0.12 * k + 0.03)):
            c.new_path()
            for (x, y, rr) in ((cx, cy, rx), (fx, fy, rf)):
                c.save(); c.translate(x, y); c.scale(rr * grow, rr * grow * e); c.new_sub_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
            c.set_fill_rule(cairo.FILL_RULE_WINDING); c.set_source_rgba(0, 0, 0, al); c.fill()

    def paint(self):
        self.shadow()
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()


# frames: seeds 0-3 in each season (0 green, 1 turning, 2 bare)
FRAMES = [dict(seed=s, season=se) for se in (0, 1, 2) for s in range(4)]


def render(fr, night=False, bb=(-70, -150, 70, 20)):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    f = dict(fr); seed = f.pop('seed')
    t = Caosu(seed, pa, **f); t.paint(); LAST[0] = t
    surf.flush(); ch.NIGHT = False
    return surf, bb


def to_image(surf):
    w, h = surf.get_width(), surf.get_height()
    a = np.ndarray((h, w, 4), np.uint8, surf.get_data()).copy()
    im = Image.frombuffer('RGBa', (w, h), a[:, :, [2, 1, 0, 3]].tobytes(), 'raw', 'RGBa', 0, 1)
    return im.resize((w // SS, h // SS), Image.LANCZOS).convert('RGBA')


def atlas(outdir, tabpath):
    """12 frames, day and night, cropped and packed into one webp; writes the frame table json"""
    import json
    crops = []; SH = {}
    for night in (False, True):
        for k, fr in enumerate(FRAMES):
            surf, bb = render(fr, night)
            q = LAST[0].sh
            SH['nd'[not night] + str(k)] = [round(q[0] / PX + bb[0], 2), round(q[1] / PX + bb[1], 2), round(q[2] / PX, 2),
                                            round(q[3] / PX + bb[0], 2), round(q[4] / PX + bb[1], 2), round(q[5] / PX, 2), q[6], round(q[7], 3), round(q[8], 3)]
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
    path = os.path.join(outdir, 'caosu.webp')
    sheet.save(path, 'WEBP', quality=90, alpha_quality=100, method=6)
    open(tabpath, 'w').write(json.dumps(table, separators=(',', ':')))
    open(tabpath.replace('.json', '_sh.json'), 'w').write(json.dumps(SH, separators=(',', ':')))
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
        sheet.save('/tmp/claude-0/g/caosu_%s.png' % tag); print(sheet.size)
