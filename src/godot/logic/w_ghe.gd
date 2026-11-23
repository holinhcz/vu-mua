extends RefCounted
# GHE THƯƠNG HỒ (bản web: Ae, mg, $M, tT, fm, aT, Hd, vx, Gq, OD; bản đang chạy là module BUON "thùng hàng"):
# có khúc sông Vàm và Bến ghe sát bờ (ben3 / ben4 có ô trên mé sông) thì 5 giờ tới 21 giờ, cách 2-7 phút, ghe từ một
# chợ miệt dưới ghé bến, đặt 5-6 thùng hàng (6 khi có từ 2 khúc sông), đậu 4 tiếng (g.gh lưu trong bản lưu).
# Chất thùng nào trả tiền thùng đó (giá chợ x1,3); chất đủ thùng thưởng thêm nửa tiền, kinh nghiệm, vật liệu hiếm.
# Nhổ neo xong 1-2 tiếng sau ghe khác mới ghé (g.ghn). Hình ghe: ghe_ve.gd; bảng: w_cho_ui.gd (open_ghe).

var G
var WC      # w_cho.gd: O0, s2, G9, W5, qi
var WR      # w_ruong.gd: _hrl
var U       # ui.gd

const MIN := 60000.0
const HOUR := 3600000.0
const STAY := 4.0 * HOUR
const FQ := ["Cái Bè", "Cần Thơ", "Cái Răng", "Phong Điền", "Ngã Bảy", "Long Xuyên", "Vĩnh Long", "Mỹ Tho", "Sa Đéc", "Châu Đốc"]
const K := ["can", "may", "gach"]   # vật liệu hiếm thưởng khi chất đủ thùng

# Ae: st 0 chưa có, 1 đang vào bến, 2 đậu, 3 nhổ neo
var Ae := {"st": 0, "t": 70.0 + randf() * 60.0, "o": null, "key": "", "c": [0.0, 0.0], "ax": "u", "off": 0.0, "al": 0.0, "left": 0.0, "offers": [], "from": ""}
var gx := 0      # đã nhắc "chưa có bến"

func _init(game) -> void:
	G = game

func _now() -> float:
	return G._now_ms()

static func _r(a: float, b: float) -> float:
	return a + randf() * (b - a)

func _ta(s: String) -> void:
	G.toast.emit(s)

func _mode() -> String:
	return String(U.bdp.mode) if U != null and U.bdp != null else "off"

func gh():   # g.gh
	var a = G.g.get("gh")
	return a if a is Dictionary else null

# ------------------------------------------------------------------ bến
func yh(x: int, y: int) -> bool:   # yh: ô mé sông của khúc sông Vàm
	var n: String = G.lang.fo(x, y)
	return n != "" and WC.W5.has(n) and G.lang.il(x, y) == "canal"

func ben_ok(t: Dictionary) -> bool:   # $M: bến có ô trên mé sông đã mua
	for a in int(t.fw):
		for n in int(t.fd):
			var x: int = int(t.gx) + a
			var y: int = int(t.gy) + n
			if yh(x, y) and G.lang.ci(G.lang.fo(x, y)):
				return true
	return false

func mg() -> Array:   # mg: bến ghe dùng được (có ô trên mé sông Vàm), hướng xoay nào cũng được
	return WR._hrl().filter(func(p): return String(p.id) in ["ben", "ben2", "ben3", "ben4"] and ben_ok(p))   # (bản 512) đủ 4 hướng xoay (trước chỉ nhận ben3 / ben4: bến xoay 2 hướng kia ghe không ghé)

func fm() -> float:   # fm: giây tới lần ghé kế
	var t: int = WC.O0()
	return _r(130, 230) if t >= 3 else (_r(190, 310) if t == 2 else _r(260, 420))

func _px(x: int, y: int) -> int:   # px: ô nước (ao, sông) hoặc mé sông
	return 1 if G.lang.is_water(x, y) or G.lang.il(x, y) == "canal" else 0

