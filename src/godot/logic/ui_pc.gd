extends RefCounted
# BẢNG NHÂN VẬT bản web (ST/ec: .raceov.pcov > .rbox.pcbox, tab Nhân vật / Đồ nghề, xe / ...), mở khi bấm hình đại diện #pcAv.
# Mỗi trạng thái một bản chụp từ web:
#   ns_nv (3 món ăn), ns_nv0 (kho không có gì ăn), ns_nv2 (5 món ăn, cấp 6)
#   ns_dn (đồ nghề cấp 0/1, chưa có xe), ns_dn2 (bình cấp 3, liềm cấp 2, có xe đạp)
# Tab Tủ đồ, Bếp nhà, Nuôi thêm, Diều, Lờ lọp, Giống lai: chưa chuyển (báo SOON).

const Snap = preload("res://ui/snap.gd")
const Box = preload("res://ui/box.gd")

var U
var G
var T := {}
var on := false
var tab := "nv"
var box: Control = null
var sig := ""
var pad_btn := 21.0          # nút .btn: đệm trái + phải (14px x zoom 0,75)
const TABS := ["nv", "dn", "td", "bep", "nuoi", "dieu", "lo", "lai"]

func _init(ui) -> void:
	U = ui
	G = ui.G
	for k in ["ns_nv", "ns_nv0", "ns_nv2", "ns_dn", "ns_dn2"]:
		T[k] = Snap.load_snap(k)[".pcov"][0]
	var b2: Array = _body(T.ns_nv2).kids
	T.eat_btn = b2[2].kids[0]
	T.eat_row = b2[2]
	var d1: Array = _body(T.ns_dn).kids
	var d2: Array = _body(T.ns_dn2).kids
	T.row_btn = d1[1]            # chưa có: [chữ][nút]
	T.row_got_btn = d1[0]        # đã có, còn nâng được
	T.row_got = d2[0]            # đã có, tối đa / xe đã sắm: không nút
	var bt: Dictionary = Snap.find(d1[1], "btn")
	pad_btn = float(bt.r[2]) - U._tw(bt, String(bt.text))
	T.tre = Snap.find(Snap.load_snap("sp_ok")[".u2pop"][0], "u2tre")
	T.tre_box = Snap.find(Snap.load_snap("sp_ok")[".u2pop"][0], "u2pc")

static func _body(n: Dictionary) -> Dictionary:
	return n.kids[0].kids[2]

# ------------------------------------------------------------------ mở, đóng
func open(t := "") -> void:   # ST
	if t != "":
		tab = t
	U.close_all()
	U.kho_close()
	on = true
	sig = ""
	_draw()

func close() -> void:   # g2
	on = false
	if box != null:
		U.anchors.erase(U._anchor_of(box))
		box.queue_free()
		box = null

func _sig() -> String:
	var f := []
	for r in G.FB:
		f.append(int(G.g.barn.get(r[0], 0)))
	return JSON.stringify([tab, G.lv(), int(G.g.pc.xp), int(G.g.pc.n), int(float(G.g.pc.en)), f, int(G.g.coins), G.mat_n("gach"), G.g.pc.get("tools", {}), G.g.pc.get("xe", 0), G.g.pc.get("xuong", 0), String(G.g.pc.get("name", ""))])

func step() -> void:
	if on and _sig() != sig:
		_draw()

# ------------------------------------------------------------------ chữ
func _txt(n: Dictionary, s: String, x: float, y: float, w: float, h: float) -> void:
	n.text = s
	n.r = [x, y, w, h]
	n.tr = [x, y, w, h]

func _nl(n: Dictionary, s: String, w: float) -> int:
	return U._nlines(s, U._fsz(n), int(n.css.get("font-weight", "400")), w)

