extends RefCounted
# ĐƯỜNG, CHUỒNG (luật, không vẽ thú), LƯU / TẢI: phần luật bản web còn thiếu ở bản Godot, chép 1:1.
#   đường g.road (laid), đình làng (d4: bỏ vật đã dời g.mv), mùa nước nổi g.fl ($q -> YD),
#   chuồng g.pens (VR thả con giống, lY đếm con, rT việc còn làm được (+ lớp bọc kho đầy), I$ việc cho ăn đang xếp,
#     W9 hàng cần giữ (+ lớp bọc tạp hóa / quán cà phê)),
#   thiên tai đánh xuống làng (tnHit + tnPick, tnNeedOf, tnBusy, tnLoEnd, tnRate (+ lớp bọc n_chiu), tnNearRiv, yh,
#     tnScale, tnMul, tnShelter): ruộng hư g.plots[].hu/lc, con vật bệnh g.pens[].s (dịch), nhà gặp nạn g.tn.nan,
#   thưởng trò chơi nhỏ mỗi ngày: Xếp trái g.xtr (xts), Ô ăn quan g.oq (oqs), Đua gà g.dg (dgs).
# Không chép: vẽ đường / lối mòn (trails, segs, polys), chữ ký vẽ lại (psig, dgCK, keyOf, rdFix), biển giá chuồng (utt),
#   chồn và chó Vện (pW), chạm trúng trên canvas (cH), hàng xóm hái trộm / giúp (hK: hệ thăm nhà hàng xóm),
#   hộp vật liệu cũ #barnCard .matbox (JE / g.mbOpen: CSS cuối của web luôn giấu, đã thay bằng thẻ Vật liệu u2vt),
#   bản lưu Ba (đã có game.save_game), q4 (đã có vatnuoi.q4), nvHasPen (đã có nv.has_pen).

const DI := ["ga", "cuu", "bo", "heo", "de"]   # Di
const LP := 4                                   # Lp: chừa lại 4 giống mỗi loại cây
const XT_MAXD := 10                             # Xếp trái: MAXD
const OQ_REW := [20, 50, 120, 250]              # Ô ăn quan: REW
const OQ_MAXD := 5
const DG_REW := [40, 20, 10]                    # Đua gà: REW
const DG_DF := [0.75, 1.0, 1.5]                 # Đua gà: DF
const DG_MAXD := 5

var G
var WR = null              # w_ruong.gd (bộ ráp gán): qs, o0, m0, _hrl, ql, wc, f2, tn_has, tn_waters, W5
var WL = null              # w_lang.gd (bộ ráp gán): tn_s, _r0, r1, ut_houses, ut_add, ut_s, htv
var WC = null              # w_cho.gd (bộ ráp gán): b2, jd, Wx
var WH = null              # w_htx.gd (bộ ráp gán): lf, tap_s, cafe_s
# ext: việc của hệ khác (bộ ráp gán Callable theo tên web)
#   Vo()                     (Vo++: mùa nước nổi đổi thì vẽ lại nền làng)
#   Bv(k, j, kind)           (Bv: hoạt cảnh con vật mới thả vô chuồng)
#   ac_del(u)                (delete ac[u]: bỏ người nhà u đang đi làm trên bản đồ)
#   Ae() -> Dictionary       (Ae: ghe thương hồ {st, offers})
#   hr() -> Dictionary       (hr: xe chè dạo {st, offer})
var ext := {}

var TNK := {}              # TNK: loại thiên tai {n, w, d}
var TNNEED := {}           # TNNEED: đồ giúp mỗi nhà gặp nạn

var mu = null              # mu: qs() lần trước (null = chưa xét)
var uT := 0.0              # uT: YD mỗi 1 giây

func _init(game) -> void:
	G = game
	var a = G._j("thien_tai/loai")
	TNK = a if a is Dictionary else {}
	var b = G._j("thien_tai/do_giup")
	TNNEED = b if b is Dictionary else {}

# ------------------------------------------------------------------ tiện ích
func _x(k: String) -> Callable:
	var c = ext.get(k)
	return c if c is Callable and (c as Callable).is_valid() else Callable()

