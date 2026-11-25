#!/usr/bin/env python3
# Phao trên mặt nước trong câu cá (thay can/phao0-2), cùng dáng 4 icon phao mới của do3d.py (float_ bậc 1-4).
# Nhìn gần ngang (EL 10) như cảnh câu; mặt nước = đỉnh bấc: trên là cọng nổi, dưới là bấc chìm (game làm mờ).
#   EL=10 PXU=14 SSA=2 python3 phao_game.py OUTDIR      -> OUTDIR/phao0..3.webp + phao.json (w h wl hs hb ws, cùng khoá can.json)
import os, sys, json, math
os.environ.setdefault('EL', '10')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import do3d as D
import numpy as np
from PIL import Image

ZW = {1: 9.5, 2: 10.2, 3: 10.7, 4: 11.6}     # đỉnh bấc = mặt nước (đơn vị)
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
meta = {"px": D.B.PXU, "el": float(os.environ['EL'])}
for t in (int(a) for a in (sys.argv[2:] or '1234')):
    im, anc = D.B.render(D.float_(t), 'phao%d' % t, water=False)
    im = im[0]
    a = np.array(im.convert('RGBA'))[..., 3] > 8
    ys = np.nonzero(a.any(1))[0]
    ce = math.cos(math.radians(meta['el']))
    wl = float(anc[1]) - ZW[t] * ce * D.B.PXU
    top, bot = int(ys.min()), int(ys.max())
    hs = wl - top
    row = a[int(top + hs * .45)]
    xs = np.nonzero(row)[0]
    nm = 'phao%d' % (t - 1)
    im.save(os.path.join(OUT, nm + '.webp'), lossless=True, quality=100, method=6)
    meta[nm] = {"w": im.width, "h": im.height, "wl": round(wl, 1), "hs": round(hs, 1), "hb": round(bot - wl, 1), "ws": float(xs.max() - xs.min() + 1)}
    print(nm, meta[nm], flush=True)
json.dump(meta, open(os.path.join(OUT, 'phao.json'), 'w'), indent=1)
