extends Node2D
# CỜ GÁNH: lớp nền tĩnh (buildBG của game.js): đất sân, hiên gạch tàu, cỏ, dép, lu, chổi chà, tàu dừa, nón lá, lá khô,
# hai cái rổ, bàn kẻ phấn. Vẽ một lần trong SubViewport rồi chụp thành ảnh (không vẽ lại mỗi khung).
# Đơn vị: css px của bản web (nhân K ra điểm ảnh thật). Cùng hạt giống ngẫu nhiên (mulberry32 20261107) như web.

const A := preload("res://logic/cg/cg_art.gd")
const SUN := Vector2(0.64, 0.77)

var g      # cg_game (L, map(), home_spot)
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
	_rng_seed(20261107)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# đất sân: ảnh đất 9px của sân caro (Link 11-22 "nền lấy bên caro"), 9 điểm ảnh / css, lặp
	var ts := 1.0 / 9.0
	_T(xf(Vector2.ZERO, 0.0, Vector2(ts, ts)))
	draw_texture_rect_region(A.img("dat"), Rect2(0, 0, W / ts, H / ts), Rect2(0, 0, W / ts, H / ts))
	_T()
	radial(Vector2(W * 0.46, H * 0.52), maxf(W, H) * 0.75, [[0.0, Color8(255, 236, 200, 26)], [1.0, Color8(60, 35, 15, 41)]])
	_porch(L)
	var bp: Rect2 = g.board_rect(L.s * 0.05)
	L.obst = [bp]
	for b in L.bx:
		L.obst.append(Rect2(b.x - b.z - 8, b.y - b.z - 8, 2 * b.z + 16, 2 * b.z + 16))
	for c in L.cards:
		L.obst.append((c as Rect2).grow(6))
	L.obst.append((L.tools as Rect2).grow(6))
	L.obst.append(Rect2(W - 190, H - 64, 190, 64))
	_decor(L)
	for b in L.bx:
		var D: float = b.z * 2 / 0.965
		on_ground("ro", Rect2i(), Vector2(b.x, b.y), D, D, 0.0, b.z * 0.5)
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
	var ph := float(roundi(maxf(30.0, minf(s * 0.78, (top - 12) * (0.7 if L.port else 0.6)))))
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

