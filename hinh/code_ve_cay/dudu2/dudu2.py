# 2026-11-16 Link "vẽ cây đu đủ": papaya redrawn in the lotus/caysen kit (per-pixel lit 3D surfaces, painted detail,
# thin own-colour edge, no shadow under the plant). Replaces the flat cairo src/dudu/dudu.py. Same footprint as the old
# godot/caytrai/dudu frames (~91 x 110 game units). Frames d<shape><ripe>.
#   CO_RS=9 python3 dudu2.py prev OUT.png [d|n] 01           (shape 0, ripe 1)
#   CO_RS=9 python3 dudu2.py one 01 DIR                      -> DIR/d01.png, n01.png + .json (top-left in game units)
import math, os, sys, json
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import caysen
from caysen import Kit as CKit, H, A_, C, nv, ramp, mix, vnoise, fbm, HALF, TOCAM, UP
import co


class Kit(CKit):
    def __init__(self, kind, seed, pa):
        self.pa = pa; self.seed = seed; self.kind = kind; self.SC = 1.0
        self.r = np.random.default_rng((seed // 2) * 5113 + 2207)        # same tree green and ripe
        self.items = []; self.shadows = []
        self._dudu(seed // 2, seed % 2 == 1)

    def _dudu(self, shape, ripe):
        r = self.r
        Ht = 1.95 if shape == 0 else 1.7
        lean = np.array([0.05, -0.02, 0.0]) if shape == 0 else np.array([-0.08, 0.0, 0.0])
        o = np.array([0.0, 0.0, 0.0]); top = o + lean + np.array([0.0, 0.0, Ht])
        trunk = self.line_c([o, o + lean * 0.3 + np.array([0, 0, Ht * 0.5]), top])
        barkp = H('#4a4a36', '#62624a', '#7c7c60', '#969676', '#aeae8c', '#c6c6a4')
        green_top = H('#3a5a20', '#4c7028', '#628a32', '#7aa23e', '#94b84e', '#b0cc6a')
        sdt = int(r.integers(1000))
        nsc = 26; ga = 2.39996
        def scars(col, P, N, A, B):
            # papaya trunk: soft grey-olive skin turning green near the crown, fine lengthwise grain, and the
            # crescent leaf scars left by fallen leaves on a spiral (sharper and closer together high up)
            g = np.clip((A - 0.62) / 0.3, 0, 1)
            col = mix(col, ramp(green_top, np.clip(col.mean(-1) * 1.25, 0, 1)), g * 0.85)
            col = col * (0.95 + 0.07 * np.abs(np.cos(B * 2 * math.pi * 26)))[..., None]
            col = col * (0.93 + 0.12 * fbm(A * 9 + sdt, B * 7, sdt, 3))[..., None]
            k = np.floor(A * nsc).astype(int); fr = A * nsc - k
            th = (k * ga) % (2 * math.pi) / (2 * math.pi)
            db = np.abs(((B - th) + 0.5) % 1.0 - 0.5)                    # angular distance to this scar's centre
            arc = fr - 0.45 - 1.6 * db ** 2                                  # a crescent curving up at the ends
            on = (np.abs(arc) < 0.07) & (db < 0.13)
            depth_ = np.clip(1 - np.abs(arc) / 0.07, 0, 1) * np.clip(1 - db / 0.13, 0, 1)
            col = mix(col, A_(C('#3a3424')), on * depth_ * (0.55 + 0.25 * A))
            lip = (arc > 0.07) & (arc < 0.11) & (db < 0.12)
            col = mix(col, A_(C('#c8c8a8')), lip * 0.35)
            return mix(col, A_(C('#4a3e2a')), np.clip((0.04 - P[..., 2]) / 0.04, 0, 1) * 0.6)       # soil at the foot
        self.tube(trunk, 0.085, 0.055, barkp, 0.0, sdt, tint=scars,
                  rfun=lambda t: 0.056 + 0.045 * (1 - np.clip(t, 0, 1)) ** 1.6 + 0.025 * np.exp(-np.clip(t, 0, 1) * 18))
        # ---- the crown: leaves on long hollow pale stalks, young ones up in the middle, old ones out and drooping
        leafp = H('#1a4a12', '#245e16', '#30761c', '#3e8e24', '#52a62e', '#6cbc3e', '#90d05a')
        und = H('#4a7a2c', '#5c8e34', '#70a240', '#88b850', '#a4cc6a', '#c2e08e')
        yel = H('#4a5414', '#646e1e', '#7e8a2a', '#9aa438', '#b4bc4c', '#ccd06c')
        petp = H('#6a7a3a', '#82924a', '#9aaa5c', '#b2c070', '#c8d488', '#dce6a4')
        NL = 15
        for j in range(NL):
            tier = j / (NL - 1)                     # 0 = oldest (low, drooping), 1 = youngest (centre, up)
            az = j * ga + r.normal(0, 0.12)
            fr = math.sin(az)
            front = fr > 0.25 and tier < 0.85     # (Link fix) front leaves stay, held up high over the fruit so the crown is round
            d = np.array([math.cos(az), math.sin(az), 0.0])
            elev = -0.15 + 1.25 * tier ** 1.2 + r.normal(0, 0.06)
            if front: elev = max(elev, 0.55) + 0.15
            Lp = (0.7 - 0.25 * tier) * r.uniform(0.9, 1.05)
            p0 = top + np.array([0, 0, -0.08 + 0.12 * tier]) + d * 0.04
            dirp = nv(d * math.cos(elev) + UP * math.sin(elev))
            p2 = p0 + dirp * Lp - UP * (0.06 + 0.1 * (1 - tier)) * Lp
            pm = p0 + dirp * Lp * 0.5 + UP * 0.03
            self.tube(self.line_c([p0, pm, p2]), 0.012, 0.008, petp, 0.0, int(r.integers(1000)))
            old = j == 0 and shape == 0
            R = (0.46 - 0.14 * tier) * r.uniform(0.92, 1.06)
            fo = nv(np.array([0, 0, 1.0]) + d * (0.35 + 0.5 * (1 - tier)) * (-1 if tier > 0.6 else 1) * 0.3 + TOCAM * 0.15)
            dl = nv(dirp * 0.8 - UP * (0.18 + 0.3 * (1 - tier)) + d * 0.25)
            if old: R *= 0.85
            self.pleaf(p2, dl, fo, R, yel if old else leafp, yel if old else und, lobes=7, depth=0.58, sub=0.5, spread=0.92,
                       cup=-0.32 - 0.2 * (1 - tier), ruffle=0.05, gloss=0.04, teeth=(0, 0), vk=0.45)
        # ---- the fruit packed round the trunk just under the crown, hanging, in tiers
        fruitG = H('#1e3e10', '#2c5418', '#3c6c20', '#4e842a', '#64983a', '#84b052', '#a8c870')
        fruitR = H('#7a3a08', '#a65010', '#cc6a18', '#e8862a', '#f6a444', '#ffc068', '#ffd894')
        tiers = [(0.0, 5), (0.17, 5), (0.33, 4)] if shape == 0 else [(0.0, 4), (0.17, 3)]
        for ti, (dz, n) in enumerate(tiers):
            for k in range(n):
                a = math.pi * 0.5 + (k - (n - 1) / 2) * (2 * math.pi / (n + 1.2)) + ti * 0.35 + r.normal(0, 0.08)
                rd = np.array([math.cos(a), math.sin(a), 0.0])
                c_top = top + lean * 0.0 + np.array([0, 0, -0.14 - dz]) + rd * 0.07
                L = 0.13 * r.uniform(0.9, 1.08); Rf = 0.072 * r.uniform(0.92, 1.05)
                ax = nv(rd * 0.55 - UP)
                c = c_top + ax * L
                # ripeness: lower/older tiers ripen first
                if ripe: rp = np.clip(0.85 - 0.45 * ti + r.normal(0, 0.2), 0, 1)
                else: rp = np.clip(0.08 - 0.05 * ti + r.normal(0, 0.05), 0, 1)
                sd = int(r.integers(1000))
                def tint(col, P, N, A, B, rp=rp, sd=sd, c=c, ax=ax, L=L):
                    # A = 0 at the stalk end... ellip runs along ax: A in 0..1 from c+ax*a (tip) to c-ax*a (stalk)
                    lam = self.lam(N)
                    g = ramp(fruitG, np.clip(0.14 + 0.82 * lam, 0, 1)); y = ramp(fruitR, np.clip(0.14 + 0.82 * lam, 0, 1))
                    tipk = 1 - A                                     # the tip (lower end) turns first
                    streak = vnoise(B * 10, A * 2.5, sd)
                    k_ = np.clip((rp * 1.5 - (1 - tipk) * 0.9 + (streak - 0.5) * 0.6) / 0.35, 0, 1)
                    out = mix(g, y, k_)
                    rib = np.abs(np.cos(B * 2 * math.pi * 2.5))
                    out = out * (0.92 + 0.1 * np.clip((rib - 0.6) / 0.4, 0, 1))[..., None]          # 5 soft ribs
                    out = out * (0.95 + 0.08 * vnoise(A * 30, B * 40, sd + 3))[..., None]
                    return mix(out, A_(C('#4a5a24')), np.clip((A - 0.93) / 0.06, 0, 1) * 0.6)        # the stalk end
                self.ellip(c, ax, L, Rf, fruitG, 0.04, spec=0.12, tint=tint, bulge=0.18)
        # a few cream flowers in the leaf axils
        for k in range(4):
            a = r.uniform(0.3, 2.8); rd = np.array([math.cos(a), math.sin(a), 0.0])
            p = top + np.array([0, 0, -0.04]) + rd * 0.08
            self.ellip(p, nv(rd + UP * 0.3), 0.022, 0.012, H('#b8b07a', '#d4cc98', '#ece6bc', '#fbf8e2'), 0.06, spec=0.05)


class Frame:
    def __init__(self, pa, kind, seed): self.m = Kit(kind, seed, pa)
    def paint(self): self.m.paint()


BB = (-58, -128, 58, 10)


def render(seed, night):
    return co.to_image(co.render(Frame, dict(kind='dudu', seed=seed), BB, night))


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
