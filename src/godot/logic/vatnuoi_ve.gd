extends "res://logic/ve_aa.gd"
# Vẽ một con vật trong chuồng (EW + Ay bản web: wW gà, MW cừu, TW bò, SW heo, CW dê; ZR bệnh / con nhỏ / tim),
# rồi bong bóng trên đầu: có hàng (món làm ra), đói (món ăn), đang lớn (thanh tiến độ).
# farm.gd tạo mỗi con một node, đặt trong sortables theo chân con vật để chen đúng giữa các lớp rào chuồng.

const H5 := {"ga": 26.0, "cuu": 26.0, "bo": 34.0, "heo": 24.0, "de": 30.0}   # cao thân
const WW := {"ga": 1.0, "cuu": 0.95, "bo": 0.88, "heo": 0.95, "de": 0.92}    # cỡ vẽ

var t := ""
var j := 0

var _rd := 0.0
func _process(dt: float) -> void:
	# vẽ lại khi đang đi, đang có tim bay; còn lại 15 lần/giây cho bong bóng nhún (đỡ tốn lệnh vẽ)
	tt += dt
	_rd -= dt
	var V = farm.G.vn
	var L: Array = V.mc.get(t, [])
	var mv: bool = j < L.size() and bool(L[j].mv)
	if mv or V.hearts_t.has(t + str(j)) or _rd <= 0.0:
		_rd = 1.0 / 15.0
		queue_redraw()

func _ga(ph: float, mv: bool) -> void:   # wW
	var n := absf(sin(ph)) * 1.6 if mv else 0.0
	var e := sin(ph) * 2.2 if mv else 0.0
	_Dt(-2 + e, -5 - n, -2 + e, 0, "#e0951c", 1.8)
	_Dt(3 - e, -5 - n, 3 - e, 0, "#e0951c", 1.8)
	_xe([-7, -10 - n, -14, -16 - n, -12, -8 - n], "#e6dcc3")
	_L(0, -9 - n, 8.5, 6.5, "#f8f3e6")
	_L(-1, -8 - n, 5, 3.4, "#e6dcc3")
	_L(7, -15 - n, 4.6, 4.6, "#f8f3e6")
	_xe([5, -19.5 - n, 6.5, -23.5 - n, 8, -19.8 - n, 9.5, -23 - n, 10.5, -18.5 - n], "#d93a32")
	_xe([11, -15.7 - n, 15.2, -14.2 - n, 11, -12.7 - n], "#f0a020")
	_xe([9, -11.8 - n, 10.6, -8 - n, 8, -9.8 - n], "#d93a32")
	_L(8.6, -15.6 - n, 0.9, 0.9, "#2b2118")

func _cuu(ph: float, mv: bool) -> void:   # MW
	var n := absf(sin(ph)) * 1.3 if mv else 0.0
	var e := sin(ph) * 2.0 if mv else 0.0
	for x in [-6 + e, -1 - e, 5 + e, 10 - e]:
		_Dt(x, -9, x, 0, "#3d342d", 2.6)
	var o := [[-8, -14, 6], [0, -17, 7], [8, -15, 6.5], [-3, -11, 6.5], [5, -11, 6]]
	for r in o:
		_L(r[0], r[1] - n, r[2] + 1, r[2] + 1, Color(0, 0, 0, 0.16))
	for r in o:
		_L(r[0], r[1] - n, r[2], r[2], "#f6f3ec")
	_L(15, -14 - n, 4.2, 5, "#4a3f37", -0.2)
	_L(12, -18.5 - n, 3, 1.5, "#4a3f37", -0.5)
	_L(16.6, -15 - n, 0.9, 0.9, "#f3f0e8")

