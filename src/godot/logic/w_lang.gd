extends RefCounted
# DÂN LÀNG, GIA ĐÌNH, NGHỀ, CƯỚI HỎI, CHUYỆN LÀNG: luật bản web còn thiếu ở bản Godot, chép 1:1.
#   thân thiết g.lang.fam[u].dp/tim (thanSync, thanAdd, thanTxt, thanInit, thanSeen, tinhOf, htv, chatLeft,
#     thanDaily, thanPQLate, thanInvite),
#   gia phả (gpFam, gpKeys, gpXom, gpHo, gpRoot, gpRel, gpSpread, gpSuiMinh, gpIsSuiMinh, gpAssign, vlTen, vlTenUsed, gpWedding),
#   nghề g.nghe / g.ngm / g.ngs / g.ndn / g.ndt / g.hn / g.hnk (T6, ngMap, ngS, ngD, ngT, HN, hnK, ngheById, ngOfHouse, aR,
#     ngNextHo, ngOkLv, ngThieu, ngheWho, ngId, ngHas, ngTake, ngBase, hnLearned, hnOf, hnStuff, hnIn1, hnIn3, hnHave, hnTake,
#     hnMiss, hnHp, famLikes, hnLe, hnLeOk, hnLeTake, ngLearned, ngHocCho, xung, Mk, ngLock, ngSao, ngStars, ngChinh,
#     ngDiemNay, ngRate, ngMax, ngThay, ngThiCond, ngThiReady, htNgay, qS, ngGen, ngMk, ngVal, ngPhat, ngXau),
#   uy tín g.ut (utS, utWeek, utNewTasks, utAdd, utBieu, utHouses, utLang, utTo, ctTen, utCond), công trình chung g.ct (ctS),
#   thiên tai g.tn (tnS, tnOk, tnOn, tnEvOf, tnFest, tnSea), chuyện làng g.clg (clgS, clgAdd, clgGen, clgFill, clgWho, clgTick),
#   thư g.thu (Eg), g.lg (lgS), đám tiệc g.dam (Tg, zm, qm, Sg, bk, YK, $K), cưới hỏi g.cuoi (nR, BS, NS, Sk, Ck, zU, NU, RU),
#   người làm thuê (lm, qq, Bq, ED, Nq, $5, om, LD, Rq, eC, Tu, rC, Zk, kS, $C, eY, yI, x9, DI),
#   hụi KN, du lịch trả phòng BR, báo khi xây xong Kq, chữ khi rê chuột Vq, ma trơi g.ma (k6, iU, ES).
# Vẽ người đi lại (vD, ID, FD, M_, qU, PU), chạm trúng (DD, BU, Dq), dân đi chơi (k_, oC, Jk, h_), đoàn khách (U_),
#   hạt bay, âm thanh: không chép (xem danh sách bỏ qua của đợt).

const NV = preload("res://logic/nv.gd")
const WRS = preload("res://logic/w_ruong.gd")   # fx (hàm tĩnh)

var G
var WR = null              # w_ruong.gd (bộ ráp gán): gg, td, ct_built, o0, qf, ro, Y0
var WC = null              # w_cho.gd (bộ ráp gán): ho, s2, v1
var WS = null              # NTWEB w_sys.gd (bộ ráp gán): htv dùng chung
var ui = null              # w_lang_ui.gd (tự gán khi tạo)
# ext: việc của hệ khác (bộ ráp gán Callable theo tên web)
#   (Uf / CD / SD / bl: làm ngay ở đây, đọc Hr của WR._hrl)
#   E2(u) -> Dictionary      (E2[u]: người nhà u đang đi chơi {st: "home" | "go" | ...}; null = chưa có)
#   Bf(id) -> int            (Bf: cấp mở món)
#   Jb() -> Dictionary       (lễ gần nhất trong 29 ngày {f: {id, sh}, d, k})
#   y6() -> int, Pm(s), vk(t, a) -> int        (hụi: kỳ tới, ghi sổ, tiền hốt)
#   R6() -> Dictionary       (g.dl du lịch)
#   mg() -> Array, Ae() -> Dictionary          (bến ghe sông Vàm, ghe thương hồ)
#   BN(t) -> String, NN_T(kd) -> String, hr() -> Dictionary   (chữ rê chuột của hệ khác, điên điển, xe chè)
#   AD(t)                    (AD: làm thuê lúc ẩn trang / offline)
#   ll(x, y) -> bool, _b(x, y) -> bool, aa() -> Vector2         (ô trong bản đồ, ô đất đã có, chỗ nhân vật)
#   Mt_mode() -> String, Cr() -> bool, ngThoMul(b) -> float, c7(t) -> String, V1() -> Dictionary
#   clgRender(now), tU(), i1(), sig_reset(), e7(), ku_reset(), s2() -> Array (khi không có WC)
var ext := {}

const CHATMAX := 3
const DPMAX := 500
const NGNGAY := 15
const NGCHINH := 3
const CLGMAX := 100
const TNLV := 15
const _D := 6              # _d: số kỳ hụi

var TINH := {}
var TINHK := []
var HOLIST := []
var XUNGT := {}
var THUT := []
var TENR := {}
var GPRATE := {}
var THICH := []
var NGAYN := []
var M6 := []
var NGH := []
var NGTHI := []
var NGK := []
var NGX := []
var NGSAO := []
var NGPHAT := {}
var NGNAN := {}
var NGHOI := []
var NGCT := {}
var NGLE := {}
var NGCUOI := []
var HNHU := []
var CLGK := {}
var CLGT := []
var CLGCON := []
var TNW := []
var TNK := {}
var TNNAN := {}
var HTI := {}
var CTB := {}
var CX := {}               # cx: sức chứa nhà
var W3 := {}               # w3
var AY := []               # aY
var EU := []
var CU := []
var LU := {}
var UTCHUC := []
var UTP := []
var UTLV := []
var UTLANG := []
var UTTUAN := []
var XO := []               # xo
var WF := []               # Wf
var PT := []               # pT
var PR := []
var V_ := {}
var A7 := {}               # a7
var CO := {}               # Co
var Z7 := {}               # Z7: tên chức năng phụ

var THMO := 20.0           # thanInvite
var CLGT0 := 0.0           # clgTick
var SS := 0.0              # $K
var Xr := {"st": 0, "x": 0.0, "y": 0.0, "tx": 0.0, "ty": 0.0, "hop": 0, "need": 3, "al": 0.0, "ph": 0.0, "tr": [], "snd": 0.0}   # ma trơi

func _init(game) -> void:
	G = game
	TINH = _jd("dan_lang/tinh_cach")
	TINHK = _ja("dan_lang/ds_tinh_cach")
	HOLIST = _ja("dan_lang/ho")
	XUNGT = _jd("dan_lang/xung_ho")
	THUT = _ja("dan_lang/thu_trong_nha")
	TENR = _jd("dan_lang/ten_rieng")
	GPRATE = _jd("dan_lang/quan_he_lay_than")
	THICH = _ja("dan_lang/so_thich")
	NGAYN = _ja("dan_lang/ngay_rieng")
	M6 = _ja("nghe/nghe")
	NGH = _ja("nghe/hang")
	NGTHI = _ja("nghe/thi_len_sao")
	NGK = _ja("nghe/ti_le_kheo")
	NGX = _ja("nghe/ti_le_tinh_xao")
	NGSAO = _ja("nghe/moc_diem_sao")
	NGPHAT = _jd("nghe/phat_tre_han")
	NGNAN = _jd("nghe/don_hoan_nan")
	NGHOI = _ja("nghe/don_hoi_dinh")
	NGCT = _jd("nghe/don_cong_trinh")
	NGLE = _jd("nghe/don_le")
	NGCUOI = _ja("nghe/don_cuoi")
	HNHU = _ja("nghe/cau_tu_choi_day")
	CLGK = _jd("chuyen_lang/nhom")
	CLGT = _ja("chuyen_lang/mau_chuyen")
	CLGCON = _ja("chuyen_lang/con_vat")
	TNW = _ja("thien_tai/ti_le_theo_mua")
	TNK = _jd("thien_tai/loai")
	TNNAN = _jd("thien_tai/ten_nan")
	for x in _ja("he_thong/nut_phat_trien"):   # HTI = {id: nút}
		HTI[String(x.id)] = x
	CTB = _jd("cong_trinh_chung/bac")
	CX = _jd("xay_dung/suc_chua_nha")
	W3 = _jd("nhan_vat/tay_nghe_lam_thue")
	AY = _ja("khac/aY")
	EU = _ja("khac/EU")
	CU = _ja("khac/CU")
	LU = _jd("dan_lang/ten_tre_con")
	UTCHUC = _ja("uy_tin/ten_chuc")
	UTP = _ja("uy_tin/diem_len_chuc")
	UTLV = _ja("uy_tin/cap_len_chuc")
	UTLANG = _ja("uy_tin/quy_mo_lang")
	UTTUAN = _ja("uy_tin/tuan_giu_chuc")
	XO = _ja("nong_trai/thu_tu_cay")
	WF = _ja("cau_ca/ds_ca")
	for t in _ja("che_bien/thu_tu_hang"):   # pT = to.filter(...)
		if t != "mat_ong" and t != "dien_dien" and t != "bong_sung" and t != "keo_neo":
			PT.append(t)
	PR = _ja("du_lich/gia_phong")
	V_ = _jd("du_lich/danh_gia")
	A7 = _jd("du_lich/khach")
	CO = _jd("che_bien/ten_cong_trinh_lam_an")
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

static func _tr(v) -> bool:   # độ "thật" kiểu JS (mảng / đối tượng rỗng vẫn là thật)
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

static func _ks(u) -> String:   # khóa đối tượng JS của số nhà
	if _num(u):
		return str(int(u))
	return String(u)

static func _rnd(x: float) -> int:   # Math.round
	return int(floor(x + 0.5))

static func _sv(v) -> String:   # String(v) như JS (số nguyên không có ".0")
	if typeof(v) == TYPE_FLOAT and v == floor(v):
		return str(int(v))
	return str(v)

static func _nn(a: float, b: float) -> float:   # Nn
	return a + randf() * (b - a)

static func _t0(a: Array) -> Variant:   # t0
	if a.is_empty():
		return null
	return a[int(floor(randf() * a.size()))]

static func _okeys(d: Dictionary) -> Array:   # Object.keys: khóa số nguyên tăng dần trước, rồi khóa chữ theo thứ tự thêm
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

static func _has_n(arr: Array, v) -> bool:   # mảng số: indexOf(v) >= 0
	for x in arr:
		if _num(x) and _num(v) and float(x) == float(v):
			return true
		if typeof(x) == typeof(v) and x == v:
			return true
	return false

func _ta(s: String) -> void:   # ta / pn
	G.toast.emit(s)

func _ba() -> void:   # Ba / kn
	G.mark()

func _gr(ms) -> void:   # gr
	G.vib(ms)

func _vr() -> int:   # vr
	return G.day()

func _d0() -> float:   # d0
	return G.nv.hour()

func _jr() -> int:   # jr
	return G.nv.jr()

func _now() -> float:   # Date.now()
	return G._now_ms()

func _ae(t) -> Dictionary:   # ae (không có -> {})
	if t == null:
		return {}
	return G.item(String(t))

func _ai(t: String) -> int:   # $i
	return G.price(t)

func _sa(v) -> String:   # Sa
	return G.fmt_n(float(v))

func _ro(s: float) -> int:   # Ro
	return int(WR.ro(s)) if WR != null else maxi(1, int(ceil(s / 600.0)))

func _sc(n: int) -> bool:   # sc
	return G.spend_ngoc(n)

func _qi(k: String) -> void:   # qi
	G.nv.qi(k)

func _v1() -> int:   # v1
	if WC != null:
		return int(WC.v1())
	return mini(4, int(floor(_n(G.g.get("delivered", 0)) / 2.0)))

func _fr() -> Dictionary:   # fr: g.pc
	return G.g.pc

func _mode() -> String:   # Mt.mode
	var f := _x("Mt_mode")
	return String(f.call()) if f.is_valid() else "off"

func _cr() -> bool:   # Cr
	var f := _x("Cr")
	return bool(f.call()) if f.is_valid() else false

func _barn(t) -> int:   # g.barn[t] || 0
	return _i(G.g.barn.get(String(t), 0))

func _ho(t: String, a: int) -> String:   # ho
	if WC != null:
		return WC.ho(t, a)
	return str(a) + " " + String(_ae(t).get("name", t)).to_lower()

func _qf(t: String) -> int:   # qf
	return int(WR.qf(t)) if WR != null else 0

func _jg(t: String) -> bool:   # Jg: chức năng đã mở (chưa mở thì báo cấp)
	var a := _qf(t)
	if a:
		_ta(String(Z7.get(t, "Chức năng này")) + " mở ở cấp " + str(a) + ".")
		return false
	return true

func _pi() -> Dictionary:   # Pi
	return G.lang.Pi if G.lang != null else {}

func _wr(x: float, y: float, m: float) -> bool:   # Wr
	if G.lang != null and G.lang.F != null:
		return G.lang.F.onscreen(x, y, m)
	return false

func _r0() -> Dictionary:   # R0
	var t = G.g.get("lang")
	if not (t is Dictionary):
		t = {}
		G.g.lang = t
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

func _lang():   # g.lang (null nếu chưa có)
	var L = G.g.get("lang")
	return L if L is Dictionary else null

func _fam_of(u) -> Variant:   # g.lang && g.lang.fam[u]
	var L = _lang()
	if L == null or not (L.get("fam") is Dictionary):
		return null
	var f = L.fam.get(_ks(u))
	return f if f is Dictionary else null

var _bl := []              # bl
var _pq := ""              # Pq (+ zq): dấu Hr lúc dựng bl
var _zq = null

func uf() -> void:   # Uf: m0 (Hr đổi thì dựng lại) -> CD khi Hr hoặc g đổi
	if WR == null:
		return
	var H: Array = WR._hrl()
	if WR._hr_sig != _pq or not is_same(_zq, G.g):
		_cd(H)

func _cd(H: Array) -> void:   # CD: bl = nhà đặt trên làng (cx), mỗi nhà một gia đình g.lang.fam[u]
	var t := _r0()
	var O: Array = G.g.get("objs", [])
	var a := {}
	var l := 0
	_bl = []
	for r in O:
		if r is Dictionary and _i(r.get("u")) > l:
			l = _i(r.get("u"))
	if _i(t.get("seq")) <= l:
		t.seq = l + 1
	for e in H:
		var r = O[int(e.idx)] if int(e.idx) < O.size() else null
		if not (r is Dictionary) or not CX.has(String(r.get("id", ""))):
			continue
		if _i(r.get("u")) > 0 and a.has(_i(r.u)):
			r.u = 0
		if not (_i(r.get("u")) > 0):   # Sq
			r.u = _i(t.seq)
			t.seq = _i(t.seq) + 1
		var o := _i(r.u)
		a[o] = 1
		_bl.append({"u": o, "o": e, "r": r})
	for c in t.fam.keys():
		if not a.has(int(float(String(c)))):
			t.fam.erase(c)
	var ZS := _ja("dan_lang/trang_phuc_dan").size()
	for f in _bl:
		var k := _ks(f.u)
		var s = t.fam.get(k)
		if not (s is Dictionary) or not (s.get("n") is String):
			s = {"n": _sd(t, int(f.u)), "lk": int(f.u) % ZS, "tim": 0, "req": null, "job": null, "jr": null, "wt": 0}
			t.fam[k] = s
		s.tim = clampi(_i(s.get("tim")), 0, 5)
		if not _num(s.get("wt")):
			s.wt = 0
		if not (_i(s.get("lk")) >= 0 and _i(s.get("lk")) < ZS):
			s.lk = 0
		var q = s.get("req")
		if _tr(q) and not (q is Dictionary and _tr(q.get("id")) and not _ae(q.id).is_empty() and _n(q.get("q")) > 0 and _n(q.get("xu")) > 0 \
				and (q.it if q.get("it") is Array and q.it.size() else [[q.id, q.q]]).all(func(x): return not _ae(x[0]).is_empty() and _n(x[1]) > 0)):
			s.req = null
		var j = s.get("job")
		if _tr(j) and j != "ruong" and not (j in ["vuon", "chan"]) and not (G.xw.sr.has(j) and G.xw.built(j)):
			s.job = null
		if _tr(s.get("jr")) and not G.xw.R.has(String(s.jr)):
			s.jr = null
		than_init(f.u, s)
	_pq = WR._hr_sig
	_zq = G.g

func _sd(t: Dictionary, a: int) -> String:   # SD: tên gia đình chưa ai dùng
	var RB := _ja("khac/Rb")
	var n := {}
	for e in t.fam:
		if t.fam[e] is Dictionary and _tr(t.fam[e].get("n")):
			n[String(t.fam[e].n)] = 1
	for r in RB.size():
		var o := String(RB[(r + a * 7) % RB.size()])
		if not n.has(o):
			return o
	return String(RB[a % RB.size()]) + " " + str(2 + a % 9)

func bl() -> Array:   # bl (dựng lại khi nhà đổi)
	uf()
	return _bl

