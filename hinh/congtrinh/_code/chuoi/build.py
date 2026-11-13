# Builds the banana sprite sheet for Nông Trại Nhỏ: python3 build.py [preview]
# Frames: decor banana seeds 0-3, wild banana seeds 0-3, fruit-tree banana green/ripe; each in a day and a night set.
import math, json, sys, os
import numpy as np, cairo
from PIL import Image
import chuoi as ch
from chuoi import Leaf, Painter, stem_items, bunch_items, nv, C, depth

RS = 5            # final pixels per game unit
SS = 2            # paint supersampling
PX = RS * SS
KU = 29.0         # game units per metre


def spear_item(pa, out, crown, lean, h):
    if ch.EDGE:
        pts = [np.array(crown) + np.array([lean[0] * t, lean[1] * t, h * t]) + np.array([0, 0, -0.05 * t * t]) for t in np.linspace(0, 1, 10)]
    else:
        # v621 (critique 7, "a pointed stick standing straight up"): shorter, leaning and bending over to one
        # side as it rises, like the soft rolled leaf it is
        sd = 1.0 if lean[0] >= 0 else -1.0
        h2 = h * 0.78
        pts = [np.array(crown) + np.array([lean[0] * t + sd * 0.22 * h2 * t ** 2.2, lean[1] * t + 0.05 * t, h2 * t - 0.16 * h2 * t ** 3]) for t in np.linspace(0, 1, 12)]
    def draw():
        pp = [pa.P(q) for q in pts]
        pa.taper(pp, pa.u(2.2), pa.u(0.3 if ch.EDGE else 0.7), C('#bfe27c'), outline=C('#3f7426'), ow=pa.u(0.5))
        sh = [(x + pa.u(0.45), y) for x, y in pp]
        pa.taper(sh[:-1], pa.u(0.8), pa.u(0.2), C('#93c158'))
        pa.taper([(x - pa.u(0.4), y) for x, y in pp[1:-2]], pa.u(0.5), pa.u(0.15), C('#e2f5b0'))
    out.append((pts[3] + np.array([0, 0.002, 0]), draw))


