extends Node2D
# MÂY (11-22, Link "bên đó tao chưa vẽ mây" rồi "vẽ đơn giản thôi"): mây phẳng 2 màu vẽ sẵn thành ảnh
# (src/tools/cc/bank9/may_don.py, ui/img/cc/may/),
# mỗi đám 1 ảnh. Thu nhỏ 1 lần (Lanczos) đúng số điểm ảnh cần lúc đổi cỡ màn, rồi chỉ vẽ ảnh: trôi chậm sang phải,
# nằm sau bờ (đáy mây khuất sau ngọn cây). Màu theo giờ = nhân với màu mây của trời (tod.cloud), mưa thì xám + nhiều mây.
# 2 bản: trên màn (đúng K điểm ảnh / css) và trong SubViewport của nước (để mặt nước soi bóng mây).

const A := preload("res://logic/cc/cc_art.gd")
const DIR := "res://ui/img/cc/may/"
# [ảnh, x (0..1 dọc đường trôi), đáy y (phần của yw), cao (phần của yw), tốc độ (phần của H mỗi giây), lật]
const SLOT := [
	["may4", .02, .62, .13, .0030, false],
	["may2", .24, .50, .2, .0036, true],
	["may0", .45, .66, .34, .0042, false],
	["may5", .63, .40, .09, .0026, true],
	["may1", .80, .60, .28, .0040, true],
	["may3", .96, .46, .17, .0033, false],
]
var game
var unit := 1.0      # đơn vị vẽ trên 1 css px (màn = 1, SubViewport = scale_s)
var px := 1.0        # điểm ảnh ảnh trên 1 css px
var clip_y := -1.0   # css: không vẽ dưới đường này (trong SubViewport: cắt ở đỉnh bờ, khỏi đè lên cây)
var _src := {}
var _meta := {}
var _tex := []       # [ImageTexture, size css, anchor css]
var _key := ""
var _t := 0.0
var _col := Color.WHITE
var _n := 6.0

func _init(gm) -> void:
	game = gm

func _load() -> bool:   # chỉ may.json; ảnh gốc (_src) đọc lúc cần thu nhỏ (khỏi giải nén khi đã có ảnh lưu sẵn)
	if not _meta.is_empty():
		return true
	var j = JSON.parse_string(FileAccess.get_file_as_string(DIR + "may.json"))
	if typeof(j) != TYPE_DICTIONARY:
		return false
	_meta = j
	return true

func _load_src() -> bool:
	if not _src.is_empty():
		return true
	for s in SLOT:
		var b := FileAccess.get_file_as_bytes(DIR + s[0] + ".webp")
		var im := Image.new()
		if b.is_empty() or im.load_webp_from_buffer(b) != OK:
			return false
		im.convert(Image.FORMAT_RGBA8)
		_src[s[0]] = im
	return true

func rebuild(unit_: float, px_: float, clip := -1.0) -> void:
	unit = unit_
	px = px_
	clip_y = clip
	var L: Dictionary = game.L
	var k := "%d_%d_%.3f_%.3f" % [int(L.W), int(L.H), px, clip]
	if k == _key or not _load():
		return
	_key = k
	_tex.clear()
	for s in SLOT:
		var m: Dictionary = _meta[s[0]]
		var hc: float = minf(L.yw, L.W * .3) * float(s[3])     # màn dọc hẹp: mây theo bề ngang, khỏi to quá
		var f: float = hc / float(m.h)
		var tw := maxi(2, int(round(m.w * f * px)))
		var th := maxi(2, int(round(m.h * f * px)))
		var ck := "may_%s_%d_%d_%d" % [s[0], tw, th, int(s[5])]
		var im: Image = A.cache_get(ck)
		if im == null or im.get_width() != tw or im.get_height() != th:
			if not _load_src():
				return
			im = _src[s[0]].duplicate()
			# nhỏ hơn nửa thì thu 2 bước cho mịn
			while im.get_width() > tw * 2:
				im.resize(im.get_width() / 2, im.get_height() / 2, Image.INTERPOLATE_CUBIC)
			im.resize(tw, th, Image.INTERPOLATE_LANCZOS)
			if s[5]:
				im.flip_x()
			A.cache_put(ck, im)
		var ax: float = m.ax * f
		if s[5]:
			ax = m.w * f - ax
		_tex.append([ImageTexture.create_from_image(im), Vector2(tw, th) / px, Vector2(ax, m.ay * f)])
	queue_redraw()

func upd(t: float, tod: Dictionary, W: Dictionary) -> void:
	_t = t
	var c: Color = tod.cloud
	_col = Color(c.r, c.g, c.b, 1.0 - W.rain * .1)
	_n = 2.0 + W.cloud * 4.0          # trời quang 2-3 đám, nhiều mây / mưa đủ 6
	queue_redraw()

func _draw() -> void:
	if _tex.is_empty():
		return
	var L: Dictionary = game.L
	for i in SLOT.size():
		var a := clampf(_n - float([0, 3, 1, 4, 2, 5][i]), 0.0, 1.0)
		if a <= 0.0:
			continue
		var s: Array = SLOT[i]
		var tx: Array = _tex[i]
		var sz: Vector2 = tx[1]
		var span: float = L.W + sz.x * 2.0
		var x: float = fposmod(float(s[1]) * span + _t * L.H * float(s[4]), span) - sz.x
		var by: float = L.yw * float(s[2])
		var pos := Vector2(x, by - tx[2].y)
		var col := Color(_col.r, _col.g, _col.b, _col.a * a)
		if clip_y > 0.0:
			var hv := clampf(clip_y - pos.y, 0.0, sz.y)
			if hv <= 0.0:
				continue
			var tsz: Vector2 = Vector2(tx[0].get_size())
			draw_texture_rect_region(tx[0], Rect2(pos * unit, Vector2(sz.x, hv) * unit),
				Rect2(0, 0, tsz.x, tsz.y * hv / sz.y), col)
		else:
			draw_texture_rect(tx[0], Rect2(pos * unit, sz * unit), false, col)
