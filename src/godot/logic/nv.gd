extends RefCounted
# Sổ nhiệm vụ chép từ bản web (17_so_nhiem_vu.js): hằng ngày (6 việc + rương năng động + chuỗi ngày),
# tuần (7 việc + rương tuần), thành tựu, chuỗi công trình, lịch sự kiện 14 ngày.
# Tên hàm giữ tên bản web ở chú thích để dễ đối chiếu. g.nv: day/c/cl/rot/sw/vg/pb, wk, st, ln, ach, evk/ev.
# Phần bản Godot chưa có (vật nuôi, xưởng, câu cá, dân làng, hợp tác xã, bếp) đếm bằng 0 như người mới chơi bên web.

var G   # game.gd
var xI := -1   # thử: ép ngày $4 (bản web: xI)

func _init(game) -> void:
	G = game

# ------------------------------------------------------------------ số ngẫu nhiên, ngày
static func _i32(x: int) -> int:
	x = x & 0xffffffff
	return x - 0x100000000 if x >= 0x80000000 else x

static func _u(x: int) -> int:   # x >>> 0
	return x & 0xffffffff

static func _imul(a: int, b: int) -> int:
	return _i32(_i32(a) * _i32(b))

class Yu:   # yu(t): bộ số ngẫu nhiên theo hạt
	var a := 0
	func _init(t: int) -> void:
		a = t & 0xffffffff
		a = a - 0x100000000 if a >= 0x80000000 else a
	func next() -> float:
		a = _i(a + 1831565813)
		var n := _mul(a ^ (_uu(a) >> 15), 1 | a)
		n = _i(_i(n + _mul(n ^ (_uu(n) >> 7), 61 | n)) ^ n)
		return float(_uu(n ^ (_uu(n) >> 14))) / 4294967296.0
	static func _i(x: int) -> int:
		x = x & 0xffffffff
		return x - 0x100000000 if x >= 0x80000000 else x
	static func _uu(x: int) -> int:
		return x & 0xffffffff
	static func _mul(x: int, y: int) -> int:
		return _i(_i(x) * _i(y))

static func Me(t: int, a: int) -> float:
	var n := _i32(t * 374761393 + a * 668265263)
	var x := _i32(n ^ (_u(n) >> 13))
	n = _i32(int(float(x) * 1274126177.0))
	return float(_u(n ^ (_u(n) >> 16))) / 4294967295.0

func _now() -> float:
	return Time.get_unix_time_from_system()

func _bias() -> float:   # phút lệch giờ địa phương (getTimezoneOffset đổi dấu)
	return float(Time.get_time_zone_from_system()["bias"])

func d4() -> int:   # $4: số ngày địa phương từ 1/1/1970
	if xI >= 0:
		return xI
	return int(floor(_now() / 86400.0 + _bias() / 1440.0))

func _nowd() -> float:
	return _now() / 86400.0 + _bias() / 1440.0

func Ao() -> int:   # yyyymmdd
	var t := Time.get_date_dict_from_system()
	return int(t.year) * 10000 + int(t.month) * 100 + int(t.day)

func week(d := -999999) -> int:   # nvWeek: tuần bắt đầu 0 giờ thứ Hai (ngày 0 là thứ Năm)
	return int(floor(float((d4() if d == -999999 else d) + 3) / 7.0))

func week_left() -> float:   # nvWeekLeft
	return maxf(0.0, ((week() + 1) * 7 - 3 - _nowd()) * 86400.0)

func hour() -> float:   # Pc / aQ (d0: hh đè giờ khi thử)
	if G.troi != null and G.troi.hh >= 0.0:
		return G.troi.hh
	if G.cfg.d == "fast":
		return fmod(Time.get_unix_time_from_system() / 60.0, 24.0)
	if G.cfg.d == "day":
		return 12.0
	if G.cfg.d == "night":
		return 0.0
	var t := Time.get_time_dict_from_system()
	return float(t.hour) + float(t.minute) / 60.0 + float(t.second) / 3600.0

static func ao(t: float) -> String:
	var s := int(maxf(0.0, ceil(t)))
	var a := s / 3600
	var n := (s % 3600) / 60
	var e := s % 60
	if a >= 24:
		var r := a / 24
		a %= 24
		return str(r) + " ngày" + (" " + str(a) + " giờ" if a else "")
	if a:
		return str(a) + " giờ" + (" " + str(n) + " phút" if n else "")
	if n >= 10:
		return str(n) + " phút"
	if n:
		return str(n) + " phút" + (" " + str(e) + " giây" if e else "")
	return str(e) + " giây"

func v0(t: float) -> int:   # xu theo cấp, KF = 0,3
	return maxi(1, int(round(t * 0.3)))

func jr() -> int:
	return G.lv()

# ------------------------------------------------------------------ thời tiết (Wd) và lễ (Mm)
const WB := [[0.68, 0.2, 0.05, 0.07], [0.42, 0.16, 0.16, 0.26], [0.32, 0.4, 0.22, 0.06], [0.66, 0.12, 0.04, 0.18]]
const TQ := ["nang", "mua", "giong", "han"]
const FEST := [[0, 1], [1, 6], [2, 7], [3, 4]]   # Tết, Vu Lan, Trung Thu, Kỳ Yên: [mùa, ngày]

static func fest_day(a: int) -> bool:   # nN(a)
	var d := posmod(a, 28)
	for f in FEST:
		if f[0] == d / 7 and f[1] == d % 7 + 1:
			return true
	return false

