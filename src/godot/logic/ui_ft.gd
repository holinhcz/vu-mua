extends RefCounted
# Bảng chạm cây ăn trái (hg / Rj bản web, giao diện ppop ui2 xanh).
# Khung chụp từ bản web ở res://ui/snap/ft.json: grow (đang ra trái: thanh Trái + "Chín · n", thanh Nước + "Tưới"),
# ripe (có trái: "Hái n trái · ~giá [xu]/trái" + "Thu hoạch").

const Snap = preload("res://ui/snap.gd")
const Box = preload("res://ui/box.gd")
const Css = preload("res://ui/css.gd")

var U
var G
var T := {}
var ti := -1               # món (g.objs) đang mở
var b: Control = null
var sig := ""
var off := Vector2.ZERO
var _t := 0.0
var _n := {}
var acts := {}             # "#id" -> Callable

func _init(ui) -> void:
	U = ui
	G = ui.G
	T = Snap.load_snap("ft")

func is_open() -> bool:
	return ti >= 0

func open(i: int) -> void:
	ti = i
	sig = ""
	step(1.0)

func close() -> void:
	ti = -1
	if b != null:
		b.queue_free()
		b = null

static func _tw(n: Dictionary, s: String) -> float:
	return Box.text_w(s, Css.px(n.css.get("font-size", "15px")) * float(n.get("z", 1.0)), int(n.css.get("font-weight", "400"))) + 0.5

static func _fit(n: Dictionary, s: String) -> float:   # đổi chữ, nới hộp; con nằm sau chữ dời theo
	var tr: Array = n.get("tr", n.r)
	var w0 := float(tr[2])
	var w1 := _tw(n, s)
	var d := w1 - w0
	var x1 := float(tr[0]) + w0
	n.text = s
	n.tr = [tr[0], tr[1], w1, tr[3]]
	n.r = [n.r[0], n.r[1], float(n.r[2]) + d, n.r[3]]
	for k in n.get("kids", []):
		if float(k.r[0]) >= x1 - 0.5:
			Snap._move(k, Vector2(d, 0))
	return d

static func _pearl(n: Dictionary) -> void:
	if n.tag == "img":
		n.src = "pearl"
	for k in n.get("kids", []):
		_pearl(k)

func _icon(n: Dictionary, id: String) -> void:   # hình trái trong vòng tròn đầu bảng
	var s := FileAccess.get_file_as_string("res://ui/svg/kh/" + id + ".svg")
	var v := Snap.find(Snap.find(n, "u2pi"), "", "svg")
	if s != "" and not v.is_empty():
		v.svg = s

