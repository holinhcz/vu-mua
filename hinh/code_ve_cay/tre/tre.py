# Bamboo clumps (bụi tre gai) for Nông Trại Nhỏ, built as small 3D models and painted in flat game tones with
# outlines, the same camera, sun and night transform as the banana kit (../chuoi).
# A clump: many culms (cây tre) from a tight base, leaning out and arching over at the top, with node rings,
# papery culm sheaths (mo tre) low down, thorny twigs at the foot, branch whorls from the middle up carrying
# drooping sprays of narrow leaves, a couple of shoots (măng) and dry leaves on the ground.
import math, os, sys
import numpy as np, cairo
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'chuoi'))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM as TOC

RS, SS = 9, 2
PX = RS * SS
KU = 29.0
UP = np.array([0, 0, 1.0])


def leaf_tones():
    # v620 (critique 6): the ramp is pulled onto the greens of the game's own trees, no near-black green
    return dict(ramp=[C('#367f31'), C('#46923a'), C('#58a63e'), C('#70b94b'), C('#86c656')], out=C('#1f4d18'),
                dry=[C('#b99a55'), C('#d8bd72')], dry_out=C('#6b5124'))


def culm_tones(old):
    if old:
        return dict(lit=C('#e2d272'), mid=C('#c4b04c'), dk=C('#927f32'), ring=C('#efe3a0'), node=C('#5e5220'), out=C('#4d4318'))
    return dict(lit=C('#bcd767'), mid=C('#94b847'), dk=C('#688d34'), ring=C('#dbeba0'), node=C('#3f5a1c'), out=C('#2f4a16'))


