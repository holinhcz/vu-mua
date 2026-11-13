# Tamarind trees (cây me) for Nông Trại Nhỏ, drawn from the real village tree of the Nam Bộ countryside as small 3D models
# and painted in flat game tones with the thin same-colour edge of the other new plants (ch.SOFT), with the banana kit's
# camera, sun and night (../chuoi). Two shapes, each unripe (0) or ripe (1), like the game's other "k2" fruit trees:
#   shape 0: a younger tree: a dark trunk forking at knee height into three limbs, a round dense crown;
#   shape 1: an old village tamarind: a thick, deeply fissured, leaning trunk splitting low into heavy limbs that spread
#            wide, a broad low dome whose edges droop.
# The crown is the clump crown of the longan kit (no dark lining, thin spots stay open). Tamarind leaves are feathery:
# each leaf a short stalk with 9-13 pairs of tiny oblong leaflets, so the crown reads fine and soft. The fruit is the
# pod: curved, beaded, hanging in loose bunches of 2-5 off the twig ends. Ripe: cinnamon-brown scurfy pods. Not ripe:
# olive-green pods and a few sprays of small pale-yellow flowers streaked red.
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
        green=[C('#21502a'), C('#2a6331'), C('#357639'), C('#448a43'), C('#5a9f51')],
        und=[C('#4a6e3c'), C('#5a8047'), C('#6c9354')],
        young=[C('#5f6a2a'), C('#77812f'), C('#8f973a'), C('#a6aa4a'), C('#bbbd5e')],
        inner=C('#173f20'), deep=[C('#1c4723'), C('#235229'), C('#2b5e30')],
        bark=dict(lit=C('#857666'), mid=C('#615446'), dk=C('#433a31'), fis=C('#352d26')),
        ripe=dict(body=C('#8c6a48'), lit=C('#ab8762'), dk=C('#5f4630'), hi=C('#cbab86'), scurf=C('#bb9a72')),
        raw=dict(body=C('#a3ab55'), lit=C('#c4ca78'), dk=C('#737d34'), hi=C('#e2e6a6'), scurf=C('#bcc27a')),
        stalk=C('#5e5131'), stalk_dk=C('#463c24'),
        fl=[C('#f4dc6a'), C('#e8c64e'), C('#d0a83e')], fl_r=C('#c4503a'),
    )


