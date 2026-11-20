extends Control
# ĐUA GÀ NÔNG TRẠI: viết lại bằng Godot từ bản web (dua-ga/index.html). Gốc phóng to K lần, mọi số bên trong là css px của web.
# Bước 1: đường Nông Trại, 17 tay đua, đua lẻ 3 vòng, AI, ô bắp, bùn, dốc rơm, vịt, rơi sông; HUD + nút cảm ứng như web
# (cỡ điện thoại: @media max-width 640 / 520), tạm dừng, bảng kết quả, xu nông trại (w_duong.dg_end).

signal ended(mode: String, place: int, diff: int)
signal closed

const A := preload("res://logic/xt/xt_art.gd")
const RACE := preload("res://logic/dg/dg_race.gd")
const MAP := preload("res://logic/dg/dg_map.gd")
const RES := preload("res://logic/dg/dg_res.gd")
const VIEW := preload("res://logic/dg/dg_view.gd")
const SND := preload("res://logic/dg/dg_snd.gd")

const KEM := Color("#fbf3df")
const KEM2 := Color("#f4e8c8")
const KEM3 := Color("#e6d4a8")
const PAPER := Color("#f3e7c6")
const INK := Color("#3b2415")
const INK2 := Color("#6e4d31")
const MUTED := Color("#8a6a48")
const WOOD := Color("#8a5a2b")
const WOODD := Color("#5e3a19")
const GACH := Color("#b5532f")
const GACHD := Color("#87391c")
const GACHL := Color("#d9774f")
const LA := Color("#4f8a2b")
const LAD := Color("#35631a")
const VANGL := Color("#ffe48a")
const VANGD := Color("#c9930c")
const SONG := Color("#3c8fa6")
const SONGD := Color("#276b7e")
const RIMW := Color("#fff9ea")
const SH := Color(59 / 255.0, 36 / 255.0, 21 / 255.0, 0.45)
const MAP_ID := "nongtrai"
const LAPS := 3
const REW := [60, 45, 35, 25, 15, 10]

class Lay extends Control:
	var fn: Callable
	func _init(f: Callable) -> void:
		fn = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		fn.call(self)

var K := 1.0
var P: Node = null          # pics.gd (gói l/)
var coins_fn := Callable()
var W := 412.0
var H := 915.0
var _vs := Vector2.ZERO
var mode := "boot"          # boot, menu, load, race
var chars: Array = []
var pers := {}
var sel := 0
var diff := 1
var paused := false
var R = null
var M = null
var RS = null
var view = null
var snd = null
var hud: Lay
var bg: Lay
var btns: Array = []        # [Rect2, việc, phím giữ]
var hold := {}              # ngón -> phím đang giữ
var t_load := 0.0
var load_ids: Array = []
var load_order: Array = []
var _stage := 0             # 0 chờ gói, 1 giải hình cảnh, 2 xong
var res_shown := false
var res_note := ""
var res_rows: Array = []
var strip_x := 0.0
var _drag = null
var _cnt := ""
var _cnt_t := 0.0
var _msg_t := ""
var _msg_pop := 0.0
var mini_vp: SubViewport = null
var mini_sz := Vector2(104, 84)
var clock := 0.0

func setup(k: float, pics: Node, coins: Callable = Callable()) -> void:
	K = maxf(1.0, k)
	P = pics
	coins_fn = coins

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	A.K = K
	bg = Lay.new(_draw_bg)
	add_child(bg)
	hud = Lay.new(_draw_hud)
	add_child(hud)
	P.load_bundle("dg_card")
	snd = SND.new(0)   # nhạc map Nông Trại (MUSICS[0])
	add_child(snd)
	resize()

func resize() -> void:
	var vs := get_viewport_rect().size
	_vs = vs
	scale = Vector2(K, K)
	W = vs.x / K
	H = vs.y / K
	size = Vector2(W, H)
	for l in [bg, hud]:
		l.position = Vector2.ZERO
		l.size = size
	if view != null:
		view.layout(W, H)
	mini_sz = Vector2(104, 104 * 4200.0 / 5200.0) if W <= 640 else Vector2(clampf(W * 0.15, 150, 190), clampf(W * 0.15, 150, 190) * 4200.0 / 5200.0)
	if M != null:
		_build_mini()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree() and _vs != Vector2.ZERO and get_viewport_rect().size != _vs:
		call_deferred("resize")

# ============================================================ vòng lặp
func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	clock += dt
	if mode == "boot":
		if P.has_bundle("dg_card"):
			var m: Dictionary = P.meta("dg_card")
			chars = m.get("chars", [])
			pers = m.get("pers", {})
			mode = "menu"
	elif mode == "load":
		t_load += dt
		_load_step()
	elif mode == "race":
		if not paused:
			R.step(dt)
			_events()
			if R.state == "result" and not res_shown:
				_show_results()
		RS.pump()
		snd.tick(dt, R.state == "race", R.player.lapShown >= R.laps, R.weather.k if R.state != "result" else 0.0, paused)
		view.redraw()
		_msg_pop = maxf(0, _msg_pop - dt)
	hud.queue_redraw()
	bg.visible = mode != "race"
	if bg.visible:
		bg.queue_redraw()

func _unhandled_key_input(e: InputEvent) -> void:
	if mode != "race" or R == null or not (e is InputEventKey):
		return
	var k: InputEventKey = e
	var m := {KEY_LEFT: "left", KEY_A: "left", KEY_RIGHT: "right", KEY_D: "right", KEY_UP: "up", KEY_W: "up", KEY_DOWN: "down", KEY_S: "down", KEY_SHIFT: "drift"}
	if m.has(k.keycode):
		R.keys[m[k.keycode]] = k.pressed
	elif k.pressed and not k.echo and k.keycode == KEY_ESCAPE and not res_shown:
		paused = not paused
	elif k.pressed and not k.echo and k.keycode == KEY_T:
		R.auto = not R.auto

# ============================================================ tải
func _start_race() -> void:
	snd.stop_all()
	# năm đối thủ bốc ngẫu nhiên trong mọi con (cả con chưa mở, cho nếm trước), con mình xuất phát cuối
	var idx: Array = []
	for i in chars.size():
		if i != sel:
			idx.append(i)
	idx.shuffle()
	load_order = idx.slice(0, 5)
	load_order.append(sel)
	load_ids = []
	for i in load_order:
		load_ids.append(String(chars[i].id))
	if RS == null:
		RS = RES.new(P)
	RS.request(MAP_ID, load_ids, String(chars[sel].id))
	mode = "load"
	t_load = 0.0
	_stage = 0
	res_shown = false
	paused = false

