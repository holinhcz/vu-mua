extends Control
# TÌM SỐ (trò chơi tuổi học trò): 100 số viết lung tung trên tờ giấy vở ô li, hai bên giành nhau kiếm theo thứ tự
# 1, 2, 3... Ai thấy trước thì khoanh (Bạn mực xanh, đối thủ mực đỏ). Hết 100 số, ai khoanh nhiều hơn thắng.
# Đấu máy: cùng lúc kiếm, máy "thấy" số sau một khoảng thời gian theo mức. Hai người: thay phiên, mỗi lượt 10 giây.
# Viết hẳn bằng Godot (không trang web). Mọi con số bên trong là css px; vẽ ra nhân K.

signal ended(win: bool, level: int)
signal closed

const A := preload("res://logic/cg/cg_art.gd")
const DIR := "res://ui/img/tso/"
const SAVE_PATH := "user://timso.json"

const INK := Color("#3a2412")
const INK2 := Color("#6a4a2c")
const CREAM := Color("#fffaf0")
const LINE := Color("#dcc08a")
const RED2 := Color("#9e3122")
const BRICK := Color("#b5452a")
const BRICK2 := Color("#8a2f1a")
const GOLD := Color("#f2c14e")
const LEAF := Color("#4f8a3a")
const LEAF2 := Color("#2f6b26")
const PC := [Color("#3f8fd0"), Color("#e46f86")]
const PCD := [Color("#2f7fbf"), Color("#c64662")]
const PEN := [Color("#1d3fa8"), Color("#c3202e")]          # mực bút bi xanh / đỏ
const SH := [[0, 2, 0, Color(90 / 255.0, 60 / 255.0, 20 / 255.0, 0.18)], [0, 8, 22, Color(60 / 255.0, 35 / 255.0, 10 / 255.0, 0.22)]]

const OPP := [
	{"k": "ut", "name": "Bé Út", "lvl": "Dễ", "t": [7.0, 12.0]},
	{"k": "ti", "name": "Thằng Tí", "lvl": "Vừa", "t": [4.5, 8.0]},
	{"k": "hai", "name": "Chị Hai", "lvl": "Khó", "t": [3.0, 5.5]},
	{"k": "sau", "name": "Ông Sáu", "lvl": "Cao thủ", "t": [1.8, 3.6]},
]

# hạt chì: chữ bút chì lốm đốm theo điểm ảnh màn hình
const PENCIL := """
shader_type canvas_item;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment(){
  vec4 c = texture(TEXTURE, UV) * COLOR;
  float n = h(floor(FRAGCOORD.xy / 1.4));
  float m = h(floor(FRAGCOORD.xy / 4.0) + 7.0);
  c.a *= 0.55 + 0.35 * n + 0.18 * m;
  c.rgb *= 0.9 + 0.2 * m;
  COLOR = c;
}
"""
# mực bút bi: đậm nhạt theo nét, có chỗ đọng mực
const INKS := """
shader_type canvas_item;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment(){
  vec4 c = texture(TEXTURE, UV) * COLOR;
  float n = h(floor(FRAGCOORD.xy / 1.2));
  c.a *= 0.78 + 0.22 * n;
  COLOR = c;
}
"""

class Lay extends Control:
	var fn: Callable
	func _init(f: Callable = Callable()) -> void:
		fn = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)

var K := 1.0
var W := 412.0
var H := 915.0
var port := true
var clock := 0.0
var _img := {}
var hand: FontFile = null

var l_bg: Lay
var l_num: Lay
var l_ink: Lay
var l_hud: Lay
var inp: Control

# trạng thái ván
var G := {"mode": "ai", "level": 1, "names": ["Bạn", "Thằng Tí"], "av": ["me", "ti"], "nums": [], "owner": [], "cur": 1,
	"score": [0, 0], "turn": 0, "started": false, "over": false, "ai_t": 0.0, "turn_t": 10.0, "lock": 0.0, "count": 100, "lay_port": true}
var paper := Rect2()      # khung giấy (css), xoay quanh tâm
var prot := -0.012
var ink_anim := {}        # số -> [t0]
var toast := {"s": "", "t": -9.0, "c": INK}
var wrong := {"n": 0, "t": -9.0}
var btns := []            # [{r, id}]
var ov := "menu"          # bảng đang mở: menu / rules / end / "" (đang chơi)
var ov_t := 0.0
var cnt_pick := 100       # số lượng số cho ván mới (100 / 50)
var rew := {"xu": -1, "left": 0, "max": 5}
var snd
var S := {"sound": 1}
var _saved = null         # ván dở trong file lưu
var _press := ""

func setup(k: float) -> void:
	K = maxf(1.0, k)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hand = FontFile.new()
	hand.load_dynamic_font("res://ui/font/patrickhand.ttf")
	hand.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	hand.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	l_bg = _lay(_draw_bg)
	l_num = _lay(_draw_nums, PENCIL)
	l_ink = _lay(_draw_ink, INKS)
	l_hud = _lay(_draw_hud)
	inp = Control.new()
	inp.mouse_filter = Control.MOUSE_FILTER_STOP
	inp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inp.gui_input.connect(_input_ev)
	add_child(inp)
	snd = preload("res://logic/tso/tso_snd.gd").new()
	add_child(snd)
	_load()
	snd.on = bool(int(S.get("sound", 1)))
	get_viewport().size_changed.connect(resize)
	await get_tree().process_frame
	resize()
	# tờ giấy phía sau bảng chọn: số mới rải sẵn, chưa chơi
	if _saved is Dictionary:
		_restore(_saved, false)
	else:
		G.nums = gen(100, randi())
		G.lay_port = port
		G.owner = []
		G.owner.resize(101)
		G.owner.fill(-1)
	show_ov("menu")

