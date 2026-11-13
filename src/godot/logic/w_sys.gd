extends RefCounted
# HỆ THỐNG, NÂNG CẤP, MỤC TIÊU, NHIỆM VỤ HỆ THỐNG, THÀNH TỰU, HƯỚNG DẪN: phần luật bản web còn thiếu ở bản Godot.
#  - g.sys: du hành / chở hàng / đặc sản / review (Kg, rH, cs, CX, G4, i3, B7, YO, o8, $O, qX, Ug + 2 lớp bọc, N7,
#    vJ, mJ, tL, RH, BH, $7, HH, NH, FH), thùng xe hàng r8 (TE, AX), cửa hàng Hệ Thống WH (d3, kJ, jH, $E),
#    "Tới ngay" bằng sen đỏ (nút của BJ), đếm g.sys.stats (S5, SY, Tp).
#  - g.up: nâng cấp khác Gp (Y8, oG, d8, X7). g.goal: mục tiêu tân thủ Dc (cur, nút #goalGo, nội dung fy).
#  - g.ht: Hệ Thống Nhà Nông (htS, htv, htC, htCap, htTier, htWhy, htBuy, htSpent, htChon, htReset, htQGen, htQCur,
#    htQOk, htNv, htDoi, htNhan, htKh, htTdOk, htTdNhan, htRed, htBgl, htNgay, htTk, htTick + hiệu lực các nút ở ht_*).
#  - g.tut: nhắc lần đầu jg (Kh, ZZ, wO, $C, nút của XZ). g.tuDone: làm quen Cô Ba pA (ZY, SF, XY, CF, bước "tut").
#  - g.tt (V1, EY, JL), g.lvq (pp), g.nv.ev hỏi (II), g.gt ($z, ktt), g.kl (klSt, mR), g.cg (cgs), g.sv2 (gJ).
#  - chấm đỏ các nút (wX).
# Vẽ bản đồ (QX), nền (mz), công trình (oz, ob1), âm thanh (Jt) không chép. Bảng: w_sys_ui.gd.
# Hàm của hệ khác bản web gọi thẳng: nhận qua WR (w_ruong.gd), WC (w_cho.gd), WK (w_kho.gd) hoặc ext (Callable).

signal render             # htRender / kn: bảng Hệ Thống, bản đồ cần dựng lại
signal tip_show(tip: Dictionary)   # XZ: hiện thẻ "Lần đầu gặp" {id, g, t}
signal tip_hide                    # wO / ZZ đóng thẻ
signal tut_text(text: String, step: String)   # SF: hộp Cô Ba (p, small)
signal tut_end                     # CF: gỡ hộp Cô Ba và bàn tay
signal coach                       # wX: #coach hiện 9,5 giây (lần đầu, mới gặt < 10)

var G
var WR = null             # w_ruong.gd: lai_add, Wc
var WC = null             # w_cho.gd: P4, yu, Rl, Ge, Wf, Mv, OL, Di
var WK = null             # w_kho.gd: ngKho ($i bọc chợ)
# ext: hàm của hệ khác (bộ ráp gán)
#   Cr() -> bool                 (đang thăm làng bạn)
#   busy() -> bool               (ZZ: Mt.mode != "off" || có .raceov || đang mở bảng ni)
#   OF() -> int                  (wX: số đơn giao được; thiếu thì đếm như web)
#   Pu(k: String)                (Pu("nap"): mở cửa hàng sen đỏ)
#   No(k: String, n: int)        (No("trip", 1) sau khi chuyến đi xong)
#   utS_c() -> int               (utS().c: chức trong làng)
#   ngSao_max() -> int           (max ngSao(x.id) trên M6; thiếu thì thành tựu nghề chưa đạt)
#   go()                         (go: bước cuối làm quen, mở 7 ngày về làng)
#   G2() -> bool                 (G2: đã mở bảng 7 ngày)
#   jg_<id>() -> bool            (điều kiện mẹo jg mà bản Godot chưa có hàm: fell, rong, cho, fest, dieu, tat, vung, tram,
#                                 ray, lo, quan, hoicho, dulich)
var ext := {}

const WRS = preload("res://logic/w_ruong.gd")   # _nn (Nn), _t0 (t0)
const VNS = preload("res://logic/vatnuoi.gd")   # ro (Ro)

const R3 := {"lon": 102.7, "lat": 9.7, "name": "Đảo trại"}   # r3
const XO := ["xe"]                                              # XO
const UJ := {"well": 4, "fert": 6, "pen": 8, "stall": 10}       # uJ: cấp mở nâng cấp
const OO := ["rom", "phan", "voi", "van", "dinh", "gach", "tre", "la", "may", "bat", "bang", "can"]   # Oo
const HTTAY := 50
const DI := ["ga", "cuu", "bo", "heo", "de"]                    # Di

var cc: Array = []        # địa danh
var r8: Dictionary = {}   # thùng xe hàng
var Gp: Dictionary = {}   # nâng cấp khác
var Z9: Array = []
var WH: Array = []        # cửa hàng Hệ Thống
var IH: Dictionary = {}   # cách dùng đặc sản
var Sf: Dictionary = {}   # hiệu ứng món ăn
var Dc: Array = []        # mục tiêu tân thủ
var HTLV: Array = []
var HTGIA: Array = []
var HTB: Dictionary = {}
var HTN: Array = []
var HTI: Dictionary = {}
var HTQ: Array = []
var HTTD: Array = []
var jg: Array = []        # mẹo lần đầu
var pA: Array = []        # các bước làm quen
var R7: Dictionary = {}   # khung miền
var HX: Dictionary = {}   # tên miền

# trạng thái bản web không lưu
var fs = null             # địa danh đang chọn trên bản đồ (id)
var lp := 0               # số sao review đang chấm
var l1 := {"p": null, "q": {}}   # chở hàng: nơi đến, số món mỗi loại
var HTV := {"tab": "nv", "br": "nong", "pick": null, "t": 0.0}
var HTK := 0.0
var red := 0              # #sysBdg
var XC := 0.0             # ZZ mỗi 2 giây
var JC := 0.0             # ms: chưa nhắc lại trước lúc này
var is_tip = null         # is: thẻ nhắc đang hiện {id, tm}
var U0 := {"on": false, "i": 0, "b0": null}
var TF := true            # chưa tạo nhân vật lúc mở game
var vA := 0.0
var _zy_t := -1.0         # setTimeout(ZY, 1200)
var _go_t := -1.0         # setTimeout(go, 900)
var _mig_t := -1.0        # setTimeout(ta(...), 3600) của htS
var _mig_msg := ""
var GO := false

func _init(game) -> void:
	G = game
	cc = _ja("du_hanh/dia_danh")
	r8 = _jd("nang_cap/thung_xe_hang")
	Gp = _jd("nang_cap/nang_cap_khac")
	Z9 = _ja("khac/Z9")
	WH = _ja("he_thong/cua_hang")
	IH = _jd("he_thong/dac_san_cach_dung")
	Sf = _jd("che_bien/hieu_ung_mon_an")
	Dc = _ja("nhiem_vu/muc_tieu_tan_thu")
	HTLV = _ja("he_thong/cap_mo_tang")
	HTGIA = _ja("he_thong/gia_nut_theo_tang")
	HTB = _jd("he_thong/nhanh")
	HTN = _ja("he_thong/nut_phat_trien")
	for x in HTN:
		HTI[String(x.id)] = x
	HTQ = _ja("he_thong/mau_nhiem_vu")
	HTTD = _ja("he_thong/thanh_tuu")
	jg = _ja("huong_dan/meo")
	pA = _ja("nhiem_vu/huong_dan_dau")
	R7 = _jd("du_hanh/khung_mien")
	HX = _jd("du_hanh/ten_mien")
	TF = not _tr(G.g.get("pc", {}).get("made"))

# ------------------------------------------------------------------ tiện ích
func _jd(p: String) -> Dictionary:   # G._j (Dictionary)
	var v = G._j(p)
	return v if v is Dictionary else {}

func _ja(p: String) -> Array:   # G._j (Array)
	var v = G._j(p)
	return v if v is Array else []

func _x(k: String) -> Callable:
	var c = ext.get(k)
	return c if c is Callable and (c as Callable).is_valid() else Callable()

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

