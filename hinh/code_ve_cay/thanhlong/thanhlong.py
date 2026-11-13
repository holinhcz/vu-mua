# Dragon fruit (thanh long) for Nông Trại Nhỏ, the way the delta grows it: a square concrete post with the climbing
# cactus tied up it, and on top an old tyre (shape 0) or a concrete cross (shape 1) that the stems spill over and
# hang down from all round, like a green fountain. Built as a small 3D model and painted in flat game tones with the
# thin same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun and night (../chuoi).
# Every stem is a three-ribbed cactus stem: two wings with wavy edges and a ridge between them, a pinch at each
# joint, small areoles in the notches. Everything (post faces, tyre patches, stem pieces, fruit, flowers) is sorted
# piece by piece, so stems lying on the tyre or the cross show on top of it and the ones hanging behind go behind.
# Ripe (t&1): 7-8 pink fruits with green-tipped scales hanging off the bends. Not ripe: a few small green fruits,
# long flower buds and two big white flowers. Frames follow the game's "k2" fruit trees: key = shape digit + ripe digit.
import math, os, sys
import numpy as np, cairo
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'co'): sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM
import co
from co import ground_shadow

UP = np.array([0, 0, 1.0])


def tones():
    return dict(
        stem=[C('#30703a'), C('#3b8541'), C('#4b9a47'), C('#5dae4f'), C('#74c05a'), C('#90d06c')],
        ridge=C('#9fd27a'), areole=C('#3c4a2c'),
        conc=dict(lit=C('#cbc6b9'), mid=C('#a9a497'), dk=C('#878276'), top=C('#dad5c8'), stain=C('#8f8a7c')),
        tyre=[C('#1e1f21'), C('#2a2b2e'), C('#36373a'), C('#47484c')],
        tie=C('#2b2b2b'),
        fruit=dict(dk=C('#a91f55'), mid=C('#d8306f'), lit=C('#ec5a92'), hi=C('#ffb6d0'),
                   scale=C('#e3528a'), tip=C('#7dbf3d'), tip_dk=C('#5c9a2e')),
        young=dict(dk=C('#4d8a32'), mid=C('#6aa842'), lit=C('#8cc45a'), hi=C('#c8e79a'),
                   scale=C('#78b24a'), tip=C('#c94a5c'), tip_dk=C('#9e3546')),
        flower=dict(pet=C('#fbfaf2'), pet_sh=C('#e4e1d2'), sep=C('#d9e28a'), sep_dk=C('#b5c463'),
                    eye=C('#f5ecb0'), stam=C('#e8c94a'), bud=C('#a9c95a'), bud_tip=C('#d65a6a')),
    )


def bez(p0, p1, p2, p3, t):
    u = 1 - t
    return u ** 3 * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t ** 3 * p3


