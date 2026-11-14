extends "res://logic/ui_hx.gd"
# ĐIỂM DANH (aA / ov bản web, nút Điểm danh ở cột sự kiện): hộp khung tre ui_hx.gd, 2 tab
#  - "Quà 7 ngày đầu" (chỉ khi chưa nhận hết): lưới 7 thẻ quà, thẻ hôm nay có nút Nhận.
#  - "Điểm danh tháng": 4 mốc 7/14/21/28 ngày, số ngày đã điểm danh, lịch tháng (chạm hôm nay / ngày lỡ để điểm danh bù).
# Mẫu: ui/snap/dd.json (chụp bản web, tọa độ tính từ đỉnh thân / đỉnh hàng tab). Luật ở w_ev.gd.

var E          # w_ev.gd
var D := {}
var cd := "7"  # tab đang mở

const CX := 30.64   # bước cột lịch
const CY := 25.5    # bước hàng lịch

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

# ------------------------------------------------------------------ tab Quà 7 ngày đầu
func _tab7() -> Array:
	var p: int = int(E.Sp().l7.get("n", 0))
	var d: bool = E.Cp()
	var g := _cl(D.dd7)
	var cards: Array = g.kids
	var rh := [float(cards[0].r[3]), float(cards[4].r[3])]
	if d and p < 4:
		rh[0] += 13.2
	elif d and p < 7:
		rh[1] += 12.6
	var y1 := float(cards[0].r[1])
	var y2: float = y1 + rh[0] + 4.5
	for i in cards.size():
		var c: Dictionary = cards[i]
		var row := 0 if i < 4 else 1
		Snap._move(c, Vector2(0, (y1 if row == 0 else y2) - float(c.r[1])))
		c.r[3] = rh[row]
		if i < p:   # đã nhận
			c.cls += " got"
			c.css.opacity = D.op_got
			var em := _cl(D.em7)
			_mv(em, float(c.r[0]) + float(c.r[2]) - 15.75, float(c.r[1]) + 3.75)
			c.kids.append(em)
		elif d and i == p:   # hôm nay: nhận
			c.cls += " today"
			if int(E.D7[i].get("big", 0)) != 2:
				c.css["box-shadow"] = D.sh_today
			var bb: Dictionary = c.kids.filter(func(k): return k.tag == "b")[0]
			var ib := _cl(D.i7)
			_mv(ib, float(c.r[0]) + (float(c.r[2]) - float(ib.r[2])) * 0.5, float(bb.r[1]) + float(bb.r[3]) + 4.5)
			c.kids.append(ib)
			c.act = E.tF
	g.r[3] = y2 + rh[1] - y1
	var out := [g]
	var bot: float = y2 + rh[1]
	if not d:
		var nt := _cl(D.note)
		_mv(nt, float(nt.r[0]), bot + 7.5)
		var st := _cl(nt)
		st.erase("kids")
		var q := p + 1
		var h := _put(nt, [_r("Hôm nay nhận rồi, mai quay lại nhận quà ngày " + str(q) + (" (xe đạp)" if q == 4 else (" (xuồng ba lá)" if q == 7 else "")) + " nha!", st)])
		nt.r[3] = h + _px(nt, "padding-top") + _px(nt, "padding-bottom")
		out.append(nt)
		bot = float(nt.r[1]) + float(nt.r[3])
	return [out, bot + 10.5]

# ------------------------------------------------------------------ tab Điểm danh tháng
func _tabm() -> Array:
	var a: Dictionary = E.Sp()
	var e: Array = E.B8()
	var v := e.size()
	var r: int = E.ld()
	var o: int = E.zY()
	var k: int = E.dow1()
	var M: int = E.bu_n()
	var out := []
	# mốc 7/14/21/28 ngày
	var ms := _cl(D.ddms)
	var bar: Dictionary = ms.kids[0]
	bar.kids[0].r[2] = float(bar.r[2]) * minf(1.0, v / 28.0)
	var row: Dictionary = ms.kids[1]
	var bs := []
	for j in E.R8.size():
		var R: Dictionary = E.R8[j]
		var pl: Dictionary = row.kids[j]
		var dt := v >= int(R.n)
		var W: bool = E.ms_got(int(R.n))
		var b := _cl(pl)
		if W or dt:
			b = _cl(D.ch_got if W else D.ch_on)
			_mv(b, float(pl.r[0]) + (0.0 if W else 21.0), float(pl.r[1]))
			b.kids[0].svg = pl.kids[0].svg
			b.kids[1].text = pl.kids[1].text
		if dt and not W:
			b.act = E.eF.bind(int(R.n))
		bs.append(b)
	row.kids = bs
	out.append(ms)
	# Đã điểm danh v/o ngày · bù
	var sm := _cl(D.ddsum)
	var sp: Dictionary = sm.kids[0]
	var bst: Dictionary = _cl(sp.kids[0])
	bst.erase("kids")
	var st := _cl(sp)
	st.erase("kids")
	_put(sp, [_r("Đã điểm danh ", st), _r(str(v), bst), _r("/" + str(o) + " ngày", st)])
	var sl: Dictionary = sm.kids[1]
	_set_txt(sl, "Điểm danh bù: " + str(5 - M) + " lần còn lại · " + str(3 + M) + " sen đỏ/lần")
	out.append(sm)
	# lịch tháng
	var cal := _cl(D.cal)
	_set_txt(cal.kids[0], "Tháng " + str(E.q8() % 100) + "/" + str(E.q8() / 100), "center")
	var x0 := float(D.dde.r[0])
	var y0 := float(D.dde.r[1])
	for t in k:
		var de := _cl(D.dde)
		_mv(de, x0 + t * CX, y0)
		cal.kids.append(de)
	for w in range(1, o + 1):
		var gi: int = k + w - 1
		var Eg: bool = E.got(w)
		var N := w == r
		var z := w < r and not Eg
		var key := "gottoday" if Eg and N else ("got" if Eg else ("today" if N else ("miss" if z else "fut")))
		var c := _cl(D.cell[key])
		_mv(c, x0 + (gi % 7) * CX, y0 + (gi / 7) * CY)
		if N:   # .ddc.today: viền xanh tròn (bản chụp không bắt được, lấy computed style của web)
			for sd in ["top", "right", "bottom", "left"]:
				c.css["border-" + sd] = "1.33333px solid rgb(62, 154, 37)"
			c.css["border-radius"] = "999px"
			c.css["background-color"] = "rgb(255, 255, 255)"
			c.css["box-shadow"] = "rgba(62, 154, 37, 0.25) 0px 0px 0px 2px"
		var sml: Dictionary = c.kids[0]
		_set_txt(sml, str(w))
		c.kids[1].svg = D.ic[String(E.aF(w).ic)]
		if N and not Eg:
			c.act = E.tA.bind(w, false)
		elif z:
			c.act = E.tA.bind(w, true)
		cal.kids.append(c)
	var rows := int(ceil((k + o) / 7.0))
	cal.r[3] = (y0 - float(cal.r[1])) + rows * CY - 3.0
	out.append(cal)
	return [out, float(cal.r[1]) + float(cal.r[3]) + 10.5]
