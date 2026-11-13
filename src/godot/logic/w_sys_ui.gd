extends RefCounted
# HỆ THỐNG (giao diện): phần bảng bản web còn thiếu ở bản Godot. Luật ở w_sys.gd.
#  - Bảng Hệ Thống (#sysCard): htSum (3 ô tóm tắt làm tab), htRender (tab nv / pt / shop), htTabNv, htTabPt, htTabShop,
#    htClick; trong tab Cửa hàng có Túi đặc sản (DH, .sysx) và "Xe hàng" (#sysShop: BX phần XO).
#  - Thẻ địa điểm trên bản đồ (#placeCard): NX + VH (Chở hàng đi bán, dùng đặc sản), review (tH, #revGo -> N7),
#    các nút miền O7 (chọn miền gọi ext IX của bản đồ).
#  - Bảng chở hàng (OH: .raceov.pcov .cgbox), dòng chuyến đi #trip (BX phần trip + BJ "Tới ngay").
#  - Danh sách nâng cấp #ups (dòng Z9), thẻ "Lần đầu gặp" (XZ), hộp Cô Ba (ZY / SF).
# Dựng bằng Control thường của Godot như w_cho_ui.gd; chỉ dựng lại khi chữ ký đổi (aL, l8, nL như web), không vẽ mỗi khung.

const Css = preload("res://ui/css.gd")

var U          # ui.gd
var G          # game.gd
var W          # w_sys.gd
# ext: việc của hệ khác (bộ ráp gán)
#   IX(r: String)          (IX: bản đồ phóng tới miền r)
#   ZC(g: String)          (ZC: mở Sổ tay hướng dẫn ở mục g)
#   clgOpen()              (clgOpen: Chuyện làng)
#   Ai(id) -> Texture2D    (thiếu thì U.item_ic)
var ext := {}

var sysp: Control = null    # bảng Hệ Thống
var sys_sig := ""
var place: Control = null   # #placeCard
var l8 := ""                # chữ ký NX
var nL := ""                # chữ ký VH
var q2 := "all"             # miền đang xem
var rev_text := ""          # #revText
var cg: Control = null      # bảng chở hàng (l1.ov)
var tip: Control = null     # thẻ nhắc (is)
var tut: Control = null     # hộp Cô Ba (U0.el)

func _init(ui, ws) -> void:
	U = ui
	G = ui.G
	W = ws
	W.render.connect(_on_render)
	W.tip_show.connect(show_tip)
	W.tip_hide.connect(hide_tip)
	W.tut_text.connect(tut_set)
	W.tut_end.connect(tut_close)

func _x(k: String) -> Callable:
	var c = ext.get(k)
	return c if c is Callable and (c as Callable).is_valid() else Callable()

static func _k(v: float) -> float:
	return v * Css.K

func _on_render() -> void:   # kn / htRender
	if sysp != null:
		sync_sys()
	if place != null:
		sync_place()
	if cg != null:
		_oh()

# ------------------------------------------------------------------ khối dựng chung (như w_cho_ui.gd)
func _panel(title: String, on_close: Callable) -> Array:
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
	var top := VBoxContainer.new()   # chỗ cho phần cố định trên đầu (htSum)
	col.add_child(top)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, minf(U.vsize().y * 0.7, 560.0) * Css.K)
	col.add_child(sc)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(_k(6)))
	sc.add_child(body)
	U.root.add_child(ov)
	ov.set_meta("top", top)
	ov.set_meta("body", body)
	ov.set_meta("sc", sc)
	return [ov, body]

func _lbl(s: String, fs: float, w: int, col: Color, wrap := true) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", Css.font(w))
	l.add_theme_font_size_override("font_size", int(_k(fs)))
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _btn(s: String, primary: bool, on: bool, cb: Callable) -> Button:   # .btn / .btn.primary
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

