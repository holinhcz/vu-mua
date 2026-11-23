extends RefCounted
# CÂU CÁ BỜ KÊNH: hình (vẽ sẵn bằng Python ở bản web, ui/img/cc/*.webp, nguyên bản không nén mất nét), chữ Baloo 2,
# hộp bo góc, biểu tượng SVG của web (vẽ ra ảnh đúng cỡ điểm ảnh). Mọi thứ đo bằng css px; gốc game phóng to K lần.

const DIR := "res://ui/img/cc/"
const INK := Color(43 / 255.0, 42 / 255.0, 36 / 255.0)   # (11-23) chữ trong bảng như Nông trại (trước #3e2810)
const PAPER := Color("#fdf6e4")
const MET := Color("#fbf0d2")
const MET_IN := Color("#ecd9a8")
const WOOD := Color("#5a3618")
const WOOD2 := Color("#3e2410")
const HEAD := Color("#9a5a2c")
const LEAF := Color("#5f9e3a")
const LEAF2 := Color("#2f6418")
const BRICK := Color("#b5452a")
const BRICK2 := Color("#7a2614")
const GOLD := Color("#f6c040")
const GOLD2 := Color("#8a5a10")
const ROW := Color("#fffaea")
const ROW_B := Color("#d2b47a")
const TH := Color("#f3e3b8")
const SMALL := Color(122 / 255.0, 90 / 255.0, 42 / 255.0)
const SMALL2 := Color(138 / 255.0, 106 / 255.0, 58 / 255.0)
const CREAM := Color("#fff3d0")
const OKBG := Color("#d8efc0")
const OKFG := Color("#2a5a12")
const NOBG := Color("#f6d6cc")
const NOFG := Color("#8a2a14")

static var K := 1.0
static var BASE := Transform2D.IDENTITY   # phép biến hình của khối đang vẽ (nút đang nảy, xu đang phồng)
static var _img := {}
static var _font := {}
static var _base: FontFile = null
static var _sb := {}

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

# ------------------------------------------------------------ chữ
static func font(w: int) -> Font:
	# (11-23 đồng bộ Nông trại) chữ thường = Nunito như Nông trại (4 nét có sẵn 400/600/700/800, lấy nét gần nhất);
	# w >= 900 = chữ tiêu đề lớn Baloo 2 (tên game ở màn đầu, chữ to nổi trên mặt nước)
	if _font.has(w):
		return _font[w]
	var f: Font
	if w >= 900:
		if _base == null:
			_base = FontFile.new()
			_base.load_dynamic_font("res://ui/font/baloo2.ttf")
			_set_aa(_base)
			_base.fallbacks = [font(800)]
		var v := FontVariation.new()
		v.base_font = _base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
		f = v
	else:
		var nw := 400 if w < 500 else (600 if w < 650 else (700 if w < 750 else 800))
		if w != nw:
			f = font(nw)
		else:
			var ff := FontFile.new()
			ff.load_dynamic_font("res://ui/font/nunito_%d.ttf" % nw)
			_set_aa(ff)
			f = ff
	_font[w] = f
	return f

