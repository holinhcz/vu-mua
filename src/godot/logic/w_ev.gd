extends RefCounted
# CỘT SỰ KIỆN BÊN PHẢI (WY bản web): luật quà
#  - Điểm danh (g.dd: Sp, Cp, N8, tF, aF, R8, q9, tA, nF, eF, rF): quà 7 ngày đầu + điểm danh tháng (bù bằng sen đỏ, mốc 7/14/21/28).
#  - 7 ngày về làng (g.tt: V1, nv, ev, rv, A9, VI, QI, KI, UI, XL): mỗi ngày một quà + 4 việc +10 điểm khai hoang, rương theo điểm.
# Bảng: ui_dd.gd, ui_tt.gd. Bùa EXP (túi A3 của web chưa có ở Godot) thì dùng luôn: cộng giờ vào g.xpU.

var G
var WS   # w_sys.gd (V1, Tp, ru, SC)
var WC   # w_cho.gd (Sp)
var WL   # w_lang.gd (di, nq)
var WH   # w_htx.gd (_l)

func _init(game) -> void:
	G = game

static func _tr(v) -> bool:
	return not (v == null or v is bool and not v or (v is float or v is int) and v == 0 or v is String and v == "")

func _ta(s: String) -> void:   # ta / pn
	G.toast.emit(s)

func _kn() -> void:   # Jt + gr + kn + Ba
	G.vib([10, 30, 10])
	G.mark()

func _coins(n: int) -> void:
	G.g.coins = int(G.g.coins) + n

func _sa(n) -> String:   # Sa
	return G.fmt_n(int(n))

func bua_h(h: int) -> void:   # EF(h) rồi dùng liền (LF): bùa +50% EXP h giờ
	var n := maxf(G._now_ms(), float(G.g.get("xpU", 0)))
	G.g.xpU = n + h * 3600000.0

func D9(L: Array) -> String:   # D9: cộng vật liệu, trả "Tên ×n, ..."
	var a := {}
	var ks := []
	for p in L:
		G.nv.S0(String(p[0]), int(p[1]))
		if not a.has(p[0]):
			ks.append(p[0])
		a[p[0]] = int(a.get(p[0], 0)) + int(p[1])
	return ", ".join(PackedStringArray(ks.map(func(k): return String(G.item_name(k)) + " ×" + str(a[k]))))

func qY(t: int) -> String:   # qY: t vật liệu ngẫu nhiên (trừ gạch)
	var a: Array = G.nv.OO.filter(func(r): return r != "gach")
	var n := []
	for e in t:
		n.append([a[randi() % a.size()], 1])
	return D9(n)

# ================================================================== ĐIỂM DANH (g.dd)
func _d() -> Dictionary:   # ngày giờ địa phương
	return Time.get_datetime_dict_from_system()

func z9() -> int:   # z9 = $4
	return G.nv.d4()

func q8() -> int:   # q8: năm*100 + tháng
	var t := _d()
	return int(t.year) * 100 + int(t.month)

func ld() -> int:   # ld: ngày trong tháng
	return int(_d().day)

func zY() -> int:   # zY: số ngày của tháng này
	var t := _d()
	var m := int(t.month)
	var y := int(t.year)
	if m == 2:
		return 29 if (y % 4 == 0 and y % 100 != 0) or y % 400 == 0 else 28
	return 30 if m in [4, 6, 9, 11] else 31

func dow1() -> int:   # (thứ của ngày 1 + 6) % 7: ô trống đầu lịch (T2 đầu tuần)
	var t := _d()
	var u := Time.get_unix_time_from_datetime_dict({"year": t.year, "month": t.month, "day": 1, "hour": 12, "minute": 0, "second": 0})
	return (int(Time.get_datetime_dict_from_unix_time(u).weekday) + 6) % 7

func Sp() -> Dictionary:
	return WC.Sp()

func B8() -> Array:   # B8: các ngày đã điểm danh tháng này
	var a := Sp()
	var k := str(q8())
	if not (a.m.get(k) is Array):
		a.m[k] = []
	return a.m[k]

func got(t: int) -> bool:
	for x in B8():
		if int(x) == t:
			return true
	return false

const D7 := [   # $I
	{"t": "1.000 xu", "ic": "coin"}, {"t": "5 sen đỏ", "ic": "pearl"}, {"t": "Gói vật liệu", "ic": "crate"},
	{"t": "Xe đạp", "ic": "xe", "big": 1}, {"t": "10 sen đỏ + bùa +50% EXP 2 ngày", "ic": "bua"},
	{"t": "Vật liệu kho + 3 phần cơm hồi sức", "ic": "che"}, {"t": "Xuồng ba lá + 20 sen đỏ", "ic": "xuong", "big": 2}]

