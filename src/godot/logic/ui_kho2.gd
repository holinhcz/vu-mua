extends "res://logic/ui_kbang.gd"
# (11-27) KHO trên KHUNG CHUNG (ui_kbang: khung sen, hàng tab, chip, thẻ, đáy chung), thay 3 bản chụp web cũ (kho / kho2 / kho3 / kho_sel).
#   Đầu (cố định): thanh sức chứa + "Đáng giá N" + chip đỏ "n/cap ★s" (bấm: bảng nâng kho U.khp).
#   Hàng hóa: chip lọc (2 hàng: 7 mục + nút xếp), lưới thẻ món 4 cột; đáy (cố định): Bán hết, hoặc chi tiết món đang chọn (−/+/Hết, Bán).
#   Vật liệu: lưới thẻ vật liệu; đáy: chi tiết (đang có, dùng để, cách nhận).
#   Đồ dùng: lưới bùa / phần cơm; đáy: chi tiết + nút Dùng / Ăn.
# Logic dùng lại của ui.gd: U._kho_items (lọc + xếp theo U.kh_f / U.kh_sort), U._cat, G.sell / sell_all, U.kdp.items(), U.khp.

const TABS := [["hang", "Hàng hóa"], ["vl", "Vật liệu"], ["dd", "Đồ dùng"]]
const TK := ["hang", "vl", "dd"]
const CW := 71.75    # thẻ món: 4 cột, cách 6
const CH := 98.0
const CG := 6.0
const NPAD := 5.0   # lề hai bên tên trong thẻ
const HEAD := 30.0   # dải đầu
const FOOT := 78.0   # dải chi tiết đáy (mọi tab cùng cao)
const FOOT_B := 30.0 # dải nút Bán hết
const UP := "rgb(47, 158, 68)"
const DOWN := "rgb(214, 69, 65)"
const GOLD_L := "rgb(214, 176, 104)"

var tab := "hang"
var conf := 0.0         # Bán hết: chạm lần 1 bật xác nhận 3 giây
var vl := ""            # vật liệu đang chọn
var dsel := ""          # đồ dùng đang chọn
var MATS := []          # [[id, tên, svg]] theo thứ tự ô Vật liệu
var TIC := {}           # hình tab
var KDD := {}

func _init(ui) -> void:
	super(ui)
	snapcut = false   # lưới dài: cuộn tới sát dải đáy, không cắt bỏ hàng lố
	KDD = Snap.load_snap("kdd")
	var n2: Dictionary = Snap.load_snap("kho2")["#pov"][0]
	for t in Snap.find(n2, "u2vg").get("kids", []):
		var nm := String(Snap.find(t, "u2vn").get("text", ""))
		var id: String = U._mat_id(nm)
		if id != "":
			MATS.append([id, nm, String(Snap.find(Snap.find(t, "u2vi"), "", "svg").get("svg", ""))])
	for nm2 in ["kho", "kho2"]:   # hình tab: ::before (svg trong url) của tab chưa chọn
		var seg := Snap.find(Snap.load_snap(nm2)["#pov"][0], "khseg")
		var j := 0
		for b in seg.get("kids", []):
			var bg := String(b.get("::before", {}).get("bgi", ""))
			if j < TK.size() and not TIC.has(TK[j]) and not String(b.get("cls", "")).split(" ").has("on") and bg.begins_with("url(\"data:image/svg+xml,"):
				TIC[TK[j]] = bg.substr(24, bg.length() - 26).uri_decode()
			j += 1

func open_tab(j: int) -> void:
	tab = TK[clampi(j, 0, 2)]
	if on:
		scroll = 0.0
		sig = ""
		_build()

func open() -> void:
	on = true
	scroll = 0.0
	sig = ""
	_build()

func close() -> void:
	U.kho_on = false
	conf = 0.0
	super()

func step(dt := 0.25) -> void:
	if conf > 0.0:
		conf -= dt
		if conf <= 0.0:
			sig = ""
	super(dt)

