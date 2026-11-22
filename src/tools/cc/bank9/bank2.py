# Bright, sunny Mekong-delta far bank (v3). Replaces scene.build_bank / build_fg.
import cairo, math, random, os
import numpy as np
from PIL import Image, ImageFilter
from fishkit import hexc, mix, crpath, lerp
from scene import new, to_np, rgba, leaf, bez, bez_tan, hyacinth, vgrad_px, OUT, BW, BH, WL

SHADOW = hexc('#1f5a48')
def C(h, k=0.0, a=1.0):
    c = hexc(h) if isinstance(h, str) else h
    c = mix(c, SHADOW, k) if k > 0 else mix(c, (1, 1, .9, 1), -k) if k < 0 else c
    return (c[0], c[1], c[2], a)

def dk(h, f):
    c = hexc(h) if isinstance(h, str) else h
    return (c[0]*f, c[1]*f, c[2]*f, 1.0)

def lt(h, t, to=(1, 1, .86, 1)):
    c = hexc(h) if isinstance(h, str) else h
    return mix(c, to, t)

def rr(*a):
    """RNG phụ cho chi tiết thêm (không đụng chuỗi R gốc -> bố cục giữ nguyên)"""
    return random.Random(int(sum(v*(31+i*17) for i, v in enumerate(a))*1000) & 0x7fffffff)

# ---------- palms ----------
def frond(c, R, base, ang, length, droop, leaflen, dark, light, lw, rach, ldroop, k, dens=1.0, up=0.0):
    """cartoon frond: a few broad, smooth leaflets per side (no saw teeth), flat light/mid tones, pale midrib"""
    dx, dy = math.sin(ang), -math.cos(ang)
    side = 1 if dx >= 0 else -1
    p0 = base
    p1 = (base[0]+dx*length*.55, base[1]+dy*length*.6)
    p2 = (base[0]+dx*length*.92+side*droop*length*.2, base[1]+dy*length*.7+droop*length*.6)
    n = max(3, int(4*dens*length/200)+2)
    for sk in (-1, 1):
        for i in range(n):
            t = .12+.86*i/n
            p = bez(p0, p1, p2, t); tx, ty = bez_tan(p0, p1, p2, t); nx, ny = -ty*sk, tx*sk
            L = leaflen*1.35*(math.sin(min(1, t*1.05)*math.pi)*.7+.3)
            e = (p[0]+(tx*.6+nx*.8)*L, p[1]+(ty*.6+ny*.8)*L+L*ldroop*.9-up*L)
            col = light if ny < 0 else mix_hex(dark, light, .5)
            leaf(c, p, e, L*.36, .2*sk)
            c.set_source_rgba(*C(col, k)); c.fill_preserve()
            c.set_source_rgba(*C(dark, k, .9)); c.set_line_width(1.6); c.stroke()
    c.move_to(*p0); c.curve_to(*lerp(p0, p1, .66), *lerp(p2, p1, .66), *p2)
    c.set_source_rgba(*C(rach, k)); c.set_line_width(max(2, lw*.7)); c.stroke()

def mix_hex(a, b, t):
    ca, cb = hexc(a), hexc(b)
    return '#%02x%02x%02x' % tuple(int(255*(ca[i]+(cb[i]-ca[i])*t)) for i in range(3))

def coco_frond(c, R, base, ang, L, k, depth, stiff=1.0, lf=.27, hang=.32, pal=None, erect=False):
    """one coconut frond: long arching rachis that rises then bows down; leaflets swept toward the tip, hanging a bit (2.5D: lit top side, shaded underside)"""
    dx, dy = math.sin(ang), -math.cos(ang)
    side = 1 if dx >= 0 else -1
    bow = (.25+.55*min(1, abs(ang)/1.6))*stiff
    p0 = base
    p1 = (base[0]+dx*L*.55, base[1]+dy*L*.55-L*(.22-.1*bow))
    p2 = (base[0]+dx*L*.92+side*L*.06, base[1]+dy*L*.4+bow*L*.55)
    if erect:   # dừa nước: nearly straight fronds, only the last third bends outward
        p1 = (base[0]+dx*L*.6, base[1]+dy*L*.6)
        p2 = (base[0]+dx*L*.92+side*L*.12, base[1]+dy*L*.86+L*.08)
    lite, mid, dark = pal or [('#a8d44c', '#72ae38', '#40782a'), ('#8ec242', '#5c9a30', '#336c26'), ('#6c9e3a', '#4a802e', '#2a5c24')][depth]
    n = 22
    pts = []
    for i in range(n):
        t = .08+.9*i/n
        p = bez(p0, p1, p2, t); tx, ty = bez_tan(p0, p1, p2, t)
        m = math.hypot(tx, ty) or 1; tx, ty = tx/m, ty/m
        Lf = L*lf*(math.sin(min(1, t*1.1)*math.pi)*.75+.25)
        for sk in (-1, 1):
            nx, ny = -ty*sk, tx*sk
            vx, vy = tx*.62+nx*.62, ty*.62+ny*.62+hang
            mm = math.hypot(vx, vy) or 1; vx, vy = vx/mm, vy/mm
            e = (p[0]+vx*Lf, p[1]+vy*Lf+R.uniform(-1, 1))
            upper = (ny < 0)
            pts.append((0 if upper else 1, p, e, Lf, sk, upper))
    # underside leaflets first (darker), then the lit upper row
    for under, p, e, Lf, sk, upper in sorted(pts, key=lambda q: -q[0]):
        col = lite if upper else dark
        tt = math.hypot(e[0]-base[0], e[1]-base[1])/L
        if tt > .85: col = mix_hex(col, '#c8c04a', .3)
        leaf(c, p, e, max(1.5, Lf*.12), .14*sk)
        gl = cairo.LinearGradient(p[0], p[1], e[0], e[1])
        gl.add_color_stop_rgba(0, *dk(col, .78)); gl.add_color_stop_rgba(.45, *C(col)); gl.add_color_stop_rgba(1, *lt(col, .22))
        c.set_source(gl); c.fill_preserve()
        c.set_source_rgba(*dk(col, .8)); c.set_line_width(.45); c.stroke()
        # gân lá sáng chạy dọc phiến
        c.move_to(*lerp(p, e, .08)); c.line_to(*lerp(p, e, .85))
        c.set_source_rgba(*lt(col, .35)[:3], .35); c.set_line_width(.35); c.stroke()
    c.move_to(*p0); c.curve_to(*lerp(p0, p1, 2/3), *lerp(p2, p1, 2/3), *p2)
    c.set_source_rgba(*C('#d6c870' if pal is None else '#b8c860')); c.set_line_width(max(1.6, L*(.016 if pal is None else .02))); c.stroke()

