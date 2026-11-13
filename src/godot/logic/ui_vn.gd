extends RefCounted
# Bảng chạm con vật / chuồng (Vm "animal" / "pen" + vá b8 bản web, giao diện u2hp).
# Khung chụp từ bản web ở res://ui/snap/vn.json (chuồng gà: đang lớn, đói, có hàng, bệnh, hết thức ăn, chuồng đủ, chuồng 1 con),
# hình con vật trong khung ở res://ui/img/vn/ (a_ = con, p_ = chuồng, s_ = ô con trong chuồng).
# Dựng: chọn khung đúng tình trạng rồi thay chữ, nút, ô con; nút dàn hàng như flex-wrap gap 6 của bản web.

const Snap = preload("res://ui/snap.gd")
const Box = preload("res://ui/box.gd")
const Css = preload("res://ui/css.gd")
const GAP := 6.0
const ROWG := 8.0          # khoảng cách giữa các hàng trong u2pin
const DOT := {"grow": "rgb(47, 168, 79)", "hun": "rgb(224, 97, 42)", "rdy": "rgb(232, 164, 20)", "sick": "rgb(123, 94, 196)"}

var U
var G
var T := {}
var BT := {}               # khung nút: soft, gold, goldx (có xu), red (có sen)
var SL := {}               # khung ô con: grow, hun, rdy, sick, em
var key = null             # {t, j}: j = -1 là chuồng
var at := Vector2.ZERO     # chỗ chạm (làng)
var b: Control = null
var sig := ""
var off := Vector2.ZERO
var acts := []             # callable theo id nút "vb<i>"
var _t := 0.0              # dựng lại bảng mỗi 0,25 giây (vị trí thì mỗi khung)
var _n := {}

func _init(ui) -> void:
	U = ui
	G = ui.G
	T = Snap.load_snap("vn")
	var sk: Dictionary = T.sick
	BT.goldx = Snap.find(sk, "gold")
	BT.red = Snap.find(sk, "red")
	BT.soft = Snap.find(T.hungry, "soft")
	BT.gold = Snap.find(Snap.find(T.hungry, "hinf"), "gold")
	for n in Snap.find(T.pen, "hsls").kids:
		for s in ["grow", "hun", "rdy", "sick"]:
			if String(n.cls).split(" ").has("s-" + s):
				SL[s] = n
	SL.em = Snap.find(T.pen1, "em")
	for k in BT:
		_pearl(BT[k], k == "red")

static func _pearl(n: Dictionary, red: bool) -> void:   # ảnh trong nút đỏ là sen đỏ, nút vàng là xu
	if n.tag == "img" and red:
		n.src = "pearl"
	for k in n.get("kids", []):
		_pearl(k, red)

func is_open() -> bool:
	return key != null

func open(va: Dictionary, w: Vector2) -> void:
	key = va
	at = w
	sig = ""
	step()

func close() -> void:
	key = null
	if b != null:
		b.queue_free()
		b = null

# ------------------------------------------------------------------ chữ, nút
static func _fit(n: Dictionary, s: String) -> float:
	# đổi chữ, nới hộp theo bề ngang chữ mới; con nằm sau chữ dời theo; trả về độ nới
	var tr: Array = n.get("tr", n.r)
	var w0 := float(tr[2])
	var w1 := U_tw(n, s)
	var d := w1 - w0
	var x1 := float(tr[0]) + w0
	n.text = s
	n.tr = [tr[0], tr[1], w1, tr[3]]
	n.r = [n.r[0], n.r[1], float(n.r[2]) + d, n.r[3]]
	for k in n.get("kids", []):
		if float(k.r[0]) >= x1 - 0.5:
			Snap._move(k, Vector2(d, 0))
	return d

static func U_tw(n: Dictionary, s: String) -> float:
	return Box.text_w(s, Css.px(n.css.get("font-size", "15px")) * float(n.get("z", 1.0)), int(n.css.get("font-weight", "400"))) + 0.5

func _btn(a: Dictionary, x: float, y: float, i: int) -> Dictionary:
	var n: Dictionary = (BT[a.k] as Dictionary).duplicate(true)
	Snap._move(n, Vector2(x - float(n.r[0]), y - float(n.r[1])))
	_fit(n, String(a.t))
	if not a.get("img", true):
		for k in n.kids.duplicate():
			if k.tag == "img":
				n.kids.erase(k)
				n.r = [n.r[0], n.r[1], float(n.r[2]) - float(k.r[2]) - 3.0, n.r[3]]
	n.id = "vb" + str(i)
	return n