func _lay(f: Callable, sh := "") -> Lay:
	var l := Lay.new(f)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if sh != "":
		var s := Shader.new()
		s.code = sh
		var m := ShaderMaterial.new()
		m.shader = s
		l.material = m
	add_child(l)
	return l

func img(name: String) -> ImageTexture:
	if _img.has(name):
		return _img[name]
	var im := Image.new()
	im.load_webp_from_buffer(FileAccess.get_file_as_bytes(DIR + name + ".webp"))
	if im.detect_alpha() != Image.ALPHA_NONE:
		im.convert(Image.FORMAT_RGBA8)
		im.fix_alpha_edges()
	im.generate_mipmaps()
	var t := ImageTexture.create_from_image(im)
	_img[name] = t
	return t

# ------------------------------------------------------------ bố cục
func resize() -> void:
	var vs := get_viewport_rect().size
	W = vs.x / K
	H = vs.y / K
	port = H >= W
	var top := 58.0
	var bot := 70.0
	if port:
		paper = Rect2(8, top, W - 16, H - top - bot)
		var asp := 1400.0 / 1900.0
		if paper.size.x / paper.size.y > asp:
			var w := paper.size.y * asp
			paper.position.x += (paper.size.x - w) / 2
			paper.size.x = w
		else:
			var h := paper.size.x / asp
			paper.position.y += (paper.size.y - h) / 2
			paper.size.y = h
	else:
		var side := minf(270.0, W * 0.24)
		paper = Rect2(side, 12, W - side * 2, H - 24)
		var asp := 1900.0 / 1400.0
		if paper.size.x / paper.size.y > asp:
			var w := paper.size.y * asp
			paper.position.x += (paper.size.x - w) / 2
			paper.size.x = w
		else:
			var h := paper.size.x / asp
			paper.position.y += (paper.size.y - h) / 2
			paper.size.y = h
	if G.nums.size() and bool(G.lay_port) != port:
		G.nums = gen(int(G.count), randi())   # máy xoay dọc / ngang: viết lại số cho vừa tờ giấy mới, số đã khoanh giữ nguyên
		_save()
	G.lay_port = port
	for l in [l_bg, l_num, l_ink, l_hud]:
		l.queue_redraw()

# giấy (u,v trong 0..1) -> màn hình css
func p2s(u: float, v: float) -> Vector2:
	var c := paper.get_center()
	return c + Vector2((u - 0.5) * paper.size.x, (v - 0.5) * paper.size.y).rotated(prot)

func s2p(p: Vector2) -> Vector2:
	var c := paper.get_center()
	var d := (p - c).rotated(-prot)
	return Vector2(d.x / paper.size.x + 0.5, d.y / paper.size.y + 0.5)

# ------------------------------------------------------------ rải 100 số
# mỗi số: {n, u, v, fs (theo cạnh ngắn của giấy), rot}. Vùng viết: bên phải lề đỏ.
func gen(count: int, seed: int) -> Array:
	# cỡ số định trước, xếp số to trước; mỗi số thử 400 chỗ, chỗ nào trống thì đặt. Hết chỗ vừa thì lấy chỗ rộng nhất
	# và thu nhỏ số đó cho vừa (không bao giờ thiếu số nào).
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var u0 := 0.165 if port else 0.12
	var ar := paper.size.x / maxf(1.0, paper.size.y)
	var sw := 1.0 if port else ar          # toạ độ theo cạnh ngắn của giấy
	var sh := (1.0 / ar) if port else 1.0
	var sc := clampf(sqrt(100.0 / float(count)), 1.0, 1.3)
	var items := []
	for n in range(1, count + 1):
		items.append({"n": n, "fs": r.randf_range(0.055, 0.086) * sc, "rot": r.randf_range(-0.7, 0.7)})
	var radf := func(n: int, fs: float) -> float:
		var ln := str(n).length()
		return 0.5 * Vector2(fs * (0.42 * ln + 0.12), fs * 0.62).length() * 0.92
	items.sort_custom(func(p, q): return radf.call(p.n, p.fs) > radf.call(q.n, q.fs))
	const GAP := 0.009
	var out := []
	for it in items:
		var rad: float = radf.call(it.n, it.fs)
		var best := Vector3(0, 0, -1e9)    # x, y, khoảng trống
		var placed := false
		for a in 400:
			var x := r.randf_range(u0 * sw + rad, sw - 0.03 - rad)
			var y := r.randf_range(0.03 * sh + rad, sh - 0.03 - rad)
			var clear := 1e9
			for o in out:
				clear = minf(clear, Vector2(x - o.x, y - o.y).length() - o.rad - GAP)
				if clear < rad and clear < best.z:
					break
			if clear >= rad:
				out.append({"n": it.n, "x": x, "y": y, "rad": rad, "fs": it.fs, "rot": it.rot})
				placed = true
				break
			if clear > best.z:
				best = Vector3(x, y, clear)
		if not placed:
			var k := clampf(best.z / rad, 0.55, 1.0)
			out.append({"n": it.n, "x": best.x, "y": best.y, "rad": rad * k, "fs": it.fs * k, "rot": it.rot})
	for o in out:
		o["u"] = o.x / sw
		o["v"] = o.y / sh
	out.sort_custom(func(p, q): return p.n < q.n)
	return out