static func Hx(t: int) -> String:
	var a := int(floor(t / 4.0))
	var n := int(floor(posmod(a, 28) / 7.0))
	if fest_day(a):
		return "nang"
	var e: Array = WB[n]
	var r := Me(t * 7 + 3, 911)
	var c := posmod(a, 7) + 1
	if n == 2 and c >= 2 and c <= 6:
		r = 0.15 + r * 0.8
	var o := 0.0
	for l in 4:
		o += float(e[l])
		if r < o:
			return TQ[l]
	return "nang"

func Wd() -> String:
	var h := hour()
	var k := Hx(G.day() * 4 + int(floor(h / 6.0)))
	if (k == "mua" or k == "giong") and fposmod(h, 6.0) >= 2.0:
		return "nang"
	return k

# ------------------------------------------------------------------ trạng thái
func Pl() -> Dictionary:
	var g: Dictionary = G.g
	if not (g.get("nv") is Dictionary):
		g.nv = {}
	var n: Dictionary = g.nv
	for k in ["c", "cl", "ln", "ach", "ev"]:
		if not (n.get(k) is Dictionary):
			n[k] = {}
	var d := Ao()
	if int(n.get("day", -1)) != d:
		n.day = d
		n.c = {}
		n.cl = {}
		n.rot = null
		n.sw = 0
		n.vg = null
		n.pb = snap()
	if not (n.get("pb") is Dictionary):
		n.pb = snap()
	var w := week()
	if not (n.get("wk") is Dictionary) or int(n.wk.get("w", -1)) != w:
		n.wk = {"w": w, "c": {}, "cl": {}, "rot": null, "dd": {}}
	return n

func snap() -> Dictionary:   # nvSnap: mốc bộ đếm nhân vật lúc đầu ngày
	var p: Dictionary = G.g.pc
	var o := {}
	for k in p.get("cnt", {}).keys():
		o[k] = int(p.cnt[k])
	o.ck = int(p.get("ck", 0))
	return o

func OL(k: String) -> int:
	var p: Dictionary = G.g.pc
	var b: Dictionary = Pl().pb
	var v := int(p.get("ck", 0)) if k == "ck" else int(p.get("cnt", {}).get(k, 0))
	return v - int(b.get(k, 0))

func S8(k: String, n := 1) -> void:   # đếm một việc cho cả ngày lẫn tuần
	var v := Pl()
	v.c[k] = int(v.c.get(k, 0)) + n
	v.wk.c[k] = int(v.wk.c.get(k, 0)) + n

func Xs(k: String) -> int:
	return int(Pl().c.get(k, 0))

func nvW(k: String) -> int:
	return int(Pl().wk.c.get(k, 0))

# qi(k) + móc của sổ nhiệm vụ: g.sys.stats, S8, sự kiện
func qi(k: String, n := 1) -> void:
	var s: Dictionary = G.g.sys
	if not (s.get("stats") is Dictionary):
		s.stats = {}
	for _q in n:
		s.stats[k] = int(s.stats.get(k, 0)) + 1
		S8(k)
		OI(k)

# điều kiện mở việc: bản Godot chưa có vật nuôi, xưởng, cây trái, dân làng, hợp tác xã
func has_fam() -> bool: return false
func has_pen() -> bool: return G.vn != null and G.vn.has_any()   # nvHasPen
func has_work() -> bool: return false
func has_tree() -> bool: return false
func has_hx() -> bool: return false

# ------------------------------------------------------------------ 1. hằng ngày
const NVPT := 15
const NVBASE := [
	{"id": "harvest", "n": "Thu hoạch 10 lần", "m": 10, "pt": 20},
	{"id": "deliver", "n": "Giao 2 đơn hàng", "m": 2, "pt": 20, "go": 1}]
const WI := [
	{"id": "water", "n": "Tưới 10 ô ruộng", "m": 10},
	{"id": "plant", "n": "Gieo hạt 12 ô", "m": 12},
	{"id": "collect", "n": "Lượm 5 sản phẩm vật nuôi", "m": 5},
	{"id": "wc", "n": "Thu hàng xưởng 3 lần", "m": 3},
	{"id": "fish", "n": "Câu được 2 con cá", "m": 2, "go": 1},
	{"id": "cook", "n": "Nấu 1 bữa ở bếp nhà", "m": 1, "go": 1},
	{"id": "tharvest", "n": "Hái trái 3 lần", "m": 3},
	{"id": "chat", "n": "Trò chuyện với 2 nhà", "m": 2},
	{"id": "scn", "n": "Dọn 3 bụi cây, gốc cây", "m": 3},
	{"id": "dd", "n": "Hái 2 bụi điên điển", "m": 2},
	{"id": "bun", "n": "Bắt cá kèo, mò ốc 2 lần", "m": 2},
	{"id": "lo", "n": "Thăm lờ, lọp 2 lần", "m": 2},
	{"id": "cho", "n": "Mua bán ở chợ nổi", "m": 1},
	{"id": "help", "n": "Giúp bà con trong xã 3 lần", "m": 3, "go": 1},
	{"id": "com", "n": "Góp nồi cơm trưa (12:00–12:30)", "m": 1, "go": 1}]

func _ok(id: String) -> bool:
	match id:
		"collect": return has_pen()
		"wc": return has_work()
		"tharvest": return has_tree()
		"chat": return has_fam()
		"dd": return false      # qs() && O0(): chưa có bụi điên điển
		"bun": return false     # O0() > 0
		"lo": return false      # T1().set.length
		"cho": return false     # u4(): chợ nổi
		"help": return has_hx()
		"com": return hour() < 12.5
	return true

func _w(id: String, x: Dictionary) -> float:
	match id:
		"water": return 4.0 if x.wx == "han" else (0.0 if x.wx == "mua" or x.wx == "giong" else 1.0)
		"fish": return 3.0 if x.wx == "mua" else 1.0
		"tharvest": return 3.0 if x.sea == 1 else 1.0
		"scn": return 2.0 if x.sea == 0 else 1.0
		"dd": return 4.0
		"bun": return 3.0 if x.wx == "mua" else 1.0
		"lo": return 3.0 if x.wx == "mua" or x.wx == "giong" else 1.0
	return 1.0

