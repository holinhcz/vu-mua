extends Control
# CÂU CÁ BỜ KÊNH: giao diện (09_ui.js + CSS của shell.html), vẽ tay bằng Godot, đo theo css px của web:
# thanh trên (xu, cấp, đồng hồ, cài đặt), mồi đang móc, Giỏ cá / Chợ / Sổ cá, nút nón lá Quăng / Chờ / Giật / Giữ
# có vòng căng dây, khung đồng hồ khi kéo cá, lời báo, chữ to giữa màn, lời nhắc, viền đỏ,
# hộp thoại (giỏ, chợ mồi + đổi đồ, sổ cá, cài đặt), thẻ cá câu được, màn đầu, lên cấp, xu bay.

const A := preload("res://logic/cc/cc_art.gd")
const D := preload("res://logic/cc/cc_data.gd")
const Tre := preload("res://logic/cc/cc_tre.gd")

# ------------------------------------------------------------ một khối vẽ + bấm (thay phần tử DOM)
class Box extends Control:
	var fn: Callable
	var items: Array = []
	var press = null
	var full := false
	var area := false   # nhận chạm trên CẢ khung của nó (khung cuộn): kéo ở chỗ trống giữa các nút cũng cuộn được
	var on_bg: Callable
	var scroll := 0.0
	var max_scroll := 0.0
	var _drag := false
	var _y0 := 0.0
	var _s0 := 0.0
	var _moved := false
	func _init(f: Callable = Callable()) -> void:
		fn = f
		mouse_filter = Control.MOUSE_FILTER_STOP
	static var T := {}
	func _draw() -> void:
		A.begin(self)   # ô vẽ bằng bộ vẽ Nông trại = canvas item con: xoá lượt trước
		if fn.is_valid():
			var t0 := Time.get_ticks_usec()
			fn.call(self)
			var k := fn.get_method()
			T[k] = T.get(k, 0) + Time.get_ticks_usec() - t0
	func hit(p: Vector2):
		for i in range(items.size() - 1, -1, -1):
			var it: Dictionary = items[i]
			if it.get("off", false):
				continue
			var r: Rect2 = it.r
			if it.get("sc", false):
				r.position.y -= scroll
			if r.grow(3).has_point(p):
				return it
		return null
	func _has_point(p: Vector2) -> bool:
		if not visible:
			return false
		if full:
			return true
		if area:
			return Rect2(Vector2.ZERO, size).has_point(p)
		return hit(p) != null
	func _gui_input(e: InputEvent) -> void:
		var pos := Vector2.ZERO
		var kind := ""
		if e is InputEventScreenTouch:
			if e.index != 0:
				return
			pos = e.position
			kind = "down" if e.pressed else "up"
		elif e is InputEventScreenDrag:
			if e.index != 0:
				return
			pos = e.position
			kind = "move"
		elif e is InputEventMouseButton:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if max_scroll > 0 and e.pressed:
					scroll = clampf(scroll + (-40.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 40.0), 0, max_scroll)
					queue_redraw()
				accept_event()
				return
			if e.button_index != MOUSE_BUTTON_LEFT:
				return
			pos = e.position
			kind = "down" if e.pressed else "up"
		elif e is InputEventMouseMotion:
			if press == null and not _drag:
				return
			pos = e.position
			kind = "move"
		else:
			return
		accept_event()
		if kind == "down":
			press = hit(pos)
			_drag = false
			_y0 = pos.y
			_s0 = scroll
			if press != null and press.has("down") and press.down.is_valid():
				press.down.call()
			queue_redraw()
		elif kind == "move":
			if max_scroll > 0 and absf(pos.y - _y0) > 8:
				_drag = true
				press = null
			if _drag:
				scroll = clampf(_s0 - (pos.y - _y0), 0, max_scroll)
				queue_redraw()
		else:
			var it = press
			press = null
			queue_redraw()
			if _drag:
				_drag = false
				return
			var h = hit(pos)
			if it != null and h != null and h.get("id") == it.get("id") and h.has("tap") and h.tap.is_valid():
				h.tap.call()
			elif it == null and h == null and on_bg.is_valid():
				on_bg.call()
	func pressed(id) -> bool:
		return press != null and press.get("id") == id

var game
var hud: Box
var fxl: Box
var modal: Box
var body: Box
var mtop: Box
var card: Box
var title: Box
var L := {}
var st := "idle"
var _hud_dirty := true
var _hud_key := ""
var _toasts: Array = []
var _cue := {"txt": "", "kind": "", "t": 9.0}
var _hint := {"txt": "", "t": 9.0}
var _lvup := {"lv": 0, "sub": "", "t": 9.0}
var _coins: Array = []
var _coinpop := 9.0
var _bite_hot := false
var _ring := {"v": 0.0, "col": Color("#7cd04a")}
var _fight := {"tn": 0.0, "st": 1.0, "ds": 0.0, "on": false}
var _vig := 0.0
var _frame := 0
var _mod := {}
var _card := {}
var _card_t := 0.0
var _title_on := false
var _title_t := 0.0
var _sure := false
var _xu_rect := Rect2()
var _tt := 0.0

func _init(gm) -> void:
	game = gm
	L = gm.L
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	hud = Box.new(_draw_hud)
	add_child(hud)
	fxl = Box.new(_draw_fx)
	fxl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fxl)
	modal = Box.new(_draw_modal)
	modal.full = true
	modal.visible = false
	modal.on_bg = func(): close_modal()
	add_child(modal)
	body = Box.new(_draw_body)
	body.clip_contents = true
	body.area = true
	modal.add_child(body)
	mtop = Box.new(_draw_mtop)
	mtop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(mtop)
	card = Box.new(_draw_card)
	card.full = true
	card.visible = false
	add_child(card)
	title = Box.new(_draw_title)
	title.full = true
	title.visible = false
	add_child(title)

func relayout() -> void:
	L = game.L
	for b in [hud, fxl, modal, card, title]:
		b.position = Vector2.ZERO
		b.size = Vector2(L.W, L.H)
	if not _mod.is_empty():
		_open(_mod.kind, _mod.get("arg"))

func nar() -> bool:
	return L.W <= 520
func low() -> bool:
	return L.H <= 500
func big() -> bool:
	return L.W >= 521 and L.H >= 501

func hud_dirty() -> void:
	_hud_dirty = true

# ============================================================ khung hình
func step(dt: float) -> void:
	_tt += dt
	_frame += 1
	for t in _toasts:
		t.t += dt
	_toasts = _toasts.filter(func(t): return t.t < 2.7)
	_cue.t += dt
	_hint.t += dt
	_lvup.t += dt
	_coinpop += dt
	_card_t += dt
	_title_t += dt
	for c in _coins:
		c.t += dt
	var done := _coins.filter(func(c): return c.t >= c.end)
	for c in done:
		game.snd.coin(c.i)
	_coins = _coins.filter(func(c): return c.t < c.end)
	if done.size() and _coins.is_empty():
		_coinpop = 0.0
	var want := 1.0 if (st == "fight" and _fight.tn > .95) else 0.0
	_vig = lerpf(_vig, want, minf(1, dt * 8))
	hud.visible = game.started
	# thanh trên + nút chỉ vẽ lại khi có gì đổi (vẽ lại mỗi khung tốn ~0.7 ms trên máy bàn, gấp mấy lần trên web điện thoại)
	if game.started:
		var S: Dictionary = game.S
		var hk := ""
		if st == "fight" or (st == "wait" and _bite_hot) or _coinpop < .4:
			hk = "anim%d" % _frame
		else:
			hk = "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%d|%d" % [S.xu, S.lv, S.xp, fmt_h(S.hour), game.W.rain > .4,
				st, S.bait, S.baits.get(S.bait, 0), S.basket.size(), S.cage, modal.visible,
				hud.press.get("id") if hud.press != null else "", int(L.W), int(L.H)]
		if hk != _hud_key or _hud_dirty:
			_hud_key = hk
			_hud_dirty = false
			hud.queue_redraw()
	fxl.queue_redraw()
	if card.visible:
		card.queue_redraw()
	if title.visible:
		title.queue_redraw()
	if modal.visible and _mod.get("anim", 0.0) < .4:
		_mod.anim = _mod.get("anim", 0.0) + dt
		modal.queue_redraw()
		mtop.queue_redraw()
		body.queue_redraw()

# ============================================================ chữ có viền (text-shadow 8 hướng + bóng dưới của web)
func otext(ci: CanvasItem, s: String, x: float, y: float, fs: float, col: Color, olc: Color, olw := 2.0, drop := 4.0, al := 1, w := 800, xf := Transform2D.IDENTITY) -> void:
	if drop > 0:
		A.text(ci, s, x, y + drop, fs, olc, al, w, olw, olc, xf)
	A.text(ci, s, x, y, fs, col, al, w, olw, olc, xf)

func _push(ci: CanvasItem, xf: Transform2D) -> void:
	A.BASE = xf
	ci.draw_set_transform_matrix(xf)

func _pop(ci: CanvasItem) -> void:
	A.BASE = Transform2D.IDENTITY
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# (11-23) hộp HUD = .coins/.ibtn của Nông trại: kem gradient, 4 lớp viền nâu trong, vệt sáng trên
func met(ci: CanvasItem, r: Rect2, rad: float, down := false) -> void:
	A.pill(ci, r, minf(rad, 14.0), down)

# nút: "" xanh lá (btn primary Nông trại), "gold" cam (u2sp), "alt" kem (khchip), "red" đỏ
func btn(ci: CanvasItem, r: Rect2, lab: String, kind := "", down := false, disabled := false, ic := "", fs := 14.0) -> void:
	A.fbtn_bg(ci, r, kind, down, disabled, 12.0)
	var al := .55 if disabled else 1.0
	var fg := A.F_CHIP if kind == "alt" else Color.WHITE
	# bóng chữ chỉ nút cam có (text-shadow của u2sp); nút xanh / kem của Nông trại chữ trơn, không lớp nào phủ
	var shc := Color(125 / 255.0, 62 / 255.0, 0, .7) if kind == "gold" else Color(0, 0, 0, 0)
	if disabled:
		shc.a *= .3
	var rr := Rect2(r.position + Vector2(0, 1.5 if down and not disabled else 0.0), r.size)
	var mid := lab.contains("@")   # "Mua 10 · @12": đồng xu nằm giữa chữ (web: Mua 10 · <coin> 12)
	if mid:
		ic = "coin"
	var parts := lab.split("@") if mid else PackedStringArray([lab])
	var w0 := A.tw(parts[0], fs, 800)
	var w1 := A.tw(parts[1], fs, 800) if mid else 0.0
	var icw := 0.0
	if ic != "":
		icw = 18 + 4
	var tw := w0 + w1
	var x0 := rr.get_center().x - (tw + icw) / 2
	var segs := []   # [chữ, x trái]
	if mid:
		segs = [[parts[0], x0], [parts[1], x0 + w0 + icw]]
		A.svg(ci, ic, Rect2(x0 + w0 + 1, rr.get_center().y - 9, 18, 18), Color(1, 1, 1, al))
	else:
		if ic != "":
			A.svg(ci, ic, Rect2(x0, rr.get_center().y - 9, 18, 18), Color(1, 1, 1, al))
		segs = [[lab, x0 + icw]]
	var cy := rr.get_center().y
	for sg in segs:
		var sx: float = sg[1]
		if shc.a > 0:
			A.text(ci, sg[0], sx, cy + 1.5, fs, shc, 0, 800)
		A.text(ci, sg[0], sx, cy, fs, Color(fg, al), 0, 800)

func btn_w(lab: String, ic := "", fs := 14.0) -> float:
	if lab.contains("@"):
		return A.tw(lab.replace("@", ""), fs, 800) + 24 + 4 + 22
	return A.tw(lab, fs, 800) + 24 + 4 + (22 if ic != "" else 0)

