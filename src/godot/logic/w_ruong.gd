extends RefCounted
# Ruộng, cây ăn trái, mưa, nước mặn, thời tiết, đất: chép 1:1 luật bản web.
#   mưa rào g.rain (đuôi vw + uG), cây ăn trái g.objs[].fp/fw (fq, Ql, zb, qM, X5, pu, Oj, Ib, Hb, Hj, Ax),
#   hạn mặn g.man (B4, V6, $R, YR, JR, TZ, tO, aO, SZ, N4, LC, AC, MZ, O0, u7, EZ, LZ),
#   ốc gạo mùa nước nổi g.plots[].oc (GY, qs), gà vịt bới ruộng (Y0: Hq, BD, _M, dx, ax),
#   giống lai g.lai (z4, W6, MC, laiH, laiAdd, xZ, yZ, sdN, sdUse, qf), tổ ong g.lang.hive (TD, Lq, Sq, Eq, MD),
#   chỗ bến dọn cây g.clr (BENCLR), cài đặt chung g.dm / g.sea (oJ), nâng sao cũ g.sapst / g.sv (qH),
#   trái rụng / chỗ rừng trong g.wx (FT, RK: chạm trúng).
# Vẽ (Lw, Ij, Aq, ZB, NK), hạt bay, âm thanh: không chép.

var G
var ui = null              # w_ruong_ui.gd (người ghép gán): CZ / U6

const K6 := 200            # xu mua 10 nước ngọt
const Q6 := 4000           # xu xây cống ngăn mặn
const ZM := 210.0          # giây ra 1 phần mật ong
const WD := {"hibiscus": 1, "bougainvillea": 1, "mai": 1, "dao": 1, "lotus": 1, "gianbau": 1, "gianbau2": 1}   # wD
const DM := ["real", "fast", "day", "night"]

var ol := {}               # giống lai
var Wc := []               # mã giống lai
var cq := []               # cây ăn trái đúng mùa
var V4 := {}               # cấp mở chức năng
var W5 := {}               # các khúc sông Vàm
var CTB := {}              # bậc công trình chung
var CX := {}               # cx: sức chứa nhà (nhà dân)
var _ei_cache = null

var E5 := 0.0              # ms (Time.get_ticks_msec): sau mưa rào 3,2 giây chưa cho gà vịt / chim tới (yG)
var zC := 0.0              # SZ mỗi 2 giây
var iA := 8.0              # GY
var KE := 0.0              # oJ mỗi 1 giây
var Y0 := {}               # gà / vịt vô bới ruộng: {t, a, plot, st, tt}
var Cl := {"v": "", "s": null, "tree": {}, "drain": {}, "fence": {}, "hive": {}, "work": {}, "hives": [], "khos": []}
var _hr := []
var _hr_sig := ""
var s7 := []               # khoảng cách tới kênh / sông
var PC := []               # khoảng cách tới nước của mình
var XR := ""
var j6 = null              # yZ
var _qh_msg := ""          # qH: setTimeout 2,2 giây
var _qh_t := 0.0

func _init(game) -> void:
	G = game
	ol = _jd("nong_trai/giong_lai")
	Wc = _ja("nong_trai/ds_giong_lai")
	cq = _ja("nong_trai/cay_an_trai_dung_mua")
	V4 = _jd("nhan_vat/chuc_nang_mo_cap")
	W5 = _jd("dat_dai/khu_song")
	CTB = _jd("cong_trinh_chung/bac")
	CX = _jd("xay_dung/suc_chua_nha")
	Y0 = {"t": _nn(70.0, 120.0), "a": null, "plot": -1, "st": 0, "tt": 0.0}

# ------------------------------------------------------------------ tiện ích chung
func _jd(p: String) -> Dictionary:   # G._j (Dictionary)
	var v = G._j(p)
	return v if v is Dictionary else {}

func _ja(p: String) -> Array:   # G._j (Array)
	var v = G._j(p)
	return v if v is Array else []

static func _nn(a: float, b: float) -> float:   # Nn
	return a + randf() * (b - a)

static func _t0(a: Array):   # t0
	return a[randi() % a.size()]

static func _ob(t: float, a: float, n: float, e: float) -> float:   # Ob
	return Vector2(t - n, a - e).length()

static func _num(v) -> bool:   # typeof x == "number"
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT

static func _date_now() -> float:   # Date.now()
	return Time.get_unix_time_from_system() * 1000.0

static func _perf() -> float:   # performance.now()
	return float(Time.get_ticks_msec())

static func _sv(v) -> String:   # String(v) như JS (số nguyên không có ".0")
	if typeof(v) == TYPE_FLOAT and v == floor(v):
		return str(int(v))
	return str(v)

func _ei() -> Dictionary:   # Ei
	if _ei_cache == null:
		_ei_cache = G.lang.C.Ei if G.lang != null else G._j("nong_trai/cay_an_trai")
	return _ei_cache

func _pi(t: int) -> Dictionary:   # pi
	return G.cells[t]

func _objs() -> Array:   # g.objs
	return G.g.objs if G.g.get("objs") is Array else []

func _a0(x: float, y: float, s: String) -> void:   # a0
	G.float_text.emit(x, y, s)

func _ta(s: String) -> void:   # ta / pn
	G.toast.emit(s)

func _mode() -> String:   # Mt.mode
	if G.lang != null and G.lang.F != null and G.lang.F.ui != null and G.lang.F.ui.get("bdp") != null:
		return String(G.lang.F.ui.bdp.mode)
	return "off"

func _vr() -> int:   # vr
	return G.day()

