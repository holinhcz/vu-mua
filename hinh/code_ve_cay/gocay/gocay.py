# 2026-11-09 gốc cây chặt (at.plants.stump, the wild stumps on unbought land), Link: "tạo gốc cây chặt còn gốc chi tiết
# từng pixel". Drawn with the lotus / caysen kit: every part a parametric 3D surface lit per pixel from its own normal,
# painted detail on top, one shared z-buffer, the kit's thin edge in its own colour, 9 px per game unit.
#   goc0  short stump, fresh saw cut: pale sapwood, red-brown heart, growth rings, saw marks, one fine check, sawdust
#   goc1  wide old stump: weathered grey cut, deep radial checks, moss on the rim and roots, nấm mèo (wood ears) on the
#         side, small white mushrooms at the foot
#   goc2  tall stump felled by axe: sloped notch face with axe facets, back cut, broken hinge with standing splinters,
#         wood chips on the ground, a young sprout (chồi) from the bark
#   goc3  tall wide rotting stump: hollow heart full of crumbled wood and leaves, moss, a linh chi bracket shelf, sprout
# Every stump: irregular lobed trunk with root buttresses, roots running into the soil, fissured bark with plates,
# lichen, peeled patches, grass blades and dry leaves round the foot. No ground shadow (Link: none under plants).
#   CO_RS=9 python3 gocay.py one goc0 DIR        CO_RS=9 python3 gocay.py pack DIR goc.webp atlas.json
#   CO_RS=9 python3 gocay.py prev OUT.png [d|n] [goc0,goc1]
import math, os, sys, json
import numpy as np
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(here, '..', 'caysen'))
import caysen
from caysen import Kit as CKit, co, ch, C, nv, LIGHT, TOCAM, A_, ramp, vnoise, fbm, mix, HALF, H, basis

TAU = 2 * math.pi


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