# sao độ hiếm vẽ bằng hình (font Baloo 2 không có chữ ★, trên điện thoại ra ô vuông)
func draw_stars(ci: CanvasItem, r: int, x: float, y: float, fs := 12.0, col := Color("#e0a020"), al := 0, xf := Transform2D.IDENTITY) -> float:
	var n := maxi(1, r)
	var step := fs * .92
	var w := step * 4
	var x0 := x
	if al == 1:
		x0 = x - w / 2
	for i in 4:
		var c := xf * Vector2(x0 + step * (i + .5), y)
		var sc := xf.get_scale().x
		ci.draw_colored_polygon(A.star_pts(c, fs * .42 * sc, fs * .18 * sc), col if i < n else Color(col, .25))
	return w

static func fmt_w(w: float) -> String:
	if w < 1:
		return str(int(round(w * 1000))) + " g"
	return (("%.2f" % w) if w < 10 else ("%.1f" % w)) + " kg"

static func fmt_h(h: float) -> String:
	var hh := int(floor(h))
	var mm := int(floor((h - hh) * 60 / 10)) * 10
	return "%d:%02d" % [hh, mm]

static func fmt_n(n: int) -> String:   # toLocaleString('vi-VN'): 1.234
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

# ============================================================ HUD
func _draw_hud(ci: Box) -> void:
	ci.items = []
	if not game.started:
		return
	var S: Dictionary = game.S
	var n := nar()
	var top := 10.0
	var ph := 38.0 if n else 44.0
	var fs := 16.0 if n else 19.0
	var ics := 26.0 if n else 30.0
	# xu
	var xs := fmt_n(S.xu)
	var pop := 1.0 + sin(clampf(_coinpop / .4, 0, 1) * PI) * .18 if _coinpop < .4 else 1.0
	var xw := 4 + ics + 6 + A.tw(xs, fs) + 12
	var xr := Rect2(12, top, xw, ph)
	_xu_rect = xr
	var xf := Transform2D(0, Vector2(pop, pop), 0, xr.get_center()) * Transform2D(0, -xr.get_center())
	_push(ci, xf)
	met(ci, xr, ph / 2)
	A.svg(ci, "coin", Rect2(xr.position.x + 4, xr.get_center().y - ics / 2 - 1, ics, ics))
	A.text(ci, xs, xr.position.x + 4 + ics + 6, xr.get_center().y - 1, fs, A.F_BROWN, 0, 800)
	_pop(ci)
	# cấp + thanh kinh nghiệm
	var lfs := 13.0 if n else 15.0
	var need := D.xp_need(S.lv)
	var lt := "Cấp " + str(S.lv)
	var em := "" if n else "%d/%d kn" % [S.xp, need]
	var lw := maxf(96.0 if n else 132.0, A.tw(lt, lfs) + (A.tw(em, 12, 700) + 4 if em != "" else 0) + 24)
	var lr := Rect2(xr.end.x + 8, top, lw, ph)
	met(ci, lr, ph / 2)
	var ty := lr.position.y + ph * .36
	A.text(ci, "Cấp ", lr.position.x + 12, ty, lfs, A.F_BROWN, 0, 800)
	A.text(ci, str(S.lv), lr.position.x + 12 + A.tw("Cấp ", lfs), ty, lfs, A.F_BROWN, 0, 800)
	if em != "":
		A.text(ci, em, lr.position.x + 12 + A.tw(lt, lfs) + 4, ty + 1, 12, A.SMALL2, 0, 700)
	var br := Rect2(lr.position.x + 12, lr.position.y + ph * .62, lw - 24, 9)
	A.bar_bg(ci, br, float(S.xp) / need, A.F_XP)
	# cài đặt
	var ib := 40.0 if n else 44.0
	var sr := Rect2(L.W - 12 - ib, top, ib, ib)
	met(ci, sr, ib / 2, ci.pressed("set"))
	A.svg(ci, "cog", Rect2(sr.get_center() - Vector2(13, 13) * (ib / 44), Vector2(26, 26) * (ib / 44)))
	ci.items.append({"r": sr, "id": "set", "tap": func(): _ui_tap(); open_settings()})
	# đồng hồ
	var h: float = S.hour
	var rain: bool = game.W.rain > .4
	var ic := "rain" if rain else ("sun" if h >= 5.6 and h < 18.8 else "moon")
	var ts := fmt_h(h)
	var sm := "" if n else ("Mưa" if rain else D.phase_name(h))
	var cw = 4 + ics + 6 + A.tw(ts, fs) + (6 + A.tw(sm, 13, 600) if sm != "" else 0) + 12
	var cr := Rect2(sr.position.x - 8 - cw, top, cw, ph)
	met(ci, cr, ph / 2)
	A.svg(ci, ic, Rect2(cr.position.x + 4, cr.get_center().y - ics / 2 - 1, ics, ics))
	A.text(ci, ts, cr.position.x + 4 + ics + 6, cr.get_center().y - 1, fs, A.F_BROWN, 0, 800)
	if sm != "":
		A.text(ci, sm, cr.position.x + 4 + ics + 6 + A.tw(ts, fs) + 6, cr.get_center().y, 13, A.SMALL, 0, 600)
	# khung kéo cá
	if st == "fight":
		_draw_fightbox(ci)
	var hide_bottom := modal.visible or st == "card" or st == "land"
	if hide_bottom:
		return
	var fighting := st == "fight"
	# mồi đang móc (trái dưới)
	var bfs := 14.0 if n else 17.0
	var sfs := 12.0 if n else 13.0
	var bh := 54.0 if n else 64.0
	var icb := 40.0 if n else 50.0
	var bt: Dictionary = D.BAIT[S.bait]
	var nm: String = bt.name
	var sub: String = "Vô hạn" if S.bait == "trun" else "Còn " + str(int(S.baits.get(S.bait, 0)))
	var maxw := 72.0 if n else 999.0
	var lines := A.wrap(nm, bfs, 800, maxw) if n else [nm]
	var tw := 0.0
	for ln in lines:
		tw = maxf(tw, A.tw(ln, bfs))
	tw = maxf(tw, A.tw(sub, sfs, 700))
	var bw := 6 + icb + 8 + tw + 12
	var bhh := maxf(bh, lines.size() * bfs * 1.05 + sfs * 1.1 + 10)
	var bb := Rect2(12, L.H - 12 - bhh - 4, bw, bhh)
	var fa := 0.0 if fighting else 1.0
	if not fighting:
		var dn := ci.pressed("bait")
		met(ci, bb, 16, dn)
		var ir := Rect2(bb.position.x + 6, bb.get_center().y - icb / 2 + (2 if dn else 0) - 2, icb, icb)
		A.fbox(ci, ir, 10, [[0.0, A._c(247, 238, 214)], [1.0, A._c(239, 226, 192)]], [[1.0, A._c(150, 112, 48, .3)]])
		A.pic(ci, S.bait, ir.grow(-3))
		var tx := ir.end.x + 8
		var yy := bb.get_center().y - (lines.size() * bfs * 1.05 + sfs * 1.1) / 2 + bfs * .52 + (2 if dn else 0) - 2
		for ln in lines:
			A.text(ci, ln, tx, yy, bfs, A.F_BROWN, 0, 800)
			yy += bfs * 1.05
		A.text(ci, sub, tx, yy - bfs * .52 + sfs * .6, sfs, A.SMALL, 0, 700)
		ci.items.append({"r": bb, "id": "bait", "tap": func(): _ui_tap(); open_shop("bait")})
	# Giỏ cá / Chợ / Sổ cá (phải dưới; máy hẹp xếp dọc)
	if not fighting:
		var mw := 58.0 if n else 74.0
		var mh := 62.0 if n else 76.0
		var mi := 34.0 if n else 44.0
		var mfs := 12.0 if n else 14.0
		var menu := [["basket", "Giỏ cá", func(): open_basket()], ["shop", "Chợ", func(): open_shop("bait")], ["book", "Sổ cá", func(): open_dex()]]
		for i in 3:
			var r: Rect2
			if n:
				r = Rect2(L.W - 12 - mw, L.H - 12 - 4 - mh - (2 - i) * (mh + 7), mw, mh)
			else:
				r = Rect2(L.W - 12 - mw * (3 - i) - 8 * (2 - i), L.H - 12 - 4 - mh, mw, mh)
			var id: String = menu[i][0]
			var dn := ci.pressed(id)
			met(ci, r, 18, dn)
			var oy := 2.0 if dn else 0.0
			A.svg(ci, id, Rect2(r.get_center().x - mi / 2, r.position.y + (mh - mi - mfs) / 2 - 2 + oy, mi, mi))
			A.text(ci, menu[i][1], r.get_center().x, r.position.y + (mh - mi - mfs) / 2 + mi + mfs * .5 - 1 + oy, mfs, A.F_BROWN, 1, 800)
			var cb: Callable = menu[i][2]
			ci.items.append({"r": r, "id": id, "tap": func(): _ui_tap(); cb.call()})
			if id == "basket" and S.basket.size() > 0:
				var cnt := str(S.basket.size())
				A.badge(ci, Vector2(r.end.x - 4, r.position.y + 4), cnt, 12.0)
	_draw_act(ci)

func _draw_act(ci: Box) -> void:
	var n := nar()
	var D2 := 84.0 if n else 92.0
	var lfs := 23.0 if n else 26.0
	if low():
		D2 = 76.0
	if big():
		D2 = 116.0
		lfs = 28.0
	var cx: float = L.W / 2
	var by: float = L.H - 14 - D2
	var busy := not (st == "idle" or st == "wait" or st == "fight")
	var dn = ci.pressed("act") or (st == "fight" and game.G.hold)
	var oy := 4.0 if dn and not busy else 0.0
	var sc := 1.0
	var strike := st == "wait" and _bite_hot
	if strike:
		sc = 1 + .1 * sin(fmod(_tt, .35) / .35 * PI)
	var c := Vector2(cx, by + D2 / 2 + oy)
	_push(ci, Transform2D(0, Vector2(sc, sc), 0, c))
	var al := .55 if busy else 1.0
	var non: Texture2D = A.img("ui_non")
	if non != null:
		ci.draw_texture_rect(non, Rect2(-D2 / 2, -D2 / 2, D2, D2), false, Color(1, 1, 1, al))
	# vòng căng dây quanh nón (svg ring r51/110, inset -9)
	var rr := D2 / 2 + 9 - (D2 + 18) * 4 / 110.0
	var rw := (D2 + 18) * 7 / 110.0
	var ring_bg := Color(1, 250 / 255.0, 230 / 255.0, .55)
	if strike:
		ring_bg = Color(1, 220 / 255.0, 200 / 255.0, .8)
	ci.draw_arc(Vector2.ZERO, rr, 0, TAU, 48, ring_bg, (D2 + 18) * 5 / 110.0, true)
	var rv: float = _ring.v
	if rv > 0.005:
		ci.draw_arc(Vector2.ZERO, rr, -PI / 2, -PI / 2 + TAU * clampf(rv, 0, 1), 48, _ring.col, rw, true)
	var lab := ""
	var olc := A.LEAF2
	var f := lfs
	var la := 1.0
	match st:
		"idle":
			lab = "Quăng"
		"wait":
			if _bite_hot:
				lab = "Giật!"
				olc = A.BRICK2
				f = lfs + 2 if not n else lfs + 2
			else:
				lab = "Chờ…"
				la = .75
				f = 22
		"fight":
			lab = "Giữ"
			olc = A.WOOD2
	if lab != "":
		otext(ci, lab, 0, 0, f, Color(1, 1, 1, la * al), Color(olc, la * al), 2.0, 4.0, 1, 900)
	_pop(ci)
	if not busy:
		ci.items.append({"r": Rect2(cx - D2 / 2, by, D2, D2), "id": "act", "down": func(): game.act(true)})

