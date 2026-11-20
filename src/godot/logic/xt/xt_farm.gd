extends Control
# XẾP TRÁI: nông trại (08c_farm.js) — kho, ghe hàng chợ nổi, chuồng thú; trả công mỗi màn.

const A := preload("res://logic/xt/xt_art.gd")
const D := preload("res://logic/xt/xt_data.gd")
const UIS := preload("res://logic/xt/xt_ui.gd")
const MUC := Color("#2b2118")
const MUC2 := Color("#5a4630")
const LH := 1.56

var game
var tab := "kho"
var is_open := false
var pan    # khung ngoài (nền tối, ruy băng, nút đóng, thẻ)
var body   # phần cuộn
var _pr := Rect2()
var _br := Rect2()
var _flash := {}
var eat = null
var _t := 0.0
var _content_h := 0.0

func _init(gm) -> void:
	game = gm
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pan = UIS.Box.new(_draw_pan)
	pan.full = true
	pan.on_bg = func():
		hide_farm()
	add_child(pan)
	body = UIS.Box.new(_draw_body)
	body.full = true
	body.clip_contents = true
	add_child(body)

# ============================================================ kho
func kho(k) -> int:
	return int(game.save.kho.get(str(k), 0))

func add_kho(o: Dictionary, sign := 1) -> void:
	for k in o:
		game.save.kho[str(k)] = maxi(0, kho(k) + int(o[k]) * sign)

func has_kho(o: Dictionary) -> bool:
	for k in o:
		if kho(k) < int(o[k]):
			return false
	return true

func level_pay(i: int, stars: int, first: bool) -> Dictionary:
	var xu := int(round((24 + i * 3 + stars * 8) * (1.0 if first else 0.4)))
	var cam := (1 + (1 if stars >= 3 else 0)) if first else (1 if stars >= 3 else 0)
	return {"xu": xu, "cam": cam}

func merchant(i: int) -> String:
	return "Ghe " + D.MERCH[(i * 3) % D.MERCH.size()]

func bank() -> Dictionary:
	var h: Dictionary = game.B.haul
	add_kho(h)
	game.B.haul = {}
	game.persist()
	return h

func haul_any(h: Dictionary) -> bool:
	for k in h:
		if int(h[k]) > 0:
			return true
	return false

# ============================================================ đơn ghe chợ nổi
func make_order(seed: int) -> Dictionary:
	var R := D.SRand.new((seed * 2654435761) & 0xffffffff)
	var cur: int = game.cur_level()
	var ch := 2 if cur >= 20 else (1 if cur >= 10 else 0)
	var kinds := 6 if cur >= 4 else 5
	var want := {}
	R.r()
	R.r()
	R.r()
	var lines := 1 + (1 if R.r() < 0.55 else 0)
	if ch > 0 and R.r() < 0.4:
		lines += 1
	var pool := [0, 1, 2, 3, 4, 5].slice(0, kinds)
	for i in lines:
		var j := int(floor(R.r() * pool.size()))
		var k: int = pool[j]
		pool.remove_at(j)
		want[str(k)] = int(round((10 + R.r() * 16) * (1 + ch * 0.35) / 2)) * 2
	# khoá số đứng trước như object của JS
	var ks := want.keys()
	ks.sort_custom(func(a, b): return int(a) < int(b))
	var w2 := {}
	for k in ks:
		w2[k] = want[k]
	if ch >= 1 and R.r() < 0.45:
		w2["rom"] = 6 + int(round(R.r() * 6))
	if ch >= 1 and R.r() < 0.25:
		w2["trung"] = 1 + int(floor(R.r() * 2))
	var val := 0
	for k in w2:
		val += int(w2[k]) * int(D.ITEMS[k].p)
	return {"id": seed, "who": D.MERCH[int(floor(R.r() * D.MERCH.size()))], "want": w2, "xu": int(round(val * 1.35 / 5)) * 5, "cam": 2 if val > 60 else 1}

