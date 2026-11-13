# Nhà tranh nhỏ (the starter hut, game id "hutnho"), painted shape by shape in pycairo for Nông Trại Nhỏ.
# Same footprint and size as the old canvas hut: 2x2 tiles, bb [-80,-136,80,44] game units, origin = footprint centre.
# Camera = the game's iso: screen x = (u-v)*32, y = (u+v)*16 - 32 - z  (u,v in tiles, z in game units).
# Horizontal metric: 1 tile = T game units, so walls/roof textures are drawn in each face's own plane (affine map).
# Light from the upper left like the game's boxes: front (+v) faces lit, right (+u) faces in shade.
# Usage:  python3 choi.py prev OUT.png [t] [n]      one frame (t = variant 0..3, n = night)
#         python3 choi.py atlas OUTDIR atlas.json  all 8 frames -> OUTDIR/choi.webp + atlas
import math, sys, json
import numpy as np, cairo
from PIL import Image, ImageFilter

T = math.hypot(32, 16)              # game units per tile, horizontally
SS = 12                             # render px per game unit (downsampled x2 -> 6, the game's top sharpness)
BX0, BY0, BX1, BY1 = -80, -136, 80, 44
W, H = int((BX1 - BX0) * SS), int((BY1 - BY0) * SS)
L = np.array([-0.22, 0.5, 0.84]); L = L / np.linalg.norm(L)
NIGHT = False
_NG = np.array([[0.6838, 0.0272, 0.0097], [0.0358, 0.71, 0.0707], [-0.0163, -0.065, 0.5548], [-0.0528, -0.0317, -0.0055]])
_NG_GREEN = np.array([[0.6475, 0.0297, -0.0727], [-0.002, 0.8864, 0.2652], [-0.0511, -0.1777, 0.3976], [-0.0025, -0.0939, -0.0255]])


def hx(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)])


def C(h, k=1.0, lit=False):
    """colour (hex or rgb) * k, through the game's night transform unless lit (lamp light)"""
    c = (hx(h) if isinstance(h, str) else np.array(h, float)) * k
    c = np.clip(c, 0, 1)
    if NIGHT and not lit:
        M = _NG_GREEN if (c[1] > c[0] and c[1] > c[2]) else _NG
        c = np.clip(np.append(c, 1.0) @ M, 0, 1)
    return tuple(float(x) for x in c)


def mix(a, b, t): return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def shade(n):
    n = np.array(n, float); n = n / np.linalg.norm(n)
    return 0.7 + 0.32 * max(0.0, float(n @ L))


K_TOP, K_FRONT, K_RIGHT = shade([0, 0, 1]), shade([0, 1, 0]), shade([1, 0, 0])


def scr(u, v, z):
    return (((u - v) * 32 - BX0) * SS, ((u + v) * 16 - 32 - z - BY0) * SS)


def face(ctx, O, U, V):
    """map local (a,b) -> world O + a*U + b*V (U,V world steps per local unit) -> screen; caller restores"""
    p0 = np.array(scr(*O)); pu = np.array(scr(*np.add(O, U))) - p0; pv = np.array(scr(*np.add(O, V))) - p0
    ctx.save(); ctx.transform(cairo.Matrix(pu[0], pu[1], pv[0], pv[1], p0[0], p0[1]))


def FRONT(ctx, u0, v, z0): face(ctx, (u0, v, z0), (1 / T, 0, 0), (0, 0, 1))      # a along +u, b up
def RIGHT(ctx, u, v0, z0): face(ctx, (u, v0, z0), (0, 1 / T, 0), (0, 0, 1))      # a along +v, b up


def poly(ctx, pts, close=True):
    ctx.new_path(); ctx.move_to(*pts[0])
    for p in pts[1:]: ctx.line_to(*p)
    if close: ctx.close_path()


def fill(ctx, pts, col, edge=None, ew=None):
    poly(ctx, pts); ctx.set_source_rgb(*col)
    if edge is not None:
        ctx.fill_preserve(); ctx.set_source_rgb(*edge); ctx.set_line_width(ew); ctx.set_line_join(cairo.LINE_JOIN_ROUND); ctx.stroke()
    else: ctx.fill()


def lin(ctx, pts, col, w, a=1.0):
    poly(ctx, pts, False); ctx.set_source_rgba(*col, a); ctx.set_line_width(w)
    ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.set_line_join(cairo.LINE_JOIN_ROUND); ctx.stroke()


def lg(x0, y0, x1, y1, stops):
    g = cairo.LinearGradient(x0, y0, x1, y1)
    for s in stops:
        if len(s[1]) == 4: g.add_color_stop_rgba(s[0], *s[1])
        else: g.add_color_stop_rgb(s[0], *s[1])
    return g


def u2(x): return x * SS          # game units -> px (screen-space drawing)


# ------------------------------------------------------------------ palettes per variant
THATCH = [['#e6bf62', '#dcb152', '#eecb72', '#d6a84d', '#e2b95c'],      # 0 golden, freshly dried
          ['#dbad58', '#d0a04c', '#e5ba66', '#c99746', '#d6a956'],      # 1 honey tan
          ['#e9ca7c', '#dfbe6c', '#f1d58a', '#d7b464', '#e5c376'],      # 2 pale straw
          ['#d6b16c', '#cba561', '#e0bd7a', '#c19b5a', '#d1ac68']]      # 3 weathered
BAMBOO = '#c9a45c'
STRIP = ['#e8cc8c', '#dfc07c', '#efd69a', '#d9b874', '#e4c786']
EARTH = '#c7a273'


# ------------------------------------------------------------------ bamboo
def pole(ctx, u, v, z0, z1, r, col=BAMBOO, k=1.0, nodes=8.5, top_cap=False, rng=None, stone=False):
    """vertical bamboo post, round, lit from the left; r in game units"""
    xa, ya = scr(u, v, z1); _, yb = scr(u, v, z0); R = u2(r)
    c = C(col, k)
    if stone:                              # a flat river stone the post stands on (đá kê chân cột)
        ctx.save(); ctx.translate(xa + R * 0.2, yb + R * 0.35); ctx.scale(R * 2.0, R * 0.95); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
        ctx.set_source_rgba(0.1, 0.07, 0.03, 0.3); ctx.fill()
        ctx.save(); ctx.translate(xa, yb + R * 0.15); ctx.scale(R * 1.75, R * 0.8); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
        ctx.set_source_rgb(*C('#8f877a', k * 0.8)); ctx.fill()
        ctx.save(); ctx.translate(xa, yb - R * 0.12); ctx.scale(R * 1.7, R * 0.72); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
        ctx.set_source(lg(xa - R * 1.7, 0, xa + R * 1.7, 0, [(0, C('#c9c2b4', k)), (1, C('#a39b8c', k * 0.9))])); ctx.fill()
    if rng is not None and nodes < 50:            # every post its own culm: tone, a slight taper to the top
        col = rng.choice(['#c9a45c', '#bf9a56', '#c8a866', '#b8955a', '#cfab62']); c = C(col, k)
        Rt, Rb = R * 0.88, R * 1.08
    else: Rt = Rb = R
    ctx.set_source(lg(xa - R, 0, xa + R, 0, [(0, mix(C(col, k * 1.02), (1, 1, 1), 0.08)), (0.22, C(col, k * 1.16)), (0.5, c), (0.85, C(col, k * 0.66)), (1, C(col, k * 0.58))]))
    poly(ctx, [(xa - Rt, ya), (xa + Rt, ya), (xa + Rb, yb), (xa - Rb, yb)]); ctx.fill()
    lin(ctx, [(xa - Rt, ya), (xa - Rb, yb)], C(col, k * 0.78), u2(0.14)); lin(ctx, [(xa + Rt, ya), (xa + Rb, yb)], C(col, k * 0.5), u2(0.14))
    if Rt != Rb:
        hz = (yb - ya)
        ctx.set_source(lg(0, yb - min(hz, u2(7)), 0, yb, [(0, (0.35, 0.3, 0.24, 0)), (1, (0.35, 0.3, 0.24, 0.35))]))   # grey, damp foot
        poly(ctx, [(xa - Rt, ya), (xa + Rt, ya), (xa + Rb, yb), (xa - Rb, yb)]); ctx.fill()
        for _ in range(3):                        # fine vertical grain streaks
            gx = xa + rng.uniform(-0.6, 0.6) * R; g0 = ya + rng.uniform(0, 0.4) * hz; g1 = g0 + rng.uniform(0.2, 0.5) * hz
            lin(ctx, [(gx, g0), (gx, min(g1, yb))], C(col, k * rng.choice([0.8, 1.15])), u2(0.1), 0.55)
    n = int((z1 - z0) / nodes)
    for i in range(1, n + 1):
        z = z0 + i * (z1 - z0) / (n + 1) + (rng.uniform(-1, 1) if rng is not None else 0)
        x, y = scr(u, v, z)
        ctx.new_path(); ctx.save(); ctx.translate(x, y); ctx.scale(R, R * 0.42); ctx.arc(0, 0, 1, 0.05, math.pi - 0.05); ctx.restore()
        ctx.set_source_rgb(*C(col, k * 0.55)); ctx.set_line_width(u2(0.32)); ctx.stroke()
        ctx.new_path(); ctx.save(); ctx.translate(x, y - u2(0.45)); ctx.scale(R, R * 0.42); ctx.arc(0, 0, 1, 0.3, math.pi - 0.3); ctx.restore()
        ctx.set_source_rgba(*C(col, k * 1.25), 0.7); ctx.set_line_width(u2(0.2)); ctx.stroke()
    if top_cap:
        ctx.save(); ctx.translate(xa, ya); ctx.scale(R, R * 0.5); ctx.arc(0, 0, 1, 0, 2 * math.pi); ctx.restore()
        ctx.set_source_rgb(*C(col, k * 1.1)); ctx.fill_preserve(); ctx.set_source_rgb(*C(col, k * 0.7)); ctx.set_line_width(u2(0.15)); ctx.stroke()
        ctx.save(); ctx.translate(xa, ya); ctx.scale(R * 0.62, R * 0.3); ctx.arc(0, 0, 1, 0, 2 * math.pi); ctx.restore()
        ctx.set_source_rgb(*C('#4a3218', k)); ctx.fill()



