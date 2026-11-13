# 2026-11-09 Link: "Theo kiểu vẽ hoa sen là đẹp nhất lấy đó mà theo" -> every plant redrawn with the lotus kit (src/sen):
# each part a parametric 3D surface, lit per pixel from its own normal, painted detail on top, one shared z-buffer per
# sprite, the kit's thin edge in its own colour, 9 px per game unit. Real-world size: KU game px per metre.
#   python3 caysen.py prev OUT.png [d|n] key1,key2
import math, os, sys, json
import numpy as np, cairo
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'co', 'dambut', 'hoaco', 'sen', 'thuysinh'):
    sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import C, nv, LIGHT, TOCAM
import co
from co import ground_shadow
import sen
from sen import Sen, A_, ramp, vnoise, fbm, mix, HALF
from hoaco import UP, basis
import thuysinh
from thuysinh import Kit as TKit, H

KU = sen.KU
co.KU = KU


TRI = [(-0.26, -0.08), (0.0, 0.17), (0.26, -0.1)]      # Link 09:50: every crop = 3 plants on these spots, every stage
# 2026-11-09 audit (Link "check lại hết ... đúng logic"): stage 1 seedlings all ~10 game px (Link: lúa/nếp/bắp/mía too), stage 3 at least
# cà tím height (~29 px). Whole plant scaled round the plot centre, spots kept (tri() divides by SC).
STAGE_SC = {('lua', 1): 0.62, ('nep', 1): 0.59, ('bap', 1): 0.46, ('mia', 1): 0.53, ('carot', 1): 0.72, ('bido', 1): 0.85,
            ('duahau', 1): 0.85, ('sa', 1): 0.85, ('ot', 1): 1.25, ('bong_vai', 1): 1.4, ('cham', 1): 1.6, ('me', 1): 1.4,
            ('dau_nanh', 1): 1.1, ('dau_xanh', 1): 1.1, ('dauphong', 1): 1.4, ('xa_lach', 1): 1.2, ('dau', 1): 1.4,
            ('hanh', 1): 1.25, ('hanh_tay', 1): 1.25, ('rau_ram', 1): 1.25, ('gung', 1): 1.1, ('nghe', 1): 1.1, ('la_dua', 1): 1.25,
            ('cai', 1): 1.1,
            ('bong_vai', 3): 1.08, ('cham', 3): 1.05, ('me', 3): 1.2, ('rau_ram', 3): 1.16, ('nghe', 3): 1.16, ('dau', 3): 1.2,
            ('dau_nanh', 3): 1.14, ('dau_xanh', 3): 1.12, ('dauphong', 3): 1.16,
            ('bau', 1): 1.42, ('bi_dao', 1): 1.42, ('kho_qua', 1): 1.62, ('dau_rong', 1): 1.42,
            ('muop', 1): 1.42, ('dau_den', 1): 1.1, ('dau_den', 3): 1.12, ('dau_bap', 1): 1.42, ('khoai_mon', 1): 1.6, ('khoai_mon', 2): 1.22, ('khoai_mon', 3): 1.15}


