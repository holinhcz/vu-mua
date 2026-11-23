extends RefCounted
# CÂU CÁ BỜ KÊNH (nút "Câu cá" trong nhóm Giải trí của Menu). Viết lại hẳn bằng Godot (logic/cc/: dữ liệu cá,
# nước + trời (shader), vẽ cần / phao / ghe, game, âm thanh, giao diện), không có trang web nào; chạy trên app.
# Câu cá cũ của vườn (tab Câu cá trong Nhân vật) ĐÃ BỎ (Link 11-23 "bỏ câu cũ đi"): nhiệm vụ "Câu được N con cá" mở game này.
# Lúc đang chơi: làng ẩn đi (không vẽ), bản đồ không nhận lướt / zoom; "Về vườn" trả lại.
# (11-23) Code logic/cc = bản chơi riêng src/cauca (Link OK "gắn lại vào game nông trại"). Hình câu cá (~25 MB) KHÔNG nằm
# trong pck vườn: lần đầu bấm "Câu cá" tải gói l/cc_<n>.wasm (tools/cc/mk_ccpack.py), ghép lại, lưu user://cc_<CC_V>.pck,
# ProjectSettings.load_resource_pack() -> res://ui/img/cc/... đọc được như thường. Lần sau mở máy: đọc file đã lưu, khỏi tải.

const GAME := preload("res://logic/cc/cc_game.gd")
const CC_V := "12ebd89f"     # crc gói hình (mk_ccpack.py in ra)
const CC_N := 4        # số miếng l/cc_<i>.wasm
const CC_SIZE := 28578460     # tổng số byte
static var _packed := false
static var _ld: CanvasLayer = null
static var _lab: Label = null
static var _parts := []
static var _reqs := []
static var _fail := false

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
	if not _packed:
		_pack_get()
		return
	on = true
	var tree: SceneTree = ui.get_tree()
	_layer = CanvasLayer.new()
	_layer.layer = 100
	var g := GAME.new()
	g.setup(float(ui.dpr_v))
	g.cache_v = CC_V      # (Link 11-23 "ấn 3s mới vào game"): ảnh dựng theo cỡ màn lưu lại, lần sau mở nhanh
	# (Link 11-23 "nối đồng bộ vô game, câu cá chỉ là minigame"): xài xu vườn, cá cất vô Kho vườn,
	# tiến trình câu cá (cấp, đồ nghề, mồi, giỏ, sổ cá) lưu chung save vườn ở g.ccsv -> đồng bộ lên mạng như vườn
	var G = ui.G
	if not (G.g.get("ccsv") is Dictionary):
		G.g.ccsv = {}
	g.host = {
		"sv": G.g.ccsv,
		"coins": func(): return int(G.g.coins),
		"add": func(d: int):
			G.g.coins = maxi(0, int(G.g.coins) + d)
			G.mark(),
		"kho": func(id: String, n: int) -> bool:   # false = Kho vườn đầy
			if G.kho_room() < n:
				return false
			G.g.barn[id] = int(G.g.barn.get(id, 0)) + n
			G.mark()
			return true,
		"room": func(): return "%d/%d" % [G.kho_n(), G.kho_cap()],
		# mồi chung Kho (cc_data.KHO_BAIT: tép sống = tép trong Kho vườn)
		"bait": func(id: String): return int(G.g.barn.get(id, 0)),
		"bait_add": func(id: String, d: int):
			G.g.barn[id] = maxi(0, int(G.g.barn.get(id, 0)) + d)
			G.mark(),
		# cá quý (3 sao trở lên) dễ cắn hơn: bùa "Tay câu đỏ" x1.5, nâng "n_cau" của hệ thống (như câu cũ w_ca.mx)
		"rare": func() -> float:
			var m := 1.5 if G.bh() == "cau" else 1.0
			if G.w_all != null:
				m *= 1.0 + float(G.w_all.WCA._htv("n_cau"))
			return m,
		"save": func(): G.save_game(),
		# (Link 11-23 "làm theo giờ của game nông trại"): giờ trong ngày + mưa ở bờ kênh = đồng hồ, thời tiết của vườn
		# (troi.hour = nv.hour, có đè giờ trong Cài đặt; troi.rain: mưa rào 1, mưa dầm .55, nắng / hạn 0)
		"hour": func() -> float: return float(G.troi.hour()) if G.troi != null else 9.0,
		"rain": func() -> float: return float(G.troi.rain()) if G.troi != null else 0.0,
		# câu được 1 con (không tính rác): đếm cho vườn như câu cũ: g.fish.total (w_ca.ry -> nhiệm vụ / thành tựu Tay câu),
		# EXP nhân vật 3, cá vườn có món thì ghi sổ làng (đã gặp) + sổ cá vườn
		"caught": func(kid: String):
			if not (G.g.get("fish") is Dictionary):
				G.g.fish = {"rod": 0, "total": 0, "dex": {}}
			var f: Dictionary = G.g.fish
			f.total = int(f.get("total", 0)) + 1
			G.add_xp(3, "fish")
			if kid != "":
				if not (f.get("dex") is Dictionary):
					f.dex = {}
				if not (f.dex.get(kid) is Dictionary):
					f.dex[kid] = {"n": 0, "best": 0}
				f.dex[kid].n = int(f.dex[kid].n) + 1
				if G.w_all != null:
					G.w_all.WCA.tc().seen[kid] = 1
			G.mark(),
	}
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