func new_game(mode: String, level: int, count := 100) -> void:
	G.mode = mode
	G.level = level
	G.count = count
	G.names = ["Bạn", OPP[level].name] if mode == "ai" else ["Người 1", "Người 2"]
	G.av = ["me", OPP[level].k] if mode == "ai" else ["me", "p2"]
	G.nums = gen(count, randi())
	G.lay_port = port
	G.owner = []
	G.owner.resize(count + 1)
	G.owner.fill(-1)
	G.cur = 1
	G.score = [0, 0]
	G.turn = 0
	G.started = true
	G.over = false
	G.lock = 0.0
	ink_anim = {}
	_ai_next()
	G.ai_t += 1.2
	G.turn_t = 10.0
	G.lock = 1.2
	rew = {"xu": -1, "left": 0, "max": 5}
	show_ov("")
	say("Bắt đầu! Kiếm số 1", LEAF2)
	_save()
	resize()

func _ai_next() -> void:
	var t: Array = OPP[G.level].t
	G.ai_t = randf_range(t[0], t[1])

func num_of(n: int) -> Dictionary:
	for o in G.nums:
		if o.n == n:
			return o
	return {}

# ------------------------------------------------------------ chạm
var _down = null
func _input_ev(e: InputEvent) -> void:
	var p = null
	if e is InputEventScreenTouch and e.pressed:
		p = e.position / K
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		p = e.position / K
	if p == null:
		return
	for i in range(btns.size() - 1, -1, -1):
		var b: Dictionary = btns[i]
		if b.r.has_point(p):
			_btn(b.id)
			return
	if ov != "" or not G.started or G.over:
		return
	tap_at(p)

func tap_at(p: Vector2) -> void:
	if G.lock > 0.0:
		return
	if G.mode == "pvp" and G.turn < 0:
		return
	# số nào gần nhất dưới ngón tay (khung số nới ra 6 px)
	var best = null
	var bd := 1e9
	for o in G.nums:
		var c := p2s(o.u, o.v)
		var d := (p - c).rotated(-(prot + o.rot))
		var fs := _fs(o)
		var hw := fs * (0.21 * str(o.n).length() + 0.06) + 6
		var hh := fs * 0.31 + 6
		if absf(d.x) <= hw and absf(d.y) <= hh:
			var dd := d.length()
			if dd < bd:
				bd = dd
				best = o
	if best == null:
		return
	if G.owner[best.n] >= 0:
		return
	var who := 0 if G.mode == "ai" else int(G.turn)
	if best.n == G.cur:
		_take(who)
	else:
		wrong = {"n": best.n, "t": clock}
		G.lock = 0.6
		snd.buzz()
		say("Số %d chưa tới, đang kiếm %d" % [best.n, G.cur], BRICK2)

func _take(who: int) -> void:
	var n: int = G.cur
	G.owner[n] = who
	G.score[who] += 1
	ink_anim[n] = clock
	G.cur += 1
	if G.mode == "ai":
		_ai_next()
	else:
		G.turn = 1 - G.turn
		G.turn_t = 10.0
	snd.scribble()
	var left: int = G.count - G.cur + 1
	if G.cur > G.count or absi(G.score[0] - G.score[1]) > left:
		_finish()
	else:
		_save()
	l_ink.queue_redraw()
	l_hud.queue_redraw()

func winner() -> int:
	return 0 if G.score[0] > G.score[1] else (1 if G.score[1] > G.score[0] else -1)

func _finish() -> void:
	G.over = true
	var w := winner()
	_del_save()
	if G.mode == "ai":
		if w == 0:
			snd.win()
		else:
			snd.lose()
	else:
		snd.win()
	await get_tree().create_timer(0.9).timeout
	show_ov("end")
	if G.mode == "ai":
		ended.emit(w == 0, int(G.level))

func reward(xu: int, left: int, mx: int) -> void:
	rew = {"xu": xu, "left": left, "max": mx}
	l_hud.queue_redraw()

var ov_prev := ""
func show_ov(id: String) -> void:
	if id != ov:
		ov_prev = ov
	ov = id
	ov_t = clock
	l_hud.queue_redraw()

func say(s: String, c := INK) -> void:
	toast = {"s": s, "t": clock, "c": c}

func _btn(id: String) -> void:
	snd.tap()
	if id.begins_with("ai_"):
		new_game("ai", int(id.substr(3)), cnt_pick)
		return
	match id:
		"home":
			_save()
			closed.emit()
		"menu":
			show_ov("menu")
		"rules":
			show_ov("rules")
		"snd":
			S.sound = 0 if int(S.sound) else 1
			snd.on = bool(int(S.sound))
			_save()
		"pvp":
			new_game("pvp", 0, cnt_pick)
		"c100":
			cnt_pick = 100
		"c50":
			cnt_pick = 50
		"resume":
			show_ov("")
			G.lock = 0.8
			if G.mode == "ai":
				G.ai_t = maxf(G.ai_t, 2.0)
		"again":
			new_game(G.mode, int(G.level), int(G.count))
		"back":
			show_ov(ov_prev if ov_prev != "rules" and (ov_prev != "" or playing()) else "menu")
		"x":
			show_ov("")
		"pick":
			show_ov("menu")
	l_hud.queue_redraw()

func playing() -> bool:
	return G.started and not G.over

