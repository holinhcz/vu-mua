# ICON ĐỒ NGHỀ THEO CẤP cho Câu cá (Link 11-23 "vẽ icon cho 4 loại cần câu cước phao giỏ tre"):
# cùng kiểu với icon cũ (cau-ca/src/art/icons.py): khối 2.5D, nền phẳng, bóng dưới-phải, sáng trên-trái, viền mực mảnh.
# Màu lấy theo ảnh 6px trong cảnh (bank9/can_phao.py) để icon khớp với đồ đang thấy trên mặt nước.
# python3 ic_gear.py OUTDIR [key ...]   -> OUTDIR/ic-rod0.webp ... (cắt sát, webp lossless)
import cairo, math, sys, os
import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/icg'
os.makedirs(OUT, exist_ok=True)
S = 160            # khung vẽ (đơn vị như icons.py)
K = 1.25           # ảnh ra 200px: icon hiện ~34 css x dpr 4.25 = 145px
INK = (0.24, 0.15, 0.08, 0.85)

def hexc(h):
    h = h.lstrip('#'); return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
def rgb(h, a=1.0):
    return (*hexc(h), a)
def mixh(a, b, t):
    x, y = hexc(a), hexc(b); return '#' + ''.join('%02x' % round((x[i] * (1 - t) + y[i] * t) * 255) for i in range(3))

def new():
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, int(S * K), int(S * K)); c = cairo.Context(s)
    c.scale(K, K); c.set_line_join(cairo.LINE_JOIN_ROUND); c.set_line_cap(cairo.LINE_CAP_ROUND)
    return s, c
def ink(c, w=2.2, col=INK):
    c.set_source_rgba(*col); c.set_line_width(w); c.stroke()
def ground_shadow(c, x, y, rx, ry=None):
    c.save(); c.translate(x, y); c.scale(1, (ry or rx * .22) / rx); c.arc(0, 0, rx, 0, 2 * math.pi); c.restore()
    c.set_source_rgba(.25, .16, .06, .18); c.fill()
def bez(p0, p1, p2, p3, n=40):
    out = []
    for i in range(n + 1):
        t = i / n; u = 1 - t
        out.append((u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                    u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]))
    return out
def cel_disc(c, x, y, r, base, shade, lite, ink_w=2):
    c.arc(x, y, r, 0, 2 * math.pi); c.set_source_rgba(*rgb(base)); c.fill_preserve(); c.save(); c.clip()
    c.arc(x - r * .28, y - r * .3, r * 1.05, 0, 2 * math.pi); c.set_fill_rule(cairo.FILL_RULE_EVEN_ODD)
    c.rectangle(x - r * 2, y - r * 2, r * 4, r * 4); c.set_source_rgba(*rgb(shade)); c.fill(); c.set_fill_rule(cairo.FILL_RULE_WINDING)
    c.save(); c.translate(x - r * .36, y - r * .4); c.rotate(-.6); c.scale(1, .62); c.arc(0, 0, r * .3, 0, 2 * math.pi); c.restore()
    c.set_source_rgba(*rgb(lite, .8)); c.fill()
    c.restore(); c.arc(x, y, r, 0, 2 * math.pi); ink(c, ink_w)

# ------------------------------------------------------------ CẦN CÂU
def ttube(c, pts, ws, cols, ink_w=2.2):
    """ống thon dọc đường gấp khúc: ws[i] = bề ngang tại pts[i]; cols[i] = (base, shade, lite) mỗi đoạn"""
    n = len(pts) - 1
    def seg(i, w, dx=0, dy=0):
        c.move_to(pts[i][0] + dx, pts[i][1] + dy); c.line_to(pts[i + 1][0] + dx, pts[i + 1][1] + dy); c.set_line_width(w); c.stroke()
    for i in range(n):
        c.set_source_rgba(*INK); seg(i, ws[i] + ink_w * 2)
    for i in range(n):
        c.set_source_rgba(*rgb(cols[i][1])); seg(i, ws[i])
    for i in range(n):
        w = ws[i]; c.set_source_rgba(*rgb(cols[i][0])); seg(i, w * .66, -w * .12, -w * .16)
    for i in range(n):
        w = ws[i]; c.set_source_rgba(*rgb(cols[i][2], .9)); seg(i, max(.8, w * .18), -w * .22, -w * .28)