static func _r(x: float) -> int:   # Math.round
	return int(floor(x + 0.5))

func _now() -> float:   # Date.now()
	return G._now_ms()

func _ta(s: String) -> void:   # ta / pn
	G.toast.emit(s)

func _kn() -> void:   # kn + Ba
	G.mark()
	render.emit()

func _cr() -> bool:   # Cr
	var f := _x("Cr")
	return bool(f.call()) if f.is_valid() else false

func jr() -> int:   # jr
	return G.lv()

func vr() -> int:   # vr
	return G.day()

func sys() -> Dictionary:   # g.sys (+ khóa thiếu như LX)
	if not (G.g.get("sys") is Dictionary):
		G.g.sys = {}
	var s: Dictionary = G.g.sys
	for k in ["stats", "shop", "unl", "visited", "spec", "reviews"]:
		if not (s.get(k) is Dictionary):
			s[k] = {}
	if not s.has("pts"):
		s.pts = 0
	if not s.shop.has("xe"):
		s.shop.xe = 0
	if not s.has("trip"):
		s.trip = null
	return s

func _barn(t: String) -> int:
	return int(G.g.barn.get(t, 0))

func _price(t: String) -> int:   # $i
	return WK.ngKho(t) if WK != null else G.price(t)

func _crop_n(t: String) -> String:   # kr[t].name
	return String(G.crop(t).get("name", t))

func _mat_n(t: String) -> String:   # $o[t].n
	var m = G.D.mat.get(t) if G.D.mat is Dictionary else null
	return String(m.get("n", t)) if m is Dictionary else t

# ------------------------------------------------------------------ đếm (S5, SY, Tp)
func S5(t: String) -> Callable:   # S5
	return func() -> int: return int(sys().stats.get(t, 0))

func ru() -> int:   # ru
	return G.n_open()

func SY() -> Dictionary:   # SY
	var t: Dictionary = G.g.sys.get("stats", {}) if G.g.get("sys") is Dictionary else {}
	var pc: Dictionary = G.g.get("pc", {})
	var fi = G.g.get("fish")
	return {"plant": int(t.get("plant", 0)), "harvest": int(t.get("harvest", 0)), "collect": int(t.get("collect", 0)),
		"mill": int(t.get("mill", 0)), "oven": int(t.get("oven", 0)), "sapsale": int(t.get("sapsale", 0)),
		"cho": int(t.get("cho", 0)), "ghe": int(t.get("ghe", 0)), "trip": int(t.get("trips", 0)) + int(t.get("cargo", 0)),
		"vlhelp": int(t.get("vlhelp", 0)), "del": int(G.g.get("delivered", 0)),
		"fish": int(fi.get("total", 0)) if fi is Dictionary else 0, "plots": ru(), "water": 0,
		"chat": int(pc.get("cnt", {}).get("chat", 0)) if pc.get("cnt") is Dictionary else 0}

func Tp(t: String) -> int:   # Tp
	var a: Dictionary = G.g.sys.get("stats", {}) if G.g.get("sys") is Dictionary else {}
	return int(a.get(t, 0)) - int(V1().get("b", {}).get(t, 0))

# ------------------------------------------------------------------ g.tt: quà 7 ngày cho người mới (V1, EY, JL)
func V1() -> Dictionary:   # V1
	var t = G.g.get("tt")
	if not (t is Dictionary):
		var a: bool = int(G.g.pc.get("lv", 1)) <= 3 and int(G.g.get("delivered", 0)) < 3 and ru() <= 8
		t = {"t0": G.nv.d4(), "b": SY(), "cl": {}, "ci": {}, "ch": {}} if a else {"off": 1}
		G.g.tt = t
	for n in ["cl", "ci", "ch"]:
		if not t.has(n) and not _tr(t.get("off")):
			t[n] = {}
	return t

func EY() -> bool:   # EY
	var t = G.g.get("tt")
	return t is Dictionary and t.get("ch") is Dictionary and _tr(t.ch.get("280")) \
		and (t.get("ci", {}) as Dictionary).size() >= 7 and (t.get("cl", {}) as Dictionary).size() >= 28

func JL() -> void:   # JL: cổng tre chỉ hiện khi đã nhận quà
	if G.lang == null:
		return
	var t = G.lang.Pi.get("cong_tre")
	if t is Dictionary:
		var tt = G.g.get("tt")
		t.hide = not (tt is Dictionary and _tr(tt.get("cong")))

# ------------------------------------------------------------------ khóa nhỏ
func pp() -> Array:   # pp: hàng chờ bảng LÊN CẤP
	if not (G.g.get("lvq") is Array):
		G.g.lvq = []
	return G.g.lvq

func II() -> Variant:   # II: sự kiện "hỏi" đang chạy
	var nv = G.g.get("nv")
	var e = nv.get("ev") if nv is Dictionary else null
	var k = nv.get("evk") if nv is Dictionary else null
	if _tr(k) and String(k).ends_with(":hoi"):
		return {"k": k, "p": int(e.get("p", 0)) if e is Dictionary else 0}
	return null

func Sz(t: int, a: int) -> Variant:   # $z: nền ô (g.gt)
	var gt = G.g.get("gt")
	if gt is Dictionary and _tr(gt.get(str(t) + "," + str(a))):
		return gt[str(t) + "," + str(a)]
	return null

func ktt() -> int:   # ktt
	var gt = G.g.get("gt")
	return gt.size() if gt is Dictionary else 0

func mR() -> int:   # mR: tuần (bắt đầu thứ Hai, giờ UTC)
	return int(floor((_now() / 86400000.0 + 3.0) / 7.0))

func klSt() -> Dictionary:   # klSt
	var k = G.g.get("kl")
	if not (k is Dictionary):
		k = {}
		G.g.kl = k
	if not (k.get("b") is Dictionary):
		k.b = {}
	if not (k.get("r") is Array):
		k.r = []
	if not (k.get("got") is Dictionary):
		k.got = {}
	if not (k.get("tt") is Array):
		k.tt = []
	var w := mR()
	if not (k.get("wk") is Dictionary) or int(k.wk.get("w", -999999)) != w:
		if k.get("wk") is Dictionary and int(k.wk.get("w", -999999)) == w - 1:
			k.pw = k.wk
		elif not (k.get("pw") is Dictionary) or int(k.pw.get("w", -999999)) < w - 1:
			k.pw = null
		k.wk = {"w": w, "b": {}}
	return k

static func _jday() -> String:   # day(): "2026-11-13" không đệm số 0
	var d := Time.get_datetime_dict_from_system()
	return str(d.year) + "-" + str(d.month) + "-" + str(d.day)

func cgs() -> Dictionary:   # cgs
	var c = G.g.get("cg")
	if not (c is Dictionary) or String(c.get("d", "")) != _jday():
		c = {"d": _jday(), "n": 0}
		G.g.cg = c
	return c

func gJ() -> void:   # gJ: bản lưu cũ lên 1 sao mọi thứ (một lần)
	if G.g.is_empty() or _tr(G.g.get("sv2")):
		return
	G.g.sv2 = 1
	var t: bool = jr() > 1 or int(G.g.get("harvested", 0)) > 0
	if not t:
		return
	for a in G.g.plots:
		if _tr(a.get("u")):
			a.st = mini(6, (int(a.get("st", 0)) if int(a.get("st", 0)) != 0 else 1) + 1)
	if G.xw != null and G.g.get("work") is Dictionary:
		for a in G.xw.N0:
			var n = G.g.work.get(a)
			if n is Dictionary and _tr(n.get("b")):
				n.st = mini(6, (int(n.get("st", 0)) if int(n.get("st", 0)) != 0 else 1) + 1)
	for a in DI:
		var pb = G.g.get("penb")
		if pb is Dictionary and _tr(pb.get(a)):   # n1
			if not (G.g.get("penst") is Dictionary):   # u3
				G.g.penst = {}
			G.g.penst[a] = mini(6, (int(G.g.penst.get(a, 0)) if int(G.g.penst.get(a, 0)) != 0 else 1) + 1)
	G.g.sapst = mini(6, (int(G.g.get("sapst", 0)) if int(G.g.get("sapst", 0)) != 0 else 1) + 1)

# ------------------------------------------------------------------ địa danh, du hành
func cs(t) -> Variant:   # cs
	for a in cc:
		if a.id == t:
			return a
	return null

