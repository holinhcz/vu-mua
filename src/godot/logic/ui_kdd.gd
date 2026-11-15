extends "res://logic/ui_bang.gd"
# KHO › ĐỒ DÙNG bản web (l() + f() trong .u2vw) và chip HUD bùa EXP (AF: .ddchips dưới hàng đầu bên trái).
# Lưới thẻ .u2vg (bùa +50% EXP theo L3, thẻ "đang chạy" khi chỉ còn giờ, phần cơm hồi sức), khung chi tiết .u2vd ở đáy bảng
# (Dùng / Ăn). Chip: "XP +50% h:mm:ss" (bấm mở Kho › Đồ dùng). Mẫu: ui/snap/kdd.json.

var K := {}
var sel := ""
var dsig := ""
var built := []
var csig := ""
var chips: Control = null

const COL_DX := 61.9   # bước cột lưới (gap 6px ở zoom .75 + thẻ 57.4)
const ROW_GAP := 4.5

func _init(ui) -> void:
	super(ui)
	K = Snap.load_snap("kdd")

static func MA(t: float) -> String:
	var a := int(ceil(t / 6e4))
	var n := a / 1440
	var e := (a % 1440) / 60
	var r := a % 60
	return (str(n) + " ngày " + str(e) + "g") if n else ((str(e) + "g " + str(r) + "p") if e else (str(r) + " phút"))

static func PF(t: float) -> String:
	var a := int(ceil(t / 1e3))
	var n := a / 86400
	var e := (a % 86400) / 3600
	var r := (a % 3600) / 60
	var o := a % 60
	if n:
		return str(n) + "n " + str(e) + "g"
	if e:
		return str(e) + ":" + ("%02d" % r) + ":" + ("%02d" % o)
	return str(r) + ":" + ("%02d" % o)

func items() -> Array:   # l()
	var nv = G.nv
	var p: Dictionary = nv.A3()
	var d: float = nv.Fu()
	var v := false
	var h := []
	var ks := []
	for k in nv.L3:
		ks.append(int(k))
	for k in p.keys():
		if not ks.has(int(k)):
			ks.append(int(k))
	for k in ks:
		var c := int(p.get(str(k), 0))
		if c > 0:
			h.append({"k": "b" + str(k), "h": k, "n": nv.xA(k), "c": c, "art": "bua", "run": 0.0 if v else d,
				"d": "+50% kinh nghiệm trong " + (str(k) + " giờ" if k < 24 else str(k / 24) + " ngày") + ". Dùng thêm thì cộng dồn thời gian.", "btn": "Dùng"})
			v = true
	if d > 0.0 and not v:
		h.push_front({"k": "brun", "h": 0, "n": "Bùa +50% EXP", "c": 0, "art": "bua", "run": d, "d": "Đang có hiệu lực: kinh nghiệm nhận được +50%.", "btn": ""})
	if nv.tu() > 0:
		h.append({"k": "com", "h": 0, "n": "Phần cơm hồi sức", "c": nv.tu(), "art": "com", "run": 0.0, "d": "Hồi đầy thể lực cho nhân vật ngay lập tức.", "btn": "Ăn"})
	return h

func _kid(n: Dictionary, cls: String) -> Dictionary:
	return Snap.find(n, cls)

func _clamp2(n: Dictionary, s: String) -> String:   # -webkit-line-clamp: 2 (dòng 2 cụt thì thêm …)
	var w := float(n.r[2])
	var fs := _fs(n)
	var fw := _fw(n)
	var L := []
	var cur := ""
	for word in s.split(" "):
		var t := word if cur == "" else cur + " " + word
		if cur != "" and Box.text_w(t, fs, fw) > w:
			L.append(cur)
			cur = word
		else:
			cur = t
	L.append(cur)
	if L.size() <= 2:
		return s
	var l2: String = L[1] + "…"
	while l2.length() > 1 and Box.text_w(l2, fs, fw) > w:
		l2 = l2.substr(0, l2.length() - 2) + "…"
	return L[0] + " " + l2

func _txt_c(n: Dictionary, s: String) -> void:   # chữ một dòng canh giữa ô
	var w := _tw(n, s)
	n.text = s
	if n.has("tr"):
		n.tr = [float(n.r[0]) + (float(n.r[2]) - w) * 0.5, n.tr[1], w, n.tr[3]]

func _dcard(it: Dictionary, on: bool) -> Dictionary:
	var run := float(it.run) > 0.0
	var li := _cl(K.li0 if run else K.li)
	var b: Dictionary = li.kids[0]
	b.css = _cl(K.sel_css if on else K.li.kids[0].css)
	var bc := _kid(b, "u2vc")
	var src: Dictionary = _kid(K.li0 if on else K.li, "u2vc")
	if not bc.is_empty():
		bc.css = _cl(src.css)
		if int(it.c) > 0:
			_txt_c(bc, str(it.c))
		else:
			b.kids.erase(bc)
	var ic := _kid(b, "u2vi")
	if not ic.is_empty() and ic.get("kids", []).size():
		ic.kids[0].svg = K.ic_com if it.art == "com" else K.ic_bua
	var nn := _kid(b, "u2vn")
	nn.text = _clamp2(nn, String(it.n))
	nn.tr = nn.r.duplicate()   # 2 dòng trong ô (overflow hidden), không canh giữa theo khung chữ 3 dòng
	if run:
		_txt_c(_kid(b, "u2vr"), "⏱ " + MA(float(it.run)))
	return li

