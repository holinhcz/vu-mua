extends CanvasLayer
# Bảng của bản web Nông Trại Nhỏ, dựng lại từ số đo của trình duyệt (res://ui/snap/*.json) và chạy
# theo luật game.gd: thanh trên (HUD), Menu, khay chọn giống (module "gieo" của web), vòng nút ô ruộng
# (module "ring"), bảng ô chưa mở (#ppop), Kho, thông báo (ta). Vẽ theo điểm ảnh thật (Css.K = dpr).

const Css = preload("res://ui/css.gd")
const Snap = preload("res://ui/snap.gd")
const Box = preload("res://ui/box.gd")
const Khuon = preload("res://ui/khuon.gd")
const VW0 := 338.0           # khổ màn hình lúc chụp số đo (css px)
const VH0 := 610.0
const RA := 28.5             # bán kính vòng nút (svg 64)
const CIRC := 179.0707812    # 2 pi RA
const SOON := "Phần này đang chuyển qua bản Godot."

var G: Node
var P: Node
var F: Node2D
var main: Node2D
var vw := VW0
var vh := VH0
var root: Control
var dpr_v := 1.0             # devicePixelRatio
var kh := {"k": "doc", "co": "nho", "r": 0.55, "s": 0.75}   # Wi của bản web: khuôn màn hình hiện tại
var U := 1.0                 # độ to giao diện so với lúc chụp số đo: Wi.s / 0,75
var anchors := []            # [Box, ax, ay]: lệch theo khổ màn hình thật
var hid := {}                # ids của thanh trên
var focus := false           # body.rmfocus
var _t := 0.0
var _vs := Vector2.ZERO
var nvp = null               # bảng Sổ nhiệm vụ (ui_nv.gd)
var bdp = null               # bảng XÂY DỰNG (ui_bd.gd)
var setp = null              # bảng CÀI ĐẶT (ui_set.gd)
var vlp = null               # bảng NHÀ DÂN (ui_vl.gd)
var ngp = null               # bảng NGHỀ THỦ CÔNG (ui_ng.gd)
var ng_bdg: Control = null   # số đơn làng giao được trên nút Nghề (ngBdg)
var slp = null               # bảng SỔ LÀNG (ui_sl.gd)
var utp = null               # bảng UY TÍN LÀNG (ui_ut.gd)
var hrp = null               # bảng NGƯỜI LÀM THUÊ (ui_hr.gd)
var huip = null              # bảng HỤI LÀNG (ui_hui.gd)
var gpp = null               # bảng GIA PHẢ (ui_gp.gd)
var tnp = null               # bảng THIÊN TAI (ui_tn.gd)
var sl_bdg: Control = null   # số danh hiệu chờ nhận trên nút Sổ làng (#bookBdg)
var lvp = null               # bảng LÊN CẤP (ui_lv.gd)
var pcp = null               # bảng Nhân vật (ui_pc.gd)
var spp = null               # Nâng sao ô ruộng (ui_sao.gd)
var khp = null               # sức chứa kho, Nâng sao kho, Kho đầy, Nâng sớm (ui_kho.gd)

func setup(game: Node, pics: Node, farm: Node2D, dpr: float) -> void:
	G = game
	P = pics
	F = farm
	main = farm.main if "main" in farm and farm.main != null else get_parent()
	dpr_v = maxf(1.0, dpr)
	kh = Khuon.tinh(get_viewport().get_visible_rect().size.x / dpr_v, get_viewport().get_visible_rect().size.y / dpr_v)
	U = _calc_u(get_viewport().get_visible_rect().size / dpr_v, kh)
	Css.K = dpr_v * U
	_web_zoom()
	layer = 10
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)   # NTWEB: gốc phủ cả màn hình, bảng neo đáy/giữa (cây ăn trái, chợ nổi, lễ hội) mới nằm trong màn
	add_child(root)
	_build_dim()
	_build_hud()
	_build_dock()
	_build_gv()
	_build_rm()
	_build_lock()
	_build_kho()
	_build_ord()
	_build_pc()
	nvp = load("res://logic/ui_nv.gd").new(self)
	lvp = load("res://logic/ui_lv.gd").new(self)
	setp = load("res://logic/ui_set.gd").new(self)
	xfp = load("res://logic/ui_xf.gd").new(self)
	bdp = load("res://logic/ui_bd.gd").new(self)
	khp = load("res://logic/ui_kho.gd").new(self)
	spp = load("res://logic/ui_sao.gd").new(self)
	pcp = load("res://logic/ui_pc.gd").new(self)
	G.kho_full.connect(_kho_full)
	var bdi := Node.new()
	bdi.set_script(load("res://logic/ui_bd_in.gd"))
	bdi.bd = bdp
	add_child(bdi)
	_build_toast()
	G.changed.connect(func(): _sync_hud())
	G.toast.connect(say)
	G.level_up.connect(func(_n, _g): if lvp != null: lvp.lvT = 2.5)
	if G.w_all != null:   # NTWEB: bảng của các mô-đun dịch từ web
		G.w_all.ui_setup(self)
	_layout()
	_sync_hud()

func main_ready(m: Node2D) -> void:
	main = m

# ------------------------------------------------------------------ helpers
func _build(n: Dictionary, ids: Dictionary, origin := Vector2.ZERO) -> Control:
	return Snap.build(n, origin, ids)

func _q(b: Control, cls: String, tag := "") -> Control:
	# the first Box under b (depth first) built from an element with this class
	for k in b.kids():
		var n: Dictionary = k.get_meta("snap", {})
		if (cls == "" or String(n.get("cls", "")).split(" ").has(cls)) and (tag == "" or n.get("tag", "") == tag):
			return k
		var f := _q(k, cls, tag)
		if f != null:
			return f
	return null

func _qall(b: Control, cls: String, out: Array) -> Array:
	for k in b.kids():
		var n: Dictionary = k.get_meta("snap", {})
		if String(n.get("cls", "")).split(" ").has(cls):
			out.append(k)
		_qall(k, cls, out)
	return out

func _txt(b: Control, s: String) -> void:
	if b == null or b.texts.is_empty():
		return
	var i: int = b.get_meta("ti", 0)
	b.set_text(i, String(b.get_meta("prefix", "")) + s + String(b.get_meta("suffix", "")))

func _move(b: Control, p: Vector2) -> void:
	b.r.position = p
	b.position = p * Css.K

func _click(b: Control, cb: Callable, fx := "down") -> void:
	if b == null:
		return
	b.clickable(fx)
	b.pressed.connect(cb)

func _stop(b: Control) -> void:
	# a panel: swallow taps so they do not reach the village under it
	b.mouse_filter = Control.MOUSE_FILTER_STOP

func vsize() -> Vector2:
	return get_viewport().get_visible_rect().size / Css.K

func _layout() -> void:
	var v := vsize()
	vw = v.x
	vh = v.y
	_vs = v
	for a in anchors:
		var b: Control = a[0]
		if is_instance_valid(b):
			b.position = (b.r.position + Vector2((vw - VW0) * a[1], (vh - VH0) * a[2])) * Css.K
	if dim != null:
		dim.size = v * Css.K
	# lớp tối phủ cả màn (.pbk, nền popup: số đo 0,0,338x610): luôn phủ kín màn thật, không chỉ khổ lúc chụp
	for a in anchors:
		if is_instance_valid(a[0]):
			_cover(a[0], v)

func _cover(b: Control, v: Vector2) -> void:
	for k in b.kids():
		var n: Dictionary = k.get_meta("snap", {})
		var rr = n.get("r", [])
		if rr is Array and rr.size() == 4 and absf(float(rr[0])) < 0.5 and absf(float(rr[1])) < 0.5 and absf(float(rr[2]) - VW0) < 0.5 and absf(float(rr[3]) - VH0) < 0.5:
			var gp: Vector2 = root.global_position
			k.place(Rect2(k.r.position, v))
			k.global_position = gp
		_cover(k, v)

func plot_css(i: int, h := -1.0) -> Vector2:
	# R1(en(gx+.5, gy+.5), nn(gx+.5, gy+.5, co)): tâm ô ruộng trên màn hình, css px
	var c: Dictionary = G.cells[i]
	var w := Vector2(F.en(c.gx + 0.5, c.gy + 0.5), F.nn(c.gx + 0.5, c.gy + 0.5, G.CO if h < 0.0 else h))
	return (w - main.cam) * main.zoom / Css.K

func bz() -> float:
	# ba.z của bản web: css px thật cho mỗi đơn vị làng
	return main.zoom / dpr_v

func _web_zoom() -> void:
	# uu(): zoom tối đa 1,7·s; kh() (zoom nhỏ nhất) làng tự tính
	if main != null and "zmax" in main:
		main.zmax = 1.7 * float(kh.s) * dpr_v

func web_start_cam() -> void:
	# rM(): lúc vào làng zoom 0,7·s, nhà chính lệch trái một chút (28·s, màn rộng 36·s)
	var vs := get_viewport().get_visible_rect().size / dpr_v
	var s := float(kh.s)
	var n := (28.0 if vs.x < 700.0 else 36.0) * s
	var z := clampf(0.7 * s, main.zmin / dpr_v, main.zmax / dpr_v)
	main.zoom = z * dpr_v
	main.cam = Vector2(4268.0 + 10.0 - (vs.x / 2.0 - n) / z, 968.0 + 105.0 - vs.y / 2.0 / z)
	if main.has_method("_clamp_cam"):
		main._clamp_cam()

func cz() -> float:
	# độ phóng của bản web (ba.z): css px cho mỗi đơn vị làng
	return main.zoom / Css.K

# ------------------------------------------------------------------ toast (ta)
var toast_b: Control = null
var _toast_t := 0.0
var _toast_n: Dictionary = {}

func _build_toast() -> void:
	var d: Dictionary = Snap.load_snap("toast")
	for sel in d:
		for n in d[sel]:
			_toast_n = n
	if _toast_n.is_empty():
		return

func say(s: String) -> void:
	if _toast_n.is_empty():
		return
	if toast_b != null:
		toast_b.queue_free()
	# web (body.u2hud .toast.u2tok): góc trái trên, dưới thanh trên (left 12, top 128), rộng theo chữ
	var n: Dictionary = _toast_n.duplicate(true)
	var fs := Css.px(n.css.get("font-size", "14px")) * float(n.get("z", 1.0))
	var fw := int(n.css.get("font-weight", "600"))
	var pl := Css.px(n.css.get("padding-left", "14px"))
	var tw: float = Box.text_w(s, fs, fw)
	var maxw := minf(vw - 24.0, 254.0)
	var w := minf(maxw, tw + 2.0 * pl + 2.0)
	var lines := _nlines(s, fs, fw, maxw - 2.0 * pl - 2.0)
	var lh := fs * 1.35
	var h0: float = n.r[3]
	var h := h0 + (lines - 1) * lh
	n.text = s
	n.erase("tr")
	n.css.erase("transform")
	# giữa dòng toast ở y ~148 (1 dòng: top 128, 3 dòng: top 120 như web)
	n.r = [12.0, roundf(147.5 - h * 0.5), w, h]
	toast_b = _build(n, {})
	root.add_child(toast_b)
	_toast_t = 2.3

static func _nlines(s: String, fs: float, fw: int, w: float) -> int:
	var n := 1
	var cur := ""
	for word in s.split(" "):
		var t := word if cur == "" else cur + " " + word
		if cur != "" and Box.text_w(t, fs, fw) > w:
			n += 1
			cur = word
		else:
			cur = t
	return n

# ------------------------------------------------------------------ HUD
const AX := {".hudtl": [0, 0], ".hudq": [0, 0.5], ".hudtr": [1, 0], ".zoomctl": [0, 1], ".autob": [0, 1], "#nvBtn": [1, 1], "#dockBtn": [1, 1]}
var hud_roots := {}
var focus_hide := []

static func _grow_w(n: Dictionary, x: float, d: float, pad := 1.5) -> void:
	# như _grow_at theo bề ngang: dời mọi thứ nằm bên phải x sang d, kéo rộng những gì chạm mép phải (trong khoảng pad)
	var x0 := float(n.r[0])
	var x1 := x0 + float(n.r[2])
	if x0 >= x - 0.5:
		Snap._move(n, Vector2(d, 0))
		return
	if x1 > x - pad and not n.has("text"):
		n.r = [n.r[0], n.r[1], float(n.r[2]) + d, n.r[3]]
	for k in n.get("kids", []):
		_grow_w(k, x, d, pad)

var goal_built := 0.0
const S_REF := 0.9   # Wi.s trên máy chuẩn của Link (S26 Ultra: screen 339x735 css)
static func _calc_u(vs: Vector2, k: Dictionary) -> float:
	# Link: S26 Ultra cố định 1 (bảng y số đo), màn khác phóng theo tỉ lệ Wi.s với máy đó; không rộng quá màn
	return minf(float(k.s) / S_REF, vs.x / VW0)

func goal_w() -> float:
	# .hudq .goal: width min(66vw, 320px) trong .hudq (zoom s), ra đơn vị số đo
	return minf(0.66 * vw * U, 320.0) * Khuon.S_SNAP

func _build_hud() -> void:
	var d: Dictionary = Snap.load_snap("hud").duplicate(true)
	vw = vsize().x
	vh = vsize().y
	if d.has(".hudq"):
		var q: Dictionary = d[".hudq"][0]
		var gl := Snap.find(q, "goal")
		if not gl.is_empty():
			goal_built = goal_w()
			var dw := goal_built - float(gl.r[2])
			if absf(dw) > 0.01:
				_grow_w(q, float(gl.r[0]) + float(gl.r[2]), dw, 16.0)   # thanh tiến độ cách mép phải bằng lề trong
	for sel in d:
		for n in d[sel]:
			var b := _build(n, hid)
			root.add_child(b)
			var a: Array = AX.get(sel, [0, 0])
			anchors.append([b, a[0], a[1]])
			hud_roots[sel] = b
	# body.rmfocus: khi mở khay giống / vòng nút thì giấu mấy nút này
	for k in [".hudq", ".autob", ".zoomctl", "#nvBtn", "#dockBtn"]:
		if hud_roots.has(k):
			focus_hide.append(hud_roots[k])
	for k in [".evrail", "#setBtn"]:
		if hid.has(k):
			focus_hide.append(hid[k])
	_click(hid.get("#dockBtn"), func(): dock_open(true), "scale")
	_click(hid.get("#zHome"), func(): F.home() if F.has_method("home") else null)
	_click(hid.get("#nvBtn"), func(): nvp.open(), "scale")
	_click(hid.get("#setBtn"), func(): setp.open(), "scale")
	_click(hid.get("#pcAv"), func(): pcp.open(), "scale")
	for k in [".autob", ".ngpill", ".hudTab", "#clock", "#coinsPill"]:
		var b = hid.get(k)
		if b != null:
			_click(b, func(): say(SOON))
	for b in hid.get(".evb*", []):
		_click(b, func(): say(SOON), "scale")

func _set_focus(on: bool) -> void:
	if on == focus:
		return
	focus = on
	for b in focus_hide:
		b.visible = not on

func _sync_hud() -> void:
	if hid.is_empty():
		return
	_txt(hid.get(".lv"), str(G.lv()))
	var en = hid.get(".en")
	if en != null and en.kids().size() > 0:
		var bar: Control = en.kids()[0]
		var fr := clampf(float(G.g.pc.en) / maxf(1.0, G.en_max()), 0.0, 1.0)
		bar.place(Rect2(bar.r.position, Vector2(en.r.size.x * fr, bar.r.size.y)))
	_coins_txt(G.fmt_n(int(G.g.coins)))
	var ng = hid.get(".ngpill")
	if ng != null:
		_txt(_q(ng, "", "b"), str(int(G.g.get("ngoc", 0))))
	var t := (posmod(G.day(), 28))
	_txt(hid.get("#seaT"), G.SEA_N[G.season()] + (" " + str(t % 7 + 1) if G.cfg.s == "auto" else ""))
	var hv := int(G.g.get("harvested", 0))
	var gtx := "Thu hoạch 5 cây trồng (" + str(mini(5, hv)) + "/5)"
	var gfr := minf(1.0, hv / 5.0)
	if G.w_all != null and hid.get("#goal") != null:   # NTWEB fy: mục tiêu tân thủ (w_sys.goal_view)
		var gv: Dictionary = G.w_all.WS.goal_view()
		hid["#goal"].visible = not gv.is_empty()
		if not gv.is_empty():
			gtx = String(gv.txt) + (" · " + String(gv.btn) if gv.get("ready", false) else "")
			gfr = float(gv.bar)
	_txt(hid.get("#goalTxt"), gtx)
	var gb = hid.get("#goalBar")
	if gb != null:
		var par: Control = gb.get_parent().get_parent()
		gb.place(Rect2(gb.r.position, Vector2(par.r.size.x * gfr, gb.r.size.y)))

# #coinsPill bản web rộng theo số (width auto, bám mép phải): số dài hơn thì ô xu nới sang trái, không cắt chữ
func _coins_txt(s: String) -> void:
	var c = hid.get("#coins")
	if c == null or c.texts.is_empty():
		return
	var i: int = c.get_meta("ti", 0)
	var t0: Dictionary = c.texts[i]
	var ns: String = String(c.get_meta("prefix", "")) + s + String(c.get_meta("suffix", ""))
	if t0.s == ns:
		return
	var d: float = Box.text_w(ns, t0.size, t0.w) - Box.text_w(t0.s, t0.size, t0.w)
	c.set_text(i, ns)
	if absf(d) < 0.01:
		return
	var pl = hid.get("#coinsPill")
	if pl != null and pl != c:
		pl.place(Rect2(pl.r.position - Vector2(d, 0), pl.r.size + Vector2(d, 0)))
	c.place(Rect2(c.r.position, c.r.size + Vector2(d, 0)))
	t0.rect = Rect2(t0.rect.position, t0.rect.size + Vector2(d, 0))
	c.redraw()