def ring_at(c, pts, i, w, col, wid=3.0, inkw=1.4):
    """vòng quấn/khâu ngang qua thân cần tại điểm i (vuông góc thân)"""
    (x0, y0), (x1, y1) = pts[max(0, i - 1)], pts[min(len(pts) - 1, i + 1)]
    dx, dy = x1 - x0, y1 - y0; L = math.hypot(dx, dy); nx, ny = -dy / L, dx / L
    x, y = pts[i]; h = w / 2 + 1.2
    c.move_to(x - nx * h, y - ny * h); c.line_to(x + nx * h, y + ny * h)
    c.set_source_rgba(*INK); c.set_line_width(wid + inkw * 2); c.stroke()
    c.move_to(x - nx * h, y - ny * h); c.line_to(x + nx * h, y + ny * h)
    c.set_source_rgba(*rgb(col)); c.set_line_width(wid); c.stroke()

def guide_at(c, pts, i, w, col='#9aa0a4'):
    """khoen dẫn dây: chân nhỏ + vòng tròn phía dưới thân"""
    (x0, y0), (x1, y1) = pts[max(0, i - 1)], pts[min(len(pts) - 1, i + 1)]
    dx, dy = x1 - x0, y1 - y0; L = math.hypot(dx, dy); nx, ny = dy / L, -dx / L      # phía dưới-phải
    x, y = pts[i]; d = w / 2 + 3.2
    c.move_to(x, y); c.line_to(x + nx * d, y + ny * d); c.set_source_rgba(*rgb('#4a4448')); c.set_line_width(1.6); c.stroke()
    c.arc(x + nx * (d + 2.2), y + ny * (d + 2.2), 2.4, 0, 6.3); c.set_source_rgba(*rgb(col)); c.set_line_width(1.5); c.stroke()

def reel(c, x, y, r, c1, c2, holes, knob, hub, metal=False):
    cel_disc(c, x, y, r, c1, c2, mixh(c1, '#ffffff', .45 if metal else .3))
    c.arc(x, y, r * .72, 0, 6.3); c.set_source_rgba(*rgb(c2, .55)); c.set_line_width(1.3); c.stroke()
    for k in range(holes):
        a = k * 2 * math.pi / holes - .5
        c.arc(x + math.cos(a) * r * .48, y + math.sin(a) * r * .48, r * .13, 0, 6.3); c.set_source_rgba(*rgb(mixh(c2, '#000000', .45))); c.fill()
    c.arc(x, y, r * .24, 0, 6.3); c.set_source_rgba(*rgb(hub)); c.fill_preserve(); ink(c, 1.2)
    # tay quay
    a = 2.2; kx, ky = x + math.cos(a) * r * .9, y + math.sin(a) * r * .9
    c.move_to(x, y); c.line_to(kx, ky); c.set_source_rgba(*rgb(hub)); c.set_line_width(2.6); c.stroke()
    c.arc(kx, ky, 3.4, 0, 6.3); c.set_source_rgba(*rgb(knob)); c.fill_preserve(); ink(c, 1.2)

RODS = [
    # thân (gốc->ngọn), mắt tre, cán quấn, nắp đuôi, khoen, khâu, ống cước
    dict(body=('#d9b874', '#a88440', '#f6e6b0'), tip=('#b88a48', '#8a5e2a', '#e8c890'), node='#8a5a2a', nodes=4,
         grip=('#6a4426', '#4a2c14', '#9a6a40'), wrap='#5a3a1e', wraps=5, cap=None, guides=0, ferr=[], w0=14, w1=5,
         reel=('#9a6436', '#6e4222', 4, '#5a361a', '#c9a24a', False)),
    dict(body=('#9a6434', '#6a3e1c', '#c89060'), tip=('#6e4422', '#4a2a10', '#a07040'), node='#3e220e', nodes=4,
         grip=('#d2a45e', '#9a7234', '#f0d090'), wrap='#8a5e2a', wraps=7, cap=None, guides=0, ferr=[], w0=15, w1=5.2,
         reel=('#6c4220', '#40240e', 4, '#2e1a0c', '#b08a3a', False)),
    dict(body=('#9a3622', '#6a2014', '#d07a5a'), tip=('#8a3020', '#5e1c10', '#c06a4a'), node=None, nodes=0,
         grip=('#7a4426', '#4e2814', '#a8704a'), wrap='#c99a42', wraps=2, cap='#c99a42', guides=5, ferr=[.42, .7], w0=15, w1=5,
         reel=('#b4b8ba', '#7c8286', 6, '#3a2a22', '#c9a24a', True)),
    dict(body=('#3a302a', '#1e1814', '#7a6a5e'), tip=('#2e2622', '#181210', '#6a5a50'), node=None, nodes=0,
         grip=('#2a1814', '#140c08', '#5a4034'), wrap='#dcb24a', wraps=6, cap='#dcb24a', guides=6, ferr=[.4, .66], w0=16, w1=5.4,
         reel=('#d0a448', '#94702a', 5, '#33241a', '#e8dcc0', True), gold=True),
]

