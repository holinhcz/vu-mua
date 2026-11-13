# Orange trees (cây cam) for Nông Trại Nhỏ, drawn from the real miền Tây orchard tree as small 3D models and painted in
# flat game tones with the thin same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun
# and night (../chuoi). Two shapes, each unripe (0) or ripe (1), like the game's other "k2" fruit trees:
#   shape 0: a cam mật / cam xoàn orchard tree: a short trunk forking at knee height, a dense round crown a little wider
#            than tall, loaded with smooth orange fruit;
#   shape 1: an older cam sành tree (Tam Bình, Vĩnh Long): broader and lower, the outer limbs bowing under the fruit,
#            one of them held up by a bamboo prop the way orchards do it; rough-skinned fruit, orange with green
#            shoulders.
# Citrus, so the leaves are the pomelo kit's (../buoi) at orange size: oval, glossy, with a short blunt point. The trunk
# fork is the tamarind kit's (../me), its leaders fading in out of the bark. Fruit hangs one to three together at the
# twig ends all over the outside of the crown. Not ripe: smaller green fruit and sprays of white five-petal flowers.
import math, os, sys
import numpy as np, cairo
from PIL import Image
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'dambut', 'da', 'xoai', 'mit', 'buoi', 'me'): sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM
from da import bez
from buoi import Buoi, to_image
import buoi as bu
from me import Me

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
        bark=dict(lit=C('#9a9080'), mid=C('#73695b'), dk=C('#514a40'), fis=C('#453f37')),
        # cam mật: smooth, bright orange
        ripe0=dict(body=C('#f0952c'), lit=C('#f8b450'), dk=C('#c8701e'), hi=C('#fde4ae'), dot=C('#de8424'),
                   dot_hi=C('#fbc878'), sh=None),
        # cam sành: a deeper orange with rough skin, the shoulders still green
        ripe1=dict(body=C('#e6862a'), lit=C('#f2a446'), dk=C('#b9651c'), hi=C('#f9d49a'), dot=C('#c96f1e'),
                   dot_hi=C('#f6bb6a'), sh=C('#7f9a36')),
        raw=dict(body=C('#5fa23a'), lit=C('#82bc58'), dk=C('#43812a'), hi=C('#cfe8a4'), dot=C('#549434'),
                 dot_hi=C('#a6d47c'), sh=None),
        stalk=C('#5d6a30'), stalk_dk=C('#434c24'),
        fl=[C('#fbfaf2'), C('#e6e4d6'), C('#cfcbb6')], fl_c=C('#efd25a'),
        bam=dict(lit=C('#d6c27c'), mid=C('#b39d58'), dk=C('#8a763e'), node=C('#7a6834')),
    )