class Clump:
    def __init__(self, seed, pa):
        self.pa = pa
        r = self.rng = np.random.default_rng(seed * 131 + 7)
        self.items = []
        n = int(r.integers(14, 19))
        self.H = 0
        culms = []
        for k in range(n):
            a = r.uniform(0, 2 * math.pi); d = 0.36 * math.sqrt(r.random())
            bx, by = math.cos(a) * d, math.sin(a) * d
            out_a = a + r.normal(0, 0.35)
            # outer culms lean more; the tallest stand near the middle
            lean = 0.05 + 0.4 * d / 0.36 + r.uniform(0, 0.1)
            H = r.uniform(3.8, 4.7) * (1.0 - 0.15 * d / 0.36)
            rad = r.uniform(0.046, 0.064)
            old = r.random() < 0.12
            young = (not old) and r.random() < 0.2
            culms.append(dict(b=(bx, by), out=out_a, lean=lean, H=H, rad=rad, old=old, young=young))
        self.culms = culms
        self.lt = leaf_tones()
        for c in culms: self._culm(c)
        self._foot()

    # ------------------------------------------------------------- culm centre line
    def _line(self, c, m=60):
        r = self.rng
        A = np.array([math.cos(c['out']), math.sin(c['out']), 0.0])
        pts = [np.array([c['b'][0], c['b'][1], 0.0])]; dirs = []
        L = c['H'] * 1.12
        e0 = math.pi / 2 - c['lean'] * 0.3
        for k in range(m):
            s = k / m
            e = e0 - c['lean'] * 1.5 * s ** 2.0 - c['lean'] * 6.0 * max(0, s - 0.68) ** 2
            d = A * math.cos(e) + UP * math.sin(e)
            dirs.append(d); pts.append(pts[-1] + d * L / m)
        dirs.append(dirs[-1])
        return np.array(pts), np.array(dirs), A

    def _culm(self, c):
        r = self.rng; pa = self.pa
        P3, D3, A = self._line(c)
        m = len(P3) - 1
        tones = culm_tones(c['old'])
        # node positions: internodes lengthen up the culm, shorten again near the top
        nodes = [0.0]; s = 0.0
        while True:
            seg = 0.045 + 0.06 * math.sin(math.pi * min(1, s * 1.1)) + r.uniform(-0.006, 0.006)
            s += seg
            if s >= 0.995: break
            nodes.append(s)
        nodes.append(1.0)
        rad = lambda s: c['rad'] * (1.0 - 0.75 * s ** 1.3) + 0.004
        at = lambda s: P3[min(m, int(round(s * m)))]
        # internodes as separate items so leaves can sit in front of and behind them
        for j in range(len(nodes) - 1):
            s0, s1 = nodes[j], nodes[j + 1]
            ss = np.linspace(s0, s1, 4)
            pts3 = [at(x) for x in ss]
            sheath = (s0 < 0.16 and (c['young'] or r.random() < 0.2)) and not c['old']
            # v621 (critique 5, "culms stick through the canopy like skewers"): up in the canopy the culm is shaded by
            # the leaves (its colours pulled toward the leaf green) and sorts a little behind the sprays around it
            sm = (s0 + s1) / 2; k = max(0.0, min(0.55, (sm - 0.42) * 1.3))
            tn = {kk: mixc(vv, self.lt['ramp'][1], k) for kk, vv in tones.items()} if k > 0 else tones
            key = (pts3[0] + pts3[-1]) / 2 - TOC * (0.18 * k / 0.55)
            self.items.append((key, self._seg_draw(pts3, [rad(x) for x in ss], tn, sheath, j > 0)))
        # branch whorls on the upper culm, each carrying sprays of leaves
        first = 0.5 + r.uniform(0, 0.08)
        bn = [x for x in nodes if first < x < 0.97]
        for j, sn in enumerate(bn):
            base = at(sn)
            nb = 1 if sn < 0.7 else 2
            for b in range(nb):
                side = (1 if (j + b) % 2 else -1)
                # branch heads out and away from the clump centre, sideways off the culm, then droops
                Bp = nv(np.cross(A, UP)) * side
                out = nv(A * 1.0 + Bp * 0.55 + UP * r.uniform(0.0, 0.4))
                Lb = r.uniform(0.36, 0.66) * (0.55 + 0.6 * (1 - abs(sn - 0.72)))
                mid = base + out * Lb * 0.5 + UP * 0.05
                tip = base + out * Lb - UP * 0.12
                tw = {kk: mixc(vv, self.lt['ramp'][1], 0.4) for kk, vv in tones.items()}
                self.items.append(((base + tip) / 2 - TOC * 0.1, self._twig_draw([base, mid, tip], tw)))
                ns = int(r.integers(1, 3)) if sn < 0.72 else int(r.integers(2, 4))
                for q in range(ns):
                    t = 0.3 + 0.7 * (q + r.uniform(0, 0.5)) / ns
                    sp_at = (1 - t) ** 2 * base + 2 * (1 - t) * t * mid + t * t * tip
                    self._spray(sp_at, nv(out + Bp * r.normal(0, 0.5) + r.normal(0, 0.2, 3) * np.array([1, 1, 0.3])), c, sn)
        # feathery tip: sprays along the last stretch of the culm
        for q in range(7):
            t = 0.78 + 0.21 * q / 6
            self._spray(at(t), nv(D3[int(t * m)] + r.normal(0, 0.45, 3)), c, 1.0)

    def _seg_draw(self, pts3, rads, tones, sheath, node):
        pa = self.pa
        def draw():
            P = pa.P
            pts = np.array([P(q) for q in pts3])
            n = len(pts)
            Lp, Rp, Cn = [], [], []
            for i in range(n):
                a = pts[max(0, i - 1)]; b = pts[min(n - 1, i + 1)]
                d = nv(b - a); nrm = np.array([-d[1], d[0]])
                w = rads[i] * pa.k
                Lp.append(pts[i] + nrm * w); Rp.append(pts[i] - nrm * w); Cn.append((pts[i], nrm, w))
            litL = (Cn[0][1] @ SLIGHT) > 0
            body = [tuple(q) for q in Lp] + [tuple(q) for q in Rp[::-1]]
            pa.fill(body, tones['mid'])
            # lit stripe and shade stripe
            lit = [tuple(p + nr * w * (1 if litL else -1) * f) for f in (0.95, 0.15) for (p, nr, w) in (Cn if f == 0.95 else Cn[::-1])]
            pa.fill(lit, tones['lit'], seam=False)
            sh = [tuple(p - nr * w * (1 if litL else -1) * f) for f in (0.95, 0.45) for (p, nr, w) in (Cn if f == 0.95 else Cn[::-1])]
            pa.fill(sh, tones['dk'], seam=False)
            if sheath:
                # papery culm sheath wrapped round the lower internode, ragged top
                k = max(2, int(n * 0.8))
                sp = [tuple(p + nr * w * 1.18) for (p, nr, w) in Cn[:k]] + [tuple(Cn[k - 1][0] + (Cn[k - 1][0] - Cn[0][0]) * 0.18)] + [tuple(p - nr * w * 1.18) for (p, nr, w) in Cn[:k]][::-1]
                pa.fill(sp, C('#b39a6c'))
                pa.line([tuple(Cn[0][0]), tuple(Cn[k - 1][0])], C('#8e6c3a'), pa.u(0.25), 0.9)
                if ch.EDGE: pa.path(sp); pa.ctx.set_source_rgb(*C('#5a3f1e')); pa.ctx.set_line_width(pa.u(0.32)); pa.ctx.stroke()
                pa.soft_edge(sp, C('#b39a6c'))
            if ch.EDGE:
                pa.line([tuple(q) for q in Lp], tones['out'], pa.u(0.36))
                pa.line([tuple(q) for q in Rp], tones['out'], pa.u(0.36))
            pa.soft_edge([tuple(q) for q in Lp], tones['mid'], close=False)
            pa.soft_edge([tuple(q) for q in Rp], tones['mid'], close=False)
            if node:
                p, nr, w = Cn[0]
                d = nv(pts[1] - pts[0])
                # node: a pale ring with a dark joint line just below it
                a1, b1 = p + nr * w * 1.12, p - nr * w * 1.12
                pa.line([tuple(a1 - d * pa.u(0.25)), tuple(b1 - d * pa.u(0.25))], tones['node'], pa.u(0.34))
                pa.line([tuple(a1 + d * pa.u(0.15)), tuple(b1 + d * pa.u(0.15))], mixc(tones['ring'], tones['mid'], 0.35), pa.u(0.34))
        return draw

    def _twig_draw(self, pts3, tones):
        pa = self.pa
        def draw():
            pp = [pa.P(q) for q in pts3]
            if ch.EDGE:
                pa.line(pp, tones['out'], pa.u(0.62))
                pa.line(pp, mixc(tones['dk'], tones['mid'], 0.4), pa.u(0.32))
            else:                       # no dark casing: the twig alone, a little wider so it still shows
                pa.line(pp, mixc(tones['dk'], tones['mid'], 0.4), pa.u(0.46))
        return draw

    # ------------------------------------------------------------- leaves
    def _spray(self, at, d, c, sn):
        """a twig end with 4-8 narrow leaves fanned out and hanging; drawn as one cluster with its own outline"""
        r = self.rng
        nl = int(r.integers(4, 7))
        horiz = nv(np.array([d[0], d[1], 0.0]) + 1e-6)
        side = nv(np.cross(horiz, UP))
        leaves = []
        for k in range(nl):
            f = (k - (nl - 1) / 2) / max(1, (nl - 1) / 2)
            ang = f * 0.9 + r.normal(0, 0.12)
            droop = r.uniform(0.6, 1.3)
            dirv = nv(horiz * math.cos(ang) + side * math.sin(ang) - UP * droop + d * 0.3)
            L = r.uniform(0.3, 0.4); W = L * r.uniform(0.17, 0.21)
            b0 = at + d * 0.035 * k + r.normal(0, 0.012, 3)
            sv = nv(np.cross(dirv, UP)) if abs(dirv[2]) < 0.97 else side
            # leaf plane tilts so some leaves show their face, some their edge
            tilt = r.uniform(-0.6, 0.6)
            wv = nv(sv * math.cos(tilt) + UP * math.sin(tilt))
            nrm = nv(np.cross(dirv, wv))
            if nrm @ np.array([0, 0.87, 0.5]) < 0: nrm = -nrm
            lam = float(nrm @ LIGHT)
            pts = []
            prof = [(0.0, 0.25), (0.12, 0.85), (0.3, 1.0), (0.55, 0.8), (0.8, 0.4), (1.0, 0.0)]
            for t, w in prof:
                q = b0 + dirv * L * t - UP * L * 0.25 * t * t
                pts.append((q + wv * W * w * 0.5, q - wv * W * w * 0.5))
            leaves.append((pts, lam))
        # how deep inside the canopy this spray is: inner and low sprays darker
        rr = math.hypot(at[0], at[1])
        hf = at[2] / 5.0
        side = (at[0] * LIGHT[0] + at[1] * LIGHT[1]) / max(0.3, rr)      # sprays on the sunny side of the clump
        # v621 (critique 4, "one flat green"): a wider spread again, within the game's greens: high, outer, sunny
        # sprays light, inner and low ones darker
        ao = min(1.08, 0.5 + 0.24 * min(1.0, rr / 1.1) + 0.3 * hf + 0.1 * side)
        yellow = c['old'] and r.random() < 0.04
        lt = self.lt
        def draw(leaves=leaves, ao=ao, yellow=yellow):
            pa = self.pa; P = pa.P
            polys = []
            for pts, lam in leaves:
                Lh = [P(a) for a, b in pts]; Rh = [P(b) for a, b in pts]
                polys.append((Lh + Rh[::-1][1:], lam))
            # outline pass for the whole spray (when edges are on), then fills
            for poly, lam in (polys if ch.EDGE else []):
                pa.path(poly); pa.ctx.set_source_rgb(*(lt['dry_out'] if yellow else lt['out']))
                pa.ctx.set_line_width(pa.u(0.44)); pa.ctx.set_line_join(cairo.LINE_JOIN_ROUND); pa.ctx.stroke()
            def tone(v):
                if yellow: return lt['dry'][1] if v > 0.55 else lt['dry'][0]
                return lt['ramp'][0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4]
            vs = [(0.55 + 0.45 * max(-0.2, lam)) * ao - (0 if ch.EDGE else 0.1) for poly, lam in polys]
            vm = float(np.mean(vs)) if vs else 0.6
            if ch.SOFT and not ch.EDGE:
                # v620 (critique 5): one cluster = one shape. Leaves keep only a little of their own light, and the
                # thin edge runs round the whole spray (stroked first, the fills cover its inner half)
                vs = [0.7 * vm + 0.3 * v for v in vs]
                ec = ch.soft(tone(vm))
                for poly, lam in polys:
                    pa.path(poly); pa.ctx.set_source_rgb(*ec); pa.ctx.set_line_width(pa.u(2 * ch.SOFT_W))
                    pa.ctx.set_line_join(cairo.LINE_JOIN_ROUND); pa.ctx.stroke()
            for (poly, lam), v in zip(polys, vs):
                pa.fill(poly, tone(v), grow=0.0 if (ch.EDGE or ch.SOFT) else pa.u(0.44))
        self.items.append((at + np.array([0, 0.0005, 0]), draw))

    # ------------------------------------------------------------- foot of the clump
    def _foot(self):
        r = self.rng; pa = self.pa
        # thorny twigs (tre gai) tangled round the foot
        for k in range(int(r.integers(7, 12))):
            a = r.uniform(0, 2 * math.pi); d0 = r.uniform(0.1, 0.28)
            p0 = np.array([math.cos(a) * d0, math.sin(a) * d0, r.uniform(0.05, 0.7)])
            dirv = nv(np.array([math.cos(a), math.sin(a), r.uniform(0.2, 0.9)]))
            L = r.uniform(0.16, 0.32)
            pts = [p0 + dirv * L * t + np.array([0, 0, -0.05 * t * t]) for t in np.linspace(0, 1, 4)]
            spikes = []
            for t in np.linspace(0.2, 0.9, 4):
                q = p0 + dirv * L * t
                sd = nv(np.cross(dirv, UP)) * (1 if r.random() < 0.5 else -1)
                spikes.append((q, q + sd * 0.06 + UP * 0.03))
            def draw(pts=pts, spikes=spikes):
                P = pa.P
                if ch.EDGE:
                    pa.line([P(q) for q in pts], C('#3e2f16'), pa.u(0.75))
                    pa.line([P(q) for q in pts], C('#7a6234'), pa.u(0.38))
                else:
                    pa.line([P(q) for q in pts], C('#5e4a26'), pa.u(0.55))
                for a, b in spikes: pa.line([P(a), P(b)], C('#4a3a1c'), pa.u(0.3))
            self.items.append((pts[1], draw))
        # bamboo shoots (măng) poking up beside the clump
        for k in range(int(r.integers(0, 3))):
            a = r.uniform(-0.3, math.pi + 0.3); d0 = r.uniform(0.45, 0.62)
            b = np.array([math.cos(a) * d0, math.sin(a) * d0, 0.0])
            h = r.uniform(0.22, 0.4); w = h * 0.24
            def draw(b=b, h=h, w=w):
                P = pa.P
                base = np.array(P(b)); top = np.array(P(b + UP * h)); ww = w * pa.k
                # v620 (critique 7, "stacked brown arrowheads"): a plump cone wrapped in overlapping sheath scales,
                # each scale a curved pointed sheet from one side, lower ones darker; a dark little tip on top
                ax = top - base
                def at(t, x):                       # point at height t, x in -1..1 across the cone
                    f = 1.0 - 0.15 * t - 0.85 * t ** 1.6
                    return base + ax * t + np.array([ww * 1.3 * f * x, ww * 0.18 * (1 - x * x) * f])
                body = [tuple(at(t, -1)) for t in np.linspace(0, 1, 9)] + [tuple(at(t, 1)) for t in np.linspace(1, 0, 9)][1:]
                pa.fill(body, C('#8c6a3c'))
                # top scale first: the older, lower sheaths wrap over the younger ones, so each shows its pointed top
                # on alternating sides, with a slanting lower edge
                scales = [(0.52, 1.0, 1, '#c49d63'), (0.34, 0.86, -1, '#b48c55'), (0.16, 0.7, 1, '#a5804a'), (0.0, 0.52, -1, '#957040')]
                for t0, t1, sd, colh in scales:
                    up = [tuple(at(t, sd)) for t in np.linspace(t0, t1 - 0.04, 6)] + [tuple(at(t1, sd * 0.2))]
                    down = [tuple(at(t, -sd)) for t in np.linspace(min(t1 - 0.12, t0 + 0.22), t0 + 0.2, 2)]
                    sc = up + down
                    pa.fill(sc, C(colh))
                    pa.soft_edge(sc, C(colh))
                pa.fill([tuple(at(0.86, -0.35)), tuple(at(1.0, 0)), tuple(at(0.86, 0.35))], C('#5a3c22'), seam=True)
                if ch.EDGE: pa.path(body); pa.ctx.set_source_rgb(*C('#4f3618')); pa.ctx.set_line_width(pa.u(0.4)); pa.ctx.stroke()
                pa.soft_edge(body, C('#8c6a3c'))
            self.items.append((b + np.array([0, 0, h / 2]), draw))
        # dry leaves on the ground
        lt = self.lt
        for k in range(int(r.integers(10, 16))):
            a = r.uniform(0, 2 * math.pi); d0 = r.uniform(0.3, 0.85)
            p = np.array([math.cos(a) * d0, math.sin(a) * d0, 0.0]); ang = r.uniform(0, math.pi)
            L = r.uniform(0.12, 0.18)
            dv = np.array([math.cos(ang), math.sin(ang), 0]); sv = np.array([-math.sin(ang), math.cos(ang), 0])
            pts = [p + dv * L * t + sv * L * 0.08 * w for t, w in [(0, 0), (0.3, 1), (1, 0), (0.3, -1)]]
            col = lt['dry'][int(r.integers(0, 2))]
            def draw(pts=pts, col=col):
                pp = [pa.P(q) for q in pts]
                pa.path(pp)
                if ch.EDGE: pa.ctx.set_source_rgb(*lt['dry_out']); pa.ctx.set_line_width(pa.u(0.3)); pa.ctx.stroke_preserve()
                pa.ctx.set_source_rgb(*col); pa.ctx.fill()
                pa.soft_edge(pp, col)
            self.items.append((p + np.array([0, 0, -5.0]), draw))   # always first

    def paint(self):
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()