func _load_step() -> void:
	if _stage == 0:
		if RS.failed():
			return
		if RS.progress(MAP_ID, load_ids, String(chars[sel].id)) < 1.0:
			return
		if M == null:
			RS.open_map()
			M = MAP.new(RS.D)
			_build_mini()
		else:
			for b in RS.RB.values():
				RS.RM[b] = P.meta(b)
		_stage = 1
	elif _stage == 1:
		RS.pump_sprites(12.0)
		if not RS.sprites_done():
			return
		if R == null:
			R = RACE.new(M)
		R.new_race(load_order, chars, sel, LAPS, diff)
		if view == null:
			view = VIEW.new()
			view.setup(R, M, RS)
			add_child(view)
			move_child(view, 0)
			view.layout(W, H)
		R.CH = R.CH0
		view.visible = true
		# lúc đếm ngược máy quay vòng quanh: giải sẵn dáng đứng mọi góc + khung chạy từ sau lưng
		var all := range(17)
		for r in R.racers:
			RS.prewarm(r.id, [0, 1, 2] if not r.isPlayer else [0, 1, 2, 3, 4])
			var m: Dictionary = RS.rmeta(r.id)
			if not m.is_empty():
				for v in all:
					RS.rframe(r.id, int(m.v[v].st))
		_stage = 2
	elif _stage == 2:
		RS.pump(12.0)
		if RS._q.is_empty():
			_stage = 3
			mode = "race"

func load_frac() -> float:
	if RS == null:
		return 0.0
	var p: float = RS.progress(MAP_ID, load_ids, String(chars[sel].id))
	if _stage >= 1:
		p = 1.0
	if _stage >= 2:
		return 0.97
	return p * 0.85 + (0.12 * (1.0 - RS._spr_left.size() / maxf(1.0, RS.SM.size())) if _stage == 1 else 0.0)

# ============================================================ sự kiện của luật đua (chữ to / số đếm)
func _events() -> void:
	for e in R.ev:
		snd.on_event(e)
	R.ev.clear()
	if R.msg.t != _msg_t:
		_msg_t = R.msg.t
		_msg_pop = 0.4

func _show_results() -> void:
	res_shown = true
	R.update_ranks()
	var s: Array = R.racers.duplicate()
	s.sort_custom(func(a, b): return a.rank < b.rank)
	res_rows = s
	var pl = R.player
	res_note = ""
	ended.emit("single", int(pl.place), diff)

func reward(xu: int, left: int, mx: int) -> void:
	if xu > 0:
		res_note = "Nông trại thưởng +%d xu (còn %d/%d lượt thưởng hôm nay)." % [xu, left, mx]
	elif left <= 0:
		res_note = "Hôm nay hết %d lượt thưởng xu nông trại rồi, mai đua tiếp nghen." % mx
	else:
		res_note = "Vô top 3 là nông trại thưởng xu."

func _quit_race() -> void:
	snd.stop_all()
	mode = "menu"
	paused = false
	res_shown = false
	if view != null:
		view.visible = false
	if R != null:
		R.state = "menu"
	hold = {}

# ============================================================ chạm
func _gui_input(e: InputEvent) -> void:
	var pos := Vector2.ZERO
	var down := false
	var up := false
	var id := 0
	if e is InputEventScreenTouch:
		pos = e.position
		down = e.pressed
		up = not e.pressed
		id = e.index
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position
		down = e.pressed
		up = not e.pressed
		id = 99
	elif e is InputEventScreenDrag or e is InputEventMouseMotion:
		if _drag != null and (e is InputEventMouseMotion or e.index == _drag.id):
			strip_x = clampf(_drag.sx - (e.position.x - _drag.x), 0.0, maxf(0.0, _strip_len() - W + 32))
			if absf(e.position.x - _drag.x) > 8:
				_drag.moved = true
		accept_event()
		return
	else:
		return
	accept_event()
	if down:
		for b in btns:
			if (b[0] as Rect2).has_point(pos):
				if b.size() > 2 and b[2] != "":
					hold[id] = b[2]
					_keys()
					if R != null and b[2] in ["item", "ability"]:
						R.keys[b[2]] = true
					elif R != null and b[2] == "drift":
						R.keys.trick = true
				elif String(b[1]).begins_with("card:"):
					_drag = {"id": id, "x": pos.x, "sx": strip_x, "moved": false, "act": b[1]}
				else:
					_act(String(b[1]))
				return
		if mode == "menu" and pos.y > _strip_y() and pos.y < _strip_y() + 96:
			_drag = {"id": id, "x": pos.x, "sx": strip_x, "moved": false, "act": ""}
	elif up:
		if hold.has(id):
			hold.erase(id)
			_keys()
		if _drag != null and _drag.id == id:
			if not _drag.moved and _drag.act != "":
				_act(_drag.act)
			_drag = null

func _keys() -> void:
	if R == null:
		return
	for k in ["left", "right", "drift"]:
		R.keys[k] = hold.values().has(k)

func _act(a: String) -> void:
	if a.begins_with("card:"):
		var i := int(a.substr(5))
		if _unlocked(chars[i]):
			sel = i
		return
	if a.begins_with("diff:"):
		diff = int(a.substr(5))
		return
	match a:
		"go":
			_start_race()
		"farm":
			snd.stop_all()
			closed.emit()
		"pause":
			paused = true
			hold = {}
			_keys()
		"resume":
			paused = false
		"restart", "again":
			_start_race()
		"quit", "again2":
			_quit_race()
		"auto":
			R.auto = not R.auto
		"mute":
			SND.muted = not SND.muted

func _unlocked(ch: Dictionary) -> bool:
	return not ch.has("unlock")   # mở bằng Giải Làng (bước 3)

func _btn(r: Rect2, act: String, key := "") -> void:
	btns.append([r, act, key])

# ============================================================ vẽ chung
# hộp kiểu web: nền, các vòng viền trong (inset box-shadow) từ ngoài vào, bóng đổ dưới
func _rbox(ci: CanvasItem, r: Rect2, rad: float, col: Color, rings := [], drop := 0.0, dropc := SH) -> void:
	if drop > 0:
		A.box(ci, Rect2(r.position + Vector2(0, drop), r.size), dropc, rad)
	A.box(ci, r, col, rad)
	var o := 0.0
	for g in rings:
		var w: float = g[0] - o
		A.box(ci, r.grow(-o), Color(0, 0, 0, 0), maxf(0, rad - o), w, g[1])
		o = g[0]

func _btn_draw(ci: CanvasItem, r: Rect2, t: String, alt: bool, act: String, fs := 21.0) -> void:
	if alt:
		_rbox(ci, r, 14, KEM, [[2.5, WOOD]], 4, WOODD)
	else:
		_rbox(ci, r, 14, GACH, [], 4, GACHD)
	A.text(ci, t, r.get_center().x, r.get_center().y + 1, fs, INK if alt else KEM, 1, 800)
	_btn(r, act)

func _circle(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, col, true, -1, true)

func _ring(ci: CanvasItem, c: Vector2, r: float, w: float, col: Color) -> void:
	ci.draw_arc(c, r - w / 2, 0, TAU, 48, col, w, true)