func _sig() -> String:
	var b := []
	for t in G.g.barn.keys():
		b.append(str(t) + ":" + str(G.g.barn[t]) + ":" + str(G.price(t)) + ":" + str(G.hot_x(t)))
	return JSON.stringify([tab, U.kh_f, U.kh_sort, U.kh_sel, U.kh_q, conf > 0.0, vl, dsel, b, G.g.get("mats", {}), G.kho_cap(), G.kho_star(),
		G.g.get("bua", {}), int(G.nv.Fu() / 60000.0), G.nv.tu(), G.day()])

func _tab_go(k: String) -> void:
	if tab != k:
		tab = k
		scroll = 0.0
		U.kh_sel = ""

# ------------------------------------------------------------------ dựng
func _build() -> void:
	U.kho_on = true
	sig = _sig()
	var L := TABS.map(func(x): return [x[0], x[1], false, TIC.get(x[0], "")])
	var sh := _kshell(L, tab, _tab_go)
	var n: Dictionary = sh[0]
	var vt: Dictionary = sh[1]
	_kfix(n, vt, _head(), HEAD, false)
	var r: Array
	if tab == "vl":
		r = _vl(n, vt)
	elif tab == "dd":
		r = _dd(n, vt)
	else:
		r = _hang(n, vt)
	_kmount(n, vt, float(vt.r[1]), r[0], float(r[1]))

func _head() -> Array:   # thanh sức chứa, Đáng giá, chip n/cap ★
	var cnt: int = G.kho_n()
	var cap: int = G.kho_cap()
	var worth := 0
	for t in G.g.barn.keys():
		worth += int(G.g.barn[t]) * G.price(t)
	var ct: String = G.fmt_n(cnt) + "/" + G.fmt_n(cap) + "  ★ " + str(G.kho_star())
	var cw: float = Box.text_w(ct, 12.0, 800) + 22.0
	var out := []
	var bw := XW - cw - 10.0
	var f := clampf(float(cnt) / maxf(1.0, cap), 0.0, 1.0)
	var l := int(round(f * 100.0))
	var col: String = U.khp.bar_col["full" if cnt >= cap else ("warn" if l >= 85 else "")] if U.khp != null else DOWN
	out.append(_dbx(X0, 2.0, bw, 8.0, TRACK, 4.0))
	if f > 0.0:
		out.append(_dbx(X0, 2.0, maxf(8.0, bw * f), 8.0, col, 4.0))
	var wt := "Đáng giá "
	var ww: float = Box.text_w(wt, 10.5, 600)
	out.append(_dt(X0, 13.0, ww, 15.0, wt, 10.5, 600, SUB, "left"))
	var vs: String = G.fmt_n(worth)
	var vw: float = Box.text_w(vs, 13.0, 800) + 2.0
	out.append(_dt(X0 + ww, 12.0, vw, 16.0, vs, 13.0, 800, "rgb(214, 128, 20)", "left"))
	out.append(_dick(X0 + ww + vw + 8.0, 20.0, 13.0, "coin"))
	var c := _onbtn(X0 + XW - cw, 0.0, cw, 26.0, ct, func(): if U.khp != null: U.khp.open(), true)
	c.kids[0].css["font-size"] = _cpx(12.0)
	out.append(c)
	return out