func task_f(t: Dictionary) -> int:   # t.f()
	var id: String = t.id
	if t.get("vg", 0):
		var v: Dictionary = t.v
		return int(v.q) if v.get("done", 0) else mini(int(v.q), int(G.g.barn.get(v.id, 0)))
	match id:
		"cook": return OL("ck")
		"tharvest": return OL("tharvest")
		"scn": return OL("scn")
		"dd": return OL("dd")
		"help": return 0
		"com":
			var c = G.g.get("com")
			return 1 if c is Dictionary and int(c.get("day", 0)) == Ao() and int(c.get("p", 0)) > 0 else 0
	return Xs(id)

func ctx() -> Dictionary:
	return {"wx": Wd(), "sea": G.season()}

func _draw(R, x: Dictionary, skip: Array):   # nvDraw: rút 1 việc theo trọng số
	var L := []
	var W := []
	var sum := 0.0
	for t in WI:
		if _ok(t.id) and not skip.has(t.id):
			L.append(t)
			var w := _w(t.id, x)
			W.append(w)
			sum += w
	if sum <= 0.0:
		return null
	var r: float = (R.next() if R is Yu else randf()) * sum
	for i in L.size():
		r -= W[i]
		if r < 0.0:
			return L[i].id
	return null

func vg_task():   # nvVgTask: việc của làng (cần dân làng, bản Godot chưa có)
	return null

func vg_ready() -> bool:
	return false

func MI() -> Array:
	var n := Pl()
	if n.rot == null:
		var R := Yu.new(int(n.day))
		var x := ctx()
		var rot := []
		for t in NVBASE:
			rot.append(t.id)
		var k := 3 if vg_task() != null else 4
		while rot.size() < 2 + k:
			var tid = _draw(R, x, rot)
			if tid == null:
				break
			rot.append(tid)
		if vg_task() != null:
			rot.append("vg")
		n.rot = rot
	var out := []
	for tid in n.rot:
		if tid == "vg":
			var v = vg_task()
			if v != null:
				out.append(v)
			continue
		for t in NVBASE + WI:
			if t.id == tid:
				out.append(t)
				break
	return out

func is_base(t: Dictionary) -> bool:
	for b in NVBASE:
		if b.id == t.id:
			return true
	return false

func pt(t: Dictionary) -> int:   # nvPt
	return int(t.get("pt", NVPT)) * (2 if t.id == "help" and ff().id == "giup" else 1)

func done(t: Dictionary) -> bool:   # nvDone
	if t.get("vg", 0):
		return bool(t.v.get("done", 0))
	return task_f(t) >= int(t.m)

func r5() -> int:   # điểm năng động
	var n := 0
	for t in MI():
		if done(t):
			n += pt(t)
	return mini(100, n)

func swap(tid: String) -> void:   # nvSwap
	var n := Pl()
	if n.sw:
		return
	var t = null
	for x in MI():
		if x.id == tid:
			t = x
	if t == null or t.get("vg", 0) or done(t) or is_base(t):
		return
	var nid = _draw(null, ctx(), n.rot)
	if nid == null:
		G.toast.emit("Hôm nay không còn việc khác để đổi.")
		return
	n.rot[n.rot.find(tid)] = nid
	n.sw = 1
	G.mark()

func C8(n: int) -> String:
	G.g.sys.pts = int(G.g.sys.get("pts", 0)) + n
	return ", +" + str(n) + " điểm Hệ Thống"

func xu(x: int) -> int:   # nvXu: xu rương cộng thêm theo chuỗi ngày
	return int(round(x * (1.0 + bonus() / 100.0)))

func coins(n: int) -> void:
	G.g.coins = int(G.g.coins) + n

func x0(n: int) -> void:   # sen đỏ
	G.g.ngoc = maxi(0, int(G.g.ngoc) + n)

func S0(m: String, a: int) -> void:   # vật liệu
	if m == "gach":
		_lang().gach = int(_lang().get("gach", 0)) + a
		return
	if not (G.g.get("mats") is Dictionary):
		G.g.mats = {}
	G.g.mats[m] = mini(999, int(G.g.mats.get(m, 0)) + a)

func bp(days: int) -> void:   # bùa +50% EXP
	var n := maxf(G._now_ms(), float(G.g.get("xpU", 0)))
	G.g.xpU = n + days * 86400000.0

func en_bank() -> void:   # phần cơm hồi sức
	G.g.enBank = int(G.g.get("enBank", 0)) + 1

func _lang() -> Dictionary:   # R0
	if not (G.g.get("lang") is Dictionary):
		G.g.lang = {}
	var L: Dictionary = G.g.lang
	if not (L.get("cg") is Dictionary):
		L.cg = {}
	return L

const OO := ["rom", "phan", "voi", "van", "dinh", "gach", "tre", "la", "may", "bat", "bang", "can"]

func _mat_n(m: String) -> String:
	return String(G.item_name(m)).to_lower()

func _rand_mats() -> Array:
	var L := []
	for m in OO:
		if m != "gach":
			L.append(m)
	return L

const E8 := [{"p": 20, "n": "Rương gỗ", "ic": "crate"}, {"p": 40, "n": "Rương vật liệu", "ic": "crate"},
	{"p": 60, "n": "Rương bạc", "ic": "coin"}, {"p": 80, "n": "Rương kho", "ic": "crate"}, {"p": 100, "n": "Rương sen đỏ", "ic": "pearl"}]

