# Cashew trees (cây điều) for Nông Trại Nhỏ, built as small 3D models and painted in flat game tones with the thin
# same-colour edge of the other new trees (ch.SOFT), with the banana kit's camera, sun and night transform (../chuoi).
# A tree: a short grey-brown trunk splitting low into 3-4 crooked limbs that spread wide, a low broad dome of
# rosettes of big oval leaves (pale midrib, a few bronze new leaves), and cashew apples (red or yellow, pear-shaped,
# the grey kidney nut hanging under each) at the lower edge of the crown. The planted tree before fruit carries
# small pink and cream flower sprays instead.
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
SUNXY = nv(np.array([LIGHT[0], LIGHT[1]]))


def tones():
    return dict(
        green=[C('#1d4f22'), C('#28662b'), C('#367f35'), C('#4c9a42'), C('#6ab452')],
        und=[C('#4a7a3c'), C('#5e9049'), C('#76a65c')],
        flush=[C('#4a8426'), C('#62992c'), C('#7cb03a'), C('#94c24a'), C('#aad25e')],
        bark=dict(lit=C('#b9a68e'), mid=C('#8f7b64'), dk=C('#66553f')),
        red=dict(dk=C('#9a2418'), mid=C('#cf3a22'), lit=C('#ee6a3e'), hi=C('#ffb08a')),
        yellow=dict(dk=C('#c27a10'), mid=C('#eba51e'), lit=C('#f8c94a'), hi=C('#fff0b0')),
        nut=dict(dk=C('#5c5634'), mid=C('#867c4c'), lit=C('#ad9f68')),
        flower=[C('#f2e6cc'), C('#e7a3a0'), C('#c96e78')], stalk=C('#7f8a4e'),
    )


