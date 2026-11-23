extends "res://logic/w_ui_base.gd"
# Giao diện lờ lọp, thú cưng, tát ao, thả diều: chép nội dung và nút từ bản web.
#  - (bản 527) tab Câu cá cũ đã bỏ: câu cá = minigame logic/cc (ui_cc.gd).
#  - tab Nuôi thêm (QQ + nút data-pet của GV), tab Diều (zh "dieu"), tab Lờ lọp (zh "lo") trong bảng nhân vật.
#  - thanh chọn chỗ thả .visitbar.pickbar (wg / f6).
#  - bảng Tát ao bắt cá (y4: #tMsg, #tBag, nút data-trui / data-tve) và Thi diều (dU: #kMsg, nút Kéo dây data-kp / Xong data-kd).
# Khung canvas (SX, _K, gU) là phần vẽ: ở đây chỉ chừa chỗ (Control) và nhận chạm; lớp vẽ đọc R.ai / R.zi.
# Dựng bằng Control thường (bản web không có bản chụp số đo cho mấy bảng này), cỡ theo Css.K như w_cho_ui.gd.


var R          # w_ca.gd

# thanh chọn chỗ
var pick: Control = null
# tát ao, thi diều
var tat: Control = null
var _t := {}
var kite: Control = null
var _kt := {}

func _init(ui, rules) -> void:
	U = ui
	G = ui.G
	R = rules
	R.ui = self

# ------------------------------------------------------------------ khối dựng chung
func _note(s: String) -> Label:   # p.note
	return _lbl(s, 12, 400, Color8(0x8a, 0x7a, 0x6a))

