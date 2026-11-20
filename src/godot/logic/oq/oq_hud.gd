extends Control
# Ô ĂN QUAN: giao diện trên sân (shell.html của bản web o-an-quan/src): thanh nút ván gỗ góc trên trái, thẻ hai người
# chơi (bảng con viết phấn trong khung gỗ), bong bóng nói giấy dó, chữ to giữa bàn, hướng dẫn ván đầu (bảng con),
# nút tua nhanh (gỗ), bảng Menu / Luật chơi / Cài đặt / Hết ván (giấy dó trong khung tre, nút sơn như bảng hiệu).
# Số đo lấy từ CSS của web (css px, nhân K ra điểm ảnh). Chữ Baloo 2.

const A := preload("res://logic/oq/oq_art.gd")
const E := preload("res://logic/oq/oq_engine.gd")

const INK := Color("#3a2412")
const INK2 := Color("#6a4a2c")
const LINE := Color("#dcc08a")
const GOLD := Color("#f2c14e")
const WD := Color("#4a2a10")
const WD2 := Color("#2e1806")
const BRICK := Color("#b5452a")
const BRICK2 := Color("#6e2210")
const LEAFG := Color("#4f8a2e")
const LEAFG2 := Color("#24500f")
const CHALK := Color("#f3efe2")
const CREAMW := Color("#fbeed0")
const FRAME := Color("#7a4a24")
const TAN := Color("#d4b888")
const PC := [Color("#56aae8"), Color("#f07a92")]
const PCD := [Color("#2f7fbf"), Color("#c64662")]
const BAM := 15.0    # bề dày khung tre của thẻ

var game   # oq_game
var K := 1.0
var W := 0.0
var H := 0.0
var port := false
var tools: W_ = null
var cards: Array = []
var bub: W_ = null
var toast_w: W_ = null
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
var _card_a := [0.92, 0.92]
var _tag_a := [0.0, 0.0]
var _ov_t := 0.0

# ------------------------------------------------------------ một khối vẽ + bấm (thay cho phần tử DOM)
class W_ extends Control:
	var fn_draw: Callable
	var items: Array = []     # [{r: Rect2 (css), tap: Callable, id}]
	var K := 1.0
	var scroll := 0.0
	var max_scroll := 0.0
	var on_bg: Callable       # chạm ra ngoài thẻ (lớp phủ)
	var items_only := false   # chỉ bắt chạm trúng nút (khối phủ cả màn để vẽ)
	var ov: Control = null    # khối giữ nút (thân thẻ vẽ, lớp phủ bắt chạm)
	var hit_r := Rect2()      # chạm trong vùng này không lọt ra on_bg
	var _press = null
	var _drag := false
	var _y0 := 0.0
	var _s0 := 0.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
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
		return _hit(p / K) != null or (hit_r.size.x > 0 and hit_r.has_point(p / K))
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
					for c in get_children():
						c.queue_redraw()
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
			_redraw_all()
		elif kind == "move":
			if max_scroll > 0 and absf(p.y - _y0) > 8:
				_drag = true
				_press = null
			if _drag:
				scroll = clampf(_s0 - (p.y - _y0), 0.0, max_scroll)
				_redraw_all()
		else:
			var it = _press
			_press = null
			_redraw_all()
			if _drag:
				_drag = false
				return
			var h = _hit(p)
			if it != null and h == it and it.tap.is_valid():
				it.tap.call()
			elif it == null and h == null and on_bg.is_valid() and not (hit_r.size.x > 0 and hit_r.has_point(p)):
				on_bg.call()
	func _redraw_all() -> void:
		queue_redraw()
		for c in get_children():
			if c is CanvasItem:
				c.queue_redraw()

# ------------------------------------------------------------ chữ
func fnt(w: int) -> Font:
	return A.font(w)

func tw(s: String, fs: float, w: int, ls := 0.0) -> float:
	return fnt(w).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(1, roundi(fs * K))).x / K + ls * s.length()

func spw(fs: float, w: int) -> float:   # bề rộng dấu cách trong dòng (đo riêng bị làm tròn)
	return (tw("n          n", fs, w) - tw("nn", fs, w)) / 10.0

func base_y(top: float, fs: float, lh: float, w: int) -> float:
	# đường chân chữ của một dòng css (line-height lh): vùng chữ (ascent + descent) nằm giữa dòng
	var f := fnt(w)
	var n := maxi(1, roundi(fs * K))
	var a := f.get_ascent(n) / K
	var d := f.get_descent(n) / K
	return top + (fs * lh - (a + d)) / 2 + a

func text(ci: CanvasItem, s: String, x: float, top: float, fs: float, w: int, col: Color, lh := 1.2, al := "left", width := 0.0, shd := Color(0, 0, 0, 0), sho := Vector2(0, 1)) -> void:
	var f := fnt(w)
	var n := maxi(1, roundi(fs * K))
	var tx := x
	if al != "left":
		var ww := tw(s, fs, w)
		tx = x + (width - ww) * (0.5 if al == "center" else 1.0)
	var by := base_y(top, fs, lh, w)
	if shd.a > 0:
		ci.draw_string(f, Vector2(tx + sho.x, by + sho.y) * K, s, HORIZONTAL_ALIGNMENT_LEFT, -1, n, shd)
	ci.draw_string(f, Vector2(tx, by) * K, s, HORIZONTAL_ALIGNMENT_LEFT, -1, n, col)

func ellip(s: String, fs: float, w: int, maxw: float) -> String:
	if tw(s, fs, w) <= maxw:
		return s
	while s.length() > 1 and tw(s + "…", fs, w) > maxw:
		s = s.substr(0, s.length() - 1)
	return s + "…"

# chữ nhiều dòng: **đậm**, {x:đậm xanh} {h:đậm hồng}. Một từ = các đoạn [chữ, đậm, màu] dính liền
const MARK_COL := {"x": Color("#2f7fbf"), "h": Color("#c64662")}
func _words(src: String) -> Array:
	var out := []
	var bold := false
	var colk := ""
	for wd in src.split(" ", false):
		var segs := []
		var cur := ""
		var i := 0
		while i < wd.length():
			if wd.substr(i, 2) == "**":
				if cur != "":
					segs.append([cur, bold, colk])
				cur = ""
				bold = not bold
				i += 2
				continue
			if wd[i] == "{" and i + 2 < wd.length() and wd[i + 2] == ":":
				if cur != "":
					segs.append([cur, bold, colk])
				cur = ""
				colk = wd[i + 1]
				i += 3
				continue
			if wd[i] == "}" and colk != "":
				if cur != "":
					segs.append([cur, bold, colk])
				cur = ""
				colk = ""
				i += 1
				continue
			cur += wd[i]
			i += 1
		if cur != "":
			segs.append([cur, bold, colk])
		if segs.size():
			out.append(segs)
	return out

func _sw(sg: Array, fs: float, w0: int, w1: int) -> int:
	return w1 if (sg[1] or sg[2] != "") else w0

func _ww(wd: Array, fs: float, w0: int, w1: int) -> float:
	var x := 0.0
	for sg in wd:
		x += tw(sg[0], fs, _sw(sg, fs, w0, w1))
	return x

func wrapt(src: String, fs: float, w0: int, w1: int, maxw: float) -> Array:
	var lines := []
	var cur := []
	for wd in _words(src):
		if cur.size() and line_w(cur + [wd], fs, w0, w1) > maxw:
			lines.append(cur)
			cur = []
		cur.append(wd)
	if cur.size():
		lines.append(cur)
	return lines

# đo cả dòng một lần (đo từng chữ rời thì mỗi chữ bị làm tròn lên, dòng dài hơn web)
func line_w(ln: Array, fs: float, w0: int, w1: int) -> float:
	var x := tw(line_s(ln), fs, w0)
	for wd in ln:
		for sg in wd:
			var w := _sw(sg, fs, w0, w1)
			if w != w0:
				x += tw(sg[0], fs, w) - tw(sg[0], fs, w0)
	return x

func line_s(ln: Array) -> String:
	return " ".join(ln.map(func(wd): return "".join(wd.map(func(sg): return sg[0]))))

func draw_lines(ci: CanvasItem, lines: Array, x: float, top: float, fs: float, lh: float, w0: int, w1: int, col: Color, col_b := Color(0, 0, 0, 0), al := "left", width := 0.0) -> float:
	var sp := spw(fs, w0)
	var y := top
	for ln in lines:
		var xx := x
		if al == "center":
			xx = x + (width - line_w(ln, fs, w0, w1)) / 2
		for i in ln.size():
			if i:
				xx += sp
			for sg in ln[i]:
				var ww := _sw(sg, fs, w0, w1)
				var c := col
				if sg[2] != "":
					c = MARK_COL[sg[2]]
				elif sg[1] and col_b.a > 0:
					c = col_b
				text(ci, sg[0], xx, y, fs, ww, c, lh)
				xx += tw(sg[0], fs, ww)
		y += fs * lh
	return y

# ------------------------------------------------------------ hộp
func box(ci: CanvasItem, r: Rect2, bg: Color, rad: float, bev := [], sh := [], ring := []) -> void:
	A.box(ci, Rect2(r.position * K, r.size * K), bg, rad, K, bev, sh, ring)

func ring_in(ci: CanvasItem, r: Rect2, rad: float, w: float, col: Color) -> void:
	# box-shadow: inset 0 0 0 w col / border
	var sb: StyleBoxFlat = A._sbox("ri" + str(rad) + str(w) + str(col) + str(K))
	sb.draw_center = false
	sb.set_border_width_all(maxi(1, roundi(w * K)))
	sb.border_color = col
	sb.set_corner_radius_all(int(rad * K))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, Rect2(r.position * K, r.size * K))

func inset_tb(ci: CanvasItem, r: Rect2, rad: float, tw_: float, tc: Color, bw: float, bc: Color) -> void:
	# box-shadow: inset 0 tw 0 tc, inset 0 -bw 0 bc (gờ sáng trên, gờ tối dưới)
	var sb: StyleBoxFlat = A._sbox("it" + str(rad) + str(tw_) + str(tc) + str(bw) + str(bc) + str(K))
	sb.draw_center = false
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_top = roundi(tw_ * K)
	sb.border_width_bottom = roundi(bw * K)
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.set_corner_radius_all(int(rad * K))
	sb.anti_aliasing = true
	if tw_ > 0:
		sb.border_color = tc
		ci.draw_style_box(sb, Rect2(r.position * K, r.size * K))
	if bw > 0 and tw_ > 0:
		var sb2: StyleBoxFlat = sb.duplicate()
		sb2.border_width_top = 0
		sb2.border_color = bc
		ci.draw_style_box(sb2, Rect2(r.position * K, r.size * K))
	elif bw > 0:
		sb.border_color = bc
		ci.draw_style_box(sb, Rect2(r.position * K, r.size * K))

# ảnh lặp: gỗ (cỡ 256 hoặc 200), bảng con, giấy dó
func tex(ci: CanvasItem, r: Rect2, name: String, tile: float, rad: float, mod := Color.WHITE) -> void:
	A.tex_box(ci, Rect2(r.position * K, r.size * K), name, tile * K, rad * K, mod, r.position * K)

