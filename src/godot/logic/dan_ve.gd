extends Node2D
# Vẽ một người dân trên làng (Lo bản web, chụp sẵn thành ảnh: ui/img/dan/<áo>.webp, khung 0 đứng, 1-8 đi, 9-14 vẫy tay).
# d = {u, x, y, lk, mv, ph, face, wave, carry, bob}; farm.gd tạo node, cập nhật d, xếp lớp theo chân.

const Css = preload("res://ui/css.gd")

static var META := {}
var farm
var d: Dictionary = {}
var tt := 0.0

static func meta() -> Dictionary:
	if META.is_empty():
		META = JSON.parse_string(FileAccess.get_file_as_string("res://ui/img/dan/meta.json"))
	return META

func _process(dt: float) -> void:
	tt += dt
	queue_redraw()

func _draw() -> void:
	var m := meta()
	var x: float = float(d.x)
	var y: float = float(d.y)
	var foot := Vector2(farm.en(x, y), farm.nn(x, y))
	var le: float = farm.sign_le()
	var r := le * 1.15
	# bóng (L(n, e + 1, 6r, 2r))
	var pts := PackedVector2Array()
	for k in 24:
		var a := k * TAU / 24.0
		pts.append(foot + Vector2(cos(a) * 6.0 * r, 1.0 + sin(a) * 2.0 * r))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.2))
	var tex: Texture2D = Css.image("res://ui/img/dan/" + str(clampi(int(d.get("lk", 0)), 0, 7)) + ".webp")
	if tex == null:
		return
	var fi := 0
	if bool(d.get("wave", false)):
		var per := TAU / 9.0
		fi = 9 + int(fposmod(tt, per) / per * 6.0) % 6
	elif bool(d.get("mv", false)):
		fi = 1 + int(fposmod(float(d.get("ph", 0.0)), TAU) / TAU * 8.0) % 8
	var fw: float = float(m.fw)
	var fh: float = float(m.fh)
	var s: float = le / 9.0   # ảnh vẽ 9 điểm mỗi đơn vị làng (đã nhân 1,15 của web)
	var bob := absf(sin(float(d.get("ph", 0.0)) * 2.0)) * 0.8 * r if bool(d.get("bob", false)) else 0.0
	var fc := 1.0 if int(d.get("face", 1)) >= 0 else -1.0
	draw_set_transform(foot + Vector2(0, bob), 0.0, Vector2(fc, 1.0))
	draw_texture_rect_region(tex, Rect2(-float(m.fx) * s, -float(m.fy) * s, fw * s, fh * s), Rect2(fi * fw, 0, fw, fh))
	# món trong giỏ (Lo: drawImage(Yu(r), w - 4, E - 9, 8, 8), w = -5, E = v - 1, v = -11 - f)
	var c = d.get("carry")
	if c != null and String(c) != "" and farm.ui != null:
		var f := absf(sin(float(d.get("ph", 0.0)))) * 1.2 if bool(d.get("mv", false)) else 0.0
		var it: Texture2D = farm.ui.item_ic(String(c), 8.0 * r * farm.main.zoom)
		if it != null:
			draw_texture_rect(it, Rect2(-9.0 * r, (-21.0 - f) * r, 8.0 * r, 8.0 * r), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
