# (11-25) Bộ trang trí "sen" cho khung tre chung: đỉnh khung, đáy khung, nút đóng, dây tua, hoa sen vàng (tab), mây hồng,
# hoa sen nét chìm trên nền giấy. Vẽ vector (cairo) ở P điểm ảnh / css px rồi lưu webp không mất nét: Godot thu đúng số
# điểm ảnh khi vẽ (Css.svg_tex), zoom nào cũng nét.
#   python3 lam.py OUTDIR
import math, sys, os
import cairo
from PIL import Image
import numpy as np

P = 6            # điểm ảnh / css px
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'

RED = ['#f0636a', '#d83443', '#b01f30', '#86121f']        # đỏ son: sáng -> tối
GOLD = ['#fff3b8', '#ffd864', '#e8b23a', '#b07a1c', '#7a520e']
PINK = ['#fde3e8', '#f8c3cf', '#f1a2b5', '#e07b96']


def C(h, a=1.0):
    h = h.lstrip('#')
    return (int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255, a)


def surf(w, h):   # w, h: css px
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, int(round(w * P)), int(round(h * P)))
    c = cairo.Context(s)
    c.scale(P, P)
    c.set_line_join(cairo.LINE_JOIN_ROUND)
    c.set_line_cap(cairo.LINE_CAP_ROUND)
    return s, c


def save(s, name):
    s.flush()
    w, h = s.get_width(), s.get_height()
    a = np.ndarray((h, w, 4), np.uint8, s.get_data()).copy()
    im = Image.frombuffer('RGBa', (w, h), a[:, :, [2, 1, 0, 3]].tobytes(), 'raw', 'RGBa', 0, 1).convert('RGBA')
    im.save(os.path.join(OUT, name + '.webp'), lossless=True, quality=100, method=6)
    return im


def lin(c, x0, y0, x1, y1, stops):
    g = cairo.LinearGradient(x0, y0, x1, y1)
    for t, col in stops:
        g.add_color_stop_rgba(t, *C(col))
    return g


def gold_fill(c, y0, y1):
    return lin(c, 0, y0, 0, y1, [(0, GOLD[0]), (0.35, GOLD[1]), (0.7, GOLD[2]), (1, GOLD[3])])


def red_fill(c, y0, y1):
    return lin(c, 0, y0, 0, y1, [(0, RED[0]), (0.45, RED[1]), (1, RED[3])])


# ------------------------------------------------------------------ hoa sen vàng kim (huy hiệu): 5 cánh + 2 cánh ngoài
def lotus_gold(c, cx, by, s, fill=None, edge=None, lw=None):
    """cx, by: giữa chân hoa; s: cao hoa (css px)"""
    def petal(ang, L, W):
        c.save(); c.translate(cx, by); c.rotate(ang)
        c.move_to(0, 0)
        c.curve_to(-W, -L * 0.25, -W * 0.9, -L * 0.75, 0, -L)
        c.curve_to(W * 0.9, -L * 0.75, W, -L * 0.25, 0, 0)
        c.close_path(); c.restore()
    shapes = [(-1.25, 0.62, 0.2), (1.25, 0.62, 0.2), (-0.62, 0.86, 0.24), (0.62, 0.86, 0.24), (0.0, 1.0, 0.27)]
    for ang, L, W in shapes:
        petal(ang, s * L, s * W)
        c.set_source(fill if fill is not None else gold_fill(c, by - s, by))
        c.fill_preserve()
        c.set_source_rgba(*C(edge or GOLD[4]))
        c.set_line_width(lw or s * 0.06)
        c.stroke()
        # gân giữa cánh
    c.save(); c.translate(cx, by)
    c.move_to(-s * 0.42, s * 0.02); c.curve_to(-s * 0.2, s * 0.14, s * 0.2, s * 0.14, s * 0.42, s * 0.02)
    c.set_source_rgba(*C(edge or GOLD[4])); c.set_line_width(lw or s * 0.06); c.stroke()
    c.restore()


def emblem_tab():   # hoa sen vàng nhỏ dưới tab đang chọn
    s, c = surf(26, 14)
    lotus_gold(c, 13, 12.6, 11.5, lw=0.75)
    save(s, 'tab_sen')


