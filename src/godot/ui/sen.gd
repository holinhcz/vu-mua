extends RefCounted
# (11-25) KHUNG SEN CHUNG (ảnh mẫu của Link "8458", cắt bằng tools/sen/cat_khung.py -> ui/img/sen + khung.json).
#   Lớp KHUNG (trên nội dung): đốt tre lặp 4 cạnh, 4 góc (hoa sen trên trái / dưới phải, nút đóng + dây tua trên phải),
#   chóp đỏ hoa sen vàng giữa cạnh trên và cạnh dưới. Mảnh nào cũng neo theo mép NGOÀI vòng tre (= khung hộp).
#   Lớp GIẤY (dưới nội dung): nền kem + hoa sen nét chìm, sóng hồng ở 4 góc trong.
# Ghép sẵn thành một ảnh theo đúng cỡ hộp, mảnh đặt ở điểm ảnh nguyên (như ui/tre.gd): không khe, không mờ.
# Hộp nhỏ (USE_W x USE_H) vẫn xài khung tre cũ: hoa to không chen vào được.
const Css = preload("res://ui/css.gd")
const D := "res://ui/img/sen/"
const USE_W := 220.0
const USE_H := 180.0
const S := 0.78     # cỡ khung so với ảnh mẫu (tre ảnh mẫu 9 css px -> 7 css px như khung tre cũ)

static var M := {}
static var _src := {}
static var _tex := {}

static func meta() -> Dictionary:
	if M.is_empty():
		M = JSON.parse_string(FileAccess.get_file_as_string(D + "khung.json"))
		for key in ["outer", "inner", "dong"]:
			M[key] = M[key].map(func(v): return float(v) * S)
		for grp in ["khung", "giay_m"]:
			for n in M[grp]:
				M[grp][n] = M[grp][n].map(func(v): return float(v) * S)
	return M

static func use(w: float, h: float) -> bool:
	return w >= USE_W and h >= USE_H

static func _px() -> float:
	return clampf(ceilf(Css.K), 2.0, 4.0)

static func _img(name: String, w: int, h: int) -> Image:
	var key := name + "|" + str(w) + "x" + str(h)
	if _src.has(key):
		return _src[key]
	var im := Image.new()
	im.load_webp_from_buffer(FileAccess.get_file_as_bytes(D + name + ".webp"))
	im.convert(Image.FORMAT_RGBA8)
	im.premultiply_alpha()
	im.resize(maxi(1, w), maxi(1, h), Image.INTERPOLATE_LANCZOS)
	Css._unpremul(im)
	_src[key] = im
	return im

static func _anchor(name: String, w: float, h: float) -> Vector2:   # góc neo của mảnh (css, so với góc trên trái hộp)
	match name:
		"k_tt": return Vector2(0, 0)
		"k_tp": return Vector2(w, 0)
		"k_dt": return Vector2(0, h)
		"k_dp": return Vector2(w, h)
		"k_dinh": return Vector2(w * 0.5, 0)
		"k_day": return Vector2(w * 0.5, h)
	return Vector2.ZERO

static func bounds(w: float, h: float) -> Rect2:   # khung tràn ra ngoài hộp bao nhiêu (css)
	var K: Dictionary = meta().khung
	var r := Rect2(0, 0, w, h)
	for n in K:
		if not String(n).begins_with("k_"):
			continue
		var q: Array = K[n]
		var a := _anchor(n, w, h)
		r = r.merge(Rect2(a.x + float(q[0]), a.y + float(q[1]), float(q[2]), float(q[3])))
	for n in ["e_tren", "e_duoi", "e_trai", "e_phai"]:
		var q: Array = K[n]
		if n == "e_tren" or n == "e_duoi":
			var y := (0.0 if n == "e_tren" else h) + float(q[1])
			r = r.merge(Rect2(0, y, w, float(q[3])))
		else:
			var x := (0.0 if n == "e_trai" else w) + float(q[0])
			r = r.merge(Rect2(x, 0, float(q[2]), h))
	return Rect2(floorf(r.position.x), floorf(r.position.y), ceilf(r.size.x) + 1.0, ceilf(r.size.y) + 1.0)

static func _put(out: Image, name: String, x: float, y: float, w: float, h: float, o: Vector2, k: float) -> void:
	var px := int(round((x - o.x) * k))
	var py := int(round((y - o.y) * k))
	var pw := int(round((x + w - o.x) * k)) - px
	var ph := int(round((y + h - o.y) * k)) - py
	var im := _img(name, pw, ph)
	out.blend_rect(im, Rect2i(0, 0, pw, ph), Vector2i(px, py))