func r1(t) -> Variant:   # r1
	for h in bl():
		if int(h.u) == int(float(_ks(t))):
			return h
	return null

# ------------------------------------------------------------------ thân thiết
func than_sync(f: Dictionary) -> void:   # thanSync
	var t := clampi(_i(f.get("tim")), 0, 5)
	var dp := _n(f.get("dp"))
	if int(floor(dp / 100.0)) != t:
		f.dp = t * 100 + (fmod(dp, 100.0) if t < 5 else 0.0)
	f.tim = t

func tinh_of(f: Dictionary) -> Dictionary:   # tinhOf
	if not TINH.has(String(f.get("tp", ""))):
		f.tp = TINHK[0]
	return TINH[String(f.tp)]

func htv(id: String) -> float:   # htv
	if WS != null:   # NTWEB: một bản htv (w_sys.htv)
		return float(WS.htv(id))
	var o = G.g.get("ht")
	var x = HTI.get(id)
	if not (o is Dictionary) or not _tr(o.get("n")) or x == null:
		return 0.0
	var k := _i(o.n.get(id, 0))
	if k > 0 and not _tr(x.get("soon")):
		var v: Array = x.v
		return float(v[mini(k, v.size()) - 1])
	return 0.0

func than_add(f: Dictionary, v: float, flo := 0.0) -> int:   # thanAdd
	than_sync(f)
	var T := tinh_of(f)
	var t0 := int(f.tim)
	var w := _rnd(v * (float(T.gain) * (1.0 + htv("l_men")) if v > 0 else float(T.loss)))
	f.dp = maxf(minf(_n(f.dp), flo), minf(DPMAX, _n(f.dp) + w))
	f.tim = int(floor(float(f.dp) / 100.0))
	if flo == 0.0:
		gp_spread(f, w)
	return int(f.tim) - t0

static func than_txt(d: int) -> String:   # thanTxt
	return " (+" + str(d) + " ♥)" if d > 0 else (" (" + str(d) + " ♥)" if d < 0 else "")

func than_init(u, f: Dictionary) -> void:   # thanInit (CD gọi cho từng nhà)
	f.hu = int(float(_ks(u)))
	gp_assign(u, f)
	if _n(f.get("nv")) != 1.0:
		f.n = vl_ten(u, f)
		f.nv = 1
	if not TINH.has(String(f.get("tp", ""))):
		f.tp = TINHK[(int(f.hu) * 5 + 1) % TINHK.size()]
	if not _num(f.get("dp")):
		f.dp = _i(f.get("tim")) * 100
	if not _num(f.get("lg")):
		f.lg = _vr()
	if _tr(f.get("pq")) and f.pq is Dictionary and not _num(f.pq.get("d")):
		f.pq.d = _vr()

func than_seen(f: Dictionary) -> void:   # thanSeen
	f.lg = _vr()

func chat_left(f: Dictionary) -> int:   # chatLeft
	return maxi(0, CHATMAX - _i(f.get("cn"))) if _num(f.get("cd")) and float(f.cd) == float(_vr()) else CHATMAX

func than_daily() -> void:   # thanDaily
	var L = _lang()
	if L == null or not _tr(L.get("fam")):
		return
	var d := _vr()
	if not _num(L.get("dd")):
		L.dd = d
		return
	for i in range(maxi(int(L.dd) + 1, d - 30), d + 1):
		for k in _okeys(L.fam):
			var f: Dictionary = L.fam[k]
			than_init(k, f)
			if _n(f.get("tim")) >= 2 and i - _n(f.get("lg")) >= 3:
				than_add(f, -_rnd(10.0 * (1.0 - htv("l_kho"))), 100.0)
	L.dd = d

func than_pq_late() -> void:   # thanPQLate
	var L = _lang()
	var d := _vr()
	var q := []
	if L == null or not _tr(L.get("fam")):
		return
	for k in _okeys(L.fam):
		var f: Dictionary = L.fam[k]
		if _tr(f.get("pq")) and d - _n(f.pq.get("d")) >= 2:
			f.pq = null
			var dh := than_add(f, -30)
			ut_add(-5, "Bỏ việc riêng của " + String(f.n))
			q.append(String(f.n) + than_txt(dh))
	if q.size():
		_ta("Bỏ Việc riêng quá lâu, " + ", ".join(PackedStringArray(q)) + " buồn lắm.")

func than_invite(dt: float) -> void:   # thanInvite
	THMO -= dt
	if THMO > 0:
		return
	THMO = _nn(90, 200)
	var L = _lang()
	if L == null or not _tr(L.get("fam")):
		return
	var ks := _okeys(L.fam)
	var on := ks.filter(func(k): return _n(L.fam[k].get("mo")) == 1.0)
	if on.size() >= mini(10, 3 + int(floor(ks.size() / 50.0))):
		return
	var c := ks.filter(func(k):
		var f: Dictionary = L.fam[k]
		return _n(f.get("mo")) != 1.0 and not _tr(f.get("req")) and chat_left(f) > 0 and r1(k) != null)
	if c.size():
		L.fam[_t0(c)].mo = 1

# ------------------------------------------------------------------ gia phả
func gp_fam() -> Dictionary:   # gpFam
	var L = _lang()
	return L.fam if L != null and L.get("fam") is Dictionary else {}

func gp_keys() -> Array:   # gpKeys
	var a := []
	for k in gp_fam():
		a.append(int(float(_ks(k))))
	a.sort()
	return a

func _gf(k) -> Dictionary:   # F[k]
	var v = gp_fam().get(_ks(k))
	return v if v is Dictionary else {}

func gp_xom(u) -> Array:   # gpXom
	var h = r1(u)
	if h == null:
		return []
	var x := float(h.o.gx) + float(h.o.fw) / 2.0
	var y := float(h.o.gy) + float(h.o.fd) / 2.0
	var a := []
	var B := bl()
	for i in B.size():
		var o = B[i]
		if int(o.u) == int(float(_ks(u))):
			continue
		var d := Vector2(float(o.o.gx) + float(o.o.fw) / 2.0 - x, float(o.o.gy) + float(o.o.fd) / 2.0 - y).length()
		if d <= 7:
			a.append([int(o.u), d, i])
	a.sort_custom(func(p, q): return p[1] < q[1] or (p[1] == q[1] and p[2] < q[2]))
	var r := []
	for p in a.slice(0, 4):
		r.append(p[0])
	return r

func gp_ho(ho) -> Array:   # gpHo
	var F := gp_fam()
	return gp_keys().filter(func(k): return F[str(k)].get("ho") == ho)

func gp_root(u) -> int:   # gpRoot
	var F := gp_fam()
	var k := int(float(_ks(u)))
	var seen := {}
	while F.has(str(k)) and _tr(F[str(k)].get("cha")) and F.has(_ks(F[str(k)].cha)) and not seen.has(k):
		seen[k] = 1
		k = int(F[str(k)].cha)
	return k

func gp_rel(u) -> Dictionary:   # gpRel
	var F := gp_fam()
	var f = F.get(_ks(u))
	var o := {"cha": [], "con": [], "ae": [], "sui": [], "bc": [], "ban": [], "xom": []}
	if not (f is Dictionary):
		return o
	var ui_ := int(float(_ks(u)))
	for k in gp_keys():
		if k == ui_:
			continue
		var g_: Dictionary = F[str(k)]
		if _i(f.get("cha")) == k and _tr(f.get("cha")):
			o.cha.append(k)
		elif _num(g_.get("cha")) and int(g_.cha) == ui_:
			o.con.append(k)
		elif _tr(f.get("ho")) and g_.get("ho") == f.ho:
			if _tr(f.get("cha")) and _n(g_.get("cha")) == _n(f.cha):
				o.ae.append(k)
			else:
				o.bc.append(k)
	var L = _lang()
	for p in (L.get("sui", []) if L != null and L.get("sui") is Array else []):
		var k := 0
		if _n(p[0]) == ui_:
			k = int(p[1])
		elif _n(p[1]) == ui_:
			k = int(p[0])
		if k and F.has(str(k)) and not o.sui.has(k):
			o.sui.append(k)
	o.ban = (f.get("ban", []) if f.get("ban") is Array else []).filter(func(k): return F.has(_ks(k))).map(func(k): return int(k))
	o.xom = gp_xom(ui_)
	return o

func gp_spread(f: Dictionary, v: int) -> void:   # gpSpread
	if f.is_empty() or not v or not _tr(f.get("hu")):
		return
	var R := gp_rel(f.hu)
	var best := {}
	var F := gp_fam()
	for t in R:
		for k in R[t]:
			if not (best.has(k) and float(best[k]) >= float(GPRATE[t])):
				best[k] = float(GPRATE[t])
	for k in best:
		var g_ = F.get(str(k))
		var d := _rnd(v * float(best[k]) * (0.5 if v < 0 else 1.0))
		if not (g_ is Dictionary) or not d:
			continue
		than_sync(g_)
		g_.dp = maxf(0.0, minf(DPMAX, _n(g_.dp) + d))
		g_.tim = int(floor(float(g_.dp) / 100.0))

func gp_sui_minh(u) -> void:   # gpSuiMinh
	var f = gp_fam().get(_ks(u))
	if not (f is Dictionary) or not _tr(f.get("ho")):
		return
	for k in gp_ho(f.ho):
		var g_: Dictionary = gp_fam()[str(k)]
		than_sync(g_)
		g_.dp = minf(DPMAX, _n(g_.dp) + 50)
		g_.tim = int(floor(float(g_.dp) / 100.0))

func gp_is_sui_minh(k) -> bool:   # gpIsSuiMinh
	var c = G.g.get("cuoi")
	var F := gp_fam()
	if not _tr(c) or not (c is Dictionary):
		return false
	var fc = F.get(_ks(c.get("u")))
	var fk = F.get(_ks(k))
	return fc is Dictionary and fk is Dictionary and fk.get("ho") == fc.get("ho")

func _ng_thieu() -> bool:   # ngThieu
	var M := ng_map()
	var c := {}
	for h in M.ho:
		c[M.ho[h]] = 1
	return c.size() < M6.size()

func gp_assign(u, f: Dictionary) -> void:   # gpAssign
	if _tr(f.get("ho")):
		return
	var F := gp_fam()
	var me_u := int(float(_ks(u)))
	var ks := gp_keys().filter(func(k): return k != me_u and F.has(str(k)) and _tr(F[str(k)].get("ho")))
	if ks.size() and randf() < (0.4 if _ng_thieu() else 0.7):
		var ho = F[str(_t0(ks))].ho
		var mem := ks.filter(func(k): return F[str(k)].ho == ho)
		var nc := {}
		for k in mem:
			var c = F[str(k)].get("cha")
			if _tr(c):
				nc[int(c)] = int(nc.get(int(c), 0)) + 1
		var cand := mem.filter(func(k): return (_n(F[str(k)].get("doi")) if _tr(F[str(k)].get("doi")) else 1.0) <= 4 and int(nc.get(k, 0)) < 3)
		if not cand.size():
			cand = mem.duplicate()
		cand.sort_custom(func(a, b): return int(nc.get(a, 0)) < int(nc.get(b, 0)) or (int(nc.get(a, 0)) == int(nc.get(b, 0)) and a < b))   # sort ổn định như JS
		var p = cand[int(floor(randf() * mini(3, cand.size())))]
		f.ho = ho
		f.cha = p
		f.doi = (_n(F[str(p)].get("doi")) if _tr(F[str(p)].get("doi")) else 1.0) + 1
	else:
		var used := {}
		for k in ks:
			used[F[str(k)].ho] = 1
		var free := HOLIST.filter(func(h): return not used.has(h))
		f.ho = _t0(free if free.size() else HOLIST)
		f.cha = 0
		f.doi = 1
	f.ban = []
	var me = a_r(u).get("id")
	var bp := ks.filter(func(k): return a_r(k).get("id") != me and (F[str(k)].get("ban", []) if F[str(k)].get("ban") is Array else []).size() < 3)
	var n := 1 if randf() < 0.5 else 2
	while n > 0 and bp.size():
		var b = bp.pop_at(int(floor(randf() * bp.size())))
		f.ban.append(b)
		if not (F[str(b)].get("ban") is Array):
			F[str(b)].ban = []
		F[str(b)].ban.append(me_u)
		n -= 1

func _vl_ten_used(u) -> Dictionary:   # vlTenUsed
	var F: Dictionary = _r0().fam
	var o := {}
	for k in _okeys(F):
		if int(k) != int(float(_ks(u))) and _tr(F[k].get("n")):
			var w := String(F[k].n).split(" ")
			o[" ".join(w.slice(1))] = 1
			if w.size() > 2:
				o["#" + w[2]] = 1
	return o

func _xj(a: Array) -> String:   # XUNGT.nam.join()
	var r := []
	for x in a:
		r.append(",".join(PackedStringArray(x)) if x is Array else String(x))
	return ",".join(PackedStringArray(r))

func vl_ten(u, f: Dictionary) -> String:   # vlTen
	var uu := int(float(_ks(u)))
	var R = NV.Yu.new(uu * 131 + 7)
	var w := String(f.get("n", "") if _tr(f.get("n")) else "").split(" ")
	var old: bool = _num(f.get("dp")) and w.size() == 2 and (_xj(XUNGT.nam).find(w[0]) >= 0 or _xj(XUNGT.nu).find(w[0]) >= 0) and THUT.has(w[1])
	if not _tr(f.get("gn")):
		if old:
			f.gn = "nu" if _xj(XUNGT.nu).find(w[0]) >= 0 else "nam"
		else:
			f.gn = "nam" if R.next() < 0.5 else "nu"
	var used := _vl_ten_used(u)
	var L: Array = TENR[String(f.gn)]
	var v1 := mini(2, maxi(0, (int(_n(f.get("doi"))) if _tr(f.get("doi")) else 2) - 1))
	var x: String = w[0] if old else String(_t0(XUNGT[String(f.gn)][v1]))
	# ưu tiên tên riêng chưa ai trong làng mang, hết thì chỉ cần thứ + tên không trùng
	for t in 80:
		var th: String = w[1] if old else String(THUT[int(floor(R.next() * THUT.size()))])
		var tn := String(L[int(floor(R.next() * L.size()))])
		if not used.has(th + " " + tn) and (t >= 40 or not used.has("#" + tn)):
			return x + " " + th + " " + tn
	return x + " " + (w[1] if old else String(THUT[uu % THUT.size()])) + " " + String(L[uu % L.size()]) + " " + str(2 + uu % 8)

func gp_wedding() -> void:   # gpWedding
	var L = _lang()
	if L == null or not _tr(L.get("fam")):
		return
	var d := _vr()
	if not _num(L.get("nw")):
		L.nw = d + 7
		return
	if d < float(L.nw):
		return
	var F := gp_fam()
	var ks := gp_keys().filter(func(k): return _tr(F[str(k)].get("ho")))
	if ks.size() < 2:
		L.nw = d + 3
		return
	var D := tg()
	if _tr(D.get("ev")):
		L.nw = d + 1
		return
	var a = _t0(ks)
	var sui: Array = L.sui if L.get("sui") is Array else []
	var b2 := ks.filter(func(k): return F[str(k)].ho != F[str(a)].ho and not sui.any(func(p): return _has_n(p, a) and _has_n(p, k)))
	if not b2.size():
		L.nw = d + 14
		return
	var b = _t0(b2)
	if not (L.get("sui") is Array):
		L.sui = []
	L.sui.append([a, b])
	L.nw = d + 14
	bk(a, "cuoi")
	_ta("Nhà " + String(F[str(a)].n) + " và nhà " + String(F[str(b)].n) + " kết sui gia! Có thiệp mời ăn đám cưới.")
	_ba()

# ------------------------------------------------------------------ nghề
func t6() -> Dictionary:   # T6: g.nghe
	var n = G.g.get("nghe")
	if not (n is Dictionary):
		n = {}
		G.g.nghe = n
	if not _tr(n.get("_m")):
		n._m = 1
		var o = G.g.get("ng") if G.g.get("ng") is Dictionary else {}
		for x in M6:
			if _tr(o.get(x.id)):
				n[x.id] = 1
				o.erase(x.id)
	return n

func ng_map() -> Dictionary:   # ngMap: g.ngm
	var M = G.g.get("ngm")
	if M is Dictionary and M.get("ord") is Array:
		return M
	var ids := []
	for x in M6:
		ids.append(x.id)
	for i in range(ids.size() - 1, 0, -1):
		var j := int(floor(randf() * (i + 1)))
		var t = ids[i]
		ids[i] = ids[j]
		ids[j] = t
	M = {"ord": ids, "ho": {}, "u": {}}
	G.g.ngm = M
	# bản lưu cũ: nghề cũ theo số nhà M6[(u-1)%10]; họ lấy nghề nhà gốc họ, nhà đang dạy, đã dạy mình giữ nghề cũ
	var L = _lang()
	var F: Dictionary = L.fam if L != null and L.get("fam") is Dictionary else {}
	var old := func(u): return M6[(int(float(_ks(u))) - 1) % M6.size()].id
	var H: Dictionary = G.g.hn.p if G.g.get("hn") is Dictionary and G.g.hn.get("p") is Dictionary else {}
	var T: Dictionary = G.g.nghe if G.g.get("nghe") is Dictionary else {}
	for u in _okeys(F):
		var f = F[u]
		if f is Dictionary and _tr(f.get("ho")) and not _tr(M.ho.get(f.ho)):
			M.ho[f.ho] = old.call(gp_root(u))
	for id in _okeys(H):
		var p = H[id]
		if p is Dictionary and F.has(_ks(p.get("u"))):
			M.u[_ks(p.u)] = id
	for id in _okeys(T):
		if id == "_m" or not _tr(T[id]):
			continue
		var us := _okeys(F).filter(func(k): return old.call(k) == id)
		if us.size():
			M.u[us[0]] = id
	return M

