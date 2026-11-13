extends Control
# One element of the web game's UI: a CSS box (background, corners, shadows, borders, pictures)
# with optional text. Positions are css px (as the browser measured them); `z` is the element's
# css zoom (the web HUD and Kho run at zoom .75), which scales radius, shadows, font size, padding.
# Children: _bg (shader box, grown for outer shadows), _deco (url background pictures, clipped to
# the box), _kids (child Boxes, then _fg = own text and pictures; clipped when css overflow hides).

const Css = preload("res://ui/css.gd")

signal pressed

var r := Rect2()          # css px, relative to the parent Box
var z := 1.0
var css := {}
var texts := []           # {s, rect(css, local), size, w, col, al, sh:[], wrap}
var pics := []            # {tex, rect(css, local), mod, sh}
var press_fx := ""        # "", "down" (translateY 2), "scale" (.9), "scale94"
var _bg: Control = null
var _mat: ShaderMaterial = null
var _deco: Control = null
var _decos := []          # {tex, rect, tile}
var _kids: Control = null
var _fg: Control = null
var _down := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kids = Control.new()
	_kids.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kids)
	_fg = Control.new()
	_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fg.draw.connect(_draw_fg)
	_kids.add_child(_fg)

func place(rect: Rect2) -> void:
	r = rect
	position = r.position * Css.K
	size = r.size * Css.K
	_kids.size = size
	_fg.size = size
	_style()
	_fg.queue_redraw()

func style(s: String, zoom := -1.0) -> void:
	if zoom > 0.0:
		z = zoom
	css = Css.parse(s)
	if css.has("opacity"):
		modulate.a = float(css["opacity"])
	var ov: String = css.get("overflow", "visible")
	_kids.clip_contents = ov == "hidden" or ov == "auto" or ov == "clip" or ov == "scroll"
	_style()

func _needs_shader() -> bool:
	if css.has("background-color") or css.has("box-shadow") or css.has("backdrop-filter"):
		return true
	for k in ["border-top", "border-right", "border-bottom", "border-left"]:
		if _border(k) > 0.0:
			return true
	for L in Css.split_top(css.get("background-image", "")):
		if L != "none" and not L.begins_with("url("):
			return true
	return false

func _border(k: String) -> float:
	var v: String = css.get(k, "")
	if v == "" or v.find("none") >= 0 or v.find("hidden") >= 0:
		return 0.0
	return Css.px(v.split(" ", false)[0]) * z

func _border_c(k: String) -> Color:
	var v: String = css.get(k, "")
	var a := v.split(" ", false)
	if a.size() < 3:
		return Color(0, 0, 0, 0)
	return Css.color(v.substr(v.find(a[2])))

