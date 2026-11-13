extends RefCounted
# Câu cá, lờ lọp, thú cưng (vịt, cá nuôi, mèo, chào mào), tát ao, thả diều: chép 1:1 luật bản web.
#   câu cá g.fish (JF, P7 + bọc, xB, QO, MX, TX, F4 + bọc, vE + bọc, mE, e8, KO, pE, gE + bọc, ME, ZO, yE + bọc,
#     fF, cF, c5, B9, lv, IY, uF, DF, B$, N$, rY, TT, MT, nút #fishGo), sổ (iV, Tc, oV),
#   lờ lọp giăng câu g.lo (T1, Jd, qk, KU, Bm, Bk, w4, L6, UU, fR, sR, Rk, ZU, Nk, GS, hZ, _U, t_, $U),
#   thú cưng g.pet (Cc, dN, WQ, Xx, Jx, GQ, jQ, DQ, VQ, uZ, tK, nK, wg + bọc, f6, e6, o6, r6, ZT, _x, _b, w2, CH),
#   tát ao g.tat (Am, WN, y4, QK, b6 + bọc, KK, DN, yS, UK),
#   thả diều g.dieu (Fh, xk, Cg, cU, fU, dU, ZN, pU, AS, v1).
# Vẽ (SX, _K, gU, XU, XQ, JQ, _Q, gN, uU), âm thanh (Jt, tk, $x, hU, aK), hạt bay, rung DOM: không chép.

var G
var ui = null              # w_ca_ui.gd (gán ở _init của nó)
var WR = null              # w_ruong.gd: qs, o0, n4, qf, _yh (người ghép gán)
var WC = null              # w_cho.gd: YT, T_ ($T), hN (người ghép gán)
var WS = null              # w_sys.gd: htv (người ghép gán)
var WK = null              # w_kho.gd: Rl (người ghép gán)
var ext := {}              # hàm của hệ khác (người ghép gán Callable):
#   "Zd": func(x: float, y: float, n: bool) -> bool   đi tới được (lưới đi bộ)
#   "Gl": func(job: Dictionary) -> void                xếp việc cho nhân vật {key, kind, pos, dur, run}
#   "No": func(k: String, a: float, pos) -> void       vật liệu rơi (Lu)
#   "L1": func(o: Dictionary) -> void                  bảng "còn thiếu" (mats/items, xu, why, go)
#   "_8": func(all: bool) -> Dictionary                món các đơn hàng đang cần
#   "Ur": func() -> Dictionary                         trạng thái tự chơi (on, fs, rx) hoặc null
#   "zc": func(t: String) -> void                      mở tab (zc("fish"))
#   "g2": func() -> void                               đóng bảng nhân vật
#   "ec": func() -> void                               vẽ lại bảng nhân vật

# ------------------------------------------------------------------ dữ liệu
var lc := {}               # cá câu
var Wf := []               # mã cá
var c1 := {}               # mồi câu
var ns := {}               # lờ, lọp, giăng câu
var n3 := []               # tên cần
var rA := []               # mô tả cần
var OY := []               # nâng cần
var HY := []               # cấp nâng cần
var m6 := []               # cá tát ao
var k4 := []               # diều
var Z7 := {}               # tên chức năng
const n8 := 3              # xu mồi cám
const sF := ["cam", "trun", "sau", "oc", "tep", "thom"]
const FS := ["lo", "lop", "giang"]
const Nh := {"vit": 600, "ca": 240, "meo": 300, "chim": 900}
const t6 := 8              # đàn vịt tối đa
const a6 := 300.0          # giây no của vịt mỗi lần rải lúa
const n6 := 360.0          # giây no của cá
const Xf := 900.0          # cá lớn đủ
const D2_FISH := 2.0       # d2.fish: sức mất mỗi lần thả câu
const Yx := [7.2, 8.8, 4.1, 4.8]

# ------------------------------------------------------------------ trạng thái không lưu
var fo := {"st": "idle", "t": 0.0, "wait": 3.0, "fish": null, "hold": false, "zc": 0.3, "zv": 0.0, "zh": 0.3, "fp": 0.5, "ft": 0.5, "fn": 0.0, "p": 0.35, "res": null, "msg": "", "W": 0, "H": 0, "loc": null}   # or
var on_fish := false       # ni === "fish"
var title := ""            # FO (#pTitle) khi câu
var S3 := ""               # chữ ký thanh mồi (oA)
var M3 := -1               # rY
var yf = null              # Yf: chọn chỗ thả {k, buy, cb, msg, sub, at}
var ai = null              # tát ao
var zi = null              # thi diều
var l6 := 0.0              # vịt chạy tới bờ (vẽ)
var c6 := 0.0              # cá ngoi lên ăn (vẽ)
var qi_hap := 0.0          # Qi.hap: mèo vui (vẽ)
var rh_sing := 0.0         # Rh.sing: chim hót (vẽ)
var XT := {}               # w2
var _zt_v := -1            # uN
var _zt = null             # v4
var _qo_v := -1
var _qo_n := 0
var _ul := 0.0             # rY mỗi giây
var _ds := 0.0             # dS: WQ mỗi giây
var _ht := 0.0             # hT: iV mỗi 2 giây
var _wq_msg := ""          # WQ setTimeout 3 giây
var _wq_t := 0.0

func _init(game) -> void:
	G = game
	lc = _jd("cau_ca/ca")
	Wf = _ja("cau_ca/ds_ca")
	c1 = _jd("cau_ca/moi")
	ns = _jd("cau_ca/lo_lop_cau_giang")
	n3 = _ja("cau_ca/ten_can")
	rA = _ja("cau_ca/mo_ta_can")
	OY = _ja("cau_ca/nang_can")
	HY = _ja("cau_ca/nang_can_cap")
	m6 = _ja("cau_ca/tat_muong")
	k4 = _ja("mini_game/dieu")
	Z7 = _jd("nhan_vat/ten_chuc_nang")

# ------------------------------------------------------------------ tiện ích chung
func _jd(p: String) -> Dictionary:   # G._j (Dictionary)
	var v = G._j(p)
	return v if v is Dictionary else {}

func _ja(p: String) -> Array:   # G._j (Array)
	var v = G._j(p)
	return v if v is Array else []

func _x(k: String) -> Callable:
	var c = ext.get(k)
	return c if c is Callable and (c as Callable).is_valid() else Callable()

static func _nn(a: float, b: float) -> float:   # Nn
	return a + randf() * (b - a)

static func _rnd(x: float) -> int:   # Math.round
	return int(floor(x + 0.5))

static func _tr(v) -> bool:   # JS truthy
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	if v is String:
		return v != ""
	return true

static func _sv(v) -> String:   # String(number) như JS
	if typeof(v) == TYPE_FLOAT and v == floor(v):
		return str(int(v))
	return str(v)

static func _kgs(v) -> String:   # String(kg).replace(".", ",")
	return _sv(v).replace(".", ",")

func _now() -> float:   # Date.now()
	return G._now_ms()

func _ta(s: String) -> void:   # ta / pn
	G.toast.emit(s)

func _ba() -> void:   # kn / Ba
	G.mark()

func _gr(ms) -> void:   # gr (mẫu rung [a, b, c]: rung đoạn đầu)
	G.vib(int(ms[0]) if ms is Array else int(ms))

func _a0(x: float, y: float, s: String) -> void:   # a0
	G.float_text.emit(x, y, s)

func _barn(k: String) -> int:   # g.barn[k] | 0
	return int(G.g.barn.get(k, 0))

func _nm(k: String) -> String:   # ae(k).name
	return String(G.item_name(k))

func _sa(v) -> String:   # Sa
	return G.fmt_n(float(v))

func _vr() -> int:   # vr
	return G.day()

func _d0() -> float:   # d0
	return float(G.troi.hour())

func _dh() -> Dictionary:   # dh
	return G.troi.dh()

func _pc() -> Dictionary:   # fr()
	return G.g.pc

func _jr() -> int:   # jr
	return G.lv()

func _qi(k: String) -> void:   # qi
	G.nv.qi(k)

func _w1(t: int, k: String) -> void:   # w1
	G.add_xp(t, k)

func _v0(t: float) -> int:   # v0
	return G.nv.v0(t)

func _htv(id: String) -> float:   # htv
	return float(WS.htv(id)) if WS != null else 0.0

func _kx() -> bool:   # Kx: bùa "cau"
	return G.bh() == "cau"

func _qs() -> bool:   # qs (typeof qs == "function" && qs())
	return WR != null and bool(WR.qs())

func _o0() -> int:   # O0
	return int(WR.o0()) if WR != null else 0

func _n4() -> bool:   # N4
	return WR != null and bool(WR.n4())

func _qf(t: String) -> int:   # qf
	return int(WR.qf(t)) if WR != null else 0

func _jg(t: String) -> bool:   # Jg
	var a := _qf(t)
	if a:
		_ta(String(Z7.get(t, "Chức năng này")) + " mở ở cấp " + str(a) + ".")
		return false
	return true

func _no(k: String, a: float = 1.0, pos = null) -> void:   # No
	var f := _x("No")
	if f.is_valid():
		f.call(k, a, pos)

func _xh() -> void:   # Xh (vẽ lại bảng câu)
	if ui != null:
		ui.xh()

func _ec() -> void:   # ec
	var f := _x("ec")
	if f.is_valid():
		f.call()

func _g2() -> void:   # g2
	var f := _x("g2")
	if f.is_valid():
		f.call()

func _ver() -> int:   # Vo
	return int(G.lang.ver) if G.lang != null else 0

# ------------------------------------------------------------------ ô nước, bờ
func _p0(x: int, y: int) -> bool:   # p0[x+","+y]
	return G.lang != null and G.lang.is_water(x, y)

func _fo(x: int, y: int) -> String:   # fo
	return String(G.lang.fo(x, y)) if G.lang != null else ""

func _ci(p: String) -> bool:   # ci
	return G.lang != null and G.lang.ci(p)

func _xx(t: int, a: int) -> bool:   # _x: ô nước của mình
	return _p0(t, a) and _ci(_fo(t, a))

