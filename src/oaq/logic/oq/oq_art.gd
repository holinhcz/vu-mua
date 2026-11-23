extends RefCounted
# Ô ĂN QUAN: hình dùng chung (dịch từ game.js + shell.html của bản web /mnt/project-files/o-an-quan/src): chữ Baloo 2,
# hộp gỗ / bảng con (đá đen) / giấy dó trong khung tre, bóng tròn / bóng sát đất (một tấm ghép chung),
# bóng đổ của hình theo mặt trời, chân dung vẽ phấn màu (SVG), biểu tượng nút.
# Hình nào giống hệt Cờ gánh (đất, gạch tàu, gà, dép, lu, chổi, tàu dừa) lấy chung ui/img/cg/; hình riêng ở ui/img/oq/.

const OWN := ["tau0", "tau1", "uiwood", "uislate", "uipaper", "peb/"]
const PEB_N := 40   # sỏi dân 9px (Link 11-22 "vẽ lại sỏi 4k 9px"): mỗi viên 1 file peb/p0..39, quan peb/q0, q1 (tools/oq/oq9.py)
static func path(name: String) -> String:
	return ("res://ui/img/oq/" if OWN.has(name) or name.begins_with("peb/") else "res://ui/img/cg/") + name + ".webp"

static var _font := {}
static var _base: FontFile = null
static var _img := {}
static var _sb := {}
static var _sil := {}
static var _svg := {}
static var atlas: ImageTexture = null    # [0,0,64,64] bóng mềm, [64,0,64,64] bóng sát
const R_SOFT := Rect2(0, 0, 64, 64)
const R_CONT := Rect2(64, 0, 64, 64)
const R_GLOW := Rect2(0, 64, 64, 64)    # tròn trắng mờ dần (tô màu lúc vẽ)

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
		_base.fallbacks = [load_nunito()]
	var v := FontVariation.new()
	v.base_font = _base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): w}
	_font[w] = v
	return v

static func load_nunito() -> Font:
	var f := FontFile.new()
	f.load_dynamic_font("res://ui/font/nunito_700.ttf")
	return f

static func tw(s: String, w: int, fs: float) -> float:
	return font(w).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(1, int(round(fs)))).x

# ------------------------------------------------------------ ảnh
static func img(name: String) -> ImageTexture:
	if _img.has(name):
		return _img[name]
	var im := Image.new()
	im.load_webp_from_buffer(FileAccess.get_file_as_bytes(path(name)))
	if im.detect_alpha() != Image.ALPHA_NONE:
		# chỗ trong suốt lấy màu mép hình: bản thu nhỏ (mipmap) không trộn ra viền đen quanh hình
		im.convert(Image.FORMAT_RGBA8)
		im.fix_alpha_edges()
	im.generate_mipmaps()
	var t := ImageTexture.create_from_image(im)
	_img[name] = t
	return t

static var _raw := {}
static func raw(name: String) -> Image:
	if _raw.has(name):
		return _raw[name]
	var im := Image.new()
	im.load_webp_from_buffer(FileAccess.get_file_as_bytes(path(name)))
	im.convert(Image.FORMAT_RGBA8)
	_raw[name] = im
	return im

# màu bóng: vẽ hình (đã làm mờ) nhân với màu này, ra gần như rgb(30,17,5) của bản web
const SHC := Color(0.118, 0.067, 0.02)

# makeShadowSprite(): ba tấm vẽ chung một ảnh để các quân vẽ liền một lượt
static func build_atlas() -> void:
	if atlas != null:
		return
	var im := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	_radial(im, 0, 0, 64, [[0.0, Color8(40, 24, 8, 158)], [0.45, Color8(40, 24, 8, 97)], [1.0, Color8(40, 24, 8, 0)]])
	_radial(im, 64, 0, 64, [[0.0, Color8(34, 20, 6, 204)], [0.78, Color8(34, 20, 6, 158)], [0.9, Color8(34, 20, 6, 56)], [1.0, Color8(34, 20, 6, 0)]])
	_radial(im, 0, 64, 64, [[0.0, Color(1, 1, 1, 1)], [0.07, Color(1, 1, 1, 1)], [1.0, Color(1, 1, 1, 0)]])
	im.fix_alpha_edges()
	if OS.has_environment("OQ_DUMP"):
		im.save_png(OS.get_environment("OQ_DUMP") + ".atlas.png")
	atlas = ImageTexture.create_from_image(im)

