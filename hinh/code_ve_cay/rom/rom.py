# Haystacks (đống rơm / cây rơm) for Nông Trại Nhỏ: the rice-straw stack every Mekong delta yard keeps for the
# buffalo, built up round a wooden pole. Made as a small 3D model and painted in flat game tones with the thin
# same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun and night (../chuoi).
# The stack: a round body (a solid of revolution, a little lumpy and leaning) that bulges out under the middle and
# narrows to the pole at the top; the bottom is pulled in where straw has been taken for the animals, so the
# bulge overhangs it with a fringe of hanging straw and a dark band under it. The body is painted in flat straw tones
# by the light, then covered in straws lying down its slope, lighter and darker ones, and loose straws stick out all
# round the edge. Twisted straw ropes bind it (2 on even seeds, 3 on odd, as the old stack had), a topknot of straw is
# tied round the pole where it comes out of the top, loose straw lies on the ground round the foot.
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
        straw=[C('#7f5a21'), C('#9b742b'), C('#b88c35'), C('#cda244'), C('#ddb757'), C('#ebcb72'), C('#f4dc94')],
        under=C('#6a4c1f'),
        rope=dict(mid=C('#b08636'), dk=C('#7e5c22'), lt=C('#d8b45c')),
        wood=dict(lit=C('#937254'), mid=C('#6e543c'), dk=C('#4c3a2a'), cut=C('#c9a77c')),
    )


