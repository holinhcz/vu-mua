# v843 cây mặt nước for Nông Trại Nhỏ (Link: "lục bình + bèo + bông súng + bè rau muống đi"), drawn like the lotus
# (src/sen): every part a parametric 3D surface, lit per pixel from its own normal, painted detail on top, one shared
# z-buffer per sprite, the kit's thin edge in its own colour, 9 px per game unit.
#   lb0-5   lục bình rosettes: swollen spongy floats, glossy round leaves with arched veins
#   lbf0-2  the same with a lilac flower spike (six tepals, the top one with a violet eye and a yellow spot)
#   beo0-3  bèo patches: a film of bèo tấm (single fronds, each a tiny lit dome) with rosettes of bèo cái (velvety,
#           ribbed spoon leaves)
#   sung0-3 bông súng clumps (1 tile): slit round pads lying on the water, mottled, red-rimmed; star flowers held a
#           little above the water, 0 tím, 1 hồng, 2 trắng, 3 xanh; slender buds
#   rau0-3  bè rau muống (1 tile): a free floating mat of water spinach runners (bamboo frame removed 2026-11-08)
#           inside with arrow leaves standing up, a few white trumpet flowers with a lilac throat
#   python3 thuysinh.py prev OUT.png [d|n] [keys]     python3 thuysinh.py atlas OUTDIR atlas.json
import math, os, sys, json
import numpy as np, cairo
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'co', 'dambut', 'hoaco', 'sen'):
    sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import C, nv, LIGHT, TOCAM
import co
from co import ground_shadow
import sen
from sen import Sen, A_, ramp, vnoise, fbm, mix, HALF
from hoaco import UP, basis

KU = sen.KU
co.KU = KU

SUNG = {   # base, mid, tip, deep, vein
    0: ('#f4ecfc', '#c6a6f0', '#8456d6', '#47268a', '#7a4ac4'),       # tím
    1: ('#fff2f6', '#f8b0cc', '#e2589a', '#9a2860', '#d0528a'),       # hồng
    2: ('#f4f6e6', '#fffefa', '#fbfaf4', '#b4b4a2', '#d4d4c0'),       # trắng
    3: ('#eef4fc', '#acc6f2', '#5c86da', '#28468e', '#5078c8'),       # xanh
}


def H(*hs): return [A_(C(h)) for h in hs]


