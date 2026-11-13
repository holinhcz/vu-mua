extends RefCounted
# XU, CHỢ, GIÁ, CHỢ NỔI (giao diện): phần bảng bản web còn thiếu ở bản Godot.
#  - jx: bảng "Chợ nổi sông Vàm" (#vlBody khi $r.mode === "cho"): 4 nút ghe (.btabs), dòng ghi chú ghe (.note),
#    hộp "🔥 Hôm nay được giá" (lớp bọc jx thêm .u2hotc), danh sách kèo (.ws-rec li.rec: hình, tên, chữ nhỏ, ô cần, nút).
#    Dựng lại chỉ khi chữ ký $r.sig đổi (web: JSON [ghe, g.cho, số trong kho, xu/10, phút còn/10]), không vẽ mỗi khung.
#  - mQ: nút viên "Chợ nổi đang họp · tan lúc 9:00" (.ghepill.chopill, .hurry khi còn < 0,4 giờ).
#  - MU / tR: bảng "Đài phát thanh huyện" (#rdBody).
#  - jR: mục "Giống nhà … để dư" trong bảng nhà dân (tab Mua giống của a4).
# Dựng bằng Control thường của Godot (bản web không có bản chụp cho các bảng này), cỡ theo Css.K như các bảng khác.

const Css = preload("res://ui/css.gd")

var U          # ui.gd
var G          # game.gd
var W          # w_cho.gd
# ext: việc của hệ khác (bộ ráp gán)
#   aN()                  (aN: camera về ghe thứ 2)
#   Ns(t: Dictionary)     (Ns: nhân vật đi tới chỗ {type: "cho", k}) rồi chạy qN -> open_cho(k)
#   cl(on: bool)          (radio: bật / tắt nhạc cải lương, âm thanh)
var ext := {}

var cho: Control = null     # bảng chợ nổi
var cho_sig := ""           # $r.sig
var rd: Control = null      # bảng radio (Cf)
var rd_cl := false          # Cf.cl
var pill: Button = null     # y2

func _init(ui, wc) -> void:
	U = ui
	G = ui.G
	W = wc
	W.panel_close.connect(_on_close)

func _on_close() -> void:   # i1: $r.mode === "cho" thì đóng bảng
	if cho != null:
		close_cho()

func _x(k: String) -> Callable:
	var c = ext.get(k)
	return c if c is Callable and (c as Callable).is_valid() else Callable()

static func _k(v: float) -> float:
	return v * Css.K

# ------------------------------------------------------------------ khối dựng chung
func _panel(title: String, on_close: Callable) -> Array:   # .raceov.pcov > .rbox.pcbox: [gốc, thân]
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
	var hd := HBoxContainer.new()   # .ws-h: <b>tên</b> + nút ×
	var b := _lbl(title, 17, 800, Color8(0x3a, 0x2a, 0x1a))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(b)
	var x := _btn("×", false, true, on_close)
	hd.add_child(x)
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
	t.texture = U.item_ic(id, _k(px))
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

func _note(b: String, rest: String) -> Control:   # .note (<b> đầu dòng + chữ thường)
	var v := VBoxContainer.new()
	if b != "":
		v.add_child(_lbl(b, 12, 700, Color8(0x5a, 0x4a, 0x3a)))
	if rest != "":
		v.add_child(_lbl(rest, 12, 400, Color8(0x8a, 0x7a, 0x6a)))
	return v

func _chip(t: String, a: int) -> Control:   # nc: <span class="chip ok|no">Ai <b>n</b>/a tên</span>
	var n := mini(int(G.g.barn.get(t, 0)), a)
	var h := HBoxContainer.new()
	h.add_child(_ic(t, 20))
	h.add_child(_lbl(str(n) + "/" + str(a) + " " + G.item_name(t), 12, 600, Color8(0x2f, 0x7a, 0x2a) if n >= a else Color8(0xc0, 0x3a, 0x2a), false))
	return h

