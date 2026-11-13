# Longan trees (cây nhãn) for Nông Trại Nhỏ, built as small 3D models and painted in flat game tones with the thin
# same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun and night (../chuoi).
# Link asked for two shapes. Like the game's other "k2" fruit trees each is drawn unripe (0) or ripe (1):
#   shape 0: a younger tree, one trunk that forks at knee height into three limbs, a round dense dome;
#   shape 1: an old orchard tree pruned low and wide the miền Tây way, a thick gnarled trunk splitting low into three
#            leaders that spread out, a broad umbrella crown.
# The crown is the mango kit's clump crown (../xoai, ../da): every clump a shell of leaves, nothing lining the inside,
# so thin spots show the branches and what is behind. Longan leaves are compound: each twig end carries a few leaves,
# each a short stalk with 3-4 pairs of narrow, slightly wavy, dark glossy leaflets; the new flush on top is coppery.
# Fruit hangs in loose bunches (chùm) off the twig ends on the outside of the crown: a stalk that branches, each
# branchlet holding a few round fruits. Ripe: big bunches of tan-brown fruit. Not ripe: cream-yellow flower panicles
# standing up over the crown and a few bunches of small green fruit.
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
        green=[C('#1a4824'), C('#22582b'), C('#2c6932'), C('#3a7c3c'), C('#4e914a')],
        und=[C('#43623a'), C('#517244'), C('#62844f')],
        young=[C('#5f6a2a'), C('#77812f'), C('#8f973a'), C('#a6aa4a'), C('#bbbd5e')],
        inner=C('#173f20'), deep=[C('#1c4723'), C('#235229'), C('#2b5e30')],
        bark=dict(lit=C('#9a8a78'), mid=C('#736454'), dk=C('#51463b'), fis=C('#43392f')),
        ripe=dict(body=C('#c39a55'), lit=C('#dcbb78'), dk=C('#94723c'), hi=C('#f1deb0'), speck=C('#8c6c3c')),
        raw=dict(body=C('#9aac4a'), lit=C('#bccb6c'), dk=C('#6e7f32'), hi=C('#e2eba8'), speck=C('#66762e')),
        stalk=C('#6f6236'), stalk_dk=C('#53482a'),
        pan=dict(stalk=C('#8a7a3e'), fl=[C('#d9cc78'), C('#e8de98'), C('#f6efc4')]),
    )


