extends Control
# XẾP TRÁI MIỆT VƯỜN: viết lại bằng Godot từ bản web (xep-trai/src: 00_core, 03_board, 04_scene, 07_render, 09_main).
# Gốc này phóng to K lần, mọi con số bên trong là css px của web. Lớp vẽ từ dưới lên: cảnh sông, thú trên bờ,
# nền sân gạch tàu, bùn + luống cày, quầng sáng / trái / ánh khăn rằn (cắt theo ô bàn), rơm + miếng trái,
# hạt GPU (có sóng bẻ cong bàn), thú làm việc + chữ điểm, HUD, bản đồ, hộp thoại, nông trại.

signal ended(level: int, stars: int, first: bool)
signal closed

const D := preload("res://logic/xt/xt_data.gd")
const A := preload("res://logic/xt/xt_art.gd")
const BOARD := preload("res://logic/xt/xt_board.gd")
const FXS := preload("res://logic/xt/xt_fx.gd")
const GFXS := preload("res://logic/xt/xt_gfx.gd")
const SCN := preload("res://logic/xt/xt_scene.gd")
const UIS := preload("res://logic/xt/xt_ui.gd")
const MAPS := preload("res://logic/xt/xt_map.gd")
const FARMS := preload("res://logic/xt/xt_farm.gd")
const SNDS := preload("res://logic/xt/xt_snd.gd")
const SAVE_PATH := "user://xeptrai.json"
const BOARD_PAD := 7.0

const MASK_SHADER := """
shader_type canvas_item;
render_mode MODE;
uniform sampler2D mask : filter_nearest;
uniform vec2 org; uniform float S; uniform vec2 gsz; uniform vec2 vp; uniform float K;
void fragment(){
  vec2 P=SCREEN_UV*vp/K; vec2 c=(P-org)/S;
  if(c.x<0.||c.y<0.||c.x>=gsz.x||c.y>=gsz.y||texture(mask,(floor(c)+.5)/gsz).r<.5) discard;
}
"""

class Waiter extends RefCounted:
	signal done
	var fin := false

class Lay extends Control:
	var fn: Callable
	func _init(f: Callable = Callable()) -> void:
		fn = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)

var K := 1.0
var clock := 0.0
var _tw: Array = []
var sched: Array = []
var LAY := {"W": 412.0, "H": 915.0, "S": 48.0, "bx": 0.0, "by": 0.0, "bw": 0.0, "bh": 0.0, "portrait": true, "hudH": 0.0, "trayH": 0.0, "pathY": 0.0, "col": 0.0}
var save := {}
var B   # luật bàn
var fx
var gfx
var scn
var ui
var mapv
var farm
var snd
var in_game := false
var embed := true
var sel = null
var boost := ""
var hover = null
var pending = null
var _down = null
var _vs := Vector2.ZERO

var l_help: Lay
var l_base: Lay
var l_mud: Lay
var l_glow: Lay
var l_tiles: Lay
var l_glint: Lay
var l_hay: Lay
var l_topadd: Lay
var l_top: Lay
var inp: Control
var _mask_tex: ImageTexture = null
var _shadow_tex: ImageTexture = null
var _shadow_rect := Rect2()
var _mats: Array = []

func setup(k: float) -> void:
	K = maxf(1.0, k)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	A.K = K
	A.load_anim()
	_load()
	B = BOARD.new(self)
	B.W = 9
	B.H = 9
	fx = FXS.new(self)
	snd = SNDS.new(self)
	add_child(snd)
	scn = SCN.new(self)
	add_child(scn)
	l_help = _lay(_draw_help)
	l_base = _lay(_draw_base)
	l_mud = _lay(_draw_mud)
	l_glow = _lay(_draw_glow, "blend_add")
	l_tiles = _lay(_draw_tiles, "blend_mix")
	l_glint = _lay(_draw_glint, "blend_add")
	l_hay = _lay(_draw_hay)
	gfx = GFXS.new(self)
	add_child(gfx)
	l_topadd = _lay(_draw_topadd)
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	l_topadd.material = am
	l_top = _lay(_draw_top)
	inp = Control.new()
	inp.mouse_filter = Control.MOUSE_FILTER_STOP
	inp.gui_input.connect(_board_input)
	add_child(inp)
	ui = UIS.new(self)
	add_child(ui)
	mapv = MAPS.new(self)
	add_child(mapv)
	farm = FARMS.new(self)
	add_child(farm)
	ui.build_overlays()
	await get_tree().process_frame
	resize()
	ui.show_title()

