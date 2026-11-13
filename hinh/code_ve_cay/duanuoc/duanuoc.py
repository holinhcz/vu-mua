# Dừa nước (nipa palm, Nypa fruticans) for Nông Trại Nhỏ: the clumps that line every river bank of the delta.
# Built like the coconut (../dua/dua.py, same painter, camera, sun and night transform from ../chuoi), but the nipa
# has no trunk: its stem creeps in the mud, and the fronds rise straight out of the bank in a clump, steep and stiff,
# arching out only near the tip. Each frond is a stout bare petiole for its lower third, then two rows of long,
# stiff, glossy leaflets held in a shallow V. Old fronds lean out low and yellow; a cut or dead one hangs down. Some
# clumps carry a fruit head (buồng dừa nước): a ball of brown wedge-shaped fruits on a short stalk at the foot.
import math, os, sys
import numpy as np, cairo
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'chuoi')); sys.path.insert(0, os.path.join(HERE, '..', 'dua'))
import chuoi as ch
from chuoi import Painter, C, nv, mixc, depth, LIGHT, SLIGHT, TOCAM
import dua

RS, SS = dua.RS, dua.SS
PX = RS * SS
KU = dua.KU
UP = np.array([0, 0, 1.0])
S0N = 0.34          # the bare petiole: leaflets start a third of the way up


def tones():
    T = dua.tones()
    # glossier, a little darker and bluer than the coconut's leaves
    T['top'] = [C('#24561f'), C('#2f6a26'), C('#3f8030'), C('#58993b'), C('#7cb24c')]
    T['und'] = [C('#577a37'), C('#6c8f43'), C('#86a85a')]
    T['pet'] = dict(dk=C('#5f6e2c'), mid=C('#7d8c3a'), lit=C('#9fae52'), base=C('#6e5a2e'))
    T['fr'] = dict(dk=C('#3e2814'), mid=C('#6a4422'), lit=C('#8e6232'), hi=C('#b48a52'), stalk=C('#7a6a34'))
    T['mud'] = dict(dk=C('#4a3e2c'), mid=C('#6a5a42'))
    return T