func ng_s() -> Dictionary:   # ngS: g.ngs
	var o = G.g.get("ngs")
	if not (o is Dictionary):
		o = {}
		G.g.ngs = o
	for k in ["xp", "mk", "hq", "sao", "thay"]:
		if not (o.get(k) is Dictionary):
			o[k] = {}
	if not (o.get("chinh") is Array):
		o.chinh = []
	if not (o.get("dp") is Dictionary):
		o.dp = {"d": -1, "n": {}}
	# bản 1 (mốc 15/40/100/200 món): đổi sang thang mới đúng sao đang có, 3 nghề cao nhất làm nghề chính
	if _n(o.get("v")) != 2.0:
		o.v = 2
		var cs := []
		for b in _okeys(o.xp):
			var xp := _n(o.xp[b])
			var s := 5 if xp >= 200 else (4 if xp >= 100 else (3 if xp >= 40 else (2 if xp >= 15 else 1)))
			o.sao[b] = s
			o.xp[b] = NGSAO[s - 1]
			if s > 3:
				cs.append([b, s, cs.size()])
		cs.sort_custom(func(a, c): return a[1] > c[1] or (a[1] == c[1] and a[2] < c[2]))
		o.chinh = cs.slice(0, NGCHINH).map(func(x): return x[0])
		for x in cs.slice(NGCHINH):
			o.sao[x[0]] = 3
			o.xp[x[0]] = NGSAO[2]
	return o

func ng_d() -> Dictionary:   # ngD: g.ndn
	var o = G.g.get("ndn")
	if not (o is Dictionary):
		o = {}
		G.g.ndn = o
	if not (o.get("l") is Array):
		o.l = []
	if not (o.get("k") is Dictionary):
		o.k = {}
	if not _num(o.get("day")):
		o.day = -1
	if not (o.get("bad") is Array):
		o.bad = []
	return o

func ng_t() -> Dictionary:   # ngT: g.ndt
	var o = G.g.get("ndt")
	if not (o is Dictionary):
		o = {}
		G.g.ndt = o
	if not (o.get("my") is Array):
		o.my = []
	if not (o.get("gv") is Dictionary):
		o.gv = {}
	return o

func hn_s() -> Dictionary:   # HN (g.hn: học nghề)
	var o = G.g.get("hn")
	if not (o is Dictionary):
		o = {"a": "", "p": {}}
		G.g.hn = o
	if not _tr(o.get("p")):
		o.p = {}
	return o

func hn_k(id: String, hu: bool) -> void:   # hnK: g.hnk
	var k = G.g.get("hnk")
	if not (k is Dictionary):
		k = {"t": 0, "h": 0, "d": {}}
		G.g.hnk = k
	if not (k.d.get(id) is Dictionary):
		k.d[id] = {"t": 0, "h": 0}
	var d: Dictionary = k.d[id]
	k.t = _n(k.t) + 1
	d.t = _n(d.t) + 1
	if hu:
		k.h = _n(k.h) + 1
		d.h = _n(d.h) + 1

func nghe_by_id(id) -> Variant:   # ngheById
	var r = null
	for x in M6:
		if x.id == id:
			r = x
	return r

func ng_of_house(u) -> Dictionary:   # ngOfHouse
	var F := gp_fam()
	var f = F.get(_ks(u))
	var M := ng_map()
	var id = M.u.get(_ks(u))
	if not _tr(id) and f is Dictionary and _tr(f.get("ho")):
		id = M.ho.get(f.ho)
		if not _tr(id):
			id = ng_next_ho()
			M.ho[f.ho] = id
	if not _tr(id):
		var uu := int(float(_ks(u))) if _tr(float(_ks(u))) else 1
		id = M.ord[(maxi(1, uu) - 1) % M.ord.size()]
	var x = nghe_by_id(id)
	return x if x != null else M6[0]

func a_r(u) -> Dictionary:   # aR
	return ng_of_house(u)

func ng_next_ho() -> String:   # ngNextHo
	var M := ng_map()
	var used := {}
	for h in M.ho:
		used[M.ho[h]] = 1
	for id in M.ord:
		if not used.has(id) and ng_ok_lv(id):
			return id
	var ok: Array = M.ord.filter(func(id): return ng_ok_lv(id))
	var r = ok[int(floor(randf() * ok.size()))] if ok.size() else null
	return r if _tr(r) else M.ord[0]

func ng_ok_lv(id) -> bool:   # ngOkLv
	var x = nghe_by_id(id)
	var lv := _jr()
	if x == null:
		return false
	var bf := _x("Bf")
	for z in x.get("in", []):
		if (int(bf.call(z[0])) if bf.is_valid() else 1) > lv:
			return false
	return true

func nghe_who(id) -> Array:   # ngheWho
	var L = _lang()
	var F: Dictionary = L.fam if L != null and L.get("fam") is Dictionary else {}
	var r := []
	for k in _okeys(F):
		if a_r(k).get("id") == id:
			r.append(F[k].n)
	return r

func ng_id(b: String, h: int) -> String:   # ngId
	return b + String(NGH[h].s)

func ng_has(b: String, h: int) -> int:   # ngHas
	var n := 0
	for k in range(h, 3):
		n += _barn(ng_id(b, k))
	return n

func ng_take(b: String, h: int, q: int) -> Array:   # ngTake
	var out := []
	var k := h
	while k < 3 and q > 0:
		var id := ng_id(b, k)
		var c := mini(q, _barn(id))
		if c > 0:
			G.g.barn[id] = _barn(id) - c
			q -= c
			out.append([id, c])
		k += 1
	return out

func ng_base(id) -> String:   # ngBase
	var re := RegEx.create_from_string("_(k|x)$")
	var b := re.sub(String(id), "")
	return b if nghe_by_id(b) != null and not _ae(b).is_empty() else ""

func hn_learned() -> int:   # hnLearned
	var T := t6()
	var n := 0
	for x in M6:
		if _tr(T.get(x.id)):
			n += 1
	return n

func hn_of(u) -> Variant:   # hnOf
	var x := a_r(u)
	var p = hn_s().p.get(x.id)
	return p if p is Dictionary and _n(p.get("u")) == float(_ks(u)) else null

static func _hn_stuff(arr: Array, k: float) -> Array:   # hnStuff
	return arr.map(func(x): return [x[0], int(ceil(float(x[1]) * k))])

func hn_in1(u, f: Dictionary) -> Array:   # hnIn1
	return _hn_stuff(a_r(u)["in"], 12.0 if f.get("tp") == "kho" else 10.0)

func hn_in3(x: Dictionary) -> Array:   # hnIn3
	return _hn_stuff(x["in"], 2.0)

func hn_have(arr: Array) -> bool:   # hnHave
	return arr.all(func(x): return _barn(x[0]) >= _n(x[1]))

func hn_take(arr: Array) -> void:   # hnTake
	for x in arr:
		G.g.barn[String(x[0])] = _barn(x[0]) - int(x[1])

func hn_miss() -> float:   # hnMiss
	return maxf(0.05, 0.3 + 0.05 * hn_learned() - htv("g_hoc"))

func hn_hp() -> int:   # hnHp
	return _rnd(4000.0 * pow(1.5, hn_learned()) / 100.0) * 100

func fam_likes(u) -> Dictionary:   # famLikes
	var R = NV.Yu.new(int(float(_ks(u))) * 977 + 41)
	var a := THICH.filter(func(id): return not _ae(id).is_empty())
	var out := []
	while out.size() < 3 and a.size():
		out.append(a.pop_at(int(floor(R.next() * a.size()))))
	return {"th": [out[0] if out.size() > 0 else null, out[1] if out.size() > 1 else null], "gh": out[2] if out.size() > 2 else null,
		"ngay": 1 + int(floor(R.next() * 7)), "ly": NGAYN[int(floor(R.next() * NGAYN.size()))]}

func _le_q(id) -> int:   # Math.max(1, Math.round(60 / (ae(id).sell || 10)))
	var s := _n(_ae(id).get("sell"))
	return maxi(1, _rnd(60.0 / (s if s != 0.0 else 10.0)))

func hn_le(u, f: Dictionary) -> Array:   # hnLe
	var L := fam_likes(u)
	var ids: Array = L.th if f.get("tp") == "sd" else [L.th[0]]
	return ids.map(func(id): return [id, _le_q(id)])

func hn_le_ok(u, f: Dictionary) -> bool:   # hnLeOk
	var L := fam_likes(u)
	if f.get("tp") == "sd":
		return hn_have(hn_le(u, f))
	return L.th.any(func(id): return id != null and _barn(id) >= _le_q(id))

func hn_le_take(u, f: Dictionary) -> void:   # hnLeTake
	var L := fam_likes(u)
	if f.get("tp") == "sd":
		hn_take(hn_le(u, f))
		return
	for j in 2:
		var id = L.th[j]
		var q := _le_q(id)
		if _barn(id) >= q:
			G.g.barn[String(id)] = _barn(id) - q
			return

func ng_learned(b: String, u) -> void:   # ngLearned
	var o := ng_s()
	o.thay[b] = int(float(_ks(u)))
	o.hd = _vr()
	o.sao[b] = 1
	o.xp[b] = o.xp.get(b) if _tr(o.xp.get(b)) else 0
	var M := ng_map()
	if not _tr(M.u.get(_ks(u))):
		M.u[_ks(u)] = b

func ng_hoc_cho() -> int:   # ngHocCho
	var o := ng_s()
	return maxi(0, int(o.hd) + 7 - _vr()) if _num(o.get("hd")) and float(o.hd) >= 0 else 0

static func xung(f: Dictionary, t: String) -> String:   # xung
	var p := (String(f.get("n", "")).split(" ")[0]).to_lower()
	var c := "em" if p == "anh" or p == "chị" else "con"
	var up := func(w: String) -> String: return w.substr(0, 1).to_upper() + w.substr(1)
	return t.replace("{x}", p).replace("{X}", up.call(p)).replace("{c}", c).replace("{C}", up.call(c))

func mk(u, a := "") -> void:   # Mk: một bước học nghề ở nhà u; a = "skip" (xong ngay bằng sen đỏ)
	if not _jg("nghe"):   # Mk = t("nghe", Mk)
		return
	var f = _fam_of(u)
	var x := a_r(u)
	var H := hn_s()
	var p = hn_of(u)
	var now := _now()
	if f == null or _tr(t6().get(x.id)):
		return
	if _n(f.get("tim")) < 3:
		_ta("Thân 3 ♥ nhà " + String(f.n) + " mới chịu truyền nghề.")
		return
	if p == null:
		if ng_hoc_cho():
			_ta("Mới học xong nghề trước, " + str(ng_hoc_cho()) + " ngày nữa mới theo học nghề mới được.")
			return
		var nd := hn_in1(u, f)
		if not hn_have(nd):
			_ta("Chưa đủ đồ đem qua xin theo học.")
			return
		hn_take(nd)
		p = {"u": int(float(_ks(u))), "st": 2, "n": 0, "dl": -1, "te": 0, "fl": 0}
		H.p[x.id] = p
		H.a = x.id
		_ta(String(f.n) + " nhận lời dạy " + String(x.n).to_lower() + ". Ghé trò chuyện mỗi ngày để coi thầy làm.")
	elif H.get("a") != x.id:
		H.a = x.id
		_ta("Quay lại theo " + String(f.n) + " học " + String(x.n).to_lower() + ".")
	elif _n(p.st) == 3 and not _tr(p.get("te")):
		if not hn_have(hn_in3(x)):
			_ta("Chưa đủ nguyên liệu làm thử.")
			return
		hn_take(hn_in3(x))
		p.te = now + float(x.tt) * 60000.0
		_ta("Bắt tay làm thử " + String(x.n).to_lower() + ", " + _sv(x.tt) + " phút nữa coi kết quả.")
	elif _n(p.st) == 3 and _n(p.te) > now:
		if a != "skip":
			return
		var c := _ro((_n(p.te) - now) / 1000.0)
		if not _sc(c):
			return
		p.te = now
		mk(u)
		return
	elif _n(p.st) == 3:
		p.te = 0
		var hu := randf() < hn_miss()
		hn_k(x.id, hu)
		if hu:
			p.fl = _n(p.get("fl")) + 1
			_ta(String(f.n) + ': "' + xung(f, String(_t0(HNHU))) + '" Món làm thử bị hư, đem nguyên liệu làm lại.')
		else:
			p.st = 4
			_ta("Món làm thử coi được! Đem qua ra mắt thầy.")
	elif _n(p.st) == 4:
		var hp := hn_hp()
		if _n(G.g.coins) < hp:
			_ta("Cần " + _sa(hp) + " xu tiền học.")
			return
		if not hn_le_ok(u, f):
			_ta("Lễ phải đủ 2 món " + String(f.n) + " thích." if f.get("tp") == "sd" else "Lễ phải có 1 món " + String(f.n) + " thích.")
			return
		G.g.coins = _n(G.g.coins) - hp
		hn_le_take(u, f)
		t6()[x.id] = 1
		ng_learned(x.id, u)
		H.p.erase(x.id)
		if H.get("a") == x.id:
			H.a = ""
		than_add(f, 100)
		ut_add(10, "Học xong nghề " + String(x.n).to_lower())
		_ta(String(f.n) + " nhận lễ, truyền bí quyết " + String(x.n).to_lower() + " gia truyền. Mở bảng Nghề (nhóm Làm ăn) để làm.")
		_gr(30)
	_ba()

func ng_lock() -> int:   # ngLock
	return _qf("nghe")

func ng_sao(b: String) -> int:   # ngSao
	var s := _i(ng_s().sao.get(b))
	return maxi(1, mini(5, s if s else 1))

static func ng_stars(s: int) -> String:   # ngStars
	var t := ""
	for i in range(1, 6):
		t += "★" if i <= s else "☆"
	return t

func ng_chinh(b: String) -> bool:   # ngChinh
	return ng_s().chinh.has(b)

func ng_diem_nay(b: String) -> int:   # ngDiemNay
	var o := ng_s()
	return _i(o.dp.n.get(b)) if _n(o.dp.get("d")) == _vr() else 0

func ng_rate(b: String) -> Array:   # ngRate
	var s := ng_sao(b)
	var d := 0.01 * maxi(0, hn_learned() - 1)
	return [maxf(0.0, float(NGK[s - 1]) - d) + htv("g_kheo"), maxf(0.0, float(NGX[s - 1]) - d) + htv("g_tx")]

func ng_max(b: String) -> int:   # ngMax
	return 5 if ng_chinh(b) else 3

func ng_thay(b: String) -> int:   # ngThay
	var o := ng_s()
	var F: Dictionary = _r0().fam
	var u = o.thay.get(b)
	if _tr(u) and F.has(_ks(u)) and r1(u) != null:
		return int(u)
	for k in _okeys(F):
		if a_r(k).get("id") == b and r1(k) != null:
			return int(k)
	return 0

func ng_thi_cond(b: String) -> Array:   # ngThiCond
	var s := ng_sao(b)
	var t := s + 1
	var T = NGTHI[t] if t < NGTHI.size() else null
	var o := ng_s()
	var r := []
	if not (T is Dictionary) or not _tr(t6().get(b)):
		return r
	var q: Array = o.hq.get(b) if o.hq.get(b) is Array else [0, 0]
	var u := ng_thay(b)
	var f = _r0().fam.get(str(u)) if u else null
	var xp := int(floor(_n(o.xp.get(b))))
	if t > 3:
		r.append([ng_chinh(b), "Là nghề chính (đang có " + str(o.chinh.size()) + "/" + str(NGCHINH) + ")"])
	r.append([xp >= _n(T.xp), "Điểm tay nghề " + _sa(xp) + "/" + _sa(T.xp)])
	if _tr(T.get("mk")):
		r.append([_i(o.mk.get(b)) >= _n(T.mk), "Đã làm " + str(_i(o.mk.get(b))) + "/" + _sv(T.mk) + " món"])
	if _tr(T.get("k")):
		r.append([_n(q[0]) >= _n(T.k), "Đã làm ra " + _sv(q[0]) + "/" + _sv(T.k) + " khéo"])
	if _tr(T.get("x")):
		r.append([_n(q[1]) >= _n(T.x), "Đã làm ra " + _sv(q[1]) + "/" + _sv(T.x) + " tinh xảo"])
	r.append([f is Dictionary and _i(f.get("tim")) >= _n(T.tim), ("Thân thầy " + String(f.n) + " " + _sv(T.tim) + " ♥ (" + str(_i(f.get("tim"))) + ")") if f is Dictionary else "Xóm không còn nhà nào giữ nghề này"])
	for z in T.nop:
		var h := int(z[0])
		r.append([ng_has(b, h) >= _n(z[1]), "Nộp " + _sv(z[1]) + " " + String(NGH[h].n) + (" trở lên" if h < 2 else "") + " (kho có " + str(ng_has(b, h)) + ")"])
	if _tr(T.get("le")) and f is Dictionary:
		var L := hn_le(u, {"tp": "sd"})
		r.append([hn_have(L), "Lễ: " + ", ".join(PackedStringArray(L.map(func(z): return str(z[1]) + " " + String(_ae(z[0]).get("name", "")).to_lower())))])
	if _tr(T.get("xu")):
		r.append([_n(G.g.coins) >= _n(T.xu), "Tiền thi " + _sa(T.xu) + " xu"])
	return r

