extends "res://logic/ui_ls.gd"
# BẢNG NHÂN VẬT (bấm hình đại diện #pcAv), kiểu bảng trang bị game online, dựng từ khối dùng chung của game:
# khung + hàng tab của bảng sổ (ui_ls.gd), ô trang bị = thẻ Kho › Đồ dùng (ui/snap/kdd.json: u2vt, viền xanh khi chọn,
# số cấp góc thẻ), khung chi tiết món đang chọn = khung chi tiết Đồ dùng (u2vd: hình, tên, "Có…", nút), thẻ thông tin .vlcard
# (.nvsh + thanh), nút .utbig.
#   Tab Nhân vật: hình nhân vật đang đứng (ảnh tạm: khung đứng của nhân vật trên làng) giữa 2 cột ô trang bị:
#     trái Nón / Áo / Quần / Dép (đồ mặc, chưa có), phải Bình tưới / Liềm / Cuốc / Gùi (đồ nghề cấp 0-3);
#     hàng dưới Xe đạp / Xuồng ba lá / Bùa / Bùa EXP. Chạm ô: chi tiết + nút Sắm / Nâng / Mở túi.
#     Dưới: cấp, kinh nghiệm, sức (+ ăn hồi sức), chỉ số (tốc độ đi, việc đã làm), Về nhà ngủ.
#   Tab Nuôi thêm, Diều, Lờ lọp: thân của w_ca_ui (tab_body).

const KDD := "kdd"
# (Link 11-23 "bỏ câu cũ đi"): tab Câu cá cũ bỏ, câu cá giờ là minigame Câu Cá Bờ Kênh (Menu > Giải trí, ui_cc.gd)
const TABS := [["nv", "Nhân vật"], ["nuoi", "Nuôi thêm"], ["dieu", "Diều"], ["lo", "Lờ lọp"]]
const WTABS := ["nuoi", "dieu", "lo"]
const LEFT := ["non", "ao", "quan", "dep"]
const RIGHT := ["binh", "liem", "cuoc", "gui"]
const BOT := ["xe", "xuong", "bua", "xp"]
const MAC := {"non": "Nón", "ao": "Áo", "quan": "Quần", "dep": "Dép"}

var K := {}
var tab := "nv"
var sel := "binh"
var wc: Control = null      # thân tab w_ca_ui
var pic: Control = null     # hình nhân vật

func _init(ui) -> void:
	super(ui)
	K = Snap.load_snap(KDD)

func open(t := "") -> void:
	if t == "cau":   # câu cũ đã bỏ: mở minigame câu cá
		U.ccp.open()
		return
	if t != "":
		tab = t
	U.close_all()
	U.kho_close()
	on = true
	scroll = 0.0
	sig = ""
	_build()

func close() -> void:
	if wc != null and is_instance_valid(wc) and wc.get_parent() != null:
		wc.get_parent().remove_child(wc)   # bảng câu dùng lại lần sau, không để khung cũ xoá mất
	wc = null   # hình nhân vật (pic) giữ theo bảng cất
	super()

func step(dt := 0.25) -> void:
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 0.5
	if _sig() != sig:
		_build()

func _sig() -> String:
	var p: Dictionary = G.g.pc
	return JSON.stringify([tab, sel, p.lv, p.xp, int(floor(float(p.en))), p.get("tools"), p.get("xe"), p.get("xuong"), G.bh(), int(G.bh_left() / 60000.0),
		int(G.nv.Fu() / 60000.0), G.g.coins, G.mat_n("gach"), p.get("n")]) if tab == "nv" else tab

func _tab_go(k: String) -> void:
	if tab != k:
		tab = k
		scroll = 0.0
		sig = ""

