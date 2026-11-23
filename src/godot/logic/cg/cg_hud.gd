extends Control
# CỜ GÁNH: giao diện trên sân (shell.html của bản web): thanh nút góc trên trái, thẻ hai người chơi, bong bóng nói của
# đối thủ, chữ to giữa bàn, hướng dẫn ván đầu, nút tua nhanh, bảng Menu / Luật chơi / Cài đặt / Hết ván.
# Số đo lấy từ CSS của web (css px, nhân K ra điểm ảnh). Chữ Baloo 2.

const A := preload("res://logic/cg/cg_art.gd")
const E := preload("res://logic/cg/cg_engine.gd")

const INK := Color("#3a2412")
const INK2 := Color("#6a4a2c")
const CREAM := Color("#fffaf0")
const LINE := Color("#dcc08a")
const RED := Color("#c9442f")
const RED2 := Color("#9e3122")
const BRICK := Color("#b5452a")
const BRICK2 := Color("#8a2f1a")
const GOLD := Color("#f2c14e")
const LEAF := Color("#4f8a3a")
const LEAF2 := Color("#2f6b26")
const PC := [Color("#3f8fd0"), Color("#e46f86")]
const PCD := [Color("#2f7fbf"), Color("#c64662")]
const SH := [[0, 2, 0, Color(90 / 255.0, 60 / 255.0, 20 / 255.0, 0.18)], [0, 8, 22, Color(60 / 255.0, 35 / 255.0, 10 / 255.0, 0.22)]]

var game   # cg_game
var K := 1.0
var W := 0.0
var H := 0.0
var port := false
var tools: W_ = null
var cards: Array = []
var bub: W_ = null
var toast_w: W_ = null
var quiet: W_ = null
var coach_w: W_ = null
var ff: W_ = null
var ovs := {}
var cur_ov := ""
var back_to := ""
var menu_mode := "ai"
var menu_level := 1
var names_le: Array = []
var _toast := {"txt": "", "cls": "", "t": 9.0}
var _bub := {"txt": "", "t": 9.0, "a": 0.0}
var _ff_on := false
var _ff_a := 0.0
var _end := {}
var _rew = null
var _card_a := [0.86, 0.86]
var _tag_a := [0.0, 0.0]
var _ov_t := 0.0

# ------------------------------------------------------------ một khối vẽ + bấm (thay cho phần tử DOM)
class W_ extends Control:
	var fn_draw: Callable
	var items: Array = []     # [{r: Rect2 (css, local), tap: Callable, id, fx}]
	var K := 1.0
	var scroll := 0.0
	var max_scroll := 0.0
	var on_bg: Callable       # chạm ra ngoài card (lớp phủ)
	var items_only := false   # chỉ bắt chạm trúng nút (khối phủ cả màn để vẽ)
	var ov: Control = null    # khối giữ nút (thân thẻ vẽ, lớp phủ bắt chạm)
	var _press = null
	var _drag := false
	var _y0 := 0.0
	var _s0 := 0.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _draw() -> void:
		if fn_draw.is_valid():
			fn_draw.call(self)
	func pressed_id():
		if ov != null:
			return ov.pressed_id()
		return _press.id if _press != null else null
	func _has_point(p: Vector2) -> bool:
		if not items_only:
			return Rect2(Vector2.ZERO, size).has_point(p)
		return _hit(p / K) != null
	func _hit(p: Vector2):
		for i in range(items.size() - 1, -1, -1):
			var it: Dictionary = items[i]
			var r: Rect2 = it.r
			if it.get("scroll", false):
				r.position.y -= scroll
			if r.grow(4).has_point(p):
				return it
		return null
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
					scroll = clampf(scroll + (-40.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 40.0), 0.0, max_scroll)
					queue_redraw()
				accept_event()
				return
			if e.button_index != MOUSE_BUTTON_LEFT:
				return
			pos = e.position
			kind = "down" if e.pressed else "up"
		elif e is InputEventMouseMotion:
			if _press == null and not _drag:
				return
			pos = e.position
			kind = "move"
		else:
			return
		accept_event()
		var p := pos / K
		if kind == "down":
			_press = _hit(p)
			_drag = false
			_y0 = p.y
			_s0 = scroll
			queue_redraw()
		elif kind == "move":
			if max_scroll > 0 and absf(p.y - _y0) > 8:
				_drag = true
				_press = null
			if _drag:
				scroll = clampf(_s0 - (p.y - _y0), 0.0, max_scroll)
				queue_redraw()
		else:
			var it = _press
			_press = null
			queue_redraw()
			if _drag:
				_drag = false
				return
			var h = _hit(p)
			if it != null and h == it and it.tap.is_valid():
				it.tap.call()
			elif it == null and h == null and on_bg.is_valid():
				on_bg.call()

# ------------------------------------------------------------ chữ
func fnt(w: int) -> Font:
	return A.font(w)

func tw(s: String, fs: float, w: int) -> float:
	return fnt(w).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(1, roundi(fs * K))).x / K

func base_y(top: float, fs: float, lh: float, w: int) -> float:
	# đường chân chữ của một dòng css (line-height lh): vùng chữ (ascent + descent) nằm giữa dòng
	var f := fnt(w)
	var n := maxi(1, roundi(fs * K))
	var a := f.get_ascent(n) / K
	var d := f.get_descent(n) / K
	return top + (fs * lh - (a + d)) / 2 + a

func text(ci: CanvasItem, s: String, x: float, top: float, fs: float, w: int, col: Color, lh := 1.2, al := "left", width := 0.0) -> void:
	var f := fnt(w)
	var n := maxi(1, roundi(fs * K))
	var tx := x
	if al != "left":
		var ww := tw(s, fs, w)
		tx = x + (width - ww) * (0.5 if al == "center" else 1.0)
	ci.draw_string(f, Vector2(tx, base_y(top, fs, lh, w)) * K, s, HORIZONTAL_ALIGNMENT_LEFT, -1, n, col)

func ellip(s: String, fs: float, w: int, maxw: float) -> String:
	if tw(s, fs, w) <= maxw:
		return s
	while s.length() > 1 and tw(s + "…", fs, w) > maxw:
		s = s.substr(0, s.length() - 1)
	return s + "…"

# chữ nhiều dòng, **đậm**. Một dòng = các từ; một từ = các đoạn [chữ, đậm] dính liền (dấu câu sau chữ đậm không bị tách)
func _words(src: String) -> Array:
	var out := []
	var bold := false
	for wd in src.split(" ", false):
		var segs := []
		var parts := wd.split("**")
		for i in parts.size():
			if i > 0:
				bold = not bold
			if parts[i] != "":
				segs.append([parts[i], bold])
		if segs.size():
			out.append(segs)
	return out

func _ww(wd: Array, fs: float, w0: int, w1: int) -> float:
	var x := 0.0
	for sg in wd:
		x += tw(sg[0], fs, w1 if sg[1] else w0)
	return x

func wrapt(src: String, fs: float, w0: int, w1: int, maxw: float) -> Array:
	var lines := []
	var cur := []
	var cw := 0.0
	var sp := tw(" ", fs, w0)
	for wd in _words(src):
		var ww := _ww(wd, fs, w0, w1)
		if cur.size() and cw + sp + ww > maxw:
			lines.append(cur)
			cur = []
			cw = 0.0
		cw += (sp if cur.size() else 0.0) + ww
		cur.append(wd)
	if cur.size():
		lines.append(cur)
	return lines

func line_w(ln: Array, fs: float, w0: int, w1: int) -> float:
	var x := 0.0
	var sp := tw(" ", fs, w0)
	for i in ln.size():
		x += (sp if i else 0.0) + _ww(ln[i], fs, w0, w1)
	return x

func line_s(ln: Array) -> String:
	return " ".join(ln.map(func(wd): return "".join(wd.map(func(sg): return sg[0]))))

func draw_lines(ci: CanvasItem, lines: Array, x: float, top: float, fs: float, lh: float, w0: int, w1: int, col: Color, col_b := Color(0, 0, 0, 0), al := "left", width := 0.0) -> float:
	var sp := tw(" ", fs, w0)
	var y := top
	for ln in lines:
		var xx := x
		if al == "center":
			xx = x + (width - line_w(ln, fs, w0, w1)) / 2
		for i in ln.size():
			if i:
				xx += sp
			for sg in ln[i]:
				var b: bool = sg[1]
				text(ci, sg[0], xx, y, fs, w1 if b else w0, (col_b if col_b.a > 0 else col) if b else col, lh)
				xx += tw(sg[0], fs, w1 if b else w0)
		y += fs * lh
	return y

func box(ci: CanvasItem, r: Rect2, bg: Color, rad: float, bev := [], sh := [], ring := []) -> void:
	A.box(ci, Rect2(r.position * K, r.size * K), bg, rad, K, bev, sh, ring)

func ring_in(ci: CanvasItem, r: Rect2, rad: float, w: float, col: Color) -> void:
	# box-shadow: inset 0 0 0 w col
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(maxi(1, roundi(w * K)))
	sb.border_color = col
	sb.set_corner_radius_all(int(rad * K))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, Rect2(r.position * K, r.size * K))

func pk(ci: CanvasItem, k: int, r: Rect2) -> void:
	var qt := A.quan(k, 3 if k else 1)
	ci.draw_texture_rect(qt, Rect2((r.position + Vector2(0, 1)) * K, r.size * K), false, Color(0.24, 0.12, 0.04, 0.35))
	ci.draw_texture_rect(qt, Rect2(r.position * K, r.size * K), false)

func avatar(ci: CanvasItem, k: String, r: Rect2) -> void:
	var t := A.svg(A.avatar(k), roundi(r.size.x * K))
	if t != null:
		ci.draw_texture_rect(t, Rect2(r.position * K, r.size * K), false)

func icon(ci: CanvasItem, k: String, col: Color, r: Rect2) -> void:
	var t := A.icon(k, "#" + col.to_html(false), roundi(r.size.x * K))
	if t != null:
		ci.draw_texture_rect(t, Rect2(r.position * K, r.size * K), false, Color(1, 1, 1, col.a))

func mk() -> W_:
	var w := W_.new()
	w.K = K
	add_child(w)
	return w