func ng_thi_ready(b: String) -> bool:   # ngThiReady
	var c := ng_thi_cond(b)
	return c.size() > 0 and ng_sao(b) < ng_max(b) and c.all(func(x): return x[0])

func ht_ngay() -> int:   # htNgay
	return NGNGAY + int(htv("g_dem"))

func q_s(gx: Dictionary) -> bool:   # qS
	return gx["in"].all(func(x): return _barn(x[0]) >= _n(x[1]))

func _ng_tho_mul(b: String) -> float:   # ngThoMul (chưa nối mạng: dr.st != "ok" -> 1)
	var f := _x("ngThoMul")
	return float(f.call(b)) if f.is_valid() else 1.0

func ng_val(it: Array) -> float:   # ngVal
	var a := 0.0
	for z in it:
		a += _ai(ng_id(String(z[0]), int(z[2]))) * _n(z[1]) * _ng_tho_mul(String(z[0]))
	return a

func ng_mk(src: String, key: String, title: String, u, it: Array, dl: int, ut: int, th: int) -> bool:   # ngMk
	var o := ng_d()
	if _tr(o.k.get(key)) or o.l.size() >= 6:
		return false
	it = it.filter(func(z): return ng_base(z[0]) != "")
	if not it.size():
		return false
	o.k[key] = _vr()
	o.l.append({"id": key, "src": src, "t": title, "u": "" if u == null else _ks(u), "it": it.duplicate(true), "dl": dl,
		"xu": _rnd(ng_val(it) * 1.8 / 10.0) * 10, "ut": ut, "th": th})
	return true

func ng_xau() -> int:   # ngXau
	var o := ng_d()
	return int(o.xau) - _vr() if _num(o.get("xau")) and float(o.xau) > _vr() else 0

func ng_phat(d: Dictionary, m: float, why: String) -> void:   # ngPhat
	var o := ng_d()
	var P: Dictionary = NGPHAT.get(String(d.get("src", "")), {})
	var f = _r0().fam.get(String(d.u)) if _tr(d.get("u")) else null
	var msg := why + ' "' + String(d.t) + '"'
	if _tr(P.get("th")) and f is Dictionary:
		msg += than_txt(than_add(f, -_rnd(float(P.th) * m)))
	if _tr(P.get("ut")):
		ut_add(-_rnd(float(P.ut) * m), why + " đơn làng")
		msg += ", −" + str(_rnd(float(P.ut) * m)) + " uy tín"
	var day := _vr()
	o.bad = o.bad.filter(func(x): return day - _n(x) < 7)
	o.bad.append(day)
	if o.bad.size() >= 3 and not ng_xau():
		o.xau = day + 3
		o.bad = []
		msg += ". Bà con xầm xì mình hứa rồi bỏ: 3 ngày không ai đặt hàng."
	_ta(msg + ".")

func ng_gen() -> bool:   # ngGen: đơn làng mỗi ngày (nạn, hội đình, công trình, lễ, đặt hàng, đám cưới)
	var o := ng_d()
	var day := _vr()
	var F: Dictionary = _r0().fam
	var ch := false
	var gone: Array = o.l.filter(func(d): return day > _n(d.dl))
	if gone.size():
		o.l = o.l.filter(func(d): return day <= _n(d.dl))
		for d in gone:
			ng_phat(d, 1, "Bỏ đơn")
		ch = true
	if ng_xau():
		if _n(o.day) != day:
			o.day = day
			ch = true
		return ch
	var tn: Dictionary = G.g.tn.nan if G.g.get("tn") is Dictionary and G.g.tn.get("nan") is Dictionary else {}
	for u in _okeys(tn):
		var nn = tn[u]
		var f = F.get(u)
		if not (f is Dictionary) or _tr(nn.get("x")) or day > _n(nn.d) + 2 or not _tr(NGNAN.get(String(nn.k))):
			continue
		ch = ng_mk("nan", "nan:" + u + ":" + _sv(nn.d), "Nhà " + String(f.n) + " gặp nạn (" + String(TNNAN[String(nn.k)]).to_lower() + ")", u, NGNAN[String(nn.k)], int(nn.d) + 2, 4, 40) or ch
	var cu = G.g.hdn.get("cur") if G.g.get("hdn") is Dictionary else null
	if _tr(cu) and day < _n(cu.d):
		ch = ng_mk("hoi", "hoi:" + _sv(cu.d), "Hội đình cần nhang, rượu cúng, chổi dọn sân", "", NGHOI, int(cu.d), 5, 0) or ch
	if G.g.get("ct") is Dictionary and G.g.ct.get("ds") is Array:
		for x in G.g.ct.ds:
			var b := String(x.id)
			if b.ends_with("2"):
				b = b.substr(0, b.length() - 1)
			var it = NGCT.get(b)
			if not _tr(it) or not _pi().has(x.id):
				continue
			ch = ng_mk("ct", "ct:" + String(x.id) + ":" + _sv(x.d), "Dựng " + String(_pi()[x.id].n).to_lower() + " cần đồ", "", it, day + 4, 5, 0) or ch
	var jb := _x("Jb")
	var fe = jb.call() if jb.is_valid() else null
	if fe is Dictionary and _tr(fe.get("f")) and _n(fe.get("k")) >= 1 and _n(fe.k) <= 3 and _tr(NGLE.get(String(fe.f.id))):
		ch = ng_mk("le", "le:" + String(fe.f.id) + ":" + _sv(fe.d), "Bà con sắm đồ " + String(fe.f.get("sh", "")), "", NGLE[String(fe.f.id)], int(fe.d) - 1, 3, 0) or ch
	if _n(o.day) != day:
		o.day = day
		var us := ut_houses()
		var ks := M6.filter(func(x): return ng_base(x.id) != "")
		if us.size() and ks.size():
			var u = us[int(floor(NV.Me(day, 881) * us.size()))]
			var f = F.get(u)
			var a = ks[int(floor(NV.Me(day, 557) * ks.size()))]
			var b = ks[int(floor(NV.Me(day, 353) * ks.size()))]
			var it := [[a.id, 2 + int(floor(NV.Me(day, 91) * 3)), 0]]
			if b.id != a.id:
				it.append([b.id, 1 + int(floor(NV.Me(day, 77) * 2)), 1 if NV.Me(day, 61) < 0.3 else 0])
			if f is Dictionary:
				ch = ng_mk("thuong", "th:" + str(day), "Nhà " + String(f.n) + " đặt hàng", u, it, day + 2, 1, 20) or ch
			if day % 7 == 3:
				var u2 = us[int(floor(NV.Me(day, 4049) * us.size()))]
				var f2 = F.get(u2)
				if f2 is Dictionary:
					ch = ng_mk("cuoi", "cuoi:" + str(day), "Nhà " + String(f2.n) + " sắp cưới con", u2, NGCUOI, day + 4, 6, 60) or ch
		for k in _okeys(o.k):
			if day - _n(o.k[k]) > 60:
				o.k.erase(k)
		ch = true
	return ch

# ------------------------------------------------------------------ uy tín, chức
func ut_s() -> Dictionary:   # utS: g.ut
	var o = G.g.get("ut")
	if not (o is Dictionary):
		o = {}
		G.g.ut = o
	if not _num(o.get("p")):
		o.p = 0
	if not (_num(o.get("c")) and float(o.c) >= 0):
		o.c = 0
	if not (o.get("ev") is Array):
		o.ev = [0, 0, 0, 0, 0]
	if not (_num(o.get("dam")) and float(o.dam) >= 0):
		o.dam = 0
	if not (o.get("lg") is Array):
		o.lg = []
	# bản 2 chức cũ: Trưởng xóm 1 → 2, Trưởng ấp 2 → 3
	if _n(o.get("v")) != 2.0:
		o.v = 2
		if _n(o.c) > 0:
			o.c = int(o.c) + 1
			o.ev = [0, 1, 1, 1 if int(o.c) > 2 else 0, 0]
		if _tr(o.get("vr")):
			o.vr.c = _n(o.vr.get("c")) + 1
		o.vx = null
		o.w = 0
	var w: int = G.nv.week()
	if not (_n(o.get("w")) > 0):
		o.w = w
	if _n(o.w) != w:
		_ut_week(o)
	if _n(o.c) > 0 and not (_n(o.get("cw")) > 0):
		o.cw = w
	if _n(o.c) > 0 and not _tr(o.get("vx")):
		o.vx = _ut_new_tasks(int(o.c), w)
	return o

func _ut_week(o: Dictionary) -> void:   # utWeek
	var w: int = G.nv.week()
	o.w = w
	if _n(o.c) > 0 and _tr(o.get("vx")):
		var bo := 0
		for t in o.vx.t:
			if not _tr(t.get("ok")):
				bo += 1
				ut_add(-15, "Bỏ việc xóm: " + String(t.n))
		if int(o.c) < 4:
			if _n(o.p) < float(UTP[int(o.c)]):
				o.low = _i(o.get("low")) + 1
			else:
				o.low = 0
			if int(o.low) >= 2:
				var cu := String(UTCHUC[int(o.c)])
				o.c = int(o.c) - 1
				o.low = 0
				o.cw = w
				_ta("Uy tín sút quá lâu, làng họp bầu lại. Bạn thôi làm " + cu + ".")
		elif bo:
			_ta("Tuần rồi Hương cả bỏ việc làng, bà con không đem quà tới biếu.")
		else:
			_ut_bieu()
	o.vx = _ut_new_tasks(int(o.c), w) if _n(o.c) > 0 else null

func _ut_new_tasks(c: int, w: int) -> Dictionary:   # utNewTasks
	var nh := ut_houses().size()
	var t := []
	var hop := func(n: int) -> void:   # hop
		n = maxi(1, mini(n, nh))
		t.append({"k": "hop", "n": "Họp tổ" if c == 1 else "Họp xóm", "d": "Trò chuyện với " + str(n) + " nhà khác nhau trong tuần", "need": n, "ok": 0})
	var xu := func(n: int) -> void:
		t.append({"k": "xu", "n": "Chuyện cực khó" if c == 4 else "Phân xử chuyện xóm", "d": "Trưởng ấp xử không xong, bà con lên nhờ Hương cả" if c == 4 else "Xử " + str(n) + " chuyện bà con nhờ", "need": n, "n2": 0, "ok": 0})
	if c == 1:
		hop.call(3)
		xu.call(1)
	elif c < 4:
		var big := c > 2
		hop.call(8 if big else 5)
		t.append({"k": "gop", "n": "Gom góp cúng đình", "d": "Góp " + _sa(1200 if big else 600) + " xu và " + str(20 if big else 10) + " giạ lúa", "xu": 1200 if big else 600, "it": [["lua", 20 if big else 10]], "ok": 0})
		t.append({"k": "don", "n": "Dọn đường làng", "d": "Đem " + str(40 if big else 20) + " củi khô đốt cỏ, đắp ổ gà", "it": [["cui", 40 if big else 20]], "ok": 0})
		xu.call(2 if big else 1)
	else:
		t.append({"k": "gop", "n": "Chủ trì cúng đình", "d": "Lễ lớn: " + _sa(2000) + " xu, 30 giạ lúa và 10 nhang trầm", "xu": 2000, "it": [["lua", 30], ["nhang", 10]], "ok": 0})
		xu.call(1)
	return {"w": w, "hop": {}, "xu": null, "t": t}

func ut_add(v: float, why := "") -> String:   # utAdd
	if v > 0:
		v = _rnd(v * (1.0 + htv("l_uy")))
	var o := ut_s()
	var p0 := _n(o.p)
	o.p = maxf(0.0, minf(1000.0, p0 + v))
	if why != "" and _n(o.p) != p0:
		o.lg.push_front([v, why])
		o.lg.resize(mini(6, o.lg.size()))
	return ""

func _ut_bieu() -> void:   # utBieu
	var F: Dictionary = _r0().fam
	var hs := ut_houses().filter(func(u): return _i(F[u].get("tim")) >= 3).slice(0, 4)
	var got := []
	var s2 := _x("s2")
	for u in hs:
		var L: Array = WC.s2() if WC != null else (s2.call() if s2.is_valid() else [])
		var id = _t0(L)
		var n := maxi(1, _rnd(150.0 / (_n(_ae(id).get("sell")) if _n(_ae(id).get("sell")) != 0.0 else 10.0)))
		G.g.barn[String(id)] = _barn(id) + n
		got.append(F[u].n)
	if got.size():
		_ta(", ".join(PackedStringArray(got)) + " đem quà tới biếu Hương cả.")

func ut_houses() -> Array:   # utHouses
	return _okeys(_r0().fam).filter(func(u): return r1(u) != null)

func ut_lang() -> Dictionary:   # utLang
	var o := {"nha": 0, "dan": 0, "ngoi": 0}
	for h in bl():
		var id := String(h.r.id)
		o.nha += 1
		o.dan += _i(CX.get(id, 0))
		if id.begins_with("house") or id.begins_with("bagian"):
			o.ngoi += 1
	return o

func ut_to() -> Array:   # utTo
	var k := [6.25, 4.35]   # _T
	var a := []
	var hs := ut_houses()
	for i in hs.size():
		var r = r1(hs[i]).r
		a.append([hs[i], Vector2(float(r.gx) - k[0], float(r.gy) - k[1]).length(), i])
	a.sort_custom(func(p, q): return p[1] < q[1] or (p[1] == q[1] and p[2] < q[2]))
	return a.slice(0, 5).map(func(x): return x[0])

func ct_ten(bac: int) -> String:   # ctTen
	var a := []
	for k in CTB:
		if int(CTB[k]) == bac and _pi().has(k):
			a.append(_pi()[k].n)
	return ", ".join(PackedStringArray(a))

func _ct_built() -> Dictionary:   # ctBuilt
	return WR.ct_built() if WR != null else {1: 0, 2: 0, 3: 0, "dinh": false}

func ut_cond(c: int) -> Array:   # utCond: điều kiện lên chức c, mỗi dòng [đạt, chữ, chữ nhỏ]
	var o := ut_s()
	var F: Dictionary = _r0().fam
	var hs := ut_houses()
	var lv := _jr()
	var Lg := ut_lang()
	var Lc: Array = UTLANG[c]
	var cb := _ct_built()
	var r := []
	var than_qua_nua := func(ds: Array, n: int) -> Array:   # thanQuaNua
		var th := ds.filter(func(u): return _i(F[u].get("tim")) >= n).size()
		return [ds.size() > 0 and th * 2 > ds.size(), "Quá nửa " + ("số nhà" if ds.size() == hs.size() else "tổ") + " thân từ " + str(n) + " ♥ (" + str(th) + "/" + str(ds.size()) + ")"]
	if c > 1:
		var wk: int = G.nv.week() - _i(o.get("cw"))
		r.append([_n(o.c) == c - 1 and wk >= int(UTTUAN[c]), "Làm " + String(UTCHUC[c - 1]) + " đủ " + _sv(UTTUAN[c]) + " tuần (" + str(wk if _n(o.c) == c - 1 else 0) + ")"])
	r.append([_n(o.p) >= float(UTP[c]), "Uy tín " + _sv(UTP[c]) + " (" + _sv(o.p) + ")"])
	r.append([lv >= int(UTLV[c]), "Cấp " + _sv(UTLV[c]) + " (" + str(lv) + ")"])
	r.append([Lg.nha >= int(Lc[0]) and Lg.dan >= int(Lc[1]) and Lg.ngoi >= int(Lc[2]), "Làng có " + _sv(Lc[0]) + " nhà, " + _sv(Lc[1]) + " dân" + ((", " + _sv(Lc[2]) + " nhà ngói") if _tr(Lc[2]) else ""), "Đang có " + str(Lg.nha) + " nhà, " + str(Lg.dan) + " dân" + ((", " + str(Lg.ngoi) + " nhà ngói hoặc ba gian") if _tr(Lc[2]) else "")])
	if c == 1:
		r.append([int(cb[1]) >= 1, "1 công trình bậc xóm (" + str(cb[1]) + ")", ct_ten(1)])
		r.append(than_qua_nua.call(ut_to(), 2))
	if c == 2:
		r.append([int(cb[1]) >= 3, "3 công trình bậc xóm (" + str(cb[1]) + ")", ct_ten(1)])
		r.append([_n(o.dam) >= 3, "Đã đi 3 đám (" + _sv(o.dam) + ")"])
		r.append(than_qua_nua.call(hs, 2))
	if c == 3:
		r.append([int(cb[2]) >= 3, "3 công trình bậc ấp (" + str(cb[2]) + ")", ct_ten(2)])
		r.append(than_qua_nua.call(hs, 3))
	if c == 4:
		r.append([bool(cb.dinh) and int(cb[2]) >= 2, "Có Đình làng và 2 công trình bậc ấp", "Đình: " + ("có" if cb.dinh else "chưa") + " · bậc ấp: " + str(cb[2])])
		r.append([_tr(G.g.get("cuoi")), "Đã kết hôn"])
	if c >= 2:
		var nl := hn_learned()
		var nd := _i(ng_s().get("don"))
		var NQ: int = [0, 0, 1, 2, 3][c]
		var DQ: int = [0, 0, 0, 10, 30][c]
		r.append([nl >= NQ and nd >= DQ, "Học " + str(NQ) + " nghề" + ((", giao " + str(DQ) + " đơn làng") if DQ else ""), "Đang có " + str(nl) + " nghề" + ((", " + str(nd) + " đơn") if DQ else "")])
	return r

