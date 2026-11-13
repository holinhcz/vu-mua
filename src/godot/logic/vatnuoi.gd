extends RefCounted
# Vật nuôi: chép luật bản web (qr / Di / g.pens, Q3, dw, pw, K3, lG, _R, kZ, EC, wZ, cy, b8, LH).
# g.pens[loại] = [{p: giây đã lớn (-1 = đói), t: thân 0..5, s: bệnh, h: giây đói, b: giây còn nhỏ, n: tên, pd: ngày vuốt ve, sk: giây bệnh}]
# g.penst[loại] = sao chuồng 1..6 (ps).

const DI := ["ga", "cuu", "bo", "heo", "de"]
const M5 := 1.5
const ZM := 150             # tiền mời thú y
const BABY := 300.0         # giây con nhỏ lớn
const HUNGRY_SICK := 3600.0 # bỏ đói quá 1 tiếng thì bệnh
const D6 := {"ga": ["Mơ", "Ki", "Bông", "Tía", "Nâu", "Ô", "Mái Mơ", "Cồ"], "cuu": ["Bông", "Mây", "Xù", "Kem", "Gòn", "Tuyết"],
	"bo": ["Vàng", "Sữa", "Bông", "Hoa", "Lang", "Mập"], "heo": ["Ủn", "Mập", "Hồng", "Ỉn", "Lợn Lành", "Bé Na"], "de": ["Râu", "Bạch", "Cún", "Sừng", "Lém", "Nâu"]}

var G
var Q := {}                 # vat_nuoi.json: loại -> {name, buy, feed, make, time, make2}
var _sc := 0.0              # SC: bước wZ mỗi 1 giây

func _init(game) -> void:
	G = game
	Q = G._j("vat_nuoi/vat_nuoi")

func pens() -> Dictionary:
	if not (G.g.get("pens") is Dictionary):
		G.g.pens = {}
	for k in DI:
		if not (G.g.pens.get(k) is Array):
			G.g.pens[k] = []
	return G.g.pens

func list(t: String) -> Array:
	return pens()[t]

func a(t: String, j: int):
	var L: Array = list(t)
	return L[j] if j >= 0 and j < L.size() else null

func name(t: String) -> String:
	return String(Q[t].name)

func q4(t: String, j: int) -> String:   # "Gà Mơ"
	var e = a(t, j)
	return name(t) + (" " + String(e.n) if e != null and e.get("n", "") != "" else "")

static func hearts(t: float) -> String:   # CC
	var n := int(floor(t))
	var s := ""
	for e in 5:
		s += "♥" if e < n else "♡"
	return s

func gl() -> int:   # LH: sức chứa mỗi chuồng theo cấp
	var l: int = G.lv()
	return 8 if l >= 82 else 6 if l >= 62 else 4

func ps(t: String) -> int:   # sao chuồng
	var s = G.g.get("penst")
	if not (s is Dictionary):
		s = {}
		G.g.penst = s
	return clampi(int(s.get(t, 1)), 1, 6)

func cy(t: String) -> float:   # tốc độ chuồng: 6% mỗi sao (+ Hệ Thống "Chuồng ấm" khi có)
	return minf(M5, 1.0 + 0.06 * (ps(t) - 1))

func price(t: String) -> int:   # Q3: con sau đắt hơn con trước 1,6 lần
	return int(round(float(Q[t].buy) * pow(1.6, list(t).size())))

func ok(t: String) -> bool:   # _c: chuồng đã xây, nằm trên đất đã khai hoang
	var L = G.lang
	if L == null or not L.pen_built(t):
		return false
	var p: Vector2i = L.pen_pos(t)
	return L.ci(L.fo(p.x, p.y))

func has_any() -> bool:   # _q
	for t in DI:
		if ok(t) and list(t).size() > 0:
			return true
	return false

func _pick_name(t: String) -> String:   # UR
	var A: Array = D6.get(t, ["Bé"])
	var used := []
	for e in list(t):
		used.append(e.get("n", ""))
	var free := A.filter(func(x): return not used.has(x))
	var B: Array = free if free.size() > 0 else A
	return String(B[randi() % B.size()])

# ------------------------------------------------------------------ mua, cho ăn, thu
func buy(t: String) -> bool:   # dw
	var L := list(t)
	var n := price(t)
	if L.size() >= gl():
		G.toast.emit("Chuồng " + name(t).to_lower() + " đã đủ con.")
		return false
	if G.lang == null or not G.lang.pen_built(t):
		G.toast.emit("Chưa có chuồng " + name(t).to_lower() + ". Vào Xây dựng › Chuồng trại xây trước.")
		return false
	if not ok(t):
		G.toast.emit(String(G.lang.CO.get(t, "Chuồng")) + " nằm trên đất chưa khai hoang.")
		return false
	if int(G.g.coins) < n:
		G.toast.emit("Cần " + G.fmt_n(n) + " xu để mua " + name(t).to_lower() + ".")
		return false
	G.g.coins = int(G.g.coins) - n
	L.append({"p": -1, "t": 0, "n": _pick_name(t)})
	G.toast.emit("Đã mua một con " + name(t).to_lower() + ". Nhớ cho ăn nhé.")
	G.vib(10)
	G.mark()
	return true