func _kcard(x: float, y: float, sel: bool, ic: Dictionary, nm: String, cnt: String, cnt_hi: bool, low: Array, dim := false) -> Array:   # thẻ món chung 3 tab: hình 44, tên (dài thì 2 dòng), dòng giá (Hàng hóa) sát đáy
	var c := _chip(x, y, CW, CH, "got" if sel else "fut")
	var col := BROWN if not dim else SUB
	var ny := y + 50.0 if low.size() else y + 58.0   # không dòng giá: hình + tên dời xuống giữa thẻ
	if not low.is_empty():
		Snap._move(ic, Vector2(0, -6.0))
	var tw := CW - 2.0 * NPAD   # tên chừa lề hai bên
	var L2 := [nm] if Box.text_w(nm, 11.0, 700) <= tw else _wrap(nm, 11.0, 700, tw)   # dài thì xuống dòng, giữ cỡ chữ
	c.kids = [ic]
	if L2.size() == 1:
		c.kids.append(_dt(x + NPAD, ny, tw, 16.0, nm, 11.0, 700, col))
	else:
		c.kids.append(_dt(x + NPAD, ny - 3.0, tw, 14.0, String(L2[0]), 11.0, 700, col))
		c.kids.append(_dt(x + NPAD, ny + 11.0, tw, 14.0, _fitw(" ".join(L2.slice(1)), 11.0, 700, tw), 11.0, 700, col))
	c.kids.append_array(low)
	if cnt != "":
		c.kids.append(_badge(x + CW - 4.0, y + 4.0, cnt, GREEN if cnt_hi else "rgb(236, 224, 196)", "rgb(255, 255, 255)" if cnt_hi else SUB, true))
	return [c]

func _badge(x: float, y: float, t: String, bg: String, col: String, right := false) -> Dictionary:   # nhãn số nhỏ (góc thẻ): chữ nằm trong hộp (không bị nền đè)
	var bw: float = Box.text_w(t, 9.0, 800) + 8.0
	var bx := x - bw if right else x
	var b := _dbx(bx, y, bw, 14.0, bg, 4.0)
	b.kids = [_dt(bx, y, bw, 14.0, t, 9.0, 800, col)]
	return b

func _kgrid(y: float, items: Array) -> Array:   # items: [card fn(x, y) -> Array]; trả [khối, đáy]
	var out := []
	for i in items.size():
		var x := X0 + (i % 4) * (CW + CG)
		var yy := y + (i / 4) * (CH + CG)
		out.append_array(items[i].call(x, yy))
	var rows := int(ceil(items.size() / 4.0))
	return [out, y + rows * (CH + CG) - CG]

func _sep(y: float) -> Dictionary:   # vạch vàng ngăn dải đáy
	return _dbx(X0, y, XW, 1.5, GOLD_L, 0.0)

func _detail(svg: String, ic_id: String, nm: String, sub: String, sub_col: String, rows: Array, btn: String, act, ok := true) -> Array:   # dải chi tiết đáy chung 3 tab (y từ 0, cao FOOT)
	var out := [_sep(0.0)]
	var ic: Dictionary = _icn(X0 + 17.0, 24.0, 28.0, ic_id) if ic_id != "" else _dic(X0 + 3.0, 10.0, 28.0, svg)
	var fr := _dbx(X0, 7.0, 34.0, 34.0, "rgb(255, 252, 244)", 6.0, "1px solid " + GOLD_L)
	fr.kids = [ic]   # hình nằm trong khung (không bị nền khung đè)
	out.append(fr)
	var bw := 0.0
	if btn != "":
		bw = maxf(64.0, Box.text_w(btn, 11.0, 800) + 24.0)
		out.append(_btn(X0 + XW - bw, 10.0, bw, 28.0, btn, act if ok else null, "go" if ok else "off"))
	var tw := XW - 42.0 - (bw + 8.0 if bw > 0.0 else 0.0)
	out.append(_dt(X0 + 42.0, 7.0, tw, 17.0, _fitw(nm, 13.0, 800, tw), 13.0, 800, BROWN, "left"))
	out.append(_dt(X0 + 42.0, 25.0, tw, 14.0, _fitw(sub, 10.5, 700, tw), 10.5, 700, sub_col, "left"))
	var y := 48.0
	for r in rows:
		out.append(_dt(X0, y, XW, 14.0, _fitw(String(r), 10.5, 600, XW), 10.5, 600, SUB, "left"))
		y += 15.0
	return out

