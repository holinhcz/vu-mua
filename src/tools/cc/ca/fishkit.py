# Fish drawing kit: vector shapes in cairo, soft layers in PIL, sticker outline.
# Fish space: x 0 (tail tip) .. 1 (snout), y up, body centred on y=0.
import cairo, math, numpy as np
from PIL import Image, ImageFilter, ImageChops

SS = 2            # supersample factor
W, H = 512, 320   # final sprite size

def hexc(h, a=1.0):
    h = h.lstrip('#')
    return (int(h[0:2], 16)/255, int(h[2:4], 16)/255, int(h[4:6], 16)/255, a)

def mix(c1, c2, t):
    return tuple(c1[i]*(1-t)+c2[i]*t for i in range(4))

def crpath(ctx, pts, closed=True, tension=0.5):
    """Catmull-Rom spline through pts as cairo beziers."""
    n = len(pts)
    if n < 2: return
    P = pts
    ctx.move_to(*P[0])
    rng = range(n) if closed else range(n-1)
    for i in rng:
        p0 = P[(i-1) % n] if closed or i > 0 else P[0]
        p1 = P[i]
        p2 = P[(i+1) % n]
        p3 = P[(i+2) % n] if closed or i+2 < n else P[-1]
        k = tension/3*2
        c1 = (p1[0]+(p2[0]-p0[0])*k/2, p1[1]+(p2[1]-p0[1])*k/2)
        c2 = (p2[0]-(p3[0]-p1[0])*k/2, p2[1]-(p3[1]-p1[1])*k/2)
        ctx.curve_to(*c1, *c2, *p2)
    if closed: ctx.close_path()