# ------------------------------------------------------------------ hình chóp kiểu "ogee" (đỉnh nhọn, hai vai cong)
def ogee(c, cx, base, w, h):   # chóp vòm nhọn kiểu đình (hai vai tròn, đỉnh nhọn nhẹ)
    c.move_to(cx - w / 2, base)
    c.curve_to(cx - w / 2, base - h * 0.62, cx - w * 0.2, base - h * 0.78, cx - w * 0.04, base - h * 0.94)
    c.curve_to(cx - w * 0.015, base - h * 0.97, cx, base - h, cx, base - h)
    c.curve_to(cx, base - h, cx + w * 0.015, base - h * 0.97, cx + w * 0.04, base - h * 0.94)
    c.curve_to(cx + w * 0.2, base - h * 0.78, cx + w / 2, base - h * 0.62, cx + w / 2, base)
    c.close_path()


def curl(c, x, y, r, d):   # cuộn mây vàng ở vai chóp
    c.new_sub_path()
    for i in range(40):
        t = i / 39 * 1.6 * math.pi
        rr = r * (1 - t / (2.2 * math.pi))
        px, py = x + d * math.cos(t + math.pi) * rr, y + math.sin(t + math.pi) * rr
        (c.move_to if i == 0 else c.line_to)(px, py)


def cloud_curl(c, x, y, r, d):   # cuộn mây nhỏ (d = 1 cuộn sang phải, -1 sang trái)
    c.new_sub_path()
    c.arc(x, y, r, 0, 2 * math.pi)


def band(c, x0, x1, y, h, tip):   # dải đỏ ngang thon hai đầu, đầu cuộn
    c.move_to(x0 + tip, y - h / 2)
    c.line_to(x1 - tip, y - h / 2)
    c.curve_to(x1 - tip * 0.2, y - h / 2, x1, y - h * 0.15, x1, y + h * 0.05)
    c.curve_to(x1, y + h * 0.42, x1 - tip * 0.5, y + h / 2, x1 - tip, y + h / 2)
    c.line_to(x0 + tip, y + h / 2)
    c.curve_to(x0 + tip * 0.5, y + h / 2, x0, y + h * 0.42, x0, y + h * 0.05)
    c.curve_to(x0, y - h * 0.15, x0 + tip * 0.2, y - h / 2, x0 + tip, y - h / 2)
    c.close_path()


def waves_on(c, x0, x1, y, h, col):   # hoa văn sóng mây trên dải đỏ
    c.save()
    n = int((x1 - x0) / 7)
    for i in range(n):
        cx = x0 + (i + 0.5) * (x1 - x0) / n
        for rr in (h * 0.34, h * 0.2):
            c.new_sub_path(); c.arc(cx, y + h * 0.5, rr, math.pi, 2 * math.pi)
    c.set_source_rgba(*col); c.set_line_width(0.55); c.stroke()
    c.restore()


