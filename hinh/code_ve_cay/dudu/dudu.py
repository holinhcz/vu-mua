# Papaya trees (cây đu đủ) for Nông Trại Nhỏ, built as small 3D models and painted in flat game tones with the thin
# same-colour edge of the other new trees (ch.SOFT), with the banana kit's camera, sun and night transform (../chuoi).
# A tree: one straight soft trunk, grey-olive below and green near the top, covered in a spiral of crescent leaf
# scars; a crown of long hollow leaf stalks (young ones up, old ones out and drooping) each ending in a big palmate
# leaf of 7 deep lobes, every lobe cut again into side lobes; the fruit packed round the trunk just under the crown
# (green, turning yellow from the tip, or ripe orange) with a few small cream flowers.
import math, os, sys
import numpy as np, cairo
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'chuoi'))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM

RS, SS = 9, 2
PX = RS * SS
KU = 29.0 * 1.13                             # drawn a little larger than life, like the game's old papaya
UP = np.array([0, 0, 1.0])
SUNXY = nv(np.array([LIGHT[0], LIGHT[1]]))

# one lobe's outline (u along the lobe, w across, left side), cut into two pairs of side lobes and a pointed tip
LOBE = [(0.0, 0.05), (0.12, 0.11), (0.3, 0.27), (0.37, 0.12), (0.54, 0.25), (0.61, 0.11), (0.75, 0.16), (0.81, 0.07),
        (0.92, 0.055), (1.0, 0.0)]


def tones():
    return dict(
        top=[C('#2c6e24'), C('#3a862b'), C('#4f9f35'), C('#69b743'), C('#88cc57')],
        und=[C('#6a9a46'), C('#82b05a'), C('#9fc674')],
        yel=[C('#b8a434'), C('#d2bc44'), C('#e4cf5c'), C('#f0df80')],
        pet=dict(lit=C('#d2de8a'), mid=C('#b0c466'), dk=C('#869e48')),
        pety=dict(lit=C('#e6d77c'), mid=C('#cdbb58'), dk=C('#a89640')),
        trunk=dict(lit=C('#cfcb9f'), mid=C('#aeaa80'), dk=C('#85825e'), scar=C('#76714e'), scar_in=C('#d6d1a8')),
        young=dict(lit=C('#bccb7c'), mid=C('#98ac5a'), dk=C('#6f8644'), scar=C('#5c6a36'), scar_in=C('#b4c47c')),
        fruit=dict(
            green=dict(dk=C('#3e7824'), mid=C('#5c9a32'), lit=C('#82bd4a'), hi=C('#cde8a0')),
            ripe=dict(dk=C('#cf6f18'), mid=C('#ef9626'), lit=C('#fab848'), hi=C('#fee0a2')),
            turn=dict(dk=C('#b88e1c'), mid=C('#e2b830'), lit=C('#f2d257'), hi=C('#fbefb0')),
        ),
        stalk=C('#a6b45a'), flower=C('#f6f0d6'), flower_c=C('#e9c85a'),
    )