var _ph := ""
func _clock() -> void:
	# hE: giờ của d0 (giờ thật), hình #clkI theo buổi (kX), chữ #wxT theo ti.cur (uQ, xm)
	var h: float = G.troi.hour()
	var e := int(floor(h))
	var m := int(floor((h - e) * 60.0))
	_txt(hid.get("#clkT"), "Ban ngày" if G.cfg.d == "day" and G.troi.hh < 0.0 else ("Ban đêm" if G.cfg.d == "night" and G.troi.hh < 0.0 else "%02d:%02d" % [e, m]))
	var ph: String = G.troi.dh().phase
	var ci = hid.get("#clkI")
	if ph != _ph and ci != null and ci.kids().size() > 0:
		_ph = ph
		_set_svg(ci.kids()[0], G.troi.KX[ph])
	var w: String = G.troi.cur if G.troi.cur != "" else "nang"
	_txt(hid.get("#wxT"), G.troi.TEN[w])

# ------------------------------------------------------------------ Menu (dock)
var dock_b: Control = null
var dock_btn2: Control = null
var dock_catch: Control = null

func _build_dock() -> void:
	var d: Dictionary = Snap.load_snap("dock")
	var ids := {}
	dock_catch = Control.new()
	dock_catch.mouse_filter = Control.MOUSE_FILTER_STOP
	dock_catch.visible = false
	dock_catch.gui_input.connect(func(e): if _is_tap_down(e): dock_open(false))
	root.add_child(dock_catch)
	for sel in d:
		for n in d[sel]:
			var b := _build(n, ids)
			b.visible = false
			root.add_child(b)
			anchors.append([b, 1, 1])
			if sel == "nav.dock":
				dock_b = b
				_stop(b)
			else:
				dock_btn2 = b
				_click(b, func(): dock_open(false), "scale")
	# each tile: Kho opens the barn, the rest are not here yet
	if dock_b != null:
		for t in _qall(dock_b, "dk", []) + _qall(dock_b, "dkb", []):
			pass
		for b in _buttons(dock_b, []):
			var lab := _label_of(b)
			var words := lab.split(" ", false)   # ô có huy hiệu số ("10 Kho", "đẹp 0 Xây dựng"): so theo chữ trong ô
			if words.has("Kho"):
				_click(b, func(): dock_open(false); kho_open(), "scale94")
			elif lab.contains("Đơn hàng"):
				_click(b, func(): dock_open(false); ord_open(), "scale94")
			elif lab.contains("Xây dựng"):
				_click(b, func(): dock_open(false); bdp.open_shop(), "scale94")
			elif lab == "Nghề":
				_click(b, func(): dock_open(false); ng_open(), "scale94")
				ng_bdg = _bdg_make(d, b)
			elif lab.contains("Sổ làng"):
				_click(b, func(): dock_open(false); sl_open(), "scale94")
				sl_bdg = _bdg_make(d, b)
			else:
				_click(b, func(): say(SOON), "scale94")

func _bdg_make(d: Dictionary, b: Control) -> Control:   # #ngheBdg, #bookBdg: huy hiệu đỏ như số trên nút Kho, ẩn khi 0
	var sn = null
	for sel in d:
		for n in d[sel]:
			var f := Snap.find(n, "bdg")
			if not f.is_empty() and f.get("id", "") == "stockN":
				sn = f
	if sn == null:
		return null
	var n0: Dictionary = sn.duplicate(true)
	var br: Rect2 = b.get_global_rect()
	var bs: Dictionary = b.get_meta("snap", {})
	var ks: Dictionary = {}
	for k in d["nav.dock"][0].kids:
		if k.get("id", "") == "stockPill":
			ks = k
	n0.text = "0"
	Snap._move(n0, Vector2(float(bs.r[0]) - float(ks.r[0]), float(bs.r[1]) - float(ks.r[1])))
	var ids2 := {}
	var bd: Control = _build(n0, ids2, Vector2(float(bs.r[0]), float(bs.r[1])))
	bd.visible = false
	b.add(bd)
	return bd

func _bdg_set(bd: Control, n: int) -> void:
	if bd == null:
		return
	bd.visible = n > 0
	if n > 0 and bd.texts.size():
		bd.set_text(0, str(n))

func _ng_bdg() -> void:   # ngBdg, lV
	if G.w_all == null:
		return
	_bdg_set(ng_bdg, G.w_all.WL.ng_red())
	_bdg_set(sl_bdg, G.w_all.WCA.lv_red())

func _buttons(b: Control, out: Array) -> Array:
	# theo thứ tự trong trang (Snap.build xếp con theo z-index để vẽ: nút "on" bị đẩy xuống cuối)
	var ks: Array = b.kids()
	var sk: Array = b.get_meta("snap", {}).get("kids", [])
	if sk.size() > 0:
		ks.sort_custom(func(x, y): return _di(sk, x) < _di(sk, y))
	for k in ks:
		var n: Dictionary = k.get_meta("snap", {})
		if n.get("tag", "") == "button":
			out.append(k)
		else:
			_buttons(k, out)
	return out

static func _di(sk: Array, k: Control) -> int:
	var n = k.get_meta("snap", null)
	for i in sk.size():
		if is_same(sk[i], n):
			return i
	return sk.find(n)

func _label_of(b: Control) -> String:
	var n: Dictionary = b.get_meta("snap", {})
	var s := _all_text(n)
	return s.strip_edges()

func _all_text(n: Dictionary) -> String:
	var s: String = n.get("text", "")
	for k in n.get("kids", []):
		var t := _all_text(k)
		if t != "":
			s += (" " if s != "" else "") + t
	return s

func dock_open(on: bool) -> void:
	if dock_b == null:
		return
	dock_b.visible = on
	dock_btn2.visible = on
	dock_catch.visible = on
	dock_catch.size = vsize() * Css.K
	var b = hid.get("#dockBtn")
	if b != null:
		b.visible = not on and not focus

func _is_tap_down(e: InputEvent) -> bool:
	return (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT)

# ------------------------------------------------------------------ camera (gv T/w/E, ring E/C/R)
var cam_tw = null      # {z0, z1, w0, w1, s, t}
var cam_back = null    # {c0, to, t}
var cam0 = null        # {c: world centre, z}

func _view_c() -> Dictionary:
	var vp := get_viewport().get_visible_rect().size
	return {"c": main.cam + vp * 0.5 / main.zoom, "z": main.zoom}

func _cam_to(i: int, z1: float, sy: float) -> void:
	# tween so plot i's centre comes to screen (vw/2, sy) at css zoom z1, .32 s ease-out cubic
	var c: Dictionary = G.cells[i]
	var w1 := Vector2(F.en(c.gx + 0.5, c.gy + 0.5), F.nn(c.gx + 0.5, c.gy + 0.5, G.CO))
	var s := Vector2(vw * 0.5, sy)
	var w0: Vector2 = main.cam + s * Css.K / main.zoom
	cam_tw = {"z0": main.zoom, "z1": z1 * Css.K, "w0": w0, "w1": w1, "s": s * Css.K, "t": 0.0}

func _cam_open() -> void:
	if cam0 == null:
		cam0 = cam_back.to if cam_back != null else _view_c()
		cam_back = null

func _cam_close() -> void:
	cam_tw = null
	if cam0 != null:
		cam_back = {"c0": _view_c(), "to": cam0, "t": 0.0}
		cam0 = null

func _cam_step(dt: float) -> void:
	dt = minf(0.05, dt)
	if cam_tw != null:
		var k: Dictionary = cam_tw
		k.t = minf(1.0, k.t + dt / 0.32)
		var e := 1.0 - pow(1.0 - k.t, 3.0)
		main.zoom = lerpf(k.z0, k.z1, e)
		var w: Vector2 = k.w0.lerp(k.w1, e)
		main.cam = w - k.s / main.zoom
		if main.has_method("_clamp_cam"):
			main._clamp_cam()
		if k.t >= 1.0:
			cam_tw = null
	elif cam_back != null:
		var k: Dictionary = cam_back
		k.t = minf(1.0, k.t + dt / 0.3)
		var e := 1.0 - pow(1.0 - k.t, 3.0)
		var vp := get_viewport().get_visible_rect().size
		main.zoom = lerpf(k.c0.z, k.to.z, e)
		var c: Vector2 = k.c0.c.lerp(k.to.c, e)
		main.cam = c - vp * 0.5 / main.zoom
		if main.has_method("_clamp_cam"):
			main._clamp_cam()
		if k.t >= 1.0:
			cam_back = null

func world_down() -> void:
	# chạm/kéo làng: web đóng khay giống, vòng nút, bảng ô (pointerdown ngoài bảng) và dừng camera về
	cam_back = null if gv_i < 0 and rm_i < 0 and not (xfp != null and xfp.is_open()) else cam_back
	cam_tw = null
	if xfp != null:
		xfp.close()
	gv_close()
	rm_close()
	lock_close()
	dock_open(false)

# ------------------------------------------------------------------ khay chọn giống ("gieo")
var gv_b: Control = null
var gv_top: Control = null
var gv_bar: Control = null
var gv_tpl_sel := {}
var gv_tpl := {}
var gv_lk := {}
var gv_bar0 := Rect2()
var gv_i := -1
var gv_sig := ""
var gv_seeds := []

func _build_gv() -> void:
	var d: Dictionary = Snap.load_snap("gv")
	var n0: Dictionary = d[".gv"][0]
	var bar: Dictionary = Snap.find(n0, "gvbar")
	var seeds := []
	for k in bar.kids:
		if String(k.cls).split(" ").has("gvs"):
			seeds.append(k)
		elif String(k.cls).split(" ").has("gvlk"):
			gv_lk = k
	gv_tpl_sel = seeds[0]
	gv_tpl = seeds[1] if seeds.size() > 1 else seeds[0]
	gv_bar0 = Rect2(bar.r[0], bar.r[1], bar.r[2], bar.r[3])
	bar.kids = []
	var ids := {}
	gv_b = _build(n0, ids)
	gv_b.visible = false
	root.add_child(gv_b)
	gv_top = ids[".gvtop"]
	gv_bar = ids[".gvbar"]
	_stop(gv_bar)
	_click(ids.get(".gvst"), func():
		var gi := gv_i
		gv_close()
		if gi >= 0:
			spp.open(gi), "down")

func _gv_order() -> Array:
	# d(): giống đã tới cấp; có hạt + hợp mùa trước, rồi có hạt, rồi hết hạt
	var L := []
	var j := 0
	for c in G.xo:
		if int(G.crop(c).get("lv", 1)) <= G.lv() and (not G.crop(c).get("hyb", false) or int(G.g.barn.get(c, 0)) > 0):
			var n := int(G.g.barn.get(c, 0))
			L.append([c, (0 if G.in_season(c) else 1) if n > 0 else 2, j])
			j += 1
	L.sort_custom(func(a, b): return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]))
	var out := []
	for a in L:
		out.append(a[0])
	return out

func _gv_locked() -> String:
	# v(): "Cấp N mở: ..." giống cấp kế tiếp
	var best := 999
	for c in G.xo:
		var l := int(G.crop(c).get("lv", 1))
		if l > G.lv() and not G.crop(c).get("hyb", false):
			best = mini(best, l)
	if best == 999:
		return ""
	var names := []
	for c in G.xo:
		if int(G.crop(c).get("lv", 1)) == best and not G.crop(c).get("hyb", false):
			names.append(G.crop(c).name)
	return "Cấp " + str(best) + " mở: " + ", ".join(names)

func gv_open(i: int) -> void:
	pc_close()
	lock_close()
	rm_close()
	dock_open(false)
	_cam_open()
	gv_i = i
	gv_sig = ""
	gv_b.visible = true
	_set_focus(true)
	_gv_sync()
	_gv_pos()
	# T(W): đưa ô vào giữa khoảng trống giữa bảng trên và khay dưới; phóng lên 1,6 nếu đang nhỏ hơn 1,2
	var z := cz()
	var zoom_up := bz() < 1.2
	var z1 := clampf(1.6, main.zmin / dpr_v, main.zmax / dpr_v) / U if zoom_up else z
	var D = gv_top.r.size.y
	var wt = vh - 12.0 - gv_bar.r.size.y - 8.0
	var nt = 96.0 + D + 6.0
	var pa = wt - 18.0 * z1
	var g := plot_css(i)
	if not zoom_up and g.y >= nt and g.y <= pa and g.x > 40.0 and g.x < vw - 40.0:
		cam0 = null
		return
	_cam_to(i, z1, clampf((nt + pa) * 0.5, nt, pa))

func gv_close() -> void:
	if gv_i < 0:
		return
	gv_i = -1
	gv_b.visible = false
	_set_focus(false)
	_cam_close()

func _ring5(st: int, cls := "") -> String:
	# e(W) / h(): 5 cung quanh nút sao, cung đã có sao màu vàng
	var s := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 64 64\">"
	for f in 5:
		var j := -90.0 + f * 72.0 + 8.0
		var e := j + 56.0
		var a := "%.2f %.2f" % [32.0 + RA * cos(deg_to_rad(j)), 32.0 + RA * sin(deg_to_rad(j))]
		var b := "%.2f %.2f" % [32.0 + RA * cos(deg_to_rad(e)), 32.0 + RA * sin(deg_to_rad(e))]
		s += "<path d=\"M" + a + "A" + str(RA) + " " + str(RA) + " 0 0 1 " + b + "\" fill=\"none\" stroke=\"" + ("#ffc21a" if f < st else "#f3ead0") + "\" stroke-width=\"5\" stroke-linecap=\"round\"/>"
	return s + "</svg>"

func _set_svg(b: Control, svg: String) -> void:
	if b == null or b.pics.is_empty():
		return
	var t := Css.svg_tex(svg, b.r.size.x, b.r.size.y)
	if t != null and b.pics[0].tex != t:
		b.pics[0].tex = t
		b.redraw()

func _gv_sync() -> void:
	var i := gv_i
	if i < 0:
		return
	var a: Dictionary = G.p(i)
	var order := _gv_order()
	var any_seed := false
	var any_sea := false
	var sig := ""
	for c in order:
		var n := int(G.g.barn.get(c, 0))
		any_seed = any_seed or n > 0
		any_sea = any_sea or G.in_season(c)
		sig += c + str(n) + ("m" if G.in_season(c) else "") + ","
	var st: int = G.star(a) - 1
	sig += "|" + str(G.g.sel) + "|" + str(st)
	if sig == gv_sig:
		return
	gv_sig = sig
	# nhãn: "Hợp mùa · lớn nhanh hơn" (lá xanh) hoặc "Gieo 1 hạt, gặt 2"
	var lab := _q(gv_top, "gvlab")
	var sm := _q(lab, "", "small")
	if sm != null:
		var leaf: Control = sm.kids()[0] if sm.kids().size() > 0 else null
		if leaf != null:
			leaf.visible = any_sea
		_txt(sm, "Hợp mùa · lớn nhanh hơn" if any_sea else "Gieo 1 hạt, gặt 2")
		if not sm.texts.is_empty():
			sm.texts[0].col = Color8(63, 138, 52) if any_sea else Color8(138, 106, 72)
			if not any_sea:
				sm.texts[0].rect = Rect2(0, sm.texts[0].rect.position.y, sm.r.size.x, sm.texts[0].rect.size.y)
			sm.redraw()
	var stb := _q(gv_top, "gvst")
	if stb != null and stb.kids().size() > 0:
		_set_svg(stb.kids()[0], _ring5(st))
	# khay: dựng lại các nút giống từ nút mẫu đã chụp
	for k in gv_bar.kids():
		k.queue_free()
	gv_seeds.clear()
	var o := gv_bar0.position
	var dx: float = float(gv_tpl.r[0]) - float(gv_tpl_sel.r[0])
	if dx <= 0.0:
		dx = 60.0
	var dy := 82.0
	var idx := 0
	for c in order:
		var n := int(G.g.barn.get(c, 0))
		var tp: Dictionary = gv_tpl_sel if (G.g.sel == c and n > 0) else gv_tpl
		var base := Vector2(float(gv_tpl_sel.r[0]), float(gv_tpl_sel.r[1]))
		var to := base + Vector2((idx % 5) * dx, int(idx / 5) * dy)
		var nd := Snap.moved(tp, to - Vector2(float(tp.r[0]), float(tp.r[1])))
		_gv_fill(nd, c, n)
		var sb := _build(nd, {}, o)
		gv_bar.add(sb)
		if n < 1:
			var gi := _q(sb, "gvi")
			if gi != null:
				gi.modulate.a = 0.7
			var gn := _q(sb, "gvn")
			if gn != null:
				gn.modulate.a = 0.6
		var cc: String = c
		_click(sb, func(): _gv_pick(cc), "scale92")
		gv_seeds.append(sb)
		idx += 1
	var rows := int(ceil(idx / 5.0))
	var lk := _gv_locked()
	if lk != "" and not gv_lk.is_empty():
		var y := float(gv_tpl_sel.r[1]) + rows * dy + (76.0 - float(gv_lk.r[3])) * 0.5
		var nd := Snap.moved(gv_lk, Vector2(0, y - float(gv_lk.r[1])))
		nd.text = lk
		nd.erase("tr")
		gv_bar.add(_build(nd, {}, o))
		rows += 1
	if not any_seed:
		var e: Control = Box.new()
		e.style("", 1.0)
		e.place(Rect2(10, 8, gv_bar0.size.x - 20, 76))
		e.text("Hết giống rồi! Mua ở Chợ phiên, nhà hàng xóm hoặc chợ nổi sáng sớm.", Rect2(0, 0, gv_bar0.size.x - 20, 76), 14, 600, Color.WHITE, "center", [], true)
		gv_bar.add(e)
		rows = maxi(rows, 1)
	var h := minf(256.0, 16.0 + rows * 76.0 + maxf(0, rows - 1) * 6.0)
	gv_bar.place(Rect2(Vector2((vw - gv_bar0.size.x) * 0.5, vh - 12.0 - h), Vector2(gv_bar0.size.x, h)))

