# Wax apple trees (cây mận, the Nam Bộ "mận" = roi, Syzygium samarangense) for Nông Trại Nhỏ, drawn from the real
# miền Tây orchard tree as small 3D models and painted in flat game tones with the thin same-colour edge of the other
# new plants (ch.SOFT), with the banana kit's camera, sun and night (../chuoi). Two shapes, each unripe (0) or ripe (1),
# like the game's other "k2" fruit trees:
#   shape 0: a mận An Phước orchard tree: a short pale trunk forking low, a dense dome; deep crimson fruit;
#   shape 1: an older mận hồng đào tree: a taller clear trunk, a broad umbrella crown; rosy pink-red fruit.
# The crown is the clump crown of the mango, longan, rambutan and pomelo kits (no dark lining, thin spots stay open).
# Leaves are simple, long oval with a short point, leathery and glossy, in fans down the slope of the crown. The bark is
# pale grey with reddish flakes. The fruit is what tells the tree: waxy, shiny bells, narrow at the stalk and broad at
# the bottom with a little ring of calyx teeth, hanging in tight bunches of 3-7 off the twigs and branches. Not ripe:
# smaller pale green-white bells and a few white puffs of stamens (bông mận).
import math, os, sys
import numpy as np, cairo
from PIL import Image
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'dambut', 'da', 'xoai', 'mit'): sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM
from da import bez
from mit import Mit

RS, SS = 9, 2
PX = RS * SS
KU = 29.0
UP = np.array([0, 0, 1.0])


def tones():
    return dict(
        green=[C('#1a4722'), C('#225a29'), C('#2c6d31'), C('#3a823a'), C('#4f984a')],
        und=[C('#3f6534'), C('#4d753e'), C('#5e874a')],
        young=[C('#5f6a2a'), C('#77812f'), C('#8f973a'), C('#a6aa4a'), C('#bbbd5e')],
        inner=C('#173f20'), deep=[C('#1c4723'), C('#235229'), C('#2b5e30')],
        bark=dict(lit=C('#b1a595'), mid=C('#8a7d6e'), dk=C('#62574c'), fis=C('#8a5e4a')),
        red=dict(body=C('#b8162c'), lit=C('#d8303f'), dk=C('#7c0e22'), hi=C('#ffd0d0'), rib=C('#94122a'), cal=C('#5a1a1c')),
        pink=dict(body=C('#d8435a'), lit=C('#ef6d7c'), dk=C('#a42a44'), hi=C('#ffe0e2'), rib=C('#bb3550'), cal=C('#6a2a26')),
        raw=dict(body=C('#c3d98a'), lit=C('#dcebab'), dk=C('#93ae5c'), hi=C('#f7fbe6'), rib=C('#a9c172'), cal=C('#6c7a3a')),
        stalk=C('#6a6234'), stalk_dk=C('#4c4626'),
        fl=[C('#f7f4e2'), C('#e6e2c4'), C('#cfc9a4')], fl_c=C('#d9c35a'),
    )


