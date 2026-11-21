extends "res://logic/ui_kbang.gd"
# BẢNG NGHỀ THỦ CÔNG (ngcOpen / ngcRender bản web, nút "Nghề" trong Menu). (bản 453) làm lại trên khung Kho + chip chung (ui_kbang.gd).
# 3 tab: Nghề (ngcTabNghe), Đơn làng (ngcTabDon), Chợ (ngcTabLai). Đặt thợ, hàng bạn bè, thợ giỏi cần chơi online
# (bản Godot chưa có bạn bè) nên ẩn. Đoạn luật dài đưa vào nút ? cạnh tiêu đề phần. Luật ở w_lang.gd.

var W          # w_lang.gd
var tab := "nghe"           # NGCV.tab
var arm := ""               # NGCV.arm: nút đang chờ bấm lần nữa
var op := ""                # (bản 453) nghề đang mở danh sách điều kiện thi

const TABC := {"nghe": "rgb(176, 136, 70)", "don": "rgb(214, 160, 30)", "cho": "rgb(60, 140, 40)"}
const NGC := {   # màu chip riêng bảng Nghề: [gradient trên, giữa, dưới, viền]
	"nghe": ["rgb(244, 230, 196)", "rgb(248, 238, 210)", "rgb(252, 246, 228)", "rgb(176, 136, 70)"],
	"don": ["rgb(255, 236, 176)", "rgb(255, 242, 198)", "rgb(255, 248, 220)", "rgb(214, 160, 30)"],
}
const CHD := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 10 10\"><path d=\"M2 3.5 L5 6.5 L8 3.5\" fill=\"none\" stroke=\"rgb(128,98,58)\" stroke-width=\"1.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>"   # mũi tên mở
const CHU := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 10 10\"><path d=\"M2 6.5 L5 3.5 L8 6.5\" fill=\"none\" stroke=\"rgb(128,98,58)\" stroke-width=\"1.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>"   # mũi tên đóng
const XM := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 12 12\"><circle cx=\"6\" cy=\"6\" r=\"5.5\" fill=\"rgb(226,90,80)\"/><path d=\"M3.8 3.8 L8.2 8.2 M8.2 3.8 L3.8 8.2\" stroke=\"white\" stroke-width=\"1.6\" stroke-linecap=\"round\"/></svg>"

func _ck(kind: String) -> Array:
	return NGC[kind] if NGC.has(kind) else super(kind)

func _init(ui, wl) -> void:
	super(ui)
	W = wl

func open(t := "") -> void:   # ngcOpen
	if t != "":
		tab = t if TABC.has(t) else "nghe"
	on = true
	arm = ""
	op = ""
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:   # ngcRender mỗi giây
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 0.5
	if _sig() != sig:
		_build()

func _sig() -> String:
	return JSON.stringify([tab, arm, op, G.g.coins, G.g.barn, G.g.get("nghe"), G.g.get("ngs"), G.g.get("ndn"), G.g.get("ndt"), G.g.get("hn"), G.g.get("hnk"), W.ng_lock(), W._vr()])

# ------------------------------------------------------------------ dựng
func _build() -> void:
	sig = _sig()
	var red: bool = W.ng_red() > 0
	var L := [["nghe", "Nghề", false], ["don", "Đơn làng", red], ["cho", "Chợ", false]]
	var sh := _kshell(L, tab, _tab_go)
	var r: Array
	match tab:
		"don":
			r = _don()
		"cho":
			r = _cho()
		_:
			r = _nghe()
	_kmount(sh[0], sh[1], float(sh[2]), r[0], float(r[1]))

func _tab_go(k: String) -> void:   # data-ngc="tab"
	if tab != k:
		tab = k
		scroll = 0.0
		arm = ""
		op = ""

