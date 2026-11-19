extends "res://logic/ui_hx.gd"
# ĐIỂM DANH (aA / ov bản web, nút Điểm danh ở cột sự kiện): hộp khung tre ui_hx.gd, 2 tab
#  - "Quà 7 ngày đầu" (chỉ khi chưa nhận hết): lưới 7 thẻ quà, thẻ hôm nay có nút Nhận.
#  - "Điểm danh tháng": 4 mốc 7/14/21/28 ngày, số ngày đã điểm danh, lịch tháng (chạm hôm nay / ngày lỡ để điểm danh bù).
# Mẫu: ui/snap/dd.json (chụp bản web, tọa độ tính từ đỉnh thân / đỉnh hàng tab). Luật ở w_ev.gd.
# (bản 385) Khung cỡ Kho hàng (#pov .pwin: x 0..338, y 85,4..610): mẫu dựng ở hộp giữa màn rồi nới ngang (_wx) và kéo cao (_hx).

var E          # w_ev.gd
var D := {}
var cd := "7"  # tab đang mở


func _init(ui, wev) -> void:
	super(ui)
	E = wev
	D = Snap.load_snap("dd")

func open(t := "") -> void:   # aA
	if t != "":
		cd = t
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	return JSON.stringify([cd, E.Sp(), E.ld(), G.g.get("ngoc", 0)])

func _tab_go(k: String) -> void:
	if cd != k:
		cd = k
		scroll = 0.0

func _build() -> void:
	if not E.N8() and cd == "7":
		cd = "m"
	sig = _sig()
	var ov := _cl(D.ov)
	var tabs := _find(ov, "ngtabs")
	var ty := float(tabs.r[1])
	var bd := _find(ov, "hxbody")
	var by := float(bd.r[1])
	_hb = float(bd.r[3]) + KH - float(_find(ov, "hxwrap").r[3])
	var mo: int = E.q8() % 100
	help = ["Điểm danh", "Vào làng mỗi ngày nhận quà · tháng " + str(mo) + "/" + str(E.q8() / 100)]
	# hàng tab: Quà 7 ngày đầu (chấm f), Điểm danh tháng (chấm s)
	var f: int = 1 if E.Cp() else 0
	var s: int = (1 if E.q9() else 0) + E.nF()
	var L: Array = (D.tab7 if cd == "7" else D.tabm) if E.N8() else D.tab1
	var keys := ["7", "m"] if E.N8() else ["m"]
	var tk := []
	for i in L.size():
		var b := _cl(L[i])
		Snap._move(b, Vector2(0, ty))
		var c: int = f if keys[i] == "7" else s
		for k in b.kids:
			if k.tag == "em":
				k.text = str(c)
		if c <= 0:
			b.kids = b.kids.filter(func(k): return k.tag != "em")
		b.act = _tab_go.bind(keys[i])
		tk.append(b)
	tabs.kids = tk
	var kids: Array
	var ch: float
	if cd == "7":
		var r := _tab7()
		kids = r[0]
		ch = r[1]
	else:
		var r := _tabm()
		kids = r[0]
		ch = r[1]
	for k in kids:
		Snap._move(k, Vector2(0, by))
	_hx(ov, kids, ch)

# ------------------------------------------------------------------ khối dựng tay (bản 386): tọa độ cuối (khung Kho), y tính từ đỉnh thân
const X0 := 18.0      # mép trái nội dung thân (khung Kho, lề trong 9)
const XW := 302.0     # rộng nội dung
const BROWN := "rgb(74, 52, 20)"
const SUB := "rgb(128, 98, 58)"
const GOLD := "rgb(222, 160, 40)"
const GREEN := "rgb(46, 150, 80)"
var _hb := 455.0      # cao thân (tính ở _build theo khung Kho)

func _dz() -> float:
	return float(D.cal.kids[0].get("z", 0.75))

func _cpx(v: float) -> String:   # đơn vị số đo -> px css của mẫu (nhân z lúc vẽ)
	return str(snappedf(v / _dz(), 0.01)) + "px"

func _dt(x: float, y: float, w: float, h: float, s: String, fs := 11.0, fw := 700, col := BROWN, al := "center") -> Dictionary:
	var n := _cl(D.cal.kids[0])
	n.erase("tr")
	n.kids = []
	n.r = [x, y, w, h]
	n.text = s
	n.css = n.css.duplicate()
	n.css["font-size"] = _cpx(fs)
	n.css["font-weight"] = str(fw)
	n.css["color"] = col
	n.css["text-align"] = al
	n.css["line-height"] = _cpx(h)
	n.css["white-space"] = "nowrap"
	for k in ["padding-top", "padding-bottom", "padding-left", "padding-right"]:
		n.css[k] = "0px"
	return n

