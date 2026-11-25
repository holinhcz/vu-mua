extends RefCounted
# Câu cá, lờ lọp, thú cưng (vịt, cá nuôi, mèo, chào mào), tát ao, thả diều: chép 1:1 luật bản web.
#   câu cá g.fish (JF sửa khi tải, rY đếm cho nhiệm vụ): (bản 527) câu cũ đã bỏ, câu cá = minigame logic/cc (ui_cc.gd), sổ (iV, Tc, oV),
#   lờ lọp giăng câu g.lo (T1, Jd, qk, KU, Bm, Bk, w4, L6, UU, fR, sR, Rk, ZU, Nk, GS, hZ, _U, t_, $U),
#   thú cưng g.pet (Cc, dN, WQ, Xx, Jx, GQ, jQ, DQ, VQ, uZ, tK, nK, wg + bọc, f6, e6, o6, r6, ZT, _x, _b, w2, CH),
#   tát ao g.tat (Am, WN, y4, QK, b6 + bọc, KK, DN, yS, UK),
#   thả diều g.dieu (Fh, xk, Cg, cU, fU, dU, ZN, pU, AS, v1).
# Vẽ (SX, _K, gU, XU, XQ, JQ, _Q, gN, uU), âm thanh (Jt, tk, $x, hU, aK), hạt bay, rung DOM: không chép.

var G
var ui = null              # w_ca_ui.gd (gán ở _init của nó)
var WR = null              # w_ruong.gd: qs, o0, n4, qf, _yh (người ghép gán)
var WC = null              # w_cho.gd: YT, T_ ($T) (người ghép gán)
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
var Wf := []               # mã cá (cau_ca/ds_ca: cá cũ còn trong công thức, lờ / lọp / giăng)
var Wcc := []              # (bản 540) 16 loại cá của Câu cá (cc_data.KHO, theo bậc) + cá chép (giăng câu): Bộ sưu tập > Cá + sổ cá vườn
var ns := {}               # lờ, lọp, giăng câu
var m6 := []               # cá tát ao
var k4 := []               # diều
var Z7 := {}               # tên chức năng
const FS := ["lo", "lop", "giang"]
const Nh := {"vit": 600, "meo": 300}   # (bản 546) bỏ cá nuôi, chào mào
const t6 := 8              # đàn vịt tối đa
const a6 := 300.0          # giây no của vịt mỗi lần rải lúa

# ------------------------------------------------------------------ trạng thái không lưu
var M3 := -1               # rY
var yf = null              # Yf: chọn chỗ thả {k, buy, cb, msg, sub, at}
var ai = null              # tát ao
var zi = null              # thi diều
var l6 := 0.0              # vịt chạy tới bờ (vẽ)
var c6 := 0.0              # cá ngoi lên ăn (vẽ)
var qi_hap := 0.0          # Qi.hap: mèo vui (vẽ)
var XT := {}               # w2
var _zt_v := -1            # uN
var _zt = null             # v4
var _ul := 0.0             # rY mỗi giây
var _ds := 0.0             # dS: WQ mỗi giây
var _ht := 0.0             # hT: iV mỗi 2 giây
var _wq_msg := ""          # WQ setTimeout 3 giây
var _wq_t := 0.0

func _init(game) -> void:
	G = game
	Wf = _ja("cau_ca/ds_ca")
	Wcc = preload("res://logic/cc/cc_data.gd").KHO.values()
	Wcc.append("ca_chep")   # (bản 544) cá chép: chỉ giăng câu ra, vẫn vô sổ / Bộ sưu tập
	ns = _jd("cau_ca/lo_lop_cau_giang")
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

func _pc() -> Dictionary:   # fr()
	return G.g.pc

func _qi(k: String) -> void:   # qi
	G.nv.qi(k)

func _w1(t: int, k: String) -> void:   # w1
	G.add_xp(t, k)

func _v0(t: float) -> int:   # v0
	return G.nv.v0(t)

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

func _wall() -> Array:   # cá câu cá + cá cũ (không trùng)
	var a := Wcc.duplicate()
	for e in Wf:
		if not a.has(e):
			a.append(e)
	return a

# ------------------------------------------------------------------ câu cá: bản lưu
func jf(t) -> Dictionary:   # JF: sửa g.fish khi tải
	var a := {"rod": 0, "total": 0, "dex": {}}
	if not (t is Dictionary):
		return a
	a.rod = maxi(0, mini(4, int(t.get("rod", 0)) if _num(t.get("rod")) else 0))
	a.total = maxi(0, int(t.get("total", 0)) if _num(t.get("total")) else 0)
	for e in _wall():
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