static func _set_aa(ff: FontFile) -> void:
	ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	ff.hinting = TextServer.HINTING_LIGHT
	ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO

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
	ci.draw_set_transform_matrix(BASE * xf * Transform2D(0, Vector2(1.0 / K, 1.0 / K), 0, Vector2(x, y)))
	if ol > 0:
		ci.draw_string_outline(f, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(1, int(round(ol * K))), olc)
	ci.draw_string(f, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	ci.draw_set_transform_matrix(BASE)

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
	ci.draw_set_transform_matrix(BASE * xf * Transform2D(0, Vector2(1.0 / K, 1.0 / K), 0, r.position))
	ci.draw_style_box(b, Rect2(Vector2.ZERO, r.size * K))
	ci.draw_set_transform_matrix(BASE)

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

# vòng tròn mềm (dải tỏa tròn). (Link 11-22 "fps"): trước dựng 121 đỉnh + 660 chỉ số bằng GDScript MỖI LẦN gọi, mỗi
# khung (~0.6 ms máy, x3-5 trên web). Giờ = 1 ảnh tròn mềm trắng dựng sẵn theo dáng độ mờ của các nấc (alpha so với nấc
# giữa), vẽ 1 lệnh draw_texture_rect nhân màu nấc giữa. Các ảnh cùng loại gộp chung 1 lệnh vẽ.
static var _rt := {}
static func radial(ci: CanvasItem, c: Vector2, r: float, stops: Array, _n := 28) -> void:
	var c0: Color = stops[0][1]
	var a0: float = maxf(c0.a, 0.0001)
	var key := ""
	for st in stops:
		key += "%.2f:%.2f," % [st[0], clampf((st[1] as Color).a / a0, 0.0, 4.0)]
	var tx: ImageTexture = _rt.get(key)
	if tx == null:
		var S := 64
		var im := Image.create(S, S, false, Image.FORMAT_RGBA8)
		for y in S:
			for x in S:
				var t := Vector2(x + .5 - S * .5, y + .5 - S * .5).length() / (S * .5)
				var al := 0.0
				if t < 1.0:
					al = clampf(stop_col(stops, t).a / a0, 0.0, 1.0)
				im.set_pixel(x, y, Color(1, 1, 1, al))
		im.generate_mipmaps()
		tx = ImageTexture.create_from_image(im)
		_rt[key] = tx
	ci.draw_texture_rect(tx, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c0.r, c0.g, c0.b, c0.a))

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
# dải nét dày thay đổi + mép mềm 1px, mỗi đoạn 1 màu, đầu cuối tròn: 1 lệnh vẽ (thay cho draw_line + draw_circle từng đoạn)
static func ribbon(ci: CanvasItem, P: PackedVector2Array, wid: PackedFloat32Array, seg_col: PackedColorArray, cap_end := true) -> void:
	# dải băng có mép AA 1 px. Viết thẳng vào mảng đã cấp sẵn (không tạo mảng tạm mỗi đoạn) cho nhẹ code vẽ mỗi khung.
	var n := P.size()
	if n < 2:
		return
	const F := 1.0
	const M := 10
	var nv := (n - 1) * 8 + (1 + (M + 1) * 2 if cap_end else 0)
	var ni := (n - 1) * 18 + (M * 9 if cap_end else 0)
	var pts := PackedVector2Array()
	pts.resize(nv)
	var cols := PackedColorArray()
	cols.resize(nv)
	var idx := PackedInt32Array()
	idx.resize(ni)
	var nr := PackedVector2Array()
	nr.resize(n)
	for i in n:
		var d := P[mini(i + 1, n - 1)] - P[maxi(i - 1, 0)]
		d = d.normalized() if d.length_squared() > 0 else Vector2.RIGHT
		nr[i] = Vector2(-d.y, d.x)
	var v := 0
	var k := 0
	for i in n - 1:
		var c: Color = seg_col[i]
		var c0 := Color(c, 0)
		var b := v
		for j in 2:
			var jj := i + j
			var h: float = wid[jj] * .5
			var p: Vector2 = P[jj]
			var q: Vector2 = nr[jj]
			pts[v] = p + q * (h + F); cols[v] = c0
			pts[v + 1] = p + q * h; cols[v + 1] = c
			pts[v + 2] = p - q * h; cols[v + 2] = c
			pts[v + 3] = p - q * (h + F); cols[v + 3] = c0
			v += 4
		for q in 3:
			idx[k] = b + q; idx[k + 1] = b + q + 1; idx[k + 2] = b + 5 + q
			idx[k + 3] = b + q; idx[k + 4] = b + 5 + q; idx[k + 5] = b + 4 + q
			k += 6
	if cap_end:
		var c: Color = seg_col[n - 2]
		var c0 := Color(c, 0)
		var e: Vector2 = P[n - 1]
		var h: float = wid[n - 1] * .5
		var a0 := nr[n - 1].angle()
		var b := v
		pts[v] = e; cols[v] = c
		v += 1
		for i in M + 1:
			var a := a0 - PI * i / M
			var dv := Vector2(cos(a), sin(a))
			pts[v] = e + dv * h; cols[v] = c
			pts[v + 1] = e + dv * (h + F); cols[v + 1] = c0
			v += 2
		for i in M:
			var kk := b + 1 + i * 2
			idx[k] = b; idx[k + 1] = kk; idx[k + 2] = kk + 2
			idx[k + 3] = kk; idx[k + 4] = kk + 1; idx[k + 5] = kk + 3
			idx[k + 6] = kk; idx[k + 7] = kk + 3; idx[k + 8] = kk + 2
			k += 9
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)

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

# ------------------------------------------------------------ biểu tượng SVG của bản web (ICON), vẽ ra ảnh theo cỡ điểm ảnh thật
static var _svg := {}
static func icon(name: String, px: float) -> Texture2D:
	var p := maxi(8, int(ceil(px * K)))
	var key := name + "|" + str(p)
	if _svg.has(key):
		return _svg[key]
	if not ICON.has(name):
		return null
	var im := Image.new()
	var s: String = ICON[name]
	if im.load_svg_from_string(s, float(p) / 48.0) != OK:
		_svg[key] = null
		return null
	im.fix_alpha_edges()
	im.generate_mipmaps()
	var t := ImageTexture.create_from_image(im)
	_svg[key] = t
	return t

