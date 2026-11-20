extends Control
# XẾP TRÁI: giao diện (08_ui.js + shell.html): thanh mục tiêu (mục tiêu | huy chương lượt | điểm + thanh sao),
# khay đồ (nghỉ, cuốc, trâu cày, đổi chỗ), lời nhắc, chữ to giữa màn, lời khen, màn đầu, hộp thoại (vô màn,
# thắng, thua, nghỉ xíu, dựng vườn). Kích thước lấy từ CSS của web (css px).

const A := preload("res://logic/xt/xt_art.gd")
const D := preload("res://logic/xt/xt_data.gd")

# ------------------------------------------------------------ một khối vẽ + bấm (thay phần tử DOM)
class Box extends Control:
	var fn: Callable
	var items: Array = []
	var press = null
	var full := false
	var on_bg: Callable
	var scroll := 0.0
	var max_scroll := 0.0
	var scroll_r := Rect2()
	var _drag := false
	var _y0 := 0.0
	var _s0 := 0.0
	func _init(f: Callable = Callable()) -> void:
		fn = f
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)
	func hit(p: Vector2):
		for i in range(items.size() - 1, -1, -1):
			var it: Dictionary = items[i]
			var r: Rect2 = it.r
			if it.get("sc", false):
				r.position.y -= scroll
				if not scroll_r.has_point(p):
					continue
			if it.get("off", false):
				continue
			if r.grow(3).has_point(p):
				return it
		return null
	func _has_point(p: Vector2) -> bool:
		if not visible:
			return false
		if full:
			return true
		return hit(p) != null
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
				if max_scroll > 0 and e.pressed:
					scroll = clampf(scroll + (-40.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 40.0), 0, max_scroll)
					queue_redraw()
				accept_event()
				return
			if e.button_index != MOUSE_BUTTON_LEFT:
				return
			pos = e.position
			kind = "down" if e.pressed else "up"
		elif e is InputEventMouseMotion:
			if press == null and not _drag:
				return
			pos = e.position
			kind = "move"
		else:
			return
		accept_event()
		if kind == "down":
			press = hit(pos)
			_drag = false
			_y0 = pos.y
			_s0 = scroll
			queue_redraw()
		elif kind == "move":
			if max_scroll > 0 and scroll_r.has_point(Vector2(pos.x, _y0)) and absf(pos.y - _y0) > 8:
				_drag = true
				press = null
			if _drag:
				scroll = clampf(_s0 - (pos.y - _y0), 0, max_scroll)
				queue_redraw()
		else:
			var it = press
			press = null
			queue_redraw()
			if _drag:
				_drag = false
				return
			var h = hit(pos)
			if it != null and h == it and it.tap.is_valid():
				it.tap.call()
			elif it == null and h == null and on_bg.is_valid():
				on_bg.call()
	func pressed(id) -> bool:
		return press != null and press.get("id") == id

var game
var dirty := true
var dirty_dlg := false
var farm_rew = null
var hud: Box
var tray: Box
var tipw: Box
var fxl: Box     # chữ to, lời khen
var dlg: Box
var title: Box
var _tip := ""
var _tip_t := 0.0
var _banner := {"a": "", "b": "", "t": 9.0}
var _praise := {"txt": "", "t": 9.0, "last": 0, "lt": 0.0}
var _bump := {}
var _dlg := {}
var _dlg_t := 0.0
var _stars_on := []
var _rects := {}

func _init(gm) -> void:
	game = gm
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func build_overlays() -> void:
	hud = Box.new(_draw_hud)
	add_child(hud)
	tray = Box.new(_draw_tray)
	add_child(tray)
	tipw = Box.new(_draw_tip)
	tipw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tipw)
	fxl = Box.new(_draw_fxl)
	fxl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fxl)
	title = Box.new(_draw_title)
	title.full = true
	add_child(title)
	hud.visible = false
	tray.visible = false

# hộp thoại nằm trên cả bản đồ: gọi sau khi bản đồ, nông trại vào cây
func build_dlg() -> void:
	dlg = Box.new(_draw_dlg)
	dlg.full = true
	dlg.visible = false
	game.add_child(dlg)

func relayout() -> void:
	var W: float = game.LAY.W
	var H: float = game.LAY.H
	for b in [hud, tray, tipw, fxl, title]:
		b.position = Vector2.ZERO
		b.size = Vector2(W, H)
	if dlg == null:
		build_dlg()
	dlg.position = Vector2.ZERO
	dlg.size = Vector2(W, H)
	_place()
	if _dlg.size():
		_layout_dlg()

func dlg_open() -> bool:
	return dlg != null and dlg.visible

# ------------------------------------------------------------ HUD
func build_hud() -> void:
	hud.visible = true
	tray.visible = true
	_bump = {}
	dirty = true
	_place()

func hide_hud() -> void:
	hud.visible = false
	tray.visible = false
	_tip = ""

func _place() -> void:
	var L: Dictionary = game.LAY
	var W: float = L.W
	var H: float = L.H
	if L.portrait:
		var w := minf(W - 16, 600)
		_rects.bar = Rect2((W - w) / 2, 8, w, L.hudH)
		var tw := minf(W - 16, 420)
		_rects.tray = Rect2((W - tw) / 2, H - L.trayH - 10, tw, L.trayH)
		_rects.tip_bottom = L.trayH + 22
	else:
		var w2: float = L.col
		var left := maxf(12.0, (L.bx - w2) / 2)
		var bh := 260.0
		_rects.bar = Rect2(left, maxf(12.0, L.by), w2, bh)
		_rects.tray = Rect2(left, _rects.bar.end.y + 14, w2, 72)
		_rects.tip_bottom = -(_rects.bar.end.y + 96)

func goal_icon(g: Dictionary) -> Texture2D:
	match g.type:
		"fruit": return A.img("f%d" % g.k)
		"mud": return A.img("mud21")
		"hay": return A.img("hay2")
		"egg": return A.img("egg")
	return A.img("svg_star")

static func goal_icon_scale(g: Dictionary) -> float:
	# icon của web: hình 1.5 ô thu .66, ngôi sao .76
	return 1.0 if g.type == "score" else 1.0

func _goal_rects() -> Array:
	var b: Rect2 = _rects.bar
	var out := []
	var x := b.position.x + 13
	var y := b.position.y + 3 + 8 + 2 + 4 + 12 + 3
	for i in game.B.goals.size():
		out.append(Rect2(x + i * 44, y, 40, 53))
	return out

func goal_pos(t: String) -> Vector2:
	var gs: Array = game.B.goals
	var rs := _goal_rects()
	for i in gs.size():
		if gs[i].type == t and i < rs.size():
			return rs[i].get_center()
	return _rects.bar.get_center() if _rects.has("bar") else Vector2.ZERO

func moves_pos() -> Vector2:
	return _moves_c()

func _moves_c() -> Vector2:
	var b: Rect2 = _rects.bar
	return Vector2(b.get_center().x, b.position.y + 3 + 6 + 17 - 8 + 43)

func bump(g: Dictionary) -> void:
	_bump[game.B.goals.find(g)] = 0.0