# ------------------------------------------------------------------ tab Nhân vật
func _nv(n: Dictionary) -> float:
	var foods := []
	for r in G.FB:   # fB lọc món có trong kho
		if int(G.g.barn.get(r[0], 0)) > 0:
			foods.append(r)
	var src: Dictionary = (T.ns_nv2 if not foods.is_empty() else T.ns_nv0)
	var body := _body(n)
	var sb: Dictionary = _body(src).duplicate(true)
	var dy: float = float(body.r[1]) - float(sb.r[1])
	sb = Snap.moved(sb, Vector2(0, dy))
	var t = G.g.pc
	var grid: Dictionary = sb.kids[0]
	var opts := Snap.find(grid, "pcopts")
	var xp_d: Dictionary = opts.kids[0]
	var en_d: Dictionary = opts.kids[1]
	var need: int = G.xp_need(G.lv())
	var bw: float = float(xp_d.r[2])
	var bi: Dictionary = Snap.find(xp_d, "tbar").kids[0]
	bi.r = [bi.r[0], bi.r[1], bw * clampf(round(float(t.xp) / need * 100.0) / 100.0, 0.0, 1.0), bi.r[3]]
	var xs: Dictionary = xp_d.kids[2]
	_txt(xs, str(int(t.xp)) + "/" + str(need) + " · đã làm " + G.fmt_n(int(t.n)) + " việc", float(xs.r[0]), float(xs.r[1]), float(xs.r[2]), float(xs.r[3]))
	var wl: float = G.en_max()
	var ei: Dictionary = Snap.find(en_d, "tbar").kids[0]
	ei.r = [ei.r[0], ei.r[1], bw * clampf(round(float(t.en) / wl * 100.0) / 100.0, 0.0, 1.0), ei.r[3]]
	var es: Dictionary = en_d.kids[2]
	_txt(es, str(int(floor(float(t.en)))) + "/" + str(int(wl)) + (" · mệt, đi chậm" if float(t.en) < 1.0 else "") + " · tự hồi 4 sức mỗi phút", float(es.r[0]), float(es.r[1]), float(es.r[2]), float(es.r[3]))
	var kids := [grid, sb.kids[1]]
	if not foods.is_empty():
		var row: Dictionary = sb.kids[2]
		var x0: float = float(row.r[0])
		var W: float = float(row.r[2])
		var gap := 4.5
		var k := foods.size()
		var w: float = (W - gap * (k - 1)) / k   # flex: chia đều, không xuống hàng
		var out := []
		for j in k:
			var r: Array = foods[j]
			var b: Dictionary = T.eat_btn.duplicate(true)
			b = Snap.moved(b, Vector2(x0 + j * (w + gap) - float(b.r[0]), float(row.r[1]) - float(b.r[1])))
			b.r = [x0 + j * (w + gap), row.r[1], w, b.r[3]]
			b.act = "eat:" + String(r[0])
			_eat_lbl(b, String(r[2]) + " +" + str(r[1]), "(" + str(int(G.g.barn[r[0]])) + ")")
			out.append(b)
		row.kids = out
		kids.append(row)
	body.kids = kids
	var last: Dictionary = kids[-1]
	return float(last.r[1]) + float(last.r[3]) - float(body.r[1])

func _eat_lbl(b: Dictionary, s: String, cnt: String) -> void:
	# chữ giữa nút xuống dòng như trình duyệt, "(n)" chữ nhỏ nối cuối dòng chót
	var sm: Dictionary = b.kids[0]
	var fs: float = U._fsz(b)
	var fw := int(b.css.get("font-weight", "700"))
	var sfs: float = U._fsz(sm)
	var cw: float = float(b.r[2]) - pad_btn
	var sp: float = Box.text_w(" ", fs, fw)
	var words := s.split(" ")
	var toks := []
	for wd in words:
		toks.append([wd, U._tw(b, wd), false])
	toks.append([cnt, Box.text_w(cnt, sfs, int(sm.css.get("font-weight", "700"))), true])
	var lines := [[]]
	var lw := [0.0]
	for tk in toks:
		var cur: Array = lines[-1]
		var add: float = tk[1] + (sp if not cur.is_empty() else 0.0)
		if not cur.is_empty() and lw[-1] + add > cw:
			lines.append([tk])
			lw.append(tk[1])
		else:
			cur.append(tk)
			lw[-1] += add
	var lh := 12.75
	var y0: float = float(b.r[1]) + (float(b.r[3]) - lh * lines.size()) * 0.5
	var cx: float = float(b.r[0]) + float(b.r[2]) * 0.5
	var kids := []
	for li in lines.size():
		var x: float = cx - lw[li] * 0.5
		var y: float = y0 + li * lh
		var txt := ""
		for tk in lines[li]:
			if tk[2]:
				if txt != "":
					kids.append(_span(b, txt, x, y, lh))
					x += U._tw(b, txt) + sp
					txt = ""
				var q: Dictionary = sm.duplicate(true)
				q.r = [x, y + (lh - float(sm.r[3])) * 0.5 + 1.0, tk[1] + 0.5, sm.r[3]]
				q.tr = q.r.duplicate()
				q.text = tk[0]
				kids.append(q)
			else:
				txt = tk[0] if txt == "" else txt + " " + tk[0]
		if txt != "":
			kids.append(_span(b, txt, x, y, lh))
	b.text = ""
	b.erase("tr")
	b.kids = kids