# vẽ biểu tượng (SVG hoặc hình vẽ tay ic-*) vừa khung r, giữ tỉ lệ
static func pic(ci: CanvasItem, k: String, r: Rect2, mod := Color.WHITE) -> void:
	var t: Texture2D = img("ic-" + k)
	if t == null:
		t = icon(k, maxf(r.size.x, r.size.y))
	if t == null:
		return
	fit(ci, t, r, mod)

static func fit(ci: CanvasItem, t: Texture2D, r: Rect2, mod := Color.WHITE) -> void:
	var ts := t.get_size()
	var s := minf(r.size.x / ts.x, r.size.y / ts.y)
	var sz := ts * s
	ci.draw_texture_rect(t, Rect2(r.get_center() - sz / 2, sz), false, mod)

static func svg(ci: CanvasItem, name: String, r: Rect2, mod := Color.WHITE) -> void:
	var t := icon(name, maxf(r.size.x, r.size.y))
	if t != null:
		ci.draw_texture_rect(t, r, false, mod)

const ICON := {
	"coin": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><circle cx="24" cy="25" r="19" fill="#b8801a"/><circle cx="24" cy="23" r="19" fill="#f4c040" stroke="#9a6a10" stroke-width="2.5"/><circle cx="24" cy="23" r="13.5" fill="none" stroke="#c8901a" stroke-width="2"/><rect x="19" y="18" width="10" height="10" rx="1.5" fill="#7a4a08"/><path d="M12 15a14 14 0 0 1 9-6" stroke="#fff6c0" stroke-width="3" fill="none" stroke-linecap="round"/></svg>',
	"basket": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M10 20h28l-3 20a4 4 0 0 1-4 3H17a4 4 0 0 1-4-3z" fill="#c89a52" stroke="#6a4a1c" stroke-width="2.4"/><path d="M12 26h24M13 32h22M14 38h20" stroke="#8a6228" stroke-width="2"/><path d="M18 21l-1 21M24 21v21M30 21l1 21" stroke="#a87a3a" stroke-width="1.6"/><path d="M14 20c1-9 19-9 20 0" fill="none" stroke="#6a4a1c" stroke-width="3"/><path d="M20 19c3-5 9-6 13-2-2 4-8 5-13 2z" fill="#7a9a5a" stroke="#3a5a24" stroke-width="1.6"/><circle cx="29" cy="17" r="1.2" fill="#222"/></svg>',
	"book": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M8 10c6-2 11-1 16 3 5-4 10-5 16-3v28c-6-2-11-1-16 3-5-4-10-5-16-3z" fill="#f6ead0" stroke="#6a4a1c" stroke-width="2.4" stroke-linejoin="round"/><path d="M24 13v28" stroke="#6a4a1c" stroke-width="2"/><path d="M11 22c3-3 7-3 10 0-3 3-7 3-10 0z" fill="#5a8a3a"/><path d="M27 28c3-3 7-3 10 0-3 3-7 3-10 0z" fill="#c8602a"/><circle cx="18.5" cy="21.6" r=".9" fill="#222"/><circle cx="34.5" cy="27.6" r=".9" fill="#222"/></svg>',
	"shop": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M6 30h36l-4 9H10z" fill="#9a6232" stroke="#5a3414" stroke-width="2.4" stroke-linejoin="round"/><path d="M10 30v-12M38 30v-12" stroke="#5a3414" stroke-width="2.4"/><path d="M6 18l4-8h28l4 8z" fill="#e04a2a" stroke="#7a1e10" stroke-width="2.2" stroke-linejoin="round"/><path d="M14 10l-2 8M22 10v8M30 10l2 8" stroke="#fff3d0" stroke-width="2.4"/><circle cx="17" cy="27" r="4" fill="#f0a030"/><circle cx="24" cy="26" r="4" fill="#6aa040"/><circle cx="31" cy="27" r="4" fill="#d8402a"/></svg>',
	"cog": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M24 6l4 5 6-2 1 6 6 2-2 6 5 4-5 4 2 6-6 2-1 6-6-2-4 5-4-5-6 2-1-6-6-2 2-6-5-4 5-4-2-6 6-2 1-6 6 2z" fill="#c89a52" stroke="#6a4a1c" stroke-width="2.4" stroke-linejoin="round"/><circle cx="24" cy="24" r="6" fill="#fbf4e0" stroke="#6a4a1c" stroke-width="2.4"/></svg>',
	"sun": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><g stroke="#e8902a" stroke-width="3" stroke-linecap="round"><path d="M24 4v6M24 38v6M4 24h6M38 24h6M10 10l4 4M34 34l4 4M38 10l-4 4M14 34l-4 4"/></g><circle cx="24" cy="24" r="10" fill="#ffc840" stroke="#e8902a" stroke-width="2.5"/></svg>',
	"moon": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M30 8a16 16 0 1 0 10 26A14 14 0 0 1 30 8z" fill="#f4e8b0" stroke="#8a7a40" stroke-width="2.5"/><circle cx="12" cy="12" r="1.5" fill="#f4e8b0"/><circle cx="40" cy="14" r="1.2" fill="#f4e8b0"/></svg>',
	"rain": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M13 30a8 8 0 0 1 1-16 11 11 0 0 1 21 3 7 7 0 0 1 0 13z" fill="#d8e2ee" stroke="#5a6a80" stroke-width="2.4"/><path d="M16 35l-2 6M24 35l-2 6M32 35l-2 6" stroke="#3a7ac8" stroke-width="2.6" stroke-linecap="round"/></svg>',
	"home": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M6 24L24 9l18 15" fill="none" stroke="#6a4a1c" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M11 22v18h26V22" fill="#e8c870" stroke="#6a4a1c" stroke-width="2.4" stroke-linejoin="round"/><path d="M4 25L24 7l20 18" fill="none" stroke="#9a6a2a" stroke-width="2" stroke-linecap="round"/><rect x="20" y="28" width="9" height="12" rx="1.5" fill="#9a5a2c" stroke="#6a4a1c" stroke-width="2"/></svg>',
	"how1": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M8 40 Q14 8 40 12" fill="none" stroke="#7a4a1e" stroke-width="3.5" stroke-linecap="round"/><path d="M40 12 Q44 26 38 34" fill="none" stroke="#9ab8c0" stroke-width="1.6" stroke-dasharray="3 3"/><ellipse cx="37" cy="38" rx="9" ry="3" fill="none" stroke="#3a8aa0" stroke-width="2.4"/><circle cx="37" cy="36" r="2.6" fill="#d8402a"/></svg>',
	"how2": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><ellipse cx="24" cy="38" rx="16" ry="4.5" fill="none" stroke="#3a8aa0" stroke-width="2.4"/><ellipse cx="24" cy="38" rx="8" ry="2.2" fill="none" stroke="#3a8aa0" stroke-width="2"/><path d="M24 6 Q30 16 24 38 Q18 16 24 6Z" fill="#efe2c0" stroke="#5a3a18" stroke-width="2"/><path d="M24 6 Q29 11 28 15 L20 15 Q19 11 24 6Z" fill="#d8402a"/></svg>',
	"how3": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M6 42 Q16 10 42 8" fill="none" stroke="#7a4a1e" stroke-width="3.5" stroke-linecap="round"/><path d="M42 8 L30 30" stroke="#9ab8c0" stroke-width="1.6"/><path d="M18 30 Q28 22 38 30 Q28 38 18 30Z M18 30 L12 25 L12 35Z" fill="#8aa868" stroke="#3a4a24" stroke-width="2" stroke-linejoin="round"/><circle cx="33" cy="29" r="1.6" fill="#222"/></svg>',
}