static func _shrink(n: Dictionary, y: float, d: float) -> void:   # bỏ / thêm một khúc cao d ở y
	var y0 := float(n.r[1])
	var y1 := y0 + float(n.r[3])
	if y0 >= y - 0.5:
		Snap._move(n, Vector2(0, d))
		return
	if y1 > y - 0.5:
		n.r = [n.r[0], n.r[1], n.r[2], float(n.r[3]) + d]
	for k in n.get("kids", []):
		_shrink(k, y, d)

func _drop_row(root: Dictionary, row: Dictionary) -> void:
	var pin := Snap.find(root, "u2pin")
	var y := float(row.r[1])
	var h := float(row.r[3]) + ROWG
	pin.kids.erase(row)
	_shrink(root, y + float(row.r[3]) + ROWG * 0.5, -h)

func _row_btns(root: Dictionary, row: Dictionary, L: Array, i0: int) -> int:
	# dàn nút trái sang phải, hết chỗ thì xuống hàng (flex-wrap, gap 6); trả về số nút đã đặt
	var x0 := float(row.r[0])
	var W := float(row.r[2])
	var y0 := float(row.r[1])
	var x := x0
	var y := y0
	var kids := []
	var i := i0
	for a in L:
		var n := _btn(a, x, y, i)
		if x > x0 and x + float(n.r[2]) > x0 + W + 0.5:
			x = x0
			y += 30.0 + GAP
			n = _btn(a, x, y, i)
		kids.append(n)
		x += float(n.r[2]) + GAP
		i += 1
	row.kids = kids
	var h := y - y0 + 30.0
	var d := h - float(row.r[3])
	if absf(d) > 0.01:
		var yb := float(row.r[1]) + float(row.r[3])
		row.r = [row.r[0], row.r[1], row.r[2], h]
		var pin := Snap.find(root, "u2pin")
		for k in root.kids:
			if k != pin:
				_shrink(k, yb, d)
		for k in pin.kids:
			if k != row:
				_shrink(k, yb, d)
		pin.r = [pin.r[0], pin.r[1], pin.r[2], float(pin.r[3]) + d]
		root.r = [root.r[0], root.r[1], root.r[2], float(root.r[3]) + d]
	return i - i0

func _svg_item(n: Dictionary, id: String) -> void:   # icon món trong hàng "Ăn ... →": svg của Kho (ui/svg/kh)
	var s := FileAccess.get_file_as_string("res://ui/svg/kh/" + id + ".svg")
	var v := Snap.find(n, "", "svg")
	if s != "" and not v.is_empty():
		v.svg = s

func _inf(root: Dictionary, t: String, btn) -> void:   # hàng "Ăn [lúa] lúa kho 6 → [trứng] trứng" + nút bên phải
	var r: Dictionary = G.vn.Q[t]
	var n := Snap.find(root, "hinf")
	var kids: Array = n.kids
	var dx := 0.0
	var hic := 0
	var bi := 0
	var kho := int(G.g.barn.get(r.feed, 0))
	for k in kids.duplicate():
		if dx != 0.0 and k.tag != "button":
			Snap._move(k, Vector2(dx, 0))
		if String(k.cls).split(" ").has("hic"):
			_svg_item(k, String(r.feed if hic == 0 else r.make))
			hic += 1
		elif k.tag == "b":
			dx += _fit(k, G.item_name(r.feed if bi == 0 else r.make).to_lower())
			bi += 1
		elif k.tag == "span" and k.has("text"):
			k.cls = "" if kho > 0 else "no"
			dx += _fit(k, "kho " + str(kho))
		elif k.tag == "button":
			kids.erase(k)
	if btn != null:
		var x1 := float(n.r[0]) + float(n.r[2])   # nút sát mép phải hàng
		var bn := _btn(btn, 0.0, float(n.r[1]) + 1.0, 0)
		Snap._move(bn, Vector2(x1 - float(bn.r[2]) - float(bn.r[0]), 0))
		kids.append(bn)