func _r0() -> Dictionary:   # R0: g.lang đủ khóa (nv._lang chỉ lo cg)
	var t: Dictionary = G.nv._lang()
	if not (_num(t.get("seq")) and float(t.seq) > 0.0):
		t.seq = 1
	if not (t.get("fam") is Dictionary):
		t.fam = {}
	if not (_num(t.get("gach")) and float(t.gach) >= 0.0):
		t.gach = 0
	if not (t.get("cg") is Dictionary):
		t.cg = {}
	if not (t.get("hive") is Dictionary):
		t.hive = {}
	return t

func _hrl() -> Array:   # Hr: món đặt có hình (gx, gy, fw, fd, idx, id)
	var O := _objs()
	var sig := (str(G.lang.ver) if G.lang != null else "") + ":" + str(O.size())
	if sig == _hr_sig:
		return _hr
	_hr_sig = sig
	_hr = []
	for n in O.size():
		var o = O[n]
		if not (o is Dictionary) or G.lang == null:
			continue
		var t = G.lang.Pi.get(o.get("id", ""))
		if t == null:
			continue
		_hr.append({"gx": int(o.gx), "gy": int(o.gy), "fw": int(t.fw), "fd": int(t.fd), "idx": n, "id": String(o.id)})
	return _hr

# ------------------------------------------------------------------ mỗi lượt luật (vw) và mỗi khung hình
func step(t: float, offline: bool) -> void:   # vw (đuôi: fq, Rq->TD, g.rain)
	# đuôi vw(t, a): fq(t); Rq -> TD(t) khi có g.lang; mưa rào g.rain
	fq(t)
	if G.g.get("lang") is Dictionary:
		td(t)
	if not _num(G.g.get("rain")):
		G.g.rain = 150.0
	G.g.rain = float(G.g.rain) - t
	if float(G.g.rain) <= 0.0:
		if not offline and not rain_shower():
			G.g.rain = 40.0
		else:
			G.g.rain = 150.0 + randf() * 150.0

func frame(dt: float) -> void:   # ui({step}) mỗi khung: man SZ, cau GY, QD Hq, sao qH, dongbo oJ
	# các bước ui({step}) của web chạy mỗi khung hình: man (SZ), cau (GY), làng (Hq), sao (qH), dongbo (oJ)
	if G.lang == null or G.g == null:
		return
	sz(dt)
	gy(dt)
	hq(dt)
	qh()
	KE -= dt
	if not (KE > 0.0):
		KE = 1.0
		oj()
	if _qh_t > 0.0:
		_qh_t -= dt
		if _qh_t <= 0.0 and _qh_msg != "":
			_ta(_qh_msg)
			_qh_msg = ""

# ------------------------------------------------------------------ mưa rào
func qb() -> bool:   # QB: đang nắng hạn
	return G.troi != null and G.troi.wx() == "han"

func yg() -> void:   # yG
	E5 = _perf() + 3200.0

func rain_shower() -> bool:   # uG
	if qb():
		return false
	var t := false
	for a in G.g.plots:
		if a.c != null and not G.ripe(a):
			a.w = G.water_hold(a)
			t = true
	if zb(true) > 0:
		t = true
	if t:
		yg()
		_ta("Mưa rào. Cả vườn được tưới.")
		return true
	return false

func sw() -> int:   # sW: số ô có sâu
	var t := 0
	for a in G.B0:
		if G.g.plots[a] and G.g.plots[a].get("b", 0):
			t += 1
	return t

func gg() -> Array:   # gg: ô đã mở trên đất đã có
	var t := []
	for a in G.B0:
		if G.g.plots[a].u and G.owned(a):
			t.append(a)
	return t

# ------------------------------------------------------------------ món đặt (g.objs)
func m0() -> void:   # m0
	if G.lang != null:
		G.lang._a1()

func cz(t: String) -> int:   # Cz
	var a := 0
	for o in _objs():
		if o.id == t:
			a += 1
	return a

func km() -> int:   # KM: số thùng ong
	var t := 0
	for o in _objs():
		if o.id == "thungong":
			t += 1
	return t

func n_() -> Array:   # n_: đèn bẫy
	m0()
	var t := []
	for n in _objs():
		if n and n.id == "denbay":
			t.append(n)
	return t

func u7() -> int:   # u7: sức chứa lu nước ngọt
	var t := 0
	for a in _objs():
		if a.id == "lunuoc":
			t += 1
	return 10 + 10 * mini(t, 8)

func kd() -> bool:   # KD: có nhà dân hoặc thùng ong
	for o in _objs():
		if CX.has(o.id) or o.id == "thungong":
			return true
	return false

func uq() -> bool:   # Uq: có cây ăn trái
	for o in _objs():
		if o is Dictionary and _ei().has(o.get("id", "")):
			return true
	return false

func nv_has_tree() -> bool:   # nvHasTree
	for r in _objs():
		if r and _ei().has(r.get("id", "")):
			return true
	return false

func tn_has(id: String) -> bool:   # tnHas
	var re := RegEx.create_from_string("^" + id + ("[2-4]?$" if id == "ben" else "2?$"))
	for r in _objs():
		if r and re.search(String(r.id)) != null:
			return true
	return false

func tn_waters() -> Array:   # tnWaters
	var re := RegEx.create_from_string("^(well|lunuoc|pond)2?$")
	var o := []
	for r in _objs():
		if r and re.search(String(r.id)) != null:
			o.append(r)
	return o

func ct_base(id: String) -> String:   # ctBase
	if CTB.has(id):
		return id
	var b := id.trim_suffix("2")
	return b if b != id and CTB.has(b) else ""

