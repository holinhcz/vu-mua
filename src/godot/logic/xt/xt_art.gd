extends RefCounted
# XẾP TRÁI: hình (vẽ sẵn từ bản web, ui/img/xt/*.webp), chữ Baloo 2, hộp bo góc, thú (animals.webp + .json như ANIM của web).
# Mọi thứ đo bằng css px của web; cái gốc của game phóng to K lần. Chữ vẽ ở cỡ thật (fs*K) cho nét.

const DIR := "res://ui/img/xt/"
const INK := Color("#2b2118")
const INK2 := Color("#5a4630")
const KEM := Color("#fbf3df")
const KEM2 := Color("#f1e2bf")
const GACH := Color("#b4532a")
const GACH_DK := Color("#7e3519")
const LA := Color("#3f7d3a")
const LA_DK := Color("#24502a")
const VANG := Color("#f4c430")
const VANG_DK := Color("#c8901a")
const DO := Color("#d2452f")
const CREAM_TXT := Color("#fff6e2")
const LIP_KEM := Color("#cdb88a")

static var K := 1.0
static var _img := {}
static var _font := {}
static var _base: FontFile = null
static var _sb := {}
static var anim_tex: Texture2D = null
static var anim_meta := {}

static func img(name: String) -> Texture2D:
	if _img.has(name):
		return _img[name]
	var im := Image.new()
	var b := FileAccess.get_file_as_bytes(DIR + name + ".webp")
	if b.is_empty() or im.load_webp_from_buffer(b) != OK:
		_img[name] = null
		return null
	if im.detect_alpha() != Image.ALPHA_NONE:
		im.convert(Image.FORMAT_RGBA8)
		im.fix_alpha_edges()
	im.generate_mipmaps()
	var t := ImageTexture.create_from_image(im)
	_img[name] = t
	return t

static func load_anim() -> void:
	if anim_tex != null:
		return
	anim_tex = img("animals")
	var f := FileAccess.get_file_as_string(DIR + "animals.json")
	var d = JSON.parse_string(f)
	if d is Dictionary:
		anim_meta = d

static func anim_cell(name: String, typ: String, view: String, frame: int):
	var a = anim_meta.get(name, {}).get(typ, {}).get(view, null)
	if a == null or a.size() == 0:
		return null
	var n: int = a.size()
	return a[((frame % n) + n) % n]

# chân ở (x,y), cao h css px (theo khung 0)
static func anim(ci: CanvasItem, name: String, typ: String, view: String, frame: int, x: float, y: float, h: float, flip: bool, mod := Color.WHITE) -> void:
	anim_t(ci, name, typ, view, frame, Transform2D(0, Vector2(x, y)), h, flip, mod)

# lật ngang đúng: dùng transform
static func anim_t(ci: CanvasItem, name: String, typ: String, view: String, frame: int, xf: Transform2D, h: float, flip: bool, mod := Color.WHITE) -> void:
	var c0 = anim_cell(name, typ, view, 0)
	var c = anim_cell(name, typ, view, frame)
	if c0 == null or c == null or anim_tex == null:
		return
	var s: float = h / float(c0[3])
	var t := xf
	if flip:
		t = xf * Transform2D(0, Vector2(-1, 1), 0, Vector2.ZERO)
	ci.draw_set_transform_matrix(t)
	ci.draw_texture_rect_region(anim_tex, Rect2(c[4] * s, c[5] * s, c[2] * s, c[3] * s), Rect2(c[0], c[1], c[2], c[3]), mod)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# ------------------------------------------------------------ chữ
static func font(w: int) -> Font:
	if _font.has(w):
		return _font[w]
	if _base == null:
		_base = FontFile.new()
		_base.load_dynamic_font("res://ui/font/baloo2.ttf")
		_base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_base.hinting = TextServer.HINTING_LIGHT
		_base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		var nf := FontFile.new()
		if nf.load_dynamic_font("res://ui/font/nunito_700.ttf") == OK:
			_base.fallbacks = [nf]
	var v := FontVariation.new()
	v.base_font = _base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): w}
	_font[w] = v
	return v

