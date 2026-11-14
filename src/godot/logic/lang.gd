extends RefCounted
# Đồ đặt trong làng (g.objs) + luật ô đất của bảng Xây dựng, chép từ bản web:
# fo/ci/D5/Zv/o2/fg/Lz/mb/BENMB/Az (chỗ đặt), mM/bM/bj/mj/Rz/Hz/_v (đặt, dời, bán, xoay, nhận vật có sẵn, dọn),
# As/uM/sM (độ đẹp, hạng làng), hoa cỏ nhỏ g.minis (oq/PM), đường g.road/g.unroad (Xz/CM), nền g.gt (nq/EM).
# Dữ liệu: ui/snap/bd_cat.json (og, LM, Yz, Kz, chuồng, Q5, V5, hj, Nd, Ei, eb) và ui/snap/bd_map.json
# (bản đồ ô lúc làng mới: khu fo, loại đất Il, đường gốc Uz, nước fM, ao p0, vật cảnh yc, cây rừng hu, So, hu list).

var G
var F                     # farm.gd (pc_own = ci)
var C := {}               # danh mục
var M := {}               # bản đồ
var Pi := {}              # id -> món
var tm := {}              # LM id -> hoa cỏ nhỏ (có "_x" nhổ bỏ)
var ug := {}              # Yz id -> nền
var Yv := {}              # Kz id -> đường
var SO := []              # So: vật cảnh có sẵn (dời / dọn được khi khu đã có)
var HU := []              # hu: cây rừng, cỏ, nhà xa (dọn được)
var so_at := {}           # "x,y" -> [chỉ số So] (vật cảnh không hoang)
var a1 := {}              # "x,y" -> [chỉ số g.objs] (wh)
var _a1_sig := ""
var ver := 0              # đổi mỗi lần đồ trong làng đổi (vẽ lại)

func _init(game, farm) -> void:
	G = game
	F = farm
	C = JSON.parse_string(FileAccess.get_file_as_string("res://ui/snap/bd_cat.json"))
	M = JSON.parse_string(FileAccess.get_file_as_string("res://ui/snap/bd_map.json"))
	for t in C.og:
		Pi[t.id] = t
	for t in C.LM:
		tm[t.id] = t
	tm["_x"] = {"id": "_x", "n": "Nhổ bỏ", "cost": 0}
	for t in C.Yz:
		ug[t.id] = t
	ug["_x"] = {"id": "_x", "n": "Trả cỏ", "cost": 0}
	for t in C.Kz:
		Yv[t.id] = t
	for r in M.S:
		SO.append({"sk": r[0], "id": r[1], "kind": r[2], "gx": int(r[3]), "gy": int(r[4]), "fw": int(r[5]), "fd": int(r[6]),
			"seed": int(r[7]), "wild": int(r[8]) == 1, "ring": int(r[9]) == 1, "pc": r[10], "k": float(r[11]),
			"sx": float(r[12]), "sy": float(r[13]), "bb": r[14]})
	for r in M.H:
		HU.append({"key": r[0], "id": r[1], "kind": r[2], "gx": int(r[3]), "gy": int(r[4]), "fw": int(r[5]), "fd": int(r[6]),
			"seed": int(r[7]), "hill": int(r[8]) == 1, "pc": r[9], "k": float(r[10]), "sx": float(r[11]), "sy": float(r[12]),
			"bb": r[13]})
	for j in SO.size():
		var o: Dictionary = SO[j]
		if o.wild or o.ring:
			continue
		for a in o.fw:
			for b in o.fd:
				var k := str(o.gx + a) + "," + str(o.gy + b)
				if not so_at.has(k):
					so_at[k] = []
				so_at[k].append(j)
	for k in ["objs"]:
		if not (G.g.get(k) is Array):
			G.g[k] = []
	for k in ["clr", "mv", "minis", "road", "unroad", "gt", "penb", "fac"]:
		if not (G.g.get(k) is Dictionary):
			G.g[k] = {}

static func en(x: float, y: float) -> float:
	return 4268.0 + (x - y) * 32.0

static func nn(x: float, y: float, z: float = 0.0) -> float:
	return 968.0 + (x + y) * 16.0 - z