func _style() -> void:
	if r.size.x <= 0.0 and r.size.y <= 0.0:
		return
	_style_pictures()
	if not _needs_shader():
		return
	var bd := css.has("backdrop-filter") and String(css["backdrop-filter"]).begins_with("blur(")
	if _bg == null:
		_bg = Control.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mat = ShaderMaterial.new()
		_mat.shader = Css.shader(bd)
		_bg.material = _mat
		_bg.draw.connect(func(): _bg.draw_rect(Rect2(Vector2.ZERO, _bg.size), Color.WHITE))
		add_child(_bg)
		move_child(_bg, 0)
	var w := r.size.x
	var h := r.size.y
	var M := _mat
	var sh: Array = Css.shadows(css.get("box-shadow", ""))
	var m := 0.0
	for s in sh:
		if not s["in"]:
			m = maxf(m, (absf(s.o.x) + absf(s.o.y) + s.b * 1.5 + s.s) * z)
	_bg.position = Vector2(-m, -m) * Css.K
	_bg.size = (r.size + Vector2(2 * m, 2 * m)) * Css.K
	_bg.queue_redraw()
	M.set_shader_parameter("size", r.size)
	M.set_shader_parameter("margin", m)
	M.set_shader_parameter("px", Css.K)
	if bd:
		M.set_shader_parameter("bd_blur", Css.px(String(css["backdrop-filter"]).substr(5).trim_suffix(")")) * z)
	var rad := Css.radius(css.get("border-radius", ""), w / z, h / z) * z
	M.set_shader_parameter("radius", rad)
	M.set_shader_parameter("bg_color", Css.color(css.get("background-color", "")))
	var ga := 0
	var gb := 0
	var layers := Css.split_top(css.get("background-image", ""))
	# css draws the first layer on top: walk from the bottom
	for li in range(layers.size() - 1, -1, -1):
		var L := layers[li]
		if L == "none" or L.begins_with("url("):
			continue
		var g := Css.gradient(L, w / z, h / z)
		# a gradient layer can have its own css size/position (Kho tab: 1px highlight line)
		var gsz: String = _layer(css.get("background-size", ""), li)
		var grc := Vector4.ZERO
		if gsz != "" and not gsz.begins_with("auto") and not L.begins_with("repeating"):
			var a := Css.split_top(gsz, " ")
			var gw := _len(a[0], w)
			var gh := _len(a[1], h) if a.size() > 1 and a[1] != "auto" else h
			var pa := Css.split_top(_layer(css.get("background-position", "0% 0%"), li), " ")
			grc = Vector4(_bgpos(pa[0], w - gw), _bgpos(pa[1] if pa.size() > 1 else "50%", h - gh), gw, gh)
			g = Css.gradient(L, gw / z, gh / z)
		var cs: Array = g.c
		var ps: Array = g.p
		var cc := PackedVector4Array()
		var pp := PackedFloat32Array()
		for i in mini(10, cs.size()):
			var c: Color = cs[i]
			cc.append(Vector4(c.r, c.g, c.b, c.a))
			pp.append(float(ps[i]) * (z if g.px else 1.0))
		while cc.size() < 10:
			cc.append(Vector4.ZERO)
			pp.append(0.0)
		if String(g.kind).begins_with("repeating"):
			gb = 1
			M.set_shader_parameter("gb_n", mini(10, cs.size()))
			M.set_shader_parameter("gb_c", cc)
			M.set_shader_parameter("gb_p", pp)
			M.set_shader_parameter("gb_ang", g.ang)
			M.set_shader_parameter("gb_period", float(ps[ps.size() - 1]) * z)
		else:
			ga = 1 if String(g.kind).begins_with("linear") else 2
			M.set_shader_parameter("ga_rect", grc)
			M.set_shader_parameter("ga_clip", 1 if _layer(css.get("background-repeat", "repeat"), li).begins_with("no-repeat") and grc.z > 0.0 else 0)
			M.set_shader_parameter("ga_kind", ga)
			M.set_shader_parameter("ga_n", mini(10, cs.size()))
			M.set_shader_parameter("ga_c", cc)
			M.set_shader_parameter("ga_p", pp)
			M.set_shader_parameter("ga_px", 1 if g.px else 0)
			if ga == 1:
				M.set_shader_parameter("ga_ang", g.ang)
			else:
				M.set_shader_parameter("ga_ctr", g.ctr * (z if g.cpx else 1.0))
				M.set_shader_parameter("ga_cpx", 1 if g.cpx else 0)
	if ga == 0:
		M.set_shader_parameter("ga_kind", 0)
	if gb == 0:
		M.set_shader_parameter("gb_n", 0)
	var g4 := PackedVector4Array()
	var c4 := PackedVector4Array()
	var inn := PackedFloat32Array()
	for s in sh:
		g4.append(Vector4(s.o.x * z, s.o.y * z, s.b * z, s.s * z))
		var c: Color = s.c
		c4.append(Vector4(c.r, c.g, c.b, c.a))
		inn.append(1.0 if s["in"] else 0.0)
	while g4.size() < 8:
		g4.append(Vector4.ZERO)
		c4.append(Vector4.ZERO)
		inn.append(0.0)
	M.set_shader_parameter("sh_n", mini(8, sh.size()))
	M.set_shader_parameter("sh_g", g4)
	M.set_shader_parameter("sh_c", c4)
	M.set_shader_parameter("sh_in", inn)
	M.set_shader_parameter("bw", Vector4(_border("border-top"), _border("border-right"), _border("border-bottom"), _border("border-left")))
	M.set_shader_parameter("bc_t", _border_c("border-top"))
	M.set_shader_parameter("bc_r", _border_c("border-right"))
	M.set_shader_parameter("bc_b", _border_c("border-bottom"))
	M.set_shader_parameter("bc_l", _border_c("border-left"))