# ============================================================ dựng
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	K = game.K
	menu_level = int(game.store.get("cg-lvl", 1))
	cards = [mk(), mk()]
	for p in [0, 1]:
		var c: W_ = cards[p]
		c.fn_draw = _draw_card.bind(p)
	tools = mk()
	tools.mouse_filter = Control.MOUSE_FILTER_STOP
	tools.fn_draw = _draw_tools
	bub = mk()
	bub.fn_draw = _draw_bub
	quiet = mk()
	quiet.fn_draw = _draw_quiet
	coach_w = mk()
	coach_w.items_only = true
	coach_w.fn_draw = _draw_coach
	ff = mk()
	ff.items_only = true
	ff.fn_draw = _draw_ff
	toast_w = mk()
	toast_w.fn_draw = _draw_toast
	for id in ["menu", "rules", "settings", "end"]:
		var o := mk()
		o.visible = false
		o.mouse_filter = Control.MOUSE_FILTER_STOP
		o.fn_draw = _draw_ov.bind(id)
		o.on_bg = _ov_bg.bind(id)
		var b := W_.new()
		b.K = K
		b.ov = o
		b.clip_contents = true
		b.fn_draw = _draw_body.bind(id)
		o.add_child(b)
		o.set_meta("body", b)
		ovs[id] = o
	for p in [0, 1]:
		var le := LineEdit.new()
		le.max_length = 14
		le.placeholder_text = "Người 1 (sỏi trắng)" if p == 0 else "Người 2 (miểng gạch)"
		le.text = String(game.store.get("cg-n" + str(p), ""))
		le.mouse_filter = Control.MOUSE_FILTER_IGNORE
		le.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		le.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		le.add_theme_font_override("font", fnt(600))
		le.add_theme_font_size_override("font_size", roundi(15 * K))
		le.add_theme_color_override("font_color", INK)
		le.add_theme_color_override("font_placeholder_color", Color(INK2, 0.6))
		le.add_theme_color_override("caret_color", INK)
		le.focus_entered.connect(func(): ovs.menu.queue_redraw())
		le.focus_exited.connect(func(): ovs.menu.queue_redraw())
		le.visible = false
		ovs.menu.get_meta("body").add_child(le)
		names_le.append(le)

func any_open() -> bool:
	return cur_ov != ""

# ------------------------------------------------------------ khổ màn hình
var tb_h := 40.0
var tb_min := 40.0
var tb_pad := 10.0
var tb_ico := 21.0
var tb_lab := false
var tb_btns := []    # [{k, ico, lab, x, w}]
var pcm := {}

func layout(w: float, h: float, pt: bool) -> void:
	W = w
	H = h
	port = pt
	K = game.K
	for c in get_children():
		if c is W_:
			c.K = K
			for d in c.get_children():
				if d is W_:
					d.K = K
	# thanh nút
	tb_lab = W >= 1100
	tb_h = 40.0; tb_min = 40.0; tb_pad = 10.0 if tb_lab else 9.0; tb_ico = 21.0
	if W <= 520:
		tb_h = 36.0; tb_min = 36.0; tb_pad = 7.0
	if H <= 430:
		tb_h = 34.0; tb_min = 34.0; tb_pad = 7.0; tb_ico = 19.0
	var lst := [["home", "home", "Về vườn"], ["menu", "menu", "Menu"], ["undo", "undo", "Đi lại"], ["rules", "rules", "Luật"], ["set", "set", "Cài đặt"], ["snd", "snd", "Âm thanh"]]
	tb_btns = []
	var x := 4.0
	for b in lst:
		if port and W <= 520 and (b[0] == "rules" or b[0] == "set"):
			continue
		var bw := tb_pad * 2 + tb_ico
		if tb_lab:
			bw += 6 + tw(b[2], 13.5, 700)
			if b[0] == "undo" and game.Gm.mode == "ai" and game.Gm.started:
				bw += 6 + 15 - 2
		bw = maxf(tb_min, bw)
		tb_btns.append({"k": b[0], "ico": b[1], "lab": b[2], "x": x, "w": bw})
		x += bw + 2
	var tw_ := x - 2 + 4
	tools.position = Vector2(10, 10) * K
	tools.size = Vector2(tw_, tb_h + 8) * K
	tools.items = []
	for b in tb_btns:
		tools.items.append({"r": Rect2(b.x, 4, b.w, tb_h), "tap": _tool.bind(b.k), "id": b.k})
	# thẻ người chơi
	var big := W >= 1100 and H >= 700
	pcm = {"w": 248.0, "pad": [7.0, 14.0, 7.0, 7.0], "gap": 10.0, "av": 50.0, "avr": 14.0, "nm": 18.0, "st": 12.0, "br": 11.5, "pts": 28.0, "small": 11.0, "rad": 18.0, "brs": true, "tagx": 64.0, "tagf": 11.0}
	if big:
		pcm.merge({"w": 300.0, "pad": [9.0, 16.0, 9.0, 9.0], "gap": 12.0, "av": 62.0, "avr": 16.0, "nm": 22.0, "st": 13.5, "br": 12.5, "pts": 36.0, "small": 12.0, "rad": 20.0, "tagx": 78.0, "tagf": 12.0}, true)
	if W <= 520:
		pcm.merge({"w": 214.0, "pad": [6.0, 10.0, 6.0, 6.0], "gap": 8.0, "av": 50.0, "avr": 12.0, "nm": 16.0, "pts": 24.0, "rad": 16.0}, true)
	if H <= 430:
		pcm.merge({"w": 206.0, "pad": [5.0, 10.0, 5.0, 5.0], "gap": 8.0, "av": 46.0, "avr": 11.0, "nm": 15.0, "st": 11.0, "pts": 22.0, "rad": 15.0, "brs": false}, true)
	for p in [0, 1]:
		var cw: float = minf(pcm.w, W - 20)
		if p == 1 and W <= 520:
			cw = minf(cw, W - 150)
		var pad: Array = pcm.pad.duplicate()
		if p == 1 and W <= 520:
			pad[0] = 13.0
		var txh: float = pcm.nm * 1.05 + 2 + 2 + pcm.st * 1.25 + (4 + 12 if pcm.brs else 0.0)
		var ch: float = pad[0] + pad[2] + maxf(pcm.av, txh)
		var r := Rect2(10, H - 10 - ch, cw, ch) if p == 0 else Rect2(W - 10 - cw, 10, cw, ch)
		var c: W_ = cards[p]
		c.set_meta("pad", pad)
		c.set_meta("r", r)
		c.position = (r.position - Vector2(12, 12)) * K
		c.size = (r.size + Vector2(24, 24)) * K
	ff.size = Vector2(W, H) * K
	quiet.size = Vector2(W, H) * K
	toast_w.size = Vector2(W, H) * K
	bub.size = Vector2(W, H) * K
	coach_w.size = Vector2(W, H) * K
	for id in ovs:
		ovs[id].size = Vector2(W, H) * K
	_lay_all()

func card_rect(p: int) -> Rect2:
	return cards[p].get_meta("r")

func tools_rect() -> Rect2:
	return Rect2(10, 10, tools.size.x / K, tools.size.y / K)

func _tool(k: String) -> void:
	var g = game
	if k == "home":
		g.go_home()
	elif k == "menu":
		build_menu()
		show_ov("menu")
	elif k == "undo":
		g.undo()
	elif k == "rules":
		show_ov("rules")
	elif k == "set":
		show_ov("settings")
	elif k == "snd":
		g.S.sound = 0 if int(g.S.sound) else 1
		g.store_set("cg-set-v1", g.S)
		g.snd.on = bool(int(g.S.sound))
		if g.snd.on:
			g.snd.sel()
		tools.queue_redraw()

func undo_ok() -> bool:
	var g = game
	var Gm: Dictionary = g.Gm
	return Gm.hist.size() > 0 and not Gm.busy and Gm.s != null and not Gm.s.over and g.is_human(Gm.s.turn) and (Gm.mode != "ai" or Gm.undoLeft > 0)

func _draw_tools(ci: W_) -> void:
	var r := Rect2(0, 0, ci.size.x / K, ci.size.y / K)
	box(ci, r, CREAM, 16, [3, Color("#e2cfa6")], SH)
	var pid = ci.pressed_id()
	for b in tb_btns:
		var br := Rect2(b.x, 4, b.w, tb_h)
		var dis: bool = b.k == "undo" and not undo_ok()
		if pid == b.k and not dis:
			box(ci, br, Color("#efdcb2"), 12)
		var col := Color("#b8a27e") if dis else (LEAF2 if b.k == "home" else INK)
		var ico: String = b.ico
		if b.k == "snd" and not int(game.S.sound):
			ico = "mute"
		var iw := tb_ico
		var cx := br.position.x + tb_pad
		if not tb_lab:
			cx = br.position.x + (br.size.x - iw) / 2
		icon(ci, ico, col, Rect2(cx, br.position.y + (tb_h - iw) / 2, iw, iw))
		if tb_lab:
			text(ci, b.lab, cx + iw + 6, br.position.y, 13.5, 700, col, tb_h / 13.5)
		if b.k == "undo" and game.Gm.mode == "ai" and game.Gm.started:
			var n := str(game.Gm.undoLeft)
			var bw := maxf(15.0, tw(n, 10, 700) + 6)
			var bx: float = (cx + iw + 6 + tw(b.lab, 13.5, 700) + 6 - 2) if tb_lab else (br.end.x - 1 - bw)
			var by: float = (br.position.y + (tb_h - 15) / 2) if tb_lab else br.position.y + 2
			box(ci, Rect2(bx, by, bw, 15), Color("#c9b48e") if dis else RED, 8)
			text(ci, n, bx, by, 10, 700, Color.WHITE, 1.5, "center", bw)

# ------------------------------------------------------------ thẻ người chơi
func setup_cards() -> void:
	layout(W, H, port)
	update_cards()

func _status(p: int) -> String:
	var g = game
	var Gm: Dictionary = g.Gm
	var turn: bool = Gm.s != null and not Gm.s.over and Gm.s.turn == p and Gm.started
	if Gm.s != null and Gm.s.over:
		return "Hết ván"
	if turn:
		if not g.is_human(p):
			return "@dots" if Gm.aiWaiting else "đang đi…"
		if Gm.busy:
			return "đang đi…"
		if E.forced(Gm.s, Gm.R) != null:
			return "@mo"
		return "Chọn chỗ đi" if Gm.sel >= 0 else ("Chọn quân" if W < 480 else "Chọn một quân")
	if Gm.mode == "ai" and p == 1:
		return "Mức " + String(g.OPP[Gm.level].lvl).to_lower()
	return "Bên dưới" if p == 0 else "Bên trên"