def rail(ctx, p0, p1, w, col=BAMBOO, k=1.0, nodes=9.0, cap=None):
    """horizontal bamboo between two world points; w in game units; lit from above"""
    a = np.array(scr(*p0)); b = np.array(scr(*p1)); d = b - a; Ln = np.linalg.norm(d); d = d / Ln
    nrm = np.array([d[1], -d[0]])
    if nrm[1] > 0: nrm = -nrm                                   # nrm points up on screen
    R = u2(w) / 2
    q = [a + nrm * R, b + nrm * R, b - nrm * R, a - nrm * R]
    m = (a + b) / 2
    ctx.set_source(lg(*(m + nrm * R), *(m - nrm * R), [(0, C(col, k * 1.18)), (0.4, C(col, k)), (1, C(col, k * 0.56))]))
    poly(ctx, [tuple(p) for p in q]); ctx.fill()
    lin(ctx, [tuple(q[2]), tuple(q[3])], C(col, k * 0.5), u2(0.12))
    n = int(Ln / u2(nodes))
    for i in range(1, n + 1):
        c = a + d * Ln * i / (n + 1)
        lin(ctx, [tuple(c + nrm * R * 0.9), tuple(c - nrm * R * 0.9)], C(col, k * 0.55), u2(0.26))
        lin(ctx, [tuple(c + d * u2(0.4) + nrm * R * 0.6), tuple(c + d * u2(0.4) - nrm * R * 0.2)], C(col, k * 1.25), u2(0.14), 0.6)
    if cap is not None:
        e = b if cap == 1 else a
        ctx.save(); ctx.translate(*e); ctx.rotate(math.atan2(d[1], d[0])); ctx.scale(R * 0.45, R); ctx.arc(0, 0, 1, 0, 2 * math.pi); ctx.restore()
        ctx.set_source_rgb(*C(col, k * 1.05)); ctx.fill_preserve(); ctx.set_source_rgb(*C(col, k * 0.6)); ctx.set_line_width(u2(0.12)); ctx.stroke()


def lash(ctx, x, y, s, k=1.0, rng=None):
    """rattan (mây) wraps where two bamboos cross"""
    col = '#7a5228'
    for i in range(4):
        o = (i - 1.5) * s * 0.38
        lin(ctx, [(x - s + o * 0.3, y - s * 0.55 + o), (x + s + o * 0.3, y + s * 0.15 + o)], C(col, k * 0.8), s * 0.36)
        lin(ctx, [(x - s * 0.8 + o * 0.3, y - s * 0.62 + o), (x + s * 0.6 + o * 0.3, y - s * 0.05 + o)], C(col, k * 1.25), s * 0.12, 0.7)


# ------------------------------------------------------------------ woven split-bamboo wall (phên đan nong đôi)
def weave(ctx, Wd, Hd, k, rng, sw=2.0, light_left=True):
    """twill 2/2 weave in face-local units (a 0..Wd, b 0..Hd up); each visible strip piece drawn and shaded"""
    ctx.save(); ctx.rectangle(0, 0, Wd, Hd); ctx.clip()
    ctx.set_source_rgb(*C("#6a5030", k)); ctx.rectangle(0, 0, Wd, Hd); ctx.fill()
    nc, nr = int(Wd / sw) + 2, int(Hd / sw) + 2
    tone_h = [STRIP[rng.integers(5)] for _ in range(nr)]
    tone_v = [STRIP[rng.integers(5)] for _ in range(nc)]
    kh = [rng.uniform(0.96, 1.04) for _ in range(nr)]; kv = [rng.uniform(0.96, 1.04) for _ in range(nc)]
    g = 0.12                                                     # gap between strips
    for j in range(nr):
        for i in range(nc):
            x, y = i * sw, j * sw
            horiz = ((i + j) % 4) < 2
            if horiz:
                start = ((i + j) % 4) == 0                       # strip comes up from under here
                kk = k * kh[j]; base = tone_h[j]
                x0 = x - (0 if start else 0.02); x1 = x + sw + (0.02 if start else 0)
                y0, y1 = y + g, y + sw - g
                c = C(base, kk)
                ctx.set_source(lg(0, y1, 0, y0, [(0, C(base, kk * 1.12)), (0.45, c), (1, C(base, kk * 0.8))]))
                ctx.rectangle(x0, y0, x1 - x0, y1 - y0); ctx.fill()
                # where it dives under / comes up, the strip is in the shadow of the crossing strip
                if start:
                    ctx.set_source(lg(x, 0, x + sw * 0.55, 0, [(0, (0.1, 0.06, 0.02, 0.3)), (1, (0.1, 0.06, 0.02, 0))])); ctx.rectangle(x, y0, sw * 0.55, y1 - y0); ctx.fill()
                else:
                    ctx.set_source(lg(x + sw, 0, x + sw * 0.45, 0, [(0, (0.1, 0.06, 0.02, 0.3)), (1, (0.1, 0.06, 0.02, 0))])); ctx.rectangle(x + sw * 0.45, y0, sw * 0.55, y1 - y0); ctx.fill()
                # grain: two hairlines along the strip
                for t_ in (0.32, 0.7):
                    yy = y0 + (y1 - y0) * t_ + rng.uniform(-0.08, 0.08)
                    lin(ctx, [(x0 + 0.2, yy), (x1 - 0.2, yy + rng.uniform(-0.05, 0.05))], C(base, kk * 0.84), 0.06, 0.8)
                lin(ctx, [(x0, y0), (x1, y0)], C(base, kk * 0.72), 0.08); lin(ctx, [(x0, y1), (x1, y1)], C(base, kk * 0.78), 0.06)
            else:
                start = ((i + j) % 4) == 2
                kk = k * kv[i]; base = tone_v[i]
                x0, x1 = x + g, x + sw - g
                y0 = y - 0.02; y1 = y + sw + 0.02
                c = C(base, kk)
                a0, a1 = (x0, x1) if light_left else (x1, x0)
                ctx.set_source(lg(a0, 0, a1, 0, [(0, C(base, kk * 1.1)), (0.5, c), (1, C(base, kk * 0.8))]))
                ctx.rectangle(x0, y0, x1 - x0, y1 - y0); ctx.fill()
                if start:
                    ctx.set_source(lg(0, y, 0, y + sw * 0.55, [(0, (0.1, 0.06, 0.02, 0.28)), (1, (0.1, 0.06, 0.02, 0))])); ctx.rectangle(x0, y, x1 - x0, sw * 0.55); ctx.fill()
                else:
                    ctx.set_source(lg(0, y + sw, 0, y + sw * 0.45, [(0, (0.1, 0.06, 0.02, 0.28)), (1, (0.1, 0.06, 0.02, 0))])); ctx.rectangle(x0, y + sw * 0.45, x1 - x0, sw * 0.55); ctx.fill()
                for t_ in (0.35, 0.68):
                    xx = x0 + (x1 - x0) * t_
                    lin(ctx, [(xx, y0 + 0.2), (xx + rng.uniform(-0.05, 0.05), y1 - 0.2)], C(base, kk * 0.85), 0.06, 0.8)
                lin(ctx, [(x0, y0), (x0, y1)], C(base, kk * 0.78), 0.06); lin(ctx, [(x1, y0), (x1, y1)], C(base, kk * 0.7), 0.08)
    # weathering: large soft patches, some strips greyed by sun and rain, some newer and warmer
    for _ in range(int(Wd * Hd / 260) + 2):
        cx, cy = rng.uniform(0, Wd), rng.uniform(0, Hd); rx, ry = rng.uniform(5, 12), rng.uniform(3, 8)
        g = cairo.RadialGradient(0, 0, 0, 0, 0, 1)
        if rng.random() < 0.55: g.add_color_stop_rgba(0, 0.42, 0.36, 0.28, 0.1); g.add_color_stop_rgba(1, 0.42, 0.36, 0.28, 0)
        else: g.add_color_stop_rgba(0, 1, 0.9, 0.6, 0.1); g.add_color_stop_rgba(1, 1, 0.9, 0.6, 0)
        ctx.save(); ctx.translate(cx, cy); ctx.scale(rx, ry); ctx.set_source(g); ctx.arc(0, 0, 1, 0, 6.3); ctx.fill(); ctx.restore()
    # rain splash and dust darken the bottom of the wall, smoothly
    ctx.set_source(lg(0, 0, 0, 7, [(0, (0.33, 0.22, 0.1, 0.42)), (1, (0.33, 0.22, 0.1, 0))])); ctx.rectangle(0, 0, Wd, 7); ctx.fill()
    ctx.restore()


# ------------------------------------------------------------------ thatch (lá dừa nước) on a slope, face-local
def thatch(ctx, Lu, Lb, k, rng, pal, course=3.6):
    """courses of folded nipa leaflets, eave at b=0 going up to b=Lb; upper courses lie over lower ones"""
    ctx.save()
    edge = []
    for i in range(41):                    # ragged rakes: leaf ends stick out unevenly at both ends of the slope
        b = -3.0 + (Lb + 3.0) * i / 40
        edge.append((Lu + 0.3 + rng.uniform(-0.25, 0.6), b))
    left = [(-0.3 - rng.uniform(-0.25, 0.6), -3.0 + (Lb + 3.0) * (40 - i) / 40) for i in range(41)]
    poly(ctx, edge + left); ctx.clip()
    ctx.set_source_rgb(*C(pal[3], k * 0.55)); ctx.rectangle(-1, 0, Lu + 2, Lb); ctx.fill()
    # large calm tone patches (older and newer bundles), very low frequency
    patches = [(rng.uniform(0, Lu), rng.uniform(0, Lb), rng.uniform(8, 16), rng.uniform(5, 9), rng.choice([-1, 1]) * rng.uniform(0.04, 0.08)) for _ in range(5)]
    def wk(a, b):
        s = 0.0
        for (pa, pb, ra, rb, amt) in patches:
            d = ((a - pa) / ra) ** 2 + ((b - pb) / rb) ** 2
            if d < 1: s += amt * (1 - d)
        return 1 + s
    n = int(Lb / course) + 3
    bs = [0.0]
    for i in range(n): bs.append(bs[-1] + course * rng.uniform(0.82, 1.15))
    for i in range(n):
        b0 = bs[i] + (-1.3 if i == 0 else 0)
        # shadow the ragged edge throws onto the course below
        if i > 0:
            ctx.set_source(lg(0, b0 + 0.4, 0, b0 - 1.7, [(0, (0.12, 0.07, 0.02, 0.4)), (0.35, (0.12, 0.07, 0.02, 0.22)), (1, (0.12, 0.07, 0.02, 0))]))
            ctx.rectangle(-1.5, b0 - 2.8, Lu + 3, 3.2); ctx.fill()
        x = -1.2 - rng.uniform(0, 0.8)
        while x < Lu + 1.2:
            w = rng.uniform(1.05, 1.7)
            tip = rng.uniform(0.5, 2.0) + (rng.uniform(0.3, 1.1) if i == 0 else 0)
            bot = b0 + rng.uniform(-0.45, 0.45) + 0.4 * math.sin(x * 0.3 + i * 1.7) + 0.25 * math.sin(x * 0.9 + i) - 1.1 * math.sin(math.pi * min(1, max(0, x / Lu))) * (1 - b0 / Lb)
            top = bot + course * 1.9
            base = pal[rng.integers(5)]
            r = rng.random()
            if r < 0.04: base = '#9c7a45'
            elif r < 0.06: base = '#e9cf8c'
            kk = k * wk(x, bot) * rng.uniform(0.95, 1.05)
            sk = rng.uniform(-0.25, 0.25)
            pts = [(x, top), (x + w, top), (x + w + sk * 0.3, bot + 0.25), (x + w * 0.5 + sk, bot - tip), (x + sk * 0.3, bot + 0.3)]
            ctx.set_source(lg(0, top, 0, bot - tip, [(0, C(base, kk * 0.62)), (0.55, C(base, kk * 0.9)), (0.85, C(base, kk * 1.04)), (1, C(base, kk * 1.12))]))
            poly(ctx, pts); ctx.fill_preserve()
            ctx.set_source_rgb(*C(base, kk * 0.8)); ctx.set_line_width(0.1); ctx.set_line_join(cairo.LINE_JOIN_ROUND); ctx.stroke()
            # the leaflet's fold (midrib) and a couple of veins near the exposed end
            mx = x + w * 0.5 + sk * 0.6
            lin(ctx, [(x + w * 0.5, bot + 3.2), (mx, bot - tip * 0.75)], C(base, kk * 0.76), 0.12, 0.9)
            lin(ctx, [(x + w * 0.2, bot + 2.4), (x + w * 0.3 + sk * 0.4, bot - tip * 0.1)], C(base, kk * 0.86), 0.06, 0.8)
            lin(ctx, [(x + w * 0.42, bot + 2.8), (x + w * 0.42 + sk * 0.5, bot - tip * 0.3)], C(base, kk * 1.15), 0.08, 0.35)
            x += w * rng.uniform(0.62, 0.8)
    ctx.restore()