# ============================================================ KIỂU NÔNG TRẠI (11-23 Link: "làm giao diện lại cho đồng bộ với Nông trại")
# màu + hộp chép đúng css của Nông trại (godot/ui/snap: kho, hud, dock): nền bảng kem, khung tre, chữ Nunito nâu đậm
const F_BG := Color(251 / 255.0, 244 / 255.0, 228 / 255.0)      # nền bảng .pwin.ui2
const F_INK := Color(43 / 255.0, 42 / 255.0, 36 / 255.0)        # chữ trong bảng
const F_BROWN := Color(74 / 255.0, 52 / 255.0, 20 / 255.0)      # chữ trên nút/ô kem (hud, khnm)
const F_MUTED := Color(122 / 255.0, 90 / 255.0, 42 / 255.0)     # chữ phụ (khworth)
const F_MUTED2 := Color(138 / 255.0, 106 / 255.0, 58 / 255.0)   # chữ mờ (u2vem)
const F_TAB := Color(106 / 255.0, 74 / 255.0, 26 / 255.0)       # chữ tab chưa chọn
const F_CHIP := Color(90 / 255.0, 62 / 255.0, 20 / 255.0)       # chữ nút kem
const F_PRICE := Color(232 / 255.0, 134 / 255.0, 12 / 255.0)    # số xu (Đáng giá 60)
const F_RED := Color(214 / 255.0, 69 / 255.0, 59 / 255.0)       # chấm đỏ đếm số
const F_RED_RING := Color(255 / 255.0, 248 / 255.0, 228 / 255.0)
const F_GREEN := Color(63 / 255.0, 116 / 255.0, 41 / 255.0)     # viền nút xanh / ô đang chọn
const F_XP := Color(35 / 255.0, 160 / 255.0, 74 / 255.0)        # thanh kinh nghiệm