func _bo(ph: float, mv: bool) -> void:   # TW
	var n := absf(sin(ph)) * 1.3 if mv else 0.0
	var e := sin(ph) * 2.2 if mv else 0.0
	_Dt(-15, -18 - n, -19, -9, "#3a322c", 1.6)
	_L(-19, -8, 1.8, 2.4, "#3a322c")
	for r in [[-10 + e, "#2e2823"], [-5 - e, "#3a322c"], [6 + e, "#2e2823"], [11 - e, "#3a322c"]]:
		_Dt(r[0], -11, r[0], 0, r[1], 3.4)
	_L(0, -18 - n, 16.5, 9.5, "#f7f3ea")
	_L(-6, -21 - n, 5.5, 4.2, "#3a322c")
	_L(5, -15 - n, 5.5, 3.8, "#3a322c")
	_L(1, -10 - n, 3.2, 2, "#f2a7a7")
	_L(17.5, -21 - n, 6.2, 5.6, "#f7f3ea")
	_L(22, -19.2 - n, 3.9, 3.2, "#f2a7a7")
	_Dt(14.5, -26 - n, 12.5, -30 - n, "#e8d9a8", 2.3)
	_L(13, -23.5 - n, 3.2, 1.6, "#3a322c", -0.4)
	_L(18.6, -22.4 - n, 1, 1, "#2b2118")
	_L(22.6, -19.6 - n, 0.7, 0.7, "#b86a6a")

func _heo(ph: float, mv: bool) -> void:   # SW
	var n := absf(sin(ph)) * 1.2 if mv else 0.0
	var e := sin(ph) * 2.0 if mv else 0.0
	var r := "#f2a9a6"
	var o := "#d9837f"
	for l in [[-9 + e, o], [-4 - e, r], [5 + e, o], [10 - e, r]]:
		_Dt(l[0], -8, l[0], 0, l[1], 3.6)
		_L(l[0], 0, 1.9, 1, "#7a4a44")
	var tail := _quad(Vector2(-15, -15 - n), Vector2(-20, -19 - n), Vector2(-18, -14 - n))
	tail.append_array(_quad(Vector2(-18, -14 - n), Vector2(-16, -11 - n), Vector2(-19, -12 - n)))
	_line(tail, o, 1.4)
	_L(0, -14 - n, 15.5, 9.5, r)
	_L(-2, -17 - n, 10, 4.5, Color(1, 1, 1, 0.28))
	_L(14, -16 - n, 7.4, 6.6, r)
	_xe([11, -21 - n, 14, -27 - n, 16.5, -20.5 - n], o)
	_L(20.2, -14.5 - n, 3.6, 3.1, "#ee8f8b")
	_L(19.6, -14.8 - n, 0.8, 1, "#8a4a46")
	_L(21.4, -14.4 - n, 0.8, 1, "#8a4a46")
	_L(15.6, -18.4 - n, 1, 1, "#2b2118")

func _de(ph: float, mv: bool) -> void:   # CW
	var n := absf(sin(ph)) * 1.4 if mv else 0.0
	var e := sin(ph) * 2.4 if mv else 0.0
	var r := _m("#f2ece0", "#9a968c")
	var o := _m("#d9cfbd", "#7a766c")
	var l := _m("#8a5a32", "#4a3420")
	var c := _m("#3a2a1e", "#1e160e")
	var f := _m("#b8a88a", "#6a5e4a")
	for s in [[-8 + e, o], [-4 - e, r], [6 + e, o], [10 - e, r]]:
		_Dt(s[0], -10, s[0], -1, s[1], 2.3)
		_L(s[0], -0.4, 1.4, 0.9, c)
	_xe([-12, -17 - n, -15, -22 - n, -11.5, -19 - n], r)
	_L(0, -15 - n, 12.5, 6.8, r)
	_L(-3, -17.5 - n, 6.5, 3.6, l)
	_L(4, -13 - n, 3.8, 2.2, Color(0, 0, 0, 0.06))
	_xe([8, -18 - n, 11, -25 - n, 15, -24 - n, 13, -16 - n], r)
	_L(15, -25 - n, 4.2, 3.6, r, 0.25)
	_L(19, -23.4 - n, 2.6, 2, _m("#e8d6c8", "#8a7a70"), 0.35)
	_line(_quad(Vector2(13.4, -28 - n), Vector2(11, -33 - n), Vector2(7.5, -31.5 - n)), f, 1.8)
	_L(11.6, -25.5 - n, 3.2, 1.3, o, -0.5)
	_xe([16.2, -22 - n, 15.4, -17.4 - n, 17.8, -21.4 - n], o)
	_L(16.4, -26 - n, 0.9, 0.9, "#2b2118")
	_L(20.6, -23.6 - n, 0.6, 0.6, "#6a4a3a")