class Kit(TKit):
    EDGE_DZ = 0.003

    def __init__(self, kind, seed, pa):
        self.pa = pa; self.seed = seed; self.kind = kind
        self.SC = 1.28 if kind in ('carot', 'bido', 'duahau', 'khoai', 'xa_lach') else 1.0      # Link 09:24: these drawn bigger
        self.SC *= STAGE_SC.get((kind, seed % 4), 1.0)      # 2026-11-09 audit: same stage = same size across crops
        self.r = np.random.default_rng(seed * 9173 + sum(map(ord, kind)) * 977 + 11)
        self.items = []; self.shadows = []
        getattr(self, '_' + kind)(seed)

    def shadow(self):
        # soft shadows: stacked ellipses, dark in the middle and fading out (no hard-edged plate)
        return      # Link 2026-11-09: no shadow under plants; real sun-cast shadows come later
        pa = self.pa; c = pa.ctx
        for (x, y, rx, ry, a) in self.shadows:
            px, py = pa.P(np.array([x, y, 0.0]))
            c.save(); c.translate(px, py); c.scale(rx * pa.k, ry * pa.k * 0.5)
            g = cairo.RadialGradient(0, 0, 0, 0, 0, 1)
            for t in np.linspace(0, 1, 24):
                g.add_color_stop_rgba(t, 0, 0, 0, a * (1 - t * t) ** 1.5)
            c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.set_source(g); c.fill(); c.restore()

    def splat(self, geo, shade_fn, key_pt, **kw):
        sc = self.SC
        if sc != 1.0:       # the whole plant scaled round the plot centre (shading/z-cuts see the scaled points)
            g0 = geo; geo = lambda A, B: g0(A, B) * sc; key_pt = np.asarray(key_pt) * sc
        return TKit.splat(self, geo, shade_fn, key_pt, **kw)

    # ------------------------------------------------------------------ generic parts
    def strap(self, cf, W, pal, key, sd=None, fold=0.18, tipcol=None, tipk=0.0, wprof=None, edge_k=0.82, gloss=0.18,
              vein_n=5, mid=None, zao=None):
        """a grass blade along the curve cf(t): width W (tapering), folded a little along the midrib, parallel veins,
        tip colour tipcol from tipk of its length (yellowing / drying tips)"""
        sd = int(self.r.integers(1000)) if sd is None else sd
        wp_t = np.array([0, 0.08, 0.3, 0.7, 0.92, 1.0]); wp_w = np.array(wprof or [0.55, 0.9, 1.0, 0.8, 0.4, 0.0])
        def frame(t):
            c = cf(t); e = 1e-3
            T = cf(np.clip(t + e, 0, 1)) - cf(np.clip(t - e, 0, 1))
            T = T / np.maximum(np.linalg.norm(T, axis=-1, keepdims=True), 1e-9)
            s = np.cross(T, np.array([0.0, 0.0, 1.0]))
            bad = np.linalg.norm(s, axis=-1, keepdims=True) < 1e-3
            s = np.where(bad, np.array([1.0, 0, 0]), s)
            s = s / np.maximum(np.linalg.norm(s, axis=-1, keepdims=True), 1e-9)
            n = np.cross(s, T)
            return c, s, n
        def geo(A, B):
            c, s, n = frame(A); w = (B * 2 - 1)[..., None]
            hw = (W * 0.5 * np.interp(A, wp_t, wp_w))[..., None]
            return c + s * hw * w + n * (np.abs(w) * hw * fold)
        def sh(P, N, F, A, B):
            w = B * 2 - 1; lam = self.lam(N)
            s_ = (0.12 + 0.86 * lam) * self.grain(P, W * 0.6, sd, 0.05)
            col = ramp(pal, s_)
            vv = np.abs(np.cos(w * math.pi * vein_n))
            col = col * (1 - 0.06 * np.clip((vv - 0.8) / 0.2, 0, 1))[..., None]
            col = mix(col, pal[-1], np.exp(-(w / 0.07) ** 2) * 0.22 * (A < 0.95))           # pale midrib
            if tipcol is not None and tipk < 1:
                tk = np.clip((A - tipk) / (1 - tipk + 1e-6), 0, 1) ** 1.3
                tc = tipcol[0] + (tipcol[1] - tipcol[0]) * np.clip(0.2 + 0.8 * lam, 0, 1)[..., None]
                col = mix(col, tc, tk * 0.95)
            col = np.where(F[..., None], col, col * 0.86 + 0.06)
            if zao is not None: col = col * (zao[0] + (1 - zao[0]) * np.clip(P[..., 2] / zao[1], 0, 1))[..., None]
            spec = np.clip(N @ HALF, 0, 1) ** 18 * gloss * F
            return np.clip(col + spec[..., None], 0, 1)
        self.splat(geo, sh, cf(np.array([0.5]))[0] + TOCAM * key, edge_k=edge_k)

    def ellip(self, c, ax, a, b, pal, key, sd=None, spec=0.3, tint=None, edge_k=0.8, bulge=0.0):
        """an ellipsoid (grain, fruit) centred at c, long axis ax (half length a), half width b"""
        sd = int(self.r.integers(1000)) if sd is None else sd
        ax = nv(ax); u, v = basis(ax)
        def geo(A, B):
            th = A * math.pi; ph = B * 2 * math.pi
            st = np.sin(th)[..., None]
            rr = b * (1 + bulge * np.cos(th))[..., None]
            return c + ax * (a * np.cos(th))[..., None] + (np.cos(ph)[..., None] * u + np.sin(ph)[..., None] * v) * st * rr
        def sh(P, N, F, A, B):
            lam = self.lam(N)
            s_ = (0.1 + 0.88 * lam) * self.grain(P, b * 0.5, sd, 0.04)
            col = ramp(pal, s_)
            if tint is not None: col = tint(col, P, N, A, B)
            sp = np.clip(N @ HALF, 0, 1) ** 20 * spec
            return np.clip(col + sp[..., None], 0, 1)
        self.splat(geo, sh, c + TOCAM * key, edge_k=edge_k)

    # ------------------------------------------------------------------ lúa
    def _lua(self, seed):
        """a hill of ripe rice: ~20 tillers, arching strap leaves drying at the tips, golden panicles bowed over"""
        r = self.r
        stage = seed % 4      # 3 ripe
        leafp = H('#2a5a18', '#3a7420', '#4e902a', '#66aa36', '#84c048', '#b0d874')
        culmp = H('#3a6a1e', '#4e8428', '#66a034', '#82b844', '#a6d064')
        dry = (A_(C('#8a8a2e')), A_(C('#c8c470')))
        grain = H('#8a5a10', '#b47c14', '#d8a224', '#efc040', '#fadc78', '#fff0b4')
        rach = H('#7a6a1c', '#a08c2c', '#c4ae44', '#ddc866')
        sz = {1: 0.34, 2: 0.78}.get(stage, 1.0)
        if stage < 3:      # young rice: fresh, brighter green, no drying tips
            leafp = H('#2e6a18', '#409020', '#56a82a', '#70c036', '#92d24c', '#bce47c')
            culmp = H('#3e7a1e', '#529428', '#6aae34', '#88c444', '#aad866')
        NEP = self.kind == 'nep'
        if NEP:     # nếp: the live lúa frames are a .35 blend of these bright palettes with the dark v899 ones -> blend
            # the palettes the same way; nếp stands a little taller, heads heavier, grains a warm pale straw (hạt nếp)
            mixp = lambda dk, br, t=0.35: [x * (1 - t) + y * t for x, y in zip(dk, br)]
            leafp = mixp(H('#173e12', '#225418', '#306c20', '#42862a', '#5ea03a', '#8cbc5e'), leafp)
            culmp = mixp(H('#244a16', '#346220', '#4a7c2c', '#66983c', '#8ab456'), culmp)
            grain = H('#946a22', '#bc8e34', '#d8ae4e', '#ecc86c', '#f6de98', '#fff2cc')
            rach = H('#76683a', '#988a4c', '#b8aa64', '#d2c47e')
            sz *= 1.1
        hills = [np.array([-0.21, -0.06, 0.0]), np.array([0.21, -0.08, 0.0]), np.array([0.0, 0.16, 0.0])]
        for o in hills:
            ntil = int(r.integers(*{1: (5, 7), 2: (11, 14)}.get(stage, (15, 19))))
            a0 = r.uniform(0, 6.28)
            for k in range(ntil):
                a = a0 + k * 2.39996 + r.normal(0, 0.15)
                rb = 0.012 + 0.03 * math.sqrt(r.uniform())
                d = np.array([math.cos(a), math.sin(a), 0.0])
                lean = r.uniform(0.04, 0.14)
                Hc = r.uniform(0.62, 0.8) * sz
                base = d * rb + o
                top = base + d * lean * Hc + np.array([0, 0, Hc])
                mid = base + d * lean * Hc * 0.4 + np.array([0, 0, Hc * 0.5])
                cul = self.line_c([base, mid, top])
                self.tube(cul, 0.0045, 0.0028, culmp, 0.0, int(r.integers(1000)),
                          tint=lambda col, P, N, A, B: col * (0.55 + 0.45 * np.clip(P[..., 2] / (0.45 * sz), 0, 1))[..., None])
                # leaves: 2-3 per tiller from low on the culm, arching out and drooping
                for j in range(int(r.integers(2, 4))):
                    t0 = 0.12 + 0.22 * j + r.uniform(0, 0.08)
                    p0 = cul(np.array([t0]))[0]
                    az = a + r.normal(0, 0.7)
                    dl = np.array([math.cos(az), math.sin(az), 0.0])
                    L = r.uniform(0.36, 0.52) * (1.1 - 0.2 * j) * (0.3 + 0.7 * sz)
                    up = r.uniform(0.35, 0.6) + (0.25 if stage < 3 else 0.0)
                    p1 = p0 + dl * L * 0.35 + np.array([0, 0, L * up])
                    p2 = p0 + dl * L * 0.7 + np.array([0, 0, L * up * 1.05])
                    p3 = p0 + dl * L * 0.95 + np.array([0, 0, L * (up * 0.7 - 0.1)]); p3[2] = max(p3[2], 0.04)
                    self.strap(self.line_c([p0, p1, p2, p3]), r.uniform(0.026, 0.032) * (0.55 + 0.45 * sz), leafp, 0.0,
                               tipcol=dry if stage >= 3 else None, tipk=r.uniform(0.78, 0.93), fold=0.25, wprof=[0.3, 0.8, 1.0, 0.8, 0.4, 0.0],
                               zao=(0.5, 0.45 * sz))
                # the panicle: rachis rises out of the flag leaf, bows over, primary branches hang with grains
                if stage >= 3:
                    Lp = r.uniform(0.2, 0.26) * (1.12 if NEP else 1.0)
                    hd = nv(d + np.array([r.normal(0, 0.3), r.normal(0, 0.3), 0.0]))
                    q0 = top; q1 = top + hd * Lp * 0.25 + np.array([0, 0, Lp * 0.28])
                    q2 = top + hd * Lp * 0.6 + np.array([0, 0, Lp * 0.18]); q3 = top + hd * Lp * 0.75 + np.array([0, 0, -Lp * 0.45])
                    rc = self.line_c([q0, q1, q2, q3])
                    self.tube(rc, 0.0022, 0.0012, rach, 0.0, int(r.integers(1000)))
                    nb = int(r.integers(7, 10))
                    for b in range(nb):
                        tb = 0.2 + 0.78 * b / (nb - 1)
                        pb = rc(np.array([tb]))[0]
                        side = nv(np.cross(hd, UP)) * (1 if b % 2 else -1)
                        bl = Lp * (0.26 - 0.12 * tb)
                        bdir = nv(side * 0.18 + hd * 0.45 + np.array([0, 0, -0.85]))
                        ng = int(8 + 6 * (1 - tb))
                        for g in range(ng):
                            tg = (g + 0.6) / ng
                            pg = pb + bdir * bl * tg + side * 0.005 * (1 if g % 2 else -1) + hd * 0.003 * math.cos(g * 1.7)
                            gax = nv(bdir + side * 0.35 * (1 if g % 2 else -1) + np.array([r.normal(0, 0.1), r.normal(0, 0.1), r.normal(0, 0.08)]))
                            self.ellip(pg, gax, 0.0115, 0.0052, grain, 0.004, spec=0.18, edge_k=0.84,
                                       tint=self._hull)
        self.shadows.append((0.0, 0.02, 0.44, 0.34, 0.16))

    # ------------------------------------------------------------------ bắp
    def _bap(self, seed):
        """corn, 3 plants in a row across the plot. Each: one thick straight stalk with nodes, broad leaves standing out
        from the nodes like a ladder (alternate left/right, only the tips bend), the tassel the highest point; stage 3
        one big ear hugging the stalk in a green husk, open at the tip with yellow kernels + a silk tuft"""
        r = self.r
        stage = seed % 4
        leafp = H('#285a18', '#38721f', '#4c8c2a', '#64a436', '#80bc48', '#a8d26c')
        stalkp = H('#3a6420', '#4e7e2a', '#669836', '#80b046', '#a2c866')
        huskp = H('#3a6a20', '#4e8428', '#66a034', '#80b644', '#9cc85c', '#bcda84')
        kern = H('#9a6a08', '#c48a10', '#e2a81a', '#f4c432', '#fcdc66', '#fff0a8')
        tass = H('#7a6a2c', '#9e8a3c', '#c0aa54', '#dac670', '#f0e09a')
        silk = H('#6a3c14', '#8a521c', '#aa6c26', '#c88a3a', '#e0aa5a')
        dry = (A_(C('#8a8a2e')), A_(C('#c4c070')))
        Hs = {1: 0.28, 2: 0.72}.get(stage, 1.06)          # stalk height to the tassel base (m)
        plants = [np.array([-0.26, -0.08, 0.0]), np.array([0.0, 0.17, 0.0]), np.array([0.26, -0.1, 0.0])]     # middle one staggered to the front
        for pi, o in enumerate(plants):
            Hc = Hs * r.uniform(0.94, 1.05)
            top = o + np.array([r.normal(0, 0.006), r.normal(0, 0.006), Hc])
            cul = self.line_c([o, (o + top) * 0.5, top])
            if stage > 1:
                r0 = 0.028 if stage == 2 else 0.042
                self.tube(cul, r0, r0 * 0.6, stalkp, 0.0, int(r.integers(1000)), node=Hc / (5 if stage == 2 else 7),
                          node_col=A_(C('#4a6a24')),
                          tint=lambda col, P, N, A, B, Hc=Hc: col * (0.7 + 0.3 * np.clip(P[..., 2] / (0.4 * Hc), 0, 1))[..., None])
            if stage == 3:
                for k in range(6):      # prop roots
                    a = k * 1.047 + r.uniform(0, 0.4); d = np.array([math.cos(a), math.sin(a), 0.0])
                    pr = self.line_c([o + np.array([0, 0, 0.06]), o + d * 0.022 + np.array([0, 0, 0.025]), o + d * 0.04])
                    self.tube(pr, 0.004, 0.003, stalkp, 0.0, int(r.integers(1000)))
            # leaves: alternate left / right (across the view) with a little turn toward or away from the camera
            nl = {1: 4, 2: 6}.get(stage, 9)
            side0 = 1 if (pi + seed) % 2 else -1
            for j in range(nl):
                if stage == 1:
                    t0 = 0.1 + 0.1 * j
                    p0 = o + np.array([0, 0, Hc * t0])
                else:
                    t0 = 0.1 + 0.75 * j / (nl - 1)
                    p0 = cul(np.array([t0]))[0]
                sd_ = side0 * (1 if j % 2 else -1)
                az = (0.0 if sd_ > 0 else math.pi) + sd_ * r.uniform(-0.55, 0.55)
                dl = np.array([math.cos(az), math.sin(az), 0.0])
                if stage == 1:
                    Lf = r.uniform(0.27, 0.35); up = r.uniform(1.5, 2.0)
                else:
                    Lf = (0.44 if stage == 2 else 0.56) * (1.0 - 0.45 * max(0, t0 - 0.5)) * r.uniform(0.92, 1.06)
                    up = 0.95 + 0.5 * t0 + r.uniform(-0.1, 0.1)      # upper leaves more upright
                p1 = p0 + dl * Lf * 0.22 + np.array([0, 0, Lf * up * 0.42])
                p2 = p0 + dl * Lf * 0.52 + np.array([0, 0, Lf * up * 0.6])
                p3 = p0 + dl * Lf * 0.86 + np.array([0, 0, Lf * (up * 0.5 - 0.2)])
                if stage == 3:      # nothing above the tassel
                    zmax = top[2] + 0.07
                    for q in (p1, p2, p3): q[2] = min(q[2], zmax - 0.04 * (q is p3))
                Wl = (0.08 if stage == 3 else 0.066 if stage == 2 else 0.042) * r.uniform(0.92, 1.08)
                self.strap(self.line_c([p0, p1, p2, p3]), Wl, leafp, 0.0, fold=0.2, vein_n=9,
                           wprof=[0.55, 0.9, 1.0, 0.85, 0.45, 0.0], gloss=0.22,
                           tipcol=dry if stage == 3 else None, tipk=r.uniform(0.9, 0.97),
                           zao=(0.6, 0.5 * Hc))
            if stage == 2:      # two young ears just showing
                ae = math.pi * 0.5 + (0.6 if pi % 2 == 0 else -0.6)
                self._ear(cul, 0.5, ae + r.normal(0, 0.1), 0.56, True, huskp, kern, silk)
                self._ear(cul, 0.64, math.pi - ae + r.normal(0, 0.1), 0.48, True, huskp, kern, silk)
            if stage < 3: continue
            # tassel: central spike + 9-11 branches arching out and down, the highest point of the plant
            spike = self.line_c([top, top + np.array([0.003, 0, 0.1]), top + np.array([0.008, 0.003, 0.2])])
            self.tube(spike, 0.0045, 0.0022, tass, 0.0, int(r.integers(1000)))
            nb = int(r.integers(9, 12))
            for b in range(nb):
                tb = 0.12 + 0.4 * b / nb
                pb = spike(np.array([tb]))[0]
                a = b * 2.39996 + r.uniform(0, 0.3); d = np.array([math.cos(a), math.sin(a), 0.0])
                Lb = r.uniform(0.12, 0.16)
                br = self.line_c([pb, pb + d * Lb * 0.4 + np.array([0, 0, Lb * 0.3]), pb + d * Lb * 0.85 + np.array([0, 0, -Lb * 0.05])])
                self.tube(br, 0.0026, 0.0015, tass, 0.0, int(r.integers(1000)))
                for g in range(8):
                    tg = 0.25 + 0.75 * g / 7; pg = br(np.array([tg]))[0] + np.array([0, 0, -0.004])
                    self.ellip(pg, nv(d + np.array([0, 0, -0.6])), 0.008, 0.0036, tass, 0.003, spec=0.1, edge_k=0.86)
            # two ears per plant at about half height, close to the stalk, one each side, both turned toward the camera
            ae = math.pi * 0.5 + (0.6 if pi % 2 == 0 else -0.6)
            self._ear(cul, 0.4, ae + r.normal(0, 0.1), 1.0, False, huskp, kern, silk)
            self._ear(cul, 0.55, math.pi - ae + r.normal(0, 0.1), 0.88, False, huskp, kern, silk)

    def _ear(self, cul, te, a, sc, young, huskp, kern, silk):
        """one ear on the stalk curve cul at te, facing azimuth a, size sc; young = closed husk, only a silk tuft"""
        r = self.r
        pe = cul(np.array([te]))[0]
        d = np.array([math.cos(a), math.sin(a), 0.0])
        ax = nv(d * (0.55 if young else 0.62) + np.array([0, 0, 1.0]))
        La = 0.36 * sc * r.uniform(0.95, 1.04); ba_ = 0.068 * (sc ** 0.8)
        base = pe + d * 0.03 * sc ** 0.5
        cen = base + ax * La * 0.5
        def kt(col, P, N, A, B):
            # big readable kernels: 12 rows round the cob, 13 along, each a rounded bump with a lit upper side
            # and a dark seam between kernels
            rb = B * 12.0; ri = np.floor(rb); fb = rb - ri
            ka = A * 13.0 + 0.5 * (ri % 2); fa = ka % 1.0
            u_ = (fb - 0.5) / 0.5; v_ = (fa - 0.5) / 0.5
            d2 = np.sqrt(np.abs(u_) ** 4 * 1.2 + np.abs(v_) ** 4)      # squarish kernels packed tight
            seam = np.clip((d2 - 0.72) / 0.22, 0, 1)
            hl = np.clip(1 - ((u_ + 0.25) ** 2 + (v_ - 0.3) ** 2) * 2.2, 0, 1)
            tipfade = np.clip((A - 0.04) / 0.08, 0, 1) * np.clip((0.97 - A) / 0.06, 0, 1)
            out = col * (1 - np.array([0.22, 0.3, 0.45]) * (seam * tipfade)[..., None]) + (0.14 * hl * tipfade)[..., None] * np.array([1.0, 0.95, 0.7])
            return out
        hv = lambda col, P, N, A, B: col * (1 - 0.07 * np.clip((np.abs(np.cos(B * 2 * math.pi * 9)) - 0.6) / 0.4, 0, 1))[..., None]
        if young:
            # a slim closed husk, tapering to a point
            self.ellip(cen, ax, La * 0.5, ba_ * 1.0, huskp, 0.002, spec=0.12, tint=hv, edge_k=0.82, bulge=0.35)
        else:
            self.ellip(cen, ax, La * 0.5, ba_ * 0.92, kern, 0.0, spec=0.3, tint=kt, edge_k=0.82, bulge=-0.18)
            self.ellip(base + ax * La * 0.2, ax, La * 0.24, ba_ * 1.12, huskp, 0.002, spec=0.12, tint=hv, edge_k=0.82, bulge=0.1)
            u, v = basis(ax)
            for h in range(5):
                th = h * math.pi * 0.4 + r.uniform(-0.25, 0.25)
                rd = math.cos(th) * u + math.sin(th) * v
                q0 = base + ax * La * 0.2 + rd * ba_ * 1.12
                q1 = base + ax * La * 0.36 + rd * ba_ * 1.15
                q2 = base + ax * La * 0.46 + rd * ba_ * 1.5
                q3 = base + ax * La * (0.5 + 0.06 * (h % 2)) + rd * ba_ * (2.3 + r.uniform(0, 0.5))
                self.strap(self.line_c([q0, q1, q2, q3]), ba_ * 1.6, huskp, 0.003, fold=0.4, vein_n=7,
                           wprof=[1.0, 1.0, 1.0, 0.85, 0.5, 0.0], gloss=0.12)
        self.tube(self.line_c([pe, pe + d * 0.016 * sc + ax * 0.008 * sc, base + ax * 0.01 * sc]), 0.011 * sc ** 0.7, 0.012 * sc ** 0.7,
                  huskp, 0.0, int(r.integers(1000)))
        tip = cen + ax * La * 0.5
        for s_ in range(12 if not young else 8):
            sa = s_ * 0.52 + r.uniform(0, 0.3); sd2 = np.array([math.cos(sa), math.sin(sa), 0.0])
            ls = r.uniform(0.035, 0.055) * (0.6 if young else 1.0)
            sl = self.line_c([tip - ax * 0.004, tip + ax * ls * 0.4 + sd2 * ls * 0.25, tip + ax * ls * 0.45 + sd2 * ls * 0.7 + np.array([0, 0, -ls * 0.35])])
            self.tube(sl, 0.0018 * (0.8 if young else 1), 0.0011, silk if not young else H('#9a8a3a', '#b8a44a', '#d4c060', '#e8d88a'), 0.0, int(r.integers(1000)))

    # ------------------------------------------------------------------ nếp (lúa nếp: same plant as lúa, own palettes)
    def _nep(self, seed):
        self._lua(seed)

    # ------------------------------------------------------------------ shared bits for the vegetable crops
    def _stake(self, o, Hk):
        """a dried bamboo cane (cọc tre) pushed into the bed, with nodes"""
        stakep = H('#5e4e30', '#7a6844', '#978258', '#b29c70', '#ccb88e', '#e2d2ac')
        top = o + np.array([0.004, -0.003, Hk])
        cf = self.line_c([o, (o + top) * 0.5, top])
        self.tube(cf, 0.0125, 0.0105, stakep, 0.0, int(self.r.integers(1000)), node=0.24, node_col=A_(C('#6a5634')))
        return cf

    def _tie(self, c, R, z):
        """a straw tie round stake + stem at height z"""
        pts = [c + np.array([R * math.cos(a), R * 0.8 * math.sin(a), z + 0.004 * math.sin(2 * a)]) for a in np.linspace(0, 2 * math.pi, 13)]
        self.tube(self.line_c(pts), 0.0032, 0.0032, H('#7a6a3a', '#a08c50', '#c4ae6a', '#dccb8c'), 0.004, int(self.r.integers(1000)))

    def _cleaf(self, p0, az, L, leafp, und, nk=3, up=0.3, sc=1.0, tint=None, rach=None):
        """a tomato compound leaf: a rachis arching out from the stem, nk pairs of toothy ovate leaflets + one at the tip"""
        r = self.r
        dl = np.array([math.cos(az), math.sin(az), 0.0])
        q1 = p0 + dl * L * 0.3 + np.array([0, 0, L * up]); q2 = p0 + dl * L * 0.68 + np.array([0, 0, L * up * 0.75])
        q3 = p0 + dl * L + np.array([0, 0, L * (up * 0.25 - 0.12)])
        rc = self.line_c([p0, q1, q2, q3])
        self.tube(rc, 0.0042 * sc, 0.0022 * sc, rach or und, 0.0, int(r.integers(1000)))
        side = nv(np.cross(UP, dl))
        lf = [(0.3 + 0.62 * k / max(nk - 1, 1), s_) for k in range(nk) for s_ in (-1, 1)] + [(1.0, 0)]
        for (t, s_) in lf:
            b = rc(np.array([t]))[0]
            tg = nv(rc(np.array([min(t + 0.02, 1.0)]))[0] - rc(np.array([max(t - 0.02, 0.0)]))[0])
            if s_ == 0:
                e = nv(tg + np.array([0, 0, -0.15])); Ll = L * 0.36
            else:
                e = nv(side * s_ * 0.9 + tg * 0.55 + np.array([0, 0, -0.1 + r.normal(0, 0.12)])); Ll = L * (0.3 + 0.12 * t) * r.uniform(0.9, 1.1)
            f = nv(np.array([0, 0, 1.0]) + side * s_ * 0.25 + np.array([0, 0.25, 0]))
            self.leaf(b, e, f, Ll, Ll * 0.6, leafp, und, droop=r.uniform(0.18, 0.32), fold=0.16, veins=5, gloss=0.12,
                      prof=[0.0, 0.5, 0.88, 1.0, 0.82, 0.46, 0.0], mid_k=0.35, tint=tint, teeth=(7, 0.3, 'saw'))

    # ------------------------------------------------------------------ cà chua
    def _cachua(self, seed):
        """tomatoes: 3 plants each tied to a bamboo cane; compound leaves, yellow star flowers (stage 2),
        trusses of round ribbed fruit, ripe red with a few orange and green ones (stage 3)"""
        r = self.r
        stage = seed % 4
        leafp = H('#173e14', '#20541a', '#2c6a22', '#3c822c', '#549a3a', '#78b458')
        und = H('#34602a', '#447436', '#568a44', '#6ea056', '#90ba78')
        stemp = H('#3a6020', '#4c782a', '#62903a', '#7aa84a', '#9cc26a')
        red = H('#760a06', '#ac140c', '#da1e12', '#f2361e', '#ff5a3c', '#ffa088')
        ora = H('#6e3008', '#9c4a10', '#c66a1a', '#e28a28', '#f2aa48', '#ffd08a')
        grn = H('#2a5418', '#3e7022', '#588c2e', '#74a63e', '#96c25a', '#c0dc8a')
        calp = H('#1e4614', '#2c5e1c', '#3e7826', '#549232', '#72aa48')
        fl = dict(base=A_(C('#e8b010')), mid=A_(C('#fcd420')), tip=A_(C('#ffe866')), deep=A_(C('#8a6a08')), vein=A_(C('#c89a10')))
        plants = [np.array([-0.25, -0.07, 0.0]), np.array([0.0, 0.15, 0.0]), np.array([0.25, -0.09, 0.0])]
        def fruit(c, pal, R):
            ax = nv(np.array([r.normal(0, 0.15), r.normal(0, 0.15), 1.0]))
            def rib(col, P, N, A, B):
                lob = np.abs(np.cos(B * math.pi * 5))           # 5 shallow lobes, deepest round the top and bottom
                k = np.clip(1 - np.sin(A * math.pi) * 1.2, 0, 1)
                return col * (1 - 0.16 * k * np.clip((0.35 - lob) / 0.35, 0, 1))[..., None]
            self.ellip(c, ax, R * 0.84, R, pal, 0.0, spec=0.42, tint=rib, edge_k=0.8)
            tp = c + ax * R * 0.8
            for k in range(5):      # the green star of sepals on top + its little stalk
                a = k * 1.2566 + r.uniform(-0.2, 0.2); d = np.array([math.cos(a), math.sin(a), 0.0])
                self.strap(self.line_c([tp, tp + d * R * 0.35 + ax * R * 0.08, tp + d * R * 0.62 - ax * R * 0.05]), R * 0.2, calp, 0.002,
                           fold=0.3, wprof=[0.8, 1.0, 0.9, 0.6, 0.3, 0.0], gloss=0.1)
            return tp
        def flower(p, d):
            f = nv(d * 0.7 + np.array([0, 0.3, -0.55]))      # nodding, turned toward the camera
            u, v = basis(f)
            for k in range(5):
                a = k * 1.2566; e = nv((math.cos(a) * u + math.sin(a) * v) * 0.8 - f * 0.45)
                self.petal(p, -f, e, 0.034, 0.013, -0.25, fl, 0.003, prof=[0.5, 0.85, 1.0, 0.85, 0.55, 0.25, 0.0], nveins=3)
            self.ellip(p + f * 0.011, f, 0.012, 0.006, H('#9a7a0a', '#c89c14', '#e8c02a', '#f8dc5a'), 0.006, spec=0.1)
        if stage == 1:
            for o in plants:
                Hc = r.uniform(0.11, 0.14)
                top = o + np.array([r.normal(0, 0.01), r.normal(0, 0.01), Hc])
                cf = self.line_c([o, o + np.array([0, 0, Hc * 0.5]), top])
                self.tube(cf, 0.0065, 0.0045, stemp, 0.0, int(r.integers(1000)))
                for s_ in (-1, 1):      # cotyledons
                    a = r.uniform(-0.3, 0.3) + (0 if s_ > 0 else math.pi)
                    d = np.array([math.cos(a), math.sin(a), 0.0]); p0 = o + np.array([0, 0, Hc * 0.62])
                    self.strap(self.line_c([p0, p0 + d * 0.03 + np.array([0, 0, 0.02]), p0 + d * 0.065 + np.array([0, 0, 0.005])]), 0.016, leafp, 0.0, fold=0.2, vein_n=1)
                a0 = r.uniform(0, 6.28)
                for j in range(3):
                    self._cleaf(top - np.array([0, 0, 0.01 * j]), a0 + j * 2.2, r.uniform(0.11, 0.14), leafp, und, nk=2, up=0.55, sc=0.7)
            return
        Hs = 0.56 if stage == 2 else 0.74
        for pi, o in enumerate(plants):
            Hc = Hs * r.uniform(0.94, 1.05)
            so = o + np.array([0.012, -0.035, 0.0])
            self._stake(so, Hc * 1.22)
            pts = [o, o + np.array([0.008, 0.006, Hc * 0.3]), o + np.array([-0.004, -0.008, Hc * 0.62]), o + np.array([0.006, -0.012, Hc])]
            cul = self.line_c(pts)
            self.tube(cul, 0.021, 0.01, stemp, 0.0, int(r.integers(1000)),
                      tint=lambda col, P, N, A, B, Hc=Hc: col * (0.72 + 0.28 * np.clip(P[..., 2] / (0.4 * Hc), 0, 1))[..., None])
            for z in (0.3, 0.62, 0.9):
                self._tie((cul(np.array([z]))[0] + so + np.array([0, 0, Hc * 1.22 * z])) * 0.5 * np.array([1, 1, 0]) + np.array([0, 0, 0]), 0.026, Hc * z)
            nl = 11 if stage == 2 else 15
            a0 = r.uniform(0, 6.28)
            for j in range(nl):
                t0 = 0.12 + 0.86 * j / (nl - 1)
                p0 = cul(np.array([t0]))[0]
                az = a0 + j * 2.39996
                if math.sin(az) < -0.75: az += 1.2          # not straight back (hidden by the stem anyway)
                L = (0.3 if stage == 3 else 0.26) * (1.05 - 0.4 * t0) * r.uniform(0.9, 1.1)
                self._cleaf(p0, az, L, leafp, und, nk=3, up=0.35 + 0.3 * t0, rach=stemp)
            if stage == 2:
                for k, t in enumerate((0.45, 0.72)):
                    a = math.pi * 0.5 + (0.8 if (k + pi) % 2 else -0.8); d = np.array([math.cos(a), math.sin(a), 0.0])
                    p0 = cul(np.array([t]))[0]; pe = p0 + d * 0.06 + np.array([0, 0, 0.01])
                    self.tube(self.line_c([p0, p0 + d * 0.03 + np.array([0, 0, 0.015]), pe]), 0.003, 0.0022, stemp, 0.0, int(r.integers(1000)))
                    for m in range(3):
                        dm = nv(d + np.array([r.normal(0, 0.5), r.normal(0, 0.5), 0.0]))
                        pf = pe + dm * 0.026 + np.array([0, 0, -0.012 * m])
                        self.tube(self.line_c([pe, (pe + pf) * 0.5 + np.array([0, 0, 0.006]), pf]), 0.0018, 0.0016, stemp, 0.0, int(r.integers(1000)))
                        if m == 2 and k == 0: fruit(pf - np.array([0, 0, 0.03]), grn, 0.03)
                        else: flower(pf, dm)
                continue
            # stage 3: three trusses, the lowest ripest
            for k, (t, cols) in enumerate(((0.52, [red, red, red, red]), (0.68, [red, ora, red, red]), (0.84, [red, ora, red]))):
                a = math.pi * 0.5 + (0.55 if (k + pi) % 2 else -0.55) + r.normal(0, 0.12); d = np.array([math.cos(a), math.sin(a), 0.0])
                p0 = cul(np.array([t]))[0]; pe = p0 + d * 0.1 + np.array([0, 0, -0.005])
                self.tube(self.line_c([p0, p0 + d * 0.04 + np.array([0, 0, 0.02]), pe]), 0.0065, 0.0045, stemp, 0.0, int(r.integers(1000)))
                n = len(cols)
                for m, pal in enumerate(cols):
                    R = 0.062 * r.uniform(0.92, 1.05) * (0.85 if pal is grn else 1.0)
                    side = nv(np.cross(UP, d))
                    off = d * (0.012 + 0.03 * (m // 2)) + side * (R * 1.05 * (1 if m % 2 else -1) if n > 1 else 0)
                    c = pe + off + np.array([0, 0, -R - 0.022 - 0.008 * (m // 2)])
                    tp = fruit(c, pal, R)
                    self.tube(self.line_c([pe, (pe + tp) * 0.5 + np.array([0, 0, 0.012]), tp]), 0.0022, 0.002, stemp, 0.0, int(r.integers(1000)))

    # ------------------------------------------------------------------ cà tím
    def _catim(self, seed):
        """eggplant (cà tím dài): purple-stemmed bushes with broad grey-green leaves, purple midribs, lilac star
        flowers (stage 2), long glossy deep-purple fruit hanging under a spiky green cap (stage 3)"""
        r = self.r
        stage = seed % 4
        leafp = H('#163a16', '#1f4e1e', '#2b6327', '#3b7a30', '#509040', '#74a85e')
        und = H('#34502e', '#44623a', '#567648', '#6a8a58', '#88a474')
        stemp = H('#2a1832', '#3e2446', '#56345a', '#6e4870', '#8a6288')
        frp = H('#12061c', '#24102e', '#3a1a48', '#542a66', '#704286', '#9a6aae')
        calp = H('#24401a', '#345424', '#4a6a2e', '#62803c', '#80984e')
        fl = dict(base=A_(C('#7a4aa0')), mid=A_(C('#a882c8')), tip=A_(C('#cdb4e2')), deep=A_(C('#4a2a66')), vein=A_(C('#6a3c8e')))
        def pv(col, P, N, A, B):      # purple midrib
            w = B * 2 - 1
            return mix(col, A_(C('#5a3a5e')), np.exp(-(w / 0.045) ** 2) * 0.55 * (A < 0.9))
        def leaf(p0, az, L, up=0.35):
            d = np.array([math.cos(az), math.sin(az), 0.0])
            b = p0 + d * L * 0.16 + np.array([0, 0, L * 0.06])
            self.tube(self.line_c([p0, p0 + d * L * 0.08 + np.array([0, 0, L * 0.06]), b]), 0.004, 0.0032, stemp, 0.0, int(r.integers(1000)))
            e = nv(d + np.array([0, 0, up - 0.2 + r.normal(0, 0.1)]))
            f = nv(np.array([0, 0.3, 1.0]) - d * 0.25)
            self.leaf(b, e, f, L, L * r.uniform(0.6, 0.7), leafp, und, droop=r.uniform(0.2, 0.34), fold=0.1, veins=6, gloss=0.1,
                      prof=[0.0, 0.62, 0.94, 1.0, 0.86, 0.5, 0.0], mid_k=0.2, tint=pv, teeth=(3.5, 0.12, 'wave'))
        def flower(p, d):
            f = nv(d * 0.3 + np.array([0, 0.8, -0.35]))
            u, v = basis(f)
            for k in range(6):
                a = k * 1.0472; e = nv((math.cos(a) * u + math.sin(a) * v) * 0.9 - f * 0.25)
                self.petal(p, -f, e, 0.038, 0.024, -0.12, fl, 0.003, prof=[0.7, 0.95, 1.0, 0.9, 0.6, 0.3, 0.0], nveins=3)
            self.ellip(p + f * 0.013, f, 0.015, 0.007, H('#9a7a0a', '#c89c14', '#e8c02a', '#f8dc5a'), 0.006, spec=0.1)
            for k in range(5):      # the hairy purple-green calyx behind
                a = k * 1.2566; e = nv((math.cos(a) * u + math.sin(a) * v) * 0.6 - f * 0.8)
                self.strap(self.line_c([p - f * 0.004, p - f * 0.012 + e * 0.008, p + e * 0.016 - f * 0.014]), 0.007, calp, 0.0, fold=0.3)
        def fruit(p, d, L, R):
            """long fruit hanging from p: a stalk, the cap, then the curved glossy body"""
            ax0 = nv(d * 0.35 + np.array([0, 0.2, -1.0]))
            c0 = p + ax0 * 0.03
            self.tube(self.line_c([p, p + d * 0.012 + ax0 * 0.012, c0]), 0.005, 0.0055, calp, 0.0, int(r.integers(1000)))
            bend = nv(d + np.array([0, 0.3, 0])) * L * 0.18
            body = self.line_c([c0, c0 + ax0 * L * 0.35 + bend * 0.3, c0 + ax0 * L * 0.7 + bend * 0.8, c0 + ax0 * L + bend * 1.1])
            def rf(t):
                g = np.clip(t / 0.5, 0, 1); g = g * g * (3 - 2 * g)
                return R * (0.5 + 0.5 * g) * np.sqrt(np.clip((1 - t) / 0.14, 0, 1)) + 1e-4
            def gl(col, P, N, A, B):
                col = mix(col, A_(C('#7a6a8e')), np.clip((0.12 - A) / 0.08, 0, 1) * 0.5)       # paler under the cap
                h = np.clip(N @ HALF, 0, 1)
                return np.clip(col + ((h ** 20) * 0.05 + (h ** 6) * 0.03)[..., None] * np.array([0.92, 0.9, 1.0]), 0, 1)     # Link 16:24: matte, no shiny highlight
            self.tube(body, R, R, frp, 0.0, int(r.integers(1000)), tint=gl, rfun=rf)
            tg = nv(body(np.array([0.02]))[0] - c0 + ax0 * 1e-3)
            u, v = basis(tg)
            self.ellip(c0 + tg * 0.012, tg, 0.024, R * 0.72, calp, 0.002, spec=0.08, bulge=0.3)
            for k in range(5):      # spiky sepals clasping the fruit
                a = k * 1.2566 + r.uniform(-0.2, 0.2); rd = math.cos(a) * u + math.sin(a) * v
                q0 = c0 + rd * R * 0.6; q1 = c0 + tg * 0.03 + rd * R * 0.75; q2 = c0 + tg * 0.07 + rd * R * 0.72
                self.strap(self.line_c([q0, q1, q2]), R * 0.55, calp, 0.002, fold=0.35, wprof=[1.0, 1.0, 0.85, 0.55, 0.25, 0.0], gloss=0.08)
        plants = [np.array([-0.25, -0.07, 0.0]), np.array([0.0, 0.15, 0.0]), np.array([0.25, -0.09, 0.0])]
        if stage == 1:
            for o in plants:
                Hc = r.uniform(0.1, 0.13)
                top = o + np.array([r.normal(0, 0.008), r.normal(0, 0.008), Hc])
                self.tube(self.line_c([o, o + np.array([0, 0, Hc * 0.5]), top]), 0.0065, 0.005, stemp, 0.0, int(r.integers(1000)))
                a0 = r.uniform(0, 6.28)
                for j in range(4):
                    leaf(top - np.array([0, 0, 0.012 * j]), a0 + j * 2.4, r.uniform(0.075, 0.095) * (1.1 - 0.1 * j), up=0.6)
            return
        Hs = 0.48 if stage == 2 else 0.62
        for pi, o in enumerate(plants):
            Hc = Hs * r.uniform(0.94, 1.05)
            top = o + np.array([r.normal(0, 0.01), r.normal(0, 0.01), Hc * 0.55])
            cul = self.line_c([o, o + np.array([0, 0, Hc * 0.3]), top])
            self.tube(cul, 0.019, 0.014, stemp, 0.0, int(r.integers(1000)))
            brs = []
            for k in range(3):       # the bush forks into 3 branches
                a = k * 2.094 + r.uniform(0, 0.6) + pi; d = np.array([math.cos(a), math.sin(a) * 0.8, 0.0])
                b0 = top; b1 = top + d * 0.08 + np.array([0, 0, Hc * 0.22]); b2 = top + d * 0.13 + np.array([0, 0, Hc * 0.45])
                bc = self.line_c([b0, b1, b2]); brs.append((bc, d))
                self.tube(bc, 0.013, 0.008, stemp, 0.0, int(r.integers(1000)))
            a0 = r.uniform(0, 6.28)
            for j in range(5):       # big low leaves on the main stem
                t0 = 0.3 + 0.17 * j
                leaf(cul(np.array([t0]))[0], a0 + j * 2.4, (0.22 if stage == 3 else 0.18) * r.uniform(0.9, 1.08), up=0.2)
            for bi, (bc, d) in enumerate(brs):
                for j in range(5):
                    t0 = 0.2 + 0.2 * j
                    az = math.atan2(d[1], d[0]) + (1 if j % 2 else -1) * r.uniform(0.6, 1.2)
                    leaf(bc(np.array([t0]))[0], az, (0.18 if stage == 3 else 0.15) * (1.05 - 0.25 * t0) * r.uniform(0.9, 1.08), up=0.3 + 0.3 * t0)
            # fruit / flowers on the branches turned toward the camera
            front = sorted(brs, key=lambda x: -x[1][1])
            if stage == 2:
                for bi, (bc, d) in enumerate(front[:2]):
                    p = bc(np.array([0.5]))[0]
                    pf = p + d * 0.03 + np.array([0, 0.06, -0.01])
                    self.tube(self.line_c([p, (p + pf) * 0.5 + np.array([0, 0, 0.004]), pf]), 0.0026, 0.0022, stemp, 0.0, int(r.integers(1000)))
                    flower(pf, d)
                    if bi == 0: fruit(bc(np.array([0.2]))[0], d, 0.1, 0.022)
                continue
            for bi, (bc, d) in enumerate(front[:2]):
                fruit(bc(np.array([0.3 + 0.12 * bi]))[0], d, 0.3 * r.uniform(0.94, 1.05), 0.045)
            bc, d = front[2]
            p = bc(np.array([0.6]))[0]; pf = p + d * 0.02 + np.array([0, 0.02, -0.012])
            flower(pf, d)

    # ------------------------------------------------------------------ shared bits for the vine crops (bí, dưa)
    def pleaf(self, b, d, f, R, pal, und, lobes=5, depth=0.25, sub=0.0, cup=-0.1, ruffle=0.03, key=0.0, gloss=0.05,
              tint=None, spread=0.86, teeth=(40, 0.03), pale=0.0, vk=0.3):
        """a palmate leaf as ONE surface in polar form round the petiole end b (no overlapping lobe pieces):
        lobes along the outline, a notch where the petiole joins, main veins out to each lobe tip, net veins between"""
        sd = int(self.r.integers(1000)); r = self.r
        f = nv(f); d = nv(d - f * (d @ f)); s = nv(np.cross(f, d))
        nh = (lobes - 1) / 2; sp = spread / max(nh, 1)
        ph0 = r.uniform(0, 6.28)
        def rr(u):
            lo = 0.5 + 0.5 * np.cos(2 * math.pi * u / sp)
            env = 0.6 + 0.4 * np.cos(np.clip(u, -1, 1) * math.pi * 0.5) ** 0.6
            q = env * (1 - depth * (1 - lo) ** 1.4)
            if sub:       # the side lobes cut again (dưa hấu)
                q = q * (1 - sub * (0.5 - 0.5 * np.cos(2 * math.pi * u / (sp / 3))) * np.clip(1.2 - lo, 0, 1))
            if teeth[1]: q = q * (1 - teeth[1] * ((u * teeth[0]) % 1.0))
            q = q * (1 - 0.8 * np.exp(-((1 - np.abs(u)) / 0.07) ** 2))       # the notch at the petiole
            return q
        def geo(A, B):
            u = B * 2 - 1; th = u * math.pi; rad = A * R * rr(u)
            pl = (np.cos(th)[..., None] * d + np.sin(th)[..., None] * s) * rad[..., None]
            hz = cup * rad * rad / R + ruffle * R * np.sin(th * 7 + ph0) * A * A
            return b + pl + f * hz[..., None]
        def sh(P, N, F, A, B):
            u = B * 2 - 1; lam = self.lam(N)
            sv = (0.12 + 0.85 * lam) * self.grain(P, R * 0.12, sd, 0.04)
            col = ramp(pal, np.clip(sv, 0, 1))
            col = np.where(F[..., None], col, ramp(und, np.clip(0.2 + 0.7 * lam, 0, 1)))
            du = ((u / sp + 0.5) % 1.0 - 0.5) * sp
            rq = rr(u); lat = np.abs(du) * math.pi * A * R * rq
            main = np.exp(-(lat / (R * 0.022 * (1.2 - A))) ** 2) * (A > 0.02) * (A < 0.95) * (np.abs(u) < spread + sp * 0.4)
            col = mix(col, und[-1], main * vk)
            net = np.abs(np.cos((A * rq * 7.0 - lat / R * 6.0) * math.pi))
            col = mix(col, und[-1], np.clip((net - 0.88) / 0.12, 0, 1) * 0.12 * (lat > R * 0.02) * (A < 0.93))
            if pale:      # silvery patches along the main veins (bí đỏ)
                n_ = vnoise(P[..., 0] / (R * 0.12), P[..., 1] / (R * 0.12), sd)
                pk = np.clip((n_ - 0.4) / 0.4, 0, 1) * np.exp(-(lat / (R * 0.12)) ** 2) * (A > 0.12) * (A < 0.8)
                col = mix(col, A_(C('#b4d29a')), pk * pale * F)
            if tint is not None: col = tint(col, P, N, A, B)
            spec = (np.clip(N @ HALF, 0, 1) ** 20 * gloss) * F
            return np.clip(col + spec[..., None], 0, 1)
        self.splat(geo, sh, b + TOCAM * key, edge_k=0.8)

    def wleaf(self, b, d, f, L, pal, und, key=0.0):
        """a watermelon leaf: three narrow, deeply wavy-cut lobes (the middle one longest) and two small basal ones"""
        r = self.r; f = nv(f); d = nv(d - f * (d @ f)); s = nv(np.cross(f, d))
        for (a, k, w) in ((0.0, 1.0, 0.46), (0.8, 0.8, 0.44), (-0.8, 0.8, 0.44), (1.65, 0.48, 0.5), (-1.65, 0.48, 0.5)):
            e = nv(d * math.cos(a) + s * math.sin(a) + f * (-0.08 * abs(a)))
            Ll = L * k * r.uniform(0.92, 1.06)
            self.leaf(b + e * L * 0.03 + f * 0.002 * (2 - abs(a)), e, f, Ll, Ll * w, pal, und, key=key, droop=r.uniform(0.08, 0.18), fold=0.1,
                      veins=4, gloss=0.08, prof=[0.0, 0.42, 0.85, 1.0, 0.85, 0.5, 0.0], mid_k=0.35, teeth=(2.6, 0.58, 'wave'))

    def _tendril(self, p, d, L=0.06, turns=2.5, pal=None):
        """a curly tendril: a short straight run, then a tightening spiral"""
        d = nv(d); u, v = basis(d); pts = [p, p + d * L * 0.3 + np.array([0, 0, 0.01])]
        c0 = pts[-1]
        for k in range(1, 22):
            t = k / 21; a = t * turns * 2 * math.pi; rad = 0.012 * (1 - 0.6 * t)
            pts.append(c0 + d * L * 0.7 * t + (math.cos(a) * u + math.sin(a) * v) * rad - u * 0.012)
        self.tube(self.line_c(pts), 0.0022, 0.0013, pal, 0.0, int(self.r.integers(1000)))

    def _vinef(self, p, fa, L, fl, n=5, cup=0.3, W=0.6):
        """a yellow trumpet flower opening toward fa: a green tube base, flaring pointed petals, a bright centre"""
        fa = nv(fa); u, v = basis(fa)
        self.ellip(p + fa * L * 0.12, fa, L * 0.18, L * 0.12, H('#3a6a1e', '#4e8428', '#66a034', '#82b844'), 0.0, spec=0.1)
        for k in range(n):
            a = k * 2 * math.pi / n + 0.3; rd = math.cos(a) * u + math.sin(a) * v
            self.petal(p + fa * L * 0.2, -fa, nv(rd * 0.62 + fa * 0.78), L, L * W, cup, fl, 0.002,
                       prof=[0.55, 0.85, 1.0, 0.95, 0.7, 0.35, 0.0], nveins=3)
        self.ellip(p + fa * L * 0.42, fa, L * 0.2, L * 0.09, H('#a05a06', '#d07a10', '#f09a20', '#ffc04a'), 0.004, spec=0.2)

    def tri(self):
        return [np.array([x / self.SC, y / self.SC, 0.0]) for (x, y) in TRI]

    def tri_vines(self, Lv, n=3, spread=0.95):
        """n vines from each of the 3 hills, fanning out away from the middle of the plot"""
        out = []
        for hi, (x, y) in enumerate(TRI):
            a0 = math.atan2(y - 0.0, x) if (x or y) else 0.0
            for k in range(n):
                a = a0 + spread * (k - (n - 1) / 2) + self.r.normal(0, 0.12)
                out.append((hi, a, Lv * self.r.uniform(0.9, 1.1), 0.3 * (1 if k % 2 else -1)))
        return out

    def _vineplants(self, hills, vines, leafR, leafp, und, vinep, kind, avoid=(), nc=3):
        """vines crawling over the bed from each hill, leaves standing on petioles along them, tendrils"""
        r = self.r; LV = []
        for o in hills:      # a few leaves straight from the crown: the middle of the clump stays full
            for k in range(nc):
                ad = np.array([math.cos(k * 6.283 / nc + 0.6), math.sin(k * 6.283 / nc + 0.6), 0.0])
                if ad[1] > 0.5 and avoid: continue
                Rl = leafR * r.uniform(0.85, 1.0); hgt = (0.2 if kind == 'bido' else 0.18) * r.uniform(0.85, 1.1)
                b = o + ad * Rl * 0.3 + np.array([0, 0, hgt])
                self.tube(self.line_c([o, o + ad * Rl * 0.08 + np.array([0, 0, hgt * 0.7]), b]),
                          0.0055 if kind == 'bido' else 0.0035, 0.0045 if kind == 'bido' else 0.003, vinep, 0.0, int(r.integers(1000)))
                LV.append((b, ad, nv(np.array([r.normal(0, 0.25), 0.3 + r.normal(0, 0.15), 1.0]) + ad * 0.3), Rl))
        for (hi, a, Lv, bend) in vines:
            o = hills[hi]; d = np.array([math.cos(a), math.sin(a), 0.0]); sd_ = nv(np.cross(UP, d))
            pts = [o + np.array([0, 0, 0.01])]
            for k in range(1, 6):
                t = k / 5
                pts.append(o + d * Lv * t + sd_ * bend * math.sin(t * 2.6) * Lv + np.array([0, 0, 0.012 + 0.006 * math.sin(t * 9)]))
            vc = self.line_c(pts)
            self.tube(vc, 0.011 if kind == 'bido' else 0.0075, 0.007 if kind == 'bido' else 0.005, vinep, 0.0, int(r.integers(1000)))
            nl = max(2, int(Lv / (0.085 if kind == 'bido' else 0.06)))
            for j in range(nl):
                t = (j + 0.6) / nl; p0 = vc(np.array([t]))[0]
                side = 1 if j % 2 else -1
                ad = nv(sd_ * side * 0.9 + d * 0.4 + np.array([r.normal(0, 0.2), r.normal(0, 0.2), 0]))
                if any(np.hypot(*(p0[:2] - q[:2])) < q[2] * 1.05 and (p0[1] < q[1] + q[2] * 0.4) for q in avoid):
                    continue       # keep the fruit in sight
                Rl = leafR * (1.05 - 0.35 * t) * r.uniform(0.88, 1.08)
                hgt = (0.14 + 0.1 * (1 - t)) * (1.0 if kind == 'bido' else 0.92) * r.uniform(0.8, 1.15)
                b = p0 + ad * Rl * 0.35 + np.array([0, 0, hgt])
                if any(np.hypot(*(b[:2] + ad[:2] * Rl * 0.6 - q[:2])) < q[2] * 0.9 for q in avoid):
                    continue
                self.tube(self.line_c([p0, p0 + ad * Rl * 0.1 + np.array([0, 0, hgt * 0.7]), b]),
                          0.0055 if kind == 'bido' else 0.0035, 0.0045 if kind == 'bido' else 0.003, vinep, 0.0, int(r.integers(1000)))
                fn = nv(np.array([r.normal(0, 0.25), 0.3 + r.normal(0, 0.15), 1.0]) + ad * 0.25)
                LV.append((b, ad, fn, Rl))
                if j % 2 == 0 and r.random() < 0.6:
                    self._tendril(p0, nv(-ad + d * 0.6), 0.05 if kind == 'bido' else 0.04, pal=vinep)
        return LV

    # ------------------------------------------------------------------ cà rốt
    def _carot(self, seed):
        """carrots in two staggered rows: tufts of finely cut feathery fronds on long stalks; orange shoulders
        of the roots showing above the soil (stage 2 a little, stage 3 fat and ringed)"""
        r = self.r
        stage = seed % 4
        leafp = H('#22561a', '#2e6e20', '#3e8828', '#52a234', '#6cba46', '#98d66a')
        und = H('#3e6c30', '#4e803c', '#64984a', '#7cb05c', '#a0c882')
        petp = H('#3a6420', '#4c7a2a', '#64943a', '#7cac4a', '#9cc46a')
        orp = H('#6e2604', '#a43c08', '#d25a10', '#ee7a1c', '#fa9c3a', '#ffc884')
        spots = [(x / self.SC, y / self.SC) for (x, y) in TRI]
        def frond(o, az, L, el=0.62, sc=1.0, reach=1.0):
            d = np.array([math.cos(az), math.sin(az), 0.0]) * reach
            dr = r.uniform(0.1, 0.25)
            pts = [o, o + d * L * 0.12 + np.array([0, 0, L * el * 0.55]), o + d * L * 0.5 + np.array([0, 0, L * el * 0.92]),
                   o + d * L * 0.9 + np.array([0, 0, L * el * (0.86 - dr)])]
            pc = self.line_c(pts)
            self.tube(pc, 0.0048 * sc, 0.002 * sc, petp, 0.0, int(r.integers(1000)))
            side = nv(np.cross(UP, d))
            npair = 6 if L > 0.15 else 3
            def pinna(bq, e, Lp):
                """one pinna: a fan of narrow linear segments, the finely cut look of a carrot leaf"""
                tip = bq + e * Lp + np.array([0, 0, -Lp * 0.15])
                self.strap(self.line_c([bq, bq + e * Lp * 0.5 + np.array([0, 0, Lp * 0.04]), tip]), 0.011 * sc, leafp, 0.0, fold=0.25,
                           vein_n=1, gloss=0.1, wprof=[0.5, 0.8, 1.0, 1.0, 0.7, 0.0])
                es = nv(np.cross(UP, e))
                for t_ in (0.2, 0.45, 0.7):
                    q = bq + e * Lp * t_ + np.array([0, 0, Lp * 0.03])
                    for s2 in (-1, 1):
                        dd = nv(e * 0.55 + es * s2 * 0.85 + np.array([0, 0, r.normal(-0.05, 0.12)])); ls = Lp * 0.4 * (1.15 - 0.6 * t_) * r.uniform(0.85, 1.1)
                        self.strap(self.line_c([q, q + dd * ls * 0.55 + np.array([0, 0, ls * 0.06]), q + dd * ls]), 0.0102 * sc, leafp, 0.0,
                                   fold=0.25, vein_n=1, gloss=0.1, wprof=[0.5, 0.85, 1.0, 1.0, 0.7, 0.0])
            for k in range(npair):
                t = 0.26 + 0.64 * k / max(npair - 1, 1)
                bq = pc(np.array([t]))[0]
                tg = nv(pc(np.array([min(t + 0.02, 1.0)]))[0] - pc(np.array([max(t - 0.02, 0.0)]))[0])
                for s_ in (-1, 1):
                    e = nv(side * s_ + tg * 0.8 + np.array([0, 0, r.normal(0.05, 0.12)]))
                    pinna(bq, e, L * 0.33 * (1.12 - 0.55 * t) * r.uniform(0.9, 1.1))
            tq = pc(np.array([1.0]))[0]; tg = nv(tq - pc(np.array([0.94]))[0])
            pinna(tq - tg * 0.004, nv(tg + np.array([0, 0, -0.1])), L * 0.2)
        def root(o, R, Hs):
            """the shoulder of the root above the soil: a blunt dome with fine growth rings"""
            cf = self.line_c([o + np.array([0, 0, -0.03]), o + np.array([0, 0, Hs * 0.5]), o + np.array([0.002, 0.001, Hs])])
            def rf(t): return R * np.where(t < 0.45, 1.0, np.sqrt(np.clip(1 - ((t - 0.45) / 0.55) ** 2, 0, 1))) * (1 - 0.1 * t) + 1e-4
            def rings(col, P, N, A, B):
                rg = np.abs(np.sin(P[..., 2] * 2 * math.pi / 0.009 + vnoise(B * 6, A * 2, 7) * 3))
                col = col * (1 - 0.13 * np.clip((0.25 - rg) / 0.25, 0, 1))[..., None]
                return mix(col, A_(C('#7a7a2a')), np.clip((A - 0.9) / 0.1, 0, 1) * 0.45)    # the green crown
            self.tube(cf, R, R, orp, 0.0, int(r.integers(1000)), tint=rings, rfun=rf, zcut=0.0)
        if stage == 1:
            for (x, y) in spots:
                o = np.array([x + r.normal(0, 0.01), y + r.normal(0, 0.01), 0.0])
                for s_ in (-1, 1):      # thread-thin seed leaves
                    a = r.uniform(-0.4, 0.4) + (0 if s_ > 0 else math.pi); d = np.array([math.cos(a), math.sin(a), 0.0])
                    self.strap(self.line_c([o, o + d * 0.02 + np.array([0, 0, 0.065]), o + d * 0.08 + np.array([0, 0, 0.088])]), 0.0095, leafp, 0.0, fold=0.2, vein_n=1)
                a0 = r.uniform(0, 6.28)
                for j in range(4):
                    frond(o, a0 + j * 1.6, r.uniform(0.16, 0.19), el=0.9, sc=0.85)
            return
        L0 = 0.26 if stage == 2 else 0.34
        nf = 10 if stage == 2 else 13
        for (x, y) in spots:
            o = np.array([x + r.normal(0, 0.012), y + r.normal(0, 0.012), 0.0])
            R = 0.036 if stage == 2 else 0.058
            Hs = (0.055 if stage == 2 else 0.12) * r.uniform(0.9, 1.1)
            root(o, R * r.uniform(0.94, 1.06), Hs)
            a0 = r.uniform(0, 6.28)
            for j in range(nf):
                az = a0 + j * 2.39996
                frond(o + np.array([0, 0, Hs * 0.92]), az, L0 * r.uniform(0.85, 1.1) * (1.0 if j > 1 else 1.12), el=1.15 + 0.25 * (j < 3), reach=0.7)

    # ------------------------------------------------------------------ bí đỏ
    def _bido(self, seed):
        """pumpkin (bí đỏ): thick vines crawling over the bed, big rounded hairy leaves standing on long petioles with
        pale silvery patches, curly tendrils, big yellow trumpet flowers; stage 3 two big ribbed orange pumpkins"""
        r = self.r
        stage = seed % 4
        leafp = H('#173e14', '#20541a', '#2c6a22', '#3c822c', '#549a3a', '#78b458')
        und = H('#3a6430', '#4a7840', '#5e8e50', '#76a466', '#98bc88')
        vinep = H('#2e5418', '#406a22', '#56842e', '#6e9c3c', '#90b85a')
        pump = H('#6a2604', '#9c400a', '#ca6214', '#e8821e', '#f6a23a', '#ffcc7a')
        ygrn = H('#28501a', '#3a6a22', '#527e2c', '#6c9a3a', '#8cb458', '#b8d488')
        fl = dict(base=A_(C('#e08a08')), mid=A_(C('#f8b418')), tip=A_(C('#ffd23e')), deep=A_(C('#8a5006')), vein=A_(C('#d07006')))
        stemp = H('#3e3a14', '#5a5420', '#76702e', '#94903e', '#b2ae5a')
        def pumpkin(c, R, pal, young=False):
            sd = int(r.integers(1000)); ax = nv(np.array([r.normal(0, 0.06), r.normal(0, 0.06), 1.0])); u, v = basis(ax)
            a = R * (0.7 if not young else 0.8); ph0 = r.uniform(0, 1)
            def geo(A, B):
                th = A * math.pi; ph = B * 2 * math.pi + ph0
                rib = 1 - 0.07 * (1 - np.abs(np.sin(5 * ph))) ** 3
                st = np.sin(th); z = a * np.cos(th) * (1 - 0.32 * np.exp(-(th / 0.42) ** 2)) * (1 - 0.12 * np.exp(-((math.pi - th) / 0.45) ** 2))
                rad = R * st * rib
                return c + ax * z[..., None] + (np.cos(ph)[..., None] * u + np.sin(ph)[..., None] * v) * rad[..., None]
            def sh(P, N, F, A, B):
                lam = self.lam(N); ph = B * 2 * math.pi + ph0
                sv = (0.12 + 0.86 * lam) * self.grain(P, R * 0.1, sd, 0.04)
                col = ramp(pal, np.clip(sv, 0, 1))
                gr = np.clip((0.18 - np.abs(np.sin(5 * ph))) / 0.18, 0, 1)
                col = mix(col, col * 0.62, gr * 0.6)                       # the grooves
                n_ = vnoise(B * 40, A * 14, sd)
                col = mix(col, pal[-1], np.clip((n_ - 0.72) / 0.2, 0, 1) * 0.25)       # fine pale flecks
                col = mix(col, A_(C('#8a7a2a')), np.clip((0.14 - A) / 0.1, 0, 1) * 0.5)   # paler, greener round the stem
                sp = np.clip(N @ HALF, 0, 1) ** 6 * 0.035
                return np.clip(col + sp[..., None], 0, 1)
            self.splat(geo, sh, c + TOCAM * 0.0, edge_k=0.8)
            top = c + ax * a * 0.68
            if young: return top
            ds = nv(np.array([r.normal(0, 0.5), r.normal(0, 0.3), 1.0]))
            sc = self.line_c([top - ax * 0.01, top + ds * 0.035, top + ds * 0.06 + np.array([0.02, 0, 0.004])])
            def ridge(col, P, N, A, B): return col * (0.8 + 0.2 * np.abs(np.cos(B * math.pi * 5)))[..., None]
            self.tube(sc, R * 0.11, R * 0.085, stemp, 0.0, int(r.integers(1000)), tint=ridge)
            self.ellip(sc(np.array([1.0]))[0], nv(sc(np.array([1.0]))[0] - sc(np.array([0.9]))[0]), 0.006, R * 0.09, stemp, 0.003, spec=0.05)
            return top
        hills = self.tri()
        if stage == 1:
            for o in hills:
                Hc = r.uniform(0.08, 0.1)
                top = o + np.array([0, 0, Hc])
                self.tube(self.line_c([o, o + np.array([0, 0, Hc * 0.5]), top]), 0.0085, 0.007, vinep, 0.0, int(r.integers(1000)))
                a0 = r.uniform(-0.3, 0.3)
                for s_ in (-1, 1):      # thick oval seed leaves
                    d = np.array([math.cos(a0) * s_, math.sin(a0) * s_, 0.0])
                    self.leaf(top, nv(d + np.array([0, 0, 0.25])), nv(UP + np.array([0, 0.25, 0])), 0.095, 0.058, leafp, und,
                              droop=0.12, fold=0.06, veins=2, gloss=0.18, prof=[0.0, 0.7, 0.95, 1.0, 0.9, 0.6, 0.0], mid_k=0.4)
                b = top + np.array([0.006, 0.01, 0.055])
                self.tube(self.line_c([top, top + np.array([0, 0.003, 0.032]), b]), 0.0055, 0.0045, vinep, 0.0, int(r.integers(1000)))
                self.pleaf(b, np.array([0.2, 0.6, 0.3]), np.array([0.0, 0.45, 1.0]), 0.105, leafp, und, pale=0.5)
            return
        LV = []
        if stage == 2:
            vines = self.tri_vines(0.17)
            avoid = [np.array([0.04, 0.17, 0.08])]
            LV = self._vineplants(hills, vines, 0.13, leafp, und, vinep, 'bido', avoid)
            pumpkin(np.array([0.04, 0.17, 0.045]), 0.05, ygrn, young=True)
            self._vinef(np.array([0.04, 0.17, 0.098]) + np.array([0, -0.004, 0]), np.array([0.1, 0.5, 1.0]), 0.05, fl, cup=0.35)
            for (p, fa) in ((np.array([-0.16, 0.08, 0.12]), np.array([-0.3, 0.6, 0.8])), (np.array([0.17, 0.06, 0.11]), np.array([0.4, 0.7, 0.7])),
                            (np.array([0.0, -0.16, 0.24]), np.array([0.0, 0.5, 0.9]))):
                self.tube(self.line_c([p - np.array([0, 0, p[2] - 0.01]), p - np.array([0, 0.01, (p[2] - 0.01) * 0.5]), p]), 0.004, 0.0035, vinep, 0.0, int(r.integers(1000)))
                self._vinef(p, fa, 0.075, fl)
        else:
            vines = self.tri_vines(0.23, n=4, spread=0.75)
            fr = [np.array([0.02, 0.2, 0.25])]
            LV = self._vineplants(hills, vines, 0.15, leafp, und, vinep, 'bido', fr, nc=5)
            pumpkin(np.array([0.02, 0.2, 0.25 * 0.66]), 0.25, pump)
            p = np.array([0.22, 0.04, 0.12])
            self.tube(self.line_c([p - np.array([0, 0, 0.08]), p - np.array([0, 0.01, 0.04]), p]), 0.004, 0.0035, vinep, 0.0, int(r.integers(1000)))
            self._vinef(p, np.array([0.4, 0.7, 0.7]), 0.075, fl)
        def yel(col, P, N, A, B): return col
        for (b, ad, fn, Rl) in LV:
            old = stage == 3 and r.random() < 0.18
            tint = (lambda col, P, N, A, B: mix(col, A_(C('#a8a03a')), np.clip(0.35 + 0.4 * A, 0, 1) * 0.5)) if old else None
            self.pleaf(b, ad, fn, Rl, leafp, und, lobes=5, depth=0.22, cup=-0.12, ruffle=0.045, pale=0.3, tint=tint)

    # ------------------------------------------------------------------ dưa hấu
    def _duahau(self, seed):
        """watermelon (dưa hấu): thin hairy vines low over the bed, grey-green deeply cut leaves lying close to the
        ground, small pale-yellow flowers; stage 3 two big oval striped melons with a pale belly where they lie"""
        r = self.r
        stage = seed % 4
        leafp = H('#1a3e1c', '#244f24', '#31632e', '#417a3a', '#58904c', '#7eac6c')
        und = H('#4a6448', '#5a7656', '#6e8a68', '#86a07e', '#a6ba9c')
        vinep = H('#365a22', '#46702a', '#5c8838', '#76a048', '#98ba68')
        wl = H('#2a5418', '#3e6e22', '#58882e', '#74a23e', '#94bc5a', '#c4dc94')
        fl = dict(base=A_(C('#e0b010')), mid=A_(C('#f6d42a')), tip=A_(C('#ffe866')), deep=A_(C('#8a6a08')), vein=A_(C('#c89a10')))
        def melon(c, ax, a, b, young=False):
            sd = int(r.integers(1000)); ph0 = r.uniform(0, 6.28)
            def stripes(col, P, N, A, B):
                ph = B * 2 * math.pi
                n_ = vnoise(A * 30, B * 8, sd) - 0.5
                s_ = np.cos(ph * 8 + ph0 + np.sin(A * math.pi * 14 + ph * 3) * 0.55 + n_ * 1.4)
                k = np.clip((s_ + 0.15) / 0.35, 0, 1) * np.sin(A * math.pi) ** 0.3
                dark = col * np.array([0.3, 0.42, 0.3]) + np.array([0.0, 0.02, 0.0])
                col = mix(col, dark, k * 0.9)
                belly = np.clip((-N[..., 2] - 0.15) / 0.5, 0, 1) * (1 - k * 0.7)
                return mix(col, A_(C('#d8c46a')), belly * 0.7)
            self.ellip(c, ax, a, b, wl, 0.0, spec=0.05, tint=stripes, edge_k=0.8)
            return c + ax * a
        hills = self.tri()
        if stage == 1:
            for o in hills:
                Hc = r.uniform(0.08, 0.1)
                top = o + np.array([0, 0, Hc])
                self.tube(self.line_c([o, o + np.array([0, 0, Hc * 0.5]), top]), 0.0085, 0.007, vinep, 0.0, int(r.integers(1000)))
                a0 = r.uniform(-0.3, 0.3)
                for s_ in (-1, 1):
                    d = np.array([math.cos(a0) * s_, math.sin(a0) * s_, 0.0])
                    self.leaf(top, nv(d + np.array([0, 0, 0.2])), nv(UP + np.array([0, 0.25, 0])), 0.095, 0.058, leafp, und,
                              droop=0.12, fold=0.06, veins=2, gloss=0.18, prof=[0.0, 0.7, 0.95, 1.0, 0.9, 0.6, 0.0], mid_k=0.4)
                for k, az in enumerate((1.3, -0.6)):
                    b = top + np.array([0.016 * math.cos(az), 0.016 * math.sin(az) + 0.01, 0.055 - 0.016 * k])
                    self.tube(self.line_c([top, top + np.array([0, 0.003, 0.02]), b]), 0.0045, 0.004, vinep, 0.0, int(r.integers(1000)))
                    self.wleaf(b, np.array([math.cos(az), math.sin(az), 0.2]), np.array([0.0, 0.45, 1.0]), 0.135 - 0.024 * k, leafp, und)
            return
        if stage == 2:
            vines = self.tri_vines(0.17)
            fr = [np.array([0.04, 0.2, 0.09])]
            LV = self._vineplants(hills, vines, 0.19, leafp, und, vinep, 'duahau', fr)
            melon(np.array([0.04, 0.2, 0.056]), nv(np.array([1.0, 0.25, 0.0])), 0.072, 0.06, young=True)
            for (p, fa) in ((np.array([-0.15, 0.07, 0.07]), np.array([-0.2, 0.6, 0.8])), (np.array([0.16, 0.05, 0.07]), np.array([0.3, 0.6, 0.8])),
                            (np.array([0.0, -0.15, 0.1]), np.array([0.0, 0.5, 0.9])), (np.array([0.1, 0.12, 0.06]), np.array([0.2, 0.7, 0.7]))):
                self.tube(self.line_c([p - np.array([0, 0, p[2] - 0.01]), p - np.array([0, 0.008, (p[2] - 0.01) * 0.5]), p]), 0.0026, 0.0024, vinep, 0.0, int(r.integers(1000)))
                self._vinef(p, fa, 0.032, fl, cup=0.45, W=0.7)
        else:
            vines = self.tri_vines(0.23, n=4, spread=0.75)
            fr = [np.array([0.02, 0.2, 0.27])]
            LV = self._vineplants(hills, vines, 0.195, leafp, und, vinep, 'duahau', fr, nc=5)
            melon(np.array([0.02, 0.2, 0.188]), nv(np.array([1.0, 0.3, 0.0])), 0.245, 0.205)
            p = np.array([0.22, 0.06, 0.07])
            self.tube(self.line_c([p - np.array([0, 0, 0.04]), p - np.array([0, 0.008, 0.02]), p]), 0.0026, 0.0024, vinep, 0.0, int(r.integers(1000)))
            self._vinef(p, np.array([0.3, 0.6, 0.8]), 0.032, fl, cup=0.45, W=0.7)
        for (b, ad, fn, Rl) in LV:
            fn2 = nv(fn + np.array([0, 0, 0.25]))          # lying flatter than the bí leaves
            self.wleaf(b, ad, fn2, Rl, leafp, und)

    # ------------------------------------------------------------------ dưa leo
    def _dua_leo(self, seed):
        """cucumber (dưa leo): 3 plants on the bắp spots, each climbing its own bamboo cane; rough 5-angled leaves,
        curly tendrils, small yellow flowers (stage 2), slim bumpy dark-green cucumbers hanging (stage 3)"""
        r = self.r
        stage = seed % 4
        leafp = H('#1c4a16', '#275e1c', '#357424', '#478c2e', '#60a43e', '#86bc62')
        und = H('#3c6630', '#4c7a3c', '#62904c', '#7aa660', '#9cc082')
        vinep = H('#3a6222', '#4a782a', '#609236', '#78aa46', '#9cc468')
        cup_ = H('#24501a', '#326c20', '#44882a', '#5aa236', '#7cbc4e', '#b4dc8a')
        fl = dict(base=A_(C('#e0b010')), mid=A_(C('#f6d42a')), tip=A_(C('#ffe866')), deep=A_(C('#8a6a08')), vein=A_(C('#c89a10')))
        spots = self.tri()
        def cuke(top, L, R, lean):
            """one cucumber hanging from top: slim, slightly curved, bumpy, pale stripes toward the blossom end"""
            sd = int(r.integers(1000))
            bot = top + np.array([lean[0] * L * 0.25, lean[1] * L * 0.25, -L])
            mid = (top + bot) * 0.5 + np.array([lean[0] * 0.012, lean[1] * 0.012 + 0.008, 0])
            cf = self.line_c([top, mid, bot])
            def rf(t): return R * np.sqrt(np.clip(1 - ((t - 0.55) / 0.55) ** 2, 0, 1)) ** 0.55 * (0.82 + 0.18 * t) + 1e-4
            def bumps(col, P, N, A, B):
                bb = vnoise(A * 22, B * 9, sd); sp = np.clip((bb - 0.72) / 0.2, 0, 1)
                col = mix(col, A_(C('#a6c87a')), sp * 0.5)                                  # pale warts
                st = np.clip((np.abs(np.cos(B * math.pi * 5)) - 0.75) / 0.25, 0, 1) * np.clip((A - 0.45) / 0.4, 0, 1)
                return mix(col, A_(C('#9cc070')), st * 0.45)                                  # stripes at the blossom end
            self.tube(cf, R, R, cup_, 0.0, sd, tint=bumps, rfun=rf)
            self.ellip(bot + np.array([0, 0, -0.004]), np.array([0, 0.3, -1.0]), 0.008, 0.006, H('#7a6420', '#a08a2a', '#c8ae40', '#e4cc6a'), 0.002, spec=0.03)
        if stage == 1:
            for o in spots:
                Hc = r.uniform(0.08, 0.1)
                top = o + np.array([0, 0, Hc])
                self.tube(self.line_c([o, o + np.array([0, 0, Hc * 0.5]), top]), 0.0075, 0.0062, vinep, 0.0, int(r.integers(1000)))
                a0 = r.uniform(-0.3, 0.3)
                for s_ in (-1, 1):      # long oval seed leaves
                    d = np.array([math.cos(a0) * s_, math.sin(a0) * s_, 0.0])
                    self.leaf(top, nv(d + np.array([0, 0, 0.25])), nv(UP + np.array([0, 0.25, 0])), 0.09, 0.045, leafp, und,
                              droop=0.12, fold=0.06, veins=2, gloss=0.05, prof=[0.0, 0.6, 0.95, 1.0, 0.9, 0.55, 0.0], mid_k=0.4)
                b = top + np.array([0.006, 0.01, 0.055])
                self.tube(self.line_c([top, top + np.array([0, 0.003, 0.032]), b]), 0.005, 0.0042, vinep, 0.0, int(r.integers(1000)))
                self.pleaf(b, np.array([0.2, 0.6, 0.3]), np.array([0.0, 0.45, 1.0]), 0.095, leafp, und, lobes=5, depth=0.16, spread=0.8,
                           teeth=(34, 0.05), cup=-0.06, ruffle=0.03)
            return
        Hk = 0.8 if stage == 2 else 1.02          # Link 11-10: gđ3 a little lower (was 1.14 / 1.06)
        Hv = 0.68 if stage == 2 else 0.95
        for pi, o in enumerate(spots):
            so = o + np.array([0.008, -0.03, 0.0])
            self._stake(so, Hk * r.uniform(0.96, 1.04))
            pts = []                      # the vine winds round the cane up to Hv
            ph = r.uniform(0, 6.28)
            for k in range(9):
                t = k / 8; a = ph + t * 4.4
                rad = 0.006 + 0.022 * (1 - abs(2 * t - 1) ** 2) if k else 0.0
                pts.append((so if k else o) * np.array([1, 1, 0]) + np.array([math.cos(a) * rad, math.sin(a) * rad + (0.03 * (1 - t) if k else 0), Hv * t]))
            vc = self.line_c(pts)
            self.tube(vc, 0.0085, 0.0055, vinep, 0.0, int(r.integers(1000)))
            for z in (0.3, 0.6) if stage == 2 else (0.25, 0.5, 0.75):
                self._tendril(vc(np.array([z]))[0], nv(so - vc(np.array([z]))[0] + np.array([0.001, -0.001, 0.02])), 0.035, pal=vinep)
            nl = 8 if stage == 2 else 12
            a0 = r.uniform(0, 6.28)
            ck = [(0.5, math.pi * 0.5 - 0.6), (0.66, math.pi * 0.5 + 0.6)] if stage == 3 else []
            for j in range(nl):
                t0 = 0.1 + 0.88 * j / (nl - 1)
                p0 = vc(np.array([t0]))[0]
                az = a0 + j * 2.39996
                if math.sin(az) < -0.6: az += 1.3       # not straight back behind the cane
                if any(-0.45 < t0 - tc < 0.12 and abs(math.atan2(math.sin(az - ac), math.cos(az - ac))) < 1.0 for tc, ac in ck):
                    az += 1.6 if math.cos(az) > 0 else -1.6       # keep the cucumbers in sight
                d = np.array([math.cos(az), math.sin(az), 0.0])
                Rl = (0.13 if stage == 2 else 0.15) * (1.1 - 0.3 * t0) * r.uniform(0.9, 1.08)
                b = p0 + d * Rl * 0.8 + np.array([0, 0, Rl * 0.3])
                self.tube(self.line_c([p0, p0 + d * Rl * 0.35 + np.array([0, 0, Rl * 0.3]), b]), 0.0042, 0.0034, vinep, 0.0, int(r.integers(1000)))
                fn = nv(TOCAM * 0.55 + UP * 0.35 + d * 0.3)
                self.pleaf(b, nv(d + np.array([0, 0, -0.35])), fn, Rl, leafp, und, lobes=5, depth=0.16, spread=0.8,
                           teeth=(34, 0.05), cup=-0.06, ruffle=0.03)
            # flowers on the front side
            nfl = 3 if stage == 2 else 2
            for k in range(nfl):
                a = math.pi * 0.5 + (k - (nfl - 1) / 2) * 1.1 + r.normal(0, 0.15); d = np.array([math.cos(a), math.sin(a), 0.0])
                p0 = vc(np.array([0.35 + 0.45 * k / max(nfl - 1, 1)]))[0]
                pf = p0 + d * 0.035 + np.array([0, 0, 0.012])
                self.tube(self.line_c([p0, p0 + d * 0.018 + np.array([0, 0, 0.01]), pf]), 0.0022, 0.002, vinep, 0.0, int(r.integers(1000)))
                self._vinef(pf, nv(d + np.array([0, 0.3, 0.6])), 0.05, fl, cup=0.45, W=0.7)
            if stage == 3:
                for k, (t, a) in enumerate(ck):
                    a += r.normal(0, 0.12); d = np.array([math.cos(a), math.sin(a), 0.0])
                    p0 = vc(np.array([t]))[0]; tp = p0 + d * 0.085 + np.array([0, 0, -0.004])
                    self.tube(self.line_c([p0, p0 + d * 0.028 + np.array([0, 0, 0.006]), tp]), 0.0032, 0.003, vinep, 0.0, int(r.integers(1000)))
                    cuke(tp, r.uniform(0.33, 0.36), 0.05, (d[0] * 0.3, d[1] * 0.3))

    # ------------------------------------------------------------------ khoai lang
    def _khoai(self, seed):
        """sweet potato (khoai lang): 3 plants on the bắp spots from cuttings; heart-shaped / 3-lobed leaves standing
        on purple-tinged stalks, short runners; stage 3 the red-purple tubers swelling out of the soil at each plant"""
        r = self.r
        stage = seed % 4
        leafp = H('#1e4a16', '#2a601c', '#387824', '#4a902e', '#64a83e', '#8cc062')
        und = H('#3e6430', '#4e783c', '#64904c', '#7ca660', '#9ec084')
        petp = H('#3e2a30', '#5a3c3a', '#76543e', '#8e7044', '#a89050')
        tubp = H('#4a0c26', '#6a1434', '#8c2046', '#ac305a', '#c64a72', '#e488a8')
        spots = self.tri()
        def young(col, P, N, A, B): return mix(col, A_(C('#6a4a52')), 0.35 * (1 - A) * 0.6)     # purple flush on new leaves
        def hleaf(p0, az, Rl, hgt, lean=0.45, yt=False):
            d = np.array([math.cos(az), math.sin(az), 0.0])
            b = p0 + d * Rl * 0.45 + np.array([0, 0, hgt])
            self.tube(self.line_c([p0, p0 + d * Rl * 0.15 + np.array([0, 0, hgt * 0.7]), b]), 0.0042, 0.0034, petp, 0.0, int(r.integers(1000)))
            fn = nv(UP * 0.8 + d * lean + np.array([0, 0.35, 0]))
            lb = 3 if r.random() < 0.6 else 5
            self.pleaf(b, nv(d + np.array([0, 0, -0.3])), fn, Rl, leafp, und, lobes=lb, depth=0.3 if lb == 3 else 0.36, spread=0.78,
                       teeth=(0, 0.0), cup=-0.05, ruffle=0.025, tint=young if yt else None)
        def tuber(o, az, L, R):
            d = np.array([math.cos(az), math.sin(az), 0.0])
            c0 = o + d * 0.05 + np.array([0, 0, -0.03])
            c2 = o + d * (0.05 + L) + np.array([0, 0, -0.03])
            cf = self.line_c([c0, (c0 + c2) * 0.5 + np.array([0, 0, R * 0.55]), c2])
            sd = int(r.integers(1000))
            def rf(t): return R * np.sqrt(np.clip(np.sin(t * math.pi), 0, 1)) * (0.9 + 0.1 * np.sin(t * 7 + sd)) + 1e-4
            def skin(col, P, N, A, B):
                n_ = vnoise(A * 14, B * 6, sd)
                col = col * (1 - 0.12 * np.clip((n_ - 0.6) / 0.3, 0, 1))[..., None]
                return mix(col, A_(C('#6a4a3a')), np.clip((0.06 - P[..., 2]) / 0.06, 0, 1) * 0.25)   # soil on the lower side
            self.tube(cf, R, R, tubp, 0.0, sd, tint=skin, rfun=rf, zcut=0.0)
        if stage == 1:
            for o in spots:
                lean = r.uniform(0, 6.28); dl = np.array([math.cos(lean), math.sin(lean), 0.0])
                top = o + dl * 0.03 + np.array([0, 0, 0.09])
                cut = self.line_c([o + np.array([0, 0, -0.01]), o + dl * 0.012 + np.array([0, 0, 0.05]), top])
                self.tube(cut, 0.0075, 0.006, petp, 0.0, int(r.integers(1000)))
                for k in range(4):
                    p0 = cut(np.array([0.45 + 0.18 * k]))[0]
                    hleaf(p0, lean + k * 2.3 + r.normal(0, 0.2), 0.062 - 0.006 * k, 0.03 + 0.008 * k, yt=k == 3)
            return
        nl = 10 if stage == 2 else 14
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            tub = [math.pi * 0.5 - 0.65, math.pi * 0.5 + 0.65] if stage == 3 else []
            for j in range(nl):
                az = a0 + j * 2.39996
                if stage == 3 and any(abs(math.atan2(math.sin(az - ta), math.cos(az - ta))) < 0.75 for ta in tub): az += 1.5
                Rl = (0.09 if stage == 2 else 0.11) * r.uniform(0.88, 1.08)
                hgt = (0.06 + 0.1 * (j % 3) / 2) * (1.35 if stage == 2 else 2.7) * r.uniform(0.85, 1.1)
                hleaf(o + np.array([0, 0, 0.012]), az, Rl, hgt, yt=j >= nl - 2)
            # two runners crawling out, away from the middle of the plot, with leaves along them
            ao = math.atan2(o[1] - 0.02, o[0]) if abs(o[0]) > 0.01 else math.pi * 0.5
            for s_ in (-1, 1):
                a = ao + s_ * 0.7; d = np.array([math.cos(a), math.sin(a), 0.0])
                Lr = (0.14 if stage == 2 else 0.18) * r.uniform(0.9, 1.1)
                rc = self.line_c([o + np.array([0, 0, 0.01]), o + d * Lr * 0.5 + nv(np.cross(UP, d)) * 0.015 + np.array([0, 0, 0.014]), o + d * Lr + np.array([0, 0, 0.01])])
                self.tube(rc, 0.0055, 0.0042, petp, 0.0, int(r.integers(1000)))
                for k in range(2 if stage == 2 else 3):
                    t = 0.45 + 0.55 * k / 2; p0 = rc(np.array([t]))[0]
                    hleaf(p0, a + (0.9 if k % 2 else -0.9), (0.075 if stage == 2 else 0.085) * r.uniform(0.9, 1.05), r.uniform(0.05, 0.09), yt=k == 2)
            for ta in tub:
                tuber(o, ta + r.normal(0, 0.1), r.uniform(0.28, 0.3), r.uniform(0.08, 0.086))      # Link 14:48: củ to rõ

    # ------------------------------------------------------------------ mía
    def _mia(self, seed):
        """sugarcane (mía tím): 3 clumps on the bắp spots; thick jointed red-purple canes with a pale waxy band under each
        node, long arching leaves from the top part, dry straw leaves hanging lower down (stage 3)"""
        r = self.r
        stage = seed % 4
        leafp = H('#24521a', '#326a20', '#428228', '#579a32', '#72b242', '#9ccc68')
        canep = H('#2a0e1c', '#46182e', '#642442', '#843458', '#a24c70', '#c4789a')
        greenc = H('#3a4a1c', '#526228', '#6e7a34', '#8a8e44', '#a8a85a', '#c8c482')
        dry = H('#6a5430', '#8a7040', '#a88c54', '#c4a86c', '#dcc48c', '#eedcae')
        dtip = (A_(C('#8a8a2e')), A_(C('#c4c070')))
        spots = self.tri()
        def cane(o, top, R, pal, node):
            cf = self.line_c([o, (o + top) * 0.5 + np.array([0.004, 0, 0]), top])
            L = float(np.linalg.norm(top - o))
            def wax(col, P, N, A, B):
                ph = (A * L / node) % 1.0
                band = np.exp(-((ph - 0.36) / 0.08) ** 2)          # waxy bloom just above each node ring
                col = mix(col, A_(C('#b0a4b4')), band * 0.45)
                eye = np.exp(-((ph - 0.56) / 0.05) ** 2) * np.exp(-(((B - 0.25 - 0.5 * (np.floor(A * L / node) % 2)) % 1.0 - 0.5) / 0.05) ** 2)
                col = mix(col, A_(C('#6a5a2a')), eye * 0.5)          # bud eyes on alternate sides
                return col * (0.72 + 0.28 * np.clip(P[..., 2] / 0.3, 0, 1))[..., None]
            self.tube(cf, R, R * 0.82, pal, 0.0, int(r.integers(1000)), node=node, node_col=A_(C('#3a2a1a')), tint=wax)
            return cf
        def blade(p0, az, L, up, W, pal=None, tip=None, droop=0.0):
            d = np.array([math.cos(az), math.sin(az), 0.0])
            p1 = p0 + d * L * 0.2 + np.array([0, 0, L * up * 0.45])
            p2 = p0 + d * L * 0.55 + np.array([0, 0, L * up * 0.55 - droop * 0.3 * L])
            p3 = p0 + d * L * 0.92 + np.array([0, 0, L * (up * 0.25 - 0.28) - droop * L])
            p2[2] = max(p2[2], 0.05); p3[2] = max(p3[2], 0.02)
            self.strap(self.line_c([p0, p1, p2, p3]), W, pal or leafp, 0.0, fold=0.22, vein_n=7,
                       wprof=[0.5, 0.85, 1.0, 0.8, 0.45, 0.0], gloss=0.1, tipcol=tip, tipk=r.uniform(0.88, 0.95) if tip else 0.0)
        if stage == 1:
            for o in spots:
                # the planted cutting (hom mía) showing a little, one young shoot fanning its leaves
                cut = self.line_c([o + np.array([-0.05, -0.012, -0.008]), o + np.array([0, 0, -0.004]), o + np.array([0.05, 0.014, -0.008])])
                self.tube(cut, 0.016, 0.016, canep, 0.0, int(r.integers(1000)), node=0.05, node_col=A_(C('#3a2a1a')), zcut=0.0)
                sh = o + np.array([0, 0, 0.012])
                top = sh + np.array([0, 0, 0.07])
                self.tube(self.line_c([sh, (sh + top) * 0.5, top]), 0.011, 0.008, greenc, 0.0, int(r.integers(1000)))
                a0 = r.uniform(0, 6.28)
                for j in range(5):
                    blade(sh + np.array([0, 0, 0.02 + 0.012 * j]), a0 + j * 2.5, r.uniform(0.26, 0.33), r.uniform(1.4, 1.9), 0.026)
            return
        nc = 3 if stage == 2 else 4
        Hm = 0.6 if stage == 2 else 0.74
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            for c_ in range(nc):
                a = a0 + c_ * 2 * math.pi / nc; dl = np.array([math.cos(a), math.sin(a), 0.0])
                ob = o + dl * 0.03
                Hc = Hm * r.uniform(0.88, 1.06) * (1.0 if c_ else 1.06)
                top = ob + dl * Hc * 0.08 + np.array([0, 0, Hc])
                R = (0.017 if stage == 2 else 0.022) * r.uniform(0.92, 1.06)
                cf = cane(ob, top, R, greenc if stage == 2 and c_ % 2 else canep, 0.07 if stage == 2 else 0.085)
                if stage == 3:      # dry straw leaves hanging from the lower nodes
                    p0 = cf(np.array([r.uniform(0.38, 0.48)]))[0]; az = a + r.uniform(-1.0, 1.0)
                    blade(p0, az, r.uniform(0.2, 0.26), 0.35, 0.03, pal=dry, droop=0.3)
                # green leaves from the top part, the youngest fan upright at the tip
                nlv = 6 if stage == 2 else 8
                for j in range(nlv):
                    t0 = (0.4 if stage == 2 else 0.6) + (0.98 - (0.4 if stage == 2 else 0.6)) * j / (nlv - 1)
                    p0 = cf(np.array([t0]))[0]
                    az = a + (j % 2 * 2 - 1) * r.uniform(0.6, 1.5) + r.normal(0, 0.25)
                    up = 0.7 + 0.9 * j / (nlv - 1) + r.uniform(-0.1, 0.1)
                    L = (0.4 if stage == 2 else 0.47) * (1.05 - 0.3 * j / nlv) * r.uniform(0.9, 1.08)
                    blade(p0, az, L, up, (0.032 if stage == 2 else 0.038) * r.uniform(0.92, 1.08),
                          tip=dtip if stage == 3 else None, droop=0.15 * (1 - j / nlv))

    # ------------------------------------------------------------------ ớt
    def _ot(self, seed):
        """chili (ớt): 3 bushy plants on the bắp spots; green forked stems, glossy-free lance leaves, small white
        flowers (stage 2) and big bright red chilies hanging out front (stage 3)"""
        r = self.r
        stage = seed % 4
        leafp = H('#173e14', '#20521a', '#2c6a22', '#3c822c', '#529a3a', '#76b458')
        und = H('#34602a', '#447436', '#568a44', '#6ea056', '#90ba78')
        stemp = H('#2e5418', '#3e6a20', '#52822a', '#6a9a38', '#8cb456')
        redp = H('#5a0606', '#8c0c0a', '#bc1a12', '#e0301e', '#f4583a', '#ff9a80')
        orap = H('#6e2a06', '#a04008', '#cc5e12', '#ea7e1e', '#f8a03c', '#ffcc88')
        grnp = H('#1e4410', '#2c5c16', '#3e761e', '#54902a', '#72aa40', '#a4cc78')
        calp = H('#24441a', '#2e5a1e', '#3e7228', '#528a34', '#70a44c')
        fl = dict(base=A_(C('#d8d8c8')), mid=A_(C('#f2f2e8')), tip=A_(C('#ffffff')), deep=A_(C('#a0a090')), vein=A_(C('#c8c8b8')))
        spots = self.tri()
        def leaf(p0, az, L, up=0.35):
            d = np.array([math.cos(az), math.sin(az), 0.0])
            b = p0 + d * L * 0.12 + np.array([0, 0, L * 0.05])
            self.tube(self.line_c([p0, p0 + d * L * 0.06 + np.array([0, 0, L * 0.05]), b]), 0.003, 0.0025, stemp, 0.0, int(r.integers(1000)))
            e = nv(d + np.array([0, 0, up - 0.2 + r.normal(0, 0.1)]))
            f = nv(np.array([0, 0.3, 1.0]) - d * 0.25)
            self.leaf(b, e, f, L, L * r.uniform(0.4, 0.46), leafp, und, droop=r.uniform(0.15, 0.3), fold=0.12, veins=6, gloss=0.05,
                      prof=[0.0, 0.55, 0.92, 1.0, 0.8, 0.4, 0.0], mid_k=0.3)
        def flower(p, d):
            f = nv(d * 0.3 + np.array([0, 0.7, -0.5]))
            u, v = basis(f)
            for k in range(5):
                a = k * 1.2566; e = nv((math.cos(a) * u + math.sin(a) * v) * 0.9 - f * 0.2)
                self.petal(p, -f, e, 0.03, 0.016, -0.1, fl, 0.003, prof=[0.6, 0.9, 1.0, 0.9, 0.6, 0.3, 0.0], nveins=3)
            self.ellip(p + f * 0.008, f, 0.01, 0.006, H('#4a5a8a', '#5a6aa0', '#7a8ab8', '#a0b0d0'), 0.006, spec=0.05)
        def chili(p, d, L, R, pal):
            """a chili hanging from p: green stalk, cap, then a long, slightly curved body to a pointed tip"""
            ax0 = nv(d * 0.3 + np.array([0, 0.25, -1.0]))
            c0 = p + ax0 * 0.025
            self.tube(self.line_c([p, p + d * 0.01 + ax0 * 0.01, c0]), 0.0042, 0.0046, calp, 0.0, int(r.integers(1000)))
            bend = nv(d + np.array([0, 0.35, 0])) * L * 0.22
            body = self.line_c([c0, c0 + ax0 * L * 0.35 + bend * 0.25, c0 + ax0 * L * 0.72 + bend * 0.75, c0 + ax0 * L + bend * 1.2])
            def rf(t):
                g = np.clip(t / 0.18, 0, 1); g = g * g * (3 - 2 * g)
                return R * (0.65 + 0.35 * g) * (1 - t) ** 0.75 + 1e-4
            def sh(col, P, N, A, B):
                h = np.clip(N @ HALF, 0, 1)
                return np.clip(col + ((h ** 30) * 0.08)[..., None], 0, 1)
            self.tube(body, R, R, pal, 0.0, int(r.integers(1000)), tint=sh, rfun=rf)
            tg = nv(body(np.array([0.02]))[0] - c0 + ax0 * 1e-3)
            self.ellip(c0 + tg * 0.006, tg, 0.014, R * 0.8, calp, 0.002, spec=0.04, bulge=0.3)
        if stage == 1:
            for o in spots:
                Hc = r.uniform(0.1, 0.12)
                top = o + np.array([r.normal(0, 0.006), r.normal(0, 0.006), Hc])
                self.tube(self.line_c([o, o + np.array([0, 0, Hc * 0.5]), top]), 0.0065, 0.005, stemp, 0.0, int(r.integers(1000)))
                a0 = r.uniform(0, 6.28)
                for j in range(5):
                    leaf(top - np.array([0, 0, 0.012 * j]), a0 + j * 2.4, r.uniform(0.08, 0.1) * (1.1 - 0.08 * j), up=0.6)
            return
        Hs = 0.46 if stage == 2 else 0.68
        for pi, o in enumerate(spots):
            Hc = Hs * r.uniform(0.94, 1.05)
            top = o + np.array([r.normal(0, 0.008), r.normal(0, 0.008), Hc * 0.45])
            cul = self.line_c([o, o + np.array([0, 0, Hc * 0.25]), top])
            self.tube(cul, 0.016, 0.012, stemp, 0.0, int(r.integers(1000)))
            brs = []
            nb = 3 if stage == 2 else 5
            w1, w2 = (0.07, 0.12) if stage == 2 else (0.11, 0.21)
            for k in range(nb):
                a = k * 6.2832 / nb + r.uniform(0, 0.5) + pi; d = np.array([math.cos(a), math.sin(a) * 0.8, 0.0])
                b1 = top + d * w1 + np.array([0, 0, Hc * 0.25]); b2 = top + d * w2 + np.array([0, 0, Hc * 0.5])
                bc = self.line_c([top, b1, b2]); brs.append((bc, d))
                self.tube(bc, 0.011, 0.006, stemp, 0.0, int(r.integers(1000)))
            a0 = r.uniform(0, 6.28)
            for j in range(4):
                leaf(cul(np.array([0.35 + 0.18 * j]))[0], a0 + j * 2.4, (0.15 if stage == 3 else 0.13) * r.uniform(0.9, 1.08), up=0.25)
            for bi, (bc, d) in enumerate(brs):
                nj = 6 if stage == 2 else 11
                for j in range(nj):
                    t0 = 0.15 + 0.8 * j / nj
                    az = math.atan2(d[1], d[0]) + (1 if j % 2 else -1) * r.uniform(0.6, 1.3)
                    leaf(bc(np.array([t0]))[0], az, (0.19 if stage == 3 else 0.12) * (1.05 - 0.25 * t0) * r.uniform(0.9, 1.08), up=0.3 + 0.3 * t0)
            if stage == 3:      # leafy crown on top of each plant so the bush reads round and full
                for j in range(9):
                    az = r.uniform(0, 6.28); bc, d = brs[j % nb]
                    leaf(bc(np.array([r.uniform(0.75, 1.0)]))[0], az, 0.17 * r.uniform(0.9, 1.1), up=r.uniform(0.3, 0.8))
            front = sorted(brs, key=lambda x: -x[1][1])
            if stage == 2:
                for bi, (bc, d) in enumerate(front):
                    p = bc(np.array([0.55]))[0]; pf = p + d * 0.025 + np.array([0, 0.05, -0.01])
                    self.tube(self.line_c([p, (p + pf) * 0.5 + np.array([0, 0, 0.004]), pf]), 0.0024, 0.002, stemp, 0.0, int(r.integers(1000)))
                    flower(pf, d)
                    if bi < 2: chili(bc(np.array([0.3]))[0], d, 0.13, 0.019, grnp)
                continue
            # stage 3: big red chilies (a couple turning orange) hanging out on the camera side, flowers few
            k = 0
            for bi, (bc, d) in enumerate(front):
                if bi > 3: break
                for t in ((0.3, 0.62) if bi < 2 else (0.5,)):
                    side = nv(np.cross(UP, d)) * (0.02 if k % 2 else -0.02)
                    p = bc(np.array([t]))[0] + side
                    pq = p + d * 0.05 + np.array([0, 0.09, -0.02])      # pulled out in front of the foliage
                    self.tube(self.line_c([p, (p + pq) * 0.5 + np.array([0, 0, 0.012]), pq]), 0.0035, 0.003, stemp, 0.0, int(r.integers(1000)))
                    p = pq
                    chili(p, nv(d + np.array([0, 0.6, 0])), 0.24 * r.uniform(0.94, 1.06), 0.032, orap if (k == 2 and pi == 1) else redp)
                    k += 1

    # ------------------------------------------------------------------ hướng dương
    def _huong_duong(self, seed):
        """sunflower (hướng dương): 3 plants on the bắp spots; a thick hairy stalk with big heart-shaped toothed leaves,
        stage 2 a closed green bud, stage 3 a big golden flower head facing the camera (brown seed disc, ray petals)"""
        r = self.r
        stage = seed % 4
        leafp = H('#1e4a14', '#2a601a', '#3a7822', '#4e902c', '#68a83c', '#90c264')
        und = H('#3e6a2e', '#4e7e3a', '#64944a', '#7caa5c', '#9ec282')
        stemp = H('#355a1c', '#477224', '#5e8c30', '#78a43e', '#9cc060')
        brp = H('#2a4a14', '#36601a', '#467822', '#5a902c', '#76a844')
        ray = dict(base=A_(C('#d88a06')), mid=A_(C('#f6b80e')), tip=A_(C('#ffd23a')), deep=A_(C('#a05a04')), vein=A_(C('#e09a10')))
        spots = self.tri()
        def hleaf(p0, az, L, up=0.1):
            d = np.array([math.cos(az), math.sin(az), 0.0])
            b = p0 + d * L * 0.25 + np.array([0, 0, L * 0.12])
            self.tube(self.line_c([p0, p0 + d * L * 0.12 + np.array([0, 0, L * 0.12]), b]), 0.0055, 0.0045, stemp, 0.0, int(r.integers(1000)))
            e = nv(d + np.array([0, 0, up + r.normal(0, 0.08)]))
            f = nv(np.array([0, 0.35, 1.0]) - d * 0.2)
            self.leaf(b, e, f, L, L * 0.82, leafp, und, droop=r.uniform(0.25, 0.4), fold=0.08, veins=6, gloss=0.05,
                      prof=[0.35, 0.85, 1.0, 0.95, 0.72, 0.38, 0.0], mid_k=0.3, teeth=(9, 0.12, 'saw'))
        def head(c, f, R):
            """the flower head: brown disc with spiralled seeds, two rings of yellow ray petals, green bracts behind"""
            f = nv(f); u, v = basis(f)
            for k in range(14):      # green bracts behind
                a = k * 2 * math.pi / 14; e = nv((math.cos(a) * u + math.sin(a) * v) - f * 0.35)
                self.strap(self.line_c([c - f * 0.02, c - f * 0.03 + e * R * 0.45, c - f * 0.035 + e * R * 0.8]), R * 0.22, brp, 0.0, fold=0.3,
                           wprof=[0.8, 1.0, 0.9, 0.6, 0.3, 0.0], gloss=0.03)
            for ring, (n, L, off) in enumerate(((21, R * 0.95, 0.0), (21, R * 0.82, 0.5))):
                for k in range(n):
                    a = (k + off) * 2 * math.pi / n + r.normal(0, 0.04); e = nv((math.cos(a) * u + math.sin(a) * v) - f * (0.12 + 0.06 * ring))
                    self.petal(c + e * R * 0.48 - f * 0.004 * (1 - ring), f, e, L * r.uniform(0.9, 1.06), L * 0.36, 0.25, ray, 0.002 * ring,
                               prof=[0.45, 0.85, 1.0, 0.9, 0.6, 0.3, 0.0], nveins=4)
            sd = int(r.integers(1000))
            def seeds(col, P, N, A, B):
                rr_ = A; th = B * 2 * math.pi
                ph = (th * 34 / (2 * math.pi) + rr_ * 21) % 1.0; ph2 = (th * 21 / (2 * math.pi) - rr_ * 13) % 1.0
                cell = np.clip(1 - (np.abs(ph - 0.5) + np.abs(ph2 - 0.5)) * 1.6, 0, 1)
                col = col * (0.75 + 0.35 * cell)[..., None]
                return mix(col, A_(C('#c8a030')), np.clip((A - 0.86) / 0.14, 0, 1) * 0.5)      # golden florets at the rim
            self.ellip(c + f * 0.01, f, R * 0.12, R * 0.5, H('#2a1406', '#3e2008', '#5a320e', '#744416', '#8e5a22', '#b07a36'), 0.004, spec=0.03, tint=seeds)
        if stage == 1:
            for o in spots:
                Hc = r.uniform(0.09, 0.11)
                top = o + np.array([0, 0, Hc])
                self.tube(self.line_c([o, o + np.array([0, 0, Hc * 0.5]), top]), 0.0075, 0.0065, stemp, 0.0, int(r.integers(1000)))
                a0 = r.uniform(-0.3, 0.3)
                for s_ in (-1, 1):
                    d = np.array([math.cos(a0) * s_, math.sin(a0) * s_, 0.0])
                    self.leaf(top, nv(d + np.array([0, 0, 0.25])), nv(UP + np.array([0, 0.25, 0])), 0.075, 0.042, leafp, und,
                              droop=0.12, fold=0.06, veins=2, gloss=0.05, prof=[0.0, 0.7, 0.95, 1.0, 0.9, 0.6, 0.0], mid_k=0.4)
                for s_ in (-1, 1):
                    a = a0 + math.pi * 0.5 + (0 if s_ > 0 else math.pi)
                    hleaf(top + np.array([0, 0, 0.012]), a, 0.085, up=0.5)
            return
        for pi, o in enumerate(spots):
            front = o[1] > 0.05
            Hc = (0.56 if stage == 2 else (0.74 if front else 0.92)) * r.uniform(0.96, 1.04)
            top = o + np.array([r.normal(0, 0.006), 0.012, Hc])
            cul = self.line_c([o, o + np.array([0, 0, Hc * 0.5]), top])
            self.tube(cul, 0.02 if stage == 3 else 0.016, 0.013, stemp, 0.0, int(r.integers(1000)))
            nl = 6 if stage == 2 else 8
            a0 = r.uniform(0, 6.28)
            for j in range(nl):
                t0 = 0.12 + 0.8 * j / (nl - 1)
                az = a0 + j * 2.39996
                if math.sin(az) > 0.75 and t0 > 0.6: az += 1.2      # keep the head's face clear
                hleaf(cul(np.array([t0]))[0], az, (0.2 if stage == 3 else 0.17) * (1.1 - 0.4 * t0) * r.uniform(0.9, 1.08), up=0.1 + 0.2 * t0)
            if stage == 2:      # a closed green bud nodding a little toward the camera
                f = nv(np.array([0, 0.5, 1.0]))
                self.ellip(top + f * 0.03, f, 0.035, 0.045, brp, 0.002, spec=0.03, bulge=-0.2)
                u, v = basis(f)
                for k in range(10):
                    a = k * 0.628; e = nv((math.cos(a) * u + math.sin(a) * v) + f * 0.6)
                    self.strap(self.line_c([top + f * 0.01, top + f * 0.035 + e * 0.035, top + f * 0.07 + e * 0.03]), 0.02, brp, 0.002, fold=0.3,
                               wprof=[0.8, 1.0, 0.9, 0.6, 0.3, 0.0], gloss=0.03)
                continue
            f = nv(TOCAM * 0.8 + np.array([(0.25 if o[0] > 0.05 else -0.25 if o[0] < -0.05 else 0), 0, 0.15]))
            neck = top + np.array([0, 0.03, 0.03])
            self.tube(self.line_c([top - np.array([0, 0, 0.04]), top + np.array([0, 0.01, 0.02]), neck]), 0.014, 0.012, stemp, 0.0, int(r.integers(1000)))
            head(neck + f * 0.02, f, 0.15)

    # ------------------------------------------------------------------ xà lách
    def _xa_lach(self, seed):
        """lettuce (xà lách): 3 rosettes on the bắp spots, frilly bright green leaves, paler and more upright inside;
        stage 3 a big loose head"""
        r = self.r
        stage = seed % 4
        outp = H('#2e6416', '#3e7c1c', '#529624', '#6aae32', '#8ac64c', '#b4dc7e')
        inp = H('#5a8a1e', '#70a226', '#8aba34', '#a6d04a', '#c2e270', '#e2f2aa')
        und = H('#6a9a48', '#7eae58', '#94c26c', '#acd484', '#cae6a6')
        spots = self.tri()
        def rib(col, P, N, A, B):
            w = B * 2 - 1
            return mix(col, A_(C('#e8f4c8')), np.exp(-(w / 0.07) ** 2) * 0.55 * (A < 0.85))       # white-green midrib
        n, L0 = {1: (6, 0.12), 2: (11, 0.17)}.get(stage, (30, 0.32))
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            for j in range(n):
                t = j / max(n - 1, 1)          # 0 = outer, 1 = innermost
                az = a0 + j * 2.39996
                d = np.array([math.cos(az), math.sin(az), 0.0])
                L = L0 * (1.0 - 0.3 * t) * r.uniform(0.92, 1.06)
                up = (0.6 + 1.6 * t) if stage < 3 else (0.7 + 2.6 * t)          # outer leaves spread, inner ones stand up and cup into a tall head
                b = o + d * 0.02 * (1 - t) + np.array([0, 0, 0.01 + (0.03 if stage < 3 else 0.07) * t])
                e = nv(d + np.array([0, 0, up]))
                f = nv(UP * (1.0 - 0.6 * t) - d * (0.25 + 0.6 * t) + np.array([0, 0.15, 0]))
                pal = inp if t > 0.55 else outp
                R = L * 0.62
                self.tube(self.line_c([b, b + e * R * 0.2, b + e * R * 0.4]), 0.012 * (1 - 0.4 * t), 0.008, und, 0.0, int(r.integers(1000)))
                self.pleaf(b + e * R * 0.35, e, f, R, pal, und, lobes=3, depth=0.06, spread=0.95, teeth=(70, 0.035),
                           cup=0.12 + 0.2 * t, ruffle=0.11, gloss=0.04, vk=0.45)

    # ------------------------------------------------------------------ cải xanh
    def _cai(self, seed):
        """mustard greens (cải xanh): 3 rosettes on the bắp spots; big spoon-shaped wavy leaves on thick pale-green
        stalks, outer leaves splayed, inner ones upright, pale midribs"""
        r = self.r
        stage = seed % 4
        leafp = H('#1c4a16', '#26601c', '#327824', '#42902e', '#58a63e', '#7cbc5e')
        und = H('#6a9e4a', '#80b25c', '#98c672', '#b2d88c', '#d0eaae')
        stk = H('#6e9a40', '#86b04e', '#a0c662', '#bcda7e', '#d8eca4')
        spots = self.tri()
        def mid(col, P, N, A, B):
            w = B * 2 - 1
            return mix(col, A_(C('#d6eca8')), np.exp(-(w / 0.07) ** 2) * 0.6 * (A < 0.9) * np.clip(1.1 - A, 0, 1))
        n, L0 = {1: (4, 0.12), 2: (8, 0.26)}.get(stage, (12, 0.5))
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            for j in range(n):
                t = j / max(n - 1, 1)           # 0 = outer, 1 = heart
                az = a0 + j * 2.39996
                d = np.array([math.cos(az), math.sin(az), 0.0])
                L = L0 * (1.0 - 0.28 * t) * r.uniform(0.92, 1.06)
                up = 2.2 + 3.0 * t
                e0 = nv(d + np.array([0, 0, up]))
                pl = L * 0.32                   # bare stalk before the blade
                b = o + d * 0.012 + np.array([0, 0, 0.004])
                pt = b + e0 * pl
                self.tube(self.line_c([b, b + e0 * pl * 0.5, pt]), 0.014 * (1 - 0.3 * t) * (L / 0.3) ** 0.5 + 0.003, 0.009 * (L / 0.3) ** 0.5 + 0.002, stk, 0.0, int(r.integers(1000)))
                e = nv(e0 + d * 0.15)
                f = nv(UP * 0.35 - d * 0.8 + np.array([0, 0.25, 0]))
                self.leaf(pt, e, f, L, L * 0.64, leafp, und, droop=0.2 - 0.1 * t, fold=0.035, veins=6, gloss=0.03,
                          prof=lambda t: np.sin(math.pi * np.clip(t, 0, 1) ** 1.5) ** 0.55, mid_k=0.0, tint=mid, teeth=(3.5, 0.03, 'wave'))

    # ------------------------------------------------------------------ dâu tây
    def _dau(self, seed):
        """strawberry (dâu tây): 3 low plants on the bắp spots; trifoliate toothed leaves on hairy stalks, white
        flowers (stage 2), stage 3 big red berries with yellow seeds and a green star calyx, lying out in front"""
        r = self.r
        stage = seed % 4
        leafp = H('#1a4614', '#245e1a', '#317822', '#40922c', '#56aa3a', '#7cc25a')
        und = H('#4a7038', '#5a8246', '#6e9656', '#86ac6c', '#a6c48c')
        stemp = H('#3a5a1c', '#4a6e24', '#5e842e', '#76983a', '#94b252')
        redp = H('#6a0610', '#a00c16', '#d01a22', '#ee3030', '#ff5a48', '#ffa090')
        pinkp = H('#a04838', '#c86a52', '#e48c6c', '#f4b08e', '#fcd2b4', '#fff0dc')
        grp = H('#5a7a2a', '#6e8e34', '#86a640', '#a0bc56', '#c0d47a', '#e2eaa8')
        calp = H('#1e4a12', '#2a6018', '#387820', '#4a9028', '#64a838')
        fl = dict(base=A_(C('#e0e0d2')), mid=A_(C('#f6f6ee')), tip=A_(C('#ffffff')), deep=A_(C('#a8a898')), vein=A_(C('#d0d0c2')))
        spots = self.tri()
        def trif(o, az, reach, hgt, Ll):
            """one leaf: a hairy stalk arching out from the crown, three toothed leaflets spread flat on top"""
            d = np.array([math.cos(az), math.sin(az), 0.0])
            top = o + d * reach + np.array([0, 0, hgt])
            self.tube(self.line_c([o + np.array([0, 0, 0.01]), o + d * reach * 0.3 + np.array([0, 0, hgt * 0.95]), top]), 0.0045, 0.0036, stemp, 0.0, int(r.integers(1000)))
            f = nv(np.array([0, 0.3, 1.0]) + d * 0.3)
            for k, (da, sc) in enumerate(((0.0, 1.0), (1.0, 0.86), (-1.0, 0.86))):
                a = az + da; e = nv(np.array([math.cos(a), math.sin(a), -0.05]))
                self.leaf(top + e * 0.004, e, f, Ll * sc, Ll * sc * 0.78, leafp, und, droop=0.1, fold=0.1, veins=7, gloss=0.04,
                          prof=lambda t: np.sin(math.pi * np.clip(t, 0, 1) ** 1.15) ** 0.6, mid_k=0.25, teeth=(9, 0.08, 'saw'))
        def flower(p):
            f = nv(np.array([0, 0.55, 0.85])); u, v = basis(f)
            for k in range(5):
                a = k * 1.2566; e = nv((math.cos(a) * u + math.sin(a) * v) * 0.95 + f * 0.05)
                self.petal(p, f, e, 0.03, 0.028, -0.05, fl, 0.003, prof=[0.55, 0.9, 1.0, 1.0, 0.85, 0.5, 0.0], nveins=3)
            self.ellip(p + f * 0.004, f, 0.009, 0.005, H('#9a8a10', '#c4b018', '#e8d02c', '#f8e85a'), 0.005, spec=0.04, bulge=0.3)
        def berry(c, ax, L, R, pal, ripe=True):
            """the berry hangs from its calyx at c along ax; widest a third down, rounded to a blunt tip"""
            body = self.line_c([c, c + ax * L * 0.5, c + ax * L])
            def rf(t):
                t = np.clip(t, 0, 1); g = np.clip((t + 0.04) / 0.3, 0, 1)
                return R * np.sin(g * math.pi / 2) ** 0.6 * ((1 - t) / 0.74) ** 0.75 * np.where(t < 0.26, 1.0, 1.0) * 0.98 + 1e-4
            def seeds(col, P, N, A, B):
                g = np.sqrt(((A * L / (R * 0.36)) % 1.0 - 0.5) ** 2 + (((B * 12 + (np.floor(A * L / (R * 0.36)) % 2) * 0.5) % 1.0) - 0.5) ** 2)
                dot = np.clip((0.2 - g) / 0.08, 0, 1) * (A > 0.08) * (A < 0.94)
                pit = np.clip((0.32 - g) / 0.1, 0, 1) * (A > 0.08)
                col = col * (1 - 0.18 * pit)[..., None]
                return mix(col, A_(C('#f2d24a' if ripe else '#e8f0b0')), dot * 0.85)
            self.tube(body, R, R, pal, 0.0, int(r.integers(1000)), tint=seeds, rfun=rf)
            u, v = basis(-ax)
            for k in range(6):
                a = k * 1.047 + r.uniform(-0.15, 0.15); e = nv((math.cos(a) * u + math.sin(a) * v) - ax * 0.25)
                self.leaf(c - ax * 0.004, e, -ax, R * 0.95, R * 0.42, calp, calp, droop=-0.1, fold=0.1, veins=3, gloss=0.03, mid_k=0.15)
            self.tube(self.line_c([c - ax * 0.003, c - ax * 0.02 + np.array([0, 0, 0.012]), c - ax * 0.04 + np.array([0, -0.01, 0.03])]),
                      0.0035, 0.003, stemp, 0.0, int(r.integers(1000)))
        if stage == 1:
            for o in spots:
                a0 = r.uniform(0, 6.28)
                for k in range(3):
                    trif(o, a0 + k * 2.1, 0.03, r.uniform(0.07, 0.085), 0.085)
            return
        # a tall leafy bush (Link: "to cao lên", gđ3 as tall as cà tím): leaves on long stalks, inner ones highest
        nl, R1, Hm, Ll = (13, 0.12, 0.3, 0.135) if stage == 2 else (20, 0.15, 0.5, 0.16)
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            for k in range(nl):
                t = k / (nl - 1)                       # 0 = outer ring, 1 = centre
                reach = R1 * (1.0 - 0.6 * t) * r.uniform(0.85, 1.1)
                hgt = Hm * (0.5 + 0.5 * t) * r.uniform(0.88, 1.06)
                az = a0 + k * 2.39996
                fa = math.atan2(math.sin(az - math.pi / 2), math.cos(az - math.pi / 2))     # angle from straight at camera
                if t < 0.6 and abs(fa) < 0.7: az += (0.75 if fa >= 0 else -0.75)        # keep the front open for the berries
                trif(o, az, reach, hgt, Ll * (1.0 - 0.15 * t) * r.uniform(0.92, 1.06))
            # flowers held up on top of the bush
            for k in range(2 if stage == 2 else 1):
                az = math.pi / 2 + (k - 0.5) * 1.6 + r.normal(0, 0.2); d = np.array([math.cos(az), math.sin(az), 0.0])
                p = o + d * 0.07 + np.array([0, 0, Hm + 0.04])
                self.tube(self.line_c([o + np.array([0, 0, 0.01]), o + d * 0.03 + np.array([0, 0, Hm * 0.8]), p]), 0.003, 0.0026, stemp, 0.0, int(r.integers(1000)))
                flower(p)
            # berries hang on arching stalks out over the front of the bush, clear of the leaves
            if stage == 2:
                hang = [(-0.6, 0.6, grp, 0.08, 0.04, False), (0.6, 0.55, grp, 0.075, 0.038, False)]
            else:
                hang = [(-0.75, 0.48, redp, 0.14, 0.07, True), (0.05, 0.4, redp, 0.15, 0.074, True),
                        (0.75, 0.5, redp, 0.14, 0.07, True), (-0.3, 0.68, pinkp if pi == 1 else redp, 0.12, 0.06, True)]
            for (da, hz, pal, L, R, rp) in hang:
                az = math.pi / 2 + da + r.normal(0, 0.06); d = np.array([math.cos(az), math.sin(az), 0.0])
                c = o + d * (R1 + 0.13) + np.array([0, 0, Hm * hz])
                self.tube(self.line_c([o + np.array([0, 0, 0.01]), o + d * R1 * 0.6 + np.array([0, 0, Hm * hz + 0.06]), c]), 0.0036, 0.003, stemp, 0.0, int(r.integers(1000)))
                berry(c, nv(d * 0.3 + np.array([0, 0, -1.0])), L * r.uniform(0.95, 1.05), R * r.uniform(0.95, 1.05), pal, ripe=rp)

    # ------------------------------------------------------------------ hành lá
    def _hanh(self, seed):
        """scallion (hành lá): 3 clumps on the bắp spots; hollow blue-green tubular leaves standing up and arching out
        at the tips, white shanks at the base"""
        r = self.r
        stage = seed % 4
        lp = H('#1e4a1c', '#285e22', '#36762a', '#469032', '#5ca83e', '#82c060')
        spots = self.tri()
        n, Hh, R0 = {1: (5, 0.15, 0.009), 2: (10, 0.36, 0.012)}.get(stage, (15, 0.66, 0.015))
        def shank(col, P, N, A, B):
            w = np.clip((0.2 - A) / 0.12, 0, 1)
            col = mix(col, A_(C('#eef2dc')), w * 0.92)
            return mix(col, A_(C('#b8d47a')), np.clip(1 - np.abs(A - 0.22) / 0.06, 0, 1) * 0.4)
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            for j in range(n):
                t = j / max(n - 1, 1)
                az = a0 + j * 2.39996
                d = np.array([math.cos(az), math.sin(az) * 0.85, 0.0])
                H_ = Hh * (1.0 - 0.35 * abs(t - 0.4)) * r.uniform(0.86, 1.08)
                lean = 0.12 + 0.3 * (1 - t) * r.uniform(0.7, 1.1)       # outer leaves lean out more
                b = o + d * 0.012 * (j % 3) + np.array([0, 0, 0.0])
                p1 = b + d * H_ * lean * 0.25 + np.array([0, 0, H_ * 0.45])
                p2 = b + d * H_ * lean * 0.7 + np.array([0, 0, H_ * 0.85])
                p3 = b + d * H_ * lean * 1.5 + np.array([0, 0, H_ * (0.95 - 0.25 * lean)])     # tip arches over
                cv = self.line_c([b, p1, p2, p3])
                R = R0 * r.uniform(0.85, 1.1)
                def rf(tt, R=R): return R * (1.25 - 0.25 * np.clip(tt / 0.2, 0, 1)) * np.clip((1 - tt) / 0.25, 0.08, 1) ** 0.7 + 1e-4
                self.tube(cv, R, R, lp, 0.0, int(r.integers(1000)), tint=shank, rfun=rf, zcut=0.0)

    # ------------------------------------------------------------------ hành tây
    def _hanh_tay(self, seed):
        """onion (hành tây): 3 plants on the bắp spots; a few thick hollow blue-green leaves fanning up from a BIG
        papery golden-brown bulb that sits half out of the soil in front (Link: củ to, nổi bật)"""
        r = self.r
        stage = seed % 4
        lp = H('#1c4426', '#265a30', '#32723a', '#428a46', '#5aa258', '#86c07c')
        skin = H('#5a2c0c', '#844414', '#a8621e', '#c8842e', '#e0a64a', '#f4d08a')
        spots = self.tri()
        n, Hh, R0, RB = {1: (3, 0.16, 0.009, 0.0), 2: (6, 0.4, 0.014, 0.065)}.get(stage, (7, 0.56, 0.017, 0.11))
        def papery(col, P, N, A, B):
            st = np.abs(np.sin(B * 2 * math.pi * 7 + A * 1.5))
            col = col * (0.9 + 0.1 * st)[..., None]
            return mix(col, A_(C('#6e8a3a')), np.clip((A - 0.8) / 0.12, 0, 1) * 0.85)      # the neck turns green into the leaves
        def shank(col, P, N, A, B):
            return mix(col, A_(C('#d8e6c0')), np.clip((0.12 - A) / 0.1, 0, 1) * 0.8)
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            z0 = 0.0
            if RB:
                # the bulb: an onion shape (flattened sphere drawn up into a neck), half above the ground
                c = o + np.array([0, 0.02, RB * 0.7])
                bulb = self.line_c([c - UP * RB * 0.95, c, c + UP * RB * 1.15])
                def rf(t, RB=RB):
                    t = np.clip(t, 0, 1)
                    sph = np.sqrt(np.clip(1 - ((t - 0.44) / 0.44) ** 2, 0, 1)) ** 0.85
                    return RB * np.maximum(sph, 0.2 * np.clip((1 - t) / 0.2, 0, 1) * (t > 0.6)) + 1e-4
                self.tube(bulb, RB, RB, skin, 0.0, int(r.integers(1000)), tint=papery, rfun=rf, zcut=0.0)
                z0 = RB * 0.7 + RB * 1.05
            for j in range(n):
                t = j / max(n - 1, 1)
                az = a0 + j * 2.39996
                d = np.array([math.cos(az), math.sin(az) * 0.85, 0.0])
                if RB and math.sin(az) > 0.55: d = np.array([math.cos(az) * 1.6, 0.25, 0.0]); d = d / np.linalg.norm(d)    # keep the bulb's face clear
                H_ = Hh * (1.0 - 0.3 * abs(t - 0.4)) * r.uniform(0.88, 1.06)
                lean = 0.15 + 0.35 * (1 - t) * r.uniform(0.7, 1.1)
                b = o + np.array([0, 0.02, z0 * 0.97])
                p1 = b + d * H_ * lean * 0.2 + np.array([0, 0, H_ * 0.45])
                p2 = b + d * H_ * lean * 0.65 + np.array([0, 0, H_ * 0.82])
                p3 = b + d * H_ * lean * 1.4 + np.array([0, 0, H_ * (0.92 - 0.3 * lean)])
                R = R0 * r.uniform(0.88, 1.08)
                def rfl(tt, R=R): return R * np.clip((1 - tt) / 0.3, 0.06, 1) ** 0.7 + 1e-4
                self.tube(self.line_c([b, p1, p2, p3]), R, R, lp, 0.0, int(r.integers(1000)), tint=shank, rfun=rfl, zcut=0.0)

    # ------------------------------------------------------------------ rau muống
    def _rau_muong(self, seed):
        """water spinach (rau muống) grown on land: 3 upright clumps of hollow green stems, long arrow-shaped leaves
        on short stalks all the way up, tender pale tips"""
        r = self.r
        stage = seed % 4
        leafp = H('#173e12', '#1f5418', '#2a6c20', '#38862a', '#4e9e38', '#72b658')
        und = H('#5e9446', '#72a858', '#8abc6c', '#a6d086', '#c6e4a8')
        stemp = H('#4e7e2e', '#629436', '#7aac44', '#96c458', '#badc80')
        spots = self.tri()
        ns, Hs, nl, Ll = {1: (2, 0.12, 3, 0.08), 2: (5, 0.32, 5, 0.15)}.get(stage, (7, 0.5, 6, 0.2))
        arrow = lambda t: np.clip(np.sin(math.pi * np.clip(t, 0, 1) ** 0.75) ** 0.7 * (0.75 + 0.6 * np.exp(-((t - 0.06) / 0.07) ** 2)), 0, 1)
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            for k in range(ns):
                az = a0 + k * 2.39996; d = np.array([math.cos(az), math.sin(az) * 0.85, 0.0])
                H_ = Hs * r.uniform(0.85, 1.08) * (1.0 if k else 1.05)
                lean = r.uniform(0.12, 0.3)
                b = o + d * 0.01
                cv = self.line_c([b, b + d * H_ * lean * 0.3 + np.array([0, 0, H_ * 0.5]), b + d * H_ * lean + np.array([0, 0, H_])])
                self.tube(cv, 0.01 if stage > 1 else 0.006, 0.0065, stemp, 0.0, int(r.integers(1000)), node=0.08)
                for j in range(nl):
                    tq = 0.25 + 0.75 * j / max(nl - 1, 1)
                    p = cv(np.array([tq]))[0]
                    la = az + (1 if j % 2 else -1) * r.uniform(0.8, 1.4)
                    e0 = np.array([math.cos(la), math.sin(la), 0.0])
                    pb = p + e0 * 0.02 + np.array([0, 0, 0.012])
                    self.tube(self.line_c([p, p + e0 * 0.01 + np.array([0, 0, 0.008]), pb]), 0.0028, 0.0024, stemp, 0.0, int(r.integers(1000)))
                    e = nv(e0 + np.array([0, 0, 0.5 + 0.6 * tq]))
                    f = nv(np.array([0, 0.45, 1.0]) - e0 * 0.2)
                    L = Ll * (1.1 - 0.35 * tq) * r.uniform(0.9, 1.08)
                    self.leaf(pb, e, f, L, L * 0.46, leafp, und, droop=0.28, fold=0.1, veins=6, gloss=0.04,
                              prof=arrow, mid_k=0.3)

    # ------------------------------------------------------------------ rau răm
    def _rau_ram(self, seed):
        """Vietnamese coriander (rau răm): 3 bushy clumps of jointed red-purple stems with narrow pointed leaves,
        each leaf with the dark maroon chevron in the middle"""
        r = self.r
        stage = seed % 4
        leafp = H('#1c4614', '#265c1a', '#327422', '#428c2c', '#58a43a', '#7cbc5a')
        und = H('#5a8a44', '#6e9e56', '#86b26a', '#a2c684', '#c2dca6')
        stemp = H('#4a1a20', '#6a2a2c', '#8a3c36', '#a85646', '#c47a5e')
        spots = self.tri()
        def mark(col, P, N, A, B):
            w = np.abs(B * 2 - 1)
            ch = np.exp(-((A - 0.36 - 0.18 * w) / 0.07) ** 2) * (w < 0.7) * np.clip((0.75 - w) / 0.2, 0, 1)
            return mix(col, A_(C('#4a1c22')), ch * 0.7)
        lance = lambda t: np.sin(math.pi * np.clip(t, 0, 1) ** 0.85) ** 0.75
        ns, Hs, nl, Ll = {1: (3, 0.11, 4, 0.075), 2: (7, 0.3, 8, 0.13)}.get(stage, (10, 0.46, 11, 0.165))
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            for k in range(ns):
                az = a0 + k * 2.39996; d = np.array([math.cos(az), math.sin(az) * 0.85, 0.0])
                H_ = Hs * r.uniform(0.85, 1.08)
                lean = r.uniform(0.25, 0.5)            # stems sprawl out a little and turn up
                b = o
                cv = self.line_c([b, b + d * H_ * lean * 0.6 + np.array([0, 0, H_ * 0.35]), b + d * H_ * lean + np.array([0, 0, H_])])
                self.tube(cv, 0.0065 if stage > 1 else 0.0045, 0.004, stemp, 0.0, int(r.integers(1000)), node=0.05, node_col=A_(C('#3a1218')))
                for j in range(nl):
                    tq = 0.2 + 0.8 * j / max(nl - 1, 1)
                    p = cv(np.array([tq]))[0]
                    la = az + (1 if j % 2 else -1) * r.uniform(0.7, 1.3)
                    e = nv(np.array([math.cos(la), math.sin(la), 0.15 + 0.4 * tq]))
                    f = nv(np.array([0, 0.55, 1.0]))
                    L = Ll * (1.05 - 0.3 * tq) * r.uniform(0.9, 1.08)
                    self.leaf(p, e, f, L, L * 0.34, leafp, und, droop=0.22, fold=0.12, veins=7, gloss=0.04,
                              prof=lance, mid_k=0.25, tint=mark)

    # ------------------------------------------------------------------ sả
    def _sa(self, seed):
        """lemongrass (sả): 3 dense clumps on the bắp spots; thick pale stalks blushed purple at the foot, long
        narrow blue-green blades arching out and over from the top of the stalks"""
        r = self.r
        stage = seed % 4
        leafp = H('#2a5a2a', '#346e30', '#42843a', '#549a46', '#6eb05a', '#98c880')
        stk = H('#6e7a4a', '#8a9658', '#a8b06c', '#c4c884', '#dcdca4', '#f0eecc')
        dtip = (A_(C('#9a9a4e')), A_(C('#c8c48a')))
        spots = self.tri()
        def foot(col, P, N, A, B):
            return mix(col, A_(C('#8a4a6a')), np.clip((0.35 - A) / 0.3, 0, 1) * 0.55)
        ns, Hs, Lb, W = {1: (3, 0.04, 0.2, 0.018), 2: (6, 0.12, 0.36, 0.024)}.get(stage, (9, 0.2, 0.5, 0.028))
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            for k in range(ns):
                az = a0 + k * 2.39996; d = np.array([math.cos(az), math.sin(az) * 0.85, 0.0])
                b = o + d * 0.012 * (k % 3)
                top = b + d * 0.01 + np.array([0, 0, Hs * r.uniform(0.85, 1.1)])
                if stage > 1:
                    self.tube(self.line_c([b, (b + top) * 0.5, top]), 0.012 if stage == 3 else 0.009, 0.009, stk, 0.0, int(r.integers(1000)), tint=foot, zcut=0.0)
                for j in range(2 if stage == 1 else 3):
                    ba = az + (j - 1) * r.uniform(0.35, 0.6)
                    db = np.array([math.cos(ba), math.sin(ba), 0.0])
                    L = Lb * r.uniform(0.85, 1.08) * (1.0 - 0.12 * j)
                    up = r.uniform(1.5, 2.2)
                    p0 = top - np.array([0, 0, 0.01])
                    p1 = p0 + db * L * 0.12 + np.array([0, 0, L * up * 0.4])
                    p2 = p0 + db * L * 0.42 + np.array([0, 0, L * up * 0.48])
                    p3 = p0 + db * L * 0.8 + np.array([0, 0, L * up * 0.32])
                    self.strap(self.line_c([p0, p1, p2, p3]), W * r.uniform(0.9, 1.1), leafp, 0.0, fold=0.25, vein_n=5,
                               wprof=[0.6, 0.9, 1.0, 0.8, 0.45, 0.0], gloss=0.06, tipcol=dtip if stage == 3 else None,
                               tipk=r.uniform(0.9, 0.96) if stage == 3 else 0.0)

    # ------------------------------------------------------------------ gừng / nghệ
    def _rhizome(self, o, az, n, R, skin, flesh=None):
        """a knobbly rhizome (củ gừng / nghệ) lying half out of the soil in front: a few plump fingers branching
        off a main body, ringed with leaf scars, tips blushed; flesh shown on one broken finger end"""
        r = self.r
        d = np.array([math.cos(az), math.sin(az), 0.0]); s = nv(np.cross(UP, d))
        def rings(col, P, N, A, B):
            ph = (A * 7.0) % 1.0
            col = col * (1 - 0.22 * np.exp(-((ph - 0.5) / 0.05) ** 2))[..., None]
            n_ = vnoise(P[..., 0] / (R * 0.5), P[..., 1] / (R * 0.5), 7)
            return col * (0.9 + 0.12 * n_)[..., None]
        def fleshy(col, P, N, A, B):
            col = rings(col, P, N, A, B)
            if flesh is None: return col
            return mix(col, flesh, np.clip((A - 0.9) / 0.06, 0, 1))
        c0 = o + np.array([0, 0, R * 0.6])
        body = self.line_c([c0 - s * R * 1.2, c0, c0 + s * R * 1.2])
        self.tube(body, R, R, skin, 0.0, int(r.integers(1000)), tint=rings, rfun=lambda t: R * (0.75 + 0.25 * np.sin(np.clip(t, 0, 1) * math.pi)) * np.sqrt(np.clip(np.sin(np.clip(t, 0, 1) * math.pi), 0, 1)) ** 0.4 + 1e-4, zcut=0.0)
        for k in range(n):
            u = -0.9 + 1.8 * k / max(n - 1, 1)
            st = c0 + s * R * 1.1 * u
            dk = nv(d * 1.0 + s * u * 1.1 + np.array([0, 0, 0.45]))
            L = R * r.uniform(1.4, 1.8)
            fing = self.line_c([st, st + dk * L * 0.5 + np.array([0, 0, R * 0.08]), st + dk * L])
            Rk = R * r.uniform(0.75, 0.88)
            self.tube(fing, Rk, Rk, skin, 0.0, int(r.integers(1000)), tint=fleshy if k == n // 2 else rings,
                      rfun=lambda t, Rk=Rk: Rk * (0.8 + 0.2 * np.sin(np.clip(t, 0, 1) * math.pi * 2)) * np.sqrt(np.clip(1 - (np.clip(t, 0, 1) - 0.0) ** 6, 0, 1)) + 1e-4, zcut=0.0)
        return c0

    def _ginger_hand(self, o, R, skin, stage):
        """a ginger 'hand' lying flat on the soil: a chain of plump flattened knobs branching sideways and forward,
        thin brown rings round each, the young knob tips blushed pink with a pointed bud"""
        r = self.r; sd = int(r.integers(1000))
        def rings(col, P, N, A, B):
            n_ = vnoise(P[..., 0] / (R * 0.35), P[..., 1] / (R * 0.35), sd)
            ring = np.exp(-((((P[..., 0] * 9 / R + P[..., 1] * 3 / R) % 1.0) - 0.5) / 0.06) ** 2)
            col = col * (0.88 + 0.16 * n_ - 0.12 * ring)[..., None]
            return mix(col, A_(C('#6a5030')), np.clip((0.012 - P[..., 2]) / 0.02, 0, 1) * 0.35)
        pink = H('#a8586a', '#c47486', '#dc96a4', '#eebcc4')
        # main body across the front, two knobs each side turned forward, one more forward in the middle
        knobs = [((0.0, 0.0), 0.15, 1.0), ((-0.85, 0.12), 0.55, 0.85), ((0.85, 0.08), -0.5, 0.88), ((-1.4, 0.62), 1.15, 0.7),
                 ((1.4, 0.58), -1.05, 0.72), ((0.2, 0.75), 1.45, 0.72), ((-0.55, 0.85), 1.9, 0.6)][: (7 if stage == 3 else 4)]
        for (kx, ky), ang, sc in knobs:
            c = o + np.array([kx * R, ky * R, R * 0.38 * sc])
            ax = nv(np.array([math.cos(ang), math.sin(ang), 0.0]))
            self.ellip(c, ax, R * 0.78 * sc, R * 0.44 * sc, skin, 0.0, spec=0.02, tint=rings, bulge=0.12)      # knobs overlap into one hand
            if ky > 0.5:
                bt = c + ax * R * 0.6 * sc + np.array([0, 0, R * 0.25 * sc])
                self.ellip(bt, nv(np.array([0, 0.5, 1.0])), R * 0.26 * sc, R * 0.14 * sc, pink, 0.0, spec=0.02)

    def _gingerlike(self, seed, kind):
        r = self.r
        stage = seed % 4
        spots = self.tri()
        if kind == 'gung':
            leafp = H('#1e4a16', '#28601c', '#357824', '#46902e', '#5ea83c', '#86c060')
            und = H('#5e8e48', '#72a25a', '#8ab66e', '#a6ca88', '#c6e0aa')
            stemp = H('#3e6a24', '#4e7e2c', '#649636', '#7eae44', '#a0c864')
            skin = H('#6a4a24', '#8a6430', '#a8803e', '#c49e56', '#dcbc78', '#f0dca8')
            flesh = None; RZ = 0.09
        else:
            leafp = H('#1c4a1a', '#245e20', '#307628', '#3e8e32', '#54a640', '#7cbe62')
            und = H('#5a8c4a', '#6ea05c', '#86b470', '#a2c88a', '#c2deac')
            stemp = H('#3a6a26', '#4a7e2e', '#5e9638', '#78ae46', '#9ac866')
            skin = H('#6a3a14', '#8c5018', '#ae6a20', '#cc8a2e', '#e2aa4c', '#f4cc80')
            flesh = A_(C('#ff9a10')); RZ = 0.078
        if kind == 'gung':      # ginger: slim reed-like pseudostems, narrow leaves in two rows up the stem
            ns, Hs, nl, Ll = {1: (2, 0.12, 4, 0.07), 2: (4, 0.36, 7, 0.13)}.get(stage, (5, 0.56, 9, 0.16))
            lance = lambda t: np.sin(math.pi * np.clip(t, 0, 1) ** 0.8) ** 0.8
            for pi, o in enumerate(spots):
                a0 = r.uniform(0, 6.28)
                for k in range(ns):
                    az = a0 + k * 2.39996; d = np.array([math.cos(az), math.sin(az) * 0.8, 0.0])
                    b = o + d * 0.02 + np.array([0, -0.02, 0])
                    H_ = Hs * r.uniform(0.85, 1.08)
                    cv = self.line_c([b, b + d * H_ * 0.08 + np.array([0, 0, H_ * 0.5]), b + d * H_ * 0.2 + np.array([0, 0, H_])])
                    self.tube(cv, 0.008 if stage > 1 else 0.005, 0.005, stemp, 0.0, int(r.integers(1000)), node=0.06)
                    ra = az + math.pi / 2 + r.normal(0, 0.2)        # the two ranks of leaves
                    for j in range(nl):
                        tq = 0.3 + 0.7 * j / max(nl - 1, 1)
                        p = cv(np.array([tq]))[0]
                        la = ra + (0 if j % 2 else math.pi)
                        e = nv(np.array([math.cos(la), math.sin(la), 0.35 + 0.4 * tq]))
                        f = nv(np.array([0, 0.5, 1.0]))
                        L = Ll * (1.05 - 0.25 * tq) * r.uniform(0.9, 1.08)
                        self.leaf(p, e, f, L, L * 0.24, leafp, und, droop=0.3, fold=0.1, veins=8, gloss=0.04, prof=lance, mid_k=0.25)
                if stage > 1:
                    self._ginger_hand(o + np.array([0, 0.07, 0]), RZ * (1.0 if stage == 3 else 0.62), skin, stage)
        else:                   # turmeric: a few big broad leaves on long stalks standing up from the base
            nl, Hs, Ll = {1: (2, 0.06, 0.1), 2: (4, 0.14, 0.24)}.get(stage, (6, 0.18, 0.34))
            broad = lambda t: np.sin(math.pi * np.clip(t, 0, 1) ** 0.95) ** 0.6
            for pi, o in enumerate(spots):
                a0 = r.uniform(0, 6.28)
                for j in range(nl):
                    az = a0 + j * 2.39996
                    if stage > 1 and math.sin(az) > 0.6: az += 1.2           # keep the front open for the rhizome
                    d = np.array([math.cos(az), math.sin(az) * 0.8, 0.0])
                    H_ = Hs * r.uniform(0.85, 1.1)
                    b = o + np.array([0, -0.02, 0])
                    pt = b + d * 0.02 + np.array([0, 0, H_])
                    self.tube(self.line_c([b, (b + pt) * 0.5, pt]), 0.009 if stage > 1 else 0.006, 0.006, stemp, 0.0, int(r.integers(1000)))
                    e = nv(d * 0.35 + np.array([0, 0, 1.0]))
                    f = nv(np.array([0, 0.6, 0.3]) - d * 0.5)
                    L = Ll * r.uniform(0.9, 1.08)
                    self.leaf(pt, e, f, L, L * 0.4, leafp, und, droop=0.32, fold=0.12, veins=12, gloss=0.04, prof=broad, mid_k=0.35)
                if stage > 1:
                    self._rhizome(o + np.array([0, 0.08, 0]), math.pi / 2, 3 if stage == 3 else 2, RZ * (1.0 if stage == 3 else 0.62), skin, flesh)

    def _gung(self, seed):
        """ginger (gừng): 3 clumps of slim leafy stems; a BIG knobbly tan rhizome showing in front (gđ2-3)"""
        self._gingerlike(seed, 'gung')

    def _nghe(self, seed):
        """turmeric (nghệ): 3 clumps of big broad upright leaves; a BIG orange-brown rhizome in front, one broken end
        showing the bright orange flesh"""
        self._gingerlike(seed, 'nghe')

    # ------------------------------------------------------------------ đậu / mè (pods)
    def _pod(self, p, ax, L, R, pal, nb=3, hairy=0.0, curve=None, seeds=None, bump=0.22):
        """a bean pod (or sesame capsule) from p along ax: bulging over each seed, pointed tip, optional fuzz"""
        r = self.r
        bend = curve if curve is not None else nv(np.cross(ax, UP) + 1e-6) * L * 0.12
        cf = self.line_c([p, p + ax * L * 0.5 + bend * 0.6, p + ax * L + bend])
        def rf(t):
            t = np.clip(t, 0, 1)
            env = np.clip(t / 0.08, 0, 1) ** 0.6 * np.clip((1 - t) / 0.16, 0, 1) ** 0.8
            return R * env * (1 - bump + bump * np.abs(np.sin(math.pi * nb * (t - 0.04) / 0.9))) + 1e-4
        def fuzz(col, P, N, A, B):
            if seeds is not None:      # dry pod skin with the dark beans showing through over each bulge
                bl = np.abs(np.sin(math.pi * nb * (np.clip(A, 0, 1) - 0.04) / 0.9)) ** 6 * np.clip(A / 0.1, 0, 1) * np.clip((1 - A) / 0.18, 0, 1)
                col = mix(col, seeds, bl * 0.3)
            if not hairy: return col
            n_ = vnoise(P[..., 0] / 0.003, P[..., 1] / 0.003, 5)
            rim = 1 - np.abs(N @ TOCAM)
            return mix(col, A_(C('#e8dcb0')), np.clip(hairy * (0.35 * rim + 0.25 * n_), 0, 1))
        self.tube(cf, R, R, pal, 0.0, int(r.integers(1000)), tint=fuzz, rfun=rf)

    def _trifol(self, top, az, Ll, leafp, und, stemp, pointed=0.0, up=0.15):
        r = self.r
        f = nv(np.array([0, 0.45, 1.0]) + np.array([math.cos(az), math.sin(az), 0]) * 0.25)
        prof = (lambda t: np.sin(math.pi * np.clip(t, 0, 1) ** (1.05 + 0.5 * pointed)) ** (0.6 + 0.3 * pointed))
        for k, (da, sc) in enumerate(((0.0, 1.0), (1.15, 0.82), (-1.15, 0.82))):
            a = az + da; e = nv(np.array([math.cos(a), math.sin(a), up]))
            b = top + e * (0.012 if k == 0 else 0.0)
            self.leaf(b, e, f, Ll * sc, Ll * sc * (0.58 - 0.12 * pointed), leafp, und, droop=0.18, fold=0.12, veins=7, gloss=0.04,
                      prof=prof, mid_k=0.28)

    def _legume(self, seed, kind):
        """soybean (đậu nành) / mung bean (đậu xanh): 3 bushy plants of trifoliate leaves on branching stems;
        stage 2 small flowers, stage 3 clusters of BIG pods held out in front of the leaves"""
        r = self.r
        stage = seed % 4
        spots = self.tri()
        if kind == 'dau_nanh':
            leafp = H('#22501a', '#2c6620', '#3a7e28', '#4c9632', '#64ac40', '#8cc464')
            podp = H('#4a4a18', '#646222', '#7e7c2e', '#98963e', '#b2ae56', '#ccc67e')
            podp2 = H('#4a6a1c', '#5e8424', '#76a030', '#90b840', '#acd05c', '#d0e88e')
            flc = dict(base=A_(C('#b090c8')), mid=A_(C('#d0b4e4')), tip=A_(C('#f0e4f8')), deep=A_(C('#7a5a96')), vein=A_(C('#a080bc')))
            pointed, hairy, PL, PR, nb = 0.0, 0.55, 0.105, 0.022, 3
        elif kind == 'dau_den':      # black-seeded cowpea: broad leaves, long straw-brown ripe pods with the black beans showing
            leafp = H('#1c4616', '#265c1c', '#327424', '#428c2c', '#58a43a', '#80bc5e')
            podp = H('#3e2c16', '#5c4424', '#7c5e34', '#9c7c48', '#b89a60', '#d2b87e')
            podp2 = H('#3a6418', '#4e7e20', '#64982a', '#7eb238', '#9ccc56', '#c4e48a')
            flc = dict(base=A_(C('#8a6ab8')), mid=A_(C('#b49ad8')), tip=A_(C('#e6dcf4')), deep=A_(C('#5a428a')), vein=A_(C('#9a80c8')))
            pointed, hairy, PL, PR, nb = 0.35, 0.0, 0.27, 0.011, 9
        else:
            leafp = H('#1e4c18', '#28621e', '#347a26', '#46922e', '#5eaa3c', '#86c262')
            podp = H('#101010', '#1e1c1a', '#2e2a26', '#423c36', '#5a524a', '#7a7068')
            podp2 = H('#3e6a1a', '#528420', '#6aa02a', '#84b83a', '#a2d058', '#c8e68c')
            flc = dict(base=A_(C('#c8b020')), mid=A_(C('#e8d040')), tip=A_(C('#fff09a')), deep=A_(C('#8a7810')), vein=A_(C('#d0b830')))
            pointed, hairy, PL, PR, nb = 0.6, 0.0, 0.18, 0.018, 6
        und = H('#5e8c48', '#72a05a', '#8ab46e', '#a6c888', '#c6deaa')
        stemp = H('#3e6224', '#4e762c', '#648e36', '#7ea644', '#a0c264')
        LK = 1.15 if kind == 'dau_den' else 1.0
        if stage == 1:
            for o in spots:
                top = o + np.array([0, 0, 0.09])
                self.tube(self.line_c([o, o + np.array([0, 0, 0.05]), top]), 0.005, 0.004, stemp, 0.0, int(r.integers(1000)))
                a0 = r.uniform(0, 6.28)
                for k in range(2):      # the first pair of simple leaves, then one trifoliate
                    a = a0 + k * math.pi; e = nv(np.array([math.cos(a), math.sin(a), 0.3]))
                    self.leaf(top, e, nv(np.array([0, 0.4, 1.0])), 0.06, 0.04, leafp, und, droop=0.1, fold=0.1, veins=5, gloss=0.04,
                              prof=lambda t: np.sin(math.pi * np.clip(t, 0, 1)) ** 0.6, mid_k=0.25)
                self._trifol(top + np.array([0, 0, 0.03]), a0 + 1.57, 0.06, leafp, und, stemp, pointed, up=0.6)
            return
        Hs, nbr, Ll = (0.3, 4, 0.1) if stage == 2 else (0.46, 6, 0.125)
        Ll *= LK
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            top0 = o + np.array([0, 0, Hs * 0.35])
            self.tube(self.line_c([o, o + np.array([0, 0, Hs * 0.2]), top0]), 0.012, 0.01, stemp, 0.0, int(r.integers(1000)))
            fronts = []
            for k in range(nbr):
                az = a0 + k * 2.39996; d = np.array([math.cos(az), math.sin(az) * 0.85, 0.0])
                h = Hs * r.uniform(0.75, 1.0)
                tip = top0 + d * Hs * 0.35 + np.array([0, 0, h - Hs * 0.35])
                bc = self.line_c([top0, top0 + d * Hs * 0.12 + np.array([0, 0, (h - Hs * 0.35) * 0.6]), tip])
                self.tube(bc, 0.007, 0.004, stemp, 0.0, int(r.integers(1000)))
                for j in range(3):
                    tq = 0.4 + 0.3 * j
                    p = bc(np.array([tq]))[0]; la = az + (1 if j % 2 else -1) * 0.9
                    dl = np.array([math.cos(la), math.sin(la), 0.0])
                    pt = p + dl * 0.05 + np.array([0, 0, 0.04])
                    self.tube(self.line_c([p, p + dl * 0.02 + np.array([0, 0, 0.03]), pt]), 0.003, 0.0025, stemp, 0.0, int(r.integers(1000)))
                    self._trifol(pt, la, Ll * r.uniform(0.9, 1.08), leafp, und, stemp, pointed)
                self._trifol(tip, az, Ll * 0.9, leafp, und, stemp, pointed, up=0.5)
                if math.sin(az) > -0.2: fronts.append((bc, d, az))
            fronts = sorted(fronts, key=lambda x: -x[1][1])[:3]
            for bi, (bc, d, az) in enumerate(fronts):
                if stage == 2:
                    p = bc(np.array([0.45 if kind == 'dau_nanh' else 0.7]))[0]
                    out = nv(d + np.array([0, 0.9, 0]))
                    c = p + out * 0.1 + np.array([0, 0, -0.01])
                    self.tube(self.line_c([p, (p + c) * 0.5 + np.array([0, 0, 0.01]), c]), 0.003, 0.0026, stemp, 0.0, int(r.integers(1000)))
                    for k in range(3):
                        u, v = basis(out)
                        e = nv(out + (math.cos(k * 2.1) * u + math.sin(k * 2.1) * v) * 0.6 + np.array([0, 0, 0.4]))
                        q = c + e * 0.012
                        ff = nv(e + np.array([0, 0.5, 0]))
                        for m in range(2):
                            self.petal(q, ff, nv(e + UP * (0.6 if m == 0 else -0.2)), 0.03, 0.026, 0.25, flc, 0.002, nveins=3)
                    continue
                out = nv(d + np.array([0, 0.9, 0]))
                side = nv(np.cross(UP, out))
                if kind == 'dau_nanh':
                    # soybean: short fuzzy pods in tight clusters of 3 right at the nodes up the branch, pointing out and down
                    for m, tq in enumerate((0.5, 0.68, 0.86)):
                        c = bc(np.array([tq]))[0] + out * 0.03
                        for k in range(3):
                            ang = (k - 1) * 0.9 + r.normal(0, 0.12)
                            ax = nv(out * 0.95 + side * ang * 0.6 + np.array([0, 0, -0.35]))
                            pal = podp2 if (k + m + bi) % 4 == 0 else podp
                            self._pod(c, ax, PL * r.uniform(0.9, 1.08), PR * r.uniform(0.95, 1.05), pal, nb=nb, hairy=hairy, bump=0.22)
                    continue
                # long slender pods hanging in pairs (đậu xanh black when ripe, đậu đen straw with the beans showing)
                p = bc(np.array([0.7]))[0]
                c = p + out * 0.1 + np.array([0, 0, -0.01])
                self.tube(self.line_c([p, (p + c) * 0.5 + np.array([0, 0, 0.01]), c]), 0.003, 0.0026, stemp, 0.0, int(r.integers(1000)))
                for k in range(2 if kind == 'dau_den' else 3):
                    ang = -1.0 + 1.0 * k + (0.5 if kind == 'dau_den' else 0.0)
                    ax = nv(out * 0.25 + side * ang * 0.3 + np.array([0, 0, -1.0]))
                    pal = podp2 if (k == 1 and bi == 0) or (kind != 'dau_nanh' and k == 2) else podp
                    self._pod(c, ax, PL * r.uniform(0.92, 1.06), PR * r.uniform(0.95, 1.05), pal, nb=nb, hairy=hairy, curve=out * (0.03 if kind == 'dau_den' else 0.02),
                              seeds=A_(C('#141018')) if kind == 'dau_den' and pal is podp else None, bump=0.16 if kind == 'dau_den' else 0.22)

    def _dau_nanh(self, seed):
        self._legume(seed, 'dau_nanh')

    def _dau_xanh(self, seed):
        self._legume(seed, 'dau_xanh')

    def _dau_den(self, seed):
        self._legume(seed, 'dau_den')

    def _me(self, seed):
        """sesame (mè): 3 upright single-stemmed plants; opposite lance leaves, pale pink-white bell flowers up the
        stem (stage 2-3) and BIG four-sided green capsules standing up the stem in front (stage 3)"""
        r = self.r
        stage = seed % 4
        leafp = H('#22501a', '#2c6820', '#3a8028', '#4c9832', '#64ae40', '#8cc664')
        und = H('#5e8c48', '#72a05a', '#8ab46e', '#a6c888', '#c6deaa')
        stemp = H('#3e6224', '#4e762c', '#648e36', '#7ea644', '#a0c264')
        capp = H('#3a5a1a', '#4c7220', '#628c2a', '#7aa438', '#98bc52', '#c0d886')
        capb = H('#5a3a14', '#7a5220', '#9a6c30', '#b88a48', '#d2aa6c', '#ecd0a0')
        flc = dict(base=A_(C('#d8b4c4')), mid=A_(C('#f0dce6')), tip=A_(C('#fff8fc')), deep=A_(C('#a87c90')), vein=A_(C('#d4a6bc')))
        lance = lambda t: np.sin(math.pi * np.clip(t, 0, 1) ** 0.9) ** 0.75
        spots = self.tri()
        ns, Hs, nl, Ll = {1: (1, 0.1, 2, 0.07), 2: (3, 0.38, 4, 0.14)}.get(stage, (3, 0.6, 5, 0.16))
        def bell(p, d):
            e = nv(d + np.array([0, 0.4, -0.25]))
            u, v = basis(e)
            for k in range(5):
                a = k * 1.2566; ee = nv(e + (math.cos(a) * u + math.sin(a) * v) * 0.45)
                self.petal(p, nv(math.cos(a) * u + math.sin(a) * v), ee, 0.04, 0.026, -0.15, flc, 0.002, nveins=3)
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            for k in range(ns):
                az = a0 + k * 2.094; d = np.array([math.cos(az), math.sin(az) * 0.8, 0.0])
                b = o + d * (0.035 if ns > 1 else 0.0)
                H_ = Hs * r.uniform(0.9, 1.06) * (1.0 if k == 0 else 0.86)
                cv = self.line_c([b, b + d * 0.02 + np.array([0, 0, H_ * 0.5]), b + d * 0.04 + np.array([0, 0, H_])])
                self.tube(cv, 0.009 if stage > 1 else 0.005, 0.005, stemp, 0.0, int(r.integers(1000)))
                for j in range(nl):         # opposite leaf pairs, each pair turned 90°
                    tq = 0.18 + 0.7 * j / max(nl - 1, 1)
                    p = cv(np.array([tq]))[0]
                    for side in (0, math.pi):
                        la = az + side + (j % 2) * 1.57 + r.normal(0, 0.15)
                        e = nv(np.array([math.cos(la), math.sin(la), 0.2 + 0.4 * tq]))
                        L = Ll * (1.1 - 0.35 * tq) * r.uniform(0.9, 1.08)
                        self.leaf(p, e, nv(np.array([0, 0.45, 1.0])), L, L * 0.34, leafp, und, droop=0.28, fold=0.12, veins=6, gloss=0.04, prof=lance, mid_k=0.25)
                if stage == 1:
                    continue
                # flowers / capsules in the axils of the upper part, turned to the camera side
                for j in range(6 if stage == 3 else 4):
                    tq = 0.4 + 0.11 * j
                    p = cv(np.array([tq]))[0]
                    sd = (1 if j % 2 else -1)
                    out = nv(np.array([sd * 0.6, 1.0, 0.0]))
                    q = p + out * 0.018
                    if stage == 2 or j == 5:
                        bell(q + np.array([0, 0, -0.005]), out)
                    else:
                        ax = nv(out * 0.22 + np.array([0, 0, 1.0]))
                        self._capsule(q - out * 0.006, ax, 0.062 * r.uniform(0.92, 1.06), 0.0125, capb if (j == 0 and k == 0) else capp)

    def _capsule(self, p, ax, L, R, pal):
        """a sesame capsule: a small upright four-sided pod, a groove down each face, a short beak"""
        r = self.r; sd = int(r.integers(1000))
        cf = self.line_c([p, p + ax * L * 0.5, p + ax * L])
        def rf(t):
            t = np.clip(t, 0, 1)
            return R * np.clip(t / 0.12, 0, 1) ** 0.5 * np.clip((1 - t) / 0.18, 0, 1) ** 0.7 + 1e-4
        def grooves(col, P, N, A, B):
            g = np.abs(np.cos(B * 2 * math.pi * 2)) ** 10
            col = col * (1 - 0.3 * g)[..., None]
            return mix(col, A_(C('#d6e6b0')), np.clip((vnoise(A * 30, B * 8, sd) - 0.7) / 0.3, 0, 1) * 0.15)
        self.tube(cf, R, R, pal, 0.0, sd, tint=grooves, rfun=rf)

    # ------------------------------------------------------------------ đậu phộng / bông vải / chàm / lá dứa
    def _quadleaf(self, top, az, Ll, leafp, und, up=0.2):
        """peanut leaf: two pairs of round-tipped (obovate) leaflets on a short rachis"""
        d = np.array([math.cos(az), math.sin(az), 0.0]); s = nv(np.cross(UP, d))
        prof = lambda t: np.sin(math.pi * np.clip(t, 0, 1) ** 0.7) ** 0.55
        f = nv(np.array([0, 0.45, 1.0]) + d * 0.2)
        for k, (ds, sc) in enumerate(((0.0, 0.9), (Ll * 0.45, 1.0))):
            b = top + d * ds + UP * 0.004 * k
            for sd_ in (-1, 1):
                e = nv(d * 0.55 + s * sd_ * 0.85 + UP * up)
                self.leaf(b, e, f, Ll * sc, Ll * sc * 0.62, leafp, und, droop=0.12, fold=0.1, veins=6, gloss=0.04, prof=prof, mid_k=0.25)

    def _pnut(self, c, ax, L, R, pal):
        """a peanut pod: two plump seed lobes with a waist between, a little beak, netted ridges on the shell"""
        r = self.r
        cf = self.line_c([c - ax * L * 0.5, c + np.array([0, 0, R * 0.12]), c + ax * L * 0.5])
        sd = int(r.integers(1000))
        def rf(t):
            t = np.clip(t, 0, 1)
            env = np.clip(t / 0.1, 0, 1) ** 0.55 * np.clip((1 - t) / 0.12, 0, 1) ** 0.6
            return R * env * (0.74 + 0.26 * np.abs(np.sin(2 * math.pi * (t - 0.03) / 0.97))) + 1e-4
        def net(col, P, N, A, B):
            rib = np.abs(np.cos(B * 2 * math.pi * 6)) ** 6
            cr = np.abs(np.cos(A * math.pi * 11 + np.sin(B * 2 * math.pi * 6) * 0.8)) ** 8
            g = np.clip(rib * 0.6 + cr * 0.5, 0, 1)
            n_ = vnoise(P[..., 0] / 0.006, P[..., 1] / 0.006, sd)
            col = col * (1 - 0.2 * g - 0.08 * n_)[..., None]
            return mix(col, A_(C('#7a5e40')), np.clip((0.02 - P[..., 2]) / 0.03, 0, 1) * 0.3)
        self.tube(cf, R, R, pal, 0.0, sd, tint=net, rfun=rf, zcut=0.0)

    def _dauphong(self, seed):
        """peanut (đậu phộng): 3 bushy plants of four-leaflet leaves; stage 2 small yellow pea flowers and pegs going
        into the soil; stage 3 BIG netted tan pods pulled up out of the soil in front of each plant"""
        r = self.r
        stage = seed % 4
        leafp = H('#1e4a1c', '#285e22', '#34762a', '#448e34', '#5aa644', '#84c068')
        und = H('#5a8a4a', '#6e9e5c', '#86b270', '#a2c68a', '#c4deaa')
        stemp = H('#3e5e24', '#4e722c', '#648a36', '#7ea244', '#a0be64')
        pegp = H('#8a7a5a', '#a49270', '#bcac88', '#d2c4a2', '#e6dcc0')
        podp = H('#7a5a32', '#9a7642', '#b89456', '#d2b070', '#e6cc96', '#f6e6c0')
        flc = dict(base=A_(C('#e8a010')), mid=A_(C('#f8c430')), tip=A_(C('#ffe680')), deep=A_(C('#b86a08')), vein=A_(C('#d88a10')))
        spots = self.tri()
        if stage == 1:
            for o in spots:
                top = o + np.array([0, 0, 0.07])
                self.tube(self.line_c([o, o + np.array([0, 0, 0.04]), top]), 0.0055, 0.0045, stemp, 0.0, int(r.integers(1000)))
                a0 = r.uniform(0, 6.28)
                for k in range(2):
                    self._quadleaf(top + UP * 0.006 * k, a0 + k * math.pi, 0.04, leafp, und, up=0.35)
            return
        Hs, nbr, Ll = (0.32, 6, 0.056) if stage == 2 else (0.48, 8, 0.068)
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            for k in range(nbr):
                az = a0 + k * 2.39996
                if stage == 3 and math.sin(az) > 0.55: az += 1.3          # keep the front open for the pods
                d = np.array([math.cos(az), math.sin(az) * 0.85, 0.0])
                h = Hs * r.uniform(0.75, 1.0) * (1.0 if k else 1.08)
                b = o + np.array([0, 0, 0.0])
                tip = b + d * (0.05 + 0.1 * (k > 0)) + np.array([0, 0, h])
                bc = self.line_c([b, b + d * 0.02 + np.array([0, 0, h * 0.45]), tip])
                self.tube(bc, 0.0075, 0.0045, stemp, 0.0, int(r.integers(1000)))
                for j in range(4):
                    tq = 0.35 + 0.18 * j
                    p = bc(np.array([tq]))[0]; la = az + (1 if j % 2 else -1) * 1.0
                    dl = np.array([math.cos(la), math.sin(la), 0.0])
                    pt = p + dl * 0.035 + np.array([0, 0, 0.03])
                    self.tube(self.line_c([p, p + dl * 0.015 + np.array([0, 0, 0.02]), pt]), 0.003, 0.0025, stemp, 0.0, int(r.integers(1000)))
                    self._quadleaf(pt, la, Ll * r.uniform(0.9, 1.08), leafp, und)
                    if stage == 2 and j < 2 and math.sin(az) > -0.3:      # a pea flower in the axil, turned to the camera
                        q = p + nv(dl + np.array([0, 1.2, 0])) * 0.03
                        e = nv(np.array([0, 1.0, 0.5]))
                        self.petal(q, nv(np.array([0, 0.3, 1.0])), nv(e + UP * 0.8), 0.036, 0.038, 0.3, flc, 0.002, nveins=5)
                        self.petal(q + np.array([0, 0.004, -0.004]), nv(np.array([0, 1, 0.2])), nv(e - UP * 0.3), 0.016, 0.012, 0.3, flc, 0.002, nveins=3)
                self._quadleaf(tip, az, Ll * 0.9, leafp, und, up=0.45)
            if stage == 2:          # pegs reaching down into the soil
                for k in range(4):
                    a = math.pi * 0.5 + (k - 1.5) * 0.6
                    dd = np.array([math.cos(a), math.sin(a), 0.0])
                    p = o + dd * 0.02 + np.array([0, 0, 0.1])
                    e = o + dd * 0.09 + np.array([0, 0, -0.005])
                    self.tube(self.line_c([p, p + dd * 0.05 + np.array([0, 0, 0.02]), e]), 0.0028, 0.002, pegp, 0.0, int(r.integers(1000)), zcut=0.0)
                continue
            # stage 3 (11-10): three big pods at the foot of the plant, half out of the loosened soil in front, each on its
            # own short peg going down from the stems; scattered, not in a ring
            for k in range(3):
                a = math.pi * 0.5 + (k - 1) * 0.75 + r.normal(0, 0.15)
                dd = np.array([math.cos(a), math.sin(a), 0.0])
                c = o + dd * (0.07 + 0.03 * r.random()) + np.array([0, 0.02, 0.018])
                ax = nv(nv(np.cross(UP, dd)) * r.choice([-1, 1]) * r.uniform(0.6, 1.0) + dd * r.uniform(0.2, 0.5) + np.array([0, 0, r.uniform(0.05, 0.25)]))
                pg = o + dd * 0.02 + np.array([0, 0, 0.07])
                self.tube(self.line_c([pg, (pg + c) * 0.5 + np.array([0, 0, 0.012]), c - ax * 0.05]), 0.0024, 0.002, pegp, 0.0, int(r.integers(1000)), zcut=0.0)
                self._pnut(c, ax, 0.14 * r.uniform(0.92, 1.06), 0.038 * r.uniform(0.95, 1.05), podp)

    def _bong_vai(self, seed):
        """cotton (bông vải): 3 upright shrubs with red-brown stems and big lobed leaves; stage 2 cream flowers blushed
        pink and green bolls; stage 3 BIG bursting bolls of white cotton in dry brown husks, held out in front"""
        r = self.r
        stage = seed % 4
        leafp = H('#1e4a1a', '#285e20', '#347628', '#448e32', '#5aa642', '#84c066')
        und = H('#5a8a48', '#6e9e5a', '#86b26e', '#a2c688', '#c4dea8')
        stemp = H('#4a2a1a', '#643a22', '#7e4e2c', '#986638', '#b4844c')
        bollg = H('#2e5418', '#3c6a1e', '#4e8426', '#649c32', '#80b448', '#a8cc70')
        husk = dict(base=A_(C('#6a4a26')), mid=A_(C('#8a6636')), tip=A_(C('#b08a52')), deep=A_(C('#4a321a')), vein=A_(C('#5a3e20')))
        wool = H('#9a9c9c', '#b8b8b6', '#d2d2ce', '#e6e4de', '#f4f2ec', '#ffffff')
        flc = dict(base=A_(C('#d84a6a')), mid=A_(C('#f4e4a0')), tip=A_(C('#fff6cc')), deep=A_(C('#a8304a')), vein=A_(C('#e8d088')))
        spots = self.tri()
        def red(col, P, N, A, B): return mix(col, A_(C('#8a3a2a')), 0.35)
        def lf(p, az, R, lean=0.5, rt=False):
            d = np.array([math.cos(az), math.sin(az), 0.0])
            b = p + d * R * 0.4 + np.array([0, 0, R * 0.2])
            self.tube(self.line_c([p, p + d * R * 0.2 + np.array([0, 0, R * 0.2]), b]), 0.0032, 0.0028, stemp, 0.0, int(r.integers(1000)))
            fn = nv(UP * 0.8 + d * lean + np.array([0, 0.35, 0]))
            self.pleaf(b, nv(d + np.array([0, 0, -0.35])), fn, R, leafp, und, lobes=5 if r.random() < 0.6 else 3, depth=0.42, spread=0.8,
                       teeth=(0, 0.0), cup=-0.08, ruffle=0.02, tint=red if rt else None)
        def wad(c, R):
            """a fluffy lock of cotton: a lumpy ball, soft and matte"""
            sd = int(r.integers(1000))
            def fl(col, P, N, A, B):
                n_ = vnoise(P[..., 0] / (R * 0.22), P[..., 1] / (R * 0.22), sd) + 0.5 * vnoise(P[..., 0] / (R * 0.08), P[..., 2] / (R * 0.08), sd + 3)
                return col * (0.9 + 0.1 * n_)[..., None]
            self.ellip(c, nv(np.array([r.normal(0, 0.3), r.normal(0, 0.3), 1.0])), R * r.uniform(0.95, 1.1), R, wool, 0.0, spec=0.02, tint=fl, bulge=0.1)
        def boll(c, out, R, ripe):
            if not ripe:
                self.ellip(c, nv(out * 0.3 + UP), R * 1.25, R, bollg, 0.0, spec=0.04, bulge=0.25)
                u, v = basis(nv(out * 0.3 + UP))
                for k in range(3):
                    a = k * 2.094; e = nv(math.cos(a) * u + math.sin(a) * v - UP * 0.2)
                    self.petal(c - UP * R * 0.6, e, nv(e + UP), R * 1.4, R * 1.3, 0.2, dict(base=bollg[1], mid=bollg[3], tip=bollg[4], deep=bollg[0], vein=bollg[2]), 0.002, nveins=5)
                return
            ax = nv(out * 0.35 + UP)
            u, v = basis(ax)
            for k in range(4):       # dry husk segments curled back
                a = k * 1.5708 + 0.4; e = nv(math.cos(a) * u + math.sin(a) * v - ax * 0.5)
                self.petal(c - ax * R * 0.2, e, nv(-ax + e * 0.3), R * 1.15, R * 0.9, -0.3, husk, 0.0, nveins=3)
            for k in range(4):       # four locks of lint bursting out
                a = k * 1.5708 + 0.4 + 0.785; e = math.cos(a) * u + math.sin(a) * v
                wad(c + e * R * 0.48 + ax * R * 0.25, R * 0.62)
            wad(c + ax * R * 0.55, R * 0.55)
        if stage == 1:
            for o in spots:
                top = o + np.array([0, 0, 0.07])
                self.tube(self.line_c([o, o + np.array([0, 0, 0.04]), top]), 0.005, 0.004, stemp, 0.0, int(r.integers(1000)))
                a0 = r.uniform(0, 6.28)
                for k in range(2):      # two kidney-shaped seed leaves + the first lobed leaf
                    a = a0 + k * math.pi; e = nv(np.array([math.cos(a), math.sin(a), 0.25]))
                    self.leaf(top, e, nv(np.array([0, 0.4, 1.0])), 0.045, 0.05, leafp, und, droop=0.08, fold=0.08, veins=4, gloss=0.04,
                              prof=lambda t: np.sin(math.pi * np.clip(t, 0, 1) ** 0.85) ** 0.45, mid_k=0.2)
                lf(top + np.array([0, 0, 0.01]), a0 + 1.57, 0.05, lean=0.2)
            return
        Hs, nb, Rl = (0.36, 5, 0.088) if stage == 2 else (0.58, 7, 0.102)
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            top = o + np.array([r.normal(0, 0.01), 0, Hs])
            cv = self.line_c([o, o + np.array([0, 0, Hs * 0.5]), top])
            self.tube(cv, 0.011, 0.006, stemp, 0.0, int(r.integers(1000)))
            lf(top - UP * 0.01, a0, Rl * 0.75, lean=0.2)
            for k in range(nb):          # fruiting branches up the stem, alternate
                tq = 0.3 + 0.62 * k / max(nb - 1, 1)
                p = cv(np.array([tq]))[0]
                az = a0 + k * 2.39996
                d = np.array([math.cos(az), math.sin(az) * 0.85, 0.0])
                Lb = (0.13 - 0.05 * tq) * r.uniform(0.9, 1.1)
                end = p + d * Lb + np.array([0, 0, Lb * 0.35])
                self.tube(self.line_c([p, p + d * Lb * 0.5 + np.array([0, 0, Lb * 0.25]), end]), 0.005, 0.0035, stemp, 0.0, int(r.integers(1000)))
                lf(p + d * Lb * 0.45, az + 0.9, Rl * r.uniform(0.9, 1.08), rt=False)
                lf(end, az - 0.6, Rl * 0.85 * r.uniform(0.9, 1.08))
                lf(p + d * 0.01, az + math.pi * 0.8, Rl * 0.8 * r.uniform(0.9, 1.08))
            # bolls / flowers on short stalks out to the camera side
            nbo = 2 if stage == 2 else 4
            for j in range(nbo):
                tq = (0.4, 0.58, 0.78, 0.94)[j] + r.normal(0, 0.03)
                p = cv(np.array([min(tq, 0.95)]))[0]
                sd_ = (-1, 1, 0, 0.5)[j]
                out = nv(np.array([sd_ * 0.7, 1.0, 0.0]))
                c = p + out * (0.065 if stage == 3 else 0.08) + np.array([0, 0, 0.012])
                self.tube(self.line_c([p, p + out * 0.03 + np.array([0, 0, 0.012]), c - UP * 0.02]), 0.003, 0.0028, stemp, 0.0, int(r.integers(1000)))
                if stage == 2:
                    if j == 0:
                        boll(c, out, 0.024, False)
                    else:
                        e = nv(out * 0.6 + UP)
                        u, v = basis(e)
                        for k in range(5):
                            a = k * 1.2566 + 0.3; ee = nv(e * 0.8 + (math.cos(a) * u + math.sin(a) * v) * 0.7)
                            self.petal(c, nv(math.cos(a) * u + math.sin(a) * v), ee, 0.058, 0.05, 0.3, flc, 0.002, nveins=5)
                else:
                    boll(c, out, 0.062 * r.uniform(0.95, 1.05), True)

    def _pinnate(self, p, az, L, n, Lf, leafp, und, stemp, up=0.25):
        """a pinnate leaf: a thin rachis with n pairs of small oval leaflets and one at the tip (chàm)"""
        d = nv(np.array([math.cos(az), math.sin(az), up])); s = nv(np.cross(UP, d))
        e2 = p + d * L
        rc = self.line_c([p, p + d * L * 0.5 + np.array([0, 0, L * 0.06]), e2 - np.array([0, 0, L * 0.06])])
        self.tube(rc, 0.0022, 0.0016, stemp, 0.0, int(self.r.integers(1000)))
        f = nv(np.array([0, 0.45, 1.0]) + d * 0.1)
        ov = lambda t: np.sin(math.pi * np.clip(t, 0, 1) ** 0.9) ** 0.6
        for k in range(n):
            q = rc(np.array([0.2 + 0.75 * k / max(n - 1, 1)]))[0]
            for sd_ in (-1, 1):
                e = nv(s * sd_ + d * 0.35 + UP * 0.15)
                self.leaf(q, e, f, Lf, Lf * 0.55, leafp, und, droop=0.08, fold=0.08, veins=4, gloss=0.04, prof=ov, mid_k=0.2)
        self.leaf(rc(np.array([1.0]))[0], d, f, Lf, Lf * 0.55, leafp, und, droop=0.08, fold=0.08, veins=4, gloss=0.04, prof=ov, mid_k=0.2)

    def _cham(self, seed):
        """indigo (chàm): 3 upright shrubs with fine pinnate blue-green leaves; stage 2 spikes of small salmon-pink
        pea flowers; stage 3 a dense tall bush, flower spikes and clusters of slim curved pods in front"""
        r = self.r
        stage = seed % 4
        leafp = H('#163e2c', '#1c5234', '#26683e', '#327e4a', '#44965c', '#6ab27e')
        und = H('#4e7e62', '#609274', '#78a88a', '#94bea2', '#b6d6c0')
        stemp = H('#4a3a24', '#5e4a2c', '#765e36', '#8e7444', '#aa9060')
        podp = H('#3a3a1a', '#4e4c22', '#66622c', '#7e7838', '#9a924a', '#bcb46e')
        flc = dict(base=A_(C('#c8505a')), mid=A_(C('#e8808a')), tip=A_(C('#f8c0c0')), deep=A_(C('#963040')), vein=A_(C('#d0606a')))
        spots = self.tri()
        if stage == 1:
            for o in spots:
                top = o + np.array([0, 0, 0.08])
                self.tube(self.line_c([o, o + np.array([0, 0, 0.04]), top]), 0.005, 0.004, stemp, 0.0, int(r.integers(1000)))
                a0 = r.uniform(0, 6.28)
                for k in range(3):
                    self._pinnate(top - UP * 0.02 * k, a0 + k * 2.3, 0.05, 2, 0.022, leafp, und, stemp, up=0.5)
            return
        Hs, nbr, nlf = (0.36, 7, 4) if stage == 2 else (0.6, 10, 5)
        def spike(p, out, L, pods=False):
            ax = nv(out * 0.45 + UP)
            cf = self.line_c([p, p + ax * L * 0.5, p + ax * L])
            self.tube(cf, 0.0022, 0.0014, stemp, 0.0, int(r.integers(1000)))
            for k in range(9):
                q = cf(np.array([0.2 + 0.09 * k]))[0]
                a = k * 2.4; u, v = basis(ax); e = nv(math.cos(a) * u + math.sin(a) * v + np.array([0, 0.6, 0]))
                sc = 1.0 - 0.06 * k
                if pods and k < 4:
                    self._pod(q, nv(e * 0.5 - UP * 0.9 + np.array([0, 0.3, 0])), 0.075 * sc, 0.009, podp, nb=6, curve=np.array([0, 0.012, 0.006]))
                else:
                    self.petal(q + e * 0.004, nv(e + UP * 0.2), nv(e + UP * 0.6), 0.021 * sc, 0.022 * sc, 0.3, flc, 0.002, nveins=3)
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            for k in range(nbr):
                az = a0 + k * 2.39996; d = np.array([math.cos(az), math.sin(az) * 0.85, 0.0])
                h = Hs * r.uniform(0.75, 1.0) * (1.08 if k == 0 else 1.0)
                tip = o + d * (0.02 + 0.07 * (k > 0)) + np.array([0, 0, h])
                bc = self.line_c([o, o + d * 0.015 + np.array([0, 0, h * 0.5]), tip])
                self.tube(bc, 0.007, 0.0035, stemp, 0.0, int(r.integers(1000)))
                for j in range(nlf):
                    tq = 0.3 + 0.7 * j / max(nlf - 1, 1)
                    p = bc(np.array([tq]))[0]; la = az + (1 if j % 2 else -1) * 1.1
                    self._pinnate(p, la, 0.095 * r.uniform(0.9, 1.08), 4, 0.034 * r.uniform(0.92, 1.06), leafp, und, stemp)
                self._pinnate(tip, az, 0.075, 3, 0.03, leafp, und, stemp, up=0.7)
                if math.sin(az) > -0.1:
                    p = bc(np.array([0.62]))[0]
                    out = nv(d + np.array([0, 1.0, 0]))
                    spike(p + out * 0.02, out, 0.14, pods=(stage == 3 and k % 2 == 0))

    def _la_dua(self, seed):
        """pandan (lá dứa): 3 rosettes of long, keeled, glossy-green strap leaves arching out in a spiral; stage 3 tall
        with a short stem and a couple of prop roots"""
        r = self.r
        stage = seed % 4
        leafp = H('#1c5418', '#246c1c', '#2e8424', '#3c9a2e', '#52b03e', '#7ec862')
        rootp = H('#5a4a2e', '#706038', '#8a7848', '#a49060', '#c0ac80')
        spots = self.tri()
        nl, Lb, W, Hs = {1: (6, 0.14, 0.024, 0.0), 2: (11, 0.4, 0.038, 0.02)}.get(stage, (16, 0.58, 0.045, 0.08))
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            top = o + np.array([0, 0, Hs])
            if stage == 3:
                self.tube(self.line_c([o, o + np.array([0, 0, Hs * 0.5]), top + UP * 0.02]), 0.02, 0.018, rootp, 0.0, int(r.integers(1000)), node=0.08)
                for k in range(3):
                    a = a0 + k * 2.1; dd = np.array([math.cos(a), math.sin(a), 0.0])
                    self.tube(self.line_c([o + UP * Hs * 0.8, o + dd * 0.03 + UP * Hs * 0.4, o + dd * 0.06]), 0.0055, 0.006, rootp, 0.0, int(r.integers(1000)), zcut=0.0)
            for k in range(nl):
                az = a0 + k * 2.39996
                q = k / max(nl - 1, 1)          # 0 = outer old leaves, 1 = young inner ones (more upright)
                db = np.array([math.cos(az), math.sin(az) * 0.9, 0.0])
                L = Lb * r.uniform(0.88, 1.06) * (1.0 - 0.25 * q)
                up = (1.3 if stage == 3 else 0.95) + 1.4 * q
                p0 = top + UP * (0.01 + 0.03 * q)
                p1 = p0 + db * L * 0.14 + UP * L * up * 0.3
                p2 = p0 + db * L * 0.45 + UP * L * up * 0.38
                p3 = p0 + db * L * 0.8 + UP * L * (up * 0.3 - 0.12 * (1 - q))
                self.strap(self.line_c([p0, p1, p2, p3]), W * r.uniform(0.9, 1.08), leafp, 0.0, fold=0.32, vein_n=7,
                           wprof=[0.55, 0.95, 1.0, 0.92, 0.6, 0.0], gloss=0.06)

    # ------------------------------------------------------------------ bầu / bí đao / khổ qua / đậu rồng (no trellis)
    def _climbbush(self, seed, kind):
        """bầu, bí đao, khổ qua, đậu rồng drawn as 3 upright leafy bushes on the bắp spots (Link 15:07: no giàn):
        a few vine stems rising and arching from each base, leaves along them, curly tendrils; stage 2 flowers and a
        small fruit; stage 3 the BIG fruit hanging / lying out in front of the leaves"""
        r = self.r
        stage = seed % 4
        spots = self.tri()
        vinep = H('#3e6224', '#4e762c', '#648e36', '#7ea644', '#a0c264')
        und = H('#5a8a48', '#6e9e5a', '#86b26e', '#a2c688', '#c4dea8')
        P = dict(
            bau=dict(leafp=H('#2a5a1e', '#346e26', '#428430', '#549c3c', '#6eb450', '#98cc78'), R=0.085, lobes=5, depth=0.12, sub=0.0,
                     fl=dict(base=A_(C('#d8dcc8')), mid=A_(C('#f4f6ec')), tip=A_(C('#ffffff')), deep=A_(C('#a8b098')), vein=A_(C('#dfe4d2')))),
            bi_dao=dict(leafp=H('#1e4a18', '#285e1e', '#347628', '#448e32', '#5aa642', '#84c066'), R=0.09, lobes=5, depth=0.3, sub=0.0,
                        fl=dict(base=A_(C('#d89a10')), mid=A_(C('#f4c020')), tip=A_(C('#ffe680')), deep=A_(C('#a86a08')), vein=A_(C('#e0a818')))),
            kho_qua=dict(leafp=H('#1e4c18', '#28621e', '#347a26', '#46922e', '#5eaa3c', '#86c262'), R=0.125, lobes=5, depth=0.58, sub=0.35,
                         fl=dict(base=A_(C('#d8b010')), mid=A_(C('#f4d428')), tip=A_(C('#fff088')), deep=A_(C('#a88008')), vein=A_(C('#e0c020')))),
            muop=dict(leafp=H('#1e4c18', '#28621e', '#347a26', '#46922e', '#5eaa3c', '#86c262'), R=0.125, lobes=5, depth=0.34, sub=0.0,
                      fl=dict(base=A_(C('#d8a810')), mid=A_(C('#f4cc22')), tip=A_(C('#ffec84')), deep=A_(C('#a87a08')), vein=A_(C('#e0b81c')))),
            dau_rong=dict(leafp=H('#1e4a18', '#28601e', '#347826', '#46902e', '#5ea83c', '#86c060'), R=0.13, lobes=0, depth=0, sub=0,
                          fl=dict(base=A_(C('#7a88c8')), mid=A_(C('#a8b4e8')), tip=A_(C('#dfe4fa')), deep=A_(C('#4e5a9a')), vein=A_(C('#8a96d0')))),
        )[kind]
        leafp = P['leafp']
        def leafat(p, az, R, hgt=0.02):
            d = np.array([math.cos(az), math.sin(az), 0.0])
            b = p + d * R * 0.45 + np.array([0, 0, hgt])
            self.tube(self.line_c([p, p + d * R * 0.2 + np.array([0, 0, hgt * 0.8]), b]), 0.0032, 0.0026, vinep, 0.0, int(r.integers(1000)))
            if kind == 'dau_rong':
                self._trifol(b, az, R * 0.95, leafp, und, vinep, pointed=0.45, up=0.25)
                return
            fn = nv(UP * 0.8 + d * 0.5 + np.array([0, 0.35, 0]))
            self.pleaf(b, nv(d + np.array([0, 0, -0.35])), fn, R, leafp, und, lobes=P['lobes'], depth=P['depth'], sub=P['sub'],
                       spread=0.8, teeth=(30, 0.02) if kind == 'kho_qua' else (36, 0.018) if kind == 'muop' else (0, 0.0), cup=-0.06, ruffle=0.025)
        if stage == 1:
            for o in spots:
                top = o + np.array([0, 0, 0.07])
                self.tube(self.line_c([o, o + np.array([0, 0, 0.04]), top]), 0.0055, 0.0045, vinep, 0.0, int(r.integers(1000)))
                a0 = r.uniform(0, 6.28)
                for k in range(2):      # two seed leaves (two simple first leaves for đậu rồng)
                    a = a0 + k * math.pi; e = nv(np.array([math.cos(a), math.sin(a), 0.3]))
                    self.leaf(top, e, nv(np.array([0, 0.4, 1.0])), 0.045, 0.03 if kind == 'dau_rong' else 0.028, leafp, und, droop=0.08,
                              fold=0.1, veins=4, gloss=0.04, prof=lambda t: np.sin(math.pi * np.clip(t, 0, 1) ** 0.8) ** 0.55, mid_k=0.2)
                leafat(top + np.array([0, 0, 0.005]), a0 + 1.57, P['R'] * 0.55, 0.012)
            return
        Hs, ns, nl = (0.36, 4, 4) if stage == 2 else (0.66, 5, 6)
        big = True      # Link 15:44 + 11-10: every climbing crop gets thick stems and big dense leaves
        if big and stage == 3: ns, nl = 6, 8
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            tops = []
            so = o + np.array([0.012, -0.03, 0.0])        # Link 15:08: a bamboo stake like the tomato, the main vine tied to it
            Hk = Hs * 1.12 * r.uniform(0.97, 1.03)
            self._stake(so, Hk)
            for k in range(ns):
                az = a0 + k * 2.39996
                if stage == 3 and math.sin(az) > 0.6: az += 1.3          # keep the front open for the fruit
                d = np.array([math.cos(az), math.sin(az) * 0.85, 0.0])
                h = Hs * r.uniform(0.75, 1.0) * (1.06 if k == 0 else 1.0)
                if k == 0:          # the leader climbs straight up the stake
                    tip = so + np.array([-0.012, 0.012, Hk * 0.97])
                    cv = self.line_c([o, so + np.array([-0.01, 0.012, Hk * 0.35]), so + np.array([0.012, 0.01, Hk * 0.66]), tip])
                else:
                    tip = o + d * 0.12 + np.array([0, 0, h])
                    cv = self.line_c([o, o + d * 0.02 + np.array([0, 0, h * 0.55]), tip - d * 0.02, tip + d * 0.05 - UP * 0.03])
                self.tube(cv, 0.014 if big else 0.0065, 0.008 if big else 0.004, vinep, 0.0, int(r.integers(1000)), node=0.1)
                if k == 0:
                    for z in (0.35, 0.66, 0.92):
                        self._tie(so * np.array([1, 1, 0]), 0.022, Hk * z)
                for j in range(nl):
                    tq = 0.22 + 0.74 * j / max(nl - 1, 1)
                    p = cv(np.array([tq]))[0]
                    la = az + (1 if j % 2 else -1) * 1.0 + r.normal(0, 0.15)
                    leafat(p, la, P['R'] * r.uniform(0.88, 1.08) * (1.05 - 0.2 * tq))
                    if j % 2 == 0 and j > 0:
                        self._tendril(p, nv(np.array([math.cos(la + 2.0), math.sin(la + 2.0), 0.5])), L=0.05, pal=vinep)
                tops.append((cv, d, az))
            # flowers, and the fruit, on the stems turned most to the camera
            fr = sorted(tops, key=lambda x: -x[1][1])
            for bi, (cv, d, az) in enumerate(fr[:2]):
                p = cv(np.array([0.5 + 0.15 * bi]))[0]
                out = nv(d * 0.4 + np.array([0, 1.0, 0]))
                if stage == 2 or bi == 1:
                    if kind == 'dau_rong':
                        q = p + out * 0.03
                        e = nv(np.array([0, 1.0, 0.5]))
                        self.petal(q, nv(np.array([0, 0.3, 1.0])), nv(e + UP * 0.8), 0.04, 0.042, 0.3, P['fl'], 0.002, nveins=5)
                        self.petal(q + np.array([0, 0.004, -0.004]), nv(np.array([0, 1, 0.2])), nv(e - UP * 0.3), 0.022, 0.018, 0.3, P['fl'], 0.002, nveins=3)
                    else:
                        self._vinef(p + out * 0.03, nv(out + UP * 0.5), 0.035 if kind == 'kho_qua' else 0.062 if kind == 'muop' else 0.05, P['fl'], n=5, W=0.75 if kind == 'bau' else 0.6)
                    if stage == 2: continue
            if stage == 2:
                continue
            self._bigfruit(kind, o, fr[0], pi)

    def _bigfruit(self, kind, o, br, pi):
        r = self.r
        cv, d, az = br
        stemp = H('#3e6224', '#4e762c', '#648e36', '#7ea644', '#a0c264')
        sd = int(r.integers(1000))
        if kind in ('bau', 'bi_dao') and pi != 1:
            return
        if kind == 'bau':
            # bầu (Link 15:44): ONE big long pale-green gourd lying on the bed in front, like the bí đỏ / dưa hấu
            c = np.array([0.0, 0.25, 0.0])
            ax = nv(np.array([1.0, -0.32, 0.0]))
            p0 = c - ax * 0.27 + np.array([0, 0, 0.05]); p1 = c + ax * 0.27 + np.array([0, 0, 0.11])
            pal = H('#2e5418', '#3c6a20', '#4e842a', '#669e38', '#84b850', '#a8d07a')
            def rf(t):
                t = np.clip(t, 0, 1)
                neck = 0.05 + 0.012 * np.clip((0.3 - t) / 0.3, 0, 1)                     # a thick neck, then the round bulb
                bulb = 0.11 * np.sqrt(np.clip(1 - ((t - 0.7) / 0.32) ** 2, 0, 1))
                body = np.maximum(neck, bulb) * np.clip(t / 0.05, 0, 1) ** 0.5 * np.clip((1 - t) / 0.04, 0, 1) ** 0.5
                return body + 1e-4
            def spk(col, P_, N, A, B):
                n_ = vnoise(P_[..., 0] / 0.01, P_[..., 1] / 0.01, sd) * 0.6 + vnoise(P_[..., 0] / 0.003, P_[..., 2] / 0.003, sd + 1) * 0.4
                col = mix(col, A_(C('#dcecb4')), np.clip((n_ - 0.58) / 0.2, 0, 1) * 0.45)          # the pale speckles of a bầu
                return mix(col, A_(C('#5a4a30')), np.clip((0.02 - P_[..., 2]) / 0.03, 0, 1) * 0.3)
            self.tube(self.line_c([p0, (p0 + p1) * 0.5 + np.array([0, 0, 0.01]), p1]), 0.1, 0.1, pal, 0.0, sd, tint=spk, rfun=rf, zcut=0.0)
            st = p0 - ax * 0.005
            self.tube(self.line_c([st, st - ax * 0.04 + np.array([0, 0, 0.03]), cv(np.array([0.25]))[0]]), 0.006, 0.005, stemp, 0.0, int(r.integers(1000)))
        elif kind == 'muop':
            # mướp (Link 16:35): TWO straight luffas hanging straight down in front, a big one on the front plant and a
            # small one on the right plant; faint dark ribs, a dry flower at the bottom tip
            big_ = pi == 1      # Link 16:51: + a medium one on the left plant
            L = (0.4, 0.5, 0.3)[pi]
            R0 = (0.05, 0.06, 0.042)[pi]
            top = o + np.array([(0.02, 0.02, -0.02)[pi], 0.11, (0.54, 0.6, 0.46)[pi]])
            bot = top + np.array([0.0, 0.012, -L])
            pal = H('#2e5418', '#3e6a20', '#52842c', '#6a9e3a', '#88b650', '#b0d27c')
            def rf(t, R0=R0):
                t = np.clip(t, 0, 1)
                return R0 * (0.8 + 0.2 * t) * np.clip(t / 0.1, 0, 1) ** 0.5 * np.clip((1 - t) / 0.07, 0, 1) ** 0.45 + 1e-4
            def rib(col, P_, N, A, B):
                ln = np.exp(-((((B * 10) % 1.0) - 0.5) / 0.07) ** 2)
                col = col * (1 - 0.3 * ln)[..., None]
                n_ = vnoise(P_[..., 0] / 0.01, P_[..., 2] / 0.01, sd)
                return mix(col, A_(C('#cfe4a4')), np.clip((n_ - 0.6) / 0.3, 0, 1) * 0.18)
            self.tube(self.line_c([top, (top + bot) * 0.5, bot]), R0, R0, pal, 0.0, sd, tint=rib, rfun=rf)
            hook = cv(np.array([0.7]))[0]
            st = top + np.array([0, 0, 0.004])
            self.tube(self.line_c([hook, (hook + st) * 0.5 + np.array([0, 0.01, 0.02]), st]), 0.006, 0.005, stemp, 0.0, int(r.integers(1000)))
            self.ellip(bot - UP * 0.01, -UP, 0.016, 0.012, H('#5a4418', '#7a5e22', '#9a7a30', '#b89a46'), 0.002, spec=0.02)
        elif kind == 'bi_dao':
            # bí đao (Link 15:44): ONE BIG oblong dark-green melon with a white waxy bloom lying in front
            c = np.array([0.0, 0.25, 0.16])
            ax = nv(np.array([1.0, -0.3, 0.02]))
            pal = H('#163416', '#1e461e', '#285a26', '#346e30', '#468440', '#669c5a')
            def bloom(col, P_, N, A, B):
                n_ = vnoise(P_[..., 0] / 0.02, P_[..., 1] / 0.02, sd) * 0.5 + vnoise(P_[..., 0] / 0.005, P_[..., 2] / 0.005, sd + 1) * 0.5
                col = mix(col, A_(C('#d4e0d0')), np.clip(0.06 + 0.42 * (n_ - 0.35), 0, 0.42))
                return mix(col, A_(C('#5a4a30')), np.clip((0.02 - P_[..., 2]) / 0.03, 0, 1) * 0.3)
            self.ellip(c, ax, 0.32, 0.16, pal, 0.0, spec=0.02, tint=bloom)
            st = c - ax * 0.29 + np.array([0, 0, 0.03])
            self.tube(self.line_c([st, st - ax * 0.04 + np.array([0, 0, 0.04]), cv(np.array([0.25]))[0]]), 0.006, 0.005, stemp, 0.0, int(r.integers(1000)))
        elif kind == 'kho_qua':
            # khổ qua: three warty bright-green fruits hanging from the front stems
            pal = H('#2e5a18', '#3c7020', '#4e8a2a', '#64a436', '#82bc4c', '#acd678')
            for k in range(3):
                p = cv(np.array([0.36 + 0.2 * k]))[0] + np.array([(k - 1) * 0.04, 0.05, 0])
                top = p + np.array([0, 0.02, -0.025])
                self.tube(self.line_c([p, (p + top) * 0.5, top]), 0.0028, 0.0024, stemp, 0.0, int(r.integers(1000)))
                L = 0.23 * r.uniform(0.92, 1.06)
                bot = top + nv(np.array([r.normal(0, 0.15), 0.25, -1.0])) * L
                sdk = int(r.integers(1000))
                def rf(t):
                    t = np.clip(t, 0, 1)
                    return 0.043 * np.clip(t / 0.18, 0, 1) ** 0.7 * np.clip((1 - t) / 0.3, 0, 1) ** 0.9 + 1e-4
                def wart(col, P_, N, A, B, sdk=sdk):
                    rib = np.cos(B * 2 * math.pi * 9)
                    bump = np.cos(A * math.pi * 26 + (B * 9 % 1) * 2.5)
                    w = np.clip(rib * 0.5 + 0.5, 0, 1) * np.clip(bump * 0.5 + 0.5, 0, 1)
                    return np.clip(col * (0.68 + 0.5 * w)[..., None], 0, 1)
                self.tube(self.line_c([top, (top + bot) * 0.5 + np.array([0, 0.012, 0]), bot]), 0.043, 0.043, pal, 0.0, sdk, tint=wart, rfun=rf)
        else:
            # đậu rồng: bunches of long winged pods hanging in front: a slim square body with four thin frilly wings
            # standing out along its length (the cross-section is a four-pointed star), the wing edges paler and toothed
            pal = H('#2e5a1a', '#3c7022', '#4e8a2c', '#64a238', '#80ba4e', '#a8d476')
            for k in range(4):
                p = cv(np.array([0.34 + 0.15 * k]))[0] + np.array([(k - 1.5) * 0.03, 0.05, 0])
                L = 0.25 * r.uniform(0.9, 1.06)
                bot = p + nv(np.array([r.normal(0, 0.2), 0.3, -1.0])) * L
                cf = self.line_c([p, (p + bot) * 0.5 + np.array([0, 0.015, 0]), bot])
                ax0 = nv(bot - p); u0, v0 = basis(ax0); rot0 = r.uniform(0, 1.5)
                R0 = 0.012; Wg = 0.021
                def geo(A, B, cf=cf, u0=u0, v0=v0, rot0=rot0, R0=R0, Wg=Wg):
                    t = np.clip(A, 0, 1); th = B * 2 * math.pi + rot0
                    env = np.clip(t / 0.06, 0, 1) ** 0.6 * np.clip((1 - t) / 0.08, 0, 1) ** 0.7
                    star = np.abs(np.cos(2 * (th - rot0))) ** 14                       # four narrow wings
                    frill = 1 + 0.12 * np.sin(t * 90) * star
                    rr = (R0 + Wg * star * frill) * env + 1e-4
                    return cf(t) + (u0[None, None] * np.cos(th)[..., None] + v0[None, None] * np.sin(th)[..., None]) * rr[..., None]
                def sh(P_, N, F, A, B, rot0=rot0):
                    th = B * 2 * math.pi + rot0
                    star = np.abs(np.cos(2 * (th - rot0))) ** 14
                    lam = self.lam(N)
                    col = ramp(pal, np.clip(0.18 + 0.75 * lam, 0, 1))
                    col = mix(col, A_(C('#cfe89a')), np.clip((star - 0.6) / 0.4, 0, 1) * 0.45)          # pale wing edges
                    return col * (1 - 0.12 * np.clip((0.2 - star) / 0.2, 0, 1) * np.abs(np.sin(A * math.pi * 40)) ** 6)[..., None]
                self.splat(geo, sh, (p + bot) * 0.5 + TOCAM * 0.02)
                self.tube(self.line_c([cv(np.array([0.34 + 0.15 * k]))[0], p]), 0.003, 0.0026, stemp, 0.0, int(r.integers(1000)))

    def _bau(self, seed): self._climbbush(seed, 'bau')
    def _bi_dao(self, seed): self._climbbush(seed, 'bi_dao')
    def _kho_qua(self, seed): self._climbbush(seed, 'kho_qua')
    def _dau_rong(self, seed): self._climbbush(seed, 'dau_rong')
    def _muop(self, seed): self._climbbush(seed, 'muop')

    def _dau_bap(self, seed):
        """okra (đậu bắp): 3 upright single-stemmed plants on the bắp spots; big deeply 5-lobed leaves on long stalks up
        the stem, pale-yellow flowers with a maroon eye (stage 2), stage 3 BIG ridged green pods standing up out of the
        leaf axils toward the camera"""
        r = self.r
        stage = seed % 4
        spots = self.tri()
        leafp = H('#1e4a18', '#28601e', '#347826', '#46902e', '#5ea83c', '#86c060')
        und = H('#4e7a3e', '#62904c', '#7aa660', '#94bc78', '#b6d49a')
        stemp = H('#3a5a20', '#4a6e28', '#5e8632', '#76a040', '#96ba5a')
        podp = H('#4a7a1e', '#5e9428', '#78ae36', '#94c64c', '#b2da6c', '#d6eea0')
        fl = dict(base=A_(C('#e2d062')), mid=A_(C('#f4ea9a')), tip=A_(C('#fffadc')), deep=A_(C('#b89c38')), vein=A_(C('#dcc86a')))
        def lf(p, az, R, lean=0.5):
            d = np.array([math.cos(az), math.sin(az), 0.0])
            b = p + d * R * 0.6 + np.array([0, 0, R * 0.22])
            self.tube(self.line_c([p, p + d * R * 0.25 + np.array([0, 0, R * 0.2]), b]), 0.0045, 0.0035, stemp, 0.0, int(r.integers(1000)))
            fn = nv(UP * 0.8 + d * lean + np.array([0, 0.35, 0]))
            self.pleaf(b, nv(d + np.array([0, 0, -0.3])), fn, R, leafp, und, lobes=5, depth=0.55, sub=0.0, spread=0.85,
                       teeth=(30, 0.03), cup=-0.06, ruffle=0.03)
        def flower(p, out, L=0.05):
            u, v = basis(out)
            for k in range(5):
                a = k * 1.2566 + 0.3; e = nv((math.cos(a) * u + math.sin(a) * v) * 0.85 + out * 0.4)
                self.petal(p, -out, e, L, L * 0.95, 0.22, fl, 0.002, prof=[0.45, 0.8, 1.0, 1.0, 0.92, 0.6, 0.0], nveins=5)
            self.ellip(p + out * 0.004, out, L * 0.34, L * 0.05, H('#3a0a10', '#561420', '#701e2a', '#8a2c34'), 0.003, spec=0.02)
            self.tube(self.line_c([p, p + out * L * 0.25, p + out * L * 0.45]), 0.0035, 0.003, H('#a8901e', '#c8ae30', '#e4ca48', '#f6e070'), 0.004, int(r.integers(1000)))
        def pod(p, ax, L, R):
            bend = nv(np.cross(ax, UP) + 1e-6) * L * 0.06
            cf = self.line_c([p, p + ax * L * 0.5 + bend * 0.5, p + ax * L + bend])
            sd = int(r.integers(1000))
            def rf(t):
                t = np.clip(t, 0, 1)
                return R * np.clip(t / 0.14, 0, 1) ** 0.5 * (1 - 0.15 * t) * np.clip((1 - t) / 0.3, 0, 1) ** 0.8 + 1e-4      # a long finger, pointed tip
            def ridge(col, P, N, A, B):
                rb = 0.5 + 0.5 * np.cos(B * 2 * math.pi * 5)
                col = col * (0.8 + 0.28 * rb)[..., None]
                n_ = vnoise(P[..., 0] / 0.004, P[..., 2] / 0.004, sd)
                return mix(col, A_(C('#d4ecac')), np.clip((n_ - 0.65) / 0.3, 0, 1) * 0.15)
            self.tube(cf, R, R, podp, 0.0, sd, tint=ridge, rfun=rf)
            u, v = basis(ax)       # the small green cap at the pod's base
            self.ellip(p + ax * 0.008, ax, 0.012, R * 0.85, H('#2e5418', '#3e6a20', '#52842c', '#6a9e3a'), 0.002, spec=0.02)
        if stage == 1:
            for o in spots:
                top = o + np.array([0, 0, 0.07])
                self.tube(self.line_c([o, o + np.array([0, 0, 0.04]), top]), 0.006, 0.005, stemp, 0.0, int(r.integers(1000)))
                a0 = r.uniform(0, 6.28)
                for k in range(2):
                    a = a0 + k * math.pi; e = nv(np.array([math.cos(a), math.sin(a), 0.3]))
                    self.leaf(top, e, nv(np.array([0, 0.4, 1.0])), 0.042, 0.032, leafp, und, droop=0.08, fold=0.1, veins=4, gloss=0.04,
                              prof=lambda t: np.sin(math.pi * np.clip(t, 0, 1) ** 0.8) ** 0.55, mid_k=0.2)
                lf(top + np.array([0, 0, 0.004]), a0 + 1.57, 0.055)
            return
        Hs = 0.42 if stage == 2 else 0.66
        for pi, o in enumerate(spots):
            Hc = Hs * r.uniform(0.95, 1.04)
            tip = o + np.array([r.normal(0, 0.008), r.normal(0, 0.008), Hc])
            cul = self.line_c([o, o + np.array([0, 0, Hc * 0.5]), tip])
            self.tube(cul, 0.022, 0.011, stemp, 0.0, int(r.integers(1000)), node=0.12)
            a0 = r.uniform(0, 6.28)
            nl = 6 if stage == 2 else 9
            axl = []
            for j in range(nl):
                tq = 0.28 + 0.68 * j / (nl - 1)
                az = a0 + j * 2.39996
                fr = math.sin(az) > 0.55
                if stage == 3 and math.sin(az) > 0.1 and 0.25 < tq < 0.85:
                    axl.append((tq, az)); az = (math.pi * 1.5 + (1 if math.cos(az) > 0 else -1) * 0.9)      # the pod stands in this axil, its leaf turns to the back
                R = (0.13 if stage == 2 else 0.19) * (1.08 - 0.42 * tq) * r.uniform(0.9, 1.08)
                lf(cul(np.array([tq]))[0], az, R, lean=0.45 + 0.4 * tq)
            for k in range(3):        # the crown of young leaves at the top
                lf(tip, a0 + k * 2.1, (0.06 if stage == 2 else 0.07) * r.uniform(0.85, 1.1), lean=0.9)
            if stage == 2:
                p = cul(np.array([0.82]))[0]; out = nv(np.array([0.2 * (pi - 1), 1.0, 0.35]))
                flower(p + out * 0.035, out)
                pod(cul(np.array([0.66]))[0] + np.array([0, 0.02, 0]), nv(np.array([0.1, 0.4, 1.0])), 0.08, 0.016)
                continue
            # stage 3: three BIG pods standing up from the front of the stem, a flower above them
            ts = (0.36, 0.52, 0.68)
            for k, tq in enumerate(ts):
                p = cul(np.array([tq]))[0]
                side = (-1.0, 1.0, -0.45)[k] * (1 if pi != 1 else -1) + r.normal(0, 0.08)
                ax = nv(np.array([side * 0.8, 0.62, 0.9]))     # standing up and out toward the camera, so the whole long pod shows
                q = p + np.array([0, 0.05, 0])
                self.tube(self.line_c([p, (p + q) * 0.5 + np.array([0, 0, 0.004]), q]), 0.005, 0.0045, stemp, 0.0, int(r.integers(1000)))
                pod(q, ax, 0.27 * r.uniform(0.94, 1.05) * (1.04 - 0.1 * k), 0.03 * r.uniform(0.95, 1.05))
            p = cul(np.array([0.88]))[0]; out = nv(np.array([0.25 * (1 - pi), 1.0, 0.4]))
            flower(p + out * 0.03, out, 0.045)

    def _khoai_mon(self, seed):
        """taro (khoai môn): 3 plants on the bắp spots; huge heart-shaped leaves held out on long fleshy stalks rising
        from the corm; stage 3 the BIG brown ringed corm sitting half out of the soil in front, with two small cormels"""
        r = self.r
        stage = seed % 4
        spots = self.tri()
        leafp = H('#1a4418', '#245a20', '#2e7228', '#3c8a32', '#50a042', '#76b866')
        und = H('#58825a', '#6a966a', '#82ac80', '#9ec29a', '#c2dabc')
        petp = H('#3a4a28', '#4a6232', '#5e7c3e', '#76964c', '#96b266')
        cormp = H('#2a1c12', '#3e2a1a', '#563c24', '#6e5030', '#88683e', '#a88656')
        def vein(col, P, N, A, B): return col
        def tleaf(o, az, Lp, R, lean=0.55):
            d = np.array([math.cos(az), math.sin(az) * 0.9, 0.0])
            top = o + d * Lp * 0.32 + np.array([0, 0, Lp])
            pc = self.line_c([o, o + d * Lp * 0.06 + np.array([0, 0, Lp * 0.55]), top])
            self.tube(pc, 0.017 * Lp / 0.36 + 0.005, 0.0065, petp, 0.0, int(r.integers(1000)))
            fn = nv(UP * 0.7 + d * lean + np.array([0, 0.3, 0]))
            self.pleaf(top, nv(d + np.array([0, 0, -0.85])), fn, R, leafp, und, lobes=3, depth=0.1, spread=0.9,
                       teeth=(0, 0.0), cup=0.05, ruffle=0.018, vk=0.38)
            return pc
        def corm(o, R, Hc):
            sd = int(r.integers(1000))
            def rf(t):
                t = np.clip(t, 0, 1)
                return R * np.sqrt(np.clip(np.sin(math.pi * (0.08 + 0.86 * t)), 0, 1)) * (1 - 0.35 * np.clip((t - 0.6) / 0.4, 0, 1)) + 1e-4
            def rings(col, P, N, A, B):
                ph = (A * 9.0) % 1.0
                col = col * (1 - 0.3 * np.exp(-((ph - 0.5) / 0.07) ** 2))[..., None]
                n_ = vnoise(P[..., 0] / 0.006, P[..., 2] / 0.004, sd)
                col = mix(col, A_(C('#b89a70')), np.clip((n_ - 0.6) / 0.3, 0, 1) * 0.28)      # dry fibres
                return mix(col, A_(C('#4a3a2a')), np.clip((0.02 - P[..., 2]) / 0.03, 0, 1) * 0.3)
            c0 = o + np.array([0, 0, -0.04]); c1 = o + np.array([0, 0.01, Hc])
            self.tube(self.line_c([c0, (c0 + c1) * 0.5 + np.array([0, 0.006, 0]), c1]), R, R, cormp, 0.0, sd, tint=rings, rfun=rf, zcut=0.0)
        if stage == 1:
            for o in spots:
                a0 = r.uniform(0, 6.28)
                for k in range(2):
                    tleaf(o, a0 + k * 2.6, 0.07 - 0.015 * k, 0.05 - 0.008 * k, lean=0.6)
            return
        nl, Lp, R = (4, 0.22, 0.11) if stage == 2 else (5, 0.36, 0.155)
        for pi, o in enumerate(spots):
            a0 = r.uniform(0, 6.28)
            if stage == 3:
                corm(o + np.array([0, 0.035, 0]), 0.078, 0.13)
                for s_ in (-1, 1):       # two small cormels at its sides
                    q = o + np.array([s_ * 0.085, 0.06, 0.0])
                    corm(q, 0.035, 0.05)
            base = o + np.array([0, 0.03, 0.1 if stage == 3 else 0.02])
            for j in range(nl):
                az = a0 + j * 2.39996
                if stage == 3 and math.sin(az) > 0.75: az += 1.0          # keep the corm in front clear
                tleaf(base, az, Lp * r.uniform(0.85, 1.05) * (1.08 if j == 0 else 1.0), R * r.uniform(0.9, 1.08), lean=0.5 + 0.1 * (j % 2))
            if stage == 3:        # one young rolled leaf rising in the middle
                q = base + np.array([0, -0.01, 0])
                self.tube(self.line_c([q, q + np.array([0.005, 0, Lp * 0.5]), q + np.array([0.01, 0.005, Lp * 0.72])]), 0.009, 0.006, petp, 0.0, int(r.integers(1000)))
                self.strap(self.line_c([q + np.array([0.01, 0.005, Lp * 0.7]), q + np.array([0.014, 0.01, Lp * 0.82]), q + np.array([0.012, 0.016, Lp * 0.9])]), 0.022, leafp, 0.0, fold=0.6, wprof=[0.6, 1.0, 0.9, 0.6, 0.3, 0.0])

    def _hull(self, col, P, N, A, B):
        rib = np.abs(np.cos(B * 2 * math.pi * 3))
        return col * (1 - 0.1 * np.clip((rib - 0.75) / 0.25, 0, 1))[..., None]

    # ------------------------------------------------------------------ broad leaves, bark
    def leaf(self, b, e, f, L, W, pal, und, key=0.0, droop=0.25, fold=0.12, ao=None, sd=None, veins=7, edge_k=0.8,
             gloss=0.35, prof=None, mid_k=0.3, tint=None, teeth=None):
        """an entire simple leaf (mango, citrus...) from b along e, its face toward f: lanceolate outline, folded along
        the midrib, tip drooping, pinnate veins, glossy top, matte paler underside. ao(P) -> 0..1 crown shade"""
        sd = int(self.r.integers(1000)) if sd is None else sd
        s = nv(np.cross(f, e)); f = nv(np.cross(e, s))
        pt = np.array([0, 0.06, 0.25, 0.5, 0.75, 0.92, 1.0]); pw = None if callable(prof) else np.array(prof or [0.0, 0.45, 0.85, 1.0, 0.78, 0.38, 0.0])
        tw = self.r.normal(0, 0.08)
        def geo(A, B):
            t = A; w = B * 2 - 1; hw = W * 0.5 * (prof(t) if callable(prof) else np.interp(t, pt, pw))
            if teeth is not None:      # serrated (saw) or wavy (wave) margin
                n_, am, kd = teeth; ph = (t * n_) % 1.0
                sw = ph if kd == 'saw' else 0.5 + 0.5 * np.cos(2 * math.pi * t * n_)
                hw = hw * (1 - am * sw * np.clip((t - 0.08) / 0.1, 0, 1) * np.clip((0.97 - t) / 0.1, 0, 1))
            return b + (e * (L * t)[..., None] + s * (hw * w)[..., None]
                        + f * (np.abs(w) * hw * fold * 2 - L * droop * t * t + tw * w * t * L * 0.3)[..., None])
        def sh(P, N, F, A, B):
            t = A; w = B * 2 - 1; lam = self.lam(N)
            sv = (0.12 + 0.85 * lam) * self.grain(P, W * 0.35, sd, 0.035)
            if ao is not None: sv = sv * (1 - ao(P))
            col = ramp(pal, np.clip(sv, 0, 1))
            col = np.where(F[..., None], col, ramp(und, np.clip(0.2 + 0.7 * lam, 0, 1) * (1 - (ao(P) if ao is not None else 0))))
            # midrib and pinnate veins running out to the margin
            col = mix(col, und[-1], np.exp(-(w / 0.05) ** 2) * mid_k * (t < 0.96))
            vv = np.abs(np.cos((t * veins * 1.0 - np.abs(w) * 0.9) * math.pi))
            col = mix(col, und[-1], np.clip((vv - 0.9) / 0.1, 0, 1) * 0.12 * (np.abs(w) > 0.08) * (np.abs(w) < 0.9))
            if tint is not None: col = tint(col, P, N, A, B)
            spec = (np.clip(N @ HALF, 0, 1) ** 22 * gloss + np.clip(N @ HALF, 0, 1) ** 5 * gloss * 0.12) * F
            return np.clip(col + spec[..., None] * np.array([0.95, 1.0, 0.9]), 0, 1)
        self.splat(geo, sh, b + e * L * 0.5 + TOCAM * key, edge_k=edge_k)

    def bark(self, pal, sd, cracks=0.35, scale=0.05):
        def tint(col, P, N, A, B):
            n = fbm(A * 6 + sd, B * 3, sd, 3)
            cr = np.abs(np.sin((B * 14 + n * 3) * math.pi))
            col = col * (0.88 + 0.24 * n)[..., None]
            return mix(col, pal[0], np.clip((0.12 - cr) / 0.12, 0, 1) * cracks)
        return tint

    # ------------------------------------------------------------------ xoài
    def _xoai(self, seed):
        self.r = r = np.random.default_rng((seed // 2) * 7919 + 4243); ripe = seed % 2 == 1   # same tree for unripe and ripe
        barkp = H('#2e241c', '#43362a', '#5c4c3c', '#76664f', '#938268')
        top = H('#1a4418', '#245a1e', '#317226', '#40892e', '#56a03a', '#72b64a', '#98cc64')
        und = H('#2e5426', '#3e6a30', '#52823c', '#6a9a4e', '#90b874')
        flush = H('#4a1a14', '#6e2a1a', '#8e4024', '#ae5e34', '#c8844c', '#e0aa70')
        fr_g = H('#1e4214', '#2c5a1a', '#3e7224', '#548a2e', '#72a23e', '#98ba5c')
        fr_y = H('#7a5410', '#a8761a', '#d49c26', '#eec03c', '#f8dc6c', '#fff0a8')
        cc = np.array([0.0, 0.05, 1.24]); RX, RZ = 0.92, 0.62
        def ao(P):
            q = (P - cc) / np.array([RX, RX * 0.9, RZ]); d = np.linalg.norm(q, axis=-1)
            facing = np.clip((q @ nv(LIGHT + TOCAM * 0.6)) / np.maximum(d, 1e-6), -1, 1)
            return np.clip(0.55 * (1 - d) + 0.15 * (0.3 - facing) + 0.3 * np.clip(-q[..., 2] - 0.1, 0, 1), 0, 0.55)
        lph = r.uniform(0, 6.28, 3)
        def lobe(u):     # an irregular crown: a few soft bulges and dips round the dome
            return 1 + 0.09 * math.sin(3 * math.atan2(u[1], u[0]) + lph[0]) + 0.06 * math.sin(5 * math.atan2(u[1], u[0]) + lph[1]) + 0.05 * math.sin(4 * u[2] + lph[2])
        # trunk and the main limbs fanning up into the crown
        sdb = int(r.integers(1000))
        tr = self.line_c([np.array([0, 0, 0.0]), np.array([0.02, 0.0, 0.3]), np.array([-0.02, 0.02, 0.55])])
        self.tube(tr, 0.11, 0.085, barkp, 0.0, sdb, tint=self.bark(barkp, sdb), rfun=lambda t: 0.1 - 0.03 * t + 0.03 * np.exp(-t * 14))
        limbs = []
        for k in range(5):
            a = k * 1.3 + r.normal(0, 0.2); d = np.array([math.cos(a), math.sin(a) * 0.8, 0.0])
            p0 = np.array([-0.02, 0.02, 0.5]); p1 = p0 + d * 0.3 + np.array([0, 0, 0.3]); p2 = p0 + d * 0.62 + np.array([0, 0, 0.6])
            self.tube(self.line_c([p0, p1, p2]), 0.06, 0.03, barkp, 0.0, sdb + k, tint=self.bark(barkp, sdb + k))
            limbs.append(p2)
        # leaf clusters on the dome: whorls of 8-12 long narrow leaves at the twig ends, drooping
        ncl = 300
        pts = []
        for i in range(ncl * 3):
            u = r.normal(size=3); u = u / np.linalg.norm(u)
            if u[2] < -0.45: continue
            pts.append(u)
            if len(pts) >= ncl: break
        for u in pts:
            c = cc + np.array([u[0] * RX, u[1] * RX * 0.9, u[2] * RZ]) * (0.35 + 0.67 * r.uniform() ** 0.45) * lobe(u)
            out = nv(np.array([u[0], u[1] * 0.9, u[2] * 0.8 + 0.15]))
            if u[2] < 0.15 and r.uniform() < 0.55:     # twigs under the crown, seen in the gaps
                lb = limbs[int(np.argmin([np.linalg.norm(l_ - c) for l_ in limbs]))]
                self.tube(self.line_c([lb, (lb + c) / 2 + np.array([0, 0, 0.06]), c]), 0.022, 0.008, barkp, 0.05, int(r.integers(1000)))
            n = int(r.integers(6, 9)); a0 = r.uniform(0, 6.28)
            is_flush = (not ripe) and r.uniform() < 0.0
            for j in range(n):
                a = a0 + j * 2 * math.pi / n + r.normal(0, 0.15)
                uu, vv = basis(out)
                e = nv(out * 0.4 + (math.cos(a) * uu + math.sin(a) * vv) * 0.8 + np.array([0, 0, -0.55]))
                fdir = nv(out + np.array([0, 0, 0.5]))
                L = r.uniform(0.2, 0.27); W = L * r.uniform(0.22, 0.27)
                self.leaf(c, e, fdir, L, W, top, und, droop=r.uniform(0.35, 0.65), ao=ao, gloss=0.2)
        # fruit: on long stalks hanging out of the lower crown, in twos and threes
        nf = 12 if ripe else 9
        for k in range(nf):
            a = -1.9 + 3.8 * (k + r.uniform(0.2, 0.8)) / nf      # spread over the whole front of the crown, middle too
            u = np.array([math.sin(a) * 0.9, math.cos(a) * 0.8 + 0.3, [-0.45, 0.1, 1.1][k % 3] + r.uniform(-0.15, 0.15)])
            u = u / np.linalg.norm(u)
            c = cc + np.array([u[0] * RX, u[1] * RX * 0.9, u[2] * RZ]) * lobe(u) * (1.14 if k % 3 == 2 else 1.02)
            for m in range(int(r.integers(1, 3))):
                st = c + np.array([0.05 * m, 0.02 * m, 0.0])
                hang = r.uniform(0.04, 0.07)
                bot = st + np.array([r.normal(0, 0.02), 0.02, -hang])
                self.tube(self.line_c([st, (st + bot) / 2 + np.array([0.01, 0, 0]), bot]), 0.006, 0.005, H('#3a4a18', '#5a6a24', '#7a8a34', '#9aa848'), 0.05, int(r.integers(1000)))
                pal = fr_y if ripe else fr_g
                fa = nv(np.array([r.normal(0, 0.25), 0.1, -1.0]))
                def blush(col, P, N, A, B, pal=pal):
                    k_ = np.clip((N @ nv(np.array([-0.4, 0.8, 0.6])) - 0.2) / 0.6, 0, 1) * (0.55 if ripe else 0.2)
                    return mix(col, A_(C('#d25a2a')) if ripe else A_(C('#8e6a2a')), k_ * np.clip((A - 0.15) / 0.5, 0, 1))
                self.ellip(bot + fa * 0.085, fa, 0.09, 0.058, pal, 0.12, spec=0.35 if ripe else 0.15, tint=blush, bulge=0.12)
        self.shadows.append((0.05, 0.05, 0.85, 0.66, 0.2))

    # ------------------------------------------------------------------ chuối (Link 17:13: redraw the live banana in the lotus kit)
    def bleaf(self, b, az, elev, L, W, droop, pal, und, tear=0.55, key=0.0, twist=0.0, dry=False):
        """a banana leaf: a long oblong blade on a pale midrib arching out of the crown and drooping, a slight V fold,
        wavy margin, fine parallel side veins running out obliquely, and wind tears along those veins (masked out)"""
        r = self.r; sd = int(r.integers(1000))
        e = np.array([math.cos(az) * math.cos(elev), math.sin(az) * math.cos(elev), math.sin(elev)])
        s = nv(np.cross(UP, e) + 1e-9); up = nv(np.cross(e, s))
        rot = math.cos(twist), math.sin(twist)
        s2 = s * rot[0] + up * rot[1]; up2 = nv(np.cross(e, s2))
        nsl = int(r.integers(14, 20)); pres = r.uniform(size=(64, 2)); w0 = r.uniform(0.12, 0.55, size=(64, 2))
        ph = r.uniform(0, 6.28)
        def mid(t):
            return b + e[None, None, :] * (L * t)[..., None] - UP * (droop * L * t ** 3)[..., None]      # arching out, the tip falling
        def geo(A, B):
            t = A; w = B * 2 - 1
            hw = W * 0.5 * np.clip(t / 0.16, 0, 1) ** 0.7 * np.clip((1.0 - t) / 0.09, 0, 1) ** 0.45 * (1 - 0.12 * np.clip((t - 0.5) / 0.5, 0, 1))
            wav = 0.003 * np.sin(t * 23 + ph) * np.abs(w) ** 3
            return (mid(t) + s2 * (hw * w)[..., None] + up2 * (np.abs(w) * hw * 0.3 + wav)[..., None]
                    - UP * (np.abs(w) ** 2 * hw * 0.18 * t)[..., None])
        age = self.leaf_age if not dry else 1.0
        youngc = A_(C('#b4dc5a')); brown = A_(C('#7a5a2e')); tan = A_(C('#b89a5e')); yell = A_(C('#c8c454'))
        tilt = r.uniform(-1, 1, size=(64, 2))
        def sh(P, N, F, A, B):
            t = A; w = B * 2 - 1; aw = np.abs(w); lam = self.lam(N)
            side = (w > 0).astype(int)
            q = t + 0.1 * aw                                   # along the side veins (they run out obliquely)
            kq = q * nsl; k = np.floor(kq).astype(int) % 64; fr = kq % 1.0
            torn = (pres[k, side] < tear) & (aw > w0[k, side] - 0.05)
            # every torn strip hangs at its own angle, so catches the light a little differently
            lam_s = lam + 0.11 * tilt[k, side] * torn * np.clip((aw - w0[k, side]) / 0.2 + 0.5, 0, 1)
            fine = np.abs(np.cos(q * 300 * math.pi)); major = np.abs(np.cos(q * 60 * math.pi))
            vein = np.clip((fine - 0.7) / 0.3, 0, 1) * 0.06 + np.clip((major - 0.9) / 0.1, 0, 1) * 0.12
            mot = fbm(t * 7.0 + sd, w * 2.2, sd) - 0.5                      # broad tone drift along the blade
            sv = (0.14 + 0.82 * lam_s) * (1 - vein) * (1 + 0.16 * mot) * self.grain(P, W * 0.25, sd, 0.03)
            col = ramp(pal, np.clip(sv, 0, 1))
            col = mix(col, youngc * np.clip(0.55 + 0.6 * lam_s, 0, 1.1)[..., None], (1 - age) * 0.35)    # young leaves yellower, paler
            ycl = np.clip((fbm(t * 5 + 3, w * 3, sd + 9) - 0.6) / 0.2, 0, 1) * age * np.clip(aw * 1.4 - 0.3, 0, 1)
            col = mix(col, yell * np.clip(0.5 + 0.6 * lam_s, 0, 1.1)[..., None], ycl * 0.3)              # yellowing patches on old leaves
            # underside: paler, waxy, the veins showing lighter
            ucol = ramp(und, np.clip(0.22 + 0.68 * lam, 0, 1)) * (1 + 0.08 * (fine - 0.5))[..., None]
            col = np.where(F[..., None], col, ucol)
            # the midrib: a thick pale yellow-green rib with a groove down its middle on top
            mr = np.exp(-(w / 0.045) ** 2)
            col = mix(col, (und[-1] * 0.92 + youngc * 0.08) * np.clip(0.7 + 0.4 * lam, 0, 1.15)[..., None], mr * 0.75)
            col = col * (1 - 0.25 * np.exp(-(w / 0.009) ** 2) * F)[..., None]
            # dried brown edges along the tears and the margin, more on old leaves
            hwid = 0.025 + 0.11 * np.clip((aw - w0[k, side]) / (1.0 - w0[k, side]), 0, 1)
            dcut = np.abs(np.abs(fr - 0.5) - hwid)
            nb = vnoise(t * 90, w * 9, sd + 5)
            burn = (torn & (aw > w0[k, side])) * np.clip((0.035 + 0.03 * nb - dcut) / 0.02, 0, 1) * (0.35 + 0.65 * age)
            burn = np.maximum(burn, np.clip((aw - (0.94 - 0.05 * nb * age)) / 0.04, 0, 1) * (0.25 + 0.75 * age))
            col = mix(col, mix(tan, brown, nb) * np.clip(0.6 + 0.5 * lam, 0, 1.1)[..., None], burn * 0.85)
            # a few small brown leaf spots
            sp = vnoise(t * 140 + sd, w * 16, sd + 11)
            col = mix(col, brown * 0.8, np.clip((sp - 0.9) / 0.04, 0, 1) * 0.6 * age)
            if dry:
                n_ = vnoise(P[..., 0] / 0.04, P[..., 2] / 0.04, sd)
                col = col * (0.85 + 0.25 * n_)[..., None]
            spec = np.clip(N @ HALF, 0, 1) ** 18 * 0.05 * F
            col = np.clip(col + spec[..., None], 0, 1)
            slit = (pres[k, side] < tear) & (np.abs(fr - 0.5) < hwid) & (aw > w0[k, side]) & (t > 0.14) & (t < 0.97)
            return col, ~slit
        self.splat(geo, sh, b + e * L * 0.45 + TOCAM * key, edge_k=0.8)
        return mid

    def _chuoi(self, seed):
        shape = seed // 2; ripe = seed % 2 == 1
        self.r = r = np.random.default_rng(shape * 6151 + 3301)        # the same plant unripe and ripe
        leafp = H('#1e5410', '#286a18', '#36821f', '#48982a', '#5eb036', '#7cc648', '#a0dc66')
        und = H('#4a7a26', '#5c9030', '#72a63c', '#8abc4c', '#a6d064', '#c4e488')
        dryp = H('#4a3a22', '#62502e', '#7c683e', '#968050', '#b09a66', '#c8b480')
        stemp = H('#3a5a24', '#4e7430', '#66903e', '#80a84e', '#9cc064', '#bcd888')
        Hs = 1.1 if shape == 0 else 1.18
        o = np.array([0.02, 0.0, 0.0]); top = np.array([0.0, 0.01, Hs])
        sds = int(r.integers(1000))
        self.leaf_age = 0.3
        def streak(col, P, N, A, B):
            # a banana pseudostem: overlapping leaf sheaths (seams with a lit lip beside each), fine lengthwise
            # striations, the dark maroon-brown blotches of the sheath skin, dried brown strips low down, soil at the foot
            n1 = vnoise(B * 9, A * 2.2, sds); n3 = vnoise(B * 16, A * 0.7, sds + 7)
            bl = fbm(B * 18, A * 7, sds + 21); sp = vnoise(B * 70, A * 30, sds + 23)
            sb = (B * 7 + 0.04 * np.sin(A * 9 + sds)) % 1.0
            col = col * (1 - 0.22 * np.clip((0.035 - sb) / 0.035, 0, 1) + 0.08 * np.clip((sb - 0.035) / 0.05, 0, 1) * np.clip((0.12 - sb) / 0.05, 0, 1))[..., None]
            col = col * (0.95 + 0.07 * np.abs(np.cos(B * 2 * math.pi * 60)))[..., None]        # fine striations
            col = mix(col, A_(C('#c8dc96')), np.clip((0.3 - n3) / 0.1, 0, 1) * 0.3)
            col = mix(col, A_(C('#4a2a22')), np.clip((bl - 0.6) / 0.06, 0, 1) * 0.7)          # maroon-brown blotches
            col = mix(col, A_(C('#3a2418')), np.clip((sp - 0.86) / 0.05, 0, 1) * 0.55)        # specks
            col = mix(col, A_(C('#8a6a40')), np.clip((n3 - 0.55) / 0.08, 0, 1) * 0.85 * np.clip(1.2 - A * 1.6, 0, 1))   # dried sheath strips
            col = mix(col, A_(C('#6a4a2c')), np.clip((n1 - 0.65) / 0.2, 0, 1) * 0.35 * np.clip(1.1 - A, 0, 1))
            return mix(col, A_(C('#5a4630')), np.clip((0.05 - P[..., 2]) / 0.05, 0, 1) * 0.55)   # soil splash at the foot
        stem = self.line_c([o, o + np.array([0.0, 0.0, Hs * 0.5]), top + np.array([0.0, 0.0, 0.14])])
        self.tube(stem, 0.11, 0.07, stemp, 0.0, sds, tint=streak,
                  rfun=lambda t: (0.12 - 0.045 * t + 0.03 * np.exp(-np.clip(t, 0, 1) * 9)) * (1 - 0.55 * np.clip((t - 0.85) / 0.15, 0, 1) ** 1.5))
        # dry sheaths peeling off the lower stem (left side, like the live tree)
        for k in range(2 + shape):
            a = math.pi * (0.85 + 0.25 * k) + r.normal(0, 0.1); d = np.array([math.cos(a), math.sin(a), 0.0])
            z0 = r.uniform(0.25, 0.55)
            p0 = o + d * 0.09 + np.array([0, 0, z0]); p1 = p0 + d * 0.05 + np.array([0, 0, -z0 * 0.55]); p2 = p1 + d * 0.06 + np.array([0, 0.02, -z0 * 0.4])
            self.strap(self.line_c([p0, p1, p2]), 0.07, dryp, 0.0, fold=0.4, wprof=[0.8, 1.0, 1.0, 0.9, 0.7, 0.4])
        # the crown: leaves from the top, the outer ones arching out wide to the sides and drooping, the inner ones climbing
        LV = ([(0.1, 0), (3.05, 0), (0.6, 1), (2.55, 1), (-0.5, 1), (3.7, 1), (4.75, 2), (1.25, 2), (4.25, 3), (1.95, 3)] if shape == 0 else
              [(3.1, 0), (0.05, 0), (2.5, 1), (0.65, 1), (-0.6, 1), (3.75, 2), (1.85, 2), (4.6, 2), (5.3, 1), (0.95, 3), (3.95, 3)])
        nl = len(LV)
        for j, (az0, tier) in enumerate(LV):
            az = az0 + r.normal(0, 0.06)
            inner = tier == 3
            fr = math.sin(az)        # > 0: toward the camera
            elev = ((1.25 if fr > 0.6 else 1.05) if inner else (0.6, 0.8, 0.95)[tier]) + r.normal(0, 0.05) + (0.05 if shape == 1 else 0.0)
            L = r.uniform(1.38, 1.52) * (0.8 if inner else 1.0); W = L * r.uniform(0.26, 0.29)
            droop = 0.42 if inner else (0.8, 0.62, 0.55)[tier] * r.uniform(0.92, 1.08) * (1.3 if fr > 0.6 else 1.0)
            p0 = top + np.array([0, 0, 0.06 - 0.05 * (nl - j) / nl])
            d = np.array([math.cos(az), math.sin(az), 0.0])
            pb = p0 + d * 0.26 + np.array([0, 0, 0.24 + (0.12 if inner else 0)])
            self.tube(self.line_c([p0, p0 + d * 0.06 + np.array([0, 0, 0.12]), pb]), 0.024, 0.014, stemp, 0.0, int(r.integers(1000)))
            self.leaf_age = 0.0 if inner else (0.45, 0.75, 1.0)[2 - tier] * r.uniform(0.85, 1.0)
            self.bleaf(pb, az, elev, L, W, droop, leafp, und, tear=0.35 if inner else 0.55, twist=r.choice([-1, 1]) * r.uniform(0.25, 0.6))
        cg = top + np.array([0.0, 0.0, 0.1])
        self.tube(self.line_c([cg, cg + np.array([0.02, 0.0, 0.25]), cg + np.array([0.08, 0.02, 0.42])]), 0.03, 0.012, leafp, 0.0, int(r.integers(1000)))
        # one old dry leaf hanging down along the stem
        dl = self.line_c([top + np.array([-0.08, 0.03, 0.02]), top + np.array([-0.17, 0.05, -0.12]), top + np.array([-0.17, 0.07, -0.42]), top + np.array([-0.14, 0.08, -0.66])])
        self.strap(dl, 0.12, dryp, 0.0, fold=0.35, wprof=[0.5, 0.9, 1.0, 1.0, 0.85, 0.5], gloss=0.03)
        # the bunch: a curved stalk out of the crown to the front right, then hanging straight; hands of fingers curling up
        # round the front of it, the purple heart (bắp chuối) at the bottom
        fing = H('#7a5a10', '#a8801a', '#d0a428', '#ecc23c', '#f8dc68', '#fff0a8') if ripe else H('#2c4a14', '#3e621c', '#527c26', '#6a9632', '#86ae46', '#a8c868')
        bx = np.array([0.22, 0.24, 0.0])
        ped = self.line_c([top + np.array([0.04, 0.05, 0.06]), top + np.array([0.13, 0.15, 0.03]), bx + np.array([0, 0, Hs - 0.05]),
                           bx + np.array([0, 0, Hs - 0.16])])
        self.tube(ped, 0.03, 0.024, stemp, 0.0, int(r.integers(1000)), tint=streak)
        rach = self.line_c([bx + np.array([0, 0, Hs - 0.14]), bx + np.array([0.03, 0.05, Hs - 0.45]), bx + np.array([0.03, 0.06, Hs - 0.74])])
        self.tube(rach, 0.022, 0.014, stemp, 0.0, int(r.integers(1000)), tint=streak)
        for h in range(4):
            c = rach(np.array([0.04 + 0.17 * h]))[0]
            nf = 7 - h
            rot = 0.25 * (h % 2 * 2 - 1)          # hands alternate round the stalk
            for f in range(nf):
                a = math.pi * 0.45 + rot + (f - (nf - 1) / 2) * (2.4 / 6) + r.normal(0, 0.08)
                out = np.array([math.cos(a), math.sin(a), 0.0])
                L = (0.29 - 0.02 * h) * r.uniform(0.85, 1.08)
                p0 = c + out * 0.026
                p1 = p0 + out * L * 0.42 + np.array([0, 0, -L * 0.04]); p2 = p0 + out * L * 0.8 + np.array([0, 0, L * 0.5])
                Rf = 0.031 - 0.002 * h
                def rf(t, Rf=Rf):
                    t = np.clip(t, 0, 1)
                    return Rf * np.clip(t / 0.16, 0, 1) ** 0.6 * np.clip((1 - t) / 0.2, 0, 1) ** 0.5 + 1e-4
                fh = r.uniform(0.9, 1.08); fsd = int(r.integers(1000))
                def tip(col, P, N, A, B, fh=fh, fsd=fsd):
                    col = col * fh * (1 - 0.1 * np.abs(np.sin(B * 2 * math.pi * 2.5)) ** 3)[..., None]       # the angled ridges
                    col = mix(col, A_(C('#5e8a2a')) * np.clip(col.mean(-1) * 1.6, 0.4, 1.2)[..., None], np.clip((0.2 - A) / 0.12, 0, 1) * (0.6 if ripe else 0.3))   # green neck
                    if ripe:
                        col = mix(col, A_(C('#5a3a14')), np.clip((vnoise(A * 40, B * 12, fsd) - 0.88) / 0.04, 0, 1) * 0.6)   # sugar specks
                    col = mix(col, A_(C('#4a3a24')), np.clip((A - 0.93) / 0.03, 0, 1) * 0.7)                       # dark tip
                    return mix(col, A_(C('#a89068')), np.clip((A - 0.975) / 0.02, 0, 1) * 0.8)                      # the dried flower
                self.tube(self.line_c([p0, p1, p2]), Rf, Rf, fing, 0.0, int(r.integers(1000)), tint=tip, rfun=rf)
        heart = H('#2a0614', '#46102a', '#661a3e', '#842a54', '#a0406c', '#bc6488')
        def bracts(col, P, N, A, B):
            # overlapping bracts: each a lit rounded lip over the shadowed edge of the next, a waxy grey-violet bloom,
            # fine lengthwise lines
            ph_ = (A * 6 + 0.45 * np.sin(B * 2 * math.pi * 1.5)) % 1.0
            col = col * (0.72 + 0.4 * ph_ ** 0.7)[..., None] * (1 - 0.3 * np.clip((0.06 - ph_) / 0.06, 0, 1))[..., None]
            view = np.abs(N @ TOCAM)
            col = mix(col, A_(C('#a888a8')), (1 - view) ** 2 * 0.45 + 0.08)
            return col * (0.95 + 0.06 * np.abs(np.cos(B * 2 * math.pi * 24)))[..., None]
        hc = rach(np.array([1.0]))[0] + np.array([0.01, 0.015, -0.11])
        self.ellip(hc, nv(np.array([0.05, 0.1, -1.0])), 0.13, 0.06, heart, 0.0, spec=0.04, tint=bracts)
        # a sucker (cây chuối con) at the foot, front left
        for q, sc in (((-0.2, 0.18), 1.0),) + ((((0.22, 0.2), 0.75),) if shape == 1 else ()):
            so = np.array([q[0], q[1], 0.0]); st = so + np.array([0, 0, 0.3 * sc])
            self.tube(self.line_c([so, so + np.array([0, 0, 0.1 * sc]), st]), 0.035 * sc, 0.022 * sc, stemp, 0.0, int(r.integers(1000)), tint=streak)
            for k in range(3):
                az = k * 2.1 + r.uniform(0, 1)
                self.bleaf(st, az, 1.25 - 0.12 * k, 0.42 * sc, 0.12 * sc, 0.3, leafp, und, tear=0.0, twist=0.15)


class Frame:
    def __init__(self, pa, kind, seed): self.m = Kit(kind, seed, pa)
    def paint(self): self.m.paint()


BBS = dict(lua=(-40, -64, 40, 16), bap=(-44, -70, 44, 16), xoai=(-56, -100, 56, 24), nep=(-42, -70, 42, 16), cachua=(-44, -66, 44, 16), catim=(-44, -60, 44, 16), carot=(-48, -58, 48, 16), bido=(-46, -50, 46, 18), duahau=(-46, -46, 46, 18), dua_leo=(-44, -60, 44, 16), khoai=(-46, -44, 46, 18), mia=(-48, -74, 48, 16), ot=(-48, -58, 48, 16), huong_duong=(-46, -62, 46, 16), xa_lach=(-46, -40, 46, 18), cai=(-48, -52, 48, 18), dau=(-48, -50, 48, 18), hanh=(-46, -52, 46, 16), hanh_tay=(-46, -54, 46, 18), rau_muong=(-46, -50, 46, 16), rau_ram=(-48, -46, 48, 16), sa=(-48, -56, 48, 16), gung=(-46, -52, 46, 18), nghe=(-46, -52, 46, 18), me=(-46, -56, 46, 16), dau_nanh=(-48, -52, 48, 18), dau_xanh=(-48, -52, 48, 18), dauphong=(-48, -52, 48, 18), bong_vai=(-48, -60, 48, 16), cham=(-48, -60, 48, 16), la_dua=(-50, -54, 50, 16), bau=(-48, -60, 48, 22), bi_dao=(-48, -60, 48, 22), kho_qua=(-48, -60, 48, 18), dau_rong=(-48, -60, 48, 18), dau_bap=(-48, -62, 48, 16), khoai_mon=(-50, -60, 50, 18), dau_den=(-48, -52, 48, 18), muop=(-48, -60, 48, 18), chuoi=(-62, -108, 62, 22))
FRAMES = [dict(key='lua%d' % s, kind='lua', seed=s) for s in (1, 2, 3)] + [dict(key='%s%d' % (k, s), kind=k, seed=s) for k in ('bap', 'nep', 'cachua', 'catim', 'carot', 'bido', 'duahau', 'dua_leo', 'khoai', 'mia', 'ot', 'huong_duong', 'xa_lach', 'cai', 'dau', 'hanh', 'hanh_tay', 'rau_muong', 'rau_ram', 'sa', 'gung', 'nghe', 'me', 'dau_nanh', 'dau_xanh', 'dauphong', 'bong_vai', 'cham', 'la_dua', 'bau', 'bi_dao', 'kho_qua', 'dau_rong', 'dau_bap', 'khoai_mon', 'dau_den', 'muop') for s in (1, 2, 3)] + [dict(key='x%d%d' % (s // 2, s % 2), kind='xoai', seed=s) for s in range(4)] + [dict(key='c%d%d' % (s // 2, s % 2), kind='chuoi', seed=s) for s in range(4)]


def render(fr, night):
    return co.to_image(co.render(Frame, dict(kind=fr['kind'], seed=fr['seed'], key=fr['key']), BBS[fr['kind']], night)), BBS[fr['kind']]


if __name__ == '__main__':
    from PIL import Image
    if sys.argv[1] == 'prev':
        night = len(sys.argv) > 3 and sys.argv[3] == 'n'
        keys = sys.argv[4].split(',') if len(sys.argv) > 4 else [f['key'] for f in FRAMES]
        ims = [render(f, night)[0] for f in FRAMES if f['key'] in keys]
        w = sum(i.width for i in ims) + 4 * len(ims); h = max(i.height for i in ims)
        o = Image.new('RGBA', (w, h), (40, 50, 30, 255) if night else (150, 170, 110, 255)); x = 0
        for im in ims: o.alpha_composite(im, (x, h - im.height)); x += im.width + 4
        o.save(sys.argv[2]); print(o.size)
    elif sys.argv[1] == 'one':      # one frame (day and night) to a pair of pngs, for parallel atlas builds
        fr = [f for f in FRAMES if f['key'] == sys.argv[2]][0]
        for night in (False, True):
            im, bb = render(fr, night); a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            im.crop((x0, y0, x1, y1)).save(os.path.join(sys.argv[3], '%s%s.png' % ('nd'[not night], fr['key'])))
            json.dump([bb[0] + x0 / co.RS, bb[1] + y0 / co.RS], open(os.path.join(sys.argv[3], '%s%s.json' % ('nd'[not night], fr['key'])), 'w'))
    elif sys.argv[1] == 'packone':  # Link 13:30: one file per crop (img/cay/<kind>.webp, day+night frames), loaded only when used
        d = sys.argv[2]; od = sys.argv[3]; os.makedirs(od, exist_ok=True); table = {}
        kinds = []
        for fr in FRAMES:
            if fr['kind'] not in kinds: kinds.append(fr['kind'])
        for kd in kinds:
            crops = []
            for night in 'dn':
                for fr in FRAMES:
                    if fr['kind'] != kd: continue
                    n = night + fr['key']; dx, dy = json.load(open(os.path.join(d, n + '.json')))
                    crops.append((n, Image.open(os.path.join(d, n + '.png')), dx, dy))
            x = y = rowh = 0; pos = {}; maxw = 2048
            for name, im, dx, dy in crops:
                if x + im.width > maxw: x = 0; y += rowh + 2; rowh = 0
                pos[name] = (x, y); x += im.width + 2; rowh = max(rowh, im.height)
            Wt = max(pos[n][0] + im.width for n, im, _, _ in crops); Ht = y + rowh
            out = Image.new('RGBA', (Wt, Ht), (0, 0, 0, 0))
            for name, im, dx, dy in crops:
                sx, sy = pos[name]; out.paste(im, (sx, sy))
                table[name] = [sx, sy, im.width, im.height, round(dx, 2), round(dy, 2), round(im.width / co.RS, 2), round(im.height / co.RS, 2), kd]
            out.save(os.path.join(od, kd + '.webp'), 'WEBP', quality=88, alpha_quality=100, method=6)
            print(kd, out.size)
        json.dump(table, open(sys.argv[4], 'w'), separators=(',', ':'))
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
