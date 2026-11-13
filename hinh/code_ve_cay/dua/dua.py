# Coconut palms (cây dừa) for Nông Trại Nhỏ, built as small 3D models and painted in flat game tones (edge outlines
# only when ch.EDGE is on; off since 2026-10-31),
# the same camera, sun and night transform as the banana kit (../chuoi).
# A palm: a slender trunk that leans and curves back up, ringed with leaf scars, a swollen foot with root stubs,
# a fibrous collar under the crown, 13-15 feather fronds (the youngest a closed spear standing up, the oldest
# hanging), each frond a pale rachis with two rows of long narrow leaflets hanging in a V, and bunches of nuts
# tucked under the crown.
import math, os, sys
import numpy as np, cairo
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'chuoi'))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM

RS, SS = 9, 2
PX = RS * SS
KU = 29.0
UP = np.array([0, 0, 1.0])
S0N = 0.06                                   # where the leaflets start along a frond (was 0.2: bare spokes)
SUNXY = nv(np.array([LIGHT[0], LIGHT[1]]))   # the sun's direction on the ground


def tones():
    return dict(
        top=[C('#2f6f22'), C('#3d8a28'), C('#55a531'), C('#74bf3e'), C('#98d457')],
        und=[C('#5f8d3c'), C('#7aa64d'), C('#97be66')],
        yel=[C('#9a9a34'), C('#b6b443'), C('#cfc95c'), C('#e2da7a')],
        dry=[C('#8a6a38'), C('#a8864c'), C('#c4a466')],
        out=C('#1e4a16'), yout=C('#5a5418'), dout=C('#4e3818'),
        rach=C('#a6c25c'), rach_dk=C('#76983f'), rach_out=C('#284c16'),
        trunk=dict(lit=C('#cbb894'), mid=C('#a8926e'), dk=C('#7c6a4f'), scar=C('#5b4a35'), ridge=C('#ddd0b2'), out=C('#43362a')),
        fib=dict(base=C('#9c7848'), lit=C('#c39a5e'), dk=C('#6b4f2c'), out=C('#3f2c16')),
        nut=dict(dk=C('#4c7d22'), mid=C('#76a836'), lit=C('#a2cb52'), hi=C('#d2ea92'), out=C('#2a4712')),
        nutb=dict(dk=C('#6b4520'), mid=C('#966331'), lit=C('#bd8746'), hi=C('#dcb47a'), out=C('#42270e')),
        cal=C('#7a5a2a'), cal_out=C('#3a2810'),
    )


