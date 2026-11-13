extends RefCounted
# KHO, BÁN HÀNG: phần luật bản web còn thiếu ở bản Godot.
#  - "Chợ có lý do": giá có lý do (mkWhy/mkEv: mùa, thiên tai, lễ, tin chợ), tin chợ mỗi ngày (mkTinMoi),
#    ghi giá mỗi ngày (mkGhi, S.mk.h 7 ngày), số liệu biểu đồ 7 ngày trong khung chi tiết của Kho (mkChart),
#    phần "sang ngày" của bước 5 giây (ui id 'mk'; phần hồi sức chợ đã có ở game._mk_step).
#  - Bán hết một món (iG), số cần giữ lại cho đơn (NF) và câu nhắc giữ lại trong khung chi tiết (eG #khDet).
#  - W8: lớp bọc "kho đầy thì bỏ bớt phần vượt" cho các việc nhặt được đồ.
# Các hàm của hệ khác mà bản web gọi có kiểm "typeof x=='function'": bản Godot nhận qua ext (Callable), chưa gán thì bỏ qua như web.

var G
# ext: hàm của hệ khác (bộ ráp gán). Thiếu thì làm như web khi hàm chưa có.
#   tnOk() -> bool                 (thiên tai: jr() >= TNLV)
#   tnOn(day: int) -> Dictionary   (thiên tai rơi đúng ngày: {k, d, ...}; không có -> {} hoặc null)
#   Jb() -> Dictionary             (lễ gần nhất trong 29 ngày: {f: {n, cand}, d, k}; không có -> {} hoặc null)
#   clgAdd(k: String, t: String)   (Chuyện làng)
#   Cr() -> bool                   (đang xem làng bạn: Cr != null)
var ext := {}

var Rl: Array = []          # Rl = xo.concat(to, Wf, Mv) + mọi món ae() còn lại (bản web đẩy thêm lúc dựng bảng Kho)
var Wf: Array = []          # cá
var Mv: Array = []          # trái cây
var UA: Dictionary = {}     # nhóm hàng
var MKTN: Dictionary = {}   # thiên tai -> [[nhóm, hệ số]]
var MKTIN: Array = []       # mẫu tin chợ [câu, hệ số]
var TNK: Dictionary = {}    # loại thiên tai {n, w, d}
var MKEC := {"d": -1, "t": 0.0, "v": {}}
var MKT := 0.0

func _init(game) -> void:
	G = game
	Wf = G._j("cau_ca/ds_ca")
	Mv = G._j("nong_trai/ds_trai_cay")
	UA = G._j("nong_trai/nhom_vat_pham")
	MKTN = G._j("cho/gia_khi_thien_tai")
	MKTIN = G._j("cho/tin_cho")
	TNK = G._j("thien_tai/loai")
	var to: Array = G._j("che_bien/thu_tu_hang")
	var seen := {}
	for L in [G.xo, to, Wf, Mv, G.D.crops.keys(), G.D.items.keys()]:
		for t in L:
			var k := String(t)
			if not seen.has(k) and not G.item(k).is_empty():
				seen[k] = 1
				Rl.append(k)

func _x(k: String) -> Callable:
	var c = ext.get(k)
	return c if c is Callable and (c as Callable).is_valid() else Callable()

# ------------------------------------------------------------------ mkS (thêm khóa tin mà game.mk() chưa có)
func mkS() -> Dictionary:   # mkS
	var o: Dictionary = G.mk()
	if not (o.get("tin") is Array):
		o.tin = []
	return o

func mkSat(t: String) -> float:   # mkSat
	return float(mkS().sat.get(t, 0.0))

# ------------------------------------------------------------------ giá có lý do
func mkNhom(t: String, k: String) -> bool:   # mkNhom
	if k == "cui" or k == "lua" or k == "nep":
		return t == k
	if k == "ca":
		return Wf.has(t)
	return UA.has(k) and UA[k] is Dictionary and bool(UA[k].get(t, false))

func mkWhy(t: String) -> Array:   # mkWhy -> [hệ số, các lý do]
	var day: int = G.day()
	var m := 1.0
	var w: Array = []
	if G.D.crops.has(t) and not G.crop(t).get("hyb", false):
		var sea: int = G.season()   # tnSea(day): ngày đang xét là hôm nay
		var q = G.D.mua[sea] if sea >= 0 and sea < G.D.mua.size() else []
		var dm: bool = q is Array and q.has(t)
		m *= 0.9 if dm else 1.1
		w.append("đúng mùa, rẻ" if dm else "trái mùa, đắt")
	var ev = null
	var f_on := _x("tnOn")
	var f_ok := _x("tnOk")
	if f_on.is_valid() and f_ok.is_valid() and bool(f_ok.call()):
		ev = f_on.call(day)
		if not (ev is Dictionary) or ev.is_empty():
			ev = f_on.call(day + 1)
	if ev is Dictionary and not ev.is_empty() and MKTN.has(String(ev.get("k", ""))):
		var ek := String(ev.k)
		for z in MKTN[ek]:
			if mkNhom(t, String(z[0])):
				m *= float(z[1])
				w.append(String(TNK.get(ek, {}).get("n", ek)).to_lower() + ", giá lên")
	var f_jb := _x("Jb")
	var fe = f_jb.call() if f_jb.is_valid() else null
	if fe is Dictionary and not fe.is_empty() and int(fe.get("k", 99)) <= 3 and fe.get("f", {}).get("cand", []).has(t):
		m *= 1.2
		w.append("sắp " + String(fe.f.get("n", "")).to_lower())
	for x in mkS().tin:
		if int(x.get("d", -1)) == day and String(x.get("id", "")) == t:
			m *= float(x.m)
			w.append("thương lái thu mua" if float(x.m) > 1.0 else "hàng về đông")
	return [m, w]

