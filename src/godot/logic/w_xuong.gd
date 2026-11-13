extends RefCounted
# XƯỞNG, ĐƠN HÀNG, CÔNG TRÌNH NHỎ: phần luật bản web còn thiếu ở bản Godot (chép 1:1).
#  - Xưởng g.work: đếm xưởng đã xây theo loại (UF), danh sách xưởng đã xây (CI, nvHasWork), số món đang xếp
#    hàng (F$), giờ còn lại cả hàng đợi (xL), xong cả hàng đợi bằng sen đỏ (qJ), dời xưởng (ytt, g.fac).
#  - Việc làng nhờ (rq) còn hợp lệ không (UJ: xưởng / chuồng / ruộng).
#  - Đơn hàng g.orders: số bậc đơn theo số đã giao (v1, g.delivered), vá bản lưu cũ (u$: đúng người đặt ↔ quán,
#    h$: đơn cũ thêm cho đủ 3 món, m3), xếp đơn theo lời (P$, _9, WF, GF), đơn kẹt lâu thì đổi (G$, jF).
#  - Hoa cỏ nhỏ g.minis: Bj, wtt.
#  - Bãi bùn khi nước ròng g.td / g.tdh (bS, gk, IK; con nước p6, GN, pk, FN, dk).
# Vẽ, hạt bay, âm thanh, chuỗi ký hiệu để vẽ lại (Lj, DU, Pj, zj, Nj, gin, A5, ro, Jt): không chép.
# Hàm của hệ khác mà bản web gọi: nhận qua ext (Callable), chưa gán thì làm như web khi hàm chưa có / giá trị mặc định.
#   qs() -> bool            mùa nước nổi (w_ruong.qs): biến mu của bản web
#   O0() -> int             số khúc sông Vàm đã mua (w_ruong.o0)
#   v6() -> Array           các chỗ bãi bùn hôm nay [{gx, gy, x, y, k, key, ph}] (hệ sông: SGEO, p0)
#   aeTide(dt: float)       FN(): ghe thương lái (Ae.st == 0 && Ae.t > 0) bớt Ae.t -= dt
#   bdMode() -> String      Mt.mode của bảng Xây dựng (ui_bd.mode), mặc định "off"
#   u2(id: String) -> int   số lần gieo giống id đang xếp việc (farm.seeds_queued)
var G
var ext := {}

const LP := 4               # Lp: chừa lại 4 giống mỗi loại cây
const GS := 12.42           # gS: chu kỳ con nước (giờ)
var Lm := 0.0               # Lm: mực nước ròng mượt (vẽ)
var FA := {}                # FA: GF nhớ
var os := {}                # Ur.os: số lần G$ thấy đơn kẹt

func _init(game) -> void:
	G = game

func _x(n: String, args := [], def = null):
	var f = ext.get(n)
	if f is Callable and (f as Callable).is_valid():
		return (f as Callable).callv(args)
	return def

func step(t: float, offline: bool) -> void:
	if not offline:
		IK(t)

# ------------------------------------------------------------------ xưởng (g.work)
func UF(t: String) -> int:   # UF
	var a := 0
	for n in G.xw.N0:
		if G.xw.sr[n].type == t and G.g.work.get(n) is Dictionary and int(G.g.work[n].get("b", 0)):
			a += 1
	return a

func nvHasWork() -> bool:   # nvHasWork
	for k in G.xw.N0:
		if G.g.work.get(k) is Dictionary and int(G.g.work[k].get("b", 0)):
			return true
	return false

func CI() -> Array:   # CI
	return G.xw.N0.filter(func(k): return G.g.work.get(k) is Dictionary and int(G.g.work[k].get("b", 0)) != 0)

func F_(t: String) -> int:   # F$
	var a := 0
	for n in G.xw.N0:
		var e = G.g.work.get(n)
		if e is Dictionary and e.get("q") is Array:
			for r in e.q:
				if r == t:
					a += 1
	return a