func orders() -> Array:
	var sv: Dictionary = game.save
	while sv.orders.size() < 3:
		sv.nextOrder = int(sv.get("nextOrder", 101)) + 7
		sv.orders.append(make_order(sv.nextOrder))
	return sv.orders

static func want_keys(w: Dictionary) -> Array:
	var ks := w.keys()
	ks.sort_custom(func(a, b):
		var ai := str(a).is_valid_int()
		var bi := str(b).is_valid_int()
		if ai and bi:
			return int(a) < int(b)
		if ai != bi:
			return ai
		return ["rom", "trung", "cam"].find(str(a)) < ["rom", "trung", "cam"].find(str(b)))
	return ks

func deliver(i: int) -> bool:
	var os := orders()
	if i >= os.size():
		return false
	var o: Dictionary = os[i]
	if not has_kho(o.want):
		return false
	add_kho(o.want, -1)
	game.save.xu = int(game.save.xu) + int(o.xu)
	add_kho({"cam": int(o.cam)})
	os.remove_at(i)
	game.persist()
	return true

func skip(i: int) -> void:
	game.save.orders.remove_at(i)
	game.persist()

# ============================================================ cho thú ăn
func pet(k: String) -> Dictionary:
	if not game.save.pets.has(k):
		game.save.pets[k] = {"lv": 1, "xp": 0}
	var p: Dictionary = game.save.pets[k]
	p.lv = int(p.lv)
	p.xp = int(p.xp)
	return p

func need(p: Dictionary) -> int:
	return 0 if p.lv >= 3 else int(D.FEEDS[p.lv - 1])

func feed(P: Dictionary) -> int:
	var p := pet(P.k)
	if p.lv >= 3 or not has_kho(P.eat):
		return 0
	add_kho(P.eat, -1)
	p.xp += 1
	var up := 0
	if p.xp >= need(p):
		p.lv += 1
		p.xp = 0
		up = 1
	game.persist()
	return 2 if up else 1

# ============================================================ màn hình
func show_tab(t := "") -> void:
	if t != "":
		tab = t
	is_open = true
	orders()
	visible = true
	body.scroll = 0.0
	relayout()

func hide_farm() -> void:
	if not is_open:
		return
	is_open = false
	visible = false

func relayout() -> void:
	if not is_open:
		return
	var L: Dictionary = game.LAY
	var pw := minf(560.0 if L.W < 640 else 780.0, L.W - 32)
	var bw := pw - 32 - 4
	_content_h = _body_h(bw)
	var head := 22.0 + 25 + 10 + 28 + 10 + 41 + 10
	var ph := minf(head + _content_h + 4 + 16, L.H - 32)
	_pr = Rect2((L.W - pw) / 2, (L.H - ph) / 2, pw, ph)
	_br = Rect2(_pr.position.x + 18, _pr.position.y + head + 2, bw, ph - head - 16 - 4)
	body.position = _br.position
	body.size = _br.size
	body.scroll_r = Rect2(Vector2.ZERO, _br.size)
	body.max_scroll = maxf(0, _content_h - _br.size.y)
	body.scroll = clampf(body.scroll, 0, body.max_scroll)
	pan.size = Vector2(L.W, L.H)

func tick(dt: float) -> void:
	if not is_open:
		return
	_t += dt
	if eat != null:
		eat.t += dt
		if eat.t > 1.4:
			eat = null
	for k in _flash.keys():
		_flash[k] += dt
		if _flash[k] > 0.6:
			_flash.erase(k)
	pan.queue_redraw()
	body.queue_redraw()

func _flash_xf(id: String, c: Vector2, dur := 0.5) -> Transform2D:
	var t: float = _flash.get(id, -1.0)
	if t < 0 or t > dur:
		return Transform2D.IDENTITY
	var k := t / dur
	var s := 1 + 0.12 * (k / 0.4 if k < 0.4 else (1 - k) / 0.6)
	return Transform2D(0, Vector2(s, s), 0, c) * Transform2D(0, -c)

