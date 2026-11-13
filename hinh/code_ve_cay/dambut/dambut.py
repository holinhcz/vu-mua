# Hibiscus bushes (bụi dâm bụt) for Nông Trại Nhỏ, built as small 3D models and painted in flat game tones with the
# thin same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun and night transform.
# A bush: a few woody stems out of the ground into a dense dome of glossy toothed oval leaves (a dark inner mass so
# the gaps read as depth, not as holes), big red flowers facing out of the dome (five broad overlapping petals, a dark
# crimson eye, the long staminal column with yellow pollen and red stigma pads) and a few spindle buds.
import math, os, sys
import numpy as np, cairo
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'chuoi'))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM

RS, SS = 9, 2
PX = RS * SS
KU = 29.0
UP = np.array([0, 0, 1.0])


def tones():
    return dict(
        green=[C('#1f5326'), C('#2a6c2e'), C('#388839'), C('#4fa245'), C('#6dba56')],
        und=[C('#3c6a34'), C('#4c7d40'), C('#5f934c')],
        inner=C('#1b4521'),
        stem=dict(lit=C('#9c8a70'), mid=C('#7a6a54'), dk=C('#584c3c')),
        petal=dict(dk=C('#8a0f1f'), mid=C('#b81b29'), lit=C('#d23034'), hi=C('#e85a4e')),   # v643: a step deeper (was a3121e d4202a ee3e36 ff6f5c)
        eye=C('#5e0818'), vein=C('#860d1e'),
        column=C('#f0c8a0'), pollen=C('#f8d24a'), stigma=C('#c8102a'),
        bud=dict(dk=C('#8e1020'), mid=C('#bc232a'), lit=C('#d6443a')), calyx=C('#4f8a34'),
    )


def hull(pts):
    pts = sorted(set((round(p[0], 3), round(p[1], 3)) for p in pts))
    if len(pts) < 3: return pts
    def cr(o, a, b): return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, hi = [], []
    for p in pts:
        while len(lo) >= 2 and cr(lo[-2], lo[-1], p) <= 0: lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(hi) >= 2 and cr(hi[-2], hi[-1], p) <= 0: hi.pop()
        hi.append(p)
    return lo[:-1] + hi[:-1]