func _gv_fill(nd: Dictionary, c: String, n: int) -> void:
	# đổi nút mẫu thành nút của giống c: hình, tên, số hạt, lá hợp mùa
	var gi := Snap.find(nd, "gvi")
	var sv: String = FileAccess.get_file_as_string("res://ui/svg/gv/" + c + ".svg")
	for k in gi.get("kids", []):
		if k.tag == "svg" and sv != "":
			k.svg = sv
	var cnt := Snap.find(nd, "gvc")
	if n > 0 and not cnt.is_empty():
		cnt.text = G.fmt_k(n)
		cnt.erase("tr")
		var fs := 14.0
		var tw: float = Box.text_w(cnt.text, fs, 800)
		var right: float = float(gi.r[0]) + float(gi.r[2]) + 7.0
		cnt.r = [right - tw, cnt.r[1], tw, cnt.r[3]]
	elif n <= 0:
		Snap.remove(nd, "gvc")
	if not G.in_season(c):
		Snap.remove(nd, "gvm")
	var gn := Snap.find(nd, "gvn")
	var name: String = G.crop(c).name
	gn.text = name
	gn.erase("tr")
	var tw2: float = Box.text_w(name, 12.0, 600)
	var bw: float = float(nd.r[2])
	var cx: float = float(nd.r[0]) + bw * 0.5
	var lines := 1 if tw2 <= bw - 2.0 else 2
	var w := minf(tw2, bw)
	gn.r = [cx - w * 0.5, gn.r[1], w, 13.2 * lines]
	gn.css["white-space"] = "normal" if lines > 1 else "nowrap"

func _gv_pick(c: String) -> void:
	var i := gv_i
	if i < 0:
		return
	if int(G.g.barn.get(c, 0)) <= F.seeds_queued(c):
		say("Hết giống " + String(G.crop(c).name).to_lower() + ". Mua ở Chợ phiên, nhà hàng xóm hoặc chợ nổi sáng sớm.")
		return
	G.g.sel = c
	F.queue_job(i, "plant", c)
	gv_close()

func _gv_pos() -> void:
	# k(): bảng sao + nhãn đứng trên ô, không ra khỏi màn hình
	if gv_i < 0:
		return
	var ft := plot_css(gv_i)
	var st = gv_top.r.size.x
	var ut = gv_top.r.size.y
	var x := clampf(ft.x, st / 2.0 + 8.0, vw - st / 2.0 - 8.0)
	var y := maxf(ut + 96.0 - 30.0, ft.y - 6.0 * cz())
	_move(gv_top, Vector2(round(x) - st / 2.0, round(y) - ut))

# ------------------------------------------------------------------ vòng nút ô ruộng ("ring")
var rm_g: Control = null      # đang lớn: chín ngay / sao / tưới + nhãn giờ
var rm_r: Control = null      # chín: nút liềm
var rm_gi := {}
var rm_i := -1
var rm_t := -1               # cây ăn trái đang mở (g.objs idx): xài chung vòng nút ô ruộng, không có nút sao
var rm_v := {}               # con vật {t, j} / chuồng {t, j: -1}: xài chung vòng nút ô ruộng (rm_vn.gd lo phần riêng)
var rv = null                # rm_vn.gd
var rm_x0 := {}              # chỗ gốc của .fast / .water
var rm_in0 := {}             # hình trong gốc của .star / .water / .rmth (+ vòng gốc .rmth)
var rm_sig := ""
var dim: Control = null
var dim_mat: ShaderMaterial = null
var dim_a := 0.0

func _build_rm() -> void:
	var d: Dictionary = Snap.load_snap("rmg")
	# nút .fast thêm một ô hình trong (chép ô hình của .star, dời sang): con vật / chuồng đặt hình món vào đó
	var fn := Snap.find(d[".rm"][0], "fast")
	var sn := Snap.find(d[".rm"][0], "star")
	fn.kids.append(Snap.moved(sn.kids[1], Vector2(float(fn.r[0]) - float(sn.r[0]), 0.0)))
	rm_g = _build(d[".rm"][0], rm_gi)
	rm_g.visible = false
	root.add_child(rm_g)
	var d2: Dictionary = Snap.load_snap("rmr")
	var ids2 := {}
	rm_r = _build(d2[".rm"][0], ids2)
	rm_r.visible = false
	root.add_child(rm_r)
	for k in [".fast", ".water"]:
		rm_x0[k] = rm_gi[k].r.position
	for k in [".star", ".water"]:
		rm_in0[k] = rm_gi[k].kids()[-1].get_meta("snap", {}).get("svg", "")
	var th: Control = ids2.get(".rmth")
	rm_in0[".rmth"] = th.kids()[-1].get_meta("snap", {}).get("svg", "")
	rm_in0["rmth_ring"] = th.kids()[0].get_meta("snap", {}).get("svg", "")
	rm_gi[".rmth"] = th
	rv = load("res://logic/rm_vn.gd").new(self)
	_click(rm_gi.get(".rmt"), func(): _rm_do("chip"))
	_click(rm_gi.get(".fast"), func(): _rm_do("fast"))
	_click(rm_gi.get(".star"), func(): _rm_do("star"))
	_click(rm_gi.get(".water"), func(): _rm_do("water"))
	_click(ids2.get(".rmth"), func(): _rm_do("harvest"))

func _build_dim() -> void:
	# .rmdim: tối nhẹ quanh ô đang chọn (radial-gradient ellipse)
	dim = Control.new()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform vec2 c; uniform vec2 r; uniform float a;\nvoid fragment(){ vec2 p = (FRAGCOORD.xy - c) / r; float d = length(p); float k = clamp((d - 0.7) / 0.3, 0.0, 1.0); COLOR = vec4(0.0, 0.0, 0.0, 0.25 * k * a); }"
	dim_mat.shader = sh
	dim.material = dim_mat
	dim.draw.connect(func(): dim.draw_rect(Rect2(Vector2.ZERO, dim.size), Color.WHITE))
	dim.visible = false
	root.add_child(dim)

func rm_open(i: int) -> void:
	pc_close()
	lock_close()
	gv_close()
	dock_open(false)
	_cam_open()
	rm_i = i
	rm_t = -1
	rm_sig = ""
	_rm_kind(false)
	_set_focus(true)
	_rm_sync()
	_rm_pos()
	# E(It): chỉ đưa camera khi đang nhỏ hơn 1,2
	if bz() >= 1.2:
		cam0 = null
		return
	var z1 := clampf(1.6, main.zmin / dpr_v, main.zmax / dpr_v) / U
	var a: Dictionary = G.p(i)
	var gt: float = F.OU[G.stage(a)] if a.c != null else 20.0
	var box := _rm_in()
	var A = box.r.size.y if box != null else 120.0
	var at = -(gt + 16.0) * z1 - A
	var pt := 18.0 * z1
	_cam_to(i, z1, (96.0 + vh) / 2.0 - (at + pt) / 2.0)

func _rm_in() -> Control:
	var a: Dictionary = G.p(rm_i) if rm_i >= 0 else {}
	var top := rm_r if (not a.is_empty() and G.ripe(a)) else rm_g
	return top.kids()[0] if top.kids().size() > 0 else null

func rm_on() -> bool:
	return rm_i >= 0 or rm_t >= 0 or not rm_v.is_empty()

func rm_close() -> void:
	if not rm_on():
		return
	var plot := rm_i >= 0
	rm_i = -1
	rm_t = -1
	rm_v = {}
	if xfp != null:
		xfp._ask_close()   # chip hỏi (chín ngay, chữa bệnh...) đi theo vòng nút
	rm_g.visible = false
	rm_r.visible = false
	_set_focus(false)
	if plot:
		_cam_close()

func _rm_kind(tree: bool) -> void:   # ô ruộng / cây ăn trái (cây: ẩn nút sao, dồn chín ngay / tưới vào giữa)
	_rm_reset()
	rm_gi[".star"].visible = not tree
	var d := 32.0 if tree else 0.0
	for k in rm_x0:
		_move(rm_gi[k], rm_x0[k] + Vector2(d if k == ".fast" else -d, 0.0))

func _rm_reset() -> void:   # trả vòng nút về như ô ruộng (hình trong gốc, sen hiện, chip có đồng hồ)
	for k in [".fast", ".star", ".water"]:
		var b: Control = rm_gi[k]
		b.visible = true
		b.modulate.a = 1.0
		_move(b, rm_x0.get(k, b.r.position))
	_rm_ic(".fast", "")
	_rm_ic(".star", rm_in0[".star"])
	_rm_ic(".water", rm_in0[".water"])
	_rm_ic(".rmth", rm_in0[".rmth"])
	_set_svg(rm_gi[".rmth"].kids()[0], rm_in0["rmth_ring"])
	_q(rm_gi[".fast"], "rmsen").visible = true
	var sm := _q(rm_gi[".rmt"], "", "small")
	if sm != null:
		sm.visible = true

func _rm_ic(k: String, svg: String, big := false) -> void:   # hình trong của nút k ("" = ẩn); big: hình món (khung 64 có chừa lề) 40 thay 28
	var b: Control = rm_gi[k].kids()[-1]
	b.visible = svg != ""
	if not b.has_meta("r0"):
		b.set_meta("r0", b.r)
	var r0: Rect2 = b.get_meta("r0")
	var r1 := r0.grow(6.0) if big else r0
	if b.r != r1:
		b.place(r1)
		if not b.pics.is_empty():
			b.pics[0].rect = Rect2(Vector2.ZERO, r1.size)
			b.pics[0].tex = null   # vẽ lại svg đúng cỡ mới
	if svg != "":
		_set_svg(b, svg)

func _rm_col(b: Control, col) -> void:   # màu chữ dòng nhỏ của chip (null = màu gốc của bản chụp)
	if b.texts.is_empty():
		return
	if not b.has_meta("c0"):
		b.set_meta("c0", b.texts[0].col)
	var c: Color = col if col is Color else b.get_meta("c0")
	if b.texts[0].col != c:
		b.texts[0].col = c
		b.redraw()

func _rm_title(rt: Control, mid: bool) -> void:   # tên trên chip: mid = chỉ có tên thì đưa vào giữa chip
	var ti: int = rt.get_meta("ti", 0)
	if rt.texts.size() <= ti:
		return
	if not rt.has_meta("ty0"):
		rt.set_meta("ty0", rt.texts[ti].rect.position.y)
	var y: float = (rt.r.size.y - rt.texts[ti].rect.size.y) * 0.5 if mid else float(rt.get_meta("ty0"))
	if absf(rt.texts[ti].rect.position.y - y) > 0.01:
		rt.texts[ti].rect.position.y = y
		rt.redraw()

func _rm_note(rt: Control, s: String, col = null) -> void:   # dòng chữ nhỏ của chip không có đồng hồ ("" = ẩn dòng, tên vào giữa); col: màu chữ
	_rm_title(rt, s == "")
	var sm := _q(rt, "", "small")
	if sm == null:
		return
	sm.visible = s != ""
	if s == "":
		return
	for k in sm.kids():
		var n: Dictionary = k.get_meta("snap", {})
		if n.get("tag", "") == "svg":
			k.visible = false
		elif n.get("tag", "") == "b":
			var w := Box.text_w(s, 12.0, 800) + 2.0
			_txt(k, s)
			_rm_col(k, col)
			k.place(Rect2(Vector2((sm.r.size.x - w) * 0.5, k.r.position.y), Vector2(w, k.r.size.y)))
			k.texts[0].rect = Rect2(0, k.texts[0].rect.position.y, w, k.texts[0].rect.size.y)
			k.texts[0].al = "left"
			k.redraw()
	if sm.has_meta("wet"):
		sm.get_meta("wet").visible = false

func rm_tree(t: int) -> void:   # hg: chạm cây ăn trái
	close_all()
	if G.w_all.WR.ql(t) == null:
		return
	rm_t = t
	rm_sig = ""
	_rm_kind(true)
	_set_focus(true)
	_rm_sync()
	_rm_pos()

func _rm_tree_sync() -> void:   # Rj: vòng trái (đỏ) + số sen đỏ, vòng nước, nhãn tên + giờ còn lại
	var R = G.w_all.WR
	var t = R.ql(rm_t)
	if t == null:
		rm_close()
		return
	var ripe: bool = R.wc(t)
	rm_g.visible = not ripe
	rm_r.visible = ripe
	if ripe:
		return
	var e: Dictionary = R._ei()[t.id]
	var fw := float(t.fw)
	var c: float = R.tree_left(rm_t)
	var fast = rm_gi.get(".fast")
	if fast != null:
		_set_svg(fast.kids()[0], _ring("rmf", "#e8324a", "rgba(232,50,74,.16)", round(minf(1.0, float(t.fp) / float(e.time)) * 1000.0) / 1000.0))
		_txt(_q(fast, "", "b"), str(R.ro(c)))
	var wat = rm_gi.get(".water")
	if wat != null:
		_set_svg(wat.kids()[0], _ring("rmw", "#1e90e8", "rgba(30,144,232,.15)", round(clampf(fw / R.f2(), 0.0, 1.0) * 1000.0) / 1000.0))
		wat.modulate.a = 0.5 if fw >= R.f2() * 0.85 else 1.0   # "Đất còn ướt"
	var rt = rm_gi.get(".rmt")
	if rt != null:
		_txt(rt, String(G.lang.Pi[t.id].n))
		_rm_small(rt, fw > 0.0, tfmt((c - minf(c, fw) * 0.09) if fw > 0.0 else c))

func _rm_tree_pos() -> void:   # am (fi.t): vòng nút đứng trên ngọn cây
	var L = G.lang
	var o: Dictionary = L.objs()[rm_t]
	var tp: Dictionary = L.Pi[o.id]
	var fw := float(tp.fw)
	var fd := float(tp.fd)
	var gx := float(o.gx)
	var gy := float(o.gy)
	var foot := Vector2(F.en(gx + fw / 2.0, gy + fd / 2.0), F.nn(gx + fw / 2.0, gy + fd / 2.0))
	var top: float = L.F.lang_ve.top_of(o)
	var tb := rm_r if G.w_all.WR.wc(o) else rm_g
	var box: Control = tb.kids()[0]
	var w = box.r.size.x
	var h = box.r.size.y
	var ra: Vector2 = (foot - main.cam) * main.zoom / Css.K
	var x := clampf(ra.x, w / 2.0 + 8.0, vw - w / 2.0 - 8.0)
	var y := clampf(ra.y + (top - 6.0) * cz(), h + 8.0, vh - 8.0)
	_move(tb, Vector2(round(x), round(y)))
	_move(box, Vector2(-w / 2.0, -h))
	# vignette quanh gốc cây + ngọn
	var mn := Vector2(INF, INF)
	var mx := -mn
	for p in [[0, 0], [fw, 0], [fw, fd], [0, fd]]:
		var q: Vector2 = (Vector2(F.en(gx + p[0], gy + p[1]), F.nn(gx + p[0], gy + p[1])) - main.cam) * main.zoom
		mn = mn.min(q)
		mx = mx.max(q)
	mn.y = minf(mn.y, (foot.y + top - main.cam.y) * main.zoom)
	dim_mat.set_shader_parameter("c", (mn + mx) * 0.5)
	dim_mat.set_shader_parameter("r", Vector2((mx.x - mn.x) / 2.0 * 1.3 + 16.0 * Css.K, (mx.y - mn.y) / 2.0 * 1.3 + 16.0 * Css.K))

func _rm_tree_do(k: String) -> void:
	var t := rm_t
	var R = G.w_all.WR
	var o = R.ql(t)
	if o == null:
		return
	var WRU = G.w_all.WRU
	if k == "harvest":
		if R.wc(o):
			rm_close()
			WRU.px(t, "tharvest")
	elif k == "water":
		if float(o.fw) >= R.f2() * 0.85:
			G.toast.emit("Đất còn ướt.")
			return
		rm_close()
		WRU.px(t, "twater")
	elif k == "fast" and not R.wc(o):
		var pa := func():
			if rm_t == t and R.tree_now(t):
				rm_close()
				WRU.px(t, "tharvest")
		xfp._ask(rm_gi.get(".fast"), R.ro(R.tree_left(t)), "Ra trái ngay cây " + String(G.lang.Pi[o.id].n).to_lower() + "?", "", pa)

func _ring(cls: String, col: String, bg: String, fr: float) -> String:
	# s(): vòng tiến độ (lớn: đỏ, nước: xanh), bắt đầu từ đỉnh
	var d := fr * CIRC
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 64 64\"><circle cx=\"32\" cy=\"32\" r=\"28.5\" fill=\"none\" stroke=\"" + bg + "\" stroke-width=\"5\"/>" + ("<circle cx=\"32\" cy=\"32\" r=\"28.5\" fill=\"none\" stroke=\"" + col + "\" stroke-width=\"5\" stroke-linecap=\"round\" stroke-dasharray=\"%.2f %.2f\" transform=\"rotate(-90 32 32)\"/>" % [d, CIRC] if fr > 0.004 else "") + "</svg>"

static func tfmt(t: float) -> String:   # o(): 1g 5p / 3p 20s / 40s
	var s := int(maxf(0.0, ceil(t)))
	var h := s / 3600
	var m := (s % 3600) / 60
	var x := s % 60
	return (str(h) + "g " + str(m) + "p") if h else ((str(m) + "p " + str(x) + "s") if m else (str(x) + "s"))

func _rm_sync() -> void:
	if not rm_v.is_empty():
		rv.sync()
		return
	if rm_t >= 0:
		_rm_tree_sync()
		return
	var i := rm_i
	if i < 0:
		return
	var a: Dictionary = G.p(i)
	if a.c == null or not a.u:
		rm_close()
		return
	var ripe: bool = G.ripe(a)
	rm_g.visible = not ripe
	rm_r.visible = ripe
	if ripe:
		return
	var cr: Dictionary = G.crop(a.c)
	var gfr := minf(1.0, float(a.g) / float(cr.time))
	var hold: float = G.water_hold(a)
	var wfr := clampf(float(a.w) / hold, 0.0, 1.0)
	var at: float = G.time_left(a)
	var pearls := maxi(1, int(ceil(at / 600.0)))
	var st: int = G.star(a) - 1
	var fast = rm_gi.get(".fast")
	if fast != null:
		_set_svg(fast.kids()[0], _ring("rmf", "#e8324a", "rgba(232,50,74,.16)", round(gfr * 1000.0) / 1000.0))
		_txt(_q(fast, "", "b"), str(pearls))
	var wat = rm_gi.get(".water")
	if wat != null:
		_set_svg(wat.kids()[0], _ring("rmw", "#1e90e8", "rgba(30,144,232,.15)", round(wfr * 1000.0) / 1000.0))
	var star = rm_gi.get(".star")
	if star != null:
		_set_svg(star.kids()[0], _ring5(st).replace("#f3ead0", "#f3ead0"))
	# nhãn: tên cây + (Đang ướt ·) đồng hồ + giờ còn lại
	var rt = rm_gi.get(".rmt")
	if rt != null:
		_txt(rt, cr.name)
		var left := (at - minf(at, float(a.w)) * 0.09) if float(a.w) > 0.0 else at
		_rm_small(rt, float(a.w) > 0.0, tfmt(left))

