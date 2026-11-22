# Bờ bên kia kênh (câu cá) vẽ lại 9px: cùng bố cục bank2.py nhưng vẽ vector ở S=3 lần (5400x900 -> 16200x2700),
# rồi tô thêm từng điểm ảnh: viền nhạt cùng màu lá, sáng mép trên trái / tối mép dưới phải, bóng đổ của lớp trước lên lớp sau,
# hạt mịn nhẹ. Xuất 6 mảnh 2700x2700 (+ lề) mỗi mảnh 1 file, Godot ghép + thu về đúng độ phân giải màn hình.
#   python3 bank9.py OUT [x0 x1]   (x0 x1 = đoạn xem thử, toạ độ ảnh cũ 0..5400)
import sys, os, math, random
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cairo
import numpy as np
from PIL import Image
import scene
import bank2 as B
from bank2 import C, WL, BW, BH, ground, CREEK

S = 3                     # 1 điểm ảnh cũ = 3 điểm ảnh mới
HW, HH = BW * S, BH * S   # 16200 x 2700
TILE = 2700               # mảnh
MARGIN = 48               # lề mỗi bên của mảnh (để thu nhỏ không lộ đường nối)

# ------------------------------------------------------------------ tiện ích ảnh
def box(a, r, axis):
    if r < 1:
        return a
    c = np.cumsum(np.pad(a, [(r + 1, r) if i == axis else (0, 0) for i in range(a.ndim)], mode='edge'), axis=axis, dtype=np.float32)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return (hi - lo) / (2 * r + 1)

def blur(a, sig):
    r = max(1, int(round(sig * 0.93)))
    for _ in range(3):
        a = box(box(a, r, 0), r, 1)
    return a

