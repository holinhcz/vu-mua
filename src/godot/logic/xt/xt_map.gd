extends Control
# XẾP TRÁI: bản đồ màn (08_ui.js buildMap/paintMap) + dựng vườn (08b_garden.js).
# Nền bản đồ vẽ MỘT LẦN thành các lát ảnh 1100 css (SubViewport), sau đó chỉ dán ảnh khi cuộn.
# Chỗ sửa vườn dùng ảnh nướng sẵn g_<id>0/1 (đúng hình vẽ của web), nút màn / nhãn / thú vẽ trực tiếp.

const A := preload("res://logic/xt/xt_art.gd")
const D := preload("res://logic/xt/xt_data.gd")
const GINK := Color("#4a3018")
const MUC := Color("#2b2118")
const MUC2 := Color("#5a4630")

class Lay extends Control:
	var fn: Callable
	func _init(f: Callable) -> void:
		fn = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)

class Painter extends Node2D:
	var fn: Callable
	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)

var game
var built := false
var W := 0.0
var H := 0.0
var nodes: Array = []
var chapters: Array = []
var riv := {}
var spots: Array = []
var u := 48.0
var slices: Array = []
var scroll := 0.0
var content: Lay
var top: Lay
var fly: Lay
var life: Array = []
var fxs: Array = []
var busy := false
var flys: Array = []
var star_disp := -1
var _wig := {}
var _glow := {}
var _timers: Array = []
var _bake_gen := 0
var _vel := 0.0
var _stw = null
var _down := false
var _drag := false
var _p0 := Vector2.ZERO
var _s0 := 0.0
var _ly := 0.0
var _lt := 0.0
var _press = null
var _items: Array = []
var _t := 0.0

func _init(gm) -> void:
	game = gm
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content = Lay.new(_draw_content)
	content.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(content)
	top = Lay.new(_draw_top)
	add_child(top)
	fly = Lay.new(_draw_fly)
	add_child(fly)

func VH() -> float:
	return float(game.LAY.H)

# ============================================================ bật / tắt
func show_map(_scroll_to := true) -> void:
	if game.in_game:
		game.leave_level()
	game.ui.hide_hud()
	game.ui.hide_title()
	visible = true
	if not built or W != float(game.LAY.W):
		build_map()
	var free := stars_free()
	if not game.save.get("gTip", false) and free >= 2:
		game.save.gTip = 1
		game.persist()
		later(0.5, func():
			var ui = game.ui
			ui.dialog([ui.b_ribbon("Dựng vườn"), ui.b_h2("Miệt vườn hư hết rồi", 26), ui.b_p("Sao kiếm được trong màn dùng để sửa nhà lá, bắc cầu khỉ, trồng cây dọc đường. Chỗ nào có cây búa là sửa được liền."),
				ui.b_row([["Đi sửa", "la", "go", func():
					game.snd.play("tap")
					ui.close_dlg()
					seek()]])]))
	var cur: int = game.cur_level()
	if cur < nodes.size():
		set_scroll(nodes[cur].y - VH() * 0.6)
	_stw = null
	_vel = 0.0

func hide_map() -> void:
	visible = false
	game.farm.hide_farm()

func relayout() -> void:
	if built and visible and W != float(game.LAY.W):
		build_map()
		var cur: int = game.cur_level()
		if cur < nodes.size():
			set_scroll(nodes[cur].y - VH() * 0.6)
	content.size = Vector2(W, H)
	top.size = Vector2(game.LAY.W, game.LAY.H)
	fly.size = top.size

func set_scroll(v: float) -> void:
	scroll = clampf(v, 0, maxf(0, H - VH()))
	content.position = Vector2(0, -scroll)

func later(sec: float, fn: Callable) -> void:
	_timers.append([sec, fn])

# ============================================================ dựng bản đồ (buildMap)
func build_map() -> void:
	W = float(game.LAY.W)
	var col := minf(W, 560)
	var cx := W / 2
	var amp := minf(col * 0.3, 150)
	var gap := 112.0
	var chap_gap := 170.0
	nodes = []
	var y := 170.0
	var chap_y := []
	for c in D.CHAPTERS.size():
		var ch: Dictionary = D.CHAPTERS[c]
		chap_y.append(y)
		y += chap_gap * 0.55
		for i in range(int(ch.from), int(ch.to) + 1):
			nodes.append({"i": i, "x": cx + sin(i * 0.85) * amp, "y": y})
			y += gap
		y += chap_gap * 0.45
	H = y + 80
	for n in nodes:
		n.y = H - n.y
	chapters = []
	for c in chap_y.size():
		var v: float = chap_y[c]
		chapters.append({"c": c, "y": H - v + 28, "top": (H - chap_y[c + 1] + chap_gap * 0.1) if c + 1 < chap_y.size() else 0.0, "bot": H - v + chap_gap * 0.3})
	var c2: Dictionary = chapters[1]
	var rt: float = c2.top - 40
	var rb: float = chapters[0].top + 40
	riv = {"rt": rt, "rb": rb, "mid": (rt + rb) / 2, "half": (rb - rt) / 2}
	place()
	content.size = Vector2(W, H)
	_glow = {}
	_build_life()
	built = true
	set_scroll(scroll)
	_bake()

func rx(y: float) -> float:
	var uu: float = (y - riv.mid) / riv.half
	return W * 0.5 + sin(y * 0.006) * W * 0.22 + signf(uu) * pow(absf(uu), 6) * W * 0.9

func rw(y: float) -> float:
	return W * 0.2 + sin(y * 0.013) * W * 0.03

func in_river(x: float, y: float, pad := 0.0) -> bool:
	return not riv.is_empty() and y > riv.rt and y < riv.rb and absf(x - rx(y)) < rw(y) + pad

func _road_pts() -> PackedVector2Array:
	var out := PackedVector2Array()
	var pts := []
	for i in range(nodes.size() - 1, -1, -1):
		pts.append(Vector2(nodes[i].x, nodes[i].y))
	out.append(pts[0])
	for i in range(1, pts.size()):
		var p: Vector2 = pts[i - 1]
		var q: Vector2 = pts[i]
		var seg := A.cubic_pts(p, Vector2(p.x, p.y + (q.y - p.y) * 0.5), Vector2(q.x, q.y - (q.y - p.y) * 0.5), q, 18)
		for k in range(1, seg.size()):
			out.append(seg[k])
	return out

# ============================================================ GARDEN.place
func box_of(p: Dictionary) -> Array:
	if p.k == "cau":
		var sp: float = p.get("span", 3.0)
		return [-sp / 2 - 0.3, -1.35, sp / 2 + 0.3, 0.3]
	return D.BOX[p.k]

func place() -> void:
	u = clampf(W / 7.8, 40, 56)
	var pts := []
	for i in range(nodes.size() - 1, -1, -1):
		pts.append([nodes[i].x, nodes[i].y])
	var road := PackedVector2Array()
	for i in range(1, pts.size()):
		var p = pts[i - 1]
		var q = pts[i]
		for k in 12:
			var t := k / 12.0
			var b1y: float = p[1] + (q[1] - p[1]) * 0.5
			var c1y: float = q[1] - (q[1] - p[1]) * 0.5
			var mt := 1 - t
			road.append(Vector2(mt * mt * mt * p[0] + 3 * mt * mt * t * p[0] + 3 * mt * t * t * q[0] + t * t * t * q[0], mt * mt * mt * p[1] + 3 * mt * mt * t * b1y + 3 * mt * t * t * c1y + t * t * t * q[1]))
	var d_road := func(x: float, y: float) -> float:
		var m := 1e18
		for r in road:
			var dd := (r.x - x) * (r.x - x) + (r.y - y) * (r.y - y)
			if dd < m:
				m = dd
		return sqrt(m)
	var placed := []
	for sp in D.SPOTS:
		var p: Dictionary = sp.duplicate()
		var on: String = p.get("on", "")
		var ch: Dictionary = chapters[p.c]
		var tp: float = ch.top
		var bot: float = H if p.c == 0 else float(chapters[p.c - 1].top)
		var ty: float = bot - (bot - tp) * float(p.f)
		var lab := Vector2(W / 2, float(ch.y) - 20)
		var best = null
		var relax := 0
		while relax < 4 and best == null:
			var yr := 60.0 + relax * 50
			var rmin := (80.0 if on == "water" else u * 1.35 + 30) - relax * 12
			var y := ty - yr
			while y <= ty + yr:
				if y < tp + u * 2.2 or y > bot - 30:
					y += 10
					continue
				var cands := []
				var skip := false
				if on == "bridge":
					if riv.is_empty() or y < riv.rt + 120 or y > riv.rb - 120:
						skip = true
					else:
						cands.append([rx(y), y, (rw(y) + 22) / u * 2, 0])
				elif on == "bank":
					if riv.is_empty() or y < riv.rt + 80 or y > riv.rb - 80:
						skip = true
					else:
						for sd in [-1, 1]:
							cands.append([rx(y) + sd * (rw(y) - u * 0.15), y, 0.0, -sd])
				elif on == "water":
					if riv.is_empty() or y < riv.rt + 80 or y > riv.rb - 80:
						skip = true
					else:
						var dx := -0.45
						while dx <= 0.45:
							cands.append([rx(y) + dx * rw(y), y, 0.0, 0])
							dx += 0.15
				else:
					var x := u * 1.3
					while x <= W - u * 1.3:
						cands.append([x, y, 0.0, 0])
						x += 8
				if skip:
					y += 10
					continue
				for cd in cands:
					var x: float = cd[0]
					var y2: float = cd[1]
					var L: float = cd[2]
					if x < u * 1.1 or x > W - u * 1.1:
						continue
					if on != "water" and on != "bridge" and on != "bank" and in_river(x, y2, u * 1.2):
						continue
					if absf(x - lab.x) < 170 and absf(y2 - lab.y) < 70 + u:
						continue
					var ok := true
					for q in placed:
						var qd := Vector2((q.x - x) * 0.8, q.y - y2).length()
						if qd < u * 2.5 - relax * 8 or (q.get("on", "") == "bridge" and absf(q.y - y2) < u * 2.2):
							ok = false
							break
					if not ok:
						continue
					var dr := 0.0
					if on == "bridge":
						dr = 1e9
						var k := -1.0
						while k <= 1:
							dr = minf(dr, d_road.call(x + k * L * u / 2, y2 - u * 0.5))
							k += 0.1
						if dr < u * 1.6 - relax * 10:
							continue
					else:
						dr = d_road.call(x, y2 - u * 0.5)
						if dr < rmin:
							continue
					var sc := absf(dr - (u * 1.35 + 70)) * 0.6 + absf(y2 - ty) * 0.5 + (absf(x - rx(y2)) * 0.3 if on == "water" else 0.0)
					if best == null or sc < best.sc:
						best = {"x": x, "y": y2, "sc": sc, "span": L, "side": cd[3]}
				y += 10
			relax += 1
		if best == null:
			best = {"x": W / 2, "y": ty, "span": 0.0, "side": 0}
		p.x = best.x
		p.y = best.y
		if best.span:
			p.span = best.span
		if best.side:
			p.side = best.side
		placed.append(p)
	spots = placed