func _e8(p: int) -> String:
	match p:
		20:
			var x := xu(v0(200 + 20 * jr()))
			coins(x)
			return "+" + G.fmt_n(x) + " xu" + C8(3)
		40:
			var ms := _rand_mats()
			var a := []
			for i in 2:
				var m: String = ms[randi() % ms.size()]
				S0(m, 1)
				a.append(_mat_n(m))
			return "+1 " + ", +1 ".join(a) + C8(3)
		60:
			var x := xu(v0(500 + 40 * jr()))
			coins(x)
			en_bank()
			return "+" + G.fmt_n(x) + " xu, 1 phần cơm hồi sức" + C8(4)
		80:
			for m in ["then", "bao", "ton"]:
				S0(m, 1)
			return "+1 then cài, bao bố, tấm tôn" + C8(4)
	x0(2)
	return "+2 sen đỏ" + C8(6)

func oY() -> int:   # rương năng động mở được
	var a := r5()
	var cl: Dictionary = Pl().cl
	var n := 0
	for c in E8:
		if a >= int(c.p) and not cl.has(str(c.p)):
			n += 1
	return n

func IL(p: int) -> void:   # mở rương năng động
	var n := Pl()
	var c = null
	for x in E8:
		if int(x.p) == p:
			c = x
	if c == null or n.cl.has(str(p)) or r5() < p:
		return
	n.cl[str(p)] = 1
	var r := _e8(p)
	G.toast.emit("Mở " + String(c.n).to_lower() + ": " + r + ".")
	G.mark()

# ------------------------------------------------------------------ 2. chuỗi ngày
func SI() -> Dictionary:
	var n := Pl()
	if not (n.get("st") is Dictionary):
		n.st = {}
	var s: Dictionary = n.st
	s.c = int(s.get("c", 0))
	if not s.has("last"):
		s.last = -1
	if not s.has("rw"):
		s.rw = -1
	s.best = maxi(int(s.get("best", 0)), int(s.c))
	if not s.has("rk"):
		s.rk = int(s.c) / 7
	return s

func keep(s: Dictionary, d: int) -> Dictionary:   # nvKeep
	var gap := d - int(s.last)
	if int(s.last) < 0 or gap <= 1:
		return {"c": int(s.c), "rest": false}
	if gap == 2 and int(s.rw) != week(d - 1):
		return {"c": int(s.c), "rest": true}
	return {"c": int(s.c) / 7 * 7, "rest": false}

func streak_now() -> int:
	var s := SI()
	var d := d4()
	return int(s.c) if int(s.last) == d else int(keep(s, d).c)

const NVBON := [[100, 50], [60, 30], [30, 20], [14, 10], [7, 5]]
func bonus(c := -1) -> int:
	if c < 0:
		c = streak_now()
	for b in NVBON:
		if c >= b[0]:
			return b[1]
	return 0

const NVSK := [[30, "Chân lấm tay bùn"], [60, "Một nắng hai sương"], [100, "Tròn một vụ lúa"], [200, "Ruộng sâu trâu nái"], [365, "Lão nông tri điền"]]
func sk_title(b := -1) -> String:
	if b < 0:
		b = int(SI().best)
	var t := ""
	for x in NVSK:
		if b >= x[0]:
			t = x[1]
	return t

const NVROUND := ["Bộ Đồ Tết đỏ", "Dế Hiếm", "Đồ trang trí lễ", "Dế Rất hiếm", "10 sen đỏ, bùa +50% EXP 3 ngày", "Đồ trang trí lễ", "20 sen đỏ", "Dế Huyền thoại"]
static func round_i(k: int) -> int:
	return k - 1 if k <= NVROUND.size() else [5, 3, 6, 7][(k - NVROUND.size() - 1) % 4]

func round_n(k: int) -> String:
	return NVROUND[round_i(k)]

func _round_f(k: int) -> String:
	match round_i(k):
		0:
			var p: Dictionary = G.g.pc
			if p.get("tet", 0):
				x0(5)
				return "5 sen đỏ (đã có Đồ Tết)"
			p.tet = 1
			return "bộ Đồ Tết đỏ"
		1, 3, 7:
			x0(8)   # nvDe: chưa có ống dế ở bản Godot
			return "8 sen đỏ"
		2, 5:
			return deco()
		4:
			x0(10)
			bp(3)
			return "10 sen đỏ, bùa +50% EXP 3 ngày"
	x0(20)
	return "20 sen đỏ"

const DECO := [["noibanhtet", "Nồi bánh tét"], ["hoadang", "Đèn hoa đăng"], ["denongsao", "Đèn ông sao"], ["cohoi", "Cờ hội đình"]]
static func deco_of(k: int) -> Array:
	return DECO[posmod(k, DECO.size())]

func deco(k := -999999) -> String:
	var d := deco_of(int(SI().rk) if k == -999999 else k)
	var L := _lang()
	L.cg[d[0]] = int(L.cg.get(d[0], 0)) + 1
	return String(d[1]).to_lower() + " (Xây dựng › Trang trí)"

