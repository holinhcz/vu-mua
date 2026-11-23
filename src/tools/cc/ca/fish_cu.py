# Mekong-delta fish, drawn side-on facing right. Run: python3 fish.py [id ...]
import sys, math, os
from fishkit import *

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')

def build(spec):
    sp = Sprite(scale=spec.get('scale', 0.86), cx=spec.get('cx', 0.07), cy=spec.get('cy', 0.5))
    pts = body_pts(spec['top'], spec['bot'])
    body = lambda c: crpath(c, pts, True)
    mask = sp.mask(lambda c: (body(c), c.fill()))
    C = {k: hexc(v) if isinstance(v, str) else v for k, v in spec['col'].items()}
    ytop = max(p[1] for p in spec['top']); ybot = min(p[1] for p in spec['bot'])

    def fins(layer):
        def f(c):
            for fs in spec.get('fins', []):
                if fs.get('layer', 'back') != layer: continue
                col = hexc(fs.get('col', spec['col']['fin']), fs.get('a', .92))
                edge = hexc(fs.get('edge', spec['col'].get('finedge', '#3a2a14')), fs.get('ea', .55))
                fade = hexc(fs['fade'], fs.get('fa', .75)) if fs.get('fade') else None
                fin(c, fs['b0'], fs['b1'], fs['o'], col, edge, fs.get('rays', 0),
                    hexc(fs.get('raycol', spec['col'].get('ray', '#3a2a14')), fs.get('ra', .35)),
                    fs.get('spiny', 0), fs.get('rw', .0028), fs.get('ew', .003), fade)
        return f

    # fins behind the body
    sp.draw(fins('back'))
    # body base colour
    def base(c):
        body(c)
        m, b = spec.get('mid', .42), spec.get('bel', .78)
        # cartoon: hard colour bands (back / flank / belly) instead of a soft gradient
        c.set_source(vgrad(c, ytop, ybot, [(0, C['back']), (m*.7, C['back']), (m*.7+.06, C['flank']), (b*.9, C['flank']), (b*.9+.05, C['belly']), (1, C['belly'])]))
        c.fill()
    sp.draw(base)
    # soft pattern (blurred) then crisp pattern
    if spec.get('soft'): sp.draw(spec['soft'], blur=min(.5, spec.get('softblur', 3)*.2), clip=mask)
    if spec.get('pattern'): sp.draw(spec['pattern'], blur=spec.get('patblur', .6), clip=mask)
    # organic grain: small soft dabs, darker and lighter
    if False and spec.get('grain', 1):
        sp.draw(blotches(99, 60, .15, .95, ybot, ytop, .006, .016, '#000000', .10), blur=1.2, clip=mask)
        sp.draw(blotches(98, 40, .15, .95, ybot*.3, ytop, .006, .014, '#ffffff', .07), blur=1.2, clip=mask)
    if spec.get('scales'):
        sx, sy, x0, x1 = spec['scales'][:4]
        sca = spec['scales'][4] if len(spec['scales']) > 4 else .22
        def smask_fn(c):
            crpath(c, pts, True)
            g = vgrad(c, ytop, ybot, [(0, (1, 1, 1, .15)), (.28, (1, 1, 1, 1)), (.62, (1, 1, 1, .9)), (.9, (1, 1, 1, .1)), (1, (1, 1, 1, 0))])
            c.set_source(g); c.fill()
        sm = sp.mask(smask_fn)
        hx = spec.get('headx', .8)
        def hfade(c):
            g = cairo.LinearGradient(hx-.06, 0, hx, 0); g.add_color_stop_rgba(0, 1, 1, 1, 1); g.add_color_stop_rgba(1, 1, 1, 1, 0)
            g2 = cairo.LinearGradient(x0, 0, x0+.06, 0)
            c.rectangle(-1, -1, 3, 2); c.set_source(g); c.fill()
        hm = sp.mask(hfade)
        sm = ImageChops.multiply(ImageChops.multiply(sm, hm), mask)
        sp.draw(lambda c: scales(c, x0, x1, ybot, ytop, sx, sy, (0, 0, 0, sca), .0024), clip=sm, blur=.35)
        sp.draw(lambda c: (c.translate(-.0035, .0035), scales(c, x0, x1, ybot, ytop, sx, sy, (1, 1, 1, sca*.55), .0016)), clip=sm, blur=.35)
    # roundness: top highlight, belly shade
    def shade(c):
        # cartoon: one crisp light band on the back, one flat shadow along the belly
        body(c)
        c.set_source(vgrad(c, ytop, ybot, [(0, (0, 0, 0, 0)), (.86, (0, 0, 0, 0)), (.8601, (0, 0, 0, .14)), (1, (0, 0, 0, .14))]))
        c.fill()
    sp.draw(shade, clip=mask)
    # 2.5D cel volume: a crisp lit band hugging the back, the tail end turning away into shadow, a small gloss on the head
    hx_ = spec.get('headx', .84)
    band = [p for p in spec['top'] if .18 <= p[0] <= hx_ + .02]
    if len(band) >= 3:
        def litband(c):
            c.move_to(*band[0])
            for p in band[1:]: c.line_to(*p)
            for x, y in reversed(band): c.line_to(x, y - (y - ybot) * .3 * max(0, min(1, (x - .15) * 3, (hx_ + .02 - x) * 5)))
            c.close_path(); c.set_source_rgba(1, 1, .92, spec.get('lit', .2)); c.fill()
        sp.draw(litband, clip=mask)
    def tailshade(c):
        g = cairo.LinearGradient(.12, 0, .42, 0); g.add_color_stop_rgba(0, 0, 0, 0, .2); g.add_color_stop_rgba(1, 0, 0, 0, 0)
        c.rectangle(-1, -1, 3, 2); c.set_source(g); c.fill()
    sp.draw(tailshade, clip=mask)
    if spec.get('gloss', 1):
        ex, ey = spec['eye'][0], spec['eye'][1]
        sp.draw(lambda c: (c.save(), c.translate(ex - .075, (ey + ytop) * .5 + .004), c.rotate(-.12), c.scale(1, .32),
                           c.arc(0, 0, .03, 0, 6.3), c.restore(), c.set_source_rgba(1, 1, 1, .5), c.fill()), clip=mask)
    if spec.get('shine', 0):
        hx = spec.get('shinex', (0.35, 0.78)); hy = spec.get('shiney', ytop*0.45)
        sp.draw(lambda c: (c.move_to(hx[0]+.05, hy*0.85), c.curve_to(hx[0]+.15, hy*1.0, hx[1]-.2, hy*1.0, hx[1]-.08, hy*.88),
                           c.set_line_width(.012), c.set_line_cap(cairo.LINE_CAP_ROUND), c.set_source_rgba(1, 1, 1, .7), c.stroke()), clip=mask)
    # head: gill cover, mouth, extras
    if spec.get('head'): sp.draw(spec['head'], blur=.4)
    sp.draw(fins('front'))
    if spec.get('front'): sp.draw(spec['front'], blur=.3)
    e = spec['eye']
    sp.draw(lambda c: eye(c, e[0], e[1], e[2], e[3] if len(e) > 3 else '#c89a2a'))
    img = sp.finish(spec.get('outline', '#24170b'), spec.get('ow', 2.0)*1.0, spec.get('bend'))
    return img