def rod(cf):
    s, c = new()
    N = 30
    pts = bez((20, 144), (62, 98), (106, 50), (146, 12), N)
    ws = [cf['w0'] + (cf['w1'] - cf['w0']) * (i / (N - 1)) for i in range(N)]
    g = 9                                   # cán: đoạn 0..g
    cols = [cf['grip'] if i < g else (cf['body'] if i < N * .62 else cf['tip']) for i in range(N)]
    ttube(c, pts, ws, cols)
    # quấn cán
    for k in range(cf['wraps']):
        i = 1 + round(k * (g - 2) / max(1, cf['wraps'] - 1)) if cf['wraps'] > 2 else (1, g - 1)[k]
        ring_at(c, pts, i, ws[i], cf['wrap'], 2.2 if cf['wraps'] > 2 else 3.4)
    ring_at(c, pts, g, ws[g], cf['wrap'] if cf['cap'] is None else cf['cap'], 3.0)
    # mắt tre
    for k in range(cf['nodes']):
        i = g + 3 + k * 5
        ring_at(c, pts, i, ws[i], cf['node'], 1.6, .6)
    # chỉ vàng quấn thân (cần ông Năm)
    if cf.get('gold'):
        for i in range(g + 2, N - 3, 3):
            ring_at(c, pts, i, ws[i], '#dcb24a', 1.2, .5)
    for f in cf['ferr']:
        i = round(f * N); ring_at(c, pts, i, ws[i], '#c99a42', 3.6)
    # khoen
    for k in range(cf['guides']):
        i = g + 3 + round(k * (N - g - 5) / max(1, cf['guides'] - 1))
        guide_at(c, pts, i, ws[i])
    # nắp đuôi đồng
    if cf['cap']:
        x, y = pts[0]
        c.arc(x - 1, y + 1, ws[0] * .55, 0, 6.3); c.set_source_rgba(*rgb(cf['cap'])); c.fill_preserve(); ink(c, 1.6)
    # ống cước
    c1, c2, holes, knob, hub, metal = cf['reel']
    x, y = pts[g + 1]
    reel(c, x + 14, y + 10, 15, c1, c2, holes, knob, hub, metal)
    # dây
    x, y = pts[-1]
    c.move_to(x, y); c.curve_to(x + 8, y + 34, x - 2, y + 74, x - 10, y + 104); c.set_source_rgba(1, 1, 1, .9); c.set_line_width(1.6); c.stroke()
    return s

ICONS = {f'rod{i}': (lambda cf=cf: rod(cf)) for i, cf in enumerate(RODS)}

