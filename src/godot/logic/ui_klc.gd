extends "res://logic/ui_kbang.gd"
# THẺ TRÁI KHỦNG (klShow bản web): hiện khi thu hoạch được trái khủng; nhiều trái thì hiện lần lượt. (bản 526) khung Kho co vừa, chip chung:
#  - hình món to trên quầng sáng, tên "Bông lúa khủng", chip hạng (màu theo hạng) + chip "Kỷ lục mới";
#  - cân nhảy số 1,2 giây rồi dừng (số to, viết kiểu Việt: 8,1 g);
#  - lưới 2 cột chip thông số có hình (dài / số củ, độ ngọt, ngày thu + trời, sao ô ruộng, mức chăm + thanh, người gặt);
#  - nút Cất vô tủ (vàng) / Xem tủ kỷ lục.
# Luật ở w_ca.gd (klq, kl_info, kl_kg, kld, KLHANG).

var WC2        # w_ca.gd
var f = null               # trái đang hiện
var t0 := 0.0
var _last := -1.0

const GLOW := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><defs><radialGradient id='g'><stop offset='0' stop-color='#fff4b0' stop-opacity='1'/><stop offset='.55' stop-color='#ffd970' stop-opacity='.55'/><stop offset='1' stop-color='#ffd970' stop-opacity='0'/></radialGradient></defs><circle cx='50' cy='50' r='50' fill='url(#g)'/></svg>"
const RULER := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><rect x='2' y='8' width='20' height='8' rx='1.5' fill='#f2c25a' stroke='#a8741e' stroke-width='1.4'/><path d='M6 8v3M10 8v4M14 8v3M18 8v4' stroke='#a8741e' stroke-width='1.4'/></svg>"
const DROP := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><path d='M12 3C9 8 6 11 6 15a6 6 0 0 0 12 0c0-4-3-7-6-12z' fill='#ff9db0' stroke='#c84a64' stroke-width='1.4'/></svg>"
const SUN := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><circle cx='12' cy='12' r='5' fill='#ffc93c' stroke='#d88a10' stroke-width='1.4'/><path d='M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M5 19l2-2M17 7l2-2' stroke='#d88a10' stroke-width='1.6' stroke-linecap='round'/></svg>"
const RAIN := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><path d='M7 15a4 4 0 0 1 0-8 5 5 0 0 1 9.6-1A3.5 3.5 0 1 1 17 15z' fill='#dfe8f2' stroke='#6a86a8' stroke-width='1.4'/><path d='M8 18l-1 3M12 18l-1 3M16 18l-1 3' stroke='#3c8ad8' stroke-width='1.6' stroke-linecap='round'/></svg>"
const DRY := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><circle cx='12' cy='9' r='5' fill='#ff9a3c' stroke='#c85a10' stroke-width='1.4'/><path d='M4 19c3-2 5 2 8 0s5 2 8 0' fill='none' stroke='#b07a3a' stroke-width='1.6' stroke-linecap='round'/></svg>"
const CARE := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><path d='M12 21c-1-5-6-6-6-11a4 4 0 0 1 6-3 4 4 0 0 1 6 3c0 5-5 6-6 11z' fill='#7fc85a' stroke='#3f8a34' stroke-width='1.4'/><path d='M12 8v9' stroke='#3f8a34' stroke-width='1.4'/></svg>"
const HANGK := ["fut", "now", "fire_l", "sen"]   # màu chip hạng: Ngon, Hảo hạng, Thượng hạng, Kỷ lục

func _init(ui, wca) -> void:
	super(ui)
	WC2 = wca
	fit = true

func show_next() -> void:   # klShow
	if on or WC2.klq.is_empty():
		return
	f = WC2.klq.pop_front()
	on = true
	scroll = 0.0
	t0 = 0.0
	_last = -1.0
	G.vib([12, 40, 12, 40, 30] if f.rec else [10, 30, 10])
	_draw(0.0)

func step(dt: float) -> void:   # cân nhảy số (ease-out bậc 3)
	if not on or f == null:
		return
	t0 += dt
	var a := minf(1.0, t0 / 1.2)
	if _last >= 1.0 or (a < 1.0 and _last >= 0.0 and t0 - _last < 0.08):
		return
	_last = t0 if a < 1.0 else 1.0
	_draw(1.0 - pow(1.0 - a, 3.0))

func _name() -> String:   # "Bông lúa khủng" (loại + tên, bỏ chữ lặp)
	var D: Array = WC2.kld().get(f.id, ["g", 1, 1, "Trái"])
	var k := String(D[3])
	var nm: String = WC2.kl_name(String(f.id)).to_lower()
	if k.to_lower().contains(nm):
		return k + " khủng"
	return k + " " + nm + " khủng"

