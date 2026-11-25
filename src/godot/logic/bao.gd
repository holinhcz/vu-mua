extends RefCounted
# Giông bão: chép module "bao" của bản web.
# Cây ngã khi giông tới (lQ / LK), sét đánh cây (HK), cháy âm ỉ rồi ngã (PK), cưa cây ngã ra củi (uk),
# cây con lớn lại sau 8 phút. Cây ngã đè lên ruộng thì ruộng đó ngưng lớn (_B).
# Cây = cây đang đứng thật trong làng (bản 191): cây cảnh có sẵn chưa dời (lang.SO, khoá sk) + cây mình đặt / đã dời / tự
# trồng (lang.objs, khoá "o" + số riêng của món). Sét, gió chọn trong đó, cháy / ngã / cây con ở đúng chỗ cây đứng; dời cây
# thì trạng thái đi theo cây. Trạng thái lưu trong G.g.wx = {fell: {khoá: {s, p, at, d}}, rung: [], fs}.

const EM := {"coconut": 3, "areca": 3, "banana": 2, "mango": 2, "jackfruit": 2, "papaya": 2, "bamboo": 1, "banyan": 1, "caosu": 2, "dieu": 1}
const SK := 90000.0        # cây bị sét cháy 90 giây rồi ngã
const ON := 480000.0       # cây con 8 phút lớn lại
const IG := {"caosu": "cây cao su", "dieu": "cây điều", "mango": "cây xoài", "jackfruit": "cây mít", "coconut": "cây dừa",
	"banana": "cây chuối", "areca": "cây cau", "bamboo": "bụi tre"}

# món mình đặt -> loài cây của bão (cây ăn trái ft_* là cây cùng loài)
const OBJ := {"ft_dua": "coconut", "ft_xoai": "mango", "ft_mit": "jackfruit", "ft_dudu": "papaya", "ft_chuoi": "banana", "ft_dieu": "dieu"}

var G
var farm = null            # farm.gd gắn vào khi dựng: pc_own, onscreen
var by := {}               # khoá -> cây {sk, id, gx, gy, fw, fd, pc, ring, wild, own}
var ver := 0               # h6: đổi mỗi khi cây đổi trạng thái / chỗ (để vẽ lại)
var bolt = null            # tia sét đang vẽ: {x, y, t, pts} (toạ độ làng)
var _msg := ""
var _msg_t := 0.0
var _pk := 0.0
var _lsig := ""

func _init(game) -> void:
	G = game

func live() -> Dictionary:   # dựng lại danh sách cây khi làng đổi (đặt, dời, nhận cây, xây xưởng / chuồng)
	var L = G.lang
	if L == null:
		return by
	var sg := str(L.ver) + "/" + str(G.g.get("mv", {}).size()) + "/" + str(L.objs().size()) + "/" + str(G.g.get("fac")) + "/" + str(G.g.get("penb"))
	if sg == _lsig:
		return by
	_lsig = sg
	var R := []   # xưởng, chuồng đã xây: cây cảnh dưới đó đã bị dọn
	for e in L.places():
		if not String(e.k).begins_with("o:"):
			R.append(Rect2(float(e.gx), float(e.gy), float(e.fw), float(e.fd)))
	var out := {}
	for o in L.SO:
		if o.sk == "" or not EM.has(o.id) or not L.so_shown(o):
			continue
		var c := Vector2(float(o.gx) + float(o.fw) / 2.0, float(o.gy) + float(o.fd) / 2.0)
		if R.any(func(r): return r.has_point(c)):
			continue
		out[o.sk] = {"sk": o.sk, "id": o.id, "gx": o.gx, "gy": o.gy, "fw": o.fw, "fd": o.fd, "pc": o.pc, "ring": o.ring, "wild": o.wild, "own": false}
	var O: Array = L.objs()
	for o in O:
		var id: String = OBJ.get(String(o.id), String(o.id))
		if not EM.has(id):
			continue
		if not o.has("bk"):   # số riêng của món (giữ qua dời chỗ, lưu theo save)
			G.g["bkn"] = int(G.g.get("bkn", 0)) + 1
			o["bk"] = int(G.g.bkn)
		var t = L.Pi.get(o.id)
		var k := "o" + str(o.bk)
		out[k] = {"sk": k, "id": id, "gx": o.gx, "gy": o.gy, "fw": t.fw if t != null else 1, "fd": t.fd if t != null else 1, "pc": "", "ring": false, "wild": false, "own": true}
	by = out
	ver += 1
	return by

static func now() -> float:
	return Time.get_unix_time_from_system() * 1000.0