static func _stops(st: Array, t: float) -> Color:
	for i in range(1, st.size()):
		if t <= st[i][0]:
			var a: Array = st[i - 1]
			var b: Array = st[i]
			return (a[1] as Color).lerp(b[1], (t - a[0]) / maxf(1e-6, b[0] - a[0]))
	return st[st.size() - 1][1]

static func _radial(im: Image, ox: int, oy: int, n: int, st: Array) -> void:
	var h := n * 0.5
	for y in n:
		for x in n:
			var t := minf(1.0, Vector2(x + 0.5 - h, y + 0.5 - h).length() / (h - 0.5))
			im.set_pixel(ox + x, oy + y, _stops(st, t))

static func _blur(im: Image, blur: float) -> void:
	# mờ kiểu hộp lặp (thu nhỏ rồi phóng lại bằng Lanczos/bilinear, chạy trong C++)
	if blur < 0.8:
		return
	var w := im.get_width()
	var h := im.get_height()
	var f := clampf(1.0 / (blur * 0.7), 0.04, 1.0)
	var sw := maxi(2, int(w * f))
	var sh := maxi(2, int(h * f))
	im.resize(sw, sh, Image.INTERPOLATE_BILINEAR)
	im.resize(w, h, Image.INTERPOLATE_CUBIC)

static func _padded(src: Image, pad: int) -> Image:
	var m := Image.create(src.get_width() + pad * 2, src.get_height() + pad * 2, false, Image.FORMAT_RGBA8)
	m.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(pad, pad))
	return m

# cell: vùng trong ảnh (atlas con gà); trả {tex, pad} (bóng sát) hoặc {tex, ox, oy} (bóng đổ, dx dy theo điểm ảnh hình)
static func contact(name: String, cell: Rect2i, blur: int) -> Dictionary:
	var key := "c" + name + str(cell) + ":" + str(blur)
	if _sil.has(key):
		return _sil[key]
	var src := raw(name).get_region(cell)
	var pad := int(ceil(blur * 1.6 + 2))
	var m := _padded(src, pad)
	_blur(m, blur)
	m.generate_mipmaps()   # Link 11-23 "bóng từng đốm đen": thiếu mipmap thì thu nhỏ ra lấm tấm
	var r := {"tex": ImageTexture.create_from_image(m), "pad": pad}
	_sil[key] = r
	return r

static func cast(name: String, cell: Rect2i, blur: int, dx: int, dy: int) -> Dictionary:
	var key := "s" + name + str(cell) + ":" + str(blur) + ":" + str(dx) + ":" + str(dy)
	if _sil.has(key):
		return _sil[key]
	var src := raw(name).get_region(cell)
	var pad := int(ceil(blur * 1.6 + 2))
	var ex := absi(dx)
	var ey := absi(dy)
	var w := src.get_width()
	var h := src.get_height()
	var m0 := src
	var acc := Image.create(w + pad * 2 + ex, h + pad * 2 + ey, false, Image.FORMAT_RGBA8)
	acc.fill(Color8(30, 17, 5, 0))
	var x0 := pad + (ex if dx < 0 else 0)
	var y0 := pad + (ey if dy < 0 else 0)
	var n := mini(28, maxi(1, int(ceil(Vector2(dx, dy).length() / maxf(1.5, blur * 0.4)))))
	for k in n + 1:
		var t := float(k) / n
		acc.blend_rect(m0, Rect2i(0, 0, w, h), Vector2i(x0 + int(round(dx * t)), y0 + int(round(dy * t))))
	_blur(acc, blur)
	acc.generate_mipmaps()
	var r := {"tex": ImageTexture.create_from_image(acc), "ox": x0, "oy": y0}
	_sil[key] = r
	if _sil.size() > 600:
		_sil.clear()
	return r

