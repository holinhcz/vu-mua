# Wild bush (bụi cây) for Nông Trại Nhỏ: a low mound of trâm ổi / ngũ sắc (lantana), the shrub that grows wild along
# every fence and canal bank in the Mekong delta. Built as a small 3D model and painted in flat game tones with the
# thin same-colour edge of the other new plants (ch.SOFT), with the banana kit's camera, sun and night (../chuoi).
# The bush: a few thin woody stems out of the soil into 5-7 rounded clumps of small rough oval leaves (the mango's
# clump crown, ../xoai, with no dark lining: thin spots show the stems and the ground), 2-3 long arching shoots
# reaching out of the mound with pairs of leaves, and 9-14 domed flower heads on the sunny side. Each head is a little
# dome of tube flowers, the outer ring one colour and the middle another, as lantana is:
# seed 0 cream with a yellow middle, 1 pink with a yellow middle, 2 orange with a yellow middle, 3 white with a pale
# yellow eye (the old bush's cream, pink, yellow and white).
import math, os, sys
import numpy as np, cairo
here = os.path.dirname(os.path.abspath(__file__))
for d in ('chuoi', 'dambut', 'da', 'xoai', 'co'): sys.path.insert(0, os.path.join(here, '..', d))
import chuoi as ch
from chuoi import C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM
from da import bez
import xoai
from xoai import Xoai
import co

UP = np.array([0, 0, 1.0])
xoai.LINING = False

FLOWERS = [
    dict(out=['#efe2b4', '#fbf0cc', '#fffae6'], mid=['#e8b93a', '#f6cf4e'], eye='#c98a2a'),
    dict(out=['#d9628f', '#ee86ae', '#fbaecb'], mid=['#eeb236', '#fbd052'], eye='#b4532f'),
    dict(out=['#df7a22', '#f39a33', '#ffbb52'], mid=['#f1c235', '#fde062'], eye='#b85a20'),
    dict(out=['#dcdcd2', '#f2f2ea', '#ffffff'], mid=['#eedc8c', '#f8eaa8'], eye='#c9a64a'),
]


def tones(seed):
    F = FLOWERS[seed % 4]
    return dict(
        green=[C('#24562a'), C('#2e6a2e'), C('#3e7f36'), C('#539542'), C('#6dae4f')],
        und=[C('#2c5530'), C('#386638'), C('#477943')],
        deep=[C('#1f4d25'), C('#26582b'), C('#2f6432')],
        inner=C('#1d4b22'),
        young=[C('#86343a')] * 5,
        bark=dict(lit=C('#8a7a64'), mid=C('#695a48'), dk=C('#4b3f33'), fis=C('#3e332a')),
        fl=dict(out=[C(x) for x in F['out']], mid=[C(x) for x in F['mid']], eye=C(F['eye'])),
    )


