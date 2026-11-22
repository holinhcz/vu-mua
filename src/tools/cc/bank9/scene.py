# Far bank of the canal (Southern Vietnam), foreground bank, floating props.
# Outputs out/bank.png (colour), out/bank_aux.png (R = night glow, G = sway mask), out/fg.png, out/props_*.png
import cairo, math, random, os
import numpy as np
from PIL import Image, ImageFilter
from fishkit import hexc, mix, crpath, crsample, lerp

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
BW, BH = 5400, 900
WL = 872            # waterline y in bank image

def new(w=BW, h=BH):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    c = cairo.Context(s)
    c.set_line_cap(cairo.LINE_CAP_ROUND); c.set_line_join(cairo.LINE_JOIN_ROUND)
    return s, c

def to_np(s):
    s.flush()
    a = np.ndarray((s.get_height(), s.get_width(), 4), np.uint8, s.get_data()).astype(np.float32)/255
    return a  # premultiplied BGRA

def rgba(col, a=1, k=0.0):
    c = hexc(col) if isinstance(col, str) else col
    if k > 0: c = mix(c, (1, 1, 1, 1), k)
    if k < 0: c = mix(c, (0, 0, 0, 1), -k)
    return (c[0], c[1], c[2], a)

def leaf(c, p0, p1, w, bend=0.0):
    dx, dy = p1[0]-p0[0], p1[1]-p0[1]
    d = math.hypot(dx, dy) or 1
    nx, ny = -dy/d, dx/d
    m = ((p0[0]+p1[0])/2+nx*bend*d, (p0[1]+p1[1])/2+ny*bend*d)
    c.move_to(p0[0]+nx*w*.5, p0[1]+ny*w*.5)
    c.curve_to(m[0]+nx*w*.6, m[1]+ny*w*.6, m[0]+nx*w*.3, m[1]+ny*w*.3, *p1)
    c.curve_to(m[0]-nx*w*.3, m[1]-ny*w*.3, m[0]-nx*w*.6, m[1]-ny*w*.6, p0[0]-nx*w*.5, p0[1]-ny*w*.5)
    c.close_path()

def bez(p0, p1, p2, t):
    u = 1-t
    return (u*u*p0[0]+2*u*t*p1[0]+t*t*p2[0], u*u*p0[1]+2*u*t*p1[1]+t*t*p2[1])

def bez_tan(p0, p1, p2, t):
    x = 2*(1-t)*(p1[0]-p0[0])+2*t*(p2[0]-p1[0]); y = 2*(1-t)*(p1[1]-p0[1])+2*t*(p2[1]-p1[1])
    d = math.hypot(x, y) or 1
    return x/d, y/d

# ---------------- plants ----------------

def pinnate_frond(c, R, base, ang, length, droop, leaflen, col_dark, col_light, leafw=4.0, density=1.0, rach='#9a9448', ldroop=.55, shade=0.0):
    """frond whose rachis is a quadratic curve; ang 0 = straight up (radians, + right)"""
    dx, dy = math.sin(ang), -math.cos(ang)
    p0 = base
    p1 = (base[0]+dx*length*.55, base[1]+dy*length*.55)
    side = 1 if dx >= 0 else -1
    p2 = (base[0]+dx*length*.95+side*droop*length*.25, base[1]+dy*length*.75+droop*length*.55)
    n = int(26*density*length/250)+6
    for side_k in (-1, 1):
        for i in range(n):
            t = .12+.88*i/n
            p = bez(p0, p1, p2, t)
            tx, ty = bez_tan(p0, p1, p2, t)
            nx, ny = -ty*side_k, tx*side_k
            L = leaflen*(math.sin(min(1, t*1.15)*math.pi)*.75+.25)*R.uniform(.8, 1.1)
            # leaflets point forward along the rachis and droop down
            ex = p[0]+(tx*.55+nx*.8)*L
            ey = p[1]+(ty*.55+ny*.8)*L+L*ldroop
            k = (t*.8+R.uniform(-.15, .15))
            col = mix(hexc(col_dark), hexc(col_light), max(0, min(1, k)))
            if shade: col = mix(col, (0, 0, 0, 1), shade)
            leaf(c, p, (ex, ey), leafw*R.uniform(.8, 1.2), R.uniform(-.08, .08))
            c.set_source_rgba(*col); c.fill()
    # rachis
    c.move_to(*p0); c.curve_to(*lerp(p0, p1, .66), *lerp(p2, p1, .66), *p2)
    c.set_source_rgba(*rgba(rach, .95, -shade)); c.set_line_width(max(1.2, leafw*.6)); c.stroke()

def nipa(c, R, x, y, s=1.0, shade=0.0):
    """dừa nước: fronds rising straight from the water, fanning out"""
    n = R.randint(9, 13)
    angs = sorted([R.uniform(-.85, .85) for _ in range(n)], key=lambda a: -abs(a))
    for a in angs:
        L = 360*s*R.uniform(.75, 1.15)*(1-.3*abs(a))
        pinnate_frond(c, R, (x+R.uniform(-14, 14)*s, y), a, L, .35+abs(a)*.4, 34*s, '#355a24', '#8cb64a', 3.6*s, 1.0, '#a89a52', .25, shade+(.12 if abs(a) > .7 else 0))

