extends Control
# TÌM SỐ — bản chơi riêng (tách khỏi Nông Trại để sửa cho xong, rồi gắn lại vào Giải trí).
# Cùng code logic/tso/ với Nông Trại; ở đây không có xu thưởng, "Về vườn" mở lại menu.
const GAME := preload("res://logic/tso/tso_game.gd")
var g: Control = null
func _dpr() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dpr="): return float(a.substr(6))
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("window.devicePixelRatio", true)
		return maxf(1.0, float(v)) if v != null else 1.0
	return maxf(1.0, DisplayServer.screen_get_scale())
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_open()
func _open() -> void:
	g = GAME.new()
	g.setup(_dpr())
	g.closed.connect(func(): g.queue_free(); call_deferred("_open"))
	add_child(g)
