# Bougainvillea bushes (bông giấy / hoa giấy) for Nông Trại Nhỏ, built as small 3D models and painted in flat game
# tones with the thin same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun and night.
# A bush: a short twisted woody trunk of three stems, a lumpy dome of small green leaves (a dark inner mass behind them),
# big masses of papery three-bract clusters over the top and front (each with tiny cream flowers in the middle), a few
# long arching canes drooping out of the sides with bracts along them, and a few fallen bracts on the ground.
# Four colours like the game had: 0 magenta, 1 pink, 2 orange, 3 white.
import math, os, sys
import numpy as np, cairo
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'chuoi'))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'dambut'))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM
from dambut import hull

RS, SS = 9, 2
PX = RS * SS
KU = 29.0 * 0.82          # a size close to the old bush, so it does not cover what stands behind it
UP = np.array([0, 0, 1.0])

BRACT = [  # dark, mid, lit, high
    ['#9c1258', '#c81a73', '#e43a92', '#f46cb0'],
    ['#c43a86', '#e2589f', '#f37cb6', '#ffa6d2'],
    ['#c4520e', '#ea6e16', '#fa9128', '#ffbc5a'],
    ['#c9c0cc', '#e6e0e8', '#f7f3f8', '#ffffff'],
]
VEIN = ['#8a0e4c', '#b03278', '#b0460c', '#bdb2c2']


def tones(col):
    return dict(
        green=[C('#1f5326'), C('#2b6c2e'), C('#3a873a'), C('#52a146'), C('#6eb956')],
        und=[C('#3e6c35'), C('#4f8041'), C('#62964d')],
        inner=C('#1b4521'),
        stem=dict(lit=C('#a68b6c'), mid=C('#7e6650'), dk=C('#5a4838')),
        bract=[C(h) for h in BRACT[col]], vein=C(VEIN[col]),
        flower=C('#fbf4dc'), fleye=C('#e8c24a'),
    )


