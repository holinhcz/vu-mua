extends RefCounted
# HỤI, LỄ HỘI (giao diện): phần bảng bản web còn thiếu ở bản Godot. Luật ở w_htx.gd.
#  - x6 / x4: bảng "Hụi làng" (.raceov.pcov .rbox.pcbox.xbox, #huiBody): ghi chú, dây đang chơi (.tt.got) + nút "Hốt hụi",
#    dây đã mãn / bể + "Chơi dây mới", hoặc chọn mức góp (.vl-jobs, aria-pressed = wS) và chủ hụi (♥, nguy cơ bể, "Vô hụi");
#    "Sổ hụi" (ul.kh-gb). MS: đóng.
#  - QT: bảng lễ hội ($r.mode === "hoi": #vlName = tên lễ, #vlBody): ghi chú, danh sách lễ vật (.ws-rec li.rec + .tbar, nút Góp),
#    nút "Nhận lộc lễ hội" (data-fest = claim). Dựng lại khi chữ ký $r.sig đổi (JSON [h4, số trong kho, ngày còn]).
#  - bQ: nút viên lễ hội (.ghepill.festpill, .hurry), chạm -> gu("hoi") = open_fest().
# Dựng bằng Control thường của Godot như w_cho_ui.gd; chỉ dựng lại khi đổi, không vẽ mỗi khung.

const Css = preload("res://ui/css.gd")
const VNV = preload("res://logic/vatnuoi.gd")   # CC = eT (♥♡)

var U          # ui.gd
var G          # game.gd
var W          # w_htx.gd
# ext: việc của hệ khác (bộ ráp gán)
#   Ai(id) -> Texture2D    (thiếu thì U.item_ic)
var ext := {}

var hui: Control = null     # Ih
var w_s := 1                # wS: mức góp đang chọn
var fest: Control = null    # bảng lễ hội ($r.mode === "hoi")
var fest_sig := ""          # $r.sig
var pill: Button = null     # k2

func _init(ui, wh) -> void:
	U = ui
	G = ui.G
	W = wh
	W.ui = self
	W.render.connect(_on_render)

func _x(k: String) -> Callable:
	var c = ext.get(k)
	return c if c is Callable and (c as Callable).is_valid() else Callable()

static func _k(v: float) -> float:
	return v * Css.K

func _on_render() -> void:   # kn / x4
	if hui != null:
		x4()
	if fest != null:
		sync_fest()

# ------------------------------------------------------------------ khối dựng chung (như w_sys_ui.gd)
func _panel(title: String, on_close: Callable) -> Array:   # .raceov.pcov > .rbox.pcbox: [gốc, thân, nhãn tên]
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if U._is_tap_down(e):
			on_close.call())
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
	var hd := HBoxContainer.new()
	var b := _lbl(title, 17, 800, Color8(0x3a, 0x2a, 0x1a))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(b)
	hd.add_child(_btn("×", false, true, on_close))
	col.add_child(hd)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, minf(U.vsize().y * 0.7, 560.0) * Css.K)
	col.add_child(sc)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(_k(6)))
	sc.add_child(body)
	U.root.add_child(ov)
	ov.set_meta("body", body)
	ov.set_meta("name", b)
	return [ov, body, b]

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
	b.pressed.connect(cb)
	return b

func _ic(id: String, px: float) -> TextureRect:   # Ai(id)
	var t := TextureRect.new()
	var f := _x("Ai")
	t.texture = f.call(id) if f.is_valid() else U.item_ic(id, _k(px))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(_k(px), _k(px))
	return t

