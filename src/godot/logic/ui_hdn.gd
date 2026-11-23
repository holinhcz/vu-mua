extends "res://logic/ui_kbang.gd"
# HỘI ĐÌNH (hdnOpen / hdnRender bản web, Sổ làng › Việc làng). (bản 501) làm lại trên khung Kho + chip chung (ui_kbang.gd), 3 tab:
#  - Mở hội: chip đầu (hình đình, loại hội, trạng thái) + chip số liệu (3 ngày chuẩn bị, +uy tín, tháng này N/M), 3 bước
#    Định ngày → Chuẩn bị → Ngày hội; chưa mở được: lý do + chức đang có + nút qua Uy tín; đang lo: lễ vật (thanh, Góp),
#    việc mình lo (Làm / ✓), Hoãn hội;
#  - Giải thi: chip thưởng nhất / nhì / ba, thẻ từng giải (hình, vòng, nút Vào thi);
#  - Sổ hội: mỗi hội một dòng (ngày, loại, nhà dự, giải); trống: hình đình + câu.
# Luật ở w_htx.gd (hdn_*).

var WH         # w_htx.gd
var tab := "mo"             # HDNV.tab
const TABS := [["mo", "Mở hội"], ["giai", "Giải thi"], ["so", "Sổ hội"]]
const DINH := "svg:res://ui/svg/mat/dinh_lang.svg"
const CONG := "svg:res://ui/svg/mat/cong_lang.svg"
const FLAG := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M5 2v20\" stroke=\"rgb(110,80,40)\" stroke-width=\"2\"/><path d=\"M6 3h13l-3 4 3 4H6z\" fill=\"rgb(226,64,60)\"/><path d=\"M6 3h13l-1.5 2H6z\" fill=\"rgb(250,200,40)\"/><path d=\"M6 7.5h12.6l-1 1.5H6z\" fill=\"rgb(60,150,70)\"/></svg>"
const CRICKET := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M9 7C7 4 5 3 2 3M11 7c1-3 3-5 6-5\" stroke=\"rgb(90,60,30)\" stroke-width=\"1.2\" fill=\"none\"/><ellipse cx=\"10\" cy=\"9\" rx=\"3\" ry=\"2.6\" fill=\"rgb(110,70,30)\"/><path d=\"M8 11c2-1 8-1 11 3 1 2 0 4-3 4-4 0-8-2-9-5z\" fill=\"rgb(150,96,40)\" stroke=\"rgb(90,60,30)\" stroke-width=\"0.8\"/><path d=\"M11 15l-4 6M14 16l-1 6M17 17l4 4\" stroke=\"rgb(90,60,30)\" stroke-width=\"1.4\"/></svg>"
const QUIZ := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M4 3h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2h-8l-5 4v-4H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z\" fill=\"rgb(70,130,200)\" stroke=\"rgb(40,90,150)\" stroke-width=\"1\"/><text x=\"12\" y=\"14.5\" font-size=\"11\" font-weight=\"bold\" text-anchor=\"middle\" fill=\"#fff\" font-family=\"sans-serif\">?</text></svg>"
const GIC := {"de": CRICKET, "do": QUIZ}
const ARR := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M8 4l8 8-8 8\" fill=\"none\" stroke=\"rgb(170,130,70)\" stroke-width=\"3\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>"   # mũi tên giữa các bước

const HDC := {   # nền chip riêng Hội đình
	"hd_top": ["rgb(252, 226, 200)", "rgb(253, 234, 214)", "rgb(254, 243, 230)", "rgb(214, 130, 60)"],
	"hd_st": ["rgb(250, 236, 206)", "rgb(252, 242, 222)", "rgb(254, 248, 236)", "rgb(214, 170, 90)"],
}
func _ck(kind: String) -> Array:
	return HDC[kind] if HDC.has(kind) else super(kind)

func _init(ui, wh) -> void:
	super(ui)
	WH = wh

func open(t := "") -> void:   # hdnOpen
	if t != "":
		tab = t
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	return JSON.stringify([tab, WH.hdn_s(), G.g.coins, G.g.barn, WH._vr(), WH.WL.ut_s().get("c")])

