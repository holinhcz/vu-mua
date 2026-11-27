extends "res://logic/ui_kbang.gd"
# (11-27) ĐƠN HÀNG = GIỎ HÀNG (khung chung ui_kbang: khung sen, đáy chung), không thẻ lồng trong bảng.
#   Đầu (cố định): "Giao được N/M đơn" + thanh + "đã giao D"; bảng quán: hàng chip (sao, danh tiếng, giá...) dưới đầu.
#   Thân (cuộn): mỗi đơn một giỏ tre nhìn nghiêng 2.5D, 3 cột, đặt thẳng trên nền bảng; giỏ 4 cấp theo hạng thưởng trong bảng
#     (cấp 4 sơn son đai đồng = đơn thưởng cao nhất, cấp 3 ~22% kế, cấp 2 ~30% kế, còn lại cấp 1 tre tươi):
#     bong bóng món nằm trong lòng giỏ (chỉ hình món; vòng tiến độ có/cần quanh bóng; món thiếu bóng trong, hình mờ),
#     tên khách + sao cấp dưới đế; đủ hàng quầng xanh nhấp nháy + dấu tích + giỏ nảy + đốm sáng bay lên; đơn gấp tem GẤP;
#     giỏ đang chọn nhô lên + quầng vàng + nảy bung lúc chọn; bong bóng nhấp nhô; cấp 3-4 vệt ánh kim quét thân giỏ, cấp 4 lấp lánh.
#   Giao: bong bóng vỡ thành bọt, giỏ nhấc khỏi đế bay vòng lên ô xu, hoa giấy, xu + sao bay theo đường cong; giỏ mới rơi xuống đế nảy.
#   Đáy (cố định): chi tiết giỏ đang chọn: mặt khách, tên, quán, thưởng xu + sao xanh, từng món có/cần, nút Giao hàng /
#     Đi lấy + bù sen + Đổi; khách đang tới: giờ chờ, thanh, Gọi. Giao: xu + sao bay về ô xu / ô cấp.
#   Mỗi giỏ đặt trên đế gỗ tràm 4 chân (ui/img/gio/de.webp, 616x455, cùng góc trên trái + bề ngang với giỏ).
#   Hình giỏ (hinh/giotre, vẽ bằng src/giotre/giotre.py): ui/img/gio/gioN_sau.webp (cả giỏ, dưới bóng) + gioN_truoc.webp
#     (thành + vành trước, đè chân bóng), khung 616x336; vành trước giữa giỏ ở 0,51 chiều cao.
#   Bảng quán: khung "món giờ này" dưới giỏ.
# Logic dùng lại của ui.gd: U.od_src, U._od_order, U._od_deliver / _od_get / _od_lack_btn / _od_swap, U.od_ud.

const HEAD := 26.0
const FW := 112.0     # dải chi tiết đáy khi khách đang tới
const IR := 26.0      # dòng món ở dải đáy
const RG6 := 6.0      # cách giữa hai kệ giỏ
const DE_A := 386.0 / 616.0   # đế gỗ: đáy chân / rộng (ảnh 616x455, cùng góc trên trái với giỏ)
const TEN_H := 20.0   # tên khách + sao dưới đế (cách chân đế 4)
const GA := 336.0 / 616.0   # giỏ: cao / rộng
const GV := 0.512     # vành trước giữa giỏ (phần chiều cao)
const GT := 10.0      # chừa trên giỏ cho bong bóng ló khỏi miệng
const BW := 94.0      # giỏ rộng
const SZ := {1: 40.0, 2: 34.0, 3: 28.0}   # bong bóng theo số món
const XS := {1: [0.5], 2: [0.35, 0.65], 3: [0.25, 0.5, 0.75]}
const GOLD_L := "rgb(214, 176, 104)"
const XP_C := "rgb(47, 127, 214)"   # chữ EXP xanh (sao xanh)
const DOWN_C := "rgb(214, 69, 65)"

var src := ""
var sel := -1   # đơn đang chọn (chỉ số trong U._od_list)
var _cap := {}   # đơn f -> cấp giỏ 1..4
var _sel_t := 0.0   # lúc vừa chọn giỏ (giây, nảy bung một nhịp)
var _drop := {}     # đơn f -> lúc vừa giao (giỏ mới rơi xuống đế)
var _swap := {}     # đơn f -> lúc vừa đổi (giỏ mới trượt vào)
var _had := {}      # "f:q" -> số có lần dựng trước (có thêm hàng -> bóng bật)
var _pop := {}      # "f:q" -> lúc vừa có thêm hàng

func _init(ui) -> void:
	super(ui)
	snapcut = false

func open(s := "") -> void:
	src = s
	U.od_src = s
	on = true
	scroll = 0.0
	sig = ""
	sel = -1
	_build()

func close() -> void:
	U.od_on = false
	super()

func _sig() -> String:
	var now: float = G._now_ms()
	var L: Array = U._od_list()
	var w := []
	for o in L:
		if o.has("w"):
			w.append(int((float(o.w) - now) / 1000.0))
	return JSON.stringify([src, L, G.g.barn, int(G.g.ngoc), int(G.g.delivered), U.od_ud, w, G.day(), sel])