func near(x: float, y: float) -> bool:
	for p in spots:
		var b := box_of(p)
		if x > p.x + b[0] * u - 40 and x < p.x + b[2] * u + 40 and y > p.y + b[1] * u - 20 and y < p.y + b[3] * u + 130:
			return true
	return false

# ============================================================ sao / vùng
func stars_all() -> int:
	var n := 0
	for k in game.save.stars:
		n += int(game.save.stars[k])
	return n

func stars_spent() -> int:
	var n := 0
	for p in D.SPOTS:
		if game.save.garden.get(p.id, 0):
			n += int(p.cost)
	return n

func stars_free() -> int:
	return stars_all() - stars_spent()

func done_c(c: int) -> bool:
	for p in D.SPOTS:
		if p.c == c and not game.save.garden.get(p.id, 0):
			return false
	return true

func open_c(c: int) -> bool:
	return game.cur_level() >= int(D.CHAPTERS[c].from) and (c == 0 or done_c(c - 1))

func count() -> int:
	var n := 0
	for p in D.SPOTS:
		if game.save.garden.get(p.id, 0):
			n += 1
	return n

# ============================================================ nướng nền bản đồ thành lát ảnh
func _bake() -> void:
	_bake_gen += 1
	var gen := _bake_gen
	var d := minf(float(game.K), 1.25 if W > 900 else 2.0)
	var slice := 1100.0
	var vps := []
	var y0 := 0.0
	while y0 < H:
		var h := minf(slice, H - y0)
		var vp := SubViewport.new()
		vp.size = Vector2i(ceili(W * d), ceili(h * d))
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var pn := Painter.new()
		pn.scale = Vector2(d, d)
		pn.position = Vector2(0, -y0 * d)
		var a := y0
		var b := y0 + h
		pn.fn = func(ci): _paint_map(ci, a, b)
		vp.add_child(pn)
		add_child(vp)
		vps.append([vp, y0, h])
		y0 += slice
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out := []
	for v in vps:
		if gen == _bake_gen:
			var img: Image = v[0].get_texture().get_image()
			out.append({"tex": ImageTexture.create_from_image(img), "y0": v[1], "h": v[2]})
		v[0].queue_free()
	if gen == _bake_gen:
		slices = out

