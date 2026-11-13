extends RefCounted
# XU, CHỢ, GIÁ, CHỢ NỔI: phần luật bản web còn thiếu ở bản Godot.
#  - Chợ nổi sông Vàm (5–9 giờ sáng, 4 ghe s4): b2, u4, YB, jd (+ lớp bọc G8), Dd (+ lớp bọc A1 kho đủ chỗ, j9),
#    Wx / dQ (g.cho: mỗi kèo một lần mỗi ngày), gQ (bước mỗi khung: hiện dần, báo họp chợ g.chod, ghe rao hàng),
#    GT (chạm ghe), vQ (chỗ đứng), qN / BN phần "cho", và các hàm phụ KR, QR, P4, F6, f7, yu, v1, s2, ho, pQ, $B.
#  - Thả cá giống (hN), vịt con ($T, YT), con giống vô chuồng (VR, chỉ dùng khi bộ ráp chưa gán bản của hệ chuồng).
#  - Giá chợ huyện: g.mult trôi dần mỗi 45 giây (phần g.mt của vw), khởi tạo g.mult (W3 / phần nạp bản lưu),
#    bản tin radio $N, tin radio sáng chiều TU (Eg = g.thu).
#  - Giống nhà hàng xóm / lái gia súc: Km (g.gio), G6, Um (+ lớp bọc A1), bZ.
#  - g.dd: hái điên điển, súng ma, kèo nèo ven sông (cT, wx + lớp bọc A1) và Sp (g.dd của điểm danh tháng).
# Các hàm của hệ khác mà bản web gọi: bản Godot nhận qua ext (Callable) hoặc qua WR (w_ruong.gd); chưa gán thì
# làm như web khi hàm chưa có (typeof x == "function" sai) — chỗ nào web gọi thẳng thì ghi rõ ở ext.

signal panel_close        # i1(): $r.mode === "cho" mà chợ tan hẳn thì đóng bảng chợ nổi

var G
var WR = null             # w_ruong.gd (bộ ráp gán): qf, o0, km, sd_n, ol
var CA = null             # NTWEB w_ca.gd (bộ ráp gán): cc() là bản Cc dùng chung
# ext: hàm của hệ khác (bộ ráp gán).
#   SGEO_c(x: float) -> float        (SGEO.c: tâm sông Vàm theo gx; YB cần, thiếu thì YB trả null -> không có ghe để chạm)
#   SGEO_top(x: int) -> float        (SGEO.top: mép bờ trên; vQ cần khi chưa có xuồng)
#   Wr(x, y, n) -> bool              (Wr: điểm đang trong khung camera; thiếu thì coi như trong khung)
#   Mt_mode() -> String              (Mt.mode: "off" khi không xây dựng; thiếu thì "off")
#   qc() -> String                   (qc: "map" khi đang xem bản đồ; thiếu thì "")
#   Cr() -> bool                     (đang thăm làng bạn)
#   Jb() -> Dictionary               (lễ gần nhất trong 29 ngày {f: {n}, d, k}; {} = không có)
#   vS(k: String) -> Variant         (vS("rong"): giờ con nước ròng kế tiếp, null = không có)
#   o6(k: String) -> String          (o6: chỗ thả "ca" / "vit": "ao sen", "sông Vàm", "ao nhà", "mặt nước", "chưa có chỗ") — web gọi thẳng
#   e6() -> bool                     (e6: có mặt nước thả vịt) — web gọi thẳng trong YT
#   VR(id: String) -> bool           (VR của hệ chuồng; thiếu thì dùng _VR bên dưới, chép đúng web)
#   Bv(id: String, j: int, k: String)(typeof Bv == "function": bày con mới mua)
#   Vb() -> Array                    (Vb: điên điển / súng / kèo nèo ven sông [{gx, gy, key, kd, v}]) — web gọi thẳng trong wx
#   lT(o: Dictionary) -> bool        (lT: bụi đó hái được) — web gọi thẳng trong wx
#   j9()                             (j9: s5.t = 0, xóa nhớ danh sách hàng cần giữ W9)
var ext := {}

const JB := 5             # chợ nổi họp từ 5 giờ
const WM := 9             # tan lúc 9 giờ
const FQ := 30            # tối đa cá trong ao
const XF := 900           # Xf: cá lớn
const T6 := 8             # t6: tối đa vịt

var s4: Array = []        # 4 ghe chợ nổi
var Tq: Dictionary = {}   # đơn vị tính
var aC: Array = []        # đồ hiếm thương lái gửi
var DR: Dictionary = {}   # lái gia súc: số con giống mỗi ngày
var Di: Array = []        # các chuồng
var Ge: Dictionary = {}   # công thức
var to: Array = []        # thứ tự món chế biến
var Mv: Array = []        # trái cây
var Wf: Array = []        # cá
var xm: Dictionary = {}   # tên thời tiết
var OL: Dictionary = {}   # ol: giống lai
var W5: Dictionary = {}   # các khúc sông Vàm
var V4: Dictionary = {}   # cấp mở chức năng
var QQ: Dictionary = {}   # qr: vật nuôi chuồng
var Co: Dictionary = {}   # tên chuồng / xưởng
var Rl: Array = []        # mọi món (như w_kho.Rl)
const NNP := {"dd": {"p": "dien_dien", "n": "bông điên điển"}, "sm": {"p": "bong_sung", "n": "bông súng ma"}, "kn": {"p": "keo_neo", "n": "rau kèo nèo"}}   # window.__NN.P (p, n)