const SUN := Vector2(0.64, 0.77)
# hình trên đất có bóng sát và bóng đổ (onGround). ox oy: góc của hình so với điểm đặt (mặc định giữa)
static func on_ground(ci: CanvasItem, K: float, name: String, cell: Rect2i, at: Vector2, w: float, h: float, rot: float, ht: float, flip := false, ox = null, oy = null, alpha := 1.0, shk := 1.0) -> void:
	var tex := img(name)
	if cell.size == Vector2i.ZERO:
		cell = Rect2i(0, 0, tex.get_width(), tex.get_height())
	var sw := float(cell.size.x)
	var shh := float(cell.size.y)
	var kx := w / sw
	var ky := h / shh
	var oxf: float = -w / 2 if ox == null else ox
	var oyf: float = -h / 2 if oy == null else oy
	var base := Transform2D(rot, Vector2(-1 if flip else 1, 1), 0.0, at)
	var S := Transform2D(0.0, Vector2(K, K), 0.0, Vector2.ZERO)
	# bóng sát đất: tối, gọn, ngay chỗ chạm đất
	if shk > 0.0:
		var cs := contact(name, cell, maxi(1, roundi(sw * 0.014)))
		var cp: int = cs.pad
		var co := ht * 0.05 + maxf(w, h) * 0.006
		ci.draw_set_transform_matrix(S * Transform2D(0.0, SUN * co) * base)
		ci.draw_texture_rect(cs.tex, Rect2(oxf - cp * kx, oyf - cp * ky, (sw + cp * 2) * kx, (shh + cp * 2) * ky), false, Color(SHC, 0.42 * alpha * shk))
	if shk > 0.0 and ht > maxf(w, h) * 0.04:
		var r := -rot
		var lx := (SUN.x * cos(r) - SUN.y * sin(r)) * (-1.0 if flip else 1.0)
		var ly := SUN.x * sin(r) + SUN.y * cos(r)
		var dx := roundi(lx * ht / kx)
		var dy := roundi(ly * ht / ky)
		var c := cast(name, cell, maxi(1, roundi(sw * 0.03)), dx, dy)
		var ct: ImageTexture = c.tex
		ci.draw_set_transform_matrix(S * base)
		ci.draw_texture_rect(ct, Rect2(oxf - c.ox * kx, oyf - c.oy * ky, ct.get_width() * kx, ct.get_height() * ky), false, Color(SHC, 0.27 * alpha * shk))
	ci.draw_set_transform_matrix(S * base)
	ci.draw_texture_rect_region(tex, Rect2(oxf, oyf, w, h), Rect2(cell), Color(1, 1, 1, alpha))
	ci.draw_set_transform_matrix(S)

# ------------------------------------------------------------ hộp (thẻ giấy, nút)
# bg: màu nền; rad: bo góc; bev: [cao, màu] gờ dưới (box-shadow inset 0 -N 0); sh: [[ox, oy, blur, màu]]; ring: [rộng, màu] viền ngoài
static func box(ci: CanvasItem, r: Rect2, bg: Color, rad: float, K: float, bev := [], sh := [], ring := []) -> void:
	rad = minf(rad, minf(r.size.x, r.size.y) / K * 0.5)
	for s in sh:
		var b: StyleBoxFlat = _sbox("sh" + str(s) + str(rad) + str(K))
		if b.shadow_size == 0:
			b.bg_color = Color(0, 0, 0, 0)
			b.draw_center = true
			b.set_corner_radius_all(int(rad * K))
			b.shadow_color = s[3]
			b.shadow_size = maxi(1, int(s[2] * K * 0.5))
			b.shadow_offset = Vector2(s[0], s[1]) * K
			b.anti_aliasing = true
		ci.draw_style_box(b, r)
	for rg in ring:
		var g: StyleBoxFlat = _sbox("rg" + str(rg) + str(rad) + str(K))
		g.bg_color = rg[1]
		g.set_corner_radius_all(int((rad + rg[0]) * K))
		g.anti_aliasing = true
		ci.draw_style_box(g, r.grow(rg[0] * K))
	var m: StyleBoxFlat = _sbox("bg" + str(bg) + str(rad) + str(K) + str(bev))
	m.bg_color = bg
	m.set_corner_radius_all(int(rad * K))
	m.anti_aliasing = true
	if bev.size():
		m.border_width_bottom = int(round(bev[0] * K))
		m.border_color = bev[1]
		m.border_blend = false
	ci.draw_style_box(m, r)

static func _sbox(k: String) -> StyleBoxFlat:
	if not _sb.has(k):
		_sb[k] = StyleBoxFlat.new()
		if _sb.size() > 400:
			_sb.clear()
			_sb[k] = StyleBoxFlat.new()
	return _sb[k]

