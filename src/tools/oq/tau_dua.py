# Tàu dừa rớt trên sân (Link 11-23 "vẽ lại lá dừa 6px"): vẽ từng điểm ảnh, 6 px / đơn vị css.
# ra ui/img/oq/tau0.webp (ngọn quay phải) + tau1.webp (ngọn quay trái), cùng hướng nắng trên-trái.
# tau.json: dài cuống theo px (để code đổi ra css). chạy: python3 tools/oq/tau_dua.py <thư mục ra> [6]
import sys, os, json, math
import numpy as np
from PIL import Image, ImageFilter
OUT = sys.argv[1]; PX = float(sys.argv[2]) if len(sys.argv) > 2 else 6.0
LN = int(340 * PX)            # dài tối đa ~340 css (95 cm khi ô to nhất)
W, H = int(LN * 1.08), int(LN * 0.62)
rng = np.random.default_rng(23)
LIG = np.array([-0.55, -0.65, 0.52]); LIG /= np.linalg.norm(LIG)
def hsl(h, s, l):
	import colorsys
	return np.array(colorsys.hls_to_rgb(h / 360, l / 100, s / 100))
def rachis(t):     # tâm cuống theo t 0 (gốc) .. 1 (ngọn); cong nhẹ
	x = -LN / 2 + LN * t
	y = math.sin(t * math.pi) * -LN * 0.05 + t * t * LN * 0.035
	return np.array([x + W / 2 - LN * 0.0, y + H / 2])
def rtan(t):
	d = rachis(min(1, t + 1e-3)) - rachis(max(0, t - 1e-3)); return d / np.linalg.norm(d)
