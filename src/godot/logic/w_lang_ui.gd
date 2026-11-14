extends RefCounted
# DÂN LÀNG (giao diện): phần bảng bản web còn thiếu ở bản Godot.
#  - ngcTabNghe: tab "Nghề" của bảng Nghề thủ công: thẻ nghề chính, thẻ từng nghề đã học (sao, điểm, nguyên liệu, điều kiện thi,
#    nút Làm / Thi lên / Chọn - Bỏ nghề chính: data-ngc -> ngcClick của hệ khác), danh sách "Nghề chưa học".
# Dựng bằng Control thường của Godot như w_cho_ui.gd; người gọi dựng lại khi chữ ký đổi, không vẽ mỗi khung.

const Css = preload("res://ui/css.gd")

var U          # ui.gd
var G          # game.gd
var W          # w_lang.gd
# ext: việc của hệ khác (bộ ráp gán)
#   ngcClick(act: String, b: String)   (nút data-ngc="lam|thi|chinh" data-v=b của bảng Nghề)
#   arm() -> String                    (NGCV.arm: nghề đang chờ bấm lần nữa để bỏ nghề chính)
var ext := {}

func _init(ui, wl) -> void:
	U = ui
	G = ui.G
	W = wl
	W.ui = self

func _x(k: String) -> Callable:
	var c = ext.get(k)
	return c if c is Callable and (c as Callable).is_valid() else Callable()

static func _k(v: float) -> float:
	return v * Css.K

# ------------------------------------------------------------------ khối dựng chung (như w_cho_ui.gd)
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

func _note(s: String) -> Control:   # p.note
	return _lbl(s, 12, 400, Color8(0x8a, 0x7a, 0x6a))

func _card() -> VBoxContainer:   # .vlcard
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(0xff, 0xff, 0xff)
	sb.border_color = Color8(0xe8, 0xdc, 0xc4)
	sb.set_border_width_all(int(maxf(1.0, _k(1))))
	sb.set_corner_radius_all(int(_k(12)))
	sb.content_margin_left = _k(10)
	sb.content_margin_right = _k(10)
	sb.content_margin_top = _k(8)
	sb.content_margin_bottom = _k(8)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(_k(4)))
	p.add_child(v)
	v.set_meta("box", p)
	return v

func _nvsh(left: String, right: String) -> Control:   # .nvsh: <b>trái</b><span>phải</span>
	var h := HBoxContainer.new()
	var a := _lbl(left, 13.5, 800, Color8(0x3a, 0x2a, 0x1a))
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(_lbl(right, 12, 600, Color8(0x8a, 0x6a, 0x48), false))
	return h

func _chip_row(id: String, have: int, q: int, tail: String) -> Control:   # .chip ok|no: Ai <b>có</b>/cần tên
	var n := mini(have, q)
	var h := HBoxContainer.new()
	h.add_child(_ic(id, 20))
	h.add_child(_lbl(str(n) + "/" + str(q) + " " + String(G.item(id).get("name", id)) + tail, 12, 600, Color8(0x2f, 0x7a, 0x2a) if n >= q else Color8(0xc0, 0x3a, 0x2a), false))
	return h

func _nc(t: String, a: int) -> Control:   # nc
	return _chip_row(t, int(G.g.barn.get(t, 0)), a, "")

func _need(chips: Array) -> Control:   # .need
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", int(_k(8)))
	for c in chips:
		f.add_child(c)
	return f

func _ngc(act: String, b: String) -> void:   # data-ngc
	var f := _x("ngcClick")
	if f.is_valid():
		f.call(act, b)