# Ui bản web: trạng thái chợ nổi (không lưu)
var Ui := {"al": 0.0, "day": -1, "offers": null, "sel": 0, "pos": null, "say": "", "sayT": 0.0, "sT": 4.0, "x0": 0, "sb": 0}
var _chod_t := -1.0       # setTimeout 1,5 giây của câu báo họp chợ
var zS := 0.0             # TU mỗi 2 giây

func _init(game) -> void:
	G = game
	s4 = G._j("cho/ghe_cho_noi")
	Tq = G._j("nong_trai/don_vi_tinh")
	aC = G._j("khac/aC")
	DR = G._j("khac/DR")
	Di = G._j("khac/Di")
	Ge = G._j("che_bien/cong_thuc")
	to = G._j("che_bien/thu_tu_hang")
	Mv = G._j("nong_trai/ds_trai_cay")
	Wf = G._j("cau_ca/ds_ca")
	xm = G._j("thoi_tiet/ten")
	OL = G._j("nong_trai/giong_lai")
	W5 = G._j("dat_dai/khu_song")
	V4 = G._j("nhan_vat/chuc_nang_mo_cap")
	QQ = G._j("vat_nuoi/vat_nuoi")
	Co = G._j("che_bien/ten_cong_trinh_lam_an")
	var seen := {}
	for L in [G.xo, to, Wf, Mv, G.D.crops.keys(), G.D.items.keys()]:
		for t in L:
			var k := String(t)
			if not seen.has(k) and not G.item(k).is_empty():
				seen[k] = 1
				Rl.append(k)

# ------------------------------------------------------------------ tiện ích
func _x(k: String) -> Callable:
	var c = ext.get(k)
	return c if c is Callable and (c as Callable).is_valid() else Callable()

static func _r(x: float) -> int:   # Math.round
	return int(floor(x + 0.5))

func _ta(s: String) -> void:   # ta / pn
	G.toast.emit(s)

func _sell(t: String, d: float) -> float:   # ae(t).sell || d
	var v := float(G.item(t).get("sell", 0))
	return v if v != 0.0 else d

func _nm(t: String) -> String:   # ae(t).name
	return String(G.item(t).get("name", t))

func _barn(t: String) -> int:   # g.barn[t] | 0
	return int(G.g.barn.get(t, 0))

func _add(t: String, n: int) -> void:   # g.barn[t] = (g.barn[t] || 0) + n
	G.g.barn[t] = _barn(t) + n

func _mode() -> String:   # Mt.mode
	var f := _x("Mt_mode")
	return String(f.call()) if f.is_valid() else "off"

func _cr() -> bool:   # Cr
	var f := _x("Cr")
	return bool(f.call()) if f.is_valid() else false

func _hour() -> float:   # d0 / aQ
	return G.nv.hour()

func _ei() -> Dictionary:   # Ei
	return G.lang.C.Ei if G.lang != null else {}

func _pi() -> Dictionary:   # Pi
	return G.lang.Pi if G.lang != null else {}

func _qf(t: String) -> int:   # qf
	if WR != null:
		return WR.qf(t)
	if G.g.get("cdOld") is Dictionary and G.g.cdOld.get(t):
		return 0
	var a := int(V4.get(t, 0))
	return a if G.lv() < a else 0

func O0() -> int:   # O0: số khúc sông Vàm đã mua
	if WR != null:
		return WR.o0()
	var t := 0
	for a in W5:
		if G.g.get("land") is Dictionary and G.g.land.get(a):
			t += 1
	return t

func _km() -> int:   # KM: số thùng ong
	if WR != null:
		return WR.km()
	var t := 0
	for o in G.g.get("objs", []):
		if o.get("id", "") == "thungong":
			t += 1
	return t

func _sdN(t: String) -> int:   # sdN
	if WR != null:
		return WR.sd_n(t)
	return _barn(t)

func _ci(t: String) -> bool:   # ci
	return G.lang != null and G.lang.ci(t)

func _lang0() -> Dictionary:   # R0
	return G.nv._lang()

func qi(t: String) -> void:   # qi: g.sys.stats[t] += 1
	G.nv.qi(t)

# ------------------------------------------------------------------ yu: bộ số ngẫu nhiên theo hạt giống (32 bit như JS)
class Yu:   # yu(t) trả về hàm a(): mỗi lần gọi một số trong [0, 1)
	var a := 0
	func _init(t: int) -> void:
		a = t & 0xffffffff
	func next() -> float:
		a = (a + 1831565813) & 0xffffffff
		var n: int = _imul_(a ^ (a >> 15), 1 | a)
		n = ((n + _imul_(n ^ (n >> 7), 61 | n)) & 0xffffffff) ^ n
		return float((n ^ (n >> 14)) & 0xffffffff) / 4294967296.0
	static func _imul_(x: int, y: int) -> int:   # Math.imul (32 bit thấp)
		x &= 0xffffffff
		y &= 0xffffffff
		var xl := x & 0xffff
		var xh := (x >> 16) & 0xffff
		var yl := y & 0xffff
		var yh := (y >> 16) & 0xffff
		return (xl * yl + ((((xh * yl) + (xl * yh)) & 0xffff) << 16)) & 0xffffffff

func yu(t: int) -> Yu:   # yu
	return Yu.new(t)

func v1() -> int:   # v1
	return mini(4, int(floor(float(G.g.get("delivered", 0)) / 2.0)))