func _head(root: Dictionary, title: String, chip: String, dot: String, cnt: String, pic: String, tm2 := "") -> void:
	var ph := Snap.find(root, "u2ph")
	var tb: Dictionary = Snap.find(ph, "u2pt").kids[0]
	_fit(tb, title)
	var tm := Snap.find(ph, "tm")
	if tm2 != "":   # "Còn [9p 55s]"
		_fit(tm, chip)
		var bb: Dictionary = tm.kids[0]
		var d := _fit(bb, tm2)
		tm.r = [tm.r[0], tm.r[1], float(tm.r[2]) + d, tm.r[3]]
	else:
		tm.kids = []
		_fit(tm, chip)
	if tm.has("::before") and dot != "":   # chấm màu đứng trước chữ (inline): đặt tuyệt đối cho builder vẽ
		var pb: Dictionary = tm["::before"]
		pb.bg = dot
		pb.pos = "absolute"
		pb.left = "8px"
		pb.top = str((float(tm.r[3]) - 8.0) * 0.5) + "px"
	var sp := Snap.find(ph, "u2sp")
	_fit(sp, cnt)
	var cv := Snap.find(ph, "", "canvas")
	cv.tag = "div"
	cv["pic"] = pic

# ------------------------------------------------------------------ nội dung theo tình trạng
func _act(t: String, k: String, cb: Callable, img := true, dis := false) -> Dictionary:
	return {"t": t, "k": k, "cb": cb, "img": img, "dis": dis}

func _animal(t: String, j: int) -> Dictionary:
	var V = G.vn
	var e = V.a(t, j)
	if e == null:
		return {}
	var r: Dictionary = V.Q[t]
	var F = U.F
	var title: String = V.q4(t, j)
	var cnt := str(int(floor(float(e.get("t", 0))))) + "/5"
	var pic := "res://ui/img/vn/a_" + t + ".png"
	var pet_done: bool = int(e.get("pd", -1)) == G.day()
	var pet := _act("Hôm nay nựng rồi" if pet_done else "Vuốt ve", "soft", func(): F.vn_job(t, j, "pet"), false, pet_done)
	var feed: String = r.feed
	var kho := int(G.g.barn.get(feed, 0))
	var mk: String = G.item_name(r.make).to_lower()
	if float(e.get("b", 0)) > 0.0:
		return {"tpl": "grow", "h": [title, "Còn nhỏ", DOT.grow, cnt, pic], "bar": [1.0 - float(e.b) / V.BABY, ""], "row": [pet]}
	if e.get("s", 0):
		return {"tpl": "sick", "h": [title, "Đang bệnh", DOT.sick, cnt, pic], "row": [
			_act("Mời thú y · " + str(V.ZM), "goldx", func(): V.vet(t, j), true, int(G.g.coins) < V.ZM),
			_act("Chữa ngay · 2", "red", func(): V.cure_now(t, j)), pet]}
	if V.ready(t, e):
		return {"tpl": "ready", "h": [title, "Có " + mk + " rồi", DOT.rdy, cnt, pic], "inf": _act("Thu " + mk, "gold", func(): F.vn_job(t, j, "collect"), false), "row": [pet]}
	if float(e.p) < 0.0:
		if kho > 0:
			return {"tpl": "hungry", "h": [title, "Đang đói", DOT.hun, cnt, pic], "inf": _act("Cho ăn", "gold", func(): F.vn_job(t, j, "feed"), false), "row": [pet]}
		var cost: int = G.lack_cost([[feed, 1]])
		return {"tpl": "nofeed", "h": [title, "Đang đói", DOT.hun, cnt, pic], "inf": _act("Bù 1 " + G.item_name(feed).to_lower() + " · " + str(cost), "red",
			func(): U._lack_open([[feed, 1]], "Kho hết thức ăn cho " + V.name(t).to_lower() + ":", func(): F.vn_job(t, j, "feed"))), "row": [pet]}
	var left: float = V.left(t, e)
	var fr := float(e.p) / float(r.time)
	return {"tpl": "grow", "h": [title, "Còn", DOT.grow, cnt, pic, U.tfmt(left)], "bar": [fr, str(int(round(fr * 100))) + "%"],
		"bbtn": _act("Xong · " + str(V.ro(left)), "red", func(): V.fast(t, j)), "row": [pet]}