func bump_type(t: String) -> void:
	for g in game.B.goals:
		if g.type == t:
			bump(g)
			return

static func khan(ci: CanvasItem, r: Rect2, cs := 5.0, light := Color("#f6f1e4"), a := 1.0) -> void:
	var dark := A.INK
	dark.a = a
	light.a = a
	var nx := int(ceil(r.size.x / cs))
	var ny := int(ceil(r.size.y / cs))
	for j in ny:
		for i in nx:
			var rr := Rect2(r.position.x + i * cs, r.position.y + j * cs, cs, cs).intersection(r)
			ci.draw_rect(rr, dark if (i + j) % 2 == 0 else light)

func _draw_hud(ci: Box) -> void:
	var B = game.B
	if not game.in_game:
		return
	var b: Rect2 = _rects.bar
	var t: float = game.clock
	A.box(ci, b, A.GACH, 22, 0, Color(), [[0, 8, 20, Color(40 / 255.0, 25 / 255.0, 10 / 255.0, 0.28)]])
	A.box(ci, b.grow(-3), A.KEM, 19)
	khan(ci, Rect2(b.position.x + 14, b.position.y + 3, b.size.x - 28, 6), 5, Color("#f6f1e4"), 0.75)
	# mục tiêu
	A.text(ci, "MỤC TIÊU", b.position.x + 13, b.position.y + 3 + 8 + 2 + 4 + 6, 12, Color(A.INK2, 0.8), 0, 700)
	var rs := _goal_rects()
	for i in B.goals.size():
		var g: Dictionary = B.goals[i]
		var r: Rect2 = rs[i]
		var bs := 1.0
		if _bump.has(i):
			var q: float = _bump[i] / 0.3
			bs = 1 + 0.2 * (q / 0.4 if q < 0.4 else (1 - q) / 0.6)
		var left := maxi(0, g.need - g.got)
		var done := left == 0
		var xf := Transform2D(0, Vector2(bs, bs), 0, r.get_center())
		ci.draw_set_transform_matrix(xf)
		var lr := Rect2(-r.size / 2, r.size)
		A.box(ci, lr, Color("#dcebc4") if done else A.KEM2, 12, 0, Color(), [], xf)
		ci.draw_set_transform_matrix(xf)
		_icon(ci, goal_icon(g), Rect2(lr.position.x + 4, lr.position.y + 2, 32, 32), g.type == "score")
		var txt := ""
		if g.type == "score":
			txt = (str(ceil(left / 100.0) / 10.0).trim_suffix(".0") + "k") if left else "✓"
		else:
			txt = str(left) if left else ""
		A.text(ci, txt, 0, lr.position.y + 2 + 32 + 7, 15, A.LA if done else A.INK, 1, 800, 0, A.INK, xf)
		if done:
			ci.draw_set_transform_matrix(xf)
			var cc := Vector2(lr.end.x + 4 - 9, lr.position.y - 4 + 9)
			ci.draw_circle(cc, 9 + 2, A.KEM)
			ci.draw_circle(cc, 9, A.LA)
			ci.draw_polyline(PackedVector2Array([cc + Vector2(-4, 0.5), cc + Vector2(-1, 3), cc + Vector2(4, -3)]), Color("#fff"), 2.2, true)
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	# điểm
	var rx := b.end.x - 13
	A.text(ci, "ĐIỂM", rx, b.position.y + 3 + 8 + 2 + 4 + 6, 12, Color(A.INK2, 0.8), 2, 700)
	A.text(ci, _num(B.score), rx, b.position.y + 3 + 8 + 2 + 4 + 12 + 3 + 14, 26, A.INK, 2, 800)
	var sb := Rect2(b.get_center().x + 53 + 6, b.position.y + 3 + 8 + 2 + 4 + 12 + 3 + 28 + 9, 0, 10)
	sb.size.x = rx - 6 - sb.position.x
	A.box(ci, sb, A.KEM2, 6)
	ci.draw_rect(Rect2(sb.position.x + 2, sb.position.y, sb.size.x - 4, 1.5), Color(0, 0, 0, 0.12))
	var st: Array = B.stars
	var mx: float = st[2] * 1.08
	var fw := clampf(B.score / mx, 0, 1) * sb.size.x
	if fw > 1:
		var fr := Rect2(sb.position, Vector2(fw, 10))
		A.grad_poly(ci, A.rrect_pts(fr, 5), Vector2(0, fr.position.y), Vector2(0, fr.end.y), [[0.0, A.VANG], [1.0, Color("#e8a21a")]])
	for i in 3:
		var on: bool = B.score >= st[i]
		var c := Vector2(sb.position.x + st[i] / mx * sb.size.x, sb.get_center().y)
		var s := 18.0 * (1.15 if on else 1.0)
		_icon(ci, A.img("svg_star"), Rect2(c - Vector2(s, s) / 2, Vector2(s, s)), true, Color(1, 1, 1, 1) if on else Color(0.55, 0.55, 0.55, 0.5))
	# tên màn + huy chương lượt
	var mc := _moves_c()
	var low: bool = B.moves <= 5 and not B.over
	var pul := 1.0 + (0.06 * (0.5 - 0.5 * cos(t / 0.8 * TAU)) if low else 0.0)
	var xf2 := Transform2D(0, Vector2(pul, pul), 0, mc)
	ci.draw_set_transform_matrix(xf2)
	ci.draw_circle(Vector2(0, 8), 49, Color(40 / 255.0, 25 / 255.0, 10 / 255.0, 0.18))
	ci.draw_circle(Vector2.ZERO, 49, A.GACH)
	ci.draw_circle(Vector2.ZERO, 46, A.KEM)
	var c0 := Color("#f0684a") if low else Color("#5a9c46")
	var c1 := A.DO if low else A.LA
	var c2 := Color("#9a2a18") if low else Color("#336a2e")
	_radial_off(ci, Vector2(-43 * 0.2, -43 * 0.36), 43, c0, c1, c2)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	A.text(ci, str(B.moves), 0, 4 + 2, 36, Color("#fff8e6"), 1, 800, 0, A.INK, xf2)
	A.text(ci, "LƯỢT", 0, 24, 12, Color(1, 0.97, 0.9, 0.9), 1, 700, 0, A.INK, xf2)
	var lv := "Màn %d" % (B.lv_idx + 1)
	var lw := A.tw(lv, 13, 800) + 20
	var lr2 := Rect2(mc.x - lw / 2, mc.y - 43 - 17 + 8 - 2, lw, 17)
	A.box(ci, Rect2(lr2.position + Vector2(0, 2), lr2.size), A.GACH_DK, 10)
	A.box(ci, lr2, A.GACH, 10)
	A.text(ci, lv, mc.x, lr2.get_center().y + 0.5, 13, A.CREAM_TXT, 1, 800)