# ------------------------------------------------------------------ khối chung bảng Nghề
func _sq(y: float, t: String, help: String) -> Array:   # tiêu đề phần + nút ? (đoạn luật) ở mép phải
	var out := _sect(y, t, String(TABC[tab]))
	if help != "":
		var rl: Dictionary = out[2]
		rl.r[2] = maxf(0.0, float(rl.r[2]) - 26.0)
		var q := _chip(X0 + XW - 20.0, y - 1.0, 20.0, 18.0, "info")
		q.kids = [_dt(X0 + XW - 20.0, y - 1.0, 20.0, 18.0, "?", 11.0, 800, "rgb(60, 110, 170)")]
		q.act = func(): U.tre_help(t, help)
		out.append(q)
	return out

func _nm(id: String) -> String:
	return String(W._ae(id).get("name", id))

func _sbtn(x: float, y: float, t: String, cb, red := false) -> Array:   # nút phụ nhỏ: chip kem (red: hồng); trả [khối, rộng]
	var w: float = Box.text_w(t, 10.5, 700) + 18.0
	var c := _chip(x, y, w, 26.0, "sen" if red else "fut")
	c.kids = [_dt(x, y, w, 26.0, t, 10.5, 700, "rgb(170, 50, 60)" if red else BROWN)]
	c.act = cb
	return [c, w]

func _stars(x: float, y: float, s: int, mx: int, z := 13.0) -> Array:   # hàng sao: s vàng, tới mx xám
	var out := []
	for i in mx:
		out.append(_pic(x + i * (z + 2.0), y, z, z, "res://ui/img/bong/" + ("sao.png" if i < s else "sao_xam.png")))
	return out

# ------------------------------------------------------------------ tab Nghề (ngcTabNghe)
func _nghe() -> Array:
	var n: Dictionary = W.t6()
	var H: Dictionary = W.hn_s()
	var S: Dictionary = W.ng_s()
	var K: Dictionary = G.g.hnk.get("d", {}) if G.g.get("hnk") is Dictionary and G.g.hnk.get("d") is Dictionary else {}
	var Lk: int = W.ng_lock()
	var nl: int = W.hn_learned()
	var hc: int = W.ng_hoc_cho()
	var out := []
	var y := 6.0
	if Lk:
		var lc := _chip(X0, y, XW, 30.0, "sen")
		lc.kids = [_dt(X0 + 10.0, y, XW - 20.0, 30.0, _fitw("Nghề thủ công mở ở cấp " + str(Lk) + ". Giờ xem trước, tới cấp mới học, mới làm.", 10.5, 700, XW - 20.0), 10.5, 700, "rgb(170, 50, 60)", "left")]
		out.append(lc)
		y += 30.0 + GG
	var help := "Học ở nhà thầy (tab Sở trường bên nhà dân), cả dòng họ chung một nghề. Mỗi món làm ra +1 điểm tay nghề, tối đa " + str(W.ht_ngay()) + \
		" điểm một ngày mỗi nghề. Đủ điểm, đủ hàng đã làm thì qua thầy thi lên sao. Chỉ " + str(W.NGCHINH) + " nghề chính lên được 4 sao, 5 sao. Tay nghề càng cao, món làm ra càng dễ thành hàng khéo, tinh xảo, bán được giá hơn."
	out.append_array(_sq(y, "Nghề chính " + str(S.chinh.size()) + "/" + str(W.NGCHINH) + " · Đã học " + str(nl) + "/" + str(W.M6.size()), help))
	y += 18.0
	if nl < W.M6.size():
		var P := ["Học nghề kế: " + W._sa(W.hn_hp()), "c"]
		if hc:
			P.append(" · " + str(hc) + " ngày nữa mới theo học được")
		out.append_array(_rowi(X0, y, 16.0, P, 10.5, 600, SUB)[0])
		y += 16.0
	y += GG
	var own: Array = W.M6.filter(func(gx): return W._tr(n.get(gx.id)) and W.ng_base(gx.id) != "")
	var rest: Array = W.M6.filter(func(gx): return not W._tr(n.get(gx.id)) and W.ng_base(gx.id) != "")
	for gx in own:
		var c := _card(y, gx, S, Lk)
		out.append_array(c[0])
		y += float(c[1]) + GG
	if rest.size():
		out.append_array(_sq(y, "Nghề chưa học", ""))
		y += 16.0 + GG
		var bt := []
		for gx in rest:
			var p = H.p.get(gx.id)
			var who: Array = W.nghe_who(gx.id)
			var hu: int = W._i(K[gx.id].get("h")) if K.get(gx.id) is Dictionary else 0
			var s := ""
			var k := "fut"   # (bản 453) có thầy dạy: xanh nhạt; đang học: vàng; chưa ai giữ: kem
			if p is Dictionary:
				s = ("Đang học" if H.a == gx.id else "Đang gác") + " bước " + str(p.st) + "/4"
				k = "now"
			elif who.size():
				s = ", ".join(PackedStringArray(who)) + " dạy"
				k = "got"
			else:
				s = "Chưa ai giữ nghề"
			var pid := _pid(gx)
			var tip := String(gx.n) + ": " + String(gx.d) + (" Làm thử hư " + str(hu) + " lần." if hu else "")
			bt.append({"b": String(gx.n), "s": s, "ic": pid, "st": "", "k": k, "act": _dsay.bind(tip)})
		var g := _grid(y, bt, 2, "got")
		out.append_array(g[0])
		y += float(g[1]) + GG
	return [out, y]