func _d7_give(i: int) -> String:   # $I[i].f()
	match i:
		0:
			_coins(1000)
		1:
			G.nv.x0(5)
		2:
			return "Gói vật liệu: " + D9([["rom", 2], ["phan", 2], ["van", 2], ["dinh", 2], ["tre", 2], ["la", 2]])
		3:
			if _tr(G.g.pc.get("xe")):
				_coins(3000)
				_ta("Đã có xe đạp, đổi thành 3.000 xu.")
			else:
				G.g.pc.xe = 1
				_ta("Có xe đạp rồi! Đi xa trên đất nhanh gấp rưỡi.")
		4:
			G.nv.x0(10)
			G.nv.bp(2)
			return "10 sen đỏ và bùa +50% EXP 2 ngày (cất trong Kho, mục Đồ dùng)"
		5:
			var t := D9([["then", 3], ["bao", 3], ["ton", 3]])
			G.g.enBank = int(G.g.get("enBank", 0)) + 3
			return t + " và 3 phần cơm hồi sức (cất trong Kho)"
		6:
			G.nv.x0(20)
			if _tr(G.g.pc.get("xuong")):
				G.nv.x0(10)
				_ta("Đã có xuồng, đổi thêm 10 sen đỏ.")
			else:
				G.g.pc.xuong = 1
				_ta("Có xuồng ba lá rồi! Băng qua sông nước, ra giữa sông Vàm câu cá to.")
	return ""

func Cp() -> bool:   # Cp: hôm nay còn quà 7 ngày đầu
	var t: Dictionary = Sp().l7
	return not _tr(t.get("done")) and int(t.get("last", -1)) != z9()

func N8() -> bool:   # N8: chưa nhận hết quà 7 ngày đầu
	return not _tr(Sp().l7.get("done"))

func tF() -> void:   # tF: nhận quà 7 ngày đầu hôm nay
	var t: Dictionary = Sp().l7
	if not Cp():
		return
	var i := int(t.get("n", 0))
	if i >= D7.size():
		return
	var n := i + 1
	var e := _d7_give(i)
	t.last = z9()
	t.n = n
	t.tot = int(t.get("tot", 0)) + 1
	if n >= 7:
		t.done = 1
		t.n = 7
	_ta("Quà đăng nhập ngày " + str(n) + ": " + (e if e != "" else String(D7[i].t)) + ".")
	_kn()

func aF(t: int) -> Dictionary:   # aF: quà ngày t của tháng {t, ic, big}
	if t % 7 == 0:
		return {"t": "3 sen đỏ" if t == 28 else "2 sen đỏ", "ic": "pearl", "big": 1}
	match t % 4:
		1:
			return {"t": _sa(G.nv.v0(200 + 10 * t)) + " xu", "ic": "coin"}
		2:
			return {"t": "Gói 2 vật liệu", "ic": "crate"}
		3:
			return {"t": "Bùa +50% EXP 2 giờ", "ic": "bua"}
	return {"t": "Phần cơm hồi sức", "ic": "che"}

func _af_give(t: int) -> String:
	if t % 7 == 0:
		G.nv.x0(3 if t == 28 else 2)
		return ""
	match t % 4:
		1:
			_coins(G.nv.v0(200 + 10 * t))
			return ""
		2:
			return "Gói vật liệu: " + qY(2)
		3:
			bua_h(2)
			return "Bùa +50% EXP 2 giờ (cất trong Kho, mục Đồ dùng)"
	G.g.enBank = int(G.g.get("enBank", 0)) + 1
	return "1 phần cơm hồi sức (cất trong Kho, ăn lúc nào cũng được)"

const R8 := [{"n": 7, "t": "1.500 xu", "ic": "coin"}, {"n": 14, "t": "5 sen đỏ", "ic": "pearl"},
	{"n": 21, "t": "Gói vật liệu lớn", "ic": "crate"}, {"n": 28, "t": "10 sen đỏ + bùa +50% EXP 3 ngày", "ic": "gift"}]

func _r8_give(n: int) -> String:
	match n:
		7:
			_coins(1500)
		14:
			G.nv.x0(5)
		21:
			return "Gói vật liệu lớn: " + D9(G.nv.OO.map(func(t): return [t, 2]))
		28:
			G.nv.x0(10)
			G.nv.bp(3)
			return "10 sen đỏ và bùa +50% EXP 3 ngày (cất trong Kho)"
	return ""

