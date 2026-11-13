# Mangosteen trees (cây măng cụt) for Nông Trại Nhỏ, drawn from the real miền Tây orchard tree (Lái Thiêu, Cái Mơn) as
# small 3D models and painted in flat game tones with the thin same-colour edge of the other new plants (ch.SOFT), with
# the banana kit's camera, sun and night (../chuoi). Two shapes, each unripe (0) or ripe (1), like the game's other
# "k2" fruit trees:
#   shape 0: an orchard tree: a short straight trunk and a dense, tidy bell-shaped crown that comes down almost to the
#            ground;
#   shape 1: an older tree: a taller, narrower crown in the shape of a round-topped cone over a clear trunk.
# Mangosteen grows like the durian (one leader, branches in level pairs), so the wood is the durian kit's (../saurieng);
# the crown is tidier and darker. The leaves are big, thick and leathery, oval with a short point, in opposite pairs at
# the twig ends, very glossy dark green on top and yellow-green under. The fruit hangs one or two together at the twig
# ends on the outside of the crown: a round fruit with a cap of four thick green sepals. Ripe: deep purple with a waxy
# bloom. Not ripe: pale green, a few turning pink-red.
import math, os, sys
import numpy as np, cairo
from PIL import Image
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'dambut', 'da', 'xoai', 'mit', 'saurieng'): sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM
from saurieng import SauRieng, to_image
import saurieng as sr

RS, SS = 9, 2
PX = RS * SS
KU = 29.0
UP = np.array([0, 0, 1.0])


def tones():
    return dict(
        green=[C('#173f1f'), C('#1e5026'), C('#27622d'), C('#347637'), C('#478b44')],
        und=[C('#557236'), C('#668341'), C('#7a984d')],
        young=[C('#5f6a2a'), C('#77812f'), C('#8f973a'), C('#a6aa4a'), C('#bbbd5e')],
        inner=C('#173f20'), deep=[C('#1c4723'), C('#235229'), C('#2b5e30')],
        bark=dict(lit=C('#8f806e'), mid=C('#685a4c'), dk=C('#493f35'), fis=C('#3b322a')),
        ripe=dict(body=C('#5b2449'), lit=C('#7b3c65'), dk=C('#3b1530'), hi=C('#c79bb6')),
        raw=dict(body=C('#a9c262'), lit=C('#c6d887'), dk=C('#7b9642'), hi=C('#ecf3c6')),
        blush=dict(body=C('#c4627a'), lit=C('#dc8a9b'), dk=C('#8f3d55'), hi=C('#f3cad2')),
        cap=dict(body=C('#4d7a34'), lit=C('#6f9b4b'), dk=C('#355828')),
        stalk=C('#5d6a32'), stalk_dk=C('#434c24'),
    )


