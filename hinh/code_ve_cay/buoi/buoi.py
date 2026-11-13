# Pomelo trees (cây bưởi) for Nông Trại Nhỏ, drawn from the real miền Tây orchard tree as small 3D models and painted in
# flat game tones with the thin same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun
# and night (../chuoi). Two shapes, each unripe (0) or ripe (1), like the game's other "k2" fruit trees:
#   shape 0: a bưởi da xanh orchard tree: a short trunk forking low into three limbs, a dense round crown a little taller
#            than wide, round fruit with a flat top;
#   shape 1: an older bưởi Năm Roi tree: a wider, more open crown whose lower limbs bow under the fruit, pear-shaped
#            fruit with a neck.
# The crown is the clump crown of the mango, longan and rambutan kits (no dark lining, thin spots stay open). Citrus
# leaves are simple, broad, oval with a blunt tip, thick and very glossy; they sit in fans down the slope of the crown.
# The fruit is big and heavy and hangs one or two together on short stalks from the lower and outer crown. Ripe: big
# yellow-green fruit with a waxy sheen and fine oil dots. Not ripe: smaller, deep green fruit.
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
        green=[C('#1a4822'), C('#225c29'), C('#2c7031'), C('#3b863b'), C('#519c4a')],
        und=[C('#3e6634'), C('#4c763e'), C('#5d884a')],
        young=[C('#5f6a2a'), C('#77812f'), C('#8f973a'), C('#a6aa4a'), C('#bbbd5e')],
        inner=C('#173f20'), deep=[C('#1c4723'), C('#235229'), C('#2b5e30')],
        bark=dict(lit=C('#9d9483'), mid=C('#756c5e'), dk=C('#524b41'), fis=C('#463f37')),
        ripe=dict(body=C('#c6cc48'), lit=C('#dde070'), dk=C('#9ea534'), hi=C('#f8f6c4'), dot=C('#b1b83c'), dot_hi=C('#eceda2')),
        raw=dict(body=C('#79b23e'), lit=C('#9cca5c'), dk=C('#558a2c'), hi=C('#def0aa'), dot=C('#6a9e36'), dot_hi=C('#b9dc84')),
        stalk=C('#5d6a30'), stalk_dk=C('#434c22'),
    )