func _radial_off(ci: CanvasItem, f: Vector2, r: float, c0: Color, c1: Color, c2: Color) -> void:
	# radial-gradient(circle at 40% 32%, c0, c1 60%, c2): tâm lệch, quạt tam giác
	var n := 40
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * r)
	for k in 5:
		var t0 := float(k) / 5
		var t1 := float(k + 1) / 5
		for i in n:
			var p0: Vector2 = f.lerp(pts[i], t0)
			var p1: Vector2 = f.lerp(pts[i], t1)
			var p2: Vector2 = f.lerp(pts[(i + 1) % n], t1)
			var p3: Vector2 = f.lerp(pts[(i + 1) % n], t0)
			var dmax := (pts[i] - f).length() / (r * 1.32)
			var ca := _g3(c0, c1, c2, t0 * dmax)
			var cb := _g3(c0, c1, c2, t1 * dmax)
			ci.draw_polygon(PackedVector2Array([p0, p1, p2, p3]), PackedColorArray([ca, cb, cb, ca]))

static func _g3(a: Color, b: Color, c: Color, t: float) -> Color:
	return a.lerp(b, t / 0.6) if t < 0.6 else b.lerp(c, clampf((t - 0.6) / 0.4, 0, 1))

func _icon(ci: CanvasItem, tex: Texture2D, r: Rect2, star := false, mod := Color.WHITE) -> void:
	if tex == null:
		return
	if star:
		var q := r.size * 0.76 if r.size.x > 24 else r.size
		ci.draw_texture_rect(tex, Rect2(r.get_center() - q / 2, q), false, mod)
		return
	# ảnh trái vẽ sẵn: 1.5 ô, web thu .66 khi làm icon
	var s := r.size * 0.99
	ci.draw_texture_rect(tex, Rect2(r.get_center() - s / 2, s), false, mod)

static func _num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if n < 0 else "") + out

# ------------------------------------------------------------ khay đồ
const TRAY := [["pause", "Nghỉ"], ["cuoc", "Cuốc"], ["trau", "Trâu cày"], ["doi", "Đổi chỗ"]]
func _draw_tray(ci: Box) -> void:
	if not game.in_game:
		ci.items = []
		return
	var r: Rect2 = _rects.tray
	A.box(ci, r, A.GACH, 20, 0, Color(), [[0, 8, 20, Color(40 / 255.0, 25 / 255.0, 10 / 255.0, 0.28)]])
	A.box(ci, r.grow(-3), A.KEM, 17)
	var inner := Rect2(r.position.x + 3 + 6, r.position.y + 3 + 4, r.size.x - 6 - 12, r.size.y - 6 - 8)
	var n := TRAY.size()
	var gap := 2.0
	var bw := (inner.size.x - 6 - gap * (n - 1)) / n
	ci.items = []
	var x := inner.position.x
	for i in n:
		var k: String = TRAY[i][0]
		var br := Rect2(x, inner.position.y, bw, inner.size.y)
		x += bw + gap + (6 if i == 0 else 0)
		var on: bool = game.boost == k
		var down := ci.pressed(k)
		var off := Vector2(0, 2) if down else Vector2.ZERO
		if on:
			A.box(ci, Rect2(br.position + off, br.size), A.VANG, 14)
		var ic := Rect2(br.get_center().x - 19, br.position.y + 3 + off.y + (br.size.y - 38 - 18 - 5) / 2, 38, 38)
		if k == "pause":
			ci.draw_texture_rect(A.img("svg_pause"), ic, false)
		else:
			var cnt := int(game.save.boost.get(k, 0))
			ci.draw_texture_rect(A.img("b_" + k), ic, false, Color(0.62, 0.6, 0.58, 0.55) if cnt == 0 else Color.WHITE)
			var bc := Vector2(br.end.x - 4 - 10, br.position.y + 10 + off.y)
			ci.draw_circle(bc, 12, A.KEM)
			ci.draw_circle(bc, 10, A.LA)
			A.text(ci, str(cnt), bc.x, bc.y + 0.5, 13, Color("#fff8e6"), 1, 800)
		A.text(ci, TRAY[i][1], br.get_center().x, ic.end.y + 9, 13, A.INK if on else A.INK2, 1, 700)
		if i == 0:
			ci.draw_rect(Rect2(br.end.x + 2, br.position.y + 10, 2, br.size.y - 20), A.KEM2)
		var kk := k
		ci.items.append({"r": br, "id": k, "tap": func():
			game.snd.init()
			if kk == "pause":
				game.snd.play("tap")
				pause()
			else:
				game.toggle_boost(kk)})

# ------------------------------------------------------------ lời nhắc, chữ to, lời khen
func tip(t: String, dur := 0.0) -> void:
	_tip = t
	_tip_t = dur

func _draw_tip(ci: Box) -> void:
	if _tip == "" or not game.in_game:
		return
	var L: Dictionary = game.LAY
	var maxw := minf(L.W - 32, 440)
	var lines := A.wrap(_tip, 15, 700, maxw - 28)
	var w := 0.0
	for ln in lines:
		w = maxf(w, A.tw(ln, 15, 700))
	w += 28
	var h := lines.size() * 20.0 + 12
	var tb: float = _rects.tip_bottom
	var y: float = L.H - tb - h if tb > 0 else -tb
	var r := Rect2(L.W / 2 - w / 2, y, w, h)
	A.box(ci, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.18), 14)
	A.box(ci, r, A.INK, 14)
	for i in lines.size():
		A.text(ci, lines[i], L.W / 2, r.position.y + 6 + 10 + i * 20, 15, A.CREAM_TXT, 1, 700)

func banner(a: String, b := "") -> void:
	_banner = {"a": a, "b": b, "t": 0.0}

const PR := ["", "", "", "Ngon!", "Đã quá!", "Hết sẩy!", "Bá cháy!", "Trùm miệt vườn!"]
func praise(n: int) -> void:
	if _praise.last == n:
		return
	_praise.last = n
	_praise.lt = 1.2
	_praise.txt = PR[mini(n, 7)]
	_praise.t = 0.0

static func _kf(t: float, keys: Array) -> Array:
	# keys [[t, scale, alpha, dy]] nội suy tuyến tính
	if t <= keys[0][0]:
		return keys[0].slice(1)
	for i in range(1, keys.size()):
		if t <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var q: float = (t - a[0]) / maxf(0.0001, b[0] - a[0])
			return [lerpf(a[1], b[1], q), lerpf(a[2], b[2], q), lerpf(a[3], b[3], q)]
	return keys[keys.size() - 1].slice(1)