class MangCut(SauRieng):
    """shape 0 or 1, ripe 0 or 1"""
    NROS = 185

    def __init__(self, shape, ripe, pa):
        self.pa = pa; self.seed = shape * 2 + ripe
        self.shape = shape; self.ripe = ripe
        r = self.rng = np.random.default_rng(shape * 3307 + 61)
        self.items = []
        self.T = tones()
        self.flush = []
        if shape == 0:
            self.ce = np.array([0.0, -0.04, 1.45]); self.ra = 1.06; self.ry = 0.94; self.rb = 0.9
        else:
            self.ce = np.array([0.0, -0.04, 1.85]); self.ra = 1.04; self.ry = 0.92; self.rb = 0.95
        self._clumps(r)
        self._trunk(r)
        for c in self.cl: self._clump_leaves(r, c)
        rf = np.random.default_rng(shape * 977 + ripe * 31 + 47)
        self._fruits(rf, (12 if shape == 0 else 13) if ripe else (9 if shape == 0 else 10), ripe)

    def _clumps(self, r):
        ra, ry = self.ra, self.ry
        cl = []
        def ring(n, rad, z, rc0, rc1, flat, tier, notch):
            m = n + 1 if notch else n
            az0 = math.pi / 2 + (2 * math.pi / m if notch else r.normal(0, 0.12))
            for k in range(n):
                az = az0 + k * 2 * math.pi / m + r.normal(0, 0.06)
                d = rad * r.uniform(0.96, 1.04)
                c = np.array([math.cos(az) * ra * d, self.ce[1] + math.sin(az) * ry * d, z + r.normal(0, 0.02)])
                rc = r.uniform(rc0, rc1)
                cl.append(dict(c=c, rc=rc, rz=rc * flat, tier=tier, az=az))
        if self.shape == 0:
            # a tidy bell: wide low skirt, then each ring narrower, a round top
            ring(7, 0.72, 0.78, 0.44, 0.5, 0.62, 0, True)
            ring(6, 0.55, 1.26, 0.45, 0.5, 0.64, 1, False)
            ring(4, 0.36, 1.74, 0.44, 0.48, 0.68, 2, False)
            ring(2, 0.12, 2.16, 0.4, 0.44, 0.74, 3, False)
        else:
            # a taller round-topped cone over a clear trunk
            ring(6, 0.74, 1.02, 0.42, 0.48, 0.6, 0, True)
            ring(5, 0.56, 1.5, 0.43, 0.48, 0.62, 1, False)
            ring(4, 0.38, 1.98, 0.42, 0.46, 0.66, 2, False)
            ring(3, 0.2, 2.44, 0.38, 0.42, 0.7, 3, False)
            ring(2, 0.08, 2.82, 0.34, 0.37, 0.74, 4, False)
        for c in cl:
            # tidier than the durian: smaller lumps, so the crown keeps its clean outline
            c['lumps'] = [(nv(r.normal(0, 1, 3)), r.uniform(1.4, 2.4), r.uniform(0, 6.28), r.uniform(0.03, 0.05)) for _ in range(4)]
            c['tv'] = r.uniform(-0.03, 0.03)
        self.cl = cl

    def trad(self, z):
        b = 0.1 if self.shape == 0 else 0.12
        return max(0.03, b * (1 - 0.22 * z) + 0.05 * math.exp(-max(0.0, z) / 0.1))

    # ------------------------------------------------------------- leaves
    def _cluster(self, r, c, p, ns, hc, G, dark=False):
        """a twig end with 2 or 3 opposite pairs of big, thick, oval leaves with a short point"""
        T = self.T
        nrm0 = nv(ns + UP * 0.6)
        t1 = np.cross(nrm0, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(nrm0, t1)
        sun = float(ns @ LIGHT)
        ao = 0.72 + 0.3 * max(-1.0, min(1.0, hc)) + 0.1 * max(-1.2, min(1.2, G))
        ztop = c['c'][2] + c['rz'] * 0.95
        if p[2] > ztop: p = np.array([p[0], p[1], ztop])
        dn = -UP - (-UP @ nrm0) * nrm0
        down = nv(dn) if np.linalg.norm(dn) > 0.25 else None
        # the twig's own direction: out along the crown surface and a little down; under the crown the twigs reach out
        # level, so no leaves dangle below the skirt
        if ns[2] < -0.3:
            hz = np.array([ns[0], ns[1], 0.0]); hz = nv(hz) if np.linalg.norm(hz) > 1e-3 else t1
            tw = nv(hz + UP * 0.1 + r.normal(0, 0.15, 3))
        elif down is not None:
            tw = nv(down * 0.5 + nrm0 * 0.6 + r.normal(0, 0.2, 3))
        else:
            a = r.uniform(0, 2 * math.pi); tw = nv(math.cos(a) * t1 + math.sin(a) * t2 + nrm0 * 0.5)
        sd0 = nv(np.cross(tw, nrm0)) if np.linalg.norm(np.cross(tw, nrm0)) > 1e-3 else t1
        leaves = []
        npair = int(r.integers(2, 4))
        for j in range(npair):
            base = p + tw * 0.03 * j
            rot = (j % 2) * 0.9                      # each pair turned against the one below it
            sdj = nv(sd0 * math.cos(rot) + nrm0 * math.sin(rot) * 0.5)
            for sg in (1, -1):
                spread = r.uniform(0.5, 0.95) if j < npair - 1 else r.uniform(0.25, 0.5)
                ld = nv(sdj * sg * math.sin(spread) + tw * math.cos(spread) - UP * (0.05 if ns[2] < -0.3 else 0.2) + r.normal(0, 0.08, 3))
                sd = nv(np.cross(nrm0, ld) + r.normal(0, 0.12, 3))
                Ll = 0.175 * r.uniform(0.88, 1.12) * (1.0 if j < npair - 1 else 0.85); Wl = Ll * r.uniform(0.44, 0.5)
                pt = base + ld * 0.01
                # oval, broadest at the middle, a short blunt point
                prof = [(0.0, 0.12), (0.07, 0.5), (0.18, 0.8), (0.32, 0.96), (0.48, 1.0), (0.64, 0.94), (0.78, 0.76),
                        (0.89, 0.5), (0.96, 0.24), (1.0, 0.0)]
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
                                   rib=(pt, pt + ld * Ll * 0.88 - UP * Ll * 0.08)))
        vm = float(np.mean([z['v'] for z in leaves]))
        for z in leaves:
            v = 0.6 * vm + 0.4 * z['v'] + c['tv']
            if not z['top']:
                z['col'] = T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            else:
                z['col'] = T['green'][0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4]
            z['gloss'] = z['top'] and z['lam'] > 0.3 and v > 0.56
        return leaves

    # ------------------------------------------------------------- fruit
    def _fruits(self, r, n, ripe):
        T = self.T
        R0 = 0.1 if ripe else 0.082
        tiers = tuple(range(5))
        got = 0
        for (p, d, c) in self._surface_spots(r, n + 6, -0.6, 0.45, 0.05, 0.42 if ripe else 0.4, tiers):
            if got >= n: break
            ns = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            R = R0 * r.uniform(0.92, 1.08)
            two = r.random() < 0.25
            if ripe: F = T['ripe']
            else: F = T['blush'] if r.random() < 0.3 else T['raw']
            got += 1
            for j in range(2 if two else 1):
                side = nv(np.cross(UP, ns)) if np.linalg.norm(np.cross(UP, ns)) > 1e-3 else np.array([1.0, 0, 0])
                off = side * R * 1.05 * (1 if j else -1) if two else np.zeros(3)
                s0 = p + ns * 0.04
                top = s0 + ns * R * 0.6 - UP * r.uniform(0.03, 0.05) + off
                cen = top - UP * R * 0.92
                if cen[2] - R < 0.1: continue
                self.items.append((cen + TOCAM * 0.3 + UP * 0.01 * j,
                                   self._fruit_draw(s0, top, cen, R, F, np.random.default_rng(int(r.integers(1, 1 << 30))))))

    def _fruit_draw(self, s0, top, cen, R, F, rr):
        T = self.T; Cp = T['cap']
        ph = rr.uniform(0, 6.28)
        def draw():
            pa = self.pa; P = pa.P; cx = pa.ctx; k = pa.k
            pa.line([P(s0), P(top + UP * R * 0.32)], T['stalk'], max(pa.u(0.45), R * k * 0.16))
            c2 = np.array(P(cen)); Ws = R * k; Hs = R * k * 0.96
            body = [tuple(c2 + np.array([math.cos(t) * Ws * (1 + 0.02 * math.sin(3 * t + ph)), math.sin(t) * Hs]))
                    for t in np.linspace(0, 2 * math.pi, 48, endpoint=False)]
            pa.fill(body, F['body'])
            cx.save(); pa.path(body); cx.clip()
            cx.new_path(); pa.path(body); cx.set_source_rgb(*F['dk']); cx.fill()
            cx.new_path(); cx.arc(*(c2 - np.array(SLIGHT) * Ws * 0.16), Ws * 0.9, 0, 2 * math.pi); cx.set_source_rgb(*F['body']); cx.fill()
            cx.new_path(); cx.arc(*(c2 - np.array(SLIGHT) * Ws * 0.36), Ws * 0.48, 0, 2 * math.pi); cx.set_source_rgb(*F['lit']); cx.fill()
            hc = c2 - np.array(SLIGHT) * Ws * 0.5
            cx.save(); cx.translate(*hc); cx.rotate(-0.6); cx.scale(Ws * 0.2, Ws * 0.12)
            cx.new_path(); cx.arc(0, 0, 1, 0, 2 * math.pi); cx.restore(); cx.set_source_rgba(*F['hi'], 0.7); cx.fill()
            cx.restore()
            pa.soft_edge(body, F['body'])
            # the cap: four thick round sepals lying on the top of the fruit, seen from a little above
            tp = c2 - np.array([0.0, Hs * 0.78])
            for i in sorted(range(4), key=lambda i: math.sin(i * math.pi / 2 + ph)):
                a = i * math.pi / 2 + ph
                qx = tp + np.array([math.cos(a) * Ws * 0.36, math.sin(a) * Ws * 0.16])
                col = Cp['lit'] if math.cos(a) < 0.2 else Cp['body']
                cx.save(); cx.translate(*qx); cx.rotate(math.atan2(math.sin(a) * 0.45, math.cos(a)))
                cx.scale(Ws * 0.34, Ws * 0.2); cx.new_path(); cx.arc(0, 0, 1, 0, 2 * math.pi); cx.restore()
                cx.set_source_rgb(*col); cx.fill_preserve(); cx.set_source_rgb(*Cp['dk']); cx.set_line_width(pa.u(0.14)); cx.stroke()
            cx.new_path(); cx.arc(tp[0], tp[1], Ws * 0.12, 0, 2 * math.pi); cx.set_source_rgb(*Cp['dk']); cx.fill()
        return draw


