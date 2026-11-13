# Mango trees (cây xoài) for Nông Trại Nhỏ, built as small 3D models and painted in flat game tones with the thin
# same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun and night (../chuoi).
# A tree: a short thick trunk with rough dark bark that forks into spreading limbs, a dense lumpy dome of leaf clumps
# (the crown machinery of the banyan kit, ../da), each clump covered in rosettes of long narrow drooping leaves, a few
# rosettes of young copper-red leaves on top. Seed 0 is in flower (upright cream panicles over the crown), seeds 1-3
# carry 3, 4, 5 ripe golden mangoes hanging on long stalks under the crown, as the old tree did.
import math, os, sys
import numpy as np, cairo
from PIL import Image
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'dambut', 'da'): sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM
from da import Da, bez
from dambut import hull

RS, SS = 9, 2
PX = RS * SS
KU = 29.0
UP = np.array([0, 0, 1.0])
# v635: Link wants thin spots in the crown to show what is behind (ground, sky); nothing lines the inside of a clump.
# LINING = True brings back the v634 shell of dark leaves and hidden core.
LINING = False


def tones():
    return dict(
        green=[C('#29682d'), C('#367d36'), C('#489541'), C('#61ae4e'), C('#82c661')],
        und=[C('#356b3a'), C('#447d42'), C('#58914c')],
        young=[C('#86343a'), C('#a04446'), C('#b85a52'), C('#cc7462'), C('#de9076')],
        inner=C('#1d4b22'),
        deep=[C('#1f4d25'), C('#26582b'), C('#2f6432')],
        bark=dict(lit=C('#8f7e6c'), mid=C('#6a5a4b'), dk=C('#4a3e34'), fis=C('#3e332a')),
        fruit=dict(lit=C('#f8d257'), mid=C('#f0b02c'), dk=C('#d5891f'), blush=C('#e4692e'), hi=C('#fff0a6'), stalk=C('#5f6a2c')),
        pan=dict(stalk=C('#b5613f'), fl=[C('#e8cf78'), C('#f2e1a0'), C('#fbf1c8')], pink=C('#e6b39a')),
    )


