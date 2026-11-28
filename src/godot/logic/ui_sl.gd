extends "res://logic/ui_kbang.gd"
# SỔ LÀNG (i4 bản web, nút "Sổ làng" trong Menu). (bản 496) làm lại trên khung Kho + chip chung (ui_kbang.gd):
#  - dải đầu cố định: huy chương + danh hiệu đang mang + "Đã đạt N/8 danh hiệu" + thanh (chạm: tab Danh hiệu);
#  - tab Làng: lưới 2 cột (hình màu, tên, dòng phụ) nền nhạt theo nhóm; việc cần làm: chấm đỏ + dòng phụ đỏ; chưa mở: mờ + khóa;
#  - tab Danh hiệu: đủ điều kiện lên đầu (nền xanh, nút Nhận), đang làm (2 dòng + thanh đỏ → xanh + chip xu), đã nhận gom cuối 1 dòng ✓;
#  - tab Bộ sưu tập: 5 chip loại đều nhau thẳng cột lưới, thanh "N/M", lưới 5 cột nền theo loại (Món chia nhóm theo xưởng),
#    món chưa có: bóng mờ + "?", chạm ô: tên, giá, chỗ kiếm (G.where).
# Luật danh hiệu ở w_ca.gd, dòng phụ thẻ ở w_lang.gd.

var WCA        # w_ca.gd (Tc, Bs, cV, aB)
var W          # w_lang.gd (dòng phụ, chấm đỏ)
var WH         # w_htx.gd (Lf: sạp quê)
var tab := "lang"        # t
var bs := "ns"           # a: chip bộ sưu tập
var SK := {}             # sky.json: hình trời
const TOP := 46.0        # cao dải đầu danh hiệu

const LOCK := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M7 10V7a5 5 0 0 1 10 0v3\" fill=\"none\" stroke=\"rgb(120,112,98)\" stroke-width=\"2.4\"/><rect x=\"4\" y=\"10\" width=\"16\" height=\"11\" rx=\"2.5\" fill=\"rgb(150,140,120)\"/><circle cx=\"12\" cy=\"15.5\" r=\"1.8\" fill=\"#fff\"/></svg>"
const SLC := {   # nền chip riêng Sổ làng: nhóm thẻ tab Làng, loại bộ sưu tập
	"g_ng": ["rgb(219, 234, 214)", "rgb(230, 240, 226)", "rgb(241, 247, 238)", "rgb(157, 197, 141)"],
	"g_vl": ["rgb(248, 230, 212)", "rgb(250, 238, 225)", "rgb(252, 245, 238)", "rgb(237, 186, 137)"],
	"g_tt": ["rgb(218, 228, 240)", "rgb(229, 236, 244)", "rgb(240, 244, 249)", "rgb(153, 181, 214)"],
	"g_vc": ["rgb(246, 222, 224)", "rgb(249, 233, 234)", "rgb(252, 243, 243)", "rgb(226, 160, 166)"],
	"b_ns": ["rgb(222, 240, 210)", "rgb(232, 245, 224)", "rgb(242, 250, 238)", "rgb(150, 196, 120)"],
	"b_tc": ["rgb(255, 232, 206)", "rgb(255, 240, 222)", "rgb(255, 248, 238)", "rgb(226, 160, 90)"],
	"b_mon": ["rgb(250, 238, 200)", "rgb(252, 244, 218)", "rgb(254, 250, 234)", "rgb(212, 172, 80)"],
	"b_ca": ["rgb(214, 230, 244)", "rgb(226, 238, 248)", "rgb(238, 245, 252)", "rgb(120, 160, 206)"],
	"b_ct": ["rgb(234, 224, 244)", "rgb(241, 233, 248)", "rgb(247, 242, 252)", "rgb(164, 138, 200)"],
}
func _ck(kind: String) -> Array:
	return SLC[kind] if SLC.has(kind) else super(kind)

