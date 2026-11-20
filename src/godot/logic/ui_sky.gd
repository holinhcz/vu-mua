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
	"han": "Ruộng khô nhanh gấp rưỡi, không mưa rào."}
const HQF := {"nang": "Không có gì đặc biệt. Thỉnh thoảng có mưa rào tưới giùm.",
	"mua": "Mưa rả rích cả buổi, ruộng và cây ăn trái thấm nước dần, khỏi tưới. Có sấm sét, gió quật ngã 1–3 cây; cây đè ruộng thì ruộng ngưng lớn tới khi dọn. Đi chậm 15% nếu không mặc áo mưa.",
	"rao": "Trận mưa rào 5 giây, tạnh là ruộng và cây ăn trái no nước.",
	"han": "Ruộng khô nhanh gấp rưỡi, không có mưa rào. Lu nước, giếng, ao gần ruộng giúp đỡ khô."}

# màu chip riêng bảng Trời đất: thời tiết (nền + viền theo trời), buổi trong ngày (ô giờ), lễ gần / xa
const SKC := {
	"wx_nang": ["rgb(255, 238, 176)", "rgb(255, 244, 200)", "rgb(255, 250, 222)", "rgb(222, 170, 40)"],
	"wx_han": ["rgb(250, 206, 160)", "rgb(252, 218, 180)", "rgb(254, 230, 202)", "rgb(206, 120, 50)"],
	"wx_rao": ["rgb(196, 226, 246)", "rgb(210, 234, 250)", "rgb(226, 242, 252)", "rgb(90, 160, 210)"],
	"wx_mua": ["rgb(184, 204, 220)", "rgb(198, 214, 228)", "rgb(214, 226, 236)", "rgb(80, 116, 150)"],
	"t_sang": ["rgb(255, 236, 170)", "rgb(255, 242, 192)", "rgb(255, 248, 214)", "rgb(214, 160, 40)"],
	"t_chieu": ["rgb(252, 210, 166)", "rgb(253, 220, 184)", "rgb(254, 230, 204)", "rgb(206, 128, 60)"],
	"t_toi": ["rgb(112, 114, 158)", "rgb(124, 126, 170)", "rgb(138, 140, 182)", "rgb(84, 86, 130)"],
	"le_gan": ["rgb(244, 170, 160)", "rgb(248, 186, 176)", "rgb(250, 202, 192)", "rgb(196, 70, 60)"],
	"le_xa": ["rgb(226, 196, 128)", "rgb(233, 206, 144)", "rgb(240, 218, 165)", "rgb(150, 108, 40)"],
}
func _ck(kind: String) -> Array:
	return SKC[kind] if SKC.has(kind) else super(kind)

static func _wk(f: String) -> String:   # loại chip theo thời tiết
	return "wx_" + (f if f in ["nang", "han", "rao", "mua"] else "nang")

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
		var L: Array = lt
		var lk: String = String(L[2]) if L.size() > 2 else "fut"
		var lc := _chip(X0 + 6.0, y + 5.0, lw, h - 10.0, lk)
		var dk := lk == "t_toi"
		if L.size() == 1:
			lc.kids = [_dic(X0 + 6.0 + (lw - 24.0) * 0.5, y + (h - 24.0) * 0.5, 24.0, String(L[0]))]
		else:
			lc.kids = [_dt(X0 + 6.0, y + h * 0.5 - 13.0, lw, 12.0, String(L[0]), 9.5, 600, "rgb(220, 222, 240)" if dk else SUB), _dt(X0 + 6.0, y + h * 0.5, lw, 13.0, String(L[1]), 11.0, 800, "rgb(255, 255, 255)" if dk else BROWN)]
		ks.append(lc)
		x = X0 + lw + 14.0
	var bw := 0.0
	if btn != null:
		bw = Box.text_w(String(btn[0]), 11.0, 800) + 22.0
	var tw := X0 + XW - x - (bw + 14.0 if bw > 0.0 else 8.0)
	var L2 := _wrap2(sub, 10.0, 600, tw) if h >= 54.0 else [_fitw(sub, 10.0, 600, tw)]
	var ty := y + (h - (16.0 + L2.size() * 13.0)) * 0.5
	ks.append(_dt(x, ty, tw, 15.0, _fitw(title, 12.0, 800, tw), 12.0, 800, BROWN, "left"))
	for i in L2.size():
		ks.append(_dt(x, ty + 17.0 + i * 13.0, tw, 13.0, String(L2[i]), 10.0, 600, SUB, "left"))
	c.kids = ks
	c.act = _dsay.bind(full)
	out.append(c)
	if btn != null:   # nút đặt ngoài chip (bấm nút không bấm luôn hàng)
		var b := _onbtn(X0 + XW - bw - 8.0, y + (h - 26.0) * 0.5, bw, 26.0, String(btn[0]), btn[1])
		b.kids[0].css["font-size"] = _cpx(11.0)
		out.append(b)
	return out