func _rec(ic: String, b: String, small: String, chip: Array, btns: Array) -> Control:   # li.rec
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(_k(8)))
	h.add_child(_ic(ic, 36))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_lbl(b, 13.5, 700, Color8(0x3a, 0x2a, 0x1a)))
	v.add_child(_lbl(small, 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
	if chip.size():
		v.add_child(_chip(chip[0], chip[1]))
	h.add_child(v)
	for x in btns:
		x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(x)
	return h

# ------------------------------------------------------------------ bảng chợ nổi
func open_cho(k: int) -> void:   # qN "cho": Ui.sel = k, gu("cho")
	W.tap(k)
	close_cho()
	U.close_all()
	cho_sig = ""
	var p := _panel("Chợ nổi sông Vàm", close_cho)   # xr(#vlName, "Chợ nổi sông Vàm")
	cho = p[0]
	cho.set_meta("body", p[1])
	sync_cho()

func close_cho() -> void:   # i1
	if cho != null:
		cho.queue_free()
		cho = null

func sync_cho() -> void:   # jx (gọi mỗi khung khi bảng mở; chỉ dựng lại khi chữ ký đổi)
	if cho == null:
		return
	if not W.b2() and float(W.Ui.al) <= 0:
		close_cho()
		return
	var t: Array = W.jd()
	var a: int = int(W.Ui.sel)
	var r: float = G.nv.hour()
	var o := maxf(0.0, W.wm() - r)
	var cnt := []
	for c in t[a]:
		cnt.append(int(G.g.barn.get(c.id, 0)))
	var l := JSON.stringify([a, G.g.get("cho"), cnt, int(floor(float(G.g.coins) / 10.0)), int(floor(o * 6.0))])
	if l == cho_sig:
		return
	cho_sig = l
	var body: VBoxContainer = cho.get_meta("body")
	for k in body.get_children():
		k.queue_free()
	# lớp bọc jx: hộp "🔥 Hôm nay được giá" đầu bảng
	var hl: Array = G.hot()
	if hl.size():
		var hb := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(236 / 255.0, 90 / 255.0, 79 / 255.0, 0.15)
		sb.set_corner_radius_all(int(_k(14)))
		sb.content_margin_left = _k(12)
		sb.content_margin_right = _k(12)
		sb.content_margin_top = _k(10)
		sb.content_margin_bottom = _k(10)
		hb.add_theme_stylebox_override("panel", sb)
		var hv := VBoxContainer.new()
		hv.add_child(_lbl("🔥 Hôm nay được giá", 13, 700, Color8(0xd6, 0x45, 0x3b)))
		var ss := []
		for f in hl:
			ss.append(G.item_name(f[0]) + " " + W.h5(float(f[1])))
		hv.add_child(_lbl(" · ".join(ss), 11.5, 500, Color8(0x5a, 0x4a, 0x3a)))
		hv.add_child(_lbl("Bán trong Kho hoặc giao đơn có món này được thêm 30%.", 11.5, 500, Color8(0x5a, 0x4a, 0x3a)))
		hb.add_child(hv)
		body.add_child(hb)
	# .btabs: 4 ghe
	var tabs := HBoxContainer.new()
	for f in W.s4.size():
		var c: Dictionary = W.s4[f]
		var bt := _btn(String(c.n).replace("Ghe ", ""), f == a, true, _sel_boat.bind(f))   # data-chob
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(bt)
	body.add_child(tabs)
	var n: Dictionary = W.s4[a]
	var left := ""
	if o > 0:
		left = " (còn khoảng " + ((str(int(floor(o))) + " tiếng ") if o >= 1 else "") + str(W._r(fmod(o, 1.0) * 60.0)) + " phút)"
	body.add_child(_note(String(n.n) + " · " + String(n.who), String(n.d) + " Chợ tan lúc " + str(W.wm()) + " giờ" + left + "."))
	for f in t[a].size():
		var c: Dictionary = t[a][f]
		var s: bool = W.Wx(a, f)
		var go := _deal.bind(a, f)   # data-cho="a:f"
		if c.t == "doi":
			var h: bool = int(G.g.barn.get(c.g, 0)) >= int(c.gq)
			body.add_child(_rec(String(c.id), "Đổi lấy " + str(int(c.q)) + " hạt giống " + G.item_name(c.id).to_lower(),
				"Đưa ghe " + W.ho(c.g, int(c.gq)) + (" · đã đổi" if s else ""), [String(c.g), int(c.gq)],
				[_btn("Xong" if s else "Đổi", true, h and not s, go)]))
		elif c.t == "mua":
			var h: bool = int(G.g.barn.get(c.id, 0)) >= int(c.q)
			body.add_child(_rec(W.bB(c), "Ghe mua " + W.ho(c.id, int(c.q)),
				"Trả " + G.fmt_n(int(c.xu)) + " xu (chợ làng " + G.fmt_n(int(c.q) * G.price(c.id)) + ")" + (" · đã bán" if s else ""),
				[String(c.id), int(c.q)], [_btn("Xong" if s else "Bán", true, h and not s, go)]))
		else:
			var h: bool = int(G.g.coins) >= int(c.xu)
			var k: String = c.k
			var sub := " · thả ao sen nuôi lớn" if k == "cagiong" else " · thả ao sen, đẻ trứng vịt" if k == "vitcon" else " · rẻ hơn tiệm 20%" if k == "cg" else " · rẻ hơn chợ phiên" if k == "giong" else " · thả vô chuồng" if k == "con" else ""
			body.add_child(_rec(W.bB(c), W.pQ(c), "Giá " + G.fmt_n(int(c.xu)) + " xu" + sub + (" · đã mua" if s else ""),
				[], [_btn("Xong" if s else "Mua", false, h and not s, go)]))

func _sel_boat(f: int) -> void:   # data-chob
	W.Ui.sel = f
	cho_sig = ""
	sync_cho()

func _deal(a: int, f: int) -> void:   # data-cho = "a:f" -> Dd
	W.Dd(a, f)
	cho_sig = ""
	sync_cho()

func _um(code: String, on_buy: Callable) -> void:   # data-gi -> Um
	W.Um(code)
	if on_buy.is_valid():
		on_buy.call()

func tip(k: int) -> String:   # BN "cho": chữ nhắc khi giữ tay trên ghe
	var a: Array = W.tip(k)
	return String(a[0]) + "\n" + String(a[1])

# ------------------------------------------------------------------ nút viên chợ nổi (mQ)
func pill_sync(parent: Control) -> void:   # mQ (gọi mỗi khung; parent = Hs(): hàng nút viên trên HUD)
	var t: bool = W.b2() and float(W.Ui.al) > 0.2 and W._mode() == "off" and String(W._x("qc").call() if W._x("qc").is_valid() else "") != "map"
	if not t:
		if pill != null:
			pill.visible = false
		return
	if pill == null:
		pill = _btn("", false, true, _pill_go)
		parent.add_child(pill)
	pill.visible = true
	var a := maxf(0.0, W.wm() - G.nv.hour())
	var s := "Chợ nổi đang họp · tan lúc " + str(W.wm()) + ":00"
	if pill.text != s:
		pill.text = s
	pill.modulate = Color(1, 0.85, 0.8) if a < 0.4 else Color.WHITE   # .hurry

func _pill_go() -> void:   # y2 click: aN(), Ui.pos && Ns({type: "cho", k: 1})
	var an := _x("aN")
	if an.is_valid():
		an.call()
	var ns := _x("Ns")
	if W.Ui.pos != null and ns.is_valid():
		ns.call({"type": "cho", "k": 1})

# ------------------------------------------------------------------ radio (MU / tR / PS)
func open_rd() -> void:   # MU
	if rd != null:
		return
	var p := _panel("Đài phát thanh huyện", close_rd)
	rd = p[0]
	rd.set_meta("body", p[1])
	tR()

func close_rd() -> void:   # PS
	if rd != null:
		rd.queue_free()
		rd = null

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

func tR() -> void:   # tR: nội dung #rdBody
	if rd == null:
		return
	var body: VBoxContainer = rd.get_meta("body")
	for k in body.get_children():
		k.queue_free()
	var t: Dictionary = W.N_()
	var jb: Callable = W._x("Jb")
	var n = jb.call() if jb.is_valid() else null
	if n is Dictionary and n.is_empty():
		n = null
	body.add_child(_lbl("“Đây là Đài phát thanh huyện. Bản tin nông nghiệp buổi " + ("sáng" if G.nv.hour() < 12 else "chiều") + "…”", 13.5, 700, Color8(0x3a, 0x2a, 0x1a)))   # .vl-talk
	var wx := "Đang cập nhật."
	if t.wx.size():
		var L := []
		var nm := ["Khuya", "Sáng", "Chiều", "Tối"]
		for r in 4:
			L.append(nm[r] + ": " + (String(t.wx[r]) if r < t.wx.size() else "").to_lower())
		wx = " · ".join(L)
	body.add_child(_tt("Thời tiết ngày mai", wx))
	var gc := ""
	if t.up.size():
		var L := []
		for e in t.up:
			L.append(G.item_name(e).to_lower() + " (+" + str(W._r((float(G.g.mult[e]) - 1.0) * 100.0)) + "%)")
		gc = "Đang lên giá: " + ", ".join(L) + ". "
	else:
		gc = "Giá cả ổn định. "
	if t.dn.size():
		var L := []
		for e in t.dn:
			L.append(G.item_name(e).to_lower())
		gc += "Đang rẻ: " + ", ".join(L) + ", bà con nên giữ lại chưa bán."
	body.add_child(_tt("Giá cả chợ huyện", gc))
	if n != null:
		var s := ("Hôm nay " + String(n.f.n) + ", chúc bà con vui hội.") if int(n.k) == 0 else ("Còn " + str(int(n.k)) + " ngày nữa tới " + String(n.f.n) + ".")
		if W.O0():
			var vs: Callable = W._x("vS")
			s += " Con nước ròng kế tiếp lúc " + W.mS(vs.call("rong") if vs.is_valid() else null) + "."
		body.add_child(_tt("Tin làng xã", s))
	var b := _btn("Tắt" if rd_cl else "Nghe", false, true, _rd_cl)   # data-rd="cl"
	body.add_child(_tt("Chương trình cải lương", "Vọng cổ, đờn ca tài tử phát liên tục khi mở radio.", b, rd_cl))

func _rd_cl() -> void:   # data-rd="cl": Cf.cl = !Cf.cl, tR() (nhạc: ext cl)
	rd_cl = not rd_cl
	var f := _x("cl")
	if f.is_valid():
		f.call(rd_cl)
	tR()

# ------------------------------------------------------------------ giống nhà hàng xóm (jR)
func jR(t, a: Dictionary, on_buy: Callable) -> Control:   # jR(t = mã nhà, a = nhà {n}); on_buy: dựng lại bảng nhà (kn)
	var v := VBoxContainer.new()
	v.add_child(_sec("Giống nhà " + String(a.n) + " để dư", "Mua lại giống của hàng xóm. Mỗi ngày mỗi thứ chỉ có chừng 6 hạt."))
	for e in W.bZ(t):
		var r := "h" + str(t) + "_" + String(e)
		var o: int = W.G6(r, 6)
		var l: int = W.F6(e)
		var c: bool = o > 0 and int(G.g.coins) >= l
		var btns := [_btn("Mua 1", c, c, _um.bind(r + "|" + String(e) + "|1|" + str(l) + "|6", on_buy))]
		if o >= 3:
			btns.append(_btn("Mua 3", false, int(G.g.coins) >= l * 3, _um.bind(r + "|" + String(e) + "|3|" + str(l) + "|6", on_buy)))
		v.add_child(_rec(String(e), "Giống " + String(G.crop(e).name).to_lower(),
			G.fmt_n(l) + " xu một hạt · còn " + str(o) + " hạt · kho có " + str(int(G.g.barn.get(e, 0))), [], btns))
	return v