func _draw_fxl(ci: Box) -> void:
	var L: Dictionary = game.LAY
	var W: float = L.W
	if _banner.t < 1.4:
		var k: Array = _kf(_banner.t / 1.4, [[0.0, 0.3, 0.0, 0.0], [0.15, 1.1, 1.0, 0.0], [0.25, 1.0, 1.0, 0.0], [0.8, 1.0, 1.0, 0.0], [1.0, 1.0, 0.0, -0.1]])
		var fs := clampf(W * 0.09, 40, 72)
		var hb := fs + (38.0 if _banner.b != "" else 0.0)
		var c := Vector2(W / 2, L.H * 0.44 + k[2] * hb)
		var xf := Transform2D(0, Vector2(k[0], k[0]), 0, c)
		var y0 := -hb / 2 + fs / 2
		var al: float = k[1]
		A.text(ci, _banner.a, 0, y0 + 5, fs, Color(A.INK, al), 1, 800, 2, Color(A.INK, al), xf)
		A.text(ci, _banner.a, 0, y0, fs, Color(A.VANG, al), 1, 800, 2, Color(A.INK, al), xf)
		if _banner.b != "":
			var sw := A.tw(_banner.b, 18, 700) + 24
			var sr := Rect2(-sw / 2, y0 + fs / 2 + 10, sw, 26)
			ci.draw_set_transform_matrix(xf)
			A.box(ci, sr, Color(A.INK, al), 12, 0, Color(), [], xf)
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
			A.text(ci, _banner.b, 0, sr.get_center().y + 1, 18, Color(A.CREAM_TXT, al), 1, 700, 0, A.INK, xf)
	if _praise.t < 0.95 and game.in_game:
		var k2: Array = _kf(_praise.t / 0.95, [[0.0, 0.4, 0.0, 0.0], [0.18, 1.12, 1.0, 0.0], [0.3, 1.0, 1.0, 0.0], [0.75, 1.0, 1.0, -0.15], [1.0, 1.0, 0.0, -0.4]])
		var c2 := Vector2(L.bx + L.bw / 2, minf(L.by + L.bh + 8, L.H - 30) + k2[2] * 34)
		var xf2 := Transform2D(0, Vector2(k2[0], k2[0]), 0, c2)
		var a2: float = k2[1]
		A.text(ci, _praise.txt, 0, 3, 34, Color(A.INK, a2), 1, 800, 1.5, Color(A.INK, a2), xf2)
		A.text(ci, _praise.txt, 0, 0, 34, Color(A.VANG, a2), 1, 800, 1.5, Color(A.INK, a2), xf2)

# ------------------------------------------------------------ mỗi khung
func update(dt: float) -> void:
	for k in _bump.keys():
		_bump[k] += dt
		if _bump[k] > 0.3:
			_bump.erase(k)
	_banner.t += dt
	_praise.t += dt
	if _praise.lt > 0:
		_praise.lt -= dt
		if _praise.lt <= 0:
			_praise.last = 0
	if _tip_t > 0:
		_tip_t -= dt
		if _tip_t <= 0:
			_tip = ""
	_dlg_t += dt
	if game.in_game:
		hud.queue_redraw()
		tray.queue_redraw()
		tipw.queue_redraw()
	fxl.queue_redraw()
	if title.visible:
		title.queue_redraw()
	if dlg != null and dlg.visible:
		if dirty_dlg:
			dirty_dlg = false
			_layout_dlg()
		dlg.queue_redraw()
	dirty = false

# ------------------------------------------------------------ màn đầu
func show_title() -> void:
	title.visible = true
	game.mapv.hide_map()

func hide_title() -> void:
	title.visible = false

func _title_geo() -> Dictionary:
	var L: Dictionary = game.LAY
	var W: float = L.W
	var H: float = L.H
	var fs := clampf(W * 0.16, 64, 124)
	var es := clampf(W * 0.045, 22, 34)
	var logo_h := fs * 0.86 + 14 + es * 0.86
	var sub_lines := A.wrap("Ráp trái cây miền Tây, có trâu, heo, gà, vịt phụ một tay", 17, 700, W * 0.9 - 28)
	var sub_h := sub_lines.size() * 17 * 1.56 + 8
	var bt_h := 26 * 1.56 + 0.7 * 26
	var home_h := 16 * 1.56 + 0.6 * 16
	var total := logo_h + 18 + sub_h + 18 + bt_h + (18 + home_h if game.embed else 0.0)
	var top := (H - total) / 2 + H * 0.06 - 8.5
	return {"fs": fs, "es": es, "top": top, "logo_h": logo_h, "sub": sub_lines, "sub_h": sub_h, "bt_h": bt_h, "home_h": home_h}

func draw_title_fruit(ci: CanvasItem) -> void:
	if not title.visible:
		return
	var g := _title_geo()
	var L: Dictionary = game.LAY
	var cxm: float = L.W / 2
	var lw := A.tw("Xếp Trái", g.fs, 800)
	var s := clampf(L.W * 0.13, 48, 84)
	var now: float = game.clock
	var rtop: float = g.top
	var rh: float = g.logo_h
	for i in 6:
		var a := PI * (1.12 + i * 0.152)
		var R := lw * 0.62 + s * 0.3
		var b := sin(now * 2 + i) * s * 0.08
		ci.draw_texture_rect(A.img("f%d" % i), Rect2(cxm + cos(a) * R - s * 0.75, rtop + rh * 0.62 + sin(a) * R * 0.62 - s * 0.75 + b, s * 1.5, s * 1.5), false)

func _draw_title(ci: Box) -> void:
	var g := _title_geo()
	var L: Dictionary = game.LAY
	var cx: float = L.W / 2
	var t: float = _dlg_t
	var y: float = g.top
	var fs: float = g.fs
	# logo: "Xếp Trái", chữ kem viền mực, bóng đặc 6px
	var w1 := A.tw("Xếp ", fs, 800)
	var w2 := A.tw("Trái", fs, 800)
	var x0 := cx - (w1 + w2) / 2
	var ly := y + fs * 0.43
	for pass_i in 2:
		var dy := 6.0 if pass_i == 0 else 0.0
		A.text(ci, "Xếp ", x0, ly + dy, fs, A.KEM if pass_i else A.INK, 0, 800, 3, A.INK)
		A.text(ci, "Trái", x0 + w1, ly + dy, fs, A.VANG if pass_i else A.INK, 0, 800, 3, A.INK)
	var es: float = g.es
	var ew := A.tw("Miệt Vườn", es, 800) + 40
	var er := Rect2(cx - ew / 2, y + fs * 0.86 + 14, ew, es * 0.86)
	A.box(ci, Rect2(er.position + Vector2(0, 4), er.size), A.GACH_DK, 14)
	A.box(ci, er, A.GACH, 14)
	if er.size.y - 16 > 0.5:
		khan(ci, Rect2(er.position.x - 22, er.position.y + 8, 14, er.size.y - 16), 5)
		khan(ci, Rect2(er.end.x + 8, er.position.y + 8, 14, er.size.y - 16), 5)
	A.text(ci, "Miệt Vườn", cx, er.get_center().y + 1, es, A.CREAM_TXT, 1, 800)
	y += g.logo_h + 18
	var sw := 0.0
	for ln in g.sub:
		sw = maxf(sw, A.tw(ln, 17, 700))
	if g.sub.size() > 1:
		sw = L.W * 0.9 - 28
	var sr := Rect2(cx - sw / 2 - 14, y, sw + 28, g.sub_h)
	A.box(ci, sr, Color(43 / 255.0, 33 / 255.0, 24 / 255.0, 0.7), 12)
	for i in g.sub.size():
		A.text(ci, g.sub[i], cx, y + 4 + 17 * 1.56 * (i + 0.5), 17, A.CREAM_TXT, 1, 700)
	y += g.sub_h + 18
	ci.items = []
	var r1 := btn_rect("Vô chơi", cx, y, 26, 2.2, 0.35)
	btn(ci, r1, "Vô chơi", "la", 26, ci.pressed("play"))
	ci.items.append({"r": r1, "id": "play", "tap": func():
		game.snd.init()
		game.snd.play("tap")
		game.mapv.show_map()})
	y += g.bt_h + 18
	if game.embed:
		var r2 := btn_rect("Về vườn", cx, y, 16, 1.1, 0.3)
		btn(ci, r2, "Về vườn", "kem", 16, ci.pressed("home"))
		ci.items.append({"r": r2, "id": "home", "tap": func():
			game.snd.play("tap")
			game.close_game()})