def paint(mirror):
	col = np.zeros((H, W, 3), np.float32); al = np.zeros((H, W), np.float32)
	r = np.random.default_rng(7)
	yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
	leaves = []
	n = 44
	for i in range(n):
		t = 0.1 + i / n * 0.88
		for side in (-1, 1):
			if r.random() < 0.06: continue
			tt = t + r.normal(0, 0.004)
			ll = LN * (0.25 * math.sin(min(1, tt * 1.18) * math.pi) ** 0.8 + 0.045) * (0.85 + r.random() * 0.3)
			# góc lá so với cuống, xuôi về ngọn; bên dưới (side=1) xoè rộng hơn vì nằm bẹp
			ang = (1.38 + r.random() * 0.4 + (0.12 if side > 0 else -0.06)) * side
			dry = r.random() < 0.22 or tt > 0.93 or (tt < 0.2 and r.random() < 0.5)
			leaves.append((tt, side, ll, ang, dry, r.random(), r.random()))
	# lá xa cuống (bên trên) vẽ trước, lá dưới đè lên; cuống vẽ sau cùng
	leaves.sort(key=lambda L: (L[1], L[0]))
	for (t, side, ll, ang, dry, q1, q2) in leaves:
		p0 = rachis(t); tg = rtan(t)
		a = math.atan2(tg[1], tg[0]) + ang * 0.62
		ax = np.array([math.cos(a), math.sin(a)]); nx = np.array([-ax[1], ax[0]])
		wd = ll * (0.03 + q1 * 0.01)
		droop = ll * (0.03 + q2 * 0.07) * side          # cong xuôi
		x0, x1 = p0[0] + min(0, ax[0] * ll) - wd * 2 - abs(droop), p0[0] + max(0, ax[0] * ll) + wd * 2 + abs(droop)
		y0, y1 = p0[1] + min(0, ax[1] * ll) - wd * 2 - abs(droop), p0[1] + max(0, ax[1] * ll) + wd * 2 + abs(droop)
		X0, X1 = max(0, int(x0)), min(W, int(x1) + 1); Y0, Y1 = max(0, int(y0)), min(H, int(y1) + 1)
		if X1 <= X0 or Y1 <= Y0: continue
		dx = xx[Y0:Y1, X0:X1] - p0[0]; dy = yy[Y0:Y1, X0:X1] - p0[1]
		u = dx * ax[0] + dy * ax[1]; v = dx * nx[0] + dy * nx[1]
		s = np.clip(u / ll, 0, 1)
		v = v - droop * s * s
		half = wd * np.where(s < 0.08, 0.35 + s / 0.08 * 0.65, np.clip((1 - s) / 0.92, 0, 1) ** 0.75)
		inside = np.clip(half - np.abs(v) + 0.5, 0, 1) * (u > -1) * (u < ll)
		if dry:   # lá khô: tước sợi ở nửa ngọn, mép xơ
			fr = (np.sin(v / max(1.0, wd) * 9 + q1 * 6) > 0.55 - 0.9 * np.clip(s - 0.55, 0, 1)) & (s > 0.5)
			inside = inside * np.where(fr, 0.0, 1.0)
		if inside.max() <= 0: continue
		# màu: xanh lá dừa già, ngả vàng ở mép; khô = nâu rơm
		if dry:
			base = hsl(36 + q1 * 10, 42 + q2 * 18, 50 + q1 * 10)
		else:
			base = hsl(68 + q1 * 20, 40 + q2 * 18, 30 + q1 * 9)
		vn = v / np.maximum(half, 1e-3)
		# gấp chữ V: nửa hướng nắng sáng hơn; gân giữa sáng mảnh
		nrm_x = np.where(vn > 0, 1, -1) * 0.22
		nv = np.stack([nrm_x * nx[0], nrm_x * nx[1], np.ones_like(vn)], -1); nv /= np.linalg.norm(nv, axis=-1, keepdims=True)
		lam = 0.42 + 0.58 * np.clip(nv @ LIG, 0, 1)
		rib = np.exp(-(v / max(1.0, wd * 0.06)) ** 2) * 0.12
		strk = (np.sin(v / max(1.0, wd) * 14 + q2 * 9) * 0.5 + 0.5) * 0.06
		tipy = np.clip((s - 0.75) / 0.25, 0, 1) * (0.0 if dry else 0.25)
		c = base[None, None, :] * lam[..., None] * 1.18
		c = c * (1 - tipy[..., None]) + hsl(48, 50, 52)[None, None, :] * tipy[..., None] * lam[..., None]
		c = c + rib[..., None] * np.array([1, 0.98, 0.78]) - strk[..., None]
		c = c * (0.86 + 0.14 * np.clip(1 - np.abs(vn), 0, 1))[..., None]
		# bóng lá này đổ lên lá bên dưới (lệch xuống phải)
		sh = np.zeros((Y1 - Y0, X1 - X0), np.float32); sh[:] = inside
		o = max(2, int(LN * 0.004))
		shp = np.zeros_like(sh); shp[o:, o:] = sh[:-o, :-o]
		sim = np.asarray(Image.fromarray((shp * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(o)), np.float32) / 255
		col[Y0:Y1, X0:X1] *= (1 - 0.22 * sim * (1 - inside))[..., None]
		a_ = inside
		col[Y0:Y1, X0:X1] = col[Y0:Y1, X0:X1] * (1 - a_[..., None]) + np.clip(c, 0, 1) * a_[..., None]
		al[Y0:Y1, X0:X1] = al[Y0:Y1, X0:X1] + a_ * (1 - al[Y0:Y1, X0:X1])
	# cuống: dày ở gốc, bẹ loe nâu, thuôn về ngọn, tròn có sáng một bên
	m = 900
	for k in range(m + 1):
		t = k / m
		p = rachis(t); tg = rtan(t); nn = np.array([-tg[1], tg[0]])
		rw = LN * (0.005 + 0.016 * (1 - t) ** 1.8 + (0.03 * (1 - t / 0.09) ** 1.5 if t < 0.09 else 0))
		X0, X1 = max(0, int(p[0] - rw - 3)), min(W, int(p[0] + rw + 4)); Y0, Y1 = max(0, int(p[1] - rw - 3)), min(H, int(p[1] + rw + 4))
		dx = xx[Y0:Y1, X0:X1] - p[0]; dy = yy[Y0:Y1, X0:X1] - p[1]
		v = dx * nn[0] + dy * nn[1]; u = dx * tg[0] + dy * tg[1]
		ins = np.clip(rw - np.sqrt(v * v + (u * 3) ** 2) + 0.5, 0, 1)
		vn = np.clip(v / rw, -1, 1)
		flat = 0.55 + 0.3 * min(1, t / 0.1)        # bẹ dẹt, cuống tròn vừa
		nz = np.sqrt(1 - (vn * flat) ** 2)
		lam = 0.45 + 0.55 * np.clip(vn * flat * (nn[0] * LIG[0] + nn[1] * LIG[1]) + nz * LIG[2], 0, 1)
		bz = float(np.clip((0.13 - t) / 0.08, 0, 1)) ** 1.5      # bẹ nâu xơ, chuyển dần sang cuống
		be = hsl(32, 34, 40) * (0.88 + 0.12 * np.sin(vn * 40)[..., None] ** 2)
		cu = hsl(50 - 14 * t, 40, 47 - 5 * t) * (0.96 + 0.04 * np.sin(vn * 9)[..., None])
		base = be * bz + cu * (1 - bz)
		if t < 0.012:     # đầu bẹ gãy xơ, không cắt tròn
			ins = ins * (np.sin(vn * 23 + 1.3) * 0.5 + 0.5 > t / 0.012 * 0.9)
		c = base * lam[..., None] * 1.12
		col[Y0:Y1, X0:X1] = col[Y0:Y1, X0:X1] * (1 - ins[..., None]) + np.clip(c, 0, 1) * ins[..., None]
		al[Y0:Y1, X0:X1] = np.maximum(al[Y0:Y1, X0:X1], ins)
	# col đang là màu đã nhân alpha (phủ lên nền đen) -> chia lại cho alpha, không thì mép lá ra viền đen lởm chởm (Link 11-23)
	rgb = np.where(al[..., None] > 1e-3, col / np.maximum(al[..., None], 1e-3), 0)
	img = np.dstack([np.clip(rgb, 0, 1) * 255, np.clip(al, 0, 1) * 255]).astype(np.uint8)
	im = Image.fromarray(img, "RGBA")
	bb = im.getbbox(); im = im.crop(bb)
	return im, bb
def go():
	os.makedirs(OUT, exist_ok=True)
	im0, bb = paint(False)
	# ngọn quay trái: vẽ lại hình gương nhưng giữ nắng trên-trái -> gương hình học qua x, lật lại phần sáng
	global rachis, rtan
	r0, t0 = rachis, rtan
	rachis = lambda t: (lambda p: np.array([W - p[0], p[1]]))(r0(t))
	rtan = lambda t: (lambda d: np.array([-d[0], d[1]]))(t0(t))
	im1, bb1 = paint(True)
	im0.save(os.path.join(OUT, "tau0.webp"), "WEBP", quality=90, alpha_quality=100, method=6)
	im1.save(os.path.join(OUT, "tau1.webp"), "WEBP", quality=90, alpha_quality=100, method=6)
	# điểm gốc/ngọn của cuống trong ảnh
	b0 = r0(0) - np.array(bb[:2]); e0 = r0(1) - np.array(bb[:2])
	b1 = rachis(0) - np.array(bb1[:2]); e1 = rachis(1) - np.array(bb1[:2])
	json.dump({"px": PX, "ln": LN, "tau0": {"size": im0.size, "base": b0.tolist(), "tip": e0.tolist()},
		"tau1": {"size": im1.size, "base": b1.tolist(), "tip": e1.tolist()}}, open(os.path.join(OUT, "tau.json"), "w"))
	print(im0.size, im1.size)
go()