func q9() -> bool:   # q9: hôm nay chưa điểm danh tháng
	return not got(ld())

func bu_n() -> int:   # số lần điểm danh bù tháng này
	return int(Sp().bu.get(str(q8()), 0))

func tA(t: int, bu: bool) -> void:   # tA: điểm danh ngày t (bu = điểm danh bù)
	var n := B8()
	var e := str(q8())
	var r := Sp()
	if got(t) or t > ld():
		return
	if bu:
		if t == ld():
			return
		var o := int(r.bu.get(e, 0))
		if o >= 5:
			_ta("Mỗi tháng điểm danh bù tối đa 5 ngày.")
			return
		var l := 3 + o
		if int(G.g.get("ngoc", 0)) < l:
			_ta("Cần " + str(l) + " sen đỏ để điểm danh bù.")
			return
		G.nv.x0(-l)
		r.bu[e] = o + 1
	elif t != ld():
		return
	n.append(t)
	var c := aF(t)
	var f := _af_give(t)
	_ta(("Điểm danh bù" if bu else "Điểm danh") + " ngày " + str(t) + ": " + (f if f != "" else String(c.t)) + ".")
	_kn()

func ms_got(n: int) -> bool:
	var m = Sp().ms.get(str(q8()))
	return m is Dictionary and _tr(m.get(str(n)))

func nF() -> int:   # nF: mốc tháng nhận được
	var t := B8().size()
	return R8.filter(func(e): return t >= int(e.n) and not ms_got(int(e.n))).size()

func eF(t: int) -> void:   # eF: nhận mốc t ngày
	var a := str(q8())
	var n := Sp()
	if not (n.ms.get(a) is Dictionary):
		n.ms[a] = {}
	var e = null
	for o in R8:
		if int(o.n) == t:
			e = o
	if e == null or ms_got(t) or B8().size() < t:
		return
	n.ms[a][str(t)] = 1
	var r := _r8_give(t)
	_ta("Đủ " + str(t) + " ngày điểm danh: " + (r if r != "" else String(e.t)) + "!")
	_kn()

func rF() -> int:   # rF: số chấm đỏ nút Điểm danh
	return (1 if Cp() else 0) + (1 if q9() else 0) + nF()

# ================================================================== 7 NGÀY VỀ LÀNG (g.tt)
func V1() -> Dictionary:
	return WS.V1()

func on() -> bool:   # nv(): còn trong 10 ngày và chưa xong hết
	var t := V1()
	return not _tr(t.get("off")) and z9() - int(t.get("t0", 0)) < 10 and not WS.EY()

func ev() -> int:   # ev(): ngày thứ mấy (1..7)
	return mini(7, z9() - int(V1().get("t0", 0)) + 1)

func left_s() -> float:   # giây còn lại để làm hết (t0 + 10 ngày)
	return maxf(0.0, (float(V1().get("t0", 0)) + 10.0 - G.nv._nowd()) * 86400.0)

func _b(k: String) -> int:
	return int(V1().get("b", {}).get(k, 0))

func _st(k: String) -> int:
	var s = G.g.get("sys")
	return int(s.get("stats", {}).get(k, 0)) if s is Dictionary else 0

func E9() -> bool:   # E9 = _l(): có hợp tác xã
	return WH._l()

func _hx() -> Dictionary:
	var h = G.g.get("hx")
	return h if h is Dictionary else {}

func _cnt_chat() -> int:
	var c = G.g.pc.get("cnt")
	return int(c.get("chat", 0)) if c is Dictionary else 0

func _fish() -> int:
	var f = G.g.get("fish")
	return int(f.get("total", 0)) if f is Dictionary else 0