# ------------------------------------------------------------ nút
func btn_rect(lab: String, cx: float, top: float, fs: float, padx := 1.5, pady := 0.42) -> Rect2:
	var w := A.tw(lab, fs, 800) + fs * padx * 2
	var h := fs * 1.56 + fs * pady * 2 - fs * 0.04
	return Rect2(cx - w / 2, top, w, h)

func btn(ci: CanvasItem, r: Rect2, lab: String, kind: String, fs: float, down := false, disabled := false) -> void:
	var bg := A.VANG
	var lip := A.VANG_DK
	var fg := A.INK
	if kind == "la":
		bg = A.LA
		lip = A.LA_DK
		fg = Color("#fff8e6")
	elif kind == "kem":
		bg = A.KEM
		lip = A.LIP_KEM
		fg = A.LA_DK
	var al := 0.45 if disabled else 1.0
	var off := 3.0 if down and not disabled else 0.0
	var rad := r.size.y / 2
	if not disabled:
		A.box(ci, Rect2(r.position + Vector2(0, off + (1 if down else 4) + 2), r.size), Color(40 / 255.0, 25 / 255.0, 10 / 255.0, 0.12), rad)
		A.box(ci, Rect2(r.position + Vector2(0, off + (1 if down else 4)), r.size), Color(lip, al), rad)
	var rr := Rect2(r.position + Vector2(0, off), r.size)
	A.box(ci, rr, Color(bg, al), rad)
	A.text(ci, lab, rr.get_center().x, rr.get_center().y + fs * 0.02, fs, Color(fg, al), 1, 800)

# ------------------------------------------------------------ hộp thoại (khối xếp dọc như .dlg của web)
# khối: {h, draw(ci, x, y, w)}; nút: {r tương đối}
func dialog(blocks: Array, opts := {}) -> void:
	_dlg = {"blocks": blocks, "opts": opts}
	_dlg_t = 0.0
	dlg.visible = true
	_layout_dlg()

func close_dlg() -> void:
	_dlg = {}
	if dlg != null:
		dlg.visible = false
		dlg.items = []

func _layout_dlg() -> void:
	if _dlg.is_empty():
		return
	var L: Dictionary = game.LAY
	var pw := minf(float(_dlg.opts.get("w", 380)), L.W - 32)
	var iw := pw - 44
	var h := 26.0 + 22
	var bs: Array = _dlg.blocks
	for i in bs.size():
		var b: Dictionary = bs[i]
		if b.has("mk"):
			b.h = b.mk.call(iw)
		h += b.h + (12 if i > 0 else 0)
	_dlg.pw = pw
	_dlg.ph = h
	_dlg.r = Rect2((L.W - pw) / 2, (L.H - h) / 2, pw, h)

func _draw_dlg(ci: Box) -> void:
	if _dlg.is_empty():
		return
	var L: Dictionary = game.LAY
	ci.draw_rect(Rect2(0, 0, L.W, L.H), Color(30 / 255.0, 22 / 255.0, 10 / 255.0, 0.42))
	var r: Rect2 = _dlg.r
	var k := clampf(_dlg_t / 0.35, 0, 1)
	# cubic-bezier(.3,1.5,.5,1) gần đúng
	var e := 1 - pow(1 - k, 3) + sin(k * PI) * 0.12
	var sc := lerpf(0.7, 1.0, e)
	var xf := Transform2D(0, Vector2(sc, sc), 0, r.get_center())
	var lr := Rect2(-r.size / 2, r.size)
	A.box(ci, lr, A.GACH, 22, 0, Color(), [[0, 10, 30, Color(40 / 255.0, 25 / 255.0, 10 / 255.0, 0.35 * k)]], xf)
	A.box(ci, lr.grow(-2.5), A.KEM, 19.5, 0, Color(), [], xf)
	ci.draw_set_transform_matrix(xf)
	khan(ci, Rect2(lr.position.x + 16, lr.position.y + 2.5, lr.size.x - 32, 10), 5, Color("#f6f1e4"), 0.92)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	ci.items = []
	var y := r.position.y + 26
	var x := r.position.x + 22
	var iw: float = _dlg.pw - 44
	var bs: Array = _dlg.blocks
	for i in bs.size():
		var b: Dictionary = bs[i]
		if i > 0:
			y += 12
		b.draw.call(ci, x, y, iw)
		y += b.h

# ---------- khối
func b_ribbon(txt: String) -> Dictionary:
	return {"h": 25.0, "draw": func(ci, x, y, w):
		var t := txt.to_upper()
		var tw := A.tw(t, 15, 800) + 24 + t.length() * 0.9
		var r := Rect2(x + w / 2 - tw / 2, y, tw, 25)
		A.box(ci, r, A.GACH, 12)
		A.text(ci, t, r.get_center().x, r.get_center().y + 1, 15, A.CREAM_TXT, 1, 800)}

func b_h2(txt: String, fs := 32.0) -> Dictionary:
	return {"h": fs + 4, "draw": func(ci, x, y, w):
		A.text(ci, txt, x + w / 2, y + 4 + fs / 2, fs, A.GACH_DK, 1, 800)}

# chữ có <b>..</b>, <br>
static func rich_parse(s: String) -> Array:
	var out := []
	var bold := false
	var i := 0
	var cur := ""
	while i < s.length():
		if s.substr(i, 3) == "<b>":
			if cur != "":
				out.append([cur, bold])
			cur = ""
			bold = true
			i += 3
			continue
		if s.substr(i, 4) == "</b>":
			if cur != "":
				out.append([cur, bold])
			cur = ""
			bold = false
			i += 4
			continue
		if s.substr(i, 4) == "<br>":
			if cur != "":
				out.append([cur, bold])
			cur = ""
			out.append(["\n", bold])
			i += 4
			continue
		cur += s[i]
		i += 1
	if cur != "":
		out.append([cur, bold])
	return out

static func rich_lines(segs: Array, fs: float, w0: int, w1: int, maxw: float) -> Array:
	# từ: [text, bold, cần dấu cách trước]
	var words := []
	var pend := false
	for sg in segs:
		if sg[0] == "\n":
			words.append(["\n", false, false])
			pend = false
			continue
		var t: String = sg[0]
		var parts := t.split(" ")
		var first := true
		for j in parts.size():
			if parts[j] == "":
				if j > 0 or t.begins_with(" "):
					pend = true
				continue
			var sp: bool = (not first) or pend or (t.begins_with(" ") and j == 0)
			words.append([parts[j], sg[1], sp])
			first = false
			pend = false
		if t.ends_with(" "):
			pend = true
	var lines := [[]]
	var lw := 0.0
	var spw := A.tw(" ", fs, w0)
	for wd in words:
		if wd[0] == "\n":
			lines.append([])
			lw = 0.0
			continue
		var ww := A.tw(wd[0], fs, w1 if wd[1] else w0)
		var add: float = ww + (spw if (lines[-1].size() and wd[2]) else 0.0)
		if lines[-1].size() and lw + add > maxw:
			lines.append([])
			lw = 0.0
			add = ww
		lines[-1].append([wd[0], wd[1], wd[2] and lines[-1].size() > 0, ww])
		lw += add
	return lines

