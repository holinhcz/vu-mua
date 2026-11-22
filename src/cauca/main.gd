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
	_meter_make()
func _open() -> void:
	g = GAME.new()
	g.setup(_dpr())
	g.embed = false
	g.closed.connect(func(): g.queue_free(); call_deferred("_open"))
	add_child(g)

# ------------------------------------------------------------ đồng hồ đo (Link 11-22 "gắn đo fps lên coi")
# Chạm vào đồng hồ để đổi chế độ thử, mỗi chế độ tắt 1 phần để biết phần nào nặng.
const MODES := ["đủ hết", "tắt lớp trời+bờ nét", "tắt mặt nước mới", "tắt hạt nước/mưa", "tắt cảnh (chỉ giao diện)"]
var _ml: Label
var _mode := 0
var _acc := 0.0
var _n := 0
var _worst := 0.0
var _sum := 0.0
func _meter_make() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 120
	add_child(cl)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, .62)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8; sb.content_margin_right = 8; sb.content_margin_top = 4; sb.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", sb)
	var k := _dpr()
	pc.position = Vector2(8, 66) * k
	_ml = Label.new()
	_ml.add_theme_font_size_override("font_size", int(11 * k))
	_ml.add_theme_color_override("font_color", Color(1, 1, .8))
	pc.add_child(_ml)
	pc.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_mode = (_mode + 1) % MODES.size()
			_apply_mode()
			pc.accept_event())
	cl.add_child(pc)
	_ml.text = "đo..."
func _apply_mode() -> void:
	if g == null or g.scn == null:
		return
	var s = g.scn
	s.trect.visible = _mode != 1
	s.wrect.visible = _mode != 2
	if g.drw and g.drw.pfx:
		g.drw.pfx.visible = _mode != 3
	s.visible = _mode != 4
	_worst = 0.0; _sum = 0.0; _n = 0; _acc = 0.0
func _process(dt: float) -> void:
	if _ml == null:
		return
	_acc += dt; _n += 1; _sum += dt; _worst = maxf(_worst, dt)
	if _acc < 1.0:
		return
	var fps := _n / _acc
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var vm := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
	var vs := get_viewport().get_visible_rect().size
	var t := "%.0f fps · tb %.1f ms · tệ %.0f ms\n%d lệnh vẽ · %.0f MB ảnh\nmàn %dx%d · dpr %.2f" % [fps, _sum / _n * 1000.0, _worst * 1000.0, dc, vm, vs.x, vs.y, _dpr()]
	if g and g.scn and g.scn.vp:
		t += "\nnước %dx%d (x%.2f)" % [g.scn.vp.size.x, g.scn.vp.size.y, g.scn.scale_s]
	t += "\nchế độ: %s (chạm để đổi)" % MODES[_mode]
	_ml.text = t
	_acc = 0.0; _n = 0; _sum = 0.0; _worst = 0.0