static func _c(r: int, g: int, b: int, a := 1.0) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a)

# hộp kiểu Nông trại: gradient dọc + các lớp viền trong (box-shadow inset) + vệt sáng mép trên + quầng tối mờ + bóng ngoài.
#   g: [[t, màu]...] trên xuống; ring: [[dày, màu]...] (inset 0 0 0 N, cái đầu nằm trên cùng); hi: [dày, màu] (inset 0 Npx 0);
#   glow: [dày, màu] (inset 0 0 8px 3px); drop: [[dx, dy, mờ, màu]...]; rad: số hoặc Vector4 (trên trái, trên phải, dưới phải, dưới trái)
static var FA := 1.0   # độ hiện chung của fbox (hộp đang mờ dần: chữ báo, lời nhắc)
static func _fa(c: Color) -> Color:
	return Color(c, c.a * FA)

static func fbox(ci: CanvasItem, r: Rect2, rad, g: Array, ring := [], hi := [], glow := [], drop := [], xf := Transform2D.IDENTITY) -> void:
	if FA < 1.0:
		g = g.map(func(e): return [e[0], _fa(e[1])])
		ring = ring.map(func(e): return [e[0], _fa(e[1])])
		if hi.size() == 2:
			hi = [hi[0], _fa(hi[1])]
		if glow.size() == 2:
			glow = [glow[0], _fa(glow[1])]
		drop = drop.map(func(e): return [e[0], e[1], e[2], _fa(e[3])])
	var q: Vector4 = rad if rad is Vector4 else Vector4(rad, rad, rad, rad)
	var m := minf(r.size.x, r.size.y) * .5
	q = Vector4(minf(q.x, m), minf(q.y, m), minf(q.z, m), minf(q.w, m))
	for d in drop:
		var b := _box_sb("fd%s|%s|%s|%s" % [str(d), q, K, r.size])
		if b.get_meta("ok", false) == false:
			b.set_meta("ok", true)
			_sb_rad(b, q)
			b.anti_aliasing = true
			if float(d[2]) <= 0.0:
				b.bg_color = d[3]
			else:
				b.bg_color = Color(0, 0, 0, 0)
				b.shadow_color = d[3]
				b.shadow_size = maxi(1, int(float(d[2]) * K * .5))
		_draw_sb(ci, b, Rect2(r.position + Vector2(d[0], d[1]), r.size), xf)
	# (Link 11-23 "nhoè lem ở các cạnh") vẽ ở toạ độ ĐIỂM ẢNH THẬT: đường viền mịn của Godot nhoè ra 1 đơn vị toạ độ,
	# vẽ theo css px thì nhoè K điểm ảnh (3 px trên điện thoại) -> thành quầng mờ quanh ô. Giờ nhoè đúng 1 điểm ảnh.
	var rk := Rect2(r.position * K, r.size * K)
	var pts := rr4_pts(rk, q * K, 6)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(stop_col(g, (p.y - rk.position.y) / maxf(1.0, rk.size.y)))
	ci.draw_set_transform_matrix(BASE * xf * Transform2D(0, Vector2(1.0 / K, 1.0 / K), 0, Vector2.ZERO))
	ci.draw_polygon(pts, cols)
	var cl := pts.duplicate()
	cl.append(pts[0])
	var cc := cols.duplicate()
	cc.append(cols[0])
	ci.draw_polyline_colors(cl, cc, 1.0, true)   # mép mịn 1 điểm ảnh (polygon không khử răng cưa)
	ci.draw_set_transform_matrix(BASE)
	if glow.size() == 2:
		var gc: Color = glow[1]
		for j in 5:   # quầng mờ dần vào trong: 5 lớp mỏng chồng nhau (không thành bậc)
			_ring(ci, r, q, float(glow[0]) * (1.0 - j * .19), Color(gc, gc.a * .28), xf)
	if hi.size() == 2:
		var b2 := _box_sb("fh%s|%s|%s|%s" % [hi, q, K, r.size])
		if b2.get_meta("ok", false) == false:
			b2.set_meta("ok", true)
			_sb_rad(b2, q)
			b2.draw_center = false
			b2.anti_aliasing = true
			b2.border_width_top = maxi(1, int(round(float(hi[0]) * K)))
			b2.border_color = hi[1]
		_draw_sb(ci, b2, r, xf)
	for i in range(ring.size() - 1, -1, -1):
		_ring(ci, r, q, float(ring[i][0]), ring[i][1], xf)

