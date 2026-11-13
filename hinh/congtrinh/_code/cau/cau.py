# Areca palms (cây cau) for Nông Trại Nhỏ, built as small 3D models and painted in flat game tones with the thin
# same-colour edge of the other new trees (ch.SOFT), with the banana kit's camera, sun and night transform (../chuoi).
# A palm: a tall slender grey trunk ringed with pale leaf scars (greener near the top), a little root cone at the foot,
# the smooth bright green crown shaft (bẹ cau) on top, 8-9 feather fronds rising out of it like a feather duster
# (young ones upright, old ones arching out), a closed spear leaf, and bunches of nuts (buồng cau) hanging from
# the bottom of the crown shaft on branched straw-coloured stalks.
import math, os, sys
import numpy as np, cairo
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'chuoi'))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM

RS, SS = 5, 2
PX = RS * SS
KU = 29.0
UP = np.array([0, 0, 1.0])
SUNXY = nv(np.array([LIGHT[0], LIGHT[1]]))


def tones():
    return dict(
        top=[C('#2c6a22'), C('#3a8428'), C('#4f9e30'), C('#6cb83c'), C('#8fcd52')],
        und=[C('#5a873a'), C('#749f4a'), C('#91b862')],
        yel=[C('#a39a30'), C('#c0b440'), C('#d6c95a'), C('#e6da7c')],
        rach=C('#a6c25c'),
        trunk=dict(lit=C('#cdc9b4'), mid=C('#aba895'), dk=C('#817e6e'), ring=C('#dcd9c5'), groove=C('#74726a')),
        young=dict(lit=C('#c0ca96'), mid=C('#9ca876'), dk=C('#728056'), ring=C('#d2dbb0'), groove=C('#5e6a44')),
        shaft=dict(lit=C('#a6d062'), mid=C('#7fb246'), dk=C('#5a8a34'), hi=C('#d4eda0'), seam=C('#4f7d2c')),
        root=C('#6e5440'), root_lt=C('#8a6c52'),
        stalk=C('#d6c77e'), stalk_dk=C('#a89a5a'),
        nut=dict(
            green=dict(dk=C('#5a8a26'), mid=C('#80b23a'), lit=C('#a8d05a'), hi=C('#def0a6'), cap=C('#7d7a36')),
            orange=dict(dk=C('#c25e18'), mid=C('#ec8a26'), lit=C('#f7ad46'), hi=C('#fde2a8'), cap=C('#8a5a24')),
            yellow=dict(dk=C('#b2861c'), mid=C('#dfb232'), lit=C('#f0cf58'), hi=C('#fbefb4'), cap=C('#8a6e26')),
        ),
    )