func _span(b: Dictionary, s: String, x: float, y: float, h: float) -> Dictionary:
	var w: float = U._tw(b, s) + 0.5
	var c: Dictionary = U.khp._plain_css(b.css)
	return {"tag": "span", "id": "", "cls": "", "z": b.get("z", 1.0), "css": c, "kids": [], "text": s, "r": [x, y, w, h], "tr": [x, y, w, h]}

# ------------------------------------------------------------------ tab Đồ nghề, xe
func _row(y: float, title: String, sub: String, got: bool, btn: String, act: String) -> Dictionary:
	var src: Dictionary = (T.row_got if btn == "" else (T.row_got_btn if got else T.row_btn))
	var o: Dictionary = src.duplicate(true)
	o = Snap.moved(o, Vector2(0, y - float(o.r[1])))
	var col: Dictionary = o.kids[0]
	var b: Dictionary = col.kids[0]
	var sm: Dictionary = col.kids[1]
	var X: float = float(o.r[0])
	var W: float = float(o.r[2])
	var bw := 0.0
	var bt := {}
	if btn != "":
		bt = o.kids[1]
		bw = U._tw(bt, btn) + pad_btn
	var cw: float = W - 18.0 - 6.0 - bw if btn != "" else W - 24.0
	var nb := _nl(b, title, cw)
	var ns := _nl(sm, sub, cw)
	var bh := 15.0 + (nb - 1) * 16.9
	var sh := 12.6 * ns
	var cx: float = X + 9.0
	var cy: float = y + 9.0
	_txt(b, title, cx, cy, minf(cw, U._tw(b, title) + 0.5) if nb == 1 else cw, bh)
	_txt(sm, sub, cx, cy + bh + 1.9, cw, sh)
	var ch := bh + 1.9 + sh
	col.r = [cx, cy, cw, ch]
	var rh := ch + 18.0
	o.r = [X, y, W, rh]
	if btn != "":
		var btr: Array = bt.get("tr", bt.r)
		var toy: float = float(btr[1]) - float(bt.r[1])
		var bx: float = X + W - 9.0 - bw
		var by: float = y + (rh - float(bt.r[3])) * 0.5
		bt.r = [bx, by, bw, bt.r[3]]
		bt.text = btn
		var tw: float = U._tw(bt, btn)
		bt.tr = [bx + (bw - tw) * 0.5, by + toy, tw + 0.5, btr[3]]
		bt.act = act
	return o

func _dn(n: Dictionary) -> float:
	var body := _body(n)
	var y: float = float(body.r[1]) + 7.5
	var kids := []
	var t = G.g.pc
	for f in G.TOOLS:
		var s: int = G.fd(f.id)
		var h: Array = G.TOOL_COST[mini(s, 2)]
		var ti: String = String(f.n) + ((" · cấp " + str(s)) if s else "")
		var su: String = G.tool_desc(f.id, s) + ((" → cấp " + str(s + 1) + ": " + G.tool_desc(f.id, s + 1)) if s < 3 else "")
		var bl := ""
		if s < 3:
			bl = ("Nâng" if s else "Sắm") + " · " + G.fmt_n(int(h[0])) + " xu" + ((" + " + str(h[1]) + " gạch") if int(h[1]) else "")
		var r := _row(y, ti, su, s > 0, bl, "tool:" + String(f.id))
		kids.append(r)
		y += float(r.r[3]) + 6.0
	for f in G.RIDES:
		var s2: bool = bool(t.get(f.id, 0))
		var r2 := _row(y, String(f.n), String(f.d) + " · mở ở cấp " + str(f.lv), s2, "" if s2 else G.fmt_n(int(f.xu)) + " xu", "ride:" + String(f.id))
		if not s2 and G.lv() < int(f.lv):
			r2.kids[1].act = ""   # disabled
		kids.append(r2)
		y += float(r2.r[3]) + 6.0
	body.kids = kids
	return y - 6.0 + 4.4 - float(body.r[1])

