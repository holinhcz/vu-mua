extends "res://logic/ui_kbang.gd"
# (11-27) ĐƠN HÀNG trên KHUNG CHUNG (ui_kbang: khung sen, chip, thẻ, đáy chung), thay bản chụp web (ord / ord_ok / ord_wait...).
#   Đầu (cố định): "Giao được N/M đơn" + thanh + "đã giao D"; bảng quán: hàng chip (sao, danh tiếng, giá...) dưới đầu.
#   Thân (cuộn): thẻ đơn 2 cột (cao theo số món, thẻ cùng hàng cao bằng): chân dung khách + tên + quán, nhãn Đổi trên mép,
#   tem GẤP góc; dòng món (ô hình to, tên, có/cần); dải thưởng xu + sao xanh; nút Giao hàng / Đi lấy + bù sen;
#   thẻ đủ hàng viền cam lửa nhấp nháy; khách đang tới: giờ chờ, thanh, Gọi.
#   Bảng quán: khung "món giờ này" dưới thẻ.
# Logic dùng lại của ui.gd: U.od_src, U._od_order, U._od_colors, U._od_deliver / _od_get / _od_lack_btn / _od_swap, U.od_ud.

const CG2 := 8.0
const TOP := 9.0      # trên hàng thẻ đầu (tem / nhãn ngồi trên mép thẻ)
const RG := 14.0      # cách giữa hai hàng thẻ (nhãn Đổi hàng dưới không chạm thẻ trên)
const HEAD := 26.0

var src := ""

func _init(ui) -> void:
	super(ui)
	snapcut = false

func open(s := "") -> void:
	src = s
	U.od_src = s
	on = true
	scroll = 0.0
	sig = ""
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
	return JSON.stringify([src, L, G.g.barn, int(G.g.ngoc), int(G.g.delivered), U.od_ud, w, G.day()])

# ------------------------------------------------------------------ dựng
func _build() -> void:
	U.od_on = true
	sig = _sig()
	var sh := _kshell([], "", func(_k): pass)
	var n: Dictionary = sh[0]
	var vt: Dictionary = sh[1]
	var lp: Array = U._od_order()
	var L: Array = lp[0]
	var plan: Array = lp[1]
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
	var out := []
	var cw := (XW - CG2) / 2.0
	var cols: Dictionary = U._od_colors()
	var y := TOP   # chừa chỗ tem GẤP / nhãn Đổi ngồi trên mép thẻ hàng đầu
	var q := 0
	while q < L.size():
		var row := [L[q]]
		if q + 1 < L.size():
			row.append(L[q + 1])
		var h := 0.0
		for e in row:
			h = maxf(h, _card_h(U._od_list()[e[1]], plan[e[1]]))
		for j in row.size():
			var f: int = row[j][1]
			out.append_array(_ocard(X0 + j * (cw + CG2), y, cw, h, f, U._od_list()[f], plan[f], String(cols.get(f, U.OD_HD[0]))))
		y += h + RG
		q += 2
	if src != "":
		var mn := _menu(y)
		out.append_array(mn[0])
		y = float(mn[1]) + RG
	if L.is_empty():
		out.append(_dt(X0, 10.0, XW, 16.0, "Chưa có đơn nào.", 12.0, 600, SUB))
		y = 40.0
	_kmount(n, vt, float(vt.r[1]), out, y - RG + 4.0)

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

func _card_h(o: Dictionary, pl) -> float:
	if pl == null:
		return 104.0
	return P + FACE + G2 + o.items.size() * (IT + G2) + RW_H + G2 + BT_H + P

const P := 8.0        # lề trong thẻ
const G2 := 6.0       # cách giữa các dòng trong thẻ
const FACE := 38.0    # chân dung khách
const IT := 34.0      # ô hình món
const RW_H := 26.0    # dải thưởng
const BT_H := 26.0    # nút
const FIRE := "rgb(238, 104, 28)"   # cam lửa (như ô mốc Nhiệm vụ)
const GOLD_L := "rgb(214, 176, 104)"   # viền ô hình món (như khung chi tiết Kho)
const XP_C := "rgb(47, 127, 214)"   # chữ EXP xanh (sao xanh)

