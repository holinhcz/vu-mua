extends "res://logic/ui_kbang.gd"
# THIÊN TAI, HOẠN NẠN (tnOpen / tnRender bản web, Sổ làng › Bà con lối xóm). (bản 462) làm lại trên khung Kho + chip chung (ui_kbang.gd).
# 3 tab: Phòng chống (tin báo, việc phòng, công trình đỡ), Gặp nạn (lo cho bà con, nhà gặp nạn + Giúp), Sổ thiên tai.
# Màu, hình theo loại thiên tai (bão, lũ, hạn, dịch, cháy); đồ cần là chip món chung; đoạn luật vào nút ?.
# Luật ở w_duong.gd (tn_prep, tn_help, tn_have, tn_scale, tn_busy, tn_tick), w_lang.gd (tn_s, tn_ok, tn_on, tn_sea).

var W          # w_lang.gd
var WD         # w_duong.gd
var SK := {}   # sky.json: hình thời tiết
var tab := "phong"          # TNV.tab
const TABC := {"phong": "rgb(70, 120, 180)", "nan": "rgb(200, 70, 60)", "so": "rgb(150, 112, 60)"}
const TNC := {   # màu chip theo loại thiên tai (nhạt như dòng việc Sổ nhiệm vụ): [gradient trên, giữa, dưới, viền]
	"tn_bao": ["rgb(222, 228, 236)", "rgb(230, 235, 242)", "rgb(240, 243, 247)", "rgb(130, 146, 170)"],
	"tn_lu": ["rgb(218, 232, 248)", "rgb(228, 239, 251)", "rgb(239, 246, 253)", "rgb(110, 156, 210)"],
	"tn_han": ["rgb(252, 230, 204)", "rgb(253, 237, 218)", "rgb(254, 245, 233)", "rgb(222, 150, 70)"],
	"tn_dich": ["rgb(234, 224, 246)", "rgb(240, 232, 250)", "rgb(246, 241, 252)", "rgb(150, 116, 196)"],
	"tn_chay": ["rgb(250, 220, 214)", "rgb(252, 230, 225)", "rgb(254, 240, 236)", "rgb(214, 100, 80)"],
}
const TNIC := {"bao": "giong", "lu": "mua", "han": "han"}   # hình thời tiết của bảng Trời đất
const FIRE := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M12 2c1 4 5 6 5 11a5 5 0 0 1-10 0c0-2.5 1.2-4 2.5-5.5C10 9.5 10.5 11 12 11.5 11 8 11.5 5 12 2z\" fill=\"rgb(236,96,48)\" stroke=\"rgb(180,60,30)\" stroke-width=\"1\"/><path d=\"M12 13c1.2 1.4 2.5 2.4 2.5 4a2.5 2.5 0 0 1-5 0c0-1.5 1.2-2.6 2.5-4z\" fill=\"rgb(255,206,90)\"/></svg>"
const GERM := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><g stroke=\"rgb(120,80,170)\" stroke-width=\"1.6\" stroke-linecap=\"round\"><path d=\"M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1\"/></g><circle cx=\"12\" cy=\"12\" r=\"5.5\" fill=\"rgb(176,140,220)\" stroke=\"rgb(120,80,170)\" stroke-width=\"1.2\"/><circle cx=\"10.3\" cy=\"10.8\" r=\"1.2\" fill=\"rgb(120,80,170)\"/><circle cx=\"13.6\" cy=\"13.4\" r=\"0.9\" fill=\"rgb(120,80,170)\"/></svg>"
const RIC := {"gach": "svg:res://ui/svg/mat/gach.svg"}   # hình đồ cần lạ (còn lại: "xu" đồng xu, mã món Kho)

func _ck(kind: String) -> Array:
	return TNC[kind] if TNC.has(kind) else super(kind)

func _init(ui, wl, wd) -> void:
	super(ui)
	W = wl
	WD = wd
	SK = Snap.load_snap("sky")

func open(t := "") -> void:   # tnOpen
	if t != "":
		tab = t if TABC.has(t) else "phong"
	on = true
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:   # tnRender mỗi giây
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	return JSON.stringify([tab, W.tn_s(), G.g.coins, G.g.barn, W._r0().get("gach"), W._vr(), W.tn_ok()])