def coconut(c, R, x, y, h, lean, s=1.0, k=0.0):
    """cây dừa: slender curved ringed trunk shaded as a cylinder, crown of arching fronds, coconut bunch"""
    top = (x+lean*h*.42, y-h)
    ctrl = (x+lean*h*.42, y-h*.42) if abs(lean) > .6 else (x-lean*h*.1, y-h*.5)
    N = 48; Lp, Rp, P = [], [], []
    for i in range(N+1):
        t = i/N; p = bez((x, y), ctrl, top, t); tx, ty = bez_tan((x, y), ctrl, top, t)
        m = math.hypot(tx, ty) or 1; nx, ny = -ty/m, tx/m
        w = (11-4.5*t+(7*(1-t/.12) if t < .12 else 0))*s
        P.append((p, nx, ny, w))
        Lp.append((p[0]+nx*w, p[1]+ny*w)); Rp.append((p[0]-nx*w, p[1]-ny*w))
    def outline():
        c.move_to(*Lp[0])
        for q in Lp[1:]: c.line_to(*q)
        for q in reversed(Rp): c.line_to(*q)
        c.close_path()
    # cylinder shading: lit from upper-left -> left edge pale, right edge dark
    outline(); c.set_source_rgba(*C('#a8977a')); c.fill()
    for (p, nx, ny, w), (p2, _, _, w2) in zip(P[:-1], P[1:]):
        side = 1 if nx < 0 else -1  # which normal points left
        c.move_to(p[0]+nx*w*side, p[1]+ny*w*side); c.line_to(p[0]+nx*w*side*.25, p[1]+ny*w*side*.25)
        c.line_to(p2[0]+nx*w2*side*.25, p2[1]+ny*w2*side*.25); c.line_to(p2[0]+nx*w2*side, p2[1]+ny*w2*side); c.close_path()
        c.set_source_rgba(*C('#d9ccb0')); c.fill()
        c.move_to(p[0]-nx*w*side, p[1]-ny*w*side); c.line_to(p[0]-nx*w*side*.45, p[1]-ny*w*side*.45)
        c.line_to(p2[0]-nx*w2*side*.45, p2[1]-ny*w2*side*.45); c.line_to(p2[0]-nx*w2*side, p2[1]-ny*w2*side); c.close_path()
        c.set_source_rgba(*C('#776650')); c.fill()
    # growth rings (short arcs)
    for i in range(4, N-1, 2):
        p, nx, ny, w = P[i]
        c.move_to(p[0]+nx*w*.9, p[1]+ny*w*.9); c.line_to(p[0]-nx*w*.9, p[1]-ny*w*.9)
        c.set_source_rgba(1, .96, .85, .25); c.set_line_width(.6*s); c.stroke()
    for i in range(3, N-1, 2):
        p, nx, ny, w = P[i]
        c.move_to(p[0]+nx*w*.95, p[1]+ny*w*.95); c.line_to(p[0]-nx*w*.95, p[1]-ny*w*.95)
        c.set_source_rgba(*C('#5e4e3a', 0, .4)); c.set_line_width(1.1*s); c.stroke()
    outline(); c.set_source_rgba(*C('#4a3c2c', 0, .7)); c.set_line_width(1.2); c.stroke()
    m = R.randint(11, 13)
    angs = [-2.5+5.0*i/(m-1)+R.uniform(-.12, .12) for i in range(m)]
    back = [a for a in angs if abs(a) < .9]; rest = sorted([a for a in angs if abs(a) >= .9], key=abs)
    for a in back: coco_frond(c, R, top, a, R.uniform(120, 150)*s, s, 2)
    if R.random() < .5:
        sd = R.choice([-1, 1])
        c.move_to(*top); c.curve_to(top[0]+sd*16*s, top[1]+30*s, top[0]+sd*20*s, top[1]+64*s, top[0]+sd*12*s, top[1]+100*s)
        c.set_source_rgba(*C('#9a7a48')); c.set_line_width(3*s); c.stroke()
        for j in range(14):
            t = j/14; p = (top[0]+sd*(17+t*2)*s, top[1]+(16+t*82)*s)
            c.move_to(*p); c.line_to(p[0]+sd*R.uniform(3, 10)*s, p[1]+R.uniform(9, 18)*s)
        c.set_source_rgba(*C('#a88456')); c.set_line_width(1.6*s); c.stroke()
    for i in range(R.randint(5, 8)):
        px, py = top[0]+R.uniform(-13, 13)*s, top[1]+R.uniform(5, 18)*s
        rg = cairo.RadialGradient(px-3*s, py-3*s, 1, px, py, 8*s)
        base = R.choice(['#7aae3a', '#9ab83a', '#c8a83a'])
        rg.add_color_stop_rgba(0, *C(mix_hex(base, '#ffffe0', .35))); rg.add_color_stop_rgba(1, *C(mix_hex(base, '#203010', .45)))
        c.arc(px, py, 7.5*s, 0, 6.3); c.set_source(rg); c.fill_preserve()
        c.set_source_rgba(*C('#2a3a14', 0, .5)); c.set_line_width(.8); c.stroke()
    for a in rest: coco_frond(c, R, top, a, R.uniform(165, 215)*s*(1.05 if abs(a) > 1.6 else 1), s, 0 if abs(a) > 1.7 else 1)

def nipa(c, R, x, y, s=1.0, k=0.0):
    n = R.randint(6, 8)
    angs = sorted([R.uniform(-.75, .75) for _ in range(n)], key=lambda a: -abs(a))
    for a in angs:
        L = 380*s*R.uniform(.75, 1.1)*(1-.25*abs(a))
        frond(c, R, (x+R.uniform(-16, 16)*s, y), a, L, .12+abs(a)*.35, 40*s, '#256a3a', '#8cc84a', 3.4*s, '#d0c058', .05, k+(.15 if abs(a) > .55 else 0), .9, .35)