# ---------- vẽ nền (paintMap)
static func _c(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if r > 0:
		ci.draw_circle(c, r, col, true, -1.0, true)

static func _ln(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float, round_cap := true) -> void:
	A.stroke(ci, PackedVector2Array([a, b]), col, w, round_cap)

static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var o := pts.duplicate()
	o.append(pts[0])
	return o

static func _fill(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	if Geometry2D.triangulate_polygon(pts).size() == 0:
		ci.draw_polyline(_closed(pts), col, 1.0, true)
		return
	ci.draw_colored_polygon(pts, col)

func _thick(ci: CanvasItem, pts: PackedVector2Array, w: float, col: Color, clip := PackedVector2Array()) -> void:
	# nét dày đầu tròn, khớp tròn, không chồng màu (cho nét trong suốt)
	var polys := Geometry2D.offset_polyline(pts, w / 2, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
	for pl in polys:
		if Geometry2D.is_polygon_clockwise(pl) and polys.size() > 1:
			continue
		if clip.size() > 2:
			for q in Geometry2D.intersect_polygons(pl, clip):
				if not Geometry2D.is_polygon_clockwise(q):
					_fill(ci, q, col)
		else:
			_fill(ci, pl, col)

func _dash(ci: CanvasItem, pts: PackedVector2Array, w: float, col: Color, on: float, off: float) -> void:
	var pos := 0.0
	var per := on + off
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var L := a.distance_to(b)
		if L <= 0:
			continue
		var s := 0.0
		while s < L:
			var ph := fmod(pos + s, per)
			if ph < on:
				var e := minf(L, s + (on - ph))
				var p0 := a.lerp(b, s / L)
				var p1 := a.lerp(b, e / L)
				_c(ci, p0, w / 2, col)
				_c(ci, p1, w / 2, col)
				ci.draw_line(p0, p1, col, w, true)
				s = e
			else:
				s += per - ph
		pos += L

func _paint_map(ci: CanvasItem, y0: float, y1: float) -> void:
	var R := D.SRand.new(77)
	var bands := chapters
	var gcol := ["#8cc157", "#79b35a", "#b7c95a"]
	for ch in bands:
		var tp: float = ch.top
		var bot: float = H if ch.c == 0 else float(bands[ch.c - 1].top)
		if bot < y0 or tp > y1:
			continue
		var col := Color(gcol[ch.c])
		ci.draw_rect(Rect2(0, tp, W, bot - tp), col)
		if ch.c < bands.size() - 1:
			var c2 := Color(gcol[ch.c + 1])
			ci.draw_polygon(PackedVector2Array([Vector2(0, tp - 60), Vector2(W, tp - 60), Vector2(W, tp + 60), Vector2(0, tp + 60)]), PackedColorArray([c2, c2, col, col]))
	# cỏ lấm tấm
	var i := 0
	while i < H / 6:
		var x := R.r() * W
		var y := R.r() * H
		i += 1
		if y < y0 - 20 or y > y1 + 20:
			continue
		var gc := Color(1, 1, 200 / 255.0, 0.25) if R.r() < 0.5 else Color(30 / 255.0, 80 / 255.0, 20 / 255.0, 0.2)
		ci.draw_line(Vector2(x, y), Vector2(x + 2, y - 6), gc, 1.4, true)
	# sông lớn vùng 2
	var river := PackedVector2Array()
	if not riv.is_empty():
		var rt: float = riv.rt
		var rb: float = riv.rb
		var y := rt
		while y <= rb:
			river.append(Vector2(rx(y) - rw(y), y))
			y += 12
		y = rb
		while y >= rt:
			river.append(Vector2(rx(y) + rw(y), y))
			y -= 12
		var sh := river.duplicate()
		for k in sh.size():
			sh[k] += Vector2(0, 4)
		_fill(ci, sh, Color("#e7dfb8"))
		_fill(ci, river, Color("#5aa3b4"))
		ci.draw_polyline(_closed(river), Color("#d9ecdf"), 5, true)
		for k in 120:
			var yy := rt + R.r() * (rb - rt)
			var xx := rx(yy) + (R.r() - 0.5) * W * 0.4
			var ww := 10 + R.r() * 22
			var rect := PackedVector2Array([Vector2(xx, yy), Vector2(xx + ww, yy), Vector2(xx + ww, yy + 1.5), Vector2(xx, yy + 1.5)])
			for q in Geometry2D.intersect_polygons(rect, river):
				_fill(ci, q, Color(1, 1, 1, 0.45))
		for k in 40:
			var yy := rt + R.r() * (rb - rt)
			var xx := rx(yy) + (-1.0 if R.r() < 0.5 else 1.0) * rw(yy) * 0.9
			var rr := 4 + R.r() * 5
			for q in Geometry2D.intersect_polygons(A.ell_pts(Vector2(xx, yy), rr, rr, 16), river):
				_fill(ci, q, Color(70 / 255.0, 130 / 255.0, 60 / 255.0, 0.85))
		for k in 8:
			var yy := rt + 80 + k * (rb - rt - 160) / 7
			var xx := rx(yy) + (1.0 if k % 2 else -1.0) * W * 0.08
			if near(xx, yy):
				continue
			boat_draw(ci, xx, yy, 28, k, k % 2 == 1)
	_bloom(ci, y0, y1)
	var road := _road_pts()
	_thick(ci, road, 30, Color(70 / 255.0, 50 / 255.0, 20 / 255.0, 0.25))
	_thick(ci, road, 26, Color("#d9b77a"))
	_dash(ci, road, 4, Color(1, 246 / 255.0, 220 / 255.0, 0.7), 2, 14)
	if river.size() > 2:
		_thick(ci, road, 30, Color("#4a2e16"), river)
		_thick(ci, road, 24, Color("#a8743e"), river)
		_thick(ci, road, 22, Color("#c08a50"), river)
	# trang trí tránh đường
	i = 0
	while i < H / 38:
		var x := R.r() * W
		var y := R.r() * H
		var idx := i
		i += 1
		if y < y0 - 160 or y > y1 + 160:
			continue
		var nr := false
		for n in nodes:
			if Vector2(n.x - x, (n.y - y) * 0.8).length() < 95:
				nr = true
				break
		if nr:
			continue
		var ch = bands[0]
		for b in bands:
			if y >= b.top:
				ch = b
				break
		var c: int = ch.c
		var v := R.r()
		if near(x, y):
			continue
		if in_river(x, y, 30):
			continue
		if c == 0:
			if v < 0.55:
				mango_tree(ci, x, y, 30 + R.r() * 18, R)
			elif v < 0.8:
				var hh := 70 + R.r() * 40
				palm(ci, x, y, hh, (R.r() - 0.5) * 0.6, idx)
			else:
				hut(ci, x, y, 60)
		elif c == 1:
			if v < 0.7:
				var hh := 70 + R.r() * 40
				palm(ci, x, y, hh, (R.r() - 0.5) * 0.6, idx)
			else:
				hut(ci, x, y, 56)
		else:
			if v < 0.45:
				paddy(ci, x, y, R)
			elif v < 0.75:
				dien_dien(ci, x, y, R)
			elif v < 0.9:
				haystack(ci, x, y)
			else:
				palm(ci, x, y, 70, (R.r() - 0.5) * 0.5, idx)

func _bloom(ci: CanvasItem, y0: float, y1: float) -> void:
	var R := D.SRand.new(991)
	var bands := chapters
	var cols := [["#e8507a", "#f4c430", "#ff8a3a"], ["#f07aa0", "#f4c430", "#ff8a3a"], ["#f6cf2e", "#ff8a3a", "#e8507a"]]
	for ch in bands:
		if not done_c(ch.c):
			continue
		var tp: float = ch.top
		var bot: float = H if ch.c == 0 else float(bands[ch.c - 1].top)
		if bot < y0 - 40 or tp > y1 + 40:
			continue
		var i := 0
		while i < (bot - tp) / 26:
			var x := R.r() * W
			var y := tp + R.r() * (bot - tp)
			var ii := i
			i += 1
			if y < y0 - 20 or y > y1 + 20:
				continue
			if in_river(x, y, 8):
				continue
			var dn := 1e9
			for n in nodes:
				dn = minf(dn, Vector2(n.x - x, n.y - y).length())
			if dn < 40:
				continue
			for k in 3:
				var fx := x + (R.r() - 0.5) * 14
				var fy := y + (R.r() - 0.5) * 6
				_c(ci, Vector2(fx, fy + 2), 2.4, Color("#3f7d3a"))
				var pc := Color(cols[ch.c][(ii + k) % 3])
				for q in 5:
					var a := q / 5.0 * TAU
					_c(ci, Vector2(fx + cos(a) * 1.9, fy + sin(a) * 1.9), 1.6, pc)
				_c(ci, Vector2(fx, fy), 1, Color("#fff3b8"))

func mango_tree(ci: CanvasItem, x: float, y: float, r: float, R) -> void:
	A.ell(ci, Vector2(x, y), r * 1.1, r * 0.3, Color(40 / 255.0, 60 / 255.0, 20 / 255.0, 0.25))
	ci.draw_rect(Rect2(x - r * 0.1, y - r * 0.9, r * 0.2, r * 0.9), Color("#6a4a2c"))
	for e in [[0, -1.3, 1, "#2f6a2a"], [-0.6, -1, 0.75, "#2f6a2a"], [0.6, -1.05, 0.75, "#2f6a2a"], [-0.2, -1.5, 0.7, "#3f8a36"], [0.3, -1.4, 0.6, "#4f9a3e"]]:
		_c(ci, Vector2(x + e[0] * r, y + e[1] * r), e[2] * r * 0.75, Color(e[3]))
	for i in 5:
		var ex: float = x + (R.r() - 0.5) * r * 1.3
		var ey: float = y - r * (0.8 + R.r() * 0.8)
		var pts := A.ell_pts(Vector2(ex, ey), r * 0.09, r * 0.13, 16, 0.3)
		ci.draw_colored_polygon(pts, Color("#f7c22a"))
		ci.draw_polyline(_closed(pts), Color("#a86a0c"), 1, true)

func palm(ci: CanvasItem, x: float, y: float, h: float, lean: float, seed: int) -> void:
	var R := D.SRand.new(seed)
	var tx := x + lean * h * 0.35
	var ty := y - h
	var trunk_a := Color("#8a6a48")
	var trunk_b := Color("#5e452c")
	var N := 14
	var pts := []
	for i in N + 1:
		var t := float(i) / N
		pts.append(Vector2(x + (tx - x) * t + lean * h * 0.12 * sin(t * PI), y + (ty - y) * t))
	for i in N:
		var t := float(i) / N
		var w := h * (0.055 - 0.025 * t)
		_ln(ci, pts[i], pts[i + 1] + Vector2(0, 0.5), trunk_a if i % 2 else trunk_b, w)
	var fr := 9 + int(R.r() * 3)
	var leaf_c := Color("#4f8f36")
	var leaf_d := Color("#2b5e22")
	var leaf_l := Color("#8cc95c")
	for pass_i in 2:
		for i in fr:
			var a := -PI / 2 + (float(i) / (fr - 1) - 0.5) * PI * 1.9 + (R.r() - 0.5) * 0.3
			var ln := h * (0.42 + R.r() * 0.16)
			var droop := 0.55 + R.r() * 0.35
			var ex := tx + cos(a) * ln
			var ey := ty + sin(a) * ln * 0.55 + ln * droop * 0.55
			var cx := tx + cos(a) * ln * 0.55
			var cy := ty + sin(a) * ln * 0.45 - ln * 0.12
			if pass_i == 0 and sin(a) < -0.2:
				continue
			if pass_i == 1 and sin(a) >= -0.2:
				continue
			var lw := maxf(1, h * 0.016)
			for k in range(1, 13):
				var t := k / 13.0
				var bx := (1 - t) * (1 - t) * tx + 2 * (1 - t) * t * cx + t * t * ex
				var by := (1 - t) * (1 - t) * ty + 2 * (1 - t) * t * cy + t * t * ey
				var dx := 2 * (1 - t) * (cx - tx) + 2 * t * (ex - cx)
				var dy := 2 * (1 - t) * (cy - ty) + 2 * t * (ey - cy)
				var dl := Vector2(dx, dy).length()
				if dl == 0:
					dl = 1
				var nx := -dy / dl
				var ny := dx / dl
				var ll := h * 0.13 * (1 - t * 0.6)
				var lc := leaf_c if k % 3 else leaf_d
				for s in [-1.0, 1.0]:
					ci.draw_polyline(A.quad_pts(Vector2(bx, by), Vector2(bx + nx * s * ll * 0.6 + dx / dl * ll * 0.2, by + ny * s * ll * 0.6 + ll * 0.3), Vector2(bx + nx * s * ll + dx / dl * ll * 0.35, by + ny * s * ll * 0.5 + ll * 0.75), 5), lc, lw, true)
			ci.draw_polyline(A.quad_pts(Vector2(tx, ty), Vector2(cx, cy), Vector2(ex, ey), 12), leaf_l, maxf(1, h * 0.014), true)
	for i in 4:
		_c(ci, Vector2(tx + (i - 1.5) * h * 0.035, ty + h * 0.03 + (i % 2) * h * 0.02), h * 0.03, Color("#6a8a2a"))

func hut(ci: CanvasItem, x: float, y: float, w: float) -> void:
	var h := w * 0.62
	for i in 5:
		ci.draw_rect(Rect2(x - w * 0.45 + i * w * 0.22, y - h * 0.08, w * 0.035, h * 0.3), Color("#6a4a2c"))
	var wx := x - w * 0.4
	var wy := y - h * 0.62
	var ww := w * 0.8
	var wh := h * 0.56
	ci.draw_rect(Rect2(wx, wy, ww, wh), Color("#c9a46a"))
	var lw := maxf(1, w * 0.008)
	for i in range(1, 10):
		ci.draw_line(Vector2(wx + ww * i / 10, wy), Vector2(wx + ww * i / 10, wy + wh), Color("#a3804a"), lw, true)
	ci.draw_rect(Rect2(x - w * 0.08, wy + wh * 0.3, w * 0.16, wh * 0.7), Color("#3a2a1c"))
	ci.draw_rect(Rect2(x + w * 0.17, wy + wh * 0.28, w * 0.13, wh * 0.28), Color("#4a3624"))
	ci.draw_rect(Rect2(x + w * 0.185, wy + wh * 0.3, w * 0.1, wh * 0.24), Color("#f2c35a"))
	var ytop := y - h * 1.12
	var ybot := wy + h * 0.06
	var roof := PackedVector2Array([Vector2(x - w * 0.56, ybot), Vector2(x - w * 0.32, ytop), Vector2(x + w * 0.32, ytop), Vector2(x + w * 0.56, ybot)])
	A.grad_poly(ci, roof, Vector2(0, ytop), Vector2(0, wy), [[0.0, Color("#c9a050")], [1.0, Color("#9a7232")]])
	var rl := maxf(1, w * 0.01)
	for i in 7:
		var yy := ytop + i * h * 0.17
		if yy > ybot:
			break
		var f := (yy - ytop) / (ybot - ytop)
		var half := w * (0.32 + 0.24 * f)
		var yy2 := yy + (rl / 4 if i == 0 else 0.0)
		ci.draw_line(Vector2(x - half, yy2), Vector2(x + half, yy2), Color("#7e5a24"), rl / 2 if i == 0 else rl, true)
	for i in 30:
		var xx := x - w * 0.55 + i * w * 0.037
		ci.draw_line(Vector2(xx, ybot), Vector2(xx + w * 0.01, wy - h * 0.04), Color("#e2c27a"), rl, true)
	ci.draw_polyline(_closed(roof), Color("#5a3e1a"), maxf(1, w * 0.014), true)

static func boat_draw(ci: CanvasItem, x: float, y: float, s: float, t: float, flip: bool) -> void:
	var bob := sin(t * 1.6) * s * 0.03
	var xf := Transform2D(0, Vector2(-1 if flip else 1, 1), 0, Vector2(x, y)) * Transform2D(0, Vector2(0, bob))
	ci.draw_set_transform_matrix(xf)
	var hull := PackedVector2Array([Vector2(-s, -s * 0.08)])
	hull.append_array(A.quad_pts(Vector2(-s, -s * 0.08), Vector2(0, s * 0.22), Vector2(s, -s * 0.14), 12).slice(1))
	hull.append(Vector2(s * 0.86, -s * 0.02))
	hull.append_array(A.quad_pts(Vector2(s * 0.86, -s * 0.02), Vector2(0, s * 0.3), Vector2(-s * 0.88, s * 0.02), 12).slice(1))
	_fill(ci, hull, Color("#5a3a1e"))
	var inner := A.quad_pts(Vector2(-s, -s * 0.08), Vector2(0, s * 0.1), Vector2(s, -s * 0.14), 12)
	inner.append_array(A.quad_pts(Vector2(s, -s * 0.14), Vector2(0, s * 0.02), Vector2(-s, -s * 0.08), 12).slice(1, 12))
	_fill(ci, inner, Color("#8a5a30"))
	var fc := ["#f7b820", "#e02f38", "#5fae36", "#f57a1c", "#8a2f7c"]
	for i in 7:
		_c(ci, Vector2(-s * 0.45 + i * s * 0.11, -s * 0.08 - ((i * 3) % 2) * s * 0.05), s * 0.07, Color(fc[i % 5]))
	ci.draw_rect(Rect2(s * 0.38, -s * 0.42, s * 0.14, s * 0.32), Color("#3c5a8a"))
	_c(ci, Vector2(s * 0.45, -s * 0.48), s * 0.07, Color("#e3b68a"))
	var hat := PackedVector2Array([Vector2(s * 0.27, -s * 0.5), Vector2(s * 0.45, -s * 0.66), Vector2(s * 0.63, -s * 0.5)])
	ci.draw_colored_polygon(hat, Color("#f1dca0"))
	ci.draw_polyline(_closed(hat), Color("#b0904a"), maxf(1, s * 0.015), true)
	var pa := sin(t * 1.6) * 0.25
	_ln(ci, Vector2(s * 0.42, -s * 0.36), Vector2(s * (0.15 + pa * 0.3), s * 0.15), Color("#4a3218"), maxf(1, s * 0.025))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

func paddy(ci: CanvasItem, x: float, y: float, R) -> void:
	var w: float = 80 + R.r() * 40
	var h: float = 40 + R.r() * 20
	ci.draw_rect(Rect2(x - w / 2, y - h / 2, w, h), Color("#93bf4a"))
	ci.draw_rect(Rect2(x - w / 2, y - h / 2, w, h), Color("#c9a46a"), false, 3)
	for i in 6:
		var yy := y - h / 2 + 6 + i * h / 6.5
		ci.draw_line(Vector2(x - w / 2 + 4, yy), Vector2(x + w / 2 - 4, yy), Color("#6a9e34"), 1.5, true)

func dien_dien(ci: CanvasItem, x: float, y: float, R) -> void:
	for i in 4:
		_ln(ci, Vector2(x, y), Vector2(x + (i - 1.5) * 8, y - 30 - R.r() * 10), Color("#5a7a2a"), 2)
	A.ell(ci, Vector2(x, y - 34), 22, 13, Color("#4f8a36"))
	for i in 10:
		var fx: float = x + (R.r() - 0.5) * 38
		var fy: float = y - 34 + (R.r() - 0.5) * 20
		_c(ci, Vector2(fx, fy), 3, Color("#f6cf2e"))

func haystack(ci: CanvasItem, x: float, y: float) -> void:
	A.ell(ci, Vector2(x, y), 26, 7, Color(60 / 255.0, 40 / 255.0, 10 / 255.0, 0.25))
	var pts := A.quad_pts(Vector2(x - 24, y), Vector2(x - 22, y - 40), Vector2(x, y - 46), 10)
	pts.append_array(A.quad_pts(Vector2(x, y - 46), Vector2(x + 22, y - 40), Vector2(x + 24, y), 10).slice(1))
	_fill(ci, pts, Color("#e8be5a"))
	ci.draw_polyline(_closed(pts), Color("#9a6e24"), 2, true)
	A.stroke(ci, A.quad_pts(Vector2(x - 18, y - 14), Vector2(x, y - 8), Vector2(x + 18, y - 14), 10), Color("#b88a34"), 2)
	ci.draw_rect(Rect2(x - 1.5, y - 56, 3, 12), Color("#6a4a2c"))

# ============================================================ thú trong vườn đã dựng (buildLife)
func _sp(id: String):
	for p in spots:
		if p.id == id:
			return p
	return null

func _build_life() -> void:
	life = []
	var add := func(name: String, typ: String, view: String, x: float, y: float, h: float, o := {}):
		var w := h * 1.4
		x = clampf(x, w * 0.5 + 4, W - w * 0.5 - 4)
		var a := {"name": name, "typ": typ, "view": view, "x": x, "y": y, "h": h, "w": w, "x0": x, "t": randf() * 5, "dir": 1.0}
		a.merge(o, true)
		life.append(a)
	if done_c(0):
		var a = _sp("nha1")
		var b = _sp("gieng")
		var d = _sp("cong")
		add.call("cho", "idle", "6", a.x + u * 1.4, a.y + u * 0.2, u * 1.15)
		add.call("ngong", "idle", "6", b.x - u * 1.3, b.y + u * 0.25, u * 1.1)
		add.call("meo", "idle", "6", d.x + u * 1.3, d.y + u * 0.1, u * 0.85)
	if done_c(1) and not riv.is_empty():
		for id in ["ghe", "ben"]:
			var q = _sp(id)
			if q == null:
				continue
			var y: float = q.y + u * (1.2 if id == "ghe" else -1.4)
			add.call("vit", "run", "4", rx(y), y, u * 0.85, {"swim": true, "range": rw(y) * 0.6, "sp": 22.0})
	if done_c(2):
		var a = _sp("ruong1")
		var b = _sp("ruong2")
		var m = _sp("rom")
		add.call("trau", "run", "4", a.x, a.y + u * 0.6, u * 1.5, {"walk": true, "range": u * 1.1, "sp": 14.0})
		add.call("de", "idle", "6", m.x - u * 1.3, m.y + u * 0.15, u * 1.0)
		add.call("bo", "idle", "6", b.x + u * 1.5, b.y + u * 0.3, u * 1.2)

func _tick_life(dt: float) -> void:
	for a in life:
		a.t += dt
		if a.get("walk", false) or a.get("swim", false):
			a.x += a.dir * a.sp * dt
			var lo: float = a.w * 0.5 + 4
			var hi: float = W - a.w * 0.5 - 4
			if absf(a.x - a.x0) > a.range or a.x < lo or a.x > hi:
				a.dir *= -1
				a.x = clampf(a.x0 + signf(a.x - a.x0) * minf(a.range, absf(a.x - a.x0)), lo, hi)

# vẽ thú, cắt phần dưới mặt nước (vịt bơi)
func _anim_clip(ci: CanvasItem, name: String, typ: String, view: String, frame: int, x: float, y: float, h: float, flip: bool, cut_y: float) -> void:
	var c0 = A.anim_cell(name, typ, view, 0)
	var c = A.anim_cell(name, typ, view, frame)
	if c0 == null or c == null or A.anim_tex == null:
		return
	var s: float = h / float(c0[3])
	var dst := Rect2(c[4] * s, c[5] * s, c[2] * s, c[3] * s)
	var src := Rect2(c[0], c[1], c[2], c[3])
	var lim := cut_y - y
	if dst.position.y >= lim:
		return
	if dst.end.y > lim:
		var k := (lim - dst.position.y) / dst.size.y
		dst.size.y *= k
		src.size.y *= k
	var xf := Transform2D(0, Vector2(x, y))
	if flip:
		xf = xf * Transform2D(0, Vector2(-1, 1), 0, Vector2.ZERO)
	ci.draw_set_transform_matrix(xf)
	ci.draw_texture_rect_region(A.anim_tex, dst, src)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_life(ci: CanvasItem, a: Dictionary) -> void:
	var w: float = a.w
	var h: float = a.h
	var fx: float = a.x
	var fy: float = a.y
	if a.get("swim", false):
		_anim_clip(ci, a.name, a.typ, a.view, int(floor(a.t * 6)), fx, fy, h, a.dir < 0, fy - h * 0.12)
		ci.draw_polyline(_closed(A.ell_pts(Vector2(fx, fy - h * 0.12), w * 0.32, h * 0.06, 28)), Color(1, 1, 1, 0.6), 1.5, true)
		var k := fmod(a.t * 1.2, 1.0)
		ci.draw_polyline(_closed(A.ell_pts(Vector2(fx - a.dir * w * 0.2 * k, fy - h * 0.1), w * (0.3 + k * 0.25), h * (0.06 + k * 0.04), 28)), Color(1, 1, 1, 0.5 * (1 - k)), 1.5, true)
	else:
		A.ell(ci, Vector2(fx, fy), w * 0.3, h * 0.07, Color(40 / 255.0, 60 / 255.0, 20 / 255.0, 0.22))
		var walk: bool = a.get("walk", false)
		A.anim(ci, a.name, a.typ, a.view, int(floor(a.t * (7 if walk else 5))), fx, fy, h, a.dir < 0 if walk else false)

# ============================================================ vẽ mỗi khung
func spot_rect(p: Dictionary) -> Rect2:
	var b := box_of(p)
	return Rect2(p.x + b[0] * u, p.y + b[1] * u, (b[2] - b[0]) * u, (b[3] - b[1]) * u)

func spot_tex(p: Dictionary, fixed: bool) -> Texture2D:
	return A.img("g_" + str(p.id) + ("1" if fixed else "0"))

func _glow_tex(p: Dictionary) -> Texture2D:
	var key: String = p.id
	if _glow.has(key):
		return _glow[key]
	var r := spot_rect(p)
	var pad := 10
	var w := int(ceil(r.size.x))
	var h := int(ceil(r.size.y))
	var src: Image = spot_tex(p, false).get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	src.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var W2 := w + pad * 2
	var H2 := h + pad * 2
	var al := PackedFloat32Array()
	al.resize(W2 * H2)
	for y in h:
		for x in w:
			al[(y + pad) * W2 + x + pad] = src.get_pixel(x, y).a
	# 3 lần mờ hộp ~ drop-shadow 6px
	var tmp := PackedFloat32Array()
	tmp.resize(W2 * H2)
	var rad := 2
	for _it in 3:
		for y in H2:
			var acc := 0.0
			for x in range(-rad, W2 + rad):
				var xi := x + rad
				if xi < W2:
					acc += al[y * W2 + xi]
				var xo := x - rad - 1
				if xo >= 0:
					acc -= al[y * W2 + xo]
				if x >= 0 and x < W2:
					tmp[y * W2 + x] = acc / (rad * 2 + 1)
		for x in W2:
			var acc := 0.0
			for y in range(-rad, H2 + rad):
				var yi := y + rad
				if yi < H2:
					acc += tmp[yi * W2 + x]
				var yo := y - rad - 1
				if yo >= 0:
					acc -= tmp[yo * W2 + x]
				if y >= 0 and y < H2:
					al[y * W2 + x] = acc / (rad * 2 + 1)
	var img := Image.create(W2, H2, false, Image.FORMAT_RGBA8)
	for y in H2:
		for x in W2:
			img.set_pixel(x, y, Color(244 / 255.0, 196 / 255.0, 48 / 255.0, minf(1.0, al[y * W2 + x] * 1.6) * 0.95))
	var t := ImageTexture.create_from_image(img)
	_glow[key] = t
	return t

func _wig_xf(p: Dictionary, r: Rect2) -> Transform2D:
	var t: float = _wig.get(p.id, -1.0)
	if t < 0 or t > 0.32:
		return Transform2D.IDENTITY
	var k := t / 0.32
	var sx := 1.0
	var sy := 1.0
	var ty := 0.0
	if k < 0.3:
		var e := k / 0.3
		sx = lerpf(1, 1.05, e)
		sy = lerpf(1, 0.95, e)
		ty = lerpf(0, 2, e)
	elif k < 0.6:
		var e := (k - 0.3) / 0.3
		sx = lerpf(1.05, 0.97, e)
		sy = lerpf(0.95, 1.04, e)
		ty = lerpf(2, 0, e)
	else:
		var e := (k - 0.6) / 0.4
		sx = lerpf(0.97, 1, e)
		sy = lerpf(1.04, 1, e)
	var c := r.get_center()
	return Transform2D(0, Vector2(0, ty) + c) * Transform2D(0, Vector2(sx, sy), 0, Vector2.ZERO) * Transform2D(0, -c)

func _fixing(p: Dictionary):
	for f in fxs:
		if f.p.id == p.id:
			return f
	return null

func _draw_content(ci: CanvasItem) -> void:
	var v0 := scroll - 80
	var v1 := scroll + VH() + 80
	ci.draw_rect(Rect2(0, v0, W, v1 - v0), Color("#7fb24a"))
	for s in slices:
		if s.y0 + s.h < v0 or s.y0 > v1:
			continue
		ci.draw_texture_rect(s.tex, Rect2(0, s.y0, W, s.h), false)
	var free := stars_free() if star_disp < 0 else star_disp
	# chỗ sửa vườn
	for p in spots:
		var r := spot_rect(p)
		if r.end.y + 30 < v0 or r.position.y > v1:
			continue
		var done: bool = game.save.garden.get(p.id, 0) != 0
		var op := open_c(p.c)
		var f = _fixing(p)
		var can = not done and op and stars_free() >= p.cost and f == null
		var xf := _wig_xf(p, r)
		var flip: bool = p.get("side", 0) == -1
		if flip:
			xf = xf * Transform2D(0, Vector2(-1, 1), 0, Vector2(2 * p.x, 0))
		ci.draw_set_transform_matrix(xf)
		if can:
			var gl := 0.5 - 0.5 * cos(_t / 1.6 * TAU)
			if gl > 0.02:
				ci.draw_texture_rect(_glow_tex(p), r.grow(10), false, Color(1, 1, 1, gl))
		var pop := 1.0
		var show_fixed := done
		if f != null and f.get("swapped", false):
			var q := clampf((f.k - 1.0) / 0.45, 0, 1)
			pop = 0.35 + 0.65 * game.ease_back(q) if q < 1 else 1.0
			show_fixed = true
		if pop != 1.0:
			ci.draw_set_transform_matrix(xf * Transform2D(0, Vector2(pop, pop), 0, Vector2(p.x, p.y)) * Transform2D(0, Vector2(-p.x, -p.y)))
		ci.draw_texture_rect(spot_tex(p, show_fixed), r, false)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		if not done and f == null:
			_draw_tag(ci, p, op, free)
	for a in life:
		if a.y < v0 - 100 or a.y - a.h > v1:
			continue
		_draw_life(ci, a)
	# tên vùng
	for ch in chapters:
		var ty: float = ch.y - 40
		if ty + 70 < v0 or ty > v1:
			continue
		var C: Dictionary = D.CHAPTERS[ch.c]
		A.text(ci, C.name, W / 2, ty + 18.7 + 3, 24, MUC, 1, 800, 1.5, MUC)
		A.text(ci, C.name, W / 2, ty + 18.7, 24, A.KEM, 1, 800, 1.5, MUC)
		var sw := A.tw(C.sub, 14, 700) + 20
		var sr := Rect2(W / 2 - sw / 2, ty + 51 - 11.5, sw, 23)
		A.box(ci, sr, MUC, 10)
		A.text(ci, C.sub, W / 2, sr.get_center().y + 0.5, 14, A.CREAM_TXT, 1, 700)
	# nút màn
	var cur: int = game.cur_level()
	for n in nodes:
		if n.y + 60 < v0 or n.y - 40 > v1:
			continue
		_draw_node(ci, n, cur)
	# trâu chờ bên màn đang chơi
	if cur < nodes.size():
		var n: Dictionary = nodes[cur]
		var left: bool = n.x < W / 2
		var lx: float = n.x + (34 if left else -124)
		A.anim(ci, "trau", "idle", "6", 0, lx + 45, n.y - 70 + 85, 75, left)
	for f in fxs:
		_draw_fx(ci, f)

func _draw_node(ci: CanvasItem, n: Dictionary, cur: int) -> void:
	var s: int = game.stars_of(n.i)
	var bg := A.KEM
	var fg := MUC
	var bc := MUC
	var shc := Color(43 / 255.0, 33 / 255.0, 24 / 255.0, 0.85)
	var sc := 1.0
	if s > 0:
		bg = A.VANG
	elif n.i == cur:
		bg = A.LA
		fg = Color("#fff8e6")
		sc = 1.0 + 0.06 * (0.5 - 0.5 * cos(_t / 1.1 * TAU))
	elif n.i > cur:
		bg = Color("#d8ccb2")
		fg = Color("#9a8a6c")
		bc = Color("#8a7a5c")
		shc = Color(90 / 255.0, 70 / 255.0, 40 / 255.0, 0.6)
	var c := Vector2(n.x + 3, n.y + 3)
	ci.draw_set_transform_matrix(Transform2D(0, Vector2(sc, sc), 0, c))
	_c(ci, Vector2(0, 5), 34, shc)
	_c(ci, Vector2.ZERO, 34, bc)
	_c(ci, Vector2.ZERO, 31, bg)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	A.text(ci, str(n.i + 1), c.x, c.y + 1, 25 * sc, fg, 1, 800)
	if s > 0:
		var x0 := c.x - (17 * 3 + 2) / 2.0
		for k in 3:
			var mod := Color.WHITE if k < s else Color(0.55, 0.55, 0.55, 0.45)
			ci.draw_texture_rect(A.img("svg_star"), Rect2(x0 + k * 18, n.y + 34, 17, 17), false, mod)

func _draw_tag(ci: CanvasItem, p: Dictionary, op: bool, free: int) -> void:
	var can: bool = op and free >= p.cost
	var cx: float = p.x
	var ty: float = p.y + 4
	if not op:
		var r := Rect2(cx - 16, ty, 32, 24)
		A.box(ci, Rect2(r.position + Vector2(0, 3), r.size), Color(43 / 255.0, 33 / 255.0, 24 / 255.0, 0.35), 12)
		A.box(ci, r, Color("#8a7a5c"), 12)
		A.box(ci, r.grow(-2), Color("#d8ccb2"), 10)
		ci.draw_texture_rect(A.img("svg_lk"), Rect2(cx - 8, ty + 4, 16, 16), false)
		return
	var num := str(p.cost)
	var nw := A.tw(num, 15, 800)
	var w := 2 + 6 + (17 + 2 if can else 0) + nw + 2 + 16 + 8 + 2
	var bob := -3.0 * (0.5 - 0.5 * cos(_t / 1.2 * TAU)) if can else 0.0
	var r := Rect2(cx - w / 2, ty + bob, w, 23)
	var bc := A.LA if can else MUC2
	A.box(ci, Rect2(r.position + Vector2(0, 3), r.size), A.LA_DK if can else Color(43 / 255.0, 33 / 255.0, 24 / 255.0, 0.35), 12)
	A.box(ci, r, bc, 12)
	A.box(ci, r.grow(-2), A.KEM, 10)
	var x := r.position.x + 8
	var cy := r.get_center().y + 0.5
	if can:
		ci.draw_texture_rect(A.img("svg_hm"), Rect2(x, cy - 8.5, 17, 17), false)
		x += 19
	A.text(ci, num, x, cy + 0.5, 15, A.LA_DK if can else MUC, 0, 800)
	x += nw + 2
	ci.draw_texture_rect(A.img("svg_star"), Rect2(x, cy - 8, 16, 16), false)

# ---------- thanh trên (mapTop)
func _top_geo() -> Dictionary:
	var VW: float = game.LAY.W
	var small := VW <= 430
	var fs := 16.0 if small else 18.0
	var padl := 10.0 if small else 16.0
	var ic := 19.0 if small else 22.0
	var gp := 4.0 if small else 6.0
	var ph := 9.0 if small else 14.0
	var h := 5.0 + (4.0 if small else 6.0) + fs * 1.56
	var cy := 10.0 + 20
	var out := {"fs": fs, "ic": ic, "gap": gp, "items": []}
	var x := padl
	var free := stars_free() if star_disp < 0 else star_disp
	var pills := [["star", "svg_star", str(free)], ["garden", "svg_hut", "%d/%d" % [count(), D.SPOTS.size()]]]
	if not small:
		pills.append(["xu", "svg_xuic", game.ui._num(int(game.save.xu))])
	for pl in pills:
		var w := 2.5 * 2 + ph * 2 + ic + gp + A.tw(pl[2], fs, 800)
		out.items.append({"id": pl[0], "kind": "pill", "icon": pl[1], "txt": pl[2], "r": Rect2(x, cy - h / 2, w, h)})
		x += w + (5.0 if small else 8.0)
	var xr := VW - padl
	var ib := ["sound"]
	if game.embed:
		ib = ["home", "sound"]
	var ibs := []
	for i in range(ib.size() - 1, -1, -1):
		var r := Rect2(xr - 40, cy - 20, 40, 40)
		ibs.push_front({"id": ib[i], "kind": "icon", "r": r})
		xr -= 40 + (5.0 if small else 8.0)
	var bfs := 15.0 if small else 16.0
	var lab := "Vựa trái" if game.embed else "Nông trại"
	var bw := A.tw(lab, bfs, 800) + bfs * (0.8 if small else 1.1) * 2
	var bh := bfs * 1.56 + bfs * 0.6
	out.items.append({"id": "farm", "kind": "btn", "txt": lab, "fs": bfs, "r": Rect2(xr - bw, cy - bh / 2, bw, bh)})
	out.items.append_array(ibs)
	return out

func _farm_note() -> bool:
	var F = game.farm
	for o in F.orders():
		if F.has_kho(o.want):
			return true
	for P in D.PETS:
		if F.pet(P.k).lv < 3 and F.has_kho(P.eat):
			return true
	return false

func _draw_top(ci: CanvasItem) -> void:
	var g := _top_geo()
	_items = g.items
	for it in g.items:
		var r: Rect2 = it.r
		var dn: bool = _press != null and _press.get("id") == it.id
		var off := Vector2(0, 3 if dn else 0)
		if it.kind == "pill" or it.kind == "icon":
			var rad := r.size.y / 2
			A.box(ci, Rect2(r.position + Vector2(0, 4 if not dn else 1) + off * 0, r.size), A.LIP_KEM, rad)
			A.box(ci, Rect2(r.position + off, r.size), A.GACH, rad)
			A.box(ci, Rect2(r.position + off, r.size).grow(-2.5), A.KEM, rad - 2.5)
			if it.kind == "pill":
				var ic: float = g.ic
				var x := r.position.x + 2.5 + (9.0 if g.fs < 17 else 14.0)
				var cy := r.get_center().y + off.y
				ci.draw_texture_rect(A.img(it.icon), Rect2(x, cy - ic / 2, ic, ic), false)
				A.text(ci, it.txt, x + ic + g.gap, cy + 1, g.fs, MUC, 0, 800)
			else:
				var c := r.get_center() + off
				if it.id == "home":
					ci.draw_texture_rect(A.img("svg_home"), Rect2(c.x - 11, c.y - 11, 22, 22), false)
				else:
					var on: bool = game.save.music or game.save.sfx
					var tex := A.img("svg_sound")
					var tw := tex.get_width()
					var th := tex.get_height()
					var cut := 14.5 / 24.0
					ci.draw_texture_rect_region(tex, Rect2(c.x - 11, c.y - 11, 22 * cut, 22), Rect2(0, 0, tw * cut, th))
					ci.draw_texture_rect_region(tex, Rect2(c.x - 11 + 22 * cut, c.y - 11, 22 * (1 - cut), 22), Rect2(tw * cut, 0, tw * (1 - cut), th), Color(1, 1, 1, 1.0 if on else 0.15))
		else:
			game.ui.btn(ci, r, it.txt, "la", it.fs, dn)
			if _farm_note():
				var c := Vector2(r.end.x + 3 - 6, r.position.y - 4 + 6) + off
				_c(ci, c, 8, A.KEM)
				_c(ci, c, 6, A.DO)

func _star_pill_pos() -> Vector2:
	var g := _top_geo()
	for it in g.items:
		if it.id == "star":
			return Vector2(it.r.position.x + 20, it.r.get_center().y)
	return Vector2(30, 30)

# ---------- sao bay (flystar)
static func _bez(t: float, x1: float, y1: float, x2: float, y2: float) -> float:
	# cubic-bezier: tìm s sao cho x(s)=t, trả y(s)
	var s := t
	for _i in 8:
		var x := 3 * (1 - s) * (1 - s) * s * x1 + 3 * (1 - s) * s * s * x2 + s * s * s - t
		var dx := 3 * (1 - s) * (1 - s) * x1 + 6 * (1 - s) * s * (x2 - x1) + 3 * s * s * (1 - x2)
		if absf(dx) < 1e-6:
			break
		s = clampf(s - x / dx, 0, 1)
	return 3 * (1 - s) * (1 - s) * s * y1 + 3 * (1 - s) * s * s * y2 + s * s * s

func _draw_fly(ci: CanvasItem) -> void:
	for f in flys:
		if f.t < 0:
			continue
		var p := _bez(clampf(f.t / 0.62, 0, 1), 0.4, 0.1, 0.5, 1)
		var pos: Vector2
		var sc: float
		if p < 0.45:
			var e := p / 0.45
			pos = f.a.lerp(f.m, e)
			sc = lerpf(1, 1.3, e)
		else:
			var e := (p - 0.45) / 0.55
			pos = f.m.lerp(f.b, e)
			sc = lerpf(1.3, 0.6, e)
		var s := 28.0 * sc
		ci.draw_texture_rect(A.img("svg_star"), Rect2(pos.x - s / 2, pos.y - s / 2, s, s), false)

# ============================================================ hiệu ứng sửa (GARDEN.fix / tickFx)
func wiggle(p: Dictionary) -> void:
	_wig[p.id] = 0.0

func fix(p: Dictionary) -> void:
	if stars_free() < p.cost or game.save.garden.get(p.id, 0):
		return
	busy = true
	var want := clampf(p.y - VH() * 0.55, 0, maxf(0, H - VH()))
	var far := absf(scroll - want) > VH() * 0.3
	if far:
		smooth_to(want)
	star_disp = stars_free()
	later(0.42 if far else 0.04, func():
		var a := _star_pill_pos()
		var b := Vector2(p.x, p.y - scroll - u * 0.4)
		for i in int(p.cost):
			var m := Vector2((a.x + b.x) / 2 + (60 if i % 2 else -60), minf(a.y, b.y) - 60)
			flys.append({"t": -i * 0.13, "a": a, "m": m, "b": b, "i": i, "started": false})
		var t0 = 0.62 + p.cost * 0.13
		fxs.append({"p": p, "k": -t0, "dur": 1.55, "parts": [], "hits": {}}))

func _tick_flys(dt: float) -> void:
	for f in flys:
		var was: float = f.t
		f.t += dt
		if was < 0 and f.t >= 0 and not f.started:
			f.started = true
			star_disp = maxi(0, star_disp - 1)
		if f.t >= 0.62 and not f.get("done", false):
			f.done = true
			game.snd.play("star", f.i)
	flys = flys.filter(func(f): return not f.get("done", false))

func _tick_fx(dt: float) -> void:
	for f in fxs:
		var p: Dictionary = f.p
		f.k += dt
		if f.k < 0:
			continue
		var k: float = f.k
		for h in [0.18, 0.48, 0.78]:
			if k >= h and not f.hits.has(h):
				f.hits[h] = true
				game.snd.play("hay")
				wiggle(p)
				for i in 9:
					f.parts.append({"x": (randf() - 0.5) * u * 1.4, "y": -u * 0.1, "vx": (randf() - 0.5) * 160, "vy": -60 - randf() * 120, "life": 0.6, "t": 0.0, "k": "dust", "s": u * (0.12 + randf() * 0.12)})
				for i in 5:
					f.parts.append({"x": u * 0.2, "y": -u * 0.6, "vx": (randf() - 0.5) * 260, "vy": -120 - randf() * 160, "life": 0.7, "t": 0.0, "k": "chip", "s": u * 0.1, "r": randf() * 3})
		if k >= 1.0 and not f.get("swapped", false):
			f.swapped = true
			game.save.garden[p.id] = 1
			game.persist()
			star_disp = -1
			game.snd.play("make")
			game.snd.play("coin")
			var pc := ["#e8507a", "#f4c430", "#ff8a3a"]
			for i in 26:
				var a := randf() * TAU
				var v := 120 + randf() * 200
				f.parts.append({"x": 0.0, "y": -u * 0.7, "vx": cos(a) * v, "vy": sin(a) * v - 120, "life": 1 + randf() * 0.4, "t": 0.0, "k": "leaf" if i % 3 else "petal", "s": u * (0.1 + randf() * 0.08), "r": randf() * 3, "c": pc[i % 3]})
		for s in f.parts:
			s.t += dt
			s.vy += (-30.0 if s.k == "dust" else 700.0 if s.k == "chip" else 260.0) * dt
			s.vx *= 0.97 if s.k == "leaf" or s.k == "petal" else 0.99
			s.x += s.vx * dt
			s.y += s.vy * dt
		if k > f.dur + 0.8:
			f.dead = true
			busy = false
			var c: int = p.c
			if done_c(c):
				later(0.25, func(): region_done(c))
	fxs = fxs.filter(func(f): return not f.get("dead", false))

func _draw_fx(ci: CanvasItem, f: Dictionary) -> void:
	if f.k < 0:
		return
	var p: Dictionary = f.p
	var k: float = f.k
	var o := Vector2(p.x, p.y)
	var hits := [0.18, 0.48, 0.78]
	if k < 1.0:
		var a := -1.1
		var ph := 1.0
		for h in hits:
			if k < h:
				ph = (h - k) / 0.3
				break
		var last := -1.0
		for h in hits:
			if k >= h:
				last = h
		if last >= 0 and k - last < 0.12:
			a = 0.15 - (k - last) / 0.12 * 0.4
		else:
			a = 0.15 - ph * 1.2
		var xf := Transform2D(a, o + Vector2(u * 0.75, -u * 1.1))
		ci.draw_set_transform_matrix(xf)
		var hd := A.rrect_pts(Rect2(-u * 0.08, -u * 0.05, u * 0.16, u * 0.95), u * 0.05, 3)
		ci.draw_colored_polygon(hd, Color("#7a4e26"))
		ci.draw_polyline(_closed(hd), GINK, 2, true)
		var hh := A.rrect_pts(Rect2(-u * 0.32, -u * 0.2, u * 0.64, u * 0.26), u * 0.05, 3)
		ci.draw_colored_polygon(hh, Color("#8a949a"))
		ci.draw_polyline(_closed(hh), GINK, 2, true)
		ci.draw_rect(Rect2(-u * 0.26, -u * 0.16, u * 0.5, u * 0.05), Color(1, 1, 1, 0.5))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if f.get("swapped", false):
		var q := clampf((k - 1.0) / 0.45, 0, 1)
		if q < 1:
			ci.draw_polyline(_closed(A.ell_pts(o + Vector2(0, -u * 0.1), u * (0.5 + q * 1.6), u * (0.16 + q * 0.5), 40)), Color(244 / 255.0, 196 / 255.0, 48 / 255.0, (1 - q) * 0.9), u * 0.12 * (1 - q) + 1, true)
	for s in f.parts:
		var al: float = 1 - s.t / s.life
		if al <= 0:
			continue
		var c := o + Vector2(s.x, s.y)
		if s.k == "dust":
			_c(ci, c, s.s * (1 + s.t * 1.5), Color(Color("#e9d6a8"), al))
		elif s.k == "chip":
			ci.draw_set_transform_matrix(Transform2D(s.r + s.t * 9, c))
			ci.draw_rect(Rect2(-s.s, -s.s * 0.3, s.s * 2, s.s * 0.6), Color(Color("#b07a42"), al))
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			var col := Color("#5fae36") if s.k == "leaf" else Color(s.c)
			ci.draw_set_transform_matrix(Transform2D(s.r + s.t * 5, c) * Transform2D(0, Vector2(1, cos(s.t * 9)), 0, Vector2.ZERO))
			A.ell(ci, Vector2.ZERO, s.s, s.s * 0.5, Color(col, al))
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)

func region_done(c: int) -> void:
	var key := "_c%d" % c
	if game.save.garden.get(key, 0):
		return
	game.save.garden[key] = 1
	for k in D.GIFT:
		game.save.boost[k] = int(game.save.boost.get(k, 0)) + int(D.GIFT[k])
	game.persist()
	game.snd.play("win")
	game.gfx.confetti(game.LAY.W, game.LAY.H)
	game.gfx.set_top(true)
	later(4.2, func(): game.gfx.set_top(false))
	var keep := scroll
	build_map()
	set_scroll(keep)
	var ui = game.ui
	var gift := {}
	for k in D.GIFT:
		gift["b_" + k] = D.GIFT[k]
	var bl := [ui.b_ribbon("Dựng vườn"), ui.b_h2(D.CHAPTERS[c].name, 26), ui.b_p("Xanh tốt lại rồi! Thú trong vườn ra chơi."), ui.b_haul("Bà con tặng", gift)]
	if c + 1 < D.CHAPTERS.size():
		var nx: Dictionary = D.CHAPTERS[c + 1]
		bl.append(ui.b_tipline("Vùng kế: %s. Tới màn %d là sửa được." % [nx.name, int(nx.from) + 1]))
	else:
		bl.append(ui.b_tipline("Miệt vườn đã dựng lại hết. Giỏi quá!"))
	bl.append(ui.b_row([["Hay quá", "la", "ok", func():
		game.snd.play("tap")
		ui.close_dlg()]]))
	ui.dialog(bl)

# ---------- bấm chỗ sửa (GARDEN.tap)
func tap_spot(p: Dictionary) -> void:
	if busy:
		return
	var done: bool = game.save.garden.get(p.id, 0) != 0
	var op := open_c(p.c)
	var free := stars_free()
	game.snd.play("tap")
	if done:
		wiggle(p)
		return
	var ui = game.ui
	var msg := ""
	var row := []
	var ok_b := func():
		game.snd.play("tap")
		ui.close_dlg()
	if not op:
		var reach: bool = game.cur_level() >= int(D.CHAPTERS[p.c].from)
		if reach:
			msg = "Dựng xong <b>%s</b> trước rồi mới tới đây." % D.CHAPTERS[p.c - 1].name
		else:
			msg = "Tới màn <b>%d</b> mới sửa được chỗ này." % (int(D.CHAPTERS[p.c].from) + 1)
		row = [["Ừ", "la", "ok", ok_b]]
	elif free < p.cost:
		msg = "Cần <b>%d</b> sao, đang có <b>%d</b>. Chơi thêm màn để kiếm sao nha." % [p.cost, free]
		row = [["Để sau", "kem", "ok", ok_b], ["Chơi màn %d" % (game.cur_level() + 1), "la", "play", func():
			game.snd.play("tap")
			ui.close_dlg()
			ui.pre(game.cur_level())]]
	else:
		msg = "Tốn <b>%d</b> sao, đang có <b>%d</b> sao." % [p.cost, free]
		var lab := "Sửa liền"
		if p.k in ["xoai", "dua", "dien", "ruong"]:
			lab = "Trồng liền"
		elif p.k == "cau":
			lab = "Bắc cầu"
		row = [["Để sau", "kem", "ok", ok_b], [lab, "la", "fix", func():
			ui.close_dlg()
			fix(p)]]
	ui.dialog([ui.b_ribbon("Dựng vườn"), ui.b_h2(p.n, 26), _b_fixprev(p), ui.b_p(msg), ui.b_row(row)])

func _b_fixprev(p: Dictionary) -> Dictionary:
	var b := box_of(p)
	var bw: float = b[2] - b[0]
	var bh: float = b[3] - b[1]
	var sc := minf(118 / bw, 104 / bh)
	var cw := maxf(110, bw * sc)
	var ch := bh * sc
	var hgt := 10 + ch + 2 + 18 + 6
	return {"h": hgt, "draw": func(ci, x, y, w):
		var aw := 22.0
		var tot := cw * 2 + aw + 16 + 24
		var r := Rect2(x + w / 2 - tot / 2, y, tot, hgt)
		A.box(ci, r, A.KEM2, 16)
		for j in 2:
			var fx := r.position.x + 12 + (cw + 8 + aw + 8) * j
			var ir := Rect2(fx + cw / 2 - bw * sc / 2, y + 10, bw * sc, ch)
			var on: String = p.get("on", "")
			var feet := Vector2(ir.position.x - b[0] * sc, ir.position.y - b[1] * sc)
			if on == "water" or on == "bridge":
				ci.draw_rect(Rect2(ir.position.x, feet.y - 0.05 * sc, ir.size.x, b[3] * sc + 0.05 * sc), Color("#5aa3b4"))
			elif on == "bank":
				var side: float = p.get("side", 1)
				var wdt: float = b[2] * sc * (1 if side > 0 else -1) * -1
				var rr := Rect2(feet.x, feet.y - 0.4 * sc, wdt, b[3] * sc + 0.4 * sc).abs()
				ci.draw_rect(rr, Color("#5aa3b4"))
			var flip: bool = p.get("side", 0) == -1
			if flip:
				ci.draw_set_transform_matrix(Transform2D(0, Vector2(-1, 1), 0, Vector2(2 * feet.x, 0)))
			ci.draw_texture_rect(spot_tex(p, j == 1), ir, false)
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
			A.text(ci, "Bây giờ" if j == 0 else "Sửa xong", fx + cw / 2, y + 10 + ch + 2 + 9, 13, MUC2, 1, 700)
		# mũi tên
		var ax := r.position.x + 12 + cw + 8
		var ay = y + 10 + ch / 2
		var col := A.GACH
		ci.draw_line(Vector2(ax + 2, ay), Vector2(ax + aw - 6, ay), col, 3.5, true)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(ax + aw - 9, ay - 6.5), Vector2(ax + aw, ay), Vector2(ax + aw - 9, ay + 6.5)]), col)}