func _sec(b: String, small: String) -> Control:   # .vl-sec
	var v := VBoxContainer.new()
	v.add_child(_lbl(b, 14, 800, Color8(0x3a, 0x2a, 0x1a)))
	if small != "":
		v.add_child(_lbl(small, 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
	return v

func _tt(b: String, small: String, btns: Array, got := false) -> Control:   # .tt: <div><b/><small/></div> + nút
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(_k(8)))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_lbl(b, 13.5, 800, Color8(0x2f, 0x7a, 0x2a) if got else Color8(0x3a, 0x2a, 0x1a)))
	if small != "":
		v.add_child(_lbl(small, 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
	h.add_child(v)
	if btns.size():
		var j := HBoxContainer.new()   # .vl-jobs
		j.add_theme_constant_override("separation", int(_k(6)))
		for b2 in btns:
			j.add_child(b2)
		h.add_child(j)
	return h

func _jobs(btns: Array) -> Control:   # .vl-jobs
	var j := HFlowContainer.new()
	j.add_theme_constant_override("h_separation", int(_k(6)))
	j.add_theme_constant_override("v_separation", int(_k(6)))
	for b in btns:
		j.add_child(b)
	return j

func _chip(ic: Control, s: String, ok: bool) -> Control:   # .chip ok|no
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(_k(3)))
	if ic != null:
		h.add_child(ic)
	h.add_child(_lbl(s, Qty.FS, Qty.FW, Qty.color(ok), false))   # (bản 291) chữ có/cần chung (qty.gd)
	return h

func _overlay(title: String, on_close: Callable) -> Array:   # .raceov > .rbox: [gốc, cột]
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	box.custom_minimum_size = Vector2(minf(U.vsize().x - 32.0, 560.0), 0) * Css.K
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(box)
	ov.add_child(cc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(_k(8)))
	box.add_child(col)
	var hd := HBoxContainer.new()   # .ws-h
	var b := _lbl(title, 17, 800, Color8(0x3a, 0x2a, 0x1a))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(b)
	var x := _btn("×", false, true, on_close)   # .ibtn aria-label Đóng
	x.tooltip_text = "Đóng"
	hd.add_child(x)
	col.add_child(hd)
	U.root.add_child(ov)
	return [ov, col]

func _canvas(w: float, h: float) -> Control:   # <canvas width=w height=h>: chỗ cho lớp vẽ, giữ tỉ lệ
	var c := AspectRatioContainer.new()
	c.ratio = w / h
	c.custom_minimum_size = Vector2(0, _k(160))
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	c.add_child(area)
	return c

static func _down(e) -> bool:
	return (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed) or (e is InputEventScreenTouch and e.pressed)

static func _up(e) -> bool:
	return (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed) or (e is InputEventScreenTouch and not e.pressed)

static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

# ------------------------------------------------------------------ bảng nhân vật: tab Nuôi thêm, Diều, Lờ lọp
func tab_name(id: String) -> String:   # zh[].n()
	if id == "dieu":
		return "Diều"
	if id == "lo":
		var t: int = R.ready_n()
		return "Lờ lọp" + ((" (" + str(t) + ")") if t else "")
	return "Nuôi thêm"

func _ec() -> void:
	var f := _x("ec")
	if f.is_valid():
		f.call()

func tab_body(id: String) -> Control:   # QQ / zh["dieu"].html / zh["lo"].html (+ click)
	match id:
		"nuoi": return _qq()
		"dieu": return _dieu()
		"lo": return _lo()
	return Control.new()

func _qq() -> Control:   # QQ + GV (data-pet)
	var t: Dictionary = R.cc()
	var a: Dictionary = t.vit
	var n: Dictionary = t.ca
	var e: Dictionary = t.meo
	var r: Dictionary = t.chim
	var o: int = G.day()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(_k(8)))
	v.add_child(_note("Nuôi thêm quanh nhà. Chạm vào con vật trên cảnh để nhân vật ra cho ăn, thu sản phẩm."))
	var pet := func(k: String) -> void:
		if k == "thi":
			R.dq()
		else:
			R.vq(k)
		_ec()
	var nv := int(a.n)
	var vb := []
	if nv < R.t6:
		vb.append(_btn(("Thêm 3 con" if nv else "Mua 3 con, chọn chỗ thả") + " · " + G.fmt_n(R.Nh.vit), false, R.e6(), pet.bind("vit")))
	if nv:
		vb.append(_btn("Đổi chỗ thả", false, true, pet.bind("mvit")))
	v.add_child(_tt("Đàn vịt" + ((" · " + str(nv) + " con · thả ở " + R.o6("vit")) if nv else ""),
		("Đói/no: " + (("còn no " + str(int(ceil(float(a.f) / 60.0))) + " phút") if float(a.f) > 0 else "đang đói") + " · trứng chờ lấy: " + str(a.e) + ". Cho ăn bằng lúa, mỗi con 150 giây đẻ 1 trứng.") if nv else ("Thả đàn vịt xuống ao, hồ hay sông tùy bạn chọn, cho ăn lúa thì đẻ trứng vịt. 3 con " + G.fmt_n(R.Nh.vit) + " xu (tối đa " + str(R.t6) + ")."),
		[_jobs(vb)]))
	var nc := int(n.n)
	v.add_child(_tt("Cá nuôi" + ((" · " + str(nc) + " con · thả ở " + R.o6("ca")) if nc else ""),
		("Lớn " + str(R._rnd(float(n.g) / R.Xf * 100.0)) + "% · " + ("đang no" if float(n.f) > 0 else "đang đói, cần cám") + ". Lớn đủ thì chạm ao để kéo lưới lấy cá tra.") if nc else ("Thả cá giống xuống ao, hồ hay sông tùy bạn chọn, rải cám (bột) cho ăn, khoảng 15 phút được cá tra. 10 con " + G.fmt_n(R.Nh.ca) + " xu."),
		[_btn("Đổi chỗ thả", false, true, pet.bind("mca"))] if nc else [_btn("Chọn chỗ, thả 10 con · " + G.fmt_n(R.Nh.ca), false, R.e6(), pet.bind("ca"))]))
	var mh: bool = R._tr(e["has"])
	v.add_child(_tt("Mèo mướp" + ((" · thân " + str(int(e.get("tim", 0))) + "/10") if mh else ""),
		(("Hôm nay đã ăn." if int(e.fd) == o else "Chưa cho ăn hôm nay (1 cá nhỏ).") + " Cho ăn hôm nay thì sáng mai Mướp tha quà về. Vuốt ve mỗi tiếng +8 sức.") if mh else ("Mèo canh nhà, cho ăn cá mỗi ngày thì sáng ra tha quà về. " + G.fmt_n(R.Nh.meo) + " xu."),
		[] if mh else [_btn("Xin mèo · " + G.fmt_n(R.Nh.meo), false, true, pet.bind("meo"))]))
	var ch: bool = R._tr(r["has"])
	var thi := int(r.gi) >= 3 and int(r.cd) != o
	v.add_child(_tt("Chào mào" + ((" · giọng " + str(r.gi) + "/10") if ch else ""),
		(("Hôm nay đã ăn." if int(r.fd) == o else "Chưa cho ăn hôm nay (chuối hoặc ớt).") + " Mỗi ngày ăn đủ thì giọng hót lên 1. Giọng từ 3 trở lên đem đi thi mỗi ngày một lần.") if ch else ("Lồng chim treo hiên, sáng sáng hót líu lo. Mở ở cấp 4, " + G.fmt_n(R.Nh.chim) + " xu."),
		[_btn("Đã thi hôm nay" if int(r.cd) == o else "Đi thi hót", thi, thi, pet.bind("thi"))] if ch else [_btn("Mua · " + G.fmt_n(R.Nh.chim), false, G.lv() >= 4, pet.bind("chim"))]))
	if not R.e6():
		v.add_child(_note("Vịt và cá cần mặt nước trong đất của bạn: ao sen, hồ, sông Vàm hoặc ao tự đào."))
	return v

