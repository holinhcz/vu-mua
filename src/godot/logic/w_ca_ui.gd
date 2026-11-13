extends RefCounted
# Giao diện câu cá, lờ lọp, thú cưng, tát ao, thả diều: chép nội dung và nút từ bản web.
#  - tab Câu cá (#pn-fish): #fishc (khung ao: chỗ trống cho lớp vẽ SX), #fishRes, #fishMsg, #fishGo (Xh + lớp bọc),
#    thanh mồi .caubait (oA), #fishInfo (yE), .fishrod (#fishRodT, #fishRodD + Q4, #fishRod -> fF), Sổ cá #fishDex.
#  - tab Nuôi thêm (QQ + nút data-pet của GV), tab Diều (zh "dieu"), tab Lờ lọp (zh "lo") trong bảng nhân vật.
#  - thanh chọn chỗ thả .visitbar.pickbar (wg / f6).
#  - bảng Tát ao bắt cá (y4: #tMsg, #tBag, nút data-trui / data-tve) và Thi diều (dU: #kMsg, nút Kéo dây data-kp / Xong data-kd).
# Khung canvas (SX, _K, gU) là phần vẽ: ở đây chỉ chừa chỗ (Control) và nhận chạm; lớp vẽ đọc R.fo / R.ai / R.zi.
# Dựng bằng Control thường (bản web không có bản chụp số đo cho mấy bảng này), cỡ theo Css.K như w_cho_ui.gd.

const Css = preload("res://ui/css.gd")

const BAIT_IC := {   # c1[k].ic (sau = Ze.sau), sinh từ web_all.js
	"cam": "<path d=\"M14 30Q32 20 50 30L46 50Q32 58 18 50Z\" fill=\"#c9a46a\" stroke=\"#7a5a2a\" stroke-width=\"1.6\"/><ellipse cx=\"32\" cy=\"30\" rx=\"18\" ry=\"6\" fill=\"#e8c88a\"/><circle cx=\"26\" cy=\"29\" r=\"2\" fill=\"#b8884a\"/><circle cx=\"34\" cy=\"31\" r=\"2\" fill=\"#b8884a\"/><circle cx=\"38\" cy=\"28\" r=\"1.6\" fill=\"#b8884a\"/>",
	"trun": "<path d=\"M10 42Q16 30 26 38T42 34Q50 30 54 38\" stroke=\"#c46a6a\" stroke-width=\"7\" fill=\"none\" stroke-linecap=\"round\"/><path d=\"M10 42Q16 30 26 38T42 34Q50 30 54 38\" stroke=\"#e89a9a\" stroke-width=\"2.4\" fill=\"none\" stroke-linecap=\"round\" stroke-dasharray=\"2 4\"/><path d=\"M6 50Q32 46 58 50\" stroke=\"#7a5434\" stroke-width=\"3\" fill=\"none\"/>",
	"thom": "<circle cx=\"22\" cy=\"38\" r=\"9\" fill=\"#e8c46a\" stroke=\"#a8843a\" stroke-width=\"1.5\"/><circle cx=\"40\" cy=\"36\" r=\"9\" fill=\"#e2b85a\" stroke=\"#a8843a\" stroke-width=\"1.5\"/><circle cx=\"31\" cy=\"24\" r=\"9\" fill=\"#f2d48a\" stroke=\"#a8843a\" stroke-width=\"1.5\"/><path d=\"M24 12Q22 6 26 2M34 12Q32 4 36 0\" stroke=\"#b8a070\" stroke-width=\"1.6\" fill=\"none\" opacity=\".7\"/>",
	"sau": "<path d=\"M14 40Q20 30 28 38Q36 46 44 36Q50 28 54 34\" stroke=\"#5aa832\" stroke-width=\"9\" fill=\"none\" stroke-linecap=\"round\"/><path d=\"M14 40Q20 30 28 38Q36 46 44 36Q50 28 54 34\" stroke=\"#8ad05a\" stroke-width=\"4\" fill=\"none\" stroke-linecap=\"round\" stroke-dasharray=\"3 4\"/><circle cx=\"55\" cy=\"33\" r=\"5.5\" fill=\"#4a9a2a\"/><circle cx=\"57\" cy=\"31.5\" r=\"1.4\" fill=\"#1a120c\"/><path d=\"M54 27L52 22M58 28L60 23\" stroke=\"#3a6a1a\" stroke-width=\"1.6\" stroke-linecap=\"round\"/>",
}

var U          # ui.gd
var G          # game.gd
var R          # w_ca.gd
var ext := {}  # "Ns": func(o: Dictionary) -> void (xếp việc thăm bẫy {type: "lo", key}), "ec": vẽ lại bảng nhân vật, "g2": đóng bảng nhân vật