static func svg(s: String, px: int) -> ImageTexture:
	var key := str(s.hash()) + ":" + str(px)
	if _svg.has(key):
		return _svg[key]
	var im := Image.new()
	var vb := 64.0
	var i := s.find("viewBox=\"")
	if i >= 0:
		var v := s.substr(i + 9, s.find("\"", i + 9) - i - 9).split(" ", false)
		if v.size() == 4:
			vb = maxf(float(v[2]), float(v[3]))
	if im.load_svg_from_string(s, px / vb) != OK:
		return null
	im.fix_alpha_edges()
	im.generate_mipmaps()
	var t := ImageTexture.create_from_image(im)
	_svg[key] = t
	return t

# ------------------------------------------------------------ chân dung vẽ phấn màu (avatarSVG của web Ô ăn quan)
# vẽ bằng phấn màu như con nít vẽ trên bảng con: nét viền phấn sáng, không có khung ảnh (bảng đen lộ ra phía sau).
# Bản web còn làm nét run run bằng feTurbulence; Godot không đọc bộ lọc SVG nên bỏ phần đó.
static func avatar(k: String) -> String:
	var skin: String = {"me": "#f3cba8", "ut": "#f6d0ae", "ti": "#e8b48c", "hai": "#f1c49e", "sau": "#e2b08a", "p2": "#f2c8a2"}.get(k, "#f3cba8")
	var shirt: String = {"me": "#f2efe4", "ut": "#f19bb0", "ti": "#7fb2ea", "hai": "#b48ad6", "sau": "#c99a6a", "p2": "#f2bd5c"}.get(k, "#f2efe4")
	var W := "#f6f1e4"
	var HAIR := "#4a3a32"
	var HL := "#cdbfa8"
	var INK := "#2a1d16"
	var st := func(c: String, w: float = 1.5) -> String: return 'stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"' % [c, str(w)]
	var eyes := func(y: float, closed: bool = false) -> String:
		if closed:
			return '<path d="M24.5 %sq2.5-2.6 5 0M34.5 %sq2.5-2.6 5 0" %s fill="none"/>' % [str(y), str(y), st.call(INK, 1.9)]
		return '<ellipse cx="27" cy="%s" rx="2" ry="2.5" fill="%s"/><ellipse cx="37" cy="%s" rx="2" ry="2.5" fill="%s"/><circle cx="27.7" cy="%s" r=".75" fill="%s"/><circle cx="37.7" cy="%s" r=".75" fill="%s"/>' % [str(y), INK, str(y), INK, str(y - 0.9), W, str(y - 0.9), W]
	var cheeks := '<ellipse cx="22.5" cy="40" rx="3" ry="1.8" fill="#f2849a" opacity=".55"/><ellipse cx="41.5" cy="40" rx="3" ry="1.8" fill="#f2849a" opacity=".55"/>'
	var mouth := func(d: String) -> String: return '<path d="%s" %s fill="none"/>' % [d, st.call("#b3423a", 1.9)]
	var hairS := func(d: String, strands: String = "") -> String:
		return '<path d="%s" fill="%s" %s/>' % [d, HAIR, st.call(HL, 1.3)] + ('<path d="%s" %s fill="none" opacity=".7"/>' % [strands, st.call(HL, 0.8)] if strands != "" else "")
	var back := ""
	var hair := ""
	var extra := ""
	var face := ""
	if k == "me":
		extra = '<path d="M5 28 32 8l27 20q-27 6-54 0z" fill="#efe0ae" %s/><path d="M12 24.5q20 3 40 0M18 19.5q14 2 28 0M24 14.6q8 1 16 0" %s fill="none"/><path d="M5 28q27 6 54 0" %s fill="none"/>' % [st.call(W, 1.5), st.call("#c8ad6c", 0.9), st.call("#c8ad6c", 1.4)]
		face = eyes.call(35) + cheeks + mouth.call("M27.5 43q4.5 3.6 9 0")
	elif k == "ut":
		back = '<circle cx="13.5" cy="35" r="5" fill="%s" %s/><circle cx="50.5" cy="35" r="5" fill="%s" %s/>' % [HAIR, st.call(HL, 1.2), HAIR, st.call(HL, 1.2)]
		hair = hairS.call("M17 34q-1-17 15-17t15 17q-2-8-8-10-6 5-15 4-5 1-7 6z", "M24 22q4 2 8 2M33 21q4 1 7 4")
		extra = '<circle cx="16.5" cy="29.5" r="2.5" fill="#ff5d73" %s/><circle cx="47.5" cy="29.5" r="2.5" fill="#ff5d73" %s/>' % [st.call(W, 0.8), st.call(W, 0.8)]
		face = eyes.call(35.5) + cheeks + mouth.call("M29 43.5q3 2.6 6 0")
	elif k == "ti":
		hair = hairS.call("M18 31q-1-14 14-14t14 14l-3-5-2 3-3-5-2 4-4-5-2 5-3-4-2 4-3-3z")
		face = eyes.call(34.5) + cheeks + '<path d="M26 41.5q6 6 12 0z" fill="#a8362f" %s/><path d="M29.4 41.6h5.2" %s/>' % [st.call("#e9a09a", 0.9), st.call(W, 1.6)]
	elif k == "hai":
		hair = '<circle cx="32" cy="15.5" r="6" fill="%s" %s/>' % [HAIR, st.call(HL, 1.2)] + hairS.call("M17 36q-2-19 15-19t15 19q-3-10-15-11-12 1-15 11z", "M22 24q5-3 10-2M36 22q5 1 8 6")
		extra = '<path d="M26 50.5l6 7 6-7" %s fill="none"/><circle cx="32" cy="60" r="1.3" fill="%s"/><circle cx="32" cy="63" r="1.3" fill="%s"/>' % [st.call("#e7d6f2", 1.3), W, W]
		face = eyes.call(35.5, true) + cheeks + mouth.call("M28.5 43.5q3.5 2.6 7 0")
	elif k == "sau":
		hair = '<path d="M17.5 34q0-6 3-8.5M46.5 34q0-6-3-8.5" %s/>' % st.call(W, 4.6)
		# khăn rằn: ô đen trắng vẽ bằng gạch phấn
		extra = ('<path d="M15 55q17 8 34 0l3 6.5q-20 9-40 0z" fill="#3b3a36" %s/><path d="M17 58.5q15 6 30 0" %s stroke-dasharray="2 2.4" fill="none"/><path d="M15 61.5q17 6.5 34 0" %s stroke-dasharray="2 2.4" stroke-dashoffset="2.2" fill="none"/>' % [st.call(W, 1.3), st.call(W, 1.6), st.call(W, 1.6)]) + \
			('<path d="M24 31q4-2 7 0M33 31q4-2 7 0" %s fill="none"/><path d="M25 41q7-4 14 0q-3 3-7 1.5q-4 1.5-7-1.5z" fill="%s"/><path d="M29 45q3 8 6 0z" fill="%s"/><path d="M22.5 25.5q9.5-3 19 0M24 27.5q8-2 16 0" %s fill="none"/>' % [st.call(W, 2.4), W, W, st.call("#a06b4a", 0.9)])
		face = eyes.call(35.5, true) + '<ellipse cx="22.5" cy="40" rx="3" ry="1.8" fill="#f2849a" opacity=".4"/><ellipse cx="41.5" cy="40" rx="3" ry="1.8" fill="#f2849a" opacity=".4"/>'
	else:
		hair = hairS.call("M17 36q-2-19 15-19t15 19q-1-9-6-11l-9 4-9-4q-5 2-6 11z")
		extra = '<path d="M18.5 25.5q13.5-8 27 0" %s fill="none"/>' % st.call("#7fd38f", 3.2)
		face = eyes.call(35.5) + cheeks + mouth.call("M28.5 43.5q3.5 3 7 0")
	# viewBox 6 9 52 52 của web, chừa thêm lề để nét ra ngoài (overflow visible) không bị cắt
	return '<svg viewBox="2 5 60 60" xmlns="http://www.w3.org/2000/svg"><g>' + back + \
		'<path d="M9 64q2-14.5 23-14.5t23 14.5" fill="%s" fill-opacity=".9" %s/>' % [shirt, st.call(W, 1.5)] + \
		'<path d="M14 61q4-6 9-8M50 61q-4-6-9-8" %s fill="none" opacity=".6"/>' % st.call(W, 0.9) + \
		'<path d="M27 50h10v4q-5 3-10 0z" fill="%s"/>' % skin + \
		'<ellipse cx="17.5" cy="37" rx="2.6" ry="3.4" fill="%s" %s/><ellipse cx="46.5" cy="37" rx="2.6" ry="3.4" fill="%s" %s/>' % [skin, st.call(W, 1.1), skin, st.call(W, 1.1)] + \
		'<ellipse cx="32" cy="36" rx="14" ry="15" fill="%s" %s/>' % [skin, st.call(W, 1.6)] + \
		'<path d="M38 24q5 3 6.5 9" %s fill="none" opacity=".55"/>' % st.call("#fff6e8", 1.6) + \
		'<path d="M24 30.5q3-1.6 6 0M34 30.5q3-1.6 6 0" %s fill="none"/>' % st.call("#5a3a26", 1.3) + \
		'<path d="M32 37q-1.4 2.6.4 3.2" %s fill="none"/>' % st.call("#a05a3a", 1.1) + \
		hair + face + extra + '</g></svg>'