func _rm_small(rt: Control, wet: bool, tm: String) -> void:
	# small: flex, giữa, gap 4: [Đang ướt][·] [đồng hồ 16] [giờ]
	var sm := _q(rt, "", "small")
	if sm == null:
		return
	var clk: Control = null
	var tb: Control = null
	for k in sm.kids():
		var n: Dictionary = k.get_meta("snap", {})
		if n.get("tag", "") == "svg":
			clk = k
		elif n.get("tag", "") == "b":
			tb = k
	if clk == null or tb == null:
		return
	_txt(tb, tm)
	_rm_col(tb, null)
	_rm_title(rt, false)
	sm.visible = true
	var w1 := Box.text_w("Đang ướt", 12.0, 600) if wet else 0.0
	var w2 := Box.text_w("·", 12.0, 600) if wet else 0.0
	var wt := Box.text_w(tm, 12.0, 800)
	var gap := 4.0
	var total := (w1 + gap + w2 + gap if wet else 0.0) + 16.0 + gap + wt
	var x = (sm.r.size.x - total) * 0.5
	if not sm.has_meta("wet"):
		var b1: Control = Box.new()
		b1.style("", 1.0)
		b1.place(Rect2(0, 0, 60, sm.r.size.y))
		b1.text("Đang ướt", Rect2(0, 0, 60, sm.r.size.y), 12.0, 600, Color8(138, 106, 72), "left")
		b1.text("·", Rect2(0, 0, 10, sm.r.size.y), 12.0, 600, Color8(138, 106, 72), "left")
		sm.add(b1)
		sm.set_meta("wet", b1)
	var wb: Control = sm.get_meta("wet")
	wb.visible = wet
	if wet:
		wb.texts[0].rect = Rect2(x, 0, w1, sm.r.size.y)
		wb.texts[1].rect = Rect2(x + w1 + gap, 0, w2, sm.r.size.y)
		wb.redraw()
		x += w1 + gap + w2 + gap
	clk.visible = true
	_move(clk, Vector2(x, clk.r.position.y))
	x += 16.0 + gap
	tb.place(Rect2(Vector2(x, tb.r.position.y), Vector2(wt + 2.0, tb.r.size.y)))
	tb.texts[0].rect = Rect2(0, tb.texts[0].rect.position.y, wt + 2.0, tb.texts[0].rect.size.y)
	tb.texts[0].al = "left"
	tb.redraw()

func _rm_pos() -> void:
	# rt(): vòng nút đứng trên ngọn cây
	if not rm_v.is_empty():
		rv.pos()
		return
	if rm_t >= 0:
		_rm_tree_pos()
		return
	if rm_i < 0:
		return
	var a: Dictionary = G.p(rm_i)
	var top := rm_r if G.ripe(a) else rm_g
	var box: Control = top.kids()[0]
	var ra := plot_css(rm_i)
	var gt: float = F.OU[G.stage(a)] if a.c != null else 20.0
	var w = box.r.size.x
	var h = box.r.size.y
	var x := clampf(ra.x, w / 2.0 + 8.0, vw - w / 2.0 - 8.0)
	var y := clampf(ra.y - (gt + 16.0) * cz(), h + 8.0, vh - 8.0)
	_move(top, Vector2(round(x), round(y)))
	_move(box, Vector2(-w / 2.0, -h))
	# vignette quanh ô
	var q := []
	var c: Dictionary = G.cells[rm_i]
	for p in [[0, 0], [1, 0], [1, 1], [0, 1]]:
		q.append((Vector2(F.en(c.gx + p[0], c.gy + p[1]), F.nn(c.gx + p[0], c.gy + p[1], G.CO)) - main.cam) * main.zoom)
	var mn: Vector2 = q[0]
	var mx: Vector2 = q[0]
	for p in q:
		mn = mn.min(p)
		mx = mx.max(p)
	mn.y -= gt * main.zoom
	var rr := Vector2((mx.x - mn.x) / 2.0 * 1.3 + 16.0 * Css.K, (mx.y - mn.y) / 2.0 * 1.3 + 16.0 * Css.K)
	dim_mat.set_shader_parameter("c", (mn + mx) * 0.5)
	dim_mat.set_shader_parameter("r", rr)

func _rm_do(k: String) -> void:
	if not rm_v.is_empty():
		rv.act(k)
		return
	if k == "chip":
		return
	if rm_t >= 0:
		_rm_tree_do(k)
		return
	var i := rm_i
	if i < 0:
		return
	var a: Dictionary = G.p(i)
	if k == "harvest":
		if G.ripe(a):
			rm_close()
			F.queue_job(i, "harvest")
		return
	if k == "fast":   # dd(nút, Ro(b3), fL, "Chín ngay ...?")
		if G.ripe(a) or a.c == null:
			return
		var nt := maxi(1, int(ceil(G.time_left(a) / 600.0)))   # Ro
		var pa := func():
			if rm_i == i and G.fast_ripe(i):
				rm_close()
				F.queue_job(i, "harvest")
		xfp._ask(rm_gi.get(".fast"), nt, "Chín ngay " + String(G.crop(a.c).name).to_lower() + "?", "", pa)
		return
	if k == "star":
		rm_close()
		spp.open(i)
		return
	if k == "water":
		rm_close()
		F.queue_job(i, "water")

# ------------------------------------------------------------------ ô chưa mở (#ppop, G1 "lock")
var lk_b: Control = null
var lk_ids := {}
var lk_i := -1
var lk_note: Control = null
var lk_h0 := 0.0

func _build_lock() -> void:
	var d: Dictionary = Snap.load_snap("lock")
	lk_b = _build(d["#ppop"][0], lk_ids)
	lk_b.visible = false
	_stop(lk_b)
	root.add_child(lk_b)
	lk_h0 = lk_b.r.size.y
	_click(lk_ids.get(".ppbig"), _lock_buy)
	_click(lk_ids.get(".ppx"), lock_close)

func lock_open(i: int) -> void:
	pc_close()
	gv_close()
	rm_close()
	dock_open(false)
	lk_i = i
	lk_b.visible = true
	_lock_sync()
	_lock_pos()

func lock_close() -> void:
	lk_i = -1
	if lk_b != null:
		lk_b.visible = false

func _lock_sync() -> void:
	if lk_i < 0:
		return
	var c: int = G.open_cost()
	var btn = lk_ids.get(".ppbig")
	if btn != null:
		_txt(btn, "Mở ô đất · " + G.fmt_n(c))
		btn.modulate.a = 1.0 if int(G.g.coins) >= c else 0.55
	var more: int = G.lv_for_more()
	var note := ("Đã đủ " + str(G.max_open()) + " ô cho cấp này. Lên cấp " + str(more) + " mở thêm.") if more > 0 else ""
	if note != "" and lk_note == null:
		lk_note = Box.new()
		lk_note.style("", 1.0)
		var pin = lk_ids.get(".u2pin")
		var y: float = (pin.r.end.y if pin != null else lk_h0) - 10.0
		lk_note.place(Rect2(12, y, lk_b.r.size.x - 24, 18))
		lk_note.text(note, Rect2(0, 0, lk_b.r.size.x - 24, 18), 12.0, 400, Color8(138, 120, 96), "center", [], true)
		lk_b.add(lk_note)
	if lk_note != null:
		lk_note.visible = note != ""
		if note != "":
			lk_note.set_text(0, note)
	var h := lk_h0 + (18.0 if note != "" else 0.0)
	if absf(lk_b.r.size.y - h) > 0.5:
		lk_b.place(Rect2(lk_b.r.position, Vector2(lk_b.r.size.x, h)))

func _lock_pos() -> void:
	# am(): trên ô 26 px; sát mép trên thì xuống dưới ô; mũi tên chỉ đúng ô (--ax)
	if lk_i < 0:
		return
	var t := plot_css(lk_i, 0.0)
	var o = lk_b.r.size.x
	var l = lk_b.r.size.y
	var s := maxf(8.0, minf(vw - o - 8.0, t.x - o / 2.0))
	var h = t.y - l - 26.0
	var below := false
	if h < 70.0:
		h = t.y + 24.0
		below = true
	h = maxf(8.0, minf(vh - l - 8.0, h))
	_move(lk_b, Vector2(round(s), round(h)))
	var ax := clampf(t.x - s, 18.0, o - 18.0)
	var arrow: Control = null
	for k in lk_b.kids():
		if not k.has_meta("snap"):
			arrow = k
	if arrow != null:
		arrow.position = Vector2(ax - arrow.r.size.x * 0.5, (-arrow.r.size.y * 0.5) if below else (l - arrow.r.size.y * 0.5)) * Css.K

func _lock_buy() -> void:
	var i := lk_i
	if i < 0:
		return
	# vá L1 cho iy: đủ cấp mà thiếu xu -> "Mở ô đất còn thiếu xu:" bù bằng sen đỏ rồi mở luôn (hw)
	var t: int = G.open_cost()
	if G.lv_for_more() == 0 and int(G.g.coins) < t and not G.p(i).u and G.owned(i):
		lock_close()
		_lack_open([], "Mở ô đất còn thiếu xu:", func():
			if G.open_plot(i):
				F.ts(i, "unlock"), t - int(G.g.coins))
		return
	if G.open_plot(i):
		F.ts(i, "unlock")
		lock_close()

# ------------------------------------------------------------------ Kho
var kho_roots := []          # Hàng hóa, Vật liệu, Đồ dùng
var kho_ids := []
var kho_tab := 0
var kho_on := false
var kh_tpl_hot := {}
var kh_tpl := {}
var kh_grid0 := Rect2()
var kh_li0 := Vector2(16, 243)   # góc thẻ đầu tiên
var kh_grid0s := Rect2()     # lưới khi đang chọn một món (khDet mở, lưới thấp lại)
var kh_tpl_sel := {}         # thẻ đang chọn (viền xanh, nền xanh nhạt)
var kh_det: Control = null   # #khDet: món đang chọn, giá, số lượng, nút bán
var kh_q := 1                # vi.q
var kh_sel := ""
var kh_f := "all"
var kh_sort := "n"
var kh_sig := ""
var kh_conf := 0.0
var kh_chips := []           # [Box, cat, snap]
var kh_chip_on := {}
var kh_chip_off := {}
const KH_CAT := [["all", "Tất cả"], ["nong", "Nông sản"], ["trai", "Trái cây"], ["nuoi", "Vật nuôi"], ["song", "Cá"], ["chebien", "Chế biến"], ["khac", "Khác"]]
const KH_SORT := [["n", "Nhiều nhất"], ["v", "Đáng giá nhất"], ["p", "Giá lên"], ["a", "Tên A–Z"]]

func _build_kho() -> void:
	for nm in ["kho", "kho2", "kho3", "kho_sel"]:
		var d: Dictionary = Snap.load_snap(nm)
		var n: Dictionary = d["#pov"][0]
		if nm == "kho_sel":
			var g2 := Snap.find(n, "khgrid")
			for li in g2.get("kids", []):
				if String(li.cls).split(" ").has("sel"):
					kh_tpl_sel = li
			kh_grid0s = Rect2(g2.r[0], g2.r[1], g2.r[2], g2.r[3])
			g2.kids = []
		if nm == "kho":
			var grid := Snap.find(n, "khgrid")
			var lis: Array = grid.get("kids", [])
			for li in lis:
				if String(li.cls).split(" ").has("hot") and kh_tpl_hot.is_empty():
					kh_tpl_hot = li
				elif kh_tpl.is_empty() and not String(li.cls).split(" ").has("hot"):
					kh_tpl = li
			if kh_tpl.is_empty() and lis.size() > 0:
				kh_tpl = lis[0]
			if kh_tpl_hot.is_empty():
				kh_tpl_hot = kh_tpl
			kh_grid0 = Rect2(grid.r[0], grid.r[1], grid.r[2], grid.r[3])
			if lis.size() > 0:
				kh_li0 = Vector2(lis[0].r[0], lis[0].r[1])
			grid.kids = []
		var ids := {}
		var b := _build(n, ids)
		b.visible = false
		root.add_child(b)
		anchors.append([b, 0.5, 0.5])
		kho_roots.append(b)
		kho_ids.append(ids)
		_click(ids.get("#pClose"), kho_close, "scale")
		_click(ids.get(".khst"), func(): if khp != null: khp.open(), "scale")
		var bk = ids.get(".pbk")
		if bk != null:
			_stop(bk)
			bk.gui_input.connect(func(e): if _is_tap_down(e): kho_close())
		var win = ids.get(".pwin")
		if win != null:
			_stop(win)
		# tabs
		var seg = ids.get(".khseg")
		if seg != null:
			var j := 0
			for t in _buttons(seg, []):
				var jj := j
				_click(t, func(): _kho_tab(jj))
				j += 1
	var ids0: Dictionary = kho_ids[0]

	_click(ids0.get("#sellAll"), _kho_sell_all)
	_build_det()
	for idq in [ids0, kho_ids[3]]:
		_click(idq.get(".u2sort"), _kho_sort)
		var chips = idq.get("#khChips")
		if chips != null:
			var L := _buttons(chips, [])
			for q in L.size():
				var sn: Dictionary = L[q].get_meta("snap")
				if String(sn.cls).split(" ").has("on"):
					kh_chip_on = sn
				elif kh_chip_off.is_empty():
					kh_chip_off = sn
				var cat: String = KH_CAT[q][0] if q < KH_CAT.size() else "khac"
				kh_chips.append([L[q], cat, sn])
				var cc := cat
				_click(L[q], func(): kh_f = cc; kh_sig = ""; _kho_chips(), "scale94")
	# Vật liệu: chạm ô để xem
	for b in _qall(kho_roots[1], "u2vt", []):
		var bb: Control = b
		_click(bb, func(): _kho_vl_pick(bb), "scale94")

func _kho_sort() -> void:
	var k := 0
	for q in KH_SORT.size():
		if KH_SORT[q][0] == kh_sort:
			k = q
	kh_sort = KH_SORT[(k + 1) % KH_SORT.size()][0]
	kh_sig = ""
	say("Sắp xếp: " + KH_SORT[(k + 1) % KH_SORT.size()][1])
	_kho_sync()

func kho_open() -> void:
	for p in [slp, utp, hrp, huip, gpp, tnp]:
		if p != null:
			p.close()
	if vlp != null:
		vlp.close()
	if ngp != null:
		ngp.close()
	if nvp != null:
		nvp.close()
	pc_close()
	ord_close()
	gv_close()
	rm_close()
	lock_close()
	kho_on = true
	kh_sig = ""
	_kho_tab(kho_tab)

func _kho_full(n: int, cap: int) -> void:
	if khp != null:
		khp.full(n, cap)

func kho_close() -> void:
	kho_on = false
	for b in kho_roots:
		b.visible = false

func _kho_tab(j: int) -> void:
	if j != kho_tab:
		kh_sel = ""
	kho_tab = j
	_kho_show()

func _kho_show() -> void:
	# Hàng hóa có 2 dáng: chưa chọn (nút Bán hết) / đang chọn một món (khDet)
	var vis := kho_tab if not (kho_tab == 0 and kh_sel != "") else 3
	for q in kho_roots.size():
		kho_roots[q].visible = kho_on and q == vis
	kh_sig = ""
	_kho_sync()

func _cat(t: String) -> String:   # rP
	if G.D.crops.has(t):
		return "nong"
	var a: Dictionary = G.item(t)
	var n: String = a.get("from", "")
	if n in ["fish", "bun", "ao", "song"]:
		return "song"
	if n == "tree":
		return "trai"
	if n in ["ga", "cuu", "bo", "heo", "de", "vit", "ong"]:
		return "nuoi"
	if n != "":
		return "chebien"
	return "khac"

func _kho_items() -> Array:
	var e := []
	for t in G.g.barn.keys():
		if int(G.g.barn[t]) > 0 and (kh_f == "all" or _cat(t) == kh_f):
			e.append(t)
	var s := kh_sort
	e.sort_custom(func(a, b):
		var na := int(G.g.barn[a])
		var nb := int(G.g.barn[b])
		if s == "v":
			return nb * G.price(b) < na * G.price(a)
		if s == "p":
			return float(G.g.get("mult", {}).get(b, 1.0)) < float(G.g.get("mult", {}).get(a, 1.0))
		if s == "a":
			return String(G.item(a).get("name", a)) < String(G.item(b).get("name", b))
		return nb < na)
	return e

func _kho_chips() -> void:
	if kh_chip_on.is_empty() or kh_chip_off.is_empty():
		return
	for c in kh_chips:
		var b: Control = c[0]
		var on: bool = c[1] == kh_f
		var tp: Dictionary = kh_chip_on if on else kh_chip_off
		b.style(Snap.css_of(tp), b.z)
		b.place(b.r)
		var sp := _q(b, "", "span")
		if sp != null and not sp.texts.is_empty():
			var sc: Dictionary = Snap.find(tp, "", "span")
			sp.texts[0].col = Css.color(sc.css.get("color", "rgb(90,62,20)") if not sc.is_empty() else "rgb(90,62,20)")
			sp.texts[0].w = int(sc.css.get("font-weight", "600")) if not sc.is_empty() else 600
			sp.redraw()
		# the icon in front: white on the green chip, its own colour otherwise
		for k in b.kids():
			if not k.has_meta("snap") and not k.pics.is_empty():
				k.modulate = Color(10, 10, 10, 1) if on else Color.WHITE
	kh_sig = ""
	_kho_sync()