def gill(x, y0, y1, bulge, col='#1c140a', a=.45, w=.006):
    def f(c):
        c.move_to(x, y0); c.curve_to(x-bulge, y0*.4, x-bulge, y1*.4, x+bulge*.3, y1)
        c.set_source_rgba(*hexc(col, a)); c.set_line_width(w); c.stroke()
        c.move_to(x+.006, y0*.9); c.curve_to(x-bulge+.008, y0*.35, x-bulge+.008, y1*.35, x+bulge*.3+.006, y1*.92)
        c.set_source_rgba(1, 1, 1, .18); c.set_line_width(w*.6); c.stroke()
    return f

def mouth(x0, y0, x1, y1, col='#2a1a0c', a=.7, w=.005):
    def f(c):
        c.move_to(x0, y0); c.curve_to((x0+x1)/2, y0-.004, x1, (y0+y1)/2, x1, y1)
        c.set_source_rgba(*hexc(col, a)); c.set_line_width(w); c.stroke()
    return f

def seq(*fs):
    def f(c):
        for g in fs:
            c.save(); g(c); c.restore()
    return f

def spots(pts, r, col, a=1.0):
    def f(c):
        for p in pts:
            rr = p[2] if len(p) > 2 else r
            c.save(); c.translate(p[0], p[1])
            if len(p) > 3: c.scale(p[3], 1)
            c.arc(0, 0, rr, 0, 2*math.pi); c.restore()
            c.set_source_rgba(*hexc(col, a)); c.fill()
    return f

def blotches(seed, n, x0, x1, y0, y1, r0, r1, col, a=1, wob=.35):
    import random
    R = random.Random(seed)
    def f(c):
        for i in range(n):
            x = R.uniform(x0, x1); y = R.uniform(y0, y1); r = R.uniform(r0, r1)
            k = R.randint(5, 8)
            pts = []
            for j in range(k):
                an = j/k*2*math.pi
                rr = r*(1+R.uniform(-wob, wob))
                pts.append((x+math.cos(an)*rr*1.3, y+math.sin(an)*rr))
            crpath(c, pts, True)
            c.set_source_rgba(*hexc(col, a*R.uniform(.7, 1))); c.fill()
    return f

FISH = {}

# ---------- Cá rô đồng ----------
FISH['ro'] = dict(
    top=[(.19, .05), (.3, .1), (.45, .152), (.6, .168), (.74, .15), (.86, .108), (.95, .055), (1.0, .012)],
    bot=[(1.0, .012), (.985, -.022), (.93, -.068), (.8, -.13), (.62, -.155), (.45, -.14), (.32, -.1), (.19, -.05)],
    col=dict(back='#38452a', flank='#7d8a4e', belly='#e4d595', fin='#7f7444', ray='#3b3218', finedge='#3b3218'),
    fins=[
        dict(b0=(.25, .07), b1=(.78, .145), o=[(.2, .14), (.27, .2), (.36, .215), (.5, .225), (.64, .218), (.73, .195)], rays=16, spiny=.45, a=.9),
        dict(b0=(.24, -.075), b1=(.56, -.15), o=[(.19, -.135), (.27, -.19), (.4, -.2), (.5, -.188)], rays=11, spiny=.35),
        dict(b0=(.215, .05), b1=(.215, -.05), o=[(.13, .12), (.04, .135), (-.004, .07), (-.01, 0), (-.004, -.07), (.04, -.135), (.13, -.12)], rays=14, fade='#5a4e2a'),
        dict(b0=(.74, -.125), b1=(.7, -.14), o=[(.66, -.19), (.62, -.21), (.64, -.17)], rays=4, layer='front', a=.85),
        dict(b0=(.78, .0), b1=(.775, -.045), o=[(.72, .01), (.65, -.03), (.66, -.065)], rays=6, layer='front', a=.7, col='#9c8f58'),
    ],
    soft=seq(blotches(3, 7, .3, .72, -.06, .12, .03, .05, '#28321c', .35),
             spots([(.235, .0, .035)], .03, '#1a160c', .9), spots([(.79, .06, .022)], .02, '#1a160c', .8)),
    softblur=2.2,
    scales=(.034, .026, .2, .8, .26),
    head=seq(gill(.8, .12, -.11, .03), mouth(.94, -.005, 1.0, .006)),
    eye=(.905, .04, .026, '#c8562a'),
)

# ---------- Cá sặc rằn ----------
def sac_pat(c):
    for x in (.36, .44, .52, .6, .68, .76):
        c.move_to(x, .13); c.line_to(x-.07, -.13)
    c.set_source_rgba(*hexc('#2a2814', .22)); c.set_line_width(.012); c.stroke()
    # broken zigzag band eye->tail
    pts=[(.24,.0),(.3,.012),(.36,-.006),(.42,.014),(.48,.0),(.55,.02),(.62,.004),(.69,.024),(.76,.01),(.84,.03)]
    for i in range(len(pts)-1):
        if i%3==2: continue
        c.move_to(*pts[i]); c.line_to(*pts[i+1])
    c.set_source_rgba(*hexc('#201e0c', .75)); c.set_line_width(.02); c.stroke()

FISH['sac'] = dict(
    top=[(.2, .05), (.32, .1), (.48, .145), (.64, .158), (.78, .135), (.9, .085), (.97, .04), (1.0, .01)],
    bot=[(1.0, .01), (.985, -.02), (.92, -.06), (.78, -.125), (.6, -.15), (.42, -.135), (.3, -.1), (.2, -.05)],
    col=dict(back='#4a4a2a', flank='#8f8c5a', belly='#d9cf9e', fin='#86784a', ray='#3a2e18'),
    fins=[
        dict(b0=(.32, .1), b1=(.48, .145), o=[(.3, .15), (.36, .19), (.44, .19)], rays=7, a=.85),
        dict(b0=(.24, -.08), b1=(.66, -.145), o=[(.18, -.14), (.26, -.2), (.42, -.215), (.58, -.19)], rays=18, a=.88),
        dict(b0=(.22, .05), b1=(.22, -.05), o=[(.12, .11), (.02, .14), (.005, .05), (.03, 0), (.005, -.05), (.02, -.14), (.12, -.11)], rays=14, fade='#5a4a28'),
        dict(b0=(.8, .0), b1=(.795, -.04), o=[(.74, .01), (.68, -.03), (.69, -.06)], rays=6, layer='front', a=.65, col='#a99a62'),
    ],
    soft=seq(blotches(7, 9, .28, .74, -.08, .1, .02, .04, '#2e2c18', .3)),
    pattern=sac_pat,
    patblur=1.2,
    scales=(.026, .02, .22, .8, .18),
    head=seq(gill(.82, .11, -.1, .028), mouth(.95, -.004, 1.0, .006)),
    front=lambda c: barbel(c, [(.78, -.12), (.66, -.17), (.5, -.215), (.36, -.235), (.28, -.232)], .007, .002, hexc('#c09048', .95)),
    eye=(.91, .04, .025, '#c86a2a'),
)