# ------------------------------------------------------------ CƯỚC (ống chỉ gỗ quấn dây; màu dây = LINE_C trong cc_draw)
LINES = [
    dict(wood=('#c88a4a', '#a86a34'), ln=('#f4f2ea', '#c8c8c0', '#ffffff'), pitch=4.0, lw=1.0, braid=False),
    dict(wood=('#b87a3e', '#8e5a2a'), ln=('#cfe6f0', '#8ab8cc', '#ffffff'), pitch=5.0, lw=1.3, braid=False),
    dict(wood=('#8e5a2e', '#6a3e1c'), ln=('#a8d8a8', '#5e9e66', '#e0f6d8'), pitch=6.0, lw=1.6, braid=False),
    dict(wood=('#6c4220', '#40240e'), ln=('#9a6a3a', '#6a4422', '#c8945a'), pitch=7.0, lw=2.0, braid=True),
]
def line(cf):
    s, c = new()
    ground_shadow(c, 80, 140, 52)
    top, bot, X0, X1, R = 34, 122, 44, 116, 46
    lb, ls, ll = cf['ln']
    # đáy ống
    c.save(); c.translate(80, bot); c.scale(1, .3); c.arc(0, 0, R, 0, 6.3); c.restore()
    c.set_source_rgba(*rgb(cf['wood'][1])); c.fill_preserve(); ink(c)
    # cuộn dây
    c.rectangle(X0, top, X1 - X0, bot - top); c.set_source_rgba(*rgb(lb)); c.fill()
    c.save(); c.rectangle(X0, top, X1 - X0, bot - top); c.clip()
    c.rectangle(X1 - 22, top, 22, bot - top); c.set_source_rgba(*rgb(ls)); c.fill()
    y = top + 2
    while y < bot + 4:
        if cf['braid']:
            # dây dù bện: vân chữ V nối nhau
            for x in range(X0 - 4, X1 + 4, 7):
                c.move_to(x, y); c.line_to(x + 3.5, y + cf['pitch'] * .5); c.line_to(x + 7, y)
            c.set_source_rgba(*rgb(mixh(ls, '#000000', .3), .8)); c.set_line_width(1.3); c.stroke()
        c.move_to(X0, y); c.curve_to(64, y + 3, 96, y + 3, X1, y)
        c.set_source_rgba(*rgb(mixh(ls, '#000000', .25), .6)); c.set_line_width(cf['lw']); c.stroke()
        y += cf['pitch']
    c.rectangle(X0 + 7, top, 9, bot - top); c.set_source_rgba(*rgb(ll, .75)); c.fill()
    c.restore()
    c.move_to(X0, top); c.line_to(X0, bot); c.move_to(X1, top); c.line_to(X1, bot); ink(c)
    # mặt ống trên
    c.save(); c.translate(80, top); c.scale(1, .3); c.arc(0, 0, R, 0, 6.3); c.restore()
    c.set_source_rgba(*rgb(cf['wood'][0])); c.fill_preserve(); ink(c)
    c.save(); c.translate(80, top); c.scale(1, .3); c.arc(0, 0, R - 8, 0, 6.3); c.restore()
    c.set_source_rgba(*rgb(mixh(cf['wood'][0], '#ffffff', .2), .6)); c.set_line_width(1.4); c.stroke()
    c.save(); c.translate(80, top); c.scale(1, .3); c.arc(0, 0, 10, 0, 6.3); c.restore(); c.set_source_rgba(*rgb('#3a2010')); c.fill()
    # đầu dây thả + lưỡi câu
    c.move_to(X1, 84); c.curve_to(138, 88, 136, 112, 138, 124)
    c.set_source_rgba(*INK); c.set_line_width(cf['lw'] + 2.2); c.stroke()
    c.move_to(X1, 84); c.curve_to(138, 88, 136, 112, 138, 124)
    c.set_source_rgba(*rgb(lb)); c.set_line_width(cf['lw'] + .8); c.stroke()
    c.move_to(138, 122); c.line_to(138, 138); c.arc_negative(132, 138, 6, 0, math.pi * .9)
    c.set_source_rgba(*rgb('#6a6a72')); c.set_line_width(3); c.stroke()
    return s