class Dudu:
    """seed picks the shape; fruit: list of colours ('green', 'turn', 'ripe'), one per fruit"""
    def __init__(self, seed, pa, fruit=(), yellow=False, flowers=4):
        self.pa = pa
        r = self.rng = np.random.default_rng(seed * 2711 + 5)
        self.items = []; self.backfruit = []; self.frontfruit = []; self.late = []
        self.T = tones()
        sign = 1 if seed % 2 == 0 else -1
        q = seed % 4
        # 0 medium and straight, 1 the tallest with a lean, 2 young and short with a full crown, 3 leaning the other way
        lean = [0.06, 0.22, 0.03, 0.16][q]
        ly = [0.04, -0.05, 0.0, 0.05][q]
        self.H = [2.55, 2.9, 2.05, 2.7][q]
        self.fscale = [1.0, 1.02, 0.94, 1.0][q]
        self.nl = [15, 15, 16, 14][q]
        self.lx, self.ly = lean * sign, ly
        self._trunk(r)
        self._crown(r, yellow)
        self._fruit(r, list(fruit), flowers)

    # ------------------------------------------------------------- trunk
    def X(self, s):
        if not hasattr(self, '_gt'):
            t = np.linspace(0, 1, 401)
            ramp = np.clip(t / 0.14, 0, 1); ramp = ramp * ramp * (3 - 2 * ramp)
            dg = (1.3 - 0.7 * t) * ramp
            G = np.concatenate([[0], np.cumsum((dg[1:] + dg[:-1]) / 2 * np.diff(t))]); G /= G[-1]
            self._gt = (t, G)
        t, G = self._gt
        g = float(np.interp(s, t, G))
        return np.array([self.lx * g, self.ly * g, self.H * s])

    def Tn(self, s):
        return nv(self.X(min(1, s + 0.01)) - self.X(max(0, s - 0.01)))

    def rad(self, s):
        z = s * self.H
        return 0.074 + 0.058 * (1 - s) ** 1.3 + 0.045 * math.exp(-z / 0.16)

    def tcol(self, key, s):
        g = min(1.0, max(0.0, (s - 0.62) / 0.32)); g = g * g * (3 - 2 * g)
        return mixc(self.T['trunk'][key], self.T['young'][key], g)

    def _trunk(self, r):
        pa = self.pa; T = self.T
        m = 64
        ss = np.linspace(0, 1, m + 1)
        # leaf scars on a spiral, closer together near the crown, faded low down
        scars = []; z = 0.16 + r.uniform(0, 0.03); ph = r.uniform(0, 2 * math.pi)
        while z < self.H * 0.97:
            s = z / self.H
            scars.append((s, ph, r.uniform(0.85, 1.15), s < 0.3 and r.random() < 0.5))
            ph += 2.39996 + r.normal(0, 0.08)
            z += (0.052 + 0.03 * (1 - s)) * r.uniform(0.85, 1.15)
        self.scars = scars
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
            pa.fill(body, self.tcol('mid', 0.0))
            def band(i, f0, f1, sgn):
                (p0, n0, w0), (p1, n1, w1) = Cn[i], Cn[i + 1]
                return [tuple(p0 + n0 * w0 * sgn * f0), tuple(p1 + n1 * w1 * sgn * f0), tuple(p1 + n1 * w1 * sgn * f1), tuple(p0 + n0 * w0 * sgn * f1)]
            for i in range(n - 1):
                sm = (ss[i] + ss[i + 1]) / 2
                pa.fill(band(i, 1.0, -1.0, 1), self.tcol('mid', sm))
                pa.fill(band(i, 0.97, 0.18, sg), self.tcol('lit', sm))
                pa.fill(band(i, 0.97, 0.45, -sg), self.tcol('dk', sm))
            pa.ctx.save(); pa.path(body); pa.ctx.clip()
            fb = [tuple(q) for q in foot]; hy = pa.u(2.0)
            pa.path([(fb[0][0] - 9, fb[0][1] - hy), (fb[-1][0] + 9, fb[-1][1] - hy), (fb[-1][0] + 9, fb[-1][1] + 9), (fb[0][0] - 9, fb[0][1] + 9)])
            pa.ctx.set_source_rgba(*T['trunk']['dk'], 0.4); pa.ctx.fill()
            # crescent scars: a dark smile with a pale inside, squeezed toward the trunk's sides
            for (s0, a0, sz, faint) in scars:
                c = self.X(s0); t = self.Tn(s0); rr = self.rad(s0)
                u = nv(np.array([1.0, 0, 0]) - t[0] * t); v = np.cross(t, u)
                dv = math.cos(a0) * u + math.sin(a0) * v
                face = float(dv @ TOCAM)
                if face < 0.12: continue
                p = c + dv * rr
                side = nv(np.cross(t, dv))
                hw = 0.38 * rr * sz * 1.5; hh = 0.028 * sz
                pts2 = []
                for k in range(13):
                    th = math.pi * k / 12
                    pts2.append(p + side * hw * math.cos(th) - t * hh * math.sin(th) * 1.3)
                for k in range(9):
                    th = math.pi * (1 - k / 8)
                    pts2.append(p + side * hw * 0.7 * math.cos(th) - t * hh * 0.35 * math.sin(th) + t * hh * 0.25)
                q2 = [P(x) for x in pts2]
                lam = float(dv @ LIGHT)
                sc = self.tcol('scar', s0)
                if lam < -0.15: sc = mixc(sc, self.tcol('dk', s0), 0.3)
                al = (0.35 if faint else 0.8) * min(1.0, (face - 0.12) / 0.3)
                pa.path(q2); pa.ctx.set_source_rgba(*sc, al); pa.ctx.fill()
                # the pale cap above the scar (the leaf base's old ridge)
                ridge = [P(p + side * hw * 0.9 * math.cos(math.pi * k / 10) + t * hh * (0.55 + 0.25 * math.sin(math.pi * k / 10))) for k in range(11)]
                pa.line(ridge, self.tcol('scar_in', s0), pa.u(0.35), al * 0.8)
            pa.ctx.restore()
            for sd in ([tuple(q) for q in Lp], [tuple(q) for q in Rp], foot):
                pa.soft_edge(sd, self.tcol('mid', 0.5), close=False)
        self.trunk_draw = draw

    # ------------------------------------------------------------- crown
    def _crown(self, r, yellow):
        top = self.X(1.0); t1 = self.Tn(1.0)
        self.cc = cc = top + t1 * 0.02
        leaves = []
        n = self.nl
        az0 = r.uniform(0, 2 * math.pi)
        for k in range(n):
            age = k / (n - 1)
            az = az0 + k * 2.39996 + r.normal(0, 0.1)
            el = 1.05 - 1.35 * age + r.normal(0, 0.07)
            Lp = (0.34 + 0.48 * min(1.0, age * 1.5)) * r.uniform(0.92, 1.06) * self.fscale
            Ll = (0.34 + 0.32 * min(1.0, age * 1.8)) * r.uniform(0.92, 1.06) * self.fscale
            # old drooping leaves don't hang straight at the viewer: they would cover the fruit
            if age > 0.55 and math.sin(az) > 0.45:
                az = math.pi / 2 - 1.05 if math.cos(az) >= 0 else math.pi / 2 + 1.05
            leaves.append(dict(az=az, el=el, Lp=Lp, Ll=Ll, age=age, kind='green', h=-0.03 * age))
        if yellow:
            az = (math.pi * 0.9 if self.lx > 0 else math.pi * 0.1) + r.normal(0, 0.06)
            leaves.append(dict(az=az, el=-0.7, Lp=0.6, Ll=0.38, age=1.0, kind='yellow', h=-0.06))
        for f in leaves: self._leaf(r, f)

    def _leaf(self, r, f):
        T = self.T; cc = self.cc
        A = np.array([math.cos(f['az']), math.sin(f['az']), 0.0])
        base = cc + A * self.rad(1.0) * 0.6 + UP * f['h']
        # the stalk: rises at el, then bends down a little toward the leaf
        m = 14; P3 = [base]; d = None
        for k in range(m):
            s = k / m
            e = f['el'] - (0.35 + 0.25 * f['age']) * s ** 1.6
            d = A * math.cos(e) + UP * math.sin(e)
            P3.append(P3[-1] + d * f['Lp'] / m)
        tip = P3[-1]
        kind = f['kind']
        pet = T['pety'] if kind == 'yellow' else T['pet']
        wbase = 0.026 if kind != 'yellow' else 0.022
        def pdraw(P3=P3, pet=pet):
            pa = self.pa; P = pa.P
            pts = [P(q) for q in P3]
            pa.taper(pts, pa.u(wbase * KU * 2), pa.u(wbase * KU * 1.2), pet['mid'], outline=pet['mid'])
            pa.line(pts[1:-1], pet['lit'], pa.u(wbase * KU * 0.5), 0.8)
        self.items.append(((base + tip) / 2, pdraw))
        # the blade: 7 lobes fanned round the stalk's end, each drooping, the edges curled down a little
        F = nv(np.array([d[0], d[1], 0.0])) if abs(d[2]) < 0.98 else A
        S = np.cross(UP, F)
        tilt = 0.35 - 0.6 * f['age'] + (0.0 if kind != 'yellow' else -0.6)
        N0 = nv(UP * math.cos(tilt) - F * math.sin(tilt))
        Fp = nv(F - (F @ N0) * N0); Sp = nv(np.cross(N0, Fp))
        L = f['Ll']
        lobes = []
        angs = [0.0, 0.62, -0.62, 1.22, -1.22, 1.9, -1.9]
        lens = [1.0, 0.92, 0.92, 0.78, 0.78, 0.55, 0.55]
        droop = 0.32 + 0.38 * f['age'] + (0.15 if kind == 'yellow' else 0.0)
        for j, (ang, ln) in enumerate(zip(angs, lens)):
            ang += r.normal(0, 0.05); ln *= r.uniform(0.92, 1.06)
            dr = nv(Fp * math.cos(ang) + Sp * math.sin(ang))
            sd = nv(np.cross(N0, dr))
            Lj = L * ln
            def P3d(u, w, dr=dr, sd=sd, Lj=Lj):
                return tip + dr * u * Lj + sd * w * Lj + N0 * (0.12 * u - droop * u * u - 0.25 * abs(w)) * Lj
            jit = [r.normal(0, 0.012) for _ in LOBE]
            left = [P3d(u, w * (1 + jit[i] * 3)) for i, (u, w) in enumerate(LOBE)]
            right = [P3d(u, -w * (1 + jit[-1 - i] * 3)) for i, (u, w) in enumerate(LOBE)]
            poly = left + right[::-1][1:]
            # normal half-way out, for the light and to know which face we see
            tg = nv(P3d(0.55, 0) - P3d(0.45, 0)); nrm = nv(np.cross(tg, sd))
            if nrm @ N0 < 0: nrm = -nrm
            topv = nrm @ TOCAM > 0
            vis = nrm if topv else -nrm
            lam = float(vis @ LIGHT)
            mid = P3d(0.5, 0)
            hd = math.hypot(mid[0] - cc[0], mid[1] - cc[1])
            ao = 0.72 + 0.26 * min(1.0, hd / 1.1) + 0.1 * max(-1.0, min(1.0, (mid[2] - cc[2]) / 0.8))
            v = (0.55 + 0.45 * max(-0.3, lam)) * ao - 0.08
            vein = [P3d(u, 0) for u in (0.0, 0.3, 0.6, 0.85)]
            sv = [(P3d(0.12, 0), P3d(0.3, 0.24)), (P3d(0.12, 0), P3d(0.3, -0.24)), (P3d(0.38, 0), P3d(0.54, 0.22)), (P3d(0.38, 0), P3d(0.54, -0.22))]
            lobes.append(dict(poly=poly, top=topv, v=v, mid=mid, vein=vein, sv=sv))
        # one tone per leaf, a little per lobe
        vm = float(np.mean([z['v'] for z in lobes]))
        sun = math.cos(f['az']) * SUNXY[0] + math.sin(f['az']) * SUNXY[1]
        for z in lobes: z['v'] = 0.65 * vm + 0.35 * z['v'] + 0.06 * sun + 0.05 * (1 - f['age'])
        def col_of(z):
            v = z['v']
            if kind == 'yellow':
                return T['yel'][0 if v < 0.45 else 1 if v < 0.62 else 2 if v < 0.8 else 3]
            if not z['top']: return T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            return T['top'][0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4]
        lobes.sort(key=lambda z: depth(z['mid']))
        cols = [col_of(z) for z in lobes]
        def ldraw(lobes=lobes, cols=cols, pet=pet):
            pa = self.pa; P = pa.P
            for z, c in zip(lobes, cols):
                poly = [P(q) for q in z['poly']]
                pa.fill(poly, c)
                pa.soft_edge(poly, c)
                vc = mixc(c, pet['lit'], 0.45)
                pa.line([P(q) for q in z['vein']], vc, pa.u(0.36), 0.9)
                for a3, b3 in z['sv']:
                    pa.line([P(a3), P(b3)], vc, pa.u(0.22), 0.75)
            # the stalk's end where the lobes meet
            pa.ctx.new_path(); c0 = P(tip); pa.ctx.arc(c0[0], c0[1], pa.u(0.6), 0, 2 * math.pi)
            pa.ctx.set_source_rgb(*pet['mid']); pa.ctx.fill()
        key = tip + UP * 0.02
        self.items.append((key, ldraw))
        if f['age'] > 0.7 and math.sin(f['az']) > 0.35 and kind == 'green': self.late.append((key, ldraw))

    # ------------------------------------------------------------- fruit
    def _fruit(self, r, fruit, flowers):
        T = self.T
        n = len(fruit)
        spots = []
        # packed round the trunk under the crown, in tiers; more of them on the viewer's half
        per = 4
        nt = max(1, math.ceil(n / per))
        for ti in range(nt):
            cnt = min(per, n - ti * per)
            s = 0.965 - ti * 0.095 / (self.H / 2.8)
            for j in range(cnt):
                x = (j - (cnt - 1) / 2) / max(1.0, (per - 1) / 2)
                a = math.pi / 2 + x * 1.25 + (0.32 if ti % 2 else 0.0) + r.normal(0, 0.07)
                spots.append((s + r.normal(0, 0.006), a))
        # the lowest tier is drawn first so the upper fruit sit over it
        spots.sort(key=lambda z: z[0])
        for i, col in enumerate(fruit):
            s, a = spots[i]
            c0 = self.X(s); rr = self.rad(s)
            A = np.array([math.cos(a), math.sin(a), 0.0])
            Lf = 0.32 * r.uniform(0.9, 1.08) * (0.86 if col == 'green' and s > 0.95 else 1.0)
            rf = 0.112 * r.uniform(0.92, 1.06)
            axis = nv(-UP + A * 0.3)
            top = c0 + A * (rr + rf * 0.75) + UP * 0.02
            cen = top + axis * Lf * 0.5
            z = dict(top=top, cen=cen, axis=axis, L=Lf, r=rf, col=col, A=A, root=c0 + A * rr * 0.9)
            (self.frontfruit if math.sin(a) > -0.05 else self.backfruit).append(z)
        self.flowers = []
        for i in range(flowers):
            a = math.pi / 2 + r.uniform(-1.3, 1.3)
            s = r.uniform(0.95, 0.995)
            A = np.array([math.cos(a), math.sin(a), 0.0])
            self.flowers.append(self.X(s) + A * (self.rad(s) + 0.03) + UP * r.uniform(0.0, 0.04))

    def _fruit_draw(self, z):
        pa = self.pa; P = pa.P; T = self.T
        F = T['fruit']
        c = np.array(P(z['cen'])); rr = z['r'] * pa.k
        h = np.array(P(z['cen'] + z['axis'])) - c; h = h / (np.linalg.norm(h) + 1e-9)
        sd = np.array([-h[1], h[0]])
        half = z['L'] * 0.5 * pa.k
        # an oval a little fuller toward the tip, rounded at both ends
        prof = lambda t: rr * (0.8 + 0.2 * t) * math.sin(math.pi * (0.03 + 0.94 * t)) ** 0.55
        ts = np.linspace(0, 1, 22)
        at = lambda t, w: c + h * (t * 2 - 1) * half + sd * w
        pts = [tuple(at(t, prof(t))) for t in ts] + [tuple(at(t, -prof(t))) for t in ts[::-1]]
        lt = np.array([SLIGHT[0], SLIGHT[1]])
        so = -1 if sd @ lt > 0 else 1                  # the shaded side
        def body(N):
            pa.path(pts); pa.ctx.set_source_rgb(*N['mid']); pa.ctx.fill()
            band = [tuple(at(t, so * prof(t) * 0.5)) for t in ts] + [tuple(at(t, so * prof(t) * 1.3)) for t in ts[::-1]]
            pa.path(band); pa.ctx.set_source_rgb(*mixc(N['mid'], N['dk'], 0.75)); pa.ctx.fill()
            lb = [tuple(at(0.06 + t * 0.86, so * prof(t) * 0.05)) for t in ts] + [tuple(at(0.06 + t * 0.86, -so * prof(t) * 0.72)) for t in ts[::-1]]
            pa.path(lb); pa.ctx.set_source_rgb(*mixc(N['mid'], N['lit'], 0.8)); pa.ctx.fill()
            g0 = at(0.36, -so * rr * 0.4)
            pa.ctx.save(); pa.ctx.translate(*g0); pa.ctx.rotate(math.atan2(h[1], h[0])); pa.ctx.scale(half * 0.3, rr * 0.12)
            pa.ctx.arc(0, 0, 1, 0, 2 * math.pi); pa.ctx.restore(); pa.ctx.set_source_rgba(*N['hi'], 0.85); pa.ctx.fill()
        def region(t0, bow):
            # everything below a gently curved line across the fruit at t0
            ln = [tuple(at(t0 + bow * (1 - x * x), x * rr * 1.4)) for x in np.linspace(-1, 1, 9)]
            return ln + [tuple(at(1.3, rr * 1.4)), tuple(at(1.3, -rr * 1.4))][::-1]
        # stalk
        pa.line([P(z['root']), P(z['top'] + UP * 0.01)], T['stalk'], pa.u(0.9))
        pa.ctx.save(); pa.path(pts); pa.ctx.clip()
        if z['col'] == 'ripe':
            body(F['ripe'])
            # a little green left round the stalk end
            pa.ctx.save(); pa.path(list(reversed(region(-0.3, 0.0))) and [tuple(at(-0.3, rr * 1.4)), tuple(at(-0.3, -rr * 1.4))] + [tuple(at(0.16 - 0.06 * (1 - x * x), x * rr * 1.4)) for x in np.linspace(-1, 1, 9)][::-1]); pa.ctx.clip()
            body({k: mixc(F['green'][k], F['ripe'][k], 0.45) for k in F['green']})
            pa.ctx.restore()
        else:
            body(F['green'])
            if z['col'] == 'turn':
                pa.ctx.save(); pa.path(region(0.64, -0.12)); pa.ctx.clip()
                body(F['turn'])
                pa.ctx.restore()
                # yellow streaks creeping up the ribs from the ripening tip
                for wq, t1 in ((-0.42, 0.34), (0.3, 0.42)):
                    st = [tuple(at(t, (wq + 0.11 * (t - 0.3)) * rr)) for t in np.linspace(t1, 0.7, 6)]
                    pa.line(st, mixc(F['turn']['mid'], F['green']['lit'], 0.25), rr * 0.22, 0.9)
        pa.ctx.restore()
        pa.soft_edge(pts, F['ripe']['mid'] if z['col'] == 'ripe' else F['green']['mid'])

    def _flower_draw(self, p):
        pa = self.pa; T = self.T
        c = np.array(pa.P(p)); rr = pa.u(0.9)
        for k in range(5):
            a = k * 2 * math.pi / 5 + 0.3
            q = c + np.array([math.cos(a), math.sin(a) * 0.8]) * rr * 0.7
            pa.ctx.new_path(); pa.ctx.arc(q[0], q[1], rr * 0.42, 0, 2 * math.pi); pa.ctx.set_source_rgb(*T['flower']); pa.ctx.fill()
        pa.ctx.new_path(); pa.ctx.arc(c[0], c[1], rr * 0.3, 0, 2 * math.pi); pa.ctx.set_source_rgb(*T['flower_c']); pa.ctx.fill()

    def shadow(self):
        pa = self.pa; c = pa.ctx
        x, y = pa.P(np.array([self.cc[0], self.cc[1], 0.0]))
        fx, fy = pa.P(np.array([0.0, 0.0, 0.0]))
        rx = 1.12 * self.fscale * pa.k; e = 0.42; rf = 0.26 * pa.k
        for grow, al in ((1.12, 0.10), (1.0, 0.18)):
            c.new_path()
            for (cx, cy, rr) in ((x, y, rx), (fx, fy, rf)):
                c.save(); c.translate(cx, cy); c.scale(rr * grow, rr * grow * e); c.new_sub_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
            c.set_fill_rule(cairo.FILL_RULE_WINDING); c.set_source_rgba(0, 0, 0, al); c.fill()

    def paint(self):
        self.shadow()
        for z in sorted(self.backfruit, key=lambda z: depth(z['cen'])): self._fruit_draw(z)
        self.trunk_draw()
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()
        for z in sorted(self.frontfruit, key=lambda z: depth(z['cen'])): self._fruit_draw(z)
        for p in self.flowers: self._flower_draw(p)
        for _, fn in sorted(self.late, key=lambda z: depth(z[0])): fn()


G, T_, R_ = 'green', 'turn', 'ripe'
# frames: decor papaya seeds 0-3, then the planted fruit tree growing (green fruit) and ready (ripe fruit)
FRAMES = [dict(seed=0, fruit=[T_, R_, T_, G, G, T_, G, G]),
          dict(seed=1, fruit=[G, R_, R_, T_, G, R_, T_, G, G, T_], yellow=True),
          dict(seed=2, fruit=[G, G, G, G], flowers=6),
          dict(seed=3, fruit=[R_, T_, G, R_, G, G, T_], yellow=True),
          dict(seed=0, fruit=[G] * 9),
          dict(seed=0, fruit=[R_, R_, T_, R_, R_, T_, R_, R_, T_])]


def render(fr, night=False, bb=(-90, -165, 90, 26)):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    f = dict(fr); seed = f.pop('seed')
    Dudu(seed, pa, **f).paint()
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
    path = os.path.join(outdir, 'dudu.webp')
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
        sheet.save('/tmp/claude-0/g/dudu_%s.png' % tag); print(sheet.size)