# ------------------------------------------------------------------ geometry
U0, U1, V0, V1 = 0.2, 1.7, 0.2, 1.4            # walls
ZF, ZW = 2.4, 40.0                             # floor top, wall plate
RV, RZ = 0.8, 64.0                             # ridge
EV, EZ = 1.76, 37.0                            # front eave
BV = 0.04                                      # back eave
RU0, RU1 = 0.02, 1.88                          # roof ends (gable overhang)
BZ = RZ - (RV - BV) * (RZ - EZ) / (EV - RV)    # back eave height
SLOPE = np.array([0.0, -(EV - RV), RZ - EZ])   # eave -> ridge, (tiles, tiles, units)
LB = math.hypot((EV - RV) * T, RZ - EZ)        # slope length in game units
SV = (0.0, SLOPE[1] / LB, SLOPE[2] / LB)       # world step per local unit up the slope
K_ROOF = shade([0, (RZ - EZ), (EV - RV) * T])
SMOKE_U = 1.3                                  # the live kitchen smoke rises from the ridge here (sx +16, sy -70)


def tuft(ctx, x, y, rng, sc=1.0):
    """a small clump of grass blades, two greens, tapered"""
    n = rng.integers(6, 10)
    for i in range(n):
        a = -math.pi / 2 + rng.uniform(-0.9, 0.9); L_ = u2(rng.uniform(2.0, 4.0) * sc)
        bx = x + u2(rng.uniform(-1.2, 1.2) * sc)
        tip = (bx + math.cos(a) * L_, y + math.sin(a) * L_ * 0.9)
        mid = (bx + math.cos(a) * L_ * 0.5 + u2(0.3), y + math.sin(a) * L_ * 0.5)
        w = u2(0.42 * sc)
        col = C(rng.choice(['#6f9a3a', '#86ad48', '#5e8a32']), rng.uniform(0.9, 1.08))
        ctx.new_path(); ctx.move_to(bx - w / 2, y); ctx.curve_to(mid[0] - w * 0.3, mid[1], tip[0], tip[1], tip[0], tip[1])
        ctx.curve_to(tip[0], tip[1], mid[0] + w * 0.3, mid[1], bx + w / 2, y); ctx.close_path()
        ctx.set_source_rgb(*col); ctx.fill()


def platform(ctx, rng, k):
    """rammed-earth floor (nền đất nện), 3 units high, softly rounded"""
    u0, u1, v0, v1 = 0.12, 1.88, 0.14, 1.88
    def outline(z, grow=0.0):
        r = 0.11 + grow
        cs = [(u1 - 0.11, v1 - 0.11, 0), (u0 + 0.11, v1 - 0.11, 0.5 * math.pi), (u0 + 0.11, v0 + 0.11, math.pi), (u1 - 0.11, v0 + 0.11, 1.5 * math.pi)]
        out = []
        for (cx, cy, a0) in cs:
            for j in range(10):
                an = a0 + 0.5 * math.pi * j / 9
                out.append((cx + math.cos(an) * r, cy + math.sin(an) * r))
        res = []
        for i, p in enumerate(out):
            w = 0.014 * math.sin(i * 0.9 + 0.4) + 0.009 * math.sin(i * 2.3) + 0.005 * math.sin(i * 5.1)
            res.append((p[0] + w, p[1] + w * 0.8))
        return [scr(p[0], p[1], z) for p in res], res
    top, plan = outline(ZF)
    bot, _ = outline(0, 0.06)
    # earth trodden off the floor onto the yard: a soft uneven skirt, so the floor sits in the ground, not on it
    sk, _ = outline(0, 0.16)
    skirt = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); sc_ = cairo.Context(skirt)
    poly(sc_, sk); sc_.set_source_rgba(0, 0, 0, 1); sc_.fill()
    for _ in range(40):
        pu, pv = rng.uniform(0.0, 2.0), rng.uniform(0.0, 2.0)
        if 0.12 < pu < 1.88 and 0.14 < pv < 1.88: continue
        x_, y_ = scr(pu, pv, 0); sc_.save(); sc_.translate(x_, y_); sc_.scale(u2(rng.uniform(1.5, 4)), u2(rng.uniform(0.8, 2))); sc_.arc(0, 0, 1, 0, 6.3); sc_.restore(); sc_.fill()
    a_ = np.ndarray((H, W, 4), np.uint8, skirt.get_data())[:, :, 3]
    a_ = np.asarray(Image.fromarray(a_.copy()).filter(ImageFilter.GaussianBlur(u2(1.6)))).astype(np.float32) / 255
    ec = np.array(C(EARTH, k * 0.92)) * 255
    sk_img = np.zeros((H, W, 4), np.uint8)
    al_ = a_ * 0.6
    sk_img[:, :, 0] = (ec[2] * al_).astype(np.uint8); sk_img[:, :, 1] = (ec[1] * al_).astype(np.uint8); sk_img[:, :, 2] = (ec[0] * al_).astype(np.uint8); sk_img[:, :, 3] = (al_ * 255).astype(np.uint8)
    sk_s = cairo.ImageSurface.create_for_data(memoryview(sk_img), cairo.FORMAT_ARGB32, W, H)
    ctx.set_source_surface(sk_s, 0, 0); ctx.paint()
    for _ in range(0):                                # (no crumbs: the yard stays calm)
        pu = rng.uniform(0.05, 1.95); pv = 1.92 + rng.uniform(0, 0.08)
        if rng.random() < 0.45: pu, pv = 1.92 + rng.uniform(0, 0.08), rng.uniform(0.1, 1.95)
        x_, y_ = scr(pu, pv, 0); r_ = u2(rng.uniform(0.25, 0.6))
        ctx.save(); ctx.translate(x_, y_); ctx.scale(r_, r_ * 0.6); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
        ctx.set_source_rgb(*C(rng.choice(['#a8845a', '#b8956a', '#9a774e']), k * 0.9)); ctx.fill()
    # sides: stack the outline down 3 units in the shaded tone, then the front-lit part left of the front-right corner
    side = '#a8845a'
    for i in range(13):
        z = ZF * (1 - i / 12)
        pts, _ = outline(z, 0.06 * i / 12)
        ctx.set_source_rgb(*C(side, k * (0.66 - 0.06 * i / 12))); poly(ctx, pts); ctx.fill()
    cx, cy = scr(u1, v1, 0)
    ctx.save(); ctx.rectangle(0, 0, cx, H); ctx.clip()
    for i in range(13):
        z = ZF * (1 - i / 12)
        pts, _ = outline(z, 0.06 * i / 12)
        ctx.set_source_rgb(*C(side, k * (0.9 - 0.12 * i / 12))); poly(ctx, pts); ctx.fill()
    ctx.restore()
    # rammed layers and pits on the side, so it reads as packed earth, not a tray
    ctx.new_path()
    for _ in range(70):
        pu = rng.uniform(0.1, 1.9); pv = 1.9 + 0.04
        if rng.random() < 0.4: pu, pv = 1.9 + 0.04, rng.uniform(0.15, 1.9)
        z_ = rng.uniform(0.3, ZF - 0.4); x_, y_ = scr(pu, pv, z_)
        ctx.save(); ctx.translate(x_, y_); ctx.scale(u2(rng.uniform(0.3, 1.4)), u2(rng.uniform(0.12, 0.25))); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
        ctx.set_source_rgba(*C(rng.choice(['#7e5e3a', '#c4a275']), k * 0.8), 0.45); ctx.fill()
    # top
    ctx.set_source_rgb(*C(EARTH, k)); poly(ctx, top); ctx.fill()
    face(ctx, (0, 0, ZF), (1 / T, 0, 0), (0, 1 / T, 0))       # plan coords in game units (a along u, b along v)
    poly(ctx, [(p[0] * T, p[1] * T) for p in plan]); ctx.clip()
    for j in range(6):
        poly(ctx, [(p[0] * T, p[1] * T) for p in plan]); ctx.set_source_rgba(*C('#7a5a34', k), 0.07); ctx.set_line_width(3.2 - j * 0.5); ctx.stroke()
    # trodden (darker, smoother) earth from the door out and along the porch
    for (cx, cy, rx, ry, a) in [(0.64 * T, 1.66 * T, 12, 6, 0.10), (0.95 * T, 1.62 * T, 26, 5, 0.06), (1.78 * T, 1.0 * T, 4, 22, 0.05)]:
        g = cairo.RadialGradient(0, 0, 0, 0, 0, 1)
        g.add_color_stop_rgba(0, 0.32, 0.2, 0.08, a); g.add_color_stop_rgba(1, 0.32, 0.2, 0.08, 0)
        ctx.save(); ctx.translate(cx, cy); ctx.scale(rx, ry); ctx.set_source(g); ctx.arc(0, 0, 1, 0, 2 * math.pi); ctx.fill(); ctx.restore()
    # broom sweeps: faint arcs, lighter than the floor
    for _ in range(26):
        cx, cy = rng.uniform(0.2, 1.8) * T, rng.uniform(1.45, 1.86) * T
        if rng.random() < 0.35: cx, cy = rng.uniform(1.72, 1.86) * T, rng.uniform(0.3, 1.8) * T
        r = rng.uniform(2.5, 5); a0 = rng.uniform(0, 6.28)
        for j in range(3):
            ctx.new_path(); ctx.arc(cx, cy, r + j * 0.35, a0, a0 + rng.uniform(0.5, 1.0))
            ctx.set_source_rgba(*C(EARTH, k * 1.1), 0.45); ctx.set_line_width(0.16); ctx.stroke()
    # wall-foot occlusion
    for (x0, y0, x1, y1) in [(U0 * T, V1 * T, U1 * T, V1 * T + 4.5)]:
        ctx.set_source(lg(0, y0, 0, y1, [(0, (0.15, 0.09, 0.03, 0.45)), (1, (0.15, 0.09, 0.03, 0))])); ctx.rectangle(x0, y0, x1 - x0, y1 - y0); ctx.fill()
    ctx.set_source(lg(U1 * T, 0, U1 * T + 4.5, 0, [(0, (0.15, 0.09, 0.03, 0.5)), (1, (0.15, 0.09, 0.03, 0))])); ctx.rectangle(U1 * T, V0 * T, 4.5, (V1 - V0) * T); ctx.fill()
    # a few pebbles and dry leaves
    for _ in range(9):
        x, y = rng.uniform(0.2, 1.84) * T, rng.choice([rng.uniform(1.45, 1.84), rng.uniform(0.2, 1.84)]) * T
        if U0 * T < x < U1 * T and V0 * T < y < V1 * T: continue
        if rng.random() < 0.5:
            ctx.save(); ctx.translate(x, y); ctx.scale(0.5, 0.36); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
            ctx.set_source_rgb(*C('#9d8d78', k)); ctx.fill()
        else:
            ctx.save(); ctx.translate(x, y); ctx.rotate(rng.uniform(0, 6.3)); ctx.scale(1.1, 0.42); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
            ctx.set_source_rgb(*C(rng.choice(['#a8783c', '#8f6a3a', '#c09050']), k)); ctx.fill()
    ctx.restore()
    # grass tufts removed (Link 2026-11-08 "bỏ cỏ xung quanh nền"); still drawn to a throwaway surface so the
    # random sequence, and so every other detail of the hut, stays exactly as before
    _ds = cairo.ImageSurface(cairo.FORMAT_ARGB32, 1, 1); _dc = cairo.Context(_ds)
    for _ in range(11):
        if rng.random() < 0.6: pu, pv = rng.uniform(0.15, 1.85), v1 + 0.05
        else: pu, pv = u1 + 0.05, rng.uniform(0.25, 1.8)
        tuft(_dc, *scr(pu, pv, 0), rng, rng.uniform(1.6, 2.3))
    # thin highlight on the lit top edge of the front lip
    lip = [scr(p[0], p[1], ZF) for p in plan if p[1] > 1.84]
    for j in range(0, len(lip) - 1, 2):              # broken highlight: the worn lip catches light in pieces
        if rng.random() < 0.7: lin(ctx, lip[j:j + 2], C(EARTH, k * 1.1), u2(0.22), 0.7)


