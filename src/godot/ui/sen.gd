extends RefCounted
# (11-26) KHUNG SEN CHUNG từ bộ 10 ảnh riêng (art/sen/bo10, ghép sẵn bằng tools/sen/lam_khung.py -> ui/img/sen + khung.json).
#   Lớp KHUNG (trên nội dung): ống tre 4 cạnh (ống trơn kéo dài + mắt tre cách đều), 4 góc cong (một ảnh góc lật ra 4),
#   chóp đỏ hoa sen giữa cạnh trên / dưới, hoa sen góc trên trái / dưới phải, nút đóng đỏ + dây tua góc trên phải.
#   Lớp GIẤY (dưới nội dung): nền kem + sóng hồng hai góc đáy.
# Mảnh nào cũng neo theo mép ngoài vòng tre (= khung hộp). Ghép sẵn một ảnh đúng cỡ hộp, điểm ảnh nguyên: không khe, không mờ.
# Hộp nhỏ hơn USE_W x USE_H vẫn khung tre cũ (ui/tre.gd).
const Css = preload("res://ui/css.gd")
const D := "res://ui/img/sen/"
const USE_W := 220.0
const USE_H := 200.0
const MAT := 40.0     # mắt tre cách nhau ~ (css px)
const DAY := 30.0    # ĐÁY CHUNG mọi bảng khung sen: nội dung dừng cách đáy thân chừng này (sóng hồng, chóp đáy, hoa sen góc phải)
const ON := true      # bộ giao diện sen (khung, thanh tre, tab, chip đỏ)

static var M := {}
static var _src := {}
static var _tex := {}

static func meta() -> Dictionary:
	if M.is_empty():
		M = JSON.parse_string(FileAccess.get_file_as_string(D + "khung.json"))
	return M

static func use(w: float, h: float) -> bool:
	return ON and w >= USE_W and h >= USE_H

static func _px() -> float:
	return clampf(ceilf(Css.K), 2.0, 4.0)

static func _img(name: String, w: int, h: int, fx := false, fy := false) -> Image:
	var key := name + "|" + str(w) + "x" + str(h) + str(fx) + str(fy)
	if _src.has(key):
		return _src[key]
	var im := Image.new()
	im.load_webp_from_buffer(FileAccess.get_file_as_bytes(D + name + ".webp"))
	im.convert(Image.FORMAT_RGBA8)
	if fx:
		im.flip_x()
	if fy:
		im.flip_y()
	im.premultiply_alpha()
	im.resize(maxi(1, w), maxi(1, h), Image.INTERPOLATE_LANCZOS)
	Css._unpremul(im)
	_src[key] = im
	return im

static func _put(out: Image, name: String, r: Rect2, o: Vector2, k: float, fx := false, fy := false) -> void:
	var px := int(round((r.position.x - o.x) * k))
	var py := int(round((r.position.y - o.y) * k))
	var pw := int(round((r.end.x - o.x) * k)) - px
	var ph := int(round((r.end.y - o.y) * k)) - py
	if pw <= 0 or ph <= 0:
		return
	out.blend_rect(_img(name, pw, ph, fx, fy), Rect2i(0, 0, pw, ph), Vector2i(px, py))

static func _deco(n: String, w: float, h: float) -> Rect2:   # mảnh trang trí neo theo hộp: a (phần hộp), c (điểm neo ảnh), dx/dy
	var q: Dictionary = meta()[n]
	var sz := Vector2(float(q.s[0]), float(q.s[1]))
	if q.has("fw"):   # rộng theo hộp (chóp đỉnh, đáy)
		var nw := clampf(float(q.fw[0]) * w, float(q.fw[1]), float(q.fw[2]))
		sz = Vector2(nw, sz.y * nw / sz.x)
	var p := Vector2(float(q.a[0]) * w + float(q.get("dx", 0.0)), float(q.a[1]) * h + float(q.get("dy", 0.0)))
	return Rect2(p - Vector2(float(q.c[0]) * sz.x, float(q.c[1]) * sz.y), sz)

const DECO := ["dinh", "day", "hoa_tt", "hoa_dp", "tua", "dong"]   # dây tua treo dưới nút đóng   # thứ tự vẽ (sau đè trước)

static func bounds(w: float, h: float) -> Rect2:
	var r := Rect2(0, 0, w, h)
	for n in DECO:
		r = r.merge(_deco(n, w, h))
	return Rect2(floorf(r.position.x), floorf(r.position.y), ceilf(r.size.x) + 1.0, ceilf(r.size.y) + 1.0)