func _build() -> void:
	sig = _sig()
	var o: Dictionary = W.tn_s()
	var ev = W.tn_on(W._vr() + 1) if W.tn_ok() else null
	var nan := false
	for uu in o.nan:
		if not W._tr(o.nan[uu].get("x")):
			nan = true
	var L := [["phong", "Phòng chống", ev != null and WD.tn_red() > 0], ["nan", "Gặp nạn", nan], ["so", "Sổ thiên tai", false]]
	var sh := _kshell(L, tab, _tab_go)
	var r: Array
	match tab:
		"nan":
			r = _nan()
		"so":
			r = _so()
		_:
			r = _phong()
	_kmount(sh[0], sh[1], float(sh[2]), r[0], float(r[1]))

func _tab_go(k: String) -> void:   # data-tn="tab"
	if tab != k:
		tab = k
		scroll = 0.0

# ------------------------------------------------------------------ khối chung
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

func _kic(cx: float, cy: float, s: float, k: String) -> Dictionary:   # hình loại thiên tai
	if TNIC.has(k):
		return _dic(cx - s * 0.5, cy - s * 0.5, s, String(SK.ic[TNIC[k]]))
	return _dic(cx - s * 0.5, cy - s * 0.5, s, FIRE if k == "chay" else GERM)

func _kk(k: String) -> String:   # loại chip theo loại thiên tai
	return "tn_" + k if TNC.has("tn_" + k) else "fut"

func _need(q: Dictionary, act = null) -> Array:   # đồ cần {mã: số} -> mục chip món chung [hình, tên, có, cần, việc khi thiếu]
	var it := []
	for k in q:
		var nm := String(WD.TNRES.get(k, k))
		it.append([String(RIC.get(k, k)), nm.substr(0, 1).to_upper() + nm.substr(1), WD._tn_hv(String(k)), int(q[k]), act])
	return it

func _nxt() -> int:   # số ngày tới trận kế (0 = không tìm thấy trong 60 ngày)
	var d: int = W._vr()
	for n in range(1, 61):
		if W.tn_on(d + n) != null:
			return n
	return 0

# công trình đỡ thiên tai: [tên, hình, có chưa, tác dụng] (bản 462: gộp giếng / lu / ao một ô)
func _ct() -> Array:
	var WR = W.WR
	var wa: bool = WR.tn_waters().size() > 0
	return [["Giếng, lu, ao", "pic:res://ui/img/xt/g_gieng1.webp", wa, "Hạn: ruộng trong vòng 4 ô quanh giếng, lu, ao không khô chết. Có giếng làng thì bớt thêm 1 nhà mất mùa." + ("" if WR.tn_has("well") else " (Chưa có giếng làng.)")],
		["Trạm y tế", "svg:res://ui/svg/mat/yte.svg", WR.tn_has("tramyt"), "Dịch: bớt 1 nhà đau ốm, tiền thuốc còn nửa."],
		["Cầu ván qua sông", "pic:res://ui/img/xt/g_cau1.webp", WR.tn_has("causong"), "Lũ: ruộng ngập hư còn nửa."],
		["Bến ghe", "pic:res://ui/img/xt/g_ben1.webp", WR.tn_has("ben"), "Lũ: ghe chở đồ cứu trợ, nhà ngập cần nửa đồ."],
		["Đình hay trường làng", "pic:res://ui/img/xt/g_nha11.webp", WD.tn_shelter(), "Bão, lũ, cháy: nhà gặp nạn ở tạm, vẫn đi làm thuê được."],
		["Chùa làng", "pic:res://ui/img/xt/g_mieu1.webp", WR.tn_has("chua"), "Phát cơm cứu đói: đồ giúp bớt 30%, nhà gặp nạn gượng dậy sớm 2 ngày."]]