# ------------------------------------------------------------------ dựng
func _build() -> void:
	U.od_on = true
	var lp: Array = U._od_order()
	var L: Array = lp[0].duplicate()
	var plan: Array = lp[1]
	L.sort_custom(func(a, b): return int(a[1]) < int(b[1]))   # giỏ giữ nguyên chỗ (không xếp lại khi đủ hàng): giao / đổi xong giỏ mới về đúng ô cũ
	if sel < 0 or sel >= U._od_list().size():   # mặc định: đơn đủ hàng đầu tiên, không có thì đơn đầu
		sel = int(lp[0][0][1]) if L.size() else -1   # lp[0] xếp đơn đủ hàng lên trước
	sig = _sig()
	_rank(plan)
	var sh := _kshell([], "", func(_k): pass)
	var n: Dictionary = sh[0]
	var vt: Dictionary = sh[1]
	var okn := 0
	var m := 0
	for f in plan.size():
		if plan[f] != null:
			m += 1
			if plan[f].ok:
				okn += 1
	_kfix(n, vt, _head(okn, m), HEAD, false)
	if src != "":
		var cs := _qchips()
		if cs.size():
			_kfix(n, vt, cs, 26.0, false)
	if sel >= 0:
		var so: Dictionary = U._od_list()[sel]
		_kfix(n, vt, _foot(sel, so, plan[sel]), _foot_h(so, plan[sel]), true)
	var out := []
	var cw := XW / 3.0
	var rows := ceili(L.size() / 3.0)
	var avail := float(vt.r[3])
	var bw := minf(BW, cw - 2.0)
	if src == "" and rows > 0:   # kệ giỏ sít nhau (cách RG6); không vừa thân thì thu giỏ nhỏ lại cho vừa, không cuộn
		bw = clampf((avail - rows * (GT + TEN_H) - (rows - 1) * RG6) / (rows * DE_A), 70.0, bw)
	var ch := GT + bw * DE_A + TEN_H
	var gh := rows * ch + maxf(0.0, rows - 1) * RG6
	# cụm giỏ cân giữa thân theo phần NHÌN THẤY: đỉnh bong bóng cao nhất hàng đầu .. đáy tên khách hàng cuối (trên = dưới)
	var vtop := GT
	for q in mini(3, L.size()):
		var e: Dictionary = U._od_list()[L[q][1]]
		if plan[L[q][1]] != null:
			var ni: int = mini(3, e.items.size())
			var s0: float = SZ[ni]
			vtop = minf(vtop, GT - (6.0 if int(L[q][1]) == sel else 0.0) + GV * bw * GA - s0 * 0.32 - (3.0 if ni == 3 else 0.0) - (s0 * 0.5 + 3.0))
	# khoảng trống nhìn thấy chia đều: trên cụm (tính cả GG dưới thanh tiến độ) = giữa các hàng = dưới cụm (tính cả GG trên dải đáy)
	var vh := ch - vtop - (TEN_H - 18.0)   # một hàng nhìn thấy: đỉnh bóng .. đáy tên
	var rg := RG6
	var y0 := 0.0
	if src == "" and rows > 0:
		var G2 := maxf(GG, (avail + 2.0 * GG - rows * vh) / (rows + 1))
		rg = maxf(RG6, G2 - vtop - (TEN_H - 18.0))
		y0 = maxf(-vtop, G2 - GG - vtop)
	gh = rows * ch + maxf(0.0, rows - 1) * rg
	for q in L.size():
		var f: int = L[q][1]
		out.append_array(_gio(X0 + (q % 3) * cw + (cw - bw) * 0.5, y0 + (q / 3) * (ch + rg), bw, cw, f, U._od_list()[f], plan[f]))
	var y := y0 + gh
	if src != "":
		var mn := _menu(y + 6.0)
		out.append_array(mn[0])
		y = float(mn[1])
	if L.is_empty():
		out.append(_dt(X0, 10.0, XW, 16.0, "Chưa có đơn nào.", 12.0, 600, SUB))
		y = 40.0
	_kmount(n, vt, float(vt.r[1]), out, y)

func _head(okn: int, m: int) -> Array:
	var out := []
	var kd: String = G.w_all.WQ.kd(src) if src != "" else ""
	var unit := "khách" if src != "" and kd != "taphoa" else "đơn"
	var t := "Giao được "
	var tw: float = Box.text_w(t, 12.0, 700)
	out.append(_dt(X0, 0.0, tw, 16.0, t, 12.0, 700, BROWN, "left"))
	var ns := str(okn) + "/" + str(m)
	var nw: float = Box.text_w(ns, 14.0, 800) + 2.0
	out.append(_dt(X0 + tw, -1.0, nw, 18.0, ns, 14.0, 800, GREEN if okn > 0 else BROWN, "left"))
	out.append(_dt(X0 + tw + nw + 4.0, 0.0, 40.0, 16.0, unit, 12.0, 700, BROWN, "left"))
	var ds: String = "đã giao " + G.fmt_n(int(G.g.delivered))
	var dw: float = Box.text_w(ds, 10.5, 700) + 22.0
	var dx := X0 + XW - dw - 10.0   # chừa dây tua góc phải
	var dc := _chip(dx, -2.0, dw, 20.0, "got")
	dc.kids = [_dt(dx, -2.0, dw, 20.0, ds, 10.5, 700, GREEN)]
	out.append(dc)
	out.append_array(_bar(X0, 20.0, XW, float(okn) / maxf(1.0, m), 5.0))
	return out