# ---------- Cá lóc ----------
FISH['loc'] = dict(
    top=[(.17, .04), (.3, .064), (.5, .084), (.68, .092), (.8, .088), (.88, .074), (.95, .05), (1.0, .016)],
    bot=[(1.0, .016), (.996, -.014), (.97, -.046), (.9, -.08), (.75, -.1), (.55, -.096), (.35, -.076), (.17, -.04)],
    col=dict(back='#2a2a22', flank='#5e5c4a', belly='#e6e0cc', fin='#3a3a30', ray='#14140c'),
    mid=.45, bel=.8,
    fins=[
        dict(b0=(.2, .05), b1=(.74, .09), o=[(.17, .1), (.24, .125), (.4, .135), (.58, .135), (.7, .12)], rays=30, a=.95, fade='#55554a'),
        dict(b0=(.2, -.05), b1=(.58, -.088), o=[(.17, -.09), (.25, -.12), (.4, -.125), (.54, -.115)], rays=20, a=.95, fade='#55554a'),
        dict(b0=(.19, .045), b1=(.19, -.045), o=[(.11, .08), (.03, .085), (-.005, .03), (-.01, 0), (-.005, -.03), (.03, -.085), (.11, -.08)], rays=14, fade='#4a4a40'),
        dict(b0=(.8, -.0), b1=(.795, -.04), o=[(.74, .0), (.69, -.03), (.7, -.06)], rays=7, layer='front', a=.8, col='#55543e'),
        dict(b0=(.77, -.07), b1=(.745, -.08), o=[(.72, -.11), (.7, -.12)], rays=3, layer='front', a=.8, col='#55543e'),
    ],
    soft=seq(*[blotches(11+i, 1, .22+i*.07, .25+i*.07, .0, .04, .028, .035, '#141410', .55, .5) for i in range(8)],
             *[blotches(31+i, 1, .26+i*.07, .29+i*.07, -.05, -.03, .014, .02, '#18180e', .4, .5) for i in range(7)]),
    softblur=1.6,
    scales=(.024, .018, .2, .82, .22),
    head=seq(lambda c: (crpath(c, [(.8, -.05), (.88, -.035), (.95, -.02), (1.0, .0), (.99, -.03), (.94, -.06), (.86, -.085), (.78, -.09)], True), c.set_source_rgba(.93, .9, .8, .55), c.fill()),
             gill(.84, .085, -.08, .026, a=.6, w=.007),
             mouth(.88, -.018, 1.0, .01, w=.007),
             lambda c: [(c.move_to(.86+i*.03, .07), c.line_to(.85+i*.03, .02)) for i in range(3)] and (c.set_source_rgba(0, 0, 0, .25), c.set_line_width(.004), c.stroke()),
             lambda c: (c.move_to(.83, -.02), c.curve_to(.88, -.035, .93, -.03, .97, -.015), c.set_source_rgba(0, 0, 0, .35), c.set_line_width(.012), c.stroke())),
    eye=(.935, .035, .018, '#b89a4a'),
    shiney=.04, shinew=.012,
)



def mirror(top):
    return [(x, -y) for x, y in top[::-1]]

def dots_rows(x0, x1, nx, ys, r, col, a):
    pts = []
    for i in range(nx):
        x = x0+(x1-x0)*i/(nx-1)
        for y in ys: pts.append((x, y))
    return spots(pts, r, col, a)

# ---------- Cá linh ----------
FISH['linh'] = dict(
    top=[(.2, .045), (.35, .09), (.5, .12), (.62, .125), (.75, .11), (.88, .075), (.96, .035), (1.0, .005)],
    bot=[(1.0, .005), (.98, -.025), (.9, -.06), (.75, -.09), (.55, -.1), (.38, -.085), (.27, -.06), (.2, -.045)],
    col=dict(back='#56666a', flank='#c6cfcc', belly='#f6f4ec', fin='#d6b27e', ray='#8a6a3a', finedge='#8a6a3a'),
    mid=.38,
    fins=[
        dict(b0=(.5, .118), b1=(.64, .124), o=[(.5, .2), (.53, .24), (.56, .2)], rays=8, a=.7),
        dict(b0=(.3, -.075), b1=(.4, -.09), o=[(.28, -.13), (.31, -.15)], rays=6, a=.7),
        dict(b0=(.215, .045), b1=(.215, -.045), o=[(.12, .1), (.02, .17), (.04, .11), (.1, .03), (.11, 0), (.1, -.03), (.04, -.11), (.02, -.17), (.12, -.1)], rays=14, a=.75, fade='#c8945a'),
        dict(b0=(.6, -.098), b1=(.57, -.1), o=[(.53, -.14), (.51, -.15)], rays=4, layer='front', a=.7),
        dict(b0=(.83, -.03), b1=(.82, -.055), o=[(.76, -.05), (.71, -.08), (.73, -.09)], rays=5, layer='front', a=.55),
    ],
    soft=spots([(.235, -.003, .022)], .02, '#2a2a28', .75),
    scales=(.03, .024, .2, .82, .2),
    head=seq(gill(.83, .09, -.08, .025, a=.35), mouth(.965, -.002, 1.0, .004)),
    eye=(.915, .028, .03, '#d8d0a0'), shinea=.4, shinew=.035,
)