def front_wall(ctx, rng, t):
    k = K_FRONT
    Wd, Hd = (U1 - U0) * T, ZW - ZF
    FRONT(ctx, U0, V1, ZF)
    weave(ctx, Wd, Hd, k, rng)
    # door opening (u .44-.84, z 3-28) and window (u 1.12-1.44, z 12-23)
    da0, da1, dh = (0.44 - U0) * T, (0.84 - U0) * T, 25.0
    wa0, wa1, wb0, wb1 = (1.12 - U0) * T, (1.44 - U0) * T, 9.0, 20.0
    if NIGHT:
        g = lg(0, dh, 0, 0, [(0, C('#c87a2e', 1, True)), (0.5, C('#f2b252', 1, True)), (1, C('#ffd88a', 1, True))])
    else:
        g = lg(0, dh, 0, 0, [(0, C('#1d130b')), (0.7, C('#2a1c10')), (1, C('#4a3520'))])
    ctx.set_source(g); ctx.rectangle(da0, 0, da1 - da0, dh); ctx.fill()
    # inside: the far floor, a bed edge (bộ ván) and the open door leaf against the right jamb
    fl = C('#6b4a2a', 0.8) if not NIGHT else C('#e09848', 1, True)
    ctx.set_source_rgb(*fl); poly(ctx, [(da0, 0), (da1, 0), (da1 - 1.5, 3.2), (da0 + 1.0, 3.2)]); ctx.fill()
    bed = C('#5a3a20', 0.9) if not NIGHT else C('#9a5a28', 1, True)
    ctx.set_source_rgb(*bed); ctx.rectangle(da0 + 0.6, 3.2, 6.5, 4.6); ctx.fill()
    ctx.set_source_rgb(*mix(bed, (1, 1, 1), 0.12)); ctx.rectangle(da0 + 0.6, 7.2, 6.5, 0.6); ctx.fill()
    ctx.save(); poly(ctx, [(da1 - 4.2, 0.9), (da1, 0), (da1, dh), (da1 - 4.2, dh - 1.5)]); ctx.clip()
    ctx.translate(da1 - 4.2, 0); ctx.scale(0.42, 1)
    leaf_k = 0.45 if not NIGHT else 0.9
    weave(ctx, 10.5, dh, leaf_k, rng, sw=1.8)
    ctx.restore()
    if NIGHT:
        g = cairo.RadialGradient((da0 + da1) / 2, dh * 0.55, 0, (da0 + da1) / 2, dh * 0.55, 13)
        g.add_color_stop_rgba(0, 1, 0.92, 0.6, 0.55); g.add_color_stop_rgba(1, 1, 0.8, 0.4, 0)
        ctx.set_source(g); ctx.rectangle(da0, 0, da1 - da0, dh); ctx.fill()
    # window
    if NIGHT: ctx.set_source(lg(0, wb0, 0, wb1, [(0, C('#e89a40', 1, True)), (1, C('#ffd27a', 1, True))]))
    else: ctx.set_source(lg(0, wb0, 0, wb1, [(0, C('#24170c')), (1, C('#3a2816'))]))
    ctx.rectangle(wa0, wb0, wa1 - wa0, wb1 - wb0); ctx.fill()
    ctx.restore()
    # window bars (round bamboo), sill, lintel; door jambs, lintel, threshold
    for i in range(1, 5):
        u = 1.12 + (1.44 - 1.12) * i / 5
        pole(ctx, u, V1 + 0.006, ZF + wb0, ZF + wb1, 0.55, k=K_FRONT, nodes=99)
    rail(ctx, (1.1, V1 + 0.01, ZF + wb0 - 0.4), (1.46, V1 + 0.01, ZF + wb0 - 0.4), 1.5, k=K_FRONT, cap=1)
    rail(ctx, (1.1, V1 + 0.01, ZF + wb1 + 0.5), (1.46, V1 + 0.01, ZF + wb1 + 0.5), 1.4, k=K_FRONT, cap=1)
    pole(ctx, 0.43, V1 + 0.01, ZF, ZF + dh + 1.5, 1.0, k=K_FRONT, rng=rng)
    pole(ctx, 0.85, V1 + 0.01, ZF, ZF + dh + 1.5, 1.0, k=K_FRONT, rng=rng)
    rail(ctx, (0.4, V1 + 0.012, ZF + dh + 0.8), (0.88, V1 + 0.012, ZF + dh + 0.8), 1.6, k=K_FRONT, cap=1)
    rail(ctx, (0.43, V1 + 0.05, ZF + 0.7), (0.85, V1 + 0.05, ZF + 0.7), 1.6, col='#8a6a44', k=K_FRONT, cap=1)
    # mid rail and corner posts
    rail(ctx, (U0, V1 + 0.012, 13), (0.43, V1 + 0.012, 13), 1.5, k=K_FRONT)
    rail(ctx, (0.85, V1 + 0.012, 13), (U1, V1 + 0.012, 13), 1.5, k=K_FRONT)
    for (u, z) in [(0.43, 13), (0.85, 13), (1.1, 13), (1.46, 13)]:
        x, y = scr(u, V1 + 0.02, z); lash(ctx, x, y, u2(0.9), K_FRONT)
    pole(ctx, U0, V1 + 0.015, ZF, ZW, 1.35, k=K_FRONT, rng=rng)
    pole(ctx, U1, V1 + 0.015, ZF, ZW, 1.35, k=K_FRONT * 0.97, rng=rng)
    for u in (U0, U1):
        x, y = scr(u, V1 + 0.02, 13); lash(ctx, x, y, u2(1.0), K_FRONT)


def eave_shadow(ctx):
    """the deep eave shades the top of the front wall; soft lower edge, shifted right a little (sun from the left)"""
    zs = EZ - (EV - V1) * T * L[2] / L[1]
    sh = (EV - V1) * T * (-L[0]) / L[1] / T                  # shift along u
    top = ZW + 6
    FRONT(ctx, U0 - 0.05, V1 + 0.03, ZF)
    Wd = (U1 - U0 + 0.1) * T
    ctx.set_source(lg(0, zs - ZF - 2.0, 0, zs - ZF + 2.5, [(0, (0.14, 0.08, 0.03, 0)), (1, (0.14, 0.08, 0.03, 0.32))]))
    ctx.rectangle(0, zs - ZF - 2.0, Wd, top - zs + 2.0); ctx.fill()
    ctx.restore()
    return zs


def window_flap(ctx, rng, t):
    """cửa sổ chống: a leaf panel hinged over the window, propped open by a stick"""
    ang = math.radians(52); Lf = 11.0
    zt = ZF + 20.0 + 1.3
    ou = (0, math.sin(ang) / T, -math.cos(ang))
    tipz = zt - Lf * math.cos(ang); tipv = V1 + 0.012 + Lf * math.sin(ang) / T
    rail(ctx, (1.27, V1 + 0.02, ZF + 8.8), (1.27, tipv - 0.02, tipz + 0.4), 0.7, k=K_FRONT, nodes=99)
    face(ctx, (1.08, V1 + 0.012, zt), (1 / T, 0, 0), ou)
    Wf = (1.48 - 1.08) * T
    k = 0.8
    ctx.set_source_rgb(*C('#4a3520', k)); ctx.rectangle(0, 0, Wf, Lf); ctx.fill()
    x = -0.3
    while x < Wf:
        w = rng.uniform(0.9, 1.3); base = THATCH[t][rng.integers(5)]
        pts = [(x, -0.2), (x + w, -0.2), (x + w, Lf - 0.3), (x + w * 0.5, Lf + rng.uniform(0.3, 1.2)), (x, Lf - 0.3)]
        ctx.set_source(lg(0, 0, 0, Lf, [(0, C(base, k * 0.8)), (1, C(base, k * 1.08))]))
        poly(ctx, pts); ctx.fill_preserve(); ctx.set_source_rgb(*C(base, k * 0.72)); ctx.set_line_width(0.08); ctx.stroke()
        x += w * 0.8
    for bb in (1.2, Lf * 0.55):                                   # two bamboo slats across the panel
        ctx.set_source(lg(0, bb - 0.6, 0, bb + 0.6, [(0, C(BAMBOO, k * 0.7)), (1, C(BAMBOO, k * 1.15))])); ctx.rectangle(-0.3, bb - 0.6, Wf + 0.6, 1.2); ctx.fill()
    ctx.restore()


