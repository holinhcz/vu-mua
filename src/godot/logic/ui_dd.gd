extends "res://logic/ui_bang.gd"
# ĐIỂM DANH (aA / ov bản web, nút Điểm danh ở cột sự kiện): (bản 393) khung chung của Kho (ui_bang.gd, khung Sổ làng sl.json:
# #pov .pwin, nút × #pClose, hàng tab tre .bk2tabs), 2 tab:
#  - "Quà 7 ngày đầu" (chỉ khi chưa nhận hết): lưới 4 + 3 ô chip, ô hôm nay có nút Nhận.
#  - "Điểm danh tháng": chip đỏ tháng + số ngày, 4 mốc 7/14/21/28 trên thanh, lịch 5 hàng (chạm hôm nay / ngày lỡ để bù).
# Mẫu khối: ui/snap/dd.json (kiểu chữ, hình quà). Luật ở w_ev.gd.

var E          # w_ev.gd
var D := {}    # dd.json: mẫu kiểu chữ, hình quà
var SB := {}   # #pov khung Sổ làng (khung chung Kho)
var ST := {}   # sl_tab.json: chấm đỏ tab
var cd := "7"  # tab đang mở

func _init(ui, wev) -> void:
	super(ui)
	E = wev
	D = Snap.load_snap("dd")
	SB = Snap.load_snap("sl")["#pov"][0]
	ST = Snap.load_snap("sl_tab")

func open(t := "") -> void:   # aA
	if t != "":
		cd = t
	on = true
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:   # dựng lại khi trạng thái đổi
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
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
	var n := _cl(SB)
	var card := _find(n, "khcard")
	var tabs := _find(n, "bk2tabs")
	var vt := _find(n, "bk2v")
	var ty0 := float(_find(n, "bk2top").r[1])   # bỏ đầu bảng danh hiệu của Sổ làng: hàng tab lên đỉnh thẻ
	card.kids = card.kids.filter(func(k): return not String(k.get("cls", "")).contains("bk2top"))
	_mv(tabs, float(tabs.r[0]), ty0)
	var vy := ty0 + float(tabs.r[3]) + 6.0
	var vb := float(vt.r[1]) + float(vt.r[3])
	vt.r = [vt.r[0], vy, vt.r[2], vb - vy]
	var L := []
	if E.N8():
		L.append(["7", "Quà 7 ngày đầu", E.Cp()])
	L.append(["m", "Điểm danh tháng", E.q9() or E.nF() > 0])
	var bd := _cl(ST.ttdot)
	bd.text = "1"
	_seg_tabs(tabs, L, cd, _tab_go, bd)
	_hb = float(vt.r[3])
	var r: Array = _tab7() if cd == "7" else _tabm()
	var kids: Array = r[0]
	for k in kids:
		Snap._move(k, Vector2(0, vy))
	_mount(n, vt, kids, vy, minf(float(r[1]), _hb), 0.0)   # nội dung xếp vừa thân: không cho cuộn lố vài đơn vị
	U._layout()

# ------------------------------------------------------------------ khối dựng tay (bản 386): tọa độ cuối (khung Kho), y tính từ đỉnh thân
const X0 := 16.5      # mép trái nội dung (như thẻ trong Kho / Sổ làng)
const XW := 305.0     # rộng nội dung
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
	n.css["opacity"] = "1"   # mẫu ô .ddc.fut của web mờ sẵn: bỏ
	n.css["border-radius"] = _cpx(rad)
	n.css["box-shadow"] = sh
	for sd in ["top", "right", "bottom", "left"]:
		n.css["border-" + sd] = bd if bd != "" else "0px none rgb(0, 0, 0)"
	return n