class Cam(Buoi):
    """shape 0 or 1, ripe 0 or 1"""
    NROS = 190

    _trunk = Me._trunk
    _fade_in = Me._fade_in

    def __init__(self, shape, ripe, pa):
        self.pa = pa; self.seed = shape * 2 + ripe
        self.shape = shape; self.ripe = ripe
        r = self.rng = np.random.default_rng(shape * 4421 + 17)
        self.items = []
        self.T = tones()
        self.flush = []
        if shape == 0:
            self.ce = np.array([0.0, -0.05, 1.3]); self.ra = 1.16; self.ry = 1.02; self.rb = 0.8
        else:
            self.ce = np.array([0.0, -0.06, 1.2]); self.ra = 1.36; self.ry = 1.16; self.rb = 0.66
        self._clumps(r)
        self._trunk(r)
        if shape == 1: self._prop(r)
        for c in self.cl: self._clump_leaves(r, c)
        rf = np.random.default_rng(shape * 977 + ripe * 31 + 5)
        if ripe:
            self._fruits(rf, 17 if shape == 0 else 20, True)
        else:
            self._fruits(rf, 11 if shape == 0 else 12, False)
            self._flowers(rf, 10 if shape == 0 else 11)

    def _clumps(self, r):
        ce, ra, ry, rb = self.ce, self.ra, self.ry, self.rb
        cl = []
        def ring(n, rad, dz, rc0, rc1, flat, tier, notch):
            m = n + 1 if notch else n
            az0 = math.pi / 2 + (2 * math.pi / m if notch else r.normal(0, 0.3))
            for k in range(n):
                az = az0 + k * 2 * math.pi / m + r.normal(0, 0.08)
                d = rad * r.uniform(0.94, 1.05)
                c = ce + np.array([math.cos(az) * ra * d, math.sin(az) * ry * d, dz * rb + r.normal(0, 0.03)])
                rc = r.uniform(rc0, rc1)
                cl.append(dict(c=c, rc=rc, rz=rc * flat, tier=tier, az=az))
        if self.shape == 0:
            # a dense round crown, a little wider than tall, the trunk showing in the front slot
            ring(6, 0.62, -0.42, 0.47, 0.53, 0.68, 0, True)
            ring(4, 0.35, 0.1, 0.5, 0.55, 0.7, 1, False)
            ring(2, 0.1, 0.52, 0.46, 0.5, 0.74, 2, False)
        else:
            # broad and low, the outer ring hanging lower where the fruit weighs the limbs down
            ring(7, 0.68, -0.48, 0.47, 0.54, 0.58, 0, True)
            ring(4, 0.36, 0.08, 0.53, 0.58, 0.62, 1, False)
            ring(2, 0.1, 0.48, 0.5, 0.54, 0.66, 2, False)
        for c in cl:
            c['lumps'] = [(nv(r.normal(0, 1, 3)), r.uniform(1.4, 2.4), r.uniform(0, 6.28), r.uniform(0.04, 0.07)) for _ in range(4)]
            c['tv'] = r.uniform(-0.03, 0.03)
        self.cl = cl

    def trad(self, z):
        return (0.1 if self.shape == 0 else 0.13) - 0.02 * z + 0.06 * math.exp(-max(0.0, z) / 0.11)

    def _prop(self, r):
        """a bamboo pole from the ground up under the heaviest front limb, its top cut in a fork that holds the limb"""
        T = self.T
        L = max((l for l in self.limbs), key=lambda l: l[0][-1][1] - abs(l[0][-1][0]) * 0.4)
        lp, lr = L
        top = lp[int(len(lp) * 0.62)] - UP * lr[int(len(lp) * 0.62)] * 0.9
        foot = np.array([top[0] * 1.25 + 0.05, top[1] * 1.2 + 0.12, 0.0])
        n = 10
        pts = [foot + (top - foot) * t for t in np.linspace(0, 1, n)]
        rads = [0.022] * n
        self._tube(pts, rads, top - TOCAM * 0.1 - UP * 0.2, fiss=0, r=r, col=T['bam']['mid'], lit=False)
        key, draw0 = self.items[-1]
        nodes = [foot + (top - foot) * t for t in (0.22, 0.5, 0.78)]
        def draw():
            pa = self.pa; P = pa.P
            draw0()
            d = np.array(P(top)) - np.array(P(foot)); d = d / np.linalg.norm(d); nm = np.array([-d[1], d[0]])
            sg = 1 if nm @ np.array(SLIGHT) < 0 else -1
            pa.line([tuple(np.array(P(q)) + nm * sg * 0.009 * pa.k) for q in pts], T['bam']['lit'], 0.012 * pa.k, 0.9)
            for q in nodes:
                a = np.array(P(q)); d = np.array(P(top)) - np.array(P(foot)); d = d / np.linalg.norm(d)
                nm = np.array([-d[1], d[0]]) * 0.024 * pa.k
                pa.line([tuple(a + nm), tuple(a - nm)], T['bam']['node'], pa.u(0.35))
            # the forked top
            a = np.array(P(top))
            pa.line([tuple(a + np.array([0, pa.u(0.6)])), tuple(a + np.array([-pa.u(1.0), -pa.u(0.4)]))], T['bam']['dk'], pa.u(0.55))
            pa.line([tuple(a + np.array([0, pa.u(0.6)])), tuple(a + np.array([pa.u(1.0), -pa.u(0.4)]))], T['bam']['dk'], pa.u(0.55))
        self.items[-1] = (key, draw)

    def _cluster(self, r, c, p, ns, hc, G, dark=False):
        """the pomelo's citrus leaves at orange size"""
        lv = Buoi._cluster(self, r, c, p, ns, hc, G, dark)
        # scale each leaf down about its base so the crown reads as the finer orange leaf
        for z in lv:
            b = z['rib'][0]
            z['poly'] = [b + (q - b) * 0.78 for q in z['poly']]
            z['mid'] = b + (z['mid'] - b) * 0.78
            z['rib'] = (b, b + (z['rib'][1] - b) * 0.78)
        return lv

    # ------------------------------------------------------------- fruit
    def _fruits(self, r, n, ripe):
        T = self.T
        F = (T['ripe0'] if self.shape == 0 else T['ripe1']) if ripe else T['raw']
        R0 = (0.084 if self.shape == 0 else 0.092) if ripe else 0.066
        spots = self._surface_spots(r, n + 8, -0.7, 0.55, -0.05, 0.36 if ripe else 0.4)
        got = 0
        self.fruit_at = []
        for (p, d, c) in spots:
            if got >= n: break
            ns = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            k = 1 if r.random() < 0.55 else 2 if r.random() < 0.7 else 3
            got += 1
            side = nv(np.cross(UP, ns)) if np.linalg.norm(np.cross(UP, ns)) > 1e-3 else np.array([1.0, 0, 0])
            for j in range(k):
                R = R0 * r.uniform(0.9, 1.08)
                off = side * R * 1.7 * (j - (k - 1) / 2) - UP * R * 0.3 * (j % 2)
                s0 = p + ns * 0.02
                top = s0 + ns * R * 0.5 - UP * r.uniform(0.02, 0.05) + off
                cen = top - UP * R * 0.95
                if cen[2] - R < 0.1: continue
                self.fruit_at.append(np.array(self.pa.P(cen)) / self.pa.k)
                self.items.append((cen + TOCAM * 0.3 + UP * 0.01 * j,
                                   self._orange_draw(s0, top, cen, R, F, np.random.default_rng(int(r.integers(1, 1 << 30))))))

    def _orange_draw(self, s0, top, cen, R, F, rr):
        T = self.T
        dots = [(rr.uniform(-1, 1), rr.uniform(-1, 1)) for _ in range(26 if F['sh'] is not None else 16)]
        ph = rr.uniform(0, 6.28)
        def draw():
            pa = self.pa; P = pa.P; cx = pa.ctx; k = pa.k
            cx.new_path(); cx.move_to(*P(s0)); cx.line_to(*P(top + UP * R * 0.2))
            cx.set_source_rgb(*T['stalk']); cx.set_line_width(pa.u(0.4)); cx.set_line_cap(cairo.LINE_CAP_ROUND); cx.stroke()
            c2 = np.array(P(cen)); Ws = R * k; Hs = R * k * 0.95
            body = [tuple(c2 + np.array([math.cos(t) * Ws * (1 + 0.015 * math.sin(4 * t + ph)), math.sin(t) * Hs]))
                    for t in np.linspace(0, 2 * math.pi, 44, endpoint=False)]
            pa.fill(body, F['body'])
            cx.save(); pa.path(body); cx.clip()
            sl = np.array(SLIGHT)
            cx.new_path(); pa.path(body); cx.set_source_rgb(*F['dk']); cx.fill()
            cx.new_path(); cx.arc(*(c2 - sl * Ws * 0.16), Ws * 0.9, 0, 2 * math.pi); cx.set_source_rgb(*F['body']); cx.fill()
            if F['sh'] is not None:
                # cam sành: the shoulders round the stalk stay green
                cx.save(); cx.translate(*(c2 - np.array([0, Hs * 0.95]))); cx.scale(Ws * 0.85, Hs * 0.5)
                cx.new_path(); cx.arc(0, 0, 1, 0, 2 * math.pi); cx.restore(); cx.set_source_rgba(*F['sh'], 0.8); cx.fill()
            cx.new_path(); cx.arc(*(c2 - sl * Ws * 0.36), Ws * 0.46, 0, 2 * math.pi); cx.set_source_rgba(*F['lit'], 0.9); cx.fill()
            for (u, v) in dots:
                if u * u + v * v > 0.8: continue
                q = c2 + np.array([u * Ws * 0.9, v * Hs * 0.9])
                lit = -((q - c2) @ sl) / (Ws + 1e-6)
                cx.new_path(); cx.arc(q[0], q[1], pa.u(0.2 if F['sh'] is not None else 0.16), 0, 2 * math.pi)
                cx.set_source_rgba(*(F['dot_hi'] if lit > 0.15 else F['dot']), 0.55); cx.fill()
            hc = c2 - sl * Ws * 0.5
            cx.save(); cx.translate(*hc); cx.rotate(-0.6); cx.scale(Ws * 0.2, Ws * 0.12)
            cx.new_path(); cx.arc(0, 0, 1, 0, 2 * math.pi); cx.restore(); cx.set_source_rgba(*F['hi'], 0.7); cx.fill()
            cx.restore()
            pa.soft_edge(body, F['body'])
            # the little green star of the calyx under the stalk
            tp = c2 - np.array([0.0, Hs * 0.8])
            cx.new_path(); cx.arc(tp[0], tp[1], max(pa.u(0.35), Ws * 0.16), 0, 2 * math.pi); cx.set_source_rgb(*T['stalk']); cx.fill()
        return draw

    def _flowers(self, r, n):
        """small sprays of white five-petal flowers with yellow hearts at the twig ends"""
        T = self.T
        for (p, d, c) in self._surface_spots(r, n, -0.3, 0.8, -0.1, 0.38):
            if any(np.linalg.norm(np.array(self.pa.P(p)) / self.pa.k - f) < 0.22 for f in self.fruit_at): continue
            ns = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
            pts = [p + ns * 0.04 + nv(r.normal(0, 1, 3)) * 0.045 for _ in range(int(r.integers(3, 6)))]
            def draw(pts=pts):
                pa = self.pa; P = pa.P; cx = pa.ctx
                for q in sorted(pts, key=depth):
                    x, y = P(q); R = 0.022 * pa.k
                    for j in range(5):
                        a = j * 2 * math.pi / 5 + 0.3
                        cx.new_path(); cx.arc(x + math.cos(a) * R * 0.6, y + math.sin(a) * R * 0.5, R * 0.5, 0, 2 * math.pi)
                        cx.set_source_rgb(*T['fl'][0 if math.sin(a) < 0.3 else 1]); cx.fill()
                    cx.new_path(); cx.arc(x, y, R * 0.3, 0, 2 * math.pi); cx.set_source_rgb(*T['fl_c']); cx.fill()
            self.items.append((p + TOCAM * 0.35, draw))


FRAMES = [dict(key='00', shape=0, ripe=0), dict(key='01', shape=0, ripe=1), dict(key='10', shape=1, ripe=0), dict(key='11', shape=1, ripe=1)]
BB = (-66, -100, 66, 25)


def render(fr, night=False, bb=BB):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    Cam(fr['shape'], fr['ripe'], pa).paint()
    surf.flush(); ch.NIGHT = False
    return surf, bb


def atlas(outdir, tabpath):
    import saurieng as sr
    sr.render = render; sr.FRAMES = FRAMES
    return sr.atlas(outdir, tabpath, name='k2_cam.webp')


if __name__ == '__main__':
    sys.path.insert(0, os.path.join(here, '..', 'saurieng'))
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
        sheet.save('/tmp/claude-0/g/cam_%s.png' % tag); print(sheet.size)
