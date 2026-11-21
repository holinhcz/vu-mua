extends Control
# CỜ CARO (Menu > Giải trí > "Cờ caro"). Viết hẳn bằng Godot, không có bản web.
# Sân đất + hiên gạch tàu + lu, nón, dép, gà (ảnh của Cờ gánh ui/img/cg), tấm phản gỗ tràm kẻ phấn 15x15
# (ảnh nướng sẵn ui/img/caro/board.webp), quân phấn X xanh / O hồng (mỗi quân 1 file x0..x3, o0..o3).
# Nền + phản vẽ 1 lần (lớp _bg không vẽ lại); quân chỉ vẽ lại khi bàn đổi hoặc lúc có hiệu ứng.
# Đơn vị: css px (nhân K = devicePixelRatio ra điểm ảnh thật), giống Cờ gánh.

signal ended(mode: String, level: int, winner: int)
signal closed

const E := preload("res://logic/caro/caro_engine.gd")
const A := preload("res://logic/cg/cg_art.gd")
const SND := preload("res://logic/cg/cg_snd.gd")
const NEN := preload("res://logic/caro/caro_nen.gd")
var _nen: Node2D = null
const DIR := "res://ui/img/caro/"
const SAVE := "user://cocaro.json"
const N := 15

const OPP := [
	{"k": "ut", "name": "Bé Út", "lvl": "Dễ", "xu": 20},
	{"k": "ti", "name": "Thằng Tí", "lvl": "Vừa", "xu": 50},
	{"k": "hai", "name": "Chị Hai", "lvl": "Khó", "xu": 120},
	{"k": "sau", "name": "Ông Sáu", "lvl": "Cao thủ", "xu": 250},
]
const PCOL := [Color8(60, 120, 200), Color8(200, 80, 106)]          # chữ màu phe X / O
const CARD := Color8(255, 248, 234)
const INK := Color8(70, 42, 24)
const INK2 := Color8(130, 100, 80)
const LINE := Color8(225, 205, 175)
const GOLD := Color8(244, 200, 80)
const DARK := Color8(58, 36, 20)
const DEF := {"first": "me", "block2": 0, "tap2": 1, "sound": 1}

var K := 1.0
var W := 412.0
var H := 915.0
var L := {}                 # bố cục (css)
var BJ := {}                # board.json (px trong ảnh phản)
var tex := {}
var S := DEF.duplicate()
var stats := {"w": [0, 0, 0, 0], "l": [0, 0, 0, 0]}
var Gm := {}
var ov := "menu"            # "", "menu", "rules", "end"
var hits := []              # [Rect2, id] nút đang hiện (vẽ xong mới có)
var snd: Node = null
var reward_txt := ""
var _bg: Control
var _pc: Control
var _hud: Control
var _vs := Vector2.ZERO
var _anim := 0.0            # còn hiệu ứng thì vẽ lại quân mỗi khung
var _clock := 0.0
var _thr: Thread = null
var _ai_tok := 0
var _ai_res := -1
var _ready_ok := false
var _press := ""            # nút đang nhấn (để nhún)

var K0 := 1.0              # dpr của máy; K = K0 * co cho vừa màn (màn nhỏ / thấp thì co cả game lại)

func setup(k: float) -> void:
	K0 = maxf(1.0, k)
	K = K0

# ------------------------------------------------------------ ảnh
# ảnh NÉT: thu ảnh gốc (9px) đúng bằng số điểm ảnh trên màn 1 lần (Lanczos), vẽ 1:1 không mipmap → đường phấn sắc
var _raw := {}
var _crisp := {}
func crisp(name: String, n: Vector2i) -> Texture2D:
	n = Vector2i(maxi(4, n.x), maxi(4, n.y))
	var key := "%s@%dx%d" % [name, n.x, n.y]
	if _crisp.has(key):
		return _crisp[key]
	if not _raw.has(name):
		var r := Image.new()
		r.load_webp_from_buffer(FileAccess.get_file_as_bytes(DIR + name + ".webp"))
		r.convert(Image.FORMAT_RGBA8)
		r.fix_alpha_edges()
		_raw[name] = r
	var im: Image = _raw[name].duplicate()
	while im.get_width() >= n.x * 3 and im.get_height() >= n.y * 3:
		im.shrink_x2()
	im.resize(n.x, n.y, Image.INTERPOLATE_LANCZOS)
	var t := ImageTexture.create_from_image(im)
	_crisp[key] = t
	return t

func img(name: String) -> Texture2D:
	if tex.has(name):
		return tex[name]
	var im := Image.new()
	im.load_webp_from_buffer(FileAccess.get_file_as_bytes(DIR + name + ".webp"))
	im.convert(Image.FORMAT_RGBA8)
	im.fix_alpha_edges()
	im.generate_mipmaps()
	var t := ImageTexture.create_from_image(im)
	tex[name] = t
	return t

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	BJ = JSON.parse_string(FileAccess.get_file_as_string(DIR + "board.json"))
	_load()
	snd = SND.new()
	add_child(snd)
	snd.on = bool(int(S.sound))
	A.build_atlas()
	for n in ["_bg", "_pc", "_hud"]:
		var c := Control.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(c)
		set(n, c)
	_bg.draw.connect(_draw_bg)
	_pc.draw.connect(_draw_pieces)
	_hud.draw.connect(_draw_hud)
	if Gm.is_empty():
		_new_game("ai", 1, false)
	ov = "menu"
	await get_tree().process_frame
	_layout()
	_ready_ok = true