func _qchips() -> Array:   # bảng quán: sao, danh tiếng, giá / trễ / khách
	var WQ = G.w_all.WQ
	var out := []
	var x := X0
	for c in WQ.chips(src):
		var t: String = c[1]
		var pic: String = c[2] if c.size() > 2 else ""
		var w: float = Box.text_w(t, 10.5, 700) + 16.0 + (18.0 if pic != "" else 0.0)
		if x + w > X0 + XW:
			break
		var ch := _chip(x, 0.0, w, 24.0, "fut")
		var tx := x + 8.0
		ch.kids = []
		if pic != "":
			ch.kids.append(_pic(tx, 4.0, 16.0, 16.0, pic) if pic.begins_with("res://") else _icx(tx + 8.0, 12.0, 16.0, pic))
			tx += 18.0
		ch.kids.append(_dt(tx, 0.0, w - (tx - x) - 6.0, 24.0, t, 10.5, 700, BROWN, "left"))
		var k := String(c[0])
		var qk := src
		if k == "sao":
			ch.act = func():
				close()
				U.spp.open_quan(qk)
		elif k == "gia":
			ch.act = func(): WQ.gia_next(qk)
		out.append(ch)
		x += w + 6.0
	return out

func _rank(plan: Array) -> void:   # cấp giỏ theo hạng thưởng các đơn đang chờ giao (cấp nào cũng có thứ bậc)
	_cap = {}
	var fs := []
	for f in plan.size():
		if plan[f] != null:
			fs.append(f)
	var OL: Array = U._od_list()
	fs.sort_custom(func(a, b): return int(OL[a].reward) > int(OL[b].reward) or (int(OL[a].reward) == int(OL[b].reward) and a < b))
	var n := fs.size()
	var n4 := 1 if n >= 3 else 0
	var n3 := clampi(roundi(n * 0.22), 0, 2)
	var n2 := clampi(roundi(n * 0.3), 0, 3)
	for r in n:
		_cap[fs[r]] = 4 if r < n4 else (3 if r < n4 + n3 else (2 if r < n4 + n3 + n2 else 1))

func _art(c: int, lop: String, x: float, y: float, w: float, h: float) -> Dictionary:   # một lớp hình giỏ cấp c
	return _pic(x, y, w, h, "res://ui/img/gio/gio" + str(c) + "_" + lop + ".webp")

func _vong(cx: float, cy: float, r: float, p: float, col: String) -> Dictionary:   # vòng tiến độ quanh bong bóng (p 0..1, chạy từ đỉnh theo chiều kim đồng hồ)
	var a := TAU * clampf(p, 0.0, 1.0)
	var arc := ""
	if p >= 0.999:
		arc = "<circle cx=\"20\" cy=\"20\" r=\"17.5\" fill=\"none\" stroke=\"%s\" stroke-width=\"4.5\"/>" % col
	elif p > 0.001:
		arc = "<path d=\"M20 2.5 A17.5 17.5 0 %d 1 %.2f %.2f\" fill=\"none\" stroke=\"%s\" stroke-width=\"4.5\" stroke-linecap=\"round\"/>" % [1 if a > PI else 0, 20.0 + 17.5 * sin(a), 20.0 - 17.5 * cos(a), col]
	# rãnh nền: trắng ngoài + xám nâu trong (thấy rõ phần còn thiếu)
	var sv := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 40 40\"><circle cx=\"20\" cy=\"20\" r=\"17.5\" fill=\"none\" stroke=\"rgb(255,255,255)\" stroke-opacity=\"0.9\" stroke-width=\"5.5\"/><circle cx=\"20\" cy=\"20\" r=\"17.5\" fill=\"none\" stroke=\"rgb(150,120,90)\" stroke-opacity=\"0.35\" stroke-width=\"3.2\"/>" + arc + "</svg>"
	return _dic(cx - r, cy - r, r * 2.0, sv)

const BONG := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 40 40\"><defs><radialGradient id=\"g\" cx=\"0.38\" cy=\"0.32\" r=\"0.75\"><stop offset=\"0\" stop-color=\"rgb(255,255,255)\" stop-opacity=\"%s\"/><stop offset=\"0.6\" stop-color=\"rgb(236,244,252)\" stop-opacity=\"%s\"/><stop offset=\"1\" stop-color=\"rgb(200,220,240)\" stop-opacity=\"%s\"/></radialGradient></defs><circle cx=\"20\" cy=\"20\" r=\"19\" fill=\"url(#g)\" stroke=\"rgb(255,255,255)\" stroke-opacity=\"0.95\" stroke-width=\"1.4\"/><ellipse cx=\"13\" cy=\"10\" rx=\"5\" ry=\"3.2\" transform=\"rotate(-25 13 10)\" fill=\"rgb(255,255,255)\" fill-opacity=\"0.95\"/></svg>"
const SAO := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 20 20\"><path d=\"M10 1.5l2.6 5.3 5.8.8-4.2 4.1 1 5.8L10 14.8l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z\" fill=\"rgb(250,186,30)\" stroke=\"rgb(140,80,10)\" stroke-width=\"1.4\" stroke-linejoin=\"round\"/><path d=\"M10 4.5l1.6 3.3\" stroke=\"rgb(255,236,150)\" stroke-width=\"1.4\" stroke-linecap=\"round\"/></svg>"
const MUI := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 12 7\" preserveAspectRatio=\"none\"><path d=\"M1 1H11L6 6.5Z\" fill=\"rgb(240,170,30)\" stroke=\"rgb(160,96,10)\" stroke-width=\"0.9\" stroke-linejoin=\"round\"/></svg>"
const SANG := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 80\"><defs><radialGradient id=\"g\"><stop offset=\"0\" stop-color=\"%s\" stop-opacity=\"0.85\"/><stop offset=\"1\" stop-color=\"%s\" stop-opacity=\"0\"/></radialGradient></defs><ellipse cx=\"50\" cy=\"42\" rx=\"50\" ry=\"40\" fill=\"url(#g)\"/></svg>"