func iY() -> void:   # ngày đủ 100 điểm: tính chuỗi
	var s := SI()
	var d := d4()
	if int(s.last) == d or r5() < 100:
		return
	var K := keep(s, d)
	if K.rest:
		s.rw = week(d - 1)
	s.c = int(K.c) + 1
	s.last = d
	s.best = maxi(int(s.best), int(s.c))
	Pl().wk.dd[str(d)] = 1
	var b := xu(v0(500 + 100 * jr()))
	coins(b)
	var msg: String = "Đủ 100 điểm năng động! Chuỗi " + str(s.c) + " ngày, +" + G.fmt_n(b) + " xu"
	if int(s.c) % 7 == 0:
		var k := int(s.c) / 7
		var x := v0(3000 + 1000 * mini(k, 10))
		coins(x)
		if k > int(s.rk):
			s.rk = k
			if k == 1:
				_lang().gach = int(_lang().get("gach", 0)) + 20
			msg = "Chuỗi " + str(s.c) + " ngày! Quà vòng " + str(k) + ": " + _round_f(k) + ", +" + G.fmt_n(x) + " xu"
		else:
			x0(3)
			msg = "Chuỗi " + str(s.c) + " ngày! +" + G.fmt_n(x) + " xu, 3 sen đỏ"
	for t in NVSK:
		if t[0] == int(s.c) and int(s.best) == int(s.c):
			msg += ". Danh hiệu mới: " + t[1]
	G.toast.emit(msg + ".")
	G.mark()

# ------------------------------------------------------------------ 3. tuần
const NVDAYPT := 10
const NVWK := [
	{"id": "deliver", "n": "Giao 25 đơn hàng", "m": 25, "pt": 15, "go": 1},
	{"id": "harvest", "n": "Thu hoạch 150 lần", "m": 150, "pt": 10},
	{"id": "xuong", "n": "Làm 40 món ở xưởng", "m": 40, "pt": 15, "ok": "work"},
	{"id": "collect", "n": "Lượm 40 sản phẩm vật nuôi", "m": 40, "pt": 10, "ok": "pen"},
	{"id": "fish", "n": "Câu được 15 con cá", "m": 15, "pt": 10, "go": 1},
	{"id": "gift", "n": "Tặng quà 5 lần", "m": 5, "pt": 15, "ok": "fam"},
	{"id": "chat", "n": "Trò chuyện 15 lần", "m": 15, "pt": 10, "ok": "fam"},
	{"id": "vg", "n": "Làm 4 việc của làng", "m": 4, "pt": 15, "ok": "fam"},
	{"id": "gop", "n": "Góp cho hợp tác xã 3 lần", "m": 3, "pt": 15, "go": 1, "ok": "hx"},
	{"id": "dz", "n": "Đá dế thắng 3 trận", "m": 3, "pt": 15, "ok": "lv12"},
	{"id": "kl", "n": "Gặt được 1 trái khủng", "m": 1, "pt": 20}]

func _wok(t: Dictionary) -> bool:
	match String(t.get("ok", "")):
		"work": return has_work()
		"pen": return has_pen()
		"fam": return has_fam()
		"hx": return has_hx()
		"lv12": return jr() >= 12
	return true

func wk_list() -> Array:   # nvWkList
	var w: Dictionary = Pl().wk
	if w.rot == null:
		var R := Yu.new(int(w.w) * 13 + 5)
		var L := []
		for t in NVWK:
			if t.id != "deliver" and _wok(t):
				L.append(t)
		var rot := ["deliver"]
		while rot.size() < 7 and L.size() > 0:
			var i := int(floor(R.next() * L.size()))
			rot.append(L[i].id)
			L.remove_at(i)
		w.rot = rot
	var out := []
	for tid in w.rot:
		for t in NVWK:
			if t.id == tid:
				out.append(t)
	return out

func wk_days() -> int:
	return Pl().wk.dd.size()

func WP() -> int:   # điểm tuần
	var n := wk_days() * NVDAYPT
	for t in wk_list():
		if nvW(t.id) >= int(t.m):
			n += int(t.pt)
	return n

const NVWCH := [{"p": 40, "n": "Túi xu", "ic": "coin"}, {"p": 80, "n": "Rương vật liệu", "ic": "crate"},
	{"p": 120, "n": "Rương bạc", "ic": "coin"}, {"p": 160, "n": "Quà tuần", "ic": "pearl"}]

func wk_ready() -> int:
	var a := WP()
	var cl: Dictionary = Pl().wk.cl
	var n := 0
	for c in NVWCH:
		if a >= int(c.p) and not cl.has(str(c.p)):
			n += 1
	return n

func wk_chest(p: int) -> void:
	var w: Dictionary = Pl().wk
	var ok := false
	for c in NVWCH:
		ok = ok or int(c.p) == p
	if not ok or w.cl.has(str(p)) or WP() < p:
		return
	w.cl[str(p)] = 1
	var r := ""
	match p:
		40:
			var x := v0(1500 + 100 * jr())
			coins(x)
			r = "+" + G.fmt_n(x) + " xu"
		80:
			x0(3)
			for m in ["then", "bao", "ton"]:
				S0(m, 1)
			r = "+3 sen đỏ, +1 then cài, bao bố, tấm tôn"
		120:
			var x := v0(4000 + 200 * jr())
			coins(x)
			bp(1)
			r = "+" + G.fmt_n(x) + " xu, bùa +50% EXP 1 ngày"
		_:
			x0(5)
			r = deco(week()) + ", +5 sen đỏ"
	G.toast.emit("Quà tuần mốc " + str(p) + ": " + r + ".")
	G.mark()

# ------------------------------------------------------------------ 4. chuỗi công trình
func _open_n() -> int:
	return G.n_open()

func _star_n(s: int) -> int:   # EI: số ô ruộng sao >= s+1
	var n := 0
	for a in G.g.plots:
		if a.u and G.star(a) - 1 >= s:
			n += 1
	return n

func kho_st() -> int:   # D1
	return clampi(int(G.g.get("khost", 1)) if int(G.g.get("khost", 0)) else 1, 1, 10)

func sap_st() -> int:   # Ul
	return clampi(int(G.g.get("sapst", 1)) if int(G.g.get("sapst", 0)) else 1, 1, 6)