func _lay(f: Callable, mask_mode := "") -> Lay:
	var l := Lay.new(f)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if mask_mode != "":
		var s := Shader.new()
		s.code = MASK_SHADER.replace("MODE", mask_mode)
		var m := ShaderMaterial.new()
		m.shader = s
		l.material = m
		_mats.append(m)
	add_child(l)
	return l

# ============================================================ đồng hồ, chờ, tween
static func ease_out(t: float) -> float:
	return 1 - (1 - t) * (1 - t)
static func ease_out3(t: float) -> float:
	return 1 - pow(1 - t, 3)
static func ease_in(t: float) -> float:
	return t * t
static func ease_in_out(t: float) -> float:
	return 2 * t * t if t < 0.5 else 1 - pow(-2 * t + 2, 2) / 2
static func ease_back(t: float) -> float:
	var c := 1.70158
	return 1 + (c + 1) * pow(t - 1, 3) + c * pow(t - 1, 2)
static func _ease(name: String, t: float) -> float:
	match name:
		"inout": return ease_in_out(t)
		"in": return ease_in(t)
		"out3": return ease_out3(t)
		"back": return ease_back(t)
		"lin": return t
	return ease_out(t)

func wait(sec: float) -> Waiter:
	var w := Waiter.new()
	_tw.append({"t": -sec, "dur": 0.0, "obj": null, "w": w})
	return w

func tween(obj, props: Dictionary, dur: float, ease := "out", delay := 0.0) -> Waiter:
	var w := Waiter.new()
	_tw.append({"obj": obj, "props": props, "from": null, "dur": maxf(0.001, dur), "ease": ease, "t": -delay, "w": w})
	return w

func all(ws: Array) -> void:
	for w in ws:
		if not w.fin:
			await w.done

func _step_tweens(dt: float) -> void:
	var i := _tw.size() - 1
	var fire := []
	while i >= 0:
		var w: Dictionary = _tw[i]
		w.t += dt
		if w.t < 0:
			i -= 1
			continue
		if w.obj == null:
			_tw.remove_at(i)
			fire.append(w.w)
			i -= 1
			continue
		if w.from == null:
			w.from = {}
			for k in w.props:
				w.from[k] = w.obj[k]
		var k2 := clampf(w.t / w.dur, 0, 1)
		var e := _ease(w.ease, k2)
		for p in w.props:
			w.obj[p] = w.from[p] + (w.props[p] - w.from[p]) * e
		if k2 >= 1:
			_tw.remove_at(i)
			fire.append(w.w)
		i -= 1
	for wt in fire:
		wt.fin = true
		wt.done.emit()

func later(sec: float, fn: Callable) -> void:
	sched.append({"t": clock + sec, "fn": fn})

func _run_sched() -> void:
	var i := 0
	while i < sched.size():
		var s: Dictionary = sched[i]
		if s.t <= clock:
			sched.remove_at(i)
			s.fn.call()
		else:
			i += 1

# ============================================================ lưu
func _load() -> void:
	save = {"stars": {}, "best": {}, "boost": {"cuoc": 3, "trau": 2, "doi": 3}, "music": true, "sfx": true, "seen": false, "xu": 0, "kho": {}, "pets": {}, "orders": [], "garden": {}, "paid": {}}
	if FileAccess.file_exists(SAVE_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if d is Dictionary:
			var bo: Dictionary = save.boost.duplicate()
			bo.merge(d.get("boost", {}), true)
			save.merge(d, true)
			save.boost = bo
			for k in ["kho", "pets", "garden", "paid", "stars", "best"]:
				if not (save.get(k) is Dictionary):
					save[k] = {}
			if not (save.get("orders") is Array):
				save.orders = []
	# số trong JSON đọc ra float: đổi lại số nguyên
	for k in ["stars", "best", "paid", "kho", "garden"]:
		for kk in save[k].keys():
			save[k][kk] = int(save[k][kk])
	for kk in save.boost.keys():
		save.boost[kk] = int(save.boost[kk])
	save.xu = int(save.xu)

func persist() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(save))
		f.close()