def right_wall(ctx, rng, t):
    k = K_RIGHT
    Wd, Hd = (V1 - V0) * T, ZW - ZF
    RIGHT(ctx, U1, V0, ZF)
    weave(ctx, Wd, Hd, k, rng, light_left=False)
    # warm bounce light from the sunlit yard at the foot of the shaded wall
    ctx.set_source(lg(0, 0, 0, 10, [(0, (0.95, 0.78, 0.5, 0.14 if not NIGHT else 0.04)), (1, (0.95, 0.78, 0.5, 0))])); ctx.rectangle(0, 0, Wd, 10); ctx.fill()
    ctx.restore()
    # gable triangle above the wall plate: vertical nipa leaf panel (vách lá) with a little vent
    RIGHT(ctx, U1, V0, ZW)
    ap = (RV - V0) * T; Wg = (V1 - V0) * T; hg = RZ - 3.6 - ZW
    zr = lambda v: (RZ - 3.6 - (RV - v) * (RZ - EZ) / (EV - RV)) - ZW if v < RV else (RZ - 3.6 - (v - RV) * (RZ - EZ) / (EV - RV)) - ZW
    poly(ctx, [(0, 0), (Wg, 0), (Wg, zr(V1)), (ap, hg), (0, zr(V0))]); ctx.clip()
    ctx.set_source_rgb(*C('#5a4224', k * 0.8)); ctx.paint()
    x = 0.0
    while x < Wg:
        w = rng.uniform(0.9, 1.4); base = THATCH[t][rng.integers(5)]
        for row in range(4):
            y0 = row * 8.5
            pts = [(x, y0 + 9.5), (x + w, y0 + 9.5), (x + w, y0 + 0.6), (x + w * 0.5, y0 - 0.8), (x, y0 + 0.5)]
            ctx.set_source(lg(0, y0 + 9.5, 0, y0 - 0.8, [(0, C(base, k * 0.6)), (0.6, C(base, k * 0.92)), (1, C(base, k * 1.08))]))
            poly(ctx, pts); ctx.fill_preserve(); ctx.set_source_rgb(*C(base, k * 0.74)); ctx.set_line_width(0.08); ctx.stroke()
        x += w * 0.75
    for row in range(1, 5):
        ctx.set_source(lg(0, row * 8.5 + 0.6, 0, row * 8.5 - 2.2, [(0, (0.1, 0.06, 0.02, 0.5)), (1, (0.1, 0.06, 0.02, 0))])); ctx.rectangle(0, row * 8.5 - 2.2, Wg, 2.8); ctx.fill()
        yb = row * 8.5 + 3.0
        ctx.set_source(lg(0, yb + 0.7, 0, yb - 0.7, [(0, C(BAMBOO, k * 1.15)), (1, C(BAMBOO, k * 0.6))])); ctx.rectangle(0, yb - 0.7, Wg, 1.4); ctx.fill()
        for xx in np.arange(3.0, Wg, 7.5):
            lin(ctx, [(xx - 0.5, yb + 0.8), (xx + 0.5, yb - 0.8)], C('#5e3c1c', k), 0.35); lin(ctx, [(xx + 0.2, yb + 0.8), (xx + 1.2, yb - 0.8)], C('#5e3c1c', k), 0.35)
    # smoke vent: a small dark triangle under the apex, crossed by two sticks
    poly(ctx, [(ap - 3.4, hg - 9.5), (ap + 3.4, hg - 9.5), (ap, hg - 4.2)]); ctx.set_source_rgb(*C('#1e140b')); ctx.fill()
    lin(ctx, [(ap - 2.2, hg - 9.6), (ap + 1.2, hg - 5.4)], C(BAMBOO, k * 0.8), 0.45); lin(ctx, [(ap + 2.2, hg - 9.6), (ap - 1.2, hg - 5.4)], C(BAMBOO, k * 0.8), 0.45)
    # shadow of the roof overhang along both rakes
    for (p, q) in [((0, zr(V0)), (ap, hg)), ((Wg, zr(V1)), (ap, hg))]:
        d = np.array(q) - np.array(p); n_ = np.array([d[1], -d[0]]) / np.linalg.norm(d)
        if n_[1] > 0: n_ = -n_
        pp = np.array(p); qq = np.array(q)
        ctx.set_source(lg(*((pp + qq) / 2), *((pp + qq) / 2 + n_ * 3.5), [(0, (0.08, 0.05, 0.02, 0.55)), (1, (0.08, 0.05, 0.02, 0))]))
        poly(ctx, [tuple(pp), tuple(qq), tuple(qq + n_ * 3.5), tuple(pp + n_ * 3.5)]); ctx.fill()
    ctx.restore()
    # frame: back corner post, middle post, rail, wall plate hidden by the roof
    rail(ctx, (U1 + 0.012, V0, 13), (U1 + 0.012, V1, 13), 1.5, k=K_RIGHT)
    pole(ctx, U1 + 0.012, V0, ZF, ZW, 1.35, k=K_RIGHT * 1.02, rng=rng)
    pole(ctx, U1 + 0.012, 0.8, ZF, ZW, 1.2, k=K_RIGHT * 1.02, rng=rng)
    for v in (V0, 0.8):
        x, y = scr(U1 + 0.02, v, 13); lash(ctx, x, y, u2(0.9), K_RIGHT)
    # nia (winnowing tray) hung on the wall
    RIGHT(ctx, U1 + 0.01, V0, ZF)
    cx, cy, R = (0.5 - V0) * T, 14.5, 6.6
    g = cairo.RadialGradient(cx + 0.8, cy - 0.8, R * 0.8, cx + 0.8, cy - 0.8, R * 1.35)
    g.add_color_stop_rgba(0, 0.08, 0.05, 0.02, 0.45); g.add_color_stop_rgba(1, 0.08, 0.05, 0.02, 0)
    ctx.set_source(g); ctx.arc(cx + 0.8, cy - 0.8, R * 1.35, 0, 6.3); ctx.fill()
    ctx.save(); ctx.arc(cx, cy, R - 0.6, 0, 6.3); ctx.clip()
    ctx.translate(cx - R, cy - R); ctx.translate(R, R); ctx.rotate(math.pi / 4); ctx.translate(-R * 1.5, -R * 1.5)
    weave(ctx, R * 3, R * 3, k * 1.08, rng, sw=1.0)
    ctx.restore()
    ctx.save(); ctx.arc(cx, cy, R - 0.6, 0, 6.3); ctx.clip()
    g = cairo.RadialGradient(cx - 2, cy + 2, 1, cx, cy, R)                      # shallow dish: lit near the top-left
    g.add_color_stop_rgba(0, 1, 0.95, 0.8, 0.12); g.add_color_stop_rgba(0.7, 0, 0, 0, 0); g.add_color_stop_rgba(1, 0.1, 0.06, 0.02, 0.35)
    ctx.set_source(g); ctx.paint(); ctx.restore()
    ctx.new_path(); ctx.arc(cx + 0.5, cy - 0.7, R - 0.1, 0, 6.3); ctx.set_source_rgb(*C('#6e5230', k)); ctx.set_line_width(1.5); ctx.stroke()   # rim depth (tray stands off the wall)
    ctx.new_path(); ctx.arc(cx, cy, R - 0.3, 0, 6.3); ctx.set_source_rgb(*C('#b08a4c', k)); ctx.set_line_width(1.3); ctx.stroke()
    ctx.new_path(); ctx.arc(cx, cy, R - 0.3, 0, 6.3); ctx.set_source_rgb(*C('#d4b073', k)); ctx.set_line_width(0.4); ctx.stroke()
    for i in range(36):
        a = i / 36 * 2 * math.pi
        p = (cx + math.cos(a) * (R - 0.9), cy + math.sin(a) * (R - 0.9)); q = (cx + math.cos(a + 0.09) * (R + 0.3), cy + math.sin(a + 0.09) * (R + 0.3))
        lin(ctx, [p, q], C('#6e4a22', k), 0.22)
    lin(ctx, [(cx - 1.4, cy + R - 0.5), (cx, cy + R + 2.6), (cx + 1.4, cy + R - 0.5)], C('#5a3a1a', k), 0.25)
    ctx.new_path(); ctx.arc(cx, cy + R + 2.8, 0.5, 0, 6.3); ctx.set_source_rgb(*C('#6a4a2a', k)); ctx.fill()
    ctx.restore()



def woodpile(ctx, rng):
    """split firewood (củi) stacked against the right wall, end grain toward the viewer's right"""
    k = K_RIGHT * 1.05
    ue = 1.86
    # top surface of the stack running back to the wall
    v0, v1, zt = 0.98, 1.36, 13.0
    logs = []
    rows = [(4.4, 5), (8.2, 4), (11.8, 3)]
    for ri, (zc, n) in enumerate(rows):
        span = (v1 - v0) * T - ri * 1.6
        for j in range(n):
            a = (v0 - V0) * T + ri * 0.8 + (j + 0.5) * span / n
            logs.append((a + rng.uniform(-0.3, 0.3), zc + rng.uniform(-0.3, 0.3), rng.uniform(1.45, 2.2), False, rng.uniform(0, 6.3)))
    # contact shadow on the floor
    x0, y0 = scr(ue + 0.03, v0 - 0.02, ZF); x1, y1 = scr(ue + 0.03, v1 + 0.02, ZF)
    ctx.save(); ctx.translate((x0 + x1) / 2, (y0 + y1) / 2 + u2(0.6)); ctx.rotate(math.atan2(y1 - y0, x1 - x0)); ctx.scale(math.hypot(x1 - x0, y1 - y0) / 2 + u2(1.5), u2(2.2))
    g = cairo.RadialGradient(0, 0, 0, 0, 0, 1); g.add_color_stop_rgba(0, 0.1, 0.06, 0.02, 0.5); g.add_color_stop_rgba(1, 0.1, 0.06, 0.02, 0)
    ctx.set_source(g); ctx.arc(0, 0, 1, 0, 6.3); ctx.fill(); ctx.restore()
    for (a, zc, r, split, rot) in sorted(logs, key=lambda q: q[1]):
        v = V0 + a / T
        # the log's side, back to the wall
        p0 = np.array(scr(ue, v, zc)); p1 = np.array(scr(U1 + 0.02, v, zc))
        R = u2(r)
        ctx.set_source(lg(0, p0[1] - R, 0, p0[1] + R, [(0, C('#7a5634', K_TOP)), (0.5, C('#5e4026', K_FRONT)), (1, C('#3e2a18', K_RIGHT))]))
        poly(ctx, [tuple(p0 + (0, -R)), tuple(p1 + (0, -R)), tuple(p1 + (0, R)), tuple(p0 + (0, R))]); ctx.fill()
        for s in range(3):
            yy = p0[1] - R * 0.6 + s * R * 0.4
            lin(ctx, [(p0[0], yy), (p1[0], yy + (p1[1] - p0[1]))], C('#3a2614', K_FRONT), u2(0.12), 0.7)
    for (a, zc, r, split, rot) in sorted(logs, key=lambda q: q[1]):
        RIGHT(ctx, ue + rng.uniform(-0.035, 0.02), V0, 0)
        ctx.translate(a, zc)
        if split:                                  # a split quarter: wedge with two flat faces and a bark arc
            ctx.rotate(rot)
            span = rng.uniform(0.55, 0.95) * math.pi; r = r * 1.15
            ctx.new_path(); ctx.move_to(0, 0); ctx.arc(0, 0, r, 0, span); ctx.close_path()
            ctx.set_source_rgb(*C('#4a3220', k)); ctx.fill_preserve(); ctx.save(); ctx.clip()
            ctx.new_path(); ctx.move_to(0, 0); ctx.arc(0, 0, r * 0.84, 0, span); ctx.close_path()
            ctx.set_source(lg(-r, r, r, -r, [(0, C('#e6c48e', k * 1.05)), (1, C('#c49860', k * 0.9))])); ctx.fill()
            for rr in (0.35, 0.6):
                ctx.new_path(); ctx.arc(0, 0, r * rr, 0.05, span - 0.05); ctx.set_source_rgba(*C('#a87a48', k), 0.75); ctx.set_line_width(0.1); ctx.stroke()
            ctx.restore()
        else:
            ctx.new_path(); ctx.arc(0, 0, r, 0, 6.3)
            ctx.set_source_rgb(*C('#4a3220', k)); ctx.fill()
            ctx.new_path(); ctx.arc(0, 0, r * 0.82, 0, 6.3)
            wt = rng.choice(['#e6c48e', '#dbb47c', '#e9cc9a', '#cfa46c'])
            ctx.set_source(lg(-r, r, r, -r, [(0, C(wt, k * 1.05)), (1, C(wt, k * 0.86))])); ctx.fill()
            for rr in (0.22, 0.42, 0.62):
                ctx.new_path(); ctx.arc(0, 0, r * rr, 0, 6.3); ctx.set_source_rgba(*C('#a87a48', k), 0.75); ctx.set_line_width(0.1); ctx.stroke()
            for _c in range(2):
                ca = rng.uniform(0, 6.3); rr0 = rng.uniform(0.1, 0.3)
                lin(ctx, [(math.cos(ca) * r * rr0, math.sin(ca) * r * rr0), (math.cos(ca + 0.08) * r * 0.8, math.sin(ca + 0.08) * r * 0.8)], C('#6a4a2a', k), 0.12)
            ctx.new_path(); ctx.arc(0, 0, r * 0.8, 0, 6.3); ctx.set_source_rgba(*C('#7a5230', k), 0.6); ctx.set_line_width(0.22); ctx.stroke()
            ctx.new_path(); ctx.arc(-r * 0.25, r * 0.25, r * 0.5, 0, 6.3); ctx.set_source_rgba(1, 0.95, 0.85, 0.08); ctx.fill()
        ctx.restore()