var _w9: Array = []
func w9() -> Array:
	if not _w9.is_empty():
		return _w9
	var L := []
	var st := []
	for v in [8, 12, 16, 20, 26, 32, 38, 44]:
		st.append({"t": "Mở " + str(v) + " ô ruộng", "m": v, "f": "open"})
	for a in [[2, 6], [3, 10], [4, 14], [5, 18]]:
		st.append({"t": "Có " + str(a[1]) + " ô ruộng " + str(a[0]) + "★", "m": a[1], "f": "star", "a": a[0]})
	L.append({"k": "ruong", "n": "Ruộng", "g": ["rom", "phan", "voi"], "steps": st})
	st = []
	for v in [1, 2, 3, 4, 6, 8, 10, 12, 15]:
		st.append({"t": "Xây " + str(v) + " xưởng", "m": v, "f": "zero"})
	for a in [[2, 2], [3, 3], [4, 4], [5, 5]]:
		st.append({"t": str(a[1]) + " xưởng đạt " + str(a[0]) + "★", "m": a[1], "f": "zero"})
	L.append({"k": "xuong", "n": "Xưởng", "g": ["van", "dinh", "gach"], "steps": st})
	st = []
	for v in [1, 3, 6, 10, 15, 20, 26, 32]:
		st.append({"t": "Nuôi " + str(v) + " con vật", "m": v, "f": "zero"})
	for a in [[2, 1], [3, 2], [4, 3], [5, 4]]:
		st.append({"t": str(a[1]) + " chuồng đạt " + str(a[0]) + "★", "m": a[1], "f": "zero"})
	L.append({"k": "chuong", "n": "Chuồng", "g": ["tre", "la", "may"], "steps": st})
	st = []
	for v in [2, 3, 4, 5, 6, 7, 8, 9, 10]:
		st.append({"t": "Nâng kho lên " + str(v) + "★", "m": v, "f": "kho"})
	L.append({"k": "kho", "n": "Kho", "g": ["then", "bao", "ton"], "steps": st})
	st = []
	for a in [["d", 5], ["s", 2], ["d", 20], ["d", 50], ["s", 3], ["d", 100], ["d", 250], ["s", 4], ["d", 500], ["s", 5], ["d", 1000]]:
		if a[0] == "d":
			st.append({"t": "Giao " + G.fmt_n(a[1]) + " đơn hàng", "m": a[1], "f": "deliv"})
		else:
			st.append({"t": "Nâng sạp lên " + str(a[1]) + "★", "m": a[1], "f": "sap"})
	L.append({"k": "sap", "n": "Sạp & đơn", "g": ["bat", "bang", "can"], "steps": st})
	_w9 = L
	return L

func step_f(s: Dictionary) -> int:
	match String(s.f):
		"open": return _open_n()
		"star": return _star_n(int(s.a))
		"kho": return kho_st()
		"deliv": return int(G.g.delivered)
		"sap": return sap_st() - 1
	return 0

func M9(L: Dictionary) -> int:
	return int(Pl().ln.get(L.k, 0))

func AI(i: int) -> Dictionary:
	return {"xu": v0(120 + 60 * i * i), "m": 1 + i / 2}

func PI() -> int:
	var n := 0
	for L in w9():
		var i := M9(L)
		if i < L.steps.size() and step_f(L.steps[i]) >= int(L.steps[i].m):
			n += 1
	return n

func zI(k: String) -> void:   # nhận quà một việc công trình
	for L in w9():
		if L.k != k:
			continue
		var i := M9(L)
		if i >= L.steps.size():
			return
		var s: Dictionary = L.steps[i]
		if step_f(s) < int(s.m):
			return
		var R := AI(i)
		Pl().ln[k] = i + 1
		coins(R.xu)
		for j in int(R.m):
			S0(L.g[j % 3], 1)
		G.toast.emit("Xong \"" + String(s.t) + "\": +" + G.fmt_n(R.xu) + " xu, +" + str(R.m) + " vật liệu " + String(L.n).to_lower() + ".")
		G.mark()

# ------------------------------------------------------------------ 5. thành tựu
const CY := [10, 50, 200, 1000, 5000]
const T9 := ["Tập sự", "Chăm chỉ", "Lành nghề", "Cao tay", "Huyền thoại"]
const L8 := [
	{"k": "harvest", "n": "Nhà nông", "d": "lần thu hoạch", "m": 1.0},
	{"k": "deliver", "n": "Bạn hàng", "d": "đơn hàng đã giao", "m": 0.2},
	{"k": "collect", "n": "Người chăn nuôi", "d": "sản phẩm vật nuôi", "m": 1.0},
	{"k": "xuong", "n": "Thợ cả", "d": "món làm ở xưởng", "m": 1.0},
	{"k": "fish", "n": "Tay câu", "d": "con cá câu được", "m": 0.2},
	{"k": "giup", "n": "Hàng xóm tốt", "d": "lần giúp bà con", "m": 0.2}]

func ach_f(A: Dictionary) -> int:
	var st: Dictionary = G.g.sys.get("stats", {})
	match String(A.k):
		"harvest": return int(st.get("harvest", 0))
		"deliver": return int(G.g.delivered)
		"collect": return int(st.get("collect", 0))
	return 0

static func S9(A: Dictionary, t: int) -> int:
	return maxi(1, int(round(CY[t] * float(A.m))))

func A8(A: Dictionary) -> int:
	return int(Pl().ach.get(A.k, 0))

func ach_rw(t: int) -> Dictionary:
	return {"ng": [1, 1, 2, 3, 5][t], "xu": v0(200 * (t + 1) * (t + 1))}

func qI() -> int:
	var n := 0
	for A in L8:
		var t := A8(A)
		if t < 5 and ach_f(A) >= S9(A, t):
			n += 1
	return n

