extends "res://logic/ui_kbang.gd"
# SỔ TAY HƯỚNG DẪN (ZC bản web, Sổ làng › Sổ tay). (bản 484) làm lại trên khung Kho + chip chung (ui_kbang.gd):
# hàng tab nhóm, ô tìm có kính lúp, mỗi nhóm tiêu đề vạch màu + lưới 2 cột nền nhạt theo nhóm (hình riêng, tên, dòng phụ,
# chấm đỏ góc phải khi chưa mở lần nào); chạm mục mở khối hướng dẫn ngay dưới hàng đó. Đọc rồi ghi g.tut.rd[mã]. Cuối: Chuyện làng, Tắt / Bật nhắc.
# Nội dung: data/huong_dan/so_tay.json. Mục "Cấp nào mở gì": cây trồng / cây ăn trái tính lại từ data (_capdo).

var Y6 := []                # [{sec, items: [{id, ic, n, b: [dòng]}]}]
var op := ""                # mục đang mở
var q := ""                 # chữ tìm
var tab := "Chung"
const TABS := [["Chung", "Chung"], ["Ruộng vườn", "Ruộng vườn"], ["Sông nước", "Sông nước"], ["Làm ăn", "Làm ăn"], ["Làng xóm", "Làng xóm"]]   # (bản 485) mỗi tab một nhóm trong so_tay.json
const SECC := {"Chung": "rgb(200, 150, 40)", "Ruộng vườn": "rgb(76, 150, 48)", "Sông nước": "rgb(60, 130, 180)", "Làm ăn": "rgb(222, 130, 40)", "Làng xóm": "rgb(200, 80, 90)"}
const ICO := {"nhanvat": "svg:res://ui/svg/mat/suckhoe.svg", "thoitiet": "sky:nang", "giong": "sky:giong", "nuoc": "sky:mua", "thu": "svg:res://ui/svg/mat/thu.svg", "dieu": "svg:res://ui/svg/mat/dieu.svg", "menuo": "pic:res://ui/img/xt/b_cuoc.webp", "lai": "lua_thom", "hoithi": "svg:res://ui/svg/mat/huychuong.svg", "ray": "svg:res://ui/svg/mat/ray.svg",
	"quan": "pic:res://ui/img/xt/g_quan1.webp", "ghe": "pic:res://ui/img/xt/g_ghe1.webp", "khaihoang": "pic:res://ui/img/xt/b_cuoc.webp", "yte": "svg:res://ui/svg/mat/yte.svg",
	"xay": "svg:res://ui/svg/mat/gach.svg", "xephang": "svg:res://ui/svg/mat/huychuong.svg", "lang": "pic:res://ui/img/vlface/0.webp", "thue": "pic:res://ui/img/vlface/3.webp",
	"dulich": "svg:res://ui/svg/mat/khach_tay.svg", "dulich2": "svg:res://ui/svg/mat/khach_sg.svg", "hoi": "svg:res://ui/svg/mat/dinh_lang.svg", "cuoi": "banh_pt", "capdo": "svg:res://ui/svg/mat/huychuong.svg"}   # hình riêng từng mục (còn lại: hình món trong data)
var SK := {}
const GCK := {   # (bản 489) nền chip theo nhóm (nhạt như Chuyện làng): [gradient trên, giữa, dưới, viền]
	"g_Chung": ["rgb(247, 236, 210)", "rgb(249, 242, 224)", "rgb(252, 247, 237)", "rgb(232, 203, 131)"],
	"g_Ruộng vườn": ["rgb(219, 234, 214)", "rgb(230, 240, 226)", "rgb(241, 247, 238)", "rgb(157, 197, 141)"],
	"g_Sông nước": ["rgb(218, 228, 240)", "rgb(229, 236, 244)", "rgb(240, 244, 249)", "rgb(153, 181, 214)"],
	"g_Làm ăn": ["rgb(248, 230, 212)", "rgb(250, 238, 225)", "rgb(252, 245, 238)", "rgb(237, 186, 137)"],
	"g_Làng xóm": ["rgb(246, 222, 224)", "rgb(249, 233, 234)", "rgb(252, 243, 243)", "rgb(226, 160, 166)"],
}

func _ck(kind: String) -> Array:
	return GCK[kind] if GCK.has(kind) else super(kind)

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
	tab = "Chung"
	scroll = 0.0
	if t != "":
		op = t
		kh(G).rd[t] = 1
		for sec in Y6:   # mở thẳng mục t: nhảy tới tab của nó
			for it in sec.items:
				if String(it.id) == t:
					tab = String(sec.sec)
	sig = ""
	_build()

func step(_dt: float) -> void:
	if on:
		_qe_place()

func _build() -> void:
	var L := TABS.map(func(x): return [x[0], x[1], false])   # (bản 490) tab không chấm đỏ: chấm nằm trên từng mục
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
	q = _low(t)
	_redo()

var _ftx := {}   # mã mục -> chữ đã bỏ dấu (tìm nhanh)
func _fold(it: Dictionary) -> String:
	var k := String(it.id)
	if not _ftx.has(k):
		_ftx[k] = _low(String(it.n) + " " + String(it.get("s", "")) + " " + " ".join(PackedStringArray(it.b)))
	return _ftx[k]

func _ico(it: Dictionary) -> String:
	return String(ICO.get(String(it.id), String(it.ic)))