func _sec(b: String, small: String) -> Control:   # .vl-sec
	var v := VBoxContainer.new()
	v.add_child(_lbl(b, 14, 800, Color8(0x3a, 0x2a, 0x1a)))
	if small != "":
		v.add_child(_lbl(small, 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
	return v

func _p(s: String, note := false) -> Label:   # <p> / .lssum / .note
	return _lbl(s, 12.5, 500, Color8(0x8a, 0x6a, 0x48) if note else Color8(0x5a, 0x4a, 0x3a))

func _row(b: String, small: String, me: bool, right: Array) -> Control:   # .lsrow (.me): <b> + <small> + nút
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(0xf3, 0xf9, 0xe8) if me else Color8(0xff, 0xff, 0xff)
	sb.border_color = Color8(0xb8, 0xd8, 0x98) if me else Color8(0xe8, 0xdc, 0xc4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(_k(10)))
	sb.content_margin_left = _k(10)
	sb.content_margin_right = _k(10)
	sb.content_margin_top = _k(6)
	sb.content_margin_bottom = _k(6)
	pc.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(_k(8)))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_lbl(b, 13.5, 700, Color8(0x3a, 0x2a, 0x1a)))
	if small != "":
		v.add_child(_lbl(small, 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
	h.add_child(v)
	for x in right:
		x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(x)
	pc.add_child(h)
	return pc

func _jobs(btns: Array) -> Control:   # .vl-jobs
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", int(_k(6)))
	f.add_theme_constant_override("v_separation", int(_k(6)))
	for b in btns:
		f.add_child(b)
	return f

func _pips(c: int) -> Control:   # .pips: 5 chấm, c chấm sáng
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(_k(3)))
	for i in 5:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(_k(14), _k(5))
		r.color = Color8(0x3f, 0x9a, 0x3a) if i < c else Color8(0xe0, 0xd6, 0xc0)
		h.add_child(r)
	return h

static func _clear(n: Control) -> void:
	for c in n.get_children():
		c.queue_free()

# ------------------------------------------------------------------ bảng Hệ Thống (htRender, htSum, htClick)
func open_sys() -> void:   # gu("sys")
	close_sys()
	U.close_all()
	sys_sig = ""
	W.HTV.t = 0.0
	var p := _panel("Hệ Thống", close_sys)
	sysp = p[0]
	sync_sys(true)

func close_sys() -> void:
	if sysp != null:
		sysp.queue_free()
		sysp = null

func _tab(v: String) -> void:   # htClick data-ht="tab"
	if W.HTV.tab != v:
		W.HTV.tab = v
		var sc: ScrollContainer = sysp.get_meta("sc")
		sc.scroll_vertical = 0
	sync_sys(true)

func _act(f: Callable) -> void:   # htClick: chạy việc rồi htRender(true)
	f.call()
	sync_sys(true)

func sync_sys(now := false) -> void:   # htRender
	if sysp == null:
		return
	var tm: float = G._now_ms()
	if not now and tm - float(W.HTV.t) < 1000:
		return
	W.HTV.t = tm
	if W.HTV.tab != "pt" and W.HTV.tab != "shop":
		W.HTV.tab = "nv"
	_ht_sum(sysp.get_meta("top"))
	var bd: VBoxContainer = sysp.get_meta("body")
	_clear(bd)
	if W.HTV.tab == "pt":
		_tab_pt(bd)
	elif W.HTV.tab == "shop":
		_tab_shop(bd)
		_dh(bd)
		_bx(bd)
	else:
		_tab_nv(bd)

func _ht_sum(E: Control) -> void:   # htSum: 3 ô tóm tắt làm tab
	_clear(E)
	var o: Dictionary = W.htNv()
	var k = o.kh.get("q") if o.get("kh") is Dictionary else null
	var d := 0
	for q in o.nv.l:
		if W._tr(q.get("ok")):
			d += 1
	var tu: Dictionary = o.tu.q
	var c0 = o.get("c0")
	var lv: int = W.jr()
	var c := [["shop", "Điểm", "⭐ " + G.fmt_n(int(W.sys().pts)), "+5 mỗi cấp"],
		["pt", "Nhánh", String(W.HTB[c0]) if W._tr(c0) else "Chưa chọn",
			("Phụ: " + String(W.HTB[o.p0])) if W._tr(c0) else ("Chọn ngay" if lv >= int(W.HTLV[1]) else "Cấp " + str(W.HTLV[1]) + " mở")],
		["nv", "Hôm nay", str(d) + "/" + str(o.nv.l.size()),
			("Khẩn còn " + G.ao(maxf(0.0, (float(k.t1) - G._now_ms()) / 1000.0))) if k is Dictionary and not W._tr(k.get("ok")) else ("Tuần " + str(W.htQCur(tu)) + "/" + str(tu.m))]]
	var red: bool = W.htRed() > 0
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(_k(6)))
	for x in c:
		var on: bool = W.HTV.tab == x[0]
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = on
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = ("● " if x[0] == "nv" and red else "") + x[1] + "\n" + x[2] + "\n" + x[3]   # i.htdot + small + span + em
		b.add_theme_font_override("font", Css.font(700))
		b.add_theme_font_size_override("font_size", int(_k(12)))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color8(0xf3, 0xf9, 0xe8) if on else Color8(0xff, 0xff, 0xff)
		sb.border_color = Color8(0x3f, 0x9a, 0x3a) if on else Color8(0xe8, 0xdc, 0xc4)
		sb.set_border_width_all(int(maxf(1.0, _k(1.5))))
		sb.set_corner_radius_all(int(_k(10)))
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_color_override("font_color", Color8(0x3a, 0x2a, 0x1a))
		b.add_theme_color_override("font_pressed_color", Color8(0x3a, 0x2a, 0x1a))
		var v: String = x[0]
		b.pressed.connect(func(): _tab(v))
		h.add_child(b)
	E.add_child(h)