func ry() -> void:   # rY: đếm cá câu cho sổ nhiệm vụ (mỗi giây)
	var f = G.g.get("fish")
	var t := int(f.get("total", 0)) if f is Dictionary else 0
	if M3 < 0:
		M3 = t
		return
	if t > M3:
		G.nv.qi("fish", t - M3)   # qi: đếm cả thành tựu Tay câu, ngày câu cá của hội làng
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

# (Link 11-23 "nối hết") câu cũ đã bỏ: danh hiệu Tay câu tính 16 loài của minigame Câu Cá Bờ Kênh (cc_data.KHO, món Kho vườn),
# câu được con nào thì ui_cc "caught" ghi sổ làng (tc().seen)
const CC_WF := ["ca_ro", "ca_sac", "ca_linh", "ca_mevinh", "ca_chot", "ca_tre", "tom", "ca_loc", "ca_he", "luon", "ca_thatlat", "ca_bong",
	"ca_locbong", "ca_chinh", "ca_ho", "ca_tradau"]
# danh hiệu (Bs): [id, tên, mô tả, max, thưởng]; cur theo id ở bs_cur
const BS := [["nong", "Nhà nông chính hiệu", "Thu được 12 loại nông sản", 12, 2000],
	["vuon", "Nhà vườn miệt thứ", "Có 8 loại trái cây, sản vật vườn sông", 8, 3000],
	["kheo", "Thợ khéo tay", "Làm ra 20 món chế biến, sản phẩm", 20, 5000],
	["cau", "Tay câu cự phách", "Câu đủ 16 loài cá ở Câu Cá Bờ Kênh", -1, 8000],
	["dung", "Người dựng làng", "Xây, đặt 25 loại công trình và đồ vật", 25, 6000],
	["than", "Con cháu của làng", "3 gia đình thân thiết đủ 5 ♥", 3, 8000],
	["lao", "Lão nông tri điền", "Đạt cấp 100, mở tượng Lão nông trong Xây dựng", 100, 20000],
	["all", "Làng kiểu mẫu", "Đạt hết các danh hiệu khác", 7, 30000]]

func bs_list() -> Array:   # Bs: [{id, n, d, max, xu}]
	var out := []
	for b in BS:
		out.append({"id": b[0], "n": b[1], "d": b[2], "max": CC_WF.size() if int(b[3]) < 0 else int(b[3]), "xu": int(b[4])})
	return out

func book_ns() -> Array:   # xo: nông sản
	return G.xo

func book_tc() -> Array:   # dT: trái cây, sản vật
	return (WC.Mv if WC != null else []) + ["mat_ong", "dien_dien", "bong_sung", "keo_neo", "luc_binh"]

const TS_THEM := ["ca_keo", "oc", "oc_buou", "tep", "cua", "ech"]   # (11-25) bãi bùn + lờ / lọp: vô tab Thủy sản
func book_ts() -> Array:   # Bộ sưu tập > Thủy sản: cá câu + cá chép + đồ mò bãi bùn, lờ lọp
	var out := Wcc.duplicate()
	for t in TS_THEM:
		if not out.has(t):
			out.append(t)
	return out

func book_mon() -> Array:   # pT: món chế biến, sản phẩm (bỏ sản vật, thủy sản: đã ở tab Trái cây / Thủy sản)
	var bo := ["mat_ong", "dien_dien", "bong_sung", "keo_neo", "luc_binh"] + book_ts()
	var out := []
	for t in (WC.to if WC != null else []):
		if not (t in bo):
			out.append(t)
	return out

func book_ct() -> Array:   # gT: công trình, đồ vật
	var out := []
	var og: Array = G.lang.C.get("og", []) if G.lang != null else []
	for t in og:
		if not _tr(t.get("hide")) and t.id != "pond":
			out.append(String(t.id))
	return out

func cx(L: Array) -> int:   # Cx
	var a := tc()
	var n := 0
	for e in L:
		if _tr(a.seen.get(e)):
			n += 1
	return n

func bs_cur(id: String) -> int:
	match id:
		"nong": return cx(book_ns())
		"vuon": return cx(book_tc())
		"kheo": return cx(book_mon())
		"cau": return cx(CC_WF)
		"dung":
			var t := tc()
			var a := 0
			for n in book_ct():
				if _tr(t.obj.get(n)):
					a += 1
			return a
		"than":
			var c := 0
			var L = G.g.get("lang")
			if L is Dictionary and L.get("fam") is Dictionary:
				for k in L.fam:
					if float(L.fam[k].get("tim", 0)) >= 5:
						c += 1
			return c
		"lao": return G.lv()
		"all":
			var t := tc()
			var a := 0
			for b in BS:
				if b[0] != "all" and _tr(t.tt.get(b[0])):
					a += 1
			return a
	return 0