# ------------------------------------------------------------------ Hàng hóa
func _hang(n: Dictionary, vt: Dictionary) -> Array:
	var s: String = U.kh_sel
	if s != "" and int(G.g.barn.get(s, 0)) <= 0:
		s = ""
		U.kh_sel = ""
	var e: Array = U._kho_items()
	if s != "":
		_kfix(n, vt, _hdet(s), FOOT, true)
	else:
		_kfix(n, vt, _sellall(e), FOOT_B, true)
	var out := []
	var chips := []   # chip lọc: 7 mục + nút xếp, 2 hàng x 4, đứng yên dưới dải đầu (không cuộn theo lưới)
	var F: Array = U.KH_CAT.duplicate()
	F.append(["*sort", "Sắp xếp"])
	var fw := (XW - 3.0 * CG) / 4.0
	for i in F.size():
		var k := String(F[i][0])
		var x := X0 + (i % 4) * (fw + CG)
		var y := (i / 4) * (24.0 + CG)
		var t := String(F[i][1])
		if k == "*sort":
			var c := _chip(x, y, fw, 24.0, "tre")
			c.kids = [_dt(x, y, fw, 24.0, _fitw(t, 10.5, 800, fw - 6.0), 10.5, 800, BROWN)]
			c.act = _sort_next
			chips.append(c)
		elif k == U.kh_f:
			var b := _onbtn(x, y, fw, 24.0, t, null)
			b.kids[0].css["font-size"] = _cpx(11.0)
			chips.append(b)
		else:
			var c2 := _chip(x, y, fw, 24.0, "fut")
			c2.kids = [_dt(x, y, fw, 24.0, t, 11.0, 800, BROWN)]
			var kk := k
			c2.act = func():
				U.kh_f = kk
				U.kh_sel = ""
				scroll = 0.0
			chips.append(c2)
	_kfix(n, vt, chips, 2.0 * 24.0 + CG, false)
	var gy := 0.0
	if e.is_empty():
		out.append(_dt(X0, gy + 10.0, XW, 16.0, "Mục này trống." if G.kho_n() > 0 else "Kho đang trống.", 11.0, 600, SUB))
		return [out, gy + 30.0]
	var items := []
	for t in e:
		var tt: String = t
		items.append(func(x: float, y: float) -> Array: return _hcard(tt, x, y))
	var g := _kgrid(gy, items)
	out.append_array(g[0])
	return [out, float(g[1]) + 2.0]

func _hcard(t: String, x: float, y: float) -> Array:
	var p: int = G.price(t)
	var r: float = G.rel(t)
	var hx: float = G.hot_x(t)
	var ps: String = G.fmt_n(p)
	var pw: float = Box.text_w(ps, 11.0, 800)
	var ar := "▲" if r > 1.08 else ("▼" if r < 0.92 else "")
	var tw := pw + 15.0 + (12.0 if ar != "" else 0.0)
	var px := x + (CW - tw) * 0.5
	var low := [_dt(px, y + CH - 19.0, pw + 1.0, 15.0, ps, 11.0, 800, "rgb(214, 128, 20)", "left"), _dick(px + pw + 8.0, y + CH - 11.5, 12.0, "coin")]
	if ar != "":
		low.append(_dt(px + pw + 15.0, y + CH - 19.0, 12.0, 15.0, ar, 9.0, 800, UP if ar == "▲" else DOWN, "left"))
	var cs := _kcard(x, y, t == U.kh_sel, _icn(x + CW * 0.5, y + 30.0, 44.0, t), String(G.item(t).get("name", t)), G.fmt_n(int(G.g.barn[t])), t == U.kh_sel, low)
	if hx > 1.0:
		var hs: String = "×" + U._xn(hx)
		cs[0].kids.append(_badge(x + 4.0, y + 4.0, hs, DOWN, "rgb(255, 255, 255)"))
	var tt := t
	cs[0].act = func():
		U.kh_sel = "" if U.kh_sel == tt else tt
		U.kh_q = 1
	return cs

func _sort_name() -> String:
	for q in U.KH_SORT:
		if q[0] == U.kh_sort:
			return String(q[1])
	return ""