func _kho_sync() -> void:
	if not kho_on:
		return
	if kho_tab == 1:
		_kho_vl_sync()
		return
	if kho_tab != 0:
		return
	if kh_sel != "" and int(G.g.barn.get(kh_sel, 0)) <= 0:
		kh_sel = ""
	var selm := kh_sel != ""
	if kho_roots[3].visible != selm or kho_roots[0].visible == selm:
		_kho_show()
	var ids: Dictionary = kho_ids[3] if selm else kho_ids[0]
	var grid: Control = ids.get(".khgrid")
	var grid0 := kh_grid0s if selm else kh_grid0
	var e := _kho_items()
	var tot_n = G.kho_n()
	var worth := 0
	for t in G.g.barn.keys():
		worth += int(G.g.barn[t]) * G.price(t)
	var sell_n := 0
	var sell_v := 0
	for t in e:
		var c := int(G.g.barn[t])
		var keep := mini(G.LY, c) if G.D.crops.has(t) else 0
		sell_v += G.sell_value(t, c - keep)
		sell_n += c - keep
	var sig := kh_f + kh_sort + kh_sel + str(kh_q) + "|" + str(G.price(kh_sel) if selm else 0) + "|" + str(tot_n) + "/" + str(G.kho_cap()) + "★" + str(G.kho_star()) + "|" + str(worth) + "|" + str(sell_v) + "|" + str(G.day()) + "|" + str(kh_conf > 0.0)
	for t in e:
		sig += t + str(G.g.barn[t]) + ","
	if sig == kh_sig:
		return
	kh_sig = sig
	# đầu kho: thanh đầy, "Đáng giá N", sức chứa n/cap ★1
	if khp != null:
		khp.sync_panel(ids, tot_n, G.kho_cap())
	var wb = ids.get(".khworth2")
	if wb != null:
		_txt(_q(wb, "", "b"), G.fmt_n(worth))
	# lưới món
	for g0 in [kho_ids[0].get(".khgrid"), kho_ids[3].get(".khgrid")]:
		for k in g0.kids():
			k.queue_free()
	var o := grid0.position
	var col := 4
	var x0 := kh_li0.x
	var y0 := kh_li0.y
	var dx := float(kh_tpl.r[2]) + 5.0
	var dy := float(kh_tpl.r[3]) + 6.0
	var idx := 0
	for t in e:
		var hx: float = G.hot_x(t)
		var tp: Dictionary = kh_tpl_hot if hx > 1.0 else kh_tpl
		if t == kh_sel and not kh_tpl_sel.is_empty():
			tp = kh_tpl_sel.duplicate(true)
			if hx <= 1.0:
				tp.erase("::before")
		var to := Vector2(x0 + (idx % col) * dx, y0 + int(idx / col) * dy)
		var nd := Snap.moved(tp, to - Vector2(float(tp.r[0]), float(tp.r[1])))
		_kh_fill(nd, t, hx)
		var cb := _build(nd, {}, o)
		grid.add(cb)
		var btn := _q(cb, "khb")
		var tt: String = t
		if btn != null:
			_click(btn, func(): kh_sel = "" if kh_sel == tt else tt; kh_q = 1; kh_sig = ""; _kho_sync(), "scale94")
		idx += 1
	var rows := int(ceil(idx / float(col)))
	grid.place(Rect2(grid.r.position, Vector2(grid.r.size.x, maxf(grid0.size.y, rows * dy + 8.0))))
	if selm:
		_det_sync()
	# Bán hết +N (chạm 2 lần), giữ 4 hạt mỗi thứ
	var sa = ids.get("#sellAll")
	if sa != null:
		if kh_conf > 0.0:
			_txt(sa, "Chạm lần nữa để bán hết")
		else:
			_txt(sa, ("Bán hết" + ("" if kh_f == "all" else " mục " + _cat_name(kh_f).to_lower()) + " +" + G.fmt_n(sell_v)) if sell_n > 0 else ("Mục này trống" if tot_n > 0 else "Kho đang trống"))
		sa.modulate.a = 1.0 if sell_n > 0 else 0.55
		var xi := _q(sa, "xui")
		if xi != null:
			xi.visible = sell_n > 0 and kh_conf <= 0.0
			var tw := Box.text_w(sa.texts[0].s, sa.texts[0].size, sa.texts[0].w)
			var total = tw + (6.0 + xi.r.size.x if xi.visible else 0.0)
			var tx = (sa.r.size.x - total) * 0.5
			sa.texts[0].rect = Rect2(tx, sa.texts[0].rect.position.y, tw + 2.0, sa.texts[0].rect.size.y)
			sa.texts[0].al = "left"
			_move(xi, Vector2(tx + tw + 6.0, xi.r.position.y))
			sa.redraw()

static func _xn(x: float) -> String:
	# 2 -> "2", 1.5 -> "1,5" (như web: String(số))
	if absf(x - round(x)) < 0.001:
		return str(int(round(x)))
	return str(snappedf(x, 0.01)).replace(".", ",")

func _cat_name(c: String) -> String:
	for q in KH_CAT:
		if q[0] == c:
			return q[1]
	return ""

func _kh_fill(nd: Dictionary, t: String, hx: float) -> void:
	var ic := Snap.find(nd, "khic")
	var sv: String = FileAccess.get_file_as_string("res://ui/svg/kh/" + t + ".svg")
	for k in ic.get("kids", []):
		if k.tag == "svg" and sv != "":
			k.svg = sv
	var cnt := Snap.find(nd, "cnt")
	if not cnt.is_empty():
		cnt.text = G.fmt_k(int(G.g.barn[t]))
		cnt.erase("tr")
	var nm := Snap.find(nd, "khnm")
	if not nm.is_empty():
		nm.text = G.item(t).get("name", t)
		nm.erase("tr")
		nm.css["white-space"] = "nowrap"
		# span co theo chữ (flow-root, padding 0 2px), nằm giữa thẻ: đổi tên thì đo lại bề ngang, không cắt chữ
		var nfs := Css.px(nm.css.get("font-size", "14px")) * float(nm.get("z", 1.0))
		var nw: float = minf(float(nd.r[2]), Box.text_w(nm.text, nfs, int(nm.css.get("font-weight", "500"))) + 4.0)
		nm.r = [float(nd.r[0]) + (float(nd.r[2]) - nw) * 0.5, nm.r[1], nw, nm.r[3]]
	if nd.has("::before") and hx > 1.0:
		nd["::before"].content = "\"" + ("×" + _xn(hx)) + "\""
	var pr := Snap.find(nd, "khpr")
	if not pr.is_empty():
		var r: float = G.rel(t)
		var ft := "up" if r > 1.08 else ("down" if r < 0.92 else "")
		pr.text = G.fmt_n(G.price(t))
		pr.erase("tr")
		var fs := Css.px(pr.css.get("font-size", "14px")) * float(pr.get("z", 1.0))
		var fw := int(pr.css.get("font-weight", "500"))
		var tw: float = Box.text_w(pr.text, fs, fw)
		var kids: Array = pr.get("kids", [])
		var img := {}
		var ka := {}
		for k in kids:
			if k.tag == "img":
				img = k
			elif String(k.cls).split(" ").has("ka"):
				ka = k
		# [giá][xu] giữa thẻ, mũi tên ▲▼ ngay sau (absolute left:100%)
		var iw: float = float(img.r[2]) if not img.is_empty() else 0.0
		var gap := 3.0
		var w := tw + gap + iw
		var cx: float = float(nd.r[0]) + float(nd.r[2]) * 0.5
		var x := cx - w * 0.5
		pr.r = [x, pr.r[1], w, pr.r[3]]
		pr.css["text-align"] = "left"
		if not img.is_empty():
			img.r = [x + tw + gap, img.r[1], img.r[2], img.r[3]]
		var keep := []
		for k in kids:
			if k.tag == "img":
				keep.append(k)
		if ft != "":
			var tpl: Dictionary = ka if not ka.is_empty() else {}
			if not tpl.is_empty():
				tpl.text = "▲" if ft == "up" else "▼"
				tpl.erase("tr")
				tpl.r = [x + w + 3.0, tpl.r[1], tpl.r[2], tpl.r[3]]
				if ft == "up":
					tpl.css["color"] = "rgb(47, 158, 68)"
				keep.append(tpl)
		pr.kids = keep
		# text box = only the price part
		pr["tr"] = [x, float(pr.r[1]), tw + 1.0, float(pr.r[3])]

func _kho_sell_all() -> void:
	# web: chạm 1 -> "Chạm lần nữa để bán hết" (nút giữ màu xanh, 3 s), chạm 2 -> bán, chừa 4 hạt mỗi thứ
	var n := 0
	for t in _kho_items():
		n += int(G.g.barn[t]) - (mini(G.LY, int(G.g.barn[t])) if G.D.crops.has(t) else 0)
	if n <= 0:
		return
	if kh_conf <= 0.0:
		kh_conf = 3.0
		kh_sig = ""
		_kho_sync()
		return
	kh_conf = 0.0
	G.sell_all(_kho_items())
	kh_sig = ""
	_kho_sync()

func _kho_conf_off() -> void:
	var sa = kho_ids[0].get("#sellAll")
	if sa != null:
		sa.style(Snap.css_of(sa.get_meta("snap")), sa.z)
		sa.place(sa.r)

# ------------------------------------------------------------------ #khDet (món đang chọn)
var kd := {}                 # phần của khDet

func _build_det() -> void:
	var ids: Dictionary = kho_ids[3]
	kh_det = ids.get("#khDet")
	if kh_det == null:
		return
	_stop(kh_det)
	kd.dic = _q(kh_det, "khdic")
	var tx := _q(kh_det, "khdtx")
	kd.nm = _q(tx, "", "b")
	kd.co = _q(tx, "khco")
	kd.hot = _q(tx, "khhot")
	var pr := _q(kh_det, "kdpr")
	kd.pr = _q(pr, "", "b")
	kd.xui = _q(pr, "xui")
	kd.kdu = _q(pr, "kdu")
	kd.ka = _q(pr, "ka")
	var st := _q(kh_det, "kdst")
	var bs := []
	for k in st.kids():
		bs.append(k)
	kd.minus = bs[0]
	kd.out = bs[1]
	kd.plus = bs[2]
	kd.all = bs[3]
	# lúc chụp: "−" đang tắt (1 cái), "+" đang bật -> hai dáng nút
	var sm: Dictionary = kd.minus.get_meta("snap")
	var sp: Dictionary = kd.plus.get_meta("snap")
	kd.off = [Snap.css_of(sm), Css.color(sm.css.get("color", "rgb(0,0,0)"))]
	kd.on = [Snap.css_of(sp), Css.color(sp.css.get("color", "rgb(0,0,0)"))]
	kd.sell = _q(kh_det, "kdsell")
	kd.sxui = _q(kd.sell, "xui")
	kd.hint = _q(kh_det, "kdhint")
	_click(kd.minus, func(): _det_q(kh_q - 1), "scale94")
	_click(kd.plus, func(): _det_q(kh_q + 1), "scale94")
	_click(kd.all, func(): _det_q(99999999), "scale94")
	_click(kd.sell, _det_sell, "scale94")

func _det_sell() -> void:
	var t := kh_sel
	if t == "":
		return
	G.sell(t, kh_q)
	if int(G.g.barn.get(t, 0)) <= 0:
		kh_sel = ""
	kh_sig = ""
	_kho_sync()

func _det_btn(b: Control, off: bool) -> void:
	var st: Array = kd.off if off else kd.on
	b.style(st[0], b.z)
	b.place(b.r)
	if not b.texts.is_empty():
		b.texts[0].col = st[1]
		b.redraw()

func _det_q(n: int) -> void:
	if kh_sel == "":
		return
	kh_q = clampi(n, 1, maxi(1, int(G.g.barn.get(kh_sel, 0))))
	kh_sig = ""
	_kho_sync()

func _inline(b: Control, x: float) -> float:
	# đặt hộp chữ b ở x (css, trong cha), rộng theo chữ; trả về mép phải
	if b == null or b.texts.is_empty():
		return x
	var t: Dictionary = b.texts[0]
	var w: float = Box.text_w(t.s, t.size, t.w) + 1.0
	b.place(Rect2(Vector2(x, b.r.position.y), Vector2(w, b.r.size.y)))
	t.rect = Rect2(0, t.rect.position.y, w, t.rect.size.y)
	t.al = "left"
	b.redraw()
	return x + w

func _det_sync() -> void:
	if kh_det == null or kh_sel == "":
		return
	var s := kh_sel
	var h := int(G.g.barn.get(s, 0))
	kh_q = clampi(kh_q, 1, maxi(1, h))
	var M := kh_q
	var p: int = G.price(s)
	var d: float = G.rel(s)
	var hx: float = G.hot_x(s)
	# hình món
	var sv: String = FileAccess.get_file_as_string("res://ui/svg/kh/" + s + ".svg")
	if sv != "" and kd.dic != null and kd.dic.kids().size() > 0:
		_set_svg(kd.dic.kids()[0], sv)
	# Lúa · có 6   🔥 Được giá ×2 hôm nay
	_txt(kd.nm, String(G.item(s).get("name", s)))
	var x := _inline(kd.nm, kd.nm.r.position.x)
	_txt(kd.co, "· có " + G.fmt_n(h))
	x = _inline(kd.co, x + 4.0)
	kd.hot.visible = hx > 1.0
	if hx > 1.0:
		_txt(kd.hot, "🔥 Được giá ×" + _xn(hx) + " hôm nay")
		_inline(kd.hot, x + 7.0)
	# 8 [xu] /cái ▼
	_txt(kd.pr, G.fmt_n(p))
	x = _inline(kd.pr, kd.pr.r.position.x)
	if kd.xui != null:
		_move(kd.xui, Vector2(x + 5.0, kd.xui.r.position.y))
		x = kd.xui.r.position.x + kd.xui.r.size.x
	x = _inline(kd.kdu, x + 3.0)
	if kd.ka != null:
		kd.ka.visible = d > 1.08 or d < 0.92
		if kd.ka.visible:
			_txt(kd.ka, "▲" if d > 1.08 else "▼")
			kd.ka.texts[0].col = Color8(47, 158, 68) if d > 1.08 else Color8(214, 69, 65)
			_inline(kd.ka, x + 3.0)
	# − 1 + Hết
	_txt(kd.out, G.fmt_n(M))
	_det_btn(kd.minus, M <= 1)
	_det_btn(kd.plus, M >= h)
	# Bán M · +X [xu]
	_txt(kd.sell, "Bán " + G.fmt_n(M) + " · +" + G.fmt_n(G.sell_value(s, M)))
	if kd.sxui != null:
		var t0: Dictionary = kd.sell.texts[0]
		var tw: float = Box.text_w(t0.s, t0.size, t0.w)
		var total: float = tw + 6.0 + kd.sxui.r.size.x
		var tx0: float = (kd.sell.r.size.x - total) * 0.5
		t0.rect = Rect2(tx0, t0.rect.position.y, tw + 2.0, t0.rect.size.y)
		t0.al = "left"
		_move(kd.sxui, Vector2(tx0 + tw + 6.0, kd.sxui.r.position.y))
		kd.sell.redraw()
	# Nên giữ lại N để gieo
	var xk: int = G.LY if G.D.crops.has(s) else 0
	var E := h - M
	var R := ""
	if G.w_all != null and G.w_all.WKU != null:   # NTWEB eG: tính cả số cần cho đơn (NF)
		R = G.w_all.WKU.det_hint(s, M)
	elif xk > 0 and E < xk:
		R = "Bán hết, không chừa lại để gieo" if E <= 0 else "Nên giữ lại " + G.fmt_n(mini(xk, h)) + " để gieo"
	kd.hint.visible = R != ""
	if R != "":
		_txt(kd.hint, R)

# Vật liệu
var kh_vl := ""

func _kho_vl_pick(b: Control) -> void:
	var n: Dictionary = b.get_meta("snap")
	var nm := Snap.find(n, "u2vn")
	kh_vl = nm.get("text", "")
	kh_sig = ""
	_kho_vl_sync()

func _mat_id(name: String) -> String:
	if G.D.mat is Dictionary:
		for k in G.D.mat.keys():
			var m = G.D.mat[k]
			if m is Dictionary and m.get("n", "") == name:
				return k
	return ""

func _kho_vl_sync() -> void:
	var ids: Dictionary = kho_ids[1]
	var mats: Dictionary = G.g.get("mats", {})
	for b in _qall(kho_roots[1], "u2vt", []):
		var n: Dictionary = b.get_meta("snap")
		var nm: String = Snap.find(n, "u2vn").get("text", "")
		var id := _mat_id(nm)
		var c := int(mats.get(id, 0))
		var vc := _q(b, "u2vc")
		_txt(vc, str(c))
		var vi := _q(b, "u2vi")
		if vi != null:
			vi.modulate.a = 1.0 if c > 0 else 0.35
	var det = ids.get(".u2vdt")
	if det != null and kh_vl != "":
		var b0 := _q(det, "", "b")
		_txt(b0, kh_vl)
		var sm := _q(det, "", "small")
		_txt(sm, "Đang có " + str(int(mats.get(_mat_id(kh_vl), 0))))

# ------------------------------------------------------------------ chạm ô ruộng (c2 bản web)
# ------------------------------------------------------------------ đơn hàng (#pn-orders, ws / jp bản web)
const OD_HD := ["#b5653a", "#5f8a3c", "#c4932c", "#4f7896", "#7a5a8c", "#3f8a7a", "#a34d70"]
const OD_IT := 33.75          # khoảng cách 2 dòng món trong thẻ
const OD_COL := 160.0         # cột 2 lệch cột 1
const OD_GAP := 6.0           # gap 8px x .75
const OD_UL := 416.22         # khung danh sách đơn cao nhất (2 hàng thẻ đầy)
var od_on := false
var od_tpl := {}              # mẫu thẻ, dòng món, nút (từ số đo bản web)
var od_shell := {}            # "has"/"no": khung bảng (chưa có thẻ)
var od_box: Control = null
var od_ids := {}
var od_ul: Control = null
var od_ul0 := Vector2.ZERO
var od_shsig := ""
var od_cards := {}            # i -> {b, sig}
var od_ud := {"i": -1, "t": 0.0}
var od_scroll := 0.0
var od_hmax := 0.0
var od_drag = null            # {y0, s0, moved}
var od_lk: Control = null
var od_lk_tpl := {}
var od_xu_span := {}