# ------------------------------------------------------------------ công trình chung, thiên tai, thư, g.lg
func ct_s() -> Dictionary:   # ctS: g.ct
	var o = G.g.get("ct")
	if not (o is Dictionary):
		o = {}
		G.g.ct = o
	# 09/11: bỏ chọi trâu, dọn trâu nhà và phần chọi trâu từng lưu chung g.ct
	if _tr(G.g.get("trau")):
		G.g.erase("trau")
	if o.has("tix") or o.has("win"):
		for k in ["win", "lose", "lad", "day", "tix", "w", "p", "wp"]:
			o.erase(k)
	if not (o.get("tok") is Dictionary):
		o.tok = {}
	if not (o.get("bia") is Dictionary):
		o.bia = {}
	if not (o.get("ds") is Array):
		o.ds = [o.cur] if _tr(o.get("cur")) else []
		o.erase("cur")
	o.ds = o.ds.filter(func(x): return _tr(x) and x is Dictionary and _n(CTB.get(String(x.get("id", "")))) > 1)
	return o

func tn_s() -> Dictionary:   # tnS: g.tn
	var o = G.g.get("tn")
	if not (o is Dictionary):
		o = {}
		G.g.tn = o
	if not (o.get("p") is Dictionary):
		o.p = {}
	if not (o.get("nan") is Dictionary):
		o.nan = {}
	if not (o.get("log") is Array):
		o.log = []
	if not _num(o.get("last")):
		o.last = _vr()
	return o

func tn_ok() -> bool:   # tnOk
	return _jr() >= TNLV

func tn_sea(day: int) -> int:   # tnSea (ip: chưa có giờ thử)
	if G.cfg.s != "auto":
		return int(G.cfg.s)
	return int(floor(posmod(day, 28) / 7.0))   # nQ

func _tn_fest(day: int) -> bool:   # tnFest
	return NV.fest_day(day - 1) or NV.fest_day(day)

func tn_ev_of(mon: int, j: int) -> Dictionary:   # tnEvOf
	var day := mon * 28 + (17 if j else 4) + int(floor(NV.Me(mon * 13 + j * 7 + 5, 4421) * 9))
	var tries := 0
	while tries < 2 and _tn_fest(day):
		day += -1 if j else 1
		tries += 1
	var si := tn_sea(day)
	var W: Array = TNW[si] if si >= 0 and si < TNW.size() and _tr(TNW[si]) else TNW[0]
	var rr: float = NV.Me(mon * 31 + j * 3 + 1, 977)
	var acc := 0.0
	var kind = W[W.size() - 1][0]
	for x in W.size():
		acc += float(W[x][1])
		if rr < acc:
			kind = W[x][0]
			break
	return {"d": day, "k": kind}

func tn_on(day: int) -> Variant:   # tnOn
	var mon := int(floor(day / 28.0))
	for j in 2:
		var ev := tn_ev_of(mon, j)
		if int(ev.d) == day:
			return ev
	return null

func eg() -> Dictionary:   # Eg: g.thu
	var t = G.g.get("thu")
	if not (t is Dictionary):
		t = {"d": -1, "un": null, "rq": null, "rd": -1}
		G.g.thu = t
	return t

func lg_s() -> Dictionary:   # lgS: g.lg
	var o = G.g.get("lg")
	if not (o is Dictionary) or not (o.get("q") is Array):
		o = {"q": []}
		G.g.lg = o
	return o

# ------------------------------------------------------------------ chuyện làng
func clg_s() -> Dictionary:   # clgS: g.clg
	if _tr(G.g.get("st")):
		G.g.erase("st")
	var o = G.g.get("clg")
	if not (o is Dictionary):
		o = {}
		G.g.clg = o
	if not (o.get("l") is Array):
		o.l = []
	if not _num(o.get("q")):
		o.q = 0
	if not _num(o.get("sn")):
		o.sn = o.q
	if not (o.get("rec") is Dictionary):
		o.rec = {}
	if not _num(o.get("lv")):
		o.lv = _jr()
	return o

func clg_add(k: String, t, a = null) -> Variant:   # clgAdd
	if not _tr(t):
		return null
	var o := clg_s()
	var re := RegEx.create_from_string("\\s+")
	t = re.sub(String(t), " ", true).strip_edges()
	if t == "":
		return null
	o.q = int(o.q) + 1
	var r := {"q": o.q, "d": _vr(), "k": k if CLGK.has(k) else "xom", "t": t}
	if _tr(a):
		r.a = a
	o.l.push_front(r)
	if o.l.size() > CLGMAX:
		o.l.resize(CLGMAX)
	return r

func clg_who(m: Dictionary, hs: Array) -> Variant:   # clgWho
	var F: Dictionary = _r0().fam
	var c := String(m.get("c", ""))
	if c == "":
		return [0, 0]
	if c == "A":
		var cc := hs.filter(func(u): return not _tr(m.get("tp")) or F[u].get("tp") == m.tp)
		return [_t0(cc), 0] if cc.size() else null
	if c == "AB":
		if hs.size() < 2:
			return null
		var a = _t0(hs)
		var b = _t0(hs.filter(func(u): return u != a))
		return [a, b]
	if c == "sui":
		var L = _lang()
		var P: Array = (L.sui if L != null and L.get("sui") is Array else []).filter(func(pp): return F.has(_ks(pp[0])) and F.has(_ks(pp[1])))
		if not P.size():
			return null
		var p = _t0(P)
		return [_ks(p[0]), _ks(p[1])] if randf() < 0.5 else [_ks(p[1]), _ks(p[0])]
	if c == "ae":
		var H := {}
		for u in hs:
			var h = F[u].get("ho")
			if _tr(h):
				if not H.has(h):
					H[h] = []
				H[h].append(u)
		var L2 := H.keys().filter(func(h): return H[h].size() > 1)
		if not L2.size():
			return null
		var Gg: Array = H[_t0(L2)]
		var x = _t0(Gg)
		return [x, _t0(Gg.filter(func(u): return u != x))]
	return null

func _clg_fill(t: String, A, B) -> String:   # clgFill
	var F: Dictionary = _r0().fam
	var cay = _t0(XO)
	var ca = _t0(WF)
	var mon = _t0(PT)
	var nm := func(id, d: String) -> String:   # (ae(id) || {name: d}).name.toLowerCase()
		var e := _ae(id)
		return String(e.get("name", d) if not e.is_empty() else d).to_lower()
	t = t.replace("{A}", String(F[_ks(A)].n) if _tr(A) and F.has(_ks(A)) else "Bà con")
	t = t.replace("{B}", String(F[_ks(B)].n) if _tr(B) and F.has(_ks(B)) else "hàng xóm")
	t = t.replace("{cay}", nm.call(cay, "rau"))
	t = t.replace("{mon}", nm.call(mon, "canh chua"))
	t = t.replace("{ca}", nm.call(ca, "cá rô"))
	t = t.replace("{con}", String(_t0(CLGCON)))
	t = t.replace("{so}", str(6 + int(floor(randf() * 7))))
	return t

func _clg_gen(day: int) -> void:   # clgGen
	var o := clg_s()
	var hs := ut_houses()
	var sea := tn_sea(day)
	var n := 2 + int(floor(randf() * 3))
	var used := {}
	var pool := []
	for i in CLGT.size():
		var m: Dictionary = CLGT[i]
		if not (_n(o.rec.get(str(i))) > day - 7 and o.rec.has(str(i))) and (not _tr(m.get("s")) or _has_n(m.s, sea)):
			pool.append(i)
	var k := 0
	while k < n and pool.size():
		var tries := 0
		while tries < 12 and pool.size():
			tries += 1
			var j := int(floor(randf() * pool.size()))
			var i: int = pool[j]
			var m: Dictionary = CLGT[i]
			var who = clg_who(m, hs)
			pool.remove_at(j)
			if who == null:
				continue
			if _tr(m.get("c")) and (used.has(_ks(who[0])) or (_tr(who[1]) and used.has(_ks(who[1])))):
				continue
			used[_ks(who[0])] = 1
			if _tr(who[1]):
				used[_ks(who[1])] = 1
			var r = clg_add("xom", _clg_fill(String(m.t), who[0], who[1]), {"i": i, "u": who[0], "v": who[1]} if _tr(m.get("a")) else null)
			if r != null:
				r.d = day
			o.rec[str(i)] = day
			break
		k += 1

func clg_tick(dt: float) -> void:   # clgTick
	CLGT0 -= dt
	if CLGT0 > 0:
		return
	CLGT0 = 2
	if _cr():
		return
	var o := clg_s()
	var day := _vr()
	var ch := false
	if not _num(o.get("d")):
		o.d = day - 1
	if day > _n(o.d):
		for x in range(maxi(int(o.d) + 1, day - 1), day + 1):
			_clg_gen(x)
		o.d = day
		ch = true
	var nx = tn_on(day + 1) if tn_ok() else null
	if nx != null and _n(o.get("tb")) != day + 1:
		o.tb = day + 1
		clg_add("tt", "Tin báo: " + String(TNK[String(nx.k)].w).to_lower() + ". " + String(TNK[String(nx.k)].d))
		ch = true
	var lv := _jr()
	if lv > _n(o.lv):
		for y in range(int(o.lv) + 1, lv + 1):
			clg_add("nha", "Nhà mình lên cấp " + str(y) + ".")
		o.lv = lv
		ch = true
	elif lv < _n(o.lv):
		o.lv = lv
	var cw = G.g.get("cuoi")
	if _tr(cw) and not _tr(o.get("cw")):
		o.cw = 1
		clg_add("nha", "Nhà mình cưới " + (String(cw.n) if _tr(cw.get("n")) else "được người thương") + ", cả xóm tới mừng.")
		ch = true
	if ch:
		_ba()
	var fr := _x("clgRender")   # bảng Chuyện làng (hệ khác)
	if fr.is_valid():
		fr.call(false)

# ------------------------------------------------------------------ đám cưới, đám giỗ (g.dam)
func zm() -> float:   # zm: giờ game tuyệt đối
	return _vr() * 24 + _d0()

func tg() -> Dictionary:   # Tg: g.dam
	var t = G.g.get("dam")
	if not (t is Dictionary):
		t = {"nt": zm() + _nn(3, 8), "ev": null}
		G.g.dam = t
	if not _num(t.get("nt")):
		t.nt = zm() + 5
	return t

static func qm(t: Dictionary) -> String:   # qm
	return ("Đám cưới" if t.get("k") == "cuoi" else "Đám giỗ") + " nhà " + String(t.n)

func sg() -> Variant:   # Sg: đám đang đãi
	var t = tg().get("ev")
	if not _tr(t):
		return null
	var a := zm()
	return t if a >= _n(t.t0) and a < _n(t.t1) else null

func bk(u0 = null, k0 := "") -> void:   # bk: thiệp mời đám
	if _qf("dam"):   # bk bọc: if (!qf("dam"))
		return
	var t := tg()
	var a = _lang()
	if a == null or not _tr(a.get("fam")) or _tr(t.get("ev")):
		return
	var n := _okeys(a.fam)
	if not n.size():
		return
	var _w := []
	for k in n:
		var _g: Dictionary = a.fam[k]
		var i := 1 + (4 if _n(_g.get("tim")) >= 2 else 0) + (2 if _g.get("tp") == "vui" else 0)
		while i > 0:
			_w.append(k)
			i -= 1
	var e := int(float(_ks(u0))) if u0 != null and a.fam.has(_ks(u0)) else int(_t0(_w))
	var o := k0 if k0 != "" else ("cuoi" if randf() < 0.35 else "gio")
	if o == "gio":
		e = gp_root(e)
	var r: Dictionary = a.fam[str(e)]
	var l := zm()
	var c := _d0()
	var s := 17.0 if o == "cuoi" else 10.0
	var f := l + fmod(s - c + 24.0, 24.0)
	if f - l < 1:
		f += 24
	if f - l > 14:
		f = l + _nn(1.5, 3)
	t.ev = {"u": e, "n": r.n, "k": o, "t0": f, "t1": f + 3, "done": 0, "inv": l}
	var h := int(floor(fmod(f, 24.0)))
	_ta("Thiệp mời: " + qm(t.ev) + " lúc " + ("0" if h < 10 else "") + str(h) + ":00. Nhớ ghé dự, đem phong bì hay chút quà.")
	_ba()

func yk(t: String) -> bool:   # YK: đi đám (t = "lon" | "nho" | "qua")
	var a = sg()
	if a == null or _tr(a.get("done")):
		return false
	var n = _fam_of(a.u)
	if n == null:
		return false
	var e := _v1()
	var r := _rnd(300.0 * (1 + e)) if t == "lon" else (_rnd(100.0 * (1 + e)) if t == "nho" else 0)
	var o = null
	if t == "qua":
		for f in ["gio_lb", "banh_pt", "mat_ong", "qua_xoai", "qua_dua", "banh"]:
			if _barn(f) >= (3 if f == "qua_xoai" or f == "qua_dua" else 1):
				o = f
				break
		if o == null:
			_ta("Kho chưa có món gì làm quà (giỏ lục bình, bánh phu thê, mật ong, 3 trái xoài/dừa, bánh mì).")
			return false
		G.g.barn[o] = _barn(o) - (3 if o == "qua_xoai" or o == "qua_dua" else 1)
	else:
		if _n(G.g.coins) < r:
			_ta("Không đủ " + _sa(r) + " xu bỏ phong bì.")
			return false
		G.g.coins = _n(G.g.coins) - r
	var _dh := than_add(n, 200 if t == "lon" or t == "qua" else 100)
	than_seen(n)
	a.done = 1
	var c := _fr()
	c.en = G.en_max()
	c.bf = {"k": "mat", "u": _now() + 10 * 6e4}
	_ta(("Chúc mừng cô dâu chú rể! " if a.k == "cuoi" else "Thắp nhang ông bà xong ngồi ăn đám. ") + 'Ăn no nê, đầy sức, được "No ấm" 10 phút. ' + String(n.n) + " quý bạn lắm" + than_txt(_dh) + ".")
	_gr(30)
	_qi("dam")
	_ba()
	return true

func dam_tick(t: float) -> void:   # $K
	SS -= t
	if SS > 0:
		return
	SS = 1
	if _cr():
		return
	var a := tg()
	var n := zm()
	if _tr(a.get("ev")) and n >= _n(a.ev.t1):
		if not _tr(a.ev.get("done")):
			var e = _fam_of(a.ev.u)
			if e != null:
				_ta(String(a.ev.n) + " trách bạn không ghé " + ("đám cưới" if a.ev.k == "cuoi" else "đám giỗ") + than_txt(than_add(e, -60)) + ut_add(-20, "Bỏ đám nhà " + String(e.n)) + ".")
		a.ev = null
		a.nt = n + _nn(20, 40)
		_ba()
	if not _tr(a.get("ev")) and n >= _n(a.nt) and _mode() == "off":
		a.nt = n + _nn(20, 40)
		bk()
	var ft := _x("tU")   # nút viên "Đám … nhà …" (giao diện của hệ khác)
	if ft.is_valid():
		ft.call()

# ------------------------------------------------------------------ cưới hỏi (g.cuoi)
func n_r(t) -> Dictionary:   # nR: người con nhà t mình rước về
	var a := "nu" if G.g.pc.get("g") == "nu" else "nam"
	var n := "nam" if a == "nu" else "nu"
	var e: Array = EU if n == "nu" else CU
	var u := int(float(_ks(t)))
	return {"n": e[u * 3 % e.size()], "g": n, "ao": ["#d86a8a", "#3a6a8a", "#7a3a8c", "#2f7a4a", "#c0503a"][u % 5]}

func b_s() -> Dictionary:   # BS: sính lễ
	return {"xu": G.nv.v0(3e3 * (1 + 0.5 * _v1())), "it": [["qua_dudu", 4], ["trung", 6], ["banh_pt", 2]]}

func n_s() -> bool:   # NS: đủ sính lễ
	var t := b_s()
	if _n(G.g.coins) < t.xu:
		return false
	return t.it.all(func(n): return (ng_has("banh_pt", 0) if n[0] == "banh_pt" else _barn(n[0])) >= n[1])