func _build() -> void:
	sig = _sig()
	var dot := {"mo": not WH._tr(WH.hdn_s().get("cur")) and WH.hdn_why() == "", "giai": WH.hdn_red() > 0 and WH.hdn_today()}
	var L := TABS.map(func(x): return [x[0], String(x[1]), bool(dot.get(x[0], false))])   # chấm đỏ chung của tab
	var o: Array
	match tab:
		"giai":
			o = _giai()
		"so":
			o = _so()
		_:
			o = _mo()
	var sh := _kshell(L, tab, _tab_go)
	_kmount(sh[0], sh[1], float(sh[2]), o[0], float(o[1]))

func _tab_go(k: String) -> void:   # data-hdn="tab"
	if tab != k:
		tab = k
		scroll = 0.0

func _ten(cu: Dictionary) -> String:   # "đá dế, đố vui"
	return ", ".join(PackedStringArray(cu.giai.map(func(id): return String(WH.HDNG[id]).replace("Giải ", ""))))

func _hic(cx: float, cy: float, z: float, k: String) -> Dictionary:   # hình: svg trong (chuỗi <svg) hoặc mã _icx
	if k.begins_with("<svg"):
		return _dic(cx - z * 0.5, cy - z * 0.5, z, k)
	return _icx(cx, cy, z, k)

func _ichip(x: float, y: float, w: float, ic: String, t: String, kd := "fut", col := BROWN) -> Dictionary:   # chip nhỏ: hình + chữ
	var c := _chip(x, y, w, 26.0, kd)
	c.kids = [_hic(x + 14.0, y + 13.0, 16.0, ic), _dt(x + 25.0, y, w - 28.0, 26.0, _fitw(t, 10.0, 700, w - 28.0), 10.0, 700, col, "left")]
	return c

# chip đầu: hình đình, loại hội, trạng thái; dưới: 3 chip số liệu
func _top(y: float, ttl: String, st: String, stc: String) -> Array:
	var o: Dictionary = WH.hdn_s()
	var out := []
	var c := _chip(X0, y, XW, 52.0, "hd_top")
	c.kids = [_hic(X0 + 28.0, y + 26.0, 40.0, DINH), _dt(X0 + 54.0, y + 8.0, XW - 62.0, 18.0, ttl, 12.5, 800, BROWN, "left"),
		_dt(X0 + 54.0, y + 27.0, XW - 62.0, 16.0, st, 10.5, 700, stc, "left")]
	out.append(c)
	y += 52.0 + 6.0
	var mon := str(WH.hdn_mon(WH.hdn_day_pick()))
	var w := (XW - 12.0) / 3.0
	out.append(_ichip(X0, y, w, "svg:res://ui/svg/mat/huychuong.svg", "+20–50 uy tín"))
	out.append(_ichip(X0 + w + 6.0, y, w, FLAG, "Lo 3 ngày"))
	out.append(_ichip(X0 + (w + 6.0) * 2.0, y, w, DINH, "Tháng này " + str(WH._i(o.m.get(mon))) + "/" + str(WH.hdn_max())))
	return [out, y + 26.0]

func _steps(y: float, cur: int) -> Array:   # 3 bước: Định ngày → Chuẩn bị → Ngày hội (cur 0..2: bước đang ở)
	var out := []
	var N := ["Định ngày", "Chuẩn bị 3 ngày", "Ngày hội"]
	var w := (XW - 2.0 * 14.0) / 3.0
	for i in 3:
		var x := X0 + i * (w + 14.0)
		var kd := "now" if i == cur else ("got" if i < cur else "fut")
		var c := _chip(x, y, w, 24.0, kd)
		c.kids = [_dt(x, y, w, 24.0, str(i + 1) + ". " + String(N[i]), 9.5, 800 if i == cur else 700, BROWN if i >= cur else "rgb(40, 110, 50)")]
		out.append(c)
		if i < 2:
			out.append(_dic(x + w + 2.0, y + 7.0, 10.0, ARR))
	return [out, y + 24.0]

