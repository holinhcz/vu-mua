# The small plants of the build menu's "Hoa cỏ" tab (quarter-tile minis, at.plants.mini_<id>) for Nông Trại Nhỏ,
# redrawn from the real plants as small 3D models in flat game tones with the thin same-colour edge of the other
# new plants (../chuoi SOFT), the same greens as the hibiscus and the mai, the banana kit's camera, sun and night.
# Each mini fits a quarter tile like the old drawings (about 18 game units across).
#   c_xanh      cỏ xanh: a small fresh grass tuft
#   c_lau       cỏ lau nhỏ: a young reed clump with 2-3 silky plumes
#   bui_la      bụi lá: a low rosette of broad glossy leaves
#   da_cuoi     đá cuội: a few smooth river pebbles half in the soil
#   nam         nấm rơm: straw mushrooms on a bit of rice straw
#   h_cuc_vang  cúc vàng: Tết chrysanthemum, full golden double heads
#   h_cuc_trang cúc trắng: cúc họa mi, white daisies with a yellow eye
#   h_muoi_gio  hoa mười giờ (Portulaca): sprawling red stems, small fleshy leaves, cup flowers in mixed colours
#   h_sao_nhai  sao nhái (Cosmos): slender stems, thread leaves, 8 notched petals, orange or pink
#   h_dua_can   dừa cạn (Catharanthus): glossy oval leaves, flat pinwheel flowers, pink or white with a red eye
#   h_tim       hoa tím (Angelonia / xác pháo tím): upright spikes of small purple flowers over lance leaves
#   h_ngu_sac   ngũ sắc (Lantana): rough leaves, domed heads of tiny florets, the ring one colour, the middle yellow
#   h_mong_ga   mồng gà (Celosia cristata): velvety wavy crests on thick stems, red or magenta
#   h_van_tho   vạn thọ (Tagetes): feathery dark leaves, round ruffled orange or yellow heads
# Frames: <id><seed> for seed 0-3, d (day) and n (night).
import math, os, sys
import numpy as np, cairo
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'co', 'dambut'):
    sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import C, nv, mixc, depth, LIGHT, TOCAM, SLIGHT
import co
from co import ground_shadow, Plant, blade, grass_tones
from dambut import hull

UP = np.array([0, 0, 1.0])
DETAIL = True      # v8xx (Link): the same cel style, more detail: two-tone leaves, veins, sheen, petal throats and veins
DENSE = 1.3        # fuller mounds
IDS = ['c_xanh', 'c_lau', 'bui_la', 'da_cuoi', 'nam', 'h_cuc_vang', 'h_cuc_trang', 'h_muoi_gio', 'h_sao_nhai',
       'h_dua_can', 'h_tim', 'h_ngu_sac', 'h_mong_ga', 'h_van_tho',
       'h_lai', 'h_mong_tay', 'h_mai_dia', 'h_huong_duong', 'h_da_yen', 'h_cuc_la_nho',
       'k_luoi_ho', 'k_nha_dam', 'k_xuong_rong', 'k_ot', 'k_sa', 'k_hung_que', 'k_lan_chi']


def greens():
    # the hibiscus / mai greens
    return dict(top=[C('#1f5326'), C('#2b6c2e'), C('#3b883a'), C('#54a346'), C('#72bc58'), C('#8acb64')],
                und=[C('#3e6c35'), C('#4f8041'), C('#62964d')],
                dark=[C('#173f20'), C('#1f5326'), C('#2b6c2e'), C('#3b7a36'), C('#4f9040')],
                stem=C('#4c7a34'), stem_lit=C('#6a9a44'))


def basis(f):
    u = np.cross(f, UP); u = nv(u) if np.linalg.norm(u) > 1e-3 else np.array([1.0, 0, 0])
    return u, nv(np.cross(f, u))


def shade(n, lo=0.3, k=0.62, ao=0.0):
    if n @ TOCAM < 0: n = -n
    return lo + k * float(n @ LIGHT) - ao


def pick(pal, v):
    return pal[max(0, min(len(pal) - 1, int(v * len(pal))))]