static func rich_draw(ci: CanvasItem, lines: Array, x: float, y: float, w: float, fs: float, lh: float, w0: int, w1: int, col: Color, colb: Color, al := 1) -> void:
	var spw := A.tw(" ", fs, w0)
	for i in lines.size():
		var ln: Array = lines[i]
		var tot := 0.0
		for wd in ln:
			tot += wd[3] + (spw if wd[2] else 0.0)
		var cx := x if al == 0 else x + (w - tot) / 2
		for wd in ln:
			if wd[2]:
				cx += spw
			A.text(ci, wd[0], cx, y + lh * i + lh / 2, fs, colb if wd[1] else col, 0, w1 if wd[1] else w0)
			cx += wd[3]

func b_p(txt: String, fs := 17.0, col := A.INK2, al := 1, colb := A.INK) -> Dictionary:
	var segs := rich_parse(txt)
	var lh := fs * 1.3
	var st := {"lines": []}
	return {"mk": func(w):
		st.lines = rich_lines(segs, fs, 600, 800, w)
		return st.lines.size() * lh, "h": 0.0, "draw": func(ci, x, y, w):
		rich_draw(ci, st.lines, x, y, w, fs, lh, 600, 800, col, colb, al)}

func b_tipline(txt: String) -> Dictionary:
	var segs := rich_parse(txt)
	var fs := 14.5
	var lh := fs * 1.35
	var st := {"lines": [], "w": 0.0}
	return {"mk": func(w):
		var mw := minf(300.0, w) - 24
		st.lines = rich_lines(segs, fs, 600, 800, mw)
		var lw := 0.0
		var spw := A.tw(" ", fs, 600)
		for ln in st.lines:
			var tot := 0.0
			for wd in ln:
				tot += wd[3] + (spw if wd[2] else 0.0)
			lw = maxf(lw, tot)
		st.w = minf(minf(300.0, w), lw + 24)
		return st.lines.size() * lh + 12 + 10, "h": 0.0, "draw": func(ci, x, y, w):
		var r := Rect2(x + w / 2 - st.w / 2, y + 10, st.w, st.lines.size() * lh + 12)
		A.box(ci, r, A.KEM2, 12)
		rich_draw(ci, st.lines, r.position.x + 12, r.position.y + 6, r.size.x - 24, fs, lh, 600, 800, A.INK2, A.INK)}

func b_row(btns: Array, sm := false) -> Dictionary:
	# btns [[label, kind, id, Callable, disabled?]]
	var fs := 16.0 if sm else clampf(game.LAY.H * 0.024, 18, 23)
	var st := {"lines": []}
	return {"mk": func(w):
		var rows := [[]]
		var lw := 0.0
		for b in btns:
			var bw: float = btn_rect(b[0], 0, 0, fs, 1.1 if sm else 1.5, 0.3 if sm else 0.42).size.x
			if rows[-1].size() and lw + 10 + bw > w:
				rows.append([])
				lw = 0.0
			lw += bw + (10 if rows[-1].size() else 0)
			rows[-1].append([b, bw])
		st.lines = rows
		var bh: float = btn_rect("A", 0, 0, fs, 1.5, 0.3 if sm else 0.42).size.y
		st.bh = bh
		return rows.size() * (bh + 4) + (rows.size() - 1) * 10, "h": 0.0, "draw": func(ci, x, y, w):
		for j in st.lines.size():
			var row: Array = st.lines[j]
			var tot := -10.0
			for b in row:
				tot += b[1] + 10
			var bx = x + (w - tot) / 2
			for b in row:
				var spec: Array = b[0]
				var r := Rect2(bx, y + j * (st.bh + 14), b[1], st.bh)
				var dis: bool = spec.size() > 4 and spec[4]
				btn(ci, r, spec[0], spec[1], fs, ci.pressed(spec[2]), dis)
				ci.items.append({"r": r, "id": spec[2], "tap": spec[3], "off": dis})
				bx += b[1] + 10}

# hàng mục tiêu (kem2), mỗi ô icon 52 + số 20
func b_goalrow(goals: Array, counts: Array) -> Dictionary:
	return {"h": 20.0 + 52 + 20 + 4, "draw": func(ci, x, y, w):
		var n := goals.size()
		var cw := 40.0
		var tot := n * cw + (n - 1) * 14 + 32
		var r := Rect2(x + w / 2 - tot / 2, y, tot, 20 + 52 + 20 + 4)
		A.box(ci, r, A.KEM2, 16)
		for i in n:
			var cx := r.position.x + 16 + i * (cw + 14) + cw / 2
			_icon(ci, goal_icon(goals[i]), Rect2(cx - 26, r.position.y + 10, 52, 52), goals[i].type == "score")
			A.text(ci, counts[i], cx, r.position.y + 10 + 52 + 10, 20, A.INK, 1, 800)}

static func icon_tex(k: String) -> Texture2D:
	if k.is_valid_int():
		return A.img("f" + k)
	if k == "trung":
		return A.img("egg")
	if k.begins_with("b_"):
		return A.img(k)
	return A.img("i_" + k)

# dòng icon + số: [[icon, text, bold?]] cỡ fs
func b_pay(prefix: String, parts: Array, fs := 15.0) -> Dictionary:
	return {"h": fs * 1.3 + 4, "draw": func(ci, x, y, w):
		var tot := A.tw(prefix, fs, 600) + 3
		for p in parts:
			tot += 20 + 3 + A.tw(p[1], fs, 800) + 3
		var cx = x + w / 2 - tot / 2
		var cy = y + fs * 0.65 + 2
		A.text(ci, prefix, cx, cy, fs, A.INK2, 0, 600)
		cx += A.tw(prefix, fs, 600) + 3
		for p in parts:
			ci.draw_texture_rect(icon_tex(p[0]), Rect2(cx, cy - 10, 20, 20), false)
			cx += 23
			A.text(ci, p[1], cx, cy, fs, A.INK, 0, 800)
			cx += A.tw(p[1], fs, 800) + 3}

