#!/usr/bin/env python3
# Lờ / lọp / giăng câu 4 cấp (bay3d.py, art/bay: lo lo2 lo3 lo4, lop.., giang..) -> ảnh vườn ui/img/ts/bay: d<id>.webp (ngày) + n<id>.webp (đêm nướng sẵn,
# nhân màu như lục bình đêm (.60 .70 .93)), bản "đặt trên nước" (_w). atlas.json: w h (điểm ảnh), ox oy = góc trên-trái
# so với chỗ đặt chân, theo đơn vị làng (6 px / đơn vị). CHƯA GẮN vô vườn (11-24 Link: "vẽ thôi để bên kia gắn").
#   python3 bake_bay.py
import os, json
import numpy as np
from PIL import Image
H = os.path.dirname(os.path.abspath(__file__)); SRC = os.path.join(H, '..', '..', '..')
ART = os.path.join(SRC, 'art', 'bay'); OUT = os.path.join(SRC, 'godot', 'ui', 'img', 'ts', 'bay')
os.makedirs(OUT, exist_ok=True)
meta = json.load(open(os.path.join(ART, 'meta.json')))
NIGHT = np.array([.60, .70, .93])
fr = {}
for k, m in meta.items():
    im = Image.open(os.path.join(ART, k + '_w.webp')).convert('RGBA')
    a = np.asarray(im).astype(np.float32)
    pu = float(m['px_per_unit'])
    for p, mul in (('d', np.ones(3)), ('n', NIGHT)):
        b = a.copy(); b[..., :3] = np.clip(b[..., :3] * mul, 0, 255)
        Image.fromarray(b.astype(np.uint8), 'RGBA').save(os.path.join(OUT, p + k + '.webp'), lossless=True, quality=100, method=6)
        fr[p + k] = {"file": p + k + '.webp', "w": im.width, "h": im.height, "ox": round(-m['ax'] / pu, 3), "oy": round(-m['ay'] / pu, 3),
                     "gw": round(im.width / pu, 3), "gh": round(im.height / pu, 3)}
json.dump({"px_per_unit": 6, "frames": fr}, open(os.path.join(OUT, 'atlas.json'), 'w'), indent=1)
print(sorted(fr))