# ---------- Cá chốt ----------
FISH['chot'] = dict(
    top=[(.2, .04), (.35, .068), (.55, .092), (.7, .098), (.82, .084), (.93, .052), (1.0, .008)],
    bot=[(1.0, .008), (.98, -.02), (.9, -.045), (.75, -.064), (.55, -.07), (.35, -.06), (.2, -.04)],
    col=dict(back='#5e5030', flank='#b4a066', belly='#f0e6c4', fin='#9a8452', ray='#4a3a1c'),
    fins=[
        dict(b0=(.6, .094), b1=(.7, .097), o=[(.6, .18), (.63, .23), (.66, .17)], rays=6, a=.85),
        dict(b0=(.25, .062), b1=(.5, .088), o=[(.25, .09), (.35, .11), (.47, .108)], a=.95, col='#7a6a40', ea=.4),
        dict(b0=(.3, -.06), b1=(.4, -.066), o=[(.28, -.1), (.32, -.12), (.37, -.11)], rays=7, a=.85),
        dict(b0=(.215, .04), b1=(.215, -.04), o=[(.12, .09), (.01, .16), (.05, .08), (.11, .02), (.12, 0), (.11, -.02), (.05, -.08), (.01, -.16), (.12, -.09)], rays=14, a=.85, fade='#6a5a34'),
        dict(b0=(.82, -.04), b1=(.81, -.06), o=[(.74, -.07), (.68, -.1), (.7, -.11)], rays=5, layer='front', a=.8),
    ],
    soft=seq(spots([(.8, .04, .02, 1.4)], .02, '#2e2414', .6),
             lambda c: (c.move_to(.22, .002), c.curve_to(.45, .006, .65, .01, .82, .01), c.set_source_rgba(1, 1, .9, .5), c.set_line_width(.006), c.stroke())),
    softblur=1.4, grain=1,
    head=seq(gill(.85, .07, -.055, .02, a=.4), mouth(.95, -.012, 1.0, .004)),
    front=seq(lambda c: barbel(c, [(.985, .0), (.9, -.03), (.7, -.09), (.5, -.12), (.32, -.13)], .005, .0015, hexc('#5a4a2a', .95)),
              lambda c: barbel(c, [(.99, .004), (.96, .04), (.9, .07), (.84, .085)], .004, .0015, hexc('#5a4a2a', .9)),
              lambda c: barbel(c, [(.96, -.03), (.92, -.06), (.86, -.085)], .004, .0015, hexc('#6a5a3a', .9)),
              lambda c: barbel(c, [(.94, -.035), (.89, -.075), (.84, -.1)], .004, .0015, hexc('#6a5a3a', .9))),
    eye=(.925, .03, .022, '#c8b46a'),
)

# ---------- Cá trê vàng ----------
def tre_dots(c):
    # cá trê vàng: short vertical rows of pale spots along the flank (not long stitched lines)
    for i in range(13):
        x = .28+i*.043
        h = .03+.03*min(1, (x-.2)*2.2)
        for j in range(5):
            y = h-(2*h)*j/4
            c.arc(x+(j % 2)*.006, y, .0055, 0, 2*math.pi); c.set_source_rgba(1, .96, .8, .6); c.fill()
FISH['tre'] = dict(
    top=[(.18, .032), (.35, .046), (.55, .06), (.72, .07), (.84, .069), (.93, .053), (.99, .025), (1.0, 0)],
    bot=[(1.0, 0), (.99, -.03), (.94, -.06), (.82, -.077), (.62, -.074), (.42, -.06), (.26, -.043), (.18, -.032)],
    col=dict(back='#4a3a20', flank='#a8843e', belly='#f0dca8', fin='#7a5e30', ray='#3a2a12'),
    mid=.4, bel=.75,
    fins=[
        dict(b0=(.2, .034), b1=(.8, .069), o=[(.18, .07), (.3, .09), (.5, .104), (.7, .1), (.78, .088)], rays=34, a=.95, fade='#8a6a3a'),
        dict(b0=(.2, -.034), b1=(.6, -.074), o=[(.18, -.075), (.3, -.095), (.48, -.105), (.58, -.094)], rays=24, a=.95, fade='#8a6a3a'),
        dict(b0=(.19, .033), b1=(.19, -.033), o=[(.12, .068), (.04, .066), (.0, .03), (-.01, 0), (0, -.03), (.04, -.066), (.12, -.068)], rays=12, a=.95),
        dict(b0=(.84, -.03), b1=(.83, -.05), o=[(.77, -.06), (.72, -.085), (.75, -.095)], rays=5, layer='front', a=.85),
    ],
    pattern=tre_dots, patblur=.4,
    soft=blotches(5, 10, .25, .8, -.03, .05, .015, .025, '#3a2810', .25), softblur=2,
    head=seq(lambda c: (crpath(c, [(.83, .066), (.9, .058), (.97, .036), (.975, .0), (.9, .005), (.83, .02)], True), c.set_source_rgba(.12, .08, .02, .32), c.fill()),
             lambda c: [(c.arc(.88+i*.022, .04-(i % 2)*.012, .006, 0, 6.3), c.set_source_rgba(0, 0, 0, .12), c.fill()) for i in range(4)],
             gill(.84, .06, -.06, .015, a=.35), mouth(.955, -.02, 1.0, -.002)),
    front=seq(lambda c: barbel(c, [(.99, .005), (.95, .05), (.86, .08), (.78, .085)], .005, .0018, hexc('#3a2a14', .95)),
              lambda c: barbel(c, [(.985, -.02), (.92, -.06), (.82, -.09), (.74, -.1)], .005, .0018, hexc('#3a2a14', .95)),
              lambda c: barbel(c, [(.97, -.035), (.92, -.075), (.86, -.1)], .004, .0016, hexc('#4a3a1c', .9)),
              lambda c: barbel(c, [(.95, -.045), (.9, -.085), (.85, -.11)], .004, .0016, hexc('#4a3a1c', .9))),
    eye=(.94, .03, .012, '#c8a050'), shiney=.035, shinew=.016,
)

# ---------- Cá thát lát cườm ----------
def ocelli(c):
    for i, (x, y, r) in enumerate([(.26, -.018, .016), (.33, -.03, .019), (.41, -.04, .021), (.49, -.048, .021), (.57, -.055, .019), (.64, -.058, .016)]):
        c.arc(x, y, r*1.45, 0, 6.3); c.set_source_rgba(1, 1, .95, .75); c.fill()
        c.arc(x, y, r, 0, 6.3); c.set_source_rgba(.07, .06, .05, .95); c.fill()
def thatlat_bars(c):
    for i in range(30):
        x = .2+i*.022
        c.move_to(x, .12); c.line_to(x-.02, -.1)
    c.set_source_rgba(1, 1, 1, .12); c.set_line_width(.005); c.stroke()
FISH['thatlat'] = dict(
    top=[(.02, .006), (.15, .028), (.35, .08), (.55, .135), (.68, .148), (.78, .128), (.88, .08), (.95, .04), (1.0, .0)],
    bot=[(1.0, .0), (.98, -.026), (.9, -.06), (.75, -.1), (.6, -.112), (.4, -.085), (.2, -.042), (.02, -.006)],
    col=dict(back='#4c4a42', flank='#b4b0a0', belly='#eeebe0', fin='#8a8476', ray='#3a382e'),
    fins=[
        dict(b0=(.52, .128), b1=(.57, .138), o=[(.51, .18), (.53, .2), (.55, .18)], rays=5, a=.8),
        dict(b0=(.02, -.004), b1=(.74, -.1), o=[(-.02, -.01), (.1, -.07), (.3, -.13), (.5, -.16), (.66, -.15)], rays=60, a=.8, rw=.0016, fade='#a8a090'),
        dict(b0=(.86, -.04), b1=(.85, -.06), o=[(.79, -.06), (.74, -.09), (.76, -.1)], rays=6, layer='front', a=.75),
    ],
    pattern=seq(thatlat_bars, ocelli), patblur=.5,
    scales=(.012, .01, .1, .85, .1),
    head=seq(gill(.87, .09, -.07, .022, a=.4), mouth(.92, -.022, 1.0, .0, w=.005)),
    eye=(.94, .03, .018, '#d8c890'), shinex=(.25, .8), shiney=.07,
)