func _od_lis(nm: String) -> Array:
	return Snap.find(Snap.load_snap(nm)["#pov"][0], "orders").get("kids", [])

func _build_ord() -> void:
	var L0 := _od_lis("ord")
	var L1 := _od_lis("ord_ok")
	od_tpl.no = L0[0]
	od_tpl.ok = L1[0]
	for li in _od_lis("ord_wait"):
		if String(li.cls).split(" ").has("odw"):
			od_tpl.wait = li
	var is0: Array = Snap.find(L0[0], "odis").kids
	od_tpl.it_no = is0[0]
	od_tpl.it_ph = is0[1]
	od_tpl.it_ok = Snap.find(L1[0], "odis").kids[0]
	od_tpl.hot = Snap.find(L0[1], "hot")["::after"]
	od_tpl.sen = Snap.find(_od_lis("ord_sen")[0], "odsen")
	od_tpl.sw_on = Snap.find(_od_lis("ord_sw")[0], "odsw")
	for k in [["no", "ord"], ["has", "ord_ok"]]:
		var n: Dictionary = Snap.load_snap(k[1])["#pov"][0].duplicate(true)
		Snap.find(n, "orders").kids = []
		od_shell[k[0]] = n
	# ô "xu" của popup thiếu xu (Khai hoang ... còn thiếu xu:), cùng khổ ô món
	var xl: Dictionary = Snap.load_snap("pc_lack")[".nglkov"][0].duplicate(true)
	var xb := Snap.find(xl, "nglk")
	var xm := RegEx.create_from_string("matrix\\(([0-9.]+)").search(String(xb.css.get("transform", "")))
	if xm != null:
		_od_unscale(xb, Vector2(float(xb.r[0]) + float(xb.r[2]) * 0.5, float(xb.r[1]) + float(xb.r[3]) * 0.5), float(xm.get_string(1)))
	od_xu_span = Snap.find(xb, "nglc")
	for nm in ["ord_lack", "ord_lack2"]:
		# số đo chụp lúc popup còn đang hiện dần (mờ .72, phóng 1,04): đưa về lúc hiện xong
		var n: Dictionary = Snap.load_snap(nm)[".nglkov"][0].duplicate(true)
		n.css["opacity"] = "1"
		var bx := Snap.find(n, "nglk")
		var m := RegEx.create_from_string("matrix\\(([0-9.]+)").search(String(bx.css.get("transform", "")))
		if m != null:
			var k := float(m.get_string(1))
			var c := Vector2(float(bx.r[0]) + float(bx.r[2]) * 0.5, float(bx.r[1]) + float(bx.r[3]) * 0.5)
			_od_unscale(bx, c, k)
			bx.css["transform"] = "none"
		od_lk_tpl[nm] = n

static func _od_unscale(n: Dictionary, c: Vector2, k: float) -> void:
	for key in ["r", "tr"]:
		if n.has(key):
			var r: Array = n[key]
			n[key] = [c.x + (float(r[0]) - c.x) / k, c.y + (float(r[1]) - c.y) / k, float(r[2]) / k, float(r[3]) / k]
	for q in n.get("kids", []):
		_od_unscale(q, c, k)

static func _fsz(n: Dictionary) -> float:
	return Css.px(n.css.get("font-size", "15px")) * float(n.get("z", 1.0))

static func _tw(n: Dictionary, s: String) -> float:
	return Box.text_w(s, _fsz(n), int(n.css.get("font-weight", "400")))

static func _set_t(n: Dictionary, s: String, x: float, w := -1.0) -> void:
	# chữ mới, hộp chữ bắt đầu ở x (css px trang)
	n.text = s
	var tr: Array = n.get("tr", n.r)
	n.tr = [x, float(tr[1]), _tw(n, s) + 0.5 if w < 0.0 else w, float(tr[3])]

static func _nshift(n: Dictionary, dx: float) -> void:
	n.r = [float(n.r[0]) + dx, n.r[1], n.r[2], n.r[3]]
	if n.has("tr"):
		n.tr = [float(n.tr[0]) + dx, n.tr[1], n.tr[2], n.tr[3]]

const OD_CK := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M6 12.6l4 4L18.2 8\" fill=\"none\" stroke=\"#fff\" stroke-width=\"3.4\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>"

static func _od_tick(n: Dictionary) -> void:
	# "✓" không có trong Nunito: vẽ dấu tích bằng nét svg trong ô tròn xanh
	if n.get("text", "") != "✓":
		return
	n.erase("text")
	n.erase("tr")
	var r: Array = n.r
	var k := 0.78
	var w: float = float(r[2]) * k
	n.kids = [{"tag": "svg", "id": "", "cls": "", "z": n.get("z", 1.0), "css": {}, "kids": [], "svg": OD_CK,
		"r": [float(r[0]) + (float(r[2]) - w) * 0.5, float(r[1]) + (float(r[3]) - w) * 0.5, w, w]}]

static func _od_dash(n: Dictionary, off := 1.5, op := 0.3, rad := 10.0) -> void:
	# css outline 1.5px dashed rgba(150,112,48,op), outline-offset -off (x .75): ô trống .odph, thẻ khách đang tới .odw
	var z := float(n.get("z", 1.0))
	var W: float = float(n.r[2])
	var H: float = float(n.r[3])
	var sw := 1.5 * z
	var c := (off - 0.75) * z
	var rr := maxf(0.0, rad * z - c)
	n.svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 %.2f %.2f\"><rect x=\"%.2f\" y=\"%.2f\" width=\"%.2f\" height=\"%.2f\" rx=\"%.2f\" fill=\"none\" stroke=\"rgb(150,112,48)\" stroke-opacity=\"%.2f\" stroke-width=\"%.2f\" stroke-dasharray=\"%.2f %.2f\"/></svg>" % [W, H, c, c, W - 2.0 * c, H - 2.0 * c, rr, op, sw, sw * 3.0, sw * 2.0]

static func _od_arrow(n: Dictionary) -> void:
	# .odget::after: mũi tên 15px (x .75) ngay sau chữ "Đi lấy", cách 5px
	var a: Dictionary = n.get("::after", {})
	var bgi: String = a.get("bgi", "")
	var i := bgi.find("data:image/svg+xml,")
	if i < 0:
		return
	var sv := bgi.substr(i + 19)
	sv = sv.substr(0, sv.rfind("\"")).uri_decode()
	n.erase("::after")
	var z := float(n.get("z", 1.0))
	var w := 15.0 * z
	var tw := _tw(n, n.text)
	var g := 5.0 * z
	var x: float = float(n.r[0]) + (float(n.r[2]) - (tw + g + w)) * 0.5
	n.tr = [x, n.tr[1], tw + 0.5, n.tr[3]]
	n.css["text-align"] = "left"
	var kids: Array = n.get("kids", [])
	kids.append({"tag": "svg", "id": "", "cls": "", "z": z, "css": {}, "kids": [], "svg": sv,
		"r": [x + tw + g, float(n.r[1]) + (float(n.r[3]) - w) * 0.5, w, w]})
	n.kids = kids

var _fits := {}
func _fit_svg(id: String) -> String:
	# như web (PA): viewBox ôm sát hình (getBBox), cạnh = max(rộng, cao) x 1,08, giữ tâm
	if _fits.has(id):
		return _fits[id]
	var sv: String = FileAccess.get_file_as_string("res://ui/svg/kh/" + id + ".svg")
	var out := sv
	var m := RegEx.create_from_string("viewBox=\"([^\"]*)\"").search(sv)
	if m != null:
		var v := m.get_string(1).split(" ", false)
		var img := Image.new()
		var q := 8.0
		if v.size() == 4 and img.load_svg_from_string(sv, q * 64.0 / float(v[2])) == OK:
			var u := img.get_used_rect()
			if u.size.x > 0:
				var k: float = float(v[2]) / img.get_width()
				var bw := u.size.x * k
				var bh := u.size.y * k
				var cx: float = float(v[0]) + (u.position.x + u.size.x * 0.5) * k
				var cy: float = float(v[1]) + (u.position.y + u.size.y * 0.5) * k
				var sz := maxf(bw, bh) * 1.08
				out = sv.replace(m.get_string(0), "viewBox=\"%.1f %.1f %.1f %.1f\" data-fit=\"1\"" % [cx - sz * 0.5, cy - sz * 0.5, sz, sz])
	_fits[id] = out
	return out

static func rf(t: float) -> String:   # RF(ao): 4p 59s / 12p / 40s
	var s := int(maxf(1.0, ceil(t)))
	var h := s / 3600
	var m := (s % 3600) / 60
	var e := s % 60
	if h:
		return str(h) + "g" + ((" " + str(m) + "p") if m else "")
	if m >= 10:
		return str(m) + "p"
	if m:
		return str(m) + "p" + ((" " + str(e) + "s") if e else "")
	return str(e) + "s"

func _od_colors() -> Dictionary:
	# K9: màu chữ cái theo tên khách, trùng màu thì lấy màu kế
	var used := {}
	var out := {}
	for f in G.g.orders.size():
		var c: Dictionary = G.g.orders[f]
		if G.ord_wait(c):
			continue
		var a := 0
		for ch in String(c.who):
			a = (a * 31 + ch.unicode_at(0)) & 0xffffffff
			if a >= 0x80000000:
				a -= 0x100000000
		var h := absi(a) % OD_HD.size()
		var s: String = OD_HD[h]
		var p := 0
		while used.has(s) and p < OD_HD.size():
			p += 1
			h = (h + 1) % OD_HD.size()
			s = OD_HD[h]
		used[s] = 1
		out[f] = s
	return out

func ord_open() -> void:
	if nvp != null:
		nvp.close()
	pc_close()
	gv_close()
	rm_close()
	lock_close()
	kho_close()
	od_on = true
	od_shsig = ""
	od_scroll = 0.0
	_ord_sync()

func ord_close() -> void:
	od_on = false
	_lack_close()
	if od_box != null:
		anchors.erase(_anchor_of(od_box))
		od_box.queue_free()
		od_box = null
	od_cards = {}

func _anchor_of(b: Control):
	for a in anchors:
		if a[0] == b:
			return a
	return null

func _od_order() -> Array:
	# thẻ đủ hàng trước (order 1), đơn thường (2), khách đang tới cuối (3)
	var plan: Array = G.ord_plan()
	var L := []
	for f in G.g.orders.size():
		var k := 3 if plan[f] == null else (1 if plan[f].ok else 2)
		L.append([k, f])
	L.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return [L, plan]

func _ord_sync() -> void:
	if not od_on:
		return
	var now: float = G._now_ms()
	if od_ud.i >= 0 and now >= od_ud.t:
		od_ud.i = -1
	var lp: Array = _od_order()
	var L: Array = lp[0]
	var plan: Array = lp[1]
	var okn := 0
	var m := 0
	for f in plan.size():
		if plan[f] != null:
			m += 1
			if plan[f].ok:
				okn += 1
	# hàng thẻ: cao 200,6, hàng toàn khách đang tới thì 108,6
	var rows := []
	for q in L.size():
		var rw := q / 2
		if rows.size() <= rw:
			rows.append(true)
		if L[q][0] != 3:
			rows[rw] = false
	var hw: float = float(od_tpl.wait.r[3])
	var hn: float = float(od_tpl.no.r[3])
	var H := 0.0
	for rw in rows.size():
		H += (hw if rows[rw] else hn) + (OD_GAP if rw > 0 else 0.0)
	var pad: float = float(od_tpl.no.r[1]) - float(Snap.find(od_shell.no, "orders").r[1])
	var ch := H + 2.0 * pad
	var dy := maxf(0.0, OD_UL - ch)
	var ssig := ("has" if okn > 0 else "no") + "|" + str(okn) + "/" + str(m) + "|" + str(int(G.g.delivered)) + "|" + str(snappedf(dy, 0.1))
	if ssig != od_shsig:
		od_shsig = ssig
		_od_shell(okn, m, dy)
	od_hmax = maxf(0.0, ch - OD_UL)
	od_scroll = clampf(od_scroll, 0.0, od_hmax)
	# thẻ
	var cols := _od_colors()
	var ul0 := od_ul0
	var y := float(od_tpl.no.r[1]) + dy
	var keep := {}
	for q in L.size():
		var rw := q / 2
		if q % 2 == 0 and rw > 0:
			y += (hw if rows[rw - 1] else hn) + OD_GAP
		var f: int = L[q][1]
		var o: Dictionary = G.g.orders[f]
		var at := Vector2(float(od_tpl.no.r[0]) + (q % 2) * OD_COL, y - od_scroll)
		var full: bool = not rows[rw]
		var sig := str(at) + JSON.stringify(o) + "|" + JSON.stringify(plan[f]) + "|" + str(cols.get(f, "")) + "|" + str(int(G.g.ngoc)) + "|" + str(od_ud.i == f) + "|" + str(full)
		for it in o.items:
			sig += str(G.hot_x(it[0]) > 1.0)
		if plan[f] == null:
			var s: float = (float(o.w) - now) / 1000.0
			sig += "|" + rf(s) + "|" + str(G.call_cost(o)) + "|" + str(int(clampf(100.0 - s * 1000.0 / G.Y8 * 100.0, 0.0, 100.0)))
		keep[f] = 1
		var c = od_cards.get(f)
		if c != null and c.sig == sig:
			continue
		if c != null:
			c.b.queue_free()
		var nd := _od_card(o, plan[f], f, cols.get(f, OD_HD[0]), full, now)
		var b := _build(Snap.moved(nd, at - Vector2(float(nd.r[0]), float(nd.r[1]))), {}, ul0)
		od_ul.add(b)
		_od_hook(b, f)
		od_cards[f] = {"b": b, "sig": sig}
	for f in od_cards.keys():
		if not keep.has(f):
			od_cards[f].b.queue_free()
			od_cards.erase(f)

func _od_shell(okn: int, m: int, dy: float) -> void:
	if od_box != null:
		anchors.erase(_anchor_of(od_box))
		od_box.queue_free()
	od_cards = {}
	var n: Dictionary = od_shell["has" if okn > 0 else "no"].duplicate(true)
	# đầu bảng: "Giao được N/M đơn", "✓ N đã giao"
	var tn := Snap.find(n, "odtn")
	var tl: Array = Snap.find(n, "odtl").kids
	_set_t(tn, str(okn) + "/" + str(m), float(tn.r[0]))
	tn.css["color"] = "rgb(63, 154, 58)" if okn > 0 else "rgb(163, 132, 58)"
	var tw := _tw(tn, tn.text)
	tn.r = [tn.r[0], tn.r[1], tw, tn.r[3]]
	var em: Dictionary = tl[2]
	_nshift(em, float(tn.r[0]) + tw + OD_GAP * 0.75 - float(em.r[0]))
	var td := Snap.find(n, "odtd")
	var tk: Array = td.kids
	var bd: Dictionary = tk[1]
	var right: float = float(td.r[0]) + float(td.r[2])
	var g := 4.5
	var bw := _tw(bd, str(int(G.g.delivered)))
	var sw := _tw(td, td.text)
	var x0 := right - (float(tk[0].r[2]) + g + bw + g + sw)
	_nshift(tk[0], x0 - float(tk[0].r[0]))
	_set_t(bd, str(int(G.g.delivered)), x0 + float(tk[0].r[2]) + g)
	bd.r = [bd.tr[0], bd.r[1], bw, bd.r[3]]
	_set_t(td, td.text, x0 + float(tk[0].r[2]) + g + bw + g)
	td.r = [x0, td.r[1], right - x0, td.r[3]]
	# ít thẻ: khung thấp xuống (đầu bảng, khăn trên, hoa dời xuống; đáy giữ chỗ)
	if dy > 0.0:
		_od_low(Snap.find(n, "pwin"), dy)
	var ul: Dictionary = Snap.find(n, "orders")
	od_ul0 = Vector2(float(ul.r[0]), float(ul.r[1]))
	_od_tick(Snap.find(n, "odtd").kids[0])
	var ids := {}
	od_box = _build(n, ids)
	root.add_child(od_box)
	anchors.append([od_box, 0.5, 1])
	od_ids = ids
	od_ul = ids.get("#orders")
	od_ul._kids.clip_contents = true
	_stop(od_ul)
	_click(ids.get("#pClose"), ord_close, "scale")
	var bk = ids.get(".pbk")
	if bk != null:
		_stop(bk)
		bk.gui_input.connect(func(e): if _is_tap_down(e): ord_close())
	var win = ids.get(".pwin")
	if win != null:
		_stop(win)
	_layout()

static func _od_low(n: Dictionary, dy: float) -> void:
	var y0 := float(n.r[1])
	var y1 := y0 + float(n.r[3])
	if y0 < 300.0 and y1 >= 590.0:
		n.r = [n.r[0], y0 + dy, n.r[2], float(n.r[3]) - dy]
		if n.has("tr"):
			n.tr = [n.tr[0], float(n.tr[1]) + dy, n.tr[2], n.tr[3]]
	elif y1 < 300.0:
		Snap._move(n, Vector2(0, dy))
		return
	for k in n.get("kids", []):
		_od_low(k, dy)