func tT(t: Dictionary) -> Dictionary:   # tT: chỗ ghe đậu cạnh bến {c, ax}
	var L = G.lang
	L._a1()
	var a = null
	var nb := -1e9
	var o: float = float(t.gx) + float(t.fw) / 2.0
	var l: float = float(t.gy) + float(t.fd) / 2.0
	var inn := func(h: int, p: int) -> bool: return h >= int(t.gx) and h < int(t.gx) + int(t.fw) and p >= int(t.gy) and p < int(t.gy) + int(t.fd)
	var f := func(h: int, p: int) -> int:
		var k := str(h) + "," + str(p)
		var n := 1 if (L.a1.get(k, []) as Array).size() > 1 else 0
		for d in L.yc(h, p):
			if d != "water":
				return n + 1
		return n
	for e in range(int(t.gx) - 2, int(t.gx) + int(t.fw) + 2):
		for r in range(int(t.gy) - 2, int(t.gy) + int(t.fd) + 2):
			if inn.call(e, r) or not _px(e, r):
				continue
			for hh in [["u", 1, 0], ["v", 0, 1]]:
				var p: int = hh[1]
				var d: int = hh[2]
				var v := _px(e - p, r - d) + _px(e + p, r + d)
				var x := (1 if inn.call(e - p, r - d) else 0) + (1 if inn.call(e + p, r + d) else 0)
				var k: int = f.call(e, r) + f.call(e - p, r - d) + f.call(e + p, r + d)
				var M := 0
				for T in range(-2, 3):
					for w in range(-2, 3):
						M += _px(e + T, r + w)
				var E := v * 3.0 - x * 12.0 - k * 3.0 - Vector2(e + 0.5, r + 0.5).distance_to(Vector2(o, l)) * 1.8 + M * 0.15 + (e + r) * 0.05
				if E > nb:
					nb = E
					a = {"c": [e + 0.5, r + 0.5], "ax": hh[0]}
	if a == null:
		var id := String(t.id)
		if id == "ben":
			a = {"c": [float(t.gx) + float(t.fw) / 2.0, float(t.gy) + float(t.fd) + 0.5], "ax": "u"}
		elif id == "ben3":
			a = {"c": [float(t.gx) + float(t.fw) / 2.0, float(t.gy) - 0.5], "ax": "u"}
		elif id == "ben4":
			a = {"c": [float(t.gx) - 0.5, float(t.gy) + float(t.fd) / 2.0], "ax": "v"}
		else:
			a = {"c": [float(t.gx) + float(t.fw) + 0.5, float(t.gy) + float(t.fd) / 2.0], "ax": "v"}
	return a

# ------------------------------------------------------------------ thùng hàng (ft, j)
func _ok(id: String, q: int) -> bool:   # c(id, q): món có, tới cấp, làm ra được
	return not G.item(id).is_empty() and G.bf(id) <= G.lv() and WC.G9(id, q)

func ft() -> Array:   # ft: 5-6 thùng
	var gt := []
	for x in WC.s2():
		if not gt.has(x) and _ok(x, 3):
			gt.append(x)
	if gt.is_empty():
		gt = ["lua"]
	var A := 6 if WC.O0() >= 2 else 5
	var At := []
	var Pt := []
	for z in A:
		var Y: Array = gt.filter(func(e): return not Pt.has(e))
		var Lt: String = (Y if Y.size() else gt).pick_random()
		Pt.append(Lt)
		var Ft := int(G.item(Lt).get("sell", 10))
		if Ft == 0:
			Ft = 10
		var q := 6 + randi() % 3 if Ft < 60 else (4 + randi() % 3 if Ft < 300 else 2 + randi() % 2)
		At.append({"id": Lt, "q": q, "xu": int(round(q * G.price(Lt) * 1.3)), "done": 0})
	return At

func bonus(cr: Array) -> Dictionary:   # j: thưởng chất đủ thùng
	var a := 0
	for c in cr:
		a += int(c.xu)
	return {"xu": int(round(a * 0.5)), "xp": maxi(20, int(round(a / 6.0)))}