func _sort_next() -> void:
	var i := 0
	for j in U.KH_SORT.size():
		if U.KH_SORT[j][0] == U.kh_sort:
			i = j
	U.kh_sort = String(U.KH_SORT[(i + 1) % U.KH_SORT.size()][0])
	G.toast.emit("Xếp: " + _sort_name())

func _sellall(e: Array) -> Array:
	var n := 0
	var v := 0
	for t in e:
		var c := int(G.g.barn[t])
		var keep := mini(G.LY, c) if G.D.crops.has(t) else 0
		v += G.sell_value(t, c - keep)
		n += c - keep
	var t: String = "Chạm lần nữa để bán hết" if conf > 0.0 else (("Bán hết" + ("" if U.kh_f == "all" else " mục " + U._cat_name(U.kh_f).to_lower()) + " +" + G.fmt_n(v) + " xu") if n > 0 else ("Mục này trống" if G.kho_n() > 0 else "Kho đang trống"))
	var bw: float = maxf(160.0, Box.text_w(t, 12.0, 800) + 34.0)
	var b := _btn(X0 + (XW - bw) * 0.5, 0.0, bw, FOOT_B, t, _sell_all if n > 0 else null, "go" if n > 0 else "off")
	b.kids[0].css["font-size"] = _cpx(12.0)
	return [b]

func _sell_all() -> void:
	if conf <= 0.0:
		conf = 3.0
		return
	conf = 0.0
	G.sell_all(U._kho_items())

func _hdet(s: String) -> Array:   # chi tiết món đang chọn: hình, tên · có N, giá/cái, − q + Hết, Bán q · +X, lời khuyên giữ hạt
	var h := int(G.g.barn.get(s, 0))
	U.kh_q = clampi(U.kh_q, 1, maxi(1, h))
	var M: int = U.kh_q
	var hx: float = G.hot_x(s)
	var r: float = G.rel(s)
	var sub: String = G.fmt_n(G.price(s)) + " xu/cái" + (" ▲" if r > 1.08 else (" ▼" if r < 0.92 else "")) + ((" · được giá ×" + U._xn(hx) + " hôm nay") if hx > 1.0 else "")
	var R := ""
	if G.w_all != null and G.w_all.WKU != null:
		R = G.w_all.WKU.det_hint(s, M)
	if R != "":
		sub += " · " + R
	var out := _detail("", s, String(G.item(s).get("name", s)) + " · có " + G.fmt_n(h), sub, UP if r > 1.08 else (DOWN if r < 0.92 else SUB), [], "", null)
	# hàng bán: − q + Hết ... Bán
	var y := 48.0
	var bs := 26.0
	out.append(_btn(X0, y, bs, 24.0, "−", (func(): U.kh_q = maxi(1, U.kh_q - 1)) if M > 1 else null, "plain" if M > 1 else "off"))
	out.append(_dt(X0 + bs, y, 32.0, 24.0, G.fmt_n(M), 12.0, 800, BROWN))
	out.append(_btn(X0 + bs + 32.0, y, bs, 24.0, "+", (func(): U.kh_q = mini(h, U.kh_q + 1)) if M < h else null, "plain" if M < h else "off"))
	out.append(_btn(X0 + 2.0 * bs + 38.0, y, 40.0, 24.0, "Hết", func(): U.kh_q = h, "red"))
	var st: String = "Bán " + G.fmt_n(M) + " · +" + G.fmt_n(G.sell_value(s, M)) + " xu"
	var sw := XW - (2.0 * bs + 38.0 + 40.0 + 8.0)
	out.append(_btn(X0 + XW - sw, y - 2.0, sw, 28.0, st, _sell_one))
	return out

func _sell_one() -> void:
	var t: String = U.kh_sel
	if t == "":
		return
	G.sell(t, U.kh_q)
	if int(G.g.barn.get(t, 0)) <= 0:
		U.kh_sel = ""