func mkEv(t: String) -> float:   # mkEv: nhớ trong ngày, tối đa 60 s
	var d: int = G.day()
	var now: float = G._now_ms()
	if int(MKEC.d) != d or now - float(MKEC.get("t", 0.0)) > 60000.0:
		MKEC = {"d": d, "t": now, "v": {}}
	if not MKEC.v.has(t):
		MKEC.v[t] = float(mkWhy(t)[0])
	return float(MKEC.v[t])

func ngKho(t: String) -> int:   # $i bọc chợ có lý do: round($i gốc × mkEv)
	# $i gốc = game.price hiện nay. Khi bộ ráp cho game.price() gọi hàm này, đổi tên thân cũ thành price0() để khỏi gọi vòng.
	var p0: int = int(G.call("price0", t)) if G.has_method("price0") else int(G.price(t))
	return int(round(p0 * mkEv(t)))

func mkRel(t: String) -> float:   # mkRel: giá ngày × lý do × bán dồn
	return float(G.g.get("mult", {}).get(t, 1.0)) * mkEv(t) * G.mk_f(t, mkSat(t))

# ------------------------------------------------------------------ tin chợ cho ngày mai
func _seen() -> Dictionary:   # typeof Tc=='function' && Tc().seen || {}
	var b = G.g.get("book")
	if b is Dictionary and b.get("seen") is Dictionary:
		return b.seen
	return {}

func mkTinMoi(day: int) -> void:   # mkTinMoi
	var o := mkS()
	var seen := _seen()
	var L: Array = []
	for t in seen.keys():
		var a: Dictionary = G.item(String(t))
		if not a.is_empty() and float(a.get("sell", 0)) > 0.0 and Rl.has(String(t)):
			L.append(String(t))
	if L.size() < 4:
		L = []
		for t in G.xo:
			if G.D.crops.has(t) and int(G.crop(t).get("lv", 1)) <= G.lv():
				L.append(t)
	if L.is_empty():
		return
	o.tin = o.tin.filter(func(x): return int(x.get("d", 0)) >= day)
	var n := 1 + (1 if randf() < 0.5 else 0)
	var used := {}
	var clg := _x("clgAdd")
	for i in n:
		var t: String = L[randi() % L.size()]   # t0
		if used.has(t):
			continue
		used[t] = 1
		var x: Array = MKTIN[randi() % MKTIN.size()]
		o.tin.append({"d": day + 1, "id": t, "m": float(x[1])})
		if clg.is_valid():
			clg.call("buon", "Tin chợ: " + String(x[0]).replace("{m}", G.item_name(t).to_lower()))

# ------------------------------------------------------------------ ghi giá mỗi ngày
func mkGhi(day: int) -> void:   # mkGhi
	var o := mkS()
	var seen := _seen()
	for t in Rl:
		var it: Dictionary = G.item(t)
		if it.is_empty() or not (float(it.get("sell", 0)) > 0.0):
			continue
		if not seen.has(t) and not (int(G.g.barn.get(t, 0)) > 0) and not o.h.has(t):
			continue
		if not (o.h.get(t) is Array):
			o.h[t] = []
		var a: Array = o.h[t]
		if a.size() and int(a[a.size() - 1][0]) == day:
			a[a.size() - 1][1] = ngKho(t)
		else:
			a.append([day, ngKho(t)])
		if a.size() > 7:
			a = a.slice(a.size() - 7)
			o.h[t] = a