# ------------------------------------------------------------------ tab Phòng chống (tnTabPhong)
func _phong() -> Array:
	var out := []
	var y := 6.0
	if not W.tn_ok():
		var lc := _chip(X0, y, XW, 40.0, "info")
		lc.kids = [_dt(X0 + 10.0, y + 5.0, XW - 20.0, 15.0, "Lên cấp " + str(W.TNLV) + " mới gặp thiên tai.", 11.0, 800, "rgb(50, 96, 150)", "left"),
			_dt(X0 + 10.0, y + 20.0, XW - 20.0, 15.0, "Tới lúc đó, trước mỗi trận 1 ngày sẽ có tin báo.", 10.5, 600, "rgb(70, 110, 160)", "left")]
		out.append(lc)
		y += 40.0 + GG
	else:
		var o: Dictionary = W.tn_s()
		var day: int = W._vr()
		var ev = W.tn_on(day + 1)
		if ev != null:
			var k := String(ev.k)
			var K: Dictionary = WD.TNK[k]
			# tin báo: chip màu loại thiên tai, hình, tiêu đề, câu tả, chip Đêm nay
			var pp := _para(X0 + 56.0, y + 30.0, XW - 66.0, String(K.d), 10.5, 600, BROWN, 14.0)
			var h := maxf(30.0 + float(pp[1]) + 10.0, 60.0)
			var c := _chip(X0, y, XW, h, _kk(k))
			out.append(c)
			out.append(_kic(X0 + 28.0, y + h * 0.5, 34.0, k))
			var dn := _tchip(X0, y + 9.0, "Đêm nay", "sen", "rgb(170, 50, 60)")
			Snap._move(dn[0], Vector2(XW - 10.0 - float(dn[1]), 0))
			out.append(dn[0])
			var tw := XW - 66.0 - float(dn[1]) - 6.0
			out.append(_dt(X0 + 56.0, y + 10.0, tw, 17.0, _fitw(String(K.w), 12.0, 800, tw), 12.0, 800, BROWN, "left"))
			out.append_array(pp[0])
			y += h + GG
			# phòng trước: 2 khối việc
			out.append_array(_sq(y, "Phòng trước", "Chỉ làm được trong hôm nay. Giữ ruộng thì ruộng đỡ hư, giữ làng thì bớt nhà gặp nạn. Giữ làng xong +3 uy tín."))
			y += 16.0 + GG
			var P: Array = WD.TNPREP[k]
			var ok: Dictionary = o.p if W._num(o.p.get("d")) and int(o.p.d) == int(ev.d) else {}
			for j in 2:
				var p = P[j]
				if p == null:
					continue
				var wh := "a" if j == 0 else "b"
				var q: Dictionary = WD.tn_scale(p[2])
				var done: bool = W._tr(ok.get(wh))
				var r := _pjob(y, ("Giữ làng: " if j else "Giữ ruộng: ") + String(p[0]), String(p[1]), q, done, WD.tn_prep.bind(wh))
				out.append_array(r[0])
				y += float(r[1]) + GG
		else:
			# chưa có tin: trận tới còn N ngày + các loại mùa này hay có
			var sea: int = W.tn_sea(day)
			var W0: Array = W.TNW[sea] if sea >= 0 and sea < W.TNW.size() else []
			var nx := _nxt()
			var c2 := _chip(X0, y, XW, 66.0, "fut")
			out.append(c2)
			out.append(_dt(X0 + 10.0, y + 9.0, XW - 20.0, 17.0, ("Trận tới còn " + str(nx) + " ngày") if nx > 0 else "Chưa có tin thiên tai", 12.0, 800, BROWN, "left"))
			out.append(_dt(X0 + 10.0, y + 26.0, XW - 20.0, 14.0, "Mùa " + String(G.SEA_N[sea]).to_lower() + " hay có:", 10.5, 600, SUB, "left"))
			var cx := X0 + 10.0
			for wk in W0:
				var kk := String(wk[0])
				var nm := String(WD.TNK[kk].n)
				var cw: float = Box.text_w(nm, 10.0, 700) + 30.0
				var tc := _chip(cx, y + 42.0, cw, 18.0, _kk(kk))
				tc.kids = [_kic(cx + 10.0, y + 51.0, 13.0, kk), _dt(cx + 19.0, y + 42.0, cw - 22.0, 18.0, nm, 10.0, 700, BROWN, "left")]
				out.append(tc)
				cx += cw + 5.0
			y += 66.0 + GG
	# công trình đỡ thiên tai: lưới 2 cột có hình, có rồi xanh + tick, chưa có kem "Chưa xây"; chạm ô hiện tác dụng
	out.append_array(_sq(y, "Công trình đỡ thiên tai", "Làng có công trình nào thì trận nào cũng được đỡ. Chạm vào ô để xem công trình đỡ được gì."))
	y += 16.0 + GG
	var bt := []
	for c3 in _ct():
		bt.append({"b": String(c3[0]), "s": "Đã có" if c3[2] else "Chưa xây", "ic": String(c3[1]), "st": "on" if c3[2] else "", "k": "fut", "act": _dsay.bind(String(c3[0]) + ": " + String(c3[3]))})
	var g := _grid(y, bt, 2, "got")
	out.append_array(g[0])
	y += float(g[1]) + GG
	return [out, y]