static func _ring(ci: CanvasItem, r: Rect2, q: Vector4, w: float, col: Color, xf: Transform2D) -> void:
	var b := _box_sb("fr%s|%s|%s|%s|%s" % [w, col, q, K, r.size])
	if b.get_meta("ok", false) == false:
		b.set_meta("ok", true)
		_sb_rad(b, q)
		b.draw_center = false
		b.anti_aliasing = true
		b.set_border_width_all(maxi(1, int(round(w * K))))
		b.border_color = col
	_draw_sb(ci, b, r, xf)

static func _sb_rad(b: StyleBoxFlat, q: Vector4) -> void:
	b.corner_radius_top_left = int(q.x * K)
	b.corner_radius_top_right = int(q.y * K)
	b.corner_radius_bottom_right = int(q.z * K)
	b.corner_radius_bottom_left = int(q.w * K)

static func rr4_pts(r: Rect2, q: Vector4, n := 6) -> PackedVector2Array:   # hình chữ nhật bo từng góc riêng
	var out := PackedVector2Array()
	var cs := [[Vector2(r.end.x - q.y, r.position.y + q.y), q.y, -PI / 2], [Vector2(r.end.x - q.z, r.end.y - q.z), q.z, 0.0], [Vector2(r.position.x + q.w, r.end.y - q.w), q.w, PI / 2], [Vector2(r.position.x + q.x, r.position.y + q.x), q.x, PI]]
	for c in cs:
		var rr: float = c[1]
		if rr <= 0.01:
			var p0: Vector2 = c[0]
			if out.size() == 0 or out[out.size() - 1].distance_squared_to(p0) > 0.0004:
				out.append(p0)
			continue
		for k in n + 1:
			var a: float = c[2] + PI / 2 * k / n
			var p: Vector2 = c[0] + Vector2(cos(a), sin(a)) * rr
			if out.size() and out[out.size() - 1].distance_squared_to(p) < 0.0004:
				continue
			out.append(p)
	if out.size() > 2 and out[0].distance_squared_to(out[out.size() - 1]) < 0.0004:
		out.remove_at(out.size() - 1)
	return out

# --- các kiểu hộp dùng chung (đúng số của css Nông trại)
const G_PILL := [[0.0, Color(1, 250 / 255.0, 240 / 255.0)], [.45, Color(248 / 255.0, 238 / 255.0, 214 / 255.0)], [1.0, Color(241 / 255.0, 226 / 255.0, 192 / 255.0)]]
static func pill(ci: CanvasItem, r: Rect2, rad := 12.0, down := false, xf := Transform2D.IDENTITY) -> void:   # .coins / .ibtn / nút dock của HUD
	var rr := Rect2(r.position + Vector2(0, 1.5 if down else 0.0), r.size)
	fbox(ci, rr, rad, G_PILL, [[.8, _c(156, 122, 54)], [2.0, _c(224, 202, 146)], [3.0, _c(179, 146, 80)], [3.6, _c(124, 95, 42)]],
		[4.6, Color(1, 1, 1, .7)], [], [] if down else [[0, 1, 2, Color(60 / 255.0, 40 / 255.0, 10 / 255.0, .18)]], xf)

static func card(ci: CanvasItem, r: Rect2, sel := false, rad := 14.0) -> void:   # ô .khb (thẻ hàng trong Kho)
	if sel:
		fbox(ci, r, rad, [[0.0, _c(246, 252, 238)], [1.0, _c(232, 244, 216)]], [[2.0, F_GREEN]], [], [], [[0, 2, 0, _c(63, 116, 41, .35)], [0, 3, 5, _c(30, 70, 20, .12)]])
	else:
		fbox(ci, r, rad, [[0.0, _c(255, 252, 244)], [1.0, _c(247, 236, 212)]], [[1.0, _c(150, 112, 48, .28)]], [2.0, Color(1, 1, 1, .85)], [], [[0, 2, 0, _c(170, 135, 70, .32)], [0, 3, 5, _c(90, 60, 20, .1)]])

