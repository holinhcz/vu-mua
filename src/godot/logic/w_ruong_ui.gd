extends RefCounted
const Css = preload("res://ui/css.gd")
# Giao diện của hệ ruộng / cây ăn trái / hạn mặn, chép nội dung và nút từ bản web:
#   bảng "Hạn mặn" (eO dựng, U6 điền #manBody, rO đóng; nút data-man buy -> EZ, cong -> LZ, x -> rO),
#   nút viên "Hạn mặn · ..." trên HUD (CZ, .ghepill.manpill), thẻ trời "Hạn mặn" (ui({id:"man"}).sky / skyclick),
#   việc đi tới cây ăn trái (Px). Vòng nút khi chạm cây xài chung vòng nút ô ruộng: ui.gd rm_tree.
# Chưa có bản chụp số đo của web cho mấy bảng này: dựng bằng Control thường, cỡ chữ theo css px x (dpr x U).

var U                      # ui.gd
var G
var R                      # w_ruong.gd
var man: Control = null    # Hg
var _man_box: PanelContainer = null
var _man_body: VBoxContainer = null
var _man_sig := ""
var pill: Button = null    # Og (người ghép đặt chỗ trong hàng nút viên HUD)
var job: Callable = Callable()   # Px: xếp việc nhân vật đi tới cây (idx, "twater" | "tharvest"); trống thì làm ngay

func _init(ui, rules) -> void:
	U = ui
	G = ui.G
	R = rules
	R.ui = self

func _k() -> float:   # Css.K
	return float(U.dpr_v) * float(U.U)

func _lbl(s: String, px: float, bold := false, wrap := true) -> Label:   # <b>/<small>
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", int(round(px * _k())))
	l.add_theme_font_override("font", Css.font(800 if bold else 600))   # NTWEB: Nunito như cả giao diện
	if bold:
		l.add_theme_color_override("font_color", Color(0.17, 0.12, 0.08))
	else:
		l.add_theme_color_override("font_color", Color(0.35, 0.29, 0.23))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _rtl(bb: String, px: float) -> RichTextLabel:   # p.note
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", int(round(px * _k())))
	r.add_theme_font_size_override("bold_font_size", int(round(px * _k())))
	r.add_theme_color_override("default_color", Color(0.35, 0.29, 0.23))
	r.text = bb
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r

func _btn(s: String, primary: bool, disabled := false) -> Button:   # button.btn (.btn.primary .ppbig / .btn.ppng)
	var b := Button.new()
	b.text = s
	b.disabled = disabled
	b.add_theme_font_override("font", Css.font(700))
	b.add_theme_font_size_override("font_size", int(round((15.0 if primary else 14.0) * _k())))
	b.custom_minimum_size.y = (50.0 if primary else 44.0) * _k()
	var fg := Color(1, 1, 1) if primary else Color("#2b2a24")
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.55))
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#3a9a4a") if primary else Color("#ffffff")
		if st == "disabled":
			sb.bg_color = Color(sb.bg_color, 0.55)
		if st == "focus":
			sb.draw_center = false
		if not primary:
			sb.set_border_width_all(int(round(1.5 * _k())))
			sb.border_color = Color("#d8ccb2")
		sb.set_corner_radius_all(int(10 * _k()))
		sb.content_margin_left = 14 * _k()
		sb.content_margin_right = 14 * _k()
		sb.content_margin_top = 6 * _k()
		sb.content_margin_bottom = 6 * _k()
		b.add_theme_stylebox_override(st, sb)
	return b

func _box_style() -> StyleBoxFlat:   # .rbox / #pp
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fffcf2")
	sb.set_corner_radius_all(int(16 * _k()))
	sb.content_margin_left = 14 * _k()
	sb.content_margin_right = 14 * _k()
	sb.content_margin_top = 12 * _k()
	sb.content_margin_bottom = 12 * _k()
	return sb

# ------------------------------------------------------------------ bảng Hạn mặn
func open_man() -> void:   # eO
	if man != null:
		u6()
		return
	var t := Control.new()   # .raceov.pcov (role dialog, aria-label "Hạn mặn")
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_PASS
	t.add_child(dim)
	t.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_man()   # bấm ra ngoài hộp: rO
	)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(cc)
	var bx := PanelContainer.new()   # .rbox.pcbox.xbox
	bx.add_theme_stylebox_override("panel", _box_style())
	bx.custom_minimum_size = Vector2(minf(340.0 * _k(), U.get_viewport().get_visible_rect().size.x - 32.0 * _k()), 0)
	bx.mouse_filter = Control.MOUSE_FILTER_STOP
	cc.add_child(bx)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(8 * _k()))
	bx.add_child(v)
	var h := HBoxContainer.new()   # .ws-h
	h.add_child(_lbl("Hạn mặn", 17.0, true, false))
	var x := _btn("×", false)      # data-man="x"
	x.tooltip_text = "Đóng"
	x.pressed.connect(close_man)
	h.add_child(x)
	v.add_child(h)
	_man_body = VBoxContainer.new()   # #manBody
	_man_body.add_theme_constant_override("separation", int(8 * _k()))
	v.add_child(_man_body)
	_man_box = bx
	U.root.add_child(t)
	man = t
	_man_sig = ""
	u6()

func close_man() -> void:   # rO
	if man != null:
		man.queue_free()
		man = null
		_man_box = null
		_man_body = null

