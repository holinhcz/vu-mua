extends "res://logic/ui_pop.gd"
# SỔ TAY HƯỚNG DẪN (ZC bản web, Sổ làng › Sổ tay): hộp nổi khung tre (ui_pop.gd): ô tìm, từng nhóm (h3.gdsec), mỗi mục một thẻ
# details.gd (hình món, tên, nhãn "Mới" khi chưa đọc, bấm để mở / gập các dòng hướng dẫn). Đọc rồi ghi g.tut.rd[mã].
# Cuối hộp: Chuyện làng, Tắt / Bật lại nhắc lần đầu (g.tut.off). Mẫu: gd_tab.json; nội dung: ui/snap/sotay.json (Y6 của web lúc chạy).

var GD := {}                # mẫu
var Y6 := []                # [{sec, items: [{id, ic, n, b: [dòng]}]}]
var opn := {}               # mục đang mở
var q := ""                 # chữ tìm

func _init(ui) -> void:
	super(ui)
	GD = Snap.load_snap("gd_tab")
	var y = JSON.parse_string(FileAccess.get_file_as_string("res://ui/snap/sotay.json"))
	Y6 = y if y is Array else []

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
	opn = {}
	q = ""
	scroll = 0.0
	if t != "":
		opn[t] = 1
		kh(G).rd[t] = 1
	sig = ""
	_build()

func step(_dt: float) -> void:
	if on:
		_qe_place()

func _build() -> void:
	_pop(_body())
	_qe_make(".u2gds", "Tìm trong sổ tay…", q, _q_changed)

func _q_changed(t: String) -> void:   # input .u2gds: lọc mục có chữ, mục khớp thì mở
	q = t.strip_edges().to_lower()
	_redo()

func _body() -> Array:
	var rd: Dictionary = kh(G).rd
	var out := []
	var inp := _cl(GD.q)
	inp.gap = 0.0
	out.append(inp)
	for sec in Y6:
		var its := []
		for it in sec.items:
			if q != "" and (String(it.n) + " " + " ".join(PackedStringArray(it.b))).to_lower().find(q) < 0:
				continue
			its.append(it)
		if its.is_empty():
			continue
		var h := _cl(GD.h3)
		h.text = sec.sec
		h.gap = 10.5
		out.append(h)
		var first := true
		for it in its:
			var d := _det(it, opn.has(it.id) or q != "", not rd.has(it.id))
			d.gap = 13.4 if first else 6.0
			first = false
			out.append(d)
	var j := _cl(GD.jobs)
	j.kids[0].act = _clg
	var tb: Dictionary = j.kids[1]
	var tt := "Bật lại nhắc lần đầu" if W_off() else "Tắt nhắc lần đầu"
	var tw := _tw(tb, tt)
	tb.text = tt
	tb.tr = [float(tb.r[0]) + (float(tb.r[2]) - tw) * 0.5, tb.tr[1], tw, tb.tr[3]]
	tb.act = _tip
	j.gap = 7.5
	out.append(j)
	return out

func W_off() -> bool:
	return bool(kh(G).get("off", false))

# details.gd: summary (hình, tên, Mới) [+ ul > li]
func _det(it: Dictionary, is_open: bool, is_new: bool) -> Dictionary:
	var d := _cl(GD.det_open if is_open else GD.det_new)
	var sm: Dictionary = d.kids[0]
	var y0 := float(d.r[1])
	var ic: Dictionary = sm.kids[0]
	var b: Dictionary = sm.kids[1]
	_ic(ic, String(it.ic))
	var bw := _tw(b, String(it.n))
	b.text = it.n
	b.r[2] = bw
	b.tr = [b.r[0], b.tr[1], bw, b.tr[3]]
	var sk := [ic, b]
	if is_new:
		var nw: Dictionary = _cl(GD.det_new.kids[0].kids[2])
		_mv(nw, float(b.r[0]) + bw + 10.5, float(sm.r[1]) + 10.3)
		sk.append(nw)
	sm.kids = sk
	sm.act = _tog.bind(String(it.id))
	if not is_open:
		d.r[3] = 51.0
		d.kids = [sm]
		return d
	var ul: Dictionary = d.kids[1]
	var li0: Dictionary = ul.kids[0]
	var y := float(ul.r[1])
	var lis := []
	for s in it.b:
		var li := _cl(li0)
		_mv(li, float(li0.r[0]), y)
		var st := _cl(li)
		st.erase("kids")
		var h := _put(li, [_r(String(s), st)])
		li.r[3] = h
		lis.append(li)
		y += h + 3.1
	ul.kids = lis
	ul.r[3] = y - 3.1 - float(ul.r[1])
	d.r[3] = y - 3.1 + 9.0 - y0
	return d

func _tog(id: String) -> void:   # toggle: mở thì ghi đã đọc
	if opn.has(id):
		opn.erase(id)
	else:
		opn[id] = 1
		kh(G).rd[id] = 1
		G.mark()

func _tip() -> void:   # data-gd="tip"
	var t := kh(G)
	t.off = not bool(t.get("off", false))
	G.mark()

func _clg() -> void:   # data-gd="st": Chuyện làng
	U.clg_open()
