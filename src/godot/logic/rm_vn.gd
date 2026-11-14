extends RefCounted
# Vòng nút của con vật / chuồng: xài chung vòng nút ô ruộng (ui.gd rm_g / rm_r, cùng bản chụp rmg / rmr), chỉ phần riêng ở đây.
#  Con đang lớn: [Làm ngay: vòng đỏ + sen] [Cho ăn: hình thức ăn, vòng xanh = đã no, đói thì nhấp nháy] [Vuốt ve: tim, vuốt rồi thì mờ]
#                chip: tên con + đồng hồ + giờ còn lại (đói: "Đang đói").
#  Có đồ: một nút thu (hình món ra). Bệnh: một nút đỏ chữ thập, bấm hiện chip "Chữa bệnh · 150 xu". Con nhỏ: không hiện gì.
#  Chuồng: [Thu hết] [Cho ăn hết] [Nâng sao: vòng sao] · chip: tên chuồng + "Mua thêm con · giá" (đủ con thì chỉ tên).

var U          # ui.gd
var G
var key := {}  # {t, j}: j = -1 là chuồng
var _st := ""  # "grow" | "ready" | "sick"
var _ic := {}  # hình đang đặt cho mỗi nút (khỏi dựng lại svg mỗi lần)

const HEART := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 40 40\"><path d=\"M20 33C9 25 5 19.5 5 14.2 5 9.6 8.6 6 13 6c3 0 5.4 1.6 7 4 1.6-2.4 4-4 7-4 4.4 0 8 3.6 8 8.2 0 5.3-4 10.8-15 18.8z\" fill=\"#e8475f\" stroke=\"#b8283f\" stroke-width=\"1.4\"/><path d=\"M10.5 12.5c.6-1.8 2-3 3.8-3.2\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2\" stroke-linecap=\"round\" opacity=\".7\"/></svg>"
const CROSS := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 40 40\"><rect x=\"16\" y=\"6\" width=\"8\" height=\"28\" rx=\"2\" fill=\"#d9443a\"/><rect x=\"6\" y=\"16\" width=\"28\" height=\"8\" rx=\"2\" fill=\"#d9443a\"/></svg>"

func _init(ui) -> void:
	U = ui
	G = ui.G

static func _svg(id: String) -> String:   # hình món của bản web (ui/svg/kh)
	return FileAccess.get_file_as_string("res://ui/svg/kh/" + id + ".svg")

func _put(k: String, svg: String) -> void:
	if _ic.get(k, "?") != svg:
		_ic[k] = svg
		U._rm_ic(k, svg)

func _ring(k: String, svg: String) -> void:
	var b: Control = U.rm_gi[k].kids()[0]
	if b.get_meta("rv", "") != svg:
		b.set_meta("rv", svg)
		U._set_svg(b, svg)

# ------------------------------------------------------------------ mở
func open(va: Dictionary) -> void:   # chạm con vật {t, j} hoặc chuồng {t, j: -1}
	var V = G.vn
	var t := String(va.t)
	var j := int(va.get("j", -1))
	if j >= 0:
		var e = V.a(t, j)
		if e == null or float(e.get("b", 0)) > 0.0:   # con nhỏ mới đẻ: không hiện gì
			return
	U.close_all()
	U.rm_v = {"t": t, "j": j}
	key = U.rm_v
	U.rm_sig = ""
	U._rm_reset()
	_ic = {}
	_st = ""
	U._set_focus(true)
	sync()
	pos()