func _icon(ci: CanvasItem, k: String, c: Vector2, s: float, col: Color) -> void:
	match k:
		"pause":
			A.box(ci, Rect2(c.x - s * 0.36, c.y - s * 0.42, s * 0.26, s * 0.84), col, s * 0.08)
			A.box(ci, Rect2(c.x + s * 0.1, c.y - s * 0.42, s * 0.26, s * 0.84), col, s * 0.08)
		"left", "right":
			var d := -1.0 if k == "left" else 1.0
			var pts := PackedVector2Array([c + Vector2(d * s * 0.42, 0), c + Vector2(-d * s * 0.3, -s * 0.44), c + Vector2(-d * s * 0.3, s * 0.44)])
			ci.draw_colored_polygon(pts, col)
			ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), col, s * 0.12, true)
		"drift":
			var p := PackedVector2Array()
			for i in 25:
				var u := i / 24.0
				p.append(c + Vector2((u - 0.5) * s, sin(u * TAU) * s * -0.22))
			ci.draw_polyline(p, col, s * 0.13, true)
		"star":
			ci.draw_colored_polygon(A.star_pts(c, s * 0.5, s * 0.22), col)

# ============================================================ nền menu / màn tải
func _draw_bg(ci: CanvasItem) -> void:
	if mode == "race":
		return
	ci.draw_rect(Rect2(0, 0, W, H), Color("#4f7a2e"))
	# ruộng xa xa cho đỡ trống: sọc luống
	for i in 14:
		var y := H * 0.08 + i * H * 0.07
		ci.draw_rect(Rect2(0, y, W, H * 0.028), Color(1, 1, 1, 0.035))
	ci.draw_rect(Rect2(0, 0, W, H), Color(40 / 255.0, 26 / 255.0, 14 / 255.0, 0.5))

func _draw_hud(ci: CanvasItem) -> void:
	btns = []
	match mode:
		"boot":
			_loading(ci, "Đang mở chuồng gà...", -1.0)
		"menu":
			_menu(ci)
		"load":
			_loading(ci, "Đang dắt gà ra đường đua...", load_frac())
		"race":
			_race_hud(ci)
			if paused:
				_pause(ci)
			elif res_shown:
				_results(ci)

func _loading(ci: CanvasItem, t: String, f: float) -> void:
	var c := Vector2(W / 2, H * 0.46)
	A.text(ci, "Đua Gà Nông Trại", c.x, c.y - 52, 30, VANGL, 1, 800, 5, GACHD)
	A.text(ci, t, c.x, c.y, 17, KEM, 1, 700)
	var bw := minf(260.0, W - 80)
	var r := Rect2(c.x - bw / 2, c.y + 22, bw, 14)
	_rbox(ci, r, 7, Color(0, 0, 0, 0.3), [[2, KEM3]])
	if f >= 0:
		A.box(ci, Rect2(r.position + Vector2(3, 3), Vector2(maxf(8, (bw - 6) * f), 8)), Color("#f4c21f"), 4)
	else:
		var u := fposmod(clock * 0.8, 1.0)
		A.box(ci, Rect2(r.position.x + 3 + (bw - 66) * u, r.position.y + 3, 60, 8), Color("#f4c21f"), 4)
	if RS != null and RS.failed():
		A.text(ci, "Mạng chập chờn, tải không được. Bấm Về vườn rồi vô lại nghen.", c.x, c.y + 64, 14, KEM, 1, 600)
	var br := Rect2(W / 2 - 70, H - 90, 140, 46)
	_btn_draw(ci, br, "Về vườn", true, "farm", 18)

# ============================================================ menu (bước 1: chọn tay đua + độ khó; đường Nông Trại)
func _strip_y() -> float:
	return _strip_y_v

func _strip_len() -> float:
	return chars.size() * 98.0 + 16