func _process(dt: float) -> void:
	clock += dt
	if G.started and not G.over and ov == "":
		G.lock = maxf(0.0, G.lock - dt)
		if G.mode == "ai":
			G.ai_t -= dt
			if G.ai_t <= 0.0:
				_take(1)
		else:
			G.turn_t -= dt
			if G.turn_t <= 0.0:
				G.turn = 1 - G.turn
				G.turn_t = 10.0
				say("Hết giờ, tới lượt " + G.names[G.turn])
				snd.buzz()
	l_ink.queue_redraw()
	l_hud.queue_redraw()
	if clock - wrong.t < 0.7:
		l_num.queue_redraw()   # rung + đỏ trong 0.5 giây, vẽ thêm vài khung cho số trở lại màu chì

# ------------------------------------------------------------ vẽ
func _fs(o: Dictionary) -> float:
	return o.fs * minf(paper.size.x, paper.size.y)

func _draw_bg(ci: CanvasItem) -> void:
	var vs := Vector2(W, H) * K
	var t := img("ban")
	var ts := t.get_size()
	var s := maxf(vs.x / ts.x, vs.y / ts.y)
	ci.draw_texture_rect(t, Rect2((vs - ts * s) / 2, ts * s), false)
	# bút + tẩy nằm trên bàn
	if port:
		_prop(ci, "but_do", Vector2(W - 70, 30), 150, -0.18)
	else:
		_prop(ci, "but_do", Vector2(W - 140, H * 0.62), 190, -0.5)
	if port:
		_prop(ci, "tay", Vector2(46, 34), 44, 0.25)
	else:
		_prop(ci, "tay", Vector2(120, H * 0.45), 60, 0.3)
	# bóng giấy + giấy
	var nm := "giay" if port else "giay_ngang"
	var pt := img(nm)
	var sht := img(nm + "_bong")
	var c := paper.get_center() * K
	var sz := paper.size * K
	var pad := 60.0 * sz.x / pt.get_size().x
	ci.draw_set_transform(c + Vector2(2.5, 5) * K, prot, Vector2.ONE)
	ci.draw_texture_rect(sht, Rect2(-sz / 2 - Vector2(pad, pad), sz + Vector2(pad, pad) * 2), false)
	ci.draw_set_transform(c, prot, Vector2.ONE)
	ci.draw_texture_rect(pt, Rect2(-sz / 2, sz), false)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if port:
		_prop(ci, "but_xanh", Vector2(W - 64, H - 26), 150, 0.12)
	else:
		_prop(ci, "but_xanh", Vector2(140, H * 0.78), 190, 0.35)

func _prop(ci: CanvasItem, name: String, at: Vector2, w: float, rot: float) -> void:
	var t := img(name)
	var ts := t.get_size()
	var h := w * ts.y / ts.x
	# bóng đổ mềm (cùng hình, tô tối, lệch theo nắng)
	ci.draw_set_transform((at + Vector2(3, 5)) * K, rot, Vector2.ONE)
	ci.draw_texture_rect(t, Rect2(Vector2(-w, -h) / 2 * K, Vector2(w, h) * K), false, Color(0.1, 0.04, 0.01, 0.35))
	ci.draw_set_transform(at * K, rot, Vector2.ONE)
	ci.draw_texture_rect(t, Rect2(Vector2(-w, -h) / 2 * K, Vector2(w, h) * K), false)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_nums(ci: CanvasItem) -> void:
	var pencil := Color(0.2, 0.2, 0.24, 0.92)
	for o in G.nums:
		var s := str(o.n)
		var fs := _fs(o)
		var fpx := maxi(1, roundi(fs * K))
		var sw := hand.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx)
		var c := p2s(o.u, o.v)
		var rot: float = prot + o.rot
		var col := pencil
		if wrong.n == o.n and clock - wrong.t < 0.5:
			c.x += sin((clock - wrong.t) * 50) * 2.5 * (1.0 - (clock - wrong.t) / 0.5)
			col = Color(0.55, 0.12, 0.1, 0.95)
		ci.draw_set_transform(c * K, rot, Vector2.ONE)
		var asc := hand.get_ascent(fpx)
		# chữ số bút chì: chừng 0.7 cỡ chữ là thân số, canh giữa theo thân
		ci.draw_string(hand, Vector2(-sw.x / 2, asc * 0.5 - fpx * 0.05), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx, col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# vòng khoanh tay: hình bầu dục hơi méo, vẽ quá một chút ở chỗ bắt đầu
func _loop(o: Dictionary, prog: float) -> PackedVector2Array:
	var fs := _fs(o)
	var ln := str(o.n).length()
	var rx := fs * (0.21 * ln + 0.06) + fs * 0.22
	var ry := fs * 0.31 + fs * 0.2
	var h: int = int(o.n) * 7919
	var a0 := float(h % 628) / 100.0
	var sweep := TAU + 0.45
	var pts := PackedVector2Array()
	var steps := 40
	var c := p2s(o.u, o.v)
	var rot: float = prot + o.rot * 0.6 + (float(h % 40) / 100.0 - 0.2)
	for i in steps + 1:
		var t := float(i) / steps * prog
		var a := a0 + sweep * t
		var wob := 1.0 + 0.06 * sin(a * 2.0 + float(h % 13)) + 0.04 * t
		var p := Vector2(cos(a) * rx * wob, sin(a) * ry * wob).rotated(rot)
		pts.append((c + p) * K)
	return pts

func _draw_ink(ci: CanvasItem) -> void:
	for n in range(1, G.cur):
		var w: int = G.owner[n]
		if w < 0:
			continue
		var o := num_of(n)
		if o.is_empty():
			continue
		var prog := 1.0
		if ink_anim.has(n):
			prog = clampf((clock - ink_anim[n]) / 0.35, 0.0, 1.0)
		if prog <= 0.0:
			continue
		var pts := _loop(o, prog)
		var col: Color = PEN[w]
		ci.draw_polyline(pts, Color(col, 0.3), 2.2 * K, true)
		ci.draw_polyline(pts, col, 1.25 * K, true)

# ------------------------------------------------------------ HUD
func box(ci: CanvasItem, r: Rect2, bg: Color, rad: float, bev := [], sh := [], ring := []) -> void:
	A.box(ci, Rect2(r.position * K, r.size * K), bg, rad, K, bev, sh, ring)

func text(ci: CanvasItem, s: String, x: float, top: float, fs: float, w: int, col: Color, lh := 1.2, al := "left", width := 0.0) -> void:
	var f := A.font(w)
	var fpx := maxi(1, roundi(fs * K))
	var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x / K
	var xx := x
	if al == "center":
		xx = x + (width - sw) / 2
	elif al == "right":
		xx = x + width - sw
	var asc := f.get_ascent(fpx) / K
	var dsc := f.get_descent(fpx) / K
	var base := top + (fs * lh - (asc + dsc)) / 2 + asc
	ci.draw_string(f, Vector2(xx, base) * K, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx, col)

func tw(s: String, fs: float, w: int) -> float:
	return A.font(w).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(1, roundi(fs * K))).x / K