def crest(name, W, Hh, med_w, med_h, band_h, flip=False):
    """đỉnh (flip=False) / đáy (flip=True) khung: dải đỏ ngang + chóp giữa có hoa sen vàng. Neo: giữa dải = mép khung."""
    s, c = surf(W, Hh)
    if flip:
        c.translate(0, Hh); c.scale(1, -1)
    by = Hh - band_h / 2 - 1.2          # giữa dải
    cx = W / 2
    sh = 1.0
    # bóng
    c.save(); c.translate(0, 0.9)
    band(c, 1.5, W - 1.5, by, band_h, band_h * 1.1); ogee(c, cx, by + band_h * 0.2, med_w, med_h)
    c.set_source_rgba(0.25, 0.08, 0.02, 0.28); c.fill(); c.restore()
    # dải đỏ viền vàng
    band(c, 1.5, W - 1.5, by, band_h, band_h * 1.1)
    c.set_source(red_fill(c, by - band_h / 2, by + band_h / 2)); c.fill_preserve()
    c.set_source(gold_fill(c, by - band_h / 2, by + band_h / 2)); c.set_line_width(1.5); c.stroke()
    waves_on(c, 6, W - 6, by - band_h / 2, band_h, C('#ffb0b8', 0.55))
    # chóp giữa
    ogee(c, cx, by + band_h * 0.2, med_w, med_h)
    c.set_source(red_fill(c, by - med_h, by)); c.fill_preserve()
    c.set_source(gold_fill(c, by - med_h, by)); c.set_line_width(1.8); c.stroke()
    ogee(c, cx, by + band_h * 0.2 - 1.6, med_w - 5.5, med_h - 4.2)
    c.set_source_rgba(*C(GOLD[1], 0.85)); c.set_line_width(0.6); c.stroke()
    for d in (-1, 1):   # cuộn mây hai vai
        curl(c, cx + d * (med_w / 2 + 3.2), by - band_h * 0.55, 3.4, d)
        c.set_source(gold_fill(c, by - 8, by)); c.set_line_width(1.5); c.stroke()
    # hoa sen vàng
    if flip:
        c.save(); c.translate(0, by * 2 - med_h * 0.52); c.scale(1, -1)
        lotus_gold(c, cx, by - med_h * 0.18, med_h * 0.5, lw=0.7)
        c.restore()
    else:
        lotus_gold(c, cx, by - med_h * 0.2, med_h * 0.52, lw=0.7)
    # nút vàng hai đầu dải
    for x in (band_h * 0.9, W - band_h * 0.9):
        c.new_sub_path(); c.arc(x, by, band_h * 0.22, 0, 2 * math.pi)
        c.set_source(gold_fill(c, by - 2, by + 2)); c.fill()
    save(s, name)


# ------------------------------------------------------------------ nút đóng: tròn đỏ son, vòng vàng
def close_btn():
    s, c = surf(36, 36)
    cx = cy = 18
    c.arc(cx, cy + 0.8, 16.6, 0, 2 * math.pi); c.set_source_rgba(0.25, 0.06, 0.02, 0.32); c.fill()
    c.arc(cx, cy, 16.6, 0, 2 * math.pi); c.set_source(gold_fill(c, 2, 34)); c.fill()
    c.arc(cx, cy, 13.8, 0, 2 * math.pi)
    g = cairo.RadialGradient(cx - 4, cy - 6, 1, cx, cy, 15)
    g.add_color_stop_rgba(0, *C(RED[0])); g.add_color_stop_rgba(0.55, *C(RED[1])); g.add_color_stop_rgba(1, *C(RED[3]))
    c.set_source(g); c.fill()
    c.arc(cx, cy, 13.8, 0, 2 * math.pi); c.set_source_rgba(*C(GOLD[4], 0.8)); c.set_line_width(0.7); c.stroke()
    c.save(); c.arc(cx, cy, 12.6, 0, 2 * math.pi); c.clip()
    c.arc(cx, cy - 9, 11, 0, 2 * math.pi); c.set_source_rgba(1, 1, 1, 0.18); c.fill(); c.restore()
    save(s, 'dong')


# ------------------------------------------------------------------ dây tua đỏ (nút thắt + tua)
def tassel():
    s, c = surf(16, 60)
    cx = 8
    c.move_to(cx, 0); c.line_to(cx, 7); c.set_source_rgba(*C(RED[2])); c.set_line_width(1.2); c.stroke()
    # nút thắt: ô trám đan, 4 vòng tai
    k = 9.0
    for (dx, dy) in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        c.new_sub_path(); c.arc(cx + dx * 4.2, 14 + dy * 4.2, 2.3, 0, 2 * math.pi)
    c.set_source(red_fill(c, 8, 20)); c.fill_preserve(); c.set_source_rgba(*C(RED[3])); c.set_line_width(0.6); c.stroke()
    c.save(); c.translate(cx, 14); c.rotate(math.pi / 4)
    c.rectangle(-3.6, -3.6, 7.2, 7.2); c.set_source(red_fill(c, -4, 4)); c.fill_preserve()
    c.set_source_rgba(*C(RED[3])); c.set_line_width(0.6); c.stroke()
    for t in (-1.2, 1.2):
        c.move_to(t, -3.6); c.line_to(t, 3.6); c.move_to(-3.6, t); c.line_to(3.6, t)
    c.set_source_rgba(*C('#ff9aa2', 0.7)); c.set_line_width(0.5); c.stroke()
    c.restore()
    # hạt vàng
    c.arc(cx, 23.5, 2.2, 0, 2 * math.pi); c.set_source(gold_fill(c, 21, 26)); c.fill()
    # đầu tua + sợi
    c.move_to(cx - 2.2, 26); c.line_to(cx + 2.2, 26); c.line_to(cx + 2.6, 29); c.line_to(cx - 2.6, 29); c.close_path()
    c.set_source(gold_fill(c, 26, 29)); c.fill()
    for i in range(11):
        t = (i - 5) / 5.0
        c.move_to(cx + t * 2.4, 29); c.curve_to(cx + t * 2.9, 40, cx + t * 3.4, 50, cx + t * 3.6, 58.5)
    c.set_source(red_fill(c, 29, 58)); c.set_line_width(0.55); c.stroke()
    save(s, 'tua')


