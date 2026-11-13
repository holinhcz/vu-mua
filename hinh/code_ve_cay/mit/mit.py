# Jackfruit trees (cây mít) for Nông Trại Nhỏ, built as small 3D models and painted in flat game tones with the thin
# same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun and night (../chuoi).
# Two shapes, both seen from the front, each unripe (0) or ripe (1), like the game's other "k2" fruit trees:
#   shape 0: a young upright tree, one straight trunk that runs on up as the leader, branches in tiers that leave the
#            trunk almost level and turn up into their leaf clumps, a tall rounded crown;
#   shape 1: an older tree, a thick trunk that splits low into two leaders, a broad dome crown.
# The crown is the mango kit's clump crown (../xoai, ../da): every clump a shell of leaf rosettes, nothing lining the
# inside, so thin spots show the branches and what is behind. Jackfruit leaves are thick, glossy, dark, oval with a
# short point. The fruit grows straight out of the trunk and the big limbs (cauliflory) on short thick stalks: knobbly
# oblong fruits, bright green and small when unripe, big and yellow-green to brownish when ripe.
import math, os, sys
import numpy as np, cairo
from PIL import Image
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'dambut', 'da', 'xoai'): sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM
from da import bez
from xoai import Xoai

RS, SS = 9, 2
PX = RS * SS
KU = 29.0
UP = np.array([0, 0, 1.0])


def tones():
    return dict(
        green=[C('#17461f'), C('#1f5826'), C('#2a6b2f'), C('#388039'), C('#4b9547')],
        und=[C('#3c5d33'), C('#4a6d3c'), C('#5a7e47')],
        young=[C('#4a8a34'), C('#5a9a3c'), C('#6aaa46'), C('#7bb951'), C('#8cc65c')],
        inner=C('#1a4522'), deep=[C('#1f4d25'), C('#26582b'), C('#2f6432')],
        bark=dict(lit=C('#a39280'), mid=C('#7c6d5e'), dk=C('#574b40'), fis=C('#4a3f35')),
        raw=dict(body=C('#7cb23c'), lit=C('#a3d259'), dk=C('#558a2b'), knob=C('#3f6e1f'), hi=C('#d2ec8a')),
        ripe=dict(body=C('#cdb846'), lit=C('#ebd96e'), dk=C('#9e8a30'), knob=C('#7a6820'), hi=C('#fbf1b0')),
        half=dict(body=C('#adb444'), lit=C('#cfd466'), dk=C('#7d872c'), knob=C('#5e6a1e'), hi=C('#edf0aa')),
        stalk=C('#6b6a33'), stalk_dk=C('#4f4e25'), scar=C('#cfc6b4'),
    )