func ct_built() -> Dictionary:   # ctBuilt
	var o := {1: 0, 2: 0, 3: 0, "dinh": false}
	for r in _objs():
		var b := ct_base(String(r.id)) if r else ""
		if b != "":
			o[int(CTB[b])] += 1
			if b == "dinh":
				o.dinh = true
	return o

static func fx(t: String) -> bool:   # fx: hàng rào
	return t.begins_with("raotre") or t.begins_with("raogoc") or t.begins_with("congngo")

func hb() -> void:   # Hb: cây gần thùng ong (Cl.tree), chỗ thùng ong, kho
	m0()
	var sig := (str(G.lang.ver) if G.lang != null else "") + ":" + str(_objs().size())
	if Cl.v == sig and is_same(Cl.s, G.g):
		return
	Cl.v = sig
	Cl.s = G.g
	Cl.tree = {}
	Cl.drain = {}
	Cl.fence = {}
	Cl.hive = {}
	Cl.work = {}
	var t := []
	var a := []
	var H := _hrl()
	var O := _objs()
	for e in H:
		var r = O[e.idx]
		if r:
			if r.id == "thungong":
				t.append([e.gx + 0.5, e.gy + 0.5])
			if r.id == "kho" or r.id == "kho2":
				a.append([e.gx + e.fw / 2.0, e.gy + e.fd / 2.0])
	Cl.hives = t
	Cl.khos = a
	for e in H:
		var r = O[e.idx]
		if not r or not _ei().has(r.id):
			continue
		var o: float = e.gx + e.fw / 2.0
		var l: float = e.gy + e.fd / 2.0
		for c in t.size():
			if _ob(o, l, t[c][0], t[c][1]) <= 3.6:
				Cl.tree[e.idx] = 1
				break

func fence(t: int) -> bool:   # _M: có rào trong 2 ô quanh ruộng
	hb()
	if Cl.fence.has(t):
		return Cl.fence[t]
	var n := _pi(t)
	var c := 0
	var O := _objs()
	for e in range(int(n.gx) - 2, int(n.gx) + 3):
		for r in range(int(n.gy) - 2, int(n.gy) + 3):
			var o = G.lang.a1.get(str(e) + "," + str(r))
			if o:
				for l in o:
					if l < O.size() and O[l] and fx(String(O[l].id)):
						c += 1
	Cl.fence[t] = c > 0
	return Cl.fence[t]

# ------------------------------------------------------------------ cây ăn trái
func ql(t: int) -> Variant:   # Ql
	var O := _objs()
	if t < 0 or t >= O.size():
		return null
	var a = O[t]
	if not (a is Dictionary) or not _ei().has(a.get("id", "")):
		return null
	if not _num(a.get("fp")):
		a.fp = 0.0
	if not _num(a.get("fw")):
		a.fw = 0.0
	return a

static func f2() -> float:   # f2: giây đất quanh cây giữ nước
	return 1800.0

func wc(t: Dictionary) -> bool:   # wc: đã có trái
	return float(t.fp) >= float(_ei()[t.id].time)

func oj_tree(t: String) -> bool:   # Oj: cây đúng mùa
	var s: int = G.season()
	return s >= 0 and s < cq.size() and cq[s].has(t)

func um() -> float:   # um
	return 1.04 if qs() and o0() > 0 else 1.0

func pu(t: String, a: bool) -> float:   # pu: tốc độ ra trái (a = đang được tưới)
	var n: float = G.boost() + (0.1 if oj_tree(t) else 0.0) + (0.04 if um() > 1.0 else 0.0) + (0.1 if a else 0.0)
	return minf(G.M5, n)

func fq(t: float) -> void:   # fq: cây ra trái theo giờ
	var O := _objs()
	for a in O.size():
		var n = O[a]
		var e = _ei().get(n.get("id", "")) if n is Dictionary else null
		if e == null:
			continue
		if not _num(n.get("fp")):
			n.fp = 0.0
		if not _num(n.get("fw")):
			n.fw = 0.0
		if float(n.fp) >= float(e.time):
			continue
		var r: float = minf(t, float(n.fw)) if float(n.fw) > 0.0 else 0.0
		n.fw = maxf(0.0, float(n.fw) - r)
		n.fp = minf(float(e.time), float(n.fp) + r * pu(String(n.id), true) + (t - r) * pu(String(n.id), false))

func zb(t: bool) -> int:   # zb: t = mưa tưới hết cây; không thì tưới cây còn khô (qM)
	var a := 0
	for n in _objs().size():
		var e = ql(n)
		if e == null or wc(e):
			continue
		if t:
			e.fw = f2()
			a += 1
		elif qm(n):
			a += 1
	return a

func qm(t: int) -> bool:   # qM: tưới cây
	var a = ql(t)
	if a == null or wc(a) or float(a.fw) >= f2() * 0.85:
		return false
	a.fw = f2()
	return true

func ib(t: int) -> int:   # Ib: cây gần thùng ong được thêm 1 trái
	hb()
	return 1 if Cl.tree.has(t) else 0

func _hr_of(t: int) -> Variant:   # Hr[t]
	for e in _hrl():
		if e.idx == t:
			return e
	return null

