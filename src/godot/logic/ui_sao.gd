extends RefCounted
# NÂNG SAO Ô RUỘNG / CHUỒNG bản web (kind "plot" | "pen": cùng bảng, chuồng chỉ 1 tab mang tên chuồng) (window.ppStarPop đời cuối: .u2pop.u2gold, tab "Ô này"/"Cả N ô", .u2sbx2 > t(a,n)).
# Mỗi trạng thái một bản chụp từ web:
#   sp_ok (đủ cấp đủ đồ, primary), sp_no (thiếu đồ), sp_lock (💎 Nâng sớm), sp_ns (🔒 Cấp L, 4 ô giá, 1 tab),
#   sp_all (tab "Cả 6 ô" đang bật), sp_max (Đã đạt 5★).
# Bấm nút: lf("plot", i) / lf("plotall", r); thiếu cấp thì lớp bọc lf mở zF (ui_kho.ns_show).

const Snap = preload("res://ui/snap.gd")
const Qty = preload("res://logic/qty.gd")

var U
var G
var K                         # ui_kho: _show, _chip, _mix, _ctext, ns_show
var T := {}
var pop: Control = null
var sig := ""
var pi := -1                  # ô đang nâng
var kind := "plot"            # "plot" | "pen" | "work" (xưởng, bản 281)
var pt := ""                  # chuồng đang nâng (kind pen)
var all := false              # n: tab "Cả N ô"
var star_on := ""
var star_off := ""

func _init(ui) -> void:
	U = ui
	G = ui.G
	K = ui.khp
	for k in ["sp_ok", "sp_no", "sp_lock", "sp_ns", "sp_max", "sp_all"]:
		T[k] = Snap.load_snap(k)[".u2pop"][0]
	star_on = Snap.find(T.sp_max, "stars").kids[0].svg
	star_off = Snap.find(T.sp_ok, "stars").kids[0].svg
	# hình rơm, phân, vôi: ô giá 2..4 của sp_ns (hl plot đủ 3 thứ)
	var ch: Array = Snap.find(T.sp_ns, "need").kids
	var ids: Array = G.DJ_PLOT.m
	for j in 3:
		K.mat_svg[ids[j]] = Snap.find(ch[j + 1], "", "svg").get("svg", "")
	for m in G.DJ_PEN.m + G.DJ_WORK.m:   # tre, lá dừa, mây; ván, đinh, gạch: hình món của bản web (ui/svg/mat)
		if not K.mat_svg.has(m):
			K.mat_svg[m] = FileAccess.get_file_as_string("res://ui/svg/mat/" + String(m) + ".svg")

func open(i: int) -> void:   # ppStarPop(a)
	kind = "plot"
	pi = i
	all = false
	sig = ""
	_draw()

func open_pen(t: String) -> void:   # nâng sao chuồng t (lf("pen", t))
	kind = "pen"
	pt = t
	pi = 0
	all = false
	sig = ""
	_draw()

func open_work(k: String) -> void:   # nâng sao xưởng k (bản 281): cùng bảng chuồng, 1 tab mang tên xưởng
	if U.xfp != null:
		U.xfp.close()   # (bản 290) như ruộng / chuồng đóng vòng nút: không chồng bảng xưởng dưới bảng sao
	kind = "work"
	pt = k
	pi = 0
	all = false
	sig = ""
	_draw()

func _r() -> int:   # sao hiện tại
	if kind == "work":
		return G.xw.ks(pt)
	return G.vn.ps(pt) if kind == "pen" else G.star(G.g.plots[pi])

func _us(a: int) -> String:   # Us(kind, a)
	if kind == "work":
		return G.us_work(a)
	return G.us_pen(a) if kind == "pen" else G.us_plot(a)

func _one() -> String:   # tên một thứ (tab, thông báo): chuồng / xưởng
	if kind == "work":
		return String(G.xw.sr[pt].name)
	return String(G.lang.CO.get(pt, "Chuồng"))

func close() -> void:
	if K.ns != null and K.ns_hid == pop:
		K.ns_close()
	if pop != null:
		U.anchors.erase(U._anchor_of(pop))
		pop.queue_free()
		pop = null

