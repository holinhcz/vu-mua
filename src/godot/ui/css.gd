extends RefCounted
# Reads the CSS values of the web game (as the browser computes them) so Godot draws the same boxes.
# Everything is in css px; K = screen pixels per css px (the phone's devicePixelRatio).

static var K := 1.0
static var _fonts := {}
static var _tex := {}
static var _shader: Shader = null

static func font(w: int) -> Font:
	var ws := [400, 600, 700, 800]
	var best := 700
	var bd := 9999
	for x in ws:
		if absi(x - w) < bd:
			bd = absi(x - w)
			best = x
	if w >= 900:
		best = 800
	if not _fonts.has(best):
		var f := FontFile.new()
		f.load_dynamic_font("res://ui/font/nunito_%d.ttf" % best)
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		if w >= 900:
			var v := FontVariation.new()
			v.base_font = f
			v.variation_embolden = 0.35
			_fonts[900] = v
		_fonts[best] = f
	if w >= 900:
		return _fonts[900] if _fonts.has(900) else _fonts[best]
	return _fonts[best]

static var _shader_bd: Shader = null
static func shader(backdrop := false) -> Shader:
	if _shader == null:
		_shader = load("res://ui/box.gdshader")
	if not backdrop:
		return _shader
	if _shader_bd == null:
		# same box, plus css backdrop-filter: blur() of what is drawn behind it
		_shader_bd = Shader.new()
		_shader_bd.code = _shader.code.replace("//BD_UNIFORMS", "uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;\nuniform float bd_blur = 3.0;").replace("//BD_FRAGMENT", """{
		float rad = max(bd_blur * px, 1.0);
		float lod = log2(max(rad * 0.5, 1.0));
		vec4 acc = vec4(0.0);
		float ws = 0.0;
		for (int i = -2; i <= 2; i++) {
			for (int j = -2; j <= 2; j++) {
				vec2 o = vec2(float(i), float(j)) * rad * 0.6;
				float w = exp(-dot(o, o) / (2.0 * rad * rad));
				acc += textureLod(scr, SCREEN_UV + o * SCREEN_PIXEL_SIZE, lod) * w;
				ws += w;
			}
		}
		box = over(box, vec4(acc.rgb / ws, 1.0));
	}""")
	return _shader_bd

# ---------------------------------------------------------------- values
static func color(s: String) -> Color:
	s = s.strip_edges()
	if s == "transparent" or s == "":
		return Color(0, 0, 0, 0)
	if s == "white" or s == "#fff":
		return Color(1, 1, 1)
	if s.begins_with("#"):
		return Color.html(s)
	if s.begins_with("rgb"):
		var a := s.substr(s.find("(") + 1).trim_suffix(")").replace("/", ",").split(",", false)
		var r := Color(float(a[0]) / 255.0, float(a[1]) / 255.0, float(a[2]) / 255.0, 1.0)
		if a.size() > 3:
			r.a = float(a[3])
		return r
	return Color.from_string(s, Color(0, 0, 0, 0))

static func split_top(s: String, sep := ",") -> PackedStringArray:
	# split on sep outside brackets and quotes
	var out := PackedStringArray()
	var d := 0
	var q := ""
	var cur := ""
	for ch in s:
		if q != "":
			cur += ch
			if ch == q:
				q = ""
			continue
		if ch == "\"" or ch == "'":
			q = ch
		elif ch == "(":
			d += 1
		elif ch == ")":
			d -= 1
		if ch == sep and d == 0:
			out.append(cur.strip_edges())
			cur = ""
		else:
			cur += ch
	if cur.strip_edges() != "":
		out.append(cur.strip_edges())
	return out

static func px(s: String, ref := 0.0) -> float:
	s = s.strip_edges()
	if s.ends_with("%"):
		return float(s.trim_suffix("%")) / 100.0 * ref
	return float(s.trim_suffix("px"))

static func parse(css: String) -> Dictionary:
	var d := {}
	for decl in split_top(css, ";"):
		var i := decl.find(":")
		if i < 0:
			continue
		d[decl.substr(0, i).strip_edges()] = decl.substr(i + 1).strip_edges()
	return d

