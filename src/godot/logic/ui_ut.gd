extends "res://logic/ui_kbang.gd"
# UY TÍN LÀNG (utOpen / utRender bản web, Sổ làng › Bà con lối xóm › Uy tín làng). (bản 467) làm lại trên khung Kho + chip chung (ui_kbang.gd).
# 4 tab: Uy tín (bậc + thang chức + mới đây), Lên chức (điều kiện có thanh tiến độ), Việc xóm, Công trình (góp xây chung).
# Đoạn luật vào nút ?. Luật ở w_lang.gd (ut*, ct*).

var W          # w_lang.gd
var tab := "ut"             # UTV.tab
const TABC := {"ut": "rgb(200, 150, 40)", "bau": "rgb(60, 140, 40)", "viec": "rgb(70, 120, 180)", "ct": "rgb(150, 112, 60)"}
const TIER := ["fut", "got", "info", "u_tim", "fire_l", "u_vang"]   # màu chip bậc uy tín theo mốc UTM
const UTC := {   # màu chip riêng: [gradient trên, giữa, dưới, viền]
	# (bản 468) mỗi chức một màu, dùng xuyên bảng: c1 Tổ trưởng xanh lá, c2 Trưởng xóm xanh dương, c3 Trưởng ấp tím, c4 Hương cả vàng đồng; cNf = nhạt (chưa tới)
	"c1": ["rgb(219, 236, 218)", "rgb(230, 242, 229)", "rgb(241, 247, 240)", "rgb(148, 198, 144)"], "c1f": ["rgb(241, 247, 240)", "rgb(246, 250, 246)", "rgb(251, 253, 250)", "rgb(192, 222, 190)"],
	"c2": ["rgb(218, 230, 244)", "rgb(229, 238, 247)", "rgb(240, 245, 251)", "rgb(144, 180, 222)"], "c2f": ["rgb(240, 245, 251)", "rgb(246, 249, 252)", "rgb(250, 252, 254)", "rgb(190, 211, 236)"],
	"c3": ["rgb(234, 226, 244)", "rgb(240, 235, 247)", "rgb(247, 243, 251)", "rgb(192, 168, 222)"], "c3f": ["rgb(247, 243, 251)", "rgb(250, 248, 252)", "rgb(252, 251, 254)", "rgb(218, 204, 236)"],
	"c4": ["rgb(247, 236, 210)", "rgb(249, 242, 224)", "rgb(252, 247, 237)", "rgb(230, 198, 120)"], "c4f": ["rgb(252, 247, 237)", "rgb(253, 250, 244)", "rgb(254, 253, 249)", "rgb(241, 222, 176)"],
	"u_tim": ["rgb(234, 224, 246)", "rgb(240, 232, 250)", "rgb(246, 241, 252)", "rgb(150, 116, 196)"],
	"u_vang": ["rgb(255, 238, 186)", "rgb(255, 243, 204)", "rgb(255, 249, 226)", "rgb(214, 160, 30)"],
}
const CHC := ["rgb(150, 112, 60)", "rgb(60, 140, 55)", "rgb(60, 115, 185)", "rgb(130, 90, 185)", "rgb(190, 140, 20)"]   # màu đậm từng chức (chữ, số, nhãn)
const CTP := {"causong": "pic:res://ui/img/xt/g_cau1.webp", "gate": "svg:res://ui/svg/mat/cong_lang.svg", "tramyt": "svg:res://ui/svg/mat/yte.svg",
	"truong": "pic:res://ui/img/xt/g_nha11.webp", "dinh": "svg:res://ui/svg/mat/dinh_lang.svg", "chua": "pic:res://ui/img/xt/g_mieu1.webp"}   # hình công trình
const VXI := {"hop": "pic:res://ui/img/vlface/0.webp", "gop": "nhang", "don": "cui", "xu": "svg:res://ui/svg/mat/can.svg"}   # hình việc xóm theo loại
const RES := {"xu": "xu", "cui": "cui", "gach": "svg:res://ui/svg/mat/gach.svg", "cong": "svg:res://ui/svg/mat/cong.svg"}   # hình đồ góp công trình
const XM := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 12 12\"><circle cx=\"6\" cy=\"6\" r=\"5.5\" fill=\"rgb(226,90,80)\"/><path d=\"M3.8 3.8 L8.2 8.2 M8.2 3.8 L3.8 8.2\" stroke=\"white\" stroke-width=\"1.6\" stroke-linecap=\"round\"/></svg>"

func _ck(kind: String) -> Array:
	return UTC[kind] if UTC.has(kind) else super(kind)

func _init(ui, wl) -> void:
	super(ui)
	W = wl