func _draw_fightbox(ci: CanvasItem) -> void:
	var n := nar()
	var w := minf(460, L.W * .94)
	var fs := 12.0 if n else 13.0
	var r := Rect2((L.W - w) / 2, 56.0 if n else 62.0, w, 0)
	var big_h := 16.0
	var sm_h := 11.0
	r.size.y = 7 + big_h + 6 + 6 + sm_h + 8 + 6
	met(ci, r, 16)
	var tn: float = _fight.tn
	var x0 := r.position.x + 12
	var y := r.position.y + 7 + 3
	# dây căng
	var lw := maxf(66, A.tw("Dây căng", fs) + 6)
	A.text(ci, "Dây căng", x0, y + big_h / 2, fs, A.F_BROWN, 0, 800)
	var sh := 0.0
	if tn > 1:
		sh = 2.0 * sin(_tt * 52)
	var tr := Rect2(x0 + lw + 6 + sh, y, r.end.x - 12 - x0 - lw - 6, big_h)
	_meter_bg(ci, tr)
	var zone := Rect2(tr.end.x - tr.size.x * .18, tr.position.y + 2, tr.size.x * .18 - 2, tr.size.y - 4)
	_hatch(ci, zone)
	var bw := (tr.size.x - 4) * clampf(tn, 0, 1.15) / 1.15
	if bw > 1:
		var b0 := Rect2(tr.position + Vector2(2, 2), Vector2(bw, tr.size.y - 4))
		var segs := [[0.0, .55, Color("#6ab040")], [.55, .8, Color("#e8c030")], [.8, 1.0, Color("#e04a2a")]]
		for s in segs:
			var a: float = b0.position.x + bw * s[0]
			var b: float = b0.position.x + bw * s[1]
			if b - a > .3:
				A.box(ci, Rect2(a, b0.position.y, b - a, b0.size.y), s[2], 0)
	y += big_h + 6
	var half := (r.size.x - 24 - 14) / 2
	var m := [["Sức cá", clampf(_fight.st, 0, 1), Color("#4a8ad0")], ["Xa %d m" % int(round(game.G.dist * 1.6)), clampf(_fight.ds, 0, 1), Color("#c8964a")]]
	for i in 2:
		var mx := x0 + i * (half + 14)
		var lab: String = m[i][0]
		var lw2 := maxf(56, A.tw(lab, fs) + 6)
		A.text(ci, lab, mx, y + sm_h / 2 + 3, fs, A.F_BROWN, 0, 800)
		var tr2 := Rect2(mx + lw2, y + 3, half - lw2, sm_h)
		_meter_bg(ci, tr2)
		var ww: float = (tr2.size.x - 4) * m[i][1]
		if ww > 1:
			A.box(ci, Rect2(tr2.position + Vector2(2, 2), Vector2(ww, tr2.size.y - 4)), m[i][2], 4)

func _meter_bg(ci: CanvasItem, r: Rect2) -> void:
	# (11-23) rãnh thanh như .kcbar của Nông trại
	A.fbox(ci, r, r.size.y / 2, [[0.0, A._c(222, 205, 160)], [.4, A._c(232, 217, 178)], [1.0, A._c(232, 217, 178)]], [[1.5, A._c(120, 82, 22, .35)]], [], [], [[0, 1, 0, Color(1, 1, 1, .75)]])

func _hatch(ci: CanvasItem, r: Rect2) -> void:
	var col := Color(200 / 255.0, 40 / 255.0, 20 / 255.0, .25)
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var pts := PackedVector2Array([Vector2(x, r.end.y), Vector2(x + 4, r.end.y), Vector2(x + 4 + r.size.y, r.position.y), Vector2(x + r.size.y, r.position.y)])
		var clip := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		for p in Geometry2D.intersect_polygons(pts, clip):
			if p.size() >= 3:
				ci.draw_colored_polygon(p, col)
		x += 8

func ui_state(s: String) -> void:
	st = s
	_ring = {"v": 0.0, "col": Color("#7cd04a")}
	_bite_hot = false
	_fight.on = s == "fight"
	if s != "fight":
		_vig = 0.0

func ui_fight(tn: float, stv: float, ds: float, _beh: String) -> void:
	_fight.tn = tn
	_fight.st = stv
	_fight.ds = ds
	_ring = {"v": tn / 1.15, "col": Color("#ff4a2a") if tn > 1 else (Color("#f0c030") if tn > .8 else Color("#7cd04a"))}

func ui_bite(on: bool) -> void:
	_bite_hot = on

func _ui_tap() -> void:
	game.snd.init()
	game.snd.ui()

# ============================================================ lời báo, chữ to, lời nhắc, lên cấp, xu bay
func toast(msg: String, kind := "") -> void:
	_toasts.append({"msg": msg, "kind": kind, "t": 0.0})
	while _toasts.size() > 3:
		_toasts.remove_at(0)

func cue(msg: String, kind := "") -> void:
	_cue = {"txt": msg, "kind": kind, "t": 0.0}

func hint(msg: String) -> void:
	_hint = {"txt": msg, "t": 0.0}

func hint_off() -> void:
	_hint.t = 9.0

func level_up(lv: int) -> void:
	var un := []
	for b in D.BAIT_ORDER:
		if D.BAIT[b].lv == lv:
			un.append(D.BAIT[b].name)
	_lvup = {"lv": lv, "sub": ("Mở khóa mồi: " + ", ".join(un)) if un.size() else "Cá lớn bắt đầu để ý tới bạn", "t": 0.0}
	game.snd.fanfare(3)

func fly_coins(n: int, from: Vector2) -> void:
	for i in mini(8, n):
		_coins.append({"from": from + Vector2(randf_range(-20, 20), randf_range(-10, 10)), "t": -(.03 + i * .06), "end": .73, "i": i})

func _draw_fx(ci: Box) -> void:
	var n := nar()
	# viền đỏ khi dây sắp đứt
	if _vig > .01:
		var e := 120.0
		for k in 12:
			var a := _vig * .45 * pow(1 - k / 12.0, 2) * .35
			var g := k * e / 12.0
			var c := Color(220 / 255.0, 30 / 255.0, 10 / 255.0, a)
			ci.draw_rect(Rect2(0, g, L.W, e / 12.0), c)
			ci.draw_rect(Rect2(0, L.H - g - e / 12.0, L.W, e / 12.0), c)
			ci.draw_rect(Rect2(g, 0, e / 12.0, L.H), c)
			ci.draw_rect(Rect2(L.W - g - e / 12.0, 0, e / 12.0, L.H), c)
	# lời báo
	var ty := 64.0
	if st == "fight":
		ty = 128.0 if n else 138.0
	for t in _toasts:
		var a := 1.0
		var oy := 0.0
		var sc := 1.0
		if t.t < .3:
			var k: float = t.t / .3
			a = k
			oy = -14 * (1 - k)
			sc = .8 + .2 * (1 + sin(k * PI) * .3)
		elif t.t > 2.2:
			var k: float = (t.t - 2.2) / .4
			a = 1 - clampf(k, 0, 1)
			oy = -10 * k
		var lines := A.wrap(t.msg, 15, 800, L.W * .92 - 40)
		var tw := 0.0
		for ln in lines:
			tw = maxf(tw, A.tw(ln, 15))
		var h := lines.size() * 15 * 1.3 + 10
		var r := Rect2(L.W / 2 - (tw + 32) / 2, ty + oy, tw + 32, h)
		# (11-23) như #toast.u2hud của Nông trại: ô kem viền nâu bo 14, chấm màu theo loại tin
		var dot := Color(0, 0, 0, 0)
		match t.kind:
			"good": dot = A._c(78, 155, 68)
			"bad": dot = A.F_RED
			"info": dot = A._c(59, 130, 200)
		if dot.a > 0:
			r = Rect2(r.position - Vector2(7, 0), r.size + Vector2(14, 0))
		var xf := Transform2D(0, Vector2(sc, sc), 0, r.get_center()) * Transform2D(0, -r.get_center())
		_push(ci, xf)
		A.FA = a
		A.pill(ci, r, 14)
		A.FA = 1.0
		if dot.a > 0:
			ci.draw_circle(Vector2(r.position.x + 15, r.get_center().y), 5, Color(dot, a))
		_pop(ci)
		var fg := A.F_BROWN
		var yy := r.position.y + 5 + 15 * 1.3 / 2
		for ln in lines:
			A.text(ci, ln, r.get_center().x + (7 if dot.a > 0 else 0), yy, 15, Color(fg, a), 1, 700, 0.0, A.INK, xf)
			yy += 15 * 1.3
		ty += h + 6
	# chữ to giữa màn
	if _cue.t < 1.1 and _cue.txt != "":
		var k: float = _cue.t / 1.1
		var a := 0.0
		var sc := 1.0
		var oy := 0.0
		if k < .15:
			a = k / .15
			sc = lerpf(.5, 1.12, k / .15)
		elif k < .25:
			a = 1
			sc = lerpf(1.12, 1, (k - .15) / .1)
		elif k < .75:
			a = 1
		else:
			a = 1 - (k - .75) / .25
			oy = -20 * (k - .75) / .25
		var fs := clampf(L.W * .08, 34, 64)
		var col := Color("#fff7d8")
		match _cue.kind:
			"warn": col = Color("#ffe070")
			"bad": col = Color("#ffb0a0")
			"good": col = Color("#e4ffb8")
		var cy: float = L.H * .36 + fs * .7 + oy
		var xf := Transform2D(0, Vector2(sc, sc), 0, Vector2(L.W / 2, cy))
		A.text(ci, _cue.txt, 0, 6, fs, Color("#4a1e08", a), 1, 800, 0.0, A.INK, xf)
		A.text(ci, _cue.txt, 0, 3, fs, Color("#8a3a14", a), 1, 800, 0.0, A.INK, xf)
		A.text(ci, _cue.txt, 0, 0, fs, Color(col, a), 1, 800, 0.0, A.INK, xf)
	# lời nhắc (trên nút nón)
	if _hint.t < 2.7 and _hint.txt != "":
		var a := clampf(_hint.t / .3, 0, 1) * (1 - clampf((_hint.t - 2.4) / .3, 0, 1))
		var fs := 13.0 if n else 14.0
		var lines := A.wrap(_hint.txt, fs, 800, L.W * .86 - 36)
		var tw := 0.0
		for ln in lines:
			tw = maxf(tw, A.tw(ln, fs))
		var h := lines.size() * fs * 1.3 + 12
		var bot = L.H - (112.0 if n else 150.0)
		var r := Rect2(L.W / 2 - (tw + 32) / 2, bot - h, tw + 32, h)
		A.FA = a
		A.pill(ci, r, 14)
		A.FA = 1.0
		var yy := r.position.y + 6 + fs * 1.3 / 2
		for ln in lines:
			A.text(ci, ln, L.W / 2, yy, fs, Color(A.F_BROWN, a), 1, 700)
			yy += fs * 1.3
	# lên cấp
	if _lvup.t < 2.6:
		var k: float = _lvup.t / 2.6
		var a := 1.0
		var sc := 1.0
		var oy := 0.0
		if k < .12:
			a = k / .12
			sc = lerpf(.5, 1.08, k / .12)
			oy = 20 * (1 - k / .12)
		elif k < .2:
			sc = lerpf(1.08, 1, (k - .12) / .08)
		elif k > .85:
			a = 1 - (k - .85) / .15
			oy = -20 * (k - .85) / .15
		var t1 := "Lên cấp %d!" % _lvup.lv
		var w := maxf(A.tw(t1, 22), A.tw(_lvup.sub, 14, 700)) + 48
		var h := 22 * 1.3 + 14 * 1.3 + 20
		var c := Vector2(L.W / 2, L.H * .3 + h / 2 + oy)
		var xf := Transform2D(0, Vector2(sc, sc), 0, c)
		var r := Rect2(-w / 2, -h / 2, w, h)
		# (11-23) bảng cam như nút u2sp của Nông trại, chữ trắng bóng nâu
		_push(ci, xf)
		A.FA = a
		A.fbtn_bg(ci, r, "gold", false, false, 16)
		A.FA = 1.0
		_pop(ci)
		var shc := Color(125 / 255.0, 62 / 255.0, 0, .7 * a)
		A.text(ci, t1, 0, -h / 2 + 10 + 22 * .65 + 1.5, 22, shc, 1, 800, 0.0, A.INK, xf)
		A.text(ci, t1, 0, -h / 2 + 10 + 22 * .65, 22, Color(1, 1, 1, a), 1, 800, 0.0, A.INK, xf)
		A.text(ci, _lvup.sub, 0, -h / 2 + 10 + 22 * 1.3 + 14 * .6 + 1.5, 14, shc, 1, 700, 0.0, A.INK, xf)
		A.text(ci, _lvup.sub, 0, -h / 2 + 10 + 22 * 1.3 + 14 * .6, 14, Color(1, 1, 1, a), 1, 700, 0.0, A.INK, xf)
	# xu bay về túi
	for c in _coins:
		if c.t < 0:
			continue
		var k := clampf(c.t / .7, 0, 1)
		# cubic-bezier(.5,-.3,.7,1)
		var e := 3 * (1 - k) * (1 - k) * k * -.3 + 3 * (1 - k) * k * k * 1 + k * k * k
		var to := _xu_rect.position + Vector2(14 + 13, 14 + 13 - 13)
		var p: Vector2 = c.from.lerp(to, e)
		var s := lerpf(1, .8, k)
		A.svg(ci, "coin", Rect2(p - Vector2(13, 13) * s, Vector2(26, 26) * s), Color(1, 1, 1, lerpf(1, .6, k)))