func _wrap2(s: String, fs: float, fw: int, w: float) -> Array:   # ngắt tối đa 2 dòng theo chữ, dòng 2 cắt "…"
	if Box.text_w(s, fs, fw) <= w:
		return [s]
	var ws := s.split(" ")
	var a := ""
	var i := 0
	while i < ws.size() and Box.text_w((a + " " + ws[i]).strip_edges(), fs, fw) <= w:
		a = (a + " " + ws[i]).strip_edges()
		i += 1
	return [a, _fitw(" ".join(ws.slice(i)), fs, fw, w)]

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
	out.append(_dt(X0 + mw + 10.0, y - 3.0 if auto else y, XW - mw - 10.0, 20.0 if auto else 26.0, st, 11.5, 700, BROWN, "left"))
	if auto:   # thanh 7 ngày
		var bx := X0 + mw + 10.0
		var bw := XW - mw - 14.0
		var sw := (bw - 6.0 * 3.0) / 7.0
		for i in 7:
			out.append(_dbx(bx + i * (sw + 3.0), y + 20.0, sw, 5.0, "rgb(35, 160, 74)" if i < dd else "rgb(230, 214, 174)", 3.0))
	# bây giờ
	var a := _now_w()
	var WN := _warns()
	var nwarn := WN.size()
	var fixed := 10.0 + 40.0 + 12.0 + 22.0 + 6.0 + 12.0 + 22.0 + nwarn * (_wrh(nwarn) + 6.0) + 4.0
	var spare := _hb - fixed - 64.0 - 70.0   # mặc định chip bây giờ 64, dự báo 1 hàng 70; âm = nhiều cảnh báo, thu chip lại
	var ny := y + 40.0
	var nh := 64.0 + (minf(spare * 0.3, 24.0) if spare > 0.0 else maxf(spare * 0.3, -4.0))
	var nc := _chip(X0, ny, XW, nh, _wk(a))
	var nis := nh - 18.0
	var tx0 := X0 + nis + 22.0
	var ty0 := ny + maxf(4.0, (nh - 63.0) * 0.5)
	nc.kids = [_dic(X0 + 12.0, ny + (nh - nis) * 0.5, nis, String(SK.ic[a])),
		_dt(tx0, ty0, XW - (tx0 - X0) - 10.0, 12.0, "Bây giờ · " + String(TK[int(floor(G.nv.hour() / 6.0))]).to_lower(), 10.0, 600, SUB, "left"),
		_dt(tx0, ty0 + 13.0, XW - (tx0 - X0) - 10.0, 20.0, String(G.troi.TEN[a]), 15.5, 800, BROWN, "left"),
		]
	var hl := _wrap2(HQ[a], 10.5, 600, XW - (tx0 - X0) - 10.0)   # hiệu ứng tối đa 2 dòng
	for i in hl.size():
		nc.kids.append(_dt(tx0, ty0 + 35.0 + i * 13.0, XW - (tx0 - X0) - 10.0, 13.0, String(hl[i]), 10.5, 600, SUB, "left"))
	nc.act = _dsay.bind(HQF[a])
	out.append(nc)
	# dự báo 3 buổi kế tiếp (bỏ khuya)
	var fy := ny + nh + 12.0
	out.append_array(_hd(fy, "Dự báo"))
	var e: int = o * 4 + int(floor(G.nv.hour() / 6.0))
	var g := 6.0
	var cw := (XW - g * 2.0) / 3.0
	var ch := 70.0 + (minf(spare - minf(spare * 0.3, 24.0), 16.0) if spare > 0.0 else maxf(spare * 0.5, -8.0))
	var isz := clampf(ch - 40.0, 22.0, 46.0)
	var gy := fy + 22.0
	var bs := []
	var c0: int = e + 1
	while bs.size() < 3:
		if posmod(c0, 4) != 0:
			bs.append(c0)
		c0 += 1
	for i in 3:
		var c: int = bs[i]
		var f: String = G.nv.Hx(c)
		var s: int = int(floor(c / 4.0)) - o
		var x := X0 + i * (cw + g)
		var yy := gy
		var cc := _chip(x, yy, cw, ch, _wk(f))
		cc.kids = [_dt(x, yy + 5.0, cw, 12.0, TK[posmod(c, 4)] + " " + ("nay" if s == 0 else ("mai" if s == 1 else "mốt")), 9.5, 600, SUB),
			_dic(x + (cw - isz) * 0.5, yy + 17.0 + (ch - 40.0 - isz) * 0.5, isz, String(SK.ic[f])),
			_dt(x + 2.0, yy + ch - 20.0, cw - 4.0, 15.0, _fitw(String(G.troi.TEN[f]), 11.5, 800, cw - 4.0), 11.5, 800, BROWN)]
		cc.act = _dsay.bind(TK[posmod(c, 4)] + " " + ("hôm nay" if s == 0 else ("mai" if s == 1 else "mốt")) + ": " + String(G.troi.TEN[f]) + ". " + HQF[f])
		out.append(cc)
	# cảnh báo + radio
	var ky := gy + ch + 12.0
	out.append_array(_hd(ky, "Cảnh báo, tin tức"))
	var ry := ky + 22.0
	var rh := _wrh(WN.size())
	for i in WN.size():
		var q: Array = WN[i]
		out.append_array(_row(ry, rh, String(q[0]), null, String(q[1]), String(q[2]), String(q[3]), q[4]))
		ry += rh + (g if i < WN.size() - 1 else 0.0)
	return [out, ry + 8.0]