func open(t := "") -> void:   # utOpen
	if t != "":
		tab = t if TABC.has(t) else "ut"
	on = true
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:   # utRender mỗi giây
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	var ds: Array = W.ct_s().ds
	var tl := []
	for c in ds:
		if c.st == "xay":
			tl.append(int(maxf(0.0, (W._n(c.te) - W._now()) / 60000.0)))
	return JSON.stringify([tab, W.ut_s(), W.ct_s(), G.g.coins, W._barn("cui"), W._barn("lua"), W._barn("nhang"), G.mat_n("gach"), W._vr(), tl])

# ------------------------------------------------------------------ dựng
func _build() -> void:
	sig = _sig()
	var o: Dictionary = W.ut_s()
	var L := [["ut", "Uy tín", false], ["bau", "Lên chức", W.ut_can_len()], ["viec", "Việc xóm", o.get("vx") is Dictionary and o.vx.get("xu") is Dictionary], ["ct", "Công trình", W.ct_red()]]
	var sh := _kshell(L, tab, _tab_go)
	var r: Array
	match tab:
		"bau":
			r = _bau()
		"viec":
			r = _viec()
		"ct":
			r = _ct()
		_:
			r = _ut()
	_kmount(sh[0], sh[1], float(sh[2]), r[0], float(r[1]))

func _tab_go(k: String) -> void:   # data-ut="tab"
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

func _cond(x: float, y: float, w: float, cc: Array) -> Array:   # 1 điều kiện: tick / chéo, nhãn, số có/cần + thanh (nếu có số); trả [khối, cao]
	var out := []
	var ok: bool = W._tr(cc[0])
	out.append(_dtick(x + 2.0, y + 2.0, 11.0) if ok else _dic(x + 2.0, y + 2.0, 11.0, XM))
	var m = cc[3] if cc.size() > 3 and cc[3] is Dictionary else null
	var sub: String = String(cc[2]) if cc.size() > 2 else ""
	var yy := y
	if m != null and int(m.n) > 0:
		var nt: String = W._sa(int(m.h)) + "/" + W._sa(int(m.n))
		var nw: float = Box.text_w(nt, 10.5, 800) + 2.0
		out.append(_dt(x + 18.0, yy, w - 24.0 - nw, 15.0, _fitw(String(m.l), 10.5, 700, w - 24.0 - nw), 10.5, 700, BROWN, "left"))
		out.append(_dt(x + w - nw, yy, nw, 15.0, nt, 10.5, 800, "rgb(46, 120, 50)" if ok else "rgb(170, 60, 50)", "right"))
		out.append_array(_bar(x + 18.0, yy + 17.0, w - 18.0, float(m.h) / float(m.n), 4.0))
		yy += 24.0
	else:
		var lb := String(cc[1]).replace(" ♥", " tim")
		var L := _wrap(lb, 10.5, 700, w - 18.0)
		for ln in L:
			out.append(_dt(x + 18.0, yy, w - 18.0, 15.0, String(ln), 10.5, 700, BROWN, "left"))
			yy += 15.0
	if sub != "":
		for ln in _wrap(sub, 10.0, 600, w - 18.0):
			out.append(_dt(x + 18.0, yy, w - 18.0, 13.0, String(ln), 10.0, 600, SUB, "left"))
			yy += 13.0
	return [out, yy - y + 6.0]