# ------------------------------------------------------------ PHAO (khúc màu từ dưới lên như can_phao.py FLOATS)
FLOS = [
    dict(bands=['#f2efe6', '#2a2a2a', '#f2efe6', '#2a2a2a', '#e8402a', '#ff6a2a'], bulb=None, eye=False),
    dict(bands=['#2a7a5a', '#e8e0c8', '#2a4aa0', '#e8e0c8', '#e84a2a', '#f8d040'], bulb=None, eye=True),
    dict(bands=['#f2efe6', '#2a2a2a', '#f2efe6', '#2a2a2a', '#e8402a', '#ff6a2a'], bulb='#9adc4a', eye=False),
]
def flo(cf):
    s, c = new()
    WL = 104                                # mặt nước
    top = 22 if cf['bulb'] else 10
    # thân bấc dưới nước (mờ)
    def spindle(y0, y1, w):
        c.move_to(80, y0); c.curve_to(80 + w, y0 + (y1 - y0) * .3, 80 + w, y0 + (y1 - y0) * .7, 80, y1)
        c.curve_to(80 - w, y0 + (y1 - y0) * .7, 80 - w, y0 + (y1 - y0) * .3, 80, y0); c.close_path()
    spindle(WL - 18, 150, 22); c.set_source_rgba(*rgb('#d8b878')); c.fill_preserve(); c.save(); c.clip()
    c.rectangle(80, 0, 20, S); c.set_source_rgba(*rgb('#b0904e')); c.fill(); c.restore()
    spindle(WL - 18, 150, 22); ink(c, 2)
    # nước phủ phần dưới: mờ dần xuống, không có mép cứng
    c.save(); spindle(WL - 18, 151, 23.5); c.clip()
    g = cairo.LinearGradient(0, WL, 0, 150); g.add_color_stop_rgba(0, .55, .78, .84, .55); g.add_color_stop_rgba(1, .55, .78, .84, .8)
    c.rectangle(0, WL, S, 60); c.set_source(g); c.fill(); c.restore()
    # cọng lông: thon dần lên, chia khúc
    bands = cf['bands']; n = len(bands); y0 = WL - 6; h = (y0 - top) / n
    def stem():
        c.move_to(80 - 10, y0); c.line_to(80 - 5.2, top + 4); c.curve_to(80 - 4.4, top - 2, 80 + 4.4, top - 2, 80 + 5.2, top + 4); c.line_to(80 + 10, y0); c.close_path()
    stem(); c.set_source_rgba(*rgb(bands[0])); c.fill_preserve(); c.save(); c.clip()
    for i, b in enumerate(bands):
        yb = y0 - (i + 1) * h
        c.rectangle(60, yb - .5, 40, h + 1); c.set_source_rgba(*rgb(b)); c.fill()
        c.rectangle(82, yb - .5, 12, h + 1); c.set_source_rgba(*rgb(mixh(b, '#000000', .28))); c.fill()
    c.move_to(75, y0); c.line_to(77.4, top + 5); c.set_source_rgba(1, 1, 1, .5); c.set_line_width(2.6); c.stroke()
    c.restore(); stem(); ink(c, 1.8)
    if cf['eye']:
        # mắt lông công ở khúc xanh lam
        yb = y0 - 2.5 * h
        c.save(); c.translate(80, yb); c.scale(1, 1.35)
        for r, col in ((12, '#2a7a5a'), (8.4, '#2a4aa0'), (4, '#1a1a40')):
            c.arc(0, 0, r, 0, 6.3); c.set_source_rgba(*rgb(col)); c.fill()
        c.restore()
        c.save(); c.translate(80, yb); c.scale(1, 1.35); c.arc(0, 0, 12, 0, 6.3); c.restore(); ink(c, 1.4)
    if cf['bulb']:
        for r, a in ((24, .18), (17, .28)):
            c.arc(80, top - 6, r, 0, 6.3); c.set_source_rgba(*rgb(cf['bulb'], a)); c.fill()
        cel_disc(c, 80, top - 6, 11, cf['bulb'], '#5aa02a', '#f0ffd0', 1.8)
    # gợn nước
    for r, a in ((46, .55), (30, .8)):
        c.save(); c.translate(80, WL); c.scale(1, .26); c.arc(0, 0, r, 0, 6.3); c.restore()
        c.set_source_rgba(.32, .58, .7, a); c.set_line_width(2.5); c.stroke()
    return s

# ------------------------------------------------------------ GIỎ
def weave_body(c, path, base, shade, lite, rows, cols, lx):
    path(); c.set_source_rgba(*rgb(base)); c.fill_preserve(); c.save(); c.clip()
    c.arc(lx, 82, 70, 0, 6.3); c.set_fill_rule(cairo.FILL_RULE_EVEN_ODD); c.rectangle(0, 0, S, S); c.set_source_rgba(*rgb(shade)); c.fill(); c.set_fill_rule(cairo.FILL_RULE_WINDING)
    for y in rows:
        c.move_to(6, y); c.curve_to(60, y + 6, 100, y + 6, 154, y); c.set_source_rgba(*rgb(mixh(shade, '#000000', .2), .7)); c.set_line_width(1.6); c.stroke()
    for x0, x1 in cols:
        c.move_to(x0, 40); c.curve_to(x0 + (x1 - x0) * .4, 80, x1, 120, x1, 146); c.set_source_rgba(*rgb(lite, .6)); c.set_line_width(2.2); c.stroke()
    c.save(); c.translate(lx - 4, 80); c.rotate(-.35); c.scale(.6, 1.6); c.arc(0, 0, 9, 0, 6.3); c.restore(); c.set_source_rgba(*rgb(lite, .65)); c.fill()
    c.restore(); path(); ink(c)