def jar(ctx, rng, t):
    """lu nước: a glazed brown water jar with a wooden lid and a coconut-shell dipper (gáo dừa)"""
    x, y = scr(0.35, 1.585, ZF)
    s = u2(1)
    R, Hh = 6.2 * s, 13.5 * s
    g = cairo.RadialGradient(0, 0, 0, 0, 0, 1)
    g.add_color_stop_rgba(0, 0.1, 0.06, 0.02, 0.45); g.add_color_stop_rgba(1, 0.1, 0.06, 0.02, 0)
    ctx.save(); ctx.translate(x + 1.5 * s, y); ctx.scale(R * 1.35, R * 0.62); ctx.set_source(g); ctx.arc(0, 0, 1, 0, 6.3); ctx.fill(); ctx.restore()
    def body():
        ctx.new_path()
        ctx.move_to(x - R * 0.62, y)
        ctx.curve_to(x - R * 1.02, y - Hh * 0.25, x - R * 1.08, y - Hh * 0.62, x - R * 0.66, y - Hh * 0.9)
        ctx.line_to(x - R * 0.6, y - Hh); ctx.line_to(x + R * 0.6, y - Hh); ctx.line_to(x + R * 0.66, y - Hh * 0.9)
        ctx.curve_to(x + R * 1.08, y - Hh * 0.62, x + R * 1.02, y - Hh * 0.25, x + R * 0.62, y)
        ctx.save(); ctx.translate(x, y); ctx.scale(R * 0.62, R * 0.25); ctx.arc(0, 0, 1, 0, math.pi); ctx.restore()
        ctx.close_path()
    glaze = '#6e3f22'
    body()
    ctx.set_source(lg(x - R, 0, x + R, 0, [(0, C(glaze, 0.95)), (0.3, C(glaze, 1.18)), (0.62, C(glaze, 0.82)), (1, C(glaze, 0.52))])); ctx.fill_preserve()
    ctx.set_source_rgb(*C(glaze, 0.5)); ctx.set_line_width(0.25 * s); ctx.stroke()
    # unglazed foot band and the glaze drip line
    ctx.save(); body(); ctx.clip()
    ctx.set_source_rgb(*C('#9a6a48', 0.85)); ctx.rectangle(x - R * 1.2, y - Hh * 0.13, R * 2.4, Hh * 0.2); ctx.fill()
    ctx.new_path(); ctx.move_to(x - R * 1.2, y - Hh * 0.13)
    for i in range(13):
        xx = x - R * 1.2 + i * R * 0.2; ctx.line_to(xx, y - Hh * 0.13 - (0.5 + 0.5 * math.sin(i * 2.3)) * 0.9 * s)
    ctx.set_source_rgb(*C(glaze, 0.75)); ctx.set_line_width(0.5 * s); ctx.stroke()
    # highlight
    ctx.save(); ctx.translate(x - R * 0.48, y - Hh * 0.6); ctx.scale(R * 0.16, Hh * 0.22)
    g = cairo.RadialGradient(0, 0, 0, 0, 0, 1); g.add_color_stop_rgba(0, 1, 0.96, 0.88, 0.55); g.add_color_stop_rgba(1, 1, 0.96, 0.88, 0)
    ctx.set_source(g); ctx.arc(0, 0, 1, 0, 6.3); ctx.fill(); ctx.restore()
    ctx.restore()
    # rim and water, lid half across, dipper
    ctx.save(); ctx.translate(x, y - Hh); ctx.scale(R * 0.62, R * 0.27); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
    ctx.set_source_rgb(*C(glaze, 1.05)); ctx.fill()
    ctx.save(); ctx.translate(x, y - Hh + 0.15 * s); ctx.scale(R * 0.5, R * 0.2); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
    ctx.set_source_rgb(*C('#2e3a34', 0.9)); ctx.fill()
    ctx.save(); ctx.translate(x + R * 0.18, y - Hh - 0.5 * s); ctx.rotate(-0.08); ctx.scale(R * 0.55, R * 0.24); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
    ctx.set_source_rgb(*C('#a07a4c', K_TOP)); ctx.fill_preserve(); ctx.set_source_rgb(*C('#6a4a2a')); ctx.set_line_width(0.2 * s); ctx.stroke()
    for i in range(3):
        lin(ctx, [(x - R * 0.25 + i * R * 0.24, y - Hh - 0.4 * s - R * 0.2), (x - R * 0.15 + i * R * 0.24, y - Hh - 0.5 * s + R * 0.18)], C('#7a5a34'), 0.12 * s, 0.8)
    # gáo dừa
    gx, gy = x + R * 0.05, y - Hh - 1.3 * s
    ctx.save(); ctx.translate(gx, gy); ctx.scale(2.3 * s, 1.5 * s); ctx.arc(0, 0, 1, 0, math.pi); ctx.restore()
    ctx.set_source(lg(gx - 2.3 * s, 0, gx + 2.3 * s, 0, [(0, C('#6a4022', 1.1)), (1, C('#3a2210'))])); ctx.fill()
    ctx.save(); ctx.translate(gx, gy); ctx.scale(2.3 * s, 0.7 * s); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
    ctx.set_source_rgb(*C('#c9b088', 0.8)); ctx.fill()
    lin(ctx, [(gx + 1.6 * s, gy - 0.2 * s), (gx + 7.5 * s, gy - 4.0 * s)], C('#b8954e', 1.0), 0.75 * s)
    lin(ctx, [(gx + 1.6 * s, gy - 0.5 * s), (gx + 7.5 * s, gy - 4.3 * s)], C('#e0c27a', 1.0), 0.25 * s, 0.8)


def hang_decor(ctx, rng, t):
    """under the front-left eave: a string of chillies (odd variants) or dried corn (even)"""
    x, y = scr(0.42, 1.7, 34.5)
    s = u2(1)
    lin(ctx, [(x, y - 3 * s), (x, y + 2 * s)], C('#5a3a1a'), 0.35 * s)
    if t % 2 == 1:
        for j in range(5):                         # a tied bunch (chùm ớt): tiers of three, the middle one in front
            yc = y + 1.8 * s + j * 2.1 * s
            for kk_ in (0, 2, 1):
                ang = (kk_ - 1) * 0.6 + rng.uniform(-0.15, 0.15)
                ctx.save(); ctx.translate(x + (kk_ - 1) * 0.35 * s, yc); ctx.rotate(ang)
                Lc, Wc = rng.uniform(3.4, 4.2) * s, rng.uniform(0.95, 1.15) * s
                ctx.new_path(); ctx.move_to(-Wc / 2, 0.2 * s)
                ctx.curve_to(-Wc / 2, Lc * 0.45, -Wc * 0.25, Lc * 0.85, Wc * 0.15, Lc)
                ctx.curve_to(Wc * 0.2, Lc * 0.8, Wc / 2, Lc * 0.45, Wc / 2, 0.2 * s); ctx.close_path()
                red = rng.choice(['#c8281e', '#b81e18', '#d23222'])
                kd = 0.82 if kk_ != 1 else 1.0
                ctx.set_source(lg(-Wc / 2, 0, Wc / 2, 0, [(0, C(red, kd * 1.2)), (0.45, C(red, kd)), (1, C(red, kd * 0.58))])); ctx.fill_preserve()
                ctx.set_source_rgb(*C(red, kd * 0.6)); ctx.set_line_width(0.1 * s); ctx.stroke()
                lin(ctx, [(-Wc * 0.18, 0.8 * s), (-Wc * 0.12, Lc * 0.55)], (1, 0.88, 0.82), 0.22 * s, 0.6 if not NIGHT else 0.15)
                ctx.save(); ctx.translate(0, 0.1 * s); ctx.scale(Wc * 0.55, 0.35 * s); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
                ctx.set_source_rgb(*C('#4f7420')); ctx.fill()
                ctx.restore()
    else:
        for i, (dx, dy, ang) in enumerate([(-1.4, 0.5, 0.18), (0.2, 1.2, -0.04), (1.6, 0.3, -0.22)]):
            ctx.save(); ctx.translate(x + dx * s, y + 2.0 * s + dy * s); ctx.rotate(ang)
            # husks folded up
            for hdx, hc in [(-1.2, '#e8d8a8'), (1.1, '#dccb98'), (0, '#f0e2b8')]:
                ctx.new_path(); ctx.move_to(0, 1.2 * s); ctx.curve_to(hdx * s, 0, hdx * 1.1 * s, -1.6 * s, hdx * 0.6 * s, -2.6 * s); ctx.curve_to(hdx * 0.2 * s, -1.2 * s, 0, 0, 0, 1.2 * s)
                ctx.set_source_rgb(*C(hc, 0.95)); ctx.fill_preserve(); ctx.set_source_rgb(*C(hc, 0.72)); ctx.set_line_width(0.12 * s); ctx.stroke()
            # cob
            ctx.new_path(); ctx.save(); ctx.translate(0, 5.0 * s); ctx.scale(1.25 * s, 4.0 * s); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
            ctx.set_source_rgb(*C('#b8701a', 0.9)); ctx.fill_preserve(); ctx.clip()
            for r_ in range(14):
                for c_ in range(4):
                    kx = (-0.95 + c_ * 0.62 + (0.31 if r_ % 2 else 0)) * s; ky = (1.4 + r_ * 0.6) * s
                    if abs(kx) > 1.25 * s * math.sqrt(max(0, 1 - ((ky - 5 * s) / (4 * s)) ** 2)): continue
                    kk = 1.0 + 0.25 * (1 - abs(kx) / (1.3 * s)) - (0.25 if kx > 0.3 * s else 0)
                    ctx.save(); ctx.translate(kx, ky); ctx.scale(0.3 * s, 0.26 * s); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
                    ctx.set_source_rgb(*C('#f0b42a', kk)); ctx.fill()
            ctx.restore()