static func frame(w: float, h: float) -> Array:   # [texture, rect css so với góc trên trái hộp]
	var k := _px()
	var B := bounds(w, h)
	var key := "f" + str(int(w * 10)) + "x" + str(int(h * 10)) + "@" + str(k)
	if not _tex.has(key):
		var K: Dictionary = meta().khung
		var out := Image.create(int(ceil(B.size.x * k)), int(ceil(B.size.y * k)), false, Image.FORMAT_RGBA8)
		var o := B.position
		for n in ["e_tren", "e_duoi"]:   # đốt tre: chia đều cạnh thành số đốt nguyên
			var q: Array = K[n]
			var cnt := maxi(1, int(round(w / float(q[2]))))
			var L := w / cnt
			for i in cnt:
				_put(out, n, i * L, (0.0 if n == "e_tren" else h) + float(q[1]), L + 0.4, float(q[3]), o, k)
		for n in ["e_trai", "e_phai"]:
			var q: Array = K[n]
			var cnt := maxi(1, int(round(h / float(q[3]))))
			var L := h / cnt
			for i in cnt:
				_put(out, n, (0.0 if n == "e_trai" else w) + float(q[0]), i * L, float(q[2]), L + 0.4, o, k)
		for n in ["k_dinh", "k_day", "k_dt", "k_tt", "k_tp", "k_dp"]:
			var q: Array = K[n]
			var a := _anchor(n, w, h)
			_put(out, n, a.x + float(q[0]), a.y + float(q[1]), float(q[2]), float(q[3]), o, k)
		out.fix_alpha_edges()
		out.generate_mipmaps()
		_tex[key] = ImageTexture.create_from_image(out)
	return [_tex[key], B]

static func close_rect(w: float) -> Rect2:   # chỗ nút đóng vẽ trong góc trên phải (css, so với góc trên trái hộp)
	var q: Array = meta().dong
	return Rect2(w + float(q[0]), float(q[1]), float(q[2]), float(q[3]))

static func paper_color() -> Color:
	var g: Array = meta().giay
	return Color8(int(g[0]), int(g[1]), int(g[2]))

static func paper(w: float, h: float) -> Texture2D:   # nền giấy (cả hộp): màu kem + hoa nét chìm, sóng hồng ở góc trong
	var k := _px()
	var key := "g" + str(int(w * 10)) + "x" + str(int(h * 10)) + "@" + str(k)
	if _tex.has(key):
		return _tex[key]
	var m := meta()
	var O: Array = m.outer
	var I: Array = m.inner
	var il := float(I[0]) - float(O[0])
	var it := float(I[1]) - float(O[1])
	var ir := float(O[2]) - float(I[2])
	var ib := float(O[3]) - float(I[3])
	var out := Image.create(int(ceil(w * k)), int(ceil(h * k)), false, Image.FORMAT_RGBA8)
	out.fill(paper_color())
	var G: Dictionary = m.giay_m
	var o := Vector2.ZERO
	for n in G:
		var q: Array = G[n]
		var a := Vector2.ZERO
		match String(n):
			"g_tt": a = Vector2(il, it)
			"g_tp": a = Vector2(w - ir, it)
			"g_dt": a = Vector2(il, h - ib)
			"g_dp": a = Vector2(w - ir, h - ib)
			"g_day": a = Vector2(w * 0.5, h - ib)
		_put(out, n, a.x + float(q[0]), a.y + float(q[1]), float(q[2]), float(q[3]), o, k)
	# bo 4 góc theo vòng tre (giấy không lòi ra ngoài góc cong)
	var rp := int(round(16.0 * k))
	var W := out.get_width()
	var H := out.get_height()
	for j in rp:
		for i in rp:
			var dx := float(rp - i) - 0.5
			var dy := float(rp - j) - 0.5
			var a2 := clampf(float(rp) - sqrt(dx * dx + dy * dy) + 0.5, 0.0, 1.0)
			if a2 < 1.0:
				for p2 in [Vector2i(i, j), Vector2i(W - 1 - i, j), Vector2i(i, H - 1 - j), Vector2i(W - 1 - i, H - 1 - j)]:
					var c := out.get_pixelv(p2)
					c.a *= a2
					out.set_pixelv(p2, c)
	out.generate_mipmaps()
	var t := ImageTexture.create_from_image(out)
	_tex[key] = t
	return t