class Goc(CKit):
    EDGE_DZ = 0.003

    def _goc(self, seed):
        q = seed % 4
        self.q = q
        r = self.r = np.random.default_rng(q * 4409 + 913)
        wide = q in (1, 3); tall = q in (2, 3); old = q in (1, 3)
        self.R0 = 0.285 if wide else 0.245
        self.Ht = 0.40 if tall else 0.29
        if q == 3: self.Ht = 0.36
        self.ph = r.uniform(0, TAU, 4)
        self.old = old
        # roots: angles round the trunk (the back ones mostly hidden), each a buttress on the trunk and a tube into the soil
        n_root = 7 if wide else 6
        a0 = r.uniform(0, TAU)
        self.roots = []
        for k in range(n_root):
            a = a0 + k * TAU / n_root + r.normal(0, 0.18)
            dd = math.remainder(a - math.pi / 2, TAU)          # a root pointing straight at the camera reads as a leg
            if abs(dd) < 0.45: a = math.pi / 2 + math.copysign(0.45, dd if dd else 1)
            self.roots.append((a, r.uniform(0.75, 1.1)))
        # palettes (dark -> light)
        if old:
            self.barkp = H('#241b15', '#33281f', '#463a2e', '#5c4e40', '#736454', '#8e806e')
        else:
            self.barkp = H('#2a1c12', '#3b2918', '#523a24', '#6a4e32', '#836444', '#a07e5a')
        self.inner = H('#5a3e22', '#7e5a34', '#a07a4c', '#c09a68', '#dcbc8a')
        self.moss = H('#24401a', '#335a20', '#467428', '#5e8c32', '#7aa63e', '#9cc054')
        self.lich = A_(C('#a8ae94')); self.lich2 = A_(C('#c8c4a4'))
        self.trunk(); self.top_face()
        for th, k in self.roots: self.root(th, k)
        self.foot()
        if q == 0: self.sawdust()
        if q == 1: self.bracket(); self.white_mush(); self.sprout(-0.5, 0.55, 0.17)
        if q == 2: self.splinters(); self.chips(); self.sprout(1.0, 0.62, 0.16)
        if q == 3: self.bracket(); self.sprout(-0.6, 0.5, 0.2); self.white_mush(few=True)

    # ------------------------------------------------------------------ shape
    def Rf(self, th, z):
        """trunk radius at angle th and height z: lobed section, flaring toward the roots"""
        p = self.ph
        lob = 1 + 0.055 * np.sin(3 * th + p[0]) + 0.035 * np.sin(5 * th + p[1]) + 0.02 * np.sin(8 * th + p[2])
        but = 0.0
        for a, k in self.roots:
            d = np.angle(np.exp(1j * (th - a)))
            but = but + k * np.exp(-(d / 0.3) ** 2)
        fl = 1 + (0.06 + 0.3 * but) * np.exp(-np.maximum(z, 0) / 0.06) + 0.05 * np.exp(-np.maximum(z, 0) / 0.2)
        return self.R0 * lob * fl

    def topz(self, x, y):
        """height of the cut at ground point x, y"""
        q = self.q; R = self.R0; H_ = self.Ht
        if q == 2:      # axe felling: notch face sloping down to the front right, back cut behind, hinge between
            d = np.array([0.55, 0.83]); u = (x * d[0] + y * d[1]) / R
            notch = H_ - 0.13 * np.clip(u - 0.12, 0, None) - 0.03 * sstep(0.0, 0.2, u)
            back = H_ + 0.025 + 0.012 * vnoise(x * 40 + 3, y * 40, 7)
            hinge = H_ + 0.045 + 0.04 * vnoise(x * 60, y * 25 + 5, 3)
            w_b = sstep(-0.05, -0.3, u); w_n = sstep(0.0, 0.18, u)
            z = hinge * (1 - w_b - w_n) + back * w_b + notch * w_n
            return z
        tilt = 0.035 * (x * math.cos(self.ph[3]) + y * math.sin(self.ph[3])) / R
        z = H_ + tilt + 0.004 * vnoise(x * 30, y * 30, 11)
        if q == 3: z = z + 0.03 * np.sin(np.arctan2(y, x) * 2 + 1.0)          # rotted, uneven rim
        return z

    def trunk(self):
        sd = int(self.r.integers(1000)); pal = self.barkp; old = self.old
        def geo(A, B):
            th = B * TAU
            Rt = self.Rf(th, self.Ht)
            zt = self.topz(Rt * np.cos(th), Rt * np.sin(th))
            z = -0.02 + A * (zt + 0.02)
            r = self.Rf(th, z)
            return np.stack([r * np.cos(th), r * np.sin(th), z], -1)
        def sh(P, N, F, A, B):
            th = B * TAU; z = P[..., 2]; lam = self.lam(N)
            u = B * 26; v = z * 14
            war = fbm(u * 0.35 + sd, v * 0.6, sd, 3)
            ridge = np.abs(np.sin(math.pi * (u + 2.6 * war + 0.6 * vnoise(u * 0.7, v * 3, sd + 9))))
            plate = 0.86 + 0.28 * vnoise(u * 1.1, v * 2.2 + sd, sd + 1)
            hz = np.abs(np.sin(math.pi * (v * 1.3 + 0.8 * vnoise(u * 0.5, v, sd + 2))))
            s_ = np.clip((0.1 + 0.86 * lam) * plate, 0, 1)
            col = ramp(pal, s_)
            fis = np.clip((0.16 - ridge) / 0.16, 0, 1) ** 0.8
            col = mix(col, pal[0] * 0.75, fis * 0.85)
            col = mix(col, pal[0], np.clip((0.07 - hz) / 0.07, 0, 1) * 0.5 * (ridge > 0.22))
            # plate tops catch the light
            col = col + (pal[-1] - col) * (np.clip((ridge - 0.75) / 0.25, 0, 1) * 0.25 * lam)[..., None]
            # peeled patches: inner wood with fibres
            pm = fbm(u * 0.28 + 9, v * 0.7, sd + 3, 3)
            pk = sstep(0.71, 0.74, pm) * (z > 0.07) * (z < self.Ht - 0.04) * (1.0 if old else 0.0)
            fib = 0.9 + 0.1 * np.sin(u * 30 + 3 * vnoise(u * 2, v * 3, sd))
            icol = ramp(self.inner, np.clip((0.15 + 0.8 * lam) * fib, 0, 1))
            if old: icol = mix(icol, A_(C('#8a8272')), 0.45)
            col = mix(col, icol, pk)
            rim = sstep(0.68, 0.71, pm) * (1 - pk) * (z > 0.07) * (1.0 if old else 0.0)
            col = mix(col, pal[0] * 0.8, rim * 0.6)
            # lichen
            lc = fbm(u * 0.9 + 3, v * 1.4, sd + 4, 3)
            lk = sstep(0.62, 0.68, lc) * (0.55 if old else 0.35) * (1 - pk)
            spot = vnoise(u * 7, v * 9, sd + 5)
            col = mix(col, mix(self.lich, self.lich2, spot) * (0.55 + 0.55 * lam)[..., None], lk * (0.6 + 0.4 * spot))
            # moss low down, more on the shady back right and on old stumps
            shade = np.clip(0.5 + 0.5 * np.cos(th - 0.6), 0, 1)
            mk = sstep(0.13 if old else 0.05, 0.02, z) * sstep(0.0, 0.03, z) * (0.45 + 0.55 * shade) * (0.85 if old else 0.5)
            if old: mk = np.maximum(mk, sstep(self.Ht - 0.07, self.Ht, z) * sstep(0.5, 0.7, fbm(u * 0.5, v, sd + 6, 2)))
            mk = mk * sstep(0.35, 0.6, fbm(u * 0.8 + 1, v * 1.5, sd + 7, 3) + 0.25 * old)
            mcol = ramp(self.moss, np.clip((0.15 + 0.85 * lam) * (0.8 + 0.4 * vnoise(u * 10, v * 14, sd + 8)), 0, 1))
            col = mix(col, mcol, np.clip(mk, 0, 1))
            # soil splash at the foot
            col = mix(col, A_(C('#4a3a2a')) * (0.7 + 0.4 * lam)[..., None], sstep(0.035, 0.0, z) * 0.55)
            return np.clip(col, 0, 1), z > 0.004
        self.splat(geo, sh, np.array([0, 0.0, self.Ht * 0.5]), edge_k=0.78)

    def top_face(self):
        q = self.q; sd = int(self.r.integers(1000)); r = self.r; old = self.old
        pith = np.array([self.R0 * r.uniform(-0.15, 0.15), self.R0 * r.uniform(-0.2, 0.05)])
        nr = 26 if not old else 22
        ncr = [1, 6, 2, 4][q]
        cracks = [(r.uniform(0, TAU), r.uniform(0.45, 0.95), r.uniform(0.6, 1.0)) for _ in range(ncr)]
        if old:
            sap = A_(C('#b0a690')); heart = A_(C('#8e806a')); pithc = A_(C('#4a4034'))
        else:
            sap = A_(C('#ecd09a')); heart = A_(C('#c48a52')); pithc = A_(C('#6e4426'))
        hollow = q == 3
        def xy(A, B):
            th = B * TAU; Rr = self.Rf(th, self.Ht) * 0.985
            rho = A
            x = pith[0] * (1 - rho) + rho * Rr * np.cos(th); y = pith[1] * (1 - rho) + rho * Rr * np.sin(th)
            return x, y, rho, th, Rr
        def geo(A, B):
            x, y, rho, th, Rr = xy(A, B)
            z = self.topz(x, y) + 0.003
            if hollow:
                hr = 0.62 + 0.08 * np.sin(th * 3 + 1.3)
                z = z - 0.11 * sstep(hr, hr - 0.3, rho) - 0.012 * vnoise(x * 50, y * 50, 4)
            if q == 2: z = z + 0.003 * np.sin(rho * 60)        # axe facets: small ridges across the faces
            return np.stack([x, y, z], -1)
        def sh(P, N, F, A, B):
            x, y, rho, th, Rr = xy(A, B); lam = self.lam(N)
            n1 = fbm(rho * 5 + sd, th * 2.2, sd, 3)
            rr = rho * nr + 1.2 * n1 + 0.4 * np.sin(th * 3 + sd)
            w = rr % 1.0
            late = sstep(0.7, 0.86, w) * (1 - sstep(0.93, 1.0, w))
            hk = sstep(0.62, 0.52, rho + 0.05 * n1)
            col = mix(sap, heart, hk)
            col = mix(col, pithc, sstep(0.06, 0.0, rho) * 0.9)
            col = col * (1 - late * (0.16 if not old else 0.1))[..., None]
            col = col * (0.93 + 0.12 * vnoise(x * 120, y * 120, sd + 1))[..., None]
            if q == 0:      # saw marks: faint arcs of the blade's teeth
                arc = np.sin(np.hypot(x + 0.9, y - 0.5) * 520)
                col = col * (1 - 0.05 * np.clip(arc, 0, 1))[..., None]
            if q == 2:      # axe cut: facets catch the light differently, fibres torn at the hinge
                fac = np.floor(rho * 7 + 0.6 * n1) % 2
                col = col * (0.94 + 0.08 * fac)[..., None]
                d = np.array([0.55, 0.83]); u = (x * d[0] + y * d[1]) / self.R0
                tor = (np.abs(u + 0.1) < 0.14)
                ff = 0.8 + 0.25 * np.sin((x * d[1] - y * d[0]) * 300 + 6 * vnoise(x * 40, y * 40, 2))
                col = np.where(tor[..., None], col * ff[..., None] * 0.95, col)
            if old:         # weathering: grey, blackened rings and algae, moss on the rim
                col = mix(col, A_(C('#5a564a')), sstep(0.5, 0.75, fbm(x * 18, y * 18, sd + 2, 3)) * 0.4)
                mk = sstep(0.82, 0.97, rho) * sstep(0.45, 0.6, fbm(th * 3, rho * 4, sd + 3, 3))
                mcol = ramp(self.moss, np.clip((0.3 + 0.7 * lam) * (0.8 + 0.4 * vnoise(x * 200, y * 200, sd + 4)), 0, 1))
                col = mix(col, mcol, mk)
            # radial checks (cracks) from the heart out
            for (ph, L, wd) in cracks:
                ang = ph + 0.15 * np.sin(rho * 9 + ph * 3)
                dd = np.abs(np.angle(np.exp(1j * (th - ang)))) * np.maximum(rho, 0.02) * Rr
                wc = (0.0035 if not old else 0.007) * wd * (1 - rho / L) * (rho < L) * (rho > 0.05)
                ck = np.clip((wc - dd) / 0.0015, 0, 1)
                lip = np.clip((wc + 0.003 - dd) / 0.002, 0, 1) * (1 - ck)
                col = col * (1 + 0.08 * lip)[..., None]
                col = mix(col, A_(C('#2a1e14')), ck * 0.92)
            # cambium line and the bark band at the rim
            bt = 0.03 / self.R0 * (1 + 0.3 * vnoise(th * 8, 0, sd + 5))
            cam = np.exp(-((rho - (1 - bt)) / 0.012) ** 2)
            col = mix(col, A_(C('#f6e2b4' if not old else '#c0b8a2')), cam * 0.5)
            bk = sstep(1 - bt + 0.01, 1 - bt + 0.03, rho)
            bcol = ramp(self.barkp, np.clip(0.25 + 0.5 * vnoise(th * 40, rho * 30, sd + 6), 0, 1))
            col = mix(col, bcol, bk)
            if hollow:      # rotten heart: crumbled dark wood, a few dead leaves fallen in
                hr = 0.62 + 0.08 * np.sin(th * 3 + 1.3)
                hk2 = sstep(hr + 0.02, hr - 0.08, rho)
                crumb = vnoise(x * 160, y * 160, sd + 7)
                rc = mix(A_(C('#2e1e12')), A_(C('#6e4a2a')), np.clip(crumb * 1.2 - 0.1, 0, 1))
                deep = sstep(hr - 0.1, hr - 0.32, rho)
                rc = rc * (1 - 0.5 * deep)[..., None]
                lf = sstep(0.68, 0.72, fbm(x * 30 + 2, y * 30, sd + 8, 2)) * (deep < 0.8)
                rc = mix(rc, A_(C('#a06a2e')) * (0.8 + 0.3 * vnoise(x * 90, y * 90, 3))[..., None], lf)
                col = mix(col, rc, hk2)
                col = mix(col, col * 0.7, sstep(hr - 0.02, hr + 0.05, rho) * (1 - sstep(hr + 0.05, hr + 0.12, rho)) * 0.6)
            sv = 0.5 + 0.62 * lam
            col = col * sv[..., None]
            spec = np.clip(N @ HALF, 0, 1) ** 12 * (0.04 if not old else 0.02)
            return np.clip(col + spec[..., None], 0, 1)
        self.splat(geo, sh, np.array([0, 0.05, self.Ht + 0.05]), edge_k=0.82)

    def root(self, th, k):
        sd = int(self.r.integers(1000)); r = self.r
        d = np.array([math.cos(th), math.sin(th), 0.0]); s = np.array([-d[1], d[0], 0.0])
        R0 = self.R0
        L = R0 * (0.32 + 0.3 * k) + r.uniform(0, 0.04)
        bend = r.normal(0, 0.03)
        pts = [d * R0 * 0.8 + np.array([0, 0, 0.09 * k]), d * (R0 * 1.02) + np.array([0, 0, 0.05 * k]),
               d * (R0 + L * 0.6) + s * bend + np.array([0, 0, 0.018]), d * (R0 + L) + s * bend * 1.6 + np.array([0, 0, -0.035])]
        cf = self.line_c(pts)
        rr0 = 0.05 * k + 0.025
        pal = self.barkp
        def tint(col, P, N, A, B):
            u = B * 6; v = A * 8
            ridge = np.abs(np.sin(math.pi * (u + 0.8 * fbm(u * 0.5, v, sd, 2))))
            col = mix(col, pal[0] * 0.8, np.clip((0.2 - ridge) / 0.2, 0, 1) * 0.6)
            mk = sstep(0.5, 0.65, fbm(u * 0.6 + 2, v * 1.2, sd + 1, 3)) * (0.9 if self.old else 0.45) * (N[..., 2] > 0.2)
            mcol = ramp(self.moss, np.clip((0.2 + 0.8 * self.lam(N)) * (0.8 + 0.4 * vnoise(u * 12, v * 12, sd + 2)), 0, 1))
            col = mix(col, mcol, mk)
            col = mix(col, A_(C('#4a3a2a')) * (0.6 + 0.4 * self.lam(N))[..., None], sstep(0.03, 0.0, P[..., 2]) * 0.7)
            return col
        self.tube(cf, rr0, 0.012, pal, 0.0, sd, zcut=-0.005, tint=tint, edge_k=0.78,
                  rfun=lambda t: (rr0 - 0.016) * (1 - t) ** 1.1 + 0.016 + rr0 * 0.35 * np.exp(-t * 6))

    # ------------------------------------------------------------------ the ground round the foot
    def foot(self):
        r = self.r; q = self.q
        grass = H('#2a6a2a', '#3a8034', '#4c9640', '#62ac4c', '#7ec25c', '#9ad470')
        dry = H('#6a5228', '#8a6c34', '#a88a44', '#c4a658', '#d8be72')
        n = [9, 7, 10, 8][q]
        for k in range(n):
            a = r.uniform(-0.3, math.pi + 0.3)          # mostly in front, where they are seen
            rad = self.R0 * r.uniform(1.1, 1.4)
            b = np.array([math.cos(a) * rad, math.sin(a) * rad * 0.9 + 0.02, 0.0])
            for j in range(int(r.integers(3, 6))):
                az = r.uniform(0, TAU); L = r.uniform(0.07, 0.14); el = r.uniform(0.9, 1.35)
                dv = np.array([math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)])
                tip = b + dv * L + np.array([math.cos(az), math.sin(az), 0]) * L * 0.35 - np.array([0, 0, L * 0.25])
                tip[2] = max(tip[2], 0.03)
                cf = self.line_c([b, b + dv * L * 0.55, tip])
                pal = dry if r.uniform() < 0.25 else grass
                self.strap(cf, r.uniform(0.012, 0.018), pal, 0.02, fold=0.25, gloss=0.08, vein_n=3,
                           tipcol=(A_(C('#a88a44')), A_(C('#d8be72'))), tipk=0.8)
        # fallen dry leaves on the soil
        lp = H('#4a2e14', '#6e4420', '#8e5c2a', '#ae7a3a', '#c89a52', '#dcb46c')
        lu = H('#5a3a1c', '#7a5428', '#9a7038', '#b88c4c')
        for k in range([3, 5, 2, 6][q]):
            a = r.uniform(-0.4, math.pi + 0.4); rad = self.R0 * r.uniform(1.1, 1.5)
            b = np.array([math.cos(a) * rad, math.sin(a) * rad, 0.012])
            az = r.uniform(0, TAU); e = np.array([math.cos(az), math.sin(az), 0.08])
            L = r.uniform(0.07, 0.11)
            self.leaf(b, nv(e), np.array([0, 0, 1.0]), L, L * 0.42, lp, lu, droop=-0.1, fold=0.15, gloss=0.05, veins=6)

    def _nhanh(self, seed):
        """Link 17:07 'nhánh cây khô chồng lên nhau', its own wild object: dry fallen branches piled across each other"""
        q = seed % 2; r = np.random.default_rng(q * 71 + 5)
        self.q = q; self.old = True
        pal = H('#2a1e16', '#3e2f22', '#56442f', '#705a42', '#8a735a', '#a68e72') if q == 0 else \
              H('#2c2620', '#423a30', '#5a5044', '#746a5c', '#8e8474', '#aaa08e')
        self.moss = H('#24401a', '#335a20', '#467428', '#5e8c32', '#7aa63e', '#9cc054')
        leafp = H('#4a2e14', '#6e4420', '#8e5c2a', '#ae7a3a', '#c89a52', '#dcb46c')
        leafu = H('#5a3a1c', '#7a5428', '#9a7038', '#b88c4c')
        pale = A_(C('#cdb48c'))
        n = 6 if q == 0 else 7
        zs = 0.0
        for k in range(n):
            big = k < 2
            az = r.uniform(0, math.pi) if not big else (0.15 + 0.5 * k) * math.pi + r.normal(0, 0.1)
            L = r.uniform(0.75, 0.95) if big else r.uniform(0.45, 0.72)
            rr = r.uniform(0.032, 0.042) if big else r.uniform(0.014, 0.024)
            d = np.array([math.cos(az), math.sin(az) * 0.85, 0.0]); nrm = np.array([-d[1], d[0], 0.0])
            c = np.array([r.normal(0, 0.06), r.normal(0, 0.05), 0.0])
            lift = 0.0 if big and k == 0 else 0.045 + 0.024 * k          # later branches rest on the earlier ones
            bow = r.normal(0, 0.025)
            p0 = c - d * L / 2 + np.array([0, 0, rr]); p2 = c + d * L / 2 + np.array([0, 0, rr + r.uniform(0, 0.02)])
            p1 = c + nrm * bow + np.array([0, 0, rr + lift])
            cf = self.line_c([p0, (p0 + p1) / 2 + np.array([0, 0, lift * 0.4]), p1, (p1 + p2) / 2 + np.array([0, 0, lift * 0.4]), p2])
            sd = int(r.integers(1000)); bt = self.bark(pal, sd, cracks=0.55)
            ends = (p0, p2)
            def tint(col, P, N, A, B, bt=bt, ends=ends, sd=sd):
                col = bt(col, P, N, A, B)
                mk = sstep(0.62, 0.72, fbm(A * 18 + sd, B * 5, sd + 1, 3)) * sstep(0.3, 0.7, N[..., 2]) * 0.55       # moss / lichen on top
                col = mix(col, ramp(self.moss, np.clip(0.25 + 0.7 * self.lam(N), 0, 1)), mk)
                w = np.maximum(sstep(0.03, 0.0, A), sstep(0.97, 1.0, A))                                  # pale broken ends
                return mix(col, pale * (0.55 + 0.55 * self.lam(N))[..., None], w * 0.85)
            self.tube(cf, rr, rr * 0.6, pal, 0.0, sd, zcut=0.0, tint=tint, edge_k=0.78)
            capp = H('#6e5a40', '#a08a68', '#c6ae86', '#dcc8a2', '#ecdcbc')
            for (pe, tt, rad) in ((p0, 0.0, rr), (p2, 1.0, rr * 0.6)):      # broken / cut ends: pale wood, not an open pipe
                tg = cf(np.array([min(tt + 0.01, 1.0)]))[0] - cf(np.array([max(tt - 0.01, 0.0)]))[0]
                self.ellip(pe, nv(tg), rad * 0.18, rad * 1.02, capp, 0.01, spec=0.0)
            for j in range(int(r.integers(2, 4)) if not big else 3):     # side twigs, some with a few dead leaves left
                t = r.uniform(0.2, 0.85); b0 = cf(np.array([t]))[0]
                ta = az + r.choice([-1, 1]) * r.uniform(0.45, 0.9); tl = r.uniform(0.09, 0.18)
                e = np.array([math.cos(ta), math.sin(ta) * 0.85, r.uniform(-0.1, 0.35)])
                tip = b0 + e * tl; tip[2] = max(tip[2], 0.008)
                tcf = self.line_c([b0, (b0 + tip) / 2 + np.array([0, 0, 0.008]), tip])
                self.tube(tcf, rr * 0.45, rr * 0.2, pal, 0.0, int(r.integers(1000)), zcut=0.0, edge_k=0.8)
                if r.uniform() < 0.45:
                    for m_ in range(int(r.integers(1, 3))):
                        lb = tcf(np.array([r.uniform(0.6, 1.0)]))[0]
                        la = r.uniform(0, TAU); le = nv(np.array([math.cos(la), math.sin(la), r.uniform(-0.2, 0.3)]))
                        Ll = r.uniform(0.06, 0.09)
                        self.leaf(lb, le, np.array([0, 0.2, 1.0]), Ll, Ll * 0.42, leafp, leafu, droop=0.05, fold=0.35, gloss=0.03, veins=6)
        for k in range(4):        # a few leaves and bark flakes on the soil round the pile
            a = r.uniform(0, TAU); rad = r.uniform(0.3, 0.48)
            b = np.array([math.cos(a) * rad, math.sin(a) * rad * 0.8, 0.012])
            az = r.uniform(0, TAU); e = np.array([math.cos(az), math.sin(az), 0.08]); L = r.uniform(0.06, 0.09)
            self.leaf(b, nv(e), np.array([0, 0, 1.0]), L, L * 0.42, leafp, leafu, droop=-0.1, fold=0.15, gloss=0.05, veins=6)

    def sawdust(self):
        r = self.r
        pal = H('#a07a48', '#c09a64', '#dcbc86', '#eed4a0', '#f8e6bc')
        for k in range(45):
            a = r.uniform(-0.2, math.pi + 0.2); rad = self.R0 * (1.08 + 0.4 * r.uniform() ** 1.5)
            c = np.array([math.cos(a) * rad, math.sin(a) * rad, 0.006])
            ax = nv(np.array([r.normal(), r.normal(), 0.1]))
            self.ellip(c, ax, r.uniform(0.006, 0.011), r.uniform(0.003, 0.006), pal, 0.03, spec=0.0)
        # a little heap on the cut too
        for k in range(6):
            a = r.uniform(0, TAU); rad = self.R0 * r.uniform(0.2, 0.8)
            x, y = math.cos(a) * rad, math.sin(a) * rad
            c = np.array([x, y, float(self.topz(np.array(x), np.array(y))) + 0.006])
            ax = nv(np.array([r.normal(), r.normal(), 0.1]))
            self.ellip(c, ax, r.uniform(0.005, 0.009), r.uniform(0.003, 0.005), pal, 0.03, spec=0.0)

    def chips(self):
        r = self.r
        pal = H('#8a6236', '#b08654', '#d0aa74', '#e8c896', '#f4dcb0')
        for k in range(9):
            a = r.uniform(0.0, math.pi * 0.9); rad = self.R0 * r.uniform(1.3, 2.0)
            c = np.array([math.cos(a) * rad + 0.04, math.sin(a) * rad, 0.01])
            az = r.uniform(0, TAU); L = r.uniform(0.04, 0.075); W = L * r.uniform(0.45, 0.7)
            e = np.array([math.cos(az), math.sin(az), r.uniform(-0.05, 0.15)])
            cf = self.line_c([c - e * L / 2, c, c + e * L / 2 + np.array([0, 0, 0.01])])
            self.strap(cf, W, pal, 0.03, fold=-0.15, gloss=0.0, vein_n=6, wprof=[0.85, 1.0, 1.0, 1.0, 0.9, 0.7])

    def splinters(self):
        """the broken hinge: torn slivers standing up across the stump"""
        r = self.r
        pal = H('#7a5430', '#a07848', '#c49e6a', '#dcbc88', '#eed6a8')
        d = np.array([0.55, 0.83]); s = np.array([-d[1], d[0]])
        for k in range(11):
            v = (k / 10 - 0.5) * 1.7 * self.R0 * r.uniform(0.85, 1.0)
            u = -0.1 * self.R0 + r.normal(0, 0.02)
            x, y = d[0] * u + s[0] * v, d[1] * u + s[1] * v
            if math.hypot(x, y) > self.R0 * 0.92: continue
            z0 = float(self.topz(np.array(x), np.array(y))) - 0.01
            hh = r.uniform(0.03, 0.09) * (1.0 - 0.6 * abs(v) / self.R0)
            lean = np.array([d[0], d[1], 0]) * r.uniform(-0.03, 0.05)
            b = np.array([x, y, z0])
            cf = self.line_c([b, b + np.array([0, 0, hh * 0.6]) + lean * 0.5, b + np.array([0, 0, hh]) + lean])
            self.strap(cf, r.uniform(0.012, 0.024), pal, 0.04, fold=0.2, gloss=0.0, vein_n=4,
                       wprof=[1.0, 1.0, 0.9, 0.7, 0.4, 0.0])

    def sprout(self, th, hk, L):
        """a young shoot breaking out of the bark: reddish stem, coppery new leaves turning green"""
        r = self.r
        R = float(self.Rf(np.array(th), np.array(self.Ht * hk)))
        b = np.array([math.cos(th) * R * 0.97, math.sin(th) * R * 0.97, self.Ht * hk])
        out = np.array([math.cos(th), math.sin(th), 0.0])
        top = b + out * L * 0.35 + np.array([0, 0.02, L])
        cf = self.line_c([b, b + out * L * 0.25 + np.array([0, 0, L * 0.45]), top])
        stem = H('#4a2a1a', '#6a3a22', '#8a5030', '#a86a3c', '#b8844a')
        self.tube(cf, 0.007, 0.004, stem, 0.06, int(r.integers(1000)), edge_k=0.8)
        top_g = H('#1e4a1a', '#2a6222', '#3a7a2a', '#4e9234', '#6aaa40', '#8cc254')
        und = H('#3a5e2a', '#4e7636', '#668e44', '#86aa5c')
        cop = A_(C('#b0502a'))
        for j in range(5):
            t = 0.35 + 0.15 * j
            p = cf(np.array([min(t, 1.0)]))[0]
            az = th + (j % 2 * 2 - 1) * 1.2 + r.normal(0, 0.2)
            e = nv(np.array([math.cos(az), math.sin(az), 0.55 + 0.25 * j]))
            Ll = 0.07 + 0.012 * (4 - j) if j < 4 else 0.05
            young = j >= 3
            def tint(col, P, N, A, B, young=young):
                return mix(col, cop * (0.7 + 0.4 * self.lam(N))[..., None], (0.65 if young else 0.15) * A)
            self.leaf(p, e, np.array([0, 0.3, 1.0]), Ll, Ll * 0.45, top_g, und, key=0.08, droop=0.25, gloss=0.25, tint=tint)

    def wood_ears(self):
        """nấm mèo: translucent brown ears in a cluster on the front of the trunk"""
        r = self.r
        pal = H('#1e0e0a', '#341a12', '#4a261a', '#603424', '#7a4632', '#965c42')
        for k in range(4):
            th = 1.15 + (k - 1.5) * 0.28 + r.normal(0, 0.08); z = self.Ht * (0.68 - 0.13 * k + r.uniform(-0.04, 0.04))
            R = float(self.Rf(np.array(th), np.array(z)))
            out = np.array([math.cos(th), math.sin(th), 0.0])
            c = out * R * 0.98 + np.array([0, 0, z])
            S = r.uniform(0.05, 0.068); sd = int(r.integers(1000))
            u_ = nv(np.cross(out, np.array([0, 0, 1.0]))); w_ = np.array([0, 0, 1.0])
            def geo(A, B, c=c, out=out, u_=u_, S=S, sd=sd):
                rho = 0.02 + 0.98 * A; ph = B * TAU
                rim = 1 + 0.1 * np.sin(ph * 3 + sd) + 0.05 * np.sin(ph * 5 + sd * 2)
                rr = S * rho * rim
                lx = np.cos(ph) * rr; ly = np.sin(ph) * rr * 0.8
                cup = S * 0.9 * rho ** 2
                return (c + out[None, None, :] * (cup + S * 0.2)[..., None] * 0.6 + u_ * lx[..., None]
                        + w_ * (ly + 0.1 * S)[..., None] - out * (0.25 * S * (1 - rho))[..., None])
            def sh(P, N, F, A, B, sd=sd):
                lam = self.lam(N)
                vein = np.abs(np.sin(B * TAU * 7 + 3 * vnoise(A * 4, B * 10, sd)))
                s_ = np.clip((0.18 + 0.75 * lam) * (0.9 + 0.12 * vein) + 0.15 * A, 0, 1)
                col = ramp(pal, s_)
                col = np.where(F[..., None], col, col * 0.8)
                spec = np.clip(N @ HALF, 0, 1) ** 16 * 0.25
                return np.clip(col + spec[..., None], 0, 1)
            self.splat(geo, sh, c + out * 0.06 + TOCAM * 0.05, edge_k=0.75)

    def white_mush(self, few=False):
        r = self.r
        cap = H('#8a7a62', '#b8a888', '#d8ccb0', '#eee6d2', '#faf6ec')
        stem = H('#a8a08a', '#c8c0a8', '#e0dac8', '#f2eee2')
        n = 3 if few else 5
        a0 = 1.9 if few else 0.6
        for k in range(n):
            a = a0 + k * 0.22 + r.normal(0, 0.06); rad = self.R0 * r.uniform(1.15, 1.35)
            b = np.array([math.cos(a) * rad, math.sin(a) * rad, 0.0])
            hh = r.uniform(0.035, 0.06); cr = r.uniform(0.014, 0.024)
            lean = np.array([r.normal(0, 0.008), r.normal(0, 0.008), 0])
            cf = self.line_c([b, b + np.array([0, 0, hh * 0.5]) + lean * 0.5, b + np.array([0, 0, hh]) + lean])
            self.tube(cf, 0.0045, 0.0035, stem, 0.0, int(r.integers(1000)), zcut=0.0)
            top = b + np.array([0, 0, hh]) + lean; sd = int(r.integers(1000))
            def geo(A, B, top=top, cr=cr):
                th = A * math.pi * 0.5; ph = B * TAU
                rr = cr * np.sin(th) * (1 + 0.05 * np.sin(ph * 6))
                z = cr * 0.6 * np.cos(th) - cr * 0.08
                return np.stack([top[0] + np.cos(ph) * rr, top[1] + np.sin(ph) * rr, top[2] + z], -1)
            def sh(P, N, F, A, B, sd=sd):
                lam = self.lam(N)
                s_ = np.clip(0.15 + 0.85 * lam, 0, 1) * (0.95 + 0.08 * vnoise(A * 8, B * 20, sd))
                col = ramp(cap, np.clip(s_, 0, 1))
                col = mix(col, A_(C('#8a6a48')), sstep(0.25, 0.0, A) * 0.45)       # brown centre
                col = np.where(F[..., None], col, ramp(stem, np.clip(0.2 + 0.5 * lam, 0, 1)) * 0.8)
                return col
            self.splat(geo, sh, top + TOCAM * 0.03, edge_k=0.8)

    def bracket(self):
        """linh chi shelf fungus: glossy lacquered red-brown fans with a pale growing rim"""
        r = self.r
        for k, (th, zf, S) in enumerate([(1.35, 0.55, 0.075), (1.75, 0.38, 0.058), (1.05, 0.3, 0.05)]):
            z = self.Ht * zf; R = float(self.Rf(np.array(th), np.array(z)))
            out = np.array([math.cos(th), math.sin(th), 0.0]); u_ = np.array([-out[1], out[0], 0.0])
            c = out * R * 0.94 + np.array([0, 0, z]); sd = int(r.integers(1000))
            def geo(A, B, c=c, out=out, u_=u_, S=S):
                rho = 0.03 + 0.97 * A; ph = (B - 0.5) * math.pi * 1.15
                rr = S * rho * (1 + 0.06 * np.sin(ph * 7))
                x = np.cos(ph) * rr; y = np.sin(ph) * rr * 1.25
                zz = S * 0.28 * (1 - rho ** 2) - S * 0.12 * rho ** 3
                return c + out * x[..., None] + u_ * y[..., None] + np.array([0, 0, 1.0]) * zz[..., None]
            def sh(P, N, F, A, B, sd=sd):
                lam = self.lam(N)
                band = 0.5 + 0.5 * np.sin(A * 26 + 2 * vnoise(A * 3, B * 6, sd))
                base = ramp(H('#2a0e08', '#4a160c', '#6e2412', '#90381a', '#b05a26'), np.clip(0.2 + 0.75 * lam * (0.85 + 0.2 * band), 0, 1))
                base = mix(base, A_(C('#e8c888')), sstep(0.86, 0.98, A) * 0.8)
                base = mix(base, A_(C('#c8823a')), sstep(0.72, 0.86, A) * (1 - sstep(0.88, 0.98, A)) * 0.5)
                base = np.where(F[..., None], base, ramp(H('#8a7058', '#b49a7a', '#d4bc98'), np.clip(0.3 + 0.6 * lam, 0, 1)))
                spec = np.clip(N @ HALF, 0, 1) ** 26 * 0.5 + np.clip(N @ HALF, 0, 1) ** 6 * 0.06
                return np.clip(base + spec[..., None], 0, 1)
            self.splat(geo, sh, c + out * 0.08 + TOCAM * 0.05, edge_k=0.75)