static func tile_of(w: Vector2) -> Vector2:   # ((y-hi)/16 + (x-ki)/32)/2, ((y-hi)/16 - (x-ki)/32)/2
	var a := (w.y - 968.0) / 16.0
	var b := (w.x - 4268.0) / 32.0
	return Vector2((a + b) / 2.0, (a - b) / 2.0)

func objs() -> Array:
	return G.g.objs

func changed() -> void:
	ver += 1
	_a1_sig = ""
	G.mark()

# ------------------------------------------------------------------ ô gốc
func _code(x: int, y: int) -> int:
	var B: Array = M.B
	if x < int(B[0]) or x >= int(B[1]) or y < int(B[2]) or y >= int(B[3]):
		return 0
	return int(M.rows[y - int(B[2])][x - int(B[0])])

func fo(x: int, y: int) -> String:   # khu đất của ô ("" = ngoài làng)
	var c := _code(x, y)
	return "" if c == 0 else String(M.P[(c & 255) - 1])

func il(x: int, y: int) -> String:
	return String(M.IL[(_code(x, y) >> 8) & 15])

func n2(x: int, y: int) -> bool:   # ô thuộc khu ruộng chính
	return (_code(x, y) >> 15) & 1 == 1

func fm(x: int, y: int) -> bool:   # mặt nước có sẵn
	return (_code(x, y) >> 16) & 1 == 1

func ci(pc: String) -> bool:
	return pc != "" and F.pc_own(pc)

func kc(x: int, y: int) -> bool:
	return G.g.clr.has(str(x) + "," + str(y))

func hu_at(x: int, y: int):   # vật hu trên ô, chưa dọn (null nếu không)
	var i = M.hu.get(str(x) + "," + str(y))
	if i == null:
		return null
	var o: Dictionary = HU[int(i)]
	return null if kc(o.gx, o.gy) else o

func D5(x: int, y: int) -> bool:   # còn cây hoặc lúa
	if n2(x, y):
		return false
	if hu_at(x, y) != null:
		return true
	return il(x, y) == "paddy" and not kc(x, y)

func uz(x: int, y: int) -> String:   # đường gốc của làng
	return String(M.RD[(_code(x, y) >> 12) & 7])

func fg(x: int, y: int) -> String:   # loại đường trên ô ("" = không có)
	var k := str(x) + "," + str(y)
	if G.g.road.has(k):
		return String(G.g.road[k])
	if G.g.unroad.has(k):
		return ""
	return uz(x, y)

func o2(x: int, y: int) -> bool:
	return fg(x, y) != ""

func so_shown(o: Dictionary) -> bool:   # tc
	if o.sk != "" and G.g.mv.has(o.sk):
		return false
	if o.wild:
		return not ci(o.pc)
	return o.ring or ci(o.pc)

func yc(x: int, y: int) -> Array:   # vật chiếm ô (trừ đồ của mình): vật cảnh còn đó, nước, biển, ruộng, xưởng, chuồng
	var k := str(x) + "," + str(y)
	var out := []
	var base: Array = M.yc.get(k, [])
	var gone := {}
	for j in so_at.get(k, []):
		var o: Dictionary = SO[j]
		if o.sk != "" and G.g.mv.has(o.sk):
			gone[o.id] = int(gone.get(o.id, 0)) + 1
	for s in base:
		if gone.get(s, 0) > 0:
			gone[s] -= 1
			continue
		out.append(s)
	for kx in G.xw.N0:
		if G.xw.built(kx) and kx != F.ui.bdp.fmv:   # xưởng đang nhấc lên: không chắn chính nó (Th(t, false))
			var e: Dictionary = G.xw.sr[kx]
			if x >= int(e.gx) and x < int(e.gx) + int(e.fw) and y >= int(e.gy) and y < int(e.gy) + int(e.fd):
				out.append(kx)
	for p in C.Di:
		if pen_built(p) and p != F.ui.bdp.fmv:
			var q := pen_pos(p)
			if x >= q.x and x < q.x + 2 and y >= q.y and y < q.y + 2:
				out.append("pen")
	return out

func _a1() -> void:   # wh: ô -> các món đặt
	var O: Array = objs()
	var sig := str(ver) + ":" + str(O.size())
	if sig == _a1_sig:
		return
	_a1_sig = sig
	a1 = {}
	for n in O.size():
		var e: Dictionary = O[n]
		var t = Pi.get(e.id)
		if t == null:
			continue
		for a in int(t.fw):
			for b in int(t.fd):
				var k := str(int(e.gx) + a) + "," + str(int(e.gy) + b)
				if not a1.has(k):
					a1[k] = []
				a1[k].append(n)