const LIC := {"gp": "pic:res://ui/img/vlface/m0.webp", "kh": "svg:res://ui/svg/mat/khach_sg.svg", "hr": "pic:res://ui/img/vlface/m3.webp",
	"ut": "svg:res://ui/svg/mat/huychuong.svg", "tn": "sky:giong", "hdn": "svg:res://ui/svg/mat/dinh_lang.svg", "st": "svg:res://ui/svg/mat/thu.svg",
	"gd": "svg:res://ui/svg/mat/la.svg", "rk": "svg:res://ui/svg/mat/huychuong.svg", "kl": "qua_saurieng", "cp": "pic:res://ui/img/xt/g_quan1.webp",
	"dl": "svg:res://ui/svg/mat/khach_tay.svg"}   # hình màu từng thẻ tab Làng
const BIC := {"nong": "lua", "vuon": "qua_xoai", "kheo": "banh", "cau": "ca_chep", "dung": "svg:res://ui/svg/mat/gach.svg", "than": "", "lao": "svg:res://ui/svg/mat/huychuong.svg", "all": "svg:res://ui/svg/mat/huychuong.svg"}   # hình từng danh hiệu ("" = tim)

func _init(ui, wca, wl, wh) -> void:
	super(ui)
	WCA = wca
	W = wl
	WH = wh
	SK = Snap.load_snap("sky")

var _vb := -1   # (bản 497) khúc cuộn đã dựng của tab Bộ sưu tập: chỉ dựng ô quanh màn hình, cuộn tới đâu dựng tới đó
const VB := 200.0

func step(dt: float) -> void:
	if on and tab == "bst" and int(scroll / VB) != _vb:
		_build()
		return
	super(dt)

func open() -> void:   # Al("book"): luôn về tab Làng
	tab = "lang"
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	var cur := []
	for t in WCA.bs_list():
		cur.append(WCA.bs_cur(t.id))
	var s := [tab, bs, WCA.tc(), cur]
	if tab == "lang":
		s.append(_links().map(func(g): return g[2].map(func(r): return [r[2], r[3], r[4]])))
	return JSON.stringify(s)

func _ic2(cx: float, cy: float, z: float, k: String) -> Dictionary:   # hình: "sky:<loại>" hình trời, "" tim, còn lại _icx
	if k == "":
		return _dic(cx - z * 0.5, cy - z * 0.5, z, HEART)
	if k.begins_with("sky:"):
		return _dic(cx - z * 0.5, cy - z * 0.5, z, String(SK.ic.get(k.substr(4), SK.ic.nang)))
	return _icx(cx, cy, z, k)

