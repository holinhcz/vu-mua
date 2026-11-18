extends RefCounted
# KHUNG CHUNG các bảng dựng bằng khối Godot (bản 287): hợp tác xã / lễ hội (w_htx_ui), hệ thống (w_sys_ui), chợ nổi / ghe /
# radio (w_cho_ui), câu cá (w_ca_ui). Trước mỗi file tự chép một bộ hàm y hệt nhau (_panel, _lbl, _btn, _ic, _x, _k);
# giờ chung một chỗ. Thân bảng cuộn bằng vscroll.gd như Kho (không dùng ScrollContainer nữa).
const Css = preload("res://ui/css.gd")
const VScroll = preload("res://logic/vscroll.gd")
const Qty = preload("res://logic/qty.gd")

var U          # ui.gd
var G          # game.gd
var ext := {}

func _x(k: String) -> Callable:
	var c = ext.get(k)
	return c if c is Callable and (c as Callable).is_valid() else Callable()

static func _k(v: float) -> float:
	return v * Css.K

func _lbl(s: String, fs: float, w: int, col: Color, wrap := true) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", Css.font(w))
	l.add_theme_font_size_override("font_size", int(_k(fs)))
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _btn(s: String, primary: bool, on: bool, cb: Callable) -> Button:   # .btn / .btn.primary (disabled khi !on)
	var b := Button.new()
	b.text = s
	b.disabled = not on
	b.add_theme_font_override("font", Css.font(700))
	b.add_theme_font_size_override("font_size", int(_k(14)))
	_btn_style(b, primary)
	if cb.is_valid():
		b.pressed.connect(func():
			if U.scroll_moved():
				return   # vừa kéo cuộn thân bảng, không phải bấm
			cb.call())
	return b

func _btn_style(b: Button, primary: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(0x3f, 0x9a, 0x3a) if primary else Color8(0xff, 0xff, 0xff)
	sb.border_color = Color8(0x2f, 0x7a, 0x2a) if primary else Color8(0xd8, 0xc8, 0xa8)
	sb.set_border_width_all(int(maxf(1.0, _k(1.5))))
	sb.set_corner_radius_all(int(_k(10)))
	sb.content_margin_left = _k(12)
	sb.content_margin_right = _k(12)
	sb.content_margin_top = _k(6)
	sb.content_margin_bottom = _k(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	var sd := sb.duplicate()
	sd.bg_color = sd.bg_color.lerp(Color(0.85, 0.85, 0.85), 0.55)
	b.add_theme_stylebox_override("disabled", sd)
	b.add_theme_color_override("font_color", Color.WHITE if primary else Color8(0x3a, 0x2a, 0x1a))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.7) if primary else Color8(0xa0, 0x90, 0x80))

func _ic(id: String, px: float) -> TextureRect:   # Ai(id): hình món
	var t := TextureRect.new()
	var f := _x("Ai")
	t.texture = f.call(id) if f.is_valid() else U.item_ic(id, _k(px))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(_k(px), _k(px))
	return t

func _coin(px: float) -> TextureRect:   # hình xu chung (ui/img/coin.webp)
	var t := TextureRect.new()
	t.texture = Css.svg_tex(Css.img_svg("res://ui/img/coin.webp"), _k(px), _k(px))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(_k(px), _k(px))
	return t

func _panel(title: String, on_close: Callable) -> Array:   # .raceov.pcov > .rbox.pcbox: [gốc, thân, nhãn tên]
	# meta: body (thân), name (nhãn tên), top (chỗ cố định trên đầu thân), sc (cuộn thân)
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	U.tap_close(dim, on_close)
	ov.add_child(dim)
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(0xff, 0xfa, 0xf0)
	sb.set_corner_radius_all(int(_k(18)))
	sb.content_margin_left = _k(14)
	sb.content_margin_right = _k(14)
	sb.content_margin_top = _k(12)
	sb.content_margin_bottom = _k(14)
	box.add_theme_stylebox_override("panel", sb)
	box.custom_minimum_size = Vector2(minf(U.vsize().x - 32.0, 420.0), 0) * Css.K
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(box)
	ov.add_child(cc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(_k(8)))
	box.add_child(col)
	var hd := HBoxContainer.new()   # .ws-h: <b>tên</b> + nút ×
	var b := _lbl(title, 17, 800, Color8(0x3a, 0x2a, 0x1a))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(b)
	hd.add_child(_btn("×", false, true, on_close))
	col.add_child(hd)
	var top := VBoxContainer.new()   # chỗ cho phần cố định trên đầu (htSum)
	col.add_child(top)
	# thân cuộn: khung cắt (view) + thân (body) dời lên xuống bằng vscroll.gd
	var view := Control.new()
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_PASS
	var vh := minf(U.vsize().y * 0.7, 560.0) * Css.K
	view.custom_minimum_size = Vector2(0, vh)
	col.add_child(view)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", int(_k(6)))
	view.add_child(body)
	var vs = VScroll.new()
	vs.area = view
	vs.mover = func(v):
		body.position.y = -v * Css.K
	var fit := func():   # thân theo bề ngang khung, khung thấp lại khi thân ngắn
		body.size.x = view.size.x
		body.size.y = 0
		var h: float = body.get_combined_minimum_size().y
		view.custom_minimum_size.y = minf(vh, h)
		vs.hmax = maxf(0.0, (h - view.size.y) / Css.K)
		vs.to(vs.s)
	view.resized.connect(fit)
	body.minimum_size_changed.connect(fit)
	U.scroll_add(vs)
	U.root.add_child(ov)
	ov.set_meta("top", top)
	ov.set_meta("body", body)
	ov.set_meta("name", b)
	ov.set_meta("sc", vs)
	return [ov, body, b]