func _sig() -> String:
	var o: int = _r()
	var mm := []
	for m in (G.DJ_PEN.m if kind == "pen" else (G.DJ_WORK.m if kind == "work" else G.DJ_PLOT.m)):
		mm.append(G.mat_n(m))
	return "|".join([kind, pt, all, o, G.k4(o).size() if kind == "plot" else 1, int(G.g.coins / 50), ",".join(mm), G.lv(), int(G.g.get("ngoc", 0))])

func step() -> void:
	if pop != null and K.ns == null and _sig() != sig:
		_draw()

# hàng tab: có từ 2 ô cùng sao thì 2 nút (bản sp_ok / sp_all), không thì 1 nút rộng (sp_ns)
func _tabs(n: Dictionary, l: int) -> void:
	var tb := Snap.find(n, "u2tb2")
	var src: Dictionary = Snap.find(T.sp_ns, "u2tb2")
	if l >= 2:
		src = Snap.find(T.sp_all if all else T.sp_ok, "u2tb2")
	var q: Dictionary = Snap.moved(src, Vector2(float(tb.r[0]) - float(src.r[0]), float(tb.r[1]) - float(src.r[1])))
	if l >= 2:
		K._ctext(q.kids[1], "Cả " + str(l) + " ô")
	else:   # (bản 290) chỉ 1 lựa chọn: tiêu đề chữ đậm không nền (thanh xanh trông như nút bấm)
		var t0: Dictionary = q.kids[0]
		t0.css = K._plain_css(t0.css)
		t0.css["color"] = "rgb(74, 52, 20)"
		t0.css["font-size"] = "17px"
		t0.css["font-weight"] = "800"
		K._ctext(t0, _one() if kind != "plot" else "Ô ruộng")
	tb.kids = q.kids

func _draw() -> void:
	if kind == "plot" and (pi < 0 or pi >= G.g.plots.size()):
		close()
		return
	var r: int = _r()
	var l: int = G.k4(r).size() if kind == "plot" else 1
	if l < 2 and all:
		all = false
	sig = _sig()
	var n: Dictionary
	var nd := {}
	var c := false
	var f := false
	var s := false
	var o := 1
	if r >= 6:
		n = T.sp_max.duplicate(true)
	else:
		o = l if all else 1
		nd = G.up_need(r + 1, o, kind)
		c = G.lv() < int(nd.lv)
		f = G.can_pay(nd)
		s = G.early_ok(int(nd.lv)) if c else f
		var key := ""
		if c:
			key = "sp_lock" if s else "sp_ns"
		else:
			key = "sp_ok" if f else "sp_no"
		n = T[key].duplicate(true)
	_tabs(n, l)
	var sv := Snap.find(n, "u2sv")
	var cx: float = float(sv.r[0]) + float(sv.r[2]) * 0.5
	var st: Array = Snap.find(sv, "stars").kids
	for j in st.size():
		st[j].svg = star_on if j + 1 <= r - 1 else star_off   # $h
	var sm: Array = []
	for k in sv.kids:
		if k.tag == "small":
			sm.append(k)
	K._ctext(sm[0], _us(r))
	var rows := [[Snap.find(sv, "stars"), 8.0], [sm[0], 6.0], [sm[1], 0.0]]   # (bản 290) xếp dọc lại trong _flow
	if r < 6:
		var sn: Dictionary = sm[1]
		var tl := String(sn.text)
		K._mix(sn, tl.substr(0, tl.find(":")), "Lên " + str(r), "", cx)   # "Lên N ★", hiệu lực xuống các dòng dưới
		rows = [[rows[0][0], 8.0], [sn, 4.0]]
		var lp: Dictionary = sn.duplicate(true)   # khuôn dòng hiệu lực: chữ đậm như dòng "Lên N"
		lp.css = K._plain_css(sn.css)
		lp.css["font-size"] = "14.5px"
		for t in _diff(_us(r), _us(r + 1)):
			rows.append([_line(lp, t, float(sv.r[0]), float(sv.r[2])), 2.0])
		rows[-1][1] = 10.0
		# Q4(l): ô xu + ô vật liệu, lưới 4 cột (chỗ đứng lấy từ sp_ns)
		var need := Snap.find(sv, "need")
		var slots: Array = Snap.find(T.sp_ns, "need").kids
		var dy: float = float(need.r[1]) - float(Snap.find(T.sp_ns, "need").r[1])
		var out := [K._chip(Snap.moved(slots[0], Vector2(0, dy)), "xu", int(G.g.coins) >= int(nd.xu), int(G.g.coins), int(nd.xu), "")]
		for j in nd.m.size():
			var m: Array = nd.m[j]
			var hv: int = G.mat_n(m[0])
			out.append(K._chip(Snap.moved(slots[j + 1], Vector2(0, dy)), m[0], hv >= int(m[1]), hv, int(m[1]), K.mat_svg.get(m[0], "")))
		var pcb := Snap.find(n, "u2pc")   # hàng ô giá rộng hết lòng bảng (trừ khung tre) cho vừa 4 ô
		need.r = [float(pcb.r[0]) + 12.0, need.r[1], float(pcb.r[2]) - 24.0, need.r[3]]
		Qty.row(need, out)   # (bản 291) đúng số ô món cần, canh giữa, chật thì xuống hàng
		var bt := Snap.find(sv, "", "button")
		rows.append([need, 10.0])
		rows.append([bt, 0.0])
		if c and s:
			_gem_l(bt, "Nâng sớm (cần cấp " + str(nd.lv) + ")", cx)
		elif c:
			K._ctext(bt, "🔒 Cần cấp " + str(nd.lv) + " · còn " + str(int(nd.lv) - G.lv()) + " cấp")
		else:
			var bl := String(bt.text)
			K._mix(bt, bl, ("Nâng cả " + str(o) + " ô lên " + str(r)) if all else ("Nâng lên " + str(r)), "", cx)
	_flow(n, rows, l < 2)
	var keep := pop != null
	var vis := pop.visible if pop != null else true
	if pop != null:
		U.anchors.erase(U._anchor_of(pop))
		pop.queue_free()
		pop = null
	var ids := {}
	pop = K._show(n, "u2pc", ids, close)
	pop.visible = vis
	var tw: Control = U._q(pop, "u2tb2")
	var tbs: Array = U._buttons(tw, []) if tw != null else []
	for j in tbs.size():   # thứ tự trong trang: 0 "Ô này", 1 "Cả N ô"
		var to_all: bool = j == 1
		U._click(tbs[j], func():
			all = to_all
			_draw(), "down")
	if r < 6 and s:
		var bb: Control = U._q(pop, "btn")
		if bb != null:
			U._click(bb, up, "scale")
	U._layout()
	if not keep:
		G.vib(0)