class Bonggiay:
    """seed picks the shape; col the bract colour (0 magenta, 1 pink, 2 orange, 3 white)"""
    def __init__(self, seed, pa, col=None):
        self.pa = pa; self.seed = seed
        r = self.rng = np.random.default_rng(seed * 4793 + 57)
        self.items = []
        self.col = seed % 4 if col is None else col
        self.T = tones(self.col)
        q = seed % 4
        self.ra = [0.98, 0.92, 1.04, 0.95][q]
        self.ry = self.ra * [0.92, 1.0, 0.9, 0.96][q]
        self.rb = [0.74, 0.8, 0.7, 0.78][q]
        self.ce = np.array([[0.03, 0.0], [-0.04, 0.02], [0.02, -0.03], [0.0, 0.02]][q] + [0.66 + self.rb * 0.86])
        self.lumps = [(nv(r.normal(0, 1, 3)), r.uniform(1.6, 2.6), r.uniform(0, 6.28), r.uniform(0.05, 0.09)) for _ in range(5)]
        self._fallen(r)
        self._trunk(r)
        self._mass()
        self._crown(r)
        self._canes(r)

    def lump(self, d):
        return 1.0 + sum(a * math.cos(fr * (d @ kk) * math.pi + ph) for kk, fr, ph, a in self.lumps)

    def env(self, d, f=1.0):
        return self.ce + np.array([d[0] * self.ra, d[1] * self.ry, d[2] * self.rb]) * f * self.lump(d)

    def norm_at(self, p):
        return nv((p - self.ce) / np.array([self.ra, self.ry, self.rb]) ** 2)

    # ------------------------------------------------------------- wood
    def _woody(self, pts, w0, w1, key):
        pa = self.pa; T = self.T
        def draw(pts=pts):
            P = pa.P; S = T['stem']
            sp = [P(q) for q in pts]
            pa.taper(sp, w0 * 2 * pa.k, w1 * 2 * pa.k, S['mid'], outline=S['mid'])
            arr = np.array(sp); lit = []
            for i in range(len(arr)):
                a = arr[max(0, i - 1)]; b = arr[min(len(arr) - 1, i + 1)]
                dd = nv(b - a); nr = np.array([-dd[1], dd[0]])
                if nr @ SLIGHT < 0: nr = -nr
                w = w0 + (w1 - w0) * i / (len(arr) - 1)
                lit.append(tuple(arr[i] + nr * w * pa.k * 0.45))
            pa.line(lit, S['lit'], max(pa.u(0.3), w0 * 0.5 * pa.k), 0.8)
        self.items.append((key, draw))

    def _trunk(self, r):
        """three stems twisting round each other out of one foot, then splaying into the crown"""
        az0 = r.uniform(0, 2 * math.pi)
        for k in range(3):
            ph = az0 + k * 2.09
            pts = []
            for j in range(11):
                t = j / 10
                z = t * (0.66 + self.rb * 0.5)
                tw = ph + t * 2.4                                        # the twist
                rr = 0.035 + 0.02 * math.sin(t * math.pi) + t * t * 0.32  # splays out at the top
                pts.append(np.array([math.cos(tw) * rr + self.ce[0] * t, math.sin(tw) * rr * 0.9 + self.ce[1] * t, z]))
            self._woody(pts, 0.052, 0.028, pts[0] - TOCAM * 3.0 + np.array([math.cos(ph), math.sin(ph), 0]) * 0.02)

    def _mass(self):
        pa = self.pa; T = self.T
        pts = []
        for th in np.linspace(0, math.pi, 25):
            for ph in np.linspace(0, 2 * math.pi, 37):
                d = np.array([math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)])
                if d[2] < -0.5: continue
                pts.append(self.env(d, 0.84))
        def draw():
            pa.fill(hull([pa.P(p) for p in pts]), T['inner'])
        self.items.append((self.ce - TOCAM * 2.0, draw))

    # ------------------------------------------------------------- crown
    def _crown(self, r):
        n = 140; ga = math.pi * (3 - math.sqrt(5))
        spots = []
        for i in range(n):
            zz = 1 - 2 * (i + 0.5) / n; rr = math.sqrt(max(0.0, 1 - zz * zz))
            if zz < -0.52: continue
            d = np.array([rr * math.cos(i * ga), rr * math.sin(i * ga), zz])
            spots.append((d, r.uniform(0.93, 1.03) if i % 4 else r.uniform(0.8, 0.9)))
        # the blooms: big masses over the top and the front, a few low and at the back
        bloom = []
        for d, f in spots:
            p = self.env(d, f)
            n0 = self.norm_at(p)
            w = 0.5 + 0.35 * d[2] + 0.3 * max(0.0, n0 @ TOCAM)
            bloom.append(r.random() < w and f > 0.9)
        for (d, f), b in zip(spots, bloom):
            p = self.env(d, f)
            self._leaves(r, p, n=int(r.integers(3, 5)) if b else int(r.integers(4, 7)))
            if b: self._bloom(r, self.env(d, f * 1.04), int(r.integers(6, 10)), 0.17)

    def _leaves(self, r, c, n):
        T = self.T; pa = self.pa
        ns = self.norm_at(c)
        nrm0 = nv(ns + UP * 0.9)
        t1 = np.cross(nrm0, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(nrm0, t1)
        hc = (c[2] - self.ce[2]) / self.rb
        sun = float(ns @ LIGHT)
        ao = 0.78 + 0.22 * max(-1.0, min(1.0, hc + 0.1))
        if math.dist(c, self.ce) < 0.88 * min(self.ra, self.rb * 1.3): ao -= 0.12
        az0 = r.uniform(0, 2 * math.pi)
        leaves = []
        for k in range(n):
            az = az0 + k * 2 * math.pi / n + r.normal(0, 0.3)
            A = math.cos(az) * t1 + math.sin(az) * t2
            el = r.uniform(0.05, 0.5)
            ld = nv(A * math.cos(el) + nrm0 * math.sin(el) - UP * 0.15)
            sd = nv(np.cross(nrm0, ld))
            Ll = 0.2 * r.uniform(0.85, 1.12); Wl = Ll * 0.66
            # heart-ovate with a drawn-out tip
            prof = [(0.0, 0.3), (0.06, 0.75), (0.2, 1.0), (0.38, 0.95), (0.58, 0.72), (0.78, 0.42), (0.92, 0.16), (1.0, 0.0)]
            pt = c + ld * 0.02
            Lp_, Rp_ = [], []
            for (t, w) in prof:
                q = pt + ld * Ll * t - UP * Ll * 0.14 * t * t
                Lp_.append(q + sd * Wl * 0.5 * w); Rp_.append(q - sd * Wl * 0.5 * w)
            poly = Lp_ + Rp_[::-1]
            nn = nv(np.cross(ld, sd))
            if nn @ nrm0 < 0: nn = -nn
            topv = nn @ TOCAM > 0
            lam = float((nn if topv else -nn) @ LIGHT)
            v = (0.55 + 0.45 * max(-0.3, lam)) * ao + 0.13 * sun - 0.05
            leaves.append(dict(poly=poly, top=topv, v=v, mid=pt + ld * Ll * 0.5, rib=(pt, pt + ld * Ll * 0.85 - UP * Ll * 0.1)))
        vm = float(np.mean([z['v'] for z in leaves]))
        for z in leaves: z['v'] = 0.55 * vm + 0.45 * z['v']
        leaves.sort(key=lambda z: depth(z['mid']))
        def col_of(z):
            v = z['v']
            if not z['top']: return T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            return T['green'][0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4]
        cols = [col_of(z) for z in leaves]
        def draw(leaves=leaves, cols=cols):
            P = pa.P
            for z, col in zip(leaves, cols):
                poly = [P(q) for q in z['poly']]
                pa.fill(poly, col); pa.soft_edge(poly, col)
                pa.line([P(z['rib'][0]), P(z['rib'][1])], mixc(col, C('#d8e6a0'), 0.3), pa.u(0.2), 0.7)
        self.items.append((c, draw))

    def _bloom(self, r, c, n, spread, key_bias=0.12, axis=None):
        """a mass of three-bract clusters round c, spread over the dome's surface there"""
        T = self.T; pa = self.pa
        ns = self.norm_at(c) if axis is None else axis
        t1 = np.cross(ns, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(ns, t1)
        hc = (c[2] - self.ce[2]) / self.rb
        ao = 0.82 + 0.18 * max(-1.0, min(1.0, hc + 0.2))
        clusters = []
        for j in range(n):
            a = r.uniform(0, 2 * math.pi); rr = spread * math.sqrt(r.uniform(0.05, 1))
            p = c + (math.cos(a) * t1 + math.sin(a) * t2) * rr + ns * r.uniform(-0.02, 0.04)
            ax = nv(ns + UP * 0.5 + r.normal(0, 0.35, 3))
            u = np.cross(ax, UP); u = nv(u) if np.linalg.norm(u) > 1e-3 else np.array([1.0, 0, 0])
            v = np.cross(ax, u)
            ph0 = r.uniform(0, 2 * math.pi)
            L = 0.15 * r.uniform(0.88, 1.12)
            bracts = []
            for k in range(3):
                ph = ph0 + k * 2.094
                e = nv(ax * 0.6 + (math.cos(ph) * u + math.sin(ph) * v) * 0.8)
                sd = nv(np.cross(ax, e))
                prof = [(0.0, 0.12), (0.12, 0.62), (0.35, 0.98), (0.55, 1.0), (0.75, 0.78), (0.9, 0.44), (1.0, 0.0)]
                Lp_, Rp_ = [], []
                for t, w in prof:
                    q = p + e * L * t
                    Lp_.append(q + sd * L * 0.42 * w + ax * L * 0.08 * w); Rp_.append(q - sd * L * 0.42 * w + ax * L * 0.08 * w)
                poly = Lp_ + Rp_[::-1]
                nn = nv(np.cross(e, sd))
                if nn @ ax < 0: nn = -nn
                front = nn @ TOCAM > 0
                lam = float((nn if front else -nn) @ LIGHT)
                vv = (0.55 + 0.45 * max(-0.3, lam)) * ao + (0.0 if front else -0.12)
                bracts.append(dict(poly=poly, v=vv, mid=p + e * L * 0.5, vein=(p + e * L * 0.08, p + e * L * 0.82)))
            bracts.sort(key=lambda z: depth(z['mid']))
            fl = [p + ax * 0.03 + nv(r.normal(0, 1, 3)) * 0.012 for _ in range(3)]
            clusters.append((p, bracts, fl))
        clusters.sort(key=lambda z: depth(z[0]))
        def draw(clusters=clusters):
            P = pa.P; Bc = T['bract']
            for p, bracts, fl in clusters:
                for z in bracts:
                    v = z['v']
                    col = Bc[0] if v < 0.45 else Bc[1] if v < 0.6 else Bc[2] if v < 0.78 else Bc[3]
                    poly = [P(q) for q in z['poly']]
                    pa.fill(poly, col); pa.soft_edge(poly, col)
                    pa.line([P(z['vein'][0]), P(z['vein'][1])], mixc(col, T['vein'], 0.4), pa.u(0.17), 0.65)
                for q in fl:
                    x, y = P(q); pa.ctx.new_path(); pa.ctx.arc(x, y, pa.u(0.42), 0, 2 * math.pi)
                    pa.ctx.set_source_rgb(*T['flower']); pa.ctx.fill()
                    pa.ctx.new_path(); pa.ctx.arc(x, y, pa.u(0.16), 0, 2 * math.pi)
                    pa.ctx.set_source_rgb(*T['fleye']); pa.ctx.fill()
        self.items.append((c + TOCAM * key_bias, draw))

    def _canes(self, r):
        """long arching canes out of the sides, drooping, with bracts and leaves along their ends"""
        nc = [2, 3, 2, 3][self.seed % 4]
        az0 = r.uniform(-0.4, 0.4)
        sides = [math.pi * 0.08 + az0, math.pi * 0.92 + az0, math.pi * 0.5 + r.normal(0, 0.3)][:nc]
        for az in sides:
            d = np.array([math.cos(az), math.sin(az), 0.15])
            p0 = self.env(nv(d), 0.85)
            out = nv(np.array([math.cos(az), math.sin(az), 0.0]))
            pts = []
            for j in range(9):
                t = j / 8
                pts.append(p0 + out * (0.55 * t) + UP * (0.18 * t - 0.75 * t * t))
            self._woody(pts, 0.02, 0.011, pts[4] - TOCAM * 0.05)
            for j in (3, 5, 7, 8):
                q = pts[j]
                ax = nv(out * 0.5 + UP * 0.6 + np.array([0, 0.5, 0]))
                self._leaves(r, q + UP * 0.02, 2)
                self._bloom(r, q - UP * 0.03, int(r.integers(2, 4)), 0.08, key_bias=0.2, axis=ax)

    def _fallen(self, r):
        """a few bracts dropped on the ground in front of the bush"""
        T = self.T; pa = self.pa
        fb = []
        for k in range(9):
            a = r.uniform(0.15 * math.pi, 0.85 * math.pi); rr = r.uniform(0.55, 1.15) * self.ra
            p = np.array([self.ce[0] + math.cos(a) * rr, self.ce[1] + math.sin(a) * rr * 0.9, 0.004])
            rot = r.uniform(0, 2 * math.pi); L = 0.1 * r.uniform(0.85, 1.1)
            fb.append((p, rot, L, int(r.integers(1, 3))))
        def draw():
            P = pa.P
            for p, rot, L, ci in fb:
                e = np.array([math.cos(rot), math.sin(rot), 0.0]); s = np.array([-e[1], e[0], 0.0])
                prof = [(0.0, 0.12), (0.12, 0.62), (0.35, 0.98), (0.55, 1.0), (0.75, 0.78), (0.9, 0.44), (1.0, 0.0)]
                poly = [P(p + e * L * t + s * L * 0.42 * w) for t, w in prof] + [P(p + e * L * t - s * L * 0.42 * w) for t, w in prof[::-1]]
                col = T['bract'][ci]
                pa.fill(poly, col); pa.soft_edge(poly, col)
        self.items.append((np.array([0, 0, 0.0]) - TOCAM * 5.0, draw))

    def shadow(self):
        pa = self.pa; c = pa.ctx
        cx, cy = pa.P(np.array([self.ce[0], self.ce[1], 0.0]))
        rx = 0.95 * self.ra * pa.k; e = 0.45
        for grow, al in ((1.1, 0.09), (1.0, 0.16)):
            c.save(); c.translate(cx, cy); c.scale(rx * grow, rx * grow * e); c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
            c.set_source_rgba(0, 0, 0, al); c.fill()

    def paint(self):
        self.shadow()
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()


FRAMES = [dict(seed=s) for s in range(4)]


def render(fr, night=False, bb=(-55, -80, 55, 20)):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    f = dict(fr); seed = f.pop('seed')
    Bonggiay(seed, pa, **f).paint()
    surf.flush(); ch.NIGHT = False
    return surf, bb


def to_image(surf):
    w, h = surf.get_width(), surf.get_height()
    a = np.ndarray((h, w, 4), np.uint8, surf.get_data()).copy()
    im = Image.frombuffer('RGBa', (w, h), a[:, :, [2, 1, 0, 3]].tobytes(), 'raw', 'RGBa', 0, 1)
    return im.resize((w // SS, h // SS), Image.LANCZOS).convert('RGBA')


def atlas(outdir, tabpath):
    """4 frames, day and night, cropped and packed into one webp; writes the frame table json"""
    import json
    crops = []
    for night in (False, True):
        for k, fr in enumerate(FRAMES):
            surf, bb = render(fr, night)
            im = to_image(surf)
            a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            crops.append(('nd'[not night] + str(k), im.crop((x0, y0, x1, y1)), bb[0] + x0 / RS, bb[1] + y0 / RS))
    cols = 4; x = y = rowh = 0; pos = {}
    for k, (name, im, dx, dy) in enumerate(crops):
        if k and k % cols == 0: x = 0; y += rowh + 2; rowh = 0
        pos[name] = (x, y); x += im.width + 2; rowh = max(rowh, im.height)
    Wt = max(pos[n][0] + im.width for n, im, _, _ in crops); Ht = y + rowh
    sheet = Image.new('RGBA', (Wt, Ht), (0, 0, 0, 0)); table = {}
    for name, im, dx, dy in crops:
        sx, sy = pos[name]; sheet.paste(im, (sx, sy))
        table[name] = [sx, sy, im.width, im.height, round(dx, 2), round(dy, 2), round(im.width / RS, 2), round(im.height / RS, 2)]
    path = os.path.join(outdir, 'bonggiay.webp')
    sheet.save(path, 'WEBP', quality=90, alpha_quality=100, method=6)
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
        sheet.save('/tmp/claude-0/g/bonggiay_%s.png' % tag); print(sheet.size)