static func CX(t: Dictionary, a: Dictionary) -> float:   # CX: km theo đường tròn lớn
	var n := 6371.0
	var e := PI / 180.0
	var r := (float(a.lat) - float(t.lat)) * e
	var o := (float(a.lon) - float(t.lon)) * e
	var l := sin(r / 2) * sin(r / 2) + cos(float(t.lat) * e) * cos(float(a.lat) * e) * sin(o / 2) * sin(o / 2)
	return 2.0 * n * asin(sqrt(l))

func G4(t: Dictionary) -> float:   # G4
	return CX(R3, t)

func i3(t: Dictionary) -> int:   # i3: vé
	return _r(15.0 + G4(t) / 12.0)

func B7(t: Dictionary, a := false) -> int:   # B7: giây đi
	return _r((240.0 + G4(t) * 2.2) * (1.4 if a else 1.0))

func YO(t: Dictionary) -> int:   # YO: xu thưởng khi tới
	return _r(i3(t) * 1.5)

func o8(t: float) -> String:   # o8
	var x := int(maxf(0.0, ceil(t)))
	if x >= 600:
		return G.ao(x)
	return str(x / 60) + ":" + ("0" + str(x % 60)).right(2)

func Kg(t: Dictionary) -> bool:   # Kg: đã mở
	return int(t.unlock) == 0 or _tr(sys().unl.get(t.id))

func rH(t: Dictionary) -> String:   # rH
	if _tr(sys().visited.get(t.id)):
		return "vis"
	if Kg(t):
		return "open"
	return "lv" if jr() < int(t.get("lv", 1)) else "pts"

func SO(t: Dictionary) -> void:   # $O: mở khóa bằng điểm
	if Kg(t):
		return
	if jr() < int(t.get("lv", 1)):
		_ta(String(t.name) + " mở ở cấp " + str(t.lv) + ".")
		return
	var s := sys()
	if int(s.pts) < int(t.unlock):
		_ta("Cần " + str(t.unlock) + " điểm Hệ Thống để mở " + String(t.name) + ".")
		_kn()
		return
	s.pts = int(s.pts) - int(t.unlock)
	s.unl[t.id] = true
	_ta("Đã mở " + String(t.name) + ".")
	_kn()

func qX(t: Dictionary) -> void:   # qX: du hành
	var s := sys()
	if s.trip != null:
		_ta("Đang có một chuyến đi.")
		return
	if not Kg(t):
		SO(t)
		return
	var a := i3(t)
	if int(G.g.coins) < a:
		_ta("Cần " + str(a) + " xu cho chuyến đi này.")
		return
	G.g.coins = int(G.g.coins) - a
	var n := _now()
	var e := B7(t)
	s.trip = {"to": t.id, "t0": n, "t1": n + e * 1000.0, "cost": a}
	_ta("Khởi hành tới " + String(t.name) + ", mất " + o8(e) + ".")
	_kn()

func Ug() -> void:   # Ug (+ lớp bọc chở hàng, + lớp bọc No("trip"))
	var s := sys()
	var l: bool = s.trip is Dictionary and _now() >= float(s.trip.t1)
	_ug1()
	if l and not (s.trip is Dictionary):
		var f := _x("No")
		if f.is_valid():
			f.call("trip", 1)

func _ug1() -> void:   # lớp bọc chở hàng của Ug
	var s := sys()
	var e = s.trip
	if not (e is Dictionary) or _now() < float(e.t1):
		return
	var r = cs(e.to)
	if not e.has("cargo") or e.cargo == null:
		_ug0()
		return
	G.g.coins = int(G.g.coins) + int(e.pay)
	s.pts = int(s.pts) + 2
	s.spec[r.id] = int(s.spec.get(r.id, 0)) + 1
	s.visited[r.id] = int(s.visited.get(r.id, 0)) + 1
	G.nv.qi("trips")
	G.nv.qi("cargo")
	s.trip = null
	G.vib(80)   # gr([15, 40, 25])
	_ta("Bán hết hàng ở " + String(r.name) + ": +" + G.fmt_n(int(e.pay)) + " xu, 2 điểm và 1 " + String(r.spec).to_lower() + ".")
	fs = r.id
	_kn()

func _ug0() -> void:   # Ug gốc
	var s := sys()
	var t = s.trip
	if not (t is Dictionary) or _now() < float(t.t1):
		return
	var a = cs(t.to)
	var n: bool = not _tr(s.visited.get(a.id))
	var e := YO(a)
	var r := 5 if n else 2
	G.g.coins = int(G.g.coins) + e
	s.pts = int(s.pts) + r
	s.visited[a.id] = int(s.visited.get(a.id, 0)) + 1
	s.spec[a.id] = int(s.spec.get(a.id, 0)) + 1
	G.nv.qi("trips")
	s.trip = null
	G.vib(80)   # gr([15, 40, 25])
	_ta("Tới " + String(a.name) + ": nhận " + G.fmt_n(e) + " xu, " + str(r) + " điểm và " + String(a.spec) + ".")
	fs = a.id
	_kn()

func N7(text: String) -> void:   # N7: đăng review (text = #revText, sao = lp)
	var t = cs(fs)
	var a := text.strip_edges()
	var s := sys()
	if t == null or not _tr(s.visited.get(t.id)):
		return
	if not lp:
		_ta("Hãy chấm số sao trước.")
		return
	if a.length() < 10:
		_ta("Viết ít nhất 10 ký tự về trải nghiệm của bạn.")
		return
	var n: bool = not _tr(s.reviews.get(t.id))
	s.reviews[t.id] = {"s": lp, "t": a.substr(0, 240), "at": _now()}
	if n:
		s.pts = int(s.pts) + 8
		G.nv.qi("reviews")
	_ta("Đã đăng review, nhận 8 điểm Hệ Thống." if n else "Đã cập nhật review.")
	_kn()

func trip_rush_cost() -> int:   # BJ: Ro(giây còn lại) sen đỏ, 0 = không hiện nút
	var t = sys().trip
	if not (t is Dictionary):
		return 0
	var n := (float(t.t1) - _now()) / 1000.0
	return VNS.ro(n) if n > 0 else 0

func trip_rush() -> void:   # nút "Tới ngay" của BJ
	var r = sys().trip
	if not (r is Dictionary):
		return
	var o := (float(r.t1) - _now()) / 1000.0
	if o <= 0:
		return
	var l: int = VNS.ro(o)
	if G.spend_ngoc(l):
		r.t1 = _now() - 1
		r.t0 = minf(float(r.t0), float(r.t1) - 1)
		Ug()

# ------------------------------------------------------------------ thùng xe hàng (r8: TE, AX), $E
func r8_fx(c: int) -> String:   # r8.xe.fx
	return "Chở được " + str(20 + 10 * c) + " món mỗi chuyến"

func TE(t: String) -> int:   # TE
	return _r(float(r8[t].base) * pow(float(r8[t].mul), int(sys().shop.get(t, 0))))

func AX(t: String) -> void:   # AX
	var a: Dictionary = r8[t]
	var s := sys()
	if int(s.shop.get(t, 0)) >= int(a.max):
		return
	var n := TE(t)
	if int(s.pts) < n:
		_ta("Cần " + str(n) + " điểm Hệ Thống.")
		return
	s.pts = int(s.pts) - n
	s.shop[t] = int(s.shop.get(t, 0)) + 1
	_ta(String(a.name) + " lên cấp " + str(s.shop[t]) + ".")
	_kn()

func SE() -> int:   # $E: sức chở xe hàng
	return 20 + 10 * int(sys().shop.get("xe", 0))

# ------------------------------------------------------------------ chở hàng đi bán (vJ, mJ, tL, RH, BH, $7, HH, NH)
static func HH(t: float) -> String:   # HH: 1,25
	return str(round(t * 100.0) / 100.0).replace(".", ",")

func S7(t: Dictionary) -> float:   # $7: hệ số giá
	return 1.25 + minf(0.35, G4(t) / 4000.0)

func BH(t: Dictionary) -> int:   # BH: tiền xăng
	return _r(10.0 + G4(t) / 30.0)

func tL() -> int:   # tL: số món trên xe
	var t := 0
	for a in l1.q:
		t += int(l1.q[a])
	return t