func sk(t) -> void:   # Sk: dạm hỏi, cưới
	if not _jg("cuoi"):   # Sk = t("cuoi", Sk)
		return
	var a = _fam_of(t)
	if a == null or _tr(G.g.get("cuoi")):
		return
	if _n(a.get("tim")) < 5:
		_ta("Thân đủ 5 ♥ mới dạm hỏi được.")
		return
	if not n_s():
		_ta("Chưa đủ mâm quả và tiền dẫn cưới.")
		return
	var n := b_s()
	G.g.coins = _n(G.g.coins) - n.xu
	for o in n.it:
		if o[0] == "banh_pt":
			ng_take("banh_pt", 0, o[1])
			continue
		G.g.barn[o[0]] = _barn(o[0]) - int(o[1])
	var r := n_r(t)
	G.g.cuoi = {"u": int(float(_ks(t))), "n": r.n, "g": r.g, "ao": r.ao, "day": _vr(), "kid": null, "eat": -1, "ew": 0}
	gp_sui_minh(t)
	var fi := _x("i1")   # i1: đóng bảng nhà dân
	if fi.is_valid():
		fi.call()
	_ta("Bưng mâm quả qua nhà " + String(a.n) + " dạm hỏi, rồi rước " + String(r.n) + " về làm " + ("vợ" if r.g == "nu" else "chồng") + "! Cả xóm tới ăn đám cưới linh đình.")
	_gr(40)
	_qi("cuoi")
	var kr := _x("ku_reset")   # typeof ku != "undefined" && (ku.t = 0): bộ đếm của hệ khác
	if kr.is_valid():
		kr.call()
	_ba()

func ck() -> int:   # Ck: số ngày từ 3 ngày sau cưới (-1: chưa cưới)
	var t = G.g.get("cuoi")
	return _vr() - int(t.day) - 3 if _tr(t) else -1

func cuoi_step(t: float) -> void:   # zU (phần luật: có em bé, vợ / chồng tưới giùm; đi lại của L0 / bo là vẽ)
	var a = G.g.get("cuoi")
	if not _tr(a) or _cr():
		return
	if not _tr(a.get("kid")) and ck() >= 0:
		var n := "nam" if randf() < 0.5 else "nu"
		a.kid = {"g": n, "n": _t0(LU[n])}
		_ta("Nhà mình có thêm em bé: " + String(a.kid.n) + "! Cả xóm qua mừng.")
		_ba()
	a.ew = _n(a.get("ew")) + t
	if a.ew > 45:
		a.ew = 0
		for f in mini(G.B0, 12):
			var s: Dictionary = G.g.plots[f]
			if _tr(s.get("u")) and _tr(s.get("c")) and not G.ripe(s) and _n(s.get("w")) < 2 and G.owned(f):
				s.w = G.water_hold(s)
				var h: Dictionary = G.cells[f]
				if _wr(h.gx, h.gy, 0):
					G.float_text.emit(float(h.gx) + 0.5, float(h.gy) + 0.5, String(a.n) + " tưới giùm")
				break

func nu() -> void:   # NU: chạm vợ / chồng: dọn cơm nhà
	var t: Dictionary = G.g.cuoi
	var a := _vr()
	var n := _fr()
	if _n(t.get("eat")) != a:
		t.eat = a
		n.en = minf(G.en_max(), _n(n.en) + 60)
		_ta(String(t.n) + " dọn mâm cơm nhà: canh chua, cá kho, rau luộc. Ăn xong khỏe re (+60 sức).")
	else:
		_ta(String(_t0(['"Mình ơi, chiều nay nhớ về sớm nha."', '"Ruộng đằng đông lúa sắp chín rồi đó."', '"Bữa nay trời đẹp, đi chợ nổi mua ít cây giống không?"', '"Thằng nhỏ hỏi ba/má hoài à."'])).replace("ba/má", "má" if n.get("g") == "nu" else "ba"))
	_ba()

func ru() -> void:   # RU: chạm em bé
	var t = G.g.get("cuoi")
	if not _tr(t) or not _tr(t.get("kid")):
		return
	var a := _fr()
	if randf() < 0.4:
		a.en = minf(G.en_max(), _n(a.en) + 5)
		_ta(String(t.kid.n) + " chạy lại ôm, đưa cho bông hoa dại hái ngoài đồng (+5 sức).")
	else:
		_ta(String(t.kid.n) + ": " + String(_t0(['"Đi thả diều đi!"', '"Con muốn ăn chè!"', '"Hồi nãy con thấy con cá kèo nhảy!"', '"Bế con đi chơi đi!"'])))
	G.changed.emit()

# ------------------------------------------------------------------ người làm thuê
func lm() -> Array:   # lm: nhà đang làm ruộng
	var t: Dictionary = _r0().fam
	var a := []
	for n in t:
		if t[n].get("job") == "ruong":
			a.append(int(float(_ks(n))))
	a.sort()
	return a

func _gg() -> Array:   # gg
	return WR.gg() if WR != null else []

func qq(t: int) -> int:   # qq: ô ruộng t do nhà nào làm
	var a := lm()
	if not a.size():
		return 0
	var e := _gg().find(t)
	if e < 0:
		return 0
	var i := int(floor(e / 12.0))
	return a[i] if i < a.size() else 0

func bq(t: int) -> String:   # Bq: cây người làm thuê gieo ở ô t
	var a: Dictionary = G.g.plots[t]
	var n := qq(t)
	var e = _fam_of(n) if n else null
	var r: String
	if e != null and _tr(e.get("crop")) and G.D.crops.has(String(e.crop)):
		r = String(e.crop)
	elif G.D.crops.has(String(a.get("lc", ""))):
		r = String(a.lc)
	else:
		r = String(G.g.get("sel", ""))
	var c7 := _x("c7")
	return String(c7.call(r)) if c7.is_valid() else r

func ed(t: int) -> String:   # ED: tên nhà làm ô t
	var a := lm()
	if not a.size():
		return ""
	var e := _gg().find(t)
	if e < 0:
		return ""
	var i := int(floor(e / 12.0))
	var r = a[i] if i < a.size() else 0
	var f = _fam_of(r) if r else null
	return String(f.n) if f != null else ""

func nq() -> bool:   # Nq: có ai đang làm thuê
	var t = _lang()
	if t == null or not _tr(t.get("fam")):
		return false
	for a in t.fam:
		if _tr(t.fam[a].get("job")):
			return true
	return false

func wage(t: Dictionary) -> int:   # $5: công mỗi phút
	var j = t.get("job")
	var a := 10 if j == "ruong" else (12 if j == "vuon" or j == "chan" else 14)
	return maxi(3, _rnd(a * (1 + 0.5 * _v1()) * (1 - 0.08 * _n(t.get("tim"))) * (0.85 if t.get("tp") == "cham" else 1.0)))

func om(t: Dictionary, a) -> int:   # om: công nếu làm việc a
	var n = t.get("job")
	t.job = a
	var e := wage(t)
	t.job = n
	return e

func r_c() -> bool:   # rC: ngoài giờ làm (hh: giờ thử, chưa có)
	if G.cfg.d == "day":
		return false
	if G.cfg.d == "night":
		return true
	var t := _d0()
	return not (t >= 6 and t < 11.5 or t >= 13 and t < 18)

func zk(t) -> bool:   # Zk: người nhà t đang đi chơi
	var f := _x("E2")
	var a = f.call(_ks(t)) if f.is_valid() else null
	return a is Dictionary and a.get("st") != "home"

func e_c(t) -> bool:   # eC: rảnh để ra quán / sạp
	var n = _fam_of(t)
	return n != null and (not _tr(n.get("job")) or r_c()) and not zk(t)

func tu(t) -> bool:   # Tu: đang làm mà nghỉ (ngoài giờ / đi chơi)
	var n = _fam_of(t)
	if n == null or not _tr(n.get("job")):
		return false
	return r_c() or zk(t)

func ld(t: float) -> void:   # LD: trả công theo phút
	var a = _lang()
	if a == null or not _tr(a.get("fam")):
		return
	var n := []
	for e in _okeys(a.fam):
		var r: Dictionary = a.fam[e]
		if not _tr(r.get("job")):
			r.wt = 0
			continue
		if t < 5 and tu(e):
			continue
		r.wt = _n(r.get("wt")) + t
		while r.wt >= 60:
			r.wt -= 60
			var o := wage(r)
			if _n(G.g.coins) >= o:
				G.g.coins = _n(G.g.coins) - o
				a.paid = _n(a.get("paid")) + o
			else:
				r.job = null
				r.wt = 0
				n.append(String(r.n) + than_txt(than_add(r, -15)))
				break
	if n.size():
		_ta(", ".join(PackedStringArray(n)) + " nghỉ làm vì chưa đủ tiền trả công.")

func rq(t: float, a: bool) -> void:   # Rq: mỗi khung (a = đang chạy bù / ẩn trang)
	if _lang() == null:
		return
	ld(t)
	if WR != null:
		WR.td(t)
	if a:
		var f := _x("AD")
		if f.is_valid():
			f.call(t)

func k_s(t) -> float:   # kS: tỉ lệ bể hụi theo thân chủ hụi
	var a = _fam_of(t)
	var n := _n(a.get("tim")) if a != null else 0.0
	return maxf(0.006, 0.05 - 0.009 * n)

func c_count(t: int) -> int:   # $C: số nhà thân từ t ♥
	var a = _lang()
	var n := 0
	if a != null and _tr(a.get("fam")):
		for e in a.fam:
			if _n(a.fam[e].get("tim")) >= t:
				n += 1
	return n

func e_y(t) -> void:   # eY: học nghề làm thuê xong ngay bằng sen đỏ
	var a = _fam_of(t)
	if a == null or not _tr(a.get("tt")):
		return
	var n := (_n(a.tt) - _now()) / 1e3
	if n <= 0:
		return
	var e := _ro(n)
	if not _sc(e):
		return
	y_i(t, a)
	_ba()

func y_i(_t, a: Dictionary) -> void:   # yI
	a.tt = 0
	a.ts = mini(5, _i(a.get("ts")) + 1)
	_ta(String(a.n) + " học nghề xong, " + String(W3[String(a.tal)].n).to_lower() + " lên " + _sv(a.ts) + "★!")
	var fs := _x("sig_reset")   # $r.sig = "": bảng nhà dân dựng lại
	if fs.is_valid():
		fs.call()

func x9(t, a) -> Variant:   # x9: sở trường làm thuê
	if not (a is Dictionary):
		return null
	if not _tr(W3.get(String(a.get("tal", "")))):
		var tn := int(float(_ks(t))) if _ks(t).is_valid_float() else 0   # +t || 0
		a.tal = AY[(tn * 7 + 3) % 4]
	if not (_n(a.get("ts")) >= 1):
		a.ts = 1
	return a.tal

func di() -> void:   # DI: nhà thân nhất thành thợ giỏi 3★
	var t = _lang()
	var a = null
	if t != null and _tr(t.get("fam")):
		for n in _okeys(t.fam):
			var e: Dictionary = t.fam[n]
			x9(n, e)
			if a == null or _i(e.get("tim")) > _i(a.f.get("tim")):
				a = {"u": n, "f": e}
	if a != null:
		a.f.ts = maxi(3, _i(a.f.get("ts")))
		_ta(String(a.f.n) + " học nghề ở huyện về, giờ là " + String(W3[String(a.f.tal)].n).to_lower() + " 3★!")
	else:
		var v1 := _x("V1")
		var v = v1.call() if v1.is_valid() else null
		if v is Dictionary:
			v.tal3 = 1
		_ta("Khi có hàng xóm, người đầu tiên sẽ là thợ giỏi 3★.")

# ------------------------------------------------------------------ hụi (KN), du lịch trả phòng (BR)
func hui_ky(t: bool) -> void:   # KN: tới kỳ góp hụi (t = im lặng khi chạy bù)
	var a = G.g.get("hui")
	if not _tr(a) or _tr(a.get("done")):
		return
	var fy6 := _x("y6")
	var fpm := _x("Pm")
	var fvk := _x("vk")
	if not fy6.is_valid() or not fpm.is_valid() or not fvk.is_valid():
		return
	var n := int(fy6.call())
	while _n(a.paid) < n and not _tr(a.get("done")):
		var e := int(a.paid) + 1
		if e > 1 and not _tr(a.get("be")) and randf() < k_s(a.u):
			a.be = 1
			a.done = 1
			var r = _fam_of(a.u)
			if r != null:
				r.tim = maxf(0, _n(r.get("tim")) - 2)
			var o := _n(a.paid) * _n(a.c) - _n(a.got)
			fpm.call("Kỳ " + str(e) + ": " + String(a.n) + " bể hụi, ôm tiền trốn lên Sài Gòn!")
			_ta("Bể hụi! " + String(a.n) + " ôm tiền trốn rồi. May mà bạn hốt trước, khỏi góp nữa." if _tr(a.get("hot")) else "Bể hụi! " + String(a.n) + " ôm tiền trốn, bạn mất trắng " + _sa(o) + " xu đã góp.")
			_gr(60)
			break
		if _n(G.g.coins) >= _n(a.c):
			G.g.coins = _n(G.g.coins) - _n(a.c)
			fpm.call("Kỳ " + str(e) + ": góp " + _sa(a.c) + " xu.")
		else:
			a.no = _n(a.get("no")) + _n(a.c)
			var l = _fam_of(a.u)
			if l != null:
				l.tim = maxf(0, _n(l.get("tim")) - 1)
			fpm.call("Kỳ " + str(e) + ": không đủ tiền góp, ghi nợ " + _sa(a.c) + " xu.")
			if not t:
				_ta("Tới kỳ góp hụi mà không đủ xu, " + String(a.n) + " ghi nợ và buồn bạn (−1 ♥).")
		a.paid = e
		if e == _D:
			if not _tr(a.get("hot")):
				var c := float(fvk.call(_D, a.c)) - _n(a.get("no"))
				a.no = 0
				G.g.coins = _n(G.g.coins) + maxf(0, c)
				a.got = _n(a.get("got")) + c
				a.hot = _D
				fpm.call("Kỳ chót: hốt hụi chót, nhận " + _sa(c) + " xu.")
				if not t:
					_ta("Mãn hụi! Bạn hốt chót, nhận " + _sa(c) + " xu (lời so với tiền góp).")
			a.done = 1
			fpm.call("Mãn hụi.")
			var f = _fam_of(a.u)
			if f != null and not _tr(a.get("be")):
				f.tim = minf(5, _n(f.get("tim")) + 1)
	if not t:
		_ba()

func br(t: Dictionary) -> void:   # BR: đoàn khách trả phòng
	var fr6 := _x("R6")
	if not fr6.is_valid():
		return
	var a: Dictionary = fr6.call()
	var n: Dictionary = PR[int(a.lv)]
	var e: int = t.m.size()
	var r := maxf(1, _n(t.get("night")))
	var o := float(n.xu) * e * r
	var l := maxi(1, mini(5, _rnd(2.4 + _n(t.get("happy")) * 0.35 + float(n.r))))
	G.g.coins = _n(G.g.coins) + o
	a.xu = _n(a.xu) + o + _n(t.get("spent"))
	a.n = _n(a.n) + e
	var c = _t0(V_[str(l)])
	a.rv.push_front({"s": l, "t": c, "k": t.k, "n": e, "xu": o + _n(t.get("spent")), "at": _now()})
	a.rv = a.rv.slice(0, 20)
	var f = _fam_of(t.host)
	if f != null and l >= 4 and _n(f.get("tim")) < 5 and randf() < 0.4:
		f.tim = _n(f.get("tim")) + 1
	_ta(String(A7[String(t.k)].n) + " trả phòng: +" + _sa(o) + " xu tiền phòng, đánh giá " + str(l) + "★ “" + String(c) + "”")
	_ba()
	var fe := _x("e7")   # tp && e7(): bảng Du lịch miệt vườn đang mở thì dựng lại
	if fe.is_valid():
		fe.call()

# ------------------------------------------------------------------ báo khi xây xong (Kq), chữ rê chuột (Vq)
func kq(t: String) -> void:   # Kq
	if CX.has(t):
		_r0()
		uf()
		var a = null
		for n in _r0().fam:
			if a == null or int(float(_ks(n))) > a:
				a = int(float(_ks(n)))
		var e = _fam_of(a) if a != null and a else null
		if e != null:
			e.mo = 1
			_ta("Gia đình " + String(e.n) + " đã dọn về ở. Chạm vào nhà để trò chuyện, tặng quà hay thuê làm phụ.")
		return
	if t == "thungong":
		_r0()
		_ta("Thùng ong: cây ăn trái trong vòng 3 ô được thêm 1 trái mỗi lần hái. Có hoa quanh đó thì ong làm mật nhanh hơn.")
		return
	if t == "lunuoc" or t == "pond" or t == "well":
		_ta("Ô ruộng cách nước, lu nước trong vòng 2 ô sẽ lâu khô hơn 40%.")
		return
	if WRS.fx(t):
		_ta("Rào gần ruộng (trong vòng 2 ô) thì gà vịt sổng chuồng không vào phá.")
		return
	if t == "kho" or t == "kho2":
		_ta("Xưởng nằm gần kho hàng (trong vòng 5 ô) làm nhanh hơn 25%.")
		return
	if RegEx.create_from_string("^ben[2-4]?$").search(t) != null:
		if WR != null:
			WR.m0()
		var fmg := _x("mg")
		var r: bool = fmg.is_valid() and (fmg.call() as Array).size() > 0
		if r:
			var fae := _x("Ae")
			var Ae = fae.call() if fae.is_valid() else null
			if Ae is Dictionary and _n(Ae.get("st")) == 0:
				Ae.t = minf(_n(Ae.get("t")), _nn(30, 60))
			_ta("Bến ghe bên sông Vàm đã dựng xong. Thỉnh thoảng ghe thương hồ sẽ ghé mua hàng.")
		else:
			_ta("Bến này không chạm sông Vàm nên ghe thương hồ không ghé được. Dời bến ra bờ sông nhé." if (WR != null and WR.o0() > 0) else "Ghe thương hồ chỉ ghé bến bên sông Vàm. Mở khúc sông phía nam làng rồi dựng bến ở đó.")