var _rv := RegEx.create_from_string("^(.*?)(\\+?\\d+(?:[.,]\\d+)?\\s*(?:%|phút|giờ|ngày))(.*)$")

func _diff(cur: String, nxt: String) -> Array:   # (bản 290) mỗi hiệu lực một dòng "nhãn cũ → mới"; chưa có thì "(mới)"
	var out := []
	var cl := cur.to_lower()
	for p in nxt.split(" · "):
		var m := _rv.search(p)
		var t: String = p + " (mới)"
		if m != null and m.get_string(1).strip_edges() != "":
			var lb := m.get_string(1)
			var at := cl.find(lb.to_lower())
			if at >= 0:
				var m2 := _rv.search(cur.substr(at))
				if m2 != null and m2.get_string(1).to_lower() == lb.to_lower():
					t = lb + m2.get_string(2) + " → " + m.get_string(2) + m.get_string(3)
		out.append(t.substr(0, 1).to_upper() + t.substr(1))
	return out

func _line(proto: Dictionary, s: String, x0: float, w: float) -> Dictionary:   # một dòng chữ giữa bề ngang w
	var o: Dictionary = proto.duplicate(true)
	o.kids = []
	o.cls = ""
	o.r = [x0, 0.0, w, 19.0]
	o.tr = [x0, 0.0, w, 19.0]
	K._ctext(o, s)
	return o