func _q_row(q: Dictionary, i: int, kind: String, o: Dictionary) -> Control:   # row(q, i, kind) của htTabNv
	var cur: int = W.htQCur(q)
	var ok: bool = W.htQOk(q)
	var right := []
	if W._tr(q.get("ok")):
		right.append(_lbl("Đã nhận", 12, 600, Color8(0x8a, 0x6a, 0x48), false))
	elif ok:
		right.append(_btn("Nhận " + str(q.pts), true, true, func(): _act(func(): _nhan(kind, i))))
	elif kind == "nv" and not W._tr(o.nv.get("doi")):
		right.append(_btn("Đổi", false, true, func(): _act(func(): W.htDoi(i))))
	var sm := str(cur) + "/" + str(q.m) + " · " + str(q.pts) + " điểm"
	if kind == "kh":
		sm += " · còn " + G.ao(maxf(0.0, (float(q.t1) - G._now_ms()) / 1000.0))
	return _row(String(q.t), sm, not W._tr(q.get("ok")) and ok, right)

func _nhan(kind: String, i: int) -> void:   # data-ht="nhan"
	var o: Dictionary = W.htNv()
	if kind == "nv":
		W.htNhan(o.nv.l[i])
	elif kind == "tu":
		W.htNhan(o.tu.q)
	else:
		W.htNhan(o.kh.get("q") if o.get("kh") is Dictionary else null)

func _tab_nv(h: Control) -> void:   # htTabNv
	var o: Dictionary = W.htNv()
	var k: Dictionary = W.htKh()
	var c0 = o.get("c0")
	h.add_child(_p((("Nhiệm vụ ngày theo nhánh chính " + String(W.HTB[c0]) + ".") if W._tr(c0) else "Chưa chọn nhánh, nhiệm vụ ngẫu nhiên.") + " Mỗi ngày đổi được 1 nhiệm vụ. Lên mỗi cấp cũng được 5 điểm."))
	if k.get("q") is Dictionary:
		h.add_child(_sec("Nhiệm vụ khẩn", ""))
		h.add_child(_q_row(k.q, -1, "kh", o))
	h.add_child(_sec("Hôm nay", ""))
	for i in o.nv.l.size():
		h.add_child(_q_row(o.nv.l[i], i, "nv", o))
	h.add_child(_sec("Tuần này", ""))
	h.add_child(_q_row(o.tu.q, -1, "tu", o))
	var T: Array = W.HTTD.filter(func(t): return not W._tr(o.td.get(t[0])))
	if T.size() > 0:
		h.add_child(_sec("Thành tựu", "Làm lần đầu được thưởng một lần."))
		for t in T:
			var ok: bool = W.htTdOk(t)
			var id: String = t[0]
			h.add_child(_row(String(t[1]), str(t[2]) + " điểm", ok,
				[_btn("Nhận " + str(t[2]), true, true, func(): _act(func(): W.htTdNhan(id)))] if ok else []))