func solid_sh(ci: CanvasItem, r: Rect2, rad: float, dy: float, col: Color, spread := 0.0) -> void:
	# box-shadow: 0 dy 0 spread col (bóng đặc lệch xuống, không mờ)
	box(ci, Rect2(r.position + Vector2(-spread, dy - spread), r.size + Vector2(spread, spread) * 2), col, rad + spread)

# ván gỗ có viền: background gỗ, border 2 màu wd2
func wood(ci: CanvasItem, r: Rect2, rad: float, bw: float, tile := 256.0) -> void:
	tex(ci, r, "uiwood", tile, rad)
	ring_in(ci, r, rad, bw, WD2)

func avatar(ci: CanvasItem, k: String, r: Rect2) -> void:
	# chân dung phấn tràn ra ngoài khung một chút (overflow: visible của web)
	var rr := Rect2(r.get_center() - r.size * A.AV_PAD / 2, r.size * A.AV_PAD)
	var t := A.svg(A.avatar(k), roundi(rr.size.x * K))
	if t != null:
		ci.draw_texture_rect(t, Rect2(rr.position * K, rr.size * K), false)

func icon(ci: CanvasItem, k: String, col: Color, r: Rect2, shd := false) -> void:
	var t := A.icon(k, "#" + col.to_html(false), roundi(r.size.x * K))
	if t == null:
		return
	if shd:
		var ts := A.icon(k, "#000000", roundi(r.size.x * K))
		ci.draw_texture_rect(ts, Rect2((r.position + Vector2(0, 1)) * K, r.size * K), false, Color(1, 1, 1, 0.4 * col.a))
	ci.draw_texture_rect(t, Rect2(r.position * K, r.size * K), false, Color(1, 1, 1, col.a))

func qdot(ci: CanvasItem, k: int, c: Vector2) -> void:
	# hòn quan nhỏ trong dòng điểm (.qd): elip 11x9 tô tròn, viền trắng mờ
	var pts := PackedVector2Array()
	for q in 24:
		var a := TAU * q / 24.0
		pts.append((c + Vector2(cos(a) * 5.5, sin(a) * 4.5)) * K)
	var pts2 := PackedVector2Array()
	for q in 24:
		var a := TAU * q / 24.0
		pts2.append((c + Vector2(cos(a) * 6.5, sin(a) * 5.5)) * K)
	ci.draw_colored_polygon(pts2, Color(1, 1, 1, 0.5))
	var c0 := Color("#d79a74") if k else Color("#8a8e98")
	var c1 := Color("#7a3c22") if k else Color("#2f3238")
	var cols := PackedColorArray()
	var hl := c + Vector2(-5.5 * 0.3, -4.5 * 0.4)
	for p in pts:
		cols.append(c0.lerp(c1, clampf((p / K - hl).length() / 7.0, 0.0, 1.0)))
	ci.draw_polygon(pts, cols)

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
	menu_level = int(game.store.get("oaq-lvl", 1))
	cards = [mk(), mk()]
	for p in [0, 1]:
		var c: W_ = cards[p]
		c.fn_draw = _draw_card.bind(p)
	tools = mk()
	tools.mouse_filter = Control.MOUSE_FILTER_STOP
	tools.fn_draw = _draw_tools
	bub = mk()
	bub.fn_draw = _draw_bub
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
		le.placeholder_text = "Người 1" if p == 0 else "Người 2"
		le.text = String(game.store.get("oaq-n" + str(p), ""))
		le.mouse_filter = Control.MOUSE_FILTER_IGNORE
		le.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		le.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		le.add_theme_font_override("font", fnt(600))
		le.add_theme_font_size_override("font_size", roundi(15 * K))
		le.add_theme_color_override("font_color", INK)
		le.add_theme_color_override("font_placeholder_color", Color(INK2, 0.6))
		le.add_theme_color_override("caret_color", INK)
		le.focus_entered.connect(func(): _redraw_ov("menu"))
		le.focus_exited.connect(func(): _redraw_ov("menu"))
		le.visible = false
		ovs.menu.get_meta("body").add_child(le)
		names_le.append(le)

func _redraw_ov(id: String) -> void:
	ovs[id].queue_redraw()
	ovs[id].get_meta("body").queue_redraw()

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
	# thanh nút: một tấm ván (viền 2, đệm 4, nút cách 2)
	tb_lab = W >= 1100
	tb_h = 40.0; tb_min = 40.0; tb_pad = 10.0 if tb_lab else 9.0; tb_ico = 21.0
	if W <= 520:
		tb_h = 36.0; tb_min = 36.0; tb_pad = 7.0
	if H <= 430:
		tb_h = 34.0; tb_min = 34.0; tb_pad = 7.0; tb_ico = 19.0
	var lst := [["home", "home", "Về vườn"], ["menu", "menu", "Menu"], ["undo", "undo", "Đi lại"], ["rules", "rules", "Luật"], ["set", "set", "Cài đặt"], ["snd", "snd", "Âm thanh"]]
	tb_btns = []
	var x := 6.0
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
	var tw_ := x - 2 + 6
	tools.position = Vector2(10, 10) * K
	tools.size = Vector2(tw_, tb_h + 12) * K
	tools.items = []
	for b in tb_btns:
		tools.items.append({"r": Rect2(b.x, 6, b.w, tb_h), "tap": _tool.bind(b.k), "id": b.k})
	# thẻ người chơi: bảng con trong khung gỗ
	var big := W >= 1100 and H >= 700
	pcm = {"w": 248.0, "pad": [7.0, 14.0, 7.0, 7.0], "gap": 10.0, "av": 50.0, "nm": 20.0, "st": 13.5, "br": 12.5, "pts": 34.0, "small": 12.0, "bd": 6.0, "brs": true, "tagx": 64.0, "tagf": 12.5}
	if big:
		pcm.merge({"w": 300.0, "pad": [9.0, 16.0, 9.0, 9.0], "gap": 12.0, "av": 62.0, "tagx": 78.0}, true)
	if W <= 520:
		pcm.merge({"w": 214.0, "pad": [6.0, 10.0, 6.0, 6.0], "gap": 8.0, "av": 50.0, "nm": 17.0, "pts": 29.0, "st": 12.5, "br": 11.5, "bd": 5.0}, true)
	if H <= 430:
		pcm.merge({"w": 206.0, "pad": [5.0, 10.0, 5.0, 5.0], "gap": 8.0, "av": 46.0, "nm": 16.0, "pts": 26.0, "bd": 4.0, "brs": false}, true)
	for p in [0, 1]:
		var cw: float = minf(pcm.w, W - 20)
		if p == 1 and W <= 520:
			cw = minf(cw, W - 150)
		var pad: Array = pcm.pad.duplicate()
		if p == 1 and W <= 520:
			pad[0] = 13.0
		var txh: float = pcm.nm * 1.05 + 4 + 3 + pcm.st * 1.15 + (4 + maxf(12.0, pcm.br) if pcm.brs else 0.0)
		var ptsh: float = pcm.pts * 0.95 + 3 + pcm.small
		var ch: float = 2 * pcm.bd + pad[0] + pad[2] + maxf(maxf(pcm.av, txh), ptsh)
		var r := Rect2(10, H - 10 - ch, cw, ch) if p == 0 else Rect2(W - 10 - cw, 10, cw, ch)
		var c: W_ = cards[p]
		c.set_meta("pad", pad)
		c.set_meta("r", r)
		c.position = (r.position - Vector2(26, 26)) * K
		c.size = (r.size + Vector2(52, 52)) * K
	ff.size = Vector2(W, H) * K
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
		g.store_set("oaq-set-v1", g.S)
		g.snd.on = bool(int(g.S.sound))
		if g.snd.on:
			g.snd.sel()
		tools.queue_redraw()

func undo_ok() -> bool:
	var g = game
	var Gm: Dictionary = g.Gm
	return Gm.hist.size() > 0 and not Gm.busy and Gm.s != null and not Gm.s.over and g.is_human(Gm.s.turn) and (Gm.mode != "ai" or Gm.undoLeft > 0)

func _draw_tools(ci: W_) -> void:
	var r := Rect2(0, 0, ci.size.x / K, ci.size.y / K - 4)
	# bóng: 0 4px 0 wd2, 0 10px 18px
	box(ci, r, Color(0, 0, 0, 0), 14, [], [[0, 10, 18, Color(30 / 255.0, 15 / 255.0, 0, 0.3)]])
	solid_sh(ci, r, 14, 4, WD2)
	wood(ci, r, 14, 2)
	inset_tb(ci, r.grow(-2), 12, 1, Color(1, 220 / 255.0, 170 / 255.0, 0.35), 3, Color(0, 0, 0, 0.25))
	var pid = ci.pressed_id()
	for b in tb_btns:
		var br := Rect2(b.x, 6, b.w, tb_h)
		var dis: bool = b.k == "undo" and not undo_ok()
		if pid == b.k and not dis:
			box(ci, br, Color(0, 0, 0, 0.15), 12)
		var col := Color(CREAMW, 0.42) if dis else CREAMW
		var ico: String = b.ico
		if b.k == "snd" and not int(game.S.sound):
			ico = "mute"
		var iw := tb_ico
		var cx := br.position.x + tb_pad
		if not tb_lab:
			cx = br.position.x + (br.size.x - iw) / 2
		icon(ci, ico, col, Rect2(cx, br.position.y + (tb_h - iw) / 2, iw, iw), true)
		if tb_lab:
			text(ci, b.lab, cx + iw + 6, br.position.y, 13.5, 700, col, tb_h / 13.5, "left", 0.0, Color(0, 0, 0, 0.45 * col.a))
		if b.k == "undo" and game.Gm.mode == "ai" and game.Gm.started:
			var n := str(game.Gm.undoLeft)
			var bw := maxf(15.0, tw(n, 10, 700) + 6)
			var bx: float = (cx + iw + 6 + tw(b.lab, 13.5, 700) + 6 - 2) if tb_lab else (br.end.x - 1 - bw)
			var by: float = (br.position.y + (tb_h - 15) / 2) if tb_lab else br.position.y + 2
			box(ci, Rect2(bx, by + 1, bw, 15), Color(0, 0, 0, 0.4), 8)
			box(ci, Rect2(bx, by, bw, 15), Color(GOLD, 0.45) if dis else GOLD, 8)
			text(ci, n, bx, by, 10, 700, WD2, 1.5, "center", bw)

# ------------------------------------------------------------ thẻ người chơi (bảng con viết phấn)
func setup_cards() -> void:
	layout(W, H, port)
	update_cards()