func hungry(e: Dictionary) -> bool:
	return float(e.p) < 0.0 and not e.get("b", 0) and not e.get("s", 0)

func ready(t: String, e: Dictionary) -> bool:
	return float(e.p) >= float(Q[t].time) and not e.get("s", 0)

func growing(t: String, e: Dictionary) -> bool:
	return float(e.p) >= 0.0 and float(e.p) < float(Q[t].time) and not e.get("s", 0) and not e.get("b", 0)

func feed(t: String, j: int, quiet := false) -> bool:   # pw
	var e = a(t, j)
	var r: Dictionary = Q[t]
	if e == null or float(e.p) >= 0.0:
		return false
	if e.get("b", 0):
		if not quiet:
			G.toast.emit(name(t) + " con còn nhỏ, đang theo mẹ chưa ăn cám được.")
		return false
	if int(G.g.barn.get(r.feed, 0)) < 1:
		if not quiet:
			G.toast.emit("Kho hết " + G.item_name(r.feed) + ". Hãy thu hoạch thêm để cho " + name(t).to_lower() + " ăn.")
		return false
	if not (ps(t) >= 4 and randf() < 0.25):   # chuồng 4★: 25% lần cho ăn không tốn
		G.g.barn[r.feed] = int(G.g.barn[r.feed]) - 1
	e.p = 0.0
	e.h = 0.0
	if not e.get("s", 0):
		e.t = minf(5.0, float(e.get("t", 0)) + 0.1)
	G.mark()
	return true

func collect(t: String, j: int) -> String:   # K3: trả về món đã thu ("" = không thu được)
	var e = a(t, j)
	var r: Dictionary = Q[t]
	if e == null or float(e.p) < float(r.time):
		return ""
	if not G.kho_fit(1):
		return ""
	var m: String = r.make2 if r.has("make2") and randf() < 0.5 else r.make
	G.g.barn[m] = int(G.g.barn.get(m, 0)) + 1
	e.p = -1.0
	G.nv.qi("collect")
	_after(t, j)
	var at := spot(t, j)
	G.float_text.emit(at.x, at.y - 0.6, "+1 " + G.item_name(m))
	G._drop_at("collect", at)
	G.vib(10)
	G.mark()
	return m

func _after(t: String, j: int) -> void:   # _R: thân thì có khi cho thêm; chuồng có 2 con khỏe thì có khi đẻ
	var e: Dictionary = list(t)[j]
	var r: Dictionary = Q[t]
	var th := float(e.get("t", 0))
	if th >= 3.0 and randf() < 0.1 * (th - 2.0):
		G.g.barn[r.make] = int(G.g.barn.get(r.make, 0)) + 1
		var at := spot(t, j)
		G.float_text.emit(at.x, at.y - 0.9, "♥ thêm 1 " + G.item_name(r.make).to_lower())
	var L := list(t)
	var well := L.filter(func(x): return not x.get("b", 0) and not x.get("s", 0)).size()
	if L.size() < gl() and well >= 2 and not e.get("s", 0) and randf() < 0.05 + 0.02 * th:
		var c := {"p": -1, "b": BABY, "t": 1}
		c.n = _pick_name(t)
		L.append(c)
		G.toast.emit(("Gà mái ấp trứng nở ra một chú gà con" if t == "ga" else "Nhà có thêm một " + name(t).to_lower() + " con") + " tên " + String(c.n) + "! Chừng 5 phút nữa là lớn.")

func pet(t: String, j: int) -> bool:   # kZ: mỗi con mỗi ngày một lần
	var e = a(t, j)
	if e == null:
		return false
	var d: int = G.day()
	if int(e.get("pd", -1)) == d:
		G.toast.emit(q4(t, j) + " được vuốt ve rồi, mai nựng tiếp nha.")
		return true
	e.pd = d
	e.t = minf(5.0, float(e.get("t", 0)) + (0.3 if e.get("s", 0) else 0.6))
	hearts_t[t + str(j)] = 2.2
	G.toast.emit("Vuốt ve " + q4(t, j) + ". " + hearts(float(e.t)) + (" Thân lắm rồi, cho hàng nhanh hơn hẳn!" if float(e.t) >= 5.0 else ""))
	G.mark()
	return true

var hearts_t := {}          # _m: tim bay sau khi vuốt ve (giây còn lại)

func vet(t: String, j: int) -> bool:   # EC
	var e = a(t, j)
	if e == null or not e.get("s", 0):
		return false
	if int(G.g.coins) < ZM:
		G.toast.emit("Cần " + str(ZM) + " xu mời thú y.")
		return false
	G.g.coins = int(G.g.coins) - ZM
	e.s = 0
	e.h = 0.0
	G.toast.emit("Thú y Tư Lành chạy xe tới chích thuốc cho " + q4(t, j).to_lower() + ". Mai mốt nhớ cho ăn đúng bữa nha!")
	G.mark()
	return true