# ô chip nổi như thẻ Sổ làng / chip Kho (viền trong 1px + vệt sáng + quầng trong + bóng): nền VÀ viền cùng tông theo trạng thái
const CHIPK := {   # [gradient trên, giữa, dưới, viền]
	"fut": ["rgb(250, 242, 222)", "rgb(252, 247, 234)", "rgb(255, 252, 245)", "rgba(150, 112, 48, 0.55)"],
	"got": ["rgb(196, 232, 184)", "rgb(208, 238, 198)", "rgb(222, 244, 214)", "rgb(76, 160, 70)"],
	"now": ["rgb(255, 226, 140)", "rgb(255, 236, 170)", "rgb(255, 245, 205)", "rgb(214, 150, 20)"],
	"miss": ["rgb(200, 196, 186)", "rgb(208, 204, 195)", "rgb(218, 215, 207)", "rgb(145, 137, 123)"],
	"tre": ["rgb(226, 196, 128)", "rgb(233, 206, 144)", "rgb(240, 218, 165)", "rgb(150, 108, 40)"],   # dải thứ: nâu vàng
	"sen": ["rgb(250, 210, 210)", "rgb(252, 222, 222)", "rgb(254, 234, 234)", "rgb(214, 120, 128)"],
}
func _chip(x: float, y: float, w: float, h: float, kind: String) -> Dictionary:
	# góc bo, viền trong, vệt sáng, bóng: lấy nguyên chip chung (Snap.chip_look); chỉ thay nền + màu viền theo trạng thái
	var C: Array = CHIPK[kind]
	var n := _dbx(x, y, w, h, "rgba(0, 0, 0, 0)")
	n.cls = "ddchip"
	Snap.chip_look(n, "ddchip", true)
	n.css["background-color"] = String(C[1])
	n.css["background-image"] = "linear-gradient(" + String(C[0]) + " 0%, " + String(C[1]) + " 50%, " + String(C[2]) + " 100%)"
	var sh := String(n.css["box-shadow"])
	sh = String(C[3]) + sh.substr(sh.find(")") + 1)   # màu viền trong (lớp bóng đầu)
	if kind == "now":
		sh = sh.replace("0px 0px 0px 1px inset", "0px 0px 0px 1.5px inset")
	var L := sh.split(") 0px 1px 2px 0px")   # bỏ lớp bóng đổ mờ dưới chip (lớp cuối, không inset)
	if L.size() > 1:
		sh = L[0].substr(0, L[0].rfind(", "))
	n.css["box-shadow"] = sh
	return n

static var _ON := {}
func _onbtn(x: float, y: float, w: float, h: float, t: String, cb, red := false) -> Dictionary:   # nút = chip "on" (xanh) của Kho; red: cùng dáng, tông đỏ
	if _ON.is_empty():
		var ch: Dictionary = Snap.find(Snap.load_snap("kho")["#pov"][0], "khchips")
		for k in ch.kids:
			if String(k.cls).split(" ").has("on"):
				_ON = k.css
				break
	var n := _dbx(x, y, w, h, "rgba(0, 0, 0, 0)", 10.0)
	for key in ["background-color", "background-image", "border-radius", "box-shadow"]:
		n.css[key] = _ON.get(key, n.css.get(key))
	if red:
		n.css["background-image"] = "linear-gradient(rgb(196, 62, 48) 0%, rgb(204, 68, 52) 50%, rgb(216, 82, 62) 100%)"
		n.css["box-shadow"] = String(n.css["box-shadow"]).replace("rgb(63, 116, 41)", "rgb(140, 38, 28)").replace("rgba(150, 215, 130, 0.45)", "rgba(255, 170, 150, 0.45)").replace("rgba(10, 55, 10, 0.2)", "rgba(80, 10, 5, 0.2)").replace("rgba(30, 70, 20, 0.32)", "rgba(80, 20, 10, 0.32)")
	n.kids = [_dt(x, y, w, h, t, 12.5, 800, "rgb(255, 255, 255)")]
	if cb is Callable:
		n.act = cb
	return n

# hình quà vẽ trong khung 64 mà độ đầy khác nhau (đồng xu nhỏ, hộp quà to): phóng theo loại cho cùng cỡ nhìn
const ICK := {"coin": 1.35, "pearl": 1.08, "crate": 1.0, "bua": 1.0, "che": 0.9, "gift": 0.8}
func _dick(cx: float, cy: float, s: float, ic: String, op := 1.0) -> Dictionary:   # hình quà loại ic, tâm (cx, cy)
	var svg: String = D.ic[ic] if D.ic.has(ic) else String(D.ddms.kids[1].kids[3].kids[0].svg)
	var z := s * float(ICK.get(ic, 1.0))
	return _dic(cx - z * 0.5, cy - z * 0.5, z, svg, op)

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
		var c := _chip(x, y, w, rh, "got" if got else ("now" if now else ("sen" if i == 6 else "fut")))
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