# url("data:image/svg+xml,...") background layers: pictures placed like css size/position/repeat
func _style_pictures() -> void:
	var layers := Css.split_top(css.get("background-image", ""))
	var any := false
	for L in layers:
		if L.begins_with("url("):
			any = true
	if not any:
		return
	if _deco == null:
		_deco = Control.new()
		_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_deco.clip_contents = true
		_deco.draw.connect(_draw_deco)
		add_child(_deco)
		move_child(_deco, 1 if _bg != null else 0)
	_deco.size = size
	_decos.clear()
	var w := r.size.x
	var h := r.size.y
	for li in range(layers.size() - 1, -1, -1):
		var L := layers[li]
		if not L.begins_with("url("):
			continue
		var svg := Css.url_svg(L)
		if svg == "":
			continue
		var asp := Css.svg_aspect(svg)
		var ts: String = _layer(css.get("background-size", ""), li)
		var tp: String = _layer(css.get("background-position", ""), li)
		var trp: String = _layer(css.get("background-repeat", "repeat"), li)
		var tw := w
		var th := h
		if (ts == "" or ts.begins_with("auto")) and not Css.svg_dims(svg):
			ts = "contain"
		if ts == "contain" or ts == "cover":
			var kk := minf(w / asp.x, h / asp.y) if ts == "contain" else maxf(w / asp.x, h / asp.y)
			tw = asp.x * kk
			th = asp.y * kk
		elif ts != "" and ts != "auto" and ts != "auto auto":
			var a := Css.split_top(ts, " ")
			var sw: String = a[0]
			var shh: String = a[1] if a.size() > 1 else "auto"
			tw = _len(sw, w)
			th = _len(shh, h)
			if sw == "auto":
				tw = th * asp.x / asp.y
			if shh == "auto":
				th = tw * asp.y / asp.x
		else:
			tw = asp.x * z
			th = asp.y * z
		var ox := 0.0
		var oy := 0.0
		if tp != "":
			var pa := Css.split_top(tp, " ")
			ox = _bgpos(pa[0], w - tw)
			oy = _bgpos(pa[1] if pa.size() > 1 else "50%", h - th)
		var t := Css.svg_tex(svg, tw, th)
		if t != null:
			_decos.append({"tex": t, "rect": Rect2(ox, oy, tw, th), "tile": not trp.begins_with("no-repeat")})
	_deco.queue_redraw()

func _len(v: String, ref: float) -> float:
	# a css length on one axis: P% of ref, Npx, calc(a +- b)
	v = v.strip_edges()
	if v.ends_with("%"):
		return float(v.trim_suffix("%")) / 100.0 * ref
	if v.begins_with("calc("):
		var a := v.substr(5, v.length() - 6).split(" ", false)
		var rr := _len(a[0], ref)
		var i := 1
		while i + 1 < a.size():
			var q := _len(a[i + 1], ref)
			rr += q if a[i] == "+" else -q
			i += 2
		return rr
	return Css.px(v) * z

func _bgpos(v: String, free: float) -> float:
	# css background-position on one axis; free = box - picture
	v = v.strip_edges()
	if v == "center":
		return free * 0.5
	if v == "right" or v == "bottom":
		return free
	if v == "left" or v == "top":
		return 0.0
	return _len(v, free)

func _draw_deco() -> void:
	var k := Css.K
	for d in _decos:
		var rr: Rect2 = d.rect
		if not d.tile:
			_deco.draw_texture_rect(d.tex, Rect2(rr.position * k, rr.size * k), false)
			continue
		var x0 := fposmod(rr.position.x, rr.size.x) - rr.size.x
		var y := fposmod(rr.position.y, rr.size.y) - rr.size.y
		while y < r.size.y:
			var x := x0
			while x < r.size.x:
				_deco.draw_texture_rect(d.tex, Rect2(Vector2(x, y) * k, rr.size * k), false)
				x += rr.size.x
			y += rr.size.y

