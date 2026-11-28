extends "res://logic/ui_kbang.gd"
# CHUYỆN LÀNG (clgOpen / clgRender bản web, Sổ làng › Tin tức trong làng). (bản 476) làm lại trên khung Kho + chip chung (ui_kbang.gd):
# tab Tất cả / Nhà mình / Xóm làng / Thiên tai / Buôn bán (chấm đỏ khi có chuyện chưa đọc); chuyện gom theo ngày (ghi mùa),
# việc có nút lên đầu mỗi ngày thành khối vàng; chuyện thường là dòng nhẹ có hình + vạch màu theo loại; chuyện lặp trong ngày gộp 1 dòng
# (chạm mở ra); chuyện chưa đọc có chấm đỏ góc (11-28; trước chip "Mới") tới lần mở bảng sau. Mở xem 1,5 giây thì tính là đã đọc (g.clg.sn).
# Luật ở w_lang.gd (clg_s, clg_act, clg_act_lb, clg_tick).

var W          # w_lang.gd
var tab := "all"            # CLGV.tab
var _mk := -1.0             # CLGV.mk: đếm 1,5 giây rồi ghi đã đọc
var sn0 := 0                # (bản 476) mốc đã đọc lúc mở bảng: chuyện sau mốc này hiện "Mới" suốt lần mở này
var ex := {}                # nhóm chuyện gộp đang mở
var SK := {}                # sky.json: hình thời tiết
const TABS := [["all", "Tất cả"], ["nha", "Nhà mình"], ["xom", "Xóm làng"], ["tt", "Thiên tai"], ["buon", "Buôn bán"]]
const TABC := {"all": "rgb(150, 112, 60)", "nha": "rgb(214, 160, 30)", "xom": "rgb(76, 150, 48)", "tt": "rgb(70, 120, 180)", "buon": "rgb(222, 130, 40)"}

const CLC := {   # (bản 477) nền dòng chuyện theo loại (nhạt như dòng việc Sổ nhiệm vụ): [gradient trên, giữa, dưới, viền]
	"k_nha": ["rgb(247, 236, 210)", "rgb(249, 242, 224)", "rgb(252, 247, 237)", "rgb(232, 203, 131)"],
	"k_xom": ["rgb(219, 234, 214)", "rgb(230, 240, 226)", "rgb(241, 247, 238)", "rgb(157, 197, 141)"],
	"k_tt": ["rgb(218, 228, 240)", "rgb(229, 236, 244)", "rgb(240, 244, 249)", "rgb(153, 181, 214)"],
	"k_buon": ["rgb(248, 230, 212)", "rgb(250, 238, 225)", "rgb(252, 245, 238)", "rgb(237, 186, 137)"],
}

func _ck(kind: String) -> Array:
	return CLC[kind] if CLC.has(kind) else super(kind)

func _init(ui, wl) -> void:
	super(ui)
	W = wl
	SK = Snap.load_snap("sky")

func open(t := "") -> void:   # clgOpen
	if t != "":
		tab = t
	on = true
	scroll = 0.0
	sig = ""
	_mk = -1.0
	ex = {}
	sn0 = int(W.clg_s().sn)
	_build()

func step(dt: float) -> void:   # clgRender mỗi giây
	if not on:
		return
	if _mk >= 0.0:
		_mk -= dt
		if _mk < 0.0:
			var o: Dictionary = W.clg_s()
			if o.sn != o.q:
				o.sn = o.q
				G.mark()
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	var o: Dictionary = W.clg_s()
	return JSON.stringify([tab, ex, o.q, o.l.size(), o.l.slice(0, 40).map(func(r): return r.get("x")), W._vr()])

func _build() -> void:
	sig = _sig()
	var o: Dictionary = W.clg_s()
	if o.sn != o.q and _mk < 0.0:
		_mk = 1.5
	var nw := {}   # loại nào có chuyện chưa đọc (tính theo mốc lúc mở)
	for r in o.l:
		if int(r.q) > sn0:
			nw[String(r.k)] = true
			nw["all"] = true
	var L := TABS.map(func(x): return [x[0], x[1], nw.has(x[0])])
	var sh := _kshell(L, tab, _tab_go)
	var b := _body()
	_kmount(sh[0], sh[1], float(sh[2]), b[0], float(b[1]))