func RH() -> int:   # RH: tiền bán dự tính
	var a := S7(l1.p)
	var n := 0.0
	for e in l1.q:
		n += int(l1.q[e]) * _price(e) * a
	return _r(n)

func NH(t: Dictionary) -> Array:   # NH: 4 món nơi đó cần hôm nay
	var a := jr()
	var id := String(t.id)
	var n = WC.yu(vr() * 733 + id.unicode_at(0) * 31 + (id.unicode_at(1) if id.length() > 1 else 7) * 7)
	var e := []
	for c in WC.Rl:
		var f: Dictionary = G.item(c)
		var ok := false
		if f.is_empty() or not (float(f.get("sell", 0)) > 0) or WC.OL.has(c) or G.bf(c) > a:
			ok = false
		elif t.r == "nam":
			ok = WC.Ge.has(c) or WC.Wf.has(c)
		elif t.r == "trung":
			ok = G.D.crops.has(c) or WC.Mv.has(c) or WC.Ge.has(c)
		else:
			ok = float(f.get("sell", 0)) >= 20
		if ok:
			e.append(c)
	if e.size() < 4:
		e = []
		for c in WC.Rl:
			var f: Dictionary = G.item(c)
			if not f.is_empty() and float(f.get("sell", 0)) > 0 and not WC.OL.has(c) and G.bf(c) <= a:
				e.append(c)
	var r := []
	var o := e.filter(func(c): return _barn(c) > 0)
	while r.size() < 2 and o.size() > 0:
		var l = o.pop_at(int(floor(n.next() * o.size())))
		r.append(l)
		e.remove_at(e.find(l))
	while r.size() < 4 and e.size() > 0:
		r.append(e.pop_at(int(floor(n.next() * e.size()))))
	return r

func vJ(t: Dictionary) -> bool:   # vJ: mở bảng chở hàng (true = UI mở OH)
	if sys().trip != null:
		_ta("Đang có một chuyến đi rồi.")
		return false
	if not Kg(t):
		_ta("Mở khóa " + String(t.name) + " trước đã.")
		return false
	l1.p = t
	l1.q = {}
	return true

func cg_adj(r: String, o: int) -> void:   # nút −/+/Hết trong bảng chở hàng (vJ click)
	var l := tL()
	var c := _barn(r)
	var f := int(l1.q.get(r, 0))
	if o > 0:
		f = mini(c, f + mini(o, SE() - l))
	elif o < 0:
		f = maxi(0, f + o)
	else:
		f = mini(c, f + SE() - l)
	l1.q[r] = f

func mJ() -> bool:   # mJ: xuất phát (true = đóng bảng t9)
	var t = l1.p
	var a := tL()
	var n := BH(t)
	var s := sys()
	if not a or s.trip != null:
		return false
	if int(G.g.coins) < n:
		_ta("Cần " + G.fmt_n(n) + " xu tiền xăng.")
		return false
	var e := []
	var r := RH()
	for o in l1.q:
		if int(l1.q[o]) > 0:
			if _barn(o) < int(l1.q[o]):
				_ta("Kho không đủ " + String(G.item(o).get("name", o)).to_lower() + ".")
				return false
			e.append([o, int(l1.q[o])])
	for f in e:
		G.g.barn[f[0]] = _barn(f[0]) - int(f[1])
	G.g.coins = int(G.g.coins) - n
	var l := _now()
	var c := B7(t, true)
	s.trip = {"to": t.id, "t0": l, "t1": l + c * 1000.0, "cost": n, "cargo": e, "pay": r}
	_ta("Xe hàng chở " + str(a) + " món lên đường đi " + String(t.name) + ", mất " + o8(c) + ".")
	_kn()
	return true

# ------------------------------------------------------------------ đặc sản (FH)
func FH(t: String) -> void:   # FH: dùng đặc sản
	var a = cs(t)
	var s := sys()
	if a == null or not (int(s.spec.get(t, 0)) > 0):
		return
	var n: PackedStringArray = String(a.get("use", "an:mat") if _tr(a.get("use")) else "an:mat").split(":")
	var e := n[0]
	var n1 := n[1] if n.size() > 1 else ""
	var spec := String(a.spec).to_lower()
	if e == "an":
		var r: Dictionary = G.g.pc
		r.en = minf(G.en_max(), float(r.en) + 30)
		if n1 != "" and Sf.has(n1):
			r.bf = {"k": n1, "u": _now() + 20 * 60000.0}
		_ta("Ăn " + spec + ": hồi 30 sức" + ((", được " + String(Sf[n1].n) + " (" + String(Sf[n1].d).to_lower() + ") 20 phút") if n1 != "" and Sf.has(n1) else "") + ".")
	elif e == "qua":
		var o = G.g.lang.get("fam") if G.g.get("lang") is Dictionary else null
		var l: Array = o.keys() if o is Dictionary else []
		if l.is_empty():
			_ta("Chưa có hàng xóm để biếu.")
			return
		l.sort_custom(func(x, k): return float(o[x].get("tim", 0)) < float(o[k].get("tim", 0)))   # sort ổn định gần đúng
		var c: Dictionary = o[l[0]]
		c.tim = mini(5, int(c.get("tim", 0)) + 1)
		_ta("Biếu nhà " + String(c.n) + " " + spec + ". Nhà " + String(c.n) + " thân thêm 1 ♥.")
	elif e == "giong":
		if t == "na":
			var R: Dictionary = G.nv._lang()
			R.cg.ft_cam = int(R.cg.get("ft_cam", 0)) + 1
			_ta("Được 1 cây giống cam. Vào Xây dựng › Cây ăn trái để trồng miễn phí, chưa tới cấp cũng trồng được.")
		else:
			var f: Array = WC.P4() if WC != null else ["lua"]
			var s2 = f[int(floor(randf() * f.size()))]
			G.g.barn[s2] = _barn(s2) + 5
			var h = WR.Wc[int(floor(randf() * WR.Wc.size()))]
			G.g.barn[h] = _barn(h) + 1
			_ta("Được 5 hạt " + _crop_n(s2).to_lower() + " và 1 hạt " + _crop_n(h).to_lower() + " quý.")
	elif e == "vat":
		var p := []
		for d in 2:
			var v: String = OO[int(floor(randf() * OO.size()))]
			if v == "gach":
				v = "van"
			G.nv.S0(v, 1)
			p.append(_mat_n(v).to_lower())
		_ta("Đổi " + spec + " lấy " + ", ".join(p) + ".")
	s.spec[t] = int(s.spec[t]) - 1
	_kn()

# ------------------------------------------------------------------ cửa hàng Hệ Thống (d3, WH, kJ, jH)
func d3() -> Dictionary:   # d3: g.sys với lượt mua trong ngày
	var t := sys()
	if not (t.get("buy") is Dictionary) or int(t.buy.get("d", -1)) != vr():
		t.buy = {"d": vr()}
	return t

func wh_ok(f: Dictionary) -> bool:   # WH[].ok (true khi món không có ok)
	var s := sys()
	match String(f.id):
		"ve":
			return s.trip is Dictionary and _now() < float(s.trip.t1)
		"boost":
			return not (float(s.get("boost", 0)) > _now())
		"bgl":
			var o := htS()
			return not o.has("bglw") or o.bglw == null or int(o.bglw) != int(floor(vr() / 7.0))
	return true

func _wh_run(id: String) -> void:   # WH[].run
	var s := sys()
	match id:
		"ve":
			var t: Dictionary = s.trip
			t.t1 = _now()
			t.t0 = minf(float(t.t0), float(t.t1) - 1)
			_ta("Tới nơi rồi.")
		"mat":
			var t := []
			for a in 3:
				var n: String = OO[int(floor(randf() * OO.size()))]
				if n == "gach":
					n = "dinh"
				G.nv.S0(n, 1)
				t.append(_mat_n(n).to_lower())
			_ta("Mở gói được: " + ", ".join(t) + ".")
		"lai":
			var t = WR.Wc[int(floor(randf() * WR.Wc.size()))]
			WR.lai_add(t, 1)
			_ta("Được 1 hạt lai " + _crop_n(t).to_lower() + ".")
		"boost":
			s.boost = _now() + 30 * 60000.0
			_ta("Rải phân bón Hệ Thống: 30 phút tới cây lớn nhanh thêm 10%.")
		"bua":
			G.nv.bp(1)
			_ta("Dán bùa: 24 giờ tới +50% kinh nghiệm.")
		"bgl":
			var o := htS()
			o.bgl = int(o.get("bgl", 0)) + 1
			o.bglw = int(floor(vr() / 7.0))
			_ta("Cất 1 bùa giữ lễ, lần thi nghề tới chắc chắn qua.")