func _face(who: String) -> String:   # chân dung tròn chung của xóm (vlface/m*), cố định theo tên khách
	return "res://ui/img/vlface/m" + str(absi(who.hash()) % 8) + ".webp"

func _ocard(x: float, y: float, w: float, h: float, f: int, o: Dictionary, pl, col: String) -> Array:
	if pl == null:
		return _wait(x, y, w, h, f, o)
	var ok: bool = pl.ok
	var out := []
	if ok:   # đủ hàng: viền cam lửa sáng nhấp nháy quanh thẻ
		var gl := _dbx(x - 2.0, y - 2.0, w + 4.0, h + 4.0, "rgba(0, 0, 0, 0)", 10.0, _cpx(2.0) + " solid " + FIRE, "0px 0px 8px rgba(238, 104, 28, 0.85)")
		gl.fx = "nhay"
		out.append(gl)
	out.append(_chip(x, y, w, h, "sel" if ok else "fut"))
	# đầu thẻ: chân dung, tên, quán
	var who := String(o.who)
	var fr := _dbx(x + P, y + P, FACE, FACE, col, FACE * 0.5, _cpx(2.0) + " solid rgb(255, 255, 255)", "0px 1px 2px rgba(90, 60, 20, 0.35)")
	fr.kids = [_pic(x + P + 2.0, y + P + 2.0, FACE - 4.0, FACE - 4.0, _face(who))]
	out.append(fr)
	var tx := x + P + FACE + 6.0
	var tw := x + w - P - tx
	out.append(_dt(tx, y + P + 2.0, tw, 16.0, _fitw(who, 12.0, 800, tw), 12.0, 800, BROWN, "left"))
	out.append(_dt(tx, y + P + 20.0, tw, 14.0, _fitw(String(o.shop), 10.5, 600, tw), 10.5, 600, SUB, "left"))
	if o.get("hot", -1) == G.day():   # đơn gấp: tem đỏ "GẤP" dán chéo góc trên trái
		out.append(_tem(x - 4.0, y - 6.0))
	if src == "":   # đổi đơn: nhãn nhỏ ngồi trên mép trên phải thẻ (không lấn chỗ tên)
		var conf: bool = U.od_ud.i == f
		var bw := 44.0 if conf else 36.0
		out.append(_btn(x + w - P - bw, y - 8.0, bw, 18.0, "Đổi?" if conf else "Đổi", func(): U._od_swap(f), "red" if conf else "plain"))
	# món: ô hình to (như thẻ Kho), tên, còn thiếu / đủ
	var iy := y + P + FACE + G2
	for q in o.items.size():
		var id: String = String(o.items[q][0])
		var need := int(o.items[q][1])
		var have: int = int(pl.have[q])   # phần hàng chia cho đơn này (không phải cả kho)
		var good := have >= need
		var tile := _dbx(x + P, iy, IT, IT, "rgb(255, 252, 244)", 7.0, "1px solid " + (GREEN if good else GOLD_L))
		tile.kids = [_icn(x + P + IT * 0.5, iy + IT * 0.5, 28.0, id)]
		if good:
			tile.kids.append(_dtick(x + P + IT - 10.0, iy - 3.0, 13.0))
		out.append(tile)
		var nx := x + P + IT + 6.0
		var nw := x + w - P - nx
		var nm: String = G.item_name(id)
		var hot: bool = G.hot_x(id) > 1.0
		var nmw := minf(Box.text_w(nm, 12.0, 700) + 1.0, nw - (16.0 if hot else 0.0))
		out.append(_dt(nx, iy + 1.0, nmw, 16.0, _fitw(nm, 12.0, 700, nmw), 12.0, 700, BROWN, "left"))
		if hot:   # món được giá: 🔥 sát sau tên
			out.append(_dt(nx + nmw + 1.0, iy + 1.0, 14.0, 16.0, "🔥", 10.5, 600, DOWN_C, "left"))
		var qs: String = G.fmt_n(have) + "/" + str(need)
		out.append(_dt(nx, iy + 18.0, nw, 14.0, qs, 12.0, 800, GREEN if good else DOWN_C, "left"))
		iy += IT + G2
	# thưởng: dải nền nhạt, xu vàng + sao xanh to
	var s1: String = "+" + G.fmt_n(int(o.reward))
	var s2 := "+" + str(maxi(3, int(round(float(o.reward) / 12.0))))
	out.append(_dbx(x + P, iy, w - 2.0 * P, RW_H, "rgb(253, 240, 208)", 7.0))
	var rw: Array = _rowi(0.0, 0.0, RW_H, [s1, "c"], 14.0, 800, "rgb(214, 128, 20)")
	var re: Array = _rowi(0.0, 0.0, RW_H, [s2, "i:pic:res://ui/img/bong/sao_xanh.png"], 14.0, 800, XP_C)
	var rgap := 12.0
	var rx := x + (w - float(rw[1]) - rgap - float(re[1])) * 0.5
	for k in rw[0]:
		Snap._move(k, Vector2(rx, iy))
		out.append(k)
	for k in re[0]:
		Snap._move(k, Vector2(rx + float(rw[1]) + rgap, iy))
		out.append(k)
	# nút
	var by := iy + RW_H + G2
	if ok:
		out.append(_btn(x + P, by, w - 2.0 * P, BT_H, "Giao hàng", func(): U._od_deliver(f)))
	else:
		var cost: int = G.lack_cost(pl.miss) if not pl.miss.is_empty() and src == "" else 0
		var gw := w - 2.0 * P
		if cost > 0:
			var cs := str(cost)
			var cwid: float = Box.text_w(cs, 12.0, 800) + 34.0
			gw -= cwid + 6.0
			var enough: bool = int(G.g.ngoc) >= cost
			var sb := _btn(x + w - P - cwid, by, cwid, BT_H, "", func(): U._od_lack_btn(f), "plain")
			sb.kids = []
			var ri: Array = _rowi(0.0, 0.0, BT_H, ["i:pearl", cs], 12.0, 800, BROWN if enough else SUB)
			var sx := x + w - P - cwid + (cwid - float(ri[1])) * 0.5
			for k in ri[0]:
				Snap._move(k, Vector2(sx, by))
				sb.kids.append(k)
			if not enough:
				sb.css["opacity"] = "0.6"
			out.append(sb)
		out.append(_btn(x + P, by, gw, BT_H, "Đi lấy ›", func(): U._od_get(f), "plain"))
	return out

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