def render(seed, night=False, bb=(-90, -190, 90, 30)):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    Clump(seed, pa).paint()
    surf.flush(); ch.NIGHT = False
    return surf, bb


def to_image(surf):
    w, h = surf.get_width(), surf.get_height()
    a = np.ndarray((h, w, 4), np.uint8, surf.get_data()).copy()
    im = Image.frombuffer('RGBa', (w, h), a[:, :, [2, 1, 0, 3]].tobytes(), 'raw', 'RGBa', 0, 1)
    return im.resize((w // SS, h // SS), Image.LANCZOS).convert('RGBA')


if __name__ == '__main__' and len(sys.argv) > 2 and sys.argv[1] == 'atlas':
    pass
elif __name__ == '__main__':
    ims = [to_image(render(s)[0]) for s in range(4)]
    w = sum(i.width for i in ims); h = ims[0].height
    sheet = Image.new('RGBA', (w, h), (155, 191, 106, 255)); x = 0
    for k, im in enumerate(ims):
        im.save('/tmp/claude-0/g/tre_%d.png' % k); sheet.alpha_composite(im, (x, 0)); x += im.width
    sheet.save('/tmp/claude-0/g/tre_prev.png'); print(sheet.size)


def atlas(outdir, tabpath):
    """4 clumps, day and night, cropped and packed into one webp; writes the frame table json"""
    import json
    crops = []
    for night in (False, True):
        for s in range(4):
            surf, bb = render(s, night)
            im = to_image(surf)
            a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            crops.append(('nd'[not night] + str(s), im.crop((x0, y0, x1, y1)), bb[0] + x0 / RS, bb[1] + y0 / RS))
    cols = 4; x = y = rowh = 0; pos = {}
    for k, (name, im, dx, dy) in enumerate(crops):
        if k and k % cols == 0: x = 0; y += rowh + 2; rowh = 0
        pos[name] = (x, y); x += im.width + 2; rowh = max(rowh, im.height)
    Wt = max(pos[n][0] + im.width for n, im, _, _ in crops); Ht = y + rowh
    sheet = Image.new('RGBA', (Wt, Ht), (0, 0, 0, 0)); table = {}
    for name, im, dx, dy in crops:
        sx, sy = pos[name]; sheet.paste(im, (sx, sy))
        table[name] = [sx, sy, im.width, im.height, round(dx, 2), round(dy, 2), round(im.width / RS, 2), round(im.height / RS, 2)]
    path = os.path.join(outdir, 'tre.webp')
    sheet.save(path, 'WEBP', quality=92, alpha_quality=100, method=6)
    open(tabpath, 'w').write(json.dumps(table, separators=(',', ':')))
    print(sheet.size, os.path.getsize(path))
    return table


if __name__ == '__main__' and len(sys.argv) > 2 and sys.argv[1] == 'atlas':
    atlas(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else 'atlas.json')