# tab Câu cá
var fish: Control = null
var _f := {}               # các nút / chữ của tab câu
var VO := ""               # chữ ký sổ cá
var _rod_sig := ""         # #fishRodD.dataset.sig
var _res_sig := ""         # #fishRes data-sig
var _bait_ic := {}         # hình mồi đã vẽ (vẽ một lần)
# thanh chọn chỗ
var pick: Control = null
# tát ao, thi diều
var tat: Control = null
var _t := {}
var kite: Control = null
var _kt := {}

func _init(ui, rules) -> void:
	U = ui
	G = ui.G
	R = rules
	R.ui = self

func _x(k: String) -> Callable:
	var c = ext.get(k)
	return c if c is Callable and (c as Callable).is_valid() else Callable()

static func _k(v: float) -> float:
	return v * Css.K

# ------------------------------------------------------------------ khối dựng chung
func _lbl(s: String, fs: float, w: int, col: Color, wrap := true) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", Css.font(w))
	l.add_theme_font_size_override("font_size", int(_k(fs)))
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _btn(s: String, primary: bool, on: bool, cb: Callable) -> Button:   # .btn / .btn.primary
	var b := Button.new()
	b.text = s
	b.disabled = not on
	b.add_theme_font_override("font", Css.font(700))
	b.add_theme_font_size_override("font_size", int(_k(14)))
	_btn_style(b, primary)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

func _btn_style(b: Button, primary: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(0x3f, 0x9a, 0x3a) if primary else Color8(0xff, 0xff, 0xff)
	sb.border_color = Color8(0x2f, 0x7a, 0x2a) if primary else Color8(0xd8, 0xc8, 0xa8)
	sb.set_border_width_all(int(maxf(1.0, _k(1.5))))
	sb.set_corner_radius_all(int(_k(10)))
	sb.content_margin_left = _k(12)
	sb.content_margin_right = _k(12)
	sb.content_margin_top = _k(6)
	sb.content_margin_bottom = _k(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	var sd := sb.duplicate()
	sd.bg_color = sd.bg_color.lerp(Color(0.85, 0.85, 0.85), 0.55)
	b.add_theme_stylebox_override("disabled", sd)
	b.add_theme_color_override("font_color", Color.WHITE if primary else Color8(0x3a, 0x2a, 0x1a))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.7) if primary else Color8(0xa0, 0x90, 0x80))

func _ic(id: String, px: float) -> TextureRect:   # Ai(id)
	var t := TextureRect.new()
	t.texture = U.item_ic(id, _k(px))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(_k(px), _k(px))
	return t

func _note(s: String) -> Label:   # p.note
	return _lbl(s, 12, 400, Color8(0x8a, 0x7a, 0x6a))