# ============================================================ hộp thoại
# _mod: {kind, arg, w, title, sub, icon, tabs, body_h, anim}
func _open(kind: String, arg = null) -> void:
	var was: bool = modal.visible and _mod.get("kind", "") == kind
	var anim: float = _mod.get("anim", 0.0) if was else 0.0
	var keep_scroll: float = body.scroll if was else 0.0
	_mod = {"kind": kind, "arg": arg, "anim": anim}
	modal.visible = true
	game.G.paused = true
	_layout_modal()
	body.scroll = clampf(keep_scroll, 0, body.max_scroll)
	modal.queue_redraw()
	mtop.queue_redraw()
	body.queue_redraw()

func close_modal() -> void:
	if not modal.visible:
		return
	modal.visible = false
	_mod = {}
	game.G.paused = false
	_sure = false
	game.save(true)

func _layout_modal() -> void:
	# (11-23 đồng bộ Nông trại) bảng như Kho của Nông trại: rộng tối đa 500, nền giấy kem, khung tre, nút X đỏ trên khung,
	# tên bảng chữ nâu trong lòng bảng (không còn thanh gỗ), thanh tre ngang ngăn đầu bảng với phần thân
	var n := nar()
	var k: String = _mod.kind
	var pw := 500.0
	if k == "set":
		pw = 380.0
	var padt := 54.0 if n else 60.0
	pw = minf(pw, L.W - 24)
	_mod.w = pw
	var hh := 20.0 + 26.0 + 8.0
	if _sub_of(k) != "":
		hh += 16.0
	_mod.hh = hh
	var tabs_h := 0.0
	if k == "shop":
		tabs_h = 34.0
	_mod.tabs_h = tabs_h
	_mod.top = hh + tabs_h + Tre.T + Tre.S - 2.0   # phần thân bắt đầu ngay dưới thanh tre
	var content_h := _body(null, pw - 32, false)
	var maxh: float = L.H - padt - 12
	var ph: float = minf(_mod.top + 10 + content_h + 14 + 9, maxh)
	_mod.ph = ph
	var top := padt + (maxh - ph) / 2
	_mod.r = Rect2((L.W - pw) / 2, top, pw, ph)
	var br := Rect2(_mod.r.position.x + 2, _mod.r.position.y + _mod.top, pw - 4, ph - _mod.top - 9)
	body.position = br.position
	body.size = br.size
	body.max_scroll = maxf(0, 10 + content_h + 14 - br.size.y)
	mtop.position = Vector2.ZERO
	mtop.size = Vector2(L.W, L.H)

func _mxf() -> Array:   # [phép biến hình bảng đang bật lên, độ dịch dọc, độ hiện]
	var r: Rect2 = _mod.r
	var k := clampf(_mod.anim / .28, 0, 1)
	var e := 1 - pow(1 - k, 3) + sin(k * PI) * .08
	var oy := 30 * (1 - e)
	var sc := lerpf(.95, 1, e)
	return [Transform2D(0, Vector2(sc, sc), 0, r.get_center() + Vector2(0, oy)) * Transform2D(0, -r.get_center()), oy, k]

func _sub_of(k: String) -> String:
	var S: Dictionary = game.S
	match k:
		"basket": return "%d/%d con · cá hiếm để dành đổi đồ ở Chợ" % [S.basket.size(), D.CAGE[S.cage].cap]
		"shop": return "Mua mồi · đổi đồ nghề bằng cá"
		"dex":
			var seen := 0
			for f in D.FISH:
				if S.dex.has(f.id):
					seen += 1
			return "%d/%d loài · chạm để xem gợi ý" % [seen, D.FISH.size()]
	return ""

func _title_of(k: String) -> Array:
	match k:
		"basket": return ["basket", "Giỏ cá"]
		"shop": return ["shop", "Chợ quê"]
		"dex": return ["book", "Sổ cá"]
		"set": return ["cog", "Cài đặt"]
	return ["", ""]

func _draw_modal(ci: Box) -> void:
	ci.items = []
	if _mod.is_empty():
		return
	var a := clampf(_mod.anim / .2, 0, 1)
	A.under_rect(ci, Rect2(0, 0, L.W, L.H), Color(10 / 255.0, 24 / 255.0, 12 / 255.0, .45 * a))   # .pbk
	var r: Rect2 = _mod.r
	var mx := _mxf()
	var xf: Transform2D = mx[0]
	body.position = Vector2(r.position.x + 2, r.position.y + _mod.top + mx[1])
	body.modulate.a = mx[2]
	# bảng: bóng (0 -10px 40px như .pwin) + nền giấy kem (một ảnh ghép sẵn); cả hai nằm dưới các ô (tab)
	A.fbox(ci, r, Tre.R, [], [], [], [], [[0, -10, 40, Color(0, 0, 0, .3)]], xf)
	A.under_tex(ci, A.paper(r.size.x, r.size.y, Tre.R), r, xf)
	# tên bảng
	var t := _title_of(_mod.kind)
	var sub := _sub_of(_mod.kind)
	var ix := r.position.x + 22
	var ty := r.position.y + 20 + 13
	if t[0] != "":
		ci.draw_set_transform_matrix(xf)
		A.svg(ci, t[0], Rect2(ix, ty - 15 + (8 if sub != "" else 0), 30, 30))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		ix += 38
	var maxw := r.end.x - 22 - ix
	var tt: String = t[1]
	var tfs := 20.0
	while A.tw(tt, tfs) > maxw and tfs > 15:
		tfs -= 1
	A.text(ci, tt, ix, ty, tfs, A.F_INK, 0, 800, 0.0, A.INK, xf)
	if sub != "":
		var sl := A.wrap(sub, 12.5, 600, maxw)
		A.text(ci, sl[0], ix, ty + 18, 12.5, A.F_MUTED, 0, 600, 0.0, A.INK, xf)
	# "panel" phải nằm TRƯỚC nút X: hit() dò từ cuối lên, panel đứng sau thì nuốt luôn cú bấm X (Link 11-23 "X đéo đóng được")
	ci.items.append({"r": r, "id": "panel"})
	var xr := _x_rect()
	ci.items.append({"r": xr.grow(5), "id": "x", "tap": func(): game.snd.ui(); close_modal()})
	# tab của Chợ (.khseg: tab chọn xanh lá cao hơn, tab kia kem; đứng trên thanh tre)
	var by: float = r.position.y + _mod.hh + _mod.tabs_h - 2
	if _mod.kind == "shop":
		var gx := r.position.x + 16
		var gw := r.size.x - 32
		var tw := (gw - 6) / 2
		_push(ci, xf)
		for i in 2:
			var id: String = ["bait", "gear"][i]
			var on: bool = _mod.arg == id
			var tr := Rect2(gx + i * (tw + 6), by - (33 if on else 30) + 2, tw, (33 if on else 30))
			var q := Vector4(14, 14, 0, 0)
			if on:
				A.fbox(ci, tr, q, [[0.0, A._c(78, 155, 68)], [.5, A._c(81, 159, 70)], [1.0, A._c(88, 169, 77)]], [[1.0, A.F_GREEN]], [2.0, A._c(150, 215, 130, .45)], [8.0, A._c(10, 55, 10, .24)])
			else:
				A.fbox(ci, tr, q, [[0.0, A._c(253, 244, 220)], [1.0, A._c(238, 220, 170)]], [[1.0, A._c(150, 112, 48, .4)]], [2.0, Color(1, 1, 1, .6)], [8.0, A._c(120, 85, 25, .14)])
			var lab: String = ["Mồi câu", "Đổi đồ nghề"][i]
			var pk: String = ["trun", D.GEAR_KEYS[0]][i]
			var lw := 20 + 5 + A.tw(lab, 14)
			var lx := tr.get_center().x - lw / 2
			var cy := tr.get_center().y + (1.5 if on else 0.0)
			A.pic(ci, pk, Rect2(lx, cy - 10, 20, 20))
			A.text(ci, lab, lx + 25, cy, 14, Color.WHITE if on else A.F_TAB, 0, 800)
			ci.items.append({"r": tr, "id": "tab" + id, "tap": func(): game.snd.ui(); _open("shop", id)})
		_pop(ci)
	# thanh tre ngang dưới đầu bảng
	var bw := r.size.x - 8
	ci.draw_set_transform_matrix(xf)
	ci.draw_texture_rect(Tre.bar(bw), Rect2(r.position.x + 4, by, bw, Tre.T + Tre.S), false)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	mtop.queue_redraw()   # nút X đang bấm (lớp trên vẽ X)

func _x_rect() -> Rect2:   # nút X đỏ của Nông trại (ibtn 27px) đè lên khung tre trên, cách mép phải 19px
	var r: Rect2 = _mod.r
	return Rect2(r.end.x - 19 - 27, r.position.y - 15, 27, 27)

# lớp TRÊN phần thân: khung tre, cành hoa góc trái trên, nút X — như .u2tre/.u2hoa (z trên nội dung)
func _draw_mtop(ci: Box) -> void:
	if _mod.is_empty():
		return
	var r: Rect2 = _mod.r
	var xf: Transform2D = _mxf()[0]
	ci.draw_set_transform_matrix(xf)
	var fr := r.grow(1.5)
	ci.draw_texture_rect(Tre.texture(fr.size.x, fr.size.y), fr, false)
	var h1 := A.usvg("hoa1", 64 * .82, 64 * .82)
	# (Link 11-23 "bỏ hoa ở dưới") chỉ còn cành hoa góc trái trên
	for f in [[h1, r.position + Vector2(14, 8), -24.0, .82]]:
		if f[0] == null:
			continue
		var s: float = 64.0 * f[3]
		var m := xf * Transform2D(deg_to_rad(f[2]), f[1])
		ci.draw_set_transform_matrix(m * Transform2D(0, Vector2(0, 2)))   # drop-shadow(0 2px 2px rgba(40,50,10,.35))
		ci.draw_texture_rect(f[0], Rect2(-s / 2, -s / 2, s, s), false, Color(40 / 255.0, 50 / 255.0, 10 / 255.0, .3))
		ci.draw_set_transform_matrix(m)
		ci.draw_texture_rect(f[0], Rect2(-s / 2, -s / 2, s, s), false)
	ci.draw_set_transform_matrix(xf)
	var xr := _x_rect()
	var dn := modal.pressed("x")
	var xt := A.usvg("nut_x", 27, 27)
	if xt != null:
		A.box(ci, Rect2(xr.position + Vector2(0, 2), xr.size), Color(60 / 255.0, 30 / 255.0, 10 / 255.0, .3), 10)
		var xp := Rect2(xr.position + Vector2(0, 1.5 if dn else 0.0), xr.size)
		ci.draw_texture_rect(xt, xp, false)
		# chữ × trắng 22px đậm, bóng rgba(90,20,10,.5) 0 1px (như .ibtn của Nông trại)
		A.text(ci, "×", xp.get_center().x, xp.get_center().y + 1, 22, Color(90 / 255.0, 20 / 255.0, 10 / 255.0, .5), 1, 800, 0.0, A.INK, xf)
		A.text(ci, "×", xp.get_center().x, xp.get_center().y, 22, Color.WHITE, 1, 800, 0.0, A.INK, xf)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_body(ci: Box) -> void:
	ci.items = []
	if _mod.is_empty():
		return
	_body(ci, _mod.w - 32, true)