# chân dung chiếm khung 6 9 52 52 của web; ảnh trên vẽ khung 2 5 60 60 nên to hơn 60/52
const AV_PAD := 60.0 / 52.0

# ------------------------------------------------------------ da giao diện: gỗ, bảng con, giấy dó, khung tre
# hình lặp (background: url() 0 0/<tile>px) phủ một hình chữ nhật bo góc. r, rad: điểm ảnh thật; tile: cỡ một hình (điểm ảnh)
static func tex_box(ci: CanvasItem, r: Rect2, name: String, tile: float, rad: float, mod := Color.WHITE, org := Vector2.ZERO) -> void:
	var t := img(name)
	var pts := rrect_pts(r, rad)
	var uvs := PackedVector2Array()
	var sx := tile
	var sy := tile * t.get_height() / t.get_width()
	for p in pts:
		uvs.append((p - org) / Vector2(sx, sy))
	ci.draw_colored_polygon(pts, mod, uvs, t)

static func rrect_pts(r: Rect2, rad: float, n := 8) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var out := PackedVector2Array()
	if rad <= 0.01:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var cs := [[r.end.x - rad, r.position.y + rad, -PI / 2], [r.end.x - rad, r.end.y - rad, 0.0], [r.position.x + rad, r.end.y - rad, PI / 2], [r.position.x + rad, r.position.y + rad, PI]]
	for c in cs:
		for k in n + 1:
			var a: float = c[2] + PI / 2 * k / n
			out.append(Vector2(c[0] + cos(a) * rad, c[1] + sin(a) * rad))
	return out