# ------------------------------------------------------------------ ghé, nhổ neo
func st() -> bool:   # st: ghe vào bến
	var gt := mg()
	if gt.is_empty():
		return false
	var A: Dictionary = gt.pick_random()
	var At := tT(A)
	var Pt := ft()
	Ae.o = A
	Ae.key = str(A.gx) + "," + str(A.gy)
	Ae.c = At.c
	Ae.ax = At.ax
	Ae.off = -7.0
	Ae.al = 0.0
	Ae.st = 1
	Ae.offers = Pt
	Ae.from = FQ.pick_random()
	Ae.left = STAY / 1000.0
	G.g.gh = {"from": Ae.from, "cr": Pt, "until": _now() + STAY, "key": Ae.key}
	_ta("Ghe thương hồ từ " + String(Ae.from) + " cập bến, cần " + str(Pt.size()) + " thùng hàng. Ghe đậu 4 tiếng, chất đủ thùng có thưởng lớn!")
	G.vib([12, 40, 12])
	G.mark()
	return true

func Db(t: String) -> void:   # Db: nhổ neo
	if Ae.st == 1 or Ae.st == 2:
		Ae.st = 3
		if t != "":
			_ta(t)
		panel_close.emit()

signal panel_close

func ut(ok: bool) -> void:   # ut: hết lượt ghé (ok = chất đủ thùng)
	var A = gh()
	G.g.gh = null
	G.g.ghn = _now() + _r(60, 120) * MIN
	if ok and A != null:
		var At := bonus(A.cr)
		var Pt := []
		G.g.coins = int(G.g.coins) + int(At.xu)
		G.add_xp(int(At.xp), "deliver")
		for z in 2:
			var Y: String = K.pick_random()
			var Lt := 1 + randi() % 2
			G.nv.S0(Y, Lt)
			Pt.append(str(Lt) + " " + String(G.item_name(Y)).to_lower())
		WC.qi("ghe")
		_ta("Chất đủ thùng! Ghe thưởng thêm " + G.fmt_n(int(At.xu)) + " xu, " + str(int(At.xp)) + " kinh nghiệm, " + ", ".join(PackedStringArray(Pt)) + ".")
		Db("Ghe thương hồ cảm ơn, nhổ neo đi tiếp!")
	else:
		Db("Ghe thương hồ hết giờ đậu, đã nhổ neo. Thùng chất rồi vẫn được trả tiền.")
	G.mark()

func Hd(i: int) -> bool:   # Hd: chất thùng i lên ghe
	var offers: Array = Ae.offers
	if i < 0 or i >= offers.size():
		return false
	var A: Dictionary = offers[i]
	if int(A.done) or Ae.st != 2 or gh() == null:
		return false
	if int(G.g.barn.get(A.id, 0)) < int(A.q):
		_ta("Kho chưa đủ " + WC.ho(A.id, int(A.q)) + ".")
		return false
	G.g.barn[A.id] = int(G.g.barn[A.id]) - int(A.q)
	A.done = 1
	G.g.coins = int(G.g.coins) + int(A.xu)
	G.add_xp(maxi(3, int(round(int(A.xu) / 10.0))), "deliver")
	_ta("Chất thùng " + WC.ho(A.id, int(A.q)) + " lên ghe, nhận " + G.fmt_n(int(A.xu)) + " xu.")
	G.vib(12)
	if offers.all(func(o): return int(o.done)):
		ut(true)
	else:
		G.mark()
	return true

