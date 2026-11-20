extends RefCounted
# Ô ĂN QUAN (#oqBtn trong nhóm Giải trí của Menu). Viết lại hẳn bằng Godot (logic/oq/: luật + máy, sân, bảng phấn,
# quân, bảng), không còn trang web nào; chạy được trên app Android / iOS.
# Thắng máy được xu như web: w_duong.oq_end (Bé Út 20, Thằng Tí 50, Chị Hai 120, Ông Sáu 250, 5 ván thắng đầu mỗi ngày, g.oq).
# Lúc đang chơi: làng ẩn đi (không vẽ), bản đồ không nhận lướt / zoom; "Về vườn" trả lại.

const GAME := preload("res://logic/oq/oq_game.gd")

var ui
# static: giao diện dựng lại (xoay máy, đổi khổ) tạo ui mới mà bàn cờ vẫn mở
static var on := false
static var _layer: CanvasLayer = null
static var _vis := []
static var _modal := false
static var _self = null   # ui_oq mới nhất (ui dựng lại thì đổi), bàn cờ gọi về qua đây

func _init(u) -> void:
	ui = u
	_self = self

static func _s_end(mode: String, level: int, winner: int) -> void:
	if _self != null:
		_self._end(mode, level, winner)

static func _s_close() -> void:
	if _self != null:
		_self.close()

func open() -> void:
	if on and is_instance_valid(_layer):
		return
	on = true
	var tree: SceneTree = ui.get_tree()
	_layer = CanvasLayer.new()
	_layer.layer = 100
	var g := GAME.new()
	g.setup(float(ui.dpr_v))
	g.ended.connect(Callable(get_script(), "_s_end"))
	g.closed.connect(Callable(get_script(), "_s_close"))
	_layer.add_child(g)
	tree.root.add_child(_layer)
	# làng nằm dưới, che kín: thôi vẽ cho nhẹ máy
	_vis = []
	for n in [ui.main, ui]:
		if n != null and is_instance_valid(n) and n.visible:
			_vis.append(n)
			n.visible = false
	_modal = bool(tree.get_meta("ui_modal", false))
	tree.set_meta("ui_modal", true)

func close() -> void:
	if not on:
		return
	on = false
	for n in _vis:
		if is_instance_valid(n):
			n.visible = true
	_vis = []
	if is_instance_valid(_layer):
		_layer.get_tree().set_meta("ui_modal", _modal)
		_layer.queue_free()
	_layer = null

func _end(mode: String, level: int, winner: int) -> void:   # web message {oq:"end"}
	var r: Dictionary = ui.G.w_all.WD.oq_end(mode, winner, level)
	if is_instance_valid(_layer) and _layer.get_child_count():
		_layer.get_child(0).reward(int(r.xu), int(r.left), int(r.max))

func step(_dt: float) -> void:
	pass