func _gio(x: float, y: float, w: float, cw: float, f: int, o: Dictionary, pl) -> Array:   # một đơn: đồ đựng + bong bóng món + tên
	var out := []
	var h := w * GA
	var c: int = _cap.get(f, 1)
	var ok: bool = pl != null and pl.ok
	var is_sel := f == sel
	var by := y + GT - (6.0 if is_sel else 0.0)   # giỏ đang chọn nhô lên
	if ok or is_sel:   # quầng: xanh = đủ hàng (nhấp nháy), vàng = đang chọn
		var gc := "rgb(255,200,60)" if is_sel else "rgb(110,220,90)"
		var gl := _dic(x - 10.0, by - 12.0, w + 20.0, SANG % [gc, gc])
		gl.r = [x - 10.0, by - 12.0, w + 20.0, h + 30.0] if is_sel else [x - 8.0, by - 10.0, w + 16.0, h + 20.0]
		if ok and not is_sel:
			gl.fx = "nhay"
		out.append(gl)
	out.append(_pic(x, y + GT, w, w * 455.0 / 616.0, "res://ui/img/gio/de.webp"))   # đế gỗ tràm (đứng yên khi giỏ nảy)
	# giỏ = một khối (giỏ sau, bong bóng, giỏ trước, dấu tích, tem): nảy / rơi / bay đi cùng nhau; đế đứng yên
	var g := _dbx(x - 4.0, y, w + 8.0, GT + h, "rgba(0, 0, 0, 0)", 0.0)
	g.gk = f
	var gf := []
	var now := Time.get_ticks_msec() / 1000.0
	if _drop.has(f) and now - float(_drop[f]) < 1.4:
		gf.append("roi:" + str(_drop[f]))   # giỏ mới rơi xuống đế sau khi giao
	elif _swap.has(f) and now - float(_swap[f]) < 1.0:
		gf.append("truot:" + str(_swap[f]))   # đổi đơn: giỏ mới trượt vào
	elif is_sel and now - _sel_t < 0.6:
		gf.append("chon:" + str(_sel_t))   # vừa chọn: nảy bung một nhịp
	elif ok:
		gf.append("nay")
	if ok:
		gf.append("hat:xanh")   # đủ hàng: đốm sáng bay lên
	if c == 4 and pl != null:
		gf.append("hat:lap")    # giỏ cấp 4: lấp lánh
	if not gf.is_empty():
		g.fx = "|".join(gf)
	var sau := _art(c, "sau", x, by, w, h)
	var tru := _art(c, "truoc", x, by, w, h)
	if c >= 3:   # cấp 3, 4: vệt ánh kim quét qua thân giỏ
		sau.fx = "kim" if c == 4 else "kim3"
		tru.fx = sau.fx
	g.kids = [sau]
	if pl != null:
		var ni: int = mini(3, o.items.size())
		var s: float = SZ[ni]
		for q in ni:
			var id: String = String(o.items[q][0])
			var need := int(o.items[q][1])
			var have: int = int(pl.have[q])
			var good := have >= need
			var cx: float = x + w * float(XS[ni][q])
			var cy: float = by + GV * h - s * 0.32 - (3.0 if ni == 3 and q == 1 else 0.0)   # chân bóng lọt dưới vành trước
			var r := s * 0.5 + 3.0
			var bb := _dbx(cx - r, cy - r, r * 2.0, r * 2.0, "rgba(0, 0, 0, 0)", 0.0)   # một bong bóng: vòng + bóng + hình, nhấp nhô lệch nhịp
			var kq := str(f) + ":" + str(q) + ":" + id
			if _had.has(kq) and have > int(_had[kq]):
				_pop[kq] = now
			_had[kq] = have
			var bf := ["nhap:" + str(q * 2.1 + f * 0.7)]
			if _pop.has(kq) and now - float(_pop[kq]) < 0.5:
				bf.append("bat:" + str(_pop[kq]))   # vừa có thêm hàng: bóng bật phồng
			if not good and is_sel and now - _sel_t < 0.7:
				bf.append("do:" + str(_sel_t))     # vừa chọn: món thiếu nháy đỏ
			bb.fx = "|".join(bf)
			var op := "1" if good else "0.18"   # món thiếu: bóng trong suốt, chỉ còn viền + vệt sáng
			var ic := _icn(cx, cy, s * 0.8, id)
			if not good:
				ic.css["opacity"] = "0.6"   # món thiếu: hình đủ màu, mờ 60%
			bb.kids = [_vong(cx, cy, r, float(have) / maxf(1.0, need), GREEN if good else "rgb(226,112,18)"), _dic(cx - s * 0.5, cy - s * 0.5, s, BONG % [op, op, op]), ic]
			g.kids.append(bb)
	g.kids.append(tru)
	if ok:
		g.kids.append(_dtick(x + w - 18.0, by + h - 18.0, 18.0))
	if pl != null and o.get("hot", -1) == G.day():
		var tm := _tem(x - 2.0, by + h * 0.45)
		tm.fx = "rung"   # đơn gấp: tem rung
		g.kids.append(tm)
	if pl == null:   # khách đang tới: giỏ mờ (đế giữ nguyên)
		g.css["opacity"] = "0.45"
	out.append(g)
	# tên khách + sao cấp giỏ (★ = cấp), dưới kệ
	var nx := x + (w - cw) * 0.5
	var ny := y + GT + w * DE_A + 4.0
	if pl == null:
		var wt: String = "Khách mới · " + U.rf((float(o.w) - G._now_ms()) / 1000.0)
		out.append(_dt(nx, ny, cw, 14.0, _fitw(wt, 10.5, 800, cw - 4.0), 10.5, 800, SUB))
	else:
		var sw := c * 11.0 + 2.0
		var nm: String = _fitw(String(o.who), 10.5, 800, cw - 4.0 - sw)
		var nw: float = Box.text_w(nm, 10.5, 800) + 1.0
		var sx := nx + (cw - nw - sw) * 0.5
		out.append(_dt(sx, ny, nw, 14.0, nm, 10.5, 800, BROWN, "left"))
		for q in c:   # sao cấp giỏ: vàng đậm viền nâu
			out.append(_dic(sx + nw + 2.0 + q * 11.0, ny + 1.5, 11.0, SAO))
	if is_sel:   # mũi tên vàng dưới tên: dải đáy đang là của giỏ này
		var ar := _dic(x + w * 0.5 - 6.0, ny + 15.0, 12.0, MUI)
		ar.r = [x + w * 0.5 - 6.0, ny + 15.0, 12.0, 7.0]
		out.append(ar)
	var hit := _dbx(nx, y, cw, GT + w * DE_A + TEN_H, "rgba(0, 0, 0, 0)", 0.0)   # chạm cả ô giỏ: chọn đơn
	var ff := f
	hit.act = func():
		sel = ff
		_sel_t = Time.get_ticks_msec() / 1000.0
		_build()
	out.append(hit)
	return out