# ------------------------------------------------------------------ cập nhật (mỗi 0,25 s)
func sync() -> void:
	var V = G.vn
	var t := String(key.t)
	var j := int(key.j)
	if not V.ok(t):
		U.rm_close()
		return
	if j < 0:
		_pen(t)
		return
	var e = V.a(t, j)
	if e == null or float(e.get("b", 0)) > 0.0:
		U.rm_close()
		return
	var r: Dictionary = V.Q[t]
	if e.get("s", 0):   # bệnh: một nút đỏ chữ thập
		_one("sick", "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 64 64\"><circle cx=\"32\" cy=\"32\" r=\"28.5\" fill=\"#fff\" stroke=\"#d9443a\" stroke-width=\"5\"/></svg>", CROSS)
		return
	if V.ready(t, e):   # có đồ: một nút thu, hình món ra
		_one("ready", U.rm_in0["rmth_ring"], _svg(String(r.make)))
		return
	_st = "grow"
	U.rm_g.visible = true
	U.rm_r.visible = false
	U._q(U.rm_gi[".fast"], "rmsen").visible = true
	_put(".fast", "")
	var hun: bool = V.hungry(e)
	var fr := 0.0 if hun else minf(1.0, float(e.p) / float(r.time))
	_ring(".fast", U._ring("rmf", "#e8324a", "rgba(232,50,74,.16)", round(fr * 1000.0) / 1000.0))
	var left: float = V.left(t, e)
	U._txt(U._q(U.rm_gi[".fast"], "", "b"), str(V.ro(left)))
	U.rm_gi[".fast"].modulate.a = 0.5 if hun else 1.0
	_ring(".star", U._ring("rmw", "#1e90e8", "rgba(30,144,232,.15)", 0.0 if hun else 1.0))   # vòng xanh: đã no
	_put(".star", _svg(String(r.feed)))
	_ring(".water", U._ring("rmw", "#e8475f", "rgba(232,71,95,.15)", 0.0))
	_put(".water", HEART)
	var pet_done: bool = int(e.get("pd", -1)) == G.day()
	U.rm_gi[".water"].modulate.a = 0.5 if pet_done else 1.0
	var rt: Control = U.rm_gi[".rmt"]
	U._txt(rt, V.q4(t, j))
	if hun:
		U._rm_note(rt, "Đang đói")
	else:
		U._rm_small(rt, false, U.tfmt(left))

func _one(st: String, ring: String, ic: String) -> void:   # một nút tròn (bản chụp rmr)
	_st = st
	U.rm_g.visible = false
	U.rm_r.visible = true
	_ring(".rmth", ring)
	_put(".rmth", ic)

func _pen(t: String) -> void:
	var V = G.vn
	var L: Array = V.list(t)
	var r: Dictionary = V.Q[t]
	var ready := 0
	var hun := 0
	for e in L:
		if V.ready(t, e):
			ready += 1
		elif V.hungry(e):
			hun += 1
	_st = "pen"
	U.rm_g.visible = true
	U.rm_r.visible = false
	U._q(U.rm_gi[".fast"], "rmsen").visible = false
	var none: String = U._ring("rmw", "#1e90e8", "rgba(150,112,48,.18)", 0.0)
	_ring(".fast", none)
	_put(".fast", _svg(String(r.make)))   # Thu hết
	U.rm_gi[".fast"].modulate.a = 1.0 if ready > 0 else 0.5
	_ring(".star", none)
	_put(".star", _svg(String(r.feed)))   # Cho ăn hết
	U.rm_gi[".star"].modulate.a = 1.0 if hun > 0 else 0.5
	_ring(".water", U._ring5(V.ps(t) - 1))   # Nâng sao
	_put(".water", U.rm_in0[".star"])
	U.rm_gi[".water"].modulate.a = 1.0
	var rt: Control = U.rm_gi[".rmt"]
	U._txt(rt, String(G.lang.CO.get(t, "Chuồng")))
	U._rm_note(rt, ("Mua thêm con · " + G.fmt_n(V.price(t)) + " xu") if L.size() < V.gl() else "")

# ------------------------------------------------------------------ chỗ đứng (mỗi khung)
func pos() -> void:
	var V = G.vn
	var t := String(key.t)
	var j := int(key.j)
	var F = U.F
	var M = U.main
	var top: Control = U.rm_r if U.rm_r.visible else U.rm_g
	var box: Control = top.kids()[0]
	var w = box.r.size.x
	var h = box.r.size.y
	var at := Vector2.INF
	var mn := Vector2.ZERO
	var mx := Vector2.ZERO
	if j >= 0:
		var n = F.anodes.get(t + ":" + str(j))
		if n == null:
			return
		var ft: Vector2 = n.foot()
		at = n.bub_at() + Vector2(0, 6.0)
		mn = (Vector2(ft.x - 22.0, at.y) - M.cam) * M.zoom
		mx = (Vector2(ft.x + 22.0, ft.y + 6.0) - M.cam) * M.zoom
		if _st == "grow" and V.hungry(V.a(t, j)):   # đói: ô Cho ăn nhấp nháy
			U.rm_gi[".star"].modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 260.0))
	else:
		var pp: Vector2i = G.lang.pen_pos(t)
		var m: Dictionary = G.lang.C.mo[t]
		var pw := float(m.w)
		var ph := float(m.h)
		at = Vector2(F.en(pp.x + pw / 2.0, pp.y + ph / 2.0), F.nn(pp.x, pp.y, 40.0))
		var q := []
		for p in [[0, 0], [pw, 0], [pw, ph], [0, ph]]:
			q.append((Vector2(F.en(pp.x + p[0], pp.y + p[1]), F.nn(pp.x + p[0], pp.y + p[1])) - M.cam) * M.zoom)
		mn = q[0]
		mx = q[0]
		for p in q:
			mn = mn.min(p)
			mx = mx.max(p)
		mn.y = minf(mn.y, (at.y - M.cam.y) * M.zoom)
	var ra: Vector2 = (at - M.cam) * M.zoom / U.Css.K
	var x := clampf(ra.x, w / 2.0 + 8.0, U.vw - w / 2.0 - 8.0)
	var y := clampf(ra.y, h + 8.0, U.vh - 8.0)
	U._move(top, Vector2(round(x), round(y)))
	U._move(box, Vector2(-w / 2.0, -h))
	U.dim_mat.set_shader_parameter("c", (mn + mx) * 0.5)
	U.dim_mat.set_shader_parameter("r", Vector2((mx.x - mn.x) / 2.0 * 1.3 + 16.0 * U.Css.K, (mx.y - mn.y) / 2.0 * 1.3 + 16.0 * U.Css.K))

