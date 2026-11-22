extends "res://logic/ui_kbang.gd"
# SỔ TAY HƯỚNG DẪN (ZC bản web, Sổ làng › Sổ tay). (bản 484) làm lại trên khung Kho + chip chung (ui_kbang.gd):
# hàng tab nhóm (chấm đỏ khi nhóm có mục chưa đọc), ô tìm có kính lúp, mỗi nhóm tiêu đề vạch màu + lưới 2 cột (hình riêng, tên, dòng phụ,
# chip "Mới" khi chưa mở lần nào); chạm mục mở khối hướng dẫn ngay dưới hàng đó. Đọc rồi ghi g.tut.rd[mã]. Cuối: Chuyện làng, Tắt / Bật nhắc.
# Nội dung: data/huong_dan/so_tay.json. Mục "Cấp nào mở gì": cây trồng / cây ăn trái tính lại từ data (_capdo).

var Y6 := []                # [{sec, items: [{id, ic, n, b: [dòng]}]}]
var op := ""                # mục đang mở
var q := ""                 # chữ tìm
var tab := "all"
const TABS := [["all", "Tất cả"], ["ruong", "Ruộng vườn"], ["lam", "Làm ăn"], ["lang", "Làng xóm"], ["khac", "Khác"]]
const SECT := {"Ruộng vườn": "ruong", "Làm ăn": "lam", "Làng xóm": "lang"}   # nhóm khác vào tab "Khác"
const SECC := {"Lộ trình 100 cấp": "rgb(200, 150, 40)", "Ruộng vườn": "rgb(76, 150, 48)", "Làm ăn": "rgb(222, 130, 40)", "Nhân vật": "rgb(200, 80, 90)",
	"Trời đất": "rgb(70, 120, 180)", "Sông nước, hội hè": "rgb(60, 140, 160)", "Làng xóm": "rgb(214, 160, 30)", "Mở mang đất đai": "rgb(150, 112, 60)", "Du hành": "rgb(130, 90, 185)"}
const ICO := {"menuo": "pic:res://ui/img/xt/b_cuoc.webp", "lai": "lua_thom", "hoithi": "svg:res://ui/svg/mat/huychuong.svg", "ray": "svg:res://ui/svg/mat/ray.svg",
	"quan": "pic:res://ui/img/xt/g_quan1.webp", "ghe": "pic:res://ui/img/xt/g_ghe1.webp", "khaihoang": "pic:res://ui/img/xt/b_cuoc.webp", "yte": "svg:res://ui/svg/mat/yte.svg",
	"xay": "svg:res://ui/svg/mat/gach.svg", "xephang": "svg:res://ui/svg/mat/huychuong.svg", "lang": "pic:res://ui/img/vlface/0.webp", "thue": "pic:res://ui/img/vlface/3.webp",
	"dulich": "svg:res://ui/svg/mat/khach_tay.svg", "dulich2": "svg:res://ui/svg/mat/khach_sg.svg", "hoi": "svg:res://ui/svg/mat/dinh_lang.svg", "cuoi": "banh_pt", "capdo": "svg:res://ui/svg/mat/huychuong.svg"}   # hình riêng từng mục (còn lại: hình món trong data)
var SK := {}

func _init(ui) -> void:
	super(ui)
	var y = G._j("huong_dan/so_tay")
	Y6 = y if y is Array else []
	SK = Snap.load_snap("sky")
	_capdo()