func on_ground(name: String, cell: Rect2i, at: Vector2, w: float, h: float, rot: float, ht: float, flip := false, ox = null, oy = null) -> void:
	A.on_ground(self, K, name, cell, at, w, h, rot, ht, flip, ox, oy)

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
	var sp = null
	# chỗ con gà mái đi dạo: một dải sân trống (đồ khác né ra)
	g.home_spot = null
	var hint_band := Rect2(-9, -9, 1, 1)
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
	for hb in [[0.0, true], [0.22, true], [0.22, false]]:
		if done:
			break
		for f in [40, 36, 32]:
			st_band[0] = hb[1]
			var hl: float = f * CM
			var jr := hl * 0.06
			var ha := hl * 0.5
			var hc := hl * 0.3 + jr
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
	# dép lào để trên bậc hiên (26 cm)
	var dl := 26 * CM
	var dD := dl / 0.82
	for tries in 80:
		if sp != null:
			break
		var x := dD * 0.5 + rng() * (W - dD)
		var y := ph + dl * (0.02 + rng() * 0.22)
		if free.call(x, y, dl * 0.52):
			sp = Vector2(x, y)
	if sp != null:
		var a := (rng() - 0.5) * 0.5
		on_ground("dep", Rect2i(), sp, dD, dD, a, dl * 0.035)
		used.call(sp.x, sp.y, dl * 0.6)
	# lu da lươn ở góc hiên
	for f in [30, 27]:
		var lr: float = f * CM
		sp = _find_spot(L, lr, false, func(x: float, y: float) -> float:
			var off := maxf(0, lr - x) + maxf(0, x + lr - W) + maxf(0, lr - y) + maxf(0, y + lr - H)
			if off > lr * 0.8 or absf(x - cx) < W * 0.22:
				return -1e9
			return -absf(y - (ph + lr * 0.1)) * 0.6 + absf(x - cx) * 0.6 - off * 2)
		if sp != null:
			var D := lr * 2 / 0.874   # lu 9px của caro: thân chiếm 87% ảnh
			on_ground("lu", Rect2i(), sp, D, D, 0.0, lr * 1.3)
			used.call(sp.x, sp.y, lr * 1.02)
			break
	# chổi chà nằm dọc bậc hiên hoặc mép dưới, cán ló ra ngoài màn
	var bl := minf(110 * CM, W * 0.5)
	var bh := bl / 3
	var cands := []
	for yy in [ph + bh * 0.62, ph + bh * 0.9, H - bh * 0.55, H - bh * 0.8]:
		for side in [-1, 1]:
			cands.append({"y": yy, "side": side})
	for i in range(cands.size() - 1, 0, -1):
		var j := int(rng() * (i + 1))
		var tmp = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	for c in cands:
		var x0: float = -bl * 0.18 if c.side < 0 else W + bl * 0.18
		var pts := []
		for t in [0.35, 0.5, 0.65, 0.8, 0.95]:
			pts.append(Vector2(x0 - c.side * bl * t, c.y))
		var all_ok := true
		for p in pts:
			if not free.call(p.x, p.y, bh * 0.42):
				all_ok = false
				break
		if all_ok:
			var ra := (rng() - 0.5) * 0.12
			on_ground("choi", Rect2i(), Vector2(x0, c.y), bl, bh, -ra if c.side > 0 else ra, bh * 0.22, c.side > 0, 0.0, -bh / 2)
			for p in pts:
				used.call(p.x, p.y, bh * 0.4)
			break
	# tàu dừa rớt ngang một góc sân trống
	var fl := minf(maxf(W, H) * 0.4, 95 * CM)
	var fb = null
	var fs := -1e9
	for k in 500:
		var x := rng() * W
		var y := ph + rng() * (H - ph)
		var ang := rng() * PI
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
		_frond(fb[0], fb[1], fl, fb[2])
		var t := -0.5
		while t <= 0.5:
			used.call(fb[0] + cos(fb[2]) * fl * t, fb[1] + sin(fb[2]) * fl * t, fl * 0.13)
			t += 0.125
	# nón lá 42 cm, ló ra mép màn tối đa một phần ba
	var nr := 21 * CM
	sp = _find_spot(L, nr * 1.05, false, func(x: float, y: float) -> float:
		var off := maxf(0, nr - x) + maxf(0, x + nr - W) + maxf(0, nr - y) + maxf(0, y + nr - H)
		return -1e9 if off > nr * 0.65 else far.call(x, y) * 0.5 + (40.0 if y > cy else 0.0) - off * 2)
	if sp != null:
		_non(sp.x, sp.y, nr)
		used.call(sp.x, sp.y, nr * 1.08)
	# lá khô (lá bàng, lá xoài) rải rác
	var placed := 0
	var want := mini(10, roundi(W * H / (s * s * 3.2)))
	var spots := []
	for k in 300:
		if placed >= want:
			break
		var x := rng() * W
		var y := rng() * H
		var ln := (15 + rng() * 7) * CM
		var near := false
		for p in spots:
			if Vector2(p.x - x, p.y - y).length() < s * 1.3:
				near = true
				break
		if hits_obst(L, x, y, ln * 0.45) or near:
			continue
		if y < ph and rng() < 0.7:
			continue
		_leaf(x, y, ln, rng() * 6.28, "bang" if rng() < 0.55 else "xoai")
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