# ---------- Lươn ----------
FISH['luon'] = dict(
    top=[(.0, .004), (.05, .018), (.2, .032), (.5, .04), (.8, .042), (.92, .038), (.98, .022), (1.0, .0)],
    bot=[(1.0, .0), (.98, -.022), (.92, -.036), (.8, -.04), (.5, -.04), (.2, -.032), (.05, -.018), (.0, -.004)],
    col=dict(back='#4a3416', flank='#a2782e', belly='#e2c27e', fin='#7a5e30'),
    mid=.45, bel=.8,
    fins=[], scale=.92, cx=.04,
    soft=blotches(21, 70, .02, .97, -.03, .04, .006, .012, '#2a1a08', .55, .4), softblur=.8,
    head=seq(mouth(.95, -.012, 1.0, -.002, w=.004), lambda c: (c.move_to(.9, -.034), c.line_to(.91, -.025), c.set_source_rgba(0, 0, 0, .4), c.set_line_width(.004), c.stroke())),
    eye=(.965, .018, .008, '#c8a050'), shiney=.025, shinew=.014, shinex=(.1, .9),
    bend=(.075, 2.2, .0, .55),
)

# ---------- Cá bống tượng ----------
FISH['bong'] = dict(
    top=[(.2, .06), (.35, .1), (.5, .125), (.62, .13), (.74, .132), (.85, .118), (.94, .075), (1.0, .02)],
    bot=[(1.0, .02), (.995, -.035), (.94, -.08), (.84, -.112), (.65, -.125), (.45, -.115), (.3, -.09), (.2, -.06)],
    col=dict(back='#382a1a', flank='#8a7048', belly='#dccaa0', fin='#7a6440', ray='#2e2010'),
    fins=[
        dict(b0=(.56, .128), b1=(.68, .132), o=[(.55, .19), (.6, .22), (.66, .2)], rays=6, spiny=.3, a=.9),
        dict(b0=(.3, .095), b1=(.49, .124), o=[(.27, .15), (.33, .2), (.44, .21), (.48, .18)], rays=10, a=.9),
        dict(b0=(.3, -.09), b1=(.45, -.115), o=[(.27, -.15), (.32, -.19), (.42, -.19)], rays=9, a=.9),
        dict(b0=(.21, .06), b1=(.21, -.06), o=[(.13, .11), (.04, .12), (-.005, .06), (-.012, 0), (-.005, -.06), (.04, -.12), (.13, -.11)], rays=14, fade='#4a3a22'),
        dict(b0=(.8, .02), b1=(.79, -.05), o=[(.72, .03), (.64, -.0), (.62, -.06), (.67, -.09)], rays=9, layer='front', a=.85, col='#8a7448'),
        dict(b0=(.78, -.11), b1=(.75, -.118), o=[(.72, -.16), (.69, -.17)], rays=4, layer='front', a=.8),
    ],
    soft=seq(blotches(41, 14, .22, .9, -.09, .11, .025, .045, '#22180c', .6, .45),
             blotches(42, 6, .3, .85, -.11, -.04, .02, .03, '#f0e0b8', .35)), softblur=1.8,
    scales=(.022, .017, .2, .78, .15), headx=.78,
    head=seq(gill(.8, .12, -.1, .03, a=.4), lambda c: (c.move_to(.86, -.06), c.curve_to(.93, -.07, .97, -.05, 1.0, -.02), c.set_source_rgba(0, 0, 0, .5), c.set_line_width(.007), c.stroke())),
    eye=(.92, .085, .022, '#b88a3a'),
)

# ---------- Cá mè vinh ----------
FISH['mevinh'] = dict(
    top=[(.2, .05), (.3, .11), (.42, .18), (.55, .205), (.68, .19), (.8, .15), (.9, .09), (.97, .04), (1.0, .01)],
    bot=[(1.0, .01), (.98, -.025), (.9, -.07), (.78, -.13), (.6, -.16), (.45, -.15), (.32, -.11), (.2, -.05)],
    col=dict(back='#4e5644', flank='#cfd0c2', belly='#f6f4ea', fin='#dca044', ray='#8a5a1a', finedge='#8a5a1a'),
    mid=.36,
    fins=[
        dict(b0=(.47, .19), b1=(.6, .2), o=[(.47, .28), (.5, .34), (.54, .3)], rays=9, a=.85),
        dict(b0=(.3, -.105), b1=(.4, -.14), o=[(.26, -.18), (.29, -.21)], rays=7, a=.85),
        dict(b0=(.215, .05), b1=(.215, -.05), o=[(.12, .12), (-.005, .22), (.04, .12), (.11, .035), (.12, 0), (.11, -.035), (.04, -.12), (-.005, -.22), (.12, -.12)], rays=16, a=.9, fade='#c88a3a'),
        dict(b0=(.6, -.155), b1=(.56, -.158), o=[(.51, -.21), (.49, -.23)], rays=5, layer='front', a=.85),
        dict(b0=(.83, -.06), b1=(.82, -.085), o=[(.75, -.09), (.7, -.13), (.72, -.14)], rays=6, layer='front', a=.7),
    ],
    scales=(.042, .032, .2, .82, .3),
    head=seq(gill(.84, .12, -.11, .03, a=.35), mouth(.965, .0, 1.0, .01)),
    eye=(.925, .045, .027, '#d8c890'), shinea=.45, shinew=.04, shiney=.1,
)

# ---------- Cá he đỏ đuôi ----------
FISH['he'] = dict(FISH['mevinh'],
    col=dict(back='#6a6236', flank='#e8dcaa', belly='#fbf6e4', fin='#e2482a', ray='#8a1e0a', finedge='#7a1a08'),
    fins=[
        dict(b0=(.47, .19), b1=(.6, .2), o=[(.47, .28), (.5, .34), (.54, .3)], rays=9, a=.92, fade='#1a1410', fa=.95),
        dict(b0=(.3, -.105), b1=(.4, -.14), o=[(.26, -.18), (.29, -.21)], rays=7, a=.92),
        dict(b0=(.215, .05), b1=(.215, -.05), o=[(.12, .12), (-.005, .22), (.04, .12), (.11, .035), (.12, 0), (.11, -.035), (.04, -.12), (-.005, -.22), (.12, -.12)], rays=16, a=.92, col='#e8502e', fade='#2a1612', fa=.95),
        dict(b0=(.6, -.155), b1=(.56, -.158), o=[(.51, -.21), (.49, -.23)], rays=5, layer='front', a=.9),
        dict(b0=(.83, -.06), b1=(.82, -.085), o=[(.75, -.09), (.7, -.13), (.72, -.14)], rays=6, layer='front', a=.8, col='#e8a060'),
    ],
)