func _pid(gx: Dictionary) -> String:   # hình món làm ra của nghề
	return String(gx.id) if not W._ae(gx.id).is_empty() else String(gx["in"][0][0])

func _card(y: float, gx: Dictionary, S: Dictionary, Lk: int) -> Array:   # (bản 453) khối nghề đã học, gọn kiểu "Nhà đang cần"
	var b := String(gx.id)
	var s: int = W.ng_sao(b)
	var mx: int = W.ng_max(b)
	var ok: bool = not Lk and W.q_s(gx)
	var C: Array = W.ng_thi_cond(b)
	var rd: bool = W.ng_thi_ready(b)
	var ch: bool = W.ng_chinh(b)
	var out := []
	var c := _chip(X0, y, XW, 10.0, "nghe")
	out.append(c)
	var x := X0 + 10.0
	var w := XW - 20.0
	var yy := y + 10.0
	# hàng 1: hình, tên, sao tới mức nghề lên được; chip nghề chính (chạm để chọn / bỏ)
	out.append(_icn(x + 15.0, yy + 15.0, 30.0, _pid(gx)))
	var tx := x + 38.0
	var ct: String = ("Bấm lần nữa: tụt về 3 sao" if arm == b else "Nghề chính") if ch else "Chọn làm chính"
	var tg := _tchip(x, yy, ct, ("sen" if arm == b else "got") if ch else "fut", ("rgb(170, 50, 60)" if arm == b else "rgb(46, 120, 50)") if ch else SUB, _chinh.bind(b), 20.0)
	Snap._move(tg[0], Vector2(w - float(tg[1]), 0))
	if ch or S.chinh.size() < W.NGCHINH:
		out.append(tg[0])
	var nw := w - 38.0 - float(tg[1]) - 6.0
	out.append(_dt(tx, yy, nw, 17.0, _fitw(String(gx.n), 12.0, 800, nw), 12.0, 800, BROWN, "left"))
	out.append_array(_stars(tx, yy + 18.0, s, mx))
	yy += 34.0
	# hàng 2: điểm hôm nay, giá chợ
	out.append_array(_rowi(x, yy, 15.0, ["Hôm nay +" + str(W.ng_diem_nay(b)) + "/" + str(W.ht_ngay()) + " điểm · Chợ trả " + W._sa(W.ng_kho(b)), "c"], 10.5, 600, SUB)[0])
	yy += 15.0 + GG
	# hàng 3: món cần (trái) + nút Làm (phải, canh giữa hàng chip)
	var it := []
	for z in gx["in"]:
		it.append([String(z[0]), _nm(String(z[0])), W._barn(String(z[0])), int(z[1])])
	var nd := _nchips(x, yy, w - 74.0, it)
	out.append_array(nd[0])
	out.append(_btn(x + w - 66.0, yy + 4.0, 66.0, 26.0, "Làm", _lam.bind(b), "go" if ok else "off"))
	yy += maxf(34.0, float(nd[1])) + GG
	# thi lên sao: 1 chip gọn, chạm mở danh sách điều kiện có thanh tiến độ
	if s < mx and C.size():
		var nok := 0
		for cc in C:
			nok += 1 if cc[0] else 0
		var oc := op == b
		var tc := _chip(x, yy, w, 30.0, "got" if rd else "fut")
		tc.kids = [_pic(x + 8.0, yy + 8.0, 14.0, 14.0, "res://ui/img/bong/sao.png"), _dt(x + 28.0, yy, w - 120.0, 30.0, "Thi lên " + str(s + 1) + " sao", 11.5, 800, BROWN, "left"),
			_dt(x + w - 100.0, yy, 82.0, 30.0, str(nok) + "/" + str(C.size()) + " điều kiện", 10.5, 700, "rgb(46, 120, 50)" if rd else SUB, "right"),
			_dic(x + w - 17.0, yy + 10.0, 10.0, CHU if oc else CHD)]
		tc.act = _op.bind(b)
		out.append(tc)
		yy += 30.0
		if oc:
			yy += 8.0
			for cc in C:
				var lb: String = String(cc[2]) if cc.size() > 2 else String(cc[1])
				var hv: float = float(cc[3]) if cc.size() > 3 else -1.0
				var nd2: float = float(cc[4]) if cc.size() > 4 else -1.0
				var un: String = String(cc[5]) if cc.size() > 5 else ""
				out.append(_dtick(x + 2.0, yy + 2.0, 11.0) if cc[0] else _dic(x + 2.0, yy + 2.0, 11.0, XM))
				if nd2 > 0.0:
					var P := [W._sa(int(hv)) + "/" + W._sa(int(nd2))]
					if un != "":
						P.append(un)
					var pw := float(_rowi(0.0, 0.0, 15.0, P, 10.5, 800, "")[1])
					out.append(_dt(x + 18.0, yy, w - 24.0 - pw, 15.0, _fitw(lb, 10.5, 600, w - 24.0 - pw), 10.5, 600, BROWN, "left"))
					out.append_array(_rowi(x + w - pw, yy, 15.0, P, 10.5, 800, "rgb(46, 120, 50)" if cc[0] else "rgb(170, 60, 50)")[0])
					out.append_array(_bar(x + 18.0, yy + 17.0, w - 18.0, hv / nd2, 4.0))
					yy += 26.0
				else:
					out.append(_dt(x + 18.0, yy, w - 18.0, 15.0, _fitw(lb, 10.5, 600, w - 18.0), 10.5, 600, BROWN, "left"))
					yy += 19.0
			yy += 4.0
			if rd:
				out.append(_btn(x + w - 84.0, yy, 84.0, 26.0, "Thi lên " + str(s + 1) + " sao", _thi.bind(b), "go"))
				yy += 26.0 + 4.0
		yy += 10.0
	else:
		out.append(_dt(x, yy, w, 15.0, "Thợ cả, tay nghề cao nhất." if s >= 5 else "Tới 3 sao rồi. Chọn làm nghề chính mới lên tiếp được.", 10.5, 700, BROWN, "left"))
		yy += 15.0 + 10.0
	c.r[3] = yy - y
	return [out, yy - y]

