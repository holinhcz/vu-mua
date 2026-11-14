extends RefCounted
# NÂNG SAO Ô RUỘNG / CHUỒNG bản web (kind "plot" | "pen": cùng bảng, chuồng chỉ 1 tab mang tên chuồng) (window.ppStarPop đời cuối: .u2pop.u2gold, tab "Ô này"/"Cả N ô", .u2sbx2 > t(a,n)).
# Mỗi trạng thái một bản chụp từ web:
#   sp_ok (đủ cấp đủ đồ, primary), sp_no (thiếu đồ), sp_lock (💎 Nâng sớm), sp_ns (🔒 Cấp L, 4 ô giá, 1 tab),
#   sp_all (tab "Cả 6 ô" đang bật), sp_max (Đã đạt 5★).
# Bấm nút: lf("plot", i) / lf("plotall", r); thiếu cấp thì lớp bọc lf mở zF (ui_kho.ns_show).

const Snap = preload("res://ui/snap.gd")

var U
var G
var K                         # ui_kho: _show, _chip, _mix, _ctext, ns_show
var T := {}
var pop: Control = null
var sig := ""
var pi := -1                  # ô đang nâng
var kind := "plot"            # "plot" | "pen"
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
	for m in G.DJ_PEN.m:   # tre, lá dừa, mây: hình món của bản web (ui/svg/mat)
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

func _r() -> int:   # sao hiện tại
	return G.vn.ps(pt) if kind == "pen" else G.star(G.g.plots[pi])

func _us(a: int) -> String:   # Us(kind, a)
	return G.us_pen(a) if kind == "pen" else G.us_plot(a)

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
	for m in (G.DJ_PEN.m if kind == "pen" else G.DJ_PLOT.m):
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
	elif kind == "pen":
		K._ctext(q.kids[0], String(G.lang.CO.get(pt, "Chuồng")))
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
	if r < 6:
		var sn: Dictionary = sm[1]
		var tl := String(sn.text)
		K._mix(sn, tl.substr(0, tl.find(":")), "Lên " + str(r), ": " + _us(r + 1), cx)
		# Q4(l): ô xu + ô vật liệu, lưới 4 cột (chỗ đứng lấy từ sp_ns)
		var need := Snap.find(sv, "need")
		var slots: Array = Snap.find(T.sp_ns, "need").kids
		var dy: float = float(need.r[1]) - float(Snap.find(T.sp_ns, "need").r[1])
		var out := [K._chip(Snap.moved(slots[0], Vector2(0, dy)), "xu", int(G.g.coins) >= int(nd.xu), int(G.g.coins), int(nd.xu), "")]
		for j in nd.m.size():
			var m: Array = nd.m[j]
			var hv: int = G.mat_n(m[0])
			out.append(K._chip(Snap.moved(slots[j + 1], Vector2(0, dy)), m[0], hv >= int(m[1]), hv, int(m[1]), K.mat_svg.get(m[0], "")))
		need.kids = out
		var bt := Snap.find(sv, "", "button")
		if c and s:
			_gem_l(bt, "Nâng sớm (cần cấp " + str(nd.lv) + ")", cx)
		elif c:
			K._ctext(bt, "🔒 Cấp " + str(nd.lv))
		else:
			var bl := String(bt.text)
			K._mix(bt, bl, ("Nâng cả " + str(o) + " ô lên " + str(r)) if all else ("Nâng lên " + str(r)), "", cx)
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

func up() -> void:   # click data-up → lf (lớp bọc nâng sớm)
	var r: int = _r()
	if r >= 6:
		return
	var o: int = G.k4(r).size() if all else 1
	if all and o == 0:
		return
	var nd: Dictionary = G.up_need(r + 1, o, kind)
	var t := pt
	var go: Callable = (func(): return G.pen_up(t)) if kind == "pen" else ((func(): return G.plot_up_all(r)) if all else (func(): return G.plot_up(pi)))
	if G.lv() < int(nd.lv):   # e$ + zF
		if G.early_ok(int(nd.lv)):
			K.ns_show({"t": (String(G.lang.CO.get(pt, "Chuồng")).to_lower() if kind == "pen" else ((str(o) + " ô ruộng") if all else "ô ruộng")) + " lên " + str(r) + "★", "nd": nd,
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