func _bb(t: int, a: int) -> bool:   # _b: đất của mình, không phải nước
	var n := _fo(t, a)
	return n != "" and _ci(n) and not _p0(t, a)

func _yh(t: int, a: int) -> bool:   # yh: kênh trên khúc sông Vàm
	return WR != null and bool(WR._yh(t, a))

func _il(t: int, a: int) -> String:   # Il
	return String(G.lang.il(t, a)) if G.lang != null else ""

func _zd(x: float, y: float, n: bool) -> bool:   # Zd
	var f := _x("Zd")
	return bool(f.call(x, y, n)) if f.is_valid() else false

func _uu(t: int, a: int) -> bool:   # _U: sát mé nước, lội tới được
	if _tr(_pc().get("xuong")):
		return true
	for n in range(-2, 3):
		for e in range(-2, 3):
			if absi(n) + absi(e) > 3:
				continue
			if _zd(t + n + 0.5, a + e + 0.5, false):
				return true
	return false

func mt(t: int, a: int):   # MT: chỗ đứng câu / thăm bẫy
	if _tr(_pc().get("xuong")) and _yh(t, a):
		return {"stand": [t + 0.5, a + 0.5], "w": [t + 0.5 + 0.6, a + 0.5], "boat": 1}
	var n = null
	var e := 1e9
	for r in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]:
		var o: int = t + r[0]
		var l: int = a + r[1]
		if _bb(o, l):
			var c: float = t + 0.5 + r[0] * 0.62
			var f: float = a + 0.5 + r[1] * 0.62
			var s := Vector2(c - G.ppos.x, f - G.ppos.y).length()
			if s < e:
				e = s
				n = {"stand": [c, f], "w": [t + 0.5 - r[0] * 0.15, a + 0.5 - r[1] * 0.15], "boat": 0}
	return n

# ------------------------------------------------------------------ câu cá: bản lưu
func jf(t) -> Dictionary:   # JF: sửa g.fish khi tải
	var a := {"rod": 0, "total": 0, "dex": {}}
	if not (t is Dictionary):
		return a
	a.rod = maxi(0, mini(4, int(t.get("rod", 0)) if _num(t.get("rod")) else 0))
	a.total = maxi(0, int(t.get("total", 0)) if _num(t.get("total")) else 0)
	for e in Wf:
		var r = t.dex.get(e) if t.get("dex") is Dictionary else null
		if r is Dictionary:
			a.dex[e] = {"n": maxi(0, int(r.get("n", 0)) if _num(r.get("n")) else 0), "best": maxf(0.0, float(r.get("best", 0)) if _num(r.get("best")) else 0.0)}
	if t.get("bait") is Dictionary:
		a.bait = {}
		var re := RegEx.create_from_string("^[a-z_]+$")
		for n in t.bait:
			if re.search(String(n)) != null:
				var v = t.bait[n]
				a.bait[n] = maxi(0, mini(9999, int(v) if _num(v) else 0))
	if t.get("bs") is String and RegEx.create_from_string("^[a-z_]+$").search(t.bs) != null:
		a.bs = t.bs
	return a

static func _num(v) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT

func _fi() -> Dictionary:   # g.fish
	if not (G.g.get("fish") is Dictionary):
		G.g.fish = jf(null)
	var f: Dictionary = G.g.fish
	if not (f.get("dex") is Dictionary):
		f.dex = {}
	return f

func _rod() -> int:   # g.fish.rod | 0
	return int(_fi().get("rod", 0))

# ------------------------------------------------------------------ câu cá: mồi
func c5() -> Dictionary:   # c5
	var f := _fi()
	var t = f.get("bait")
	if not (t is Dictionary):
		t = {"trun": 3, "sau": 0, "thom": 0}
		f.bait = t
	return t

func b9() -> String:   # B9: mồi đang chọn
	var f := _fi()
	var t := String(f.get("bs", "cam")) if _tr(f.get("bs")) else "cam"
	if t == "tom":
		t = "tep"
		f.bs = t
	return t if c1.has(t) else "cam"

func lv(t: String) -> float:   # lv: số mồi (cám = vô hạn)
	if t == "cam":
		return INF
	if _tr(c1[t].get("barn")):
		return float(_barn(t))
	return float(int(c5().get(t, 0)))

func iy(t: String) -> void:   # IY: dùng 1 mồi
	if _tr(c1[t].get("barn")):
		G.g.barn[t] = _barn(t) - 1
	else:
		var b := c5()
		b[t] = int(b.get(t, 0)) - 1

func pick_bait(t: String) -> void:   # oA click [data-bt]
	var s := String(fo.st)
	if s == "cast" or s == "wait" or s == "bite" or s == "reel":
		return
	_fi().bs = t
	S3 = ""
	_xh()

func uf() -> void:   # uF: trộn mồi thơm
	if _barn("bot") < 1 or _barn("trung") < 1:
		var f := _x("L1")
		if f.is_valid():
			f.call({"items": G.missing([["bot", 1], ["trung", 1]]), "why": "Trộn mồi thơm còn thiếu:", "go": uf})
		else:
			_ta("Cần 1 bột mì và 1 trứng.")
		return
	G.g.barn.bot = _barn("bot") - 1
	G.g.barn.trung = _barn("trung") - 1
	c5().thom = int(c5().get("thom", 0)) + 4
	_ta("Trộn được 4 viên mồi thơm, cá chép, cá bông lau mê lắm.")
	S3 = ""
	_ba()
	_xh()

func _need8() -> Dictionary:   # _8(!0)
	var f := _x("_8")
	var v = f.call(true) if f.is_valid() else {}
	return v if v is Dictionary else {}

func df() -> int:   # DF: số cá các đơn còn thiếu
	var t := _need8()
	var a := 0
	for n in t:
		if lc.has(n):
			var e := int(t[n]) - _barn(n)
			if e > 0:
				a += e
	return a

func b_s() -> Array:   # B$: mã cá đơn còn thiếu
	var t := _need8()
	var out := []
	for a in t:
		if lc.has(a) and int(t[a]) > _barn(a):
			out.append(a)
	return out

func n_s() -> void:   # N$: chọn mồi dụ được cá đơn cần
	var t := b_s()
	var a := "cam"
	var n := 1.0
	for e in c1:
		if e == "cam" or lv(e) < 1:
			continue
		var r := 1.0
		var mu = c1[e].get("mul")
		for o in t:
			var m := float(mu.get(o, 0)) if mu is Dictionary else 0.0
			r = maxf(r, m if m != 0.0 else 1.0)
		if r > n:
			n = r
			a = e
	_fi().bs = a

# ------------------------------------------------------------------ câu cá: chọn cá
func qo() -> int:   # QO: số ô nước trong đất của mình
	if G.lang == null:
		return 0
	if _qo_v == _ver() and _qo_v >= 0:
		return _qo_n
	_qo_v = _ver()
	var B: Array = G.lang.M.B
	var a := 0
	for y in range(int(B[2]), int(B[3])):
		for x in range(int(B[0]), int(B[1])):
			if _p0(x, y):
				var e := _fo(x, y)
				if e != "" and _ci(e):
					a += 1
	_qo_n = a
	return a

func xb(t: String) -> float:   # xB: hệ số chỗ câu
	var a: Dictionary = fo.loc if fo.loc is Dictionary else {}
	var n := 1.0
	if _tr(a.get("riv")):
		n *= float({"ca_loc": 2, "ca_tre": 1.4, "ca_chep": 0.7, "ca_koi": 0.4}.get(t, 1))
		if _tr(a.get("boat")):
			n *= float({"ca_loc": 1.6, "ca_koi": 1.8, "ca_ro": 0.6}.get(t, 1))
	else:
		n *= 1.4 if t == "ca_chep" else (1.3 if t == "ca_koi" else (0.0 if t == "ca_linh" else 1.0))
	if t == "ca_loc" or t == "ca_koi":
		n *= (1.0 + _htv("n_cau")) * (1.5 if _kx() else 1.0)
	return n

func p7() -> Dictionary:   # P7 (+ lớp bọc cá lăng, cá bông lau, hệ số mồi)
	var t := qo()
	var a := _dh()
	var n := String(a.phase)
	var e := bool(a.night)
	var r := _rod()
	var o := {}
	var loc: Dictionary = fo.loc if fo.loc is Dictionary else {}
	for l in lc:
		var c: Dictionary = lc[l]
		if t < float(c.min):
			continue
		var f := float(c.w)
		if l == "ca_linh":
			if not (_qs() and _o0() > 0 and _tr(loc.get("riv"))):
				continue
			f = 48.0
		f *= xb(l)
		if l == "ca_tre":
			f *= 2.0 if e else 0.6
		if l == "ca_loc":
			f *= 3.0 if e else 0.3
		if l == "tom":
			f *= 2.4 if (n == "dawn" or n == "dusk") else (0.5 if e else 1.0)
		if l == "ca_koi":
			f *= 4.0 if (n == "dawn" or n == "dusk") else (0.5 if e else 1.0)
		if l == "ca_loc" or l == "ca_koi":
			f *= 1.0 + 0.35 * r
		o[l] = f
	# lớp bọc
	o.erase("ca_lang")
	o.erase("ca_bong_lau")
	if _tr(loc.get("riv")) and r >= 2:
		o["ca_lang"] = (7.0 if G.night else 4.0) * (1.0 + 0.2 * (r - 2))
	if _tr(loc.get("riv")) and _tr(loc.get("boat")) and r >= 3:
		o["ca_bong_lau"] = (3.5 if (n == "dawn" or n == "dusk") else 1.6) * (1.0 + 0.3 * (r - 3))
	var rr = c1.get(b9())
	if rr is Dictionary and rr.get("mul") is Dictionary:
		for k in o:
			var m := float(rr.mul.get(k, 0))
			o[k] = float(o[k]) * (m if m != 0.0 else 1.0)
	return o