func _menu(ci: CanvasItem) -> void:
	var bx := maxf(0.0, (W - 440) / 2)
	var bw := minf(W, 440.0)
	var r := Rect2(bx, 0, bw, H)
	A.box(ci, r, KEM, 0 if W <= 440 else 20)
	var x0 := bx + 16
	var x1 := bx + bw - 16
	# đầu: tên + xu + về vườn
	A.text(ci, "Đua Gà", x0, 26, 24, GACH, 0, 800)
	A.text(ci, "Nông Trại", x0, 51, 24, GACH, 0, 800)
	var fb := Rect2(x1 - 96, 16, 96, 38)
	_rbox(ci, fb, 14, KEM, [[2.5, WOOD]], 3, WOODD)
	A.text(ci, "Về vườn", fb.get_center().x, fb.get_center().y + 1, 16, INK, 1, 800)
	_btn(fb, "farm")
	if coins_fn.is_valid():
		var cs := "%s xu" % str(coins_fn.call())
		var cw := A.tw(cs, 17) + 36
		var cr := Rect2(fb.position.x - 8 - cw, 19, cw, 32)
		A.box(ci, cr, KEM2, 16)
		_circle(ci, cr.position + Vector2(15, 16), 8, Color("#f4c21f"))
		_ring(ci, cr.position + Vector2(15, 16), 8, 1.5, VANGD)
		A.text(ci, cs, cr.position.x + 27, cr.get_center().y + 1, 17, INK, 0, 800)
	# sân khấu: con đang chọn đứng trên nia
	var ch: Dictionary = chars[sel]
	var sr := Rect2(x0, 74, x1 - x0, 196)
	A.grad_poly(ci, A.rrect_pts(sr, 16), sr.position, sr.end, [[0, Color("#fff2c4")], [1, Color("#f0d48a")]])
	A.box(ci, sr, Color(0, 0, 0, 0), 16, 2, KEM3)
	var pc := Vector2(sr.get_center().x, sr.end.y - 40)
	A.ell(ci, pc + Vector2(0, 6), 92, 24, Color("#8a5a2b"))
	A.ell(ci, pc, 90, 22, Color("#c99a5c"))
	A.ell(ci, pc, 74, 16, Color("#d8b070"))
	for i in 5:
		var ep := A.ell_pts(pc, 70.0 - i * 13, 15.0 - i * 2.8, 40)
		ep.append(ep[0])
		ci.draw_polyline(ep, Color(0.45, 0.3, 0.15, 0.22), 1.0, true)
	var tx: Texture2D = P.tex("dg_card", String(ch.id))
	var cm: Dictionary = P.meta("dg_card")
	if tx != null and cm.has("f"):
		var f: Array = cm.f[String(ch.id)]
		var k := minf(1.0, 150.0 / float(f[3]))
		var bob := sin(clock * 2.4) * 1.5
		ci.draw_texture_rect(tx, Rect2(pc.x + float(f[0]) * k, pc.y + float(f[1]) * k + bob, float(f[2]) * k, float(f[3]) * k), false)
	# tên, kỹ năng, chỉ số
	var y := sr.end.y + 26
	A.text(ci, String(ch.name), x0, y, 26, INK, 0, 800)
	var nw := A.tw(String(ch.name), 26) + 14
	_icon(ci, "star", Vector2(x0 + nw + 7, y), 15, GACH)
	A.text(ci, String(ch.ab), x0 + nw + 18, y + 1, 16, GACH, 0, 700)
	y += 26
	for ln in A.wrap(String(ch.abd), 14, 500, x1 - x0):
		A.text(ci, ln, x0, y, 14, INK2, 0, 500)
		y += 19
	y += 4
	for s in [["Tốc độ", "spd"], ["Tăng tốc", "acc"], ["Bẻ lái", "turn"]]:
		A.text(ci, s[0], x0, y, 13, INK2, 0, 600)
		var br := Rect2(x0 + 78, y - 5, x1 - x0 - 78, 10)
		A.box(ci, br, KEM2, 5)
		var v := clampf(roundf((float(ch[s[1]]) - 0.75) / 0.45 * 100.0), 0, 100) / 100.0
		A.box(ci, Rect2(br.position, Vector2(br.size.x * v, 10)), LA, 5)
		y += 20
	# chọn tay đua: dải thẻ lướt ngang
	y += 8
	A.text(ci, "CHỌN TAY ĐUA", x0, y, 12, MUTED, 0, 700)
	var sy := y + 14
	_strip_y_v = sy
	var cmf: Dictionary = cm.get("f", {})
	for i in chars.size():
		var c: Dictionary = chars[i]
		var cr := Rect2(x0 + i * 98 - strip_x, sy, 90, 92)
		if cr.end.x < bx or cr.position.x > bx + bw:
			continue
		var on := i == sel
		var lock := not _unlocked(c)
		if on:
			_rbox(ci, cr, 14, Color("#fff3cf"), [[3, GACH]], 3, GACHD)
		else:
			_rbox(ci, cr, 14, KEM2, [[2, KEM3]])
		var t: Texture2D = P.tex("dg_card", String(c.id))
		if t != null and cmf.has(String(c.id)):
			var f: Array = cmf[String(c.id)]
			var k := minf(56.0 / float(f[3]), 70.0 / float(f[2]))
			var fc := Vector2(cr.get_center().x, cr.position.y + 64)
			ci.draw_texture_rect(t, Rect2(fc.x + float(f[0]) * k, fc.y + float(f[1]) * k, float(f[2]) * k, float(f[3]) * k), false, Color(1, 1, 1, 0.45) if lock else Color.WHITE)
		A.text(ci, String(c.name), cr.get_center().x, cr.end.y - 13, 12.5, GACH if on else INK, 1, 700)
		if lock:
			_lock(ci, cr.position + Vector2(cr.size.x - 18, 18))
		_btn(cr, "card:%d" % i)
	# độ khó
	y = sy + 92 + 26
	A.text(ci, "ĐỘ KHÓ", x0, y, 12, MUTED, 0, 700)
	var segw := 3 * 74.0
	var sg := Rect2(x1 - segw - 8, y - 20, segw + 8, 40)
	A.box(ci, sg, KEM2, 12)
	for i in 3:
		var b := Rect2(sg.position.x + 4 + i * 74, sg.position.y + 4, 74, 32)
		if i == diff:
			_rbox(ci, b, 9, GACH, [], 2, GACHD)
		A.text(ci, ["Dễ", "Thường", "Khó"][i], b.get_center().x, b.get_center().y + 1, 15, KEM if i == diff else INK2, 1, 700)
		_btn(b, "diff:%d" % i)
	# thanh vào đua
	var gy := H - 70
	ci.draw_rect(Rect2(bx, gy - 1, bw, 71), KEM)
	ci.draw_line(Vector2(bx, gy - 1), Vector2(bx + bw, gy - 1), KEM3, 2)
	A.text(ci, String(ch.name), x0, gy + 35, 20, INK, 0, 800)
	A.text(ci, " · Nông Trại", x0 + A.tw(String(ch.name), 20), gy + 36, 15, MUTED, 0, 600)
	var gr := Rect2(x1 - 160, gy + 12, 160, 48)
	_btn_draw(ci, gr, "Vào đua!", false, "go", 21)

var _strip_y_v := 430.0

func _lock(ci: CanvasItem, c: Vector2) -> void:
	_circle(ci, c, 11, INK)
	ci.draw_arc(c + Vector2(0, -2), 4, PI, TAU, 12, KEM, 1.8, true)
	A.box(ci, Rect2(c.x - 5, c.y - 2, 10, 7), KEM, 1.5)