# ------------------------------------------------------------------ tab Mở hội (hdnTabMo)
func _mo() -> Array:
	var o: Dictionary = WH.hdn_s()
	var cu = o.get("cur")
	var day: int = WH._vr()
	var out := []
	var y := 6.0
	if not WH._tr(cu):
		var why: String = WH.hdn_why()
		var big: bool = WH.hdn_big()
		var T := _top(y, ("Hội lớn" if big else "Hội nhỏ") + " · đá dế, đố vui", "Chưa định ngày mở hội" if why == "" else "Chưa mở được", SUB)
		out.append_array(T[0])
		y = float(T[1]) + GG
		var S := _steps(y, 0)
		out.append_array(S[0])
		y = float(S[1]) + GG
		if why != "":   # chưa mở được: lý do + đường đi
			var P := _parab(X0 + 34.0, 0.0, XW - 44.0, why, 10.5, 700, "rgb(160, 50, 50)", 15.0)
			var sub := ""
			var go = null
			if why.begins_with("Có chức"):
				var c := int(WH.WL.ut_s().c)
				sub = "Bạn đang là " + (String(WH.WL.UTCHUC[c]) if c > 0 else "dân làng") + ". Lên chức ở bảng Uy tín làng."
				go = U.ut_open
			elif why.contains("đình"):
				sub = "Khai hoang khu Sân đình trước (bảng Khai hoang)."
			var h := 12.0 + float(P[1]) + (16.0 if sub != "" else 0.0) + 10.0
			var bc := _chip(X0, y, XW, h, "sen")
			out.append(bc)
			out.append(_hic(X0 + 18.0, y + 18.0, 18.0, "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M7 10V7a5 5 0 0 1 10 0v3\" fill=\"none\" stroke=\"rgb(170,60,60)\" stroke-width=\"2.4\"/><rect x=\"4\" y=\"10\" width=\"16\" height=\"11\" rx=\"2.5\" fill=\"rgb(200,80,80)\"/></svg>"))
			for n in P[0]:
				n.r[1] = float(n.r[1]) + y + 10.0
				out.append(n)
			if sub != "":
				out.append(_dt(X0 + 34.0, y + 10.0 + float(P[1]) + 2.0, XW - 44.0, 14.0, sub, 9.5, 600, SUB, "left"))
			y += h + GG
			if go != null:
				out.append(_btn(X0, y, XW, 32.0, "Xem Uy tín làng ›", go, "go"))
				y += 32.0
		else:
			out.append(_btn(X0, y, XW, 34.0, "Định ngày mở hội (3 ngày sau)", WH.hdn_open_hoi, "go"))
			y += 34.0 + 6.0
			out.append(_para(X0 + 2.0, y, XW, "Bà con góp lễ 3 ngày, mình dựng cổng treo cờ. Hội càng đông càng được nhiều uy tín." + ("" if big else " Lên Trưởng ấp thì mở được hội lớn."), 10.0, 600, SUB, 14.0)[0])
			y += 30.0
		return [_flat(out), y + GG]
	var left := int(cu.d) - day
	var st := ("Còn " + str(left) + " ngày nữa mở hội") if left > 0 else "Hôm nay mở hội ở sân đình"
	var T2 := _top(y, ("Hội lớn" if WH._tr(cu.big) else "Hội nhỏ") + " · " + _ten(cu), st, "rgb(196, 110, 20)" if left > 0 else "rgb(46, 130, 60)")
	out.append_array(T2[0])
	y = float(T2[1]) + GG
	var S2 := _steps(y, 1 if left > 0 else 2)
	out.append_array(S2[0])
	y = float(S2[1]) + GG
	if left <= 0 and WH._tr(cu.get("att")):
		out.append_array(_rowi(X0 + 2.0, y, 16.0, ["i:" + DINH, " " + str(cu.att.size()) + "/" + WH._sa(cu.tot) + " nhà tới dự · trò chuyện với nhà đi dự thân gấp đôi"], 10.0, 700, BROWN)[0])
		y += 16.0 + GG
	if left > 0:   # lễ vật
		out.append_array(_sect(y, "Lễ vật", "rgb(214, 130, 60)"))
		out.append(_dt(X0 + 70.0, y, XW - 70.0, 16.0, "mình góp tối đa nửa, bà con góp nửa", 9.5, 600, SUB, "right"))
		y += 16.0 + 8.0
		for r in WH.HDNRES:
			var k := String(r[0])
			var gt: float = WH._n(cu.got[k])
			var nd: float = WH._n(cu.need[k])
			var full := gt >= nd
			var mm: int = WH.hdn_me(cu, k)
			var c := _chip(X0, y, XW, 46.0, "got" if full else "fut")
			out.append(c)
			out.append(_icx(X0 + 22.0, y + 23.0, 28.0, k))
			out.append(_dt(X0 + 42.0, y + 5.0, 150.0, 16.0, String(WH.HDNMON[k]), 11.0, 800, BROWN, "left"))
			var ns: String = WH._sa(gt) + "/" + WH._sa(nd)
			out.append(_dt(X0 + 150.0, y + 5.0, XW - 150.0 - 78.0, 16.0, ns, 10.5, 800, "rgb(40, 110, 50)" if full else BROWN, "right"))
			out.append_array(_bar(X0 + 42.0, y + 24.0, XW - 42.0 - 78.0, gt / maxf(1.0, nd), 6.0))
			out.append(_dt(X0 + 42.0, y + 31.0, XW - 42.0 - 78.0, 13.0, "" if full else ("Mình góp được thêm " + WH._sa(mm) + " " + String(r[1]) if mm else "Đủ phần mình, chờ bà con"), 9.0, 600, SUB, "left"))
			if full:
				out.append(_dtick(X0 + XW - 40.0, y + 15.0, 16.0))
			else:
				out.append(_btn(X0 + XW - 70.0, y + 9.0, 62.0, 28.0, "Góp", WH.hdn_give.bind(k), "go" if mm > 0 else "off"))
			y += 46.0 + 5.0
		y += GG - 5.0
	if left >= 0:   # việc mình lo
		out.append_array(_sect(y, "Việc mình lo", "rgb(76, 150, 48)"))
		out.append(_dt(X0 + 90.0, y, XW - 90.0, 16.0, "mỗi việc +2 uy tín, hội đông hơn", 9.5, 600, SUB, "right"))
		y += 16.0 + 8.0
		for k in WH.HDNVIEC:
			var V: Array = WH.HDNVIEC[k]
			var q: Dictionary = WH.hdn_scale(V[2])
			var done: bool = WH._tr(cu.v.get(k))
			var parts := []
			for kk in q:
				parts += ["i:" + String(kk), " " + WH._sa(q[kk]) + "  "]
			var c2 := _chip(X0, y, XW, 44.0, "got" if done else "fut")
			out.append(c2)
			out.append(_hic(X0 + 22.0, y + 22.0, 26.0, CONG if k == "cong" else FLAG))
			out.append(_dt(X0 + 42.0, y + 5.0, XW - 120.0, 16.0, String(V[0]), 11.0, 800, BROWN, "left"))
			if done:
				out.append(_dt(X0 + 42.0, y + 23.0, XW - 120.0, 14.0, "Đã xong", 9.5, 700, "rgb(40, 110, 50)", "left"))
				out.append(_dtick(X0 + XW - 40.0, y + 14.0, 16.0))
			else:
				out.append_array(_rowi(X0 + 42.0, y + 23.0, 14.0, parts, 9.5, 700, SUB)[0])
				var ok: bool = WH.WL.WD.tn_have(q)
				out.append(_btn(X0 + XW - 70.0, y + 8.0, 62.0, 28.0, "Làm", WH.hdn_viec.bind(k), "go" if ok else "off"))
			y += 44.0 + 5.0
		y += GG - 5.0
	if left > 0:
		var hc := _chip(X0, y, XW, 28.0, "fut")
		hc.kids = [_dt(X0, y, XW, 28.0, "Hoãn hội (−10 uy tín)", 10.5, 700, "rgb(170, 60, 60)")]
		hc.act = WH.hdn_huy
		out.append(hc)
		y += 28.0
	return [_flat(out), y + GG]