func avatar(ci: CanvasItem, k: String, r: Rect2) -> void:
	var t := A.svg(A.avatar(k), roundi(r.size.x * K))
	if t != null:
		ci.draw_texture_rect(t, Rect2(r.position * K, r.size * K), false)

func icon(ci: CanvasItem, k: String, col: Color, r: Rect2) -> void:
	var t := A.icon(k, "#" + col.to_html(false), roundi(r.size.x * K))
	if t != null:
		ci.draw_texture_rect(t, Rect2(r.position * K, r.size * K), false)

func card_rect(p: int) -> Rect2:
	if port:
		var cw := minf(214.0, W - 20 - 104)
		var ow := minf(220.0, W - 10 - 158)
		return Rect2(10, H - 62, cw, 54) if p == 0 else Rect2(W - 10 - ow, 7, ow, 46)
	var cw2 := minf(248.0, paper.position.x - 24)
	return Rect2(12, H - 12 - 70, cw2, 70) if p == 0 else Rect2(W - 12 - cw2, 12, cw2, 70)

func target_rect() -> Rect2:
	if port:
		var c0 := card_rect(0)
		return Rect2(c0.end.x + 8, H - 66, W - 10 - c0.end.x - 8, 58)
	var cw2 := minf(248.0, paper.position.x - 24)
	return Rect2(12, H * 0.5 - 60, cw2, 120)

func _draw_hud(ci: CanvasItem) -> void:
	btns = []
	# thanh nút trên cùng (Về vườn, Menu, Luật, Âm thanh)
	var ids := [["home", "home"], ["menu", "menu"], ["rules", "rules"], ["snd", "snd"]]
	var bw := 36.0
	var tr := Rect2(8, 8, 4 + ids.size() * (bw + 2) + 2, 42)
	if port:
		tr = Rect2(8, 9, 4 + ids.size() * (bw - 2) + 2, 40)
		bw = 34.0
	box(ci, tr, CREAM, 16, [3, Color("#e2cfa6")], SH)
	var x := tr.position.x + 3
	for b in ids:
		var br := Rect2(x, tr.position.y + 2, bw, tr.size.y - 7)
		icon(ci, b[1], LEAF2 if b[0] == "home" else INK, Rect2(br.get_center() - Vector2(10, 10), Vector2(20, 20)))
		btns.append({"r": br, "id": b[0]})
		x += bw
	for p in [0, 1]:
		_card(ci, p)
	_target(ci)
	# chữ báo nhanh
	var age: float = clock - toast.t
	if age < 1.8 and toast.s != "":
		var a := clampf(minf(age / 0.15, (1.8 - age) / 0.3), 0.0, 1.0)
		var fs := 15.0
		var ww := tw(toast.s, fs, 700) + 28
		var r := Rect2((W - ww) / 2, paper.position.y + 14 - (1.0 - a) * 6, ww, 32)
		box(ci, r, Color(0.16, 0.1, 0.05, 0.86 * a), 16)
		text(ci, toast.s, r.position.x, r.position.y, fs, 700, Color(1, 0.97, 0.9, a), 32.0 / fs, "center", ww)

	if ov != "":
		btns = []
		_draw_ov(ci)