func cure_now(t: String, j: int) -> bool:   # "Chữa ngay" 2 sen đỏ
	var e = a(t, j)
	if e == null or not e.get("s", 0) or not G.spend_ngoc(2):
		return false
	e.s = 0
	e.h = 0.0
	G.toast.emit("Thuốc tốt, " + q4(t, j).to_lower() + " khỏe lại liền!")
	G.mark()
	return true

func left(t: String, e: Dictionary) -> float:   # b8: giây còn lại
	return maxf(0.0, (float(Q[t].time) - float(e.p)) / maxf(0.2, cy(t)))

static func ro(s: float) -> int:   # Ro: sen đỏ cho xong ngay
	return maxi(1, int(ceil(s / 600.0)))

func fast(t: String, j: int) -> bool:   # "Xong ngay"
	var e = a(t, j)
	if e == null or not growing(t, e) or not G.spend_ngoc(ro(left(t, e))):
		return false
	e.p = float(Q[t].time)
	G.mark()
	return true

func fast_all_cost(t: String) -> int:   # "Cả chuồng xong ngay": Ro(lâu nhất) + số con - 1
	var s := 0.0
	var n := 0
	for e in list(t):
		if growing(t, e):
			s = maxf(s, left(t, e))
			n += 1
	return 0 if n == 0 else ro(s) + n - 1

func fast_all(t: String) -> bool:
	var c := fast_all_cost(t)
	if c == 0 or not G.spend_ngoc(c):
		return false
	for e in list(t):
		if growing(t, e):
			e.p = float(Q[t].time)
	G.mark()
	return true

# ------------------------------------------------------------------ chạy theo giờ
func step(dt: float, offline := false) -> void:
	# lớn (vw): con có ăn, không bệnh, không còn nhỏ
	for t in DI:
		var h := float(Q[t].time)
		var f := cy(t)
		for e in list(t):
			if float(e.p) >= 0.0 and float(e.p) < h and not e.get("s", 0) and not e.get("b", 0):
				e.p = minf(h, float(e.p) + dt * minf(M5, f + 0.02 * float(e.get("t", 0))))
	for k in hearts_t.keys():
		hearts_t[k] = float(hearts_t[k]) - dt
		if float(hearts_t[k]) <= 0.0:
			hearts_t.erase(k)
	# wZ: con nhỏ lớn dần, đói lâu thì bệnh, trở trời bệnh, bệnh lâu mất thân (mỗi 1 giây, chỉ lúc đang chơi
	# như bản web: lúc tắt game chỉ tính phần lớn)
	if offline:
		return
	_sc -= dt
	if _sc > 0.0:
		return
	var n := 1.0
	_sc = 1.0
	var ch := false
	for t in DI:
		var L := list(t)
		for j in L.size():
			var o: Dictionary = L[j]
			if not o.has("n") or String(o.n) == "":
				o.n = _pick_name(t)
				ch = true
			if float(o.get("b", 0)) > 0.0:
				o.b = float(o.b) - n
				if float(o.b) <= 0.0:
					o.erase("b")
					o.p = -1.0
					G.toast.emit(q4(t, j) + " đã lớn, ăn được rồi đó!")
					ch = true
				continue
			if float(o.p) < 0.0 and not o.get("s", 0):
				o.h = float(o.get("h", 0)) + n
				if float(o.h) > HUNGRY_SICK:
					o.s = 1
					o.t = maxf(0.0, float(o.get("t", 0)) - 1.0)
					G.toast.emit(q4(t, j) + " bỏ đói lâu quá nên bệnh rồi! Chạm vào nó để mời thú y.")
					ch = true
			elif not o.get("s", 0) and randf() < (3e-6 if float(o.get("t", 0)) >= 4.0 else 1e-5):
				o.s = 1
				G.toast.emit(q4(t, j) + " trở trời bị bệnh, nằm ủ rũ. Chạm vào để mời thú y.")
				ch = true
			if o.get("s", 0):
				o.sk = float(o.get("sk", 0)) + n
				if float(o.sk) > 600.0:
					o.sk = 0.0
					o.t = maxf(0.0, float(o.get("t", 0)) - 1.0)
	if ch:
		G.mark()

# ------------------------------------------------------------------ chỗ con vật đứng (mc bản web: farm/vatnuoi_ve gán khi vẽ)
var mc := {}                # loại -> [{x, y, tx, ty, wait, dir, ph, mv}]

func spot(t: String, j: int) -> Vector2:
	var L: Array = mc.get(t, [])
	if j < L.size():
		return Vector2(float(L[j].x), float(L[j].y))
	var p: Vector2i = G.lang.pen_pos(t) if G.lang != null else Vector2i.ZERO
	return Vector2(p.x + 1.0, p.y + 1.0)