func _dcard(x: float, y: float, w: float, h: float) -> Dictionary:   # thẻ kem như các thẻ trong Kho
	var n := _cl(D.ddsum)
	n.erase("text")
	n.erase("tr")
	n.kids = []
	n.r = [x, y, w, h]
	return n

func _dbx(x: float, y: float, w: float, h: float, bg: String, rad := 8.0, bd := "", sh := "none") -> Dictionary:
	var n := _cl(D.cell.fut)
	n.kids = []
	n.r = [x, y, w, h]
	n.css = n.css.duplicate()
	n.css["background-color"] = bg
	n.css["background-image"] = "none"
	n.css["border-radius"] = _cpx(rad)
	n.css["box-shadow"] = sh
	for sd in ["top", "right", "bottom", "left"]:
		n.css["border-" + sd] = bd if bd != "" else "0px none rgb(0, 0, 0)"
	return n

func _dic(x: float, y: float, s: float, svg: String, op := 1.0) -> Dictionary:
	var n := _cl(D.cell.fut.kids[1])
	n.r = [x, y, s, s]
	n.svg = svg
	n.css = n.css.duplicate()
	n.css["opacity"] = str(op)
	return n

func _dtick(x: float, y: float, s := 11.0) -> Dictionary:   # dấu ✓ = ảnh tick chung (Snap)
	var n := _cl(D.cell.got.kids[2])
	n.erase("tr")
	n.r = [x, y, s, s]
	return n

func _dbtn(x: float, y: float, w: float, h: float, s: String, cb: Callable) -> Dictionary:   # nút vàng (mẫu Nhận)
	var n := _cl(D.i7)
	n.erase("tr")
	n.r = [x, y, w, h]
	n.text = s
	n.css = n.css.duplicate()
	n.css["line-height"] = _cpx(h)
	n.css["font-size"] = _cpx(11.5)
	n.css["padding-left"] = "0px"
	n.css["padding-right"] = "0px"
	n.act = cb
	return n

func _dsay(s: String) -> void:
	G.toast.emit(s)

# ------------------------------------------------------------------ tab Quà 7 ngày đầu (bản 386): lưới 4 + 3, ô ngày 7 rộng gấp đôi
const T7 := [["1.000 xu"], ["5 sen đỏ"], ["Gói", "vật liệu"], ["Xe đạp"], ["10 sen đỏ", "+ bùa EXP"], ["Vật liệu", "+ 3 phần cơm"], ["Xuồng ba lá", "+ 20 sen đỏ"]]

