extends "res://logic/ui_kbang.gd"
# (11-27) ĐƠN HÀNG = GIỎ HÀNG (khung chung ui_kbang: khung sen, đáy chung), không thẻ lồng trong bảng.
#   Đầu (cố định): "Giao được N/M đơn" + thanh + "đã giao D"; bảng quán: hàng chip (sao, danh tiếng, giá...) dưới đầu.
#   Thân (cuộn): mỗi đơn một đồ đựng nhìn nghiêng 2.5D (giỏ / thúng / rổ / mẹt theo quán), 3 cột, đặt thẳng trên nền bảng:
#     bong bóng món nằm trong lòng giỏ (chỉ hình món; vòng tiến độ có/cần quanh bóng; món thiếu bóng trong, hình mờ),
#     tên khách dưới giỏ; đủ hàng quầng xanh nhấp nháy + dấu tích; đơn gấp tem GẤP; giỏ đang chọn nhô lên + quầng vàng.
#   Đáy (cố định): chi tiết giỏ đang chọn: mặt khách, tên, quán, thưởng xu + sao xanh, từng món có/cần, nút Giao hàng /
#     Đi lấy + bù sen + Đổi; khách đang tới: giờ chờ, thanh, Gọi. Giao: xu + sao bay về ô xu / ô cấp.
#   Hình giỏ: 2 lớp (sau: quai + lòng giỏ, dưới bóng; trước: thân + vành trước, đè chân bóng), khung 100x80, miệng giỏ elip
#     tâm (50, GIO[k][0]) rx 44: ảnh res://ui/img/gio/<k>_sau.webp / _truoc.webp nếu có, không thì svg ui/svg/gio/.
#   Bảng quán: khung "món giờ này" dưới giỏ.
# Logic dùng lại của ui.gd: U.od_src, U._od_order, U._od_deliver / _od_get / _od_lack_btn / _od_swap, U.od_ud.

const HEAD := 26.0
const FOOT := 116.0   # dải chi tiết đáy
const GIO := {"gio": [32.0], "thung": [30.0], "ro": [36.0], "met": [50.0]}   # vành miệng (khung 100x80)
const BW := 90.0      # giỏ rộng (cao = 0,8 rộng)
const SZ := {1: 40.0, 2: 34.0, 3: 28.0}   # bong bóng theo số món
const XS := {1: [0.5], 2: [0.34, 0.66], 3: [0.22, 0.5, 0.78]}
const GOLD_L := "rgb(214, 176, 104)"
const XP_C := "rgb(47, 127, 214)"   # chữ EXP xanh (sao xanh)
const DOWN_C := "rgb(214, 69, 65)"

var src := ""
var sel := -1   # đơn đang chọn (chỉ số trong U._od_list)

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
	var L: Array = lp[0]
	var plan: Array = lp[1]
	if sel < 0 or sel >= U._od_list().size():
		sel = int(L[0][1]) if L.size() else -1
	sig = _sig()
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
		_kfix(n, vt, _foot(sel, U._od_list()[sel], plan[sel]), FOOT, true)
	var out := []
	var cw := XW / 3.0
	var bw := minf(BW, cw - 4.0)
	var ch := 4.0 + bw * 0.8 + 18.0
	var rows := ceili(L.size() / 3.0)
	if src == "" and rows > 0:   # giỏ giãn đều theo chiều cao thân (không dồn hết khoảng trống xuống dưới)
		ch = clampf(float(vt.r[3]) / rows, ch, ch + 18.0)
	for q in L.size():
		var f: int = L[q][1]
		out.append_array(_gio(X0 + (q % 3) * cw + (cw - bw) * 0.5, (q / 3) * ch, bw, cw, f, U._od_list()[f], plan[f]))
	var y := rows * ch
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

func _kind(o: Dictionary) -> String:   # đồ đựng theo quán: vựa / nhà hàng thúng, rau / phở / chè rổ, cơm / bánh mẹt, còn lại giỏ
	var t := String(o.get("shop", "")).to_lower()
	for k in [["vựa", "thung"], ["nhà hàng", "thung"], ["rau", "ro"], ["phở", "ro"], ["chè", "ro"], ["cơm", "met"], ["bánh", "met"]]:
		if t.find(k[0]) >= 0:
			return k[1]
	return "gio"

func _art(k: String, lop: String, x: float, y: float, w: float, h: float) -> Dictionary:   # một lớp hình giỏ: ảnh vẽ tay nếu có, không thì svg
	var pic := "res://ui/img/gio/" + k + "_" + lop + ".webp"
	if ResourceLoader.exists(pic) or FileAccess.file_exists(pic):
		return _pic(x, y, w, h, pic)
	var d := _dic(x, y, w, FileAccess.get_file_as_string("res://ui/svg/gio/" + k + "_" + lop + ".svg"))
	d.r = [x, y, w, h]
	return d

