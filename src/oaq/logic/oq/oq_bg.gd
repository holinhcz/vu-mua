extends Node2D
# Ô ĂN QUAN: lớp nền tĩnh (buildBG của o-an-quan/src/game.js): đất sân, hiên gạch tàu, cỏ, dép, lu, chổi chà, tàu dừa,
# nón lá, lá khô, hai cái rổ, bàn ô ăn quan kẻ phấn (10 ô dân, 2 ô quan hình bán nguyệt, gạch phấn xanh / hồng dưới hàng
# mỗi bên). Vẽ một lần trong SubViewport rồi chụp thành ảnh (không vẽ lại mỗi khung).
# Đơn vị: css px của bản web (nhân K ra điểm ảnh thật). Cùng hạt giống ngẫu nhiên (mulberry32 20261028) như web.

const A := preload("res://logic/oq/oq_art.gd")
const SUN := Vector2(0.64, 0.77)

var g      # oq_game (L, map(), lg(), home_spot)
var K := 1.0
var _a := 0

func _rng_seed(v: int) -> void:
	_a = v & 0xffffffff

static func _imul(x: int, y: int) -> int:
	x &= 0xffffffff
	y &= 0xffffffff
	return ((x * (y & 0xffff)) + (((x * (y >> 16)) & 0xffff) << 16)) & 0xffffffff

func rng() -> float:   # mulberry32 như web
	_a = (_a + 0x6D2B79F5) & 0xffffffff
	var t := _imul(_a ^ (_a >> 15), 1 | _a)
	t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xffffffff) ^ t
	return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

# ------------------------------------------------------------ vẽ có biến đổi (css px)
func _T(xf := Transform2D.IDENTITY) -> void:
	draw_set_transform_matrix(Transform2D(0.0, Vector2(K, K), 0.0, Vector2.ZERO) * xf)

static func xf(pos: Vector2, rot := 0.0, sc := Vector2.ONE) -> Transform2D:
	return Transform2D(rot, sc, 0.0, pos)

func vgrad(r: Rect2, stops: Array, horiz := false) -> void:
	# gradient thẳng theo chiều dọc (hoặc ngang) nhiều mốc
	for i in range(1, stops.size()):
		var t0: float = stops[i - 1][0]
		var t1: float = stops[i][0]
		var c0: Color = stops[i - 1][1]
		var c1: Color = stops[i][1]
		var pts: PackedVector2Array
		var cols := PackedColorArray([c0, c0, c1, c1])
		if horiz:
			var x0 := r.position.x + r.size.x * t0
			var x1 := r.position.x + r.size.x * t1
			pts = PackedVector2Array([Vector2(x0, r.end.y), Vector2(x0, r.position.y), Vector2(x1, r.position.y), Vector2(x1, r.end.y)])
		else:
			var y0 := r.position.y + r.size.y * t0
			var y1 := r.position.y + r.size.y * t1
			pts = PackedVector2Array([Vector2(r.position.x, y0), Vector2(r.end.x, y0), Vector2(r.end.x, y1), Vector2(r.position.x, y1)])
		draw_polygon(pts, cols)

var _gt := {}
func radial_tex(stops: Array) -> GradientTexture2D:
	var k := str(stops)
	if _gt.has(k):
		return _gt[k]
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	gr.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var t := GradientTexture2D.new()
	t.gradient = gr
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	_gt[k] = t
	return t

func radial(c: Vector2, r: float, stops: Array) -> void:
	draw_texture_rect(radial_tex(stops), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)

static func quad(p0: Vector2, c: Vector2, p1: Vector2, n := 12) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n + 1:
		var t := float(k) / n
		var u := 1.0 - t
		out.append(p0 * u * u + c * 2.0 * u * t + p1 * t * t)
	return out