func _status(p: int) -> String:
	var g = game
	var Gm: Dictionary = g.Gm
	var turn: bool = Gm.s != null and not Gm.s.over and Gm.s.turn == p and Gm.started
	var short: bool = port or W < 900
	if Gm.s != null and Gm.s.over:
		return "Hết ván"
	if turn:
		if not g.is_human(p):
			return "@dots" if Gm.aiWaiting else "đang rải…"
		if Gm.busy:
			return "đang rải…"
		if Gm.sel >= 0:
			return "Chọn hướng" if short else "Chọn hướng rải nghen"
		return "Bốc ô sáng" if short else "Bốc ô đang sáng"
	if Gm.mode == "ai" and p == 1:
		return "Mức " + String(g.OPP[Gm.level].lvl).to_lower()
	if port:
		return "Hàng bên trái" if p == 0 else "Hàng bên phải"
	return "Hàng dưới" if p == 0 else "Hàng trên"

func _draw_card(ci: W_, p: int) -> void:
	var g = game
	var Gm: Dictionary = g.Gm
	var v = Gm.vis if Gm.vis != null else Gm.s
	if v == null:
		return
	var r0: Rect2 = ci.get_meta("r")
	var r := Rect2(Vector2(26, 26), r0.size)
	var pad: Array = ci.get_meta("pad")
	var bd: float = pcm.bd
	var turn: bool = Gm.s != null and not Gm.s.over and Gm.s.turn == p and Gm.started
	ci.modulate.a = _card_a[p]
	# bóng, vòng vàng khi tới phiên
	box(ci, r, Color(0, 0, 0, 0), 14, [], [[0, 10, 22, Color(20 / 255.0, 10 / 255.0, 0, 0.35)]])
	if turn:
		box(ci, r, Color(0, 0, 0, 0), 14, [], [[0, 0, 22, Color(GOLD, 0.55)]])
	solid_sh(ci, r, 14, 3, WD2)
	if turn:
		box(ci, r.grow(3), GOLD, 17)
	# khung gỗ (cỡ 200) rồi mặt bảng con (cỡ 256) bên trong viền
	tex(ci, r, "uiwood", 200, 14)
	var inner := r.grow(-bd)
	tex(ci, inner, "uislate", 256, maxf(0.0, 14 - bd))
	var cb := Rect2(inner.position + Vector2(pad[3], pad[0]), inner.size - Vector2(pad[1] + pad[3], pad[0] + pad[2]))
	# chân dung phấn: quầng phấn mờ phía sau, không khung
	var av: float = pcm.av
	var ar := Rect2(cb.position.x, cb.position.y + (cb.size.y - av) / 2, av, av)
	var gl := A.atlas
	ci.draw_texture_rect_region(gl, Rect2(ar.position * K, ar.size * K), A.R_GLOW, Color(CHALK, 0.1))
	avatar(ci, Gm.av[p], ar)
	# ô điểm bên phải
	var sc := str(g.score_of(v, p))
	var ptsw := maxf(tw(sc, pcm.pts, 700), tw("điểm", pcm.small, 500)) + 10 + 2
	var px: float = cb.end.x - ptsw
	var midy: float = cb.position.y + cb.size.y / 2
	var hh: float = pcm.pts * 0.95 + 3 + pcm.small
	var yy: float = cb.position.y
	while yy < cb.end.y:
		ci.draw_line(Vector2(px + 1, yy) * K, Vector2(px + 1, minf(yy + 4, cb.end.y)) * K, Color(CHALK, 0.35), 2 * K)
		yy += 7
	var pt_top := midy - hh / 2
	ci.draw_string_outline(fnt(700), Vector2(px + 12 + (ptsw - 12 - tw(sc, pcm.pts, 700)) / 2, base_y(pt_top, pcm.pts, 0.95, 700)) * K, sc, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(pcm.pts * K), maxi(1, roundi(2 * K)), Color(1, 1, 1, 0.18))
	text(ci, sc, px + 12, pt_top, pcm.pts, 700, Color.WHITE, 0.95, "center", ptsw - 12)
	text(ci, "điểm", px + 12, pt_top + pcm.pts * 0.95 + 3, pcm.small, 500, Color("#c9d3c6"), 1.0, "center", ptsw - 12)
	# chữ giữa
	var tx: float = ar.end.x + pcm.gap
	var tww: float = px - pcm.gap - tx
	var txh: float = pcm.nm * 1.05 + 4 + 3 + pcm.st * 1.15 + (4 + maxf(12.0, pcm.br) if pcm.brs else 0.0)
	var ty: float = cb.position.y + (cb.size.y - txh) / 2
	var nm := ellip(Gm.names[p], pcm.nm, 700, tww)
	text(ci, nm, tx, ty + 2, pcm.nm, 700, Color.WHITE, 1.05)
	ci.draw_rect(Rect2(Vector2(tx, ty + 2 + pcm.nm * 1.05 + 2 - 2.5) * K, Vector2(minf(tww, tw(nm, pcm.nm, 700)), 2.5) * K), PC[p])
	ty += pcm.nm * 1.05 + 4 + 3
	var st := _status(p)
	var stc := Color("#c9d3c6")
	if st == "@dots":
		for k in 3:
			var a := 0.25 + 0.75 * maxf(0.0, 1.0 - absf(fposmod(g.clock - k * 0.15, 1.0) - 0.4) / 0.4)
			ci.draw_circle(Vector2(tx + 3.5 + k * 7, ty + pcm.st * 1.15 / 2 + 1) * K, 2.5 * K, Color(stc, a), true, -1.0, true)
		text(ci, " đang tính", tx + 21, ty, pcm.st, 500, stc, 1.15)
	else:
		text(ci, ellip(st, pcm.st, 500, tww), tx, ty, pcm.st, 500, stc, 1.15)
	ty += pcm.st * 1.15
	if pcm.brs:
		# dòng điểm: dân ăn được, quan, nợ
		ty += 4
		var bx := tx
		var lh: float = 12.0 / float(pcm.br)
		var bc := Color("#dfe6da")
		var s1 := "%d dân" % int(v.dan[p])
		text(ci, s1, bx, ty, pcm.br, 500, bc, lh)
		bx += tw(s1, pcm.br, 500) + 4
		var qn := []
		for k in [0, 1]:
			if int(v.qw[k]) == p:
				qn.append(k)
		if qn.size():
			text(ci, "·", bx, ty, pcm.br, 500, bc, lh)
			bx += tw("·", pcm.br, 500) + 4
			for k in qn:
				qdot(ci, k, Vector2(bx + 5.5, ty + 6 + 0.5))
				bx += 11 + 4
			var s2 := "%d quan" % qn.size()
			text(ci, s2, bx, ty, pcm.br, 500, bc, lh)
			bx += tw(s2, pcm.br, 500) + 4
		if int(v.debt[p]):
			text(ci, "· nợ %d" % int(v.debt[p]), bx, ty, pcm.br, 500, Color("#b03a2a"), lh)
	# nhãn "Tới phiên"
	if _tag_a[p] > 0.01:
		var tg := "Tới phiên"
		var tgw := tw(tg, pcm.tagf, 700) + 20 + 3
		var tgh: float = pcm.tagf + 7 + 3
		var off: float = (1.0 - _tag_a[p]) * 4
		var trc := Rect2(inner.position.x + pcm.tagx, inner.position.y - 10 + off, tgw, tgh)
		box(ci, Rect2(trc.position + Vector2(0, 2), trc.size), Color(0, 0, 0, 0.25 * _tag_a[p]), 99)
		box(ci, trc, Color(PCD[p], _tag_a[p]), 99)
		ring_in(ci, trc, 99, 1.5, Color(0, 0, 0, 0.25 * _tag_a[p]))
		text(ci, tg, trc.position.x, trc.position.y + 1.5, pcm.tagf, 700, Color(1, 1, 1, _tag_a[p]), (tgh - 3) / pcm.tagf, "center", tgw)

func update_cards() -> void:
	for c in cards:
		c.queue_redraw()
	tools.queue_redraw()
	coach_w.queue_redraw()
	_lay_coach()

# ------------------------------------------------------------ chữ to giữa bàn, bong bóng nói, tua nhanh
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
	var avx: float = c1.position.x + pcm.bd + pad[3] + pcm.av / 2
	var maxw := minf(300.0, W - 24)
	var lines := wrapt(_bub.txt, 14.5, 600, 600, maxw - 30)
	var bw := 0.0
	for ln in lines:
		bw = maxf(bw, line_w(ln, 14.5, 600, 600))
	bw += 30
	var bh := lines.size() * 14.5 * 1.3 + 20
	var left := clampf(avx - 26, 12, W - bw - 12)
	var top := c1.end.y + 14 - (1 - a) * 4
	var tail := clampf(avx - left - 8, 14, bw - 30)
	ci.modulate.a = a
	var r := Rect2(left, top, bw, bh)
	box(ci, r, Color(0, 0, 0, 0), 14, [], [[0, 2, 0, Color(90 / 255.0, 60 / 255.0, 20 / 255.0, 0.18)], [0, 8, 22, Color(60 / 255.0, 35 / 255.0, 10 / 255.0, 0.22)]])
	# đuôi: ô vuông 12 xoay 45 độ, viền trái + trên
	var tc := Vector2(left + 2 + tail + 6, top + 2 - 8 + 6)
	var d := 6.0 * sqrt(2.0)
	var dia := PackedVector2Array([(tc + Vector2(-d, 0)) * K, (tc + Vector2(0, -d)) * K, (tc + Vector2(d, 0)) * K, (tc + Vector2(0, d)) * K])
	ci.draw_colored_polygon(dia, Color("#b89462"))
	tex(ci, r, "uipaper", 256, 14)
	ring_in(ci, r, 14, 2, Color("#b89462"))
	var d2 := d - 2.0 * sqrt(2.0)
	var dia2 := PackedVector2Array([(tc + Vector2(-d2, 0.7)) * K, (tc + Vector2(0, -d2 + 0.7)) * K, (tc + Vector2(d2, 0.7)) * K, (tc + Vector2(0, d2 + 0.7)) * K])
	ci.draw_colored_polygon(dia2, Color("#fbf3de"))
	draw_lines(ci, lines, left + 15, top + 10, 14.5, 1.3, 600, 600, INK)

func show_ff(on: bool) -> void:
	_ff_on = on
	if not on:
		game.Gm.ff = 1.0
	ff.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_lay_ff_r()
	ff.queue_redraw()

func ff_toggle() -> void:
	game.Gm.ff = 1.0 if game.Gm.ff > 1.0 else 3.2
	_lay_ff_r()
	ff.queue_redraw()

func _lay_ff_r() -> void:
	var lab := "Đi thường" if game.Gm.ff > 1.0 else "Tua nhanh"
	var w := 2 + 14 + 18 + 6 + tw(lab, 14, 700) + 14 + 2
	var h := 2 + 10 + 18 + 10 + 2.0
	var r := Rect2(W - 12 - w, H - 12 - h, w, h)
	ff.set_meta("r", r)
	ff.items = [{"r": r, "tap": ff_toggle, "id": "ff"}]

