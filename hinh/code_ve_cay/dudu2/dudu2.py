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

    def bark2(self, cf, rfun, pal, sd, flat=False, tint=None):
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
            col = col * (1 - 0.15 * np.clip((0.18 - fis) / 0.18, 0, 1))[..., None]   # papaya: smooth skin, faint grain
            col = mix(col, A_(C('#6e6a60')) * light[..., None], np.clip((fbm(A * 5, B * 4, sd + 9) - 0.58) / 0.14, 0, 1) * 0.35)
            if tint is not None: col = tint(col, P, N, A, B)
            return col
        self.splat(geo, sh, cf(np.array([0.5]))[0], edge_k=0.8)

    def trunk_dd(self, cf, rfun, Lt, sd, green_top):
        """papaya trunk (11-26 redo): smooth pale grey-green skin, separate heart-shaped leaf scars on a spiral
        (raised rim, dark sunken centre, denser and greener toward the crown), root lumps at the foot"""
        nsc = 72; ga = 2.39996
        def frame(t):
            c = cf(t); e = 1e-3
            T = cf(np.clip(t + e, 0, 1)) - cf(np.clip(t - e, 0, 1)); T = T / np.maximum(np.linalg.norm(T, axis=-1, keepdims=True), 1e-9)
            n1 = np.cross(T, np.array([0, 0, 1.0])); n1 = np.where(np.linalg.norm(n1, axis=-1, keepdims=True) < 1e-3, np.array([1.0, 0, 0]), n1)
            n1 = n1 / np.maximum(np.linalg.norm(n1, axis=-1, keepdims=True), 1e-9)
            return c, n1, np.cross(T, n1)
        def hpos(A):                      # scar coordinate: closer together high up
            return 1 - (1 - np.clip(A, 0, 1)) ** 1.25
        def scar(A, B):
            """-> (inside 0..1 , rim 0..1, centre 0..1) of the nearest scar"""
            h = hpos(A) * nsc; best_in = np.zeros_like(A); best_rim = np.zeros_like(A); best_c = np.zeros_like(A)
            r0 = rfun(A)
            for dk in (-1, 0, 1):
                k = np.floor(h).astype(int) + dk
                th = (k * ga) % (2 * math.pi) / (2 * math.pi)
                du = (((B - th) + 0.5) % 1.0 - 0.5) * 2 * math.pi * r0        # metres round the trunk
                dv = (h - k - 0.5) / nsc * Lt                                 # metres up (approx.)
                sz = 0.021 + 0.01 * np.clip(1 - A, 0, 1)                       # older scars lower down, a bit wider
                w = sz * 1.15; hh = sz * 0.7
                # heart / shield: wide rounded top, narrowing to a point below
                yy = dv / hh; xx = du / w
                half = np.where(yy > 0, np.sqrt(np.clip(1 - yy * yy, 0, 1)), np.clip(1 + yy * 0.8, 0, 1))
                inside = np.clip((half - np.abs(xx)) / 0.18, 0, 1) * (yy > -1.25) * (yy < 1)
                dd = np.sqrt(xx * xx + (yy * 1.2) ** 2)
                rim = np.clip(1 - np.abs(half - np.abs(xx)) / 0.16, 0, 1) * (yy > -1.25) * (yy < 1.05)
                cen = np.clip(1 - dd / 0.55, 0, 1)
                fresh = (k >= 0) & (k < nsc)
                best_in = np.maximum(best_in, inside * fresh); best_rim = np.maximum(best_rim, rim * fresh); best_c = np.maximum(best_c, cen * inside * fresh)
            return best_in, best_rim, best_c
        def geo(A, B):
            c, n1, n2 = frame(A); th = (B * 2 * math.pi)[..., None]
            r = rfun(A)
            roots = 1 + 0.07 * np.exp(-np.clip(A, 0, 1) * 9) * (0.55 + 0.45 * np.cos(B * 2 * math.pi * 5 + 1.3 * vnoise(B * 5, A, sd)))
            si, srim, sc_ = scar(A, B)
            bump = 1 + 0.06 * srim - 0.03 * sc_ + 0.012 * (vnoise(B * 22, A * 30, sd + 2) - 0.5)
            out = c + (np.cos(th) * n1 + np.sin(th) * n2) * (r * roots * bump)[..., None]
            return np.concatenate([out[..., :2], np.maximum(out[..., 2:], 0.0)], axis=-1)
        skin = H('#505a40', '#667052', '#7c8866', '#929e78', '#a6b08a', '#b8c09c')
        scd = H('#3e3a2a', '#544e3a', '#6a644c')
        def sh(P, N, F, A, B):
            lam = self.lam(N); light = 0.22 + 0.78 * np.clip(lam, 0, 1) ** 1.15
            mott = 0.9 + 0.16 * (fbm(A * 7, B * 5, sd + 5, 3) - 0.5) + 0.05 * (vnoise(B * 60, A * 80, sd + 6) - 0.5)
            col = ramp(skin, np.clip(light * mott * 0.95, 0, 1))
            g = np.clip((A - 0.55) / 0.35, 0, 1) ** 1.3                                  # green toward the crown
            col = mix(col, ramp(green_top, np.clip(light * 0.95, 0, 1)), g * 0.8)
            si, srim, sc_ = scar(A, B)
            col = mix(col, ramp(scd, np.clip(light * 0.9, 0, 1)), si * (0.25 + 0.45 * sc_) * (1 - g * 0.5))
            col = mix(col, ramp(skin, np.clip(light * 1.05, 0, 1)), srim * 0.35)
            dots = (vnoise(B * 260, A * 300, sd + 7) > 0.72) * sc_ * si                # the little vascular dots in a scar
            col = col * (1 - 0.3 * dots)[..., None]
            return mix(col, A_(C('#4a3e2a')), np.clip((0.03 - P[..., 2]) / 0.03, 0, 1) * 0.5)
        self.splat(geo, sh, cf(np.array([0.5]))[0], edge_k=0.8)

    def _dudu(self, shape, ripe):
        r = self.r
        Ht = 1.95 if shape == 0 else 1.7
        lean = np.array([0.05, -0.02, 0.0]) if shape == 0 else np.array([-0.08, 0.0, 0.0])
        o = np.array([0.0, 0.0, 0.0]); top = o + lean + np.array([0.0, 0.0, Ht])
        bend_ = np.array([0.05 if shape == 0 else -0.04, 0.02, 0.0])
        trunk = self.line_c([o, o + lean * 0.3 + bend_ + np.array([0, 0, Ht * 0.5]), top])
        barkp = H('#5a5a48', '#727260', '#8a8a74', '#a2a28a', '#b8b8a0', '#cecdb6')   # 11-26 Link: lighter (was too dark grey)
        green_top = H('#3a5a20', '#4c7028', '#628a32', '#7aa23e', '#94b84e', '#b0cc6a')
        sdt = int(r.integers(1000))
        nsc = 34; ga = 2.39996
        def scars(col, P, N, A, B):
            # papaya trunk: soft grey-olive skin turning green near the crown, fine lengthwise grain, and the
            # crescent leaf scars left by fallen leaves on a spiral (sharper and closer together high up)
            g = np.clip((A - 0.62) / 0.3, 0, 1)
            col = mix(col, ramp(green_top, np.clip(col.mean(-1) * 1.25, 0, 1)), g * 0.85)
            col = col * (0.9 + 0.13 * np.abs(np.cos(B * 2 * math.pi * 26 + 2 * fbm(A * 6, B * 4, sdt + 3, 2))))[..., None]
            col = col * (0.86 + 0.24 * fbm(A * 9 + sdt, B * 7, sdt, 3))[..., None]
            k = np.floor(A * nsc).astype(int); fr = A * nsc - k
            th = (k * ga) % (2 * math.pi) / (2 * math.pi)
            db = np.abs(((B - th) + 0.5) % 1.0 - 0.5)                    # angular distance to this scar's centre
            arc = fr - 0.45 - 0.9 * db ** 2                                  # a crescent curving up at the ends
            on = (np.abs(arc) < 0.08) & (db < 0.3)
            depth_ = np.clip(1 - np.abs(arc) / 0.08, 0, 1) * np.clip(1 - db / 0.3, 0, 1) ** 0.5
            col = mix(col, A_(C('#4a4636')), on * depth_ * (0.7 + 0.2 * A))
            lip = (arc > 0.08) & (arc < 0.13) & (db < 0.28)
            col = mix(col, A_(C('#c8c8a8')), lip * 0.35)
            return mix(col, A_(C('#4a3e2a')), np.clip((0.04 - P[..., 2]) / 0.04, 0, 1) * 0.6)       # soil at the foot
        self.trunk_dd(trunk, lambda t: 0.056 + 0.045 * (1 - np.clip(t, 0, 1)) ** 1.6 + 0.02 * np.exp(-np.clip(t, 0, 1) * 18),
                      Ht, sdt, green_top)            # 11-26 Link 'thân đu đủ vẫn đéo ưng': redrawn trunk
        # ---- the crown: leaves on long hollow pale stalks, young ones up in the middle, old ones out and drooping
        leafp = H('#1a4a12', '#245e16', '#30761c', '#3e8e24', '#52a62e', '#6cbc3e', '#90d05a')
        und = H('#4a7a2c', '#5c8e34', '#70a240', '#88b850', '#a4cc6a', '#c2e08e')
        yel = H('#4a5414', '#646e1e', '#7e8a2a', '#9aa438', '#b4bc4c', '#ccd06c')
        petp = H('#6a7a3a', '#82924a', '#9aaa5c', '#b2c070', '#c8d488', '#dce6a4')
        dk = lambda pal, k=0.86: [c * k for c in pal]                   # 11-26: as bright as dừa nước/chuối
        leafp, und, petp = dk(leafp), dk(und), dk(petp, 0.9)
        NL = 15
        for j in range(NL):
            tier = j / (NL - 1)                     # 0 = oldest (low, drooping), 1 = youngest (centre, up)
            az = j * ga + r.normal(0, 0.12)
            fr = math.sin(az)
            front = fr > 0.25 and tier < 0.85     # (Link fix) front leaves stay, held up high over the fruit so the crown is round
            d = np.array([math.cos(az), math.sin(az), 0.0])
            elev = -0.15 + 1.25 * tier ** 1.2 + r.normal(0, 0.06)
            if front: elev = max(elev, 0.55) + 0.15
            if shape == 1:                      # 11-26 Link fix dáng 2: no leaf hanging low, fruit not hidden
                elev = max(elev, 0.12)
                if front: elev = max(elev, 0.8)
            Lp = (0.92 - 0.3 * tier) * r.uniform(0.9, 1.05)   # Link 11-26: crown bigger
            p0 = top + np.array([0, 0, -0.08 + 0.12 * tier]) + d * 0.04
            dirp = nv(d * math.cos(elev) + UP * math.sin(elev))
            p2 = p0 + dirp * Lp - UP * (0.06 + 0.1 * (1 - tier)) * Lp
            pm = p0 + dirp * Lp * 0.5 + UP * 0.03
            self.tube(self.line_c([p0, pm, p2]), 0.012, 0.008, petp, 0.0, int(r.integers(1000)))
            old = j == 0 and shape == 0
            R = (0.54 - 0.16 * tier) * r.uniform(0.92, 1.06)
            fo = nv(np.array([0, 0, 1.0]) + d * (0.35 + 0.5 * (1 - tier)) * (-1 if tier > 0.6 else 1) * 0.3 + TOCAM * 0.15)
            dl = nv(dirp * 0.8 - UP * (0.18 + 0.3 * (1 - tier)) + d * 0.25)
            if old: R *= 0.85
            self.pleaf(p2, dl, fo, R, yel if old else leafp, yel if old else und, lobes=7, depth=0.58, sub=0.5, spread=0.92,
                       cup=-0.32 - 0.2 * (1 - tier), ruffle=0.05, gloss=0.04, teeth=(0, 0), vk=0.45)
        # ---- the fruit packed round the trunk just under the crown, hanging, in tiers
        fruitG = H('#1e3e10', '#2c5418', '#3c6c20', '#4e842a', '#64983a', '#84b052', '#a8c870')
        fruitR = H('#7a3a08', '#a65010', '#cc6a18', '#e8862a', '#f6a444', '#ffc068', '#ffd894')
        tiers = [(0.0, 5), (0.17, 5), (0.33, 4)] if shape == 0 else [(0.0, 5), (0.17, 4), (0.33, 3)]   # 11-26: dáng 2 more fruit
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


BB = (-78, -140, 78, 10)


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
        o.convert('RGB').save(sys.argv[2]); print(o.size)
    elif sys.argv[1] == 'one':
        k = sys.argv[2]; od = sys.argv[3]
        for night in (False, True):
            im = render(seed_of(k), night); a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            im.crop((x0, y0, x1, y1)).save(os.path.join(od, '%s%s.png' % ('nd'[not night], k)))
            json.dump([BB[0] + x0 / co.RS, BB[1] + y0 / co.RS], open(os.path.join(od, '%s%s.json' % ('nd'[not night], k)), 'w'))