class Cau:
    """seed picks the shape; bunches: list of (colour, nuts) hung under the crown shaft"""
    def __init__(self, seed, pa, bunches=(('green', 14),), yellow=False):
        self.pa = pa
        r = self.rng = np.random.default_rng(seed * 1931 + 7)
        self.items = []; self.nutitems = []; self.late = []
        self.T = tones()
        sign = 1 if seed % 2 == 0 else -1
        q = seed % 4
        # 0 straight, 1 a gentle lean, 2 young and shorter with a fuller crown, 3 the tallest with a slight S-bend
        lean = [0.1, 0.34, 0.06, 0.2][q]
        ly = [0.05, -0.08, 0.0, 0.06][q]
        self.H = [3.5, 3.75, 2.95, 4.05][q]
        self.wamp = [0.0, 0.0, 0.0, 0.07][q]
        self.Ls = [0.6, 0.62, 0.54, 0.64][q]          # crown shaft length
        self.fscale = [1.0, 1.0, 0.95, 1.04][q]
        self.nf = [9, 9, 10, 10][q]
        self.lift = [0.0, -0.04, 0.08, 0.0][q]
        self.lx, self.ly = lean * sign, ly
        self._trunk(r)
        self._shaft()
        self._crown(r, yellow)
        for k, (col, n) in enumerate(bunches): self._bunch(r, col, n, k, len(bunches))

    # ------------------------------------------------------------- trunk
    def X(self, s):
        # straight out of the ground, the lean only starts above the foot
        if not hasattr(self, '_gt'):
            t = np.linspace(0, 1, 401)
            ramp = np.clip(t / 0.12, 0, 1); ramp = ramp * ramp * (3 - 2 * ramp)
            dg = (1.4 - 0.9 * t) * ramp; dw = self.wamp * math.pi * 1.4 * np.cos(math.pi * t * 1.4) * ramp
            G = np.concatenate([[0], np.cumsum((dg[1:] + dg[:-1]) / 2 * np.diff(t))]); G /= G[-1]
            Wc = np.concatenate([[0], np.cumsum((dw[1:] + dw[:-1]) / 2 * np.diff(t))])
            self._gt = (t, G, Wc)
        t, G, Wc = self._gt
        g = float(np.interp(s, t, G)); w = float(np.interp(s, t, Wc))
        return np.array([self.lx * g + w * (-self.ly), self.ly * g + w * self.lx * 0.3, self.H * s])

    def Tn(self, s):
        return nv(self.X(min(1, s + 0.01)) - self.X(max(0, s - 0.01)))

    def rad(self, s):
        z = s * self.H
        return 0.09 + 0.018 * (1 - s) + 0.05 * math.exp(-z / 0.13)

    def tcol(self, key, s):
        """trunk colour at height s: grey below, turning grey-green over the top quarter"""
        g = min(1.0, max(0.0, (s - 0.68) / 0.3)); g = g * g * (3 - 2 * g)
        return mixc(self.T['trunk'][key], self.T['young'][key], g)

    def _trunk(self, r):
        pa = self.pa; T = self.T
        m = 72
        ss = np.linspace(0, 1, m + 1)
        # leaf-scar rings, nearly even, a little wider apart up the trunk
        rings = []; s = 0.04 + r.uniform(0, 0.01)
        while s < 0.975:
            rings.append((s, r.uniform(0.0, 0.12), r.random() < 0.2))
            s += (0.135 + 0.03 * s) * r.uniform(0.86, 1.14) / self.H
        roots = []
        for k in range(5):
            ph = math.pi * (0.16 + 0.68 * k / 4) + r.normal(0, 0.08)
            roots.append((ph, r.uniform(0.6, 1.0), r.uniform(0.8, 1.0)))
        def draw():
            P = pa.P
            pts = np.array([P(self.X(q)) for q in ss])
            n = len(pts)
            Lp, Rp, Cn = [], [], []
            for i in range(n):
                a = pts[max(0, i - 1)]; b = pts[min(n - 1, i + 1)]
                d = nv(b - a); nrm = np.array([-d[1], d[0]])
                w = self.rad(ss[i]) * pa.k
                Lp.append(pts[i] + nrm * w); Rp.append(pts[i] - nrm * w); Cn.append((pts[i], nrm, w))
            litL = (Cn[n // 2][1] @ SLIGHT) > 0
            sg = 1 if litL else -1
            cb = np.array(P(self.X(0.0))); rb = self.rad(0.0) * pa.k
            foot = [tuple(cb + np.array([rb * math.cos(ph), 0.5 * rb * math.sin(ph)])) for ph in np.linspace(math.pi, 0, 17)]
            body = [tuple(q) for q in Lp] + [tuple(q) for q in Rp[::-1]] + foot[1:-1]
            pa.fill(body, self.tcol('mid', 0.0))
            # the body, then a lit and a shaded band, piece by piece so the colour can turn green near the top
            def band(i, f0, f1, sgn):
                (p0, n0, w0), (p1, n1, w1) = Cn[i], Cn[i + 1]
                return [tuple(p0 + n0 * w0 * sgn * f0), tuple(p1 + n1 * w1 * sgn * f0), tuple(p1 + n1 * w1 * sgn * f1), tuple(p0 + n0 * w0 * sgn * f1)]
            for i in range(n - 1):
                sm = (ss[i] + ss[i + 1]) / 2
                pa.fill(band(i, 1.0, -1.0, 1), self.tcol('mid', sm))
                pa.fill(band(i, 0.97, 0.2, sg), self.tcol('lit', sm))
                pa.fill(band(i, 0.97, 0.48, -sg), self.tcol('dk', sm))
            pa.ctx.save(); pa.path(body); pa.ctx.clip()
            # the foot a little darker where it stands in the soil
            fb = [tuple(q) for q in foot]
            hy = pa.u(2.2)
            pa.path([(fb[0][0] - 9, fb[0][1] - hy), (fb[-1][0] + 9, fb[-1][1] - hy), (fb[-1][0] + 9, fb[-1][1] + 9), (fb[0][0] - 9, fb[0][1] + 9)])
            pa.ctx.set_source_rgba(*T['trunk']['dk'], 0.45); pa.ctx.fill()
            # the root cone: the lowest hand-width of the foot is a reddish mass of roots, streaked downward
            hr = pa.u(1.5)
            pa.path([(fb[0][0] - 9, fb[0][1] - hr), (fb[-1][0] + 9, fb[-1][1] - hr), (fb[-1][0] + 9, fb[-1][1] + 9), (fb[0][0] - 9, fb[0][1] + 9)])
            pa.ctx.set_source_rgba(*T['root'], 0.55); pa.ctx.fill()
            for k in range(7):
                x = fb[0][0] + (fb[-1][0] - fb[0][0]) * (k + 0.5) / 7
                yb = cb[1] + 0.5 * rb * math.sqrt(max(0.0, 1 - ((x - cb[0]) / rb) ** 2))
                pa.line([(x, yb - hr * 1.15), (x + pa.u(0.15) * (k - 3), yb + 2)], T['root'], pa.u(0.35), 0.7)
            # rings: the front half of each scar, a pale ridge with a thin groove under it, darker on the shaded side
            for (s0, off, faint) in rings:
                c = self.X(s0); t = self.Tn(s0); rr = self.rad(s0)
                u = nv(np.array([1.0, 0, 0]) - t[0] * t); v = np.cross(t, u)
                arc = []
                for ph in np.linspace(0, 2 * math.pi, 49):
                    dv = math.cos(ph) * u + math.sin(ph) * v
                    if dv @ TOCAM > -0.02: arc.append((ph, c + dv * rr * 1.02, float(dv @ LIGHT)))
                phs = [a for a, _, _ in arc]
                k0 = 0
                for i in range(1, len(phs)):
                    if phs[i] - phs[i - 1] > 0.3: k0 = i
                arc = arc[k0:] + arc[:k0]
                cut = int(len(arc) * off)
                arc = arc[cut:] if sg > 0 else arc[:len(arc) - cut]
                if len(arc) < 3: continue
                up = np.array([0, -pa.u(0.5)])
                rc, gc = self.tcol('ring', s0), self.tcol('groove', s0)
                # split the arc by light so the ring follows the trunk's own shading
                segs = []; cur = [arc[0]]
                cls = lambda l: 0 if l > 0.15 else 1 if l > -0.2 else 2
                for z in arc[1:]:
                    if cls(z[2]) != cls(cur[-1][2]): segs.append(cur + [z]); cur = [z]
                    else: cur.append(z)
                segs.append(cur)
                for sgm in segs:
                    kq = cls(sgm[len(sgm) // 2][2])
                    q = [np.array(P(p)) for _, p, _ in sgm]
                    ridge = [rc, mixc(rc, self.tcol('mid', s0), 0.45), mixc(rc, self.tcol('dk', s0), 0.6)][kq]
                    groove = [mixc(gc, self.tcol('lit', s0), 0.5), mixc(gc, self.tcol('mid', s0), 0.35), gc][kq]
                    a_r = 0.4 if faint else 0.75
                    pa.line([tuple(p + up) for p in q], ridge, pa.u(0.6), a_r, cap=cairo.LINE_CAP_BUTT)
                    pa.line([tuple(p) for p in q], groove, pa.u(0.3), 0.3 if faint else 0.55, cap=cairo.LINE_CAP_BUTT)
            pa.ctx.restore()
            for side in ([tuple(q) for q in Lp], [tuple(q) for q in Rp], foot):
                pa.soft_edge(side, self.tcol('mid', 0.5), close=False)
            # the root cone: short reddish roots pushing out round the foot (front half only)
            for (ph, ln, wd) in roots:
                d = np.array([math.cos(ph), math.sin(ph), 0.0])
                a3 = d * self.rad(0.0) * 0.9 + UP * 0.035 * ln
                b3 = d * self.rad(0.0) * (1.06 + 0.1 * ln) + UP * 0.0
                pa.taper([P(a3), P((a3 + b3) / 2 + UP * 0.006), P(b3)], pa.u(0.8 * wd), pa.u(0.4 * wd), T['root'], outline=T['root'])
        self.items.append((self.X(0.5) - np.array([0, 0, 1.2]), draw))

    # ------------------------------------------------------------- crown shaft (bẹ cau)
    def _shaft(self):
        t1 = self.Tn(1.0)
        b = self.X(1.0) - t1 * 0.02
        self.sb = b
        Ls = self.Ls
        sv = np.linspace(0, 1, 17)
        p3 = [b + t1 * Ls * q for q in sv]
        r0 = self.rad(1.0)
        rads = [r0 * (1.2 + 0.24 * math.sin(math.pi * min(1.0, q / 0.8)) - 0.34 * max(0.0, (q - 0.8) / 0.2)) for q in sv]
        self.cc = b + t1 * Ls
        self.srad = r0 * 1.25
        T = self.T['shaft']
        def draw():
            pa = self.pa; P = pa.P
            pp = np.array([P(q) for q in p3]); n = len(pp)
            Lp, Rp, Cn = [], [], []
            for i in range(n):
                a = pp[max(0, i - 1)]; bq = pp[min(n - 1, i + 1)]
                d = nv(bq - a); nrm = np.array([-d[1], d[0]])
                w = rads[i] * pa.k
                Lp.append(pp[i] + nrm * w); Rp.append(pp[i] - nrm * w); Cn.append((pp[i], nrm, w))
            litL = (Cn[n // 2][1] @ SLIGHT) > 0
            sg = 1 if litL else -1
            # the shaft's lower lip throws a little shade on the trunk
            c0 = pp[0]; w0 = rads[0] * pa.k
            sh = [tuple(c0 + np.array([w0 * 0.95 * math.cos(ph), 0.5 * w0 * 0.95 * math.sin(ph) + pa.u(0.5)])) for ph in np.linspace(0, math.pi, 13)]
            pa.line(sh, self.tcol('dk', 1.0), pa.u(0.9), 0.55)
            bot = [tuple(c0 + np.array([w0 * math.cos(ph), 0.5 * w0 * math.sin(ph)])) for ph in np.linspace(0, math.pi, 13)]
            ct = pp[-1]; wt = rads[-1] * pa.k
            topa = [tuple(ct + np.array([-wt * math.cos(ph), -0.5 * wt * math.sin(ph)])) for ph in np.linspace(0, math.pi, 9)]
            body = [tuple(q) for q in Lp] + topa[1:-1] + [tuple(q) for q in Rp[::-1]] + bot[1:-1]
            pa.fill(body, T['mid'])
            pa.ctx.save(); pa.path(body); pa.ctx.clip()
            band = lambda f0, f1, sgn, i0=0, i1=n: [tuple(p + nr * w * sgn * f0) for (p, nr, w) in Cn[i0:i1]] + [tuple(p + nr * w * sgn * f1) for (p, nr, w) in Cn[i0:i1][::-1]]
            pa.fill(band(1.1, 0.15, sg), T['lit'], seam=False)
            pa.fill(band(1.1, 0.45, -sg), T['dk'], seam=False)
            # the edge of the outermost sheath running up the front, and a soft gloss down the lit side
            seam = [tuple(p - nr * w * sg * (0.18 + 0.12 * (i / (n - 1)))) for i, (p, nr, w) in enumerate(Cn) if i <= n - 3]
            pa.line(seam, mixc(T['seam'], T['mid'], 0.35), pa.u(0.28), 0.8)
            gl = [tuple(p + nr * w * sg * 0.55) for (p, nr, w) in Cn[2:n - 3]]
            pa.line(gl, T['hi'], pa.u(0.45), 0.75)
            pa.ctx.restore()
            pa.soft_edge([tuple(q) for q in Lp], T['mid'], close=False)
            pa.soft_edge([tuple(q) for q in Rp], T['mid'], close=False)
            pa.soft_edge(bot, T['mid'], close=False)
        self.items.append((b + t1 * Ls * 0.45, draw))

    # ------------------------------------------------------------- crown
    def _crown(self, r, yellow):
        fronds = []
        n = self.nf
        az0 = r.uniform(0, 2 * math.pi)
        for k in range(n):
            age = k / (n - 1)
            az = az0 + k * 2.39996 + r.normal(0, 0.1)
            e0 = 1.36 - 0.88 * age + r.normal(0, 0.06) + self.lift
            D = 0.5 + 0.78 * age + r.normal(0, 0.06) - self.lift * 0.5
            Lf = (1.3 + 0.45 * min(1.0, age * 2.0)) * r.uniform(0.94, 1.05) * self.fscale
            fy = math.sin(az)
            # old low fronds don't hang straight at the viewer: they would hide the shaft and the nuts
            if age > 0.4 and fy > 0.5:
                az = math.pi / 2 - 1.0 if math.cos(az) >= 0 else math.pi / 2 + 1.0
            fronds.append(dict(az=az, e0=e0, D=D, L=Lf, age=age, kind='green', h=-0.07 * age, roll=r.normal(0, 0.15), p=1.45))
        if yellow:
            # an old frond gone yellow, hanging down beside the shaft on the side away from the lean (and the nuts)
            az = (math.pi * 0.86 if self.lx > 0 else math.pi * 0.14) + r.normal(0, 0.06)
            fronds.append(dict(az=az, e0=-0.35, D=0.85, L=1.3, age=1.0, kind='yellow', h=-0.12, roll=0.0, p=0.9))
        # the spear: the newest leaf, still closed, standing up
        fronds.append(dict(az=az0 + 1.0, e0=1.45, D=0.15, L=0.72, age=0.0, kind='spear', h=0.02, roll=0.0, p=1.5))
        for f in fronds: self._frond(r, f)

    def _frond(self, r, f):
        cc = self.cc
        A = np.array([math.cos(f['az']), math.sin(f['az']), 0.0])
        base = cc + A * (self.srad * 0.55 if f['kind'] != 'spear' else 0.0) + UP * (f['h'] - 0.03)
        m = 40
        R, Td = [base], []
        for k in range(m):
            s = k / m
            e = max(-1.45, f['e0'] - f['D'] * s ** f.get('p', 1.5))
            a = f['az'] + 0.1 * s * (1 if f['roll'] > 0 else -1)
            Ah = np.array([math.cos(a), math.sin(a), 0.0])
            d = Ah * math.cos(e) + UP * math.sin(e)
            Td.append(d); R.append(R[-1] + d * f['L'] / m)
        Td.append(Td[-1])
        R, Td = np.array(R), np.array(Td)
        at = lambda s: (R[min(m, int(round(s * m)))], Td[min(m, int(round(s * m)))])
        kind = f['kind']
        sc = f['L'] / 2.4
        s0 = 0.07 if kind != 'spear' else 0.25
        pinnae = []
        for side in (-1, 1):
            npin = int(f['L'] * 7.6)
            if kind == 'spear': npin = 7
            s = s0 + r.uniform(0, 0.02); grp = 0; goff = 0.0
            step = (0.99 - s0) / npin
            while s < 0.99:
                gap = 1.0
                if grp <= 0:
                    grp = int(r.integers(3, 6)); goff = r.normal(0, 0.08); gap = 1.3
                grp -= 1
                s += step * (gap - 1.0) * 0.6
                if s >= 0.99: break
                if not (kind != 'spear' and r.random() < (0.12 if kind == 'yellow' else 0.04)):
                    pinnae.append(self._pinna(r, f, side, s, at, sc, goff, s0))
                s += step * r.uniform(0.62, 0.9)
        def rachis_seg(sa, sb):
            xs = np.linspace(sa, sb, 13 if sa == 0 else 7)
            pts3 = [at(x)[0] for x in xs]
            ws = [(0.02 * (1 - 0.8 * x) + 0.005) * (1 - 0.6 * max(0.0, (x - 0.8) / 0.2)) + 0.045 * max(0.0, 1 - x / 0.14) ** 1.5 for x in xs]
            if kind == 'spear': ws = [0.026 * (1 - 0.75 * x) + 0.005 for x in xs]
            return pts3, ws
        for side in (-1, 1):
            grp = [p for p in pinnae if p['side'] == side]
            if grp:
                vf = float(np.mean([p['v'] for p in grp]))
                for p in grp: p['v'] = 0.7 * vf + 0.3 * p['v']
        if kind == 'green':
            sun = math.cos(f['az']) * SUNXY[0] + math.sin(f['az']) * SUNXY[1]
            em = max(-1.0, min(1.0, f['e0'] - f['D'] * 0.5 ** f.get('p', 1.5)))
            dv = 0.1 * sun + 0.08 * em
            for p in pinnae: p['v'] += dv
        cuts = [0.0, 0.3, 0.55, 0.78, 1.0001]
        for ci in range(len(cuts) - 1):
            sa, sb = cuts[ci], cuts[ci + 1]
            ps = [p for p in pinnae if sa <= p['s'] < sb]
            rs = rachis_seg(sa, min(1.0, sb + 0.01))
            key = at((sa + min(1.0, sb)) / 2)[0]
            fn = self._chunk_draw(ps, rs, kind, ci)
            self.items.append((key, fn))
            # the outer parts of fronds that reach toward the viewer go back over the nut bunches
            if ci >= 1 and kind == 'green' and math.sin(f['az']) > 0.3 and f['age'] > 0.3: self.late.append((key, fn))

    def _pinna(self, r, f, side, s, at, sc, goff, s0):
        kind = f['kind']
        p, Tt = at(s)
        Sv = nv(np.cross(Tt, UP)) if abs(Tt[2]) < 0.985 else np.array([1.0, 0, 0])
        Uf = nv(np.cross(Sv, Tt))
        roll = f['roll'] * s * side
        u = (s - s0) / (0.99 - s0)
        if kind == 'spear':
            al, be, Lp, W, hg = 0.22 + 0.08 * s, 0.25, 0.4 * (1 - 0.55 * s), 0.07, 0.04
        else:
            tip = max(0.0, (u - 0.76) / 0.24)
            # areca leaflets: broad, crowded, swept forward and held fairly high (a shallow V), tips drooping;
            # the last pair stays long and close together like a fish tail
            al = 0.6 - 0.16 * u - 0.32 * tip ** 0.8 + goff * 0.3 * (1 - tip) + r.normal(0, 0.03)
            be = 0.42 + 0.38 * u + f['age'] * 0.22 + goff * 0.35 + r.normal(0, 0.04)
            if kind == 'yellow': be += 0.35
            Lp = 0.92 * sc * float(np.interp(u, [0, 0.22, 0.55, 0.85, 1.0], [0.72, 1.0, 0.92, 0.6, 0.42])) * r.uniform(0.93, 1.06)
            W = 0.145 * sc * r.uniform(0.9, 1.1) * (1 - 0.15 * tip)
            hg = 0.26 + 0.3 * u - 0.1 * tip
        out = side * Sv * math.cos(be + roll) - Uf * math.sin(be + roll)
        dp = nv(Tt * math.cos(al) + out * math.sin(al))
        wv = nv(Tt - (Tt @ dp) * dp)
        prof = [(0.0, 0.45), (0.12, 1.0), (0.45, 0.88), (0.8, 0.48), (1.0, 0.0)]
        L, Rr = [], []
        for t, w in prof:
            q = p + dp * Lp * t - UP * Lp * hg * t * t
            L.append(q + wv * W * w * 0.5); Rr.append(q - wv * W * w * 0.5)
        nrm = nv(np.cross(dp, wv))
        if nrm @ Uf < 0: nrm = -nrm
        topv = nrm @ TOCAM > 0
        vis = nrm if topv else -nrm
        lam = float(vis @ LIGHT)
        mid = p + dp * Lp * 0.5
        hd = math.hypot(mid[0] - self.cc[0], mid[1] - self.cc[1])
        ao = 0.68 + 0.3 * min(1.0, hd / 1.3) + 0.12 * max(-1.0, min(1.0, (mid[2] - self.cc[2]) / 1.0))
        v = (0.55 + 0.45 * max(-0.3, lam)) * ao - 0.1
        return dict(s=s, side=side, pts=L + Rr[::-1][1:], top=topv, lam=lam, ao=ao, v=v, mid=mid, young=f['age'] < 0.2 or kind == 'spear')

    def _chunk_draw(self, ps, rs, kind, ci=1):
        pa = self.pa; T = self.T
        ps = sorted(ps, key=lambda z: depth(z['mid']))
        rpts, rws = rs
        ramp = T['yel'] if kind == 'yellow' else None
        def col_of(z):
            v = z['v']
            if ramp is not None:
                i = 0 if v < 0.45 else 1 if v < 0.62 else 2 if v < 0.8 else 3
                return ramp[i]
            if not z['top']:
                return T['und'][2 if z['young'] else 0 if v < 0.5 else 1 if v < 0.7 else 2]
            i = 0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4
            if z['young']: i = min(4, i + 1)
            return T['top'][i]
        cols = [col_of(z) for z in ps]
        def draw():
            P = pa.P
            polys = [[P(q) for q in z['pts']] for z in ps]
            for poly, c in zip(polys, cols):
                pa.fill(poly, c)
                pa.soft_edge(poly, c)
                pa.line([poly[0], poly[2], poly[4]], mixc(c, T['top'][0], 0.3), pa.u(0.2), 0.7)
            rp = np.array([P(q) for q in rpts], float); n = len(rp); Lr, Rr = [], []
            for i in range(n):
                a = rp[max(0, i - 1)]; b = rp[min(n - 1, i + 1)]
                d = nv(b - a); nr = np.array([-d[1], d[0]]); w = rws[i] * pa.k
                Lr.append(tuple(rp[i] + nr * w)); Rr.append(tuple(rp[i] - nr * w))
            if kind == 'yellow': rc = T['yel'][2]
            elif kind == 'spear': rc = T['top'][3]
            else: rc = T['top'][2] if ci == 0 else mixc(T['rach'], T['top'][2], 0.55)
            pa.fill(Lr + Rr[::-1], rc)
            pa.soft_edge(Lr, rc, close=False); pa.soft_edge(Rr, rc, close=False)
        return draw

    # ------------------------------------------------------------- nut bunches (buồng cau)
    def _bunch(self, r, col, nn, k, nb):
        T = self.T
        a = math.pi / 2 + (0.0 if nb == 1 else (-0.62 if k == 0 else 0.55)) + r.normal(0, 0.08) - 0.2 * np.sign(self.lx)
        A = np.array([math.cos(a), math.sin(a), 0.0])
        rr = self.rad(1.0)
        p0 = self.sb + A * rr * 0.85 + UP * (0.03 - 0.05 * k)
        p1 = p0 + A * 0.08 - UP * 0.05
        nbr = 5 if nn >= 12 else 4
        per = [nn // nbr + (1 if j < nn % nbr else 0) for j in range(nbr)]
        branches = []
        for j in range(nbr):
            ang = a + (j - (nbr - 1) / 2) * 0.42 + r.normal(0, 0.06)
            dj = np.array([math.cos(ang), math.sin(ang), 0.0])
            q1 = p1 + dj * 0.05 - UP * 0.04
            ln = r.uniform(0.85, 1.1)
            q2 = q1 + dj * 0.12 * ln - UP * 0.4 * ln
            nuts = []
            for i in range(per[j]):
                t = 0.22 + 0.78 * (i + 0.6) / per[j] + r.normal(0, 0.03)
                c = q1 + (q2 - q1) * t + dj * 0.04 + np.cross(dj, UP) * (0.034 if i % 2 else -0.034) + r.normal(0, 0.006, 3)
                cc_ = col
                if col == 'orange' and r.random() < 0.25: cc_ = 'yellow'
                if col == 'green' and r.random() < 0.12: cc_ = 'yellow'
                nuts.append(dict(c=c, r=0.062 * r.uniform(0.92, 1.06), hang=nv(dj * 0.4 - UP), col=cc_, at=q1 + (q2 - q1) * t))
            branches.append((q1, q2, nuts))
        def draw():
            pa = self.pa; P = pa.P
            st, sd = T['stalk'], T['stalk_dk']
            # the peduncle out of the shaft's foot, then the branches fanning down
            pa.taper([P(p0), P((p0 + p1) / 2 + UP * 0.012), P(p1)], pa.u(1.7), pa.u(1.2), sd, outline=sd)
            for q1, q2, nuts in branches:
                pa.taper([P(p1), P(q1), P((q1 + q2) / 2), P(q2)], pa.u(0.9), pa.u(0.45), st, outline=st)
                for z in nuts:
                    pa.line([P(z['at']), P(z['c'] - z['hang'] * z['r'] * 0.9)], sd, pa.u(0.4))
            allnuts = [z for _, _, ns in branches for z in ns]
            for z in sorted(allnuts, key=lambda z: depth(z['c'])):
                self._nut_draw(z)
        self.nutitems.append((p1, draw))

    def _nut_draw(self, z):
        pa = self.pa; P = pa.P
        N = self.T['nut'][z['col']]
        c = np.array(P(z['c'])); rr = z['r'] * pa.k
        h = np.array(P(z['c'] + z['hang'])) - c; h = h / (np.linalg.norm(h) + 1e-9)
        sdir = np.array([-h[1], h[0]])
        pts = []
        for k in range(40):
            th = k / 40 * 2 * math.pi
            x, y = math.cos(th), math.sin(th)
            wx = 0.86 - 0.18 * max(0.0, y) ** 1.5
            pts.append(tuple(c + sdir * x * rr * wx + h * y * rr * 1.36))
        pa.fill(pts, N['mid'])
        pa.ctx.save(); pa.path(pts); pa.ctx.clip()
        lt = np.array([SLIGHT[0], SLIGHT[1]])
        sh = c - lt * rr * 0.6
        pa.ctx.new_path(); pa.ctx.arc(sh[0], sh[1], rr * 1.15, 0, 2 * math.pi); pa.ctx.set_source_rgb(*N['dk'])
        pa.ctx.rectangle(-1e5, -1e5, 2e5, 2e5); pa.ctx.set_fill_rule(cairo.FILL_RULE_EVEN_ODD); pa.ctx.fill(); pa.ctx.set_fill_rule(cairo.FILL_RULE_WINDING)
        lc = c + lt * rr * 0.36
        pa.ctx.save(); pa.ctx.translate(*lc); pa.ctx.rotate(math.atan2(h[1], h[0])); pa.ctx.scale(rr * 0.7, rr * 0.5)
        pa.ctx.arc(0, 0, 1, 0, 2 * math.pi); pa.ctx.restore(); pa.ctx.set_source_rgb(*N['lit']); pa.ctx.fill()
        hc = c + lt * rr * 0.55
        pa.ctx.new_path(); pa.ctx.arc(hc[0], hc[1], rr * 0.2, 0, 2 * math.pi); pa.ctx.set_source_rgb(*N['hi']); pa.ctx.fill()
        pa.ctx.restore()
        pa.soft_edge(pts, N['mid'])
        # the little calyx cap where the nut hangs from its stalk
        cp = c - h * rr * 1.24
        cap = [tuple(cp + sdir * rr * 0.55 + h * rr * 0.12), tuple(cp - h * rr * 0.12), tuple(cp - sdir * rr * 0.55 + h * rr * 0.12), tuple(cp + h * rr * 0.36)]
        pa.fill(cap, N['cap'])

    def shadow(self):
        """the crown's shadow and a small contact shadow at the foot, one flat shape"""
        pa = self.pa; c = pa.ctx
        x, y = pa.P(np.array([self.cc[0], self.cc[1], 0.0]))
        fx, fy = pa.P(np.array([0.0, 0.0, 0.0]))
        rx = 0.82 * self.fscale * pa.k; e = 0.42; rf = 0.24 * pa.k
        for grow, al in ((1.12, 0.10), (1.0, 0.18)):
            c.new_path()
            for (cx, cy, rr) in ((x, y, rx), (fx, fy, rf)):
                c.save(); c.translate(cx, cy); c.scale(rr * grow, rr * grow * e); c.new_sub_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
            c.set_fill_rule(cairo.FILL_RULE_WINDING); c.set_source_rgba(0, 0, 0, al); c.fill()

    def paint(self):
        self.shadow()
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()
        for _, fn in sorted(self.nutitems, key=lambda z: depth(z[0])): fn()
        for _, fn in sorted(self.late, key=lambda z: depth(z[0])): fn()


# frames: the four decor palms
FRAMES = [dict(seed=0, bunches=(('green', 13),)),
          dict(seed=1, bunches=(('orange', 15),), yellow=True),
          dict(seed=2, bunches=(('green', 11),)),
          dict(seed=3, bunches=(('orange', 13), ('green', 12)))]


def render(fr, night=False, bb=(-90, -190, 90, 26)):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    f = dict(fr); seed = f.pop('seed')
    Cau(seed, pa, **f).paint()
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
    path = os.path.join(outdir, 'cau.webp')
    sheet.save(path, 'WEBP', quality=92, alpha_quality=100, method=6)
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
        sheet.save('/tmp/claude-0/g/cau_%s.png' % tag); print(sheet.size)
