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
	var tex: Texture2D = Css.image(String(d.img) if d.has("img") else "res://ui/img/dan/" + str(clampi(int(d.get("lk", 0)), 0, 7)) + ".webp")
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
	# khách du lịch vui: tim đỏ bay lên trên đầu (J_: r - 40o - (Ke·12 + n·7) % 14)
	if bool(d.get("heart", false)) and not farm.G.motion_off():
		var hy := foot.y - 40.0 * r - fposmod(tt * 12.0 + float(d.get("ph", 0.0)) * 7.0, 14.0)
		var hf: Font = Css.font(700)
		var hw := hf.get_string_size("♥", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(hf, Vector2(foot.x - hw / 2.0, hy), "♥", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e2453a"))
	# tên trên đầu khi zoom gần (Lh: ba.z >= 1,05): viên trắng .88, chữ 700 9px nâu, nhân le
	var z: float = farm.main.zoom
	if farm.ui != null and farm.ui.cz() >= 1.05 and String(d.get("n", "")) != "":
		var nm := String(d.n)
		var fnt: Font = Css.font(700)
		var fs := 9.0 * le * z   # vẽ chữ ở cỡ px màn hình cho nét, rồi thu về toạ độ làng
		var q := maxi(1, int(round(fs)))
		var tw := fnt.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, q).x / z
		var w := tw + 10.0 * le
		var c0 := foot + Vector2(0, -36.0 * r)
		var rr := Rect2(c0.x - w / 2.0, c0.y - 7.0 * le, w, 14.0 * le)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.88)
		sb.set_corner_radius_all(int(round(7.0 * le * z)))
		sb.anti_aliasing = true
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 / z, 1.0 / z))
		draw_style_box(sb, Rect2(rr.position * z, rr.size * z))
		var asc := fnt.get_ascent(q)
		var hh := fnt.get_height(q)
		draw_string(fnt, Vector2(c0.x * z - tw * z / 2.0, c0.y * z + 0.5 * le * z - hh / 2.0 + asc), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, q, Color("#4a3420"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