class Dambut:
    """seed picks the shape and the number of flowers"""
    def __init__(self, seed, pa):
        self.pa = pa; self.seed = seed
        r = self.rng = np.random.default_rng(seed * 6151 + 41)
        self.items = []
        self.T = tones()
        q = seed % 4
        self.ra = [1.0, 0.9, 1.06, 0.95][q]
        self.ry = self.ra * [0.92, 1.0, 0.9, 0.96][q]
        self.rb = [0.66, 0.72, 0.62, 0.68][q]
        self.ce = np.array([[0.02, 0.0], [-0.03, 0.02], [0.03, -0.02], [0.0, 0.03]][q] + [self.rb * 0.72 + 0.16])
        # the dome is lumpy: a few broad bulges, so it reads as a shrub and not a clipped ball
        self.lumps = [(nv(r.normal(0, 1, 3)), r.uniform(1.6, 2.6), r.uniform(0, 6.28), r.uniform(0.05, 0.09)) for _ in range(5)]
        self.nfl = [6, 7, 8, 7][q]
        self._stems(r)
        self._mass()
        self._leaves(r)
        self._flowers(r)

    def norm_at(self, p):
        e = (p - self.ce) / np.array([self.ra, self.ry, self.rb]) ** 2
        return nv(e)

    def lump(self, d):
        return 1.0 + sum(a * math.cos(fr * (d @ kk) * math.pi + ph) for kk, fr, ph, a in self.lumps)

    def env(self, d, f=1.0):
        """the point of the dome in direction d from its centre"""
        return self.ce + np.array([d[0] * self.ra, d[1] * self.ry, d[2] * self.rb]) * f * self.lump(d)

    # ------------------------------------------------------------- stems and the inner mass
    def _stems(self, r):
        pa = self.pa; T = self.T
        n = 5
        az0 = r.uniform(0, 2 * math.pi)
        for k in range(n):
            az = az0 + k * 2 * math.pi / n + r.normal(0, 0.3)
            A = np.array([math.cos(az), math.sin(az), 0.0])
            p0 = A * r.uniform(0.02, 0.07)
            d = nv(UP + A * r.uniform(0.4, 0.8))
            pts = [p0]
            for j in range(6):
                d = nv(d + r.normal(0, 0.12, 3) + UP * 0.05)
                pts.append(pts[-1] + d * 0.11)
            w0 = 0.028 * r.uniform(0.85, 1.15)
            def draw(pts=pts, w0=w0):
                P = pa.P; S = T['stem']
                sp = [P(q) for q in pts]
                pa.taper(sp, w0 * 2 * pa.k, w0 * 1.1 * pa.k, S['mid'], outline=S['mid'])
                arr = np.array(sp); lit = []
                for i in range(len(arr)):
                    a = arr[max(0, i - 1)]; b = arr[min(len(arr) - 1, i + 1)]
                    dd = nv(b - a); nr = np.array([-dd[1], dd[0]])
                    if nr @ SLIGHT < 0: nr = -nr
                    lit.append(tuple(arr[i] + nr * w0 * pa.k * 0.45))
                pa.line(lit, S['lit'], pa.u(0.3), 0.8)
            self.items.append((pts[0] - TOCAM * 3.0 + UP * 0.0, draw))

    def _mass(self):
        """a dark inner dome a little smaller than the leaf surface: the gaps between leaves show it, not the ground"""
        pa = self.pa; T = self.T
        pts = []
        for th in np.linspace(0, math.pi, 25):
            for ph in np.linspace(0, 2 * math.pi, 37):
                d = np.array([math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)])
                if d[2] < -0.55: continue
                pts.append(self.env(d, 0.84))
        def draw():
            P = pa.P
            h = hull([P(p) for p in pts])
            pa.fill(h, T['inner'])
        self.items.append((self.ce - TOCAM * 2.0, draw))

    # ------------------------------------------------------------- leaves
    def _leaves(self, r):
        n = 150; ga = math.pi * (3 - math.sqrt(5))
        spots = []
        for i in range(n):
            zz = 1 - 2 * (i + 0.5) / n; rr = math.sqrt(max(0.0, 1 - zz * zz))
            if zz < -0.5: continue
            d = np.array([rr * math.cos(i * ga), rr * math.sin(i * ga), zz])
            f = r.uniform(0.93, 1.03) if i % 4 else r.uniform(0.8, 0.9)
            spots.append(self.env(d, f))
        self.nmain = len(spots)
        # a few shoots poking out of the top and the sides (leaves and buds only)
        for k in range(6):
            az = r.uniform(-0.3, math.pi + 0.3); zz = r.uniform(0.15, 0.8); rr = math.sqrt(1 - zz * zz)
            spots.append(self.env(np.array([rr * math.cos(az), rr * math.sin(az), zz]), r.uniform(1.05, 1.12)))
        self.spots = spots
        for p in spots:
            self._cluster(r, p)

    def _cluster(self, r, c):
        T = self.T; pa = self.pa
        # leaves turn their faces up to the light, the back of the dome too
        ns = self.norm_at(c)
        nrm0 = nv(ns + UP * 0.9)
        t1 = np.cross(nrm0, UP)
        t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(nrm0, t1)
        hc = (c[2] - self.ce[2]) / self.rb
        sun = float(ns @ LIGHT)                      # the side of the dome toward the sun is lighter
        ao = 0.78 + 0.22 * max(-1.0, min(1.0, hc + 0.1))
        if math.dist(c, self.ce) < 0.88 * min(self.ra, self.rb * 1.4): ao -= 0.12   # inner leaves sit in shade
        nl = int(r.integers(4, 7))
        az0 = r.uniform(0, 2 * math.pi)
        leaves = []
        for k in range(nl):
            az = az0 + k * 2 * math.pi / nl + r.normal(0, 0.25)
            A = math.cos(az) * t1 + math.sin(az) * t2
            el = r.uniform(0.05, 0.55)
            ld = nv(A * math.cos(el) + nrm0 * math.sin(el) - UP * 0.15)
            sd = nv(np.cross(nrm0, ld))
            Ll = 0.24 * r.uniform(0.85, 1.12); Wl = Ll * 0.62
            # ovate, toothed on the outer half, a pointed tip
            prof = [(0.0, 0.1), (0.08, 0.55), (0.22, 0.9), (0.38, 1.0), (0.5, 0.95), (0.58, 0.9), (0.66, 0.8),
                    (0.73, 0.72), (0.8, 0.58), (0.86, 0.47), (0.92, 0.3), (1.0, 0.0)]
            tooth = [0, 0, 0, 0, 1, -1, 1, -1, 1, -1, 1, 0]
            pt = c + ld * 0.02
            Lp_, Rp_ = [], []
            for (t, w), th in zip(prof, tooth):
                q = pt + ld * Ll * t - UP * Ll * 0.14 * t * t
                ww = w * (1 + 0.06 * th)
                Lp_.append(q + sd * Wl * 0.5 * ww); Rp_.append(q - sd * Wl * 0.5 * ww)
            poly = Lp_ + Rp_[::-1]
            n = nv(np.cross(ld, sd))
            if n @ nrm0 < 0: n = -n
            topv = n @ TOCAM > 0
            vis = n if topv else -n
            lam = float(vis @ LIGHT)
            v = (0.55 + 0.45 * max(-0.3, lam)) * ao + 0.13 * sun - 0.05
            leaves.append(dict(poly=poly, top=topv, v=v, mid=pt + ld * Ll * 0.5, rib=(pt, pt + ld * Ll * 0.86 - UP * Ll * 0.1),
                               gloss=topv and lam > 0.45))
        vm = float(np.mean([z['v'] for z in leaves]))
        for z in leaves: z['v'] = 0.55 * vm + 0.45 * z['v']
        leaves.sort(key=lambda z: depth(z['mid']))
        def col_of(z):
            v = z['v']; ramp = T['green']
            if not z['top']: return T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            return ramp[0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4]
        cols = [col_of(z) for z in leaves]
        def draw(leaves=leaves, cols=cols):
            P = pa.P
            for z, col in zip(leaves, cols):
                poly = [P(q) for q in z['poly']]
                pa.fill(poly, col)
                pa.soft_edge(poly, col)
                pa.line([P(z['rib'][0]), P(z['rib'][1])], mixc(col, C('#d8e6a0'), 0.3), pa.u(0.2), 0.75)
                if z['gloss']:
                    # glossy leaf: one short pale streak beside the midrib
                    a3, b3 = z['rib']; m3 = a3 + (b3 - a3) * 0.3; e3 = a3 + (b3 - a3) * 0.62
                    pa.line([P(m3), P(e3)], mixc(col, (1, 1, 1), 0.28), pa.u(0.45), 0.55)
        self.items.append((c, draw))

    # ------------------------------------------------------------- flowers and buds
    def _flowers(self, r):
        cand = []
        for p in self.spots[:self.nmain]:
            n = self.norm_at(p)
            vis = n @ TOCAM
            if vis < 0.15 or p[2] < 0.3: continue
            cand.append((vis * 0.6 + r.uniform(0, 0.7), p, n))
        cand.sort(key=lambda z: -z[0])
        picked = []
        for s, p, n in cand:
            if len(picked) >= self.nfl + 3: break
            sp = np.array(self.pa.P(p)) / self.pa.k
            if any(np.linalg.norm(sp - q) < 0.42 for q, _, _ in picked): continue
            picked.append((sp, p, n))
        for k, (_, p, n) in enumerate(picked):
            if k < self.nfl: self._flower(r, p, n)
            else: self._bud(r, p, n)

    def _flower(self, r, c, n):
        T = self.T; pa = self.pa
        R = 0.235 * r.uniform(0.93, 1.07)
        f = nv(n + UP * 0.3 + TOCAM * 0.2 + r.normal(0, 0.25, 3))
        u = np.cross(f, UP); u = nv(u) if np.linalg.norm(u) > 1e-3 else np.array([1.0, 0, 0])
        v = np.cross(f, u)
        c = c + n * 0.04
        ph0 = r.uniform(0, 2 * math.pi)
        petals = []
        for k in range(5):
            pk = ph0 + k * 2 * math.pi / 5
            a = 0.8
            ths = np.linspace(pk - a, pk + a, 15)
            def X(rho, th):
                h = 0.5 * rho * (1 - 0.45 * rho / R)                   # the funnel
                return c + f * h + (math.cos(th) * u + math.sin(th) * v) * rho
            outer = []
            for th in ths:
                s = (th - pk) / a
                rho = R * (0.8 + 0.2 * math.cos(s * math.pi / 2)) * (1 + 0.035 * math.sin(th * 9 + k))
                outer.append(X(rho, th))
            inner = [X(R * 0.05, pk + a * 0.3), X(R * 0.05, pk - a * 0.3)]
            poly = inner[1:] + outer + inner[:1]
            eye = [X(R * 0.05, pk + a * 0.3), X(R * 0.05, pk - a * 0.3)][::-1] + [X(R * 0.34, th) for th in np.linspace(pk - a * 0.85, pk + a * 0.85, 7)]
            # shade from the petal's tilt
            mid = X(R * 0.6, pk)
            radial = nv(X(R * 0.7, pk) - X(R * 0.4, pk))
            tang = nv(X(R * 0.6, pk + 0.2) - X(R * 0.6, pk - 0.2))
            pn = nv(np.cross(radial, tang))
            if pn @ f < 0: pn = -pn
            front = pn @ TOCAM > 0
            lam = float((pn if front else -pn) @ LIGHT)
            veins = [[X(R * 0.2, pk + dv), X(R * 0.62, pk + dv * 1.4)] for dv in (-0.35, 0.0, 0.35)]
            petals.append(dict(poly=poly, eye=eye, mid=mid, lam=lam, front=front, veins=veins))
        petals.sort(key=lambda z: depth(z['mid']))
        # the staminal column: out of the centre, curving a little down, pollen along its outer half, red pads at the end
        cd = nv(f - UP * 0.25)
        col = [c + f * 0.01 + cd * R * t + (-UP) * R * 0.18 * t * t for t in np.linspace(0, 1.05, 8)]
        pol = [col[i] + nv(r.normal(0, 1, 3)) * R * 0.06 for i in (4, 5, 5, 6, 6, 6, 7)]
        tip = col[-1]
        pads = [tip + (math.cos(a) * u + math.sin(a) * v) * R * 0.07 + cd * R * 0.04 for a in np.linspace(0, 2 * math.pi, 6)[:-1]]
        col_front = cd @ TOCAM > -0.2
        Pt = T['petal']
        def draw():
            P = pa.P
            def column():
                pa.line([P(q) for q in col], T['pollen'], pa.u(0.75))
                for q in pol:
                    x, y = P(q); pa.ctx.new_path(); pa.ctx.arc(x, y, pa.u(0.5), 0, 2 * math.pi)
                    pa.ctx.set_source_rgb(*T['pollen']); pa.ctx.fill()
                for q in pads:
                    x, y = P(q); pa.ctx.new_path(); pa.ctx.arc(x, y, pa.u(0.45), 0, 2 * math.pi)
                    pa.ctx.set_source_rgb(*T['stigma']); pa.ctx.fill()
            if not col_front: column()
            for z in petals:
                lam = z['lam']
                cl = Pt['dk'] if not z['front'] else Pt['lit'] if lam > 0.55 else Pt['mid'] if lam > 0.05 else mixc(Pt['mid'], Pt['dk'], 0.5)
                poly = [P(q) for q in z['poly']]
                pa.fill(poly, cl)
                pa.ctx.save(); pa.path(poly); pa.ctx.clip()
                for a3, b3 in z['veins']:
                    pa.line([P(a3), P(b3)], mixc(cl, T['vein'], 0.45), pa.u(0.18), 0.7)
                pa.fill([P(q) for q in z['eye']], T['eye'], seam=False)
                pa.ctx.restore()
                pa.soft_edge(poly, cl)
            if col_front: column()
        self.items.append((c + TOCAM * 0.3, draw))

    def _bud(self, r, c, n):
        T = self.T; pa = self.pa
        d = nv(n * 0.5 + UP + r.normal(0, 0.2, 3))
        base = c + n * 0.02
        L, W = 0.17 * r.uniform(0.9, 1.1), 0.065
        def draw():
            P = pa.P; k = pa.k
            a = np.array(P(base)); b = np.array(P(base + d * L))
            ax = b - a; ln = np.linalg.norm(ax); ax = ax / ln; sx = np.array([ax[1], -ax[0]])
            prof = [(0.0, 0.5), (0.25, 0.95), (0.5, 1.0), (0.75, 0.7), (1.0, 0.0)]
            body = [tuple(a + ax * ln * t + sx * W * k * 0.5 * w) for t, w in prof] + [tuple(a + ax * ln * t - sx * W * k * 0.5 * w) for t, w in prof[::-1]]
            B = T['bud']
            pa.fill(body, B['mid'])
            sl = 1 if sx @ SLIGHT > 0 else -1
            pa.ctx.save(); pa.path(body); pa.ctx.clip()
            pa.path([tuple(a + ax * ln * t + sx * sl * W * k * 0.5 * w * 1.1) for t, w in prof] + [tuple(a + ax * ln * t + sx * sl * W * k * 0.08) for t, w in prof[::-1]])
            pa.ctx.set_source_rgb(*B['lit']); pa.ctx.fill()
            # the green calyx wrapping the lower third
            cal = [tuple(a + ax * ln * t + sx * W * k * 0.55 * w) for t, w in ((0, 0.6), (0.2, 1.0), (0.38, 0.9))] + \
                  [tuple(a + ax * ln * 0.3 + sx * W * k * 0.1), tuple(a + ax * ln * 0.42), tuple(a + ax * ln * 0.3 - sx * W * k * 0.1)] + \
                  [tuple(a + ax * ln * t - sx * W * k * 0.55 * w) for t, w in ((0.38, 0.9), (0.2, 1.0), (0, 0.6))]
            pa.fill(cal, T['calyx'], seam=False)
            pa.ctx.restore()
            pa.soft_edge(body, B['mid'])
        self.items.append((base + TOCAM * 0.25, draw))

    def shadow(self):
        pa = self.pa; c = pa.ctx
        cx, cy = pa.P(np.array([self.ce[0], self.ce[1], 0.0]))
        rx = 1.0 * self.ra * pa.k; e = 0.45
        for grow, al in ((1.1, 0.09), (1.0, 0.16)):
            c.save(); c.translate(cx, cy); c.scale(rx * grow, rx * grow * e); c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
            c.set_source_rgba(0, 0, 0, al); c.fill()

    def paint(self):
        self.shadow()
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()


FRAMES = [dict(seed=s) for s in range(4)]


def render(fr, night=False, bb=(-50, -60, 50, 20)):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    f = dict(fr); seed = f.pop('seed')
    Dambut(seed, pa, **f).paint()
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
    path = os.path.join(outdir, 'dambut.webp')
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
        sheet.save('/tmp/claude-0/g/dambut_%s.png' % tag); print(sheet.size)