static func _pick(W: Array, a: Yu):   # e(W) = W[floor(a() * W.length)]
	var i := int(floor(a.next() * W.size()))
	return W[i] if i < W.size() else null

static func _stable_sort(L: Array, key: Callable, desc: bool) -> Array:   # Array.prototype.sort (ổn định)
	var P := []
	for i in L.size():
		P.append([float(key.call(L[i])), i, L[i]])
	P.sort_custom(func(x, y): return (x[0] > y[0] if desc else x[0] < y[0]) if x[0] != y[0] else x[1] < y[1])
	var o := []
	for p in P:
		o.append(p[2])
	return o

# ------------------------------------------------------------------ chữ
func ho(t: String, a: int) -> String:   # ho: "4 bao gạo"
	return str(a) + " " + ((String(Tq[t]) + " ") if Tq.has(t) else "") + _nm(t).to_lower()

func pQ(t: Dictionary) -> String:   # pQ: tên kèo ghe bán
	var k: String = t.k
	if k == "giong":
		return str(int(t.q)) + " hạt giống " + _nm(t.id).to_lower()
	if k == "con":
		return "1 con " + String(QQ[t.id].name).to_lower() + " giống"
	if k == "cg":
		return "Cây giống " + String(_pi()[t.id].n).to_lower()
	if k == "cagiong":
		return str(int(t.q)) + " con cá giống"
	if k == "vitcon":
		return "1 con vịt con"
	return ho(t.id, int(t.q))

func bB(t: Dictionary) -> String:   # $B: mã hình của kèo (Ai)
	var k: String = t.k
	if k == "con":
		return String(QQ[t.id].make)
	if k == "cg":
		return String(_ei()[t.id].p)
	if k == "cagiong":
		return "ca_tra"
	if k == "vitcon":
		return "trung_vit"
	return String(t.id)

static func h5(t: float) -> String:   # h5: "×1,8"
	var s := str(int(t)) if t == floor(t) else str(t)
	return "×" + s.replace(".", ",")

static func mS(t) -> String:   # mS: "05:30"
	if t == null:
		return "--"
	var a := int(floor(float(t)))
	var n := int(floor((float(t) - a) * 60.0))
	return ("0" if a < 10 else "") + str(a) + ":" + ("0" if n < 10 else "") + str(n)

# ------------------------------------------------------------------ chợ nổi: giờ họp, chỗ ghe
func u4() -> Variant:   # u4: khúc sông Vàm có chợ (null = chưa mở)
	if O0() == 0:
		return null
	if _ci("song"):
		return "song"
	if _ci("song_dong"):
		return "song_dong"
	if _ci("song_tay"):
		return "song_tay"
	return null

func wm() -> int:   # wm (giờ tan chợ, cho bảng)
	return WM

func b2() -> bool:   # b2 (+ lớp bọc qf("cho"))
	if _qf("cho"):
		return false
	var t := _hour()
	return t >= JB and t < WM and u4() != null

func YB() -> Variant:   # YB: chỗ 4 ghe trên sông (null = không có)
	var t = u4()
	if t == null:
		return null
	var c := _x("SGEO_c")
	if not c.is_valid():
		return null
	var a := -17 if t == "song" else 29 if t == "song_dong" else -60
	var n := 26 if t == "song" else 60 if t == "song_dong" else -19
	var e: int = maxi(a + 1, mini(n - 9, 8 if t == "song" else 33 if t == "song_dong" else -30))
	if absi(e - 5) < 2:
		e = 7
	var o := []
	for d in [[0.6, -0.95], [2.4, 0.95], [4.4, -0.95], [6.2, 0.95]]:
		var x: float = e + float(d[0])
		o.append([x, float(c.call(x)) + float(d[1])])
	return o

func vQ(t: int):   # vQ(t)() -> Variant: chỗ nhân vật đứng mua bán với ghe t
	if Ui.pos == null:
		return null
	var a: Array = Ui.pos[t]
	if G.g.pc.get("xuong"):
		return [float(a[0]) + 0.3, float(a[1]) + (0.55 if t % 2 else -0.55)]
	var tp := _x("SGEO_top")
	return [float(a[0]), (float(tp.call(int(floor(float(a[0]))))) if tp.is_valid() else float(a[1])) - 0.3]

func GT(t: float, a: float):   # GT: chạm ghe (t, a: tọa độ màn hình làng như en/nn) -> {type: "cho", k} / null
	if float(Ui.al) < 0.5 or Ui.pos == null:
		return null
	for n in range(Ui.pos.size() - 1, -1, -1):
		var e: Array = Ui.pos[n]
		var r: float = G.lang.en(float(e[0]), float(e[1]))
		var o: float = G.lang.nn(float(e[0]), float(e[1]), 0.0)
		if absf(t - r) < 60.0 and a >= o - 100.0 and a <= o + 16.0:
			return {"type": "cho", "k": n}
	return null

func tap(k: int) -> void:   # qN phần "cho": Ui.sel = k rồi gu("cho") (bộ ráp mở w_cho_ui.open)
	Ui.sel = k

func tip(k: int) -> Array:   # BN phần "cho": [chữ đậm, chữ thường]
	return [String(s4[k].n), String(s4[k].d) + " Chạm để ra bến mua bán."]

