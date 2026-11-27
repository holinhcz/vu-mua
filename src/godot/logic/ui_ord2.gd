extends "res://logic/ui_kbang.gd"
# (11-27) ĐƠN HÀNG trên KHUNG CHUNG (ui_kbang: khung sen, chip, thẻ, đáy chung), thay bản chụp web (ord / ord_ok / ord_wait...).
#   Đầu (cố định): "Giao được N/M đơn" + thanh + "đã giao D"; bảng quán: hàng chip (sao, danh tiếng, giá...) dưới đầu.
#   Thân (cuộn): thẻ đơn 2 cột (cao theo số món, thẻ cùng hàng cao bằng): đầu thẻ chữ cái + tên + nghề + đổi đơn,
#   dòng món (hình, tên, có/cần), thưởng xu + sao, nút Giao hàng / Đi lấy + bù sen; khách đang tới: giờ chờ, thanh, Gọi.
#   Bảng quán: khung "món giờ này" dưới thẻ.
# Logic dùng lại của ui.gd: U.od_src, U._od_order, U._od_colors, U._od_deliver / _od_get / _od_lack_btn / _od_swap, U.od_ud.

const CG2 := 8.0
const IH := 24.0      # dòng món
const HEAD := 26.0
const STAR := "res://ui/img/bong/sao.png"

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
	var y := 0.0
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
		y += h + CG2
		q += 2
	if src != "":
		var mn := _menu(y)
		out.append_array(mn[0])
		y = float(mn[1]) + CG2
	if L.is_empty():
		out.append(_dt(X0, 10.0, XW, 16.0, "Chưa có đơn nào.", 12.0, 600, SUB))
		y = 40.0
	_kmount(n, vt, float(vt.r[1]), out, y - CG2 + 2.0)

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
	return 40.0 + o.items.size() * (IH + 4.0) + 26.0 + 32.0

func _ocard(x: float, y: float, w: float, h: float, f: int, o: Dictionary, pl, col: String) -> Array:
	if pl == null:
		return _wait(x, y, w, h, f, o)
	var ok: bool = pl.ok
	var out := []
	var c := _chip(x, y, w, h, "sel" if ok else "fut")
	out.append(c)
	# đầu thẻ: chữ cái, tên, nghề, đổi đơn
	var nm: String = String(o.who).split(" ")[-1]
	var av := _dbx(x + 8.0, y + 8.0, 26.0, 26.0, col, 13.0)
	av.kids = [_dt(x + 8.0, y + 8.0, 26.0, 26.0, nm.substr(0, 1), 12.0, 800, "rgb(255, 255, 255)")]
	out.append(av)
	var hot: bool = o.get("hot", -1) == G.day()
	var sw := src == ""
	if hot:   # đơn gấp: lửa nhỏ góc chữ cái (không lấn chỗ tên)
		out.append(_dt(x + 24.0, y + 2.0, 16.0, 14.0, "🔥", 10.5, 600, BROWN))
	var tw := w - 42.0 - (44.0 if sw else 6.0)
	var who := String(o.who)
	out.append(_dt(x + 40.0, y + 6.0, tw, 16.0, _fitw(who, 12.0, 800, tw), 12.0, 800, BROWN, "left"))
	out.append(_dt(x + 40.0, y + 22.0, tw, 13.0, _fitw(String(o.shop), 10.5, 600, tw), 10.5, 600, SUB, "left"))
	if sw:
		var conf: bool = U.od_ud.i == f
		var bw := 44.0 if conf else 38.0
		var b := _btn(x + w - bw - 6.0, y + 8.0, bw, 24.0, "Đổi?" if conf else "Đổi", func(): U._od_swap(f), "red" if conf else "plain")
		out.append(b)
	# món
	var iy := y + 40.0
	for it in o.items:
		var id: String = String(it[0])
		var need := int(it[1])
		var have := int(G.g.barn.get(id, 0))
		var good := have >= need
		var r := _dbx(x + 6.0, iy, w - 12.0, IH, "rgb(226, 242, 212)" if good else "rgb(248, 238, 218)", 6.0)   # trong thẻ: nền phẳng, không viền
		var qs: String = G.fmt_n(have) + "/" + str(need)
		var qw: float = Box.text_w(qs, 10.5, 800) + 2.0
		var nw := w - 12.0 - 30.0 - qw - 10.0
		r.kids = [_icn(x + 20.0, iy + IH * 0.5, 18.0, id),
			_dt(x + 34.0, iy, nw, IH, _fitw(G.item_name(id), 10.5, 600, nw), 10.5, 600, BROWN, "left"),
			_dt(x + w - 10.0 - qw, iy, qw, IH, qs, 10.5, 800, GREEN if good else DOWN_C, "right")]
		if G.hot_x(id) > 1.0:
			r.kids.append(_dt(x + w - 14.0 - qw - 14.0, iy, 14.0, IH, "🔥", 9.0, 600, DOWN_C))
		out.append(r)
		iy += IH + 4.0
	# thưởng
	var s1: String = "+" + G.fmt_n(int(o.reward))
	var s2 := "+" + str(maxi(3, int(round(float(o.reward) / 12.0))))
	var rw: Array = _rowi(0.0, 0.0, 20.0, [s1, "c", "   ", s2, "s"], 12.0, 800, "rgb(214, 128, 20)")
	var rx := x + (w - float(rw[1])) * 0.5
	var ry := y + h - 32.0 - 24.0
	for k in rw[0]:
		Snap._move(k, Vector2(rx, ry))
		out.append(k)
	# nút
	var by := y + h - 32.0
	if ok:
		out.append(_btn(x + 6.0, by, w - 12.0, 26.0, "Giao hàng", func(): U._od_deliver(f)))
	else:
		var cost: int = G.lack_cost(pl.miss) if not pl.miss.is_empty() and src == "" else 0
		var gw := w - 12.0
		if cost > 0:
			var cs := str(cost)
			var cwid: float = Box.text_w(cs, 12.0, 800) + 34.0
			gw -= cwid + 6.0
			var enough: bool = int(G.g.ngoc) >= cost
			var sb := _btn(x + w - 6.0 - cwid, by, cwid, 26.0, "", func(): U._od_lack_btn(f), "plain")
			sb.kids = []
			var ri: Array = _rowi(0.0, 0.0, 26.0, ["i:pearl", cs], 12.0, 800, BROWN if enough else SUB)
			var sx := x + w - 6.0 - cwid + (cwid - float(ri[1])) * 0.5
			for k in ri[0]:
				Snap._move(k, Vector2(sx, by))
				sb.kids.append(k)
			if not enough:
				sb.css["opacity"] = "0.6"
			out.append(sb)
		out.append(_btn(x + 6.0, by, gw, 26.0, "Đi lấy ›", func(): U._od_get(f), "plain"))
	return out

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
