extends RefCounted
# XẾP TRÁI MIỆT VƯỜN (nút "Xếp trái" trong nhóm Giải trí của Menu). Viết lại hẳn bằng Godot (logic/xt/: luật bàn,
# hiệu ứng, cảnh sông, bản đồ + dựng vườn, nông trại, âm thanh), không còn trang web nào; chạy trên app Android / iOS.
# Qua màn được xu như web: w_duong.xt_end (lần đầu 30 + 20/sao, chơi lại 10/sao, giới hạn mỗi ngày, g.xt).
# Lúc đang chơi: làng ẩn đi (không vẽ), bản đồ không nhận lướt / zoom; "Về vườn" trả lại.

const GAME := preload("res://logic/xt/xt_game.gd")

var ui
static var on := false
static var _layer: CanvasLayer = null
static var _vis := []
static var _modal := false
static var _self = null

func _init(u) -> void:
	ui = u
	_self = self

static func _s_end(level: int, stars: int, _first: bool) -> void:
	if _self != null:
		_self._end(level, stars)

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

func _end(level: int, stars: int) -> void:   # web message {xt:"end"}
	var r: Dictionary = ui.G.w_all.WD.xt_end(level, stars)
	if is_instance_valid(_layer) and _layer.get_child_count():
		_layer.get_child(0).reward(int(r.xu), int(r.left), int(r.max))

func step(_dt: float) -> void:
	pass