class Dieu:
    """seed picks the shape; fruit: number of cashew apples (0 none); flowers: flower sprays (planted tree before fruit)"""
    def __init__(self, seed, pa, fruit=5, flowers=False, ripe_mix=0.5):
        self.pa = pa; self.seed = seed; self.fruit = fruit; self.flowers = flowers; self.mix = ripe_mix
        r = self.rng = np.random.default_rng(seed * 7919 + 23)
        self.items = []
        self.T = tones()
        q = seed % 4
        self.H = [0.62, 0.72, 0.56, 0.68][q]          # height of the low fork
        self.lean = np.array([[0.04, 0.02], [-0.05, 0.03], [0.06, -0.02], [-0.03, -0.04]][q])
        self.crown = [1.0, 1.05, 0.96, 1.02][q]
        self.nb = [3, 4, 3, 4][q]
        self._trunk(r)
        self._limbs(r)

    # ------------------------------------------------------------- trunk
    def X(self, s):
        return np.array([self.lean[0] * s, self.lean[1] * s, self.H * s])

    def rad(self, s):
        return 0.1 + 0.02 * (1 - s) + 0.05 * math.exp(-s * self.H / 0.08)

    def _trunk(self, r):
        pa = self.pa; T = self.T
        ss = np.linspace(0, 1, 13)
        def draw():
            P = pa.P
            pts = np.array([P(self.X(q)) for q in ss]); n = len(pts)
            Lp, Rp, Cn = [], [], []
            for i in range(n):
                a = pts[max(0, i - 1)]; b = pts[min(n - 1, i + 1)]
                d = nv(b - a); nrm = np.array([-d[1], d[0]])
                w = self.rad(ss[i]) * pa.k
                Lp.append(pts[i] + nrm * w); Rp.append(pts[i] - nrm * w); Cn.append((pts[i], nrm, w))
            sg = 1 if (Cn[n // 2][1] @ SLIGHT) > 0 else -1
            cb = np.array(P(self.X(0.0))); rb = self.rad(0.0) * pa.k
            foot = [tuple(cb + np.array([rb * math.cos(a), 0.5 * rb * math.sin(a)])) for a in np.linspace(math.pi, 0, 17)]
            body = [tuple(q) for q in Lp] + [tuple(q) for q in Rp[::-1]] + foot[1:-1]
            B = T['bark']
            pa.fill(body, B['mid'])
            band = lambda f0, f1, sgn: [tuple(p + nr * w * sgn * f0) for (p, nr, w) in Cn] + [tuple(p + nr * w * sgn * f1) for (p, nr, w) in Cn[::-1]]
            pa.ctx.save(); pa.path(body); pa.ctx.clip()
            pa.fill(band(1.05, 0.25, sg), B['lit'], seam=False)
            pa.fill(band(1.05, 0.45, -sg), B['dk'], seam=False)
            # rough bark: a few short dark furrows
            for k in range(7):
                s0 = 0.1 + 0.11 * k; off = (((k * 37) % 9) / 9 - 0.5) * 1.2
                p, nr, w = Cn[min(n - 1, int(s0 * (n - 1)))]
                a = p + nr * w * off; d = np.array([-nr[1], nr[0]])
                pa.line([tuple(a), tuple(a + d * pa.u(2.2))], B['dk'], pa.u(0.3), 0.55)
            pa.ctx.restore()
            for sd in ([tuple(q) for q in Lp], [tuple(q) for q in Rp], foot):
                pa.soft_edge(sd, B['mid'], close=False)
        self.items.append((self.X(0.5) - np.array([0, 0, 1.5]), draw))

    # ------------------------------------------------------------- limbs and leaves
    def _limbs(self, r):
        top = self.X(1.0)
        rf = self.rad(1.0)
        limbs = []
        # the crown: a broad low dome the branch ends stay inside
        self.ce = np.array([top[0] * 1.5, top[1] * 1.5, self.H + 0.82 * self.crown])
        self.ra = [1.36, 1.44, 1.3, 1.4][self.seed % 4] * self.crown
        self.rb = [0.74, 0.78, 0.7, 0.76][self.seed % 4] * self.crown
        az0 = r.uniform(0, 2 * math.pi)
        for k in range(self.nb):
            az = az0 + k * 2 * math.pi / self.nb + r.normal(0, 0.25)
            tilt = 0.72 + r.normal(0, 0.08)
            d = nv(UP * math.cos(tilt) + np.array([math.cos(az), math.sin(az), 0]) * math.sin(tilt))
            L = 1.25 * r.uniform(0.92, 1.06) * self.crown
            limbs.append(self._branch(r, top - UP * 0.02, d, L, rf * 0.7, 0))
        self.tips = []; self.bpts = []
        for b in limbs: self._collect(b)
        self._fill(r)
        self._pick_fruit(r)
        for i, (p, d, lev) in enumerate(self.tips):
            self._rosette(r, p, d, lev, i)

    def _branch(self, r, p0, d, L, w0, lev):
        m = 8
        pts = [p0]; dd = d.copy()
        hz = np.array([dd[0], dd[1], 0.0])
        bend = nv(hz + np.array([r.normal(0, 0.3), r.normal(0, 0.3), 0])) if np.linalg.norm(hz) > 1e-3 else np.array([1.0, 0, 0])
        sc = np.array([1 / self.ra, 1 / self.ra, 1 / self.rb])
        for k in range(m):
            # crooked: the cashew limb zigzags a little
            dd = nv(dd + bend * 0.04 + UP * 0.01 + r.normal(0, 0.06, 3))
            nx = pts[-1] + dd * L / m
            e = (nx - self.ce) * sc
            if np.linalg.norm(e) > 0.9:
                g = nv(e * sc)
                dd = nv(dd - g * max(0.0, dd @ g) * 1.1 + UP * 0.03)
                nx = pts[-1] + dd * L / m
                if np.linalg.norm((nx - self.ce) * sc) > 1.02 and k >= 2: break
            pts.append(nx)
        node = dict(pts=pts, w0=w0, w1=w0 * 0.55, lev=lev, kids=[])
        if lev < 2:
            nk = int(r.integers(3, 5)) if lev == 0 else int(r.integers(2, 4))
            for j in range(nk):
                t = r.uniform(0.35, 0.85) if j < nk - 1 else 1.0
                mm = len(pts) - 1; i = min(mm, max(1, int(round(t * mm))))
                base = pts[i]
                dir0 = nv(pts[min(mm, i + 1)] - pts[max(0, i - 1)])
                out = np.array([base[0] - self.lean[0], base[1] - self.lean[1], 0.0])
                az = r.uniform(0, 2 * math.pi)
                side = np.array([math.cos(az), math.sin(az), 0.0])
                if np.linalg.norm(out) > 0.05: side = nv(side * 0.9 + nv(out) * 0.8)
                cd = nv(dir0 * math.cos(0.6) + nv(side - (side @ dir0) * dir0) * math.sin(0.6) + UP * 0.08)
                cl = L * r.uniform(0.5, 0.68)
                node['kids'].append(self._branch(r, base, cd, cl, node['w1'] * (0.9 if t > 0.95 else 0.7), lev + 1))
        return node

    def _collect(self, node):
        pa = self.pa; T = self.T
        pts = node['pts']; w0, w1 = node['w0'], node['w1']
        def draw(pts=pts, w0=w0, w1=w1, lev=node['lev']):
            P = pa.P
            sp = [P(q) for q in pts]
            B = T['bark']
            inner = lev > 0 or pts[0][2] > 0.9
            col = B['mid'] if lev == 0 else mixc(B['mid'], B['dk'], 0.25)
            if inner and lev > 0: col = mixc(col, mixc(B['dk'], C('#36442a'), 0.3), 0.4)
            pa.taper(sp, w0 * 2 * pa.k, w1 * 2 * pa.k, col, outline=col)
            if lev > 0: return
            arr = np.array(sp, float); n = len(arr); lit = []
            for i in range(n):
                a = arr[max(0, i - 1)]; b = arr[min(n - 1, i + 1)]
                dd = nv(b - a); nr = np.array([-dd[1], dd[0]])
                if nr @ SLIGHT < 0: nr = -nr
                w = (w0 + (w1 - w0) * i / (n - 1)) * pa.k
                lit.append(tuple(arr[i] + nr * w * 0.45))
            pa.line(lit, B['lit'], max(pa.u(0.3), (w0 + w1) * 0.35 * pa.k), 0.8)
        key = (pts[0] + pts[-1]) / 2 - (TOCAM * 0.3 if node['lev'] > 0 else 0)
        self.items.append((key, draw))
        for q in pts[2:]: self.bpts.append((q, node['lev'], (w0 + w1) / 2))
        if not node['kids'] or node['lev'] >= 1:
            d = nv(pts[-1] - pts[-3])
            self.tips.append((pts[-1], d, node['lev']))
            if node['lev'] >= 1:
                self.tips.append((pts[len(pts) // 2], d, node['lev'] + 0.5))
        elif node['lev'] == 0:
            d = nv(pts[-1] - pts[-3])
            self.tips.append((pts[int(len(pts) * 0.75)], d, 0.5))
        for k in node['kids']: self._collect(k)

    def _fill(self, r):
        """where the dome has a hole, a short spur grows from the nearest branch into it"""
        ce, ra, rb = self.ce, self.ra, self.rb
        n = 110; ga = math.pi * (3 - math.sqrt(5))
        pts = []
        for i in range(n):
            zz = 1 - 2 * (i + 0.5) / n; rr = math.sqrt(1 - zz * zz)
            if zz < -0.45: continue
            f = 0.88 if i % 3 else 0.55
            pts.append(ce + np.array([rr * math.cos(i * ga) * ra, rr * math.sin(i * ga) * ra, zz * rb]) * f)
        order = r.permutation(len(pts))
        cand = [b for b in self.bpts if b[0][2] > self.H + 0.2]
        if not cand: return
        B = np.array([b[0] for b in cand])
        for oi in order:
            sp = pts[oi]
            tp = np.array([t[0] for t in self.tips])
            if len(tp) and np.min(np.linalg.norm(tp - sp, axis=1)) < 0.36: continue
            j = int(np.argmin(np.linalg.norm(B - sp, axis=1)))
            bp, lev, w = cand[j]
            v = sp - bp; L = float(np.linalg.norm(v))
            if L < 0.05: continue
            if L > 0.6: sp = bp + v / L * 0.6; L = 0.6
            d = nv(v)
            spur = [bp, bp + d * L * 0.5 + UP * 0.04, sp]
            ww = max(0.008, w * 0.55)
            def draw(spur=spur, ww=ww):
                pa = self.pa; P = pa.P; Bk = self.T['bark']
                col = mixc(mixc(Bk['mid'], Bk['dk'], 0.3), mixc(Bk['dk'], C('#36442a'), 0.3), 0.4)
                pa.taper([P(q) for q in spur], ww * 2 * pa.k, ww * 1.1 * pa.k, col, outline=col)
            self.items.append(((bp + sp) / 2 - TOCAM * 0.3, draw))
            self.tips.append((sp, d, 2))

    def _pick_fruit(self, r):
        """fruit and flowers go on the rosettes the viewer sees: low on the crown, on the near side"""
        self.fruit_at = {}; self.flower_at = set()
        sc = []
        for i, (p, d, lev) in enumerate(self.tips):
            rel = p - self.ce
            front = rel @ np.array([0, -1.0, 0]) / self.ra      # nearer the viewer
            low = -rel[2] / self.rb
            side = abs(rel[0]) / self.ra
            if front < 0.05 or rel[2] > 0.35 * self.rb: continue
            sc.append((front * 0.8 + low * 1.2 + 0.3 * side + r.uniform(0, 0.5), i))
        sc.sort(reverse=True)
        picked = []
        for s, i in sc:
            if len(picked) >= max(self.fruit, 7 if self.flowers else 0): break
            p = self.tips[i][0]
            # keep them apart on screen
            if any(np.linalg.norm((p - self.tips[j][0])[[0, 2]]) < 0.3 for j in picked): continue
            picked.append(i)
        for k, i in enumerate(picked):
            if self.flowers: self.flower_at.add(i)
            elif k < self.fruit: self.fruit_at[i] = 'red' if r.random() < self.mix else 'yellow'
        # a few sprays on top too, where the planted tree flowers most
        if self.flowers:
            top = sorted(range(len(self.tips)), key=lambda i: -self.tips[i][0][2] - 0.5 * (self.tips[i][0] @ np.array([0, -1.0, 0])))
            for i in top[:5]: self.flower_at.add(i)

    def _rosette(self, r, c, d, lev, idx):
        """a rosette of big oval leaves round a twig end"""
        T = self.T
        nl = int(r.integers(7, 10)) if lev < 1.5 else int(r.integers(5, 8))
        cc = c + UP * 0.03
        leaves = []
        az0 = r.uniform(0, 2 * math.pi)
        hd = math.hypot(c[0] - self.ce[0], c[1] - self.ce[1])
        hz = c[2] - self.ce[2]
        hc = hz / self.rb
        ao = 0.76 + 0.14 * min(1.0, hd / self.ra) + 0.22 * max(-1.0, min(1.0, hc + 0.2))
        sun = ((c[0] - self.ce[0]) * SUNXY[0] + (c[1] - self.ce[1]) * SUNXY[1]) / (hd + 1e-6) * min(1.0, hd / 0.5)
        flush = r.random() < 0.3 and hz > 0.1
        for k in range(nl):
            az = az0 + k * 2 * math.pi / nl + r.normal(0, 0.18)
            el = r.uniform(-0.1, 0.5) if k % 2 else r.uniform(-0.6, 0.1)
            A = np.array([math.cos(az), math.sin(az), 0.0])
            Ll = 0.27 * r.uniform(0.85, 1.12); Wl = Ll * 0.56
            S = nv(np.cross(UP, A))
            ld = nv(A * math.cos(el) + UP * math.sin(el))
            sd = nv(np.cross(UP, ld)) if abs(ld[2]) < 0.99 else S
            nrm = nv(np.cross(ld, sd))
            if nrm[2] < 0: nrm = -nrm
            # obovate: narrow at the stalk, widest past the middle, a round tip
            prof = [(0.0, 0.08), (0.12, 0.42), (0.35, 0.78), (0.6, 1.0), (0.8, 0.9), (0.93, 0.6), (1.0, 0.0)]
            pt = cc + ld * 0.03
            Lp_, Rp_ = [], []
            for (t, w) in prof:
                q = pt + ld * Ll * t - UP * Ll * 0.18 * t * t
                cup = UP * Wl * 0.06 * w
                Lp_.append(q + sd * Wl * 0.5 * w + cup); Rp_.append(q - sd * Wl * 0.5 * w + cup)
            poly = Lp_ + Rp_[::-1]
            topv = nrm @ TOCAM > 0
            vis = nrm if topv else -nrm
            lam = float(vis @ LIGHT)
            v = (0.55 + 0.45 * max(-0.3, lam)) * ao + 0.08 * sun - 0.06
            mid = pt + ld * Ll * 0.5
            fam = 'flush' if (flush and k % 3 == 0) else 'green'
            leaves.append(dict(poly=poly, top=topv, v=v, mid=mid, fam=fam, rib=(pt, pt + ld * Ll * 0.88 - UP * Ll * 0.14)))
        vm = float(np.mean([z['v'] for z in leaves]))
        for z in leaves: z['v'] = 0.6 * vm + 0.4 * z['v']
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
                poly = [P(q) for q in z['poly']]
                pa.fill(poly, c)
                pa.soft_edge(poly, c)
                pa.line([P(z['rib'][0]), P(z['rib'][1])], mixc(c, C('#e8e2a0'), 0.4), pa.u(0.24), 0.8)
        self.items.append((cc + UP * 0.05, draw))
        if idx in self.fruit_at: self._apple(r, c, self.fruit_at[idx])
        if idx in self.flower_at: self._spray(r, c)

    def _apple(self, r, c, kind):
        """a cashew apple hanging under the rosette, the nut under it"""
        T = self.T; pa = self.pa
        tilt = r.normal(0, 0.18)
        top = c - UP * 0.12 + np.array([r.normal(0, 0.03), -0.1, 0])
        L = 0.24 * r.uniform(0.92, 1.08); W = 0.19 * r.uniform(0.92, 1.08)
        F = T[kind]; N = T['nut']
        def draw():
            P = pa.P; k = pa.k
            a = np.array(P(top))
            ax = np.array([math.sin(tilt), math.cos(tilt)])          # down the fruit on screen
            sx = np.array([ax[1], -ax[0]])
            # pear outline: narrow shoulder at the stalk, full round bottom
            prof = [(0.0, 0.36), (0.12, 0.56), (0.35, 0.84), (0.6, 1.0), (0.8, 0.97), (0.94, 0.74), (1.0, 0.0)]
            Lp = [a + ax * L * k * t + sx * W * k * 0.5 * w for t, w in prof]
            Rp = [a + ax * L * k * t - sx * W * k * 0.5 * w for t, w in prof]
            body = [tuple(q) for q in Lp + Rp[::-1]]
            # the stalk up into the leaves
            pa.line([tuple(a - ax * k * 0.07), tuple(a + ax * k * 0.01)], T['stalk'], pa.u(0.45))
            # the nut: a grey kidney hanging under the apple, drawn first so the apple sits on it
            nb = a + ax * L * k * 0.97
            nl, nw = 0.12 * k, 0.1 * k
            nut = []
            for j in range(19):
                th = j / 18 * 2 * math.pi
                x = math.cos(th); y = math.sin(th)
                bean = 0.45 * max(0.0, math.cos(th)) ** 4       # the kidney's dent on one side
                nut.append(tuple(nb - ax * nl * 0.12 + ax * (nl * 0.5 * (1 + y)) + sx * nw * 0.5 * (x - bean) + sx * nw * 0.18 * (1 + y)))
            pa.fill(nut, N['mid'])
            pa.ctx.save(); pa.path(nut); pa.ctx.clip()
            sl = 1 if sx @ SLIGHT > 0 else -1
            pa.path([tuple(nb + sx * sl * nw * 0.15 + ax * nl * t) for t in (0, 1)] + [tuple(nb + sx * sl * nw * 0.9 + ax * nl * t) for t in (1, 0)])
            pa.ctx.set_source_rgb(*N['lit']); pa.ctx.fill()
            pa.path([tuple(nb - sx * sl * nw * 0.2 + ax * nl * t) for t in (0, 1)] + [tuple(nb - sx * sl * nw * 0.9 + ax * nl * t) for t in (1, 0)])
            pa.ctx.set_source_rgb(*N['dk']); pa.ctx.fill()
            pa.ctx.restore()
            pa.soft_edge(nut, N['mid'])
            # the apple: flat base colour, the lit side, the shade side, one gloss spot
            pa.fill(body, F['mid'])
            pa.ctx.save(); pa.path(body); pa.ctx.clip()
            sl = 1 if sx @ SLIGHT > 0 else -1
            lit = [tuple(a + ax * L * k * t + sx * sl * W * k * 0.5 * w * f) for (t, w) in prof for f in (1.05,)] + \
                  [tuple(a + ax * L * k * t + sx * sl * W * k * 0.5 * w * 0.05) for (t, w) in prof[::-1]]
            pa.path(lit); pa.ctx.set_source_rgb(*F['lit']); pa.ctx.fill()
            dk = [tuple(a + ax * L * k * t - sx * sl * W * k * 0.5 * w * 1.05) for (t, w) in prof] + \
                 [tuple(a + ax * L * k * t - sx * sl * W * k * 0.5 * w * 0.5) for (t, w) in prof[::-1]]
            pa.path(dk); pa.ctx.set_source_rgb(*F['dk']); pa.ctx.fill()
            hc = a + ax * L * k * 0.42 + sx * sl * W * k * 0.22
            pa.ctx.save(); pa.ctx.translate(*hc); pa.ctx.rotate(math.atan2(ax[1], ax[0])); pa.ctx.scale(L * k * 0.13, W * k * 0.09)
            pa.ctx.new_path(); pa.ctx.arc(0, 0, 1, 0, 2 * math.pi); pa.ctx.restore()
            pa.ctx.set_source_rgba(*F['hi'], 0.85); pa.ctx.fill()
            pa.ctx.restore()
            pa.soft_edge(body, F['mid'])
        self.items.append((top + TOCAM * 4.0, draw))   # fruit hangs clear of the leaves: drawn last

    def _spray(self, r, c):
        """a small spray of pink and cream cashew flowers above the rosette"""
        T = self.T; pa = self.pa
        base = c + UP * 0.08
        stems = []
        for j in range(5):
            az = r.uniform(0, 2 * math.pi)
            d = nv(UP * 1.3 + np.array([math.cos(az), math.sin(az), 0]) * 0.7)
            e = base + d * 0.15 * r.uniform(0.8, 1.2)
            dots = [e + nv(np.array([r.normal(), r.normal(), abs(r.normal()) + 0.3])) * 0.045 for _ in range(4)]
            stems.append((e, dots, [int(r.integers(0, 3)) for _ in range(4)]))
        def draw():
            P = pa.P
            for e, dots, cs in stems:
                pa.line([P(base), P(e)], T['stalk'], pa.u(0.3), 0.9)
            for e, dots, cs in stems:
                for p, ci in zip(dots, cs):
                    x, y = P(p); rr = pa.u(0.9)
                    pa.ctx.new_path(); pa.ctx.arc(x, y, rr, 0, 2 * math.pi)
                    pa.ctx.set_source_rgb(*T['flower'][ci]); pa.ctx.fill()
                    pa.ctx.new_path(); pa.ctx.arc(x, y, rr * 0.35, 0, 2 * math.pi)
                    pa.ctx.set_source_rgb(*C('#d8a03a')); pa.ctx.fill()
        self.items.append((base + TOCAM * 0.3, draw))

    def shadow(self):
        pa = self.pa; c = pa.ctx
        cx, cy = pa.P(np.array([self.ce[0], self.ce[1], 0.0]))
        fx, fy = pa.P(np.array([0.0, 0.0, 0.0]))
        rx = 0.92 * self.ra * pa.k; e = 0.42; rf = 0.22 * pa.k
        for grow, al in ((1.1, 0.09), (1.0, 0.15)):
            c.new_path()
            for (x, y, rr) in ((cx, cy, rx), (fx, fy, rf)):
                c.save(); c.translate(x, y); c.scale(rr * grow, rr * grow * e); c.new_sub_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
            c.set_fill_rule(cairo.FILL_RULE_WINDING); c.set_source_rgba(0, 0, 0, al); c.fill()

    def paint(self):
        self.shadow()
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()


# frames: d0-d3 decor trees (fruit, mixed colours); d4 planted tree before fruit (flowers); d5 planted tree ripe
FRAMES = [dict(seed=0, fruit=5, ripe_mix=0.55), dict(seed=1, fruit=6, ripe_mix=0.4),
          dict(seed=2, fruit=4, ripe_mix=0.7), dict(seed=3, fruit=6, ripe_mix=0.5),
          dict(seed=1, fruit=0, flowers=True), dict(seed=1, fruit=9, ripe_mix=0.55)]


def render(fr, night=False, bb=(-80, -110, 80, 20)):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    f = dict(fr); seed = f.pop('seed')
    Dieu(seed, pa, **f).paint()
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
    path = os.path.join(outdir, 'dieu.webp')
    sheet.save(path, 'WEBP', quality=90, alpha_quality=100, method=6)
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
        sheet.save('/tmp/claude-0/g/dieu_%s.png' % tag); print(sheet.size)