func _note_ghe() -> bool:
	for o in orders():
		if has_kho(o.want):
			return true
	return false

func _note_pet() -> bool:
	for P in D.PETS:
		if pet(P.k).lv < 3 and has_kho(P.eat):
			return true
	return false

func _draw_pan(ci) -> void:
	var L: Dictionary = game.LAY
	ci.items = []
	ci.draw_rect(Rect2(0, 0, L.W, L.H), Color(30 / 255.0, 22 / 255.0, 10 / 255.0, 0.42))
	var r := _pr
	ci.items.append({"r": r, "id": "panel", "tap": func(): pass})
	A.box(ci, r, A.GACH, 22, 0, Color(), [[0, 10, 30, Color(40 / 255.0, 25 / 255.0, 10 / 255.0, 0.35)]])
	A.box(ci, r.grow(-2.5), A.KEM, 19.5)
	UIS.khan(ci, Rect2(r.position.x + 16, r.position.y + 2.5, r.size.x - 32, 10), 5, Color("#f6f1e4"), 0.92)
	var x := r.position.x + 16
	var iw := r.size.x - 32
	var y := r.position.y + 22
	# ruy băng
	var t := ("Vựa trái nhà mình" if game.embed else "Nông trại nhà mình").to_upper()
	var tw := A.tw(t, 15, 800) + 24 + t.length() * 0.9
	var rr := Rect2(x + iw / 2 - tw / 2, y, tw, 25)
	A.box(ci, rr, A.GACH, 12)
	A.text(ci, t, rr.get_center().x, rr.get_center().y + 1, 15, A.CREAM_TXT, 1, 800)
	# nút đóng
	var cr := Rect2(r.end.x - 10 - 36, r.position.y + 16, 36, 36)
	var dn: bool = ci.pressed("close")
	A.box(ci, cr, A.GACH, 18)
	A.box(ci, cr.grow(-2.5), Color("#efe3c8") if dn else A.KEM, 15.5)
	var cc := cr.get_center()
	for s in [-1.0, 1.0]:
		ci.draw_line(cc + Vector2(-5.5, -5.5 * s), cc + Vector2(5.5, 5.5 * s), A.GACH_DK, 3.2, true)
	ci.items.append({"r": cr, "id": "close", "tap": func():
		game.snd.play("tap")
		hide_farm()})
	y += 25 + 10
	# ví xu
	var xs = game.ui._num(int(game.save.xu))
	var ww := 24 + 4 + A.tw(xs, 18, 800) + A.tw(" xu", 18, 800)
	var wc := Vector2(x + iw / 2, y + 14)
	ci.draw_set_transform_matrix(_flash_xf("wallet", wc))
	ci.draw_texture_rect(A.img("i_xu"), Rect2(wc.x - ww / 2, wc.y - 12, 24, 24), false)
	A.text(ci, xs + " xu", wc.x - ww / 2 + 28, wc.y + 1, 18, MUC, 0, 800, 0, MUC, _flash_xf("wallet", wc))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	y += 28 + 10
	# thẻ
	var tr := Rect2(x, y, iw, 41)
	A.box(ci, tr, A.KEM2, 20.5)
	var tabs := [["kho", "Kho"], ["ghe", "Ghe hàng"], ["chuong", "Chuồng thú"]]
	var bw := (iw - 6 - 6) / 3
	for i in 3:
		var b := Rect2(x + 3 + i * (bw + 3), y + 3, bw, 35)
		var on: bool = tabs[i][0] == tab
		if on:
			A.box(ci, Rect2(b.position + Vector2(0, 2), b.size), A.GACH_DK, 17.5)
			A.box(ci, b, A.GACH, 17.5)
		A.text(ci, tabs[i][1], b.get_center().x, b.get_center().y + 1, 16, A.CREAM_TXT if on else MUC2, 1, 800)
		var note: bool = (tabs[i][0] == "ghe" and _note_ghe()) or (tabs[i][0] == "chuong" and _note_pet())
		if note:
			var c := Vector2(b.end.x + 3 - 6, b.position.y - 4 + 6)
			ci.draw_circle(c, 8, A.KEM, true, -1, true)
			ci.draw_circle(c, 6, A.DO, true, -1, true)
		var id: String = tabs[i][0]
		ci.items.append({"r": b, "id": "t_" + id, "tap": func():
			game.snd.play("tap")
			tab = id
			body.scroll = 0.0
			relayout()})

