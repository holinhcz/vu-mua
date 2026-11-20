extends "res://logic/ui_kbang.gd"
# TRỜI ĐẤT TRONG LÀNG (RN / Hh bản web, chạm ô giờ - thời tiết góc trái trên): (bản 396) khung Kho + chip chung (ui_kbang.gd), 2 tab:
#  - "Thời tiết": chip đỏ mùa + ngày trong mùa (thanh 7 ngày), chip bây giờ, dự báo 6 buổi (3 × 2), cảnh báo: thiên tai ngày mai,
#    hạn mặn, gió chướng, radio (bản tin ngày mai).
#  - "Lịch làng": hôm nay trong làng theo giờ (chợ nổi, hội chợ sân đình, đám), lễ hội 4 lễ gần nhất + hội đình.
# Bỏ khỏi bảng (bản 396): nhạc đờn ca (bản Godot chưa có nhạc), chỉnh giờ / mùa (Cài đặt có), hụi (Sổ làng), rầy nâu (cột việc;
# phun hết thuốc tự mua), tát ao (chạm ao), hội thi làng + nồi cơm trưa (chơi mạng, chưa có). Hình thời tiết: ui/snap/sky.json.

var SK := {}
var cd := "t"

const TK := ["Khuya", "Sáng", "Chiều", "Tối"]
const T8 := ["Mùa xuân", "Mùa hạ", "Mùa thu", "Mùa khô"]
const HQ := {"nang": "Trời đẹp, thỉnh thoảng có mưa rào tưới giùm.",
	"mua": "Ruộng, cây ăn trái tự thấm nước. Có sấm sét, gió quật ngã cây.",
	"rao": "Mưa rào chốc lát, tạnh là ruộng và cây no nước.",
	"han": "Ruộng khô nhanh gấp rưỡi, không có mưa rào."}
const HQF := {"nang": "Không có gì đặc biệt. Thỉnh thoảng có mưa rào tưới giùm.",
	"mua": "Mưa rả rích cả buổi, ruộng và cây ăn trái thấm nước dần, khỏi tưới. Có sấm sét, gió quật ngã 1–3 cây; cây đè ruộng thì ruộng ngưng lớn tới khi dọn. Đi chậm 15% nếu không mặc áo mưa.",
	"rao": "Trận mưa rào 5 giây, tạnh là ruộng và cây ăn trái no nước.",
	"han": "Ruộng khô nhanh gấp rưỡi, không có mưa rào. Lu nước, giếng, ao gần ruộng giúp đỡ khô."}

func _init(ui) -> void:
	super(ui)
	SK = Snap.load_snap("sky")

func open() -> void:   # RN
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	return JSON.stringify([cd, _now_w(), G.day(), int(G.nv.hour() * 4.0), G.ray_n(), G.g.get("hc"), G.cfg.s])

func _now_w() -> String:   # ti.cur || Wd()
	return G.troi.cur if G.troi.cur != "" else G.nv.Wd()

func _tab_go(k: String) -> void:
	if cd != k:
		cd = k
		scroll = 0.0

func _go(f: Callable) -> Callable:   # đóng bảng rồi mở bảng khác
	return func(): close(); f.call()

func _build() -> void:
	sig = _sig()
	var W = G.w_all
	var o: int = G.day()
	var lehot := false
	for r in 3:
		if W.WH.mm(o + r) != null:
			lehot = true
	var tn_mai: bool = W.WL.tn_ok() and W.WL.tn_on(o + 1) != null
	var sh := _kshell([["t", "Thời tiết", tn_mai], ["l", "Lịch làng", lehot]], cd, _tab_go)
	var r: Array = _tabt() if cd == "t" else _tabl()
	_kmount(sh[0], sh[1], sh[2], r[0], float(r[1]))