func wx() -> Dictionary:   # Tf
	if not (G.g.get("wx") is Dictionary):
		G.g.wx = {}
	var t: Dictionary = G.g.wx
	if not (t.get("fell") is Dictionary):
		t.fell = {}
	if not (t.get("rung") is Array):
		t.rung = []
	if not (t.get("fs") is float or t.get("fs") is int):
		t.fs = -1
	return t

func ck(t: Dictionary) -> bool:   # CK: cây mình đặt, hoặc cây cảnh trong khu đã mua (không phải cây hoang)
	if t.own:
		return true
	if t.ring or t.wild or t.pc == null:
		return false
	return farm != null and farm.pc_own(String(t.pc))

func hn() -> Array:   # HN: cây còn đứng, ngã được
	var f: Dictionary = wx().fell
	var a := []
	for t in live().values():
		if not f.has(t.sk) and ck(t):
			a.append(t)
	return a

func ek(t: Dictionary) -> int:   # EK: ô ruộng kề bên (không trùng chỗ cây)
	for a in G.B0:
		if not G.p(a).get("u", false) or not G.owned(a):
			continue
		var n: Dictionary = G.cells[a]
		if absi(int(n.gx) - int(t.gx)) <= 1 and absi(int(n.gy) - int(t.gy)) <= 1 and not (int(n.gx) == int(t.gx) and int(n.gy) == int(t.gy)):
			return a
	return -1

func lk(cnt: int) -> int:   # LK: quật ngã cnt cây (chọn theo trọng số Em), tối đa 6 cây chưa dọn
	var n := wx()
	var down := 0
	for k in n.fell:
		if n.fell[k].s != "grow":
			down += 1
	if down >= 6:
		return 0
	var e := hn()
	var o := 0.0
	for d in e:
		o += EM[d.id]
	var r := 0
	while r < cnt and e.size() > 0:
		var l := randf() * o
		var c = null
		for f in e:
			l -= EM[f.id]
			if l <= 0.0:
				c = f
				break
		if c == null:
			c = e[e.size() - 1]
		o -= EM[c.id]
		e.erase(c)
		var s := ek(c) if randf() < 0.55 else -1
		var h: Array
		if s >= 0:
			var p: Dictionary = G.cells[s]
			h = [int(p.gx) - int(c.gx), int(p.gy) - int(c.gy)]
		else:
			h = [[1, 0], [0, 1], [1, 1], [-1, 1], [1, -1]].pick_random()
		n.fell[c.sk] = {"s": "down", "p": s, "at": now(), "d": h}
		r += 1
	if r:
		ver += 1
	return r

func storm(first: bool) -> void:   # lQ (AK trái rụng: chờ cây ăn trái qua Godot)
	var a := lk(1 + randi() % 3)
	if not first and a:
		var e := false
		for k in wx().fell:
			var o: Dictionary = wx().fell[k]
			if o.s == "down" and int(o.p) >= 0:
				e = true
		_msg = "Gió giật quật ngã " + str(a) + " cây trong làng" + (", có cây đè lên ruộng (ruộng ngưng lớn)" if e else "") + ". Chạm cây ngã để dọn, được củi."
		_msg_t = 2.6
	G.mark()

func strike() -> void:   # HK: sét đánh cây cao (chưa có cột thu lôi ở bản Godot)
	var t := hn().filter(func(c): return (farm != null and farm.onscreen(c.gx, c.gy, 200.0)) or randf() < 0.3)
	if t.is_empty():
		return
	# web: sort((c, f) => EM[f.id] - EM[c.id] + (random - .5) * 2): cây cao hơn bị sét trước, có xáo nhẹ. So sánh ngẫu nhiên
	# làm Godot báo "bad comparison function": gán mỗi cây một điểm ngẫu nhiên một lần rồi xếp theo điểm đó.
	var sc := {}
	for c in t:
		sc[c] = float(EM[c.id]) + (randf() - 0.5) * 2.0
	t.sort_custom(func(c, f): return sc[c] > sc[f])
	var a: Dictionary = t[0]
	var e := float(a.gx) + float(a.fw) / 2.0
	var r := float(a.gy) + float(a.fd) / 2.0
	var o := []
	for l in range(1, 7):
		o.append([randf_range(-40.0, 40.0), l / 7.0])
	bolt = {"x": 4268.0 + (e - r) * 32.0, "y": 968.0 + (e + r) * 16.0 - 50.0, "t": 0.6, "pts": o}
	G.troi.flash = 1.0
	G.troi.thT = 0.05
	wx().fell[a.sk] = {"s": "burn", "at": now(), "p": -1}
	ver += 1
	G.toast.emit("Đùng! Sét đánh trúng cây " + String(IG.get(a.id, "cao")).trim_prefix("cây ") + ", cháy xém bốc khói. Dựng cột thu lôi (Xây dựng › Vật dụng) để che chắn.")
	G.vib(130)
	G.mark()