func _tab_go(k: String) -> void:   # data-clg="tab"
	if tab != k:
		tab = k
		scroll = 0.0
		ex = {}

func _kic(cx: float, cy: float, s: float, k: String) -> Dictionary:   # hình theo loại chuyện
	match k:
		"nha":
			return _icx(cx, cy, s, "pic:res://ui/img/xt/g_nha11.webp")
		"xom":
			return _icx(cx, cy, s, "pic:res://ui/img/vlface/0.webp")
		"tt":
			return _dic(cx - s * 0.5, cy - s * 0.5, s, String(SK.ic.mua))
		_:
			return _icx(cx, cy, s, "xu")

func _key(t: String) -> String:   # mẫu câu để gộp chuyện lặp: số thay bằng #
	var re := RegEx.create_from_string("\\d[\\d.]*")
	return re.sub(t, "#", true)

func _body() -> Array:   # clgTab
	var o: Dictionary = W.clg_s()
	var day: int = W._vr()
	var L: Array = o.l.filter(func(r): return tab == "all" or r.k == tab)
	var out := []
	var y := 6.0
	if L.is_empty():
		out.append(_dt(X0, y, XW, 16.0, "Chưa có chuyện gì" + ("" if tab == "all" else " trong mục này") + ". Ghé lại sau nha.", 10.5, 700, SUB, "left"))
		return [out, y + 16.0 + GG]
	# gom theo ngày
	var days := []
	var by := {}
	for r in L:
		var d := int(r.d)
		if not by.has(d):
			by[d] = []
			days.append(d)
		by[d].append(r)
	for d in days:
		var ago: int = day - d
		var sea := int(floor(posmod(d, 28) / 7.0))
		var dn := ("Hôm nay" if ago <= 0 else ("Hôm qua" if ago == 1 else str(ago) + " ngày trước")) + " · " + String(G.SEA_N[sea]) + " " + str(posmod(d, 28) % 7 + 1)
		out.append_array(_sect(y, dn, String(TABC.get(tab, TABC.all)) if ago > 0 else "rgb(200, 70, 60)"))   # hôm nay: vạch đỏ
		y += 16.0 + GG
		var R: Array = by[d]
		# việc có nút lên đầu
		for r in R:
			var lb: String = W.clg_act_lb(r)
			if lb == "":
				continue
			var k := String(r.k)
			var P := _para(X0 + 42.0, y + 10.0, XW - 52.0, String(r.t), 10.5, 700, BROWN, 15.0)
			var h := maxf(10.0 + float(P[1]) + 6.0 + 26.0 + 10.0, 60.0)
			var c := _chip(X0, y, XW, h, "now")
			out.append(c)
			out.append(_kic(X0 + 20.0, y + 22.0, 24.0, k))
			out.append_array(P[0])
			if int(r.q) > sn0:
				out.append(_new(X0 + XW - 12.0, y + 5.0))
			var bw: float = minf(Box.text_w(lb, 10.5, 700) + 24.0, XW - 52.0)
			out.append(_btn(X0 + XW - 10.0 - bw, y + h - 36.0, bw, 26.0, lb, W.clg_act.bind(int(r.q)), "go"))
			y += h + 6.0
		# chuyện thường: gộp chuyện lặp liền nhau (cùng loại, cùng mẫu câu)
		var G0 := []
		for r in R:
			if W.clg_act_lb(r) != "":
				continue
			var kk := String(r.k) + "|" + _key(String(r.t))
			if G0.size() and String(G0.back()[0]) == kk:
				G0.back()[1].append(r)
			else:
				G0.append([kk, [r]])
		for g in G0:
			var rs: Array = g[1]
			var gid := str(d) + "|" + String(g[0])
			var opn: bool = ex.has(gid)
			if rs.size() > 1:
				var r0: Dictionary = rs[0]
				var r1: Dictionary = rs[rs.size() - 1]
				var re := RegEx.create_from_string("\\d[\\d.]*")
				var m0 := re.search_all(String(r0.t))
				var m1 := re.search_all(String(r1.t))
				var t := String(r0.t)
				if m0.size() == 1 and m1.size() == 1:   # 1 số: ghi khoảng "30 → 40"
					var a := int(String(m1[0].get_string()).replace(".", ""))
					var b := int(String(m0[0].get_string()).replace(".", ""))
					t = re.sub(String(r0.t), (str(mini(a, b)) + " → " + str(maxi(a, b))), false)
				else:
					t = String(r0.t) + " (" + str(rs.size()) + " lần)"
				var rr := _line(y, String(r0.k), t, "", int(r0.q) > sn0, _tg.bind(gid), CHU if opn else CHD)
				out.append_array(rr[0])
				y += float(rr[1]) + 4.0
				if opn:
					for r in rs:
						var r2 := _line(y, String(r.k), String(r.t), String(r.get("r", "")), int(r.q) > sn0, null, "", 20.0)
						out.append_array(r2[0])
						y += float(r2[1]) + 4.0
			else:
				var r3 := _line(y, String(rs[0].k), String(rs[0].t), String(rs[0].get("r", "")) if W._tr(rs[0].get("r")) else "", int(rs[0].q) > sn0, null, "")
				out.append_array(r3[0])
				y += float(r3[1]) + 4.0
		y += GG - 4.0
	return [out, y]