static func _num(v) -> bool:   # typeof x == "number"
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT

static func _n(v) -> float:   # x || 0
	return float(v) if _num(v) else 0.0

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

static func _rnd(x: float) -> int:   # Math.round
	return int(floor(x + 0.5))

func _ta(s: String) -> void:   # ta / pn
	G.toast.emit(s)

func _ba() -> void:   # Ba / kn
	G.mark()

func _later(s: float, f: Callable) -> void:   # setTimeout
	G.get_tree().create_timer(s).timeout.connect(f)

func _gr(ms) -> void:   # gr: mảng [rung, nghỉ, rung, ...] như navigator.vibrate
	if ms is Array:
		var at := 0.0
		for i in ms.size():
			if i % 2 == 0:
				var v := int(ms[i])
				if at <= 0.0:
					G.vib(v)
				else:
					_later(at / 1000.0, func() -> void: G.vib(v))
			at += float(ms[i])
	else:
		G.vib(int(ms))

func _vr() -> int:   # vr
	return G.day()

func _jr() -> int:   # jr: fr().lv
	return G.lv()

func _qr(k: String) -> Dictionary:   # qr[k]
	return G.vn.Q.get(k, {}) if G.vn != null else {}

func _pens() -> Dictionary:   # g.pens
	var p = G.g.get("pens")
	return p if p is Dictionary else {}

func _barn(t: String) -> int:   # g.barn[t] || 0
	return int(_n(G.g.barn.get(t, 0)))

func _okeys(d: Dictionary) -> Array:   # Object.keys
	if WL != null:
		return WL._okeys(d)
	var a := []
	for k in d:
		a.append(str(k))
	return a

# ------------------------------------------------------------------ đường, đình
func laid(x: int, y: int) -> bool:   # laid
	var R = G.g.get("road")
	return R is Dictionary and _tr(R.get(str(x) + "," + str(y)))

func d4() -> Variant:   # d4: đình làng (món đặt dinh / dinh2, hoặc vật cảnh đình có sẵn chưa dời)
	if WR != null:
		WR.m0()
		for t in WR._hrl():
			if RegEx.create_from_string("^dinh2?$").search(String(t.id)) != null:
				return t
	if G.lang != null:
		for a in G.lang.SO:
			if String(a.id).begins_with("dinh") and not (String(a.sk) != "" and G.g.get("mv") is Dictionary and _tr(G.g.mv.get(a.sk))):
				return a
	return null

# ------------------------------------------------------------------ mùa nước nổi ($q mỗi khung: YD mỗi 1 giây)
func step(t: float, offline: bool) -> void:   # $q (phần eV(t) thuộc hệ khác)
	if offline:
		return
	tn_tick(t)
	uT -= t
	if uT <= 0.0:
		uT = 1.0
		YD()

func YD() -> void:   # YD
	var t: bool = WR.qs() if WR != null else false
	if mu != null and mu != t:
		var vo := _x("Vo")
		if vo.is_valid():
			vo.call()
	mu = t
	if not t or not (WR != null and int(WR.o0()) > 0):
		return
	var a := _vr()
	if not (_num(G.g.get("fl")) and int(G.g.fl) == a):
		G.g.fl = a
		_later(1.2, func(): _ta("Nước nổi về sông Vàm! Phù sa bồi: cây lớn nhanh hơn 4%. Có cá linh để câu, ven sông có điên điển nở vàng, bông súng ma, rau kèo nèo để hái."))
		G.save_game()   # Ba

# ------------------------------------------------------------------ chuồng
func VR(t: String) -> bool:   # VR: thả một con giống vô chuồng
	var a = _pens().get(t)
	var q := _qr(t)
	if not (a is Array) or a.size() >= G.vn.gl():
		_ta("Chuồng " + String(q.get("name", t)).to_lower() + " đã đủ con.")
		return false
	if not G.lang.pen_built(t):   # n1
		_ta("Chưa có " + String(G.lang.CO.get(t, "")).to_lower() + ". Vào Xây dựng › Chuồng trại xây chuồng trước.")
		return false
	if not G.vn.ok(t):   # _c
		_ta(String(G.lang.CO.get(t, "")) + " nằm trên đất chưa khai hoang.")
		return false
	a.append({"p": -1})
	_ta("Đã thả một con " + String(q.get("name", t)).to_lower() + " vô chuồng. Nhớ cho ăn " + String(G.item(String(q.get("feed", ""))).get("name", "")).to_lower() + " nhé.")
	var bv := _x("Bv")
	if bv.is_valid():
		bv.call(t, a.size() - 1, "buy")
	return true