class Me(Mit):
    """shape 0 or 1, ripe 0 or 1"""
    NROS = 150          # twig ends on a clump of radius 0.9 (scaled by area); each holds a few compound leaves

    def __init__(self, shape, ripe, pa):
        self.pa = pa; self.seed = shape * 2 + ripe
        self.shape = shape; self.ripe = ripe
        r = self.rng = np.random.default_rng(shape * 5113 + 41)
        self.items = []
        self.T = tones()
        self.flush = []
        if shape == 0:
            self.ce = np.array([0.0, -0.06, 1.7]); self.ra = 1.14; self.ry = 1.02; self.rb = 0.9
        else:
            self.ce = np.array([0.0, -0.08, 1.62]); self.ra = 1.44; self.ry = 1.22; self.rb = 0.66
        self._clumps(r)
        self._trunk(r)
        for c in self.cl: self._clump_leaves(r, c)
        rf = np.random.default_rng(shape * 977 + ripe * 31 + 19)
        if ripe:
            self._pods(rf, 12 if shape == 0 else 14, True)
        else:
            self._pods(rf, 9 if shape == 0 else 10, False)
            self._flowers(rf, 8 if shape == 0 else 9)

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
            ring(6, 0.62, -0.38, 0.5, 0.56, 0.66, 0, True)
            ring(4, 0.36, 0.1, 0.53, 0.58, 0.68, 1, False)
            ring(2, 0.1, 0.5, 0.5, 0.54, 0.72, 2, False)
        else:
            # pruned low and wide: a broad flat ring, a low middle, a gentle top
            # an old village tree: a broad low dome, its rim drooping
            ring(8, 0.7, -0.34, 0.48, 0.56, 0.52, 0, True)
            ring(5, 0.4, 0.1, 0.54, 0.6, 0.56, 1, False)
            ring(2, 0.1, 0.46, 0.54, 0.58, 0.6, 2, False)
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
        return (0.15 if self.shape == 0 else 0.23) - 0.02 * z + 0.07 * math.exp(-max(0.0, z) / 0.11)

    def _trunk(self, r):
        self.lean = [0.02, -0.06][self.shape]
        self.limbs = []; self.leaders = []
        low = [c for c in self.cl if c['tier'] == 0]
        mid = [c for c in self.cl if c['tier'] == 1]
        top = [c for c in self.cl if c['tier'] == 2]
        zf = 0.62 if self.shape == 0 else 0.5
        R = self.trad(zf)
        zs = np.linspace(-0.04, zf, 14)
        self._tube([self.axis(z) for z in zs], [self.trad(z) for z in zs], np.array([0, 0, 0.5]), fiss=7 if self.shape else 5, r=r)
        f0 = self.axis(zf); self.fork = f0
        self.tc = np.array([0.0, 0.0]); self.tR = self.trad(0.2)
        # three leaders out of the fork: left and right in front, one leaning back behind them
        if self.shape == 0:
            heads = [np.array([-0.5, 0.1, self.ce[2] + 0.05]), np.array([0.52, 0.02, self.ce[2] + 0.1]),
                     np.array([-0.24, -0.4, self.ce[2] + 0.22])]
        else:
            heads = [np.array([-0.86, 0.14, self.ce[2] - 0.08]), np.array([0.84, 0.0, self.ce[2] - 0.04]),
                     np.array([0.3, -0.56, self.ce[2] + 0.1])]
        # each leader is the trunk's own half (the back one a narrower core) carried on up: it starts inside the trunk,
        # straight up, and fades in over the top of the trunk, so the fork flows out of the bark with no seam or cap
        z0 = zf - 0.3
        self.leaders = [None] * 3
        for j in (2, 0, 1):
            H = heads[j]
            hd = nv(np.array([H[0], H[1], 0.0]))
            off = hd * R * (0.42 if j < 2 else 0.3)
            w0 = R * (0.6 if j < 2 else 0.5)
            B0 = self.axis(z0) + off
            p1 = self.axis(zf + 0.12) + off * 1.15
            p2 = np.array([H[0] * 0.8, H[1] * 0.85, f0[2] + (H[2] - f0[2]) * 0.5])
            lp = [bez(B0, p1, p2, H, t) for t in np.linspace(0, 1, 18)]
            lr = [w0 * (1 - 0.55 * t) for t in np.linspace(0, 1, 18)]
            key = np.array([0, 0, 0.5]) - TOCAM * 0.3 if j == 2 else (f0 + H) / 2 - TOCAM * 0.25
            self._tube(lp, lr, key, fiss=2, r=r)
            self._fade_in(self.axis(z0 + 0.04), self.axis(zf - 0.04))
            self.leaders[j] = (lp, lr)
        # limbs from the leaders out into the clumps
        for c in low + mid + top:
            side = 0 if c['c'][0] < -0.2 else 1 if c['c'][0] > 0.2 else 2
            if c['c'][1] > 0.25 and side == 2: side = 0 if c['c'][0] < 0 else 1
            lp, lr = self.leaders[side]
            i0 = {0: 7, 1: 11, 2: 15}[c["tier"]]
            b0 = lp[i0]; Tp = c['c'] - UP * c['rz'] * 0.2
            wl = lr[i0] * (0.62 if c['tier'] == 0 else 0.55)
            l = self._limb(r, b0, Tp, wl, key_back=0.45 if c['tier'] == 0 else 0.65, rise=0.05, sag=0.02)
            if c['tier'] == 0: self.limbs.append(l)

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

    # ------------------------------------------------------------- leaves
    def _cluster(self, r, c, p, ns, hc, G, dark=False):
        """a twig end with 3-4 feathery leaves: a short stalk with 9-13 pairs of tiny oblong leaflets"""
        T = self.T
        nrm0 = nv(ns + UP * 0.6)
        t1 = np.cross(nrm0, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(nrm0, t1)
        sun = float(ns @ LIGHT)
        ao = 0.72 + 0.3 * max(-1.0, min(1.0, hc)) + 0.12 * G
        young = any(np.linalg.norm(p - f) < 0.17 for f in self.flush)
        nleaf = int(r.integers(3, 5))
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
            Lr = 0.2 * r.uniform(0.85, 1.12)
            pt = p + (r.normal(0, 1, 3) * np.array([1, 1, 0.5])) * 0.02
            npair = int(r.integers(9, 14))
            for j in range(npair):
                t = 0.12 + 0.88 * (j + 0.5) / npair
                q0 = pt + rd * Lr * t - UP * Lr * 0.12 * t * t
                for sg in (1, -1):
                    # leaflets angle forward along the rachis; the last pair is the longest
                    fw = r.uniform(0.15, 0.4)
                    ld = nv(sd0 * sg * math.cos(fw) + rd * math.sin(fw) - UP * r.uniform(0.05, 0.3) + nrm0 * r.normal(0, 0.22))
                    sd = nv(np.cross(nrm0, ld))
                    Ll = 0.042 * r.uniform(0.85, 1.15) * (1 - 0.25 * abs(j / max(1, npair - 1) - 0.45)); Wl = Ll * r.uniform(0.36, 0.42)
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
                                    rib=(qq, qq)))
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

    # ------------------------------------------------------------- pods
    def _pods(self, r, n, ripe):
        T = self.T; F = T['ripe'] if ripe else T['raw']
        spots = self._surface_spots(r, n + 4, -0.82, 0.25, -0.1, 0.4)
        got = 0
        for (p, d, c) in spots:
            if got >= n: break
            if p[2] < 0.55: continue
            got += 1
            ns = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            s0 = p - ns * 0.02
            s2 = s0 + ns * 0.04 - UP * r.uniform(0.02, 0.05)
            pods = []
            for k in range(int(r.integers(2, 6))):
                # each pod on a short stalk, hanging down, curved to one side like a bean
                L = (0.27 if ripe else 0.22) * r.uniform(0.82, 1.15)
                Wd = (0.046 if ripe else 0.036) * r.uniform(0.9, 1.1)
                az = r.uniform(0, 2 * math.pi)
                hd = np.array([math.cos(az), math.sin(az) * 0.8, 0.0])
                a0 = s2 + hd * r.uniform(0.0, 0.05)
                # splayed out from the stalk and curved like a bean, the tip turning in
                out = hd * L * r.uniform(0.25, 0.45)
                bend = nv(np.cross(UP, hd)) * L * r.uniform(0.15, 0.3) * (1 if r.random() < 0.5 else -1)
                a1 = a0 - UP * L * 0.35 + out * 0.8
                a2 = a0 - UP * L * 0.8 + out + bend
                a3 = a0 - UP * L * 0.95 + out * 0.6 + bend * 1.6
                nb = int(r.integers(3, 6))                       # seeds: the beads along the pod
                pods.append((a0, a1, a2, a3, Wd, nb, r.uniform(0, 1)))
            assert min(min(q[3][2] for q in pods), 1.0) > 0.1, 'pod touches the ground'
            self.items.append((p + TOCAM * 0.35, self._pod_draw(s0, s2, pods, F)))

    def _pod_draw(self, s0, s2, pods, F):
        T = self.T
        def draw():
            pa = self.pa; P = pa.P; cx = pa.ctx
            cx.set_line_cap(cairo.LINE_CAP_ROUND)
            pa.line([P(s0), P(s2)], T['stalk'], pa.u(0.4))
            for (a0, a1, a2, a3, Wd, nb, ph) in sorted(pods, key=lambda z: depth(z[2])):
                pa.line([P(s2), P(a0)], T['stalk'], pa.u(0.26))
                cen = [np.array(P(bez(a0, a1, a2, a3, t))) for t in np.linspace(0, 1, 26)]
                Lp, Rp, nrm = [], [], []
                for i, q in enumerate(cen):
                    t = i / (len(cen) - 1)
                    dd = cen[min(len(cen) - 1, i + 1)] - cen[max(0, i - 1)]; dd = dd / (np.linalg.norm(dd) + 1e-9)
                    nm = np.array([-dd[1], dd[0]])
                    # beaded: narrow between the seeds, rounded at both ends
                    bead = 1 - 0.16 * (0.5 + 0.5 * math.cos(2 * math.pi * (t * nb + ph)))
                    e0 = min(t, 1 - t) / 0.07                          # round blunt ends
                    end = math.sqrt(max(0.0, 1 - (1 - min(1.0, e0)) ** 2)) if e0 < 1 else 1.0
                    end = max(end, 0.25)
                    w = Wd * pa.k * 0.5 * bead * end
                    Lp.append(q + nm * w); Rp.append(q - nm * w); nrm.append((q, nm, w))
                body = [tuple(z) for z in Lp] + [tuple(z) for z in Rp[::-1]]
                pa.fill(body, F['body'])
                cx.save(); pa.path(body); cx.clip()
                sg = 1 if np.mean([nm @ SLIGHT for (_, nm, _) in nrm]) < 0 else -1
                pa.line([tuple(q + nm * w * 0.62 * sg) for (q, nm, w) in nrm], F['lit'], max(pa.u(0.3), Wd * pa.k * 0.22), 0.95)
                pa.line([tuple(q - nm * w * 0.78 * sg) for (q, nm, w) in nrm], F['dk'], max(pa.u(0.3), Wd * pa.k * 0.2), 0.9)
                pa.line([tuple(q + nm * w * 0.5 * sg) for (q, nm, w) in nrm[3:-6]], F['hi'], pa.u(0.22), 0.6)
                # the rough, scurfy skin
                rr = np.random.default_rng(int(ph * 1e6))
                for _ in range(10):
                    q, nm, w = nrm[int(rr.integers(2, len(nrm) - 2))]
                    pt = q + nm * w * rr.uniform(-0.7, 0.7)
                    cx.new_path(); cx.arc(pt[0], pt[1], pa.u(0.16), 0, 2 * math.pi)
                    cx.set_source_rgba(*F['scurf'], 0.6); cx.fill()
                cx.restore()
                pa.soft_edge(body, F['body'])
        return draw

    def _flowers(self, r, n):
        """small sprays of pale-yellow flowers streaked red at the twig ends"""
        T = self.T
        for (p, d, c) in self._surface_spots(r, n, -0.3, 0.8, -0.3, 0.4):
            ns = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            pts = [p + ns * 0.03 + nv(r.normal(0, 1, 3)) * 0.04 - UP * 0.02 * k for k in range(int(r.integers(3, 6)))]
            def draw(pts=pts):
                pa = self.pa; P = pa.P; cx = pa.ctx
                for q in sorted(pts, key=depth):
                    x, y = P(q); R = 0.018 * pa.k
                    for j in range(4):
                        a = j * math.pi / 2 + 0.4
                        cx.new_path(); cx.arc(x + math.cos(a) * R * 0.55, y + math.sin(a) * R * 0.5, R * 0.55, 0, 2 * math.pi)
                        cx.set_source_rgb(*T['fl'][0 if j < 2 else 1]); cx.fill()
                    cx.new_path(); cx.move_to(x, y); cx.line_to(x + R * 0.5, y - R * 0.6)
                    cx.set_source_rgb(*T['fl_r']); cx.set_line_width(pa.u(0.18)); cx.stroke()
            self.items.append((p + TOCAM * 0.3, draw))


# key "sr": s = shape, r = ripe (the game picks ((t>>1)&1, t&1))
FRAMES = [dict(key='00', shape=0, ripe=0), dict(key='01', shape=0, ripe=1), dict(key='10', shape=1, ripe=0), dict(key='11', shape=1, ripe=1)]
BB = (-66, -105, 66, 25)
FLUSH = False


def render(fr, night=False, bb=BB):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    Me(fr['shape'], fr['ripe'], pa).paint()
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
    path = os.path.join(outdir, 'k2_me.webp')
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
        sheet.save('/tmp/claude-0/g/me_%s.png' % tag); print(sheet.size)