const DOWN_C := "rgb(214, 69, 65)"

func _wait(x: float, y: float, w: float, h: float, f: int, o: Dictionary) -> Array:   # khách đang tới
	var now: float = G._now_ms()
	var s: float = (float(o.w) - now) / 1000.0
	var out := []
	var c := _chip(x, y, w, h, "miss")
	c.css["opacity"] = "0.85"
	out.append(c)
	var cy := y + h * 0.5 - (34.0 if src == "" else 18.0)
	out.append(_dt(x, cy, w, 16.0, "Khách mới · " + U.rf(s), 12.0, 700, BROWN))
	var p := clampf(1.0 - s * 1000.0 / G.Y8, 0.0, 1.0)
	out.append_array(_bar(x + 14.0, cy + 22.0, w - 28.0, p, 5.0))
	if src == "":
		var cost := str(G.call_cost(o))
		var bw := w - 24.0
		var b := _btn(x + 12.0, cy + 36.0, bw, 26.0, "", func(): G.call_now(f), "plain")
		var ri: Array = _rowi(0.0, 0.0, 26.0, ["Gọi · " + cost, "i:pearl"], 12.0, 800, BROWN)
		b.kids = []
		var sx := x + 12.0 + (bw - float(ri[1])) * 0.5
		for k in ri[0]:
			Snap._move(k, Vector2(sx, cy + 36.0))
			b.kids.append(k)
		out.append(b)
	return out

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