# ============================================================ HUD lúc đua (cỡ điện thoại của web)
func _race_hud(ci: CanvasItem) -> void:
	var pl = R.player
	var ph := W <= 640
	# chớp tối khi trúng đòn (web vẽ đè lên canvas trước HUD)
	if R.flash > 0:
		ci.draw_rect(Rect2(0, 0, W, H), Color(40 / 255.0, 52 / 255.0, 96 / 255.0, R.flash * 0.6))
	# vệt gió khi turbo
	if pl.boostT > 0 and not paused:
		var cx := W / 2
		var cy: float = view.HOR + (H - view.HOR) * 0.35
		for i in 22:
			var a := randf() * TAU
			var r0 := maxf(W, H) * (0.42 + randf() * 0.15)
			var r1 := r0 + 60 + randf() * 120
			ci.draw_line(Vector2(cx + cos(a) * r0, cy + sin(a) * r0 * 0.7), Vector2(cx + cos(a) * r1, cy + sin(a) * r1 * 0.7), Color(1, 1, 1, 0.55), 2)
	var top := 8.0 if ph else 10.0
	var bs := 38.0 if ph else 44.0
	# nút tạm dừng
	var pc := Vector2(12 + bs / 2, top + bs / 2)
	_circle(ci, pc + Vector2(0, 3), bs / 2, SH)
	_circle(ci, pc, bs / 2, KEM)
	_ring(ci, pc, bs / 2, 3, WOOD)
	_ring(ci, pc, bs / 2 - 3, 2, RIMW)
	_icon(ci, "pause", pc, 15 if ph else 18, INK)
	_btn(Rect2(pc - Vector2(bs, bs) / 2, Vector2(bs, bs)).grow(6), "pause")
	# hạng · vòng · giờ
	var rk := str(pl.rank + 1)
	var fsb := 31.0 if ph else 38.0
	var fsl := 12.5 if ph else 14.0
	var lap := "VÒNG %d/%d" % [clampi(floori(pl.prog / M.N) + 1, 1, R.laps), R.laps]
	var tm := _fmt(pl.finT if pl.finished else R.race_t)
	var w_b := maxf(A.tw(rk, fsb), fsb * 0.6)
	var w_of := A.tw("/" + str(R.racers.size()), 13 if ph else 16, 700)
	var w_lt := maxf(A.tw(lap, fsl, 800) + 4, A.tw("0:00.00", fsl, 600) + 4)
	var rx := 12 + bs + 7
	var rw := 8 + w_b + 2 + w_of + 7 + 2 + 8 + w_lt + 10
	var rr := Rect2(rx, top, rw, bs)
	_rbox(ci, rr, 12 if ph else 14, KEM, [[3, WOOD], [5, RIMW]], 3, SH)
	var bx := rx + 8 + w_b / 2
	var pop := 1.0 + 0.7 * pow(R.rank_pop / 0.45, 2) if R.rank_pop > 0 else 1.0
	if pop != 1.0:
		A.text(ci, rk, 0, top + bs / 2 + 3 - (top + bs * 0.6), fsb, GACH, 1, 800, 0.0, INK, Transform2D(0, Vector2(pop, pop), 0, Vector2(bx, top + bs * 0.6)))
	else:
		A.text(ci, rk, bx, top + bs / 2 + 3, fsb, GACH, 1, 800)
	var ox := rx + 8 + w_b + 2
	A.text(ci, "/" + str(R.racers.size()), ox, top + bs / 2 + 6, 13 if ph else 16, MUTED, 0, 700)
	var lx := ox + w_of + 7
	_dash_v(ci, lx, top + 7, top + bs - 7, KEM3)
	A.text(ci, lap, lx + 8 + 1, top + bs / 2 - 7, fsl, INK, 0, 800)
	A.text(ci, tm, lx + 8 + 1, top + bs / 2 + 8, fsl, INK2, 0, 600)
	# bản đồ nhỏ
	if mini_vp != null:
		var mr := Rect2(W - 12 - mini_sz.x, top, mini_sz.x, mini_sz.y)
		ci.draw_texture_rect(mini_vp.get_texture(), Rect2(mr.position + Vector2(0, 3), mr.size), false, Color(0.23, 0.14, 0.08, 0.4))
		ci.draw_texture_rect(mini_vp.get_texture(), mr, false)
		var fr := roundf(mr.size.x * 0.058)
		var ms: float = (mr.size.x - 2 * fr) / M.WORLD_W
		var k := mr.size.x / 200.0
		var rs: Array = R.racers.duplicate()
		rs.sort_custom(func(a, b): return int(a.isPlayer) < int(b.isPlayer))
		for r in rs:
			var p := mr.position + Vector2(fr + r.x * ms, fr + r.y * ms)
			var rad := (5.4 if r.isPlayer else 3.8) * k
			_circle(ci, p, rad, GACH if r.isPlayer else Color(String(r.ch.dark)))
			ci.draw_arc(p, rad, 0, TAU, 20, Color("#fff8e6") if r.isPlayer else INK, (1.8 if r.isPlayer else 1.2) * k, true)
			if r.isPlayer:
				ci.draw_arc(p, 6.3 * k, 0, TAU, 24, INK, 0.9 * k, true)
	# chữ: nhỏ trong viên kem, to (chữ hoa) giữa màn
	if R.msg.life > 0 and R.msg.t != "":
		var t: String = R.msg.t
		var big := t == t.to_upper()
		var a := clampf(R.msg.life / 0.3, 0, 1)
		if big:
			var s := 1.0 - 0.5 * pow(_msg_pop / 0.4, 2) if _msg_pop > 0 else 1.0
			var fs := 34.0 if ph else clampf(W * 0.06, 34, 58)
			var bxf := Transform2D(0, Vector2(s, s), 0, Vector2(W / 2, H * (0.24 if ph else 0.27) + fs * 0.5))
			A.text(ci, t, 0, 6, fs, Color(SH, 0.45 * a), 1, 800, 5, Color(SH, 0.45 * a), bxf)
			A.text(ci, t, 0, 0, fs, Color(VANGL, a), 1, 800, 5, Color(GACHD, a), bxf)
		else:
			var fs := 15.0 if ph else 19.0
			var tw := A.tw(t, fs) + 26
			var tr := Rect2(W / 2 - tw / 2, (96.0 if ph else 118.0), tw, fs + 13)
			_rbox(ci, tr, 20, Color(KEM, a), [[2.5, Color(WOOD, a)]], 3, Color(SH, 0.4 * a))
			A.text(ci, t, W / 2, tr.get_center().y + 1, fs, Color(INK, a), 1, 800)
	# đếm ngược: con dấu đỏ 3, 2, 1 rồi ĐI! xanh
	var cd := ""
	if R.state == "count":
		var n := ceili(R.count_t)
		if n >= 1 and n <= 3:
			cd = str(n)
	elif R.state == "race" and R.race_t < 0.8:
		cd = "ĐI!"
	if cd != _cnt:
		_cnt = cd
		_cnt_t = 0.0
	_cnt_t += get_process_delta_time()
	if cd != "":
		_stamp(ci, cd, ph)
	# turbo, đi ngược, tự đua
	var tb: int = R.player.tier if R.player.drift else 0
	if tb > 0:
		var t := "TURBO!!" if tb == 2 else "TURBO!"
		var fs := 16.0 if ph else 20.0
		var w := A.tw(t, fs) + 30
		var r := Rect2(W / 2 - w / 2, H * (0.56 if ph else 0.58), w, fs + 12)
		_rbox(ci, r, 16, GACHL if tb == 2 else SONG, [], 3, GACHD if tb == 2 else SONGD)
		A.text(ci, t, W / 2, r.get_center().y + 1, fs, KEM, 1, 800)
	if R.wrong_t > 1 and fmod(clock, 0.6) < 0.3:
		var t := "ĐI NGƯỢC RỒI!"
		var fs := 20.0 if ph else 26.0
		var w := A.tw(t, fs) + 40
		var r := Rect2(W / 2 - w / 2, H * 0.47, w, fs + 18)
		_rbox(ci, r, 16, GACH, [], 4, GACHD)
		A.text(ci, t, W / 2, r.get_center().y + 1, fs, KEM, 1, 800)
	if R.auto and not pl.finished:
		var t := "ĐANG TỰ ĐUA"
		var w := A.tw(t, 14) + 28
		var r := Rect2(W / 2 - w / 2, H - 112 - 30, w, 28)
		A.box(ci, r, Color(43 / 255.0, 30 / 255.0, 18 / 255.0, 0.78), 14)
		A.text(ci, t, W / 2, r.get_center().y + 1, 14, Color("#f4c21f"), 1, 800)
	# nút cảm ứng
	if not res_shown:
		_touch(ci)

func _stamp(ci: CanvasItem, cd: String, ph: bool) -> void:
	var go := cd == "ĐI!"
	var d := 96.0 if ph else 118.0
	var w := (140.0 if ph else 170.0) if go else d
	var u := clampf(_cnt_t / 0.42, 0, 1)
	var sc := 1.0
	var rot := -6.0
	var al := 1.0
	if u < 0.6:
		var v := u / 0.6
		sc = lerpf(2.3, 0.9, v)
		rot = lerpf(-16, -5, v)
		al = v
	else:
		var v := (u - 0.6) / 0.4
		sc = lerpf(0.9, 1.0, v)
		rot = lerpf(-5, -6, v)
	var c := Vector2(W / 2, H * 0.41)
	var bgc := LA if go else GACH
	var dk := LAD if go else GACHD
	var xf := Transform2D(deg_to_rad(rot), Vector2(sc, sc), 0, c)
	var r := Rect2(-w / 2, -d / 2, w, d)
	var rad := 60.0 if go else d / 2
	A.box(ci, Rect2(r.position + Vector2(0, 10), r.size), Color(40 / 255.0, 20 / 255.0, 10 / 255.0, 0.18 * al), rad, 0.0, Color(0, 0, 0, 0), [], xf)
	A.box(ci, Rect2(r.position + Vector2(0, 6), r.size), Color(dk, al), rad, 0.0, Color(0, 0, 0, 0), [], xf)
	A.box(ci, r, Color(bgc, al), rad, 0.0, Color(0, 0, 0, 0), [], xf)
	A.box(ci, r.grow(-5), Color(0, 0, 0, 0), rad - 5, 3, Color(KEM, al), [], xf)
	var fs := (54.0 if ph else 66.0) if go else (60.0 if ph else 74.0)
	A.text(ci, cd, 0, 4, fs, Color(KEM, al), 1, 800, 0.0, INK, xf)
	# vòng sáng loang ra
	var v2 := clampf((_cnt_t - 0.12) / 0.5, 0, 1)
	if v2 > 0 and v2 < 1:
		var rxf := Transform2D(deg_to_rad(rot), Vector2(1, 1) * lerpf(0.9, 1.55, v2), 0, c)
		A.box(ci, r.grow(6), Color(0, 0, 0, 0), rad + 6, 4, Color(KEM, 0.85 * 0.9 * (1 - v2)), [], rxf)

