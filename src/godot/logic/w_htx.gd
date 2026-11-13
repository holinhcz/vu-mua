extends RefCounted
# HỢP TÁC XÃ, HỘI ĐÌNH, HỤI, LỄ HỘI, QUÁN, Y TẾ, SEN ĐỎ, CÁC HỆ NHỎ: luật bản web còn thiếu ở bản Godot, chép 1:1.
#   hợp tác xã g.hx (Io, AL, I2, Rf, m9, Ru, sI, uI, ed, Nu, F2, PL, b9, _J, pI, JJ, w8, v9, tY (đếm), nvHasHx, _l);
#     phần mạng (_i.mem, _i.xas, _i.loaded, dr.uid, Ll) để trong I / ext: chưa nối mạng thì xã trống, _l() = false.
#   hội đình g.hdn / g.hc (hdnS, hdnToday, hdnAtt, hdnPillTxt, hdnFill, hdnStart, Zb, Fm, ER, CR, L2),
#   hụi g.hui (y6, Pm, JK, mk, vk, QN, UN; KN ở w_lang.gd hui_ky; bảng x6 / x4 ở w_htx_ui.gd),
#   lễ hội g.fest / g.festn / g.festh (Mm, Jb, WT, x2, xQ, kQ, h4, eN, Tm, p4, DT, Dx, jT, VT, yQ; nút viên bQ ở UI),
#   quán g.quan (Yd, Dk), cơm g.com (n5), y tế g.yte (cC), chợ phiên g.cp (Lf), du lịch g.dl (R6), g.vm (Wm),
#   hội thi g.thi (Jm), sen đỏ g.ng ($0), sổ khách g.gb (iS), thưởng xếp hạng g.rkw (bR), rầy g.ray (rc),
#   vật liệu g.mat (PH), sao chuồng g.penst (u3), quán cà phê g.cafe (N), tạp hóa g.tap (x),
#   đổi nhịp Hay Day g.hdv (SH, TH, _7, fJ).
# Vẽ cờ hội đình (hdnItems), đèn lồng lễ (rN), hạt bay xu (Ol), âm thanh (Jt): không chép.

const NV = preload("res://logic/nv.gd")

signal render              # kn(): bảng đang mở dựng lại (w_htx_ui.gd nghe)

var G
var WL = null              # w_lang.gd (bộ ráp gán): _r0, ut_houses, htv, k_s, hui_ky
var WC = null              # w_cho.gd (bộ ráp gán): yu, s2, v1, ho
var WS = null              # w_sys.gd (bộ ráp gán): mR, j5
var WX = null              # w_xuong.gd (bộ ráp gán): UJ
var ui = null              # w_htx_ui.gd (tự gán khi tạo)
# ext: việc của hệ khác (bộ ráp gán Callable theo tên web)
#   Ll() -> bool            (Ll: dr.st == "ok" && dr.db && !Cr; thiếu = chưa nối mạng)
#   Nu() -> String          (Nu: dr.uid)
#   fI(), k3(), Zl()        (đồng bộ xã trên mạng trong bước "htx")
#   z6() -> Dictionary      (z6: đình làng đã xây trên bản đồ {gx, gy, fw, fd, ...}; null = chưa có)
#   Cr() -> bool, Mt_mode() -> String, qc() -> String
#   ui_x4()                 (Ih && x4(): bảng hụi đang mở thì dựng lại; w_htx_ui tự nghe render nên không bắt buộc)
var ext := {}

# _i của bản web (xã trên mạng): mem = thành viên các xã, xas = danh sách xã, loaded, dirty (Rf)
var I := {"mem": [], "xas": [], "loaded": false, "dirty": false}

const D9 := 90             # d9: giây bớt cho mỗi người giúp
const _D := 6              # _d: số phần một dây hụi
const VN := 12             # VN: giờ mỗi kỳ hụi
const GI := [{"ng": 10, "xu": 1000}, {"ng": 6, "xu": 600}, {"ng": 4, "xu": 300}]   # gI (sinh từ web_all.js)
const LJ := {"ga": 20, "cuu": 40, "bo": 70, "heo": 100, "de": 55}   # lJ (sinh từ web_all.js)
const CJ := {"ft_chuoi": 7200, "ft_dudu": 9000, "ft_nhan": 10800, "ft_chomchom": 12000, "ft_xoai": 14400, "ft_thanhlong": 13200, "ft_mit": 18000, "ft_buoi": 16800, "ft_mangcut": 19200, "ft_saurieng": 28800, "ft_dua": 12600, "ft_dieu": 11400}   # cJ (sinh từ web_all.js)

var G9 := []               # g9: mốc điểm cấp công trình xã
var LL := []               # LL: rương quà xã
var XU := []               # xu: 4 lễ (le_hoi.json)
var HDNG := {}             # HDNG
var HDNO := []             # HDNO
var HDNRES := []           # HDNRES
var U7 := {}               # U7
var OL := {}               # ol: giống lai
var TV := {}               # Tv: thời gian gốc món xưởng

var KT := 0.0              # KT (yQ)
var TS := 0.0              # TS (bước "hui")
var ZL := 0.0              # zL (bước "htx")
var UE := 0.0              # UE (bước "hayday")

func _init(game) -> void:
	G = game
	G9 = _ja("khac/g9")
	LL = _ja("khac/LL")
	XU = _ja("le_hoi/le_hoi")
	HDNG = _jd("hoi_dinh/giai")
	HDNO = _ja("hoi_dinh/thu_tu_giai")
	HDNRES = _ja("hoi_dinh/le_vat")
	U7 = _jd("nong_trai/gia_ban_si_cay")
	OL = _jd("nong_trai/giong_lai")
	TV = _jd("che_bien/cong_thuc_thoi_gian_goc")

# ------------------------------------------------------------------ tiện ích chung (như w_lang.gd)
func _jd(p: String) -> Dictionary:   # G._j (Dictionary)
	var v = G._j(p)
	return v if v is Dictionary else {}

func _ja(p: String) -> Array:   # G._j (Array)
	var v = G._j(p)
	return v if v is Array else []