static func _flat(a: Array) -> Array:   # gộp mảng lồng (vd _para trả mảng) thành một hàng khối
	var o := []
	for x in a:
		if x is Array:
			o.append_array(x)
		else:
			o.append(x)
	return o

# ------------------------------------------------------------------ tab Giải thi (hdnTabGiai)
func _giai() -> Array:
	var cu = WH.hdn_s().get("cur")
	var out := []
	var y := 6.0
	var has: bool = WH._tr(cu)
	var today: bool = has and WH._vr() == int(cu.d)
	var st := "Hôm nay thi, mỗi giải thi 1 lần, bỏ ngang tính thua" if today else (("Tới ngày hội mới thi, còn " + str(int(cu.d) - WH._vr()) + " ngày") if has else "Định ngày mở hội rồi mới có giải")
	out.append_array(_rowi(X0 + 2.0, y, 16.0, ["i:" + DINH, " " + st], 10.5, 700, "rgb(46, 130, 60)" if today else BROWN)[0])
	y += 16.0 + GG
	# thưởng nhất / nhì / ba
	var w := (XW - 12.0) / 3.0
	for i in 3:
		var T: Array = WH.HDNTHUONG[i + 1]
		var x := X0 + i * (w + 6.0)
		var c := _chip(x, y, w, 50.0, ["now", "fut", "fut"][i])
		c.kids = [_dt(x, y + 4.0, w, 15.0, "Giải " + String(WH.HDNHANG[i + 1]), 10.5, 800, BROWN),
			_dt(x, y + 19.0, w, 13.0, "+" + str(int(T[0])) + " uy tín", 9.5, 700, "rgb(46, 130, 60)"),
			_dt(x, y + 33.0, w, 13.0, "+" + WH._sa(int(T[1])) + " xu", 9.5, 700, "rgb(150, 90, 10)")]
		out.append(c)
	y += 50.0 + GG
	var ids: Array = cu.giai if has else WH.HDNG.keys()
	for id in ids:
		var gg = cu.g.get(id) if has else null
		if not (gg is Dictionary):
			gg = {"rd": 0, "st": "chua"}
		var xong: bool = gg.st == "xong"
		var sub := ""
		if not has:
			sub = "3 vòng đấu dế với nhà trong xóm" if id == "de" else "10 câu đố, thi với 4 nhà"
		elif xong:
			sub = "Đoạt giải " + WH.HDNHANG[int(gg.rank)] if WH._tr(gg.get("rank")) else "Chưa vào giải"
		elif id == "de":
			var rd: int = WH._i(gg.rd)
			sub = WH.HDNVONG[rd] + ": gặp nhà " + String(WH.hdn_names(cu, id, 3)[rd]) + " (dế cấp " + str(WH.hdn_de_lv(rd)) + ")"
		else:
			sub = "10 câu, thi với nhà " + ", ".join(PackedStringArray(WH.hdn_names(cu, "do", 4)))
		var won: bool = xong and WH._tr(gg.get("rank"))
		var c2 := _chip(X0, y, XW, 50.0, "got" if won else "fut")
		out.append(c2)
		out.append(_hic(X0 + 24.0, y + 25.0, 30.0, String(GIC.get(id, QUIZ))))
		out.append(_dt(X0 + 46.0, y + 7.0, XW - 130.0, 17.0, String(WH.HDNG[id]), 11.5, 800, BROWN, "left"))
		out.append(_dt(X0 + 46.0, y + 26.0, XW - 130.0, 15.0, _fitw(sub, 9.5, 600, XW - 130.0), 9.5, 600, "rgb(40, 110, 50)" if won else SUB, "left"))
		if xong:
			if won:
				out.append(_dtick(X0 + XW - 36.0, y + 17.0, 16.0))
		else:
			out.append(_btn(X0 + XW - 80.0, y + 11.0, 72.0, 28.0, "Vào thi", WH.hdn_play.bind(String(id)), "go" if today else "off"))
		y += 50.0 + 5.0
	return [out, y + GG]