# ------------------------------------------------------------------ một hàng chip: [ô trái nhỏ], tên đậm + 1 dòng, nút chip xanh phải
func _row(y: float, h: float, kind: String, lt, title: String, sub: String, full: String, btn = null) -> Array:
	var out := []
	var c := _chip(X0, y, XW, h, kind)
	var x := X0 + 10.0
	var ks := []
	if lt != null:   # ô trái: [dòng 1, dòng 2] hoặc [svg]
		var lw := 50.0
		var lc := _chip(X0 + 6.0, y + 5.0, lw, h - 10.0, "fut")
		var L: Array = lt
		if L.size() == 1:
			lc.kids = [_dic(X0 + 6.0 + (lw - 24.0) * 0.5, y + (h - 24.0) * 0.5, 24.0, String(L[0]))]
		else:
			lc.kids = [_dt(X0 + 6.0, y + h * 0.5 - 13.0, lw, 12.0, String(L[0]), 9.5, 600, SUB), _dt(X0 + 6.0, y + h * 0.5, lw, 13.0, String(L[1]), 11.0, 800, BROWN)]
		ks.append(lc)
		x = X0 + lw + 14.0
	var bw := 0.0
	if btn != null:
		bw = Box.text_w(String(btn[0]), 11.0, 800) + 22.0
	var tw := X0 + XW - x - (bw + 14.0 if bw > 0.0 else 8.0)
	ks.append(_dt(x, y + h * 0.5 - 15.0, tw, 15.0, _fitw(title, 12.0, 800, tw), 12.0, 800, BROWN, "left"))
	ks.append(_dt(x, y + h * 0.5 + 1.0, tw, 13.0, _fitw(sub, 10.0, 600, tw), 10.0, 600, SUB, "left"))
	c.kids = ks
	c.act = _dsay.bind(full)
	out.append(c)
	if btn != null:   # nút đặt ngoài chip (bấm nút không bấm luôn hàng)
		var b := _onbtn(X0 + XW - bw - 8.0, y + (h - 26.0) * 0.5, bw, 26.0, String(btn[0]), btn[1])
		b.kids[0].css["font-size"] = _cpx(11.0)
		out.append(b)
	return out