static func tw(s: String, fs: float, w := 800) -> float:
	return font(w).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(1, int(round(fs * K)))).x / K

# al: 0 trái, 1 giữa, 2 phải; y = giữa dòng
static func text(ci: CanvasItem, s: String, x: float, y: float, fs: float, col: Color, al := 1, w := 800, ol := 0.0, olc := INK, xf := Transform2D.IDENTITY) -> void:
	if s == "":
		return
	var f := font(w)
	var px := maxi(1, int(round(fs * K)))
	var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var asc := f.get_ascent(px)
	var des := f.get_descent(px)
	var ox := 0.0
	if al == 1:
		ox = -sw / 2
	elif al == 2:
		ox = -sw
	var base := Vector2(ox, (asc - des) * 0.5 - des * 0.15)
	ci.draw_set_transform_matrix(xf * Transform2D(0, Vector2(1.0 / K, 1.0 / K), 0, Vector2(x, y)))
	if ol > 0:
		ci.draw_string_outline(f, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(1, int(round(ol * K))), olc)
	ci.draw_string(f, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# xuống dòng theo bề rộng, trả về mảng dòng
static func wrap(s: String, fs: float, w: int, maxw: float) -> Array:
	var out := []
	for para in s.split("\n"):
		var cur := ""
		for word in para.split(" ", false):
			var t := word if cur == "" else cur + " " + word
			if cur != "" and tw(t, fs, w) > maxw:
				out.append(cur)
				cur = word
			else:
				cur = t
		out.append(cur)
	return out

# ------------------------------------------------------------ hộp
static func _box_sb(key: String) -> StyleBoxFlat:
	if not _sb.has(key):
		if _sb.size() > 600:
			_sb.clear()
		_sb[key] = StyleBoxFlat.new()
	return _sb[key]

# hộp bo góc: nền, viền, bóng (dx,dy,blur,col)
static func box(ci: CanvasItem, r: Rect2, bg: Color, rad: float, bw := 0.0, bc := Color(0, 0, 0, 0), sh := [], xf := Transform2D.IDENTITY) -> void:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	for s in sh:
		var key := "sh%s|%s|%s|%s" % [str(s), rad, K, r.size]
		var b := _box_sb(key)
		if b.shadow_size == 0:
			b.bg_color = Color(0, 0, 0, 0)
			b.set_corner_radius_all(int(rad * K))
			b.shadow_color = s[3]
			b.shadow_size = maxi(1, int(s[2] * K * 0.5))
			b.shadow_offset = Vector2(s[0], s[1]) * K
			b.anti_aliasing = true
		_draw_sb(ci, b, r, xf)
	var key2 := "b%s|%s|%s|%s|%s" % [bg, rad, bw, bc, K]
	var m := _box_sb(key2)
	m.bg_color = bg
	m.set_corner_radius_all(int(rad * K))
	m.anti_aliasing = true
	if bw > 0:
		m.set_border_width_all(maxi(1, int(round(bw * K))))
		m.border_color = bc
	_draw_sb(ci, m, r, xf)

static func _draw_sb(ci: CanvasItem, b: StyleBoxFlat, r: Rect2, xf := Transform2D.IDENTITY) -> void:
	# hộp vẽ ở cỡ điểm ảnh thật cho bo góc mịn (xf: phép biến hình của khung chứa, vd hộp thoại đang bật lên)
	ci.draw_set_transform_matrix(xf * Transform2D(0, Vector2(1.0 / K, 1.0 / K), 0, r.position))
	ci.draw_style_box(b, Rect2(Vector2.ZERO, r.size * K))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

static func rrect_pts(r: Rect2, rad: float, n := 6) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var out := PackedVector2Array()
	if rad <= 0.01:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var cs := [[r.end.x - rad, r.position.y + rad, -PI / 2], [r.end.x - rad, r.end.y - rad, 0.0], [r.position.x + rad, r.end.y - rad, PI / 2], [r.position.x + rad, r.position.y + rad, PI]]
	for c in cs:
		for k in n + 1:
			var a: float = c[2] + PI / 2 * k / n
			var q := Vector2(c[0] + cos(a) * rad, c[1] + sin(a) * rad)
			# bỏ điểm trùng (bo tròn bằng nửa cạnh) để chia tam giác không hỏng
			if out.size() and out[out.size() - 1].distance_squared_to(q) < 0.0004:
				continue
			out.append(q)
	if out.size() > 2 and out[0].distance_squared_to(out[out.size() - 1]) < 0.0004:
		out.remove_at(out.size() - 1)
	return out

static func ell_pts(c: Vector2, rx: float, ry: float, n := 24, rot := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n:
		var a := TAU * i / n
		var p := Vector2(cos(a) * rx, sin(a) * ry)
		out.append(c + Vector2(p.x * cr - p.y * sr, p.x * sr + p.y * cr))
	return out

static func ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	if rx <= 0 or ry <= 0:
		return
	ci.draw_colored_polygon(ell_pts(c, rx, ry, 24, rot), col)

# polygon tô theo dải màu tuyến tính (a -> b), stops [[t, Color],...]
static func grad_poly(ci: CanvasItem, pts: PackedVector2Array, a: Vector2, b: Vector2, stops: Array) -> void:
	var cols := PackedColorArray()
	var d := b - a
	var L2 := maxf(0.0001, d.length_squared())
	for p in pts:
		var t := clampf((p - a).dot(d) / L2, 0.0, 1.0)
		cols.append(stop_col(stops, t))
	ci.draw_polygon(pts, cols)

static func stop_col(stops: Array, t: float) -> Color:
	if t <= stops[0][0]:
		return stops[0][1]
	for i in range(1, stops.size()):
		if t <= stops[i][0]:
			var a = stops[i - 1]
			var b = stops[i]
			return (a[1] as Color).lerp(b[1], (t - a[0]) / maxf(0.0001, b[0] - a[0]))
	return stops[stops.size() - 1][1]

# vòng tròn mềm (dải tỏa tròn) bằng quạt tam giác
static func radial(ci: CanvasItem, c: Vector2, r: float, stops: Array, n := 28) -> void:
	var rings := 6
	for k in rings:
		var t0 := float(k) / rings
		var t1 := float(k + 1) / rings
		var c0 := stop_col(stops, t0)
		var c1 := stop_col(stops, t1)
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var p := PackedVector2Array([c + Vector2(cos(a0), sin(a0)) * r * t0, c + Vector2(cos(a0), sin(a0)) * r * t1, c + Vector2(cos(a1), sin(a1)) * r * t1, c + Vector2(cos(a1), sin(a1)) * r * t0])
			ci.draw_polygon(p, PackedColorArray([c0, c1, c1, c0]))

# chặng đường cong bậc hai / bậc ba thành điểm
static func quad_pts(a: Vector2, c: Vector2, b: Vector2, n := 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		out.append(a * (1 - t) * (1 - t) + c * 2 * (1 - t) * t + b * t * t)
	return out

static func cubic_pts(a: Vector2, b: Vector2, c: Vector2, d: Vector2, n := 12) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var m := 1 - t
		out.append(a * m * m * m + b * 3 * m * m * t + c * 3 * m * t * t + d * t * t * t)
	return out

# đường dày đầu tròn (lineCap round)
static func stroke(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float, caps := true) -> void:
	if pts.size() < 2:
		return
	ci.draw_polyline(pts, col, w, true)
	if caps and w > 1.5:
		ci.draw_circle(pts[0], w * 0.5, col)
		ci.draw_circle(pts[pts.size() - 1], w * 0.5, col)

static func hexc(s: String, a := 1.0) -> Color:
	var c := Color(s)
	c.a = a
	return c

static func star_pts(c: Vector2, r1: float, r2: float, n := 5, rot := -PI / 2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n * 2:
		var r := r1 if i % 2 == 0 else r2
		var a := rot + PI * i / n
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out