static func radius(s: String, w: float, h: float) -> Vector4:
	if s == "":
		return Vector4.ZERO
	var a := s.split(" ", false)
	var m := minf(w, h)
	var v := []
	for x in a:
		v.append(minf(px(x, m), m * 0.5) if x.ends_with("%") else px(x))
	if v.size() == 1:
		return Vector4(v[0], v[0], v[0], v[0])
	if v.size() == 2:
		return Vector4(v[0], v[1], v[0], v[1])
	if v.size() == 3:
		return Vector4(v[0], v[1], v[2], v[1])
	return Vector4(v[0], v[1], v[2], v[3])

static func shadows(s: String) -> Array:
	var out := []
	if s == "" or s == "none":
		return out
	for part in split_top(s):
		var inset := part.find(" inset") >= 0 or part.begins_with("inset")
		part = part.replace("inset", "").strip_edges()
		var ci := part.find(")")
		var col: Color
		var rest: String
		if part.begins_with("rgb"):
			col = color(part.substr(0, ci + 1))
			rest = part.substr(ci + 1)
		else:
			var sp := part.split(" ", false)
			col = color(sp[sp.size() - 1]) if not sp[0].ends_with("px") else color(sp[sp.size() - 1])
			rest = part
		var n := []
		for t in rest.split(" ", false):
			if t.ends_with("px") or t == "0":
				n.append(px(t))
		while n.size() < 4:
			n.append(0.0)
		out.append({"o": Vector2(n[0], n[1]), "b": n[2], "s": n[3], "c": col, "in": inset})
	return out

static func _stops(args: PackedStringArray, L: float) -> Dictionary:
	# returns {c:[], p:[], px:bool}; positions in px when any stop is px
	var cs := []
	var ps := []
	var anypx := false
	for a in args:
		var ci := a.find(")")
		var c: Color
		var rest := ""
		if a.begins_with("rgb"):
			c = color(a.substr(0, ci + 1))
			rest = a.substr(ci + 1).strip_edges()
		else:
			var sp := a.split(" ", false)
			c = color(sp[0])
			rest = " ".join(sp.slice(1))
		var pos := rest.split(" ", false)
		if pos.size() == 0:
			cs.append(c)
			ps.append(null)
		else:
			for q in pos:
				cs.append(c)
				if q.ends_with("px"):
					anypx = true
				ps.append(q)
	var out := []
	for i in ps.size():
		var q = ps[i]
		if q == null:
			out.append(null)
		elif String(q).ends_with("%"):
			out.append(float(String(q).trim_suffix("%")) / 100.0 * (L if anypx else 1.0))
		else:
			out.append(px(q) / (1.0 if anypx else L))
	# fill missing like css: first 0, last 1, between spread evenly
	if out.size() > 0 and out[0] == null:
		out[0] = 0.0
	var endv := L if anypx else 1.0
	if out.size() > 1 and out[out.size() - 1] == null:
		out[out.size() - 1] = endv
	var i := 1
	while i < out.size():
		if out[i] == null:
			var j := i
			while out[j] == null:
				j += 1
			for k in range(i, j):
				out[k] = lerpf(out[i - 1], out[j], float(k - i + 1) / float(j - i + 1))
			i = j
		# css: a stop before an earlier one is clamped up
		out[i] = maxf(out[i], out[i - 1])
		i += 1
	return {"c": cs, "p": out, "px": anypx}

