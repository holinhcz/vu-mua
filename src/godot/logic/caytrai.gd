extends RefCounted
# Cây ăn trái: chép luật bản web (Ei / g.objs fp, fw; f2, wc, pu, fq, qM, X5, zb, Rj).
# Mỗi cây là một món đặt trong g.objs có id trong Ei: fp = giây đã ra trái, fw = giây nước còn trong đất (tưới đầy 1800).
# Tốc độ: 1 + 10% đúng mùa (cay_an_trai_dung_mua) + 10% lúc còn nước, tối đa x1,5. Mưa, giông tự tưới.

const F2 := 1800.0          # tưới đầy: 30 phút nước
const M5 := 1.5

var G
var CQ: Array = []          # cq: 4 mùa -> cây đúng mùa

func _init(game) -> void:
	G = game
	CQ = G._j("nong_trai/cay_an_trai_dung_mua")

func ei() -> Dictionary:
	return G.lang.C.Ei if G.lang != null else {}

func tree(i: int):   # Ql: món i là cây ăn trái thì trả về (đủ fp, fw)
	var O: Array = G.g.get("objs", [])
	if i < 0 or i >= O.size() or not (O[i] is Dictionary) or not ei().has(O[i].id):
		return null
	var a: Dictionary = O[i]
	if not a.has("fp"):
		a.fp = 0.0
	if not a.has("fw"):
		a.fw = 0.0
	return a

func E(a: Dictionary) -> Dictionary:
	return ei()[a.id]

func ripe(a: Dictionary) -> bool:   # wc
	return float(a.fp) >= float(E(a).time)

func in_season(id: String) -> bool:   # Oj
	var s: int = G.season()
	return s >= 0 and s < CQ.size() and (CQ[s] as Array).has(id)

func pu(id: String, wet: bool) -> float:   # tốc độ ra trái
	return minf(M5, G.boost() + (0.1 if in_season(id) else 0.0) + (0.1 if wet else 0.0))

func left(a: Dictionary) -> float:   # giây còn lại (tính lúc khô, như bản web)
	return maxf(0.0, (float(E(a).time) - float(a.fp)) / pu(String(a.id), false))

func step(dt: float) -> void:   # fq
	var O: Array = G.g.get("objs", [])
	var T := ei()
	for i in O.size():
		var n = O[i]
		if not (n is Dictionary) or not T.has(n.id):
			continue
		var a: Dictionary = tree(i)
		var e: Dictionary = T[n.id]
		if float(a.fp) >= float(e.time):
			continue
		var r := minf(dt, float(a.fw)) if float(a.fw) > 0.0 else 0.0
		a.fw = maxf(0.0, float(a.fw) - r)
		a.fp = minf(float(e.time), float(a.fp) + r * pu(n.id, true) + (dt - r) * pu(n.id, false))

func can_water(a: Dictionary) -> bool:
	return not ripe(a) and float(a.fw) < F2 * 0.85

func water(i: int) -> bool:   # qM
	var a = tree(i)
	if a == null or not can_water(a):
		return false
	a.fw = F2
	G.mark()
	return true

func rain_all() -> bool:   # zb(true): mưa tưới hết cây chưa chín
	var ch := false
	for i in (G.g.get("objs", []) as Array).size():
		var a = tree(i)
		if a != null and not ripe(a) and float(a.fw) < F2 * 0.9:
			a.fw = F2
			ch = true
	return ch

func harvest(i: int) -> String:   # X5: trả về trái đã hái ("" = không hái được)
	var a = tree(i)
	if a == null or not ripe(a):
		return ""
	var e := E(a)
	var n := int(e.yield)
	if not G.kho_fit(n):
		return ""
	G.g.barn[e.p] = int(G.g.barn.get(e.p, 0)) + n
	a.fp = 0.0
	G.nv.qi("harvest")
	G.mark()
	return String(e.p)

static func ro(s: float) -> int:   # Ro
	return maxi(1, int(ceil(s / 600.0)))

func fast(i: int) -> bool:   # "Chín ngay" bằng sen đỏ
	var a = tree(i)
	if a == null or ripe(a) or not G.spend_ngoc(ro(left(a))):
		return false
	a.fp = float(E(a).time)
	G.mark()
	return true