func lY() -> int:   # lY: tổng số con trong các chuồng
	var n := 0
	for k in DI:
		var L = _pens().get(k)
		n += L.size() if L is Array else 0
	return n

func rT(t) -> bool:   # rT (+ lớp bọc: hái trái / thu chuồng mà kho hết chỗ thì thôi)
	if _tr(t) and (t.get("t") == "th" or t.get("t") == "c") and G.kho_room() < 1:
		return false
	return _rT0(t)

func _rT0(t: Dictionary) -> bool:   # rT gốc
	if t.get("t") == "th":
		var a = WR.ql(int(t.i)) if WR != null else null
		return a != null and WR.wc(a)
	if t.get("t") == "tw":
		var n = WR.ql(int(t.i)) if WR != null else null
		return n != null and not WR.wc(n) and float(n.fw) < WR.f2() * 0.6
	var L = _pens().get(String(t.get("k", "")))
	var j := int(_n(t.get("j")))
	var e = L[j] if L is Array and j >= 0 and j < L.size() else null
	if not _tr(e):
		return false
	var q := _qr(String(t.k))
	if t.get("t") == "c":
		return float(e.p) >= float(q.time)
	var r := String(q.feed)
	return float(e.p) < 0.0 and _barn(r) > (LP if G.D.crops.has(r) else 0)

func I_(t: String) -> int:   # I$: số việc cho ăn (món t) đang xếp chờ nhân vật làm
	var a := 0
	var F = G.lang.F if G.lang != null else null
	if F == null:
		return 0
	var L: Array = ([F.cur] if F.cur != null else []) + F.q
	var re := RegEx.create_from_string("^animal:([^:]*):([^:]*)")
	for n in L:
		if n.get("kind") == "animal":
			var e := re.search(String(n.get("key", "")))
			if e != null:
				var P = _pens().get(e.get_string(1))
				var j := int(e.get_string(2).to_float())
				var r = P[j] if P is Array and j >= 0 and j < P.size() else null
				var q := _qr(e.get_string(1))
				if _tr(r) and float(r.p) < 0.0 and not q.is_empty() and String(q.feed) == t:
					a += 1
	return a

func W9() -> Dictionary:   # W9 (+ lớp bọc: đơn tạp hóa g.tap.o, quán cà phê g.cafe.c): hàng cần giữ lại khi bán
	var t := {}
	var add := func(r, o) -> void:
		if _tr(r) and _num(o) and float(o) > 0:
			t[String(r)] = int(_n(t.get(String(r), 0))) + int(o)
	for r in G.g.get("orders", []):
		if r is Dictionary and r.get("items") is Array:
			for o in r.items:
				add.call(o[0], o[1])
	var n = WL._r0() if WL != null else null
	if n is Dictionary and n.get("fam") is Dictionary:
		for r in _okeys(n.fam):
			var o = n.fam[r].get("req")
			if _tr(o):
				var it: Array = o.it if o.get("it") is Array and o.it.size() else [[o.get("id"), o.get("q")]]   # _rIt
				for x in it:
					add.call(x[0], x[1])
			var l = n.fam[r].get("pq")
			if _tr(l) and l.get("it") is Array:
				for c in l.it:
					add.call(c[0], c[1])
	# Ws(): bản web cuối cùng đặt Ws = function(){return []} -> không cộng gì
	if WC != null and WC.b2():
		var D: Array = WC.jd()
		for o in D.size():
			var R = D[o]
			if R is Array:
				for c in R.size():
					var l = R[c]
					if l.get("t") == "mua" and l.get("k") == "item" and not WC.Wx(o, c):
						add.call(l.id, l.q)
	var fae := _x("Ae")
	if fae.is_valid():
		var Ae = fae.call()
		if Ae is Dictionary and _tr(Ae.get("offers")) and _n(Ae.get("st")) >= 1:
			for r in Ae.offers:
				if not _tr(r.get("done")):
					add.call(r.id, r.q)
	var fhr := _x("hr")
	if fhr.is_valid():
		var hr = fhr.call()
		if hr is Dictionary and _tr(hr.get("offer")) and not _tr(hr.offer.get("done")) and _n(hr.get("st")) >= 1:
			add.call(hr.offer.id, hr.offer.q)
	for r in G.xo:
		if G.D.crops.has(r):
			add.call(r, 4)
	for r in DI:
		if G.lang != null and G.lang.pen_built(r) and _pens().get(r) is Array and _pens()[r].size():
			add.call(_qr(r).get("feed"), _pens()[r].size())
	# lớp bọc: A(At, Pt) cộng thẳng, không xét > 0
	if WH != null:
		for At in WH.tap_s().o:
			for Pt in At.items:
				t[String(Pt[0])] = int(_n(t.get(String(Pt[0]), 0))) + int(Pt[1])
		for At in WH.cafe_s().c:
			for Pt in At.items:
				t[String(Pt[0])] = int(_n(t.get(String(Pt[0]), 0))) + int(Pt[1])
	return t

