extends RefCounted
# Bảng LÊN CẤP chép từ bản web (QH / TJ / KH / iL, giao diện u2lv).
# Khung, thẻ quà, nút lấy đúng số đo bản web (res://ui/snap/lv5.json, chụp lúc lên cấp 5 còn 1 cấp chờ).
# Quà mở khóa từng cấp 2–100 (MJ bản web) ở res://ui/snap/lv_qua.json; hình xưởng/chuồng (canvas Qv/Z5) và emoji
# chụp từ chính bản web ở res://ui/img/lv/.

const Snap = preload("res://ui/snap.gd")
const Box = preload("res://ui/box.gd")
const Css = preload("res://ui/css.gd")

const CW := 94.0          # thẻ quà: 3 cột, cách 6
const CX0 := 22.0
const GY := 6.0
const GMAX := 256.2       # .lvgifts max-height 42vh
const SM_W := 86.0        # chữ dưới thẻ: rộng tối đa (94 - padding 4 x 2)

var U
var G
var on := false
var box: Control = null
var ids := {}
var gifts: Control = null
var cont: Control = null
var hmax := 0.0
var scroll := 0.0
var drag = null
var T := {}
var Q := {}
var _wait := 0.0
var lvT := 0.0             # aa.lvT: chữ LÊN CẤP! trên đầu nhân vật (2,5 giây)

func _init(ui) -> void:
	U = ui
	G = ui.G
	Q = Snap.load_snap("lv_qua")
	var root: Dictionary = Snap.load_snap("lv5")[".lvov"][0]
	T.root = root
	var gk: Array = Snap.find(root, "lvgifts").kids
	T.xu = gk[0]
	T.sen = gk[1]
	T.svg = gk[2]
	T.cv = gk[4]
	T.emo = gk[6]

static func _tw(n: Dictionary, s: String) -> float:
	return Box.text_w(s, Css.px(n.css.get("font-size", "15px")) * float(n.get("z", 1.0)), int(n.css.get("font-weight", "400")))

static func _at(n: Dictionary, x: float, y: float) -> void:
	Snap._move(n, Vector2(x - float(n.r[0]), y - float(n.r[1])))

static func _ctext(n: Dictionary, s: String, cx: float, y: float) -> float:
	# chữ giữa thẻ, rộng theo chữ (xuống 2 dòng khi quá SM_W); trả về cao
	var w := _tw(n, s)
	var lh := float(n.r[3])
	var lines := 1
	if w > SM_W:
		w = SM_W
		lines = 2
	var tr: Array = n.get("tr", n.r)
	var off := float(tr[1]) - float(n.r[1])
	n.text = s
	n.r = [cx - w / 2.0, y, w, lh * lines]
	n.tr = [cx - w / 2.0, y + off, w + (0.5 if lines == 1 else 0.0), float(tr[3]) + (lh if lines == 2 else 0.0)]
	return lh * lines

static func _kid(c: Dictionary, tag: String) -> Dictionary:
	for k in c.kids:
		if k.tag == tag:
			return k
	return {}

func _card(it: Dictionary, t: int) -> Dictionary:
	var k: String = it.k
	var c: Dictionary = (T.xu if k == "xu" else T.sen if k == "sen" else T.cv if k == "cv" else T.emo if k == "emo" else T.svg).duplicate(true)
	_at(c, 0.0, 0.0)
	var cx := CW / 2.0
	var y := 12.0
	var ic: Dictionary = c.kids[0]
	var ih := float(ic.r[3])
	if k == "xu" and ic.kids.size() > 0:
		ic.kids[0].src = "xuimg"
	if k == "svg":
		ic.svg = it.svg
	elif k == "cv":
		ic.tag = "div"
		ic["pic"] = "res://ui/img/lv/" + String(it.ic) + ".png"
	elif k == "emo":
		ic.erase("text")
		ic.erase("tr")
		ic.r = [cx - 23.0, y, 46.0, 46.0]
		ic["pic"] = "res://ui/img/lv/" + String(it.ic) + ".png"
	y += ih + 3.0
	var b := _kid(c, "b")
	if not b.is_empty():
		if k == "xu":
			b.text = "+" + G.fmt_n(30 * t)
		y += _ctext(b, b.text, cx, y) + 3.0
	var sm := _kid(c, "small")
	y += _ctext(sm, String(it.n), cx, y)
	var em := _kid(c, "em")
	if not em.is_empty() and not it.get("em", false):
		c.kids.erase(em)
	c.r = [0.0, 0.0, CW, y + 10.0]
	return c