class ThanhLong(co.Plant):
    def __init__(self, shape, ripe, pa):
        self.pa = pa; self.shape = shape; self.ripe = ripe
        self.seed = shape * 2 + ripe
        r = np.random.default_rng(shape * 7717 + 23)            # the plant itself is the same ripe or not
        self.items = []
        self.T = tones()
        self.top = [1.74, 1.82][shape]
        self._post(r)
        if shape == 0: self._tyre()
        else: self._cross()
        self.stems = []
        self._climbers(r)
        self._canopy(r)
        rf = np.random.default_rng(shape * 131 + 7 + ripe * 1000)
        if ripe: self._fruits(rf)
        else: self._unripe(rf)

    # ------------------------------------------------------------- post, tyre, cross
    def _box(self, c, ax, key_split=1, cols=None, seams=False):
        """a box: centre c, three half-axis vectors; visible faces shaded; optionally split along ax[0]"""
        pa = self.pa; Cn = cols or self.T['conc']
        u, v, w = ax
        for k in range(key_split):
            f0 = -1 + 2 * k / key_split; f1 = -1 + 2 * (k + 1) / key_split
            cc = c + u * (f0 + f1) / 2; uu = u * (f1 - f0) / 2
            faces = []
            ends = (k == 0, k == key_split - 1)
            for fi, (n0, a1, a2) in enumerate(((uu, v, w), (-uu, v, w), (v, uu, w), (-v, uu, w), (w, uu, v), (-w, uu, v))):
                nn = nv(n0)
                if nn @ TOCAM <= 0.02: continue
                if key_split > 1 and ((fi == 0 and not ends[1]) or (fi == 1 and not ends[0])): continue
                fc = cc + n0
                q = [fc + a1 + a2, fc - a1 + a2, fc - a1 - a2, fc + a1 - a2]
                lam = float(nn @ LIGHT)
                col = Cn['top'] if nn[2] > 0.7 else (Cn['lit'] if lam > 0.15 else Cn['mid'] if lam > -0.25 else Cn['dk'])
                # edges that run along ax[0] (the cut ends of a piece have no edge line)
                if fi < 2: eds = [(0, 1), (1, 2), (2, 3), (3, 0)]
                elif key_split > 1: eds = [(0, 1), (2, 3)]
                else: eds = [(0, 1), (1, 2), (2, 3), (3, 0)]
                faces.append((q, col, eds, fi))
            def draw(faces=faces):
                for q, col, eds, fi in faces:
                    pp = [pa.P(x) for x in q]; pa.fill(pp, col)
                for q, col, eds, fi in faces:
                    pp = [pa.P(x) for x in q]
                    for a_, b_ in eds: pa.line([pp[a_], pp[b_]], ch.soft(col), pa.u(ch.SOFT_W))
            self.items.append((cc, draw))

    def _post(self, r):
        pa = self.pa; Cn = self.T['conc']
        a = 0.075; h = self.top
        d1 = np.array([math.sqrt(0.5), math.sqrt(0.5), 0.0]) * a
        d2 = np.array([-math.sqrt(0.5), math.sqrt(0.5), 0.0]) * a
        # the post in 6 pieces up its height so stems in front and behind sort right; a few stains on the faces
        for k in range(6):
            z0 = h * k / 6; z1 = h * (k + 1) / 6
            self._box(np.array([0, 0, (z0 + z1) / 2]), (UP * (z1 - z0) / 2, d1, d2))
        stains = [(r.uniform(-0.9, 0.9), r.uniform(0.05, 0.9) * h, r.uniform(0.08, 0.25)) for _ in range(5)]
        def draw():
            for f, z, L in stains:
                face = d2 if f < 0 else d1
                side = -1 if f < 0 else 1
                # on the front-left (f<0) or front-right face
                n0 = nv(np.array([side * math.sqrt(0.5), math.sqrt(0.5), 0])) * a
                ax2 = nv(np.array([math.sqrt(0.5), -side * math.sqrt(0.5), 0])) * a
                p = n0 * 1.01 + ax2 * (abs(f) - 0.5) * 1.6
                pa.line([pa.P(p + UP * z), pa.P(p + UP * (z - L))], Cn['stain'], pa.u(0.35), 0.55)
        self.items.append((np.array([0, 0.11, h * 0.5]), draw))

    def _tyre(self):
        """an old tyre lying on top of the post"""
        pa = self.pa; T = self.T
        c0 = np.array([0, 0, self.top + 0.05])
        R, rt = 0.31, 0.075
        NU, NV = 56, 14
        for i in range(NU):
            u0 = 2 * math.pi * i / NU; u1 = 2 * math.pi * (i + 1) / NU; uc = (u0 + u1) / 2
            quads = []
            for j in range(NV):
                v0 = 2 * math.pi * j / NV; v1 = 2 * math.pi * (j + 1) / NV; vc = (v0 + v1) / 2
                def pt(u, v): return c0 + np.array([(R + rt * math.cos(v)) * math.cos(u), (R + rt * math.cos(v)) * math.sin(u) * 1.0, rt * 0.8 * math.sin(v)])
                n = nv(np.array([math.cos(vc) * math.cos(uc), math.cos(vc) * math.sin(uc), math.sin(vc)]))
                if n @ TOCAM < -0.05: continue
                lam = float(n @ LIGHT)
                col = T['tyre'][0 if lam < -0.2 else 1 if lam < 0.25 else 2 if lam < 0.6 else 3]
                quads.append((depth(pt(uc, vc)), [pt(u0, v0), pt(u1, v0), pt(u1, v1), pt(u0, v1)], col))
            quads.sort(key=lambda z: z[0])
            def draw(quads=quads):
                for _, q, col in quads: pa.fill([pa.P(x) for x in q], col)
            self.items.append((c0 + np.array([R * math.cos(uc), R * math.sin(uc), -0.02]), draw))

    def _cross(self):
        """two concrete arms crossed on top of the post"""
        h = self.top
        for d in ((1, 1), (1, -1)):
            u = nv(np.array([d[0], d[1], 0.0])) * 0.5
            v = nv(np.array([-d[1], d[0], 0.0])) * 0.04
            self._box(np.array([0, 0, h + 0.04 + (0.0 if d[1] > 0 else 0.081)]), (u, v, UP * 0.04), key_split=8)

    # ------------------------------------------------------------- stems
    def _stem(self, pts3, w, tone0=0.0):
        """a three-ribbed cactus stem along a 3D polyline; added piece by piece"""
        pa = self.pa; T = self.T; S = T['stem']
        n = len(pts3)
        L = sum(np.linalg.norm(pts3[i + 1] - pts3[i]) for i in range(n - 1))
        acc = [0.0]
        for i in range(n - 1): acc.append(acc[-1] + np.linalg.norm(pts3[i + 1] - pts3[i]))
        nlob = max(2, int(L / 0.075))
        joints = [x for x in np.arange(0.28, L - 0.1, 0.32)]
        def width(i):
            s = acc[i]
            wv = 0.84 + 0.16 * abs(math.sin(math.pi * s / L * nlob))       # the wavy ribs
            for jz in joints: wv *= 1 - 0.28 * math.exp(-((s - jz) / 0.03) ** 2)   # pinch at a joint
            tip = min(1.0, (L - s) / 0.06)
            return w * wv * (0.35 + 0.65 * tip)
        Wd = [width(i) for i in range(n)]
        notch = [i for i in range(1, n - 1) if Wd[i] < Wd[i - 1] and Wd[i] <= Wd[i + 1]]
        for i in range(n - 1):
            a3, b3 = pts3[i], pts3[i + 1]
            mid = (a3 + b3) / 2
            tg = nv(b3 - a3)
            rad = np.array([mid[0], mid[1], 0.0])
            rr = np.linalg.norm(rad)
            out = rad / rr if rr > 1e-3 else np.array([0, 1.0, 0])
            nrm = nv(out * 0.7 + UP * 0.8 - tg * (tg @ (out * 0.7 + UP * 0.8)))
            lam = float(nrm @ LIGHT)
            v = 0.42 + 0.34 * lam + tone0
            v -= 0.18 * max(0.0, (self.top - mid[2]) / 1.2) * (1 if rr < 0.45 else 0.5)   # low inside the canopy: shade
            def draw(i=i, v=v):
                P = pa.P
                A = np.array(P(pts3[i])); B = np.array(P(pts3[i + 1]))
                d = B - A; ln = np.linalg.norm(d)
                if ln < 1e-6: return
                d = d / ln
                # carry the side direction smoothly across pieces
                pa_ = np.array(P(pts3[max(0, i - 1)])); pb_ = np.array(P(pts3[min(n - 1, i + 2)]))
                da = A - pa_; da = d if np.linalg.norm(da) < 1e-6 else da / np.linalg.norm(da)
                db = pb_ - B; db = d if np.linalg.norm(db) < 1e-6 else db / np.linalg.norm(db)
                na = nv(np.array([-(da + d)[1], (da + d)[0]])); nb = nv(np.array([-(db + d)[1], (db + d)[0]]))
                wa = Wd[i] * pa.k * 0.5; wb = Wd[i + 1] * pa.k * 0.5
                lit_pos = (na @ SLIGHT) > 0
                cl = S[max(0, min(5, int(round((v + 0.12) * 5))))]
                cd = S[max(0, min(5, int(round((v - 0.1) * 5))))]
                rf = 0.12 * (1 if lit_pos else -1)                           # the ridge leans a little to the dark side
                ra = A - na * wa * rf; rb = B - nb * wb * rf
                Lw = [tuple(A + na * wa), tuple(B + nb * wb), tuple(rb), tuple(ra)]
                Rw = [tuple(ra), tuple(rb), tuple(B - nb * wb), tuple(A - na * wa)]
                pa.fill(Lw, cl if lit_pos else cd); pa.fill(Rw, cd if lit_pos else cl)
                pa.line([tuple(ra), tuple(rb)], mixc(cl, T['ridge'], 0.45), pa.u(0.28))
                pa.line([tuple(A + na * wa), tuple(B + nb * wb)], ch.soft(cl if lit_pos else cd), pa.u(ch.SOFT_W))
                pa.line([tuple(A - na * wa), tuple(B - nb * wb)], ch.soft(cd if lit_pos else cl), pa.u(ch.SOFT_W))
                if i in notch:
                    for sg in (1, -1):
                        q = A + na * wa * sg * 0.92
                        c = pa.ctx; c.new_path(); c.arc(q[0], q[1], pa.u(0.22), 0, 2 * math.pi)
                        c.set_source_rgb(*T['areole']); c.fill()
            self.items.append((pts3[i] * 0.5 + pts3[i + 1] * 0.5, draw))
        self.stems.append(dict(pts=pts3, w=w, acc=acc, L=L))

    def _climbers(self, r):
        """the old stems that climbed the post, tied to it"""
        for k, (x, y) in enumerate([(-0.095, 0.095), (0.1, 0.09)][:2 if self.shape else 1]):
            pts = [np.array([x + 0.01 * math.sin(t * 9), y, -0.02 + (self.top + 0.12) * t]) for t in np.linspace(0, 1, 26)]
            self._stem(pts, 0.075, tone0=-0.04)
            for zt in (0.35, 0.85, 1.3)[:3]:
                z = zt * self.top / 1.6
                p = np.array([x, y, z])
                def draw(p=p):
                    pa = self.pa
                    a = pa.P(p + np.array([-0.045, 0.0, 0.0])); b = pa.P(p + np.array([0.045, 0.0, 0.0]))
                    pa.line([a, b], self.T['tie'], pa.u(0.8))
                self.items.append((p + np.array([0, 0.05, 0]), draw))

    def _canopy(self, r):
        top = self.top
        n = [17, 20][self.shape]
        rim = 0.36 if self.shape == 0 else 0.46
        z_on = top + (0.12 if self.shape == 0 else 0.1)
        az0 = r.uniform(0, 2 * math.pi)
        for k in range(n):
            a = az0 + 2 * math.pi * k / n + r.normal(0, 0.1)
            if self.shape == 1:
                # stems gather over the four arms a little
                a += 0.18 * math.sin(4 * (a - math.pi / 4))
            o = np.array([math.cos(a), math.sin(a), 0.0])
            sd = np.array([-math.sin(a), math.cos(a), 0.0])
            p0 = o * 0.06 + UP * (top + 0.1)
            p1 = o * rim * 0.7 + UP * (z_on + r.uniform(0.08, 0.2))
            reach = r.uniform(0.9, 1.28)
            drop = r.uniform(0.3, 0.85)
            tw = r.normal(0, 0.18)
            p2 = (o * (rim + 0.3) + sd * tw * 0.3) + UP * (z_on + r.uniform(0.0, 0.1))
            p3 = (o * reach + sd * tw) + UP * (top - drop)
            pts = [bez(p0, p1, p2, p3, t) for t in np.linspace(0, 1, 22)]
            if min(q[2] for q in pts) < 0.25: continue
            self._stem(pts, r.uniform(0.09, 0.105))
            # now and then a side shoot from the bend, hanging on its own
            if r.random() < 0.35:
                i0 = int(r.integers(9, 13)); b0 = pts[i0]
                o2 = nv(o + sd * r.choice([-1, 1]) * 0.7)
                q1 = b0 + o2 * 0.12 + UP * 0.05
                q3 = b0 + o2 * r.uniform(0.25, 0.4) - UP * r.uniform(0.3, 0.6)
                q2 = b0 + o2 * 0.28 - UP * 0.05
                sp = [bez(b0, q1, q2, q3, t) for t in np.linspace(0, 1, 12)]
                self._stem(sp, 0.08)
        # a few young shoots standing up out of the middle
        for k in range(3):
            a = az0 + k * 2.1 + 0.5
            o = np.array([math.cos(a), math.sin(a), 0.0])
            p0 = o * 0.05 + UP * (top + 0.12)
            pts = [p0 + o * 0.12 * t * t + UP * 0.32 * t for t in np.linspace(0, 1, 10)]
            self._stem(pts, 0.062, tone0=0.06)

    # ------------------------------------------------------------- fruit and flowers
    def _spots(self, r, n, smin=0.5, smax=0.85, front=-0.35):
        """places along the outer stems for fruit, spread evenly round the side the camera sees"""
        cand = []
        for st in self.stems:
            if st['L'] < 0.6: continue
            for _ in range(4):
                s = r.uniform(smin, smax) * st['L']
                i = int(np.searchsorted(st['acc'], s)); i = max(1, min(len(st['pts']) - 2, i))
                p = st['pts'][i]
                rr = np.linalg.norm(p[:2])
                if rr < 0.5: continue
                cand.append((p, nv(st['pts'][i + 1] - st['pts'][i - 1]), st, math.atan2(p[1], p[0])))
        out = []
        # target directions fanned over the front and the two sides (+y faces the camera)
        tg = np.linspace(-0.04 * math.pi, 1.04 * math.pi, n) + r.normal(0, 0.08, n)
        for t in tg:
            best = None
            for p, tv, st, az in cand:
                da = abs((az - t + math.pi) % (2 * math.pi) - math.pi)
                if any(np.linalg.norm(p - q[0]) < 0.3 for q in out): continue
                sc = da + 0.2 * r.random()
                if best is None or sc < best[0]: best = (sc, (p, tv, st))
            if best: out.append(best[1])
        return out

    def _fruits(self, r):
        for p, tg, st in self._spots(r, [7, 8][self.shape], 0.62, 0.92):
            o = nv(np.array([p[0], p[1], 0.0]) + 1e-6)
            ax = nv(-UP * 0.85 + o * 0.45 + r.normal(0, 0.12, 3) * np.array([1, 1, 0]))
            c = p + o * 0.05 - UP * 0.02 + ax * 0.12
            self._fruit(r, p, c, ax, 0.23, 0.17, self.T['fruit'])

    def _unripe(self, r):
        spots = self._spots(r, 7, 0.55, 0.9)
        for k, (p, tg, st) in enumerate(spots):
            o = nv(np.array([p[0], p[1], 0.0]) + 1e-6)
            if k in (0, 3):
                self._flower(r, p, o)
            elif k in (1, 4, 6):
                ax = nv(-UP * 0.8 + o * 0.5)
                self._fruit(r, p, p + o * 0.04 + ax * 0.08, ax, 0.15, 0.11, self.T['young'])
            else:
                self._bud(r, p, o)

    def _fruit(self, r, base, c, ax, Lf, Wf, Fc):
        pa = self.pa
        rr = np.random.default_rng(int(r.integers(1, 1 << 30)))
        scales = [(rr.uniform(-0.55, 0.55), rr.choice([-1, 1]), rr.uniform(0.75, 1.15)) for _ in range(5)]
        def draw():
            P = pa.P; cx = pa.ctx
            A = np.array(P(c - ax * Lf * 0.5)); B = np.array(P(c + ax * Lf * 0.5))
            d = B - A; Ls = np.linalg.norm(d); d = d / max(1e-6, Ls)
            nr = np.array([-d[1], d[0]])
            W = Wf * pa.k * 0.5; Ctr = (A + B) / 2
            # stalk from the stem
            pa.line([P(base), tuple(A)], self.T['stem'][2], pa.u(0.6))
            def ell(t, k=1.0):
                return [tuple(Ctr + d * math.cos(a) * Ls * 0.5 * k + nr * math.sin(a) * W * k) for a in np.linspace(0, 2 * math.pi, 40)]
            body = ell(0)
            pa.fill(body, Fc['mid'])
            lit_sg = 1 if nr @ SLIGHT > 0 else -1
            # shade on the far side, a lit cheek and a shine on the sunny side
            sh = [tuple(Ctr + d * math.cos(a) * Ls * 0.5 + nr * math.sin(a) * W) for a in np.linspace(0, math.pi, 20)]
            sh2 = [tuple(Ctr + d * math.cos(a) * Ls * 0.46 + nr * math.sin(a) * W * 0.45) for a in np.linspace(math.pi, 0, 20)]
            if lit_sg > 0:
                sh = [tuple(Ctr + d * math.cos(a) * Ls * 0.5 - nr * math.sin(a) * W) for a in np.linspace(0, math.pi, 20)]
                sh2 = [tuple(Ctr + d * math.cos(a) * Ls * 0.46 - nr * math.sin(a) * W * 0.45) for a in np.linspace(math.pi, 0, 20)]
            pa.fill(sh + sh2, Fc['dk'])
            lc = Ctr + nr * lit_sg * W * 0.38 - d * Ls * 0.08
            cheek = [tuple(lc + d * math.cos(a) * Ls * 0.26 + nr * math.sin(a) * W * 0.32) for a in np.linspace(0, 2 * math.pi, 24)]
            pa.fill(cheek, Fc['lit'])
            cx.new_path(); cx.save(); cx.translate(*(lc - d * Ls * 0.08)); cx.rotate(math.atan2(d[1], d[0]))
            cx.scale(Ls * 0.09, W * 0.13); cx.arc(0, 0, 1, 0, 2 * math.pi); cx.restore(); cx.set_source_rgb(*Fc['hi']); cx.fill()
            pa.soft_edge(body, Fc['mid'])
            # the scales: flaps along both sides and over the face, pink at the base, green at the tip,
            # all leaning toward the bottom of the fruit; a crown of them at the bottom
            def flap(p0, dirv, size):
                side = np.array([-dirv[1], dirv[0]])
                tip = p0 + dirv * size
                fl = [tuple(p0 + side * size * 0.32), tuple(p0 + dirv * size * 0.55 + side * size * 0.2), tuple(tip),
                      tuple(p0 + dirv * size * 0.55 - side * size * 0.2), tuple(p0 - side * size * 0.32)]
                pa.fill(fl, Fc['scale'])
                gt = [tuple(p0 + dirv * size * 0.55 + side * size * 0.2), tuple(tip), tuple(p0 + dirv * size * 0.55 - side * size * 0.2)]
                pa.fill(gt, Fc['tip']); pa.soft_edge(fl, Fc['scale'], w=0.18)
            sz = Ls * 0.32
            for t, sg, k in scales:
                p0 = Ctr + d * t * Ls * 0.45 + nr * sg * W * 0.92 * math.sqrt(max(0.0, 1 - t * t))
                flap(p0, nv(d * 0.9 + nr * sg * 0.55), sz * k)
            for t in (-0.25, 0.15):
                flap(Ctr + d * t * Ls * 0.5 + nr * lit_sg * W * 0.15, nv(d * 1.0 + nr * lit_sg * 0.25), sz * 0.75)
            for k in (-1, 0, 1):
                flap(B - d * Ls * 0.06, nv(d + nr * k * 0.6), sz * 0.85)
        self.items.append((c + TOCAM * 0.16, draw))

    def _bud(self, r, base, o):
        pa = self.pa; Fl = self.T['flower']
        ax = nv(o * 0.55 + UP * 0.75)
        L = r.uniform(0.18, 0.24)
        def draw():
            P = pa.P
            A = np.array(P(base)); B = np.array(P(base + ax * L))
            d = B - A; Ls = np.linalg.norm(d); d = d / max(1e-6, Ls); nr = np.array([-d[1], d[0]])
            W = pa.k * 0.03
            prof = lambda t: math.sin(math.pi * min(1.0, 0.2 + t * 0.85)) ** 0.8 * (0.45 + 0.55 * t) * (1 - t ** 4)
            ts = np.linspace(0, 1, 18)
            body = [tuple(A + d * Ls * t + nr * W * prof(t)) for t in ts] + [tuple(A + d * Ls * t - nr * W * prof(t)) for t in ts[::-1]]
            pa.fill(body, Fl['bud']); pa.soft_edge(body, Fl['bud'])
            for t in (0.35, 0.6, 0.85):
                for sg in (1, -1):
                    p0 = A + d * Ls * t + nr * sg * W * prof(t) * 0.8
                    pa.line([tuple(p0), tuple(p0 + (d * 0.8 + nr * sg * 0.4) * W * 0.9)], Fl['bud_tip'], pa.u(0.35))
            pa.line([tuple(A + d * Ls * 0.92), tuple(B + d * W * 0.3)], Fl['bud_tip'], pa.u(0.5))
        self.items.append((base + ax * L * 0.5 + TOCAM * 0.05, draw))

    def _flower(self, r, base, o):
        """a big white night flower on a long green tube"""
        pa = self.pa; Fl = self.T['flower']
        ax = nv(o * 0.6 + UP * 0.5 + TOCAM * 0.5)
        c = base + nv(o * 0.7 + UP * 0.6) * 0.16
        t1 = nv(np.cross(ax, UP)); t2 = nv(np.cross(ax, t1))
        R = 0.135
        pet = []; sep = []
        for k in range(12):
            a = 2 * math.pi * k / 12
            pet.append(a)
        for k in range(9):
            sep.append(2 * math.pi * k / 9 + 0.3)
        def ring_pts(a, Lr, Wr, lift):
            dv = t1 * math.cos(a) + t2 * math.sin(a)
            sd = t1 * -math.sin(a) + t2 * math.cos(a)
            pts = []
            for t in np.linspace(0, 1, 9):
                w = Wr * math.sin(math.pi * min(1.0, 0.15 + t * 0.9)) ** 0.8
                pts.append(c + dv * Lr * t + ax * lift * t + sd * w)
            for t in np.linspace(1, 0, 9):
                w = Wr * math.sin(math.pi * min(1.0, 0.15 + t * 0.9)) ** 0.8
                pts.append(c + dv * Lr * t + ax * lift * t - sd * w)
            return pts, dv
        def draw():
            P = pa.P; cx = pa.ctx
            # the tube from the stem
            pa.line([P(base), P(c - ax * 0.02)], Fl['bud'], pa.u(1.0))
            for a in sep:
                pts, dv = ring_pts(a, R * 1.15, R * 0.12, -0.02)
                col = Fl['sep'] if dv @ np.array([-0.6, 0, 0.8]) > -0.2 else Fl['sep_dk']
                pp = [P(q) for q in pts]; pa.fill(pp, col); pa.soft_edge(pp, col, w=0.18)
            order = sorted(pet, key=lambda a: depth(c + (t1 * math.cos(a) + t2 * math.sin(a)) * R))
            for a in order:
                pts, dv = ring_pts(a, R, R * 0.2, 0.03)
                lam = float(nv(ax + dv * 0.3) @ LIGHT)
                col = Fl['pet'] if lam > 0.2 else Fl['pet_sh']
                pp = [P(q) for q in pts]; pa.fill(pp, col); pa.soft_edge(pp, col, w=0.18)
            # the throat and the stamens
            x, y = P(c + ax * 0.02)
            cx.new_path(); cx.arc(x, y, pa.k * R * 0.32, 0, 2 * math.pi); cx.set_source_rgb(*Fl['eye']); cx.fill()
            for k in range(10):
                a = 2 * math.pi * k / 10
                q = c + ax * 0.03 + (t1 * math.cos(a) + t2 * math.sin(a)) * R * 0.22
                x2, y2 = P(q)
                cx.new_path(); cx.arc(x2, y2, pa.u(0.32), 0, 2 * math.pi); cx.set_source_rgb(*Fl['stam']); cx.fill()
        self.items.append((c + TOCAM * 0.08, draw))

    def shadow(self):
        ground_shadow(self.pa, 0.0, 0.0, 1.05, 0.95, 0.12)
        ground_shadow(self.pa, 0.0, 0.0, 0.22, 0.2, 0.14)


FRAMES = [dict(key='%d%d' % (s, k), shape=s, ripe=k) for s in (0, 1) for k in (0, 1)]
BB = (-70, -105, 70, 25)

if __name__ == '__main__':
    co.main(ThanhLong, FRAMES, BB, 'k2_thanhlong.webp', 'thanhlong')