func _pjob(y: float, t: String, s: String, q: Dictionary, done: bool, act) -> Array:   # khối việc phòng: tên, tác dụng, đồ cần + nút Làm
	var out := []
	var c := _chip(X0, y, XW, 10.0, "got" if done else "fut")
	out.append(c)
	var x := X0 + 10.0
	var w := XW - 20.0
	var yy := y + 10.0
	out.append(_dt(x, yy, w - 20.0, 16.0, _fitw(t, 12.0, 800, w - 20.0), 12.0, 800, BROWN, "left"))
	if done:
		out.append(_dtick(x + w - 14.0, yy + 2.0, 13.0))
	yy += 17.0
	out.append(_dt(x, yy, w, 14.0, _fitw(s, 10.5, 600, w), 10.5, 600, SUB, "left"))
	yy += 14.0 + GG
	if done:
		out.append(_dt(x, yy - 4.0, w, 14.0, "Đã làm xong hôm nay.", 10.5, 700, "rgb(46, 120, 50)", "left"))
		yy += 14.0 + 6.0
	else:
		var nd := _nchips(x, yy, w - 74.0, _need(q))
		out.append_array(nd[0])
		out.append(_btn(x + w - 66.0, yy + 4.0, 66.0, 26.0, "Làm", act, "go" if WD.tn_have(q) else "off"))
		yy += maxf(34.0, float(nd[1])) + 10.0
	c.r[3] = yy - y
	return [out, yy - y]

# ------------------------------------------------------------------ tab Gặp nạn (tnTabNan)
func _nan() -> Array:
	var o: Dictionary = W.tn_s()
	var F: Dictionary = W._r0().fam
	var day: int = W._vr()
	var out := []
	var y := 6.0
	if W._tr(o.get("lo")):   # việc của người có chức: lo cho bà con
		var lo: Dictionary = o.lo
		var n := maxi(1, lo.u.size())
		var hp := int(W._n(lo.hp))
		var c := _chip(X0, y, XW, 58.0, _kk(String(lo.k)))
		out.append(c)
		out.append(_kic(X0 + 22.0, y + 29.0, 26.0, String(lo.k)))
		out.append(_dt(X0 + 42.0, y + 8.0, XW - 110.0, 16.0, _fitw("Lo cho bà con sau " + String(WD.TNK[lo.k].n).to_lower(), 12.0, 800, XW - 110.0), 12.0, 800, BROWN, "left"))
		out.append(_dt(X0 + XW - 70.0, y + 8.0, 60.0, 16.0, str(hp) + "/" + str(lo.u.size()) + " nhà", 11.0, 800, "rgb(46, 120, 50)" if hp * 2 >= lo.u.size() else BROWN, "right"))
		out.append_array(_bar(X0 + 42.0, y + 28.0, XW - 52.0, float(hp) / n, 5.0))
		out.append(_dt(X0 + 42.0, y + 37.0, XW - 52.0, 14.0, _fitw("Còn " + str(int(lo.d) + 3 - day) + " ngày · giúp nửa số nhà +15 uy tín", 10.5, 600, XW - 52.0), 10.5, 600, SUB, "left"))
		y += 58.0 + GG
	var live := []
	for uu in o.nan:
		if F.get(uu) != null:
			live.append(uu)
	out.append_array(_sq(y, "Nhà gặp nạn", "Giúp trong 3 ngày: +60 thân, +8 uy tín. Quá hạn thì nhà đó buồn (−20 thân) rồi tự gượng dậy. Người có chức lo cho bà con: giúp được nửa số nhà thì +15 uy tín, bỏ mặc hết thì −15."))
	y += 16.0 + GG
	if live.is_empty():
		out.append(_dt(X0, y, XW, 16.0, "Xóm bình yên, không nhà nào gặp nạn.", 11.0, 700, SUB, "left"))
		return [out, y + 16.0 + GG]
	for uu in live:
		var r := _nblock(y, uu, o.nan[uu], F[uu], day)
		out.append_array(r[0])
		y += float(r[1]) + GG
	return [out, y]

