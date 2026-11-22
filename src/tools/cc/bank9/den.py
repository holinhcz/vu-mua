#!/usr/bin/env python3
# Ảnh đêm bờ -> CHỈ PHẦN ĐÈN (Link 11-22 "bung ra 170MB"): đêm của nông trại = ngày x(.61,.68,.82) + đèn.
# Game tô đêm bằng ảnh ngày x màu giờ, chỉ cần phần đèn dư ra: L = max(n - d*(.61,.68,.82) - .04, 0).
# Ảnh đèn gần như đen hết -> pck nhẹ, và game giữ atlas đèn ở nửa độ phân giải (đèn là quầng mềm).
# python3 den.py DIR   (đổi tại chỗ mọi X_n.webp có X_d.webp; CHỈ chạy 1 lần trên ảnh đêm gốc — farm_pick.py tự gọi)
import sys, os, glob
import numpy as np
from PIL import Image

K = np.array([.61, .68, .82], np.float32)

def den_dir(D):
    n_ok = 0
    for fn in sorted(glob.glob(os.path.join(D, '*_n.webp'))):
        fd = fn[:-7] + '_d.webp'
        if not os.path.exists(fd):
            continue
        d = np.asarray(Image.open(fd).convert('RGBA')).astype(np.float32) / 255
        n = np.asarray(Image.open(fn).convert('RGBA')).astype(np.float32) / 255
        if d.shape != n.shape:
            continue
        L = np.clip(n[..., :3] - d[..., :3] * K - .04, 0, 1) * (n[..., 3:] > 0)
        out = np.dstack([L, n[..., 3:]])
        Image.fromarray((out * 255 + .5).astype(np.uint8), 'RGBA').save(fn, lossless=True, quality=100, method=4)
        n_ok += 1
    return n_ok

if __name__ == '__main__':
    print(den_dir(sys.argv[1]), 'ảnh đêm -> đèn')