def porch_posts(ctx, rng):
    for u in (0.25, 1.65):
        pole(ctx, u, 1.73, ZF, EZ + 0.5, 1.45, k=K_FRONT * 1.04, rng=rng, stone=True)
    # eave beam along the posts (mostly hidden by the thatch edge)
    rail(ctx, (RU0 + 0.05, 1.73, EZ - 0.3), (RU1 - 0.05, 1.73, EZ - 0.3), 1.6, k=K_FRONT)
    for u in (0.25, 1.65):
        x, y = scr(u, 1.74, EZ - 0.4); lash(ctx, x, y, u2(1.0), K_FRONT)


def roof(ctx, rng, t):
    pal = THATCH[t]
    kr = K_ROOF
    Lu = (RU1 - RU0) * T
    # underside of the back slope overhang, seen between the gable and the verge
    fill(ctx, [scr(U1, RV, RZ - 3.6), scr(RU1, RV, RZ - 3.6), scr(RU1, BV, BZ - 3.6), scr(U1, BV, BZ - 3.6)], C(pal[3], K_RIGHT * 0.38))
    ctx.save(); poly(ctx, [scr(U1, RV, RZ - 3.6), scr(RU1, RV, RZ - 3.6), scr(RU1, BV, BZ - 3.6), scr(U1, BV, BZ - 3.6)]); ctx.clip()
    for i in range(160):                           # leaf ribs of the underside
        q = rng.uniform(0, 1); uu = U1 + (RU1 - U1) * rng.uniform(0, 1)
        vv = RV + (BV - RV) * q; zz = RZ - 3.6 + (BZ - RZ) * q
        p0 = scr(uu, vv, zz); p1 = scr(uu + rng.uniform(-0.02, 0.02), vv - rng.uniform(0.03, 0.08), zz - rng.uniform(0.5, 2))
        lin(ctx, [p0, p1], C(pal[rng.integers(5)], K_RIGHT * rng.uniform(0.3, 0.5)), u2(0.25))
    ctx.restore()
    # right verge: thickness of the thatch seen end-on (front and back slopes) + the bit of back slope edge
    RIGHT(ctx, RU1, 0, 0)
    th = 4.4
    fpts = [(EV * T, EZ), (RV * T, RZ), (BV * T, BZ)]
    band = [(EV * T, EZ), (RV * T, RZ + 0.6), (BV * T, BZ), (BV * T, BZ - th), (RV * T, RZ - th), (EV * T, EZ - th)]
    ctx.set_source_rgb(*C(pal[1], K_RIGHT * 0.78)); poly(ctx, band); ctx.fill()
    poly(ctx, band); ctx.save(); ctx.clip()
    for i in range(140):
        f = rng.uniform(0, 1)
        if f < 0.55:
            q = f / 0.55; aa = EV * T + (RV * T - EV * T) * q; zz = EZ + (RZ - EZ) * q
        else:
            q = (f - 0.55) / 0.45; aa = RV * T + (BV * T - RV * T) * q; zz = RZ + (BZ - RZ) * q
        dz = rng.uniform(0.2, th)
        lin(ctx, [(aa, zz - dz), (aa + rng.uniform(-0.6, 0.6), zz - dz - rng.uniform(0.4, 1.1))], C(pal[rng.integers(5)], K_RIGHT * rng.uniform(0.75, 1.05)), 0.18)
    for i in range(int(LB * 6)):                    # leaf ends seen end-on: little bundles, light and dark
        f = rng.uniform(0, 1)
        if f < 0.55: q = f / 0.55; aa = EV * T + (RV * T - EV * T) * q; zz = EZ + (RZ - EZ) * q
        else: q = (f - 0.55) / 0.45; aa = RV * T + (BV * T - RV * T) * q; zz = RZ + (BZ - RZ) * q
        dz = rng.uniform(0.3, th - 0.2)
        ctx.save(); ctx.translate(aa + rng.uniform(-0.4, 0.4), zz - dz); ctx.scale(rng.uniform(0.35, 0.8), rng.uniform(0.25, 0.5)); ctx.arc(0, 0, 1, 0, 6.3); ctx.restore()
        ctx.set_source_rgba(*C(pal[rng.integers(5)], K_RIGHT * rng.uniform(0.55, 1.1)), 0.85); ctx.fill()
    ctx.restore()
    # ragged lower edge of the verge
    pts = []
    for i in range(60):
        q = i / 59
        if q < 0.55: aa = EV * T + (RV * T - EV * T) * q / 0.55; zz = EZ + (RZ - EZ) * q / 0.55
        else: aa = RV * T + (BV * T - RV * T) * (q - 0.55) / 0.45; zz = RZ + (BZ - RZ) * (q - 0.55) / 0.45
        pts.append((aa, zz - th + 0.9 * math.sin(i * 0.7) + 0.6 * math.sin(i * 1.9 + 1.0)))
    for (aa, zz) in pts:                   # leaf tips hanging off the lower edge of the verge
        for j in range(2):
            a2 = aa + rng.uniform(-0.5, 0.5); L_ = rng.uniform(0.6, 1.9) + (rng.uniform(0, 2.4) if rng.random() < 0.35 else 0)
            ctx.new_path(); ctx.move_to(a2 - 0.35, zz + 0.3); ctx.line_to(a2 + 0.35, zz + 0.3); ctx.line_to(a2 + rng.uniform(-0.2, 0.2), zz - L_); ctx.close_path()
            ctx.set_source_rgb(*C(pal[rng.integers(5)], K_RIGHT * rng.uniform(0.62, 0.85))); ctx.fill()
    ctx.restore()
    # eave edge thickness on the front (faces +v)
    face(ctx, (RU0, EV, EZ), (1 / T, 0, 0), (0, 0, 1))
    ctx.set_source_rgb(*C(pal[1], K_FRONT * 0.66)); ctx.rectangle(0, -th, Lu, th + 0.2); ctx.fill()
    for i in range(int(Lu * 4)):
        aa = rng.uniform(0, Lu); z0 = rng.uniform(-th, 0)
        lin(ctx, [(aa, z0), (aa + rng.uniform(-0.3, 0.3), z0 - rng.uniform(0.4, 1.2))], C(pal[rng.integers(5)], K_FRONT * rng.uniform(0.62, 0.95)), 0.16)
    ctx.set_source(lg(0, -th, 0, 0, [(0, (0.08, 0.05, 0.02, 0.45)), (0.6, (0.08, 0.05, 0.02, 0)), (1, (0.08, 0.05, 0.02, 0))])); ctx.rectangle(0, -th, Lu, th); ctx.fill()
    ctx.restore()
    # the front slope
    face(ctx, (RU0, EV, EZ), (1 / T, 0, 0), SV)
    thatch(ctx, Lu, LB + 1.0, kr, rng, pal)
    # soft rim light along the right rake and a darker band where the slope meets the ridge roll
    ctx.set_source(lg(Lu - 2.5, 0, Lu, 0, [(0, (1, 0.95, 0.8, 0)), (1, (1, 0.95, 0.8, 0.12 if not NIGHT else 0.03))])); ctx.rectangle(Lu - 2.5, 0, 2.5, LB); ctx.fill()
    ctx.set_source(lg(0, LB - 5, 0, LB, [(0, (0.1, 0.06, 0.02, 0)), (1, (0.1, 0.06, 0.02, 0.35))])); ctx.rectangle(0, LB - 5, Lu, 5.5); ctx.fill()
    # two bamboo battens holding the thatch down (cây đè), tied every so often
    for bb in (LB * 0.5,):
        ctx.restore()
        p0 = np.add((RU0 + 0.03, EV, EZ), np.multiply(SV, bb)); p1 = np.add((RU1 - 0.01, EV, EZ), np.multiply(SV, bb))
        p0 = tuple(p0 + np.array([0, 0, 0.9])); p1 = tuple(p1 + np.array([0, 0, 0.9]))
        rail(ctx, p0, p1, 1.5, k=kr * 1.02, nodes=8, cap=1)
        for i in range(1, 6):
            q = i / 6; x, y = scr(*np.add(np.multiply(p0, 1 - q), np.multiply(p1, q))); lash(ctx, x, y, u2(0.85), kr)
        face(ctx, (RU0, EV, EZ), (1 / T, 0, 0), SV)
    ctx.restore()
    # ridge cap (nóc): a thick fold of thatch over the ridge; its leaf tips drape down the front slope as a fringe,
    # tied across with rattan; lifts a little over the kitchen smoke vent
    r = 3.4
    a0 = np.array(scr(RU0 - 0.03, RV, RZ + 1.0)); a1 = np.array(scr(RU1 + 0.02, RV, RZ + 1.0))
    d = a1 - a0; Ln = np.linalg.norm(d); d = d / Ln; nrm = np.array([d[1], -d[0]])
    if nrm[1] > 0: nrm = -nrm
    R = u2(r)
    dn = np.array(scr(1, EV, EZ)) - np.array(scr(1, RV, RZ)); dn = dn / np.linalg.norm(dn)     # down the front slope
    hc = np.array(scr(SMOKE_U, RV, RZ + 1.0)); hw = u2(10.0)
    def hump(pt):
        q_ = float((pt - hc) @ d) / hw
        return (0.5 + 0.5 * math.cos(math.pi * min(1.0, abs(q_)))) * R * 0.16
    base = pal[0]
    # smoke slit: dark gap under the lifted stretch, seen on the front side
    sl = [tuple(hc - d * hw * 0.45 - nrm * R * 0.45), tuple(hc + d * hw * 0.45 - nrm * R * 0.45), tuple(hc + d * hw * 0.3 - nrm * R * 0.05), tuple(hc - d * hw * 0.3 - nrm * R * 0.05)]
    fill(ctx, sl, C('#140d07'))
    N = 140
    top, fr = [], []
    for i in range(N + 1):
        c = a0 + d * Ln * i / N; h = hump(c)
        top.append(tuple(c + nrm * (R + h + u2(rng.uniform(-0.1, 0.3)))))
    # fringe: individual leaf tips hanging down the slope from the cap's lower edge
    tips = []
    x = 0.0
    while x < Ln:
        w = u2(rng.uniform(1.0, 1.6)); c = a0 + d * x; h = hump(c)
        root = c - nrm * R * 0.35 + nrm * h * 0.6
        tips.append((root, w, u2(rng.uniform(2.6, 4.4)), pal[rng.integers(5)], rng.uniform(0.92, 1.06)))
        x += w * 0.7
    # shadow the cap throws on the slope below its fringe
    sh = [tuple(a0 - nrm * R * 0.3 + dn * u2(5.5)), tuple(a1 - nrm * R * 0.3 + dn * u2(5.5)), tuple(a1 - nrm * R * 0.3), tuple(a0 - nrm * R * 0.3)]
    ctx.set_source(lg(*(a0 - nrm * R * 0.3), *(a0 - nrm * R * 0.3 + dn * u2(5.5)), [(0, (0.12, 0.07, 0.02, 0.4)), (1, (0.12, 0.07, 0.02, 0))]))
    poly(ctx, sh); ctx.fill()
    # body of the cap
    body = top + [tuple(a1 - nrm * R * 0.4), tuple(a0 - nrm * R * 0.4)]
    m = (a0 + a1) / 2
    ctx.set_source(lg(*(m + nrm * R * 1.1), *(m - nrm * R * 0.4), [(0, C(base, kr * 1.08)), (0.45, C(base, kr * 0.95)), (1, C(base, kr * 0.72))]))
    poly(ctx, body); ctx.fill()
    ctx.save(); poly(ctx, body); ctx.clip()
    for i in range(int(Ln / u2(0.18))):                      # straws draping over the ridge
        c = a0 + d * Ln * rng.uniform(0, 1); h = hump(c)
        p0 = c + nrm * (R + h) + d * u2(rng.uniform(-0.3, 0.3))
        p1 = c - nrm * R * 0.4 + dn * u2(rng.uniform(0, 1.2)) + d * u2(rng.uniform(-0.8, 0.8))
        col = C(pal[rng.integers(5)], kr * rng.uniform(0.82, 1.08))
        lin(ctx, [tuple(p0), tuple((p0 + p1) / 2 + nrm * u2(0.6)), tuple(p1)], col, u2(0.14), 0.8)
    ctx.restore()
    for (root, w, L_, col, kk) in tips:                        # the fringe over the slope
        tip = root + dn * L_ + d * u2(rng.uniform(-0.5, 0.5))
        pts = [tuple(root - d * w / 2), tuple(root + d * w / 2), tuple(root + d * w * 0.45 + dn * L_ * 0.6), tuple(tip), tuple(root - d * w * 0.45 + dn * L_ * 0.6)]
        ctx.set_source(lg(*root, *tip, [(0, C(col, kr * kk * 0.78)), (1, C(col, kr * kk * 1.06))]))
        poly(ctx, pts); ctx.fill_preserve(); ctx.set_source_rgb(*C(col, kr * kk * 0.72)); ctx.set_line_width(u2(0.08)); ctx.stroke()
        lin(ctx, [tuple(root + dn * u2(0.3)), tuple(tip - dn * u2(0.5))], C(col, kr * kk * 0.75), u2(0.09), 0.8)
    for i in range(80):                                        # loose straws on top of the cap
        c = a0 + d * Ln * rng.uniform(0.01, 0.99)
        p = c + nrm * (R * 0.85 + hump(c))
        lin(ctx, [tuple(p), tuple(p + nrm * u2(rng.uniform(0.5, 1.4)) + d * u2(rng.uniform(-1.0, 1.0)))], C(pal[rng.integers(5)], kr * 1.05), u2(0.12), 0.9)
    # rattan ties: bands following the cap's round section
    for u in [RU0 + 0.16 + i * (RU1 - RU0 - 0.3) / 5 for i in range(6)]:
        if abs(u - SMOKE_U) < 0.17: continue
        c = np.array(scr(u, RV, RZ + 1.0)); h = hump(c)
        for j in range(3):
            o = (j - 1) * u2(0.42)
            p0 = c + d * o + nrm * (R + h); p1 = c + d * (o + u2(0.3)) - nrm * R * 0.4 + dn * u2(0.5)
            mid = (p0 + p1) / 2 + d * u2(0.35)
            lin(ctx, [tuple(p0), tuple(mid), tuple(p1)], C('#5e3c1c', kr * 0.95), u2(0.34))
            lin(ctx, [tuple(p0 + d * u2(-0.06) - nrm * u2(0.2)), tuple(mid + d * u2(-0.06))], C('#b08850', kr), u2(0.11), 0.75)
    # right end of the cap: a shaggy cut end in shade
    e = a1 - nrm * R * 0.05
    for i in range(70):
        an = rng.uniform(0, 6.3); rr = rng.uniform(0.15, 1.0)
        p = e + np.array([math.cos(an) * R * 0.45 * rr, math.sin(an) * R * 0.75 * rr])
        lin(ctx, [tuple(p), tuple(p + np.array([u2(rng.uniform(0.2, 0.7)), u2(rng.uniform(-0.2, 0.3))]))], C(pal[rng.integers(5)], K_RIGHT * rng.uniform(0.7, 0.95)), u2(0.16))
    # crossed ridge poles (X) at both ends
    for u in (RU0 + 0.1, RU1 - 0.08):
        top_f = (u, RV - 0.12, RZ + 6.5); bot_f = (u, RV + 0.24, RZ - 5.0)
        top_b = (u, RV + 0.12, RZ + 6.5); bot_b = (u, RV - 0.04, RZ + 2.2)
        rail(ctx, bot_b, top_b, 1.1, k=K_RIGHT * 1.1, nodes=99, cap=1)
        rail(ctx, bot_f, top_f, 1.2, k=kr, nodes=99, cap=1)
        x, y = scr(u, RV, RZ + 2.2); lash(ctx, x, y, u2(1.0), kr)