# vẽ (hoặc chỉ đo khi ci == null) phần thân hộp thoại; trả về chiều cao
func _body(ci, w: float, draw: bool) -> float:
	var y := 10.0
	match _mod.kind:
		"basket": y = _b_basket(ci, w, y)
		"shop": y = _b_shop(ci, w, y)
		"dex": y = _b_dex(ci, w, y)
		"set": y = _b_set(ci, w, y)
	return y - 10

func _sc(ci) -> float:
	return ci.scroll if ci != null else 0.0

# một hàng = ô .khb của Kho Nông trại (kem gradient, viền nâu mảnh, gờ dưới); đang chọn = viền xanh lá
func _row(ci, r: Rect2, sel := false) -> void:
	if ci == null:
		return
	A.card(ci, Rect2(r.position - Vector2(0, _sc(ci)), r.size), sel)

func _th(ci, r: Rect2, fid := "", pic := "", dark := false) -> void:
	if ci == null:
		return
	var rr := Rect2(r.position - Vector2(0, _sc(ci)), r.size)
	A.fbox(ci, rr, 10, [[0.0, A._c(247, 238, 214)], [1.0, A._c(239, 226, 192)]], [[1.0, A._c(150, 112, 48, .22)]])
	if fid != "":
		var t: Texture2D = A.img(fid)
		if t != null:
			A.fit(ci, t, rr.grow(-3), Color(0, 0, 0, .28) if dark else Color.WHITE)
	elif pic != "":
		A.pic(ci, pic, Rect2(rr.get_center() - Vector2(27, 27), Vector2(54, 54)))

func _t(ci, s: String, x: float, y: float, fs: float, col: Color, al := 0, wt := 800) -> void:
	if ci != null:
		A.text(ci, s, x, y - _sc(ci), fs, col, al, wt)

func _bt(ci, r: Rect2, lab: String, kind: String, id: String, tap: Callable, disabled := false, ic := "") -> void:
	if ci == null:
		return
	var rr := Rect2(r.position - Vector2(0, _sc(ci)), r.size)
	btn(ci, rr, lab, kind, ci.pressed(id), disabled, ic)
	if not disabled:
		ci.items.append({"r": r, "id": id, "sc": true, "tap": tap})

func _chip(ci, x: float, y: float, lab: String, ok: bool, fid := "", ic := "", pic := "") -> float:
	var fs := 12.0
	var iw := 0.0
	if fid != "":
		var t: Texture2D = A.img(fid)
		iw = 18.0 * t.get_size().x / t.get_size().y + 3 if t != null else 0.0
	elif ic != "" or pic != "":
		iw = 19.0
	var w := 2 + iw + A.tw(lab, fs) + 7
	if ci != null:
		var r := Rect2(x, y - _sc(ci), w, 20)
		A.box(ci, r, A.OKBG if ok else A.NOBG, 9)
		if fid != "":
			var t: Texture2D = A.img(fid)
			if t != null:
				A.fit(ci, t, Rect2(r.position.x + 2, r.position.y + 1, iw - 3, 18))
		elif ic != "":
			A.svg(ci, ic, Rect2(r.position.x + 2, r.position.y + 2, 16, 16))
		elif pic != "":
			A.pic(ci, pic, Rect2(r.position.x + 1, r.position.y, 20, 20))
		A.text(ci, lab, r.position.x + 2 + iw, r.get_center().y, fs, A.OKFG if ok else A.NOFG, 0, 800)
	return w

func _chips(ci, x: float, y: float, w: float, list: Array) -> float:   # list: [[lab, ok, fid, ic, pic]], trả về y dưới
	var cx := x
	var cy := y
	for c in list:
		var cw := _chip(null, 0, 0, c[0], c[1], c[2], c[3], c[4] if c.size() > 4 else "")
		if cx > x and cx + cw > x + w:
			cx = x
			cy += 24
		_chip(ci, cx, cy, c[0], c[1], c[2], c[3], c[4] if c.size() > 4 else "")
		cx += cw + 4
	return cy + 20

func _need_chips(need: Dictionary) -> Array:
	var out := []
	for id in need:
		var hv := basket_count(id)
		var n: int = need[id]
		out.append(["%s %d/%d" % [D.fish(id).name, mini(hv, n), n], hv >= n, id, ""])
	return out

# ------------------------------------------------------------ giỏ cá
func _b_basket(ci, w: float, y: float) -> float:
	var S: Dictionary = game.S
	if S.basket.is_empty():
		if ci != null:
			A.pic(ci, "cage", Rect2(w / 2 + 14 - 48, y + 20 - _sc(ci), 96, 96), Color(1, 1, 1, .85))
		_t(ci, "Giỏ trống trơn", w / 2 + 14, y + 20 + 96 + 6 + 10, 17, A.F_MUTED, 1)
		var yy := y + 20 + 96 + 6 + 22
		for ln in A.wrap("Cá câu được bỏ vô đây: bán lấy xu, hoặc để dành đổi đồ nghề.", 14, 600, w - 20):
			_t(ci, ln, w / 2 + 14, yy + 9, 14, A.SMALL2, 1, 600)
			yy += 18
		return yy + 20
	var tot := 0
	for i in S.basket.size():
		var c: Dictionary = S.basket[i]
		var f := D.fish(c.id)
		var val := D.fish_value(f, c.w)
		tot += val
		var r := Rect2(14, y, w, 58)
		_row(ci, r)
		_th(ci, Rect2(r.position.x + 8, r.position.y + 6, 72, 46), c.id)
		var lab := str(val)
		var bw := btn_w(lab, "coin")
		_t(ci, f.name, r.position.x + 90, r.position.y + 21, 15, A.INK)
		_t(ci, fmt_w(c.w) + " · ", r.position.x + 90, r.position.y + 39, 13, A.SMALL, 0, 600)
		if ci != null:
			draw_stars(ci, f.rar, r.position.x + 90 + A.tw(fmt_w(c.w) + " · ", 13, 600), r.position.y + 39 - _sc(ci))
		var idx = i
		_bt(ci, Rect2(r.end.x - 8 - bw, r.position.y + 10, bw, 38), lab, "gold", "sell%d" % i, func():
			var cc: Dictionary = S.basket[idx]
			sell([cc], body.position + Vector2(r.end.x - 8 - bw / 2, r.position.y + 10 - body.scroll))
			_open("basket"), false, "coin")
		y += 58 + 7
	var sr := Rect2(14, y + 6 - 7, w, 54)
	if ci != null:
		var rr := Rect2(sr.position - Vector2(0, _sc(ci)), sr.size)
		A.fbox(ci, rr, 12, [[0.0, A._c(247, 234, 208)], [1.0, A._c(241, 226, 192)]], [[1.0, A._c(150, 112, 48, .3)]], [2.0, Color(1, 1, 1, .6)])
	_t(ci, "Bán hết cho vựa", sr.position.x + 10, sr.get_center().y, 15, A.INK)
	var lab2 := str(tot)
	var bw2 := btn_w(lab2, "coin")
	_bt(ci, Rect2(sr.end.x - 10 - bw2, sr.position.y + 8, bw2, 38), lab2, "", "sellall", func():
		sell(S.basket.duplicate(), body.position + Vector2(sr.end.x - 10 - bw2 / 2, sr.position.y + 8 - body.scroll))
		_open("basket"), false, "coin")
	return sr.end.y + 4

func sell(list: Array, from: Vector2) -> void:
	var S: Dictionary = game.S
	var tot := 0
	for c in list:
		var i: int = S.basket.find(c)
		if i >= 0:
			S.basket.remove_at(i)
			tot += D.fish_value(D.fish(c.id), c.w)
	if tot == 0:
		return
	S.xu += tot
	fly_coins(int(ceil(tot / 20.0)), _to_screen(from))
	game.save(true)

func _to_screen(p: Vector2) -> Vector2:
	return p

func basket_count(id: String) -> int:
	var n := 0
	for c in game.S.basket:
		if c.id == id:
			n += 1
	return n

func has_fish(need: Dictionary) -> bool:
	for id in need:
		if basket_count(id) < need[id]:
			return false
	return true

func take_fish(need: Dictionary) -> void:
	var S: Dictionary = game.S
	for id in need:
		for k in need[id]:
			var best := -1
			for i in S.basket.size():
				var c: Dictionary = S.basket[i]
				if c.id == id and (best < 0 or c.w < S.basket[best].w):
					best = i
			if best >= 0:
				S.basket.remove_at(best)