func _dieu() -> Control:   # zh "dieu": html + click
	var t: Dictionary = R.fh()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(_k(8)))
	v.add_child(_note("Mùa gió chướng (đông và xuân), chiều 14–18 giờ trời có gió. " + ("Đang có gió, thả diều được!" if R.cg() else "Bây giờ chưa có gió.") + " Đã thắng " + str(int(t.get("cup", 0))) + " lần thi diều."))
	for e in R.k4:
		var id := String(e.id)
		var r: bool = R._tr(t["has"].get(id))
		var cur: bool = t.cur == id
		var b: Button
		if r:
			b = _btn("Đang dùng" if cur else "Chọn", cur, true, func() -> void:   # data-kite
				R.pick_kite(id)
				_ec())
		else:
			b = _btn("Làm · " + G.fmt_n(int(e.xu)) + " xu", false, G.lv() >= int(e.lv), func() -> void:   # data-kbuy
				R.cu(id)
				_ec())
		v.add_child(_tt(String(e.n), String(e.d) + ("" if r else " · mở ở cấp " + str(e.lv)), [b], cur))
	var has_cur: bool = R._tr(t.cur)
	var b1 := _btn("Thu diều về" if R._tr(t.on) else "Thả diều", true, has_cur, func() -> void:   # data-kon
		R.fu()
		_ec())
	var b2 := _btn("Mai thi tiếp" if int(t.td) == G.day() else "Thi diều với tụi nhỏ", false, has_cur and int(t.td) != G.day(), func() -> void:   # data-kcon
		R.du())
	v.add_child(_jobs([b1, b2]))
	return v