class Frame:
    def __init__(self, pa, kind, seed): self.m = Goc(kind, seed, pa)
    def paint(self): self.m.paint()


BB = (-38, -46, 38, 18)
FRAMES = [dict(key='goc%d' % s, kind='goc', seed=s) for s in range(2)] + [dict(key='nhanh%d' % s, kind='nhanh', seed=s) for s in range(2)]   # Link 16:09 "2 kiểu thôi"


def render(fr, night):
    return co.to_image(co.render(Frame, dict(kind=fr['kind'], seed=fr['seed'], key=fr['key']), BB, night)), BB


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
    elif sys.argv[1] == 'one':
        fr = [f for f in FRAMES if f['key'] == sys.argv[2]][0]
        for night in (False, True):
            im, bb = render(fr, night); a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            im.crop((x0, y0, x1, y1)).save(os.path.join(sys.argv[3], '%s%s.png' % ('nd'[not night], fr['key'])))
            json.dump([bb[0] + x0 / co.RS, bb[1] + y0 / co.RS], open(os.path.join(sys.argv[3], '%s%s.json' % ('nd'[not night], fr['key'])), 'w'))
    elif sys.argv[1] == 'pack':
        d = sys.argv[2]; crops = []
        for night in 'dn':
            for fr in FRAMES:
                n = night + fr['key']; dx, dy = json.load(open(os.path.join(d, n + '.json')))
                crops.append((n, Image.open(os.path.join(d, n + '.png')), dx, dy))
        x = y = rowh = 0; pos = {}; maxw = 2048
        for name, im, dx, dy in crops:
            if x + im.width > maxw: x = 0; y += rowh + 2; rowh = 0
            pos[name] = (x, y); x += im.width + 2; rowh = max(rowh, im.height)
        Wt = max(pos[n][0] + im.width for n, im, _, _ in crops); Ht = y + rowh
        out = Image.new('RGBA', (Wt, Ht), (0, 0, 0, 0)); table = {}
        for name, im, dx, dy in crops:
            sx, sy = pos[name]; out.paste(im, (sx, sy))
            table[name] = [sx, sy, im.width, im.height, round(dx, 2), round(dy, 2), round(im.width / co.RS, 2), round(im.height / co.RS, 2)]
        out.save(os.path.join(d, sys.argv[3]), 'WEBP', quality=90, alpha_quality=100, method=6)
        json.dump(table, open(sys.argv[4], 'w'), separators=(',', ':')); print(out.size)
