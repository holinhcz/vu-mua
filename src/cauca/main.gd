extends Control
# CÂU CÁ BỜ KÊNH — bản chơi riêng (tách khỏi Nông Trại để sửa cho xong, rồi gắn lại vào Giải trí).
# logic/cc/ = link tới src/godot/logic/cc (bản 529: một bản code duy nhất, sửa một chỗ là vườn + bản chơi riêng cùng đổi).
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
	# (Link 11-22 "fps còn 80 giựt"): màn 120Hz mà máy chỉ ra ~80 khung thì khung dài khung ngắn xen kẽ = giựt.
	# Khoá 60 khung/giây: mỗi khung đúng 2 lần quét màn, chạy đều, còn dư sức (máy đang làm được 80).
	Engine.max_fps = 60
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
var _pc: Control
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
	_pc = pc
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
# ms mỗi khung của từng phần: code logic (cc_game PT) + code vẽ từng lớp (cc_draw Lay.T). Phần còn lại của 'tb'
# là Godot dựng hình + card màn hình.
func _prof_text(n: int) -> String:
	var LG = load("res://logic/cc/cc_game.gd")
	var LD = load("res://logic/cc/cc_draw.gd")
	var t := ""
	var tot := 0.0
	var a := []
	for k in LG.PT:
		var ms: float = LG.PT[k] / 1000.0 / maxf(n, 1)
		tot += ms; a.append("%s %.1f" % [k, ms])
	LG.PT.clear()
	var b := []
	var tot2 := 0.0
	for k in LD.Lay.T:
		var ms: float = LD.Lay.T[k] / 1000.0 / maxf(n, 1)
		tot2 += ms; b.append("%s %.1f" % [k, ms])
	LD.Lay.T.clear()
	var LU = load("res://logic/cc/cc_ui.gd")
	for k in LU.Box.T:
		var ms: float = LU.Box.T[k] / 1000.0 / maxf(n, 1)
		tot2 += ms; b.append("%s %.1f" % [str(k).trim_prefix("_draw_"), ms])
	LU.Box.T.clear()
	t += "\ncode %.1f ms:%s" % [tot, _rows(a)]
	t += "\nvẽ %.1f ms:%s" % [tot2, _rows(b)]
	return t

# màn dọc hẹp: mỗi dòng 4 mục, khỏi tràn ra ngoài
func _rows(a: Array) -> String:
	var o := ""
	for i in a.size():
		o += ("\n   " if i % 4 == 0 else " · ") + str(a[i])
	return o

func _process(dt: float) -> void:
	if _ml == null:
		return
	# mở hộp thoại thì ẩn đồng hồ đo: nó đè lên tab "Mồi câu" + tiêu đề, nuốt mất cú bấm
	_pc.visible = not (g != null and g.ui != null and g.ui.modal.visible)
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
	t += _prof_text(_n)
	t += "\nchế độ: %s (chạm để đổi)" % MODES[_mode]
	_ml.text = t
	if OS.has_feature("pc") and not OS.has_feature("web"):
		print(t.replace("\n", " | "))
	_acc = 0.0; _n = 0; _sum = 0.0; _worst = 0.0