func _draw(e: float) -> void:
	var out := []
	var cx := X0 + XW * 0.5
	var y := 4.0
	out.append(_dic(cx - 52.0, y, 104.0, GLOW))
	out.append(_icx(cx, y + 52.0, 74.0, String(f.id)))
	y += 106.0
	out.append(_dt(X0, y, XW, 20.0, _name(), 14.0, 800, BROWN))
	y += 24.0
	# chip hạng (+ kỷ lục mới)
	var h := clampi(int(f.h), 0, 3)
	var hs: String = WC2.KLHANG[h]
	var cs := [[hs, HANGK[h], BROWN]]
	if f.rec:
		cs.append(["Kỷ lục mới!", "sen", "rgb(180, 40, 50)"])
	var tws := 0.0
	for c in cs:
		tws += Box.text_w(c[0], 10.5, 700) + 14.0
	tws += 6.0 * (cs.size() - 1)
	var x := cx - tws * 0.5
	for c in cs:
		var T: Array = _tchip(x, y, c[0], c[1], c[2], null, 20.0, 10.5)
		out.append(T[0])
		x += float(T[1]) + 6.0
	y += 24.0
	out.append(_dt(X0, y, XW, 34.0, WC2.kl_kg(float(f.g) * e, String(f.id)), 26.0, 900, "rgb(58, 42, 16)"))
	y += 34.0 + GG
	# lưới thông số (bỏ Cân nặng: đã có số to)
	var L: Array = WC2.kl_info(f).slice(1)
	var g := 6.0
	var cw := (XW - g) * 0.5
	var ch := 44.0
	for i in L.size():
		var r: Array = L[i]
		var bx := X0 + (i % 2) * (cw + g)
		if i > 0 and i % 2 == 0:
			y += ch + g
		out.append_array(_stat(bx, y, cw, ch, String(r[0]), String(r[1])))
	if L.size():
		y += ch + GG
	# nút
	var bw := (XW - g) * 0.5
	out.append(_dbtn(X0, y, bw, 32.0, "Cất vô tủ", _ok))
	var tb := _chip(X0 + bw + g, y, bw, 32.0, "fut")
	tb.kids = [_dt(X0 + bw + g, y, bw, 32.0, "Xem tủ kỷ lục", 11.0, 800, BROWN)]
	tb.act = _tu
	out.append(tb)
	y += 32.0 + 8.0
	var sh := _kshell([], "", func(_k): pass)
	_kmount(sh[0], sh[1], float(sh[2]), out, y)

func _stat(x: float, y: float, w: float, h: float, lb: String, v: String) -> Array:   # một chip thông số: hình + nhãn nhỏ + số
	var out := []
	var c := _chip(x, y, w, h, "fut")
	out.append(c)
	var ic := ""
	var pic := ""
	if lb == "Thu ngày":
		var wx := String(f.get("wx", ""))
		ic = RAIN if wx == "mua" or wx == "rao" else DRY if wx == "han" else SUN
		v = v.replace(" · trời ", " · ")
	elif lb == "Ô ruộng":
		pic = "res://ui/img/bong/sao.png"
		v = v.replace("★", " sao")
	elif lb == "Mức chăm":
		ic = CARE
	elif lb == "Độ ngọt":
		ic = DROP
	elif lb == "Người gặt":
		ic = ""
	else:   # dài bông / cỡ / số củ
		ic = RULER
	var tx := x + 8.0
	if ic != "":
		out.append(_dic(x + 8.0, y + (h - 22.0) * 0.5, 22.0, ic))
		tx = x + 36.0
	elif pic != "":
		out.append(_pic(x + 8.0, y + (h - 22.0) * 0.5, 22.0, 22.0, pic))
		tx = x + 36.0
	var tw := x + w - 6.0 - tx
	out.append(_dt(tx, y + 6.0, tw, 14.0, lb, 9.5, 600, SUB, "left"))
	out.append(_dt(tx, y + 20.0, tw, 18.0, _fitw(v, 12.0, 800, tw), 12.0, 800, BROWN, "left"))
	if lb == "Mức chăm":   # thanh dưới số
		var p := clampf(float(v.replace("%", "")) / 100.0, 0.0, 1.0)
		var vw: float = Box.text_w(v, 12.0, 800) + 6.0
		out.append_array(_bar(tx + vw, y + 27.0, maxf(20.0, tw - vw), p, 5.0))
	return out

func close() -> void:   # × / chạm nền / Cất vô tủ: trái kế
	super()
	if f != null:
		f = null
		if WC2.klq.size():
			G.get_tree().create_timer(0.25).timeout.connect(show_next)

func _ok() -> void:
	close()

func _tu() -> void:   # Xem tủ kỷ lục
	WC2.klq.clear()
	close()
	U.kl_open("tu")
