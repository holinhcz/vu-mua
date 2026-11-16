# 2026-11-16 Link "đéo vẽ được như bản đang có mà theo cách của dừa nước hả": the banana EXACTLY as it is in the game
# now (godot/caytrai/chuoi, made by src/chuoi/build.py), same plant, same leaves, same bunch, same suckers: the old
# model is built by the old code itself (same seeds, same numbers), only the painting is new, in the dừa nước way
# (caysen kit: per-pixel lit surfaces, dừa nước greens, no shine, no grey rim).
#   shape 0 = old build.plant(1, 'ft'), shape 1 = old build.plant(2, 'banana') (what d0x / d1x in the game are)
#   CO_RS=9 python3 chuoi3.py prev OUT.png [d|n] 01,11
#   CO_RS=9 python3 chuoi3.py one 01 DIR
import math, os, sys, json
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(HERE, '..', 'chuoi'))
import caysen
from caysen import Kit as CKit, H, A_, C, nv, ramp, mix, vnoise, fbm, TOCAM, UP
import co
import build as OB          # the old banana code (shape source only)
import chuoi as OC

OLD = [('ft', 1), ('banana', 2)]


def old_model(shape, ripe):
    """run the old plant() and catch what it builds instead of painting it"""
    leaves, spears, bunches = [], [], []
    keep = (OC.Leaf.items, OB.spear_item, OB.bunch_items)
    OC.Leaf.items = lambda self, pa, out: leaves.append(self)
    OB.spear_item = lambda pa, out, crown, lean, h: spears.append((np.array(crown, float), lean, h))
    OB.bunch_items = lambda pa, out, rng, p0, az, ripe_, hands=5, scale=1.0: bunches.append((np.array(p0, float), az, hands, scale, rng))
    try:
        kind, seed = OLD[shape]
        items, stems, mb, Hm, r0 = OB.plant(seed, kind, ripe, None)
    finally:
        OC.Leaf.items, OB.spear_item, OB.bunch_items = keep
    return leaves, spears, bunches, stems, Hm, r0


def nrm(v): return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-9)


def LEAFP_(): return {0: H('#265a12', '#33721a', '#448c22', '#58a42c', '#70ba38', '#8ece52', '#b0e078'),
         1: H('#163e10', '#215616', '#2d6e1c', '#3c8624', '#4f9e2e', '#68b63c', '#8ccc58'),       # dừa nước greens
         2: H('#3a4c14', '#50641c', '#687e26', '#829830', '#9eb03e', '#b8c654', '#d0d878'),
         3: H('#4a3a22', '#62502e', '#7c683e', '#968050', '#b09a66', '#c8b480')}
def UNDP_(): return {0: H('#466e26', '#5a862e', '#70a03a', '#8ab84a', '#a6ce64', '#c4e288'),
        1: H('#3a6424', '#4c7a2c', '#609236', '#78aa44', '#96c25c', '#b4d880'),
        2: H('#56682a', '#6c8034', '#869a42', '#a0b254', '#bac86c', '#d2dc8c'),
        3: H('#5a4a2c', '#726038', '#8c7848', '#a6925c', '#bea872', '#d4c08c')}
def PETP(): return H('#46622a', '#587834', '#6c8e40', '#84a650', '#9ebc66', '#bad282')
def STEMP(): return H('#3e5a26', '#527030', '#6a8a3e', '#84a250', '#a0ba66', '#c0d488')