# ------------------------------------------------------------------ tab Thời tiết
func _tabt() -> Array:
	var W = G.w_all
	var out := []
	var o: int = G.day()
	var sea: int = G.season()
	var auto: bool = G.cfg.s == "auto"
	var dd: int = posmod(o, 28) % 7 + 1
	# mùa + ngày trong mùa
	var y := 10.0
	var mt: String = T8[sea]
	var mw: float = Box.text_w(mt, 12.5, 800) + 24.0
	out.append(_onbtn(X0, y, mw, 26.0, mt, null, true))
	var st := ("Ngày " + str(dd) + "/7 · " + ("còn " + str(7 - dd) + " ngày sang " + String(T8[(sea + 1) % 4]).to_lower() if dd < 7 else "mai sang " + String(T8[(sea + 1) % 4]).to_lower())) if auto else "Mùa chỉnh tay trong Cài đặt"
	out.append(_dt(X0 + mw + 10.0, y, XW - mw - 10.0, 26.0, st, 11.5, 700, BROWN, "left"))
	if auto:   # thanh 7 ngày
		var bx := X0 + mw + 10.0
		var bw := XW - mw - 14.0
		var sw := (bw - 6.0 * 3.0) / 7.0
		for i in 7:
			out.append(_dbx(bx + i * (sw + 3.0), y + 30.0, sw, 5.0, "rgb(35, 160, 74)" if i < dd else "rgb(230, 214, 174)", 3.0))
	# bây giờ
	var a := _now_w()
	var ny := y + 44.0
	var nh := 64.0
	var nc := _chip(X0, ny, XW, nh, "fut")
	nc.kids = [_dic(X0 + 10.0, ny + (nh - 46.0) * 0.5, 46.0, String(SK.ic[a])),
		_dt(X0 + 66.0, ny + 9.0, XW - 76.0, 12.0, "Bây giờ · " + String(TK[int(floor(G.nv.hour() / 6.0))]).to_lower(), 10.0, 600, SUB, "left"),
		_dt(X0 + 66.0, ny + 21.0, XW - 76.0, 18.0, String(G.troi.TEN[a]), 14.5, 800, BROWN, "left"),
		_dt(X0 + 66.0, ny + 40.0, XW - 76.0, 14.0, _fitw(HQ[a], 10.5, 600, XW - 76.0), 10.5, 600, SUB, "left")]
	nc.act = _dsay.bind(HQF[a])
	out.append(nc)
	# dự báo 6 buổi
	var fy := ny + nh + 12.0
	out.append_array(_hd(fy, "Dự báo"))
	var e: int = o * 4 + int(floor(G.nv.hour() / 6.0))
	var g := 6.0
	var cw := (XW - g * 2.0) / 3.0
	var ch := 70.0
	var gy := fy + 22.0
	for i in 6:
		var c: int = e + i + 1
		var f: String = G.nv.Hx(c)
		var s: int = int(floor(c / 4.0)) - o
		var x := X0 + (i % 3) * (cw + g)
		var yy := gy + (i / 3) * (ch + g)
		var cc := _chip(x, yy, cw, ch, "fut")
		cc.kids = [_dt(x, yy + 5.0, cw, 12.0, TK[posmod(c, 4)] + " " + ("hôm nay" if s == 0 else ("mai" if s == 1 else "mốt")), 9.5, 600, SUB),
			_dic(x + (cw - 28.0) * 0.5, yy + 19.0, 28.0, String(SK.ic[f])),
			_dt(x + 2.0, yy + 50.0, cw - 4.0, 15.0, _fitw(String(G.troi.TEN[f]), 11.5, 800, cw - 4.0), 11.5, 800, BROWN)]
		cc.act = _dsay.bind(TK[posmod(c, 4)] + " " + ("hôm nay" if s == 0 else ("mai" if s == 1 else "mốt")) + ": " + String(G.troi.TEN[f]) + ". " + HQF[f])
		out.append(cc)
	# cảnh báo + radio
	var ky := gy + ch * 2.0 + g + 12.0
	out.append_array(_hd(ky, "Cảnh báo, tin tức"))
	var ry := ky + 22.0
	var rh := 44.0
	var tn = W.WL.tn_on(o + 1) if W.WL.tn_ok() else null
	if tn != null:
		var K: Dictionary = W.WL.TNK[String(tn.k)]
		out.append_array(_row(ry, rh, "sen", null, "Ngày mai: " + String(K.w), String(K.d), String(K.w) + ": " + String(K.d), ["Phòng chống", _go(U.tn_open.bind("phong"))]))
		ry += rh + g
	var n4: bool = W.WR.n4()
	var ac: int = W.WR.ac()
	if n4 or (ac >= 0 and ac <= 4):
		var ms := "Nước mặn đang lấn vô sông, ruộng chậm lớn." if n4 else "Chừng " + str(ac) + " ngày nữa mặn lấn vô sông Vàm. Trữ nước ngọt sẵn."
		out.append_array(_row(ry, rh, "sen" if n4 else "fut", null, "Hạn mặn", ms, ms, ["Xem", _go(W.WRU.open_man)]))
		ry += rh + g
	if sea == 3 or sea == 0:
		var cg: bool = W.WCA.cg()
		var gs := "Đang có gió, ra đồng thả diều (bảng nhân vật › Diều)." if cg else "Mùa này chiều 14–18 giờ có gió thả diều."
		out.append_array(_row(ry, rh, "got" if cg else "fut", null, "Gió chướng", gs, gs))
		ry += rh + g
	var rs := "Bản tin thời tiết ngày mai, giá cả, cải lương."
	out.append_array(_row(ry, rh, "fut", null, "Radio", rs, rs, ["Mở radio", _go(W.WCU.open_rd)]))
	ry += rh
	return [out, ry + 8.0]