func _line(y: float, k: String, t: String, sub: String, nw: bool, act, chev: String, ind := 0.0) -> Array:   # dòng chuyện nhẹ: vạch màu loại, hình, chữ (+ dòng phụ), chấm mới, mũi tên (nhóm gộp)
	var out := []
	var x := X0 + ind
	var w := XW - ind
	var rw := (16.0 if chev != "" else 0.0)
	var L := _wrap(t, 10.5, 600, w - 40.0 - rw)
	var h := 8.0 + L.size() * 15.0 + (13.0 if sub != "" else 0.0) + 8.0
	h = maxf(h, 32.0)
	var c := _chip(x, y, w, h, "k_" + k if CLC.has("k_" + k) else "fut")   # (bản 477) nền theo loại
	out.append(c)
	out.append(_dbx(x + 3.0, y + 5.0, 3.0, h - 10.0, String(TABC.get(k, TABC.all)), 1.5))
	out.append(_kic(x + 20.0, y + h * 0.5, 20.0, k))
	var ty := y + (h - L.size() * 15.0 - (13.0 if sub != "" else 0.0)) * 0.5
	for i in L.size():
		out.append(_dt(x + 36.0, ty + i * 15.0, w - 40.0 - rw, 15.0, String(L[i]), 10.5, 600, BROWN, "left"))
	if sub != "":
		out.append(_dt(x + 36.0, ty + L.size() * 15.0, w - 40.0 - rw, 13.0, _fitw(sub, 10.5, 600, w - 40.0 - rw), 10.5, 600, SUB, "left"))
	var rx := x + w - 8.0
	if chev != "":
		out.append(_dic(rx - 10.0, y + h * 0.5 - 5.0, 10.0, chev))
		rx -= 16.0
	if nw:
		out.append(_new(x + w - 12.0, y + 5.0))
	if act != null:
		c.act = act
	return [out, h]

func _new(x: float, y: float) -> Dictionary:   # (11-28) chuyện mới: chấm đỏ góc trên phải (trước chip "Mới" dòng nào cũng có: rối, chiếm chỗ chữ)
	return _dbx(x, y, 8.0, 8.0, "rgb(214, 69, 65)", 4.0, _cpx(1.0) + " solid rgb(255, 255, 255)")

func _tg(gid: String) -> void:   # chạm nhóm gộp: mở / đóng
	if ex.has(gid):
		ex.erase(gid)
	else:
		ex[gid] = true