func _pen(t: String) -> Dictionary:
	var V = G.vn
	var L: Array = V.list(t)
	var r: Dictionary = V.Q[t]
	var F = U.F
	var ready := 0
	var hun := 0
	for e in L:
		if V.ready(t, e):
			ready += 1
		elif V.hungry(e):
			hun += 1
	var slots := []
	for j in V.gl():
		if j >= L.size():
			slots.append(["em", -1])
			continue
		var e: Dictionary = L[j]
		slots.append(["sick" if e.get("s", 0) else "rdy" if V.ready(t, e) else "hun" if float(e.p) < 0.0 and not e.get("b", 0) else "grow", j])
	var inf = null
	if ready > 0:
		inf = _act("Thu hết · " + str(ready), "gold", _collect_all.bind(t), false)
	elif L.size() < V.gl():
		inf = _act("Mua giống · " + G.fmt_n(V.price(t)), "goldx", func(): V.buy(t), true, int(G.g.coins) < V.price(t))
	var row := []
	if hun > 0:
		var kho := int(G.g.barn.get(r.feed, 0))
		row.append(_act("Cho ăn hết", "soft", _feed_all.bind(t), false, kho < 1))
	var fc: int = V.fast_all_cost(t)
	if fc > 0:
		row.append(_act("Xong hết · " + str(fc), "red", func(): V.fast_all(t)))
	return {"tpl": "pen", "h": [String(G.lang.CO.get(t, "Chuồng")), str(L.size()) + "/" + str(V.gl()) + " con", "", str(V.ps(t) - 1) + "/5", "res://ui/img/vn/p_" + t + ".png"],
		"slots": slots, "inf": inf, "row": row}

func _collect_all(t: String) -> void:   # "Thu hết": nhân vật đi thu từng con
	var L: Array = G.vn.list(t)
	for j in L.size():
		if G.vn.ready(t, L[j]):
			U.F.vn_job(t, j, "collect")

func _feed_all(t: String) -> void:   # "Cho ăn hết": đủ thức ăn tới đâu cho tới đó
	var V = G.vn
	var L: Array = V.list(t)
	var kho := int(G.g.barn.get(V.Q[t].feed, 0))
	var n := 0
	for j in L.size():
		if V.hungry(L[j]) and n < kho:
			n += 1
			U.F.vn_job(t, j, "feed")

func _model() -> Dictionary:
	if key == null:
		return {}
	var t: String = key.t
	if G.vn.list(t).size() == 0 and int(key.j) >= 0:
		return {}
	return _pen(t) if int(key.j) < 0 else _animal(t, int(key.j))