static func cubic(p0: Vector2, c0: Vector2, c1: Vector2, p1: Vector2, n := 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n + 1:
		var t := float(k) / n
		var u := 1.0 - t
		out.append(p0 * u * u * u + c0 * 3.0 * u * u * t + c1 * 3.0 * u * t * t + p1 * t * t * t)
	return out

static func rrect(x: float, y: float, w: float, h: float, r: float, n := 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cs := [[x + w - r, y + r, -PI / 2], [x + w - r, y + h - r, 0.0], [x + r, y + h - r, PI / 2], [x + r, y + r, PI]]
	for c in cs:
		for k in n + 1:
			var a: float = c[2] + PI / 2 * k / n
			out.append(Vector2(c[0] + cos(a) * r, c[1] + sin(a) * r))
	return out

func _fill(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3:
		var tri := Geometry2D.triangulate_polygon(pts)
		if tri.is_empty():
			return
		draw_polygon(pts, PackedColorArray([col]))

static func hsl(h: float, s: float, l: float) -> Color:
	h = fposmod(h, 360.0) / 360.0
	s /= 100.0
	l /= 100.0
	var q := l * (1.0 + s) if l < 0.5 else l + s - l * s
	var p := 2.0 * l - q
	var f := func(t: float) -> float:
		t = fposmod(t, 1.0)
		if t < 1.0 / 6.0: return p + (q - p) * 6.0 * t
		if t < 0.5: return q
		if t < 2.0 / 3.0: return p + (q - p) * (2.0 / 3.0 - t) * 6.0
		return p
	return Color(f.call(h + 1.0 / 3.0), f.call(h), f.call(h - 1.0 / 3.0))

# ------------------------------------------------------------ dựng
func _draw() -> void:
	var L: Dictionary = g.L
	var W: float = L.W
	var H: float = L.H
	_rng_seed(20261028)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# đất sân: ảnh đất 9px của sân caro (Link 11-22 "lấy nền đất bên caro qua"), 9 điểm ảnh / css, lặp
	var ts := 1.0 / 9.0
	_T(xf(Vector2.ZERO, 0.0, Vector2(ts, ts)))
	draw_texture_rect_region(A.img("dat"), Rect2(0, 0, W / ts, H / ts), Rect2(0, 0, W / ts, H / ts))
	_T()
	radial(Vector2(W * 0.42, H * 0.5), maxf(W, H) * 0.75, [[0.0, Color8(255, 236, 200, 26)], [1.0, Color8(60, 35, 15, 41)]])
	_porch(L)
	var bp: Rect2 = g.board_rect(14)
	L.obst = [bp]
	for b in L.bx:
		L.obst.append(Rect2(b.x - b.z - 8, b.y - b.z - 8, 2 * b.z + 16, 2 * b.z + 16))
	for c in L.cards:
		L.obst.append((c as Rect2).grow(6))
	L.obst.append((L.tools as Rect2).grow(6))
	L.obst.append(Rect2(W - 190, H - 64, 190, 64))
	for r in L.get("tan", []):     # dưới tán xoài: không đặt đồ (bị lá che mất)
		L.obst.append(r)
	_decor(L)
	for b in L.bx:
		var D: float = b.z * 2 / 0.965
		on_ground("ro", Rect2i(), Vector2(b.x, b.y), D, D, 0.0, b.z * 0.14)   # rổ cờ gánh (Link 11-23)
	_chalk_board(L)

func hits_obst(L: Dictionary, x: float, y: float, r: float) -> bool:
	for o in L.obst:
		var q: Rect2 = o
		var cx := clampf(x, q.position.x, q.end.x)
		var cy := clampf(y, q.position.y, q.end.y)
		if Vector2(cx - x, cy - y).length() < r:
			return true
	return false

# --- hiên gạch tàu chạy dọc mép trên, bậc xi măng xuống sân
func _porch(L: Dictionary) -> void:
	var W: float = L.W
	var s: float = L.s
	var top: float = g.board_rect(0).position.y
	var ph := float(roundi(minf(maxf(30.0, minf(s * 0.78, (top - 12) * (0.7 if L.port else 0.6))), L.get("porch_max", 1e9))))
	L.porch = ph
	var k := s * 0.6 * 2 / 512.0
	var tx := -rng() * s
	var ty := ph - s * 0.6 * 0.08
	_T(xf(Vector2(tx, ty), 0.0, Vector2(k, k)))
	draw_texture_rect_region(A.img("gach"), Rect2(-tx / k, -ty / k, W / k, ph / k), Rect2(-tx / k, -ty / k, W / k, ph / k))
	_T()
	vgrad(Rect2(0, 0, W, ph), [[0.0, Color8(40, 20, 8, 56)], [0.5, Color8(40, 20, 8, 10)], [1.0, Color8(40, 20, 8, 0)]])
	var sh := maxf(6.0, s * 0.09)
	vgrad(Rect2(0, ph - sh, W, sh), [[0.0, Color("#cfc4ae")], [0.6, Color("#b9ac93")], [1.0, Color("#8e806a")]])
	var x := 0.0
	while x < W:
		if rng() < 0.3:
			var c := Color8(84, 104, 52) if rng() < 0.4 else Color8(90, 72, 52)
			c.a = 0.15 + rng() * 0.25
			var yy := ph - sh * (0.2 + rng() * 0.8)
			draw_rect(Rect2(x, yy, 3 + rng() * 6, 2 + rng() * 3), c)
		x += 6
	vgrad(Rect2(0, ph, W, s * 0.2), [[0.0, Color8(40, 22, 8, 107)], [1.0, Color8(40, 22, 8, 0)]])

func on_ground(name: String, cell: Rect2i, at: Vector2, w: float, h: float, rot: float, ht: float, flip := false, ox = null, oy = null, shk := 1.0) -> void:
	A.on_ground(self, K, name, cell, at, w, h, rot, ht, flip, ox, oy, 1.0, shk)

# --- đồ trang trí
func _find_spot(L: Dictionary, r: float, inside: bool, pref: Callable):
	var best = null
	var bs := -1e9
	var st := maxf(10.0, r * 0.25)
	var y := r if inside else r * 0.3
	while y <= L.H - (r if inside else r * 0.3):
		var x := r if inside else r * 0.3
		while x <= L.W - (r if inside else r * 0.3):
			if not hits_obst(L, x, y, r):
				var sc: float = pref.call(x, y) + rng() * 4
				if sc > bs and sc > -1e8:
					bs = sc
					best = Vector2(x, y)
			x += st
		y += st
	return best

func _decor(L: Dictionary) -> void:
	var W: float = L.W
	var H: float = L.H
	var s: float = L.s
	var ph: float = L.porch
	var cx := W / 2
	var cy := H / 2
	var far := func(x: float, y: float) -> float: return Vector2(x - cx, y - cy).length()
	var used := func(x: float, y: float, r: float) -> void: L.obst.append(Rect2(x - r, y - r, 2 * r, 2 * r))
	var free := func(x: float, y: float, r: float) -> bool: return not hits_obst(L, x, y, r)
	# cỏ dọc mép sân (không mọc trên gạch hiên)
	var per := 2 * (W + H)
	var nT := roundi(per / 60)
	for k in nT:
		var t := rng() * per
		var x: float
		var y: float
		if t < W:
			x = t; y = -4
		elif t < W + H:
			x = W + 4; y = t - W
		elif t < 2 * W + H:
			x = 2 * W + H - t; y = H + 4
		else:
			x = -4; y = per - t
		if y < ph + 12 or hits_obst(L, x, y, 26):
			continue
		_grass(x, y, 18 + rng() * 26)
	var CM := s / 33.0
	# Link 11-23: màn ngang -> tàu dừa nằm góc dưới phải, bẹ ló ra ngoài mép màn, ngọn chĩa vô sân (đặt trước gà, lá khô)
	# Link 11-23 (nhận xét 4): màn dọc rộng (768x1024, 860x1000) -> tàu dừa nằm sân trái, bẹ ló mép trái, cho sân trái đỡ trống
	var corner_fr := false
	var fl0 := minf(maxf(W, H) * 0.4, 95 * CM)
	if not L.port:
		var bases := []
		for bx in [0.08, 0.0, 0.16, -0.06]:
			for by in [0.06, -0.04, 0.14, -0.12]:
				bases.append([Vector2(W + fl0 * bx, H + fl0 * by), absf(bx - 0.05) * 20 + absf(by) * 10])
		corner_fr = _corner_frond(L, fl0, bases, [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8], 1, 0.45)
	elif W >= 700:
		var bases := []
		for fy in [0.62, 0.55, 0.7, 0.48, 0.78]:
			for bx in [-0.06, 0.0, -0.12]:
				bases.append([Vector2(fl0 * bx, H * fy), absf(fy - 0.62) * 20 + absf(bx + 0.06) * 20])
		corner_fr = _corner_frond(L, fl0, bases, [-0.35, -0.2, -0.5, 0.2, 0.35, -0.65], 0, -0.3)
	var sp = null
	# chỗ con gà mái đi dạo: một dải sân trống (đồ khác né ra)
	g.home_spot = null
	# gà còn né dải sân cạnh hàng mình, chỗ kẻ mũi tên chọn hướng và chữ gợi ý
	var ba: Vector2 = g.map(-0.3, 2)
	var bb: Vector2 = g.map(5.3, 2 + (1.15 if L.port else 0.55))
	var hint_band := Rect2(minf(ba.x, bb.x), minf(ba.y, bb.y), absf(bb.x - ba.x), absf(bb.y - ba.y))
	var st_band := [true]
	var box_free := func(x: float, y: float, hw: float, hh: float) -> bool:
		if y - hh < ph + 6:
			return false
		var lst: Array = L.obst + ([hint_band] if st_band[0] else [])
		for o in lst:
			var q: Rect2 = o
			if x + hw > q.position.x and x - hw < q.end.x and y + hh > q.position.y and y - hh < q.end.y:
				return false
		return true
	var done := false
	# ưu tiên gà nằm trọn trong màn; hết chỗ mới cho ló ra mép màn (cỡ thật, không thu nhỏ cho vừa: luật v7)
	# hb = [phần được ló ra mép màn, né dải gợi ý, dải rộng đủ cho gà quay ngang]: thử chỗ rộng trọn trong màn trước
	# Link 11-23 (nhận xét 3): điện thoại dọc rất dài (360x860, 412x915) không có khoảng sân cho gà cỡ thật -> bỏ gà (luật v7: không thu nhỏ)
	var hen_ok: bool = not (L.port and H > W * 2.0)
	# Link 11-23 (nhận xét 7): màn ngang không cho gà ló ra mép màn (bị cắt nửa thân) -> không có chỗ trọn trong màn thì thôi gà
	# Link 11-23: 1280x720, 1600x900 -> gà cỡ như 1440x900 (f 32) đi dải trống dưới giữa rổ và tàu dừa (dải hẹp, chồng chỗ mũi tên gợi ý)
	var hbs := [[0.0, true, true], [0.0, false, true], [0.0, true, false]] + ([[0.0, false, false, [32]]] if not L.port else [[0.22, true, false], [0.22, false, false]])
	for hb in (hbs if hen_ok else []):
		if done:
			break
		for f in (hb[3] if hb.size() > 3 else [40, 36, 32]):
			st_band[0] = hb[1]
			var hl: float = f * CM
			var jr := hl * 0.06
			var ha := hl * 0.72   # ảnh gà caro (D = dài / 0.6) to hơn hộp cũ: hộp ôm hết hình
			var hc := maxf(hl * 0.3 + jr, ha * 0.92) if hb[2] else hl * 0.3 + jr   # gà quay đủ hướng (mổ, ngó): bề ngang dải cũng phải vừa thân gà
			var best = null
			var bs := -1e9
			var st := maxf(8.0, hc * 0.5)
			var lim := hl * 2.2
			var d := 8.0
			var hg: float = hb[0] * hl
			for ax in [0, 1]:
				var hw := hc if ax else ha
				var hh := ha if ax else hc
				var y := ph + 6 + hh
				while y <= H - hh + hg:
					var x := hw - hg
					while x <= W - hw + hg:
						if box_free.call(x, y, hw, hh):
							var ok := func(t: float) -> bool:
								var px: float = x + (0.0 if ax else t)
								var py: float = y + (t if ax else 0.0)
								return px >= hw - hg and px <= W - hw + hg and py <= H - hh + hg and box_free.call(px, py, hw, hh)
							var a0 := 0.0
							var a1 := 0.0
							while -a0 < lim and ok.call(a0 - d):
								a0 -= d
							while a1 < lim and ok.call(a1 + d):
								a1 += d
							var m := (a0 + a1) / 2
							var mx: float = x + (0.0 if ax else m)
							var my: float = y + (m if ax else 0.0)
							var sc: float = (a1 - a0) - absf(far.call(mx, my) - minf(W, H) * 0.4) * 0.15 - (12 if ax else 0) + rng() * 6
							if sc > bs:
								bs = sc
								best = {"x": mx, "y": my, "ax": ax, "half": (a1 - a0) / 2, "hw": hw, "hh": hh}
						x += st
					y += st
			if best != null and best.half * 2 > hl * 0.3:
				g.home_spot = {"x": best.x, "y": best.y, "ax": best.ax, "half": best.half, "r": jr, "cr": hc, "len": hl}
				var t: float = -best.half
				while t <= best.half + 0.1:
					var px: float = best.x + (0.0 if best.ax else t)
					var py: float = best.y + (t if best.ax else 0.0)
					L.obst.append(Rect2(px - best.hw * 1.05, py - best.hh * 1.05, best.hw * 2.1, best.hh * 2.1))
					t += ha * 0.5
				done = true
				break
	# Link 11-22: bỏ dép, lu nước, nón lá
	# Link 11-23: xóa cây chổi
	# tàu dừa rớt ngang một góc sân trống
	var fl := minf(maxf(W, H) * 0.4, 95 * CM)
	var fb = null
	var fs := -1e9
	for k in (0 if corner_fr else 500):
		var x := rng() * W
		var y := ph + rng() * (H - ph)
		var ang := (rng() - 0.5) * 2.2     # ảnh nắng trên-trái: chỉ xoay vừa, ngọn trái/phải bằng 2 ảnh
		var ok := true
		var on := 0
		var t := -0.5
		while t <= 0.5 and ok:
			var px := x + cos(ang) * fl * t
			var py := y + sin(ang) * fl * t
			if px > 0 and px < W and py > 0 and py < H:
				on += 1
				if hits_obst(L, px, py, fl * 0.12) or py < ph:
					ok = false
			t += 0.1
		if not ok or on < 4:
			continue
		var sc: float = far.call(x, y) + (11 - on) * 20 + rng() * 30
		if sc > fs:
			fs = sc
			fb = [x, y, ang]
	if fb != null:
		_frond(fb[0], fb[1], fl, fb[2], 1 if rng() < 0.5 else 0)
		var t := -0.5
		while t <= 0.5:
			used.call(fb[0] + cos(fb[2]) * fl * t, fb[1] + sin(fb[2]) * fl * t, fl * 0.2)
			t += 0.125
	# lá khô (lá bàng, lá xoài): Link 11-23 (nhận xét 5) bớt còn nửa, gom thành 2-3 cụm nhỏ thay vì rải đều
	var want := mini(6, roundi(W * H / (s * s * 6.4)))
	var placed := 0
	var spots := []
	var nclu := 3 if want >= 5 else 2
	var centres := []
	if not L.port and W > H * 2.0:
		# Link 11-23 (nhận xét 8): màn rất dài -> một cụm lá khô ở khoảng sân trống bên phải bàn
		var br2: Rect2 = g.board_rect(14)
		for k in 200:
			var lx := br2.end.x + 30 + rng() * maxf(1.0, W - br2.end.x - 60)
			var ly := H * (0.3 + rng() * 0.4)
			if not hits_obst(L, lx, ly, s * 0.25):
				centres.append(Vector2(lx, ly))
				break
	for k in 400:
		if centres.size() >= nclu:
			break
		var lx := rng() * W
		var ly := ph + rng() * (H - ph)
		if hits_obst(L, lx, ly, s * 0.3):
			continue
		var far_ok := true
		for c in centres:
			if (c as Vector2).distance_to(Vector2(lx, ly)) < minf(W, H) * 0.35:
				far_ok = false
				break
		if far_ok:
			centres.append(Vector2(lx, ly))
	for k in 400:
		if placed >= want or centres.is_empty():
			break
		var c: Vector2 = centres[placed % centres.size()] if k < 200 else centres[int(rng() * centres.size())]
		var a2 := rng() * TAU
		var rr := s * (0.15 + rng() * 0.45)
		var x := c.x + cos(a2) * rr
		var y := c.y + sin(a2) * rr
		var ln := (15 + rng() * 7) * CM
		var near := false
		for p in spots:
			if Vector2(p.x - x, p.y - y).length() < ln * 0.55:
				near = true
				break
		if hits_obst(L, x, y, ln * 0.45) or near or x < 0 or x > W or y < ph or y > H:
			continue
		_leaf(x, y, ln, rng() * 6.28, "bang" if rng() < 0.5 else "xoai")
		placed += 1
		spots.append(Vector2(x, y))
		L.obst.append(Rect2(x - ln * 0.35, y - ln * 0.35, ln * 0.7, ln * 0.7))

func _grass(x: float, y: float, sz: float) -> void:
	var n := 6 + int(rng() * 6)
	var blades := []
	for k in n:
		var a := rng() * TAU
		var l := sz * (0.55 + rng() * 0.6)
		var w := sz * 0.07
		var bend := (rng() - 0.5) * 0.9
		var e := Vector2(cos(a), sin(a)) * l
		var m := Vector2(cos(a + bend), sin(a + bend)) * l * 0.55
		var hue := 78 + rng() * 30
		var lit := 30 + rng() * 14
		var col := hsl(hue, 42 + rng() * 18, lit)
		var p0 := Vector2(-sin(a) * w, cos(a) * w)
		var p1 := Vector2(sin(a) * w, -cos(a) * w)
		var pts := quad(p0, m, e, 8)
		var back := quad(e, m, p1, 8)
		back.remove_at(0)
		pts.append_array(back)
		blades.append([pts, col])
	_T(xf(Vector2(x + 2, y + 3)))
	for b in blades:
		_fill(b[0], Color(0.118, 0.078, 0.02, 0.25))
	_T(xf(Vector2(x, y)))
	for b in blades:
		_fill(b[0], b[1])
	_T()

# tàu dừa đặt theo chỗ chọn sẵn: bases = gốc cuống (có thể ngoài màn), angs = góc xoay, v = ảnh (0 ngọn phải, 1 ngọn trái)
func _corner_frond(L: Dictionary, fl0: float, bases: Array, angs: Array, v: int, ang0: float) -> bool:
	var W: float = L.W
	var H: float = L.H
	var corner_btn := Rect2(W - 190, H - 64, 190, 64)
	var keep: Array = L.obst.filter(func(o): return o != corner_btn)   # lá nằm dưới đất, chồng dưới chỗ nút góc được
	var bestc = null
	var bsc := -1e9
	for ang in angs:
		var dir := Vector2(cos(ang), sin(ang)) * (1.0 if v == 0 else -1.0)
		for bi in bases.size():
			var b0: Vector2 = bases[bi][0]
			var ok := true
			var on := 0
			for i in 12:
				var t := 0.12 + i / 11.0 * 0.88
				var p := b0 + dir * fl0 * t
				if p.x > 0 and p.x < W and p.y > 0 and p.y < H:
					on += 1
				for o in keep:
					var q: Rect2 = o
					if q.grow(fl0 * 0.13).has_point(p):
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var sc: float = on * 10.0 - absf(ang - ang0) * 8 - bases[bi][1]
			if sc > bsc:
				bsc = sc
				bestc = [b0, dir, ang]
	if bestc == null:
		return false
	var mid: Vector2 = bestc[0] + bestc[1] * fl0 * 0.5
	_frond(mid.x, mid.y, fl0, bestc[2], v)
	for i in 8:
		var p: Vector2 = bestc[0] + bestc[1] * fl0 * (0.1 + i * 0.1)
		var r := fl0 * (0.17 - i * 0.012)   # lá ngắn dần về ngọn
		L.obst.append(Rect2(p.x - r, p.y - r, r * 2, r * 2))
	return true

# tàu dừa = ảnh 6px vẽ sẵn (tools/oq/tau_dua.py, Link 11-23); (x, y) = giữa cuống, ln = dài cuống
const TAU_IMG := {0: [Vector2(2082, 1146), Vector2(37.5, 632.0), Vector2(2077.5, 703.4)], 1: [Vector2(2082, 1146), Vector2(2043.5, 632.0), Vector2(3.5, 703.4)]}
func _frond(x: float, y: float, ln: float, ang: float, v: int) -> void:
	var d: Array = TAU_IMG[v]
	var k: float = ln / (d[2] - d[1]).length()
	var mid: Vector2 = (d[1] + d[2]) * 0.5 * k
	# Link 11-23 "đụ má lá dừa": tàu nằm bẹp sát đất -> không bóng đổ lệch (thành cái bóng thứ hai), chỉ bóng sát nhạt
	# Link 11-23 "làm bóng mờ lại": 1 ảnh bóng đã blur sẵn (tools/oq/tau_bong.py), mịn, nhạt, lệch nhẹ theo nắng, không đốm
	var sp := 60.0 * k
	var so: Vector2 = A.SUN * ln * 0.035
	draw_set_transform_matrix(Transform2D(0.0, Vector2(K, K), 0.0, Vector2.ZERO) * Transform2D(0.0, so) * Transform2D(ang, Vector2(x, y)))
	draw_texture_rect(A.img("tau_s%d" % v), Rect2(-mid.x - sp, -mid.y - sp, d[0].x * k + sp * 2, d[0].y * k + sp * 2), false, Color(A.SHC, 0.36))
	on_ground("tau%d" % v, Rect2i(), Vector2(x, y), d[0].x * k, d[0].y * k, ang, 0.0, false, -mid.x, -mid.y, 0.0)

func _leaf(x: float, y: float, ln: float, ang: float, kind: String) -> void:
	var w := ln * 0.5 if kind == "bang" else ln * 0.2
	var curl := (rng() - 0.5) * 0.25
	var a := cubic(Vector2(-ln / 2, 0), Vector2(-ln * 0.3, -w * (0.9 + curl)), Vector2(ln * 0.25, -w * (0.75 - curl)), Vector2(ln / 2, 0), 14)
	var b := cubic(Vector2(ln / 2, 0), Vector2(ln * 0.25, w * (0.8 + curl)), Vector2(-ln * 0.3, w * (0.85 - curl)), Vector2(-ln / 2, 0), 14)
	b.remove_at(0)
	b.remove_at(b.size() - 1)
	a.append_array(b)
	var base := xf(Vector2(x, y), ang)
	var so := base.basis_xform_inv(Vector2(ln * 0.012, ln * 0.016))
	_T(base * Transform2D(0.0, so))
	_fill(a, Color(0.125, 0.07, 0.02, 0.45))
	_T(base)
	# Link 11-23 (nhận xét 5): lá bàng khô nâu, bớt đỏ cam rực
	var pal := [[134, 80, 46], [150, 104, 60], [112, 74, 46]] if kind == "bang" else [[176, 146, 70], [146, 116, 56], [196, 168, 98]]
	var c: Array = pal[int(rng() * pal.size())]
	var c0 := Color8(c[0] + 18, c[1] + 16, c[2] + 8)
	var c1 := Color8(c[0] - 22, c[1] - 20, c[2] - 12)
	# gradient chéo từ góc trên trái xuống dưới phải
	var cols := PackedColorArray()
	var d := Vector2(ln, 2 * w)
	for p in a:
		var t := clampf(((p + Vector2(ln / 2, w)).dot(d)) / d.length_squared(), 0.0, 1.0)
		cols.append(c0.lerp(c1, t))
	if not Geometry2D.triangulate_polygon(a).is_empty():
		draw_polygon(a, cols)
	for k in 6:
		var px := (rng() - 0.5) * ln * 0.8
		var py := (rng() - 0.5) * w
		var rr := ln * 0.03 * (1 + rng())
		if Geometry2D.is_point_in_polygon(Vector2(px, py), a):
			draw_circle(Vector2(px, py), rr, Color8(70, 40, 15, 46), true, -1.0, true)
	# ánh sáng nửa trên
	var top := PackedVector2Array()
	var cols2 := PackedColorArray()
	for p in a:
		if p.y < -w * 0.4 + w * 1.6 - w:   # nửa trên lá (fillRect -w*2 .. -w*0.4)
			top.append(p)
	draw_polyline(PackedVector2Array([Vector2(-ln / 2 - ln * 0.12, 0), Vector2(ln * 0.46, 0)]), Color8(255, 235, 195, 115), maxf(1.0, ln * 0.02), true)
	for k in range(1, 6):
		var px := -ln / 2 + k * ln / 6.5
		for sd in [-1, 1]:
			draw_polyline(quad(Vector2(px, 0), Vector2(px + ln * 0.06, sd * w * 0.35), Vector2(px + ln * 0.12, sd * w * 0.6), 6), Color8(255, 235, 195, 77), maxf(0.6, ln * 0.009), true)
	_T()

# --- bàn kẻ phấn: hai hàng năm ô dân, hai ô quan nửa vòng ở hai đầu
const QW := 0.95

func chalk_lines() -> Array:
	var segs := []
	var line := func(x0: float, y0: float, x1: float, y1: float) -> void:
		var pts := []
		var n := maxi(6, roundi(Vector2(x1 - x0, y1 - y0).length() * 14))
		for k in n + 1:
			pts.append(Vector2(x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n))
		segs.append(pts)
	line.call(0, 0, 5, 0); line.call(0, 2, 5, 2); line.call(0, 1, 5, 1)
	for x in 6:
		line.call(x, 0, x, 2)
	for cs in [[0.0, -1.0], [5.0, 1.0]]:
		var pts := []
		for k in 41:
			var a := -PI / 2 + PI * k / 40.0
			pts.append(Vector2(cs[0] + cs[1] * cos(a) * QW, 1 + sin(a)))
		segs.append(pts)
	return segs

static func board_path(inset: float) -> PackedVector2Array:
	# viền bàn: cạnh trên, nửa elip ô quan phải, cạnh dưới, nửa elip ô quan trái
	var out := PackedVector2Array()
	out.append(Vector2(0, inset))
	for k in 25:
		var a := -PI / 2 + PI * k / 24.0
		out.append(Vector2(5 + cos(a) * (QW - inset), 1 + sin(a) * (1 - inset)))
	out.append(Vector2(0, 2 - inset))
	for k in range(1, 24):
		var a := PI / 2 + PI * k / 24.0
		out.append(Vector2(cos(a) * (QW - inset), 1 + sin(a) * (1 - inset)))
	return out

func _chalk_board(L: Dictionary) -> void:
	var s: float = L.s
	var lg: Transform2D = g.lg()
	# khoảng sân trong bàn quét láng, sáng hơn chút (bóng mờ shadowBlur của web = vài lớp loang ra ngoài)
	_T(lg)
	var bp := board_path(0.02)
	for k in 4:
		var gr := 0.3 * (k + 1) / 4.0
		var pts := PackedVector2Array()
		var c := Vector2(2.5, 1)
		for p in bp:
			var d := p - c
			pts.append(p + Vector2(signf(d.x), signf(d.y)) * gr * 0.5)
		_fill(pts, Color8(255, 238, 205, 3))
	_fill(bp, Color8(255, 238, 205, 15))
	for k in 26:
		var ccx := rng() * 6 - 0.5
		var ccy := rng() * 4 - 1
		var r2 := 0.8 + rng() * 1.6
		var a0 := rng() * 6.28
		for j in 6:
			# vệt chổi quét, chỉ phần nằm trong bàn (clip)
			var a1 := a0 + 0.5 + rng() * 0.4
			var pts := PackedVector2Array()
			for q in 13:
				var aa := a0 + (a1 - a0) * q / 12.0
				var p := Vector2(ccx, ccy) + Vector2(cos(aa), sin(aa)) * (r2 + j * 0.022)
				if Geometry2D.is_point_in_polygon(p, bp):
					pts.append(p)
				else:
					if pts.size() > 1:
						draw_polyline(pts, Color8(255, 240, 210, 18), 0.012, true)
					pts = PackedVector2Array()
			if pts.size() > 1:
				draw_polyline(pts, Color8(255, 240, 210, 18), 0.012, true)
	var segs := chalk_lines()
	var lw := 0.036
	_T()
	# rãnh cạo mờ dưới phấn
	for pts in segs:
		var scr := PackedVector2Array()
		for p in pts:
			scr.append(lg * (p + Vector2(0.01, 0.012)))
		draw_polyline(scr, Color8(70, 45, 22, 51), lw * 1.2 * s, true)
	var scr_lines := []
	for pts in segs:
		var scr := PackedVector2Array()
		for p in pts:
			var j := Vector2((rng() - 0.5) * 0.004, (rng() - 0.5) * 0.004)
			scr.append(lg * (p + j))
		scr_lines.append(scr)
	# bụi phấn loang quanh nét (lớp blur 0.18 của web)
	for scr in scr_lines:
		draw_polyline(scr, Color8(252, 249, 240, 14), lw * 2.6 * s, true)
	for scr in scr_lines:
		draw_polyline(scr, Color8(252, 249, 240, 128), lw * 0.62 * s, true)
	_T(lg)
	_dabs(segs, Color8(253, 250, 242), lw, 1.0)
	# hàng mỗi bên gạch dưới bằng phấn màu: xanh cho người dưới, hồng cho người trên (cùng màu thẻ)
	for yc in [[2.085, Color8(86, 170, 232)], [-0.085, Color8(240, 122, 146)]]:
		var u := []
		for q in 61:
			u.append(Vector2(0.08 + 4.84 * q / 60.0, yc[0] + 0.006 * sin(q * 0.7)))
		var scr := PackedVector2Array()
		for p in u:
			scr.append(lg * p)
		_T()
		var cc: Color = yc[1]
		draw_polyline(scr, Color(cc, 0.12), lw * 2.6 * s, true)
		draw_polyline(scr, Color(cc, 0.55), lw * 0.9 * s, true)
		_T(lg)
		_dabs([u], cc, lw * 1.3, 1.4)
	_T()

func _dabs(segs: Array, col: Color, lw: float, amt: float) -> void:
	for pts in segs:
		var ln := 0.0
		var ph := rng() * 10
		var ph2 := rng() * 10
		for q in range(1, pts.size()):
			var p0: Vector2 = pts[q - 1]
			var p1: Vector2 = pts[q]
			var sl := (p1 - p0).length()
			var n := maxi(1, ceili(sl / 0.007))
			var nrm := Vector2(-(p1.y - p0.y) / sl, (p1.x - p0.x) / sl)
			for mm in n:
				var t := float(mm) / n
				var p := p0 + (p1 - p0) * t
				ln += sl / n
				if rng() < 0.35:
					continue
				var press := 0.72 + 0.22 * sin(ln * 2.3 + ph) + 0.12 * sin(ln * 7.1 + ph2)
				var wob := 0.006 * sin(ln * 4.7 + ph) + 0.003 * sin(ln * 13 + ph2)
				for dct in 3:
					var off := (rng() - 0.5) * lw * press
					var r0 := lw * (0.12 + rng() * 0.2) * press
					var a := (0.16 + rng() * 0.26) * amt * minf(1.0, press + 0.2)
					draw_circle(p + nrm * (off + wob), r0, Color(col, a), true, -1.0, false)
