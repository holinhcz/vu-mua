# Flood-season plants of Sông Vàm (mùa nước nổi) for Nông Trại Nhỏ, in the kit of the game's flower plants
# (../caycanh, ../hoaco: small 3D models painted in flat game tones with the thin same-colour edge).
# Each one stands in the flood water at the river's flooded fringe and can be picked once a day:
#   dd  điên điển (Sesbania): a small shrub-tree of 3 slim trunks, a light crown of feathery pinnate leaves,
#       drooping clusters of yellow pea flowers, a few long thin pods.  Picked: same tree, no flowers.
#   sm  súng ma (wild Nymphaea): a raft of round notched floating pads, purple-pink star flowers on stalks a little
#       above the water, pointed buds.  Picked: pads and one bud.
#   kn  kèo nèo (Limnocharis flava): a clump of upright broad light-green leaves on thick stalks, umbels of pale yellow
#       3-petal flowers and green buds.  Picked: cut stubs and a few young leaves.
# Frames <kind><seed><a|b> (a = in flower, b = picked), d (day) and n (night).
#   preview: CO_RS=9 python3 nuocnoi.py dd,sm,kn [d|n] out.png
#   sheet:   CO_RS=9 python3 nuocnoi.py atlas OUTDIR atlas.json      (writes OUTDIR/nuocnoi.webp)
import math, os, sys
import numpy as np, cairo
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'co', 'dambut', 'hoaco'):
    sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM
import co
from co import Plant
import hoaco as hc
from hoaco import Mini, UP, shade, pick, basis

KU = 29.0 * 1.12          # the scale of the 1-tile flower plants (../caycanh)
KINDS = ['dd', 'sm', 'kn']
NSEED = 3


def water_rings(pa, pts, a=0.5):
    """thin light rings on the flood water round the stems, and a dark reflection under them"""
    c = pa.ctx
    for (x, y, rx) in pts:
        X, Y = pa.P(np.array([x, y, 0.0]))
        for k, (s, al) in enumerate(((1.0, a), (1.7, a * 0.55))):
            c.save(); c.translate(X, Y); c.scale(rx * s * pa.k, rx * s * pa.k * 0.5)
            c.new_path(); c.arc(0, 0, 1, math.pi * 0.05, math.pi * 0.95); c.restore()
            c.set_source_rgba(*C('#e8f2f0'), al); c.set_line_width(pa.u(0.32)); c.stroke()
            c.save(); c.translate(X, Y); c.scale(rx * s * pa.k, rx * s * pa.k * 0.5)
            c.new_path(); c.arc(0, 0, 1, math.pi * 1.1, math.pi * 1.9); c.restore()
            c.set_source_rgba(*C('#e8f2f0'), al * 0.45); c.set_line_width(pa.u(0.22)); c.stroke()


def water_shade(pa, cx, cy, rx, ry, a=0.13):
    c = pa.ctx; x, y = pa.P(np.array([cx, cy, 0.0]))
    g = cairo.RadialGradient(0, 0, 0, 0, 0, 1)
    g.add_color_stop_rgba(0, *C('#0c2a2a'), a); g.add_color_stop_rgba(0.7, *C('#0c2a2a'), a * 0.6); g.add_color_stop_rgba(1, *C('#0c2a2a'), 0)
    c.save(); c.translate(x, y); c.scale(rx * pa.k, ry * pa.k * 0.5); c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi)
    c.set_source(g); c.fill(); c.restore()