# ------------------------------------------------------------------ biểu đồ 7 ngày (số liệu; vẽ ở w_kho_ui.chart)
func mkChart(t: String) -> Dictionary:   # mkChart: {} khi chưa đủ 2 ngày
	var src = mkS().h.get(t, [])
	var a: Array = []
	if src is Array:
		for x in src:
			a.append([int(x[0]), int(x[1])])
	var day: int = G.day()
	var now := ngKho(t)
	if a.is_empty() or int(a[a.size() - 1][0]) != day:
		a.append([day, now])
	else:
		a[a.size() - 1][1] = now
	if a.size() < 2:
		return {}
	var v: Array = []
	for x in a:
		v.append(int(x[1]))
	var mn: int = v.min()
	var mx: int = v.max()
	var W := 220
	var H := 44
	var r: int = (mx - mn) if mx - mn != 0 else 1
	var pts: Array = []
	for i in a.size():
		pts.append(Vector2(round(6.0 + i * (W - 12) / float(a.size() - 1)), round(6.0 + (H - 12) * (1.0 - float(int(a[i][1]) - mn) / r))))
	var why: Array = mkWhy(t)[1]
	var s := mkSat(t)
	var dd := int(round((1.0 - G.mk_f(t, s)) * 100.0)) if s > 0.0 else 0
	var lbl: String = str(a.size()) + " ngày: thấp " + G.fmt_n(mn) + ", cao " + G.fmt_n(mx) + " xu" + ((" · " + ", ".join(why)) if not why.is_empty() else "") + ((" · bán dồn −" + str(dd) + "%") if dd else "")
	return {"W": W, "H": H, "pts": pts, "n": a.size(), "mn": mn, "mx": mx, "why": why, "dd": dd, "label": lbl, "aria": "Giá " + str(a.size()) + " ngày qua"}

# ------------------------------------------------------------------ bước 5 giây (ui id 'mk'): phần sang ngày
func step(t: float, offline: bool) -> void:   # ui({id:'mk'}).step (hồi sức chợ: game._mk_step)
	MKT -= t
	if MKT > 0.0:
		return
	MKT = 5.0
	var cr := _x("Cr")
	if cr.is_valid() and bool(cr.call()):
		return
	var o := mkS()
	var day: int = G.day()
	if not o.has("d") or int(o.d) != day:
		o.d = day
		MKEC.d = -1
		mkGhi(day)
		mkTinMoi(day)
		G.mark()

# ------------------------------------------------------------------ bán hết một món
func iG(t: String) -> int:   # iG
	var a := int(G.g.barn.get(t, 0))
	if a:
		var n: int = G.sell_value(t, a, false)   # mkVal
		G.g.coins = int(G.g.coins) + n
		G.g.barn[t] = 0
		G.toast.emit("Bán " + str(a) + " " + G.item_name(t) + ", nhận " + G.fmt_n(n) + " xu.")
		G.vib(12)
		G.mark()
		return n
	return 0

# ------------------------------------------------------------------ số đang cần cho đơn (giữ lại khi bán)
func NF(t: String) -> int:   # NF
	var a := 0
	var now: float = G._now_ms()
	for r in G.g.get("orders", []):
		if r is Dictionary and not (float(r.get("w", 0)) > now) and r.get("items") is Array:
			for o in r.items:
				if String(o[0]) == t:
					a += int(o[1])
	# R0().fam[u].req (_rIt: req.it hoặc [[req.id, req.q]]); chỉ đọc, không dựng g.lang
	var L = G.g.get("lang")
	if L is Dictionary and L.get("fam") is Dictionary:
		for u in L.fam.keys():
			var f = L.fam[u]
			var q = f.get("req") if f is Dictionary else null
			if q is Dictionary and not q.is_empty():
				var it: Array = q.it if (q.get("it") is Array and q.it.size() > 0) else [[q.get("id", ""), q.get("q", 0)]]
				for x in it:
					if String(x[0]) == t and int(x[1]) > 0:
						a += int(x[1])
	# phần Ws() (khách sạp mua): bản web cuối cùng đặt Ws = function(){return []} -> không cộng gì
	return a

# câu nhắc dưới nút bán trong #khDet (eG): s = món đang chọn, M = số định bán
func det_hint(s: String, M: int) -> String:   # eG (khDet: R)
	var h := int(G.g.barn.get(s, 0))
	var v := NF(s)
	var x: int = (G.LY if G.D.crops.has(s) else 0) + v
	var E := h - M
	var C := "cho đơn và để gieo" if (v and G.D.crops.has(s)) else ("cho đơn" if v else "để gieo")
	if x > 0 and E < x:
		return ("Bán hết, không chừa lại " + C) if E <= 0 else ("Nên giữ lại " + G.fmt_n(mini(x, h)) + " " + C)
	return ""

# ------------------------------------------------------------------ W8: kho đầy thì bỏ phần vượt
func W8(f: Callable, args: Array = []) -> Variant:   # W8(t)(...)
	var a := {}
	for n in G.g.barn.keys():
		a[n] = G.g.barn[n]
	var e = f.callv(args)
	var r: int = G.kho_n() - G.kho_cap()
	var o: Array = []
	if r > 0:
		for l in G.g.barn.keys():
			var c: int = int(G.g.barn[l]) - int(a.get(l, 0))
			if c > 0 and r > 0:
				var ff := mini(c, r)
				G.g.barn[l] = int(G.g.barn[l]) - ff
				r -= ff
				o.append(str(ff) + " " + G.item_name(l).to_lower())
	if o.size():
		G.toast.emit("Kho đầy, đành bỏ lại " + ", ".join(o) + ".")
	return e