# ------------------------------------------------------------------ tab Sổ hội (hdnTabSo)
func _so() -> Array:
	var o: Dictionary = WH.hdn_s()
	var day: int = WH._vr()
	var out := []
	var y := 6.0
	if o.log.is_empty():
		out.append(_hic(X0 + XW * 0.5, y + 40.0, 64.0, DINH))
		out.append(_dt(X0, y + 80.0, XW, 16.0, "Chưa mở hội đình nào.", 11.5, 800, BROWN))
		out.append(_dt(X0, y + 98.0, XW, 14.0, "Mỗi lần mở hội sẽ ghi lại ở đây: nhà dự, giải đoạt.", 10.0, 600, SUB))
		return [out, y + 120.0]
	for r in o.log:
		var ago := day - int(r.d)
		var gs := []
		for id in r.g:
			gs.append(String(WH.HDNG.get(id, id)).replace("Giải ", "") + ": " + ("giải " + WH.HDNHANG[int(r.g[id])] if WH._tr(r.g[id]) else "không giải"))
		var c := _chip(X0, y, XW, 46.0, "hd_st")
		c.kids = [_hic(X0 + 20.0, y + 23.0, 26.0, DINH),
			_dt(X0 + 40.0, y + 6.0, XW - 48.0, 16.0, ("Hội lớn" if WH._tr(r.big) else "Hội nhỏ") + " · " + ("hôm qua" if ago <= 1 else str(ago) + " ngày trước"), 11.0, 800, BROWN, "left"),
			_dt(X0 + 40.0, y + 24.0, XW - 48.0, 14.0, _fitw(WH._sa(r.att) + "/" + WH._sa(r.tot) + " nhà dự" + (" · " + " · ".join(PackedStringArray(gs)) if gs.size() else ""), 9.5, 600, XW - 48.0), 9.5, 600, SUB, "left")]
		out.append(c)
		y += 46.0 + 5.0
	return [out, y + GG]