def coconut(c, R, x, y, h, lean, s=1.0, shade=0.0):
    top = (x+lean*h*.35, y-h)
    ctrl = (x+lean*h*.05, y-h*.55)
    # trunk
    n = 40
    for i in range(n):
        t0, t1 = i/n, (i+1)/n
        a0 = bez((x, y), ctrl, top, t0); a1 = bez((x, y), ctrl, top, t1)
        w = (14-6*t0)*s
        c.move_to(*a0); c.line_to(*a1)
        col = mix(hexc('#6a5a46'), hexc('#a8987a'), .4+.4*math.sin(i*1.7))
        col = mix(col, (0, 0, 0, 1), shade)
        c.set_source_rgba(*col); c.set_line_width(w); c.stroke()
    # trunk shading strip
    c.move_to(x+4*s, y); c.curve_to(ctrl[0]+4*s, ctrl[1], ctrl[0]+3*s, ctrl[1], top[0]+2*s, top[1])
    c.set_source_rgba(0, 0, 0, .18); c.set_line_width(5*s); c.stroke()
    # coconuts
    for i in range(5):
        c.arc(top[0]+R.uniform(-12, 12)*s, top[1]+R.uniform(4, 14)*s, 7*s, 0, 6.3)
        c.set_source_rgba(*rgba('#6a7a2a', 1, -shade-.1*i)); c.fill()
    # crown
    m = R.randint(13, 17)
    for i in range(m):
        a = -1.9+3.8*i/(m-1)+R.uniform(-.12, .12)
        back = abs(a) < .6 and R.random() < .5
        L = R.uniform(150, 200)*s
        pinnate_frond(c, R, top, a*1.05, L, .45+abs(a)*.35, 30*s, '#2e4a1c', '#7aa040', 3.0*s, .85, '#8a8a3e', .55, shade+(.15 if back else 0))

def bamboo(c, R, x, y, s=1.0, shade=0.0):
    culms = []
    for i in range(R.randint(9, 13)):
        a = R.uniform(-.45, .45)
        h = R.uniform(320, 470)*s
        bx = x+R.uniform(-20, 20)*s
        tip = (bx+math.sin(a)*h*1.1+a*h*.35, y-math.cos(a)*h)
        ctrl = (bx+math.sin(a)*h*.3, y-h*.6)
        culms.append(((bx, y), ctrl, tip))
        c.move_to(bx, y); c.curve_to(*lerp((bx, y), ctrl, .66), *lerp(tip, ctrl, .66), *tip)
        c.set_source_rgba(*rgba('#7a8a3a', 1, -shade)); c.set_line_width(5*s); c.stroke()
        for k in range(1, 9):
            p = bez((bx, y), ctrl, tip, k/9)
            c.arc(p[0], p[1], 2.4*s, 0, 6.3); c.set_source_rgba(*rgba('#4a5a22', 1, -shade)); c.fill()
    # feathery leaf masses along upper culms
    for (p0, ctrl, tip) in culms:
        for k in range(26):
            t = R.uniform(.35, 1.0)
            p = bez(p0, ctrl, tip, t)
            for j in range(R.randint(4, 7)):
                a = R.uniform(-2.6, 2.6)
                L = R.uniform(18, 30)*s
                e = (p[0]+math.sin(a)*L, p[1]-math.cos(a)*L*.4+L*.5)
                leaf(c, p, e, 3.6*s, R.uniform(-.1, .1))
                col = mix(hexc('#3a5a22'), hexc('#9ac050'), R.uniform(.1, .9)*(t*.7+.3))
                c.set_source_rgba(*mix(col, (0, 0, 0, 1), shade)); c.fill()

def banana(c, R, x, y, s=1.0, shade=0.0):
    for i in range(R.randint(2, 3)):
        bx = x+R.uniform(-24, 24)*s; h = R.uniform(120, 170)*s
        c.move_to(bx, y); c.line_to(bx+R.uniform(-6, 6), y-h)
        c.set_source_rgba(*rgba('#7a8a4a', 1, -shade)); c.set_line_width(13*s); c.stroke()
        for j in range(6):
            a = -1.6+3.2*j/5+R.uniform(-.2, .2)
            L = R.uniform(110, 150)*s
            p0 = (bx, y-h)
            p2 = (bx+math.sin(a)*L, y-h-math.cos(a)*L*.6+L*.35)
            p1 = (bx+math.sin(a)*L*.5, y-h-L*.55)
            # blade
            pts = []
            for k in range(13):
                t = k/12; p = bez(p0, p1, p2, t); tx, ty = bez_tan(p0, p1, p2, t)
                w = math.sin(t*math.pi)**.7*22*s
                pts.append((p[0]-ty*w, p[1]+tx*w))
            for k in range(12, -1, -1):
                t = k/12; p = bez(p0, p1, p2, t); tx, ty = bez_tan(p0, p1, p2, t)
                w = math.sin(t*math.pi)**.7*18*s
                tear = 1 if (k % 3) else .45
                pts.append((p[0]+ty*w*tear, p[1]-tx*w*tear))
            c.move_to(*pts[0])
            for p in pts[1:]: c.line_to(*p)
            c.close_path()
            col = mix(hexc('#4f7e2a'), hexc('#9ac454'), R.uniform(.3, .8))
            c.set_source_rgba(*mix(col, (0, 0, 0, 1), shade)); c.fill()
            c.move_to(*p0); c.curve_to(*lerp(p0, p1, .66), *lerp(p2, p1, .66), *p2)
            c.set_source_rgba(*rgba('#c8d080', .7, -shade)); c.set_line_width(1.6*s); c.stroke()

