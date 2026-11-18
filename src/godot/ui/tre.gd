extends RefCounted
# KHUNG TRE CHUNG BẰNG ẢNH (bản 294-295): 4 góc cong + 4 cạnh lặp theo đốt (ui/img/tre, vẽ bằng tools/tre/lam.py).
# Góc và cạnh cùng một mặt cắt cây tre (dày T, bóng S vào lòng) nên nối liền; nền hộp bo đúng R nên không lòi viền.
# (bản 295) Ghép SẴN cả khung thành MỘT ảnh theo đúng cỡ hộp, mảnh nào cũng đặt ở điểm ảnh nguyên, rồi vẽ một lần:
# không còn khe giữa các mảnh (vẽ từng mảnh ở toạ độ lẻ thì máy làm tròn hở 1 điểm ảnh, lộ nền kem thành vạch trắng).
# Snap.build gọi frame() cho mọi .u2tre và bar() cho mọi thanh tre ngang: một khung cho cả game.
const Css = preload("res://ui/css.gd")
const T := 7.0     # dày tre (css px)
const S := 3.0     # bóng đổ vào lòng bảng
const R := 16.0    # bo góc ngoài = bo góc nền hộp
const L := 48.0    # dài một đốt (một mắt tre)
const D := "res://ui/img/tre/"
const SRC := 6.0   # ảnh gốc: 6 điểm ảnh / css px

static var _src := {}
static var _tex := {}

static func _px() -> float:   # điểm ảnh / css px khi ghép: theo độ nét màn (2..4)
	return clampf(ceilf(Css.K), 2.0, 4.0)

static func _img(name: String, w: int, h: int) -> Image:   # mảnh gốc thu về đúng w x h điểm ảnh
	var key := name + "|" + str(w) + "x" + str(h)
	if _src.has(key):
		return _src[key]
	var im := Image.new()
	im.load_png_from_buffer(FileAccess.get_file_as_bytes(D + name + ".png"))
	im.convert(Image.FORMAT_RGBA8)
	# thu như Css.svg_load: nhân màu với độ trong trước rồi mới thu, chia lại sau (không thì mép trong suốt kéo màu đen /
	# vệt sáng Lanczos ra viền quanh tre)
	im.premultiply_alpha()
	im.resize(maxi(1, w), maxi(1, h), Image.INTERPOLATE_LANCZOS)
	Css._unpremul(im)
	_src[key] = im
	return im

static func _cuts(total: int, n: int) -> Array:   # chia total điểm ảnh thành n đoạn nguyên, cộng lại đúng total
	var o := []
	var a := 0
	for i in n:
		var b := int(round(float(total) * (i + 1) / n))
		o.append([a, b - a])
		a = b
	return o

static func texture(w: float, h: float) -> Texture2D:   # cả khung tre cho hộp w x h (css px), một ảnh
	var k := _px()
	var W := int(round(w * k))
	var H := int(round(h * k))
	var key := str(W) + "x" + str(H)
	if _tex.has(key):
		return _tex[key]
	var r := int(round(R * k))
	var e := int(round((T + S) * k))
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var sw := W - 2 * r
	for c in _cuts(sw, maxi(1, int(round(sw / (L * k))))):
		out.blit_rect(_img("canh_tren", c[1], e), Rect2i(0, 0, c[1], e), Vector2i(r + c[0], 0))
		out.blit_rect(_img("canh_duoi", c[1], e), Rect2i(0, 0, c[1], e), Vector2i(r + c[0], H - e))
	var sh := H - 2 * r
	for c in _cuts(sh, maxi(1, int(round(sh / (L * k))))):
		out.blit_rect(_img("canh_trai", e, c[1]), Rect2i(0, 0, e, c[1]), Vector2i(0, r + c[0]))
		out.blit_rect(_img("canh_phai", e, c[1]), Rect2i(0, 0, e, c[1]), Vector2i(W - e, r + c[0]))
	out.blit_rect(_img("goc_tt", r, r), Rect2i(0, 0, r, r), Vector2i(0, 0))
	out.blit_rect(_img("goc_tp", r, r), Rect2i(0, 0, r, r), Vector2i(W - r, 0))
	out.blit_rect(_img("goc_dt", r, r), Rect2i(0, 0, r, r), Vector2i(0, H - r))
	out.blit_rect(_img("goc_dp", r, r), Rect2i(0, 0, r, r), Vector2i(W - r, H - r))
	out.fix_alpha_edges()   # chỗ trong suốt mang màu mép tre: mipmap / lọc mịn không ra viền đen hay sáng
	out.generate_mipmaps()
	var t := ImageTexture.create_from_image(out)
	_tex[key] = t
	return t

static func bar(w: float) -> Texture2D:   # thanh tre ngang dài w (css px), cao T + S, một ảnh
	var k := _px()
	var W := int(round(w * k))
	var key := "bar" + str(W)
	if _tex.has(key):
		return _tex[key]
	var e := int(round((T + S) * k))
	var out := Image.create(W, e, false, Image.FORMAT_RGBA8)
	for c in _cuts(W, maxi(1, int(round(W / (L * k))))):
		out.blit_rect(_img("canh_tren", c[1], e), Rect2i(0, 0, c[1], e), Vector2i(c[0], 0))
	out.fix_alpha_edges()
	out.generate_mipmaps()
	var t := ImageTexture.create_from_image(out)
	_tex[key] = t
	return t

static func frame(r: Array, z: float) -> Array:   # khung quanh hộp r (tràn ra 1,5 px: phủ kín cả mép mịn của nền ở mọi độ nét màn)
	var x: float = float(r[0]) - 1.5
	var y: float = float(r[1]) - 1.5
	var w: float = float(r[2]) + 3.0
	var h: float = float(r[3]) + 3.0
	return [{"tag": "i", "id": "", "cls": "tre-khung", "z": z, "css": {"position": "absolute"}, "r": [x, y, w, h], "kids": [], "tre": [w, h]}]
