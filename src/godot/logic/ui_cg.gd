extends RefCounted
# CỜ GÁNH (#cgBtn trong nhóm Giải trí của Menu). Bản 351: viết lại hẳn bằng Godot (logic/cg/: luật + máy, sân, quân,
# bảng), không còn trang web nào; chạy được trên app Android / iOS.
# Thắng máy được xu như web: Bé Út 20, Thằng Tí 50, Chị Hai 120, Ông Sáu 250, chỉ 5 ván thắng đầu mỗi ngày (g.cg {d, n}).
# Lúc đang chơi cờ: làng ẩn đi (không vẽ), bản đồ không nhận lướt / zoom; "Về vườn" trả lại.

const REW := [20, 50, 120, 250]
const MAXD := 5
const MG := preload("res://logic/mg_pack.gd")
const GAME := preload("res://logic/cg/cg_game.gd")

var ui
# static: giao diện dựng lại (xoay máy, đổi khổ) tạo ui mới mà bàn cờ vẫn mở
static var on := false
static var _layer: CanvasLayer = null
static var _vis := []
static var _modal := false
static var _self = null   # ui_cg mới nhất (ui dựng lại thì đổi), bàn cờ gọi về qua đây

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
	if not MG.ready():   # (bản 533) hình mini game nằm gói riêng: tải lần đầu rồi mới mở
		MG.need(ui, open)
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

func _day() -> String:   # web day(): năm-tháng-ngày theo giờ máy, không thêm số 0
	var d := Time.get_date_dict_from_system()
	return "%d-%d-%d" % [d.year, d.month, d.day]

func _cgs() -> Dictionary:   # web cgs()
	var c = G().g.get("cg")
	if not (c is Dictionary) or String(c.get("d", "")) != _day():
		c = {"d": _day(), "n": 0}
		G().g["cg"] = c
	return c

func G() -> Node:
	return ui.G

func _end(mode: String, level: int, winner: int) -> void:   # web d.t==="end"
	var xu := 0
	var c := _cgs()
	if mode == "ai" and winner == 0 and int(c.n) < MAXD:
		xu = int(REW[level]) if level >= 0 and level < REW.size() else 20
		c.n = int(c.n) + 1
		G().g.coins = int(G().g.coins) + xu
		G().mark()
	if is_instance_valid(_layer) and _layer.get_child_count():
		_layer.get_child(0).reward(xu, MAXD - int(c.n), MAXD)

func step(_dt: float) -> void:
	pass