func pk() -> void:   # PK: cháy xong thì ngã, cây con lớn xong thì về như cũ
	var t := wx()
	var a := now()
	var n := false
	for e in t.fell.keys():
		var r: Dictionary = t.fell[e]
		if r.s == "burn" and a - float(r.at) > SK:
			t.fell[e] = {"s": "down", "p": -1, "at": a, "d": [[1, 0], [0, 1], [1, 1]].pick_random()}
			n = true
		elif r.s == "grow" and a - float(r.at) > ON:
			t.fell.erase(e)
			n = true
	if n:
		ver += 1
		G.mark()

func step(dt: float) -> void:
	if bolt != null:
		bolt.t -= dt
		if bolt.t <= 0.0:
			bolt = null
	if _msg_t > 0.0:
		_msg_t -= dt
		if _msg_t <= 0.0:
			G.toast.emit(_msg)
	_pk -= dt
	if _pk <= 0.0:
		_pk = 2.0
		# cây không còn đứng (bán, nhận rồi bỏ, xưởng xây đè): bỏ trạng thái (d6)
		var f: Dictionary = wx().fell
		var L0 := live()
		for k in f.keys():
			if not L0.has(k):
				f.erase(k)
				ver += 1
		pk()

func blocks(i: int) -> bool:   # _B: ruộng bị cây ngã đè
	var f = G.g.get("wx", {}).get("fell", {}) if G.g.get("wx") is Dictionary else {}
	for k in f:
		var r: Dictionary = f[k]
		if r.s == "down" and int(r.get("p", -1)) == i:
			return true
	return false

func hit(w: Vector2) -> String:   # qK: chạm trúng cây ngã / cây cháy
	var n: Dictionary = wx().fell
	for k in n:
		var o: Dictionary = n[k]
		if o.s == "grow" or not by.has(k):
			continue
		var l: Dictionary = by[k]
		var c := float(l.gx) + float(l.fw) / 2.0
		var f := float(l.gy) + float(l.fd) / 2.0
		if o.s == "down":
			var p: Array = o.get("d", [1, 0])
			var dx: float = 4268.0 + ((c + p[0] * 0.6) - (f + p[1] * 0.6)) * 32.0
			var dy: float = 968.0 + ((c + p[0] * 0.6) + (f + p[1] * 0.6)) * 16.0
			if absf(w.x - dx) < 40.0 and w.y > dy - 44.0 and w.y < dy + 16.0:
				return k
		else:
			var s := 4268.0 + (c - f) * 32.0
			var h := 968.0 + (c + f) * 16.0
			if absf(w.x - s) < 18.0 and w.y > h - 60.0 and w.y < h + 6.0:
				return k
	return ""

func stand(k: String) -> Vector2:   # BK: chỗ đứng cưa
	var a: Dictionary = by[k]
	return Vector2(float(a.gx) + float(a.fw) / 2.0 + 0.2, float(a.gy) + float(a.fd) + 0.3)

func state(k: String) -> String:
	var f: Dictionary = wx().fell
	return f[k].s if f.has(k) else ""

func chop(k: String) -> bool:   # uk: cưa cây ngã ra 3–5 bó củi, trồng cây con
	var a := wx()
	if not a.fell.has(k) or a.fell[k].s == "grow":
		return false
	if a.fell[k].s == "burn":
		G.toast.emit("Cây đang cháy âm ỉ, đợi tắt hẳn rồi dọn.")
		return false
	var r := 3 + randi() % 3
	if not G.kho_fit(r):   # (11-25) Kho đầy thì chưa cưa (như thu hoạch ruộng)
		return false
	G.g.barn["cui"] = int(G.g.barn.get("cui", 0)) + r
	a.fell[k] = {"s": "grow", "at": now(), "p": -1}
	ver += 1
	var e: Dictionary = by[k]
	G.float_text.emit(float(e.gx) + 0.5, float(e.gy) + 0.5, "+" + str(r) + " củi")
	if G.w_all != null:   # No("chop"): cưa cây có khi rơi ván, đinh, tre
		G.w_all.No("chop", 1, [float(e.gx) + 0.5, float(e.gy) - 0.2])
	if farm != null:
		farm.burst(Vector2(4268.0 + (float(e.gx) - float(e.gy)) * 32.0, 968.0 + (float(e.gx) + float(e.gy) + 1.0) * 16.0 - 10.0), 12,
			["#8a6440", "#5fa040", "#c9a868"], 90.0, 2.8, 320.0, 2.2, 0.6, 20.0)
	G.toast.emit("Cưa cây ngã ra " + str(r) + " bó củi. Trồng lại cây con, chừng 8 phút là lớn lại như cũ.")
	G.vib(10)
	G.nv.qi("fall")
	G.mark()
	return true