func tb(t: Dictionary) -> bool:   # tB: nhận được
	return not _tr(tc().tt.get(t.id)) and bs_cur(t.id) >= int(t.max)

func cv(id: String) -> void:   # cV: nhận danh hiệu
	var a = null
	for e in bs_list():
		if e.id == id:
			a = e
	if a == null or not tb(a):
		return
	var n := tc()
	n.tt[id] = 1
	n.cur = id
	G.g.coins = float(G.g.coins) + int(a.xu)
	_ta("Đạt danh hiệu \"" + String(a.n) + "\"! Thưởng " + _sa(a.xu) + " xu.")
	_gr([12, 30, 18])
	_ba()

func ab() -> Variant:   # aB: danh hiệu đang mang
	var t := tc()
	var a = null
	for n in bs_list():
		if _tr(t.tt.get(n.id)):
			a = n
	if _tr(t.get("cur")):
		for n in bs_list():
			if n.id == t.cur:
				a = n
	return a

# ------------------------------------------------------------------ kỷ lục nông sản (g.kl): trái khủng, tủ kỷ lục, hội thi tuần
# KLD[id] = [đơn vị, nặng thường (g), kỷ lục (g), gọi là, đo gì, cỡ thường (cm), độ ngọt thường] (data/ky_luc/can_nang.json, đã tính giống lai)
const KLHANG := ["Ngon", "Hảo hạng", "Thượng hạng", "Kỷ lục"]
const KLPRIZE := [[3000, 5], [2000, 3], [1200, 1]]
static var KLD := {}
var klq := []              # KLQ: trái khủng chờ hiện thẻ
var klw = null             # KLW: nhà làm thuê đang gặt

static func kld() -> Dictionary:
	if KLD.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/ky_luc/can_nang.json"))
		KLD = d if d is Dictionary else {}
	return KLD

func m_r() -> int:   # mR: tuần theo giờ thật
	return int(floor((_now() / 864e5 + 3.0) / 7.0))

func kl_st() -> Dictionary:   # klSt
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
	var w := m_r()
	if not (k.get("wk") is Dictionary) or int(k.wk.get("w", -1)) != w:
		if k.get("wk") is Dictionary and int(k.wk.w) == w - 1:
			k.pw = k.wk
		elif not (k.get("pw") is Dictionary) or int(k.pw.w) < w - 1:
			k.pw = null
		k.wk = {"w": w, "b": {}}
	return k

func kl_name(id: String) -> String:   # klName
	return G.item_name(id)

static func vi_num(v: float, dec := 3) -> String:   # toLocaleString("vi-VN"): 1.234,5
	var neg := v < 0.0
	v = absf(v)
	var ip := int(floor(v + 1e-9))
	var fr := snappedf(v - ip, pow(10.0, -dec))
	if fr >= 1.0:
		ip += 1
		fr = 0.0
	var s := str(ip)
	var o := ""
	while s.length() > 3:
		o = "." + s.substr(s.length() - 3) + o
		s = s.substr(0, s.length() - 3)
	o = s + o
	if fr > 0.0:
		var f := ("%." + str(dec) + "f") % fr
		f = f.substr(2).rstrip("0")
		if f != "":
			o += "," + f
	return ("-" if neg else "") + o

static func _js(v: float) -> String:   # String(number) của JS
	return str(int(v)) if v == floor(v) else str(v)

func kl_kg(g: float, id: String) -> String:   # klKg
	var d = kld().get(id)
	if d != null and d[0] == "g":
		return (vi_num(round(g * 10.0) / 10.0, 1) if g < 100.0 else str(int(round(g)))) + " g"   # (bản 526) 8,1 g (dấu phẩy như cm, kg)
	return vi_num(round(g / 10.0) / 100.0) + " kg"

func kl_num(v: float) -> String:   # klNum
	return vi_num(round(v * 10.0) / 10.0)

func lai_la(id: String) -> bool:   # laiLa
	return bool(G.crop(id).get("hyb", false))

