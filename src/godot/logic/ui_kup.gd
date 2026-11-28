extends "res://logic/ui_kbang.gd"
# (11-28) NÂNG SAO KHO (m$, Re.pop u2gold) + NÂNG SỚM bằng sen đỏ (zF .nglkov) trên khung chung (ui_kbang, khung co vừa nội dung),
#   thay hộp chụp web cũ (kup_* / k3_* / k2_no / k_hard / kns_*: hoa sen đè nút, chữ "nâng sớm bằng 🪷" vỡ dòng).
#   Kiểu "up": 10 sao, đang chứa, "Lên N★ · chứa M món", ô giá (xu + ván / đinh / gạch có / cần), dòng cấp, nút.
#   Kiểu "ns": nâng sớm: lý do, ô [cấp mở sớm] [vật liệu thiếu] [xu thiếu], sen đỏ đang có, nút Nâng ngay / Nạp thêm.
#   Luật ở game.gd (kho_need, can_pay, early_ok, kho_early_cost, early_cost, early_go); nút Nâng: ui_kho.up().

var K              # ui_kho.gd
var kind := "up"
var sp := {}       # hộp nâng sớm: {t, nd, fee, extra, go, done}
const CHW := 70.0  # ô giá
const CHH := 34.0
const PEARL_C := "rgb(196, 44, 60)"

func _init(ui, k) -> void:
	super(ui)
	K = k
	fit = true

func open_up() -> void:
	kind = "up"
	_go()

func open_kf(n: int, cap: int) -> void:   # Kho đầy (lL .kfov)
	kind = "kf"
	sp = {"n": n, "cap": cap}
	_go()

func open_ns(s: Dictionary) -> void:
	kind = "ns"
	sp = s
	var hd = sp.get("hide")
	if hd is Control and is_instance_valid(hd):
		hd.visible = false   # hộp gọi (vd nâng sao ô ruộng) ẩn khi hộp nâng sớm mở, hiện lại khi đóng
	_go()

func close() -> void:
	var hd = sp.get("hide") if kind == "ns" else null
	super()
	if hd is Control and is_instance_valid(hd):
		hd.visible = true

func _go() -> void:
	if not on:
		for p in U._pans():
			if p != null and p != self and p.on and p != U.khop:
				p.close()
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	return kind + "|" + K._sig()

func _build() -> void:
	sig = _sig()
	var sh := _kshell([], "", func(_k): pass)
	var out := []
	var y := 8.0 if kind == "up" else 4.0
	if kind == "up":
		y = _up(out, y)
	elif kind == "kf":
		y = _kf(out, y)
	else:
		y = _ns(out, y)
	_kmount(sh[0], sh[1], sh[2], out, y)

func _center(out: Array, y: float, t: String, fs: float, fw: int, col: String) -> float:
	var p := _para(X0, y, XW, t, fs, fw, col, fs + 5.0)
	for k in p[0]:
		k.css["text-align"] = "center"
	out.append_array(p[0])
	return y + float(p[1])

func _cell(x: float, y: float, w: float, ic: Dictionary, txt: String, ok: bool, sub := "") -> Dictionary:   # (cao CHH, có chữ phụ thì +14)   # ô giá: hình + có/cần (xanh đủ, đỏ thiếu)
	var c := _chip(x, y, w, CHH + (14.0 if sub != "" else 0.0), "got" if ok else "fut")
	c.kids = [ic, _dt(x + 30.0, y, w - 32.0, CHH, txt, 12.0, 800, GREEN if ok else DOWN_C, "left")]
	if sub != "":
		c.kids.append(_dt(x + 2.0, y + CHH - 4.0, w - 4.0, 14.0, _fitw(sub, 10.5, 600, w - 4.0), 10.5, 600, SUB))
	return c

func _row(out: Array, y: float, cells: Array, w := CHW) -> float:   # hàng ô canh giữa, cách 6; không đủ chỗ thì thu đều
	var n := cells.size()
	var cw := minf(w, (XW - 6.0 * (n - 1)) / maxf(1.0, n))
	var tot := cw * n + 6.0 * (n - 1)
	var x := X0 + (XW - tot) * 0.5
	var h := 0.0
	for c in cells:
		var k: Dictionary = c.call(x, cw, y)   # y lúc xếp hàng (lambda chụp y lúc tạo: sai khi có dòng chữ chen trước)
		out.append(k)
		h = maxf(h, float(k.r[3]))
		x += cw + 6.0
	return y + h

