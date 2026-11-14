extends "res://logic/ui_pop.gd"
# TRỜI ĐẤT TRONG LÀNG (RN / Hh bản web, chạm ô giờ - thời tiết góc trái trên): hộp nổi khung tre (ui_pop.gd).
# Thời tiết bây giờ, dự báo 6 buổi, lịch lễ hội (4 lễ gần nhất), chợ nổi, nhạc đờn ca tài tử, rồi thẻ của từng phần
# (sky() của W1 bản web: tát ao, hụi, đám, gió chướng, radio, rầy nâu, hội chợ, hạn mặn, hội thi, nồi cơm, thiên tai, hội đình),
# cuối là nút "Chỉnh giờ ngày đêm, mùa". Mẫu: ui/snap/sky.json (wxnow, ô dự báo, hình thời tiết), hui_tab.json (.tt).

var SK := {}
static var nhac := true   # Kl.on: nhạc đờn ca (bản Godot chưa có nhạc nền, chỉ giữ nút)

const TK := ["Khuya", "Sáng", "Chiều", "Tối"]
const T8 := ["Mùa xuân", "Mùa hạ", "Mùa thu", "Mùa khô"]
const HQ := {"nang": "Không có gì đặc biệt. Thỉnh thoảng có mưa rào tưới giùm.",
	"mua": "Ruộng, cây ăn trái tự được tưới. Nhân vật đi chậm 20% nếu không mặc áo mưa.",
	"giong": "Ruộng tự được tưới. Gió quật ngã 1–3 cây, cây đè ruộng thì ruộng ngưng lớn tới khi dọn. Đi chậm 30% nếu không mặc áo mưa.",
	"han": "Ruộng khô nhanh gấp rưỡi, không có mưa rào. Lu nước, giếng, ao gần ruộng giúp đỡ khô."}
const RK := ["điệu Bắc rộn ràng", "điệu Nam thong thả", "điệu Oán man mác", "điệu Oán chậm rãi"]   # rk[xi].nm

func _init(ui) -> void:
	super(ui)
	SK = Snap.load_snap("sky")

func open() -> void:   # RN
	on = true
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	return JSON.stringify([_now_w(), G.day(), int(G.nv.hour() * 4.0), G.g.get("hui"), G.g.get("ray", {}).get("th"), G.ray_n(), G.g.get("hc"), nhac, G.cfg.a])

func _now_w() -> String:   # ti.cur || Wd()
	return G.troi.cur if G.troi.cur != "" else G.nv.Wd()

func _build() -> void:
	sig = _sig()
	var out := [_wxnow()]
	out[0].gap = 0.0
	out.append(_sec_p("Dự báo", "Mỗi ngày chia 4 buổi, mỗi buổi 6 tiếng. Mưa dầm, giông bão chỉ 2 tiếng đầu buổi rồi tạnh, nắng đẹp tới hết buổi."))
	out[-1].gap = 4.5
	var wf := _wxf()
	wf.gap = 7.5
	out.append(wf)
	out.append(_sec_p("Lịch lễ hội", "Ba ngày trước lễ, bà con nhờ góp lễ vật. Đủ lễ thì ngày hội cả làng nhận lộc."))
	out[-1].gap = 4.5
	var first := true
	for c in _cards():
		c.gap = 7.5 if first else 6.0
		first = false
		out.append(c)
	var jb := _cl(SK.jobs)
	jb.kids[0].act = _go(func(): U.setp.open())
	jb.gap = 7.5
	out.append(jb)
	_pop(out)

# ------------------------------------------------------------------ bây giờ: hình, "Nắng hạn · Mùa xuân ngày 7", lời giải thích
func _wxnow() -> Dictionary:
	var a := _now_w()
	var n := _cl(SK.wxnow)
	n.kids[0].svg = SK.ic[a]
	var d: Dictionary = n.kids[1]
	var b: Dictionary = d.kids[0]
	var sea: int = G.season()
	var auto: bool = G.cfg.s == "auto"
	var st := _cl(b)
	st.erase("kids")
	var hb := _put(b, [_r(String(G.troi.TEN[a]) + " · " + T8[sea] + (" ngày " + str(posmod(G.day(), 28) % 7 + 1) if auto else ""), st)], "left", float(d.r[2]))
	b.r[3] = hb
	var sm: Dictionary = d.kids[1]
	_mv(sm, float(sm.r[0]), float(b.r[1]) + hb + 1.8)
	var s2 := _cl(sm)
	s2.erase("kids")
	var hs := _put(sm, [_r(HQ[a], s2)], "left", float(d.r[2]))
	sm.r[3] = hs + 3.0
	d.r[3] = float(sm.r[1]) + float(sm.r[3]) - float(d.r[1])
	n.r[3] = maxf(float(d.r[3]), 42.0) + 15.0
	d.r[1] = float(n.r[1]) + (float(n.r[3]) - float(d.r[3])) * 0.5
	_mv(n.kids[0], float(n.kids[0].r[0]), float(n.r[1]) + (float(n.r[3]) - 42.0) * 0.5)
	var dy := float(d.r[1]) - float(b.r[1])
	for k in [b, sm]:
		Snap._move(k, Vector2(0, dy))
	return n