func kl_care(kind: String, o: Dictionary) -> float:   # klCare: mức chăm 0..1
	var c := 0.0
	var w: String = G.nv.Wd()
	if kind == "crop":
		var p: Dictionary = o.p
		c += 0.3 * clampf((float(p.get("st", 1)) - 1.0) / 4.0, 0.0, 1.0)
		if _num(p.get("w")) and float(p.w) > 0.0:
			c += 0.15
		if G.in_season(String(o.id)):
			c += 0.2
		if lai_la(String(o.id)):
			c += 0.1
	else:
		if o.get("r") is Dictionary and _num(o.r.get("fw")) and float(o.r.fw) > 0.0:
			c += 0.25
		if _tr(o.get("bee")):
			c += 0.25
		c += 0.15
	if w == "nang" or w == "mua":
		c += 0.1
	if _tr(o.get("tal")):
		c += 0.1
	return minf(1.0, c)

func kl_roll(kind: String, id: String, o: Dictionary) -> Variant:   # klRoll: 1% + 2% × mức chăm (giống lai gấp 3)
	var lai := lai_la(id)
	var D = kld().get(id)
	if D == null or randf() >= (0.01 + 0.02 * kl_care(kind, o)) * (3.0 if lai else 1.0):
		return null
	var c := kl_care(kind, o)
	var x := pow(randf(), (4.0 if lai else 6.0) - 3.0 * c)
	var d1 := float(D[1])
	var g := d1 * (1.25 + (float(D[2]) / d1 - 1.25) * x)
	var h := 3 if x >= 0.92 else (2 if x >= 0.55 else (1 if x >= 0.2 else 0))
	var sz: float = round(float(D[5]) * pow(g / d1, 1.0 / 3.0) * 10.0) / 10.0
	var br: float = round((float(D[6]) * (0.95 + 0.25 * c) + randf() * 2.0) * 10.0) / 10.0 if float(D[6]) else 0.0
	var day: int = G.day()
	var f := {"id": id, "g": round(g * 10.0) / 10.0, "h": h, "s": sz, "br": br, "t": _now(), "d": day, "sea": G.season(), "day": posmod(day, 28) % 7 + 1,
		"wx": G.nv.Wd(), "st": int(o.p.get("st", 1)) if kind == "crop" and o.get("p") is Dictionary else 0, "who": String(o.get("who", "")), "c": int(round(c * 100.0))}
	return kl_keep(f)

func kl_keep(f: Dictionary) -> Dictionary:   # klKeep: cất vô tủ
	var k := kl_st()
	var old = k.b.get(f.id)
	f.rec = old == null or float(f.g) > float(old.g)
	if f.rec:
		k.b[f.id] = f
	k.r.push_front(f)
	if k.r.size() > 20:
		k.r.resize(20)
	k.n = int(k.get("n", 0)) + 1
	if not (float(k.wk.b.get(f.id, -1.0)) >= float(f.g)):
		k.wk.b[f.id] = f.g
	_ba()
	return f

func kl_harvest(kind: String, id: String, o: Dictionary) -> void:   # klHarvest: người chơi gặt thì hiện thẻ, người làm thuê gặt thì báo
	if klw is Dictionary:
		o.who = klw.n
		o.tal = String(klw.get("tal", "")) == ("ruong" if kind == "crop" else "vuon")
	var f = kl_roll(kind, id, o)
	if f == null:
		return
	G.nv.S8("kl")
	if String(f.who) != "":
		_ta(String(f.who) + " gặt được " + kl_name(id).to_lower() + " khủng " + kl_kg(f.g, id) + (", kỷ lục mới!" if f.rec else "!") + " Xem ở Tủ kỷ lục.")
	else:
		klq.append(f)
		var sh := _x("klShow")
		if sh.is_valid():
			sh.call()

func kl_info(f: Dictionary) -> Array:   # klInfo: [[nhãn, giá trị]]
	var D: Array = kld().get(f.id, ["g", 1, 1, "", "Cỡ", 1, 0])
	var se: String = (["Xuân", "Hạ", "Thu", "Đông"][int(f.sea)] if _num(f.get("sea")) and int(f.sea) >= 0 and int(f.sea) < 4 else "")
	var wx: String = {"nang": "nắng", "mua": "mưa", "rao": "mưa rào", "han": "hạn"}.get(String(f.get("wx", "")), String(f.get("wx", "")))
	var out := [["Cân nặng", kl_kg(f.g, f.id)], [String(D[4]), (str(int(round(float(f.s)))) + " củ") if D[4] == "Số củ" else kl_num(float(f.s)) + " cm"]]
	if _tr(f.get("br")):
		out.append(["Độ ngọt", kl_num(float(f.br)) + " °Bx"])
	out.append(["Thu ngày", ((se + " " + _js(float(f.day))) if se != "" else "") + ((" · trời " + wx) if wx != "" else "")])
	if _tr(f.get("st")):
		out.append(["Ô ruộng", _js(float(f.st)) + "★"])
	out.append(["Mức chăm", _js(float(f.c)) + "%"])
	if String(f.get("who", "")) != "":
		out.append(["Người gặt", String(f.who)])
	return out