func _wrh(n: int) -> float:   # cao hàng cảnh báo: nhiều hàng thì thấp lại
	return 44.0 if n <= 4 else 40.0

# cảnh báo, tin tức: [loại chip, tên, dòng phụ, mô tả chạm, nút?]
func _warns() -> Array:
	var W = G.w_all
	var o: int = G.day()
	var sea: int = G.season()
	var L := []
	# thiên tai: báo trước 2 ngày (hiện loại), xa hơn chỉ báo còn mấy ngày; đang có nạn thì nút giúp
	if W.WL.tn_ok():
		var nx := -1
		var ev = null
		for r in range(1, 40):
			ev = W.WL.tn_on(o + r)
			if ev != null:
				nx = r
				break
		if nx >= 1 and nx <= 2:
			var K: Dictionary = W.WL.TNK[String(ev.k)]
			var t := ("Ngày mai: " if nx == 1 else "Ngày mốt: ") + String(K.n)
			L.append(["sen", t, String(K.d), String(K.w) + ". " + String(K.d), ["Phòng chống", _go(U.tn_open.bind("phong"))], 1])
		elif nx > 2:
			L.append(["fut", "Thiên tai kế tiếp · còn " + str(nx) + " ngày", "Báo loại thiên tai trước 2 ngày để kịp phòng chống.", "Mỗi tháng 2 trận thiên tai. Trận tới còn " + str(nx) + " ngày, trước 2 ngày sẽ báo là bão, lũ, hạn, dịch hay cháy.", null, 7])
		var tp: Array = W.WD.tn_pill_txt()
		if tp.size() and not bool(tp[1]):
			L.append(["sen", String(tp[0]).split(" · ")[0], "Bà con cần giúp sửa nhà, góp đồ.", String(tp[0]), ["Giúp", _go(U.tn_open.bind("nan"))], 2])
	# nước nổi: mùa thu ngày 2..6
	var dd: int = posmod(o, 28) % 7 + 1
	if W.WR.qs():
		var fs := "Phù sa bồi, cây lớn nhanh 4%. Cá linh về, ven sông có điên điển, bông súng, kèo nèo."
		L.append(["wx_rao", "Nước nổi về sông Vàm", fs, fs, null, 4])
	elif G.cfg.s == "auto":
		var to := posmod(2 * 7 + 1 - (posmod(o, 28)), 28)   # tới ngày 2 mùa thu
		if to >= 1 and to <= 7:
			L.append(["fut", "Nước nổi · còn " + str(to) + " ngày", "Mùa thu nước sông lên, cá linh về.", "Còn " + str(to) + " ngày nữa nước nổi về sông Vàm (mùa thu, ngày 2–6).", null, 4])
	# hạn mặn
	var n4: bool = W.WR.n4()
	var ac: int = W.WR.ac()
	if n4 or (ac >= 0 and ac <= 4):
		var ms := "Nước mặn đang lấn vô sông, ruộng chậm lớn." if n4 else "Chừng " + str(ac) + " ngày nữa mặn lấn vô sông Vàm. Trữ nước ngọt sẵn."
		L.append(["sen" if n4 else "fut", "Hạn mặn", ms, ms, ["Xem", _go(W.WRU.open_man)], 4])
	# gió chướng
	if sea == 3 or sea == 0:
		var cg: bool = W.WCA.cg()
		var gs := "Đang có gió, ra đồng thả diều (bảng nhân vật › Diều)." if cg else "Mùa này chiều 14–18 giờ có gió thả diều."
		L.append(["got" if cg else "fut", "Gió chướng", gs, gs, null, 6])
	var rs := "Bản tin thời tiết ngày mai, giá cả, cải lương."
	L.append(["fut", "Radio", rs, rs, ["Mở radio", _go(W.WCU.open_rd)], 8])
	# cây ngã đè ruộng (mưa dầm, giông)
	var fl: Dictionary = G.troi.bao.wx().fell
	var nf := 0
	var fk := ""
	for k in fl:
		if String(fl[k].s) == "down":
			nf += 1
			if fk == "" or int(fl[k].p) >= 0:
				fk = String(k)
	if nf:
		var fd := "Cây ngã đè ruộng thì ruộng ngưng lớn tới khi dọn. Chạm cây ngã để dọn."
		L.append(["sen", str(nf) + " cây ngã sau giông", "Đè ruộng thì ruộng ngưng lớn, dọn sớm.", fd, ["Tới dọn", _cam_to.bind(fk)], 3])
	# ruộng khô (đất hết nước)
	var nd := 0
	for e in G.B0:
		var rr: Dictionary = G.g.plots[e]
		if rr.c != null and not G.ripe(rr) and float(rr.w) <= 0.0:
			nd += 1
	if nd:
		var ds := "Đất khô thì cây lớn chậm hơn. " + ("Trời nắng hạn, ruộng khô nhanh gấp rưỡi." if _now_w() == "han" else "Tưới để ruộng lớn nhanh hơn 10%.")
		L.append(["wx_han" if _now_w() == "han" else "fut", str(nd) + " ô ruộng đang khô", ds, ds, null, 5])
	L.sort_custom(func(a, b): return int(a[5]) < int(b[5]))
	return L.slice(0, 5)   # tối đa 5 dòng, bỏ bớt dòng ít gấp