func _draw_card(ci: W_, p: int) -> void:
	var g = game
	var Gm: Dictionary = g.Gm
	var v = Gm.s if Gm.s != null else Gm.demo
	if v == null:
		return
	var r0: Rect2 = ci.get_meta("r")
	var r := Rect2(Vector2(12, 12), r0.size)
	var pad: Array = ci.get_meta("pad")
	var turn: bool = Gm.s != null and not Gm.s.over and Gm.s.turn == p and Gm.started
	ci.modulate.a = _card_a[p]
	var ringl := [[6, Color(GOLD, 0.35)], [3, GOLD]] if turn else []
	if ringl.size():
		box(ci, r.grow(6), Color(0, 0, 0, 0), pcm.rad + 6, [], SH)
		box(ci, r.grow(6), Color(GOLD, 0.35), pcm.rad + 6)
		box(ci, r.grow(3), GOLD, pcm.rad + 3)
		box(ci, r, CREAM, pcm.rad, [4, PC[p]])
	else:
		box(ci, r, CREAM, pcm.rad, [4, PC[p]], SH)
	# chân dung
	var av: float = pcm.av
	var ar := Rect2(r.position.x + pad[3], r.position.y + (r.size.y - av) / 2 if pad[0] == pad[2] else r.position.y + pad[0] + (r.size.y - pad[0] - pad[2] - av) / 2, av, av)
	box(ci, ar.grow(2.5), PC[p], pcm.avr + 2.5)
	box(ci, ar, Color("#f3e3c0"), pcm.avr)
	avatar(ci, Gm.av[p], ar)
	# ô điểm bên phải
	var ptsw := maxf(52.0, tw(str(E.count(v.b, p)), pcm.pts, 800) + 10)
	ptsw = maxf(ptsw, tw("quân", pcm.small, 600) + 10)
	var px: float = r.end.x - pad[1] - ptsw
	var midy: float = r.position.y + pad[0] + (r.size.y - pad[0] - pad[2]) / 2
	var hh: float = pcm.pts * 0.95 + 3 + pcm.small
	var dash_y: float = midy - hh / 2 - 2
	var yy := dash_y
	while yy < midy + hh / 2 + 2:
		ci.draw_line(Vector2(px, yy) * K, Vector2(px, minf(yy + 4, midy + hh / 2 + 2)) * K, LINE, 2 * K)
		yy += 7
	text(ci, str(E.count(v.b, p)), px + 10, midy - hh / 2, pcm.pts, 800, RED2, 0.95, "center", ptsw - 10)
	text(ci, "quân", px + 10, midy - hh / 2 + pcm.pts * 0.95 + 3, pcm.small, 600, INK2, 1.0, "center", ptsw - 10)
	# chữ giữa
	var tx: float = ar.end.x + pcm.gap
	var tww: float = px - pcm.gap - tx
	var txh: float = pcm.nm * 1.05 + 2 + 2 + pcm.st * 1.25 + (16.0 if pcm.brs else 0.0)
	var ty: float = r.position.y + pad[0] + (r.size.y - pad[0] - pad[2] - txh) / 2
	text(ci, ellip(Gm.names[p], pcm.nm, 800, tww), tx, ty + 2, pcm.nm, 800, INK, 1.05)
	ty += pcm.nm * 1.05 + 2 + 2
	var st := _status(p)
	if st == "@dots":
		for k in 3:
			var a := 0.25 + 0.75 * maxf(0.0, 1.0 - absf(fposmod(g.clock - k * 0.15, 1.0) - 0.4) / 0.4)
			ci.draw_circle(Vector2(tx + 3.5 + k * 7, ty + pcm.st * 1.25 / 2 + 1) * K, 2.5 * K, Color(INK2, a), true, -1.0, true)
		text(ci, " đang tính", tx + 21, ty, pcm.st, 600, INK2, 1.25)
	elif st == "@mo":
		text(ci, ellip("Bị mở, phải gánh!", pcm.st, 800, tww), tx, ty, pcm.st, 800, BRICK2, 1.25)
	else:
		text(ci, ellip(st, pcm.st, 600, tww), tx, ty, pcm.st, 600, INK2, 1.25)
	ty += pcm.st * 1.25
	if pcm.brs:
		ty += 4
		pk(ci, p, Rect2(tx, ty + (12 - 15) / 2.0, 15, 15))
		var bx := tx + 15 + 5
		text(ci, g.KIND[p], bx, ty, pcm.br, 600, INK2, 12.0 / pcm.br)
		bx += tw(g.KIND[p], pcm.br, 600) + 5
		if v.has("ganh") and (int(v.ganh[p]) or int(v.vay[p])):
			text(ci, "·", bx, ty, pcm.br, 600, INK2, 12.0 / pcm.br)
			bx += tw("·", pcm.br, 600) + 5
			text(ci, "ăn %d" % int(v.took[p]), bx, ty, pcm.br, 600, INK2, 12.0 / pcm.br)
	# nhãn "Tới phiên"
	if _tag_a[p] > 0.01:
		var tg := "Tới phiên"
		var tgw := tw(tg, pcm.tagf, 700) + 18
		var tgh: float = pcm.tagf + 8
		var tgy: float = r.position.y - 10 if p == 0 or W <= 520 else r.end.y - tgh + 10
		if p == 1 and W <= 520:
			tgy = r.position.y - 8
		var off: float = (1.0 - _tag_a[p]) * 4
		var trc := Rect2(r.position.x + pcm.tagx, tgy + off, tgw, tgh)
		box(ci, trc.grow(0), Color(PCD[p], _tag_a[p]), 99, [], [[0, 2, 0, Color(0, 0, 0, 0.25 * _tag_a[p])]])
		text(ci, tg, trc.position.x, trc.position.y, pcm.tagf, 700, Color(1, 1, 1, _tag_a[p]), tgh / pcm.tagf, "center", tgw)

func update_cards() -> void:
	for c in cards:
		c.queue_redraw()
	tools.queue_redraw()
	quiet.queue_redraw()
	coach_w.queue_redraw()
	_lay_coach()

# ------------------------------------------------------------ chữ to giữa bàn, bong bóng nói, tua nhanh, "còn N lượt"
func toast(txt: String, cls := "") -> void:
	_toast = {"txt": txt, "cls": cls, "t": 0.0}

func _draw_toast(ci: W_) -> void:
	var t: float = _toast.t
	if t >= 1.7 or _toast.txt == "":
		return
	var vmin := minf(W, H)
	var fs := clampf(vmin * 0.054, 26, 52)
	var col := Color("#fff8e6")
	var oc := Color("#7a3c18")
	if _toast.cls == "big":
		fs = clampf(vmin * 0.09, 38, 86)
		col = Color("#ffe27a")
	elif _toast.cls == "soft":
		fs = clampf(vmin * 0.036, 18, 30)
		col = Color.WHITE
		oc = Color(60 / 255.0, 30 / 255.0, 10 / 255.0, 0.85)
	# keyframes tin 1.6s
	var k := t / 1.6
	var op := 1.0
	var sc := 1.0
	var dy := 0.0
	if k < 0.14:
		var e := k / 0.14
		op = e
		sc = lerpf(0.6, 1.08, _ease(e))
	elif k < 0.24:
		sc = lerpf(1.08, 1.0, (k - 0.14) / 0.1)
	elif k > 0.78:
		var e2 := minf(1.0, (k - 0.78) / 0.22)
		op = 1.0 - e2
		dy = -14 * e2
	var f := fnt(800)
	var n := maxi(1, roundi(fs * sc * K))
	var lines := [_toast.txt]
	var maxw := W * 0.9
	if tw(_toast.txt, fs, 800) > maxw:
		lines = []
		for ln in wrapt(_toast.txt, fs, 800, 800, maxw):
			lines.append(line_s(ln))
	var y0 := H / 2 - lines.size() * fs / 2 + dy
	for i in lines.size():
		var s: String = lines[i]
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, n).x
		var asc := f.get_ascent(n)
		var dsc := f.get_descent(n)
		var cy := (y0 + fs * (i + 0.5)) * K
		var pos := Vector2(W / 2 * K - w / 2, cy + (asc - dsc) / 2)
		ci.draw_string_outline(f, pos + Vector2(0, (6 if _toast.cls != "soft" else 4) * K), s, HORIZONTAL_ALIGNMENT_LEFT, -1, n, roundi(6 * K), Color(0.157, 0.078, 0, 0.25 * op))
		ci.draw_string_outline(f, pos + Vector2(0, (3 if _toast.cls != "soft" else 2) * K), s, HORIZONTAL_ALIGNMENT_LEFT, -1, n, roundi(4 * K), Color(oc, oc.a * op))
		ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, n, roundi(4 * K), Color(oc, oc.a * op))
		ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, n, Color(col, op))

static func _ease(x: float) -> float:   # cubic-bezier(.2,.9,.2,1) gần đúng
	return 1.0 - pow(1.0 - x, 3.0)

func bubble(txt: String) -> void:
	_bub = {"txt": txt, "t": 0.0, "a": _bub.a}

func _draw_bub(ci: W_) -> void:
	if _bub.a <= 0.01 or _bub.txt == "":
		return
	var a: float = _bub.a
	var c1: Rect2 = card_rect(1)
	var pad: Array = cards[1].get_meta("pad")
	var avx: float = c1.position.x + pad[3] + pcm.av / 2
	var maxw := minf(300.0, W - 24)
	var lines := wrapt(_bub.txt, 13.5, 600, 600, maxw - 24)
	var bw := 0.0
	for ln in lines:
		bw = maxf(bw, line_w(ln, 13.5, 600, 600))
	bw += 24
	var bh := lines.size() * 13.5 * 1.3 + 16
	var left := clampf(avx - 26, 12, W - bw - 12)
	var top := c1.end.y + 14 - (1 - a) * 4
	var tail := clampf(avx - left - 8, 14, bw - 30)
	ci.modulate.a = a
	box(ci, Rect2(left, top, bw, bh), Color.WHITE, 14, [], SH)
	var tc := Vector2(left + tail + 6, top + 1)
	var pts := PackedVector2Array([tc + Vector2(-8.5, 0), tc + Vector2(0, -7.5), tc + Vector2(8.5, 0)])
	var sp := PackedVector2Array()
	for q in pts:
		sp.append(q * K)
	ci.draw_colored_polygon(sp, Color.WHITE)
	draw_lines(ci, lines, left + 12, top + 8, 13.5, 1.3, 600, 600, INK)

func show_ff(on: bool) -> void:
	_ff_on = on
	if not on:
		game.Gm.ff = 1.0
	ff.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_lay_ff()

func ff_toggle() -> void:
	game.Gm.ff = 1.0 if game.Gm.ff > 1.0 else 3.2
	ff.queue_redraw()

func _lay_ff() -> void:
	var lab := "Đi thường" if game.Gm.ff > 1.0 else "Tua nhanh"
	var w := 14 + 17 + 7 + tw(lab, 13, 700) + 14
	var r := Rect2(W - 12 - w, H - 12 - 33, w, 33)
	ff.items = [{"r": r, "tap": ff_toggle, "id": "ff"}]
	ff.set_meta("r", r)
	ff.queue_redraw()