func _pbtn(y: float, t: String, n: int, cb, red := false) -> Dictionary:   # nút chữ + [sen đỏ] số, canh giữa
	var b := _onbtn(X0, y, XW, 34.0, "", cb, red)
	var ri: Array = _rowi(0.0, 0.0, 34.0, [t, "i:pearl", str(n)], 14.0, 800, "rgb(255, 255, 255)")
	b.kids = []
	var sx := X0 + (XW - float(ri[1])) * 0.5
	for k in ri[0]:
		Snap._move(k, Vector2(sx, y))
		b.kids.append(k)
	return b

const DOWN_C := "rgb(214, 69, 65)"

# ------------------------------------------------------------------ nâng sao kho
func _up(out: Array, y: float) -> float:
	var a: int = G.kho_star()
	var ss := 22.0
	var sx := X0 + (XW - ss * 10.0 - 3.0 * 9.0) * 0.5
	for j in 10:
		out.append(_dic(sx + j * (ss + 3.0), y, ss, K.star_on if j < a else K.star_off))
	y += ss + GG
	y = _center(out, y, "Đang chứa tối đa " + str(G.kho_cap()) + " món", 12.0, 600, SUB) + 6.0
	if a >= 10:
		y = _center(out, y, "Kho đã tối đa 10★", 14.0, 800, BROWN) + GG
		return y - GG
	var nd: Dictionary = G.kho_need(a + 1)
	var lock: bool = G.lv() < int(nd.lv)
	var early: bool = lock and G.early_ok(int(nd.lv))
	y = _center(out, y, "Lên " + str(a + 1) + "★ · chứa " + str(G.KHO_VP[a + 1] + int(G.g.get("khoB", 0))) + " món", 14.0, 800, BROWN) + GG
	var cells := [func(x, w, y): return _cell(x, y, w, _dick(x + 16.0, y + CHH * 0.5, 20.0, "coin"), G.fmt_n(int(nd.xu)), int(G.g.coins) >= int(nd.xu))]
	for m in nd.m:
		var id: String = m[0]
		var need := int(m[1])
		var hv: int = G.mat_n(id)
		cells.append(func(x, w, y): return _cell(x, y, w, _dic(x + 5.0, y + 6.0, 22.0, String(K.mat_svg.get(id, ""))), str(hv) + "/" + str(need), hv >= need))
	y = _row(out, y, cells) + GG
	if lock:
		y = _center(out, y, "Cần cấp " + str(nd.lv) + " · bạn đang cấp " + str(G.lv()) + ("" if early else " · chỉ nâng sớm khi thiếu tối đa " + str(G.KHO_SA) + " cấp"), 12.0, 600, SUB) + 6.0
	if early:
		out.append(_pbtn(y, "Nâng sớm", G.kho_early_cost(nd), K.up))
	elif lock:
		out.append(_btn(X0, y, XW, 34.0, "Cần cấp " + str(nd.lv), null, "off"))
	else:
		var bt := _onbtn(X0, y, XW, 34.0, "Nâng kho lên " + str(a + 1) + "★", K.up)
		bt.kids[0].css["font-size"] = _cpx(14.0)
		out.append(bt)
	return y + 34.0