func _tab_pt(h: Control) -> void:   # htTabPt
	var o: Dictionary = W.htS()
	var b: String = W.HTV.br
	var P: Dictionary = W.HTV.pick if W.HTV.pick is Dictionary else {}
	var c0 = o.get("c0")
	var lv: int = W.jr()
	if not W._tr(c0):
		if lv < int(W.HTLV[1]):
			h.add_child(_p("Lên cấp " + str(W.HTLV[1]) + " thì chọn 1 nhánh chính (lên tới tầng 5) và 1 nhánh phụ (tới tầng 3). Giờ mỗi nhánh chỉ mở tầng 1. Bấm từng nhánh để xem trước."))
		else:
			h.add_child(_p("Chưa chọn nhánh. Bấm từng nhánh để xem, rồi chọn 1 nhánh chính (lên tới tầng 5) và 1 nhánh phụ (tới tầng 3). Chọn xong bấm Xác nhận mới chốt."))
			if W._tr(P.get("c")):
				var r := []
				if W._tr(P.get("p")):
					r.append(_btn("Xác nhận", true, true, func(): _act(func(): W.htChon("ok", ""))))
				r.append(_btn("Chọn lại", false, true, func(): _act(func(): W.htChon("lai", ""))))
				h.add_child(_row("Chính: " + String(W.HTB[P.c]),
					("Phụ: " + String(W.HTB[P.p]) + ". Chốt rồi muốn đổi phải tẩy điểm.") if W._tr(P.get("p")) else "Giờ chọn nhánh phụ.", true, r))
	var bs := []
	for kk in W.HTB:
		var k: String = kk
		var lb := ""
		if c0 == k or (not W._tr(c0) and P.get("c") == k):
			lb = " · chính"
		elif o.get("p0") == k or (not W._tr(c0) and P.get("p") == k):
			lb = " · phụ"
		bs.append(_btn(String(W.HTB[k]) + lb, b == k, true, func():
			W.HTV.br = k
			sync_sys(true)))
	h.add_child(_jobs(bs))
	if not W._tr(c0) and lv >= int(W.HTLV[1]):
		var bt: Button = null
		if not W._tr(P.get("c")) or P.get("c") == b:
			if P.get("c") != b:
				bt = _btn("Chọn " + String(W.HTB[b]) + " làm nhánh chính", true, true, func(): _act(func(): W.htChon("c", b)))
		elif P.get("p") != b:
			bt = _btn("Chọn " + String(W.HTB[b]) + " làm nhánh phụ", true, true, func(): _act(func(): W.htChon("p", b)))
		if bt != null:
			h.add_child(_jobs([bt]))
	for t in range(1, 6):
		var L: Array = W.HTN.filter(func(x): return x.b == b and int(x.t) == t)
		h.add_child(_sec("Tầng " + str(t) + (" · tuyệt kỹ" if t == 5 else ""),
			"Mở ở cấp " + str(W.HTLV[t - 1]) + " · " + str(W.HTGIA[t - 1]) + " điểm mỗi bậc" + (" · nhánh này không lên tới" if W._tr(c0) and t > W.htCap(b) else "")))
		for x in L:
			var k := int(o.n.get(x.id, 0))
			var w: String = W.htWhy(x)
			var mx: int = x.v.size()
			var nm := String(x.n) + ((" · " + str(k) + "/" + str(mx)) if mx > 1 else (" · đã có" if k else ""))
			var sm := ""
			if W._tr(x.get("soon")):
				sm = W.ht_d(x, 0)
			elif k:
				sm = W.ht_d(x, k - 1) + ((" → " + W.ht_d(x, k)) if k < mx else "")
			else:
				sm = W.ht_d(x, 0)
			var right := []
			if not (w == "Tối đa" or (k and mx == 1)):
				var id: String = x.id
				right.append(_btn(w if w != "" else (("Nâng" if k else "Mở") + " · " + str(W.HTGIA[t - 1])), w == "", w == "", func(): _act(func(): W.htBuy(id))))
			h.add_child(_row(nm, sm, k > 0, right))
	var s: int = W.htSpent()
	if s or W._tr(c0):
		h.add_child(_sec("Tẩy điểm", "Hoàn lại " + str(s) + " điểm đã dùng, chọn lại nhánh. Tốn " + str(W.HTTAY) + " sen đỏ, 7 ngày một lần."))
		h.add_child(_jobs([_btn("Tẩy điểm · " + str(W.HTTAY) + " sen đỏ", false, true, func(): _act(func(): W.htReset()))]))

func _tab_shop(h: Control) -> void:   # htTabShop
	var n: Dictionary = W.d3()
	var e: float = G._now_ms()
	var lv: int = W.jr()
	h.add_child(_p("Đồ dùng mua bằng điểm Hệ Thống, có món giới hạn mỗi ngày."))
	for f in W.WH:
		var lim := int(f.get("lim", 0))
		var s := (lim - int(n.buy.get(f.id, 0))) if lim else 1
		var ok: bool = int(n.pts) >= int(f.c) and s > 0 and W.wh_ok(f) and (not W._tr(f.get("lv")) or lv >= int(f.lv))
		var sm := String(f.d)
		if f.id == "boost" and float(n.get("boost", 0)) > e:
			sm += " Đang có hiệu lực, còn " + G.ao((float(n.boost) - e) / 1000.0) + "."
		if f.id == "bgl" and W._tr(W.htS().get("bgl")):
			sm += " Đang cất " + str(W.htS().bgl) + " lá."
		var id: String = f.id
		h.add_child(_row(String(f.n) + ((" · còn " + str(maxi(0, s)) + "/" + str(lim)) if lim else ""), sm, false,
			[_btn(("Cấp " + str(f.lv)) if W._tr(f.get("lv")) and lv < int(f.lv) else (str(f.c) + " điểm"), ok, ok, func(): _act(func(): W.kJ(id)))]))

const SPICO := {"an": "🍜", "qua": "🎁", "giong": "🌱", "vat": "🧰"}