const BAMBOO := "<svg xmlns='http://www.w3.org/2000/svg' width='120' height='120' viewBox='0 0 120 120'><defs><linearGradient id='h' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='#ecd590'/><stop offset='.42' stop-color='#cfa65a'/><stop offset='1' stop-color='#8a6226'/></linearGradient><linearGradient id='v' x1='0' y1='0' x2='1' y2='0'><stop offset='0' stop-color='#ecd590'/><stop offset='.42' stop-color='#cfa65a'/><stop offset='1' stop-color='#8a6226'/></linearGradient></defs><rect x='0' y='6' width='120' height='22' rx='11' fill='url(#h)'/><rect x='0' y='92' width='120' height='22' rx='11' fill='url(#h)'/><rect x='6' y='0' width='22' height='120' rx='11' fill='url(#v)'/><rect x='92' y='0' width='22' height='120' rx='11' fill='url(#v)'/><g fill='#6e4a1c' opacity='.75'><rect x='58' y='6' width='3' height='22'/><rect x='58' y='92' width='3' height='22'/><rect x='6' y='58' width='22' height='3'/><rect x='92' y='58' width='22' height='3'/></g><g fill='#fff3c8' opacity='.6'><rect x='61' y='8' width='1.4' height='18'/><rect x='61' y='94' width='1.4' height='18'/><rect x='8' y='61' width='18' height='1.4'/><rect x='94' y='61' width='18' height='1.4'/></g><g stroke='#4a2c10' stroke-width='3' stroke-linecap='round' fill='none'><path d='M7 10l20 14M7 24l20-14M10 7l14 20M24 7l-14 20'/><path d='M93 10l20 14M93 24l20-14M96 7l14 20M110 7l-14 20'/><path d='M7 96l20 14M7 110l20-14M10 93l14 20M24 93l-14 20'/><path d='M93 96l20 14M93 110l20-14M96 93l14 20M110 93l-14 20'/></g></svg>"
static var _bam := {}
# khung tre (border: 15px; border-image: bamboo 30 round): bw = bề dày khung, điểm ảnh thật
static func bamboo(ci: CanvasItem, r: Rect2, bw: float) -> void:
	var key := roundi(bw * 100)
	var sb: StyleBoxTexture = _bam.get(key)
	if sb == null:
		var im := Image.new()
		im.load_svg_from_string(BAMBOO, bw / 30.0)
		var t := ImageTexture.create_from_image(im)
		sb = StyleBoxTexture.new()
		sb.texture = t
		var m := float(im.get_width()) / 4.0
		sb.texture_margin_left = m
		sb.texture_margin_right = m
		sb.texture_margin_top = m
		sb.texture_margin_bottom = m
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.draw_center = false
		_bam[key] = sb
	ci.draw_style_box(sb, r)


