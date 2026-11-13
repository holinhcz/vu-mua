# Wild grass tufts (bụi cỏ) for Nông Trại Nhỏ, built as small 3D models and painted in flat game tones with the thin
# same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun and night (../chuoi).
# A tuft: 26-40 blades growing out of a small crown at the soil. Every blade is a ribbon folded along its midrib (two
# halves lit differently), it leaves the soil steep, arches out and its tip droops; the long outer ones bend over the
# most. Blades deep in the tuft are darker. A few blades are old and dry (straw coloured), some tufts carry thin seed
# spikes standing above the leaves. Also the shared pieces the reed (../lau) and the wild bush (../buicay) use:
# blade ribbons, baked ground shadow, render / atlas / preview helpers.
import math, os, sys, json
import numpy as np, cairo
from PIL import Image
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(here, '..', 'chuoi'))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM

RS, SS = int(os.environ.get('CO_RS', 5)), 2   # CO_RS=9 (v831): sheets sharp on Link's 4K phone (DPR 4.25 x zoom 1.955 = 8.3 px/unit)
PX = RS * SS
KU = 29.0
UP = np.array([0, 0, 1.0])


def grass_tones():
    return dict(
        fresh=[C('#2a6e2e'), C('#358134'), C('#45953d'), C('#5aa947'), C('#74bd54'), C('#90cf62')],
        dry=[C('#94793a'), C('#ad9046'), C('#c4a752'), C('#d6bd66')],
        spike=dict(stem=C('#7f8a44'), seed=C('#a9a35a'), seed_lit=C('#cdc57a'), seed_dk=C('#7c7638')),
    )


