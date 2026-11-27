# 2026-11-16 Link "vẽ cây xoài": the mango tree drawn new (not the old ball of leaves). Lotus-kit rendering: per-pixel
# light and shade, deep shade inside the crown, sun-lit clumps upper left, no shine, thin own-colour edge.
# Colours = the old in-game mango (caysen _xoai palettes). Frames d<shape><ripe>.
#   CO_RS=3 python3 xoai2.py prev OUT.png [d|n] 00,01
import math, os, sys, json
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import caysen
from caysen import Kit as CKit, H, A_, C, nv, ramp, mix, vnoise, fbm, TOCAM, UP
from hoaco import basis
import co

SUN = nv(np.array([-0.6, 0.45, 0.72]))


class Kit(CKit):
    def __init__(self, kind, seed, pa):
        self.pa = pa; self.seed = seed; self.kind = kind; self.SC = 0.73   # Link 11-26: same size as the old mango
        self.r = np.random.default_rng((seed // 2) * 7351 + 89)
        self.items = []; self.shadows = []
        self._xoai(seed // 2, seed % 2 == 1)

    def bark2(self, cf, rfun, pal, sd, flat=False):
        """matte bark: the sun only a soft wrap, the detail from the bark (lengthwise fissures, flakes, grey patches)"""
        def frame(t):
            c = cf(t); e = 1e-3
            T = cf(np.clip(t + e, 0, 1)) - cf(np.clip(t - e, 0, 1)); T = T / np.maximum(np.linalg.norm(T, axis=-1, keepdims=True), 1e-9)
            n1 = np.cross(T, np.array([0, 0, 1.0])); n1 = np.where(np.linalg.norm(n1, axis=-1, keepdims=True) < 1e-3, np.array([1.0, 0, 0]), n1)
            n1 = n1 / np.maximum(np.linalg.norm(n1, axis=-1, keepdims=True), 1e-9)
            return c, n1, np.cross(T, n1)
        def geo(A, B):
            c, n1, n2 = frame(A); th = (B * 2 * math.pi)[..., None]
            rough = 1 + 0.05 * (vnoise(B * 14, A * 10, sd + 4) - 0.5)
            out = c + (np.cos(th) * n1 + np.sin(th) * n2) * (rfun(A) * rough)[..., None]
            if flat: out = np.concatenate([out[..., :2], np.maximum(out[..., 2:], 0.0)], axis=-1)   # foot cut level with the ground
            return out
        def sh(P, N, F, A, B):
            lam = self.lam(N); light = 0.6 + 0.4 * lam
            fis = np.abs(np.sin((B * 16 + 1.5 * fbm(A * 4, B * 3, sd, 3)) * math.pi))           # lengthwise fissures
            g = vnoise(B * 90, A * 60, sd + 1)
            tex = 0.55 + 0.2 * (g - 0.5) + 0.25 * (fbm(B * 6, A * 8, sd + 2, 3) - 0.5)
            col = ramp(pal, np.clip(tex * light * 1.15, 0, 1))
            col = col * (1 - 0.45 * np.clip((0.18 - fis) / 0.18, 0, 1))[..., None]
            col = mix(col, A_(C('#6e6a60')) * light[..., None], np.clip((fbm(A * 5, B * 4, sd + 9) - 0.58) / 0.14, 0, 1) * 0.35)
            return col
        self.splat(geo, sh, cf(np.array([0.5]))[0], edge_k=0.8)

    def _xoai(self, shape, ripe):
        r = self.r
        barkp = H('#2e241c', '#43362a', '#5c4c3c', '#76664f', '#938268')
        top = H('#163c14', '#1a4418', '#245a1e', '#317226', '#40892e', '#56a03a', '#72b64a', '#98cc64')
        und = H('#2e5426', '#3e6a30', '#52823c', '#6a9a4e', '#90b874')
        fr_g = H('#1e4214', '#2c5a1a', '#3e7224', '#548a2e', '#72a23e', '#98ba5c')
        fr_y = H('#7a5410', '#a8761a', '#d49c26', '#eec03c', '#f8dc6c', '#fff0a8')

        # nháp 9 (Link 11-26 nhận xét): broad irregular dome made of overlapping DRooping leaf tufts (twig ends), gaps
        # in the outline, each clump lit on its sun side and dark in its belly, curved trunk with a flared foot,
        # fork + limbs open under the crown, fruit in hanging clusters of 2-4 coming out from inside the crown edge
        W0 = 1.2 if shape == 0 else 1.05
        Hf = 0.8 if shape == 0 else 0.7
        base_z = Hf + 0.7
        a0 = r.uniform(0, 6.28)
        cl = [(np.array([r.normal(0, 0.05), -0.05, base_z + 0.72]), 0.5)]
        nring = 9
        for k in range(nring):
            if r.uniform() < 0.12: continue                    # a missing clump = a notch in the outline
            a = a0 + k * 2 * math.pi / nring + r.normal(0, 0.18)
            rr = W0 * r.uniform(0.62, 0.82)
            cl.append((np.array([math.cos(a) * rr, math.sin(a) * rr * 0.85, base_z + 0.25 + r.uniform(-0.12, 0.18)]), r.uniform(0.32, 0.5)))
        for k in range(5):
            a = a0 + 0.4 + k * 2 * math.pi / 5 + r.normal(0, 0.25)
            rr = W0 * r.uniform(0.3, 0.45)
            cl.append((np.array([math.cos(a) * rr, math.sin(a) * rr * 0.85, base_z + 0.55 + r.uniform(-0.05, 0.12)]), r.uniform(0.36, 0.46)))
        CC = np.array([0.0, 0.0, base_z + 0.35])
        S = self.SC
        def ao(P):
            P = P / S
            q = (P - CC) / np.array([W0 * 1.1, W0, 0.8]); d = np.linalg.norm(q, axis=-1)
            face = (q @ SUN) / np.maximum(d, 1e-6)
            under = np.clip(-(P[..., 2] - base_z - 0.1) / 0.3, 0, 1)
            return np.clip(0.14 + 0.6 * (1 - d) + 0.3 * (0.2 - face) + 0.14 * np.clip(-face, 0, 1) + 0.4 * under, 0.16, 0.5)   # 11-26: shade lifted to match dừa nước/chuối   # Link 11-26: sun side not so bright
        # trunk: flared foot, a gentle bend, bark
        sdb = int(r.integers(1000))
        lean = r.normal(0, 0.06); bend = r.choice([-1, 1]) * r.uniform(0.035, 0.06)
        fork = np.array([lean, 0.02, Hf])
        tr = self.line_c([np.array([0, 0, -0.08]), np.array([0, 0, 0.14]), np.array([lean * 0.3 + bend, 0.0, Hf * 0.5]), fork])   # Link 11-26: foot stands straight on the ground
        self.bark2(tr, lambda t: 0.1 - 0.02 * np.clip(t, 0, 1) + 0.055 * np.exp(-np.clip(t - 0.06, 0, 1) * 9), barkp, sdb, flat=True)
        for k in range(3):                                      # three limbs out of the fork, each splitting again
            a = a0 + 0.3 + k * 2.1 + r.normal(0, 0.2)
            d = np.array([math.cos(a), math.sin(a) * 0.85, 0])
            e = fork + d * W0 * 0.42 + np.array([0, 0, 0.5])
            self.bark2(self.line_c([fork - np.array([0, 0, 0.06]), fork + d * 0.2 + np.array([0, 0, 0.16]), e]), lambda t: 0.07 - 0.03 * np.clip(t, 0, 1), barkp, sdb + k + 1)
            for (c, R) in cl[1:]:
                if (c[:2] - e[:2]) @ d[:2] > -0.25 and np.linalg.norm(c[:2] - e[:2]) < W0 * 0.7:
                    self.bark2(self.line_c([e, (e + c) / 2 + np.array([0, 0, 0.05]), c - np.array([0, 0, R * 0.25])]), lambda t: 0.04 - 0.022 * np.clip(t, 0, 1), barkp, int(r.integers(1000)))
        # leaf tufts: at each twig end 8-11 long leaves fanning OUT and hanging DOWN (half fan, not a star)
        for ci, (c, R) in enumerate(cl):
            n_t = int(round(14 * (R / 0.45) ** 2)) + 3
            def aoc(P0, c=c, R=R):
                P = P0 / S; q = (P - c) / R; dq = np.linalg.norm(q, axis=-1)
                fc = (q @ SUN) / np.maximum(dq, 1e-6)
                belly = np.clip((c[2] + R * 0.2 - P[..., 2]) / R, 0, 1)
                return np.clip(ao(P0) + 0.24 * (0.15 - fc) + 0.1 * np.clip(-fc, 0, 1) + 0.32 * belly ** 1.2 - 0.05, 0.16, 0.52)
            for i in range(n_t):
                u = r.normal(size=3); u = u / np.linalg.norm(u)
                if u[2] < -0.25: u[2] = -u[2] * 0.6
                p = c + u * np.array([R, R * 0.9, R * 0.72]) * r.uniform(0.7, 1.0)
                oh = nv(np.array([u[0], u[1], 0]) + np.array([1e-3, 0, 0]))
                side = nv(np.cross(UP, oh))
                n = int(r.integers(8, 12)); spread = r.uniform(1.0, 1.4)
                for j in range(n):
                    s_ = (j / (n - 1) - 0.5) * 2 * spread + r.normal(0, 0.08)
                    dn_ = r.uniform(0.05, 0.38) + 0.2 * abs(s_) - 0.35 * max(u[2], 0)
                    e = nv(oh * math.cos(s_ * 0.9) + side * math.sin(s_ * 0.9) * 1.0 + UP * (-dn_) + u * 0.25)
                    fdir = nv(UP * 0.8 + oh * 0.3)
                    Lf = r.uniform(0.34, 0.44); Wl = Lf * r.uniform(0.2, 0.24)
                    self.leaf(p, e, fdir, Lf, Wl, top, und, droop=r.uniform(0.25, 0.45), ao=aoc, gloss=0.0, veins=8, mid_k=0.35)
        # fruit: clusters of 2-4 on a long stalk that starts INSIDE the crown edge (front half) and hangs below it
        pal = fr_y if ripe else fr_g
        stalkp = H('#3a4a18', '#5a6a24', '#7a8a34', '#9aa848')
        fronts = [(c, R) for (c, R) in cl[1:] if math.sin(math.atan2(c[1], c[0])) > -0.5 and c[2] < base_z + 0.5]
        r.shuffle(fronts)
        jobs = [(c, R, 0) for (c, R) in fronts[:6 if shape == 0 else 5]]
        faces = [(c, R) for (c, R) in cl if c[1] > -0.15]          # clumps facing the camera: fruit over the crown face
        r.shuffle(faces)
        jobs += [(c, R, 1) for (c, R) in faces[:0]]   # face fruit came out cut by leaves (nháp 12): off
        for (c, R, mode) in jobs:
            ah = math.atan2(c[1], c[0]) + r.normal(0, 0.4)
            if mode == 0:
                st = c + np.array([math.cos(ah) * R * 0.45, math.sin(ah) * R * 0.45 + 0.1, -R * 0.15])
                knot = st + np.array([math.cos(ah) * 0.05 + r.normal(0, 0.02), 0.06, -(R * 0.6 + r.uniform(0.1, 0.18))])
            else:                                                     # out of the leaves on the front face, short stalk
                st = c + np.array([r.normal(0, R * 0.3), R * 0.95, r.uniform(-0.35, 0.05) * R])
                knot = st + np.array([r.normal(0, 0.02), 0.2, -r.uniform(0.1, 0.16)])
            self.tube(self.line_c([st, (st + knot) / 2 + np.array([0.015, 0.01, 0.0]), knot]), 0.007, 0.005, stalkp, 0.0, int(r.integers(1000)))
            n_f = int(r.integers(2, 5)); b0 = r.uniform(0, 6.28)
            for m in range(n_f):
                ang = b0 + m * 2 * math.pi / n_f
                off = np.array([math.cos(ang) * 0.12, math.sin(ang) * 0.096, -0.05 * (m % 2)])
                top_ = knot + off * 0.6 + np.array([0, 0, -0.01])
                self.tube(self.line_c([knot, (knot + top_) / 2, top_]), 0.004, 0.004, stalkp, 0.0, int(r.integers(1000)))
                fa = nv(np.array([off[0] * 3 + r.normal(0, 0.15), off[1] * 3 + 0.05, -1.0]))
                sd = int(r.integers(1000))
                def tint(col, P, N, A, B, sd=sd):
                    view = np.abs(N @ TOCAM)
                    col = col * (0.5 + 0.5 * np.clip(view, 0, 1) ** 0.5)[..., None]
                    col = col * (0.95 + 0.08 * vnoise(A * 20, B * 30, sd))[..., None]
                    k_ = np.clip((N @ nv(np.array([-0.4, 0.8, 0.6])) - 0.2) / 0.6, 0, 1) * (0.5 if ripe else 0.15)
                    return mix(col, A_(C('#d25a2a')) if ripe else A_(C('#8e6a2a')), k_ * np.clip((A - 0.15) / 0.5, 0, 1))
                self.ellip(top_ + fa * 0.12, fa, 0.126, 0.082,   # Link 11-26: fruit a bit bigger
                           pal, 0.0, spec=0.0, tint=tint, bulge=0.2)

class Frame:
    def __init__(self, pa, kind, seed): self.m = Kit(kind, seed, pa)
    def paint(self): self.m.paint()


BB = (-75, -120, 75, 12)


def render(seed, night):
    return co.to_image(co.render(Frame, dict(kind='xoai2', seed=seed), BB, night))


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
        o.convert('RGB').save(sys.argv[2]); print(o.size)
    elif sys.argv[1] == 'one':
        k = sys.argv[2]; od = sys.argv[3]
        for night in (False, True):
            im = render(seed_of(k), night); a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            im.crop((x0, y0, x1, y1)).save(os.path.join(od, '%s%s.png' % ('nd'[not night], k)))
            json.dump([BB[0] + x0 / co.RS, BB[1] + y0 / co.RS], open(os.path.join(od, '%s%s.json' % ('nd'[not night], k)), 'w'))