# ------------------------------------------------------------------ dữ liệu thẻ lối vào: [[tên nhóm, loại chip, [[khóa, tên, dòng phụ, gấp (chấm đỏ), khóa (chưa mở)]]]]
func _links() -> Array:
	var cp: int = WH.lf().list.size() if WH != null else 0
	var L = G.g.get("lang")
	var nf: int = L.fam.size() if L is Dictionary and L.get("fam") is Dictionary else 0
	var ut: Dictionary = W.ut_s()
	var kl = G.g.get("kl")
	var nk: int = kl.b.size() if kl is Dictionary and kl.get("b") is Dictionary else 0
	var nn: int = W.tn_s().nan.size() if W.tn_ok() else 0
	var hw: String = WH.hdn_why() if WH != null else "Chưa mở được"
	var hs: String = W.hdn_bk_sub()
	var hlk: bool = hs == "Chưa mở được"
	var hshort := "Cần có chức" if hw.begins_with("Có chức") else ("Cần có đình" if hw.contains("đình") else hs)
	var tn_sub: String = W.tn_bk_sub()
	var R := [["Bà con lối xóm", "g_ng", [["gp", "Gia phả", (str(nf) + " nhà") if nf else "Dòng họ, bà con", 0, false],   # (bản 500) bỏ Hụi làng: 3 nhóm, mỗi nhóm 4 thẻ
			["kh", "Khách thăm", "Thăm làng bạn bè", 0, false],
			["hr", "Làm thuê", "Thuê phụ việc", 0, false],
			["st", "Chuyện làng", W.clg_bk_sub(), W.clg_red(), false]]],
		["Việc làng", "g_vl", [["ut", "Uy tín làng", W._sv(ut.p) + " điểm", W.ut_red(), false],
			["tn", "Thiên tai", tn_sub, maxi(int(W.tn_red()), nn), not W.tn_ok()],
			["hdn", "Hội đình", hshort if hlk else hs, W.WH.hdn_red() if W.WH != null else 0, hlk],
			["rk", "Xếp hạng", "Bảng tuần này", 0, false]]],
		["Vui chơi, hướng dẫn", "g_vc", [["kl", "Kỷ lục", (str(nk) + " loại trái khủng") if nk else "Trái khủng, hội thi", 0, false],
			["cp", "Sạp quê", ("Đang bày " + str(cp) + " món") if cp else "Mua bán với bạn bè", 0, false],
			["dl", "Du lịch", G.w_all.WDL.bk_sub(), 0, false],
			["gd", "Sổ tay", "Cách chơi, mẹo hay", 0, false]]]]
	for g in R:   # (11-28) thẻ chức năng chưa tới cấp: khóa + "Từ cấp N" (trước bấm chỉ hiện toast, thẻ không báo gì)
		for r in g[2]:
			var a: int = W._qf(String(FEAT.get(r[0], "")))
			if a > 0:
				r[2] = "Từ cấp " + str(a)
				r[3] = 0
				r[4] = true
	return R

const FEAT := {"kh": "khach", "hr": "thue", "rk": "xephang", "dl": "dulich"}   # thẻ -> khóa chức năng mở theo cấp (chuc_nang_mo_cap.json)

func _cols() -> Array:   # c(): [khóa, tên, danh sách, là công trình, hình chip]
	return [["ns", "Nông sản", WCA.book_ns(), false, "lua"], ["tc", "Trái cây", WCA.book_tc(), false, "qua_xoai"],
		["mon", "Món", WCA.book_mon(), false, "banh"], ["ca", "Thủy sản", WCA.book_ts(), false, "ca_ro"], ["ct", "Công trình", WCA.book_ct(), true, "svg:res://ui/svg/mat/gach.svg"]]

# ------------------------------------------------------------------ dựng
func _build() -> void:
	sig = _sig()
	_vb = int(scroll / VB)
	var rt := 0
	for t in WCA.bs_list():
		if WCA.tb(t):
			rt += 1
	var L := [["lang", "Làng", false], ["dh", "Danh hiệu", rt > 0], ["bst", "Bộ sưu tập", false]]
	var out: Array
	match tab:
		"dh":
			out = _dh()
		"bst":
			out = _bst()
		_:
			out = _lang()
	var sh := _kshell(L, tab, _tab_go, TOP)
	_find(sh[0], "khcard").kids.append_array(_top(float(sh[3])))
	_kmount(sh[0], sh[1], float(sh[2]), out[0], float(out[1]))
	_wire_extra(box)

func _tab_go(k: String) -> void:   # data-bkt
	if tab != k:
		tab = k
		scroll = 0.0

