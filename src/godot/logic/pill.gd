extends Control
# NÚT VIÊN TRÊN HUD (button.ghepill bản web: "Chợ nổi đang họp …", "Hạn mặn …", "Rầy nâu …", lễ hội, thiên tai):
# dựng từ mẫu chụp ui/snap/pill.json (viên trắng chữ đỏ, rộng bằng cột .xpills), nằm trong hàng nút viên w_all.pills.
# text: chữ (dài quá thì cắt …), hurry: .hurry (sắp hết giờ / việc gấp: nhịp nhẹ), pressed: bấm.

const Snap = preload("res://ui/snap.gd")
const Box = preload("res://ui/box.gd")
const Css = preload("res://ui/css.gd")

signal pressed

static var T := {}
var U
var box: Control = null
var _t := ""
var _h := false
var _ph := 0.0

var text: String:
	get:
		return _t
	set(v):
		if v != _t:
			_t = v
			_make()

var hurry: bool:
	get:
		return _h
	set(v):
		if v != _h:
			_h = v
			_make()

func _init(ui) -> void:
	U = ui
	if T.is_empty():
		T = Snap.load_snap("pill")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_make()

func _make() -> void:
	var n: Dictionary = (T.hurry if _h else T.pill).duplicate(true)
	Snap._move(n, Vector2(-float(n.r[0]), -float(n.r[1])))
	var fs := Css.px(String(n.css.get("font-size", "11.5px"))) * float(n.get("z", 1.0))
	var fw := int(String(n.css.get("font-weight", "700")))
	var pl := Css.px(String(n.css.get("padding-left", "10px"))) * float(n.get("z", 1.0))
	var W0 := float(n.r[2]) - pl * 2.0
	var s := _t
	if Box.text_w(s, fs, fw) > W0:
		while s.length() > 1 and Box.text_w(s + "…", fs, fw) > W0:
			s = s.substr(0, s.length() - 1)
		s = s.strip_edges() + "…"
	n.text = s
	n.tr = [pl, n.tr[1], Box.text_w(s, fs, fw), n.tr[3]]
	if box != null:
		box.queue_free()
	box = U._build(n, {})
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	custom_minimum_size = Vector2(float(n.r[2]), float(n.r[3])) * Css.K
	size = custom_minimum_size

func _process(dt: float) -> void:   # .hurry: viên nhịp nhẹ
	if _h and is_visible_in_tree():
		_ph += dt
		pivot_offset = size * 0.5
		scale = Vector2.ONE * (1.0 + 0.025 * sin(_ph * 5.0))
	elif scale != Vector2.ONE:
		scale = Vector2.ONE

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT)) and not e.pressed:
		accept_event()
		pressed.emit()
	elif e is InputEventScreenTouch or e is InputEventMouseButton:
		accept_event()