func _draw_ff(ci: W_) -> void:
	if _ff_a <= 0.01:
		return
	_lay_ff_r()
	var r: Rect2 = ci.get_meta("r")
	var on: bool = game.Gm.ff > 1.0
	ci.modulate.a = _ff_a
	box(ci, r, Color(0, 0, 0, 0), 99, [], [[0, 8, 16, Color(30 / 255.0, 15 / 255.0, 0, 0.3)]])
	solid_sh(ci, r, 99, 3, Color("#5b3416") if on else WD2)
	tex(ci, r, "uiwood", 256, 99, Color(1.15, 1.15, 1.15) if on else Color.WHITE)
	ring_in(ci, r, 99, 2, WD2)
	if on:
		ring_in(ci, r.grow(-2), 99, 2, Color("#ffe27a"))
	var lab := "Đi thường" if on else "Tua nhanh"
	var ip := Vector2(r.position.x + 16, r.position.y + 12)
	ci.draw_texture_rect(A.ff_icon("#000000", roundi(18 * K)), Rect2((ip + Vector2(0, 1)) * K, Vector2(18, 18) * K), false, Color(1, 1, 1, 0.45))
	ci.draw_texture_rect(A.ff_icon("#fbeed0", roundi(18 * K)), Rect2(ip * K, Vector2(18, 18) * K), false)
	text(ci, lab, ip.x + 18 + 6, r.position.y + 2, 14, 700, CREAMW, (r.size.y - 4) / 14, "left", 0.0, Color(0, 0, 0, 0.45))