func x5(t: int) -> bool:   # X5 (+ lớp bọc g8: kho phải đủ chỗ)
	var c = ql(t)
	if c != null and wc(c) and not G.kho_fit(int(_ei()[c.id].yield)):
		return false
	var a = ql(t)
	if a == null or not wc(a):
		return false
	var n: Dictionary = _ei()[a.id]
	var e: int = int(n.yield) + ib(t)
	var p: String = String(n.p)
	G.g.barn[p] = int(G.g.barn.get(p, 0)) + e
	a.fp = 0.0
	var r = _hr_of(t)
	if r != null:
		_a0(r.gx + r.fw / 2.0, r.gy + r.fd / 2.0, "+" + str(e) + " " + String(G.item_name(p)) + (" (có ong)" if e > int(n.yield) else ""))
	G.vib(10)
	G.nv.qi("harvest")
	return true

func hj() -> int:   # Hj: thu hết cây đã có trái
	var t := 0
	for a in _objs().size():
		var o = _objs()[a]
		if o is Dictionary and _ei().has(o.get("id", "")) and x5(a):
			t += 1
	return t

func ax_pos(t: int) -> Variant:   # Ax: chỗ đứng hái / tưới cây
	m0()
	for n in _hrl():
		if n.idx == t:
			return [n.gx + n.fw / 2.0, n.gy + n.fd + 0.2]
	return null

func tree_run(t: int, a: String) -> bool:   # Px run(): việc "twater" / "tharvest" khi nhân vật tới nơi
	var r: bool = qm(t) if a == "twater" else x5(t)
	if r:
		G.mark()
	return r

func ro(s: float) -> int:   # Ro
	return maxi(1, int(ceil(s / 600.0)))

func tree_left(t: int) -> float:   # (a.time - t.fp) / pu(t.id, false) trong Rj
	var a = ql(t)
	if a == null:
		return 0.0
	return (float(_ei()[a.id].time) - float(a.fp)) / pu(String(a.id), false)

func tree_now(t: int) -> bool:   # Rj nút "ngtree": ra trái ngay bằng sen đỏ
	var n = ql(t)
	if n == null or wc(n):
		return false
	var e: Dictionary = _ei()[n.id]
	var r := ro(tree_left(t))
	if G.spend_ngoc(r):
		n.fp = float(e.time)
		_ta("Cây " + String(G.lang.Pi[n.id].n).to_lower() + " ra trái ngay, tốn " + str(r) + " sen đỏ.")
		G.mark()
		return true
	return false

# ------------------------------------------------------------------ tổ ong (g.lang.hive)
func sq(t: Dictionary) -> int:   # Sq
	if not (_num(t.get("u")) and float(t.u) > 0.0):
		var a := _r0()
		t.u = int(a.seq)
		a.seq = int(a.seq) + 1
	return int(t.u)

func lq(t: Dictionary) -> Variant:   # Lq
	var O := _objs()
	if t.idx >= O.size() or not O[t.idx]:
		return null
	var a: Dictionary = O[t.idx]
	var n := _r0()
	var e := str(sq(a))
	var r = n.hive.get(e)
	if not (r is Dictionary):
		r = {"h": 0, "t": 0.0}
		n.hive[e] = r
	if not _num(r.get("h")):
		r.h = 0
	if not _num(r.get("t")):
		r.t = 0.0
	return r

func md(t: Dictionary) -> float:   # MD: cây, hoa quanh thùng ong
	var a: float = t.gx + 0.5
	var n: float = t.gy + 0.5
	var e := 0.0
	var O := _objs()
	for o in _hrl():
		var l = O[o.idx] if o.idx < O.size() else null
		if not l or o.idx == t.idx:
			continue
		if not _ei().has(l.id) and not WD.has(l.id):
			continue
		if _ob(a, n, o.gx + o.fw / 2.0, o.gy + o.fd / 2.0) <= 3.6:
			e += 1.0
	if G.g.get("minis") is Dictionary:
		for c in G.g.minis:
			var f: PackedStringArray = String(c).split(",")
			if _ob(a, n, (f[0].to_float() + 0.5) / 2.0, (f[1].to_float() + 0.5) / 2.0) <= 3.2:
				e += 0.25
	return e

func eq(t: Dictionary) -> float:   # Eq: tốc độ ra mật
	hb()
	var a := str(t.gx) + "," + str(t.gy) + "|" + str(G.g.minis.size() if G.g.get("minis") is Dictionary else 0)
	if not Cl.hive.has(a):
		var e := md(t)
		Cl.hive[a] = minf(2.0, 0.45 + 0.22 * e) if e > 0.0 else 0.2
	return Cl.hive[a]

func td(t: float) -> void:   # TD: mật ong đầy dần, tối đa 3 phần
	m0()
	var r := {}
	var O := _objs()
	for n in _hrl():
		if n.id != "thungong":
			continue
		var e = lq(n)
		if e == null:
			continue
		r[str(int(O[n.idx].u))] = 1
		if int(e.h) >= 3:
			e.t = 0.0
			continue
		e.t = float(e.t) + t * eq(n)
		while float(e.t) >= ZM and int(e.h) < 3:
			e.t = float(e.t) - ZM
			e.h = int(e.h) + 1
	var o := _r0()
	for l in o.hive.keys():
		if not r.has(String(l)):
			o.hive.erase(l)

# ------------------------------------------------------------------ gà / vịt vô bới ruộng (Y0)
func bd() -> int:   # BD: ô có cây đang lớn, không rào
	var t := []
	for a in G.B0:
		var n: Dictionary = G.g.plots[a]
		if not n.u or n.c == null or n.get("b", 0) or not G.owned(a) or G.stage(n) < 1:
			continue
		if not fence(a):
			t.append(a)
	return _t0(t) if t.size() else -1