func _touch(ci: CanvasItem) -> void:
	var small := W <= 520
	var big := 66.0 if small else 76.0
	var sm := 52.0 if small else 60.0
	var gap := 9.0 if small else 12.0
	var by := H - 14
	var lc := Vector2(14 + big / 2, by - big / 2)
	_tb(ci, lc, big, "left", "left", "", small)
	_tb(ci, lc + Vector2(big + gap, 0), big, "right", "right", "", small)
	# nhóm phải (web: Trượt, Kỹ năng, thúng vật phẩm, canh đáy)
	var ic := Vector2(W - 14 - big / 2, by - big / 2)
	var kc := ic - Vector2(big + gap, 0)
	var dc := Vector2(kc.x - big / 2 - gap - sm / 2, by - sm / 2)
	_tb(ci, dc, sm, "drift", "drift", "Trượt", small)
	_tb_skill(ci, kc, big, small)
	_tb_item(ci, ic, big)

# nút Kỹ năng: vòng tiến độ (gauge), đầy thì sao đỏ gạch + vầng vàng nhịp 1 giây
func _tb_skill(ci: CanvasItem, c: Vector2, d: float, small: bool) -> void:
	var pl = R.player
	var on: bool = hold.values().has("ability")
	var ga := clampf(pl.gauge, 0, 1)
	var full := ga >= 1
	var r := d / 2
	if on:
		c.y += 3
	if full:
		var g := 0.5 - 0.5 * cos(clock * TAU)
		_circle(ci, c, r + 7 * g, Color(244 / 255.0, 194 / 255.0, 31 / 255.0, 0.55 * g))
	_circle(ci, c + Vector2(0, 1 if on else 4), r, Color(59 / 255.0, 36 / 255.0, 21 / 255.0, 0.5))
	_circle(ci, c, r, VANGL if on else Color(251 / 255.0, 243 / 255.0, 223 / 255.0, 0.86))
	_ring(ci, c, r, 3, WOOD)
	_ring(ci, c, r - 3, 2, Color(1, 249 / 255.0, 234 / 255.0, 0.9))
	# svg 64x64, r 28.5, nét 5, bắt đầu từ đỉnh
	var k := d / 64.0
	ci.draw_arc(c, 28.5 * k, 0, TAU, 48, Color("#f4e8c8"), 5 * k, true)
	if ga > 0:
		ci.draw_arc(c, 28.5 * k, -PI / 2, -PI / 2 + TAU * ga, maxi(4, int(48 * ga)), Color("#f4c21f") if full else Color("#4f8a2b"), 5 * k, true)
	var isz := 24.0 if small else 28.0
	var col := Color("#b5532f") if full else INK
	var sc := c + Vector2(0, -5)
	var pts := A.star_pts(sc, isz * 0.5 * 0.92, isz * 0.5 * 0.92 * 0.45)
	ci.draw_colored_polygon(pts, col)
	var lp := pts.duplicate()
	lp.append(pts[0])
	ci.draw_polyline(lp, col, isz / 24.0 * 1.6, true)
	A.text(ci, "Kỹ năng", c.x, c.y + isz * 0.5 + 3, 10 if small else 11, INK2, 1, 700)
	btns.append([Rect2(c - Vector2(r, r), Vector2(d, d)).grow(4), "", "ability"])

# nút thúng: mặt thúng + món đang giữ (lúc quay thì lật qua lại các món), chấm cấp, xN
func _tb_item(ci: CanvasItem, c: Vector2, d: float) -> void:
	var pl = R.player
	var on: bool = hold.values().has("item")
	var r := d / 2
	var ready: bool = pl.item != null and pl.item != "" and pl.rollT <= 0
	if on:
		c.y += 3
	if ready:
		_circle(ci, c + Vector2(0, 1 if on else 4), r + 4, Color(244 / 255.0, 194 / 255.0, 31 / 255.0, 0.6))
	_circle(ci, c + Vector2(0, 1 if on else 4), r, Color(59 / 255.0, 36 / 255.0, 21 / 255.0, 0.5))
	_circle(ci, c, r, VANGL if on else Color(251 / 255.0, 243 / 255.0, 223 / 255.0, 0.86))
	# canvas inset 3px, bo tròn
	var w := d - 6
	var o := c - Vector2(w / 2, w / 2)
	var bt = RS.fx("basket")
	if bt != null:
		ci.draw_texture_rect(bt, Rect2(o, Vector2(w, w)), false)
	var has: bool = pl.item != null and pl.item != ""
	var roll: bool = has and pl.rollT > 0
	var key: String = String(R.IKEYS[int(floor(clock * 14)) % R.IKEYS.size()]) if roll else (String(pl.item) if has else "")
	var lvl: int = 0 if roll else int(pl.lvl)
	var uses: int = 0 if roll else int(pl.uses)
	if key != "":
		var it = RS.fx("ic_" + key)
		if it != null:
			var s := w * 0.5
			var cy := o.y + w * (0.46 if lvl > 0 else 0.5)
			ci.draw_texture_rect(it, Rect2(o.x + w / 2 - s, cy - s, s * 2, s * 2), false)
	else:
		A.text(ci, "?", o.x + w / 2, o.y + w * 0.55, roundf(w * 0.34), Color(110 / 255.0, 77 / 255.0, 49 / 255.0, 0.5), 1, 800)
	if key != "" and lvl > 0:
		for j in 3:
			var pc := o + Vector2(w / 2 + (j - 1) * w * 0.1, w * 0.765)
			_circle(ci, pc, w * 0.036, Color("#b5532f") if j < lvl else Color("#fbf3df"))
			_ring(ci, pc, w * 0.036 + w * 0.006, w * 0.012, INK)
	if key != "" and uses > 1:
		A.text(ci, "x%d" % uses, o.x + w * 0.76, o.y + w * 0.26, roundf(w * 0.2), Color("#b5532f"), 1, 800, w * 0.05, Color("#fbf3df"))
	_ring(ci, c, r, 3, Color("#c9930c") if ready else WOOD)
	_ring(ci, c, r - 3, 2, Color(1, 249 / 255.0, 234 / 255.0, 0.9))
	btns.append([Rect2(c - Vector2(r, r), Vector2(d, d)).grow(4), "", "item"])