# ------------------------------------------------------------------ g.cho: mỗi kèo một lần mỗi ngày
func Wx(t: int, a: int) -> bool:   # Wx
	var n = G.g.get("cho")
	return n is Dictionary and int(n.get("day", -1)) == G.day() and n.get("d") is Dictionary and bool(n.d.get(str(t) + "_" + str(a), 0))

func dQ(t: int, a: int) -> void:   # dQ
	var n: int = G.day()
	if not (G.g.get("cho") is Dictionary) or int(G.g.cho.get("day", -1)) != n:
		G.g.cho = {"day": n, "d": {}}
	G.g.cho.d[str(t) + "_" + str(a)] = 1

# ------------------------------------------------------------------ hàng của 4 ghe hôm nay
func s2() -> Array:   # s2: món đang làm ra được
	var t: Array = G._lv_items().duplicate()
	var a := {}
	var Ei := _ei()
	for n in G.g.get("objs", []):
		var e = Ei.get(n.get("id", ""))
		if e != null and not a.has(e.p):
			a[e.p] = 1
			t.append(e.p)
			t.append(e.p)
	if _km():
		t.append("mat_ong")
	if G.g.get("fish") is Dictionary and float(G.g.fish.get("total", 0)) > 0:
		t.append("ca_ro")
	return t.filter(func(n): return not G.item(String(n)).is_empty())

func tf(t: String) -> bool:   # tf: giống chưa mở
	if OL.has(t):
		return not (_sdN(t) > 0)
	var vs := 1
	if G.D.crops.has(t) and not G.crop(t).get("hyb", false):
		vs = int(G.crop(t).get("lv", 1))
		if vs == 0:
			vs = 1
	return vs > G.lv()

func P4() -> Array:   # P4: giống đã mở (không tính giống lai)
	return G.xo.filter(func(t): return not OL.has(t) and not tf(t))

func F6(t: String) -> int:   # F6: giá một hạt giống ở chợ
	var a: Dictionary = G.crop(t)
	return maxi(int(float(a.cost) * 2.0), _r(float(a.sell) * 0.9))

func f7(t: int, a: int) -> Array:   # f7: a giống ngẫu nhiên theo hạt t
	var n: Array = P4().duplicate()
	var e := yu(t)
	var r := []
	while n.size() and r.size() < a:
		r.append(n.pop_at(int(floor(e.next() * n.size()))))
	return r

func KR(t: Yu) -> Variant:   # KR: ghe cây giống bán 1 con giống chuồng
	var a := Di.filter(func(e): return G.vn.ok(e))
	if a.is_empty():
		return null
	var n: String = a[int(floor(t.next() * a.size()))]
	return {"t": "ban", "k": "con", "id": n, "q": 1, "xu": _r(float(QQ[n].buy) * 0.9)}

func QR(t: Yu) -> Array:   # QR: ghe lúa gạo bán hạt giống, đổi nông sản lấy giống
	var a := P4()
	var n := []
	var e := 0
	while e < 2 and a.size():
		var r: String = a.pop_at(int(floor(t.next() * a.size())))
		var o := 6 + int(floor(t.next() * 5))
		n.append({"t": "ban", "k": "giong", "id": r, "q": o, "xu": _r(o * F6(r) * 0.85)})
		e += 1
	var l: Array = G.xo.filter(func(d): return _barn(d) >= 3)
	var c := P4()
	if l.size() and c.size():
		var f: String = l[int(floor(t.next() * l.size()))]
		var s: String = c[int(floor(t.next() * c.size()))]
		if s == f:
			s = c[(c.find(s) + 1) % c.size()]
		var h := maxi(2, mini(12, _r(F6(s) * 4.0 / maxf(1.0, float(G.crop(f).sell)))))
		var p := 4
		if s != f:
			n.append({"t": "doi", "k": "giong", "g": f, "gq": h, "id": s, "q": p, "xu": 0})
	return n