func kl_price(f: Dictionary) -> int:   # klPrice
	var D: Array = kld().get(f.id, ["g", 1])
	return int(round(G.price(String(f.id)) * maxf(3.0, float(f.g) / float(D[1]) * 2.0)))

func kl_sell(i: int) -> void:   # klSell
	var k := kl_st()
	if i < 0 or i >= k.r.size():
		return
	var f: Dictionary = k.r[i]
	var xu := kl_price(f)
	G.g.coins = float(G.g.coins) + xu
	k.r.remove_at(i)
	_ta("Bán " + kl_name(f.id).to_lower() + " khủng " + kl_kg(f.g, f.id) + ": +" + _sa(xu) + " xu.")
	_ba()

func kl_pub() -> Dictionary:   # klPub
	var k := kl_st()
	var b := {}
	for id in k.b:
		b[id] = k.b[id].g
	return {"b": b, "wk": k.wk, "pw": k.get("pw")}

static func yu(t: int) -> Callable:   # yu: số ngẫu nhiên có hạt (mulberry32 kiểu web)
	var st := [t & 0xffffffff]
	return func() -> float:
		var a: int = (st[0] + 1831565813) & 0xffffffff
		st[0] = a
		var n: int = _imul(a ^ (a >> 15), 1 | a)
		n = ((n + _imul(n ^ (n >> 7), 61 | n)) & 0xffffffff) ^ n
		return float((n ^ (n >> 14)) & 0xffffffff) / 4294967296.0

static func _imul(a: int, b: int) -> int:   # Math.imul, giữ 32 bit không dấu
	return ((a & 0xffffffff) * (b & 0xffffffff)) & 0xffffffff

func kl_thi(w: int) -> Array:   # klThi: 4 loại thi tuần w
	var R: Callable = yu(w * 7919 + 13)
	var A := []
	var B := []
	var C := []
	var H := []
	for id in kld():
		if id.begins_with("qua_"):
			C.append(id)
		elif not G.crop(id).is_empty() and int(G.crop(id).get("lv", 1)) <= 15 and not lai_la(id):
			A.append(id)
		else:
			B.append(id)
		if lai_la(id):
			H.append(id)
	return [A, B, C, H].map(func(a): return a[int(floor(R.call() * a.size()))] if a.size() else "")

func kl_thi_rank(w: int, id: String) -> Array:   # klThiRank (chưa có bạn bè: chỉ làng mình)
	var k := kl_pub()
	var s = k.wk if int(k.wk.w) == w else (k.pw if k.pw is Dictionary and int(k.pw.w) == w else null)
	if s is Dictionary and float(s.b.get(id, 0)) > 0.0:
		return [{"n": os_name(), "me": true, "g": float(s.b[id])}]
	return []

func os_name() -> String:   # Os: tên làng / người chơi
	var p = G.g.get("pc")
	return String(p.get("name", "Bạn")).substr(0, 16) if p is Dictionary and String(p.get("name", "")) != "" else "Bạn"

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
		for e in _wall():
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
# (bản 547) 4 BẬC mỗi loại (lo_lop_cau_giang.json "up": bậc 2..4, nâng bằng xu + vật liệu nâng cấp): nst(t) = luật của bậc đang có
func lo_lv(t: String) -> int:
	return clampi(int(t1().get("lv", {}).get(t, 1)), 1, 1 + ns[t].get("up", []).size())

func nst(t: String) -> Dictionary:
	var e: Dictionary = ns[t]
	var v := lo_lv(t)
	if v <= 1:
		return e
	var o := e.duplicate()
	o.merge(e.up[v - 2], true)
	return o

func lo_next(t: String) -> Dictionary:   # bậc kế ({} = bậc 4 rồi)
	var v := lo_lv(t)
	var U: Array = ns[t].get("up", [])
	return U[v - 1] if v - 1 < U.size() else {}

func lo_up_ok(t: String) -> bool:
	var u := lo_next(t)
	if u.is_empty() or int(G.g.coins) < int(u.xu):
		return false
	for m in u.m:
		if G.mat_n(String(m[0])) < int(m[1]):
			return false
	return true