# ------------------------------------------------------------------ mỗi bước (aT bản BUON)
var test_hold := false   # (bản 515) lệnh thử ghet: giữ ghe đứng yên (không có bến vẫn mở được bảng)
func step(dt: float) -> void:
	if test_hold:
		return
	var A = gh()
	var At := _now()
	if Ae.st == 0:
		if A != null and float(A.until) > At:   # đang có ghe trong bản lưu: cho ghé lại đúng bến
			if _mode() != "off":
				return
			var Pt := mg()
			if Pt.is_empty():
				return
			var zt: Dictionary = Pt[0]
			for p in Pt:
				if str(p.gx) + "," + str(p.gy) == String(A.key):
					zt = p
			var Y := tT(zt)
			Ae.o = zt
			Ae.key = str(zt.gx) + "," + str(zt.gy)
			A.key = Ae.key
			Ae.c = Y.c
			Ae.ax = Y.ax
			Ae.off = -7.0
			Ae.al = 0.0
			Ae.st = 1
			Ae.offers = A.cr
			Ae.from = A.from
			Ae.left = (float(A.until) - At) / 1000.0
			return
		if A != null and float(A.until) <= At:
			G.g.gh = null
			G.g.ghn = At + _r(60, 120) * MIN
		if _mode() != "off":
			return
		var Lt: float = G.nv.hour()
		var ghn := float(G.g.get("ghn", 0))
		if Lt < 5 or Lt >= 21 or WC.O0() == 0 or (ghn > 0 and At < ghn and Ae.t > 1):
			return
		Ae.t -= dt
		if Ae.t > 0:
			return
		Ae.t = fm()
		if not st() and not gx:
			gx = 1
			_ta("Ghe thương hồ muốn ghé mà chưa có bến bên sông. Đặt Bến ghe sát bờ sông Vàm (một phần nằm trên mặt sông) nhé.")
		return
	var found := false
	for p in mg():
		if str(p.gx) + "," + str(p.gy) == Ae.key:
			found = true
			Ae.o = p
	if not found and Ae.st < 3:
		Ae.st = 0
		Ae.t = fm()
		panel_close.emit()
		return
	if Ae.st == 1:
		Ae.off = minf(0.0, Ae.off + dt * 1.5)
		Ae.al = minf(1.0, Ae.al + dt * 0.8)
		Ae.left = (float(A.until) - At) / 1000.0 if A != null else 0.0
		if Ae.off >= 0:
			Ae.st = 2
	elif Ae.st == 2:
		Ae.al = 1.0
		Ae.left = (float(A.until) - At) / 1000.0 if A != null else 0.0
		if A == null or Ae.left <= 0:
			ut(false)
	elif Ae.st == 3:
		Ae.off += dt * 1.5
		Ae.al = maxf(0.0, Ae.al - dt * 0.35)
		if Ae.off > 7 or Ae.al <= 0:
			Ae.st = 0
			Ae.t = fm()

# ------------------------------------------------------------------ chỗ ghe, chạm ghe
func vx() -> Array:   # vx: chỗ ghe (đang trôi vào / ra theo trục)
	var t: Array = Ae.c
	var a: float = float(t[0]) + (Ae.off if Ae.ax == "u" else 0.0)
	var n: float = float(t[1]) + (Ae.off if Ae.ax == "v" else 0.0)
	if Ae.ax == "u" and G.w_all.WSG != null:
		n += G.w_all.WSG.c(a) - G.w_all.WSG.c(float(t[0]))
	return [a, n]

func th() -> float:   # góc ghe theo dòng sông (trục u)
	if Ae.ax != "u" or G.w_all.WSG == null:
		return 0.0
	return atan(G.w_all.WSG.sl(vx()[0]))

func Gq(w: Vector2):   # Gq: chạm ghe
	if Ae.st != 2 and Ae.st != 1:
		return null
	var n := vx()
	var e: float = G.lang.F.en(n[0], n[1])
	var r: float = G.lang.F.nn(n[0], n[1])
	return {"type": "ghe"} if absf(w.x - e) < 80 and w.y >= r - 125 and w.y <= r + 20 else null

func shown_offers() -> Array:   # lớp bọc yg: chỉ treo 3 thùng chưa chất
	return (Ae.offers as Array).filter(func(o): return not int(o.done)).slice(0, 3)

static func cm(t: float) -> String:   # cm: "1 giờ 5 phút" / "4:05"
	var s := maxi(0, int(ceil(t)))
	if s >= 3600:
		return str(s / 3600) + " giờ " + str((s % 3600) / 60) + " phút"
	return str(s / 60) + ":" + ("%02d" % (s % 60))