func u6() -> void:   # U6
	if man == null:
		return
	var t: Dictionary = R.b4()
	var a: bool = R.n4()
	var n := 0
	var e := 0
	var o: int = R.u7()
	for r in G.B0:
		if R.v6(r):
			n += 1
		if G.g.plots[r].u and R.yr(r):
			e += 1
	var l: int = R.ac()
	var cong: bool = true if t.get("cong", 0) else false
	var ngot := int(floor(float(t.ngot)))
	var f: bool = R.mc("lua_man")
	var sig := str([a, l, R.mz(), cong, e, ngot, o, int(G.g.coins) >= R.K6, int(G.g.coins) >= R.Q6, f, int(G.g.barn.get("lua_man", 0)), n])
	if sig == _man_sig:
		return
	_man_sig = sig
	for c in _man_body.get_children():
		c.queue_free()
	var p1: String
	if a:
		p1 = "[b]Nước mặn đang lấn vô sông Vàm[/b], còn chừng " + str(R.mz() + 1) + " ngày nữa mới rút."
	elif l > 0:
		p1 = "Chừng " + str(l) + " ngày nữa mặn lấn vô (mấy ngày cuối tháng, mùa khô)."
	else:
		p1 = "Sông đang ngọt."
	p1 += " Nước kênh mương dẫn vô ruộng bị mặn: cây lớn chậm còn " + ("60–85%" if cong else "35–55%") + " (ruộng càng gần sông càng nặng). Ô ruộng cách ao, hồ nước ngọt 2 ô trở lại thì không sao (" + str(e) + " ô của bạn)."
	_man_body.add_child(_rtl(p1, 12.5))   # p.note
	# ul.ws-rec
	var b1 := _btn("Mua 10 · " + str(R.K6) + " xu", true, int(G.g.coins) < R.K6 or float(t.ngot) >= o)   # data-man="buy"
	b1.pressed.connect(func() -> void: R.ez())
	_rec("nuoc_mia", "Lu nước ngọt · " + str(ngot) + "/" + str(o),
		"Tưới ô nhiễm mặn tốn 1 nước ngọt, cây lớn bình thường tới lúc đất khô. Trời mưa tự hứng đầy dần. Mỗi lu nước, chum sành đặt trong làng chứa thêm 10.", b1)
	var b2: Control
	if cong:
		b2 = _lbl("Đã xây", 12.0, false, false)   # span.note
	else:
		var bb := _btn("Xây · " + G.fmt_n(R.Q6) + " xu", false, int(G.g.coins) < R.Q6)   # data-man="cong"
		bb.pressed.connect(func() -> void: R.lz())
		b2 = bb
	_rec("muoi_hot", "Cống ngăn mặn",
		"Đã xây. Nước mặn vô ít, cây vẫn lớn được 60–85%." if cong else "Đắp cống đầu kênh chặn bớt nước mặn: cây lớn được 60–85% thay vì 35–55%.", b2)
	_rec("lua_man" if f else "lua", "Lúa chịu mặn",
		("Đã có giống. Gieo ruộng sát sông, mặn không ảnh hưởng. Kho có " + str(int(G.g.barn.get("lua_man", 0))) + " hạt.") if f else "Giống lai: trồng lúa sát bên cải xanh rồi gặt, thỉnh thoảng ra hạt lúa chịu mặn.", null)
	_rec("tom", "Mùa mặn tôm về", "Nước lợ tôm càng lên nhiều: thăm lờ, lọp, giăng câu dính tôm nhiều hơn.", null)
	_man_body.add_child(_rtl("Đang nhiễm mặn: " + str(n) + " ô ruộng.", 12.5))   # p.note

func _rec(ic: String, title: String, small: String, act) -> void:   # li.rec: Ai(ic) + <div><b>…</b><small>…</small></div> + nút
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(8 * _k()))
	var tx = U.item_ic(ic, 34.0 * _k())
	if tx != null:
		var im := TextureRect.new()
		im.texture = tx
		im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		im.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		im.custom_minimum_size = Vector2(34, 34) * _k()
		h.add_child(im)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_lbl(title, 13.5, true))
	v.add_child(_lbl(small, 11.5))
	h.add_child(v)
	if act != null:
		(act as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(act)
	_man_body.add_child(h)

# ------------------------------------------------------------------ nút viên HUD
func cz() -> void:   # CZ
	var t: bool = R.n4()
	if pill == null:
		if not t:
			return
		pill = Button.new()   # button.ghepill.manpill
		pill.add_theme_font_size_override("font_size", int(round(12.0 * _k())))
		pill.pressed.connect(open_man)   # eO
		U.root.add_child(pill)
	pill.visible = t and R._mode() == "off"
	if t:
		var a: int = R.man_n()
		pill.text = "Hạn mặn · " + ((str(a) + " ô nhiễm mặn") if a else "ruộng đang ổn") + " · lu còn " + str(int(floor(float(R.b4().ngot)))) + " nước ngọt"

# ------------------------------------------------------------------ thẻ trời (ui "man": sky / skyclick)
func sky_card() -> Dictionary:   # {} = không hiện; got = đang mặn (div.tt.got)
	var t: bool = R.n4()
	var a: int = R.ac()
	if not t and (a < 0 or a > 4):
		return {}
	return {"key": "man", "got": t, "b": "Hạn mặn",
		"small": "Nước mặn đang lấn vô sông, ruộng chậm lớn." if t else "Chừng " + str(a) + " ngày nữa mặn lấn vô sông Vàm. Trữ nước ngọt sẵn.",
		"btn": "Xem"}

func sky_click(t: String) -> void:   # skyclick: $f() đóng các bảng rồi eO()
	if t == "man":
		U.close_all()
		open_man()

# ------------------------------------------------------------------ cây ăn trái
func px(t: int, a: String) -> void:   # Px: việc đi tới cây ("twater" | "tharvest")
	if job.is_valid():
		job.call(t, a)
	else:
		R.tree_run(t, a)