static func ax(t: String, a: float, n: float) -> Dictionary:   # ax (không có item.f: vẽ để phần vẽ lo)
	return {"sp": t, "x": a, "y": n, "tx": a, "ty": n, "z": 0.0, "wait": _nn(0.3, 3.0), "face": 1 if randf() < 0.5 else -1,
		"ph": _nn(0.0, 6.28), "mv": false, "fly": 0, "al": 0.0, "act": 0, "actT": _nn(2.0, 8.0), "seed": randf(), "item": null}

func dx(t: String) -> void:   # dx: gà / vịt bỏ đi
	var a = Y0.a
	if a == null or int(Y0.st) == 2:
		return
	Y0.st = 2
	var n := randf() * 6.283
	a.tx = a.x + cos(n) * 8.0
	a.ty = a.y + sin(n) * 8.0
	a.act = 0
	if t != "":
		_a0(a.x, a.y, t)

func hq(t: float) -> void:   # Hq
	var a = Y0.a
	if a == null:
		if G.night or _mode() != "off" or G.motion_off() or _perf() < E5:
			return
		Y0.t = float(Y0.t) - t
		if float(Y0.t) > 0.0:
			return
		Y0.t = _nn(90.0, 170.0)
		var n := bd()
		if n < 0:
			return
		var e := _pi(n)
		var r := randf() * 6.283
		var o := "ganha" if randf() < 0.55 else "vit"
		a = ax(o, e.gx + 0.5 + cos(r) * 6.0, e.gy + 0.5 + sin(r) * 6.0)
		a.tx = e.gx + _nn(0.3, 0.7)
		a.ty = e.gy + _nn(0.3, 0.7)
		a.al = 0.0
		a.big = 1.3
		a.act = 0
		Y0.a = a
		Y0.plot = n
		Y0.st = 0
		Y0.tt = 0.0
		# web: 50% gọi chó Vện (Gw) rượt sau 2,5 giây — phần chó không chép
		return
	a.ph = float(a.ph) + t * (5.0 if int(Y0.st) == 1 else 8.0)
	var l = G.g.plots[int(Y0.plot)] if int(Y0.plot) >= 0 and int(Y0.plot) < G.B0 else null
	var ten: String = "vịt" if a.sp == "vit" else "gà"
	if int(Y0.st) < 2 and (l == null or l.c == null or fence(int(Y0.plot))):
		dx(("Có rào, " + ten + " quay đi") if l != null and l.c != null else "")
	if int(Y0.st) == 0 or int(Y0.st) == 2:
		var c: float = a.tx - a.x
		var f: float = a.ty - a.y
		var s := Vector2(c, f).length()
		var h: float = (1.3 if int(Y0.st) == 2 else 0.8) * t
		a.mv = true
		if absf(c - f) > 0.001:
			a.face = 1 if c - f > 0.0 else -1
		if int(Y0.st) == 0:
			a.al = minf(1.0, float(a.al) + t * 1.5)
		else:
			a.al = maxf(0.0, float(a.al) - t * 0.35)
		if s <= h:
			a.x = a.tx
			a.y = a.ty
			if int(Y0.st) == 0:
				Y0.st = 1
				Y0.tt = 0.0
				a.mv = false
				a.act = 1
			else:
				Y0.a = null
		else:
			a.x += c / s * h
			a.y += f / s * h
		if int(Y0.st) == 2 and float(a.al) <= 0.0:
			Y0.a = null
		return
	Y0.tt = float(Y0.tt) + t
	a.mv = sin(float(Y0.tt) * 1.3) > 0.85
	if a.mv:
		a.x += sin(float(Y0.tt) * 2.0) * t * 0.1
	if float(Y0.tt) > 13.0:
		if l != null and l.c != null:
			var p: float = float(G.crop(l.c).time)
			if G.ripe(l):
				l.g = p * 0.8
			else:
				l.g = maxf(0.0, float(l.g) - p * 0.18)
			_a0(a.x, a.y, ("Vịt" if a.sp == "vit" else "Gà") + " bới hư ruộng! Rào lại nha")
			G.mark()
		dx("")

# ------------------------------------------------------------------ ốc gạo mùa nước nổi
func qs() -> bool:   # qs: mùa nước nổi (mùa thu, ngày 2..6 trong tuần mùa)
	if G.season() != 2:
		return false
	if str(G.cfg.s) != "auto":
		return true
	var t := posmod(_vr(), 28) % 7 + 1
	return t >= 2 and t <= 6

func gy(t: float) -> void:   # GY
	var a := qs()
	var r := 0
	if not a:
		for n in G.B0:
			var e = G.g.plots[n]
			if e and e.get("oc", 0):
				e.oc = 0
		return
	for n in G.B0:
		if G.g.plots[n] and G.g.plots[n].get("oc", 0):
			r += 1
	if r >= 5:
		return
	iA -= t
	if iA > 0.0:
		return
	iA = _nn(15.0, 35.0)
	var o := []
	for n in G.B0:
		var e = G.g.plots[n]
		if e and e.u and e.c != null and not e.get("oc", 0) and G.owned(n):
			o.append(n)
	if o.size():
		G.g.plots[o[randi() % o.size()]].oc = 1
		if G.g.get("ocHint") == null or int(G.g.ocHint) != _vr():
			G.g.ocHint = _vr()
			_ta("Mùa nước nổi: ốc gạo bò lên ruộng! Chạm ô ruộng có ốc để nhặt làm mồi câu, mồi lọp lươn.")

# ------------------------------------------------------------------ hạn mặn (g.man)
func b4() -> Dictionary:   # B4
	var t = G.g.get("man")
	if not (t is Dictionary):
		t = {}
		G.g.man = t
	if not _num(t.get("ngot")):
		t.ngot = 10.0
	return t