def canopy_tree(c, R, x, y, h, w, s=1.0, shade=0.0, dark='#2c4a1e', light='#7aa646'):
    # trunk
    c.move_to(x, y); c.curve_to(x-6, y-h*.3, x+8, y-h*.5, x+R.uniform(-10, 10), y-h*.62)
    c.set_source_rgba(*rgba('#4a3a2a', 1, -shade)); c.set_line_width(12*s); c.stroke()
    for i in range(3):
        a = R.uniform(-1, 1)
        c.move_to(x, y-h*.45); c.line_to(x+a*w*.35, y-h*.75)
        c.set_line_width(5*s); c.stroke()
    # leaf clusters: big blobs then dabs
    cy = y-h*.72
    for k in range(260):
        a = R.uniform(0, 2*math.pi); r = math.sqrt(R.random())
        px = x+math.cos(a)*r*w*.5; py = cy+math.sin(a)*r*h*.28
        up = (cy-py)/(h*.28)
        col = mix(hexc(dark), hexc(light), max(0, min(1, .45+up*.45+R.uniform(-.2, .2))))
        c.new_sub_path(); c.arc(px, py, R.uniform(9, 17)*s, 0, 6.3)
        c.set_source_rgba(*mix(col, (0, 0, 0, 1), shade)); c.fill()

# ---------------- structures ----------------

def house(c, g, R, x, y, s=1.0):
    """nhà lá trên cột, mái lá dừa nước, hiên + bến"""
    W, Hh = 300*s, 120*s
    floor = y-60*s
    # stilts
    for i in range(7):
        px = x-W*.48+i*W*.16
        c.move_to(px, floor); c.line_to(px+R.uniform(-3, 3), y+6)
        c.set_source_rgba(*rgba('#4a3828')); c.set_line_width(7*s); c.stroke()
    c.move_to(x-W*.5, floor+16*s); c.line_to(x+W*.5, floor+20*s); c.set_line_width(4*s); c.stroke()
    # floor beam
    c.rectangle(x-W*.52, floor-6*s, W*1.04, 10*s); c.set_source_rgba(*rgba('#5a4430')); c.fill()
    # walls: woven nipa panels
    wx0, wx1, wtop = x-W*.42, x+W*.42, floor-Hh*.78
    c.rectangle(wx0, wtop, wx1-wx0, floor-wtop-6*s)
    c.set_source_rgba(*rgba('#b89a64')); c.fill()
    for i in range(int((wx1-wx0)/(6*s))):
        px = wx0+i*6*s
        c.move_to(px, wtop); c.line_to(px, floor-6*s)
    c.set_source_rgba(*rgba('#8a6e44', .55)); c.set_line_width(1.6*s); c.stroke()
    for j in range(int((floor-wtop)/(26*s))):
        py = wtop+j*26*s
        c.move_to(wx0, py); c.line_to(wx1, py)
    c.set_source_rgba(*rgba('#5a4428', .7)); c.set_line_width(3*s); c.stroke()
    # door + window (dark inside, glow layer)
    dx0, dy0 = x-W*.06, floor-Hh*.66
    c.rectangle(dx0, dy0, 46*s, floor-6*s-dy0); c.set_source_rgba(*rgba('#2a1e14')); c.fill()
    g.rectangle(dx0, dy0, 46*s, floor-6*s-dy0); g.set_source_rgba(1, 1, 1, 1); g.fill()
    for wxx in (x-W*.3, x+W*.2):
        c.rectangle(wxx, floor-Hh*.6, 44*s, 32*s); c.set_source_rgba(*rgba('#2a1e14')); c.fill()
        g.rectangle(wxx, floor-Hh*.6, 44*s, 32*s); g.set_source_rgba(1, 1, 1, .9); g.fill()
        # shutter propped open
        c.move_to(wxx-4*s, floor-Hh*.6-2*s); c.line_to(wxx+48*s, floor-Hh*.6-2*s); c.line_to(wxx+52*s, floor-Hh*.6-26*s); c.line_to(wxx, floor-Hh*.6-26*s); c.close_path()
        c.set_source_rgba(*rgba('#8a6a40')); c.fill()
        for k in range(4):
            c.move_to(wxx+6*s+k*11*s, floor-Hh*.6+2*s); c.line_to(wxx+6*s+k*11*s, floor-Hh*.6+30*s)
        c.set_source_rgba(*rgba('#4a3420')); c.set_line_width(2.5*s); c.stroke()
    # roof: thatch
    rt = wtop-62*s
    pts = [(x-W*.6, wtop+10*s), (x-W*.3, rt), (x+W*.3, rt), (x+W*.6, wtop+10*s)]
    c.move_to(*pts[0])
    for p in pts[1:]: c.line_to(*p)
    c.close_path()
    c.set_source(vgrad_px(rt, wtop+10*s, [(0, rgba('#9a7e4e')), (.6, rgba('#b8995e')), (1, rgba('#7a6038'))])); c.fill()
    # thatch rows
    for j in range(7):
        t = j/7
        yy = rt+(wtop+10*s-rt)*t
        xl = x-W*.3-W*.3*t; xr = x+W*.3+W*.3*t
        k = 0
        while xl+k < xr:
            px = xl+k
            c.move_to(px, yy); c.line_to(px+R.uniform(-2, 2), yy+(wtop-rt)/7+5*s)
            k += R.uniform(3, 6)*s
        c.set_source_rgba(*rgba('#6a5030', .5)); c.set_line_width(1.4*s); c.stroke()
        c.move_to(xl, yy); c.line_to(xr, yy); c.set_source_rgba(*rgba('#5a4026', .6)); c.set_line_width(2*s); c.stroke()
    c.move_to(x-W*.3, rt); c.line_to(x+W*.3, rt); c.set_source_rgba(*rgba('#4a3420')); c.set_line_width(6*s); c.stroke()
    # eave shadow
    c.rectangle(wx0, wtop, wx1-wx0, 14*s); c.set_source_rgba(0, 0, 0, .3); c.fill()
    # porch / dock with steps down to water
    px0 = x+W*.45
    c.rectangle(px0, floor-4*s, 110*s, 8*s); c.set_source_rgba(*rgba('#6a5034')); c.fill()
    for i in range(3):
        c.move_to(px0+20*s+i*40*s, floor); c.line_to(px0+20*s+i*40*s, y+6); c.set_source_rgba(*rgba('#4a3828')); c.set_line_width(5*s); c.stroke()
    for i in range(4):
        c.rectangle(px0+80*s+i*10*s, floor+i*15*s, 34*s, 5*s); c.set_source_rgba(*rgba('#6a5034')); c.fill()
    # a lamp post on the dock, lamp glow
    c.move_to(px0+100*s, floor); c.line_to(px0+100*s, floor-70*s); c.set_source_rgba(*rgba('#3a2a1c')); c.set_line_width(4*s); c.stroke()
    c.rectangle(px0+92*s, floor-84*s, 16*s, 18*s); c.set_source_rgba(*rgba('#e8c070')); c.fill()
    g.arc(px0+100*s, floor-75*s, 12*s, 0, 6.3); g.set_source_rgba(1, 1, 1, 1); g.fill()
    # clothes line + water jars (lu)
    for i, jx in enumerate((x-W*.5-20*s, x-W*.5-60*s)):
        c.save(); c.translate(jx, floor-2*s); c.scale(1, 1.1)
        c.arc(0, -18*s, 20*s, 0, 6.3); c.restore()
        c.set_source_rgba(*rgba('#7a4a2a')); c.fill()
    return floor