func _queue() -> Array:
	if not (G.g.get("lvq") is Array):
		G.g.lvq = []
	return G.g.lvq

# ------------------------------------------------------------------ mở (QH), nhận (TJ / KH), đóng (iL)
func open() -> void:
	var q := _queue()
	if on or q.is_empty():
		return
	var t := int(q[0])
	var L: Array = Q.get(str(t), [])
	var n: Dictionary = T.root.duplicate(true)
	var wrap := Snap.find(n, "lvwrap")
	var gb := Snap.find(n, "lvgifts")
	var g0: Array = gb.r
	# thẻ quà xếp lưới 3 cột, mỗi hàng cao bằng thẻ cao nhất
	var cards := []
	var news := 0
	for it in L:
		cards.append(_card(it, t))
		if it.get("em", false):
			news += 1
	var y := float(g0[1])
	var i := 0
	while i < cards.size():
		var h := 0.0
		for j in range(i, mini(i + 3, cards.size())):
			h = maxf(h, float(cards[j].r[3]))
		for j in range(i, mini(i + 3, cards.size())):
			var c: Dictionary = cards[j]
			_at(c, CX0 + (j - i) * (CW + GY), y)
			c.r = [c.r[0], c.r[1], CW, h]
		y += h + GY
		i += 3
	var ch := y - GY - float(g0[1])
	var gh := minf(ch, GMAX)
	hmax = maxf(0.0, ch - gh)
	scroll = 0.0
	gb.kids = []
	gb.r = [g0[0], g0[1], g0[2], gh]
	T.cards = cards
	# tiêu đề: Lên cấp N · Mở khóa K thứ mới / Chúc mừng!
	var hb := Snap.find(n, "u2pt")
	var tb: Dictionary = hb.kids[0]
	tb.text = "Lên cấp " + str(t)
	tb.tr = [tb.tr[0], tb.tr[1], _tw(tb, tb.text) + 0.5, tb.tr[3]]
	var tm: Dictionary = hb.kids[1]
	var pad := Css.px(tm.css.get("padding-left", "8px"))
	tm.text = ("Mở khóa " + str(news) + " thứ mới") if news > 0 else "Chúc mừng!"
	var tw := _tw(tm, tm.text)
	tm.r = [tm.r[0], tm.r[1], tw + 2.0 * pad, tm.r[3]]
	tm.tr = [float(tm.r[0]) + pad, tm.tr[1], tw + 0.5, tm.tr[3]]
	# nút
	var bt := Snap.find(n, "lvbtn")
	var al := Snap.find(n, "lvall")
	var yb := float(g0[1]) + gh + 14.0
	Snap._move(bt, Vector2(0, yb - float(bt.r[1])))
	var bottom := yb + float(bt.r[3])
	if q.size() > 1:
		Snap._move(al, Vector2(0, bottom + 8.0 - float(al.r[1])))
		al.text = "Mở hết " + str(q.size()) + " cấp một lần"
		var aw := _tw(al, al.text)
		var acx := float(al.r[0]) + float(al.r[2]) / 2.0
		al.tr = [acx - aw / 2.0, al.tr[1], aw + 0.5, al.tr[3]]
		# gạch dưới chữ (text-decoration: underline)
		var fs := Css.px(al.css.get("font-size", "13px"))
		al.kids = [{"tag": "div", "id": "", "cls": "", "z": al.get("z", 1.0), "kids": [],
			"css": {"background-color": al.css.get("color", "rgb(35, 116, 74)")},
			"r": [acx - aw / 2.0, float(al.tr[1]) + fs * 1.08, aw, maxf(0.8, fs / 13.0)]}]
		bottom = float(al.r[1]) + float(al.r[3])
	else:
		wrap.kids.erase(al)
	# khung giữa màn hình như flex center của .lvov
	var w0: Array = wrap.r
	var wh := bottom + 14.0 + 2.0 - float(w0[1])
	var root_h := float(n.r[3])
	var dy := (root_h - wh) / 2.0 - float(w0[1])
	for k in wrap.kids:
		Snap._move(k, Vector2(0, dy))
	wrap.r = [w0[0], float(w0[1]) + dy, w0[2], wh]
	for c in cards:
		Snap._move(c, Vector2(0, dy))
	gb = Snap.find(n, "lvgifts")
	# dựng
	# lớp tối .lvov thành lớp riêng phủ kín màn thật (_cover), khung nằm giữa như flex center
	var bk: Dictionary = n.duplicate()
	bk.kids = []
	bk.css = bk.css.duplicate()
	bk.css["z-index"] = "auto"
	var top := {"tag": "div", "id": "", "cls": "", "z": n.get("z", 1.0), "css": {}, "r": n.r, "kids": [bk, wrap]}
	ids = {}
	box = U._build(top, ids)
	U.root.add_child(box)
	U.anchors.append([box, 0.5, 0.5])
	U._stop(box)
	if ids.has(".lvov"):
		U._stop(ids.get(".lvov"))
	gifts = ids.get(".lvgifts")
	gifts._kids.clip_contents = true
	var gr := Rect2(gb.r[0], gb.r[1], gb.r[2], gb.r[3])
	var cc := {"tag": "div", "id": "", "cls": "", "z": 1.0, "css": {}, "kids": cards, "r": [gr.position.x, gr.position.y, gr.size.x, ch]}
	cont = U._build(cc, {}, gr.position)
	gifts.add(cont)
	_pics(cont)
	U._click(ids.get(".lvbtn"), take, "down")
	if ids.has(".lvall"):
		U._click(ids.get(".lvall"), take_all, "down")
	U._layout()
	on = true
	G.vib(120)