func o0() -> int:   # O0: số khúc sông Vàm đã mua
	var t := 0
	for a in W5:
		if G.g.get("land") is Dictionary and G.g.land.get(a):
			t += 1
	return t

func lc(t: int) -> bool:   # LC: ngày t nước mặn lấn vô (mấy ngày cuối tháng; đặt mùa cố định thì mùa khô)
	var a := posmod(t, 28)
	if str(G.cfg.s) != "auto":
		return G.season() == 3 and a % 7 >= 2
	return a >= 23

func n4() -> bool:   # N4
	if o0() == 0:
		return false
	return lc(_vr())

func ac() -> int:   # AC: còn mấy ngày nữa mặn lấn vô (-1 = 10 ngày tới không có)
	for t in 10:
		if lc(_vr() + t):
			return t
	return -1

func mz() -> int:   # MZ: còn mấy ngày nữa mặn mới rút
	var t := 0
	while t < 8 and lc(_vr() + t + 1):
		t += 1
	return t

func _yh(t: int, a: int) -> bool:   # yh: kênh trên khúc sông Vàm
	var n: String = G.lang.fo(t, a)
	return n != "" and W5.has(n) and G.lang.il(t, a) == "canal"

func jr() -> void:   # JR: khoảng cách (ô) từ mỗi ô ruộng tới kênh/sông (s7) và tới nước của mình (PC)
	if G.lang == null:
		return
	var t := str(G.g.land.size() if G.g.get("land") is Dictionary else 0) + "|" + str(G.B0)
	if s7.size() and XR == t:
		return
	XR = t
	s7 = []
	PC = []
	var a := []
	var n := []
	var L = G.lang
	var B: Array = L.M.B
	var seen := {}
	for x in range(int(B[0]), int(B[1])):
		for y in range(int(B[2]), int(B[3])):
			if L.fm(x, y):
				seen[str(x) + "," + str(y)] = Vector2i(x, y)
	L._a1()
	var O := _objs()
	for k in L.a1:
		for j in L.a1[k]:
			if O[j].id == "pond":
				var c: PackedStringArray = String(k).split(",")
				seen[k] = Vector2i(int(c[0]), int(c[1]))
	for k in seen:
		var v: Vector2i = seen[k]
		if _yh(v.x, v.y) or L.il(v.x, v.y) == "canal":
			a.append(v)
		elif L.ci(L.fo(v.x, v.y)):
			n.append(v)
	for c in G.B0:
		var f := _pi(c)
		var s := 99
		var h := 99
		for p in a:
			var d: int = maxi(absi(p.x - int(f.gx)), absi(p.y - int(f.gy)))
			if d < s:
				s = d
		for p in n:
			var d: int = maxi(absi(p.x - int(f.gx)), absi(p.y - int(f.gy)))
			if d < h:
				h = d
		s7.append(s)
		PC.append(h)

func yr(t: int) -> bool:   # YR: cách ao, hồ nước ngọt của mình 2 ô trở lại
	jr()
	return t < PC.size() and int(PC[t]) <= 2

func tz(t: int) -> int:   # TZ
	jr()
	return int(s7[t]) if t < s7.size() else 99

func r_salt(t: int) -> bool:   # $R
	return n4() and not yr(t)

func v6(t: int) -> bool:   # V6: ô đang nhiễm mặn
	var a = G.g.plots[t]
	if not a or not a.u or a.c == null or a.get("ng", 0) or (ol.has(a.c) and ol[a.c].get("man", 0)):
		return false
	return r_salt(t)

func t_o(t: int) -> float:   # tO: hệ số lớn khi nhiễm mặn
	if not v6(t):
		return 1.0
	var a := tz(t) <= 10
	if b4().get("cong", 0):
		return 0.6 if a else 0.85
	return 0.35 if a else 0.55

func a_o(t: int) -> void:   # aO: tưới ô nhiễm mặn tốn 1 nước ngọt trong lu
	var a: Dictionary = G.g.plots[t]
	if not r_salt(t) or a.c == null or (ol.has(a.c) and ol[a.c].get("man", 0)):
		return
	var n := b4()
	if float(n.ngot) >= 1.0:
		n.ngot = float(n.ngot) - 1.0
		a.ng = 1
		var e := _pi(t)
		_a0(e.gx + 0.5, e.gy + 0.5, "Nước ngọt trong lu")
	elif not n.get("warn") or _date_now() - float(n.warn) > 60000.0:
		n.warn = _date_now()
		_ta("Hết nước ngọt trong lu, tưới nước sông mặn cây vẫn chậm lớn. Mua nước ngọt hoặc chờ mưa hứng nước.")

func sz(t: float) -> void:   # SZ (mỗi 2 giây)
	zC -= t
	if zC > 0.0:
		return
	zC = 2.0
	var a := b4()
	var n := n4()
	var e := _vr()
	if n and (a.get("ann") == null or int(a.ann) != e):
		a.ann = e
		var r := 0
		for o in G.B0:
			if v6(o):
				r += 1
		_ta("Hạn mặn! Nước mặn lấn vô sông Vàm theo kênh mương vô ruộng" + ((", " + str(r) + " ô ruộng chậm lớn hẳn.") if r else ".") + " Tưới bằng nước ngọt trong lu, trồng lúa chịu mặn, hoặc xây cống ngăn mặn.")
	if not n and ac() == 1 and (a.get("fc") == null or int(a.fc) != e):
		a.fc = e
		_ta("Đài báo: mai nước mặn lấn vô sông Vàm. Hứng nước mưa, trữ nước ngọt sẵn nha!")
	if G.troi != null and G.troi.rainy() and float(a.ngot) < u7():
		a.ngot = minf(u7(), float(a.ngot) + 0.2)
	for l in G.g.plots:
		if l.get("ng", 0) and (l.c == null or float(l.w) <= 0.0):
			l.erase("ng")
	if ui != null:
		ui.cz()
		if ui.man != null:
			ui.u6()

