import sys, numpy as np
from PIL import Image, ImageFilter
src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGBA'); a = np.asarray(im).astype(np.float32) / 255
rgb, al = a[..., :3], a[..., 3]
# màu đậm + tươi hơn: tăng độ bão hoà, hạ sáng nhẹ
l = (rgb * [0.299, 0.587, 0.114]).sum(-1, keepdims=True)
rgb = np.clip(l + (rgb - l) * 1.9, 0, 1) * 0.86
# phấn dày hơn: ít lỗ rỗ
al2 = 1 - (1 - al) ** 2.2
# bóng đổ mềm dưới quân cho nổi lên mặt phản
A = Image.fromarray((al2 * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))
sh = np.roll(np.roll(np.asarray(A).astype(np.float32) / 255, 4, 0), 3, 1) * 0.45
out_a = al2 + sh * (1 - al2)
col = (rgb * al2[..., None] + np.array([0.12, 0.07, 0.03]) * (sh * (1 - al2))[..., None]) / np.maximum(out_a, 1e-4)[..., None]
o = np.dstack([np.clip(col, 0, 1), out_a])
Image.fromarray((o * 255).round().astype(np.uint8)).save(dst, lossless=True, quality=100, method=6)