func xL(t: String) -> float:   # xL: giây còn lại cả hàng đợi
	var a = G.g.work.get(t)
	if not (a is Dictionary) or a.q.is_empty():
		return 0.0
	var n := 0.0
	for o in a.q.size():
		var r: String = a.q[o]
		n += float(G.xw.R[r].time) - (0.0 if o else float(a.p))
	var e: float = G.xw.mc(t)
	return n / maxf(1.0, e)

func qJ(t: String) -> void:   # qJ: xong cả hàng đợi bằng sen đỏ
	var a = G.g.work.get(t)
	if not (a is Dictionary) or a.q.is_empty():
		return
	var n: int = G.vn.ro(xL(t))
	if G.spend_ngoc(n):
		for e in a.q:
			a.r[e] = int(a.r.get(e, 0)) + 1
			G.nv.qi(G.xw.sr[t].type)
		a.q = []
		a.p = 0.0
		G.toast.emit(String(G.xw.sr[t].name) + " làm xong hết hàng đợi, tốn " + str(n) + " sen đỏ.")
		G.mark()

func ytt(t: String, a: int, n: int) -> void:   # ytt: dời xưởng / chuồng (Th bỏ chỗ cũ, yb, Th chiếm chỗ mới)
	if G.xw.sr.has(t):
		G.xw.sr[t].gx = a
		G.xw.sr[t].gy = n
	if not (G.g.get("fac") is Dictionary):
		G.g.fac = {}
	G.g.fac[t] = [a, n]
	if G.lang != null:
		G.lang.changed()

# ------------------------------------------------------------------ việc làng nhờ
func UJ(t: Dictionary) -> bool:   # UJ
	if G._now_ms() - float(t.get("t0", 0)) > 3 * 3600000.0:
		return false
	var k := String(t.get("k", ""))
	if k == "w":
		var a = G.g.work.get(t.key)
		return a is Dictionary and not a.q.is_empty()
	if k == "p":
		var n: Dictionary = G.vn.Q[t.key]
		var P = G.g.pens.get(t.key, [])
		for e in (P if P is Array else []):
			if not e.get("b", 0) and not e.get("s", 0) and float(e.p) >= 0.0 and float(e.p) < float(n.time):
				return true
		return false
	if k == "r":
		for e in G.g.plots:
			if e.get("u", 0) and e.get("c") != null and not G.ripe(e):
				return true
		return false
	return false

# ------------------------------------------------------------------ đơn hàng (g.orders, g.delivered)
func v1() -> int:   # v1
	return mini(4, int(floor(int(G.g.delivered) / 2.0)))

func _e(n: Dictionary, f: String) -> int:
	return n.items.filter(func(s): return G._g3(String(G.D.shop.get(f, "")), String(s[0]))).size()

func u_() -> bool:   # u$: vá bản lưu cũ, người đặt đúng quán và mỗi người một đơn
	var k5: Array = G.D.who
	var t := {}
	var a := false
	for n in G.g.orders:
		if not (n is Dictionary) or not (n.get("items") is Array) or not k5.has(n.get("who")):
			continue
		var w: String = n.who
		if not t.has(w) and n.get("shop") == G.D.shop.get(w) and (n.get("sf", 0) or _e(n, w) == n.items.size()):
			t[w] = 1
			n.sf = 1
			continue
		var r: Array = k5.filter(func(f): return not t.has(f))
		if r.is_empty():
			r = k5.duplicate()
		var o := -999999
		for f in r:
			o = maxi(o, _e(n, f))
		var l: Array = r.filter(func(f): return _e(n, f) == o)
		var c: String
		if l.has(w):
			c = w
		elif l.has("Bà Tư") and o < n.items.size():
			c = "Bà Tư"
		else:
			c = l[randi() % l.size()]
		n.who = c
		n.shop = G.D.shop.get(c)
		n.sf = 1
		t[c] = 1
		a = true
	if a:
		G.mark()
	return a