func b_haul(label: String, haul: Dictionary) -> Dictionary:
	var ks := []
	for k in haul:
		if int(haul[k]) > 0:
			ks.append(k)
	var st := {"rows": []}
	return {"mk": func(w):
		var rows := [[]]
		var lw := 0.0
		for k in ks:
			var iw := 30 + 1 + A.tw("+" + str(haul[k]), 16, 800)
			if rows[-1].size() and lw + 10 + iw > w - 20:
				rows.append([])
				lw = 0.0
			lw += iw + (10 if rows[-1].size() else 0)
			rows[-1].append([k, iw])
		st.rows = rows
		return 6 + 17 + rows.size() * 34.0 + 6, "h": 0.0, "draw": func(ci, x, y, w):
		var r := Rect2(x, y, w, 6 + 17 + st.rows.size() * 34.0 + 6)
		A.box(ci, r, A.KEM2, 14)
		A.text(ci, label, x + w / 2, y + 6 + 8, 13, A.INK2, 1, 700)
		for j in st.rows.size():
			var row: Array = st.rows[j]
			var tot := -10.0
			for it in row:
				tot += it[1] + 10
			var cx = x + w / 2 - tot / 2
			var cy = y + 6 + 17 + j * 34 + 17
			for it in row:
				ci.draw_texture_rect(icon_tex(str(it[0])), Rect2(cx, cy - 15, 30, 30), false)
				A.text(ci, "+" + str(haul[it[0]]), cx + 31, cy, 16, A.INK, 0, 800)
				cx += it[1] + 10}

func b_stars(n: int) -> Dictionary:
	_stars_on = []
	for k in n:
		_stars_on.append(0.3 + k * 0.35)
	return {"h": 74.0, "draw": func(ci, x, y, w):
		var sz := [58.0, 72.0, 58.0]
		var tot := 58.0 + 72 + 58 + 12
		var cx = x + w / 2 - tot / 2
		for k in 3:
			var s: float = sz[k]
			var c := Vector2(cx + s / 2, y + 74 - s / 2)
			cx += s + 6
			var on = k < _stars_on.size() and _dlg_t >= _stars_on[k]
			if on and not _dlg.get("rang" + str(k), false):
				_dlg["rang" + str(k)] = true
				game.snd.play("star", k)
			var sc := 0.8
			var rot := 0.0
			var al := 0.35
			var mod := Color(0.6, 0.6, 0.6, 0.35)
			if on:
				var q := clampf((_dlg_t - _stars_on[k]) / 0.45, 0, 1)
				var e := 1 - pow(1 - q, 3) + sin(q * PI) * 0.15
				sc = lerpf(2.2, 1.0, e)
				rot = lerpf(-40.0, 0.0, e) * PI / 180
				mod = Color(1, 1, 1, clampf(q * 3, 0, 1))
			var xf := Transform2D(rot, Vector2(sc, sc), 0, c)
			ci.draw_set_transform_matrix(xf)
			ci.draw_texture_rect(A.img("svg_star"), Rect2(-s / 2, -s / 2, s, s), false, mod)
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)}

func b_space(h: float) -> Dictionary:
	return {"h": h, "draw": func(_ci, _x, _y, _w): pass}

func b_custom(h: float, f: Callable) -> Dictionary:
	return {"h": h, "draw": f}

func b_tog(lab: String, key: String, cb: Callable) -> Dictionary:
	return {"h": 46.0, "draw": func(ci, x, y, w):
		var r := Rect2(x, y, w, 46)
		A.box(ci, r, A.KEM2, 14)
		A.text(ci, lab, x + 14, y + 23, 18, A.INK, 0, 700)
		var on: bool = game.save.get(key, true)
		var sr := Rect2(r.end.x - 14 - 58, y + 8, 58, 30)
		A.box(ci, sr, A.LA if on else A.LIP_KEM, 15)
		ci.draw_circle(Vector2(sr.position.x + (31 + 12 if on else 3 + 12), sr.get_center().y), 12, Color.WHITE)
		ci.items.append({"r": r, "id": key, "tap": cb})}

# ---------- các hộp thoại của màn chơi
func goal_text(g: Dictionary) -> String:
	match g.type:
		"fruit": return "Hái " + str(g.need) + " " + str(D.FRUITS[g.k].name).to_lower()
		"mud": return "Dọn sạch bùn"
		"hay": return "Phá hết rơm"
		"egg": return "Lượm " + str(g.need) + " trứng vịt"
	return "Đạt " + _num(g.need) + " điểm"

func pre(i: int) -> void:
	var L: Dictionary = D.LEVELS[i]
	var mp := "".join(L.map)
	var cnt := func(chs: String) -> int:
		var n := 0
		for ch in mp:
			if chs.contains(ch):
				n += 1
		return n
	var goals := []
	for gg in L.goals:
		if gg.has("fruit"):
			goals.append({"type": "fruit", "k": int(gg.fruit), "need": int(gg.n)})
		elif gg.has("mud"):
			goals.append({"type": "mud", "need": cnt.call("mL") + cnt.call("M") * 2})
		elif gg.has("hay"):
			goals.append({"type": "hay", "need": cnt.call("h") + cnt.call("H") * 2})
		elif gg.has("egg"):
			goals.append({"type": "egg", "need": int(gg.egg)})
		else:
			goals.append({"type": "score", "need": int(gg.score)})
	var best := int(game.save.best.get(str(i), 0))
	var stars = game.stars_of(i)
	var fresh: bool = stars == 0 and not game.save.paid.has(str(i))
	var pay: Dictionary = game.farm.level_pay(i, 3, fresh)
	var pay1: Dictionary = game.farm.level_pay(i, 1, fresh)
	var gtxt := []
	for gg in goals:
		gtxt.append(goal_text(gg))
	var counts := []
	for gg in goals:
		counts.append((str(gg.need / 1000.0).trim_suffix(".0") + "k") if gg.type == "score" else str(gg.need))
	var bl := [b_ribbon("Màn %d" % (i + 1)), b_h2(D.chapter_of(i).name)]
	var otxt := "<b>%s</b> đặt hàng:<br>%s<br>trong <b>%d lượt</b>" % [game.farm.merchant(i), " · ".join(gtxt), int(L.moves)]
	var order_p := b_p(otxt, 17, A.INK2, 0)
	var ost := {"h": 50.0, "tw": 0.0, "th": 0.0}
	var order := {"mk": func(w):
		ost.th = order_p.mk.call(w - 92)
		ost.h = maxf(50.0, ost.th)
		ost.tw = 0.0
		var spw := A.tw(" ", 17, 600)
		for ln in rich_lines(rich_parse(otxt), 17, 600, 800, w - 92):
			var tot := 0.0
			for wd in ln:
				tot += wd[3] + (spw if wd[2] else 0.0)
			ost.tw = maxf(ost.tw, tot)
		return ost.h, "h": 0.0, "draw": func(ci, x, y, w):
		var x0: float = x + (w - (92 + ost.tw)) / 2
		ci.draw_texture_rect(A.img("boaticon"), Rect2(x0, y + maxf(0.0, (ost.h - 50) / 2), 84, 50), false)
		order_p.draw.call(ci, x0 + 92, y + maxf(0.0, (ost.h - ost.th) / 2), ost.tw + 1)}
	bl.append(order)
	bl.append(b_goalrow(goals, counts))
	var parts := [["xu", "%d–%d" % [pay1.xu, pay.xu]]]
	if pay.cam:
		parts.append(["cam", str(pay.cam) if pay1.cam == pay.cam else "%d–%d" % [pay1.cam, pay.cam]])
	bl.append(b_pay("Trả công", parts))
	if L.has("tip"):
		bl.append(b_tipline(L.tip))
	if best:
		bl.append(b_p("Kỷ lục: <b>%s</b> · %s" % [_num(best), "★".repeat(stars)]))
	bl.append(b_row([["Để sau", "kem", "close", func():
		game.snd.play("tap")
		close_dlg()], ["Chơi", "la", "go", func():
		game.snd.play("tap")
		close_dlg()
		game.start_level(i)]]))
	dialog(bl)