func _op(b: String) -> void:   # chạm chip thi: mở / đóng danh sách điều kiện
	op = "" if op == b else b

func _lam(b: String) -> void:   # data-ngc="lam": đóng bảng, nhân vật về nhà làm
	close()
	W.tk(b)

func _thi(b: String) -> void:
	W.ng_thi(b)

func _chinh(b: String) -> void:
	if W.ng_chinh(b) and W.ng_sao(b) > 3 and arm != b:
		arm = b
	else:
		arm = ""
		W.ng_chon_chinh(b)

# ------------------------------------------------------------------ tab Đơn làng (ngcTabDon)
func _don() -> Array:
	var o: Dictionary = W.ng_d()
	var day: int = W._vr()
	var out := []
	var y := 6.0
	var help := "Bà con đặt đồ nghề cho đám cưới, hội đình, nhà gặp nạn, công trình, lễ Tết. Giao đủ được gần gấp đôi giá chợ, thêm thân và uy tín. Quá hạn không giao thì mất thân, mất uy tín; không kịp thì từ chối sớm (trước hạn từ 1 ngày) chỉ bị nửa phạt."
	out.append_array(_sq(y, "Đơn làng", help))
	y += 16.0 + GG
	if not W.ng_on():
		var Lk: int = W.ng_lock()
		out.append(_dt(X0, y, XW, 16.0, ("Lên cấp " + str(Lk) + " thì bà con mới đặt đồ nghề.") if Lk else "Có hàng xóm thì bà con mới đặt đồ nghề.", 11.0, 700, SUB, "left"))
		return [out, y + 16.0 + GG]
	var xau: int = W.ng_xau()
	if xau:
		var pp := _para(X0 + 10.0, y + 30.0, XW - 20.0, "Bỏ hoặc từ chối 3 đơn trong 7 ngày nên bà con chưa đặt hàng mới, đơn đang có chỉ trả 80%.", 10.5, 600, SUB, 14.0)
		var xc := _chip(X0, y, XW, 30.0 + float(pp[1]) + 10.0, "sen")
		out.append(xc)
		out.append(_dt(X0 + 10.0, y + 10.0, XW - 90.0, 16.0, "Đang mang tiếng hứa rồi bỏ", 11.5, 800, "rgb(170, 50, 60)", "left"))
		out.append(_dt(X0 + XW - 90.0, y + 10.0, 80.0, 16.0, "Còn " + str(xau) + " ngày", 10.5, 800, "rgb(170, 50, 60)", "right"))
		out.append_array(pp[0])
		y += float(xc.r[3]) + GG
	if o.l.is_empty():
		out.append(_dt(X0, y, XW, 16.0, "Chưa có đơn nào" + ("." if xau else ", mỗi ngày có đơn mới."), 11.0, 700, SUB, "left"))
		return [out, y + 16.0 + GG]
	for d in o.l:
		var r := _don_c(y, d, day)
		out.append_array(r[0])
		y += float(r[1]) + GG
	return [out, y]