# ------------------------------------------------------------------ dự báo 6 buổi (Hx)
func _wxf() -> Dictionary:
	var w := _cl(SK.wxf)
	var e: int = G.day() * 4 + int(floor(G.nv.hour() / 6.0))   # Ox
	var o: int = G.day()
	var x0 := float(w.r[0])
	var y0 := float(w.r[1])
	var cw := float(SK.cell.r[2])
	var chh := float(SK.cell.r[3])
	var kids := []
	for i in 6:
		var c: int = e + i + 1
		var f: String = G.nv.Hx(c)
		var s: int = int(floor(c / 4.0)) - o
		var n := _cl(SK.cell)
		_mv(n, x0 + (i % 4) * (cw + 4.5), y0 + (i / 4) * (chh + 4.5))
		n.kids[0].svg = SK.ic[f]
		_ctxt(n.kids[1], TK[posmod(c, 4)], n)
		_ctxt(n.kids[2], "hôm nay" if s == 0 else ("mai" if s == 1 else "mốt"), n)
		_ctxt(n.kids[3], G.troi.TEN[f], n)
		kids.append(n)
	w.kids = kids
	w.r[3] = 2 * chh + 4.5
	return w

func _ctxt(n: Dictionary, s: String, box: Dictionary) -> void:   # chữ giữa ô
	var w := _tw(n, s)
	var x := float(box.r[0]) + (float(box.r[2]) - w) * 0.5
	n.text = s
	n.r = [x, n.r[1], w, n.r[3]]
	if n.has("tr"):
		n.tr = [x, n.tr[1], w, n.tr[3]]

# ------------------------------------------------------------------ thẻ .tt
func _t(got: bool, title: String, small: String, btn = null) -> Dictionary:
	return _tt_p(got, [[title, false]], small, btn)

func _go(f: Callable) -> Callable:   # đóng bảng rồi mở bảng khác
	return func(): close(); f.call()