func lo_up(t: String) -> bool:
	var u := lo_next(t)
	if u.is_empty():
		return false
	if not lo_up_ok(t):
		_ta("Chưa đủ xu hoặc vật liệu để nâng.")
		return false
	G.g.coins = int(G.g.coins) - int(u.xu)
	for m in u.m:
		G.mat_add(String(m[0]), -int(m[1]))
	var T := t1()
	if not (T.get("lv") is Dictionary):
		T.lv = {}
	T.lv[t] = lo_lv(t) + 1
	_ta(String(ns[t].n) + " lên bậc " + str(T.lv[t]) + "!")
	_gr([12, 30, 18])
	_ba()
	return true

func ready_keys() -> Array:   # khoá các bẫy đang có cá
	var o := []
	for a in t1()["set"]:
		if w4(a):
			o.append(bk(a))
	return o

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
	return _now() - float(t.at) >= float(nst(t.t).ms)

func l6_ms(t: Dictionary) -> float:   # L6: ms còn lại
	return maxf(0.0, float(nst(t.t).ms) - (_now() - float(t.at)))

func ready_n() -> int:   # T1()["set"].filter(w4).length (tên tab "Lờ lọp (n)")
	var n := 0
	for a in t1()["set"]:
		if w4(a):
			n += 1
	return n

func fr_put(t: String, a: int, n: int) -> bool:   # fR: đặt bẫy
	var e: Dictionary = nst(t)
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
		_ta("Đã gỡ " + String(nst(n.t).n).to_lower() + " về cất. Đặt lại (Menu › Lờ lọp) khỏi tốn xu.")
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
	var n: Dictionary = nst(a.t)
	if not w4(a):
		_ta(String(n.n) + " mới đặt, chừng " + str(int(ceil(l6_ms(a) / 6e4))) + " phút nữa mới có.")
		return false
	var e := _now() - float(a.at) > float(n.ms) * 4.0
	var r := []
	for d in n.c:
		if d[0] != "ca_linh" or _qs():
			r.append([d[0], float(d[1]) * (float(n.get("k", 1.0)) if n.get("rare", []).has(d[0]) else 1.0)])   # (bản 547) bậc cao: con quý dễ vô
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
			if fi is Dictionary and fi.get("dex") is Dictionary and (fi.dex.get(d) is Dictionary or _wall().has(d)):   # (bản 544) cá trong sổ: chưa có mục thì tạo
				if not (fi.dex.get(d) is Dictionary):
					fi.dex[d] = {"n": 0, "best": 0.0}
				fi.dex[d].n = int(fi.dex[d].get("n", 0)) + int(l[d])
				if G.w_all != null:
					tc().seen[d] = 1
			h.append(str(l[d]) + " " + _nm(d).to_lower())
		c = "Thăm " + String(n.n).to_lower() + " được " + ", ".join(h) + (" (để lâu quá, cá xổng bớt)" if e else "") + (". Đêm cá ăn mạnh!" if G.night else ".")
		_no("lo", 1.0, [float(a.gx) + 0.5, float(a.gy) + 1.2])
		var hh := []
		for d in l:
			hh.append(str(l[d]) + " " + _nm(d))
		_a0(float(a.gx) + 0.5, float(a.gy) + 0.5, "+" + ", ".join(hh))
	a.u = int(a.u) + 1
	t1().n = int(t1().n) + 1
	if int(n.use) > 0 and int(a.u) >= int(n.use):   # (bản 547) bậc 4: use 0 = không mục
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
	var e: Dictionary = nst(t)
	if qk(t) >= jd(t):
		return ("Đặt hết " + String(e.n).to_lower() + " rồi. Mua thêm hoặc gỡ bớt.") if jd(t) else ("Chưa có " + String(e.n).to_lower() + ". Mua trước đã.")
	if ku(a, n) != null:
		return "Chỗ này đã có bẫy rồi."
	if _tr(e.get("river")) and _il(a, n) != "canal":
		return "Giăng câu phải đặt trên sông Vàm."
	return "" if _uu(a, n) else "Chỗ này xa bờ quá, lội không tới. Đặt sát mé nước (hoặc sắm xuồng ba lá)."

func lo_why(t: String, a: int, n: int) -> String:   # như gs, không bắt mua trước
	var e: Dictionary = nst(t)
	if qk(t) >= int(e.max):
		return "Đặt đủ " + str(int(e.max)) + " " + String(e.n).to_lower() + " rồi. Gỡ bớt cái cũ."
	if ku(a, n) != null:
		return "Chỗ này đã có bẫy rồi."
	if _tr(e.get("river")) and _il(a, n) != "canal":
		return "Giăng câu phải đặt trên sông Vàm."
	return "" if _uu(a, n) else "Chỗ này xa bờ quá, lội không tới. Đặt sát mé nước."