class Nipa(dua.Palm):
    def __init__(self, seed, pa, fruit=False, dead=False, yellow=False, n=None):
        self.pa = pa
        r = self.rng = np.random.default_rng(seed * 733 + 29)
        self.items = []; self.nutitems = []; self.late = []; self.latepet = []; self.frpts = []
        self.T = tones()
        q = seed % 4
        self.fscale = [1.0, 0.9, 0.78, 1.08][q]
        self.spread = [1.0, 1.15, 0.85, 1.05][q]
        self.lift = 0.0
        self.cc = np.array([0.0, 0.0, 0.04])
        self._clump(r, n or [15, 13, 10, 16][q], dead, yellow)
        if fruit: self._fruit(r)

    def _clump(self, r, n, dead, yellow):
        az0 = r.uniform(0, 2 * math.pi)
        fronds = []
        for k in range(n):
            age = k / (n - 1)
            az = az0 + k * 2.39996 + r.normal(0, 0.15)
            e0 = 1.45 - 0.42 * age * self.spread + r.normal(0, 0.05)
            D = 0.32 + 0.7 * age * self.spread + r.normal(0, 0.06)
            Lf = (2.0 + 0.75 * min(1.0, age * 1.8)) * r.uniform(0.92, 1.06) * self.fscale
            fronds.append(dict(az=az, e0=e0, D=D, L=Lf, age=age, kind='green', h=0.0, roll=r.normal(0, 0.15),
                               off=0.05 + 0.2 * age * self.spread + r.uniform(0, 0.05), p=1.9))
        if yellow:
            old = [f for f in fronds if f['age'] > 0.6]
            pick = max(old, key=lambda f: math.sin(f['az']) * 0.5 + abs(math.cos(f['az'])))
            pick['kind'] = 'yellow'; pick['D'] += 0.25
        if dead:
            az = (0.4 if r.random() < 0.5 else math.pi - 0.4) + r.normal(0, 0.15)
            fronds.append(dict(az=az, e0=0.7, D=1.6, L=1.5 * self.fscale, age=1.0, kind='dead', h=0.0, roll=0.0, off=0.3, p=1.3))
        fronds.append(dict(az=az0 + 1.0, e0=1.5, D=0.08, L=1.25 * self.fscale, age=0.0, kind='spear', h=0.0, roll=0.0, off=0.02, p=1.7))
        self.cuts = []
        for f in fronds: self._frond(r, f)
        # cut stubs of old fronds round the foot, and the dark wet foot itself
        for k in range(int(r.integers(3, 6))):
            a = r.uniform(0, 2 * math.pi); d = r.uniform(0.18, 0.34) * self.spread
            self.cuts.append((np.array([math.cos(a) * d, math.sin(a) * d, 0.0]), a, r.uniform(0.12, 0.22)))
        self.items.append((np.array([0.0, -0.4, 0.0]), self._foot))

    def _foot(self):
        pa = self.pa; P = pa.P; T = self.T
        for (p, a, h) in sorted(self.cuts, key=lambda z: depth(z[0])):
            A = np.array([math.cos(a), math.sin(a), 0.0]) * 0.05
            q0 = p; q1 = p + A + UP * h
            pa.taper([P(q0), P((q0 + q1) / 2), P(q1)], pa.u(2.6), pa.u(2.0), T['pet']['base'], outline=T['mud']['dk'], ow=pa.u(0.3))
            top = P(q1)
            pa.ctx.new_path(); pa.ctx.save(); pa.ctx.translate(*top); pa.ctx.scale(pa.u(1.0), pa.u(0.45)); pa.ctx.arc(0, 0, 1, 0, 2 * math.pi)
            pa.ctx.restore(); pa.ctx.set_source_rgb(*mixc(T['pet']['lit'], C('#d8c890'), 0.5)); pa.ctx.fill()

    def _frond(self, r, f):
        A = np.array([math.cos(f['az']), math.sin(f['az']), 0.0])
        base = self.cc + A * f['off']
        m = 40
        R, Td = [base], []
        for k in range(m):
            s = k / m
            e = max(-1.45, f['e0'] - f['D'] * s ** f.get('p', 1.7))
            a = f['az'] + 0.1 * s * (1 if f['roll'] > 0 else -1)
            Ah = np.array([math.cos(a), math.sin(a), 0.0])
            d = Ah * math.cos(e) + UP * math.sin(e)
            Td.append(d); R.append(R[-1] + d * f['L'] / m)
        Td.append(Td[-1])
        R, Td = np.array(R), np.array(Td)
        at = lambda s: (R[min(m, int(round(s * m)))], Td[min(m, int(round(s * m)))])
        kind = f['kind']
        sc = f['L'] / 2.6
        s0 = 0.2 if kind != 'spear' else 0.3
        pinnae = []
        for side in (-1, 1):
            npin = int(f['L'] * (6.2 if kind != 'dead' else 6))
            if kind == 'spear': npin = 7
            s = s0 + r.uniform(0, 0.02); grp = 0; goff = 0.0
            step = (0.985 - s0) / npin
            while s < 0.985:
                gap = 1.0
                if grp <= 0:
                    grp = int(r.integers(3, 6)); goff = r.normal(0, 0.08); gap = 1.4
                grp -= 1
                s += step * (gap - 1.0) * 0.6
                if s >= 0.985: break
                if not (kind != 'spear' and r.random() < (0.2 if kind == 'dead' else 0.04)):
                    sp = 0.5 + (s - s0) * 0.48 / (0.985 - s0) if kind == 'spear' else S0N + (s - s0) * (0.985 - S0N) / (0.985 - s0)
                    pinnae.append(self._pinna(r, f, side, sp, at, sc, goff))
                s += step * r.uniform(0.65, 0.9)
        def rachis_seg(sa, sb):
            xs = np.linspace(sa, sb, 13 if sa == 0 else 7)
            pts3 = [at(x)[0] for x in xs]
            # a stout petiole that narrows into the rachis where the leaflets begin
            ws = [0.01 + 0.038 * (1 - x) ** 1.5 + 0.02 * max(0.0, 1 - x / 0.12) for x in xs]
            if kind == 'spear': ws = [0.03 * (1 - 0.6 * x) + 0.008 for x in xs]
            return pts3, ws
        for side in (-1, 1):
            grp = [p for p in pinnae if p['side'] == side]
            if grp:
                vf = float(np.mean([p['v'] for p in grp]))
                for p in grp: p['v'] = 0.7 * vf + 0.3 * p['v']
        if kind in ('green', 'yellow'):
            sun = math.cos(f['az']) * dua.SUNXY[0] + math.sin(f['az']) * dua.SUNXY[1]
            dv = 0.09 * sun + 0.04
            for p in pinnae: p['v'] += dv
        cuts = [0.0, 0.3, 0.52, 0.74, 1.0001]
        for ci in range(len(cuts) - 1):
            sa, sb = cuts[ci], cuts[ci + 1]
            ps = [p for p in pinnae if sa <= p['s'] < sb]
            rs = rachis_seg(sa, min(1.0, sb + 0.01))
            key = at((sa + min(1.0, sb)) / 2)[0]
            self.items.append((key, self._chunk(ps, rs, kind, ci)))

    def _pinna(self, r, f, side, s, at, sc, goff):
        kind = f['kind']
        p, Tt = at(s)
        Sv = nv(np.cross(Tt, UP)) if abs(Tt[2]) < 0.985 else np.array([1.0, 0, 0])
        Uf = nv(np.cross(Sv, Tt))
        roll = f['roll'] * s * side
        u = (s - S0N) / (0.985 - S0N) * 0.98
        if kind == 'spear':
            al, be, Lp, W, hg = 0.16, 0.25, 0.42 * (1 - 0.5 * u), 0.07, 0.02
        elif kind == 'dead':
            al = 0.4 + r.normal(0, 0.1); be = 1.2 + r.normal(0, 0.15)
            Lp = 0.4 * (0.5 + 0.5 * math.sin(math.pi * min(1, u / 0.8))) * r.uniform(0.5, 1.0); W = 0.045; hg = 0.45
        else:
            tip = max(0.0, (u - 0.75) / 0.25)
            # stiff leaflets swept forward, a shallow V, barely sagging
            al = 0.62 - 0.18 * u - 0.3 * tip ** 0.8 + goff * 0.3 + r.normal(0, 0.03)
            be = 0.5 + 0.2 * u + f['age'] * 0.2 + goff * 0.3 + r.normal(0, 0.04)
            Lp = 0.66 * sc * float(np.interp(u, [0, 0.2, 0.55, 0.85, 1.0], [0.7, 1.0, 0.92, 0.55, 0.18])) * r.uniform(0.94, 1.05)
            W = 0.1 * sc * r.uniform(0.92, 1.08) * (1 - 0.35 * tip); hg = 0.1 + 0.16 * u + 0.15 * f['age']
        out = side * Sv * math.cos(be + roll) - Uf * math.sin(be + roll)
        dp = nv(Tt * math.cos(al) + out * math.sin(al))
        wv = nv(Tt - (Tt @ dp) * dp)
        prof = [(0.0, 0.55), (0.12, 1.0), (0.5, 0.88), (0.82, 0.45), (1.0, 0.0)]
        L, Rr = [], []
        for t, w in prof:
            q = p + dp * Lp * t - UP * Lp * hg * t * t
            L.append(q + wv * W * w * 0.5); Rr.append(q - wv * W * w * 0.5)
        nrm = nv(np.cross(dp, wv))
        if nrm @ Uf < 0: nrm = -nrm
        topv = nrm @ TOCAM > 0
        vis = nrm if topv else -nrm
        lam = float(vis @ LIGHT)
        mid = p + dp * Lp * 0.5
        # lower down, inside the clump, it is darker
        ao = 0.62 + 0.38 * min(1.0, max(0.0, mid[2] / 2.0)) + 0.08 * min(1.0, math.hypot(mid[0], mid[1]) / 1.2)
        v = (0.55 + 0.45 * max(-0.3, lam)) * ao - 0.08
        return dict(s=s, side=side, pts=L + Rr[::-1][1:], top=topv, lam=lam, ao=ao, v=v, mid=mid, young=f['age'] < 0.15 or kind == 'spear')

    def _chunk(self, ps, rs, kind, ci):
        pa = self.pa; T = self.T
        ps = sorted(ps, key=lambda z: depth(z['mid']))
        rpts, rws = rs
        if kind == 'dead': out, ramp = T['dout'], T['dry']
        elif kind == 'yellow': out, ramp = T['yout'], T['yel']
        else: out, ramp = T['out'], None
        def col_of(z):
            v = z['v']
            if ramp is not None:
                i = 0 if v < 0.45 else 1 if v < 0.62 else 2 if v < 0.8 else 3
                return ramp[min(i, len(ramp) - 1)]
            if not z['top']:
                return T['und'][0 if v < 0.5 else 1 if v < 0.7 else 2]
            i = 0 if v < 0.42 else 1 if v < 0.55 else 2 if v < 0.68 else 3 if v < 0.82 else 4
            if z['young']: i = min(4, i + 1)
            return T['top'][i]
        cols = [col_of(z) for z in ps]
        def draw():
            P = pa.P
            # the petiole and rachis first, the leaflets over them
            rp = np.array([P(q) for q in rpts], float); n = len(rp); Lr, Rr = [], []
            for i in range(n):
                a = rp[max(0, i - 1)]; b = rp[min(n - 1, i + 1)]
                d = nv(b - a); nr = np.array([-d[1], d[0]]); w = rws[i] * pa.k
                Lr.append(tuple(rp[i] + nr * w)); Rr.append(tuple(rp[i] - nr * w))
            if kind == 'dead': rc = T['dry'][1]
            elif kind == 'yellow': rc = T['yel'][1]
            else: rc = T['pet']['mid'] if ci == 0 else mixc(T['pet']['lit'], T['top'][2], 0.5)
            pa.fill(Lr + Rr[::-1], rc)
            pa.soft_edge(Lr, rc, close=False); pa.soft_edge(Rr, rc, close=False)
            if ci == 0 and kind in ('green', 'yellow'):
                # the lit side of the stout petiole
                side = Lr if (np.array(Lr[len(Lr) // 2]) - rp[len(rp) // 2]) @ np.array([SLIGHT[0], SLIGHT[1]]) > 0 else Rr
                pa.line([tuple((np.array(q) + rp[i]) / 2) for i, q in enumerate(side)][:-2], T['pet']['lit'], pa.u(0.35), 0.8)
            polys = [[P(q) for q in z['pts']] for z in ps]
            for poly, c in zip(polys, cols):
                pa.fill(poly, c, grow=0.0)
                pa.soft_edge(poly, c)
                pa.line([poly[0], poly[2], poly[4]], mixc(c, out, 0.3), pa.u(0.2), 0.7)
        return draw

    def _fruit(self, r):
        """buồng dừa nước: a ball of brown wedge-shaped fruits on a short stalk, low in the clump on the viewer's side"""
        T = self.T
        a = math.pi / 2 + r.normal(0, 0.4)
        A = np.array([math.cos(a), math.sin(a), 0.0])
        hub = A * 0.26 + UP * 0.42
        R0 = 0.15
        def draw():
            pa = self.pa; P = pa.P; F = T['fr']
            pa.taper([P(A * 0.1), P(A * 0.2 + UP * 0.18), P(hub - UP * R0 * 0.6)], pa.u(2.4), pa.u(1.8), F['stalk'])
            c = np.array(P(hub)); rr = R0 * pa.k
            lt0 = np.array([SLIGHT[0], SLIGHT[1]])
            g = cairo.RadialGradient(c[0] + lt0[0] * rr * 0.4, c[1] + lt0[1] * rr * 0.4, rr * 0.1, c[0], c[1], rr * 1.05)
            g.add_color_stop_rgb(0, *F['lit']); g.add_color_stop_rgb(0.6, *F['mid']); g.add_color_stop_rgb(1, *F['dk'])
            pa.ctx.new_path(); pa.ctx.arc(c[0], c[1], rr * 1.02, 0, 2 * math.pi); pa.ctx.set_source(g); pa.ctx.fill()
            # the fruits: wedges packed over the ball, each a rounded facet, lit from the sun's side
            lt = np.array([SLIGHT[0], SLIGHT[1]])
            facets = []
            for ring, (ph, cnt) in enumerate(((0.0, 1), (0.62, 6), (1.2, 9), (1.75, 10))):
                for k in range(cnt):
                    th = k / cnt * 2 * math.pi + ring * 0.4 + r.normal(0, 0.05)
                    # direction on the sphere facing the camera (ph from the view axis)
                    d = np.array([math.sin(ph) * math.cos(th), math.sin(ph) * math.sin(th), math.cos(ph)])
                    facets.append(d)
            for d in sorted(facets, key=lambda d: d[2]):
                if d[2] < 0.05: continue
                cpos = c + d[:2] * rr * 0.86
                sz = rr * (0.36 if d[2] > 0.9 else 0.3) * (0.55 + 0.45 * d[2])
                lam = float(np.clip(0.5 + 0.6 * (d[:2] @ -lt) * 0.8 + 0.3 * d[2], 0, 1))
                col = F['dk'] if lam < 0.35 else F['mid'] if lam < 0.62 else F['lit'] if lam < 0.85 else F['hi']
                ang = math.atan2(d[1], d[0])
                pa.ctx.save(); pa.ctx.translate(*cpos); pa.ctx.rotate(ang); pa.ctx.scale(sz * (0.7 + 0.3 * d[2]), sz)
                pa.ctx.new_path(); pa.ctx.arc(0, 0, 1, 0, 2 * math.pi); pa.ctx.restore()
                pa.ctx.set_source_rgb(*col); pa.ctx.fill_preserve()
                pa.ctx.set_source_rgb(*mixc(col, F['dk'], 0.5)); pa.ctx.set_line_width(pa.u(0.22)); pa.ctx.stroke()
                # the pale tip of each fruit
                tp = cpos + d[:2] * sz * 0.25
                pa.ctx.new_path(); pa.ctx.arc(tp[0], tp[1], sz * 0.18, 0, 2 * math.pi); pa.ctx.set_source_rgb(*mixc(col, F['hi'], 0.5)); pa.ctx.fill()
        self.items.append((hub + A * 0.3, draw))

    def shadow(self):
        pa = self.pa; c = pa.ctx
        x, y = pa.P(np.array([0.0, 0.1, 0.0]))
        rx = 0.95 * self.fscale * self.spread * pa.k; e = 0.42
        for grow, al in ((1.0, 0.1), (0.62, 0.1)):
            c.save(); c.translate(x, y); c.scale(rx * grow, rx * grow * e); c.new_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
            c.set_source_rgba(0, 0, 0, al); c.fill()

    def paint(self):
        self.shadow()
        for _, fn in sorted(self.items, key=lambda z: depth(z[0])): fn()


# decor clumps: seed & 3 picks the frame. 0 full with a fruit head, 1 broad with a dead frond, 2 small and young,
# 3 tall with a yellowing frond
FRAMES = [dict(seed=0, fruit=True), dict(seed=1, dead=True), dict(seed=2), dict(seed=3, yellow=True, fruit=True)]


def render(fr, night=False, bb=(-110, -120, 110, 30)):
    ch.NIGHT = night
    W = int((bb[2] - bb[0]) * PX); H = int((bb[3] - bb[1]) * PX)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf); ctx.set_antialias(cairo.ANTIALIAS_GOOD)
    pa = Painter(ctx, KU, PX, -bb[0] * PX, -bb[1] * PX)
    f = dict(fr); seed = f.pop('seed')
    Nipa(seed, pa, **f).paint()
    surf.flush(); ch.NIGHT = False
    return surf, bb


def atlas(outdir, tabpath):
    import json
    crops = []
    for night in (False, True):
        for k, fr in enumerate(FRAMES):
            surf, bb = render(fr, night)
            im = dua.to_image(surf)
            a = np.array(im)[:, :, 3]; ys, xs = np.where(a > 0)
            x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(im.width, xs.max() + 3), min(im.height, ys.max() + 3)
            crops.append(('nd'[not night] + str(k), im.crop((x0, y0, x1, y1)), bb[0] + x0 / RS, bb[1] + y0 / RS))
    cols = 4; x = y = rowh = 0; pos = {}
    for k, (name, im, dx, dy) in enumerate(crops):
        if k and k % cols == 0: x = 0; y += rowh + 2; rowh = 0
        pos[name] = (x, y); x += im.width + 2; rowh = max(rowh, im.height)
    Wt = max(pos[n][0] + im.width for n, im, _, _ in crops); Ht = y + rowh
    sheet = Image.new('RGBA', (Wt, Ht), (0, 0, 0, 0)); table = {}
    for name, im, dx, dy in crops:
        sx, sy = pos[name]; sheet.paste(im, (sx, sy))
        table[name] = [sx, sy, im.width, im.height, round(dx, 2), round(dy, 2), round(im.width / RS, 2), round(im.height / RS, 2)]
    path = os.path.join(outdir, 'duanuoc.webp')
    sheet.save(path, 'WEBP', quality=92, alpha_quality=100, method=6)
    open(tabpath, 'w').write(json.dumps(table, separators=(',', ':')))
    print(sheet.size, os.path.getsize(path))
    return table


if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == 'atlas':
        atlas(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else os.path.join(HERE, 'atlas.json'))
    else:
        which = [int(x) for x in sys.argv[1].split(',')] if len(sys.argv) > 1 else range(len(FRAMES))
        night = len(sys.argv) > 2 and sys.argv[2] == 'n'
        tag = sys.argv[3] if len(sys.argv) > 3 else 'a'
        ims = [dua.to_image(render(FRAMES[k], night)[0]) for k in which]
        w = sum(i.width for i in ims); h = ims[0].height
        sheet = Image.new('RGBA', (w, h), (40, 58, 52, 255) if night else (155, 191, 106, 255)); x = 0
        for im in ims:
            sheet.alpha_composite(im, (x, 0)); x += im.width
        sheet.save('/tmp/claude-0/g/duanuoc_%s.png' % tag); print(sheet.size)