# ------------------------------------------------------------ hướng dẫn ván đầu (bảng con)
const COACH := [
	["Bước 1/3 · Bốc sỏi", "Chạm một ô đang sáng trên hàng của mình, hàng có gạch phấn xanh đó."],
	["Bước 2/3 · Chọn hướng", "Chạm mũi tên ở mép ô, hoặc vuốt qua trái, qua phải. Chữ kế mũi tên nói đi hướng đó ăn được nhiêu."],
	["Bước 3/3 · Ăn quân", "Rải hết thì bốc ô kế tiếp rải tiếp. Ô kế trống thì ăn ô sau nó, trống nữa thì ăn tiếp. Hai ô trống liền là hết phiên. Quan non (chưa đủ 5 dân) thì chưa ăn được nghen."],
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
	coach_w.hit_r = Rect2()
	coach_w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach = {"step": step}
	if step < 0:
		coach_w.queue_redraw()
		return
	var title: String = COACH[step][0]
	var body: String = COACH[step][1]
	var w := minf(340.0, W - 32)
	var x := (W - w) / 2
	var tl := wrapt(title, 19, 800, 800, w - 10 - 28)
	var bl := wrapt(body, 15, 500, 500, w - 10 - 28)
	var h := 5 + 12 + tl.size() * 19 * 1.15 + 4 + bl.size() * 15 * 1.4 + 12 + 5
	var btn := Rect2()
	if step == 2:
		var bw := tw("Hiểu rồi", 17, 800) + 28 + 5
		var bh := btn_h(true)
		h += 4 + 6 + bh
		btn = Rect2(x + w - 5 - 14 - bw, 0, bw, bh)
	var L: Dictionary = g.L
	var y := 0.0
	if port:
		var c0: Rect2 = L.cards[0]
		y = c0.position.y - h - 12
	else:
		y = maxf(60.0, g.board_rect(0).position.y - h - 14)
	btn.position.y = y + h - 5 - 12 - btn.size.y
	_coach.merge({"r": Rect2(x, y, w, h), "tl": tl, "bl": bl, "btn": btn})
	if step == 2:
		coach_w.mouse_filter = Control.MOUSE_FILTER_STOP
		coach_w.items = [{"r": btn, "tap": _coach_ok, "id": "ok"}]
		coach_w.hit_r = Rect2(x, y, w, h)
	coach_w.queue_redraw()

func _coach_ok() -> void:
	game.tut_step = 3
	game.store_set("oaq-tut", 3)
	_lay_coach()

func _draw_coach(ci: W_) -> void:
	if _coach.step < 0 or not _coach.has("r"):
		return
	var r: Rect2 = _coach.r
	box(ci, r, Color(0, 0, 0, 0), 14, [], [[0, 10, 30, Color(30 / 255.0, 15 / 255.0, 0, 0.4)]])
	box(ci, r, FRAME, 14)
	tex(ci, r.grow(-5), "uislate", 256, 9)
	var y := draw_lines(ci, _coach.tl, r.position.x + 5 + 14, r.position.y + 5 + 12, 19, 1.15, 800, 800, Color("#ffe27a"))
	draw_lines(ci, _coach.bl, r.position.x + 5 + 14, y + 4, 15, 1.4, 500, 500, CHALK)
	if _coach.step == 2:
		_btn(ci, _coach.btn, "Hiểu rồi", "", true, ci.pressed_id() == "ok")

# ------------------------------------------------------------ nút .btn (bảng hiệu sơn)
func _btn(ci: CanvasItem, r: Rect2, lab: String, kind := "", sm := false, down := false) -> void:
	var bg := BRICK
	var bd := BRICK2
	var col := Color.WHITE
	var inl := Color(1, 226 / 255.0, 190 / 255.0, 0.4)
	var shc := Color(110 / 255.0, 34 / 255.0, 16 / 255.0, 0.25)
	var tsh := Color(80 / 255.0, 20 / 255.0, 8 / 255.0, 0.6)
	if kind == "g":
		bg = LEAFG; bd = LEAFG2; inl = Color(230 / 255.0, 1, 200 / 255.0, 0.35); shc = Color(36 / 255.0, 80 / 255.0, 15 / 255.0, 0.25); tsh = Color(20 / 255.0, 50 / 255.0, 8 / 255.0, 0.6)
	elif kind == "w":
		bd = WD2; col = CREAMW; inl = Color(1, 226 / 255.0, 190 / 255.0, 0.25); shc = Color(0, 0, 0, 0); tsh = Color(0, 0, 0, 0.5)
	var fs := 17.0 if sm else 21.0
	var rr := r
	if down:
		rr.position.y += 2
		solid_sh(ci, rr, 14, 1, bd)
	else:
		if shc.a > 0:
			box(ci, rr, Color(0, 0, 0, 0), 14, [], [[0, 8, 16, shc]])
		solid_sh(ci, rr, 14, 4, bd)
	if kind == "w":
		tex(ci, rr, "uiwood", 256, 14)
	else:
		box(ci, rr, bg, 14)
	ring_in(ci, rr.grow(-2.5), 11.5, 2, inl)
	ring_in(ci, rr, 14, 2.5, bd)
	var pt := 9.0 if sm else 12.0
	var pb := 10.0 if sm else 13.0
	text(ci, lab, rr.position.x, rr.position.y + 2.5 + pt, fs, 800, col, 1.0, "center", rr.size.x, tsh, Vector2(0, 2))

func btn_h(sm := false) -> float:
	return (17 + 19 + 5.0) if sm else (21 + 25 + 5.0)

func _ib(ci: CanvasItem, r: Rect2, ico: String, down: bool) -> void:
	# nút tròn gỗ (.ib)
	var rr := r
	if down:
		rr.position.y += 2
	else:
		solid_sh(ci, rr, 99, 3, WD2)
	tex(ci, rr, "uiwood", 200, 99)
	ring_in(ci, rr, 99, 2, WD2)
	var iw := 19.0 if H <= 430 else 22.0
	icon(ci, ico, CREAMW, Rect2(rr.get_center() - Vector2(iw, iw) / 2, Vector2(iw, iw)))

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

# khung thẻ giữa màn: rộng tối đa mw (tính cả khung tre), cao theo nội dung (cuộn nếu dài)
func _card_frame(mw: float, h: float, top_extra := 0.0) -> Rect2:
	var w := minf(mw, W - 32)
	var hh := minf(h, H - 32 - 8 - top_extra)
	return Rect2((W - w) / 2, (H - hh + top_extra) / 2, w, hh)

func _lay(id: String) -> void:
	var o: W_ = ovs[id]
	var res: Dictionary = call("_lay_" + id)
	o.set_meta("L", res)
	o.items = res.items
	var fr: Rect2 = res.frame
	var inner := fr.grow(-BAM)
	o.max_scroll = maxf(0.0, res.h - fr.size.y)
	o.scroll = clampf(o.scroll, 0.0, o.max_scroll)
	o.hit_r = fr
	var b: W_ = o.get_meta("body")
	# menu: bảng hiệu ló lên trên mép thẻ, khung không cắt khi khỏi cuộn
	if id == "menu" and o.max_scroll <= 0:
		b.clip_contents = false
	else:
		b.clip_contents = true
	b.position = inner.position * K
	b.size = inner.size * K
	o.queue_redraw()
	b.queue_redraw()

func _draw_ov(ci: W_, id: String) -> void:
	if not ci.has_meta("L"):
		return
	var res: Dictionary = ci.get_meta("L")
	ci.modulate.a = minf(1.0, _ov_t / 0.25)
	ci.draw_rect(Rect2(Vector2.ZERO, ci.size), Color(48 / 255.0, 30 / 255.0, 12 / 255.0, 0.38))
	var fr: Rect2 = res.frame
	# giấy dó trong khung tre
	box(ci, fr, Color(0, 0, 0, 0), 15, [], [[0, 20, 60, Color(40 / 255.0, 20 / 255.0, 0, 0.45)]])
	tex(ci, fr.grow(-BAM), "uipaper", 256, 4)
	A.bamboo(ci, Rect2(fr.position * K, fr.size * K), BAM * K)

func _draw_body(ci: W_, id: String) -> void:
	var o: W_ = ovs[id]
	if not o.has_meta("L"):
		return
	var res: Dictionary = o.get_meta("L")
	var fr: Rect2 = res.frame
	var inner := fr.grow(-BAM)
	ci.draw_set_transform(-inner.position * K, 0.0, Vector2.ONE)
	(res.draw as Callable).call(ci, fr, o.scroll, inner)
	ci.draw_set_transform(-inner.position * K, 0.0, Vector2.ONE)
	if o.max_scroll > 0:
		var th := inner.size.y * inner.size.y / (inner.size.y + o.max_scroll)
		var ty := inner.position.y + (inner.size.y - th) * o.scroll / o.max_scroll
		box(ci, Rect2(inner.end.x - 6, ty + 4, 3, th - 8), Color(INK2, 0.3), 2)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _visible(r: Rect2, clip: Rect2, sc: float) -> bool:
	return r.end.y - sc > clip.position.y - 2 and r.position.y - sc < clip.end.y + 2

# đệm trong thẻ (padding 16 18 16, cộng khung tre 15)
const CP := [16.0, 18.0, 16.0]

# ------------------------------------------------------------ Menu
func build_menu() -> void:
	if cur_ov == "menu":
		_lay("menu")

func _mini_board() -> String:
	# bàn phấn nhỏ có sỏi (buildMenu của web)
	var m := '<svg viewBox="0 0 190 46" width="190" height="46" xmlns="http://www.w3.org/2000/svg"><rect x="0" y="0" width="190" height="46" rx="10" fill="#b8956c"/>'
	m += '<g fill="none" stroke="#fffbf0" stroke-width="2" opacity=".9"><path d="M35 5h120v36H35zM35 23h120M59 5v36M83 5v36M107 5v36M131 5v36"/><path d="M35 5a20 18 0 0 0 0 36M155 5a20 18 0 0 1 0 36"/></g>'
	var cols := ["#9a9590", "#c8bfb0", "#7a6e62", "#d8d0c2", "#a07a58"]
	for c in 10:
		var x := 47 + (c % 5) * 24
		var y := 14 if c < 5 else 32
		for k in 5:
			var a := k * 1.3 + c
			m += '<circle cx="%.2f" cy="%.2f" r="2.2" fill="%s"/>' % [x + cos(a) * 5, y + sin(a) * 3.6, cols[(k + c) % 5]]
	m += '<path d="M37 3h116" stroke="#f07a92" stroke-width="2"/><path d="M37 43h116" stroke="#56aae8" stroke-width="2"/>'
	m += '<ellipse cx="24" cy="23" rx="6" ry="5" fill="#3d4046"/><ellipse cx="166" cy="23" rx="6" ry="5" fill="#9a5636"/>'
	return m + "</svg>"

func _lay_menu() -> Dictionary:
	var g = game
	var small := H <= 430
	var pt := 10.0 if small else 14.0
	var px := 20.0
	var cw := minf(600.0, W - 32)
	var iw := cw - 2 * BAM - px * 2
	var x0 := BAM + px
	var items := []
	var ops := []   # lệnh vẽ (theo y trong thẻ, tính từ mép ngoài khung tre)
	var y := BAM + pt
	# bảng hiệu gỗ đóng đinh, ló lên trên mép thẻ
	var lf := clampf(W * 0.095, 42, 62)
	if W <= 520:
		lf = 42.0
	if small:
		lf = 40.0
	var sgp := [6.0, 26.0, 10.0] if W <= 520 else [8.0, 34.0, 12.0]
	var smt := -40.0
	if W <= 520:
		smt = -34.0
	if small:
		smt = -30.0
	var sw: float = tw("Ô Ăn Quan", lf, 800, 1.0) + float(sgp[1]) * 2 + 6
	var sh: float = 3 + float(sgp[0]) + lf * 1.05 + float(sgp[2]) + 3
	var sy := y + smt
	ops.append(["sign", sy, sw, sh, lf, sgp])
	y = sy + sh + 4
	# khăn rằn
	ops.append(["ran", y])
	y += 12 + (6 if small else 12)
	var sub := wrapt("Trưa trưa ra sân trước hiên, kẻ phấn, bốc sỏi chơi một ván nghen!", 16, 500, 500, iw)
	y += 6
	ops.append(["sub", y, sub])
	y += sub.size() * 16 * 1.35 + 10
	if not small:
		y += 4
		ops.append(["mini", y])
		y += 46 + 12
	# tabs
	y += 4
	var tabh := 2 + 4 + 35 + 4 + 2.0
	ops.append(["tabs", y, tabh])
	var tw2 := (iw - 4 - 8 - 4) / 2
	items.append({"r": Rect2(x0 + 6, y + 6, tw2, 35), "tap": func(): menu_mode = "ai"; _lay("menu"), "id": "t_ai", "scroll": true})
	items.append({"r": Rect2(x0 + 6 + tw2 + 4, y + 6, tw2, 35), "tap": func(): menu_mode = "pvp"; _lay("menu"), "id": "t_pvp", "scroll": true})
	y += tabh + 2
	if menu_mode == "ai":
		y += 8 if small else 14
		var cols := 2 if W <= 520 else 4
		var gw := (iw - 8 * (cols - 1)) / cols
		var avs := 44.0 if small else 58.0
		var oh := 8 + avs + 4 + 17 * 1.1 + 12 * 1.3 + 2 + 12.5 * 1.2 + 9
		for k in 4:
			var r := Rect2(x0 + (k % cols) * (gw + 8), y + (k / cols) * (oh + 8), gw, oh)
			items.append({"r": r, "tap": _pick_opp.bind(k), "id": "o" + str(k), "scroll": true, "opp": k, "avs": avs})
		y += ceili(4.0 / cols) * (oh + 8) - 8 + (2 if small else 4)
	else:
		y += 12
		var nw := (iw - 8) / 2
		for p in [0, 1]:
			var r := Rect2(x0 + p * (nw + 8), y, nw, 15 * 1.2 + 22)
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
			items.append({"r": Rect2(x0, y, bw, bh), "tap": _start, "id": "start", "scroll": true, "btn": lab})
			items.append({"r": Rect2(x0 + bw + 10, y, bw, bh), "tap": _resume, "id": "resume", "scroll": true, "btn": "Chơi tiếp ván cũ", "kind": "g"})
			y += bh
		else:
			items.append({"r": Rect2(x0, y, iw, bh), "tap": _start, "id": "start", "scroll": true, "btn": lab})
			y += bh + 10
			items.append({"r": Rect2(x0, y, iw, bh), "tap": _resume, "id": "resume", "scroll": true, "btn": "Chơi tiếp ván cũ", "kind": "g"})
			y += bh
	else:
		items.append({"r": Rect2(x0, y, iw, bh), "tap": _start, "id": "start", "scroll": true, "btn": lab})
		y += bh
	# liên kết
	var l1 := tw("Luật chơi", 16, 600) + 16
	var l2 := tw("Cài đặt luật", 16, 600) + 16
	var lx := x0 + (iw - l1 - l2) / 2
	items.append({"r": Rect2(lx, y, l1, 36), "tap": func(): back_to = "menu"; show_ov("rules"), "id": "l_rules", "scroll": true, "lnk": "Luật chơi"})
	items.append({"r": Rect2(lx + l1, y, l2, 36), "tap": func(): back_to = "menu"; show_ov("settings"), "id": "l_set", "scroll": true, "lnk": "Cài đặt luật"})
	y += 36 + 16 + BAM
	# phần bảng hiệu ló ra trên khung (âm) cũng phải vừa màn
	var over := maxf(0.0, -sy)
	var fr := _card_frame(600, y, over)
	for it in items:
		it.r.position += fr.position
	for le in names_le:
		le.visible = menu_mode == "pvp" and cur_ov == "menu"
	return {"frame": fr, "h": y, "items": items, "draw": _draw_menu.bind(ops, x0, iw)}

func _pick_opp(k: int) -> void:
	menu_level = k
	game.store_set("oaq-lvl", k)
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
		g.store_set("oaq-n0", a)
		g.store_set("oaq-n1", b)
		names = [a if a != "" else "Người 1", b if b != "" else "Người 2"]
	g.start(menu_mode, menu_level, names)

func _resume() -> void:
	game.resume_game()

func _khan(ci: CanvasItem, r: Rect2, cs := 4.0) -> void:
	# khăn rằn: ô cờ đen trắng
	var y := r.position.y
	var row := 0
	while y < r.end.y - 0.01:
		var x := r.position.x
		var col := 0
		var hh := minf(cs, r.end.y - y)
		while x < r.end.x - 0.01:
			var ww := minf(cs, r.end.x - x)
			var c := Color("#2a2420") if (row + col) % 2 == 0 else Color("#f3efe6")
			ci.draw_rect(Rect2(Vector2(x, y) * K, Vector2(ww, hh) * K), Color(c, 0.9))
			x += cs
			col += 1
		y += cs
		row += 1

func _draw_menu(ci: W_, fr: Rect2, sc: float, clip: Rect2, ops: Array, x0: float, iw: float) -> void:
	var g = game
	var o := fr.position - Vector2(0, sc)
	for op in ops:
		var y: float = o.y + op[1]
		if op[0] == "sign":
			var sw: float = op[2]
			var shh: float = op[3]
			var lf: float = op[4]
			var sgp: Array = op[5]
			var r := Rect2(-sw / 2, -shh / 2, sw, shh)
			var c := Vector2(o.x + fr.size.x / 2, y + shh / 2)
			ci.draw_set_transform((c - clip.position) * K, deg_to_rad(-1.2), Vector2.ONE)
			box(ci, r, Color(0, 0, 0, 0), 12, [], [[0, 14, 24, Color(30 / 255.0, 15 / 255.0, 0, 0.35)]])
			solid_sh(ci, r, 12, 6, WD2)
			tex(ci, r, "uiwood", 256, 12)
			ring_in(ci, r, 12, 3, WD2)
			inset_tb(ci, r.grow(-3), 9, 2, Color(1, 220 / 255.0, 170 / 255.0, 0.3), 4, Color(0, 0, 0, 0.25))
			# đinh hai đầu
			for nx in [r.position.x + 3 + 11 + 4.5, r.end.x - 3 - 11 - 4.5]:
				var nc := Vector2(nx, 0)
				ci.draw_circle((nc + Vector2(0, 1)) * K, 4.5 * K, Color(0, 0, 0, 0.5), true, -1.0, true)
				ci.draw_circle(nc * K, 4.5 * K, Color("#6b6358"), true, -1.0, true)
				ci.draw_circle((nc + Vector2(-1.2, -1.4)) * K, 2.6 * K, Color("#c9c2b4"), true, -1.0, true)
				ci.draw_circle((nc + Vector2(-1.5, -1.7)) * K, 1.3 * K, Color("#e8e2d4"), true, -1.0, true)
			# chữ: trắng ngà viền gạch đỏ, bóng đổ
			var f := fnt(800)
			var n := roundi(lf * K)
			var txt := "Ô Ăn Quan"
			var ww := tw(txt, lf, 800, 1.0)
			var bx := -ww / 2
			var by := base_y(r.position.y + 3 + sgp[0], lf, 1.05, 800)
			var draw_ls := func(off: Vector2, col: Color, outline := 0) -> void:
				var xx := bx
				for ch in txt:
					if outline > 0:
						ci.draw_string_outline(f, Vector2(xx + off.x, by + off.y) * K, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, n, outline, col)
					else:
						ci.draw_string(f, Vector2(xx + off.x, by + off.y) * K, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, n, col)
					xx += tw(ch, lf, 800) + 1.0
			draw_ls.call(Vector2(0, 6), Color(0, 0, 0, 0.18), roundi(8 * K))
			draw_ls.call(Vector2(0, 3), BRICK2, roundi(4 * K))
			draw_ls.call(Vector2(0, 0), BRICK2, roundi(4 * K))
			draw_ls.call(Vector2(0, 3), BRICK2)
			draw_ls.call(Vector2(0, 0), Color("#fff4d6"))
			ci.draw_set_transform(-clip.position * K, 0.0, Vector2.ONE)
		elif op[0] == "ran":
			var r := Rect2(o.x + BAM, y, fr.size.x - 2 * BAM, 12)
			_khan(ci, Rect2(r.position.x, r.position.y + 2, r.size.x, 8))
			ci.draw_rect(Rect2(r.position * K, Vector2(r.size.x, 2) * K), Color("#2a2420"))
			ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - 2) * K, Vector2(r.size.x, 2) * K), Color("#2a2420"))
		elif op[0] == "sub":
			draw_lines(ci, op[2], o.x + x0, y, 16, 1.35, 500, 500, INK2, Color(0, 0, 0, 0), "center", iw)
		elif op[0] == "mini":
			var r := Rect2(o.x + (fr.size.x - 190) / 2, y, 190, 46)
			var t := A.svg(_mini_board(), roundi(190 * K))
			if t != null:
				ci.draw_texture_rect(t, Rect2(r.position * K, r.size * K), false)
		elif op[0] == "tabs":
			wood(ci, Rect2(o.x + x0, y, iw, op[2]), 14, 2)
	for it in ci.ov.items:
		var r: Rect2 = it.r
		r.position.y -= sc
		if not _visible(r, clip, 0):
			continue
		var id: String = it.id
		var down: bool = ci.pressed_id() == id
		if id == "t_ai" or id == "t_pvp":
			var on: bool = (id == "t_ai") == (menu_mode == "ai")
			var lab := "Đấu với máy" if id == "t_ai" else "Hai người chơi"
			if on:
				solid_sh(ci, r, 11, 2, Color(0, 0, 0, 0.25))
				tex(ci, r, "uipaper", 256, 11)
				text(ci, lab, r.position.x, r.position.y, 15, 700, INK, r.size.y / 15, "center", r.size.x)
			else:
				text(ci, lab, r.position.x, r.position.y, 15, 700, CREAMW, r.size.y / 15, "center", r.size.x, Color(0, 0, 0, 0.45))
		elif it.has("opp"):
			var k: int = it.opp
			var sel := k == menu_level
			var avs: float = it.avs
			var rr := r
			if sel:
				rr.position.y -= 2
				box(ci, rr, Color(0, 0, 0, 0), 16, [], [[0, 6, 14, Color(150 / 255.0, 50 / 255.0, 20 / 255.0, 0.2)]])
				tex(ci, rr, "uipaper", 256, 16, Color(1.0, 0.975, 0.93))
				ring_in(ci, rr, 16, 3, BRICK)
			else:
				tex(ci, rr, "uipaper", 256, 16)
				ring_in(ci, rr, 16, 2, TAN)
			# chân dung trên bảng con nhỏ
			var ar := Rect2(rr.position.x + (rr.size.x - avs) / 2, rr.position.y + 8, avs, avs)
			solid_sh(ci, ar, 10, 2, Color(60 / 255.0, 30 / 255.0, 10 / 255.0, 0.25))
			box(ci, ar, FRAME, 10)
			tex(ci, ar.grow(-3), "uislate", 128, 7)
			ring_in(ci, ar.grow(-3), 7, 1, Color(1, 1, 1, 0.08))
			avatar(ci, g.OPP[k].k, ar.grow(-5))
			var yy := ar.end.y + 4
			text(ci, g.OPP[k].name, rr.position.x, yy, 17, 800, WD, 1.1, "center", rr.size.x)
			yy += 17 * 1.1
			text(ci, g.OPP[k].lvl, rr.position.x, yy, 12, 600, INK2, 1.3, "center", rr.size.x)
			yy += 12 * 1.3 + 2
			var em: String = ("thắng %d · thua %d" % [int(g.stats.w[k]), int(g.stats.l[k])]) if (int(g.stats.w[k]) or int(g.stats.l[k])) else g.OPP[k].tag
			text(ci, ellip(em, 12.5, 500, rr.size.x - 6), rr.position.x, yy, 12.5, 500, Color("#8a6a44"), 1.2, "center", rr.size.x)
		elif it.has("name"):
			var p: int = it.name
			var le: LineEdit = names_le[p]
			box(ci, r, Color("#fffaf0"), 12)
			A.box(ci, Rect2(r.position * K, Vector2(8, r.size.y) * K), PC[p], 0, K)
			ring_in(ci, r, 12, 2, BRICK if le.has_focus() else TAN)
			le.position = (Vector2(r.position.x + 8 + 6, r.position.y + 2) - clip.position) * K
			le.size = Vector2(r.size.x - 8 - 12, r.size.y - 4) * K
		elif it.has("btn"):
			_btn(ci, r, it.btn, it.get("kind", ""), false, down)
		elif it.has("lnk"):
			var c := WD
			text(ci, it.lnk, r.position.x + 8, r.position.y + 10, 16, 600, c, 1.0)
			var uy := r.position.y + 10 + 16 + 3
			ci.draw_line(Vector2(r.position.x + 8, uy) * K, Vector2(r.end.x - 8, uy) * K, c, 1.2 * K)