# ---------- phần thân (cuộn được)
func _fnote_lines(txt: String, w: float) -> Array:
	# text-wrap: balance
	var lines := A.wrap(txt, 14.5, 600, w)
	var n := lines.size()
	if n <= 1:
		return lines
	var lo := 40.0
	var hi := w
	for _i in 12:
		var mid := (lo + hi) / 2
		if A.wrap(txt, 14.5, 600, mid).size() > n:
			lo = mid
		else:
			hi = mid
	return A.wrap(txt, 14.5, 600, hi)

const NOTE_GHE := "Ghe ghé bến mua trái trong kho. Giao đủ hàng là được trả xu với cám."
const NOTE_PET := "Thú ăn no thì lên cấp, phụ ráp trái mạnh hơn."
const KHO_KEYS := ["0", "1", "2", "3", "4", "5", "rom", "trung", "cam"]

func _cols(n_small: int, n_big: int) -> int:
	return n_big if game.LAY.W >= 640 else n_small

func _body_h(bw: float) -> float:
	if tab == "kho":
		var c := _cols(3, 5)
		var rows := int(ceil(KHO_KEYS.size() / float(c)))
		var c2 := _cols(2, 3)
		var r2 := int(ceil(D.SHOP.size() / float(c2)))
		return rows * 87.0 + (rows - 1) * 6 + 10 + 4 + 17 * LH + 10 + r2 * 44.0 + (r2 - 1) * 6
	elif tab == "ghe":
		var nl := _fnote_lines(NOTE_GHE, bw).size()
		var n := orders().size()
		return nl * 14.5 * 1.3 + 10 + n * 136.0 + (n - 1) * 8
	var nl2 := _fnote_lines(NOTE_PET, bw).size()
	var c3 := _cols(2, 4)
	var rr := int(ceil(D.PETS.size() / float(c3)))
	return nl2 * 14.5 * 1.3 + 10 + rr * 227.0 + (rr - 1) * 8

func _draw_body(ci) -> void:
	ci.items = []
	var bw := _br.size.x
	var y = -ci.scroll
	if tab == "kho":
		_draw_kho(ci, bw, y)
	elif tab == "ghe":
		_draw_ghe(ci, bw, y)
	else:
		_draw_chuong(ci, bw, y)

func _it(ci, r: Rect2, id: String, fn: Callable, off := false) -> void:
	var rr := r
	rr.position.y += ci.scroll
	ci.items.append({"r": rr, "id": id, "tap": fn, "sc": true, "off": off})