func _capdo() -> void:   # dòng "Cấp N: ..." : bỏ chữ "Cây ..." cũ, ghi lại cây mở ở cấp đó theo data
	var lai: Dictionary = G._j("nong_trai/giong_lai")
	var ei: Dictionary = G._j("nong_trai/cay_an_trai")
	var ct: Dictionary = G._j("xay_dung/cong_trinh")
	var by := {}      # cấp -> ["Cây lúa", ...]
	var all := {}     # mọi chữ "Cây ..." có thể có
	for k in G.D.crops:
		var t := "Cây " + String(G.D.crops[k].name).to_lower()
		all[t] = true
		if not lai.has(k):
			by.get_or_add(int(G.D.crops[k].lv), []).append(t)
	for f in ei:
		var t := "Cây " + String(ct.get(f, {}).get("n", G.item_name(String(ei[f].p)))).to_lower()
		all[t] = true
		by.get_or_add(int(ei[f].lv), []).append(t)
	for sec in Y6:
		for it in sec.items:
			if it.id != "capdo":
				continue
			var out := []
			var seen := {}
			for line in it.b:
				var m := String(line)
				if not m.begins_with("Cấp ") or m.find(": ") < 0:
					out.append(m)
					continue
				var n := int(m.substr(4, m.find(":") - 4))
				var rest := m.substr(m.find(": ") + 2).trim_suffix(".")
				var keep := []
				for tok in rest.split(", "):
					if not all.has(tok):
						keep.append(tok)
				var toks: Array = by.get(n, []) + keep
				seen[n] = true
				if not toks.is_empty():
					out.append("Cấp " + str(n) + ": " + ", ".join(toks) + ".")
			for n in by:   # cấp có cây mới mà sổ chưa có dòng
				if not seen.has(n):
					out.append("Cấp " + str(n) + ": " + ", ".join(by[n]) + ".")
			var head := out.filter(func(l): return not String(l).begins_with("Cấp "))
			var lv := out.filter(func(l): return String(l).begins_with("Cấp "))
			lv.sort_custom(func(a, b): return int(String(a).substr(4, String(a).find(":") - 4)) < int(String(b).substr(4, String(b).find(":") - 4)))
			it.b = head + lv

static func kh(G) -> Dictionary:   # Kh: g.tut
	var t = G.g.get("tut")
	if not (t is Dictionary):
		t = {}
		G.g.tut = t
	if not (t.get("h") is Dictionary):
		t.h = {}
	if not (t.get("rd") is Dictionary):
		t.rd = {}
	return t

func open(t := "") -> void:   # ZC(t)
	on = true
	op = ""
	q = ""
	tab = "all"
	scroll = 0.0
	if t != "":
		op = t
		kh(G).rd[t] = 1
	sig = ""
	_build()

func step(_dt: float) -> void:
	if on:
		_qe_place()

func _build() -> void:
	var rd: Dictionary = kh(G).rd
	var red := {}
	for sec in Y6:
		for it in sec.items:
			if not rd.has(it.id):
				red[String(SECT.get(String(sec.sec), "khac"))] = true
				red["all"] = true
	var L := TABS.map(func(x): return [x[0], x[1], red.has(x[0])])
	var sh := _kshell(L, tab, _tab_go)
	var r := _body()
	_kmount(sh[0], sh[1], float(sh[2]), r[0], float(r[1]))
	_qe_make(".u2gds", "Tìm trong sổ tay…", q, _q_changed)

func _tab_go(k: String) -> void:
	if tab != k:
		tab = k
		scroll = 0.0
		op = ""

func _q_changed(t: String) -> void:   # ô tìm: lọc mục có chữ
	q = t.strip_edges().to_lower()
	_redo()

func _ico(it: Dictionary) -> String:
	return String(ICO.get(String(it.id), String(it.ic)))