func _jd0() -> Array:   # jd gốc
	var t: int = G.day()
	if int(Ui.day) == t and Ui.offers != null:
		return Ui.offers
	var a := yu(t * 7919 + 13)
	var n := v1()
	var r := s2()
	var o := func(W: Array) -> Array:
		var K := W.filter(func(ft): return _barn(String(ft)) > 0)
		return K if K.size() and a.next() < 0.75 else W
	var l := [[], [], [], []]
	var Pi := _pi()
	var c := _ei().keys().filter(func(W): return Pi.has(W))
	var f = _pick(c, a)
	var s = _pick(c.filter(func(W): return W != f), a)
	for W in [f, s]:
		if W != null:
			l[0].append({"t": "ban", "k": "cg", "id": W, "q": 1, "xu": _r(float(Pi[W].cost) * 0.8)})
	l[0].append({"t": "ban", "k": "cagiong", "id": "cagiong", "q": 10, "xu": 240})
	l[0].append({"t": "ban", "k": "vitcon", "id": "vitcon", "q": 1, "xu": 220})
	var h = KR(a)
	if h != null:
		l[0].append(h)
	var p: Array = o.call(Mv.filter(func(W): return r.has(W) or _barn(W) > 0) + Mv.slice(0, 3))
	var d = _pick(p, a)
	var v = _pick(p.filter(func(W): return W != d) + [d], a)
	var dv := [d, v]
	for K in 2:
		var W = dv[K]
		if not (K and W == d):
			var ft := _sell(W, 10)
			var j := maxi(2, mini(20, _r((200.0 + a.next() * 260.0) * (1.0 + 0.5 * n) / ft)))
			l[1].append({"t": "mua", "k": "item", "id": W, "q": j, "xu": _r(j * G.price(W) * (1.5 + a.next() * 0.25))})
	var x: String = _pick(["qua_saurieng", "qua_mangcut", "qua_chomchom", "qua_buoi", "qua_xoai", "qua_thanhlong"], a)
	var k := 2 + int(floor(a.next() * 3))
	l[1].append({"t": "ban", "k": "item", "id": x, "q": k, "xu": _r(k * _sell(x, 20) * 0.85)})
	var M: Array = o.call(G.xo.filter(func(W): return r.has(W)) + ["lua"])
	var T = _pick(M, a)
	var w = _pick(M.filter(func(W): return W != T) + [T], a)
	var tw := [T, w]
	for K in 2:
		var W = tw[K]
		if not (K and W == T):
			var ft := _sell(W, 10)
			var j := maxi(3, mini(40, _r((180.0 + a.next() * 240.0) * (1.0 + 0.5 * n) / ft)))
			l[2].append({"t": "mua", "k": "item", "id": W, "q": j, "xu": _r(j * G.price(W) * (1.4 + a.next() * 0.2))})
	for W in QR(a):
		l[2].append(W)
	l[2].append({"t": "ban", "k": "item", "id": "gao", "q": 4, "xu": _r(4 * _sell("gao", 20) * 0.9)})
	l[2].append({"t": "ban", "k": "item", "id": "bot", "q": 4, "xu": _r(4 * _sell("bot", 14) * 0.9)})
	l[3].append({"t": "ban", "k": "item", "id": "cui", "q": 6, "xu": 42})
	l[3].append({"t": "ban", "k": "item", "id": "soi", "q": 2, "xu": _r(2 * _sell("soi", 20) * 0.9)})
	l[3].append({"t": "ban", "k": "item", "id": "muoi_hot", "q": 3, "xu": _r(3 * _sell("muoi_hot", 10) * 0.9)})
	var E := to.filter(func(W): return _barn(W) > 0 and W != "cui" and Ge.has(W))
	if E.size():
		var C: String = _pick(E, a)
		var R := _sell(C, 20)
		var N := maxi(1, mini(10, _r((260.0 + a.next() * 300.0) * (1.0 + 0.5 * n) / R)))
		l[3].append({"t": "mua", "k": "item", "id": C, "q": N, "xu": _r(N * G.price(C) * 1.6)})
	var z := aC.filter(func(W): return not G.item(W).is_empty())
	if z.size():
		var rt: String = _pick(z, a)
		var dt := maxi(1, _r((300.0 + a.next() * 500.0) * (1.0 + 0.5 * n) / _sell(rt, 20)))
		l[3].append({"t": "ban", "k": "item", "id": rt, "q": dt, "xu": _r(dt * G.price(rt) * (1.2 + a.next() * 0.15)), "rare": 1})
	Ui.day = t
	Ui.offers = l
	return l

func jd() -> Array:   # jd (+ lớp bọc: lần sinh mới thì đổi món không làm ra được bằng G8)
	var o: bool = not (int(Ui.day) == G.day() and Ui.offers != null)
	G._ep = 0   # Ep = 0
	var l := _jd0()
	if o:
		for f in l.size():
			for h in l[f].size():
				var s: Dictionary = l[f][h]
				if s.k == "item":
					G8(s, G.day() * 11 + f * 5 + h)
	return l

func G9(t: String, a: int) -> bool:   # G9
	return G._f8(t) or _barn(t) >= (a if a else 1)

func Y_(t: String, a: int, n: int) -> String:   # $Y
	if G9(t, a):
		return t
	var e: Array = G.xo.filter(func(r): return G._f8(r))
	if e.is_empty():
		e = ["lua"]
	return e[absi(n) % e.size()]

func G8(t: Dictionary, a: int) -> Dictionary:   # G8: kèo ghe mua món người chơi không làm ra được -> đổi món
	if t.is_empty() or not t.get("id") or t.get("done") or (t.get("t") and t.t != "mua") or G9(String(t.id), int(t.get("q", 0))):
		return t
	var n: Dictionary = G.item(t.id)
	var e := Y_(String(t.id), int(t.get("q", 0)), a)
	var r := _sell(e, 10)
	var ns := float(n.get("sell", 0))
	var o: float = (ns if ns != 0.0 else 10.0) * int(t.q)
	var l := maxi(2, mini(40, _r(o / r)))
	var c := float(t.xu) / (int(t.q) * maxi(1, G.price(t.id))) if t.get("xu") and t.get("q") else 1.5
	t.id = e
	t.q = l
	if t.get("xu"):
		t.xu = _r(l * G.price(e) * c)
	return t

# ------------------------------------------------------------------ mua bán với ghe
func _dd_room(t: int, a: int) -> int:   # lớp bọc A1 của Dd: số chỗ kho cần
	var L := jd()
	if t < 0 or t >= L.size() or a < 0 or a >= L[t].size():
		return 0
	var n: Dictionary = L[t][a]
	if n.t == "mua":
		return 0
	if n.t == "doi":
		return maxi(0, int(n.q) - int(n.gq))
	if n.k in ["cg", "cagiong", "vitcon", "con"]:
		return 0
	return int(n.q) if int(n.get("q", 0)) else 1

