extends Control
# CÂU CÁ BỜ KÊNH — bản chơi riêng (tách khỏi Nông Trại để sửa cho xong, rồi gắn lại vào Giải trí).
# logic/cc/ là BẢN CHÉP của src/godot/logic/cc: sửa ở đây trước, Link OK thì chép ngược vào godot/.
# Ở đây không có xu thưởng, không có nút "Về vườn" (embed = false, như bản web gốc).
const GAME := preload("res://logic/cc/cc_game.gd")
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
	g.embed = false
	g.closed.connect(func(): g.queue_free(); call_deferred("_open"))
	add_child(g)