class Xoai(Da):
    """seed 0 in flower, seeds 1-3 with 3, 4, 5 ripe fruit"""
    NROS = 185          # leaf rosettes on a clump of radius 0.9 (scaled by area)
    def __init__(self, seed, pa):
        self.pa = pa; self.seed = seed
        r = self.rng = np.random.default_rng(seed * 6007 + 71)
        self.items = []
        self.T = tones()
        q = seed % 4
        self.nfruit = [0, 3, 4, 5][q]
        self.lean = [0.05, -0.06, 0.03, -0.04][q]
        self.ce = np.array([self.lean, -0.04, 1.9])
        self.ra = [1.38, 1.42, 1.34, 1.4][q]
        self.ry = self.ra * 0.92
        self.rb = 0.85
        self._clumps(r)
        self._trunk(r)
        for c in self.cl: self._clump_leaves(r, c)
        if q == 0: self._panicles(r)
        else: self._fruits(r)

    def _clumps(self, r):
        ce, ra, ry, rb = self.ce, self.ra, self.ry, self.rb
        cl = []
        n0 = [5, 4, 5, 4][self.seed % 4]
        az0 = r.uniform(0, 2 * math.pi)
        for k in range(n0):
            az = az0 + k * 2 * math.pi / n0 + r.normal(0, 0.12)
            d = 0.55 * r.uniform(0.92, 1.06)
            c = ce + np.array([math.cos(az) * ra * d, math.sin(az) * ry * d, -0.25 * rb + r.normal(0, 0.04)])
            rc = r.uniform(0.6, 0.68)
            cl.append(dict(c=c, rc=rc, rz=rc * 0.62, tier=0))
        n2 = 2 if n0 == 5 else 3
        az2 = r.uniform(0, 2 * math.pi)
        for k in range(n2):
            az = az2 + k * 2 * math.pi / n2
            c = ce + np.array([math.cos(az) * ra * 0.2, math.sin(az) * ry * 0.2, 0.36 * rb + r.normal(0, 0.03)])
            rc = r.uniform(0.6, 0.66)
            cl.append(dict(c=c, rc=rc, rz=rc * 0.66, tier=2))
        # a few patches of young copper-red leaves (a flush) on the top of the crown
        self.flush = []
        for c in cl:
            if c['tier'] == 2 and r.random() < 0.8:
                a = r.uniform(0, 2 * math.pi); zz = r.uniform(0.45, 0.85); rr = math.sqrt(1 - zz * zz)
                self.flush.append(c['c'] + np.array([rr * math.cos(a) * c['rc'], rr * math.sin(a) * c['rc'], zz * c['rz']]))
        for c in cl:
            c['lumps'] = [(nv(r.normal(0, 1, 3)), r.uniform(1.4, 2.4), r.uniform(0, 6.28), r.uniform(0.05, 0.08)) for _ in range(4)]
            c['tv'] = r.uniform(-0.03, 0.03)
        self.cl = cl

    def _trunk(self, r):
        Bk = self.T['bark']
        zs = 0.52 + r.normal(0, 0.03)
        top = np.array([self.lean * 0.6, 0.0, zs])
        ss = np.linspace(0, 1, 16)
        pts = [np.array([self.lean * 0.6 * t * t + 0.02 * math.sin(t * 3), 0.01 * math.sin(t * 2.4), -0.04 + (zs + 0.04) * t]) for t in ss]
        rads = [0.15 - 0.015 * t + 0.07 * math.exp(-max(0.0, p[2]) / 0.12) for t, p in zip(ss, pts)]
        self._tube(pts, rads, np.array([0, 0, 0.5]), fiss=4, r=r)
        self.tc = np.array([0.0, 0.0]); self.tR = 0.14
        # limbs from the fork out and up into the bottom of each clump; smaller ones on up to the top clumps
        low = [c for c in self.cl if c['tier'] == 0]
        for j, c in enumerate(low):
            Tp = c['c'] - UP * c['rz'] * 0.25
            b0 = top - UP * 0.04
            hz = np.array([Tp[0] - b0[0], Tp[1] - b0[1], 0.0])
            p1 = b0 + nv(hz) * 0.16 + UP * 0.22
            p2 = b0 + hz * 0.6 + UP * 0.5
            lp = [bez(b0, p1, p2, Tp, t) for t in np.linspace(0, 1, 14)]
            w0 = 0.095 * r.uniform(0.9, 1.08)
            lr = [w0 * (1 - 0.55 * t) for t in np.linspace(0, 1, 14)]
            col = mixc(Bk['mid'], Bk['lit'], 0.1) if j % 2 == 0 else mixc(Bk['mid'], Bk['dk'], 0.1)
            self._tube(lp, lr, (b0 + Tp) / 2 - TOCAM * 0.4, fiss=1, r=r, col=col)
            for cc in [x for x in self.cl if x['tier'] == 2]:
                if r.random() < 0.6:
                    i0 = 7; s0 = lp[i0]; T2 = cc['c'] - UP * cc['rz'] * 0.3
                    mp = (s0 + T2) / 2 + UP * 0.1
                    sp_ = [bez(s0, s0 + (mp - s0) * 0.6, mp, T2, t) for t in np.linspace(0, 1, 10)]
                    self._tube(sp_, [lr[i0] * 0.6 * (1 - 0.5 * t) for t in np.linspace(0, 1, 10)], (s0 + T2) / 2 - TOCAM * 0.6, r=r)

    def _clump_leaves(self, r, c):
        """the banyan's clump, but with no round dark mass and no shade cast on the clump behind (both showed as smooth
        round patches on the crown): the inside of the clump is a shell of dark leaves, so whatever shows between the
        lit leaves is leaves too and every edge is a leafy edge"""
        T = self.T; pa = self.pa
        n = int(self.NROS * (c['rc'] / 0.9) ** 2)
        ga = math.pi * (3 - math.sqrt(5))
        zmin = -0.62 if c['tier'] == 0 else -0.4
        later = [o for o in self.cl if o is not c and depth(o['c']) > depth(c['c'])]
        spots = []
        for i in range(n):
            zz = 1 - 2 * (i + 0.5) / n; rr = math.sqrt(max(0.0, 1 - zz * zz))
            if zz < zmin: continue
            d = np.array([rr * math.cos(i * ga), rr * math.sin(i * ga), zz])
            p = self.env(c, d, r.uniform(0.94, 1.03) if i % 4 else r.uniform(0.82, 0.9))
            if any(self.inside(o, p, 0.86) for o in later): continue
            spots.append((p, d))
        G = (c['c'][2] - self.ce[2]) / self.rb
        clusters = []
        for p, d in spots:
            nrm = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            clusters.append(self._cluster(r, c, p, nrm, d[2], G))
        # the dark inside: a second, smaller shell of dark leaves (own random stream, so the lit leaves stay put)
        rd = np.random.default_rng(int(abs(c['c'][0] * 1000) + abs(c['c'][1] * 7000)) + self.seed * 131)
        nd = int(n * 0.7) if LINING else 0
        deep = []
        for i in range(nd):
            zz = 1 - 2 * (i + 0.5) / nd; rr = math.sqrt(max(0.0, 1 - zz * zz))
            if zz < zmin - 0.08: continue
            d = np.array([rr * math.cos(i * ga + 1.3), rr * math.sin(i * ga + 1.3), zz])
            p = self.env(c, d, rd.uniform(0.74, 0.82))
            if any(self.inside(o, p, 0.8) for o in later): continue
            nrm = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            deep.append(self._cluster(rd, c, p, nrm, d[2], G, dark=True))
        # a small hidden core so no sky shows through the middle; it sits well inside the dark leaves
        core = []
        for th in np.linspace(0, math.pi, 13):
            for ph in np.linspace(0, 2 * math.pi, 21):
                d = np.array([math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)])
                if d[2] < zmin + 0.1: continue
                core.append(self.env(c, d, 0.56))
        def draw():
            P = pa.P
            if LINING: pa.fill(hull([P(q) for q in core]), T['deep'][0])
            dv = [z for cl in deep for z in cl]
            allv = [z for cl in clusters for z in cl]
            dv.sort(key=lambda z: depth(z['mid']))
            for z in dv:
                poly = [P(q) for q in z['poly']]
                pa.fill(poly, z['col']); pa.soft_edge(poly, z['col'])
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

    def _cluster(self, r, c, p, ns, hc, G, dark=False):
        """a rosette of long narrow leaves drooping from a twig end; a few young copper rosettes on the top clumps"""
        T = self.T
        nrm0 = nv(ns + UP * 0.6)
        t1 = np.cross(nrm0, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(nrm0, t1)
        sun = float(ns @ LIGHT)
        ao = 0.72 + 0.3 * max(-1.0, min(1.0, hc)) + 0.12 * G
        young = (not dark) and any(np.linalg.norm(p - f) < 0.2 for f in self.flush)
        nl = int(r.integers(5, 8))
        az0 = r.uniform(0, 2 * math.pi)
        leaves = []
        for k in range(nl):
            az = az0 + k * 2 * math.pi / nl + r.normal(0, 0.35)
            A = math.cos(az) * t1 + math.sin(az) * t2
            el = r.uniform(-0.1, 0.4)
            ld = nv(A * math.cos(el) + nrm0 * math.sin(el) - UP * (0.9 if young else 0.28))
            sd = nv(np.cross(nrm0, ld))
            Ll = 0.21 * r.uniform(0.85, 1.12) * (0.85 if young else 1.0); Wl = Ll * 0.27
            pt = p + (r.normal(0, 1, 3) * np.array([1, 1, 0.5])) * 0.02 + ld * 0.01
            # lanceolate: narrow base, widest a third of the way, long pointed tip, drooping along its length
            prof = [(0.0, 0.1), (0.1, 0.55), (0.28, 0.95), (0.42, 1.0), (0.6, 0.86), (0.78, 0.58), (0.92, 0.26), (1.0, 0.0)]
            Lp_, Rp_ = [], []
            for (t, w) in prof:
                q = pt + ld * Ll * t - UP * Ll * 0.22 * t * t
                Lp_.append(q + sd * Wl * 0.5 * w); Rp_.append(q - sd * Wl * 0.5 * w)
            nn = nv(np.cross(ld, sd))
            if nn @ nrm0 < 0: nn = -nn
            topv = nn @ TOCAM > 0
            lam = float((nn if topv else -nn) @ LIGHT)
            v = (0.62 + 0.3 * max(-0.3, lam)) * ao + 0.2 * sun - 0.06
            leaves.append(dict(poly=Lp_ + Rp_[::-1], top=topv, v=v, lam=lam, mid=pt + ld * Ll * 0.5,
                               rib=(pt, pt + ld * Ll * 0.88 - UP * Ll * 0.17)))
        vm = float(np.mean([z['v'] for z in leaves]))
        for z in leaves:
            v = 0.6 * vm + 0.4 * z['v'] + c['tv']
            if dark:
                z['col'] = T['deep'][0 if v < 0.5 else 1 if v < 0.68 else 2]
            elif young:
                z['col'] = T['young'][max(0, min(4, int((v - 0.35) / 0.12)))]
            elif not z['top']:
                z['col'] = T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            else:
                z['col'] = T['green'][0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4]
            z['gloss'] = z['top'] and z['lam'] > 0.5 and v > 0.7 and not young and not dark
        return leaves

    # ------------------------------------------------------------- flowers (seed 0)
    def _panicles(self, r):
        T = self.T; Pn = T['pan']
        spots = []
        for c in self.cl:
            m = 9 if c['tier'] == 2 else 5
            for _ in range(m * 3):
                a = r.uniform(0, 2 * math.pi); zz = r.uniform(0.15, 0.9); rr = math.sqrt(1 - zz * zz)
                d = np.array([rr * math.cos(a), rr * math.sin(a), zz])
                p = self.env(c, d, 1.0)
                if any(self.inside(o, p, 0.9) for o in self.cl if o is not c): continue
                if d[1] < -0.6 and c['tier'] == 0: continue
                spots.append((p, d, c))
        r.shuffle(spots)
        picked = []
        for p, d, c in spots:
            sp = np.array(self.pa.P(p)) / self.pa.k
            if any(np.linalg.norm(sp - q) < 0.3 for q in picked): continue
            picked.append(sp)
            if len(picked) > 19: break
            ns = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            ax = nv(UP + ns * 0.45 + r.normal(0, 0.12, 3))
            L = r.uniform(0.26, 0.36)
            base = p - ax * 0.03
            # side branchlets, shorter toward the tip; each ends in a small knot of flowers
            fl = []
            for t in np.linspace(0.1, 0.95, 11):
                q0 = base + ax * L * t
                for sgn in (1, -1):
                    az = r.uniform(0, 2 * math.pi)
                    sd = nv(np.cross(ax, np.array([math.cos(az), math.sin(az), 0.0])))
                    ln = 0.085 * (1 - t) ** 1.1 + 0.012
                    q1 = q0 + sd * ln * sgn + ax * ln * 0.4
                    fl.append((q0, q1))
            lit = float(ns @ LIGHT)
            def draw(base=base, ax=ax, L=L, fl=fl, lit=lit, rr=np.random.default_rng(int(r.integers(1, 1 << 30)))):
                pa = self.pa; P = pa.P
                pa.line([P(base), P(base + ax * L)], Pn['stalk'], pa.u(0.4))
                for q0, q1 in fl: pa.line([P(q0), P(q1)], Pn['stalk'], pa.u(0.25), 0.9)
                dots = []
                for q0, q1 in fl:
                    for j in range(4):
                        q = q0 + (q1 - q0) * rr.uniform(0.3, 1.0) + rr.normal(0, 0.01, 3)
                        dots.append(q)
                dots.append(base + ax * L * 1.02)
                dots.sort(key=depth)
                for q in dots:
                    x, y = P(q)
                    sx, sy = np.array(P(q)) - np.array(P(base + ax * L * 0.5))
                    side = -(sx * SLIGHT[0] + sy * SLIGHT[1]) / (pa.k * 0.1 + 1e-6)
                    k = 2 if side < -0.4 else 1 if side < 0.5 else 0
                    if lit < -0.2: k = min(2, k + 1)
                    col = Pn['fl'][2 - k] if rr.random() > 0.12 else Pn['pink']
                    pa.ctx.new_path(); pa.ctx.arc(x, y, pa.u(0.5), 0, 2 * math.pi); pa.ctx.set_source_rgb(*col); pa.ctx.fill()
            self.items.append((p + TOCAM * 0.2, draw))

    # ------------------------------------------------------------- fruit (seeds 1-3)
    def _fruits(self, r):
        T = self.T; F = T['fruit']
        low = [c for c in self.cl if c['tier'] == 0]
        n = self.nfruit
        xs = np.linspace(-0.7, 0.7, n) + r.normal(0, 0.08, n)
        for j, x in enumerate(xs):
            # under the front half of the crown, a little inside its edge
            y = r.uniform(0.45, 0.75) * (1 - abs(x) * 0.4)
            best = min(low, key=lambda c: (c['c'][0] - x) ** 2 + (c['c'][1] - y) ** 2)
            zb = best['c'][2] - best['rz'] * r.uniform(0.55, 0.8)
            top = np.array([self.ce[0] + x, y + r.uniform(-0.05, 0.12), zb])
            sl = r.uniform(0.08, 0.26)
            tilt = r.normal(0, 0.18)
            bot = top + np.array([math.sin(tilt) * sl, 0.02, -sl * math.cos(tilt)])
            green = j == 1 and n >= 4
            flip = 1 if r.random() < 0.5 else -1
            ang = r.normal(0, 0.12)
            def draw(top=top, bot=bot, green=green, flip=flip, ang=ang):
                pa = self.pa; P = pa.P; k = pa.k
                a0 = np.array(P(top)); a1 = np.array(P(bot))
                mid = (a0 + a1) / 2 + np.array([flip * 0.012 * k, 0])
                pa.ctx.new_path(); pa.ctx.move_to(*a0); pa.ctx.curve_to(*mid, *mid, *a1)
                pa.ctx.set_source_rgb(*F['stalk']); pa.ctx.set_line_width(pa.u(0.36)); pa.ctx.stroke()
                ax = np.array([math.sin(ang), math.cos(ang)]); sx = np.array([ax[1], -ax[0]]) * flip
                Lf, Wf = 0.3 * k, 0.205 * k
                # a mango: full shoulder at the stalk, the belly on one side, a little beak near the tip
                out, inn = [], []
                for t in np.linspace(0, 1, 15):
                    w = max(0.0, 1 - abs(2 * t - 1) ** 2.6) ** 0.5 * (1 - 0.18 * t)
                    o = Wf * 0.56 * w * (1.0 + 0.1 * math.sin(t * math.pi))
                    i_ = Wf * 0.44 * w * (1.0 - 0.3 * t * t)
                    cpt = a1 + ax * Lf * t - sx * Wf * 0.06 * t * t
                    out.append(tuple(cpt + sx * o)); inn.append(tuple(cpt - sx * i_))
                body = out + inn[::-1]
                if green:
                    base, lit, dk, bl = mixc(F['mid'], C('#b8b23a'), 0.6), mixc(F['lit'], C('#d8d060'), 0.6), mixc(F['dk'], C('#8c8a2a'), 0.6), F['blush']
                else:
                    base, lit, dk, bl = F['mid'], F['lit'], F['dk'], F['blush']
                pa.fill(body, base)
                pa.ctx.save(); pa.path(body); pa.ctx.clip()
                # shade on the side away from the sun, light on the sun side, a red-orange blush on the shoulder
                sg = 1 if sx @ SLIGHT > 0 else -1
                pa.path([tuple(a1 + ax * Lf * t - sx * sg * Wf * 0.7) for t in np.linspace(-0.1, 1.1, 8)] +
                        [tuple(a1 + ax * Lf * t - sx * sg * Wf * 0.12) for t in np.linspace(1.1, -0.1, 8)])
                pa.ctx.set_source_rgb(*dk); pa.ctx.fill()
                pa.ctx.save(); pa.ctx.translate(*(a1 + ax * Lf * 0.16 + sx * sg * Wf * 0.1)); pa.ctx.scale(Wf * 0.42, Lf * 0.2)
                pa.ctx.new_path(); pa.ctx.arc(0, 0, 1, 0, 2 * math.pi); pa.ctx.restore()
                pa.ctx.set_source_rgba(*bl, 0.75); pa.ctx.fill()
                pa.ctx.save(); pa.ctx.translate(*(a1 + ax * Lf * 0.42 + sx * sg * Wf * 0.24)); pa.ctx.scale(Wf * 0.16, Lf * 0.24)
                pa.ctx.new_path(); pa.ctx.arc(0, 0, 1, 0, 2 * math.pi); pa.ctx.restore()
                pa.ctx.set_source_rgb(*lit); pa.ctx.fill()
                pa.ctx.save(); pa.ctx.translate(*(a1 + ax * Lf * 0.36 + sx * sg * Wf * 0.27)); pa.ctx.scale(Wf * 0.06, Lf * 0.08)
                pa.ctx.new_path(); pa.ctx.arc(0, 0, 1, 0, 2 * math.pi); pa.ctx.restore()
                pa.ctx.set_source_rgba(*F['hi'], 0.9); pa.ctx.fill()
                pa.ctx.restore()
                pa.soft_edge(body, base)
                # the stalk's end where it holds the fruit
                pa.ctx.new_path(); pa.ctx.arc(a1[0], a1[1], pa.u(0.5), 0, 2 * math.pi); pa.ctx.set_source_rgb(*F['stalk']); pa.ctx.fill()
            self.items.append((top + TOCAM * 0.9, draw))

    def shadow(self):
        pa = self.pa; c = pa.ctx
        cx, cy = pa.P(np.array([self.ce[0], self.ce[1], 0.0]))
        rx = self.ra * 0.92 * pa.k; e = 0.5
        c.save(); c.translate(cx, cy); c.scale(rx, rx * e); c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
        c.set_source_rgba(0, 0, 0, 0.12); c.fill()
        fx, fy = pa.P(np.array([0.0, 0.0, 0.0])); rf = 0.42 * pa.k
        c.save(); c.translate(fx, fy); c.scale(rf, rf * e); c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
        c.set_source_rgba(0, 0, 0, 0.1); c.fill()


FRAMES = [dict(seed=s) for s in range(4)]
BB = (-60, -95, 60, 25)


def render(fr, night=False, bb=BB):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    f = dict(fr); seed = f.pop('seed')
    Xoai(seed, pa, **f).paint()
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
    path = os.path.join(outdir, 'xoai.webp')
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
        sheet.save('/tmp/claude-0/g/xoai_%s.png' % tag); print(sheet.size)