func Dd(t: int, a: int) -> bool:   # Dd (+ lớp bọc A1: kho đủ chỗ; + j9 sau khi chạy)
	var need := _dd_room(t, a)
	if need > 0 and not G.kho_fit(need):
		return false
	var r := _dd(t, a)
	var f := _x("j9")
	if f.is_valid():
		f.call()
	return r

func _dd(t: int, a: int) -> bool:   # Dd gốc
	if not b2():
		_ta("Chợ đã tan. Mai 5 giờ sáng ghé lại nha.")
		return false
	var n := jd()
	var e = n[t][a] if t >= 0 and t < n.size() and a >= 0 and a < n[t].size() else null
	if e == null or Wx(t, a):
		return false
	if e.t == "doi":
		if _barn(e.g) < int(e.gq):
			_ta("Kho chưa đủ " + ho(e.g, int(e.gq)) + " để đổi.")
			return false
		G.g.barn[e.g] = _barn(e.g) - int(e.gq)
		_add(e.id, int(e.q))
		_ta("Đổi " + ho(e.g, int(e.gq)) + " lấy " + str(int(e.q)) + " hạt giống " + _nm(e.id).to_lower() + ".")
	elif e.t == "mua":
		if _barn(e.id) < int(e.q):
			_ta("Kho chưa đủ " + ho(e.id, int(e.q)) + ".")
			return false
		G.g.barn[e.id] = _barn(e.id) - int(e.q)
		G.g.coins = int(G.g.coins) + int(e.xu)
		_ta("Bán " + ho(e.id, int(e.q)) + " cho " + String(s4[t].n).to_lower() + ", nhận " + G.fmt_n(int(e.xu)) + " xu.")
	else:
		if int(G.g.coins) < int(e.xu):
			_ta("Chưa đủ " + G.fmt_n(int(e.xu)) + " xu.")
			return false
		if e.k == "vitcon" and not YT():
			return false
		if e.k == "con" and G.vn.list(e.id).size() >= G.vn.gl():
			_ta("Chuồng " + String(QQ[e.id].name).to_lower() + " đã đủ " + str(G.vn.gl()) + " con.")
			return false
		G.g.coins = int(G.g.coins) - int(e.xu)
		if e.k == "cg":
			var r := _lang0()
			r.cg[e.id] = int(r.cg.get(e.id, 0)) + 1
			_ta("Mua được cây giống " + String(_pi()[e.id].n).to_lower() + ". Vào Xây dựng › Cây ăn trái để trồng (miễn phí).")
		elif e.k == "cagiong":
			hN(int(e.q))
		elif e.k == "vitcon":
			T_(1)
		elif e.k == "con":
			if not VR(e.id):
				G.g.coins = int(G.g.coins) + int(e.xu)
				return false
		else:
			_add(e.id, int(e.q))
			_ta("Mua " + ho(e.id, int(e.q)) + " giá " + G.fmt_n(int(e.xu)) + " xu.")
	dQ(t, a)
	qi("cho")
	G.vib(10)
	Ui.say = ["Cảm ơn nghen!", "Mai ghé nữa nha!", "Hàng tươi rói đó!", "Đi chợ sớm vậy giỏi ghê!"].pick_random()
	Ui.sayT = 2.6
	Ui.sb = t
	G.mark()
	return true

# ------------------------------------------------------------------ cá giống, vịt con, con giống chuồng
func _Cc() -> Dictionary:   # Cc (g.pet, chép đúng web; hệ thú cưng làm chủ)
	if CA != null:   # NTWEB: một bản Cc (w_ca.cc)
		return CA.cc()
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
		if not (v is float or v is int) or is_nan(float(v)) or is_inf(float(v)):
			t.vit[a] = 0
	for a in ["n", "g", "f"]:
		var v = t.ca.get(a)
		if not (v is float or v is int) or is_nan(float(v)) or is_inf(float(v)):
			t.ca[a] = 0
	return t

func _o6(k: String) -> String:   # o6 (web gọi thẳng)
	var f := _x("o6")
	return String(f.call(k)) if f.is_valid() else ""

func hN(t: int) -> void:   # hN: thả cá giống xuống ao
	var a: Dictionary = _Cc().ca
	if float(a.n) > 0 and float(a.g) >= XF:
		_ta("Ao đang có cá lớn, kéo lưới trước rồi thả lứa mới.")
		G.g.coins = int(G.g.coins) + 240
		return
	a.n = mini(FQ, int(a.n) + t)
	if int(a.n) == t:
		a.g = 0
	_ta("Thả " + str(t) + " con cá giống xuống " + _o6("ca") + ". Rải cám (bột) cho cá ăn, khoảng 15 phút cá lớn.")

func T_(t: int) -> void:   # $T: thả vịt con
	var a: Dictionary = _Cc().vit
	a.n = mini(T6, int(a.n) + t)
	if float(a.f) < 60:
		a.f = 60
	_ta("Thả vịt con xuống " + _o6("vit") + ". Cho vịt ăn lúa thì vịt đẻ trứng.")
	# Qd = null: nhớ chỗ vịt của hệ thú cưng (bộ ráp xóa giùm nếu có)

func YT() -> bool:   # YT: thả vịt được không
	var f := _x("e6")
	if f.is_valid() and bool(f.call()):
		if int(_Cc().vit.n) >= T6:
			_ta("Đàn vịt đã đủ " + str(T6) + " con.")
			return false
		return true
	_ta("Chưa có mặt nước nào trong đất của bạn. Khai hoang ao sen, mở sông hoặc đào ao (Xây dựng › Mặt nước).")
	return false