func _face(who: String) -> String:   # chân dung tròn chung của xóm (vlface/m*), cố định theo tên khách
	return "res://ui/img/vlface/m" + str(absi(who.hash()) % 8) + ".webp"

func _foot_h(o: Dictionary, pl) -> float:   # cao dải đáy: đầu 46 + dòng món + nút 30
	if pl == null:
		return FW
	return 46.0 + o.items.size() * (IR + 2.0) + 4.0 + 30.0

func _foot(f: int, o: Dictionary, pl) -> Array:   # dải chi tiết đáy của đơn đang chọn (y từ 0, cao _foot_h)
	var out := [_dbx(X0, 0.0, XW, 1.5, GOLD_L, 0.0)]
	var who := String(o.get("who", ""))
	var fr := _dbx(X0, 6.0, 34.0, 34.0, "rgb(243, 230, 200)", 17.0, _cpx(2.0) + " solid rgb(255, 255, 255)", "0px 0px 0px 2px rgb(232, 160, 32)")
	fr.kids = [_pic(X0 + 2.0, 8.0, 30.0, 30.0, _face(who))]
	out.append(fr)
	var tw := XW - 42.0 - 90.0
	out.append(_dt(X0 + 42.0, 5.0, tw, 18.0, _fitw(who, 14.0, 800, tw), 14.0, 800, BROWN, "left"))
	if pl == null:   # khách đang tới
		var s: float = (float(o.w) - G._now_ms()) / 1000.0
		out.append(_dt(X0 + 42.0, 23.0, tw + 90.0, 16.0, "Khách mới tới sau " + U.rf(s), 12.0, 700, SUB, "left"))
		out.append_array(_bar(X0, 58.0, XW, clampf(1.0 - s * 1000.0 / G.Y8, 0.0, 1.0), 5.0))
		if src == "":
			var b := _btn(X0, 80.0, XW, 30.0, "", func(): G.call_now(f), "plain")
			var ri: Array = _rowi(0.0, 0.0, 30.0, ["Gọi ngay · " + str(G.call_cost(o)), "i:pearl"], 14.0, 800, BROWN)
			b.kids = []
			var sx := X0 + (XW - float(ri[1])) * 0.5
			for k in ri[0]:
				Snap._move(k, Vector2(sx, 80.0))
				b.kids.append(k)
			out.append(b)
		return out
	out.append(_dt(X0 + 42.0, 23.0, tw, 16.0, _fitw(String(o.shop), 12.0, 700, tw), 12.0, 700, SUB, "left"))
	# thưởng: xu + sao xanh, hai dòng bên phải
	var s1: String = "+" + G.fmt_n(int(o.reward))
	var s2 := "+" + str(maxi(3, int(round(float(o.reward) / 12.0))))
	var rw: Array = _rowi(0.0, 0.0, 18.0, [s1, "c"], 14.0, 800, "rgb(214, 128, 20)")
	var re: Array = _rowi(0.0, 0.0, 18.0, [s2, "i:pic:res://ui/img/bong/sao_xanh.png"], 14.0, 800, XP_C)
	for k in rw[0]:
		Snap._move(k, Vector2(X0 + XW - float(rw[1]), 5.0))
		out.append(k)
	for k in re[0]:
		Snap._move(k, Vector2(X0 + XW - float(re[1]), 23.0))
		out.append(k)
	# từng món một dòng: hình, tên, có/cần (đủ: xanh + tích; thiếu: đỏ)
	var iy := 46.0
	for q in o.items.size():
		var id: String = String(o.items[q][0])
		var need := int(o.items[q][1])
		var have: int = int(pl.have[q])
		var good := have >= need
		var row := _dbx(X0, iy, XW, IR, "rgb(230, 245, 222)" if good else "rgb(253, 231, 226)", 7.0)   # nền phẳng dòng món (đủ xanh nhạt / thiếu hồng nhạt); chữ là con của nền
		var qs: String = G.fmt_n(have) + "/" + str(need)
		var qw: float = Box.text_w(qs, 12.0, 800) + 2.0
		var rx0 := X0 + XW - 8.0 - (16.0 if good else 0.0)
		var nw := rx0 - qw - X0 - 36.0
		row.kids = [_icn(X0 + 15.0, iy + IR * 0.5, 22.0, id),
			_dt(X0 + 30.0, iy, nw, IR, _fitw(String(G.item_name(id)), 12.0, 700, nw), 12.0, 700, BROWN, "left"),
			_dt(rx0 - qw, iy, qw, IR, qs, 12.0, 800, GREEN if good else DOWN_C, "right")]
		if good:
			row.kids.append(_dtick(X0 + XW - 20.0, iy + (IR - 13.0) * 0.5, 13.0))
		row.kids.append(_dbx(X0, iy + 4.0, 3.0, IR - 8.0, GREEN if good else DOWN_C, 1.5))   # vạch màu mép trái
		out.append(row)
		iy += IR + 2.0
	# nút: Giao hàng / Đi lấy + bù sen, Đổi
	var by := iy + 4.0
	var bh := 30.0
	var rx := X0 + XW
	if src == "":
		var conf: bool = U.od_ud.i == f
		var dw := 62.0 if conf else 56.0
		rx -= dw
		out.append(_b14(rx, by, dw, bh, "Đổi?" if conf else "Đổi", func():
			if U.od_ud.i == f and G._now_ms() < float(U.od_ud.t):   # chạm lần 2: giỏ cũ trượt ra, giỏ mới trượt vào
				_doi(f)
				_swap[f] = Time.get_ticks_msec() / 1000.0
			U._od_swap(f), "red" if conf else "plain"))
		rx -= 8.0
	if pl.ok:
		out.append(_b14(X0, by, rx - X0, bh, "Giao hàng", func():
			_giao(f)
			_drop[f] = Time.get_ticks_msec() / 1000.0
			U._od_deliver(f)))
	else:
		var cost: int = G.lack_cost(pl.miss) if not pl.miss.is_empty() and src == "" else 0
		if cost > 0:
			var cs := str(cost)
			var cwid: float = Box.text_w(cs, 14.0, 800) + 40.0
			rx -= cwid
			var enough: bool = int(G.g.ngoc) >= cost
			var sb := _btn(rx, by, cwid, bh, "", func(): U._od_lack_btn(f), "plain")
			sb.kids = []
			var ri: Array = _rowi(0.0, 0.0, bh, ["i:pearl", cs], 14.0, 800, BROWN if enough else SUB)
			var sx := rx + (cwid - float(ri[1])) * 0.5
			for k in ri[0]:
				Snap._move(k, Vector2(sx, by))
				sb.kids.append(k)
			if not enough:
				sb.css["opacity"] = "0.6"
			out.append(sb)
			rx -= 8.0
		out.append(_vang(X0, by, rx - X0, bh, "Đi lấy ›", func(): U._od_get(f)))
	return out