class Kit(CKit):
    def __init__(self, kind, seed, pa):
        self.pa = pa; self.seed = seed; self.kind = kind
        self.SC = OB.KU / (29.0 * 1.45)                     # old model was 29 px/m, this kit 42 px/m: same size
        self.r = np.random.default_rng(seed * 7919 + 17)  # texture only; the shape comes from the old code
        self.items = []; self.shadows = []
        self._chuoi3(seed // 2, seed % 2 == 1)

    # ------------------------------------------------------------ one old leaf, painted per pixel
    def leaf3(self, lf):
        r = self.r; sd = int(r.integers(1000))
        pts, T, Bv, N, n, sb = lf.pts, lf.T, lf.B, lf.N, lf.n, lf.sb
        def ip(arr, s):
            f = np.clip(s * n, 0, n - 1e-6); i = f.astype(int); t = (f - i)[..., None]
            return arr[i] * (1 - t) + arr[i + 1] * t
        tv = {s_: np.array([t for t, g in lf.tears[s_]]) for s_ in (-1, 1)}
        tg = {s_: np.array([g for t, g in lf.tears[s_]]) for s_ in (-1, 1)}
        tdr = {s_: np.array(lf.sdroop[s_]) for s_ in (-1, 1)}
        def per_side(v, side, fn):
            out = np.zeros(v.shape)
            for s_ in (-1, 1):
                m = side == s_
                if m.any(): out[m] = fn(s_, v[m])
            return out
        def extra_of(v, side):
            return per_side(v, side, lambda s_, vv: tdr[s_][np.searchsorted(tv[s_], vv)] if len(tdr[s_]) else 0.0)
        def geo(A, B):
            v = A; w = B * 2 - 1; side = np.where(w >= 0, 1, -1); u = np.abs(w)
            rp = np.clip(np.minimum(v / 0.08, (1 - v) / 0.1), 0, 1)
            t = np.minimum(1.0, v + lf.vf * u ** 1.4 * rp)
            s = sb + t * (1 - sb)
            m = ip(pts, s); Bb = nrm(ip(Bv, s)); Nn = nrm(ip(N, s))
            t0 = np.where(side > 0, lf.side0[1], lf.side0[-1])
            tt = np.clip((t - t0) / (1 - t0), 0, 1)
            wp = 0.22 + 0.78 * np.sin(np.minimum(1, tt / 0.12) * math.pi / 2)
            wp = wp * np.where(tt > 0.8, np.sqrt(np.clip(1 - ((tt - 0.8) / 0.2) ** 2, 0, 1)), 1.0)
            wp = np.where(t < t0, 0.0, wp)
            ex = extra_of(v, side)
            acc = np.zeros(m.shape); st = 6
            for j in range(st):
                tau = (j + 0.5) / st * u
                fa = lf.fold + lf.curl * tau ** 2 + ex * tau - side * lf.twist
                acc += (Bb * (side * np.cos(fa))[..., None] - Nn * np.sin(fa)[..., None]) * (u / st)[..., None]
            return m + acc * (lf.W * wp)[..., None]
        age = lf.age
        pal, und = LEAFP_()[age], UNDP_()[age]
        youngc = A_(C('#b4dc5a')); brown = A_(C('#7a5a2e')); yell = A_(C('#c8c454'))
        tilt = r.uniform(-1, 1, size=(16, 2))
        def sh(P, Nn, F, A, B):
            v = A; w = B * 2 - 1; aw = np.abs(w); side = np.where(w >= 0, 1, -1); lam = self.lam(Nn)
            k = per_side(v, side, lambda s_, vv: np.searchsorted(tv[s_], vv)).astype(int)
            lam_s = lam + 0.09 * tilt[np.minimum(k, 15), (side > 0).astype(int)] * np.clip(aw * 2 - 0.4, 0, 1)   # every strip its own tilt
            q = v + 0.06 * aw ** 1.4                              # side veins run out obliquely to the margin
            fine = np.abs(np.cos(q * 100 * math.pi)); major = np.abs(np.cos(q * 25 * math.pi))
            vein = np.clip((fine - 0.7) / 0.3, 0, 1) * 0.06 + np.clip((major - 0.9) / 0.1, 0, 1) * 0.12
            mot = fbm(v * 7.0 + sd, w * 2.2, sd) - 0.5
            sv = (0.06 + 0.92 * lam_s) * (1 - vein) * (1 + 0.16 * mot) * self.grain(P, lf.W * 0.25, sd, 0.03)
            col = ramp(pal, np.clip(sv, 0, 1))
            if age == 0: col = mix(col, youngc * np.clip(0.55 + 0.6 * lam_s, 0, 1.1)[..., None], 0.12)
            if age >= 1:
                ycl = np.clip((fbm(v * 5 + 3, w * 3, sd + 9) - 0.62) / 0.2, 0, 1) * np.clip(aw * 1.4 - 0.3, 0, 1) * (0.25 if age == 1 else 0.6)
                col = mix(col, yell * np.clip(0.5 + 0.6 * lam_s, 0, 1.1)[..., None], ycl * 0.3)
            ucol = ramp(und, np.clip(0.22 + 0.68 * lam, 0, 1)) * (1 + 0.08 * (fine - 0.5))[..., None]
            col = np.where(F[..., None], col, ucol)
            mr = np.exp(-(w / 0.05) ** 2) * (1 - 0.5 * v)
            col = mix(col, und[-1] * np.clip(0.7 + 0.4 * lam, 0, 1.15)[..., None], mr * 0.7)
            col = col * (1 - 0.22 * np.exp(-(w / 0.01) ** 2) * F)[..., None]
            sp = vnoise(v * 140 + sd, w * 16, sd + 11)
            col = mix(col, brown * 0.8, np.clip((sp - 0.9) / 0.04, 0, 1) * (0.25 + 0.35 * min(age, 2) / 2))
            if age == 3:
                col = col * (0.85 + 0.25 * vnoise(v * 60, w * 8, sd))[..., None]
            col = np.clip(col * 0.94, 0, 1)                       # no shine; 0.94 = same mean brightness as dừa nước (measured)
            # the old tears, exactly where the old leaf had them: a slit opening toward the margin
            slit = np.zeros(v.shape, bool)
            for s_ in (-1, 1):
                for t_, g_ in zip(tv[s_], tg[s_]):
                    slit |= (side == s_) & (np.abs(v - t_) < g_ * 0.5 * aw ** 1.2)
            return col, ~slit
        self.splat(geo, sh, ip(pts, np.array([sb + 0.4 * (1 - sb)]))[0], edge_k=0.8, edge_w=2.4)   # Link 12:47 "viền mỏng quanh đâu": thin rim in the leaf own colour x0.8, 0.26 units wide = old chuoi SOFT_W/SOFT_K (Link v619)
        # the petiole: a pale round stalk out of the crown
        ps = np.linspace(0, sb + 0.02, 6)
        dead = age == 3
        self.tube(self.line_c([ip(pts, np.array([s]))[0] for s in ps]), 0.016 if dead else 0.022, 0.01 if dead else 0.013,
                  LEAFP_()[3] if dead else PETP(), 0.0, int(r.integers(1000)))

    def sheath(self, sds):
        def streak(col, P, N, A, B):
            n3 = vnoise(B * 16, A * 0.7, sds + 7); bl = fbm(B * 14, A * 6, sds + 21); sp = vnoise(B * 60, A * 26, sds + 23)
            sb = (B * 6 + 0.05 * np.sin(A * 8 + sds)) % 1.0
            col = col * (1 - 0.2 * np.clip((0.035 - sb) / 0.035, 0, 1) + 0.07 * np.clip((sb - 0.035) / 0.05, 0, 1) * np.clip((0.12 - sb) / 0.05, 0, 1))[..., None]
            col = col * (0.95 + 0.07 * np.abs(np.cos(B * 2 * math.pi * 55)))[..., None]
            col = mix(col, A_(C('#4a2c20')), np.clip((bl - 0.6) / 0.07, 0, 1) * 0.65)
            col = mix(col, A_(C('#36221a')), np.clip((sp - 0.87) / 0.05, 0, 1) * 0.5)
            col = mix(col, A_(C('#8c6c44')), np.clip((n3 - 0.56) / 0.08, 0, 1) * 0.8 * np.clip(1.0 - A * 1.7, 0, 1))
            return mix(col, A_(C('#5a4630')), np.clip((0.06 - P[..., 2]) / 0.06, 0, 1) * 0.6)
        return streak

    def stem(self, base, Hs, r0, young=False):
        bx, by = base; sds = int(self.r.integers(1000))
        o = np.array([bx, by, 0.0])
        self.tube(self.line_c([o, o + np.array([0, 0, Hs * 0.5]), o + np.array([0, 0, Hs])]), r0, r0, STEMP(), 0.0, sds,
                  tint=self.sheath(sds), rfun=lambda t: r0 * (1 - 0.34 * np.clip(t, 0, 1)) + r0 * 0.4 * np.clip(1 - np.clip(t, 0, 1) / 0.22, 0, 1) ** 2)

    def spear(self, crown, lean, h):
        # same curve as the old spear_item: the rolled new leaf leaning over to one side
        sd_ = 1.0 if lean[0] >= 0 else -1.0; h2 = h * 0.78
        pts = [crown + np.array([lean[0] * t + sd_ * 0.22 * h2 * t ** 2.2, lean[1] * t + 0.05 * t, h2 * t - 0.16 * h2 * t ** 3]) for t in np.linspace(0, 1, 8)]
        self.tube(self.line_c(pts), 0.034, 0.006, H('#3e7a1e', '#4e9226', '#62a832', '#7cbe42', '#9ad25c', '#bce284'), 0.0,
                  int(self.r.integers(1000)), rfun=lambda t: 0.006 + 0.03 * np.clip(1 - np.clip(t, 0, 1), 0, 1) ** 0.7)

    def bunch(self, p0, az, ripe, hands, scale, rng):
        # same geometry as the old bunch_items (same rng draws), painted per pixel
        d = np.array([math.cos(az), math.sin(az), 0.0]); up = np.array([0, 0, 1.0])
        p1 = p0 + d * 0.40 * scale + up * 0.20 * scale
        p2 = p0 + d * 0.56 * scale - up * 0.76 * scale
        bez = lambda t: (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2
        dbez = lambda t: OC.nv(2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1))
        self.tube(self.line_c([bez(t) for t in np.linspace(0, 1, 9)]), 0.02, 0.014, STEMP(), 0.0, int(self.r.integers(1000)))
        fing = (H('#c88e1e', '#d99c22', '#e9b02c', '#f7c934', '#fcd648', '#ffe468', '#fff09a') if ripe else      # 13:03 Link: ripe yellow = old 2D (#d99c22/#f7c934/#ffe468)
                H('#24420e', '#365a16', '#4a7420', '#5e8e2a', '#7aa63c', '#9cc05c'))
        nh = max(2, int(round(hands * 0.7))); t0, t1 = 0.3, 0.74; yv = np.array([0.0, 1.0, 0.0])
        for h in range(nh):
            t = t0 + (t1 - t0) * h / max(1, nh - 1)
            c = bez(t); T = dbez(t)
            X1 = OC.nv(np.cross(T, up)) if abs(T[2]) < 0.99 else np.array([1.0, 0, 0])
            nf = int(rng.integers(5, 7)) if h < nh - 1 else int(rng.integers(4, 5))
            Lf = (0.27 - 0.04 * h / max(1, nh - 1)) * scale
            rf = 0.04 * scale
            cdir = OC.nv(yv - (yv @ T) * T); cdir = OC.nv(cdir + X1 * (0.45 if h % 2 else -0.45))
            cside = OC.nv(np.cross(T, cdir))
            span = 2.7 + rng.uniform(-0.15, 0.15)
            for j in range(nf):
                fj = j / max(1, nf - 1) - 0.5
                phi = fj * span
                rad = cdir * math.cos(phi) + cside * math.sin(phi)
                b0 = c + rad * 0.045 * scale
                Lj = Lf * (1.0 - 0.22 * abs(fj) * 2)
                cl = [b0 + rad * Lj * (0.75 * tau - 0.12 * tau * tau) + cside * Lj * 0.35 * fj * tau * tau + up * Lj * 0.62 * tau ** 1.35 - T * Lj * 0.06 * tau
                      for tau in np.linspace(0, 1, 9)]
                R = rf * 0.85
                def rfun(tt, R=R):
                    tt = np.clip(tt, 0, 1)
                    return R * (0.5 + 0.5 * np.sin(np.pi * np.minimum(1, 0.12 + tt * 0.92)) ** 0.6) * np.clip((1 - tt) / 0.08, 0.35, 1) + 1e-4
                fh = self.r.uniform(0.92, 1.06); fsd = int(self.r.integers(1000))
                def tip(col, P, N, A, B, fh=fh, fsd=fsd):
                    col = col * fh * (1 - 0.1 * np.abs(np.sin(B * 2 * math.pi * 2.5)) ** 3)[..., None]
                    col = mix(col, A_(C('#5e8a2a')) * np.clip(col.mean(-1) * 1.6, 0.4, 1.2)[..., None], np.clip((0.15 - A) / 0.12, 0, 1) * (0.6 if ripe else 0.3))
                    if ripe: col = mix(col, A_(C('#5a3a14')), np.clip((vnoise(A * 40, B * 12, fsd) - 0.88) / 0.04, 0, 1) * 0.6)
                    return mix(col, A_(C('#4a3a24')), np.clip((A - 0.93) / 0.04, 0, 1) * 0.75)
                self.tube(self.line_c(cl), R, R, fing, 0.0, int(self.r.integers(1000)), tint=tip, rfun=rfun)
        Th = dbez(1.0)
        top = p2; bot = p2 + OC.nv(Th * 0.4 + np.array([0, 0, -1.0])) * 0.36 * scale
        heart = H('#6a1a3c', '#7d2248', '#8e2c58', '#a8396b', '#b84a7c', '#c75b8c')        # 13:03 Link: heart = old 2D (#7d2248/#a8396b/#c75b8c)
        def bracts(col, P, N, A, B):
            ph_ = (A * 6 + 0.45 * np.sin(B * 2 * math.pi * 1.5)) % 1.0
            col = col * (0.88 + 0.16 * ph_ ** 0.7)[..., None] * (1 - 0.22 * np.clip((0.06 - ph_) / 0.06, 0, 1))[..., None]
            view = np.abs(N @ TOCAM)
            col = mix(col, A_(C('#c87aa0')), (1 - view) ** 2 * 0.25)
            return col * (0.95 + 0.06 * np.abs(np.cos(B * 2 * math.pi * 24)))[..., None]
        ax = nv(top - bot)
        self.ellip((top + bot) / 2, ax, 0.18 * scale, 0.08 * scale, heart, 0.0, spec=0.0, tint=bracts, bulge=0.35)

    def _chuoi3(self, shape, ripe):
        leaves, spears, bunches, stems, Hm, r0 = old_model(shape, ripe)
        self.stem((0.0, 0.0), Hm, r0)
        for (b, hs, rr, young, _) in stems: self.stem(b, hs, rr, young=True)
        for lf in leaves: self.leaf3(lf)
        for sp in spears: self.spear(*sp)
        for (p0, az, hands, scale, rng) in bunches: self.bunch(p0, az, ripe, hands, scale, rng)


class Frame:
    def __init__(self, pa, kind, seed): self.m = Kit(kind, seed, pa)
    def paint(self): self.m.paint()


BB = (-80, -150, 80, 30)


def render(seed, night):
    return co.to_image(co.render(Frame, dict(kind='chuoi3', seed=seed), BB, night))


def seed_of(key): return int(key[0]) * 2 + int(key[1])


if __name__ == '__main__':
    from PIL import Image
    if sys.argv[1] == 'prev':
        night = len(sys.argv) > 3 and sys.argv[3] == 'n'
        keys = (sys.argv[4] if len(sys.argv) > 4 else '01').split(',')
        ims = [render(seed_of(k), night) for k in keys]
        w = sum(i.width for i in ims) + 4 * len(ims); h = max(i.height for i in ims)
        o = Image.new('RGBA', (w, h), (40, 50, 30, 255) if night else (150, 170, 110, 255)); x = 0
        for im in ims: o.alpha_composite(im, (x, h - im.height)); x += im.width + 4
        o.save(sys.argv[2]); print(o.size)
    elif sys.argv[1] == 'one':
        k = sys.argv[2]; od = sys.argv[3]
        for night in (False, True):
            im = render(seed_of(k), night); a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            im.crop((x0, y0, x1, y1)).save(os.path.join(od, '%s%s.png' % ('nd'[not night], k)))
            json.dump([BB[0] + x0 / co.RS, BB[1] + y0 / co.RS], open(os.path.join(od, '%s%s.json' % ('nd'[not night], k)), 'w'))