# ------------------------------------------------------------ Luật chơi
const DG := [
	'<svg viewBox="0 0 220 92"><g class="ch"><rect x="18" y="40" width="34" height="34"/><rect x="55" y="40" width="34" height="34"/><rect x="92" y="40" width="34" height="34"/><rect x="129" y="40" width="34" height="34"/><rect x="166" y="40" width="34" height="34"/></g><circle cx="72.0" cy="57.0" r="3.2" fill="#e9e4d6"/><circle cx="68.7" cy="60.0" r="3.2" fill="#e9e4d6"/><circle cx="109.0" cy="57.0" r="3.2" fill="#e9e4d6"/><circle cx="105.7" cy="60.0" r="3.2" fill="#e9e4d6"/><circle cx="146.0" cy="57.0" r="3.2" fill="#e9e4d6"/><circle cx="142.7" cy="60.0" r="3.2" fill="#e9e4d6"/><circle cx="183.0" cy="57.0" r="3.2" fill="#e9e4d6"/><circle cx="179.7" cy="60.0" r="3.2" fill="#e9e4d6"/><path class="ar" d="M35 34 Q 90 4 183 34"/><path class="ar" d="M176 27l8 7-10 3"/><text x="35" y="86">bốc 4 viên</text><text x="138" y="86">rải mỗi ô 1</text></svg>',
	'<svg viewBox="0 0 220 92"><g class="ch"><rect x="18" y="40" width="34" height="34"/><rect x="55" y="40" width="34" height="34"/><rect x="92" y="40" width="34" height="34"/><rect x="129" y="40" width="34" height="34"/><rect x="166" y="40" width="34" height="34"/></g><circle cx="35.0" cy="57.0" r="3.2" fill="#e9e4d6"/><circle cx="31.7" cy="60.0" r="3.2" fill="#e9e4d6"/><circle cx="35.6" cy="50.7" r="3.2" fill="#e9e4d6"/><circle cx="72.0" cy="57.0" r="3.2" fill="#ffe27a"/><circle cx="146.0" cy="57.0" r="3.2" fill="#e9e4d6"/><circle cx="142.7" cy="60.0" r="3.2" fill="#e9e4d6"/><circle cx="146.6" cy="50.7" r="3.2" fill="#e9e4d6"/><circle cx="150.7" cy="63.2" r="3.2" fill="#e9e4d6"/><circle cx="137.1" cy="55.4" r="3.2" fill="#e9e4d6"/><circle class="ring" cx="146" cy="57" r="17"/><path class="ar" d="M78 32 Q 95 18 109 32"/><text x="97" y="24" text-anchor="middle">vỗ</text><path class="ar" d="M115 30 Q 130 14 142 30"/><text x="152" y="86" text-anchor="middle">ăn ô sau</text><text x="106" y="86" text-anchor="middle">trống</text><text x="58" y="86" text-anchor="middle">viên cuối</text></svg>',
	'<svg viewBox="0 0 220 92"><g class="ch"><path d="M70 22 A 46 34 0 0 0 70 90"/><path d="M70 22h74v68H70"/><path d="M144 22v68"/></g><ellipse cx="48" cy="56" rx="11" ry="9" fill="#5b5f66" stroke="#e9e4d6" stroke-width="1.5"/><circle cx="54.0" cy="40.0" r="3.2" fill="#e9e4d6"/><circle cx="50.7" cy="43.0" r="3.2" fill="#e9e4d6"/><circle cx="107.0" cy="56.0" r="3.2" fill="#e9e4d6"/><circle cx="103.7" cy="59.0" r="3.2" fill="#e9e4d6"/><circle cx="107.6" cy="49.7" r="3.2" fill="#e9e4d6"/><path class="no" d="M28 30l40 52M68 30l-40 52"/><text x="48" y="16" text-anchor="middle">dưới 5 dân</text><text x="176" y="54" text-anchor="middle">chưa ăn</text><text x="176" y="70" text-anchor="middle">được đâu</text></svg>',
]
const DG_CLS := {
	'class="ch"': 'fill="none" stroke="#eeeadc" stroke-width="1.6" opacity=".9"',
	'class="ar"': 'fill="none" stroke="#ffe27a" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"',
	'class="ring"': 'fill="none" stroke="#ffe27a" stroke-width="2" stroke-dasharray="4 3"',
	'class="no"': 'stroke="#f07a92" stroke-width="3" stroke-linecap="round" opacity=".85"',
}
var _dg_cache := {}

func _dg(i: int) -> Dictionary:
	# sơ đồ luật: hình (không chữ) + các dòng chữ phấn (vẽ bằng Baloo)
	if _dg_cache.has(i):
		return _dg_cache[i]
	var s: String = DG[i].replace('<svg viewBox="0 0 220 92">', '<svg viewBox="0 0 220 92" xmlns="http://www.w3.org/2000/svg">')
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
	["1 · Rải quân", 0, ["Bốc hết sỏi một ô dân của mình, chọn hướng, rải mỗi ô một viên (rải qua cả ô quan).", "Ô kế tiếp còn sỏi thì bốc rải tiếp. Ô kế là **ô quan** thì ngừng."], ""],
	["2 · Ăn quân", 1, ["Ô kế **trống** mà ô sau có sỏi thì vỗ ô trống, **ăn** ô sau.", "Sau đó lại trống rồi có sỏi thì **ăn tiếp**. Hai ô trống liền là hết phiên."], ""],
	["3 · Quan non", 2, [], "Ô quan còn hòn quan mà **chưa đủ 5 dân** là quan non, chưa ăn được. Tắt được trong Cài đặt."],
	["4 · Hết quân, hết ván", -1, [], "Tới phiên mà 5 ô trống trơn thì lấy 5 dân đã ăn rải lại. Không đủ thì **mượn** đối thủ 5 dân, cuối ván trả.|Hai ô quan sạch quân là “hết quan, tàn dân, thu quân, kéo về”. Mỗi dân 1 điểm, mỗi quan 10 điểm (hoặc 5)."],
]