func _sec(b: String, small: String) -> Control:   # .vl-sec
	var v := VBoxContainer.new()
	v.add_child(_lbl(b, 14, 800, Color8(0x3a, 0x2a, 0x1a)))
	if small != "":
		v.add_child(_lbl(small, 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
	return v

func _tt(b: String, small: String, btns: Array, got := false) -> Control:   # .tt: <div><b/><small/></div> + nút
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(_k(8)))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_lbl(b, 13.5, 800, Color8(0x2f, 0x7a, 0x2a) if got else Color8(0x3a, 0x2a, 0x1a)))
	if small != "":
		v.add_child(_lbl(small, 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
	h.add_child(v)
	if btns.size():
		var j := HBoxContainer.new()   # .vl-jobs
		j.add_theme_constant_override("separation", int(_k(6)))
		for b2 in btns:
			j.add_child(b2)
		h.add_child(j)
	return h

func _jobs(btns: Array) -> Control:   # .vl-jobs
	var j := HFlowContainer.new()
	j.add_theme_constant_override("h_separation", int(_k(6)))
	j.add_theme_constant_override("v_separation", int(_k(6)))
	for b in btns:
		j.add_child(b)
	return j

func _chip(ic: Control, s: String, ok: bool) -> Control:   # .chip ok|no
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(_k(3)))
	if ic != null:
		h.add_child(ic)
	h.add_child(_lbl(s, 12, 700, Color8(0x2f, 0x7a, 0x2a) if ok else Color8(0xc0, 0x3a, 0x2a), false))
	return h

func _q4(t: Dictionary) -> Control:   # Q4: .need (ô xu + pJ từng vật liệu "có/cần")
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", int(_k(6)))
	if int(t.xu):
		h.add_child(_chip(_lbl("xu", 11, 700, Color8(0xb0, 0x80, 0x20), false), G.fmt_n(int(t.xu)), int(G.g.coins) >= int(t.xu)))
	for a in t.m:
		var have: int = G.mat_n(String(a[0]))
		h.add_child(_chip(_ic(String(a[0]), 20), str(have) + "/" + str(int(a[1])), have >= int(a[1])))
	return h

func _overlay(title: String, on_close: Callable) -> Array:   # .raceov > .rbox: [gốc, cột]
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(0xff, 0xfa, 0xf0)
	sb.set_corner_radius_all(int(_k(18)))
	sb.content_margin_left = _k(14)
	sb.content_margin_right = _k(14)
	sb.content_margin_top = _k(12)
	sb.content_margin_bottom = _k(14)
	box.add_theme_stylebox_override("panel", sb)
	box.custom_minimum_size = Vector2(minf(U.vsize().x - 32.0, 560.0), 0) * Css.K
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(box)
	ov.add_child(cc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(_k(8)))
	box.add_child(col)
	var hd := HBoxContainer.new()   # .ws-h
	var b := _lbl(title, 17, 800, Color8(0x3a, 0x2a, 0x1a))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(b)
	var x := _btn("×", false, true, on_close)   # .ibtn aria-label Đóng
	x.tooltip_text = "Đóng"
	hd.add_child(x)
	col.add_child(hd)
	U.root.add_child(ov)
	return [ov, col]

func _canvas(w: float, h: float) -> Control:   # <canvas width=w height=h>: chỗ cho lớp vẽ, giữ tỉ lệ
	var c := AspectRatioContainer.new()
	c.ratio = w / h
	c.custom_minimum_size = Vector2(0, _k(160))
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	c.add_child(area)
	return c

static func _down(e) -> bool:
	return (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed) or (e is InputEventScreenTouch and e.pressed)

static func _up(e) -> bool:
	return (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed) or (e is InputEventScreenTouch and not e.pressed)

# ------------------------------------------------------------------ tab Câu cá (#pn-fish)
func fish_panel() -> Control:   # dựng #pn-fish (người ghép đặt vào chỗ tab "fish"; hiện thì gọi R.me_open(), ẩn thì R.zo())
	if fish != null:
		return fish
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(_k(8)))
	var wrap := _canvas(4.0, 3.0)   # #fishWrap > canvas#fishc
	var area: Control = wrap.get_child(0)
	area.gui_input.connect(func(e) -> void:
		if _down(e):
			if R.me():   # mE
				_bE()
		elif _up(e):
			R.e8()
			_bE())
	_f.area = area
	var res := VBoxContainer.new()   # #fishRes
	res.visible = false
	var ri := CenterContainer.new()   # #fishResI
	res.add_child(ri)
	var rn := _lbl("", 15, 800, Color8(0x3a, 0x2a, 0x1a), false)   # #fishResN
	res.add_child(rn)
	var rd := _lbl("", 12, 500, Color8(0x5a, 0x4a, 0x3a))   # #fishResD
	res.add_child(rd)
	area.add_child(res)
	res.set_anchors_preset(Control.PRESET_CENTER)
	_f.res = res
	_f.resI = ri
	_f.resN = rn
	_f.resD = rd
	v.add_child(wrap)
	var msg := _lbl("", 13, 600, Color8(0x3a, 0x2a, 0x1a))   # #fishMsg
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(msg)
	_f.msg = msg
	var bait := VBoxContainer.new()   # .caubait (oA chèn trước #fishGo)
	v.add_child(bait)
	_f.bait = bait
	var go := _btn("Thả câu", true, true, Callable())   # #fishGo
	go.button_down.connect(func() -> void:
		if R.me():   # pointerdown -> mE
			_bE())
	go.button_up.connect(func() -> void:
		R.e8()   # pointerup -> e8
		_bE())
	go.pressed.connect(func() -> void:
		R.go_click()
		xh())
	v.add_child(go)
	_f.go = go
	var info := _note("")   # #fishInfo
	v.add_child(info)
	_f.info = info
	var rod := HBoxContainer.new()   # .fishrod
	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rt := _lbl("Cần câu tre", 13.5, 800, Color8(0x3a, 0x2a, 0x1a), false)   # #fishRodT
	rv.add_child(rt)
	var rdd := VBoxContainer.new()   # #fishRodD
	rv.add_child(rdd)
	rod.add_child(rv)
	var rb := _btn("", false, true, func() -> void:   # #fishRod -> fF
		R.ff()
		xh())
	rod.add_child(rb)
	v.add_child(rod)
	_f.rodT = rt
	_f.rodD = rdd
	_f.rod = rb
	v.add_child(_lbl("Sổ cá", 15, 800, Color8(0x3a, 0x2a, 0x1a), false))   # h3.fishh
	var dex := GridContainer.new()   # #fishDex
	dex.columns = 3
	dex.add_theme_constant_override("h_separation", int(_k(6)))
	dex.add_theme_constant_override("v_separation", int(_k(6)))
	v.add_child(dex)
	_f.dex = dex
	fish = v
	VO = ""
	_rod_sig = ""
	_res_sig = ""
	R.S3 = ""
	xh()
	return v