func mx() -> String:   # MX: rút cá
	var t := p7()
	var n := 0.0
	for a in t:
		n += float(t[a])
	var e := randf() * n
	for a in t:
		e -= float(t[a])
		if e <= 0.0:
			return a
	return "ca_ro"

func tx(t: String) -> float:   # TX: bề rộng vùng kéo
	return minf(0.5, 0.36 - 0.055 * float(lc[t].dif) + 0.04 * _rod())

# ------------------------------------------------------------------ câu cá: lượt câu
func set_loc(riv: bool, boat: bool) -> void:   # or.loc = {riv, boat} (TT run)
	fo.loc = {"riv": riv, "boat": 1 if boat else 0}

func tt(t: int, a: int) -> bool:   # TT: chạm mặt nước để đi câu
	var n = mt(t, a)
	if n == null:
		_ta("Không có bờ để đứng câu chỗ này.")
		return false
	var gl := _x("Gl")
	var run := func() -> bool:
		fo.loc = {"riv": _yh(t, a), "boat": n.boat}
		title = "Câu cá · " + ((("giữa sông Vàm" if _tr(n.boat) else "bờ sông Vàm")) if fo.loc.riv else "bờ ao")
		var z := _x("zc")
		if z.is_valid():
			z.call("fish")
		return true
	if gl.is_valid():
		# aa.fishing = {wx, wy}, aa.fface: lớp nhân vật đọc job.fishing
		gl.call({"key": "fish", "kind": "gofish", "pos": n.stand, "dur": 0.2, "fishing": {"wx": n.w[0], "wy": n.w[1]}, "run": run})
	return true

func me_open() -> void:   # ME (mở tab câu): dừng lượt dở
	on_fish = true
	var s := String(fo.st)
	if s == "cast" or s == "wait" or s == "bite" or s == "reel":
		fo.st = "idle"
	fo.hold = false
	fo.msg = ""
	fo.W = 0
	_xh()

func zo() -> void:   # ZO (rời tab câu)
	on_fish = false
	fo.hold = false
	fo.st = "idle"
	fo.msg = ""

func _cast(w: float) -> void:   # phần chung F4: thả câu
	fo.st = "cast"
	fo.t = 0.0
	fo.fish = null
	fo.res = null
	fo.hold = false
	fo.wait = _nn(2.0, 6.5) * (1.0 - 0.07 * _rod()) * w
	fo.msg = ""
	_gr(10)
	_ba()

func _f4_0() -> void:   # F4 gốc: mua mồi cám
	if int(G.g.coins) < n8:
		_ta("Cần " + str(n8) + " xu để mua mồi.")
		return
	var t := maxi(1, n8 - _rnd(_htv("n_cau") * 4.0))
	if int(G.g.coins) < t:
		_ta("Cần " + str(t) + " xu để mua mồi.")
		return
	G.g.coins = int(G.g.coins) - t
	G.use_en(D2_FISH)   # qh(d2.fish)
	_cast(1.0)

func f4() -> void:   # F4 (+ lớp bọc mồi)
	var a := b9()
	if a == "cam":
		_f4_0()
		return
	if lv(a) < 1:
		_ta("Hết " + String(c1[a].n).to_lower() + ". " + String(c1[a].src) + ".")
		_fi().bs = "cam"
		S3 = ""
		_xh()
		return
	iy(a)
	G.use_en(D2_FISH)   # qh(d2.fish)
	_cast(float(c1[a].wait))

func go_click() -> void:   # #fishGo click
	var t := String(fo.st)
	if t == "idle" or t == "caught" or t == "lost":
		f4()
	elif t == "cast" or t == "wait":
		fo.st = "idle"
		fo.msg = "Bạn thu cần về, mồi đã mất."
		_xh()

func ko() -> void:   # KO: giật, vào kéo
	fo.st = "reel"
	fo.t = 0.0
	fo.zh = tx(String(fo.fish))
	fo.zc = float(fo.zh) / 2.0 + 0.02
	fo.zv = 0.0
	fo.fp = 0.5
	fo.ft = 0.5
	fo.fn = 0.3
	fo.p = 0.35
	fo.msg = "Giữ tay để kéo vùng xanh theo con cá!"
	_gr(18)
	_xh()

func pe(t: String) -> void:   # pE: sổng cá
	fo.st = "lost"
	fo.t = 0.0
	fo.hold = false
	fo.msg = t
	fo.fish = null
	_gr([30, 40, 30])
	_xh()

func me() -> bool:   # mE: nhấn nút / ao
	if fo.st == "bite":
		ko()
		fo.hold = true
		return true
	if fo.st == "reel":
		fo.hold = true
		return true
	return false

func e8() -> void:   # e8: buông tay
	if fo.hold:
		fo.hold = false

func ge() -> void:   # gE (+ lớp bọc cá khủng, No("fish"))
	var t := String(fo.fish)
	var a: Dictionary = lc[t]
	var n := _rnd((float(a.kg[0]) + (float(a.kg[1]) - float(a.kg[0])) * pow(randf(), 1.7)) * 100.0) / 100.0
	var f := _fi()
	G.g.barn[t] = _barn(t) + 1
	f.total = int(f.total) + 1
	_w1(3, "fish")
	if not (f.dex.get(t) is Dictionary):
		f.dex[t] = {"n": 0, "best": 0}
	var e: Dictionary = f.dex[t]
	e.n = int(e.n) + 1
	if n > float(e.best):
		e.best = n
	fo.res = {"id": t, "kg": n, "price": G.price(t)}
	fo.st = "caught"
	fo.t = 0.0
	fo.hold = false
	fo.msg = ""
	_gr([20, 40, 20])
	_ba()
	# lớp bọc
	var r: Dictionary = fo.res
	var o: Dictionary = lc[r.id]
	var l := float(o.kg[0]) + (float(o.kg[1]) - float(o.kg[0])) * 0.85
	if float(r.kg) >= l:
		var c := _v0(_rnd(float(r.price) * 1.5))
		G.g.coins = int(G.g.coins) + c
		r.big = 1
		_ta("Cá khủng! " + _kgs(r.kg) + " kg, được thưởng thêm " + _sa(c) + " xu.")
	_no("fish")

func ve(t: float) -> void:   # vE (+ lớp bọc tự chơi): mỗi khung hình khi tab câu mở (_O)
	var a := fo
	a.t = float(a.t) + t
	if a.st == "cast":
		if a.t >= 0.7:
			a.st = "wait"
			a.t = 0.0
	elif a.st == "wait":
		if a.t >= float(a.wait):
			a.fish = mx()
			a.st = "bite"
			a.t = 0.0
			_gr([30, 40, 30])
			_xh()
	elif a.st == "bite":
		if a.t >= 1.25:
			pe("Cá thoát mất rồi. Lần sau giật nhanh hơn nhé.")
	elif a.st == "reel":
		var n: Dictionary = lc[a.fish]
		var dif := float(n.dif)
		a.zv = float(a.zv) + (3.3 if a.hold else -2.5) * t
		a.zv = maxf(-1.5, minf(1.5, float(a.zv)))
		a.zc = float(a.zc) + float(a.zv) * t
		var e := float(a.zh) / 2.0
		var r := 1.0 - float(a.zh) / 2.0
		if a.zc < e:
			a.zc = e
			a.zv = absf(float(a.zv)) * 0.2
		if a.zc > r:
			a.zc = r
			a.zv = -absf(float(a.zv)) * 0.2
		a.fn = float(a.fn) - t
		if a.fn <= 0.0:
			a.ft = 0.08 + randf() * 0.84
			a.fn = _nn(0.5, 1.5) / dif
		a.fp = float(a.fp) + (float(a.ft) - float(a.fp)) * minf(1.0, t * (0.9 + 0.9 * dif))
		var o := absf(float(a.fp) - float(a.zc)) <= float(a.zh) / 2.0
		a.p = float(a.p) + t * (0.32 if o else -0.2 * sqrt(dif))
		if a.p >= 1.0:
			ge()
		elif a.p <= 0.0:
			pe("Cá giằng đứt dây mất rồi.")
		elif a.t > 28.0:
			pe("Cá quá khỏe, đành thả nó đi.")
	# lớp bọc: tự chơi đang câu
	var uf_ := _x("Ur")
	var ur = uf_.call() if uf_.is_valid() else null
	if not (ur is Dictionary) or not _tr(ur.get("on")) or ur.get("fs") != "fishing":
		return
	if a.st == "bite":
		ur.rx = float(ur.get("rx", 0)) - t
		if ur.rx <= 0.0:
			ko()
			a.hold = true
	elif a.st == "reel":
		var e2 := float(a.fp) - float(a.zc) - float(a.zv) * 0.32
		var r2 := e2 > 0.01
		if randf() < 0.04:
			r2 = not r2
		a.hold = r2
	else:
		ur.rx = _nn(0.22, 0.55)

func ye() -> String:   # yE (+ lớp bọc): chữ #fishInfo
	var t := _dh()
	var a := qo()
	var n: String
	if t.night:
		n = "Ban đêm cá trê và cá lóc dễ cắn câu."
	elif t.phase == "dawn" or t.phase == "dusk":
		n = "Lúc sáng sớm và chiều tối hay có tôm và cá chép vàng."
	else:
		n = "Ban ngày cá rô và cá chép cắn câu nhiều."
	var s := "Ao của bạn có " + str(a) + " ô nước. " + n + " Ao từ 4 ô có cá chép và tôm, từ 10 ô có cá lóc, từ 15 ô có cá chép vàng."
	if _rod() >= 2:
		s += " Cần trúc trở lên: cá lăng ở sông Vàm."
	if _rod() >= 3:
		s += " Cần mây ngồi xuồng giữa sông: cá bông lau."
	if _qs():
		s += " Mùa nước nổi: cá linh về, ốc bò lên ruộng."
	return s

func cf(t: int) -> Variant:   # cF: đồ nâng cần lên cấp t
	if t < 0 or t >= OY.size() or OY[t] == null:
		return null
	var a: Dictionary = OY[t]
	return {"xu": int(a.xu), "m": (a.m as Array).duplicate(true), "lv": int(HY[t])}