# nút: "" = xanh lá (btn primary), "gold" = cam (u2sp), "alt" = kem (khchip), "red" = đỏ
static func fbtn_bg(ci: CanvasItem, r: Rect2, kind: String, down := false, disabled := false, rad := 10.0) -> void:
	var rr := Rect2(r.position + Vector2(0, 1.5 if down and not disabled else 0.0), r.size)
	var drop := [] if down else [[0, 1, 2, _c(30, 70, 20, .32)]]
	var g: Array
	var ring: Array
	var hi: Array
	var glow: Array
	match kind:
		"gold":
			g = [[0.0, _c(240, 171, 67)], [.5, _c(237, 160, 58)], [1.0, _c(233, 150, 51)]]
			ring = [[1.0, _c(130, 70, 5, .6)]]
			hi = [2.0, _c(255, 228, 170, .75)]
			glow = [5.0, _c(120, 60, 0, .18)]
			drop = [] if down else [[0, 1, 2, _c(60, 40, 15, .28)]]
		"alt":
			g = [[0.0, _c(241, 225, 186)], [.5, _c(245, 232, 200)], [1.0, _c(250, 241, 218)]]
			ring = [[1.0, _c(120, 82, 22, .5)]]
			hi = [2.0, Color(1, 1, 1, .75)]
			glow = [5.0, _c(120, 85, 25, .13)]
			drop = [] if down else [[0, 1, 2, _c(60, 40, 15, .28)]]
		"red":
			g = [[0.0, _c(226, 92, 70)], [1.0, _c(196, 60, 44)]]
			ring = [[1.0, _c(120, 30, 18, .6)]]
			hi = [2.0, _c(255, 200, 180, .55)]
			glow = [5.0, _c(90, 10, 0, .2)]
		_:
			g = [[0.0, _c(78, 155, 68)], [.5, _c(81, 159, 70)], [1.0, _c(88, 169, 77)]]
			ring = [[1.0, F_GREEN]]
			hi = [2.0, _c(150, 215, 130, .45)]
			glow = [5.0, _c(10, 55, 10, .2)]
	if disabled:
		for i in g.size():
			var c: Color = g[i][1]
			var v := c.get_luminance()
			g[i] = [g[i][0], Color(v, v, v).lerp(c, .25)]
		ring = [[1.0, Color(0, 0, 0, .25)]]
	fbox(ci, rr, rad, g, ring, hi, glow, drop)

static func bar_bg(ci: CanvasItem, r: Rect2, frac: float, fill := Color(1, 204 / 255.0, 51 / 255.0)) -> void:   # .kcbar
	var rad := r.size.y * .5
	fbox(ci, r, rad, [[0.0, _c(222, 205, 160)], [.4, _c(232, 217, 178)], [1.0, _c(232, 217, 178)]], [[1.0, _c(120, 82, 22, .22)]], [], [], [[0, 1, 0, Color(1, 1, 1, .75)]])
	var fw := r.size.x * clampf(frac, 0, 1)
	if fw > 1:
		var fr := Rect2(r.position, Vector2(maxf(fw, r.size.y), r.size.y))
		fbox(ci, fr, rad, [[0.0, fill.lerp(Color.WHITE, .22)], [.55, fill], [1.0, fill.darkened(.1)]], [[1.0, Color(0, 0, 0, .14)]])

static func badge(ci: CanvasItem, c: Vector2, s: String, fs := 11.0) -> void:   # chấm đỏ đếm số (em của evb)
	var w := maxf(fs * 1.45, tw(s, fs, 800) + 8)
	var h := fs * 1.45
	var r := Rect2(c - Vector2(w, h) / 2, Vector2(w, h))
	box(ci, Rect2(r.position + Vector2(0, 1), r.size).grow(1.5), Color(60 / 255.0, 20 / 255.0, 10 / 255.0, .3), h / 2 + 1.5)
	box(ci, r.grow(1.5), F_RED_RING, h / 2 + 1.5)
	box(ci, r, F_RED, h / 2)
	text(ci, s, c.x, c.y, fs, Color.WHITE, 1, 800)