func stars_of(i: int) -> int:
	return int(save.stars.get(str(i), 0))

func cur_level() -> int:
	var i := 0
	while i < D.LEVELS.size() - 1 and stars_of(i) > 0:
		i += 1
	return i

# ============================================================ khổ màn
func sx(x: float) -> float:
	return LAY.bx + (x + 0.5) * LAY.S
func sy(y: float) -> float:
	return LAY.by + (y + 0.5) * LAY.S

func layout() -> void:
	var W: float = LAY.W
	var H: float = LAY.H
	var port := H > W * 1.02
	LAY.portrait = port
	var gw: int = B.W if B.W else 9
	var gh: int = B.H if B.H else 9
	var ex := 0.0
	for r in B.cell:
		for c in r:
			if c.exit:
				ex = 16.0
	if port:
		LAY.hudH = clampf(H * 0.105, 84, 104)
		LAY.trayH = clampf(H * 0.085, 66, 80)
		var zoo := clampf(H * 0.11, 80, 120)
		var top: float = LAY.hudH + 34
		LAY.S = floor(minf(minf((W - 14) / gw, (H - top - LAY.trayH - zoo - ex - 14) / gh), 88))
		LAY.bw = LAY.S * gw
		LAY.bh = LAY.S * gh
		LAY.bx = round((W - LAY.bw) / 2)
		var free: float = H - top - LAY.trayH - zoo - ex - 14 - LAY.bh
		LAY.by = round(top + maxf(0.0, free * 0.3))
		var bb: float = LAY.by + LAY.bh + ex
		var tray_top: float = H - LAY.trayH - 10
		scn.bank = bb + 4
		LAY.pathY = bb + (tray_top - bb) * 0.74
		scn.horizon = maxf(LAY.hudH + 40, LAY.by + LAY.bh * 0.18)
	else:
		LAY.col = clampf(W * 0.2, 200, 280)
		LAY.S = floor(minf(minf((W - LAY.col * 2 - 36) / gw, (H - 24 - ex) / gh), 84))
		if LAY.S < 40:
			LAY.S = floor(minf((W - LAY.col - 36) / gw, (H - 24 - ex) / gh))
		LAY.bw = LAY.S * gw
		LAY.bh = LAY.S * gh
		LAY.bx = round(maxf(LAY.col + 24, (W - LAY.bw) / 2))
		LAY.by = round((H - LAY.bh - ex) / 2)
		scn.horizon = H * 0.44
		scn.bank = H * 0.63
		LAY.pathY = H * 0.86

func resize() -> void:
	var vs := get_viewport_rect().size
	_vs = vs
	scale = Vector2(K, K)
	size = vs / K
	LAY.W = vs.x / K
	LAY.H = vs.y / K
	for l in [l_help, l_base, l_mud, l_glow, l_tiles, l_glint, l_hay, l_topadd, l_top, inp]:
		l.position = Vector2.ZERO
		l.size = Vector2(LAY.W, LAY.H)
	layout()
	scn.resize()
	_bake_board()
	ui.relayout()
	mapv.relayout()
	farm.relayout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree() and _vs != Vector2.ZERO and get_viewport_rect().size != _vs:
		call_deferred("resize")

# ============================================================ vô màn
func start_level(i: int) -> void:
	B.load_level(i)
	fx.reset()
	gfx.clear_all()
	in_game = true
	sel = null
	boost = ""
	hover = null
	pending = null
	ui.tip("")
	mapv.hide_map()
	ui.hide_title()
	resize()
	ui.build_hud()
	for r in B.T:
		for t in r:
			if t != null:
				t.py = t.y - B.H - 1 - randf() * 0.6
				t.vy = 0.0
	B.busy = true
	var my_gen: int = B.gen
	await B.wait_settled()
	if my_gen == B.gen:
		B.busy = false

