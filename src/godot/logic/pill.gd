extends Control
# (bản 362) THẺ VIỆC BÊN MÉP TRÁI HUD: một form chung cho mọi dòng trong cột "việc đang chờ" (w_all.pills): mục tiêu tân thủ,
# lễ hội, thiên tai, rầy, hạn mặn, chợ nổi, ghe... Dựng từ thẻ mục tiêu #goal của hud.json (khung kem, viền trong), thêm:
#   - hình nhỏ bên trái (ic: đường ảnh res://... hoặc "kh:<món>"), vạch màu theo loại (kind) ở mép trái;
#   - dòng 1: tên việc (phần chữ trước " · " đầu tiên), dòng 2 chữ nhỏ: phần còn lại (hạn, việc cần làm) hoặc thanh tiến độ (bar >= 0).
# kind: "khan" (gấp: nạn, rầy, mặn) > "le" (lễ hội, hội đình) > "su" (chợ nổi, ghe) > "nv" (mục tiêu) > "more" (+N việc khác).
# text / hurry giữ như nút viên cũ (các nơi gọi không đổi); hurry: nhịp nhẹ.

const Snap = preload("res://ui/snap.gd")
const Box = preload("res://ui/box.gd")
const Css = preload("res://ui/css.gd")

signal pressed

const KC := {"khan": "rgb(214, 84, 52)", "le": "rgb(222, 160, 40)", "su": "rgb(52, 132, 200)", "nv": "rgb(46, 150, 80)", "more": "rgb(156, 122, 54)"}
const KO := {"khan": 0, "le": 1, "su": 2, "nv": 3, "more": 9}
const KI := {"khan": "res://ui/img/bong/gap.png", "le": "kh:long_den", "su": "res://ui/img/ghe/ghe_v.webp", "nv": "res://ui/img/bong/sao.png"}

var U
var box: Control = null
var _t := ""
var _h := false
var _k := ""
var _ic := ""
var _bar := -1.0
var _ph := 0.0
var _full := Vector2.ZERO
var _up_ms := 0

var text: String:
	get:
		return _t
	set(v):
		if v != _t:
			_t = v
			_make()

var hurry: bool:
	get:
		return _h
	set(v):
		if v != _h:
			_h = v
			_make()

var kind: String:   # "" = theo hurry (gấp thì khan, không thì su)
	get:
		return _k if _k != "" else ("khan" if _h else "su")
	set(v):
		if v != _k:
			_k = v
			_make()

var ic: String:   # "" = hình tạm theo loại
	get:
		return _ic
	set(v):
		if v != _ic:
			_ic = v
			_make()

var bar: float:   # 0..1: dòng 2 là thanh tiến độ; < 0: dòng 2 là chữ
	get:
		return _bar
	set(v):
		if absf(v - _bar) > 0.001:
			_bar = v
			_make()

var _cut := false
var cut: bool:   # (cột việc quá 3 dòng) ẩn sau "+N việc khác": không chiếm chỗ, không bấm được
	get:
		return _cut
	set(v):
		if v != _cut:
			_cut = v
			_fit_cut()

func _fit_cut() -> void:
	if box != null:
		box.visible = not _cut
	mouse_filter = Control.MOUSE_FILTER_IGNORE if _cut else Control.MOUSE_FILTER_STOP
	if _cut:
		custom_minimum_size = Vector2.ZERO
		size = Vector2.ZERO
	elif box != null:
		custom_minimum_size = _full
		size = _full

func order() -> int:
	return int(KO.get(kind, 5))

func _init(ui) -> void:
	U = ui
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	_make()

static func _fit(s: String, fs: float, fw: int, W0: float) -> String:
	if Box.text_w(s, fs, fw) <= W0:
		return s
	while s.length() > 1 and Box.text_w(s + "…", fs, fw) > W0:
		s = s.substr(0, s.length() - 1)
	return s.strip_edges() + "…"