class Mini(Plant):
    def __init__(self, kind, seed, pa):
        self.pa = pa; self.kind = kind; self.seed = seed
        self.r = np.random.default_rng(seed * 7919 + IDS.index(kind) * 104729 + 11)
        self.items = []
        self.G = greens()
        self.R = 0.26
        getattr(self, '_' + kind)(self.r)

    # ------------------------------------------------------------------ primitives
    def leaf(self, b, d, L, W, droop=0.35, pal=None, prof=None, teeth=0, rib=True, ao=0.0, key=0.0, und=None, n=9, rib_col=None, rib_w=0.16, extra=None):
        """a flat leaf: leaves b along d, bends down by droop, width W at its widest; lit by its own normal"""
        pa = self.pa; pal = pal or self.G['top']; und = und or self.G['und']
        d = nv(d)
        side = np.cross(UP, d); side = nv(side) if np.linalg.norm(side) > 1e-3 else np.array([1.0, 0, 0])
        prof = prof or [(0, 0.15), (0.12, 0.62), (0.32, 0.96), (0.5, 1.0), (0.7, 0.8), (0.88, 0.42), (1.0, 0.0)]
        cen, tans = [], []
        for i in range(n + 1):
            u = i / n
            cen.append(b + d * L * u - UP * droop * L * u * u)
            tans.append(nv(d - UP * 2 * droop * u))
        def wid(u):
            for (u0, w0), (u1, w1) in zip(prof[:-1], prof[1:]):
                if u0 <= u <= u1: return w0 + (w1 - w0) * (u - u0) / (u1 - u0 + 1e-9)
            return 0.0
        L1, R1 = [], []
        for i, q in enumerate(cen):
            u = i / n; w = W * 0.5 * wid(u)
            if teeth and 0.15 < u < 0.92: w *= (1.18 if i % 2 else 0.86)
            L1.append(q + side * w + UP * w * 0.25); R1.append(q - side * w + UP * w * 0.25)
        nrm = nv(np.cross(side, tans[n // 2]))
        if nrm[2] < 0: nrm = -nrm
        front = nrm @ TOCAM > 0
        v = shade(nrm, ao=ao)
        col = pick(pal if front else und, v)
        poly3 = L1 + R1[::-1]
        dark = mixc(col, C('#0c2410'), 0.32)
        gloss = front and v > 0.62
        def draw():
            P = pa.P; poly = [P(q) for q in poly3]
            pa.fill(poly, col)
            if DETAIL and front:
                cs = [np.array(P(q)) for q in cen]; ls = [np.array(P(q)) for q in L1]; rs = [np.array(P(q)) for q in R1]
                sz = max(np.linalg.norm(cs[-1] - cs[0]), 1e-6)
                c = pa.ctx; c.save(); pa.path(poly); c.clip()
                # the half turned from the sun one tone darker: the leaf reads folded along its midrib
                lit_left = float((np.mean(ls, 0) - np.mean(cs, 0)) @ SLIGHT) > 0
                sh = rs if lit_left else ls; li = ls if lit_left else rs
                pa.path([tuple(q) for q in cs] + [tuple(q) for q in sh[::-1]]); c.set_source_rgba(*dark, 0.5); c.fill()
                # the foot of the leaf sits in the plant's shade
                k3 = max(2, n // 3)
                pa.path([tuple(q) for q in ls[:k3]] + [tuple(q) for q in rs[:k3][::-1]]); c.set_source_rgba(*dark, 0.35); c.fill()
                if sz > pa.u(3.0):   # side veins
                    vc = mixc(col, C('#e4f0b0'), 0.42)
                    for i in range(2, n - 1, 2):
                        for E in (ls, rs):
                            j = min(n, i + 2); tip = cs[i] + (E[j] - cs[i]) * 0.82 + (cs[j] - cs[i]) * 0.3
                            pa.line([tuple(cs[i]), tuple(tip)], vc, pa.u(0.13), 0.6)
                if gloss:            # a pale sheen on the lit half
                    a3 = n // 4; b3 = (n * 2) // 3
                    pts = [tuple(cs[i] + (li[i] - cs[i]) * 0.45) for i in range(a3, b3 + 1)]
                    pa.line(pts, mixc(col, (1, 1, 1), 0.4), pa.u(0.35), 0.4)
                c.restore()
            pa.soft_edge(poly, col)
            if rib and front:
                pa.line([P(q) for q in cen[:-1]], rib_col or mixc(col, C('#e8eeb0'), 0.3), pa.u(rib_w), 0.75 if rib_col is None else 1.0)
            if extra: extra(P, cen, L1, R1, col, front)
        self.items.append((cen[n // 2] + TOCAM * key, draw))

    def stem(self, pts, w0, w1, col, key=0.0):
        pa = self.pa
        def draw():
            sp = [pa.P(q) for q in pts]
            pa.taper(sp, pa.u(w0), pa.u(w1), col, outline=col)
            if DETAIL and pa.u(w0) > 1.2:
                o = SLIGHT * pa.u(w0) * 0.22
                pa.line([(x + o[0], y + o[1]) for x, y in sp], mixc(col, (1, 1, 1), 0.3), pa.u(min(w0, w1)) * 0.3, 0.6)
        self.items.append((pts[len(pts) // 2] + TOCAM * key, draw))

    def disc(self, p, f, r, n=18):
        u, v = basis(f)
        return [p + (math.cos(a) * u + math.sin(a) * v) * r for a in np.linspace(0, 2 * math.pi, n, endpoint=False)]

    def flower(self, p, f, n, R, W, cols, eye=None, eye_r=0.0, cup=0.25, notch=False, ph0=0.0, key=0.08,
               pinwheel=0.0, prof=None, ring_eye=None, layers=1):
        """a radial flower facing f: n petals of length R; cols = (dark, mid, lit, hi)"""
        pa = self.pa
        u, v = basis(f)
        front = f @ TOCAM > 0
        lam = shade(f, 0.42, 0.55)
        prof = prof or [(0.0, 0.25), (0.25, 0.8), (0.55, 1.0), (0.8, 0.85), (1.0, 0.35 if notch else 0.0)]
        petals = []
        for ly in range(layers):
            Rl = R * (1 - 0.28 * ly); cl = cup * (1 + 1.2 * ly)
            for k in range(n):
                a = ph0 + (k + 0.5 * ly) * 2 * math.pi / n
                e = math.cos(a) * u + math.sin(a) * v
                s = -math.sin(a) * u + math.cos(a) * v
                e2 = nv(e + s * pinwheel)
                up = [p + e2 * Rl * t + s * W * 0.5 * w + f * Rl * cl * t * t for t, w in prof]
                lo = [p + e2 * Rl * t - s * W * 0.5 * w * (1 - pinwheel) + f * Rl * cl * t * t for t, w in prof[::-1]]
                pts = up + ([p + e2 * Rl * 1.0 - s * W * 0.12 + f * Rl * cl] if notch else []) + lo
                # a petal tipped toward the light is lighter
                pn = nv(f - e * cl * 1.5)
                vv = lam + 0.12 * float(e @ LIGHT) - (0.12 if not front else 0) - 0.08 * ly
                petals.append((pts, p + e * Rl * 0.6 + f * 0.002 * ly, vv, ly, e2, s, Rl, cl))
        def draw():
            P = pa.P
            for pts, mid, vv, ly, e2, s, Rl, cl in sorted(petals, key=lambda z: (z[3], depth(z[1])) if front else (-z[3], depth(z[1]))):
                col = cols[0] if vv < 0.4 else cols[1] if vv < 0.66 else cols[2] if vv < 0.9 else cols[3]   # v832: fewer washed-out top tones
                poly = [P(q) for q in pts]; pa.fill(poly, col)
                if DETAIL and np.linalg.norm(np.array(P(p + e2 * Rl)) - np.array(P(p))) > pa.u(1.6):
                    c = pa.ctx; c.save(); pa.path(poly); c.clip()
                    # a deeper tone in the throat, fine veins out to the tip
                    x0, y0 = P(p); rr = np.linalg.norm(np.array(P(p + e2 * Rl)) - np.array([x0, y0]))
                    g = cairo.RadialGradient(x0, y0, 0, x0, y0, rr * 0.75)
                    g.add_color_stop_rgba(0, *cols[0], 0.6); g.add_color_stop_rgba(1, *cols[0], 0.0)
                    c.set_source(g); c.paint()
                    vc = mixc(col, cols[0], 0.55)
                    for sv in (-0.28, 0.0, 0.28):
                        a3 = p + e2 * Rl * 0.18 + f * Rl * cl * 0.03
                        b3 = p + e2 * Rl * 0.8 + s * W * sv + f * Rl * cl * 0.64
                        pa.line([P(a3), P(b3)], vc, pa.u(0.09), 0.5)
                    c.restore()
                pa.soft_edge(poly, col)
            if front and ring_eye is not None:
                poly = [P(q) for q in self.disc(p + f * 0.003, f, eye_r * 1.6)]
                pa.fill(poly, ring_eye, seam=False)
            if front and eye is not None:
                poly = [P(q) for q in self.disc(p + f * 0.004, f, eye_r)]
                pa.fill(poly, eye); pa.soft_edge(poly, eye)
                if DETAIL and eye_r > 0.007:   # stamens / seeds round the eye, a lit spot on it
                    u3, v3 = basis(f)
                    for a in np.linspace(0, 2 * math.pi, 9, endpoint=False):
                        x, y = P(p + f * 0.005 + (math.cos(a) * u3 + math.sin(a) * v3) * eye_r * 0.62)
                        pa.ctx.new_path(); pa.ctx.arc(x, y, pa.u(0.16), 0, 2 * math.pi)
                        pa.ctx.set_source_rgb(*mixc(eye, (0, 0, 0), 0.3)); pa.ctx.fill()
                    x, y = P(p + f * 0.006 + (-u3 * 0.3 + v3 * 0.3) * eye_r)
                    pa.ctx.new_path(); pa.ctx.arc(x, y, pa.u(0.22), 0, 2 * math.pi)
                    pa.ctx.set_source_rgba(*mixc(eye, (1, 1, 1), 0.5), 0.8); pa.ctx.fill()
        self.items.append((p + TOCAM * key, draw))

    def blob(self, c, rx, ry, rz, cols, key=0.0, flat=0.0, spots=None, sink=0.0, hi=True):
        """an ellipsoid painted flat: body, a lit patch toward the sun, a shaded crescent away from it"""
        pa = self.pa
        pts = []
        for a in np.linspace(0, 2 * math.pi, 28, endpoint=False):
            for b in np.linspace(-math.pi / 2, math.pi / 2, 11):
                q = c + np.array([math.cos(a) * math.cos(b) * rx, math.sin(a) * math.cos(b) * ry, math.sin(b) * rz])
                if q[2] >= sink: pts.append(q)
        def draw():
            P = pa.P
            H = hull([P(q) for q in pts])
            pa.fill(H, cols[1]); pa.soft_edge(H, cols[1])
            pa.ctx.save(); pa.path(H); pa.ctx.clip()
            k = pa.k
            x, y = P(c)
            # dark side: the hull shifted toward the sun cuts a crescent on the far side
            sh = [(q[0] - LIGHT[0] * rx * k * 0.55, q[1] + LIGHT[1] * 0 + ry * k * 0.0 + LIGHT[2] * rz * k * 0.35) for q in H]
            pa.ctx.set_source_rgb(*cols[0]); pa.path(H); pa.ctx.fill()
            pa.ctx.set_source_rgb(*cols[1])
            pa.path([(q[0] + LIGHT[0] * rx * k * 0.35, q[1] - LIGHT[2] * rz * k * 0.3) for q in H]); pa.ctx.fill()
            pa.ctx.set_source_rgb(*cols[2])
            pa.path([(x + (q[0] - x) * 0.62 + LIGHT[0] * rx * k * 0.3, y + (q[1] - y) * 0.6 - LIGHT[2] * rz * k * 0.35) for q in H]); pa.ctx.fill()
            if spots: spots(H, x, y)
            if DETAIL and hi:
                hx = x + LIGHT[0] * rx * k * 0.35; hy = y - LIGHT[2] * rz * k * 0.45
                pa.ctx.new_path(); pa.ctx.arc(hx, hy, max(0.6, min(rx, rz) * k * 0.22), 0, 2 * math.pi)
                pa.ctx.set_source_rgba(*mixc(cols[2], (1, 1, 1), 0.55), 0.7); pa.ctx.fill()
            pa.ctx.restore()
        self.items.append((c + TOCAM * key, draw))

    # ------------------------------------------------------------------ v836g shaded parts (Link: detail in every pixel)
    def _scr_shape(self, a, b, prof, R):
        """screen outline of a body of revolution from a to b (screen points) with half-width profile prof(t)*R px"""
        a = np.array(a); b = np.array(b); d = b - a; Lp = np.linalg.norm(d) + 1e-6; e = d / Lp; s = np.array([-e[1], e[0]])
        ts = np.linspace(0, 1, 16)
        left = [tuple(a + e * Lp * t + s * R * prof(t)) for t in ts]
        right = [tuple(a + e * Lp * t - s * R * prof(t)) for t in ts[::-1]]
        return left + right, e, s, Lp

    def _cyl_grad(self, a, s, R, cols, hi=True):
        """a linear gradient across a round body: dark rim, lit band toward the sun (left), dark far side"""
        lsx = -1.0 if s[0] > 0 else 1.0      # which side of s faces the light (sun from the left)
        g = cairo.LinearGradient(a[0] - s[0] * R * lsx, a[1] - s[1] * R * lsx, a[0] + s[0] * R * lsx, a[1] + s[1] * R * lsx)
        g.add_color_stop_rgb(0.0, *cols[0]); g.add_color_stop_rgb(0.22, *cols[1]); g.add_color_stop_rgb(0.55, *cols[2])
        g.add_color_stop_rgb(0.8, *(cols[3] if len(cols) > 3 else cols[2])); g.add_color_stop_rgb(1.0, *cols[1])
        return g

    def chili(self, base, d, L, R, cols, key=0.1):
        """ornamental chilli: a glossy tapering cone pointing up out of a green calyx on a short stalk"""
        pa = self.pa; calyx = [C('#2a5a22'), C('#3e7a2e'), C('#5e9a40')]
        tip3 = base + nv(d) * L
        def draw():
            a = np.array(pa.P(base)); b = np.array(pa.P(tip3)); Rp = pa.u(R * 100) / 100 * pa.k / pa.k if False else R * pa.k
            prof = lambda t: (min(1.0, 0.55 + t * 4.0) if t < 0.12 else (1 - (t - 0.12) / 0.88) ** 0.85) * (1 - 0.0 * t)
            poly, e, s, Lp = self._scr_shape(a, b, prof, Rp)
            c = pa.ctx
            # stalk down into the leaves
            pa.taper([tuple(a + e * Rp * 0.2), tuple(a - e * Rp * 1.6 + s * Rp * 0.4)], Rp * 0.32, Rp * 0.26, calyx[1], outline=calyx[0])
            pa.fill(poly, cols[1])
            c.save(); pa.path(poly); c.clip()
            c.set_source(self._cyl_grad(a + e * Lp * 0.35, s, Rp, [cols[0], cols[1], cols[2], cols[3] if len(cols) > 3 else mixc(cols[2], (1, 1, 1), 0.25)]))
            c.paint()
            # tip a shade darker, gloss streak on the lit side
            g = cairo.LinearGradient(*a, *b); g.add_color_stop_rgba(0.6, *cols[0], 0); g.add_color_stop_rgba(1.0, *cols[0], 0.45)
            c.set_source(g); c.paint()
            sl = -1.0 if s[0] > 0 else 1.0
            pa.line([tuple(a + e * Lp * t + s * sl * Rp * 0.42 * prof(t)) for t in np.linspace(0.12, 0.62, 6)], mixc(cols[2], (1, 1, 1), 0.7), Rp * 0.22, 0.85)
            c.restore()
            pa.soft_edge(poly, cols[0])
            # calyx: a little green star cap
            for k in range(5):
                an = k / 5 * 2 * math.pi
                q = a + s * Rp * 0.95 * math.cos(an) + e * Rp * (0.35 + 0.18 * math.sin(an))
                pa.fill([tuple(a - s * Rp * 0.3 + e * Rp * 0.05), tuple(q), tuple(a + s * Rp * 0.3 + e * Rp * 0.05)], calyx[1 + (math.cos(an) < 0)], seam=False)
            pa.fill([tuple(a + s * Rp * 0.8), tuple(a + e * Rp * 0.3 + s * Rp * 0.5), tuple(a + e * Rp * 0.3 - s * Rp * 0.5), tuple(a - s * Rp * 0.8), tuple(a - e * Rp * 0.25)], calyx[1])
        self.items.append((tip3 * 0.5 + base * 0.5 + TOCAM * key, draw))

    def basil_spike(self, base, top, key=0.08):
        """Thai basil flower spike: a purple square stem with whorls of dark purple bracts and tiny lilac-white lipped flowers"""
        pa = self.pa
        pur = [C('#3a1a4e'), C('#5a2a72'), C('#7a4492'), C('#9a68b0')]
        fl = [C('#b8a0d0'), C('#d8c8ec'), C('#f4ecfa')]
        nwh = 6
        def draw():
            a = np.array(pa.P(base)); b = np.array(pa.P(top)); d = b - a; Lp = np.linalg.norm(d) + 1e-6; e = d / Lp; s = np.array([-e[1], e[0]])
            u = pa.k * 0.01
            pa.taper([tuple(a), tuple(b)], u * 0.7, u * 0.4, pur[1], outline=pur[0])
            for j in range(nwh):
                t = 0.1 + 0.86 * j / (nwh - 1); q = a + d * t; sz = u * (1.35 - 0.6 * t)
                # two bracts hanging out to each side, one on the near side
                for sd in (-1, 1):
                    tipb = q + s * sd * sz * 1.25 - e * sz * 0.65
                    poly = [tuple(q + e * sz * 0.25), tuple(q + s * sd * sz * 0.9 + e * sz * 0.35), tuple(tipb), tuple(q + s * sd * sz * 0.6 - e * sz * 0.4), tuple(q - e * sz * 0.2)]
                    pa.fill(poly, pur[1] if sd > 0 else pur[2]); pa.soft_edge(poly, pur[0])
                pa.ctx.new_path(); pa.ctx.arc(*(q - e * sz * 0.1), sz * 0.42, 0, 2 * math.pi); pa.ctx.set_source_rgb(*pur[2 if j % 2 else 1]); pa.ctx.fill()
                # tiny flowers poking out of the whorl (only lower whorls are open)
                if t < 0.6:
                    for f in ((-1, 1) if j % 2 else (0,)):
                        fp = q + s * f * sz * 0.85 + e * sz * (0.5 - 0.2 * abs(f))
                        pa.ctx.new_path(); pa.ctx.save(); pa.ctx.translate(*fp); pa.ctx.scale(sz * 0.34, sz * 0.26); pa.ctx.arc(0, 0, 1, 0, 2 * math.pi); pa.ctx.restore()
                        pa.ctx.set_source_rgb(*fl[1 + (f < 0)]); pa.ctx.fill_preserve(); pa.ctx.set_source_rgba(*fl[0], 0.9); pa.ctx.set_line_width(u * 0.18); pa.ctx.stroke()
            # a closed tip bud
            pa.ctx.new_path(); pa.ctx.arc(*(b + e * u * 0.6), u * 0.8, 0, 2 * math.pi); pa.ctx.set_source_rgb(*pur[1]); pa.ctx.fill()
        self.items.append(((base + top) / 2 + TOCAM * key, draw))

    def pompom(self, c, R, cols, key=0.05, seed=0):
        """v836h a marigold / button-mum pom-pom painted per pixel: a dome packed with ruffled petal lobes
        (phyllotaxis cells), each lit with a dark crease round it, a frilled rim"""
        pa = self.pa
        cs = [np.array(q, float) for q in cols]
        N = 150; ga = math.pi * (3 - math.sqrt(5))
        i = np.arange(N); zc = 1 - (i + 0.5) / N * 1.15; zc = np.clip(zc, -0.15, 1)
        rc = np.sqrt(np.clip(1 - zc * zc, 0, 1)); th = i * ga + seed
        cen = np.stack([rc * np.cos(th), zc, rc * np.sin(th)], 1)   # x right, y up(toward crown), z out of the dome
        # tip the dome toward the viewer: crown up and back
        tilt = 0.9; ct, st = math.cos(tilt), math.sin(tilt)
        cen = np.stack([cen[:, 0], cen[:, 1] * ct + cen[:, 2] * st * 0 - 0, cen[:, 2]], 1)
        L = nv(np.array([-0.5, 0.6, 0.62]))
        def draw():
            k = pa.k; X, Y = pa.P(c); SS = 3
            Rp = R * k
            x0 = int(X - Rp * 1.15) - 2; y0 = int(Y - Rp * 1.05) - 2; W_ = int(Rp * 2.3) + 5; H_ = int(Rp * 2.0) + 5
            yy, xx = np.mgrid[0:H_ * SS, 0:W_ * SS].astype(float)
            ux = ((xx + 0.5) / SS + x0 - X) / Rp; uy = -((yy + 0.5) / SS + y0 - Y) / (Rp * 0.88)
            ang = np.arctan2(uy, ux)
            rim = 1 + 0.06 * np.sin(ang * 13 + seed) + 0.03 * np.sin(ang * 29 + 2 * seed)
            rr = np.hypot(ux, uy) / rim
            m = rr < 1
            nz = np.sqrt(np.clip(1 - rr * rr, 0, 1))
            n = np.stack([ux / rim, uy / rim, nz], -1)
            # dome normal -> petal cells: view dir is +z; crown is +y so map n to dome coords (y up = crown)
            d = n.reshape(-1, 3) @ np.stack([cen[:, 0], cen[:, 1] * 0.55 + 0.45 * np.sqrt(np.clip(1 - cen[:, 1] ** 2, 0, 1)) * 0, cen[:, 2]], 1).T
            dn = n.reshape(-1, 3)
            cc = np.stack([cen[:, 0], cen[:, 2] * 0.3 + cen[:, 1] * 0.7, np.sqrt(np.clip(1 - cen[:, 0] ** 2 - (cen[:, 2] * 0.3 + cen[:, 1] * 0.7) ** 2, 0, 1))], 1)
            cc /= np.linalg.norm(cc, axis=1, keepdims=True)
            dd = dn @ cc.T
            j1 = np.argmax(dd, 1); d1 = dd[np.arange(len(j1)), j1]; dd[np.arange(len(j1)), j1] = -9; d2 = dd.max(1)
            gap = np.clip((d1 - d2) / 0.035, 0, 1).reshape(nz.shape)            # 0 on a crease between petals
            off = (dn - cc[j1]).reshape(n.shape)                                 # where on its petal the pixel sits
            ln = n + off * 2.2                                                   # cupped lobe: edges tilt outward
            ln /= np.linalg.norm(ln, axis=-1, keepdims=True)
            lam = np.clip(ln @ L, 0, 1)
            sh = (0.15 + 0.85 * lam) * (0.32 + 0.68 * gap ** 0.6) * (0.7 + 0.3 * nz)
            edge = np.clip(np.linalg.norm(off, axis=-1) / 0.16, 0, 1)            # petal lip catches light
            sh = np.clip(sh + 0.18 * edge * gap * lam, 0, 1)[..., None]
            col = np.where(sh < 0.35, cs[0] + (cs[1] - cs[0]) * (sh / 0.35), np.where(sh < 0.7, cs[1] + (cs[2] - cs[1]) * ((sh - 0.35) / 0.35), cs[2] + (cs[3] - cs[2]) * np.clip((sh - 0.7) / 0.3, 0, 1)))
            a = m.astype(float)
            from scipy.ndimage import gaussian_filter
            er = gaussian_filter(a, 0.7 * SS)
            col = np.where((m & (er < 0.7))[..., None], cs[0] * 0.8, col)
            col = np.clip(col, 0, 1) * a[..., None]
            h2, w2 = H_, W_
            col = col.reshape(h2, SS, w2, SS, 3).mean((1, 3)); a = a.reshape(h2, SS, w2, SS).mean((1, 3))
            out = np.zeros((h2, w2, 4), np.uint8)
            out[..., 0] = (col[..., 2] * 255).astype(np.uint8); out[..., 1] = (col[..., 1] * 255).astype(np.uint8)
            out[..., 2] = (col[..., 0] * 255).astype(np.uint8); out[..., 3] = (a * 255).astype(np.uint8)
            stride = cairo.ImageSurface.format_stride_for_width(cairo.FORMAT_ARGB32, w2)
            buf = np.zeros((h2, stride // 4, 4), np.uint8); buf[:, :w2] = out
            surf = cairo.ImageSurface.create_for_data(memoryview(buf).cast('B'), cairo.FORMAT_ARGB32, w2, h2, stride)
            cx = pa.ctx; cx.save(); cx.set_source_surface(surf, x0, y0); cx.paint(); cx.restore()
        self.items.append((c + TOCAM * key, draw))

    def leaf_mound(self, n, L, W, R=0.12, el=(15, 55), droop=0.35, pal=None, teeth=0, z0=0.0, prof=None, ao=0.45):
        r = self.r; n = int(round(n * DENSE))
        for j in range(n):
            az = 2 * math.pi * (j + r.uniform(-0.3, 0.3)) / n * 2.618
            out = r.uniform(0.2, 1.0)
            e = math.radians(el[1] - (el[1] - el[0]) * out + r.normal(0, 6))
            d = np.array([math.cos(az) * math.cos(e), math.sin(az) * math.cos(e), math.sin(e)])
            b = np.array([math.cos(az) * R * out * 0.5, math.sin(az) * R * out * 0.5, z0 + (1 - out) * R * 0.6])
            self.leaf(b, d, L * r.uniform(0.8, 1.15), W * r.uniform(0.85, 1.1), droop, pal=pal, teeth=teeth,
                      ao=ao * (1 - out), key=0.04 * out, prof=prof)

    def grass(self, n, L, W=0.022, R=0.035, pal=None, dry=0):
        r = self.r; T = grass_tones()
        dryset = set(r.choice(n, dry, replace=False).tolist()) if dry else set()
        for j in range(n):
            az = 2 * math.pi * (j + r.uniform(-0.4, 0.4)) / n
            ring = r.uniform(0.2, 1)
            base = np.array([math.cos(az) * R * ring, math.sin(az) * R * ring * 0.8, 0.0])
            outer = r.uniform(0, 1) ** 0.8
            blade(self.pa, self.items, base, az, math.radians(84 - 22 * outer + r.normal(0, 4)),
                  L * (0.75 + 0.4 * outer) * r.uniform(0.88, 1.1), W * r.uniform(0.9, 1.1),
                  math.radians(25 + 70 * outer) * r.uniform(0.8, 1.15), T['dry'] if j in dryset else (pal or T['fresh']), r,
                  ao_in=(1 - outer) * 0.7, twist=r.normal(0, 0.35), fold=r.uniform(0.4, 0.6), key_push=0.04 * outer, zmin=0.01)

    def stalk(self, base, top, bow, n=8):
        """points along a gently bowed stalk"""
        mid = (base + top) / 2 + bow
        return [(1 - t) ** 2 * base + 2 * (1 - t) * t * mid + t * t * top for t in np.linspace(0, 1, n)]

    # ------------------------------------------------------------------ kinds
    def _c_xanh(self, r):
        self.grass(int(r.integers(26, 32)), 0.42, 0.024, R=0.05, dry=int(r.integers(0, 2)))
        self.R = 0.24

    def _c_lau(self, r):
        self.grass(int(r.integers(18, 22)), 0.5, 0.02, R=0.05, dry=1)
        lean = r.uniform(0, 2 * math.pi)
        wd = np.array([math.cos(lean), math.sin(lean) * 0.6, 0.0])
        for k in range(int(r.integers(2, 4))):
            a = lean + (k - 1) * 0.5 + r.normal(0, 0.15)
            b = np.array([math.cos(a), math.sin(a), 0]) * 0.02
            top = b + np.array([math.cos(a), math.sin(a), 0]) * r.uniform(0.05, 0.1) + UP * r.uniform(0.62, 0.76)
            pts = self.stalk(b, top, wd * 0.04)
            self.stem(pts, 0.4, 0.26, C('#8c9a56'), key=-0.02)
            self._plume(r, top, nv(pts[-1] - pts[-2]), wd)
        self.R = 0.24

    def _plume(self, r, top, t0, wd):
        """a small silky plume: a curved axis that bends downwind, fine silver strands slanting toward its tip"""
        pa = self.pa
        Pl = dict(sh=C('#a89c88'), mid=C('#cfc5b0'), lit=C('#e6dfcf'), hi=C('#f4efe4'), base=C('#a99c86'))
        L = r.uniform(0.26, 0.32); bend = r.uniform(0.8, 1.2)
        side = nv(wd - t0 * (wd @ t0))
        ax = []; p = top.copy()
        for i in range(13):
            s = i / 12
            d = nv(t0 * math.cos(bend * s ** 1.4) + nv(side - UP * 0.2) * math.sin(bend * s ** 1.4))
            ax.append(p.copy()); p = p + d * L / 12
        W = r.uniform(0.045, 0.055)
        ws = [(min(0.85, 0.04 + (k + r.uniform(0, 1)) / 22 * 0.8), 1 if k % 2 else -1, r.uniform(0.22, 0.34), r.uniform(0.8, 1.15), r.uniform(0, 1)) for k in range(22)]
        def draw():
            P = pa.P
            A = [np.array(P(q)) for q in ax]; n = len(A)
            def at(s):
                s = min(1.0, max(0.0, s)); f = s * (n - 1); i = min(int(f), n - 2); fr = f - i
                d = A[i + 1] - A[i]; d = d / (np.linalg.norm(d) + 1e-9)
                return A[i] * (1 - fr) + A[i + 1] * fr, d, np.array([-d[1], d[0]])
            prof = lambda s: (math.sin(math.pi * min(1.0, 0.02 + s * 0.98)) ** 0.75) * (1 - 0.45 * s ** 1.4)
            Wp = pa.u(W * 29)
            q, d, nr = at(0.4); sg = 1 if nr @ np.array([-0.6, -0.8]) > 0 else -1
            def wisp(s0, sd, la, ln, tone, near):
                q0, _, _ = at(s0); s1 = min(1.0, s0 + la); q1, _, n1 = at(s1)
                e = q1 + n1 * sd * Wp * prof(s1) * ln
                m = at((s0 + s1) / 2); mid = m[0] + m[2] * sd * Wp * prof((s0 + s1) / 2) * ln * 0.85
                pts = [(1 - t) ** 2 * q0 + 2 * (1 - t) * t * mid + t * t * e for t in np.linspace(0, 1, 7)]
                w0 = pa.u(0.55); Lp, Rp = [], []
                for i, p2 in enumerate(pts):
                    t = i / 6; dd = pts[min(i + 1, 6)] - pts[max(i - 1, 0)]; dd = dd / (np.linalg.norm(dd) + 1e-9)
                    nn = np.array([-dd[1], dd[0]]); w = w0 * (1 - t) ** 0.7
                    Lp.append(tuple(p2 + nn * w)); Rp.append(tuple(p2 - nn * w))
                poly = Lp + Rp[::-1]
                col = (Pl['hi'] if tone > 0.6 else Pl['lit']) if near else (Pl['sh'] if tone > 0.4 else Pl['mid'])
                pa.fill(poly, col)
            for z in ws:
                if z[1] != sg: wisp(*z, False)
            bl, br = [], []
            for s in np.linspace(0, 1, 24):
                q, d, nr = at(s); w = Wp * 0.6 * prof(s); bl.append(tuple(q + nr * w)); br.append(tuple(q - nr * w))
            body = bl + [tuple(A[-1])] + br[::-1]
            pa.fill(body, Pl['mid']); pa.soft_edge(body, Pl['mid'], w=0.14)
            for z in ws:
                if z[1] == sg: wisp(*z, True)
        self.items.append((top + TOCAM * 0.2, draw))

    def _bui_la(self, r):
        """v831: a small round leafy bush (pointed leaves on short twigs, in layers up a dome), not a cabbage head"""
        G = self.G
        prof = [(0, 0.15), (0.15, 0.65), (0.4, 1.0), (0.65, 0.92), (0.88, 0.48), (1.0, 0.0)]   # v836g rounder, like dâm bụt
        self.leaf_mound(20, 0.12, 0.06, R=0.15, el=(5, 25), droop=0.45, pal=G['dark'], prof=prof, ao=0.35)
        self.leaf_mound(20, 0.11, 0.062, R=0.13, el=(20, 50), droop=0.4, prof=prof, z0=0.05, ao=0.25)
        self.leaf_mound(16, 0.1, 0.058, R=0.1, el=(30, 65), droop=0.35, prof=prof, z0=0.1)
        self.leaf_mound(11, 0.09, 0.048, R=0.06, el=(45, 80), droop=0.3, pal=G['top'], prof=prof, z0=0.15)
        self.R = 0.24

    def _da_cuoi(self, r):
        tones = [[C('#7e776b'), C('#a59d8e'), C('#cfc7b6')], [C('#6f6c66'), C('#958f86'), C('#bdb7ac')],
                 [C('#8c7f6a'), C('#b4a68c'), C('#d8cbb0')], [C('#77746c'), C('#a19c90'), C('#c9c4b8')]]
        n = int(r.integers(4, 6))
        pos = [(-0.08, -0.01), (0.1, 0.03), (0.01, 0.12), (-0.14, 0.11), (0.14, -0.08)]
        sz = sorted([r.uniform(0.06, 0.11) for _ in range(n)], reverse=True)
        T = grass_tones()
        # a few short blades standing up behind and between the stones
        for j in range(int(r.integers(5, 8))):
            blade(self.pa, self.items, np.array([r.uniform(-0.16, 0.16), r.uniform(-0.13, -0.04), 0.0]), r.uniform(0, 2 * math.pi),
                  math.radians(r.uniform(74, 88)), r.uniform(0.1, 0.17), 0.02, math.radians(r.uniform(12, 35)), T['fresh'], r, zmin=0.005)
        for k in range(n):
            x, y = pos[k]; rr = sz[k]
            self.blob(np.array([x + r.normal(0, 0.01), y + r.normal(0, 0.01), 0.0]), rr * r.uniform(1.05, 1.35), rr * r.uniform(0.8, 1.0),
                      rr * r.uniform(0.5, 0.7), tones[int(r.integers(0, 4))], sink=0.0)
        self.R = 0.24

    def _nam(self, r):
        # a small mat of rice straw under the cluster
        pa = self.pa; straw = [C('#a8863a'), C('#c8a650'), C('#e0c470')]
        bits = []
        for j in range(22):
            a = r.uniform(0, math.pi); c = np.array([r.normal(0, 0.09), r.normal(0, 0.07), 0.004])
            L = r.uniform(0.1, 0.2); d = np.array([math.cos(a), math.sin(a), 0]) * L / 2
            bits.append((c - d, c + d, straw[j % 3]))
        def draw():
            for a, b, col in bits:
                pa.line([pa.P(a), pa.P(b)], mixc(col, (0, 0, 0), 0.25), pa.u(0.85))
                pa.line([pa.P(a), pa.P(b)], col, pa.u(0.55))
        self.items.append((np.array([0, -0.3, 0.0]), draw))
        # straw mushrooms are picked young: grey egg-shaped buttons, dark on top, pale at the foot, in a tight cluster;
        # one or two have split open into a bell cap on a white stem
        egg = [C('#6a645c'), C('#9a948a'), C('#c8c2b6')]
        top_c = C('#4a443e')
        spots = [(0.0, 0.0, 1.15), (-0.06, 0.03, 1.0), (0.06, 0.035, 0.95), (-0.03, -0.05, 0.85), (0.05, -0.05, 0.8),
                 (-0.1, -0.02, 0.7), (0.1, -0.01, 0.65)]
        nb = int(r.integers(5, 8)); opened = {int(r.integers(1, nb))}
        for idx, (x, y, s) in enumerate(spots[:nb]):
            x *= 1.4; y *= 1.4; x += r.normal(0, 0.006); y += r.normal(0, 0.006); s *= r.uniform(0.9, 1.1) * 1.5
            def cap_fn(H, cx, cy, s=s):
                # the dark brown-grey top of the button
                pa.ctx.save(); pa.ctx.translate(cx - pa.k * 0.006 * s, cy - pa.k * 0.03 * s); pa.ctx.scale(1, 0.75)
                pa.ctx.new_path(); pa.ctx.arc(0, 0, pa.k * 0.026 * s, 0, 2 * math.pi); pa.ctx.restore()
                pa.ctx.set_source_rgba(*top_c, 0.85); pa.ctx.fill()
            if idx in opened:
                H = 0.07 * s
                self.stem([np.array([x, y, 0.0]), np.array([x, y, H])], 2.2 * s, 1.8 * s, C('#e6dfd0'))
                self.blob(np.array([x, y, H]), 0.05 * s, 0.05 * s, 0.035 * s, egg, key=0.01, sink=H - 0.004, spots=cap_fn)
            else:
                self.blob(np.array([x, y, 0.045 * s]), 0.036 * s, 0.034 * s, 0.05 * s, egg, key=0.01, spots=cap_fn)
        self.R = 0.22

    def _daisy_base(self, r, n=12, L=0.14, W=0.06, teeth=1):
        prof = [(0, 0.1), (0.15, 0.45), (0.4, 0.9), (0.6, 1.0), (0.8, 0.8), (1.0, 0.0)]
        self.leaf_mound(n, L, W, R=0.08, el=(10, 45), droop=0.35, teeth=teeth, prof=prof, pal=self.G['dark'] if teeth else None)

    def _stems_heads(self, r, n, H, spread, fn):
        """n stems out of the clump to flower heads round height H; fn(top, facing) draws a head"""
        G = self.G
        for k in range(n):
            a = 2 * math.pi * (k + r.uniform(-0.3, 0.3)) / n + r.uniform(0, 1)
            out = spread * r.uniform(0.3, 1.0)
            top = np.array([math.cos(a) * out, math.sin(a) * out * 0.85, H * r.uniform(0.75, 1.1)])
            b = np.array([math.cos(a), math.sin(a), 0]) * 0.02
            pts = self.stalk(b, top, np.array([0, 0, 0.02]))
            self.stem(pts, 0.36, 0.26, G['stem'], key=-0.03)
            f = nv(np.array([math.cos(a) * 0.45, math.sin(a) * 0.45 + 0.25, 1.0]) + r.normal(0, 0.15, 3))
            fn(top, f, k)

    def _h_cuc_vang(self, r):
        self._daisy_base(r, 16, 0.17, 0.08)
        cols = (C('#b86a00'), C('#e89a08'), C('#ffc21a'), C('#ffe266'))
        def head(top, f, k):     # v836h a full double mum: wider petals, 4 layers cupping in to a tight centre
            self.flower(top, f, 15, 0.064, 0.026, cols, eye=C('#c88410'), eye_r=0.009, cup=0.6, layers=4, ph0=k)
        self._stems_heads(r, int(r.integers(5, 7)), 0.3, 0.13, head)
        self.R = 0.24

    def _h_cuc_trang(self, r):
        self._daisy_base(r, 12, 0.15, 0.06)
        cols = (C('#c9ccd6'), C('#e2e4ea'), C('#f6f6f6'), C('#ffffff'))
        def head(top, f, k):
            self.flower(top, f, 18, 0.064, 0.015, cols, eye=C('#f2b81e'), eye_r=0.021, cup=0.12, ph0=k,
                        ring_eye=C('#e09a14'), layers=2)
        self._stems_heads(r, int(r.integers(5, 7)), 0.27, 0.12, head)
        self.R = 0.24

    def _h_muoi_gio(self, r):
        # a low mat: reddish stems spread over the soil, short fleshy finger leaves in little rosettes along them,
        # cup flowers on top of the mat as well as at the stem tips
        sc = C('#a8483a'); lf = [C('#3b7a2e'), C('#4f9438'), C('#6aae46'), C('#86c458')]
        fleshy = [(0, 0.7), (0.25, 1.0), (0.75, 0.95), (1.0, 0.5)]
        tips = []
        for k in range(10):
            a = 2 * math.pi * k / 10 + r.uniform(-0.25, 0.25)
            L = r.uniform(0.15, 0.24)
            tip = np.array([math.cos(a) * L, math.sin(a) * L * 0.85, r.uniform(0.05, 0.09)])
            pts = self.stalk(np.zeros(3), tip, np.array([0, 0, 0.04]))
            self.stem(pts, 0.6, 0.45, sc, key=-0.04)
            for q in (pts[3], pts[5], pts[7]):
                for j in range(6):
                    az = r.uniform(0, 2 * math.pi)
                    d = np.array([math.cos(az) * 0.6, math.sin(az) * 0.6, r.uniform(0.4, 1.0)])
                    self.leaf(q, d, r.uniform(0.04, 0.055), 0.018, 0.1, pal=lf, rib=False, key=0.01, prof=fleshy)
            tips.append(tip)
        for j in range(3):
            a = r.uniform(0, 2 * math.pi); rr = r.uniform(0.0, 0.07)
            tips.append(np.array([math.cos(a) * rr, math.sin(a) * rr, 0.1]))
        # v832 (Link: "mờ màu vừa nhạt"): portulaca is vivid, satin magenta / scarlet / orange / lemon, never pastel
        PK = ('#ec1c84', '#b00c5c', '#ff3c9a', '#ff6cb4'); RD = ('#e8201c', '#a80c0e', '#ff3a28', '#ff6448')
        OR = ('#ff7010', '#c44c06', '#ff8c1c', '#ffaa3a'); YE = ('#ffc80c', '#c89400', '#ffd828', '#ffe866')
        MG = ('#c418a0', '#86086c', '#e03cbc', '#f466d0')
        sets = [[PK, RD], [OR, YE], [PK, YE, MG], [RD, OR, MG]][self.seed % 4]
        for k, tip in enumerate(tips):
            if k < 10 and k % 3 == 2: continue
            cs = sets[k % len(sets)]
            cols = (C(cs[1]), C(cs[0]), C(cs[2]), C(cs[3]))
            f = nv(np.array([tip[0] * 3, tip[1] * 3 + 0.3, 1.0]))
            self.flower(tip + UP * 0.014, f, 5, 0.056, 0.05, cols, eye=C('#f8d24a'), eye_r=0.01, cup=0.4, ph0=k)
        self.R = 0.25

    def _h_sao_nhai(self, r):
        """v836h sao nhái (Cosmos): a loose bush of lacy thread-like bipinnate leaves, branching stems,
        broad notched petals with a darker throat round a gold disc, a few round buds"""
        pa = self.pa; G = self.G
        orange = self.seed % 2 == 0
        cols = (C('#d4601a'), C('#f07a1e'), C('#ff9a32'), C('#ffbe5a')) if orange else (C('#b8306e'), C('#e0508e'), C('#f27ab0'), C('#ff9ec8'))
        lt = [C('#2a6a2a'), C('#3c8434'), C('#58a040'), C('#78bc54')]
        def feather(q, d, L, key):
            """one lacy leaf: a rachis with paired thread leaflets, each with 2-3 side threads"""
            d = nv(d); side = nv(np.cross(UP, d) + np.array([1e-4, 0, 0]))
            segs = []
            n = 6
            for i in range(n):
                t = (i + 1) / (n + 1); b = q + d * L * t - UP * 0.15 * L * t * t
                ln = L * 0.42 * (1 - 0.55 * t)
                for sd in (1, -1):
                    e = nv(d * 0.75 + side * sd + UP * 0.15)
                    tip = b + e * ln
                    segs.append((b, tip, sd, 0))
                    for j in (0.35, 0.7):
                        m = b + e * ln * j
                        e2 = nv(e * 0.6 + d * 0.5 + side * sd * 0.3 + UP * 0.2)
                        segs.append((m, m + e2 * ln * 0.38, sd, 1))
            rach = [q + d * L * t - UP * 0.15 * L * t * t for t in np.linspace(0, 1, 6)]
            def draw():
                P = pa.P
                pa.line([P(x) for x in rach], lt[1], pa.u(0.2))
                for a3, b3, sd, lv in segs:
                    lit = sd * (-LIGHT[0]) > 0
                    pa.line([P(a3), P(b3)], lt[2 + (1 if lit and lv else 0)] if lit else lt[1 + lv], pa.u(0.17 - 0.03 * lv))
            self.items.append((q + d * L * 0.5 + TOCAM * key, draw))
        # a low cloud of leaves round the foot
        for k in range(9):
            a = 2 * math.pi * k / 9 + r.uniform(-0.3, 0.3)
            q = np.array([math.cos(a), math.sin(a), 0]) * 0.02 + UP * r.uniform(0.02, 0.08)
            feather(q, np.array([math.cos(a), math.sin(a), r.uniform(0.3, 0.8)]), r.uniform(0.12, 0.16), -0.02)
        for k in range(int(r.integers(5, 7))):
            a = 2 * math.pi * k / 6 + r.uniform(-0.4, 0.4)
            out = r.uniform(0.08, 0.17)
            top = np.array([math.cos(a) * out, math.sin(a) * out * 0.85, r.uniform(0.46, 0.62)])
            pts = self.stalk(np.zeros(3), top, np.array([math.cos(a), math.sin(a), 0]) * 0.04)
            self.stem(pts, 0.42, 0.28, C('#4a7a30'), key=-0.05)
            for i, q in enumerate(pts[1:-2]):
                az = a + (1 if i % 2 else -1) * r.uniform(0.9, 1.6)
                feather(q, np.array([math.cos(az), math.sin(az), 0.55]), 0.11 * (1 - 0.1 * i), -0.03)
            f = nv(np.array([math.cos(a) * 0.3, math.sin(a) * 0.3 + 0.35, 1.0]))
            self.flower(top, f, 8, 0.058, 0.04, cols, eye=C('#e0a020') if orange else C('#f2c22a'), eye_r=0.014,
                        cup=0.12, notch=True, ph0=k, ring_eye=cols[0], prof=[(0, 0.35), (0.3, 0.9), (0.7, 1.0), (1.0, 0.92)])
            if k % 2 == 0:      # a side branch with a bud
                bq = pts[len(pts) // 2]; bt = bq + nv(np.array([math.cos(a + 0.8), math.sin(a + 0.8), 1.6])) * 0.14
                self.stem([bq, (bq + bt) / 2 + UP * 0.01, bt], 0.3, 0.22, C('#4a7a30'), key=-0.04)
                self.blob(bt, 0.011, 0.011, 0.013, [cols[0], cols[1], cols[2]], key=0.06)
                for j in range(5):
                    an = j / 5 * 2 * math.pi
                    self.leaf(bt - UP * 0.008, np.array([math.cos(an), math.sin(an), -0.4]), 0.012, 0.004, 0.0, pal=lt + lt[-1:] * 2, rib=False, key=0.07)
        self.R = 0.24

    def _h_dua_can(self, r):
        prof = [(0, 0.15), (0.15, 0.6), (0.4, 1.0), (0.65, 0.92), (0.88, 0.45), (1.0, 0.0)]
        self.leaf_mound(20, 0.14, 0.062, R=0.12, el=(8, 38), droop=0.25, prof=prof)
        self.leaf_mound(16, 0.13, 0.056, R=0.1, el=(30, 65), droop=0.25, prof=prof, z0=0.08)
        white = self.seed % 2 == 1
        cols = (C('#d8d4dc'), C('#ece8ee'), C('#faf8fa'), C('#ffffff')) if white else (C('#c02e78'), C('#de4a96'), C('#f06cae'), C('#ff92c6'))
        n = int(r.integers(6, 8))
        for k in range(n):
            a = 2 * math.pi * k / n + r.uniform(-0.3, 0.3); out = r.uniform(0.07, 0.15) if k else 0.0
            p = np.array([math.cos(a) * out, math.sin(a) * out * 0.9, 0.2 - out * 0.45])
            f = nv(np.array([math.cos(a) * out * 6, math.sin(a) * out * 6 + 0.3, 1.0]))
            self.flower(p, f, 5, 0.056, 0.048, cols, eye=C('#c8204a'), eye_r=0.009, cup=0.05, pinwheel=0.35, ph0=k,
                        prof=[(0, 0.2), (0.3, 0.7), (0.65, 1.0), (0.9, 0.8), (1.0, 0.3)], key=0.12)
        self.R = 0.25

    def _h_tim(self, r):
        G = self.G; pa = self.pa
        prof = [(0, 0.1), (0.2, 0.7), (0.45, 1.0), (0.75, 0.6), (1.0, 0.0)]
        self.leaf_mound(12, 0.14, 0.04, R=0.07, el=(25, 70), droop=0.3, prof=prof)
        pur = [C('#5a2c94'), C('#7a42b8'), C('#9a62d8'), C('#b888ec')]
        for k in range(int(r.integers(3, 5))):
            a = 2 * math.pi * k / 4 + r.uniform(-0.4, 0.4); out = r.uniform(0.02, 0.07)
            top = np.array([math.cos(a) * out, math.sin(a) * out, r.uniform(0.5, 0.62)])
            base = np.array([math.cos(a) * 0.01, math.sin(a) * 0.01, 0.0])
            pts = self.stalk(base, top, np.array([0, 0, 0]))
            self.stem(pts, 0.3, 0.18, G['stem'], key=-0.03)
            # small two-lipped flowers all round the upper half of the spike, smaller and closed near the tip
            for j in range(9):
                s = 0.45 + 0.55 * j / 9
                q = base + (top - base) * s
                for sd in range(2):
                    az = j * 2.2 + sd * math.pi + r.uniform(-0.3, 0.3)
                    f = nv(np.array([math.cos(az), math.sin(az) + 0.25, 0.25]))
                    sz = 0.022 * (1 - 0.55 * (s - 0.45) / 0.55)
                    if s > 0.9:
                        self.blob(q + f * 0.008, sz * 0.5, sz * 0.5, sz * 0.7, pur[:3], key=0.01)
                    else:
                        self.flower(q + f * 0.01, f, 4, sz, sz * 0.9, pur, eye=C('#f4f0ff'), eye_r=sz * 0.18, cup=0.3, ph0=az, key=0.02)
        self.R = 0.2

    def _h_ngu_sac(self, r):
        G = self.G; pa = self.pa
        prof = [(0, 0.15), (0.15, 0.6), (0.4, 1.0), (0.65, 0.9), (0.88, 0.45), (1.0, 0.0)]
        self.leaf_mound(16, 0.13, 0.07, R=0.12, el=(8, 35), droop=0.3, prof=prof, teeth=1, pal=G['dark'])
        self.leaf_mound(12, 0.12, 0.065, R=0.1, el=(25, 60), droop=0.3, prof=prof, teeth=1, z0=0.06)
        sets = [(('#ff8a2a', '#e0601a', '#ffa84a', '#ffc070'), ('#ffd23a', '#e8b020', '#ffe46a', '#fff0a0')),
                (('#f2589a', '#c8327a', '#ff8ab8', '#ffb4d4'), ('#ffd23a', '#e8b020', '#ffe46a', '#fff0a0')),
                (('#e2302a', '#b8201e', '#f45a46', '#ff8a70'), ('#ff9a2a', '#d4701a', '#ffb84a', '#ffd88a')),
                (('#fff4d0', '#e6d6a8', '#ffffff', '#ffffff'), ('#ffd23a', '#e8b020', '#ffe46a', '#fff0a0'))][self.seed % 4]
        ring = [C(c) for c in sets[0]]; mid = [C(c) for c in sets[1]]
        n = int(r.integers(5, 7))
        for k in range(n):
            a = 2 * math.pi * k / n + r.uniform(-0.3, 0.3); out = r.uniform(0.05, 0.14) if k else 0.0
            c = np.array([math.cos(a) * out, math.sin(a) * out * 0.85, 0.16 - out * 0.35])
            f = nv(np.array([math.cos(a) * out * 5, math.sin(a) * out * 5 + 0.3, 1.0]))
            u, v = basis(f); R = 0.046
            # v836i a domed posy: 12 outer florets in the head's colour, 7 half-turned ones, 4 young yellow ones on top
            flo = [(c + (math.cos(th) * u + math.sin(th) * v) * R * 0.8, 1) for th in np.linspace(0, 2 * math.pi, 12, endpoint=False) + k] + \
                  [(c + (math.cos(th) * u + math.sin(th) * v) * R * 0.47 + f * 0.006, 2) for th in np.linspace(0, 2 * math.pi, 7, endpoint=False) + k + 0.4] + \
                  [(c + (math.cos(th) * u + math.sin(th) * v) * R * 0.17 + f * 0.011, 0) for th in (0.3, 1.9, 3.5, 5.1)]
            ring = [mixc(ring[i], mid[i], 0.0) for i in range(4)]
            def draw(flo=flo, f=f):
                P = pa.P; k = pa.k
                lam = shade(f, 0.5, 0.5)
                xc, yc = P(flo[-1][0])
                for q, lvl in sorted(flo, key=lambda z: (-z[1] if z[1] else -9, depth(z[0]))):
                    pal = ring if lvl == 1 else [mixc(ring[i], mid[i], 0.5) for i in range(4)] if lvl == 2 else mid
                    x, y = P(q)
                    lit = lam + 0.18 * ((xc - x) * 0.7 + (yc - y) * 0.7) / max(1.0, k * 0.04)   # florets on the sun side lighter
                    for k4 in range(4):
                        ang = k4 * 1.5708 + 0.4 + lvl
                        rr = k * (0.0068 if lvl else 0.0055)
                        cx, cy = x + math.cos(ang) * rr * 0.95, y + math.sin(ang) * rr * 0.75
                        tone = lit + 0.12 * math.cos(ang + 2.4)
                        col = pal[0] if tone < 0.42 else pal[1] if tone < 0.58 else pal[2] if tone < 0.78 else pal[3]
                        pa.ctx.new_path(); pa.ctx.arc(cx, cy, rr, 0, 2 * math.pi)
                        pa.ctx.set_source_rgb(*col); pa.ctx.fill_preserve()
                        pa.ctx.set_source_rgb(*ch.soft(col)); pa.ctx.set_line_width(pa.u(0.16)); pa.ctx.stroke()
                    pa.ctx.new_path(); pa.ctx.arc(x, y, k * 0.0028, 0, 2 * math.pi)        # the floret's dark throat
                    pa.ctx.set_source_rgb(*mixc(pal[0], (0.45, 0.15, 0.05), 0.5)); pa.ctx.fill()
            self.items.append((c + TOCAM * 0.12, draw))
        self.R = 0.25

    def _h_mong_ga(self, r):
        """v836 mồng gà (Celosia cristata), drawn from Link's model: 3 upright pale-green stems with long lanceolate
        leaves up them, each topped by a fan crest: a finely pebbled wedge widening up from the stem into a thick
        rolled, brain-like velvet ridge. One colour per seed: đỏ, hồng sen, vàng, cam."""
        G = self.G; pa = self.pa
        COLS = [('#7a0812', '#c0101c', '#e8222a', '#ff5a4e'), ('#800a4c', '#bc1874', '#e03a96', '#ff76c0'),
                ('#b86400', '#e09a00', '#ffc414', '#ffe46a'), ('#a43c00', '#e0660a', '#ff8a1a', '#ffb24c')][self.seed % 4]
        cols = [C(x) for x in COLS]
        stemc = C('#86ae3e')
        lanc = [(0, 0.12), (0.18, 0.7), (0.42, 1.0), (0.7, 0.72), (0.9, 0.3), (1.0, 0.0)]
        lpal = [C('#1a4620'), C('#1f5326'), C('#2a6c2e'), C('#388839'), C('#4fa245'), C('#6dba56')]   # v836f dâm bụt's greens
        self.leaf_mound(9, 0.19, 0.06, R=0.05, el=(18, 45), droop=0.4, prof=lanc, ao=0.3, pal=lpal)
        # main stem at the back, two side stems out to the left and right, a young bud crest low in front
        plan = [(np.array([0.0, -0.02]), 0.33, 1.0), (np.array([-0.1, 0.02]), 0.25, 0.78), (np.array([0.1, 0.03]), 0.27, 0.8),
                (np.array([0.015, 0.05]), 0.17, 0.32)]
        sq = int(r.integers(0, 2))
        for k, (xy, H, sz) in enumerate(plan):
            if k in (1, 2) and sq: xy = xy * np.array([-1, 1])
            top = np.array([xy[0], xy[1], H * r.uniform(0.96, 1.04)])
            b0 = np.array([xy[0] * 0.25, xy[1] * 0.25, 0.0])
            pts = self.stalk(b0, top, np.array([xy[0] * 0.2, 0, 0]))
            self.stem(pts, 0.75 * sz + 0.4, 0.5 * sz + 0.3, stemc, key=-0.02)
            nl = 7 if sz > 0.5 else 2          # v836e leafy all the way up like the model, smaller toward the crest
            for j in range(nl):
                f = 0.12 + 0.8 * j / max(1, nl - 1) if nl > 2 else 0.2 + 0.3 * j
                fi = f * (len(pts) - 1); i0 = int(fi); q = pts[i0] + (pts[min(i0 + 1, len(pts) - 1)] - pts[i0]) * (fi - i0)
                la = (0.0 if (j + k) % 2 else math.pi) + r.normal(0, 0.3) + 0.4
                d = np.array([math.cos(la), math.sin(la) * 0.7, 0.75 + 0.5 * f])
                sc = (1.0 - 0.55 * f) if nl > 2 else 0.8
                self.leaf(q, d, 0.2 * sc * (0.65 + 0.35 * sz), 0.06 * (0.6 + 0.4 * sc) * (0.7 + 0.3 * sz), 0.3, pal=lpal, prof=lanc, key=0.01 * j, rib_col=C('#2e7030'), rib_w=0.12)
            w = 0.2 * sz * r.uniform(0.94, 1.06); h = 0.23 * sz * r.uniform(0.94, 1.05)
            crest = self._celosia(r, w, h, cols, k)
            base = top.copy()
            def draw(base=base, crest=crest):
                crest(*pa.P(base))
            self.items.append((top + UP * 0.04 + TOCAM * (0.06 + 0.01 * xy[1]), draw))
        self.R = 0.22

    def _celosia(self, r, w, h, cols, seedk):
        """v836e a cockscomb crest painted per pixel after Link's model: a fan of small flame-tipped scales
        flaring up from the stem into a crown of curled velvet loops (each loop a lit tube with a dark crease,
        fuzzy rim, deep pockets between). Returns draw(x, y) that paints it standing on screen point (x, y)."""
        from scipy.ndimage import gaussian_filter
        pa = self.pa
        c0, c1, c2, c3 = [np.array(q, float) for q in cols]
        gold = np.array(mixc(cols[3], C('#ffd84a'), 0.55))
        L = nv(np.array([-0.5, 0.62, 0.6]))
        # ---- the loops, in crest units (x right, y up, 0 at the foot of the fan)
        curls = []
        def row(n, yc, droop, rr0, z, xs):
            for i in range(n):
                t = ((i + 0.5) / n * 2 - 1) * xs + r.uniform(-0.04, 0.04)
                cx = t * w * 0.5; cy = h * (yc - droop * t * t) + r.uniform(-0.025, 0.025) * h
                rr = w * rr0 * r.uniform(0.85, 1.15)
                a0 = r.uniform(0, 2 * math.pi); span = r.uniform(2.4, 3.4)
                curls.append((cx, cy, rr, rr * r.uniform(0.8, 0.9), a0, span, z + r.uniform(0, 0.004)))
        row(int(r.integers(7, 9)), 0.87, 0.26, 0.08, 0.0, 0.92)       # back crown along the top
        row(int(r.integers(6, 8)), 0.78, 0.24, 0.082, 0.014, 0.82)       # middle
        row(int(r.integers(4, 6)), 0.69, 0.18, 0.078, 0.028, 0.6)      # front, lowest
        ph = r.uniform(0, 100, 4)
        def draw(X, Y):
            k = pa.k; SS = 2
            x0 = int(X - w * 0.8 * k) - 3; x1 = int(X + w * 0.8 * k) + 4
            y0 = int(Y - h * 1.08 * k * 0.866) - 3; y1 = int(Y + 2)
            W_, H_ = (x1 - x0) * SS, (y1 - y0) * SS
            yy, xx = np.mgrid[0:H_, 0:W_].astype(float)
            ux = ((xx + 0.5) / SS + x0 - X) / k; uy = (Y - ((yy + 0.5) / SS + y0)) / (k * 0.866)
            px = 1.0 / (k * SS)                                    # one supersample in crest units
            nz = np.sin(ux * 900 + ph[0]) * np.sin(uy * 840 + ph[1]) + 0.6 * np.sin((ux + uy) * 1500 + ph[2])
            # ---- fan body: polar scales around a focus below the foot
            fy = -h * 0.45
            th = np.arctan2(ux, uy - fy); rho = np.hypot(ux, uy - fy)
            half_ang = 0.04 + 0.6 * np.clip(uy / (h * 0.75), 0, 1) ** 1.7
            u = th / np.maximum(half_ang, 1e-3)
            m_b = (uy >= -px) & (uy <= h * (0.8 - 0.26 * np.clip(ux / (w * 0.5), -1, 1) ** 2)) & (np.abs(u) <= 1)
            colw = 0.012 * w / 0.15; rowh = 0.016 * h / 0.17
            gi = rho / rowh; ri = np.floor(gi); cy = gi - ri
            gx = th * (h * 0.9) / colw + (ri % 2) * 0.5; hs = np.sin(ri * 12.9898 + np.floor(gx) * 78.233 + ph[3]) * 43758.5453; hs = hs - np.floor(hs)
            cx = gx - np.floor(gx) - 0.5 + (hs - 0.5) * 0.18; cy = np.clip(cy + (hs - 0.5) * 0.2, 0, 1)
            wid = (0.42 + 0.12 * hs) * np.clip(1 - cy, 0, 1) ** 1.1 * np.clip(cy * 3.0, 0, 1) + 0.03
            inside = np.abs(cx) < wid
            dome = np.sqrt(np.clip(1 - (cx / wid) ** 2, 0, 1)) * inside
            nb = np.dstack([cx / wid * 0.8, (cy - 0.5) * 0.9 + 0.2, np.ones_like(cx)]); nb /= np.linalg.norm(nb, axis=2, keepdims=True)
            lb = np.clip(nb @ L, 0, 1) * dome
            tipm = np.clip((cy - 0.45) / 0.5, 0, 1)[..., None] * dome[..., None]
            cyl = (1 - 0.5 * np.clip(np.abs(u), 0, 1) ** 2)[..., None]
            up = np.clip(uy / (h * 0.65), 0, 1)[..., None]
            scl = c1 * (1 - tipm) + (gold * (1 - up) + c3 * up) * tipm
            scl = scl * (0.7 + 0.45 * lb[..., None] + 0.16 * (hs[..., None] - 0.5))
            col_b = np.where(inside[..., None], scl, c0 * 0.6 + c1 * 0.35) * (0.65 + 0.35 * cyl)
            col_b = col_b * (0.8 + 0.3 * up)
            # ---- loops: z-buffer of lit tubes
            Hz = np.full(ux.shape, -1.0); Nx = np.zeros_like(ux); Ny = np.zeros_like(ux); Nz = np.ones_like(ux); E = np.zeros_like(ux)
            back = np.zeros(ux.shape, bool)
            for (cx_, cy_, rr, tr, a0, span, z) in curls:
                dx = ux - cx_; dy = uy - cy_
                ang = (np.arctan2(dy, dx) - a0) % (2 * math.pi)
                ang = np.where(ang > span, np.where(ang - span < (2 * math.pi - span) / 2, span, 0.0), ang) + a0
                qx = cx_ + rr * np.cos(ang); qy = cy_ + rr * np.sin(ang)
                ex = ux - qx; ey = uy - qy
                trf = tr * (1 + 0.035 * np.sin(np.arctan2(dy, dx) * 9 + a0))
                d2 = (ex * ex + ey * ey) / (trf * trf)
                ins = d2 < 1
                hz = z + tr * np.sqrt(np.clip(1 - d2, 0, 1))
                win = ins & (hz > Hz)
                Hz = np.where(win, hz, Hz); Nx = np.where(win, ex / trf, Nx); Ny = np.where(win, ey / trf, Ny)
                Nz = np.where(win, np.sqrt(np.clip(1 - d2, 0.0, 1)), Nz); E = np.where(win, np.sqrt(d2), E)
                back |= ((dx * dx + dy * dy) < (rr + tr * 0.45) ** 2) & (dy < rr * 0.3)
            m_c = Hz > -1
            nrm = np.dstack([Nx, Ny, Nz + 0.25]); nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
            lam = np.clip(nrm @ L, 0, 1)
            Hf = np.where(m_c, Hz, -0.01 * w)
            ao = np.clip(1 - (gaussian_filter(Hf, 3 * SS) - Hf) / (w * 0.035), 0.35, 1.0)
            ao = np.where(m_c, np.clip(1 - (gaussian_filter(Hf, 3 * SS) - Hf) / (w * 0.03), 0.35, 1), ao)
            rimv = np.clip((E - 0.72) / 0.28, 0, 1) ** 2 * np.clip(Ny * 0.6 + 0.5, 0, 1)   # velvet rim catches light on top
            sh = np.clip((0.12 + 0.88 * lam) * ao + 0.22 * rimv , 0, 1.05)
            crease = np.clip((E - 0.8) / 0.2, 0, 1) ** 1.5                                          # dark seam where tubes meet
            sh = sh * (1 - 0.68 * crease * (1 - rimv))
            s3 = sh[..., None]
            col_c = np.where(s3 < 0.38, c0 + (c1 - c0) * (s3 / 0.38), np.where(s3 < 0.72, c1 + (c2 - c1) * ((s3 - 0.38) / 0.34), c2 + (c3 - c2) * np.clip((s3 - 0.72) / 0.3, 0, 1)))
            # pockets behind the loops: deep dark velvet
            m_k = back & ~m_c & (uy > h * 0.4)
            col_k = c0 * 0.72 + c1 * 0.12
            rgb = np.where(m_c[..., None], col_c, np.where(m_k[..., None], col_k, col_b))
            m = m_c | m_k | m_b
            # thin dark outline round the whole crest
            a = m.astype(float)
            er = gaussian_filter(a, 0.8 * SS)
            rim = m & (er < 0.72)
            rgb = np.where(rim[..., None], c0 * 0.7, rgb)
            # downsample SSxSS
            rgb = np.clip(rgb, 0, 1) * a[..., None]
            rgb = rgb.reshape(H_ // SS, SS, W_ // SS, SS, 3).mean((1, 3)); a = a.reshape(H_ // SS, SS, W_ // SS, SS).mean((1, 3))
            h2, w2 = a.shape
            out = np.zeros((h2, w2, 4), np.uint8)
            out[..., 0] = (rgb[..., 2] * 255).astype(np.uint8); out[..., 1] = (rgb[..., 1] * 255).astype(np.uint8)
            out[..., 2] = (rgb[..., 0] * 255).astype(np.uint8); out[..., 3] = (a * 255).astype(np.uint8)
            stride = cairo.ImageSurface.format_stride_for_width(cairo.FORMAT_ARGB32, w2)
            buf = np.zeros((h2, stride // 4, 4), np.uint8); buf[:, :w2] = out
            surf = cairo.ImageSurface.create_for_data(memoryview(buf).cast('B'), cairo.FORMAT_ARGB32, w2, h2, stride)
            c = pa.ctx; c.save(); c.set_source_surface(surf, x0, y0); c.paint(); c.restore()
        return draw

    def _h_van_tho(self, r):
        G = self.G; pa = self.pa
        # feathery dark leaves: a midrib with pairs of small narrow leaflets
        for j in range(12):
            az = 2 * math.pi * j / 12 + r.uniform(-0.3, 0.3); e0 = math.radians(r.uniform(15, 55))
            d = np.array([math.cos(az) * math.cos(e0), math.sin(az) * math.cos(e0), math.sin(e0)])
            b = np.array([math.cos(az), math.sin(az), 0]) * 0.02 + UP * r.uniform(0.02, 0.1)
            L = r.uniform(0.13, 0.17)
            for i in range(5):
                q = b + d * L * (0.2 + 0.18 * i) - UP * 0.25 * L * (0.2 + 0.18 * i) ** 2
                for sd in (1, -1):
                    s = nv(np.cross(UP, d)) * sd
                    self.leaf(q, nv(s + d * 0.6), L * 0.32 * (1 - 0.12 * i), 0.012, 0.15, pal=G['dark'], rib=False,
                              prof=[(0, 0.4), (0.3, 1.0), (0.7, 0.8), (1.0, 0.0)], ao=0.1)
        cols = [C('#d0560e'), C('#ee7a16'), C('#ff9a22'), C('#ffb84a')] if self.seed % 2 == 0 else [C('#d89a10'), C('#f0b818'), C('#ffd02e'), C('#ffe266')]
        n = int(r.integers(5, 7))
        for k in range(n):
            a = 2 * math.pi * k / n + r.uniform(-0.3, 0.3); out = r.uniform(0.04, 0.12)
            c = np.array([math.cos(a) * out, math.sin(a) * out * 0.85, r.uniform(0.24, 0.32)])
            pts = self.stalk(np.zeros(3), c, np.array([0, 0, 0.02]))
            self.stem(pts, 0.4, 0.32, G['stem'], key=-0.03)
            for sd in (1, -1):      # a feathery leaf part way up each stem
                q = pts[3]; s2 = nv(np.cross(UP, np.array([math.cos(a), math.sin(a), 0]))) * sd
                for i in range(4):
                    self.leaf(q + s2 * 0.015 * i + UP * 0.01 * i, nv(s2 + UP * 0.3), 0.04 * (1 - 0.15 * i), 0.012, 0.2, pal=G['dark'], rib=False,
                              prof=[(0, 0.4), (0.3, 1.0), (0.7, 0.8), (1.0, 0.0)], key=-0.02)
            R = r.uniform(0.056, 0.068)
            def ruff(H, cx, cy, R=R, k=k):
                # v831: a pom-pom of ruffled petal tips, row on row from the rim to the crown (no shiny ball)
                xs = [q[0] for q in H]; ys = [q[1] for q in H]
                rr0 = (max(xs) - min(xs)) / 2; cy = (max(ys) + min(ys)) / 2 + rr0 * 0.05
                rows = [(1.0, 0.25, 0, 22), (0.82, 0.05, 1, 19), (0.64, -0.15, 2, 16), (0.46, -0.32, 2, 12), (0.26, -0.48, 3, 8), (0.0, -0.58, 3, 1)]
                for ring, (rr, dy, tone, m) in enumerate(rows):
                    for j in range(m):
                        an = j * 2 * math.pi / max(1, m) + ring * 0.5 + k
                        x = cx + math.cos(an) * rr0 * rr * 0.8; y = cy + math.sin(an) * rr0 * rr * 0.45 + rr0 * dy * 0.6
                        lit = math.cos(an - 2.4) * 0.5 + 0.5
                        col = cols[min(3, tone + (1 if lit > 0.6 else 0))]
                        sz = rr0 * (0.24 - 0.02 * ring)
                        c2 = pa.ctx; c2.new_path(); c2.arc(x, y, sz, math.pi * 0.0, math.pi * 2)
                        c2.set_source_rgb(*col); c2.fill_preserve()
                        c2.set_source_rgba(*cols[0], 0.8); c2.set_line_width(pa.u(0.16)); c2.stroke()
            self.pompom(c, R * 1.05, cols, key=0.05, seed=k * 1.7 + self.seed)   # v836h per-pixel ruffled pom-pom
        self.R = 0.2

    # ------------------------------------------------------------------ v759 new kinds
    def _h_lai(self, r):
        """hoa lài (Jasminum sambac): a mound of glossy dark oval leaves in pairs, small white double flowers and buds"""
        prof = [(0, 0.15), (0.15, 0.65), (0.4, 1.0), (0.65, 0.9), (0.88, 0.45), (1.0, 0.0)]
        self.leaf_mound(20, 0.12, 0.065, R=0.12, el=(8, 40), droop=0.2, prof=prof, pal=self.G['dark'])
        self.leaf_mound(16, 0.11, 0.06, R=0.1, el=(30, 70), droop=0.2, prof=prof, z0=0.08)
        cols = (C('#d6dae0'), C('#eceef2'), C('#fafafa'), C('#ffffff'))
        n = int(r.integers(6, 9))
        for k in range(n):
            a = 2 * math.pi * k / n + r.uniform(-0.3, 0.3); out = r.uniform(0.04, 0.14)
            p = np.array([math.cos(a) * out, math.sin(a) * out * 0.9, 0.2 - out * 0.4 + r.uniform(0, 0.03)])
            f = nv(np.array([math.cos(a) * out * 6, math.sin(a) * out * 6 + 0.3, 1.0]))
            if k % 3 == 2:
                self.blob(p, 0.012, 0.012, 0.022, cols[:3], key=0.1)                    # a bud, long and pointed
            else:
                self.flower(p, f, 7, 0.034, 0.02, cols, eye=C('#f2e6a8'), eye_r=0.005, cup=0.4, layers=2, ph0=k, key=0.12)
        self.R = 0.25

    def _h_mong_tay(self, r):
        """bông móng tay (Impatiens balsamina): fleshy pale upright stems, toothed lance leaves crowded at the top,
        cupped flowers hugging the stem under the leaves"""
        G = self.G
        cs = [('#c8327a', '#e2589a', '#f47ab4', '#ff9ec8'), ('#b8203a', '#d8364e', '#f05a6a', '#ff8a90'),
              ('#7a3aa0', '#9a52c0', '#b874d8', '#d29aec'), ('#d8d4dc', '#ece8ee', '#fafafa', '#ffffff')][self.seed % 4]
        cols = tuple(C(c) for c in cs)
        prof = [(0, 0.1), (0.2, 0.7), (0.45, 1.0), (0.75, 0.6), (1.0, 0.0)]
        self.leaf_mound(10, 0.1, 0.03, R=0.08, el=(10, 40), droop=0.3, prof=prof, teeth=1)
        nst = int(r.integers(5, 7))
        for k in range(nst):
            a = 2 * math.pi * k / nst + r.uniform(-0.3, 0.3); out = r.uniform(0.04, 0.11)
            top = np.array([math.cos(a) * out, math.sin(a) * out * 0.85, r.uniform(0.28, 0.38)])
            pts = self.stalk(np.zeros(3), top, np.array([0, 0, 0]))
            self.stem(pts, 1.3, 0.8, C('#9ab86a'), key=-0.03)
            for j in range(13):
                s = 0.06 + 0.94 * j / 13; q = pts[0] + (top - pts[0]) * s
                az = j * 2.4 + k
                d = np.array([math.cos(az), math.sin(az), 0.5 + s])
                self.leaf(q, d, 0.12 * (1.15 - 0.45 * s), 0.034, 0.3, prof=prof, teeth=1, key=0.01, pal=self.G['dark'] if j % 2 else None)
                if 0.4 < s < 0.92 and j % 2 == 0:
                    f = nv(np.array([math.cos(az + 1), math.sin(az + 1) + 0.3, 0.3]))
                    self.flower(q + f * 0.018, f, 6, 0.026, 0.028, cols, eye=None, cup=0.85, ph0=az, key=0.03, layers=3)   # v836g double camellia-like balsam
        self.R = 0.22

    def _h_mai_dia(self, r):
        """mai địa thảo (Impatiens walleriana): a low dense mound smothered in flat round 5-petal flowers"""
        cs = [('#c41860', '#e02e80', '#f44c98', '#ff74b2'), ('#c01820', '#e02a2e', '#f4463e', '#ff6e5e'),
              ('#d8500e', '#f06c18', '#ff8a2c', '#ffa852'), ('#d8d4dc', '#ece8ee', '#fafafa', '#ffffff')][self.seed % 4]
        cols = tuple(C(c) for c in cs)
        prof = [(0, 0.15), (0.15, 0.6), (0.4, 1.0), (0.65, 0.92), (0.88, 0.45), (1.0, 0.0)]
        self.leaf_mound(20, 0.11, 0.055, R=0.12, el=(8, 35), droop=0.2, prof=prof, teeth=1)
        self.leaf_mound(14, 0.1, 0.05, R=0.1, el=(25, 60), droop=0.2, prof=prof, z0=0.06)
        n = 10
        for k in range(n):
            a = 2.4 * k + r.uniform(0, 0.5); out = 0.15 * math.sqrt((k + 0.5) / n)
            p = np.array([math.cos(a) * out, math.sin(a) * out * 0.9, 0.15 - out * 0.4])
            f = nv(np.array([math.cos(a) * out * 5, math.sin(a) * out * 5 + 0.3, 1.0]))
            self.flower(p, f, 5, 0.04, 0.042, cols, eye=C('#f4f0f0'), eye_r=0.006, cup=0.05, ph0=k,
                        prof=[(0, 0.3), (0.3, 0.9), (0.65, 1.0), (0.9, 0.75), (1.0, 0.35)], key=0.12)
        self.R = 0.26

    def _h_huong_duong(self, r):
        """hướng dương (sunflower): a tall rough stem with big heart leaves and 1-2 big heads turned toward the sun"""
        G = self.G
        n = 2 if self.seed % 2 else 1
        prof = [(0, 0.3), (0.15, 0.85), (0.4, 1.0), (0.7, 0.75), (1.0, 0.0)]
        petal = (C('#d89a08'), C('#f0b812'), C('#ffd024'), C('#ffe262'))
        for k in range(n):
            a = r.uniform(0, 2 * math.pi) if n > 1 else 0.0; out = 0.05 if n > 1 else 0.0
            H = r.uniform(0.85, 1.0) if k == 0 else r.uniform(0.62, 0.75)
            top = np.array([math.cos(a) * out, math.sin(a) * out, H])
            pts = self.stalk(np.zeros(3), top, np.array([0.02, 0, 0]))
            self.stem(pts, 1.8, 1.2, C('#5e8a34'), key=-0.05)
            for j in range(6):
                s = 0.15 + 0.13 * j; q = pts[0] + (top - pts[0]) * s
                az = j * 2.4 + k
                self.leaf(q, np.array([math.cos(az), math.sin(az), 0.35]), 0.16 * (1.15 - 0.5 * s), 0.12 * (1.15 - 0.5 * s), 0.45, prof=prof, key=0.0)
            f = nv(np.array([-0.35, 0.75, 0.35]) + r.normal(0, 0.1, 3))
            Rh = 0.1 if k == 0 else 0.08
            self.flower(top + f * 0.01, f, 22, Rh, Rh * 0.32, petal, eye=C('#5a3414'), eye_r=Rh * 0.45, cup=0.15, ph0=k,
                        ring_eye=C('#8a5a20'), layers=2, key=0.15)
        self.R = 0.22

    def _h_da_yen(self, r):
        """dạ yến thảo (petunia): a spilling mound of soft leaves and wide trumpet flowers with darker veins"""
        cs = [('#5a1a84', '#7a2aa8', '#9844c6', '#b468de'), ('#b81a62', '#d8307e', '#ee5098', '#ff78b4'),
              ('#d8d4dc', '#ece8ee', '#fafafa', '#ffffff'), ('#981640', '#be2a5a', '#dc4478', '#f46a98')][self.seed % 4]
        cols = tuple(C(c) for c in cs)
        eye = C('#4a1a5a') if self.seed % 4 != 2 else C('#e8d060')
        prof = [(0, 0.2), (0.2, 0.75), (0.45, 1.0), (0.75, 0.75), (1.0, 0.0)]
        self.leaf_mound(18, 0.12, 0.06, R=0.13, el=(0, 25), droop=0.3, prof=prof)
        self.leaf_mound(12, 0.1, 0.055, R=0.1, el=(20, 50), droop=0.25, prof=prof, z0=0.05)
        n = 8
        for k in range(n):
            a = 2.4 * k + r.uniform(0, 0.4); out = 0.17 * math.sqrt((k + 0.5) / n)
            p = np.array([math.cos(a) * out, math.sin(a) * out * 0.9, 0.12 - out * 0.35])
            f = nv(np.array([math.cos(a) * out * 6, math.sin(a) * out * 6 + 0.3, 1.0]))
            self.flower(p, f, 5, 0.05, 0.065, cols, eye=eye, eye_r=0.012, cup=0.55, ph0=k,
                        prof=[(0, 0.35), (0.4, 0.85), (0.8, 1.0), (1.0, 0.8)], key=0.12)
        self.R = 0.27

    def _h_cuc_la_nho(self, r):
        """cúc lá nho: lobed rough leaves, single orange-red daisies on stiff stems"""
        prof = [(0, 0.2), (0.2, 0.8), (0.45, 1.0), (0.7, 0.75), (1.0, 0.0)]
        self.leaf_mound(14, 0.15, 0.09, R=0.1, el=(10, 45), droop=0.3, prof=prof, teeth=1, pal=self.G['dark'])
        cols = (C('#c83a14'), C('#e8521c'), C('#ff7230'), C('#ff9a58'))
        def head(top, f, k):
            self.flower(top, f, 12, 0.055, 0.024, cols, eye=C('#e8a018'), eye_r=0.017, cup=0.1, ph0=k, ring_eye=C('#c87818'))
        self._stems_heads(r, int(r.integers(4, 6)), 0.36, 0.13, head)
        self.R = 0.24

    def _k_luoi_ho(self, r):
        """lưỡi hổ (Sansevieria trifasciata Laurentii): stiff upright sword leaves, dark cross bands, yellow edges"""
        pa = self.pa
        band = C('#1e3a1c'); edge = C('#e2cc3e'); light = C('#8eae7a')
        pal = [C('#2a5426'), C('#356630'), C('#42783a'), C('#528a44')]
        n = int(r.integers(7, 10))
        for k in range(n):
            a = 2 * math.pi * k / n + r.uniform(-0.3, 0.3)
            out = r.uniform(0.0, 0.06)
            b = np.array([math.cos(a) * out, math.sin(a) * out, 0.0])
            lean = 0.03 + out * 3.2 + r.uniform(0, 0.12)     # v831: inner ones straight up, outer ones fan out
            d = nv(np.array([math.cos(a) * lean, math.sin(a) * lean, 1.0]))
            L = r.uniform(0.36, 0.66) * (1.1 - out * 3)
            def extra(P, cen, L1, R1, col, front, seed=k):
                # yellow margins, then dark wavy cross bands
                # v836i tiger bands: pale grey-green zigzags across a dark leaf, a wide gold margin with a thin dark rim
                c = pa.ctx; c.save(); pa.path([P(q) for q in L1] + [P(q) for q in R1[::-1]]); c.clip()
                m = len(cen) - 1
                for j in range(1, 3 * m - 2):
                    t = j / (3 * m); i0 = int(t * m); f = t * m - i0
                    A = L1[i0] + (L1[i0 + 1] - L1[i0]) * f; B = R1[i0] + (R1[i0 + 1] - R1[i0]) * f; Cn = cen[i0] + (cen[i0 + 1] - cen[i0]) * f
                    zz = [P(A * (1 - u) + B * u) for u in np.linspace(0, 1, 7)]
                    zz = [(x, y + pa.u(0.5) * (1 if q % 2 else -1) * (0.6 + 0.4 * math.sin(j * 2.3 + seed))) for q, (x, y) in enumerate(zz)]
                    pa.line(zz, light if j % 2 else band, pa.u(0.42 if j % 2 else 0.3), 0.75 if j % 2 else 0.6)
                c.restore()
                pa.line([P(q) for q in L1[1:-1]], edge, pa.u(0.55)); pa.line([P(q) for q in R1[1:-1]], edge, pa.u(0.55))
                pa.line([P(q) for q in L1[1:-1]], mixc(edge, (0.2, 0.25, 0.1), 0.5), pa.u(0.2), 0.8); pa.line([P(q) for q in R1[1:-1]], mixc(edge, (0.2, 0.25, 0.1), 0.5), pa.u(0.2), 0.8)
            self.leaf(b, d, L, r.uniform(0.042, 0.075), r.uniform(0.0, 0.06), pal=pal, rib=False, n=12, key=0.02 * k / n,
                      prof=[(0, 0.6), (0.15, 0.95), (0.5, 1.0), (0.8, 0.75), (0.95, 0.3), (1.0, 0.0)], extra=extra)
        self.R = 0.2

    def _k_nha_dam(self, r):
        """v831 nha đam (Aloe vera): thick fleshy grey-green leaves standing up in a V fan, outer tips arching over,
        small pale teeth on the margins, only faint flecks on the young inner leaves"""
        pa = self.pa
        pal = [C('#4e7a52'), C('#62905e'), C('#78a672'), C('#90ba86')]
        side = [C('#3d6640'), C('#4a764a'), C('#58845a')]
        spot = C('#b8d0ae'); tooth = C('#d8e4b8')
        n = 13
        for k in range(n):
            a = 2 * math.pi * k / n * 2.618; ring = k / n
            e = math.radians(80 - 32 * ring + r.normal(0, 4))
            d = np.array([math.cos(a) * math.cos(e), math.sin(a) * math.cos(e) * 0.8, math.sin(e)])
            L = 0.26 + 0.14 * ring
            def extra(P, cen, L1, R1, col, front, ring=ring):
                for j in range(1, len(cen) - 1, 2):      # v836i small pale hooked teeth along both margins
                    for M, sg in ((L1, -1), (R1, 1)):
                        x, y = P(M[j]); x2, y2 = P(M[j + 1]); dx, dy = x2 - x, y2 - y; ln = math.hypot(dx, dy) + 1e-6
                        nx, ny = -dy / ln * sg, dx / ln * sg; h = pa.u(0.22)
                        pa.fill([(x, y), (x + dx * 0.5 + nx * h, y + dy * 0.5 + ny * h), (x + dx * 0.6, y + dy * 0.6)], mixc(tooth, col, 0.3), seam=False)
                if not front or ring > 0.6: return
                rs = np.random.default_rng(int(ring * 1000))
                for j in range(1, len(cen) - 2, 2):         # pale flecks in loose rows, more on young leaves
                    for u in rs.uniform(0.25, 0.75, 1):
                        x, y = P(L1[j] * (1 - u) + R1[j] * u)
                        pa.ctx.new_path(); pa.ctx.save(); pa.ctx.translate(x, y); pa.ctx.scale(pa.u(0.34), pa.u(0.2)); pa.ctx.arc(0, 0, 1, 0, 2 * math.pi); pa.ctx.restore()
                        pa.ctx.set_source_rgba(*spot, 0.75 - 0.3 * ring); pa.ctx.fill()
                pa.line([P(q) for q in cen[1:-2]], mixc(col, (1, 1, 1), 0.18), pa.u(0.5), 0.35)   # a soft fleshy sheen down the middle
            prof = [(0, 1.0), (0.25, 0.95), (0.55, 0.7), (0.82, 0.38), (1.0, 0.0)]
            b0 = np.array([math.cos(a), math.sin(a), 0]) * 0.015
            if math.sin(a) < 0.2:   # the fleshy edge only shows on leaves turned away or sideways
                self.leaf(b0 - UP * 0.016, d, L, 0.075, 0.12 + 0.5 * ring ** 2, pal=side, rib=False, n=10, prof=prof, key=0.03 * ring - 0.004, ao=0.2)
            self.leaf(b0, d, L, 0.072, 0.12 + 0.5 * ring ** 2, pal=pal, rib=False, n=10, prof=prof, key=0.03 * ring, ao=0.25 * (1 - ring), extra=extra)
        self.R = 0.22

    def _k_xuong_rong(self, r):
        """xương rồng tai thỏ (Opuntia microdasys): flat oval pads growing out of each other, rows of pale
        glochid dots, a few red flowers on the pad rims"""
        pa = self.pa
        pal = [C('#3e7a3a'), C('#4e8e44'), C('#62a450'), C('#7cba62')]
        pads = []
        def pad(base, up, R, depth_lvl):
            c = base + up * R
            side = nv(np.cross(up, np.array([0, 1.0, 0]))) if abs(up[1]) < 0.95 else np.array([1.0, 0, 0])
            nrm = nv(np.cross(side, up))
            if nrm @ TOCAM < 0: nrm = -nrm
            pts3 = [c + up * R * math.sin(t) + side * R * 0.72 * math.cos(t) for t in np.linspace(0, 2 * math.pi, 30, endpoint=False)]
            col = pick(pal, shade(nrm, 0.35, 0.6))
            dots = [c + up * R * u * 0.75 + side * R * 0.5 * w for u in np.linspace(-0.8, 0.8, 5) for w in np.linspace(-0.8, 0.8, 4)]
            def draw(pts3=pts3, col=col, dots=dots):
                P = pa.P; poly = [P(q) for q in pts3]
                pa.fill(poly, col); pa.soft_edge(poly, col)
                for q in dots:
                    x, y = P(q); pa.ctx.new_path(); pa.ctx.arc(x, y, pa.u(0.3), 0, 2 * math.pi)
                    pa.ctx.set_source_rgb(*C('#e8e0a8')); pa.ctx.fill()
            self.items.append((c + TOCAM * 0.01 * depth_lvl, draw))
            return c + up * R * 0.95, side
        az0 = r.uniform(-0.4, 0.4)
        top0, s0 = pad(np.zeros(3), nv(np.array([math.sin(az0) * 0.2, 0.05, 1.0])), 0.13, 0)
        tops = []
        for k, ang in enumerate((-0.6, 0.5)):
            up = nv(np.array([math.sin(ang), 0.1 * k, math.cos(ang)]))
            tp, _ = pad(top0 - np.array([0, 0, 0.04]) + s0 * ang * 0.08, up, 0.1, 1)
            tops.append(tp)
        if self.seed % 2:
            tp, _ = pad(tops[0] - np.array([0, 0, 0.03]), nv(np.array([-0.3, 0.2, 1.0])), 0.075, 2); tops.append(tp)
        cols = (C('#b8182a'), C('#d82a36'), C('#f04a46'), C('#ff7a6a'))
        for k, tp in enumerate(tops[:int(r.integers(2, 4))]):
            self.flower(tp, nv(np.array([0.1, 0.4, 1.0])), 8, 0.032, 0.02, cols, eye=C('#f2d24a'), eye_r=0.008, cup=0.6, ph0=k, key=0.1)
        self.R = 0.2

    def _k_ot(self, r):
        """ớt kiểng (ornamental chili): a small round bush of narrow leaves covered in upright cone fruits of mixed colours"""
        prof = [(0, 0.1), (0.2, 0.7), (0.45, 1.0), (0.75, 0.6), (1.0, 0.0)]
        self.leaf_mound(22, 0.09, 0.03, R=0.1, el=(10, 50), droop=0.25, prof=prof, pal=self.G['dark'])
        self.leaf_mound(14, 0.08, 0.028, R=0.08, el=(35, 70), droop=0.2, prof=prof, z0=0.08)
        fr = [[C('#a8101a'), C('#d42020'), C('#f24a3a')], [C('#c89a08'), C('#ecc018'), C('#ffe050')],
              [C('#4a1a5a'), C('#6a2a7a'), C('#8e4a9a')], [C('#d0601a'), C('#f07a1e'), C('#ff9a42')]]
        mix = [[0, 0, 3, 1, 0, 2], [0, 0, 3, 0, 1, 3], [0, 2, 0, 3, 0, 2], [0, 3, 0, 1, 0, 3]][self.seed % 4]   # ripe red most, a few on the way
        n = 13
        for k in range(n):
            a = 2.4 * k; out = 0.14 * math.sqrt((k + 0.5) / n)
            p = np.array([math.cos(a) * out, math.sin(a) * out * 0.9, 0.15 - out * 0.4 + r.uniform(0, 0.02)])
            c3 = fr[mix[k % 6]]; c4 = [c3[0], c3[1], c3[2], mixc(c3[2], (1, 1, 1), 0.35)]
            d = nv(np.array([math.cos(a) * out * 2.5, math.sin(a) * out * 2.5, 1.0]) + r.normal(0, 0.12, 3))
            self.chili(p, d, r.uniform(0.045, 0.058), 0.0105, c4, key=0.12)   # v836g real cone chillies, calyx, gloss
        self.R = 0.22

    def _k_sa(self, r):
        """bụi sả (lemongrass): long blue-green blades arching out of a tight clump of pale purple-white stalks"""
        pal = [C('#3f7436'), C('#4e8a3e'), C('#62a04a'), C('#78b458'), C('#92c66a'), C('#a8d47e')]
        for k in range(9):
            a = 2 * math.pi * k / 8 + r.uniform(-0.2, 0.2)
            b = np.array([math.cos(a), math.sin(a), 0]) * 0.025
            pts = self.stalk(b, b * 1.8 + UP * r.uniform(0.13, 0.18), np.array([0, 0, 0]))
            self.stem(pts, 2.8, 2.0, C('#d8c8c4') if k % 2 else C('#c0a0b0'), key=0.03 if b[1] > 0 else -0.01)
        self.grass(int(r.integers(20, 25)), 0.62, 0.038, R=0.045, pal=pal, dry=1)
        self.R = 0.24

    def _k_hung_que(self, r):
        """húng quế (Thai basil): a bushy mound of glossy oval leaves on purple stems with purple flower spikes"""
        pa = self.pa
        prof = [(0, 0.15), (0.15, 0.65), (0.4, 1.0), (0.65, 0.9), (0.88, 0.45), (1.0, 0.0)]
        self.leaf_mound(20, 0.1, 0.06, R=0.12, el=(10, 45), droop=0.3, prof=prof)
        self.leaf_mound(14, 0.09, 0.055, R=0.1, el=(30, 70), droop=0.25, prof=prof, z0=0.08)
        pur = [C('#4a2a6a'), C('#6a3a8a'), C('#8a5aaa'), C('#a87ac6')]
        for k in range(int(r.integers(4, 6))):
            a = 2 * math.pi * k / 5 + r.uniform(-0.4, 0.4); out = r.uniform(0.03, 0.12)
            base = np.array([math.cos(a) * out, math.sin(a) * out * 0.85, 0.14])
            top = base + UP * r.uniform(0.1, 0.13) + np.array([math.cos(a), math.sin(a), 0]) * 0.015
            self.basil_spike(base, top, key=0.12)    # v836g whorls of bracts and tiny flowers, not beads
        self.R = 0.24

    def _k_lan_chi(self, r):
        """cỏ lan chi (Chlorophytum comosum): a fountain of arching narrow leaves with a cream stripe down the middle,
        one or two runners with baby plants hanging off them"""
        pal = self.G['top'][1:]
        cream = C('#f2eccc')
        for k in range(26):
            a = 2 * math.pi * k / 26 * 2.618; out = r.uniform(0, 1) ** 0.8
            e = math.radians(80 - 45 * out + r.normal(0, 4))
            d = np.array([math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)])
            self.leaf(np.array([math.cos(a), math.sin(a), 0]) * 0.02, d, r.uniform(0.22, 0.3), 0.042, 0.3 + 0.45 * out, pal=pal,
                      rib_col=cream, rib_w=0.17, n=12, key=0.05 * out, ao=0.35 * (1 - out),
                      prof=[(0, 0.6), (0.2, 1.0), (0.6, 0.85), (0.9, 0.4), (1.0, 0.0)])
        a0 = r.uniform(0, 2 * math.pi)
        for k in range(2):
            a = a0 + k * 2.6 + r.uniform(-0.3, 0.3)
            dh = np.array([math.cos(a), math.sin(a) * 0.8, 0])
            tip = dh * 0.24 + UP * 0.05
            pts = self.stalk(np.zeros(3) + UP * 0.08, tip, UP * 0.14)
            self.stem(pts, 0.28, 0.22, C('#b8cc88'), key=0.02)
            for j in range(5):
                az = r.uniform(0, 2 * math.pi)
                self.leaf(tip, np.array([math.cos(az), math.sin(az), 0.8]), 0.075, 0.028, 0.3, pal=pal, rib_col=cream, rib_w=0.17, key=0.06,
                          prof=[(0, 0.6), (0.2, 1.0), (0.6, 0.85), (1.0, 0.0)])
        self.R = 0.26

    def shadow(self):
        # kept inside the plant's own footprint (v756 shadows read as dark plates under the small ones)
        ground_shadow(self.pa, 0.0, 0.02, self.R * 0.64, self.R * 0.54, 0.13)
        ground_shadow(self.pa, 0.0, 0.0, self.R * 0.38, self.R * 0.32, 0.1)


class Frame:
    def __init__(self, pa, kind, seed): self.m = Mini(kind, seed, pa)
    def paint(self): self.m.paint()


def make(pa, kind, seed): return Mini(kind, seed, pa)


GONE = ['da_cuoi', 'nam']      # v758: taken out of the game (kits kept)
# v759 (Link: big kinds fill a whole tile): these models are only parts of the 1-tile plants in ../caycanh
BIG = ['h_lai', 'h_huong_duong', 'k_luoi_ho', 'k_nha_dam', 'k_xuong_rong', 'k_sa']
FRAMES = [dict(key='%s%d' % (k, s), kind=k, seed=s) for k in IDS if k not in GONE and k not in BIG for s in range(4)]
BB = (-22, -76, 22, 10)

co.KU = 29.0 * 2.0         # v757 (Link): each mini fills its whole quarter tile, tall kinds stand tall
if __name__ == '__main__':
    os.makedirs('/tmp/claude-0/g', exist_ok=True)
    if len(sys.argv) > 1 and sys.argv[1] == 'atlas':
        co.atlas(Frame, FRAMES, BB, sys.argv[2], 'hoaco.webp', sys.argv[3], cols=16)
    else:
        sel = sys.argv[1].split(',') if len(sys.argv) > 1 else IDS
        night = len(sys.argv) > 2 and sys.argv[2] == 'n'
        fr = [f for f in FRAMES if f['kind'] in sel]
        co.preview(Frame, fr, BB, range(len(fr)), night, '/tmp/claude-0/g/hoaco_%s.png' % (sys.argv[3] if len(sys.argv) > 3 else 'a'))