func _draw_kho(ci, bw: float, y0: float) -> void:
	var c := _cols(3, 5)
	var cw := (bw - (c - 1) * 6) / c
	for i in KHO_KEYS.size():
		var k: String = KHO_KEYS[i]
		var r := Rect2((i % c) * (cw + 6), y0 + (i / c) * 93, cw, 87)
		var n := kho(k)
		var al := 1.0 if n > 0 else 0.55
		A.box(ci, r, Color(A.KEM2, al), 14)
		var cx := r.get_center().x
		ci.draw_texture_rect(UIS.icon_tex(k), Rect2(cx - 22, r.position.y + 4, 44, 44), false, Color(1, 1, 1, al))
		A.text(ci, game.ui._num(n), cx, r.position.y + 48 + 10, 19, Color(MUC, al), 1, 800)
		A.text(ci, D.ITEMS[k].n, cx, r.position.y + 68 + 6.5, 12.5, Color(MUC2, al), 1, 700)
	var rows := int(ceil(KHO_KEYS.size() / float(c)))
	var y := y0 + rows * 87.0 + (rows - 1) * 6 + 10 + 4
	A.text(ci, "Tiệm tạp hóa", 2, y + 17 * LH / 2, 17, A.GACH_DK, 0, 800)
	y += 17 * LH + 10
	var c2 := _cols(2, 3)
	var cw2 := (bw - (c2 - 1) * 6) / c2
	for i in D.SHOP.size():
		var s: Dictionary = D.SHOP[i]
		var r := Rect2((i % c2) * (cw2 + 6), y + (i / c2) * 50, cw2, 44)
		var dis: bool = int(game.save.xu) < int(s.cost)
		var dn: bool = ci.pressed("s%d" % i) and not dis
		var id := "s%d" % i
		ci.draw_set_transform_matrix(_flash_xf(id, r.get_center()))
		var al := 0.5 if dis else 1.0
		if not dis:
			A.box(ci, Rect2(r.position + Vector2(0, 3 if not dn else 1), r.size), A.LIP_KEM, 14, 0, Color(), [], _flash_xf(id, r.get_center()))
		var rr := Rect2(r.position + Vector2(0, 2 if dn else 0), r.size)
		ci.draw_set_transform_matrix(_flash_xf(id, r.get_center()))
		A.box(ci, rr, Color(A.KEM2, al) if not dis else Color(A.KEM2.lerp(Color("#d6c59f"), 0.0), al), 14, 0, Color(), [], _flash_xf(id, r.get_center()))
		ci.draw_set_transform_matrix(_flash_xf(id, r.get_center()))
		var cy := rr.get_center().y
		ci.draw_texture_rect(UIS.icon_tex(s.k), Rect2(rr.position.x + 4, cy - 18, 36, 36), false, Color(1, 1, 1, al))
		var tx := rr.position.x + 4 + 36 + 6
		var xf := _flash_xf(id, r.get_center())
		if s.has("boost"):
			A.text(ci, s.n, tx, cy - 14.3 + 8, 14.5, Color(MUC, al), 0, 700, 0, MUC, xf)
			A.text(ci, "đang có %d" % int(game.save.boost.get(s.boost, 0)), tx, cy - 14.3 + 16 + 6.3, 11.5, Color(MUC2, al), 0, 600, 0, MUC, xf)
		else:
			A.text(ci, s.n, tx, cy, 14.5, Color(MUC, al), 0, 700, 0, MUC, xf)
		var cs := str(s.cost)
		var cwid := A.tw(cs, 15, 800)
		var bx := rr.end.x - 10 - cwid
		A.text(ci, cs, bx, cy + 0.5, 15, Color(MUC, al), 0, 800, 0, MUC, xf)
		ci.draw_set_transform_matrix(xf)
		ci.draw_texture_rect(A.img("i_xu"), Rect2(bx - 1 - 18, cy - 9, 18, 18), false, Color(1, 1, 1, al))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		var idx := i
		_it(ci, r, id, func(): _buy(idx), dis)

func _buy(i: int) -> void:
	var s: Dictionary = D.SHOP[i]
	if int(game.save.xu) < int(s.cost):
		game.snd.play("bad")
		return
	game.save.xu = int(game.save.xu) - int(s.cost)
	if s.has("give"):
		add_kho(s.give)
	if s.has("boost"):
		game.save.boost[s.boost] = int(game.save.boost.get(s.boost, 0)) + 1
	game.persist()
	game.snd.play("coin")
	_flash["s%d" % i] = 0.0

func _draw_note(ci, txt: String, bw: float, y: float) -> float:
	var lines := _fnote_lines(txt, bw)
	var lh := 14.5 * 1.3
	for i in lines.size():
		A.text(ci, lines[i], bw / 2, y + lh * i + lh / 2, 14.5, MUC2, 1, 600)
	return lines.size() * lh