# ---------- Cá lóc bông ----------
def locbong_pat(c):
    pts = [(.18, -.005), (.26, .012), (.34, -.008), (.42, .015), (.5, -.004), (.58, .016), (.66, .0), (.74, .012), (.82, .0)]
    crpath(c, pts, False); c.set_source_rgba(.04, .05, .06, .85); c.set_line_width(.024); c.stroke()
    import random
    R = random.Random(5)
    for i in range(70):
        x = R.uniform(.2, .84); y = R.uniform(.02, .08)
        c.arc(x, y, R.uniform(.0035, .0065), 0, 6.3); c.set_source_rgba(.75, .9, 1, R.uniform(.5, .9)); c.fill()
FISH['locbong'] = dict(FISH['loc'],
    col=dict(back='#18222a', flank='#465a66', belly='#e8eef0', fin='#202a32', ray='#0a0e12'),
    soft=blotches(77, 12, .25, .8, -.06, -.02, .015, .025, '#0c1014', .35), softblur=2,
    pattern=locbong_pat, patblur=.35,
    eye=(.935, .035, .019, '#c8402a'),
)

# ---------- Cá chình bông ----------
FISH['chinh'] = dict(
    top=[(.0, .004), (.05, .02), (.2, .036), (.5, .048), (.75, .05), (.88, .044), (.96, .03), (1.0, .004)],
    bot=[(1.0, .004), (.98, -.02), (.9, -.036), (.75, -.046), (.5, -.046), (.2, -.036), (.05, -.02), (.0, -.004)],
    col=dict(back='#3e3a1c', flank='#8a8040', belly='#ded6a8', fin='#6a6436', ray='#2a2810'),
    scale=.92, cx=.04,
    fins=[
        dict(b0=(.0, .004), b1=(.62, .048), o=[(-.01, .012), (.1, .045), (.35, .07), (.58, .066)], a=.9, rays=50, rw=.0012, fade='#8a8040'),
        dict(b0=(.0, -.004), b1=(.5, -.046), o=[(-.01, -.012), (.1, -.045), (.3, -.065), (.47, -.062)], a=.9, rays=40, rw=.0012, fade='#b4aa70'),
        dict(b0=(.86, .0), b1=(.855, -.025), o=[(.82, .01), (.8, -.02), (.82, -.035)], rays=6, layer='front', a=.85),
    ],
    soft=blotches(61, 46, .03, .97, -.04, .05, .012, .026, '#1e1c0a', .7, .5), softblur=1.0,
    head=seq(gill(.86, .04, -.03, .01, a=.3), mouth(.94, -.014, 1.0, .0, w=.004)),
    eye=(.955, .022, .01, '#c8b060'), shiney=.028, shinew=.014,
    bend=(.07, 2.0, 1.0, .55),
)

# ---------- Cá tra dầu (huyền thoại) ----------
FISH['tradau'] = dict(
    top=[(.19, .05), (.3, .09), (.45, .13), (.6, .145), (.72, .14), (.84, .115), (.93, .078), (.99, .032), (1.0, 0)],
    bot=[(1.0, 0), (.99, -.04), (.94, -.075), (.82, -.105), (.6, -.12), (.42, -.11), (.3, -.08), (.19, -.05)],
    col=dict(back='#3c464e', flank='#909aa0', belly='#eef0ee', fin='#5a646a', ray='#2a3036'),
    mid=.4, bel=.68, grain=1,
    fins=[
        dict(b0=(.6, .143), b1=(.7, .14), o=[(.6, .22), (.62, .29), (.66, .24)], rays=7, a=.9),
        dict(b0=(.3, .088), b1=(.36, .1), o=[(.3, .125), (.34, .13)], a=.9, col='#4a545a'),
        dict(b0=(.22, -.06), b1=(.42, -.11), o=[(.18, -.12), (.24, -.17), (.34, -.17), (.4, -.15)], rays=14, a=.88),
        dict(b0=(.215, .05), b1=(.215, -.05), o=[(.12, .12), (-.005, .24), (.04, .13), (.11, .04), (.125, 0), (.11, -.04), (.04, -.13), (-.005, -.24), (.12, -.12)], rays=16, a=.9, fade='#3a444a'),
        dict(b0=(.6, -.118), b1=(.56, -.12), o=[(.52, -.17), (.5, -.19)], rays=5, layer='front', a=.85),
        dict(b0=(.85, -.06), b1=(.84, -.085), o=[(.77, -.1), (.71, -.14), (.73, -.15)], rays=7, layer='front', a=.8),
    ],
    soft=seq(lambda c: (c.move_to(.22, .005), c.curve_to(.45, .012, .7, .012, .86, .02), c.set_source_rgba(1, 1, 1, .35), c.set_line_width(.008), c.stroke())),
    softblur=1.2,
    head=seq(gill(.86, .11, -.1, .03, a=.35), mouth(.94, -.03, 1.0, -.01, w=.006)),
    eye=(.95, -.012, .016, '#b8b49a'), shiney=.09,
)

# ---------- Cá hô (huyền thoại) ----------
FISH['ho'] = dict(
    top=[(.2, .06), (.3, .12), (.42, .18), (.55, .205), (.68, .2), (.8, .17), (.9, .12), (.96, .07), (1.0, .02)],
    bot=[(1.0, .02), (.99, -.03), (.94, -.085), (.82, -.14), (.62, -.165), (.45, -.15), (.32, -.11), (.2, -.06)],
    col=dict(back='#3a3628', flank='#a69a74', belly='#ede4c8', fin='#6e6450', ray='#2e281a', finedge='#2e281a'),
    mid=.38,
    fins=[
        dict(b0=(.46, .192), b1=(.6, .204), o=[(.46, .3), (.49, .35), (.55, .3)], rays=10, a=.9, fade='#c87a3a', fa=.8),
        dict(b0=(.3, -.105), b1=(.42, -.15), o=[(.26, -.2), (.3, -.23)], rays=8, a=.9, fade='#c87a3a', fa=.8),
        dict(b0=(.215, .06), b1=(.215, -.06), o=[(.12, .13), (-.005, .23), (.04, .13), (.11, .04), (.12, 0), (.11, -.04), (.04, -.13), (-.005, -.23), (.12, -.13)], rays=16, a=.92, fade='#b0703a', fa=.8),
        dict(b0=(.6, -.162), b1=(.56, -.164), o=[(.5, -.22), (.48, -.24)], rays=5, layer='front', a=.85, fade='#c87a3a'),
        dict(b0=(.74, -.07), b1=(.73, -.1), o=[(.66, -.11), (.61, -.15), (.63, -.16)], rays=7, layer='front', a=.8),
    ],
    scales=(.05, .04, .2, .72, .34), headx=.72,
    soft=blotches(3, 6, .3, .7, -.1, .15, .03, .05, '#2a2418', .2), softblur=3,
    head=seq(gill(.74, .17, -.14, .045, a=.45),
             lambda c: (crpath(c, [(.74, .17), (.85, .15), (.95, .09), (.99, .02), (.96, -.06), (.85, -.12), (.74, -.14)], True), c.set_source_rgba(0, 0, 0, .1), c.fill()),
             mouth(.93, -.0, 1.0, .02, w=.007)),
    eye=(.88, .06, .022, '#c8a050'), shiney=.11, shinea=.3,
)

