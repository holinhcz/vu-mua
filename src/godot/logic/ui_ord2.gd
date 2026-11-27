extends "res://logic/ui_kbang.gd"
# (11-27) ĐƠN HÀNG trên KHUNG CHUNG (ui_kbang: khung sen, chip, thẻ, đáy chung), thay bản chụp web (ord / ord_ok / ord_wait...).
#   Đầu (cố định): "Giao được N/M đơn" + thanh + "đã giao D"; bảng quán: hàng chip (sao, danh tiếng, giá...) dưới đầu.
#   Thân (cuộn): thẻ đơn 2 cột (cao theo số món, thẻ cùng hàng cao bằng): chân dung khách + tên + quán, nhãn Đổi trên mép,
#   tem GẤP góc; dòng món (ô hình to, tên, có/cần); dải thưởng xu + sao xanh; nút Giao hàng / Đi lấy + bù sen;
#   thẻ đủ hàng quầng sáng nhấp nháy; độ hiếm theo thưởng (thường nâu / hiếm xanh / quý tím / huyền thoại vàng ánh kim):
#   viền, viên đá mép trên, dải đầu thẻ mang màu; giao: lá bài lật mặt sen rồi tan thành xu + sao bay lên; khách đang tới: giờ chờ, thanh, Gọi.
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
# (11-27) độ hiếm lá bài theo thưởng so với mức thưởng thường của cấp: thường / hiếm / quý / huyền thoại
const T_COL := ["rgb(176, 128, 72)", "rgb(52, 132, 220)", "rgb(146, 84, 214)", "rgb(232, 172, 24)"]
const T_TINT := ["", "rgb(220, 235, 252)", "rgb(238, 226, 252)", "rgb(255, 238, 190)"]
const T_CUT := [0.95, 1.15, 1.5]
const QUET := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 30 100\" preserveAspectRatio=\"none\"><defs><linearGradient id=\"g\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"0\"><stop offset=\"0\" stop-color=\"rgb(255,255,255)\" stop-opacity=\"0\"/><stop offset=\"0.5\" stop-color=\"rgb(255,250,220)\" stop-opacity=\"0.75\"/><stop offset=\"1\" stop-color=\"rgb(255,255,255)\" stop-opacity=\"0\"/></linearGradient></defs><path d=\"M12 0H30L18 100H0Z\" fill=\"url(#g)\"/></svg>"
const LAP := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 20 20\"><path d=\"M10 0L12.2 7.8L20 10L12.2 12.2L10 20L7.8 12.2L0 10L7.8 7.8Z\" fill=\"rgb(255,248,200)\" stroke=\"rgb(232,172,24)\" stroke-width=\"0.8\"/></svg>"
const GOLD_L := "rgb(214, 176, 104)"   # viền ô hình món (như khung chi tiết Kho)
const XP_C := "rgb(47, 127, 214)"   # chữ EXP xanh (sao xanh)

func _tier(o: Dictionary) -> int:   # thưởng / thưởng thường của cấp (như G._fh0: 20 + 10 x cấp + 6 x số giao, nhân 1,65)
	var a := mini(4, int(floor(int(G.g.delivered) / 2.0)))
	var base := (20.0 + 10.0 * mini(100, G.lv()) + 6.0 * a) * 1.65
	var r := float(o.reward) / maxf(1.0, base)
	var t := 0
	for c in T_CUT:
		if r >= c:
			t += 1
	return t

func _face(who: String) -> String:   # chân dung tròn chung của xóm (vlface/m*), cố định theo tên khách
	return "res://ui/img/vlface/m" + str(absi(who.hash()) % 8) + ".webp"

