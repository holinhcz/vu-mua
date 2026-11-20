extends RefCounted
# ĐUA GÀ (#dgBtn trong nhóm Giải trí của Menu). Viết lại hẳn bằng Godot (logic/dg/: luật đua + AI, đường, hình, vẽ
# trời, mặt đường, cảnh, gà, HUD), không còn trang web nào; chạy được trên app Android / iOS.
# Về top 3 được xu nông trại như web: w_duong.dg_end (g.dg, lượt thưởng mỗi ngày).
# Lúc đang chơi: làng ẩn đi (không vẽ), bản đồ không nhận lướt / zoom; "Về vườn" trả lại.

const GAME := preload("res://logic/dg/dg_game.gd")

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

static func _s_end(mode: String, place: int, diff: int) -> void:
	if _self != null:
		_self._end(mode, place, diff)

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
	g.setup(float(ui.dpr_v), ui.F.P, func(): return int(ui.G.g.coins))
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

func _end(mode: String, place: int, diff: int) -> void:   # web message {dg:1, t:"end"}
	var r: Dictionary = ui.G.w_all.WD.dg_end(mode, place, diff)
	if is_instance_valid(_layer) and _layer.get_child_count():
		_layer.get_child(0).reward(int(r.xu), int(r.left), int(r.max))

func step(_dt: float) -> void:
	pass