func seek() -> void:
	var free := stars_free()
	var lst := []
	for p in spots:
		if not game.save.garden.get(p.id, 0) and open_c(p.c):
			lst.append(p)
	var pick = null
	for p in lst:
		if p.cost <= free:
			pick = p
			break
	if pick == null and lst.size():
		pick = lst[0]
	if pick == null:
		game.snd.play("tap")
		return
	smooth_to(pick.y - VH() * 0.55)
	later(0.45, func(): wiggle(pick))

func smooth_to(v: float) -> void:
	v = clampf(v, 0, maxf(0, H - VH()))
	_vel = 0.0
	_stw = {"a": scroll, "b": v, "t": 0.0, "dur": clampf(absf(v - scroll) / 2500.0, 0.25, 0.6)}

# ============================================================ mỗi khung
func tick(dt: float) -> void:
	if not visible:
		return
	_t += dt
	for i in range(_timers.size() - 1, -1, -1):
		_timers[i][0] -= dt
		if _timers[i][0] <= 0:
			var fn: Callable = _timers[i][1]
			_timers.remove_at(i)
			fn.call()
	if _stw != null:
		_stw.t += dt
		var k := clampf(_stw.t / _stw.dur, 0, 1)
		set_scroll(lerpf(_stw.a, _stw.b, game.ease_in_out(k)))
		if k >= 1:
			_stw = null
	elif not _down and absf(_vel) > 5:
		set_scroll(scroll + _vel * dt)
		_vel *= pow(0.05, dt)
		if scroll <= 0 or scroll >= H - VH():
			_vel = 0.0
	for id in _wig.keys():
		_wig[id] += dt
		if _wig[id] > 0.32:
			_wig.erase(id)
	_tick_life(dt)
	if fxs.size():
		_tick_fx(dt)
	if flys.size():
		_tick_flys(dt)
	content.queue_redraw()
	top.queue_redraw()
	fly.queue_redraw()