def shift(a, dx, dy):
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    xs0, xs1 = max(0, -dx), min(w, w - dx)
    ys0, ys1 = max(0, -dy), min(h, h - dy)
    out[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = a[ys0:ys1, xs0:xs1]
    return out

def dilate(a, n):
    for _ in range(n):
        b = a.copy()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            b = np.maximum(b, shift(a, dx, dy))
        a = b
    return a

def vnoise(h, w, cell, seed):
    rg = np.random.default_rng(seed)
    gh, gw = h // cell + 3, w // cell + 3
    g = rg.random((gh, gw)).astype(np.float32)
    im = Image.fromarray(g, 'F').resize((gw * cell, gh * cell), Image.BICUBIC)
    return np.asarray(im)[:h, :w]

# ------------------------------------------------------------------ vẽ 1 đoạn [x0, x1) toạ độ mới
def draw_layers(x0, w):
    """chạy toàn bộ bố cục (cùng hạt giống 21 như bank2) vào các mặt rộng w bắt đầu ở x0 (toạ độ mới)"""
    surfs = []
    def new():
        s = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, HH)
        c = cairo.Context(s)
        c.set_line_cap(cairo.LINE_CAP_ROUND); c.set_line_join(cairo.LINE_JOIN_ROUND)
        c.translate(-x0, 0); c.scale(S, S)
        return s, c
    R = random.Random(21)
    layers = []
    # 1. xa: hàng cây liền + ngọn dừa, mờ sương
    s, c = new()
    pts = [(-20, WL)]
    for x in range(-20, BW + 40, 30):
        pts.append((x, WL - 120 - 26 * math.sin(x / 310) - 18 * math.sin(x / 97 + 2) - R.uniform(0, 14)))
    pts.append((BW + 40, WL)); B.crpath(c, pts, True)
    c.set_source(scene.vgrad_px(WL - 190, WL - 40, [(0, C('#8cc86a')), (1, C('#4e8a4a'))])); c.fill()
    for i in range(90):
        x = R.uniform(0, BW)
        B.leafy_clump(c, R, x, WL - 130 - R.uniform(0, 30), R.uniform(36, 60), R.uniform(24, 36), 20, '#a8d878', '#6aa856', '#3e7a4e', 0, (8, 14))
    for g0 in (300, 1300, 1750, 2900, 4300, 5150):
        for j in range(R.randint(2, 4)):
            B.coconut(c, R, g0 + R.uniform(-110, 110), WL - 110, R.uniform(150, 230), R.uniform(-.3, .3), .5, 0)
    layers.append(dict(s=s, fol=True, hz=.30, sh=0))
    # 2. giữa: vườn dừa + cây ăn trái
    s, c = new()
    for x, h, ww, fr in ((1150, 250, 260, 'xoai'), (2050, 230, 240, 'chom'), (3420, 260, 280, 'xoai'), (4520, 240, 260, None), (230, 230, 240, 'chom')):
        B.fruit_tree(c, R, x, ground(x) + 4, h, ww, fr, 1.0, .03)
    for cx, n, spread in ((600, 5, 220), (2230, 4, 160), (3750, 4, 200), (4980, 5, 230)):
        for j in range(n):
            x = cx + R.uniform(-spread, spread)
            B.coconut(c, R, x, ground(x) + 2, R.uniform(330, 560), R.uniform(-.35, .35) + (x - cx) / spread * .15, .85, .04)
    layers.append(dict(s=s, fol=True, hz=.09, sh=.16))
    # 3. vườn sau nhà: chuối, dâm bụt, điên điển, bụi thấp
    s, c = new()
    for x in (420, 980, 2140, 2420, 3330, 3880, 4700, 5250):
        B.banana(c, R, x + R.uniform(-30, 30), ground(x) + 6, R.uniform(.85, 1.05), 0)
    for x in (760, 2950, 4060):
        B.hibiscus(c, R, x, ground(x) + 4, R.uniform(110, 150))
    for x in range(0, BW, 70):
        if CREEK[0] - 40 < x < CREEK[1] + 40 or R.random() < .35: continue
        B.leafy_clump(c, R, x, ground(x) - 16, R.uniform(40, 60), 22, 20, '#a4d460', '#5ea23c', '#2e6a36', 0, (7, 11))
    layers.append(dict(s=s, fol=True, hz=0, sh=.26))
    # 4. bờ đất + nhà
    s, c = new(); sg, g = new()
    B.nha_la(c, g, R, 4250, ground(4250) + 6, .74)
    B.nha_la(c, g, R, 860, ground(860) + 6, .66)
    B.mud_bank(c, R, -20, BW + 20)
    B.rach_and_bridge(c, R, *CREEK)
    for ex, d in ((CREEK[0], 1), (CREEK[1], -1)):
        c.move_to(ex - d * 30, ground(ex) + 8); c.curve_to(ex, ground(ex) + 10, ex + d * 24, WL - 14, ex + d * 50, WL + 2); c.line_to(ex - d * 30, WL + 2); c.close_path()
        c.set_source_rgba(*C('#9a7044')); c.fill()
    B.nha_la(c, g, R, 2650, WL + 10, 1.15)
    B.stakes(c, R, 3190, 5, 1.0); B.stakes(c, R, 1180, 3, .9); B.stakes(c, R, 4560, 4, .9)
    sx = 3560; sy = ground(sx) + 4
    c.move_to(sx, sy); c.line_to(sx, sy - 74); c.set_source_rgba(*C('#7a5434')); c.set_line_width(5); c.stroke()
    c.rectangle(sx - 16, sy - 98, 32, 24); c.set_source_rgba(*C('#d8402a')); c.fill()
    c.move_to(sx - 24, sy - 96); c.line_to(sx, sy - 114); c.line_to(sx + 24, sy - 96); c.close_path(); c.set_source_rgba(*C('#a82a1a')); c.fill()
    g.arc(sx, sy - 86, 8, 0, 6.3); g.set_source_rgba(1, 1, 1, .9); g.fill()
    layers.append(dict(s=s, fol=False, hz=0, sh=.30))
    # 5. trước: dừa nghiêng ra kênh, dừa nước, điên điển, lục bình
    s, c = new()
    B.coconut(c, R, 3020, ground(3020) + 6, 640, .82, 1.1, 0)
    B.coconut(c, R, 3150, ground(3150) + 6, 520, .45, 1.0, 0)
    B.coconut(c, R, 2330, ground(2330) + 6, 600, -.72, 1.05, 0)
    for xa, xb, step in ((-40, 420, 120), (1080, 1430, 110), (1910, 2160, 120), (4620, 5100, 120), (5250, BW + 60, 120)):
        x = xa
        while x < xb:
            B.nipa_clump(c, R, x, WL + 4, R.uniform(.8, 1.05)); x += step * R.uniform(.8, 1.2)
    B.dien_dien(c, R, 3480, ground(3480) + 8, 1.05); B.dien_dien(c, R, 4420, ground(4420) + 8, .95); B.dien_dien(c, R, 520, ground(520) + 8, .9)
    for xa in (180, 1300, 2020, 3260, 4760, 5300):
        for j in range(R.randint(2, 4)):
            scene.hyacinth(c, R, xa + j * R.uniform(24, 40), WL + R.uniform(0, 6), R.uniform(.7, .95), R.random() < .35, 0)
    layers.append(dict(s=s, fol=True, hz=0, sh=.30))
    return layers, sg

def to_np(s):
    s.flush()
    return np.ndarray((s.get_height(), s.get_width(), 4), np.uint8, s.get_data()).astype(np.float32) / 255

HAZE = np.array([.74, .86, .92], np.float32)
SHADOW = np.array([.10, .26, .22], np.float32)
LIGHT = np.array([-.55, -.83], np.float32)   # nắng từ trên trái

