# Ferns (dương xỉ) for Nông Trại Nhỏ, built as small 3D models and painted in flat game tones with the thin
# same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun and night (../chuoi).
# Drawn from the real plant (Nephrolepis, dương xỉ lá kiếm, the fern of every Nam Bộ yard, ditch bank and verandah):
# long narrow once-pinnate fronds, each a green rachis with a row of small lance-shaped leaflets (pinnae) on both
# sides, short at the base, longest a third of the way out, shrinking to a pointed tip. Fronds rise from one crown,
# arch out and droop. Undersides are paler and carry rows of brown spore dots (sori). Young fronds unroll from a
# coiled fiddlehead (ngọn cuộn).
# Two shapes (vars 2):
#   0 a wild clump on the ground: a fountain of 22 arching fronds, 3 old brown fronds lying low, 3 fiddleheads;
#   1 a fern in a terracotta pot (the pot of ../mai), its fronds spilling over the rim and hanging down the sides.
import math, os, sys
import numpy as np, cairo
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'co', 'mai', 'dambut'):
    sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import C, nv, mixc, depth, LIGHT, TOCAM
import co
from co import ground_shadow, Plant
import mai as maikit

UP = np.array([0, 0, 1.0])


def tones():
    return dict(
        # fern green is fresher and yellower than the shrubs round it
        top=[C('#1f5326'), C('#2b6c2e'), C('#3b883a'), C('#54a346'), C('#72bc58'), C('#8acb64')],
        under=[C('#3e6c35'), C('#4f8041'), C('#62964d')],
        rachis=C('#3b883a'), rachis_lit=C('#5e8f3a'), stipe=C('#6e7a3a'),
        dry=[C('#7a5a30'), C('#93703c'), C('#ab874a'), C('#c09e5c')],
        sorus=C('#8a5a2a'),
        fid=dict(dk=C('#5d8a34'), mid=C('#7fac44'), lit=C('#a4c95e'), fuzz=C('#9a7448')),
        scale=C('#7a5c34'),
    )


class Frond:
    """one frond: a rachis curve that leaves the crown at el0, arches out along az and droops; pinnae on both sides"""
    def __init__(self, base, az, el0, L, droop, rng, dry=False, twist=0.0, n=28, avoid=None, zmin=0.03, lp=0.17):
        self.dry = dry
        dh = np.array([math.cos(az), math.sin(az), 0.0])
        perp = np.array([-math.sin(az), math.cos(az), 0.0])
        m = 40
        for _ in range(60):
            pts, tans = [], []
            p = np.array(base, float)
            for i in range(m + 1):
                s = i / m
                el = el0 - droop * s ** 1.1
                # a long frond that reaches the soil lies along it instead of going in
                if p[2] <= zmin + 0.04 and i > 2: el = max(el, -0.08 * (p[2] - zmin) / 0.04 if p[2] > zmin else 0.0)
                t = dh * math.cos(el) + UP * math.sin(el)
                pts.append(p.copy()); tans.append(t)
                p = p + t * L / m
            ok = True
            if avoid is not None: ok = avoid(pts)
            if ok: break
            droop *= 0.94
            if avoid is not None: el0 = min(math.radians(88), el0 + math.radians(1.2))
        self.pts, self.tans, self.L = pts, tans, L
        self.perp, self.twist = perp, twist
        # leaflets: alternate on the two sides, uniform for most of the length, shorter at the base, tapering to the tip
        self.pinnae = []
        ns = n
        s0 = 0.1
        for side in (1, -1):
            for k in range(ns):
                s = s0 + (1 - s0) * (k + (0.5 if side < 0 else 0.0)) / ns
                if s > 0.985: continue
                ln = L * lp * min(1.0, (s - s0 + 0.04) / 0.22) ** 0.55 * (1 - 0.86 * max(0.0, (s - 0.45) / 0.55) ** 1.5)
                self.pinnae.append((s, side, ln * rng.uniform(0.92, 1.06), rng.uniform(-0.12, 0.12)))

    def at(self, s):
        f = s * (len(self.pts) - 1); i = min(int(f), len(self.pts) - 2); fr = f - i
        return self.pts[i] * (1 - fr) + self.pts[i + 1] * fr, nv(self.tans[i] * (1 - fr) + self.tans[i + 1] * fr)

    def frame(self, s):
        q, t = self.at(s)
        tw = self.twist * s
        sd = nv(self.perp - t * (self.perp @ t))
        nb = nv(np.cross(t, sd))
        if nb[2] < 0: nb = -nb
        sd, nb = nv(sd * math.cos(tw) + nb * math.sin(tw)), nv(nb * math.cos(tw) - sd * math.sin(tw))
        if nb[2] < 0: nb = -nb
        return q, t, sd, nb