func leave_level() -> void:
	in_game = false
	B.gen += 1
	sched.clear()
	fx.reset()
	gfx.clear_all()
	ui.hide_hud()

# ============================================================ nền sân (vẽ một lần mỗi màn / khổ)
func _cells() -> Array:
	var out := []
	for y in B.H:
		for x in B.W:
			if B.cell.size() > y and B.cell[y][x].play:
				out.append(Vector2i(x, y))
	return out

func _bake_board() -> void:
	if B.cell.is_empty():
		return
	var cells := _cells()
	# mặt nạ ô bàn cho lớp trái
	var mi := Image.create(B.W, B.H, false, Image.FORMAT_L8)
	for c in cells:
		mi.set_pixel(c.x, c.y, Color.WHITE)
	_mask_tex = ImageTexture.create_from_image(mi)
	for m in _mats:
		m.set_shader_parameter("mask", _mask_tex)
		m.set_shader_parameter("gsz", Vector2(B.W, B.H))
		m.set_shader_parameter("S", LAY.S)
		m.set_shader_parameter("K", K)
	# bóng đổ mềm của cả sân (shadowBlur 18, offsetY 8)
	var S: float = LAY.S
	var m0 := BOARD_PAD + 14 + 24.0
	var q := 4.0   # 1 điểm ảnh = 4 css px
	var w := int(ceil((LAY.bw + m0 * 2) / q))
	var h := int(ceil((LAY.bh + m0 * 2) / q))
	var a := PackedFloat32Array()
	a.resize(w * h)
	var pad := BOARD_PAD + 1.5
	for c in cells:
		var x0 := int(floor((c.x * S - pad + m0) / q))
		var x1 := int(ceil((c.x * S + S + pad + m0) / q))
		var y0 := int(floor((c.y * S - pad + m0) / q))
		var y1 := int(ceil((c.y * S + S + pad + m0) / q))
		for yy in range(maxi(0, y0), mini(h, y1)):
			for xx in range(maxi(0, x0), mini(w, x1)):
				a[yy * w + xx] = 1.0
	for _pass in 3:
		a = _box_blur(a, w, h, 2)
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for yy in h:
		for xx in w:
			im.set_pixel(xx, yy, Color(30 / 255.0, 20 / 255.0, 8 / 255.0, a[yy * w + xx] * 0.5))
	_shadow_tex = ImageTexture.create_from_image(im)
	_shadow_rect = Rect2(LAY.bx - m0, LAY.by - m0 + 8, w * q, h * q)
	l_base.queue_redraw()