func _l9(t: Array) -> Array:   # l9
	var out := []
	for a in t:
		var n: int = int(a[1]) - int(G.mat_n(String(a[0])))
		if n > 0:
			out.append([a[0], n])
	return out

func _zh(t: Dictionary) -> void:   # zH
	G.g.coins = int(G.g.coins) - int(t.xu)
	for a in t.m:
		G.mat_add(String(a[0]), -int(a[1]))

func ff() -> void:   # fF: nâng cần câu
	var t := _rod()
	if t >= 4:
		return
	var a: Dictionary = cf(t + 1)
	if _jr() < int(a.lv):
		_ta("Lên cấp " + str(a.lv) + " mới nâng được " + String(n3[t + 1]).to_lower() + ".")
		return
	if not G.can_pay(a):
		var f := _x("L1")
		if f.is_valid():
			f.call({"mats": _l9(a.m), "xu": maxi(0, int(a.xu) - int(G.g.coins)), "why": "Nâng cần câu còn thiếu:", "go": ff})
		else:
			_ta("Chưa đủ vật liệu.")
		return
	_zh(a)
	_fi().rod = t + 1
	_ta(String(n3[t + 1]) + ": " + String(rA[t + 1]).to_lower() + ".")
	_gr(15)
	S3 = ""
	_ba()
	_xh()

func ry() -> void:   # rY: đếm cá câu cho sổ nhiệm vụ (mỗi giây)
	var f = G.g.get("fish")
	var t := int(f.get("total", 0)) if f is Dictionary else 0
	if M3 < 0:
		M3 = t
		return
	if t > M3:
		G.nv.S8("fish", t - M3)
		G.nv.OI("fish", t - M3)
	M3 = t

# ------------------------------------------------------------------ sổ làng: đã gặp
func tc() -> Dictionary:   # Tc
	var t = G.g.get("book")
	if not (t is Dictionary):
		t = {}
		G.g.book = t
	if not (t.get("seen") is Dictionary):
		t.seen = {}
	if not (t.get("obj") is Dictionary):
		t.obj = {}
	if not (t.get("tt") is Dictionary):
		t.tt = {}
	if t.has("cup") or t.has("races") or t.has("rt"):
		if _num(t.get("cup")) and float(t.cup) > 0:
			if not (G.g.get("hdn") is Dictionary):
				G.g.hdn = {}
			G.g.hdn.vd = 1
		t.erase("cup")
		t.erase("races")
		t.erase("rt")
	if _tr(t.tt.get("song")):
		t.tt.erase("song")
		if t.get("cur") == "song":
			t.erase("cur")
	if G.g.has("dua"):
		G.g.erase("dua")
	return t

func _ov(t: String) -> String:   # oV: món ẩn -> món đang hiện cùng vòng xoay
	var P: Dictionary = G.lang.Pi if G.lang != null else {}
	var a = P.get(t)
	if not (a is Dictionary) or not _tr(a.get("hide")):
		return t
	var og: Array = G.lang.C.get("og", []) if G.lang != null else []
	for e in og:
		if not _tr(e.get("hide")) and _tr(e.get("rot")):
			var r = e.rot
			var o := 0
			while _tr(r) and r != e.id and o < 5:
				if r == t:
					return String(e.id)
				var pr = P.get(r)
				r = pr.get("rot") if pr is Dictionary else null
				o += 1
	return t

func iv() -> void:   # iV: đánh dấu đã gặp (mỗi 2 giây)
	var t := tc()
	var rl: Array = WK.Rl if WK != null else []
	for e in rl:
		if _barn(String(e)) > 0:
			t.seen[e] = 1
	var f = G.g.get("fish")
	if f is Dictionary and f.get("dex") is Dictionary:
		for e in Wf:
			var d = f.dex.get(e)
			if d is Dictionary and _tr(d.get("n")):
				t.seen[e] = 1
	var P: Dictionary = G.lang.Pi if G.lang != null else {}
	for o in G.g.get("objs", []):
		if not _tr(o.get("f")):
			var n := _ov(String(o.id))
			if P.has(n):
				t.obj[n] = 1

# ------------------------------------------------------------------ lờ, lọp, giăng câu (g.lo)
func t1() -> Dictionary:   # T1
	var t = G.g.get("lo")
	if not (t is Dictionary):
		t = {}
		G.g.lo = t
	if not (t.get("own") is Dictionary):
		t.own = {}
	if not (t.get("set") is Array):
		t["set"] = []
	if not _num(t.get("n")):
		t.n = 0
	return t

func jd(t: String) -> int:   # Jd: số cái đã mua
	return int(t1().own.get(t, 0))

func qk(t: String) -> int:   # qk: số cái đang đặt
	var n := 0
	for a in t1()["set"]:
		if a.t == t:
			n += 1
	return n

func ku(t: int, a: int) -> Variant:   # KU: bẫy ở ô
	for e in t1()["set"]:
		if int(e.gx) == t and int(e.gy) == a:
			return e
	return null

static func bk(t: Dictionary) -> String:   # Bk
	return String(t.t) + "@" + str(int(t.gx)) + "," + str(int(t.gy))

func bm(t: String) -> Variant:   # Bm
	for a in t1()["set"]:
		if bk(a) == t:
			return a
	return null

func w4(t: Dictionary) -> bool:   # w4: có cá rồi
	return _now() - float(t.at) >= float(ns[t.t].ms)

func l6_ms(t: Dictionary) -> float:   # L6: ms còn lại
	return maxf(0.0, float(ns[t.t].ms) - (_now() - float(t.at)))

func ready_n() -> int:   # T1()["set"].filter(w4).length (tên tab "Lờ lọp (n)")
	var n := 0
	for a in t1()["set"]:
		if w4(a):
			n += 1
	return n

func uu(t: String) -> void:   # UU: mua bẫy
	var a: Dictionary = ns[t]
	var n := t1()
	if int(G.g.coins) < int(a.xu):
		_ta("Cần " + _sa(a.xu) + " xu.")
		return
	if jd(t) >= int(a.max):
		_ta("Có đủ " + str(a.max) + " " + String(a.n).to_lower() + " rồi.")
		return
	if t == "giang" and _o0() <= 0:
		_ta("Mở một khúc sông Vàm trước đã.")
		return
	G.g.coins = int(G.g.coins) - int(a.xu)
	n.own[t] = jd(t) + 1
	if not (n.get("hp") is Dictionary):
		n.hp = {}
	_ta("Mua thêm " + String(a.n).to_lower() + '. Bấm "Đặt" rồi chạm vào mặt nước để đặt.')
	_ba()

func fr_put(t: String, a: int, n: int) -> bool:   # fR: đặt bẫy
	var e: Dictionary = ns[t]
	var r = e.get("bait")
	var o: bool = r == null or _barn(String(r[0])) >= int(r[1])
	if r != null and o:
		G.g.barn[r[0]] = _barn(String(r[0])) - int(r[1])
	t1()["set"].append({"t": t, "gx": a, "gy": n, "at": _now(), "b": 1 if o else 0, "u": 0, "s": int(floor(randf() * 4))})
	var bs := ""
	if r != null:
		bs = (", mồi " + str(int(r[1])) + " " + _nm(String(r[0])).to_lower()) if o else ". Không có mồi nên ít cá ăn hơn"
	_ta("Đã đặt " + String(e.n).to_lower() + bs + ". Chừng " + str(_rnd(float(e.ms) / 6e4)) + " phút nữa ra thăm.")
	_ba()
	return true

func sr(t: String) -> void:   # sR: gỡ bẫy
	var a := t1()
	var n = bm(t)
	if n != null:
		a["set"].erase(n)
		_ta("Đã gỡ " + String(ns[n.t].n).to_lower() + " về.")
		_ba()

static func zu(t: Array) -> String:   # ZU: rút theo trọng số
	var a := 0.0
	for r in t:
		a += float(r[1])
	var e := randf() * a
	for n in t.size():
		e -= float(t[n][1])
		if e <= 0.0:
			return String(t[n][0])
	return String(t[0][0])

func rk(t: String) -> bool:   # Rk: thăm bẫy
	var a = bm(t)
	if a == null:
		return false
	var n: Dictionary = ns[a.t]
	if not w4(a):
		_ta(String(n.n) + " mới đặt, chừng " + str(int(ceil(l6_ms(a) / 6e4))) + " phút nữa mới có.")
		return false
	var e := _now() - float(a.at) > float(n.ms) * 4.0
	var r := []
	for d in n.c:
		if d[0] != "ca_linh" or _qs():
			r.append(d)
	if _n4():
		r = r + [["tom", 45]]
	var bait = n.get("bait")
	var o := _rnd(_nn(float(n.q[0]), float(n.q[1]))) + (0 if (_tr(a.get("b")) or bait == null) else -1) + (1 if G.night else 0) + (1 if _kx() else 0)
	if e:
		o = maxi(1, int(floor(o / 2.0)))
	var l := {}
	var c: String
	if randf() < 0.1:
		c = "Rái cá vô ăn sạch rồi, " + String(n.n).to_lower() + " trống trơn!"
	else:
		for f in maxi(1, o):
			var s := zu(r)
			l[s] = int(l.get(s, 0)) + 1
		var h := []
		var fi = G.g.get("fish")
		for d in l:
			G.g.barn[d] = _barn(d) + int(l[d])
			if fi is Dictionary and fi.get("dex") is Dictionary and fi.dex.get(d) is Dictionary:
				fi.dex[d].n = int(fi.dex[d].get("n", 0)) + int(l[d])
			h.append(str(l[d]) + " " + _nm(d).to_lower())
		c = "Thăm " + String(n.n).to_lower() + " được " + ", ".join(h) + (" (để lâu quá, cá xổng bớt)" if e else "") + (". Đêm cá ăn mạnh!" if G.night else ".")
		_no("lo", 1.0, [float(a.gx) + 0.5, float(a.gy) + 1.2])
		var hh := []
		for d in l:
			hh.append(str(l[d]) + " " + _nm(d))
		_a0(float(a.gx) + 0.5, float(a.gy) + 0.5, "+" + ", ".join(hh))
	a.u = int(a.u) + 1
	t1().n = int(t1().n) + 1
	if int(a.u) >= int(n.use):
		t1()["set"].erase(a)
		t1().own[a.t] = maxi(0, jd(String(a.t)) - 1)
		c += " " + String(n.n) + " cũ mục rồi, bỏ luôn, mua cái mới nha."
	else:
		var p = n.get("bait")
		a.at = _now()
		a.b = 0
		if p != null and _barn(String(p[0])) >= int(p[1]):
			G.g.barn[p[0]] = _barn(String(p[0])) - int(p[1])
			a.b = 1
		elif p != null:
			c += " Hết " + _nm(String(p[0])).to_lower() + " làm mồi."
	_ta(c)
	_gr(8)
	_qi("lo")
	_ba()
	return true