def crsample(pts, n=200, closed=False):
    """Sample a Catmull-Rom curve into a polyline."""
    out = []
    m = len(pts)
    segs = m if closed else m-1
    for i in range(segs):
        p0 = pts[(i-1) % m] if closed or i > 0 else pts[0]
        p1 = pts[i]; p2 = pts[(i+1) % m]
        p3 = pts[(i+2) % m] if closed or i+2 < m else pts[-1]
        for j in range(max(2, n//segs)):
            t = j/max(2, n//segs)
            t2, t3 = t*t, t*t*t
            x = 0.5*((2*p1[0])+(-p0[0]+p2[0])*t+(2*p0[0]-5*p1[0]+4*p2[0]-p3[0])*t2+(-p0[0]+3*p1[0]-3*p2[0]+p3[0])*t3)
            y = 0.5*((2*p1[1])+(-p0[1]+p2[1])*t+(2*p0[1]-5*p1[1]+4*p2[1]-p3[1])*t2+(-p0[1]+3*p1[1]-3*p2[1]+p3[1])*t3)
            out.append((x, y))
    if not closed: out.append(pts[-1])
    return out

def lerp(a, b, t): return (a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t)

def poly_at(pl, t):
    """point at arc-length fraction t on polyline"""
    L = [0]
    for i in range(1, len(pl)):
        L.append(L[-1]+math.hypot(pl[i][0]-pl[i-1][0], pl[i][1]-pl[i-1][1]))
    s = t*L[-1]
    for i in range(1, len(pl)):
        if L[i] >= s:
            u = (s-L[i-1])/max(1e-9, L[i]-L[i-1])
            return lerp(pl[i-1], pl[i], u)
    return pl[-1]


class Sprite:
    """A set of RGBA layers composited bottom to top."""
    def __init__(self, scale=0.86, cx=0.07, cy=0.5, w=W, h=H):
        self.w, self.h = w*SS, h*SS
        self.L = scale*self.w          # px per fish unit
        self.ox = cx*self.w
        self.oy = cy*self.h
        self.layers = []              # (PIL image, mode)
        self.body = None              # body path pts

    def surf(self):
        s = cairo.ImageSurface(cairo.FORMAT_ARGB32, self.w, self.h)
        c = cairo.Context(s)
        c.translate(self.ox, self.oy)
        c.scale(self.L, -self.L)
        c.set_line_join(cairo.LINE_JOIN_ROUND)
        c.set_line_cap(cairo.LINE_CAP_ROUND)
        return s, c

    @staticmethod
    def pil(s):
        s.flush()
        a = np.ndarray((s.get_height(), s.get_width(), 4), np.uint8, s.get_data()).copy()
        # cairo is premultiplied BGRA
        b, g, r, al = a[..., 0].astype(np.float32), a[..., 1].astype(np.float32), a[..., 2].astype(np.float32), a[..., 3].astype(np.float32)
        m = np.maximum(al, 1)/255
        out = np.stack([np.clip(r/m, 0, 255), np.clip(g/m, 0, 255), np.clip(b/m, 0, 255), al], -1).astype(np.uint8)
        return Image.fromarray(out, 'RGBA')

    def add(self, img, blur=0, clip=None, op='over', alpha=1.0):
        if blur: img = img.filter(ImageFilter.GaussianBlur(blur*SS))
        if clip is not None:
            a = ImageChops.multiply(img.getchannel('A'), clip)
            img.putalpha(a)
        if alpha < 1:
            img.putalpha(img.getchannel('A').point(lambda v: int(v*alpha)))
        self.layers.append((img, op))
        return img

    def draw(self, fn, blur=0, clip=None, op='over', alpha=1.0):
        s, c = self.surf()
        fn(c)
        return self.add(self.pil(s), blur, clip, op, alpha)

    def mask(self, fn):
        s, c = self.surf()
        c.set_source_rgba(1, 1, 1, 1)
        fn(c)
        return self.pil(s).getchannel('A')

    def flatten(self, layers=None):
        base = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        for img, op in (layers or self.layers):
            if op == 'over':
                base = Image.alpha_composite(base, img)
            elif op in ('multiply', 'screen'):
                # blend colour over existing pixels only (alpha of img = strength)
                b = np.asarray(base).astype(np.float32)/255
                o = np.asarray(img).astype(np.float32)/255
                a = o[..., 3:4]
                if op == 'multiply': blended = b[..., :3]*o[..., :3]
                else: blended = 1-(1-b[..., :3])*(1-o[..., :3])
                rgb = b[..., :3]*(1-a)+blended*a
                base = Image.fromarray((np.concatenate([rgb, b[..., 3:4]], -1)*255).astype(np.uint8), 'RGBA')
        return base

    def finish(self, outline='#2a1a0c', ow=2.2, bend=None, inner=None):
        img = self.flatten()
        if bend: img = bend_warp(img, *bend)
        a = img.getchannel('A')
        k = int(ow*SS)*2+1
        dil = a.point(lambda v: 255 if v > 40 else 0).filter(ImageFilter.MaxFilter(k)).filter(ImageFilter.GaussianBlur(0.7*SS))
        o = Image.new('RGBA', img.size, hexc_int(outline))
        o.putalpha(dil)
        img = Image.alpha_composite(o, img)
        return img.resize((self.w//SS, self.h//SS), Image.LANCZOS)


def hexc_int(h):
    c = hexc(h)
    return (int(c[0]*255), int(c[1]*255), int(c[2]*255), 255)


def bend_warp(img, amp, waves=1.0, phase=0.0, center=0.5):
    """bend horizontally laid sprite: vertical offset by x (amp in fraction of height)"""
    a = np.asarray(img).astype(np.float32)
    h, w = a.shape[:2]
    xs = np.arange(w)/w
    off = amp*h*np.sin((xs-center)*math.pi*2*waves*0.5+phase)
    off -= off[int(w*center)]
    yy = np.arange(h)[:, None]-off[None, :]
    y0 = np.clip(np.floor(yy).astype(int), 0, h-1)
    y1 = np.clip(y0+1, 0, h-1)
    t = (yy-np.floor(yy))[..., None]
    xi = np.arange(w)[None, :].repeat(h, 0)
    out = a[y0, xi]*(1-t)+a[y1, xi]*t
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), 'RGBA')


# ---------- fish building blocks ----------

def body_pts(top, bot):
    """top: from peduncle to snout, bot: from snout to peduncle (snout shared)"""
    return top+bot[1:]

def fill_path(c, pts, col, closed=True):
    crpath(c, pts, closed)
    c.set_source_rgba(*col)
    c.fill()

def vgrad(c, y0, y1, stops):
    g = cairo.LinearGradient(0, y0, 0, y1)
    for t, col in stops: g.add_color_stop_rgba(t, *col)
    return g

def fin(c, base0, base1, outer, col, edge=None, rays=0, raycol=None, spiny=0, rw=0.0025, ew=0.003, fade=None):
    """Fin: membrane from base0 along outer edge to base1. rays drawn base->edge."""
    edge_pl = crsample([base0]+outer+[base1], 120)
    if spiny and rays:
        # membrane edge dips between ray tips
        tips = [poly_at(edge_pl, (i+0.5)/rays) for i in range(rays)]
        bases = [lerp(base0, base1, (i+0.5)/rays) for i in range(rays)]
        pts = [base0]
        for i in range(rays):
            tip = tips[i]; b = bases[i]
            pts.append(tip)
            if i < rays-1:
                nt = tips[i+1]; nb = bases[i+1]
                mid = lerp(tip, nt, 0.5)
                bm = lerp(b, nb, 0.5)
                pts.append(lerp(mid, bm, spiny))
        pts.append(base1)
        c.move_to(*pts[0])
        for p in pts[1:]: c.line_to(*p)
        c.close_path()
    else:
        crpath(c, [base0]+outer+[base1], True)
    if fade:
        # gradient from base to tip
        mb = lerp(base0, base1, 0.5); mt = poly_at(edge_pl, 0.5)
        g = cairo.LinearGradient(mb[0], mb[1], mt[0], mt[1])
        g.add_color_stop_rgba(0, *col)
        g.add_color_stop_rgba(1, *fade)
        c.set_source(g)
    else:
        c.set_source_rgba(*col)
    c.fill_preserve()
    if edge:
        c.set_source_rgba(*edge); c.set_line_width(ew); c.stroke()
    else:
        c.new_path()
    if rays:
        c.set_source_rgba(*(raycol or edge or (0, 0, 0, .3)))
        c.set_line_width(rw)
        for i in range(rays):
            t = (i+0.5)/rays
            b = lerp(base0, base1, t)
            e = poly_at(edge_pl, t)
            e = lerp(b, e, 1.0 if spiny else 0.93)
            c.move_to(*b); c.line_to(*e); c.stroke()

def eye(c, x, y, r, iris='#c89a2a', ring='#f4ecd0', pupil='#120c08'):
    c.arc(x, y, r*1.18, 0, 2*math.pi); c.set_source_rgba(*hexc('#1d140c', .55)); c.fill()
    c.arc(x, y, r, 0, 2*math.pi)
    g = cairo.RadialGradient(x, y+r*.3, 0, x, y, r)
    g.add_color_stop_rgba(0, *hexc(ring)); g.add_color_stop_rgba(1, *mix(hexc(iris), (0, 0, 0, 1), .25))
    c.set_source(g); c.fill()
    c.arc(x, y, r*.78, 0, 2*math.pi); c.set_source_rgba(*hexc(iris)); c.fill()
    c.arc(x+r*.08, y, r*.52, 0, 2*math.pi); c.set_source_rgba(*hexc(pupil)); c.fill()
    c.arc(x+r*.28, y+r*.3, r*.2, 0, 2*math.pi); c.set_source_rgba(1, 1, 1, .95); c.fill()
    c.arc(x-r*.18, y-r*.32, r*.09, 0, 2*math.pi); c.set_source_rgba(1, 1, 1, .6); c.fill()

def barbel(c, pts, w0, w1, col):
    pl = crsample(pts, 60, False)
    n = len(pl)
    for i in range(n-1):
        t = i/(n-1)
        c.set_line_width(w0+(w1-w0)*t)
        c.move_to(*pl[i]); c.line_to(*pl[i+1])
        c.set_source_rgba(*col); c.stroke()

def scales(c, x0, x1, y0, y1, sx, sy, col, lw=0.0022, shrink=None):
    """scallop rows; shrink(x)->scale factor"""
    row = 0
    y = y1
    while y > y0:
        x = x0 + (sx*0.5 if row % 2 else 0)
        while x < x1:
            k = shrink(x) if shrink else 1
            r = sx*0.62*k
            c.new_sub_path()
            c.arc(x, y, r, math.pi*0.58, math.pi*1.42)
            x += sx*k
        y -= sy
        row += 1
    c.set_source_rgba(*col); c.set_line_width(lw); c.stroke()


def tube_outline(center, widths):
    """outline polygon of a tube along centre pts (list) with half-widths list"""
    L, R = [], []
    n = len(center)
    for i in range(n):
        p = center[i]
        a = center[max(0, i-1)]; b = center[min(n-1, i+1)]
        dx, dy = b[0]-a[0], b[1]-a[1]
        d = math.hypot(dx, dy) or 1
        nx, ny = -dy/d, dx/d
        L.append((p[0]+nx*widths[i], p[1]+ny*widths[i]))
        R.append((p[0]-nx*widths[i], p[1]-ny*widths[i]))
    return L, R[::-1]
