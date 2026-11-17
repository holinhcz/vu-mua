extends RefCounted
# Bong bóng X0 dùng chung (và vòng vàng ô chín) (ô ruộng, cây ăn trái, thùng ong, con vật, xưởng, củi cây đổ): khung ảnh + hình trong.
# Khung xanh dương = thường (có hàng, có trái, cần tưới), đỏ = sâu bệnh, nguy hại.
# Ảnh gốc 9 px mỗi đơn vị làng ở res://ui/img/bong/ (vẽ bằng src/tools/bong/lam.py). Làng vẽ lọc LINEAR không mipmap,
# nên lấy bản thu nhỏ sẵn theo nấc 1/2, 1/4... gần nhất với cỡ trên màn (như P.texz / item_ic): zoom nào cũng nét.

const KHUNG := Rect2(-12.5, -12.5, 25.0, 31.1111)   # tâm vòng tròn ở (0, 0), r 10, đuôi tới y 14,6
const GOC := 9.0                                     # px ảnh gốc mỗi đơn vị

static var _img := {}   # tên -> Image gốc
static var _tex := {}   # tên@nấc -> ImageTexture

static func _anh(k: String, ppu: float) -> Texture2D:   # ppu: px màn hình mỗi đơn vị cần vẽ
	var n := 0
	while n < 4 and GOC / pow(2.0, n + 1) >= ppu:
		n += 1
	var key := k + "@" + str(n)
	if _tex.has(key):
		return _tex[key]
	if not _img.has(k):
		var im := Image.new()
		if im.load_png_from_buffer(FileAccess.get_file_as_bytes("res://ui/img/bong/" + k + ".png")) != OK:
			_img[k] = null
		else:
			im.convert(Image.FORMAT_RGBA8)
			im.fix_alpha_edges()   # chỗ trong suốt mang màu mép: thu nhỏ không bị viền tối
			_img[k] = im
	var g = _img[k]
	if g == null:
		_tex[key] = null
		return null
	var m: Image = (g as Image).duplicate()
	if n > 0:
		m.resize(maxi(1, m.get_width() >> n), maxi(1, m.get_height() >> n), Image.INTERPOLATE_LANCZOS)
	_tex[key] = ImageTexture.create_from_image(m)
	return _tex[key]

static func ve(ci: CanvasItem, at: Vector2, s: float, hinh: Texture2D, red := false, cao := 13.6) -> void:
	# at: tâm vòng (toạ độ làng); s: độ to (le x nhún); hinh: hình đặt giữa vòng, cạnh `cao` đơn vị
	var ppu := s * float(ci.get_canvas_transform().get_scale().x)
	ci.draw_set_transform(at, 0.0, Vector2(s, s))
	var f := _anh("do" if red else "xanh", ppu)
	# (bản 235) khung + hình gộp sẵn thành MỘT ảnh (mỗi loại một lần): hàng trăm bong bóng cùng loại vẽ chung một lệnh,
	# trước đây khung và hình xen kẽ hai ảnh nên mỗi bong bóng tốn hai lệnh vẽ
	var g := _gop(f, hinh, cao) if f != null and hinh != null else null
	if g != null:
		ci.draw_texture_rect(g, KHUNG, false)
	else:
		if f != null:
			ci.draw_texture_rect(f, KHUNG, false)
		if hinh != null:
			ci.draw_texture_rect(hinh, Rect2(-cao / 2.0, -cao / 2.0, cao, cao), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static var _gopc := {}   # khung@hình@cao -> ImageTexture
static func _gop(f: Texture2D, hinh: Texture2D, cao: float) -> Texture2D:
	var key := str(f.get_rid().get_id()) + "@" + str(hinh.get_rid().get_id()) + "@" + str(cao)
	if _gopc.has(key):
		return _gopc[key]
	_gopc[key] = null
	var fi: Image = f.get_image()
	var hi: Image = hinh.get_image()
	if fi == null or hi == null or fi.is_empty() or hi.is_empty():
		return null
	fi = fi.duplicate()
	if fi.is_compressed() or hi.is_compressed():
		return null
	fi.convert(Image.FORMAT_RGBA8)
	hi = hi.duplicate()
	hi.convert(Image.FORMAT_RGBA8)
	var sc := float(fi.get_width()) / KHUNG.size.x   # px ảnh khung mỗi đơn vị
	var w := maxi(1, int(round(cao * sc)))
	if hi.get_width() != w or hi.get_height() != w:
		hi.resize(w, w, Image.INTERPOLATE_LANCZOS)
	var at := Vector2i(int(round((-cao / 2.0 - KHUNG.position.x) * sc)), int(round((-cao / 2.0 - KHUNG.position.y) * sc)))
	fi.blend_rect(hi, Rect2i(0, 0, w, w), at)
	var t := ImageTexture.create_from_image(fi)
	_gopc[key] = t
	return t

static func anh(k: String, ppu: float) -> Texture2D:   # ảnh khác trong ui/img/bong: nuoc (cần tưới), gap (!), benh (chữ thập), vong (vòng ô chín); ppu = px màn mỗi đơn vị
	return _anh(k, ppu)