# ---------- Tôm càng xanh ----------
def tom(spec_unused=None):
    sp = Sprite(scale=.58, cx=.03, cy=.56)
    # shrimp coordinates: body 0..1 along x
    seg = [(.1, -.025), (.19, .025), (.285, .058), (.38, .074), (.47, .072), (.55, .06)]
    hw = [.035, .045, .055, .062, .068, .072]
    blue = hexc('#2f63b8'); blue2 = hexc('#6aa0e8')
    def antenna(c):
        for pts, w in [([(.84, .02), (.7, .16), (.45, .27), (.15, .33), (-.05, .3)], .004), ([(.85, .01), (.75, .2), (.55, .33), (.3, .4)], .003)]:
            barbel(c, pts, w, .0012, hexc('#7a4a2a', .9))
        barbel(c, [(.86, .02), (.95, .08), (1.02, .1)], .004, .002, hexc('#7a5a3a', .9))
        barbel(c, [(.86, .015), (.96, .05), (1.04, .055)], .004, .002, hexc('#7a5a3a', .9))
    def legs(c, far):
        a = .6 if far else 1
        for i in range(5):
            x = .58+i*.045
            barbel(c, [(x, -.045), (x+.02, -.09), (x-.005+(i-2)*.012, -.15)], .007, .003, hexc('#4a6a7a' if far else '#5a7e8a', a))
        # swimmerets hang from each segment
        for i in range(1, 6):
            x, y = seg[i]
            barbel(c, [(x, y-hw[i]*.8), (x-.012, y-hw[i]-.03), (x-.03, y-hw[i]-.045)], .009, .004, hexc('#7a9aa0', .75*a))
    def claw(c, far):
        col = mix(blue, (0, 0, 0, 1), .3) if far else blue
        dy = .02 if far else 0
        # arm: three segments, elbow bent down then up
        P = [(.7, -.045+dy), (.86, -.115+dy), (1.03, -.1+dy), (1.17, -.045+dy)]
        for i in range(3):
            c.move_to(*P[i]); c.line_to(*P[i+1])
            c.set_source_rgba(*mix(col, (0, 0, 0, 1), .45)); c.set_line_width(.046-.006*i); c.stroke()
            c.move_to(*P[i]); c.line_to(*P[i+1])
            c.set_source_rgba(*col); c.set_line_width(.036-.006*i); c.stroke()
            c.move_to(P[i][0], P[i][1]+.007); c.line_to(P[i+1][0], P[i+1][1]+.007)
            c.set_source_rgba(*blue2[:3], .55); c.set_line_width(.009); c.stroke()
            c.arc(*P[i+1], .016, 0, 6.3); c.set_source_rgba(*hexc('#e07a2a', .9 if not far else .6)); c.fill()
        for i in range(12):
            t = i/11; p = lerp(P[1], P[3], t)
            c.move_to(p[0], p[1]+.012); c.line_to(p[0]-.012, p[1]+.024)
        c.set_source_rgba(*mix(col, (0, 0, 0, 1), .4)); c.set_line_width(.003); c.stroke()
        dark = mix(col, (0, 0, 0, 1), .45)
        # palm (propodus): fat spindle
        palm = [(1.15, -.03+dy), (1.22, .012+dy), (1.32, .03+dy), (1.4, .026+dy), (1.43, .0+dy), (1.38, -.04+dy), (1.27, -.07+dy), (1.17, -.065+dy)]
        crpath(c, palm, True); c.set_source_rgba(*dark); c.set_line_width(.012); c.stroke_preserve(); c.set_source_rgba(*col); c.fill()
        crpath(c, [(1.2, .0+dy), (1.3, .022+dy), (1.39, .018+dy), (1.33, .004+dy), (1.24, -.008+dy)], True)
        c.set_source_rgba(*blue2[:3], .7); c.fill()
        # fixed finger (upper) and movable finger (lower), slightly open
        for pts in ([(1.39, .024+dy), (1.48, .04+dy), (1.58, .045+dy), (1.62, .038+dy), (1.52, .022+dy), (1.42, .006+dy)],
                    [(1.41, -.012+dy), (1.5, -.012+dy), (1.6, .0+dy), (1.63, .01+dy), (1.52, -.03+dy), (1.4, -.036+dy)]):
            crpath(c, pts, True); c.set_source_rgba(*dark); c.set_line_width(.01); c.stroke_preserve()
            c.set_source_rgba(*mix(col, (1, 1, 1, 1), .08)); c.fill()
        c.arc(1.615, .04+dy, .008, 0, 6.3); c.arc(1.625, .008+dy, .008, 0, 6.3); c.set_source_rgba(*hexc('#e07a2a', .95)); c.fill()
    sp.draw(lambda c: claw(c, True))
    sp.draw(lambda c: legs(c, True))
    sp.draw(antenna)
    # tail fan
    def tail(c):
        c.translate(.1, -.02); c.rotate(-.35); c.translate(-.1, .02)
        for pts, a in [([(.1, .02), (-.02, .1), (-.06, .07), (-.05, .0), (.1, -.01)], .85), ([(.1, .01), (-.04, -.02), (-.05, -.07), (.0, -.08), (.1, -.015)], .85), ([(.11, .02), (-.03, .05), (-.04, .02), (.11, .0)], .95)]:
            crpath(c, pts, True); c.set_source_rgba(*hexc('#5a7a82', a)); c.fill_preserve()
            c.set_source_rgba(*hexc('#2a3a40', .6)); c.set_line_width(.003); c.stroke()
        for i in range(8):
            c.move_to(.08, .01); c.line_to(-.04, .1-i*.025)
        c.set_source_rgba(.1, .2, .25, .25); c.set_line_width(.002); c.stroke()
    sp.draw(tail)
    # abdomen segments (back to front so front overlaps)
    def abdomen(c):
        for i in range(len(seg)):
            x, y = seg[i]; w = hw[i]
            c.save(); c.translate(x, y-.005)
            c.scale(1, 1)
            crpath(c, [(-.06, w*.7), (.0, w), (.05, w*.85), (.06, -w*.2), (.03, -w*.95), (-.04, -w*.9), (-.065, -w*.1)], True)
            g = vgrad(c, w, -w, [(0, hexc('#3e5a5e')), (.35, hexc('#7aa0a0')), (.75, hexc('#a8c4bc')), (1, hexc('#8aa8a6'))])
            c.set_source(g); c.fill_preserve()
            c.set_source_rgba(*hexc('#20343a', .7)); c.set_line_width(.004); c.stroke()
            # dark band
            c.move_to(-.03, w*.95); c.curve_to(-.01, 0, -.02, -w*.5, -.035, -w*.9)
            c.set_source_rgba(.1, .18, .2, .35); c.set_line_width(.008); c.stroke()
            c.restore()
    sp.draw(abdomen)
    sp.draw(lambda c: legs(c, False))
    # carapace + rostrum
    def cara(c):
        pts = [(.55, .07), (.65, .085), (.75, .08), (.82, .06), (.88, .07), (.98, .12), (.9, .055), (.86, .02), (.85, -.02), (.78, -.05), (.65, -.06), (.55, -.05)]
        crpath(c, pts, True)
        g = vgrad(c, .09, -.06, [(0, hexc('#3a5660')), (.4, hexc('#6a9298')), (1, hexc('#9cbcb6'))])
        c.set_source(g); c.fill_preserve(); c.set_source_rgba(*hexc('#1e3238', .75)); c.set_line_width(.004); c.stroke()
        # rostrum teeth
        for i in range(7):
            x = .87+i*.016; y = .065+i*.008
            c.move_to(x, y); c.line_to(x+.004, y+.016); c.line_to(x+.012, y+.004)
        c.set_source_rgba(*hexc('#2a4048', .9)); c.set_line_width(.003); c.stroke()
        # carapace groove + stripes
        c.move_to(.6, .06); c.curve_to(.65, .02, .7, .0, .78, .0)
        c.set_source_rgba(.1, .2, .22, .4); c.set_line_width(.005); c.stroke()
        for i in range(4):
            c.move_to(.6+i*.05, .08); c.line_to(.62+i*.05, -.04)
        c.set_source_rgba(.15, .25, .3, .25); c.set_line_width(.006); c.stroke()
        # eye on stalk
        c.move_to(.84, .03); c.line_to(.88, .045); c.set_source_rgba(*hexc('#4a5a5a')); c.set_line_width(.012); c.stroke()
        c.arc(.885, .048, .016, 0, 6.3); c.set_source_rgba(.06, .06, .06, 1); c.fill()
        c.arc(.89, .054, .005, 0, 6.3); c.set_source_rgba(1, 1, 1, .9); c.fill()
    sp.draw(cara)
    sp.draw(lambda c: (c.move_to(.15, .05), c.curve_to(.35, .1, .55, .1, .78, .07), c.set_line_width(.012), c.set_source_rgba(1, 1, 1, .35), c.stroke()), blur=2)
    sp.draw(lambda c: claw(c, False))
    return sp.finish('#1a242a', 1.8)