def vgrad_px(y0, y1, stops):
    g = cairo.LinearGradient(0, y0, 0, y1)
    for t, col in stops: g.add_color_stop_rgba(t, *col)
    return g

def monkey_bridge(c, R, x0, x1, y, s=1.0):
    """cầu khỉ: one bamboo walking pole on X-crossed legs, a handrail above"""
    span = x1-x0
    n = 7
    deck = []
    for i in range(n+1):
        t = i/n
        dx = x0+span*t
        dy = y-(30+170*math.sin(t*math.pi))*s
        deck.append((dx, dy))
    col = rgba('#8a7a4a'); dark = rgba('#5a4a2a')
    for i, (dx, dy) in enumerate(deck):
        if 0 < i < n:
            for sgn in (-1, 1):
                c.move_to(dx-sgn*22*s, y+8); c.line_to(dx+sgn*14*s, dy-16*s)
            c.set_source_rgba(*dark); c.set_line_width(4.2*s); c.stroke()
    # walking pole
    c.move_to(*deck[0])
    for p in deck[1:]: c.line_to(*p)
    c.set_source_rgba(*col); c.set_line_width(5*s); c.stroke()
    # handrail
    rail = [(p[0], p[1]-46*s) for p in deck[1:-1]]
    c.move_to(deck[0][0]+span*.04, deck[0][1]-30*s)
    for p in rail: c.line_to(*p)
    c.line_to(deck[-1][0]-span*.04, deck[-1][1]-30*s)
    c.set_source_rgba(*col); c.set_line_width(3.2*s); c.stroke()
    for p in rail:
        c.move_to(p[0], p[1]); c.line_to(p[0]+4*s, p[1]+50*s)
    c.set_source_rgba(*dark); c.set_line_width(2.6*s); c.stroke()

def mud_bank(c, R, x0, x1, s=1.0):
    pts = [(x0, WL+30)]
    x = x0
    while x < x1:
        pts.append((x, WL-R.uniform(4, 16)))
        x += R.uniform(40, 90)
    pts.append((x1, WL-10)); pts.append((x1, WL+30))
    crpath(c, pts, True)
    c.set_source(vgrad_px(WL-24, WL+4, [(0, rgba('#6a5432')), (.6, rgba('#7e6a44')), (1, rgba('#4a3a22'))])); c.fill()
    # wet line
    c.rectangle(x0, WL-4, x1-x0, 6); c.set_source_rgba(*rgba('#3a2c18', .6)); c.fill()