func _draw_ghe(ci, bw: float, y0: float) -> void:
	var y := y0 + _draw_note(ci, NOTE_GHE, bw, y0) + 10
	var os := orders()
	for i in os.size():
		var o: Dictionary = os[i]
		var ok := has_kho(o.want)
		var r := Rect2(0, y, bw, 136)
		if ok:
			A.box(ci, r, A.LA, 16)
			A.box(ci, r.grow(-2), A.KEM2, 14)
		else:
			A.box(ci, r, A.KEM2, 16)
		var x0 := r.position.x + 12
		var yy := r.position.y + 10
		var iw := bw - 24
		ci.draw_texture_rect(A.img("boaticon"), Rect2(x0, yy, 72, 43), false)
		A.text(ci, "Ghe " + str(o.who), x0 + 78, yy + 6 + 8.9, 17, MUC, 0, 800)
		A.text(ci, "cần mua", x0 + 78, yy + 6 + 17.85 + 6.6, 12.5, MUC2, 0, 700)
		# trả
		var px := x0 + iw
		var pcy := yy + 21.5
		var cam := str(int(o.cam))
		var xu := str(int(o.xu))
		px -= A.tw(cam, 16, 800) + 4
		A.text(ci, cam, px, pcy + 0.5, 16, MUC, 0, 800)
		px -= 2 + 20
		ci.draw_texture_rect(A.img("i_cam"), Rect2(px, pcy - 10, 20, 20), false)
		px -= 2 + 4 + A.tw(xu, 16, 800)
		A.text(ci, xu, px, pcy + 0.5, 16, MUC, 0, 800)
		px -= 2 + 20
		ci.draw_texture_rect(A.img("i_xu"), Rect2(px, pcy - 10, 20, 20), false)
		px -= 2 + A.tw("Trả", 14, 700)
		A.text(ci, "Trả", px, pcy + 0.5, 14, MUC2, 0, 700)
		# cần
		var wx := x0
		var wy := yy + 43 + 4 + 15
		for k in want_keys(o.want):
			var nd := int(o.want[k])
			var have := kho(k) >= nd
			var s := "%d/%d" % [mini(kho(k), nd), nd]
			ci.draw_texture_rect(UIS.icon_tex(str(k)), Rect2(wx, wy - 15, 30, 30), false)
			A.text(ci, s, wx + 30, wy + 0.5, 15, A.LA if have else A.DO, 0, 800)
			wx += 30 + A.tw(s, 15, 800) + 12
		# nút
		var by := yy + 43 + 4 + 30 + 4
		var fs := 16.0
		var b2 = game.ui.btn_rect("Giao hàng", 0, by, fs, 1.1, 0.3)
		b2.position.x = x0 + iw - b2.size.x
		var b1 = game.ui.btn_rect("Đổi đơn", 0, by, fs, 1.1, 0.3)
		b1.position.x = b2.position.x - 8 - b1.size.x
		game.ui.btn(ci, b1, "Đổi đơn", "kem", fs, ci.pressed("k%d" % i))
		game.ui.btn(ci, b2, "Giao hàng", "la", fs, ci.pressed("g%d" % i), not ok)
		var idx := i
		_it(ci, b1, "k%d" % i, func():
			game.snd.play("tap")
			skip(idx)
			relayout())
		_it(ci, b2, "g%d" % i, func():
			if not deliver(idx):
				game.snd.play("bad")
				return
			game.snd.play("win")
			_flash["wallet"] = 0.0
			relayout(), not ok)
		y += 136 + 8