# ------------------------------------------------------------------ tab Uy tín (utTabUt)
func _ut() -> Array:
	var o: Dictionary = W.ut_s()
	var p: float = W._n(o.p)
	var c := int(o.c)
	var out := []
	var y := 6.0
	# bậc uy tín: chip màu theo bậc, thanh tới mốc kế
	var ti := 0
	for i in W.UTM.size():
		if p >= float(W.UTM[i][0]):
			ti = i
	var b0 := float(W.UTM[ti][0])
	var nx = W.UTM[ti + 1] if ti + 1 < W.UTM.size() else null
	var hc := _chip(X0, y, XW, 66.0, TIER[mini(ti, TIER.size() - 1)])
	hc.act = _dsay.bind("Mốc uy tín: " + ", ".join(PackedStringArray(W.UTM.map(func(m): return String(m[1]) + " " + str(m[0])))) + ".")
	out.append(hc)
	out.append(_dic(X0 + 8.0, y + 9.0, 34.0, _medal(ti)))   # (bản 468) huy hiệu màu theo bậc
	out.append(_dt(X0 + 50.0, y + 9.0, XW - 150.0, 18.0, _fitw(W.ut_rank(), 13.0, 800, XW - 150.0), 13.0, 800, BROWN, "left"))
	out.append(_dt(X0 + XW - 100.0, y + 9.0, 88.0, 18.0, W._sv(o.p) + " điểm", 12.0, 800, "rgb(46, 120, 50)", "right"))
	var bx := X0 + 50.0
	var bw := XW - 62.0
	var mx := float(W.UTM[W.UTM.size() - 1][0])
	out.append_array(_bar(bx, y + 32.0, bw, p / maxf(1.0, mx), 6.0))
	for m in W.UTM:   # vạch mốc trên thanh
		var tx := bx + bw * float(m[0]) / maxf(1.0, mx)
		if float(m[0]) > 0.0:
			out.append(_dbx(clampf(tx - 1.0, bx, bx + bw - 2.0), y + 30.0, 2.0, 10.0, "rgb(150, 112, 60)" if p < float(m[0]) else "rgb(46, 120, 50)", 1.0))
	out.append(_dt(X0 + 50.0, y + 44.0, XW - 62.0, 14.0, _fitw(("Còn " + str(int(float(nx[0]) - p)) + " điểm tới \"" + String(nx[1]) + "\"") if nx != null else "Cả làng kính rồi.", 10.5, 600, XW - 62.0), 10.5, 600, SUB, "left"))
	y += 66.0 + GG
	if c and c < 4 and p < float(W.UTP[c]):   # đang dưới mốc chức
		var wc := _chip(X0, y, XW, 40.0, "sen")
		wc.kids = [_dt(X0 + 10.0, y + 5.0, XW - 20.0, 15.0, "Uy tín dưới mốc " + W._sv(W.UTP[c]) + " của " + String(W.UTCHUC[c]) + ".", 11.0, 800, "rgb(170, 50, 60)", "left"),
			_dt(X0 + 10.0, y + 20.0, XW - 20.0, 15.0, "Qua " + str(2 - W._i(o.get("low"))) + " tuần nữa chưa lên lại là làng bầu người khác.", 10.5, 600, "rgb(170, 60, 60)", "left")]
		out.append(wc)
		y += 40.0 + GG
	# thang chức
	var cs := "Chưa có chức. Đủ điều kiện thì ra họp ở tab Lên chức."
	if c:
		cs = "Đang làm " + String(W.UTCHUC[c]) + ". Thuê dân làm rẻ " + str(W.UTGIAM[c]) + "%." + \
			(" Được đứng ra kêu gọi xây trạm y tế." if c == 1 else (" Được đứng ra kêu gọi xây công trình " + ("bậc ấp" if c == 2 else "bậc ấp, bậc làng") + "." if c > 1 and c < 4 else "")) + \
			(" Làm đủ việc tuần thì tuần sau bà con đem quà tới biếu." if c == 4 else " Mỗi tuần có việc xóm, bỏ việc bị trừ uy tín.")
	out.append_array(_sq(y, "Chức trong làng", cs))
	y += 16.0 + GG
	for i in range(1, W.UTCHUC.size()):
		var held := c >= i
		var nxt := i == c + 1
		var k := "c" + str(i) + ("" if held or nxt else "f")   # (bản 468) màu riêng từng chức, chưa tới thì nhạt
		var bc := _chip(X0, y, XW, 42.0, k)
		out.append(bc)
		var nc := _dbx(X0 + 8.0, y + 10.0, 22.0, 22.0, String(CHC[i]) if held or nxt else "rgb(200, 190, 170)", 11.0)
		nc.kids = [_dt(X0 + 8.0, y + 10.0, 22.0, 22.0, str(i), 11.0, 800, "rgb(255, 255, 255)")]
		out.append(nc)
		out.append(_dt(X0 + 38.0, y + 6.0, XW - 130.0, 16.0, String(W.UTCHUC[i]), 12.0, 800, BROWN, "left"))
		out.append(_dt(X0 + 38.0, y + 23.0, XW - 48.0, 14.0, _fitw("Uy tín " + W._sv(W.UTP[i]) + " · cấp " + W._sv(W.UTLV[i]) + " · làng " + W._sv(W.UTLANG[i][0]) + " nhà", 10.5, 600, XW - 48.0), 10.5, 600, SUB, "left"))
		if held:
			var tc := _tchip(X0, y + 6.0, "Đang giữ" if c == i else "Đã qua", k, String(CHC[i]))
			Snap._move(tc[0], Vector2(XW - 10.0 - float(tc[1]), 0))
			out.append(tc[0])
		elif nxt:
			var tc2 := _tchip(X0, y + 6.0, "Kế tiếp ›", "fut", String(CHC[i]))
			Snap._move(tc2[0], Vector2(XW - 10.0 - float(tc2[1]), 0))
			out.append(tc2[0])
			bc.act = _tab_go.bind("bau")
		y += 42.0 + 6.0
	y += GG - 6.0
	# mới đây
	out.append_array(_sq(y, "Mới đây", "Việc nào làm lên, làm xuống uy tín. Giúp bà con, đi đám, góp cúng đình là lên uy tín."))
	y += 16.0 + GG
	if o.lg.is_empty():
		out.append(_dt(X0, y, XW, 16.0, "Chưa có gì. Giúp bà con, đi đám là lên uy tín.", 11.0, 700, SUB, "left"))
		y += 16.0 + GG
	for l in o.lg:
		var v := float(l[0])
		var dt: String = ("+" if v > 0 else "") + W._sv(l[0])
		var lc := _chip(X0, y, XW, 28.0, "fut")
		var dw: float = Box.text_w(dt, 10.5, 800) + 14.0
		var dc := _chip(X0 + XW - 8.0 - dw, y + 5.0, dw, 18.0, "sen" if v < 0 else "got")
		dc.kids = [_dt(X0 + XW - 8.0 - dw, y + 5.0, dw, 18.0, dt, 10.5, 800, "rgb(170, 50, 60)" if v < 0 else "rgb(46, 120, 50)")]
		lc.kids = [_dt(X0 + 10.0, y, XW - 26.0 - dw, 28.0, _fitw(String(l[1]), 10.5, 600, XW - 26.0 - dw), 10.5, 600, BROWN, "left"), dc]
		out.append(lc)
		y += 28.0 + 5.0
	return [out, y + GG - 5.0]

