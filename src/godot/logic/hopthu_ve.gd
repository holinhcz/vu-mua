extends "res://logic/ve_aa.gd"
# HỘP THƯ trước nhà (yU bản web, khi có thư chưa đọc hoặc thư hẹn, và ông đưa thư không đứng chờ): cọc gỗ, hộp xanh, cờ đỏ,
# bong bóng lá thư (chỉ lúc không xây dựng). Vẽ ở toạ độ làng (không nhân le như bản web).

var bub := true
var bid := "thu"    # (bản 492) hình trong bong bóng: lá thư, hoặc món của thư hẹn
var ok := false     # thư hẹn đã đủ hàng: dấu ✓ xanh, nhún mạnh hơn

func _process(dt: float) -> void:
	tt += dt
	if farm.on_view(Vector2(farm.en(6.5, 5.5), farm.nn(6.5, 5.5))):
		queue_redraw()

func _draw() -> void:
	var o := Vector2(6.5, 5.5)
	var e: float = farm.en(o.x + 0.35, o.y - 0.3)
	var r: float = farm.nn(o.x + 0.35, o.y - 0.3)
	_aa = 1.0 / farm.main.zoom
	_tf(Vector2.ZERO, Vector2.ONE)
	_Dt(e, r, e, r - 18.0, _m("#5a4a2a", "#2e2614"), 1.6)
	_xe([e - 6, r - 26, e + 6, r - 26, e + 6, r - 17, e - 6, r - 17], _m("#2f6a8a", "#1a3a4a"))
	_xe([e + 4, r - 30, e + 5.4, r - 30, e + 5.4, r - 24, e + 4, r - 24], _m("#c4302a", "#6a1a18"))
	_flush()
	if bub:
		var at := Vector2(e, r - 40.0 + (0.0 if farm.G.motion_off() else sin(tt * (6.0 if ok else 3.0)) * (2.4 if ok else 1.2)))
		_x0(at, bid)
		if ok:
			_flush()
			var le: float = farm.sign_le()
			var tk: Texture2D = Bong.anh("tick", le * farm.main.zoom)
			if tk != null:
				draw_texture_rect(tk, Rect2(at + Vector2(5.0, -13.0) * le, Vector2(9.0, 9.0) * le), false)
	_flush()