class Man(Mit):
    """shape 0 or 1, ripe 0 or 1"""
    NROS = 170          # twig ends on a clump of radius 0.9 (scaled by area); each holds a fan of leaves

    def __init__(self, shape, ripe, pa):
        self.pa = pa; self.seed = shape * 2 + ripe
        self.shape = shape; self.ripe = ripe
        r = self.rng = np.random.default_rng(shape * 5113 + 41)
        self.items = []
        self.T = tones()
        self.flush = []
        if shape == 0:
            self.ce = np.array([0.0, -0.06, 1.52]); self.ra = 1.16; self.ry = 1.02; self.rb = 0.86
        else:
            self.ce = np.array([0.0, -0.08, 1.98]); self.ra = 1.28; self.ry = 1.1; self.rb = 0.7
        self._clumps(r)
        self._trunk(r)
        for c in self.cl: self._clump_leaves(r, c)
        rf = np.random.default_rng(shape * 977 + ripe * 31 + 17)
        if ripe:
            self._bunches(rf, 14 if shape == 0 else 13, True)
        else:
            self._bunches(rf, 10 if shape == 0 else 9, False)
            self._flowers(rf, 7 if shape == 0 else 8)

    # ------------------------------------------------------------- crown layout
    def _clumps(self, r):
        ce, ra, ry, rb = self.ce, self.ra, self.ry, self.rb
        cl = []
        def ring(n, rad, dz, rc0, rc1, flat, tier, notch):
            m = n + 1 if notch else n
            az0 = math.pi / 2 + (2 * math.pi / m if notch else r.uniform(0, 2 * math.pi))
            for k in range(n):
                az = az0 + k * 2 * math.pi / m + r.normal(0, 0.08)
                d = rad * r.uniform(0.94, 1.05)
                c = ce + np.array([math.cos(az) * ra * d, math.sin(az) * ry * d, dz * rb + r.normal(0, 0.03)])
                rc = r.uniform(rc0, rc1)
                cl.append(dict(c=c, rc=rc, rz=rc * flat, tier=tier, az=az))
        if self.shape == 0:
            # a round dome: a full low ring with the front slot open for the trunk, a middle ring, a round top
            # a dense round crown, a little taller than wide, the trunk showing in the front slot
            ring(6, 0.62, -0.4, 0.5, 0.56, 0.68, 0, True)
            ring(4, 0.36, 0.1, 0.53, 0.58, 0.7, 1, False)
            ring(2, 0.1, 0.52, 0.5, 0.54, 0.74, 2, False)
        else:
            # older and wider: a broad low ring whose limbs bow under the fruit, a middle, a gentle top
            # an umbrella: a wide ring held high so the trunk shows, a middle, a low flat top
            ring(7, 0.66, -0.36, 0.48, 0.55, 0.58, 0, True)
            ring(4, 0.36, 0.12, 0.54, 0.6, 0.6, 1, False)
            ring(2, 0.1, 0.46, 0.5, 0.54, 0.62, 2, False)
        for c in cl:
            c['lumps'] = [(nv(r.normal(0, 1, 3)), r.uniform(1.4, 2.4), r.uniform(0, 6.28), r.uniform(0.05, 0.08)) for _ in range(4)]
            c['tv'] = r.uniform(-0.03, 0.03)
        # the coppery new flush: patches on the outside of the upper clumps
        for c in cl:
            if c['tier'] >= 1 and r.random() < 0.7 and FLUSH:
                for _ in range(1 + (c['tier'] == 2)):
                    a = r.uniform(0, 2 * math.pi); zz = r.uniform(0.4, 0.85); rr = math.sqrt(1 - zz * zz)
                    self.flush.append(c['c'] + np.array([rr * math.cos(a) * c['rc'], rr * math.sin(a) * c['rc'], zz * c['rz']]))
        self.cl = cl

    # ------------------------------------------------------------- wood
    def axis(self, z):
        return np.array([0.025 * math.sin(z * 1.9) + self.lean * z * z, 0.012 * math.sin(z * 2.6), z])

    def trad(self, z):
        return (0.13 if self.shape == 0 else 0.14) - 0.02 * z + 0.07 * math.exp(-max(0.0, z) / 0.11)

    def _trunk(self, r):
        self.lean = [-0.02, 0.025][self.shape]
        self.limbs = []; self.leaders = []
        low = [c for c in self.cl if c['tier'] == 0]
        mid = [c for c in self.cl if c['tier'] == 1]
        top = [c for c in self.cl if c['tier'] == 2]
        zf = 0.42 if self.shape == 0 else 1.08
        zs = np.linspace(-0.04, zf + 0.04, 14)
        # the trunk narrows into the fork, so its top never shows as a flat cut between the leaders
        tr = [self.trad(z) * (1 - 0.32 * max(0.0, (z - zf * 0.7) / (zf * 0.3 + 0.04)) ** 1.5) for z in zs]
        self._tube([self.axis(z) for z in zs], tr, np.array([0, 0, 0.5]), fiss=4, r=r)
        f0 = self.axis(zf); self.fork = f0
        self.tc = np.array([0.0, 0.0]); self.tR = self.trad(0.2)
        # three leaders out of the fork: left, right and one leaning back, all turning up into the crown
        if self.shape == 0:
            heads = [np.array([-0.6, 0.12, self.ce[2] - 0.02]), np.array([0.6, 0.04, self.ce[2] + 0.04]),
                     np.array([0.2, -0.38, self.ce[2] + 0.22])]
            w0 = 0.08
        else:
            heads = [np.array([-0.7, 0.12, self.ce[2] - 0.1]), np.array([0.7, 0.04, self.ce[2] - 0.05]),
                     np.array([-0.24, -0.5, self.ce[2] + 0.12])]
            w0 = 0.1
        for j, H in enumerate(heads):
            p1 = f0 + np.array([H[0] * 0.5, H[1] * 0.4, 0.16 if self.shape else 0.22])
            p2 = np.array([H[0] * 0.92, H[1] * 0.95, f0[2] + (H[2] - f0[2]) * 0.55])
            lp = [bez(f0 - UP * 0.16, p1, p2, H, t) for t in np.linspace(0, 1, 16)]
            lr = [w0 * (1 - 0.6 * t + 0.25 * max(0.0, 1 - t / 0.15)) * (0.85 if j == 2 else 1.0) for t in np.linspace(0, 1, 16)]
            key = (f0 + H) / 2 - TOCAM * (0.25 if j < 2 else 0.6)
            self._tube(lp, lr, key, fiss=2, r=r)
            self.leaders.append((lp, lr))
        # limbs from the leaders out into the clumps
        for c in low + mid + top:
            side = 0 if c['c'][0] < -0.2 else 1 if c['c'][0] > 0.2 else 2
            if c['c'][1] > 0.25 and side == 2: side = 0 if c['c'][0] < 0 else 1
            lp, lr = self.leaders[side]
            i0 = {0: 6, 1: 10, 2: 13}[c['tier']]
            b0 = lp[i0]; Tp = c['c'] - UP * c['rz'] * 0.2
            wl = lr[i0] * (0.62 if c['tier'] == 0 else 0.55)
            l = self._limb(r, b0, Tp, wl, key_back=0.45 if c['tier'] == 0 else 0.65, rise=0.05, sag=0.02)
            if c['tier'] == 0: self.limbs.append(l)

    # ------------------------------------------------------------- leaves
    def _cluster(self, r, c, p, ns, hc, G, dark=False):
        """a twig end with 4-6 long oval, leathery, glossy leaves with a short point, fanned down the slope of the crown"""
        T = self.T
        nrm0 = nv(ns + UP * 0.7)
        t1 = np.cross(nrm0, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(nrm0, t1)
        sun = float(ns @ LIGHT)
        ao = 0.72 + 0.3 * max(-1.0, min(1.0, hc)) + 0.12 * G
        nl = int(r.integers(4, 7))
        dn = -UP - (-UP @ nrm0) * nrm0
        down = nv(dn) if np.linalg.norm(dn) > 0.25 else None
        az0 = r.uniform(0, 2 * math.pi)
        leaves = []
        for k in range(nl):
            if down is not None:
                a = r.uniform(-1.3, 1.3)
                A = nv(down * math.cos(a) + nv(np.cross(nrm0, down)) * math.sin(a))
            else:
                az = az0 + k * 2 * math.pi / nl + r.normal(0, 0.5)
                A = math.cos(az) * t1 + math.sin(az) * t2
            el = r.uniform(-0.1, 0.25)
            ld = nv(A * math.cos(el) + nrm0 * math.sin(el) - UP * 0.15 + r.normal(0, 0.1, 3))
            sd = nv(np.cross(nrm0, ld))
            Ll = 0.19 * r.uniform(0.85, 1.15); Wl = Ll * r.uniform(0.36, 0.42)
            pt = p + (r.normal(0, 1, 3) * np.array([1, 1, 0.5])) * 0.022 + ld * 0.014
            # long oval, widest at the middle, a short point
            prof = [(0.0, 0.1), (0.08, 0.42), (0.2, 0.74), (0.36, 0.94), (0.5, 1.0), (0.64, 0.93), (0.78, 0.72),
                    (0.89, 0.44), (0.96, 0.18), (1.0, 0.0)]
            Lp_, Rp_ = [], []
            for (t, w) in prof:
                q = pt + ld * Ll * t - UP * Ll * 0.1 * t * t
                Lp_.append(q + sd * Wl * 0.5 * w); Rp_.append(q - sd * Wl * 0.5 * w)
            nn = nv(np.cross(ld, sd))
            if nn @ nrm0 < 0: nn = -nn
            topv = nn @ TOCAM > 0
            lam = float((nn if topv else -nn) @ LIGHT)
            v = (0.62 + 0.3 * max(-0.3, lam)) * ao + 0.2 * sun - 0.06
            leaves.append(dict(poly=Lp_ + Rp_[::-1], top=topv, v=v, lam=lam, mid=pt + ld * Ll * 0.5,
                               rib=(pt, pt + ld * Ll * 0.9 - UP * Ll * 0.08)))
        vm = float(np.mean([z['v'] for z in leaves]))
        for z in leaves:
            v = 0.6 * vm + 0.4 * z['v'] + c['tv']
            if not z['top']:
                z['col'] = T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            else:
                z['col'] = T['green'][0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4]
            # leathery glossy leaves: a sheen on most sunlit tops
            z['gloss'] = z['top'] and z['lam'] > 0.3 and v > 0.58
        return leaves

    # ------------------------------------------------------------- where bunches and panicles go
    def _surface_spots(self, r, n, zlo, zhi, front, gap):
        """points on the outside of the crown, spread out on screen, on the side facing the camera"""
        spots = []
        for c in self.cl:
            for _ in range(60):
                a = r.uniform(0, 2 * math.pi); zz = r.uniform(zlo, zhi); rr = math.sqrt(max(0.0, 1 - zz * zz))
                d = np.array([rr * math.cos(a), rr * math.sin(a), zz])
                if d[1] < front: continue
                p = self.env(c, d, 1.0)
                if any(self.inside(o, p, 0.92) for o in self.cl if o is not c): continue
                spots.append((p, d, c))
        r.shuffle(spots)
        picked, out = [], []
        for p, d, c in spots:
            sp = np.array(self.pa.P(p)) / self.pa.k
            if any(np.linalg.norm(sp - q) < gap for q in picked): continue
            picked.append(sp); out.append((p, d, c))
            if len(out) >= n: break
        return out

    # ------------------------------------------------------------- fruit bunches
    def _bunches(self, r, n, ripe):
        T = self.T
        F = (T['red'] if self.shape == 0 else T['pink']) if ripe else T['raw']
        spots = self._surface_spots(r, n + 4, -0.82, 0.3, -0.1, 0.38)
        got = 0
        for (p, d, c) in spots:
            if got >= n: break
            if p[2] < 0.42: continue
            got += 1
            ns = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            # a short stalk from the twig, then the fruit stalks fan out a little and hang straight down: a tight bunch
            Ls = r.uniform(0.03, 0.06)
            s0 = p - ns * 0.02
            s2 = s0 + ns * 0.04 - UP * Ls
            H = (0.078 if ripe else 0.056) * r.uniform(0.94, 1.06)       # half length of a bell
            nf = int(r.integers(4, 8)) if ripe else int(r.integers(3, 6))
            fruits = []
            for f in range(nf * 5):
                if len(fruits) >= nf: break
                az = r.uniform(0, 2 * math.pi); rad = r.uniform(0.0, 1.0) ** 0.7 * H * 1.5
                hd = np.array([math.cos(az), math.sin(az) * 0.8, 0.0])
                top = s2 + hd * rad - UP * r.uniform(0.01, 0.05 + H * 0.7)
                ax = nv(-UP + hd * r.uniform(0.05, 0.3) + r.normal(0, 0.08, 3))
                cen = top + ax * H
                if any(np.linalg.norm(cen - q) < H * 1.1 for (q, _, _, _) in fruits): continue
                fruits.append((cen, top, ax, H * r.uniform(0.92, 1.06)))
            assert min(q[2] - h for (q, _, _, h) in fruits) > 0.12, 'bunch too low'
            self.items.append((p + TOCAM * 0.35, self._bunch_draw(s0, s2, fruits, F,
                                                                  np.random.default_rng(int(r.integers(1, 1 << 30))))))

    def _flowers(self, r, n):
        """white puffs of stamens at the twig ends (bông mận), two to four together"""
        T = self.T
        for (p, d, c) in self._surface_spots(r, n, -0.4, 0.7, -0.2, 0.42):
            ns = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            pts = [p + ns * 0.03 + nv(r.normal(0, 1, 3)) * 0.045 for _ in range(int(r.integers(2, 5)))]
            def draw(pts=pts, rr=np.random.default_rng(int(r.integers(1, 1 << 30)))):
                pa = self.pa; P = pa.P; cx = pa.ctx
                cx.set_line_cap(cairo.LINE_CAP_ROUND)
                for q in sorted(pts, key=depth):
                    x, y = P(q); R = 0.034 * pa.k
                    for j in range(22):
                        a = 2 * math.pi * j / 22 + rr.normal(0, 0.1); ln = R * rr.uniform(0.7, 1.05)
                        side = -(math.cos(a) * SLIGHT[0] + math.sin(a) * SLIGHT[1])
                        col = T['fl'][0] if side > 0.2 else T['fl'][2] if side < -0.5 else T['fl'][1]
                        cx.new_path(); cx.move_to(x, y); cx.line_to(x + math.cos(a) * ln, y + math.sin(a) * ln * 0.9)
                        cx.set_source_rgb(*col); cx.set_line_width(pa.u(0.2)); cx.stroke()
                    cx.new_path(); cx.arc(x, y, R * 0.3, 0, 2 * math.pi); cx.set_source_rgb(*T['fl_c']); cx.fill()
            self.items.append((p + TOCAM * 0.3, draw))

    def _bunch_draw(self, s0, s2, fruits, F, rr):
        T = self.T
        # bell outline as (y, half width): y -1 at the stalk, 1 at the broad bottom
        prof = [(-1.0, 0.0), (-0.985, 0.11), (-0.94, 0.18), (-0.84, 0.26), (-0.66, 0.36), (-0.42, 0.48), (-0.16, 0.6),
                (0.12, 0.75), (0.38, 0.88), (0.6, 0.97), (0.76, 1.0), (0.88, 0.95), (0.95, 0.84), (0.99, 0.66), (1.0, 0.46)]
        def draw():
            pa = self.pa; P = pa.P; cx = pa.ctx
            cx.set_line_cap(cairo.LINE_CAP_ROUND)
            cx.new_path(); cx.move_to(*P(s0)); cx.line_to(*P(s2))
            cx.set_source_rgb(*T['stalk']); cx.set_line_width(pa.u(0.45)); cx.stroke()
            for (cen, top, ax, H) in fruits:
                pa.line([P(s2), P(top)], T['stalk'], pa.u(0.26), 0.95)
            for (cen, top, ax, H) in sorted(fruits, key=lambda z: depth(z[0])):
                c2 = np.array(P(cen)); t2 = np.array(P(top))
                axv = c2 - t2; Hs = np.linalg.norm(axv)
                axv = axv / Hs if Hs > 1e-6 else np.array([0.0, 1.0]); sx = np.array([axv[1], -axv[0]])
                Ws = H * 0.8 * pa.k
                right = [tuple(c2 + axv * Hs * y + sx * Ws * w) for (y, w) in prof]
                left = [tuple(c2 + axv * Hs * y - sx * Ws * w) for (y, w) in prof[::-1]]
                # the bottom: a shallow dip in the middle where the calyx sits
                bot = [tuple(c2 + axv * Hs * 0.96 + sx * Ws * 0.22), tuple(c2 + axv * Hs * 0.93 + sx * Ws * 0.06), tuple(c2 + axv * Hs * 0.93 - sx * Ws * 0.06), tuple(c2 + axv * Hs * 0.96 - sx * Ws * 0.22)]
                body = right + bot + left
                pa.fill(body, F['body'])
                cx.save(); pa.path(body); cx.clip()
                ang = math.atan2(axv[1], axv[0])
                sg = 1 if sx @ SLIGHT > 0 else -1
                # shade side, then the lit side, two faint lobe lines and the waxy shine
                cx.new_path(); pa.path(body); cx.set_source_rgb(*F['dk']); cx.fill()
                # the body tone over all but a crescent on the shade side (the bell's broad bottom stays body colour)
                o2 = c2 - sx * sg * Ws * 0.14
                bod = [tuple(o2 + axv * Hs * y + sx * Ws * w * (0.78 if sg > 0 else 1.06)) for (y, w) in prof]
                bod += [tuple(o2 + axv * Hs * y - sx * Ws * w * (1.06 if sg > 0 else 0.78)) for (y, w) in prof[::-1]]
                pa.fill(bod, F['body'])
                lt = [tuple(c2 + axv * Hs * (y * 0.86 + 0.06) - sx * sg * Ws * (0.18 + w * 0.42)) for (y, w) in prof[2:12]]
                lt += [tuple(c2 + axv * Hs * (y * 0.86 + 0.06) - sx * sg * Ws * (0.18 - w * 0.3)) for (y, w) in prof[2:12][::-1]]
                pa.fill(lt, F['lit'])
                for f in (-0.4, 0.38):
                    pts = [tuple(c2 + axv * Hs * y + sx * Ws * w * f) for (y, w) in prof[3:-2]]
                    pa.line(pts, F['rib'], pa.u(0.2), 0.55)
                hp = [tuple(c2 + axv * Hs * y - sx * sg * Ws * w * 0.55) for (y, w) in prof[3:11]]
                pa.line(hp, F['hi'], max(pa.u(0.42), Ws * 0.16), 0.8)
                cx.restore()
                pa.soft_edge(body, F['body'])
                # the calyx sits in the dip at the bottom: a few small teeth
                b0 = c2 + axv * Hs * 0.86
                for f in (-0.14, 0.0, 0.14):
                    q = b0 + sx * Ws * f
                    cx.new_path(); cx.move_to(*q); cx.line_to(*(q + axv * Hs * 0.08 + sx * Ws * f * 0.5))
                    cx.set_source_rgb(*mixc(F['cal'], F['dk'], 0.4)); cx.set_line_width(pa.u(0.28)); cx.stroke()
        return draw


# key "sr": s = shape, r = ripe (the game picks ((t>>1)&1, t&1))
FRAMES = [dict(key='00', shape=0, ripe=0), dict(key='01', shape=0, ripe=1), dict(key='10', shape=1, ripe=0), dict(key='11', shape=1, ripe=1)]
BB = (-62, -100, 62, 25)
FLUSH = False


def render(fr, night=False, bb=BB):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    Man(fr['shape'], fr['ripe'], pa).paint()
    surf.flush(); ch.NIGHT = False
    return surf, bb


def to_image(surf):
    w, h = surf.get_width(), surf.get_height()
    a = np.ndarray((h, w, 4), np.uint8, surf.get_data()).copy()
    im = Image.frombuffer('RGBa', (w, h), a[:, :, [2, 1, 0, 3]].tobytes(), 'raw', 'RGBa', 0, 1)
    return im.resize((w // SS, h // SS), Image.LANCZOS).convert('RGBA')


def atlas(outdir, tabpath):
    """4 frames, day and night, cropped and packed into one webp; writes the frame table json (d00..n11)"""
    import json
    crops = []
    for fr in FRAMES:
        for night in (False, True):
            surf, bb = render(fr, night)
            im = to_image(surf)
            a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            crops.append(('nd'[not night] + fr['key'], im.crop((x0, y0, x1, y1)), bb[0] + x0 / RS, bb[1] + y0 / RS))
    cols = 4; x = y = rowh = 0; pos = {}
    for k, (name, im, dx, dy) in enumerate(crops):
        if k and k % cols == 0: x = 0; y += rowh + 2; rowh = 0
        pos[name] = (x, y); x += im.width + 2; rowh = max(rowh, im.height)
    Wt = max(pos[n][0] + im.width for n, im, _, _ in crops); Ht = y + rowh
    sheet = Image.new('RGBA', (Wt, Ht), (0, 0, 0, 0)); table = {}
    for name, im, dx, dy in crops:
        sx, sy = pos[name]; sheet.paste(im, (sx, sy))
        table[name] = [sx, sy, im.width, im.height, round(dx, 2), round(dy, 2), round(im.width / RS, 2), round(im.height / RS, 2)]
    path = os.path.join(outdir, 'k2_man.webp')
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
        sheet = Image.new('RGBA', (w, h), (40, 58, 52, 255) if night else (153, 204, 86, 255)); x = 0
        for im in ims:
            sheet.alpha_composite(im, (x, 0)); x += im.width
        sheet.save('/tmp/claude-0/g/man_%s.png' % tag); print(sheet.size)