class Mit(Xoai):
    """shape 0 or 1, ripe 0 or 1"""
    NROS = 215

    def __init__(self, shape, ripe, pa):
        self.pa = pa; self.seed = shape * 2 + ripe
        self.shape = shape; self.ripe = ripe
        # the tree's own form comes from the shape only, so unripe and ripe are the same tree
        r = self.rng = np.random.default_rng(shape * 4441 + 29)
        self.items = []
        self.T = tones()
        self.flush = []
        if shape == 0:
            self.ce = np.array([0.0, -0.1, 1.98]); self.ra = 0.96; self.ry = 0.86; self.rb = 1.0
        else:
            self.ce = np.array([0.0, -0.12, 1.7]); self.ra = 1.28; self.ry = 1.1; self.rb = 0.72
        self._clumps(r)
        self._trunk(r)
        for c in self.cl: self._clump_leaves(r, c)
        self._fruits(np.random.default_rng(shape * 977 + ripe * 31 + 5))

    # ------------------------------------------------------------- crown layout
    def _clumps(self, r):
        ce, ra, ry, rb = self.ce, self.ra, self.ry, self.rb
        cl = []
        def ring(n, rad, dz, rc0, rc1, flat, tier, notch):
            # notch: n clumps on n+1 slots with the front slot left empty, so the trunk shows under the crown
            m = n + 1 if notch else n
            az0 = math.pi / 2 + (2 * math.pi / m if notch else r.uniform(0, 2 * math.pi))
            for k in range(n):
                az = az0 + k * 2 * math.pi / m + r.normal(0, 0.08)
                d = rad * r.uniform(0.94, 1.05)
                c = ce + np.array([math.cos(az) * ra * d, math.sin(az) * ry * d, dz * rb + r.normal(0, 0.03)])
                rc = r.uniform(rc0, rc1)
                cl.append(dict(c=c, rc=rc, rz=rc * flat, tier=tier, az=az))
        if self.shape == 0:
            # upright: narrow tiers, a tall rounded top
            ring(5, 0.62, -0.42, 0.48, 0.54, 0.62, 0, True)
            ring(4, 0.4, 0.06, 0.48, 0.53, 0.66, 1, False)
            ring(2, 0.14, 0.48, 0.46, 0.5, 0.7, 2, False)
        else:
            # spreading: a wide low dome over two leaders
            ring(6, 0.64, -0.3, 0.5, 0.58, 0.56, 0, True)
            ring(4, 0.36, 0.16, 0.56, 0.62, 0.6, 1, False)
            ring(2, 0.12, 0.54, 0.52, 0.56, 0.66, 2, False)
        for c in cl:
            c['lumps'] = [(nv(r.normal(0, 1, 3)), r.uniform(1.4, 2.4), r.uniform(0, 6.28), r.uniform(0.05, 0.08)) for _ in range(4)]
            c['tv'] = r.uniform(-0.03, 0.03)
        # a few patches of fresh light-green leaves on the outside of the top clumps
        for c in cl:
            if c['tier'] >= 1 and r.random() < 0.5:
                a = r.uniform(0, 2 * math.pi); zz = r.uniform(0.35, 0.8); rr = math.sqrt(1 - zz * zz)
                self.flush.append(c['c'] + np.array([rr * math.cos(a) * c['rc'], rr * math.sin(a) * c['rc'], zz * c['rz']]))
        self.cl = cl

    # ------------------------------------------------------------- wood
    def axis(self, z):
        """the trunk's centre line (shape 0 all the way up, shape 1 up to the split)"""
        return np.array([0.03 * math.sin(z * 1.7) + self.lean * z * z, 0.015 * math.sin(z * 2.3), z])

    def trad(self, z):
        return (0.15 if self.shape == 0 else 0.185) - 0.022 * z + 0.075 * math.exp(-max(0.0, z) / 0.11)

    def _limb(self, r, b0, Tp, w0, key_back=0.4, rise=0.08, sag=0.0):
        hz = np.array([Tp[0] - b0[0], Tp[1] - b0[1], 0.0])
        p1 = b0 + hz * 0.38 + UP * rise
        p2 = b0 + hz * 0.78 + UP * (Tp[2] - b0[2]) * 0.35 - UP * sag
        lp = [bez(b0, p1, p2, Tp, t) for t in np.linspace(0, 1, 14)]
        lr = [w0 * (1 - 0.6 * t) for t in np.linspace(0, 1, 14)]
        self._tube(lp, lr, (b0 + Tp) / 2 - TOCAM * key_back, fiss=1, r=r)
        return lp, lr

    def _trunk(self, r):
        self.lean = [0.012, -0.02][self.shape]
        self.limbs = []
        low = [c for c in self.cl if c['tier'] == 0]
        mid = [c for c in self.cl if c['tier'] == 1]
        top = [c for c in self.cl if c['tier'] == 2]
        if self.shape == 0:
            zt = self.ce[2] + 0.42
            zs = np.linspace(-0.04, zt, 22)
            pts = [self.axis(z) for z in zs]
            rads = [max(0.035, self.trad(z) * (1 - 0.55 * (max(0.0, z) / zt) ** 1.5)) for z in zs]
            self._tube(pts, rads, np.array([0, 0, 0.6]), fiss=4, r=r)
            for c in low:
                zb = 1.02 + r.uniform(0, 0.16)
                b0 = self.axis(zb); Tp = c['c'] - UP * c['rz'] * 0.15
                self.limbs.append(self._limb(r, b0, Tp, 0.072 * r.uniform(0.92, 1.08), rise=0.04, sag=0.02))
            for c in mid:
                zb = 1.55 + r.uniform(0, 0.15)
                b0 = self.axis(zb); Tp = c['c'] - UP * c['rz'] * 0.2
                self._limb(r, b0, Tp, 0.052, key_back=0.6)
            for c in top:
                b0 = self.axis(2.05); Tp = c['c'] - UP * c['rz'] * 0.25
                self._limb(r, b0, Tp, 0.04, key_back=0.7, rise=0.1)
            self.fork = None
        else:
            zf = 0.72
            zs = np.linspace(-0.04, zf + 0.06, 12)
            pts = [self.axis(z) for z in zs]
            rads = [self.trad(z) for z in zs]
            self._tube(pts, rads, np.array([0, 0, 0.5]), fiss=4, r=r)
            f0 = self.axis(zf)
            # two leaders out of the split, one each side, both turning up
            heads = [np.array([-0.5, 0.04, self.ce[2] + 0.3]), np.array([0.54, -0.1, self.ce[2] + 0.26])]
            self.leaders = []
            for j, H in enumerate(heads):
                p1 = f0 + np.array([H[0] * 0.45, H[1] * 0.3, 0.26])
                p2 = np.array([H[0] * 0.95, H[1], f0[2] + (H[2] - f0[2]) * 0.6])
                lp = [bez(f0 - UP * 0.05, p1, p2, H, t) for t in np.linspace(0, 1, 18)]
                lr = [0.125 * (1 - 0.62 * t) for t in np.linspace(0, 1, 18)]
                self._tube(lp, lr, (f0 + H) / 2 - TOCAM * (0.25 if j == 0 else 0.3), fiss=2, r=r)
                self.leaders.append((lp, lr))
            for c in low + mid:
                side = 0 if c['c'][0] < 0 else 1
                lp, lr = self.leaders[side]
                i0 = 4 if c['tier'] == 0 else 9
                b0 = lp[i0]; Tp = c['c'] - UP * c['rz'] * 0.15
                w0 = lr[i0] * (0.6 if c['tier'] == 0 else 0.5)
                l = self._limb(r, b0, Tp, w0, key_back=0.45 if c['tier'] == 0 else 0.6, rise=0.05, sag=0.03)
                if c['tier'] == 0: self.limbs.append(l)
            self.fork = f0

    # ------------------------------------------------------------- leaves
    def _cluster(self, r, c, p, ns, hc, G, dark=False):
        """a rosette of 5-8 thick glossy oval leaves with a short point, held out nearly level from a twig end"""
        T = self.T
        nrm0 = nv(ns + UP * 0.7)
        t1 = np.cross(nrm0, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(nrm0, t1)
        sun = float(ns @ LIGHT)
        ao = 0.72 + 0.3 * max(-1.0, min(1.0, hc)) + 0.12 * G
        young = any(np.linalg.norm(p - f) < 0.15 for f in self.flush)
        nl = int(r.integers(4, 7))
        dn = -UP - (-UP @ nrm0) * nrm0
        down = nv(dn) if np.linalg.norm(dn) > 0.25 else None
        az0 = r.uniform(0, 2 * math.pi)
        leaves = []
        for k in range(nl):
            if down is not None:
                # down the slope of the crown, fanned out, so leaves lie over each other like scales
                a = r.uniform(-1.25, 1.25)
                A = nv(down * math.cos(a) + nv(np.cross(nrm0, down)) * math.sin(a))
            else:
                az = az0 + k * 2 * math.pi / nl + r.normal(0, 0.5)
                A = math.cos(az) * t1 + math.sin(az) * t2
            el = r.uniform(-0.1, 0.25)
            ld = nv(A * math.cos(el) + nrm0 * math.sin(el) - UP * 0.15)
            sd = nv(np.cross(nrm0, ld))
            Ll = 0.18 * r.uniform(0.85, 1.12) * (0.82 if young else 1.0); Wl = Ll * 0.46
            pt = p + (r.normal(0, 1, 3) * np.array([1, 1, 0.5])) * 0.02 + ld * 0.012
            # widest past the middle, rounded, then a short blunt point
            prof = [(0.0, 0.08), (0.1, 0.42), (0.24, 0.74), (0.42, 0.94), (0.58, 1.0), (0.73, 0.9), (0.85, 0.66),
                    (0.93, 0.36), (0.975, 0.14), (1.0, 0.0)]
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
            if young and z['top']:
                z['col'] = T['young'][max(0, min(4, int((v - 0.35) / 0.12)))]
            elif not z['top']:
                z['col'] = T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            else:
                z['col'] = T['green'][0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4]
            # thick glossy leaves: a sheen on most sunlit tops
            z['gloss'] = z['top'] and z['lam'] > 0.35 and v > 0.6
        return leaves

    # ------------------------------------------------------------- fruit
    def _fruits(self, r):
        """jackfruit straight off the trunk (and the big limbs), hanging on short thick stalks, on the front half"""
        ripe = self.ripe
        # (kind, height on the trunk or leader index, angle round the trunk or place along the leader)
        # angles: pi/2 faces the camera, 0 the right side, pi the left side; heights keep every fruit off the ground
        if self.shape == 0:
            spots = ([('t', 0.56, 0.3), ('t', 0.66, 2.8), ('t', 1.02, 0.95), ('l', 0, 0.42)] if ripe else
                     [('t', 0.52, 0.45), ('t', 0.8, 2.55), ('t', 1.04, 1.35)])
        else:
            spots = ([('t', 0.5, 0.8), ('t', 0.56, 2.9), ('L', 0, 0.36), ('L', 1, 0.42)] if ripe else
                     [('t', 0.44, 0.45), ('t', 0.62, 2.6), ('L', 1, 0.3)])
        for j, (kind, z, a) in enumerate(spots):
            if kind == 't':
                ax = self.axis(z); R = self.trad(z)
                out = np.array([math.cos(a), math.sin(a), 0.0])
                att = ax + out * R * 0.92
            else:
                if kind == 'l':
                    if not self.limbs: continue
                    front = max(self.limbs, key=lambda l: l[0][-1][1])
                    lp, lr = front
                else:
                    lp, lr = self.leaders[z]
                i = int(len(lp) * a)
                ax = lp[i]; R = lr[i]
                out = nv(np.array([0.0, 1.0, -0.35]))
                att = ax + out * R * 0.8
            if ripe:
                L = r.uniform(0.34, 0.4); W = L * r.uniform(0.6, 0.66)
                pal = 'half' if j % 3 == 2 else 'ripe'
            else:
                L = r.uniform(0.22, 0.26); W = L * r.uniform(0.6, 0.66)
                pal = 'raw'
            st = r.uniform(0.02, 0.035)
            # the fruit hangs pressed against the bark on a short thick stalk
            top = att - UP * st + out * W * 0.22
            cen = top - UP * L * 0.5
            assert cen[2] - L * 0.5 > 0.06, ('fruit touches the ground', kind, z, a)
            tilt = r.normal(0, 0.12) + (0.18 if out[0] > 0.5 else -0.18 if out[0] < -0.5 else 0.0)
            self.items.append((cen + out * 0.3 + TOCAM * 0.25, self._fruit_draw(att, top, cen, L, W, tilt, pal, out,
                                                                                 np.random.default_rng(int(r.integers(1, 1 << 30))))))

    def _fruit_draw(self, att, top, cen, L, W, tilt, pal, out, rr):
        T = self.T; F = T[pal]
        def draw():
            pa = self.pa; P = pa.P; k = pa.k; cx = pa.ctx
            # the stalk: a short thick peduncle bending down from the bark
            a0 = np.array(P(att)); a1 = np.array(P(top))
            sw = pa.u(1.2 if L > 0.25 else 0.9)
            m = (a0 + a1) / 2 + np.array([0, -0.2 * sw])
            cx.new_path(); cx.move_to(*a0); cx.curve_to(*m, *m, *a1)
            cx.set_source_rgb(*T['stalk']); cx.set_line_width(sw); cx.set_line_cap(cairo.LINE_CAP_ROUND); cx.stroke()
            c2 = np.array(P(cen)); t2 = np.array(P(top))
            Ls = np.linalg.norm(t2 - c2) * 2; Ws = W * k
            axv = np.array([math.sin(tilt), 1.0]); axv = axv / np.linalg.norm(axv); sx = np.array([axv[1], -axv[0]])
            # an oblong lumpy fruit, a little fuller low down, its outline knobbly from the spines
            body = []
            n = 72
            ph1, ph2 = rr.uniform(0, 6.28), rr.uniform(0, 6.28)
            for i in range(n):
                th = 2 * math.pi * i / n
                cy_, sy_ = math.cos(th), math.sin(th)
                knob = 1 + 0.03 * math.sin(30 * th + ph2)
                rx = 0.5 * (1 + 0.07 * cy_ + 0.05 * math.sin(3 * th + ph1)) * knob
                y_ = cy_ * 0.5 * (1 + 0.02 * sy_) * knob
                body.append(tuple(c2 + axv * Ls * y_ + sx * Ws * sy_ * rx))
            pa.fill(body, F['body'])
            cx.save(); pa.path(body); cx.clip()
            sg = 1 if sx @ SLIGHT > 0 else -1
            # the side away from the sun, then the sunlit cheek
            cx.save(); cx.translate(*(c2 - sx * sg * Ws * 0.42 + axv * Ls * 0.04)); cx.rotate(math.atan2(axv[1], axv[0]))
            cx.scale(Ls * 0.62, Ws * 0.5); cx.new_path(); cx.arc(0, 0, 1, 0, 2 * math.pi); cx.restore()
            cx.set_source_rgb(*F['dk']); cx.fill()
            cx.save(); cx.translate(*(c2 + sx * sg * Ws * 0.2 - axv * Ls * 0.12)); cx.rotate(math.atan2(axv[1], axv[0]))
            cx.scale(Ls * 0.3, Ws * 0.22); cx.new_path(); cx.arc(0, 0, 1, 0, 2 * math.pi); cx.restore()
            cx.set_source_rgb(*F['lit']); cx.fill()
            # the knobbly skin: a staggered grid of small bumps, each a dark pit with a lit tip
            sp = pa.u(0.62)
            nu = int(Ws / sp) + 3; nv_ = int(Ls / (sp * 0.86)) + 3
            for iv in range(-nv_ // 2 - 1, nv_ // 2 + 2):
                for iu in range(-nu // 2 - 1, nu // 2 + 2):
                    u = (iu + 0.5 * (iv & 1)) * sp; v = iv * sp * 0.86
                    q = c2 + sx * u + axv * v + rr.normal(0, 0.06, 2) * sp
                    # bumps crowd toward the edges, as on a round surface
                    e = (u / (Ws * 0.5)) if Ws > 0 else 0
                    if abs(e) > 1.02: continue
                    lit = (sx * sg) @ (q - c2) / (Ws * 0.5 + 1e-6)
                    rad = sp * 0.26 * (1 - 0.35 * e * e)
                    cx.new_path(); cx.arc(q[0], q[1], rad, 0, 2 * math.pi)
                    cx.set_source_rgba(*F['knob'], 0.42 if lit > -0.2 else 0.58); cx.fill()
                    if lit > -0.3:
                        cx.new_path(); cx.arc(q[0] - SLIGHT[0] * rad * 0.6, q[1] - SLIGHT[1] * rad * 0.6, rad * 0.5, 0, 2 * math.pi)
                        cx.set_source_rgba(*F['hi'], 0.35 + 0.35 * max(0.0, min(1.0, lit))); cx.fill()
            cx.restore()
            pa.soft_edge(body, F['body'])
            # where the stalk holds the fruit
            cx.new_path(); cx.arc(a1[0], a1[1], sw * 0.6, 0, 2 * math.pi); cx.set_source_rgb(*T['stalk_dk']); cx.fill()
        return draw

    def shadow(self):
        pa = self.pa; c = pa.ctx
        cx, cy = pa.P(np.array([self.ce[0], self.ce[1], 0.0]))
        rx = self.ra * 0.9 * pa.k; e = 0.5
        c.save(); c.translate(cx, cy); c.scale(rx, rx * e); c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
        c.set_source_rgba(0, 0, 0, 0.12); c.fill()
        fx, fy = pa.P(np.array([0.0, 0.0, 0.0])); rf = 0.42 * pa.k
        c.save(); c.translate(fx, fy); c.scale(rf, rf * e); c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
        c.set_source_rgba(0, 0, 0, 0.1); c.fill()


# key "sr": s = shape, r = ripe (the game picks ((t>>1)&1, t&1))
FRAMES = [dict(key='00', shape=0, ripe=0), dict(key='01', shape=0, ripe=1), dict(key='10', shape=1, ripe=0), dict(key='11', shape=1, ripe=1)]
BB = (-60, -100, 60, 25)


def render(fr, night=False, bb=BB):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    Mit(fr['shape'], fr['ripe'], pa).paint()
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
    path = os.path.join(outdir, 'k2_mit.webp')
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
        sheet.save('/tmp/claude-0/g/mit_%s.png' % tag); print(sheet.size)