# ------------------------------------------------------------ chợ: mồi + đổi đồ
func _b_shop(ci, w: float, y: float) -> float:
	var S: Dictionary = game.S
	if _mod.arg == "bait":
		var soon := []
		for k in D.BAIT_ORDER:
			var b: Dictionary = D.BAIT[k]
			if b.lv > S.lv:
				soon.append(k)
				continue
			var cur: bool = S.bait == k
			var have: String = "∞" if k == "trun" else str(int(S.baits.get(k, 0)))
			var acts := []   # [lab, kind, id, fn, disabled, ic]  hoặc "hook"
			if not cur and (k == "trun" or int(S.baits.get(k, 0)) > 0):
				var kk: String = k
				acts.append(["Móc mồi", "alt", "use" + k, func():
					S.bait = kk
					game.snd.ui()
					hud_dirty()
					close_modal()
					toast("Móc " + D.BAIT[kk].name, "info"), false, ""])
			elif cur:
				acts.append("hook")
			if b.pack:
				var kk: String = k
				acts.append(["Mua %d · @%d" % [b.pack, b.price], "gold", "buy" + k, func():
					var it: Dictionary = D.BAIT[kk]
					if S.xu < it.price:
						return
					S.xu -= it.price
					S.baits[kk] = int(S.baits.get(kk, 0)) + it.pack
					game.snd.coin(0)
					if S.bait == "trun":
						S.bait = kk
					hud_dirty()
					_open("shop", "bait"), S.xu < b.price, "coin"])
			var aw := 0.0
			for a in acts:
				aw = maxf(aw, A.tw("Đang móc", 13) + 20 if a is String else btn_w(a[0], a[5]))
			var tx := 14 + 8 + 72 + 10
			var txw := w - (tx - 14) - 8 - aw - 10
			var dl := A.wrap(b.desc, 13, 600, txw)
			var th := 15 * 1.15 + dl.size() * 13 * 1.2 + 13 * 1.25 + 4
			var ah := acts.size() * 38 + (acts.size() - 1) * 6
			var rh := maxf(maxf(58, th + 14), ah + 14)
			var r := Rect2(14, y, w, rh)
			_row(ci, r, cur)
			_th(ci, Rect2(r.position.x + 8, r.get_center().y - 23, 72, 46), "", k)
			var yy := r.get_center().y - th / 2 + 15 * .58
			_t(ci, b.name, tx, yy, 15, A.INK)
			yy += 15 * .6 + 13 * .6 + 2
			for ln in dl:
				_t(ci, ln, tx, yy, 13, A.SMALL, 0, 600)
				yy += 13 * 1.2
			_t(ci, "Đang có: ", tx, yy, 13, A.SMALL, 0, 600)
			_t(ci, have, tx + A.tw("Đang có: ", 13, 600), yy, 13, A.INK, 0, 800)
			var ay := r.get_center().y - ah / 2
			for a in acts:
				var ar := Rect2(r.end.x - 8 - aw, ay, aw, 38)
				if a is String:
					if ci != null:
						var rr := Rect2(ar.position - Vector2(0, _sc(ci)), Vector2(aw, 30))
						rr.position.y += 4
						A.fbox(ci, rr, 10, [[0.0, A._c(222, 240, 204)], [1.0, A._c(206, 232, 184)]], [[1.0, A._c(63, 116, 41, .5)]], [2.0, Color(1, 1, 1, .6)])
						A.text(ci, "Đang móc", rr.get_center().x, rr.get_center().y, 13, A.F_GREEN, 1, 800)
				else:
					_bt(ci, ar, a[0], a[1], a[2], a[3], a[4], a[5])
				ay += 44
			y += rh + 7
		if soon.size():
			var cols := maxi(1, int(floor((w - 16 + 6) / (92 + 6))))
			var cw := (w - 16 - (cols - 1) * 6) / cols
			var rows := int(ceil(soon.size() / float(cols)))
			var h := 8 + 13 * 1.3 + 6 + rows * 84 + (rows - 1) * 6 + 8
			if ci != null:
				var rr := Rect2(14, y - _sc(ci) + 4, w, h)
				_dash_rect(ci, rr, 14, A._c(150, 112, 48, .45))
			_t(ci, "Lên cấp mở thêm mồi", 14 + 10, y + 4 + 8 + 13 * .6, 13, A.SMALL2)
			for i in soon.size():
				var k: String = soon[i]
				var cx := 14 + 8 + (i % cols) * (cw + 6)
				var cy := y + 4 + 8 + 13 * 1.3 + 6 + int(i / cols) * 90
				if ci != null:
					var rr := Rect2(cx, cy - _sc(ci), cw, 84)
					A.fbox(ci, rr, 12, [[0.0, A._c(250, 243, 226)], [1.0, A._c(243, 233, 208)]], [[1.0, A._c(150, 112, 48, .18)]])
					A.pic(ci, k, Rect2(rr.get_center().x - 20, rr.position.y + 6, 40, 40), Color(.5, .5, .5, .45))
				_t(ci, D.BAIT[k].name, cx + cw / 2, cy + 6 + 40 + 9, 12, Color("#6a4a24"), 1)
				_t(ci, "Cấp %d" % D.BAIT[k].lv, cx + cw / 2, cy + 6 + 40 + 9 + 15, 11, Color("#a08050"), 1)
			y += h + 8
		return y
	# đổi đồ nghề
	for k in D.GEAR_KEYS:
		var list: Array = D.gear(k)
		var cur: int = S[k]
		var tx := 14 + 8 + 72 + 10
		var txw := w - (tx - 14) - 8
		if cur + 1 >= list.size():
			var r := Rect2(14, y, w, 64)
			_row(ci, r)
			_th(ci, Rect2(r.position.x + 8, r.get_center().y - 23, 72, 46), "", k)
			_t(ci, D.GEAR_NAME[k], tx, r.position.y + 14, 13, A.SMALL, 0, 600)
			_t(ci, list[cur].name, tx, r.position.y + 32, 16, A.INK)
			_t(ci, "Đồ xịn nhất rồi!", tx, r.position.y + 50, 13, A.SMALL, 0, 600)
			y += 64 + 7
			continue
		var nx: Dictionary = list[cur + 1]
		var ok_xu: bool = S.xu >= nx.price
		var ok_f: bool = not nx.has("need") or has_fish(nx.need)
		var dl := A.wrap(nx.desc, 13, 600, txw)
		if dl.size() > 2:
			dl = dl.slice(0, 2)
			dl[1] = dl[1] + "…"
		var chips := [[str(nx.price), ok_xu, "", "coin"]]
		if nx.has("need"):
			chips.append_array(_need_chips(nx.need))
		var ch_h := _chips(null, tx, 0, txw, chips)
		var rh := 6 + 13 * 1.25 + 16 * 1.3 + dl.size() * 13 * 1.2 + 3 + ch_h + 6 + 38 + 8
		var r := Rect2(14, y, w, rh)
		_row(ci, r)
		_th(ci, Rect2(r.position.x + 8, r.position.y + 8, 72, 46), "", k)
		var yy := r.position.y + 6 + 13 * .62
		_t(ci, D.GEAR_NAME[k], tx, yy, 13, A.SMALL, 0, 600)
		yy += 13 * .62 + 16 * .65
		var c1: String = list[cur].name + " "
		_t(ci, c1, tx, yy, 16, A.INK)
		var ax := tx + A.tw(c1, 16)
		_t(ci, "→ ", ax, yy, 16, A.BRICK)
		ax += A.tw("→ ", 16)
		_t(ci, nx.name, ax, yy, 16, Color("#2a5a12"))
		yy += 16 * .65 + 13 * .6
		for ln in dl:
			_t(ci, ln, tx, yy, 13, A.SMALL, 0, 600)
			yy += 13 * 1.2
		var cy := _chips(ci, tx, yy - 13 * .6 + 3, txw, chips)
		var ay := cy + 6
		if ok_xu and ok_f:
			var kk: String = k
			_bt(ci, Rect2(tx, ay, btn_w("Đổi"), 38), "Đổi", "", "up" + k, func():
				var nn: Dictionary = D.gear(kk)[S[kk] + 1]
				if S.xu < nn.price or (nn.has("need") and not has_fish(nn.need)):
					return
				S.xu -= nn.price
				if nn.has("need"):
					take_fish(nn.need)
				S[kk] += 1
				game.snd.fanfare(3)
				toast("Đổi được " + nn.name + "!", "good")
				hud_dirty()
				game.save(true)
				_open("shop", "gear"))
		else:
			var lab: String = ("Còn thiếu %d xu" % (nx.price - S.xu)) if not ok_xu else "Câu thêm cá"
			if ci != null:
				var lr := Rect2(tx, ay + 4 - _sc(ci), A.tw(lab, 12) + 24, 28)
				A.box(ci, lr, A._c(245, 232, 200), 10)
				_dash_rect(ci, lr, 10, A._c(150, 112, 48, .5))
				A.text(ci, lab, lr.get_center().x, lr.get_center().y, 12, A.SMALL, 1, 800)
		y += rh + 7
	var yy := y + 6
	for ln in A.wrap("Đồ nghề đổi bằng xu cộng cá trong giỏ. Cá hiếm nhớ để dành, đừng bán vội!", 14, 600, w - 12):
		_t(ci, ln, 14 + w / 2, yy + 9, 14, A.SMALL2, 1, 600)
		yy += 18
	return yy + 6

func _dash_rect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	var pts := A.rrect_pts(r, rad, 6)
	pts.append(pts[0])
	var acc := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var L2 := a.distance_to(b)
		var t := 0.0
		while t < L2:
			var on := fmod(acc + t, 9.0) < 5.0
			var step := minf(1.5, L2 - t)
			if on:
				ci.draw_line(a.lerp(b, t / L2), a.lerp(b, (t + step) / L2), col, 2)
			t += step
		acc += L2

# ------------------------------------------------------------ sổ cá
func _b_dex(ci, w: float, y: float) -> float:
	var S: Dictionary = game.S
	var sel = _mod.get("arg")
	if sel != null:
		var f := D.fish(sel)
		var d = S.dex.get(sel)
		var tw := w - 16
		var iw := minf(220, tw * .46)
		var tx := 14 + 8 + iw + 12
		var txw := w - (tx - 14) - 8
		var lines := []
		lines.append(["n", f.name if d != null else "???", 18])
		lines.append(["st", "", 14])
		lines.append_array(_p_lines(f.desc if d != null else "Chưa câu được.", txw))
		if not f.has("junk"):
			var best_t := "d"
			var bv := -1.0
			for kk in f.time:
				if f.time[kk] > bv:
					bv = f.time[kk]
					best_t = kk
			var best_b := ""
			var bb := -1.0
			for kk in f.bait:
				if f.bait[kk] > bb:
					bb = f.bait[kk]
					best_b = kk
			var tm: String = {"d": "ban ngày", "dd": "rạng sáng, chạng vạng", "n": "ban đêm"}[best_t]
			var zn := "giữa kênh xa" if f.zone[0] > 15 else ("sát mé" if f.zone[1] < 12 else "tầm giữa")
			var s := "Gợi ý: %s, %s%s%s." % [tm, zn, ", gần lục bình" if f.has("cover") else "", (", mồi " + D.BAIT[best_b].name.to_lower()) if best_b != "" else ""]
			lines.append_array(_p_lines(s, txw))
		if d != null:
			lines.append_array(_p_lines("Đã câu %d lần · con lớn nhất %s" % [int(d.n), fmt_w(float(d.best))], txw))
		var th := 0.0
		for ln in lines:
			th += ln[2] * 1.25 if ln[0] != "p" else 13 * 1.3
		var t: Texture2D = A.img(sel)
		var ih := iw * t.get_size().y / t.get_size().x if t != null else 40.0
		var rh := maxf(th, ih) + 16
		var r := Rect2(14, y, w, rh)
		_row(ci, r)
		if ci != null and t != null:
			var ir := Rect2(r.position.x + 8, r.get_center().y - ih / 2 - _sc(ci), iw, ih)
			ci.draw_texture_rect(t, ir, false, Color.WHITE if d != null else Color(0, 0, 0, .3))
		var yy := r.get_center().y - th / 2
		for ln in lines:
			match ln[0]:
				"n":
					_t(ci, ln[1], tx, yy + 18 * .62, 18, A.INK)
					yy += 18 * 1.25
				"st":
					if ci != null:
						var sw := draw_stars(ci, f.rar, tx, yy + 8 - _sc(ci), 12)
						A.text(ci, " " + D.RAR[f.rar], tx + sw, yy + 8 - _sc(ci), 12, A.SMALL2, 0, 800)
					yy += 14 * 1.25
				"p":
					_t(ci, ln[1], tx, yy + 13 * .62, 13, A.F_BROWN, 0, 600)
					yy += 13 * 1.3
		y += rh + 10
	var cols := maxi(1, int(floor((w + 8) / (112 + 8))))
	var cw := (w - (cols - 1) * 8) / cols
	var ch := 6 + 54 + 4 + 13 * 1.1 + 12 + 13 + 6
	for i in D.FISH.size():
		var f: Dictionary = D.FISH[i]
		var d = S.dex.get(f.id)
		var x := 14 + (i % cols) * (cw + 8)
		var cy := y + int(i / cols) * (ch + 8)
		var r := Rect2(x, cy, cw, ch)
		if ci != null:
			var rr := Rect2(r.position - Vector2(0, _sc(ci)), r.size)
			# (11-23) ô = thẻ .khb của Kho Nông trại; cá hiếm viền màu độ hiếm
			var bc := Color(0, 0, 0, 0)
			match int(f.rar):
				2: bc = Color("#6aa0d8")
				3: bc = Color("#b070d8")
				4: bc = Color("#e0a020")
			var dn: bool = ci.pressed("f" + f.id)
			var cr := Rect2(rr.position + Vector2(0, 1.5 if dn else 0), rr.size)
			if bc.a > 0:
				A.fbox(ci, cr, 14, [[0.0, A._c(255, 252, 244)], [1.0, A._c(247, 236, 212) if f.rar < 4 else A._c(252, 238, 196)]], [[2.0, bc]], [2.0, Color(1, 1, 1, .85)], [], [] if dn else [[0, 2, 0, Color(bc, .45)], [0, 3, 5, A._c(90, 60, 20, .1)]])
			else:
				A.card(ci, cr)
			var im := Rect2(cr.position.x + 6, cr.position.y + 6, cw - 12, 54)
			A.fbox(ci, im, 10, [[0.0, A._c(247, 238, 214)], [1.0, A._c(239, 226, 192)]], [[1.0, A._c(150, 112, 48, .22)]])
			var t: Texture2D = A.img(f.id)
			if t != null:
				A.fit(ci, t, Rect2(im.position.x + 2, im.position.y + 1, im.size.x - 4, 52), Color.WHITE if d != null else Color(0, 0, 0, .28))
			var nm: String = f.name if d != null else "???"
			var fs := 13.0
			while A.tw(nm, fs) > cw - 8 and fs > 10:
				fs -= .5
			A.text(ci, nm, rr.get_center().x, im.end.y + 4 + 7, fs, A.F_BROWN, 1, 800)
			draw_stars(ci, f.rar, rr.get_center().x, im.end.y + 4 + 13 * 1.1 + 6, 11, Color("#e0a020"), 1)
			if d != null:
				A.text(ci, fmt_w(float(d.best)), rr.get_center().x, im.end.y + 4 + 13 * 1.1 + 12 + 8, 11, A.SMALL2, 1, 600)
			var fid: String = f.id
			ci.items.append({"r": r, "id": "f" + fid, "sc": true, "tap": func(): game.snd.ui(); _open("dex", fid); body.scroll = 0})
	var rows := int(ceil(D.FISH.size() / float(cols)))
	return y + rows * (ch + 8)