func _layer(v: String, i: int) -> String:
	var a := Css.split_top(v)
	if a.size() == 0:
		return ""
	return a[mini(i, a.size() - 1)]

# ---------------------------------------------------------------- content
func add(b: Control) -> Control:
	_kids.add_child(b)
	_kids.move_child(_fg, _kids.get_child_count() - 1)
	return b

func kids() -> Array:
	var out := []
	for c in _kids.get_children():
		if c != _fg:
			out.append(c)
	return out

func text(s: String, rect: Rect2, fsize: float, weight: int, col: Color, al := "center", sh := [], wrap := false) -> int:
	# rect = the text element's box in css px (local); font size already in css px on screen
	texts.append({"s": s, "rect": rect, "size": fsize, "w": weight, "col": col, "al": al, "sh": sh, "wrap": wrap})
	_fg.queue_redraw()
	return texts.size() - 1

func set_text(i: int, s: String) -> void:
	if texts[i].s != s:
		texts[i].s = s
		_fg.queue_redraw()

func pic(t: Texture2D, rect: Rect2, mod := Color.WHITE, sh = null) -> int:
	pics.append({"tex": t, "rect": rect, "mod": mod, "sh": sh})
	_fg.queue_redraw()
	return pics.size() - 1

func redraw() -> void:
	_fg.queue_redraw()

static func text_w(s: String, fsize: float, weight: int) -> float:
	# glyphs are drawn at a whole pixel size; widths are taken back to the exact css size so lines break where the browser breaks them
	var px := fsize * Css.K
	var n := maxi(1, int(round(px)))
	return _line_w(s, Css.font(weight), n) * (px / n) / Css.K

# emoji are pictures (ui/emo/<hex>.webp, the browser's colour emoji); everything else is Nunito
static func _runs(s: String) -> Array:
	var out := []
	var cur := ""
	for ch in s:
		var o := ch.unicode_at(0)
		if o == 0xfe0f:
			continue
		if o == 0x25b2 or o == 0x25bc or o == 0x2605:
			# ▲ ▼ ★ are not in Nunito (the browser takes them from a fallback font): drawn as shapes
			if cur != "":
				out.append(cur)
				cur = ""
			out.append(-o)
		elif Css.emoji(o) != null:
			if cur != "":
				out.append(cur)
				cur = ""
			out.append(o)
		else:
			cur += ch
	if cur != "":
		out.append(cur)
	return out