func _card(ci: CanvasItem, p: int) -> void:
	var r := card_rect(p)
	var active: bool = G.started and not G.over and (G.mode == "ai" or G.turn == p)
	if G.mode == "pvp" and active:
		box(ci, r.grow(4), Color(GOLD, 0.35), 20)
		box(ci, r.grow(2), GOLD, 18)
	box(ci, r, CREAM, 16, [4, PC[p]], SH)
	var av := r.size.y - 14
	var ar := Rect2(r.position.x + 7, r.position.y + 6, av, av)
	box(ci, ar.grow(2), PC[p], 13)
	box(ci, ar, Color("#f3e3c0"), 11)
	avatar(ci, G.av[p], ar)
	# điểm (số đã khoanh)
	var sc := str(G.score[p])
	var pts := 24.0
	var pw := maxf(44.0, tw(sc, pts, 800) + 10)
	var px := r.end.x - 8 - pw
	var hh := pts * 0.95 + 2 + 10.0
	var my := r.position.y + (r.size.y - 4) / 2
	var yy := my - hh / 2
	while yy < my + hh / 2:
		ci.draw_line(Vector2(px, yy) * K, Vector2(px, minf(yy + 4, my + hh / 2)) * K, LINE, 2 * K)
		yy += 7
	text(ci, sc, px + 6, my - hh / 2 - 1, pts, 800, PEN[p], 0.95, "center", pw - 6)
	text(ci, "số", px + 6, my - hh / 2 + pts * 0.95 + 1, 10.5, 600, INK2, 1.0, "center", pw - 6)
	# tên + tình trạng
	var tx := ar.end.x + 8
	var nm: String = G.names[p]
	var fsn := 15.0
	text(ci, nm, tx, r.position.y + (5.0 if r.size.y < 50 else 8.0), fsn, 800, INK, 1.1)
	var st := ""
	if G.mode == "ai":
		st = "Mức " + String(OPP[G.level].lvl).to_lower() if p == 1 else "mực xanh"
	else:
		st = ("còn %d giây" % ceili(G.turn_t)) if G.turn == p else ("mực xanh" if p == 0 else "mực đỏ")
	text(ci, st, tx, r.position.y + (5.0 if r.size.y < 50 else 8.0) + fsn * 1.1 + 1, 11.5, 600, INK2, 1.2)

func _target(ci: CanvasItem) -> void:
	var r := target_rect()
	box(ci, r, Color("#fff6dc"), 16, [4, Color("#e2c88f")], SH)
	var big := 30.0 if port else 54.0
	var top := r.position.y + (r.size.y - 14 - big * 1.05 - 6) / 2
	text(ci, "Tìm số", r.position.x, top, 11.5 if port else 14.0, 700, INK2, 1.2, "center", r.size.x)
	var n := str(mini(G.cur, G.count)) if not G.over else "✓"
	var pulse := 1.0 + 0.06 * maxf(0.0, 1.0 - fposmod(clock, 1.6) / 0.35)
	var fs := big * pulse
	var f := hand
	var fpx := roundi(fs * K)
	var sw := f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x / K
	ci.draw_string(f, Vector2(r.position.x + (r.size.x - sw) / 2, top + 14 + big * 0.85) * K, n, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx, Color(0.2, 0.2, 0.24))
	# tiến độ: chấm nhỏ dưới đáy
	var done := float(G.cur - 1) / float(G.count)
	var br := Rect2(r.position.x + 10, r.end.y - 9, r.size.x - 20, 3)
	box(ci, br, Color("#ead9b4"), 2)
	box(ci, Rect2(br.position, Vector2(br.size.x * done, br.size.y)), LEAF, 2)

# ------------------------------------------------------------ lưu ván dở (user://timso.json)
func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var j = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (j is Dictionary):
		return
	if j.get("set") is Dictionary:
		S.merge(j.set, true)
	if j.get("g") is Dictionary and j.g.get("nums") is Array:
		_saved = j.g

func _save() -> void:
	var d := {"set": S}
	if playing():
		d["g"] = {"mode": G.mode, "level": G.level, "count": G.count, "nums": G.nums, "owner": G.owner, "cur": G.cur,
			"score": G.score, "turn": G.turn, "port": G.lay_port}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))

func _del_save() -> void:
	_saved = null
	_save()

func _restore(g: Dictionary, start: bool) -> void:
	G.mode = String(g.get("mode", "ai"))
	G.level = clampi(int(g.get("level", 1)), 0, 3)
	G.count = int(g.get("count", 100))
	G.names = ["Bạn", OPP[G.level].name] if G.mode == "ai" else ["Người 1", "Người 2"]
	G.av = ["me", OPP[G.level].k] if G.mode == "ai" else ["me", "p2"]
	G.nums = []
	for o in g.nums:
		G.nums.append({"n": int(o.n), "x": float(o.x), "y": float(o.y), "rad": float(o.rad), "fs": float(o.fs), "rot": float(o.rot), "u": float(o.u), "v": float(o.v)})
	G.lay_port = bool(g.get("port", true))
	G.owner = []
	for v in g.owner:
		G.owner.append(int(v))
	G.cur = int(g.get("cur", 1))
	G.score = [int(g.score[0]), int(g.score[1])]
	G.turn = int(g.get("turn", 0))
	G.started = true
	G.over = false
	_ai_next()
	G.turn_t = 10.0

func has_resume() -> bool:
	return playing()

# ------------------------------------------------------------ bảng phủ: chọn đối thủ, luật, hết ván
const REW := [20, 50, 120, 250]
var _ovs := 1.0
var _ovo := Vector2.ZERO

func _wrap(src: String, fs: float, w: int, maxw: float) -> Array:
	var out := []
	var cur := ""
	for wd in src.split(" ", false):
		var t := wd if cur == "" else cur + " " + wd
		if tw(t, fs, w) > maxw and cur != "":
			out.append(cur)
			cur = wd
		else:
			cur = t
	if cur != "":
		out.append(cur)
	return out

func _ob(ci: CanvasItem, r: Rect2, id: String) -> void:
	# nút trong bảng: lưu khung theo toạ độ màn hình
	btns.append({"r": Rect2(_ovo + r.position * _ovs, r.size * _ovs), "id": id})