def plant(seed, kind='banana', ripe=None, pa=None):
    """returns (items, main stem base). items: list of (3D anchor, draw(pa))"""
    rng = np.random.default_rng(seed * 97 + {'banana': 1, 'wild': 2, 'ft': 3}[kind])
    wild = kind == 'wild'
    sc = 0.8 if wild else 1.0
    H = (1.55 if wild else 1.8) * (1.0 + rng.uniform(-0.04, 0.05))
    if kind == 'banana' and seed == 0: H *= 0.9
    r0 = 0.17 * sc
    crown = np.array([0.0, 0.0, H])
    items = []
    leaves = []
    nl = int(rng.integers(7, 9)) if wild else int(rng.integers(10, 13))
    a0 = rng.uniform(0, 6.28)
    has_bunch = (kind == 'banana' and seed > 0) or kind == 'ft' or (wild and seed == 3)
    br = np.random.default_rng(seed * 5 + 11)
    bside = -1 if kind == 'ft' else (1 if br.random() < 0.5 else -1)
    azb = math.pi / 2 + bside * br.uniform(0.55, 0.85)
    for j in range(nl):
        f = j / (nl - 1)
        az = a0 + j * 2.39996 + rng.normal(0, 0.18)
        # old drooping leaves must not hang straight down the front of the trunk
        if f > 0.3 and math.sin(az) > 0.45:
            az = math.asin(0.45) if math.cos(az) >= 0 else math.pi - math.asin(0.45)
        # nor over the bunch
        dd = (az - azb + math.pi) % (2 * math.pi) - math.pi
        if has_bunch and f > 0.35 and abs(dd) < 0.7: az = azb + (0.7 if dd >= 0 else -0.7)
        age = 0 if j == 0 else 1 if f < 0.9 else 2
        if wild and f > 0.7: age = 2
        e0 = (1.32 - 1.0 * f if j else rng.uniform(1.12, 1.32)) + rng.normal(0, 0.07)
        droop = 0.45 + 2.1 * f ** 1.3 + rng.uniform(0, 0.3)
        L = (1.5 + 0.45 * rng.random()) * (0.85 if j == 0 else 1.0) * sc
        W = (0.34 + 0.05 * rng.random()) * sc
        tears = 0 if j == 0 else (1.2 + 3.2 * f) * (1.8 if wild else 1.0)
        base = crown + np.array([math.cos(az) * 0.05, math.sin(az) * 0.05, 0.12 - 0.05 * j])
        young = j == 0
        lf = Leaf(rng, base, az, e0, droop, L, W * (0.8 if young else 1.0), 0.36 * sc, age, tears=tears, twist=rng.normal(0, 0.22),
                  fold=0.6 if young else 0.14 + 0.1 * rng.random(), curl=0.4 if young else 0.12 + 0.25 * f, bend=rng.normal(0, 0.12),
                  torn_droop=0.6 + 0.8 * f, shade=1.0 - 0.06 * max(0.0, -math.sin(az)))
        leaves.append(lf)
    # a dead leaf hanging down beside the trunk
    if not (kind == 'banana' and seed == 1):
        dside = 1 if rng.random() < 0.5 else -1
        azd = math.pi / 2 + dside * rng.uniform(0.7, 1.1)
        el = lambda s: 0.55 - 3.4 * min(1.0, s ** 0.45) if s > 0.04 else 0.55
        dl = Leaf(rng, crown + np.array([math.cos(azd) * 0.06, math.sin(azd) * 0.06, 0.02]), azd, 0, 0,
                  (1.15 if not wild else 0.95) * sc, 0.13 * sc, 0.16, 3, tears=6, fold=0.75, curl=0.5, twist=0.5 * dside,
                  elev=lambda s: max(-1.45, 0.1 - 3.2 * s ** 0.5), torn_droop=1.1, gap=0.07)
        leaves.append(dl)
        if wild:
            azd2 = azd + math.pi * 0.8
            leaves.append(Leaf(rng, crown + np.array([0, 0, -0.05]), azd2, 0, 0, 0.9 * sc, 0.1 * sc, 0.1, 3, tears=5,
                               fold=1.0, curl=0.7, elev=lambda s: max(-1.5, 0.05 - 3.2 * s ** 0.5), gap=0.05))
    for lf in leaves: lf.items(pa, items)
    spear_item(pa, items, crown + np.array([0, 0, 0.1]), (rng.normal(0, 0.06), rng.normal(0, 0.04)), (0.62 if not wild else 0.45) * sc)
    # suckers round the foot
    nsuck = {'banana': [1, 2, 3, 1][seed % 4], 'wild': 2, 'ft': 1}[kind]
    sang = rng.uniform(0, 6.28)
    stems = []
    for k in range(nsuck):
        ang = sang + k * 2.1 + rng.normal(0, 0.3)
        if math.sin(ang) < -0.3 and k == 0: ang = -ang     # the first one in view
        if has_bunch:                                      # keep suckers out from under the hanging heart
            db = (ang - azb + math.pi) % (2 * math.pi) - math.pi
            if abs(db) < 1.0: ang = azb + (1.0 if db >= 0 else -1.0)
            if kind == 'ft': ang = azb + math.pi + rng.normal(0, 0.2)
        d = rng.uniform(0.34, 0.5) * sc
        bx, by = math.cos(ang) * d, math.sin(ang) * d
        hs = rng.uniform(0.14, 0.32) * sc
        stems.append(((bx, by), hs, rng.uniform(0.06, 0.075) * sc, True, 0))
        nlv = int(rng.integers(3, 5)); a1 = rng.uniform(0, 6.28)
        for m in range(nlv):
            az = a1 + m * 2.4 + rng.normal(0, 0.3)
            items_l = Leaf(rng, (bx, by, hs + 0.02), az, rng.uniform(0.95, 1.3) - 0.15 * m, 0.6 + 0.5 * m,
                           rng.uniform(0.45, 0.75) * sc, rng.uniform(0.08, 0.11) * sc, 0.08, 0, tears=0, fold=0.25, curl=0.2)
            items_l.items(pa, items)
    if kind == 'banana' and seed == 0:
        pass
    if has_bunch:
        hands = {'banana': [0, 4, 5, 6][seed % 4], 'ft': 6, 'wild': 3}[kind]
        bunch_items(pa, items, rng, crown + np.array([0, 0, 0.0]), azb, bool(ripe), hands=hands, scale=sc * (1.3 if kind == 'ft' else 1.2))
    return items, stems, (0.0, 0.0), H, r0