func _make(a: Dictionary) -> Dictionary:
	var C = G.ct
	var e: Dictionary = C.E(a)
	var name: String = String(G.lang.Pi[a.id].n)
	var F = U.F
	var i := ti
	acts = {}
	if C.ripe(a):
		var n: Dictionary = (T.ripe as Dictionary).duplicate(true)
		_icon(n, String(e.p))
		_fit(Snap.find(n, "u2pt").kids[0], "Cây " + name.to_lower() + " có trái")
		# "Hái 3 trái · ~49 [xu]/trái": chữ trước hình xu, "/trái" sau hình xu
		var tm := Snap.find(n, "tm")
		var im: Dictionary = tm.kids[0]
		var s1 := "Hái " + str(int(e.yield)) + " trái · ~" + G.fmt_n(G.price(String(e.p)))
		var tr0: Array = tm.tr
		tm.text = s1
		var w1 := _tw(tm, s1)
		tm.tr = [tr0[0], tr0[1], w1, tr0[3]]
		var ix := float(tr0[0]) + w1 + 3.0
		im.r = [ix, im.r[1], im.r[2], im.r[3]]
		var t2: Dictionary = {"z": 1, "tag": "span", "id": "", "cls": "", "css": tm.css.duplicate(), "kids": []}
		for k in ["background-color", "background-image", "box-shadow"]:
			t2.css.erase(k)
		t2.css["border-radius"] = "0px"
		t2.css["padding-left"] = "0px"
		var sx := ix + float(im.r[2]) + 1.0
		var w2 := _tw(tm, "/trái")
		t2.text = "/trái"
		t2.r = [sx, tr0[1], w2, tr0[3]]
		t2.tr = [sx, tr0[1], w2, tr0[3]]
		tm.kids.append(t2)
		tm.r = [tm.r[0], tm.r[1], sx + w2 + 8.0 - float(tm.r[0]), tm.r[3]]
		var bt := Snap.find(n, "ppbig")
		bt.id = "ftgo"
		acts["#ftgo"] = func(): F.ft_job(i, "tharvest"); close()
		return n
	var n: Dictionary = (T.grow as Dictionary).duplicate(true)
	_icon(n, String(e.p))
	_fit(Snap.find(n, "u2pt").kids[0], "Cây " + name.to_lower())
	var tm := Snap.find(n, "tm")
	var lf: float = C.left(a)
	var wet := float(a.fw) > 0.0
	# web Rj: lúc có nước thì còn ít hơn chừng 9% của phần còn nước
	var shown := lf - minf(lf, float(a.fw)) * 0.09 if wet else lf
	var d := _fit(tm.kids[0], U.tfmt(shown))
	tm.r = [tm.r[0], tm.r[1], float(tm.r[2]) + d, tm.r[3]]
	var rows: Array = Snap.find(n, "u2bars").kids
	# hàng Trái: thanh %, nút "Chín · n [sen]"
	var r0: Dictionary = rows[0]
	var bar := Snap.find(r0, "ppbar")
	var tk: Dictionary = bar.kids[1]
	var fr := clampf(float(a.fp) / float(e.time), 0.0, 1.0)
	tk.kids[0].r = [tk.r[0], tk.r[1], float(tk.r[2]) * fr, tk.r[3]]
	Snap.find(bar, "", "em").text = str(int(round(fr * 100))) + "%"
	var ch := Snap.find(r0, "u2act")
	_pearl(ch)
	var sm := Snap.find(ch, "", "small")
	var dd := _fit(sm, str(C.ro(lf)))
	ch.r = [float(ch.r[0]) - dd, ch.r[1], float(ch.r[2]) + dd, ch.r[3]]
	Snap._move(ch.kids[0], Vector2(-dd, 0))
	Snap._move(sm, Vector2(-dd, 0))
	ch.id = "ftng"
	acts["#ftng"] = func(): C.fast(i)
	# hàng Nước: thanh, "Đang ẩm" / "Khô", nút "Tưới"
	var r1: Dictionary = rows[1]
	var bw := Snap.find(r1, "ppbar")
	var tw: Dictionary = bw.kids[1]
	tw.kids[0].r = [tw.r[0], tw.r[1], float(tw.r[2]) * clampf(float(a.fw) / C.F2, 0.0, 1.0), tw.r[3]]
	var em := Snap.find(bw, "", "em")
	em.text = "Đang ẩm" if wet else "Khô"
	em.tr = [em.tr[0], em.tr[1], _tw(em, em.text), em.tr[3]]
	var wb := Snap.find(r1, "u2act")
	wb.id = "ftw"
	if C.can_water(a):
		acts["#ftw"] = func(): F.ft_job(i, "twater")
	else:
		var wl: Dictionary = wb.kids[0]
		var dw := _fit(wl, "Đất còn ướt")
		wb.r = [float(wb.r[0]) - dw, wb.r[1], float(wb.r[2]) + dw, wb.r[3]]
		Snap._move(wl, Vector2(-dw, 0))
		acts["#ftw"] = null
	return n

func step(dt: float) -> void:
	if ti < 0:
		return
	var a = G.ct.tree(ti) if G.ct != null else null
	if a == null:
		close()
		return
	_t -= dt
	if _t <= 0.0 or sig == "":
		_t = 0.25
		_n = _make(a)
	var n: Dictionary = _n
	var w: Vector2 = U.F.ft_bub(ti)
	# chỗ đặt (xC): ngang giữa cây, trên 18; sát mép trên quá thì lật xuống dưới
	var H: float = float(n.r[3])
	var Wd: float = float(n.r[2])
	var p: Vector2 = (Vector2(w.x, w.y - 18.0) - U.main.cam) * U.main.zoom / Css.K
	var l := maxf(8.0, minf(U.vw - Wd - 8.0, p.x - Wd * 0.5))
	var c := p.y - H - 18.0
	var below := false
	if c < 70.0:
		c = p.y + 60.0
		below = true
	c = maxf(8.0, minf(U.vh - H - 8.0, c))
	var ax := roundf(maxf(18.0, minf(Wd - 18.0, p.x - l)))
	if n.has("::after"):
		n["::after"].left = str(ax - 8.0) + "px"
		n["::after"].top = (str(-6.05) if below else str(H - 9.95)) + "px"
	var s := str(n.hash())
	off = Vector2(l, c) - Vector2(float(n.r[0]), float(n.r[1]))
	if s != sig:
		sig = s
		if b != null:
			b.queue_free()
		var ids := {}
		b = U._build(n, ids)
		U.root.add_child(b)
		U._stop(b)
		U._click(ids.get(".ppx"), close, "scale")
		for k in acts:
			var bx = ids.get(k)
			if bx == null:
				continue
			if acts[k] == null:
				bx.modulate = Color(1, 1, 1, 0.55)
				continue
			U._click(bx, _do.bind(acts[k]), "down")
	b.position = (b.r.position + off) * Css.K

func _do(cb: Callable) -> void:
	cb.call()
	sig = ""
