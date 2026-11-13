# Rambutan trees (cây chôm chôm) for Nông Trại Nhỏ, drawn from the real tree as small 3D models and painted in flat game
# tones with the thin same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun and night.
# Two shapes, each unripe (0) or ripe (1), like the game's other "k2" fruit trees:
#   shape 0: a miền Tây orchard tree, pruned low: a short trunk that splits near the ground into four limbs and a broad,
#            dense dome whose skirt hangs low;
#   shape 1: an older, taller tree with a clear grey trunk and a high oval crown.
# The crown is the clump crown of the mango and longan kits (no dark lining, thin spots stay open). Rambutan leaves are
# compound like longan but bigger: each twig end holds a few leaves of 2-4 pairs of broad, glossy, blunt leaflets.
# The fruit is what tells the tree: loose bunches of oval fruits covered in soft hairs (râu) hanging off the twig ends all
# over the outside of the crown. Ripe: red fruit, red hairs, a few hair tips still yellow-green. Not ripe: yellow-green
# fruit with green hairs, a few just turning.
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
        green=[C('#1e4a22'), C('#275e2b'), C('#317033'), C('#40833c'), C('#56994a')],
        und=[C('#486c3a'), C('#577e44'), C('#6a9150')],
        young=[C('#5f6a2a'), C('#77812f'), C('#8f973a'), C('#a6aa4a'), C('#bbbd5e')],
        inner=C('#173f20'), deep=[C('#1c4723'), C('#235229'), C('#2b5e30')],
        bark=dict(lit=C('#a39888'), mid=C('#7a6f62'), dk=C('#564c43'), fis=C('#4b423a')),
        ripe=dict(body=C('#cf2a24'), lit=C('#ea4a36'), dk=C('#931a1e'), hi=C('#ff9c86'),
                  hair=C('#c4221f'), hair_lit=C('#f0664a'), hair_dk=C('#86161b'), tip=C('#b9c84a')),
        raw=dict(body=C('#9cba3e'), lit=C('#bad65e'), dk=C('#6c8a2a'), hi=C('#e4f2a6'),
                 hair=C('#8fae36'), hair_lit=C('#c2da62'), hair_dk=C('#5f7c26'), tip=C('#d9df72')),
        turn=dict(body=C('#d9a634'), lit=C('#efc458'), dk=C('#a8761e'), hi=C('#fbe6a4'),
                  hair=C('#cf8f2c'), hair_lit=C('#f0b84e'), hair_dk=C('#9a6418'), tip=C('#c9cf56')),
        stalk=C('#6a5c34'), stalk_dk=C('#4e4328'),
    )