func BI(k: String) -> void:
	for A in L8:
		if A.k != k:
			continue
		var t := A8(A)
		if t >= 5 or ach_f(A) < S9(A, t):
			return
		Pl().ach[k] = t + 1
		var R := ach_rw(t)
		x0(R.ng)
		coins(R.xu)
		G.toast.emit("Thành tựu \"" + String(A.n) + " " + String(T9[t]).to_lower() + "\": +" + str(R.ng) + " sen đỏ, +" + G.fmt_n(R.xu) + " xu.")
		G.mark()

# ------------------------------------------------------------------ 6. lịch sự kiện 14 ngày
const FY := [
	{"id": "hoi", "d0": 0, "d1": 5, "n": "Hội làng 5 chặng", "ic": "🎪", "d": "Mỗi ngày một đề, làm đúng đề để lấy điểm. Đủ mốc trong ngày có quà, cộng dồn 5 ngày có quà lớn và bảng vàng."},
	{"id": "cho", "d0": 5, "d1": 8, "n": "Phiên chợ đổi quà", "ic": "🏮", "d": "Làm việc nhận vé chợ, đổi lấy vật liệu, sen đỏ, bùa. Hết phiên vé cũ hết hạn."},
	{"id": "ngoc", "d0": 8, "d1": 10, "odd": 1, "n": "Tiêu sen đỏ có lộc", "ic": "💎", "d": "Hai ngày hiếm hoi: tiêu sen đỏ vào bất cứ việc gì, đủ mốc được quà lớn."},
	{"id": "giup", "d0": 8, "d1": 10, "odd": 0, "n": "Ngày hội giúp nhau", "ic": "🤝", "d": "Giúp bà con trong xã được tiền nước gấp đôi, điểm năng động việc giúp gấp đôi."},
	{"id": "bt", "d0": 10, "d1": 14, "n": "Tuần lễ bội thu", "ic": "🌾", "d": "Thu hoạch ruộng, hái trái có 15% cơ hội ra dư 1. Đơn hàng trả thêm 10% xu."}]
const FL := [{"k": "harvest", "n": "Ngày gặt", "d": "mỗi lần thu hoạch 1 điểm", "mul": 1}, {"k": "xuong", "n": "Ngày làm hàng", "d": "mỗi món xưởng làm xong 1 điểm", "mul": 1},
	{"k": "collect", "n": "Ngày chăn nuôi", "d": "mỗi sản phẩm vật nuôi 1 điểm", "mul": 1}, {"k": "deliver", "n": "Ngày giao đơn", "d": "mỗi đơn giao xong 5 điểm", "mul": 5},
	{"k": "fish", "n": "Ngày câu cá", "d": "mỗi con cá 4 điểm", "mul": 4}]
const GL := [20, 50, 90]
const WL := [150, 350, 600]

func wp() -> Dictionary:
	var d := d4()
	return {"c": int(floor(d / 14.0)), "d": posmod(d, 14)}

static func jL(c: int) -> Array:
	var out := []
	for e in FY:
		if not e.has("odd") or int(e.odd) == posmod(c, 2):
			out.append(e)
	return out

func ff() -> Dictionary:
	var x := wp()
	for e in jL(x.c):
		if x.d >= int(e.d0) and x.d < int(e.d1):
			return e
	return {"id": ""}

func RI() -> String:
	var e := ff()
	return str(wp().c) + ":" + String(e.id) if e.id != "" else ""

func ev():   # id(): trạng thái sự kiện đang chạy
	var n := Pl()
	var k := RI()
	if k == "":
		return null
	if String(n.get("evk", "")) != k:
		n.evk = k
		n.ev = {"p": 0, "day": {}, "cl": {}, "ve": 0, "sp": 0, "buy": {}}
		G.toast.emit("Sự kiện mới: " + String(ff().n) + "! Xem ở Sổ nhiệm vụ › Sự kiện.")
	return n.ev

func OI(k: String, n := 1) -> void:
	var e := ff()
	var s = ev()
	if s == null:
		return
	if e.id == "hoi":
		var d := int(wp().d)
		var st: Dictionary = FL[d]
		if k == st.k:   # "xuong": món xưởng (bản Godot chưa có xưởng)
			var p := int(st.mul) * n
			s.p = int(s.p) + p
			s.day[str(d)] = int(s.day.get(str(d), 0)) + p
	elif e.id == "cho" and k == "deliver":
		s.ve = int(s.ve) + 2

func DL() -> int:   # phiên chợ: vé từ năng động
	var s = ev()
	if s == null or ff().id != "cho":
		return 0
	var d := str(Ao())
	if not (s.get("apd") is Dictionary):
		s.apd = {}
	var got := int(s.apd.get(d, 0))
	var add := r5() / 10 - got
	if add > 0:
		s.apd[d] = got + add
		s.ve = int(s.ve) + add
	return int(s.ve)

const HI := [
	{"id": "mk", "n": "Vật liệu kho", "d": "1 then cài, 1 bao bố, 1 tấm tôn", "c": 6, "ic": "crate"},
	{"id": "mr", "n": "Gói vật liệu", "d": "3 vật liệu ngẫu nhiên", "c": 5, "ic": "crate"},
	{"id": "ng", "n": "2 sen đỏ", "d": "đổi tối đa 3 lần mỗi phiên", "c": 8, "max": 3, "ic": "pearl"},
	{"id": "xp", "n": "Bùa +50% EXP 1 ngày", "d": "+50% kinh nghiệm, cất trong kho", "c": 10, "max": 2, "ic": "bua"},
	{"id": "en", "n": "Phần cơm hồi sức", "d": "để dành, hồi đầy thể lực", "c": 4, "max": 5, "ic": "che"},
	{"id": "xu", "n": "Túi xu", "d": "xu theo cấp", "c": 3, "ic": "coin"}]