func _don_c(y: float, d: Dictionary, day: int) -> Array:   # khối 1 đơn: tiêu đề + hạn, chip món, thưởng / phạt bằng hình, nút
	var left := int(d.dl) - day
	var ok: bool = W.ng_don_ok(d)
	var f = W._fam_of(d.u) if W._tr(d.get("u")) else null
	var P: Dictionary = W.NGPHAT.get(String(d.get("src", "")), {})
	var out := []
	var c := _chip(X0, y, XW, 10.0, "don")
	out.append(c)
	var x := X0 + 10.0
	var w := XW - 20.0
	var yy := y + 10.0
	var ht: String = "Còn " + str(left) + " ngày" if left > 0 else "Hạn hôm nay"
	var hc := _tchip(x, yy - 1.0, ht, "info" if left > 1 else "sen", "rgb(60, 110, 170)" if left > 1 else "rgb(170, 50, 60)")
	Snap._move(hc[0], Vector2(w - float(hc[1]), 0))
	out.append(hc[0])
	var tw := w - float(hc[1]) - 8.0
	out.append(_dt(x, yy, tw, 16.0, _fitw(String(d.t), 12.0, 800, tw), 12.0, 800, BROWN, "left"))
	yy += 16.0 + GG
	var it := []
	for z in d.it:
		var id: String = W.ng_id(String(z[0]), int(z[2]))
		it.append([id, _nm(id) + (" trở lên" if int(z[2]) == 1 else ""), mini(W.ng_has(String(z[0]), int(z[2])), int(z[1])), int(z[1])])
	var nd := _nchips(x, yy, w, it)
	out.append_array(nd[0])
	yy += float(nd[1]) + GG
	# thưởng
	var Rw := ["Trả " + W._sa(d.xu), "c"]
	if W._tr(d.get("ut")):
		Rw.append(" · +" + W._sv(d.ut) + " uy tín")
	if W._tr(d.get("th")) and f != null:
		Rw.append_array([" · +", "h", " nhà " + String(f.n)])
	out.append_array(_rowi(x, yy, 16.0, Rw, 11.0, 800, "rgb(40, 130, 50)")[0])
	yy += 16.0
	var Pn := []
	if W._tr(P.get("th")) and f != null:
		Pn.append_array(["−" + W._sv(P.th), "h"])
	if W._tr(P.get("ut")):
		Pn.append((" · " if Pn.size() else "") + "−" + W._sv(P.ut) + " uy tín")
	if Pn.size():
		out.append_array(_rowi(x, yy, 15.0, ["Bỏ đơn: "] + Pn, 10.5, 600, "rgb(170, 60, 50)")[0])
		yy += 15.0
	yy += GG
	# nút: phụ bên trái, Giao hàng bên phải
	var id0 := String(d.id)
	var bx := x
	if not ok:
		var a := _sbtn(bx, yy, "Thương lái", _tab_go.bind("cho"))
		out.append(a[0])
		bx += float(a[1]) + 6.0
	var t2 := _sbtn(bx, yy, "Bấm lần nữa để từ chối" if arm == "tu" + id0 else "Từ chối", _tu.bind(id0), true)
	out.append(t2[0])
	out.append(_btn(x + w - 84.0, yy, 84.0, 26.0, "Giao hàng", func(): W.ng_giao(id0), "go" if ok else "off"))
	yy += 26.0 + 10.0
	c.r[3] = yy - y
	return [out, yy - y]