static func frame(w: float, h: float) -> Array:   # [texture, rect css so với góc trên trái hộp]
	var k := _px()
	var B := bounds(w, h)
	var key := "f" + str(int(w * 10)) + "x" + str(int(h * 10)) + "@" + str(k)
	if not _tex.has(key):
		var m := meta()
		var o := B.position
		var out := Image.create(int(ceil(B.size.x * k)), int(ceil(B.size.y * k)), false, Image.FORMAT_RGBA8)
		var gw := float(m.goc[0])
		var gh := float(m.goc[1])
		var tn := float(m.ong_n[0])
		var td := float(m.ong_d[0])
		# ống trơn giữa hai góc (kéo dài theo chiều ống: ống trơn kéo không lộ)
		_put(out, "ong_n", Rect2(gw - 0.5, 0, w - 2.0 * gw + 1.0, tn), o, k)
		_put(out, "ong_n", Rect2(gw - 0.5, h - tn, w - 2.0 * gw + 1.0, tn), o, k, false, true)
		_put(out, "ong_d", Rect2(0, gh - 0.5, td, h - 2.0 * gh + 1.0), o, k)
		_put(out, "ong_d", Rect2(w - td, gh - 0.5, td, h - 2.0 * gh + 1.0), o, k, true, false)
		# mắt tre cách đều
		var mn: Array = m.mat_n
		var md: Array = m.mat_d
		var L := w - 2.0 * gw
		var cnt := maxi(0, int(round(L / MAT)) - 1)
		for i in cnt:
			var x := gw + L * float(i + 1) / float(cnt + 1) - float(mn[0]) * 0.5
			_put(out, "mat_n", Rect2(x, 0, float(mn[0]), float(mn[1])), o, k)
			_put(out, "mat_n", Rect2(x, h - float(mn[1]), float(mn[0]), float(mn[1])), o, k, false, true)
		L = h - 2.0 * gh
		cnt = maxi(0, int(round(L / MAT)) - 1)
		for i in cnt:
			var y := gh + L * float(i + 1) / float(cnt + 1) - float(md[1]) * 0.5
			_put(out, "mat_d", Rect2(0, y, float(md[0]), float(md[1])), o, k)
			_put(out, "mat_d", Rect2(w - float(md[0]), y, float(md[0]), float(md[1])), o, k, true, false)
		# 4 góc: một ảnh lật
		_put(out, "goc", Rect2(0, 0, gw, gh), o, k)
		_put(out, "goc", Rect2(w - gw, 0, gw, gh), o, k, true, false)
		_put(out, "goc", Rect2(0, h - gh, gw, gh), o, k, false, true)
		_put(out, "goc", Rect2(w - gw, h - gh, gw, gh), o, k, true, true)
		for n in DECO:
			_put(out, n, _deco(n, w, h), o, k)
		out.fix_alpha_edges()   # không mipmap: thu nhỏ theo bảng vẫn nét
		_tex[key] = ImageTexture.create_from_image(out)
	return [_tex[key], B]

static func bar(w: float, h: float) -> Texture2D:   # thanh tre ngang bên trong bảng (ngăn mục): ống tre khung + mắt tre
	var k := _px()
	var key := "b" + str(int(w * 10)) + "x" + str(int(h * 10)) + "@" + str(k)
	if _tex.has(key):
		return _tex[key]
	var m := meta()
	var out := Image.create(int(ceil(w * k)), int(ceil(h * k)), false, Image.FORMAT_RGBA8)
	var t := minf(h, 4.6)   # ảnh mẫu: thanh ngăn mảnh hơn khung (15 px / 1112)
	var y := (h - t) * 0.5
	_put(out, "ong_n", Rect2(0, y, w, t), Vector2.ZERO, k)
	var mn: Array = m.mat_n
	var mw := float(mn[0]) * t / float(mn[1])
	var cnt := maxi(0, int(round(w / MAT)) - 1)
	for i in cnt:
		_put(out, "mat_n", Rect2(w * float(i + 1) / float(cnt + 1) - mw * 0.5, y, mw, t), Vector2.ZERO, k)
	var tx := ImageTexture.create_from_image(out)
	_tex[key] = tx
	return tx

static func close_rect(w: float) -> Rect2:   # chỗ bấm nút đóng (css, so với góc trên trái hộp)
	return _deco("dong", w, 0.0)

static func paper(w: float, h: float) -> Texture2D:   # nền giấy cả hộp: kem + sóng hồng hai góc đáy, bo góc theo vòng tre
	var k := _px()
	var key := "g" + str(int(w * 10)) + "x" + str(int(h * 10)) + "@" + str(k)
	if _tex.has(key):
		return _tex[key]
	var m := meta()
	var g: Array = m.giay
	var out := Image.create(int(ceil(w * k)), int(ceil(h * k)), false, Image.FORMAT_RGBA8)
	out.fill(Color8(int(g[0]), int(g[1]), int(g[2])))
	var sw := minf(120.0, w * 0.36)   # ảnh mẫu: sóng hồng hai góc đáy, cao như gò mây, giữa chừa trống dưới nút
	var sh := float(m.song[1]) * sw / float(m.song[0]) * 1.9
	var t := float(m.T)
	_put(out, "song", Rect2(t - 1.0, h - t - sh + 1.0, sw, sh), Vector2.ZERO, k)
	_put(out, "song", Rect2(w - t + 1.0 - sw, h - t - sh + 1.0, sw, sh), Vector2.ZERO, k, true, false)
	# góc: giấy chỉ tới giữa ống tre góc cong (mặt nạ cắt từ chính ảnh góc tre): giấu hẳn dưới tre, không lòi ra ngoài
	var gw := int(round(float(m.goc[0]) * k))
	var gh := int(round(float(m.goc[1]) * k))
	var mk := Image.new()
	mk.load_png_from_buffer(FileAccess.get_file_as_bytes(D + "goc_mask.png"))
	mk.convert(Image.FORMAT_RGBA8)
	mk.resize(gw, gh, Image.INTERPOLATE_BILINEAR)
	var W := out.get_width()
	var H := out.get_height()
	for j in mini(gh, H):
		for i in mini(gw, W):
			var a2 := mk.get_pixel(i, j).r
			if a2 < 1.0:
				for p2 in [Vector2i(i, j), Vector2i(W - 1 - i, j), Vector2i(i, H - 1 - j), Vector2i(W - 1 - i, H - 1 - j)]:
					var c := out.get_pixelv(p2)
					c.a *= a2
					out.set_pixelv(p2, c)
	var tx := ImageTexture.create_from_image(out)
	_tex[key] = tx
	return tx
