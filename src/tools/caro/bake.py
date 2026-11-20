# Nướng ảnh cờ caro cho Godot: ui/img/caro/
#   board.webp (phản gỗ + bóng), board.json (toạ độ lưới, px), x0..x3 / o0..o3 (quân phấn, mỗi cái 1 file),
#   ring.webp (khoanh phấn vàng nước vừa đi), line.webp (vệt phấn vàng gạch 5 con thắng)
import sys, os, json, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import board2 as B

OUT = sys.argv[1]
KB = 4.0                      # điểm ảnh / css của ảnh nướng
os.makedirs(OUT, exist_ok=True)

def save(arr, name):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA').save(os.path.join(OUT, name + '.webp'), lossless=True, quality=100, method=6)

# ---------------- phản
a, meta = B.board(KB)
save(np.dstack([a[..., :3], a[..., 3] * 255]), 'board')
ox = int(meta['M'] * KB); s = int(meta['S'] * KB); fr = meta['FR'] * KB; pad = 5.0 * KB
cs = (s - 2 * fr - 2 * pad) / 15
info = {'w': a.shape[1], 'h': a.shape[0], 'gx0': ox + fr + pad, 'gy0': ox + fr + pad, 'cs': cs,
        'face': [ox, ox, s, s], 'th': int(meta['TH'] * KB), 'kb': KB}
json.dump(info, open(os.path.join(OUT, 'board.json'), 'w'))
print(info)

# ---------------- quân phấn
CS = cs / KB                  # css 1 ô
SZ = int(round(CS * 1.6 * KB))  # khung ảnh quân (rộng hơn ô 1 chút cho bụi phấn)

def stroke_mask(pts, width):
    m = Image.new('L', (SZ, SZ), 0); d = ImageDraw.Draw(m)
    q = [(x * KB, y * KB) for x, y in pts]
    d.line(q, fill=255, width=max(1, int(width * KB)), joint='curve')
    r = width * KB / 2
    for x, y in (q[0], q[-1]):
        d.ellipse((x - r, y - r, x + r, y + r), fill=255)
    return np.asarray(m.filter(ImageFilter.GaussianBlur(KB * 0.35)), np.float32) / 255

def chalk(mask, col, rg):
    grain = B.fbm(SZ, SZ, 0.7 * KB, 2, rg)
    grain2 = B.fbm(SZ, SZ, 3.0 * KB, 2, rg)
    al = np.clip(mask * (0.40 + 1.05 * grain) * (0.78 + 0.38 * grain2), 0, 1)
    dust = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(KB * 2.0)), np.float32) / 255
    al = np.maximum(al, dust * 0.16 * grain)
    lit = (0.86 + 0.26 * grain)[..., None]
    rgb = np.clip(np.array(col, np.float32) * lit, 0, 255)
    return np.dstack([rgb, al * 255])

XC = (150, 206, 248); OC = (250, 160, 178); YC = (255, 216, 96)
c = SZ / KB / 2               # tâm (css)
r = CS * 0.34
for v in range(4):
    rg = np.random.default_rng(500 + v)
    j = lambda: rg.uniform(-1, 1) * CS * 0.045
    a1 = [(c - r + j(), c - r + j()), (c + j() * 0.5, c + j() * 0.5), (c + r + j(), c + r + j())]
    a2 = [(c + r + j(), c - r + j()), (c - r + j(), c + r + j())]
    m = np.maximum(stroke_mask(a1, 3.0), stroke_mask(a2, 3.0))
    save(chalk(m, XC, rg), 'x%d' % v)
    rg = np.random.default_rng(600 + v)
    t0 = rg.uniform(0, 6.28); pts = []
    for i in range(49):
        t = t0 + i / 48 * 6.28 * 1.07
        rr = r * (1.0 + 0.05 * math.sin(t * 2 + v)) * (1 + 0.05 * i / 48)
        pts.append((c + rr * math.cos(t), c + rr * 0.95 * math.sin(t)))
    save(chalk(stroke_mask(pts, 2.9), OC, rg), 'o%d' % v)

# khoanh vàng nước vừa đi (vuông bo, nét phấn mảnh)
rg = np.random.default_rng(700)
m = Image.new('L', (SZ, SZ), 0); d = ImageDraw.Draw(m)
h = CS * 0.47 * KB; cc = SZ / 2
d.rounded_rectangle((cc - h, cc - h, cc + h, cc + h), radius=int(4 * KB), outline=255, width=int(1.5 * KB))
m = np.asarray(m.filter(ImageFilter.GaussianBlur(KB * 0.3)), np.float32) / 255
save(chalk(m, YC, rg), 'ring')

# vệt phấn vàng dài (gạch 5 con): ảnh ngang 1024 x 64, kéo giãn theo độ dài
LW, LH = 1024, 64
rg = np.random.default_rng(800)
m = Image.new('L', (LW, LH), 0); d = ImageDraw.Draw(m)
pts = [(16 + i * (LW - 32) / 40, LH / 2 + math.sin(i * 0.7) * 2.0) for i in range(41)]
d.line(pts, fill=255, width=int(LH * 0.30), joint='curve')
for x, y in (pts[0], pts[-1]):
    d.ellipse((x - LH * 0.15, y - LH * 0.15, x + LH * 0.15, y + LH * 0.15), fill=255)
m = np.asarray(m.filter(ImageFilter.GaussianBlur(1.4)), np.float32) / 255
g1 = B.fbm(LH, LW, 2.8, 2, rg); g2 = B.fbm(LH, LW, 12, 2, rg)
al = np.clip(m * (0.45 + 1.0 * g1) * (0.8 + 0.35 * g2), 0, 1)
rgb = np.clip(np.array(YC, np.float32) * (0.88 + 0.22 * g1)[..., None], 0, 255)
save(np.dstack([rgb, al * 255]), 'line')
print('quan', SZ, 'px; ô', CS, 'css')