func _draw_ff(ci: W_) -> void:
	if _ff_a <= 0.01:
		return
	_lay_ff_r()
	var r: Rect2 = ci.get_meta("r")
	var on: bool = game.Gm.ff > 1.0
	ci.modulate.a = _ff_a
	box(ci, r, Color(1, 250 / 255.0, 240 / 255.0, 0.92), 99, [], SH)
	if on:
		ring_in(ci, r, 99, 2, GOLD)
	var lab := "Đi thường" if on else "Tua nhanh"
	ci.draw_texture_rect(A.ff_icon("#3a2412", roundi(17 * K)), Rect2(Vector2(r.position.x + 14, r.position.y + 8) * K, Vector2(17, 17) * K), false)
	text(ci, lab, r.position.x + 14 + 17 + 7, r.position.y, 13, 700, INK, 33.0 / 13)

func _lay_ff_r() -> void:
	var lab := "Đi thường" if game.Gm.ff > 1.0 else "Tua nhanh"
	var w := 14 + 17 + 7 + tw(lab, 13, 700) + 14
	var r := Rect2(W - 12 - w, H - 12 - 33, w, 33)
	ff.set_meta("r", r)
	ff.items = [{"r": r, "tap": ff_toggle, "id": "ff"}]

func _draw_quiet(ci: W_) -> void:
	var Gm: Dictionary = game.Gm
	var s = Gm.s
	if s == null or s.over or not int(Gm.R.get("quiet", 0)) or int(s.quiet) < int(Gm.R.quiet) * 2 - 10:
		return
	var t := "Còn %d lượt không ai ăn là hòa" % ceili((int(Gm.R.quiet) * 2 - int(s.quiet)) / 2.0)
	var w := tw(t, 13, 700) + 28
	var h := 31.0
	var r := Rect2((W - w) / 2, H / 2 - 10 if port else H - 12 - h, w, h)
	box(ci, r, CREAM, 99, [3, Color("#e2cfa6")], SH)
	text(ci, t, r.position.x, r.position.y + 1, 13, 700, BRICK2, (h - 3) / 13, "center", w)

# ------------------------------------------------------------ hướng dẫn ván đầu
const COACH := [
	["Bước 1/3 · Chọn quân", "Chạm một quân của mình. Bạn cầm sỏi trắng, đi từ phía dưới lên."],
	["Bước 2/3 · Đi một bước", "Chạm chỗ có vòng phấn, hoặc kéo quân tới đó. Đi một bước theo đường kẻ; chỗ nào có đường chéo thì đi chéo được."],
	["Bước 3/3 · Gánh và vây", "Đi vô giữa hai quân bên kia là gánh: hai quân đó thành của mình. Bít hết đường đi của quân bên kia là vây: ăn luôn. Vòng phấn vàng là nước ăn được."],
]
var _coach := {"step": -1}

func _lay_coach() -> void:
	var g = game
	var Gm: Dictionary = g.Gm
	var human: bool = Gm.started and Gm.s != null and not Gm.s.over and g.is_human(Gm.s.turn) and not Gm.busy
	var step := -1
	if g.tut_step < 3:
		if g.tut_step == 0 and human and Gm.sel < 0:
			step = 0
		elif g.tut_step <= 1 and human and Gm.sel >= 0:
			step = 1
		elif g.tut_step == 2 and human:
			step = 2
	coach_w.items = []
	coach_w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach = {"step": step}
	if step < 0:
		coach_w.queue_redraw()
		return
	var title: String = COACH[step][0]
	var body: String = ("Chạm một quân của mình. " + Gm.names[0] + " cầm sỏi trắng (dưới), " + Gm.names[1] + " cầm miểng gạch (trên).") if step == 0 and Gm.mode == "pvp" else COACH[step][1]
	var w := minf(340.0, W - 32)
	var x := (W - w) / 2
	var L: Dictionary = g.L
	if not port:
		var col: float = g.map(0, 0).x - g.PR * L.s - 14
		w = minf(330.0, col - 12)
		x = 10.0
	var tl := wrapt(title, 17, 800, 800, w - 28)
	var bl := wrapt(body, 13.5, 500, 500, w - 28)
	var h := 12 + tl.size() * 17 * 1.2 + 4 + bl.size() * 13.5 * 1.45 + 12
	var btn := Rect2()
	if step == 2:
		var bw := tw("Hiểu rồi", 15, 800) + 28
		h += 4 + 6 + 15 + 20
		btn = Rect2(x + w - 14 - bw, 0, bw, 15 + 20)
	var y := 0.0
	if port:
		y = maxf(8.0, g.map(0, 0).y - g.PR * L.s - 10 - h)
	else:
		var c0: Rect2 = L.cards[0]
		var tr: Rect2 = L.tools
		y = maxf(tr.end.y + 8, c0.position.y - 10 - h)
	btn.position.y = y + h - 12 - btn.size.y
	_coach.merge({"r": Rect2(x, y, w, h), "tl": tl, "bl": bl, "btn": btn})
	if step == 2:
		coach_w.mouse_filter = Control.MOUSE_FILTER_STOP
		coach_w.items = [{"r": btn, "tap": _coach_ok, "id": "ok"}]
		coach_w.set_meta("hit", Rect2(x, y, w, h))
	coach_w.queue_redraw()

func _coach_ok() -> void:
	game.tut_step = 3
	game.store_set("cg-tut", 3)
	_lay_coach()

func _draw_coach(ci: W_) -> void:
	if _coach.step < 0 or not _coach.has("r"):
		return
	var r: Rect2 = _coach.r
	box(ci, r, INK, 16, [], [[0, 10, 30, Color(30 / 255.0, 15 / 255.0, 0, 0.4)]])
	var y := draw_lines(ci, _coach.tl, r.position.x + 14, r.position.y + 12, 17, 1.2, 800, 800, Color("#ffe27a"))
	draw_lines(ci, _coach.bl, r.position.x + 14, y + 4, 13.5, 1.45, 500, 500, Color("#fff6e0"))
	if _coach.step == 2:
		_btn(ci, _coach.btn, "Hiểu rồi", "", true, ci.pressed_id() == "ok")

# ------------------------------------------------------------ nút .btn
func _btn(ci: CanvasItem, r: Rect2, lab: String, kind := "", sm := false, down := false) -> void:
	var bg := BRICK
	var bev := BRICK2
	var col := Color.WHITE
	var shc := Color(150 / 255.0, 50 / 255.0, 20 / 255.0, 0.25)
	if kind == "g":
		bg = LEAF; bev = LEAF2; shc = Color(40 / 255.0, 90 / 255.0, 20 / 255.0, 0.25)
	elif kind == "w":
		bg = Color("#fff3d6"); bev = Color("#e2c88f"); col = INK; shc = Color(90 / 255.0, 60 / 255.0, 20 / 255.0, 0.15)
	var fs := 16.0 if sm else 19.0
	var rad := 13.0 if sm else 16.0
	var rr := r
	if down:
		rr.position.y += 2
		box(ci, rr, bg, rad, [2, bev])
	else:
		box(ci, rr, bg, rad, [4, bev], [[0, 6, 14, shc]])
	text(ci, lab, rr.position.x, rr.position.y, fs, 800, col, (rr.size.y - (2 if down else 4)) / fs, "center", rr.size.x)

func btn_h(sm := false) -> float:
	return 16 + 20.0 if sm else 19 + 26.0

# ============================================================ bảng phủ
func show_ov(id: String) -> void:
	for k in ovs:
		ovs[k].visible = k == id
	cur_ov = id
	_ov_t = 0.0
	for le in names_le:
		le.visible = false
	if id != "":
		ovs[id].scroll = 0.0
		_lay(id)

func close_all() -> void:
	for k in ovs:
		ovs[k].visible = false
	for le in names_le:
		le.release_focus()
		le.visible = false
	cur_ov = ""
	if not game.Gm.started:
		show_ov("menu")

func _close_x() -> void:
	close_all()
	if back_to != "":
		var b := back_to
		back_to = ""
		show_ov(b)

func _ov_bg(id: String) -> void:
	if id == "menu":
		if game.Gm.started:
			close_all()
		return
	if id == "end":
		return
	_close_x()

func _lay_all() -> void:
	_lay_ff_r()
	_lay_coach()
	if cur_ov != "":
		_lay(cur_ov)

# khung thẻ giữa màn: rộng tối đa mw, cao theo nội dung (cuộn nếu dài)
func _card_frame(mw: float, h: float) -> Rect2:
	var w := minf(mw, W - 32)
	var hh := minf(h, H - 32 - 8)
	return Rect2((W - w) / 2, (H - hh) / 2, w, hh)

func _cpad() -> Array:   # padding thẻ: trên, phải/trái, dưới
	if H <= 430:
		return [16.0, 16.0, 14.0]
	if W <= 520:
		return [20.0, 16.0, 16.0]
	return [22.0, 22.0, 20.0]

func _lay(id: String) -> void:
	var o: W_ = ovs[id]
	var res: Dictionary = call("_lay_" + id)
	o.set_meta("L", res)
	o.items = res.items
	var fr: Rect2 = res.frame
	o.max_scroll = maxf(0.0, res.h - fr.size.y)
	o.scroll = clampf(o.scroll, 0.0, o.max_scroll)
	var b: W_ = o.get_meta("body")
	b.position = fr.position * K
	b.size = fr.size * K
	o.queue_redraw()
	b.queue_redraw()

func _draw_ov(ci: W_, id: String) -> void:
	if not ci.has_meta("L"):
		return
	var res: Dictionary = ci.get_meta("L")
	ci.modulate.a = minf(1.0, _ov_t / 0.25)
	ci.draw_rect(Rect2(Vector2.ZERO, ci.size), Color(48 / 255.0, 30 / 255.0, 12 / 255.0, 0.38))
	var fr: Rect2 = res.frame
	box(ci, fr, CREAM, 24, [4, Color("#ead7ae")], [[0, 20, 60, Color(40 / 255.0, 20 / 255.0, 0, 0.4)]])

func _draw_body(ci: W_, id: String) -> void:
	var o: W_ = ovs[id]
	if not o.has_meta("L"):
		return
	var res: Dictionary = o.get_meta("L")
	var fr: Rect2 = res.frame
	ci.draw_set_transform(-fr.position * K, 0.0, Vector2.ONE)
	_cur_body = ci
	(res.draw as Callable).call(ci, fr, o.scroll, fr)
	ci.draw_set_transform(-fr.position * K, 0.0, Vector2.ONE)
	if o.max_scroll > 0:
		var th := fr.size.y * fr.size.y / (fr.size.y + o.max_scroll)
		var ty := fr.position.y + (fr.size.y - th) * o.scroll / o.max_scroll
		box(ci, Rect2(fr.end.x - 6, ty + 4, 3, th - 8), Color(INK2, 0.3), 2)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

var _cur_body: W_ = null

# --- nội dung được vẽ theo danh sách lệnh, dịch theo scroll và cắt ngoài khung (mỗi phần tử dưới mép thì bỏ)
func _visible(r: Rect2, clip: Rect2, sc: float) -> bool:
	return r.end.y - sc > clip.position.y - 2 and r.position.y - sc < clip.end.y + 2