func _tab7() -> Array:
	var p: int = int(E.Sp().l7.get("n", 0))
	var d: bool = E.Cp()
	var out := []
	var g := 6.0
	var cw := (XW - g * 3.0) / 4.0
	var fh := 44.0
	var rh := (_hb - 8.0 - g - g - fh - 10.0) * 0.5
	var y1 := 8.0
	var y2 := y1 + rh + g
	for i in 7:
		var row := 0 if i < 4 else 1
		var col := i if i < 4 else i - 4
		var x := X0 + col * (cw + g)
		var y := y1 if row == 0 else y2
		var w := cw * 2.0 + g if i == 6 else cw
		var got := i < p
		var now := d and i == p
		var bg := "rgb(232, 245, 226)" if got else ("rgb(255, 255, 255)" if now else "rgb(255, 250, 240)")
		var bd := "1.5px solid " + GOLD if now else ("1.33333px solid rgb(214, 84, 52)" if i == 6 else "1px solid rgb(225, 208, 170)")
		var c := _dbx(x, y, w, rh, bg, 12.0, bd, "rgba(222, 160, 40, 0.35) 0px 0px 0px 2px" if now else "none")
		var op := 0.55 if got else (1.0 if now else 0.8)
		var s := minf(w - 14.0, rh * 0.5) if i == 6 else minf(cw - 10.0, rh * 0.42)
		var L: Array = T7[i]
		var foot := 30.0   # chỗ nút Nhận / dấu tích dưới đáy ô
		var bh := 16.0 + 8.0 + s + 8.0 + L.size() * 15.0
		var top := y + maxf(6.0, (rh - foot - bh) * 0.5)
		var kids := [_dt(x, top, w, 14.0, "Ngày " + str(i + 1), 11.0, 800, GOLD if now else SUB)]
		var iy := top + 22.0
		kids.append(_dic(x + (w - s) * 0.5, iy, s, String(D.dd7.kids[i].kids[1].svg), op))
		var ty := iy + s + 8.0
		for ln in L:
			var sm: bool = String(ln).begins_with("+")
			kids.append(_dt(x + 2.0, ty, w - 4.0, 15.0, String(ln), 11.0 if sm else 12.5, 600 if sm else 800, SUB if got or sm else BROWN))
			ty += 15.0
		if got:
			kids.append(_dtick(x + (w - 18.0) * 0.5, y + rh - 26.0, 18.0))
		elif now:
			kids.append(_dbtn(x + (w - 58.0) * 0.5, y + rh - 29.0, 58.0, 22.0, "Nhận", E.tF))
			c.act = E.tF
		c.kids = kids
		out.append(c)
	var fy := y2 + rh + g + 4.0
	var fc := _dcard(X0, fy, XW, fh)
	var q := p + 1 if not d else p + 1
	var ft := ""
	if d:
		ft = "Hôm nay nhận quà ngày " + str(p + 1) + ": " + " ".join(T7[p])
	elif p < 7:
		ft = "Mai nhận quà ngày " + str(q) + ": " + " ".join(T7[p])
	fc.kids = [_dt(X0 + 10.0, fy, XW - 20.0, fh, ft, 12.0, 700, BROWN)]
	out.append(fc)
	return [out, fy + fh + 10.0]

# ------------------------------------------------------------------ tab Điểm danh tháng (bản 386)
const R8S := ["1.500 xu", "5 sen đỏ", "Vật liệu lớn", "10 sen + bùa"]