func _p_lines(s: String, w: float) -> Array:
	var out := []
	for ln in A.wrap(s, 13, 600, w):
		out.append(["p", ln, 13])
	return out

# ------------------------------------------------------------ cài đặt
func _b_set(ci, w: float, y: float) -> float:
	var S: Dictionary = game.S
	var rows := [
		["Âm thanh", "Tiếng nước, chim, côn trùng", "sw", S.sound == 1, func(): game.snd.set_sound(S.sound != 1); _open("set")],
		["Nhạc đàn tranh", "Vài câu đờn nhẹ nhàng", "sw", S.music == 1, func(): game.snd.set_music(S.music != 1); _open("set")],
		["Thống kê", "Quăng %d lần · câu được %d · đứt dây %d" % [S.stats.casts, S.stats.catches, S.stats.snaps], "", false, Callable()],
		["Chơi lại từ đầu", "Xóa hết xu, cá, đồ nghề", "reset", false, func():
			if _sure:
				_sure = false
				game.reset_save()
				close_modal()
				hud_dirty()
				toast("Chơi lại từ đầu nha", "info")
			else:
				_sure = true
				_open("set")],
	]
	if game.embed:
		rows.append(["Về vườn", "Thôi câu, về lại nông trại", "home", false, func(): close_modal(); game.close_game()])
	for rw in rows:
		var aw := 124.0   # Bật | Tắt (.seg của Cài đặt Nông trại)
		if rw[2] == "reset":
			aw = btn_w("Chắc chưa?" if _sure else "Xóa")
		elif rw[2] == "home":
			aw = btn_w("Về vườn", "home")
		elif rw[2] == "":
			aw = 0.0
		var txw := w - 16 - aw - (10 if aw > 0 else 0)
		var sl := A.wrap(rw[1], 13, 600, txw)
		var th := 15 * 1.2 + sl.size() * 13 * 1.2
		var rh := maxf(52, th + 14)
		var r := Rect2(14, y, w, rh)
		_row(ci, r)
		var yy := r.get_center().y - th / 2 + 15 * .6
		_t(ci, rw[0], r.position.x + 10, yy, 15, A.INK)
		yy += 15 * .6 + 13 * .6
		for ln in sl:
			_t(ci, ln, r.position.x + 10, yy, 13, A.SMALL, 0, 600)
			yy += 13 * 1.2
		var ar := Rect2(r.end.x - 8 - aw, r.get_center().y - 18, aw, 36)
		match rw[2]:
			"sw":
				var hw := (aw - 4) / 2
				for j in 2:
					var on: bool = rw[3] == (j == 0)
					var sr := Rect2(ar.position.x + j * (hw + 4), ar.position.y, hw, 36)
					if on:
						if ci != null:
							btn(ci, Rect2(sr.position - Vector2(0, _sc(ci)), sr.size), ["Bật", "Tắt"][j], "", false, false, "", 14)
					else:
						_bt(ci, sr, ["Bật", "Tắt"][j], "alt", "sw%d%s" % [j, rw[0]], rw[4])
			"reset":
				_bt(ci, Rect2(ar.position.x, ar.position.y - 1, aw, 38), "Chắc chưa?" if _sure else "Xóa", "alt", "reset", rw[4])
			"home":
				_bt(ci, Rect2(ar.position.x, ar.position.y - 1, aw, 38), "Về vườn", "", "home", rw[4], false, "home")
		y += rh + 7
	return y

func open_basket() -> void:
	_open("basket")
func open_shop(tab := "bait") -> void:
	_open("shop", tab)
func open_dex(sel = null) -> void:
	_open("dex", sel)
func open_settings() -> void:
	_sure = false
	_open("set")

# ============================================================ thẻ cá câu được
func show_catch(o: Dictionary) -> void:
	_card = o
	_card_t = 0.0
	card.visible = true

func _card_done() -> void:
	card.visible = false
	_card = {}
	game.set_state("idle")
	hud_dirty()
	game.save(true)

func _draw_card(ci: Box) -> void:
	ci.items = []
	if _card.is_empty():
		return
	var S: Dictionary = game.S
	var f: Dictionary = _card.f
	var junk := f.has("junk")
	var cap: int = D.CAGE[S.cage].cap
	var full: bool = S.basket.size() >= cap
	A.under_rect(ci, Rect2(0, 0, L.W, L.H), Color(10 / 255.0, 24 / 255.0, 12 / 255.0, .45))
	var cw := minf(400, L.W - 32)
	var short := low()
	var img_h := 120.0 if short else 170.0
	var desc := A.wrap(f.desc, 14, 600, cw - 32)
	var acts := []
	if junk:
		acts.append(["Bỏ thùng rác · +phước", "", "junk", ""])
	else:
		if not full:
			acts.append(["Bỏ giỏ", "", "keep", "basket"])
		acts.append(["Bán liền %d" % _card.val, "gold", "sell", "coin"])
		acts.append(["Thả về", "alt", "free", ""])
	# xếp nút theo hàng (flex-wrap)
	var rows_b := [[]]
	var rwid := 0.0
	for a in acts:
		var bw := btn_w(a[0], a[3])
		if rwid > 0 and rwid + 8 + bw > cw - 32:
			rows_b.append([])
			rwid = 0.0
		rows_b[rows_b.size() - 1].append([a, bw])
		rwid += (8 if rwid > 0 else 0) + bw
	var tags := []
	if _card.isNew:
		tags.append(["Loài mới!", A.F_RED])
	if _card.rec and not _card.isNew and not junk:
		tags.append(["Kỷ lục!", Color("#e09a20")])
	var h := 16 + 8 + img_h + 2 + 34 * 1.0 + (6 + 20 + 6 if tags.size() else 8) + 46 + 4 + 6 + desc.size() * 14 * 1.3 + 10 + rows_b.size() * 46 + 14
	if full and not junk:
		h += 8 + 14 * 1.3
	var k := clampf(_card_t / .5, 0, 1)
	var e := 1 - pow(1 - k, 3) + sin(k * PI) * .12
	var c := Vector2(L.W / 2, L.H / 2)
	var xf := Transform2D(lerpf(-8, 0, e) * PI / 180, Vector2(lerpf(.4, 1, e), lerpf(.4, 1, e)), 0, c)
	var r := Rect2(-cw / 2, -h / 2, cw, h)
	ci.draw_set_transform_matrix(xf)
	# tia nắng xoay sau thẻ
	var rays_c := Vector2(0, -h / 2 + 120)
	var ra := (1.0 if f.rar >= 3 else .6) * k
	var rot := _card_t / 14.0 * TAU
	for i in 18:
		var a0 := rot + i * TAU / 18
		var a1 := a0 + TAU / 36
		var pts := PackedVector2Array([rays_c])
		var cols := PackedColorArray([Color(1, 220 / 255.0, 120 / 255.0, .5 * ra)])
		for j in 5:
			var a := lerpf(a0, a1, j / 4.0)
			pts.append(rays_c + Vector2(cos(a), sin(a)) * 280 * .62)
			cols.append(Color(1, 220 / 255.0, 120 / 255.0, 0))
		var mid := PackedVector2Array([rays_c])
		var mcols := PackedColorArray([Color(1, 220 / 255.0, 120 / 255.0, .5 * ra)])
		for j in 5:
			var a := lerpf(a0, a1, j / 4.0)
			mid.append(rays_c + Vector2(cos(a), sin(a)) * 280 * .25)
			mcols.append(Color(1, 220 / 255.0, 120 / 255.0, .5 * ra))
		A.under_poly(ci, pts, cols, xf)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	# (11-23) thẻ = bảng Nông trại: bóng, nền giấy kem (dưới các ô số đo), khung tre
	A.fbox(ci, r, Tre.R, [], [], [], [], [[0, 6, 30, Color(0, 0, 0, .3)]], xf)
	A.under_tex(ci, A.paper(r.size.x, r.size.y, Tre.R), r, xf)
	ci.draw_set_transform_matrix(xf)
	var fr := r.grow(1.5)
	ci.draw_texture_rect(Tre.texture(fr.size.x, fr.size.y), fr, false)
	# băng độ hiếm
	var rl: String = D.RAR[f.rar]
	var nst := 0 if junk else maxi(1, f.rar)
	var stw := (6 + nst * 18 * .92) if nst > 0 else 0.0
	var rw := A.tw(rl, 18) + stw + 52
	var rb := Rect2(-rw / 2, r.position.y - 16, rw, 30)
	var rc := Color(D.RAR_COL[f.rar])
	var pts := PackedVector2Array([rb.position, Vector2(rb.end.x, rb.position.y), Vector2(rb.end.x - 12, rb.get_center().y), rb.end, Vector2(rb.position.x, rb.end.y), Vector2(rb.position.x + 12, rb.get_center().y)])
	var sh := pts.duplicate()
	for i in sh.size():
		sh[i] += Vector2(0, 3)
	ci.draw_colored_polygon(sh, Color(0, 0, 0, .25))
	ci.draw_colored_polygon(pts, rc)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	var rtx := -(A.tw(rl, 18) + stw) / 2
	A.text(ci, rl, rtx, rb.get_center().y + 1, 18, Color(0, 0, 0, .3), 0, 800, 0.0, A.INK, xf)
	A.text(ci, rl, rtx, rb.get_center().y, 18, Color.WHITE, 0, 800, 0.0, A.INK, xf)
	for si in nst:
		var sc2 := xf * Vector2(rtx + A.tw(rl, 18) + 6 + 18 * .92 * (si + .5), rb.get_center().y)
		ci.draw_colored_polygon(A.star_pts(sc2, 18 * .42 * xf.get_scale().x, 18 * .18 * xf.get_scale().x), Color.WHITE)
	var y := r.position.y + 16 + 8
	# hình cá lắc lư
	var t: Texture2D = A.img(f.id)
	if t != null:
		var fl := sin(_card_t / 1.6 * TAU) * .5 + .5
		var iw := minf(cw - 32, img_h * t.get_size().x / t.get_size().y)
		var ih := iw * t.get_size().y / t.get_size().x
		var ic := Vector2(0, y + img_h / 2 - 4 * fl)
		var fxf := xf * Transform2D(-3 * fl * PI / 180, ic)
		ci.draw_set_transform_matrix(fxf)
		ci.draw_texture_rect(t, Rect2(-iw / 2, -ih / 2 + 8, iw, ih), false, Color(0, 0, 0, .22))
		ci.draw_texture_rect(t, Rect2(-iw / 2, -ih / 2, iw, ih), false)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	y += img_h + 2
	A.text(ci, f.name, 0, y + 17, 32 if A.tw(f.name, 32) < cw - 24 else 26, A.F_INK, 1, 800, 0.0, A.INK, xf)
	y += 34
	if tags.size():
		y += 6
		var tw := 0.0
		for tg in tags:
			tw += A.tw(tg[0], 13) + 18 + 6
		var x := -tw / 2 + 3
		for tg in tags:
			var ww := A.tw(tg[0], 13) + 18
			A.box(ci, Rect2(x, y, ww, 20).grow(1.5), A.F_RED_RING, 11.5, 0, Color(0, 0, 0, 0), [], xf)
			A.box(ci, Rect2(x, y, ww, 20), tg[1], 10, 0, Color(0, 0, 0, 0), [], xf)
			A.text(ci, tg[0], x + ww / 2, y + 10, 13, Color.WHITE, 1, 800, 0.0, A.INK, xf)
			x += ww + 6
		y += 20 + 6
	else:
		y += 8
	# số đo
	var stats := [[fmt_w(_card.w), "cân nặng"]]
	if not junk:
		stats.append(["%d cm" % _card.cm, "dài"])
	stats.append(["+%d" % _card.xp, "kinh nghiệm"])
	var sws := []
	var tot := 0.0
	for s in stats:
		var ww := maxf(A.tw(s[0], 18), A.tw(s[1], 11, 700)) + 24
		sws.append(ww)
		tot += ww
	tot += (stats.size() - 1) * 8
	var sx := -tot / 2
	for i in stats.size():
		var sr := Rect2(sx, y, sws[i], 46)
		_push(ci, xf)
		A.card(ci, sr, false, 12)
		_pop(ci)
		A.text(ci, stats[i][0], sr.get_center().x, sr.position.y + 4 + 18 * .6, 18, A.F_BROWN, 1, 800, 0.0, A.INK, xf)
		A.text(ci, stats[i][1], sr.get_center().x, sr.position.y + 4 + 18 * 1.05 + 11 * .6, 11, A.SMALL2, 1, 700, 0.0, A.INK, xf)
		sx += sws[i] + 8
	y += 46 + 4 + 6
	for ln in desc:
		A.text(ci, ln, 0, y + 14 * .65, 14, A.F_BROWN, 1, 600, 0.0, A.INK, xf)
		y += 14 * 1.3
	y += 10
	var cf := func(id: String) -> void:
		var G2: Dictionary = game.G
		match id:
			"junk":
				game.snd.ui()
				toast("Kênh sạch thêm chút, phước tăng!", "good")
				_card_done()
			"keep":
				game.snd.ui()
				S.basket.append({"id": f.id, "w": _card.w})
				_card_done()
				if S.tut < 4:
					S.tut = 4
					game.later(.4, func(): toast("Cá trong giỏ: bán ở Giỏ cá, hoặc để dành đổi đồ ở Chợ", "info"))
			"sell":
				S.xu += _card.val
				fly_coins(int(ceil(_card.val / 15.0)), Vector2(L.W / 2, L.H / 2 + 100))
				_card_done()
			"free":
				game.snd.ui()
				S.luck = minf(10, S.luck + .5)
				toast("Thả cá về sông, may mắn tăng", "good")
				game.fx_splash(0, game.L.zEdge + 1, .6)
				_card_done()
	for row in rows_b:
		var w := 0.0
		for a in row:
			w += a[1]
		w += (row.size() - 1) * 8
		var x := -w / 2
		for a in row:
			var br := Rect2(x, y, a[1], 38)
			var sr := Rect2(xf * br.position, br.size * xf.get_scale())
			_push(ci, xf)
			btn(ci, br, a[0][0], a[0][1], ci.pressed(a[0][2]), false, a[0][3])
			_pop(ci)
			var id: String = a[0][2]
			ci.items.append({"r": sr, "id": id, "tap": func(): cf.call(id)})
			x += a[1] + 8
		y += 46
	if full and not junk:
		A.text(ci, "Giỏ đầy rồi! Bán bớt hoặc đổi giỏ lớn hơn.", 0, y + 8 + 14 * .6, 14, Color("#a8401a"), 1, 600, 0.0, A.INK, xf)