func _sec(b: String, small: String) -> Control:   # .vl-sec: <b> + <small>
	var v := VBoxContainer.new()
	v.add_child(_lbl(b, 14, 800, Color8(0x3a, 0x2a, 0x1a)))
	if small != "":
		v.add_child(_lbl(small, 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
	return v

func _note(b: String, rest: String) -> Control:   # p.note (<b> đầu dòng + chữ thường)
	var v := VBoxContainer.new()
	if b != "":
		v.add_child(_lbl(b, 12, 700, Color8(0x5a, 0x4a, 0x3a)))
	if rest != "":
		v.add_child(_lbl(rest, 12, 400, Color8(0x8a, 0x7a, 0x6a)))
	return v

func _tt(b: String, small: String, btn: Button = null, got := false) -> Control:   # .tt (.got): <div><b><small></div> [nút]
	var h := HBoxContainer.new()
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_lbl(b, 13.5, 700, Color8(0x2f, 0x7a, 0x2a) if got else Color8(0x3a, 0x2a, 0x1a)))
	v.add_child(_lbl(small, 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
	h.add_child(v)
	if btn != null:
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(btn)
	return h

func _jobs(btns: Array) -> Control:   # .vl-jobs
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", int(_k(6)))
	f.add_theme_constant_override("v_separation", int(_k(6)))
	for b in btns:
		f.add_child(b)
	return f

func _bar(r: float) -> Control:   # .tbar > i (width %)
	var p := ProgressBar.new()
	p.min_value = 0
	p.max_value = 100
	p.value = r
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, _k(6))
	return p

static func _clear(n: Control) -> void:
	for c in n.get_children():
		c.queue_free()

# ------------------------------------------------------------------ bảng hụi (x6, x4, MS)
func x6() -> void:   # x6
	if hui != null:
		x4()
		return
	var p := _panel("Hụi làng", ms)
	hui = p[0]
	x4()

func ms() -> void:   # MS
	if hui != null:
		hui.queue_free()
		hui = null

func _hot() -> void:   # data-hui="hot"
	W.jk()

func _new() -> void:   # data-hui="new"
	W.hui_new()
	x4()

func _pick_c(p: int) -> void:   # data-huic
	w_s = p
	x4()

func _vo(h: String) -> void:   # data-huiu
	W.mk(h, int(W.u_n()[w_s]))

func x4() -> void:   # x4: nội dung #huiBody
	if hui == null:
		return
	var t: VBoxContainer = hui.get_meta("body")
	_clear(t)
	var a = G.g.get("hui")
	t.add_child(_note("", "Dây hụi 6 phần: bạn và 5 nhà trong xóm. Cứ 12 tiếng là một kỳ, ai cũng góp một phần. Mỗi kỳ được bỏ thăm hốt một lần: hốt sớm có tiền xài liền mà chịu lãi, hốt chót được lời. Chủ hụi càng thân (♥) càng ít sợ bể hụi."))
	if W._tr(a) and not W._tr(a.get("done")):
		var e: int = W.y6()
		var r: float = W._vr() * 24 + W._d0()
		var o: float = (float(a.k0) + float(a.paid)) * W.VN - r
		var l: int = W.vk(maxi(1, e), float(a.c))
		var c := float(a.c)
		var no: float = W._n(a.get("no"))
		t.add_child(_tt("Hụi của " + String(a.n) + " · mỗi phần " + W._sa(c) + " xu",
			"Kỳ " + str(e) + "/" + str(W._D) + " · đã góp " + W._sa(float(a.paid) * c) + " xu" + (" · nợ " + W._sa(no) if no else "") + " · kỳ tới sau " + str(maxi(0, int(floor(o)))) + " giờ " + str(maxi(0, W._rnd(fmod(o, 1.0) * 60))) + " phút · nguy cơ bể hụi " + W._ns(W._rnd(float(W.WL.k_s(a.u)) * 1e3) / 10.0) + "% mỗi kỳ", null, true))
		if W._tr(a.get("hot")):
			t.add_child(_note("", "Bạn đã hốt kỳ " + str(a.hot) + ", nhận " + W._sa(a.got) + " xu. Tiếp tục góp tới mãn hụi nha."))
		else:
			t.add_child(_tt("Hốt hụi kỳ này: " + W._sa(l - no) + " xu", "Hốt chót (kỳ 6) được " + W._sa(W.vk(W._D, c)) + " xu. Tổng góp cả dây: " + W._sa(W._D * c) + " xu.", _btn("Hốt hụi", true, true, _hot)))
	elif W._tr(a) and W._tr(a.get("done")):
		var pd := float(a.paid) * float(a.c)
		var gt: float = W._n(a.get("got"))
		t.add_child(_tt(("Dây hụi " + String(a.n) + " đã bể") if W._tr(a.get("be")) else ("Dây hụi " + String(a.n) + " đã mãn"),
			"Góp " + W._sa(pd) + " xu, nhận " + W._sa(gt) + " xu (" + ("lời " if gt - pd >= 0 else "lỗ ") + W._sa(absf(gt - pd)) + " xu).",
			_btn("Chơi dây mới", false, true, _new), not W._tr(a.get("be"))))
	else:
		var c = W._lang()
		var f: Array = W._okeys(c.fam) if c != null and W._tr(c.get("fam")) else []
		if f.size() < 1:
			t.add_child(_note("", "Xóm chưa có ai ở để rủ chơi hụi. Xây nhà cho dân về ở trước đã."))
		else:
			var s: Array = W.u_n()
			t.add_child(_sec("Mức góp mỗi kỳ", ""))
			var bs := []
			for p in s.size():
				var pi: int = p
				var b := _btn(W._sa(s[p]) + " xu", false, true, func(): _pick_c(pi))
				b.toggle_mode = true
				b.button_pressed = w_s == p   # aria-pressed
				bs.append(b)
			t.add_child(_jobs(bs))
			t.add_child(_sec("Chọn chủ hụi", "Thân càng nhiều ♥ càng đáng tin."))
			W._stable_sort(f, func(h, p): return int(W._n(c.fam[p].get("tim")) - W._n(c.fam[h].get("tim"))))
			for h in f:
				var p: Dictionary = c.fam[h]
				var hk: String = h
				t.add_child(_tt(String(p.n) + " " + VNV.hearts(W._n(p.get("tim"))), "Nguy cơ bể hụi " + W._ns(W._rnd(float(W.WL.k_s(h)) * 1e3) / 10.0) + "% mỗi kỳ", _btn("Vô hụi", true, true, func(): _vo(hk))))
	if W._tr(a) and W._tr(a.get("log")) and a.log.size():
		t.add_child(_sec("Sổ hụi", ""))
		for h in a.log:
			t.add_child(_lbl("• " + String(h), 12, 500, Color8(0x5a, 0x4a, 0x3a)))

# ------------------------------------------------------------------ bảng lễ hội (gu("hoi") -> QT)
func open_fest() -> void:   # gu("hoi")
	close_fest()
	U.close_all()
	fest_sig = ""
	var p := _panel("", close_fest)
	fest = p[0]
	sync_fest()

func close_fest() -> void:   # i1
	if fest != null:
		fest.queue_free()
		fest = null

func sync_fest() -> void:   # QT (gọi mỗi khung khi bảng mở; chỉ dựng lại khi chữ ký đổi)
	if fest == null:
		return
	var t = W.h4()
	if t == null:
		close_fest()   # i1()
		return
	var a: Dictionary = W.tm(t)
	var n: int = int(t.d) - W._vr()
	var have := []
	for o in t.need:
		have.append(W._barn(o[0]))
	var r := JSON.stringify([t, have, n])
	if r == fest_sig:
		return
	fest_sig = r
	(fest.get_meta("name") as Label).text = String(a.n)
	var bd: VBoxContainer = fest.get_meta("body")
	_clear(bd)
	bd.add_child(_note(("Còn " + str(n) + " ngày nữa là tới " + String(a.sh) + ".") if n > 0 else ("Hôm nay là " + String(a.sh) + "!"),
		String(a.d) + " Bà con nhờ góp lễ vật để " + String(a.why) + ". Đủ lễ thì tới ngày hội cả làng nhận lộc."))
	if W._tr(t.get("done")):
		if n > 0:
			bd.add_child(_note("Đã đủ lễ vật.", "Tới ngày hội ghé lại nhận lộc: " + W._sa(W.d_t()) + " xu, gạch nung, nhà nào cũng thân thêm 1 ♥ và cây lớn nhanh suốt ngày hội."))
		elif W._tr(t.get("claim")):
			bd.add_child(_note("", "Đã nhận lộc. Chúc làng mình một mùa an lành, mưa thuận gió hòa!"))
		else:
			bd.add_child(_jobs([_btn("Nhận lộc lễ hội · " + W._sa(W.d_t()) + " xu", true, true, func(): W.v_t())]))
	else:
		for o in t.need:
			var id: String = o[0]
			var q: int = int(o[1])
			var l: int = W._i(t.got.get(id))
			var c := q - l
			var f: int = W._barn(id)
			var s := c <= 0
			var h := HBoxContainer.new()   # li.rec
			h.add_theme_constant_override("separation", int(_k(8)))
			h.add_child(_ic(id, 36))
			var v := VBoxContainer.new()
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(_lbl(W._ho(id, q), 13.5, 700, Color8(0x3a, 0x2a, 0x1a)))
			v.add_child(_lbl("Đã góp " + str(l) + "/" + str(q) + (" · đủ" if s else ""), 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
			v.add_child(_bar(W._rnd(minf(1.0, float(l) / q) * 100)))
			h.add_child(v)
			var b := _btn("Đủ" if s else "Góp " + str(mini(c, f)), true, not (s or f <= 0), func(): W.j_t(id))
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(b)
			bd.add_child(h)
		if n == 0:
			bd.add_child(_note("", "Hôm nay là ngày hội rồi, góp cho đủ trước nửa đêm vẫn kịp nhận lộc."))

# ------------------------------------------------------------------ nút viên lễ hội (bQ)
func pill_sync(parent: Control) -> void:   # bQ (gọi mỗi khung hoặc mỗi giây; parent = Hs(): hàng nút viên trên HUD)
	var d: Dictionary = W.fest_pill()
	if d.is_empty():
		if pill != null:
			pill.visible = false
		return
	if pill == null:
		pill = _btn("", false, true, open_fest)
		parent.add_child(pill)
	pill.visible = true
	if pill.text != String(d.text):
		pill.text = String(d.text)
	pill.modulate = Color(1, 0.85, 0.8) if d.hurry else Color.WHITE   # .hurry