func kJ(t: String) -> void:   # kJ: mua ở cửa hàng Hệ Thống
	var a = null
	for e in WH:
		if e.id == t:
			a = e
	if a == null:
		return
	var n := d3()
	if _tr(a.get("lv")) and jr() < int(a.lv):
		_ta("Cấp " + str(a.lv) + " mới mua được.")
		return
	if not wh_ok(a):
		_ta("Chưa dùng được lúc này.")
		return
	if _tr(a.get("lim")) and int(n.buy.get(t, 0)) >= int(a.lim):
		_ta("Hôm nay mua đủ rồi, mai quay lại.")
		return
	if int(n.pts) < int(a.c):
		_ta("Cần " + str(a.c) + " điểm Hệ Thống.")
		return
	n.pts = int(n.pts) - int(a.c)
	n.buy[t] = int(n.buy.get(t, 0)) + 1
	_wh_run(t)
	_kn()

func jH() -> float:   # jH: phân bón Hệ Thống +10% tốc độ ruộng
	return 0.1 if G.g.get("sys") is Dictionary and float(G.g.sys.get("boost", 0)) > _now() else 0.0

# ------------------------------------------------------------------ nâng cấp khác g.up (Y8, oG, d8, X7)
func _up() -> Dictionary:
	if not (G.g.get("up") is Dictionary):
		G.g.up = {}
	for k in Gp:
		if not G.g.up.has(k):
			G.g.up[k] = 0
	return G.g.up

func Y8(t: String) -> int:   # Y8
	return _r(float(Gp[t].base) * pow(float(Gp[t].mul), int(_up()[t])))

func d8(t: String) -> int:   # d8: cấp còn thiếu (0 = mở)
	var a := int(UJ.get(t, 1))
	return a if jr() < a else 0

func gp_fx(k: String, t: int) -> String:   # Gp[k].fx
	match k:
		"well": return "Nước giữ " + str(25 + 10 * t) + " giây"
		"fert": return ("Cây lớn nhanh hơn " + str(2 * t) + "%") if t else "Tốc độ bình thường"
		"stall": return ("Giá bán cao hơn " + _jsn(1.25 * t).replace(".", ",") + "%") if t else "Giá bán gốc"
		"pen": return ("Vật nuôi cho sản phẩm nhanh hơn " + str(3 * t) + "%") if t else "Tốc độ bình thường"
		"xuong": return ("Xưởng chế biến nhanh hơn " + _jsn(2.5 * t).replace(".", ",") + "%") if t else "Tốc độ bình thường"
	return ""

static func _jsn(v: float) -> String:   # Number.toString (bỏ ".0")
	return str(int(v)) if v == floor(v) else str(v)

func AH(t: int) -> int:   # AH: cấp mở thêm nấc nâng cấp
	var a := jr()
	return 0 if t >= 8 else (80 if a < 80 else (86 if a < 86 else (92 if a < 92 else 0)))

func X7(_t: String) -> int:   # X7: bậc tối đa theo cấp
	var a := jr()
	return 8 if a >= 92 else (7 if a >= 86 else (6 if a >= 80 else 5))

func oG(t: String) -> void:   # oG
	var a: Dictionary = Gp[t]
	if d8(t):
		_ta("Lên cấp " + str(d8(t)) + " mới nâng cấp được " + String(a.name).to_lower() + ".")
		return
	var u := _up()
	if int(u[t]) >= X7(t):
		return
	var n := Y8(t)
	if int(G.g.coins) < n:
		_ta("Cần " + G.fmt_n(n) + " xu để nâng cấp.")
		return
	G.g.coins = int(G.g.coins) - n
	u[t] = int(u[t]) + 1
	_ta(String(a.name) + " lên cấp " + str(u[t]) + ".")
	G.vib(15)
	_kn()

# ------------------------------------------------------------------ chấm đỏ (wX)
func badges() -> Dictionary:   # wX: số trên #ordBdg, #sysBdg, #upBdg, #mapBdg ("!")
	var t := 0
	var n := 0
	var r = G.g.sys.get("trip") if G.g.get("sys") is Dictionary else null
	var f := _x("OF")
	if f.is_valid():
		t = int(f.call())
	else:
		for l in G.g.orders:
			var ok := true
			for c in l.items:
				if not (_barn(c[0]) >= int(c[1])):
					ok = false
			if ok:
				t += 1
	for l in Z9:
		if int(_up()[l]) < int(Gp[l].max) and int(G.g.coins) >= Y8(l):
			n += 1
	if not GO:
		GO = true
		var st = G.g.sys.get("stats") if G.g.get("sys") is Dictionary else null
		if (int(st.get("harvest", 0)) if st is Dictionary else 0) < 10:
			coach.emit()
	return {"ord": t, "sys": htRed(), "up": n, "map": 1 if r is Dictionary and _now() >= float(r.t1) else 0}

# ------------------------------------------------------------------ mục tiêu tân thủ (Dc, #goalGo, fy)
func j5() -> int:   # j5: số khu đã khai hoang
	var t := 0
	if G.lang != null and G.lang.F != null:
		for a in G.lang.F.PC.x1:
			if G.lang.F.pc_own(a):
				t += 1
	return t

func _pens_n(k: String) -> int:   # g.pens[k].length
	var p = G.g.get("pens")
	return (p.get(k, []) as Array).size() if p is Dictionary and p.get(k) is Array else 0

func dc_cur(i: int) -> int:   # Dc[i].cur()
	match i:
		0: return int(S5("harvest").call())
		1, 15, 20: return ru()
		2, 12: return int(G.g.get("delivered", 0))
		3, 19, 21, 26: return j5()
		4: return (G.g.get("objs", []) as Array).size()
		5: return _pens_n("ga")
		6: return int(S5("collect").call())
		7:
			for t in G.g.plots:
				if _tr(t.get("u")) and int(t.get("st", 0)) > 1:
					return 1
			return 0
		8: return 1 if G.cd("mill") else 0
		9: return int(S5("mill").call())
		10: return 1 if G.cd("oven") else 0
		11: return int(S5("oven").call())
		13: return _pens_n("bo")
		14: return _pens_n("cuu")
		16: return int(S5("trips").call())
		17: return int(S5("cargo").call())
		18:
			var h = G.g.get("ht")
			if h is Dictionary and h.get("nv") is Dictionary:
				for q in h.nv.get("l", []):
					if _tr(q.get("ok")):
						return 1
			return 0
		22, 24, 25: return G.lang.beauty() if G.lang != null else 0
		23:
			var a := 0
			for o in G.g.get("objs", []):
				if o.get("id", "") == "hut" or o.get("id", "") == "house":
					a += 1
			return a
		27:
			var fi = G.g.get("fish")
			return int(fi.get("total", 0)) if fi is Dictionary else 0
	return 0

func goal_view() -> Dictionary:   # fy: {} = ẩn #goal
	var a := int(G.g.get("goal", 0))
	if a < 0 or a >= Dc.size():
		return {}
	var n: Dictionary = Dc[a]
	var mx := int(n.max)
	var r := mini(mx, dc_cur(a))
	var l := r >= mx
	return {"no": "Mục tiêu " + str(a + 1) + "/" + str(Dc.size()) + " · thưởng " + str(int(n.xu)) + " xu và " + str(int(n.pts)) + " điểm Hệ Thống",
		"txt": String(n.t) + ((" (" + str(r) + "/" + str(mx) + ")") if mx > 1 else ""),
		"bar": float(_r(float(r) / mx * 100.0)) / 100.0, "go": l, "btn": "Nhận " + str(int(n.xu)) + " xu", "ready": l}

func goal_claim() -> bool:   # #goalGo click
	var i := int(G.g.get("goal", 0))
	if i < 0 or i >= Dc.size():
		return false
	var t: Dictionary = Dc[i]
	if mini(int(t.max), dc_cur(i)) < int(t.max):
		return false
	G.g.coins = int(G.g.coins) + int(t.xu)
	sys().pts = int(sys().pts) + int(t.pts)
	G.g.goal = i + 1
	G.vib(60)   # gr([12, 30, 18])
	_ta("Hoàn thành mục tiêu: +" + str(int(t.xu)) + " xu, +" + str(int(t.pts)) + " điểm Hệ Thống.")
	_kn()
	return true