func _body() -> Array:
	var rd: Dictionary = kh(G).rd
	var out := []
	var y := 6.0
	# ô tìm: nền trắng, kính lúp
	var sb := _dbx(X0, y, XW, 30.0, "rgb(255, 255, 255)", 15.0, "", "rgba(150, 112, 48, 0.55) 0px 0px 0px 1px inset")
	sb.cls = "u2gds"
	sb.kids = [_dic(X0 + XW - 26.0, y + 7.0, 16.0, LUP)]
	out.append(sb)
	y += 30.0 + GG
	for sec in Y6:
		var sk := String(SECT.get(String(sec.sec), "khac"))
		if tab != "all" and tab != sk and q == "":
			continue
		var its := []
		for it in sec.items:
			if q != "" and (String(it.n) + " " + " ".join(PackedStringArray(it.b))).to_lower().find(q) < 0:
				continue
			its.append(it)
		if its.is_empty():
			continue
		var nw := its.filter(func(it): return not rd.has(it.id)).size()
		out.append_array(_sect(y, String(sec.sec) + ((" · " + str(nw) + " mới") if nw else ""), String(SECC.get(String(sec.sec), "rgb(150, 112, 60)"))))
		y += 16.0 + GG
		var g := 6.0
		var bw := (XW - g) * 0.5
		var bh := 44.0
		var i := 0
		while i < its.size():
			for c in 2:
				if i + c >= its.size():
					break
				var it: Dictionary = its[i + c]
				var x := X0 + c * (bw + g)
				var on: bool = op == String(it.id) or (q != "" and its.size() == 1)
				var ch := _chip(x, y, bw, bh, "now" if on else "fut")
				var ks := [_icx(x + 20.0, y + bh * 0.5, 26.0, _ico(it))]
				var tw := bw - 44.0 - (26.0 if not rd.has(it.id) else 0.0)
				var nfs := clampf(11.0 * tw / maxf(1.0, Box.text_w(String(it.n), 11.0, 800)), 9.0, 11.0)   # tên dài: bóp chữ trước khi cắt
				ks.append(_dt(x + 40.0, y + 6.0, tw, 15.0, _fitw(String(it.n), nfs, 800, tw), nfs, 800, BROWN, "left"))
				var s0: String = String(it.b[0]) if it.b.size() else ""
				ks.append(_dt(x + 40.0, y + 23.0, bw - 46.0, 14.0, _fitw(s0, 9.5, 600, bw - 46.0), 9.5, 600, SUB, "left"))
				if not rd.has(it.id):
					var mc := _chip(x + bw - 28.0, y + 6.0, 24.0, 13.0, "sen")
					mc.kids = [_dt(x + bw - 28.0, y + 6.0, 24.0, 13.0, "Mới", 8.0, 800, "rgb(190, 50, 60)")]
					ks.append(mc)
				ch.kids = ks
				ch.act = _tog.bind(String(it.id))
				out.append(ch)
			y += bh + g
			# mục đang mở trong hàng này: khối hướng dẫn ngay dưới
			for c in 2:
				if i + c >= its.size():
					break
				var it2: Dictionary = its[i + c]
				if op == String(it2.id) or (q != "" and its.size() == 1):
					var r := _det(y, it2, String(SECC.get(String(sec.sec), "rgb(150, 112, 60)")))
					out.append_array(r[0])
					y += float(r[1]) + g
			i += 2
		y += GG - g
	# cuối: Chuyện làng, nhắc lần đầu
	var bw2 := (XW - 6.0) * 0.5
	out.append(_btn(X0, y, bw2, 30.0, "Chuyện làng ›", _clg, "go"))
	var tc := _chip(X0 + bw2 + 6.0, y, bw2, 30.0, "fut")
	tc.kids = [_dt(X0 + bw2 + 6.0, y, bw2, 30.0, "Bật lại nhắc lần đầu" if W_off() else "Tắt nhắc lần đầu", 10.5, 700, BROWN)]
	tc.act = _tip
	out.append(tc)
	y += 30.0 + GG
	return [out, y]

func _det(y: float, it: Dictionary, col: String) -> Array:   # khối hướng dẫn: vạch màu nhóm, từng dòng có chấm
	var out := []
	var lines := []
	for s0 in it.b:
		lines.append(_wrap(String(s0), 10.5, 600, XW - 34.0))
	var h := 10.0
	for L in lines:
		h += L.size() * 14.5 + 4.0
	h += 6.0
	var c := _chip(X0, y, XW, h, "fut")
	out.append(c)
	out.append(_dbx(X0 + 4.0, y + 6.0, 3.0, h - 12.0, col, 1.5))
	var yy := y + 10.0
	for L in lines:
		out.append(_dbx(X0 + 16.0, yy + 5.5, 4.0, 4.0, col, 2.0))
		for ln in L:
			out.append(_dt(X0 + 26.0, yy, XW - 34.0, 14.5, String(ln), 10.5, 600, BROWN, "left"))
			yy += 14.5
		yy += 4.0
	return [out, h]

func W_off() -> bool:
	return bool(kh(G).get("off", false))

func _tog(id: String) -> void:   # chạm mục: mở (ghi đã đọc) / gập
	if op == id:
		op = ""
	else:
		op = id
		kh(G).rd[id] = 1
		G.mark()

func _tip() -> void:   # data-gd="tip"
	var t := kh(G)
	t.off = not bool(t.get("off", false))
	G.mark()

func _clg() -> void:   # data-gd="st": Chuyện làng
	U.clg_open()

const LUP := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><circle cx=\"10\" cy=\"10\" r=\"6.5\" fill=\"none\" stroke=\"rgb(150,112,60)\" stroke-width=\"2.2\"/><path d=\"M15 15 L21 21\" stroke=\"rgb(150,112,60)\" stroke-width=\"2.6\" stroke-linecap=\"round\"/></svg>"