func _exit_tree() -> void:
	_ai_tok += 1
	if _thr != null and _thr.is_started():
		_thr.wait_to_finish()

# ------------------------------------------------------------ lưu
func _load() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if not (d is Dictionary):
		return
	if d.get("set") is Dictionary:
		S.merge(d.set, true)
	if d.get("stats") is Dictionary:
		stats = d.stats
	var g = d.get("game")
	if g is Dictionary and g.get("b") is Array and (g.b as Array).size() == 225 and not bool(g.get("over", true)):
		Gm = g
		Gm.b = PackedInt32Array(g.b)
		Gm.hist = Array(g.hist).map(func(v): return int(v))
		Gm.turn = int(Gm.turn)
		Gm.level = int(Gm.level)
		Gm.undo = int(Gm.undo)
		Gm.wl = []
		Gm.ghost = -1
		Gm.think = false
		Gm.score = Array(Gm.get("score", [0, 0])).map(func(v): return int(v))
		Gm.resume = true

func save() -> void:
	var g := {}
	if not Gm.is_empty():
		g = Gm.duplicate()
		g.b = Array(Gm.b)
		g.erase("wl")
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"set": S, "stats": stats, "game": g}))

# ------------------------------------------------------------ ván
func _new_game(mode: String, level: int, start := true) -> void:
	var first := 1
	var sc := [0, 0]
	if not Gm.is_empty() and Gm.get("mode") == mode and int(Gm.get("level", -1)) == level:
		sc = Gm.get("score", [0, 0])
	if mode == "ai":
		match str(S.first):
			"ai":
				first = 2
			"alt":
				first = 2 if int(Gm.get("first", 2)) == 1 else 1
			_:
				first = 1
	else:
		first = 2 if int(Gm.get("first", 2)) == 1 and Gm.get("mode") == "pvp" else 1
	_ai_tok += 1
	Gm = {"mode": mode, "level": level, "b": E.new_board(), "hist": [], "turn": first, "first": first, "over": false,
		"winner": 0, "wl": [], "ghost": -1, "undo": 3, "think": false, "score": sc, "block2": int(S.block2), "resume": false}
	reward_txt = ""
	if start:
		ov = ""
		save()
		_maybe_ai()
	_redraw_all()

func human_turn() -> bool:
	if Gm.over or ov != "":
		return false
	if Gm.mode == "pvp":
		return true
	return int(Gm.turn) == 1

func play(i: int) -> void:
	var b: PackedInt32Array = Gm.b
	if b[i] != 0 or Gm.over:
		return
	var p: int = Gm.turn
	b[i] = p
	Gm.b = b
	Gm.hist.append(i)
	Gm.ghost = -1
	Gm.born = _clock
	_anim = 0.5
	if snd != null:
		snd.clack(0.6, false)
	var wl := E.win_line(b, i, bool(int(Gm.block2)))
	if wl.size():
		Gm.over = true
		Gm.winner = p
		Gm.wl = wl
		Gm.wt = _clock
		_anim = 2.0
		_finish()
	elif E.full(b):
		Gm.over = true
		Gm.winner = 0
		Gm.wt = _clock
		_finish()
	else:
		Gm.turn = 3 - p
		_maybe_ai()
	save()
	_redraw_all()

func _finish() -> void:
	var w: int = Gm.winner
	if w > 0:
		Gm.score[w - 1] = int(Gm.score[w - 1]) + 1
	if Gm.mode == "ai":
		var lv: int = Gm.level
		if w == 1:
			stats.w[lv] = int(stats.w[lv]) + 1
			if snd != null:
				snd.win()
		elif w == 2:
			stats.l[lv] = int(stats.l[lv]) + 1
			if snd != null:
				snd.lose()
		# xu: chỉ thắng máy (ui_caro trả về reward())
		emit_signal("ended", "ai", lv, 0 if w == 1 else (1 if w == 2 else -1))
	elif snd != null:
		snd.win()
	get_tree().create_timer(1.3).timeout.connect(func():
		if Gm.over:
			ov = "end"
			_redraw_all())

func reward(xu: int, left: int, mx: int) -> void:
	if xu > 0:
		reward_txt = "+" + str(xu) + " xu  ·  hôm nay còn " + str(left) + "/" + str(mx) + " ván có thưởng"
	elif Gm.mode == "ai" and int(Gm.winner) == 1:
		reward_txt = "Hôm nay hết " + str(mx) + " ván có thưởng rồi"
	_hud.queue_redraw()