func _od_card(o: Dictionary, pl, f: int, col: String, full: bool, now: float) -> Dictionary:
	if pl == null:
		return _od_wait(o, full, now)
	var ok: bool = pl.ok
	var nd: Dictionary = (od_tpl.ok if ok else od_tpl.no).duplicate(true)
	if o.get("hot", -1) == G.day():
		nd.cls = String(nd.cls) + " u2oh"
	# khách: chữ cái đầu của tên, màu riêng
	var av := Snap.find(nd, "odav")
	var nm: String = String(o.who).split(" ")[-1]
	var cx: float = float(av.r[0]) + float(av.r[2]) * 0.5
	_set_t(av, nm.substr(0, 1), cx - _tw(av, nm.substr(0, 1)) * 0.5)
	av.css["background-color"] = col
	var on: Array = Snap.find(nd, "odn").kids
	for q in 2:
		_set_t(on[q], String(o.who if q == 0 else o.shop), float(on[q].r[0]))
		on[q].r = [on[q].r[0], on[q].r[1], on[q].tr[2], on[q].r[3]]
		on[q].css["white-space"] = "nowrap"
	if od_ud.i == f:
		var hd := Snap.find(nd, "odh")
		for q in hd.kids.size():
			if String(hd.kids[q].cls).split(" ").has("odsw"):
				hd.kids[q] = od_tpl.sw_on.duplicate(true)
	# món
	var odis := Snap.find(nd, "odis")
	var its := []
	for q in 3:
		var t: Dictionary
		if q < o.items.size():
			var id: String = o.items[q][0]
			var need := int(o.items[q][1])
			var have := int(pl.have[q]) if pl.have != null else mini(int(G.g.barn.get(id, 0)), need)
			t = (od_tpl.it_ok if have >= need else od_tpl.it_no).duplicate(true)
			if G.hot_x(id) > 1.0:
				t.cls = String(t.cls) + " hot"
				t["::after"] = od_tpl.hot.duplicate(true)
			for k in t.kids:
				if String(k.cls).split(" ").has("odck"):
					_od_tick(k)
			var ic := Snap.find(t, "odic")
			var sv := _fit_svg(id)
			for k in ic.get("kids", []):
				if k.tag == "svg" and sv != "":
					k.svg = sv
			var oq := Snap.find(t, "odq")
			var b0: Dictionary = oq.kids[0]
			var r1: float = float(oq.r[0]) + float(oq.r[2])
			var bw := _tw(b0, str(have))
			var sw := _tw(oq, "/" + str(need))
			var x := r1 - bw - sw
			_set_t(b0, str(have), x, bw)
			b0.r = [x, b0.r[1], bw, b0.r[3]]
			_set_t(oq, "/" + str(need), x + bw, sw)
			oq.r = [x, oq.r[1], bw + sw, oq.r[3]]
			var sm := Snap.find(t, "", "small")
			_set_t(sm, G.item_name(id), float(sm.r[0]))
			sm.r = [sm.r[0], sm.r[1], maxf(10.0, x - float(sm.r[0]) - 2.0), sm.r[3]]
			sm.tr = [sm.tr[0], sm.tr[1], minf(float(sm.tr[2]), float(sm.r[2])), sm.tr[3]]
			sm.css["white-space"] = "nowrap"
		else:
			t = od_tpl.it_ph.duplicate(true)
			_od_dash(t)
		its.append(Snap.moved(t, Vector2(0, float(odis.kids[0].r[1]) + q * OD_IT - float(t.r[1]))))
	odis.kids = its
	# thưởng: "+xu [xu]  +EXP [★]" giữa thẻ
	var odr := Snap.find(nd, "odr")
	var rb: Dictionary = odr.kids[0]
	var rx: Dictionary = odr.kids[1]
	var g := 5.0 * 0.75
	var s1: String = "+" + G.fmt_n(int(o.reward))
	var s2 := "+" + str(maxi(3, int(round(float(o.reward) / 12.0))))
	var w1 := _tw(rb, s1)
	var w2 := _tw(rx, s2)
	var i1: Dictionary = rb.kids[0]
	var i2: Dictionary = rx.kids[0]
	var W1 := w1 + g + float(i1.r[2])
	var W2 := w2 + g + float(i2.r[2])
	var x1: float = float(odr.r[0]) + (float(odr.r[2]) - (W1 + OD_GAP + W2)) * 0.5
	_set_t(rb, s1, x1, w1)
	rb.r = [x1, rb.r[1], W1, rb.r[3]]
	i1.r = [x1 + w1 + g, i1.r[1], i1.r[2], i1.r[3]]
	var x2 := x1 + W1 + OD_GAP
	_set_t(rx, s2, x2, w2)
	rx.r = [x2, rx.r[1], W2, rx.r[3]]
	i2.r = [x2 + w2 + g, i2.r[1], i2.r[2], i2.r[3]]
	if not ok:
		# Đi lấy + nút bù bằng sen đỏ (mờ khi không đủ sen)
		var acts := Snap.find(nd, "odacts")
		var cost: int = G.lack_cost(pl.miss) if not pl.miss.is_empty() else 0
		var kids := []
		var get_n: Dictionary = {}
		for k in acts.kids:
			if String(k.cls).split(" ").has("odget"):
				get_n = k
		kids.append(get_n)
		if cost > 0:
			var sn: Dictionary = acts.kids[1]
			if int(G.g.ngoc) >= cost:
				sn = od_tpl.sen.duplicate(true)
			var sb: Dictionary = Snap.find(sn, "", "b")
			var im: Dictionary = Snap.find(sn, "xui")
			im.src = "pearl"
			var bw := _tw(sb, str(cost))
			var tot := float(im.r[2]) + 3.0 + bw
			var w := maxf(float(sn.r[2]), tot + 12.0)
			var sx: float = float(acts.r[0]) + float(acts.r[2]) - w
			sn.r = [sx, sn.r[1], w, sn.r[3]]
			var ix := sx + (w - tot) * 0.5
			im.r = [ix, im.r[1], im.r[2], im.r[3]]
			_set_t(sb, str(cost), ix + float(im.r[2]) + 3.0, bw)
			sb.r = [sb.tr[0], sb.r[1], bw, sb.r[3]]
			var gw: float = sx - 4.5 - float(acts.r[0])
			var dw: float = gw - float(get_n.r[2])
			if absf(dw) > 0.01:
				get_n.r = [get_n.r[0], get_n.r[1], gw, get_n.r[3]]
				if get_n.has("tr"):
					get_n.tr = [float(get_n.tr[0]) + dw * 0.5, get_n.tr[1], get_n.tr[2], get_n.tr[3]]
			kids.append(sn)
		else:
			get_n.r = [get_n.r[0], get_n.r[1], acts.r[2], get_n.r[3]]
			if get_n.has("tr"):
				get_n.tr = [float(get_n.tr[0]) + (float(acts.r[2]) - 95.5) * 0.5, get_n.tr[1], get_n.tr[2], get_n.tr[3]]
		_od_arrow(get_n)
		acts.kids = kids
	return nd

func _od_wait(o: Dictionary, full: bool, now: float) -> Dictionary:
	# khách mới đang tới: 🛶, "Khách mới · 4p 59s", thanh chờ, "Gọi · N [sen]"
	var nd: Dictionary = od_tpl.wait.duplicate(true)
	var s: float = (float(o.w) - now) / 1000.0
	var b: Dictionary = Snap.find(nd, "odwm").kids[0]
	var tm: Dictionary = b.kids[0]
	var t1 := _tw(b, "Khách mới · ")
	var t2 := _tw(tm, rf(s))
	var cx: float = float(nd.r[0]) + float(nd.r[2]) * 0.5
	var x := cx - (t1 + t2) * 0.5
	_set_t(b, b.text, x, t1)
	b.r = [x, b.r[1], t1 + t2, b.r[3]]
	_set_t(tm, rf(s), x + t1, t2)
	tm.r = [x + t1, tm.r[1], t2, tm.r[3]]
	var bar: Dictionary = Snap.find(nd, "odbar")
	var fi: Dictionary = bar.kids[0]
	var p := clampf(100.0 - s * 1000.0 / G.Y8 * 100.0, 0.0, 100.0)
	fi.r = [fi.r[0], fi.r[1], float(bar.r[2]) * round(p) / 100.0, fi.r[3]]
	var bt := Snap.find(nd, "odb2")
	var wc := Snap.find(bt, "odwc")
	var im := Snap.find(bt, "xui")
	im.src = "pearl"
	var n := str(G.call_cost(o))
	var a1 := _tw(bt, bt.text)
	var a2 := _tw(wc, n)
	var g := 5.0 * 0.75
	var tot: float = a1 + g + a2 + g + float(im.r[2])
	var bx: float = float(bt.r[0]) + (float(bt.r[2]) - tot) * 0.5
	_set_t(bt, bt.text, bx, a1)
	_set_t(wc, n, bx + a1 + g, a2)
	wc.r = [wc.tr[0], wc.r[1], a2, wc.r[3]]
	im.r = [bx + a1 + g + a2 + g, im.r[1], im.r[2], im.r[3]]
	if full:
		# cùng hàng với thẻ đầy: thẻ kéo cao bằng, ruột ở giữa (justify-content center)
		var d: float = (float(od_tpl.no.r[3]) - float(nd.r[3])) * 0.5
		for k in nd.kids:
			Snap._move(k, Vector2(0, d))
		nd.r = [nd.r[0], nd.r[1], nd.r[2], od_tpl.no.r[3]]
	_od_dash(nd, 5.0, 0.35, 14.0)
	return nd

func _od_hook(b: Control, f: int) -> void:
	_click(_q(b, "odgo"), func(): if not _od_dragged(): _od_deliver(f), "down")
	_click(_q(b, "odget"), func(): if not _od_dragged(): _od_get(f), "down")
	_click(_q(b, "odsen"), func(): if not _od_dragged(): _od_lack_btn(f), "down")
	_click(_q(b, "odsw"), func(): if not _od_dragged(): _od_swap(f), "down")
	_click(_q(b, "odb2"), func(): if not _od_dragged(): G.call_now(f); _ord_sync(), "down")

func _od_dragged() -> bool:
	return od_drag != null and od_drag.moved

func _od_deliver(f: int) -> void:
	var r = G.deliver(f)
	if r is Dictionary and r.has("lack"):
		_lack_open(r.lack, r.why, func(): _od_deliver(f))
	_ord_sync()

func _od_lack_btn(f: int) -> void:
	var pl: Array = G.ord_plan()
	if f >= pl.size() or pl[f] == null or pl[f].ok or pl[f].miss.is_empty():
		return
	_lack_open(pl[f].miss, "Đơn của " + str(G.g.orders[f].who) + " còn thiếu:", func(): _od_deliver(f))

func _od_swap(f: int) -> void:
	# chạm 1: "Đổi?" 3 giây; chạm 2: đổi đơn, khách mới tới sau 5 phút
	var now: float = G._now_ms()
	if od_ud.i == f and now < od_ud.t:
		od_ud.i = -1
		G.swap(f)
	else:
		od_ud = {"i": f, "t": now + 3000.0}
	_ord_sync()

func _od_kind(t: String) -> String:   # d$: món này lấy ở đâu (bản Godot mới có ruộng)
	if G.D.crops.has(t):
		return "crop"
	var a: Dictionary = G.item(t)
	var fr: String = a.get("from", "")
	if fr in ["ga", "cuu", "bo", "heo", "de"]:
		return "pen:" + fr
	if t == "thit_vit" or t == "trung_vit":
		return "vit"
	if fr in ["fish", "bun", "ao", "song"]:
		return "fish"
	if fr == "tree":
		return "tree"
	if fr != "":
		return "work"
	return "cho"

const OD_PEN := {"ga": "Chuồng gà", "cuu": "Chuồng cừu", "bo": "Chuồng bò", "heo": "Chuồng heo", "de": "Chuồng dê"}

func _od_get(f: int) -> void:   # g$
	var pl: Array = G.ord_plan()
	if f >= pl.size() or pl[f] == null or pl[f].ok or pl[f].miss.is_empty():
		return
	var o: Dictionary = G.g.orders[f]
	var e: String = pl[f].miss[0][0]
	var r := int(pl[f].miss[0][1])
	var nm: String = G.item_name(e)
	var c := int(G.g.barn.get(e, 0))
	var need := 0
	for it in o.items:
		if it[0] == e:
			need = int(it[1])
	var s := (" Kho có " + str(c) + " nhưng đang để cho đơn khác.") if c >= need else ""
	var h := "Thiếu " + str(r) + " " + nm.to_lower() + ": "
	var k := _od_kind(e)
	if k == "crop":
		var p: int = c - (F.seeds_queued(e) if F.has_method("seeds_queued") else 0)
		if p <= 0:
			say(h + "hết hạt, mua ở Chợ phiên.")
			ord_close()
			return
		var d := -1
		for v in G.g.plots.size():
			var x: Dictionary = G.g.plots[v]
			if x.u and x.c == null:
				d = v
				break
		if d < 0:
			say(h + "ruộng đang kín, gặt xong rồi gieo " + nm.to_lower() + "." + s)
			ord_close()
			return
		ord_close()
		gv_open(d)
		say(h + "gieo ở ruộng, 1 hạt gặt 2." + s)
		return
	if k.begins_with("pen:"):
		ord_close()
		say(h + "lấy ở " + String(OD_PEN.get(k.substr(4), "chuồng")).to_lower() + "." + s)
		return
	if k == "work":
		ord_close()
		say(h + "làm ở xưởng." + s)
		return
	if k == "fish":
		ord_close()
		say(h + "đi câu cá." + s)
		return
	if k == "vit":
		say(h + "nuôi vịt ở ao." + s)
		return
	if k == "tree":
		say(h + "hái ở cây trái trong vườn." + s)
		return
	ord_close()
	say(h + "mua ở Chợ phiên." + s)

# ---- L1: "Còn thiếu một chút!" bù phần thiếu bằng sen đỏ
func _lack_open(items: Array, why: String, go: Callable, xu := 0, mats := []) -> void:
	_lack_close()
	# L1: sen đỏ = H2(món) + mL(vật liệu: gạch 4, khác 3) + bL(xu) (1 sen mỗi 25 xu, ít nhất 1)
	var r: int = (G.lack_cost(items) if not items.is_empty() else 0) + (maxi(1, int(ceil(xu / 25.0))) if xu > 0 else 0)
	for q in mats:
		r += int(q[1]) * (4 if q[0] == "gach" else 3)
	var have := int(G.g.ngoc)
	var rich := have >= r
	var n: Dictionary = od_lk_tpl["ord_lack" if rich else "ord_lack2"].duplicate(true)
	var bx: Dictionary = Snap.find(n, "nglk")
	var cxb: float = float(bx.r[0]) + float(bx.r[2]) * 0.5
	var p: Dictionary = Snap.find(bx, "", "p")
	_set_t(p, why, cxb - _tw(p, why) * 0.5)
	# món thiếu: [hình][×n][tên], xếp giữa, cách 8
	var cs := Snap.find(bx, "nglcs")
	var c0: Dictionary = cs.kids[0]
	var spans := []
	var W := 0.0
	var L := items.duplicate()
	for q in mats:
		L.append(["__m", q[1], q[0]])
	if xu > 0:
		L.append(["__xu", xu])
	for it in L:
		var sp: Dictionary = (c0 if it[0] != "__xu" else od_xu_span).duplicate(true)
		var sv: String = "" if it[0] == "__xu" else (String(khp.mat_svg.get(it[2], "")) if it[0] == "__m" else FileAccess.get_file_as_string("res://ui/svg/kh/" + String(it[0]) + ".svg"))
		for k in sp.kids:
			if k.tag == "svg" and sv != "":
				k.svg = sv
		var bn: Dictionary = Snap.find(sp, "", "b")
		var sm: Dictionary = Snap.find(sp, "", "small")
		var nm: String = "xu" if it[0] == "__xu" else G.item_name(it[2] if it[0] == "__m" else it[0])
		var w: float = maxf(float(c0.r[2]), _tw(sm, nm) + 8.0)
		var d: float = (w - float(c0.r[2])) * 0.5
		for k in sp.kids:
			_nshift(k, d)
		sp.r = [sp.r[0], sp.r[1], w, sp.r[3]]
		# "×n" đỏ ở góc phải trên ô (b::before "×" + số): một dòng chữ
		var br: float = float(bn.r[0]) + float(bn.r[2])
		var xs: String = "×" + (G.fmt_n(int(it[1])) if it[0] == "__xu" else str(int(it[1])))
		var nw := _tw(bn, xs)
		bn.erase("::before")
		_set_t(bn, xs, br - nw, nw)
		bn.r = [br - nw, bn.r[1], nw, bn.r[3]]
		var scx: float = float(sp.r[0]) + w * 0.5
		_set_t(sm, nm, scx - _tw(sm, nm) * 0.5)
		sm.r = [float(sp.r[0]), sm.r[1], w, sm.r[3]]
		spans.append(sp)
		W += w
	W += 8.0 * maxf(0.0, spans.size() - 1)
	var x := cxb - W * 0.5
	var out := []
	for sp in spans:
		out.append(Snap.moved(sp, Vector2(x - float(sp.r[0]), 0)))
		x += float(sp.r[2]) + 8.0
	cs.kids = out
	# nút: "Bù ngay [sen r]" / "Nạp thêm sen đỏ [sen r]"
	var bt := Snap.find(bx, "ngbuy")
	var cost := Snap.find(bt, "ngcost")
	var cb: Dictionary = Snap.find(cost, "", "b")
	var old_cw: float = float(cb.r[2])
	var nw2 := _tw(cb, str(r))
	var dcw := nw2 - old_cw
	cb.r = [cb.r[0], cb.r[1], nw2, cb.r[3]]
	if cb.has("tr"):
		cb.tr = [cb.tr[0], cb.tr[1], nw2, cb.tr[3]]
	cb.text = str(r)
	cost.r = [cost.r[0], cost.r[1], float(cost.r[2]) + dcw, cost.r[3]]
	var bw: float = float(bt.r[2]) + dcw
	var bx0 := cxb - bw * 0.5
	var sh := bx0 - float(bt.r[0])
	bt.r = [bx0, bt.r[1], bw, bt.r[3]]
	if bt.has("tr"):
		bt.tr = [float(bt.tr[0]) + sh, bt.tr[1], bt.tr[2], bt.tr[3]]
	Snap._move(cost, Vector2(sh, 0))
	var hv := Snap.find(bx, "nghave")
	var hs: String = "Đang có " + G.fmt_n(have) + " sen đỏ"
	_set_t(hv, hs, cxb - _tw(hv, hs) * 0.5)
	var ids := {}
	od_lk = _build(n, ids)
	root.add_child(od_lk)
	anchors.append([od_lk, 0.5, 0.5])
	_stop(od_lk)
	od_lk.gui_input.connect(func(e): if _is_tap_down(e): _lack_close())
	var box = ids.get(".nglk")
	if box != null:
		_stop(box)
	_click(ids.get(".ngx"), _lack_close, "scale")
	_click(ids.get(".ngbuy"), func():
		_lack_close()
		if int(G.g.ngoc) < r:
			say("Còn thiếu " + str(r - int(G.g.ngoc)) + " sen đỏ.")
		else:
			G.g.ngoc = int(G.g.ngoc) - r
			G.nv.spent(r)
			for q in items:
				G.g.barn[q[0]] = int(G.g.barn.get(q[0], 0)) + int(q[1])
			for q in mats:
				G.mat_add(q[0], int(q[1]))   # S0
			G.g.coins = int(G.g.coins) + xu
			G.mark()
			go.call()
		_ord_sync(), "down")
	_layout()