func _tb(ci: CanvasItem, c: Vector2, d: float, ico: String, key: String, lab: String, small: bool) -> void:
	var on: bool = hold.values().has(key)
	var r := d / 2
	if on:
		c.y += 3
	_circle(ci, c + Vector2(0, 1 if on else 4), r, Color(59 / 255.0, 36 / 255.0, 21 / 255.0, 0.5))
	_circle(ci, c, r, VANGL if on else Color(251 / 255.0, 243 / 255.0, 223 / 255.0, 0.86))
	_ring(ci, c, r, 3, WOOD)
	_ring(ci, c, r - 3, 2, Color(1, 249 / 255.0, 234 / 255.0, 0.9))
	var isz := (24.0 if small else 28.0) if d > 60 else (19.0 if small else 22.0)
	if lab != "":
		_icon(ci, ico, c + Vector2(0, -5), isz, INK)
		A.text(ci, lab, c.x, c.y + isz * 0.5 + 3, 10 if small else 11, INK2, 1, 700)
	else:
		_icon(ci, ico, c, isz, INK)
	btns.append([Rect2(c - Vector2(r, r), Vector2(d, d)).grow(4), "", key])

func _dash_v(ci: CanvasItem, x: float, y0: float, y1: float, col: Color) -> void:
	var y := y0
	while y < y1:
		ci.draw_line(Vector2(x + 1, y), Vector2(x + 1, minf(y1, y + 3)), col, 2)
		y += 6

func _fmt(t: float) -> String:
	var m := floori(t / 60)
	var s := fmod(t, 60.0)
	return "%d:%s%.2f" % [m, "0" if s < 10 else "", s]

# ============================================================ tạm dừng / kết quả
func _overlay(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, W, H), Color(40 / 255.0, 26 / 255.0, 14 / 255.0, 0.55))

func _board(ci: CanvasItem, r: Rect2) -> void:
	A.box(ci, Rect2(r.position + Vector2(0, 14), r.size), Color(30 / 255.0, 18 / 255.0, 8 / 255.0, 0.2), 20)
	_rbox(ci, r, 20, KEM, [[3, WOOD], [5, RIMW]], 3, Color(59 / 255.0, 36 / 255.0, 21 / 255.0, 0.4))

func _pause(ci: CanvasItem) -> void:
	_overlay(ci)
	var bw := minf(380.0, W - 24)
	var bh := 22 + 42 + 14 + 4 * (47 + 12) + 54 + 10
	var r := Rect2((W - bw) / 2, (H - bh) / 2, bw, bh)
	_board(ci, r)
	A.text(ci, "Tạm dừng", r.get_center().x, r.position.y + 22 + 21, 34, GACH, 1, 800)
	var y := r.position.y + 22 + 42 + 14
	for b in [["Chạy tiếp", false, "resume"], ["Đua lại từ đầu", true, "restart"], ["Về chọn gà", true, "quit"], ["Về vườn", true, "farm"]]:
		_btn_draw(ci, Rect2(r.position.x + 22, y, bw - 44, 47), b[0], b[1], b[2])
		y += 59
	_dash_h(ci, r.position.x + 22, r.end.x - 22, y + 2, KEM3)
	var tw1 := 14 + A.tw("Tự đua", 15, 700) + 9 + 34 + 8
	var tw2 := 14 + A.tw("Âm thanh", 15, 700) + 9 + 34 + 8
	var x0 := r.get_center().x - (tw1 + 8 + tw2) / 2
	_tgl(ci, Rect2(x0, y + 14, tw1, 32), "Tự đua", R.auto, "auto")
	_tgl(ci, Rect2(x0 + tw1 + 8, y + 14, tw2, 32), "Âm thanh", not SND.muted, "mute")

func _tgl(ci: CanvasItem, tr: Rect2, lab: String, on: bool, act: String) -> void:
	A.box(ci, tr, KEM2, 16, 2, KEM3)
	A.text(ci, lab, tr.position.x + 14, tr.get_center().y + 1, 15, INK, 0, 700)
	var sw := Rect2(tr.end.x - 42, tr.position.y + 6, 34, 20)
	A.box(ci, sw, LA if on else KEM3, 10)
	_circle(ci, sw.position + Vector2(24 if on else 10, 10), 7, Color.WHITE)
	_btn(tr, act)

func _dash_h(ci: CanvasItem, x0: float, x1: float, y: float, col: Color) -> void:
	var x := x0
	while x < x1:
		ci.draw_line(Vector2(x, y), Vector2(minf(x1, x + 3), y), col, 2)
		x += 6

func _results(ci: CanvasItem) -> void:
	_overlay(ci)
	var pl = R.player
	var bw := minf(520.0, W - 24)
	var rows := res_rows.size()
	var bh := 112.0 + rows * 50 + 6 + 20 + 18 + 47 + 22
	var r := Rect2((W - bw) / 2, maxf(12, (H - bh) / 2), bw, bh)
	_board(ci, r)
	# đầu: sọc khăn rằn, tựa, câu phụ
	var hr := Rect2(r.position + Vector2(3, 3), Vector2(bw - 6, 10))
	ci.draw_rect(hr, Color("#f3ede0"))
	var x := hr.position.x
	var i := 0
	while x < hr.end.x:
		for j in 2:
			if (i + j) % 2 == 0:
				ci.draw_rect(Rect2(x, hr.position.y + j * 5, minf(5, hr.end.x - x), 5), Color(43 / 255.0, 36 / 255.0, 32 / 255.0, 0.62))
		x += 5
		i += 1
	var place: int = pl.place
	var ttl := "Về nhất!" if place == 1 else "Về thứ %d" % place
	var sub := "Gà nhà mày đỉnh thật" if place == 1 else ("Lên bục rồi, ráng chút nữa là nhất" if place <= 3 else "Đua lại gỡ gạc không?")
	A.text(ci, ttl, r.get_center().x, r.position.y + 52, 36, GACH, 1, 800)
	A.text(ci, sub, r.get_center().x, r.position.y + 84, 16, INK2, 1, 600)
	ci.draw_line(Vector2(r.position.x + 3, r.position.y + 104), Vector2(r.end.x - 3, r.position.y + 104), WOOD, 3)
	# bảng hạng
	var y := r.position.y + 116
	var cm: Dictionary = P.meta("dg_card")
	var x0 := r.position.x + 18
	var x1 := r.end.x - 18
	for k in rows:
		var q = res_rows[k]
		var me: bool = q.isPlayer
		var rr := Rect2(x0, y, x1 - x0, 46)
		A.box(ci, rr, VANGL if me else KEM2, 10)
		var pcol: Color = [Color("#b58300"), Color("#8d8a80"), Color("#a85f2c")][k] if k < 3 else INK2
		A.text(ci, str(k + 1), x0 + 18, y + 24, 20, pcol, 1, 800)
		var t: Texture2D = P.tex("dg_card", String(q.id))
		if t != null and cm.has("f") and cm.f.has(String(q.id)):
			var f: Array = cm.f[String(q.id)]
			var kk := minf(38.0 / float(f[3]), 38.0 / float(f[2]))
			var fc := Vector2(x0 + 56, y + 43)
			ci.draw_texture_rect(t, Rect2(fc.x + float(f[0]) * kk, fc.y + float(f[1]) * kk, float(f[2]) * kk, float(f[3]) * kk), false)
		var nm := String(q.ch.name)
		A.text(ci, nm, x0 + 84, y + 24, 15, INK, 0, 600)
		var nx := x0 + 84 + A.tw(nm, 15, 600) + 6
		if me:
			var bwd := A.tw("mày", 11) + 12
			A.box(ci, Rect2(nx, y + 15, bwd, 17), GACH, 7)
			A.text(ci, "mày", nx + bwd / 2, y + 24, 11, KEM, 1, 800)
		else:
			var pn := String(pers.get(String(q.ai.pers), {}).get("name", ""))
			A.text(ci, "· " + pn, nx, y + 25, 12.5, MUTED, 0, 500)
		A.text(ci, _fmt(q.finT) if q.finished else "đang chạy", x1 - 8, y + 24, 15, INK, 2, 700)
		y += 50
	y += 6
	if res_note != "":
		for ln in A.wrap(res_note, 14, 600, x1 - x0):
			A.text(ci, ln, x0, y + 9, 14, INK2, 0, 600)
			y += 20
	else:
		y += 20
	y += 18
	var bwd2 := (x1 - x0 - 10) / 2
	_btn_draw(ci, Rect2(x0, y, bwd2, 47), "Đổi gà", true, "again2")
	_btn_draw(ci, Rect2(x0 + bwd2 + 10, y, bwd2, 47), "Đua lại", false, "again")