func gs(t: String, a: int, n: int) -> String:   # GS: lý do không đặt bẫy được ("" = được)
	var e: Dictionary = ns[t]
	if qk(t) >= jd(t):
		return ("Đặt hết " + String(e.n).to_lower() + " rồi. Mua thêm hoặc gỡ bớt.") if jd(t) else ("Chưa có " + String(e.n).to_lower() + ". Mua trước đã.")
	if ku(a, n) != null:
		return "Chỗ này đã có bẫy rồi."
	if _tr(e.get("river")) and _il(a, n) != "canal":
		return "Giăng câu phải đặt trên sông Vàm."
	return "" if _uu(a, n) else "Chỗ này xa bờ quá, lội không tới. Đặt sát mé nước (hoặc sắm xuồng ba lá)."

func nk_lo(t: String) -> void:   # Nk: nút "Đặt" -> chạm mặt nước
	var a: Dictionary = ns[t]
	if qk(t) >= jd(t):
		_ta(("Đặt hết " + String(a.n).to_lower() + " rồi. Mua thêm hoặc gỡ bớt.") if jd(t) else ("Chưa có " + String(a.n).to_lower() + ". Mua trước đã."))
		return
	var cb := func(n: int, e: int) -> bool:
		var r := gs(t, n, e)
		if r != "":
			_ta(r)
			return false
		fr_put(t, n, e)
		return true
	var sub := "Giăng câu phải đặt trên sông Vàm, sát mé bờ." if t == "giang" else "Chọn chỗ mương, ao, mé sông sát bờ để còn lội ra thăm."
	wg("lo", false, {"msg": "Chạm vào mặt nước để đặt " + String(a.n).to_lower(), "sub": sub, "at": [G.ppos.x, G.ppos.y], "cb": cb})

func hz(t: String, a: int, n: int) -> void:   # hZ: nhân vật lội ra đặt bẫy
	var e := gs(t, a, n)
	if e != "":
		_ta(e)
		return
	var r = mt(a, n)
	if r == null:
		_ta("Không có bờ để đứng chỗ này.")
		return
	var run := func() -> bool:
		var o := gs(t, a, n)
		if o != "":
			_ta(o)
			return false
		return fr_put(t, a, n)
	var gl := _x("Gl")
	if gl.is_valid():
		gl.call({"key": "lop" + t + "@" + str(a) + "," + str(n), "kind": "lo", "pos": r.stand, "dur": 0.6, "run": run})

func lo_tip(key: String):   # t_: chữ nổi khi chạm bẫy ({b, s}; null = không phải bẫy)
	var a = bm(key)
	if a == null:
		return {"b": "", "s": ""}
	var n: Dictionary = ns[a.t]
	return {"b": String(n.n), "s": ("Có cá rồi! Chạm để ra thăm." if w4(a) else "Đang chờ cá vô, chừng " + str(int(ceil(l6_ms(a) / 6e4))) + " phút nữa.") + (" Đang không có mồi." if n.get("bait") != null and not _tr(a.get("b")) else "") + " Dùng thêm " + str(int(n.use) - int(a.u)) + " lần."}

func lo_stand(key: String):   # $U: chỗ đứng thăm bẫy
	var a = bm(key)
	return [float(a.gx) + 0.5, float(a.gy) + 0.5] if a != null else null

func lo_at(x: int, y: int):   # YU (theo ô): bẫy ở ô chạm -> {type: "lo", key}
	var r = ku(x, y)
	return {"type": "lo", "key": bk(r)} if r != null else null

# ------------------------------------------------------------------ thú cưng (g.pet)
func cc() -> Dictionary:   # Cc
	var t = G.g.get("pet")
	if not (t is Dictionary):
		t = {}
		G.g.pet = t
	if not (t.get("vit") is Dictionary):
		t.vit = {"n": 0, "f": 0, "e": 0, "a": 0}
	if not (t.get("ca") is Dictionary):
		t.ca = {"n": 0, "g": 0, "f": 0}
	if not (t.get("meo") is Dictionary):
		t.meo = {"has": 0, "fd": -1, "gd": -1, "pt": 0, "tim": 0}
	if not (t.get("chim") is Dictionary):
		t.chim = {"has": 0, "fd": -1, "gi": 0, "cd": -1, "sd": -1}
	for a in ["n", "f", "e", "a"]:
		var v = t.vit.get(a)
		if not _num(v) or is_nan(float(v)) or is_inf(float(v)):
			t.vit[a] = 0
	for a in ["n", "g", "f"]:
		var v = t.ca.get(a)
		if not _num(v) or is_nan(float(v)) or is_inf(float(v)):
			t.ca[a] = 0
	return t

func dn(t: float) -> void:   # dN: vịt ăn, đẻ trứng; cá ăn, lớn (cả lúc tắt game)
	var a = G.g.get("pet")
	if not (a is Dictionary):
		return
	var n = a.get("vit")
	if n is Dictionary and float(n.get("n", 0)) > 0 and float(n.get("f", 0)) > 0:
		var e := minf(t, float(n.f))
		n.f = float(n.f) - e
		n.a = float(n.get("a", 0)) + e * float(n.n)
		while float(n.a) >= 150.0:
			n.a = float(n.a) - 150.0
			if float(n.get("e", 0)) < float(n.n) * 3:
				n.e = int(n.get("e", 0)) + 1
	var r = a.get("ca")
	if r is Dictionary and float(r.get("n", 0)) > 0 and float(r.get("f", 0)) > 0 and float(r.get("g", 0)) < Xf:
		var o := minf(t, float(r.f))
		r.f = float(r.f) - o
		r.g = minf(Xf, float(r.g) + o)

func wq() -> void:   # WQ: mèo tha quà buổi sáng (mỗi giây)
	var p = G.g.get("pet")
	var t = p.get("meo") if p is Dictionary else null
	if not (t is Dictionary) or not _tr(t.get("has")):
		return
	var a := _vr()
	if int(t.get("fd", -1)) == a - 1 and int(t.get("gd", -1)) != a and _d0() >= 6.0:
		t.gd = a
		var n: String = ["ca_ro", "ca_ro", "ca_linh", "tom", "ca_tre"][randi() % 5]
		G.g.barn[n] = _barn(n) + 1
		_wq_msg = "Sáng nay Mướp tha về 1 " + _nm(n).to_lower() + " khoe bạn. Mèo được cho ăn hôm qua nên biết trả ơn!"
		_wq_t = 3.0
		_ba()

func xx() -> bool:   # Xx: chạm đàn vịt
	var t: Dictionary = cc().vit
	if not _tr(t.n):
		return false
	if int(t.e) > 0:
		var a := int(t.e)
		t.e = 0
		var n := 0
		for e in a:
			if randf() < 0.5:
				n += 1
		G.g.barn.trung_vit = _barn("trung_vit") + a - n
		if n > 0:
			G.g.barn.thit_vit = _barn("thit_vit") + n
		var r = w2("vit")
		_a0(float(r.c[0]) if r != null else 4.5, float(r.c[1]) if r != null else -2.5, (("+" + str(a - n) + " trứng vịt") if a - n > 0 else "") + (", " if a - n > 0 and n > 0 else "") + (("+" + str(n) + " thịt vịt") if n > 0 else ""))
		_qi("vit")
		_ba()
		return true
	if float(t.f) < a6 * 0.6:
		var o := int(ceil(float(t.n) / 2.0))
		if _barn("lua") < o:
			_ta("Cần " + str(o) + " lúa để cho vịt ăn.")
			return false
		G.g.barn.lua = _barn("lua") - o
		t.f = minf(a6 * 2.0, float(t.f) + a6)
		_ta("Rải " + str(o) + " lúa cho vịt. Vịt no thì đẻ trứng đều.")
		l6 = 1.2
		_ba()
		return true
	_ta("Vịt đang no, lội ao kêu cạp cạp.")
	return true

func jx() -> bool:   # Jx: chạm ao cá nuôi
	var t: Dictionary = cc().ca
	if not _tr(t.n):
		return false
	if float(t.g) >= Xf:
		var a := maxi(1, _rnd(float(t.n) * 0.9))
		G.g.barn.ca_tra = _barn("ca_tra") + a
		t.n = 0
		t.g = 0
		t.f = 0
		var n = w2("ca")
		var e: float = float(n.c[0]) if n != null else 4.5
		var r: float = float(n.c[1]) if n != null else -2.5
		_a0(e, r, "+" + str(a) + " cá tra")
		_qi("ao")
		_ba()
		return true
	if float(t.f) < n6 * 0.6:
		if _barn("bot") < 1:
			_ta("Cần 1 bao bột (cám) cho cá ăn. Xay lúa ở cối xay.")
			return false
		G.g.barn.bot = _barn("bot") - 1
		t.f = minf(n6 * 2.0, float(t.f) + n6)
		_ta("Rải cám cho cá. Cá lớn " + str(_rnd(float(t.g) / Xf * 100.0)) + "%.")
		c6 = 1.5
		_ba()
		return true
	_ta("Cá đang ăn no, lớn " + str(_rnd(float(t.g) / Xf * 100.0)) + "%.")
	return true