# ------------------------------------------------------------------ thiên tai đánh xuống làng (tnTick gọi)
func tn_mul() -> float:   # tnMul
	return 1.0 + _jr() / 50.0

func tn_scale(q: Dictionary) -> Dictionary:   # tnScale
	var out := {}
	for k in q:
		out[k] = _rnd(float(q[k]) * tn_mul() / 10.0) * 10 if k == "xu" else q[k]
	return out

func tn_shelter() -> bool:   # tnShelter
	return WR.tn_has("dinh") or WR.tn_has("truong")

func yh(t: int, a: int) -> bool:   # yh: ô kênh / sông thuộc khúc sông Vàm
	var n: String = G.lang.fo(t, a)
	return n != "" and WR.W5.has(n) and _tr(WR.W5[n]) and G.lang.il(t, a) == "canal"

func tn_near_riv(gx: float, gy: float, rad: int) -> bool:   # tnNearRiv
	for dx in range(-rad, rad + 1):
		for dy in range(-rad, rad + 1):
			if yh(_rnd(gx + dx), _rnd(gy + dy)):
				return true
	return false

func tn_rate(kind: String, cell: Dictionary, wat: Array, pa: bool) -> float:   # tnRate (+ lớp bọc: * (1 - htv("n_chiu")))
	var r := _tn_rate0(kind, cell, wat, pa)
	return r * (1.0 - WL.htv("n_chiu"))

func _tn_rate0(kind: String, cell: Dictionary, wat: Array, pa: bool) -> float:   # tnRate gốc
	var rate := 0.0
	if kind == "bao":
		rate = 0.3
	elif kind == "lu":
		rate = 0.6 if tn_near_riv(float(cell.gx), float(cell.gy), 5) else 0.15
		if WR.tn_has("causong"):
			rate /= 2.0
	elif kind == "han":
		for r in wat:
			if absf(float(r.gx) - float(cell.gx)) <= 4 and absf(float(r.gy) - float(cell.gy)) <= 4:
				return 0.0
		rate = 0.35
	return rate / 4.0 if pa else rate

func tn_need_of(kind: String) -> Dictionary:   # tnNeedOf
	var q := tn_scale(TNNEED.get(kind, {}))
	if kind == "lu" and WR.tn_has("ben"):
		for k in q:
			q[k] = int(ceil(float(q[k]) / 2.0))
	if kind == "dich" and WR.tn_has("tramyt"):
		q.xu = _rnd(float(q.xu) / 20.0) * 10
	if WR.tn_has("chua"):
		for k in q:
			q[k] = _rnd(float(q[k]) * 0.07) * 10 if k == "xu" else int(ceil(float(q[k]) * 0.7))
	return q

func tn_busy(uu: String) -> bool:   # tnBusy
	var nn = WL.tn_s().nan.get(uu)
	if not _tr(nn):
		return false
	return not ((nn.k == "bao" or nn.k == "lu" or nn.k == "chay") and tn_shelter())