func VR(t: String) -> bool:   # VR (hệ chuồng làm chủ; chưa gán thì dùng bản chép _VR)
	var f := _x("VR")
	return bool(f.call(t)) if f.is_valid() else _VR(t)

func _VR(t: String) -> bool:   # VR: thả một con giống vô chuồng
	var a = G.g.pens.get(t) if G.g.get("pens") is Dictionary else null
	if a == null or a.size() >= G.vn.gl():
		_ta("Chuồng " + String(QQ[t].name).to_lower() + " đã đủ con.")
		return false
	if not G.lang.pen_built(t):
		_ta("Chưa có " + String(Co[t]).to_lower() + ". Vào Xây dựng › Chuồng trại xây chuồng trước.")
		return false
	if not G.vn.ok(t):
		_ta(String(Co[t]) + " nằm trên đất chưa khai hoang.")
		return false
	a.append({"p": -1})
	_ta("Đã thả một con " + String(QQ[t].name).to_lower() + " vô chuồng. Nhớ cho ăn " + _nm(String(QQ[t].feed)).to_lower() + " nhé.")
	var bv := _x("Bv")
	if bv.is_valid():
		bv.call(t, a.size() - 1, "buy")
	return true

# ------------------------------------------------------------------ bước mỗi khung (gQ), radio (TU), giá trôi (vw)
func step(t: float, offline: bool) -> void:
	vw_mult(t)
	if offline:
		return
	gQ(t)
	TU(t)

func gQ(t: float) -> void:   # gQ (mQ: w_cho_ui.pill đọc trạng thái)
	var a := b2()
	Ui.al = minf(1.0, float(Ui.al) + t * 0.5) if a else maxf(0.0, float(Ui.al) - t * 0.4)
	Ui.sayT = maxf(0.0, float(Ui.sayT) - t)
	if float(Ui.al) > 0 and Ui.pos == null:
		Ui.pos = YB()
	if float(Ui.al) <= 0:
		Ui.pos = null
		panel_close.emit()
	if _chod_t > 0.0:
		_chod_t -= t
		if _chod_t <= 0.0:
			_ta("Chợ nổi sông Vàm đang họp tới 9 giờ sáng! Bốn ghe bán cây giống, trái cây, lúa gạo, đồ bếp. Chạm ghe để nhân vật ra bến mua bán.")
	if a:
		var n: int = G.day()
		if int(G.g.get("chod", -1)) != n and _mode() == "off":
			G.g.chod = n
			_chod_t = 1.5   # setTimeout 1500
			G.mark()
		Ui.sT = float(Ui.sT) - t
		if float(Ui.sT) <= 0:
			Ui.sT = 6.0 + randf() * 5.0   # Nn(6, 11)
			var wr := _x("Wr")
			if Ui.pos != null and (not wr.is_valid() or bool(wr.call(float(Ui.pos[0][0]), float(Ui.pos[0][1]), 0))):
				Ui.sb = int(floor(randf() * 4))
				Ui.say = ["Ai mua sầu riêng hông?", "Gạo mới đây bà con!", "Củi khô nè, củi khô!", "Cây giống tốt đây!", "Khóm ngọt lịm nè!", "Mua giùm con mớ cá!"].pick_random()
				Ui.sayT = 2.4
				# ok(Ui.say): đọc thành tiếng (âm thanh) — bỏ

func mult_init() -> void:   # W3 / nạp bản lưu: g.mult của mọi món = 1, g.mt = 45
	if not (G.g.get("mult") is Dictionary):
		G.g.mult = {}
	for e in G.xo + Rl:
		var v = G.g.mult.get(e)
		if not (v is float or v is int):
			G.g.mult[e] = 1
	if not (G.g.get("mt") is float or G.g.get("mt") is int):
		G.g.mt = 45

func vw_mult(t: float) -> void:   # vw phần g.mt: 45 giây một lần giá chợ huyện trôi ±5%, trong 0,85..1,15
	if not (G.g.get("mt") is float or G.g.get("mt") is int):
		mult_init()
	G.g.mt = float(G.g.mt) - t
	if float(G.g.mt) <= 0:
		if not (G.g.get("mult") is Dictionary):
			mult_init()
		for s in Rl:
			G.g.mult[s] = minf(1.15, maxf(0.85, float(G.g.mult.get(s, 1)) + (randf() - 0.5) * 0.1))
		G.g.mt = 45

func Ox() -> int:   # Ox: buổi hiện tại (4 buổi một ngày)
	return G.day() * 4 + int(floor(_hour() / 6.0))

func N_() -> Dictionary:   # $N: bản tin radio {wx: thời tiết 4 buổi ngày mai, up: 3 món lên giá, dn: 2 món rẻ}
	var t := Ox()
	var a: int = G.day()
	var n := []
	for e in range(1, 9):
		var r := t + e
		if int(floor(r / 4.0)) == a + 1:
			n.append(String(xm[G.nv.Hx(r)]))
	var m: Dictionary = G.g.get("mult", {})
	var o := _stable_sort(Rl.filter(func(c): return m.has(c) and float(m[c]) > 1.12), func(c): return float(m[c]), true).slice(0, 3)
	var l := _stable_sort(Rl.filter(func(c): return m.has(c) and float(m[c]) < 0.88), func(c): return float(m[c]), false).slice(0, 2)
	return {"wx": n, "up": o, "dn": l}