# ============================================================ chạm / kéo
func _gui_input(e: InputEvent) -> void:
	var pos := Vector2.ZERO
	var kind := ""
	if e is InputEventScreenTouch:
		if e.index != 0:
			return
		pos = e.position
		kind = "down" if e.pressed else "up"
	elif e is InputEventScreenDrag:
		if e.index != 0:
			return
		pos = e.position
		kind = "move"
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed:
				_stw = null
				set_scroll(scroll + (-60.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 60.0))
			accept_event()
			return
		if e.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = e.position
		kind = "down" if e.pressed else "up"
	elif e is InputEventMouseMotion:
		if not _down:
			return
		pos = e.position
		kind = "move"
	else:
		return
	accept_event()
	if kind == "down":
		_down = true
		_drag = false
		_p0 = pos
		_s0 = scroll
		_vel = 0.0
		_stw = null
		_ly = pos.y
		_lt = Time.get_ticks_msec() / 1000.0
		_press = _top_hit(pos)
	elif kind == "move" and _down:
		if not _drag and pos.distance_to(_p0) > 8:
			_drag = true
			_press = null
		if _drag:
			set_scroll(_s0 - (pos.y - _p0.y))
			var now := Time.get_ticks_msec() / 1000.0
			var dtt := now - _lt
			if dtt > 0.001:
				_vel = lerpf(_vel, -(pos.y - _ly) / dtt, 0.6)
			_ly = pos.y
			_lt = now
	elif kind == "up" and _down:
		_down = false
		var pr = _press
		_press = null
		if _drag:
			if Time.get_ticks_msec() / 1000.0 - _lt > 0.08:
				_vel = 0.0
			return
		_vel = 0.0
		if pr != null:
			var hp = _top_hit(pos)
			if hp != null and hp.id == pr.id:
				_tap_top(pr.id)
			return
		_tap_map(pos + Vector2(0, scroll))