# ------------------------------------------------------------------ tab Lên chức (utTabBau)
func _bau() -> Array:
	var o: Dictionary = W.ut_s()
	var out := []
	var y := 6.0
	if int(o.c) < 4:
		var c := int(o.c) + 1
		var ok: bool = W.ut_can_len()
		var help := ("Đủ điều kiện thì các bô lão tới nhà mời lên đình, không cần bầu." if c == 4 else ("Họp tổ với 5 nhà gần nhà mình nhất, quá nửa gật là đậu." if c == 1 else "Họp cả làng, quá nửa số nhà gật mới đậu.")) + (" Rớt thì mai họp lại." if c < 4 else "")
		out.append_array(_sq(y, "Lên " + String(W.UTCHUC[c]), help))
		y += 16.0 + GG
		var C: Array = W.ut_cond(c)
		var nok := 0
		for cc in C:
			nok += 1 if W._tr(cc[0]) else 0
		var bc := _chip(X0, y, XW, 10.0, "c" + str(c) + ("" if ok else "f"))   # (bản 468) màu chức đang nhắm
		out.append(bc)
		var yy := y + 10.0
		out.append(_dt(X0 + 10.0, yy, XW - 20.0, 16.0, "Đủ " + str(nok) + "/" + str(C.size()) + " điều kiện", 11.5, 800, "rgb(46, 120, 50)" if ok else BROWN, "left"))
		yy += 20.0
		for cc in C:
			var r := _cond(X0 + 10.0, yy, XW - 20.0, cc)
			out.append_array(r[0])
			yy += float(r[1])
		bc.r[3] = yy + 4.0 - y
		y = yy + 4.0 + GG
		var t: String = "Bữa nay họp rồi, mai họp lại" if W._n(o.get("bd", -1)) == float(W._vr()) else ("Nhận lời làng mời" if c == 4 else ("Họp tổ bầu Tổ trưởng" if c == 1 else "Họp làng bầu " + String(W.UTCHUC[c])))
		var bt := _btn(X0, y, XW, 32.0, t, W.ut_bau, "go" if ok else "off")
		if not ok:
			bt.act = _dsay.bind("Chưa đủ điều kiện lên " + String(W.UTCHUC[c]) + ".")
		out.append(bt)
		y += 32.0 + GG
	else:
		var hc := _chip(X0, y, XW, 34.0, "u_vang")
		hc.kids = [_dt(X0 + 10.0, y, XW - 20.0, 34.0, "Bạn là Hương cả, bậc cao nhất trong làng.", 11.5, 800, BROWN, "left")]
		out.append(hc)
		y += 34.0 + GG
	if o.get("vr") is Dictionary:   # lần bầu gần nhất
		var v: Dictionary = o.vr
		var won: bool = W._tr(v.won)
		out.append_array(_sq(y, "Lễ rước Hương cả" if int(v.c) == 4 else "Lần bầu " + String(W.UTCHUC[int(v.c)]) + " gần nhất", ""))
		y += 16.0 + GG
		if int(v.c) != 4:
			var rc := _tchip(X0, y, W._sv(v.yes) + "/" + W._sv(v.n) + " nhà gật · " + ("Đắc cử" if won else "Rớt"), "got" if won else "sen", "rgb(46, 120, 50)" if won else "rgb(170, 50, 60)", null, 20.0, 10.5)
			out.append(rc[0])
			y += 20.0 + 6.0
		for l in v.ln:
			var gt: bool = W._tr(l[0])
			var L := _wrap(String(l[2]), 10.0, 600, XW - 46.0)
			var h := 10.0 + 15.0 + L.size() * 13.0 + 8.0
			var lc := _chip(X0, y, XW, h, "got" if gt else "fut")
			var ks := [_dtick(X0 + 10.0, y + 11.0, 11.0) if gt else _dic(X0 + 10.0, y + 11.0, 11.0, XM), _dt(X0 + 28.0, y + 8.0, XW - 38.0, 15.0, _fitw(String(l[1]), 11.0, 800, XW - 38.0), 11.0, 800, BROWN, "left")]
			for j in L.size():
				ks.append(_dt(X0 + 28.0, y + 24.0 + j * 13.0, XW - 38.0, 13.0, String(L[j]), 10.0, 600, SUB, "left"))
			lc.kids = ks
			out.append(lc)
			y += h + 5.0
	return [out, y]

