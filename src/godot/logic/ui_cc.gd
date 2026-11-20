extends RefCounted
# CÂU CÁ BỜ KÊNH (nút "Câu cá" trong nhóm Giải trí của Menu). Viết lại hẳn bằng Godot (logic/cc/: dữ liệu cá,
# nước + trời (shader), vẽ cần / phao / ghe, game, âm thanh, giao diện), không có trang web nào; chạy trên app.
# Câu cá cũ của vườn vẫn mở được từ chỗ nước / tab Nhân vật (pcp.open("cau")).
# Lúc đang chơi: làng ẩn đi (không vẽ), bản đồ không nhận lướt / zoom; "Về vườn" trả lại.

const GAME := preload("res://logic/cc/cc_game.gd")

var ui
static var on := false
static var _layer: CanvasLayer = null
static var _vis := []
static var _modal := false
static var _self = null

func _init(u) -> void:
	ui = u
	_self = self

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
