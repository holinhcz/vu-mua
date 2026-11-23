extends RefCounted
# (bản 533) GÓI HÌNH MINI GAME (Cờ caro, Cờ gánh, Ô ăn quan, Tìm số: ui/img/caro, cg, oq, tso ~16 MB) KHÔNG nằm trong gói vườn
# (mở làng đỡ tải ~16 MB): lần đầu bấm vào 1 trong 4 game thì tải l/mg_<i>.wasm (tools/mk_mgpack.py), ghi thẳng từng miếng
# ra file, ghép lại thành user://mg_<MG_V>.pck, ProjectSettings.load_resource_pack() -> res://ui/img/caro/... đọc như thường.
# Lần sau mở máy: đọc file đã lưu, khỏi tải. Gói vườn nào còn chứa sẵn hình (bản build khác) thì khỏi tải luôn.
#   MG.need(ui, cb): hình có rồi -> cb() liền; chưa -> hiện "Đang tải trò chơi… N%", tải xong mới cb().

const MG_V := "c6f2e0cb"       # crc gói (mk_mgpack.py điền)
const MG_N := 2        # số miếng l/mg_<i>.wasm
const MG_SIZE := 16417364     # tổng số byte
const PROBE := "res://ui/img/caro/board.webp"
static var _ok := false
static var _ld: CanvasLayer = null
static var _lab: Label = null
static var _reqs := []
static var _done := []
static var _fail := false
static var _cb := Callable()
static var _ui = null

static func ready() -> bool:
	if not _ok and FileAccess.file_exists(PROBE):
		_ok = true
	return _ok

static func need(ui, cb: Callable) -> void:
	if ready():
		cb.call()
		return
	_ui = ui
	_cb = cb
	if _load():
		_fin()
		return
	if is_instance_valid(_ld):
		return
	_start()

static func _path() -> String:
	return "user://mg_" + MG_V + ".pck"

static func _part(i: int) -> String:
	return "user://mg_part_%d.tmp" % i

static func _fsize(p: String) -> int:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return 0
	var n := f.get_length()
	f.close()
	return n

static func _load() -> bool:
	if MG_N <= 0 or _fsize(_path()) != MG_SIZE:
		return false
	_ok = ProjectSettings.load_resource_pack(_path(), true)
	return _ok

static func _fin() -> void:
	_free()
	if _cb.is_valid():
		var c := _cb
		_cb = Callable()
		c.call()

static func _start() -> void:
	var tree: SceneTree = _ui.get_tree()
	var k := float(_ui.dpr_v)
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
	_lab.text = "Đang tải trò chơi… 0%"
	bg.add_child(_lab)
	# lỗi mạng: chạm để thử lại; còn đang tải mà chạm thì thôi (đóng, lần sau bấm lại tải tiếp từ đầu)
	bg.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			if _fail:
				_free()
				_start()
			else:
				_cb = Callable()
				_free())
	tree.root.add_child(_ld)
	var tm := Timer.new()
	tm.wait_time = .2
	tm.autostart = true
	tm.timeout.connect(_tick)
	_ld.add_child(tm)
	_fail = false
	_reqs = []
	_done = []
	var base := str(_ui.main.base_url) if _ui.main != null and "base_url" in _ui.main else ""
	for i in MG_N:
		_done.append(false)
		var h := HTTPRequest.new()
		h.accept_gzip = false
		h.download_chunk_size = 1 << 20
		h.download_file = _part(i)   # ghi thẳng ra file, khỏi giữ cả gói trong RAM
		_ld.add_child(h)
		_reqs.append(h)
		var ii := i
		h.request_completed.connect(func(res, code, _hd, _body):
			if res != HTTPRequest.RESULT_SUCCESS or code != 200:
				_fail = true
				return
			_done[ii] = true
			_join())
		if h.request(base + "l/mg_%d.wasm?v=%s" % [i, MG_V]) != OK:
			_fail = true

static func _tick() -> void:
	if not is_instance_valid(_lab):
		return
	if _fail:
		_lab.text = "Tải trò chơi bị lỗi mạng\nChạm để thử lại"
		return
	var got := 0
	for h in _reqs:
		if is_instance_valid(h):
			got += maxi(0, (h as HTTPRequest).get_downloaded_bytes())
	_lab.text = "Đang tải trò chơi… %d%%" % clampi(int(100.0 * got / maxf(1.0, MG_SIZE)), 0, 99)

static func _join() -> void:
	for d in _done:
		if not d:
			return
	var tot := 0
	for i in MG_N:
		tot += _fsize(_part(i))
	if tot != MG_SIZE:
		_fail = true
		return
	var d := DirAccess.open("user://")   # bỏ gói cũ (bản khác) cho đỡ chật máy
	if d != null:
		for f in d.get_files():
			if f.begins_with("mg_") and f.ends_with(".pck") and f != _path().get_file():
				d.remove(f)
	var fo := FileAccess.open(_path(), FileAccess.WRITE)
	if fo != null:   # ghép từng miếng, đọc 1 MB một lần
		for i in MG_N:
			var fi := FileAccess.open(_part(i), FileAccess.READ)
			if fi == null:
				continue
			while fi.get_position() < fi.get_length():
				fo.store_buffer(fi.get_buffer(1 << 20))
			fi.close()
			DirAccess.remove_absolute(_part(i))
		fo.close()
	if not _load():
		_fail = true
		push_warning("mini game: không nạp được gói hình")
		return
	_fin()

static func _free() -> void:
	if is_instance_valid(_ld):
		_ld.queue_free()
	_ld = null
	_lab = null
	_reqs = []
	_done = []