# ------------------------------------------------------------------ tab Việc xóm (utTabViec)
func _viec() -> Array:
	var o: Dictionary = W.ut_s()
	var out := []
	var y := 6.0
	if not W._tr(o.c) or not (o.get("vx") is Dictionary):   # chưa có chức: chip khóa + kể việc + nút qua Lên chức
		var lc := _chip(X0, y, XW, 82.0, "info")
		out.append(lc)
		out.append(_dt(X0 + 10.0, y + 8.0, XW - 20.0, 16.0, "Làm Tổ trưởng mới có việc xóm", 12.0, 800, "rgb(40, 80, 130)", "left"))
		var pp := _para(X0 + 10.0, y + 27.0, XW - 20.0, "Mỗi tuần: họp xóm, góp lễ cúng đình, dọn đường làng, phân xử bà con. Xong mỗi việc +10 uy tín.", 10.5, 600, "rgb(70, 110, 160)", 14.0)
		out.append_array(pp[0])
		lc.r[3] = 27.0 + float(pp[1]) + 10.0
		y += float(lc.r[3]) + GG
		out.append(_btn(X0, y, XW, 30.0, "Xem đường lên chức", _tab_go.bind("bau"), "go"))
		return [out, y + 30.0 + GG]
	out.append_array(_sq(y, "Việc tuần này", "Xong mỗi việc +10 uy tín, qua tuần còn bỏ việc nào thì bị trừ 15."))
	y += 16.0 + GG
	for t in o.vx.t:
		var done: bool = W._tr(t.get("ok"))
		var cnt := ""
		if t.k == "hop":
			cnt = str(o.vx.hop.size()) + "/" + W._sv(t.need)
		elif t.k == "xu":
			cnt = str(W._i(t.get("n2"))) + "/" + W._sv(t.need)
		var bc := _chip(X0, y, XW, 10.0, "got" if done else "fut")
		out.append(bc)
		var x := X0 + 10.0
		var w := XW - 20.0
		var yy := y + 10.0
		var rw := 0.0
		out.append(_icx(x + 15.0, yy + 15.0, 30.0, String(VXI.get(String(t.k), "nhang"))))   # (bản 468) hình theo loại việc
		x += 38.0
		w -= 38.0
		if done:
			out.append(_dtick(x + w - 14.0, yy + 2.0, 13.0))
			rw = 20.0
		elif cnt != "":
			var cc := _tchip(x, yy - 1.0, cnt, "info", "rgb(60, 110, 170)")
			Snap._move(cc[0], Vector2(w - float(cc[1]), 0))
			out.append(cc[0])
			rw = float(cc[1]) + 6.0
		out.append(_dt(x, yy, w - rw, 16.0, _fitw(String(t.n), 12.0, 800, w - rw), 12.0, 800, BROWN, "left"))
		yy += 17.0
		out.append(_dt(x, yy, w, 14.0, _fitw(String(t.d), 10.5, 600, w), 10.5, 600, SUB, "left"))
		yy += 14.0 + GG
		if not done and (t.k == "gop" or t.k == "don"):
			var it := []
			for z in t.get("it", []):
				it.append([String(z[0]), String(W._ae(String(z[0])).get("name", z[0])), W._barn(String(z[0])), int(z[1])])
			var xq := int(W._n(t.get("xu", 0)))
			var xw := 0.0
			if xq > 0:
				var P := [W._sa(xq), "c"]
				xw = float(_rowi(0.0, 0.0, 26.0, P, 11.5, 800, "")[1])
				out.append_array(_rowi(x + w - 72.0 - xw, yy + 4.0, 26.0, P, 11.5, 800, BROWN if W._n(G.g.coins) >= xq else "rgb(190, 60, 50)")[0])
			var nd := _nchips(x, yy, w - 74.0 - (xw + 8.0 if xw > 0.0 else 0.0), it)
			out.append_array(nd[0])
			var gb := _btn(x + w - 66.0, yy + 4.0, 66.0, 26.0, "Góp" if t.k == "gop" else "Đem qua", W.ut_give.bind(String(t.k)), "go" if W.ut_give_ok(t) else "off")
			out.append(gb)
			yy += maxf(34.0, float(nd[1])) + 10.0
		elif not done and t.k == "xu" and not (o.vx.get("xu") is Dictionary):
			out.append(_btn(x + w - 96.0, yy - 4.0, 96.0, 26.0, "Nghe chuyện", _xu_new, "go"))
			yy += 22.0 + 10.0
		bc.r[3] = yy - y
		y += float(bc.r[3]) + GG
	var x0 = o.vx.get("xu")
	if x0 is Dictionary:   # phân xử
		var cs: Dictionary = W.UTXU[int(x0.i)]
		out.append_array(_sq(y, "Bà con nhờ phân xử" + (" · chuyện khó" if W._tr(cs.get("kho")) else ""), "Xử đúng lẽ thì cả hai nhà nể, bênh một bên thì bên kia giận."))
		y += 16.0 + GG
		var pp2 := _para(X0 + 10.0, y + 10.0, XW - 20.0, W.ut_xu_txt(x0, String(cs.t)), 11.0, 600, BROWN, 15.0)
		var sc := _chip(X0, y, XW, float(pp2[1]) + 20.0, "info")
		out.append(sc)
		out.append_array(pp2[0])
		y += float(sc.r[3]) + 8.0
		for j in x0.op.size():
			var L := _wrap(W.ut_xu_txt(x0, String(cs[x0.op[j]])), 11.0, 700, XW - 40.0)
			var h := L.size() * 14.0 + 14.0
			var b := _chip(X0, y, XW, h, "fut")
			var cc2 := _dbx(X0 + 8.0, y + (h - 18.0) * 0.5, 18.0, 18.0, "rgb(196, 160, 100)", 9.0)
			cc2.kids = [_dt(X0 + 8.0, y + (h - 18.0) * 0.5, 18.0, 18.0, str(j + 1), 10.0, 800, "rgb(255, 255, 255)")]
			var ks := [cc2]
			for i in L.size():
				ks.append(_dt(X0 + 32.0, y + 7.0 + i * 14.0, XW - 40.0, 14.0, String(L[i]), 11.0, 700, BROWN, "left"))
			b.kids = ks
			b.act = W.ut_xu_pick.bind(j)
			out.append(b)
			y += h + 6.0
		y += GG - 6.0
	return [out, y]