def catmull(pts, n=200):
    """smooth curve through (z, r) points, sampled densely; returns z array and r array"""
    P = [pts[0]] + pts + [pts[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = [np.array(q, float) for q in P[i - 1:i + 3]]
        for t in np.linspace(0, 1, n // (len(pts) - 1), endpoint=False):
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(np.array(pts[-1], float))
    a = np.array(out)
    return a[:, 0], a[:, 1]


class Rom(co.Plant):
    def __init__(self, seed, pa):
        self.pa = pa; self.seed = seed
        r = self.r = np.random.default_rng(seed * 7121 + 3)
        self.items = []
        T = self.T = tones()
        q = seed % 4
        sc = self.sc = [1.0, 0.92, 1.06, 0.84][q]
        H = 2.15 * sc
        # the profile (height, radius), from the pulled-in foot, out to the bulge, in to the pole
        prof = [(0.0, 0.6), (0.1, 0.63), (0.24, 0.74), (0.34, 0.81), (0.6, 0.85), (0.92, 0.81), (1.25, 0.7),
                (1.52, 0.54), (1.74, 0.37), (1.89, 0.21), (1.97, 0.09), (2.0, 0.05)]
        sh = [(1.0, 1.0), (1.04, 0.97), (0.98, 1.04), (1.0, 1.0)][q]
        prof = [(z * 1.07 * sc * sh[1], rr * 0.9 * sc * sh[0]) for z, rr in prof]
        self.zs, self.rs = catmull(prof, 240)
        self.H = self.zs[-1]
        self.ropes = [[0.36, 0.62], [0.3, 0.5, 0.7], [0.38, 0.64], [0.3, 0.5, 0.7]][q]
        self.ropes = [z * self.H for z in self.ropes]
        self.rtilt = [(r.uniform(0.02, 0.05) * sc, r.uniform(0, 6.28)) for _ in self.ropes]
        self.lump = [(r.integers(2, 6), r.uniform(0, 6.28), r.uniform(0.012, 0.028)) for _ in range(3)]
        self.lean = np.array([r.normal(0, 0.05), r.normal(0, 0.03), 0.0])
        self.items.append((np.array([0.0, 0.0, 0.0]), self._body))
        self._ground_straw()

    # ------------------------------------------------------------- geometry
    def rad(self, z, th):
        rr = float(np.interp(z, self.zs, self.rs))
        rr *= 1 + sum(a * math.sin(k * th + ph) for k, ph, a in self.lump) * min(1.0, z / 0.4)
        for zr, (ta, tp) in zip(self.ropes, self.rtilt):
            zz = zr + ta * math.sin(th + tp)
            rr *= 1 - 0.045 * math.exp(-((z - zz) / 0.045) ** 2)          # the rope pinches the straw in
        return rr

    def S(self, z, th, out=0.0):
        rr = self.rad(z, th) + out
        lz = (z / self.H) ** 2
        return np.array([rr * math.cos(th), rr * math.sin(th), z]) + self.lean * lz

    def N(self, z, th):
        dz = 0.01
        dr = (self.rad(min(self.H, z + dz), th) - self.rad(max(0.0, z - dz), th)) / (2 * dz)
        return nv(np.array([math.cos(th), math.sin(th), -dr]))

    def tone(self, n, z):
        lam = float(n @ LIGHT)
        v = 0.44 + 0.68 * lam
        if n[2] < -0.15: v -= 0.25 * min(1.0, -n[2])                        # the undercut faces down, in shade
        v -= 0.12 * max(0.0, 1 - z / 0.3)                                    # the foot sits in its own shadow
        return v

    def colc(self, v):
        S = self.T['straw']
        f = max(0.0, min(1.0, v)) * (len(S) - 1); i = min(int(f), len(S) - 2)
        return mixc(S[i], S[i + 1], f - i)

    def col(self, v, k=0):
        S = self.T['straw']
        i = int(round(max(0.0, min(1.0, v)) * (len(S) - 1))) + k
        return S[max(0, min(len(S) - 1, i))]

    # ------------------------------------------------------------- painting
    def _body(self):
        pa = self.pa; P = pa.P; T = self.T; r = np.random.default_rng(self.seed * 31 + 5)
        NT, NZ = 140, 84
        zs = np.linspace(0, self.H, NZ + 1)
        ths = np.linspace(-math.pi, math.pi, NT + 1)
        quads = []
        for i in range(NZ):
            for j in range(NT):
                zc = (zs[i] + zs[i + 1]) / 2; tc = (ths[j] + ths[j + 1]) / 2
                n = self.N(zc, tc)
                if n @ TOCAM < -0.12: continue
                pts = [self.S(zs[i], ths[j]), self.S(zs[i], ths[j + 1]), self.S(zs[i + 1], ths[j + 1]), self.S(zs[i + 1], ths[j])]
                quads.append((depth(sum(pts) / 4), pts, self.colc(self.tone(n, zc))))
        # loose straws round the back edge first (only the ends that stick out past the body show)
        self._fringe(r, back=True)
        for _, pts, c in sorted(quads, key=lambda z: z[0]):
            pa.fill([P(q) for q in pts], c)
        self._edge()
        self._straws(r)
        self._eave(r)
        for zr, tl in zip(self.ropes, self.rtilt): self._rope(r, zr, tl)
        self._fringe(r, back=False)
        self._top(r)

    def _straws(self, r):
        """straws lying down the slope: short tapered strokes, lighter and darker than the straw under them"""
        pa = self.pa; P = pa.P
        n = int(900 * self.sc ** 2)
        for k in range(n):
            th = r.uniform(-math.pi, math.pi)
            z0 = self.H * (1 - r.uniform(0, 1) ** 1.25) * 0.98
            nrm = self.N(z0, th)
            if nrm @ TOCAM < 0.12: continue
            ln = r.uniform(0.25, 0.5) * (0.6 if z0 > self.H * 0.85 else 1.0)
            dth = r.normal(0, 0.05)
            pts3 = []
            for t in np.linspace(0, 1, 6):
                z = max(0.3, z0 - ln * t) if z0 > 0.32 else z0 - ln * t * 0.3
                pts3.append(self.S(z, th + dth * t, 0.006))
            v = self.tone(nrm, z0)
            k2 = int(r.choice([-1, -1, 1, 1, 2]))
            col = self.col(v, k2)
            pa.line([P(q) for q in pts3], col, pa.u(r.uniform(0.38, 0.55)))

    def _eave(self, r):
        """straw hanging off the bulge over the pulled-in foot"""
        pa = self.pa; P = pa.P; T = self.T
        ze = 0.3 * self.sc
        for k in range(80):
            th = r.uniform(-0.15, math.pi + 0.15)
            nrm = self.N(ze + 0.05, th)
            if nrm @ TOCAM < 0.0: continue
            p0 = self.S(ze + r.uniform(0.0, 0.08), th, 0.01)
            L = r.uniform(0.05, 0.12)
            p1 = p0 + np.array([math.cos(th), math.sin(th), 0]) * 0.02 - UP * L
            p1[2] = max(0.02, p1[2])
            v = self.tone(nrm, ze + 0.1)
            pa.line([P(p0), P(p1)], self.col(v, int(r.choice([-1, 0, 1]))), pa.u(r.uniform(0.45, 0.65)))

    def _fringe(self, r, back):
        """loose straws sticking out along the silhouette"""
        pa = self.pa; P = pa.P
        for k in range(60):
            z = self.H * r.uniform(0.15, 0.9)
            # find the silhouette angle for this height: n . TOCAM = 0
            dz = 0.01
            dr = (float(np.interp(z + dz, self.zs, self.rs)) - float(np.interp(z - dz, self.zs, self.rs))) / (2 * dz)
            s = max(-1.0, min(1.0, 0.577 * dr))
            base = math.asin(s)
            th = (base if r.random() < 0.5 else math.pi - base) + r.normal(0, 0.12) + (-0.25 if back else 0.12) * (1 if r.random() < 0.5 else -1) * 0
            th += r.normal(0, 0.06) + (-0.22 if back else 0.0)
            if not back and self.N(z, th) @ TOCAM < 0: th += 0.3 if math.cos(th) > 0 else -0.3
            p0 = self.S(z, th, -0.02)
            out = np.array([math.cos(th), math.sin(th), 0.0])
            d = nv(out * r.uniform(0.25, 0.6) - UP * r.uniform(0.6, 1.0) + np.array([0, 0, 0.0]))
            p1 = p0 + d * r.uniform(0.08, 0.16)
            v = self.tone(self.N(z, th), z)
            pa.line([P(p0), P(p1)], self.col(v, -1 if back else int(r.choice([-1, 0]))), pa.u(r.uniform(0.4, 0.6)))

    def _rope(self, r, zr, tilt):
        """a twisted straw rope round the stack, a little out of level; its ends tuck in at the edges"""
        pa = self.pa; P = pa.P; Rp = self.T['rope']
        ta, tp = tilt
        pts = []
        for t in np.linspace(-0.6, math.pi + 0.6, 120):
            z = zr + ta * math.sin(t + tp)
            f = float(self.N(z, t) @ TOCAM)
            if f < 0.3: continue
            pts.append(self.S(z, t, 0.02 * min(1.0, (f - 0.3) / 0.2)))
        if len(pts) < 2: return
        seg = [P(p) for p in pts]
        pa.line(seg, ch.soft(Rp['dk']), pa.u(1.5))
        pa.line(seg, Rp['mid'], pa.u(1.15))
        # the twist: short slanted strands across the rope, lit on top
        for k, p in enumerate(pts):
            if k % 2: continue
            x, y = P(p)
            a = pa.u(0.5)
            pa.line([(x - a * 0.6, y - a), (x + a * 0.6, y + a)], Rp['dk'], pa.u(0.26))
            pa.line([(x - a * 0.9, y - a * 0.6), (x - a * 0.2, y - a * 1.1)], Rp['lt'], pa.u(0.2))
        for end in (0, -1):
            p = pts[end]; th = math.atan2(p[1], p[0])
            for k in range(5):
                t2 = th + (0.06 if end == 0 else -0.06) * k * 0.6 + r.normal(0, 0.03)
                z0 = p[2] + r.uniform(0.04, 0.1)
                q3 = [self.S(z0 - 0.2 * u, t2, 0.03 - 0.01 * u) for u in np.linspace(0, 1, 4)]
                v = self.tone(self.N(z0, t2), z0)
                pa.line([P(q) for q in q3], self.col(v, int(r.choice([0, 1]))), pa.u(0.5))

    def _edge(self):
        """the thin edge a shade darker than the straw, down both sides of the stack"""
        pa = self.pa; P = pa.P
        for side in (0, 1):
            pts = []; cols = []
            for z in np.linspace(0.04, self.H * 0.97, 70):
                dz = 0.01
                dr = (float(np.interp(z + dz, self.zs, self.rs)) - float(np.interp(z - dz, self.zs, self.rs))) / (2 * dz)
                b = math.asin(max(-1.0, min(1.0, 0.577 * dr)))
                th = b if side == 0 else math.pi - b
                pts.append(P(self.S(z, th))); cols.append(self.col(self.tone(self.N(z, th), z)))
            for i in range(len(pts) - 1):
                pa.line([pts[i], pts[i + 1]], ch.soft(cols[i]), pa.u(ch.SOFT_W))

    def _top(self, r):
        """the pole coming out of the top and a topknot of straw tied round it"""
        pa = self.pa; P = pa.P; Wd = self.T['wood']; T = self.T
        top = self.S(self.H, 0.0) * np.array([0, 0, 1]) + self.lean
        zt = self.H
        # the topknot: straws from round the pole bending out and down like a little fountain
        # the cap: a little flared cone of straw bound round the pole, covering the top of the stack
        sc = self.sc
        capz = [(0.1, 0.045), (0.04, 0.06), (-0.04, 0.1), (-0.12, 0.17), (-0.2, 0.235), (-0.26, 0.27)]
        cq = []
        NT = 48
        tt = np.linspace(-math.pi, math.pi, NT + 1)
        for i in range(len(capz) - 1):
            (z0, r0), (z1, r1) = capz[i], capz[i + 1]
            for j in range(NT):
                t0, t1 = tt[j], tt[j + 1]; tc = (t0 + t1) / 2
                q4 = [top + np.array([math.cos(a) * rr * sc, math.sin(a) * rr * sc, zz * sc]) for (zz, rr), a in
                      (((z0, r0), t0), ((z0, r0), t1), ((z1, r1), t1), ((z1, r1), t0))]
                slope = (r1 - r0) / (z0 - z1)
                n = nv(np.array([math.cos(tc), math.sin(tc), slope]))
                if n @ TOCAM < -0.1: continue
                cq.append((depth(sum(q4) / 4), q4, self.colc(0.5 + 0.55 * float(n @ LIGHT))))
        knot = []
        for k in range(40):
            th = 2 * math.pi * k / 40 + r.normal(0, 0.06)
            out = np.array([math.cos(th), math.sin(th), 0.0])
            n = nv(out + UP * 1.4)
            if n @ TOCAM < 0.05: continue
            pts = []
            for t in np.linspace(0, 1, 6):
                zz = 0.06 - 0.34 * t; rr = 0.05 + 0.24 * t ** 0.8
                pts.append(top + np.array([math.cos(th) * rr * sc, math.sin(th) * rr * sc, zz * sc]) + out * 0.006)
            lam = float(n @ LIGHT)
            knot.append((depth(pts[-1]), pts, self.col(0.5 + 0.55 * lam, int(r.choice([-1, 1, 1, 2])))))
        # the skirt of the cap: straw ends hanging off its rim
        rim = []
        for k in range(36):
            th = r.uniform(-0.4, math.pi + 0.4)
            out = np.array([math.cos(th), math.sin(th), 0.0])
            if float(nv(out + UP * 0.3) @ TOCAM) < 0.05: continue
            p0 = top + np.array([math.cos(th) * 0.26 * sc, math.sin(th) * 0.26 * sc, -0.24 * sc])
            p1 = p0 + out * 0.02 - UP * r.uniform(0.04, 0.09) * sc
            rim.append((p0, p1, self.col(0.5 + 0.5 * float(nv(out + UP) @ LIGHT), int(r.choice([-1, 0])))))
        pole = [top + UP * 0.06 * self.sc, top + UP * 0.46 * self.sc]
        # the cap, its straws and the hanging rim
        for _, q4, c3 in sorted(cq, key=lambda z: z[0]):
            pa.fill([P(q) for q in q4], c3)
        for p0, p1, c3 in rim:
            pa.line([P(p0), P(p1)], c3, pa.u(0.5))
        for _, pts, c2 in sorted(knot, key=lambda z: z[0]):
            pa.line([P(q) for q in pts], c2, pa.u(0.45))
        # the cap's thin edge
        for side in (0, 1):
            ed = []
            for zz, rr in capz:
                th = 0.0 if side == 0 else math.pi
                ed.append(P(top + np.array([math.cos(th) * rr * sc, 0.0, zz * sc])))
            pa.line(ed, ch.soft(self.colc(0.55)), pa.u(ch.SOFT_W))
        # the pole
        a, b = P(pole[0]), P(pole[1])
        w = pa.u(0.035 * 29)
        body = [(a[0] - w, a[1]), (b[0] - w * 0.85, b[1]), (b[0] + w * 0.85, b[1]), (a[0] + w, a[1])]
        pa.fill(body, Wd['mid']); pa.soft_edge(body, Wd['mid'])
        pa.line([(a[0] - w * 0.4, a[1]), (b[0] - w * 0.35, b[1])], Wd['lit'], w * 0.6)
        pa.line([(a[0] + w * 0.55, a[1]), (b[0] + w * 0.5, b[1])], Wd['dk'], w * 0.45)
        c = pa.ctx; c.save(); c.translate(*b); c.scale(w * 0.85, w * 0.38); c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
        c.set_source_rgb(*Wd['cut']); c.fill()
        # the tie round the knot
        ring = [top + UP * 0.0 + np.array([math.cos(t) * 0.066 * self.sc, math.sin(t) * 0.066 * self.sc, 0.0]) for t in np.linspace(-0.3, math.pi + 0.3, 20)]
        pa.line([P(q) for q in ring], self.T['rope']['dk'], pa.u(0.9))

    def _ground_straw(self):
        """loose straw lying on the ground round the foot"""
        pa = self.pa; r = np.random.default_rng(self.seed * 97 + 11)
        rb = float(self.rs[0])
        for k in range(34):
            th = r.uniform(-math.pi, math.pi)
            rr = rb + r.uniform(0.02, 0.32) * self.sc
            p0 = np.array([math.cos(th) * rr, math.sin(th) * rr, 0.004])
            a = th + r.normal(0, 0.7)
            L = r.uniform(0.1, 0.26)
            p1 = p0 + np.array([math.cos(a), math.sin(a), 0.0]) * L
            v = r.uniform(0.4, 0.8)
            def draw(p0=p0, p1=p1, v=v):
                pa.line([pa.P(p0), pa.P(p1)], self.col(v), pa.u(0.42))
            self.items.append((p0 + (p1 - p0) * 0.5, draw))

    def shadow(self):
        R = float(max(self.rs))
        ground_shadow(self.pa, 0.0, 0.0, R + 0.28, R + 0.22, 0.15)
        ground_shadow(self.pa, 0.0, 0.0, float(self.rs[0]) + 0.05, float(self.rs[0]), 0.16)


FRAMES = [dict(key=str(s), seed=s) for s in range(4)]
BB = (-50, -90, 50, 22)

if __name__ == '__main__':
    co.main(Rom, FRAMES, BB, 'rom.webp', 'rom')