func _draw_chuong(ci, bw: float, y0: float) -> void:
	var y := y0 + _draw_note(ci, NOTE_PET, bw, y0) + 10
	var c := _cols(2, 4)
	var cw := (bw - (c - 1) * 8) / c
	for i in D.PETS.size():
		var P: Dictionary = D.PETS[i]
		var p := pet(P.k)
		var nd := need(p)
		var ok: bool = p.lv < 3 and has_kho(P.eat)
		var r := Rect2((i % c) * (cw + 8), y + (i / c) * 235, cw, 227)
		var id := "p" + str(P.k)
		ci.draw_set_transform_matrix(_flash_xf(id, r.get_center(), 0.6))
		A.box(ci, r, A.KEM2, 16, 0, Color(), [], _flash_xf(id, r.get_center(), 0.6))
		var xf := _flash_xf(id, r.get_center(), 0.6)
		var cx := r.get_center().x
		var py := r.position.y + 6
		_draw_pet(ci, P.k, Rect2(cx - 48, py, 96, 90), xf)
		var ty := py + 90 + 4
		A.text(ci, P.n, cx, ty + 9.8, 17, MUC, 1, 800, 0, MUC, xf)
		ty += 19.55 + 1
		ci.draw_set_transform_matrix(xf)
		for l in 3:
			var dc := Vector2(cx - 20 + l * 20, ty + 9)
			var on: bool = l + 1 <= p.lv
			ci.draw_circle(dc, 9, A.VANG_DK if on else Color("#b8a888"), true, -1, true)
			ci.draw_circle(dc, 7, A.VANG if on else Color("#d8ccb2"), true, -1, true)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		ty += 18 + 1
		var a := str(P.sp) + ": "
		var b: String = P.lv[p.lv - 1]
		var tw := A.tw(a, 12.5, 600) + A.tw(b, 12.5, 800)
		A.text(ci, a, cx - tw / 2, ty + 7.2, 12.5, MUC2, 0, 600, 0, MUC, xf)
		A.text(ci, b, cx - tw / 2 + A.tw(a, 12.5, 600), ty + 7.2, 12.5, A.GACH_DK, 0, 800, 0, MUC, xf)
		ty += 14.4 + 1
		if p.lv < 3:
			A.text(ci, "Cấp %d: %s" % [p.lv + 1, P.lv[p.lv]], cx, ty + 7.2, 12.5, A.LA, 1, 700, 0, MUC, xf)
			ty += 14.4 + 1 + 2
			var br := Rect2(r.position.x + 8, ty, cw - 16, 16)
			ci.draw_set_transform_matrix(xf)
			A.box(ci, br, Color("#e2d2ac"), 8, 0, Color(), [], xf)
			if p.xp > 0:
				A.box(ci, Rect2(br.position, Vector2(br.size.x * p.xp / float(nd), 16)), A.LA, 8, 0, Color(), [], xf)
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
			A.text(ci, "%d/%d bữa" % [p.xp, nd], cx, ty + 8.5, 11.5, MUC, 1, 800, 0, MUC, xf)
			ty += 16 + 4
			# nút cho ăn
			var parts := []
			var fw := 0.0
			for k in P.eat:
				var s := str(int(P.eat[k]))
				parts.append([str(k), s, kho(k) >= int(P.eat[k])])
				fw += 18 + A.tw(s, 13, 800)
			fw += (parts.size() - 1) * 4 + 12
			var lw := A.tw("Cho ăn", 14, 800)
			var bwid := 10 + lw + 5 + fw + 4
			var fr := Rect2(cx - bwid / 2, ty, bwid, 26)
			var dn: bool = ci.pressed("f%d" % i) and ok
			ci.draw_set_transform_matrix(xf)
			if ok:
				A.box(ci, Rect2(fr.position + Vector2(0, 1 if dn else 3), fr.size), A.LA_DK, 13, 0, Color(), [], xf)
			var fr2 := Rect2(fr.position + Vector2(0, 2 if dn else 0), fr.size)
			A.box(ci, fr2, A.LA if ok else Color("#b8ad94"), 13, 0, Color(), [], xf)
			var pr := Rect2(fr2.position.x + 10 + lw + 5, fr2.position.y + 3, fw, fr2.size.y - 5)
			A.box(ci, pr, Color(A.KEM, 0.92), pr.size.y / 2, 0, Color(), [], xf)
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
			A.text(ci, "Cho ăn", fr2.position.x + 10, fr2.get_center().y + 1, 14, Color("#fff8e6"), 0, 800, 0, MUC, xf)
			var ix := pr.position.x + 6
			for pt in parts:
				ci.draw_set_transform_matrix(xf)
				ci.draw_texture_rect(UIS.icon_tex(pt[0]), Rect2(ix, pr.get_center().y - 9, 18, 18), false)
				ci.draw_set_transform_matrix(Transform2D.IDENTITY)
				ix += 18
				A.text(ci, pt[1], ix, pr.get_center().y + 0.5, 13, MUC if pt[2] else A.DO, 0, 800, 0, MUC, xf)
				ix += A.tw(pt[1], 13, 800) + 4
			var idx := i
			_it(ci, fr, "f%d" % i, func(): _feed(idx), not ok)
		else:
			A.text(ci, "Cấp cao nhất rồi", cx, ty + 7.2, 12.5, A.GACH, 1, 700, 0, MUC, xf)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)