func _lay_rules() -> Dictionary:
	var cw := minf(900.0, W - 32)
	var x0 := BAM + CP[1]
	var iw := cw - 2 * x0
	var items := []
	var ops := []
	var y := BAM + CP[0]
	ops.append(["h2", y, "Luật chơi", x0])
	y += 32 * 1.05 + 4
	var lead := wrapt("Bàn có **10 ô dân** (mỗi bên 5 ô, mỗi ô 5 viên sỏi) và **2 ô quan** ở hai đầu, mỗi ô một hòn quan to. Hàng của bạn gạch phấn {x:xanh}, hàng đối thủ gạch phấn {h:hồng}. Số ghi ở ô quan là điểm ăn được ô đó.", 14.5, 500, 800, iw)
	ops.append(["p", y, lead, 14.5, 1.4, x0])
	y += lead.size() * 14.5 * 1.4 + 8
	var two := W >= 820
	var colw := (iw - 10) / 2 if two else iw
	var secs := []
	for i in RULES.size():
		var R: Array = RULES[i]
		var inner := colw - 2 * 13.5
		var sec := []
		var yy := 1.5 + 4 + 6.0
		sec.append(["h3", yy, R[0]])
		yy += 19 * 1.1 + 6
		if R[1] >= 0:
			var dw := minf(300.0, inner)
			var dh := dw * 92 / 220
			sec.append(["dg", yy + 2, R[1], (inner - dw) / 2, dw, dh])
			yy += 2 + dh + 6
		for li in R[2]:
			var ls := wrapt(li, 14, 500, 800, inner - 20)
			sec.append(["li", yy, ls])
			yy += ls.size() * 14 * 1.38 + 8
		if R[3] != "":
			for para in R[3].split("|"):
				var ps := wrapt(para, 14, 500, 800, inner)
				sec.append(["pp", yy, ps])
				yy += ps.size() * 14 * 1.38 + 8
		yy += 8 - 8 + 1.5
		secs.append([sec, yy])
	# lưới: một cột, hoặc hai cột (mỗi hàng cao bằng ô cao hơn)
	if two:
		for rr in 2:
			var a: Array = secs[rr * 2]
			var b: Array = secs[rr * 2 + 1]
			var hh := maxf(a[1], b[1])
			ops.append(["sec", y, x0, colw, hh, a[0]])
			ops.append(["sec", y, x0 + colw + 10, colw, hh, b[0]])
			y += hh + 10
	else:
		for sc in secs:
			ops.append(["sec", y, x0, colw, sc[1], sc[0]])
			y += sc[1] + 10
	y -= 10
	var note := wrapt("**Mẹo:** chạm ô sáng, rồi chạm mũi tên phấn ở mép ô (hoặc vuốt qua trái, phải). Máy tính: phím 1–5 chọn ô, ← → chọn hướng. Đấu với máy được đi lại 3 lần. Chạm bàn khi đang rải để tua nhanh.", 12.5, 500, 800, iw - 25)
	y += 10
	ops.append(["note", y, note, x0, iw])
	y += note.size() * 12.5 * 1.4 + 21
	y += 10
	var bw := tw("Xem lại hướng dẫn", 17, 800) + 28 + 5
	items.append({"r": Rect2(x0 + iw - bw, y, bw, btn_h(true)), "tap": _tut_again, "id": "tut", "scroll": true, "btn": "Xem lại hướng dẫn", "kind": "w", "sm": true})
	y += btn_h(true) + CP[2] + BAM
	var fr := _card_frame(900, y)
	for it in items:
		it.r.position += fr.position
	items.append({"r": Rect2(fr.end.x - BAM - 6 - 36, fr.position.y + BAM + 6, 36, 36), "tap": _close_x, "id": "x"})
	return {"frame": fr, "h": y, "items": items, "draw": _draw_doc.bind(ops)}

func _tut_again() -> void:
	game.tut_step = 0
	game.store_set("oaq-tut", 0)
	close_all()
	update_cards()

func _draw_doc(ci: W_, fr: Rect2, sc: float, clip: Rect2, ops: Array) -> void:
	var o := fr.position - Vector2(0, sc)
	var body := Color("#4a321c")
	for op in ops:
		var y: float = o.y + op[1]
		match op[0]:
			"h2":
				text(ci, op[2], o.x + op[3], y, 32, 800, BRICK2, 1.05)
			"p":
				draw_lines(ci, op[2], o.x + op[5], y, op[3], op[4], 500, 800, body)
			"grp":
				text(ci, op[2], o.x + op[3], y, 18, 800, WD, 1.0)
				ci.draw_rect(Rect2(Vector2(o.x + op[3], y + 18 + 4) * K, Vector2(op[4], 2) * K), TAN)
			"sec":
				var sr := Rect2(o.x + op[2], y, op[3], op[4])
				if not _visible(sr, clip, 0):
					continue
				box(ci, sr, Color(1, 1, 1, 0.45), 12)
				_dash_rrect(ci, sr, 12, 1.5, TAN)
				for q in op[5]:
					var qy: float = y + q[1]
					var qx := sr.position.x + 13.5
					match q[0]:
						"h3":
							text(ci, q[2], qx, qy, 19, 800, BRICK, 1.1)
						"dg":
							var d := _dg(q[2])
							var dr := Rect2(qx + q[3], qy, q[4], q[5])
							box(ci, dr, FRAME, 10)
							tex(ci, dr.grow(-4), "uislate", 200, 6)
							var k: float = (q[4] - 8) / 220.0
							var cr := dr.grow(-4)
							var t := A.svg(d.svg, roundi(cr.size.x * K))
							if t != null:
								ci.draw_texture_rect(t, Rect2(cr.position * K, cr.size * K), false)
							for tt in d.tx:
								var fs := 11 * k
								var tx: float = cr.position.x + tt[0] * k
								var ww := tw(tt[3], fs, 600)
								if tt[2]:
									tx -= ww / 2
								var f := fnt(600)
								var n := maxi(1, roundi(fs * K))
								ci.draw_string(f, Vector2(tx, cr.position.y + tt[1] * k) * K, tt[3], HORIZONTAL_ALIGNMENT_LEFT, -1, n, Color("#eeeadc"))
						"li":
							ci.draw_circle(Vector2(qx + 8, qy + 14 * 0.72) * K, 2.2 * K, body, true, -1.0, true)
							draw_lines(ci, q[2], qx + 20, qy, 14, 1.38, 500, 800, body)
						"pp":
							draw_lines(ci, q[2], qx, qy, 14, 1.38, 500, 800, body)
			"note":
				var nr := Rect2(o.x + op[3], y, op[4], op[2].size() * 12.5 * 1.4 + 21)
				box(ci, nr, Color(GOLD, 0.18), 12)
				_dash_rrect(ci, nr, 12, 1.5, Color("#d9b25a"))
				draw_lines(ci, op[2], nr.position.x + 12.5, y + 10.5, 12.5, 1.4, 500, 800, INK2)
			"row":
				# hàng cài đặt
				var lb: Array = op[2]
				var sm: Array = op[3]
				var yy := draw_lines(ci, lb, o.x + op[5], y, 15, 1.25, 700, 700, INK)
				if sm.size():
					draw_lines(ci, sm, o.x + op[5], yy + 2, 12.5, 1.35, 500, 500, INK2)
				var ly: float = o.y + op[6] - 0.5
				var xx: float = o.x + op[5]
				while xx < o.x + op[5] + op[7]:
					ci.draw_line(Vector2(xx, ly) * K, Vector2(minf(xx + 3, o.x + op[5] + op[7]), ly) * K, LINE, maxf(1.0, K))
					xx += 6
			"segbg":
				var sr := Rect2(o.x + op[2], y, op[3], op[4])
				box(ci, sr, Color(122 / 255.0, 74 / 255.0, 36 / 255.0, 0.12), 12)
				ring_in(ci, sr, 12, 1.5, TAN)
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
			_ib(ci, r, "x", down)
		elif it.has("btn"):
			_btn(ci, r, it.btn, it.get("kind", ""), it.get("sm", false), down)
		elif it.has("seg"):
			var on: bool = it.on
			if on:
				solid_sh(ci, r, 9, 2, Color(0, 0, 0, 0.3))
				tex(ci, r, "uislate", 200, 9)
				text(ci, it.seg, r.position.x, r.position.y, 13, 700, Color.WHITE, r.size.y / 13, "center", r.size.x)
			else:
				text(ci, it.seg, r.position.x, r.position.y, 13, 700, INK2, r.size.y / 13, "center", r.size.x)

func _dash_rrect(ci: CanvasItem, r: Rect2, rad: float, w: float, col: Color) -> void:
	# border: dashed (nét đứt quanh khung bo góc)
	var pts := A.rrect_pts(r.grow(-w / 2), rad - w / 2, 6)
	pts.append(pts[0])
	var acc := 0.0
	var on := true
	var dl := w * 3.0
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var L := a.distance_to(b)
		var t := 0.0
		while t < L:
			var step := minf(dl - acc, L - t)
			if on:
				ci.draw_line((a + (b - a) * (t / L)) * K, (a + (b - a) * ((t + step) / L)) * K, col, w * K)
			t += step
			acc += step
			if acc >= dl - 0.001:
				acc = 0.0
				on = not on

# ------------------------------------------------------------ Cài đặt
const SETS := [
	["grp", "Luật chơi"],
	["non", "Quan non", "Ô quan dưới 5 dân thì chưa được ăn", [["1", "Bật"], ["0", "Tắt"]]],
	["qv", "Giá một quan", "Đổi ra bao nhiêu dân khi tính điểm", [["10", "10 dân"], ["5", "5 dân"]]],
	["borrow", "Hết quân mà không đủ rải", "Vay đối thủ 5 dân, cuối ván trả", [["1", "Cho vay"], ["0", "Dừng ván"]]],
	["first", "Ai đi trước", "Khi đấu với máy", [["me", "Mình"], ["ai", "Máy"], ["rnd", "Bốc thăm"]]],
	["grp", "Chơi cho sướng"],
	["hint", "Gợi ý nước đi", "Ghi bên mũi tên: hướng đó ăn được bao nhiêu", [["1", "Bật"], ["0", "Tắt"]]],
	["speed", "Tốc độ rải", "", [["0.7", "Chậm"], ["1", "Vừa"], ["1.6", "Nhanh"]]],
	["fx", "Bóng cây lay", "Tắt nếu máy yếu", [["1", "Bật"], ["0", "Tắt"]]],
]

static func _sv(v) -> String:
	if v is float and v == floorf(v):
		return str(int(v))
	return str(v)

func _lay_settings() -> Dictionary:
	var g = game
	var cw := minf(520.0, W - 32)
	var x0 := BAM + CP[1]
	var iw := cw - 2 * x0
	var items := []
	var ops := []
	var y := BAM + CP[0]
	ops.append(["h2", y, "Cài đặt", x0])
	y += 32 * 1.05 + 4
	for i in SETS.size():
		var R: Array = SETS[i]
		if R[0] == "grp":
			y += 14
			ops.append(["grp", y, R[1], x0, iw])
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
		var rh := 22 + maxf(th, segh) + 1
		ops.append(["row", y + 11 + (maxf(th, segh) - th) / 2, lb, sm, true, x0, y + rh, iw])
		var sy := y + 11 + (maxf(th, segh) - segh) / 2
		var sx := x0 + iw - sw
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
		var note := wrapt("Đổi luật sẽ áp dụng từ ván sau.", 12.5, 500, 800, iw - 25)
		y += 10
		ops.append(["note", y, note, x0, iw])
		y += note.size() * 12.5 * 1.4 + 21
	y += CP[2] + BAM
	var fr := _card_frame(520, y)
	for it in items:
		it.r.position += fr.position
	items.append({"r": Rect2(fr.end.x - BAM - 6 - 36, fr.position.y + BAM + 6, 36, 36), "tap": _close_x, "id": "x"})
	return {"frame": fr, "h": y, "items": items, "draw": _draw_doc.bind(ops)}