func _pics(b: Control) -> void:
	for k in b.kids():
		var n: Dictionary = k.get_meta("snap", {})
		if n.has("pic"):
			var t: Texture2D = Css.image(n.pic)
			if t != null:
				k.pic(t, Rect2(Vector2.ZERO, k.r.size))
		_pics(k)

func take() -> void:   # TJ: nhận quà 1 cấp
	var q := _queue()
	if q.is_empty():
		close()
		return
	var t := int(q.pop_front())
	var a := 30 * t
	G.g.coins = int(G.g.coins) + a
	if t % 5 == 0:
		G.g.ngoc = int(G.g.get("ngoc", 0)) + 3
	G.toast.emit("Nhận " + G.fmt_n(a) + " xu quà lên cấp " + str(t) + ".")
	G.mark()
	close()
	if not q.is_empty():
		_wait = 0.45

func take_all() -> void:   # KH: nhận hết các cấp đang chờ
	var q := _queue()
	var t := 0
	var a := 0
	var n := 0
	while not q.is_empty():
		var r := int(q.pop_front())
		t += 30 * r
		if r % 5 == 0:
			a += 3
		n += 1
	G.g.coins = int(G.g.coins) + t
	if a:
		G.g.ngoc = int(G.g.get("ngoc", 0)) + a
	G.toast.emit("Nhận quà " + str(n) + " cấp: " + G.fmt_n(t) + " xu" + ((", " + str(a) + " sen đỏ") if a else "") + ".")
	G.mark()
	close()

func close() -> void:   # iL
	on = false
	if box != null:
		U.anchors.erase(U._anchor_of(box))
		box.queue_free()
		box = null
	gifts = null
	cont = null

# ------------------------------------------------------------------ cuộn danh sách quà
func input(e: InputEvent) -> bool:
	if not on or gifts == null:
		return false
	var pos := Vector2.ZERO
	if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		scroll = clampf(scroll + (-40.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 40.0), 0.0, hmax)
		U._move(cont, Vector2(0, -scroll))
		return true
	if e is InputEventScreenTouch or e is InputEventMouseButton:
		if e is InputEventMouseButton and e.button_index != MOUSE_BUTTON_LEFT:
			return false
		pos = e.position / Css.K
		if e.pressed:
			var gr := Rect2(gifts.get_global_rect().position / Css.K, gifts.r.size)
			drag = {"y0": pos.y, "s0": scroll, "moved": false} if gr.has_point(pos) else null
		else:
			drag = null
	elif (e is InputEventScreenDrag or e is InputEventMouseMotion) and drag != null:
		pos = e.position / Css.K
		var d: float = pos.y - drag.y0
		if absf(d) > 6.0:
			drag.moved = true
		if drag.moved and cont != null:
			scroll = clampf(drag.s0 - d, 0.0, hmax)
			U._move(cont, Vector2(0, -scroll))
	return false

func step(dt: float) -> void:
	lvT = maxf(0.0, lvT - dt)
	if _wait > 0.0:
		_wait -= dt
		if _wait <= 0.0:
			open()
		return
	if not on and not _queue().is_empty():
		open()