func is_water(x: int, y: int) -> bool:   # p0: nước có sẵn hoặc ao tự đào
	if fm(x, y):
		return true
	_a1()
	for n in a1.get(str(x) + "," + str(y), []):
		if objs()[n].id == "pond":
			return true
	return false

func yy(x: int, y: int) -> bool:   # Yy: ô có hoa cỏ nhỏ
	var m: Dictionary = G.g.minis
	return m.has(str(x * 2) + "," + str(y * 2)) or m.has(str(x * 2 + 1) + "," + str(y * 2)) or m.has(str(x * 2) + "," + str(y * 2 + 1)) or m.has(str(x * 2 + 1) + "," + str(y * 2 + 1))

func zv(x: int, y: int, n: int, e := false) -> String:   # Zv: "land" / "water" / "" (bận)
	var k := str(x) + "," + str(y)
	var o := fo(x, y)
	if o == "" or not ci(o) or D5(x, y):
		return ""
	_a1()
	var s := 0
	var h := 0
	var p := 0
	for f in a1.get(k, []):
		if f != n:
			if objs()[f].id == "pond":
				s += 1
			else:
				h += 1
	for q in yc(x, y):
		if q != "water" and q != "sign":
			p += 1
	if fm(x, y):
		return "water" if h == 0 and s == 0 and p == 0 else ""
	if s > 0:
		return "water" if h == 0 and p == 0 else ""
	return "" if (h > 0 or p > 0 or o2(x, y) or (not e and yy(x, y))) else "land"

func lz(x: int, y: int, n: int) -> bool:   # Lz: ô đường trống (cho món onroad)
	var k := str(x) + "," + str(y)
	if not o2(x, y) or is_water(x, y):
		return false
	_a1()
	for f in a1.get(k, []):
		if f != n:
			return false
	for q in yc(x, y):
		if q != "sign":
			return false
	return true

func vp(id: String, a: int, b: int) -> bool:   # VP: rào chiếm chỗ nhỏ (a, b) của ô
	var e = C.eb.get(id)
	if e == null:
		return true
	for q in e:
		if int(q[0]) == a and int(q[1]) == b:
			return true
	return false

func _boc(x: int, y: int, e: int) -> int:   # BOC: -1 bận, 1 ô ao của mình, 0 trống
	var k := str(x) + "," + str(y)
	_a1()
	var w := 0
	for i in a1.get(k, []):
		if i != e:
			if objs()[i].id == "pond":
				w = 1
			else:
				return -1
	for q in yc(x, y):
		if q != "water" and q != "sign":
			return -1
	return w

static func bhd(id: String) -> Array:
	return [[0, 2], [1, 2]] if id == "ben" else ([[0, 0], [1, 0]] if id == "ben3" else ([[2, 0], [2, 1]] if id == "ben2" else [[0, 0], [0, 1]]))

func mb(t: Dictionary, a: int, n: int, e: int) -> String:   # lý do không đặt được món t ở (a, n); e = món đang dời
	var id: String = t.id
	if id in ["ben", "ben2", "ben3", "ben4"]:
		var hd := bhd(id)
		for r in int(t.fw):
			for o in int(t.fd):
				var f := a + r
				var s := n + o
				var h := fo(f, s)
				if h == "":
					return "Ra ngoài rìa làng"
				if not ci(h):
					return "Khu đất này chưa khai hoang"
				var b := _boc(f, s, e)
				if b < 0:
					return "Chỗ này đã có vật khác"
				var head := false
				for q in hd:
					head = head or (int(q[0]) == r and int(q[1]) == o)
				if head:
					if not fm(f, s) and b == 0:
						return "Hai ô đầu bến phải nằm trên mặt nước"
				elif o2(f, s):
					return "Không đặt lên đường làng được"
		return ""
	var l := 0
	var c := 0
	for r in int(t.fw):
		for o in int(t.fd):
			var f := a + r
			var s := n + o
			var h := fo(f, s)
			if h == "":
				return "Ra ngoài rìa làng"
			if not ci(h):
				return "Khu đất này chưa khai hoang"
			if D5(f, s):
				return "Chỗ này còn cây hoặc lúa, chạm để dọn trước"
			var p := zv(f, s, e)
			if p == "" and C.eb.has(id) and zv(f, s, e, true) == "land":
				var d := true
				for v in 2:
					for x in 2:
						if G.g.minis.has(str(f * 2 + v) + "," + str(s * 2 + x)) and vp(id, v, x):
							d = false
				if d:
					p = "land"
			if p == "" and t.get("onroad", 0) and lz(f, s, e):
				p = "land"
			if p == "land":
				l += 1
			elif p == "water":
				c += 1
			else:
				return "Không đặt lên đường làng được" if o2(f, s) else "Chỗ này đã có vật khác"
	var wt: String = str(t.get("water", ""))
	if wt == "only":
		return "Món này chỉ đặt được trên mặt nước" if l > 0 else ""
	if wt == "mixed":
		return "" if c > 0 else String(t.get("wmsg", "Cầu cần bắc qua mặt nước"))
	return "Không đặt xuống nước được" if c > 0 else ""