def render(kind, seed, night=False, ripe=None, bb=(-80, -150, 80, 30)):
    ch.NIGHT = night
    # the painter is needed while building (stem palettes etc. go through C), so build inside the night flag
    W = int((bb[2] - bb[0]) * PX); Hh = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, Hh)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    items, stems, mb, H, r0 = plant(seed, kind, ripe, pa)
    rng = np.random.default_rng(seed * 31 + 7)
    allit = []
    for pos, fn in items:
        allit.append((pos, fn))
    for (b, hs, rr, young, _) in stems:
        fn = stem_items(pa, None, rng, b, hs, rr, young=True, dry_sheaths=1)
        allit.append((np.array([b[0], b[1], hs / 2]), fn))
    main = stem_items(pa, None, rng, mb, H, r0, dry_sheaths=2 if kind != 'wild' else 4)
    back = [(depth(p), fn) for p, fn in allit if p[1] < mb[1]]
    front = [(depth(p), fn) for p, fn in allit if p[1] >= mb[1]]
    for _, fn in sorted(back, key=lambda z: z[0]): call(fn, pa)
    main()
    for _, fn in sorted(front, key=lambda z: z[0]): call(fn, pa)
    surf.flush()
    ch.NIGHT = False
    return surf, bb


def call(fn, pa):
    fn()


def to_image(surf):
    w, h = surf.get_width(), surf.get_height()
    a = np.ndarray((h, w, 4), np.uint8, surf.get_data()).copy()
    rgba = a[:, :, [2, 1, 0, 3]]     # premultiplied
    im = Image.frombuffer('RGBa', (w, h), rgba.tobytes(), 'raw', 'RGBa', 0, 1)
    im = im.resize((w // SS, h // SS), Image.LANCZOS)
    return im.convert('RGBA')


def preview():
    out = '/tmp/claude-0/g/chuoi_prev.png'
    frames = [('banana', 0, None), ('banana', 1, None), ('banana', 2, None), ('banana', 3, None), ('ft', 0, 0), ('ft', 1, 1), ('wild', 0, None), ('wild', 3, None)]
    ims = []
    for kind, seed, ripe in frames:
        s, bb = render(kind, seed, False, ripe)
        ims.append((to_image(s), bb))
    w = sum(im.width for im, _ in ims); h = max(im.height for im, _ in ims)
    sheet = Image.new('RGBA', (w, h), (143, 174, 88, 255))
    x = 0
    for k, (im, bb) in enumerate(ims):
        im.save('/tmp/claude-0/g/fr_%d.png' % k)
        sheet.alpha_composite(im, (x, 0)); x += im.width
    sheet.save(out)
    print(sheet.size)


def atlas(outdir):
    """all frames, day and night, cropped and shelf-packed into one webp; prints the JS frame table"""
    frames = [('b', k, 'banana', k, None) for k in range(4)] + [('f', k, 'ft', 1, k) for k in range(2)] + [('w', k, 'wild', k, None) for k in range(4)]
    crops = []
    for night in (False, True):
        for tag, idx, kind, seed, ripe in frames:
            s, bb = render(kind, seed, night, ripe)
            im = to_image(s)
            a = np.array(im)[:, :, 3]
            ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            crops.append(('nd'[not night] + tag + str(idx), im.crop((x0, y0, x1, y1)), bb[0] + x0 / RS, bb[1] + y0 / RS))
    # shelf pack, tallest first
    order = sorted(crops, key=lambda c: -c[1].height)
    Wmax = 2600; x = y = rowh = 0; pos = {}
    for name, im, dx, dy in order:
        if x + im.width > Wmax: x = 0; y += rowh + 2; rowh = 0
        pos[name] = (x, y); x += im.width + 2; rowh = max(rowh, im.height)
    Wt = max(pos[n][0] + im.width for n, im, _, _ in order); Ht = y + rowh
    sheet = Image.new('RGBA', (Wt, Ht), (0, 0, 0, 0))
    table = {}
    for name, im, dx, dy in crops:
        sx, sy = pos[name]; sheet.paste(im, (sx, sy))
        table[name] = [sx, sy, im.width, im.height, round(dx, 2), round(dy, 2), round(im.width / RS, 2), round(im.height / RS, 2)]
    path = os.path.join(outdir, 'chuoi.webp')
    sheet.save(path, 'WEBP', quality=92, alpha_quality=100, method=6)
    sheet.save('/tmp/claude-0/g/atlas.png')
    print(sheet.size, os.path.getsize(path))
    print(json.dumps(table, separators=(',', ':')))
    return table


if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == 'atlas': atlas(sys.argv[2])
    else: preview()