# ------------------------------------------------------------------ mây sóng hồng (góc đáy nền giấy)
def clouds():
    s, c = surf(140, 46)
    rows = [(46, 26, PINK[1], 0.75), (40, 20, PINK[2], 0.55), (34, 14, PINK[3], 0.35)]
    import random; random.seed(5)
    for (base, rr, col, a) in [(46, 22, PINK[0], 0.95), (44, 17, PINK[1], 0.9), (45, 12, PINK[2], 0.8)]:
        x = -6
        while x < 150:
            r = rr * random.uniform(0.8, 1.2)
            c.new_sub_path(); c.arc(x + r, base, r, math.pi, 2 * math.pi)
            # vòng xoắn trong (kiểu mây cát tường)
            c.set_source_rgba(*C(col, a)); c.fill_preserve()
            c.set_source_rgba(1, 1, 1, 0.55); c.set_line_width(0.8); c.stroke()
            c.new_sub_path(); c.arc(x + r, base, r * 0.62, math.pi, 2 * math.pi)
            c.set_source_rgba(1, 1, 1, 0.45); c.set_line_width(0.7); c.stroke()
            x += r * 1.55
    # mờ dần lên trên
    c.set_operator(cairo.OPERATOR_DEST_IN)
    c.set_source(lin(c, 0, 0, 0, 46, [(0, '#000000'), (0, '#000000')]))
    g = cairo.LinearGradient(0, 0, 0, 46); g.add_color_stop_rgba(0, 0, 0, 0, 0.0); g.add_color_stop_rgba(0.45, 0, 0, 0, 0.75); g.add_color_stop_rgba(1, 0, 0, 0, 1)
    c.set_source(g); c.paint()
    g2 = cairo.LinearGradient(0, 0, 140, 0); g2.add_color_stop_rgba(0, 0, 0, 0, 1); g2.add_color_stop_rgba(0.55, 0, 0, 0, 1); g2.add_color_stop_rgba(1, 0, 0, 0, 0)
    c.set_source(g2); c.paint()
    save(s, 'may')


# ------------------------------------------------------------------ hoa sen nét mảnh in chìm (nền giấy)
def line_lotus():
    s, c = surf(120, 74)
    col = C('#e7a7b6', 0.55)
    cx, by = 60, 66

    def petal(ang, L, W, x=cx, y=by):
        c.save(); c.translate(x, y); c.rotate(ang)
        c.move_to(0, 0); c.curve_to(-W, -L * 0.3, -W * 0.85, -L * 0.78, 0, -L)
        c.curve_to(W * 0.85, -L * 0.78, W, -L * 0.3, 0, 0)
        c.move_to(0, -L * 0.1); c.curve_to(-W * 0.15, -L * 0.5, -W * 0.1, -L * 0.75, 0, -L * 0.95)   # gân giữa
        c.restore()
    for ang, L, W in [(-1.35, 40, 9), (1.35, 40, 9), (-0.95, 50, 11), (0.95, 50, 11), (-0.48, 58, 12), (0.48, 58, 12), (0.0, 62, 13)]:
        petal(ang, L, W)
    c.set_source_rgba(*col); c.set_line_width(0.9); c.stroke()
    save(s, 'net_sen')


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    emblem_tab()
    crest('dinh', 128, 44, 50, 34, 12)
    crest('day', 72, 28, 32, 21, 9, flip=True)
    close_btn()
    tassel()
    clouds()
    line_lotus()
    print('ok')