class Palm:
    """seed picks the shape (lean, height, frond layout); nuts: number of nuts (0 = none)"""
    def __init__(self, seed, pa, nuts=4, brown=0, dead=False, yellow=False):
        self.pa = pa
        r = self.rng = np.random.default_rng(seed * 977 + 13)
        self.items = []; self.nutitems = []; self.late = []; self.latepet = []; self.frpts = []
        self.T = tones()
        sign = 1 if seed % 2 == 0 else -1
        q = seed % 4
        # 0 tall and nearly straight, 1 low and bent hard like a banana, 2 young and short with an upright crown,
        # 3 the tallest, with an S-bend
        lean = [0.36, 1.0, 0.2, 0.62][q]
        ly = [0.15, -0.1, -0.2, 0.12][q]
        self.H = H = [3.95, 3.45, 2.85, 4.3][q]
        self.wamp = [0.04, 0.03, 0.02, 0.13][q]
        self.fscale = [1.0, 1.0, 0.86, 1.04][q]
        self.lift = [0.0, -0.05, 0.16, 0.0][q]
        self.ttint = [1.0, 0.94, 1.06, 0.97][q]
        self.lx, self.ly = lean * sign, ly
        self._trunk(r)
        self._crown(r, dead, yellow)
        if nuts: self._nuts(r, nuts, brown)

    # ------------------------------------------------------------- trunk
    def X(self, s):
        # the lean only starts above the foot, so the trunk stands straight up out of the ground
        if not hasattr(self, '_gt'):
            t = np.linspace(0, 1, 401)
            ramp = np.clip(t / 0.11, 0, 1); ramp = ramp * ramp * (3 - 2 * ramp)
            dg = (1.65 - 1.3 * t) * ramp; dw = self.wamp * math.pi * 1.4 * np.cos(math.pi * t * 1.4) * ramp
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
        return 0.105 + 0.05 * (1 - s) ** 1.6 + 0.085 * math.exp(-z / 0.14)

    def _trunk(self, r):
        pa = self.pa
        T = {k: tuple(min(1.0, c * self.ttint) for c in v) for k, v in self.T['trunk'].items()}
        m = 64
        ss = np.linspace(0, 1, m + 1)
        # ring scars, closer near the top, a few skipped or broken
        rings = []; s = 0.05 + r.uniform(0, 0.02)
        while s < 0.965:
            faint = r.random() < 0.22
            rings.append((s, r.uniform(0.0, 0.3), r.uniform(0.45, 0.9) if r.random() < 0.35 else 1.0, faint))
            s += (0.024 + 0.014 * (1 - s)) * r.uniform(0.55, 1.6)
        bands = [k for k in range(len(rings) - 1) if r.random() < 0.28]
        # v620 (Link's critique 2: "trunk looks like a ladder"): a separate rng (so the crown stays the same) drops
        # a fifth of the scars, fades 40% of the rest and shortens many, so the rings stop reading as rungs
        r2 = np.random.default_rng(len(rings) * 31 + int(self.H * 100))
        thin = []
        for (s0, off, part, faint) in rings:
            x = r2.random()
            if x < 0.2 and 0.12 < s0 < 0.9: continue
            thin.append((s0, off + r2.uniform(0, 0.25), min(part, r2.uniform(0.35, 1.0)) if r2.random() < 0.5 else part, faint or r2.random() < 0.4))
        rings = thin
        bands = [k for k in bands if k < len(rings) - 1]
        self.top = self.X(1.0)
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
            pa.fill(body, T['mid'])
            band = lambda f0, f1, sgn: [tuple(p + nr * w * sgn * f0) for (p, nr, w) in Cn] + [tuple(p + nr * w * sgn * f1) for (p, nr, w) in Cn[::-1]]
            pa.fill(band(0.97, 0.22, sg), T['lit'], seam=False)
            pa.fill(band(0.97, 0.5, -sg), T['dk'], seam=False)
            # ring scars: the front half of a ring round the trunk, a dark groove with a pale ridge above it
            pa.ctx.save(); pa.path(body); pa.ctx.clip()
            # weathered bands: a few gaps between scars a shade darker
            for k in bands:
                sa, sb = rings[k][0], rings[k + 1][0]
                seg = [q for q in ss if sa <= q <= sb] or [sa, sb]
                seg = [sa] + seg + [sb]
                Lb = [P(self.X(q) + np.array([0, 0, 0])) for q in seg]
                wv = [self.rad(q) * pa.k * 1.05 for q in seg]
                poly = [(x + w, y) for (x, y), w in zip(Lb, wv)] + [(x - w, y) for (x, y), w in zip(Lb[::-1], wv[::-1])]
                pa.path(poly); pa.ctx.set_source_rgba(*T['dk'], 0.3); pa.ctx.fill()
            for (s0, off, part, faint) in rings:
                c = self.X(s0); t = self.Tn(s0); rr = self.rad(s0)
                u = nv(np.array([1.0, 0, 0]) - t[0] * t); v = np.cross(t, u)
                arc = []
                for ph in np.linspace(0, 2 * math.pi, 37):
                    dv = math.cos(ph) * u + math.sin(ph) * v
                    if dv @ TOCAM > -0.05: arc.append((ph, c + dv * rr * 1.02))
                arc.sort(key=lambda z: z[0])
                # the visible arc may wrap round 0; rebuild it as one run
                phs = [a for a, _ in arc]
                k0 = 0
                for i in range(1, len(phs)):
                    if phs[i] - phs[i - 1] > 0.3: k0 = i
                arc = arc[k0:] + arc[:k0]
                q = [np.array(P(p)) for _, p in arc]
                q = q[int(len(q) * off * 0.4):]
                q = q[:max(2, int(len(q) * part))]
                up = np.array([0, -pa.u(0.55)])
                if not faint: pa.line([tuple(p + up) for p in q], mixc(T['ridge'], T['lit'], 0.5), pa.u(0.36), 0.55)
                pa.line([tuple(p) for p in q], mixc(T['dk'], T['mid'], 0.15) if faint else mixc(T['scar'], T['dk'], 0.45), pa.u(0.3 if faint else 0.4))
            pa.ctx.restore()
            if ch.EDGE:
                pa.line([tuple(q) for q in Lp], T['out'], pa.u(0.55))
                pa.line([tuple(q) for q in Rp], T['out'], pa.u(0.55))
                pa.line(foot, T['out'], pa.u(0.55))
            for side in ([tuple(q) for q in Lp], [tuple(q) for q in Rp], foot):
                pa.soft_edge(side, T['mid'], close=False)
        self.items.append((self.X(0.5) - np.array([0, 0, 1.2]), draw))

    # ------------------------------------------------------------- crown
    def _crown(self, r, dead, yellow):
        top = self.X(1.0); t1 = self.Tn(1.0)
        self.cc = cc = top + t1 * 0.02
        T = self.T
        # fibrous collar (xơ dừa) and old leaf bases wrapped round the top of the trunk
        def collar():
            pa = self.pa; P = pa.P
            # v620 (critique 3, "a brown can on the trunk"): shorter, slimmer, its brown pulled toward the trunk;
            # the frond bases now start on it and hide its top
            F = {k: mixc(v, T['trunk']['dk'], 0.55) for k, v in T['fib'].items()}   # v621: in the crown's shade
            s0 = 0.979
            sv = np.linspace(s0, 1.0, 6)
            pts = [self.X(s) for s in sv]
            rads = [self.rad(s) * (1.04 + 0.2 * (s - s0) / (1 - s0)) for s in sv]
            pp = np.array([P(q) for q in pts]); n = len(pp)
            Lp, Rp = [], []
            for i in range(n):
                a = pp[max(0, i - 1)]; b = pp[min(n - 1, i + 1)]
                d = nv(b - a); nrm = np.array([-d[1], d[0]])
                w = rads[i] * pa.k
                Lp.append(pp[i] + nrm * w); Rp.append(pp[i] - nrm * w)
            def arc(A, B, down):
                h = (A - B) / 2; c = (A + B) / 2; hn = np.linalg.norm(h)
                return [c + h * math.cos(ph) + np.array([0, hn * 0.5 * down]) * math.sin(ph) for ph in np.linspace(0, math.pi, 11)]
            topa = arc(Lp[-1], Rp[-1], -1)
            bot = arc(Lp[0], Rp[0], 1)[::-1]
            body = [tuple(q) for q in Lp] + [tuple(q) for q in topa[1:-1]] + [tuple(q) for q in Rp[::-1]] + [tuple(q) for q in bot[1:-1]]
            pa.fill(body, F['base'])
            pa.ctx.save(); pa.path(body); pa.ctx.clip()
            # the lower rim in shade, then a few loose fibre strands running round the sheath
            x0, x1 = min(q[0] for q in body), max(q[0] for q in body)
            y0, y1 = min(q[1] for q in body), max(q[1] for q in body)
            pa.path([(x0 - 9, y1 - (y1 - y0) * 0.38), (x1 + 9, y1 - (y1 - y0) * 0.3), (x1 + 9, y1 + 9), (x0 - 9, y1 + 9)])
            pa.ctx.set_source_rgb(*F['dk']); pa.ctx.fill()
            rs = np.random.default_rng(int(x0 * 7) % 997)
            for k in range(5):
                yy = y0 + (y1 - y0) * (0.15 + 0.17 * k + rs.uniform(-0.04, 0.04))
                sl = rs.uniform(-0.25, 0.25) * (x1 - x0)
                pa.line([(x0, yy), ((x0 + x1) / 2, yy + sl * 0.3 + (y1 - y0) * 0.06), (x1, yy + sl * 0.2)], F['lit'] if k % 2 else F['dk'], pa.u(0.3), 0.85)
            pa.ctx.restore()
            if ch.EDGE: pa.path(body); pa.ctx.set_source_rgb(*F['out']); pa.ctx.set_line_width(pa.u(0.5)); pa.ctx.stroke()
            pa.soft_edge(body, F['base'])
            # frayed fibre ends hanging off the lower edge, uneven
            for j in range(1, len(bot) - 1, 2):
                q = np.array(bot[j]); ln = pa.u(0.9 + 1.4 * rs.random())
                pa.line([tuple(q), tuple(q + np.array([pa.u(rs.uniform(-0.6, 0.6)), ln]))], F['out'] if ch.EDGE else F['dk'], pa.u(0.3))
        self.items.append((cc - UP * 0.05 + np.array([0, 0.02, 0]), collar))

        fronds = []
        n = int(r.integers(11, 14))
        az0 = r.uniform(0, 2 * math.pi)
        for k in range(n):
            age = k / (n - 1)
            az = az0 + k * 2.39996 + r.normal(0, 0.12)
            e0 = 1.08 - 1.25 * age + r.normal(0, 0.07) + self.lift
            D = 0.4 + 0.75 * age + r.normal(0, 0.08) - self.lift * 0.6
            Lf = (1.6 + 0.65 * min(1.0, age * 2.2)) * r.uniform(0.93, 1.05) * self.fscale
            # old low fronds don't hang straight at the viewer: that would hide the trunk
            fy = math.sin(az)
            if age > 0.45 and fy > 0.55:
                az = math.pi / 2 + (1.0 if math.cos(az) >= 0 else -1.0) * -0.95 * 1
                az = math.pi / 2 - 0.95 if math.cos(az) >= 0 else math.pi / 2 + 0.95
            kind = 'green'
            fronds.append(dict(az=az, e0=e0, D=D, L=Lf, age=age, kind=kind, h=0.1 - 0.28 * age, roll=r.normal(0, 0.18)))
        if yellow:
            # the yellowing frond: the oldest one that shows best from the viewer's side
            old = [f for f in fronds if f['age'] > 0.7]
            pick = max(old, key=lambda f: math.sin(f['az']) + 0.6 * abs(math.cos(f['az'])))
            pick['kind'] = 'yellow'
        if dead:
            # one dead frond hanging down the side of the trunk that faces the viewer
            az = (0.35 if self.lx < 0 else math.pi - 0.35) + r.normal(0, 0.15)
            fronds.append(dict(az=az, e0=-0.15, D=1.25, L=1.75, age=1.0, kind='dead', h=-0.26, roll=0.0, p=0.55))
        # the spear: the newest leaf, still closed, standing straight up
        fronds.append(dict(az=az0 + 1.0, e0=1.22, D=0.2, L=0.95, age=0.0, kind='spear', h=0.14, roll=0.0))
        for f in fronds: self._frond(r, f)

    def _frond(self, r, f):
        cc = self.cc
        A = np.array([math.cos(f['az']), math.sin(f['az']), 0.0])
        base = cc + A * (0.07 if f['kind'] != 'spear' else 0.05) + UP * f['h']
        m = 40
        R, Td = [base], []
        for k in range(m):
            s = k / m
            e = max(-1.45, f['e0'] - f['D'] * s ** f.get('p', 1.7))
            a = f['az'] + 0.12 * s * (1 if f['roll'] > 0 else -1)
            Ah = np.array([math.cos(a), math.sin(a), 0.0])
            d = Ah * math.cos(e) + UP * math.sin(e)
            Td.append(d); R.append(R[-1] + d * f['L'] / m)
        Td.append(Td[-1])
        R, Td = np.array(R), np.array(Td)
        if f['kind'] in ('green', 'yellow'): self.frpts.append(R)
        at = lambda s: (R[min(m, int(round(s * m)))], Td[min(m, int(round(s * m)))])
        kind = f['kind']
        sc = f['L'] / 2.6
        s0 = 0.2 if kind != 'spear' else 0.25
        # leaflets: one row each side, spacing jittered, the odd one missing, neighbours splaying in groups
        pinnae = []
        for side in (-1, 1):
            npin = int(f['L'] * (5.4 if kind != 'dead' else 6))
            if kind == 'spear': npin = 8
            s = s0 + r.uniform(0, 0.02); grp = 0; goff = 0.0
            step = (0.985 - s0) / npin
            while s < 0.985:
                gap = 1.0
                if grp <= 0:
                    grp = int(r.integers(2, 5)); goff = r.normal(0, 0.12); gap = 1.7
                grp -= 1
                s += step * (gap - 1.0) * 0.6
                if s >= 0.985: break
                if not (kind != 'spear' and r.random() < (0.18 if kind == 'dead' else 0.05)):
                    sp = s if kind == 'spear' else S0N + (s - s0) * (0.985 - S0N) / (0.985 - s0)
                    pinnae.append(self._pinna(r, f, side, sp, at, sc, goff))
                s += step * r.uniform(0.6, 0.9)
        # rachis with the petiole widening at the base
        rk = 'dead' if kind == 'dead' else 'green'
        def rachis_seg(sa, sb):
            pts3 = [at(x)[0] for x in np.linspace(sa, sb, 13 if sa == 0 else 7)]
            ws = [(0.022 * (1 - 0.8 * x) + 0.006) * (1 - 0.6 * max(0.0, (x - 0.8) / 0.2)) + 0.02 * max(0.0, 1 - x / 0.08) for x in np.linspace(sa, sb, 13 if sa == 0 else 7)]
            if kind == 'spear': ws = [0.024 * (1 - 0.7 * x) + 0.006 for x in np.linspace(sa, sb, len(pts3))]
            return pts3, ws
        for side in (-1, 1):
            grp = [p for p in pinnae if p['side'] == side]
            if grp:
                vf = float(np.mean([p['v'] for p in grp]))
                for p in grp: p['v'] = 0.7 * vf + 0.3 * p['v']
        if kind in ('green', 'yellow'):
            sun = math.cos(f['az']) * SUNXY[0] + math.sin(f['az']) * SUNXY[1]
            em = max(-1.0, min(1.0, f['e0'] - f['D'] * 0.5 ** f.get('p', 1.7)))
            dv = 0.1 * sun + 0.09 * em
            for p in pinnae: p['v'] += dv
        cuts = [0.0, 0.3, 0.52, 0.74, 1.0001]
        for ci in range(len(cuts) - 1):
            sa, sb = cuts[ci], cuts[ci + 1]
            ps = [p for p in pinnae if sa <= p['s'] < sb]
            rs = rachis_seg(sa, min(1.0, sb + 0.01))
            key = at((sa + min(1.0, sb)) / 2)[0]
            fn = self._chunk_draw(ps, rs, kind, ci)
            self.items.append((key, fn))
            # 4: the leaf bases of low fronds on the viewer's side pass in front of the nut bunch
            if ci == 0 and kind in ('green', 'yellow') and math.sin(f['az']) > 0.1 and f['age'] > 0.25:
                self.latepet.append((key, self._chunk_draw([], rachis_seg(0.0, 0.16), kind, 0)))
            # outer parts of fronds that hang toward the viewer go back over the nuts
            if ci >= 2 and kind != 'spear' and math.sin(f['az']) > 0.35: self.late.append((key, fn))

    def _pinna(self, r, f, side, s, at, sc, goff):
        kind = f['kind']
        p, Tt = at(s)
        Sv = nv(np.cross(Tt, UP)) if abs(Tt[2]) < 0.985 else nv(np.cross(Tt, np.array([math.cos(f['az']), math.sin(f['az']), 0]) * 0 + np.array([1, 0, 0])))
        Uf = nv(np.cross(Sv, Tt))                      # the frond's own "up"
        roll = f['roll'] * s * side
        u = (s - S0N) / (0.985 - S0N) * 0.98
        if kind == 'spear':
            al, be, Lp, W, hg = 0.3 + 0.1 * s, 0.3, 0.46 * (1 - 0.55 * s), 0.075, 0.06
        elif kind == 'dead':
            al = 0.38 + r.normal(0, 0.1); be = 1.25 + r.normal(0, 0.15)
            Lp = 0.42 * (0.55 + 0.45 * math.sin(math.pi * min(1, u / 0.8))) * r.uniform(0.5, 1.0); W = 0.04; hg = 0.5
        else:
            tip = max(0.0, (u - 0.72) / 0.28)
            # v621 (critique 1, "leaflets stick out every which way like thorns"): leaflets swept forward at an even
            # angle and hanging in a deeper V, the group splay and noise damped, so a frond reads as one feather;
            # (critique 2) the inner leaflets start long, covering the stalks where they meet
            al = 0.72 - 0.22 * u - 0.4 * tip ** 0.8 + goff * 0.35 * (1 - tip) + r.normal(0, 0.04) * 0.4
            be = 0.8 + 0.3 * u + f['age'] * 0.15 + goff * 0.45 + r.normal(0, 0.05) * 0.6
            Lp = 0.82 * sc * float(np.interp(u, [0, 0.28, 0.6, 0.85, 1.0], [0.82, 1.0, 0.86, 0.46, 0.13])) * r.uniform(0.92, 1.06)
            W = 0.104 * sc * r.uniform(0.9, 1.1) * (1 - 0.35 * tip); hg = 0.32 + 0.3 * u - 0.12 * tip
        out = side * Sv * math.cos(be + roll) - Uf * math.sin(be + roll)
        dp = nv(Tt * math.cos(al) + out * math.sin(al))
        wv = nv(Tt - (Tt @ dp) * dp)
        prof = [(0.0, 0.5), (0.1, 1.0), (0.45, 0.85), (0.8, 0.45), (1.0, 0.0)]
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
        ao = 0.66 + 0.3 * min(1.0, hd / 1.7) + 0.12 * max(-1.0, min(1.0, (mid[2] - self.cc[2]) / 1.2))
        v = (0.55 + 0.45 * max(-0.3, lam)) * ao - (0 if ch.EDGE else 0.1)     # no outline: a touch darker
        return dict(s=s, side=side, pts=L + Rr[::-1][1:], top=topv, lam=lam, ao=ao, v=v, mid=mid, young=f['age'] < 0.2 or kind == 'spear')

    def _chunk_draw(self, ps, rs, kind, ci=1):
        pa = self.pa; T = self.T
        ps = sorted(ps, key=lambda z: depth(z['mid']))
        rpts, rws = rs
        if kind == 'dead': out, ramp = T['dout'], T['dry']
        elif kind == 'yellow': out, ramp = T['yout'], T['yel']
        else: out, ramp = T['out'], None
        def col_of(z):
            v = z['v']
            if ramp is not None:
                i = 0 if v < 0.45 else 1 if v < 0.62 else 2 if v < 0.8 else min(3, len(ramp) - 1)
                return ramp[min(i, len(ramp) - 1)]
            if not z['top']:
                return T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            i = 0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4
            if z['young']: i = min(4, i + 1)
            return T['top'][i]
        cols = [col_of(z) for z in ps]
        def draw():
            P = pa.P
            polys = [[P(q) for q in z['pts']] for z in ps]
            for poly in (polys if ch.EDGE else []):
                pa.path(poly); pa.ctx.set_source_rgb(*out)
                pa.ctx.set_line_width(pa.u(0.46)); pa.ctx.set_line_join(cairo.LINE_JOIN_ROUND); pa.ctx.stroke()
            for poly, c in zip(polys, cols):
                pa.fill(poly, c, grow=0.0 if (ch.EDGE or ch.SOFT) else pa.u(0.46))
                pa.soft_edge(poly, c)
                # a darker crease down the leaflet so neighbours stay apart
                pa.line([poly[0], poly[2], poly[4]], mixc(c, out, 0.3), pa.u(0.2), 0.7)
            rp = [P(q) for q in rpts]
            if kind == 'dead':
                rc, ro = T['dry'][2], T['dout']
            else:
                # 1: the rachis stays close to the leaf green, darker in the shade near the crown
                rc, ro = (T['rach_dk'] if ci == 0 else T['rach']), T['rach_out']
            rp = np.array(rp, float); n = len(rp); Lr, Rr = [], []
            for i in range(n):
                a = rp[max(0, i - 1)]; b = rp[min(n - 1, i + 1)]
                d = nv(b - a); nr = np.array([-d[1], d[0]]); w = rws[i] * pa.k
                Lr.append(tuple(rp[i] + nr * w)); Rr.append(tuple(rp[i] - nr * w))
            if not ch.EDGE and kind != 'dead':
                # v621 (critique 2): stalks a leaf green, only a little lighter than the leaflets, no pale star
                rc = T['top'][2] if ci == 0 else mixc(T['rach'], T['top'][2], 0.55)
            pa.fill(Lr + Rr[::-1], rc)
            pa.soft_edge(Lr, rc, close=False); pa.soft_edge(Rr, rc, close=False)   # no cross lines at the chunk joins
            if ch.EDGE: pa.line(Lr, ro, pa.u(0.4)); pa.line(Rr, ro, pa.u(0.4))
        return draw

    # ------------------------------------------------------------- nuts
    def _nuts(self, r, n, brown):
        cc = self.cc; T = self.T
        # bunches hang from the leaf axils on the side facing the viewer
        nb = 1 if n <= 5 else 2
        per = [n] if nb == 1 else [n // 2 + n % 2, n // 2]
        bro = set(int(x) for x in r.choice(n, brown, replace=False)) if brown else set()
        idx = 0
        for b in range(nb):
            a = math.pi / 2 + (0.0 if nb == 1 else (-0.5 if b == 0 else 0.55)) + r.normal(0, 0.12) - 0.25 * np.sign(self.lx)
            A = np.array([math.cos(a), math.sin(a), 0.0])
            st0 = cc + A * 0.11 - UP * 0.05
            st1 = st0 + A * 0.13 + UP * 0.03
            hub = st1 + A * 0.04 - UP * 0.16
            nuts = []
            k = per[b]
            for j in range(k):
                # nuts packed below the end of the stalk, more of them low and to the front
                ang = a + (j - (k - 1) / 2) * (2.2 / max(1, k)) + r.normal(0, 0.12)
                ring = 0 if j % 3 == 2 and k > 3 else 1
                d = np.array([math.cos(ang), math.sin(ang), 0.0])
                c = hub + d * (0.15 if ring else 0.05) - UP * (0.12 + (0.16 if not ring else 0.0)) + r.normal(0, 0.012, 3)
                nuts.append(dict(c=c, r=0.145 * r.uniform(0.92, 1.08), hang=nv(d * 0.35 - UP), brown=idx in bro))
                idx += 1
            def draw(st0=st0, st1=st1, hub=hub, nuts=nuts):
                pa = self.pa; P = pa.P
                stalk, so = C('#bba45c'), C('#4a4018')
                # the bunch stalk (cuống buồng) arching out from between the leaf bases
                pa.taper([P(st0), P((st0 + st1) / 2 + UP * 0.04), P(st1), P(hub)], pa.u(2.0), pa.u(1.2), stalk, outline=so, ow=pa.u(0.42))
                pa.line([P(st0 + UP * 0.012), P((st0 + st1) / 2 + UP * 0.05), P(st1 + UP * 0.01)], C('#dccb8a'), pa.u(0.5), 0.9)
                # short stems from the end of the stalk to each nut
                for z in nuts:
                    top = z['c'] - z['hang'] * z['r'] * 0.85
                    if ch.EDGE: pa.line([P(hub), P((hub + top) / 2 + UP * 0.02), P(top)], so, pa.u(1.1))
                    pa.line([P(hub), P((hub + top) / 2 + UP * 0.02), P(top)], stalk, pa.u(0.55 if ch.EDGE else 0.8))
                for z in sorted(nuts, key=lambda z: depth(z['c'])):
                    self._nut_draw(z)
            self.nutitems.append((hub, draw))

    def _nut_draw(self, z):
        pa = self.pa; P = pa.P; T = self.T
        N = T['nutb'] if z['brown'] else T['nut']
        c = np.array(P(z['c'])); rr = z['r'] * pa.k
        h = np.array(P(z['c'] + z['hang'])) - c; h = h / (np.linalg.norm(h) + 1e-9)
        sdir = np.array([-h[1], h[0]])
        # egg shape: broad shoulder at the stalk end, blunt three-cornered point at the bottom
        pts = []
        for k in range(48):
            th = k / 48 * 2 * math.pi
            x, y = math.cos(th), math.sin(th)          # y along the hang direction
            wx = 1.0 - 0.16 * max(0.0, y) ** 2
            ly = 1.12 if y > 0 else 0.95
            pts.append(tuple(c + sdir * x * rr * wx + h * y * rr * ly))
        pa.fill(pts, N['mid'])
        pa.ctx.save(); pa.path(pts); pa.ctx.clip()
        lt = np.array([SLIGHT[0], SLIGHT[1]])
        sh = c - lt * rr * 0.55
        pa.ctx.new_path(); pa.ctx.arc(sh[0], sh[1], rr * 1.1, 0, 2 * math.pi); pa.ctx.set_source_rgb(*N['dk'])
        pa.ctx.rectangle(-1e5, -1e5, 2e5, 2e5); pa.ctx.set_fill_rule(cairo.FILL_RULE_EVEN_ODD); pa.ctx.fill(); pa.ctx.set_fill_rule(cairo.FILL_RULE_WINDING)
        lc = c + lt * rr * 0.38
        pa.ctx.new_path(); pa.ctx.arc(lc[0], lc[1], rr * 0.55, 0, 2 * math.pi); pa.ctx.set_source_rgb(*N['lit']); pa.ctx.fill()
        hc = c + lt * rr * 0.55
        pa.ctx.save(); pa.ctx.translate(*hc); pa.ctx.rotate(math.atan2(lt[1], lt[0]) + math.pi / 2); pa.ctx.scale(rr * 0.24, rr * 0.13)
        pa.ctx.arc(0, 0, 1, 0, 2 * math.pi); pa.ctx.restore(); pa.ctx.set_source_rgb(*N['hi']); pa.ctx.fill()
        # the faint ridge running down the nut
        pa.line([tuple(c - h * rr * 0.6 + sdir * rr * 0.1), tuple(c + sdir * rr * 0.18), tuple(c + h * rr * 1.0)], mixc(N['dk'], N['mid'], 0.4), pa.u(0.3), 0.7)
        pa.ctx.restore()
        if ch.EDGE: pa.path(pts); pa.ctx.set_source_rgb(*N['out']); pa.ctx.set_line_width(pa.u(0.48)); pa.ctx.set_line_join(cairo.LINE_JOIN_ROUND); pa.ctx.stroke()
        pa.soft_edge(pts, N['mid'])
        # calyx: a small brown star where the nut hangs from the stalk
        cp = c - h * rr * 0.92
        star = []
        for k in range(6):
            th = math.atan2(h[1], h[0]) + math.pi + (k - 2.5) * 0.42
            rad = rr * (0.42 if k % 2 == 0 else 0.26)
            star.append(tuple(cp + np.array([math.cos(th), math.sin(th)]) * rad * -1 + h * rr * 0.12))
        star = [tuple(cp)] + star
        pa.path(star)
        if ch.EDGE: pa.ctx.set_source_rgb(*T['cal_out']); pa.ctx.set_line_width(pa.u(0.36)); pa.ctx.stroke_preserve()
        pa.ctx.set_source_rgb(*T['cal']); pa.ctx.fill()
        pa.soft_edge(star, T['cal'])

    def shadow(self):
        """the crown's shadow on the ground, a plain flat ellipse drawn the way the game's vl() draws its shadows"""
        pa = self.pa; c = pa.ctx
        x, y = pa.P(np.array([self.cc[0], self.cc[1], 0.0]))
        fx, fy = pa.P(np.array([0.0, 0.0, 0.0]))
        rx = 1.0 * self.fscale * pa.k; e = 0.42; rf = 0.3 * pa.k
        # v620 (critique 1): the crown shadow and a small contact shadow at the foot are one shape (filled together,
        # so they never stack into a darker puddle); the game no longer adds its own foot shadow under the palm
        for grow, al in ((1.12, 0.10), (1.0, 0.18)):
            c.new_path()
            for (cx, cy, rr) in ((x, y, rx), (fx, fy, rf)):
                c.save(); c.translate(cx, cy); c.scale(rr * grow, rr * grow * e); c.new_sub_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
            c.set_fill_rule(cairo.FILL_RULE_WINDING); c.set_source_rgba(0, 0, 0, al); c.fill()

    def paint(self):
        self.shadow()
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()
        if self.nutitems:
            for _, fn in sorted(self.nutitems, key=lambda z: depth(z[0])): fn()
            for _, fn in sorted(self.latepet, key=lambda z: depth(z[0])): fn()
            for _, fn in sorted(self.late, key=lambda z: depth(z[0])): fn()


# frames: decor coconut seeds 0-3, then the planted fruit tree without and with nuts
FRAMES = [dict(seed=0, nuts=4), dict(seed=1, nuts=5, dead=True), dict(seed=2, nuts=5, brown=1),
          dict(seed=3, nuts=6, brown=1, yellow=True), dict(seed=0, nuts=0), dict(seed=0, nuts=9, brown=1)]


def render(fr, night=False, bb=(-110, -175, 110, 30)):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    f = dict(fr); seed = f.pop('seed')
    Palm(seed, pa, **f).paint()
    surf.flush(); ch.NIGHT = False
    return surf, bb


def to_image(surf):
    w, h = surf.get_width(), surf.get_height()
    a = np.ndarray((h, w, 4), np.uint8, surf.get_data()).copy()
    im = Image.frombuffer('RGBa', (w, h), a[:, :, [2, 1, 0, 3]].tobytes(), 'raw', 'RGBa', 0, 1)
    return im.resize((w // SS, h // SS), Image.LANCZOS).convert('RGBA')


def atlas(outdir, tabpath):
    """6 frames, day and night, cropped and packed into one webp; writes the frame table json"""
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
    path = os.path.join(outdir, 'dua.webp')
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
        sheet.save('/tmp/claude-0/g/dua_%s.png' % tag); print(sheet.size)