func _tabm() -> Array:   # (bản 388) không thẻ kem chồng: tiêu đề phần + chip đặt thẳng trên nền khung
	var e: Array = E.B8()
	var v := e.size()
	var r: int = E.ld()
	var o: int = E.zY()
	var k: int = E.dow1()
	var M: int = E.bu_n()
	var out := []
	# 1. mốc tháng: thanh tiến độ + 4 mốc đúng vị trí ngày
	var hy := 12.0
	var mt := "Tháng " + str(E.q8() % 100)
	var mw: float = Box.text_w(mt, 12.5, 800) + 24.0
	out.append(_onbtn(X0, hy - 3.0, mw, 24.0, mt, null, true))
	var tx := X0 + mw + 8.0
	var t1 := "Đã điểm danh "
	var w1: float = Box.text_w(t1, 12.0, 700)
	out.append(_dt(tx, hy - 3.0, w1, 24.0, t1, 12.0, 700, BROWN, "left"))
	var t2 := str(v) + "/" + str(o)
	var w2: float = Box.text_w(t2, 13.0, 800)
	out.append(_dt(tx + w1, hy - 3.0, w2, 24.0, t2, 13.0, 800, GREEN, "left"))
	out.append(_dt(tx + w1 + w2 + 5.0, hy - 3.0, 50.0, 24.0, "ngày", 12.0, 700, BROWN, "left"))
	var bx0 := X0 + 14.0
	var bw := XW - 28.0
	var iy := hy + 31.0
	var ms := 44.0        # chip mốc cỡ ô ngày
	var by := iy + ms * 0.5 - 3.5   # thanh chạy qua giữa các chip mốc
	out.append(_dbx(bx0, by, bw, 7.0, "rgb(230, 214, 174)", 4.0))
	out.append(_dbx(bx0, by, bw * clampf(float(v) / o, 0.0, 1.0), 7.0, "rgb(35, 160, 74)", 4.0))
	var ly := iy + ms + 5.0
	for j in E.R8.size():
		var R: Dictionary = E.R8[j]
		var n := int(R.n)
		var cx := bx0 + bw * float(n) / o
		var got: bool = E.ms_got(n)
		var ok := v >= n
		var nxt: bool = not ok and (j == 0 or v >= int(E.R8[j - 1].n))   # mốc kế tiếp
		var ring := _chip(cx - ms * 0.5, iy, ms, ms, "got" if got else ("now" if ok else "fut"))   # vàng = đủ ngày, chờ bấm Nhận
		ring.kids = [_dick(cx, iy + ms * 0.5, 32.0, String(R.ic))]
		if got:
			ring.kids.append(_dtick(cx + ms * 0.5 - 13.0, iy + 3.0, 10.0))
		if ok and not got:
			ring.act = E.eF.bind(n)
		else:
			ring.act = _dsay.bind("Mốc " + str(n) + " ngày: " + String(R.t) + ("" if ok else " (còn " + str(n - v) + " ngày)"))
		out.append(ring)
		out.append(_dt(cx - 30.0, ly, 60.0, 14.0, "Nhận" if ok and not got else (str(n) + " ngày"), 10.0, 800, GREEN if got else (GOLD if ok else (BROWN if nxt else SUB))))
		out.append(_dt(cx - 38.0, ly + 16.0, 76.0, 13.0, ("còn " + str(n - v) + " ngày") if nxt else R8S[j], 9.5, 700 if nxt else 600, "rgb(176, 118, 10)" if nxt else SUB))
	# 2. lịch
	var cy := ly + 42.0
	var misses := 0
	for w in range(1, r):
		if not E.got(w):
			misses += 1
	var bot := 38.0 + (18.0 if misses > 0 else 0.0)   # chỗ nút / dòng hôm nay + dòng bù dưới lịch
	var DW := ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]
	var g := 4.0
	var cw := (XW - g * 6.0) / 7.0
	var gx := X0
	var wy := cy
	var band := _chip(gx, wy, XW, 24.0, "tre")
	band.css["border-radius"] = _cpx(5.0)   # dải mỏng: bo ít (chỉ dải này)
	out.append(band)
	for i in 7:
		out.append(_dt(gx + i * (cw + g), wy, cw, 24.0, DW[i], 12.0, 800, "rgb(190, 50, 40)" if i == 6 else "rgb(80, 52, 14)"))
	var rows := mini(5, int(ceil((k + o) / 7.0)))   # lịch giấy: ngày 30, 31 tràn hàng 6 thì dồn lên ô trống hàng 1
	var gy := wy + 29.0
	var rh := (_hb - 2.0 - bot - gy - g * (rows - 1)) / rows   # ô lịch cao lấp hết thân
	for w in range(1, o + 1):
		var gi: int = k + w - 1
		if gi >= 35:
			gi -= 35
		out.append(_dday(w, gx + (gi % 7) * (cw + g), gy + (gi / 7) * (rh + g), cw, rh, M))
	# 3. hôm nay: nút vàng (chưa nhận) / một dòng (đã nhận), dòng bù
	var ty := gy + rows * (rh + g) + 4.0
	var gd: Dictionary = E.aF(r)
	if E.q9():
		out.append(_onbtn(X0 + (XW - 170.0) * 0.5, ty, 170.0, 28.0, "Điểm danh hôm nay", E.tA.bind(r, false)))
	else:
		var t := "✓ Đã nhận hôm nay" + ((" · Mai: " + String(E.aF(r + 1).t)) if r < o else "")
		out.append(_dt(X0, ty, XW, 28.0, t, 11.0, 700, GREEN))
	var ey := ty + 36.0
	if misses > 0:
		var fs := ("Chạm ngày lỡ để bù · còn " + str(5 - M) + " lần · " + str(3 + M) + " sen đỏ/lần") if M < 5 else "Hết lượt bù tháng này"
		out.append(_dt(X0, ey, XW, 16.0, fs, 10.5, 600, SUB))
		ey += 20.0
	return [out, ey + 8.0]