func man_n() -> int:   # số ô nhiễm mặn (vòng đếm V6 trong CZ / U6)
	var a := 0
	for n in G.B0:
		if v6(n):
			a += 1
	return a

func ez() -> bool:   # EZ: mua 10 nước ngọt
	var t := b4()
	var a := u7()
	if float(t.ngot) >= a:
		_ta("Lu đầy rồi. Đặt thêm lu nước, chum sành (Xây dựng › Đồ vật) để chứa thêm.")
		return false
	if int(G.g.coins) < K6:
		_ta("Cần " + str(K6) + " xu.")
		return false
	G.g.coins = int(G.g.coins) - K6
	t.ngot = minf(a, float(t.ngot) + 10.0)
	_ta("Ghe chở nước ngọt đổ đầy 10 lu. Lu còn " + str(int(floor(float(t.ngot)))) + " nước ngọt.")
	G.mark()
	if ui != null:
		ui.u6()
	return true

func lz() -> bool:   # LZ: xây cống ngăn mặn
	var t := b4()
	if t.get("cong", 0):
		return false
	if int(G.g.coins) < Q6:
		_ta("Cần " + G.fmt_n(Q6) + " xu xây cống.")
		return false
	G.g.coins = int(G.g.coins) - Q6
	t.cong = 1
	_ta("Xây xong cống ngăn mặn đầu kênh! Nước mặn vô ít hẳn.")
	G.mark()
	if ui != null:
		ui.u6()
	return true

# ------------------------------------------------------------------ giống lai (g.lai)
func qf(t: String) -> int:   # qf: cấp còn thiếu để mở chức năng (0 = đã mở)
	if G.g.get("cdOld") is Dictionary and G.g.cdOld.get(t):
		return 0
	var a := int(V4.get(t, 0))
	return a if G.lv() < a else 0

func w6() -> Dictionary:   # W6
	var t = G.g.get("lai")
	if not (t is Dictionary):
		t = {}
		G.g.lai = t
	if not (t.get("d") is Dictionary):
		t.d = {}
	if not _num(t.get("n")):
		t.n = 0
	return t

func mc(t: String) -> bool:   # MC: đã có giống lai t
	if not (G.g.get("lai") is Dictionary and G.g.lai.get("d") is Dictionary):
		return false
	var v = G.g.lai.d.get(t)
	return true if v else false

func lai_h() -> Dictionary:   # laiH: số hạt lai đang giữ
	var p := w6()
	if not (p.get("h") is Dictionary):
		p.h = {}
		for t in p.d.keys():
			p.h[t] = 3
	return p.h

func lai_add(t: String, n: int) -> void:   # laiAdd
	var h := lai_h()
	h[t] = int(h.get(t, 0)) + n

func sd_n(t: String) -> int:   # sdN: hạt giống (giống lai lấy ở g.lai.h)
	if ol.has(t):
		return int(lai_h().get(t, 0))
	return int(G.g.barn.get(t, 0))

func sd_use(t: String) -> void:   # sdUse
	if ol.has(t):
		var h := lai_h()
		h[t] = maxi(0, int(h.get(t, 0)) - 1)
	else:
		G.g.barn[t] = int(G.g.barn.get(t, 0)) - 1

func yz() -> Dictionary:   # yZ: "gx,gy" -> ô
	if j6 != null:
		return j6
	j6 = {}
	for t in G.B0:
		var a := _pi(t)
		j6[str(int(a.gx)) + "," + str(int(a.gy))] = t
	return j6

func xz(t: String, a: String) -> Variant:   # xZ: giống lai của 2 cây gốc
	for n in Wc:
		var e: Dictionary = ol[n]
		if (e.a == t and e.b == a) or (e.a == a and e.b == t):
			return n
	return null

func z4(t: int, a: String, n: bool = true) -> void:   # z4 (+ lớp bọc qf("lai"))
	if qf("lai"):
		return
	if ol.has(a):
		return
	var e := _pi(t)
	var r := yz()
	var o := []
	for l in range(-1, 2):
		for c in range(-1, 2):
			if not l and not c:
				continue
			var f = r.get(str(int(e.gx) + l) + "," + str(int(e.gy) + c))
			if f == null:
				continue
			var s: Dictionary = G.g.plots[f]
			var h = s.c if s.c != null else s.get("lc")
			if h == null or String(h) == "" or h == a:
				continue
			var dd = xz(a, String(h))
			if dd != null and not o.has(dd):
				o.append(dd)
	if not o.size():
		return
	var p := w6()
	var d: String = o[randi() % o.size()]
	var v: bool = not p.d.get(d)
	var x := 0.14 if v else 0.08
	if randf() >= x:
		return
	var k: int = 3 if v else 1 + (1 if randf() < 0.3 else 0)
	lai_add(d, k)
	p.n = int(p.n) + 1
	if v:
		p.d[d] = _date_now()
		if n:
			_ta("Lai giống mới: " + String(ol[d].name) + "! Được " + str(k) + " hạt lai. " + String(ol[d].d) + " Xem sổ giống lai trong bảng nhân vật.")
			G.vib(60)   # gr([12, 30, 18]): Godot rung một lần cả mẫu
			var M := _pi(t)
			_a0(M.gx + 0.5, M.gy + 0.5, "✦ Giống lai mới!")
	elif n:
		var T := _pi(t)
		_a0(T.gx + 0.5, T.gy + 0.5, "+" + str(k) + " hạt " + String(ol[d].name).to_lower())