func az(t: Dictionary, a: int, n: int, e: int):   # Az: chỗ đặt được gần (a, n) nhất, tối đa 26 vòng
	for r in 27:
		var best = null
		var bd := 1e9
		for o in range(-r, r + 1):
			for l in range(-r, r + 1):
				if maxi(absi(o), absi(l)) != r:
					continue
				if mb(t, a + o, n + l, e) == "":
					var s := float(o * o + l * l)
					if s < bd:
						bd = s
						best = Vector2i(a + o, n + l)
		if best != null:
			return best
	return null

# ------------------------------------------------------------------ độ đẹp (As / uM / sM)
func pg(id: String) -> int:   # cây giống quý / quà lễ đang giữ (g.lang.cg)
	var l = G.g.get("lang")
	if l is Dictionary and l.get("cg") is Dictionary:
		return int(l.cg.get(id, 0))
	return 0

func cm(t: Dictionary) -> int:   # cM: cấp còn thiếu
	var lv := int(t.get("lv", 0))
	return lv if lv > 0 and G.lv() < lv and pg(t.id) == 0 else 0

func beauty() -> int:   # As
	var t := 0
	for p in F.PC.x1:
		if F.pc_own(p):
			t += 3
	for p in F.PC.tg:
		if F.pc_own(p):
			t += 3
	for o in objs():
		var a = Pi.get(o.id)
		if a != null and not o.get("f", 0):
			t += int(a.b)
	t += G.g.minis.size() / 4
	t += G.g.gt.size() / 6
	return t

func tier(b: int) -> int:   # uM
	var n := 0
	for a in C.Q5.size():
		if b >= int(C.Q5[a].b):
			n = a
	return n

func sell_bonus() -> float:   # sM
	return minf(0.05, beauty() / 4800.0)

# ------------------------------------------------------------------ món đặt
func refund(o: Dictionary) -> int:   # Nz: dọn đồ có sẵn / bán lại nửa giá
	var t: Dictionary = Pi[o.id]
	if o.get("f", 0):
		return int(C.Nd.get(o.id, maxi(5, int(floor(float(t.cost) * 0.1)))))
	return int(floor(float(t.cost) * float(C.hj)))

func count(id: String) -> int:
	var a := 0
	for o in objs():
		if o.id == id:
			a += 1
	return a

func obj_at(w: Vector2, pick_px: Callable) -> int:   # qz: món đặt bị chạm (ô dưới chân hoặc điểm ảnh của hình)
	var tl := tile_of(w)
	var r := -1
	var best := -1e9
	var O: Array = objs()
	for l in O.size():
		var c: Dictionary = O[l]
		var t = Pi.get(c.id)
		if t == null:
			continue
		var f: bool = tl.x >= c.gx and tl.x < c.gx + t.fw and tl.y >= c.gy and tl.y < c.gy + t.fd
		if not f and c.id != "pond":
			f = pick_px.call(l, w)
		if f:
			var d: float = c.gx + c.gy + (t.fw + t.fd) / 2.0 - (0.5 if c.id == "pond" else 0.0)
			if d > best:
				best = d
				r = l
	return r