# ------------------------------------------------------------ gói hình câu cá (tải 1 lần, lưu máy)
func _pack_path() -> String:
	return "user://cc_" + CC_V + ".pck"

func _pack_load() -> bool:
	var p := _pack_path()
	if not FileAccess.file_exists(p):
		return false
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null or f.get_length() != CC_SIZE:
		return false
	f.close()
	_packed = ProjectSettings.load_resource_pack(p, true)
	return _packed

func _pack_get() -> void:
	if _pack_load():
		open()
		return
	if is_instance_valid(_ld):
		return
	var tree: SceneTree = ui.get_tree()
	var k := float(ui.dpr_v)
	_ld = CanvasLayer.new()
	_ld.layer = 101
	var bg := ColorRect.new()
	bg.color = Color(.1, .16, .14, .72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_ld.add_child(bg)
	_lab = Label.new()
	_lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var fv := FontVariation.new()
	var ff := FontFile.new()
	ff.load_dynamic_font("res://ui/font/nunito_800.ttf")
	fv.base_font = ff
	_lab.add_theme_font_override("font", fv)
	_lab.add_theme_font_size_override("font_size", int(20 * k))
	_lab.add_theme_color_override("font_color", Color(1, .97, .88))
	_lab.text = "Đang tải bờ kênh… 0%"
	bg.add_child(_lab)
	# chạm khi tải lỗi = thử lại; chạm ngoài lúc đang tải thì thôi
	bg.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			if _fail:
				_pack_free()
				_pack_get())
	tree.root.add_child(_ld)
	var tm := Timer.new()
	tm.wait_time = .2
	tm.autostart = true
	tm.timeout.connect(_pack_tick)
	_ld.add_child(tm)
	_fail = false
	_parts = []
	_reqs = []
	var base := str(ui.main.base_url) if ui.main != null and "base_url" in ui.main else ""
	for i in CC_N:
		_parts.append(null)
		var h := HTTPRequest.new()
		h.accept_gzip = false
		h.download_chunk_size = 1 << 20
		_ld.add_child(h)
		_reqs.append(h)
		var ii := i
		h.request_completed.connect(func(res, code, _hd, body: PackedByteArray):
			if res != HTTPRequest.RESULT_SUCCESS or code != 200:
				_fail = true
				return
			_parts[ii] = body
			_pack_done())
		if h.request(base + "l/cc_%d.wasm?v=%s" % [i, CC_V]) != OK:
			_fail = true

func _pack_tick() -> void:
	if not is_instance_valid(_lab):
		return
	if _fail:
		_lab.text = "Tải bờ kênh bị lỗi mạng\nChạm để thử lại"
		return
	var got := 0
	for h in _reqs:
		if is_instance_valid(h):
			got += maxi(0, (h as HTTPRequest).get_downloaded_bytes())
	_lab.text = "Đang tải bờ kênh… %d%%" % clampi(int(100.0 * got / maxf(1.0, CC_SIZE)), 0, 99)

func _pack_done() -> void:
	for b in _parts:
		if b == null:
			return
	var all := PackedByteArray()
	for b in _parts:
		all.append_array(b)
	if all.size() != CC_SIZE:
		_fail = true
		return
	# xoá gói cũ (bản khác) cho đỡ chật máy
	var d := DirAccess.open("user://")
	if d != null:
		for f in d.get_files():
			if f.begins_with("cc_") and f.ends_with(".pck") and f != _pack_path().get_file():
				d.remove(f)
	var fo := FileAccess.open(_pack_path(), FileAccess.WRITE)
	if fo != null:
		fo.store_buffer(all)
		fo.close()
	_pack_free()
	if not _pack_load():
		push_warning("câu cá: không nạp được gói hình")
		return
	open()

func _pack_free() -> void:
	if is_instance_valid(_ld):
		_ld.queue_free()
	_ld = null
	_lab = null
	_parts = []
	_reqs = []