func _top(y: float) -> Array:   # dải đầu: huy chương, danh hiệu đang mang, "Đã đạt N/8 danh hiệu" + thanh; chạm: tab Danh hiệu
	var M: Dictionary = WCA.tc()
	var Bs: Array = WCA.bs_list()
	var N := 0
	for t in Bs:
		if W._tr(M.tt.get(t.id)):
			N += 1
	var R = WCA.ab()
	var c := _chip(X0, y, XW, TOP - 6.0, "now")
	c.act = _tab_go.bind("dh")
	var ks := [_icx(X0 + 20.0, y + 20.0, 28.0, "svg:res://ui/svg/mat/huychuong.svg")]   # chữ, hình là con của chip (nằm trên nền chip)
	var nm: String = String(R.n) if R != null else "Chưa có danh hiệu"
	ks.append(_dt(X0 + 40.0, y + 4.0, 170.0, 17.0, _fitw(nm, 12.0, 800, 170.0), 12.0, 800, "rgb(196, 110, 20)", "left"))
	var st := "Đã đạt " + str(N) + "/" + str(Bs.size()) + " danh hiệu ›"
	ks.append(_dt(X0 + XW - 128.0, y + 5.0, 120.0, 15.0, st, 10.5, 700, SUB, "right"))
	ks.append_array(_bar(X0 + 40.0, y + 26.0, XW - 52.0, float(N) / maxf(1.0, Bs.size()), 6.0))
	c.kids = ks
	var out := [c]
	return out

# ------------------------------------------------------------------ tab Làng: lưới 2 cột như Sổ tay
func _lang() -> Array:
	var out := []
	var y := 6.0
	var g := 6.0
	var bw := (XW - g) * 0.5
	var bh := 44.0
	for G0 in _links():
		out.append_array(_sect(y, String(G0[0]), String(_ck(G0[1])[3])))
		y += 16.0 + 8.0
		var R: Array = G0[2]
		var i := 0
		while i < R.size():
			for c in 2:
				if i + c >= R.size():
					break
				var r: Array = R[i + c]
				var full: bool = R.size() == 1   # nhóm 1 thẻ: dài hết ngang
				var w := XW if full else bw
				var x := X0 + c * (bw + g)
				var lk: bool = r[4]
				var ch := _chip(x, y, w, bh, "miss" if lk else String(G0[1]))
				var ks := [_ic2(x + 22.0, y + bh * 0.5, 28.0, String(LIC.get(r[0], "xu")))]
				var tw := w - 48.0
				ks.append(_dt(x + 42.0, y + 6.0, tw, 16.0, _fitw(String(r[1]), 12.0, 800, tw), 12.0, 800, "rgb(110, 104, 92)" if lk else BROWN, "left"))
				var red: bool = int(r[3]) > 0
				var sc := "rgb(190, 50, 60)" if red else SUB
				ks.append(_dt(x + 42.0, y + 23.0, tw, 14.0, _fitw(String(r[2]), 10.5, 700 if red else 600, tw), 10.5, 700 if red else 600, sc, "left"))
				if red:
					ks.append(_dbx(x + w - 13.0, y + 5.0, 8.0, 8.0, "rgb(226, 70, 60)", 4.0))
				if lk:   # chưa mở: hình mờ + ổ khóa
					ks[0].css["opacity"] = "0.45"
					ks.append(_dic(x + w - 20.0, y + 6.0, 13.0, LOCK))
				ch.kids = ks
				ch.act = _go.bind(String(r[0]))
				out.append(ch)
			y += bh + g
			i += 2
		y += GG - g + 2.0
	return [out, y]

func _go(k: String) -> void:   # data-gp / data-kh / data-hr / data-ut / ...
	match k:
		"ut":
			U.ut_open()
		"hr":
			U.hr_open()
		"gp":
			U.gp_open()
		"tn":
			U.tn_open()
		"kl":
			U.kl_open()
		"gd":
			U.gd_open()
		"rk":
			U.rk_open()
		"hdn":
			U.hdn_open()
		"dl":
			U.dl_open()
		"st":
			U.clg_open()
		_:
			U.say("Phần này đang chuyển qua bản Godot.")