# ------------------------------------------------------------------ Hệ Thống Nhà Nông g.ht
static func htP(v: float) -> String:   # htP
	return str(_r(v * 100.0)) + "%"

func ht_d(x: Dictionary, k: int) -> String:   # x.d(x.v[k]) = mo_ta[k]
	var m: Array = x.get("mo_ta", [])
	return String(m[clampi(k, 0, m.size() - 1)]) if m.size() > 0 else ""

func htS() -> Dictionary:   # htS
	var o = G.g.get("ht")
	if not (o is Dictionary):
		o = {}
		G.g.ht = o
	if not (o.get("n") is Dictionary):
		o.n = {}
	if not (o.get("c") is Dictionary):
		o.c = {}
	if not (o.get("td") is Dictionary):
		o.td = {}
	if not _tr(o.get("mig")):
		o.mig = 1
		o.lv = jr()
		var gv := maxi(0, (jr() - 1) * 5)
		if G.g.get("pc") is Dictionary and G.g.pc.has("sk"):
			G.g.pc.erase("sk")
		if gv and G.g.get("sys") is Dictionary:
			G.g.sys.pts = int(G.g.sys.get("pts", 0)) + gv
			_mig_msg = "Kỹ năng nhân vật đã gộp vào Hệ Thống: nhận " + str(gv) + " điểm để mở cây phát triển."
			_mig_t = 3.6
	if not (o.get("lv") is int or o.get("lv") is float):
		o.lv = jr()
	return o

func htv(id: String) -> float:   # htv: giá trị hiện tại của nút (0 = chưa có)
	var o = G.g.get("ht")
	var x = HTI.get(id)
	if not (o is Dictionary) or not (o.get("n") is Dictionary) or x == null:
		return 0.0
	var k := int(o.n.get(id, 0))
	return float(x.v[mini(k, x.v.size()) - 1]) if k > 0 and not _tr(x.get("soon")) else 0.0

func htC(k: String, n := 1) -> void:   # htC (lớp bọc S8 gọi)
	var o := htS()
	o.c[k] = int(o.c.get(k, 0)) + (n if n else 1)

func htCap(b: String) -> int:   # htCap: tầng tối đa của nhánh
	var o := htS()
	return 5 if o.get("c0") == b else (3 if o.get("p0") == b else 1)

func htTier(b: String, t: int) -> int:   # htTier
	var o := htS()
	var n := 0
	for x in HTN:
		if x.b == b and int(x.t) == t:
			n += int(o.n.get(x.id, 0))
	return n

func htWhy(x: Dictionary) -> String:   # htWhy: lý do chưa nâng được ("" = được)
	var o := htS()
	var k := int(o.n.get(x.id, 0))
	var t := int(x.t)
	if _tr(x.get("soon")):
		return "Sắp có"
	if k >= x.v.size():
		return "Tối đa"
	if jr() < int(HTLV[t - 1]):
		return "Cấp " + str(HTLV[t - 1])
	if t > htCap(x.b):
		if _tr(o.get("c0")):
			return "Chỉ nhánh chính" if t > 3 else "Nhánh chính, phụ"
		return "Chưa chốt nhánh" if jr() >= int(HTLV[1]) else "Chọn nhánh ở cấp 15"
	if t > 1 and htTier(x.b, t - 1) < (3 if t == 5 else 2):
		return "Cần " + str(3 if t == 5 else 2) + " bậc tầng " + str(t - 1)
	if int(sys().pts) < int(HTGIA[t - 1]):
		return str(HTGIA[t - 1]) + " điểm"
	return ""

func htBuy(id: String) -> void:   # htBuy
	var x = HTI.get(id)
	if x == null:
		return
	var w := htWhy(x)
	if w != "":
		_ta("Đã nâng tối đa." if w == "Tối đa" else ("Cần " + w + " Hệ Thống." if w.ends_with("điểm") else w + "."))
		return
	sys().pts = int(sys().pts) - int(HTGIA[int(x.t) - 1])
	var o := htS()
	o.n[id] = int(o.n.get(id, 0)) + 1
	var k := int(o.n[id])
	_ta(String(x.n) + ((" lên bậc " + str(k)) if x.v.size() > 1 else "") + ": " + ht_d(x, mini(k, x.v.size()) - 1) + ".")
	_kn()

func htSpent() -> int:   # htSpent
	var o := htS()
	var s := 0
	for x in HTN:
		s += int(o.n.get(x.id, 0)) * int(HTGIA[int(x.t) - 1])
	return s

func _nv_any_ok(o: Dictionary) -> bool:   # o.nv.l.some(q => q.ok)
	for q in o.nv.get("l", []):
		if _tr(q.get("ok")):
			return true
	return false

func htChon(a: String, b: String) -> void:   # htChon: "c" chính, "p" phụ, "ok" xác nhận, "lai" chọn lại
	var o := htS()
	if not (HTV.pick is Dictionary):
		HTV.pick = {}
	var P: Dictionary = HTV.pick
	if _tr(o.get("c0")):
		return
	if jr() < int(HTLV[1]):
		_ta("Cấp " + str(HTLV[1]) + " mới chọn nhánh.")
		return
	if a == "c":
		P.c = b
		if P.get("p") == b:
			P.p = null
	elif a == "p":
		if not _tr(P.get("c")) or b == P.get("c"):
			return
		P.p = b
	elif a == "lai":
		HTV.pick = null
	elif a == "ok" and _tr(P.get("c")) and _tr(P.get("p")):
		o.c0 = P.c
		o.p0 = P.p
		HTV.pick = null
		HTV.br = o.c0
		if o.get("nv") is Dictionary and not _nv_any_ok(o):
			o.nv = null
		_ta("Đã chốt: nhánh chính " + String(HTB[o.c0]) + ", nhánh phụ " + String(HTB[o.p0]) + ". Nhiệm vụ ngày theo nhánh chính.")
		G.mark()

func htReset() -> void:   # htReset: tẩy điểm
	var o := htS()
	if _tr(o.get("tay")) and vr() - int(o.tay) < 7:
		_ta("Tẩy điểm 7 ngày một lần, còn " + str(7 - (vr() - int(o.tay))) + " ngày.")
		return
	if int(G.g.get("ngoc", 0)) < HTTAY:   # K0
		_ta("Cần " + str(HTTAY) + " sen đỏ.")
		var f := _x("Pu")
		if f.is_valid():
			f.call("nap")
		return
	var s := htSpent()
	G.nv.x0(-HTTAY)
	sys().pts = int(sys().pts) + s
	o.n = {}
	o.c0 = null
	o.p0 = null
	o.tay = vr()
	if o.get("nv") is Dictionary and not _nv_any_ok(o):
		o.nv = null
	_ta("Tẩy điểm: hoàn " + str(s) + " điểm, chọn lại nhánh.")
	_kn()

func htQGen(b, mul := 1.0, pts := 0) -> Dictionary:   # htQGen
	if not mul:
		mul = 1.0
	var L := HTQ.filter(func(q): return not _tr(b) or q[1] == b)
	var q: Array = WRS._t0(L)
	var r: Array = q[3]
	var m := maxi(1, _r((int(r[0]) + int(floor(randf() * (int(r[1]) - int(r[0]) + 1)))) * mul))
	return {"id": q[0], "t": String(q[2]).replace("{n}", str(m)), "k": q[4], "m": m,
		"b0": int(htS().c.get(q[4], 0)), "pts": pts if pts else int(q[5])}

func htQCur(q: Dictionary) -> int:   # htQCur
	return mini(int(q.m), maxi(0, int(htS().c.get(q.k, 0)) - int(q.b0)))

func htQOk(q) -> bool:   # htQOk
	return q is Dictionary and not _tr(q.get("ok")) and htQCur(q) >= int(q.m)