# rv: [tên, biểu tượng, quà {t, ic}, việc [{t, alt?, m, m2?, k}]]
const RV := [
	{"n": "Ruộng đồng", "ic": "🌾", "gift": {"t": "500 xu", "ic": "coin"}, "q": [
		{"t": "Gieo 10 ô ruộng", "m": 10, "k": "plant"}, {"t": "Tưới 10 ô ruộng", "m": 10, "k": "w"},
		{"t": "Thu hoạch 20 lần", "m": 20, "k": "harvest"}, {"t": "Mở thêm 2 ô đất", "m": 2, "k": "plots"}]},
	{"n": "Xưởng", "ic": "⚙️", "gift": {"t": "5 vật liệu ruộng", "ic": "crate"}, "q": [
		{"t": "Xây cối xay", "m": 1, "k": "cd_mill"}, {"t": "Xay 5 mẻ bột", "m": 5, "k": "mill"},
		{"t": "Giao 3 đơn hàng", "m": 3, "k": "del"}, {"t": "Nâng 1 ô ruộng lên 1★", "m": 1, "k": "star1"}]},
	{"n": "Vật nuôi", "ic": "🐓", "gift": {"t": "5 sen đỏ", "ic": "pearl"}, "q": [
		{"t": "Nuôi 3 con gà", "m": 3, "k": "ga"}, {"t": "Lượm 10 sản phẩm vật nuôi", "m": 10, "k": "collect"},
		{"t": "Xây lò bánh", "m": 1, "k": "cd_oven"}, {"t": "Nướng 3 mẻ bánh", "m": 3, "k": "oven"}]},
	{"n": "Kho và sạp", "ic": "🏚️", "gift": {"t": "Rương vật liệu kho", "ic": "crate"}, "q": [
		{"t": "Nâng kho lên 2★", "m": 2, "k": "kho"}, {"t": "Bán 10 món ở sạp", "m": 10, "k": "sapsale"},
		{"t": "Giao tổng 8 đơn hàng", "m": 8, "k": "del"}, {"t": "Đạt cấp 12", "m": 12, "k": "lv"}]},
	{"n": "Bà con", "ic": "🤝", "gift": {"t": "Bùa +50% EXP 1 ngày", "ic": "bua"}, "q": [
		{"t": "Vào một hợp tác xã", "alt": "Trò chuyện với hàng xóm 3 lần", "m": 1, "m2": 3, "k": "hx"},
		{"t": "Giúp bà con trong xã 3 lần", "alt": "Giúp hàng xóm 1 việc", "m": 3, "m2": 1, "k": "giup"},
		{"t": "Thân 2 ♥ với một nhà", "m": 1, "k": "than2"}, {"t": "Thuê một người làm phụ", "m": 1, "k": "nq"}]},
	{"n": "Sông nước", "ic": "🛶", "gift": {"t": "10 sen đỏ", "ic": "pearl"}, "q": [
		{"t": "Câu được 3 con cá", "m": 3, "k": "fish"}, {"t": "Mua bán ở chợ nổi", "m": 1, "k": "cho"},
		{"t": "Đổi hàng với ghe thương hồ", "m": 1, "k": "ghe"}, {"t": "Đi một chuyến trên bản đồ", "m": 1, "k": "trip"}]},
	{"n": "Thành nhà nông", "ic": "🏆", "gift": {"t": "Cổng tre \"Nhà mới về làng\"", "ic": "cong"}, "q": [
		{"t": "Đạt cấp 18", "m": 18, "k": "lv"}, {"t": "Mở 20 ô đất", "m": 20, "k": "ru"},
		{"t": "Đủ 100 điểm năng động trong ngày", "m": 100, "k": "r5"}, {"t": "Mở 3 rương năng động trong ngày", "m": 3, "k": "rcl"}]}]

func qf(q: Dictionary) -> int:   # q.f()
	match String(q.k):
		"plant", "harvest", "mill", "collect", "oven", "sapsale", "cho", "ghe":
			return WS.Tp(String(q.k))
		"w":
			return int(V1().get("w", 0))
		"plots":
			return WS.ru() - _b("plots")
		"cd_mill":
			return 1 if G.cd("mill") else 0
		"cd_oven":
			return 1 if G.cd("oven") else 0
		"del":
			return int(G.g.get("delivered", 0)) - _b("del")
		"star1":
			return 1 if G.nv._star_n(1) > 0 else 0
		"ga":
			var p = G.g.get("pens")
			return (p.get("ga", []) as Array).size() if p is Dictionary and p.get("ga") is Array else 0
		"kho":
			return G.kho_star()
		"lv":
			return G.lv()
		"hx":
			if E9():
				return 1 if _tr(_hx().get("x")) else 0
			return _cnt_chat() - _b("chat")
		"giup":
			if E9():
				var c = _hx().get("c")
				return int(c.get("giup", 0)) if c is Dictionary else 0
			return WS.Tp("vlhelp")
		"than2":
			return 1 if WS.SC(2) > 0 else 0
		"nq":
			return 1 if WL.nq() else 0
		"fish":
			return _fish() - _b("fish")
		"trip":
			return _st("trips") + _st("cargo") - _b("trip")
		"ru":
			return WS.ru()
		"r5":
			return G.nv.r5()
		"rcl":
			return (G.nv.Pl().cl as Dictionary).size()
	return 0

func L9(q: Dictionary) -> int:   # L9: mốc (khác khi chưa có hợp tác xã)
	return int(q.m2) if q.has("alt") and not E9() else int(q.m)