def hyacinth(c, R, x, y, s=1.0, flower=True, shade=0.0):
    """lục bình rosette: glossy kidney leaves on swollen petioles, lilac spike"""
    n = R.randint(8, 12)
    leaves = []
    for i in range(n):
        a = -1.25+2.5*i/(n-1)+R.uniform(-.18, .18)
        L = R.uniform(30, 50)*s*(1-.25*abs(a))
        back = R.random() < .45
        leaves.append((back, a, L))
    leaves.sort(key=lambda t: (not t[0], abs(t[1])) if False else (0 if t[0] else 1, -abs(t[1])))
    for back, a, L in leaves:
        sh = shade+(.22 if back else 0)
        bx, by = x+math.sin(a)*L*1.15, y-math.cos(a)*L*.45-L*.2
        # swollen spongy petiole (bulb)
        c.move_to(x+math.sin(a)*3*s, y)
        c.curve_to(x+math.sin(a)*L*.35, y-L*.05, bx-math.sin(a)*L*.1, by+L*.35, bx, by+L*.08)
        c.set_source_rgba(*rgba('#5e8e34', 1, -sh)); c.set_line_width(7*s); c.stroke()
        c.save(); c.translate(x+math.sin(a)*L*.3, y-L*.12); c.rotate(a); c.scale(.55, 1)
        c.arc(0, 0, 5.5*s, 0, 6.3); c.restore()
        c.set_source_rgba(*rgba('#7aa848', 1, -sh)); c.fill()
        # kidney-shaped blade facing outward
        r = L*.42
        c.save(); c.translate(bx, by-r*.55); c.rotate(a*.7)
        c.move_to(0, r*.95)
        c.curve_to(-r*1.25, r*.6, -r*1.2, -r*1.05, -r*.1, -r*.95)
        c.curve_to(-r*.02, -r*.8, r*.02, -r*.8, r*.1, -r*.95)
        c.curve_to(r*1.2, -r*1.05, r*1.25, r*.6, 0, r*.95)
        c.close_path()
        g = cairo.RadialGradient(-r*.3, -r*.5, r*.1, 0, 0, r*1.3)
        base = mix(hexc('#3c7426'), hexc('#78b448'), R.uniform(.3, .8))
        g.add_color_stop_rgba(0, *mix(mix(base, (1, 1, .85, 1), .28), (0, 0, 0, 1), sh))
        g.add_color_stop_rgba(.6, *mix(base, (0, 0, 0, 1), sh))
        g.add_color_stop_rgba(1, *mix(base, (0, 0, 0, 1), sh+.25))
        c.set_source(g); c.fill_preserve()
        c.set_source_rgba(*rgba('#1e3a12', .7, 0)); c.set_line_width(1.3*s); c.stroke()
        # veins
        for k in (-.6, -.25, .25, .6):
            c.move_to(0, r*.85); c.curve_to(k*r*.4, r*.2, k*r*.9, -r*.3, k*r*.95, -r*.75)
        c.set_source_rgba(*rgba('#24461a', .28)); c.set_line_width(.9*s); c.stroke()
        # gloss
        c.save(); c.translate(-r*.38, -r*.45); c.rotate(-.5); c.scale(1, .45); c.arc(0, 0, r*.32, 0, 6.3); c.restore()
        c.set_source_rgba(1, 1, .92, .3*(1-sh)); c.fill()
        c.restore()
    if flower:
        fx, fy = x+R.uniform(-6, 6)*s, y-L*0-64*s
        c.move_to(x, y-14*s); c.curve_to(x, y-40*s, fx, fy+40*s, fx, fy+14*s)
        c.set_source_rgba(*rgba('#5a8a32', 1, -shade)); c.set_line_width(4*s); c.stroke()
        for k in range(10):
            px = fx+R.uniform(-11, 11)*s; py = fy+R.uniform(-18, 16)*s
            c.save(); c.translate(px, py); c.rotate(R.uniform(-.4, .4))
            for p in range(6):
                c.save(); c.rotate(p*1.047); c.scale(1, .6); c.arc(5.6*s, 0, 5*s, 0, 6.3); c.restore()
            c.set_source_rgba(*rgba('#b49ade', .97, -shade)); c.fill()
            c.save(); c.rotate(-1.57); c.scale(1, .6); c.arc(6*s, 0, 4.4*s, 0, 6.3); c.restore()
            c.set_source_rgba(*rgba('#8a6ad0', 1, -shade)); c.fill()
            c.arc(0, -6*s, 1.8*s, 0, 6.3); c.set_source_rgba(*rgba('#f2d040', 1)); c.fill()
            c.restore()
            c.arc(px, py, 1.2*s, 0, 6.3); c.set_source_rgba(*rgba('#4a3a8a', .6)); c.fill()


# ---------------- far bank composition ----------------