func _bE() -> void:   # bE: #fishGo.hold
	if fish != null:
		_f.go.modulate = Color(0.85, 0.95, 0.85) if R.fo.hold else Color.WHITE

func xh() -> void:   # Xh (+ lớp bọc): điền tab câu
	if fish == null or not is_instance_valid(fish):
		return
	var o: Dictionary = R.fo
	var t := String(o.st)
	var r: int = R._rod()
	var n: String
	if t == "idle" or t == "caught" or t == "lost":
		n = ("Thả câu" if t == "idle" else "Thả câu tiếp") + " · " + str(R.n8) + " xu"
	elif t == "cast" or t == "wait":
		n = "Thu cần về"
	elif t == "bite":
		n = "Giật!"
	else:
		n = "Giữ để kéo"
	var dis: bool = (t == "idle" or t == "caught" or t == "lost") and int(G.g.coins) < R.n8
	var bs: String = R.b9()   # lớp bọc: mồi khác cám
	if bs != "cam" and (t == "idle" or t == "caught" or t == "lost"):
		n = ("Thả câu" if t == "idle" else "Thả câu tiếp") + " · " + String(R.c1[bs].n).to_lower() + " (" + str(int(R.lv(bs))) + ")"
		dis = R.lv(bs) < 1
	if _f.go.text != n:
		_f.go.text = n
	_f.go.disabled = dis
	var h := String(o.msg)
	if h == "":
		if t == "idle":
			h = "Bấm Thả câu, chờ phao chìm rồi giật thật nhanh."
		elif t == "cast" or t == "wait":
			h = "Đang chờ cá cắn câu..."
		elif t == "bite":
			h = "Cá cắn câu rồi, giật ngay!"
	if _f.msg.text != h:
		_f.msg.text = h
	var inf: String = R.ye()
	if _f.info.text != inf:
		_f.info.text = inf
	_f.rodT.text = String(R.n3[r]) + " · cấp " + str(r + 1)
	if r >= 4:
		if _rod_sig != "max":
			_rod_sig = "max"
			_clear(_f.rodD)
			_f.rodD.add_child(_lbl(String(R.rA[4]), 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
		_f.rod.text = "Tối đa"
		_f.rod.disabled = true
	else:
		var c: Dictionary = R.cf(r + 1)
		var f: bool = G.lv() < int(c.lv)
		var ms := []
		for p in c.m:
			ms.append(str(G.mat_n(String(p[0]))))
		var s := str(r) + "|" + ("1" if f else "0") + "|" + str(G.g.coins) + "|" + ",".join(ms)
		if _rod_sig != s:
			_rod_sig = s
			_clear(_f.rodD)
			_f.rodD.add_child(_lbl("Lên " + String(R.n3[r + 1]).to_lower() + ": " + String(R.rA[r + 1]).to_lower() + ".", 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
			_f.rodD.add_child(_q4(c))
			_f.rod.text = ("🔒 Cấp " + str(c.lv)) if f else "Nâng cần"
			_f.rod.disabled = f
			_btn_style(_f.rod, G.can_pay(c) and not f)
	var res = o.res
	if t == "caught" and res is Dictionary:
		_f.res.visible = true
		var k := String(res.id) + "|" + str(res.kg) + "|" + str(res.get("big", 0))
		if _res_sig != k:
			_res_sig = k
			_clear(_f.resI)
			_f.resI.add_child(_ic(String(res.id), 48))
			_f.resN.text = G.item_name(String(res.id))
			_f.resD.text = ("🏆 Cá khủng! " if R._tr(res.get("big")) else "") + R._kgs(res.kg) + " kg · giá chợ " + str(res.price) + " xu · đã vào kho"
	elif _f.res.visible:
		_f.res.visible = false
		_res_sig = ""
	var fi: Dictionary = R._fi()
	var sg := []
	for w in R.Wf:
		var E = fi.dex.get(w)
		sg.append((str(E.n) + ":" + str(E.best)) if E is Dictionary else "0")
	var T := "|".join(sg)
	if T != VO:
		VO = T
		_clear(_f.dex)
		for w in R.Wf:
			var E = fi.dex.get(w)
			var C := int(E.n) if E is Dictionary else 0
			var cell := VBoxContainer.new()   # .fc / .fc.no
			cell.modulate = Color.WHITE if C else Color(1, 1, 1, 0.5)
			var ic := _ic(String(w), 36)
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell.add_child(ic)
			cell.add_child(_lbl(G.item_name(String(w)) if C else "Chưa gặp", 12, 800, Color8(0x3a, 0x2a, 0x1a)))
			cell.add_child(_lbl((str(C) + " con · nặng nhất " + R._kgs(E.best) + " kg") if C else "Thử câu xem", 10.5, 500, Color8(0x8a, 0x6a, 0x48)))
			_f.dex.add_child(cell)
	_oa()

func _bait_tex(k: String) -> Texture2D:   # FY: ốc, tép = Ai(k); còn lại Hi(c1[k].ic) (vẽ một lần)
	if k == "oc" or k == "tep":
		return U.item_ic(k, _k(28))
	if _bait_ic.has(k):
		return _bait_ic[k]
	var img := Image.new()
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">' + String(BAIT_IC.get(k, "")) + "</svg>"
	var px := int(pow(2.0, ceil(log(maxf(16.0, _k(28))) / log(2.0))))
	var tex: Texture2D = null
	if img.load_svg_from_string(svg, px / 64.0) == OK:
		tex = ImageTexture.create_from_image(img)
	_bait_ic[k] = tex
	return tex

func _oa() -> void:   # oA: thanh chọn mồi
	if fish == null:
		return
	var a: String = R.b9()
	var lvs := []
	for k in R.sF:
		lvs.append(str(R.lv(k)))
	var n := "|".join([a, ",".join(lvs), str(int(G.g.barn.get("bot", 0))), str(int(G.g.barn.get("trung", 0))), String(R.fo.st)])
	if n == R.S3:
		return
	R.S3 = n
	var box: VBoxContainer = _f.bait
	_clear(box)
	var e: Dictionary = R.c1[a]
	var row := HBoxContainer.new()   # .cbrow
	row.add_theme_constant_override("separation", int(_k(4)))
	for o in R.sF:
		var l: float = R.lv(o)
		var c: bool = o == a
		var b := Button.new()   # .cb (.on, .none)
		b.toggle_mode = true
		b.button_pressed = c
		b.tooltip_text = String(R.c1[o].n) + ": " + String(R.c1[o].src)
		b.custom_minimum_size = Vector2(_k(48), _k(56))
		b.modulate = Color(1, 1, 1, 0.5) if l < 1 else Color.WHITE
		var bv := VBoxContainer.new()
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.set_anchors_preset(Control.PRESET_FULL_RECT)
		var ti := TextureRect.new()
		ti.texture = _bait_tex(o)
		ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ti.custom_minimum_size = Vector2(_k(24), _k(24))
		ti.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(ti)
		var bl := _lbl("3 xu" if l == INF else str(int(l)), 11, 800, Color8(0x3a, 0x2a, 0x1a), false)
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(bl)
		var bs := _lbl(String(R.c1[o].n), 9.5, 500, Color8(0x8a, 0x6a, 0x48), false)
		bs.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(bs)
		b.add_child(bv)
		var key: String = o
		b.pressed.connect(func() -> void:   # [data-bt]
			R.pick_bait(key)
			xh())
		row.add_child(b)
	box.add_child(row)
	var r := []
	var mu = e.get("mul")
	if mu is Dictionary:
		for k in mu:
			if float(mu[k]) > 1:
				r.append(G.item_name(String(k)).to_lower() if not G.item(String(k)).is_empty() else String(k))
	var inf := VBoxContainer.new()   # .cbinfo
	inf.add_child(_lbl(String(e.n) + " · " + (("dụ " + ", ".join(r)) if r.size() else "mồi thường") + ((" · cá cắn lẹ hơn " + str(R._rnd((1.0 - float(e.wait)) * 100.0)) + "%") if float(e.wait) < 1 else ""), 12, 700, Color8(0x3a, 0x2a, 0x1a)))
	inf.add_child(_lbl(String(e.src) + ".", 11, 500, Color8(0x8a, 0x6a, 0x48)))
	if a == "thom" or R.lv("thom") < 1:
		inf.add_child(_btn("Trộn mồi thơm (1 bột mì + 1 trứng)", false, true, func() -> void:   # [data-mix] -> uF
			R.uf()
			xh()))
	box.add_child(inf)

static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

# ------------------------------------------------------------------ bảng nhân vật: tab Nuôi thêm, Diều, Lờ lọp
func tab_name(id: String) -> String:   # zh[].n()
	if id == "dieu":
		return "Diều"
	if id == "lo":
		var t: int = R.ready_n()
		return "Lờ lọp" + ((" (" + str(t) + ")") if t else "")
	return "Nuôi thêm"

func _ec() -> void:
	var f := _x("ec")
	if f.is_valid():
		f.call()

func tab_body(id: String) -> Control:   # QQ / zh["dieu"].html / zh["lo"].html (+ click)
	match id:
		"nuoi": return _qq()
		"dieu": return _dieu()
		"lo": return _lo()
	return Control.new()

func _qq() -> Control:   # QQ + GV (data-pet)
	var t: Dictionary = R.cc()
	var a: Dictionary = t.vit
	var n: Dictionary = t.ca
	var e: Dictionary = t.meo
	var r: Dictionary = t.chim
	var o: int = G.day()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(_k(8)))
	v.add_child(_note("Nuôi thêm quanh nhà. Chạm vào con vật trên cảnh để nhân vật ra cho ăn, thu sản phẩm."))
	var pet := func(k: String) -> void:
		if k == "thi":
			R.dq()
		else:
			R.vq(k)
		_ec()
	var nv := int(a.n)
	var vb := []
	if nv < R.t6:
		vb.append(_btn(("Thêm 3 con" if nv else "Mua 3 con, chọn chỗ thả") + " · " + G.fmt_n(R.Nh.vit), false, R.e6(), pet.bind("vit")))
	if nv:
		vb.append(_btn("Đổi chỗ thả", false, true, pet.bind("mvit")))
	v.add_child(_tt("Đàn vịt" + ((" · " + str(nv) + " con · thả ở " + R.o6("vit")) if nv else ""),
		("Đói/no: " + (("còn no " + str(int(ceil(float(a.f) / 60.0))) + " phút") if float(a.f) > 0 else "đang đói") + " · trứng chờ lấy: " + str(a.e) + ". Cho ăn bằng lúa, mỗi con 150 giây đẻ 1 trứng.") if nv else ("Thả đàn vịt xuống ao, hồ hay sông tùy bạn chọn, cho ăn lúa thì đẻ trứng vịt. 3 con " + G.fmt_n(R.Nh.vit) + " xu (tối đa " + str(R.t6) + ")."),
		[_jobs(vb)]))
	var nc := int(n.n)
	v.add_child(_tt("Cá nuôi" + ((" · " + str(nc) + " con · thả ở " + R.o6("ca")) if nc else ""),
		("Lớn " + str(R._rnd(float(n.g) / R.Xf * 100.0)) + "% · " + ("đang no" if float(n.f) > 0 else "đang đói, cần cám") + ". Lớn đủ thì chạm ao để kéo lưới lấy cá tra.") if nc else ("Thả cá giống xuống ao, hồ hay sông tùy bạn chọn, rải cám (bột) cho ăn, khoảng 15 phút được cá tra. 10 con " + G.fmt_n(R.Nh.ca) + " xu."),
		[_btn("Đổi chỗ thả", false, true, pet.bind("mca"))] if nc else [_btn("Chọn chỗ, thả 10 con · " + G.fmt_n(R.Nh.ca), false, R.e6(), pet.bind("ca"))]))
	var mh: bool = R._tr(e["has"])
	v.add_child(_tt("Mèo mướp" + ((" · thân " + str(int(e.get("tim", 0))) + "/10") if mh else ""),
		(("Hôm nay đã ăn." if int(e.fd) == o else "Chưa cho ăn hôm nay (1 cá nhỏ).") + " Cho ăn hôm nay thì sáng mai Mướp tha quà về. Vuốt ve mỗi tiếng +8 sức.") if mh else ("Mèo canh nhà, cho ăn cá mỗi ngày thì sáng ra tha quà về. " + G.fmt_n(R.Nh.meo) + " xu."),
		[] if mh else [_btn("Xin mèo · " + G.fmt_n(R.Nh.meo), false, true, pet.bind("meo"))]))
	var ch: bool = R._tr(r["has"])
	var thi := int(r.gi) >= 3 and int(r.cd) != o
	v.add_child(_tt("Chào mào" + ((" · giọng " + str(r.gi) + "/10") if ch else ""),
		(("Hôm nay đã ăn." if int(r.fd) == o else "Chưa cho ăn hôm nay (chuối hoặc ớt).") + " Mỗi ngày ăn đủ thì giọng hót lên 1. Giọng từ 3 trở lên đem đi thi mỗi ngày một lần.") if ch else ("Lồng chim treo hiên, sáng sáng hót líu lo. Mở ở cấp 4, " + G.fmt_n(R.Nh.chim) + " xu."),
		[_btn("Đã thi hôm nay" if int(r.cd) == o else "Đi thi hót", thi, thi, pet.bind("thi"))] if ch else [_btn("Mua · " + G.fmt_n(R.Nh.chim), false, G.lv() >= 4, pet.bind("chim"))]))
	if not R.e6():
		v.add_child(_note("Vịt và cá cần mặt nước trong đất của bạn: ao sen, hồ, sông Vàm hoặc ao tự đào."))
	return v

func _dieu() -> Control:   # zh "dieu": html + click
	var t: Dictionary = R.fh()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(_k(8)))
	v.add_child(_note("Mùa gió chướng (đông và xuân), chiều 14–18 giờ trời có gió. " + ("Đang có gió, thả diều được!" if R.cg() else "Bây giờ chưa có gió.") + " Đã thắng " + str(int(t.get("cup", 0))) + " lần thi diều."))
	for e in R.k4:
		var id := String(e.id)
		var r: bool = R._tr(t["has"].get(id))
		var cur: bool = t.cur == id
		var b: Button
		if r:
			b = _btn("Đang dùng" if cur else "Chọn", cur, true, func() -> void:   # data-kite
				R.pick_kite(id)
				_ec())
		else:
			b = _btn("Làm · " + G.fmt_n(int(e.xu)) + " xu", false, G.lv() >= int(e.lv), func() -> void:   # data-kbuy
				R.cu(id)
				_ec())
		v.add_child(_tt(String(e.n), String(e.d) + ("" if r else " · mở ở cấp " + str(e.lv)), [b], cur))
	var has_cur: bool = R._tr(t.cur)
	var b1 := _btn("Thu diều về" if R._tr(t.on) else "Thả diều", true, has_cur, func() -> void:   # data-kon
		R.fu()
		_ec())
	var b2 := _btn("Mai thi tiếp" if int(t.td) == G.day() else "Thi diều với tụi nhỏ", false, has_cur and int(t.td) != G.day(), func() -> void:   # data-kcon
		R.du())
	v.add_child(_jobs([b1, b2]))
	return v

func _lo() -> Control:   # zh "lo": html + click
	var t: Dictionary = R.t1()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(_k(8)))
	v.add_child(_note("Mua lờ, lọp, dây câu rồi đặt dưới mương, ao, sông. Để một lúc cá vô, ra thăm lấy cá. Đặt ban đêm, thăm ban đêm được nhiều hơn. Thỉnh thoảng rái cá vô ăn mất. Đã thăm " + str(int(t.n)) + " lần."))
	for n in R.FS:
		var e: Dictionary = R.ns[n]
		var r: int = R.jd(n)
		var o: int = R.qk(n)
		var bait = e.get("bait")
		var key: String = n
		var buy := _btn("Mua · " + G.fmt_n(int(e.xu)), false, r < int(e.max), func() -> void:   # data-lob
			R.uu(key)
			_ec())
		var put := _btn("Đặt", true, o < r, func() -> void:   # data-lop
			R.nk_lo(key))
		v.add_child(_tt(String(e.n) + " · có " + str(r) + "/" + str(e.max) + " · đang đặt " + str(o),
			String(e.d) + " Thăm mỗi " + str(R._rnd(float(e.ms) / 6e4)) + " phút" + ((", mồi " + str(int(bait[1])) + " " + G.item_name(String(bait[0])).to_lower() + " (kho còn " + str(int(G.g.barn.get(bait[0], 0))) + ")") if bait != null else "") + ".",
			[buy, put]))
	if t["set"].size():
		v.add_child(_sec("Đang đặt", "Chạm Thăm để nhân vật lội ra lấy cá."))
		for n in t["set"]:
			var e: Dictionary = R.ns[n.t]
			var r: bool = R.w4(n)
			var key: String = R.bk(n)
			var visit := _btn("Thăm", r, r, func() -> void:   # data-loh
				var g2 := _x("g2")
				if g2.is_valid():
					g2.call()
				var ns_ := _x("Ns")
				if ns_.is_valid():
					ns_.call({"type": "lo", "key": key}))
			var rm := _btn("Gỡ", false, true, func() -> void:   # data-lor
				R.sr(key)
				_ec())
			v.add_child(_tt(String(e.n), ("Có cá rồi" if r else "Còn " + str(int(ceil(R.l6_ms(n) / 6e4))) + " phút") + (" · không mồi" if e.get("bait") != null and not R._tr(n.get("b")) else "") + " · dùng thêm " + str(int(e.use) - int(n.u)) + " lần", [visit, rm], r))
	return v

# ------------------------------------------------------------------ thanh chọn chỗ thả (Ud)
func pick_bar() -> void:   # wg dựng / f6 ẩn
	if pick != null:
		pick.queue_free()
		pick = null
	var y = R.yf
	if y == null:
		return
	var bar := PanelContainer.new()   # .visitbar.pickbar
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(0xff, 0xfa, 0xf0)
	sb.set_corner_radius_all(int(_k(14)))
	sb.content_margin_left = _k(12)
	sb.content_margin_right = _k(12)
	sb.content_margin_top = _k(8)
	sb.content_margin_bottom = _k(8)
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -_k(16)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(_k(10)))
	var v := VBoxContainer.new()
	v.add_child(_lbl(String(y.msg), 13.5, 800, Color8(0x3a, 0x2a, 0x1a), false))
	v.add_child(_lbl(String(y.sub), 11.5, 500, Color8(0x8a, 0x6a, 0x48)))
	v.custom_minimum_size = Vector2(_k(220), 0)
	h.add_child(v)
	h.add_child(_btn("Hủy", false, true, func() -> void:   # data-pk=x
		R.f6(true)))
	bar.add_child(h)
	U.root.add_child(bar)
	pick = bar