func _lack_close() -> void:
	if od_lk != null:
		anchors.erase(_anchor_of(od_lk))
		od_lk.queue_free()
		od_lk = null

func _od_input(e: InputEvent) -> void:
	# kéo dọc danh sách đơn khi nhiều hơn 2 hàng thẻ
	if not od_on or od_ul == null or od_hmax <= 0.0:
		return
	var pos := Vector2.ZERO
	if e is InputEventScreenTouch or e is InputEventMouseButton:
		if e is InputEventMouseButton and e.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = e.position / Css.K
		if e.pressed:
			var gr := Rect2(od_ul.get_global_rect().position / Css.K, od_ul.r.size)
			od_drag = {"y0": pos.y, "s0": od_scroll, "moved": false} if gr.has_point(pos) else null
		elif od_drag != null:
			var dd = od_drag
			get_tree().create_timer(0.05).timeout.connect(func(): if od_drag == dd: od_drag = null)
	elif (e is InputEventScreenDrag or e is InputEventMouseMotion) and od_drag != null:
		pos = e.position / Css.K
		var d: float = pos.y - od_drag.y0
		if absf(d) > 6.0:
			od_drag.moved = true
		if od_drag.moved:
			od_scroll = clampf(od_drag.s0 - d, 0.0, od_hmax)
			_ord_sync()


# ------------------------------------------------------------------ khai hoang: bảng chạm biển (Vm "parcel" + Qm + xC bản web)
var pc_id := ""
var pc_w := Vector2.ZERO        # chỗ chạm (làng)
var pc_b: Control = null
var pc_sig := ""
var pc_off := Vector2.ZERO
var pc_tpl := {}

func _build_pc() -> void:
	for k in ["lv", "buy", "far"]:
		var d: Dictionary = Snap.load_snap("pc_" + k)
		pc_tpl[k] = d[d.keys()[0]][0]

func pc_open(id: String, w: Vector2) -> void:
	close_all()
	pc_id = id
	pc_w = w
	pc_sig = ""
	_pc_sync()

func pc_close() -> void:
	pc_id = ""
	if pc_b != null:
		pc_b.queue_free()
		pc_b = null

static func _grow_at(n: Dictionary, y: float, d: float) -> void:
	# dời mọi thứ nằm dưới y xuống d, kéo dài những gì vắt qua y
	var y0 := float(n.r[1])
	var y1 := y0 + float(n.r[3])
	if y0 >= y - 0.5:
		Snap._move(n, Vector2(0, d))
		return
	if y1 > y - 0.5:
		n.r = [n.r[0], n.r[1], n.r[2], float(n.r[3]) + d]
	for k in n.get("kids", []):
		_grow_at(k, y, d)

func _pc_state() -> Array:
	# [dáng, tiêu đề, mô tả] như Vm(): chưa kề = "Đất hoang"; chưa đủ cấp = không nút; còn lại = nút Khai hoang · giá
	var n: Dictionary = F.PC.G0[pc_id]
	if not F.pc_next(pc_id):
		return ["far", "Đất hoang", "Khai hoang khu đất bên cạnh trước để mở khu này."]
	var t := "Khai hoang " + String(n.name).to_lower()
	var r: int = F.pc_lv(pc_id)
	if r > 0:
		return ["lv", t, "Lên cấp " + str(r) + " mới khai hoang được. " + String(n.desc)]
	return ["buy", t, String(n.desc)]

func _pc_sync() -> void:
	if pc_id == "":
		return
	if F.pc_own(pc_id):
		pc_close()
		return
	var st := _pc_state()
	var n: Dictionary = (pc_tpl[st[0]] as Dictionary).duplicate(true)
	var cost := int(F.PC.G0[pc_id].cost)
	# chữ: tiêu đề một dòng; mô tả xuống dòng theo bề ngang (12,5px, dòng 18,125px)
	var tb: Dictionary = Snap.find(n, "u2pt").kids[0]
	_set_t(tb, st[1], float(tb.r[0]))
	tb.r = [tb.r[0], tb.r[1], tb.tr[2], tb.r[3]]
	var ps: Array = []
	_qall_n(n, "hdes", ps)
	var p0: Dictionary = ps[0]
	var lh := Css.px(p0.css.get("line-height", "18.125px"))
	var fs := _fsz(p0)
	var fw := int(p0.css.get("font-weight", "500"))
	var l0 := int(round(float(p0.r[3]) / lh))
	var l1 := _nlines(st[2], fs, fw, float(p0.r[2]))
	p0.text = st[2]
	p0.erase("tr")
	var d := (l1 - l0) * lh
	if absf(d) > 0.01:
		var yb: float = float(p0.r[1]) + float(p0.r[3])
		p0.r = [p0.r[0], p0.r[1], p0.r[2], float(p0.r[3]) + d]
		for k in n.kids:
			_grow_at(k, yb, d)
		n.r = [n.r[0], n.r[1], n.r[2], float(n.r[3]) + d]
	if st[0] == "buy":
		# "Khai hoang · 300 [xu]": nút ôm chữ
		var bt := Snap.find(n, "hmini")
		var im := Snap.find(bt, "xui")
		var tr: Array = bt.tr
		var pl: float = float(tr[0]) - float(bt.r[0])
		var g: float = float(im.r[0]) - (float(tr[0]) + float(tr[2]))
		var pr: float = float(bt.r[0]) + float(bt.r[2]) - (float(im.r[0]) + float(im.r[2]))
		var s: String = "Khai hoang · " + G.fmt_n(cost)
		var tw := _tw(bt, s)
		bt.text = s
		bt.tr = [tr[0], tr[1], tw + 0.5, tr[3]]
		bt.css["text-align"] = "left"
		im.r = [float(tr[0]) + tw + g, im.r[1], im.r[2], im.r[3]]
		bt.r = [bt.r[0], bt.r[1], pl + tw + g + float(im.r[2]) + pr, bt.r[3]]
	# chỗ đặt (xC): ngang giữa chỗ chạm, trên chỗ chạm 18; sát mép trên quá thì lật xuống dưới
	var H: float = float(n.r[3])
	var Wd: float = float(n.r[2])
	var a: Vector2 = (Vector2(pc_w.x, pc_w.y - 18.0) - main.cam) * main.zoom / Css.K
	var l := maxf(8.0, minf(vw - Wd - 8.0, a.x - Wd * 0.5))
	var c := a.y - H - 18.0
	var below := false
	if c < 70.0:
		c = a.y + 40.0
		below = true
	c = maxf(8.0, minf(vh - H - 8.0, c))
	var ax := roundf(maxf(18.0, minf(Wd - 18.0, a.x - l)))
	if n.has("::after"):
		n["::after"].left = str(ax - 8.0) + "px"
		n["::after"].top = (str(-6.05) if below else str(H - 9.95)) + "px"
	var sig := JSON.stringify(st) + str(cost) + str(ax) + str(below) + str(H)
	pc_off = Vector2(l, c) - Vector2(float(n.r[0]), float(n.r[1]))
	if sig != pc_sig:
		pc_sig = sig
		if pc_b != null:
			pc_b.queue_free()
		var ids := {}
		pc_b = _build(n, ids)
		root.add_child(pc_b)
		_stop(pc_b)
		_click(ids.get(".ppx"), pc_close, "scale")
		var id := pc_id
		_click(ids.get(".hmini"), func(): pc_close(); pc_try(id), "down")
	pc_b.position = (pc_b.r.position + pc_off) * Css.K

func _qall_n(n: Dictionary, cls: String, out: Array) -> void:
	if String(n.get("cls", "")).split(" ").has(cls):
		out.append(n)
	for k in n.get("kids", []):
		_qall_n(k, cls, out)

func pc_try(id: String) -> void:
	# pb + vá L1: đủ điều kiện mà thiếu xu -> "Khai hoang ... còn thiếu xu:" bù bằng sen đỏ rồi mua luôn
	var n: Dictionary = F.PC.G0[id]
	var cost := int(n.cost)
	if not F.pc_own(id) and F.pc_next(id) and F.pc_lv(id) == 0 and int(G.g.coins) < cost:
		_lack_open([], "Khai hoang " + String(n.name).to_lower() + " còn thiếu xu:", func(): pc_try(id), cost - int(G.g.coins))
		return
	F.pc_buy(id)

func tap_plot(i: int) -> void:
	var a: Dictionary = G.p(i)
	if not a.u:
		lock_open(i)
	elif a.c == null:
		gv_open(i)
	else:
		rm_open(i)

func vn_open(va: Dictionary, _w := Vector2.ZERO) -> void:   # chạm con vật / chuồng: vòng nút chung (rm_vn.gd)
	rv.open(va)

var xfp = null               # vòng xưởng (ui_xf.gd)
func xf_open(k: String) -> void:
	xfp.open(k)

func vl_open(u: int) -> void:   # gu("nha", u): chạm nhà dân
	if G.w_all == null:
		return
	if vlp == null:
		vlp = load("res://logic/ui_vl.gd").new(self, G.w_all.WL, G.w_all.WC)
	close_all()
	kho_close()
	vlp.open(u)

func vl_chip(o: Dictionary) -> void:   # chạm nhà có sẵn: chip "Dọn vào ở"
	if G.w_all == null:
		return
	if vlp == null:
		vlp = load("res://logic/ui_vl.gd").new(self, G.w_all.WL, G.w_all.WC)
	close_all()
	kho_close()
	vlp.chip_open(o)

func ng_open(t := "") -> void:   # ngcOpen: nút Nghề trong Menu
	if G.w_all == null:
		return
	if ngp == null:
		ngp = load("res://logic/ui_ng.gd").new(self, G.w_all.WL)
	close_all()
	kho_close()
	ngp.open(t)

func sl_open() -> void:   # Al("book"): nút Sổ làng trong Menu
	if G.w_all == null:
		return
	if slp == null:
		slp = load("res://logic/ui_sl.gd").new(self, G.w_all.WCA, G.w_all.WL, G.w_all.WH)
	close_all()
	kho_close()
	slp.open()

func ut_open(t := "") -> void:   # utOpen: Sổ làng › Uy tín làng
	if G.w_all == null:
		return
	if utp == null:
		utp = load("res://logic/ui_ut.gd").new(self, G.w_all.WL)
	close_all()
	kho_close()
	utp.open(t)

func tn_open(t := "") -> void:   # tnOpen: Sổ làng › Thiên tai, hoạn nạn
	if G.w_all == null:
		return
	if tnp == null:
		tnp = load("res://logic/ui_tn.gd").new(self, G.w_all.WL, G.w_all.WD)
	close_all()
	kho_close()
	tnp.open(t)

func gp_open(u = null) -> void:   # gpOpen: Sổ làng › Gia phả
	if G.w_all == null:
		return
	if gpp == null:
		gpp = load("res://logic/ui_gp.gd").new(self, G.w_all.WL)
	close_all()
	kho_close()
	gpp.open(u)

func hui_open() -> void:   # x6: Sổ làng › Hụi làng (Jg("hui"): chưa tới cấp thì báo)
	if G.w_all == null or not G.w_all.WL._jg("hui"):
		return
	if huip == null:
		huip = load("res://logic/ui_hui.gd").new(self, G.w_all.WH)
	close_all()
	kho_close()
	huip.open()

func hr_open() -> void:   # ZD: Sổ làng › Làm thuê
	if G.w_all == null:
		return
	if hrp == null:
		hrp = load("res://logic/ui_hr.gd").new(self, G.w_all.WL)
	close_all()
	kho_close()
	hrp.open()

func close_all() -> void:
	for p in [slp, utp, hrp, huip, gpp, tnp]:
		if p != null and p.on:
			p.close()
	if ngp != null and ngp.on:
		ngp.close()
	if vlp != null:
		vlp.close()
		vlp.chip_close()
	if pcp != null and pcp.on:
		pcp.close()
	if xfp != null:
		xfp.close()
	if nvp != null:
		nvp.close()
	if setp != null and setp.on:
		setp.close()
	pc_close()
	ord_close()
	gv_close()
	rm_close()
	lock_close()
	dock_open(false)
	if G != null and G.w_all != null:   # NTWEB bảng cây, hạn mặn, chợ nổi, radio, lễ hội
		G.w_all.close_all()

func item_ic(id: String, px: float) -> Texture2D:
	# hình món của bản web (Ai, ui/svg/kh, khung 64), vẽ ra đúng số px màn hình cần (làm tròn lên 2^n): luôn nét
	var n := int(pow(2.0, ceil(log(maxf(16.0, px)) / log(2.0))))
	var key := "kh/" + id + "_" + str(n)
	if _icons.has(key):
		return _icons[key]
	var svg := FileAccess.get_file_as_string("res://ui/svg/kh/" + id + ".svg")
	var img := Image.new()
	if svg == "" or img.load_svg_from_string(svg, n / 64.0) != OK:
		_icons[key] = null
		return null
	_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]

var _icons := {}
func icon(id: String, px: float) -> Texture2D:
	# icon vector của gói thiết kế (icons/<id>.svg), vẽ ra đúng số px màn hình cần (làm tròn lên 2^n): luôn nét
	var n := int(pow(2.0, ceil(log(maxf(16.0, px)) / log(2.0))))
	var key := id + "_" + str(n)
	if _icons.has(key):
		return _icons[key]
	var svg := FileAccess.get_file_as_string("res://icons/" + id + ".svg")
	var img := Image.new()
	if svg == "" or img.load_svg_from_string(svg, n / 64.0) != OK:
		return null
	_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]

# ------------------------------------------------------------------ frame
func _process(dt: float) -> void:
	if root == null:
		return
	if vsize() != _vs:
		var vs := get_viewport().get_visible_rect().size / dpr_v
		var k2 := Khuon.tinh(vs.x, vs.y)
		if (absf(_calc_u(vs, k2) - U) > 0.001 or absf(minf(0.66 * vs.x, 320.0) * Khuon.S_SNAP - goal_built) > 0.5) and has_meta("rebuild"):
			# khác độ to: dựng lại cả giao diện theo s mới (như web đổi --ks)
			_vs = vsize()
			(get_meta("rebuild") as Callable).call_deferred()
			return
		kh = k2
		_layout()
	_cam_step(dt)
	if nvp != null:
		nvp.step(dt)
	if lvp != null:
		lvp.step(dt)
	if setp != null:
		setp.step(dt)
	if vlp != null:
		vlp.step(dt)
	if ngp != null:
		ngp.step(dt)
	for p in [slp, utp, hrp, huip, gpp, tnp]:
		if p != null:
			p.step(dt)
	_ng_bdg()
	if xfp != null:
		xfp.step(dt)
	if bdp != null:
		bdp.step(dt)
	if khp != null:
		khp.step()
	if spp != null:
		spp.step()
	if pcp != null:
		pcp.step()
	_t -= dt
	if _t <= 0.0:
		_t = 0.25
		_clock()
		_sync_hud()
		if gv_i >= 0:
			var a: Dictionary = G.p(gv_i)
			if not a.u or a.c != null:
				gv_close()
			else:
				_gv_sync()
		if rm_on():
			_rm_sync()
		if lk_i >= 0:
			if G.p(lk_i).u:
				lock_close()
			else:
				_lock_sync()
		if kho_on:
			_kho_sync()
		if od_on:
			_ord_sync()
		if G.w_all != null:   # NTWEB bảng cây, chợ nổi, lễ hội, nút viên
			G.w_all.ui_tick()
	if pc_id != "":
		_pc_sync()
	if gv_i >= 0:
		_gv_pos()
	if rm_on():
		_rm_pos()
	if lk_i >= 0:
		_lock_pos()
	var want := 1.0 if rm_on() or (xfp != null and xfp.is_open()) else 0.0
	dim_a = move_toward(dim_a, want, dt / 0.2)
	dim.visible = dim_a > 0.001
	if dim.visible:
		dim.size = get_viewport().get_visible_rect().size
		dim_mat.set_shader_parameter("a", dim_a)
		dim.queue_redraw()
	if kh_conf > 0.0:
		kh_conf -= dt
		if kh_conf <= 0.0:
			_kho_conf_off()
			kh_sig = ""
	if toast_b != null:
		_toast_t -= dt
		toast_b.modulate.a = clampf(_toast_t / 0.25, 0.0, 1.0)
		if _toast_t <= 0.0:
			toast_b.queue_free()
			toast_b = null

func _input(e: InputEvent) -> void:
	# bảng che cả màn đang mở (Cài đặt, Kho, Nhiệm vụ, Lên cấp, cửa hàng Xây dựng): bản đồ không được lướt/zoom theo ngón tay (như web: .pbk chặn).
	# main.gd đọc cờ này trong _unhandled_input; không chặn sự kiện ở đây để main vẫn đếm đủ ngón tay.
	get_tree().set_meta("ui_modal", (setp != null and setp.on) or (vlp != null and vlp.on) or (ngp != null and ngp.on) or (slp != null and slp.on) or (utp != null and utp.on) or (hrp != null and hrp.on) or (huip != null and huip.on) or (gpp != null and gpp.on) or (tnp != null and tnp.on) or kho_on or (nvp != null and nvp.on) or (lvp != null and lvp.on) or (bdp != null and bdp.mode == "shop"))
	_od_input(e)
	# dd: chạm ra ngoài hộp hỏi "Tốn ... sen đỏ" thì đóng (pointerdown bắt trước, không chặn)
	if xfp != null and xfp.ask != null and is_instance_valid(xfp.ask) and _is_tap_down(e):
		var pp: Vector2 = e.position
		if not xfp.ask.get_global_rect().has_point(pp):
			xfp._ask_close()
	if lvp != null:
		lvp.input(e)
	if setp != null:
		setp.input(e)
	if vlp != null:
		vlp.input(e)
	if ngp != null:
		ngp.input(e)
	for p in [slp, utp, hrp, huip, gpp, tnp]:
		if p != null:
			p.input(e)
	if xfp != null:
		xfp.input(e)