func _lo() -> Control:   # zh "lo": html + click
	var t: Dictionary = R.t1()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(_k(8)))
	v.add_child(_note("Mua lờ, lọp, dây câu rồi đặt dưới mương, ao, sông. Để một lúc cá vô, ra thăm lấy cá. Đặt ban đêm, thăm ban đêm được nhiều hơn. Thỉnh thoảng rái cá vô ăn mất. Đã thăm " + str(int(t.n)) + " lần."))
	for n in R.FS:
		var e: Dictionary = R.ns[n]
		var r: int = R.jd(n)
		var o: int = R.qk(n)
		var bait = e.get("bait")
		var key: String = n
		var buy := _btn("Mua · " + G.fmt_n(int(e.xu)), false, r < int(e.max), func() -> void:   # data-lob
			R.uu(key)
			_ec())
		var put := _btn("Đặt", true, o < r, func() -> void:   # data-lop
			R.nk_lo(key))
		v.add_child(_tt(String(e.n) + " · có " + str(r) + "/" + str(e.max) + " · đang đặt " + str(o),
			String(e.d) + " Thăm mỗi " + str(R._rnd(float(e.ms) / 6e4)) + " phút" + ((", mồi " + str(int(bait[1])) + " " + G.item_name(String(bait[0])).to_lower() + " (kho còn " + str(int(G.g.barn.get(bait[0], 0))) + ")") if bait != null else "") + ".",
			[buy, put]))
	if t["set"].size():
		v.add_child(_sec("Đang đặt", "Chạm Thăm để nhân vật lội ra lấy cá."))
		for n in t["set"]:
			var e: Dictionary = R.ns[n.t]
			var r: bool = R.w4(n)
			var key: String = R.bk(n)
			var visit := _btn("Thăm", r, r, func() -> void:   # data-loh
				var g2 := _x("g2")
				if g2.is_valid():
					g2.call()
				var ns_ := _x("Ns")
				if ns_.is_valid():
					ns_.call({"type": "lo", "key": key}))
			var rm := _btn("Gỡ", false, true, func() -> void:   # data-lor
				R.sr(key)
				_ec())
			v.add_child(_tt(String(e.n), ("Có cá rồi" if r else "Còn " + str(int(ceil(R.l6_ms(n) / 6e4))) + " phút") + (" · không mồi" if e.get("bait") != null and not R._tr(n.get("b")) else "") + " · dùng thêm " + str(int(e.use) - int(n.u)) + " lần", [visit, rm], r))
	return v