FRAMES = [dict(key='00', shape=0, ripe=0), dict(key='01', shape=0, ripe=1), dict(key='10', shape=1, ripe=0), dict(key='11', shape=1, ripe=1)]
BB = (-60, -110, 60, 25)


def render(fr, night=False, bb=BB):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    MangCut(fr['shape'], fr['ripe'], pa).paint()
    surf.flush(); ch.NIGHT = False
    return surf, bb


if __name__ == '__main__':
    sr.render = render; sr.FRAMES = FRAMES
    if len(sys.argv) > 2 and sys.argv[1] == 'atlas':
        sr.atlas(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else 'atlas.json', name='k2_mangcut.webp')
    else:
        which = [int(x) for x in sys.argv[1].split(',')] if len(sys.argv) > 1 else range(len(FRAMES))
        night = len(sys.argv) > 2 and sys.argv[2] == 'n'
        tag = sys.argv[3] if len(sys.argv) > 3 else 'a'
        ims = [to_image(render(FRAMES[k], night)[0]) for k in which]
        w = sum(i.width for i in ims); h = ims[0].height
        sheet = Image.new('RGBA', (w, h), (40, 58, 52, 255) if night else (153, 204, 86, 255)); x = 0
        for im in ims:
            sheet.alpha_composite(im, (x, 0)); x += im.width
        sheet.save('/tmp/claude-0/g/mangcut_%s.png' % tag); print(sheet.size)