# ------------------------------------------------------------------ dựng
func _draw() -> void:
	sig = _sig()
	var n: Dictionary = (T.ns_dn if tab == "dn" else T.ns_nv).duplicate(true)
	var bx: Dictionary = n.kids[0]
	var body := _body(n)
	# tiêu đề: "Tên · cấp N" trong viên giữa đầu bảng
	var tt := Snap.find(bx, "tre-tt")
	var nm := String(G.g.pc.get("name", ""))
	var s := (nm if nm != "" else "Bạn") + " · cấp " + str(G.lv())
	var tw: float = U._tw(tt, s)
	var pw: float = float(tt.r[2]) - float(tt.get("tr", tt.r)[2])
	var tcx: float = float(tt.r[0]) + float(tt.r[2]) * 0.5
	var ttr: Array = tt.get("tr", tt.r)
	tt.r = [tcx - (tw + pw) * 0.5, tt.r[1], tw + pw, tt.r[3]]
	tt.tr = [tcx - tw * 0.5, ttr[1], tw + 0.5, ttr[3]]
	tt.text = s
	var H: float = _dn(n) if tab == "dn" else _nv(n)
	# cao hộp theo nội dung, giữa màn (tối đa như web: 610 - 18)
	var top0: float = float(body.r[1]) - float(bx.r[1])
	var bot: float = float(bx.r[1]) + float(bx.r[3]) - float(body.r[1]) - float(body.r[3])
	var bh: float = minf(592.0, top0 + H + bot)
	body.r = [body.r[0], body.r[1], body.r[2], bh - top0 - bot]
	var ny: float = (float(n.r[3]) - bh) * 0.5
	var d: float = ny - float(bx.r[1])
	var nb: Dictionary = Snap.moved(bx, Vector2(0, d))
	nb.r = [bx.r[0], ny, bx.r[2], bh]
	# khung tre (giống hộp .u2pop: thanh trên/dưới/trái/phải + 4 góc)
	nb.kids.append(_tre(float(nb.r[0]), ny, float(nb.r[2]), bh))
	n.kids = [nb]
	if box != null:
		U.anchors.erase(U._anchor_of(box))
		box.queue_free()
		box = null
	var ids := {}
	box = U.khp._show(n, "rbox", ids, close)
	U._click(ids.get(".tre-x"), close, "scale")
	var tb = ids.get(".tre-ts")
	if tb != null:
		var bs: Array = U._buttons(tb, [])
		for j in bs.size():
			var tk: String = TABS[j] if j < TABS.size() else ""
			U._click(bs[j], func(): _tab(tk), "down")
	if tb != null:
		tb._kids.clip_contents = true   # .tre-ts cuộn ngang: tab dư bị che
	_hook(box)
	U._layout()

func _tre(x: float, y: float, w: float, h: float) -> Dictionary:
	var src: Dictionary = T.tre
	var o: Dictionary = src.duplicate(true)
	var r0: Array = T.tre_box.r
	var sx: float = x - float(r0[0])
	var sy: float = y - float(r0[1])
	o.r = [x, y, w, h]
	for k in o.kids:
		var c := String(k.cls)
		var kr: Array = k.r
		if c == "t":
			k.r = [x + 24.0, y - 6.0, w - 48.0, kr[3]]
		elif c == "b":
			k.r = [x + 24.0, y + h - 4.0, w - 48.0, kr[3]]
		elif c == "l":
			k.r = [x - 6.0, y + 24.0, kr[2], h - 48.0]
		elif c == "r":
			k.r = [x + w - 3.0, y + 24.0, kr[2], h - 48.0]
		elif c.find("c1") >= 0:
			k.r = [x - 6.0, y - 6.0, kr[2], kr[3]]
		elif c.find("c2") >= 0:
			k.r = [x + w - 24.0, y - 6.0, kr[2], kr[3]]
		elif c.find("c3") >= 0:
			k.r = [x - 6.0, y + h - 25.0, kr[2], kr[3]]
		elif c.find("c4") >= 0:
			k.r = [x + w - 24.0, y + h - 25.0, kr[2], kr[3]]
		else:
			Snap._move(k, Vector2(sx, sy))
	return o

func _tab(tk: String) -> void:
	if tk == "nv" or tk == "dn":
		tab = tk
		sig = ""
		_draw()
	else:
		U.say(U.SOON)

func _hook(b: Control) -> void:
	for k in b.kids():
		var n: Dictionary = k.get_meta("snap", {})
		var a := String(n.get("act", ""))
		var lb := String(n.get("text", ""))
		if a != "":
			U._click(k, func(): _do(a), "down")
		elif n.get("tag", "") == "button" and lb == "Về nhà ngủ":
			U._click(k, func():
				close()
				U.F.sleep_go(), "down")
		elif n.get("tag", "") == "button" and lb == "Đổi dáng, tên":
			U._click(k, func(): U.say(U.SOON), "down")
		_hook(k)

func _do(a: String) -> void:
	var p := a.split(":")
	match p[0]:
		"eat": G.eat(p[1])
		"tool": G.tool_up(p[1])
		"ride": G.ride_buy(p[1])
	sig = ""
	_draw()