func _dlg_h(_b) -> float:
	return 50.0

func stars_for() -> int:
	var st: Array = game.B.stars
	var n := 0
	for s in st:
		if game.B.score >= s:
			n += 1
	return maxi(1, n)

func win() -> void:
	var B = game.B
	var sv: Dictionary = game.save
	var i: int = B.lv_idx
	var stars := stars_for()
	var first: bool = game.stars_of(i) == 0
	sv.stars[str(i)] = maxi(game.stars_of(i), stars)
	sv.best[str(i)] = maxi(int(sv.best.get(str(i), 0)), B.score)
	var gift := ""
	if first:
		var k: String = ["cuoc", "trau", "doi"][i % 3]
		sv.boost[k] = int(sv.boost.get(k, 0)) + 1
		gift = "Quà qua màn: +1 " + {"cuoc": "cuốc", "trau": "trâu cày", "doi": "đổi chỗ"}[k]
	var pay: Dictionary = game.farm.level_pay(i, stars, first and not sv.paid.has(str(i)))
	sv.paid[str(i)] = 1
	sv.xu = int(sv.xu) + pay.xu
	game.farm.add_kho({"cam": pay.cam})
	var haul: Dictionary = game.farm.bank()
	game.persist()
	game.snd.play("win")
	farm_rew = null
	if game.embed:
		game.ended.emit(i, stars, first)
	var W: float = game.LAY.W
	var H: float = game.LAY.H
	var S: float = game.LAY.S
	game.gfx.confetti(W, H)
	game.gfx.set_top(true)
	game.later(4.2, func(): game.gfx.set_top(false))
	var cols := ["#f7b820", "#e02f38", "#5fae36", "#f57a1c"]
	for k in 4:
		var c: String = cols[k]
		game.later(k * 0.22, func(): game.gfx.firework(W * (0.2 + 0.6 * randf()), H * (0.15 + 0.25 * randf()), S, c))
	await game.wait(0.7).done
	if not game.in_game or B.lv_idx != i:
		return
	var bl := [b_ribbon("Màn %d" % (i + 1)), b_h2(["", "Được rồi!", "Giỏi quá!", "Trúng mùa!"][stars]), b_stars(stars)]
	bl.append({"h": 34.0, "draw": func(ci, x, y, w):
		var a := "Điểm: "
		var b := _num(B.score)
		var tw := A.tw(a, 17, 600) + A.tw(b, 26, 800)
		A.text(ci, a, x + w / 2 - tw / 2, y + 17, 17, A.INK2, 0, 600)
		A.text(ci, b, x + w / 2 - tw / 2 + A.tw(a, 17, 600), y + 17, 26, A.INK, 0, 800)})
	var parts := [["xu", "+%d" % pay.xu]]
	if pay.cam:
		parts.append(["cam", "+%d" % pay.cam])
	bl.append(b_pay(game.farm.merchant(i) + " trả", parts))
	if game.farm.haul_any(haul):
		bl.append(b_haul("Chở về kho", haul))
	if gift != "":
		bl.append(b_p(gift))
	if game.embed:
		bl.append({"mk": func(_w): return 22.0 if farm_rew != null else 0.0, "h": 0.0, "draw": func(ci, x, y, w):
			if farm_rew == null:
				return
			if farm_rew.xu > 0:
				var a := "+%d xu" % farm_rew.xu
				var b := " gửi về vườn"
				var tw := A.tw(a, 17, 800) + A.tw(b, 17, 700)
				A.text(ci, a, x + w / 2 - tw / 2, y + 11, 17, A.LA, 0, 800)
				A.text(ci, b, x + w / 2 - tw / 2 + A.tw(a, 17, 800), y + 11, 17, A.LA_DK, 0, 700)
			else:
				A.text(ci, "Hôm nay hết lượt thưởng xu về vườn", x + w / 2, y + 11, 15, A.LA_DK, 1, 700)})
	var row := [["Bản đồ", "kem", "map", func():
		game.snd.play("tap")
		close_dlg()
		game.mapv.show_map()]]
	if i + 1 < D.LEVELS.size():
		row.append(["Màn kế", "la", "next", func():
			game.snd.play("tap")
			close_dlg()
			game.mapv.show_map(false)
			pre(i + 1)])
	bl.append(b_row(row))
	dialog(bl)

func lose() -> void:
	var B = game.B
	game.snd.play("lose")
	var left := []
	var counts := []
	for g in B.goals:
		if g.got < g.need:
			left.append(g)
			counts.append((str(ceil((g.need - g.got) / 100.0) / 10.0).trim_suffix(".0") + "k") if g.type == "score" else str(g.need - g.got))
	var haul: Dictionary = game.farm.bank()
	var bl := [b_ribbon("Màn %d" % (B.lv_idx + 1)), b_h2("Hết lượt rồi!"), b_p("Còn thiếu chút xíu:"), b_goalrow(left, counts)]
	if game.farm.haul_any(haul):
		bl.append(b_haul("Trái hái được vẫn chở về kho", haul))
	var row := []
	if not B.extra_used:
		row.append(["+5 lượt", "", "more", func():
			game.snd.play("coin")
			B.extra_used = true
			B.moves += 5
			B.busy = false
			close_dlg()])
	row.append(["Chơi lại", "la", "retry", func():
		game.snd.play("tap")
		close_dlg()
		game.start_level(B.lv_idx)])
	bl.append(b_row(row))
	bl.append(b_row([["Về bản đồ", "kem", "map", func():
		game.snd.play("tap")
		close_dlg()
		game.mapv.show_map()]], true))
	dialog(bl)

func pause() -> void:
	var B = game.B
	if B.over:
		return
	var bl := [b_ribbon("Nghỉ xíu"), b_h2("Màn %d" % (B.lv_idx + 1))]
	bl.append(b_tog("Nhạc đờn", "music", func(): game.snd.set_music(not game.save.music)))
	bl.append(b_tog("Tiếng động", "sfx", func(): game.snd.set_sfx(not game.save.sfx)))
	bl.append(b_p("Ráp 4: khăn rằn, trâu cày một hàng · Ráp L/T: gói lá, heo nhảy ụp · Ráp vuông 2x2: vịt bay · Ráp 5: gà trống gáy · Đổi hai trái đặc biệt với nhau ra combo", 15))
	bl.append(b_row([["Bản đồ", "kem", "map", func():
		game.snd.play("tap")
		close_dlg()
		game.mapv.show_map()], ["Chơi lại", "kem", "retry", func():
		game.snd.play("tap")
		close_dlg()
		game.start_level(B.lv_idx)], ["Chơi tiếp", "la", "go", func():
		game.snd.play("tap")
		close_dlg()]]))
	dialog(bl)