def tail(c, x, y, ang, col='#8aa0a8'):
    c.save(); c.translate(x, y); c.rotate(ang)
    c.move_to(0, 0); c.line_to(-8, -18); c.line_to(0, -13); c.line_to(8, -18); c.close_path()
    c.set_source_rgba(*rgb(col)); c.fill_preserve(); ink(c, 1.8); c.restore()

def cage0():
    s, c = new()
    ground_shadow(c, 80, 140, 44)
    def body():
        c.move_to(64, 48); c.curve_to(32, 66, 32, 132, 60, 140); c.line_to(100, 140); c.curve_to(128, 132, 128, 66, 96, 48); c.close_path()
    weave_body(c, body, '#d8b066', '#a07a38', '#f0d48a', range(54, 142, 9), [(80 + i * 4, 80 + i * 6) for i in range(-6, 7)], 66)
    c.move_to(64, 48); c.line_to(66, 34); c.line_to(94, 34); c.line_to(96, 48); c.close_path(); c.set_source_rgba(*rgb('#c49a52')); c.fill_preserve(); ink(c, 2)
    c.save(); c.translate(80, 32); c.scale(1, .3); c.arc(0, 0, 19, 0, 6.3); c.restore(); c.set_source_rgba(*rgb('#e0bc70')); c.fill_preserve(); ink(c, 2)
    c.save(); c.translate(80, 32); c.scale(1, .3); c.arc(0, 0, 11, 0, 6.3); c.restore(); c.set_source_rgba(*rgb('#4a3014')); c.fill()
    c.move_to(66, 38); c.curve_to(44, 8, 116, 8, 94, 38); c.set_source_rgba(*rgb('#6a4a24')); c.set_line_width(2.6); c.stroke()
    tail(c, 82, 27, .25)
    return s

def cage1():
    s, c = new()
    ground_shadow(c, 80, 142, 64)
    def body():
        c.move_to(56, 44); c.curve_to(6, 60, 8, 136, 48, 142); c.line_to(112, 142); c.curve_to(152, 136, 154, 60, 104, 44); c.close_path()
    weave_body(c, body, '#c89a52', '#8e6a2e', '#e8c47a', range(50, 144, 8), [(80 + i * 4.4, 80 + i * 8.6) for i in range(-8, 9)], 56)
    # đai tre ngang (cắt theo thân)
    c.save(); body(); c.clip()
    for y in (78, 116):
        c.move_to(0, y); c.curve_to(56, y + 9, 104, y + 9, 160, y); c.set_source_rgba(*INK); c.set_line_width(6.4); c.stroke()
        c.move_to(0, y); c.curve_to(56, y + 9, 104, y + 9, 160, y); c.set_source_rgba(*rgb('#7a5424')); c.set_line_width(4); c.stroke()
        c.move_to(0, y - 1); c.curve_to(56, y + 8, 104, y + 8, 160, y - 1); c.set_source_rgba(*rgb('#b0844a')); c.set_line_width(1.2); c.stroke()
    c.restore(); body(); ink(c)
    c.move_to(56, 44); c.line_to(58, 30); c.line_to(102, 30); c.line_to(104, 44); c.close_path(); c.set_source_rgba(*rgb('#b88a44')); c.fill_preserve(); ink(c, 2)
    c.save(); c.translate(80, 28); c.scale(1, .3); c.arc(0, 0, 27, 0, 6.3); c.restore(); c.set_source_rgba(*rgb('#d8b066')); c.fill_preserve(); ink(c, 2)
    c.save(); c.translate(80, 28); c.scale(1, .3); c.arc(0, 0, 17, 0, 6.3); c.restore(); c.set_source_rgba(*rgb('#4a3014')); c.fill()
    c.move_to(58, 36); c.curve_to(30, 0, 130, 0, 102, 36); c.set_source_rgba(*rgb('#6a4a24')); c.set_line_width(3); c.stroke()
    tail(c, 72, 24, -.3); tail(c, 90, 22, .35, '#a8b0a0')
    return s