func _vong(cx: float, cy: float, r: float, p: float, col: String) -> Dictionary:   # vòng tiến độ quanh bong bóng (p 0..1, chạy từ đỉnh theo chiều kim đồng hồ)
	var a := TAU * clampf(p, 0.0, 1.0)
	var arc := ""
	if p >= 0.999:
		arc = "<circle cx=\"20\" cy=\"20\" r=\"18\" fill=\"none\" stroke=\"%s\" stroke-width=\"3.6\"/>" % col
	elif p > 0.001:
		arc = "<path d=\"M20 2 A18 18 0 %d 1 %.2f %.2f\" fill=\"none\" stroke=\"%s\" stroke-width=\"3.6\" stroke-linecap=\"round\"/>" % [1 if a > PI else 0, 20.0 + 18.0 * sin(a), 20.0 - 18.0 * cos(a), col]
	var sv := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 40 40\"><circle cx=\"20\" cy=\"20\" r=\"18\" fill=\"none\" stroke=\"rgb(255,255,255)\" stroke-opacity=\"0.7\" stroke-width=\"3.6\"/>" + arc + "</svg>"
	return _dic(cx - r, cy - r, r * 2.0, sv)

const BONG := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 40 40\"><defs><radialGradient id=\"g\" cx=\"0.38\" cy=\"0.32\" r=\"0.75\"><stop offset=\"0\" stop-color=\"rgb(255,255,255)\" stop-opacity=\"%s\"/><stop offset=\"0.6\" stop-color=\"rgb(236,244,252)\" stop-opacity=\"%s\"/><stop offset=\"1\" stop-color=\"rgb(200,220,240)\" stop-opacity=\"%s\"/></radialGradient></defs><circle cx=\"20\" cy=\"20\" r=\"19\" fill=\"url(#g)\" stroke=\"rgb(255,255,255)\" stroke-opacity=\"0.85\" stroke-width=\"1\"/><ellipse cx=\"13\" cy=\"10\" rx=\"5\" ry=\"3.2\" transform=\"rotate(-25 13 10)\" fill=\"rgb(255,255,255)\" fill-opacity=\"0.95\"/></svg>"
const SANG := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 80\"><defs><radialGradient id=\"g\"><stop offset=\"0\" stop-color=\"%s\" stop-opacity=\"0.85\"/><stop offset=\"1\" stop-color=\"%s\" stop-opacity=\"0\"/></radialGradient></defs><ellipse cx=\"50\" cy=\"42\" rx=\"50\" ry=\"40\" fill=\"url(#g)\"/></svg>"

func _gio(x: float, y: float, w: float, cw: float, f: int, o: Dictionary, pl) -> Array:   # một đơn: đồ đựng + bong bóng món + tên
	var out := []
	var h := w * 0.8
	var k := _kind(o)
	var ok: bool = pl != null and pl.ok
	var is_sel := f == sel
	var by := y + 4.0 - (4.0 if is_sel else 0.0)   # giỏ đang chọn nhô lên
	if ok or is_sel:   # quầng: xanh = đủ hàng (nhấp nháy), vàng = đang chọn
		var c := "rgb(255,200,60)" if is_sel else "rgb(110,220,90)"
		var gl := _dic(x - 8.0, y, w + 16.0, SANG % [c, c])
		gl.r = [x - 8.0, y, w + 16.0, h + 12.0]
		if ok and not is_sel:
			gl.fx = "nhay"
		out.append(gl)
	out.append(_art(k, "sau", x, by, w, h))
	var T: float = GIO[k][0] * h / 80.0
	if pl != null:
		var ni: int = mini(3, o.items.size())
		var s: float = SZ[ni]
		for q in ni:
			var id: String = String(o.items[q][0])
			var need := int(o.items[q][1])
			var have: int = int(pl.have[q])
			var good := have >= need
			var cx: float = x + w * float(XS[ni][q])
			var cy: float = by + T - 9.0 * h / 80.0 - (3.0 if ni == 3 and q == 1 else 0.0)
			out.append(_vong(cx, cy, s * 0.5 + 3.0, float(have) / maxf(1.0, need), GREEN if good else "rgb(240,160,32)"))
			var op := "1" if good else "0.7"
			out.append(_dic(cx - s * 0.5, cy - s * 0.5, s, BONG % [op, op, op]))
			var ic := _icn(cx, cy, s * 0.72, id)
			if not good:
				ic.css["opacity"] = "0.5"   # món thiếu: hình mờ trong bóng trong
			out.append(ic)
	out.append(_art(k, "truoc", x, by, w, h))
	if ok:
		out.append(_dtick(x + w - 20.0, by + h - 24.0, 18.0))
	if pl != null and o.get("hot", -1) == G.day():
		out.append(_tem(x - 2.0, by + h * 0.55))
	var nm: String = String(o.who) if pl != null else "Khách mới · " + U.rf((float(o.w) - G._now_ms()) / 1000.0)
	var nx := x + (w - cw) * 0.5
	out.append(_dt(nx, y + 4.0 + h + 1.0, cw, 14.0, _fitw(nm, 10.5, 800, cw - 4.0), 10.5, 800, BROWN if pl != null else SUB))
	if pl == null:   # khách đang tới: giỏ mờ
		for q in [-2, -3]:
			out[out.size() + q].css["opacity"] = "0.45"
	var hit := _dbx(nx, y, cw, h + 18.0, "rgba(0, 0, 0, 0)", 0.0)   # chạm cả ô giỏ: chọn đơn
	var ff := f
	hit.act = func():
		sel = ff
		_build()
	out.append(hit)
	return out