# ------------------------------------------------------------ Menu
func build_menu() -> void:
	if cur_ov == "menu":
		_lay("menu")

func _mini_board() -> String:
	var m := '<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><rect x="0" y="0" width="120" height="120" rx="14" fill="#c9ab84"/><g fill="none" stroke="#fffbf0" stroke-width="2.2" stroke-linecap="round" opacity=".95">'
	var P := func(k: int) -> int: return 16 + k * 22
	for k in 5:
		m += '<path d="M%d %dH%dM%d %dV%d"/>' % [P.call(0), P.call(k), P.call(4), P.call(k), P.call(0), P.call(4)]
	m += '<path d="M%d %dL%d %dM%d %dL%d %dM%d %dL%d %dL%d %dL%d %dZ"/></g>' % [P.call(0), P.call(0), P.call(4), P.call(4), P.call(4), P.call(0), P.call(0), P.call(4), P.call(2), P.call(0), P.call(0), P.call(2), P.call(2), P.call(4), P.call(4), P.call(2)]
	var b: PackedByteArray = E.new_state(0).b
	for i in 25:
		if b[i]:
			var x: int = P.call(i % 5)
			var y: int = P.call(i / 5)
			if b[i] == 1:
				m += '<circle cx="%d" cy="%d" r="7.5" fill="#efebe2" stroke="#7d7466" stroke-width="1.6"/>' % [x, y]
			else:
				m += '<rect x="%d" y="%d" width="14" height="14" rx="4.5" fill="#a9452a" stroke="#6e2a16" stroke-width="1.6"/>' % [x - 7, y - 7]
	return m + "</svg>"

func _lay_menu() -> Dictionary:
	var g = game
	var cp := _cpad()
	var pt := 30.0 if H > 430 else 16.0
	var px := 22.0 if H > 430 else 18.0
	if W <= 520:
		px = 16.0
	var pb := 20.0 if H > 430 else 12.0
	var cw := minf(560.0, W - 32)
	var iw := cw - px * 2
	var items := []
	var ops := []   # lệnh vẽ (theo y trong thẻ)
	var y := pt
	# logo
	var lf := clampf(W * 0.11, 46, 72)
	if H <= 430:
		lf = 44.0
	y += 2
	ops.append(["logo", y, lf])
	y += lf * 0.9 + 2
	var sub := wrapt("Kẻ phấn ra sân, sỏi trắng đấu miểng gạch. Gánh hai, vây một, ai hết quân là thua nghen!", 14, 600, 600, iw)
	ops.append(["sub", y, sub])
	y += sub.size() * 14 * 1.4 + (14 if H > 430 else 6)
	if H > 430:
		var ms := 96.0 if W <= 520 else 120.0
		y += 4
		ops.append(["mini", y, ms])
		y += ms + 12
	# tabs
	y += 4
	var tabh := 15 + 20.0 + 8
	ops.append(["tabs", y, tabh])
	var tw2 := (iw - 8 - 4) / 2
	items.append({"r": Rect2(px + 4, y + 4, tw2, tabh - 8), "tap": func(): menu_mode = "ai"; _lay("menu"), "id": "t_ai", "scroll": true})
	items.append({"r": Rect2(px + 4 + tw2 + 4, y + 4, tw2, tabh - 8), "tap": func(): menu_mode = "pvp"; _lay("menu"), "id": "t_pvp", "scroll": true})
	y += tabh + 2
	if menu_mode == "ai":
		y += 14 if H > 430 else 8
		var cols := 2 if W <= 520 else 4
		var gw := (iw - 8 * (cols - 1)) / cols
		var avs := 44.0 if H <= 430 else 58.0
		var oh := 8 + avs + 4 + 16 * 1.1 + 11.5 * 1.3 + 2 + 10.5 * 1.2 + 9
		for k in 4:
			var r := Rect2(px + (k % cols) * (gw + 8), y + (k / cols) * (oh + 8), gw, oh)
			items.append({"r": r, "tap": _pick_opp.bind(k), "id": "o" + str(k), "scroll": true, "opp": k, "avs": avs})
		y += ceili(4.0 / cols) * (oh + 8) - 8 + (4 if H > 430 else 2)
	else:
		y += 12
		var nw := (iw - 8) / 2
		for p in [0, 1]:
			var r := Rect2(px + p * (nw + 8), y, nw, 15 * 1.2 + 22)
			items.append({"r": r, "tap": _focus_name.bind(p), "id": "n" + str(p), "scroll": true, "name": p})
		y += 15 * 1.2 + 22 + 2
	# nút
	y += 14
	var bh := btn_h()
	var resume: bool = g.has_save() and not g.Gm.started
	var lab: String = "Chơi ván mới" if g.Gm.started else "Vô chơi"
	if resume:
		if iw >= 410:
			var bw := (iw - 10) / 2
			items.append({"r": Rect2(px, y, bw, bh), "tap": _start, "id": "start", "scroll": true, "btn": lab})
			items.append({"r": Rect2(px + bw + 10, y, bw, bh), "tap": _resume, "id": "resume", "scroll": true, "btn": "Chơi tiếp ván cũ", "kind": "g"})
			y += bh
		else:
			items.append({"r": Rect2(px, y, iw, bh), "tap": _start, "id": "start", "scroll": true, "btn": lab})
			y += bh + 10
			items.append({"r": Rect2(px, y, iw, bh), "tap": _resume, "id": "resume", "scroll": true, "btn": "Chơi tiếp ván cũ", "kind": "g"})
			y += bh
	else:
		items.append({"r": Rect2(px, y, iw, bh), "tap": _start, "id": "start", "scroll": true, "btn": lab})
		y += bh
	# liên kết
	var l1 := tw("Luật chơi", 14, 700) + 16
	var l2 := tw("Cài đặt luật", 14, 700) + 16
	var lx := px + (iw - l1 - l2) / 2
	items.append({"r": Rect2(lx, y, l1, 34), "tap": func(): back_to = "menu"; show_ov("rules"), "id": "l_rules", "scroll": true, "lnk": "Luật chơi"})
	items.append({"r": Rect2(lx + l1, y, l2, 34), "tap": func(): back_to = "menu"; show_ov("settings"), "id": "l_set", "scroll": true, "lnk": "Cài đặt luật"})
	y += 34 + pb
	var fr := _card_frame(560, y)
	for it in items:
		it.r.position += fr.position
	for le in names_le:
		le.visible = menu_mode == "pvp" and cur_ov == "menu"
	return {"frame": fr, "h": y, "items": items, "draw": _draw_menu.bind(ops, px, iw)}

func _pick_opp(k: int) -> void:
	menu_level = k
	game.store_set("cg-lvl", k)
	game.snd.sel()
	_lay("menu")

func _focus_name(p: int) -> void:
	names_le[p].grab_focus()
	names_le[p].caret_column = names_le[p].text.length()

func _start() -> void:
	var g = game
	for le in names_le:
		le.release_focus()
	var names := ["Người 1", "Người 2"]
	if menu_mode == "pvp":
		var a: String = names_le[0].text.strip_edges()
		var b: String = names_le[1].text.strip_edges()
		g.store_set("cg-n0", a)
		g.store_set("cg-n1", b)
		names = [a if a != "" else "Người 1", b if b != "" else "Người 2"]
	g.start(menu_mode, menu_level, names)

func _resume() -> void:
	game.resume_game()

func _draw_menu(ci: W_, fr: Rect2, sc: float, clip: Rect2, ops: Array, px: float, iw: float) -> void:
	var g = game
	var o := fr.position - Vector2(0, sc)
	# khăn rằn trên đầu thẻ
	_khan(ci, Rect2(fr.position.x, fr.position.y, fr.size.x, 16))
	ci.draw_rect(Rect2(Vector2(fr.position.x, fr.position.y + 16) * K, Vector2(fr.size.x, 3) * K), Color(Color("#2a2420"), 0.7))
	for op in ops:
		var y: float = o.y + op[1]
		if op[0] == "logo":
			var fs: float = op[2]
			text(ci, "Cờ Gánh", o.x, y + 5, fs, 800, Color(120 / 255.0, 60 / 255.0, 10 / 255.0, 0.22), 0.9, "center", fr.size.x)
			text(ci, "Cờ Gánh", o.x, y + 3, fs, 800, GOLD, 0.9, "center", fr.size.x)
			text(ci, "Cờ Gánh", o.x, y, fs, 800, BRICK2, 0.9, "center", fr.size.x)
		elif op[0] == "sub":
			draw_lines(ci, op[2], o.x + px, y, 14, 1.4, 600, 600, INK2, Color(0, 0, 0, 0), "center", iw)
		elif op[0] == "mini":
			var ms: float = op[2]
			var r := Rect2(o.x + (fr.size.x - ms) / 2, y, ms, ms)
			box(ci, r, Color("#c9ab84"), 14, [], [[0, 4, 0, Color("#b08a5c")], [0, 8, 16, Color(90 / 255.0, 60 / 255.0, 20 / 255.0, 0.18)]])
			var t := A.svg(_mini_board(), roundi(ms * K))
			ci.draw_texture_rect(t, Rect2(r.position * K, r.size * K), false)
		elif op[0] == "tabs":
			box(ci, Rect2(o.x + px, y, iw, op[2]), Color("#f1e2c2"), 14)
	for it in ci.ov.items:
		var r: Rect2 = it.r
		r.position.y -= sc
		if not _visible(r, clip, 0):
			continue
		var id: String = it.id
		var down: bool = ci.pressed_id() == id
		if id == "t_ai" or id == "t_pvp":
			var on: bool = (id == "t_ai") == (menu_mode == "ai")
			if on:
				box(ci, r, Color.WHITE, 11, [], [[0, 2, 6, Color(90 / 255.0, 60 / 255.0, 20 / 255.0, 0.15)]])
			text(ci, "Đấu với máy" if id == "t_ai" else "Hai người chơi", r.position.x, r.position.y, 15, 700, BRICK2 if on else INK2, r.size.y / 15, "center", r.size.x)
		elif it.has("opp"):
			var k: int = it.opp
			var sel := k == menu_level
			var avs: float = it.avs
			if sel:
				box(ci, r, Color("#fff6ea"), 16, [], [[0, 6, 14, Color(150 / 255.0, 50 / 255.0, 20 / 255.0, 0.18)]])
				ring_in(ci, r, 16, 3, BRICK)
			else:
				box(ci, r, Color.WHITE, 16)
				ring_in(ci, r, 16, 2, Color("#ecd9b0"))
			var ar := Rect2(r.position.x + (r.size.x - avs) / 2, r.position.y + 8, avs, avs)
			box(ci, ar, Color("#f3e3c0"), 14)
			avatar(ci, g.OPP[k].k, ar)
			var yy := ar.end.y + 4
			text(ci, g.OPP[k].name, r.position.x, yy, 16, 800, INK, 1.1, "center", r.size.x)
			yy += 16 * 1.1
			text(ci, g.OPP[k].lvl, r.position.x, yy, 11.5, 600, INK2, 1.3, "center", r.size.x)
			yy += 11.5 * 1.3 + 2
			var em: String = ("thắng %d · thua %d" % [int(g.stats.w[k]), int(g.stats.l[k])]) if (int(g.stats.w[k]) or int(g.stats.l[k])) else g.OPP[k].tag
			text(ci, ellip(em, 10.5, 600, r.size.x - 6), r.position.x, yy, 10.5, 600, Color("#9a7b55"), 1.2, "center", r.size.x)
		elif it.has("name"):
			var p: int = it.name
			var le: LineEdit = names_le[p]
			box(ci, r, Color.WHITE, 12)
			ci.draw_rect(Rect2(Vector2(r.position.x + 1, r.position.y + 1) * K, Vector2(29, r.size.y - 2) * K), Color("#f6ead0"))
			ring_in(ci, r, 12, 2, BRICK if le.has_focus() else Color("#ecd9b0"))
			pk(ci, p, Rect2(r.position.x + 6, r.position.y + (r.size.y - 18) / 2, 18, 18))
			le.position = (Vector2(r.position.x + 32, r.position.y + 2) - fr.position) * K
			le.size = Vector2(r.size.x - 36, r.size.y - 4) * K
		elif it.has("btn"):
			_btn(ci, r, it.btn, it.get("kind", ""), false, down)
		elif it.has("lnk"):
			var c := INK2
			text(ci, it.lnk, r.position.x + 8, r.position.y + 10, 14, 700, c, 1.0)
			var uy := r.position.y + 10 + 14 + 3
			ci.draw_line(Vector2(r.position.x + 8, uy) * K, Vector2(r.end.x - 8, uy) * K, c, 1.2 * K)