# ------------------------------------------------------------------ bấm
func act(k: String) -> void:   # k: fast / star / water (3 nút), harvest (một nút), chip
	var V = G.vn
	var F = U.F
	var t := String(key.t)
	var j := int(key.j)
	if j < 0:
		_pen_act(t, k)
		return
	var e = V.a(t, j)
	if e == null:
		return
	var r: Dictionary = V.Q[t]
	if k == "harvest":
		if _st == "ready":
			U.rm_close()
			F.vn_job(t, j, "collect")
		elif _st == "sick":   # chip "Chữa bệnh · 150 xu" (thú y), không chữa bằng sen
			U.xfp._ask(U.rm_gi[".rmth"], V.ZM, "Chữa bệnh cho " + V.q4(t, j) + "?", "", func():
				if V.vet(t, j):
					U.rm_close(), true)
		return
	if k == "fast":   # Làm ngay: sen đỏ
		if V.hungry(e):
			G.toast.emit("Cho " + V.q4(t, j) + " ăn trước đã.")
			return
		var n: int = V.ro(V.left(t, e))
		U.xfp._ask(U.rm_gi[".fast"], n, "Xong ngay " + V.q4(t, j) + "?", "", func():
			if V.fast(t, j):
				U.rm_close()
				F.vn_job(t, j, "collect"))
	elif k == "star":   # Cho ăn
		if not V.hungry(e):
			G.toast.emit(V.q4(t, j) + " chưa đói.")
			return
		var feed: String = r.feed
		U.rm_close()
		if int(G.g.barn.get(feed, 0)) > 0:
			F.vn_job(t, j, "feed")
		else:
			U._lack_open([[feed, 1]], "Kho hết thức ăn cho " + V.name(t).to_lower() + ":", func(): F.vn_job(t, j, "feed"))
	elif k == "water":   # Vuốt ve
		if int(e.get("pd", -1)) == G.day():
			G.toast.emit("Hôm nay nựng " + V.q4(t, j) + " rồi.")
			return
		U.rm_close()
		F.vn_job(t, j, "pet")

func _pen_act(t: String, k: String) -> void:
	var V = G.vn
	var F = U.F
	var L: Array = V.list(t)
	if k == "fast":   # Thu hết: nhân vật đi thu từng con
		var n := 0
		for j in L.size():
			if V.ready(t, L[j]):
				F.vn_job(t, j, "collect")
				n += 1
		if n == 0:
			G.toast.emit("Chưa con nào có " + G.item_name(V.Q[t].make).to_lower() + ".")
			return
		U.rm_close()
	elif k == "star":   # Cho ăn hết: đủ thức ăn tới đâu cho tới đó
		var feed: String = V.Q[t].feed
		var kho := int(G.g.barn.get(feed, 0))
		var hun := []
		for j in L.size():
			if V.hungry(L[j]):
				hun.append(j)
		if hun.is_empty():
			G.toast.emit("Chưa con nào đói.")
			return
		U.rm_close()
		if kho < 1:
			U._lack_open([[feed, 1]], "Kho hết thức ăn cho " + V.name(t).to_lower() + ":", func(): F.vn_job(t, hun[0], "feed"))
			return
		for q in hun.slice(0, kho):
			F.vn_job(t, q, "feed")
	elif k == "water":   # Nâng sao chuồng
		U.rm_close()
		U.spp.open_pen(t)
	elif k == "chip":   # Mua thêm con
		if L.size() < V.gl():
			V.buy(t)
			U.rm_sig = ""
			sync()
