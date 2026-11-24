extends RefCounted
# CUỘN DỌC DÙNG CHUNG (bản 276, mọi bảng từ bản 287): kéo tay / lăn chuột trong khung `area` thì cuộn.
# Mọi bảng cuộn đều xài cái này (Kho, khay giống, đơn hàng, Xây dựng, Sổ nhiệm vụ, Cài đặt, Lên cấp, xưởng, bảng tre chung).
#   setup(box, cao nội dung, cao khung): khung cắt phần dư, các ô con trong box dời lên xuống (Kho, khay giống).
#   bind(area, hmax, mover): bảng tự dời phần thân, mover.call(s) mỗi khi s đổi.
#   hz = true: cuộn NGANG (bản 538, hàng chip lọc Kho): cao nội dung / cao khung đọc là rộng nội dung / rộng khung.
# moved(): lần chạm này là kéo cuộn (nhấc tay ra không tính là bấm nút); tự xoá khi chạm xuống lần sau.
const Css = preload("res://ui/css.gd")

var area: Control = null   # khung bắt ngón tay
var box: Control = null    # kiểu setup: khung có các ô con được dời
var mover = null           # kiểu bind: Callable(s)
var s := 0.0               # đang cuộn bao nhiêu (đơn vị giao diện)
var hmax := 0.0            # cuộn tối đa
var off := 0.0             # (setup) các ô con đang dời lên bao nhiêu
var drag = null            # {y0, s0} khi đang giữ ngón tay trong khung
var _moved := false
var hz := false            # (bản 538) cuộn ngang

func setup(b: Control, content_h: float, view_h: float) -> void:   # gọi sau khi dựng lại các ô con (ô con ở chỗ gốc)
	box = b
	area = b
	mover = null
	box._kids.clip_contents = true
	hmax = maxf(0.0, content_h - view_h)
	s = clampf(s, 0.0, hmax)
	off = 0.0
	to(s)

func bind(a: Control, h: float, mv: Callable) -> void:
	area = a
	box = null
	mover = mv
	hmax = maxf(0.0, h)
	s = clampf(s, 0.0, hmax)
	mover.call(s)

func reset() -> void:
	s = 0.0
	drag = null
	_moved = false

func to(v: float) -> void:
	s = clampf(v, 0.0, hmax)
	if mover != null:
		mover.call(s)
		return
	if box == null or not is_instance_valid(box):
		return
	var d := s - off
	if d == 0.0:
		return
	for k in box.kids():
		if hz:
			k.position.x -= d * Css.K
		else:
			k.position.y -= d * Css.K
	off = s

func _live() -> bool:
	return area != null and is_instance_valid(area) and area.is_visible_in_tree()

func grabbing(e: InputEvent) -> bool:   # (bản 277) ngón tay / chuột đang ở trong khung cuộn: làng không kéo / zoom theo
	if not _live():
		return false
	return drag != null or (("position" in e) and area.get_global_rect().has_point(e.position))

func moved() -> bool:
	return _moved

func input(e: InputEvent) -> bool:   # true = đã dùng sự kiện (lăn chuột)
	var down: bool = (e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT)) and e.pressed
	if down:
		_moved = false
	if not _live():
		drag = null
		return false
	var inside: bool = ("position" in e) and area.get_global_rect().has_point(e.position)
	if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if inside and hmax > 0.0 and not hz:
			to(s + (-40.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 40.0))
			return true
		return false
	# ngón tay theo đơn vị giao diện của khung (khung có thể đang thu nhỏ cho vừa màn)
	var k: float = absf(area.get_global_transform_with_canvas().get_scale().y)
	var ax := 0 if hz else 1
	k = maxf(0.0001, k) * Css.K
	if e is InputEventScreenTouch or e is InputEventMouseButton:
		if e is InputEventMouseButton and e.button_index != MOUSE_BUTTON_LEFT:
			return false
		if e.pressed:
			drag = {"y0": e.position[ax], "s0": s} if inside and hmax > 0.0 else null
		else:
			drag = null
	elif (e is InputEventScreenDrag or e is InputEventMouseMotion) and drag != null:
		var d: float = (e.position[ax] - float(drag.y0)) / k
		if absf(d) > 6.0:
			_moved = true
		if _moved:
			to(drag.s0 - d)
	return false