func sY(tid: String) -> void:   # đổi vé chợ
	var s = ev()
	var it = null
	for x in HI:
		if x.id == tid:
			it = x
	if s == null or it == null:
		return
	DL()
	if it.has("max") and int(s.buy.get(tid, 0)) >= int(it.max):
		G.toast.emit("Phiên này đổi đủ rồi.")
		return
	if int(s.ve) < int(it.c):
		G.toast.emit("Cần " + str(it.c) + " vé chợ.")
		return
	s.ve = int(s.ve) - int(it.c)
	s.buy[tid] = int(s.buy.get(tid, 0)) + 1
	match tid:
		"mk":
			for m in ["then", "bao", "ton"]:
				S0(m, 1)
		"mr":
			var ms := _rand_mats()
			for i in 3:
				S0(ms[randi() % ms.size()], 1)
		"ng": x0(2)
		"xp": bp(1)
		"en": en_bank()
		"xu": coins(v0(300 + 30 * jr()))
	G.toast.emit("Đổi được " + String(it.n).to_lower() + ".")
	G.mark()

const VL := [{"p": 20, "n": "+1.000 xu"}, {"p": 60, "n": "5 vật liệu kho"}, {"p": 150, "n": "Bùa +50% EXP 3 ngày + 3.000 xu"}, {"p": 300, "n": "20 sen đỏ hoàn lại + 10 vật liệu"}]

func spent(n: int) -> void:   # x0(-n) lúc sự kiện "ngoc"
	if n > 0 and ff().id == "ngoc":
		var s = ev()
		if s != null:
			s.sp = int(s.sp) + n

func FI(kind: String, i: int) -> void:   # quà hội làng: d = trong ngày, t = cộng dồn
	var s = ev()
	if s == null:
		return
	var x := wp()
	var key: String = kind + ":" + (str(x.d) + ":" if kind == "d" else "") + str(i)
	if s.cl.has(key):
		return
	var ok: bool = int(s.day.get(str(x.d), 0)) >= GL[i] if kind == "d" else int(s.p) >= WL[i]
	if not ok:
		return
	s.cl[key] = 1
	var msg := ""
	if kind == "d":
		if i == 0:
			var a := v0(300)
			coins(a)
			msg = "+" + G.fmt_n(a) + " xu"
		elif i == 1:
			var ms := _rand_mats()
			S0(ms[randi() % ms.size()], 2)
			msg = "+2 vật liệu"
		else:
			x0(1)
			msg = "+1 sen đỏ"
	else:
		if i == 0:
			var b := v0(1500)
			coins(b)
			msg = "+" + G.fmt_n(b) + " xu"
		elif i == 1:
			x0(3)
			for m in ["then", "bao", "ton"]:
				S0(m, 2)
			msg = "+3 sen đỏ, 6 vật liệu kho"
		else:
			x0(8)
			bp(2)
			msg = "+8 sen đỏ, bùa +50% EXP 2 ngày"
	G.toast.emit("Hội làng: " + msg + ".")
	G.mark()

func hY(i: int) -> void:   # quà tiêu sen đỏ
	var s = ev()
	if s == null or ff().id != "ngoc":
		return
	var M: Dictionary = VL[i]
	if s.cl.has("n" + str(i)) or int(s.sp) < int(M.p):
		return
	s.cl["n" + str(i)] = 1
	match i:
		0: coins(1000)
		1:
			for m in ["then", "bao", "ton", "then", "bao"]:
				S0(m, 1)
		2:
			bp(3)
			coins(3000)
		3:
			x0(20)
			var ms := _rand_mats()
			for j in 10:
				S0(ms[j % ms.size()], 1)
	G.toast.emit("Tiêu sen đỏ có lộc: nhận " + String(M.n) + ".")
	G.mark()

func QL() -> int:
	var e := ff()
	var s = ev()
	if s == null:
		return 0
	var n := 0
	var x := wp()
	if e.id == "hoi":
		for i in GL.size():
			if int(s.day.get(str(x.d), 0)) >= GL[i] and not s.cl.has("d:" + str(x.d) + ":" + str(i)):
				n += 1
		for i in WL.size():
			if int(s.p) >= WL[i] and not s.cl.has("t:" + str(i)):
				n += 1
	if e.id == "ngoc":
		for i in VL.size():
			if int(s.sp) >= int(VL[i].p) and not s.cl.has("n" + str(i)):
				n += 1
	return n

func vY(d_end: int) -> String:   # thời gian còn của sự kiện
	var x := wp()
	var now := _nowd()
	var end: float = floor(now) - int(x.d) + d_end
	return ao(maxf(0.0, (end - now) * 86400.0))

func ready_n() -> Dictionary:   # nvReady: số quà nhận được mỗi tab (chấm đỏ nút Nhiệm vụ)
	return {"ngay": oY() + (1 if vg_ready() else 0), "tuan": wk_ready(), "tt": PI() + qI(), "sk": QL()}

# bội thu: thu hoạch ruộng 15% ra dư 1; đơn hàng trả thêm 10% xu
func bt_harvest(c: String) -> bool:
	if ff().id == "bt" and randf() < 0.15:
		G.g.barn[c] = int(G.g.barn.get(c, 0)) + 1
		return true
	return false

func bt_deliver(got: int) -> void:
	if got > 0 and ff().id == "bt":
		coins(int(round(got * 0.1)))

# mỗi giây (ui step của bản web): Pl, iY, id, DL
var _t := 0.0
func step(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 1.0
	Pl()
	iY()
	ev()
	if ff().id == "cho":
		DL()