# biểu tượng nút (svg 24, nét currentColor)
const ICO := {
	"home": '<path d="M4 11.5 12 5l8 6.5"/><path d="M6.5 10v9h11v-9"/><path d="M10.5 19v-5h3v5"/>',
	"menu": '<path d="M4 7h16M4 12h16M4 17h16"/>',
	"undo": '<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>',
	"rules": '<circle cx="12" cy="12" r="9"/><path d="M9.6 9.3a2.5 2.5 0 1 1 3.4 2.3c-.7.3-1 .8-1 1.5v.6"/><path d="M12 17h.01"/>',
	"set": '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2.2"/><circle cx="10" cy="17" r="2.2"/>',
	"snd": '<path d="M4 10v4h4l5 4V6L8 10H4z"/><path d="M16.5 9a4 4 0 0 1 0 6"/><path d="M19 6.5a7.5 7.5 0 0 1 0 11"/>',
	"mute": '<path d="M4 10v4h4l5 4V6L8 10H4z"/><path d="M17 10l4 4M21 10l-4 4"/>',
	"x": '<path d="M6 6l12 12M18 6 6 18"/>',
}
static func icon(k: String, col: String, px: int) -> ImageTexture:
	var s := '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="%s" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [col, ICO[k]]
	return svg(s, px)

static func ff_icon(col: String, px: int) -> ImageTexture:
	return svg('<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="%s" d="M4 6l7 6-7 6zM12 6l7 6-7 6z"/></svg>' % col, px)

# bóng cánh tay + bàn tay cầm quân (armShadow): vẽ một lần, mờ 5px
static var arm: ImageTexture = null
static func build_arm() -> void:
	if arm != null:
		return
	var q := func(p0: Vector2, c: Vector2, p1: Vector2) -> PackedVector2Array:
		var o := PackedVector2Array()
		for k in range(1, 9):
			var t := k / 8.0
			o.append(p0 * (1 - t) * (1 - t) + c * 2.0 * (1 - t) * t + p1 * t * t)
		return o
	var P := PackedVector2Array([Vector2(0, 14), Vector2(178, 22)])
	# cẳng tay thon tới cổ tay rồi nắm tay có bốn đốt
	P.append_array(q.call(Vector2(178, 22), Vector2(190, 14), Vector2(214, 12)))
	P.append_array(q.call(Vector2(214, 12), Vector2(244, 14), Vector2(246, 32)))
	P.append_array(q.call(Vector2(246, 32), Vector2(244, 52), Vector2(214, 52)))
	P.append_array(q.call(Vector2(214, 52), Vector2(190, 50), Vector2(178, 42)))
	P.append(Vector2(0, 52))
	var im := Image.create(256, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 256:
			var pp := Vector2(x + 0.5, y + 0.5)
			var knuck := false
			for k in 4:
				if pp.distance_to(Vector2(240, 18 + k * 9.5)) <= 6.0:
					knuck = true
			if knuck or Geometry2D.is_point_in_polygon(pp, P):
				im.set_pixel(x, y, Color8(30, 17, 5, 255))
			else:
				im.set_pixel(x, y, Color8(30, 17, 5, 0))
	_blur(im, 5)
	arm = ImageTexture.create_from_image(im)