def pinna_poly(q, t, sd, nb, side, ln, fwd, droop):
    """a lance-shaped leaflet: rounded eared base on the rachis, widest a quarter out, a sickle curve to a point"""
    e = nv(sd * side * math.cos(fwd) + t * math.sin(fwd) - nb * droop)
    w = np.cross(nb, e); w = nv(w) if np.linalg.norm(w) > 1e-6 else t
    if w @ t < 0: w = -w                                     # +w points toward the frond tip
    W = ln * 0.42
    prof = [(0.0, 0.42), (0.08, 0.92), (0.22, 1.0), (0.45, 0.86), (0.68, 0.6), (0.86, 0.3), (1.0, 0.0)]
    bend = lambda u: (u ** 2) * 0.16 * ln                    # the leaflet tip curves toward the frond tip
    up = [q + e * ln * u + w * (W * h * 0.5 + bend(u) * 0.5) for u, h in prof]
    lo = [q + e * ln * u + w * (-W * h * 0.5 + bend(u) * 0.5) - nb * 0.0 for u, h in prof[::-1]]
    # the ear: the tip-side base lobe overlaps the rachis a little (Nephrolepis auricle)
    return up + lo, e, w


class DuongXi(Plant):
    """seed 0: wild clump on the ground; seed 1: fern in a terracotta pot"""
    def __init__(self, seed, pa):
        self.pa = pa; self.seed = seed
        self.q = seed % 2
        r = self.rng = np.random.default_rng(seed * 7717 + 23)
        self.items = []
        self.T = tones()
        if self.q == 0: self._clump(r)
        else: self._potted(r)

    # ------------------------------------------------------------- shapes
    def _clump(self, r):
        n = 44
        self.R = 0.9
        for j in range(n):
            az = 2 * math.pi * (j + r.uniform(-0.35, 0.35)) / n + 0.2
            outer = r.uniform(0, 1) ** 0.7
            base = np.array([math.cos(az), math.sin(az), 0.0]) * 0.06 * r.uniform(0.3, 1)
            el0 = math.radians(86 - 18 * outer + r.normal(0, 4))
            L = (0.95 + 0.55 * outer) * r.uniform(0.86, 1.1)
            tip = math.radians(30 - 62 * outer + r.normal(0, 8))           # where the tip ends up pointing
            droop = el0 - tip
            fr = Frond(base, az, el0, L, droop, r, twist=r.normal(0, 0.3), n=int(12 + 3 * outer))
            self._frond(fr, ao=0.55 * (1 - outer), key_push=0.1 * outer)
        # a few young fronds standing straight up in the heart
        for j in range(9):
            az = r.uniform(0, 2 * math.pi)
            fr = Frond(np.zeros(3), az, math.radians(r.uniform(80, 88)), r.uniform(0.7, 0.85), math.radians(r.uniform(25, 45)), r, n=11)
            self._frond(fr, ao=0.05, key_push=0.05)
        # old fronds gone brown, lying low on the ground at the edge of the clump
        for j, a in enumerate((2.3, 4.1, 5.6)):
            az = a + r.normal(0, 0.2)
            fr = Frond(np.array([math.cos(az), math.sin(az), 0]) * 0.05, az, math.radians(40), r.uniform(0.7, 0.82),
                       math.radians(45), r, dry=True, n=12, zmin=0.025)
            self._frond(fr, ao=0.0, key_push=-0.25)
        for az in (0.6, 2.9, 4.6):
            self._fiddle(r, az + r.normal(0, 0.15), r.uniform(0.3, 0.38))

    def _potted(self, r):
        # a slightly smaller pot than the mai's, the fronds spill over its rim
        self.PH = 0.5
        sc = 0.86
        self.prof = lambda t: sc * maikit.Mai.prof(None, t)
        self.T.update({k: v for k, v in maikit.tones().items() if k in ('pot', 'soil', 'soil2', 'root')})
        self.R = 0.62
        maikit.Mai._pot(self, np.random.default_rng(5))
        # the pot sorts by its middle, so fronds hanging behind it go under it and the ones in front over it
        self.items[-1] = (np.array([0, 0, 0.2]), self.items[-1][1])
        zr = 0.9 * self.PH + 0.03
        Rr = self.prof(0.9) + 0.05

        def avoid(pts):
            # a frond never passes into the pot: below the rim it must already be outside the pot's wall
            for q in pts:
                rr = math.hypot(q[0], q[1])
                if q[2] < zr - 0.01 and rr < Rr + 0.03: return False
            return True
        n = 24
        for j in range(n):
            az = 2 * math.pi * (j + r.uniform(-0.3, 0.3)) / n + 0.1
            outer = r.uniform(0, 1) ** 0.6
            base = np.array([math.cos(az) * 0.07, math.sin(az) * 0.07, zr])
            el0 = math.radians(78 - 30 * outer + r.normal(0, 3))
            L = (0.7 + 0.45 * outer) * r.uniform(0.88, 1.1)
            droop = math.radians(100 + 80 * outer) * r.uniform(0.85, 1.12)       # the long outer fronds hang down
            fr = Frond(base, az, el0, L, droop, r, twist=r.normal(0, 0.3), n=int(12 + 3 * outer), avoid=avoid, zmin=0.06)
            self._frond(fr, ao=0.5 * (1 - outer), key_push=0.1 * outer)
        for j in range(5):
            az = r.uniform(0, 2 * math.pi)
            fr = Frond(np.array([0, 0, zr]), az, math.radians(r.uniform(80, 88)), r.uniform(0.6, 0.75),
                       math.radians(r.uniform(35, 55)), r, n=10, avoid=avoid)
            self._frond(fr, ao=0.05, key_push=0.05)
        for az in (1.2, 3.8):
            self._fiddle(r, az, r.uniform(0.26, 0.32), z0=zr)

    # ------------------------------------------------------------- pieces
    def _frond(self, fr, ao=0.0, key_push=0.0):
        """the frond goes in as 4 pieces along its length so crossing fronds sort by depth piece by piece"""
        pa = self.pa; T = self.T
        cuts = [0.0, 0.3, 0.55, 0.78, 1.0]
        for c0, c1 in zip(cuts[:-1], cuts[1:]):
            leaflets = []
            for s, side, ln, jit in fr.pinnae:
                if not (c0 <= s < c1): continue
                q, t, sd, nb = fr.frame(s)
                droop = 0.25 + 0.5 * s + jit                       # leaflets hang a little, more toward the tip
                poly3, e, w = pinna_poly(q, t, sd, nb, side, ln, math.radians(16 + 10 * s), droop)
                npn = nv(np.cross(e, w))
                if npn[2] < 0: npn = -npn
                npn = nv(npn + nb * 0.6)
                front = npn @ TOCAM > 0
                vis = npn if front else -npn
                lam = float(vis @ LIGHT)
                aoo = ao * (1 - s) + 0.12 * max(0.0, 0.45 - q[2])       # low and inner leaflets sit in shade
                if fr.dry:
                    pal = T['dry']; v = 0.45 + 0.4 * lam - 0.2 * aoo
                elif front:
                    pal = T['top']; v = 0.3 + 0.62 * lam - 0.8 * aoo
                else:
                    pal = T['under']; v = 0.45 + 0.35 * lam - 0.4 * aoo
                k = max(0, min(len(pal) - 1, int(v * len(pal))))
                leaflets.append((poly3, pal[k], front, q + e * ln * 0.5, s, e, w, ln))
            sm = 0.5 * (c0 + c1)
            q0, _ = fr.at(min(1.0, c1)); qa, _ = fr.at(c0)
            rpts = [fr.at(c0 + (c1 - c0) * u)[0] for u in np.linspace(0, 1, 7)]
            w0 = 0.3 * (1 - c0 * 0.7); w1 = 0.3 * (1 - c1 * 0.7)
            rc = T['dry'][1] if fr.dry else (T['stipe'] if c1 <= 0.12 else T['rachis'])
            lit_up = fr.frame(sm)[3] @ TOCAM > 0

            def draw(leaflets=leaflets, rpts=rpts, w0=w0, w1=w1, rc=rc, c0=c0, lit_up=lit_up, dry=fr.dry, fr=fr):
                P = pa.P
                if c0 == 0.0:
                    # the bare stipe from the crown to the first leaflets, with a few brown scales at its foot
                    st = [P(fr.at(u)[0]) for u in np.linspace(0, 0.11, 5)]
                    pa.taper(st, pa.u(0.6), pa.u(0.45), T['dry'][0] if dry else T['stipe'], outline=T['stipe'])
                ls = sorted(leaflets, key=lambda z: depth(z[3]))
                if not lit_up: pa.taper([P(p) for p in rpts], pa.u(w0), pa.u(w1), rc)
                for poly3, col, front, mid, s, e, w, ln in ls:
                    poly = [P(p) for p in poly3]
                    pa.fill(poly, col); pa.soft_edge(poly, col)
                    if not front and not dry and s > 0.3:
                        # two rows of spore dots under the leaflet
                        for u in (0.3, 0.55):
                            for sg in (1, -1):
                                x, y = P(mid - e * ln * (0.5 - u) + w * sg * ln * 0.09)
                                pa.ctx.new_path(); pa.ctx.arc(x, y, pa.u(0.13), 0, 2 * math.pi)
                                pa.ctx.set_source_rgb(*mixc(T['sorus'], col, 0.35)); pa.ctx.fill()
                    elif front and not dry:
                        # the midvein, a lighter line down the leaflet
                        a = P(poly3[0] * 0.5 + poly3[-1] * 0.5); b = P(poly3[len(poly3) // 2 - 1] * 0.7 + poly3[len(poly3) // 2] * 0.3)
                        pa.line([a, b], mixc(col, C('#e6f2b8'), 0.28), pa.u(0.13), 0.7)
                if lit_up: pa.taper([P(p) for p in rpts], pa.u(w0), pa.u(w1), rc)
            self.items.append((fr.at(sm)[0] + TOCAM * key_push, draw))

    def _fiddle(self, r, az, H, z0=0.0):
        """a young frond still coiled: a fuzzy stalk up out of the crown ending in a tight spiral (ngọn cuộn)"""
        pa = self.pa; F = self.T['fid']
        dh = np.array([math.cos(az), math.sin(az), 0.0])
        stalk = [dh * (0.04 + 0.12 * t ** 1.6) + UP * (z0 + H * t) for t in np.linspace(0, 1, 10)]
        top = stalk[-1]
        # the coil sits in the vertical plane of az, rolled outward (toward dh) then down
        R0 = 0.095; spiral = []
        for th in np.linspace(0, 3.2 * math.pi, 40):
            rr = R0 * math.exp(-0.21 * th)
            c = top + dh * R0 * 0.0
            spiral.append(top + dh * (R0 - rr * math.cos(th)) * 1.0 + UP * (rr * math.sin(th)) + dh * 0.0)
        def draw():
            P = pa.P
            pa.taper([P(q) for q in stalk], pa.u(0.75), pa.u(0.6), F['mid'], outline=F['mid'])
            # the lit side of the stalk
            pa.line([P(q + nv(np.array([LIGHT[0], LIGHT[1], 0])) * 0.006) for q in stalk[2:]], F['lit'], pa.u(0.22), 0.8)
            sp = [P(q) for q in spiral]
            pa.taper(sp, pa.u(0.85), pa.u(0.35), F['mid'], outline=F['mid'])
            pa.line(sp[:28], F['lit'], pa.u(0.22), 0.8)
            # the coil's heart, a small round knot
            x, y = sp[-1]; pa.ctx.new_path(); pa.ctx.arc(x, y, pa.u(0.4), 0, 2 * math.pi)
            pa.ctx.set_source_rgb(*F['dk']); pa.ctx.fill()
            # brown fuzz (hairs and scales) on the stalk and coil
            for i, q in enumerate(stalk[1:] + spiral[::5]):
                if i % 2: continue
                x, y = P(q); pa.ctx.new_path(); pa.ctx.arc(x + pa.u(0.15), y, pa.u(0.14), 0, 2 * math.pi)
                pa.ctx.set_source_rgb(*F['fuzz']); pa.ctx.fill()
        self.items.append((top + TOCAM * 0.15, draw))

    def shadow(self):
        if self.q == 0:
            ground_shadow(self.pa, 0.0, 0.05, self.R * 0.8, self.R * 0.7, 0.15)
            ground_shadow(self.pa, 0.0, 0.0, 0.3, 0.26, 0.12)
        else:
            ground_shadow(self.pa, 0.0, 0.05, 0.72, 0.62, 0.14)
            ground_shadow(self.pa, 0.0, 0.0, 0.42, 0.38, 0.16)


FRAMES = [dict(key=str(s), seed=s) for s in range(2)]
BB = (-55, -72, 55, 24)

if __name__ == '__main__':
    os.makedirs('/tmp/claude-0/g', exist_ok=True)
    co.KU = 29.0 * 1.12          # v1 in the game read a little small next to the hibiscus
    co.main(DuongXi, FRAMES, BB, 'duongxi.webp', 'duongxi')