func _dday(w: int, x: float, y: float, cw: float, rh: float, bu: int) -> Dictionary:   # một ô lịch
	var got: bool = E.got(w)
	var r: int = E.ld()
	var now := w == r
	var miss := w < r and not got
	var gd: Dictionary = E.aF(w)
	var big := w % 7 == 0
	var kind := "got" if got else ("now" if now else ("miss" if miss else ("sen" if big else "fut")))
	var op := 0.5 if miss else 1.0
	var c := _chip(x, y, cw, rh, kind)
	var s := minf(cw - 6.0, rh - 13.0)
	var kids := [_dt(x + 4.0, y + 2.5, 18.0, 10.0, str(w), 8.25, 500, GREEN if got else ("rgb(150, 100, 10)" if now else ("rgb(190, 80, 90)" if kind == "sen" else (SUB if not miss else "rgb(130, 122, 108)"))), "left"),
		_dick(x + cw * 0.5, y + rh - s * 0.5 - 3.0, s, String(gd.ic), op)]
	if got:
		kids.append(_dtick(x + cw - 12.5, y + 2.5, 10.0))
		c.act = _dsay.bind("Ngày " + str(w) + ": đã nhận " + String(gd.t) + ".")
	elif now:
		c.act = E.tA.bind(w, false)
	elif miss:
		if bu < 5:
			c.act = _bu_ask.bind(w, 3 + bu)
		else:
			c.act = _dsay.bind("Ngày " + str(w) + " đã lỡ, hết lượt bù tháng này.")
	else:
		c.act = _dsay.bind("Ngày " + str(w) + ": " + String(gd.t) + ".")
	c.kids = kids
	return c

func _bu_ask(w: int, cost: int) -> void:   # ngày lỡ: hỏi lại rồi mới bù
	U.xfp._ask(null, cost, "Điểm danh bù ngày " + str(w) + "?", "Quà: " + String(E.aF(w).t), func(): E.tA(w, true))