def blade(pa, items, base, az, el0, L, W0, droop, pal, r, ao_in=0.0, twist=0.0, fold=0.5, n=12, key_push=0.0, tipw=0.0, zmin=0.04):
    """one grass blade: a ribbon folded along its midrib; appends its two halves to items as (key, draw)"""
    dh = np.array([math.cos(az), math.sin(az), 0.0])
    perp = np.array([-math.sin(az), math.cos(az), 0.0])
    ds = 1.0 / n
    for _ in range(40):
        pts, tans = [], []
        p = np.array(base, float)
        for i in range(n + 1):
            s = i / n
            el = el0 - droop * s ** 1.6
            t = dh * math.cos(el) + UP * math.sin(el)
            pts.append(p.copy()); tans.append(t)
            p = p + t * L * ds
        # a blade never dips into the soil: a long drooping one bends a little less
        if min(q[2] for q in pts[1:]) >= zmin: break
        droop *= 0.9
    halves = []
    for side in (1, -1):
        edge = []
        nrm_acc = np.zeros(3)
        for i, (q, t) in enumerate(zip(pts, tans)):
            s = i / n
            w = W0 * (1 - s ** 1.5) * min(1.0, 0.55 + 2.2 * s) + tipw * s
            tw = twist * s
            sd = nv(perp * math.cos(tw) + np.cross(t, perp) * math.sin(tw))
            nb = nv(np.cross(t, sd))              # the blade's face normal (before folding)
            if nb[2] < 0: nb = -nb
            # the fold: each half tilts up from the midrib
            hv = nv(sd * side * math.cos(fold) + nb * math.sin(fold))
            edge.append(q + hv * w)
            nrm_acc += nv(np.cross(t, hv * side)) if True else 0
        nrm = nv(nrm_acc) if np.linalg.norm(nrm_acc) > 1e-6 else UP
        if nrm @ TOCAM < 0: nrm = -nrm
        poly3 = pts + edge[::-1]
        lam = float(nrm @ LIGHT)
        halves.append((poly3, lam, side))
    mid = pts[n // 2]
    for poly3, lam, side in halves:
        # inner blades and the lower parts stay in the tuft's shade
        v = 0.5 + 0.42 * max(-0.4, lam) - 0.28 * ao_in
        k = max(0, min(len(pal) - 1, int(v * len(pal))))
        col = pal[k]
        col_base = mixc(col, (0, 0, 0), 0.18)
        def draw(poly3=poly3, col=col, col_base=col_base):
            P = pa.P
            poly = [P(q) for q in poly3]
            pa.fill(poly, col)
            # the base of the blade sits in the tuft's own shade
            nn = len(poly3) // 2
            low = [P(q) for q in poly3[:max(2, nn // 3)]] + [P(q) for q in poly3[len(poly3) - max(2, nn // 3):]]
            pa.ctx.save(); pa.path(poly); pa.ctx.clip()
            pa.path(low); pa.ctx.set_source_rgba(*col_base, 0.7); pa.ctx.fill()
            pa.ctx.restore()
            pa.soft_edge(poly, col)
        items.append((mid + TOCAM * key_push + np.array([0, 0, 0.001 * side]), draw))


def ground_shadow(pa, cx, cy, rx, ry, a=0.16):
    c = pa.ctx; x, y = pa.P(np.array([cx, cy, 0.0]))
    c.save(); c.translate(x, y); c.scale(rx * pa.k, ry * pa.k * 0.5); c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
    c.set_source_rgba(0, 0, 0, a); c.fill()


class Plant:
    """base: items sorted by depth, then the ground shadow underneath (DEST_OVER)"""
    def paint(self):
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()
        self.pa.ctx.save(); self.pa.ctx.set_operator(cairo.OPERATOR_DEST_OVER); self.shadow(); self.pa.ctx.restore()


class BuiCo(Plant):
    """seed 0-3: four tufts; seeds 1 and 3 carry foxtail seed heads (cỏ đuôi chồn)"""
    def __init__(self, seed, pa):
        self.pa = pa; self.seed = seed
        r = np.random.default_rng(seed * 3301 + 17)
        self.items = []
        T = self.T = grass_tones()
        q = seed % 4
        n = [40, 44, 38, 46][q]
        ndry = [2, 1, 2, 2][q]
        self.R = [0.62, 0.66, 0.58, 0.66][q]
        sq = [1.0, 0.9, 1.12, 0.95][q]                    # how flat / wide the tuft is (front-back)
        dry_idx = set(r.choice(n, ndry, replace=False).tolist())
        for j in range(n):
            # an upright fan, the outer blades longer, leaning out and arching over
            az = 2 * math.pi * (j + r.uniform(-0.4, 0.4)) / n
            ring = r.uniform(0.2, 1)
            base = np.array([math.cos(az) * 0.07 * ring * sq, math.sin(az) * 0.05 * ring, 0.0])
            outer = r.uniform(0, 1) ** 0.8
            el0 = math.radians(86 - 24 * outer + r.normal(0, 4))
            L = (0.82 + 0.42 * outer) * r.uniform(0.88, 1.1)
            droop = math.radians(30 + 70 * outer) * r.uniform(0.8, 1.15)
            W0 = r.uniform(0.058, 0.07)
            dry = j in dry_idx
            pal = T['dry'] if dry else T['fresh']
            ao = (1 - outer) * 0.7
            blade(pa, self.items, base, az, el0, L, W0, droop, pal, r, ao_in=ao,
                  twist=r.normal(0, 0.35), fold=r.uniform(0.4, 0.62), key_push=0.12 * outer)
        # the heart of the tuft: young blades standing straight up
        for j in range(10):
            az = r.uniform(0, 2 * math.pi)
            blade(pa, self.items, np.array([0.0, 0.0, 0.0]), az, math.radians(r.uniform(82, 89)), r.uniform(0.7, 0.95),
                  0.055, math.radians(r.uniform(10, 28)), T['fresh'], r, ao_in=0.1, fold=0.5)
        if q in (1, 3):
            azs = [math.radians(a) for a in ([-60, 200] if q == 1 else [-40, 160, 250])]
            for a in azs:
                self._foxtail(r, a + r.normal(0, 0.2))

    def _foxtail(self, r, az):
        """a thin stalk with a long nodding bristly seed head (cỏ đuôi chồn / Setaria)"""
        S = self.T['spike']; pa = self.pa
        dh = np.array([math.cos(az), math.sin(az), 0.0])
        H = r.uniform(1.15, 1.4); lean = r.uniform(0.2, 0.32)
        stalk = [dh * 0.03 + dh * lean * (t ** 2) * H + UP * H * t for t in np.linspace(0, 1, 14)]
        top = stalk[-1]
        # the head arches over and hangs: it leaves the stalk's line and bends down toward the lean
        HL = r.uniform(0.4, 0.48)
        axis = []; p = top.copy()
        t0 = nv(stalk[-1] - stalk[-2])
        for i in range(13):
            s = i / 12
            ang = s * 1.5                                  # turns about 85 degrees over its length
            d = nv(t0 * math.cos(ang) + (nv(dh * 0.3 - UP) if True else 0) * math.sin(ang))
            axis.append(p.copy()); p = p + d * HL / 12
        def draw():
            P = pa.P; c = pa.ctx
            pa.line([P(q) for q in stalk], S['stem'], pa.u(0.45))
            A = [np.array(P(q)) for q in axis]
            # the head's outline is a row of bristle tufts: teeth that point toward the tip
            left, right, mid = [], [], []
            m = 26
            for i in range(m + 1):
                t = i / m
                f = t * (len(A) - 1); i0 = min(int(f), len(A) - 2); fr = f - i0
                p2 = A[i0] * (1 - fr) + A[i0 + 1] * fr
                d = A[i0 + 1] - A[i0]; d = d / (np.linalg.norm(d) + 1e-9); nrm = np.array([-d[1], d[0]])
                body = pa.u(0.95) * min(1.0, 0.45 + t * 4) * (1 - t ** 3 * 0.75)
                tooth = 1.38 if i % 2 else 1.0
                left.append(tuple(p2 + nrm * body * tooth + (d * pa.u(0.25) if i % 2 else 0)))
                right.append(tuple(p2 - nrm * body * tooth + (d * pa.u(0.25) if i % 2 else 0)))
                mid.append(tuple(p2))
            left.append(tuple(A[-1] + (A[-1] - A[-2]) / (np.linalg.norm(A[-1] - A[-2]) + 1e-9) * pa.u(0.6)))
            poly = left + right[::-1]
            pa.fill(poly, S['seed'])
            # the lit half toward the sky
            up_side = left if np.mean([p[1] for p in left]) < np.mean([p[1] for p in right]) else right
            half = up_side[:-1] if up_side is left else up_side
            pa.fill(half + mid[::-1], S['seed_lit'])
            pa.soft_edge(poly, S['seed'])
        self.items.append((top - UP * 0.3 + TOCAM * 0.35, draw))

    def shadow(self):
        ground_shadow(self.pa, 0.0, 0.0, self.R, self.R * 0.95, 0.15)
        ground_shadow(self.pa, 0.0, 0.0, 0.24, 0.22, 0.12)


# ------------------------------------------------------------- shared output helpers
def render(cls, fr, bb, night=False):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    f = dict(fr); f.pop('key', None)
    cls(pa=pa, **f).paint()
    surf.flush(); ch.NIGHT = False
    return surf


def to_image(surf):
    w, h = surf.get_width(), surf.get_height()
    a = np.ndarray((h, w, 4), np.uint8, surf.get_data()).copy()
    im = Image.frombuffer('RGBa', (w, h), a[:, :, [2, 1, 0, 3]].tobytes(), 'raw', 'RGBa', 0, 1)
    return im.resize((w // SS, h // SS), Image.LANCZOS).convert('RGBA')


def atlas(cls, frames, bb, outdir, sheet, tabpath, cols=4):
    crops = []
    for night in (False, True):
        for fr in frames:
            im = to_image(render(cls, fr, bb, night))
            a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            crops.append(('nd'[not night] + fr['key'], im.crop((x0, y0, x1, y1)), bb[0] + x0 / RS, bb[1] + y0 / RS))
    x = y = rowh = 0; pos = {}
    for k, (name, im, dx, dy) in enumerate(crops):
        if k and k % cols == 0: x = 0; y += rowh + 2; rowh = 0
        pos[name] = (x, y); x += im.width + 2; rowh = max(rowh, im.height)
    Wt = max(pos[n][0] + im.width for n, im, _, _ in crops); Ht = y + rowh
    out = Image.new('RGBA', (Wt, Ht), (0, 0, 0, 0)); table = {}
    for name, im, dx, dy in crops:
        sx, sy = pos[name]; out.paste(im, (sx, sy))
        table[name] = [sx, sy, im.width, im.height, round(dx, 2), round(dy, 2), round(im.width / RS, 2), round(im.height / RS, 2)]
    path = os.path.join(outdir, sheet)
    out.save(path, 'WEBP', quality=88, alpha_quality=100, method=6)
    open(tabpath, 'w').write(json.dumps(table, separators=(',', ':')))
    print(out.size, os.path.getsize(path))
    return table


def preview(cls, frames, bb, which, night, out):
    ims = [to_image(render(cls, frames[k], bb, night)) for k in which]
    w = sum(i.width for i in ims); h = ims[0].height
    sheet = Image.new('RGBA', (w, h), (40, 58, 52, 255) if night else (155, 191, 106, 255)); x = 0
    for im in ims:
        sheet.alpha_composite(im, (x, 0)); x += im.width
    sheet.save(out); print(sheet.size)


def main(cls, frames, bb, sheet, tag):
    if len(sys.argv) > 2 and sys.argv[1] == 'atlas':
        atlas(cls, frames, bb, sys.argv[2], sheet, sys.argv[3] if len(sys.argv) > 3 else 'atlas.json')
    else:
        which = [int(x) for x in sys.argv[1].split(',')] if len(sys.argv) > 1 else range(len(frames))
        night = len(sys.argv) > 2 and sys.argv[2] == 'n'
        t = sys.argv[3] if len(sys.argv) > 3 else 'a'
        preview(cls, frames, bb, which, night, '/tmp/claude-0/g/%s_%s.png' % (tag, t))


FRAMES = [dict(key=str(s), seed=s) for s in range(4)]
BB = (-50, -70, 50, 22)

if __name__ == '__main__':
    main(BuiCo, FRAMES, BB, 'co.webp', 'co')
