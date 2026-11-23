extends "res://logic/w_ui_base.gd"
# XU, CHỢ, GIÁ, CHỢ NỔI (giao diện): phần bảng bản web còn thiếu ở bản Godot.
#  - jx: bảng Chợ nổi sông Vàm -> (bản 517) ui_cho.gd (khung Kho); ở đây chỉ còn mở / đóng.
#  - mQ: nút viên "Chợ nổi đang họp · tan lúc 9:00" (.ghepill.chopill, .hurry khi còn < 0,4 giờ).
#  - MU / tR: bảng "Đài phát thanh huyện" (#rdBody).
# Dựng bằng Control thường của Godot (bản web không có bản chụp cho các bảng này), cỡ theo Css.K như các bảng khác.


var W          # w_cho.gd
# ext: việc của hệ khác (bộ ráp gán)
#   aN()                  (aN: camera về ghe thứ 2)
#   Ns(t: Dictionary)     (Ns: nhân vật đi tới chỗ {type: "cho", k}) rồi chạy qN -> open_cho(k)
#   cl(on: bool)          (radio: bật / tắt nhạc cải lương, âm thanh)

var rd: Control = null      # bảng radio (Cf)
var rd_cl := false          # Cf.cl
const PILL = preload("res://logic/pill.gd")
var pill: Control = null    # y2
var gpill: Control = null   # vu: nút viên "Ghe thương hồ ghé bến"

func _init(ui, wc) -> void:
	U = ui
	G = ui.G
	W = wc
	W.panel_close.connect(_on_close)

func _on_close() -> void:   # i1: $r.mode === "cho" thì đóng bảng
	close_cho()

# ------------------------------------------------------------------ bảng chợ nổi: (bản 517) ui_cho.gd (khung Kho)
func open_cho(k: int) -> void:   # qN "cho": Ui.sel = k, gu("cho")
	W.tap(k)
	U.cho_open(k)

func close_cho() -> void:   # i1
	if U.chop != null and U.chop.on:
		U.chop.close()

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
		pill = PILL.new(U)
		pill.kind = "su"
		pill.pressed.connect(_pill_go)
		parent.add_child(pill)
	pill.visible = true
	var a := maxf(0.0, W.wm() - G.nv.hour())
	var s := "Chợ nổi đang họp · tan lúc " + str(W.wm()) + ":00"
	if pill.text != s:
		pill.text = s
	pill.hurry = a < 0.4   # .hurry

func _pill_go() -> void:   # y2 click: aN(), Ui.pos && Ns({type: "cho", k: 1})
	var an := _x("aN")
	if an.is_valid():
		an.call()
	var ns := _x("Ns")
	if W.Ui.pos != null and ns.is_valid():
		ns.call({"type": "cho", "k": 1})


# ------------------------------------------------------------------ ghe thương hồ (BUON D / UD / OD)
func _GH():
	return G.w_all.WGH

func open_ghe() -> void:   # OD(), gu("ghe")
	var A = _GH().Ae
	if int(A.st) != 2 and int(A.st) != 1:
		return
	close_ghe()
	U.close_all()
	var cam := _x("camTo")
	if cam.is_valid():
		var q: Array = _GH().vx()
		cam.call(float(q[0]), float(q[1]), 40.0)
	U.ghe_open()   # (bản 515) bảng khung Kho (ui_gh.gd)

func close_ghe() -> void:   # i1
	if U.ghp != null and U.ghp.on:
		U.ghp.close()

func sync_ghe() -> void:   # bảng ui_gh tự dựng lại theo chữ ký
	pass

func ghe_pill_sync(parent: Control) -> void:   # UD: nút viên khi ghe đang vào / đậu bến
	var A = _GH().Ae
	var on: bool = (int(A.st) == 1 or int(A.st) == 2) and W._mode() == "off"
	if not on:
		if gpill != null:
			gpill.visible = false
		return
	if gpill == null:
		gpill = PILL.new(U)
		gpill.kind = "su"
		gpill.pressed.connect(open_ghe)
		parent.add_child(gpill)
	gpill.visible = true
	var t := maxf(0.0, ceil(float(A.left)))
	var s: String = "Ghe thương hồ đang vào bến" if int(A.st) == 1 else "Ghe thương hồ ghé bến · " + String(_GH().cm(t))
	if gpill.text != s:
		gpill.text = s
	gpill.hurry = int(A.st) == 2 and t < 30

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