# ------------------------------------------------------------------ dựng
func _build() -> void:
	sig = _sig()
	var L := TABS.map(func(x): return [x[0], x[1], false])
	var blocks: Array
	if WTABS.has(tab) and G.w_all != null and G.w_all.WCAU != null:
		wc = G.w_all.WCAU.tab_body(tab)
		var h: float = maxf(200.0, wc.get_combined_minimum_size().y / Css.K)
		blocks = [{"z": 0.75, "tag": "div", "id": "", "cls": "pcw", "r": [16.5, 0.0, 305.0, h], "css": {"display": "block", "position": "static"}, "kids": [], "nw": str(Time.get_ticks_msec())}]
	else:
		wc = null
		blocks = _nv()
	_ls_build(L, tab, _tab_go, blocks)
	if wc != null:   # thân tab w_ca_ui đặt vào khối giữ chỗ
		var hold = ids.get(".pcw")
		if hold != null:
			wc.custom_minimum_size.x = hold.size.x
			hold.add_child(wc)
	else:
		var fig = ids.get(".pcfig")
		if fig != null and (pic == null or not is_instance_valid(pic) or pic.get_parent() != fig):
			pic = PcPic.new()
			pic.farm = U.F
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fig.add_child(pic)
		if pic != null and fig != null:   # giữa 2 cột ô trang bị
			var cw := float(K.li.r[2])
			var ch := float(K.li.kids[0].r[3])
			var a := Rect2(cw + 8.0, 4.0, 305.0 - 2.0 * cw - 16.0, 4.0 * (ch + 4.5) - 12.0)
			pic.position = a.position * Css.K
			pic.size = a.size * Css.K

# ô trang bị: [hình (ui/svg/kh), tên, số góc thẻ ("" = không), có chưa]
func _slot(k: String) -> Array:
	var p: Dictionary = G.g.pc
	if MAC.has(k):
		return ["pc_" + k, MAC[k], "", false]
	if RIGHT.has(k):
		var t: int = G.fd(k)
		var nm := ""
		for o in G.TOOLS:
			if o.id == k:
				nm = String(o.n)
		return ["pc_" + k, nm, ("c" + str(t)) if t > 0 else "", t > 0]
	match k:
		"xe":
			return ["pc_xe", "Xe đạp", "", bool(p.get("xe", 0))]
		"xuong":
			return ["pc_xuong", "Xuồng ba lá", "", bool(p.get("xuong", 0))]
		"bua":
			var b: String = G.bh()
			return ["*bua", String(G.BUFFS[b].n) if b != "" else "Bùa", "", b != ""]
		"xp":
			var n := 0
			for v in G.nv.A3().values():
				n += int(v)
			return ["*bua", "Bùa EXP", str(n) if n > 0 else "", G.nv.Fu() > 0.0 or n > 0]
	return ["", k, "", false]

func _scard(k: String, x: float, y: float) -> Dictionary:   # thẻ u2vt của Đồ dùng
	var s := _slot(k)
	var on_ := k == sel
	var li := _cl(K.li)
	var b: Dictionary = li.kids[0]
	b.css = _cl(K.sel_css if on_ else K.li.kids[0].css)
	if not s[3]:
		b.css["opacity"] = "0.6"
	var ic := Snap.find(b, "u2vi")
	if not ic.is_empty() and ic.get("kids", []).size():
		ic.kids[0].svg = K.ic_bua if s[0] == "*bua" else FileAccess.get_file_as_string("res://ui/svg/kh/" + String(s[0]) + ".svg")
	var nn := Snap.find(b, "u2vn")
	nn.text = String(s[1])
	nn.tr = nn.r.duplicate()
	var bc := Snap.find(b, "u2vc")
	if not bc.is_empty():
		if String(s[2]) != "":
			bc.css = _cl(Snap.find(K.li0 if on_ else K.li, "u2vc").css)
			var w := _tw(bc, String(s[2]))
			bc.text = String(s[2])
			var bw := maxf(float(bc.r[2]), w + 6.0)
			bc.r = [float(bc.r[0]) + float(bc.r[2]) - bw, bc.r[1], bw, bc.r[3]]
			bc.tr = [float(bc.r[0]) + (bw - w) * 0.5, bc.tr[1], w, bc.tr[3]]
		else:
			b.kids.erase(bc)
	b.act = func(): sel = k
	_mv(li, x, y)
	li.r[3] = float(b.r[3])
	return li