def build_bank():
    R = random.Random(11)
    layers = []  # (surface, is_foliage)
    # L1: distant tree line (very far, soft) + a distant pagoda roof
    s, c = new()
    for k in range(260):
        x = R.uniform(-50, BW+50); h = R.uniform(70, 160)
        for j in range(5):
            c.new_sub_path(); c.arc(x+R.uniform(-30, 30), WL-30-h+R.uniform(-10, 40), R.uniform(24, 46), 0, 6.3)
        c.set_source_rgba(*rgba('#58704e', 1, R.uniform(-.1, .1))); c.fill()
    for k in range(40):
        x = R.uniform(0, BW)
        coconut(c, R, x, WL-40, R.uniform(170, 240), R.uniform(-.4, .4), .55, .1)
    c.rectangle(0, WL-90, BW, 60); c.set_source_rgba(*rgba('#58704e')); c.fill()
    layers.append((s, True, .62))
    # L2: back coconut palms + tall trees
    s, c = new()
    for k in range(10):
        canopy_tree(c, R, R.uniform(0, BW), WL-30, R.uniform(260, 340), R.uniform(220, 300), 1.0, .1)
    xs = sorted(R.uniform(80, BW-80) for _ in range(19))
    for x in xs:
        coconut(c, R, x, WL-26, R.uniform(330, 520), R.uniform(-.55, .55), .85, .12)
    layers.append((s, True, .30))
    # L3: bamboo clumps, banana, mid trees
    s, c = new()
    for x in (300, 1350, 2200, 3300, 4100, 5050):
        bamboo(c, R, x+R.uniform(-80, 80), WL-24, R.uniform(.8, 1.0), .05)
    for k in range(5):
        canopy_tree(c, R, R.uniform(0, BW), WL-20, R.uniform(200, 260), R.uniform(180, 240), .9, .05, '#2a4a1a', '#86b04a')
    layers.append((s, True, .12))
    # L4: structures
    s, c = new(); sg, g = new()
    floor = house(c, g, R, 2780, WL-4, 1.0)
    for k in range(3): banana(c, R, 2330+k*70+R.uniform(-20, 20), WL-30, 1.0)
    house(c, g, R, 4560, WL-6, .78)
    monkey_bridge(c, R, 1440, 1900, WL-6, 1.0)
    # a small shrine (miếu) on a post
    c.move_to(3800, WL-8); c.line_to(3800, WL-80); c.set_source_rgba(*rgba('#5a4430')); c.set_line_width(5); c.stroke()
    c.rectangle(3784, WL-104, 32, 24); c.set_source_rgba(*rgba('#c84a2a')); c.fill()
    c.move_to(3776, WL-102); c.line_to(3800, WL-120); c.line_to(3824, WL-102); c.close_path(); c.set_source_rgba(*rgba('#8a2a1a')); c.fill()
    g.arc(3800, WL-92, 8, 0, 6.3); g.set_source_rgba(1, 1, 1, .9); g.fill()
    layers.append((s, False, 0))
    # L5: dừa nước along the water + bank vegetation
    s, c = new()
    x = -60
    while x < BW+60:
        gap = (1440 < x < 1900) or (2560 < x < 3080) or (4380 < x < 4760)
        if not gap or R.random() < .15:
            nipa(c, R, x, WL-6, R.uniform(.75, 1.05), R.uniform(0, .12))
        x += R.uniform(110, 190)
    for k in range(26):
        x0 = R.uniform(0, BW)
        for j in range(R.randint(1, 4)):
            hyacinth(c, R, x0+j*R.uniform(20, 40), WL+R.uniform(-4, 6), R.uniform(.7, 1.0), R.random() < .25, .05)
    layers.append((s, True, 0))
    # L6: mud bank strip (drawn first in z, so put it before L5 visually) -> just under everything
    s, c = new()
    mud_bank(c, R, -20, 1480)
    mud_bank(c, R, 1860, BW+20)
    layers.insert(3, (s, False, 0))

    # composite with haze
    col = np.zeros((BH, BW, 3), np.float32); al = np.zeros((BH, BW), np.float32); sway = np.zeros((BH, BW), np.float32)
    haze = np.array([0.72, 0.80, 0.80], np.float32)  # light blue-grey
    for surf, fol, hz in layers:
        a = to_np(surf)
        pa = a[..., 3]
        prgb = a[..., [2, 1, 0]]  # premultiplied
        if hz:
            prgb = prgb*(1-hz)+haze[None, None, :]*pa[..., None]*hz
        col = col*(1-pa[..., None])+prgb
        al = al*(1-pa)+pa
        sway = sway*(1-pa)+pa*(1.0 if fol else 0.0)
    rgb = col/np.maximum(al[..., None], 1e-4)
    img = np.concatenate([rgb, al[..., None]], -1)
    Image.fromarray((img.clip(0, 1)*255).astype(np.uint8), 'RGBA').save(f'{OUT}/bank.png')
    glow = to_np(sg)[..., 3]
    glow = np.asarray(Image.fromarray((glow*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))).astype(np.float32)/255
    aux = np.stack([glow, sway, np.zeros_like(glow), np.ones_like(glow)], -1)
    Image.fromarray((aux*255).astype(np.uint8), 'RGBA').resize((BW//2, BH//2), Image.BILINEAR).save(f'{OUT}/bank_aux.png')

# ---------------- foreground (near bank, bottom of screen) ----------------
FW, FH = 2800, 420
def build_fg():
    R = random.Random(5)
    s, c = new(FW, FH)
    # bank profile: lower in the middle so the water shows
    top = []
    for i in range(41):
        x = FW*i/40
        t = abs(x-FW*.5)/(FW*.5)
        y = FH-60-180*t**1.6+R.uniform(-8, 8)
        top.append((x, y))
    pts = [(-10, FH+10)]+top+[(FW+10, FH+10)]
    crpath(c, pts, True)
    c.set_source(vgrad_px(FH-260, FH, [(0, rgba('#5e7a34')), (.3, rgba('#6e5a34')), (1, rgba('#3e2e1a'))])); c.fill()
    # grass tufts along the edge
    for i in range(900):
        x = R.uniform(0, FW)
        t = abs(x-FW*.5)/(FW*.5)
        y = FH-60-180*t**1.6+R.uniform(0, 30+200*t)
        if y > FH+10: continue
        L = R.uniform(30, 90)*(.6+t)
        a = R.uniform(-.6, .6)
        e = (x+math.sin(a)*L, y-math.cos(a)*L)
        leaf(c, (x, y), e, R.uniform(3, 6), R.uniform(-.25, .25))
        col = mix(hexc('#2a4a18'), hexc('#a4c058'), R.uniform(0, 1)*(1-(y-(FH-200))/400*.5))
        c.set_source_rgba(*col); c.fill()
    # reeds (cỏ lau) on the left and right
    for side in (0, 1):
        for i in range(26):
            x = (R.uniform(20, 380) if side == 0 else R.uniform(FW-380, FW-20))
            y = FH-20
            h = R.uniform(200, 330)
            a = R.uniform(-.25, .25)+(.15 if side == 0 else -.15)
            tip = (x+math.sin(a)*h, y-h)
            c.move_to(x, y); c.curve_to(x, y-h*.5, tip[0]-math.sin(a)*20, tip[1]+40, *tip)
            c.set_source_rgba(*rgba('#8a9a4a')); c.set_line_width(3); c.stroke()
            # plume
            for k in range(14):
                p = (tip[0]+R.uniform(-6, 6), tip[1]+k*4)
                e = (p[0]+R.uniform(8, 22)*(1 if a > 0 else -1), p[1]+R.uniform(4, 16))
                leaf(c, p, e, 4, .1); c.set_source_rgba(*rgba('#e8dcc0', .85)); c.fill()
            for k in range(3):
                b = R.uniform(.25, .6); p = (x+math.sin(a)*h*b, y-h*b)
                e = (p[0]+R.uniform(-90, 90), p[1]+R.uniform(-60, 20))
                leaf(c, p, e, 7, R.uniform(-.2, .2)); c.set_source_rgba(*rgba('#5a7a2a')); c.fill()
    s.write_to_png(f'{OUT}/fg.png')

# ---------------- floating props ----------------
def outline_png(path, px=3, col=(38, 80, 46), lift=1.12):
    """cartoon sticker outline: dilate alpha, fill the ring with a dark colour behind the art"""
    from PIL import ImageEnhance
    im = Image.open(path).convert('RGBA'); a = im.getchannel('A')
    rgb = ImageEnhance.Color(ImageEnhance.Brightness(im.convert('RGB')).enhance(lift)).enhance(1.1)
    im = rgb.convert('RGBA'); im.putalpha(a)
    ring = a.filter(ImageFilter.MaxFilter(px))
    base = Image.new('RGBA', im.size, col+(0,)); base.putalpha(ring)
    base.alpha_composite(im); base.save(path)

def build_props():
    R = random.Random(9)
    for i in range(4):
        s, c = new(320, 220)
        for k in range(R.randint(2, 4)):
            hyacinth(c, R, 160+R.uniform(-70, 70), 185+R.uniform(-10, 10), R.uniform(1.4, 1.9), R.random() < .45, R.uniform(0, .15))
        s.write_to_png(f'{OUT}/prop_lucbinh{i}.png'); outline_png(f'{OUT}/prop_lucbinh{i}.png')
    # trader boat (ghe hàng), cartoon style: flat colours + dark outline; oar drawn at runtime from the grip (552,142)
    s, c = new(700, 300)
    OL = rgba('#2a1e14'); c.set_line_join(cairo.LINE_JOIN_ROUND); c.set_line_cap(cairo.LINE_CAP_ROUND)
    def ink(w=2.0): c.set_source_rgba(*OL); c.set_line_width(w); c.stroke()
    def hull_path():
        c.move_to(26, 150); c.curve_to(60, 196, 120, 222, 200, 226); c.line_to(560, 226)
        c.curve_to(620, 222, 664, 186, 684, 138); c.line_to(660, 162); c.curve_to(560, 178, 160, 178, 52, 166); c.close_path()
    # inside of the hull (dark) visible above the near gunwale
    c.move_to(52, 166); c.curve_to(160, 160, 560, 160, 660, 162); c.curve_to(560, 178, 160, 178, 52, 166); c.close_path()
    c.set_source_rgba(*rgba('#5a3a20')); c.fill()
    # cargo first so the near gunwale overlaps it
    def thung(bx, by, r, fruit, n=9):
        for k in range(n):
            fx, fy = bx+R.uniform(-r*.75, r*.75), by-6+R.uniform(-10, 2)
            c.arc(fx, fy, 9, 0, 6.3); c.set_source_rgba(*rgba(fruit[0])); c.fill_preserve(); ink(1.3)
            c.arc(fx-3, fy-3, 3, 0, 6.3); c.set_source_rgba(1, 1, 1, .55); c.fill()
        c.move_to(bx-r, by-4); c.line_to(bx+r, by-4); c.curve_to(bx+r*.9, by+22, bx-r*.9, by+22, bx-r, by-4); c.close_path()
        c.set_source_rgba(*rgba('#d8a85a')); c.fill_preserve(); ink(1.7)
        for k in range(1, 6):
            c.move_to(bx-r+k*r/3, by-3); c.line_to(bx-r*.9+k*r*.3, by+16)
        c.set_source_rgba(*rgba('#a8783a')); c.set_line_width(1.6); c.stroke()
    thung(150, 152, 40, ['#f0b030'])
    thung(240, 150, 40, ['#e0402a'])
    # buồng chuối
    for k in range(7):
        x0 = 300+k*9; c.move_to(x0, 160); c.curve_to(x0-6, 140, x0+4, 126, x0+12, 122)
    c.set_source_rgba(*rgba('#e8d040')); c.set_line_width(9); c.stroke()
    for k in range(7):
        x0 = 300+k*9; c.move_to(x0, 160); c.curve_to(x0-6, 140, x0+4, 126, x0+12, 122)
    c.set_source_rgba(*OL); c.set_line_width(1.2); c.stroke()
    # dừa tươi pile
    for (dx, dy) in ((390, 160), (414, 162), (402, 146), (438, 161), (426, 147)):
        c.arc(dx, dy, 12, 0, 6.3); c.set_source_rgba(*rgba('#6aa83a')); c.fill_preserve(); ink(1.4)
        c.arc(dx-4, dy-4, 4, 0, 6.3); c.set_source_rgba(1, 1, 1, .35); c.fill()
    # rower: standing woman, black pants, light áo bà ba, nón lá
    px, deck = 520, 172
    # legs
    c.move_to(px-10, deck); c.line_to(px-8, 132); c.line_to(px+10, 132); c.line_to(px+12, deck); c.close_path()
    c.set_source_rgba(*rgba('#2a2a34')); c.fill_preserve(); ink(1.6)
    # body (áo bà ba)
    c.move_to(px-14, 136); c.curve_to(px-16, 116, px-12, 100, px, 96); c.curve_to(px+12, 98, px+16, 112, px+15, 136); c.close_path()
    c.set_source_rgba(*rgba('#f2e8f6')); c.fill_preserve(); ink(1.6)
    c.move_to(px+1, 99); c.line_to(px+2, 134); c.set_source_rgba(*rgba('#c8b8d8')); c.set_line_width(1.6); c.stroke()
    # arms to the oar grip
    c.move_to(px+8, 104); c.curve_to(px+22, 116, px+28, 128, 548, 140); c.set_source_rgba(*rgba('#f2e8f6')); c.set_line_width(9); c.stroke()
    c.move_to(px+8, 104); c.curve_to(px+22, 116, px+28, 128, 548, 140); c.set_source_rgba(*OL); c.set_line_width(1.6); c.stroke()
    c.arc(552, 142, 5, 0, 6.3); c.set_source_rgba(*rgba('#d89a64')); c.fill_preserve(); ink(1.2)
    # head + khăn rằn scarf at the neck
    c.arc(px+1, 88, 10, 0, 6.3); c.set_source_rgba(*rgba('#d89a64')); c.fill_preserve(); ink(1.4)
    c.move_to(px-9, 97); c.line_to(px+11, 97); c.line_to(px+8, 102); c.line_to(px-6, 102); c.close_path()
    c.set_source_rgba(*rgba('#e8e4dc')); c.fill_preserve(); ink(1.0)
    # nón lá
    c.move_to(px-30, 86); c.line_to(px+1, 54); c.line_to(px+32, 86); c.curve_to(px+12, 91, px-10, 91, px-30, 86); c.close_path()
    c.set_source_rgba(*rgba('#f2dc9a')); c.fill_preserve(); ink(1.6)
    c.move_to(px+1, 54); c.line_to(px+32, 86); c.curve_to(px+20, 89, px+12, 90, px+6, 90); c.close_path()
    c.set_source_rgba(*rgba('#d8b868')); c.fill()
    c.move_to(px-30, 86); c.curve_to(px-10, 91, px+12, 91, px+32, 86); ink(1.6)
    # hull on top: green with red + white stripe, outline
    hull_path(); c.set_source_rgba(*rgba('#2f8a6a')); c.fill_preserve(); ink(2.2)
    c.save(); hull_path(); c.clip()
    c.move_to(46, 178); c.curve_to(160, 192, 560, 192, 668, 160); c.set_source_rgba(*rgba('#d8402a')); c.set_line_width(7); c.stroke()
    c.move_to(54, 186); c.curve_to(160, 199, 560, 199, 664, 170); c.set_source_rgba(*rgba('#f4ecd8')); c.set_line_width(3); c.stroke()
    c.move_to(52, 166); c.curve_to(160, 178, 560, 178, 660, 162); c.set_source_rgba(*rgba('#e8c060')); c.set_line_width(4); c.stroke()
    c.restore(); hull_path(); ink(2.2)
    # mắt ghe: almond eye on the bow
    c.save(); c.translate(624, 194); c.rotate(-.35)
    c.move_to(-13, 0); c.curve_to(-5, -8, 7, -8, 13, 0); c.curve_to(5, 6, -7, 6, -13, 0); c.close_path()
    c.set_source_rgba(1, 1, 1, 1); c.fill_preserve(); c.restore(); ink(1.2)
    c.arc(626, 193, 3.6, 0, 6.3); c.set_source_rgba(.1, .1, .1, 1); c.fill()
    s.write_to_png(f'{OUT}/prop_ghe.png')

if __name__ == '__main__':
    import sys
    what = sys.argv[1:] or ['bank', 'fg', 'props']
    if 'bank' in what: build_bank()
    if 'fg' in what: build_fg()
    if 'props' in what: build_props()
    print('done')
