# Dấu tích xanh dùng chung (bản 300): ô tròn xanh một màu + dấu tích trắng, vẽ phóng 8 lần rồi thu (mép mượt).
import sys, math
from PIL import Image, ImageDraw, ImageFilter
N, SS = 128, 8
S = N * SS
im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
c = S / 2
R = S * 0.46
# thân tròn: một màu xanh như bản cũ (.odck rgb(87, 181, 78)), không viền, không vệt sáng
ImageDraw.Draw(im).ellipse((c - R, c - R, c + R, c + R), fill=(87, 181, 78, 255))
# dấu tích: bóng mờ rồi nét trắng
pts = [(c - R * 0.46, c + R * 0.02), (c - R * 0.12, c + R * 0.36), (c + R * 0.50, c - R * 0.32)]
w = int(S * 0.115)
d = ImageDraw.Draw(im)
d.line(pts, fill=(255, 255, 255, 255), width=w, joint="curve")
for x, y in (pts[0], pts[2]):
    d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=(255, 255, 255, 255))
# thu có nhân alpha
import numpy as np
a = np.asarray(im).astype(np.float64)
al = a[..., 3:4] / 255.0
pre = np.concatenate([a[..., :3] * al, a[..., 3:4]], -1).reshape(N, SS, N, SS, 4).mean((1, 3))
out = pre.copy()
m = pre[..., 3:4] > 0
out[..., :3] = np.where(m, pre[..., :3] / np.maximum(pre[..., 3:4] / 255.0, 1e-6), 0)
Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA").save(sys.argv[1])
print("ok")