func _xu_new() -> void:   # data-ut="xu"
	if W.ut_xu_new() == null:
		U.say("Xóm chưa đủ 2 nhà để có chuyện mà xử.")

# ------------------------------------------------------------------ tab Công trình (ctTab)
func _ct() -> Array:
	var o: Dictionary = W.ct_s()
	var cb: Dictionary = W.WR.ct_built() if W.WR != null else {1: 0, 2: 0, 3: 0}
	var F: Dictionary = W._r0().fam
	var P: Dictionary = W._pi()
	var out := []
	var y := 6.0
	# đầu tab: 3 chip đếm công trình theo bậc + nút ?
	out.append_array(_sq(y, "Công trình chung", "Bậc xóm tự mua trong Xây dựng. Bậc ấp, bậc làng phải đứng ra kêu gọi bà con góp xây. Mỗi món mình góp tối đa nửa, nửa kia bà con góp dần mỗi ngày."))
	y += 16.0 + GG
	var cx := X0
	for bac in [1, 2, 3]:
		var t: String = ["", "Xóm", "Ấp", "Làng"][bac] + " " + str(cb[bac])
		var tc := _tchip(cx, y, t, "fut", BROWN, null, 24.0, 11.0)
		out.append(tc[0])
		cx += float(tc[1]) + 6.0
	y += 24.0 + GG
	var tk: Array = o.tok.keys().filter(func(b): return W._i(o.tok[b]) > 0)
	if tk.size():
		var pp := _para(X0 + 10.0, y + 8.0, XW - 20.0, "Đã khánh thành, chờ đặt: " + ", ".join(PackedStringArray(tk.map(func(b): return String(P[b].n) + (" ×" + W._sv(o.tok[b]) if W._i(o.tok[b]) > 1 else "")))) + ". Vào Xây dựng đặt miễn phí.", 10.5, 700, "rgb(46, 120, 50)", 14.0)
		var gc := _chip(X0, y, XW, float(pp[1]) + 16.0, "got")
		out.append(gc)
		out.append_array(pp[0])
		y += float(gc.r[3]) + GG
	# đang góp xây
	for i in o.ds.size():
		var r := _gop(y, i, o.ds[i], P, F)
		out.append_array(r[0])
		y += float(r[1]) + GG
	if o.ds.size() < W.CTMAX and int(W.ut_s().c) > 1:
		out.append(_dt(X0, y, XW, 15.0, "Còn góp song song được " + str(W.CTMAX - o.ds.size()) + " công trình nữa.", 10.5, 600, SUB, "left"))
		y += 15.0 + GG
	# danh sách công trình bậc ấp, bậc làng
	for bac in [2, 3]:
		out.append_array(_sq(y, "Công trình " + String(W.CTBN[bac]), ("Trưởng xóm" if bac == 2 else "Trưởng ấp") + " trở lên đứng ra kêu gọi. Khánh thành +" + ("30" if bac == 2 else "60") + " uy tín."))
		y += 16.0 + GG
		for k in W.CTB:
			if int(W.CTB[k]) != bac or not P.has(k):
				continue
			var r2 := _ctb(y, String(k), bac, P, o)
			out.append_array(r2[0])
			y += float(r2[1]) + GG
	return [out, y]