# ------------------------------------------------------------------ tab Danh hiệu
func _dh() -> Array:
	var M: Dictionary = WCA.tc()
	var dt := []
	for t in WCA.bs_list():
		var c := mini(int(t.max), WCA.bs_cur(t.id))
		var got: bool = W._tr(M.tt.get(t.id))
		dt.append({"t": t, "c": c, "got": got, "rd": not got and c >= int(t.max)})
	dt.sort_custom(func(D, E):
		if D.rd != E.rd:
			return D.rd
		if D.got != E.got:
			return E.got
		return float(D.c) / float(D.t.max) > float(E.c) / float(E.t.max))
	var out := []
	var y := 6.0
	var ng := 0
	for D in dt:
		var ra: Dictionary = D.t
		if D.got:
			ng += 1
			continue
		var h := 52.0
		var c := _chip(X0, y, XW, h, "got" if D.rd else "fut")
		out.append(c)
		out.append(_ic2(X0 + 22.0, y + 22.0, 28.0, String(BIC.get(ra.id, "xu"))))
		var x := X0 + 42.0
		var rx := X0 + XW - 8.0
		# phải: nút Nhận (đủ) hoặc chip xu
		if D.rd:
			var bw: float = Box.text_w("Nhận " + W._sa(ra.xu), 10.5, 800) + 40.0
			var b := _btn(rx - bw, y + 4.0, bw, 22.0, "Nhận " + W._sa(ra.xu), WCA.cv.bind(String(ra.id)), "go")
			out.append(b)
			rx -= bw + 6.0
		else:
			var xs: String = W._sa(ra.xu)
			var xw: float = Box.text_w(xs, 10.5, 800) + 30.0
			var xc := _chip(rx - xw, y + 4.0, xw, 20.0, "now")
			xc.kids = [_icx(rx - xw + 12.0, y + 14.0, 15.0, "xu"), _dt(rx - xw + 22.0, y + 4.0, xw - 24.0, 20.0, xs, 10.5, 800, "rgb(150, 90, 10)", "left")]
			out.append(xc)
			rx -= xw + 6.0
		out.append(_dt(x, y + 6.0, rx - x, 16.0, _fitw(String(ra.n), 12.0, 800, rx - x), 12.0, 800, BROWN, "left"))
		var ns := str(D.c) + "/" + str(ra.max)
		var nw: float = Box.text_w(ns, 10.5, 800) + 2.0
		out.append(_dt(x, y + 23.0, X0 + XW - 10.0 - nw - x, 14.0, _fitw(String(ra.d), 10.5, 600, X0 + XW - 14.0 - nw - x), 10.5, 600, SUB, "left"))
		out.append(_dt(X0 + XW - 8.0 - nw, y + 24.0, nw, 14.0, ns, 10.5, 800, "rgb(40, 110, 50)" if D.rd else BROWN, "left"))
		out.append_array(_bar(x, y + 39.0, X0 + XW - 8.0 - x, float(D.c) / maxf(1.0, float(ra.max)), 6.0))
		y += h + 5.0
	if ng:   # đã nhận: gom cuối, mỗi danh hiệu 1 dòng mờ có ✓
		y += 4.0
		out.append_array(_sect(y, "Đã đạt (" + str(ng) + ")", "rgb(76, 150, 48)"))
		y += 16.0 + 8.0
		for D in dt:
			if not D.got:
				continue
			var c2 := _chip(X0, y, XW, 28.0, "fut")
			c2.kids = [_dtick(X0 + 10.0, y + 8.0, 12.0), _dt(X0 + 28.0, y, XW - 120.0, 28.0, String(D.t.n), 10.5, 700, SUB, "left"),
				_dt(X0 + XW - 98.0, y, 90.0, 28.0, "Đã nhận " + W._sa(D.t.xu), 10.5, 600, SUB, "right")]
			out.append(c2)
			y += 28.0 + 4.0
	return [out, y + GG]