func foot() -> Vector2:   # chân con vật (toạ độ làng)
	var V = farm.G.vn
	var L: Array = V.mc.get(t, [])
	if j >= L.size():
		return Vector2.INF
	return Vector2(farm.en(L[j].x, L[j].y), farm.nn(L[j].x, L[j].y))

func scale_f() -> float:
	var e = farm.G.vn.a(t, j)
	return float(WW[t]) * (0.58 if e != null and float(e.get("b", 0)) > 0.0 else 1.0)

func has_bub() -> bool:   # đang hiện bong bóng (bệnh, có hàng, đói); con nhỏ / đang lớn chỉ có thanh
	var V = farm.G.vn
	var e = V.a(t, j)
	if e == null:
		return false
	if e.get("s", 0):
		return true
	if float(e.get("b", 0)) > 0.0:
		return false
	return V.ready(t, e) or V.hungry(e)

func bub_at() -> Vector2:   # chỗ bong bóng (X0: c - p - 14)
	var p := foot()
	return Vector2(p.x, p.y - float(H5[t]) * scale_f() - 14.0)

func _draw() -> void:
	_draw_all()
	_flush()

func _draw_all() -> void:
	var V = farm.G.vn
	var e = V.a(t, j)
	var L: Array = V.mc.get(t, [])
	if e == null or j >= L.size():
		return
	var m: Dictionary = L[j]
	var base := foot()
	var f := scale_f()
	var r: Dictionary = V.Q[t]
	var still: bool = farm.G.motion_off()
	var zm: float = farm.main.zoom
	_aa = 1.0 / zm
	# bóng (qv)
	_L(base.x, base.y, 13.0 * f, 13.0 * f * 0.42, Color(0, 0, 0, 0.24))
	_aa = 1.0 / (zm * f)
	_tf(base, Vector2(float(m.dir) * f, f))
	match t:
		"ga": _ga(float(m.ph), bool(m.mv))
		"cuu": _cuu(float(m.ph), bool(m.mv))
		"bo": _bo(float(m.ph), bool(m.mv))
		"heo": _heo(float(m.ph), bool(m.mv))
		"de": _de(float(m.ph), bool(m.mv))
	_tf(Vector2.ZERO, Vector2.ONE)
	_aa = 1.0 / zm
	var p := float(H5[t]) * f
	var d := 0.0 if still else sin(tt * 3.0 + j) * 1.2
	var x := base.x
	var c := base.y
	# ZR: tim bay sau khi vuốt ve
	var ht := float(V.hearts_t.get(t + str(j), 0.0))
	_flush()
	if ht > 0.0:
		var fnt: Font = ThemeDB.fallback_font
		for k in 3:
			var s := fmod((2.2 - ht) * 0.8 + k * 0.3, 1.0)
			draw_string(fnt, Vector2(x - 8 + k * 8 - 4, c - p - 8 - s * 18), "♥", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.886, 0.271, 0.227, minf(1.0, ht)))
	var le: float = farm.sign_le()
	if e.get("s", 0):   # bệnh: bong bóng đỏ chữ thập + "z"
		_x0(Vector2(x, c - p - 14 + d), "@benh", true)
		if not still and sin(tt * 2 + j) > 0.6:
			draw_string(ThemeDB.fallback_font, Vector2(x + 10, c - p + 2), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(8 * le), Color(80 / 255.0, 80 / 255.0, 120 / 255.0, 0.8))
		return
	if float(e.get("b", 0)) > 0.0:   # con nhỏ: thanh hồng
		var v: float = 1.0 - float(e.b) / V.BABY
		draw_rect(Rect2(x - 7, c - p - 4, 14, 3), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(x - 7, c - p - 4, 14 * v, 3), Color("#f29ab0"))
		return
	if V.ready(t, e):
		_x0(Vector2(x, c - p - 14 + d), String(r.make))
	elif V.hungry(e):
		_x0(Vector2(x, c - p - 14 + d), String(r.feed))
	else:
		var v2 := minf(1.0, float(e.p) / float(r.time))
		draw_rect(Rect2(x - 9, c - p - 6, 18, 3.4), Color(0, 0, 0, 0.35))
		var pal = farm.G.troi.st.get("pal", {}) if farm.G.troi != null else {}
		draw_rect(Rect2(x - 9, c - p - 6, 18 * v2, 3.4), Color(String(pal.get("leaf2", "#5aa83a"))))