func _ctb(y: float, k: String, bac: int, P: Dictionary, o: Dictionary) -> Array:   # khối 1 công trình chưa xây: tên, khánh thành, đồ cần bằng hình, Kêu gọi
	var nd: Dictionary = W.ct_need(k)
	var why: String = W.ct_can_start(k)
	var cr: int = int(W.CTCHUC[k]) if W.CTCHUC.has(k) else (2 if bac == 2 else 3)
	var lock: bool = int(W.ut_s().c) < cr
	var out := []
	var c := _chip(X0, y, XW, 10.0, "c2f" if bac == 2 else "c4f")   # (bản 468) bậc ấp xanh dương nhạt, bậc làng vàng nhạt
	out.append(c)
	var x := X0 + 10.0
	var w := XW - 20.0
	var yy := y + 10.0
	out.append(_icx(x + 17.0, yy + 17.0, 34.0, String(CTP.get(k, "svg:res://ui/svg/mat/dinh_lang.svg"))))
	x += 42.0
	w -= 42.0
	var rw := 0.0
	if lock:
		var lc := _tchip(x, yy - 1.0, "Cần " + String(W.UTCHUC[cr]), "c" + str(cr), String(CHC[cr]))
		Snap._move(lc[0], Vector2(w - float(lc[1]), 0))
		out.append(lc[0])
		rw = float(lc[1]) + 6.0
	out.append(_dt(x, yy, w - rw, 16.0, _fitw(String(P[k].n), 12.0, 800, w - rw), 12.0, 800, BROWN, "left"))
	yy += 17.0
	var s: String = "Khánh thành +" + ("30" if bac == 2 else "60") + " uy tín" + ((" · Bia: " + ", ".join(PackedStringArray(o.bia[k].slice(0, 2)))) if o.bia.has(k) else "")
	out.append(_dt(x, yy, w, 14.0, _fitw(s, 10.5, 600, w), 10.5, 600, "rgb(46, 120, 50)", "left"))
	yy += 14.0 + GG
	# đồ cần: chip nhỏ có hình (như "Mùa hạ hay có" bên Thiên tai)
	var cx := X0 + 10.0
	for rk in ["xu", "cui", "gach", "cong"]:
		var nt: String = W._sa(int(nd[rk]))
		var cw: float = Box.text_w(nt, 10.5, 800) + 32.0
		var rc := _chip(cx, yy + 2.0, cw, 22.0, "fut")
		rc.kids = [_icx(cx + 11.0, yy + 13.0, 16.0, String(RES[rk])), _dt(cx + 22.0, yy + 2.0, cw - 25.0, 22.0, nt, 10.5, 800, BROWN, "left")]
		rc.act = _dsay.bind(String(W.CTRES.filter(func(r): return r[0] == rk)[0][1]) + ": cần " + nt + ".")
		out.append(rc)
		cx += cw + 4.0
	var bt := _btn(X0 + XW - 86.0, yy, 76.0, 26.0, "Kêu gọi", W.ct_start.bind(k), "go" if why == "" else "off")
	if why != "":
		bt.act = _dsay.bind(why)
	out.append(bt)
	yy += 26.0 + 10.0
	c.r[3] = yy - y
	return [out, yy - y]