# ------------------------------------------------------------------ g.wx: chạm trúng trái rụng / chỗ rừng (toạ độ làng px)
func ft(t: float, a: float) -> Variant:   # FT
	var n = G.g.get("wx")
	if not (n is Dictionary) or not (n.get("fall") is Array) or not n.fall.size():
		return null
	for e in range(n.fall.size() - 1, -1, -1):
		var r: Dictionary = n.fall[e]
		var o: float = G.lang.en(float(r.gx) + 0.5, float(r.gy) + 0.5)
		var l: float = G.lang.nn(float(r.gx) + 0.5, float(r.gy) + 0.5, 0.0)
		if absf(t - o) < 34.0 and a > l - 46.0 and a < l + 16.0:
			return {"type": "fall", "key": _sv(r.gx) + "," + _sv(r.gy)}
	return null

func rk(t: float, a: float) -> Variant:   # RK
	var n = G.g.get("wx")
	if not (n is Dictionary) or not (n.get("rung") is Array):
		return null
	for e in n.rung.size():
		var r: Dictionary = n.rung[e]
		var o: float = float(r.gx) + 0.5 + (0.35 if int(r.get("s", 0)) % 2 else -0.25)
		var l: float = float(r.gy) + 1.05
		var c: float = G.lang.en(o, l)
		var f: float = G.lang.nn(o, l, 0.0)
		if absf(t - c) < 18.0 and a > f - 30.0 and a < f + 8.0:
			return {"type": "rung", "k": r.get("k")}
	return null

# ------------------------------------------------------------------ bến ghe dọn cây, cỏ dưới chân (g.clr)
func benclr() -> bool:   # BENCLR (sau mỗi lần dựng lại a1); true = có dọn, cần vẽ lại
	var hit := false
	if not (G.g.get("clr") is Dictionary):
		G.g.clr = {}
	var L = G.lang
	var re := RegEx.create_from_string("^ben[2-4]?$")
	var re24 := RegEx.create_from_string("^ben[24]$")
	for o in _objs():
		if not o or re.search(String(o.id)) == null:
			continue
		var r := [3, 2] if re24.search(String(o.id)) != null else [2, 3]
		for c in r[0]:
			for f in r[1]:
				var x: int = int(o.gx) + c
				var y: int = int(o.gy) + f
				var k := str(x) + "," + str(y)
				if L.D5(x, y):
					var hi = L.M.hu.get(k)
					var e = L.HU[int(hi)] if hi != null else null
					if e != null and not L.kc(e.gx, e.gy):
						G.g.clr[str(e.gx) + "," + str(e.gy)] = 1
					else:
						G.g.clr[k] = 1
					hit = true
				if G.g.get("minis") is Dictionary:
					for v in 2:
						for w in 2:
							var mk := str(x * 2 + v) + "," + str(y * 2 + w)
							if G.g.minis.has(mk):
								G.g.minis.erase(mk)
								hit = true
	return hit

# ------------------------------------------------------------------ cài đặt chung theo bản lưu (g.dm, g.sea)
func oj() -> void:   # oJ: b1 = G.cfg.d, Af = G.cfg.s
	if not DM.has(G.g.get("dm")):
		G.g.dm = G.cfg.d
	elif G.g.dm != G.cfg.d:
		G.cfg_set("d", G.g.dm)
		if G.troi != null:
			G.troi.hh = -1.0
	var s = G.g.get("sea")
	var ok: bool = (typeof(s) == TYPE_STRING and s == "auto") or (s != null and RegEx.create_from_string("^[0-3]$").search(_sv(s)) != null)
	if not ok:
		G.g.sea = G.cfg.s
	elif _sv(s) != str(G.cfg.s):
		G.cfg_set("s", _sv(s))

# ------------------------------------------------------------------ đổi bảng Nâng cấp cũ sang nâng sao (một lần)
func qh() -> void:   # qH
	if G.g == null or G.g.get("sv"):
		return
	var t: Dictionary = G.g.up if G.g.get("up") is Dictionary else {}
	var a := 1 + mini(4, maxi(int(t.get("fert", 0)), int(t.get("well", 0))))
	for r in G.g.plots:
		if r.u and not (int(r.get("st", 0)) > 1):
			r.st = a
	var n := 1 + mini(4, int(t.get("pen", 0)))
	if not (G.g.get("penst") is Dictionary):
		G.g.penst = {}
	for r in G.lang.C.Di:
		if G.lang.pen_built(r) and not (int(G.g.penst.get(r, 0)) > 1):
			G.g.penst[r] = n
	var e := 1 + mini(4, int(t.get("xuong", 0)))
	for r in G.xw.N0:
		var o = G.g.work.get(r) if G.g.get("work") is Dictionary else null
		if o and o.get("b", 0) and not (int(o.get("st", 0)) > 1):
			o.st = e
	G.g.sapst = maxi(int(G.g.get("sapst", 0)), 1 + mini(4, int(t.get("stall", 0))))
	G.g.sv = 1
	if a > 1 or n > 1 or e > 1 or int(G.g.sapst) > 1:
		_qh_msg = "Bảng Nâng cấp đã đổi sang nâng sao: ô ruộng " + str(a) + "★, chuồng " + str(n) + "★, xưởng " + str(e) + "★, sạp " + str(int(G.g.sapst)) + "★. Chạm từng thứ để nâng tiếp, cần xu và vật liệu."
		_qh_t = 2.2