func htNv() -> Dictionary:   # htNv: nhiệm vụ ngày, tuần
	var o := htS()
	var d := vr()
	var w := int(floor(d / 7.0))
	if not (o.get("nv") is Dictionary) or int(o.nv.get("d", -1)) != d:
		var l := []
		var b = o.get("c0")
		var used := {}
		for i in 3:
			var q: Dictionary
			var tr := 0
			while true:
				q = htQGen(b if i < 2 and _tr(b) else null)
				if not used.has(q.id):
					break
				var go := tr < 9
				tr += 1
				if not go:
					break
			used[q.id] = 1
			l.append(q)
		o.nv = {"d": d, "l": l, "doi": 0}
	if not (o.get("tu") is Dictionary) or int(o.tu.get("w", -1)) != w:
		o.tu = {"w": w, "q": htQGen(o.get("c0") if _tr(o.get("c0")) else null, 5, 100)}
	return o

func htDoi(i: int) -> void:   # htDoi: đổi 1 nhiệm vụ ngày
	var o := htNv()
	var L: Array = o.nv.l
	if i < 0 or i >= L.size():
		return
	var q: Dictionary = L[i]
	if _tr(q.get("ok")):
		return
	if _tr(o.nv.get("doi")):
		_ta("Hôm nay đổi rồi, mai đổi tiếp.")
		return
	var n: Dictionary
	var tr := 0
	while true:
		n = htQGen(o.c0 if i < 2 and _tr(o.get("c0")) else null)
		var same: bool = n.id == q.id
		for z in L:
			if z.id == n.id:
				same = true
		if not same:
			break
		var go := tr < 12
		tr += 1
		if not go:
			break
	L[i] = n
	o.nv.doi = 1
	G.mark()

func htNhan(q) -> void:   # htNhan
	if q == null or not htQOk(q):
		return
	q.ok = 1
	sys().pts = int(sys().pts) + int(q.pts)
	G.vib(50)   # gr([10, 30, 10])
	_ta("Xong nhiệm vụ \"" + String(q.t) + "\": +" + str(q.pts) + " điểm Hệ Thống.")
	_kn()

func htKh() -> Dictionary:   # htKh: nhiệm vụ khẩn 1–2 lần/ngày, 8–22 giờ, làm trong 2 tiếng
	var o := htS()
	var now := _now()
	var d := vr()
	var h: int = Time.get_datetime_dict_from_system().hour
	if not (o.get("kh") is Dictionary) or int(o.kh.get("d", -1)) != d:
		o.kh = {"d": d, "n": 0, "nx": now + _r(WRS._nn(0.5, 3) * 3600000.0)}
	var k: Dictionary = o.kh
	if k.get("q") is Dictionary and not _tr(k.q.get("ok")) and now > float(k.q.t1):
		_ta("Nhiệm vụ khẩn \"" + String(k.q.t) + "\" hết giờ.")
		k.q = null
		G.mark()
	if not (k.get("q") is Dictionary) and int(k.n) < 2 and now >= float(k.nx) and h >= 8 and h < 22:
		var q := htQGen(null, 0.5, 20)
		q.t0 = now
		q.t1 = now + 2 * 3600000.0
		q.t = "Khẩn: " + String(q.t)
		k.q = q
		k.n = int(k.n) + 1
		k.nx = now + _r(WRS._nn(3, 6) * 3600000.0)
		_ta("Nhiệm vụ khẩn: " + String(q.t).replace("Khẩn: ", "").to_lower() + " trong 2 tiếng.")
		G.mark()
	return k

func SC(t: int) -> int:   # $C: số nhà thân >= t ♥
	var a = G.g.get("lang")
	var n := 0
	if a is Dictionary and a.get("fam") is Dictionary:
		for e in a.fam:
			if float(a.fam[e].get("tim", 0)) >= t:
				n += 1
	return n

func _td_c(id: String) -> bool:   # HTTD[i][3]()
	match id:
		"c20": return jr() >= 20
		"c40": return jr() >= 40
		"c60": return jr() >= 60
		"than5": return SC(5) >= 1
		"cuoi": return _tr(G.g.get("cuoi"))
		"chuc1", "chuc2", "chuc3", "chuc4":
			var f := _x("utS_c")
			return f.is_valid() and int(f.call()) >= int(id.substr(4))
		"sao3", "sao5":
			var f := _x("ngSao_max")
			return f.is_valid() and int(f.call()) >= int(id.substr(3))
		"ct":
			var c = G.g.get("ct")
			return c is Dictionary and _tr(c.get("n"))
	return false

func htTdOk(t: Array) -> bool:   # htTdOk
	var o := htS()
	if _tr(o.td.get(t[0])):
		return false
	return _td_c(String(t[0]))

func htTdNhan(id: String) -> void:   # htTdNhan
	var t = null
	for x in HTTD:
		if x[0] == id:
			t = x
			break
	if t == null or not htTdOk(t):
		return
	htS().td[id] = 1
	sys().pts = int(sys().pts) + int(t[2])
	_ta("Thành tựu \"" + String(t[1]) + "\": +" + str(t[2]) + " điểm Hệ Thống.")
	_kn()

func htRed() -> int:   # htRed: chấm đỏ nút Hệ Thống
	var o := htNv()
	var n := 0
	for q in o.nv.l:
		if htQOk(q):
			n += 1
	if htQOk(o.tu.q):
		n += 1
	var k = o.kh.get("q") if o.get("kh") is Dictionary else null
	if k is Dictionary and htQOk(k):
		n += 1
	for t in HTTD:
		if htTdOk(t):
			n += 1
	if not _tr(o.get("c0")) and jr() >= int(HTLV[1]):
		n += 1
	return n

func htBgl() -> bool:   # htBgl: bùa giữ lễ cháy (thi nghề)
	var o := htS()
	if int(o.get("bgl", 0)) > 0:
		o.bgl = int(o.bgl) - 1
		_ta("Bùa giữ lễ cháy, thầy du di cho qua.")
		return true
	return false

func htNgay(NGNGAY: int) -> int:   # htNgay: điểm tay nghề mỗi ngày
	return NGNGAY + int(htv("g_dem"))

func htTk(ins: Array) -> void:   # htTk: xưởng tiết kiệm 1 nguyên liệu
	var x := htv("g_tk")
	if x and randf() < x and ins.size() > 0:
		var z: Array = WRS._t0(ins)
		G.g.barn[z[0]] = _barn(z[0]) + 1
		_ta("Tiết kiệm được 1 " + String(G.item(z[0]).get("name", z[0])).to_lower() + ".")

# hiệu lực các nút (lớp bọc của bản web; bộ ráp gọi ở đúng chỗ)
func ht_tn_rate(r: float) -> float:   # tnRate bọc: thiên tai hư cây ít đi
	return r * (1.0 - htv("n_chiu"))

func ht_after_plant(t: int, quiet := false) -> void:   # Ev bọc (gieo thành công): phân xanh
	if randf() < htv("n_xanh"):
		var c = G.g.plots[t].c
		G.g.barn[c] = _barn(c) + 1
		if not quiet:
			G.float_text.emit(float(G.cells[t].gx), float(G.cells[t].gy), "+1 giống (phân xanh)")   # _p

func ht_dat_before(t: int) -> Array:   # dat(Xu) trước khi gặt: [c, số trong kho]
	var p = G.g.plots[t]
	var c = p.get("c") if p is Dictionary else null
	return [c, _barn(c) if c != null else 0]

func ht_dat_after(t: int, r: bool, pre: Array) -> void:   # dat(Xu) sau khi gặt: đất lành gấp đôi lần đầu mỗi ngày
	var p = G.g.plots[t]
	var c = pre[0]
	var o = G.g.get("ht")
	if r and c != null and htv("n_dat") and o is Dictionary and o.get("dl") != vr() and not _tr(p.get("c")):
		var n := _barn(c) - int(pre[1])
		if n > 0:
			G.g.barn[c] = _barn(c) + n
			o.dl = vr()
			G.float_text.emit(float(G.cells[t].gx), float(G.cells[t].gy), "+" + str(n) + " đất lành")

func ht_ghe(c0: int) -> void:   # Hd bọc: mối ghe trả thêm (c0 = xu trước khi đổi)
	var x := htv("t_ghe")
	if x and int(G.g.coins) > c0:
		var b := _r((int(G.g.coins) - c0) * x)
		G.g.coins = int(G.g.coins) + b
		if b:
			_ta("Mối ghe trả thêm " + G.fmt_n(b) + " xu.")