static func gradient(g: String, w: float, h: float) -> Dictionary:
	var kind := g.substr(0, g.find("("))
	var inner := g.substr(g.find("(") + 1)
	inner = inner.substr(0, inner.length() - 1)
	var args := split_top(inner)
	var r := {"kind": kind}
	if kind.ends_with("linear-gradient"):
		var ang := 180.0
		if args.size() > 0 and (args[0].ends_with("deg") or args[0].begins_with("to ")):
			var a0 := args[0]
			if a0.ends_with("deg"):
				ang = float(a0.trim_suffix("deg"))
			else:
				ang = {"to right": 90.0, "to left": 270.0, "to top": 0.0, "to bottom": 180.0}.get(a0, 180.0)
			args = args.slice(1)
		var an := deg_to_rad(ang)
		var L := absf(w * sin(an)) + absf(h * cos(an))
		r.ang = ang
		r.merge(_stops(args, L))
		if kind.begins_with("repeating"):
			# repeating stripes are always given in px
			var s := _stops(args, L)
			if not s.px:
				for i in s.p.size():
					s.p[i] *= L
			r.merge(s, true)
			r.px = true
	else:
		# radial-gradient(circle at X Y, stops)
		var ctr := Vector2(0.5, 0.5)
		var cpx := false
		if args.size() > 0 and (args[0].begins_with("circle") or args[0].begins_with("ellipse") or args[0].begins_with("at ")):
			var a0 := args[0]
			var at := a0.find("at ")
			if at >= 0:
				var xy := a0.substr(at + 3).split(" ", false)
				if xy[0].ends_with("px"):
					cpx = true
					ctr = Vector2(px(xy[0]), px(xy[1]))
				else:
					ctr = Vector2(px(xy[0], 1.0), px(xy[1], 1.0))
			args = args.slice(1)
		var c := ctr * (Vector2.ONE if cpx else Vector2(w, h))
		var L := maxf(maxf(c.length(), (c - Vector2(w, 0)).length()), maxf((c - Vector2(0, h)).length(), (c - Vector2(w, h)).length()))
		r.ctr = ctr
		r.cpx = cpx
		r.merge(_stops(args, L))
	return r

static func svg_tex(svg: String, w: float, h: float) -> Texture2D:
	# rasterise at screen resolution so it is sharp
	var key := str(svg.hash()) + "_" + str(int(w * K)) + "x" + str(int(h * K))
	if _tex.has(key):
		return _tex[key]
	var img := Image.new()
	var vb := svg_aspect(svg)
	var sc := maxf(w * K / vb.x, h * K / vb.y)
	if img.load_svg_from_string(svg, maxf(0.05, sc)) != OK:
		return null
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t

static func svg_dims(svg: String) -> bool:
	# true when the <svg> tag says its own width and height (else only a viewBox ratio)
	var re := RegEx.new()
	re.compile("<svg[^>]*?\\swidth=['\"]([0-9.]+)[^>]*?\\sheight=['\"]([0-9.]+)")
	return re.search(svg) != null

static func svg_aspect(svg: String) -> Vector2:
	# the svg's own size as ThorVG rasterises it: width/height when given, else the viewBox
	var re := RegEx.new()
	re.compile("<svg[^>]*?\\swidth=['\"]([0-9.]+)[^>]*?\\sheight=['\"]([0-9.]+)")
	var m := re.search(svg)
	if m:
		return Vector2(float(m.get_string(1)), float(m.get_string(2)))
	var i := svg.find("viewBox=")
	if i >= 0:
		var q := svg.substr(i + 8, 1)
		var v := svg.substr(i + 9, svg.find(q, i + 9) - i - 9).replace(",", " ").split(" ", false)
		if v.size() == 4 and float(v[2]) > 0.0:
			return Vector2(float(v[2]), float(v[3]))
	return Vector2(64, 64)

static func url_svg(u: String) -> String:
	# url("data:image/svg+xml,%3Csvg...") -> svg text
	var a := u.find("data:image/svg+xml,")
	if a < 0:
		return ""
	var s := u.substr(a + 19)
	var e := s.rfind("\")")
	if e < 0:
		e = s.rfind(")")
	s = s.substr(0, e)
	return s.uri_decode()

static var _emo := {}
static func emoji(code: int) -> Texture2D:
	if code < 0x2190:
		return null
	if not _emo.has(code):
		var path := "res://ui/emo/%x.webp" % code
		_emo[code] = image(path) if FileAccess.file_exists(path) else null
	return _emo[code]

static func image(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var img := Image.new()
	var b := FileAccess.get_file_as_bytes(path)
	if path.ends_with(".webp"):
		img.load_webp_from_buffer(b)
	else:
		img.load_png_from_buffer(b)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[path] = t
	return t