func _set_opt(k: String, v: String) -> void:
	var g = game
	if k == "first":
		g.S[k] = v
	elif k == "speed":
		g.S[k] = float(v)
	else:
		g.S[k] = int(v)
	g.store_set("oaq-set-v1", g.S)
	g.snd.sel()
	if k == "fx":
		g.shade_enable(bool(int(v)))
	_lay("settings")

# ------------------------------------------------------------ Hết ván
func end_info(av: String, title: String, sub: String, s: Dictionary, sc: Array) -> void:
	_end = {"av": av, "title": title, "sub": sub, "s": s, "sc": sc}
	_rew = null

func set_reward(xu: int, left: int, mx: int) -> void:
	_rew = {"xu": xu, "left": left, "max": mx}
	if cur_ov == "end":
		_lay("end")

func _end_rows() -> Array:
	var g = game
	var s: Dictionary = _end.s
	var qv: int = int(g.Gm.R.get("qv", 10))
	var qc := func(n: int) -> Array: return [("%d quan" % n), ("= %d điểm" % (n * qv))] if n else ["", "chưa có"]
	var rows := [["Quan", qc.call(E.quan_of(s, 0)), qc.call(E.quan_of(s, 1))], ["Dân ăn được", [str(int(s.dan[0])), ""], [str(int(s.dan[1])), ""]]]
	var d0 := int(s.debt[0])
	var d1 := int(s.debt[1])
	if d0 or d1:
		var a := ("−%d" % d0) if d0 else (("+%d" % d1) if d1 else "0")
		var b := ("−%d" % d1) if d1 else (("+%d" % d0) if d0 else "0")
		rows.append(["Vay / trả", [a, ""], [b, ""]])
	return rows

func _lay_end() -> Dictionary:
	var cw := minf(520.0, W - 32)
	var x0 := BAM + CP[1]
	var iw := cw - 2 * x0
	var items := []
	var ops := []
	var y := BAM + CP[0]
	if _end.is_empty():
		return {"frame": _card_frame(520, 100), "h": 100.0, "items": [], "draw": _draw_doc.bind([])}
	var tl := wrapt(_end.title, 40, 800, 800, iw)
	var sub := wrapt(_end.sub, 14.5, 500, 500, iw)
	var info := {"av_y": y}
	y += 96 + 6
	info.t_y = y
	info.tl = tl
	y += tl.size() * 40 * 1.05 + 6
	info.s_y = y - 6
	info.sub = sub
	y += -6 + sub.size() * 14.5 * 1.3 + 14
	# bảng con ghi điểm
	var rows := _end_rows()
	var rh_th := 17 * 1.1 + 12 + 2.5
	var rowh := []
	for row in rows:
		var hh := 16 * 1.2 + 16 + 1
		if row[1][1] != "" or row[2][1] != "":
			hh += 16 * 0.78 * 1.2 + 1
		rowh.append(hh)
	var toth := 30 * 1.0 + 16 + 2
	var tbl_h := 4 + 4 + rh_th
	for hh in rowh:
		tbl_h += hh
	tbl_h += toth + 4 + 4
	var slate_h := 14.0 + tbl_h
	info.sl = {"y": y + 14, "h": tbl_h, "rows": rows, "rowh": rowh, "th": rh_th, "toth": toth}
	y += 14 + tbl_h + 18
	if _rew != null:
		var b := "+%d xu" % _rew.xu if _rew.xu > 0 else "Hết lượt thưởng hôm nay"
		var mid := "gửi về vườn" if _rew.xu > 0 else ""
		var sm := (("Hôm nay còn %d ván thắng có thưởng" % _rew.left) if _rew.left > 0 else "Hết lượt thưởng hôm nay, mai chơi tiếp nghen") if _rew.xu > 0 else "Mỗi ngày thắng máy %d ván đầu được xu, mai quay lại nghen" % int(_rew.max)
		var sml := wrapt(sm, 12.5, 600, 600, iw - 32)
		var rw := maxf(tw(b, 20, 800), tw(mid, 14, 600))
		for ln in sml:
			rw = maxf(rw, line_w(ln, 12.5, 600, 600))
		rw = minf(iw, rw + 32)
		var rh := 8 + 20 * 1.1 + 2 + (14 * 1.25 + 2 if mid != "" else 0.0) + sml.size() * 12.5 * 1.3 + 8
		info.rew = {"y": y - 4, "b": b, "mid": mid, "sm": sml, "w": rw, "h": rh}
		y += -4 + rh + 14
	var bh := btn_h()
	var bw := (iw - 10) / 2
	if iw >= 410:
		items.append({"r": Rect2(x0, y, bw, bh), "tap": _again, "id": "again", "scroll": true, "btn": "Ván mới"})
		items.append({"r": Rect2(x0 + bw + 10, y, bw, bh), "tap": _to_menu, "id": "tomenu", "scroll": true, "btn": "Đổi đối thủ", "kind": "w"})
		y += bh
	else:
		items.append({"r": Rect2(x0, y, iw, bh), "tap": _again, "id": "again", "scroll": true, "btn": "Ván mới"})
		y += bh + 10
		items.append({"r": Rect2(x0, y, iw, bh), "tap": _to_menu, "id": "tomenu", "scroll": true, "btn": "Đổi đối thủ", "kind": "w"})
		y += bh
	y += CP[2] + BAM
	ops.append(["end", 0.0, info, x0, iw])
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
	var x0: float = op[3]
	var iw: float = op[4]
	var cw := iw + x0 * 2
	# chân dung trên bảng con, vòng vàng + khung gỗ
	var ar := Rect2(o.x + (cw - 96) / 2, o.y + info.av_y, 96, 96)
	solid_sh(ci, ar, 16, 4, Color(60 / 255.0, 30 / 255.0, 10 / 255.0, 0.25), 3)
	box(ci, ar.grow(3), GOLD, 19)
	box(ci, ar, FRAME, 16)
	tex(ci, ar.grow(-5), "uislate", 128, 11)
	avatar(ci, _end.av, ar.grow(-5))
	draw_lines(ci, info.tl, o.x + x0, o.y + info.t_y, 40, 1.05, 800, 800, BRICK2, Color(0, 0, 0, 0), "center", iw)
	draw_lines(ci, info.sub, o.x + x0, o.y + info.s_y, 14.5, 1.3, 500, 500, INK2, Color(0, 0, 0, 0), "center", iw)
	# bảng con: viền gỗ 6 ngoài, bóng gỗ đậm, mặt đá đen
	var sl: Dictionary = info.sl
	var sr := Rect2(o.x + x0 + 6, o.y + sl.y, iw - 12, sl.h)
	solid_sh(ci, sr, 20, 4, WD2, 6)
	box(ci, sr.grow(6), FRAME, 20)
	tex(ci, sr.grow(-7), "uislate", 256, 7)
	var tr := Rect2(sr.position.x + 7 + 12, sr.position.y + 7 + 4, sr.size.x - 14 - 24, sr.size.y - 14 - 8)
	var c1w := tr.size.x * 0.4
	var c2w := tr.size.x * 0.3
	var ty := tr.position.y
	var sc: Array = _end.sc
	for p in [0, 1]:
		var cx: float = tr.position.x + c1w + p * c2w
		var nm: String = ellip(g.Gm.names[p], 17, 700, c2w - 8)
		text(ci, nm, cx, ty + 6, 17, 700, Color.WHITE, 1.1, "center", c2w)
		var nw := minf(c2w - 8, tw(nm, 17, 700) + 8)
		ci.draw_rect(Rect2(Vector2(cx + 4, ty + sl.th - 2.5) * K, Vector2(c2w - 8, 2.5) * K), PC[p])
	ty += sl.th
	var dash := func(yy: float, col: Color, w: float) -> void:
		var xx := tr.position.x
		while xx < tr.end.x:
			ci.draw_line(Vector2(xx, yy) * K, Vector2(minf(xx + 3, tr.end.x), yy) * K, col, maxf(1.0, w * K))
			xx += 6
	for i in sl.rows.size():
		var row: Array = sl.rows[i]
		var hh: float = sl.rowh[i]
		dash.call(ty, Color(CHALK, 0.3), 1.0)
		text(ci, row[0], tr.position.x + 4, ty + 9, 16, 600, Color("#c9d3c6"), 1.2)
		for p in [0, 1]:
			var cell: Array = row[1 + p]
			var cx: float = tr.position.x + c1w + p * c2w
			var yy := ty + 9
			if cell[0] != "":
				text(ci, cell[0], cx, yy, 16, 600, CHALK, 1.2, "center", c2w)
				yy += 16 * 1.2 + 1
			if cell[1] != "":
				text(ci, cell[1], cx, yy, 16 * 0.78, 600, Color(CHALK, 0.72), 1.2, "center", c2w)
		ty += hh
	ci.draw_rect(Rect2(Vector2(tr.position.x, ty) * K, Vector2(tr.size.x, 2) * K), Color(CHALK, 0.55))
	text(ci, "Tổng", tr.position.x + 4, ty + 10, 30, 800, Color.WHITE, 1.0)
	for p in [0, 1]:
		var win: bool = sc[p] > sc[1 - p]
		text(ci, str(sc[p]), tr.position.x + c1w + p * c2w, ty + 10, 30, 800, Color("#ffe27a") if win else Color.WHITE, 1.0, "center", c2w)
	if info.has("rew"):
		var rw: Dictionary = info.rew
		var rr := Rect2(o.x + (cw - rw.w) / 2, o.y + rw.y, rw.w, rw.h)
		box(ci, rr, Color("#fbefd3"), 14)
		ring_in(ci, rr, 14, 1.5, Color("#e7c77a"))
		var yy := rr.position.y + 8
		text(ci, rw.b, rr.position.x, yy, 20, 800, Color("#8a5a00"), 1.1, "center", rr.size.x)
		yy += 20 * 1.1 + 2
		if rw.mid != "":
			text(ci, rw.mid, rr.position.x, yy, 14, 600, INK2, 1.25, "center", rr.size.x)
			yy += 14 * 1.25 + 2
		draw_lines(ci, rw.sm, rr.position.x + 16, yy, 12.5, 1.3, 600, 600, INK2, Color(0, 0, 0, 0), "center", rr.size.x - 32)

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
		var ca: float = move_toward(_card_a[p], 1.0 if turn else 0.92, dt / 0.25)
		var ta: float = move_toward(_tag_a[p], 1.0 if turn else 0.0, dt / 0.2)
		if ca != _card_a[p] or ta != _tag_a[p] or (turn and Gm.aiWaiting):
			_card_a[p] = ca
			_tag_a[p] = ta
			cards[p].queue_redraw()
	if cur_ov != "" and _ov_t < 0.4:
		_ov_t += dt
		ovs[cur_ov].queue_redraw()