func tn_pick(kind: String, cnt: int) -> Array:   # tnPick
	var o: Dictionary = WL.tn_s()
	var pool := []
	for uu in WL.ut_houses():
		if _tr(o.nan.get(uu)):
			continue
		var hh = WL.r1(uu)
		var id := String(hh.r.id)
		if id.ends_with("2"):
			id = id.substr(0, id.length() - 1)
		var wt := 1.0
		if kind == "bao":
			wt = 3.0 if (id == "hut" or id == "hutnho") else (2.0 if id == "bagian" else 1.0)
		elif kind == "lu":
			wt = 4.0 if tn_near_riv(float(hh.o.gx) + float(hh.o.fw) / 2.0, float(hh.o.gy) + float(hh.o.fd) / 2.0, 6) else 0.5
		elif kind == "chay":
			wt = 0.5 if id == "house" else 2.0
		pool.append([uu, wt])
	var out := []
	while out.size() < cnt and pool.size():
		var tot := 0.0
		for q in pool:
			tot += float(q[1])
		var rr := randf() * tot
		var x := 0
		while x < pool.size() - 1:
			rr -= float(pool[x][1])
			if rr <= 0:
				break
			x += 1
		out.append(pool[x][0])
		pool.remove_at(x)
	return out

func tn_lo_end() -> void:   # tnLoEnd
	var o: Dictionary = WL.tn_s()
	var lo = o.get("lo")
	if not _tr(lo):
		return
	var nm := String(TNK[String(lo.k)].n).to_lower()
	if _n(lo.hp) * 2 >= lo.u.size():
		WL.ut_add(15, "Lo cho bà con sau " + nm)
	elif not _tr(lo.hp):
		WL.ut_add(-15, "Bỏ mặc bà con sau " + nm)
	o.erase("lo")

func tn_hit(ev: Dictionary, late: bool) -> void:   # tnHit
	var o: Dictionary = WL.tn_s()
	var pr: Dictionary = o.p if (_num(o.p.get("d")) and _num(ev.get("d")) and int(o.p.d) == int(ev.d)) else {}
	var kind := String(ev.k)
	var rep := {"k": kind, "d": ev.d, "cay": 0, "con": 0, "nha": [], "pa": _tr(pr.get("a")), "pb": _tr(pr.get("b"))}
	var F: Dictionary = WL._r0().fam
	var day := _vr()
	if kind == "bao" or kind == "lu" or kind == "han":
		var wat: Array = WR.tn_waters()
		for ix in G.B0:
			var pl = G.g.plots[ix] if ix < G.g.plots.size() else null
			if not _tr(pl) or not _tr(pl.get("u")) or not _tr(pl.get("c")):
				continue
			if randf() < tn_rate(kind, G.cells[ix], wat, _tr(pr.get("a"))):
				pl.lc = pl.c
				pl.c = null
				pl.g = 0
				pl.w = 0
				pl.b = 0
				pl.oc = 0
				pl.hu = day
				rep.cay += 1
	if kind == "dich":
		var P := _pens()
		for kk in _okeys(P):
			var L = P[kk]
			if not (L is Array):
				continue
			for an in L:
				if _tr(an) and not _tr(an.get("s")) and not _tr(an.get("b")) and randf() < (0.1 if _tr(pr.get("a")) else 0.4) * (1.0 - WL.htv("n_khoe")):
					an.s = 1
					rep.con += 1
	var pb := _tr(pr.get("b"))
	var cnt := 0
	if kind == "bao":
		cnt = 1 + int(floor(randf() * 3)) - (2 if pb else 0)
	elif kind == "lu":
		cnt = 1 + int(floor(randf() * 2)) - (1 if pb else 0)
	elif kind == "han":
		cnt = 1 + int(floor(randf() * 2)) - (1 if pb else 0) - (1 if WR.tn_has("well") else 0)
	elif kind == "dich":
		cnt = 2 + int(floor(randf() * 2)) - (1 if pb else 0) - (1 if WR.tn_has("tramyt") else 0)
	else:
		cnt = 0 if pb else 1
	for uu in tn_pick(kind, maxi(0, cnt)):
		var ff = F[uu]
		o.nan[uu] = {"k": kind, "d": ev.d, "need": tn_need_of(kind)}
		rep.nha.append(ff.n)
		if tn_busy(uu) and _tr(ff.get("job")):
			ff.job = null
			var acd := _x("ac_del")
			if acd.is_valid():
				acd.call(uu)
	tn_lo_end()
	if _n(WL.ut_s().get("c")) >= 1 and rep.nha.size():
		var us := []
		for uu in _okeys(o.nan):
			if _num(o.nan[uu].get("d")) and int(o.nan[uu].d) == int(ev.d):
				us.append(uu)
		o.lo = {"d": ev.d, "k": kind, "u": us, "hp": 0}
	o.log.push_front(rep)
	o.log = o.log.slice(0, 12)
	var nm := String(TNK[kind].n).to_lower()
	var parts := []
	if rep.cay:
		parts.append("hư " + str(rep.cay) + " ô ruộng")
	if rep.con:
		parts.append(str(rep.con) + " con vật bệnh")
	if rep.nha.size():
		parts.append(str(rep.nha.size()) + " nhà gặp nạn")
	var msg := ("Mấy bữa trước làng bị " if late else "Đêm qua làng bị ") + nm + ": " + ", ".join(PackedStringArray(parts))
	var bad: bool = rep.cay or rep.con or rep.nha.size()
	var txt := (msg if bad else "Đêm qua " + nm + " mà nhờ phòng kỹ nên làng bình yên") + ". Coi ở Sổ làng › Thiên tai, hoạn nạn."
	var tell := func() -> void:
		_ta(txt)
		_gr([20, 60, 20])   # Jt("err"): âm thanh, không chép
	_later(3.0 if late else 1.5, tell)
	_ba()   # kn

