extends RefCounted
# CÂU CÁ BỜ KÊNH: hình (vẽ sẵn bằng Python ở bản web, ui/img/cc/*.webp, nguyên bản không nén mất nét), chữ Baloo 2,
# hộp bo góc, biểu tượng SVG của web (vẽ ra ảnh đúng cỡ điểm ảnh). Mọi thứ đo bằng css px; gốc game phóng to K lần.

const DIR := "res://ui/img/cc/"
const INK := Color("#3e2810")
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
const SMALL := Color("#7a5a30")
const SMALL2 := Color("#8a6a40")
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
	"boat": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M4 28h40l-6 10H10z" fill="#9a6232" stroke="#4a2a10" stroke-width="2.2" stroke-linejoin="round"/><circle cx="16" cy="24" r="4" fill="#f0a030"/><circle cx="24" cy="23" r="4" fill="#d8402a"/><path d="M30 26l6-14 6 14z" fill="#f4dfa0" stroke="#8a6a30" stroke-width="2"/></svg>',
	"home": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M6 24L24 9l18 15" fill="none" stroke="#6a4a1c" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M11 22v18h26V22" fill="#e8c870" stroke="#6a4a1c" stroke-width="2.4" stroke-linejoin="round"/><path d="M4 25L24 7l20 18" fill="none" stroke="#9a6a2a" stroke-width="2" stroke-linecap="round"/><rect x="20" y="28" width="9" height="12" rx="1.5" fill="#9a5a2c" stroke="#6a4a1c" stroke-width="2"/></svg>',
	"how1": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M8 40 Q14 8 40 12" fill="none" stroke="#7a4a1e" stroke-width="3.5" stroke-linecap="round"/><path d="M40 12 Q44 26 38 34" fill="none" stroke="#9ab8c0" stroke-width="1.6" stroke-dasharray="3 3"/><ellipse cx="37" cy="38" rx="9" ry="3" fill="none" stroke="#3a8aa0" stroke-width="2.4"/><circle cx="37" cy="36" r="2.6" fill="#d8402a"/></svg>',
	"how2": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><ellipse cx="24" cy="38" rx="16" ry="4.5" fill="none" stroke="#3a8aa0" stroke-width="2.4"/><ellipse cx="24" cy="38" rx="8" ry="2.2" fill="none" stroke="#3a8aa0" stroke-width="2"/><path d="M24 6 Q30 16 24 38 Q18 16 24 6Z" fill="#efe2c0" stroke="#5a3a18" stroke-width="2"/><path d="M24 6 Q29 11 28 15 L20 15 Q19 11 24 6Z" fill="#d8402a"/></svg>',
	"how3": '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path d="M6 42 Q16 10 42 8" fill="none" stroke="#7a4a1e" stroke-width="3.5" stroke-linecap="round"/><path d="M42 8 L30 30" stroke="#9ab8c0" stroke-width="1.6"/><path d="M18 30 Q28 22 38 30 Q28 38 18 30Z M18 30 L12 25 L12 35Z" fill="#8aa868" stroke="#3a4a24" stroke-width="2" stroke-linejoin="round"/><circle cx="33" cy="29" r="1.6" fill="#222"/></svg>',
}