# ------------------------------------------------------------------ thanh chọn chỗ thả (Ud)
func pick_bar() -> void:   # wg dựng / f6 ẩn
	if pick != null:
		pick.queue_free()
		pick = null
	var y = R.yf
	if y == null:
		return
	var bar := PanelContainer.new()   # .visitbar.pickbar
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(0xff, 0xfa, 0xf0)
	sb.set_corner_radius_all(int(_k(14)))
	sb.content_margin_left = _k(12)
	sb.content_margin_right = _k(12)
	sb.content_margin_top = _k(8)
	sb.content_margin_bottom = _k(8)
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -_k(16)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(_k(10)))
	var v := VBoxContainer.new()
	v.add_child(_lbl(String(y.msg), 13.5, 800, Color8(0x3a, 0x2a, 0x1a), false))
	v.add_child(_lbl(String(y.sub), 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
	v.custom_minimum_size = Vector2(_k(220), 0)
	h.add_child(v)
	h.add_child(_btn("Hủy", false, true, func() -> void:   # data-pk=x
		R.f6(true)))
	bar.add_child(h)
	U.root.add_child(bar)
	pick = bar

# ------------------------------------------------------------------ bảng Tát ao bắt cá
func tat_open() -> void:   # y4: dựng .raceov "Tát ao bắt cá"
	tat_close()
	var p := _overlay("Tát ao bắt cá", func() -> void:   # data-tx
		R.ys())
	tat = p[0]
	var col: VBoxContainer = p[1]
	var cv := _canvas(760.0, 330.0)   # canvas 1520 x 660 (khung 760 x 330)
	var area: Control = cv.get_child(0)
	area.gui_input.connect(func(e) -> void:   # pointerdown -> KK
		if _down(e) and area.size.x > 0 and area.size.y > 0:
			var pp: Vector2 = e.position
			R.kk(pp.x / area.size.x * 760.0, pp.y / area.size.y * 330.0))
	col.add_child(cv)
	_t.area = area
	var msg := _lbl("", 13, 600, Color8(0x3a, 0x2a, 0x1a))   # #tMsg
	col.add_child(msg)
	_t.msg = msg
	var row := HFlowContainer.new()   # #tRow
	row.add_theme_constant_override("h_separation", int(_k(6)))
	var bag := HFlowContainer.new()   # #tBag
	bag.add_theme_constant_override("h_separation", int(_k(6)))
	bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bag)
	col.add_child(row)
	_t.row = row
	_t.bag = bag
	_t.end = false
	tat_draw()

func tat_area() -> Control:   # khung vẽ tát ao (lớp vẽ _K đọc R.ai)
	return _t.get("area") if tat != null else null

func tat_draw() -> void:   # xS + jN + nút kết thúc
	if tat == null or R.ai == null:
		return
	var ai: Dictionary = R.ai
	_t.msg.text = String(ai.msg)
	_clear(_t.bag)
	if ai.got.size():
		for a in ai.got:
			_t.bag.add_child(_chip(_ic(String(a), 20), str(ai.got[a]) + " " + G.item_name(String(a)), true))
	else:
		_t.bag.add_child(_note("Chưa bắt được con nào"))
	if R._tr(ai.get("end")) and not _t.end:
		_t.end = true
		_t.row.add_child(_btn("Nướng trui mời xóm (3 con)", true, int(ai.n) >= 3, func() -> void:   # data-trui -> UK
			R.uk()))
		_t.row.add_child(_btn("Mang về hết", false, true, func() -> void:   # data-tve -> yS
			R.ys()))

func tat_close() -> void:   # ai.ov.remove()
	if tat != null:
		tat.queue_free()
		tat = null
	_t = {}

# ------------------------------------------------------------------ bảng Thi diều
func kite_open() -> void:   # dU: dựng .raceov "Thi diều"
	kite_close()
	var p := _overlay("Thi diều với tụi nhỏ trong xóm", func() -> void:   # data-kx -> AS
		R.as_close())
	kite = p[0]
	var col: VBoxContainer = p[1]
	var cv := _canvas(760.0, 330.0)
	var area: Control = cv.get_child(0)
	area.gui_input.connect(func(e) -> void:   # canvas pointerdown / pointerup
		if _down(e):
			R.kite_hold(true)
		elif _up(e):
			R.kite_hold(false))
	col.add_child(cv)
	_kt.area = area
	var msg := _lbl("", 13, 600, Color8(0x3a, 0x2a, 0x1a))   # #kMsg
	col.add_child(msg)
	_kt.msg = msg
	var b := _btn("Kéo dây", true, true, Callable())   # .rgo data-kp
	b.button_down.connect(func() -> void:
		R.kite_hold(true))
	b.button_up.connect(func() -> void:
		R.kite_hold(false))
	b.mouse_exited.connect(func() -> void:   # pointerleave
		R.kite_hold(false))
	b.pressed.connect(func() -> void:   # data-kd -> AS
		if R.zi != null and R._tr(R.zi.get("done")):
			R.as_close())
	var row := HBoxContainer.new()   # .rrow
	row.add_child(b)
	col.add_child(row)
	_kt.btn = b
	kite_draw()

func kite_area() -> Control:   # khung vẽ thi diều (lớp vẽ gU đọc R.zi)
	return _kt.get("area") if kite != null else null

func kite_draw() -> void:   # #kMsg, nút Xong
	if kite == null or R.zi == null:
		return
	_kt.msg.text = String(R.zi.msg)
	if R._tr(R.zi.get("done")):
		_kt.btn.text = "Xong"

func kite_key(e) -> void:   # wk: phím cách giữ / thả, Esc đóng
	if R.zi == null or not (e is InputEventKey):
		return
	if e.keycode == KEY_SPACE:
		R.kite_hold(e.pressed)
	elif e.keycode == KEY_ESCAPE and e.pressed:
		R.as_close()

func kite_close() -> void:   # zi.ov.remove()
	if kite != null:
		kite.queue_free()
		kite = null
	_kt = {}

