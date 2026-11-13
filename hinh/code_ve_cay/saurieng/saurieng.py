# Durian trees (cây sầu riêng) for Nông Trại Nhỏ, drawn from the real miền Tây orchard tree as small 3D models and
# painted in flat game tones with the thin same-colour edge of the other new plants (ch.SOFT), with the banana kit's
# camera, sun and night (../chuoi). Two shapes, each unripe (0) or ripe (1), like the game's other "k2" fruit trees:
#   shape 0: an orchard tree in its prime: one straight trunk running up through the middle, branches nearly level
#            all the way down to knee height, a dense crown shaped like a tall egg;
#   shape 1: an old tall tree: a clear grey-brown trunk, then the crown in loose tiers of level branches with gaps
#            between them where the branches and the fruit show.
# The crown is the clump crown of the mango, longan and tamarind kits (no dark lining, thin spots stay open). Durian
# leaves are oblong with a drawn-out tip, dark glossy green on top and olive-gold underneath; they hang in flat sprays.
# The fruit grows on the big branches themselves, not at the twig ends: heavy spiny ovals on short thick stalks, hanging
# under the level limbs close in to the trunk. Ripe: big olive-gold fruit with brown spine tips. Not ripe: smaller
# fresh green fruit, and bunches of cream flowers hanging under the branches.
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
        green=[C('#1b4824'), C('#235a2a'), C('#2d6d31'), C('#3c823b'), C('#51984a')],
        und=[C('#566e36'), C('#69813f'), C('#7e944b')],
        young=[C('#5f6a2a'), C('#77812f'), C('#8f973a'), C('#a6aa4a'), C('#bbbd5e')],
        inner=C('#173f20'), deep=[C('#1c4723'), C('#235229'), C('#2b5e30')],
        bark=dict(lit=C('#958271'), mid=C('#6e5d4e'), dk=C('#4d4137'), fis=C('#3e342c')),
        ripe=dict(body=C('#a3a243'), lit=C('#c2bd5e'), dk=C('#72772e'), hi=C('#e2dc94'), tip=C('#6c5629'),
                  sp_lit=C('#d6cf78'), sp_dk=C('#535a21')),
        raw=dict(body=C('#8db544'), lit=C('#abcc62'), dk=C('#62862e'), hi=C('#dceca0'), tip=C('#5a7a2a'),
                 sp_lit=C('#c3dc84'), sp_dk=C('#4f7026')),
        stalk=C('#6a5a3a'), stalk_dk=C('#4a3f29'),
        fl=[C('#f4eed6'), C('#e2d8b4'), C('#c9bb8c')], fl_c=C('#d9c76a'),
    )