# ------------------------------------------------------------------ tab Bộ sưu tập
func _bst() -> Array:
	var M: Dictionary = WCA.tc()
	var W5 := _cols()
	var K: Array = W5[0]
	for D in W5:
		if D[0] == bs:
			K = D
	var out := []
	var y := 6.0
	# (bản 499) chip loại: 5 chip đều nhau một hàng, thẳng cột với lưới bên dưới (hình / tên / số đã có)
	var cw0 := (XW - 4.0 * 5.0) / 5.0
	var hh := 56.0
	var cnt := {}
	for i in W5.size():
		var D: Array = W5[i]
		var ra := 0
		for e in D[2]:
			if W._tr(M.obj.get(e) if D[3] else M.seen.get(e)):
				ra += 1
		cnt[D[0]] = ra
		var a: bool = D == K
		var x := X0 + i * (cw0 + 5.0)
		var c := _chip(x, y, cw0, hh, "b_" + String(D[0]) if a else "fut")
		c.kids = [_ic2(x + cw0 * 0.5, y + 14.0, 20.0, String(D[4])),
			_dt(x, y + 26.0, cw0, 14.0, _fitw(String(D[1]), 10.5, 800, cw0 - 4.0), 10.5, 800 if a else 700, BROWN),
			_dt(x, y + 39.0, cw0, 13.0, str(ra) + "/" + str(D[2].size()), 10.5, 800, "rgb(40, 110, 50)" if a else SUB)]
		c.act = _bs_go.bind(String(D[0]))
		out.append(c)
	y += hh + GG
	# thanh tiến độ loại đang xem
	var n0: int = cnt[K[0]]
	var tot: int = K[2].size()
	out.append(_dt(X0 + 2.0, y, XW, 15.0, "Đã có " + str(n0) + "/" + str(tot) + " " + String(K[1]).to_lower(), 10.5, 700, BROWN, "left"))
	out.append_array(_bar(X0 + 2.0, y + 18.0, XW - 4.0, float(n0) / maxf(1.0, tot), 6.0))
	y += 30.0 + 4.0
	# lưới 5 cột; Món: chia nhóm theo xưởng
	var groups := []
	if K[0] == "mon":
		var by := {}
		var order := []
		for id in K[2]:
			var f := String(G.item(id).get("from", ""))
			var gn: String = String(G.xw.T[f].name) if G.xw != null and G.xw.T.has(f) else "Khác"
			if not by.has(gn):
				by[gn] = []
				order.append(gn)
			by[gn].append(id)
		order.erase("Khác")   # nhóm Khác (đồ nghề, đồ quê) xuống cuối
		if by.has("Khác"):
			order.append("Khác")
		for gn in order:
			groups.append([gn, by[gn]])
	else:
		groups.append(["", K[2]])
	var cw := (XW - 4.0 * 5.0) / 5.0
	var ch := 66.0   # (11-28) tên 2 dòng cỡ 10.5
	var lo := scroll - 300.0   # chỉ dựng ô trong khoảng màn hình ± 300 (còn lại chỉ giữ chỗ)
	var hi := scroll + _hb + 300.0
	for gr in groups:
		if String(gr[0]) != "":
			var ng := 0
			for id in gr[1]:
				if W._tr(M.seen.get(id)):
					ng += 1
			out.append_array(_sect(y, String(gr[0]) + " · " + str(ng) + "/" + str(gr[1].size()), String(_ck("b_mon")[3])))
			y += 16.0 + 6.0
		var L: Array = gr[1]
		for i in L.size():
			var cx := X0 + (i % 5) * (cw + 5.0)
			if i > 0 and i % 5 == 0:
				y += ch + 5.0
			if y + ch >= lo and y <= hi:
				out.append_array(_kb(cx, y, cw, ch, String(L[i]), K[3], M, "b_" + String(K[0])))
		y += ch + GG
	return [out, y]

func _bs_go(k: String) -> void:   # data-bks
	if bs != k:
		bs = k
		scroll = 0.0