# ------------------------------------------------------------------ bảng Tát ao bắt cá
func tat_open() -> void:   # y4: dựng .raceov "Tát ao bắt cá"
	tat_close()
	var p := _overlay("Tát ao bắt cá", func() -> void:   # data-tx
		R.ys())
	tat = p[0]
	var col: VBoxContainer = p[1]
	var cv := _canvas(760.0, 330.0)   # canvas 1520 x 660 (khung 760 x 330)
	var area: Control = cv.get_child(0)
	area.gui_input.connect(func(e) -> void:   # pointerdown -> KK
		if _down(e) and area.size.x > 0 and area.size.y > 0:
			var pp: Vector2 = e.position
			R.kk(pp.x / area.size.x * 760.0, pp.y / area.size.y * 330.0))
	col.add_child(cv)
	_t.area = area
	var msg := _lbl("", 13, 600, Color8(0x3a, 0x2a, 0x1a))   # #tMsg
	col.add_child(msg)
	_t.msg = msg
	var row := HFlowContainer.new()   # #tRow
	row.add_theme_constant_override("h_separation", int(_k(6)))
	var bag := HFlowContainer.new()   # #tBag
	bag.add_theme_constant_override("h_separation", int(_k(6)))
	bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bag)
	col.add_child(row)
	_t.row = row
	_t.bag = bag
	_t.end = false
	tat_draw()

