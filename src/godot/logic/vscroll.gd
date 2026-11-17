extends RefCounted
# Cuộn dọc dùng chung (bản 276): một khung cắt phần dư (box), các ô con dời lên xuống theo kéo tay / lăn chuột.
# Kho, khay giống ô ruộng... đều xài cái này. moved(): vừa kéo cuộn (chạm lúc đó không tính là bấm).
const Css = preload("res://ui/css.gd")

var box: Control = null
var s := 0.0        # đang cuộn bao nhiêu (đơn vị giao diện)
var hmax := 0.0     # cuộn tối đa
var off := 0.0      # các ô con đang dời lên bao nhiêu
var drag = null

func setup(b: Control, content_h: float, view_h: float) -> void:   # gọi sau khi dựng lại các ô con (ô con ở chỗ gốc)
	box = b
	box._kids.clip_contents = true
	hmax = maxf(0.0, content_h - view_h)
	s = clampf(s, 0.0, hmax)
	off = 0.0
	to(s)

func to(v: float) -> void:
	s = clampf(v, 0.0, hmax)
	if box == null or not is_instance_valid(box):
		return
	var d := s - off
	if d == 0.0:
		return
	for k in box.kids():
		k.position.y -= d * Css.K
	off = s

func grabbing(e: InputEvent) -> bool:   # (bản 277) ngón tay / chuột đang ở trong khung cuộn: làng không kéo / zoom theo
	if box == null or not is_instance_valid(box) or not box.is_visible_in_tree():
		return false
	return drag != null or (("position" in e) and box.get_global_rect().has_point(e.position))

func moved() -> bool:
	return drag != null and drag.moved

func input(e: InputEvent) -> void:
	if box == null or not is_instance_valid(box) or not box.is_visible_in_tree():
		drag = null
		return
	var inside: bool = ("position" in e) and box.get_global_rect().has_point(e.position)
	if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if inside:
			to(s + (-40.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 40.0))
		return
	if e is InputEventScreenTouch or e is InputEventMouseButton:
		if e is InputEventMouseButton and e.button_index != MOUSE_BUTTON_LEFT:
			return
		if e.pressed:
			drag = {"y0": e.position.y / Css.K, "s0": s, "moved": false} if box.get_global_rect().has_point(e.position) and hmax > 0.0 else null
		elif drag != null:
			var dd = drag
			box.get_tree().create_timer(0.05).timeout.connect(func(): if drag == dd: drag = null)
	elif (e is InputEventScreenDrag or e is InputEventMouseMotion) and drag != null:
		var d: float = e.position.y / Css.K - drag.y0
		if absf(d) > 6.0:
			drag.moved = true
		if drag.moved:
			to(drag.s0 - d)