def cage2():
    s, c = new()
    ground_shadow(c, 80, 144, 56)
    X0, X1, top, bot = 30, 130, 34, 136
    rings = [top, 68, 102, bot]
    def body():
        c.move_to(X0, top); c.line_to(X0, bot); c.line_to(X1, bot); c.line_to(X1, top); c.close_path()
    # đáy
    c.save(); c.translate(80, bot); c.scale(1, .28); c.arc(0, 0, 50, 0, 6.3); c.restore(); c.set_source_rgba(*rgb('#3e5a48')); c.fill()
    # thân lưới: mắt lưới thoi
    c.save(); body(); c.clip()
    c.rectangle(X0, top, X1 - X0, bot - top); c.set_source_rgba(*rgb('#cfe6d4', .7)); c.fill()
    c.rectangle(X1 - 30, top, 30, bot - top); c.set_source_rgba(*rgb('#3e5a48', .25)); c.fill()
    # cá bên trong
    c.save(); c.translate(76, 110); c.scale(1, .55); c.arc(0, 0, 22, 0, 6.3); c.restore(); c.set_source_rgba(*rgb('#8aa0a8', .8)); c.fill()
    for k in range(-14, 16):
        x = 80 + k * 7
        c.move_to(x - 40, top); c.line_to(x + 40, bot); c.move_to(x + 40, top); c.line_to(x - 40, bot)
    c.set_source_rgba(*rgb('#3e7a5a', .85)); c.set_line_width(1.4); c.stroke()
    c.restore()
    c.move_to(X0, top); c.line_to(X0, bot); c.move_to(X1, top); c.line_to(X1, bot); ink(c)
    # vành mây
    for y in rings:
        c.save(); c.translate(80, y); c.scale(1, .28); c.arc(0, 0, 50, 0 if y == top else 0, 6.3 if y == top else math.pi); c.restore()
        c.set_source_rgba(*INK); c.set_line_width(6.4); c.stroke_preserve(); c.set_source_rgba(*rgb('#c8944a')); c.set_line_width(4); c.stroke()
    c.save(); c.translate(80, top); c.scale(1, .28); c.arc(0, 0, 50, math.pi, 2 * math.pi); c.restore()
    c.set_source_rgba(*rgb('#e0b060')); c.set_line_width(2); c.stroke()
    # dây rút + quai
    c.move_to(36, top - 2); c.curve_to(30, -4, 130, -4, 124, top - 2); c.set_source_rgba(*rgb('#6a4a24')); c.set_line_width(3); c.stroke()
    return s

ICONS.update({f'line{i}': (lambda cf=cf: line(cf)) for i, cf in enumerate(LINES)})
ICONS.update({f'flo{i}': (lambda cf=cf: flo(cf)) for i, cf in enumerate(FLOS)})
ICONS.update(cage0=cage0, cage1=cage1, cage2=cage2)

def save(s, path):
    a = np.ndarray((s.get_height(), s.get_width(), 4), np.uint8, s.get_data()).copy()
    im = Image.fromarray(a[..., [2, 1, 0, 3]], 'RGBA')
    # cairo cho màu nhân alpha sẵn -> trả về màu thật
    arr = np.asarray(im).astype(np.float32); al = arr[..., 3:4] / 255
    arr[..., :3] = np.where(al > 0, np.clip(arr[..., :3] / np.maximum(al, 1e-6), 0, 255), 0)
    im = Image.fromarray(arr.astype(np.uint8), 'RGBA')
    bb = im.getbbox(); im = im.crop((max(0, bb[0] - 2), max(0, bb[1] - 2), min(im.width, bb[2] + 2), min(im.height, bb[3] + 2)))
    im.save(path, lossless=True, quality=100)

if __name__ == '__main__':
    for k in (sys.argv[2:] or ICONS):
        save(ICONS[k](), os.path.join(OUT, f'ic-{k}.webp'))
    print('ok', OUT)