func _non(x: float, y: float, r: float) -> void:
	# quai nón nằm lòi ra dưới vành
	var pts := cubic(Vector2(x - r * 0.5, y + r * 0.62), Vector2(x - r * 0.75, y + r * 1.1), Vector2(x - r * 0.2, y + r * 1.25), Vector2(x + r * 0.15, y + r * 0.9), 20)
	var lw := maxf(2.0, r * 0.05)
	_T(xf(Vector2(1.5, 2)))
	draw_polyline(pts, Color8(40, 25, 10, 60), lw * 1.4, true)
	_T()
	draw_polyline(pts, Color("#e9e2d6"), lw, true)
	on_ground("non", Rect2i(), Vector2(x, y), 2 * r, 2 * r, 0.0, r * 0.8)

func _frond(x: float, y: float, ln: float, ang: float) -> void:
	var bend := ln * 0.12
	var P := func(t: float) -> Vector2: return Vector2(-ln / 2 + ln * t, sin(t * PI) * -bend * 0.6 + t * t * bend * 0.4)
	var so := Vector2(ln * 0.008, ln * 0.011)
	var base := xf(Vector2(x, y), ang)
	for i in 46:
		var t := 0.12 + i / 46.0 * 0.86
		var p: Vector2 = P.call(t)
		var side := 1.0 if i & 1 else -1.0
		var ll := ln * (0.22 * sin(minf(1.0, t * 1.25) * PI) + 0.06) * (0.85 + rng() * 0.3)
		var la := side * (0.9 + rng() * 0.25) - 0.35
		var dry := rng() < 0.3 or t > 0.9
		var col: Color
		if dry:
			col = hsl(38 + rng() * 10, 45 + rng() * 15, 46 + rng() * 10)
		else:
			col = hsl(70 + rng() * 22, 38 + rng() * 18, 30 + rng() * 12)
		var w := ln * 0.012
		var sh := quad(Vector2.ZERO, Vector2(ll * 0.5, -w * 2.2), Vector2(ll, side * ll * 0.08), 8)
		var b2 := quad(Vector2(ll, side * ll * 0.08), Vector2(ll * 0.5, w * 1.4), Vector2.ZERO, 8)
		b2.remove_at(0)
		sh.append_array(b2)
		var lx := Transform2D(la, p)
		# bóng lá (shadowBlur nhỏ, lệch xuống phải theo mặt trời)
		var inv := base.basis_xform_inv(so)
		_T(base * Transform2D(0.0, inv) * lx)
		_fill(sh, Color(0.125, 0.07, 0.02, 0.42))
		_T(base * lx)
		_fill(sh, col)
		draw_polyline(quad(Vector2.ZERO, Vector2(ll * 0.5, -w * 0.4), Vector2(ll * 0.95, side * ll * 0.07), 8), Color(1, 0.98, 0.78, 0.22), maxf(0.6, w * 0.25), true)
	var rib := PackedVector2Array()
	var rib2 := PackedVector2Array()
	var t := 0.0
	while t <= 1.001:
		var p: Vector2 = P.call(t)
		rib.append(p)
		rib2.append(p - Vector2(0, ln * 0.004))
		t += 0.05
	var inv2 := base.basis_xform_inv(so)
	_T(base * Transform2D(0.0, inv2))
	draw_polyline(rib, Color(0.125, 0.07, 0.02, 0.4), ln * 0.026, true)
	_T(base)
	draw_polyline(rib, Color("#8a6a2a"), ln * 0.022, true)
	draw_polyline(rib2, Color("#c9a85a"), ln * 0.008, true)
	_T()

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
	var pal := [[165, 62, 34], [196, 110, 44], [120, 64, 36]] if kind == "bang" else [[176, 146, 70], [146, 116, 56], [196, 168, 98]]
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

# --- bàn kẻ phấn: 5x5 điểm, hai đường chéo lớn và hình thoi qua trung điểm các cạnh
func chalk_lines() -> Array:
	var segs := []
	var line := func(x0: float, y0: float, x1: float, y1: float) -> void:
		var pts := []
		var n := maxi(6, roundi(Vector2(x1 - x0, y1 - y0).length() * 16))
		for k in n + 1:
			pts.append(Vector2(x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n))
		segs.append(pts)
	for k in 5:
		line.call(0, k, 4, k)
		line.call(k, 0, k, 4)
	line.call(0, 0, 4, 4); line.call(4, 0, 0, 4)
	line.call(2, 0, 0, 2); line.call(0, 2, 2, 4); line.call(2, 4, 4, 2); line.call(4, 2, 2, 0)
	return segs