func _icg(cx: float, cy: float, z: float, k: String) -> Dictionary:   # hình mục: "sky:<loại>" hình bảng Trời đất, còn lại _icx
	if k.begins_with("sky:"):
		return _dic(cx - z * 0.5, cy - z * 0.5, z, String(SK.ic.get(k.substr(4), SK.ic.nang)))
	return _icx(cx, cy, z, k)

func _body() -> Array:
	var rd: Dictionary = kh(G).rd
	var out := []
	var y := 6.0
	# ô tìm: nền trắng, kính lúp
	var sb := _qbox(y, "u2gds")
	out.append(sb)
	y += 30.0 + GG
	var nf := 0
	for sec in Y6:
		if tab != String(sec.sec) and q == "":   # đang tìm: tìm trong mọi nhóm
			continue
		var its := []
		for it in sec.items:
			if q != "" and _fold(it).find(q) < 0:
				continue
			its.append(it)
		if its.is_empty():
			continue
		nf += its.size()
		var nw := its.filter(func(it): return not rd.has(it.id)).size()
		if q != "":   # đang tìm: tiêu đề nhóm (mục từ nhiều nhóm)
			out.append_array(_sect(y, String(sec.sec), String(SECC.get(String(sec.sec), "rgb(150, 112, 60)"))))
			y += 16.0 + GG
		else:   # (bản 486) tab đã ghi tên nhóm: chỉ 1 dòng nhỏ đếm mục
			out.append(_dt(X0 + 2.0, y - 2.0, XW, 14.0, str(its.size()) + " mục" + ((" · " + str(nw) + " chưa đọc") if nw else " · đã đọc hết"), 10.0, 600, SUB, "left"))
			y += 14.0 + 6.0
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
				var on: bool = op == String(it.id)
				var ch := _chip(x, y, bw, bh, "now" if on else "g_" + String(sec.sec))
				var ks := [_icg(x + 20.0, y + bh * 0.5, 26.0, _ico(it))]
				var tw := bw - 44.0 - (14.0 if on else 0.0)   # (bản 486) tên một cỡ 11, dài thì cắt
				ks.append(_dt(x + 40.0, y + 6.0, tw, 15.0, _fitw(String(it.n), 11.0, 800, tw), 11.0, 800, BROWN, "left"))
				var s0: String = String(it.get("s", it.b[0] if it.b.size() else ""))
				ks.append(_dt(x + 40.0, y + 23.0, bw - 46.0, 14.0, _fitw(s0, 9.5, 600, bw - 46.0), 9.5, 600, SUB, "left"))
				if not rd.has(it.id):   # chưa đọc: chấm đỏ góc trên phải chip
					ks.append(_dbx(x + bw - 13.0, y + 5.0, 8.0, 8.0, "rgb(226, 70, 60)", 4.0))
				if on:
					ks.append(_dic(x + bw - 16.0, y + 8.0, 10.0, CHU))
				ch.kids = ks
				ch.act = _tog.bind(String(it.id))
				out.append(ch)
			y += bh + g
			# mục đang mở trong hàng này: khối hướng dẫn ngay dưới
			for c in 2:
				if i + c >= its.size():
					break
				var it2: Dictionary = its[i + c]
				if op == String(it2.id):
					var r := _det(y, it2, String(SECC.get(String(sec.sec), "rgb(150, 112, 60)")), "g_" + String(sec.sec))
					out.append_array(r[0])
					y += float(r[1]) + g
			i += 2
		y += GG - g
	if q != "" and nf == 0:   # (bản 489) tìm không ra
		out.append(_dt(X0 + 2.0, y, XW, 16.0, "Không thấy mục nào có chữ này.", 11.0, 700, SUB, "left"))
		y += 16.0 + GG
	# cuối: nhắc lần đầu (đường kẻ ngăn với lưới); (11-28) bỏ nút Chuyện làng (lạc chỗ: đã có ở Sổ làng)
	y += 4.0
	out.append(_dbx(X0 + 20.0, y, XW - 40.0, 1.0, "rgb(222, 204, 164)", 0.0))
	y += 1.0 + GG + 2.0
	out.append(_btn(X0, y, XW, 30.0, "Bật lại nhắc lần đầu" if W_off() else "Tắt nhắc lần đầu", _tip, "go" if W_off() else "plain"))   # (11-28) tắt: nút kem thường (đỏ là huỷ / cảnh báo), bật lại: xanh
	y += 30.0 + GG
	return [out, y]

func _det(y: float, it: Dictionary, col: String, kd := "fut") -> Array:   # khối hướng dẫn: vạch màu nhóm, từng dòng có chấm, số liệu tô đậm (bản 488)
	var out := []
	var ps := []
	var h := 10.0
	for s0 in it.b:
		var P := _parab(X0 + 26.0, 0.0, XW - 34.0, String(s0), 10.5, 600, BROWN, 14.5)
		ps.append(P)
		h += float(P[1]) + 4.0
	h += 6.0
	var c := _chip(X0, y, XW, h, kd)
	out.append(c)
	out.append(_dbx(X0 + 4.0, y + 6.0, 3.0, h - 12.0, col, 1.5))
	var yy := y + 10.0
	for P in ps:
		out.append(_dbx(X0 + 16.0, yy + 5.5, 4.0, 4.0, col, 2.0))
		for n in P[0]:
			n.r[1] = float(n.r[1]) + yy
			out.append(n)
		yy += float(P[1]) + 4.0
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