func undo() -> void:
	if Gm.over or Gm.think or Gm.hist.is_empty():
		return
	var n := 1
	if Gm.mode == "ai":
		if int(Gm.undo) <= 0:
			return
		# lùi tới lượt mình: bỏ nước máy + nước mình
		n = 2 if int(Gm.turn) == 1 else 1
		if Gm.hist.size() < n:
			return
		Gm.undo = int(Gm.undo) - 1
	var b: PackedInt32Array = Gm.b
	for k in n:
		var i: int = Gm.hist.pop_back()
		b[i] = 0
	Gm.b = b
	Gm.turn = 1 if Gm.mode == "ai" else 3 - int(Gm.turn)
	if Gm.mode == "pvp":
		pass
	Gm.ghost = -1
	if snd != null:
		snd.tap()
	save()
	_maybe_ai()
	_redraw_all()

# ------------------------------------------------------------ máy
func _maybe_ai() -> void:
	if Gm.over or Gm.mode != "ai" or int(Gm.turn) != 2:
		return
	Gm.think = true
	_ai_tok += 1
	var tok := _ai_tok
	var b: PackedInt32Array = (Gm.b as PackedInt32Array).duplicate()
	var lv: int = Gm.level
	var seed := randi()
	var web := OS.has_feature("web") or OS.get_processor_count() < 2
	var wait := 0.45 + randf() * 0.35
	await get_tree().create_timer(wait).timeout
	if tok != _ai_tok:
		return
	var mv := -1
	if web:
		mv = E.think(b, 2, lv, seed, 500)
	else:
		if _thr != null and _thr.is_started():
			_thr.wait_to_finish()
		_thr = Thread.new()
		_thr.start(func(): return E.think(b, 2, lv, seed, 1100))
		while _thr.is_alive():
			await get_tree().process_frame
			if not is_inside_tree():
				return
		mv = _thr.wait_to_finish()
		_thr = null
	if tok != _ai_tok or Gm.over:
		return
	Gm.think = false
	if mv >= 0:
		play(mv)

# ------------------------------------------------------------ bố cục
func _layout() -> void:
	var vs := get_viewport_rect().size
	_vs = vs
	# co đều theo khung màn: ngang cần tối thiểu 620 css cao (bảng chọn) + 900 rộng; dọc 360 rộng + 720 cao
	var cw0 := vs.x / K0; var ch0 := vs.y / K0
	if ch0 >= cw0 * 1.15:
		K = K0 * minf(1.0, minf(cw0 / 360.0, ch0 / 720.0))
	else:
		K = K0 * minf(1.0, minf(cw0 / 900.0, ch0 / 620.0))
	W = vs.x / K
	H = vs.y / K
	var port := H >= W * 1.15
	L = {"port": port}
	var safe := 6.0
	L.tools = Rect2(8, 8 + safe, minf(W - 16, 420), 36)
	var face: float
	var fx: float
	var fy: float
	if port:
		var top := 54.0 + safe + 66
		var bot := H - 132
		face = minf(W - 18, bot - top)
		face = maxf(200, face)
		fx = (W - face) / 2
		fy = top + maxf(0, (bot - top - face) * 0.22)
		var cw := minf(240, W - 16)
		L.opp = Rect2(W - 8 - cw, 54 + safe, cw, 58)
		L.me = Rect2(8, fy + face + face * 12 / 392 + 24, cw, 62)
		L.tip = Rect2(8, L.me.end.y + 10, cw, 46)
	else:
		var colw := minf(250, W * 0.34)
		var rw: float = float(BJ.w) / float(BJ.face[2])     # khung gỗ rộng hơn lòng phản
		# bàn cờ LUÔN chính giữa màn (Link): 2 bên chừa đều = cột thẻ người chơi bên trái, cột đồ bên phải
		var side := colw + 20
		face = minf(H - 24, (W - 2 * side) / rw)
		fx = (W - face) / 2
		fy = (H - face - face * 12 / 392) / 2
		L.tools = Rect2(8, 8 + safe, colw, 36)
		L.opp = Rect2(8, 62, colw, 58)
		L.me = Rect2(8, 140, colw, 62)
		L.tip = Rect2(8, 214, colw, 46)
	L.face = Rect2(fx, fy, face, face)
	# ô lưới trên màn (css)
	var kb: float = BJ.kb
	var sc := face / (float(BJ.face[2]) / kb)                 # css màn / css ảnh
	var px := sc / kb                                         # css màn / điểm ảnh ảnh
	L.px = px
	L.bimg = Rect2(fx - float(BJ.face[0]) * px, fy - float(BJ.face[1]) * px, float(BJ.w) * px, float(BJ.h) * px)
	L.gx = fx + (float(BJ.gx0) - float(BJ.face[0])) * px
	L.gy = fy + (float(BJ.gy0) - float(BJ.face[1])) * px
	L.cs = float(BJ.cs) * px
	if _nen == null:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--q="): NEN.Q = float(a.substr(4)); NEN.Q_fixed = true
		_nen = NEN.new()
		_bg.add_child(_nen)
	_nen.scale = Vector2(K, K)
	_crisp.clear()
	_nen.build(L, W, H, crisp("board", Vector2i(roundi(L.bimg.size.x * K), roundi(L.bimg.size.y * K))))
	_redraw_all()