class Kit(Sen):
    EDGE_DZ = 0.004
    def __init__(self, kind, seed, pa):
        self.pa = pa; self.seed = seed; self.kind = kind
        self.r = np.random.default_rng(seed * 7717 + sum(map(ord, kind)) * 131 + 5)
        self.items = []; self.shadows = []
        self.water_sh = C('#0e2a30')
        getattr(self, '_' + kind)(seed)

    def shadow(self):
        for (x, y, rx, ry, a) in self.shadows: ground_shadow(self.pa, x, y, rx, ry, a)

    # ------------------------------------------------------------------ generic parts
    def tube(self, cfun, r0, r1, pal, key, sd=0, node=0.0, node_col=None, zcut=None, tint=None, edge_k=0.8, rfun=None):
        """a round stalk along cfun(t) (t in 0..1 -> (..., 3)), radius r0 -> r1, lit per pixel; node rings every `node`"""
        def frame(t):
            c = cfun(t); e = 1e-3
            T = cfun(np.clip(t + e, 0, 1)) - cfun(np.clip(t - e, 0, 1))
            T = T / np.maximum(np.linalg.norm(T, axis=-1, keepdims=True), 1e-9)
            ref = np.where(np.abs(T[..., 2:3]) > 0.9, np.array([1.0, 0, 0]), np.array([0, 0, 1.0]))
            n1 = np.cross(T, ref); n1 /= np.maximum(np.linalg.norm(n1, axis=-1, keepdims=True), 1e-9)
            return c, n1, np.cross(T, n1)
        L = float(np.linalg.norm(cfun(np.array([1.0])) - cfun(np.array([0.0]))))
        def geo(A, B):
            c, n1, n2 = frame(A); th = (B * 2 * math.pi)[..., None]
            r = (rfun(A) if rfun is not None else (r0 + (r1 - r0) * A))[..., None]
            if node:
                ph = (A * L / node) % 1.0
                r = r * (1 + 0.12 * np.exp(-((ph - 0.5) / 0.04) ** 2))[..., None]
            return c + (np.cos(th) * n1 + np.sin(th) * n2) * r
        def sh(P, N, F, A, B):
            lam = self.lam(N); rim = 1 - np.abs(N @ TOCAM)
            s = (0.15 + 0.78 * lam + 0.1 * rim) * self.grain(P, max(r0, 0.002) * 1.5, sd, 0.05)
            col = ramp(pal, s)
            col = col * (1 + 0.05 * np.sin(B * 2 * math.pi * 9))[..., None]
            if node:
                ph = (A * L / node) % 1.0
                col = mix(col, node_col if node_col is not None else pal[0], np.exp(-((ph - 0.5) / 0.025) ** 2) * 0.6)
            if tint is not None: col = tint(col, P, N, A, B)
            msk = (P[..., 2] > zcut) if zcut is not None else None
            return (col, msk) if msk is not None else col
        self.splat(geo, sh, cfun(np.array([0.5]))[0] + TOCAM * key, edge_k=edge_k)

    def line_c(self, pts):
        """a smooth curve through pts (catmull-rom), as a function of t"""
        P = np.array(pts, float); n = len(P)
        def f(t):
            t = np.asarray(t, float); x = np.clip(t, 0, 1) * (n - 1); i = np.clip(np.floor(x).astype(int), 0, n - 2); u = (x - i)[..., None]
            p0 = P[np.maximum(i - 1, 0)]; p1 = P[i]; p2 = P[i + 1]; p3 = P[np.minimum(i + 2, n - 1)]
            return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u ** 2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3)
        return f

    def petal(self, p, f, e, L, W, cup, cols, key, prof=None, nveins=9, eye=None, edge_k=0.84, curl=0.0):
        """a petal or tepal from p along e, cupped toward f; cols = dict base, mid, tip, deep, vein"""
        prof_t = np.array([0, 0.12, 0.35, 0.6, 0.82, 0.95, 1.0]); prof_w = np.array(prof or [0.25, 0.7, 1.0, 0.92, 0.6, 0.25, 0.0])
        s = nv(np.cross(f, e)); nin = nv(f - e * cup * 1.6)
        sd = int(self.r.integers(1000)); tw = self.r.normal(0, 0.05)
        def geo(A, B):
            t = A; w = B * 2 - 1; pw = np.interp(t, prof_t, prof_w)
            return p + (e * (L * t)[..., None] + s * (W * 0.5 * w * pw)[..., None] + f * (L * cup * t * t)[..., None]
                        + nin * (L * (0.14 * w * w * pw + curl * t ** 3 + tw * w * t))[..., None])
        def sh(P, N, F, A, B):
            t = A; w = B * 2 - 1; lam = self.lam(N)
            g = np.clip(t ** 1.3 + 0.2 * np.abs(w) ** 3 * t, 0, 1)
            base = ramp([cols['base'], cols['mid'], cols['tip']], g)
            vv = np.abs(np.cos(w * math.pi * nveins * 0.5 * (1 - 0.15 * t)))
            vein = np.clip((vv - 0.82) / 0.18, 0, 1) ** 1.5 * np.clip((t - 0.05) / 0.1, 0, 1) * (1 - t ** 3)
            base = mix(base, cols['vein'], vein * np.where(F, 0.2, 0.32) * (1 - 0.4 * g))
            base = mix(base, cols['tip'], (~F) * 0.16 * (0.4 + 0.6 * g))
            if eye is not None:
                ew = np.exp(-((t - 0.42) / 0.16) ** 2 - (w / 0.42) ** 2)
                base = mix(base, eye[0], np.clip(ew * 1.6, 0, 1) * F)
                base = mix(base, eye[1], np.clip((np.exp(-((t - 0.4) / 0.06) ** 2 - (w / 0.14) ** 2) - 0.3) * 3, 0, 1) * F)
            sv = np.clip(0.38 + 0.75 * lam + 0.12 * (~F), 0, 1.08) * self.grain(P, L * 0.03, sd, 0.025)
            sv = sv * (1 - np.clip((0.2 - t) / 0.2, 0, 1) * 0.25)
            col = mix(cols['deep'], base, np.clip(sv, 0, 1))
            spec = np.clip(N @ HALF, 0, 1) ** 24 * 0.22 * F
            return np.clip(col + spec[..., None], 0, 1)
        self.splat(geo, sh, p + e * L * 0.55 + TOCAM * key, edge_k=edge_k)

    # ------------------------------------------------------------------ lục bình
    def rosette(self, c, S, sd, flower=False):
        """a water hyacinth rosette at c, size S (about 1)"""
        r = self.r
        bulb = H('#3a6a26', '#4e8432', '#68a040', '#86bc52', '#a6d470', '#c8e894')
        leaf = H('#123c14', '#1c5a1c', '#2a7a24', '#3e9a2e', '#62ba40', '#a4e070')
        n = int(r.integers(6, 9)); a0 = r.uniform(0, 6.28)
        L = []
        for k in range(n):
            a = a0 + 2 * math.pi * k / n + r.normal(0, 0.1)
            out = (k % 2) * 0.7 + r.uniform(0.0, 0.3)                        # 0: an inner, upright leaf; 1: an outer, spread leaf
            L.append((a, out))
        for (a, out) in L:
            d = np.array([math.cos(a), math.sin(a), 0.0])
            # the petiole, swollen into a spongy float a third of the way up, rising out of the crown to the blade
            p0 = c + d * S * 0.006 + np.array([0, 0, S * 0.006])
            p1 = c + d * S * (0.03 + 0.02 * out) + np.array([0, 0, S * (0.03 - 0.008 * out)])
            top = c + d * S * (0.06 + 0.05 * out) + np.array([0, 0, S * (0.095 - 0.045 * out)])
            sw = S * (0.015 + 0.006 * out)
            rf = lambda t, sw=sw: S * 0.0055 + sw * np.exp(-((t - 0.34) / 0.2) ** 2)
            sdb = int(r.integers(1000))
            def tint_b(col, P, N, A, B, sdb=sdb):
                bulbc = ramp(bulb, 0.12 + 0.86 * self.lam(N))
                k_ = np.exp(-((A - 0.32) / 0.2) ** 2)
                col = mix(col, bulbc, k_)
                pore = vnoise(A * 40, B * 50, sdb + 3)
                col = mix(col, bulb[1], np.clip((pore - 0.78) / 0.1, 0, 1) * 0.45 * k_)
                spec = np.clip(N @ HALF, 0, 1) ** 30 * 0.4 * k_
                return np.clip(col + spec[..., None], 0, 1)
            self.tube(self.line_c([p0, p1, top]), 0, 0, bulb[1:], 0.0, sdb, tint=tint_b, rfun=rf)
            # the glossy blade: round, a little cupped, turned outward and toward the light now and then
            Rb = S * r.uniform(0.046, 0.058) * (1.0 - 0.1 * out)
            tilt = 0.22 + 0.5 * out                            # radians from upright
            fwd = nv(d * math.sin(tilt) + np.array([0, 0, 1.0]) * math.cos(tilt) * 0.0 + np.array([0, 0, 0.25]))
            fn = nv(d * math.sin(tilt) + np.array([0, 0, math.cos(tilt)]) + np.array([-0.15, 0.1, 0]) * r.uniform(0, 1))
            upv = nv(np.array([0, 0, 1.0]) - fn * fn[2]) if abs(fn[2]) < 0.99 else nv(d)
            sv_ = nv(np.cross(fn, upv))
            ctr = top + upv * Rb * 0.9
            sdl = int(r.integers(1000)); ph = r.uniform(0, 6.28)
            def geo_l(A, B, ctr=ctr, fn=fn, upv=upv, sv_=sv_, Rb=Rb, ph=ph):
                rho = 0.004 + 0.996 * A; th = B * 2 * math.pi
                rr = Rb * rho * (1 + 0.06 * np.cos(2 * th) + 0.02 * np.sin(3 * th + ph))
                cup = Rb * (0.34 * rho ** 2 + 0.015 * np.sin(th * 2 + ph) * rho ** 2)
                return ctr + (np.cos(th) * rr)[..., None] * sv_ + (np.sin(th) * rr * 1.12)[..., None] * upv + fn * cup[..., None]
            def sh_l(P, N, F, A, B, sdl=sdl, Rb=Rb, upv=upv, sv_=sv_, ctr=ctr):
                rho = 0.004 + 0.996 * A; th = B * 2 * math.pi
                lam = self.lam(N)
                s = (0.0 + 0.78 * lam) * self.grain(P, Rb * 0.08, sdl, 0.04)
                s = s + 0.06 * (fbm(A * 3 + sdl, B * 6, sdl) - 0.5)
                col = ramp(leaf, s)
                # arched veins: from the stalk point at the bottom, sweeping up round to the top
                q = P - (ctr - upv * Rb * 0.95)
                u_ = q @ sv_; v_ = q @ upv
                ang = np.arctan2(u_, v_)
                vv = np.abs(np.cos(ang * 9))
                vein = np.clip((vv - 0.9) / 0.1, 0, 1) * np.clip(rho / 0.2, 0, 1) * (1 - rho ** 4)
                col = mix(col, leaf[5], vein * 0.18)
                col = mix(col, leaf[1], np.clip((rho - 0.9) / 0.1, 0, 1) * 0.25 * (~F))
                col = np.where(F[..., None], col, ramp(leaf[1:], 0.35 + 0.35 * lam))               # the back: paler, matte, never a dark sliver                 # the back: paler, matte
                spec = np.clip(N @ HALF, 0, 1) ** 12 * 0.6 + np.clip(N @ HALF, 0, 1) ** 4 * 0.1
                return np.clip(col + (spec * F)[..., None] * np.array([0.92, 1.0, 0.85]), 0, 1)
            self.splat(geo_l, sh_l, ctr + TOCAM * 0.02, zflat=ctr, zk=0.25)     # flattened depth: blades never cut through each other
        if flower:
            st = c + np.array([0.0, 0.0, 0.0]); top = c + np.array([S * 0.02, S * 0.01, S * 0.37])
            self.tube(self.line_c([st + np.array([0, 0, S * 0.03]), (st + top) / 2 + np.array([S * 0.015, 0, 0]), top]),
                      S * 0.008, S * 0.006, leaf[1:], 0.05, int(r.integers(1000)))
            cols = dict(base=A_(C('#f4ecfc')), mid=A_(C('#d6c2f4')), tip=A_(C('#b494e6')), deep=A_(C('#6a4aa8')), vein=A_(C('#9a78d8')))
            eye = (A_(C('#5a2ec2')), A_(C('#ffd42a')))
            nfl = int(r.integers(8, 11))
            for k in range(nfl):
                h = 0.22 + 0.15 * k / (nfl - 1)
                az = k * 2.4 + r.uniform(-0.2, 0.2)
                d = np.array([math.cos(az), math.sin(az), 0.0])
                fc = c + np.array([S * 0.015, S * 0.008, S * h]) + d * S * 0.028
                fdir = nv(d * 0.8 + np.array([0, 0.35, 0.55]))       # flowers face out and a little toward us
                u, v = basis(fdir)
                for j in range(6):
                    a = j * math.pi / 3 + az * 0.3
                    e = nv(math.cos(a) * u + math.sin(a) * v + fdir * 0.25)
                    top_t = (j == 0)
                    self.petal(fc, fdir, e, S * (0.05 if top_t else 0.043), S * (0.032 if top_t else 0.027), 0.25,
                               cols, 0.06 + 0.001 * j, nveins=7, eye=eye if top_t else None, edge_k=0.86)
        self.shadows.append((c[0] + 0.01 * S, c[1] + 0.01 * S, S * 0.13, S * 0.1, 0.24))

    def _lb(self, seed):
        self.rosette(np.zeros(3), 1.0 + 0.1 * (seed % 3), seed, flower=False)

    def _lbf(self, seed):
        self.rosette(np.zeros(3), 1.05, seed, flower=True)

    # ------------------------------------------------------------------ bèo
    def _beo(self, seed):
        r = self.r
        Lx, Ly = 0.4 + 0.06 * (seed % 2), 0.22
        gr = H('#2a6a1e', '#3e8a26', '#58a432', '#74bc40', '#98d25a', '#c2e888')
        sd = int(r.integers(1000)); rot = r.uniform(-0.3, 0.3)
        cs = 0.011                                           # one frond per cell, about 8 mm
        def geo(A, B):
            x = (A * 2 - 1) * Lx * 1.2; y = (B * 2 - 1) * Ly * 1.3
            return np.stack([x, y, np.full_like(x, 0.0015)], -1)
        def sh(P, N, F, A, B):
            x = P[..., 0]; y = P[..., 1]
            xr = x * math.cos(rot) + y * math.sin(rot); yr = -x * math.sin(rot) + y * math.cos(rot)
            e = (xr / Lx) ** 2 + (yr / Ly) ** 2 + 0.55 * (fbm(x / 0.12, y / 0.08, sd) - 0.5)
            dens = np.clip((1.0 - e) / 0.35, 0, 1)            # thick in the middle, thinning out at the edge
            gx = x / cs; gy = y / (cs * 0.9)
            ix = np.floor(gx).astype(np.int64); iy = np.floor(gy).astype(np.int64)
            best = np.full(x.shape, 9.0); bdx = np.zeros(x.shape); bdy = np.zeros(x.shape); bid = np.zeros(x.shape)
            for oy in (-1, 0, 1):
                for ox in (-1, 0, 1):
                    cx_ = ix + ox; cy_ = iy + oy
                    hx_ = np.sin(cx_ * 127.1 + cy_ * 311.7 + sd) * 43758.5453; hx_ -= np.floor(hx_)
                    hy_ = np.sin(cx_ * 269.5 + cy_ * 183.3 + sd * 1.7) * 43758.5453; hy_ -= np.floor(hy_)
                    px = cx_ + 0.1 + 0.8 * hx_; py = cy_ + 0.1 + 0.8 * hy_
                    dx = gx - px; dy = gy - py
                    d2 = dx * dx * 1.0 + dy * dy * 1.35
                    better = d2 < best
                    best = np.where(better, d2, best); bdx = np.where(better, dx, bdx); bdy = np.where(better, dy, bdy)
                    bid = np.where(better, np.floor(hx_ * 1000), bid)
            rf = 0.42 + 0.08 * ((bid * 13) % 7) / 7.0
            clump = fbm(x / 0.05, y / 0.04, sd + 5)
            keep = ((bid * 37 + 11) % 100) / 100.0 < np.clip(dens * (0.8 + 0.6 * clump), 0, 1) ** 0.45
            on = (best < rf * rf) & keep
            # each frond is a tiny flat dome: lit on the sun's side, a darker rim, a pale growth point
            q = np.sqrt(best) / rf
            nx_ = -bdx / rf * 0.6; ny_ = bdy / rf * 0.6
            lam = np.clip(0.75 + 0.35 * (nx_ * (-LIGHT[0]) * -1 + ny_ * LIGHT[1]), 0, 1.1)
            tone = 0.3 + 0.4 * ((bid * 7) % 11) / 11.0 + 0.3 * (lam - 0.75) + 0.25 * (clump - 0.5)
            col = ramp(gr, tone)
            col = mix(col, gr[0], np.clip((q - 0.75) / 0.25, 0, 1) * 0.55)
            col = mix(col, gr[5], np.exp(-((bdx + 0.12) ** 2 + (bdy - 0.08) ** 2) / 0.006) * 0.55)
            col = mix(col, gr[1], (dens < 0.5) * 0.15)
            return col, on
        self.splat(geo, sh, np.zeros(3) + TOCAM * -0.1, edge_k=0.92, edge_w=0.35)
        # bèo cái rosettes riding in the film
        pal = H('#3e6e32', '#557f40', '#6e9a52', '#8cb46c', '#acca8c', '#cce0b0')
        nr = int(r.integers(4, 8))
        for k in range(nr):
            a = r.uniform(0, 6.28); dd = math.sqrt(r.uniform(0, 1)) * 0.75
            c = np.array([math.cos(a) * Lx * dd, math.sin(a) * Ly * dd, 0.0])
            R = r.uniform(0.035, 0.06)
            nl = int(r.integers(7, 11)); a0 = r.uniform(0, 6.28)
            for j in range(nl):
                az = a0 + 2 * math.pi * j / nl + r.normal(0, 0.12)
                inner = j % 2
                el = math.radians(r.uniform(28, 48) + 14 * inner)
                e = np.array([math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)])
                s = nv(np.cross(UP, e)); f = nv(np.cross(e, s))
                Ll = R * (0.9 - 0.25 * inner) * r.uniform(0.9, 1.1); Wl = Ll * 0.62
                sdl = int(r.integers(1000))
                def geo_p(A, B, c=c, e=e, s=s, f=f, Ll=Ll, Wl=Wl):
                    t = A; w = B * 2 - 1
                    pw = np.clip(np.sin(np.pi * np.clip(t * 0.62 + 0.06, 0, 1)) ** 0.7 * (0.35 + 0.65 * t ** 0.5), 0, 1)
                    pw = pw * np.sqrt(np.clip(1 - np.clip((t - 0.86) / 0.14, 0, 1) ** 2, 0, 1))    # a rounded, flat top
                    return c + e * (Ll * t)[..., None] + s * (Wl * 0.5 * w * pw)[..., None] + f * (Ll * (0.12 * w * w * pw - 0.06 * t * t))[..., None]
                def sh_p(P, N, F, A, B, sdl=sdl, Ll=Ll):
                    t = A; w = B * 2 - 1; lam = self.lam(N)
                    ridge = np.abs(np.cos(w * math.pi * 3.5 * (1 - 0.2 * t)))             # the deep parallel ribs
                    s_ = (0.12 + 0.82 * lam) * (0.8 + 0.25 * ridge) * self.grain(P, Ll * 0.05, sdl, 0.06)
                    col = ramp(pal, s_)
                    view = np.abs(N @ TOCAM)
                    col = mix(col, pal[5], (1 - view) ** 2 * 0.4)                           # velvet: pale at grazing
                    col = mix(col, pal[0], np.clip((0.15 - t) / 0.15, 0, 1) * 0.4)
                    return col
                self.splat(geo_p, sh_p, c + e * Ll * 0.5 + TOCAM * 0.01, edge_k=0.84)
            self.shadows.append((c[0], c[1], R * 1.3, R * 1.0, 0.18))

    # ------------------------------------------------------------------ bông súng
    def sung_pad(self, c, R, rot, young=False):
        r = self.r
        pal = H('#3a2e1a', '#55402a', '#6e5632', '#86703e', '#a08a52', '#bca46c') if young else \
            H('#173c1c', '#225228', '#2e6a34', '#428440', '#5e9e52', '#86ba6e')
        red = A_(C('#8a2a36')); maroon = A_(C('#4a1e22'))
        notch = 0.13; ph = r.uniform(0, 6.28); sd = int(r.integers(1000)); nvein = int(r.integers(16, 22))
        def geo(A, B):
            rho = 0.004 + 0.996 * A; th = notch / 2 + (2 * math.pi - notch) * B
            rr = R * rho * (1 + 0.012 * np.sin(th * 4 + ph) + 0.012 * np.abs(np.sin(th * 34 + ph)))
            z = 0.003 + R * (0.012 * (1 - rho ** 2) + 0.02 * np.sin(th * 2 + ph) * rho ** 3 + 0.08 * np.clip(rho - 0.94, 0, 1))
            return np.stack([c[0] + np.cos(th + rot) * rr, c[1] + np.sin(th + rot) * rr, c[2] + z], -1)
        def sh(P, N, F, A, B):
            rho = 0.004 + 0.996 * A; th = notch / 2 + (2 * math.pi - notch) * B
            lam = self.lam(N)
            s = 0.5 + 1.2 * (lam - 0.6) + 0.08 * (fbm(P[..., 0] / (R * 0.4), P[..., 1] / (R * 0.4), sd) - 0.5)
            s = s * self.grain(P, R * 0.025, sd + 3, 0.05)
            col = ramp(pal, s)
            ang = th * nvein / (2 * math.pi)
            dv = np.abs(ang - np.round(ang)) * (2 * math.pi / nvein) * rho * R
            wv = R * (0.007 + 0.006 * (1 - rho))
            v = np.exp(-(dv / wv) ** 2) * np.clip((rho - 0.05) / 0.08, 0, 1)
            col = mix(col, pal[5], v * 0.3)
            if not young:      # maroon mottling of the tropical súng pad
                bl = fbm(P[..., 0] / (R * 0.09), P[..., 1] / (R * 0.09), sd + 9)
                col = mix(col, maroon, np.clip((bl - 0.64) / 0.06, 0, 1) * 0.35)
            lip = np.clip((rho - 0.955) / 0.045, 0, 1)                   # the red underside shows at the curled rim
            col = mix(col, red, lip * 0.75)
            col = mix(col, pal[5], np.clip((0.04 - rho) / 0.02, 0, 1) * 0.6)
            spec = np.clip(N @ HALF, 0, 1) ** 40 * 0.3
            return np.clip(col + spec[..., None], 0, 1)
        wsh = self.water_sh; pa = self.pa
        def shadow():
            P = pa.P
            poly = [P(c + np.array([math.cos(t + rot), math.sin(t + rot), 0]) * R) for t in np.linspace(notch / 2, 2 * math.pi - notch / 2, 40)] + [P(c)]
            sh_ = [(x + pa.u(0.6), y + pa.u(0.8)) for x, y in poly]
            pa.path(sh_); pa.ctx.set_source_rgba(*wsh, 0.25); pa.ctx.fill()
        self.items.append((c + TOCAM * -0.31, shadow))
        self.splat(geo, sh, c + TOCAM * -0.3, zflat=c)

    def sung_flower(self, p, f, R, cols, k):
        r = self.r; u, v = basis(f)
        sep = dict(base=A_(C('#3e6a2a')), mid=A_(C('#4e7e34')), tip=A_(C('#5e8a3a')), deep=A_(C('#24401a')), vein=A_(C('#2e5220')))
        # four sepals, green outside and coloured inside, spread wide
        for j in range(4):
            a = j * math.pi / 2 + k + 0.4
            e = nv(math.cos(a) * u + math.sin(a) * v + f * 0.15)
            self.petal(p, f, e, R * 0.95, R * 0.34, 0.12, cols, 0.0 + 0.001 * j, nveins=7, edge_k=0.84)
        # petals: narrow and pointed, three rings rising toward the middle
        for ri, (n, Ls, el, cup) in enumerate([(8, 0.95, 0.25, 0.15), (8, 0.82, 0.62, 0.25), (6, 0.62, 1.05, 0.35)]):
            for j in range(n):
                a = (j + 0.5 * (ri % 2)) * 2 * math.pi / n + k + r.normal(0, 0.06)
                e = nv((math.cos(a) * u + math.sin(a) * v) * math.cos(el) + f * math.sin(el))
                self.petal(p + f * R * 0.02 * ri, f, e, R * Ls, R * 0.26, cup, cols, 0.03 + 0.03 * ri + 0.001 * j,
                           prof=[0.2, 0.62, 0.95, 1.0, 0.7, 0.3, 0.0], nveins=7)
        # the heart: a cup of golden stamens, tipped with the flower's colour
        gold = H('#9a6a08', '#d09a14', '#f4c42a', '#ffdc58', '#fff0a8')
        tipc = cols['tip']; nst = 40; lens = r.uniform(0.75, 1.0, nst)
        def geo_st(A, B):
            th = B * 2 * math.pi
            rad = np.cos(th)[..., None] * u + np.sin(th)[..., None] * v
            return p + f * (R * (0.04 + 0.26 * A))[..., None] + rad * (R * (0.06 + 0.1 * A))[..., None]
        def sh_st(P, N, F, A, B):
            fi = B * nst; i = np.floor(fi).astype(int) % nst; fr = fi - np.floor(fi)
            on = (np.abs(fr - 0.5) < 0.4) & (A < lens[i])
            lam = self.lam(N); across = 1 - ((fr - 0.5) / 0.4) ** 2
            col = ramp(gold[:4], 0.2 + 0.45 * lam + 0.35 * across)
            col = mix(col, tipc, np.clip((A - (lens[i] - 0.2)) / 0.1, 0, 1) * 0.7)
            return col, on
        self.splat(geo_st, sh_st, p + f * 0.02 + TOCAM * 0.12, edge_k=0.9, edge_w=0.4)
        def geo_c(A, B):
            rho = 0.004 + 0.996 * A; th = B * 2 * math.pi
            rad = np.cos(th)[..., None] * u + np.sin(th)[..., None] * v
            return p + f * (R * (0.1 - 0.03 * rho))[..., None] + rad * (R * 0.06 * rho)[..., None]
        def sh_c(P, N, F, A, B):
            lam = self.lam(N); return ramp(gold, 0.35 + 0.6 * lam - 0.2 * (B * 12 % 1 < 0.15))
        self.splat(geo_c, sh_c, p + f * 0.02 + TOCAM * 0.11, edge_k=0.85)

    def sung_bud(self, p, f, R, cols):
        u, v = basis(f); sd = int(self.r.integers(1000)); ph = self.r.uniform(0, 6.28)
        green = A_(C('#4e7a30'))
        def geo(A, B):
            h = A; th = B * 2 * math.pi
            w = np.sin(np.pi * np.clip(h, 0, 1)) ** 0.7 * (1 - 0.55 * h) * (1 + 0.04 * np.sin(th * 4 + ph))
            rad = np.cos(th)[..., None] * u + np.sin(th)[..., None] * v
            return p + f * (R * 3.0 * h)[..., None] + rad * (R * w)[..., None]
        def sh(P, N, F, A, B):
            h = A; th = B * 2 * math.pi; lam = self.lam(N)
            sa = (th - ph) * 4 / (2 * math.pi); fr = sa - np.floor(sa)
            sepal = (np.abs(fr - 0.5) < 0.36 - 0.25 * h) & (h < 0.92)      # four green sepals, the petals show between
            base = np.where(sepal[..., None], green, ramp([cols['mid'], cols['tip']], h))
            sv = np.clip(0.35 + 0.78 * lam, 0, 1.05) * self.grain(P, R * 0.1, sd, 0.03)
            col = mix(np.where(sepal[..., None], A_(C('#24401a')), cols['deep']), base, np.clip(sv, 0, 1))
            col = mix(col, A_(C('#8a2a36')), sepal * np.exp(-((fr - 0.5 + (0.36 - 0.25 * h)) / 0.03) ** 2) * 0.4)
            return col
        self.splat(geo, sh, p + f * R + TOCAM * 0.05, edge_k=0.84)

    def _sung(self, seed):
        r = self.r; q = seed % 4
        b, m, t, d, v = SUNG[q]
        cols = dict(base=A_(C(b)), mid=A_(C(m)), tip=A_(C(t)), deep=A_(C(d)), vein=A_(C(v)))
        stem = H('#3a2a1a', '#5a3a26', '#6e5a2e', '#86743a', '#a08e4a')
        npad = [8, 7, 9, 8][q]; a0 = r.uniform(0, 6.28)
        for k in range(npad):
            a = a0 + k * 2.4 + r.normal(0, 0.3); d_ = 0.12 + 0.52 * math.sqrt((k + 0.5) / npad)
            c = np.array([math.cos(a) * d_, math.sin(a) * d_ * 0.8, 0.0])
            self.sung_pad(c, r.uniform(0.13, 0.19), r.uniform(0, 6.28), young=(k == npad - 2))
        nfl = [2, 2, 1, 2][q]
        for k in range(nfl):
            a = a0 + 1.3 + k * 2.6 + r.normal(0, 0.3); d_ = r.uniform(0.05, 0.3)
            base = np.array([math.cos(a) * d_, math.sin(a) * d_ * 0.7, 0.0])
            H_ = r.uniform(0.1, 0.2); top = base + np.array([math.cos(a) * 0.03, 0.02, H_])
            self.tube(self.line_c([base, (base + top) / 2 + np.array([0.01, 0, 0]), top]), 0.008, 0.007, stem, -0.02, int(r.integers(1000)), zcut=0.0)
            self.sung_flower(top, nv(np.array([math.cos(a) * 0.2, 0.35, 1.0])), r.uniform(0.1, 0.13), cols, k)
        for k in range([1, 2, 2, 1][q]):
            a = a0 + 3.9 + k * 1.9; d_ = r.uniform(0.1, 0.35)
            base = np.array([math.cos(a) * d_, math.sin(a) * d_ * 0.7, 0.0])
            top = base + np.array([0.0, 0.0, r.uniform(0.04, 0.12)])
            self.tube(self.line_c([base, top]), 0.007, 0.006, stem, -0.02, int(r.integers(1000)), zcut=0.0)
            self.sung_bud(top, nv(np.array([0.15 * math.cos(a), 0.1, 1.0])), r.uniform(0.022, 0.03), cols)
        self.shadows.append((0.0, 0.05, 0.42, 0.34, 0.06))

    # ------------------------------------------------------------------ bè rau muống
    def _rau(self, seed):
        r = self.r; q = seed % 4
        bam = H('#5a4418', '#7a6026', '#9a7e38', '#b89c50', '#d2b86c', '#e4d08e')
        rope = H('#3a2a16', '#5a4224', '#7a5c34', '#9a7a48')
        rot = r.uniform(-0.12, 0.12) + [0, 0.3, -0.25, 0.1][q]
        hx, hy = [0.52, 0.46, 0.55, 0.48][q], [0.36, 0.4, 0.32, 0.38][q]
        Rm = np.array([[math.cos(rot), -math.sin(rot), 0], [math.sin(rot), math.cos(rot), 0], [0, 0, 1.0]])
        def W(x, y, z=0.0): return Rm @ np.array([x, y, z])
        rp = 0.022
        poles = [((-hx - 0.07, -hy, 0), (hx + 0.07, -hy, 0)), ((-hx - 0.07, hy, 0), (hx + 0.07, hy, 0)),
                 ((-hx, -hy - 0.07, rp * 1.6), (-hx, hy + 0.07, rp * 1.6)), ((hx, -hy - 0.07, rp * 1.6), (hx, hy + 0.07, rp * 1.6))]
        FRAME = False                 # Link 2026-11-08: no bamboo frame, the runners float free
        if FRAME:
            for (a, b) in poles:
                A = W(*a) + np.array([0, 0, rp * 0.15]); B = W(*b) + np.array([0, 0, rp * 0.15])
                sag = r.uniform(-0.01, 0.01)
                self.tube(self.line_c([A, (A + B) / 2 + np.array([0, 0, sag]), B]), rp, rp * 0.92, bam, 0.0, int(r.integers(1000)),
                          node=0.2 + r.uniform(-0.02, 0.02), node_col=bam[0], zcut=-0.002)
            for sx in (-1, 1):            # lashings at the corners: a few turns of rope
                for sy in (-1, 1):
                    cc = W(sx * hx, sy * hy, rp * 1.0)
                    for t in range(3):
                        off = W(0, 0, 0) + Rm @ np.array([sx * (t - 1) * 0.012, 0, 0])
                        def ring(tt, cc=cc, off=off, sy=sy):
                            th = tt * 2 * math.pi
                            return cc + off + np.stack([np.zeros_like(th), np.cos(th) * rp * 1.15, np.sin(th) * rp * 1.15 + rp * 0.4], -1) @ Rm.T
                        self.tube(ring, 0.0045, 0.0045, rope, 0.03, int(r.integers(1000)), zcut=0.0)
        # no round shadow under the mat (Link 2026-11-08): it floats flat, the water shows its reflection instead
        # water spinach: runners lying on the water inside the frame (some trailing out), leaves standing up at the nodes
        stem = H('#4a6a2a', '#628a36', '#7ea846', '#9cc25c', '#bcd884')
        node_c = A_(C('#8a5a7a'))
        leafp = H('#174a18', '#226a20', '#32862c', '#4ca23c', '#72be54', '#a6dc80')
        nrun = [15, 14, 16, 15][q]
        flowers = []
        for k in range(nrun):
            # each runner starts somewhere in the frame and wanders off in its own direction, some out over the poles
            sx0, sy0 = r.uniform(-hx * 0.9, hx * 0.9), r.uniform(-hy * 0.9, hy * 0.9)
            ang = r.uniform(0, 6.28); Lr = r.uniform(0.3, 0.55); bend = r.normal(0, 0.8)
            pts = []
            for i in range(6):
                t = i / 5; aa = ang + bend * t
                lim = 1.0 if k % 4 else 1.15      # most stay inside the poles, now and then one trails over
                px_, py_ = sx0 + math.cos(ang + bend * t * 0.5) * Lr * t, sy0 + math.sin(ang + bend * t * 0.5) * Lr * t * 0.9
                if not FRAME:             # free mat: keep it a soft oval, not a box
                    rr = math.hypot(px_ / (hx * lim * 1.05), py_ / (hy * lim * 1.05))
                    if rr > 1: px_, py_ = px_ / rr, py_ / rr
                pts.append(W(float(np.clip(px_, -hx * lim * 1.05, hx * lim * 1.05)), float(np.clip(py_, -hy * lim * 1.05, hy * lim * 1.05)), 0.006))
            x0, x1 = 0.0, Lr
            cf = self.line_c(pts)
            self.tube(cf, 0.0065, 0.0055, stem, 0.0, int(r.integers(1000)), zcut=0.0,
                      tint=lambda col, P, N, A, B, k=k: mix(col, node_c, np.exp(-(((A * 8 + k * 0.3) % 1 - 0.5) / 0.05) ** 2) * 0.45))
            nn = int(abs(x1 - x0) / 0.04)
            for i in range(nn):
                t = (i + 0.5) / nn
                p0 = cf(np.array([t]))[0] + np.array([0, 0, 0.004])
                tg = nv(cf(np.array([min(1, t + 0.02)]))[0] - cf(np.array([max(0, t - 0.02)]))[0])
                side = (1 if i % 2 else -1)
                sd_ = nv(np.cross(UP, tg)) * side
                el = math.radians(r.uniform(25, 50))
                e = nv(sd_ * math.cos(el) * 0.75 + tg * 0.35 + UP * math.sin(el))
                Lp = r.uniform(0.04, 0.065)
                tip = p0 + e * Lp
                self.tube(self.line_c([p0, tip]), 0.0032, 0.0028, stem, 0.01, int(r.integers(1000)))
                e2 = nv(sd_ * 0.8 + tg * r.normal(0, 0.6) + UP * r.uniform(-0.05, 0.3))
                self.arrow_leaf(tip, e2, r.uniform(0.09, 0.12), r.uniform(0.036, 0.046), leafp)
                if r.uniform() < 0.05 and len(flowers) < 4: flowers.append((p0, sd_))
        if len(flowers) < 2:
            for k in range(2 - len(flowers)):
                flowers.append((W(r.uniform(-hx, hx) * 0.6, r.uniform(-hy, hy) * 0.6, 0.006), nv(np.array([r.normal(), r.normal(), 0]))))
        for (p0, sd_) in flowers:
            f = nv(sd_ * 0.6 + UP * 0.8 + np.array([0, 0.3, 0]))
            top = p0 + f * 0.05
            self.tube(self.line_c([p0, top]), 0.003, 0.0028, stem, 0.01, int(r.integers(1000)))
            self.trumpet(top, f, 0.032)

    def arrow_leaf(self, b, e, L, W, pal):
        """an arrow-shaped water spinach leaf from b along e, its two back lobes spread; a pale midrib, a little gloss"""
        s = nv(np.cross(UP, e)) if np.linalg.norm(np.cross(UP, e)) > 1e-3 else np.array([1.0, 0, 0])
        f = nv(np.cross(e, s))
        if f[2] < 0: f = -f
        sd = int(self.r.integers(1000)); t0 = -0.2
        def geo(A, B):
            t = t0 + A * (1 - t0); w = B * 2 - 1
            hw = np.where(t >= 0, 0.5 * W * (1 - t) ** 0.6 * (0.8 + 0.2 * np.cos(t * 2.4)), 0.5 * W * (1 + (-t) * 1.4))
            x = e * (L * t)[..., None] + s * (hw * w)[..., None] + f * (L * (0.08 * w * w - 0.1 * np.clip(t, 0, 1) ** 2))[..., None]
            return b + x
        def sh(P, N, F, A, B):
            t = t0 + A * (1 - t0); w = B * 2 - 1
            notch = (t < 0) & (np.abs(w) < 0.25 + (-t) * 2.2)       # cut between the two back lobes
            lam = self.lam(N)
            s_ = (0.1 + 0.9 * lam) * self.grain(P, L * 0.05, sd, 0.04)
            col = ramp(pal, s_)
            col = mix(col, pal[5], np.exp(-(w / 0.05) ** 2) * np.clip(1 - np.abs(t), 0, 1) * 0.35)
            vv = np.abs(np.cos((w * 4 - t * 3) * math.pi)) * (t > 0)
            col = mix(col, pal[4], np.clip((vv - 0.92) / 0.08, 0, 1) * 0.15)
            col = mix(col, ramp(pal[:4], s_ * 0.85), (~F) * 0.4)
            spec = np.clip(N @ HALF, 0, 1) ** 26 * 0.3 * F
            return np.clip(col + spec[..., None], 0, 1), ~notch
        self.splat(geo, sh, b + e * L * 0.4 + TOCAM * 0.02, edge_k=0.82)

    def trumpet(self, p, f, R):
        """a morning-glory trumpet: white, a lilac throat, five faint folds"""
        u, v = basis(f); sd = int(self.r.integers(1000))
        white = A_(C('#fbfaf6')); lil = A_(C('#c890d8')); deep = A_(C('#9a8aa8')); throat = A_(C('#8a3a9a'))
        def geo(A, B):
            t = A; th = B * 2 * math.pi
            rad = R * (0.12 + 0.88 * t ** 2.2) * (1 + 0.05 * np.cos(th * 5) * t)
            rv = np.cos(th)[..., None] * u + np.sin(th)[..., None] * v
            return p + f * (R * 1.1 * t - R * 0.15 * t ** 4)[..., None] + rv * rad[..., None]
        def sh(P, N, F, A, B):
            t = A; th = B * 2 * math.pi; lam = self.lam(N)
            base = mix(throat, mix(lil, white, np.clip((t - 0.35) / 0.3, 0, 1)), np.clip(t / 0.35, 0, 1))
            fold = np.abs(np.cos(th * 2.5)); base = mix(base, lil, np.clip((fold - 0.9) / 0.1, 0, 1) * 0.25 * (t > 0.3))
            sv = np.clip(0.4 + 0.72 * lam, 0, 1.05) * self.grain(P, R * 0.1, sd, 0.02)
            return mix(deep, base, np.clip(sv, 0, 1))
        self.splat(geo, sh, p + f * R * 0.5 + TOCAM * 0.05, edge_k=0.86)