func _khan(ci: CanvasItem, r: Rect2) -> void:
	# khăn rằn: ô cờ đen trắng 4px, bo theo góc trên của thẻ
	var cs := 4.0
	var y := r.position.y
	var row := 0
	while y < r.end.y - 0.01:
		var x := r.position.x
		var col := 0
		while x < r.end.x - 0.01:
			var ww := minf(cs, r.end.x - x)
			var inset := 0.0
			var top_d := y - r.position.y
			# góc bo 24px
			var dx := minf(x - r.position.x, r.end.x - (x + ww))
			if dx < 24 and top_d < 24:
				var cy := 24 - top_d - cs * 0.5
				var need := 24 - sqrt(maxf(0.0, 24 * 24 - cy * cy))
				if dx < need:
					x += cs
					col += 1
					continue
			var c := Color("#2a2420") if (row + col) % 2 == 0 else Color("#f3efe6")
			ci.draw_rect(Rect2(Vector2(x, y) * K, Vector2(ww, cs) * K), Color(c, 0.92))
			x += cs
			col += 1
		y += cs
		row += 1

# ------------------------------------------------------------ Luật chơi
const DG := [
	'<svg viewBox="0 0 280 118"><g class="ln"><path d="M36 12H104M36 12V80"/><path d="M36 46H104M70 12V80"/><path d="M36 80H104M104 12V80"/><path d="M36 12L104 80M104 12L36 80"/></g><path class="ar" d="M61.5 37.5L38.8 14.8M45.2 15.5L38.8 14.8L39.5 21.2"/><path class="ar" d="M70.0 34.0L70.0 16.0M74.0 21.0L70.0 16.0L66.0 21.0"/><path class="ar" d="M78.5 37.5L101.2 14.8M100.5 21.2L101.2 14.8L94.8 15.5"/><path class="ar" d="M58.0 46.0L40.0 46.0M45.0 42.0L40.0 46.0L45.0 50.0"/><path class="ar" d="M82.0 46.0L100.0 46.0M95.0 50.0L100.0 46.0L95.0 42.0"/><path class="ar" d="M61.5 54.5L38.8 77.2M39.5 70.8L38.8 77.2L45.2 76.5"/><path class="ar" d="M70.0 58.0L70.0 76.0M66.0 71.0L70.0 76.0L74.0 71.0"/><path class="ar" d="M78.5 54.5L101.2 77.2M94.8 76.5L101.2 77.2L100.5 70.8"/><circle class="w" cx="70" cy="46" r="8"/><g class="ln"><path d="M176 12H244M176 12V80"/><path d="M176 46H244M210 12V80"/><path d="M176 80H244M244 12V80"/><path d="M210 12L176 46L210 80L244 46Z"/></g><path class="ar" d="M210.0 34.0L210.0 16.0M214.0 21.0L210.0 16.0L206.0 21.0"/><path class="ar" d="M198.0 46.0L180.0 46.0M185.0 42.0L180.0 46.0L185.0 50.0"/><path class="ar" d="M222.0 46.0L240.0 46.0M235.0 50.0L240.0 46.0L235.0 42.0"/><path class="ar" d="M210.0 58.0L210.0 76.0M206.0 71.0L210.0 76.0L214.0 71.0"/><circle class="w" cx="210" cy="46" r="8"/><text x="70" y="108" text-anchor="middle">có đường chéo: 8 hướng</text><text x="210" y="108" text-anchor="middle">không có chéo: 4 hướng</text></svg>',
	'<svg viewBox="0 0 280 118"><g class="ln"><path d="M34 26H102M34 26V94"/><path d="M34 60H102M68 26V94"/><path d="M34 94H102M102 26V94"/></g><path class="pole" d="M34 21Q68 2 102 21"/><rect class="r" x="26.5" y="18.5" width="15" height="15" rx="5"/><rect class="r" x="94.5" y="18.5" width="15" height="15" rx="5"/><circle class="ring" cx="68" cy="26" r="11"/><circle class="w" cx="68" cy="60" r="8"/><path class="ar" d="M68.0 48.0L68.0 40.0M72.0 45.0L68.0 40.0L64.0 45.0"/><text x="68" y="112" text-anchor="middle">đi vô giữa hai quân</text><path class="ar" d="M128.0 58.0L156.0 58.0M150.0 62.8L156.0 58.0L150.0 53.2"/><circle class="w" cx="186" cy="58" r="8"/><circle class="w" cx="216" cy="58" r="8"/><circle class="w" cx="246" cy="58" r="8"/><g class="ln85"><path d="M186 58H246"/></g><circle class="w" cx="186" cy="58" r="8"/><circle class="w" cx="216" cy="58" r="8"/><circle class="w" cx="246" cy="58" r="8"/><text x="216" y="86" text-anchor="middle">cả hai thành</text><text x="216" y="100" text-anchor="middle">quân của mình</text></svg>',
	'<svg viewBox="0 0 280 118"><g class="ln"><path d="M40 14H108M40 14V82"/><path d="M40 48H108M74 14V82"/><path d="M40 82H108M108 14V82"/><path d="M40 14L108 82"/></g><rect class="r" x="32.5" y="6.5" width="15" height="15" rx="5"/><circle class="ring" cx="40" cy="14" r="14"/><circle class="w" cx="74" cy="14" r="8"/><circle class="w" cx="74" cy="48" r="8"/><circle class="w" cx="40" cy="82" r="8"/><path class="ar" d="M40.0 70.0L40.0 61.0M44.0 66.0L40.0 61.0L36.0 66.0"/><text x="136" y="36">bít điểm cuối cùng:</text><text x="136" y="52">quân đỏ hết đường đi,</text><text x="136" y="68">bị vây, thành quân trắng</text></svg>',
]
const DG_CLS := {
	'class="ln"': 'fill="none" stroke="#fffbf0" stroke-width="2" stroke-linecap="round" opacity=".95"',
	'class="ln85"': 'fill="none" stroke="#fffbf0" stroke-width="2" stroke-linecap="round" opacity=".85"',
	'class="w"': 'fill="#efebe2" stroke="#7d7466" stroke-width="1.6"',
	'class="r"': 'fill="#a9452a" stroke="#6e2a16" stroke-width="1.6"',
	'class="ar"': 'fill="none" stroke="#ffe27a" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"',
	'class="ring"': 'fill="none" stroke="#ffe27a" stroke-width="2.6" stroke-dasharray="4 3"',
	'class="pole"': 'fill="none" stroke="#ffd85a" stroke-width="4" stroke-linecap="round" opacity=".9"',
}
var _dg_cache := {}

func _dg(i: int) -> Dictionary:
	# sơ đồ luật: hình (không chữ) + các dòng chữ (vẽ bằng Baloo)
	if _dg_cache.has(i):
		return _dg_cache[i]
	var s: String = DG[i].replace('<svg viewBox="0 0 280 118">', '<svg viewBox="0 0 280 118" xmlns="http://www.w3.org/2000/svg">')
	for k in DG_CLS:
		s = s.replace(k, DG_CLS[k])
	var re := RegEx.new()
	re.compile('<text x="([0-9.]+)" y="([0-9.]+)"( text-anchor="middle")?>([^<]*)</text>')
	var tx := []
	for m in re.search_all(s):
		tx.append([float(m.get_string(1)), float(m.get_string(2)), m.get_string(3) != "", m.get_string(4)])
	s = re.sub(s, "", true)
	var r := {"svg": s, "tx": tx}
	_dg_cache[i] = r
	return r

const RULES := [
	["1 · Đi quân", 0, ["Đi **một bước** theo đường kẻ tới chỗ trống: ngang, dọc, hoặc chéo ở điểm có đường chéo.", "Không nhảy qua quân nào hết."], ""],
	["2 · Gánh", 1, ["Đi vô **chính giữa hai quân bên kia** trên cùng một đường thì **gánh**: hai quân đó đổi thành quân mình.", "Một nước gánh được nhiều cặp cùng lúc (gánh đôi)."], ""],
	["3 · Vây (chẹt)", 2, [], "Đi xong mà một hay một chùm quân bên kia **hết đường đi** (mọi điểm kề đều có quân) thì vây được, mấy quân đó cũng thành của mình."],
	["4 · Mở, hết ván", -1, [], "**Mở:** bên kia vừa rời một điểm mà mình đi vô đó gánh được, thì **bắt buộc phải gánh**. Coi chừng, đó thường là bẫy! (Tắt được trong Cài đặt.)|**Thắng:** ăn hết quân bên kia. Thế cờ lặp lại ba lần, hoặc lâu quá không ai ăn được quân nào, thì hòa."],
]