func _redraw_all() -> void:
	if _bg == null:
		return
	_bg.queue_redraw()
	_pc.queue_redraw()
	_hud.queue_redraw()

func cell_center(i: int) -> Vector2:
	return Vector2(L.gx + (i % N + 0.5) * L.cs, L.gy + (i / N + 0.5) * L.cs)

func cell_at(X: Vector2) -> int:
	var cx := int(floor((X.x - L.gx) / L.cs))
	var cy := int(floor((X.y - L.gy) / L.cs))
	if cx < 0 or cy < 0 or cx >= N or cy >= N:
		return -1
	return cy * N + cx

func _process(dt: float) -> void:
	_clock += dt
	if not _ready_ok:
		return
	var vs := get_viewport_rect().size
	if vs != _vs:
		_layout()
	if _anim > 0:
		_anim -= dt
		_pc.queue_redraw()
	if Gm.get("think", false):
		_hud.queue_redraw()   # chấm nghĩ nhấp nháy

# ------------------------------------------------------------ vẽ: nền (1 lần)
func _T(ci: CanvasItem, xf := Transform2D.IDENTITY) -> void:
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2(K, K), 0.0, Vector2.ZERO) * xf)

func _draw_bg() -> void:
	pass   # nền dựng bằng node (caro_nen.gd), không vẽ lại

func _vg(ci: CanvasItem, r: Rect2, c0: Color, c1: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([c0, c0, c1, c1]))

# ------------------------------------------------------------ vẽ: quân
func _piece(ci: CanvasItem, p: int, i: int, a: float, sc := 1.0) -> void:
	var c := cell_center(i)
	var s: float = L.cs * 1.6 * sc
	var name := ("x" if p == 1 else "o") + str((i * 7 + 3) % 4)
	ci.draw_texture_rect(crisp(name, Vector2i(roundi(s * K), roundi(s * K))), Rect2(c.x - s / 2, c.y - s / 2, s, s), false, Color(1, 1, 1, a))

func _draw_pieces() -> void:
	if L.is_empty():
		return
	var ci := _pc
	_T(ci)
	if Gm.is_empty():
		return
	var b: PackedInt32Array = Gm.b
	var last: int = Gm.hist.back() if Gm.hist.size() else -1
	for i in 225:
		if b[i] != 0 and i != last:
			_piece(ci, b[i], i, 1.0)
	if last >= 0:
		var t := clampf((_clock - float(Gm.get("born", -9))) / 0.22, 0, 1)
		# phấn vừa vẽ: hiện dần, hơi to rồi về cỡ
		_piece(ci, b[last], last, t, 1.0 + 0.12 * (1 - t))
		if t < 1:
			var c := cell_center(last)
			for k in 6:
				var ang := k * 1.047 + last
				var d: float = L.cs * (0.3 + 0.5 * t)
				ci.draw_circle(c + Vector2(cos(ang), sin(ang)) * d, L.cs * 0.05 * (1 - t) + 0.3, Color(0.95, 0.93, 0.88, 0.5 * (1 - t)))
		if not Gm.over:
			var s: float = L.cs * 1.6
			var cc := cell_center(last)
			ci.draw_texture_rect(img("ring"), Rect2(cc.x - s / 2, cc.y - s / 2, s, s), false, Color(1, 1, 1, 0.9))
	# ô đang chọn (chạm 2 lần mới đặt)
	var g: int = Gm.ghost
	if g >= 0 and b[g] == 0:
		_piece(ci, Gm.turn, g, 0.45 + 0.1 * sin(_clock * 6))
		_anim = maxf(_anim, 0.05)
	# vệt phấn vàng gạch 5 con
	if Gm.wl.size() >= 5:
		var t := clampf((_clock - float(Gm.get("wt", 0))) / 0.5, 0, 1)
		var p0 := cell_center(Gm.wl[0])
		var p1 := cell_center(Gm.wl[Gm.wl.size() - 1])
		var dv := p1 - p0
		var ext: Vector2 = dv.normalized() * float(L.cs) * 0.45
		p0 -= ext
		p1 = p0 + (dv + ext * 2) * t
		var ln := (p1 - p0).length()
		if ln > 1:
			var th: float = L.cs * 0.7
			_T(ci, Transform2D((p1 - p0).angle(), p0))
			ci.draw_texture_rect(img("line"), Rect2(0, -th / 2, ln, th), false)
			_T(ci)
		if t < 1:
			_anim = maxf(_anim, 0.05)

# ------------------------------------------------------------ vẽ: giao diện
func _font(w := 700) -> Font:
	return A.font(w)