func gq() -> bool:   # GQ: chạm mèo
	var t: Dictionary = cc().meo
	var a := _vr()
	if not _tr(t["has"]):
		return false
	if int(t.fd) != a:
		var n := ""
		for o in ["ca_keo", "ca_linh", "ca_ro", "ca_tre", "tom"]:
			if _barn(o) > 0:
				n = o
				break
		if n != "":
			G.g.barn[n] = _barn(n) - 1
			t.fd = a
			t.tim = mini(10, int(t.get("tim", 0)) + 1)
			_ta("Mướp ăn " + _nm(n).to_lower() + " ngon lành, dụi đầu vô chân bạn.")
			qi_hap = 3.0
			_ba()
			return true
		_ta("Mèo đói, cần 1 con cá nhỏ (cá kèo, cá rô, cá linh, cá trê) hoặc tôm.")
		return false
	var e := _now()
	if e - float(t.get("pt", 0)) > 36e5:
		t.pt = e
		var r := _pc()
		r.en = minf(G.en_max(), float(r.en) + 8.0)
		_ta("Vuốt ve Mướp, nghe nó gừ gừ thấy khỏe hẳn (+8 sức).")
		qi_hap = 3.0
		_ba()
		return true
	_ta("Mướp đang lim dim ngủ.")
	qi_hap = 2.0
	return true

func jq() -> bool:   # jQ: chạm chào mào
	var t: Dictionary = cc().chim
	var a := _vr()
	if not _tr(t["has"]):
		return false
	if int(t.fd) != a:
		var n := ""
		for e in ["qua_chuoi", "ot"]:
			if _barn(e) > 0:
				n = e
				break
		if n != "":
			G.g.barn[n] = _barn(n) - 1
			t.fd = a
			if int(t.get("sd", -1)) != a:
				t.sd = a
				t.gi = mini(10, int(t.get("gi", 0)) + 1)
			_ta("Cho chào mào ăn " + _nm(n).to_lower() + ". Giọng hót lên " + str(t.gi) + "/10.")
			rh_sing = 4.0
			_ba()
			return true
		_ta("Chào mào cần 1 trái chuối chín hoặc ớt.")
		return false
	rh_sing = 3.0
	_ta("Chào mào hót líu lo. Giọng " + str(t.gi) + "/10.")
	return true

func dq() -> void:   # DQ: đem chào mào đi thi
	var t: Dictionary = cc().chim
	var a := _vr()
	if not _tr(t["has"]) or int(t.cd) == a or int(t.gi) < 3:
		return
	t.cd = a
	var n := minf(0.85, 0.2 + int(t.gi) * 0.07)
	var e := randf() < n
	var r := _v0(150 * int(t.gi) if e else 30 * int(t.gi))
	G.g.coins = int(G.g.coins) + r
	_qi("chim")
	_ta(("Chào mào đoạt giải nhất hội thi chim làng! Thưởng " + _sa(r) + " xu.") if e else ("Chào mào hót hay nhưng chưa đoạt giải, được thưởng khuyến khích " + _sa(r) + " xu."))
	_ba()

func vq(t: String) -> void:   # VQ: nút data-pet trong tab Nuôi thêm
	var a := cc()
	var n := int(Nh.get(t, 0))
	if (t == "vit" or t == "ca" or t == "mvit" or t == "mca") and not _jg("vit"):
		return
	if t == "meo" and not _jg("meo"):
		return
	if t == "vit":
		if WC == null or not WC.YT():
			return
		if int(G.g.coins) < n:
			_ta("Cần " + _sa(n) + " xu.")
			return
		if not _tr(a.vit.n):
			wg("vit", true)
			return
		G.g.coins = int(G.g.coins) - n
		WC.T_(3)
	elif t == "ca":
		if not e6():
			_ta("Chưa có mặt nước nào trong đất của bạn.")
			return
		if int(G.g.coins) < n:
			_ta("Cần " + _sa(n) + " xu.")
			return
		wg("ca", true)
		return
	elif t == "mvit":
		wg("vit", false)
		return
	elif t == "mca":
		wg("ca", false)
		return
	elif t == "meo":
		if _tr(a.meo["has"]):
			return
		if int(G.g.coins) < n:
			_ta("Cần " + _sa(n) + " xu.")
			return
		G.g.coins = int(G.g.coins) - n
		a.meo["has"] = 1
		_ta("Bà Năm cho bạn một bé mèo mướp. Mỗi ngày cho Mướp ăn 1 con cá nhỏ, sáng hôm sau nó tha quà về.")
	elif t == "chim":
		if _tr(a.chim["has"]):
			return
		if int(_pc().lv) < 4:
			_ta("Cấp 4 mới nuôi chào mào.")
			return
		if int(G.g.coins) < n:
			_ta("Cần " + _sa(n) + " xu.")
			return
		G.g.coins = int(G.g.coins) - n
		a.chim["has"] = 1
		_ta("Treo lồng chào mào trước hiên. Mỗi ngày cho ăn chuối hoặc ớt, giọng hót lên dần rồi đem đi thi.")
	_ba()
	_ec()

func uz(t: String) -> String:   # uZ: tên việc khi chạm con vật
	var a := cc()
	if t == "vit":
		return ("Lượm " + str(a.vit.e) + " trứng vịt") if _tr(a.vit.e) else ("Rải lúa cho vịt" if float(a.vit.f) < a6 * 0.6 else "Ra thăm vịt")
	if t == "ca":
		return "Kéo lưới bắt cá" if float(a.ca.g) >= Xf else ("Rải cám cho cá" if float(a.ca.f) < n6 * 0.6 else "Ra thăm ao")
	if t == "meo":
		return "Vuốt ve" if int(a.meo.fd) == _vr() else "Cho mèo ăn"
	if t == "chim":
		return "Nghe chim hót" if int(a.chim.fd) == _vr() else "Cho chim ăn"
	return "Đi tới"

func tk(t: String) -> Variant:   # tK: chữ nổi khi chạm con vật ({b, s} hoặc null)
	var a := cc()
	if t == "vit":
		return {"b": "Đàn vịt · " + str(a.vit.n) + " con", "s": (("Có " + str(a.vit.e) + " trứng vịt, chạm để lượm. ") if _tr(a.vit.e) else "") + ("Vịt đói, chạm để rải lúa." if float(a.vit.f) < a6 * 0.6 else "Vịt đang no.")}
	if t == "ca":
		return {"b": "Cá nuôi · " + str(a.ca.n) + " con", "s": "Lớn " + str(_rnd(float(a.ca.g) / Xf * 100.0)) + "%. " + ("Chạm để kéo lưới." if float(a.ca.g) >= Xf else ("Chạm để rải cám (bột)." if float(a.ca.f) < n6 * 0.6 else "Cá đang no."))}
	if t == "meo":
		return {"b": "Mèo Mướp", "s": "Đã ăn hôm nay. Chạm để vuốt ve." if int(a.meo.fd) == _vr() else "Đói rồi, chạm để cho ăn 1 con cá nhỏ."}
	if t == "chim":
		return {"b": "Chào mào · giọng " + str(a.chim.gi) + "/10", "s": "Đã ăn hôm nay." if int(a.chim.fd) == _vr() else "Chạm để cho ăn chuối hoặc ớt."}
	return null

static func jt(t, a: float, n: float) -> Variant:   # JT: chỗ bờ gần (a, n) nhất của vùng nước t
	if t == null:
		return null
	if not t.bank.size():
		return [t.c[0], float(t.c[1]) + 0.6]
	var e = null
	var r := 1e9
	for o in t.bank:
		var l := Vector2(float(o[0]) - a, float(o[1]) - n).length()
		if l < r:
			r = l
			e = o
	return e

func pet_stand(t: String) -> Variant:   # YQ: chỗ nhân vật đứng làm việc với con vật (mèo: lớp vẽ biết chỗ Qi)
	if t == "chim":
		return [7.85 + 0.1, 4.15 + 0.5]   # Jf
	if t == "meo":
		return null   # [Qi.x + .35 * Qi.f, Qi.y + .3]: chỗ mèo do lớp vẽ giữ
	return jt(w2(t), G.ppos.x, G.ppos.y)

func pet_job(k: String) -> bool:   # $Q: việc "pet" của con vật k (Xx / Jx / GQ / jQ)
	match k:
		"vit": return xx()
		"ca": return jx()
		"meo": return gq()
		"chim": return jq()
	return false

# ------------------------------------------------------------------ chỗ thả vịt, cá
func zt() -> Variant:   # ZT: ô nước của mình gần nhà nhất (null nếu không có)
	if _zt_v == _ver() and _zt != null:
		return _zt if _zt is Array else null
	_zt_v = _ver()
	_zt = 0
	if _xx(4, -3):
		_zt = [4, -3]
		return _zt
	for t in range(1, 40):
		for a in range(-t, t + 1):
			for n in range(-t, t + 1):
				if maxi(absi(a), absi(n)) == t and _xx(6 + a, 3 + n):
					_zt = [6 + a, 3 + n]
					return _zt
	return null

func e6() -> bool:   # e6: có mặt nước trong đất của mình
	return zt() != null

func r6(t: String):   # r6: ô thả vịt / cá
	var a: Dictionary = cc()[t]
	var n = a.get("at")
	if n is Array and n.size() >= 2 and _xx(int(n[0]), int(n[1])):
		return [int(n[0]), int(n[1])]
	return zt()

func o6(t: String) -> String:   # o6: tên chỗ thả
	var a = r6(t)
	if a == null:
		return "chưa có chỗ"
	if a[0] >= 2 and a[0] <= 6 and a[1] >= -4 and a[1] <= -2:
		return "ao sen"
	if _yh(a[0], a[1]):
		return "sông Vàm"
	var n := str(a[0]) + "," + str(a[1])
	if G.lang != null:
		G.lang._a1()
		if (G.lang.a1.get(n, []) as Array).size():
			return "ao nhà"
	return "mặt nước"