class Nhan(Mit):
    """shape 0 or 1, ripe 0 or 1"""
    NROS = 100          # twig ends on a clump of radius 0.9 (scaled by area); each holds a few compound leaves

    def __init__(self, shape, ripe, pa):
        self.pa = pa; self.seed = shape * 2 + ripe
        self.shape = shape; self.ripe = ripe
        r = self.rng = np.random.default_rng(shape * 5113 + 41)
        self.items = []
        self.T = tones()
        self.flush = []
        if shape == 0:
            self.ce = np.array([0.0, -0.06, 1.58]); self.ra = 1.12; self.ry = 1.0; self.rb = 0.86
        else:
            self.ce = np.array([0.0, -0.08, 1.36]); self.ra = 1.32; self.ry = 1.14; self.rb = 0.6
        self._clumps(r)
        self._trunk(r)
        for c in self.cl: self._clump_leaves(r, c)
        rf = np.random.default_rng(shape * 977 + ripe * 31 + 7)
        if ripe:
            self._bunches(rf, 11 if shape == 0 else 13, True)
        else:
            self._panicles(rf, 7 if shape == 0 else 9)
            self._bunches(rf, 7 if shape == 0 else 8, False)

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
            ring(6, 0.6, -0.36, 0.5, 0.56, 0.66, 0, True)
            ring(4, 0.34, 0.12, 0.52, 0.57, 0.68, 1, False)
            ring(2, 0.1, 0.5, 0.48, 0.52, 0.72, 2, False)
        else:
            # pruned low and wide: a broad flat ring, a low middle, a gentle top
            ring(7, 0.68, -0.28, 0.5, 0.58, 0.54, 0, True)
            ring(4, 0.36, 0.1, 0.56, 0.62, 0.56, 1, False)
            ring(2, 0.1, 0.42, 0.54, 0.58, 0.6, 2, False)
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
        return (0.13 if self.shape == 0 else 0.19) - 0.02 * z + 0.07 * math.exp(-max(0.0, z) / 0.11)

    def _trunk(self, r):
        self.lean = [0.02, -0.03][self.shape]
        self.limbs = []; self.leaders = []
        low = [c for c in self.cl if c['tier'] == 0]
        mid = [c for c in self.cl if c['tier'] == 1]
        top = [c for c in self.cl if c['tier'] == 2]
        zf = 0.62 if self.shape == 0 else 0.46
        zs = np.linspace(-0.04, zf + 0.04, 14)
        # the trunk narrows into the fork, so its top never shows as a flat cut between the leaders
        tr = [self.trad(z) * (1 - 0.32 * max(0.0, (z - zf * 0.7) / (zf * 0.3 + 0.04)) ** 1.5) for z in zs]
        self._tube([self.axis(z) for z in zs], tr, np.array([0, 0, 0.5]), fiss=4, r=r)
        f0 = self.axis(zf); self.fork = f0
        self.tc = np.array([0.0, 0.0]); self.tR = self.trad(0.2)
        # three leaders out of the fork: left, right and one leaning back, all turning up into the crown
        if self.shape == 0:
            heads = [np.array([-0.5, 0.1, self.ce[2] + 0.05]), np.array([0.52, 0.02, self.ce[2] + 0.1]),
                     np.array([-0.24, -0.4, self.ce[2] + 0.22])]
            w0 = 0.085
        else:
            heads = [np.array([-0.72, 0.12, self.ce[2] - 0.05]), np.array([0.74, -0.02, self.ce[2]]),
                     np.array([0.32, -0.5, self.ce[2] + 0.12])]
            w0 = 0.115
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
        """a twig end with 2-3 compound leaves: a short stalk with 3-4 pairs of narrow, slightly wavy leaflets"""
        T = self.T
        nrm0 = nv(ns + UP * 0.6)
        t1 = np.cross(nrm0, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(nrm0, t1)
        sun = float(ns @ LIGHT)
        ao = 0.72 + 0.3 * max(-1.0, min(1.0, hc)) + 0.12 * G
        young = any(np.linalg.norm(p - f) < 0.17 for f in self.flush)
        nleaf = int(r.integers(2, 4))
        dn = -UP - (-UP @ nrm0) * nrm0
        down = nv(dn) if np.linalg.norm(dn) > 0.25 else None
        az0 = r.uniform(0, 2 * math.pi)
        out = []
        for k in range(nleaf):
            if down is not None:
                a = r.uniform(-1.3, 1.3)
                A = nv(down * math.cos(a) + nv(np.cross(nrm0, down)) * math.sin(a))
            else:
                az = az0 + k * 2 * math.pi / nleaf + r.normal(0, 0.5)
                A = math.cos(az) * t1 + math.sin(az) * t2
            el = r.uniform(-0.05, 0.3)
            rd = nv(A * math.cos(el) + nrm0 * math.sin(el) - UP * (0.5 if young else 0.12))   # the rachis
            sd0 = nv(np.cross(nrm0, rd))
            Lr = 0.22 * r.uniform(0.85, 1.1) * (0.8 if young else 1.0)
            pt = p + (r.normal(0, 1, 3) * np.array([1, 1, 0.5])) * 0.02
            npair = int(r.choice([2, 3, 3, 4]))
            for j in range(npair):
                t = 0.28 + 0.72 * (j + 0.5) / npair
                q0 = pt + rd * Lr * t - UP * Lr * 0.12 * t * t
                for sg in (1, -1):
                    # leaflets angle forward along the rachis; the last pair is the longest
                    fw = r.uniform(0.2, 0.5) + 0.2 * j / max(1, npair - 1)
                    ld = nv(sd0 * sg * math.cos(fw) + rd * math.sin(fw) - UP * r.uniform(0.05, 0.3) + nrm0 * r.normal(0, 0.22))
                    sd = nv(np.cross(nrm0, ld))
                    Ll = (0.1 + 0.03 * j / max(1, npair - 1)) * r.uniform(0.88, 1.12); Wl = Ll * r.uniform(0.38, 0.44)
                    qq = q0 + sd0 * sg * 0.004
                    wav = r.uniform(0, 6.28)
                    prof = [(0.0, 0.1), (0.1, 0.6), (0.27, 0.92), (0.45, 1.0), (0.64, 0.92), (0.8, 0.68), (0.92, 0.36), (1.0, 0.0)]
                    Lp_, Rp_ = [], []
                    for (tt, w) in prof:
                        wv = 1 + 0.08 * math.sin(tt * 9 + wav)
                        q = qq + ld * Ll * tt - UP * Ll * 0.14 * tt * tt
                        Lp_.append(q + sd * Wl * 0.5 * w * wv); Rp_.append(q - sd * Wl * 0.5 * w * (2 - wv))
                    nn = nv(np.cross(ld, sd))
                    if nn @ nrm0 < 0: nn = -nn
                    topv = nn @ TOCAM > 0
                    lam = float((nn if topv else -nn) @ LIGHT)
                    v = (0.62 + 0.3 * max(-0.3, lam)) * ao + 0.2 * sun - 0.06
                    out.append(dict(poly=Lp_ + Rp_[::-1], top=topv, v=v, lam=lam, mid=qq + ld * Ll * 0.5,
                                    rib=(qq, qq + ld * Ll * 0.88 - UP * Ll * 0.1)))
        vm = float(np.mean([z['v'] for z in out]))
        for z in out:
            v = 0.6 * vm + 0.4 * z['v'] + c['tv']
            if young and z['top']:
                z['col'] = T['young'][max(0, min(4, int((v - 0.35) / 0.12)))]
            elif not z['top']:
                z['col'] = T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            else:
                z['col'] = T['green'][0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4]
            z['gloss'] = z['top'] and z['lam'] > 0.45 and v > 0.66 and not young
        return out

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
        T = self.T; F = T['ripe'] if ripe else T['raw']
        spots = self._surface_spots(r, n, -0.75, 0.3, -0.1, 0.34 if ripe else 0.42)
        for (p, d, c) in spots:
            ns = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            # the stalk leaves the twig end, arches out a little and hangs; the bunch hangs below it
            Ls = r.uniform(0.1, 0.16)
            s0 = p - ns * 0.02
            s1 = s0 + ns * 0.05 - UP * Ls * 0.4
            s2 = s0 + ns * 0.07 - UP * Ls
            nb = int(r.integers(6, 9)) if ripe else int(r.integers(4, 7))
            Rf = (0.047 if ripe else 0.037) * r.uniform(0.94, 1.06)
            fruits, twigs = [], []
            for b in range(nb):
                # branchlets fan down and out from the stalk end, each holding 2-4 fruits
                az = 2 * math.pi * b / nb + r.normal(0, 0.3)
                hd = np.array([math.cos(az), math.sin(az) * 0.8, 0.0])
                ln = r.uniform(0.04, 0.09) * (1.0 if ripe else 0.8)
                b1 = s2 + hd * ln * 0.6 - UP * ln * 0.5
                b2 = s2 + hd * ln - UP * ln * 1.1
                twigs.append((s2, b1, b2))
                for f in range(int(r.integers(3, 6)) if ripe else int(r.integers(2, 4))):
                    t = r.uniform(0.35, 1.0)
                    q = bez(s2, b1, b1, b2, t) + hd * Rf * 0.6 + r.normal(0, 1, 3) * Rf * 0.35 - UP * Rf * 1.1
                    fruits.append((q, Rf * r.uniform(0.9, 1.08)))
            # thin out fruits sitting inside each other
            kept = []
            for q, rr_ in sorted(fruits, key=lambda z: -z[0][2]):
                if any(np.linalg.norm(q - k[0]) < (rr_ + k[1]) * 0.8 for k in kept): continue
                kept.append((q, rr_))
            assert min(q[2] - rr_ for q, rr_ in kept) > 0.15, 'bunch too low'
            self.items.append((p + TOCAM * 0.35, self._bunch_draw(s0, s1, s2, twigs, kept, F,
                                                                  np.random.default_rng(int(r.integers(1, 1 << 30))))))

    def _bunch_draw(self, s0, s1, s2, twigs, fruits, F, rr):
        T = self.T
        def draw():
            pa = self.pa; P = pa.P; cx = pa.ctx
            def curve(a, b, cc, d, w, col):
                cx.new_path(); cx.move_to(*P(a)); cx.curve_to(*P(b), *P(cc), *P(d))
                cx.set_source_rgb(*col); cx.set_line_width(w); cx.set_line_cap(cairo.LINE_CAP_ROUND); cx.stroke()
            curve(s0, s1, s1, s2, pa.u(0.42), T['stalk'])
            for (a, b, d) in twigs: curve(a, b, b, d, pa.u(0.24), T['stalk'])
            # pedicels: each fruit on a short thread back to its twig
            for q, R in fruits:
                tw = min(twigs, key=lambda z: np.linalg.norm(z[2] - q))
                pa.line([P(tw[1] + (tw[2] - tw[1]) * 0.6), P(q + UP * R * 0.8)], T['stalk_dk'], pa.u(0.16), 0.9)
            for q, R in sorted(fruits, key=lambda z: depth(z[0])):
                x, y = P(q); rad = R * pa.k
                body = [(x + math.cos(a) * rad, y + math.sin(a) * rad * 0.98) for a in np.linspace(0, 2 * math.pi, 28, endpoint=False)]
                pa.fill(body, F['body'])
                cx.save(); pa.path(body); cx.clip()
                # the side away from the sun, then the lit cheek and a small sheen
                cx.new_path(); cx.arc(x + SLIGHT[0] * rad * 0.55, y + SLIGHT[1] * rad * 0.55, rad * 1.05, 0, 2 * math.pi)
                cx.set_source_rgb(*F['dk']); cx.fill()
                cx.new_path(); cx.arc(x - SLIGHT[0] * rad * 0.18, y - SLIGHT[1] * rad * 0.18, rad * 0.78, 0, 2 * math.pi)
                cx.set_source_rgb(*F['body']); cx.fill()
                cx.new_path(); cx.arc(x - SLIGHT[0] * rad * 0.42, y - SLIGHT[1] * rad * 0.42, rad * 0.38, 0, 2 * math.pi)
                cx.set_source_rgb(*F['lit']); cx.fill()
                cx.new_path(); cx.arc(x - SLIGHT[0] * rad * 0.52, y - SLIGHT[1] * rad * 0.56, rad * 0.13, 0, 2 * math.pi)
                cx.set_source_rgba(*F['hi'], 0.85); cx.fill()
                # the fine speckled skin
                for _ in range(5):
                    a = rr.uniform(0, 2 * math.pi); d = rad * rr.uniform(0.2, 0.8)
                    cx.new_path(); cx.arc(x + math.cos(a) * d, y + math.sin(a) * d, rad * 0.07, 0, 2 * math.pi)
                    cx.set_source_rgba(*F['speck'], 0.5); cx.fill()
                cx.restore()
                pa.soft_edge(body, F['body'])
                # the tiny scar where it hangs
                cx.new_path(); cx.arc(x, y - rad * 0.86, rad * 0.14, 0, 2 * math.pi); cx.set_source_rgb(*T['stalk_dk']); cx.fill()
        return draw

    # ------------------------------------------------------------- flower panicles (not ripe)
    def _panicles(self, r, n):
        T = self.T; Pn = T['pan']
        for (p, d, c) in self._surface_spots(r, n, 0.0, 0.92, -0.5, 0.3):
            ns = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            ax = nv(UP + ns * 0.5 + r.normal(0, 0.12, 3))
            L = r.uniform(0.26, 0.36)
            base = p - ax * 0.03
            fl = []
            for t in np.linspace(0.1, 0.95, 11):
                q0 = base + ax * L * t
                for sgn in (1, -1):
                    az = r.uniform(0, 2 * math.pi)
                    sd = nv(np.cross(ax, np.array([math.cos(az), math.sin(az), 0.0])))
                    ln = 0.085 * (1 - t) ** 1.1 + 0.012
                    fl.append((q0, q0 + sd * ln * sgn + ax * ln * 0.45))
            lit = float(ns @ LIGHT)
            def draw(base=base, ax=ax, L=L, fl=fl, lit=lit, rr=np.random.default_rng(int(r.integers(1, 1 << 30)))):
                pa = self.pa; P = pa.P
                pa.line([P(base), P(base + ax * L)], Pn['stalk'], pa.u(0.36))
                for q0, q1 in fl: pa.line([P(q0), P(q1)], Pn['stalk'], pa.u(0.22), 0.9)
                dots = []
                for q0, q1 in fl:
                    for j in range(4):
                        dots.append(q0 + (q1 - q0) * rr.uniform(0.35, 1.0) + rr.normal(0, 0.008, 3))
                dots.append(base + ax * L * 1.02)
                dots.sort(key=depth)
                mid = np.array(P(base + ax * L * 0.5))
                for q in dots:
                    x, y = P(q)
                    s = -((x - mid[0]) * SLIGHT[0] + (y - mid[1]) * SLIGHT[1]) / (pa.k * 0.08 + 1e-6)
                    k = 2 if s < -0.4 else 1 if s < 0.5 else 0
                    if lit < -0.2: k = min(2, k + 1)
                    pa.ctx.new_path(); pa.ctx.arc(x, y, pa.u(0.34), 0, 2 * math.pi); pa.ctx.set_source_rgb(*Pn['fl'][2 - k]); pa.ctx.fill()
            self.items.append((p + TOCAM * 0.2, draw))


# key "sr": s = shape, r = ripe (the game picks ((t>>1)&1, t&1))
FRAMES = [dict(key='00', shape=0, ripe=0), dict(key='01', shape=0, ripe=1), dict(key='10', shape=1, ripe=0), dict(key='11', shape=1, ripe=1)]
BB = (-62, -95, 62, 25)
FLUSH = False


def render(fr, night=False, bb=BB):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    Nhan(fr['shape'], fr['ripe'], pa).paint()
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
    path = os.path.join(outdir, 'k2_nhan.webp')
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
        sheet.save('/tmp/claude-0/g/nhan_%s.png' % tag); print(sheet.size)