func _b14(x: float, y: float, w: float, h: float, t: String, cb, kind := "go") -> Dictionary:   # nút chung, chữ 14 (cả hàng nút một cỡ)
	var b := _btn(x, y, w, h, t, cb, kind)
	if b.kids.size() and b.kids[0] is Dictionary and b.kids[0].has("css"):
		b.kids[0].css["font-size"] = _cpx(14.0)
	return b

func _vang(x: float, y: float, w: float, h: float, t: String, cb) -> Dictionary:   # nút chính vàng nổi (Đi lấy)
	var b := _dbx(x, y, w, h, "rgb(250, 200, 80)", 10.0, _cpx(2.0) + " solid rgb(255, 240, 190)", "0px 0px 0px 2px rgb(200, 136, 28), 0px 3px 0px 1px rgb(164, 102, 14)")
	b.css["background-image"] = "linear-gradient(rgb(255, 222, 120) 0%, rgb(244, 178, 52) 100%)"
	b.kids = [_dt(x, y, w, h, t, 14.0, 800, "rgb(106, 58, 8)")]
	b.act = cb
	return b

func _gnode(f: int) -> Control:   # khối giỏ của đơn f đang hiện
	if inner == null:
		return null
	for c in inner._kids.get_children():
		if c is Control and int(c.get_meta("snap", {}).get("gk", -1)) == f:
			return c
	return null