func _text(ci: CanvasItem, p: Vector2, s: String, fs: float, col: Color, w := 700, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	# p = điểm giữa dòng theo chiều dọc (css); vẽ ở điểm ảnh thật cho nét chữ sắc
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	var f := _font(w)
	var px := maxi(1, int(round(fs * K)))
	var asc := f.get_ascent(px)
	var dsc := f.get_descent(px)
	var y := p.y * K + (asc - dsc) / 2
	var x := p.x * K
	var wd := width * K if width > 0 else -1.0
	if align == HORIZONTAL_ALIGNMENT_CENTER and width <= 0:
		x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / 2
	elif align == HORIZONTAL_ALIGNMENT_RIGHT and width <= 0:
		x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	ci.draw_string(f, Vector2(x, y), s, align if width > 0 else HORIZONTAL_ALIGNMENT_LEFT, wd, px, col)
	_T(ci)

func _box(ci: CanvasItem, r: Rect2, bg: Color, rad := 12.0, ring := Color(0, 0, 0, 0), rw := 1.2, shadow := true) -> void:
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	var rr := Rect2(r.position * K, r.size * K)
	var sh := []
	if shadow:
		sh = [[0, 3, 10, Color8(40, 22, 8, 70)]]
	var rg := []
	if ring.a > 0:
		rg = [[rw, ring]]
	A.box(ci, rr, bg, rad, K, [], sh, rg)
	_T(ci)

func _btn(ci: CanvasItem, r: Rect2, id: String, label: String, bg := CARD, fg := INK, fs := 14.0, ring := Color8(232, 214, 186)) -> void:
	var rr := r
	if _press == id:
		rr = Rect2(r.position + r.size * 0.03, r.size * 0.94)
	_box(ci, rr, bg, minf(12, r.size.y / 2), ring, 1.2)
	_text(ci, Vector2(rr.position.x, rr.position.y + rr.size.y / 2), label, fs, fg, 800, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
	hits.append([r, id])

func _avatar(ci: CanvasItem, c: Vector2, k: String, r: float, ring: Color) -> void:
	ci.draw_circle(c, r + 1.5, ring)
	ci.draw_circle(c, r, Color8(250, 240, 220))
	var t := A.svg(A.avatar(k), int(r * 2 * K))
	ci.draw_texture_rect(t, Rect2(c - Vector2(r, r), Vector2(r, r) * 2), false)

func _mini_piece(ci: CanvasItem, c: Vector2, p: int, r: float) -> void:
	_box(ci, Rect2(c - Vector2(r, r), Vector2(r, r) * 2), Color8(62, 48, 38), 7, Color8(120, 90, 60), 1.2, false)
	var s := r * 2.6
	ci.draw_texture_rect(img("x1" if p == 1 else "o2"), Rect2(c - Vector2(s, s) / 2, Vector2(s, s)), false)

func _card(ci: CanvasItem, r: Rect2, side: int) -> void:
	var on: bool = not Gm.over and int(Gm.turn) == side
	var ring := GOLD if on else (Color8(236, 170, 182) if side == 2 else Color8(150, 196, 236))
	_box(ci, r, CARD, 12, ring, 2.6 if on else 1.6)
	var name: String
	var sub: String
	var av: String
	if Gm.mode == "ai":
		if side == 1:
			name = "Bạn"
			av = "me"
			sub = ("Chạm 2 lần để đặt X" if int(S.tap2) else "Chạm 1 ô để đặt X") if on else "cầm X phấn xanh"
		else:
			var o: Dictionary = OPP[int(Gm.level)]
			name = o.name
			av = o.k
			sub = ("Đang nghĩ" + ".".repeat(1 + int(_clock * 3) % 3)) if Gm.think else "Mức " + str(o.lvl).to_lower() + " · cầm O"
	else:
		name = "Người " + str(side)
		av = "me" if side == 1 else "p2"
		sub = ("Tới lượt · đặt " + ("X" if side == 1 else "O")) if on else "cầm " + ("X phấn xanh" if side == 1 else "O phấn hồng")
	_avatar(ci, Vector2(r.position.x + 30, r.position.y + r.size.y / 2), av, 19, ring)
	_mini_piece(ci, Vector2(r.position.x + 44, r.position.y + r.size.y / 2 + 13), side, 7)
	_text(ci, Vector2(r.position.x + 58, r.position.y + r.size.y / 2 - 10), name, 16, INK, 800)
	_text(ci, Vector2(r.position.x + 58, r.position.y + r.size.y / 2 + 11), sub, 11.5, INK2, 600)
	var sx := r.end.x - 32
	ci.draw_line(Vector2(sx - 26, r.position.y + 10), Vector2(sx - 26, r.end.y - 10), LINE, 1.0)
	_text(ci, Vector2(sx, r.position.y + r.size.y / 2 - 6), str(Gm.score[side - 1]), 22, PCOL[side - 1], 800, HORIZONTAL_ALIGNMENT_CENTER)
	_text(ci, Vector2(sx, r.position.y + r.size.y / 2 + 15), "ván", 10, INK2, 600, HORIZONTAL_ALIGNMENT_CENTER)
	if on:
		var tr := Rect2(r.position.x + 62, r.position.y - 9, 62, 17)
		_box(ci, tr, Color8(60, 120, 200), 8, Color(0, 0, 0, 0), 0, false)
		_text(ci, Vector2(tr.position.x, tr.position.y + 8.5), "Tới phiên", 10.5, Color.WHITE, 700, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)

func _draw_hud() -> void:
	if L.is_empty():
		return
	var ci := _hud
	hits = []
	_T(ci)
	if Gm.is_empty():
		return
	# thanh công cụ
	var tr: Rect2 = L.tools
	_box(ci, tr, CARD, 12, Color8(232, 214, 186), 1.2)
	var items := [["menu", "Menu"], ["undo", "Đi lại" + (" " + str(Gm.undo) if Gm.mode == "ai" else "")], ["rules", "Luật"], ["sound", "Âm thanh" if int(S.sound) else "Tắt tiếng"]]
	var bw := tr.size.x / items.size()
	for j in items.size():
		var r := Rect2(tr.position.x + j * bw, tr.position.y, bw, tr.size.y)
		var dim: bool = items[j][0] == "undo" and (Gm.hist.is_empty() or Gm.over or (Gm.mode == "ai" and int(Gm.undo) <= 0))
		_text(ci, Vector2(r.position.x, r.position.y + r.size.y / 2), items[j][1], 12.5, Color8(160, 140, 120) if dim else INK, 700, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		if j > 0:
			ci.draw_line(Vector2(r.position.x, r.position.y + 8), Vector2(r.position.x, r.end.y - 8), LINE, 1.0)
		hits.append([r, items[j][0]])
	_card(ci, L.opp, 2)
	_card(ci, L.me, 1)
	var tp: Rect2 = L.tip
	_box(ci, tp, Color(DARK, 0.93), 12, Color(0, 0, 0, 0), 0)
	var t1 := "5 con liền là thắng"
	var t2 := "ngang, dọc hay chéo đều được"
	if int(Gm.block2):
		t2 = "bị chặn 2 đầu thì không tính"
	if Gm.over:
		t1 = "Hết ván"
		t2 = "Chạm Menu để chơi ván mới"
	_text(ci, Vector2(tp.position.x + 12, tp.position.y + 15), t1, 12.5, Color8(255, 214, 92), 800)
	_text(ci, Vector2(tp.position.x + 12, tp.position.y + 32), t2, 11, Color8(240, 228, 210), 600)
	if ov != "":
		hits = []
		_draw_ov(ci)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# ------------------------------------------------------------ hộp thoại
func _panel(ci: CanvasItem, h: float, low := false) -> Rect2:
	var w := minf(364, W - 24)
	var r := Rect2((W - w) / 2, maxf(12, (H - h) / 2), w, h)
	if low:
		# hết ván: hộp nằm dưới phản cho còn thấy vệt gạch 5 con
		var f: Rect2 = L.face
		if L.port:
			r.position.y = clampf(f.end.y + 18, 12, H - h - 12)
		else:
			r.position.x = maxf(12, f.position.x - w - 16)
		ci.draw_rect(Rect2(0, 0, W, H), Color8(30, 18, 8, 50))
	else:
		ci.draw_rect(Rect2(0, 0, W, H), Color8(30, 18, 8, 120))
	_box(ci, r, CARD, 18, Color8(196, 150, 96), 2.4)
	# khăn rằn trên đầu hộp
	var sr := Rect2(r.position.x + 18, r.position.y + 12, r.size.x - 36, 9)
	var q := 4.5
	var n := int(sr.size.x / q)
	sr.size.x = n * q
	ci.draw_rect(Rect2(sr.position, Vector2(sr.size.x, q * 2)), Color8(245, 240, 230))
	for k in n:
		ci.draw_rect(Rect2(sr.position.x + k * q, sr.position.y + (k % 2) * q, q, q), Color8(40, 30, 26))
	return r

func _draw_ov(ci: CanvasItem) -> void:
	match ov:
		"menu":
			_ov_menu(ci)
		"rules":
			_ov_rules(ci)
		"end":
			_ov_end(ci)

func _ov_menu(ci: CanvasItem) -> void:
	var can_resume: bool = Gm.hist.size() > 0 and not Gm.over
	var h := 540.0 + (48.0 if can_resume else 0.0)
	var r := _panel(ci, h)
	var x := r.position.x + 16
	var w := r.size.x - 32
	var y := r.position.y + 42
	_text(ci, Vector2(r.position.x, y), "Cờ Caro", 26, INK, 800, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	y += 24
	_text(ci, Vector2(r.position.x, y), "Ai xếp đủ 5 con liền trước là thắng", 12, INK2, 600, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	y += 20
	if can_resume:
		_btn(ci, Rect2(x, y, w, 40), "resume", "Chơi tiếp ván đang dở", GOLD, INK, 15, Color8(200, 150, 40))
		y += 48
	_text(ci, Vector2(x, y + 8), "Đánh với máy", 13, INK, 800)
	y += 20
	for j in 4:
		var o: Dictionary = OPP[j]
		var br := Rect2(x, y, w, 46)
		var id := "ai" + str(j)
		var rr := br if _press != id else Rect2(br.position + br.size * 0.02, br.size * 0.96)
		_box(ci, rr, Color8(255, 252, 244), 12, Color8(232, 214, 186), 1.4, false)
		_avatar(ci, Vector2(rr.position.x + 24, rr.position.y + 23), o.k, 16, Color8(232, 214, 186))
		_text(ci, Vector2(rr.position.x + 48, rr.position.y + 15), o.name, 15, INK, 800)
		var wl := "thắng " + str(int(stats.w[j])) + " · thua " + str(int(stats.l[j]))
		_text(ci, Vector2(rr.position.x + 48, rr.position.y + 33), str(o.lvl) + " · " + wl, 11, INK2, 600)
		_text(ci, Vector2(rr.end.x - 12, rr.position.y + 23), "+" + str(o.xu) + " xu", 13, Color8(190, 120, 20), 800, HORIZONTAL_ALIGNMENT_RIGHT)
		hits.append([br, id])
		y += 52
	_btn(ci, Rect2(x, y, w, 40), "pvp", "Hai người chơi chung 1 máy", Color8(255, 252, 244), INK, 14)
	y += 50
	# tuỳ chọn
	var fl := {"me": "Bạn", "ai": "Máy", "alt": "Thay phiên"}
	_opt(ci, Rect2(x, y, w, 30), "opt_first", "Ai đi trước", str(fl.get(str(S.first), "Bạn")))
	y += 34
	_opt(ci, Rect2(x, y, w, 30), "opt_block2", "Chặn 2 đầu không tính", "Bật" if int(S.block2) else "Tắt")
	y += 34
	_opt(ci, Rect2(x, y, w, 30), "opt_tap2", "Chạm 2 lần mới đặt quân", "Bật" if int(S.tap2) else "Tắt")
	y += 40
	var hw := (w - 8) / 2
	_btn(ci, Rect2(x, y, hw, 40), "rules", "Luật chơi", Color8(255, 252, 244), INK, 14)
	_btn(ci, Rect2(x + hw + 8, y, hw, 40), "home", "Về vườn", Color8(120, 170, 90), Color.WHITE, 14, Color8(80, 130, 60))

func _opt(ci: CanvasItem, r: Rect2, id: String, label: String, val: String) -> void:
	_text(ci, Vector2(r.position.x + 2, r.position.y + r.size.y / 2), label, 12.5, INK, 700)
	var vr := Rect2(r.end.x - 96, r.position.y + 2, 96, r.size.y - 4)
	var on := val != "Tắt"
	_box(ci, vr, Color8(250, 226, 160) if on else Color8(236, 226, 210), 13, Color8(214, 184, 120), 1.2, false)
	_text(ci, Vector2(vr.position.x, vr.position.y + vr.size.y / 2), val, 12, INK, 800, HORIZONTAL_ALIGNMENT_CENTER, vr.size.x)
	hits.append([r, id])

func _ov_rules(ci: CanvasItem) -> void:
	var r := _panel(ci, 420)
	var x := r.position.x + 18
	var w := r.size.x - 36
	var y := r.position.y + 42
	_text(ci, Vector2(r.position.x, y), "Luật cờ caro", 22, INK, 800, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	y += 30
	var parts := [
		["Đặt quân", "Hai bên thay phiên chạm 1 ô trống trên phản để vẽ quân: bạn X phấn xanh, bên kia O phấn hồng."],
		["Thắng", "Ai có 5 quân liền nhau trên 1 hàng ngang, dọc hoặc chéo trước là thắng. 6 con trở lên cũng tính."],
		["Chặn 2 đầu", "Nếu bật: 5 con mà 2 đầu đều bị quân bên kia chặn thì không tính thắng."],
		["Mẹo", "Thấy bên kia có 3 con liền còn trống 2 đầu thì chặn liền, để tới 4 là hết đường đỡ."],
		["Xu", "Thắng máy được xu: Bé Út 20, Thằng Tí 50, Chị Hai 120, Ông Sáu 250. Mỗi ngày 5 ván đầu có thưởng."],
	]
	var f := _font(600)
	for pt in parts:
		_text(ci, Vector2(x, y), pt[0], 13.5, Color8(160, 90, 30), 800)
		y += 18
		var lines := _wrap(pt[1], 12, w, f)
		for ln in lines:
			_text(ci, Vector2(x, y), ln, 12, INK, 600)
			y += 17
		y += 6
	_btn(ci, Rect2(r.position.x + r.size.x / 2 - 70, r.end.y - 52, 140, 38), "close", "Đóng", GOLD, INK, 14, Color8(200, 150, 40))

func _wrap(s: String, fs: float, w: float, f: Font) -> Array:
	var px := maxi(1, int(round(fs * K)))
	var out := []
	var cur := ""
	for word in s.split(" "):
		var t := word if cur == "" else cur + " " + word
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w * K and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = t
	if cur != "":
		out.append(cur)
	return out

func _ov_end(ci: CanvasItem) -> void:
	var r := _panel(ci, 250, true)
	var x := r.position.x + 16
	var w := r.size.x - 32
	var y := r.position.y + 50
	var title := "Hòa rồi!"
	var sub := "Kín phản mà chưa ai đủ 5 con"
	var wn: int = Gm.winner
	if Gm.mode == "ai":
		var o: Dictionary = OPP[int(Gm.level)]
		if wn == 1:
			title = "Thắng rồi!"
			sub = "Bạn hạ " + str(o.name) + " sau " + str(Gm.hist.size()) + " nước"
		elif wn == 2:
			title = "Thua rồi..."
			sub = str(o.name) + " xếp đủ 5 con trước"
	elif wn > 0:
		title = "Người " + str(wn) + " thắng!"
		sub = "5 con " + ("X" if wn == 1 else "O") + " liền nhau"
	_text(ci, Vector2(r.position.x, y), title, 26, PCOL[0] if wn == 1 else (PCOL[1] if wn == 2 else INK), 800, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	y += 30
	_text(ci, Vector2(r.position.x, y), sub, 13, INK2, 600, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	y += 26
	if reward_txt != "":
		_text(ci, Vector2(r.position.x, y), reward_txt, 13, Color8(190, 120, 20), 800, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	y += 26
	_btn(ci, Rect2(x, y, w, 42), "again", "Ván mới", GOLD, INK, 15, Color8(200, 150, 40))
	y += 50
	var hw := (w - 8) / 2
	_btn(ci, Rect2(x, y, hw, 38), "menu", "Menu", Color8(255, 252, 244), INK, 14)
	_btn(ci, Rect2(x + hw + 8, y, hw, 38), "home", "Về vườn", Color8(120, 170, 90), Color.WHITE, 14, Color8(80, 130, 60))

# ------------------------------------------------------------ chạm
func _gui_input(ev: InputEvent) -> void:
	if not _ready_ok:
		return
	var pos := Vector2.ZERO
	var down := false
	if ev is InputEventScreenTouch:
		if ev.index != 0:
			return
		pos = ev.position
		down = ev.pressed
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		pos = ev.position
		down = ev.pressed
	else:
		return
	accept_event()
	var X := pos / K
	if down:
		_press = _hit(X)
		if _press != "":
			_hud.queue_redraw()
		return
	var id := _hit(X)
	var was := _press
	_press = ""
	if was != "" or id != "":
		_hud.queue_redraw()
		if id != "" and id == was:
			_do(id)
		return
	if ov == "":
		_tap_board(X)

func _hit(X: Vector2) -> String:
	for j in range(hits.size() - 1, -1, -1):
		if (hits[j][0] as Rect2).has_point(X):
			return hits[j][1]
	return ""

func _tap_board(X: Vector2) -> void:
	if not human_turn() or Gm.think:
		return
	var i := cell_at(X)
	if i < 0 or (Gm.b as PackedInt32Array)[i] != 0:
		return
	if int(S.tap2) and Gm.ghost != i:
		Gm.ghost = i
		if snd != null:
			snd.tap()
		_pc.queue_redraw()
		return
	play(i)

func _do(id: String) -> void:
	if snd != null:
		snd.tap()
	match id:
		"menu":
			ov = "menu"
		"undo":
			undo()
		"rules":
			ov = "rules"
		"close":
			ov = "menu" if Gm.hist.is_empty() and not Gm.over and not Gm.get("started", false) else ""
		"sound":
			S.sound = 0 if int(S.sound) else 1
			snd.on = bool(int(S.sound))
			save()
		"resume":
			ov = ""
			Gm.started = true
			_maybe_ai()
		"pvp":
			_new_game("pvp", 0)
			Gm.started = true
		"again":
			_new_game(Gm.mode, int(Gm.level))
			Gm.started = true
		"home":
			save()
			emit_signal("closed")
			return
		"opt_first":
			var seq := ["me", "ai", "alt"]
			S.first = seq[(seq.find(str(S.first)) + 1) % 3]
			save()
		"opt_block2":
			S.block2 = 0 if int(S.block2) else 1
			save()
		"opt_tap2":
			S.tap2 = 0 if int(S.tap2) else 1
			save()
		_:
			if id.begins_with("ai"):
				_new_game("ai", int(id.substr(2)))
				Gm.started = true
	_redraw_all()

func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		if ov == "":
			ov = "menu"
		elif ov == "rules":
			ov = "menu"
		_redraw_all()

# ------------------------------------------------------------ test (chỉ dùng trong project thử)
func t_state() -> Dictionary:
	return {"ov": ov, "turn": Gm.turn, "hist": Gm.hist.size(), "over": Gm.over, "winner": Gm.winner, "ghost": Gm.ghost, "think": Gm.think}