func _lay_rules() -> Dictionary:
	var cp := _cpad()
	var cw := minf(900.0, W - 32)
	var px: float = cp[1]
	var iw := cw - px * 2
	var items := []
	var ops := []
	var y: float = cp[0]
	ops.append(["h2", y, "Luật chơi"])
	y += 28 + 4
	var lead := wrapt("Bàn kẻ **5 × 5 điểm**, có đường chéo. Mỗi bên **8 quân**: bạn cầm **sỏi trắng** ở phía dưới, bên kia cầm **miểng gạch** ở phía trên. Mỗi lượt đi một quân.", 14.5, 500, 800, iw)
	ops.append(["p", y, lead, 14.5, 1.45, px])
	y += lead.size() * 14.5 * 1.45 + 8
	var two := W >= 820
	var colw := (iw - 10) / 2 if two else iw
	var col_y := [y, y]
	for i in RULES.size():
		var R: Array = RULES[i]
		var c := (i % 2) if two else 0
		var sx := px + c * (colw + 10)
		var sy: float = col_y[c] if two else y
		var inner := colw - 24
		var sec := []
		var yy := 6.0 + 6
		sec.append(["h3", yy, R[0]])
		yy += 18 * 1.1 + 6
		if R[1] >= 0:
			var dw := minf(330.0, inner)
			var dh := dw * 118 / 280
			sec.append(["dg", yy + 4, R[1], (inner - dw) / 2, dw, dh])
			yy += 4 + dh + 6
		for li in R[2]:
			var ls := wrapt(li, 14, 500, 800, inner - 20)
			sec.append(["li", yy, ls])
			yy += ls.size() * 14 * 1.4 + 8
		if R[3] != "":
			for para in R[3].split("|"):
				var ps := wrapt(para, 14, 500, 800, inner)
				sec.append(["pp", yy, ps])
				yy += ps.size() * 14 * 1.4 + 8
		yy += 8 - 8 + 2
		ops.append(["sec", sy, sx, colw, yy, sec])
		if two:
			col_y[c] = sy + yy + 10
		else:
			y += yy + 10
	if two:
		# hai cột: mỗi hàng cao bằng ô cao hơn (grid)
		var rows := []
		var yb := y
		for rr in 2:
			var a: Array = ops[ops.size() - 4 + rr * 2]
			var b: Array = ops[ops.size() - 4 + rr * 2 + 1]
			var hh := maxf(a[4], b[4])
			a[1] = yb; b[1] = yb
			a[4] = hh; b[4] = hh
			yb += hh + 10
		y = yb
	y -= 10
	var note := wrapt("**Mẹo:** chạm quân rồi chạm chỗ có vòng phấn, hoặc kéo quân thả vô chỗ đó. Vòng phấn vàng là nước ăn được, ghi luôn ăn mấy quân. Đấu với máy được đi lại 3 lần. Chạm bàn khi đang đi để tua nhanh.", 12.5, 500, 800, iw - 22)
	y += 10
	ops.append(["note", y, note, px, iw])
	y += note.size() * 12.5 * 1.4 + 18
	y += 10
	var bw := tw("Xem lại hướng dẫn", 16, 800) + 28
	items.append({"r": Rect2(px + iw - bw, y, bw, btn_h(true)), "tap": _tut_again, "id": "tut", "scroll": true, "btn": "Xem lại hướng dẫn", "kind": "w", "sm": true})
	y += btn_h(true) + cp[2]
	var fr := _card_frame(900, y)
	for it in items:
		it.r.position += fr.position
	items.append({"r": Rect2(fr.end.x - 12 - 36, fr.position.y + 12, 36, 36), "tap": _close_x, "id": "x"})
	return {"frame": fr, "h": y, "items": items, "draw": _draw_doc.bind(ops)}

func _tut_again() -> void:
	game.tut_step = 0
	game.store_set("cg-tut", 0)
	close_all()
	update_cards()

func _draw_doc(ci: W_, fr: Rect2, sc: float, clip: Rect2, ops: Array) -> void:
	var o := fr.position - Vector2(0, sc)
	for op in ops:
		var y: float = o.y + op[1]
		match op[0]:
			"h2":
				text(ci, op[2], o.x + _cpad()[1], y, 28, 800, INK, 1.0)
			"p":
				draw_lines(ci, op[2], o.x + op[5], y, op[3], op[4], 500, 800, Color("#4a321c"))
			"grp":
				text(ci, op[2], o.x + op[3], y, 18, 800, BRICK2, 1.0)
				ci.draw_rect(Rect2(Vector2(o.x + op[3], y + 18 + 4) * K, Vector2(op[4], 2) * K), Color("#ecd9b0"))
			"sec":
				var sr := Rect2(o.x + op[2], y, op[3], op[4])
				if not _visible(sr, clip, 0):
					continue
				box(ci, sr, Color("#fff7e6"), 14)
				ring_in(ci, sr, 14, 1.5, Color("#ecd9b0"))
				for q in op[5]:
					var qy: float = y + q[1]
					var qx := sr.position.x + 12
					match q[0]:
						"h3":
							text(ci, q[2], qx, qy, 18, 800, RED2, 1.1)
						"dg":
							var d := _dg(q[2])
							var dr := Rect2(qx + q[3], qy, q[4], q[5])
							box(ci, dr, Color("#c9ab84"), 12)
							var t := A.svg(d.svg, roundi(q[4] * K))
							if t != null:
								ci.draw_texture_rect(t, Rect2(dr.position * K, dr.size * K), false)
							var k: float = q[4] / 280.0
							for tt in d.tx:
								var fs := 11 * k
								var tx: float = dr.position.x + tt[0] * k
								var ww := tw(tt[3], fs, 700)
								if tt[2]:
									tx -= ww / 2
								var f := fnt(700)
								var n := maxi(1, roundi(fs * K))
								ci.draw_string(f, Vector2(tx, dr.position.y + tt[1] * k) * K, tt[3], HORIZONTAL_ALIGNMENT_LEFT, -1, n, INK)
						"li":
							ci.draw_circle(Vector2(qx + 8, qy + 14 * 0.7) * K, 2.2 * K, Color("#4a321c"), true, -1.0, true)
							draw_lines(ci, q[2], qx + 20, qy, 14, 1.4, 500, 800, Color("#4a321c"))
						"pp":
							draw_lines(ci, q[2], qx, qy, 14, 1.4, 500, 800, Color("#4a321c"))
			"note":
				var nr := Rect2(o.x + op[3], y, op[4], op[2].size() * 12.5 * 1.4 + 18)
				box(ci, nr, Color("#fbefd3"), 12)
				draw_lines(ci, op[2], nr.position.x + 11, y + 9, 12.5, 1.4, 500, 800, INK2)
			"row":
				# hàng cài đặt
				var lb: Array = op[2]
				var sm: Array = op[3]
				var yy := draw_lines(ci, lb, o.x + op[5], y + 11, 15, 1.25, 700, 700, INK)
				if sm.size():
					draw_lines(ci, sm, o.x + op[5], yy + 2, 12.5, 1.35, 500, 500, INK2)
				if op[4]:
					var ly: float = y + op[6] - 0.5
					var xx: float = o.x + op[5]
					while xx < o.x + op[5] + op[7]:
						ci.draw_line(Vector2(xx, ly) * K, Vector2(minf(xx + 3, o.x + op[5] + op[7]), ly) * K, LINE, maxf(1.0, K))
						xx += 6
			"segbg":
				box(ci, Rect2(o.x + op[2], y, op[3], op[4]), Color("#f1e2c2"), 12)
			"end":
				_draw_end_top(ci, o, op)
	for it in ci.ov.items:
		var r: Rect2 = it.r
		if it.get("scroll", false):
			r.position.y -= sc
		if not _visible(r, clip, 0) and it.id != "x":
			continue
		var down: bool = ci.pressed_id() == it.id
		if it.id == "x":
			var rr := r
			if down:
				rr.position.y += 2
			box(ci, rr, CREAM, 99, [3 if not down else 1, Color("#e2cfa6")], SH if not down else [])
			icon(ci, "x", INK, Rect2(rr.position.x + 7, rr.position.y + 7, 22, 22))
		elif it.has("btn"):
			_btn(ci, r, it.btn, it.get("kind", ""), it.get("sm", false), down)
		elif it.has("seg"):
			var on: bool = it.on
			if on:
				box(ci, r, Color.WHITE, 9, [], [[0, 2, 5, Color(90 / 255.0, 60 / 255.0, 20 / 255.0, 0.15)]])
			text(ci, it.seg, r.position.x, r.position.y, 13, 700, INK if on else INK2, r.size.y / 13, "center", r.size.x)

# ------------------------------------------------------------ Cài đặt
const SETS := [
	["grp", "Luật chơi"],
	["mo", "Luật mở", "Bên kia mở chỗ cho mình gánh thì bắt buộc phải gánh", [["1", "Bật"], ["0", "Tắt"]]],
	["quiet", "Hòa khi không ai ăn", "Sau bao nhiêu lượt liền mỗi bên không ăn được quân nào", [["25", "25"], ["40", "40"], ["0", "Không hòa"]]],
	["first", "Ai đi trước", "Khi đấu với máy", [["me", "Mình"], ["ai", "Máy"], ["rnd", "Bốc thăm"]]],
	["grp", "Chơi cho sướng"],
	["hint", "Gợi ý nước ăn", "Vòng phấn vàng và chữ \"gánh 2\", \"vây 1\" ở chỗ đi được", [["1", "Bật"], ["0", "Tắt"]]],
	["speed", "Tốc độ", "", [["0.7", "Chậm"], ["1", "Vừa"], ["1.6", "Nhanh"]]],
	["fx", "Bóng cây lay", "Tắt nếu máy yếu", [["1", "Bật"], ["0", "Tắt"]]],
]

static func _sv(v) -> String:
	if v is float and v == floorf(v):
		return str(int(v))
	return str(v)