# ------------------------------------------------------------------ thiên tai: phòng trước, giúp nhà gặp nạn, qua ngày
# việc phòng: [giữ ruộng, giữ làng] = [tên, tác dụng, đồ] (cháy nhà chỉ có giữ làng)
const TNPREP := {
	"bao": [["Cắm cọc chằng cây trồng", "Cây ngoài ruộng hư ít hẳn.", {"cui": 20}], ["Chằng chống nhà cho bà con", "Bớt 2 nhà bị sập.", {"xu": 400, "cui": 15}]],
	"lu": [["Đắp bờ bao quanh ruộng", "Ruộng ngập ít hẳn.", {"xu": 600, "cui": 10}], ["Kê cao đồ đạc giúp bà con", "Bớt 1 nhà bị ngập.", {"xu": 300}]],
	"han": [["Trữ nước vô lu, khạp", "Ruộng khô chết ít hẳn.", {"xu": 400}], ["Đào giếng tạm cho xóm", "Bớt 1 nhà mất mùa.", {"xu": 500, "cui": 10}]],
	"dich": [["Rắc vôi chuồng trại", "Vật nuôi ít bệnh hẳn.", {"xu": 300}], ["Phát thuốc phòng cho bà con", "Bớt 1 nhà đau ốm.", {"xu": 600}]],
	"chay": [null, ["Đặt lu nước, cử người canh lửa", "Lửa dập kịp, không nhà nào cháy.", {"xu": 300}]]}
const TNRES := {"xu": "xu", "cui": "củi", "gach": "gạch", "lua": "giạ lúa", "chieu": "chiếu", "gio_lb": "giỏ", "nhang": "nhang"}
var TNT := 0.0

func _tn_hv(k: String) -> int:
	if k == "xu":
		return int(_n(G.g.coins))
	if k == "gach":
		return int(_n(WL._r0().get("gach")))
	return int(_n(G.g.barn.get(k, 0)))

func tn_have(q: Dictionary) -> bool:   # tnHave
	for k in q:
		if _tn_hv(k) < int(q[k]):
			return false
	return true

func tn_miss(q: Dictionary) -> String:   # tnMiss
	var ms := []
	for k in q:
		var hv := _tn_hv(k)
		if hv < int(q[k]):
			ms.append(WL._sa(int(q[k]) - hv) + " " + String(TNRES.get(k, k)))
	return ", ".join(PackedStringArray(ms))

