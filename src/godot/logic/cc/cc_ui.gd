extends Control
# CÂU CÁ BỜ KÊNH: giao diện (09_ui.js + CSS của shell.html), vẽ tay bằng Godot, đo theo css px của web:
# thanh trên (xu, cấp, đồng hồ, cài đặt), mồi đang móc, Giỏ cá / Chợ / Sổ cá, nút nón lá Quăng / Chờ / Giật / Giữ
# có vòng căng dây, khung đồng hồ khi kéo cá, lời báo, chữ to giữa màn, lời nhắc, viền đỏ,
# hộp thoại (giỏ, chợ mồi + đổi đồ, sổ cá, cài đặt), thẻ cá câu được, màn đầu, lên cấp, xu bay.

const A := preload("res://logic/cc/cc_art.gd")
const D := preload("res://logic/cc/cc_data.gd")
const Tre := preload("res://logic/cc/cc_tre.gd")
const TM := preload("res://logic/cc/cc_toanman.gd")

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
var _bsel := -1          # ô cá đang chọn trong giỏ
var _sell_sure := false  # đã chạm Bán hết 1 lần
var _kho_err := ""   # Kho vườn đầy: hiện đỏ ở lời nhắc dưới giá (toast nằm dưới bảng, không thấy)
var _ssel := ""          # ô đang chọn trong Chợ (mã mồi / mã đồ nghề); "" = mặc định
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
			hk = "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%d|%d" % [S.xu, S.lv, S.xp, fmt_h(S.hour, game.host != null), game.W.rain > .4,
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

static func fmt_h(h: float, farm := false) -> String:
	var hh := int(floor(h))
	if farm:   # trong vườn: y như đồng hồ vườn (ui._clock)
		return "%02d:%02d" % [hh, int(floor((h - hh) * 60.0))]
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
	# (11-25) phước: dưới ô xu, chạm xem giải thích
	var pt := "Phước %d/10" % int(floor(float(S.luck)))
	var pr := Rect2(12, top + ph + 8, 4 + ics * .8 + 6 + A.tw(pt, fs * .85, 800) + 12, ph * .8)
	met(ci, pr, pr.size.y / 2, ci.pressed("phuoc"))
	A.svg(ci, "phuoc", Rect2(pr.position.x + 5, pr.get_center().y - ics * .4, ics * .8, ics * .8))
	A.text(ci, pt, pr.position.x + 5 + ics * .8 + 6, pr.get_center().y - 1, fs * .85, A.F_BROWN, 0, 800)
	ci.items.append({"r": pr, "id": "phuoc", "tap": func():
		_ui_tap()
		toast("Phước %d: cá hiếm dễ dính hơn %d%%. Vớt rác, thả cá để tăng; câu được cá hiếm tốn 2 phước." % [int(S.luck), int(floor(float(S.luck))) * 4], "info")})
	# cấp + thanh kinh nghiệm (bản 534: chỉ bản chơi riêng; trong vườn câu cá dùng cấp vườn, khỏi hiện)
	if game.host == null:
		_hud_lv(ci, xr, top, ph, n)
	# cài đặt
	var ib := 40.0 if n else 44.0
	var sr := Rect2(L.W - 12 - ib, top, ib, ib)
	met(ci, sr, ib / 2, ci.pressed("set"))
	A.svg(ci, "cog", Rect2(sr.get_center() - Vector2(13, 13) * (ib / 44), Vector2(26, 26) * (ib / 44)))
	ci.items.append({"r": sr, "id": "set", "tap": func(): _ui_tap(); open_settings()})
	# (Link 11-23 "gắn nút toàn màn hình dưới ô cài đặt") cùng kiểu ô, bật/tắt toàn màn như Nông trại (cc_toanman.gd).
	# Trình duyệt không cho (iPhone Safari, khung nhúng) thì không hiện nút.
	if TM.co() and st != "fight":   # lúc kéo cá khung kéo nằm ngang chỗ này
		var fr := Rect2(sr.position.x, sr.end.y + 8, ib, ib)
		var on := TM.dang_bat()
		met(ci, fr, ib / 2, ci.pressed("full"))
		A.svg(ci, "full_off" if on else "full", Rect2(fr.get_center() - Vector2(12, 12) * (ib / 44), Vector2(24, 24) * (ib / 44)))
		ci.items.append({"r": fr, "id": "full", "tap": func():
			_ui_tap()
			if TM.dang_bat():
				TM.tat()
			else:
				TM.bat()
			game.later(.4, func(): hud_dirty())})
	# đồng hồ
	var h: float = S.hour
	var rain: bool = game.W.rain > .4
	var ic := "rain" if rain else ("sun" if h >= 5.6 and h < 18.8 else "moon")
	var ts := fmt_h(h, game.host != null)
	var sm := "" if n else ("Mưa" if rain else D.phase_name(h))
	if game.host != null and game.host.has("wx"):
		sm = str(game.host.wx.call())
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
	# (Link 11-23 "chip mồi đè nút Quăng"): chip dài quá mép trái vòng nút Quăng thì thu ảnh mồi + xuống dòng từng chữ cho vừa
	var lim: float = L.W / 2 - _act_d2() / 2 - 9 - 4
	var ipad := 6.0
	if 12 + bw > lim:
		# tên mồi tối đa 2 dòng (chữ dài nhất "Trái sung" ~62): ảnh mồi nhỏ lại cho vừa chỗ
		ipad = 4.0
		var cap: float = lim - 12
		icb = clampf(cap - (ipad + 5 + 6) - 62, 22, 30)
		var room: float = cap - (ipad + icb + 5 + 6)
		lines = A.wrap(nm, bfs, 800, room)
		tw = A.tw(sub, sfs, 700)
		for ln in lines:
			tw = maxf(tw, A.tw(ln, bfs))
		bw = minf(ipad + icb + 5 + tw + 6, cap)
	var bhh := maxf(bh, lines.size() * bfs * 1.05 + sfs * 1.1 + 10)
	var bb := Rect2(12, L.H - 12 - bhh - 4, bw, bhh)
	var fa := 0.0 if fighting else 1.0
	if not fighting:
		var dn := ci.pressed("bait")
		met(ci, bb, 16, dn)
		var ir := Rect2(bb.position.x + ipad, bb.get_center().y - icb / 2 + (2 if dn else 0) - 2, icb, icb)
		A.fbox(ci, ir, 10, [[0.0, A._c(247, 238, 214)], [1.0, A._c(239, 226, 192)]], [[1.0, A._c(150, 112, 48, .3)]])
		A.pic(ci, S.bait, ir.grow(-3))
		var tx := ir.end.x + (5 if ipad < 6 else 8)
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
		var vk: bool = game.host != null and game.host.has("free")   # (bản 537) trong vườn: cá vô Kho
		var menu := [["basket", "Kho" if vk else "Giỏ cá", func(): open_basket()], ["shop", "Chợ", func(): open_shop("bait")], ["book", "Sổ cá", func(): open_dex()]]
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
			if id == "basket" and not vk and S.basket.size() > 0:
				var cnt := str(S.basket.size())
				A.badge(ci, Vector2(r.end.x - 4, r.position.y + 4), cnt, 12.0)
	_draw_act(ci)

func _hud_lv(ci: Box, xr: Rect2, top: float, ph: float, n: bool) -> void:   # ô "Cấp N" + thanh kinh nghiệm (bản chơi riêng)
	var S: Dictionary = game.S
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

func _act_d2() -> float:   # cỡ nút Quăng, cùng luật với _draw_act
	var d := 84.0 if nar() else 92.0
	if low():
		d = 76.0
	if big():
		d = 116.0
	return d

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
		var hw: float = L.W * .86 - 36
		if n:
			# màn hẹp: cột nút Giỏ cá/Chợ/Sổ cá bên phải (rộng 58, cách mép 12); lời nhắc canh giữa mà đụng cột thì bóp hẹp lại cho xuống dòng (Link 11-23 "đè nút Chợ")
			var col_x: float = L.W - 12 - 58.0 - 8
			hw = minf(hw, 2 * (col_x - L.W / 2) - 32)
		var lines := A.wrap(_hint.txt, fs, 800, hw)
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
	if game.host != null and game.host.has("pan"):   # (bản 535) trong vườn: bảng khung Kho chung (ui_ccp.gd)
		game.host.pan.call(kind, arg)
		return
	var was: bool = modal.visible and _mod.get("kind", "") == kind
	var anim: float = _mod.get("anim", 0.0) if was else 0.0
	var keep_scroll: float = body.scroll if was else 0.0
	if not was:
		_bsel = -1
		_sell_sure = false
		_kho_err = ""
		_ssel = ""
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
	# (Link 11-23 "lấy chuẩn khung chung của Kho nông trại"): mọi bảng = .pwin của Nông trại trên khuôn 338x610
	# (#pov đứng giữa màn): rộng 338, cao 524.6, đỉnh cách đỉnh khuôn 85.4, bo 22. Không tên bảng: trên cùng là
	# thanh sức chứa (.kcbox) và tab (.khseg); "Bán hết" + ô xem cá nằm trong dock cố định ở đáy (.khdock).
	# Màn thấp hơn khuôn thì thu chiều cao như farm (fp = vh / 610).
	var k: String = _mod.kind
	var fp := minf(1.0, L.H / KPOV)
	var pw := minf(KW, L.W)
	var top: float = (L.H - KPOV * fp) / 2 + KTOP * fp
	_mod.w = pw
	_mod.r = Rect2((L.W - pw) / 2, top, pw, KH * fp)
	_mod.top = _head_h(k)
	_mod.dock = _dock_h(k)
	var content_h := _body(null, KCW, false)
	# (bản 534) bảng ít đồ co lại vừa nội dung như khung Kho của vườn (trước luôn cao 524,6 -> giỏ trống trơn trống nửa bảng)
	var ph: float = clampf(_mod.top + content_h + 22.0 + _mod.dock + (3.0 if _mod.dock > 0 else 6.0), 220.0, KH * fp)
	_mod.r = Rect2((L.W - pw) / 2, top, pw, ph)
	var br := Rect2(_mod.r.position.x + 2.5, top + _mod.top, pw - 5, ph - _mod.top - _mod.dock - (3.0 if _mod.dock > 0 else 6.0))
	body.position = br.position
	body.size = br.size
	body.max_scroll = maxf(0, content_h + 12 - br.size.y)
	mtop.position = Vector2.ZERO
	mtop.size = Vector2(L.W, L.H)

const KW := 338.0      # .pwin rộng
const KH := 524.6      # .pwin cao
const KTOP := 85.4     # .pwin cách đỉnh #pov
const KPOV := 610.0    # #pov cao
const KX := 16.5       # .khcard lề trái
const KCW := 305.0     # .khcard rộng
const KC_Y := 24.0     # .kcbox cách đỉnh bảng
const KTAB_Y := 64.5   # tab chọn (.khseg button.on) cách đỉnh bảng

func _head_h(k: String) -> float:   # phần cố định trên đầu bảng (không cuộn)
	match k:
		"basket", "dex": return KC_Y + 34.5 + 6.0
		"shop": return KTAB_Y + 33.0 + Tre.T + Tre.S - 2.0
	return 0.0

func _dock_h(k: String) -> float:   # .khdock: 58.5 (một nút), ô xem cá thì cao hơn
	match k:
		"basket":
			if game.S.basket.is_empty():
				return 0.0
			if _bsel >= 0 and _bsel < game.S.basket.size():
				var h := 128.5 + (_bhint().size() - 1) * 18
				return maxf(h, 128.5 + 33) if _kho_id(game.S.basket[_bsel].id) != "" else h
			return 58.5
		"dex":
			return _dex_dock(null, Rect2()) if _mod.get("arg") != null else 0.0
		"shop":
			return _shop_dock(null, Rect2())
	return 0.0

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
	body.position = Vector2(r.position.x + 2.5, r.position.y + _mod.top + mx[1])
	body.modulate.a = mx[2]
	# bảng: bóng (0 -10px 40px như .pwin) + nền giấy kem (một ảnh ghép sẵn); cả hai nằm dưới các ô
	A.fbox(ci, r, Tre.R, [], [], [], [], [[0, -10, 40, Color(0, 0, 0, .3)]], xf)
	A.under_tex(ci, A.paper(r.size.x, r.size.y, Tre.R), r, xf)
	# "panel" phải nằm TRƯỚC nút X: hit() dò từ cuối lên, panel đứng sau thì nuốt luôn cú bấm X (Link 11-23 "X đéo đóng được")
	ci.items.append({"r": r, "id": "panel"})
	var xr := _x_rect()
	ci.items.append({"r": xr.grow(5), "id": "x", "tap": func(): game.snd.ui(); close_modal()})
	var S: Dictionary = game.S
	var x0 := r.position.x + KX
	_push(ci, xf)
	match _mod.kind:
		"basket":
			var cap: int = D.CAGE[S.cage].cap
			var n: int = S.basket.size()
			var tot := 0
			for c in S.basket:
				tot += D.fish_value(D.fish(c.id), c.w)
			_kcbox(ci, r, float(n) / cap, n >= cap, [["Đáng giá ", A.F_MUTED, 600], [str(tot), A.F_PRICE, 800], ["@coin", null, 0]],
				"%d/%d" % [n, cap], n >= cap, func(): game.snd.ui(); _open("shop", "gear"))
			_basket_dock(ci, r)
		"dex":
			var seen := 0
			for f in D.FISH:
				if S.dex.has(f.id):
					seen += 1
			_kcbox(ci, r, float(seen) / D.FISH.size(), false, [["Đã gặp ", A.F_MUTED, 600], [str(seen), A.F_PRICE, 800], [" / %d loài" % D.FISH.size(), A.F_MUTED, 600]],
				"", false, Callable())
			if _mod.get("arg") != null:
				_dex_dock(ci, r)
		"shop":
			# vạch = kinh nghiệm tới cấp sau (lên cấp mở mồi mới); nút cam = giỏ cá (đồ nghề đổi bằng cá trong giỏ)
			var xi: Array = game.host.xpi.call() if game.host != null and game.host.has("xpi") else [int(S.xp), D.xp_need(S.lv)]
			var need: int = maxi(1, int(xi[1]))
			var cap: int = D.CAGE[S.cage].cap
			_kcbox(ci, r, float(xi[0]) / need, false, [[("Cấp vườn %d · còn " if game.host != null else "Cấp %d · còn ") % game.lv(), A.F_MUTED, 600], [str(need - int(xi[0])), A.F_PRICE, 800], [" kinh nghiệm", A.F_MUTED, 600]],
				"Giỏ %d/%d" % [S.basket.size(), cap], false, func(): game.snd.ui(); _open("basket"))
			_shop_dock(ci, r)
			# tab (.khseg: tab chọn xanh lá cao 33, tab kia kem cao 30, chân cùng một đường; đứng trên thanh tre)
			var by: float = r.position.y + KTAB_Y + 33
			var tw := (KCW - 6) / 2
			for i in 2:
				var id: String = ["bait", "gear"][i]
				var on: bool = _mod.arg == id
				var tr := Rect2(x0 + i * (tw + 6), by - (33 if on else 30), tw, (33 if on else 30))
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
				ci.items.append({"r": tr, "id": "tab" + id, "tap": func(): game.snd.ui(); _ssel = ""; _open("shop", id)})
			# thanh tre ngang dưới tab
			var bw := r.size.x - 8
			ci.draw_texture_rect(Tre.bar(bw), Rect2(r.position.x + 4, by - 2, bw, Tre.T + Tre.S), false)
	_pop(ci)
	mtop.queue_redraw()   # nút X đang bấm (lớp trên vẽ X)

# .kcbox của Kho: vạch sức chứa (208 rộng, 9 cao) + dòng "Đáng giá 60 ⊙" bên trái, nút cam .khst bên phải
# parts: [[chữ, màu, độ đậm]]; "@coin" = đồng xu 11px
func _kcbox(ci: Box, r: Rect2, frac: float, full: bool, parts: Array, st: String, st_red: bool, st_tap: Callable) -> void:
	var x0 := r.position.x + KX
	var y0 := r.position.y + KC_Y
	var stw := 0.0
	if st != "":
		stw = A.tw(st, 14, 800) + 24
	var bw := KCW - 3 - (stw + 16 if st != "" else 0.0)
	A.bar_bg(ci, Rect2(x0 + 1.5, y0 + 3.3, bw, 9), frac, A.F_RED if full else Color(1, 204 / 255.0, 51 / 255.0))
	var tx := x0 + 1.5
	var ty := y0 + 18.6 + 7.6
	for p in parts:
		if p[0] == "@coin":
			A.svg(ci, "coin", Rect2(tx + 3, ty - 6, 12, 12))
			tx += 15
			continue
		A.text(ci, p[0], tx, ty, 14, p[1], 0, p[2])
		tx += A.tw(p[0], 14, p[2])
	if st != "":
		var sr := Rect2(x0 + KCW - stw, y0 + 4.5, stw, 25.5)
		var dn := ci.pressed("khst")
		A.fbtn_bg(ci, sr, "red" if st_red else "gold", dn, false, 11.0)
		var c := sr.get_center() + Vector2(0, 1.5 if dn else 0.0)
		A.text(ci, st, c.x, c.y + 1.5, 14, Color(125 / 255.0, 62 / 255.0, 0, .7) if not st_red else Color(90 / 255.0, 15 / 255.0, 5 / 255.0, .5), 1, 800)
		A.text(ci, st, c.x, c.y, 14, Color.WHITE, 1, 800)
		if st_tap.is_valid():
			ci.items.append({"r": sr, "id": "khst", "tap": st_tap})

func _dock_rect(r: Rect2, h: float) -> Rect2:
	return Rect2(r.position.x, r.end.y - h, r.size.x, h)

func _dock_bg(ci: Box, dr: Rect2) -> void:   # .khdock: nền 247,234,208, bo 2 góc dưới 22, thanh tre ngang trên mép (::after top -3px, cao 9)
	A.fbox(ci, dr, Vector4(0, 0, Tre.R, Tre.R), [[0.0, A._c(247, 234, 208)], [1.0, A._c(247, 234, 208)]], [], [])
	var bw := dr.size.x - 8
	ci.draw_texture_rect(Tre.bar(bw), Rect2(dr.position.x + 4, dr.position.y - 3, bw, Tre.T + Tre.S), false)
	ci.items.append({"r": dr, "id": "dock"})

# ô hình .khdic của Kho: 30x30 nền trắng bo 10
func _dic(ci: Box, p: Vector2, fid: String, dark := false) -> void:
	A.fbox(ci, Rect2(p, Vector2(30, 30)), 10, [[0.0, Color.WHITE], [1.0, Color.WHITE]], [[1.0, A._c(150, 112, 48, .22)]])
	if fid.begins_with("@"):
		A.pic(ci, fid.substr(1), Rect2(p + Vector2(3, 3), Vector2(24, 24)), Color(.5, .5, .5, .45) if dark else Color.WHITE)
		return
	var t: Texture2D = A.img(fid)
	if t != null:
		A.fit(ci, t, Rect2(p + Vector2(2, 3), Vector2(26, 24)), Color(0, 0, 0, .3) if dark else Color.WHITE)

# nút trong bảng (vẽ trong lớp bảng, không cuộn)
func _mbt(ci: Box, r: Rect2, lab: String, kind: String, id: String, tap: Callable, ic := "") -> void:
	btn(ci, r, lab, kind, ci.pressed(id), false, ic)
	ci.items.append({"r": r, "id": id, "tap": tap})

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
	_body(ci, KCW, true)

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

# ------------------------------------------------------------ giỏ cá (= tab Hàng hóa của Kho Nông trại)
# lưới ô .khb 4 ô một hàng (72.9 rộng, khe 4.5); chạm ô = chọn (viền xanh), dock đáy hiện ô xem con cá + nút Bán.
# "Bán hết" chạm 2 lần mới bán (như Kho: "Chạm lần nữa để bán hết").
const TILE_W := 72.875
const TILE_GAP := 4.5
const TILE_H := 100.8   # .khb 84.7 + 1 dòng tên (tên cá dài xuống 2 dòng)

func _rar_col(r: int) -> Color:
	match r:
		2: return Color("#6aa0d8")
		3: return Color("#b070d8")
		4: return Color("#e0a020")
	return Color(0, 0, 0, 0)

# một ô cá: hình, tên (tối đa 2 dòng), dòng dưới (giá / cân nặng); viền màu độ hiếm, đang chọn viền xanh
func _tile(ci, r: Rect2, fid: String, name: String, low: String, low_col: Color, coin: bool, rar: int, sel: bool, dark: bool, id: String, tap: Callable, badge := false) -> void:
	if ci == null:
		return
	var dn: bool = ci.pressed(id)
	var rr := Rect2(r.position - Vector2(0, _sc(ci)) + Vector2(0, 1.5 if dn else 0.0), r.size)
	var bc := _rar_col(rar)
	if sel:
		A.card(ci, rr, true, 12)
	elif bc.a > 0:
		A.fbox(ci, rr, 12, [[0.0, A._c(255, 252, 244)], [1.0, A._c(247, 236, 212) if rar < 4 else A._c(252, 238, 196)]], [[2.0, bc]], [2.0, Color(1, 1, 1, .85)], [], [] if dn else [[0, 2, 0, Color(bc, .45)], [0, 3, 5, A._c(90, 60, 20, .1)]])
	else:
		A.card(ci, rr, false, 12)
	var pr := Rect2(rr.position.x + 5, rr.position.y + 6, rr.size.x - 10, 34)
	if fid.begins_with("@"):
		A.pic(ci, fid.substr(1), pr, Color(.5, .5, .5, .45) if dark else Color.WHITE)
		if dark:   # (bản 534) món chưa mở: ổ khóa như vườn
			A.svg(ci, "lock", Rect2(pr.get_center() - Vector2(11, 11), Vector2(22, 22)))
	else:
		var t: Texture2D = A.img(fid)
		if t != null:
			A.fit(ci, t, pr, Color(0, 0, 0, .28) if dark else Color.WHITE)
	if badge:   # dấu tích xanh góc phải trên (mồi đang móc)
		var bcen := Vector2(rr.end.x - 9, rr.position.y + 9)
		ci.draw_circle(bcen, 7, A.F_GREEN)
		ci.draw_polyline(PackedVector2Array([bcen + Vector2(-3.2, 0), bcen + Vector2(-.8, 2.6), bcen + Vector2(3.4, -2.6)]), Color.WHITE, 1.8, true)
	var lines := A.wrap(name, 14, 500, rr.size.x - 8)
	if lines.size() > 2:
		lines = [lines[0], " ".join(lines.slice(1))]
	var ny := rr.position.y + 50 + (8.0 if lines.size() == 1 else 0.0)
	for ln in lines:
		A.text(ci, ln, rr.get_center().x, ny, 14, A.F_BROWN, 1, 500)
		ny += 16.1
	var py := rr.end.y - 15.8
	if coin:
		var w := A.tw(low, 14, 700) + 13
		var lx := rr.get_center().x - w / 2
		A.text(ci, low, lx, py, 14, low_col, 0, 700)
		A.svg(ci, "coin", Rect2(lx + w - 11, py - 5.5, 11, 11))
	else:
		A.text(ci, low, rr.get_center().x, py, 14, low_col, 1, 600)
	ci.items.append({"r": r, "id": id, "sc": true, "tap": tap})

func _b_basket(ci, w: float, y: float) -> float:
	var S: Dictionary = game.S
	if S.basket.is_empty():
		if ci != null:
			A.pic(ci, "cage%d" % S.cage, Rect2(w / 2 + 14.0 - 48, y + 20 - _sc(ci), 96, 96), Color(1, 1, 1, .85))
		_t(ci, "Giỏ trống trơn", w / 2 + 14.0, y + 20 + 96 + 6 + 10, 14, A.F_MUTED, 1)
		var yy := y + 20 + 96 + 6 + 22
		for ln in A.wrap("Cá câu được bỏ vô đây: bán lấy xu, hoặc để dành đổi đồ nghề.", 14, 600, w - 20):
			_t(ci, ln, w / 2 + 14.0, yy + 9, 14, A.SMALL2, 1, 600)
			yy += 18
		return yy + 20
	for i in S.basket.size():
		var c: Dictionary = S.basket[i]
		var f := D.fish(c.id)
		var r := Rect2(14.0 + (i % 4) * (TILE_W + TILE_GAP), y + int(i / 4) * (TILE_H + 6), TILE_W, TILE_H)
		var idx: int = i
		_tile(ci, r, c.id, f.name, str(D.fish_value(f, c.w)), A.F_RED, true, int(f.rar), i == _bsel, false, "b%d" % i, func():
			game.snd.ui()
			_bsel = -1 if _bsel == idx else idx
			_sell_sure = false
			_kho_err = ""
			_open("basket"))
	var rows := int(ceil(S.basket.size() / 4.0))
	return y + rows * (TILE_H + 6)

# cá này đang cần để đổi đồ nghề nào không (nhắc giữ lại, đừng bán)
func _kho_id(fid: String) -> String:   # món Kho vườn của loài cá này ("" = bản riêng / vườn chưa có món đó)
	return str(D.KHO.get(fid, "")) if game.host != null else ""

func _need_by(fid: String) -> String:
	var S: Dictionary = game.S
	for k in D.GEAR_KEYS:
		var list: Array = D.gear(k)
		var cur: int = S[k]
		if cur + 1 < list.size():
			var nx: Dictionary = list[cur + 1]
			if nx.has("need") and nx.need.has(fid):
				return nx.name
	return ""

func _bhint() -> Array:   # lời nhắc dưới giá (.kdhint, cột trái 143.5)
	var S: Dictionary = game.S
	if _bsel < 0 or _bsel >= S.basket.size():
		return []
	var c: Dictionary = S.basket[_bsel]
	var nb := _need_by(c.id)
	var f := D.fish(c.id)
	if _kho_err != "":
		return A.wrap(_kho_err, 14, 500, 143.5)
	var h := ("Cần để đổi " + nb) if nb != "" else ("Cá hiếm, để dành đổi đồ" if int(f.rar) >= 3 else ("Bán lấy xu, hay cất vô Kho xài trong vườn" if _kho_id(c.id) != "" else "Bán lấy xu"))
	return A.wrap(h, 14, 500, 143.5)

func _basket_dock(ci: Box, r: Rect2) -> void:
	var S: Dictionary = game.S
	if S.basket.is_empty():
		return
	var dh: float = _mod.dock
	var dr := _dock_rect(r, dh)
	_dock_bg(ci, dr)
	var x0 := r.position.x + KX
	if _bsel >= 0 and _bsel < S.basket.size():
		# = .khdet của Kho: hàng 1 ô hình 30 + tên (· cân nặng); hàng 2 giá trái, độ hiếm phải; hàng 3 lời nhắc trái, nút Bán phải
		var c: Dictionary = S.basket[_bsel]
		var f := D.fish(c.id)
		var val := D.fish_value(f, c.w)
		var y0 := dr.position.y
		_dic(ci, Vector2(x0, y0 + 10.5), c.id)
		A.text(ci, f.name, x0 + 37.5, y0 + 25.5, 14, A.F_INK, 0, 800)
		A.text(ci, " · " + fmt_w(c.w), x0 + 37.5 + A.tw(f.name, 14, 800), y0 + 25.5, 14, A._c(154, 122, 72), 0, 500)
		var py := y0 + 66.0
		A.text(ci, str(val), x0, py, 20, A._c(240, 140, 0), 0, 700)
		A.svg(ci, "coin", Rect2(x0 + A.tw(str(val), 20, 700) + 4, py - 6, 12, 12))
		var rx := x0 + 152.5
		var sw := draw_stars(ci, f.rar, rx, py, 13)
		A.text(ci, " " + D.RAR[f.rar], rx + sw, py, 14, A._c(154, 122, 72), 0, 500)
		var lab := "Bán · +%d" % val
		var br := Rect2(rx, y0 + 83.5, KCW - 152.5, 27)
		var idx := _bsel
		_mbt(ci, br, lab, "", "sell1", func():
			var cc: Dictionary = S.basket[idx]
			_bsel = -1
			sell([cc], br.get_center())
			_open("basket"), "coin")
		var kid := _kho_id(c.id)
		if kid != "":
			# bản trong vườn: cất con cá này vô Kho Nông Trại (món vườn có sẵn), dưới nút Bán
			var kr := Rect2(rx, y0 + 83.5 + 33, KCW - 152.5, 27)
			_mbt(ci, kr, "Vô Kho", "alt", "kho1", func():
				var cc: Dictionary = S.basket[idx]
				var i: int = S.basket.find(cc)
				if i < 0:
					return
				if not game.host.kho.call(kid, 1):
					_kho_err = "Kho vườn đầy (" + str(game.host.room.call()) + "), bán bớt đã"
					game.snd.ui()
					_open("basket")
					return
				S.basket.remove_at(i)
				_bsel = -1
				game.snd.ui()
				toast("Đã cất " + D.fish(cc.id).name + " vô Kho", "info")
				game.save(true)
				_open("basket"))
		for i in _bhint().size():
			A.text(ci, _bhint()[i], x0, y0 + 97 + i * 18, 14, A.F_RED if _need_by(c.id) != "" or _kho_err != "" else A._c(122, 114, 98), 0, 500)
		return
	var tot := 0
	for c in S.basket:
		tot += D.fish_value(D.fish(c.id), c.w)
	var lab2 := "Chạm lần nữa để bán hết" if _sell_sure else "Bán hết +%d" % tot
	var bw2 := btn_w(lab2, "" if _sell_sure else "coin")
	var br2 := Rect2(r.get_center().x - bw2 / 2, dr.position.y + 12, bw2, 30)
	_mbt(ci, br2, lab2, "", "sellall", func():
		if _sell_sure:
			_sell_sure = false
			_bsel = -1
			sell(S.basket.duplicate(), br2.get_center())
		else:
			_sell_sure = true
		_open("basket"), "" if _sell_sure else "coin")

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
	if game.host != null and game.host.has("free"):   # (bản 537) trong vườn: cá nằm trong Kho
		var kid := str(D.KHO.get(id, ""))
		return int(game.host.bait.call(kid)) if kid != "" else 0
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
	if game.host != null and game.host.has("free"):
		for id in need:
			game.host.bait_add.call(str(D.KHO.get(id, "")), -int(need[id]))
		return
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
# ------------------------------------------------------------ chợ (= Kho: lưới ô 4 ô/hàng, chạm ô xem + mua/đổi ở dock đáy)
func _shop_cur() -> String:   # ô đang chọn; mặc định: mồi đang móc / món đồ nghề đầu tiên
	if _ssel != "":
		return _ssel
	return game.S.bait if _mod.get("arg") == "bait" else D.GEAR_KEYS[0]

func _b_shop(ci, w: float, y: float) -> float:
	var S: Dictionary = game.S
	var sel := _shop_cur()
	var keys: Array = D.BAIT_ORDER if _mod.arg == "bait" else D.GEAR_KEYS
	for i in keys.size():
		var k: String = keys[i]
		var r := Rect2(14.0 + (i % 4) * (TILE_W + TILE_GAP), y + int(i / 4) * (TILE_H + 6), TILE_W, TILE_H)
		var kk := k
		var tap := func():
			game.snd.ui()
			_ssel = kk
			_open("shop", _mod.arg)
		if _mod.arg == "bait":
			var b: Dictionary = D.BAIT[k]
			var lock: bool = b.lv > game.lv()
			var low: String = ("Cấp %d" % b.lv) if lock else ("Vô hạn" if k == "trun" else "Có %d" % int(S.baits.get(k, 0)))
			_tile(ci, r, "@" + k, b.name, low, A.SMALL2 if lock else A.F_BROWN, false, 0, sel == k, lock, "s" + k, tap, S.bait == k)
		else:
			var list: Array = D.gear(k)
			var cur: int = S[k]
			var st := "Xịn nhất"
			var col := A.F_GREEN
			if cur + 1 < list.size():
				var nx: Dictionary = list[cur + 1]
				var ok: bool = S.xu >= nx.price and (not nx.has("need") or has_fish(nx.need))
				st = "Đổi được" if ok else "Chưa đủ"
				col = A.F_GREEN if ok else A.SMALL2
			_tile(ci, r, "@%s%d" % [k, cur], list[cur].name, st, col, false, 0, sel == k, false, "s" + k, tap)
	var rows := int(ceil(keys.size() / 4.0))
	return y + rows * (TILE_H + 6)

# dock Chợ: hàng 1 ô hình 30 + tên; mô tả; hàng chip giá/cá (đồ nghề); hàng cuối lời nhắc trái + nút phải (cỡ .kdsell 27 cao)
# ci == null: chỉ đo, trả về chiều cao dock
func _shop_dock(ci, r: Rect2) -> float:
	var S: Dictionary = game.S
	var k := _shop_cur()
	var x0 := r.position.x + KX
	var title := ""
	var sub := ""
	var desc := ""
	var chips := []
	var hint := ""
	var hint_bad := false
	var btns := []   # [lab, kind, id, tap, disabled, ic]
	var gic := ""    # đồ nghề: icon theo cấp (cấp kế tiếp nếu còn đổi được)
	if _mod.get("arg") == "bait":
		var b: Dictionary = D.BAIT[k]
		title = b.name
		desc = b.desc
		if b.lv > game.lv():
			hint = ("Vườn lên cấp %d mới mở" if game.host != null else "Lên cấp %d mới mở") % b.lv
			hint_bad = true
		else:
			sub = " · " + ("vô hạn" if k == "trun" else "có %d" % int(S.baits.get(k, 0)))
			hint = ("Đang có %d xu" % S.xu) if b.pack else ""
			if S.bait == k:
				btns.append(["Đang dùng", "", "hook", Callable(), false, ""])
			elif k == "trun" or int(S.baits.get(k, 0)) > 0:
				btns.append(["Móc mồi", "alt", "use" + k, func():
					S.bait = k
					game.snd.ui()
					hud_dirty()
					toast("Móc " + D.BAIT[k].name, "info")
					_open("shop", "bait"), false, ""])
			if b.pack:
				btns.append(["Mua %d · @%d" % [b.pack, b.price], "gold", "buy" + k, func():
					var it: Dictionary = D.BAIT[k]
					if S.xu < it.price:
						return
					S.xu -= it.price
					S.baits[k] = int(S.baits.get(k, 0)) + it.pack
					game.snd.coin(0)
					if S.bait == "trun":
						S.bait = k
					hud_dirty()
					_open("shop", "bait"), S.xu < b.price, "coin"])
	else:
		var list: Array = D.gear(k)
		var cur: int = S[k]
		gic = str(mini(cur + 1, list.size() - 1))
		if cur + 1 >= list.size():
			title = list[cur].name
			desc = list[cur].desc
			hint = D.GEAR_NAME[k] + " xịn nhất rồi"
		else:
			var nx: Dictionary = list[cur + 1]
			title = list[cur].name + " → " + nx.name
			desc = nx.desc
			var ok_xu: bool = S.xu >= nx.price
			var ok_f: bool = not nx.has("need") or has_fish(nx.need)
			chips = [[str(nx.price), ok_xu, "", "coin"]]
			if nx.has("need"):
				chips.append_array(_need_chips(nx.need))
			if not ok_xu:
				hint = "Còn thiếu %d xu" % (nx.price - S.xu)
				hint_bad = true
			elif not ok_f:
				hint = "Câu thêm cá cho đủ"
				hint_bad = true
			else:
				hint = "Đủ rồi, đổi thôi"
			btns.append(["Đổi", "", "up" + k, func():
				var nn: Dictionary = D.gear(k)[S[k] + 1]
				if S.xu < nn.price or (nn.has("need") and not has_fish(nn.need)):
					return
				S.xu -= nn.price
				if nn.has("need"):
					take_fish(nn.need)
				S[k] += 1
				game.snd.fanfare(3)
				toast("Đổi được " + nn.name + "!", "good")
				hud_dirty()
				game.save(true)
				_open("shop", "gear"), not (ok_xu and ok_f), ""])
	# đo
	var tl := A.wrap(title, 14, 800, KCW - 37.5)
	var dl := A.wrap(desc, 14, 500, KCW)
	var ch_h := 0.0
	if chips.size():
		ch_h = _chips(null, 0, 0, KCW, chips) + 8
	var bw := 0.0
	for bt in btns:
		bw += btn_w(bt[0], bt[5]) + 6
	# lời nhắc nằm trái hàng nút; không đủ chỗ (2 nút) thì lên một dòng riêng phía trên
	var hl := A.wrap(hint, 14, 500, KCW) if hint != "" else []
	var own := hl.size() > 0 and (hl.size() > 1 or A.tw(hint, 14, 500) > KCW - bw - 8)
	var head := maxf(30, tl.size() * 18)
	var h: float = 10.5 + head + 8 + dl.size() * 18 + 4 + ch_h + (hl.size() * 18 + 4 if own else 0.0) + 27 + 24
	if ci == null:
		return h
	var dr := _dock_rect(r, h)
	_dock_bg(ci, dr)
	var y := dr.position.y + 10.5
	_dic(ci, Vector2(x0, y), "@" + k + gic)
	var ty := y + 15 - (tl.size() - 1) * 9
	for i in tl.size():
		A.text(ci, tl[i], x0 + 37.5, ty, 14, A.F_INK, 0, 800)
		if i == tl.size() - 1 and sub != "":
			A.text(ci, sub, x0 + 37.5 + A.tw(tl[i], 14, 800), ty, 14, A._c(154, 122, 72), 0, 500)
		ty += 18
	y += head + 8
	for ln in dl:
		A.text(ci, ln, x0, y + 9, 14, A.F_BROWN, 0, 500)
		y += 18
	y += 4
	if chips.size():
		# chip nằm trong lớp bảng (không cuộn): vẽ bằng _chip với ci = bảng, cuộn = 0
		_chips(ci, x0, y, KCW, chips)
		y += ch_h
	if own:
		for i in hl.size():
			A.text(ci, hl[i], x0, y + 9 + i * 18, 14, A.F_RED if hint_bad else A._c(122, 114, 98), 0, 500)
		y += hl.size() * 18 + 4
		hl = []
	var by := y
	var bx := x0 + KCW
	for i in range(btns.size() - 1, -1, -1):
		var bt: Array = btns[i]
		var ww := btn_w(bt[0], bt[5])
		bx -= ww
		var br := Rect2(bx, by, ww, 27)
		if bt[4]:
			btn(ci, br, bt[0], bt[1], false, true, bt[5])
		else:
			_mbt(ci, br, bt[0], bt[1], bt[2], bt[3], bt[5])
		bx -= 6
	for i in hl.size():
		A.text(ci, hl[i], x0, by + 13.5 + i * 18, 14, A.F_RED if hint_bad else A._c(122, 114, 98), 0, 500)
	return h

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
# ------------------------------------------------------------ sổ cá (lưới ô như Kho; chạm ô = xem trong dock đáy)
func _b_dex(ci, w: float, y: float) -> float:
	var S: Dictionary = game.S
	var sel = _mod.get("arg")
	for i in D.FISH.size():
		var f: Dictionary = D.FISH[i]
		var d = S.dex.get(f.id)
		var r := Rect2(14.0 + (i % 4) * (TILE_W + TILE_GAP), y + int(i / 4) * (TILE_H + 6), TILE_W, TILE_H)
		var fid: String = f.id
		_tile(ci, r, fid, f.name if d != null else "???", fmt_w(float(d.best)) if d != null else "chưa gặp", A.SMALL2, false, int(f.rar), sel == fid, d == null, "f" + fid, func():
			game.snd.ui()
			_open("dex", null if _mod.get("arg") == fid else fid))
	var rows := int(ceil(D.FISH.size() / 4.0))
	return y + rows * (TILE_H + 6)

# dock sổ cá: tên, độ hiếm, mô tả, gợi ý chỗ câu. ci == null: chỉ đo, trả về chiều cao dock
func _dex_dock(ci, r: Rect2) -> float:
	var S: Dictionary = game.S
	var sel = _mod.get("arg")
	if sel == null:
		return 0.0
	var f := D.fish(sel)
	var d = S.dex.get(sel)
	var lines := []
	lines.append_array(A.wrap(f.desc if d != null else "Chưa câu được con nào.", 14, 500, KCW))
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
		lines.append_array(A.wrap(s, 14, 500, KCW))
	if d != null:
		lines.append_array(A.wrap("Đã câu %d lần · con lớn nhất %s" % [int(d.n), fmt_w(float(d.best))], 14, 500, KCW))
	var h := 10.5 + 30 + 12 + lines.size() * 18 + 14
	if ci == null:
		return h
	var dr := _dock_rect(r, h)
	_dock_bg(ci, dr)
	var x0 := r.position.x + KX
	var y0 := dr.position.y
	_dic(ci, Vector2(x0, y0 + 10.5), sel, d == null)
	var nm: String = f.name if d != null else "???"
	A.text(ci, nm, x0 + 37.5, y0 + 25.5, 14, A.F_INK, 0, 800)
	var nx := x0 + 37.5 + A.tw(nm, 14, 800) + 8
	var sw := draw_stars(ci, f.rar, nx, y0 + 25.5, 13)
	A.text(ci, " " + D.RAR[f.rar], nx + sw, y0 + 25.5, 14, A._c(154, 122, 72), 0, 500)
	var yy := y0 + 10.5 + 30 + 12 + 9
	for ln in lines:
		A.text(ci, ln, x0, yy, 14, A.F_BROWN, 0, 500)
		yy += 18
	return h

func _p_lines(s: String, w: float) -> Array:
	var out := []
	for ln in A.wrap(s, 13, 600, w):
		out.append(["p", ln, 13])
	return out

# ------------------------------------------------------------ cài đặt (= Cài đặt Nông trại: nhóm .qset, nút .seg, "Chơi lại từ đầu" chữ đỏ)
func _qset(ci, y: float, h: float) -> void:
	if ci == null:
		return
	A.fbox(ci, Rect2(14.0, y - _sc(ci), KCW, h), 14, [[0.0, A._c(255, 252, 244)], [1.0, A._c(247, 236, 212)]], [[1.0, A._c(150, 112, 48, .3)]], [2.0, Color(1, 1, 1, .85)], [], [[0, 2, 0, A._c(170, 135, 70, .32)], [0, 3, 5, A._c(90, 60, 20, .1)]])

func _seg(ci, y: float, labs: Array, on: int, id: String, taps: Array) -> void:   # .seg: các nút chia đều 287 rộng, cao 33, khe 4.6
	var n := labs.size()
	var bw := (KCW - 18 - (n - 1) * 4.6) / n
	for j in n:
		var r := Rect2(14.0 + 9 + j * (bw + 4.6), y, bw, 33)
		if j == on:
			if ci != null:
				btn(ci, Rect2(r.position - Vector2(0, _sc(ci)), r.size), labs[j], "", false, false, "", 14)
		else:
			_bt(ci, r, labs[j], "alt", id + str(j), taps[j])

func _b_set(ci, w: float, y: float) -> float:
	var S: Dictionary = game.S
	y += 11.0   # .pn bắt đầu cách đỉnh bảng 21
	var groups := [
		["Âm thanh", 1 if S.sound != 1 else 0, func(): game.snd.set_sound(true); _open("set"), func(): game.snd.set_sound(false); _open("set")],
		["Nhạc đàn tranh", 1 if S.music != 1 else 0, func(): game.snd.set_music(true); _open("set"), func(): game.snd.set_music(false); _open("set")],
	]
	for g in groups:
		_qset(ci, y, 68.1)
		_t(ci, g[0], 14.0 + 9, y + 7.5 + 7, 14, A.F_BROWN, 0, 800)
		_seg(ci, y + 26.1, ["Bật", "Tắt"], g[1], "sw" + g[0], [g[2], g[3]])
		y += 68.1 + 16.5
	# thống kê
	var st := "Quăng %d lần · câu được %d · đứt dây %d" % [S.stats.casts, S.stats.catches, S.stats.snaps]
	var sl := A.wrap(st, 14, 500, KCW - 18)
	var gh := 7.5 + 16.5 + 4 + sl.size() * 18 + 8
	_qset(ci, y, gh)
	_t(ci, "Thống kê", 14.0 + 9, y + 7.5 + 7, 14, A.F_BROWN, 0, 800)
	var yy := y + 7.5 + 16.5 + 4 + 9
	for ln in sl:
		_t(ci, ln, 14.0 + 9, yy, 14, A.F_MUTED, 0, 500)
		yy += 18
	y += gh + 16.5
	if game.embed:
		_qset(ci, y, 68.1)
		_t(ci, "Về vườn", 14.0 + 9, y + 7.5 + 7, 14, A.F_BROWN, 0, 800)
		_bt(ci, Rect2(14.0 + 9, y + 26.1, KCW - 18, 33), "Thôi câu, về lại nông trại", "", "home", func(): close_modal(); game.close_game(), false, "home")
		y += 68.1 + 16.5
	# Chơi lại từ đầu: chữ đỏ (button.link), chạm 2 lần
	var lab := "Chạm lần nữa để xóa hết" if _sure else "Chơi lại từ đầu"
	var lw := A.tw(lab, 14, 700) + 16
	var lr := Rect2(14.0 + KCW / 2 - lw / 2, y, lw, 22.5 + 16)
	_t(ci, lab, lr.get_center().x, lr.get_center().y, 14, A._c(192, 57, 43), 1, 700)
	if ci != null:
		ci.items.append({"r": lr, "id": "reset", "sc": true, "tap": func():
			if _sure:
				_sure = false
				game.reset_save()
				close_modal()
				hud_dirty()
				toast("Chơi lại từ đầu nha", "info")
			else:
				_sure = true
				_open("set")})
	return lr.end.y + 8

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
	var vk: bool = game.host != null and game.host.has("free")   # (bản 537) trong vườn: không giỏ, cá vô thẳng Kho vườn
	var full: bool = (int(game.host.free.call()) < 1) if vk else S.basket.size() >= cap
	A.under_rect(ci, Rect2(0, 0, L.W, L.H), Color(10 / 255.0, 24 / 255.0, 12 / 255.0, .45))
	var cw := minf(400, L.W - 32)
	var short := low()
	var img_h := 120.0 if short else 170.0
	var desc := A.wrap(f.desc, 14, 600, cw - 32)
	var acts := []
	if junk:
		acts.append(["Bỏ thùng rác", "", "junk", ""])
	else:
		if not full:
			acts.append(["Vô Kho" if vk else "Bỏ giỏ", "", "keep", "" if vk else "basket"])
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
	var h := 16 + 8 + img_h + 2 + 34 * 1.0 + (6 + 20 + 6 if tags.size() else 8) + 52 + 4 + 6 + desc.size() * 14 * 1.3 + 10 + rows_b.size() * 46 + 14
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
	A.text(ci, f.name, 0, y + 17, A.FS_L, A.F_INK, 1, 800, 0.0, A.INK, xf)
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
		var ww := maxf(A.tw(s[0], 20), A.tw(s[1], 14, 700)) + 24
		sws.append(ww)
		tot += ww
	tot += (stats.size() - 1) * 8
	var sx := -tot / 2
	for i in stats.size():
		var sr := Rect2(sx, y, sws[i], 52)
		_push(ci, xf)
		A.card(ci, sr, false, 12)
		_pop(ci)
		A.text(ci, stats[i][0], sr.get_center().x, sr.position.y + 5 + 20 * .6, 20, A.F_BROWN, 1, 800, 0.0, A.INK, xf)
		A.text(ci, stats[i][1], sr.get_center().x, sr.position.y + 5 + 20 * 1.1 + 14 * .6, 14, A.SMALL2, 1, 700, 0.0, A.INK, xf)
		sx += sws[i] + 8
	y += 52 + 4 + 6
	for ln in desc:
		A.text(ci, ln, 0, y + 14 * .65, 14, A.F_BROWN, 1, 600, 0.0, A.INK, xf)
		y += 14 * 1.3
	y += 10
	var cf := func(id: String) -> void:
		var G2: Dictionary = game.G
		match id:
			"junk":
				game.snd.ui()
				toast("Kênh sạch thêm chút, +1 phước", "good")
				_card_done()
			"keep":
				game.snd.ui()
				if vk:
					# vô thẳng Kho vườn; con to hơn trung bình: thưởng liền phần chênh so với giá Kho (Kho chỉ đếm con, không nhớ cân)
					var kid := str(D.KHO.get(f.id, ""))
					if kid == "" or not game.host.kho.call(kid, 1):
						toast("Kho vườn đầy, bán ngay hoặc thả về", "bad")
						return
					var bonus: int = maxi(0, int(_card.val) - int(game.host.price.call(kid)))
					if bonus > 0:
						S.xu += bonus
						fly_coins(int(ceil(bonus / 15.0)), Vector2(L.W / 2, L.H / 2 + 100))
					toast("Đã cất vô Kho" + ((" · cá to +%d xu" % bonus) if bonus > 0 else ""), "good")
					_card_done()
					return
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
				toast("Thả cá về sông, +0,5 phước", "good")
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
		A.text(ci, ("Kho vườn đầy (%s): bán ngay hoặc thả về." % str(game.host.room.call())) if vk else "Giỏ đầy rồi! Bán bớt hoặc đổi giỏ lớn hơn.", 0, y + 8 + 14 * .6, 14, Color("#a8401a"), 1, 600, 0.0, A.INK, xf)

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
	var fs := A.FS_L   # Link 11-23: cả game chỉ 2 cỡ chữ 20 + 14
	var l1 := "Câu Cá"
	var l2 := "Bờ Kênh"
	var one = A.tw(l1 + " " + l2, fs, 900) + 68 < L.W - 40
	var lw := (maxf(A.tw(l1, fs, 900), A.tw(l2, fs, 900)) if not one else A.tw(l1 + " " + l2, fs, 900)) + (52 if n else 68)
	var lh := fs * 1.02 * (1 if one else 2) + 12 + 30 + (30 if n else 34)
	var sub := "MIỆT VƯỜN · NÔNG TRẠI"
	var sfs := A.FS_S
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