func _kb(x: float, y: float, w: float, h: float, id: String, ct: bool, M: Dictionary, kd: String) -> Array:   # ô bộ sưu tập: hình + tên; chưa có: mờ + "?"
	var seen: bool = W._tr(M.obj.get(id) if ct else M.seen.get(id))
	var c := _chip(x, y, w, h, kd if seen else "miss")
	var out := [c]
	var ic: Dictionary
	if ct and FileAccess.file_exists("res://ui/img/ct/" + id + ".webp"):   # (bản 498) công trình: ảnh nướng sẵn 128px (src/tools/bake_ct.py)
		ic = _icx(x + w * 0.5, y + 21.0, 32.0, "pic:res://ui/img/ct/" + id + ".webp")
	elif ct:   # chưa có ảnh nướng: dựng như bảng Xây dựng (U.bdp._icon)
		ic = _dbx(x + w * 0.5 - 15.0, y + 6.0, 30.0, 30.0, "rgba(0, 0, 0, 0)", 0.0)
		ic.th = id
	else:   # (11-25) hình dài ngang (cá, lươn): khung giãn theo phần có hình cho vừa bề ngang ô, không còn nhỏ xíu cạnh ốc / cua
		var bb := _vis_bb(id)   # [x0, y0, x1, y1] phần có hình, theo 1 cạnh ảnh
		var vw: float = bb[2] - bb[0]
		var vh: float = maxf(0.05, bb[3] - bb[1])
		var s2 := 36.0   # (11-25) món, trái cây, nông sản to ra (trước 30)
		if vw / vh > 1.3:
			s2 = clampf(minf((w - 8.0) / maxf(0.05, vw), 32.0 / vh), 36.0, 56.0)
		ic = _icx(x + w * 0.5, y + 21.0 - ((bb[1] + bb[3]) * 0.5 - 0.5) * s2, s2, id)
	if not seen:
		ic.sil = true
	out.append(ic)
	var nm: String = (String(G.lang.Pi[id].n) if ct and G.lang != null and G.lang.Pi.has(id) else G.item_name(id))
	if seen:
		var L := _wrap(nm, 10.5, 700, w - 4.0)
		for i in mini(2, L.size()):
			out.append(_dt(x + 2.0, y + 38.0 + i * 13.0, w - 4.0, 13.0, String(L[i]) if i == 0 or L.size() <= 2 else _fitw(String(L[i]), 10.5, 700, w - 4.0), 10.5, 700, BROWN))
		c.act = _dsay.bind(nm + ("" if ct else " · giá " + G.fmt_n(int(G.item(id).get("sell", 0))) + " xu · " + G.where(id)))
	else:
		out.append(_dt(x, y + 40.0, w, 16.0, "?", 12.0, 800, "rgb(120, 114, 102)"))
		c.act = _dsay.bind("Chưa có. " + ("Xây hoặc đặt ở Xây dựng." if ct else G.where(id) + "."))
	return out

static var _vis_c := {}
func _vis_bb(id: String) -> Array:   # phần có hình (alpha) của ảnh món Kho ui/img/kh/<id>_64.webp, theo 1 cạnh ảnh; không có ảnh: cả khung
	if _vis_c.has(id):
		return _vis_c[id]
	var r := [0.0, 0.0, 1.0, 1.0]
	var raw := FileAccess.get_file_as_bytes("res://ui/img/kh/" + id + "_64.webp")
	var im := Image.new()
	if raw.size() and im.load_webp_from_buffer(raw) == OK:
		var u := im.get_used_rect()
		var n := float(maxi(1, im.get_width()))
		if u.size.x > 0 and u.size.y > 0:
			r = [u.position.x / n, u.position.y / n, u.end.x / n, u.end.y / n]
	_vis_c[id] = r
	return r

# hình công trình (canvas) và bóng đen mờ của món chưa gặp
func _wire_extra(b: Control) -> void:
	var n: Dictionary = b.get_meta("snap", {})
	if n.has("th") and U.bdp != null and not b.has_meta("thd"):   # hình công trình: vẽ một lần mỗi nút (nút dùng lại thì thôi)
		U.bdp._icon(b, ["id", String(n.th)], false)
		b.set_meta("thd", true)
	if n.get("sil", false):
		b.modulate = Color(0, 0, 0, 0.18)
	for k in b.kids():
		_wire_extra(k)