func _chalk_board(L: Dictionary) -> void:
	var s: float = L.s
	var lg := Transform2D(0.0, Vector2(s, s), 0.0, Vector2(L.ox, L.oy))
	# khoảng sân con nít quét láng trước khi kẻ: sáng hơn, mịn, mép mềm
	_T(lg)
	var m := 0.42
	for k in 4:
		var gr := 0.35 * (k + 1) / 4.0
		_fill(rrect(-m - gr * 0.5, -m - gr * 0.5, 4 + 2 * m + gr, 4 + 2 * m + gr, 0.5 + gr * 0.5), Color8(255, 238, 205, 3))
	_fill(rrect(-m, -m, 4 + 2 * m, 4 + 2 * m, 0.5), Color8(255, 238, 205, 18))
	for k in 26:
		var ccx := rng() * 5 - 0.5
		var ccy := rng() * 5 - 0.5
		var r2 := 0.8 + rng() * 1.6
		var a0 := rng() * 6.28
		var a1 := a0 + 0.5 + rng() * 0.4
		for j in 6:
			# vệt chổi quét, chỉ phần nằm trong khoảng sân láng (clip)
			var pts := PackedVector2Array()
			for q in 13:
				var aa := a0 + (a1 - a0) * q / 12.0
				var p := Vector2(ccx, ccy) + Vector2(cos(aa), sin(aa)) * (r2 + j * 0.022)
				if p.x > -m and p.x < 4 + m and p.y > -m and p.y < 4 + m:
					pts.append(p)
				else:
					if pts.size() > 1:
						draw_polyline(pts, Color8(255, 240, 210, 18), 0.012, true)
					pts = PackedVector2Array()
			if pts.size() > 1:
				draw_polyline(pts, Color8(255, 240, 210, 18), 0.012, true)
	var segs := chalk_lines()
	var lw := 0.034
	# rãnh cạo mờ dưới phấn
	for pts in segs:
		var pp := PackedVector2Array()
		for p in pts:
			pp.append(p + Vector2(0.01, 0.012))
		_T()
		var scr := PackedVector2Array()
		for p in pp:
			scr.append(lg * p)
		draw_polyline(scr, Color8(70, 45, 22, 51), lw * 1.2 * s, true)
	var scr_lines := []
	for pts in segs:
		var scr := PackedVector2Array()
		for p in pts:
			var j := Vector2((rng() - 0.5) * 0.004, (rng() - 0.5) * 0.004)
			scr.append(lg * (p + j))
		scr_lines.append(scr)
	# quầng phấn mờ (thay lớp blur 0.18 của web)
	for scr in scr_lines:
		draw_polyline(scr, Color8(252, 249, 240, 14), lw * 2.6 * s, true)
	for scr in scr_lines:
		draw_polyline(scr, Color8(252, 249, 240, 128), lw * 0.62 * s, true)
	_T(lg)
	_dabs(segs, Color8(253, 250, 242), lw, 1.0)
	# mép nhà mỗi bên gạch phấn màu, cùng màu thẻ người chơi
	for yc in [[4.3, Color8(86, 170, 232)], [-0.3, Color8(240, 122, 146)]]:
		var u := []
		for q in 51:
			u.append(Vector2(-0.05 + 4.1 * q / 50.0, yc[0] + 0.008 * sin(q * 0.7)))
		var scr := PackedVector2Array()
		for p in u:
			scr.append(lg * p)
		_T()
		var cc: Color = yc[1]
		draw_polyline(scr, Color(cc, 0.5), lw * 0.9 * s, true)
		_T(lg)
		_dabs([u], cc, lw * 1.3, 1.3)
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