func tn_take(q: Dictionary) -> void:   # tnTake
	for k in q:
		if k == "xu":
			G.g.coins = _n(G.g.coins) - int(q[k])
		elif k == "gach":
			var lg: Dictionary = WL._r0()
			lg.gach = int(_n(lg.get("gach"))) - int(q[k])
		else:
			G.g.barn[k] = int(_n(G.g.barn.get(k, 0))) - int(q[k])

func tn_help(uu) -> void:   # tnHelp: giúp nhà gặp nạn
	var o: Dictionary = WL.tn_s()
	var k := str(uu)
	var nn = o.nan.get(k)
	var ff = WL._r0().fam.get(k)
	if not _tr(nn) or ff == null or _tr(nn.get("x")):
		return
	if not tn_have(nn.need):
		_ta("Còn thiếu " + tn_miss(nn.need) + ".")
		return
	tn_take(nn.need)
	o.nan.erase(k)
	if _tr(o.get("lo")) and o.lo.u.map(func(x): return str(x)).has(k):
		o.lo.hp = int(_n(o.lo.hp)) + 1
	WL.than_add(ff, 60)
	WL.ut_add(8, "Giúp nhà " + String(ff.n) + " qua cơn " + String(WL.TNNAN.get(nn.k, "")).to_lower())
	_ta("Nhà " + String(ff.n) + " cảm ơn rối rít, mai mốt có gì cứ kêu một tiếng.")
	_ba()

func tn_prep(which: String) -> void:   # tnPrep: việc phòng hôm báo tin
	var ev = WL.tn_on(_vr() + 1)
	var o: Dictionary = WL.tn_s()
	if ev == null or not WL.tn_ok():
		return
	var P = TNPREP[ev.k][0 if which == "a" else 1]
	if P == null:
		return
	if not (_num(o.p.get("d")) and int(o.p.d) == int(ev.d)):
		o.p = {"d": ev.d}
	if _tr(o.p.get(which)):
		return
	var q := tn_scale(P[2])
	if not tn_have(q):
		_ta("Còn thiếu " + tn_miss(q) + ".")
		return
	tn_take(q)
	o.p[which] = 1
	if which == "b":
		WL.ut_add(3, "Phòng " + String(TNK[ev.k].n).to_lower() + " cho xóm")
	_ta(String(P[0]) + " xong. " + String(P[1]))
	_ba()

func tn_days(day: int) -> bool:   # tnDays: hết hạn giúp, tự gượng dậy, chấm việc lo cho bà con
	var o: Dictionary = WL.tn_s()
	var F: Dictionary = WL._r0().fam
	var ch := false
	for uu in o.nan.keys():
		var nn: Dictionary = o.nan[uu]
		var ff = F.get(uu)
		if ff == null or WL.r1(uu) == null:
			o.nan.erase(uu)
			ch = true
			continue
		if not _tr(nn.get("x")) and day >= int(nn.d) + 3:
			nn.x = 1
			WL.than_add(ff, -20)
			ch = true
		if day >= int(nn.d) + maxi(1, (3 if WR.tn_has("chua") else 5) - int(WL.htv("l_xa"))):
			o.nan.erase(uu)
			ch = true
	if _tr(o.get("lo")) and day >= int(o.lo.d) + 3:
		tn_lo_end()
		ch = true
	return ch

func tn_tick(dt: float) -> void:   # tnTick (2 giây một lần)
	TNT -= dt
	if TNT > 0.0:
		return
	TNT = 2.0
	if WL == null:
		return
	var o: Dictionary = WL.tn_s()
	var day := _vr()
	var ch := false
	if day > int(o.last):
		for x in range(maxi(int(o.last) + 1, day - 2), day + 1):
			var ev = WL.tn_on(x)
			if ev != null and WL.tn_ok():
				tn_hit(ev, x < day)
		o.last = day
		ch = true
	if tn_days(day):
		ch = true
	for ix in G.B0:
		var pl = G.g.plots[ix] if ix < G.g.plots.size() else null
		if _tr(pl) and _tr(pl.get("hu")) and (_tr(pl.get("c")) or day - int(pl.hu) > 2):
			pl.erase("hu")
			ch = true
	if ch:
		_ba()

