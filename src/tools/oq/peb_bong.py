# Bóng bám đất cho từng viên sỏi/quan (Link 11-23 "sỏi lơ lửng"): mỗi ảnh peb/pN, qN ra
#  sN = bóng trên đất theo đúng hình viên (sát đen + đổ ngắn xuống dưới phải + quầng mờ), khung rộng 1.5 lần, 1/4 độ phân giải
#  aN = lớp tối mép dưới phải ngay trên thân viên (chỗ khuất sát đất), khung bằng ảnh, 1/2 độ phân giải
# chạy: python3 tools/oq/peb_bong.py src/oaq/ui/img/oq/peb
import sys, os, glob
import numpy as np
from PIL import Image, ImageFilter
D = sys.argv[1]
SUN = np.array([0.64, 0.77])
def blur(a, r):
	return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255
def shift(a, dx, dy):
	im = Image.fromarray((a * 255).astype(np.uint8))
	return np.asarray(im.transform(im.size, Image.AFFINE, (1, 0, -dx, 0, 1, -dy), Image.BILINEAR), np.float32) / 255
def save(a, path, col):
	h, w = a.shape
	o = np.zeros((h, w, 4), np.uint8)
	o[..., 0], o[..., 1], o[..., 2] = col
	o[..., 3] = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
	Image.fromarray(o).save(path, "WEBP", lossless=True)
for f in sorted(glob.glob(os.path.join(D, "[pq]*.webp"))):
	b = os.path.basename(f)[:-5]
	im = Image.open(f).convert("RGBA")
	W = im.size[0]
	# bóng: 1/4, khung 1.5W
	w4 = W // 4
	a = np.asarray(im.resize((w4, w4), Image.LANCZOS), np.float32)[..., 3] / 255
	P = w4 // 4
	c = np.zeros((w4 + 2 * P, w4 + 2 * P), np.float32)
	c[P:P + w4, P:P + w4] = a
	u = w4 * 0.75  # cỡ thân viên
	cont = blur(shift(c, u * 0.02, u * 0.026), u * 0.018) * 0.6
	acc = np.zeros_like(c)
	n = 8
	for k in range(n + 1):
		t = k / n * 0.11 * u
		acc = np.maximum(acc, shift(c, SUN[0] * t, SUN[1] * t))
	castv = blur(acc, u * 0.04) * 0.34
	amb = blur(c, u * 0.09) * 0.1
	s = 1 - (1 - cont) * (1 - castv) * (1 - amb)
	save(s, os.path.join(D, "s" + b[1:] + ".webp" if b[0] == "p" else "t" + b[1:] + ".webp"), (30, 17, 5))
	# lớp tối trên thân: 1/2
	w2 = W // 2
	a2 = np.asarray(im.resize((w2, w2), Image.LANCZOS), np.float32)[..., 3] / 255
	u2 = w2 * 0.75
	d = u2 * 0.075
	out = 1 - blur(shift(a2, -SUN[0] * d, -SUN[1] * d), u2 * 0.035)
	ao = a2 * np.clip(out, 0, 1) ** 1.2 * 0.36
	save(ao, os.path.join(D, ("a" if b[0] == "p" else "b") + b[1:] + ".webp"), (24, 14, 6))
	print(b, end=" ", flush=True)
print()