func _nblock(y: float, uu, nn: Dictionary, ff: Dictionary, day: int) -> Array:   # khối 1 nhà gặp nạn
	var x0: bool = W._tr(nn.get("x"))
	var out := []
	var c := _chip(X0, y, XW, 10.0, "miss" if x0 else _kk(String(nn.k)))
	out.append(c)
	var x := X0 + 10.0
	var w := XW - 20.0
	var yy := y + 10.0
	var left := int(nn.d) + 3 - day
	var hc := _tchip(x, yy - 1.0, "Quá hạn" if x0 else ("Còn " + str(left) + " ngày"), "miss" if x0 else ("info" if left > 1 else "sen"), "rgb(110, 104, 92)" if x0 else ("rgb(60, 110, 170)" if left > 1 else "rgb(170, 50, 60)"))
	Snap._move(hc[0], Vector2(w - float(hc[1]), 0))
	out.append(hc[0])
	var nk := String(W.TNNAN.get(nn.k, ""))
	var kc := _tchip(x, yy - 1.0, nk, "sen", "rgb(170, 50, 60)")
	Snap._move(kc[0], Vector2(w - float(hc[1]) - 5.0 - float(kc[1]), 0))
	if nk != "":
		out.append(kc[0])
	var tw := w - float(hc[1]) - float(kc[1]) - 14.0
	out.append(_dt(x, yy, tw, 16.0, _fitw(String(ff.n), 12.0, 800, tw), 12.0, 800, BROWN, "left"))
	yy += 16.0 + GG
	if x0:
		out.append(_dt(x, yy, w, 14.0, "Quá hạn, đang tự gượng dậy.", 10.5, 600, SUB, "left"))
		yy += 14.0 + 10.0
	else:
		var nd := _nchips(x, yy, w, _need(nn.need))
		out.append_array(nd[0])
		yy += float(nd[1]) + GG
		var Rw := ["+60", "h", " thân · +8 uy tín"]
		out.append_array(_rowi(x, yy + 5.0, 16.0, Rw, 11.5, 800, "rgb(40, 130, 50)")[0])
		if WD.tn_busy(String(uu)):
			out.append(_dt(x, yy + 20.0, w - 90.0, 13.0, "Đang nghỉ làm thuê", 10.0, 600, SUB, "left"))
		out.append(_btn(x + w - 66.0, yy, 66.0, 26.0, "Giúp", WD.tn_help.bind(uu), "go" if WD.tn_have(nn.need) else "off"))
		yy += 26.0 + 10.0 + (6.0 if WD.tn_busy(String(uu)) else 0.0)
	c.r[3] = yy - y
	return [out, yy - y]

# ------------------------------------------------------------------ tab Sổ thiên tai (tnTabSo)
func _so() -> Array:
	var o: Dictionary = W.tn_s()
	var day: int = W._vr()
	var out := []
	var y := 6.0
	out.append_array(_sq(y, "Các trận đã qua", ""))
	y += 16.0 + GG
	if o.log.is_empty():
		out.append(_dt(X0, y, XW, 16.0, "Làng chưa gặp trận thiên tai nào.", 11.0, 700, SUB, "left"))
		return [out, y + 16.0 + GG]
	for r in o.log:
		var k := String(r.k)
		var ago := day - int(r.d)
		var p := []
		if W._tr(r.get("cay")):
			p.append("Hư " + W._sv(r.cay) + " ô ruộng")
		if W._tr(r.get("con")):
			p.append(W._sv(r.con) + " con vật bệnh")
		if r.get("nha", []).size():
			p.append("Nạn: " + ", ".join(PackedStringArray(r.nha)))
		var s := " · ".join(PackedStringArray(p))
		var L := _wrap(s if s != "" else "Không hư hại gì", 10.5, 600, XW - 56.0)
		var ph := []
		if W._tr(r.get("pa")):
			ph.append("Đã giữ ruộng")
		if W._tr(r.get("pb")):
			ph.append("Đã giữ làng")
		var h := 10.0 + 17.0 + L.size() * 14.0 + (24.0 if ph.size() else 0.0) + 8.0
		var c := _chip(X0, y, XW, h, _kk(k))
		out.append(c)
		out.append(_kic(X0 + 22.0, y + 22.0, 26.0, k))
		var dc := _tchip(X0, y + 8.0, "hôm nay" if ago <= 0 else str(ago) + " ngày trước", "fut", SUB)
		Snap._move(dc[0], Vector2(XW - 10.0 - float(dc[1]), 0))
		out.append(dc[0])
		out.append(_dt(X0 + 42.0, y + 10.0, XW - 60.0 - float(dc[1]), 16.0, String(WD.TNK[k].n), 12.0, 800, BROWN, "left"))
		var yy := y + 27.0
		for ln in L:
			out.append(_dt(X0 + 42.0, yy, XW - 56.0, 14.0, String(ln), 10.5, 600, "rgb(46, 120, 50)" if s == "" else SUB, "left"))
			yy += 14.0
		var cx := X0 + 42.0
		for t in ph:
			var pc := _tchip(cx, yy + 4.0, String(t), "got", "rgb(46, 120, 50)")
			out.append(pc[0])
			cx += float(pc[1]) + 5.0
		y += h + GG
	return [out, y]