func tn_red() -> int:   # tnRed
	if not WL.tn_ok():
		return 0
	var o: Dictionary = WL.tn_s()
	var ev = WL.tn_on(_vr() + 1)
	if ev != null and (not (_num(o.p.get("d")) and int(o.p.d) == int(ev.d)) or not _tr(o.p.get("b")) or (TNPREP[ev.k][0] != null and not _tr(o.p.get("a")))):
		return 1
	for uu in o.nan:
		if not _tr(o.nan[uu].get("x")) and tn_have(o.nan[uu].need):
			return 1
	return 0

# ------------------------------------------------------------------ thưởng trò chơi nhỏ (lúc trò chơi báo "end")
static func _today() -> String:   # day(): "năm-tháng-ngày" theo giờ máy
	var d := Time.get_datetime_dict_from_system()
	return str(d.year) + "-" + str(d.month) + "-" + str(d.day)

func xts() -> Dictionary:   # xts: g.xtr (Xếp trái miệt vườn)
	var c = G.g.get("xtr")
	if not (c is Dictionary):
		c = {"d": _today(), "n": 0, "lv": {}}
		G.g.xtr = c
	if not _tr(c.get("lv")):
		c.lv = {}
	if str(c.get("d")) != _today():
		c.d = _today()
		c.n = 0
	return c

func xt_end(level: int, stars: int) -> Dictionary:   # message xt "end" -> {xu, left, max} gửi lại trò chơi ("reward")
	var c := xts()
	var lv := str(level)
	var st := maxi(1, mini(3, stars))
	var xu := 0
	if not _tr(c.lv.get(lv)):
		c.lv[lv] = st
		xu = 30 + 20 * st
	elif int(c.n) < XT_MAXD:
		c.n = int(c.n) + 1
		xu = 10 * st
		if st > int(c.lv[lv]):
			c.lv[lv] = st
	if xu:
		G.g.coins = int(G.g.coins) + xu
		G.save_game()   # Ba
	return {"xu": xu, "left": XT_MAXD - int(c.n), "max": XT_MAXD}

func oqs() -> Dictionary:   # oqs: g.oq (Ô ăn quan)
	var c = G.g.get("oq")
	if not (c is Dictionary) or str(c.get("d")) != _today():
		c = {"d": _today(), "n": 0}
		G.g.oq = c
	return c

func oq_end(mode: String, winner, level: int) -> Dictionary:   # message oq "end" -> {xu, left, max}
	var xu := 0
	var c := oqs()
	if mode == "ai" and _num(winner) and int(winner) == 0 and int(c.n) < OQ_MAXD:
		xu = int(OQ_REW[level]) if level >= 0 and level < OQ_REW.size() else 20
		c.n = int(c.n) + 1
		G.g.coins = int(G.g.coins) + xu
		G.save_game()   # Ba
	return {"xu": xu, "left": OQ_MAXD - int(c.n), "max": OQ_MAXD}

func dgs() -> Dictionary:   # dgs: g.dg (Đua gà)
	var c = G.g.get("dg")
	if not (c is Dictionary) or str(c.get("d")) != _today():
		c = {"d": _today(), "n": 0}
		G.g.dg = c
	return c

func dg_end(mode: String, place: int, diff: int) -> Dictionary:   # message dg "end" -> {xu, left, max}
	var xu := 0
	var c := dgs()
	if int(c.n) < DG_MAXD:
		if mode == "tt":
			xu = 15
		else:
			var rw := int(DG_REW[place - 1]) if place - 1 >= 0 and place - 1 < DG_REW.size() else 0
			var df := float(DG_DF[diff]) if diff >= 0 and diff < DG_DF.size() else 1.0
			xu = _rnd(rw * df)
		if xu > 0:
			c.n = int(c.n) + 1
			G.g.coins = int(G.g.coins) + xu
			G.save_game()   # Ba
	return {"xu": xu, "left": DG_MAXD - int(c.n), "max": DG_MAXD}