func build_tab_nghe(box: Container) -> void:   # ngcTabNghe
	var n: Dictionary = W.t6()
	var H: Dictionary = W.hn_s()
	var S: Dictionary = W.ng_s()
	var K: Dictionary = G.g.hnk.d if G.g.get("hnk") is Dictionary and G.g.hnk.get("d") is Dictionary else {}
	var L: int = W.ng_lock()
	var nl: int = W.hn_learned()
	var hc: int = W.ng_hoc_cho()
	var M6: Array = W.M6
	var fa := _x("arm")
	var arm = fa.call() if fa.is_valid() else ""
	if L:
		box.add_child(_note("🔒 Nghề thủ công mở ở cấp " + str(L) + ". Giờ xem trước được, tới cấp mới học, mới làm."))
	var c0 := _card()
	c0.add_child(_nvsh("Nghề chính " + str(S.chinh.size()) + "/" + str(W.NGCHINH), "đã học " + str(nl) + "/" + str(M6.size())))
	c0.add_child(_lbl("Học ở nhà thầy (tab Sở trường), cả dòng họ chung một nghề. Mỗi món làm ra +1 điểm tay nghề, tối đa " + str(W.ht_ngay()) + " điểm một ngày mỗi nghề. Đủ điểm, đủ hàng đã làm thì qua thầy thi lên sao. Chỉ " + str(W.NGCHINH) + " nghề chính lên được 4★, 5★." +
		((" Nghề kế tiền học " + G.fmt_n(W.hn_hp()) + " xu" + ((", " + str(hc) + " ngày nữa mới theo học nghề mới") if hc else "") + ".") if nl < M6.size() else ""), 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
	box.add_child(c0.get_meta("box"))
	var own := M6.filter(func(gx): return W._tr(n.get(gx.id)) and W.ng_base(gx.id) != "")
	var rest := M6.filter(func(gx): return not W._tr(n.get(gx.id)) and W.ng_base(gx.id) != "")
	for gx in own:
		var b := String(gx.id)
		var s: int = W.ng_sao(b)
		var q: Array = S.hq.get(b) if S.hq.get(b) is Array else [0, 0]
		var R: Array = W.ng_rate(b)
		var mx: int = W.ng_max(b)
		var ok: bool = not L and W.q_s(gx)
		var C: Array = W.ng_thi_cond(b)
		var rd: bool = W.ng_thi_ready(b)
		var ch: bool = W.ng_chinh(b)
		var hu: int = W._i(K[b].get("h")) if K.get(b) is Dictionary else 0
		var cd := _card()
		cd.add_child(_nvsh(String(gx.n) + " " + W.ng_stars(s), "nghề chính" if ch else "tối đa 3★"))
		cd.add_child(_lbl("Đã làm " + str(W._i(S.mk.get(b))) + " món · khéo " + W._sv(q[0]) + " · tinh xảo " + W._sv(q[1]) + " · hôm nay +" + str(W.ng_diem_nay(b)) + "/" + str(W.ht_ngay()) + " điểm · ra khéo " + str(W._rnd(float(R[0]) * 100)) + "%" + ((", tinh xảo " + str(W._rnd(float(R[1]) * 100)) + "%") if float(R[1]) else "") + " · chợ trả " + G.fmt_n(G.price(b)) + " xu" + ((" · làm thử hư " + str(hu) + " lần") if hu else ""), 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
		var chips := []
		for x in gx["in"]:
			chips.append(_nc(String(x[0]), int(x[1])))
		cd.add_child(_need(chips))
		if s < mx and C.size():
			var lines := []
			for x in C:
				lines.append(("✓ " if x[0] else "✗ ") + String(x[1]))
			cd.add_child(_sec("Thi lên " + str(s + 1) + "★", "\n".join(PackedStringArray(lines))))
		elif s >= 5:
			cd.add_child(_lbl("Thợ cả, tay nghề cao nhất.", 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
		else:
			cd.add_child(_lbl("Tới 3★ rồi. Chọn làm nghề chính mới lên tiếp được.", 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
		var jobs := HFlowContainer.new()   # .vl-jobs
		jobs.add_theme_constant_override("h_separation", int(_k(6)))
		jobs.add_child(_btn("Làm", ok, ok, func(): _ngc("lam", b)))
		if s < mx:
			jobs.add_child(_btn("Thi lên " + str(s + 1) + "★", rd, rd, func(): _ngc("thi", b)))
		if ch:
			jobs.add_child(_btn("Bấm lần nữa: tụt về 3★" if arm == b else "Bỏ nghề chính", false, true, func(): _ngc("chinh", b)))
		elif S.chinh.size() < W.NGCHINH:
			jobs.add_child(_btn("Chọn nghề chính", false, true, func(): _ngc("chinh", b)))
		cd.add_child(jobs)
		box.add_child(cd.get_meta("box"))
	if rest.size():
		box.add_child(_sec("Nghề chưa học", ""))
		var ls := VBoxContainer.new()   # .lslist
		for gx in rest:
			var p = H.p.get(gx.id)
			var who: Array = W.nghe_who(gx.id)
			var hu: int = W._i(K[gx.id].get("h")) if K.get(gx.id) is Dictionary else 0
			var sub: String
			if p is Dictionary:
				var fp = W._fam_of(p.get("u"))
				sub = ("Đang học" if H.get("a") == gx.id else "Đang gác") + " ở bước " + W._sv(p.st) + "/4" + ((" · nhà " + String(fp.n)) if fp != null else "")
			else:
				sub = (("Học ở nhà " + ", ".join(PackedStringArray(who))) if who.size() else "Làng chưa có dòng họ nào giữ nghề này") + ". " + String(gx.d)
			var row := VBoxContainer.new()   # .lsrow > .lsrn
			row.add_child(_lbl(String(gx.n), 13, 700, Color8(0x3a, 0x2a, 0x1a)))
			row.add_child(_lbl(sub + ((" · làm thử hư " + str(hu) + " lần") if hu else ""), 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
			ls.add_child(row)
		box.add_child(ls)