func _x(k: String) -> Callable:
	var c = ext.get(k)
	return c if c is Callable and (c as Callable).is_valid() else Callable()

static func _tr(v) -> bool:   # độ "thật" kiểu JS
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT:
			return v != 0
		TYPE_FLOAT:
			return v != 0.0 and not is_nan(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return String(v) != ""
	return true

static func _num(v) -> bool:   # typeof x == "number"
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT

static func _n(v) -> float:   # x || 0
	return float(v) if _num(v) else 0.0

static func _i(v) -> int:   # x | 0
	return int(v) if _num(v) else 0

static func _ks(u) -> String:   # khóa đối tượng JS
	if _num(u):
		return str(int(u))
	return String(u)

static func _rnd(x: float) -> int:   # Math.round
	return int(floor(x + 0.5))

static func _ns(v: float) -> String:   # số in như JS (nguyên thì không có ".0")
	if v == floor(v):
		return str(int(v))
	return str(v)

static func _okeys(d: Dictionary) -> Array:   # Object.keys: khóa số tăng dần trước, rồi khóa chữ theo thứ tự thêm
	var a := []
	var b := []
	for k in d:
		var s := String(k) if typeof(k) == TYPE_STRING else _ks(k)
		if s.is_valid_int() and not s.begins_with("-") and (s == "0" or not s.begins_with("0")):
			a.append(s)
		else:
			b.append(s)
	a.sort_custom(func(p, q): return int(p) < int(q))
	return a + b

func _ta(s: String) -> void:   # ta / pn
	G.toast.emit(s)

func _ba() -> void:   # Ba
	G.mark()

func _kn() -> void:   # kn: dựng lại bảng
	render.emit()
	G.mark()

func _gr(ms) -> void:   # gr
	G.vib(ms)

func _later(s: float, f: Callable) -> void:   # setTimeout
	G.get_tree().create_timer(s).timeout.connect(f)

func _vr() -> int:   # vr
	return G.day()

func _d0() -> float:   # d0
	return G.nv.hour()

func _jr() -> int:   # jr
	return G.lv()

func _now() -> float:   # Date.now()
	return G._now_ms()

func _fr() -> Dictionary:   # fr: g.pc
	return G.g.pc

func _ae(t) -> Dictionary:   # ae ({} = không có)
	if t == null:
		return {}
	return G.item(String(t))

func _sa(v) -> String:   # Sa
	return G.fmt_n(float(v))

func _v0(t: float) -> int:   # v0
	return G.nv.v0(t)

func _x0(n: int) -> void:   # x0
	G.nv.x0(n)

func _v1() -> int:   # v1
	if WC != null:
		return int(WC.v1())
	return mini(4, int(floor(_n(G.g.get("delivered", 0)) / 2.0)))

func _ho(t: String, a: int) -> String:   # ho
	if WC != null:
		return WC.ho(t, a)
	return str(a) + " " + String(_ae(t).get("name", t)).to_lower()

func _mode() -> String:   # Mt.mode
	var f := _x("Mt_mode")
	return String(f.call()) if f.is_valid() else "off"

func _cr() -> bool:   # Cr
	var f := _x("Cr")
	return bool(f.call()) if f.is_valid() else false

func _barn(t) -> int:   # g.barn[t] || 0
	return _i(G.g.barn.get(String(t), 0))

func _lang():   # g.lang (null nếu chưa có)
	var L = G.g.get("lang")
	return L if L is Dictionary else null

func _fam_of(u) -> Variant:   # g.lang && g.lang.fam[u]
	var L = _lang()
	if L == null or not (L.get("fam") is Dictionary):
		return null
	var f = L.fam.get(_ks(u))
	return f if f is Dictionary else null

static func _eqn(v, n) -> bool:   # v === n (số trong JSON đọc ra là float)
	return _num(v) and float(v) == float(n)

# ================================================================== HỢP TÁC XÃ (g.hx)
func _l() -> bool:   # _l
	var f := _x("Ll")
	return bool(f.call()) if f.is_valid() else false

func nu() -> String:   # Nu: dr.uid
	var f := _x("Nu")
	return String(f.call()) if f.is_valid() else ""

func rf() -> void:   # Rf
	I.dirty = true

func io() -> Dictionary:   # Io
	var t = G.g.get("hx")
	if not _tr(t) or not (t is Dictionary):
		t = {"x": "", "c": {}, "rq": [], "hp": {"d": 0, "l": []}, "g": [], "wk": {"w": 0, "p": 0}, "wkp": {"w": 0, "p": 0}, "got": {}, "gc": {}, "paidW": 0}
		G.g.hx = t
	for a in ["c", "got", "gc"]:
		if not _tr(t.get(a)) or not (t[a] is Dictionary):
			t[a] = {}
	if not (t.get("rq") is Array):
		t.rq = []
	if not (t.get("g") is Array):
		t.g = []
	if not _tr(t.get("hp")):
		t.hp = {"d": 0, "l": []}
	if not _tr(t.get("wk")):
		t.wk = {"w": 0, "p": 0}
	if not _tr(t.get("wkp")):
		t.wkp = {"w": 0, "p": 0}
	return t

func i2(t := 0.0) -> int:   # I2: tuần địa phương (bắt đầu thứ Hai)
	var a: float = (t if t != 0.0 else _now()) / 864e5 + float(G.nv._bias()) / 1440.0   # - getTimezoneOffset()/1440
	return int(floor((a + 3.0) / 7.0))

func al() -> void:   # AL
	var t := io()
	var a := i2()
	if not _eqn(t.wk.get("w"), a):
		if _tr(t.wk.get("w")):
			t.wkp = {"w": t.wk.w, "p": _i(t.wk.get("p"))}
		t.wk = {"w": a, "p": 0}
		rf()

func m9(t: int) -> void:   # m9: cộng điểm thi đua tuần cho xã
	var a = G.g.get("hx")
	if not _tr(a) or not _tr(a.get("x")) or not t:
		return
	al()
	a.wk.p = _i(a.wk.get("p")) + t
	rf()

func ed(t = null) -> Array:   # ed: thành viên xã t (mặc định xã mình), có cả "Bạn"
	if t == null:
		t = io().x
	if not _tr(t):
		return []
	var a := nu()
	var n := []
	for r in I.mem:
		if r.get("x") == t and r.get("id") != a:
			n.append(r)
	var e := io()
	if e.x == t:
		n.append({"id": a, "x": t, "n": "Bạn", "lv": _jr(), "t": _now(), "c": e.c, "rq": e.rq, "hp": e.hp.l, "g": e.g, "wk": e.wk, "wkp": e.wkp, "me": 1})
	return n

func f2(t) -> Variant:   # F2: xã có mã t (null = không có)
	for a in I.xas:
		if a.get("id") == t:
			return a
	return null

static func pl(t: Dictionary, a: int) -> int:   # PL: điểm tuần a
	var wk = t.get("wk")
	if _tr(wk) and _eqn(wk.get("w"), a):
		return _i(wk.get("p"))
	var wkp = t.get("wkp")
	if _tr(wkp) and _eqn(wkp.get("w"), a):
		return _i(wkp.get("p"))
	return 0

func b9(t: int) -> Array:   # b9: bảng thi đua các xã tuần t
	var a := {}
	for e in I.mem:
		if not _tr(e.get("x")) or e.get("id") == nu():
			continue
		a[e.x] = _i(a.get(e.x)) + pl(e, t)
	var n := io()
	if _tr(n.x):
		a[n.x] = _i(a.get(n.x)) + pl({"wk": n.wk, "wkp": n.wkp}, t)
	var out := []
	for e in _okeys(a):
		var r = f2(e)
		out.append({"x": e, "n": r.n if r != null else "Hợp tác xã", "ic": r.ic if r != null else 0, "p": a[e], "cnt": ed(e).size()})
	out = out.filter(func(e): return f2(e.x) != null)
	_stable_sort(out, func(e, r): return int(r.p) - int(e.p))
	return out

static func _stable_sort(arr: Array, cmp: Callable) -> void:   # Array.sort của JS (ổn định)
	var idx := []
	for i in arr.size():
		idx.append([arr[i], i])
	idx.sort_custom(func(p, q):
		var c: int = cmp.call(p[0], q[0])
		return c < 0 or (c == 0 and p[1] < q[1]))
	for i in idx.size():
		arr[i] = idx[i][0]

func s_i(t, a: String) -> float:   # sI: tổng đóng góp loại a của xã t
	var n := 0.0
	for e in ed(t):
		var c = e.get("c")
		n += maxf(0.0, float(c.get(a)) if _tr(c) and _num(c.get(a)) else 0.0)
	return n

func u_i(t: float) -> int:   # uI: bậc theo mốc g9
	var a := 0
	for n in range(1, G9.size()):
		if t >= float(G9[n]):
			a = n
	return a

func ru(t: String) -> int:   # Ru: bậc công trình xã t (dinh | cho | ben)
	var a = G.g.get("hx")
	return 0 if not _tr(a) or not _tr(a.get("x")) or not _l() else u_i(s_i(a.x, t))

func _j_(t) -> int:   # _J: số người trong xã đã giúp yêu cầu t của mình
	var a := nu()
	var n := 0
	var e := {}
	for r in ed():
		if _tr(r.get("me")):
			continue
		for o in r.get("hp", []):
			if o is Array and o.size() > 1 and o[0] == a and o[1] == t and not e.has(r.id):
				e[r.id] = 1
				n += 1
	return n

func _uj(e: Dictionary) -> bool:   # UJ
	return bool(WX.UJ(e)) if WX != null else false

func p_i() -> void:   # pI: nhận phần giúp của bà con trong xã
	var t = G.g.get("hx")
	if not _tr(t) or not _tr(t.get("x")):
		return
	var a := false
	for e in t.rq:
		var r := mini(int(e.n), _j_(e.id))
		var o := r - _i(t.got.get(e.id))
		if o <= 0:
			continue
		t.got[e.id] = r
		a = true
		var l := float(D9 * o)
		if e.k == "w":
			var c = G.g.work.get(e.key) if G.g.get("work") is Dictionary else null
			if _tr(c) and c.q.size():
				c.p = float(c.p) + l
		elif e.k == "p":
			var f: Dictionary = G.vn.Q[e.key]
			var pens = G.g.get("pens")
			for s in (pens.get(e.key, []) if pens is Dictionary else []):
				if not _tr(s.get("b")) and not _tr(s.get("s")) and float(s.p) >= 0.0 and float(s.p) < float(f.time):
					s.p = minf(float(f.time), float(s.p) + l)
		elif e.k == "r":
			for s in G.g.plots:
				if _tr(s.get("u")) and _tr(s.get("c")) and not G.ripe(s):
					s.g = minf(float(G.crop(String(s.c)).time), float(s.g) + l)
		_ta(str(o) + " người trong xã vừa giúp " + String(e.lb).to_lower() + ", bớt " + NV.ao(l) + ".")
	var n: int = t.rq.size()
	t.rq = t.rq.filter(func(e): return _uj(e) and _i(t.got.get(e.id)) < int(e.n))
	if t.rq.size() != n or a:
		rf()
		_kn()
		_ba()

func jj() -> void:   # JJ: thưởng thi đua tuần trước
	var t = G.g.get("hx")
	if not _tr(t) or not _tr(t.get("x")) or not _tr(I.loaded):
		return
	al()
	var a := i2() - 1
	if _num(t.get("paidW")) and float(t.paidW) >= float(a):
		return
	t.paidW = a
	if (_n(t.wkp.get("p")) if _eqn(t.wkp.get("w"), a) else 0.0) < 10.0:
		_ba()
		return
	var n := b9(a)
	var e := -1
	for i in n.size():
		if n[i].x == t.x:
			e = i
			break
	if e < 0 or n.size() < 2:
		_ba()
		return
	var r: Dictionary = GI[e] if e < GI.size() else {"ng": 1, "xu": 100}
	_x0(int(r.ng))
	G.g.coins = _n(G.g.coins) + _v0(float(r.xu))
	if e == 0:
		t.cup = a
	_ta("Thi đua tuần trước: xã bạn hạng " + str(e + 1) + "/" + str(n.size()) + "! Nhận " + str(r.ng) + " sen đỏ, " + _sa(_v0(float(r.xu))) + " xu" + (" và cờ thi đua treo ở đình" if e == 0 else "") + ".")
	_kn()
	_ba()

func w8() -> Array:   # w8: yêu cầu giúp của bà con trong xã mà mình chưa giúp
	var t := nu()
	var a := io()
	var n: int = G.nv.Ao()
	var e: Array = a.hp.l if _eqn(a.hp.get("d"), n) else []
	var r := []
	for o in ed():
		if _tr(o.get("me")):
			continue
		for l in o.get("rq", []):
			if not _tr(l) or not _tr(l.get("id")):
				continue
			var c := false
			for s in e:
				if s[0] == o.id and s[1] == l.id:
					c = true
					break
			var f := 0
			for s in I.mem:
				if s.get("x") == a.x:
					for h in s.get("hp", []):
						if h[0] == o.id and h[1] == l.id:
							f += 1
							break
			var need := _i(l.get("n")) if _i(l.get("n")) else 1
			var t0 := float(l.t0) if _num(l.get("t0")) else (str(l.get("t0")).to_float() if str(l.get("t0")).is_valid_float() else 0.0)   # +l.t0 || 0
			if not c and f < need and _now() - t0 < 3 * 36e5:
				r.append({"m": o, "r": l, "helped": f})
	return r

func v9() -> Array:   # v9: quà xã chưa nhận (3 ngày)
	var t := io()
	var a := []
	for n in ed():
		if _tr(n.get("me")):
			continue
		for e in n.get("g", []):
			if not _tr(e):
				continue
			var v := _i(e.get("v"))
			var tt := float(e.t) if _num(e.get("t")) else 0.0
			if v < 0 or v >= LL.size() or not _tr(LL[v]) or _now() - tt > 3 * 864e5:
				continue
			var r: String = str(n.id) + ":" + str(e.id)
			if not _tr(t.gc.get(r)):
				a.append({"m": n, "g": e, "key": r})
	return a

func htx_badge() -> int:   # tY: số trên huy hiệu #htxBdg (0 = ẩn)
	var a = G.g.get("hx")
	return w8().size() + v9().size() if _tr(a) and _tr(a.get("x")) and _l() else 0

func nv_has_hx() -> bool:   # nvHasHx
	return _l() and _tr(G.g.get("hx")) and _tr(G.g.hx.get("x"))

func htx_step(t: float) -> void:   # ui({id: "htx"}).step
	ZL -= t
	if ZL > 0:
		return
	ZL = 1
	if _l():
		var fi := _x("fI")
		if fi.is_valid():
			fi.call()
		var hx = G.g.get("hx")
		if _tr(hx) and _tr(hx.get("x")):
			al()
			p_i()
			jj()
		var k3 := _x("k3")
		if k3.is_valid():
			k3.call()
	# tY(): huy hiệu do UI đọc htx_badge()
	var zl := _x("Zl")
	if zl.is_valid():
		zl.call()

# ================================================================== HỘI ĐÌNH (g.hdn, g.hc)
func zb(t: Dictionary) -> String:   # Zb: lý do chưa mở món mặc (áo, nón)
	var a := _fr()
	if _tr(t.get("lv")) and int(a.lv) < int(t.lv):
		return "Cấp " + str(t.lv)
	if _tr(t.get("streak")) and not _tr(a.get("tet")):
		return "Chuỗi 7 ngày Việc hôm nay"
	if _tr(t.get("hoi")) and not (_tr(G.g.get("hdn")) and _tr(G.g.hdn.get("vd"))):
		return "Giải nhất hội đình"
	return ""

func hdn_s() -> Dictionary:   # hdnS
	var o = G.g.get("hdn")
	if not _tr(o) or not (o is Dictionary):
		o = {}
		G.g.hdn = o
	if not _tr(o.get("m")) or not (o.m is Dictionary):
		o.m = {}
	if not (o.get("log") is Array):
		o.log = []
	# 09/11: bỏ giải đua ghe khỏi hội đang mở và sổ hội
	if not _tr(o.get("v2")):
		o.v2 = 1
		if _tr(o.get("cur")) and _tr(o.cur.get("giai")):
			o.cur.giai = o.cur.giai.filter(func(id): return _tr(HDNG.get(String(id))))
		for r in o.log:
			if _tr(r.get("g")):
				r.g.erase("ghe")
	# 09/11: hội đang lo thêm rượu nếp vào lễ vật
	if _tr(o.get("cur")) and _tr(o.cur.get("need")) and o.cur.need.get("ruou_nep") == null:
		o.cur.need.ruou_nep = 4 if _tr(o.cur.get("big")) else 2
		o.cur.got.ruou_nep = 0
		o.cur.me.ruou_nep = 0
	# 09/11: bỏ giải chọi trâu
	if not _tr(o.get("v3")):
		o.v3 = 1
		if _tr(o.get("cur")):
			if _tr(o.cur.get("giai")):
				o.cur.giai = o.cur.giai.filter(func(id): return _tr(HDNG.get(String(id))))
				if not o.cur.giai.size():
					o.cur.giai = HDNO.duplicate()
			if _tr(o.cur.get("g")):
				o.cur.g.erase("trau")
		for r in o.log:
			if _tr(r.get("g")):
				r.g.erase("trau")
	return o

func _hdn_cur():   # g.hdn && g.hdn.cur
	var h = G.g.get("hdn")
	return h.get("cur") if h is Dictionary and _tr(h.get("cur")) else null

func hdn_today() -> bool:   # hdnToday
	var cu = _hdn_cur()
	return cu != null and _vr() == int(cu.d)

func hdn_att(uu) -> bool:   # hdnAtt: nhà uu có tới dự hội hôm nay
	var cu = _hdn_cur()
	return cu != null and _tr(cu.get("att")) and _vr() == int(cu.d) and cu.att.has(_ks(uu))

func hdn_pill_txt() -> Variant:   # hdnPillTxt: [chữ, 1 = hôm nay] hoặc null
	var cu = _hdn_cur()
	if cu == null:
		return null
	var left := int(cu.d) - _vr()
	if left > 0:
		return ["Hội đình còn " + str(left) + " ngày · chuẩn bị", 0]
	if left == 0:
		return ["Hôm nay hội đình · vào thi", 1]
	return null

func hdn_fill(cu: Dictionary) -> float:   # hdnFill
	var sum := 0.0
	for r in HDNRES:
		sum += minf(1.0, _n(cu.got.get(r[0])) / maxf(1.0, _n(cu.need.get(r[0]))))
	return sum / HDNRES.size()

func hdn_start(cu: Dictionary) -> void:   # hdnStart: nhà nào tới dự hội
	var F: Dictionary = WL._r0().fam
	var fill := hdn_fill(cu)
	var vv: int = cu.v.size()
	var att := []
	var hs: Array = WL.ut_houses()
	for uu in hs:
		var ff: Dictionary = F[_ks(uu)]
		var pp := minf(0.95, (0.25 + 0.15 * _i(ff.get("tim"))) * (0.5 + 0.5 * fill) * (1 + 0.1 * vv) * (1 + float(WL.htv("l_hoi")))) * (0.6 if ff.get("tp") == "kho" else 1.0)
		if randf() < pp:
			att.append(_ks(uu))
	cu.att = att
	cu.tot = hs.size()
	if not _tr(G.g.get("hc")):
		G.g.hc = {}
	G.g.hc.sp = cu.d

func fm() -> Dictionary:   # Fm: g.hc (hội chợ sân đình)
	var t = G.g.get("hc")
	if not _tr(t) or not (t is Dictionary):
		t = {}
		G.g.hc = t
	if not _eqn(t.get("day"), _vr()):
		t.day = _vr()
		t.niu = 0
		t.won = 0
	return t

func c_r(t: int) -> bool:   # CR: ngày chẵn hoặc ngày lễ
	return t % 2 == 0 or mm(t) != null

func e_r() -> bool:   # ER: hôm nay có hội chợ
	var t = G.g.get("hc")
	return c_r(_vr()) or (_tr(t) and _eqn(t.get("sp"), _vr()))

func _z6():   # z6
	var f := _x("z6")
	var v = f.call() if f.is_valid() else null
	return v if _tr(v) else null

func l2() -> bool:   # L2: hội chợ sân đình đang mở
	if _cr() or _z6() == null:
		return false
	var t := _d0()
	if G.troi.hh < 0.0 and (G.cfg.d == "day" or G.cfg.d == "night"):   # hh === null && (b1 day | night)
		var hc = G.g.get("hc")
		return _tr(hc) and _eqn(hc.get("sp"), _vr())
	return e_r() and t >= 18.5 and t < 22.5

# ================================================================== HỤI (g.hui)
func q_n() -> int:   # QN: số kỳ (12 giờ) tính từ đầu
	return int(floor((_vr() * 24 + _d0()) / VN))

func y6() -> int:   # y6: kỳ hiện tại
	var t = G.g.get("hui")
	return 0 if not _tr(t) or _tr(t.get("done")) else mini(_D, q_n() - int(t.k0) + 1)

func pm(t: String) -> void:   # Pm: ghi sổ hụi
	var a: Dictionary = G.g.hui
	a.log.push_front(t)
	a.log = a.log.slice(0, 8)

static func vk(t: int, a: float) -> int:   # vk: tiền hốt kỳ t
	return _rnd(a * (4.4 + 0.4 * t))

func u_n() -> Array:   # UN: các mức góp
	var t := _v1()
	var out := []
	for a in [300, 1000, 3000]:
		out.append(_rnd(a * (1 + 0.5 * t) / 100.0) * 100)
	return out

func jk() -> void:   # JK: bỏ thăm hốt hụi kỳ này
	var t = G.g.get("hui")
	if not _tr(t) or _tr(t.get("done")) or _tr(t.get("hot")):
		return
	var a := y6()
	if a < 1:
		return
	var n := vk(a, float(t.c)) - _n(t.get("no"))
	t.no = 0
	G.g.coins = _n(G.g.coins) + maxf(0.0, n)
	t.got = _n(t.get("got")) + n
	t.hot = a
	pm("Kỳ " + str(a) + ": bỏ thăm hốt hụi, nhận " + _sa(n) + " xu.")
	_ta("Hốt hụi kỳ " + str(a) + ": nhận " + _sa(n) + " xu. Các kỳ sau vẫn phải góp đủ tới mãn hụi.")
	_kn()
	_ba()

func mk(t, a: int) -> void:   # mk: vô hụi của nhà t, mỗi phần a xu
	if _tr(G.g.get("hui")) and not _tr(G.g.hui.get("done")):
		_ta("Đang chơi một dây hụi rồi.")
		return
	var n = _fam_of(t)
	if n == null:
		_ta("Chưa chọn chủ hụi.")
		return
	if _n(G.g.coins) < a:
		_ta("Cần " + _sa(a) + " xu để góp kỳ đầu.")
		return
	G.g.hui = {"u": int(_ks(t)) if _ks(t).is_valid_int() else 0, "n": n.n, "c": a, "k0": q_n(), "paid": 0, "hot": 0, "got": 0, "done": 0, "be": 0, "no": 0, "log": []}
	if WL != null:
		WL.hui_ky(true)   # KN(!0)
	_ta("Vô hụi của " + String(n.n) + ": 6 phần, mỗi kỳ 12 tiếng góp " + _sa(a) + " xu.")
	_ba()
	_kn()   # x4()

func hui_new() -> void:   # data-hui="new": g.hui = null
	G.g.hui = null
	_kn()

func hui_step(t: float) -> void:   # ui({id: "hui"}).step
	TS -= t
	if TS > 0:
		return
	TS = 2.0
	if _cr():
		return
	var h = G.g.get("hui")
	var a = h.get("paid") if _tr(h) else null
	if WL != null:
		WL.hui_ky(false)
	h = G.g.get("hui")
	if _tr(h) and h.get("paid") != a:
		_kn()

func sky_hui() -> Array:   # sky của "hui": [đang chơi (.got), chữ <small>]
	var t = G.g.get("hui")
	var on: bool = _tr(t) and not _tr(t.get("done"))
	return [on, ("Đang chơi hụi " + String(t.n) + ", kỳ " + str(y6()) + "/" + str(_D) + (", đã hốt" if _tr(t.get("hot")) else ", chưa hốt")) if on else "Chưa chơi dây hụi nào."]

# ================================================================== LỄ HỘI (g.fest, g.festn, g.festh)
func mm(t: int) -> Variant:   # Mm: lễ của ngày t (null = không có)
	var a := posmod(t, 28)
	var n := int(floor(a / 7.0))
	var e := a % 7 + 1
	for r in XU:
		if int(r.sea) == n and int(r.day) == e:
			return r
	return null

func jb() -> Variant:   # Jb: lễ gần nhất trong 29 ngày {f, d, k}
	var t := _vr()
	for a in 29:
		var n = mm(t + a)
		if n != null:
			return {"f": n, "d": t + a, "k": a}
	return null

func wt():   # WT: lễ hôm nay
	return mm(_vr())

func x2():   # x2: lễ trong 2 ngày tới
	var t = jb()
	return t if t != null and int(t.k) <= 2 else null

func x_q():   # xQ
	var t = wt()
	return t if _tr(t) else null

func k_q():   # kQ: lễ sắp tới (chưa phải hôm nay)
	var t = x2()
	return t.f if t != null and int(t.k) > 0 else null

func _yu(t: int):   # yu
	return WC.yu(t)

func _s2() -> Array:   # s2
	return WC.s2() if WC != null else []

func h4() -> Variant:   # h4: lễ vật làng nhờ góp cho lễ sắp tới
	var t = x2()
	if t == null:
		return null
	var a: String = String(t.f.id) + ":" + str(t.d)
	var n = G.g.get("fest")
	if not _tr(n) or not (n is Dictionary) or n.get("key") != a:
		var e := _v1()
		var r := _s2()
		var o = _yu(int(t.d) * 31 + 7)
		var l := []
		for d in t.f.cand:
			if not _ae(d).is_empty() and (r.has(d) or _barn(d) > 0):
				l.append(d)
		if l.size() < 3:
			for d in t.f.cand:
				if not _ae(d).is_empty() and ["gao", "trung", "lua", "qua_chuoi", "bot"].has(d):
					l.append(d)
		if l.size() < 3:
			l += ["lua", "trung", "gao"]
		var uniq := {}
		for d in l:
			uniq[d] = 1
		var c := []
		var f := {}
		while c.size() < 4 and c.size() < l.size():
			var s: String = l[int(floor(o.next() * l.size()))]
			if f.has(s):
				if f.size() >= uniq.size():
					break
				continue
			f[s] = 1
			var h: float = float(_ae(s).get("sell", 0)) if _tr(_ae(s).get("sell")) else 10.0
			var p := maxi(2, mini(60, _rnd((320 + o.next() * 280) * (1 + 0.6 * e) / h)))
			c.append([s, p])
		n = {"key": a, "id": t.f.id, "d": t.d, "need": c, "got": {}, "done": 0, "claim": 0}
		G.g.fest = n
	return n

func e_n(t: Dictionary) -> int:   # eN: số lễ vật còn thiếu
	var a := 0
	for n in t.need:
		a += maxi(0, int(n[1]) - _i(t.got.get(n[0])))
	return a

func tm(t: Dictionary) -> Dictionary:   # Tm: lễ theo id
	for a in XU:
		if a.id == t.get("id"):
			return a
	return XU[0]

func p4(t: String) -> String:   # p4: tên ngắn của lễ
	for a in XU:
		if a.id == t:
			return String(a.get("sh", "")) if _tr(a.get("sh")) else String(a.n)
	return "lễ"

func d_t() -> int:   # DT: lộc lễ hội
	return _v0(1500 * (1 + 0.8 * _v1()))

func dx() -> float:   # Dx: hôm nay nhận lộc rồi thì cây lớn nhanh (1,2)
	var t = G.g.get("fest")
	return 1.2 if _tr(t) and _tr(t.get("done")) and int(t.d) == _vr() else 1.0

func j_t(t: String) -> bool:   # jT: góp lễ vật t
	var a = h4()
	if a == null or _tr(a.get("done")):
		return false
	var n = null
	for l in a.need:
		if l[0] == t:
			n = l
	if n == null:
		return false
	var e: int = int(n[1]) - _i(a.got.get(t))
	var r := _barn(t)
	var o := mini(e, r)
	if o <= 0:
		_ta("Kho chưa có " + String(_ae(t).get("name", t)).to_lower() + ".")
		return false
	G.g.barn[t] = _barn(t) - o
	a.got[t] = _i(a.got.get(t)) + o
	G.add_xp(mini(6, 1 + int(floor(o / 5.0))), "fest")   # w1
	_ta("Góp " + _ho(t, o) + " cho lễ " + String(tm(a).sh) + ".")
	_gr(8)
	if e_n(a) <= 0:
		a.done = 1
		var nm := String(tm(a).n)
		_later(0.7, func(): _ta("Làng đã đủ lễ vật cho " + nm + "! Tới ngày hội nhớ ghé nhận lộc nha."))
	_kn()
	_ba()
	return true

func v_t() -> bool:   # VT: nhận lộc lễ hội
	var t = h4()
	if t == null or not _tr(t.get("done")) or _tr(t.get("claim")) or _vr() != int(t.d):
		return false
	t.claim = 1
	var a := d_t()
	var n = _lang()
	var e := 0
	G.g.coins = _n(G.g.coins) + a
	if n != null and _tr(n.get("fam")):
		for r in _okeys(n.fam):
			var o: Dictionary = n.fam[r]
			if _n(o.get("tim")) < 5:
				o.tim = _n(o.get("tim")) + 1
				e += 1
	if n != null:
		n.gach = _n(n.get("gach")) + 8
	G.g.festn = _n(G.g.get("festn")) + 1
	G.nv.qi("fest")
	_ta("Lộc " + String(tm(t).sh) + ": " + _sa(a) + " xu, 8 viên gạch" + (", " + str(e) + " nhà thân thêm 1 ♥" if e else "") + ". Hôm nay cây trái trong làng lớn nhanh hơn 4%!")
	_gr([12, 30, 18])
	_kn()
	_ba()
	return true

func y_q(t: float) -> void:   # yQ: báo lễ sắp tới (mỗi giây; bQ ở w_htx_ui.gd pill_sync)
	KT -= t
	if KT > 0:
		return
	KT = 1
	var a = x2()
	if a == null:
		return
	var n = h4()
	var e := _vr()
	if n != null and G.g.get("festh") != str(e) + ":" + String(n.id) and _mode() == "off":
		G.g.festh = str(e) + ":" + String(n.id)
		var r := tm(n)
		var o: int = int(n.d) - e
		var msg := ("Sắp tới " + String(r.n) + " (" + str(o) + " ngày nữa)! Bà con trong làng nhờ góp lễ vật. Chạm nút lễ hội ở trên để xem.") if o > 0 else ("Hôm nay " + String(r.n) + "! " + String(r.d))
		_later(2.4, func(): _ta(msg))
		_ba()

func fest_pill() -> Dictionary:   # bQ (phần chữ): {} = ẩn; {text, hurry}
	var t = x2()
	var qc := _x("qc")
	var a: bool = t != null and _mode() == "off" and (String(qc.call()) if qc.is_valid() else "") != "map"
	if not a:
		return {}
	var n = h4()
	if n == null:
		return {}
	var e := tm(n)
	var r: int = int(n.d) - _vr()
	var o := ""
	if r > 0:
		var tot := 0
		for c in n.need:
			tot += int(c[1])
		o = String(e.sh) + " còn " + str(r) + " ngày · góp lễ " + ("đủ rồi" if _tr(n.get("done")) else str(_rnd(100 * (1 - float(e_n(n)) / tot))) + "%")
	else:
		o = (("Hôm nay " + String(e.sh) + " · làng đang vui hội") if _tr(n.get("claim")) else ("Hôm nay " + String(e.sh) + " · nhận lộc")) if _tr(n.get("done")) else ("Hôm nay " + String(e.sh) + " · còn thiếu lễ vật")
	return {"text": o, "hurry": r == 0 and not _tr(n.get("done"))}

# ================================================================== QUÁN, CƠM, Y TẾ, CHỢ PHIÊN, DU LỊCH, CÁC HỆ NHỎ
func yd() -> Dictionary:   # Yd: g.quan
	var t = G.g.get("quan")
	if not _tr(t) or not (t is Dictionary):
		t = {}
		G.g.quan = t
	if not _tr(t.get("st")):
		t.st = {}
	if not _num(t.get("sao")):
		t.sao = 3
	if not _num(t.get("lv")):
		t.lv = 1
	if not _num(t.get("tot")):
		t.tot = 0
	if not _num(t.get("xu")):
		t.xu = 0
	var a := _vr()
	if not _eqn(t.get("day"), a):
		t.day = a
		t.dn = 0
		t.dx = 0
		t.miss = 0
	return t

func dk() -> Dictionary:   # Dk: số liệu xếp hạng của mình
	var t = G.g.get("quan")
	return {"dep": _rnd(float(G.lang.beauty())), "xu": _rnd(_n(G.g.coins)), "lv": int(_fr().lv),
		"sao": float(_rnd(float(t.sao) * 10)) / 10.0 if _tr(t) and _tr(t.get("tot")) else 0,
		"dat": int(WS.j5()) if WS != null else 0, "sk": G.nv.streak_now()}

func n5() -> Dictionary:   # n5: g.com (nồi cơm chung)
	var t: int = G.nv.Ao()
	var c = G.g.get("com")
	if not _tr(c) or not _eqn(c.get("day"), t):
		G.g.com = {"day": t, "p": 0, "paid": 0, "last": c.get("res") if _tr(c) and _tr(c.get("res")) else null}
	return G.g.com

func c_c() -> Dictionary:   # cC: g.yte
	var t = G.g.get("yte")
	if not _tr(t) or not (t is Dictionary):
		t = {}
		G.g.yte = t
	if not _num(t.get("kt")):
		t.kt = 0
	return t

func lf() -> Dictionary:   # Lf: g.cp (chợ phiên)
	var t = G.g.get("cp")
	if not _tr(t) or not (t is Dictionary):
		t = {}
		G.g.cp = t
	if not (t.get("list") is Array):
		t.list = []
	if not (t.get("log") is Array):
		t.log = []
	if not _tr(t.get("bought")):
		t.bought = {}
	if not _tr(t.get("npc")) or not _eqn(t.npc.get("day"), _vr()):
		t.npc = {"day": _vr(), "d": {}}
	return t

func r6() -> Dictionary:   # R6: g.dl (du lịch)
	var t = G.g.get("dl")
	if not _tr(t) or not (t is Dictionary):
		t = {}
		G.g.dl = t
	if not (t.get("rv") is Array):
		t.rv = []
	if not _num(t.get("lv")):
		t.lv = 1
	if not _num(t.get("xu")):
		t.xu = 0
	if not _num(t.get("n")):
		t.n = 0
	return t

func wm() -> Dictionary:   # Wm: g.vm
	if not _tr(G.g.get("vm")):
		G.g.vm = {}
	var t: Dictionary = G.g.vm
	if not _tr(t.get("cl")):
		t.cl = {}
	if not _tr(t.get("ong")):
		t.ong = {}
	return t

func jm() -> Dictionary:   # Jm: g.thi (hội thi làng)
	var t = G.g.get("thi")
	if not _tr(t) or not (t is Dictionary):
		t = {}
		G.g.thi = t
	if not _num(t.get("n")):
		t.n = 0
	if not _num(t.get("best")):
		t.best = 0
	if not _num(t.get("gold")):
		t.gold = 0
	if not _num(t.get("st")):
		t.st = 0
	return t

func ng0() -> Dictionary:   # $0: g.ng (sen đỏ)
	var t = G.g.get("ng")
	if not _tr(t) or not (t is Dictionary):
		G.g.ng = {"n": 0, "first": 0, "tot": 0, "the": null, "vip": {}}
	if not _tr(G.g.ng.get("vip")):
		G.g.ng.vip = {}
	return G.g.ng

func i_s() -> Dictionary:   # iS: g.gb (sổ khách)
	var t = G.g.get("gb")
	if not _tr(t) or not (t is Dictionary):
		t = {}
		G.g.gb = t
	if not _num(t.get("seen")):
		t.seen = 0
	if not (t.get("list") is Array):
		t.list = []
	return t

func b_r() -> Dictionary:   # bR: g.rkw (thưởng xếp hạng tuần)
	var w: int = int(WS.mR()) if WS != null else 0
	var t = G.g.get("rkw")
	if not _tr(t) or not (t is Dictionary) or not _eqn(t.get("w"), w):
		t = {"w": w, "got": {}}
		G.g.rkw = t
	return t

func r_c() -> Dictionary:   # rc: g.ray (rầy nâu)
	var t = G.g.get("ray")
	if not _tr(t) or not (t is Dictionary):
		t = {}
		G.g.ray = t
	if not _tr(t.get("p")):
		t.p = {}
	if not _num(t.get("th")):
		t.th = 0
	if not _num(t.get("cd")):
		t.cd = 0
	if not _num(t.get("k")):
		t.k = 0
	return t

func p_h() -> Dictionary:   # PH: g.mat (vật liệu nâng sao)
	var t = G.g.get("mat")
	if not _tr(t) or not (t is Dictionary):
		t = {}
		G.g.mat = t
	return t

func u3() -> Dictionary:   # u3: g.penst (sao chuồng)
	var t = G.g.get("penst")
	if not _tr(t) or not (t is Dictionary):
		t = {}
		G.g.penst = t
	return t

func cafe_s() -> Dictionary:   # N (khối quán cà phê): g.cafe
	var gt = G.g.get("cafe")
	if not _tr(gt) or not (gt is Dictionary):
		gt = {"c": [], "nx": 0}
		G.g.cafe = gt
	if not (gt.get("c") is Array):
		gt.c = []
	return gt

func tap_s() -> Dictionary:   # x (khối tạp hóa): g.tap
	var gt = G.g.get("tap")
	if not _tr(gt) or not (gt is Dictionary):
		gt = {"o": [], "nx": 0}
		G.g.tap = gt
	if not (gt.get("o") is Array):
		gt.o = []
	return gt

# ================================================================== ĐỔI NHỊP HAY DAY (g.hdv)
static func hd7(t: float, a: float, n: float) -> float:   # _7: đổi tiến độ t (thang a) sang thang n
	if not (t > 0) or not (a > 0):
		return t
	return n if t >= a else t / a * n

func f_j(t: String) -> int:   # fJ: thời gian gốc của cây (giống lai = cây gốc x 1,1)
	if _tr(U7.get(t)):
		return int(U7[t])
	var a = OL.get(t)
	return _rnd(float(U7[a.a]) * 1.1) if _tr(a) and _tr(U7.get(a.a)) else 0

func t_h(t: float) -> void:   # TH: đổi tiến độ cây ăn trái
	var Ei: Dictionary = G.lang.C.Ei if G.lang != null else _jd("nong_trai/cay_an_trai")
	var objs = G.g.get("objs")
	for a in (objs if objs is Array else []):
		var n = Ei.get(String(a.get("id", ""))) if _tr(a) else null
		var e = CJ.get(String(a.get("id", ""))) if _tr(a) else null
		if _tr(n) and _tr(e) and _n(a.get("fp")) > 0:
			a.fp = hd7(float(a.fp), float(e) / t, float(n.time))

func s_h() -> bool:   # SH: đổi sang nhịp Hay Day (một lần)
	if G.g.is_empty() or _n(G.g.get("hdv")) >= 2:
		return false
	if _n(G.g.get("hdv")) == 1:
		t_h(1)
		G.g.hdv = 2
		_later(1.5, func(): _ta("Cây ăn trái đổi nhịp Hay Day: ra trái mỗi 16 giờ tới 1 ngày rưỡi, mở theo cấp (tối đa cấp 100). Có thêm cây cam sành và cây mận."))
		_ba()
		return true
	for n in G.g.get("plots", []):
		if not _tr(n) or not _tr(n.get("c")) or G.crop(String(n.c)).is_empty():
			continue
		var e := f_j(String(n.c))
		if e:
			n.g = hd7(float(n.g), e, float(G.crop(String(n.c)).time))
	var pens = G.g.get("pens")
	for n in G.DI:
		for e in (pens.get(n, []) if pens is Dictionary else []):
			if _tr(e) and _n(e.get("p")) > 0:
				e.p = hd7(float(e.p), float(LJ[n]), float(G.vn.Q[n].time))
	var work = G.g.get("work")
	if work is Dictionary:
		for n in _okeys(work):
			var e = work[n]
			if _tr(e) and _tr(e.get("q")) and e.q.size() and _tr(TV.get(String(e.q[0]))):
				e.p = hd7(float(e.p), float(TV[String(e.q[0])]), float(G.xw.R[String(e.q[0])].time))
	t_h(60)
	var t := _jr()
	var a := []
	for n in G.xo:
		var e: Dictionary = G.crop(n)
		if _tr(e.get("hyb")) or (int(e.get("lv", 1)) if _tr(e.get("lv")) else 1) > t or _barn(n) > 0:
			continue
		G.g.barn[n] = 4
		a.append(e.name)
	G.g.hdv = 2
	var gift := (" Tặng 4 hạt: " + ", ".join(PackedStringArray(a)) + ".") if a.size() else ""
	_later(1.5, func(): _ta("Làng đổi sang nhịp Hay Day: cây lớn theo phút, giờ thật, không tưới vẫn lớn, tưới thì nhanh hơn 10%. Giá bán, cấp mở giống đổi theo." + gift))
	_kn()
	_ba()
	return true

func hayday_step(t: float) -> void:   # ui({id: "hayday"}).step
	UE -= t
	if UE > 0:
		return
	UE = 1
	s_h()

# ================================================================== bước mỗi khung
func step(t: float, offline: bool) -> void:   # htx, hui, yQ (trong wK), hayday; bản web không chạy các bước ui() khi bù offline
	if offline:
		return
	hayday_step(t)
	htx_step(t)
	hui_step(t)
	y_q(t)
