#!/usr/bin/env python3
# Mây ĐƠN GIẢN cho Câu cá (Link 11-22 "mây thì vẽ đơn giản thôi"): vài múi tròn nhập 1 khối, đáy bo,
# 2 màu phẳng (trắng + bóng xanh nhạt hình lưỡi liềm ở dưới-phải), viền mảnh gần màu mây. Không chi tiết.
# python3 may_don.py OUTDIR   -> may0..5.webp + may.json (cùng tên/khung như may.py, cc_may.gd dùng thẳng)
import sys, os, json
import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/may_don'
os.makedirs(OUT, exist_ok=True)

C_BODY = np.array([255, 255, 255], np.float32)
C_SHADE = np.array([214, 230, 247], np.float32)
C_EDGE = np.array([198, 216, 238], np.float32)

def smin(a, b, k):
    h = np.clip(.5 + .5 * (b - a) / k, 0, 1)
    return b + (a - b) * h - k * h * (1 - h)

def sdf(xx, yy, bumps, base, W):
    d = None
    for (bx, by, br) in bumps:
        e = np.hypot(xx - bx * W, yy - by * W) - br * W
        d = e if d is None else smin(d, e, W * .03)
    # thân dưới: viên dẹt bo tròn nối các múi, đáy hơi bầu
    x0, x1, y0, rr = base
    cx = np.clip(xx, x0 * W, x1 * W)
    e = np.hypot(xx - cx, (yy - y0 * W) * 1.15) - rr * W
    return smin(d, e, W * .03)

def render(name, bumps, base, W=900):
    pad = 8
    xs = [b[0] - b[2] for b in bumps] + [base[0] - base[3]]
    xe = [b[0] + b[2] + .04 for b in bumps] + [base[1] + base[3] + .04]
    ys = [b[1] - b[2] for b in bumps]
    x0, x1 = min(xs) * W - pad, max(xe) * W + pad
    y0, y1 = min(ys) * W - pad, (base[2] + base[3] + .06) * W + pad
    w, h = int(x1 - x0), int(y1 - y0)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    xx += x0 + .5; yy += y0 + .5
    # 2 lớp: lớp bóng xanh nhạt (chính hình mây dời xuống-phải) nằm sau, lớp trắng đè lên -> viền bóng lưỡi liềm dưới-phải
    dw = sdf(xx, yy, bumps, base, W)
    off = (W * .03, W * .05)
    db = sdf(xx - off[0], yy - off[1], bumps, base, W)
    d = np.minimum(dw, db)
    A = np.clip(.5 - d, 0, 1)
    sh = np.clip(.5 + dw, 0, 1)                       # 1 = ngoài lớp trắng (thấy lớp bóng)
    col = C_BODY[None, None] * (1 - sh[..., None]) + C_SHADE[None, None] * sh[..., None]
    ew = max(1.5, W * .004)                             # viền mảnh, gần màu mây
    edge = np.clip(1 - np.abs(d + ew * .5) / (ew * .5 + .5), 0, 1) * (d < 0) + (d >= 0)
    col = col * (1 - edge[..., None]) + C_EDGE[None, None] * edge[..., None]
    im = Image.fromarray(np.dstack([col, A * 255]).astype(np.uint8), 'RGBA')
    bb = im.getbbox()
    im = im.crop(bb)
    ax = (0 - x0) - bb[0]; ay = ((base[2] + base[3] + .05) * W - y0) - bb[1]
    im.save(os.path.join(OUT, name + '.webp'), lossless=True, quality=100, method=6)
    im.save(os.path.join(OUT, name + '.png'))
    return dict(w=im.width, h=im.height, ax=round(float(ax), 1), ay=round(float(ay), 1))

# múi: (x, y, r) theo bề ngang W; y âm = lên. base = (x trái, x phải, y tâm, bán kính) của thân dưới
SPEC = {
    'may0': ([(-.24, -.1, .14), (-.06, -.2, .2), (.15, -.16, .17), (.31, -.07, .11)], (-.3, .34, -.02, .08)),
    'may1': ([(-.2, -.08, .13), (-.02, -.17, .18), (.18, -.09, .13)], (-.27, .26, -.02, .08)),
    'may2': ([(-.22, -.06, .1), (-.06, -.12, .14), (.1, -.13, .13), (.24, -.05, .09)], (-.28, .3, -.01, .065)),
    'may3': ([(-.12, -.1, .14), (.08, -.13, .15), (.24, -.04, .09)], (-.2, .28, -.01, .07)),
    'may4': ([(-.14, -.04, .08), (.0, -.08, .11), (.15, -.04, .08)], (-.2, .2, -.0, .055)),
    'may5': ([(-.08, -.05, .09), (.08, -.07, .1)], (-.14, .14, -.0, .055)),
}
meta = {k: render(k, *v) for k, v in SPEC.items()}
json.dump(meta, open(os.path.join(OUT, 'may.json'), 'w'), indent=1)
print(meta)