func _fly(g: Control, bub: bool) -> Control:   # bản sao giỏ (lớp sau / trước, bóng nếu bub) trên lớp hiệu ứng, cùng chỗ trên màn
	var L: CanvasLayer = U.fx_layer()
	var xf: Transform2D = g.get_global_transform_with_canvas()
	var fly := Control.new()
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.position = xf.origin
	fly.scale = xf.get_scale()
	fly.size = g.size
	fly.pivot_offset = g.size * 0.5
	L.add_child(fly)
	for k in g.kids():
		var sn: Dictionary = k.get_meta("snap", {})
		var src_k: Array = []
		if sn.has("pic"):
			src_k = [k]
		elif bub and String(sn.get("fx", "")).begins_with("nhap:"):
			for kk in k.kids():
				if kk.get_meta("snap", {}).has("ic"):
					src_k = [kk]
		for kk in src_k:
			var s2: Dictionary = kk.get_meta("snap", {})
			var tr := TextureRect.new()
			tr.texture = Css.image(String(s2.pic)) if s2.has("pic") else U.item_ic(String(s2.ic), kk.size.x * xf.get_scale().x)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.position = kk.get_global_transform_with_canvas().origin - xf.origin
			tr.position /= xf.get_scale()
			tr.size = kk.size
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fly.add_child(tr)
	return fly

