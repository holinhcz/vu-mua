# Ghi lại bố cục bờ cũ (bank2.py, hạt giống 21): REC = [lớp, loại, tham số], FAR = đường cây xa.
# Toạ độ thế giới = toạ độ ảnh cũ 5400x900 (đơn vị bờ). Ảnh vẽ S=3 điểm ảnh / đơn vị.
import sys, os, math, random, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cairo
import numpy as np
from PIL import Image
import scene
import bank2 as B
from bank2 import C, WL, BW, BH, ground, CREEK
from bank9 import blur, shift, dilate, vnoise, to_np, LIGHT, HAZE

S = 3

# ------------------------------------------------------------------ 1. ghi lại bố cục (chạy đúng chuỗi R của bank2)
rec = []
depth = [0]
layer = [0]
def wrap(mod, name, key):
    f = getattr(mod, name)
    def g(*a, **k):
        if depth[0] == 0:
            rec.append([layer[0], key, a[2:] if key != 'nha' else a[3:], k])
        depth[0] += 1
        try:
            return f(*a, **k)
        finally:
            depth[0] -= 1
    setattr(mod, name, g)
for nm, key in [('coconut', 'dua'), ('leafy_clump', 'bui'), ('fruit_tree', 'cay'), ('banana', 'chuoi'), ('hibiscus', 'dambut'),
                ('dien_dien', 'diendien'), ('nipa_clump', 'duanuoc'), ('nha_la', 'nha'), ('stakes', 'coc'),
                ('mud_bank', 'bo'), ('rach_and_bridge', 'cau')]:
    wrap(B, nm, key)
wrap(scene, 'hyacinth', 'lucbinh')

def compose_record():
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, 1, 1); c = cairo.Context(s); g = cairo.Context(cairo.ImageSurface(cairo.FORMAT_ARGB32, 1, 1))
    R = random.Random(21)
    far = []
    layer[0] = 0
    pts = [(-20, WL)]
    for x in range(-20, BW + 40, 30):
        pts.append((x, WL - 120 - 26 * math.sin(x / 310) - 18 * math.sin(x / 97 + 2) - R.uniform(0, 14)))
    pts.append((BW + 40, WL)); far = pts
    for i in range(90):
        x = R.uniform(0, BW)
        B.leafy_clump(c, R, x, WL - 130 - R.uniform(0, 30), R.uniform(36, 60), R.uniform(24, 36), 20, '#a8d878', '#6aa856', '#3e7a4e', 0, (8, 14))
    for g0 in (300, 1300, 1750, 2900, 4300, 5150):
        for j in range(R.randint(2, 4)):
            B.coconut(c, R, g0 + R.uniform(-110, 110), WL - 110, R.uniform(150, 230), R.uniform(-.3, .3), .5, 0)
    layer[0] = 1
    for x, h, ww, fr in ((1150, 250, 260, 'xoai'), (2050, 230, 240, 'chom'), (3420, 260, 280, 'xoai'), (4520, 240, 260, None), (230, 230, 240, 'chom')):
        B.fruit_tree(c, R, x, ground(x) + 4, h, ww, fr, 1.0, .03)
    for cx, n, spread in ((600, 5, 220), (2230, 4, 160), (3750, 4, 200), (4980, 5, 230)):
        for j in range(n):
            x = cx + R.uniform(-spread, spread)
            B.coconut(c, R, x, ground(x) + 2, R.uniform(330, 560), R.uniform(-.35, .35) + (x - cx) / spread * .15, .85, .04)
    layer[0] = 2
    for x in (420, 980, 2140, 2420, 3330, 3880, 4700, 5250):
        B.banana(c, R, x + R.uniform(-30, 30), ground(x) + 6, R.uniform(.85, 1.05), 0)
    for x in (760, 2950, 4060):
        B.hibiscus(c, R, x, ground(x) + 4, R.uniform(110, 150))
    for x in range(0, BW, 70):
        if CREEK[0] - 40 < x < CREEK[1] + 40 or R.random() < .35: continue
        B.leafy_clump(c, R, x, ground(x) - 16, R.uniform(40, 60), 22, 20, '#a4d460', '#5ea23c', '#2e6a36', 0, (7, 11))
    layer[0] = 3
    B.nha_la(c, g, R, 4250, ground(4250) + 6, .74)
    B.nha_la(c, g, R, 860, ground(860) + 6, .66)
    B.mud_bank(c, R, -20, BW + 20)
    B.rach_and_bridge(c, R, *CREEK)
    B.nha_la(c, g, R, 2650, WL + 10, 1.15)
    B.stakes(c, R, 3190, 5, 1.0); B.stakes(c, R, 1180, 3, .9); B.stakes(c, R, 4560, 4, .9)
    rec.append([3, 'mieu', (3560, ground(3560) + 4), {}])
    layer[0] = 4
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
    return far

FAR = compose_record()
depth[0] = 1   # từ đây vẽ món: không ghi nữa

depth[0] = 1