# ============================================================ màn đầu
func show_title() -> void:
	_title_on = true
	_title_t = 0.0
	title.visible = true

func hide_title() -> void:
	_title_on = false
	title.visible = false

func _draw_title(ci: Box) -> void:
	ci.items = []
	var n := nar()
	var dk := Color(20 / 255.0, 14 / 255.0, 6 / 255.0)
	A.under_poly(ci, PackedVector2Array([Vector2.ZERO, Vector2(L.W, 0), Vector2(L.W, L.H), Vector2(0, L.H)]), PackedColorArray([Color(dk, .15), Color(dk, .15), Color(dk, .55), Color(dk, .55)]))
	# bảng hiệu treo
	var fs := 44.0 if n else clampf(L.W * .1, 44, 92)
	if low():
		fs = minf(fs, maxf(40, L.H * .13))
	var l1 := "Câu Cá"
	var l2 := "Bờ Kênh"
	var one = not n and A.tw(l1 + " " + l2, fs, 900) + 68 < L.W - 40
	var lw := (maxf(A.tw(l1, fs, 900), A.tw(l2, fs, 900)) if not one else A.tw(l1 + " " + l2, fs, 900)) + (52 if n else 68)
	var lh := fs * 1.02 * (1 if one else 2) + 12 + 30 + (30 if n else 34)
	var sub := "MIỆT VƯỜN · NÔNG TRẠI"
	var sfs := fs * .32
	var sw := A.tw(sub, sfs, 800) + sub.length() * 3 + 28
	lw = maxf(lw, sw + (52 if n else 68))
	var how_n := 3
	var how_w := minf(340, L.W * .92) if n else 200.0
	var how_h := 62.0
	for ht in ["Chạm mặt nước chỗ muốn thả. Chỗ sủi tăm, gần lục bình hay có cá lớn.", "Phao nhấp thì ráng chờ. Chìm hẳn, kéo ngang hay nằm ra thì GIẬT.", "Giữ để kéo vô. Dây đỏ hay cá phóng lên thì thả tay."]:
		how_h = maxf(how_h, 17 * 1.1 + A.wrap(ht, 13, 700, how_w - 72).size() * 13 * 1.25 + 16)
	var how_rows := 3 if n else (1 if 3 * 200 + 20 <= minf(660, L.W - 40) else 2)
	var col_how := n
	var hb_h := (how_h * 3 + 20) if col_how else (how_h * how_rows + 10 * (how_rows - 1))
	var go_h := 58.0
	var side = low() and game.embed   # màn thấp (nằm ngang): Về vườn nằm cạnh Ra bờ kênh
	var total := 40 + lh + 14 + hb_h + 14 + go_h + (14 + 40 if game.embed and not side else 0)
	var y := maxf(20, (L.H - total) / 2) + 40
	var lr := Rect2(L.W / 2 - lw / 2, y, lw, lh)
	# dây treo
	for sx in [.22, .78]:
		var px = lr.position.x + lr.size.x * sx
		var ang := (8 if sx < .5 else -8) * PI / 180
		ci.draw_set_transform(Vector2(px, lr.position.y + 4), ang)
		A.grad_poly(ci, PackedVector2Array([Vector2(-2, -50), Vector2(2, -50), Vector2(2, 0), Vector2(-2, 0)]), Vector2(0, -50), Vector2.ZERO, [[0.0, Color("#c8a46a")], [1.0, Color("#8a6434")]])
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	A.box(ci, Rect2(lr.position + Vector2(0, 7), lr.size), Color("#2a1606"), 18)
	A.box(ci, lr, Color("#a8622c"), 18, 4, A.WOOD2)
	# vân ván gỗ
	var yy := lr.position.y + 4 + 38
	while yy < lr.end.y - 6:
		ci.draw_rect(Rect2(lr.position.x + 4, yy, lr.size.x - 8, 3), Color(60 / 255.0, 26 / 255.0, 6 / 255.0, .35))
		yy += 44
	ci.draw_rect(Rect2(lr.position.x + 10, lr.position.y + 4, lr.size.x - 20, 4), Color(1, 215 / 255.0, 160 / 255.0, .3))
	var ty := lr.position.y + (16 if n else 18) + fs * .51
	var tc := Color("#fff2c4")
	var sh1 := Color("#6a2e0c")
	if one:
		A.text(ci, l1 + " " + l2, L.W / 2, ty + 3, fs, sh1, 1, 900)
		A.text(ci, l1 + " " + l2, L.W / 2, ty, fs, tc, 1, 900)
		ty += fs * 1.02
	else:
		for s in [l1, l2]:
			A.text(ci, s, L.W / 2, ty + 3, fs, sh1, 1, 900)
			A.text(ci, s, L.W / 2, ty, fs, tc, 1, 900)
			ty += fs * 1.02
	var sr := Rect2(L.W / 2 - sw / 2, ty - fs * .51 + 12, sw, sfs * 1.4 + 7)
	A.box(ci, sr, Color("#4a2a12"), sr.size.y / 2)
	_spaced(ci, sub, sr.get_center().x, sr.get_center().y, sfs, Color("#f6e2b0"), 3)
	y = lr.end.y + 14 + 7
	# ba ô hướng dẫn
	var hows := [["how1", "Quăng câu", "Chạm mặt nước chỗ muốn thả. Chỗ sủi tăm, gần lục bình hay có cá lớn."],
		["how2", "Canh phao", "Phao nhấp thì ráng chờ. Chìm hẳn, kéo ngang hay nằm ra thì GIẬT."],
		["how3", "Kéo cá", "Giữ để kéo vô. Dây đỏ hay cá phóng lên thì thả tay."]]
	var per_row := 1 if col_how else (3 if how_rows == 1 else 2)
	for i in how_n:
		var rw := how_w
		var row := int(i / per_row)
		var colx := i % per_row
		var cnt := mini(per_row, how_n - row * per_row)
		var x0 = L.W / 2 - (cnt * rw + (cnt - 1) * 10) / 2
		var hr := Rect2(x0 + colx * (rw + 10), y + row * (how_h + 10), rw, how_h)
		A.card(ci, hr)   # (11-23) ô .khb của Nông trại
		var ir := Rect2(hr.position.x + 10, hr.get_center().y - 22, 44, 44)
		A.fbox(ci, ir, 10, [[0.0, A._c(247, 238, 214)], [1.0, A._c(239, 226, 192)]], [[1.0, A._c(150, 112, 48, .22)]])
		A.svg(ci, hows[i][0], ir.grow(-4))
		var txw := rw - 10 - 44 - 8 - 10
		var pl := A.wrap(hows[i][2], 13, 700, txw)
		var th := 17 * 1.1 + pl.size() * 13 * 1.25
		var tyy := hr.get_center().y - th / 2 + 17 * .55
		A.text(ci, hows[i][1], ir.end.x + 8, tyy, 17, A.F_INK, 0, 800)
		tyy += 17 * .55 + 13 * .65
		for ln in pl:
			A.text(ci, ln, ir.end.x + 8, tyy, 13, A.F_BROWN, 0, 600)
			tyy += 13 * 1.25
	y += hb_h + 14
	var gw := btn_w("Ra bờ kênh", "", 26) + 56
	var hw := btn_w("Về vườn", "home", 16)
	var gx = L.W / 2 - gw / 2 - ((hw + 14) / 2 if side else 0.0)
	var gr := Rect2(gx, y, gw, go_h)
	_big_btn(ci, gr, "Ra bờ kênh", ci.pressed("go"))
	ci.items.append({"r": gr, "id": "go", "tap": func(): game.start_game()})
	if game.embed:
		var hr2 := Rect2(gr.end.x + 14, gr.get_center().y - 20, hw, 40) if side else Rect2(L.W / 2 - hw / 2, gr.end.y + 14, hw, 40)
		btn(ci, hr2, "Về vườn", "alt", ci.pressed("home"), false, "home", 16)
		ci.items.append({"r": hr2, "id": "home", "tap": func(): game.snd.ui(); game.close_game()})

func _big_btn(ci: CanvasItem, r: Rect2, lab: String, down: bool) -> void:
	# (11-23) nút xanh lá của Nông trại (btn primary), cỡ lớn
	A.fbtn_bg(ci, r, "", down, false, 16)
	var rr := Rect2(r.position + Vector2(0, 1.5 if down else 0.0), r.size)
	A.text(ci, lab, rr.get_center().x, rr.get_center().y, 26, Color.WHITE, 1, 800)

func _spaced(ci: CanvasItem, s: String, cx: float, cy: float, fs: float, col: Color, sp: float) -> void:
	var tw := 0.0
	for ch in s:
		tw += A.tw(ch, fs) + sp
	tw -= sp
	var x := cx - tw / 2
	for ch in s:
		A.text(ci, ch, x, cy, fs, col, 0, 800)
		x += A.tw(ch, fs) + sp