func _r_tx(r: Dictionary) -> String:   # _rTx
	var it: Array = r.it if r.get("it") is Array and r.it.size() else [[r.id, r.q]]   # _rIt
	return " và ".join(PackedStringArray(it.map(func(x): return _ho(String(x[0]), int(x[1])))))

func vq(t: Dictionary) -> Variant:   # Vq: chữ khi rê / giữ trên vật (có <b>…</b> như bản web)
	var ty := String(t.get("type", ""))
	if ty == "nha":
		var a = _fam_of(t.u)
		if a == null:
			return ""
		var job = a.get("job")
		return "<b>Nhà " + String(a.n) + "</b>" + (("Đang cần " + _r_tx(a.req) + ". ") if _tr(a.get("req")) else "") + ("Đang làm ruộng cho bạn. " if job == "ruong" else (("Đang làm ở " + String(CO.get(String(job), "")).to_lower() + ". ") if _tr(job) else "")) + ("Đang muốn nói chuyện với bạn. " if _n(a.get("mo")) == 1.0 and chat_left(a) else "") + "Chạm để ghé chơi."
	if ty == "dd":
		var fnn := _x("NN_T")
		return String(fnn.call(String(t.get("kd", "dd")))) if fnn.is_valid() else "<b>Bông điên điển</b>Chạm để hái."
	if ty == "xe":
		var fhr := _x("hr")
		var hr = fhr.call() if fhr.is_valid() else {}
		var of = hr.get("offer") if hr is Dictionary else null
		return "<b>Xe chè dạo</b>Cô bán chè cần mua " + (_ho(String(of.id), int(of.q)) if _tr(of) else "nguyên liệu") + ". Chạm để bán."
	if ty == "ghe":
		var fae := _x("Ae")
		var Ae = fae.call() if fae.is_valid() else {}
		return "<b>Ghe thương hồ " + String(Ae.get("from", "")) + "</b>Mua sỉ giá gấp đôi, đổi gạch nung, cây giống quý. Chạm để xem."
	var fbn := _x("BN")
	if fbn.is_valid():
		var n = fbn.call(t)
		if _tr(n):
			return n
	if ty == "hive":
		var O: Array = G.g.get("objs", [])
		var e = O[int(t.i)] if int(t.i) < O.size() else null
		var L = _lang()
		var r = L.hive.get(_ks(e.u)) if e is Dictionary and _tr(e.get("u")) and L != null and L.get("hive") is Dictionary else null
		return "<b>Thùng ong mật</b>" + (("Có " + _sv(r.h) + " hũ mật, chạm để lấy. ") if r is Dictionary and _tr(r.get("h")) else "Ong đang làm mật. ") + "Cây ăn trái trong vòng 3 ô được thêm 1 trái mỗi lần hái."
	if ty == "gavit":
		var y = WR.Y0.get("a") if WR != null else null
		return "<b>" + ("Vịt" if y is Dictionary and y.get("sp") == "vit" else "Gà") + " sổng chuồng</b>Đang bới ruộng! Chạm để đuổi. Rào quanh ruộng thì gà vịt không vào được."
	return null

# ------------------------------------------------------------------ ma trơi (g.ma)
func i_u() -> Variant:   # iU: đêm nay có ma trơi (ngày) hay không (null)
	var t := _d0()
	if not (t >= 21 or t < 4):
		return null
	var a := _vr() if t >= 21 else _vr() - 1
	return a if NV.Me(a, 31) < 0.55 else null

func e_s(t: bool) -> Variant:   # ES: chỗ ma trơi hiện (gần Xr khi t)
	var fll := _x("ll")
	var fb := _x("_b")
	var faa := _x("aa")
	if not fll.is_valid() or not fb.is_valid():
		return null
	for _a in 60:
		var n: int
		var e: int
		if t:
			n = int(floor(float(Xr.x) + _nn(-3.5, 3.5)))
			e = int(floor(float(Xr.y) + _nn(-3.5, 3.5)))
		else:
			var r := randf() * 6.283
			var o := _nn(6, 15)
			n = int(floor(5 + cos(r) * o))
			e = int(floor(4 + sin(r) * o))
		if not (not fll.call(n, e) or not fb.call(n, e) or (G.lang != null and G.lang.o2(n, e))):
			if t and faa.is_valid():
				var p: Vector2 = faa.call()
				if Vector2(n + 0.5 - p.x, e + 0.5 - p.y).length() < 2.2:
					continue
			return [n + 0.5, e + 0.5]
	return null

func k6(t: float) -> void:   # k6: ma trơi hiện / tắt, trôi về chỗ tới (vệt sáng, tiếng: không chép)
	Xr.ph += t
	var a = i_u()
	if int(Xr.st) == 0:
		if a == null or _cr() or _mode() != "off":
			return
		var n = G.g.get("ma") if G.g.get("ma") is Dictionary else {}
		if n.get("d") != null and _n(n.d) == float(a) or randf() > t / 40.0:
			return
		var e = e_s(false)
		if e == null:
			return
		Xr.st = 1
		Xr.x = e[0]
		Xr.tx = e[0]
		Xr.y = e[1]
		Xr.ty = e[1]
		Xr.hop = 0
		Xr.need = 2 + int(floor(randf() * 2))
		Xr.al = 0.0
		Xr.tr = []
		G.g.ma = {"d": a}
		_ba()
		if _wr(Xr.x, Xr.y, 200):
			_ta("Ngoài đồng có đốm lửa xanh lập lờ… ma trơi! Chạm vào thử đi theo coi.")
		return
	if a == null and int(Xr.st) == 1:
		Xr.al = maxf(0.0, Xr.al - t)
		if Xr.al <= 0:
			Xr.st = 0
		return
	Xr.al = minf(1.0, Xr.al + t * 0.5)
	var r: float = Xr.tx - Xr.x
	var o: float = Xr.ty - Xr.y
	var l := Vector2(r, o).length()
	if l > 0.02:
		var c := minf(l, 1.6 * t)
		Xr.x += r / l * c
		Xr.y += o / l * c

# ------------------------------------------------------------------ mỗi khung (các ui({id, step}) của bản web, chạy trong wK mỗi khung)
var THT := 0.0

func than_step(dt: float) -> void:   # ui({id: "than"}).step
	THT -= dt
	than_invite(dt)
	if THT > 0:
		return
	THT = 1
	var L = _lang()
	if L == null or not _tr(L.get("fam")):
		return
	for k in _okeys(L.fam):
		than_init(k, L.fam[k])
		than_sync(L.fam[k])
	than_daily()
	than_pq_late()
	gp_wedding()

func step(t: float, offline: bool) -> void:   # wK: than, dam ($K), cuoi (zU), ma (k6), clg (clgTick); bản web không chạy khi bù offline
	if offline:
		return
	than_step(t)
	dam_tick(t)
	cuoi_step(t)
	if not _qf("ma"):   # k6 bọc: if (!qf("ma"))
		k6(t)
	clg_tick(t)

# ------------------------------------------------------------------ bảng nhà dân (a4): việc nhà, thuê làm, trò chuyện, tặng quà, sở trường
const NGHEWHY := {"gio_lb": ["đan giỏ bán chợ phiên", "làm giỏ đựng trái cây"], "chieu": ["dệt chiếu cưới", "dệt chiếu bán Tết"], "nhang": ["se nhang cúng rằm", "se nhang bỏ mối"],
	"banh_pt": ["gói bánh đám cưới", "làm mâm quả"], "choi_rom": ["bó chổi bán chợ", "bó chổi quét sân đình"], "ruou_nep": ["nấu rượu đãi khách", "nấu rượu cúng đình"],
	"khan_theu": ["thêu khăn làm quà cưới", "thêu khăn bán chợ huyện"], "mut_gung": ["sên mứt Tết", "sên mứt biếu sui gia"], "chao": ["làm chao ăn chay rằm", "làm chao bỏ mối chợ"],
	"long_den": ["làm lồng đèn Trung thu", "làm lồng đèn cho con nít trong xóm"]}
const E4 := {"vuon": 1, "chan": 1}   # e4
var THOAI := []            # THOAI (dan_lang/cay_thoai)
var XD := []               # xD (dan_lang/ly_do_nho)
var NVT := []              # NV (dan_lang/viec_nho)

func _vl_data() -> void:
	if THOAI.is_empty():
		THOAI = _ja("dan_lang/cay_thoai")
		XD = _ja("dan_lang/ly_do_nho")
		NVT = _ja("dan_lang/viec_nho")

static func _r_it(r: Dictionary) -> Array:   # _rIt
	return r.it if r.get("it") is Array and r.it.size() else [[r.get("id"), r.get("q")]]

func r_ok(r: Dictionary) -> bool:   # _rOk
	return _r_it(r).all(func(x): return _barn(x[0]) >= _i(x[1]))

func _sday() -> int:   # t3().day
	return posmod(_vr(), 28) % 7 + 1

func is_ngay_rieng(u) -> bool:   # isNgayRieng
	return _sday() == int(fam_likes(u).ngay)

static func e_t(t: int) -> String:   # eT
	var a := ""
	for n in 5:
		a += "♥" if n < t else "♡"
	return a

static func n_y(t: int) -> String:   # nY
	var a := ""
	for n in range(1, 6):
		a += "★" if n <= t else "☆"
	return a

func talk_line(f: Dictionary) -> String:   # talkLine
	var t: Array = tinh_of(f).talk[mini(3, int(floor(_n(f.get("tim")) / 1.5)))]
	return xung(f, String(t[(_vr() + _i(f.get("lk"))) % t.size()]))

func than_bonus(f: Dictionary) -> String:   # thanBonus
	if not _tr(tinh_of(f).get("gift")):
		return ""
	var id = _t0(_s2())
	if id == null:
		return ""
	var q := maxi(1, _rnd(30.0 / _sell(id)))
	G.g.barn[String(id)] = _barn(id) + q
	return " Cho thêm " + _ho(String(id), q) + "."

func _sell(id) -> float:   # ae(id).sell || 10
	var s := _n(_ae(id).get("sell"))
	return s if s != 0.0 else 10.0

func _s2() -> Array:   # s2
	if WC != null:
		return WC.s2()
	var f := _x("s2")
	return f.call() if f.is_valid() else []

func fam_know(f: Dictionary, k: String) -> bool:   # famKnow
	if not (f.get("bk") is Dictionary):
		f.bk = {}
	var n := not _tr(f.bk.get(k))
	f.bk[k] = 1
	return n

func vg(t: String) -> String:   # vg: tên nhà đang làm việc t
	var a = _lang()
	if a == null or not (a.get("fam") is Dictionary):
		return ""
	for n in a.fam:
		if a.fam[n].get("job") == t:
			return String(a.fam[n].n)
	return ""

func yx(t: String) -> bool:   # yx
	if t == "vuon":
		return WR != null and WR.uq()
	if t == "chan":
		return G.vn != null and G.vn.has_any()
	return false

func ux(t) -> Array:   # ux: ô ruộng nhà t phụ trách
	var n := lm().find(int(float(_ks(t))))
	return [] if n < 0 else _gg().slice(n * 12, n * 12 + 12)

func xq(_f: Dictionary) -> Array:   # Xq + _vCS: [[id, chữ]], ô "Giữ giống cũ" đầu, còn giống trước, hợp mùa trước
	var a := []
	var k := 0
	for n in XO:
		var e: Dictionary = G.D.crops.get(n, {})
		if e.is_empty() or (WC != null and WC.tf(n)):
			continue
		var c := _barn(n)
		var h: bool = G.in_season(n)
		a.append({"id": n, "t": String(e.name) + (" (hợp mùa)" if h else "") + " · còn " + str(c) + " giống", "n": c, "h": 1 if h else 0, "i": k, "z": c == 0})
		k += 1
	a.sort_custom(func(p, q): return (p.n > 0 and q.n == 0) or ((p.n > 0) == (q.n > 0) and (p.h > q.h or (p.h == q.h and p.i < q.i))))
	return [{"id": "", "t": "Giữ giống cũ", "z": false}] + a

func gb(t) -> bool:   # Gb: đưa đồ nhà đang cần
	var n = _fam_of(t)
	if n == null or not _tr(n.get("req")):
		return false
	var e: Dictionary = n.req
	var m := _r_it(e).filter(func(x): return _barn(x[0]) < _i(x[1]))
	if m.size():
		_ta("Kho chưa đủ " + _r_tx({"it": m}) + ".")
		return false
	for x in _r_it(e):
		G.g.barn[String(x[0])] = _barn(x[0]) - _i(x[1])
	G.g.coins = _n(G.g.coins) + _n(e.xu)
	var dh := than_add(n, 35)
	var bn := than_bonus(n)
	than_seen(n)
	var no := _x("No")
	if no.is_valid():
		no.call("help")
	n.req = null
	_qi("vlhelp")
	var r = r1(t)
	if r != null:
		G.float_text.emit(float(r.o.gx) + float(r.o.fw) / 2.0, float(r.o.gy) + float(r.o.fd) / 2.0, String(n.n) + " cảm ơn! +" + _sa(e.xu) + " xu")
	_ta(String(n.n) + " cảm ơn nhiều nha! Nhận " + _sa(e.xu) + " xu." + bn + than_txt(dh) + (" Nhà " + String(n.n) + " giờ thân như ruột thịt." if dh > 0 and _i(n.tim) >= 5 else ""))
	_gr([10, 30, 14])
	_ba()
	return true

func iv(t) -> void:   # IV: giao việc riêng
	var a = _fam_of(t)
	if a == null or not _tr(a.get("pq")):
		return
	if not a.pq.it.all(func(e): return _barn(e[0]) >= _i(e[1])):
		_ta("Kho chưa đủ đồ.")
		return
	for e in a.pq.it:
		G.g.barn[String(e[0])] = _barn(e[0]) - _i(e[1])
	G.g.coins = _n(G.g.coins) + _n(a.pq.xu)
	ut_add(5, "Xong việc riêng")
	var dh := than_add(a, 50)
	var bn := than_bonus(a)
	than_seen(a)
	G.add_xp(10, "pq")
	_ta("Xong việc \"" + String(a.pq.t) + "\" cho " + String(a.n) + ": +" + _sa(a.pq.xu) + " xu." + bn + than_txt(dh))
	a.pq = null
	_ba()

func n4(t, a: String) -> void:   # n4: thuê nhà t làm việc a ("" = nghỉ)
	var e = _fam_of(t)
	if e == null:
		return
	if a != "" and a != "ruong" and not E4.has(a) and not (G.xw.sr.has(a) and G.xw.built(a)):
		return
	if E4.has(a) and not yx(a):
		_ta("Chưa có cây ăn trái nào để chăm." if a == "vuon" else "Chuồng trại chưa có con nào.")
		return
	if a != "" and _n(G.g.coins) < om(e, a):
		_ta("Cần ít nhất " + str(om(e, a)) + " xu để trả công phút đầu.")
		return
	if a != "" and a != "ruong":
		var r := vg(a)
		if r != "" and r != String(e.n):
			_ta(r + " đang làm ở đây rồi.")
			return
	e.job = a if a != "" else null
	e.wt = 0
	if a != "" and a != "ruong" and G.xw.sr.has(a):
		var o: Dictionary = G.xw.sr[a]
		var q: Array = G.g.work[a].get("q", [])
		var ok: Array = o.rec.filter(func(x): return G.xw.has_in(String(x)))
		e.jr = q[0] if q.size() else (ok[0] if ok.size() else o.rec[0])
	_ta(String(e.n) + " ra ruộng phụ bạn: tự gieo lại giống cũ, tưới và gặt." if a == "ruong" else (String(e.n) + " ra vườn phụ bạn: tưới cây, hái trái chín cất vào kho." if a == "vuon" else (String(e.n) + " ra chuồng phụ bạn: cho gà, cừu, bò, heo ăn (lấy thức ăn trong kho) và lượm sản phẩm." if a == "chan" else (String(e.n) + " tới " + String(CO.get(a, a)).to_lower() + " làm phụ." if a != "" else String(e.n) + " về nhà nghỉ."))))
	_ba()