class Frame:
    def __init__(self, pa, kind, seed): self.m = Kit(kind, seed, pa)
    def paint(self): self.m.paint()


BBS = dict(lb=(-13, -15, 13, 6), lbf=(-13, -22, 13, 6), beo=(-24, -9, 24, 9), sung=(-40, -26, 40, 24), rau=(-36, -24, 36, 22))
FRAMES = ([dict(key='lb%d' % s, kind='lb', seed=s) for s in range(6)] + [dict(key='lbf%d' % s, kind='lbf', seed=s) for s in range(3)] +
          [dict(key='beo%d' % s, kind='beo', seed=s) for s in range(4)] + [dict(key='sung%d' % s, kind='sung', seed=s) for s in range(4)] +
          [dict(key='rau%d' % s, kind='rau', seed=s) for s in range(4)])


def render(fr, night):
    return co.to_image(co.render(Frame, dict(kind=fr['kind'], seed=fr['seed'], key=fr['key']), BBS[fr['kind']], night)), BBS[fr['kind']]


if __name__ == '__main__':
    from PIL import Image
    if sys.argv[1] == 'prev':
        night = len(sys.argv) > 3 and sys.argv[3] == 'n'
        keys = sys.argv[4].split(',') if len(sys.argv) > 4 else [f['key'] for f in FRAMES]
        ims = [render(f, night)[0] for f in FRAMES if f['key'] in keys]
        w = sum(i.width for i in ims) + 4 * len(ims); h = max(i.height for i in ims)
        o = Image.new('RGBA', (w, h), (40, 70, 80, 255) if night else (70, 120, 140, 255)); x = 0
        for im in ims: o.alpha_composite(im, (x, h - im.height)); x += im.width + 4
        o.save(sys.argv[2]); print(o.size)
    elif sys.argv[1] == 'one':      # one frame (day and night) to a pair of pngs, for parallel atlas builds
        fr = [f for f in FRAMES if f['key'] == sys.argv[2]][0]
        for night in (False, True):
            im, bb = render(fr, night); a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            im.crop((x0, y0, x1, y1)).save(os.path.join(sys.argv[3], '%s%s.png' % ('nd'[not night], fr['key'])))
            json.dump([bb[0] + x0 / co.RS, bb[1] + y0 / co.RS], open(os.path.join(sys.argv[3], '%s%s.json' % ('nd'[not night], fr['key'])), 'w'))
    elif sys.argv[1] == 'pack':     # pack the pngs of 'one' into the sheet and its table
        d = sys.argv[2]; crops = []
        for night in 'dn':
            for fr in FRAMES:
                n = night + fr['key']; dx, dy = json.load(open(os.path.join(d, n + '.json')))
                crops.append((n, Image.open(os.path.join(d, n + '.png')), dx, dy))
        x = y = rowh = 0; pos = {}; maxw = 4096
        for name, im, dx, dy in crops:
            if x + im.width > maxw: x = 0; y += rowh + 2; rowh = 0
            pos[name] = (x, y); x += im.width + 2; rowh = max(rowh, im.height)
        Wt = max(pos[n][0] + im.width for n, im, _, _ in crops); Ht = y + rowh
        out = Image.new('RGBA', (Wt, Ht), (0, 0, 0, 0)); table = {}
        for name, im, dx, dy in crops:
            sx, sy = pos[name]; out.paste(im, (sx, sy))
            table[name] = [sx, sy, im.width, im.height, round(dx, 2), round(dy, 2), round(im.width / co.RS, 2), round(im.height / co.RS, 2)]
        out.save(os.path.join(d, sys.argv[3]), 'WEBP', quality=88, alpha_quality=100, method=6)
        json.dump(table, open(sys.argv[4], 'w'), separators=(',', ':')); print(out.size)