# ------------------------------------------------------------------ Vật liệu
func _vl(n: Dictionary, vt: Dictionary) -> Array:
	var mats: Dictionary = G.g.get("mats", {})
	if vl == "" and MATS.size():
		vl = String(MATS[0][0])
	var m: Array = []
	for q in MATS:
		if q[0] == vl:
			m = q
	if m.size():
		var mid := String(m[0])
		var pc := str(int(round(float(G.D.drop.get("rate", 0.0)) * 100.0))) + "%"
		var cau: bool = G.D.drop.nhom.cau.has(mid)
		var c := int(mats.get(mid, 0))
		_kfix(n, vt, _detail(String(m[2]), "", String(m[1]), "Đang có " + str(c), GREEN if c > 0 else SUB,
			["Dùng để: " + String(G.MAT_DUNG.get(String(G.D.mat[mid].get("g", "")), "nâng sao")),
			"Cách nhận: " + ("Câu cá, thăm lờ, giăng câu: " if cau else "Làm việc gì cũng có thể rơi: ") + pc + (" (hoặc nung ở lò gạch)." if mid == "gach" else ".")], "", null), FOOT, true)
	var items := []
	for q in MATS:
		var qq: Array = q
		items.append(func(x: float, y: float) -> Array:
			var c2 := int(mats.get(String(qq[0]), 0))
			var cs := _kcard(x, y, vl == qq[0], _dic(x + (CW - 44.0) * 0.5, y + 10.0, 44.0, String(qq[2]), 1.0 if c2 > 0 else 0.4), String(qq[1]), str(c2), vl == qq[0], [], c2 <= 0)
			var kk := String(qq[0])
			cs[0].act = func(): vl = kk
			return cs)
	var g := _kgrid(0.0, items)
	return [g[0], float(g[1]) + 2.0]

# ------------------------------------------------------------------ Đồ dùng
func _dd(n: Dictionary, vt: Dictionary) -> Array:
	var L: Array = U.kdp.items()
	if L.is_empty():
		return [[_dt(X0, 10.0, XW, 16.0, "Chưa có đồ dùng.", 11.0, 700, BROWN),
			_dt(X0, 30.0, XW, 14.0, "Bùa +50% EXP và phần cơm hồi sức có từ điểm danh, nhiệm vụ, sự kiện.", 10.0, 600, SUB)], 50.0]
	if not L.any(func(x): return x.k == dsel):
		dsel = String(L[0].k)
	var E: Dictionary = L.filter(func(x): return x.k == dsel)[0]
	var run := float(E.run) > 0.0
	var ek: String = E.k
	var eh: int = int(E.h)
	var go := func():
		if ek == "com":
			G.nv.j8()
		elif ek.begins_with("b"):
			G.nv.LF(eh)
		G.mark()
		U.bfp.sync(true)
	var dl := _wrap(String(E.d), 10.5, 600, XW)
	if run:
		dl.append("⏱ Còn " + U.kdp.MA(float(E.run)))
	_kfix(n, vt, _detail(_ddsvg(E), "", String(E.n), (("Có ×" + str(E.c)) + (" · đang chạy" if run else "")) if int(E.c) > 0 else "Đang dùng", GREEN, dl.slice(0, 2), String(E.btn), go), FOOT, true)
	var items := []
	for x0 in L:
		var it: Dictionary = x0
		items.append(func(x: float, y: float) -> Array:
			var cs := _kcard(x, y, it.k == dsel, _dic(x + (CW - 44.0) * 0.5, y + 10.0, 44.0, _ddsvg(it), 1.0 if int(it.c) > 0 else 0.4), String(it.n), str(it.c) if int(it.c) > 0 else "", it.k == dsel, [])
			var kk := String(it.k)
			cs[0].act = func(): dsel = kk
			return cs)
	var g := _kgrid(0.0, items)
	return [g[0], float(g[1]) + 2.0]

func _ddsvg(it: Dictionary) -> String:
	return String(KDD.ic_com if it.art == "com" else KDD.ic_bua)