func _bbtn(ci: CanvasItem, r: Rect2, lab: String, kind: String, id: String) -> void:
	var bg := BRICK
	var bev := BRICK2
	var col := Color.WHITE
	if kind == "g":
		bg = LEAF; bev = LEAF2
	elif kind == "w":
		bg = Color("#fff3d6"); bev = Color("#e2c88f"); col = INK
	box(ci, r, bg, 14, [4, bev], [[0, 5, 12, Color(0.35, 0.2, 0.05, 0.22)]])
	text(ci, lab, r.position.x, r.position.y, 17, 800, col, (r.size.y - 4) / 17.0, "center", r.size.x)
	_ob(ci, r, id)

func _draw_ov(ci: CanvasItem) -> void:
	var a := clampf((clock - ov_t) / 0.18, 0.0, 1.0)
	ci.draw_rect(Rect2(Vector2.ZERO, Vector2(W, H) * K), Color(0.12, 0.07, 0.02, 0.45 * a))
	var pw := minf(380.0, W - 24)
	var ph := _ov_h(pw)
	_ovs = minf(1.0, (H - 24) / ph)
	_ovo = Vector2((W - pw * _ovs) / 2, (H - ph * _ovs) / 2 + (1.0 - a) * 10)
	var K0 := K
	K = K0 * _ovs
	ci.draw_set_transform(_ovo * K0, 0, Vector2.ONE)
	var r := Rect2(0, 0, pw, ph)
	box(ci, r, CREAM, 22, [5, Color("#e2cfa6")], SH)
	# viền khăn rằn trên đầu bảng
	var n_st := int((pw - 28) / 12)
	var st0 := (pw - n_st * 12) / 2
	for i in n_st:
		var c := Color("#2f4f8f") if i % 2 == 0 else Color("#f4ecd8")
		ci.draw_rect(Rect2(Vector2(st0 + i * 12, 0) * K, Vector2(12, 5) * K), c)
	match ov:
		"menu": _ov_menu(ci, pw)
		"rules": _ov_rules(ci, pw)
		"end": _ov_end(ci, pw)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	K = K0

func _ov_h(pw: float) -> float:
	match ov:
		"menu":
			return 20 + 34 + 22 + 4 * 60 + 60 + 44 + (60 if has_resume() else 0) + 14
		"rules":
			var h := 20 + 34.0 + 10
			for ln in RULES:
				h += _wrap(ln, 14, 600, pw - 64).size() * 19 + 8
			return h + 64
		"end":
			return 20 + 40 + 30 + 90 + 40 + 3 * 56 + 10
	return 200.0

func _x_btn(ci: CanvasItem, pw: float, id: String) -> void:
	var r := Rect2(pw - 46, 12, 34, 34)
	box(ci, r, Color("#f3e3c0"), 17)
	icon(ci, "x", INK, Rect2(r.position + Vector2(8, 8), Vector2(18, 18)))
	_ob(ci, r.grow(6), id)

func _ov_menu(ci: CanvasItem, pw: float) -> void:
	var y := 20.0
	text(ci, "Tìm Số", 0, y, 26, 800, INK, 1.25, "center", pw)
	if has_resume():
		_x_btn(ci, pw, "x")
	y += 34
	text(ci, "Kiếm số theo thứ tự 1, 2, 3… ai khoanh nhiều hơn thắng", 0, y, 12.5, 600, INK2, 1.3, "center", pw)
	y += 22
	for i in 4:
		var o: Dictionary = OPP[i]
		var r := Rect2(16, y + 4, pw - 32, 52)
		box(ci, r, Color("#fff6dc"), 14, [3, Color("#e8d3a6")])
		var ar := Rect2(r.position.x + 6, r.position.y + 5, 40, 40)
		box(ci, ar.grow(2), PC[1], 11)
		box(ci, ar, Color("#f3e3c0"), 9)
		avatar(ci, o.k, ar)
		text(ci, o.name, ar.end.x + 10, r.position.y + 6, 16, 800, INK, 1.1)
		text(ci, "Mức " + String(o.lvl).to_lower() + " · thắng +%d xu" % REW[i], ar.end.x + 10, r.position.y + 28, 12, 600, INK2, 1.2)
		var br := Rect2(r.end.x - 74, r.position.y + 9, 66, 34)
		box(ci, br, LEAF, 12, [3, LEAF2])
		text(ci, "Chơi", br.position.x, br.position.y, 15, 800, Color.WHITE, 31.0 / 15, "center", br.size.x)
		_ob(ci, r, "ai_" + str(i))
		y += 60
	# hai người
	var r2 := Rect2(16, y + 4, pw - 32, 52)
	box(ci, r2, Color("#eef4ff"), 14, [3, Color("#c9d8ef")])
	var a1 := Rect2(r2.position.x + 6, r2.position.y + 5, 40, 40)
	box(ci, a1.grow(2), PC[0], 11)
	box(ci, a1, Color("#f3e3c0"), 9)
	avatar(ci, "p2", a1)
	text(ci, "Hai người chơi", a1.end.x + 10, r2.position.y + 6, 16, 800, INK, 1.1)
	text(ci, "Thay phiên, mỗi lượt 10 giây", a1.end.x + 10, r2.position.y + 28, 12, 600, INK2, 1.2)
	var b2 := Rect2(r2.end.x - 74, r2.position.y + 9, 66, 34)
	box(ci, b2, Color("#3f8fd0"), 12, [3, Color("#2f6fa8")])
	text(ci, "Chơi", b2.position.x, b2.position.y, 15, 800, Color.WHITE, 31.0 / 15, "center", b2.size.x)
	_ob(ci, r2, "pvp")
	y += 60
	# số lượng + luật
	text(ci, "Số lượng:", 18, y + 10, 14, 700, INK, 1.4)
	var cx := 18 + tw("Số lượng:", 14, 700) + 10
	for c in [[100, "c100"], [50, "c50"]]:
		var cr := Rect2(cx, y + 6, 60, 30)
		var on: bool = cnt_pick == c[0]
		box(ci, cr, Color("#e9b949") if on else Color("#f3e3c0"), 15, [2, Color("#b8862a") if on else Color("#dcc59a")])
		text(ci, "%d số" % c[0], cr.position.x, cr.position.y, 13.5, 800 if on else 600, INK, 28.0 / 13.5, "center", cr.size.x)
		_ob(ci, cr, c[1])
		cx += 66
	var lr := Rect2(pw - 16 - 72, y + 6, 72, 30)
	box(ci, lr, Color("#f3e3c0"), 15, [2, Color("#dcc59a")])
	icon(ci, "rules", INK, Rect2(lr.position + Vector2(9, 6), Vector2(18, 18)))
	text(ci, "Luật", lr.position.x + 30, lr.position.y, 13.5, 700, INK, 28.0 / 13.5)
	_ob(ci, lr, "rules")
	y += 44
	if has_resume():
		_bbtn(ci, Rect2(16, y + 6, pw - 32, 46), "Chơi tiếp ván dở (số %d)" % G.cur, "g", "resume")

