# 2026-11-16 Link "vẽ": dừa nước (nipa palm) on the river banks redrawn in the lotus/caysen kit (per-pixel lit 3D
# surfaces, painted detail, thin own-colour edge, no shadow under the plant). Replaces the flat cairo duanuoc.py.
#   CO_RS=9 python3 duanuoc2.py prev OUT.png [d|n] 0,1,2,3
#   CO_RS=9 python3 duanuoc2.py one <shape> DIR          -> DIR/d<shape>.png, n<shape>.png + .json (top-left in game units)
import math, os, sys, json
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import caysen
from caysen import Kit as CKit, H, A_, C, nv, ramp, mix, vnoise, fbm, HALF, TOCAM, UP
import co

def nv_arr(v): return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-9)


DOWN = np.array([0.0, 0.0, -1.0])


class Kit(CKit):
    def __init__(self, kind, seed, pa):
        self.pa = pa; self.seed = seed; self.kind = kind; self.SC = 0.8      # Link 08:08: same footprint as the old clump
        self.r = np.random.default_rng(seed * 4409 + 1777)
        self.items = []; self.shadows = []
        self._duanuoc(seed)

    # ------------------------------------------------------------------ one frond
    def frond(self, b, az, elev, L, droop, age=0.0, dead=False, npair=24, side_k=1.0):
        """a nipa frond: stout petiole straight out of the water, a stiff rachis arching only near the tip, two rows of
        long narrow stiff leaflets held in a shallow V, longest in the middle, short at both ends"""
        r = self.r
        d = nv(np.array([math.cos(az) * math.cos(elev), math.sin(az) * math.cos(elev), math.sin(elev)]))
        def rach(t):
            t = np.asarray(t, float)
            return b + d * (L * t)[..., None] - UP * (droop * L * t ** 2.4)[..., None]
        green = H('#163e10', '#215616', '#2d6e1c', '#3c8624', '#4f9e2e', '#68b63c', '#8ccc58')
        und = H('#3a6424', '#4c7a2c', '#609236', '#78aa44', '#96c25c', '#b4d880')
        yel = H('#5a5414', '#7a7420', '#9a9430', '#b8b040', '#d0c858', '#e4dc80')
        dry = H('#3e2c18', '#56401f', '#6e5428', '#886a36', '#a08248', '#baa064')
        petg = H('#2c3e16', '#3e521c', '#526a24', '#68822e', '#82983c', '#a0b45a')
        if dead: lp, up_, pp = dry, dry, dry
        elif age > 0.7: lp, up_, pp = yel, yel, H('#4c4a18', '#64601e', '#7e7828', '#989036', '#b0a648', '#c8bc64')
        else: lp, up_, pp = green, und, petg
        if 0 < age <= 0.7 and not dead:      # older green fronds a touch duller/darker than the young ones
            lp = [c * (1 - 0.12 * age) + A_(C('#6a6a20')) * 0.12 * age for c in lp]
        t0 = 0.3                              # the bare petiole: lower ~30% of the frond
        sdp = int(r.integers(1000))
        def petint(col, P, N, A, B):
            # lengthwise fibres, a darker brown wet band near the water, dried skin flecks at the foot
            col = col * (0.94 + 0.08 * np.abs(np.cos(B * 2 * math.pi * 7)))[..., None]
            n1 = vnoise(B * 10, A * 40, sdp)
            col = mix(col, A_(C('#5a4626')), np.clip((n1 - 0.72) / 0.1, 0, 1) * 0.35 * np.clip(1.4 - A * 2.5, 0, 1))
            wet = np.clip((0.07 - P[..., 2]) / 0.06, 0, 1)
            return mix(col, A_(C('#3a2e1c')) * (0.8 + 0.3 * n1)[..., None], wet * 0.8)
        pet = lambda t: rach(np.asarray(t) * t0)
        self.tube(pet, 0.06 * side_k, 0.022, pp, 0.0, sdp, tint=petint,
                  rfun=lambda t: (0.024 + 0.05 * (1 - np.clip(t, 0, 1)) ** 2.5) * side_k)
        self.tube(lambda t: rach(t0 + (1 - t0) * np.asarray(t)), 0.02, 0.005, pp, 0.0, int(r.integers(1000)),
                  rfun=lambda t: 0.019 - 0.014 * np.clip(t, 0, 1))
        # the leaflets
        Lp = L * 0.42
        for k in range(npair):
            u = k / (npair - 1)
            t = t0 + 0.04 + (0.985 - t0 - 0.04) * u
            q = rach(np.array([t]))[0]
            T = nv(rach(np.array([t + 1e-3]))[0] - rach(np.array([t - 1e-3]))[0])
            s = nv(np.cross(T, UP) + 1e-9); nup = nv(np.cross(s, T))
            ll = Lp * (0.42 + 0.58 * math.sin(math.pi * (0.12 + 0.8 * u)) ** 0.7) * r.uniform(0.92, 1.06)
            for side in (-1, 1):
                if dead and r.uniform() < 0.25: continue          # some leaflets broken off the dead frond
                vup = 0.3 + r.normal(0, 0.06)                    # the V: leaflets raised above the rachis plane
                fwd = 0.6 + 0.25 * u
                pdir = nv(s * side + T * fwd + nup * vup)
                hang = (0.18 if not dead else 0.8) * ll
                tw = r.normal(0, 0.03)
                def cf(tt, q=q, pdir=pdir, ll=ll, hang=hang, tw=tw, s=s):
                    tt = np.asarray(tt, float)[..., None]
                    return q + pdir * ll * tt - UP * hang * tt ** 2 + s * tw * ll * tt ** 2
                W = ll * 0.085 * r.uniform(0.92, 1.08)
                tipk = 0.82 if age < 0.4 else 0.6
                tipc = (A_(C('#6a5226')), A_(C('#b89a5a'))) if not dead else None
                self.strap(cf, W, lp, 0.0, fold=0.22, tipcol=tipc, tipk=tipk if age > 0.35 or dead else 0.97,
                           wprof=[0.25, 0.75, 1.0, 0.85, 0.45, 0.0], edge_k=0.82, gloss=0.05, vein_n=4)
        return rach

    # ------------------------------------------------------------------ the fruit head (buồng dừa nước)
    def fruit_head(self, base, c, R):
        """buồng dừa nước (Link 09:53: the faceted ball read as a pine cone): a stout stalk rising from the foot and
        bending over, carrying a round head of BIG separate carpels, each a woody wedge widening outward and ending in a
        short pointed beak, packed radially so their beaks stick out all round; a lengthwise keel on each, dark gaps
        between them, chestnut brown with a waxy sheen."""
        r = self.r
        stalk = H('#2c2a12', '#3e3a18', '#544e20', '#6c642a', '#867c38', '#a09650')
        top = c + np.array([-0.04, -0.06, -R * 0.4])          # the stalk comes up from the foot into the bottom of the head
        st = self.line_c([base, base + (top - base) * 0.45 + np.array([-0.04, -0.02, 0.06]), top])
        self.tube(st, 0.04, 0.03, stalk, 0.0, int(r.integers(1000)))
        brown = H('#1c120a', '#2e1e10', '#443018', '#5a4020', '#70522c', '#88663a', '#a07e52')
        self.ellip(c, UP, R * 0.6, R * 0.6, H('#1a0e06', '#26160a', '#341e0e', '#42280f', '#4e3014', '#5a3818'), 0.0, spec=0.0)   # dark core in the gaps
        n = 44; ga = math.pi * (3 - math.sqrt(5))
        for i in range(n):
            z = 1 - 2 * (i + 0.5) / n; rr = math.sqrt(1 - z * z); th = ga * i + r.normal(0, 0.06)
            dd = nv(np.array([rr * math.cos(th), rr * math.sin(th), z]) + r.normal(0, 0.03, 3))
            if dd @ TOCAM < -0.35: continue
            L = R * r.uniform(0.98, 1.06); W = R * 0.34 * r.uniform(0.9, 1.1)
            p0 = c + dd * R * 0.2
            fh = r.uniform(0.85, 1.12); sd = int(r.integers(1000))
            def rf(t, W=W):
                t = np.clip(t, 0, 1)
                body = W * (0.3 + 0.7 * np.clip(t / 0.8, 0, 1) ** 0.9)                 # widening outward (wedge)
                return body * (np.clip((1.0 - t) / 0.24, 0, 1) ** 0.55 * 0.82 + 0.18 * np.clip((1.0 - t) / 0.24, 0, 1) ** 2) + 1e-4                 # rounded shoulder into the beak
            def tint(col, P, N, A, B, fh=fh, sd=sd):
                col = col * fh
                keel = np.abs(np.cos(B * 2 * math.pi * 2))                                   # 2 keels -> 4 flat faces
                col = col * (0.88 + 0.2 * np.clip((keel - 0.75) / 0.25, 0, 1))[..., None]
                col = col * (0.93 + 0.12 * vnoise(A * 12, B * 18, sd))[..., None]             # woody grain
                col = mix(col, A_(C('#140a04')), np.clip((0.45 - A) / 0.25, 0, 1) * 0.75)      # deep in the gaps
                return mix(col, A_(C('#6a4a26')), np.clip((A - 0.9) / 0.08, 0, 1) * 0.6)      # dry beak
            self.tube(self.line_c([p0, p0 + dd * L * 0.5, p0 + dd * L]), W, W, brown, 0.0, sd, tint=tint, rfun=rf)

    # ------------------------------------------------------------------ clumps
    def _duanuoc(self, seed):
        r = self.r
        shape = seed % 4
        if seed == 9:
            self.fruit_head(np.array([0.0, 0.0, 0.0]), np.array([0.1, 0.3, 0.5]), 0.21); return
        # crowns (shoots of the rhizome under the water): position, size
        CR = {0: [((-0.14, 0.02), 1.0), ((0.24, -0.06), 0.82)],
              1: [((-0.2, 0.0), 0.95), ((0.18, 0.04), 0.9)],
              2: [((0.0, 0.0), 0.72)],
              3: [((-0.22, -0.02), 1.0), ((0.14, 0.04), 1.06), ((0.42, -0.08), 0.6)]}[shape]
        AZ = [-0.2, 0.5, 2.65, 3.35, 4.05, 5.2, 4.7]       # fronds fan out left/right and back; few point at the camera
        spear = H('#4a6a1c', '#5e8424', '#76a030', '#90b83e', '#aed056', '#cce47e')
        stub = H('#2a1e10', '#3c2c18', '#544022', '#6c562e', '#86703e', '#a08a56')
        for ci, ((x, y), sc) in enumerate(CR):
            b = np.array([x, y, -0.02])
            nf = 6 if sc > 0.9 else 5
            rot = r.normal(0, 0.15) + (0.35 if ci % 2 else 0.0)
            for k in range(nf):
                az = AZ[k] + rot + r.normal(0, 0.1)
                fr = math.sin(az)
                elev = r.uniform(0.82, 1.08) + (0.18 if fr > 0.3 else 0.0)
                L = 2.7 * sc * r.uniform(0.9, 1.05)
                droop = r.uniform(0.24, 0.34)
                age = r.uniform(0.0, 0.5)
                self.frond(b + np.array([math.cos(az), math.sin(az), 0]) * 0.03, az, elev, L, droop, age=age,
                           npair=int(14 + 4 * sc), side_k=sc)
            # the young unopened frond: a pale spear straight up out of the middle
            lean = np.array([r.normal(0, 0.12), -0.06, 1.0])
            self.tube(self.line_c([b, b + lean * 0.9 * sc, b + nv(lean) * 2.2 * sc + np.array([0.05, 0, 0])]), 0.03 * sc, 0.004, spear, 0.0,
                      int(r.integers(1000)), rfun=lambda t, sc=sc: (0.03 - 0.012 * np.clip(t, 0, 1) - 0.016 * np.clip((t - 0.7) / 0.3, 0, 1) ** 1.5) * sc + 0.002)
            # old rotted frond bases round the foot: flat brown dry sheaths splayed out, frayed at the top
            for k in range(3):
                a = math.pi * (0.35 + 0.55 * k) + r.normal(0, 0.25); dd = np.array([math.cos(a), math.sin(a), 0])
                h = r.uniform(0.2, 0.34) * sc
                p0 = b + dd * 0.04; p1 = p0 + dd * 0.05 + np.array([0, 0, h * 0.6]); p2 = p0 + dd * 0.12 + np.array([0, 0, h])
                self.strap(self.line_c([p0, p1, p2]), 0.09 * sc, stub, 0.0, fold=0.45, wprof=[1.0, 1.0, 0.95, 0.85, 0.6, 0.3],
                           tipcol=(A_(C('#4a3a26')), A_(C('#9c8660'))), tipk=0.6, gloss=0.02, vein_n=9)
        # (Link 09:20: no dead frond sticking out; shape 1 = green clump without a fruit head)
        if shape == 3:         # an old frond yellowing, leaning out low
            self.frond(np.array([0.2, 0.06, -0.02]), -0.15, 0.62, 2.3, 0.35, age=0.9, npair=15)
        if shape in (0, 3):    # the fruit head low in the clump, on the viewer's side
            cx = CR[0][0][0] + 0.14
            self.fruit_head(np.array([cx - 0.1, 0.03, 0.02]), np.array([cx + 0.1, 0.38, 0.5]), 0.21)


