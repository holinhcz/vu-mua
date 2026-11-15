extends "res://logic/ve_aa.gd"
# HỘP THƯ trước nhà (yU bản web, khi có thư chưa đọc và ông đưa thư không đứng chờ): cọc gỗ, hộp xanh, cờ đỏ,
# bong bóng lá thư (chỉ lúc không xây dựng). Vẽ ở toạ độ làng (không nhân le như bản web).

var bub := true

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
		_x0(Vector2(e, r - 40.0 + (0.0 if farm.G.motion_off() else sin(tt * 3.0) * 1.2)), "thu")
	_flush()
