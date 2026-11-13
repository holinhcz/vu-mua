extends RefCounted
# Xưởng chế biến: chép luật bản web (N0 / sr / g.work, fG, _3, Dp, Df, q3, Mc, Ks).
# Mỗi loại xưởng có 2 cái (I3): cái 1 khoá = loại ("mill"), cái 2 = loại + "2" ("mill2"), giá gấp đôi, mở ở cấp cao hơn.
# g.work[k] = {b: đã xây, q: [món đang chờ, món đầu đang làm], p: giây đã làm món đầu, r: {món: số đã xong chờ thu}, st: sao 1..6}
# g.fac[k] = [gx, gy] chỗ đặt (không có thì chỗ mặc định X8 của cái 1).

const I3 := 2
const M5 := 1.5            # tốc độ tối đa
const X8 := {"mill": [7, 4], "oven": [7, 2], "muoi": [15, 0], "ep": [15, 3], "rang": [15, 6], "kho": [1, 12], "say": [8, 12], "det": [-3, 12]}

var G
var T := {}                # xuong.json: loại -> {name, cost, lv, fw, fd, blurb, rec}
var R := {}                # cong_thuc.json: món -> {w, time, in, fest?}
var LV2 := {}              # cái thứ hai mở cấp
var N0 := []
var sr := {}

func _init(game) -> void:
	G = game
	T = G._j("che_bien/xuong")
	R = G._j("che_bien/cong_thuc")
	LV2 = G._j("che_bien/xuong_cai_thu_hai_mo_cap")
	var wv: Array = G._j("che_bien/thu_tu_xuong")
	var more: Dictionary = G._j("che_bien/mon_lam_them_o_xuong_khac")
	for t in wv:
		var a: Dictionary = T[t]
		var rec: Array = a.rec.duplicate()
		for m in more:   # món làm thêm ở xưởng khác (Ge[m].w nhiều xưởng cách nhau |)
			if String(more[m]).split("|").has(t) and not rec.has(m) and R.has(m):
				rec.append(m)
		for n in I3:
			var k: String = t + (str(n + 1) if n else "")
			var p: Array = X8.get(t, [0, 0]) if n == 0 else [0, 0]
			N0.append(k)
			sr[k] = {"type": t, "n": n, "name": a.name, "cost": int(a.cost) * (2 if n else 1), "fw": int(a.fw), "fd": int(a.fd),
				"blurb": a.get("blurb", ""), "rec": rec, "gx": int(p[0]), "gy": int(p[1]), "lv": int(LV2.get(t, a.lv)) if n else int(a.lv)}
	sync_pos()

func sync_pos() -> void:   # g.fac đè chỗ mặc định
	var f = G.g.get("fac", {})
	if not (f is Dictionary):
		return
	for k in f:
		if sr.has(k):
			sr[k].gx = int(f[k][0])
			sr[k].gy = int(f[k][1])

func w(k: String) -> Dictionary:
	if not (G.g.get("work") is Dictionary):
		G.g.work = {}
	if not (G.g.work.get(k) is Dictionary):
		G.g.work[k] = {"b": 0, "q": [], "p": 0.0, "r": {}}
	return G.g.work[k]

func built(k: String) -> bool:
	return G.g.get("work") is Dictionary and G.g.work.has(k) and int(G.g.work[k].get("b", 0)) == 1

func list_built() -> Array:
	return N0.filter(func(k): return built(k))

func ks(k: String) -> int:   # sao xưởng 1..6
	return clampi(int(w(k).get("st", 1)), 1, 6)

const GS := [20, 40]       # gs: sen đỏ mở ô hàng đợi thứ 4, thứ 5

func qx() -> Dictionary:   # qu(): số ô đã mua thêm mỗi xưởng
	if not (G.g.get("qx") is Dictionary):
		G.g.qx = {}
	return G.g.qx

func nc(k: String) -> int:   # Nc: 3 ô + ô mua bằng sen
	return 3 + int(qx().get(k, 0))

func buy_slot(k: String) -> bool:   # kL
	var a := int(qx().get(k, 0))
	if a >= GS.size() or not G.spend_ngoc(int(GS[a])):
		return false
	qx()[k] = a + 1
	G.toast.emit(String(sr[k].name) + " thêm 1 ô hàng đợi, giờ xếp được " + str(nc(k)) + " món.")
	G.mark()
	return true

func fin_cost(k: String) -> int:   # Ro(q3(k))
	return maxi(1, int(ceil(left(k) / 600.0)))