func sync(ids: Dictionary) -> void:   # f() với data-v = dd
	var vw: Control = ids.get(".u2vw")
	if vw == null:
		return
	var L := items()
	if not L.any(func(x): return x.k == sel):
		sel = String(L[0].k) if L.size() else ""
	var sg := sel + "|" + str(ceili(G.nv.Fu() / 6e4))
	for x in L:
		sg += "," + String(x.k) + ":" + str(x.c)
	if sg == dsig and built.size() and is_instance_valid(built[0]):
		return
	dsig = sg
	for b in built:
		if is_instance_valid(b):
			b.queue_free()
	built = []
	var em = U._q(vw, "u2vem")
	if em != null:
		em.visible = L.is_empty()
	if L.is_empty():
		return
	var vr: Array = vw.get_meta("snap", {}).get("r", [vw.r.position.x, vw.r.position.y])
	var o := Vector2(float(vr[0]), float(vr[1]))
	var x0 := float(K.li0.r[0])
	var y := float(K.li0.r[1])
	var rows := []
	for i in L.size():
		if i % 4 == 0:
			rows.append([])
		rows[-1].append(L[i])
	var cards := []
	for row in rows:
		var hmax := 0.0
		for j in row.size():
			var it: Dictionary = row[j]
			var li := _dcard(it, it.k == sel)
			_mv(li, x0 + j * COL_DX, y)
			hmax = maxf(hmax, float(li.kids[0].r[3]))
			cards.append([li, it])
		y += hmax + ROW_GAP
	for c in cards:
		var it: Dictionary = c[1]
		var cb: Control = U._build(c[0], {}, o)
		vw.add(cb)
		built.append(cb)
		if int(it.c) <= 0:   # .u2vt.zero
			var ic: Control = U._q(cb, "u2vi")
			if ic != null:
				ic.modulate.a = 0.35
		var bt: Control = U._q(cb, "u2vt")
		var kk: String = it.k
		U._click(bt, func(): sel = kk; dsig = ""; sync(ids), "scale94")
	# khung chi tiết
	var E: Dictionary = L.filter(func(x): return x.k == sel)[0]
	var run := float(E.run) > 0.0
	var d := _cl(K.det if run else K.det0)
	var ic := _kid(d, "u2vi")
	if ic.get("kids", []).size():
		ic.kids[0].svg = K.ic_com if E.art == "com" else K.ic_bua
	var dt := _kid(d, "u2vdt")
	dt.kids[0].text = String(E.n)
	dt.kids[1].text = ("Có ×" + str(E.c)) if int(E.c) > 0 else "Đang dùng"
	var go := _kid(d, "u2vgo")
	if String(E.btn) == "":
		d.kids.erase(go)
	else:
		_txt_c(go, String(E.btn))
	var ds := _kid(d, "u2vds")
	ds.kids[0].text = String(E.d)
	if run and ds.kids.size() > 1:
		ds.kids[1].text = "⏱ Còn " + MA(float(E.run))
	var db: Control = U._build(d, {}, o)
	vw.add(db)
	built.append(db)
	var gb: Control = U._q(db, "u2vgo")
	if gb != null:
		var ek: String = E.k
		var eh: int = int(E.h)
		U._click(gb, func():
			if ek == "com":
				G.nv.j8()
			elif ek.begins_with("b"):
				G.nv.LF(eh)
			G.mark()
			dsig = ""
			csig = ""
			sync(ids)
			chips_sync(), "scale")

func chips_sync() -> void:   # AF: chip HUD "XP +50% h:mm:ss" (bấm mở Kho › Đồ dùng); chip phần cơm bỏ ở bản 172
	var hl = U.hud_roots.get(".hudtl")
	if hl == null or G.nv == null:
		return
	var n: float = G.nv.Fu()
	var off: bool = G.w_all == null or G.w_all.WC._mode() == "off"
	var sg := (PF(n) if n > 0.0 else "") + "|" + str(off)
	if sg == csig and (chips == null or is_instance_valid(chips)):
		return
	csig = sg
	if chips != null and is_instance_valid(chips):
		chips.queue_free()
	chips = null
	if not off or n <= 0.0:
		return
	var d := _cl(K.chips)
	var xp: Dictionary = d.kids[0]
	var k := _kid(xp, "ddk")
	var s := PF(n)
	var dw := _tw(k, s) - _tw(k, String(k.text))
	k.text = s
	k.r[2] = float(k.r[2]) + dw
	if k.has("tr"):
		k.tr[2] = float(k.tr[2]) + dw
	xp.r[2] = float(xp.r[2]) + dw
	d.kids = [xp]
	chips = U._build(d, {}, hl.r.position)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.add(chips)
	U._click(chips.kids()[0], func():
		U.kho_open()
		U._kho_tab(2), "scale")