func _make() -> void:
	if U == null or not is_inside_tree():
		return
	var gb = U.hid.get("#goal")
	if gb == null:
		return
	var n: Dictionary = (gb.get_meta("snap", {}) as Dictionary).duplicate(true)
	if n.is_empty():
		return
	n.erase("id")
	Snap._move(n, Vector2(-float(n.r[0]), -float(n.r[1])))
	var z := float(n.get("z", 1.0))
	var W := float(n.r[2])
	var H := float(n.r[3])
	var k := kind
	var gl: Dictionary = n.kids[0]
	var tb: Dictionary = n.kids[1]
	var tt: Dictionary = gl.kids[0]
	tt.erase("id")
	tb.kids[0].erase("id")
	var x0 := 33.0 if k != "more" else 12.0
	var tw := W - x0 - 9.0
	var parts := _t.split(" · ", false)
	var t1: String = parts[0] if parts.size() else ""
	var t2: String = " · ".join(parts.slice(1)) if parts.size() > 1 else ""
	var fs1 := Css.px(String(tt.css.get("font-size", "13px"))) * z
	var fw1 := int(String(tt.css.get("font-weight", "700")))
	var cnt := ""   # thanh tiến độ: "(1/3)" cuối tên dời xuống cạnh thanh
	if _bar >= 0.0:
		var m := RegEx.create_from_string("\\s*\\((\\d+/\\d+)\\)$").search(t1)
		if m != null:
			cnt = m.get_string(1)
			t1 = t1.substr(0, m.get_start())
	var two := t2 != "" or _bar >= 0.0
	var y1 := 6.0 if two else (H - float(tt.r[3])) * 0.5
	tt.text = _fit(t1, fs1, fw1, tw)
	tt.r = [x0, y1, tw, float(tt.r[3])]
	tt.erase("tr")
	gl.r = [x0, y1, tw, float(gl.r[3])]
	var kids := [gl]
	if _bar >= 0.0:
		var c3: Dictionary = tt.css.duplicate()
		c3["font-size"] = "10.5px"
		c3["font-weight"] = "800"
		c3["color"] = "rgb(128, 98, 58)"
		c3["line-height"] = "13px"
		var cw := Box.text_w(cnt, 10.5 * z, 800) if cnt != "" else 0.0
		var bw := tw - (cw + 5.0 if cnt != "" else 0.0)
		tb.r = [x0, 24.5, bw, float(tb.r[3])]
		var bi: Dictionary = tb.kids[0]
		bi.r = [x0, 24.5, bw * clampf(_bar, 0.0, 1.0), float(bi.r[3])]
		kids.append(tb)
		if cnt != "":
			kids.append({"tag": "span", "id": "", "cls": "", "z": z, "css": c3, "r": [x0 + tw - cw, 21.0, cw + 1.0, 10.0], "text": cnt, "kids": []})
	elif t2 != "":
		var c2: Dictionary = tt.css.duplicate()
		c2["font-size"] = "11px"
		c2["font-weight"] = "600"
		c2["color"] = "rgb(214, 84, 52)" if k == "khan" else "rgb(128, 98, 58)"
		c2["line-height"] = "14px"
		var fs2 := 11.0 * z
		kids.append({"tag": "span", "id": "", "cls": "", "z": z, "css": c2, "r": [x0, 20.5, tw, 10.5], "text": _fit(t2, fs2, 600, tw), "kids": []})
	# vạch màu theo loại ở mép trái
	kids.append({"tag": "i", "id": "", "cls": "", "z": z, "css": {"background-color": String(KC.get(k, KC.su)), "border-radius": "3px", "position": "absolute"}, "r": [4.2, 7.0, 2.6, H - 14.0], "kids": []})
	n.kids = kids
	if box != null:
		box.queue_free()
	box = U._build(n, {})
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var src := _ic if _ic != "" else String(KI.get(k, ""))
	if src != "":
		var K := Css.K
		var s := 20.0
		var tex: Texture2D = U.item_ic(src.substr(3), s * K) if src.begins_with("kh:") else Css.image(src)
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.position = Vector2(9.5, (H - s) * 0.5) * K
			tr.size = Vector2(s, s) * K
			box.add_child(tr)
	_full = Vector2(W, H) * Css.K
	custom_minimum_size = _full
	size = _full
	_fit_cut()

func _process(dt: float) -> void:   # hurry: thẻ nhịp nhẹ
	if _h and not _cut and is_visible_in_tree():
		_ph += dt
		pivot_offset = size * 0.5
		scale = Vector2.ONE * (1.0 + 0.02 * sin(_ph * 5.0))
	elif scale != Vector2.ONE:
		scale = Vector2.ONE

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT)) and not e.pressed:
		accept_event()
		var now := Time.get_ticks_msec()
		if now - _up_ms > 250:   # chạm trên điện thoại ra cả touch lẫn chuột giả: chỉ tính một lần
			_up_ms = now
			pressed.emit()
	elif e is InputEventScreenTouch or e is InputEventMouseButton:
		accept_event()