func so_pick(w: Vector2, strict: bool, pick_px: Callable):   # Oz: vật cảnh có sẵn bị chạm
	var e = null
	for o in SO:
		if o.wild or o.ring or not Pi.has(o.id) or not so_shown(o) or not ci(o.pc):
			continue
		var bb: Array = o.bb
		if w.x < float(bb[0]) or w.x > float(bb[2]) or w.y < float(bb[1]) or w.y > float(bb[3]):
			continue
		var s: bool = pick_px.call(o, w)
		if not s and not strict:
			s = absf(w.x - o.sx) < (float(bb[2]) - float(bb[0])) * 0.22 and w.y >= o.sy + (float(bb[1]) - o.sy) * 0.8 and w.y <= o.sy + 8
		if s and (e == null or o.k > e.k):
			e = o
	return e

func hu_pick(w: Vector2):   # lM: cây rừng / cỏ hoang bị chạm -> {type: scn|scnlock, o}
	var tl := tile_of(w)
	var l := int(floor(tl.x))
	var c := int(floor(tl.y))
	var f = null
	for s in 5:
		for h in 2:
			for p in 2:
				var d = hu_at(l + s + h, c + s + p)
				if d == null or d.hill or (f != null and d.k <= f.k):
					continue
				var bb: Array = d.bb
				var x: float = (float(bb[2]) - float(bb[0])) * 0.36
				if w.x >= d.sx - x and w.x <= d.sx + x and w.y >= d.sy + (float(bb[1]) - d.sy) * 0.9 and w.y <= d.sy + 10:
					f = d
	if f != null:
		return {"type": "scn" if ci(f.pc) else "scnlock", "o": f, "id": f.pc}
	if not n2(l, c) and il(l, c) == "paddy" and not kc(l, c):
		var k := fo(l, c)
		return {"type": "paddy", "gx": l, "gy": c} if ci(k) else {"type": "scnlock", "id": k}
	return null

func clear_hu(o: Dictionary) -> int:   # _v: dọn cây rừng / cỏ hoang lấy xu
	G.g.clr[o.key] = 1
	var a := int(C.Nd.get(o.id, 5))
	G.g.coins += a
	if G.w_all != null:   # No("clear"): dọn cây có khi rơi tre, mây, cuốc (vật liệu nâng sao)
		G.w_all.No("clear", 1, [o.gx + 0.5, o.gy + 0.5])
	G.vib(10)
	if o.id == "tram":
		G.g.barn["cui"] = int(G.g.barn.get("cui", 0)) + 2
		G.float_text.emit(o.gx + o.fw / 2.0, o.gy + o.fd / 2.0 - 0.6, "+2 Củi khô")
	G.float_text.emit(o.gx + o.fw / 2.0, o.gy + o.fd / 2.0, "+" + str(a) + " xu")
	F.burst(Vector2(o.sx, o.sy - 24), 10, [Color("#4f8f3a"), Color("#6aa84a"), Color("#a4764d"), Color("#e3d09b")], 90.0, 2.8, 280.0, 2.0, 0.6, 16.0)
	changed()
	return a

func clear_paddy(x: int, y: int) -> void:   # Dy: gặt lúa hoang ở khu đã có
	G.g.clr[str(x) + "," + str(y)] = 1
	G.g.barn["lua"] = int(G.g.barn.get("lua", 0)) + 1
	G.float_text.emit(x + 0.5, y + 0.5, "+1 Lúa")
	G.vib(8)
	var w := Vector2(4268.0 + (x - y) * 32.0 + 0.0, 968.0 + (x + y) * 16.0 + 16.0)
	F.burst(w - Vector2(0, 6), 8, [Color("#e8c84a"), Color("#c9a640"), Color("#8fbf4a")], 70.0, 2.6, 280.0, 2.0, 0.6, 16.0)
	changed()

const XV := {"banana": "ft_chuoi", "wildbanana": "ft_chuoi", "papaya": "ft_dudu", "coconut": "ft_dua", "mango": "ft_xoai", "jackfruit": "ft_mit", "dieu": "ft_dieu"}

func take_so(o: Dictionary) -> int:   # Hz: nhận vật cảnh có sẵn thành món của mình (rồi dời)
	if objs().size() >= int(C.V5):
		G.toast.emit("Làng đã đủ " + str(int(C.V5)) + " món, hãy bán bớt.")
		return -1
	G.g.mv[o.sk] = 1
	objs().append({"id": XV.get(o.id, o.id), "gx": o.gx, "gy": o.gy, "seed": 0 if XV.has(o.id) else o.seed, "f": 1})
	changed()
	return objs().size() - 1