func _flow(n: Dictionary, rows: Array, single: bool) -> void:   # (bản 290) xếp dọc các hàng [nút, khoảng dưới]; hộp và khung tre co giãn theo
	var sv := Snap.find(n, "u2sv")
	var pc := Snap.find(n, "u2pc")
	var tb := Snap.find(n, "u2tb2")
	var d0 := 0.0   # (bản 291) 1 lựa chọn: bỏ hàng tab 34, tên nằm sát mép trên, khoảng trên = khoảng dưới
	if single:
		var top: float = float(pc.r[1]) + 20.0
		Snap._move(tb, Vector2(0, top - float(tb.r[1])))
		var t0: Dictionary = tb.kids[0]
		var th := 22.0
		tb.r = [tb.r[0], top, tb.r[2], th]
		t0.r = [t0.r[0], top, t0.r[2], th]
		var tr: Array = t0.get("tr", t0.r)
		t0.tr = [tr[0], top + (th - float(tr[3])) * 0.5, tr[2], tr[3]]
		var sb := Snap.find(n, "u2sbx2")
		d0 = top + th + 12.0 - float(sb.r[1])
		Snap._move(sb, Vector2(0, d0))
	var cx: float = float(sv.r[0]) + float(sv.r[2]) * 0.5
	var stb := Snap.find(sv, "stars")   # sao to 1,5 lần
	var st: Array = stb.kids
	var S := 31.0
	var gp := 5.0
	var tw: float = S * st.size() + gp * (st.size() - 1)
	for j in st.size():
		st[j].r = [cx - tw * 0.5 + j * (S + gp), float(stb.r[1]), S, S]
	stb.r = [cx - tw * 0.5, float(stb.r[1]), tw, S]
	var y: float = float(sv.r[1])
	var kids := []
	for e in rows:
		var nd: Dictionary = e[0]
		Snap._move(nd, Vector2(0, y - float(nd.r[1])))
		kids.append(nd)
		y += float(nd.r[3]) + float(e[1])
	var d: float = y - float(sv.r[1]) - float(sv.r[3])
	sv.kids = kids
	var sb2 := Snap.find(n, "u2sbx2")
	sv.r = [sv.r[0], sv.r[1], sv.r[2], float(sv.r[3]) + d]
	sb2.r = [sb2.r[0], sb2.r[1], sb2.r[2], float(sb2.r[3]) + d]
	d += d0
	for c in ["u2pc", "u2tre"]:
		var q := Snap.find(n, c)
		if not q.is_empty():
			q.r = [q.r[0], q.r[1], q.r[2], float(q.r[3]) + d]
	var tre := Snap.find(n, "u2tre")
	for k in tre.get("kids", []):
		var cs: PackedStringArray = String(k.cls).split(" ")
		if cs.has("l") or cs.has("r"):
			k.r = [k.r[0], k.r[1], k.r[2], float(k.r[3]) + d]
		elif cs.has("b") or cs.has("c3") or cs.has("c4"):
			Snap._move(k, Vector2(0, d))
	Snap._move(Snap.find(n, "u2pc"), Vector2(0, -d * 0.5))   # giữ giữa màn

func up() -> void:   # click data-up → lf (lớp bọc nâng sớm)
	var r: int = _r()
	if r >= 6:
		return
	var o: int = G.k4(r).size() if all else 1
	if all and o == 0:
		return
	var nd: Dictionary = G.up_need(r + 1, o, kind)
	var t := pt
	var go: Callable = (func(): return G.work_up(t)) if kind == "work" else ((func(): return G.pen_up(t)) if kind == "pen" else ((func(): return G.plot_up_all(r)) if all else (func(): return G.plot_up(pi))))
	if G.lv() < int(nd.lv):   # e$ + zF
		if G.early_ok(int(nd.lv)):
			K.ns_show({"t": (_one().to_lower() if kind != "plot" else ((str(o) + " ô ruộng") if all else "ô ruộng")) + " lên " + str(r) + "★", "nd": nd,
				"fee": G.NS_FEE[r + 1] * G.early_lv(int(nd.lv)) * o, "go": go, "hide": pop,
				"done": func():
					sig = ""
					if pop != null:
						_draw()})
		else:
			U.say("Cần cấp " + str(nd.lv) + ". Chỉ nâng sớm được khi thiếu tối đa " + str(G.KHO_SA) + " cấp.")
		return
	go.call()
	sig = ""
	if pop != null:
		_draw()

func _gem_l(bt: Dictionary, s: String, cx: float) -> void:
	# "[💎 hình] chữ" giữa nút: khoảng hở hình–chữ đo từ bản chụp sp_lock
	var ic: Dictionary = bt.kids[0]
	var tr: Array = bt.get("tr", bt.r)
	var gap: float = float(tr[0]) - float(ic.r[0]) - float(ic.r[2])
	var w: float = U._tw(bt, s)
	var x: float = cx - (float(ic.r[2]) + gap + w) * 0.5
	Snap._move(ic, Vector2(x - float(ic.r[0]), 0))
	bt.text = s
	bt.tr = [x + float(ic.r[2]) + gap, float(tr[1]), w + 0.5, float(tr[3])]