class Chom(Mit):
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
            self.ce = np.array([0.0, -0.06, 1.42]); self.ra = 1.26; self.ry = 1.1; self.rb = 0.8
        else:
            self.ce = np.array([0.0, -0.06, 1.84]); self.ra = 1.2; self.ry = 1.06; self.rb = 0.86
        self._clumps(r)
        self._trunk(r)
        for c in self.cl: self._clump_leaves(r, c)
        rf = np.random.default_rng(shape * 977 + ripe * 31 + 11)
        self._bunches(rf, (13 if shape == 0 else 12) if ripe else (11 if shape == 0 else 10), ripe)

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
            # broad orchard dome: a full low skirt (front slot open for the trunk), a middle ring, a round top
            ring(7, 0.64, -0.4, 0.5, 0.56, 0.64, 0, True)
            ring(4, 0.36, 0.1, 0.54, 0.6, 0.66, 1, False)
            ring(2, 0.1, 0.5, 0.5, 0.54, 0.7, 2, False)
        else:
            # a taller tree: a high oval crown, a lower ring that leaves the trunk in view, a middle, a top
            ring(6, 0.6, -0.38, 0.5, 0.56, 0.7, 0, True)
            ring(4, 0.34, 0.08, 0.54, 0.58, 0.72, 1, False)
            ring(2, 0.1, 0.5, 0.5, 0.54, 0.76, 2, False)
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
        return (0.15 if self.shape == 0 else 0.135) - 0.02 * z + 0.07 * math.exp(-max(0.0, z) / 0.11)

    def _trunk(self, r):
        self.lean = [-0.02, 0.025][self.shape]
        self.limbs = []; self.leaders = []
        low = [c for c in self.cl if c['tier'] == 0]
        mid = [c for c in self.cl if c['tier'] == 1]
        top = [c for c in self.cl if c['tier'] == 2]
        zf = 0.4 if self.shape == 0 else 0.98
        zs = np.linspace(-0.04, zf + 0.04, 14)
        # the trunk narrows into the fork, so its top never shows as a flat cut between the leaders
        tr = [self.trad(z) * (1 - 0.32 * max(0.0, (z - zf * 0.7) / (zf * 0.3 + 0.04)) ** 1.5) for z in zs]
        self._tube([self.axis(z) for z in zs], tr, np.array([0, 0, 0.5]), fiss=4, r=r)
        f0 = self.axis(zf); self.fork = f0
        self.tc = np.array([0.0, 0.0]); self.tR = self.trad(0.2)
        # three leaders out of the fork: left, right and one leaning back, all turning up into the crown
        if self.shape == 0:
            heads = [np.array([-0.7, 0.14, self.ce[2] - 0.05]), np.array([0.68, 0.06, self.ce[2]]),
                     np.array([0.26, -0.48, self.ce[2] + 0.14])]
            w0 = 0.1
        else:
            heads = [np.array([-0.52, 0.08, self.ce[2] + 0.02]), np.array([0.54, 0.0, self.ce[2] + 0.06]),
                     np.array([-0.2, -0.36, self.ce[2] + 0.24])]
            w0 = 0.085
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
            Lr = 0.21 * r.uniform(0.85, 1.1) * (0.8 if young else 1.0)
            pt = p + (r.normal(0, 1, 3) * np.array([1, 1, 0.5])) * 0.02
            npair = int(r.choice([2, 2, 3, 3, 4]))
            for j in range(npair):
                t = 0.28 + 0.72 * (j + 0.5) / npair
                q0 = pt + rd * Lr * t - UP * Lr * 0.12 * t * t
                for sg in (1, -1):
                    # leaflets angle forward along the rachis; the last pair is the longest
                    fw = r.uniform(0.2, 0.5) + 0.2 * j / max(1, npair - 1)
                    ld = nv(sd0 * sg * math.cos(fw) + rd * math.sin(fw) - UP * r.uniform(0.05, 0.3) + nrm0 * r.normal(0, 0.22))
                    sd = nv(np.cross(nrm0, ld))
                    Ll = (0.125 + 0.035 * j / max(1, npair - 1)) * r.uniform(0.88, 1.12); Wl = Ll * r.uniform(0.42, 0.48)
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
        T = self.T
        spots = self._surface_spots(r, n, -0.8, 0.45, -0.15, 0.4)
        for (p, d, c) in spots:
            ns = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            # the bunch stalk leaves the twig end, arches out and droops under the weight of the fruit
            Ls = r.uniform(0.08, 0.14)
            s0 = p - ns * 0.03
            s1 = s0 + ns * 0.06 - UP * Ls * 0.3
            s2 = s0 + ns * 0.09 - UP * Ls
            nb = int(r.integers(5, 8))
            Rf = (0.06 if ripe else 0.054) * r.uniform(0.94, 1.06)
            F = T['ripe'] if ripe else (T['turn'] if r.random() < 0.14 else T['raw'])
            fruits, twigs = [], []
            for b in range(nb):
                # branchlets fan out and down from the stalk end, each holding one to three fruits
                az = 2 * math.pi * b / nb + r.normal(0, 0.35)
                hd = np.array([math.cos(az), math.sin(az) * 0.8, 0.0])
                ln = r.uniform(0.06, 0.13)
                b1 = s2 + hd * ln * 0.6 - UP * ln * 0.4
                b2 = s2 + hd * ln - UP * ln * 1.0
                twigs.append((s2, b1, b2))
                for f in range(int(r.integers(2, 4))):
                    t = r.uniform(0.4, 1.0)
                    q = bez(s2, b1, b1, b2, t) + hd * Rf * 0.5 + r.normal(0, 1, 3) * Rf * 0.3 - UP * Rf * 1.25
                    # each fruit hangs from its top: the long axis points down, tipped out a little
                    ax = nv(-UP + hd * r.uniform(0.2, 0.6) + r.normal(0, 0.15, 3))
                    fruits.append((q, Rf * r.uniform(0.9, 1.08), ax))
            kept = []
            for q, rr_, ax in sorted(fruits, key=lambda z: -z[0][2]):
                if any(np.linalg.norm(q - k[0]) < (rr_ + k[1]) * 0.92 for k in kept): continue
                kept.append((q, rr_, ax))
            assert min(q[2] - rr_ * 1.2 for q, rr_, ax in kept) > 0.12, 'bunch too low'
            self.items.append((p + TOCAM * 0.35, self._bunch_draw(s0, s1, s2, twigs, kept, F,
                                                                  np.random.default_rng(int(r.integers(1, 1 << 30))))))

    def _bunch_draw(self, s0, s1, s2, twigs, fruits, F, rr):
        T = self.T
        # the hairs of every fruit, picked once: (kind, angle, reach, curl, yellow-green tip)
        hairs = []
        for _ in fruits:
            hs = [('o', 2 * math.pi * k / 24 + rr.normal(0, 0.07), rr.uniform(0.28, 0.4), rr.uniform(-0.7, 0.7), rr.random() < 0.2)
                  for k in range(24)]
            hs += [('b', rr.uniform(0, 2 * math.pi), rr.uniform(0.12, 0.78), rr.uniform(-0.7, 0.7), False)
                   for k in range(14)]
            hairs.append(hs)

        def draw():
            pa = self.pa; P = pa.P; cx = pa.ctx
            def curve(a, b, cc, d, w, col):
                cx.new_path(); cx.move_to(*P(a)); cx.curve_to(*P(b), *P(cc), *P(d))
                cx.set_source_rgb(*col); cx.set_line_width(w); cx.set_line_cap(cairo.LINE_CAP_ROUND); cx.stroke()
            curve(s0, s1, s1, s2, pa.u(0.46), T['stalk'])
            for (a, b, d) in twigs: curve(a, b, b, d, pa.u(0.28), T['stalk'])
            for q, R, ax in fruits:
                tw = min(twigs, key=lambda z: np.linalg.norm(z[2] - q))
                pa.line([P(tw[1] + (tw[2] - tw[1]) * 0.6), P(q - ax * R * 0.9)], T['stalk_dk'], pa.u(0.2), 0.9)
            cx.set_line_cap(cairo.LINE_CAP_ROUND)
            for i in sorted(range(len(fruits)), key=lambda i: depth(fruits[i][0])):
                q, R, ax = fruits[i]
                x, y = P(q); rad = R * pa.k
                e2 = np.array(P(q + ax * R)) - np.array([x, y])
                fore = min(1.0, np.linalg.norm(e2) / rad)
                ang = math.atan2(e2[1], e2[0])
                A, B = rad * (1 + 0.17 * fore), rad
                ca, sa = math.cos(ang), math.sin(ang)
                def at(t, s=1.0):
                    u, v = math.cos(t) * A * s, math.sin(t) * B * s
                    return (x + u * ca - v * sa, y + u * sa + v * ca)
                body = [at(t) for t in np.linspace(0, 2 * math.pi, 30, endpoint=False)]
                pa.fill(body, F['body'])
                cx.save(); pa.path(body); cx.clip()
                cx.new_path(); cx.arc(x + SLIGHT[0] * rad * 0.55, y + SLIGHT[1] * rad * 0.55, rad * 1.08, 0, 2 * math.pi)
                cx.set_source_rgb(*F['dk']); cx.fill()
                cx.new_path(); cx.arc(x - SLIGHT[0] * rad * 0.18, y - SLIGHT[1] * rad * 0.18, rad * 0.8, 0, 2 * math.pi)
                cx.set_source_rgb(*F['body']); cx.fill()
                cx.new_path(); cx.arc(x - SLIGHT[0] * rad * 0.42, y - SLIGHT[1] * rad * 0.42, rad * 0.4, 0, 2 * math.pi)
                cx.set_source_rgb(*F['lit']); cx.fill()
                cx.new_path(); cx.arc(x - SLIGHT[0] * rad * 0.5, y - SLIGHT[1] * rad * 0.54, rad * 0.14, 0, 2 * math.pi)
                cx.set_source_rgba(*F['hi'], 0.7); cx.fill()
                cx.restore()
                pa.soft_edge(body, F['body'])
                # the soft hairs: short curled strokes over the skin, longer ones standing out round the rim
                for (kind, a, reach, curl, tip) in hairs[i]:
                    if kind == 'b':
                        p0 = np.array(at(a, reach)); out = p0 - np.array([x, y]); ln = rad * 0.3
                    else:
                        p0 = np.array(at(a, 0.86)); out = p0 - np.array([x, y]); ln = rad * reach
                    on = np.linalg.norm(out)
                    out = out / on if on > 1e-6 else np.array([0.0, -1.0])
                    side = -(out[0] * SLIGHT[0] + out[1] * SLIGHT[1])
                    col = F['hair_lit'] if side > 0.35 else F['hair_dk'] if side < -0.45 else F['hair']
                    pr = np.array([-out[1], out[0]])
                    p1 = p0 + out * ln * 0.55 + pr * ln * 0.2 * curl
                    p2 = p0 + out * ln + pr * ln * 0.55 * curl
                    w = pa.u(0.3 if kind == 'o' else 0.26)
                    cx.new_path(); cx.move_to(*p0); cx.curve_to(*p1, *p1, *p2)
                    cx.set_source_rgb(*col); cx.set_line_width(w); cx.stroke()
                    if tip:
                        pt = p0 + out * ln * 0.78 + pr * ln * 0.4 * curl
                        cx.new_path(); cx.move_to(*pt); cx.line_to(*p2)
                        cx.set_source_rgb(*mixc(F['tip'], col, 0.35)); cx.set_line_width(w * 0.8); cx.stroke()
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
    Chom(fr['shape'], fr['ripe'], pa).paint()
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
    path = os.path.join(outdir, 'k2_chomchom.webp')
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
        sheet.save('/tmp/claude-0/g/chom_%s.png' % tag); print(sheet.size)