def contact_shadow():
    """soft shadow the house's floor and eaves throw on the yard around it (blurred separately)"""
    sh = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); c = cairo.Context(sh)
    c.set_source_rgba(0, 0, 0, 1)
    poly(c, [scr(0.06, 0.1, 0), scr(1.98, 0.1, 0), scr(2.02, 1.96, 0), scr(0.08, 1.95, 0)]); c.fill()
    a = np.ndarray((H, W, 4), np.uint8, sh.get_data())[:, :, 3].copy()
    tight = np.asarray(Image.fromarray(a).filter(ImageFilter.GaussianBlur(u2(1.0)))).astype(np.float32) / 255 * 0.42
    c.set_operator(cairo.OPERATOR_CLEAR); c.paint(); c.set_operator(cairo.OPERATOR_OVER)
    c.set_source_rgba(0, 0, 0, 1)                                # the roof's shadow falls past the floor on the shade side
    poly(c, [scr(0.1, 0.02, 0), scr(2.1, 0.02, 0), scr(2.14, 1.9, 0), scr(0.2, 1.98, 0)]); c.fill()
    a = np.ndarray((H, W, 4), np.uint8, sh.get_data())[:, :, 3].copy()
    wide = np.asarray(Image.fromarray(a).filter(ImageFilter.GaussianBlur(u2(3.5)))).astype(np.float32) / 255 * 0.28
    return np.maximum(tight, wide)


EDGE_R, EDGE_K = 9, 0.6          # edge band (render px, odd) and how much darker than the fill it is


def edged(ctx, fn, *a):
    """draw one part on its own layer, then darken a thin band just inside its outline: the game's sprite edge,
    a shade darker than the part's own colours (like the trees), never a black line"""
    s2 = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); c2 = cairo.Context(s2); c2.set_antialias(cairo.ANTIALIAS_GOOD)
    fn(c2, *a); s2.flush()
    buf = np.ndarray((H, W, 4), np.uint8, s2.get_data())
    m = buf[:, :, 3].astype(np.float32) / 255
    solid = np.where(m > 0.7, 255, 0).astype(np.uint8)
    e = np.asarray(Image.fromarray(solid).filter(ImageFilter.MinFilter(EDGE_R))).astype(np.float32) / 255
    ring = np.clip(m - e, 0, 1) * (m > 0.15)
    ring = np.asarray(Image.fromarray((ring * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255 * (m > 0.15)
    f = 1 - (1 - EDGE_K) * ring
    buf[:, :, :3] = np.clip(buf[:, :, :3].astype(np.float32) * f[:, :, None], 0, 255).astype(np.uint8)
    s2.mark_dirty()
    ctx.set_source_surface(s2, 0, 0); ctx.paint()
    return s2


def render(t=0, night=False, seed=None):
    global NIGHT
    NIGHT = night
    rng = np.random.default_rng(1000 + t * 17 if seed is None else seed)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); ctx = cairo.Context(surf)
    ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    edged(ctx, platform, rng, K_TOP)
    edged(ctx, right_wall, rng, t)
    edged(ctx, woodpile, rng)
    edged(ctx, front_wall, rng, t)
    eave_shadow(ctx)
    edged(ctx, window_flap, rng, t)
    edged(ctx, jar, rng, t)
    edged(ctx, hang_decor, rng, t)
    edged(ctx, porch_posts, rng)
    edged(ctx, roof, rng, t)
    if night:                                                   # lamp light spilling out of the door onto the floor
        x0, y0 = scr(0.44, V1, ZF); x1, y1 = scr(0.84, V1, ZF); x2, y2 = scr(0.95, 1.86, ZF); x3, y3 = scr(0.36, 1.86, ZF)
        g = cairo.LinearGradient(0, y0, 0, y3); g.add_color_stop_rgba(0, 1, 0.78, 0.4, 0.5); g.add_color_stop_rgba(1, 1, 0.7, 0.3, 0)
        ctx.set_operator(cairo.OPERATOR_ADD); ctx.set_source(g); poly(ctx, [(x0, y0), (x1, y1), (x2, y2), (x3, y3)]); ctx.fill(); ctx.set_operator(cairo.OPERATOR_OVER)
    surf.flush()
    buf = np.ndarray((H, W, 4), np.uint8, surf.get_data()).copy()       # BGRA premultiplied
    rgb = buf[:, :, [2, 1, 0]].astype(np.float32); al = buf[:, :, 3].astype(np.float32) / 255
    sh = contact_shadow()
    shc = np.array([10, 8, 4], np.float32) if not night else np.array([4, 6, 14], np.float32)
    out_a = al + sh * (1 - al)
    out_rgb = rgb + shc[None, None, :] * (sh * (1 - al))[:, :, None]
    with np.errstate(invalid='ignore', divide='ignore'):
        col = np.where(out_a[:, :, None] > 0, out_rgb / np.maximum(out_a[:, :, None], 1e-6), 0)
    img = np.dstack([np.clip(col, 0, 255), np.clip(out_a * 255, 0, 255)]).astype(np.uint8)
    im = Image.fromarray(img, 'RGBA')
    return im.resize((W // 2, H // 2), Image.LANCZOS)


if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        t = int(sys.argv[3]) if len(sys.argv) > 3 else 0; n = len(sys.argv) > 4 and sys.argv[4] == 'n'
        render(t, n).save(sys.argv[2])
    elif sys.argv[1] == 'atlas':
        import os
        out, tab = sys.argv[2], sys.argv[3]
        frames = {}
        for t in range(4):
            for n in (0, 1):
                im = render(t, bool(n)); bb = im.getbbox()
                frames[('n' if n else 'd') + str(t)] = (im.crop(bb), bb)
        fw = max(f[0].width for f in frames.values()); fh = max(f[0].height for f in frames.values())
        keys = ['d0', 'n0', 'd1', 'n1', 'd2', 'n2', 'd3', 'n3']
        sheet = Image.new('RGBA', (4 * (fw + 2), 2 * (fh + 2)), (0, 0, 0, 0)); G = {}
        sc = SS / 2
        for i, k in enumerate(keys):
            im, bb = frames[k]; x = (i % 4) * (fw + 2); y = (i // 4) * (fh + 2)
            sheet.paste(im, (x, y))
            G[k] = [x, y, im.width, im.height, round(BX0 + bb[0] / sc, 2), round(BY0 + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, 'choi.webp'), 'WEBP', quality=92, method=6)
        json.dump(G, open(tab, 'w'))
        print('sheet', sheet.size, G)