func ht_deliver(c0: int) -> void:   # ks bọc: giá chợ + mối ruột (c0 = xu trước khi giao)
	var d := int(G.g.coins) - c0
	var o := htS()
	if d > 0:
		var b := _r(d * htv("t_cho"))
		if htv("t_moi") and o.get("mr") != vr():
			o.mr = vr()
			b += d
		if b:
			G.g.coins = int(G.g.coins) + b
			_ta("Hệ Thống: đơn này thêm " + G.fmt_n(b) + " xu.")

func htTick(dt: float) -> void:   # htTick: mỗi giây
	HTK -= dt
	if HTK > 0:
		return
	HTK = 1.0
	if _cr() or not (G.g.get("sys") is Dictionary):
		return
	var o := htS()
	var lv := jr()
	if lv > int(o.lv):
		var n := (lv - int(o.lv)) * 5
		G.g.sys.pts = int(G.g.sys.get("pts", 0)) + n
		o.lv = lv
		_ta("Lên cấp: +" + str(n) + " điểm Hệ Thống.")
		G.mark()
	elif lv < int(o.lv):
		o.lv = lv
	htKh()
	red = htRed()
	render.emit()   # htRender (bảng tự giới hạn 1 giây)

# ------------------------------------------------------------------ nhắc lần đầu (Kh, ZZ, wO, XZ)
func Kh() -> Dictionary:   # Kh
	var t = G.g.get("tut")
	if not (t is Dictionary):
		t = {}
		G.g.tut = t
	if not (t.get("h") is Dictionary):
		t.h = {}
	if not (t.get("rd") is Dictionary):
		t.rd = {}
	return t

func _jg_c(id: String) -> bool:   # jg[i].c() (bọc _Z: lỗi = false)
	var f := _x("jg_" + id)
	if f.is_valid():
		return bool(f.call())
	var g: Dictionary = G.g
	match id:
		"wx": return G.troi != null and (G.troi.cur == "mua" or G.troi.cur == "giong")
		"giong": return G.troi != null and G.troi.cur == "giong"
		"han": return G.troi != null and G.troi.cur == "han"
		"met": return float(g.pc.en) < G.en_max() * 0.2
		"buff": return G.bh() != ""
		"dem": return G.night
		"dam": return g.get("dam") is Dictionary and _tr(g.dam.get("ev"))
		"culao": return G.lang != null and G.lang.ci("culao")
		"tim3", "tim5":
			if id == "tim5" and _tr(g.get("cuoi")):
				return false
			return SC(3 if id == "tim3" else 5) > 0
		"sao1":
			if not (jr() >= 3 and G.can_pay(G.up_need(2))):
				return false
			for t in g.plots:
				if int(t.get("st", 0)) > 1:
					return false
			return true
		"vatlieu":
			for t in OO:
				if t != "gach" and G.mat_n(t) > 0:
					return true
			return false
		"chohang": return jr() >= 4 and not (sys().trip is Dictionary) and int(S5("cargo").call()) < 1
		"khoa": return jr() >= 2 and jr() < 4
	return false

func ZZ(t: float) -> void:   # ZZ: bước "sotay" (web: Cr thì không chạy)
	var bf := _x("busy")
	var a: bool = bf.is_valid() and bool(bf.call())
	if is_tip != null and a:
		if _tr(is_tip.get("hid")):
			Kh().h.erase(is_tip.hid)
		is_tip = null
		tip_hide.emit()
		JC = _now() + 20000
		return
	if is_tip != null:
		is_tip.tm = float(is_tip.tm) - t
		if float(is_tip.tm) <= 0:
			wO()
	XC -= t
	if XC > 0:
		return
	XC = 2
	var n := Kh()
	if _tr(n.get("off")) or _cr() or is_tip != null or a or int(G.g.get("goal", 0)) < 2 or _now() < JC:
		return
	for r in jg:
		if not _tr(n.h.get(r.id)) and _jg_c(String(r.id)):
			n.h[r.id] = 1
			is_tip = {"hid": r.id, "tm": 16.0}   # XZ
			tip_show.emit(r)
			G.mark()
			return

func wO() -> void:   # wO: đóng thẻ nhắc
	if is_tip != null:
		is_tip = null
		tip_hide.emit()
		JC = _now() + 40000

func tip_off() -> void:   # XZ nút "Tắt nhắc lần đầu"
	Kh().off = 1
	G.mark()
	_ta("Đã tắt nhắc lần đầu. Bật lại trong Sổ tay hướng dẫn.")
	wO()

# ------------------------------------------------------------------ làm quen Cô Ba (ZY, SF, XY, CF, bước "tut")
func ZY() -> void:   # ZY
	if U0.on:
		return
	U0.on = true
	U0.i = 0
	var tt = G.g.get("tt")
	U0.b0 = {"plant": int(sys().stats.get("plant", 0)), "harvest": int(sys().stats.get("harvest", 0)),
		"del": int(G.g.get("delivered", 0)), "w": int(tt.get("w", 0)) if tt is Dictionary else 0, "nw": G.nv.Xs("water")}
	SF()

func SF() -> void:   # SF
	var i := int(U0.i)
	if i >= pA.size():
		CF(false)
		return
	_pa_enter(i)
	tut_text.emit(String(pA[i].t), "Bước " + str(i + 1) + "/" + str(pA.size()))

func _pa_done(i: int) -> bool:   # pA[i].done()
	var b: Dictionary = U0.b0
	var st: Dictionary = sys().stats
	match i:
		0: return int(st.get("plant", 0)) > int(b.plant)
		1:
			var tt = G.g.get("tt")
			return (int(tt.get("w", 0)) if tt is Dictionary else 0) > int(b.w) or G.nv.Xs("water") > int(b.nw)
		2: return int(st.get("harvest", 0)) > int(b.harvest)
		3: return int(G.g.get("delivered", 0)) > int(b.del)
		4:
			var f := _x("G2")
			return f.is_valid() and bool(f.call())
	return false

func _pa_enter(i: int) -> void:   # pA[i].enter()
	match i:
		2:
			for t in G.g.plots:
				if _tr(t.get("u")) and t.get("c") != null and not G.ripe(t):
					t.g = float(G.crop(t.c).time)
			G.mark()
		3:
			var t: String = "lua" if G.D.crops.has("lua") else String(G.xo[0])
			var o := {"who": "Bà Năm", "shop": "hàng xóm", "items": [[t, 2]], "reward": 60}
			if G.g.orders.is_empty():
				G.g.orders.append(o)
			else:
				G.g.orders[0] = o
			if _barn(t) < 2:
				G.g.barn[t] = 2
			G.mark()
		4:
			_go_t = 0.9

func XY() -> void:   # XY (bàn tay chỉ chỗ: lớp giao diện tự lo theo pA[i] — tg là DOM / camera)
	if not U0.on:
		return
	var i := int(U0.i)
	if i < pA.size() and _pa_done(i):
		U0.i = i + 1
		SF()

func CF(t: bool) -> void:   # CF: xong / bỏ qua làm quen
	U0.on = false
	G.g.tuDone = 1
	tut_end.emit()
	if not t:
		G.g.coins = int(G.g.coins) + 100
		_ta("Xong phần làm quen! Thưởng 100 xu. Giờ tự do làm vườn, nhớ ghé Nhiệm vụ mỗi ngày nha.")
	G.mark()

func tut_step(t: float) -> void:   # ui({id:"tut"}).step
	if _zy_t >= 0:
		_zy_t -= t
		if _zy_t < 0:
			ZY()
	if _go_t >= 0:
		_go_t -= t
		if _go_t < 0:
			var f := _x("go")
			if f.is_valid():
				f.call()
	if not U0.on and TF and not _tr(G.g.get("tuDone")) and G.g.get("pc") is Dictionary and _tr(G.g.pc.get("made")) and not _cr():
		TF = false
		_zy_t = 1.2
	vA -= t
	if vA > 0:
		return
	vA = 0.1
	XY()

# ------------------------------------------------------------------ bước mỗi khung
func step(t: float, offline: bool) -> void:
	if _mig_t >= 0:
		_mig_t -= t
		if _mig_t < 0:
			_ta(_mig_msg)
	if offline:
		return
	htTick(t)
	if not _cr():
		ZZ(t)
	tut_step(t)