func lo_free(t: String) -> bool:   # còn cái cất sẵn: đặt khỏi trả xu
	return jd(t) > qk(t)

func lo_place(t: String) -> void:
	if not _jg("lo"):
		return
	var a: Dictionary = nst(t)
	if qk(t) >= int(a.max):
		_ta("Đặt đủ " + str(int(a.max)) + " " + String(a.n).to_lower() + " rồi. Gỡ bớt cái cũ.")
		return
	if t == "giang" and _o0() <= 0:
		_ta("Mở một khúc sông Vàm trước đã.")
		return
	if not lo_free(t) and int(G.g.coins) < int(a.xu):
		_ta("Cần " + _sa(a.xu) + " xu.")
		return
	var cb := func(x: int, y: int) -> bool:
		var r := lo_why(t, x, y)
		if r != "":
			_ta(r)
			return false
		var run := func() -> bool:
			var o := lo_why(t, x, y)
			if o != "":
				_ta(o)
				return false
			if not lo_free(t):
				if int(G.g.coins) < int(a.xu):
					_ta("Cần " + _sa(a.xu) + " xu.")
					return false
				G.g.coins = int(G.g.coins) - int(a.xu)
				t1().own[t] = jd(t) + 1
			return fr_put(t, x, y)
		var m = mt(x, y)
		var gl := _x("Gl")
		if m != null and gl.is_valid():
			gl.call({"key": "lop" + t + "@" + str(x) + "," + str(y), "kind": "lo", "pos": m.stand, "dur": 0.6, "run": run})
		else:
			run.call()
		return true
	var sub := "Ô xanh là chỗ đặt được: sông Vàm, sát mé bờ." if t == "giang" else "Ô xanh là chỗ đặt được: mương, ao, mé sông sát bờ."
	var bt = a.get("bait")
	if bt != null and _barn(String(bt[0])) < int(bt[1]):   # (bản 549) báo trước: hết mồi thì mỗi mẻ bớt 1 con
		sub = "Hết " + _nm(String(bt[0])).to_lower() + " làm mồi: đặt vẫn được nhưng mỗi mẻ ít hơn 1 con."
	wg("lo", false, {"msg": "Chạm ô nước để đặt " + String(a.n).to_lower() + ("" if lo_free(t) else " · " + _sa(a.xu) + " xu"), "sub": sub, "at": [G.ppos.x, G.ppos.y], "cb": cb, "lo": t})

func lo_info(key: String) -> Dictionary:   # vòng nút lờ: {n: tên, s: dòng phụ, ready}
	var a = bm(key)
	if a == null:
		return {}
	var n: Dictionary = nst(a.t)
	var r := w4(a)
	var P := ["Có cá rồi" if r else "Còn " + str(int(ceil(l6_ms(a) / 6e4))) + " phút"]   # (bản 549) ngắn cho vừa chip
	if n.get("bait") != null and not _tr(a.get("b")):
		P.append("hết mồi")
	P.append("không mục" if int(n.use) <= 0 else str(int(n.use) - int(a.u)) + " lần")
	return {"n": String(n.n) + " · bậc " + str(lo_lv(String(a.t))), "ready": r, "s": " · ".join(P)}

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

func lo_stand(key: String):   # $U: chỗ đứng thăm bẫy (bản 541: đứng trên bờ sát bẫy, không đứng giữa nước)
	var a = bm(key)
	if a == null:
		return null
	var m = mt(int(a.gx), int(a.gy))
	return m.stand if m != null else [float(a.gx) + 0.5, float(a.gy) + 0.5]

# ------------------------------------------------------------------ thú cưng (g.pet)
func cc() -> Dictionary:   # Cc
	var t = G.g.get("pet")
	if not (t is Dictionary):
		t = {}
		G.g.pet = t
	if not (t.get("vit") is Dictionary):
		t.vit = {"n": 0, "f": 0, "e": 0, "a": 0}
	if t.has("ca") or t.has("chim"):   # (bản 546) bỏ cá nuôi, chào mào: trả lại tiền mua
		if t.get("ca") is Dictionary and float(t.ca.get("n", 0)) > 0:
			G.g.coins = int(G.g.coins) + 240
		if t.get("chim") is Dictionary and _tr(t.chim.get("has")):
			G.g.coins = int(G.g.coins) + 900
		t.erase("ca")
		t.erase("chim")
	if not (t.get("meo") is Dictionary):
		t.meo = {"has": 0, "fd": -1, "gd": -1, "pt": 0, "tim": 0}
	for a in ["n", "f", "e", "a"]:
		var v = t.vit.get(a)
		if not _num(v) or is_nan(float(v)) or is_inf(float(v)):
			t.vit[a] = 0
	return t