func w2(t: String) -> Variant:   # w2: vùng nước của đàn (t: ô, set, bank: bờ, c: tâm)
	var a = r6(t)
	if a == null:
		return null
	var n := str(a[0]) + "," + str(a[1]) + "|" + str(_ver())
	var e = XT.get(t)
	if e is Dictionary and e.key == n:
		return e
	var r := {}
	var o := []
	var l := [a]
	var c := []
	var f := {}
	var s := []
	r[str(a[0]) + "," + str(a[1])] = 1
	while l.size() and o.size() < 24:
		var h: Array = l.pop_front()
		o.append(h)
		for v in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var x: int = h[0] + v[0]
			var k: int = h[1] + v[1]
			var M := str(x) + "," + str(k)
			if r.has(M) or absi(x - int(a[0])) > 3 or absi(k - int(a[1])) > 3:
				continue
			if _xx(x, k):
				r[M] = 1
				l.append([x, k])
	for v in o:
		for x in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var k: int = v[0] + x[0]
			var M: int = v[1] + x[1]
			var T := str(k) + "," + str(M)
			if not (r.has(T) or f.has(T) or _p0(k, M)):
				f[T] = 1
				var w := [k + 0.5 - x[0] * 0.35, M + 0.5 - x[1] * 0.35]
				if _bb(k, M):
					c.append(w)
				else:
					s.append(w)   # ll(k, M): ô còn trong khung nhìn
	var p := 0.0
	var d := 0.0
	for v in o:
		p += v[0] + 0.5
		d += v[1] + 0.5
	if not c.size():
		c = s
	e = {"key": n, "t": o, "set": r, "bank": c, "c": [p / o.size(), d / o.size()]}
	XT[t] = e
	return e

func wg(t: String, a: bool, n = null) -> void:   # wg (+ lớp bọc Jg("vit")): vào chế độ chọn chỗ thả
	if (t == "vit" or t == "ca") and not _jg("vit"):
		return
	_g2()
	yf = {"k": t, "buy": a, "cb": n.get("cb") if n is Dictionary else null,
		"msg": String(n.get("msg")) if n is Dictionary and _tr(n.get("msg")) else "Chạm vào mặt nước để thả " + ("vịt" if t == "vit" else "cá"),
		"sub": String(n.get("sub")) if n is Dictionary and _tr(n.get("sub")) else "Ô nước sáng viền vàng là chỗ thả được: ao sen, hồ, sông Vàm, ao tự đào.",
		"at": (n.get("at") if n is Dictionary else (w2(t).c if w2(t) != null else zt()))}   # camera dời tới at (lớp làng)
	if ui != null:
		ui.pick_bar()

func f6(t := false) -> void:   # f6: thôi chọn chỗ
	yf = null
	if ui != null:
		ui.pick_bar()
	if t:
		_ta("Đã hủy chọn chỗ thả.")

func nk(r: int, o: int) -> void:   # nK (theo ô): chạm mặt nước khi đang chọn chỗ
	if yf == null:
		return
	if not _p0(r, o):
		_ta("Chỗ này là đất liền. Chạm vào ô nước có viền vàng.")
		return
	if not _ci(_fo(r, o)):
		_ta("Khúc nước này chưa khai hoang.")
		return
	if yf.cb is Callable and (yf.cb as Callable).is_valid():
		var l: Callable = yf.cb
		if l.call(r, o) != false:
			f6()
		return
	var c := cc()
	var f: String = yf.k
	var s: Dictionary = c[f]
	if yf.buy:
		var h := int(Nh[f])
		if int(G.g.coins) < h:
			_ta("Cần " + _sa(h) + " xu.")
			f6()
			return
		G.g.coins = int(G.g.coins) - h
		s.at = [r, o]
		if f == "vit":
			if WC != null:
				WC.T_(3)
		elif WC != null:
			WC.hN(10)
	else:
		s.at = [r, o]
		_ta("Đã lùa " + ("đàn vịt" if f == "vit" else "cá") + " qua " + o6(f) + ".")
	XT = {}
	f6()
	_ba()

func ch() -> void:   # CH: ghi chức năng đã dùng từ bản cũ (g.cdOld, một lần)
	var g: Dictionary = G.g
	if _tr(g.get("cdv")):
		return
	var t := {}
	if g.get("quan") is Dictionary and float(g.quan.get("tot", 0)) > 0:
		t.quan = 1
	if g.get("dl") is Dictionary and float(g.dl.get("n", 0)) > 0:
		t.dulich = 1
	if _tr(g.get("hui")):
		t.hui = 1
	if g.get("lai") is Dictionary and g.lai.get("d") is Dictionary and g.lai.d.size():
		t.lai = 1
	if g.get("lang") is Dictionary and g.lang.get("fam") is Dictionary:
		for a in g.lang.fam:
			if g.lang.fam[a] is Dictionary and _tr(g.lang.fam[a].get("job")):
				t.thue = 1
	var p = g.get("pet")
	if p is Dictionary and ((p.get("vit") is Dictionary and float(p.vit.get("n", 0)) > 0) or (p.get("ca") is Dictionary and float(p.ca.get("n", 0)) > 0)):
		t.vit = 1
	g.cdOld = t
	g.cdv = 1

# ------------------------------------------------------------------ tát ao (g.tat)
func wn() -> int:   # WN: tuần
	return int(floor(_vr() / 7.0))

func am() -> bool:   # Am: tát được tuần này
	return _ci("ao") and (not (G.g.get("tat") is Dictionary) or int(G.g.tat.get("w", -1)) != wn())

func y4() -> bool:   # y4: bắt đầu tát ao (true = mở bảng)
	if not am():
		_ta("Tuần này ao vừa tát rồi, để cá con lớn đã. Tuần sau tát tiếp." if _ci("ao") else "Khai hoang khu Ao sen trước đã.")
		return false
	var n := 0
	var e = G.g.get("lang")
	if e is Dictionary and e.get("fam") is Dictionary:
		for r in e.fam:
			n += int(e.fam[r].get("tim", 0))
	ai = {"st": "tat", "t": 3.0, "time": 25.0 + mini(10, int(floor(n / 2.0))), "fish": [], "got": {}, "n": 0, "spawn": 0.4, "water": 1.0, "msgT": 0, "fx": [], "stun": 0.0,
		"msg": "Bà con đang tát nước… chuẩn bị lội xuống bùn!", "end": false}
	G.g.tat = {"w": wn()}
	_ba()
	if ui != null:
		ui.tat_open()
	return true

func qk_t() -> Array:   # QK: rút con dưới bùn
	var t := 0.0
	for e in m6:
		t += float(e[1])
	var a := randf() * t
	for n in m6.size():
		a -= float(m6[n][1])
		if a <= 0.0:
			return m6[n]
	return m6[0]

func _xs(t: String) -> void:   # xS: #tMsg
	if ai != null:
		ai.msg = t
		if ui != null:
			ui.tat_draw()

func b6(t: bool) -> void:   # b6 (+ lớp bọc vét mương ra đất sét)
	if ai == null or ai.st == "end":
		return
	ai.st = "end"
	for o in ai.got:
		G.g.barn[o] = _barn(String(o)) + int(ai.got[o])
	var a = G.g.get("pet").get("ca") if G.g.get("pet") is Dictionary else null
	var n := 0
	if a is Dictionary and _tr(a.get("n")):
		var e = r6("ca")
		if e != null and e[0] >= 2 and e[0] <= 6 and e[1] >= -4 and e[1] <= -2 and float(a.g) >= Xf * 0.5:
			n = maxi(1, _rnd(float(a.n) * 0.8 * float(a.g) / Xf))
			G.g.barn.ca_tra = _barn("ca_tra") + n
			a.n = 0
			a.g = 0
			a.f = 0
	_qi("tatao")
	_w1(5 + int(ai.n), "tat")
	_ba()
	if not t:
		_xs("Hết giờ! Bắt được " + str(ai.n) + " con" + ((", thêm " + str(n) + " cá tra nuôi trong ao") if n else "") + ". Nướng trui mời bà con xóm hay mang về hết?")
		ai.end = true   # hiện nút Nướng trui (ai.n >= 3) và Mang về hết
	# lớp bọc
	var k := 1 + int(floor(randf() * 3))
	G.g.barn.dat_set = _barn("dat_set") + k
	_ta("Vét mương được " + str(k) + " cục đất sét.")
	_ba()
	if ui != null:
		ui.tat_draw()

func kk(n: float, e: float) -> void:   # KK: chạm canvas tát ao (n, e theo khung 760 x 330)
	if ai == null or ai.st != "go":
		return
	if not (float(ai.stun) > 0.0):
		for r in range(ai.fish.size() - 1, -1, -1):
			var o: Dictionary = ai.fish[r]
			if not _tr(o.got):
				var l := Vector2(n - float(o.x), e - (float(o.y) - float(o.h))).length()
				if l < 34.0 * float(o.s[3]):
					o.got = 1
					ai.fx.append({"x": o.x, "y": float(o.y) - float(o.h), "t": 0.6, "txt": "Á! Rắn!" if o.s[0] == "ran" else "+1 " + String(o.s[2])})
					if o.s[0] == "ran":
						ai.stun = 1.6
						_gr(40)
						_xs("Chụp trúng rắn nước, giật mình buông tay!")
					else:
						ai.got[o.s[0]] = int(ai.got.get(o.s[0], 0)) + 1
						ai.n = int(ai.n) + 1
						_gr(8)
						if ui != null:
							ui.tat_draw()   # jN
					return
		ai.fx.append({"x": n, "y": e, "t": 0.4, "txt": "Hụt!"})