func _top_hit(p: Vector2):
	for it in _items:
		if (it.r as Rect2).grow(3).has_point(p):
			return it
	return null

func _tap_top(id: String) -> void:
	match id:
		"star", "garden":
			game.snd.play("tap")
			seek()
		"xu":
			game.snd.play("tap")
			game.farm.show_tab("kho")
		"farm":
			game.snd.play("tap")
			var F = game.farm
			var tab: String = F.tab
			for o in F.orders():
				if F.has_kho(o.want):
					tab = "ghe"
					break
			if tab != "ghe":
				for P in D.PETS:
					if F.pet(P.k).lv < 3 and F.has_kho(P.eat):
						tab = "chuong"
						break
			F.show_tab(tab)
		"home":
			game.snd.play("tap")
			game.close_game()
		"sound":
			var on: bool = not (game.save.music or game.save.sfx)
			game.snd.set_music(on)
			game.snd.set_sfx(on)

func _tap_map(p: Vector2) -> void:
	# nút màn trước (nằm trên chỗ sửa)
	var cur: int = game.cur_level()
	for n in nodes:
		if Vector2(n.x + 3, n.y + 3).distance_to(p) <= 36:
			if n.i > cur:
				game.snd.play("bad")
				return
			game.snd.play("tap")
			game.ui.pre(n.i)
			return
	for i in range(spots.size() - 1, -1, -1):
		var s: Dictionary = spots[i]
		if spot_rect(s).has_point(p):
			tap_spot(s)
			return