func _tabm() -> Array:
	var e: Array = E.B8()
	var v := e.size()
	var r: int = E.ld()
	var o: int = E.zY()
	var k: int = E.dow1()
	var M: int = E.bu_n()
	var out := []
	# 1. đầu bảng: tháng + số ngày + thanh tiến độ có 4 mốc đúng vị trí ngày
	var hy := 6.0
	var hh := 92.0
	var hc := _dcard(X0, hy, XW, hh)
	var hk := []
	hk.append(_dt(X0 + 12.0, hy + 8.0, XW - 24.0, 16.0, "Tháng " + str(E.q8() % 100) + " · đã điểm danh " + str(v) + "/" + str(o) + " ngày", 13.0, 800, BROWN, "left"))
	var bx0 := X0 + 16.0
	var bw := XW - 32.0
	var by := hy + 58.0
	hk.append(_dbx(bx0, by, bw, 7.0, "rgb(230, 214, 174)", 4.0))
	hk.append(_dbx(bx0, by, bw * clampf(float(v) / o, 0.0, 1.0), 7.0, "rgb(35, 160, 74)", 4.0))
	var row: Dictionary = D.ddms.kids[1]
	for j in E.R8.size():
		var R: Dictionary = E.R8[j]
		var n := int(R.n)
		var cx := bx0 + bw * float(n) / o
		var got: bool = E.ms_got(n)
		var ok := v >= n
		var s := 26.0
		var ring := _dbx(cx - 17.0, hy + 27.0, 34.0, 30.0, "rgb(255, 244, 200)" if ok and not got else "rgba(0, 0, 0, 0)", 8.0, ("1.5px solid " + GOLD) if ok and not got else "")
		ring.kids = [_dic(cx - s * 0.5, hy + 29.0, s, String(row.kids[j].kids[0].svg), 1.0 if ok else 0.45)]
		if got:
			ring.kids.append(_dtick(cx + 7.0, hy + 26.0, 11.0))
		if ok and not got:
			ring.act = E.eF.bind(n)
		else:
			ring.act = _dsay.bind("Mốc " + str(n) + " ngày: " + String(R.t) + ("" if ok else " (còn " + str(n - v) + " ngày)"))
		hk.append(ring)
		hk.append(_dt(cx - 30.0, by + 10.0, 60.0, 12.0, (str(n) + " ngày") if not (ok and not got) else "Nhận", 10.0, 800, GREEN if got else (GOLD if ok else SUB)))
		hk.append(_dt(cx - 34.0, by + 21.0, 68.0, 11.0, R8S[j], 9.5, 600, SUB))
	hc.kids = hk
	out.append(hc)
	# 2. thẻ hôm nay
	var ty := hy + hh + 6.0
	var th := 50.0
	var tc := _dcard(X0, ty, XW, th)
	var gd: Dictionary = E.aF(r)
	var tk := [_dic(X0 + 10.0, ty + 7.0, 36.0, D.ic[String(gd.ic)])]
	if E.q9():
		tk.append(_dt(X0 + 54.0, ty + 8.0, 150.0, 14.0, "Hôm nay · ngày " + str(r), 10.5, 700, SUB, "left"))
		tk.append(_dt(X0 + 54.0, ty + 23.0, 150.0, 18.0, String(gd.t), 13.0, 800, BROWN, "left"))
		tk.append(_dbtn(X0 + XW - 96.0, ty + 12.0, 86.0, 26.0, "Điểm danh", E.tA.bind(r, false)))
		tc.css = tc.css.duplicate()
		tc.css["box-shadow"] = "rgb(222, 160, 40) 0px 0px 0px 1.5px inset, rgba(222, 160, 40, 0.3) 0px 0px 0px 2px"
	else:
		var nx := ""
		if r < o:
			nx = "Mai: " + String(E.aF(r + 1).t)
		tk.append(_dt(X0 + 54.0, ty + 8.0, 200.0, 14.0, "Hôm nay đã nhận", 10.5, 700, GREEN, "left"))
		tk.append(_dt(X0 + 54.0, ty + 23.0, 230.0, 18.0, nx if nx != "" else "Hết tháng, tháng sau điểm danh lại", 13.0, 800, BROWN, "left"))
		tk.append(_dtick(X0 + 36.0, ty + 6.0, 13.0))
	tc.kids = tk
	out.append(tc)
	# 3. lịch
	var cy := ty + th + 6.0
	var misses := 0
	for w in range(1, r):
		if not E.got(w):
			misses += 1
	var foot := 22.0 if misses > 0 else 0.0
	var ch := _hb - cy - 10.0
	var cc := _dcard(X0, cy, XW, ch)
	var ck := []
	var DW := ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]
	var g := 4.0
	var cw := (XW - 16.0 - g * 6.0) / 7.0
	var gx := X0 + 8.0
	for i in 7:
		ck.append(_dt(gx + i * (cw + g), cy + 6.0, cw, 14.0, DW[i], 10.0, 800, SUB))
	var rows := int(ceil((k + o) / 7.0))
	var gy := cy + 24.0
	var rh := minf(cw + 6.0, (ch - 24.0 - 8.0 - foot - g * (rows - 1)) / rows)
	for w in range(1, o + 1):
		var gi: int = k + w - 1
		var x := gx + (gi % 7) * (cw + g)
		var y := gy + (gi / 7) * (rh + g)
		ck.append(_dday(w, x, y, cw, rh, M))
	if misses > 0:
		var fs := ("Bù ngày lỡ: còn " + str(5 - M) + " lần · " + str(3 + M) + " sen đỏ/lần · chạm ngày lỡ để bù") if M < 5 else "Hết lượt bù tháng này"
		ck.append(_dt(X0 + 8.0, cy + ch - 8.0 - foot + 2.0, XW - 16.0, foot - 4.0, fs, 10.5, 600, SUB))
	cc.kids = ck
	out.append(cc)
	return [out, cy + ch + 10.0]