func dn_tat(dt: float) -> void:   # DN: bước tát ao (mỗi khung hình khi bảng mở)
	if ai == null:
		return
	var a := minf(0.05, dt)
	if ai.st == "tat":
		ai.t = float(ai.t) - a
		ai.water = maxf(0.0, float(ai.t) / 3.0)
		if ai.t <= 0.0:
			ai.st = "go"
			_xs("Nước cạn rồi! Chạm vào cá đang quẫy để chụp, coi chừng rắn nước.")
	elif ai.st == "go":
		ai.time = float(ai.time) - a
		ai.stun = maxf(0.0, float(ai.stun) - a)
		ai.spawn = float(ai.spawn) - a
		if ai.spawn <= 0.0:
			ai.spawn = _nn(0.35, 0.8)
			var n := qk_t()
			ai.fish.append({"s": n, "x": _nn(70, 690), "y": _nn(150, 300), "life": _nn(0.9, 1.5) * (0.8 if n[0] == "ca_loc" else 1.0), "t": 0.0, "h": 0.0, "face": 1 if randf() < 0.5 else -1, "got": 0})
		if ai.time <= 0.0:
			b6(false)
	if ai == null:
		return
	for e in ai.fish:
		e.t = float(e.t) + a
		var r := float(e.t) / float(e.life)
		e.h = sin(minf(1.0, r) * PI) * 36.0 * float(e.s[3])
	ai.fish = ai.fish.filter(func(e): return float(e.t) < float(e.life) and not _tr(e.got))
	for e in ai.fx:
		e.t = float(e.t) - a
	ai.fx = ai.fx.filter(func(e): return float(e.t) > 0.0)

func ys() -> void:   # yS: đóng bảng tát ao
	if ai == null:
		return
	if ai.st != "end":
		b6(true)
	ai = null
	if ui != null:
		ui.tat_close()
	_ba()

func uk() -> void:   # UK: nướng trui mời xóm
	if ai == null or int(ai.n) < 3:
		return
	var t := 3
	for l in ["ca_loc", "ca_chep", "ca_tre", "ca_ro", "tom"]:
		while t > 0 and int(ai.got.get(l, 0)) > 0 and _barn(l) > 0:
			ai.got[l] = int(ai.got[l]) - 1
			G.g.barn[l] = _barn(l) - 1
			t -= 1
	var n = G.g.get("lang")
	var e := 0
	if n is Dictionary and n.get("fam") is Dictionary:
		for r in n.fam:
			var o: Dictionary = n.fam[r]
			if int(o.get("tim", 0)) < 5:
				o.tim = int(o.get("tim", 0)) + 1
				e += 1
	_ta("Rơm rạ un lửa, cá lóc nướng trui cuốn bánh tráng rau sống chấm mắm me. Cả xóm ăn vui" + ((", " + str(e) + " nhà thân thêm 1 ♥") if e else "") + "!")
	_gr([10, 30, 10])
	_ba()
	ys()

# ------------------------------------------------------------------ thả diều (g.dieu)
func fh() -> Dictionary:   # Fh
	var t = G.g.get("dieu")
	if not (t is Dictionary):
		t = {"has": {}, "cur": null, "on": 0, "cup": 0, "td": -1}
		G.g.dieu = t
	if not (t.get("has") is Dictionary):
		t["has"] = {}
	return t

func xk(t) -> Dictionary:   # xk
	for a in k4:
		if a.id == t:
			return a
	return k4[0]

func cg() -> bool:   # Cg: đang có gió thả diều
	var xi: int = G.season()
	var w: String = String(G.troi.wx())
	if w == "":
		w = "nang"
	return (xi == 3 or xi == 0) and not G.night and _d0() >= 14.0 and _d0() < 18.5 and w != "mua" and w != "giong"

func v1() -> int:   # v1
	return mini(4, int(floor(float(G.g.get("delivered", 0)) / 2.0)))

func cu(t: String) -> void:   # cU: làm diều
	var a := xk(t)
	var n := fh()
	if _tr(n["has"].get(t)):
		return
	if int(_pc().lv) < int(a.lv):
		_ta("Cấp " + str(a.lv) + " mới làm được " + String(a.n).to_lower() + ".")
		return
	if int(G.g.coins) < int(a.xu):
		_ta("Cần " + _sa(a.xu) + " xu mua giấy, tre, chỉ.")
		return
	G.g.coins = int(G.g.coins) - int(a.xu)
	n["has"][t] = 1
	n.cur = t
	_ta("Chuốt tre, dán giấy làm xong " + String(a.n).to_lower() + ". Chiều mùa gió (đông, xuân, 14–18 giờ) đem ra thả.")
	_ba()

func pick_kite(t: String) -> void:   # data-kite: chọn diều
	fh().cur = t
	_ba()

func fu() -> void:   # fU: thả / thu diều
	var t := fh()
	if not _tr(t.cur):
		_ta("Chưa có con diều nào.")
		return
	if not _tr(t.on) and not cg():
		_ta("Trời đang lặng gió. Chiều mùa khô, mùa xuân (14–18 giờ) mới có gió chướng thả diều.")
		return
	t.on = 0 if _tr(t.on) else 1
	_ta(("Nhân vật thả " + String(xk(t.cur).n).to_lower() + " lên trời, gió chướng lồng lộng!") if _tr(t.on) else "Cuốn dây thu diều về.")
	_ba()

func du() -> void:   # dU: thi diều
	var t := fh()
	if not _tr(t.cur):
		_ta("Làm một con diều trước đã.")
		return
	if not cg():
		_ta("Thi diều chỉ có chiều mùa gió (đông, xuân, 14–18 giờ).")
		return
	if int(t.td) == _vr():
		_ta("Hôm nay thi rồi, mai thi tiếp nha.")
		return
	_g2()
	var riv := []
	for l in [_nn(9, 16), _nn(9, 16), _nn(10, 17)]:
		riv.append(_rnd(l * 10.0) / 10.0)
	zi = {"st": "cd", "t": 2.5, "time": 25.0, "y": 0.7, "vy": 0.0, "hold": false, "band": 0.45, "bv": 0.0, "score": 0.0, "gust": 0.0, "gv": 0.0, "riv": riv,
		"msg": "Nhấn giữ nút Kéo dây cho diều lên, buông ra cho diều hạ. Giữ diều trong vùng gió xanh càng lâu càng tốt!", "done": false}
	t.td = _vr()
	_ba()
	if ui != null:
		ui.kite_open()

func kite_hold(h: bool) -> void:   # pointerdown / pointerup nút Kéo dây, phím cách
	if zi != null:
		zi.hold = h

func zn(dt: float) -> void:   # ZN: bước thi diều (mỗi khung hình khi bảng mở)
	if zi == null:
		return
	var a := minf(0.05, dt)
	if zi.st == "cd":
		zi.t = float(zi.t) - a
		if zi.t <= 0.0:
			zi.st = "go"
	elif zi.st == "go":
		zi.time = float(zi.time) - a
		zi.gust = float(zi.gust) - a
		if zi.gust <= 0.0:
			zi.gust = _nn(0.8, 2.0)
			zi.gv = _nn(-0.35, 0.35)
		zi.vy = float(zi.vy) + ((-0.9 if zi.hold else 0.55) + float(zi.gv)) * a
		zi.vy = float(zi.vy) * 0.96
		zi.y = maxf(0.05, minf(0.95, float(zi.y) + float(zi.vy) * a))
		if zi.y <= 0.05 or zi.y >= 0.95:
			zi.vy = 0.0
		zi.bv = float(zi.bv) + _nn(-0.6, 0.6) * a
		zi.bv = float(zi.bv) * 0.98
		zi.band = maxf(0.2, minf(0.75, float(zi.band) + float(zi.bv) * a * 0.6))
		if absf(float(zi.y) - (float(zi.band) + 0.06)) < 0.09:
			zi.score = float(zi.score) + a
		if zi.time <= 0.0:
			pu()

func pu() -> void:   # pU: hết giờ thi diều
	zi.st = "end"
	var t := fh()
	var a := _rnd(float(zi.score) * 10.0) / 10.0
	var n := -INF
	for v in zi.riv:
		n = maxf(n, float(v))
	var e := a > n
	var r := _v0(_rnd(800.0 * (1.0 + v1() * 0.5) if e else a * 20.0))
	G.g.coins = int(G.g.coins) + r
	if e:
		t.cup = int(t.get("cup", 0)) + 1
		if not _tr(t["has"].get("en")):
			t["has"].en = 1
	_qi("dieu")
	_ba()
	zi.msg = ("Thắng rồi! Diều bạn giữ gió " + _sv(a) + " giây, hơn hết tụi nhỏ. Thưởng " + _sa(r) + " xu" + (" và tặng diều cánh én" if int(t.cup) == 1 else "") + "!") if e else ("Diều bạn giữ gió " + _sv(a) + " giây, thằng Tèo giữ " + _sv(n) + " giây. Được " + _sa(r) + " xu, mai thi tiếp!")
	zi.done = true   # nút Kéo dây thành "Xong" (data-kd)
	if ui != null:
		ui.kite_draw()

func as_close() -> void:   # AS: đóng bảng thi diều
	if zi == null:
		return
	zi = null
	if ui != null:
		ui.kite_close()
	_ba()

# ------------------------------------------------------------------ mỗi lượt
func step(t: float, offline: bool) -> void:
	dn(t)   # dN: trong bước luật chính (cả lúc tắt game)
	if offline:
		return
	ch()   # CH (ui capdo.step)
	l6 = maxf(0.0, l6 - t)   # KQ
	c6 = maxf(0.0, c6 - t)
	qi_hap = maxf(0.0, qi_hap - t)   # ZQ
	rh_sing = maxf(0.0, rh_sing - t)
	if _wq_t > 0.0:
		_wq_t -= t
		if _wq_t <= 0.0 and _wq_msg != "":
			_ta(_wq_msg)
			_wq_msg = ""
	_ds -= t
	if _ds <= 0.0:   # dS: mỗi giây
		_ds = 1.0
		wq()
	_ul -= t
	if _ul <= 0.0:   # UL (ui nv.step): mỗi giây
		_ul = 1.0
		ry()
	_ht -= t
	if _ht <= 0.0:   # hT (fV): mỗi 2 giây
		_ht = 2.0
		iv()
	if on_fish:   # _O: rAF khi tab câu mở
		ve(minf(0.05, maxf(0.001, t)))
		if ui != null:
			ui.xh()
	if ai != null:   # DN
		dn_tat(t)
	if zi != null:   # ZN
		zn(t)