func tat_area() -> Control:   # khung vẽ tát ao (lớp vẽ _K đọc R.ai)
	return _t.get("area") if tat != null else null

func tat_draw() -> void:   # xS + jN + nút kết thúc
	if tat == null or R.ai == null:
		return
	var ai: Dictionary = R.ai
	_t.msg.text = String(ai.msg)
	_clear(_t.bag)
	if ai.got.size():
		for a in ai.got:
			_t.bag.add_child(_chip(_ic(String(a), 20), str(ai.got[a]) + " " + G.item_name(String(a)), true))
	else:
		_t.bag.add_child(_note("Chưa bắt được con nào"))
	if R._tr(ai.get("end")) and not _t.end:
		_t.end = true
		_t.row.add_child(_btn("Nướng trui mời xóm (3 con)", true, int(ai.n) >= 3, func() -> void:   # data-trui -> UK
			R.uk()))
		_t.row.add_child(_btn("Mang về hết", false, true, func() -> void:   # data-tve -> yS
			R.ys()))

func tat_close() -> void:   # ai.ov.remove()
	if tat != null:
		tat.queue_free()
		tat = null
	_t = {}

# ------------------------------------------------------------------ bảng Thi diều
func kite_open() -> void:   # dU: dựng .raceov "Thi diều"
	kite_close()
	var p := _overlay("Thi diều với tụi nhỏ trong xóm", func() -> void:   # data-kx -> AS
		R.as_close())
	kite = p[0]
	var col: VBoxContainer = p[1]
	var cv := _canvas(760.0, 330.0)
	var area: Control = cv.get_child(0)
	area.gui_input.connect(func(e) -> void:   # canvas pointerdown / pointerup
		if _down(e):
			R.kite_hold(true)
		elif _up(e):
			R.kite_hold(false))
	col.add_child(cv)
	_kt.area = area
	var msg := _lbl("", 13, 600, Color8(0x3a, 0x2a, 0x1a))   # #kMsg
	col.add_child(msg)
	_kt.msg = msg
	var b := _btn("Kéo dây", true, true, Callable())   # .rgo data-kp
	b.button_down.connect(func() -> void:
		R.kite_hold(true))
	b.button_up.connect(func() -> void:
		R.kite_hold(false))
	b.mouse_exited.connect(func() -> void:   # pointerleave
		R.kite_hold(false))
	b.pressed.connect(func() -> void:   # data-kd -> AS
		if R.zi != null and R._tr(R.zi.get("done")):
			R.as_close())
	var row := HBoxContainer.new()   # .rrow
	row.add_child(b)
	col.add_child(row)
	_kt.btn = b
	kite_draw()

func kite_area() -> Control:   # khung vẽ thi diều (lớp vẽ gU đọc R.zi)
	return _kt.get("area") if kite != null else null

func kite_draw() -> void:   # #kMsg, nút Xong
	if kite == null or R.zi == null:
		return
	_kt.msg.text = String(R.zi.msg)
	if R._tr(R.zi.get("done")):
		_kt.btn.text = "Xong"

func kite_key(e) -> void:   # wk: phím cách giữ / thả, Esc đóng
	if R.zi == null or not (e is InputEventKey):
		return
	if e.keycode == KEY_SPACE:
		R.kite_hold(e.pressed)
	elif e.keycode == KEY_ESCAPE and e.pressed:
		R.as_close()

func kite_close() -> void:   # zi.ov.remove()
	if kite != null:
		kite.queue_free()
		kite = null
	_kt = {}