func h_() -> bool:   # h$: đơn cũ (m3 < 2) ít hơn 3 món thì thêm món cho đủ 3
	var k5: Array = G.D.who
	var t := false
	var a = null
	for n in G.g.orders:
		if not (n is Dictionary) or not (n.get("items") is Array) or int(n.get("m3", 0)) >= 2 or not k5.has(n.get("who")):
			continue
		n.m3 = 2
		t = true
		if n.items.size() >= 3:
			continue
		if a == null:
			var lv: Array = G._lv_items()
			a = []
			for p in lv.size():
				if lv.find(lv[p]) == p:
					a.append(lv[p])
		var r := {}
		for h in n.items:
			r[h[0]] = 1
		var o: Array = a.filter(func(h): return not r.has(h) and G._g3(String(n.shop), String(h)))
		var l := maxf(10.0, float(n.reward) / 1.65 / n.items.size())
		while n.items.size() < 3 and o.size():
			var c: String = o.pop_at(randi() % o.size())
			var f := float(G.item(c).get("sell", 0))
			if f == 0.0:
				f = 10.0
			var s := maxi(1, mini(15, int(round(l / f))))
			n.items.append([c, s])
			n.reward = int(n.reward) + int(round(s * f * 1.65))
	if t:
		G.mark()
	return t

func _u2(id: String) -> int:
	return int(_x("u2", [id], 0))

func GF(t: String, a := 0) -> float:   # GF: giây để làm ra 1 món (ước)
	if FA.has(t):
		return FA[t]
	var n := 600.0
	if G.D.crops.has(t):
		n = float(G.crop(t).get("time", 0))
		if n == 0.0:
			n = 300.0
	elif G.xw.R.has(t) and a < 4:
		var e: Dictionary = G.xw.R[t]
		n = float(e.get("time", 0))
		if n == 0.0:
			n = 120.0
		for o in e["in"]:
			n += GF(String(o[0]), a + 1) * float(o[1]) * 0.5
	else:
		for o in G.vn.DI:
			if G.vn.Q[o].get("make") == t:
				n = float(G.vn.Q[o].time) / 2.0
		var Ei: Dictionary = G.lang.C.Ei if G.lang != null else {}
		for r in Ei:
			if Ei[r].get("p") == t:
				n = float(Ei[r].time) / 3.0
	FA[t] = n
	return n

func WF(t: Array) -> float:   # WF: giây còn phải làm cho đủ đơn
	var a := 0.0
	for n in t:
		var id: String = n[0]
		var e := maxi(0, int(n[1]) - (int(G.g.barn.get(id, 0)) - _u2(id) - (LP if G.D.crops.has(id) else 0)))
		if e > 0:
			a += e * GF(id)
	return a

func _9(t: Dictionary) -> float:   # _9: lời của đơn so với công làm
	var r := float(t.get("reward", 0))
	if r == 0.0:
		r = 1.0
	return r / (1.0 + WF(t.items) / 60.0)

func P_() -> Array:   # P$: đơn đang mở, lời nhất trước
	var now: float = G._now_ms()
	var L := []
	for a in G.g.orders.size():
		var o = G.g.orders[a]
		if o is Dictionary and not (float(o.get("w", 0)) > now):
			L.append({"o": o, "i": a})
	L.sort_custom(func(t, a): return _9(a.o) < _9(t.o))
	return L

func jF(t: Array) -> bool:   # jF: kho đủ cho đơn (chừa giống đang gieo + 4 giống)
	return t.all(func(a): return int(G.g.barn.get(a[0], 0)) - _u2(String(a[0])) - (LP if G.D.crops.has(a[0]) else 0) >= int(a[1]))