func _dday(w: int, x: float, y: float, cw: float, rh: float, bu: int) -> Dictionary:   # một ô lịch
	var got: bool = E.got(w)
	var r: int = E.ld()
	var now := w == r
	var miss := w < r and not got
	var gd: Dictionary = E.aF(w)
	var big := w % 7 == 0
	var bg := "rgb(255, 250, 240)"
	var bd := "1px solid rgb(232, 218, 186)"
	var sh := "none"
	var op := 0.75
	if got:
		bg = "rgb(226, 243, 220)"
		bd = "1px solid rgb(170, 214, 160)"
		op = 1.0
	elif now:
		bg = "rgb(255, 255, 255)"
		bd = "1.5px solid " + GOLD
		sh = "rgba(222, 160, 40, 0.35) 0px 0px 0px 2px"
		op = 1.0
	elif miss:
		bg = "rgb(255, 255, 255)"
		bd = "1px solid rgb(205, 196, 178)"
		op = 0.3
	elif big:
		bg = "rgb(253, 232, 230)"
		bd = "1px solid rgb(236, 190, 182)"
	var c := _dbx(x, y, cw, rh, bg, 8.0, bd, sh)
	var s := minf(cw - 12.0, rh - 15.0)
	var kids := [_dt(x + 3.0, y + 1.5, 16.0, 11.0, str(w), 9.5, 800, GREEN if got else (GOLD if now else (SUB if not miss else "rgb(170, 160, 140)")), "left"),
		_dic(x + (cw - s) * 0.5, y + rh - s - 3.0, s, D.ic[String(gd.ic)], op)]
	if got:
		kids.append(_dtick(x + cw - 11.5, y + 1.5, 10.0))
		c.act = _dsay.bind("Ngày " + str(w) + ": đã nhận " + String(gd.t) + ".")
	elif now:
		c.act = E.tA.bind(w, false)
	elif miss:
		if bu < 5:
			kids.append(_dt(x + cw - 15.0, y + 1.5, 13.0, 11.0, str(3 + bu), 9.0, 800, "rgb(214, 84, 52)", "right"))
			c.act = _bu_ask.bind(w, 3 + bu)
		else:
			c.act = _dsay.bind("Ngày " + str(w) + " đã lỡ, hết lượt bù tháng này.")
	else:
		c.act = _dsay.bind("Ngày " + str(w) + ": " + String(gd.t) + ".")
	c.kids = kids
	return c

func _bu_ask(w: int, cost: int) -> void:   # ngày lỡ: hỏi lại rồi mới bù
	U.xfp._ask(null, cost, "Điểm danh bù ngày " + str(w) + "?", "Quà: " + String(E.aF(w).t), func(): E.tA(w, true))

# ------------------------------------------------------------------ khung cỡ Kho hàng (bản 385)
const KX := 0.0       # .pwin của Kho
const KY := 85.4
const KW := 338.0
const KH := 524.6
var _ox := 48.2       # mép trái hộp mẫu (.hxwrap)
var _sx := 1.0

func _wx(n: Dictionary, dd = null) -> void:   # nới ngang: khối nền (không chữ, không hình) giãn theo; chữ / hình giữ cỡ,
	# dời theo tâm; chữ nằm trong chữ (đoạn chữ nhiều kiểu) dời cùng một khoảng với chữ ngoài (dd)
	var R: Array = n.r
	var keep: bool = n.has("svg") or String(n.get("text", "")) != "" or dd != null
	var d = null
	if keep:
		if dd == null:
			var cx := float(R[0]) + float(R[2]) * 0.5
			dd = KX + (cx - _ox) * _sx - float(R[2]) * 0.5 - float(R[0])
		d = dd
		n.r = [float(R[0]) + float(dd), R[1], R[2], R[3]]
		if n.has("tr"):
			n.tr = [float(n.tr[0]) + float(dd), n.tr[1], n.tr[2], n.tr[3]]
	else:
		n.r = [KX + (float(R[0]) - _ox) * _sx, R[1], float(R[2]) * _sx, R[3]]
		if n.has("tr"):
			n.tr = [KX + (float(n.tr[0]) - _ox) * _sx, n.tr[1], n.tr[2], n.tr[3]]
	for k in n.get("kids", []):
		if k is Dictionary and k.has("r"):
			_wx(k, d)

func _hx(ov: Dictionary, kids: Array, ch: float) -> void:   # khung đặt đúng chỗ, đúng cỡ Kho; thân cao hết phần còn lại
	var wr := _find(ov, "hxwrap")
	var bd := _find(ov, "hxbody")
	_ox = float(wr.r[0])
	_sx = KW / float(wr.r[2])
	for k in wr.kids:
		_wx(k)
	wr.r = [KX, wr.r[1], KW, wr.r[3]]
	var dh := KH - float(wr.r[3])
	bd.r[3] = float(bd.r[3]) + dh
	var hin := _find(wr, "hxin")
	if not hin.is_empty():
		hin.r[3] = float(hin.r[3]) + dh
	wr.r[3] = KH
	var dy := KY - float(wr.r[1])
	Snap._move(wr, Vector2(0, dy))
	for k in kids:
		Snap._move(k, Vector2(0, dy))
	_tre_box(wr)
	_mount(_ovl(ov), bd, kids, float(bd.r[1]), ch)
	_wire_ov(".hxwrap")