func CY(q: Dictionary) -> String:   # CY: tên việc
	return String(q.alt) if q.has("alt") and not E9() else String(q.t)

const A9 := [{"p": 40, "n": "1.000 xu", "ic": "coin"}, {"p": 100, "n": "10 sen đỏ", "ic": "pearl"},
	{"p": 160, "n": "Rương vật liệu lớn", "ic": "crate"}, {"p": 220, "n": "Thợ giỏi 3★ về làng", "ic": "tal"},
	{"p": 280, "n": "60 sen đỏ", "ic": "pearl"}]

func XL() -> int:   # XL: điểm khai hoang
	var a := 0
	for n in V1().get("cl", {}):
		if _tr(V1().cl[n]):
			a += 10
	return a

func ci(d: int) -> bool:
	return _tr(V1().get("ci", {}).get(str(d)))

func cl(d: int, l: int) -> bool:
	return _tr(V1().get("cl", {}).get(str(d) + ":" + str(l)))

func ch(p: int) -> bool:
	return _tr(V1().get("ch", {}).get(str(p)))

func VI() -> int:   # VI: số quà nhận được
	if not on():
		return 0
	var n := 0
	for e in ev():
		if not ci(e):
			n += 1
		var Q: Array = RV[e].q
		for l in Q.size():
			if not cl(e, l) and qf(Q[l]) >= L9(Q[l]):
				n += 1
	var r := XL()
	for o in A9:
		if r >= int(o.p) and not ch(int(o.p)):
			n += 1
	return n

func QI(t: int) -> void:   # QI: nhận quà điểm danh ngày t
	var a := V1()
	if t >= ev() or ci(t):
		return
	a.ci[str(t)] = 1
	match t:
		0:
			_coins(500)
		1:
			G.nv.S0("rom", 2)
			G.nv.S0("phan", 2)
			G.nv.S0("voi", 1)
		2:
			G.nv.x0(5)
		3:
			for m in ["then", "bao", "ton"]:
				G.nv.S0(m, 3)
		4:
			G.nv.bp(1)
		5:
			G.nv.x0(10)
		6:
			a.cong = 1
			WS.JL()
	_ta("Quà ngày " + str(t + 1) + ": " + String(RV[t].gift.t) + ".")
	_kn()
	if t == 6:
		G.get_tree().create_timer(1.5).timeout.connect(func(): _ta("Cổng tre đã có trong Xây dựng › Vật dụng, đặt trước nhà cho đẹp!"))

func KI(t: int, l: int) -> void:   # KI: nhận +10 điểm một việc
	var n := V1()
	var e: Dictionary = RV[t].q[l]
	if t >= ev() or cl(t, l) or qf(e) < L9(e):
		return
	n.cl[str(t) + ":" + str(l)] = 1
	_ta("+10 điểm khai hoang.")
	G.mark()

func UI(t: int) -> void:   # UI: mở rương t điểm
	var a := V1()
	var n = null
	for e in A9:
		if int(e.p) == t:
			n = e
	if n == null or ch(t) or XL() < t:
		return
	a.ch[str(t)] = 1
	match t:
		40:
			_coins(1000)
		100:
			G.nv.x0(10)
		160:
			for m in G.nv.OO:
				G.nv.S0(m, 2 if m == "gach" else 3)
		220:
			WL.di()
		280:
			G.nv.x0(60)
	_ta("Mở rương " + str(t) + " điểm: " + String(n.n) + "!")
	_kn()

const PK := [{"vnd": 10000, "t": "60 sen đỏ + đèn lồng đỏ"}, {"vnd": 10000, "t": "60 sen đỏ + 10 vật liệu xưởng"},
	{"vnd": 20000, "t": "130 sen đỏ + 3 con gà mái đẻ"}, {"vnd": 20000, "t": "130 sen đỏ + nâng kho 1 bậc"},
	{"vnd": 20000, "t": "130 sen đỏ + thợ giỏi 2★"}, {"vnd": 50000, "t": "350 sen đỏ + bùa +50% EXP 7 ngày"},
	{"vnd": 50000, "t": "350 sen đỏ + khăn đỏ mới cho trâu"}]   # _I: gói tân thủ (nạp tiền, bản Godot chưa có cửa hàng)

func step() -> void:   # tanthu mỗi giây: thợ giỏi 3★ chờ có hàng xóm, cổng tre
	var a := V1()
	if _tr(a.get("tal3")) and G.g.get("lang") is Dictionary and _tr(G.g.lang.get("fam")):
		a.tal3 = 0
		WL.di()