func take_hu(o: Dictionary) -> int:   # Rz
	if not Pi.has(o.id):
		G.toast.emit("Bụi cỏ này chỉ dọn được. Thoát Xây dựng rồi chạm để dọn.")
		return -1
	if objs().size() >= int(C.V5):
		G.toast.emit("Làng đã đủ " + str(int(C.V5)) + " món, hãy bán bớt.")
		return -1
	G.g.clr[o.key] = 1
	objs().append({"id": XV.get(o.id, o.id), "gx": o.gx, "gy": o.gy, "seed": 0 if XV.has(o.id) else o.seed, "f": 1})
	changed()
	return objs().size() - 1

# ------------------------------------------------------------------ hoa cỏ nhỏ (g.minis, ô nhỏ = nửa ô)
func _gq(x: int, y: int, a: int, b: int) -> bool:   # $G: chỗ nhỏ còn trống cạnh hàng rào
	var k := str(x) + "," + str(y)
	_a1()
	var o: Array = a1.get(k, [])
	if o.is_empty() or o2(x, y):
		return false
	for q in yc(x, y):
		if q != "water" and q != "sign":
			return false
	for i in o:
		var f: Dictionary = objs()[i]
		if not C.eb.has(f.id) or vp(f.id, a, b):
			return false
	return true

func oq(t: int, a: int, n: String) -> String:   # lý do không trồng hoa cỏ nhỏ được
	var e := t >> 1
	var r := a >> 1
	var o := fo(e, r)
	var l = G.g.minis.get(str(t) + "," + str(a))
	if o == "":
		return "Ra ngoài rìa làng"
	if not ci(o):
		return "Khu đất này chưa khai hoang"
	if n == "_x":
		return "" if l != null else "Ở đây không có hoa cỏ"
	if l == n:
		return "Đã có " + String(tm[n].n).to_lower()
	if l != null:
		return ""
	if D5(e, r):
		return "Chỗ này còn cây hoặc lúa, chạm để dọn trước"
	var c := zv(e, r, -1, true)
	if c == "water":
		return "Không trồng xuống nước được"
	if c != "land" and not _gq(e, r, t & 1, a & 1):
		if o2(e, r):
			return "Không trồng lên đường được"
		_a1()
		for f in a1.get(str(e) + "," + str(r), []):
			if C.eb.has(objs()[f].id):
				return "Chỗ này hàng rào đang chiếm"
		return "Chỗ này đã có vật khác"
	return ""

func mini_put(t: int, a: int, id: String, quiet: bool) -> bool:   # PM
	var r = tm.get(id)
	if r == null:
		return false
	var l := oq(t, a, id)
	if l != "":
		if not quiet:
			G.toast.emit(l + ".")
		return false
	if G.g.coins < int(r.cost):
		if not quiet:
			G.toast.emit("Cần " + str(int(r.cost)) + " xu.")
		return false
	G.g.coins -= int(r.cost)
	var k := str(t) + "," + str(a)
	if id == "_x":
		G.g.minis.erase(k)
	else:
		G.g.minis[k] = id
	changed()
	return true

# ------------------------------------------------------------------ đường (g.road / g.unroad)
func xz(t: int, a: int, n: String) -> String:
	var e := fo(t, a)
	if e == "":
		return "Ra ngoài rìa làng"
	if not ci(e):
		return "Khu đất này chưa khai hoang"
	var r := fg(t, a)
	if n == "_x":
		return "" if r != "" else "Ở đây không có đường"
	if r == n:
		return "Đã là " + String(Yv[n].n).to_lower()
	if r != "":
		return ""
	if D5(t, a):
		return "Chỗ này còn cây hoặc lúa, chạm để dọn trước"
	var o := zv(t, a, -1)
	return "Không lát đường trên nước được" if o == "water" else ("Chỗ này đã có vật khác" if o != "land" else "")