func _make(m: Dictionary) -> Dictionary:
	var n: Dictionary = (T[m.tpl] as Dictionary).duplicate(true)
	var h: Array = m.h
	_head(n, h[0], h[1], h[2], h[3], h[4], h[5] if h.size() > 5 else "")
	acts = []
	var i := 0
	# thanh tiến độ + nút "Xong · n"
	var bars := Snap.find(n, "u2bars")
	if not bars.is_empty():
		var pb := Snap.find(bars, "ppbar")
		var tk: Dictionary = pb.kids[0]
		var fill: Dictionary = tk.kids[0]
		fill.r = [fill.r[0], fill.r[1], float(tk.r[2]) * clampf(float(m.bar[0]), 0.0, 1.0), fill.r[3]]
		var em := Snap.find(pb, "", "em")
		em.text = String(m.bar[1])
		var bt := Snap.find(bars, "red")
		_pearl(bt, true)
		if m.has("bbtn"):
			var d := _fit(bt, String(m.bbtn.t))
			Snap._move(bt, Vector2(-d, 0))
			pb.r = [pb.r[0], pb.r[1], float(pb.r[2]) - d, pb.r[3]]
			tk.r = [tk.r[0], tk.r[1], float(tk.r[2]) - d, tk.r[3]]
			fill.r = [fill.r[0], fill.r[1], float(tk.r[2]) * clampf(float(m.bar[0]), 0.0, 1.0), fill.r[3]]
			Snap._move(em, Vector2(-d, 0))
			bt.id = "vb" + str(i)
			acts.append(m.bbtn)
			i += 1
		else:
			bars.kids.erase(bt)
	# ô con trong chuồng (4 ô một hàng, gap 6)
	var hs := Snap.find(n, "hsls")
	if not hs.is_empty():
		var x0 := float(hs.r[0])
		var y0 := float(hs.r[1])
		var kids := []
		var pin := Snap.find(n, "u2pin")
		for q in m.slots.size():
			var s: Array = m.slots[q]
			var c: Dictionary = (SL[s[0]] as Dictionary).duplicate(true)
			Snap._move(c, Vector2(x0 + (q % 4) * (70.0 + GAP) - float(c.r[0]), y0 + (q / 4) * (56.0 + GAP) - float(c.r[1])))
			var cv := Snap.find(c, "", "canvas")
			if not cv.is_empty():
				cv.tag = "div"
				cv["pic"] = "res://ui/img/vn/s_" + String(key.t) + ".png"
				var jj: int = s[1]
				c.id = "vb" + str(i)
				acts.append({"cb": func(): open({"t": key.t, "j": jj}, at), "dis": false})
				i += 1
			kids.append(c)
		hs.kids = kids
		var rows := int(ceil(m.slots.size() / 4.0))
		var d2 := (rows - 1) * (56.0 + GAP)
		if d2 > 0.0:
			var yb := y0 + float(hs.r[3])
			hs.r = [hs.r[0], hs.r[1], hs.r[2], float(hs.r[3]) + d2]
			for k in n.kids:
				if k != pin:
					_shrink(k, yb, d2)
			for k in pin.kids:
				if k != hs:
					_shrink(k, yb, d2)
			pin.r = [pin.r[0], pin.r[1], pin.r[2], float(pin.r[3]) + d2]
			n.r = [n.r[0], n.r[1], n.r[2], float(n.r[3]) + d2]
	# hàng "Ăn ... →" + nút bên phải
	var inf := Snap.find(n, "hinf")
	if not inf.is_empty():
		var a = m.get("inf")
		_inf(n, String(key.t), a)
		if a != null:
			var bk: Dictionary = inf.kids[inf.kids.size() - 1]
			bk.id = "vb" + str(i)
			acts.append(a)
			i += 1
	# hàng nút
	var row := Snap.find(n, "hmrow")
	if not row.is_empty():
		if m.row.is_empty():
			_drop_row(n, row)
		else:
			_row_btns(n, row, m.row, i)
			acts.append_array(m.row)
	return n

# ------------------------------------------------------------------ mỗi khung
func step(dt := 1.0) -> void:
	if key == null:
		return
	_t -= dt
	if _t <= 0.0 or sig == "":
		_t = 0.25
		var m := _model()
		if m.is_empty():
			close()
			return
		_n = _make(m)
	var F = U.F
	var w := at
	if int(key.j) >= 0 and F.anodes.has(String(key.t) + ":" + str(key.j)):
		w = F.anodes[String(key.t) + ":" + str(key.j)].foot() + Vector2(0, -26)
	var n: Dictionary = _n
	# chỗ đặt (xC): ngang giữa chỗ chạm, trên 18; sát mép trên quá thì lật xuống dưới
	var H: float = float(n.r[3])
	var Wd: float = float(n.r[2])
	var a: Vector2 = (Vector2(w.x, w.y - 18.0) - U.main.cam) * U.main.zoom / Css.K
	var l := maxf(8.0, minf(U.vw - Wd - 8.0, a.x - Wd * 0.5))
	var c := a.y - H - 18.0
	var below := false
	if c < 70.0:
		c = a.y + 40.0
		below = true
	c = maxf(8.0, minf(U.vh - H - 8.0, c))
	var ax := roundf(maxf(18.0, minf(Wd - 18.0, a.x - l)))
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
		_pics(b)
		U._click(ids.get(".ppx"), close, "scale")
		for q in acts.size():
			var bx = ids.get("#vb" + str(q))
			if bx == null:
				continue
			var ac: Dictionary = acts[q]
			if ac.get("dis", false):
				bx.modulate = Color(1, 1, 1, 0.55)
				continue
			var cb: Callable = ac.cb
			U._click(bx, _do.bind(cb), "down")
	b.position = (b.r.position + off) * Css.K

func _do(cb: Callable) -> void:
	cb.call()
	sig = ""

func _pics(x: Control) -> void:
	for k in x.kids():
		var n: Dictionary = k.get_meta("snap", {})
		if n.has("pic"):
			var tx: Texture2D = Css.image(n.pic)
			if tx != null:
				k.pic(tx, Rect2(Vector2.ZERO, k.r.size))
		_pics(k)