func _nv() -> Array:
	var out := []
	# hình + ô trang bị
	var cw := float(K.li.r[2])
	var ch := float(K.li.kids[0].r[3])
	var gap := 4.5
	var x0 := 16.5
	var x1 := 321.5 - cw
	var y0 := 0.0
	var kids := []
	for i in 4:
		kids.append(_scard(LEFT[i], x0, y0 + i * (ch + gap)))
		kids.append(_scard(RIGHT[i], x1, y0 + i * (ch + gap)))
	var yb := y0 + 4 * (ch + gap) + 3.0
	var bx := (305.0 - 4 * cw - 3 * gap) * 0.5
	for i in 4:
		kids.append(_scard(BOT[i], 16.5 + bx + i * (cw + gap), yb))
	var H := yb + ch
	var fig := {"z": 0.75, "tag": "div", "id": "", "cls": "pcfig", "r": [16.5, 0.0, 305.0, H], "css": {"display": "block", "position": "static"}, "kids": kids}
	out.append(fig)
	# chi tiết món đang chọn
	out.append(_det())
	# thông tin
	var p: Dictionary = G.g.pc
	var lv: int = int(p.lv)
	var need: int = G.xp_need(lv)
	var em: float = G.en_max()
	out.append(_sec2("Thông tin"))
	out.append(_card_nv(UT.card, "Cấp " + str(lv), [["Kinh nghiệm ", false], [str(int(p.xp)) + "/" + str(need), true]], float(p.xp) / maxf(1.0, need),
		[["Đã làm ", false], [G.fmt_n(int(p.get("n", 0))), true], [" việc trong làng.", false]]))
	out.append(_card_nv(UT.card, "Sức", [[str(int(floor(float(p.en)))) + "/" + str(int(em)), true]], float(p.en) / maxf(1.0, em),
		[["Tự hồi 4 sức mỗi phút" + (", đang mệt nên đi chậm." if float(p.en) < 1.0 else "."), false]]))
	var sp: float = G.speed(3.0)
	out.append(_card_nv(UT.card, "Chỉ số", [], null, [["Tốc độ đi ", false], [str(snappedf(sp, 0.1)).replace(".", ",") + " ô/giây", true],
		[(" (xe đạp +70% khi đi xa)" if p.get("xe", 0) else ""), false], [". Bùa đang có: ", false], [(String(G.BUFFS[G.bh()].n)) if G.bh() != "" else "không", true], [".", false]]))
	out.append(_big("Về nhà ngủ", "plain", true, func():
		close()
		U.F.sleep_go()))
	return out