func road_put(t: int, a: int, id: String, quiet: bool) -> bool:   # CM
	var r = Yv.get(id)
	if r == null:
		return false
	var l := xz(t, a, id)
	if l != "":
		if not quiet:
			G.toast.emit(l + ".")
		return false
	if G.g.coins < int(r.cost):
		if not quiet:
			G.toast.emit("Cần " + str(int(r.cost)) + " xu cho mỗi ô " + String(r.n).to_lower() + ".")
		return false
	G.g.coins -= int(r.cost)
	var o := str(t) + "," + str(a)
	if id == "_x":
		G.g.road.erase(o)
		if uz(t, a) != "":
			G.g.unroad[o] = 1
	else:
		G.g.road[o] = id
		G.g.unroad.erase(o)
	changed()
	return true

# ------------------------------------------------------------------ nền đất (g.gt)
func nq(t: int, a: int, n: String) -> String:
	var e := fo(t, a)
	if e == "":
		return "Ra ngoài rìa làng"
	if not ci(e):
		return "Khu đất này chưa khai hoang"
	var r = G.g.gt.get(str(t) + "," + str(a))
	if n == "_x":
		return "" if r != null else "Ô này đang là nền gốc"
	if r == n:
		return "Đã là " + String(ug[n].n).to_lower()
	if is_water(t, a):
		return "Không đổi nền dưới nước được"
	if o2(t, a):
		return "Ô này là đường, gỡ đường trước"
	if D5(t, a):
		return "Chỗ này còn cây hoặc lúa, chạm để dọn trước"
	return ""

func nen_put(t: int, a: int, id: String, nb: int, quiet: bool) -> bool:   # EM: cọ 1 ô / 3x3
	var r = ug.get(id)
	if r == null:
		return false
	var L := []
	var o := 1 if nb == 3 else 0
	var f := ""
	for y in range(-o, o + 1):
		for x in range(-o, o + 1):
			var h := nq(t + x, a + y, id)
			if h != "":
				if x == 0 and y == 0:
					f = h
			else:
				L.append(Vector2i(t + x, a + y))
	if L.is_empty():
		if not quiet:
			G.toast.emit((f if f != "" else "Không có ô nào đổi được") + ".")
		return false
	var p := int(r.cost) * L.size()
	if G.g.coins < p:
		var d: int = (int(G.g.coins) / int(r.cost)) if int(r.cost) > 0 else L.size()
		if d <= 0:
			if not quiet:
				G.toast.emit("Cần " + str(int(r.cost)) + " xu cho mỗi ô " + String(r.n).to_lower() + ".")
			return false
		L = L.slice(0, d)
		p = int(r.cost) * L.size()
	G.g.coins -= p
	for c in L:
		var k := str(c.x) + "," + str(c.y)
		if id == "_x":
			G.g.gt.erase(k)
		else:
			G.g.gt[k] = id
	changed()
	return true

# ------------------------------------------------------------------ chuồng (penb / fac), chỉ chuồng, không con vật
func pen_built(p: String) -> bool:   # n1
	return G.g.penb.has(p)

func pen_pos(p: String) -> Vector2i:
	var f = G.g.fac.get(p)
	if f is Array:
		return Vector2i(int(f[0]), int(f[1]))
	var m: Dictionary = C.mo[p]
	return Vector2i(int(m.gx), int(m.gy))

func pen_lv(p: String) -> int:   # Ky: cấp còn thiếu
	var n := int(C.bb.get(p, 1))
	return n if G.lv() < n else 0

const CO := {"ga": "Chuồng gà", "cuu": "Chuồng cừu", "bo": "Chuồng bò", "heo": "Chuồng heo", "de": "Chuồng dê"}

# vật cảnh đã nhận (g.mv) và cây cỏ hoang đã dọn (g.clr): bên nền giấu hình gốc theo chỗ chân (main.xuong_set)
var _hr_sig := ""
var _hr := {}
func hidden_rects() -> Dictionary:
	var sig := str(G.g.mv.size()) + "/" + str(G.g.clr.size()) + "/" + str(ver)
	if sig == _hr_sig:
		return _hr
	_hr_sig = sig
	_hr = {}
	for o in SO:
		if o.sk != "" and G.g.mv.has(o.sk):
			_hr["mv" + String(o.sk)] = [o.gx, o.gy, o.fw, o.fd, o.id]
	for o in HU:
		if G.g.clr.has(o.key):
			_hr["cl" + String(o.key)] = [o.gx, o.gy, o.fw, o.fd, o.id]
	return _hr