func _doi(f: int) -> void:   # đổi đơn: giỏ cũ (cả món) trượt sang trái rồi mờ đi
	var g := _gnode(f)
	if g == null:
		return
	var fly := _fly(g, true)
	var a := fly.position
	var tw := fly.create_tween()
	tw.tween_property(fly, "position", a + Vector2(-70.0 * Css.K, 0.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(fly, "modulate:a", 0.0, 0.35).set_delay(0.1)
	tw.tween_callback(fly.queue_free)

func _giao(f: int) -> void:   # giao: bong bóng vỡ bụp thành bọt, giỏ nhấc khỏi đế bay vòng lên ô xu, hoa giấy + xu + sao bay theo đường cong
	var g := _gnode(f)
	if g == null:
		return
	var L: CanvasLayer = U.fx_layer()
	var xf: Transform2D = g.get_global_transform_with_canvas()
	var fly := _fly(g, false)
	var gc: Vector2 = xf * (g.size * 0.5)
	for k in g.kids():
		var sn: Dictionary = k.get_meta("snap", {})
		if String(sn.get("fx", "")).begins_with("nhap:"):   # bong bóng: vỡ thành bọt, hình món phồng lên rồi tan
			var bc: Vector2 = k.get_global_transform_with_canvas() * (k.size * 0.5)
			_bot(L, bc, k.size.x * xf.get_scale().x)
			for kk in k.kids():
				var s2: Dictionary = kk.get_meta("snap", {})
				if s2.has("ic"):
					var t: Texture2D = U.item_ic(String(s2.ic), kk.size.x * xf.get_scale().x)
					if t != null:
						var ir := TextureRect.new()
						ir.texture = t
						ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
						ir.size = kk.size * xf.get_scale()
						ir.pivot_offset = ir.size * 0.5
						ir.position = bc - ir.size * 0.5
						ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
						L.add_child(ir)
						var tw0 := ir.create_tween()
						tw0.tween_property(ir, "scale", Vector2(1.5, 1.5), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
						tw0.parallel().tween_property(ir, "modulate:a", 0.0, 0.3).set_delay(0.1)
						tw0.tween_callback(ir.queue_free)
	_hoa(L, gc)
	_burst(gc)
	var tg: Control = U.hid.get("#coinsPill")
	var dst: Vector2 = tg.get_global_rect().get_center() if tg != null and is_instance_valid(tg) else Vector2(gc.x, 0.0)
	var a := fly.position
	var b := dst - fly.size * fly.scale * 0.5
	var ctl := Vector2((a.x + b.x) * 0.5 - 60.0 * Css.K, minf(a.y, b.y) - 90.0 * Css.K)
	var tw := fly.create_tween()
	tw.tween_property(fly, "position", a - Vector2(0, 10.0 * Css.K), 0.16).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var a2 := a - Vector2(0, 10.0 * Css.K)
	var sc0 := xf.get_scale()
	var step := func(t: float):
		var u := 1.0 - t
		fly.position = u * u * a2 + 2.0 * u * t * ctl + t * t * b
		fly.scale = sc0 * lerpf(1.0, 0.25, t)
		fly.rotation = -0.5 * t
		fly.modulate.a = 1.0 - maxf(0.0, t - 0.7) / 0.3
	tw.tween_method(step, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(fly.queue_free)

func _bot(L: CanvasLayer, c: Vector2, d: float) -> void:   # bọt vỡ (hạt trắng tung ra một lần)
	var p := CPUParticles2D.new()
	p.texture = dot_tex("tron")
	p.position = c
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 0.5
	p.spread = 180.0
	p.gravity = Vector2(0, 60.0 * Css.K)
	p.initial_velocity_min = d * 1.2
	p.initial_velocity_max = d * 2.4
	p.scale_amount_min = d / 32.0 * 0.12
	p.scale_amount_max = d / 32.0 * 0.26
	var rp := Gradient.new()
	rp.set_color(0, Color(1, 1, 1, 0.95))
	rp.set_color(1, Color(0.85, 0.93, 1.0, 0.0))
	p.color_ramp = rp
	p.emitting = true
	L.add_child(p)
	p.finished.connect(p.queue_free)

func _hoa(L: CanvasLayer, c: Vector2) -> void:   # hoa giấy nổ nhẹ
	var p := CPUParticles2D.new()
	p.position = c
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 28
	p.lifetime = 1.1
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 320.0 * Css.K)
	p.initial_velocity_min = 120.0 * Css.K
	p.initial_velocity_max = 220.0 * Css.K
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 3.0 * Css.K
	p.scale_amount_max = 5.0 * Css.K
	var cr := Gradient.new()
	cr.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	cr.colors = PackedColorArray([Color8(232, 64, 52), Color8(250, 196, 40), Color8(70, 180, 90), Color8(60, 140, 230), Color8(240, 120, 180)])
	p.color_initial_ramp = cr
	p.emitting = true
	L.add_child(p)
	p.finished.connect(p.queue_free)

func _burst(c: Vector2) -> void:   # xu bay về ô xu, sao xanh bay về ô cấp, theo đường cong (tung ra rồi vòng lên)
	var L: CanvasLayer = U.fx_layer()
	var tg := {"coin": U.hid.get("#coinsPill"), "sao": U.hid.get("#pcAv")}
	var n := 10
	for q in n + 4:
		var is_c := q < n
		var t: Control = tg["coin" if is_c else "sao"]
		var dst := (t.get_global_rect().get_center() if t != null and is_instance_valid(t) else Vector2(c.x, 0.0))
		var s := 20.0 * Css.K
		var tr := TextureRect.new()
		tr.texture = Css.svg_tex(Css.img_svg("res://ui/img/coin.webp" if is_c else "res://ui/img/bong/sao_xanh.png"), s, s)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.size = Vector2(s, s)
		tr.pivot_offset = tr.size * 0.5
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ang := TAU * q / float(n + 4)
		var a := c - tr.size * 0.5
		var mid := a + Vector2(cos(ang), sin(ang)) * randf_range(30.0, 60.0) * Css.K
		var b := dst - tr.size * 0.5
		var ctl := Vector2(mid.x + randf_range(-50.0, 50.0) * Css.K, minf(mid.y, b.y) - randf_range(20.0, 70.0) * Css.K)
		tr.position = a
		tr.modulate.a = 0.0
		L.add_child(tr)
		var tw := tr.create_tween()
		tw.tween_interval(0.18)
		tw.tween_property(tr, "modulate:a", 1.0, 0.05)
		tw.tween_property(tr, "position", mid, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.03 * q)
		var st := func(u: float):
			var v := 1.0 - u
			tr.position = v * v * mid + 2.0 * v * u * ctl + u * u * b
			tr.scale = Vector2.ONE * lerpf(1.0, 0.6, u)
		tw.tween_method(st, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(tr.queue_free)

func _tem(x: float, y: float) -> Dictionary:   # tem "GẤP": nền đỏ viền trắng, nghiêng
	var tw := 34.0
	var th := 16.0
	var a := -0.26
	var bw := absf(tw * cos(a)) + absf(th * sin(a))   # khung bao của tem đã nghiêng (Snap tự tính lại hộp thật)
	var bh := absf(tw * sin(a)) + absf(th * cos(a))
	var t := _dbx(x, y, bw, bh, DOWN_C, 4.0, _cpx(1.5) + " solid rgb(255, 255, 255)", "0px 1px 2px rgba(90, 20, 10, 0.45)")
	t.css["transform"] = "matrix(%f, %f, %f, %f, 0, 0)" % [cos(a), sin(a), -sin(a), cos(a)]
	t.kids = [_dt(x, y, bw, bh, "GẤP", 10.5, 900, "rgb(255, 255, 255)")]
	return t

func _menu(y: float) -> Array:   # bảng quán: món giờ này
	var WQ = G.w_all.WQ
	var ids: Array = WQ.menu_now(src)
	var out := []
	var t: String = WQ.menu_title(src)
	var per := 8
	var iw := (XW - 16.0 - (per - 1) * 4.0) / per
	var rows := ceili(ids.size() / float(per)) if ids.size() else 0
	var h := 30.0 + rows * (iw + 4.0) + 4.0
	var c := _chip(X0, y, XW, h, "fut")
	out.append(c)
	out.append(_dt(X0 + 8.0, y + 6.0, XW - 16.0, 16.0, _fitw(t, 12.0, 700, XW - 16.0), 12.0, 700, BROWN, "left"))
	for q in ids.size():
		var cx := X0 + 8.0 + (q % per) * (iw + 4.0) + iw * 0.5
		var cy := y + 28.0 + (q / per) * (iw + 4.0) + iw * 0.5
		out.append(_icn(cx, cy, iw - 4.0, String(ids[q])))
	return [out, y + h]