func _cam_to(sk: String) -> void:   # đóng bảng, đưa máy quay tới cây ngã
	var B = G.troi.bao
	if not B.by.has(sk):
		return
	var t: Dictionary = B.by[sk]
	var M = U.main
	var cx := float(t.gx) + float(t.fw) / 2.0
	var cy := float(t.gy) + float(t.fd) / 2.0
	M.cam = Vector2(U.F.en(cx, cy), U.F.nn(cx, cy)) - U.get_viewport().get_visible_rect().size / M.zoom * 0.5
	if M.has_method("_clamp_cam"):
		M._clamp_cam()
	close()

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
		out.append_array(_row(y, rh, "got" if v else "fut", ["sáng", "5–" + str(W.WC.wm()) + "g", "t_sang"], "Chợ nổi sông Vàm", "Đang họp" if v else "Chưa họp", cs, ["Đi chợ", _go(W.WCU._pill_go)] if v else null))
	else:
		out.append_array(_row(y, rh, "fut", ["sáng", "5–8g", "t_sang"], "Chợ nổi sông Vàm", "Mở khúc sông Vàm để có chợ", "Mở khúc sông Vàm (khai hoang phía nam) để có chợ nổi."))
	y += rh + g
	# hội chợ sân đình
	var a2 := 0
	while a2 < 4 and not W.WH.c_r(o + a2):
		a2 += 1
	var n2: bool = W.WH.e_r()
	var l2: bool = W.WH.l2()
	var hs := "Đang mở! Ra sân đình chơi ném vòng, đập niêu, lô tô." if l2 else ("Tối nay 18g30–22g30 có hội chợ." if n2 else "Hội chợ kế tiếp " + ("tối mai" if a2 == 1 else "sau " + str(a2) + " ngày") + ". Bỏ 2.000 xu tổ chức tối nay thì chơi liền.")
	out.append_array(_row(y, rh, "got" if l2 else "fut", ["tối", "18g30", "t_toi"], "Hội chợ sân đình", "Đang mở" if l2 else ("Tối nay có hội" if n2 else "Tối nay không có"), hs, null if n2 else ["Tổ chức · 2.000", W.WH.b_]))
	y += rh + g
	# đám cưới / đám giỗ
	var ev = W.WL.tg().get("ev")
	if _tr(ev):
		var a := int(floor(fmod(float(ev.t0), 24.0)))
		var on_d: bool = W.WL.sg() != null
		var es := "Đã dự." if _tr(ev.get("done")) else ("Đang đãi khách, ghé dự liền!" if on_d else "Lúc " + ("0" if a < 10 else "") + str(a) + ":00.")
		out.append_array(_row(y, rh, "got" if on_d else "fut", ["giờ", str(a) + "g", "t_sang" if a < 11 else ("t_chieu" if a < 17 else "t_toi")], String(W.WL.qm(ev)), es, String(W.WL.qm(ev)) + ": " + es))
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
		out.append_array(_row(y, 58.0, "sen" if i == 0 else "fut", ["", "Hôm nay", "le_gan"] if r == 0 else (["còn", str(r) + " ngày", "le_gan"] if r <= 2 else [String(G.SEA_N[int(f.sea)]), "ngày " + str(int(f.day)), "le_xa"]), String(f.n), (String(f.d) if r <= 2 else "Còn " + str(r) + " ngày · " + String(f.d)), String(f.n) + " (" + when + "): " + String(f.d), ["Góp lễ", _go(W.WHU.open_fest)] if r <= 2 else null))
		y += 58.0 + g
	var tx = W.WH.hdn_pill_txt()
	if tx != null:
		var cu: Dictionary = W.WH.hdn_s().cur
		var today: bool = int(tx[1]) == 1
		var hd := ("Hôm nay mở hội ở sân đình.") if today else "Còn " + str(int(cu.d) - o) + " ngày tới hội. Bà con đang góp lễ."
		out.append_array(_row(y, rh, "sen" if today else "fut", ["", "Hôm nay", "le_gan"] if today else (["còn", str(int(cu.d) - o) + " ngày", "le_gan"] if int(cu.d) - o <= 2 else [String(G.SEA_N[int(floor(posmod(int(cu.d), 28) / 7.0))]), "ngày " + str(posmod(int(cu.d), 28) % 7 + 1), "le_xa"]), "Hội đình làng", hd, hd, ["Vào thi" if today else "Chuẩn bị", _go(U.hdn_open.bind("giai" if today else "mo"))]))
		y += rh + g
	return [out, y + 2.0]

static func _tr(v) -> bool:
	return not (v == null or v is bool and not v or (v is float or v is int) and v == 0 or v is String and v == "")