func Eg() -> Dictionary:   # Eg (g.thu)
	var t = G.g.get("thu")
	if not (t is Dictionary):
		t = {"d": -1, "un": null, "rq": null, "rd": -1}
		G.g.thu = t
	return t

func TU(t: float) -> void:   # TU: 6 giờ sáng, 6 giờ chiều radio báo tin (phần nhạc cải lương Kl.t: âm thanh, bỏ)
	zS -= t
	if zS > 0:
		return
	zS = 2.0
	if _cr() or _mode() != "off":
		return
	var a := _hour()
	var n := "s" if a >= 6 and a < 6.5 else "c" if a >= 18 and a < 18.5 else ""
	if n == "":
		return
	var e := str(G.day()) + n
	var r := Eg()
	if str(r.get("rd", -1)) != e:
		r.rd = e
		G.mark()
		var o := N_()
		_ta("Đài phát thanh: " + (("mai trời " + String(o.wx[1]).to_lower() + ". ") if o.wx.size() > 1 else "") + ((_nm(o.up[0]) + " đang lên giá. ") if o.up.size() else "") + "Mở radio (chạm đồng hồ › Radio) để nghe thêm.")

# ------------------------------------------------------------------ giống nhà hàng xóm, lái gia súc (g.gio)
func Km() -> Dictionary:   # Km
	var t = G.g.get("gio")
	if not (t is Dictionary):
		t = {}
		G.g.gio = t
	if int(t.get("day", -999999)) != G.day() or not t.has("day"):
		t.day = G.day()
		t.b = {}
		t.gift = 0
	if not (t.get("b") is Dictionary):
		t.b = {}
	if not (t.get("lv") is float or t.get("lv") is int):
		t.lv = G.lv()
	return t

func G6(t: String, a: int) -> int:   # G6: còn bao nhiêu
	return maxi(0, a - int(Km().b.get(t, 0)))

func bZ(t) -> Array:   # bZ: 2 giống nhà t để dư hôm nay
	return f7(int(t) * 131 + G.day() * 17 + 3, 2)

func Um(t: String) -> bool:   # Um "khóa|giống|số|giá|tối đa" (+ lớp bọc A1: kho đủ chỗ); true = đã mua
	var a := t.split("|")
	var need := 0 if (a.size() > 1 and a[1].begins_with("@")) else (int(a[2]) if a.size() > 2 and int(a[2]) else 1)
	if need > 0 and not G.kho_fit(need):
		return false
	var n := a[0]
	var e := a[1]
	var r := int(a[2])
	var o := int(a[3])
	var l := int(a[4])
	if G6(n, l) < r:
		_ta("Hết hàng rồi.")
		return false
	var c := o * r
	if int(G.g.coins) < c:
		_ta("Cần " + G.fmt_n(c) + " xu.")
		return false
	if e.begins_with("@"):
		var f := e.substr(1)
		if not VR(f):
			return false
		G.g.coins = int(G.g.coins) - c
	else:
		if tf(e):
			_ta("Chưa mở khóa giống này.")
			return false
		G.g.coins = int(G.g.coins) - c
		_add(e, r)
		_ta("Mua " + str(r) + " hạt giống " + String(G.crop(e).name).to_lower() + " (" + G.fmt_n(c) + " xu).")
	Km().b[n] = int(Km().b.get(n, 0)) + r
	G.mark()
	return true

# ------------------------------------------------------------------ g.dd: hái bông ven sông (cT, wx); điểm danh (Sp)
func cT(t: Dictionary) -> bool:   # cT: bụi này hôm nay hái rồi
	var a = G.g.get("dd")
	return a is Dictionary and int(a.get("day", -1)) == G.day() and a.get("p") is Dictionary and bool(a.p.get(t.key, 0))

func wx(t: String) -> bool:   # wx (+ lớp bọc A1: kho còn 1 chỗ): hái bụi khóa t
	if not G.kho_fit(1):
		return false
	var vb := _x("Vb")
	var lt := _x("lT")
	if not vb.is_valid() or not lt.is_valid():
		return false
	var n = null
	for o in vb.call():
		if o.key == t:
			n = o
	if n == null or not bool(lt.call(n)) or cT(n):
		return false
	var e: int = G.day()
	if not (G.g.get("dd") is Dictionary) or int(G.g.dd.get("day", -1)) != e:
		G.g.dd = {"day": e, "p": {}}   # web ghi đè cả g.dd (mất dữ liệu điểm danh Sp) — giữ đúng như web
	G.g.dd.p[t] = 1
	var r := 2 + (1 if randf() < 0.35 else 0)
	var P9: Dictionary = NNP[String(n.get("kd", "dd")) if n.get("kd") else "dd"]
	_add(P9.p, r)
	G.float_text.emit(float(n.gx) + 0.5, float(n.gy) + 0.5, "+" + str(r) + " " + String(P9.n))
	G.vib(8)
	qi("harvest")
	G.mark()
	return true

func Sp() -> Dictionary:   # Sp: g.dd của điểm danh tháng {l7, m, ms, bu}
	var t = G.g.get("dd")
	if not (t is Dictionary):
		t = {"l7": {"n": 0, "last": -1}, "m": {}, "ms": {}, "bu": {}}
		G.g.dd = t
	if not t.get("l7"):
		t.l7 = {"n": 0, "last": -1}
	for a in ["m", "ms", "bu"]:
		if not (t.get(a) is Dictionary):
			t[a] = {}
	return t