class BuiCay(Xoai):
    NROS = 470          # small leaves, so many more rosettes than the mango's
    def __init__(self, seed, pa):
        self.pa = pa; self.seed = seed
        r = self.rng = np.random.default_rng(seed * 4409 + 29)
        self.items = []
        self.T = tones(seed)
        q = seed % 4
        self.flush = []
        self.ce = np.array([0.0, 0.0, 0.4])
        self.ra = [0.78, 0.84, 0.74, 0.82][q]
        self.ry = self.ra * [0.82, 0.78, 0.86, 0.8][q]
        self.rb = 0.4
        self._clumps(r)
        self._stems(r)
        for c in self.cl: self._clump_leaves(r, c)
        self._shoots(r)
        self._heads(r)

    def _clumps(self, r):
        ce, ra, ry = self.ce, self.ra, self.ry
        cl = []
        n0 = [5, 5, 4, 5][self.seed % 4]
        az0 = r.uniform(0, 2 * math.pi)
        for k in range(n0):
            az = az0 + k * 2 * math.pi / n0 + r.normal(0, 0.15)
            d = 0.66 * r.uniform(0.92, 1.08)
            rc = r.uniform(0.38, 0.46)
            c = ce + np.array([math.cos(az) * ra * d, math.sin(az) * ry * d, -0.06 + r.normal(0, 0.03)])
            cl.append(dict(c=c, rc=rc, rz=rc * 0.78, tier=0))
        n2 = [2, 2, 2, 1][self.seed % 4]
        az2 = r.uniform(0, 2 * math.pi)
        for k in range(n2):
            az = az2 + k * 2 * math.pi / n2
            d = 0.2 if n2 > 1 else 0.0
            rc = r.uniform(0.42, 0.48)
            c = ce + np.array([math.cos(az) * ra * d, math.sin(az) * ry * d, 0.24 + r.normal(0, 0.03)])
            cl.append(dict(c=c, rc=rc, rz=rc * 0.74, tier=2))
        for c in cl:
            c['lumps'] = [(nv(r.normal(0, 1, 3)), r.uniform(1.6, 2.6), r.uniform(0, 6.28), r.uniform(0.06, 0.1)) for _ in range(4)]
            c['tv'] = r.uniform(-0.06, 0.05)
            # never let leaves reach under the soil
            assert c['c'][2] - 0.62 * c['rz'] * 1.12 > 0.02, c
        self.cl = cl

    def _stems(self, r):
        """thin woody stems from the soil up into each clump; they show through the gaps low in the bush"""
        Bk = self.T['bark']
        for j, c in enumerate(self.cl):
            for m in range(2 if c['tier'] == 0 else 1):
                b0 = np.array([r.normal(0, 0.05), r.normal(0, 0.04), -0.02])
                Tp = c['c'] + np.array([r.normal(0, 0.08), r.normal(0, 0.08), -c['rz'] * 0.2])
                hz = np.array([Tp[0] - b0[0], Tp[1] - b0[1], 0.0])
                p1 = b0 + hz * 0.25 + UP * 0.12
                p2 = b0 + hz * 0.7 + UP * (Tp[2] - b0[2]) * 0.6
                pts = [bez(b0, p1, p2, Tp, t) for t in np.linspace(0, 1, 12)]
                w0 = 0.028 * r.uniform(0.85, 1.15)
                rads = [w0 * (1 - 0.45 * t) for t in np.linspace(0, 1, 12)]
                col = mixc(Bk['mid'], Bk['lit'], 0.15) if (j + m) % 2 else Bk['mid']
                self._tube(pts, rads, (b0 + Tp) / 2 - TOCAM * 0.3, r=r, col=col)

    def _cluster(self, r, c, p, ns, hc, G, dark=False):
        """a twig end with 4-6 small oval leaves, rough and matte, held out flat and drooping a little"""
        T = self.T
        nrm0 = nv(ns + UP * 0.7)
        t1 = np.cross(nrm0, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(nrm0, t1)
        sun = float(ns @ LIGHT)
        ao = 0.66 + 0.4 * max(-1.0, min(1.0, hc)) + 0.12 * G
        nl = int(r.integers(4, 7))
        az0 = r.uniform(0, 2 * math.pi)
        leaves = []
        for k in range(nl):
            az = az0 + k * 2 * math.pi / nl + r.normal(0, 0.3)
            A = math.cos(az) * t1 + math.sin(az) * t2
            el = r.uniform(0.0, 0.45)
            ld = nv(A * math.cos(el) + nrm0 * math.sin(el) - UP * 0.15)
            sd = nv(np.cross(nrm0, ld))
            Ll = 0.125 * r.uniform(0.85, 1.12); Wl = Ll * 0.62
            pt = p + (r.normal(0, 1, 3) * np.array([1, 1, 0.5])) * 0.018 + ld * 0.008
            # ovate: round base, widest a third of the way out, pointed tip
            prof = [(0.0, 0.25), (0.08, 0.66), (0.22, 0.93), (0.36, 1.0), (0.55, 0.9), (0.74, 0.62), (0.9, 0.3), (1.0, 0.0)]
            Lp_, Rp_ = [], []
            for (t, w) in prof:
                q = pt + ld * Ll * t - UP * Ll * 0.14 * t * t
                Lp_.append(q + sd * Wl * 0.5 * w); Rp_.append(q - sd * Wl * 0.5 * w)
            # a leaf low on the bush that would reach the soil is left off: the bush stands on its stems
            if min(q[2] for q in Lp_ + Rp_) < 0.015: continue
            nn = nv(np.cross(ld, sd))
            if nn @ nrm0 < 0: nn = -nn
            topv = nn @ TOCAM > 0
            lam = float((nn if topv else -nn) @ LIGHT)
            v = (0.62 + 0.3 * max(-0.3, lam)) * ao + 0.2 * sun - 0.06
            leaves.append(dict(poly=Lp_ + Rp_[::-1], top=topv, v=v, lam=lam, mid=pt + ld * Ll * 0.5,
                               rib=(pt, pt + ld * Ll * 0.82 - UP * Ll * 0.1)))
        if not leaves: return leaves
        vm = float(np.mean([z['v'] for z in leaves]))
        for z in leaves:
            v = 0.6 * vm + 0.4 * z['v'] + c['tv']
            if not z['top']:
                z['col'] = T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            else:
                z['col'] = T['green'][0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4]
            z['gloss'] = False
        return leaves

    def _shoots(self, r):
        """2-3 long shoots arching out of the mound, leaves in pairs along them, a flower head at the end"""
        T = self.T; pa = self.pa; Bk = T['bark']
        # shoots leave the bush at its sides or its back, so they come out of the leaves instead of lying on them
        sides = [[0.15, 3.3], [-0.1, -1.9, 2.9], [3.0, -1.2], [0.2, -2.2]][self.seed % 4]
        self.shoot_tips = []
        for az in sides:
            az += r.normal(0, 0.12)
            dh = np.array([math.cos(az), math.sin(az), 0.0])
            sc = np.array([dh[0] * self.ra, dh[1] * self.ry, 0.0])
            b0 = self.ce + sc * 0.62 + UP * 0.02
            tip = self.ce + sc * 1.32 + UP * r.uniform(0.18, 0.32)
            p1 = b0 + (tip - b0) * 0.3 + UP * 0.28
            p2 = b0 + (tip - b0) * 0.72 + UP * 0.22
            pts = [bez(b0, p1, p2, tip, t) for t in np.linspace(0, 1, 16)]
            near = min(self.cl, key=lambda c: np.linalg.norm(c['c'] - b0))
            leaves = []
            for i in (5, 8, 11, 14):
                q = pts[i]; tg = nv(pts[i + 1] - pts[i - 1])
                sd = nv(np.cross(tg, UP))
                for s in (1, -1):
                    ld = nv(sd * s * 0.85 + tg * 0.35 - UP * 0.12)
                    Ll = 0.11 * (1.0 - 0.2 * (i - 5) / 9); Wl = Ll * 0.62
                    sd2 = nv(np.cross(UP, ld))
                    prof = [(0.0, 0.25), (0.08, 0.66), (0.22, 0.93), (0.36, 1.0), (0.55, 0.9), (0.74, 0.62), (0.9, 0.3), (1.0, 0.0)]
                    poly = [q + ld * Ll * t - UP * Ll * 0.12 * t * t + sd2 * Wl * 0.5 * w for t, w in prof] + \
                           [q + ld * Ll * t - UP * Ll * 0.12 * t * t - sd2 * Wl * 0.5 * w for t, w in prof][::-1]
                    lam = float(UP @ LIGHT) * 0.7 + float(ld @ LIGHT) * 0.3
                    col = T['green'][3] if lam > 0.55 else T['green'][2]
                    leaves.append((q + ld * Ll * 0.5, poly, col, q, q + ld * Ll * 0.8))
            def draw(pts=pts, leaves=leaves):
                P = pa.P
                pa.line([P(q) for q in pts], mixc(Bk['mid'], T['green'][1], 0.45), pa.u(0.55))
                for _, poly, col, a, b in sorted(leaves, key=lambda z: depth(z[0])):
                    pp = [P(q) for q in poly]; pa.fill(pp, col); pa.soft_edge(pp, col)
                    pa.line([P(a), P(b)], mixc(col, C('#dfe8b0'), 0.25), pa.u(0.16), 0.6)
            self.items.append((near['c'] - TOCAM * 0.002, draw))
            self.shoot_tips.append((pts[-1], nv(pts[-1] - pts[-3]) * 0.5 + UP * 0.6))

    def _heads(self, r):
        self.heads = []; self.head_fns = []
        self.idmode = False
        """domed lantana flower heads on short stalks over the leaves, mostly on the side the camera sees"""
        T = self.T; pa = self.pa; Fl = T['fl']
        want = [11, 13, 10, 12][self.seed % 4]
        ga = math.pi * (3 - math.sqrt(5))
        cand = []
        for c in self.cl:
            for i in range(60):
                zz = 1 - 2 * (i + 0.5) / 60; rr = math.sqrt(max(0.0, 1 - zz * zz))
                d = np.array([rr * math.cos(i * ga + c['tv'] * 50), rr * math.sin(i * ga + c['tv'] * 50), zz])
                if zz < -0.15: continue
                p = self.env(c, d, 1.0)
                nrm = nv(np.array([d[0] / c['rc'], d[1] / c['rc'], d[2] / c['rz']]))
                if nrm @ TOCAM < 0.2: continue
                if any(self.inside(o, p, 0.96) for o in self.cl if o is not c): continue
                # nor where a nearer clump covers that spot on screen (only a scrap of the head would show)
                if any(self.covers(o, p) for o in self.cl if o is not c and depth(o['c']) > depth(c['c'])): continue
                cand.append((p, nrm, c))
        r.shuffle(cand)
        heads = [(tip, nv(d), None) for tip, d in self.shoot_tips]
        want += len(heads)
        for p, nrm, c in cand:
            sx = np.array([p[0], 0.5 * p[1] - 0.866 * p[2]])
            if all(np.linalg.norm(p - h[0]) > 0.24 and np.linalg.norm(sx - np.array([h[0][0], 0.5 * h[0][1] - 0.866 * h[0][2]])) > 0.2 for h in heads):
                heads.append((p, nrm, c))
            if len(heads) >= want + 6: break
        self.want = want
        for p, nrm, c in heads:
            hn = nv(nrm * 0.55 + UP * 0.7)
            h0 = p + nrm * 0.035 + UP * 0.02
            key = (c['c'] + TOCAM * 0.002) if c is not None else p + TOCAM * 0.01
            fn = self._head_draw(r, h0, hn, p, len(self.heads))
            self.items.append((key, fn)); self.head_fns.append(fn)
            self.heads.append(dict(shoot=c is None, hidden=False))

    def covers(self, o, p):
        sx = lambda q: np.array([q[0], 0.5 * q[1] - 0.866 * q[2]])
        d = sx(p) - sx(o['c'])
        rx = o['rc'] * 1.02; ry = (0.5 * o['rc'] + 0.866 * o['rz']) * 0.92
        return (d[0] / rx) ** 2 + (d[1] / ry) ** 2 < 1.0

    def _head_draw(self, r, h, hn, base, hid):
        T = self.T; pa = self.pa; Fl = T['fl']
        t1 = np.cross(hn, UP); t1 = nv(t1) if np.linalg.norm(t1) > 1e-3 else np.array([1.0, 0, 0])
        t2 = np.cross(hn, t1)
        rh = 0.072 * r.uniform(0.88, 1.1)
        fl = []
        a0 = r.uniform(0, 6.28)
        # outer ring of open flowers, then a smaller ring, then the buds in the middle, on a dome
        for ring, cnt, rho in ((2, 10, 0.9), (1, 7, 0.52), (0, 3, 0.18)):
            for k in range(cnt):
                a = a0 + k * 2 * math.pi / cnt + ring * 0.3
                q = h + (t1 * math.cos(a) + t2 * math.sin(a)) * rh * rho + hn * rh * 0.85 * math.sqrt(max(0.0, 1 - rho * rho))
                nq = nv((q - h) + hn * rh * 0.3)
                fl.append((q, nq, ring))
        rf = 0.026
        def draw():
            P = pa.P; c = pa.ctx
            if self.heads[hid]['hidden']: return
            if self.idmode:
                # the visibility pass: the head in one flat colour of its own
                c.set_source_rgb(1.0, hid / 64.0, 1.0)
                x, y = P(h - hn * rh * 0.1)
                c.save(); c.translate(x, y); c.scale(pa.u(rh * 29 * 0.9), pa.u(rh * 29 * 0.6)); c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore(); c.fill()
                for q, nq, ring in fl:
                    x, y = P(q); c.new_path(); c.arc(x, y, pa.u(rf * 29) * (1.0 if ring == 2 else 0.8), 0, 2 * math.pi); c.fill()
                return
            pa.line([P(base), P(h - hn * 0.01)], T['green'][1], pa.u(0.45))
            # underside of the head, the green calyx cup
            x, y = P(h - hn * rh * 0.1)
            c.save(); c.translate(x, y); c.scale(pa.u(rh * 29 * 0.9), pa.u(rh * 29 * 0.6)); c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
            c.set_source_rgb(*T['green'][1]); c.fill()
            for q, nq, ring in sorted(fl, key=lambda z: depth(z[0])):
                lam = float(nq @ LIGHT)
                if ring == 2:
                    col = Fl['out'][0 if lam < 0.15 else 1 if lam < 0.6 else 2]
                    R = pa.u(rf * 29)
                else:
                    col = Fl['mid'][0 if lam < 0.4 else 1]
                    R = pa.u(rf * 29) * (0.8 if ring == 1 else 0.62)
                x, y = P(q)
                # four round lobes: a tiny flower; the open ones show a darker throat
                pts = []
                for i in range(32):
                    th = i / 32 * 2 * math.pi
                    rr = R * (0.78 + 0.22 * abs(math.cos(2 * th))) if ring else R * 0.9
                    pts.append((x + rr * math.cos(th), y + rr * math.sin(th) * 0.86))
                pa.fill(pts, col); pa.soft_edge(pts, col)
                if ring == 2:
                    c.new_path(); c.arc(x, y, R * 0.2, 0, 2 * math.pi); c.set_source_rgb(*Fl['eye']); c.fill()
        return draw

    def shadow(self):
        co.ground_shadow(self.pa, 0.0, 0.0, self.ra + 0.18, self.ry + 0.12, 0.15)
        co.ground_shadow(self.pa, 0.0, 0.0, self.ra * 0.55, self.ry * 0.5, 0.1)

    def paint(self):
        """a head that leaves in front of it would mostly cover is left off (only a scrap of it would show): paint once
        with every head in a flat colour of its own, then each head alone, and compare the pixel counts"""
        pa = self.pa; ctx0 = pa.ctx; tg = ctx0.get_target()
        W, H = tg.get_width(), tg.get_height()
        items = sorted(self.items, key=lambda z: depth(z[0]))
        def run(fns):
            surf = cairo.ImageSurface(cairo.FORMAT_RGB24, W, H)
            c = cairo.Context(surf); c.set_antialias(cairo.ANTIALIAS_NONE); c.set_source_rgb(0, 0, 0); c.paint()
            pa.ctx = c; self.idmode = True
            try:
                for fn in fns: fn()
            finally:
                pa.ctx = ctx0; self.idmode = False
            surf.flush()
            a = np.ndarray((H, W, 4), np.uint8, surf.get_data())
            mk = (a[:, :, 2] == 255) & (a[:, :, 0] == 255)
            return np.bincount(np.round(a[:, :, 1][mk] / 255.0 * 64).astype(int), minlength=len(self.heads) + 1)
        seen = run([fn for _, fn in items])
        nshoot = sum(1 for z in self.heads if z['shoot'])
        keep = 0
        for hid, hd in enumerate(self.heads):
            alone = run([self.head_fns[hid]])[hid]
            ok = alone > 0 and seen[hid] / alone > 0.8
            if ok and (hd['shoot'] or keep < self.want - nshoot):
                keep += 0 if hd['shoot'] else 1
            else:
                hd['hidden'] = True
        self.nheads = sum(1 for z in self.heads if not z['hidden'])
        co.Plant.paint(self)


FRAMES = [dict(key=str(s), seed=s) for s in range(4)]
BB = (-50, -70, 50, 22)

if __name__ == '__main__':
    co.main(BuiCay, FRAMES, BB, 'buicay.webp', 'buicay')