func _gop(y: float, i: int, c: Dictionary, P: Dictionary, F: Dictionary) -> Array:   # khối công trình đang góp xây: từng món có thanh + nút góp, người góp nhiều, khởi công
	var D: Dictionary = P[c.id]
	var out := []
	var bc := _chip(X0, y, XW, 10.0, "now")
	out.append(bc)
	var x := X0 + 10.0
	var w := XW - 20.0
	var yy := y + 10.0
	out.append(_dt(x, yy, w, 16.0, _fitw("Đang góp xây: " + String(D.n), 12.0, 800, w), 12.0, 800, BROWN, "left"))
	yy += 17.0
	var st: String = ("Đang dựng, còn " + G.ao(maxf(0.0, (W._n(c.te) - W._now()) / 1000.0)) + " nữa khánh thành.") if c.st == "xay" else "Mình góp tối đa nửa mỗi món, nửa kia chờ bà con."
	out.append(_dt(x, yy, w, 14.0, _fitw(st, 10.5, 600, w), 10.5, 600, SUB, "left"))
	yy += 14.0 + GG
	for r in W.CTRES:
		var k: String = r[0]
		var g: float = W._n(c.got[k])
		var nn: float = W._n(c.need[k])
		var ok: bool = g >= nn
		var m: int = W.ct_me(c, k)
		out.append(_icx(x + 10.0, yy + 10.0, 18.0, String(RES[k])))
		var nt: String = W._sa(g) + "/" + W._sa(nn)
		var bw := 0.0
		if c.st == "gop" and not ok:
			var gb := _btn(x + w - 62.0, yy, 62.0, 22.0, "Thuê thợ" if k == "cong" else "Góp", W.ct_give.bind(i, k), "go" if m > 0 else "off")
			if m <= 0:
				gb.act = _dsay.bind("Đủ phần mình, chờ bà con góp.")
			out.append(gb)
			bw = 68.0
		elif ok:
			out.append(_dtick(x + w - 14.0, yy + 4.0, 12.0))
			bw = 20.0
		var tw0: float = Box.text_w(nt, 10.5, 800) + 2.0
		out.append(_dt(x + 26.0, yy, w - 26.0 - bw - tw0, 14.0, String(r[1]), 10.5, 700, BROWN, "left"))
		out.append(_dt(x + w - bw - tw0, yy, tw0, 14.0, nt, 10.5, 800, "rgb(46, 120, 50)" if ok else BROWN, "right"))
		out.append_array(_bar(x + 26.0, yy + 16.0, w - 26.0 - bw, g / maxf(1.0, nn), 4.0))
		yy += 28.0
	var by: Array = c.by.keys()
	by.sort_custom(func(a, b): return W._n(c.by[a]) > W._n(c.by[b]))
	by = by.slice(0, 5)
	if by.size():
		var t: String = "Góp nhiều: " + " · ".join(PackedStringArray(by.map(func(k): return ("Bạn" if k == "me" else (String(F[k].n) if F.has(k) else "Nhà cũ")) + " " + W._sa(c.by[k]))))
		out.append(_dt(x, yy, w, 14.0, _fitw(t, 10.5, 600, w), 10.5, 600, SUB, "left"))
		yy += 14.0 + GG
	if c.st == "gop":
		var full: bool = W.ct_full(c)
		var kb := _btn(x + w - 150.0, yy, 150.0, 26.0, "Khởi công · " + str(W.CTGIO[int(W.CTB[c.id])]) + " tiếng", W.ct_go.bind(i), "go" if full else "off")
		if not full:
			kb.act = _dsay.bind("Góp đủ các món mới khởi công được.")
		out.append(kb)
		var qc := _tchip(x, yy + 4.0, "Thôi không xây", "sen", "rgb(170, 50, 60)", W.ct_quit.bind(i), 20.0, 10.0)
		out.append(qc[0])
		yy += 26.0 + 10.0
	bc.r[3] = yy - y
	return [out, yy - y]

func _medal(ti: int) -> String:   # (bản 468) huy hiệu bậc uy tín: tròn có dải, màu theo bậc
	var C := ["rgb(176, 136, 70)", "rgb(76, 160, 70)", "rgb(70, 130, 200)", "rgb(150, 110, 200)", "rgb(232, 112, 40)", "rgb(214, 160, 30)"]
	var col: String = C[clampi(ti, 0, C.size() - 1)]
	var cs := col.replace(" ", "")
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M7 2 L10 10 L12 9 L14 10 L17 2 Z\" fill=\"rgb(200,70,60)\"/><circle cx=\"12\" cy=\"15\" r=\"7\" fill=\"" + cs + "\" stroke=\"rgb(120,90,40)\" stroke-width=\"1\"/><circle cx=\"12\" cy=\"15\" r=\"4.6\" fill=\"none\" stroke=\"rgb(255,255,255)\" stroke-width=\"1\" opacity=\"0.7\"/><path d=\"M12 11.6 L13 14 L15.5 14.2 L13.6 15.8 L14.2 18.3 L12 17 L9.8 18.3 L10.4 15.8 L8.5 14.2 L11 14 Z\" fill=\"rgb(255,255,255)\"/></svg>"