# ------------------------------------------------------------------ tab Lịch làng
func _tabl() -> Array:
	var W = G.w_all
	var out := []
	var o: int = G.day()
	var g := 6.0
	var rh := 46.0
	var y := 10.0
	out.append_array(_hd(y, "Hôm nay trong làng"))
	y += 22.0
	# chợ nổi
	if W.WC.u4() != null:
		var v: bool = W.WC.b2()
		var cs := "Họp từ 5 giờ tới " + str(W.WC.wm()) + " giờ sáng mỗi ngày. " + ("Đang họp!" if v else "Bây giờ chưa họp.")
		out.append_array(_row(y, rh, "got" if v else "fut", ["sáng", "5–" + str(W.WC.wm()) + "g"], "Chợ nổi sông Vàm", "Đang họp" if v else "Chưa họp", cs, ["Đi chợ", _go(W.WCU._pill_go)] if v else null))
	else:
		out.append_array(_row(y, rh, "miss", ["sáng", "5–8g"], "Chợ nổi sông Vàm", "Mở khúc sông Vàm để có chợ", "Mở khúc sông Vàm (khai hoang phía nam) để có chợ nổi."))
	y += rh + g
	# hội chợ sân đình
	var a2 := 0
	while a2 < 4 and not W.WH.c_r(o + a2):
		a2 += 1
	var n2: bool = W.WH.e_r()
	var l2: bool = W.WH.l2()
	var hs := "Đang mở! Ra sân đình chơi ném vòng, đập niêu, lô tô." if l2 else ("Tối nay 18g30–22g30 có hội chợ." if n2 else "Hội chợ kế tiếp " + ("tối mai" if a2 == 1 else "sau " + str(a2) + " ngày") + ". Bỏ 2.000 xu tổ chức tối nay thì chơi liền.")
	out.append_array(_row(y, rh, "got" if l2 else "fut", ["tối", "18g30"], "Hội chợ sân đình", "Đang mở" if l2 else ("Tối nay có hội" if n2 else "Tối nay không có"), hs, null if n2 else ["Tổ chức · 2.000", W.WH.b_]))
	y += rh + g
	# đám cưới / đám giỗ
	var ev = W.WL.tg().get("ev")
	if _tr(ev):
		var a := int(floor(fmod(float(ev.t0), 24.0)))
		var on_d: bool = W.WL.sg() != null
		var es := "Đã dự." if _tr(ev.get("done")) else ("Đang đãi khách, ghé dự liền!" if on_d else "Lúc " + ("0" if a < 10 else "") + str(a) + ":00.")
		out.append_array(_row(y, rh, "got" if on_d else "fut", ["giờ", str(a) + "g"], String(W.WL.qm(ev)), es, String(W.WL.qm(ev)) + ": " + es))
		y += rh + g
	# lễ hội: 4 lễ gần nhất trong 56 ngày + hội đình
	y += 6.0
	out.append_array(_hd(y, "Lễ hội"))
	y += 22.0
	var seen := {}
	var p := []
	for r in 56:
		if p.size() >= 4:
			break
		var d = W.WH.mm(o + r)
		if d != null and not seen.has(d.id):
			seen[d.id] = 1
			p.append([d, r])
	for i in p.size():
		var f: Dictionary = p[i][0]
		var r: int = p[i][1]
		var when := String(G.SEA_N[int(f.sea)]) + " ngày " + str(int(f.day))
		out.append_array(_row(y, rh, "sen" if i == 0 else "fut", ["", "Hôm nay"] if r == 0 else ["còn", str(r) + " ngày"], String(f.n), when + " · " + String(f.d), String(f.n) + " (" + when + "): " + String(f.d), ["Góp lễ", _go(W.WHU.open_fest)] if r <= 2 else null))
		y += rh + g
	var tx = W.WH.hdn_pill_txt()
	if tx != null:
		var cu: Dictionary = W.WH.hdn_s().cur
		var today: bool = int(tx[1]) == 1
		var hd := ("Hôm nay mở hội ở sân đình.") if today else "Còn " + str(int(cu.d) - o) + " ngày tới hội. Bà con đang góp lễ."
		out.append_array(_row(y, rh, "sen" if today else "fut", ["", "Hôm nay"] if today else ["còn", str(int(cu.d) - o) + " ngày"], "Hội đình làng", hd, hd, ["Vào thi" if today else "Chuẩn bị", _go(U.hdn_open.bind("giai" if today else "mo"))]))
		y += rh + g
	return [out, y + 2.0]

static func _tr(v) -> bool:
	return not (v == null or v is bool and not v or (v is float or v is int) and v == 0 or v is String and v == "")