class Buoi(Mit):
    """shape 0 or 1, ripe 0 or 1"""
    NROS = 175          # twig ends on a clump of radius 0.9 (scaled by area); each holds a few compound leaves

    def __init__(self, shape, ripe, pa):
        self.pa = pa; self.seed = shape * 2 + ripe
        self.shape = shape; self.ripe = ripe
        r = self.rng = np.random.default_rng(shape * 5113 + 41)
        self.items = []
        self.T = tones()
        self.flush = []
        if shape == 0:
            self.ce = np.array([0.0, -0.06, 1.62]); self.ra = 1.04; self.ry = 0.94; self.rb = 0.92
        else:
            self.ce = np.array([0.0, -0.08, 1.56]); self.ra = 1.3; self.ry = 1.12; self.rb = 0.74
        self._clumps(r)
        self._trunk(r)
        for c in self.cl: self._clump_leaves(r, c)
        rf = np.random.default_rng(shape * 977 + ripe * 31 + 13)
        self._fruits(rf, (7 if shape == 0 else 8) if ripe else (8 if shape == 0 else 9), ripe)

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
            ring(6, 0.62, -0.42, 0.48, 0.54, 0.7, 0, True)
            ring(4, 0.36, 0.08, 0.52, 0.57, 0.72, 1, False)
            ring(2, 0.1, 0.52, 0.48, 0.52, 0.76, 2, False)
        else:
            # older and wider: a broad low ring whose limbs bow under the fruit, a middle, a gentle top
            ring(7, 0.68, -0.4, 0.48, 0.56, 0.6, 0, True)
            ring(4, 0.36, 0.1, 0.54, 0.6, 0.62, 1, False)
            ring(2, 0.1, 0.48, 0.5, 0.54, 0.66, 2, False)
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
        return (0.12 if self.shape == 0 else 0.15) - 0.02 * z + 0.07 * math.exp(-max(0.0, z) / 0.11)

    def _trunk(self, r):
        self.lean = [-0.02, 0.025][self.shape]
        self.limbs = []; self.leaders = []
        low = [c for c in self.cl if c['tier'] == 0]
        mid = [c for c in self.cl if c['tier'] == 1]
        top = [c for c in self.cl if c['tier'] == 2]
        zf = 0.5 if self.shape == 0 else 0.58
        zs = np.linspace(-0.04, zf + 0.04, 14)
        # the trunk narrows into the fork, so its top never shows as a flat cut between the leaders
        tr = [self.trad(z) * (1 - 0.32 * max(0.0, (z - zf * 0.7) / (zf * 0.3 + 0.04)) ** 1.5) for z in zs]
        self._tube([self.axis(z) for z in zs], tr, np.array([0, 0, 0.5]), fiss=4, r=r)
        f0 = self.axis(zf); self.fork = f0
        self.tc = np.array([0.0, 0.0]); self.tR = self.trad(0.2)
        # three leaders out of the fork: left, right and one leaning back, all turning up into the crown
        if self.shape == 0:
            heads = [np.array([-0.46, 0.1, self.ce[2] + 0.02]), np.array([0.48, 0.04, self.ce[2] + 0.08]),
                     np.array([0.2, -0.38, self.ce[2] + 0.22])]
            w0 = 0.08
        else:
            heads = [np.array([-0.76, 0.14, self.ce[2] - 0.12]), np.array([0.74, 0.04, self.ce[2] - 0.06]),
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
        """a twig end with 4-6 broad, glossy, blunt citrus leaves fanned down the slope of the crown"""
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
            Ll = 0.165 * r.uniform(0.85, 1.15); Wl = Ll * r.uniform(0.5, 0.56)
            pt = p + (r.normal(0, 1, 3) * np.array([1, 1, 0.5])) * 0.022 + ld * 0.014
            # oval, widest a little below the middle, with a blunt rounded tip
            prof = [(0.0, 0.12), (0.08, 0.46), (0.2, 0.78), (0.36, 0.96), (0.5, 1.0), (0.64, 0.94), (0.78, 0.78),
                    (0.89, 0.54), (0.96, 0.28), (1.0, 0.0)]
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
            # citrus leaves are very glossy: a sheen on most sunlit tops
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

    # ------------------------------------------------------------- fruit
    def _fruits(self, r, n, ripe):
        T = self.T; F = T['ripe'] if ripe else T['raw']
        spots = self._surface_spots(r, n + 6, -0.72, 0.05, 0.0, 0.66 if ripe else 0.56)
        got = 0
        for (p, d, c) in spots:
            if got >= n: break
            ns = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            R = (0.155 if ripe else 0.108) * r.uniform(0.92, 1.06)
            pear = self.shape == 1
            two = r.random() < 0.3
            if p[2] - R * 4.2 - 0.14 < 0.0: continue        # no room under it: the fruit would sit on the ground
            got += 1
            for j in range(2 if two else 1):
                # a short stalk from the twig end, out and down; the fruit hangs from it, its neck up
                side = nv(np.cross(UP, ns)) if np.linalg.norm(np.cross(UP, ns)) > 1e-3 else np.array([1.0, 0, 0])
                off = side * (R * 0.95 * (1 if j else -1)) if two else np.zeros(3)
                Ls = r.uniform(0.05, 0.08) + ((0.05 + 0.08 * j) if two else 0.0)
                s0 = p - ns * 0.02
                s1 = s0 + ns * 0.05 - UP * Ls * 0.55 + off * 0.25
                top = s0 + ns * (R * 0.75) - UP * Ls + off
                Hh = R * (1.22 if pear else 0.95)          # half height of the fruit
                cen = top - UP * Hh
                assert cen[2] - Hh > 0.14, 'fruit too low'
                tilt = r.normal(0, 0.1) + 0.12 * float(ns[0])
                self.items.append((p + TOCAM * 0.4 + UP * 0.01 * j,
                                   self._fruit_draw(s0, s1, top, cen, R, Hh, tilt, pear, F,
                                                    np.random.default_rng(int(r.integers(1, 1 << 30))))))

    def _fruit_draw(self, s0, s1, top, cen, R, Hh, tilt, pear, F, rr):
        T = self.T
        dots = [(rr.uniform(-1, 1), rr.uniform(-1, 1)) for _ in range(34)]
        ph = rr.uniform(0, 6.28)
        def draw():
            pa = self.pa; P = pa.P; cx = pa.ctx; k = pa.k
            # the stalk
            cx.new_path(); cx.move_to(*P(s0)); cx.curve_to(*P(s1), *P(s1), *P(top))
            cx.set_source_rgb(*T['stalk']); cx.set_line_width(pa.u(0.55)); cx.set_line_cap(cairo.LINE_CAP_ROUND); cx.stroke()
            c2 = np.array(P(cen)); t2 = np.array(P(top))
            Hs = np.linalg.norm(t2 - c2); Ws = R * k
            axv = np.array([math.sin(tilt), 1.0]); axv = axv / np.linalg.norm(axv); sx = np.array([axv[1], -axv[0]])
            # outline: y from -1 (top) to 1 (bottom); pomelo da xanh round with a flat top and a small neck,
            # Năm Roi a pear with a longer neck
            body = []
            n = 64
            for i in range(n):
                th = 2 * math.pi * i / n
                yy = -math.cos(th); s_ = math.sin(th)
                w = abs(s_)
                if pear:
                    # wide round bottom narrowing into a neck at the top
                    w *= (1 + 0.12 * yy) * (1 - 0.44 * max(0.0, -yy) ** 1.3)
                else:
                    # nearly round, a touch wider low down, the top squashed a little flat round the stalk
                    w *= 1 + 0.04 * yy
                    yy *= 1 - 0.1 * max(0.0, -yy) ** 2
                w *= 1 + 0.01 * math.sin(5 * th + ph)
                w = math.copysign(w, s_)
                body.append(tuple(c2 + axv * Hs * yy + sx * Ws * w))
            pa.fill(body, F['body'])
            cx.save(); pa.path(body); cx.clip()
            sg = 1 if sx @ SLIGHT > 0 else -1
            ang = math.atan2(axv[1], axv[0])
            # the shade side and the underside, then the lit cheek and the waxy sheen
            cx.new_path(); pa.path(body); cx.set_source_rgb(*F['dk']); cx.fill()
            cx.save(); cx.translate(*(c2 - SLIGHT * Ws * 0.2 - axv * Hs * 0.08)); cx.rotate(ang)
            cx.scale(Hs * 0.9, Ws * 0.9); cx.new_path(); cx.arc(0, 0, 1, 0, 2 * math.pi); cx.restore()
            cx.set_source_rgb(*F['body']); cx.fill()
            cx.save(); cx.translate(*(c2 - SLIGHT * Ws * 0.36 - axv * Hs * 0.16)); cx.rotate(ang)
            cx.scale(Hs * 0.42, Ws * 0.4); cx.new_path(); cx.arc(0, 0, 1, 0, 2 * math.pi); cx.restore()
            cx.set_source_rgb(*F['lit']); cx.fill()
            # fine oil dots of the rind
            for (u, v) in dots:
                if u * u + v * v > 0.85: continue
                q = c2 + sx * Ws * u * 0.9 + axv * Hs * v * 0.9
                lit = -((q - c2) @ SLIGHT) / (Ws + 1e-6)
                cx.new_path(); cx.arc(q[0], q[1], pa.u(0.22), 0, 2 * math.pi)
                if lit > 0.15: cx.set_source_rgba(*F['dot_hi'], 0.55)
                else: cx.set_source_rgba(*F['dot'], 0.5)
                cx.fill()
            hc = c2 - SLIGHT * Ws * 0.46 - axv * Hs * 0.3
            cx.save(); cx.translate(*hc); cx.rotate(ang + 0.5); cx.scale(Ws * 0.2, Ws * 0.11)
            cx.new_path(); cx.arc(0, 0, 1, 0, 2 * math.pi); cx.restore()
            cx.set_source_rgba(*F['hi'], 0.75); cx.fill()
            cx.restore()
            pa.soft_edge(body, F['body'])
            # the calyx where the stalk holds the fruit
            cx.new_path(); cx.arc(t2[0], t2[1] + pa.u(0.2), pa.u(0.5), 0, 2 * math.pi); cx.set_source_rgb(*T['stalk_dk']); cx.fill()
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
    Buoi(fr['shape'], fr['ripe'], pa).paint()
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
    path = os.path.join(outdir, 'k2_buoi.webp')
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
        sheet.save('/tmp/claude-0/g/buoi_%s.png' % tag); print(sheet.size)