# ---------- rác vớt lên ----------
def junk(kind):
    sp = Sprite(scale=.86, cx=.07, cy=.5)
    if kind == 'dep':
        def f(c):
            c.save(); c.translate(.5, 0); c.rotate(.12)
            crpath(c, [(-.38, .0), (-.3, .1), (-.05, .1), (.2, .13), (.36, .1), (.4, .0), (.34, -.09), (.1, -.08), (-.15, -.11), (-.33, -.08)], True)
            c.set_source_rgba(*hexc('#e8e2d0')); c.fill_preserve(); c.set_source_rgba(*hexc('#2f6fb0')); c.set_line_width(.035); c.stroke()
            for i in range(40):
                import random; R = random.Random(i)
                c.new_sub_path(); c.arc(R.uniform(-.3, .3), R.uniform(-.07, .08), .008, 0, 6.3)
            c.set_source_rgba(0, 0, 0, .12); c.fill()
            c.move_to(-.02, .1); c.curve_to(.05, .03, .15, .0, .24, .0); c.move_to(-.02, -.1); c.curve_to(.05, -.03, .15, .0, .24, .0)
            c.set_source_rgba(*hexc('#2f6fb0')); c.set_line_width(.04); c.stroke()
            c.arc(.24, 0, .02, 0, 6.3); c.set_source_rgba(*hexc('#1e4a80')); c.fill()
            c.restore()
        sp.draw(f)
        sp.draw(blotches(4, 8, .2, .8, -.1, .1, .01, .03, '#6a5a30', .35), blur=1)
    elif kind == 'lon':
        def f(c):
            c.save(); c.translate(.5, 0); c.rotate(-.35)
            c.rectangle(-.28, -.12, .56, .24)
            c.set_source(vgrad(c, .12, -.12, [(0, hexc('#1e5a2a')), (.3, hexc('#4aa060')), (.55, hexc('#2a7a3a')), (1, hexc('#123a1a'))])); c.fill()
            c.rectangle(-.06, -.12, .2, .24); c.set_source_rgba(*hexc('#e8d070', .9)); c.fill()
            c.rectangle(-.04, -.06, .16, .1); c.set_source_rgba(*hexc('#c8302a', .9)); c.fill()
            for x in (.28,):
                c.save(); c.translate(x, 0); c.scale(.05, .125); c.arc(0, 0, 1, 0, 6.3); c.restore()
                c.set_source_rgba(*hexc('#b8b8b0')); c.fill()
            c.move_to(-.2, .1); c.line_to(-.1, .02); c.line_to(-.16, -.05)
            c.set_source_rgba(0, 0, 0, .3); c.set_line_width(.01); c.stroke()
            c.restore()
        m = sp.mask(lambda c: (f(c), None))
        sp.draw(f)
        sp.draw(blotches(9, 14, .3, .7, -.15, .15, .01, .03, '#8a5a24', .6), blur=.8, clip=m)
    elif kind == 'non':
        def f(c):
            c.save(); c.translate(.5, -.05)
            crpath(c, [(-.42, -.02), (0, .3), (.42, -.02), (.3, -.06), (0, -.08), (-.3, -.06)], True)
            c.set_source(vgrad(c, .3, -.08, [(0, hexc('#f0dca0')), (1, hexc('#b8984e'))])); c.fill_preserve()
            c.set_source_rgba(*hexc('#6a5020', .8)); c.set_line_width(.006); c.stroke()
            for i in range(9):
                t = i/8; c.move_to(0, .3); c.line_to(-.42+.84*t, -.02-.05*math.sin(t*math.pi))
            c.set_source_rgba(.4, .3, .1, .35); c.set_line_width(.004); c.stroke()
            crpath(c, [(.08, .12), (.2, .04), (.16, .0), (.05, .06)], True); c.set_source_rgba(*hexc('#3a2a14', .85)); c.fill()
            c.restore()
        sp.draw(f)
    return sp.finish('#24170b', 2.0)

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    ids = sys.argv[1:] or list(FISH)+['tom', 'dep', 'lon', 'non']
    for k in ids:
        im = tom() if k == 'tom' else junk(k) if k in ('dep', 'lon', 'non') else build(FISH[k])
        im.save(f'{OUT}/fish_{k}.png')
        print('ok', k)