class Frame:
    def __init__(self, pa, kind, seed): self.m = Kit(kind, seed, pa)
    def paint(self): self.m.paint()


BB = (-72, -102, 72, 14)


def render(seed, night):
    return co.to_image(co.render(Frame, dict(kind='duanuoc', seed=seed), BB, night))


if __name__ == '__main__':
    from PIL import Image
    if sys.argv[1] == 'prev':
        night = len(sys.argv) > 3 and sys.argv[3] == 'n'
        seeds = [int(s) for s in (sys.argv[4] if len(sys.argv) > 4 else '0').split(',')]
        ims = [render(s, night) for s in seeds]
        w = sum(i.width for i in ims) + 4 * len(ims); h = max(i.height for i in ims)
        o = Image.new('RGBA', (w, h), (40, 50, 30, 255) if night else (150, 170, 110, 255)); x = 0
        for im in ims: o.alpha_composite(im, (x, h - im.height)); x += im.width + 4
        o.save(sys.argv[2]); print(o.size)
    elif sys.argv[1] == 'one':
        s = int(sys.argv[2]); od = sys.argv[3]
        for night in (False, True):
            im = render(s, night); a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            im.crop((x0, y0, x1, y1)).save(os.path.join(od, '%s%d.png' % ('nd'[not night], s)))
            json.dump([BB[0] + x0 / co.RS, BB[1] + y0 / co.RS], open(os.path.join(od, '%s%d.json' % ('nd'[not night], s)), 'w'))