# ---------- shrubs & trees ----------
def leafy_clump(c, R, cx, cy, rx, ry, n, light, mid, dark, k, size=(7, 12), s=1.0):
    """2.5D canopy, cel-shaded: dark silhouette of merged leaf masses, mid tone shifted up-left, a light cap on top, leaf dabs"""
    m = max(3, min(12, n//28))
    blobs = []
    for i in range(m):
        a = R.uniform(0, 2*math.pi); r = math.sqrt(R.random())*.6
        blobs.append((cx+math.cos(a)*r*rx, cy+math.sin(a)*r*ry, R.uniform(.38, .55)*min(rx, ry*1.3)))
    def shape(dx, dy, sc):
        for bx, by, br in blobs:
            c.new_sub_path(); c.arc(bx+dx*br, by+dy*br, br*sc, 0, 2*math.pi)
            # scalloped leafy rim: small bumps around each mass
            for j in range(9):
                an = j/9*2*math.pi+bx*.01
                c.new_sub_path(); c.arc(bx+dx*br+math.cos(an)*br*sc*.9, by+dy*br+math.sin(an)*br*sc*.9, br*sc*.24, 0, 2*math.pi)
    shape(0, 0, 1); c.set_source_rgba(*C(dark, k)); c.fill()
    shape(0, 0, 1); c.save(); c.clip()
    shape(-.14, -.18, .9); c.set_source_rgba(*C(mid, k)); c.fill()
    shape(-.3, -.36, .62); c.set_source_rgba(*C(light, k)); c.fill()
    for bx, by, br in blobs:
        for j in range(int(br*.3)):
            an = R.uniform(math.pi*1.0, math.pi*1.75); r = br*R.uniform(.35, .9)
            px, py = bx+math.cos(an)*r, by+math.sin(an)*r
            ln = R.uniform(*size)*s; aa = R.uniform(0, 6.3)
            leaf(c, (px, py), (px+math.cos(aa)*ln, py+math.sin(aa)*ln), ln*.5, .2)
            c.set_source_rgba(*C(mix_hex(light, '#ffffe0', .25), k, .6)); c.fill()
        for j in range(int(br*.2)):
            an = R.uniform(0, math.pi*.9); r = br*R.uniform(.4, .95)
            px, py = bx+math.cos(an)*r, by+math.sin(an)*r
            ln = R.uniform(*size)*s; aa = R.uniform(0, 6.3)
            leaf(c, (px, py), (px+math.cos(aa)*ln, py+math.sin(aa)*ln), ln*.5, .2)
            c.set_source_rgba(*C(dark, k, .7)); c.fill()
    r2 = rr(cx, cy, rx)
    for bx, by, br in blobs:
        nlv = int(br*br/9)
        for j in range(nlv):
            an = r2.uniform(0, 6.283); r = br*math.sqrt(r2.random())*.98
            px, py = bx+math.cos(an)*r, by+math.sin(an)*r
            lit = -(math.cos(an)*-.55+math.sin(an)*-.83)*r/br          # -1 tối .. 1 sáng (nắng trên trái)
            lit += r2.uniform(-.35, .35)
            base = light if lit > .3 else mid if lit > -.55 else dark
            ln = r2.uniform(size[0]*.55, size[1]*.75)*s; aa = an+r2.uniform(-1.2, 1.2)
            q = (px+math.cos(aa)*ln, py+math.sin(aa)*ln)
            leaf(c, (px, py), q, ln*.46, r2.uniform(-.2, .2))
            g2 = cairo.LinearGradient(px, py, *q)
            g2.add_color_stop_rgba(0, *dk(C(base, k), .9)); g2.add_color_stop_rgba(1, *lt(C(base, k), .14 if lit > 0 else .04))
            c.set_source(g2); c.fill_preserve()
            c.set_source_rgba(*dk(C(base, k), .8)[:3], .7); c.set_line_width(.35); c.stroke()
    c.restore()

def fruit_tree(c, R, x, y, h, w, fruit=None, s=1.0, k=0.0):
    c.move_to(x, y); c.curve_to(x-8*s, y-h*.3, x+10*s, y-h*.45, x+R.uniform(-12, 12)*s, y-h*.6)
    c.set_source_rgba(*C('#6a4a2e', k)); c.set_line_width(14*s); c.stroke()
    for i in range(4):
        a = R.uniform(-1.1, 1.1)
        c.move_to(x, y-h*.42); c.curve_to(x+a*w*.15, y-h*.55, x+a*w*.3, y-h*.6, x+a*w*.38, y-h*.72)
        c.set_line_width(6*s); c.stroke()
    blobs = [(R.uniform(-.32, .32)*w, -h*R.uniform(.62, .86), R.uniform(.22, .32)*w) for _ in range(7)]
    blobs.sort(key=lambda b: -b[1])
    for bx, by, r in blobs:
        leafy_clump(c, R, x+bx, y+by, r, r*.75, int(r*r/18*s)+40, '#b4dc5a', '#5aa83c', '#22603e', k, (8, 13), s)
    if fruit:
        for i in range(int(w/6)):
            a = R.uniform(0, 2*math.pi); r = math.sqrt(R.random())*.9
            px = x+math.cos(a)*r*w*.4; py = y-h*.72+math.sin(a)*r*h*.18+8*s
            if fruit == 'xoai':
                c.save(); c.translate(px, py); c.rotate(.3); c.scale(.7, 1); c.arc(0, 0, 6*s, 0, 6.3); c.restore()
                c.set_source_rgba(*C(R.choice(['#f0c040', '#e8a030', '#c8c840']), k)); c.fill()
            else:  # chôm chôm clusters
                for j in range(3):
                    c.arc(px+R.uniform(-5, 5)*s, py+R.uniform(-3, 5)*s, 4*s, 0, 6.3)
                    c.set_source_rgba(*C(R.choice(['#e0302a', '#c82a2a', '#f05040']), k)); c.fill()

def dien_dien(c, R, x, y, s=1.0, k=0.0):
    """bông điên điển: feathery shrub with hanging yellow flowers"""
    tips = []
    for i in range(R.randint(5, 7)):
        a = R.uniform(-.7, .7); h = R.uniform(110, 170)*s
        tip = (x+math.sin(a)*h, y-math.cos(a)*h)
        c.move_to(x, y); c.curve_to(x+math.sin(a)*h*.2, y-h*.5, tip[0]-math.sin(a)*20, tip[1]+30, *tip)
        c.set_source_rgba(*C('#7a6a3a', k)); c.set_line_width(3*s); c.stroke()
        tips.append(tip)
    for tp in tips:
        for j in range(5):
            a = R.uniform(-2.2, 2.2)
            frond(c, R, (tp[0]+R.uniform(-30, 30)*s, tp[1]+R.uniform(-10, 40)*s), a, R.uniform(40, 70)*s, .4, 9*s, '#4a9a3a', '#b8e070', 2.6*s, '#7a9a3a', .3, k, 1.2)
    for tp in tips:
        for j in range(R.randint(4, 8)):
            px, py = tp[0]+R.uniform(-40, 40)*s, tp[1]+R.uniform(-10, 50)*s
            for q in range(5):
                fx, fy = px+R.uniform(-4, 4)*s, py+q*5*s
                c.save(); c.translate(fx, fy); c.rotate(R.uniform(-.5, .5)); c.scale(1, .7); c.arc(0, 0, 4.2*s, 0, 6.3); c.restore()
                c.set_source_rgba(*C(R.choice(['#ffd030', '#f8c020', '#ffe060']), k)); c.fill()

def banana(c, R, x, y, s=1.0, k=0.0):
    """chuối: tapered pseudo-stems, long leaves arching out then drooping, lit upper half / shaded lower half, torn edges"""
    for i in range(R.randint(2, 3)):
        bx = x+R.uniform(-26, 26)*s; h = R.uniform(110, 160)*s; tx_ = bx+R.uniform(-8, 8)*s
        c.move_to(bx-8*s, y); c.line_to(tx_-5*s, y-h); c.line_to(tx_+5*s, y-h); c.line_to(bx+8*s, y); c.close_path()
        gr = cairo.LinearGradient(bx-8*s, 0, bx+8*s, 0)
        gr.add_color_stop_rgba(0, *C('#b8d878', k)); gr.add_color_stop_rgba(1, *C('#5a8a3a', k)); c.set_source(gr); c.fill()
        top = (tx_, y-h)
        # young rolled leaf pointing up
        c.move_to(top[0]-3*s, top[1]); c.curve_to(top[0]-4*s, top[1]-40*s, top[0]+2*s, top[1]-60*s, top[0]+6*s, top[1]-72*s)
        c.set_source_rgba(*C('#a8d860', k)); c.set_line_width(6*s); c.stroke()
        nl = R.randint(5, 6)
        for j in range(nl):
            a = (-1.45+2.9*j/(nl-1)+R.uniform(-.15, .15))
            L = R.uniform(120, 160)*s*(1-.15*(1-abs(a)/1.45))
            sd = 1 if a >= 0 else -1
            p0 = top; p1 = (top[0]+math.sin(a)*L*.5, top[1]-math.cos(a)*L*.55-L*.12)
            p2 = (top[0]+math.sin(a)*L*.95, top[1]-math.cos(a)*L*.25+L*.25*abs(math.sin(a)))
            N = 16; up, lo = [], []
            notches = set(R.sample(range(3, N-2), R.randint(1, 3)))
            for q in range(N+1):
                t = q/N; p = bez(p0, p1, p2, t); tx, ty = bez_tan(p0, p1, p2, t)
                m = math.hypot(tx, ty) or 1; nx, ny = -ty/m, tx/m
                if ny > 0: nx, ny = -nx, -ny          # nx,ny = side facing up
                w = math.sin(t*math.pi)**.55*21*s
                up.append((p[0]+nx*w*(.2 if q in notches and sd > 0 else 1), p[1]+ny*w*(.2 if q in notches and sd > 0 else 1)))
                lo.append((p[0]-nx*w*(.2 if q in notches and sd < 0 else 1), p[1]-ny*w*(.2 if q in notches and sd < 0 else 1)))
            mid = [bez(p0, p1, p2, q/N) for q in range(N+1)]
            c.move_to(*mid[0])
            for q in up: c.line_to(*q)
            for q in reversed(mid): c.line_to(*q)
            c.close_path(); c.set_source_rgba(*C('#8cc84a', k)); c.fill()
            c.move_to(*mid[0])
            for q in lo: c.line_to(*q)
            for q in reversed(mid): c.line_to(*q)
            c.close_path(); c.set_source_rgba(*C('#3e8432', k)); c.fill()
            c.move_to(*p0); c.curve_to(*lerp(p0, p1, .66), *lerp(p2, p1, .66), *p2)
            c.set_source_rgba(*C('#d8e890', k, .9)); c.set_line_width(1.8*s); c.stroke()
            for q in range(2, N-1):
                t = q/N; pm = mid[q]
                for side, arr, colv in ((1, up, '#b4e070'), (-1, lo, '#2e6a28')):
                    e = arr[min(N, q+1)]
                    c.move_to(*pm); c.line_to(pm[0]+(e[0]-pm[0])*.92, pm[1]+(e[1]-pm[1])*.92)
                    c.set_source_rgba(*C(colv, k, .45)); c.set_line_width(.5*s); c.stroke()

def hibiscus(c, R, x, y, w, s=1.0, k=0.0):
    leafy_clump(c, R, x, y-30*s, w/2, 34*s, int(w*1.2), '#9ad050', '#4a9a38', '#1f5a3a', k, (7, 11), s)
    for i in range(int(w/14)):
        px, py = x+R.uniform(-w*.45, w*.45), y-30*s+R.uniform(-26, 20)*s
        for p in range(5):
            c.save(); c.translate(px, py); c.rotate(p*1.256); c.scale(1, .7); c.arc(5*s, 0, 5*s, 0, 6.3); c.restore()
        c.set_source_rgba(*C('#e8302a', k)); c.fill()
        c.arc(px, py, 1.6*s, 0, 6.3); c.set_source_rgba(1, .9, .4, 1); c.fill()

def grass_bank(c, R, x0, x1, top=WL-14):
    pts = [(x0, WL+30)]
    x = x0
    while x < x1:
        pts.append((x, top+R.uniform(-6, 6))); x += R.uniform(40, 80)
    pts += [(x1, top), (x1, WL+30)]
    crpath(c, pts, True)
    c.set_source(vgrad_px(top-6, WL+4, [(0, C('#86c44a')), (.5, C('#5ea23c')), (.74, C('#4a8e3c')), (.84, C('#a88a52')), (1, C('#7a6040'))])); c.fill()
    for i in range(int((x1-x0)/5)):
        gx = R.uniform(x0, x1); gy = top+R.uniform(-2, 8)
        L = R.uniform(8, 20)
        leaf(c, (gx, gy), (gx+R.uniform(-6, 6), gy-L), 2.4, R.uniform(-.2, .2))
        c.set_source_rgba(*C(R.choice(['#8ac848', '#6aaa3a', '#a8d858', '#4a8a34']))); c.fill()

# ---------- buildings ----------
def nha_la(c, g, R, x, y, s=1.0):
    """nhà lá: golden thatch, plank walls, blue shutters, hammock, clothesline, bến + xuồng"""
    W, Hh = 300*s, 120*s
    floor = y-56*s
    for i in range(7):
        px = x-W*.48+i*W*.16
        c.move_to(px, floor); c.line_to(px+R.uniform(-3, 3), y+6)
        c.set_source_rgba(*C('#6a4a30')); c.set_line_width(7*s); c.stroke()
    c.rectangle(x-W*.52, floor-6*s, W*1.04, 10*s); c.set_source_rgba(*C('#7a5434')); c.fill()
    # nhà tre mái tranh in 3/4 view: bamboo-pole walls, a darker gable side, thick straw roof
    wx0, wx1, wtop = x-W*.42, x+W*.42, floor-Hh*.8
    fl = floor-6*s
    ox, oy = W*.2, -W*.08                      # receding side direction
    def poles(xa, xb, ya0, ya1, yb0, yb1, n, k):
        for i in range(n):
            t0, t1 = i/n, (i+1)/n
            xa_, xb_ = xa+(xb-xa)*t0, xa+(xb-xa)*t1
            ta = ya0+(yb0-ya0)*t0; tb = ya0+(yb0-ya0)*t1; ba = ya1+(yb1-ya1)*t0; bb = ya1+(yb1-ya1)*t1
            c.move_to(xa_, ta); c.line_to(xb_, tb); c.line_to(xb_, bb); c.line_to(xa_, ba); c.close_path()
            gr = cairo.LinearGradient(xa_, 0, xb_, 0)
            gr.add_color_stop_rgba(0, *C(mix_hex('#e8cc88', '#8a6a38', k))); gr.add_color_stop_rgba(.35, *C(mix_hex('#f4dca0', '#9a7a44', k)))
            gr.add_color_stop_rgba(1, *C(mix_hex('#b08a4a', '#5a4220', k)))
            c.set_source(gr); c.fill()
            # khe tối giữa 2 cây tre
            c.move_to(xb_, tb); c.line_to(xb_, bb); c.set_source_rgba(*C(mix_hex('#5a4018', '#2a1a08', k), 0, .55)); c.set_line_width(.9*s); c.stroke()
            top, bot = min(ta, tb), max(ba, bb)
            yy = top+14*s+R.uniform(0, 8)*s
            while yy < bot-4*s:
                c.move_to(xa_+1, yy+(tb-ta)*.5); c.line_to(xb_-1, yy+(tb-ta)*.5)
                c.set_source_rgba(*C(mix_hex('#7a5a2a', '#3a2810', k), 0, .8)); c.set_line_width(1.6*s); c.stroke()
                c.move_to(xa_+1, yy+(tb-ta)*.5-1.4*s); c.line_to(xb_-1, yy+(tb-ta)*.5-1.4*s)
                c.set_source_rgba(1, .95, .8, .35); c.set_line_width(.8*s); c.stroke()
                yy += R.uniform(20, 28)*s
    # side (gable) wall
    poles(wx1, wx1+ox, wtop, fl, wtop+oy, fl+oy, 6, .55)
    rh = 78*s
    rL, rR = (wx0+ox*.5, wtop+oy*.5-rh), (wx1+ox*.5, wtop+oy*.5-rh)
    c.move_to(wx1, wtop); c.line_to(wx1+ox, wtop+oy); c.line_to(*rR); c.close_path()
    c.set_source_rgba(*C('#7a5a30')); c.fill()
    # front wall
    poles(wx0, wx1, wtop, fl, wtop, fl, int((wx1-wx0)/(10*s)), 0)
    c.rectangle(wx0, fl-6*s, wx1-wx0, 6*s); c.set_source_rgba(*C('#8a6a38')); c.fill()
    c.move_to(wx0, wtop+30*s); c.line_to(wx1, wtop+30*s); c.move_to(wx0, fl-26*s); c.line_to(wx1, fl-26*s)
    c.set_source_rgba(*C('#a07a40')); c.set_line_width(5*s); c.stroke()
    # door + windows: dark openings in bamboo frames
    dx0, dy0 = x-W*.06, floor-Hh*.68
    c.rectangle(dx0-5*s, dy0-5*s, 56*s, fl-dy0+5*s); c.set_source_rgba(*C('#9a7438')); c.fill()
    c.rectangle(dx0, dy0, 46*s, fl-dy0); c.set_source_rgba(*C('#3a2616')); c.fill()
    g.rectangle(dx0, dy0, 46*s, fl-dy0); g.set_source_rgba(1, 1, 1, 1); g.fill()
    for wxx in (x-W*.32, x+W*.2):
        wy = floor-Hh*.62
        c.rectangle(wxx-5*s, wy-5*s, 54*s, 42*s); c.set_source_rgba(*C('#9a7438')); c.fill()
        c.rectangle(wxx, wy, 44*s, 32*s); c.set_source_rgba(*C('#3a2616')); c.fill()
        g.rectangle(wxx, wy, 44*s, 32*s); g.set_source_rgba(1, 1, 1, .9); g.fill()
        for q in range(4):
            c.move_to(wxx+8*s+q*9.5*s, wy); c.line_to(wxx+8*s+q*9.5*s, wy+32*s)
        c.set_source_rgba(*C('#d8b46a')); c.set_line_width(3.4*s); c.stroke()
    # bóng mái hắt xuống vách (vẽ trước mái để không đè lên tua tranh)
    gsh = cairo.LinearGradient(0, wtop, 0, wtop+26*s); gsh.add_color_stop_rgba(0, .12, .07, .02, .42); gsh.add_color_stop_rgba(1, .12, .07, .02, 0)
    c.rectangle(wx0, wtop, wx1-wx0, 26*s); c.set_source(gsh); c.fill()
    # roof: back slope, front slope, thatch strands, ragged eave, ridge roll
    ov = 34*s; eL, eR = (wx0-ov, wtop+14*s), (wx1+ov*.35, wtop+14*s)
    bR = (wx1+ox+ov*.35, wtop+oy+14*s)
    c.move_to(*rR); c.line_to(*bR); c.line_to(eR[0], eR[1]); c.close_path()
    c.set_source_rgba(*C('#9a7a3a')); c.fill()
    def front_slope():
        c.move_to(*eL); c.line_to(*rL); c.line_to(*rR); c.line_to(*eR)
        # ragged straw fringe along the eave
        n = int((eR[0]-eL[0])/(9*s))
        for i in range(n, -1, -1):
            px = eL[0]+(eR[0]-eL[0])*i/n
            c.line_to(px, eL[1]+(R.uniform(3, 9) if i % 2 else 0)*s)
        c.close_path()
    front_slope()
    gr = cairo.LinearGradient(0, rL[1], 0, eL[1]+8*s)
    gr.add_color_stop_rgba(0, *C('#f2d88a')); gr.add_color_stop_rgba(.55, *C('#d8b062')); gr.add_color_stop_rgba(1, *C('#a8823e'))
    c.set_source(gr); c.fill()
    front_slope(); c.save(); c.clip()
    for row in range(9):
        t = row/9
        y0 = rL[1]+(eL[1]-rL[1])*t
        xl = rL[0]+(eL[0]-rL[0])*t; xr = rR[0]+(eR[0]-rR[0])*t
        q = xl
        while q < xr:
            L = R.uniform(10, 18)*s
            c.move_to(q, y0); c.line_to(q-(rL[0]-eL[0])/(eL[1]-rL[1])*L, y0+L)
            q += R.uniform(3, 6)*s
        c.set_source_rgba(*C('#8a6428', 0, .45)); c.set_line_width(1.2*s); c.stroke()
        c.move_to(xl, y0+1); c.line_to(xr, y0+1); c.set_source_rgba(1, .95, .75, .22); c.set_line_width(2*s); c.stroke()
    r2 = rr(x, y, s)
    sl = (rL[0]-eL[0])/(eL[1]-rL[1])
    for row in range(9):
        t = row/9; y0 = rL[1]+(eL[1]-rL[1])*t; y1 = rL[1]+(eL[1]-rL[1])*(row+1)/9
        xl = rL[0]+(eL[0]-rL[0])*t; xr = rR[0]+(eR[0]-rR[0])*t
        # bóng dưới mép mỗi lớp tranh
        c.rectangle(xl-40*s, y1-3.5*s, xr-xl+80*s, 3.5*s); c.set_source_rgba(.35, .22, .08, .18); c.fill()
        for pas, cols, wl in ((0, ('#6e4c1c', '#8a6428', '#7a5420'), .5), (1, ('#f6e2a0', '#e8c878', '#fff0c0'), .4)):
            q = xl
            while q < xr:
                L = r2.uniform(8, 16)*s; yy = y0+r2.uniform(-1, 4)*s
                c.move_to(q, yy); c.line_to(q-sl*L+r2.uniform(-1, 1)*s, yy+L)
                c.set_source_rgba(*C(r2.choice(cols), 0, .36 if pas == 0 else .36)); c.set_line_width(wl*s); c.stroke()
                q += r2.uniform(.9, 2.2)*s
    c.restore()
    c.move_to(*rL); c.line_to(*rR); c.set_source_rgba(*C('#8a6428')); c.set_line_width(9*s); c.stroke()
    c.move_to(rL[0], rL[1]-2*s); c.line_to(rR[0], rR[1]-2*s); c.set_source_rgba(*C('#c8a056')); c.set_line_width(3*s); c.stroke()
    # hammock under the eave (võng)
    hx0, hx1 = x-W*.62+8*s, x-W*.45
    # porch posts
    for px in (x-W*.6, x+W*.6):
        c.move_to(px, wtop+12*s); c.line_to(px, floor); c.set_source_rgba(*C('#6a4a30')); c.set_line_width(5*s); c.stroke()
    # bến: deck + steps + xuồng ba lá tied
    px0 = x+W*.45
    c.rectangle(px0, floor-4*s, 110*s, 8*s); c.set_source_rgba(*C('#8a6440')); c.fill()
    for i in range(3):
        c.move_to(px0+20*s+i*40*s, floor); c.line_to(px0+20*s+i*40*s, y+6); c.set_source_rgba(*C('#6a4a30')); c.set_line_width(5*s); c.stroke()
    for i in range(4):
        c.rectangle(px0+80*s+i*10*s, floor+i*14*s, 34*s, 5*s); c.set_source_rgba(*C('#8a6440')); c.fill()
    xuong(c, px0+40*s, y+2, 1.0*s)
    # lantern on the dock
    c.move_to(px0+100*s, floor); c.line_to(px0+100*s, floor-70*s); c.set_source_rgba(*C('#4a3020')); c.set_line_width(4*s); c.stroke()
    c.rectangle(px0+92*s, floor-84*s, 16*s, 18*s); c.set_source_rgba(*C('#f0c860')); c.fill()
    g.arc(px0+100*s, floor-75*s, 12*s, 0, 6.3); g.set_source_rgba(1, 1, 1, 1); g.fill()
    # clothesline with áo bà ba, water jars
    lx0, lx1, ly = x-W*.95, x-W*.6, floor-70*s
    c.move_to(lx0, floor); c.line_to(lx0, ly-6*s); c.set_source_rgba(*C('#6a4a30')); c.set_line_width(4*s); c.stroke()
    c.move_to(lx0, ly); c.curve_to(lx0+30*s, ly+8*s, lx1-30*s, ly+8*s, lx1, ly); c.set_source_rgba(*C('#5a4a3a')); c.set_line_width(1.5*s); c.stroke()
    for i, col in enumerate(['#8a4ab8', '#e8e4d8', '#d8402a', '#3a6ab8']):
        cx = lx0+16*s+i*22*s
        c.move_to(cx-9*s, ly+4*s); c.line_to(cx+9*s, ly+4*s); c.line_to(cx+8*s, ly+30*s); c.line_to(cx-8*s, ly+30*s); c.close_path()
        c.set_source_rgba(*C(col)); c.fill()
        c.move_to(cx-9*s, ly+4*s); c.line_to(cx-15*s, ly+14*s); c.line_to(cx-9*s, ly+16*s); c.close_path(); c.fill()
        c.move_to(cx+9*s, ly+4*s); c.line_to(cx+15*s, ly+14*s); c.line_to(cx+9*s, ly+16*s); c.close_path(); c.fill()
    for i, jx in enumerate((x-W*.5-14*s, x-W*.5-50*s)):
        c.save(); c.translate(jx, floor-20*s); c.scale(1, 1.15); c.arc(0, 0, 18*s, 0, 6.3); c.restore()
        c.set_source(vgrad_px(floor-42*s, floor, [(0, C('#a85a2a')), (1, C('#6a3018'))])); c.fill()
        c.save(); c.translate(jx, floor-40*s); c.scale(1, .3); c.arc(0, 0, 10*s, 0, 6.3); c.restore()
        c.set_source_rgba(*C('#4a2010')); c.fill()
        c.arc(jx-6*s, floor-28*s, 4*s, 0, 6.3); c.set_source_rgba(1, .9, .8, .35); c.fill()
    return floor

def nha_ngoi(c, g, R, x, y, s=1.0):
    """yellow-walled house with red tile roof and green doors, on the bank"""
    W, H = 280*s, 110*s
    base = y-24*s
    c.rectangle(x-W/2, base-H, W, H); c.set_source(vgrad_px(base-H, base, [(0, C('#f2d27a')), (1, C('#e0b45a'))])); c.fill()
    c.rectangle(x-W/2, base-8*s, W, 8*s); c.set_source_rgba(*C('#b8905a')); c.fill()
    # pillars + porch shadow
    c.rectangle(x-W/2, base-H, W, 14*s); c.set_source_rgba(0, 0, 0, .15); c.fill()
    for px in (x-W*.32, x, x+W*.32):
        c.rectangle(px-30*s if px == x else px-20*s, base-H*.72, 60*s if px == x else 40*s, H*.64)
        c.set_source_rgba(*C('#2e8a5a')); c.fill()
        c.rectangle(px-26*s if px == x else px-16*s, base-H*.68, 52*s if px == x else 32*s, H*.56)
        c.set_source_rgba(*C('#3a2616')); c.fill()
        g.rectangle(px-26*s if px == x else px-16*s, base-H*.68, 52*s if px == x else 32*s, H*.56); g.set_source_rgba(1, 1, 1, .9); g.fill()
        c.move_to(px, base-H*.72); c.line_to(px, base-H*.08); c.set_source_rgba(*C('#3a9a6a')); c.set_line_width(3*s); c.stroke()
    # roof tiles
    rt = base-H-70*s
    c.move_to(x-W*.6, base-H+8*s); c.line_to(x-W*.4, rt); c.line_to(x+W*.4, rt); c.line_to(x+W*.6, base-H+8*s); c.close_path()
    c.set_source(vgrad_px(rt, base-H, [(0, C('#c8502e')), (1, C('#a83a22'))])); c.fill()
    for j in range(6):
        t = j/6; yy = rt+(base-H+8*s-rt)*t; xl = x-W*.4-W*.2*t; xr = x+W*.4+W*.2*t
        c.move_to(xl, yy); c.line_to(xr, yy)
    c.set_source_rgba(*C('#7a2a14', .5)); c.set_line_width(2*s); c.stroke()
    for i in range(int(W*1.1/(9*s))):
        px = x-W*.55+i*9*s
        c.move_to(px, rt+2*s); c.line_to(px+(px-x)*.25, base-H+6*s)
    c.set_source_rgba(*C('#e87a50', .35)); c.set_line_width(1.6*s); c.stroke()
    c.move_to(x-W*.4, rt); c.line_to(x+W*.4, rt); c.set_source_rgba(*C('#8a2a14')); c.set_line_width(7*s); c.stroke()
    # little front yard steps
    for i in range(3):
        c.rectangle(x-40*s+i*4*s, base+i*7*s, 80*s-i*8*s, 7*s); c.set_source_rgba(*C('#c8b090')); c.fill()

def xuong(c, x, y, s=1.0, col='#3a8a5a'):
    """xuồng ba lá: green hull, red trim, painted eye"""
    c.move_to(x-60*s, y-16*s); c.curve_to(x-40*s, y+2*s, x+40*s, y+2*s, x+66*s, y-20*s)
    c.line_to(x+52*s, y-12*s); c.curve_to(x+20*s, y-8*s, x-30*s, y-8*s, x-50*s, y-12*s); c.close_path()
    c.set_source_rgba(*C(col)); c.fill()
    c.move_to(x-60*s, y-16*s); c.curve_to(x-30*s, y-9*s, x+30*s, y-9*s, x+66*s, y-20*s)
    c.set_source_rgba(*C('#d84a2a')); c.set_line_width(3*s); c.stroke()
    c.arc(x+48*s, y-10*s, 3.2*s, 0, 6.3); c.set_source_rgba(1, 1, 1, 1); c.fill()
    c.arc(x+49*s, y-10*s, 1.6*s, 0, 6.3); c.set_source_rgba(0, 0, 0, 1); c.fill()

def rach_and_bridge(c, R, x0, x1):
    """a side creek (rạch) opening into the canal, crossed by a monkey bridge"""
    mid = (x0+x1)/2
    # water of the creek receding into the garden
    c.move_to(x0, WL+2); c.curve_to(x0+60, WL-20, mid-60, WL-36, mid-30, WL-40)
    c.line_to(mid+30, WL-40); c.curve_to(mid+60, WL-36, x1-60, WL-20, x1, WL+2); c.close_path()
    c.set_source(vgrad_px(WL-40, WL, [(0, C('#9ad8d0')), (1, C('#4aa8a0'))])); c.fill()
    for i in range(6):
        yy = WL-34+i*6
        c.move_to(mid-40-i*30, yy); c.line_to(mid+40+i*30, yy)
    c.set_source_rgba(1, 1, 1, .25); c.set_line_width(1.2); c.stroke()
    # bridge
    span = x1-x0; n = 7
    deck = [(x0+span*i/n, WL-6-(30+110*math.sin(i/n*math.pi))) for i in range(n+1)]
    for i, (dx, dy) in enumerate(deck):
        if 0 < i < n:
            for sg in (-1, 1):
                c.move_to(dx-sg*22, WL+4); c.line_to(dx+sg*14, dy-16)
            c.set_source_rgba(*C('#8a7040')); c.set_line_width(4.5); c.stroke()
    c.move_to(*deck[0])
    for p in deck[1:]: c.line_to(*p)
    c.set_source_rgba(*C('#c8a860')); c.set_line_width(6); c.stroke()
    rail = [(p[0], p[1]-46) for p in deck[1:-1]]
    c.move_to(deck[0][0]+span*.04, deck[0][1]-30)
    for p in rail: c.line_to(*p)
    c.line_to(deck[-1][0]-span*.04, deck[-1][1]-30)
    c.set_source_rgba(*C('#c8a860')); c.set_line_width(3.4); c.stroke()
    for p in rail: c.move_to(*p); c.line_to(p[0]+4, p[1]+50)
    c.set_source_rgba(*C('#8a7040')); c.set_line_width(2.6); c.stroke()
    # a kid in white áo bà ba with a nón lá, walking across holding the rail
    p = deck[2]; q = deck[3]; t = .55
    fx, fy = p[0]+(q[0]-p[0])*t, p[1]+(q[1]-p[1])*t
    c.set_line_cap(cairo.LINE_CAP_ROUND)
    c.move_to(fx-5, fy-1); c.line_to(fx-2, fy-20); c.move_to(fx+7, fy-3); c.line_to(fx+3, fy-20)
    c.set_source_rgba(*C('#24345e')); c.set_line_width(5); c.stroke()
    c.move_to(fx-9, fy-18); c.curve_to(fx-11, fy-30, fx-9, fy-40, fx-4, fy-44); c.line_to(fx+6, fy-44)
    c.curve_to(fx+10, fy-40, fx+11, fy-30, fx+9, fy-18); c.close_path()
    c.set_source_rgba(*C('#f6f2e6')); c.fill_preserve(); c.set_source_rgba(*C('#c8c0aa')); c.set_line_width(1.2); c.stroke()
    c.move_to(fx+7, fy-40); c.line_to(fx+16, fy-50)
    c.set_source_rgba(*C('#c8905a')); c.set_line_width(3.4); c.stroke()
    c.arc(fx+1, fy-50, 6.5, 0, 6.3); c.set_source_rgba(*C('#c8905a')); c.fill()
    c.move_to(fx-17, fy-52); c.line_to(fx+1, fy-68); c.line_to(fx+19, fy-52); c.curve_to(fx+8, fy-49, fx-6, fy-49, fx-17, fy-52)
    c.set_source_rgba(*C('#f2dca0')); c.fill_preserve(); c.set_source_rgba(*C('#b89a58')); c.set_line_width(1.2); c.stroke()
    c.set_line_cap(cairo.LINE_CAP_BUTT)

# ---------- composition ----------
CREEK = (1440, 1900)
def ground(x):
    """height of the bank top (grass line) along the canal: gently rolling, lower where the main house sits on the water"""
    g = WL-50-14*math.sin(x/640+1.3)-7*math.sin(x/233+.4)
    g += 16*math.exp(-((x-2650)/260)**2)          # bank drops where the stilt house stands over the water
    return g

def nipa_clump(c, R, x, y, s=1.0):
    """dừa nước: long stiff feather fronds springing straight from the water, arching only at the tips"""
    pal = [('#8cc444', '#4e9030', '#2a6428'), ('#78b03c', '#3e7e2c', '#245a24')]
    n = R.randint(6, 8)
    angs = sorted([R.uniform(-.7, .7) for _ in range(n)], key=lambda a: -abs(a))
    for i, a in enumerate(angs):
        coco_frond(c, R, (x+R.uniform(-12, 12)*s, y), a, R.uniform(210, 290)*s*(1-.12*abs(a)), 0, 0,
                   stiff=.14, lf=.19, hang=-.04, pal=pal[1 if abs(a) > .5 else 0], erect=True)

def stakes(c, R, x, n, s=1.0):
    """a row of weathered bamboo stakes in the water (cọc), tops at uneven heights"""
    for i in range(n):
        px = x+i*R.uniform(16, 26)*s; h = R.uniform(30, 70)*s
        c.move_to(px, WL+8); c.line_to(px+R.uniform(-3, 3), WL-h)
        c.set_source_rgba(*C('#5a4630')); c.set_line_width(6*s); c.stroke()
        c.move_to(px-1.5*s, WL+4); c.line_to(px-1.5*s, WL-h+3)
        c.set_source_rgba(*C('#9a8058', 0, .8)); c.set_line_width(1.6*s); c.stroke()

def mud_bank(c, R, x0, x1):
    """the bank itself: grass lip on top, ochre clay slope below, dark wet band at the waterline, hanging grass + roots"""
    xs = list(range(x0, x1+1, 20))
    top = [(x, ground(x)) for x in xs]
    crpath(c, [(x0, WL+6)]+top+[(x1, WL+6)], True)
    c.set_source(vgrad_px(WL-80, WL+4, [(0, C('#c49a62')), (.6, C('#a47a4a')), (.86, C('#7a5a3a')), (1, C('#5a4430'))])); c.fill()
    # wet band + horizontal clay streaks
    crpath(c, [(x0, WL+6)]+[(x, WL-6-3*math.sin(x/90)) for x in xs]+[(x1, WL+6)], True)
    c.set_source_rgba(*C('#4e3c2a')); c.fill()
    for i in range(int((x1-x0)/30)):
        x = R.uniform(x0, x1); y = R.uniform(ground(x)+16, WL-10)
        if y > WL-10: continue
        c.move_to(x, y); c.line_to(x+R.uniform(20, 60), y+R.uniform(-1, 2))
        c.set_source_rgba(*C(R.choice(['#d4ae78', '#8a6440']), 0, .6)); c.set_line_width(R.uniform(1.4, 2.6)); c.stroke()
    # grass lip: lit top, shaded underside, tufts hanging over the clay
    crpath(c, [(x, y-3) for x, y in top]+[(x, y+14+4*math.sin(x/37)) for x, y in reversed(top)], True)
    c.set_source(vgrad_px(WL-90, WL-20, [(0, C('#8ccc4c')), (1, C('#4e9234'))])); c.fill()
    for i in range(int((x1-x0)/14)):
        x = R.uniform(x0, x1); y = ground(x)+R.uniform(6, 12); L = R.uniform(10, 26)
        leaf(c, (x, y), (x+R.uniform(-8, 8), y+L), 3.2, R.uniform(-.3, .3))
        c.set_source_rgba(*C(R.choice(['#4e9234', '#3e7e2e', '#5ea23c']))); c.fill()
    for i in range(int((x1-x0)/6)):
        x = R.uniform(x0, x1); y = ground(x)+R.uniform(-1, 4); L = R.uniform(8, 18)
        leaf(c, (x, y), (x+R.uniform(-6, 6), y-L), 2.4, R.uniform(-.2, .2))
        c.set_source_rgba(*C(R.choice(['#9ad858', '#7cbc46', '#b4e06a']))); c.fill()
    r2 = rr(x0, x1, 7)
    for i in range(int((x1-x0)/1.6)):
        x = r2.uniform(x0, x1); y = ground(x)+r2.uniform(-2, 6); L = r2.uniform(6, 15)
        leaf(c, (x, y), (x+r2.uniform(-5, 5), y-L), 1.3, r2.uniform(-.25, .25))
        c.set_source_rgba(*C(r2.choice(['#a8e060', '#86c84a', '#6aae3c', '#c0e878', '#4e9234']))); c.fill()
    for i in range(int((x1-x0)/5)):
        x = r2.uniform(x0, x1); y = r2.uniform(ground(x)+18, WL-8)
        c.move_to(x, y); c.line_to(x+r2.uniform(6, 22), y+r2.uniform(-.5, 1))
        c.set_source_rgba(*C(r2.choice(['#d8b27c', '#7e5c3c', '#b08858']), 0, .35)); c.set_line_width(r2.uniform(.5, 1.1)); c.stroke()
    # roots poking out of the clay under the big trees
    for rx in (2330, 3020, 3150, 640, 3700, 4980):
        if not (x0 < rx < x1): continue
        for j in range(R.randint(3, 5)):
            y0 = ground(rx)+14; ex = rx+R.uniform(-40, 40); ey = WL-R.uniform(4, 16)
            c.move_to(rx+R.uniform(-8, 8), y0); c.curve_to(rx+R.uniform(-20, 20), y0+14, ex, ey-14, ex, ey)
            c.set_source_rgba(*C('#5e4632')); c.set_line_width(R.uniform(2, 4)); c.stroke()

def build_bank():
    R = random.Random(21)
    layers = []
    # 1. FAR: low continuous tree line across the canal bend, palm crowns poking up in loose groups (strong haze)
    s, c = new()
    pts = [(-20, WL)]
    for x in range(-20, BW+40, 30):
        pts.append((x, WL-120-26*math.sin(x/310)-18*math.sin(x/97+2)-R.uniform(0, 14)))
    pts.append((BW+40, WL)); crpath(c, pts, True)
    c.set_source(vgrad_px(WL-190, WL-40, [(0, C('#8cc86a')), (1, C('#4e8a4a'))])); c.fill()
    for i in range(90):
        x = R.uniform(0, BW)
        leafy_clump(c, R, x, WL-130-R.uniform(0, 30), R.uniform(36, 60), R.uniform(24, 36), 20, '#a8d878', '#6aa856', '#3e7a4e', 0, (8, 14))
    for g0 in (300, 1300, 1750, 2900, 4300, 5150):
        for j in range(R.randint(2, 4)):
            coconut(c, R, g0+R.uniform(-110, 110), WL-110, R.uniform(150, 230), R.uniform(-.3, .3), .5, 0)
    layers.append((s, True, .32))
    # 2. MID: coconut groves in clusters of mixed height, fruit trees between; sky shows in the gaps
    s, c = new()
    for x, h, w, fr in ((1150, 250, 260, 'xoai'), (2050, 230, 240, 'chom'), (3420, 260, 280, 'xoai'), (4520, 240, 260, None), (230, 230, 240, 'chom')):
        fruit_tree(c, R, x, ground(x)+4, h, w, fr, 1.0, .03)
    for cx, n, spread in ((600, 5, 220), (2230, 4, 160), (3750, 4, 200), (4980, 5, 230)):
        for j in range(n):
            x = cx+R.uniform(-spread, spread)
            coconut(c, R, x, ground(x)+2, R.uniform(330, 560), R.uniform(-.35, .35)+(x-cx)/spread*.15, .85, .04)
    layers.append((s, True, .1))
    # 3. GARDEN behind the houses: bananas, hibiscus, điên điển, low shrubs hiding tree bases
    s, c = new()
    for x in (420, 980, 2140, 2420, 3330, 3880, 4700, 5250):
        banana(c, R, x+R.uniform(-30, 30), ground(x)+6, R.uniform(.85, 1.05), 0)
    for x in (760, 2950, 4060):
        hibiscus(c, R, x, ground(x)+4, R.uniform(110, 150))
    for x in range(0, BW, 70):
        if CREEK[0]-40 < x < CREEK[1]+40 or R.random() < .35: continue
        leafy_clump(c, R, x, ground(x)-16, R.uniform(40, 60), 22, 20, '#a4d460', '#5ea23c', '#2e6a36', 0, (7, 11))
    layers.append((s, True, 0))
    # 4. BANK + BUILDINGS: houses set back (smaller = further), the clay bank, creek + monkey bridge, main stilt house on the water
    s, c = new(); sg, g = new()
    nha_la(c, g, R, 4250, ground(4250)+6, .74)
    nha_la(c, g, R, 860, ground(860)+6, .66)
    mud_bank(c, R, -20, BW+20)
    rach_and_bridge(c, R, *CREEK)
    for ex, d in ((CREEK[0], 1), (CREEK[1], -1)):          # clay corners where the creek cuts the bank
        c.move_to(ex-d*30, ground(ex)+8); c.curve_to(ex, ground(ex)+10, ex+d*24, WL-14, ex+d*50, WL+2); c.line_to(ex-d*30, WL+2); c.close_path()
        c.set_source_rgba(*C('#9a7044')); c.fill()
    nha_la(c, g, R, 2650, WL+10, 1.15)
    stakes(c, R, 3190, 5, 1.0); stakes(c, R, 1180, 3, .9); stakes(c, R, 4560, 4, .9)
    # miếu (shrine) post on the bank
    sx = 3560; sy = ground(sx)+4
    c.move_to(sx, sy); c.line_to(sx, sy-74); c.set_source_rgba(*C('#7a5434')); c.set_line_width(5); c.stroke()
    c.rectangle(sx-16, sy-98, 32, 24); c.set_source_rgba(*C('#d8402a')); c.fill()
    c.move_to(sx-24, sy-96); c.line_to(sx, sy-114); c.line_to(sx+24, sy-96); c.close_path(); c.set_source_rgba(*C('#a82a1a')); c.fill()
    g.arc(sx, sy-86, 8, 0, 6.3); g.set_source_rgba(1, 1, 1, .9); g.fill()
    layers.append((s, False, 0))
    # 5. FRONT: two hero palms leaning out over the canal beside the main house, dừa nước standing in the water, điên điển, lục bình
    s, c = new()
    coconut(c, R, 3020, ground(3020)+6, 640, .82, 1.1, 0)
    coconut(c, R, 3150, ground(3150)+6, 520, .45, 1.0, 0)
    coconut(c, R, 2330, ground(2330)+6, 600, -.72, 1.05, 0)
    for x0, x1, step in ((-40, 420, 120), (1080, 1430, 110), (1910, 2160, 120), (4620, 5100, 120), (5250, BW+60, 120)):
        x = x0
        while x < x1:
            nipa_clump(c, R, x, WL+4, R.uniform(.8, 1.05)); x += step*R.uniform(.8, 1.2)
    dien_dien(c, R, 3480, ground(3480)+8, 1.05); dien_dien(c, R, 4420, ground(4420)+8, .95); dien_dien(c, R, 520, ground(520)+8, .9)
    for x0 in (180, 1300, 2020, 3260, 4760, 5300):
        for j in range(R.randint(2, 4)):
            hyacinth(c, R, x0+j*R.uniform(24, 40), WL+R.uniform(0, 6), R.uniform(.7, .95), R.random() < .35, 0)
    layers.append((s, True, 0))

    col = np.zeros((BH, BW, 3), np.float32); al = np.zeros((BH, BW), np.float32); sway = np.zeros((BH, BW), np.float32)
    haze = np.array([.74, .86, .92], np.float32)
    for surf, fol, hz in layers:
        a = to_np(surf); pa = a[..., 3]; prgb = a[..., [2, 1, 0]]
        if hz < .2:   # cartoon sticker outline around near layers
            dil = np.asarray(Image.fromarray((pa*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))).astype(np.float32)/255
            ring = np.clip(dil-pa, 0, 1)*.5
            oc = np.array([.12, .26, .16], np.float32)
            prgb = prgb+oc[None, None, :]*ring[..., None]; pa = pa+ring
        if hz: prgb = prgb*(1-hz)+haze[None, None, :]*pa[..., None]*hz
        col = col*(1-pa[..., None])+prgb; al = al*(1-pa)+pa; sway = sway*(1-pa)+pa*(1.0 if fol else 0.0)
    rgb = col/np.maximum(al[..., None], 1e-4)
    Image.fromarray((np.concatenate([rgb, al[..., None]], -1).clip(0, 1)*255).astype(np.uint8), 'RGBA').save(f'{OUT}/bank.png')
    glow = to_np(sg)[..., 3]
    glow = np.asarray(Image.fromarray((glow*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))).astype(np.float32)/255
    aux = np.stack([glow, sway, np.zeros_like(glow), np.ones_like(glow)], -1)
    Image.fromarray((aux*255).astype(np.uint8), 'RGBA').resize((BW//2, BH//2), Image.BILINEAR).save(f'{OUT}/bank_aux.png')

FW, FH = 2800, 420
def build_fg():
    """cartoon near bank: flat mound, outlined grass tufts, big simple flowers, a few cỏ lau plumes"""
    R = random.Random(5)
    s, c = new(FW, FH)
    OL = C('#1f4a2a')
    def ink(w):
        c.set_source_rgba(*OL); c.set_line_width(w); c.stroke()
    top = []
    for i in range(41):
        x = FW*i/40; t = abs(x-FW*.5)/(FW*.5)
        top.append((x, FH-62-170*t**1.6+3*math.sin(i*1.3)))
    # mound: darker body, a lighter sunlit lip along the top, ink outline
    crpath(c, [(-10, FH+10)]+top+[(FW+10, FH+10)], True)
    gm = cairo.LinearGradient(0, FH-240, 0, FH); gm.add_color_stop_rgba(0, *C('#5aa83a')); gm.add_color_stop_rgba(1, *C('#2e6e28'))
    c.set_source(gm); c.fill()
    crpath(c, [(-10, FH+10)]+[(x, y+4) for x, y in top]+[(FW+10, FH+10)], True)
    c.save(); c.clip()
    crpath(c, [(x, y-2) for x, y in top]+[(x, y+22+30*abs(x-FW*.5)/(FW*.5)) for x, y in reversed(top)], True)
    c.set_source_rgba(*C('#7cc444')); c.fill()
    c.restore()
    crpath(c, [(-10, FH+10)]+top+[(FW+10, FH+10)], True); ink(2.4)
    # soft rounded grass clumps sitting on the lip only (clean silhouette)
    def clump(x, y, sc):
        blades = R.randint(5, 7)
        for j in range(blades):
            a = -.9+1.8*j/(blades-1)+R.uniform(-.08, .08); L = (26+18*math.cos(a))*sc
            tip = (x+math.sin(a)*L*1.1, y-math.cos(a)*L)
            wd = 11*sc
            c.move_to(x-wd*.5, y+2); c.curve_to(x-wd*.6+math.sin(a)*L*.4, y-L*.55, tip[0]-math.cos(a)*wd*.4, tip[1]+wd*.2, *tip)
            c.curve_to(tip[0]+math.cos(a)*wd*.5, tip[1]+wd*.5, x+wd*.6+math.sin(a)*L*.4, y-L*.45, x+wd*.5, y+2); c.close_path()
            gb = cairo.LinearGradient(x, y+2, tip[0], tip[1]); lt = '#9ad856' if j % 2 else '#80c446'
            gb.add_color_stop_rgba(0, *C('#3e8a2c')); gb.add_color_stop_rgba(.55, *C(lt)); gb.add_color_stop_rgba(1, *C(mix_hex(lt, '#f0ffc0', .35)))
            c.set_source(gb); c.fill_preserve(); ink(1.3)
    xs = []
    x = R.uniform(0, 60)
    while x < FW:
        xs.append(x)
        if R.random() < .4: xs.append(x+R.uniform(18, 34))
        x += R.uniform(70, 190)
    for x in xs:
        i = min(40, int(x/FW*40)); y = top[i][1]+(top[min(40, i+1)][1]-top[i][1])*((x/FW*40) % 1)
        t = abs(x-FW*.5)/(FW*.5)
        clump(x, y+8, (1.5+1.1*t)*R.uniform(.8, 1.15))
    # lá môn (taro) at both ends: big heart leaves on long stalks
    def lamon(x, y, h, a, sc):
        tip = (x+math.sin(a)*h, y-math.cos(a)*h)
        c.move_to(x, y); c.curve_to(x, y-h*.5, tip[0]-math.sin(a)*30, tip[1]+40, *tip)
        c.set_source_rgba(*OL); c.set_line_width(7*sc); c.stroke_preserve(); c.set_source_rgba(*C('#9ccc5a')); c.set_line_width(5*sc); c.stroke()
        W2, H2 = 70*sc, 86*sc
        c.save(); c.translate(*tip); c.rotate(a*.6+(.5 if a > 0 else -.5))
        c.move_to(0, -H2*.15); c.curve_to(-W2*.4, -H2*.55, -W2*1.05, -H2*.2, -W2*.8, H2*.25)
        c.curve_to(-W2*.55, H2*.62, -W2*.15, H2*.8, 0, H2); c.curve_to(W2*.15, H2*.8, W2*.55, H2*.62, W2*.8, H2*.25)
        c.curve_to(W2*1.05, -H2*.2, W2*.4, -H2*.55, 0, -H2*.15); c.close_path()
        c.set_source_rgba(*C('#4e9a34')); c.fill_preserve(); c.restore(); ink(1.6)
        c.save(); c.translate(*tip); c.rotate(a*.6+(.5 if a > 0 else -.5))
        c.move_to(0, 0); c.curve_to(-W2*.35, -H2*.3, -W2*.8, -H2*.05, -W2*.72, H2*.22)
        c.curve_to(-W2*.5, H2*.55, -W2*.15, H2*.72, 0, H2*.92); c.close_path()
        c.set_source_rgba(*C('#7cc04a')); c.fill()
        c.move_to(0, 0); c.line_to(0, H2*.9)
        for v in (-1, 1):
            c.move_to(0, H2*.05); c.line_to(v*W2*.6, H2*.05); c.move_to(0, H2*.35); c.line_to(v*W2*.55, H2*.45); c.move_to(0, H2*.6); c.line_to(v*W2*.3, H2*.75)
        c.set_source_rgba(*C('#d8f0a0')); c.set_line_width(2.2); c.stroke()
        c.restore()
    for (x, h, a) in ((150, 230, -.25), (250, 180, .2), (60, 160, -.5)):
        lamon(x, FH, h, a, 1.0)
    for (x, h, a) in ((FW-170, 220, .25), (FW-270, 170, -.2), (FW-70, 150, .5)):
        lamon(x, FH, h, a, 1.0)
    # flower clusters on the mound
    for i in range(14):
        x = R.uniform(60, FW-60); t = abs(x-FW*.5)/(FW*.5)
        y = FH-30-150*t**1.6+R.uniform(10, 40+100*t)
        if y > FH-10: continue
        col = R.choice(['#ffffff', '#ffd83a', '#f8a0c8'])
        for q in range(3):
            fx, fy = x+R.uniform(-16, 16), y+R.uniform(-8, 8)
            for p in range(5):
                c.save(); c.translate(fx, fy); c.rotate(p*1.256); c.scale(1, .7); c.arc(7, 0, 6, 0, 6.3); c.restore()
            c.set_source_rgba(*C(col)); c.fill_preserve(); ink(1.1)
            c.arc(fx, fy, 3.4, 0, 6.3); c.set_source_rgba(*C('#f0a020')); c.fill()
    for side in (0, 1):
        for i in range(7):
            x = R.uniform(30, 300) if side == 0 else R.uniform(FW-300, FW-30)
            y = FH-10; h = R.uniform(200, 290)
            a = R.uniform(-.2, .2)+(.15 if side == 0 else -.15)
            tip = (x+math.sin(a)*h, y-h)
            c.move_to(x, y); c.curve_to(x, y-h*.5, tip[0]-math.sin(a)*20, tip[1]+50, tip[0], tip[1]+40)
            c.set_source_rgba(*OL); c.set_line_width(4.6); c.stroke_preserve()
            c.set_source_rgba(*C('#b8c468')); c.set_line_width(3); c.stroke()
            d = 1 if a > 0 else -1
            for fa in (-.5, .05, .55):
                c.save(); c.translate(tip[0], tip[1]+40); c.rotate(d*(.35+fa*.6)+fa*.4)
                c.move_to(0, 0); c.curve_to(-11, -18, -8, -46, 2, -62); c.curve_to(12, -44, 12, -18, 0, 0); c.close_path()
                c.restore(); c.set_source_rgba(*C('#fbf4e4')); c.fill_preserve(); ink(1.2)
                c.save(); c.translate(tip[0], tip[1]+40); c.rotate(d*(.35+fa*.6)+fa*.4)
                for q in range(4):
                    yy = -12-q*11; c.move_to(1, yy); c.line_to(-5, yy+6); c.move_to(1, yy); c.line_to(7, yy+6)
                c.restore(); c.set_source_rgba(*C('#d8ccb0')); c.set_line_width(1.4); c.stroke()
    s.write_to_png(f'{OUT}/fg.png')

if __name__ == '__main__':
    import sys
    w = sys.argv[1:] or ['bank', 'fg']
    if 'bank' in w: build_bank()
    if 'fg' in w: build_fg()
    print('done')