func _dh(h: Control) -> void:   # DH: Túi đặc sản (.sysx)
	var spec: Dictionary = W.sys().spec
	h.add_child(_sec("Túi đặc sản", ""))
	var c: Array = W.cc.filter(func(f): return int(spec.get(f.id, 0)) > 0)
	if c.is_empty():
		h.add_child(_p("Đi du lịch hoặc chở hàng tới đâu cũng mang về đặc sản nơi đó.", true))
		return
	for f in c:
		var use: String = String(f.get("use", "")) if W._tr(f.get("use")) else "an"
		var sp := use.split(":")
		var s: String = sp[0]
		var hh: String = sp[1] if sp.size() > 1 else ""
		var sm := ""
		if s == "an":
			sm = "Ăn hồi 30 sức" + ((", " + String(W.Sf[hh].n) + " 20 phút") if hh != "" and W.Sf.has(hh) else "")
		elif s == "qua":
			sm = "Biếu nhà ít thân nhất, +1 ♥"
		elif s == "giong":
			sm = "Đổi 1 cây giống cam" if f.id == "na" else "5 hạt giống + 1 hạt quý"
		else:
			sm = "Đổi 2 vật liệu nâng sao"
		var id: String = f.id
		h.add_child(_row(String(SPICO.get(s, "🎁")) + " " + String(f.spec) + " ×" + str(spec[f.id]), sm, false,
			[_btn(String(W.IH.get(s, "")), false, true, func(): _act(func(): W.FH(id)))]))