const RULES := [
	"Trên tờ giấy có 100 số viết lung tung, xoay đủ kiểu.",
	"Kiếm theo thứ tự 1, 2, 3… Ô \"Tìm số\" dưới góc cho biết số đang cần.",
	"Thấy rồi thì chạm vô số đó để khoanh lại. Bạn mực xanh, đối thủ mực đỏ.",
	"Đấu máy: hai bên cùng kiếm một lúc, ai thấy trước thì được số đó. Chạm nhầm số khác thì khựng tay một chút.",
	"Hai người: thay phiên, mỗi lượt 10 giây. Hết giờ thì qua lượt người kia.",
	"Ai khoanh nhiều số hơn thì thắng. Thắng máy được xu, 5 ván đầu mỗi ngày.",
]

func _ov_rules(ci: CanvasItem, pw: float) -> void:
	var y := 20.0
	text(ci, "Luật chơi", 0, y, 24, 800, INK, 1.25, "center", pw)
	_x_btn(ci, pw, "back")
	y += 44
	for i in RULES.size():
		var cr := Vector2(30, y + 9)
		ci.draw_circle(cr * K, 9 * K, Color("#e9b949"), true, -1, true)
		text(ci, str(i + 1), cr.x - 9, cr.y - 9, 12, 800, INK, 18.0 / 12, "center", 18)
		var lines := _wrap(RULES[i], 14, 600, pw - 64)
		for ln in lines:
			text(ci, ln, 46, y, 14, 600, INK, 19.0 / 14)
			y += 19
		y += 8
	_bbtn(ci, Rect2(16, y + 6, pw - 32, 46), "Hiểu rồi", "g", "back")

func _ov_end(ci: CanvasItem, pw: float) -> void:
	var w := winner()
	var y := 22.0
	var title := "Hòa rồi!"
	if G.mode == "ai":
		title = "Bạn thắng rồi nghen!" if w == 0 else (OPP[G.level].name + " thắng rồi!" if w == 1 else title)
	elif w >= 0:
		title = G.names[w] + " thắng!"
	text(ci, title, 0, y, 23, 800, LEAF2 if (w == 0 or G.mode == "pvp") and w >= 0 else INK, 1.3, "center", pw)
	y += 40
	var sub := "Khoanh hết %d số" % G.count if G.cur > G.count else "Số còn lại không đủ gỡ nữa"
	text(ci, sub, 0, y, 13, 600, INK2, 1.3, "center", pw)
	y += 30
	# hai cột điểm
	for p in [0, 1]:
		var cr := Rect2(16 + p * (pw - 32) / 2 + (4 if p else 0), y, (pw - 32) / 2 - 4, 82)
		box(ci, cr, Color("#fff6dc"), 14, [3, PC[p]])
		var ar := Rect2(cr.position.x + 8, cr.position.y + 8, 36, 36)
		box(ci, ar, Color("#f3e3c0"), 9)
		avatar(ci, G.av[p], ar)
		text(ci, G.names[p], ar.end.x + 6, cr.position.y + 14, 14, 800, INK, 1.2)
		var sc := str(G.score[p])
		var f := hand
		var fpx := roundi(36 * K)
		var sw := f.get_string_size(sc, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x / K
		ci.draw_string(f, Vector2(cr.position.x + (cr.size.x - sw) / 2, cr.position.y + 74) * K, sc, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx, PEN[p])
	y += 90
	var rt := ""
	if G.mode == "ai":
		if w != 0:
			rt = "Ván sau gỡ lại nghen"
		elif int(rew.xu) > 0:
			rt = "+%d xu · còn %d ván có thưởng hôm nay" % [int(rew.xu), int(rew.left)]
		elif int(rew.xu) == 0:
			rt = "Hôm nay hết lượt thưởng xu rồi"
	if rt != "":
		text(ci, rt, 0, y + 4, 14, 800, Color("#b8862a") if int(rew.xu) > 0 and w == 0 else INK2, 1.4, "center", pw)
	y += 40
	_bbtn(ci, Rect2(16, y, pw - 32, 46), "Ván mới", "g", "again")
	y += 56
	_bbtn(ci, Rect2(16, y, pw - 32, 46), "Đổi đối thủ", "w", "pick")
	y += 56
	_bbtn(ci, Rect2(16, y, pw - 32, 46), "Về vườn", "w", "home")