func finish_now(k: String) -> bool:   # BA: xong ngay món đang làm bằng sen đỏ
	var a := w(k)
	if a.q.is_empty():
		return false
	var n := fin_cost(k)
	if not G.spend_ngoc(n):
		return false
	var e: String = a.q.pop_front()
	a.r[e] = int(a.r.get(e, 0)) + 1
	a.p = 0.0
	G.nv.qi(sr[k].type)
	G.toast.emit(G.item_name(e) + " xong ngay, tốn " + str(n) + " sen đỏ.")
	G.mark()
	return true

func df(k: String) -> int:   # số món xong chờ thu
	var n := 0
	var r: Dictionary = w(k).r
	for e in r:
		n += int(r[e])
	return n

func mc(_k: String) -> float:   # gần Kho hàng (bản Godot chưa có Kho đặt trên bản đồ)
	return 1.0

func speed(k: String) -> float:   # fG: 1 + gần kho + Hệ Thống + 5% mỗi sao, tối đa 1,5
	return minf(M5, 1.0 + (mc(k) - 1.0) + 0.05 * (ks(k) - 1))

func has_in(rid: String) -> bool:   # t1
	for a in R[rid].in:
		if int(G.g.barn.get(a[0], 0)) < int(a[1]):
			return false
	return true

func left(k: String) -> float:   # q3: giây còn lại món đang làm
	var a := w(k)
	if a.q.is_empty():
		return 0.0
	return maxf(0.0, float(R[a.q[0]].time) - float(a.p)) / maxf(1.0, mc(k))

func make(k: String, rid: String) -> bool:   # _3: trừ nguyên liệu, xếp vào hàng đợi
	var n := w(k)
	var e: Dictionary = R.get(rid, {})
	if not built(k) or e.is_empty() or not sr[k].rec.has(rid):
		return false
	if n.q.size() >= nc(k):
		G.toast.emit("Hàng đợi đã đầy (" + str(nc(k)) + " việc). Mở thêm ô bằng sen đỏ để xếp thêm.")
		return false
	if not has_in(rid):
		G.toast.emit("Kho chưa đủ nguyên liệu để làm " + G.item_name(rid).to_lower() + ".")
		return false
	for a in e.in:
		G.g.barn[a[0]] = int(G.g.barn.get(a[0], 0)) - int(a[1])
	n.q.append(rid)
	G.vib(8)
	G.mark()
	return true

func collect(k: String) -> bool:   # Dp
	var a := w(k)
	if df(k) == 0:
		return false
	var f := 0
	for id in a.r:
		f += int(a.r[id])
	if not G.kho_fit(f):   # g8 (bản web bọc Dp)
		return false
	var s: Dictionary = sr[k]
	var at := Vector2(s.gx + s.fw / 2.0, s.gy + s.fd / 2.0)
	var txt := []
	for id in a.r:
		var c := int(a.r[id])
		G.g.barn[id] = int(G.g.barn.get(id, 0)) + c
		txt.append("+" + str(c) + " " + G.item_name(id))
	a.r = {}
	G.float_text.emit(at.x, at.y - 0.6, ", ".join(txt))
	G._drop_at("work", at)
	G.vib(10)
	G.mark()
	return true

func step(t: float) -> void:   # fG
	if not (G.g.get("work") is Dictionary):
		return
	for k in G.g.work:
		var e: Dictionary = G.g.work[k]
		if not sr.has(k) or int(e.get("b", 0)) != 1 or e.q.is_empty():
			continue
		e.p = float(e.p) + t * speed(k)
		while e.q.size() > 0:
			var r: String = e.q[0]
			var o := float(R[r].time)
			if float(e.p) < o:
				break
			e.p = float(e.p) - o
			e.q.pop_front()
			e.r[r] = int(e.r.get(r, 0)) + 1
			G.nv.qi(sr[k].type)
			G.mark()
		if e.q.is_empty():
			e.p = 0.0

func build(k: String, gx := -9999, gy := -9999) -> bool:   # MM (đặt chỗ + trả xu)
	var s: Dictionary = sr[k]
	if built(k):
		return false
	if gx != -9999:
		if not (G.g.get("fac") is Dictionary):
			G.g.fac = {}
		G.g.fac[k] = [gx, gy]
		s.gx = gx
		s.gy = gy
	w(k).b = 1
	G.mark()
	return true

func stand(k: String) -> Vector2:   # GR: chỗ nhân vật đứng làm
	var a: Dictionary = sr[k]
	return Vector2(a.gx + a.fw / 2.0, a.gy + a.fd + 0.3)

func at_tile(x: float, y: float) -> String:   # ô (x, y) nằm trên xưởng nào
	for k in N0:
		if not built(k):
			continue
		var s: Dictionary = sr[k]
		if x >= s.gx - 0.1 and x < s.gx + s.fw + 0.1 and y >= s.gy - 0.1 and y < s.gy + s.fd + 0.1:
			return k
	return ""