func _face(who: String) -> String:   # chân dung tròn chung của xóm (vlface/m*), cố định theo tên khách
	return "res://ui/img/vlface/m" + str(absi(who.hash()) % 8) + ".webp"

func _foot(f: int, o: Dictionary, pl) -> Array:   # dải chi tiết đáy của đơn đang chọn (y từ 0, cao FOOT)
	var out := [_dbx(X0, 0.0, XW, 1.5, GOLD_L, 0.0)]
	var who := String(o.get("who", ""))
	var fr := _dbx(X0, 8.0, 38.0, 38.0, "rgb(243, 230, 200)", 19.0, _cpx(2.0) + " solid rgb(255, 255, 255)", "0px 0px 0px 2px rgb(232, 160, 32)")
	fr.kids = [_pic(X0 + 2.0, 10.0, 34.0, 34.0, _face(who))]
	out.append(fr)
	var tw := XW - 46.0 - 90.0
	out.append(_dt(X0 + 46.0, 8.0, tw, 18.0, _fitw(who, 14.0, 800, tw), 14.0, 800, BROWN, "left"))
	if pl == null:   # khách đang tới
		var s: float = (float(o.w) - G._now_ms()) / 1000.0
		out.append(_dt(X0 + 46.0, 27.0, tw + 90.0, 16.0, "Khách mới tới sau " + U.rf(s), 12.0, 700, SUB, "left"))
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
	out.append(_dt(X0 + 46.0, 27.0, tw, 16.0, _fitw(String(o.shop), 12.0, 700, tw), 12.0, 700, SUB, "left"))
	# thưởng: xu + sao xanh, hai dòng bên phải
	var s1: String = "+" + G.fmt_n(int(o.reward))
	var s2 := "+" + str(maxi(3, int(round(float(o.reward) / 12.0))))
	var rw: Array = _rowi(0.0, 0.0, 18.0, [s1, "c"], 14.0, 800, "rgb(214, 128, 20)")
	var re: Array = _rowi(0.0, 0.0, 18.0, [s2, "i:pic:res://ui/img/bong/sao_xanh.png"], 14.0, 800, XP_C)
	for k in rw[0]:
		Snap._move(k, Vector2(X0 + XW - float(rw[1]), 8.0))
		out.append(k)
	for k in re[0]:
		Snap._move(k, Vector2(X0 + XW - float(re[1]), 27.0))
		out.append(k)
	# từng món: hình + có/cần
	var ix := X0
	for q in o.items.size():
		var id: String = String(o.items[q][0])
		var need := int(o.items[q][1])
		var have: int = int(pl.have[q])
		var good := have >= need
		var ic := _icn(ix + 13.0, 64.0, 26.0, id)
		if not good:
			ic.css["opacity"] = "0.45"
		out.append(ic)
		var qs: String = G.fmt_n(have) + "/" + str(need)
		var qw: float = Box.text_w(qs, 12.0, 800) + 2.0
		out.append(_dt(ix + 29.0, 56.0, qw, 16.0, qs, 12.0, 800, GREEN if good else DOWN_C, "left"))
		ix += 29.0 + qw + 12.0
	# nút: Giao hàng / Đi lấy + bù sen, Đổi
	var by := 80.0
	var bh := 30.0
	var rx := X0 + XW
	if src == "":
		var conf: bool = U.od_ud.i == f
		var dw := 62.0 if conf else 56.0
		rx -= dw
		out.append(_btn(rx, by, dw, bh, "Đổi?" if conf else "Đổi", func(): U._od_swap(f), "red" if conf else "plain"))
		rx -= 8.0
	if pl.ok:
		out.append(_btn(X0, by, rx - X0, bh, "Giao hàng", func():
			_burst()
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
		out.append(_btn(X0, by, rx - X0, bh, "Đi lấy ›", func(): U._od_get(f), "plain"))
	return out

func _burst() -> void:   # giao: xu bay về ô xu, sao xanh bay về ô cấp, tung ra từ nút vừa bấm
	var b: Control = U.last_btn
	if b == null or not is_instance_valid(b):
		return
	var c: Vector2 = b.get_global_transform_with_canvas() * (b.size * 0.5)
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
		var mid := c + Vector2(cos(ang), sin(ang)) * randf_range(30.0, 60.0) * Css.K - tr.size * 0.5
		tr.position = c - tr.size * 0.5
		L.add_child(tr)
		var tw := tr.create_tween()
		tw.tween_property(tr, "position", mid, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.05 + 0.03 * q)
		tw.tween_property(tr, "position", dst - tr.size * 0.5, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(tr, "scale", Vector2(0.6, 0.6), 0.5)
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