static func _box_blur(a: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(w * h)
	var n := float(2 * r + 1)
	for y in h:
		for x in w:
			var s := 0.0
			for k in range(-r, r + 1):
				s += a[y * w + clampi(x + k, 0, w - 1)]
			b[y * w + x] = s / n
	var c := PackedFloat32Array()
	c.resize(w * h)
	for y in h:
		for x in w:
			var s2 := 0.0
			for k in range(-r, r + 1):
				s2 += b[clampi(y + k, 0, h - 1) * w + x]
			c[y * w + x] = s2 / n
	return c

func _rr(pad: float, rad: float) -> Array:
	var out := []
	var S: float = LAY.S
	for c in _cells():
		out.append(A.rrect_pts(Rect2(LAY.bx + c.x * S - pad, LAY.by + c.y * S - pad, S + pad * 2, S + pad * 2), rad, 5))
	return out

func _draw_base(ci: CanvasItem) -> void:
	if not in_game or B.cell.is_empty():
		return
	var S: float = LAY.S
	if _shadow_tex != null:
		ci.draw_texture_rect(_shadow_tex, _shadow_rect, false)
	var y0: float = LAY.by - BOARD_PAD
	var y1: float = LAY.by + LAY.bh + BOARD_PAD
	var cst := [[0.0, Color("#c9673a")], [1.0, Color("#9e4423")]]
	for p in _rr(BOARD_PAD, BOARD_PAD + 6):
		A.grad_poly(ci, p, Vector2(0, y0), Vector2(0, y1), cst)
	for p in _rr(BOARD_PAD - 1.5, BOARD_PAD + 5):
		var cl: PackedVector2Array = p.duplicate()
		cl.append(p[0])
		ci.draw_polyline(cl, Color(1, 220 / 255.0, 180 / 255.0, 0.45), 2.0, true)
	# viền lại phần ngoài cho gọn (nét sáng chỉ nằm trong mép gạch)
	for p in _rr(2.5, 6):
		ci.draw_colored_polygon(p, Color("#fff3da"))
	for p in _rr(0.5, 4):
		ci.draw_colored_polygon(p, Color("#d9b892"))
	var gap := maxf(1.5, S * 0.035)
	var rad := maxf(2.0, S * 0.09)
	for c in _cells():
		var odd = (c.x + c.y) & 1
		var X: float = LAY.bx + c.x * S + gap / 2
		var Y: float = LAY.by + c.y * S + gap / 2
		var w := S - gap
		var pts := A.rrect_pts(Rect2(X, Y, w, w), rad, 4)
		A.grad_poly(ci, pts, Vector2(X, Y), Vector2(X + w, Y + w), [[0.0, Color("#f2dcbd") if odd else Color("#f8e8cf")], [1.0, Color("#e7cba6") if odd else Color("#efdcbf")]])
		var hl := Color(1, 252 / 255.0, 240 / 255.0, 0.7)
		ci.draw_line(Vector2(X + rad, Y + 0.8), Vector2(X + w - rad, Y + 0.8), hl, 1.2, true)
		ci.draw_line(Vector2(X + 0.8, Y + rad), Vector2(X + 0.8, Y + w - rad), hl, 1.2, true)
		var sh := Color(150 / 255.0, 100 / 255.0, 60 / 255.0, 0.22)
		ci.draw_line(Vector2(X + rad, Y + w - 0.8), Vector2(X + w - rad, Y + w - 0.8), sh, 1.2, true)
		ci.draw_line(Vector2(X + w - 0.8, Y + rad), Vector2(X + w - 0.8, Y + w - rad), sh, 1.2, true)
	for c in _cells():
		if B.cell[c.y][c.x].exit:
			var X2: float = LAY.bx + c.x * S + S / 2
			var Y2: float = LAY.by + (c.y + 1) * S + BOARD_PAD + 2
			var tri := PackedVector2Array([Vector2(X2 - S * 0.22, Y2), Vector2(X2 + S * 0.22, Y2), Vector2(X2, Y2 + S * 0.2)])
			ci.draw_colored_polygon(tri, Color("#3f7d3a"))
			var cl2 := tri.duplicate()
			cl2.append(tri[0])
			ci.draw_polyline(cl2, Color("#fff1d2"), 2.0, true)

# ============================================================ lớp vẽ mỗi khung
func _draw_help(ci: CanvasItem) -> void:
	scn.draw_helpers(ci)
	ui.draw_title_fruit(ci)

func _draw_mud(ci: CanvasItem) -> void:
	if not in_game:
		return
	var S: float = LAY.S
	for y in B.H:
		for x in B.W:
			var c: Dictionary = B.cell[y][x]
			if c.play and c.mud:
				ci.draw_texture_rect(A.img("mud%d%d" % [mini(2, c.mud), c.v]), Rect2(LAY.bx + x * S - S * 0.25, LAY.by + y * S - S * 0.25, S * 1.5, S * 1.5), false)
	if boost != "" and hover != null:
		var hc := Color(1, 1, 1, 0.35)
		if boost == "trau":
			ci.draw_rect(Rect2(LAY.bx, LAY.by + hover.y * S, LAY.bw, S), hc)
		else:
			ci.draw_rect(Rect2(LAY.bx + hover.x * S, LAY.by + hover.y * S, S, S), hc)
	fx.draw_under(ci)

func _tile_tex(t: Dictionary) -> Texture2D:
	if t.k == BOARD.EGG:
		return A.img("egg")
	if t.sp == "rooster":
		return A.img("rooster")
	if t.sp != "":
		return A.img("s%d%s" % [t.k, t.sp])
	return A.img("f%d" % t.k)

func _tile_xf(t: Dictionary, X: float, Y: float, S: float, now: float, sc_over := -1.0) -> Transform2D:
	var sc: float = t.sc if sc_over < 0 else sc_over
	var sxv := sc
	var syv := sc
	var rot := 0.0
	var oy := 0.0
	if t.sq > 0:
		sxv *= 1 + t.sq * 0.13
		syv *= 1 - t.sq * 0.13
		oy = S * 0.065 * t.sq
	if t.wob > 0:
		rot = sin(t.wob * 30) * 0.18 * t.wob
	if B.hint != null and (B.hint[0] == t or B.hint[1] == t):
		var w := sin(now * 9)
		rot += w * 0.1
		sxv *= 1 + absf(w) * 0.06
		syv = sxv
	if sel != null and sel == t:
		var w2 := 1 + sin(now * 8) * 0.05
		sxv *= w2 * 1.08
		syv *= w2 * 1.08
	if t.born > 0:
		var b := ease_back(1 - t.born)
		sxv *= b
		syv *= b
	var xf := Transform2D(rot, Vector2(sxv, syv), 0, Vector2(X, Y + oy))
	if t.sp == "duck":
		xf = xf * Transform2D(0, Vector2(0, sin(now * 3 + t.id) * S * 0.02))
	return xf

func _each_tile(fn: Callable) -> void:
	var S: float = LAY.S
	for y in B.H:
		for x in B.W:
			var t = B.T[y][x]
			if t != null:
				fn.call(t, LAY.bx + (t.px + 0.5) * S, LAY.by + (t.py + 0.5) * S, 1.0, -1.0)
	for t in B.dying:
		var k: float = t.dieT / 0.22
		var s := 1 + ease_out(k / 0.32) * 0.2 if k < 0.32 else 1.2 * (1 - ease_in((k - 0.32) / 0.68) * 0.9)
		fn.call(t, LAY.bx + (t.px + 0.5) * S, LAY.by + (t.py + 0.5) * S, clampf(1 - (k - 0.3) / 0.22, 0, 1), s)

func _draw_glow(ci: CanvasItem) -> void:
	if not in_game:
		return
	var now := clock
	var S: float = LAY.S
	_each_tile(func(t, X, Y, al, _s):
		if t.sp == "":
			return
		var pulse := 0.5 + 0.5 * sin(now * 4 + t.id)
		var col: Color = {"bomb": Color8(255, 150, 160), "rooster": Color8(255, 210, 90), "duck": Color8(200, 235, 255)}.get(t.sp, Color8(255, 240, 180))
		var a0: float = (0.35 + pulse * 0.25 + t.glow * 0.5) * al
		var c0 := Color(col.r, col.g, col.b, minf(1.0, a0))
		A.radial(ci, Vector2(X, Y), S * 0.62, [[0.0, c0], [1.0, Color(col.r, col.g, col.b, 0)]], 20))

func _draw_tiles(ci: CanvasItem) -> void:
	if not in_game:
		return
	var now := clock
	var S: float = LAY.S
	_each_tile(func(t, X, Y, al, s):
		if t.sp == "rooster":
			var rx := Transform2D(now * 0.8, Vector2(X, Y))
			for i in 8:
				var r2 := rx * Transform2D(TAU / 8 * (i + 1), Vector2.ZERO)
				ci.draw_colored_polygon(PackedVector2Array([r2 * Vector2(-S * 0.07, -S * 0.3), r2 * Vector2(0, -S * 0.62), r2 * Vector2(S * 0.07, -S * 0.3)]), Color(1, 229 / 255.0, 138 / 255.0, 0.55 * al))
		ci.draw_set_transform_matrix(_tile_xf(t, X, Y, S, now, s))
		ci.draw_texture_rect(_tile_tex(t), Rect2(-S * 0.75, -S * 0.75, S * 1.5, S * 1.5), false, Color(1, 1, 1, al))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		if t.lock:
			ci.draw_texture_rect(A.img("vine"), Rect2(X - S * 0.75, Y - S * 0.75, S * 1.5, S * 1.5), false, Color(1, 1, 1, al)))

func _draw_glint(ci: CanvasItem) -> void:
	if not in_game:
		return
	var now := clock
	var S: float = LAY.S
	var st := A.img("glint")
	_each_tile(func(t, X, Y, al, _s):
		if t.sp != "h" and t.sp != "v":
			return
		var q := fmod(now * 0.7 + t.id * 0.37, 1.6) / 1.6
		if q >= 1:
			return
		var gx: float = X + (q - 0.5) * S * 0.9 if t.sp == "h" else X
		var gy: float = Y + (q - 0.5) * S * 0.9 if t.sp == "v" else Y
		ci.draw_texture_rect(st, Rect2(gx - S * 0.25, gy - S * 0.25, S * 0.5, S * 0.5), false, Color(1, 1, 1, sin(q * PI) * 0.8 * al)))

func _draw_hay(ci: CanvasItem) -> void:
	if not in_game:
		return
	var S: float = LAY.S
	for y in B.H:
		for x in B.W:
			var c: Dictionary = B.cell[y][x]
			if c.play and c.block != null:
				ci.draw_texture_rect(A.img("hay%d" % mini(2, c.block.hp)), Rect2(LAY.bx + x * S - S * 0.25, LAY.by + y * S - S * 0.25, S * 1.5, S * 1.5), false)
	fx.draw_parts(ci)

func _draw_topadd(ci: CanvasItem) -> void:
	if in_game:
		fx.draw_top_add(ci)

func _draw_top(ci: CanvasItem) -> void:
	if in_game:
		fx.draw_top(ci)

# ============================================================ khung hình
func _process(dt: float) -> void:
	dt = minf(0.05, dt)
	clock += dt
	_step_tweens(dt)
	if in_game:
		_run_sched()
		_update_tiles(dt)
		fx.update(dt)
		if not B.busy and not B.over and not ui.dlg_open():
			B.idle += dt
			if B.idle > 5 and B.hint == null:
				B.hint = B.find_move()
		else:
			B.idle = 0.0
	scn.update(dt)
	gfx.step(dt)
	# rung: sân, trái, rơm, miếng trái cùng rung
	var shv: float = fx.shake_v * LAY.S * 0.12
	var off := Vector2(randf_range(-shv, shv), randf_range(-shv, shv)) if shv > 0 else Vector2.ZERO
	for l in [l_base, l_mud, l_glow, l_tiles, l_glint, l_hay]:
		l.position = off
	var vp := get_viewport_rect().size
	for m in _mats:
		m.set_shader_parameter("org", Vector2(LAY.bx, LAY.by) + off)
		m.set_shader_parameter("vp", vp)
	gfx.render()
	for l in [l_help, l_mud, l_glow, l_tiles, l_glint, l_hay, l_top, l_topadd]:
		l.queue_redraw()
	if not in_game:
		mapv.tick(dt)
		farm.tick(dt)
	ui.update(dt)

func _update_tiles(dt: float) -> void:
	var landed := 0
	for r in B.T:
		for t in r:
			if t == null:
				continue
			if t.sq > 0:
				t.sq = maxf(0.0, t.sq - dt * 5)
			if t.wob > 0:
				t.wob = maxf(0.0, t.wob - dt * 2.5)
			if t.born > 0:
				t.born = maxf(0.0, t.born - dt * 3.2)
			if t.glow > 0:
				t.glow = maxf(0.0, t.glow - dt * 1.5)
			if t.tw:
				continue
			var ty := float(t.y)
			var tx := float(t.x)
			if t.py < ty:
				t.vy = minf(t.vy + dt * 55, 16.0)
				var dy: float = ty - t.py
				var step: float = t.vy * dt
				var total := maxf(absf(dy), 0.0001)
				if step >= dy:
					t.py = ty
					t.px = tx
					if t.vy > 3:
						t.sq = minf(1.0, t.vy / 12)
						landed += 1
					t.vy = 0.0
				else:
					var f := step / total
					t.py += step
					t.px += (tx - t.px) * minf(1.0, f * 1.0001)
				if t.py > ty:
					t.py = ty
			elif t.px != tx:
				var d: float = tx - t.px
				var st := dt * 9
				t.px = tx if absf(d) <= st else t.px + signf(d) * st
				if t.py > ty:
					t.py = ty
			elif t.py > ty:
				t.py = ty
	if landed:
		snd.play("land")
	for i in range(B.dying.size() - 1, -1, -1):
		var t: Dictionary = B.dying[i]
		t.dieT += dt
		if t.dieT >= 0.22:
			B.dying.remove_at(i)

# ============================================================ chạm bàn: kéo trái qua ô kế, hay chạm hai trái liền nhau
func _cell_at(p: Vector2):
	var x := int(floor((p.x - LAY.bx) / LAY.S))
	var y := int(floor((p.y - LAY.by) / LAY.S))
	var c = B.C(x, y)
	return Vector2i(x, y) if c != null and c.play else null

func _board_input(e: InputEvent) -> void:
	if not in_game:
		return
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
		if e.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = e.position
		kind = "down" if e.pressed else "up"
	elif e is InputEventMouseMotion:
		pos = e.position
		kind = "move"
	else:
		return
	inp.accept_event()
	if kind == "down":
		if B.over:
			return
		snd.init()
		var c = _cell_at(pos)
		if c == null:
			sel = null
			return
		if boost != "":
			_on_boost_tap(c)
			return
		if B.busy:
			return
		_down = {"c": c, "p": pos, "moved": false}
	elif kind == "move":
		if boost != "":
			hover = _cell_at(pos)
			return
		var d = _down
		if d == null or d.moved or B.busy:
			return
		var dv: Vector2 = pos - d.p
		if dv.length() > LAY.S * 0.32:
			d.moved = true
			var x: int = d.c.x
			var y: int = d.c.y
			var tx := x + (int(signf(dv.x)) if absf(dv.x) > absf(dv.y) else 0)
			var ty := y + (0 if absf(dv.x) > absf(dv.y) else int(signf(dv.y)))
			sel = null
			var cc = B.C(tx, ty)
			if cc != null and cc.play:
				B.try_swap(x, y, tx, ty)
	else:
		var d2 = _down
		_down = null
		if d2 == null or d2.moved or B.busy:
			return
		var x2: int = d2.c.x
		var y2: int = d2.c.y
		var t = B.TL(x2, y2)
		if sel != null and sel != t:
			var s = sel
			if absi(s.x - x2) + absi(s.y - y2) == 1:
				sel = null
				B.try_swap(s.x, s.y, x2, y2)
				return
		sel = null if sel == t else t
		if sel != null:
			snd.play("tap")

func _on_boost_tap(c: Vector2i) -> void:
	var k := boost
	if k == "doi":
		if pending == null:
			pending = c
			sel = B.TL(c.x, c.y)
			return
		var p: Vector2i = pending
		pending = null
		sel = null
		if absi(p.x - c.x) + absi(p.y - c.y) != 1:
			pending = c
			sel = B.TL(c.x, c.y)
			return
		boost = ""
		ui.tip("")
		save.boost.doi = int(save.boost.doi) - 1
		persist()
		ui.dirty = true
		await B.use_booster("doi", p.x, p.y, c.x, c.y)
		return
	boost = ""
	hover = null
	ui.tip("")
	save.boost[k] = int(save.boost[k]) - 1
	persist()
	ui.dirty = true
	await B.use_booster(k, c.x, c.y)

func toggle_boost(k: String) -> void:
	if B.busy or B.over:
		return
	if boost == k:
		boost = ""
		ui.tip("")
	elif int(save.boost.get(k, 0)) > 0:
		boost = k
		sel = null
		snd.play("tap")
		ui.tip({"cuoc": "Chạm một ô để cuốc bể", "trau": "Chạm một hàng cho trâu cày", "doi": "Chạm hai ô kế nhau để đổi"}[k])
	else:
		ui.tip("Hết rồi, qua màn mới để kiếm thêm", 1.5)
	ui.dirty = true

# ============================================================ với game nông trại
func reward(xu: int, left: int, mx: int) -> void:
	ui.farm_rew = {"xu": xu, "left": left, "max": mx}
	ui.dirty_dlg = true

func close_game() -> void:
	persist()
	closed.emit()