# ảnh SVG của Nông trại (ui/img/cc/ui/*.svg) vẽ ra đúng cỡ điểm ảnh, giữ trong bộ nhớ
static var _fsvg := {}
static func usvg(name: String, w: float, h: float) -> Texture2D:
	var pw := maxi(2, int(ceil(w * K)))
	var ph := maxi(2, int(ceil(h * K)))
	var key := name + "|" + str(pw) + "x" + str(ph)
	if _fsvg.has(key):
		return _fsvg[key]
	var src := FileAccess.get_file_as_string(DIR + "ui/" + name + ".svg")
	var t: Texture2D = null
	if src != "":
		# cỡ gốc theo viewBox
		var vb := src.get_slice("viewBox=\"", 1).get_slice("\"", 0).split(" ")
		var vw := float(vb[2]) if vb.size() == 4 else 100.0
		var vh := float(vb[3]) if vb.size() == 4 else 100.0
		if not src.contains(" width=\""):
			src = src.replace("<svg ", "<svg width=\"%s\" height=\"%s\" " % [vw, vh])
		var im := Image.new()
		if im.load_svg_from_string(src, minf(pw / vw, ph / vh)) == OK:
			im.fix_alpha_edges()
			im.generate_mipmaps()
			t = ImageTexture.create_from_image(im)
	_fsvg[key] = t
	return t

# nền giấy của bảng Nông trại: kem + 14 nhành lá vẽ chì mờ (.pbody background, đúng cỡ + chỗ của css), bo góc; GHÉP SẴN một ảnh
# theo cỡ bảng (giống khung tre), vẽ một lệnh
const GIAY := [[150, 0, [0, -14], [0, 150]], [150, 0, [1, 14], [1, -40]], [120, 0, [1, 10], [0, 120]], [62, 108, [0, 6], [1, -160]],
	[62, 108, [1, -18], [.46, 0]], [22, 0, [.44, 0], [.52, 0]], [18, 0, [.74, 0], [1, -120]], [16, 0, [.22, 0], [0, 205]],
	[140, 0, [.32, 0], [.40, 0]], [92, 0, [.46, 0], [0, -18]], [44, 78, [0, 4], [0, -14]], [15, 0, [.30, 0], [0, 34]],
	[18, 0, [.62, 0], [.31, 0]], [110, 0, [.58, 0], [.58, 0]]]
static var _paper := {}
static var _giay := {}

static func _svg_src(path: String) -> Array:   # [chữ svg có width/height, rộng gốc, cao gốc]
	var src := FileAccess.get_file_as_string(path)
	var vb := src.get_slice("viewBox=\"", 1).get_slice("\"", 0).split(" ")
	var vw := float(vb[2]) if vb.size() == 4 else 100.0
	var vh := float(vb[3]) if vb.size() == 4 else 100.0
	if not src.contains(" width=\""):
		src = src.replace("<svg ", "<svg width=\"%s\" height=\"%s\" " % [vw, vh])
	return [src, vw, vh]

static func paper(w: float, h: float, rad: float) -> Texture2D:
	var k := clampf(ceilf(K), 2.0, 4.0)
	var W := maxi(2, int(round(w * k)))
	var H := maxi(2, int(round(h * k)))
	var key := "%dx%d|%s" % [W, H, rad]
	if _paper.has(key):
		return _paper[key]
	if _paper.size() > 12:
		_paper.clear()
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	out.fill(F_BG)
	for i in range(GIAY.size() - 1, -1, -1):   # lớp đầu nằm trên cùng
		var g: Array = GIAY[i]
		var gk := "%d|%s" % [i, k]
		var im: Image = _giay.get(gk)
		var sv := _svg_src(DIR + "ui/giay/giay_%d.svg" % i)
		var vw: float = sv[1]
		var vh: float = sv[2]
		var gw: float = g[0]
		var gh: float = g[1] if g[1] > 0 else gw * vh / vw
		if im == null:
			im = Image.new()
			if im.load_svg_from_string(sv[0], minf(gw / vw, gh / vh) * k) != OK:
				continue
			im.convert(Image.FORMAT_RGBA8)
			_giay[gk] = im
		var x: float = (w - gw) * g[2][0] + g[2][1] + (gw - im.get_width() / k) / 2
		var y: float = (h - gh) * g[3][0] + g[3][1] + (gh - im.get_height() / k) / 2
		out.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(int(round(x * k)), int(round(y * k))))
	# bo góc (mép mịn)
	var R := int(round(rad * k))
	for cy in [0, 1]:
		for cx in [0, 1]:
			for yy in R:
				for xx in R:
					var dx := R - xx - .5
					var dy := R - yy - .5
					var d := sqrt(dx * dx + dy * dy)
					var al := clampf(R - d + .5, 0.0, 1.0)
					if al >= 1.0:
						continue
					var px: int = xx if cx == 0 else W - 1 - xx
					var py: int = yy if cy == 0 else H - 1 - yy
					var c := out.get_pixel(px, py)
					c.a *= al
					out.set_pixel(px, py, c)
	var t := ImageTexture.create_from_image(out)
	_paper[key] = t
	return t