# ------------------------------------------------------------------ nâng sớm bằng sen đỏ
func _ns(out: Array, y: float) -> float:
	var nd: Dictionary = sp.nd
	var fee: int = int(sp.fee)
	var r: int = G.early_cost(nd, fee)
	var lack := []
	for m in nd.m:
		var d: int = int(m[1]) - G.mat_n(m[0])
		if d > 0:
			lack.append([m[0], d])
	var xe := maxi(0, int(nd.xu) - int(G.g.coins))
	var have := int(G.g.get("ngoc", 0))
	var rich := have >= r
	out.append_array(_hd(y + 5.0, "Nâng sớm: " + String(sp.t)))
	y += 26.0 + 6.0
	var ps := "Bạn đang cấp " + str(G.lv()) + ", mức này cần cấp " + str(nd.lv) + "." + String(sp.get("extra", "")) + " Dùng sen đỏ để mở khóa ngay" + (", bù luôn phần còn thiếu" if not lack.is_empty() or xe > 0 else "") + "."
	var p := _para(X0, y, XW, ps, 12.0, 600, SUB, 16.0)
	out.append_array(p[0])
	y += float(p[1]) + GG
	var el: int = G.early_lv(int(nd.lv))
	var lv := _chip(X0, y, XW, CHH, "now")   # dòng mở khóa sớm: cấp + số cấp + sen đỏ
	var ri: Array = _rowi(0.0, 0.0, CHH, ["Mở khóa sớm " + str(el) + " cấp (tới cấp " + str(nd.lv) + ") · " + str(fee), "i:pearl"], 12.0, 800, BROWN)
	lv.kids = []
	var lx := X0 + (XW - float(ri[1])) * 0.5
	for k in ri[0]:
		Snap._move(k, Vector2(lx, y))
		lv.kids.append(k)
	out.append(lv)
	y += CHH + 6.0
	var cells := []
	for q in lack:
		var id: String = q[0]
		var n := int(q[1])
		cells.append(func(x, w, y): return _cell(x, y, w, _dic(x + 5.0, y + 6.0, 22.0, String(K.mat_svg.get(id, ""))), "×" + str(n), false, G.item_name(id)))
	if xe > 0:
		cells.append(func(x, w, y): return _cell(x, y, w, _dick(x + 16.0, y + CHH * 0.5, 20.0, "coin"), "×" + G.fmt_n(xe), false, "xu"))
	if cells.size():
		y = _center(out, y, "Bù luôn phần còn thiếu:", 12.0, 600, SUB) + 8.0
		y = _row(out, y, cells, 84.0) + GG
	else:
		y += GG - 6.0
	y = _center(out, y, "Đang có " + G.fmt_n(have) + " sen đỏ" + ("" if rich else " · còn thiếu " + str(r - have)), 12.0, 700, BROWN if rich else DOWN_C) + 6.0
	var go: Callable = sp.go
	var done: Callable = sp.get("done", func(): pass)
	if rich:
		out.append(_pbtn(y, "Nâng ngay", r, func():
			close()
			G.early_go(nd, fee, go)
			done.call()))
	else:
		out.append(_pbtn(y, "Nạp thêm sen đỏ", r, func():
			close()
			U.nap_open(), true))
	return y + 34.0

# ------------------------------------------------------------------ kho đầy
const KHO_IC := "res://ui/img/cg/basket.webp"
func _kf(out: Array, y: float) -> float:
	var a: int = G.kho_star()
	out.append(_dick(X0 + XW * 0.5, y + 22.0, 40.0, "crate"))
	y += 46.0 + 6.0
	y = _center(out, y, "Kho đầy rồi!", 17.0, 800, BROWN) + 6.0
	y = _center(out, y, "Đang chứa " + G.fmt_n(int(sp.n)) + "/" + str(int(sp.cap)) + " món. Bán bớt hàng hoặc nâng kho để chứa thêm.", 12.0, 600, SUB) + GG
	if a < 10:
		var nd: Dictionary = G.kho_need(a + 1)
		var lock: bool = G.lv() < int(nd.lv)
		if not lock or G.early_ok(int(nd.lv)):
			var bt := _onbtn(X0, y, XW, 34.0, ("Nâng kho sớm lên " if lock else "Nâng kho lên ") + str(a + 1) + "★", func():
				close()
				K.open())
			bt.kids[0].css["font-size"] = _cpx(14.0)
			out.append(bt)
			y += 34.0 + 6.0
	var w := (XW - 6.0) * 0.5
	out.append(_b14(X0, y, w, 32.0, "Mở kho", func():
		close()
		U.kho_open(), "plain"))
	out.append(_b14(X0 + w + 6.0, y, w, 32.0, "Để sau", close, "plain"))
	return y + 32.0

func _b14(x: float, y: float, w: float, h: float, t: String, cb, kind2 := "go") -> Dictionary:   # nút chung, chữ 14
	var b := _btn(x, y, w, h, t, cb, kind2)
	if b.kids.size() and b.kids[0] is Dictionary and b.kids[0].has("css"):
		b.kids[0].css["font-size"] = _cpx(14.0)
	return b