func dn(t: float) -> void:   # dN: vịt ăn, đẻ trứng (cả lúc tắt game)
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



func vq(t: String) -> void:   # VQ: nút data-pet trong tab Nuôi thêm
	var a := cc()
	var n := int(Nh.get(t, 0))
	if (t == "vit" or t == "mvit") and not _jg("vit"):
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
	elif t == "mvit":
		wg("vit", false)
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
	_ba()
	_ec()

func uz(t: String) -> String:   # uZ: tên việc khi chạm con vật
	var a := cc()
	if t == "vit":
		return ("Lượm " + str(a.vit.e) + " trứng vịt") if _tr(a.vit.e) else ("Rải lúa cho vịt" if float(a.vit.f) < a6 * 0.6 else "Ra thăm vịt")
	if t == "meo":
		return "Vuốt ve" if int(a.meo.fd) == _vr() else "Cho mèo ăn"
	return "Đi tới"

func tk(t: String) -> Variant:   # tK: chữ nổi khi chạm con vật ({b, s} hoặc null)
	var a := cc()
	if t == "vit":
		return {"b": "Đàn vịt · " + str(a.vit.n) + " con", "s": (("Có " + str(a.vit.e) + " trứng vịt, chạm để lượm. ") if _tr(a.vit.e) else "") + ("Vịt đói, chạm để rải lúa." if float(a.vit.f) < a6 * 0.6 else "Vịt đang no.")}
	if t == "meo":
		return {"b": "Mèo Mướp", "s": "Đã ăn hôm nay. Chạm để vuốt ve." if int(a.meo.fd) == _vr() else "Đói rồi, chạm để cho ăn 1 con cá nhỏ."}
	return null

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
	if t == "vit" and not _jg("vit"):
		return
	_g2()
	yf = {"k": t, "buy": a, "cb": n.get("cb") if n is Dictionary else null,
		"msg": String(n.get("msg")) if n is Dictionary and _tr(n.get("msg")) else "Chạm vào mặt nước để thả " + ("vịt" if t == "vit" else "cá"),
		"sub": String(n.get("sub")) if n is Dictionary and _tr(n.get("sub")) else "Ô nước sáng viền vàng là chỗ thả được: ao sen, hồ, sông Vàm, ao tự đào.",
		"at": (n.get("at") if n is Dictionary else (w2(t).c if w2(t) != null else zt())),   # camera dời tới at (lớp làng)
		"lo": String(n.get("lo", "")) if n is Dictionary else ""}   # (bản 546) loại lờ đang đặt: song_ve tô ô xanh
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
		if WC != null:
			WC.T_(3)
	else:
		s.at = [r, o]
		_ta("Đã lùa đàn vịt qua " + o6(f) + ".")
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
	if g.get("lai") is Dictionary and g.lai.get("d") is Dictionary and g.lai.d.size():
		t.lai = 1
	if g.get("lang") is Dictionary and g.lang.get("fam") is Dictionary:
		for a in g.lang.fam:
			if g.lang.fam[a] is Dictionary and _tr(g.lang.fam[a].get("job")):
				t.thue = 1
	var p = g.get("pet")
	if p is Dictionary and (p.get("vit") is Dictionary and float(p.vit.get("n", 0)) > 0):
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
	_qi("tatao")
	_w1(5 + int(ai.n), "tat")
	_ba()
	if not t:
		_xs("Hết giờ! Bắt được " + str(ai.n) + " con. Nướng trui mời bà con xóm hay mang về hết?")
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

var dbg_wind := false   # hook thử "wind": coi như đang có gió
func cg() -> bool:   # Cg: đang có gió thả diều
	if dbg_wind:
		return true
	var xi: int = G.season()
	var w: String = String(G.troi.wx())
	if w == "":
		w = "nang"
	return (xi == 3 or xi == 0) and not G.night and _d0() >= 14.0 and _d0() < 18.5 and w != "mua" and w != "rao"

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
	if ai != null:   # DN
		dn_tat(t)
	if zi != null:   # ZN
		zn(t)