func _bx(h: Control) -> void:   # BX phần XO (#sysShop "Xe hàng")
	h.add_child(_sec("Xe hàng", ""))
	for o in W.XO:
		var l: Dictionary = W.r8[o]
		var c := int(W.sys().shop.get(o, 0))
		var s: bool = c >= int(l.max)
		var v := VBoxContainer.new()
		v.add_child(_lbl(String(l.name), 13.5, 700, Color8(0x3a, 0x2a, 0x1a)))
		v.add_child(_lbl(W.r8_fx(c), 11.5, 500, Color8(0x5a, 0x4a, 0x3a)))
		v.add_child(_lbl("Đã đạt cấp tối đa" if s else "Cấp tiếp: " + W.r8_fx(c + 1), 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
		v.add_child(_pips(c))
		var id: String = o
		var on: bool = not s and int(W.sys().pts) >= W.TE(o)
		h.add_child(_row("", "", false, [v, _btn("Tối đa" if s else str(W.TE(o)) + " điểm", false, on, func(): _act(func(): W.AX(id)))]))

# ------------------------------------------------------------------ dòng chuyến đi #trip (BX phần trip + BJ)
func trip_view() -> Dictionary:   # {} = #trip ẩn; {to, t, bar, go, rush (sen đỏ, 0 = ẩn nút Tới ngay)}
	var t = W.sys().trip
	if not (t is Dictionary):
		return {}
	var n = W.cs(t.to)
	var now: float = G._now_ms()
	var e := (float(t.t1) - now) / 1000.0
	var r := e <= 0
	var cargo: bool = t.has("cargo") and t.cargo != null
	var to := ""
	if r:
		to = ("Xe hàng đã tới " if cargo else "Đã tới ") + String(n.name)
	else:
		to = ("Xe hàng đang chạy tới " if cargo else "Đang đi tới ") + String(n.name)
	return {"to": to, "t": "Nhận quà để hoàn tất" if r else "Còn " + W.o8(e),
		"bar": minf(1.0, (now - float(t.t0)) / maxf(1.0, float(t.t1) - float(t.t0))), "go": r,
		"rush": W.trip_rush_cost(), "rush_t": "Tới ngay " + str(W.trip_rush_cost()) + " sen đỏ"}

# ------------------------------------------------------------------ thẻ địa điểm (NX + VH), miền (O7), review (tH, N7)
func open_place(id: String) -> void:   # chạm ghim trên bản đồ: fs = id
	W.fs = id
	l8 = ""
	nL = ""
	rev_text = ""
	if place == null:
		var p := _panel("", close_place)
		place = p[0]
	sync_place()

func close_place() -> void:
	if place != null:
		place.queue_free()
		place = null

func region_tabs() -> Control:   # O7: nút miền + đã ghé / tổng
	var bs := []
	for a in W.R7:
		var r: String = a
		var n := 0
		var e := 0
		for p in W.cc:
			if r == "all" or p.r == r:
				n += 1
				if W._tr(W.sys().visited.get(p.id)):
					e += 1
		if r == "all":
			e = W.sys().visited.size()
		var b := _btn(String(W.HX.get(r, r)) + " " + str(e) + "/" + str(n), q2 == r, true, func():
			q2 = r
			var f := _x("IX")
			if f.is_valid():
				f.call(r))
		bs.append(b)
	return _jobs(bs)

func sync_place() -> void:   # NX + VH
	if place == null:
		return
	var a = W.cs(W.fs)
	if a == null:
		close_place()
		return
	var s: Dictionary = W.sys()
	var n := int(s.visited.get(a.id, 0))
	var e: bool = W.Kg(a)
	var r = s.reviews.get(a.id)
	var o: bool = s.trip is Dictionary
	var l := int(G.g.coins)
	var c := int(s.pts)
	var lv: int = W.jr()
	var parts := PackedStringArray()
	for x in [a.id, n, e, r != null, o, l >= W.i3(a), c >= int(a.unlock), lv, r.at if r is Dictionary else "", s.spec.get(a.id, 0), G.day()]:
		parts.append(str(x))
	var f := "|".join(parts)
	if f == l8:
		return
	l8 = f
	var bd: VBoxContainer = place.get_meta("body")
	_clear(bd)
	var lk: bool = lv < int(a.get("lv", 1)) and not e
	bd.add_child(_lbl(String(a.name), 18, 800, Color8(0x3a, 0x2a, 0x1a)))
	bd.add_child(_lbl(("Cấp " + str(a.lv) + " mở") if lk else (("Đã ghé " + str(n) + " lần" if n else "Chưa ghé") if e else "Khóa: " + str(a.unlock) + " điểm"),
		12, 700, Color8(0x2f, 0x7a, 0x2a) if n else Color8(0x8a, 0x6a, 0x48)))   # #plTag
	bd.add_child(_p(String(a.fact)))
	if a.src.size() > 0:   # #plSrc
		var nm := []
		for w in a.src:
			nm.append(String(w[0]))
		bd.add_child(_p("Nguồn: " + ", ".join(nm), true))
	bd.add_child(_p(String(a.tip), true))
	var v: int = s.spec.size()
	var meta := [["Miền", {"nam": "Miền Nam", "trung": "Miền Trung", "bac": "Miền Bắc"}.get(a.r, "")],
		["Khoảng cách", G.fmt_n(W.G4(a)) + " km từ đảo trại"], ["Thời gian đi", W.o8(W.B7(a))],
		["Phí chuyến đi", str(W.i3(a)) + " xu"], ["Thưởng khi tới", G.fmt_n(W.YO(a)) + " xu"],
		["Đặc sản", String(a.spec) + ((" (đã có " + str(s.spec[a.id]) + ")") if W._tr(s.spec.get(a.id)) else "")],
		["Bộ sưu tập", str(v) + "/" + str(W.cc.size()) + " đặc sản"]]
	for w in meta:   # #plMeta li: span + b
		var hb := HBoxContainer.new()
		var k := _lbl(String(w[0]), 12, 500, Color8(0x8a, 0x6a, 0x48), false)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(k)
		hb.add_child(_lbl(String(w[1]), 12, 700, Color8(0x3a, 0x2a, 0x1a), false))
		bd.add_child(hb)
	var gtxt := ""
	var gon := true
	if lk:
		gtxt = "Lên cấp " + str(a.lv) + " mới đi được"
		gon = false
	elif e:
		if o:
			gtxt = "Đang có một chuyến đi"
			gon = false
		else:
			gtxt = "Du hành tới " + String(a.name) + " (" + str(W.i3(a)) + " xu)"
			gon = l >= W.i3(a)
	else:
		gtxt = "Mở khóa bằng " + str(a.unlock) + " điểm"
		gon = c >= int(a.unlock)
	bd.add_child(_btn(gtxt, true, gon, func(): _pl_go()))   # #plGo
	# VH: .plx dưới #plGo
	if e:
		var cn: Array = W.NH(a)
		var nms := []
		for x in cn:
			nms.append(String(G.item(x).get("name", x)))
		bd.add_child(_p("Hôm nay " + String(a.name) + " cần mua: " + ", ".join(nms) + " · trả gấp " + W.HH(W.S7(a)) + " lần giá làng", true))
		bd.add_child(_btn("🚚 Chở hàng đi bán", false, not o, func(): _cargo(a)))
	var sp := int(s.spec.get(a.id, 0))
	var su: String = (String(a.get("use", "")) if W._tr(a.get("use")) else "an").split(":")[0]
	if sp:
		var id: String = a.id
		bd.add_child(_row("", "Bạn có " + str(sp) + " " + String(a.spec).to_lower(), false,
			[_btn(String(W.IH.get(su, "")), false, true, func(): W.FH(id))]))
	# #plRev: chỉ khi đã ghé
	if n:
		if r is Dictionary:
			W.lp = int(r.s)
		bd.add_child(_sec("Review của bạn", ""))
		var st := HBoxContainer.new()   # #stars
		for i in 5:
			var k := i + 1
			st.add_child(_btn("★" if i < W.lp else "☆", false, true, func():
				W.lp = k
				l8 = ""
				sync_place()))
		bd.add_child(st)
		var te := TextEdit.new()   # #revText maxlength 240
		te.custom_minimum_size = Vector2(0, _k(70))
		te.placeholder_text = "Viết vài dòng về trải nghiệm thật của bạn ở đây"
		if rev_text == "" and r is Dictionary:
			rev_text = String(r.t)
		te.text = rev_text
		var cnt := _lbl(str(rev_text.length()) + "/240", 11, 500, Color8(0x8a, 0x6a, 0x48), false)
		te.text_changed.connect(func():
			if te.text.length() > 240:
				te.text = te.text.substr(0, 240)
			rev_text = te.text
			cnt.text = str(rev_text.length()) + "/240")
		bd.add_child(te)
		bd.add_child(cnt)
		bd.add_child(_btn("Đăng review", true, true, func():
			W.N7(rev_text)
			l8 = ""
			sync_place()))
		if r is Dictionary:   # #myRev
			bd.add_child(_p("★".repeat(int(r.s)) + " " + String(r.t)))

func _pl_go() -> void:   # #plGo: qX (chưa mở thì $O)
	var a = W.cs(W.fs)
	if a != null:
		W.qX(a)

# ------------------------------------------------------------------ bảng chở hàng (vJ, OH, t9)
func _cargo(t: Dictionary) -> void:   # vJ
	if not W.vJ(t):
		return
	t9()
	var p := _panel("🚚 Chở hàng đi " + String(t.name), t9)
	cg = p[0]
	_oh()

func t9() -> void:   # t9
	if cg != null:
		cg.queue_free()
		cg = null

func _oh() -> void:   # OH
	if cg == null:
		return
	var t: Dictionary = W.l1.p
	var a: Array = W.NH(t)
	var n: int = W.tL()
	var e: int = W.SE()
	var r: int = W.RH()
	var o: int = W.BH(t)
	var bd: VBoxContainer = cg.get_meta("body")
	_clear(bd)
	bd.add_child(_p("Hôm nay " + String(t.name) + " đang cần 4 món dưới đây, trả giá gấp " + W.HH(W.S7(t)) + " lần giá chợ làng. Xe chở tối đa " + str(e) + " món, đi mất " + W.o8(W.B7(t, true)) + ", tiền xăng " + G.fmt_n(o) + " xu.", true))
	for c in a:
		var f := int(G.g.barn.get(c, 0))
		var s := int(W.l1.q.get(c, 0))
		var id: String = c
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(_k(6)))
		h.add_child(_ic(c, 32))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_lbl(String(G.item(c).get("name", c)), 13.5, 700, Color8(0x3a, 0x2a, 0x1a)))
		v.add_child(_lbl("Kho có " + str(f) + " · giá ở đây " + G.fmt_n(W._r(W._price(c) * W.S7(t))) + " xu/món", 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
		h.add_child(v)
		var more: bool = s < f and n < e
		h.add_child(_btn("−", false, s > 0, func(): _adj(id, -1)))
		h.add_child(_lbl(str(s), 14, 800, Color8(0x3a, 0x2a, 0x1a), false))
		h.add_child(_btn("+", false, more, func(): _adj(id, 1)))
		h.add_child(_btn("Hết", false, more, func(): _adj(id, 0)))
		bd.add_child(h)
	var sm := HBoxContainer.new()   # .cgsum
	var l := _lbl("Trên xe " + str(n) + "/" + str(e) + " món", 12.5, 600, Color8(0x5a, 0x4a, 0x3a), false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sm.add_child(l)
	sm.add_child(_lbl("Bán được ~" + G.fmt_n(r) + " xu", 13, 800, Color8(0x3a, 0x2a, 0x1a), false))
	bd.add_child(sm)
	bd.add_child(_btn("Xuất phát (" + G.fmt_n(o) + " xu xăng)", true, n > 0 and int(G.g.coins) >= o, func():
		if W.mJ():
			t9()))

func _adj(id: String, d: int) -> void:   # data-id / data-d
	W.cg_adj(id, d)
	_oh()

# ------------------------------------------------------------------ danh sách nâng cấp #ups (Z9)
func ups(parent: Control) -> void:   # dòng #ups: tên, .cur, .nxt, .pips, nút oG
	_clear(parent)
	for a in W.Z9:
		var k: String = a
		var n: Dictionary = W.Gp[k]
		var e := int(W._up()[k])
		var o: int = W.X7(k)
		var l: int = W.d8(k)
		var c := e >= o
		var f: int = W.AH(e)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_lbl(String(n.name), 13.5, 700, Color8(0x3a, 0x2a, 0x1a)))
		v.add_child(_lbl(W.gp_fx(k, e), 11.5, 500, Color8(0x5a, 0x4a, 0x3a)))
		var nxt := ""
		if l:
			nxt = "Mở ở cấp " + str(l)
		elif c:
			nxt = ("Cấp " + str(f) + " mở thêm nấc nâng cấp") if f and e < int(n.max) else "Đã đạt cấp tối đa"
		else:
			nxt = "Cấp tiếp: " + W.gp_fx(k, e + 1)
		v.add_child(_lbl(nxt, 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
		v.add_child(_pips(e))
		var y: int = W.Y8(k)
		var bt := _btn(("🔒 Cấp " + str(l)) if l else ("Tối đa" if c else "Nâng cấp, " + G.fmt_n(y) + " xu"), false,
			not (l or c or int(G.g.coins) < y), func():
				W.oG(k)
				ups(parent))
		var h := HBoxContainer.new()
		h.add_child(v)
		bt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bt)
		parent.add_child(h)

# ------------------------------------------------------------------ thẻ "Lần đầu gặp" (XZ)
func show_tip(t: Dictionary) -> void:   # XZ
	hide_tip()
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(0xff, 0xfa, 0xf0)
	sb.set_corner_radius_all(int(_k(14)))
	sb.set_content_margin_all(_k(12))
	pc.add_theme_stylebox_override("panel", sb)
	pc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pc.custom_minimum_size = Vector2(minf(U.vsize().x - 32.0, 360.0) * Css.K, 0)
	var v := VBoxContainer.new()
	var hd := HBoxContainer.new()
	var b := _lbl("Lần đầu gặp", 14, 800, Color8(0x3a, 0x2a, 0x1a))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(b)
	hd.add_child(_btn("×", false, true, func(): W.wO()))
	v.add_child(hd)
	v.add_child(_p(String(t.t)))
	var gg = t.get("g")
	var bs := []
	if W._tr(gg):
		bs.append(_btn("Xem sổ tay", false, true, func():
			var f := _x("ZC")
			if f.is_valid():
				f.call(gg)
			W.wO()))
	else:
		bs.append(_btn("Chuyện làng", false, true, func():
			var f := _x("clgOpen")
			if f.is_valid():
				f.call()
			W.wO()))
	bs.append(_btn("Đã hiểu", true, true, func(): W.wO()))
	v.add_child(_jobs(bs))
	v.add_child(_btn("Tắt nhắc lần đầu", false, true, func(): W.tip_off()))
	pc.add_child(v)
	tip = pc
	U.root.add_child(pc)
	pc.position = Vector2((U.root.size.x - pc.custom_minimum_size.x) / 2.0, U.root.size.y - _k(220))

func hide_tip() -> void:
	if tip != null:
		tip.queue_free()
		tip = null

# ------------------------------------------------------------------ hộp Cô Ba (ZY, SF, CF)
func tut_set(text: String, step: String) -> void:   # SF: p + small (hộp tạo ở ZY)
	if tut == null:
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color8(0xff, 0xfa, 0xf0)
		sb.set_corner_radius_all(int(_k(14)))
		sb.set_content_margin_all(_k(10))
		pc.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(_k(8)))
		h.add_child(_lbl("👩‍🌾", 26, 400, Color.BLACK, false))   # .tuav
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_lbl("Cô Ba chỉ nè", 13.5, 800, Color8(0x3a, 0x2a, 0x1a)))
		var p := _p("")
		var s := _lbl("", 11, 500, Color8(0x8a, 0x6a, 0x48), false)
		v.add_child(p)
		v.add_child(s)
		h.add_child(v)
		var sk := _btn("Bỏ qua", false, true, func(): W.CF(true))   # .tuskip
		sk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sk)
		pc.add_child(h)
		pc.custom_minimum_size = Vector2(minf(U.vsize().x - 32.0, 380.0) * Css.K, 0)
		pc.set_meta("p", p)
		pc.set_meta("s", s)
		tut = pc
		U.root.add_child(pc)
		pc.position = Vector2((U.root.size.x - pc.custom_minimum_size.x) / 2.0, _k(120))
	(tut.get_meta("p") as Label).text = text
	(tut.get_meta("s") as Label).text = step

func tut_close() -> void:   # CF: U0.el.remove()
	if tut != null:
		tut.queue_free()
		tut = null