# ============================================================ bản đồ nhỏ: vẽ một lần vào ảnh (buildMini của web)
func _build_mini() -> void:
	if mini_vp != null:
		mini_vp.queue_free()
	mini_vp = SubViewport.new()
	mini_vp.transparent_bg = true
	mini_vp.size = Vector2i(int(mini_sz.x * K), int(mini_sz.y * K))
	mini_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var l := Lay.new(_draw_mini)
	mini_vp.add_child(l)
	l.size = Vector2(mini_vp.size)
	add_child(mini_vp)

func _draw_mini(ci: CanvasItem) -> void:
	var Wp := float(mini_vp.size.x)
	var Hp := float(mini_vp.size.y)
	var fr := roundf(Wp * 0.058)
	var ms: float = (Wp - 2 * fr) / M.WORLD_W
	var k := Wp / 200.0
	ci.draw_rect(Rect2(fr * 0.5, fr * 0.5, Wp - fr, Hp - fr), PAPER)
	var o := Vector2(fr, fr)
	for w in M.WATER:
		var pts := PackedVector2Array()
		for p in w.pts:
			pts.append(o + Vector2(p[0], p[1]) * ms)
		var lw := maxf(3.2 * k, float(w.w) * 2 * ms)
		ci.draw_polyline(pts, INK, lw + 1.8 * k, true)
		ci.draw_polyline(pts, Color("#7cc0d8"), lw, true)
	if M.POND != null:
		var pp := A.ell_pts(o + Vector2(M.POND.x, M.POND.y) * ms, float(M.POND.rx) * ms, float(M.POND.ry) * ms, 32)
		ci.draw_colored_polygon(pp, Color("#7cc0d8"))
		pp.append(pp[0])
		ci.draw_polyline(pp, INK, 0.9 * k, true)
	var tp := PackedVector2Array()
	var i := 0
	while i < M.N:
		tp.append(o + Vector2(M.PX[i], M.PY[i]) * ms)
		i += 3
	tp.append(tp[0])
	ci.draw_polyline(tp, INK, 7 * k, true)
	for q in tp:
		_circle(ci, q, 3.5 * k, INK)
	ci.draw_polyline(tp, Color("#e4c58c"), 4.6 * k, true)
	for q in tp:
		_circle(ci, q, 2.3 * k, Color("#e4c58c"))
	var seg := PackedVector2Array()
	for j in M.N:
		if M.BR[j]:
			seg.append(o + Vector2(M.PX[j], M.PY[j]) * ms)
		elif seg.size() > 1:
			ci.draw_polyline(seg, WOOD, 4.6 * k)
			seg = PackedVector2Array()
		else:
			seg = PackedVector2Array()
	if seg.size() > 1:
		ci.draw_polyline(seg, WOOD, 4.6 * k)
	# vạch đích ca rô
	var q := 1.6 * k
	var xf := Transform2D(M.TA[0] + PI / 2, o + Vector2(M.PX[0], M.PY[0]) * ms)
	ci.draw_set_transform_matrix(xf)
	for a in range(-2, 2):
		for b in 2:
			ci.draw_rect(Rect2(a * q, (b - 1) * q, q, q), INK if (a + b) & 1 else Color("#fff8e6"))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	_bamboo(ci, Wp, Hp, fr)

func _bamboo(ci: CanvasItem, Wp: float, Hp: float, t: float) -> void:
	var pole := func(x0: float, y0: float, ln: float, vert: bool) -> void:
		ci.draw_set_transform(Vector2(x0, y0), PI / 2 if vert else 0.0, Vector2.ONE)
		var r := Rect2(0, -t / 2, ln, t)
		ci.draw_colored_polygon(A.rrect_pts(r, t / 2), Color("#d4b45a"))
		ci.draw_rect(Rect2(t * 0.5, -t * 0.3, ln - t, t * 0.2), Color("#efd88f"))
		var x := t * 2.4
		while x < ln - t * 1.6:
			for dx in [0.0, t * 0.32]:
				ci.draw_line(Vector2(x + dx, -t / 2 + 0.5), Vector2(x + dx, t / 2 - 0.5), Color("#9a7f33"), maxf(1, t * 0.16))
			x += t * 5.2
		var pp := A.rrect_pts(r, t / 2)
		pp.append(pp[0])
		ci.draw_polyline(pp, INK, maxf(1, t * 0.17), true)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	pole.call(t / 2, 0.0, Hp, true)
	pole.call(Wp - t / 2, 0.0, Hp, true)
	pole.call(0.0, t / 2, Wp, false)
	pole.call(0.0, Hp - t / 2, Wp, false)
	for c in [Vector2(t / 2, t / 2), Vector2(Wp - t / 2, t / 2), Vector2(t / 2, Hp - t / 2), Vector2(Wp - t / 2, Hp - t / 2)]:
		var lw := maxf(1, t * 0.24)
		ci.draw_line(c + Vector2(-t, -t) * 0.7, c + Vector2(t, t) * 0.7, Color("#7a4e22"), lw, true)
		ci.draw_line(c + Vector2(t, -t) * 0.7, c + Vector2(-t, t) * 0.7, Color("#7a4e22"), lw, true)