func _ocard(x: float, y: float, w: float, h: float, f: int, o: Dictionary, pl, col: String) -> Array:
	if pl == null:
		return _wait(x, y, w, h, f, o)
	var ok: bool = pl.ok
	var out := []
	var ti := _tier(o)
	var tc: String = T_COL[ti]
	if ok or ti >= 2:   # đủ hàng / bài quý trở lên: quầng sáng nhấp nháy quanh thẻ (đủ hàng mà bài thường: cam lửa)
		var gc: String = tc if ti > 0 else FIRE
		var gl := _dbx(x - 3.0, y - 3.0, w + 6.0, h + 6.0, "rgba(0, 0, 0, 0)", 14.0, _cpx(2.0) + " solid " + gc, "0px 0px 9px " + gc.replace("rgb(", "rgba(").replace(")", ", 0.9)"))
		gl.fx = "nhay"
		out.append(gl)
	out.append(_chip(x, y, w, h, "sel" if ok else "fut"))
	if ti > 0:   # dải đầu thẻ mang màu độ hiếm
		out.append(_dbx(x + 3.0, y + 3.0, w - 6.0, P + FACE + 1.0, T_TINT[ti], 10.0))
	out.append(_dbx(x, y, w, h, "rgba(0, 0, 0, 0)", 12.0, _cpx(2.5 if ti > 0 else 1.5) + " solid " + tc))   # viền độ hiếm
	if ti == 3:   # huyền thoại: vệt ánh kim quét ngang + đốm lấp lánh
		var sw0 := _dic(x + 4.0, y + 4.0, 28.0, QUET)
		sw0.r = [x + 4.0, y + 4.0, 28.0, h - 8.0]
		sw0.fx = "quet:" + str(w - 36.0)
		out.append(sw0)
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
	iy = y + h - P - BT_H - G2 - RW_H   # thưởng + nút bám đáy thẻ (thẻ cùng hàng: nút thẳng hàng nhau)
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
		out.append(_btn(x + P, by, w - 2.0 * P, BT_H, "Giao hàng", func():
			_giao_fx(Vector2(P, by - y), w, h, ti)
			U._od_deliver(f)))
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
	if ti > 0:   # viên đá giữa mép trên
		out.append(_gem(x + w * 0.5, y, tc))
	if ti == 3:
		for q in 3:
			var sp := _dic(0.0, 0.0, 12.0, LAP)
			var pt: Vector2 = [Vector2(w * 0.3, 10.0), Vector2(w - 14.0, P + FACE - 4.0), Vector2(14.0, h * 0.62)][q]
			sp.r = [x + pt.x - 6.0, y + pt.y - 6.0, 12.0, 12.0]
			sp.fx = "lap:" + str(q * 0.67)
			out.append(sp)
	return out

func _gem(cx: float, cy: float, col: String) -> Dictionary:   # viên đá độ hiếm: hình thoi màu, viền trắng
	var s := 11.0
	var a := PI * 0.25
	var bb := s * 1.4142
	var g := _dbx(cx - bb * 0.5, cy - bb * 0.5, bb, bb, col, 2.0, _cpx(1.5) + " solid rgb(255, 255, 255)", "0px 1px 2px rgba(60, 30, 10, 0.45)")
	g.css["transform"] = "matrix(%f, %f, %f, %f, 0, 0)" % [cos(a), sin(a), -sin(a), cos(a)]
	return g

func _giao_fx(off: Vector2, w: float, h: float, ti: int) -> void:   # giao: lá bài lật mặt sau (hoa sen) rồi tan thành xu + sao bay về ô xu / ô cấp
	var b: Control = U.last_btn
	if b == null or not is_instance_valid(b) or b.get_parent() == null:
		return
	var k := b.size.x / maxf(1.0, w - 2.0 * P)
	var xf: Transform2D = b.get_parent().get_global_transform_with_canvas()
	var sc := xf.get_scale().x
	var p0: Vector2 = xf * (b.position - off * k)
	var sz := Vector2(w, h) * k * sc
	var L: CanvasLayer = U.fx_layer()
	var card := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color8(176, 40, 34)
	st.border_color = Color.html("#" + _hex(T_COL[ti]))
	st.set_border_width_all(int(round(3.0 * k * sc)))
	st.set_corner_radius_all(int(round(12.0 * k * sc)))
	card.add_theme_stylebox_override("panel", st)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = p0
	card.size = sz
	card.pivot_offset = sz * 0.5
	var lt := TextureRect.new()
	var ls := minf(sz.x, sz.y) * 0.62
	lt.texture = Css.svg_tex(Css.img_svg("res://ui/img/sen/hoa_tt.webp"), ls, ls)
	lt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lt.size = Vector2(ls, ls)
	lt.position = (sz - lt.size) * 0.5
	lt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lt)
	L.add_child(card)
	card.scale = Vector2(0.0, 1.0)
	var tw := card.create_tween()
	tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_callback(func(): _burst(card.position + sz * 0.5, ti))
	tw.tween_property(card, "scale", Vector2(0.2, 0.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "modulate:a", 0.0, 0.3)
	tw.tween_callback(card.queue_free)

func _hex(rgb: String) -> String:
	var v := rgb.replace("rgb(", "").replace(")", "").split(",")
	return "%02x%02x%02x" % [int(v[0]), int(v[1]), int(v[2])]

func _burst(c: Vector2, ti: int) -> void:   # xu bay về ô xu, sao xanh bay về ô cấp
	var L: CanvasLayer = U.fx_layer()
	var tg := {"coin": U.hid.get("#coinsPill"), "sao": U.hid.get("#pcAv")}
	var n := 8 + ti * 3
	for q in n + 4:
		var is_c := q < n
		var key := "coin" if is_c else "sao"
		var t: Control = tg[key]
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