func jq(t, a: String) -> void:   # Jq: giống nhà t gieo
	var n = _fam_of(t)
	if n == null:
		return
	n.crop = a if a != "" and G.D.crops.has(a) else ""
	_ta(String(n.n) + " sẽ gieo " + String(G.D.crops[n.crop].name).to_lower() + " ở các ô mình phụ trách." if n.crop != "" else String(n.n) + " gieo lại giống cũ của từng ô.")
	_ba()

func set_jr(t, r: String) -> void:   # data-jr
	var n = _fam_of(t)
	if n != null:
		n.jr = r
		_ba()

# trò chuyện ($r.cv): {u, inv, t, st, sum, node, lines: [[n|m|s, chữ]], opts: [{k, i, t, tone}], out}
func chat_ctx(u, f: Dictionary, inv: bool) -> String:   # chatCtx
	var d := _vr()
	var c := []
	var e = tg().get("ev")
	var wx: String = "lu" if (WR != null and WR.qs()) else String(G.nv.Wd())
	if _tr(f.get("req")) and randf() < 0.5:
		c.append("nho")
	if e is Dictionary and _i(e.get("u")) == int(float(_ks(u))):
		c.append("dam")
	if c.is_empty() and _num(f.get("cd")) and int(f.cd) == d and _i(f.get("cn")) > 0:
		c.append("lai")
	if c.is_empty() and d - _i(f.get("lg")) >= 3:
		c.append("lau")
	if c.is_empty() and _i(f.get("tim")) >= 3 and randf() < (0.6 if inv else 0.3):
		c.append("than")
	if c.is_empty() and wx in ["lu", "mua", "han", "giong"] and randf() < 0.45:
		c.append(wx)
	if c.is_empty() and randf() < 0.2:
		c.append(["xuan", "he", "thu", "dong"][G.season()])
	return String(c[0]) if c.size() else "chao"

func chat_tree(u, f: Dictionary, inv: bool) -> int:   # chatTree
	var k := chat_ctx(u, f, inv)
	var L := []
	for i in THOAI.size():
		if THOAI[i].c == k and i != _i(f.get("ml", -1)):
			L.append(i)
	if L.is_empty():
		for i in THOAI.size():
			if THOAI[i].c == "chao" and i != _i(f.get("ml", -1)):
				L.append(i)
	var i: int = _t0(L)
	f.ml = i
	return i

func chat_opts(L: Array, f: Dictionary) -> Array:   # chatOpts (+ xung)
	var o := []
	for i in L.size():
		o.append({"k": "r", "i": i, "t": xung(f, String(L[i][1])), "tone": L[i][0]})
	o.shuffle()
	return o

func chat_score(f: Dictionary, tone) -> int:   # chatScore
	var T := tinh_of(f)
	return 12 if tone == T.ton else (-12 if tone == T.ghet else 4)

func chat_start(u) -> Variant:   # chatStart -> cv (null = không nói được)
	_vl_data()
	var f = _fam_of(u)
	if f == null:
		return null
	if not chat_left(f):
		_ta(String(f.n) + " nói chuyện với bạn đủ rồi, mai ghé tiếp nha.")
		return null
	var inv := _i(f.get("mo")) == 1
	var ti := chat_tree(u, f, inv)
	var t: Dictionary = THOAI[ti]
	return {"u": int(float(_ks(u))), "inv": inv, "t": ti, "st": 1, "sum": 0, "node": t.r, "lines": [["n", xung(f, String(t.mo))]], "opts": chat_opts(t.r, f), "out": null}

func chat_pick(c: Dictionary, i: int) -> bool:   # chatPick; true = xong cuộc trò chuyện
	var f = _fam_of(c.u)
	if f == null:
		return true
	if c.out != null:
		chat_end(c, f, i)
		return true
	if i >= c.opts.size():
		return false
	var o: Dictionary = c.opts[i]
	var d := _vr()
	if c.st == 1:
		if not (_num(f.get("cd")) and int(f.cd) == d):
			f.cd = d
			f.cn = 0
		if not chat_left(f):
			return false
		f.cn = _i(f.get("cn")) + 1
		G.nv.S8("chat")
		than_seen(f)
		if c.inv:
			f.mo = 0
		_ut_chat(c.u)
	var T := tinh_of(f)
	var node: Array = c.node[int(o.i)]
	var sc := chat_score(f, o.tone)
	var ghet: bool = o.tone == T.ghet
	var mul: float = [1.0, 0.6, 0.4][mini(2, _i(f.cn) - 1)]
	c.sum += sc
	c.lines.append(["m", o.t])
	var dh := than_add(f, _rnd(sc * mul) + (10 if c.inv and c.st == 1 else 0))
	if c.st == 1:
		c.lines.append(["n", xung(f, String(node[3] if ghet and node.size() > 3 and _tr(node[3]) else node[2]))])
		if ghet:
			c.lines.append(["s", String(f.n) + " hổng ưa kiểu nói đó"])
		_hn_chat(c, f)
		c.st = 2
		c.node = node[4]
		c.opts = chat_opts(node[4], f)
	else:
		c.lines.append(["n", xung(f, String(node[2]))])
		if ghet:
			c.lines.append(["s", String(f.n) + " hổng ưa kiểu nói đó"])
		c.out = chat_out(c.u, f, String(node[3]) if node.size() > 3 and node[3] != null else "") if not ghet and (c.sum > 0 or c.inv) else {"k": "", "opts": [{"k": "xong", "t": "Dạ, {c} về nha."}]}
		if _tr(c.out.get("say")):
			c.lines.append(["n", xung(f, String(c.out.say))])
		c.opts = c.out.opts.map(func(x): return {"k": x.k, "t": xung(f, String(x.t))})
	if dh > 0:
		c.lines.append(["s", "Thân thiết thêm ♥"])
	elif dh < 0:
		c.lines.append(["s", "Bớt thân ♥"])
	_ba()
	return false

func chat_out(u, f: Dictionary, k: String) -> Dictionary:   # chatOut
	var L := fam_likes(u)
	var day := _vr()
	var ok := [{"k": "xong", "t": "Dạ, {c} về nha."}]
	if k == "pq" and (_tr(f.get("pq")) or _i(f.get("tim")) < 2 or _i(f.get("pqd", -1)) == day):
		k = "nho"
	if k == "nho" and not _tr(f.get("req")):
		var q := make_req(u, f)
		return {"k": k, "v": q, "say": "Nhà đang cần " + _r_tx(q) + " để " + String(q.why) + ". {C} kiếm giùm được hông?", "opts": [{"k": "nhan", "t": "Dạ, để {c} lo."}, {"k": "xong", "t": "Dạ, bữa khác nha."}]}
	if k == "pq":
		var p := make_pq(f)
		return {"k": k, "v": p, "say": "Việc này {x} nhờ riêng {c}: " + String(p.t).to_lower() + ", cần " + _r_tx(p) + ". Giúp {x} nha?", "opts": [{"k": "nhan", "t": "Dạ, {c} giúp liền."}, {"k": "xong", "t": "Dạ, để bữa khác."}]}
	var unk := ["a", "b", "x", "d"].filter(func(x): return not (f.get("bk") is Dictionary and _tr(f.bk.get(x))))
	if k == "ke" and unk.size():
		var kk: String = _t0(unk)
		fam_know(f, kk)
		var say := ""
		if kk == "x":
			say = "Nói nhỏ nghe, cả đời {x} ghét nhất là " + String(_ae(L.gh).get("name", "")).to_lower() + ", ai đem tới {x} cũng hổng ưng."
		elif kk == "d":
			say = "Ngày " + str(L.ngay) + " mỗi mùa là " + String(L.ly) + " nhà {x}, {c} nhớ ghé nha."
		else:
			say = "{X} mê " + String(_ae(L.th[0 if kk == "a" else 1]).get("name", "")).to_lower() + " lắm đó, {c} nhớ giùm."
		return {"k": k, "say": say, "opts": ok}
	if k == "tang" and _i(f.get("tgd", -1)) != day:
		f.tgd = day
		var id = _t0(_s2())
		if id != null:
			var n := maxi(1, _rnd(_nn(30, 60) / _sell(id)))
			G.g.barn[String(id)] = _barn(id) + n
			return {"k": k, "say": "Cầm " + _ho(String(id), n) + " về ăn lấy thảo nè.", "opts": [{"k": "xong", "t": "Dạ, {c} cảm ơn."}]}
	if k == "moi":
		bk(int(float(_ks(u))))
		var e = tg().get("ev")
		if e is Dictionary and _i(e.get("u")) == int(float(_ks(u))):
			return {"k": k, "say": "Mấy bữa nữa nhà {x} có " + ("đám cưới" if e.get("k") == "cuoi" else "đám giỗ") + ", nhớ qua nghen.", "opts": ok}
	return {"k": "", "opts": ok}

func chat_end(c: Dictionary, f: Dictionary, i: int) -> void:   # chatEnd
	if i >= c.opts.size():
		return
	var o: Dictionary = c.opts[i]
	if o.k == "nhan" and c.out.k == "nho" and not _tr(f.get("req")):
		f.req = c.out.v
		_ta(String(f.n) + " cần " + _r_tx(f.req) + ". Xem ở Việc nhà.")
	if o.k == "nhan" and c.out.k == "pq" and not _tr(f.get("pq")):
		f.pq = c.out.v
		f.pqd = _vr()
		_ta("Nhận Việc riêng \"" + String(f.pq.t) + "\" của " + String(f.n) + ".")
	_ba()

func make_req(u, f: Dictionary) -> Dictionary:   # makeReq
	_vl_data()
	var pool := _s2()
	var have := pool.filter(func(id): return _barn(id) > 0)
	var gn := a_r(u)
	var it := []
	var v := 0.0
	var by_ng := false
	var ng: Array = gn.get("in", []).map(func(x): return x[0]).filter(func(id): return pool.has(id))
	while it.size() < 2:
		var src: Array
		if it.is_empty() and ng.size() and randf() < 0.6:
			by_ng = true
			src = ng
		else:
			src = pool.filter(func(id): return not it.any(func(x): return x[0] == id))
		if src.is_empty():
			break
		var h2 := have.filter(func(id): return src.has(id))
		var id = _t0(h2) if h2.size() and randf() < 0.55 else _t0(src)
		var sell := _sell(id)
		var q := maxi(1, mini(8, _rnd(_nn(50, 140) * (1.0 + 0.5 * _v1()) / sell)))
		it.append([id, q])
		v += q * sell
	var why = _t0(NGHEWHY[gn.id]) if by_ng and NGHEWHY.has(gn.get("id", "")) else _t0(XD)
	if it.is_empty():
		it = [["lua", 2]]
		v = 2 * _sell("lua")
	return {"id": it[0][0], "q": it[0][1], "it": it, "xu": maxi(10, _rnd(v * _nn(1.5, 1.8) * float(tinh_of(f).xu))), "why": why, "t": 0}

func make_pq(f: Dictionary) -> Dictionary:   # makePQ
	_vl_data()
	var pool := _s2().duplicate()
	var t := _v1()
	var n := 2 if randf() < 0.5 else 3
	var it := []
	var v := 0.0
	while it.size() < n and pool.size():
		var id = pool.pop_at(int(floor(randf() * pool.size())))
		if it.any(func(x): return x[0] == id):
			continue
		it.append([id, maxi(1, mini(10, _rnd(_nn(90, 200) * (1.0 + 0.5 * t) / _sell(id))))])
	for x in it:
		v += x[1] * _sell(x[0])
	return {"t": _t0(NVT), "it": it, "xu": _rnd(v * 2.2 * float(tinh_of(f).xu)), "d": _vr()}

func _hn_chat(c: Dictionary, f: Dictionary) -> void:   # hnChat
	var x := a_r(c.u)
	var p = hn_of(c.u)
	var day := _vr()
	if not (p is Dictionary) or _i(p.get("st")) != 2 or hn_s().get("a") != x.id or _i(p.get("dl", -1)) == day:
		return
	p.dl = day
	p.n = _i(p.get("n")) + 1
	var need := hn_days(f)
	c.lines.append(["n", xung(f, String(x.tip[mini(x.tip.size(), int(p.n)) - 1]))])
	c.lines.append(["s", "Buổi chỉ nghề " + str(p.n) + "/" + str(need)])
	if int(p.n) >= need:
		p.st = 3
		c.lines.append(["s", "Thầy cho làm thử rồi đó. Vô tab Sở trường để làm thử."])

static func hn_days(f: Dictionary) -> int:   # hnDays
	return 1 if f.get("tp") == "hien" else 2

func _ut_chat(u) -> void:   # utChat
	var o := ut_s()
	if not _tr(o.get("vx")):
		return
	for t in o.vx.t:
		if t.k == "hop" and not _tr(t.get("ok")):
			o.vx.hop[_ks(u)] = 1
			if o.vx.hop.size() >= int(t.need):
				t.ok = 1
				ut_add(10, "Xong việc xóm: " + String(t.n))
				_ta("Xong việc \"" + String(t.n) + "\", bà con khen.")
			return

func gift_give(u, id: String) -> void:   # giftGive
	var f = _fam_of(u)
	if f == null or _i(f.get("gq", -1)) == _vr() or not (_barn(id) > 0) or _ae(id).is_empty():
		return
	var L := fam_likes(u)
	var like: int = L.th.find(id)
	var hate: bool = L.gh == id
	var x2 := is_ngay_rieng(u)
	var v := 40 if like >= 0 else (-25 if hate else 10)
	if x2 and v > 0:
		v *= 2
	G.g.barn[id] = _barn(id) - 1
	f.gq = _vr()
	G.nv.S8("gift")
	than_seen(f)
	var dh := than_add(f, _rnd(v * (1.0 + htv("l_qua"))) if v > 0 else v)
	var msg := ""
	var nm := String(_ae(id).name).to_lower()
	if like >= 0:
		fam_know(f, "b" if like else "a")
		msg = String(f.n) + " mê " + nm + xung(f, " lắm, cảm ơn {c}!")
	elif hate:
		fam_know(f, "x")
		msg = String(f.n) + " nhăn mặt: món này hổng ưng chút nào."
	else:
		msg = String(f.n) + xung(f, " cảm ơn {c} nha.")
	if x2:
		fam_know(f, "d")
		if v > 0:
			msg += " Đúng " + String(L.ly) + ", quý gấp đôi."
	_ta(msg + than_txt(dh))
	_ba()

func gift_ids(u) -> Array:   # giftHtml: món tặng được, thích trước, ghét sau, giá cao trước
	var f = _fam_of(u)
	var L := fam_likes(u)
	var k: Dictionary = f.get("bk") if f != null and f.get("bk") is Dictionary else {}
	var ids := []
	for id in G.g.barn:
		if _barn(id) > 0 and not _ae(id).is_empty() and _n(_ae(id).get("sell")) > 0:
			ids.append(String(id))
	var tag := func(id) -> int:
		var i: int = L.th.find(id)
		return 1 if i >= 0 and _tr(k.get("b" if i else "a")) else (-1 if id == L.gh and _tr(k.get("x")) else 0)
	ids.sort_custom(func(a, b): return tag.call(a) > tag.call(b) or (tag.call(a) == tag.call(b) and _n(_ae(a).get("sell")) > _n(_ae(b).get("sell"))))
	return ids.map(func(id): return [id, tag.call(id)])

# sở trường làm thuê (TALH, bI)
static func q_l(t: int) -> int:   # qL
	return 5 * t

static func b_l(t: int) -> int:   # BL
	return 4 * t

func m_i(t: int) -> int:   # mI
	return G.nv.v0(200.0 * t * t)

static func n_l(t: int) -> int:   # NL
	return 1800 * t

func v_i(t: String, a: int) -> String:   # vI
	if t == "xuong":
		return "Đứng xưởng: công rẻ hơn " + str(q_l(a)) + "%, xưởng nhanh hơn " + str(4 * a) + "%"
	return "Khi " + String(W3[t].job) + ": công rẻ hơn " + str(q_l(a)) + "%, " + str(b_l(a)) + "% " + String(W3[t].d)

func k9(t: Dictionary) -> bool:   # k9: đang làm đúng nghề
	if not _tr(t.get("job")) or not _tr(t.get("tal")):
		return false
	return G.xw.sr.has(t.job) if t.tal == "xuong" else t.tal == t.job

func b_i(t) -> void:   # bI: gửi đi học nghề
	var a = _fam_of(t)
	if a == null:
		return
	x9(t, a)
	var n := _i(a.ts)
	if n >= 5 or _tr(a.get("tt")):
		return
	if _i(a.get("tim")) < n:
		_ta("Thân thiết " + str(n) + " ♥ với " + String(a.n) + " mới gửi đi học nghề được.")
		return
	var e := m_i(n)
	if _n(G.g.coins) < e:
		_ta("Cần " + _sa(e) + " xu.")
		return
	G.g.coins = _n(G.g.coins) - e
	a.tt = _now() + n_l(n) * 1000.0
	if _tr(a.get("job")):
		a.job = null
		a.wt = 0
	_ta(String(a.n) + " lên chợ huyện học nghề, " + G.ao(n_l(n)) + " nữa về. Trong lúc học thì nghỉ làm thuê.")
	_ba()