func _tu(id: String) -> void:   # data-ngc="tu": bấm 2 lần
	if arm != "tu" + id:
		arm = "tu" + id
	else:
		arm = ""
		W.ng_tu_choi(id)

# ------------------------------------------------------------------ tab Chợ (ngcTabLai): thương lái, chạm chip là mua
func _cho() -> Array:
	var out := []
	var y := 6.0
	out.append_array(_sq(y, "Thương lái", "Chở hàng nghề từ chợ huyện: chỉ có hàng thường, giá gấp 3, mỗi món 1 cái một ngày. Chạm vào món để mua."))
	y += 16.0 + GG
	var L: Dictionary = W.ng_lai()
	var g := 6.0
	var bw := (XW - g) * 0.5
	var bh := 44.0
	var i := 0
	for x0 in W.M6:
		if W.ng_base(x0.id) == "":
			continue
		var id := String(x0.id)
		var p: int = W._ai(id) * 3
		var n: int = 1 + int(W.htv("t_lai")) - W._i(L.n.get(id))
		var cx := X0 + (i % 2) * (bw + g)
		var cy := y + floorf(i / 2.0) * (bh + g)
		var c := _chip(cx, cy, bw, bh, "fut" if n > 0 else "miss")
		var tx := cx + 42.0
		var tw := cx + bw - 6.0 - tx
		var ks := [_icn(cx + 21.0, cy + bh * 0.5, 26.0, id), _dt(tx, cy + 6.0, tw, 15.0, _fitw(_nm(id), 11.5, 800, tw), 11.5, 800, BROWN if n > 0 else "rgb(120, 112, 98)", "left")]
		if n > 0:
			var rich: bool = W._n(G.g.coins) >= p
			ks.append_array(_rowi(tx, cy + 22.0, 14.0, [W._sa(p), "c", " · còn " + str(n)], 10.5, 700, SUB if rich else "rgb(190, 60, 50)")[0])
			c.act = (func(): W.ng_lai_mua(id)) if rich else _dsay.bind("Thiếu xu: " + _nm(id) + " giá " + W._sa(p) + " xu.")
		else:
			ks.append(_dt(tx, cy + 22.0, tw, 14.0, "Hết, mai ghé lại", 10.5, 600, "rgb(130, 124, 112)", "left"))
		c.kids = ks
		out.append(c)
		i += 1
	var rows := int(ceil(i / 2.0))
	y += rows * bh + maxf(0, rows - 1) * g + GG
	return [out, y]