class Base(Mini):
    def __init__(self, kind, seed, picked, pa):
        self.pa = pa; self.kind = kind; self.seed = seed; self.picked = picked
        self.r = np.random.default_rng(seed * 7919 + KINDS.index(kind) * 104729 + 23)
        self.items = []; self.post = []
        self.G = hc.greens(); self.R = 0.5
        getattr(self, '_' + kind)(self.r)

    def paint(self):
        c = self.pa.ctx
        self.under()
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()

    # ------------------------------------------------------------------ điên điển
    def _dd(self, r):
        pa = self.pa; G = self.G
        bark = [C('#5a4a2c'), C('#6e5c36'), C('#857246'), C('#9c8a58')]
        leafp = [C('#245a26'), C('#2f6e2e'), C('#3f863a'), C('#56a046'), C('#70b656'), C('#88c866')]
        und = [C('#3e6c35'), C('#4f8041'), C('#62964d')]
        yel = (C('#cf980a'), C('#ecbc1a'), C('#f9d838'), C('#fff07c'))
        H = [1.6, 1.72, 1.5][self.seed]
        self.R = 0.62
        # 2-3 slim trunks out of the water, leaning apart, forking twice into an umbrella crown of twigs
        n = [3, 2, 3][self.seed]
        a0 = r.uniform(0, 6.28)
        bases, tips, limbs = [], [], []
        for k in range(n):
            a = a0 + k * 6.283 / n + r.normal(0, 0.3)
            b = np.array([math.cos(a) * 0.06, math.sin(a) * 0.045, 0.0])
            lean = np.array([math.cos(a) * r.uniform(0.12, 0.22), math.sin(a) * r.uniform(0.08, 0.16), 0.0])
            hk = H * r.uniform(0.44, 0.52)
            pts = [b + lean * (t ** 1.3) + UP * hk * t for t in np.linspace(0, 1, 8)]
            bases.append(b)
            self._limb(pts, 0.072, 0.05, bark, key=-0.08)
            stack = [(pts[-1], nv(pts[-1] - pts[-3]), 0.07, 0, a)]
            while stack:
                q, d, w, lvl, az = stack.pop()
                for j in range(2 if lvl < 2 else 1):
                    az2 = az + (j - 0.5) * r.uniform(1.4, 2.2) + r.normal(0, 0.3)
                    el = [0.9, 0.55, 0.3][lvl] + r.normal(0, 0.12)
                    d2 = nv(np.array([math.cos(az2) * math.cos(el), math.sin(az2) * math.cos(el) * 0.85, math.sin(el)]) + d * 0.3)
                    Lb = [0.34, 0.28, 0.2][lvl] * r.uniform(0.85, 1.15) * H / 1.6
                    bp = [q + d2 * Lb * t - UP * 0.04 * t * t * lvl for t in np.linspace(0, 1, 5)]
                    self._limb(bp, w * 0.7, w * 0.5, bark, key=-0.04 + 0.01 * lvl)
                    limbs.append((bp, lvl))
                    if lvl < 2: stack.append((bp[-1], d2, w * 0.6, lvl + 1, az2))
                    else: tips.append((bp[-1], d2))
        self.trunks = bases
        allp = [t for t, _ in tips]
        cen_c = np.mean(allp, 0) - UP * 0.15
        # leaves: feathery pinnate ones spread flat-ish round every twig tip and along the upper limbs
        leaves = []
        for tp, d0 in tips:
            for k in range(int(r.integers(5, 8))):
                az = math.atan2(d0[1], d0[0]) + r.uniform(-2.6, 2.6)
                d = nv(np.array([math.cos(az), math.sin(az) * 0.9, r.uniform(-0.05, 0.45)]))
                leaves.append((tp + r.normal(0, 0.03, 3), d, r.uniform(0.2, 0.3)))
        for bp, lvl in limbs:
            if lvl == 0: continue
            q = bp[2]; dd0 = nv(bp[-1] - bp[0])
            for k in range(2):
                az = math.atan2(dd0[1], dd0[0]) + (1 if k else -1) * r.uniform(0.6, 1.4)
                d = nv(np.array([math.cos(az), math.sin(az) * 0.9, r.uniform(0.0, 0.4)]))
                leaves.append((q, d, r.uniform(0.2, 0.28)))
        for b, d, L in leaves:
            self._pinnate(r, b, d, L, leafp, und, cen_c)
        # flowers: drooping clusters of yellow pea flowers at the twig tips and leaf bases, most on the outside
        cand = sorted(leaves, key=lambda z: -(nv(z[0] - cen_c) @ nv(TOCAM + UP * 0.2)) - r.uniform(0, 0.5))
        if not self.picked:
            nfl = [18, 20, 16][self.seed]
            used = []
            for b, d, L in cand:
                if len(used) >= nfl: break
                q = b + d * L * r.uniform(0.05, 0.2)
                sp = np.array(pa.P(q)) / pa.k
                if any(np.linalg.norm(sp - u) < 0.13 for u in used): continue
                used.append(sp)
                self._raceme(r, q, d, yel)
        for b, d, L in cand[-6:][: [3, 4, 3][self.seed]]:
            self._pod(r, b + d * L * 0.15)
        self.rings = [(b[0], b[1], 0.07) for b in bases]
        self.shade_w = (0.8, 0.62)

    def _limb(self, pts, w0, w1, pal, key=0.0):
        pa = self.pa
        d = nv(pts[-1] - pts[0]); side = nv(np.cross(d, TOCAM)) if np.linalg.norm(np.cross(d, TOCAM)) > 1e-3 else np.array([1.0, 0, 0])
        lit = float(side @ LIGHT) > 0
        def draw():
            sp = [pa.P(q) for q in pts]
            col = pal[1]
            pa.taper(sp, w0 * pa.k, w1 * pa.k, col, outline=col)
            # lit side toward the sun, pale bark bands (lenticels) up the stem
            o = SLIGHT * w0 * pa.k * 0.22
            pa.line([(x + o[0], y + o[1]) for x, y in sp], pal[2], w1 * pa.k * 0.55, 0.9)
            for i in range(1, len(sp) - 1, 2):
                x, y = sp[i]
                pa.line([(x - w0 * pa.k * 0.3, y), (x + w0 * pa.k * 0.3, y + 0.0)], pal[3], pa.u(0.18), 0.7)
        self.items.append((pts[len(pts) // 2] + TOCAM * key, draw))

    def _pinnate(self, r, b, d, L, pal, und, cen):
        """a feathery compound leaf: a rachis arching out with 10-14 pairs of small oblong leaflets"""
        pa = self.pa
        side = np.cross(UP, d); side = nv(side) if np.linalg.norm(side) > 1e-3 else np.array([1.0, 0, 0])
        droop = r.uniform(0.25, 0.5)
        n = int(r.integers(10, 14))
        rach = [b + d * L * t - UP * droop * L * t * t for t in np.linspace(0, 1, n + 2)]
        nrm = nv(np.cross(side, nv(rach[-1] - rach[0])))
        if nrm[2] < 0: nrm = -nrm
        front = nrm @ TOCAM > 0
        # crown volume: leaves on the far side / inside are darker, the sunny top lighter
        rel = nv(b + d * L * 0.5 - cen)
        ao = 0.18 * max(0.0, -(rel @ TOCAM)) + 0.12 * max(0.0, -rel[2])
        v = shade(nrm, 0.32, 0.62, ao=ao) + 0.12 * float(rel @ LIGHT)
        col = pick(pal if front else und, v)
        dk = mixc(col, C('#0c2410'), 0.35)
        lls = []
        for i in range(1, n + 1):
            t = i / (n + 1)
            q = rach[i]
            tang = nv(rach[i + 1] - rach[i - 1])
            sd = nv(np.cross(tang, nrm)) if np.linalg.norm(np.cross(tang, nrm)) > 1e-4 else side
            ll = 0.075 * (1.0 - 0.35 * abs(t - 0.45) * 2) * r.uniform(0.9, 1.08)
            ww = ll * 0.36
            for sgn in (1, -1):
                ax = nv(sd * sgn + tang * 0.35 - UP * 0.15)
                pts = [q + ax * ll * u + nv(np.cross(ax, nrm)) * ww * 0.5 * w for u, w in ((0, 0.3), (0.2, 0.85), (0.5, 1), (0.8, 0.8), (1, 0.2))]
                pts += [q + ax * ll * u - nv(np.cross(ax, nrm)) * ww * 0.5 * w for u, w in ((1, 0.2), (0.8, 0.8), (0.5, 1), (0.2, 0.85), (0, 0.3))]
                lls.append((pts, sgn, ax))
            # the terminal leaflet
        tip = rach[-1]; tang = nv(rach[-1] - rach[-2])
        lls.append(([tip + tang * 0.06 * u + side * 0.012 * w for u, w in ((0, 0.4), (0.4, 1), (1, 0.2))] +
                    [tip + tang * 0.06 * u - side * 0.012 * w for u, w in ((1, 0.2), (0.4, 1), (0, 0.4))], 0, tang))
        lit_side = float(np.array([side[0], 0.5 * side[1] - 0.866 * side[2]]) @ SLIGHT) > 0
        hi = mixc(col, C('#e8f4b0'), 0.28)
        def draw():
            P = pa.P
            pa.line([P(q) for q in rach], mixc(col, C('#7a8a3a'), 0.35), pa.u(0.22), 1.0)
            for pts, sgn, ax in lls:
                poly = [P(q) for q in pts]
                cl = col if (sgn > 0) == lit_side or sgn == 0 else mixc(col, dk, 0.45)
                pa.fill(poly, cl, seam=False); pa.soft_edge(poly, cl, w=0.14)
                if front and (sgn > 0) == lit_side:
                    a3 = P(pts[1]); b3 = P(pts[3])
                    pa.line([a3, b3], hi, pa.u(0.12), 0.6)
        self.items.append((b + d * L * 0.55, draw))

    def _raceme(self, r, q, d, yel):
        """a drooping spray of 4-7 yellow pea flowers; the tip ones are buds"""
        pa = self.pa
        out = nv(np.array([d[0], d[1], 0.0]) + r.normal(0, 0.2, 3) * np.array([1, 1, 0]))
        L = r.uniform(0.14, 0.22)
        st = [q + out * L * 0.45 * t - UP * L * (0.15 + 0.85 * t * t) for t in np.linspace(0, 1, 7)]
        stc = C('#6a8a34')
        def stalk():
            pa.line([pa.P(p) for p in st], stc, pa.u(0.22), 1.0)
        self.items.append((st[3] + TOCAM * 0.05, stalk))
        nfl = int(r.integers(5, 8))
        for i in range(nfl):
            t = 0.12 + 0.88 * i / max(1, nfl - 1)
            p = st[min(6, int(round(t * 6)))] + r.normal(0, 0.01, 3) + out * 0.02 * (i % 2 * 2 - 1)
            face = nv(out * 0.7 + TOCAM * 0.7 + r.normal(0, 0.25, 3) + UP * 0.1)
            if i >= nfl - 2:
                self.blob(p, 0.014, 0.014, 0.024, (C('#9a9a2a'), C('#c2bc3a'), C('#e0d65a')), key=0.08)
            else:
                self._pea(p, face, 0.085 * r.uniform(0.9, 1.1) * (1 - 0.15 * t), yel)

    def _pea(self, p, f, R, cols):
        """a pea flower: the round banner standing up and back, wings and keel cupped in front of it"""
        pa = self.pa
        u, v = basis(f)
        up = nv(UP - f * (UP @ f))
        ban = [p + f * (-0.004) + up * R * (0.15 + 0.55 * (1 + math.sin(a))) * 0.9 + nv(np.cross(f, up)) * R * 0.5 * math.cos(a)
               for a in np.linspace(-math.pi / 2, 3 * math.pi / 2, 18)]
        keel = [p + f * R * 0.25 * (0.5 + 0.5 * math.cos(a)) - up * R * 0.15 + nv(np.cross(f, up)) * R * 0.22 * math.sin(a) - up * R * 0.1 * (1 - math.cos(a))
                for a in np.linspace(0, 2 * math.pi, 14, endpoint=False)]
        front = f @ TOCAM > 0
        v0 = shade(f, 0.45, 0.55)
        cb = cols[2] if v0 > 0.66 else cols[1]
        ck = cols[1] if v0 > 0.66 else cols[0]
        streak = C('#b85a1a')
        def draw():
            P = pa.P
            poly = [P(q) for q in ban]; pa.fill(poly, cb); pa.soft_edge(poly, cb, w=0.16)
            if front:
                x0, y0 = P(p + up * R * 0.2)
                for s in (-0.2, 0.0, 0.2):
                    x1, y1 = P(p + up * R * 0.8 + nv(np.cross(f, up)) * R * s)
                    pa.line([(x0, y0), (x1, y1)], mixc(cb, streak, 0.35), pa.u(0.1), 0.6)
                hx, hy = P(p + up * R * 0.95 - nv(np.cross(f, up)) * R * 0.15)
                pa.ctx.new_path(); pa.ctx.arc(hx, hy, pa.u(0.35), 0, 6.283); pa.ctx.set_source_rgba(*cols[3], 0.85); pa.ctx.fill()
            kp = [P(q) for q in keel]; pa.fill(kp, ck); pa.soft_edge(kp, ck, w=0.14)
        self.items.append((p + TOCAM * 0.1, draw))

    def _pod(self, r, q):
        """a long thin green pod hanging from the crown, beaded by its seeds"""
        pa = self.pa
        out = nv(np.array([r.uniform(-1, 1), r.uniform(-0.2, 1), 0]))
        L = r.uniform(0.32, 0.44)
        pts = [q + out * 0.08 * t - UP * L * t + out * 0.04 * math.sin(t * 3) for t in np.linspace(0, 1, 10)]
        col = C('#7a9a3a'); lit = C('#a2bc52')
        def draw():
            sp = [pa.P(p) for p in pts]
            pa.taper(sp, pa.u(0.75), pa.u(0.35), col, outline=col)
            o = SLIGHT * pa.u(0.2)
            pa.line([(x + o[0], y + o[1]) for x, y in sp[1:-1]], lit, pa.u(0.22), 0.8)
        self.items.append((pts[4] + TOCAM * 0.02, draw))

    # ------------------------------------------------------------------ súng ma
    def _sm(self, r):
        pa = self.pa
        padp = [C('#1e4a26'), C('#2a5e2c'), C('#386f34'), C('#4a8240'), C('#5e964c')]
        rimc = C('#7a3a4a')
        petal = (C('#8e3a8e'), C('#b459b2'), C('#d07ccc'), C('#eaa6e6'))
        n = [7, 8, 6][self.seed]
        pads = []
        for k in range(60):
            if len(pads) >= n: break
            a = r.uniform(0, 6.28); d = r.uniform(0, 0.5) * (1 if k else 0)
            c = np.array([math.cos(a) * d * 1.2, math.sin(a) * d * 0.95, 0.0])
            R = r.uniform(0.19, 0.29) * (1.12 if k == 0 else 1)
            if any(np.linalg.norm(c[:2] - p[0][:2]) < (R + p[1]) * 0.72 for p in pads): continue
            pads.append((c, R, r.uniform(0, 6.28), r.uniform(-0.1, 0.1), int(r.integers(0, 3))))
        for c, R, ang, tone, blot in pads:
            self._pad(r, c, R, ang, tone, blot, padp, rimc)
        self.R = 0.7
        # flowers and buds stand a little above the water on their stalks
        tops = sorted(pads, key=lambda p: -p[1])
        nf = 0 if self.picked else [2, 3, 2][self.seed]
        nb = 1 if self.picked else [1, 1, 2][self.seed]
        spots = []
        for k in range(nf + nb):
            for _ in range(30):
                a = r.uniform(0, 6.28); d = r.uniform(0.05, 0.42)
                q = np.array([math.cos(a) * d, math.sin(a) * d * 0.8, 0.0])
                if all(np.linalg.norm(q[:2] - s[:2]) > 0.27 for s in spots): break
            spots.append(q)
            h = r.uniform(0.16, 0.28)
            top = q + UP * h + np.array([r.uniform(-0.03, 0.03), r.uniform(-0.02, 0.02), 0])
            self.stem([q, q + UP * h * 0.5 + (top - q) * 0.1, top], 0.9, 0.7, C('#5a6a2e'), key=-0.02)
            if k < nf:
                f = nv(UP * 1.0 + TOCAM * 0.35 + r.normal(0, 0.1, 3))
                # súng ma: pointed star petals in two rows, sepals green-purple below, a gold centre
                self.flower(top - f * 0.01, f, 5, 0.15, 0.06, (C('#4e5a2a'), C('#6a6a3a'), C('#8a8048'), C('#a89a5a')), cup=0.2,
                            ph0=r.uniform(0, 6), key=0.06, prof=[(0, 0.3), (0.3, 0.9), (0.6, 0.85), (1, 0.0)])
                self.flower(top, f, 12, 0.19, 0.062, petal, eye=C('#f2c232'), eye_r=0.038, cup=0.55, layers=2,
                            ph0=r.uniform(0, 6), key=0.1, prof=[(0.0, 0.2), (0.25, 0.75), (0.55, 1.0), (0.8, 0.7), (1.0, 0.0)])
            else:
                f = nv(UP + r.normal(0, 0.15, 3))
                self._bud(top, f, petal)
        self.rings = [(s[0], s[1], 0.06) for s in spots]
        self.shade_w = (0.0, 0.0)

    def _pad(self, r, c, R, ang, tone, blot, pal, rimc):
        pa = self.pa
        notch = 0.16
        pts = [c]
        for a in np.linspace(ang + notch, ang + 2 * math.pi - notch, 30):
            rr = R * (1 + 0.03 * math.sin(a * 5 + ang))
            pts.append(c + np.array([math.cos(a) * rr, math.sin(a) * rr, 0.004]))
        # a curled-up rim on the side away from the camera shows the purple-red underside
        curl = r.uniform() < 0.45
        col = pick(pal, 0.55 + tone)
        lit = mixc(col, C('#a8d088'), 0.35)
        dk = mixc(col, C('#0c2410'), 0.35)
        bl = [(c + np.array([math.cos(b) * R * d, math.sin(b) * R * d, 0.005]), R * r.uniform(0.08, 0.16))
              for b, d in ((r.uniform(0, 6.28), r.uniform(0.3, 0.75)) for _ in range(blot))]
        veins = [c + np.array([math.cos(a) * R * 0.92, math.sin(a) * R * 0.92, 0.005]) for a in np.linspace(ang + 0.6, ang + 2 * math.pi - 0.6, 9)]
        def draw():
            P = pa.P; poly = [P(q) for q in pts]
            pa.fill(poly, col)
            cx = pa.ctx; cx.save(); pa.path(poly); cx.clip()
            X, Y = P(c)
            g = cairo.LinearGradient(X - R * pa.k, Y - R * pa.k * 0.5, X + R * pa.k, Y + R * pa.k * 0.5)
            g.add_color_stop_rgba(0, *lit, 0.7); g.add_color_stop_rgba(0.55, *col, 0.0); g.add_color_stop_rgba(1, *dk, 0.45)
            cx.set_source(g); cx.paint()
            for q, rb in bl:
                x, y = P(q); cx.save(); cx.translate(x, y); cx.scale(rb * pa.k, rb * pa.k * 0.5); cx.new_path(); cx.arc(0, 0, 1, 0, 6.283); cx.restore()
                cx.set_source_rgba(*C('#5a2a3a'), 0.55); cx.fill()
            for q in veins:
                pa.line([P(c), P(q)], mixc(col, C('#c8e0a0'), 0.3), pa.u(0.1), 0.45)
            cx.restore()
            pa.line(poly[1:], rimc, pa.u(0.16), 0.55)
            pa.soft_edge(poly, col)
            pa.line([P(pts[1]), P(c), P(pts[-1])], dk, pa.u(0.16), 0.7)
            if curl:
                arc = [c + np.array([math.cos(a) * R, math.sin(a) * R, 0.0]) for a in np.linspace(ang + 3.6, ang + 5.0, 10)]
                up = [q + (q - c) * -0.06 + UP * R * 0.1 * math.sin(math.pi * i / 9) for i, q in enumerate(arc)]
                pp = [P(q) for q in arc] + [P(q) for q in up[::-1]]
                pa.fill(pp, C('#7a3a4c'), seam=False); pa.soft_edge(pp, C('#7a3a4c'), w=0.12)
        self.items.append((c - TOCAM * 0.3 + np.array([0, 0, 0.001 * R]), draw))

    def _bud(self, top, f, petal):
        """a closed bud: a pointed egg of 4 green sepals flushed purple, the petal tip just showing"""
        pa = self.pa
        u, v = basis(f)
        side = nv(np.cross(f, TOCAM)) if np.linalg.norm(np.cross(f, TOCAM)) > 1e-3 else u
        L = 0.16; Wd = 0.046
        prof = [(0, 0.55), (0.15, 0.9), (0.35, 1.0), (0.6, 0.8), (0.85, 0.35), (1.0, 0.0)]
        body = [top + f * L * t + side * Wd * w for t, w in prof] + [top + f * L * t - side * Wd * w for t, w in prof[::-1]]
        sep = [top + f * L * t + side * Wd * w * 0.55 for t, w in prof[:-1]] + [top + f * L * 0.9] + [top + f * L * t - side * Wd * w * 0.25 for t, w in prof[-2::-1]]
        lit = float(np.array([side[0], 0]) @ SLIGHT) > 0
        g0, g1, g2 = C('#3e5a28'), C('#587a34'), C('#7a6a4a')
        def draw():
            P = pa.P
            bp = [P(q) for q in body]; pa.fill(bp, g1); pa.soft_edge(bp, g1)
            c = pa.ctx; c.save(); pa.path(bp); c.clip()
            # purple flush up the sepals, the far half in shade, the petal tip at the top
            sp = [P(q) for q in sep]; pa.fill(sp, mixc(g1, petal[0], 0.45), seam=False)
            x0, y0 = P(top + f * L * 0.72); x1, y1 = P(top + f * L)
            g = cairo.LinearGradient(x0, y0, x1, y1); g.add_color_stop_rgba(0, *petal[1], 0); g.add_color_stop_rgba(0.5, *petal[1], 0.9); g.add_color_stop_rgba(1, *petal[2], 1)
            c.set_source(g); c.paint()
            pa.line([P(top + f * L * 0.1), P(top + f * L * 0.95)], mixc(g0, petal[0], 0.3), pa.u(0.14), 0.7)
            c.restore()
        self.items.append((top + TOCAM * 0.08, draw))

    # ------------------------------------------------------------------ kèo nèo
    def _kn(self, r):
        pa = self.pa
        pal = [C('#3e7a26'), C('#4f8e2e'), C('#64a43a'), C('#7cb848'), C('#96ca5a'), C('#b0da70')]
        und = [C('#5a8a3a'), C('#6a9a44'), C('#7eaa50')]
        stalk = C('#5e8e36')
        n = 5 if self.picked else [13, 14, 12][self.seed]
        H = [0.8, 0.88, 0.76][self.seed]
        a0 = r.uniform(0, 6.28)
        cut = []
        # a vase of leaves: thick stalks curving out of the water, broad blades held up and out, their faces seen
        for k in range(n):
            a = a0 + k * 6.283 / n + r.normal(0, 0.18)
            young = self.picked or k >= n - 3
            hk = H * (r.uniform(0.3, 0.42) if young else r.uniform(0.45, 0.8))
            sp = r.uniform(0.3, 0.5) * hk
            b = np.array([math.cos(a) * 0.04, math.sin(a) * 0.03, 0.0])
            top = b + np.array([math.cos(a) * sp, math.sin(a) * sp * 0.8, hk])
            mid = b + np.array([math.cos(a) * sp * 0.25, math.sin(a) * sp * 0.2, hk * 0.55])
            pts = [b + (mid - b) * t * 2 if t < 0.5 else mid + (top - mid) * (t - 0.5) * 2 for t in np.linspace(0, 1, 7)]
            pts = [b * (1 - t) ** 2 + mid * 2 * t * (1 - t) + top * t * t for t in np.linspace(0, 1, 8)]
            self.stem(pts, 1.7 if not young else 1.2, 0.95, stalk, key=-0.06)
            el = r.uniform(0.3, 0.85)
            d = nv(np.array([math.cos(a) * math.cos(el), math.sin(a) * math.cos(el) * 0.9 + 0.15, math.sin(el)]))
            L = (0.4 if not young else 0.25) * r.uniform(0.9, 1.1)
            self.leaf(top, d, L, L * 0.82, droop=0.14, pal=pal, und=und, n=10,
                      prof=[(0, 0.4), (0.1, 0.78), (0.3, 0.98), (0.5, 1.0), (0.72, 0.88), (0.9, 0.52), (1.0, 0.0)],
                      ao=0.0 if not young else 0.05, key=0.03, rib_w=0.2, extra=self._arc_veins, rib_col=C('#c8e090'))
        if self.picked:
            # stubs of the cut stalks, pale at the cut
            for k in range(5):
                a = a0 + 1.2 + k * 1.3 + r.normal(0, 0.2)
                b = np.array([math.cos(a) * 0.06, math.sin(a) * 0.05, 0.0])
                tp = b + np.array([math.cos(a) * 0.05, math.sin(a) * 0.04, r.uniform(0.12, 0.2)])
                self.stem([b, tp], 1.3, 1.2, stalk, key=-0.03)
                cut.append(tp)
            def cuts():
                for q in cut:
                    x, y = pa.P(q); pa.ctx.save(); pa.ctx.translate(x, y); pa.ctx.scale(pa.u(0.65), pa.u(0.32))
                    pa.ctx.new_path(); pa.ctx.arc(0, 0, 1, 0, 6.283); pa.ctx.restore(); pa.ctx.set_source_rgb(*C('#d8e6a8')); pa.ctx.fill()
            self.items.append((np.array([0, 0, 0.3]), cuts))
        else:
            # 1-2 umbels of pale yellow 3-petal flowers on stalks among the leaves, green buds nodding beside
            cols = (C('#c4a828'), C('#e2c844'), C('#f2de6a'), C('#fdf0a2'))
            for k in range([2, 2, 1][self.seed]):
                a = a0 + 1.0 + k * 3.0
                b = np.array([math.cos(a) * 0.04, math.sin(a) * 0.03, 0.0])
                top = b + np.array([math.cos(a) * 0.2, math.sin(a) * 0.16 + 0.05, H * r.uniform(0.82, 0.95)])
                self.stem([b, b + (top - b) * 0.5 + np.array([0.02, 0, 0]), top], 1.0, 0.8, stalk, key=0.0)
                for j in range(int(r.integers(3, 6))):
                    az = r.uniform(0, 6.28)
                    e = np.array([math.cos(az), math.sin(az) * 0.8, 0])
                    q = top + e * 0.07 + UP * r.uniform(0.0, 0.05)
                    self.stem([top, top + e * 0.04 + UP * 0.03, q], 0.45, 0.4, stalk, key=0.04)
                    if j % 3 == 2:
                        self.blob(q - UP * 0.02, 0.026, 0.026, 0.034, (C('#4a7a2a'), C('#62983a'), C('#86b456')), key=0.06)
                    else:
                        f = nv(e * 0.6 + UP * 0.6 + TOCAM * 0.5)
                        self.flower(q, f, 3, 0.07, 0.085, cols, eye=C('#c88a1a'), eye_r=0.016, cup=0.25, ph0=az, key=0.09,
                                    prof=[(0.0, 0.3), (0.3, 0.9), (0.6, 1.0), (0.85, 0.8), (1.0, 0.3)])
        self.rings = [(0.0, 0.0, 0.12)]
        self.shade_w = (0.45, 0.4)
        self.R = 0.5

    def _arc_veins(self, P, cen, L1, R1, col, front):
        """kèo nèo veins: curved, running from the base to the tip along both halves"""
        if not front: return
        pa = self.pa; vc = mixc(col, C('#d8eca0'), 0.4)
        n = len(cen) - 1
        for f in (0.38, 0.72):
            for E in (L1, R1):
                pts = [P(cen[i] + (E[i] - cen[i]) * f) for i in range(1, n)] + [P(cen[n])]
                pa.line(pts, vc, pa.u(0.11), 0.55)

    # ------------------------------------------------------------------ the water under it
    def under(self):
        pa = self.pa
        if self.shade_w[0] > 0:
            water_shade(pa, 0.08, 0.06, self.shade_w[0], self.shade_w[1], 0.12)
        water_rings(pa, self.rings)


class Frame:
    def __init__(self, pa, kind, seed, picked):
        self.m = Base(kind, seed, picked, pa)
    def paint(self): self.m.paint()


FRAMES = [dict(key='%s%d%s' % (k, s, 'ab'[p]), kind=k, seed=s, picked=p) for k in KINDS for s in range(NSEED) for p in (0, 1)]
BB = (-64, -96, 64, 24)

co.KU = KU
if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'atlas':
        co.atlas(Frame, FRAMES, BB, sys.argv[2], 'nuocnoi.webp', sys.argv[3], cols=8)
    else:
        from PIL import Image
        sel = sys.argv[1].split(',') if len(sys.argv) > 1 and sys.argv[1] != 'all' else KINDS
        night = len(sys.argv) > 2 and sys.argv[2] == 'n'
        rows = [[co.to_image(co.render(Frame, dict(kind=k, seed=s, picked=p), BB, night)) for s in range(NSEED) for p in (0, 1)] for k in sel]
        w, h = rows[0][0].size
        o = Image.new('RGBA', (w * NSEED * 2, h * len(rows)), (24, 40, 46, 255) if night else (58, 96, 104, 255))
        for j, ims in enumerate(rows):
            for i, im in enumerate(ims): o.alpha_composite(im, (i * w, j * h))
        o.save(sys.argv[3] if len(sys.argv) > 3 else '/tmp/claude-0/g/nuocnoi.png'); print(o.size)