func _cards() -> Array:
	var W = G.w_all
	var out := []
	var o: int = G.day()
	# lễ hội: 4 lễ gần nhất trong 56 ngày
	var seen := {}
	var p := []
	for r in 56:
		if p.size() >= 4:
			break
		var d = W.WH.mm(o + r)
		if d != null and not seen.has(d.id):
			seen[d.id] = 1
			p.append([d, r])
	for x in p:
		var f: Dictionary = x[0]
		var r: int = x[1]
		out.append(_t(false, String(f.n), ("Hôm nay" if r == 0 else "Còn " + str(r) + " ngày") + " · " + String(G.SEA_N[int(f.sea)]) + " ngày " + str(int(f.day)) + " · " + String(f.d),
			["Góp lễ", true, true, _go(W.WHU.open_fest)] if r <= 2 else null))
	# chợ nổi
	var v: bool = W.WC.b2()
	out.append(_t(false, "Chợ nổi sông Vàm", ("Họp từ 5 giờ tới " + str(W.WC.wm()) + " giờ sáng mỗi ngày. " + ("Đang họp!" if v else "Bây giờ chưa họp.")) if W.WC.u4() != null else "Mở khúc sông Vàm (khai hoang phía nam) để có chợ nổi.",
		["Đi chợ", true, true, _go(W.WCU._pill_go)] if v else null))
	# nhạc đờn ca tài tử
	out.append(_t(false, "Nhạc đờn ca tài tử", "Mùa này đàn " + RK[G.season()] + ". Kèm tiếng rao, chuông chùa chiều." + ("" if int(G.cfg.a) == 1 else " Đang tắt âm thanh chung."),
		["Đang bật" if nhac else "Đang tắt", false, true, func(): nhac = not nhac]))
	# tát ao
	if W.WC._ci("ao"):
		var am: bool = W.WCA.am()
		out.append(_t(am, "Tát ao bắt cá", "Tuần này chưa tát! Ra bờ ao sen chạm cái gàu sòng." if am else "Tuần này tát rồi, tuần sau tát tiếp."))
	# hụi
	var h = G.g.get("hui")
	var hon: bool = h is Dictionary and not _tr(h.get("done"))
	out.append(_t(hon, "Hụi làng", ("Đang chơi hụi " + String(h.n) + ", kỳ " + str(W.WH.y6()) + "/6" + (", đã hốt" if _tr(h.get("hot")) else ", chưa hốt")) if hon else "Chưa chơi dây hụi nào.",
		["Xem", false, true, _go(U.hui_open)]))
	# đám cưới / đám giỗ
	var ev = W.WL.tg().get("ev")
	if _tr(ev):
		var a := int(floor(fmod(float(ev.t0), 24.0)))
		var on_d: bool = W.WL.sg() != null
		out.append(_t(on_d, W.WL.qm(ev), "Đã dự." if _tr(ev.get("done")) else ("Đang đãi khách, ghé dự liền!" if on_d else "Lúc " + ("0" if a < 10 else "") + str(a) + ":00.")))
	# gió chướng (mùa khô, mùa xuân)
	if G.season() == 3 or G.season() == 0:
		var cg: bool = W.WCA.cg()
		out.append(_t(cg, "Gió chướng", "Đang có gió, ra đồng thả diều (bảng nhân vật › Diều)." if cg else "Mùa này chiều 14–18 giờ có gió thả diều."))
	# radio, thư nhà
	var th: Dictionary = W.WC.Eg()
	out.append(_t(false, "Radio, thư nhà", "Bản tin thời tiết ngày mai, giá cả, cải lương." + (" Có thư chưa xử lý." if _tr(th.get("un")) or _tr(th.get("rq")) else " Ông đưa thư ghé khoảng 9–12 giờ."),
		["Mở radio", false, true, _go(W.WCU.open_rd)]))
	# rầy nâu
	var es: int = G.ray_n()
	out.append(_t(es == 0, "Rầy nâu", ("Đang có dịch: " + str(es) + " ô bị rầy." if es else "Ruộng đang sạch rầy.") + " Mùa hạ, mùa thu, trời mưa dễ có dịch. Đèn bẫy rầy (Xây dựng › Đồ vật) che ruộng trong 6 ô. Thuốc còn " + str(int(G.g.ray.th)) + " lần.",
		["Mua bình thuốc · 150", false, true, func(): G.ray_buy(1)]))
	# hội chợ sân đình
	var a2 := 0
	while a2 < 4 and not W.WH.c_r(o + a2):
		a2 += 1
	var n2: bool = W.WH.e_r()
	var l2: bool = W.WH.l2()
	out.append(_t(l2, "Hội chợ sân đình", "Đang mở! Ra sân đình chơi ném vòng, đập niêu, lô tô." if l2 else ("Tối nay 18g30–22g30 có hội chợ." if n2 else "Hội chợ kế tiếp " + ("tối mai" if a2 == 1 else "sau " + str(a2) + " ngày") + ". Muốn chơi liền thì bỏ 2.000 xu tổ chức tối nay."),
		null if n2 else ["Tổ chức tối nay · 2.000", false, true, W.WH.b_]))
	# hạn mặn
	var n4: bool = W.WR.n4()
	var ac: int = W.WR.ac()
	if n4 or (ac >= 0 and ac <= 4):
		out.append(_t(n4, "Hạn mặn", "Nước mặn đang lấn vô sông, ruộng chậm lớn." if n4 else "Chừng " + str(ac) + " ngày nữa mặn lấn vô sông Vàm. Trữ nước ngọt sẵn.",
			["Xem", false, true, _go(W.WRU.open_man)]))
	# hội thi làng, nồi cơm trưa (chơi mạng: bản Godot chưa có)
	var hr: float = G.nv.hour()
	var thi := hr >= 19.0 and hr < 19.25
	out.append(_t(thi, "🔔 Hội thi làng", "Mỗi tối 19:00–19:15 ở sân đình: 10 câu đố về Nam Bộ: địa danh, đặc sản, ca dao, cải lương, lễ hội, chuyện trong làng. Đúng càng nhiều thưởng càng lớn, đúng hết được Rung chuông vàng.",
		["Vào thi", true, true, U.say.bind(U.SOON)] if thi else null))
	var com := hr >= 12.0 and hr < 12.5
	var cp := int(W.WH.n5().get("p", 0))
	out.append(_t(com, "🍚 Nồi cơm trưa của làng", "Mỗi trưa 12:00–12:30: cả làng góp nguyên liệu vào một nồi chung. Đông hay vắng thì mốc tự co giãn, vắng có hàng xóm góp phụ. Góp từ 10 điểm là có quà theo mốc nồi đạt được." + (" Hôm nay bạn góp " + str(cp) + " điểm." if cp else ""),
		["Góp ngay" if com else "Xem nồi", com, true, U.say.bind(U.SOON)]))
	# thiên tai ngày mai
	var tn = W.WL.tn_on(o + 1) if W.WL.tn_ok() else null
	if tn != null:
		var K: Dictionary = W.WL.TNK[String(tn.k)]
		out.append(_t(true, String(K.w), String(K.d), ["Phòng chống", true, true, _go(U.tn_open.bind("phong"))]))
	# hội đình
	var tx = W.WH.hdn_pill_txt()
	if tx != null:
		var cu: Dictionary = W.WH.hdn_s().cur
		var today: bool = int(tx[1]) == 1
		out.append(_t(true, "Hội đình làng", ("Hôm nay mở hội ở sân đình: " + ", ".join(PackedStringArray(cu.giai.map(func(id): return String(W.WH.HDNG[id]).to_lower()))) + ".") if today else "Còn " + str(int(cu.d) - o) + " ngày tới hội. Bà con đang góp lễ.",
			["Vào thi" if today else "Chuẩn bị", true, true, _go(U.hdn_open.bind("giai" if today else "mo"))]))
	return out

static func _tr(v) -> bool:
	return not (v == null or v is bool and not v or (v is float or v is int) and v == 0 or v is String and v == "")