func _lay_settings() -> Dictionary:
	var g = game
	var cp := _cpad()
	var cw := minf(520.0, W - 32)
	var px: float = cp[1]
	var iw := cw - px * 2
	var items := []
	var ops := []
	var y: float = cp[0]
	ops.append(["h2", y, "Cài đặt"])
	y += 28 + 4
	for i in SETS.size():
		var R: Array = SETS[i]
		if R[0] == "grp":
			y += 14
			ops.append(["grp", y, R[1], px, iw])
			y += 18 + 4 + 2 + 2
			continue
		var segs: Array = R[3]
		var sw := 6.0 + 3 * (segs.size() - 1)
		var bws := []
		for sg in segs:
			var bw := tw(sg[1], 13, 700) + 20
			bws.append(bw)
			sw += bw
		var lw := iw - sw - 12
		var lb := wrapt(R[1], 15, 700, 700, lw)
		var sm := wrapt(R[2], 12.5, 500, 500, lw) if R[2] != "" else []
		var th := lb.size() * 15 * 1.25 + (2 + sm.size() * 12.5 * 1.35 if sm.size() else 0.0)
		var segh := 13 + 16 + 6.0
		var rh := 22 + maxf(th, segh)
		var last: bool = i == SETS.size() - 1 or SETS[i + 1][0] == "grp"
		ops.append(["row", y + (rh - 22 - th) / 2 - 0, lb, sm, not last, px, rh, iw])
		var sy := y + (rh - segh) / 2
		var sx := px + iw - sw
		ops.append(["segbg", sy, sx, sw, segh])
		var bx := sx + 3
		var cur := _sv(g.S[R[0]])
		for j in segs.size():
			var k: String = R[0]
			var v: String = segs[j][0]
			items.append({"r": Rect2(bx, sy + 3, bws[j], segh - 6), "tap": _set_opt.bind(k, v), "id": k + "=" + v, "scroll": true, "seg": segs[j][1], "on": cur == v})
			bx += bws[j] + 3
		y += rh
	if g.Gm.started:
		var note := wrapt("Đổi luật sẽ áp dụng từ ván sau.", 12.5, 500, 800, iw - 22)
		y += 10
		ops.append(["note", y, note, px, iw])
		y += note.size() * 12.5 * 1.4 + 18
	y += cp[2]
	var fr := _card_frame(520, y)
	for it in items:
		it.r.position += fr.position
	items.append({"r": Rect2(fr.end.x - 12 - 36, fr.position.y + 12, 36, 36), "tap": _close_x, "id": "x"})
	return {"frame": fr, "h": y, "items": items, "draw": _draw_doc.bind(ops)}

func _set_opt(k: String, v: String) -> void:
	var g = game
	if k == "first":
		g.S[k] = v
	elif k == "speed":
		g.S[k] = float(v)
	else:
		g.S[k] = int(v)
	g.store_set("cg-set-v1", g.S)
	g.snd.sel()
	if k == "fx":
		g.shade_enable(bool(int(v)))
	_lay("settings")

# ------------------------------------------------------------ Hết ván
func end_info(av: String, title: String, why: String, s: Dictionary, w: int) -> void:
	_end = {"av": av, "title": title, "why": why, "s": s, "w": w}
	_rew = null

func set_reward(xu: int, left: int, mx: int) -> void:
	_rew = {"xu": xu, "left": left, "max": mx}
	if cur_ov == "end":
		_lay("end")

func _lay_end() -> Dictionary:
	var g = game
	var cp := _cpad()
	var cw := minf(520.0, W - 32)
	var px: float = cp[1]
	var iw := cw - px * 2
	var items := []
	var ops := []
	var y: float = cp[0]
	if _end.is_empty():
		return {"frame": _card_frame(520, 100), "h": 100.0, "items": [], "draw": _draw_doc.bind([])}
	var st: Dictionary = _end.s
	var tl := wrapt(_end.title, 28, 800, 800, iw)
	var sub := wrapt(_end.why, 13, 600, 600, iw)
	var info := {"av_y": y}
	y += 96 + 6
	info.t_y = y
	info.tl = tl
	y += tl.size() * 28 + 4
	info.s_y = y + 4
	info.sub = sub
	y += 4 + sub.size() * 13 * 1.4 + 14 - 6
	if _rew != null:
		var b := ("+%d xu gửi về vườn" % _rew.xu) if _rew.xu > 0 else "Hết lượt thưởng hôm nay"
		var sm := (("Hôm nay còn %d ván thắng có thưởng" % _rew.left) if _rew.left > 0 else "Hết lượt thưởng hôm nay, mai chơi tiếp nghen") if _rew.xu > 0 else "Mỗi ngày thắng máy %d ván đầu được xu, mai quay lại nghen" % int(_rew.max)
		var sml := wrapt(sm, 12.5, 600, 600, iw - 32)
		var rw := maxf(tw(b, 20, 800), 0.0)
		for ln in sml:
			rw = maxf(rw, line_w(ln, 12.5, 600, 600))
		rw = minf(iw, rw + 32)
		var rh := 8 + 20 * 1.1 + 2 + sml.size() * 12.5 * 1.3 + 8
		info.rew = {"y": y + 8, "b": b, "sm": sml, "w": rw, "h": rh}
		y += 8 + rh
	info.tb_y = y + 12
	y += 12 + 15 * 1.1 + 12 + 5 * (14 * 1.2 + 17) + 22 + 17 + 16
	var bh := btn_h()
	var bw := (iw - 10) / 2
	if iw >= 410:
		items.append({"r": Rect2(px, y, bw, bh), "tap": _again, "id": "again", "scroll": true, "btn": "Ván mới"})
		items.append({"r": Rect2(px + bw + 10, y, bw, bh), "tap": _to_menu, "id": "tomenu", "scroll": true, "btn": "Đổi đối thủ", "kind": "w"})
		y += bh
	else:
		items.append({"r": Rect2(px, y, iw, bh), "tap": _again, "id": "again", "scroll": true, "btn": "Ván mới"})
		y += bh + 10
		items.append({"r": Rect2(px, y, iw, bh), "tap": _to_menu, "id": "tomenu", "scroll": true, "btn": "Đổi đối thủ", "kind": "w"})
		y += bh
	y += cp[2]
	ops.append(["end", 0.0, info, px, iw])
	var fr := _card_frame(520, y)
	for it in items:
		it.r.position += fr.position
	return {"frame": fr, "h": y, "items": items, "draw": _draw_doc.bind(ops)}

func _again() -> void:
	game.ai_token += 1
	game.new_game()

func _to_menu() -> void:
	game.Gm.started = false
	show_ov("menu")

func _draw_end_top(ci: W_, o: Vector2, op: Array) -> void:
	var g = game
	var info: Dictionary = op[2]
	var px: float = op[3]
	var iw: float = op[4]
	var cw := iw + px * 2
	var ar := Rect2(o.x + (cw - 96) / 2, o.y + info.av_y, 96, 96)
	box(ci, ar, Color("#f3dfb5"), 24)
	avatar(ci, _end.av, ar)
	ring_in(ci, ar, 24, 3, Color("#e6c98f"))
	draw_lines(ci, info.tl, o.x + px, o.y + info.t_y, 28, 1.0, 800, 800, INK, Color(0, 0, 0, 0), "center", iw)
	draw_lines(ci, info.sub, o.x + px, o.y + info.s_y, 13, 1.4, 600, 600, INK2, Color(0, 0, 0, 0), "center", iw)
	if info.has("rew"):
		var rw: Dictionary = info.rew
		var rr := Rect2(o.x + (cw - rw.w) / 2, o.y + rw.y, rw.w, rw.h)
		box(ci, rr, Color("#fbefd3"), 14)
		ring_in(ci, rr, 14, 1.5, Color("#e7c77a"))
		text(ci, rw.b, rr.position.x, rr.position.y + 8, 20, 800, Color("#8a5a00"), 1.1, "center", rr.size.x)
		draw_lines(ci, rw.sm, rr.position.x + 16, rr.position.y + 8 + 22 + 2, 12.5, 1.3, 600, 600, INK2, Color(0, 0, 0, 0), "center", rr.size.x - 32)
	# bảng số
	var st: Dictionary = _end.s
	var w: int = _end.w
	var ty: float = o.y + info.tb_y
	var x0 := o.x + px
	var c1w := iw * 0.4
	var c2w := iw * 0.3
	var hh := 15 * 1.1 + 12
	for p in [0, 1]:
		var cx: float = x0 + c1w + p * c2w
		var nm: String = ellip(g.Gm.names[p], 15, 800, c2w - 30)
		var ww := 17 + 5 + tw(nm, 15, 800)
		var sx: float = cx + (c2w - ww) / 2
		pk(ci, p, Rect2(sx, ty + 6 + (15 * 1.1 - 17) / 2, 17, 17))
		text(ci, nm, sx + 22, ty + 6, 15, 800, INK2, 1.1)
		ci.draw_rect(Rect2(Vector2(cx + 2, ty + hh - 3) * K, Vector2(c2w - 4, 3) * K), PC[p])
	ty += hh
	var rows := [["Lần gánh", st.ganh[0], st.ganh[1]], ["Lần vây", st.vay[0], st.vay[1]], ["Quân ăn được", st.took[0], st.took[1]], ["Số nước đi", ceili(st.ply / 2.0), floori(st.ply / 2.0)]]
	var rh := 14 * 1.2 + 16
	for row in rows:
		var yy := ty
		while yy < 0:
			break
		var xx := x0
		while xx < x0 + iw:
			ci.draw_line(Vector2(xx, ty) * K, Vector2(minf(xx + 3, x0 + iw), ty) * K, LINE, maxf(1.0, K))
			xx += 6
		text(ci, row[0], x0 + 4, ty + 8, 14, 600, INK2, 1.2)
		text(ci, str(int(row[1])), x0 + c1w, ty + 8, 14, 600, INK, 1.2, "center", c2w)
		text(ci, str(int(row[2])), x0 + c1w + c2w, ty + 8, 14, 600, INK, 1.2, "center", c2w)
		ty += rh
	ci.draw_rect(Rect2(Vector2(x0, ty) * K, Vector2(iw, 2) * K), LINE)
	text(ci, "Quân còn", x0 + 4, ty + 8, 22, 800, RED2, 1.0)
	for p in [0, 1]:
		text(ci, str(E.count(st.b, p)), x0 + c1w + p * c2w, ty + 8, 22, 800, BRICK if w == p else RED2, 1.0, "center", c2w)

# ============================================================ mỗi khung
func _process(dt: float) -> void:
	var g = game
	if g == null:
		return
	var Gm: Dictionary = g.Gm
	if _toast.t < 1.7:
		_toast.t += dt
		toast_w.queue_redraw()
	if _bub.txt != "":
		_bub.t += dt
		var want := 1.0 if _bub.t < 2.6 else 0.0
		var na: float = move_toward(_bub.a, want, dt / 0.22)
		if na != _bub.a:
			_bub.a = na
			bub.queue_redraw()
	var ffw := 1.0 if _ff_on else 0.0
	if _ff_a != ffw:
		_ff_a = move_toward(_ff_a, ffw, dt / 0.2)
		ff.queue_redraw()
	for p in [0, 1]:
		var turn: bool = Gm.s != null and not Gm.s.over and Gm.s.turn == p and Gm.started
		var ca: float = move_toward(_card_a[p], 1.0 if turn else 0.86, dt / 0.25)
		var ta: float = move_toward(_tag_a[p], 1.0 if turn else 0.0, dt / 0.2)
		if ca != _card_a[p] or ta != _tag_a[p] or (turn and Gm.aiWaiting):
			_card_a[p] = ca
			_tag_a[p] = ta
			cards[p].queue_redraw()
	if cur_ov != "" and _ov_t < 0.4:
		_ov_t += dt
		ovs[cur_ov].queue_redraw()
	# chạm vô hướng dẫn (ngoài nút) không lọt xuống bàn khi có nút
	if coach_w.mouse_filter == Control.MOUSE_FILTER_STOP and coach_w.has_meta("hit"):
		pass