func _feed(i: int) -> void:
	var P: Dictionary = D.PETS[i]
	var r := feed(P)
	if r == 0:
		game.snd.play("bad")
		return
	game.snd.play("win" if r == 2 else ("ga" if P.k == "trong" else P.k))
	eat = {"k": P.k, "t": 0.0, "up": r == 2}
	if r == 2:
		_flash["p" + str(P.k)] = 0.0
	relayout()

func _heart(ci: CanvasItem, x: float, y: float, s: float, col: Color) -> void:
	var pts := A.cubic_pts(Vector2(x, y + s * 0.9), Vector2(x - s * 1.4, y), Vector2(x - s * 0.7, y - s), Vector2(x, y - s * 0.3), 10)
	pts.append_array(A.cubic_pts(Vector2(x, y - s * 0.3), Vector2(x + s * 0.7, y - s), Vector2(x + s * 1.4, y), Vector2(x, y + s * 0.9), 10).slice(1, 10))
	ci.draw_colored_polygon(pts, col)

# thú đứng trên bãi cỏ; khung chạy khi đang mở, nhảy lên khi được ăn
func _draw_pet(ci: CanvasItem, k: String, r: Rect2, xf: Transform2D) -> void:
	var sc := r.size.x / 160.0
	var W := 160.0
	var H := 150.0
	ci.draw_set_transform_matrix(xf * Transform2D(0, Vector2(sc, sc), 0, r.position))
	A.ell(ci, Vector2(W / 2, H * 0.8), W * 0.42, H * 0.14, Color("#a9cf6a"))
	A.ell(ci, Vector2(W / 2, H * 0.8), W * 0.26, H * 0.06, Color(60 / 255.0, 90 / 255.0, 30 / 255.0, 0.25))
	var e = eat if eat != null and eat.k == k else null
	var hop := 0.0
	if e != null:
		hop = absf(sin(e.t * 9)) * H * 0.12 * maxf(0, 1 - e.t / 1.2)
	var fr := int(floor(_t * 6))
	var hh := H * (0.66 if k == "trau" else (0.78 if k == "trong" else 0.62))
	A.anim_t(ci, k, "idle", "6", fr, xf * Transform2D(0, Vector2(sc, sc), 0, r.position) * Transform2D(0, Vector2(W / 2, H * 0.8 - hop)), hh, false)
	if e != null and e.t < 1.2:
		ci.draw_set_transform_matrix(xf * Transform2D(0, Vector2(sc, sc), 0, r.position))
		var col := Color(210 / 255.0, 69 / 255.0, 47 / 255.0, 1 - e.t / 1.2)
		for i in (5 if e.up else 2):
			var a := -1.2 + i * 0.6
			var rr = H * (0.36 + e.t * 0.3)
			_heart(ci, W / 2 + cos(a) * rr * 0.8, H * 0.42 - sin(1.2 + a * 0.3) * rr * 0.5, H * 0.06, col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