def compose(layers, x0, w):
    col = np.zeros((HH, w, 3), np.float32); al = np.zeros((HH, w), np.float32); sway = np.zeros((HH, w), np.float32)
    grain = (vnoise(HH, w, 5, 5) - .5) * .035
    for li, L in enumerate(layers):
        a = to_np(L['s']); pa = a[..., 3].copy(); prgb = a[..., [2, 1, 0]].copy()   # premultiplied
        if pa.max() <= 0:
            continue
        # màu thẳng (không nhân alpha) để tô
        un = prgb / np.maximum(pa[..., None], 1e-4)
        # sáng/tối theo mép (khối nổi): pháp tuyến từ alpha nhoè
        ab = blur(pa, 3.0 * S / 3 * 2)
        gy, gx = np.gradient(ab)
        nl = -(gx * LIGHT[0] + gy * LIGHT[1]) * 9.0
        rim = np.clip(nl, -1, 1)
        k = .16 if li >= 1 else .07
        un = un * (1 + k * rim[..., None]) + np.where(rim > 0, rim, 0)[..., None] * k * .5 * np.array([1, .96, .8], np.float32)
        # hạt mịn rất nhẹ (đất/lá không lấm tấm)
        un = un * (1 + grain[..., None] * (.5 if li == 0 else 1.0))
        # viền nhạt cùng màu lá (lá x0.78), không viền đen/xám
        if li >= 1:
            ring = np.clip(dilate(pa, 2) - pa, 0, 1)
            if ring.max() > 0:
                # màu kế bên: lan màu ra ngoài 2 điểm ảnh
                cs = un * pa[..., None]
                for _ in range(2):
                    acc = cs.copy(); wacc = pa.copy()
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        acc += shift(cs, dx, dy); wacc += shift(pa, dx, dy)
                    cs = acc / 5; pa_s = wacc / 5
                edge = cs / np.maximum(pa_s[..., None], 1e-4) * .78
                un = np.where(pa[..., None] > 1e-3, un, edge)
                pa = pa + ring * .85
        # sương xa
        if L['hz']:
            un = un * (1 - L['hz']) + HAZE[None, None, :] * L['hz']
        # bóng đổ của lớp này lên các lớp phía sau (chỉ tối màu, không đổi alpha)
        if L['sh'] > 0 and al.max() > 0:
            shd = blur(shift(pa, int(4 * S), int(6 * S)), 5.0 * S) * L['sh']
            shd = shd * (1 - pa)
            col = col * (1 - shd[..., None]) + (SHADOW[None, None, :] * shd[..., None]) * al[..., None] * .55 + col * shd[..., None] * .45
        un = np.clip(un, 0, 1)
        prgb = un * pa[..., None]
        col = col * (1 - pa[..., None]) + prgb; al = al * (1 - pa) + pa
        sway = sway * (1 - pa) + pa * (1.0 if L['fol'] else 0.0)
    rgb = col / np.maximum(al[..., None], 1e-4)
    rgba = (np.concatenate([np.clip(rgb, 0, 1), np.clip(al, 0, 1)[..., None]], -1) * 255 + .5).astype(np.uint8)
    return rgba, sway

def region(x0, x1):
    w = x1 - x0
    layers, sg = draw_layers(x0, w)
    rgba, sway = compose(layers, x0, w)
    glow = to_np(sg)[..., 3]
    return rgba, sway, glow

if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    if len(sys.argv) > 3:
        a, b = int(float(sys.argv[2]) * S), int(float(sys.argv[3]) * S)
        rgba, _, _ = region(a, b)
        Image.fromarray(rgba, 'RGBA').save(os.path.join(out, 'thu.png'))
        print('thu', rgba.shape)
        sys.exit()
    n = HW // TILE
    sw_full = np.zeros((BH, BW), np.float32); gl_full = np.zeros((BH, BW), np.float32)
    for i in range(n):
        a = i * TILE - MARGIN; b = (i + 1) * TILE + MARGIN
        rgba, sway, glow = region(a, b)
        Image.fromarray(rgba, 'RGBA').save(os.path.join(out, 'bank9_%d.webp' % i), lossless=True, quality=100, method=4)
        core = slice(MARGIN, MARGIN + TILE)
        sm = Image.fromarray(sway[:, core], 'F').resize((TILE // S, BH), Image.BOX)
        gm = Image.fromarray(glow[:, core], 'F').resize((TILE // S, BH), Image.BOX)
        sw_full[:, i * TILE // S:(i + 1) * TILE // S] = np.asarray(sm)
        gl_full[:, i * TILE // S:(i + 1) * TILE // S] = np.asarray(gm)
        print('tile', i, rgba.shape, flush=True)
    gl = np.asarray(Image.fromarray((gl_full * 255).astype(np.uint8)).filter(__import__('PIL.ImageFilter', fromlist=['x']).GaussianBlur(2))).astype(np.float32) / 255
    aux = np.stack([gl, sw_full, np.zeros_like(gl), np.ones_like(gl)], -1)
    Image.fromarray((aux * 255 + .5).clip(0, 255).astype(np.uint8), 'RGBA').resize((BW // 2, BH // 2), Image.BILINEAR).save(os.path.join(out, 'bank_aux.webp'), lossless=True)
    print('done')