func G_() -> bool:   # G$: đơn chưa đủ hàng quá 1800 lần xét thì đổi đơn khác (mỗi lần một đơn)
	var t := {}
	var a := false
	var now: float = G._now_ms()
	for r in G.g.orders.size():
		var e = G.g.orders[r]
		if not (e is Dictionary) or float(e.get("w", 0)) > now:
			continue
		var o: String = "+".join(e.items.map(func(l): return String(l[0]) + str(int(l[1])))) + "|" + str(int(e.reward))
		t[o] = 1
		if jF(e.items):
			os[o] = 0
			continue
		os[o] = int(os.get(o, 0)) + 1
		if not a and int(os[o]) > 1800:
			G.swap(r)
			os.erase(o)
			a = true
	for n in os.keys():
		if not t.has(n):
			os.erase(n)
	return a

# ------------------------------------------------------------------ hoa cỏ nhỏ (g.minis)
func Bj(t: int, a: int):   # Bj
	return G.g.minis.get(str(t) + "," + str(a))

func wtt() -> int:   # wtt
	return (G.g.get("minis", {}) as Dictionary).size() if G.g.get("minis") is Dictionary else 0

# ------------------------------------------------------------------ bãi bùn khi nước ròng (g.td, g.tdh)
func dk() -> float:   # dk: giờ tính từ ngày 0
	return G.day() * 24 + G.nv.hour()

func p6(t = null) -> float:   # p6: mực con nước -1..1
	return cos((dk() if t == null else float(t)) / GS * PI * 2.0)

func GN() -> int:   # GN: số thứ tự con nước
	return int(floor((dk() + GS / 2.0) / GS))

func pk() -> bool:   # pk: nước ròng (không phải mùa nước nổi)
	return not bool(_x("qs", [], false)) and p6() < -0.35

func FN() -> bool:   # FN: nước lớn
	return p6() > 0.35

func bS(t: Dictionary) -> bool:   # bS: chỗ bãi bùn này con nước này đã mò rồi
	var a = G.g.get("td")
	return a is Dictionary and int(a.get("c", -1)) == GN() and a.get("p") is Dictionary and bool(a.p.get(t.key, 0))

func gk(t: String) -> bool:   # gk: mò bãi bùn
	var a: Array = _x("v6", [], [])
	var n = null
	for r in a:
		if r.key == t:
			n = r
	if n == null or bS(n):
		return false
	if not pk():
		G.toast.emit("Nước lên rồi, bãi bùn ngập mất. Đợi con nước ròng lần sau nha.")
		return false
	var g6 := GN()   # g6: con nước của v6()
	if not (G.g.get("td") is Dictionary) or int(G.g.td.get("c", -1)) != g6:
		G.g.td = {"c": g6, "p": {}}
	G.g.td.p[n.key] = 1
	var k: String = n.k
	var e: int
	if k == "oc_buou":
		e = 2 + randi() % 3
	elif k == "tep" or k == "oc" or k == "luc_binh":
		e = 3 + randi() % 3
	else:
		e = 1 + randi() % 2
	G.g.barn[k] = int(G.g.barn.get(k, 0)) + e
	G.float_text.emit(float(n.x), float(n.y), "+" + str(e) + " " + G.item_name(k))
	G.vib(8)
	G.nv.qi("bun")
	G.mark()
	return true

func IK(t: float) -> void:   # IK: báo nước ròng mỗi con nước
	var a := 1.0 if pk() else 0.0
	Lm += (a - Lm) * minf(1.0, t * 0.6)
	if FN():
		_x("aeTide", [t * 0.6])
	var n := GN()
	if a and int(_x("O0", [], 0)) and G.g.get("tdh") != n and String(_x("bdMode", [], "off")) == "off":
		G.g.tdh = n
		G.get_tree().create_timer(1.2).timeout.connect(func(): G.toast.emit("Nước ròng! Sông Vàm lộ bãi bùn hai bên bờ. Ra bắt cá kèo, mò ốc, vớt lục bình đi."))