func _det() -> Dictionary:   # khung chi tiết u2vd (Đồ dùng): hình, tên, dòng nhỏ, nút, lời tả
	var s := _slot(sel)
	var d := _cl(K.det0)
	var ic := Snap.find(d, "u2vi")
	if ic.get("kids", []).size():
		ic.kids[0].svg = K.ic_bua if s[0] == "*bua" else FileAccess.get_file_as_string("res://ui/svg/kh/" + String(s[0]) + ".svg")
	var dt := Snap.find(d, "u2vdt")
	var go := Snap.find(d, "u2vgo")
	var ds := Snap.find(d, "u2vds")
	var nm := String(s[1])
	var sm := ""
	var tx := ""
	var bl := ""
	var act = null
	var ok := true
	if MAC.has(sel):
		sm = "Chưa mặc"
		tx = "Đồ mặc (nón, áo, quần, dép) sẽ có ở Tủ đồ. Sắp có."
	elif RIGHT.has(sel):
		var t: int = G.fd(sel)
		nm += " · cấp " + str(t)
		sm = G.tool_desc(sel, t)
		if t >= 3:
			tx = "Đã nâng tối đa."
		else:
			var c: Array = G.TOOL_COST[t]
			tx = "Cấp " + str(t + 1) + ": " + G.tool_desc(sel, t + 1) + "."
			bl = ("Sắm" if t == 0 else "Nâng") + " · " + G.fmt_n(int(c[0])) + " xu" + ((" + " + str(c[1]) + " gạch") if int(c[1]) > 0 else "")
			ok = int(G.g.coins) >= int(c[0]) and G.mat_n("gach") >= int(c[1])
			var kk := sel
			act = func(): G.tool_up(kk)
	elif sel == "xe" or sel == "xuong":
		var a := {}
		for o in G.RIDES:
			if o.id == sel:
				a = o
		var has := bool(G.g.pc.get(sel, 0))
		sm = "Đã có" if has else ("Cần cấp " + str(a.lv) if G.lv() < int(a.lv) else "Chưa có")
		tx = String(a.d) + "."
		if not has:
			bl = "Sắm · " + G.fmt_n(int(a.xu)) + " xu"
			ok = G.lv() >= int(a.lv) and int(G.g.coins) >= int(a.xu)
			var kk2 := sel
			act = func(): G.ride_buy(kk2)
	elif sel == "bua":
		var b: String = G.bh()
		if b != "":
			sm = "Còn " + U.kdp.MA(G.bh_left())
			tx = String(G.BUFFS[b].d) + "."
		else:
			sm = "Chưa có bùa"
			tx = "Bùa (Chân sáo, Tay mát, Dẻo dai, Sáng dạ, No ấm, Tay câu đỏ) có từ chùa, lễ hội, sự kiện."
	elif sel == "xp":
		var f: float = G.nv.Fu()
		sm = ("Đang chạy · còn " + U.kdp.MA(f)) if f > 0.0 else "Chưa dùng"
		tx = "+50% kinh nghiệm. Bùa cất trong Kho › Đồ dùng, dùng thêm thì cộng dồn thời gian."
		bl = "Mở túi đồ dùng"
		act = func():
			close()
			U.kho_open()
			U._kho_tab(2)
	dt.kids[0].text = nm
	dt.kids[1].text = sm
	if bl == "" or act == null:
		d.kids.erase(go)
	else:
		var w := _tw(go, bl)
		var bw := w + _px(go, "padding-left") + _px(go, "padding-right") + 4.0
		go.r = [float(go.r[0]) + float(go.r[2]) - bw, go.r[1], bw, go.r[3]]
		go.text = bl
		go.tr = [float(go.r[0]) + (bw - w) * 0.5, go.tr[1], w, go.tr[3]]
		dt.r[2] = float(go.r[0]) - 6.0 - float(dt.r[0])
		_act(go, act, ok)
	ds.kids[0].text = tx
	d.dx = -16.5
	return d

# ------------------------------------------------------------------ hình nhân vật (ảnh tạm: khung đứng nhìn ra của nhân vật trên làng)
class PcPic extends Control:
	var farm
	func _process(_dt: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var P = farm.P
		var m: Dictionary = P.meta("nv_walk")
		var tx: Texture2D = P.tex("nv_walk", "sheet")
		if m.is_empty() or tx == null:
			return
		var dir := 0
		var n := int(m["n"])
		var fr := int(m["stand"][dir])
		var fw := float(m["fw"])
		var fh := float(m["fh"])
		var per := maxi(1, int(tx.get_width() / fw))
		var j := dir * n + fr
		var src := Rect2((j % per) * fw, (j / per) * fh, fw, fh)
		var h := size.y
		var w := h * fw / fh
		draw_texture_rect_region(tx, Rect2((size.x - w) * 0.5, 0, w, h), src)