class SauRieng(Mit):
    """shape 0 or 1, ripe 0 or 1"""
    NROS = 165          # twig ends on a clump of radius 0.9 (scaled by area); each holds a spray of leaves

    def __init__(self, shape, ripe, pa):
        self.pa = pa; self.seed = shape * 2 + ripe
        self.shape = shape; self.ripe = ripe
        r = self.rng = np.random.default_rng(shape * 7177 + 29)
        self.items = []
        self.T = tones()
        self.flush = []
        if shape == 0:
            self.ce = np.array([0.0, -0.04, 1.95]); self.ra = 1.2; self.ry = 1.06; self.rb = 1.1
        else:
            self.ce = np.array([0.0, -0.06, 2.3]); self.ra = 1.26; self.ry = 1.1; self.rb = 1.0
        self._clumps(r)
        self._trunk(r)
        for c in self.cl: self._clump_leaves(r, c)
        rf = np.random.default_rng(shape * 977 + ripe * 31 + 23)
        if ripe:
            self._fruits(rf, 10 if shape == 0 else 11, True)
        else:
            self._fruits(rf, 7 if shape == 0 else 8, False)
            self._flowers(rf, 7 if shape == 0 else 8)

    # ------------------------------------------------------------- crown layout
    def _clumps(self, r):
        ra, ry = self.ra, self.ry
        cl = []
        def ring(n, rad, z, rc0, rc1, flat, tier, notch):
            m = n + 1 if notch else n
            # the upper rings always have a clump straight in front, so the leader never shows up the face of the crown
            az0 = math.pi / 2 + (2 * math.pi / m if notch else r.normal(0, 0.12))
            for k in range(n):
                az = az0 + k * 2 * math.pi / m + r.normal(0, 0.08)
                d = rad * r.uniform(0.94, 1.05)
                c = np.array([math.cos(az) * ra * d, self.ce[1] + math.sin(az) * ry * d, z + r.normal(0, 0.03)])
                rc = r.uniform(rc0, rc1)
                cl.append(dict(c=c, rc=rc, rz=rc * flat, tier=tier, az=az))
        if self.shape == 0:
            # a tall egg: level branches all the way down, each tier a little narrower than the one under it
            ring(7, 0.7, 0.98, 0.46, 0.52, 0.56, 0, True)
            ring(6, 0.56, 1.55, 0.46, 0.52, 0.6, 1, False)
            ring(5, 0.4, 2.12, 0.44, 0.49, 0.62, 2, False)
            ring(3, 0.22, 2.65, 0.4, 0.44, 0.66, 3, False)
            ring(2, 0.12, 3.04, 0.36, 0.4, 0.7, 4, False)
        else:
            # an old tall tree: the crown starts high, in loose tiers with gaps between them
            ring(6, 0.78, 1.36, 0.47, 0.54, 0.46, 0, True)
            ring(5, 0.58, 2.22, 0.44, 0.5, 0.5, 1, False)
            ring(4, 0.36, 2.98, 0.4, 0.45, 0.54, 2, False)
            ring(2, 0.12, 3.46, 0.38, 0.42, 0.66, 3, False)
        for c in cl:
            c['lumps'] = [(nv(r.normal(0, 1, 3)), r.uniform(1.4, 2.4), r.uniform(0, 6.28), r.uniform(0.05, 0.08)) for _ in range(4)]
            c['tv'] = r.uniform(-0.03, 0.03)
        self.cl = cl

    # ------------------------------------------------------------- wood
    def axis(self, z):
        return np.array([0.02 * math.sin(z * 1.7) + self.lean * z * z, 0.01 * math.sin(z * 2.3), z])

    def trad(self, z):
        b = 0.12 if self.shape == 0 else 0.15
        return max(0.035, b * (1 - 0.2 * z) + 0.06 * math.exp(-max(0.0, z) / 0.1))

    def _fade_in(self, a, b):
        """the last drawn item fades in from a (clear) to b (solid), along the screen line between them"""
        key, draw = self.items[-1]; pa = self.pa
        def fd():
            ctx = pa.ctx; ctx.push_group(); draw(); ctx.pop_group_to_source()
            A, Bp = pa.P(a), pa.P(b)
            g = cairo.LinearGradient(A[0], A[1], Bp[0], Bp[1])
            g.add_color_stop_rgba(0, 0, 0, 0, 0); g.add_color_stop_rgba(1, 0, 0, 0, 1)
            ctx.mask(g)
        self.items[-1] = (key, fd)

    def _trunk(self, r):
        self.lean = [0.006, -0.01][self.shape]
        self.limbs = []
        zt = max(c['c'][2] for c in self.cl) - 0.1
        # one straight leader up through the crown, in a few pieces so each sorts at its own height
        # inside the crown it sorts a little behind the middle, so the clumps in front always cover it
        z0 = min(c['c'][2] for c in self.cl)
        cuts = np.linspace(-0.04, zt, 5)
        for a, b in zip(cuts[:-1], cuts[1:]):
            zs = np.linspace(a, b, 8)
            key = self.axis((a + b) / 2) * np.array([1, 0, 1]) - TOCAM * (0.0 if a < z0 - 0.2 else 0.35)
            self._tube([self.axis(z) for z in zs], [self.trad(z) for z in zs], key, fiss=4 if a < 0.5 else 2, r=r)
        self.fork = self.axis(0.6)
        self.tc = np.array([0.0, 0.0]); self.tR = self.trad(0.2)
        # level branches out of the leader, one to each clump, the outer end dipping a little under the leaves
        for c in self.cl:
            if c['tier'] == max(cc['tier'] for cc in self.cl) and np.linalg.norm(c['c'][:2]) < 0.1: continue
            zb = c['c'][2] - c['rz'] * 0.35 - 0.06
            b0 = self.axis(zb)
            Tp = c['c'] - UP * c['rz'] * 0.25
            hz = np.array([Tp[0] - b0[0], Tp[1] - b0[1], 0.0])
            w0 = self.trad(zb) * (0.6 if c['tier'] == 0 else 0.5)
            p1 = b0 + hz * 0.4 + UP * 0.03
            p2 = b0 + hz * 0.78 + UP * (Tp[2] - b0[2]) * 0.4
            lp = [bez(b0, p1, p2, Tp, t) for t in np.linspace(0, 1, 14)]
            lr = [w0 * (1 - 0.55 * t) for t in np.linspace(0, 1, 14)]
            key = (b0 + Tp) / 2 - TOCAM * (0.35 if c['tier'] == 0 else 0.5)
            self._tube(lp, lr, key, fiss=1, r=r)
            # the branch grows out of the bark: it fades in across the leader so no flat end shows on the trunk
            dh = nv(hz)
            self._fade_in(b0 + dh * self.trad(zb) * 0.2, b0 + dh * self.trad(zb) * 1.1)
            self.limbs.append(dict(lp=lp, lr=lr, c=c))

    # ------------------------------------------------------------- leaves
    def _cluster(self, r, c, p, ns, hc, G, dark=False):
        """a twig end with a flat spray of 5-7 oblong leaves with drawn-out tips, hanging down the slope of the crown"""
        T = self.T
        nrm0 = nv(ns + UP * 0.6)
        t1 = np.cross(nrm0, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(nrm0, t1)
        sun = float(ns @ LIGHT)
        ao = 0.72 + 0.3 * max(-1.0, min(1.0, hc)) + 0.1 * max(-1.2, min(1.2, G))
        nl = int(r.integers(5, 8))
        dn = -UP - (-UP @ nrm0) * nrm0
        down = nv(dn) if np.linalg.norm(dn) > 0.25 else None
        az0 = r.uniform(0, 2 * math.pi)
        leaves = []
        flat_top = down is None
        # a spray on top of a clump sits down on the dome, never above it (a lump can push a spot up off the crown)
        ztop = c['c'][2] + c['rz'] * 0.95
        if p[2] > ztop: p = np.array([p[0], p[1], ztop])
        if flat_top: p = p - UP * 0.03
        for k in range(nl):
            if down is not None:
                a = r.uniform(-1.4, 1.4)
                A = nv(down * math.cos(a) + nv(np.cross(nrm0, down)) * math.sin(a))
            else:
                az = az0 + k * 2 * math.pi / nl + r.normal(0, 0.5)
                A = math.cos(az) * t1 + math.sin(az) * t2
            el = r.uniform(-0.15, 0.2)
            ld = nv(A * math.cos(el) + nrm0 * math.sin(el) - UP * (0.5 if flat_top else 0.22) + r.normal(0, 0.1, 3))
            sd = nv(np.cross(nrm0, ld) + r.normal(0, 0.15, 3))
            Ll = 0.17 * r.uniform(0.85, 1.15); Wl = Ll * r.uniform(0.32, 0.38)
            pt = p + (r.normal(0, 1, 3) * np.array([1, 1, 0.5])) * 0.024 + ld * 0.012
            # oblong, the sides nearly parallel, narrowing to a drawn-out pointed tip
            prof = [(0.0, 0.1), (0.07, 0.5), (0.18, 0.82), (0.32, 0.97), (0.48, 1.0), (0.62, 0.93), (0.75, 0.74),
                    (0.86, 0.46), (0.94, 0.2), (1.0, 0.0)]
            Lp_, Rp_ = [], []
            for (t, w) in prof:
                q = pt + ld * Ll * t - UP * Ll * 0.14 * t * t
                Lp_.append(q + sd * Wl * 0.5 * w); Rp_.append(q - sd * Wl * 0.5 * w)
            nn = nv(np.cross(ld, sd))
            if nn @ nrm0 < 0: nn = -nn
            topv = nn @ TOCAM > 0
            lam = float((nn if topv else -nn) @ LIGHT)
            v = (0.62 + 0.3 * max(-0.3, lam)) * ao + 0.2 * sun - 0.06
            leaves.append(dict(poly=Lp_ + Rp_[::-1], top=topv, v=v, lam=lam, mid=pt + ld * Ll * 0.5,
                               rib=(pt, pt + ld * Ll * 0.88 - UP * Ll * 0.1)))
        vm = float(np.mean([z['v'] for z in leaves]))
        for z in leaves:
            v = 0.6 * vm + 0.4 * z['v'] + c['tv']
            if not z['top']:
                z['col'] = T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            else:
                z['col'] = T['green'][0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4]
            z['gloss'] = z['top'] and z['lam'] > 0.35 and v > 0.6
        return leaves

    # ------------------------------------------------------------- where fruit and flowers hang
    def _hang_spots(self, r, n, gap, zmin):
        """points under the level branches, from a third of the way out to near the leaves, on the camera's side"""
        cand = []
        for L in self.limbs:
            c = L['c']
            if c['tier'] > (0 if self.shape == 0 else 1): continue
            if c['c'][1] - self.ce[1] < -0.25 * self.ry: continue
            for _ in range(8):
                t = r.uniform(0.3, 0.72)
                i = t * (len(L['lp']) - 1); i0 = int(i); f = i - i0
                q = L['lp'][i0] * (1 - f) + L['lp'][min(i0 + 1, len(L['lp']) - 1)] * f
                w = L['lr'][i0]
                if q[2] < zmin: continue
                cand.append((q - UP * w * 0.7, w, c))
        r.shuffle(cand)
        picked, out = [], []
        for q, w, c in cand:
            sp = np.array(self.pa.P(q)) / self.pa.k
            if any(np.linalg.norm(sp - s) < gap for s in picked): continue
            picked.append(sp); out.append((q, w, c))
            if len(out) >= n: break
        return out

    def _surface_spots(self, r, n, zlo, zhi, front, gap, tiers=(0, 1)):
        """points on the lower outside of the crown, spread out on screen, on the side facing the camera"""
        spots = []
        for c in self.cl:
            if c['tier'] not in tiers: continue
            for _ in range(60):
                a = r.uniform(0, 2 * math.pi); zz = r.uniform(zlo, zhi); rr = math.sqrt(max(0.0, 1 - zz * zz))
                d = np.array([rr * math.cos(a), rr * math.sin(a), zz])
                if d[1] < front: continue
                p = self.env(c, d, 0.9)
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

    # ------------------------------------------------------------- fruit
    def _fruits(self, r, n, ripe):
        T = self.T; F = T['ripe'] if ripe else T['raw']
        R0 = 0.142 if ripe else 0.098
        gap = 0.48 if ripe else 0.4
        # a few under the front branches below the skirt of the crown, the rest on the big branches just inside the
        # outer leaves of the lower crown, where they show
        hang = [h for h in self._hang_spots(r, 8, gap, 0.5) if h[2]['c'][1] - self.ce[1] > 0.25 * self.ry][:3]
        hang = [(q, w, c, None) for (q, w, c) in hang]
        tiers = (0, 1, 2)
        for (p, d, c) in self._surface_spots(r, n + 4, -0.75, 0.05, 0.15, gap, tiers):
            if len(hang) >= n: break
            sp = np.array(self.pa.P(p)) / self.pa.k
            if any(np.linalg.norm(sp - np.array(self.pa.P(h[0])) / self.pa.k) < gap for h in hang): continue
            ns = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            hang.append((p + ns * 0.02, 0.02, c, ns))
        self.fruit_at = []
        for (q, w, c, ns) in hang:
            R = R0 * r.uniform(0.9, 1.08)
            Hh = R * r.uniform(1.2, 1.34)                  # half height: an oval hanging point down
            Ls = r.uniform(0.04, 0.07)
            top = q - UP * Ls
            cen = top - UP * Hh * 0.92
            if cen[2] - Hh < 0.12: continue
            tilt = r.normal(0, 0.12)
            self.fruit_at.append(np.array(self.pa.P(cen)) / self.pa.k)
            self.items.append((cen + TOCAM * 0.3, self._fruit_draw(q, top, cen, R, Hh, tilt, F,
                                                                  np.random.default_rng(int(r.integers(1, 1 << 30))))))

    def _fruit_draw(self, s0, top, cen, R, Hh, tilt, F, rr):
        T = self.T
        nsp = int(rr.integers(14, 17))
        ph = rr.uniform(0, 6.28)
        studs = []
        # the spines on the face: staggered rows inside the outline (u across, v down), each a little cone
        rows = 5
        for i in range(rows):
            v = -0.72 + 1.44 * i / (rows - 1)
            m = int(round(2 + 2.0 * math.sqrt(max(0.0, 1 - v * v))))
            for j in range(m):
                u = ((j + 0.5 * (i % 2)) / max(1, m - 0.5)) * 2 - 1 + rr.uniform(-0.06, 0.06)
                u *= math.sqrt(max(0.0, 1 - v * v)) * 0.78
                studs.append((u, v + rr.uniform(-0.04, 0.04)))
        def draw():
            pa = self.pa; P = pa.P; cx = pa.ctx; k = pa.k
            # the thick woody stalk off the branch
            pa.line([P(s0), P(top)], T['stalk'], max(pa.u(0.7), R * k * 0.2))
            c2 = np.array(P(cen)); t2 = np.array(P(cen + UP * Hh))
            Hs = np.linalg.norm(t2 - c2); Ws = R * k
            axv = np.array([math.sin(tilt), 1.0]); axv = axv / np.linalg.norm(axv); sx = np.array([axv[1], -axv[0]])
            ang = math.atan2(axv[1], axv[0])
            def pt(u, v): return c2 + sx * Ws * u + axv * Hs * v
            # outline: an oval a little fuller below the middle, its edge cut into short spines
            body, smooth = [], []
            nn = nsp * 4
            for i in range(nn):
                th = 2 * math.pi * i / nn
                yy = -math.cos(th); s_ = math.sin(th)
                w = s_ * (1 + 0.05 * yy) * (1 + 0.03 * math.sin(3 * th + ph))
                smooth.append(tuple(pt(w, yy)))
                fr = (i % 4) / 4.0
                spike = 1 + 0.15 * (1 - abs(fr - 0.5) * 2) - 0.03
                body.append(tuple(pt(w * spike, yy * (1 + (spike - 1) * 0.8))))
            pa.fill(body, F['body'])
            cx.save(); pa.path(smooth); cx.clip()
            sg = 1 if sx @ SLIGHT > 0 else -1
            cx.new_path(); pa.path(smooth); cx.set_source_rgb(*F['dk']); cx.fill()
            cx.save(); cx.translate(*(c2 - SLIGHT * Ws * 0.18 - axv * Hs * 0.06)); cx.rotate(ang)
            cx.scale(Hs * 0.9, Ws * 0.88); cx.new_path(); cx.arc(0, 0, 1, 0, 2 * math.pi); cx.restore()
            cx.set_source_rgb(*F['body']); cx.fill()
            cx.save(); cx.translate(*(c2 - SLIGHT * Ws * 0.34 - axv * Hs * 0.16)); cx.rotate(ang)
            cx.scale(Hs * 0.45, Ws * 0.42); cx.new_path(); cx.arc(0, 0, 1, 0, 2 * math.pi); cx.restore()
            cx.set_source_rgb(*F['lit']); cx.fill()
            # the spines: each a small cone pointing out of the face, its sunny side light and its far side dark,
            # a dark notch under it and a brown tip
            s = Ws * 0.17
            for (u, v) in studs:
                q = pt(u, v)
                lit = float((q - c2) @ np.array(SLIGHT)) / (Ws + 1e-6)     # > 0 on the shade side
                out = sx * u * 0.55 - axv * (0.55 - 0.25 * v)               # the tip leans out from the middle and up
                out = out / (np.linalg.norm(out) + 1e-9)
                tip = q + out * s * 1.05
                side = np.array([-out[1], out[0]]) * s * 0.62
                b1, b2 = q + side, q - side
                cx.new_path(); cx.move_to(*(q - out * s * 0.25 + side * 0.9)); cx.line_to(*(q - out * s * 0.25 - side * 0.9))
                cx.line_to(*(q - out * s * 0.55)); cx.close_path(); cx.set_source_rgba(*F['dk'], 0.7); cx.fill()
                l1, l2 = (b1, b2) if (side @ np.array(SLIGHT)) < 0 else (b2, b1)     # l1 is the sunny side
                cx.new_path(); cx.move_to(*tip); cx.line_to(*l1); cx.line_to(*q); cx.close_path()
                cx.set_source_rgba(*F['sp_lit'], 0.95 if lit < 0.2 else 0.7); cx.fill()
                cx.new_path(); cx.move_to(*tip); cx.line_to(*q); cx.line_to(*l2); cx.close_path()
                cx.set_source_rgba(*F['sp_dk'], 0.75 if lit < 0.2 else 0.9); cx.fill()
                cx.new_path(); cx.arc(tip[0], tip[1], max(pa.u(0.12), s * 0.16), 0, 2 * math.pi)
                cx.set_source_rgb(*F['tip']); cx.fill()
            cx.restore()
            pa.soft_edge(body, F['body'])
            # the stalk's end where it meets the fruit
            cx.new_path(); cx.arc(*P(top), max(pa.u(0.45), R * k * 0.14), 0, 2 * math.pi)
            cx.set_source_rgb(*T['stalk_dk']); cx.fill()
        return draw

    def _flowers(self, r, n):
        """bunches of cream flowers hanging on long stalks under the branches"""
        T = self.T
        spots = self._hang_spots(np.random.default_rng(int(r.integers(1, 1 << 30))), n + 4, 0.32, 0.45)
        far = [s for s in spots if all(np.linalg.norm(np.array(self.pa.P(s[0])) / self.pa.k - f) > 0.3 for f in self.fruit_at)]
        if len(far) < n:
            for (p, d, c) in self._surface_spots(r, n - len(far), -0.8, -0.2, 0.0, 0.4):
                far.append((p, 0.02, c))
        for (q, w, c) in far[:n]:
            fl = []
            for k in range(int(r.integers(8, 13))):
                a = r.uniform(0, 2 * math.pi); L = r.uniform(0.06, 0.14)
                tip = q + np.array([math.cos(a), math.sin(a), 0.0]) * r.uniform(0.02, 0.06) - UP * L
                fl.append((tip, r.uniform(0.85, 1.15), r.uniform(0, 6.28)))
            def draw(q=q, fl=fl):
                pa = self.pa; P = pa.P; cx = pa.ctx
                for (tip, s, ph) in sorted(fl, key=lambda z: depth(z[0])):
                    pa.line([P(q), P(tip + UP * 0.02)], T['stalk'], pa.u(0.22), 0.9)
                    x, y = P(tip); R = 0.032 * pa.k * s
                    # a cup of five cream petals round a tuft of stamens
                    cx.new_path(); cx.arc(x, y, R, 0, 2 * math.pi); cx.set_source_rgb(*T['fl'][1]); cx.fill()
                    cx.new_path(); cx.arc(x - R * 0.25, y - R * 0.3, R * 0.68, 0, 2 * math.pi); cx.set_source_rgb(*T['fl'][0]); cx.fill()
                    cx.new_path(); cx.arc(x + R * 0.1, y + R * 0.45, R * 0.32, 0, 2 * math.pi); cx.set_source_rgb(*T['fl_c']); cx.fill()
            self.items.append((q + TOCAM * 0.3, draw))


# key "sr": s = shape, r = ripe (the game picks ((t>>1)&1, t&1))
FRAMES = [dict(key='00', shape=0, ripe=0), dict(key='01', shape=0, ripe=1), dict(key='10', shape=1, ripe=0), dict(key='11', shape=1, ripe=1)]
BB = (-66, -125, 66, 25)


def render(fr, night=False, bb=BB):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    SauRieng(fr['shape'], fr['ripe'], pa).paint()
    surf.flush(); ch.NIGHT = False
    return surf, bb


def to_image(surf):
    w, h = surf.get_width(), surf.get_height()
    a = np.ndarray((h, w, 4), np.uint8, surf.get_data()).copy()
    im = Image.frombuffer('RGBa', (w, h), a[:, :, [2, 1, 0, 3]].tobytes(), 'raw', 'RGBa', 0, 1)
    return im.resize((w // SS, h // SS), Image.LANCZOS).convert('RGBA')


def atlas(outdir, tabpath, name='k2_saurieng.webp'):
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
    for k, (nm, im, dx, dy) in enumerate(crops):
        if k and k % cols == 0: x = 0; y += rowh + 2; rowh = 0
        pos[nm] = (x, y); x += im.width + 2; rowh = max(rowh, im.height)
    Wt = max(pos[n][0] + im.width for n, im, _, _ in crops); Ht = y + rowh
    sheet = Image.new('RGBA', (Wt, Ht), (0, 0, 0, 0)); table = {}
    for nm, im, dx, dy in crops:
        sx, sy = pos[nm]; sheet.paste(im, (sx, sy))
        table[nm] = [sx, sy, im.width, im.height, round(dx, 2), round(dy, 2), round(im.width / RS, 2), round(im.height / RS, 2)]
    path = os.path.join(outdir, name)
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
        sheet.save('/tmp/claude-0/g/saurieng_%s.png' % tag); print(sheet.size)