static func _line_w(s: String, f: Font, fs: int) -> float:
	var w := 0.0
	for q in _runs(s):
		if q is int:
			w += fs * (0.77 if q < 0 else 1.18)
		else:
			w += f.get_string_size(q, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return w

func _draw_line(f: Font, pos: Vector2, s: String, fs: int, col: Color, shadow: bool) -> void:
	var x := pos.x
	for q in _runs(s):
		if q is int and q < 0:
			_shape(-q, x, pos.y, fs, col)
			x += fs * 0.77
		elif q is int:
			if not shadow:
				_fg.draw_texture_rect(Css.emoji(q), Rect2(x, pos.y - fs * 0.98, fs * 1.18, fs * 1.18), false, Color(1, 1, 1, col.a))
			x += fs * 1.18
		else:
			_fg.draw_string(f, Vector2(x, pos.y), q, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			x += f.get_string_size(q, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

func _shape(o: int, x: float, base: float, fs: float, col: Color) -> void:
	var cx := x + fs * 0.385
	var w := fs * 0.35
	var top := base - fs * 0.7
	var bot := base - fs * 0.02
	var pts := PackedVector2Array()
	if o == 0x25bc:
		pts = PackedVector2Array([Vector2(cx - w, top), Vector2(cx + w, top), Vector2(cx, bot)])
	elif o == 0x25b2:
		pts = PackedVector2Array([Vector2(cx, top), Vector2(cx + w, bot), Vector2(cx - w, bot)])
	else:
		var c := Vector2(cx, (top + bot) * 0.5)
		for k in 10:
			var a := -PI / 2 + k * PI / 5
			var r := w * (1.05 if k % 2 == 0 else 0.42)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
	_fg.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	_fg.draw_polyline(pts, col, 1.0, true)

func _draw_fg() -> void:
	var k := Css.K
	if has_meta("arrow"):
		# the little speech-label arrow (css border triangle) with its thin brown edge
		var a: Dictionary = get_meta("arrow")
		var x: float = a.x * k
		var y: float = a.y * k
		var w: float = a.w * k
		_fg.draw_colored_polygon(PackedVector2Array([Vector2(x - w - 0.6 * k, y - 0.5 * k), Vector2(x + w + 0.6 * k, y - 0.5 * k), Vector2(x, y + w + 1.0 * k)]), Color(0.47, 0.32, 0.09, 0.5))
		_fg.draw_colored_polygon(PackedVector2Array([Vector2(x - w, y - 1.0 * k), Vector2(x + w, y - 1.0 * k), Vector2(x, y + w)]), a.c)
	for p in pics:
		if p.tex == null:
			continue
		var rr: Rect2 = p.rect
		if p.sh != null:
			# css filter: drop-shadow(colour ox oy blur): the picture's own shape, offset and tinted
			var c: Color = p.sh.c
			var o: Vector2 = p.sh.o
			var bl: float = p.sh.b
			var n := 1 if bl < 0.6 else 4
			for i in n:
				var j := Vector2.ZERO if n == 1 else Vector2(cos(i * PI * 0.5), sin(i * PI * 0.5)) * bl * 0.5
				_fg.draw_texture_rect(p.tex, Rect2((rr.position + o + j) * k, rr.size * k), false, Color(c.r, c.g, c.b, c.a / n * (1.6 if n > 1 else 1.0)))
		_fg.draw_texture_rect(p.tex, Rect2(rr.position * k, rr.size * k), false, p.mod)
	for t in texts:
		if t.s == "":
			continue
		var f := Css.font(t.w)
		var fs := int(round(t.size * k))
		var rr: Rect2 = t.rect
		var ax := 0.5
		if t.al == "left":
			ax = 0.0
		elif t.al == "right":
			ax = 1.0
		var lines := [t.s]
		if t.wrap:
			lines = _wrap(t.s, f, fs, rr.size.x * k, t.size * k / maxf(1.0, fs))
		var lh := f.get_height(fs)
		var tot := lh * lines.size()
		var y0 := rr.position.y * k + (rr.size.y * k - tot) * 0.5 + f.get_ascent(fs)
		for li in lines.size():
			# no clipping: Godot's draw_string cuts text wider than `width`, so place it ourselves
			var lw := _line_w(lines[li], f, fs)
			var pos := Vector2(rr.position.x * k + (rr.size.x * k - lw) * ax, y0 + li * lh)
			for s in t.sh:
				var c: Color = s.c
				if s.b > 0.0:
					c.a *= 0.6
				_draw_line(f, pos + s.o * k, lines[li], fs, c, true)
			_draw_line(f, pos, lines[li], fs, t.col, false)

func _wrap(s: String, f: Font, fs: int, w: float, q := 1.0) -> Array:
	var out := []
	var cur := ""
	for word in s.split(" "):
		var t := word if cur == "" else cur + " " + word
		if cur != "" and _line_w(t, f, fs) * q > w:
			out.append(cur)
			cur = word
		else:
			cur = t
	if cur != "":
		out.append(cur)
	return out

# ---------------------------------------------------------------- press
func clickable(fx := "down") -> void:
	press_fx = fx
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(e: InputEvent) -> void:
	if mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	var down := false
	var up := false
	if e is InputEventScreenTouch:
		down = e.pressed
		up = not e.pressed
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		down = e.pressed
		up = not e.pressed
	else:
		return
	accept_event()
	if down:
		_down = true
		_fx(true)
	elif up and _down:
		_down = false
		_fx(false)
		if Rect2(Vector2.ZERO, size).grow(6 * Css.K).has_point(e.position):
			pressed.emit()

func _fx(on: bool) -> void:
	if press_fx == "down":
		position = (r.position + (Vector2(0, 2) if on else Vector2.ZERO)) * Css.K
	elif press_fx.begins_with("scale"):
		var s := 0.9 if press_fx == "scale" else (0.94 if press_fx == "scale94" else 0.92)
		pivot_offset = size * 0.5
		scale = Vector2.ONE * (s if on else 1.0)
