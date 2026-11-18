extends RefCounted
# Đồ đặt trong làng (g.objs) + luật ô đất của bảng Xây dựng, chép từ bản web:
# fo/ci/D5/Zv/o2/fg/Lz/mb/BENMB/Az (chỗ đặt), mM/bM/bj/mj/Rz/Hz/_v (đặt, dời, bán, xoay, nhận vật có sẵn, dọn),
# As/uM/sM (độ đẹp, hạng làng), hoa cỏ nhỏ g.minis (oq/PM), đường g.road/g.unroad (Xz/CM), nền g.gt (nq/EM).
# Dữ liệu: ui/snap/bd_cat.json (og, LM, Yz, Kz, chuồng, Q5, V5, hj, Nd, eb), Ei = data/nong_trai/cay_an_trai.json và ui/snap/bd_map.json
# (bản đồ ô lúc làng mới: khu fo, loại đất Il, đường gốc Uz, nước fM, ao p0, vật cảnh yc, cây rừng hu, So, hu list).

var G
var F                     # farm.gd (pc_own = ci)
var C := {}               # danh mục
var M := {}               # bản đồ
var Pi := {}              # id -> món
var tm := {}              # LM id -> hoa cỏ nhỏ (có "_x" nhổ bỏ)
var ug := {}              # Yz id -> nền
var Yv := {}              # Kz id -> đường
const BO := {"lantern": 1, "rock": 1, "dao": 1}   # món đã bỏ khỏi game (đào: bỏ 11-16)
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
	C.Ei = G._j("nong_trai/cay_an_trai")   # cây ăn trái: data/nong_trai/cay_an_trai.json (bản 329 bỏ bản chép trong bd_cat)
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
	# đèn lồng, cục đá cũ đã bỏ khỏi game (Link 11-15): món đã đặt trong bản lưu cũng dọn luôn (như bán, remove_at)
	G.g.objs = G.g.objs.filter(func(o): return not (o is Dictionary and BO.has(String(o.get("id", "")))))
	for k in ["clr", "mv", "minis", "road", "unroad", "gt", "penb", "fac"]:
		if not (G.g.get(k) is Dictionary):
			G.g[k] = {}
	for k in G.g.gt.keys():   # loại nền đã bỏ (cỏ, lá khô, phù sa... bản 223): ô đó trả về nền cũ
		if not ug.has(String(G.g.gt[k])) or String(G.g.gt[k]) == "_x":
			G.g.gt.erase(k)

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
	if G.g.unroad.has(k) or dead_roads().has(k):
		return ""
	return uz(x, y)

# đường cụt của làng dẫn vô nhà, chòi, đình, miếu có sẵn: dời món đó đi thì đường cụt cũng bỏ (từ ô cụt sát món, men theo
# tới chỗ giao đường thì thôi)
const HOUSE := {"hut": 1, "hutnho": 1, "pavilion": 1, "dinh": 1, "shrine": 1, "well": 1, "haystack": 1}
var _dead := {}
var _dead_sig := "-"

func _deg(x: int, y: int) -> int:
	var n := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if uz(x + d.x, y + d.y) != "":
			n += 1
	return n

func dead_roads() -> Dictionary:
	var sig := str(G.g.mv.size())
	if sig == _dead_sig:
		return _dead
	_dead_sig = sig
	_dead = {}
	for o in SO:
		if o.wild or not HOUSE.has(o.id) or not G.g.mv.has(o.sk):
			continue
		var st := []
		for a in range(-1, o.fw + 1):
			for b in range(-1, o.fd + 1):
				var inn: bool = a >= 0 and b >= 0 and a < o.fw and b < o.fd
				var corner: bool = (a < 0 or a >= o.fw) and (b < 0 or b >= o.fd)
				if inn or corner:
					continue
				var x: int = o.gx + a
				var y: int = o.gy + b
				if uz(x, y) != "" and _deg(x, y) == 1:
					st.append(Vector2i(x, y))
		while st.size():
			var t: Vector2i = st.pop_back()
			var k := str(t.x) + "," + str(t.y)
			if _dead.has(k) or uz(t.x, t.y) == "" or _deg(t.x, t.y) >= 3:
				continue
			_dead[k] = 1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				st.append(t + d)
	return _dead

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
			if x >= q.x and x < q.x + int(C.mo[p].w) and y >= q.y and y < q.y + int(C.mo[p].h):
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

func obj_at(w: Vector2, pick_px: Callable) -> int:   # qz: món đặt bị chạm: trúng điểm ảnh trước (như farm.pick), không trúng
	# hình nào thì món có ô dưới ngón tay; nhiều cái thì cái vẽ sau (đứng trước) thắng, ao nằm dưới mọi thứ
	var tl := tile_of(w)
	var O: Array = objs()
	var best := [-1, -1e9, -1, -1e9]   # [món trúng hình, hạng, món trúng ô, hạng]
	for l in O.size():
		var c: Dictionary = O[l]
		var t = Pi.get(c.id)
		if t == null or is_fixed(c):   # đồ có sẵn đứng yên (chỉ Dọn / tưới, hái): Xây dựng không chọn / dời
			continue
		var d: float = -1e6 + c.gx + c.gy if c.id == "pond" else float(F.main.draw_rank(F.lang_ve.obj_nodes.get(l, []), w))
		if c.id != "pond" and pick_px.call(l, w):
			if d > best[1]:
				best[0] = l
				best[1] = d
		elif tl.x >= c.gx and tl.x < c.gx + t.fw and tl.y >= c.gy and tl.y < c.gy + t.fd and d > best[3]:
			best[2] = l
			best[3] = d
	return best[0] if best[0] >= 0 else best[2]

func hu_near(w: Vector2, m := 12.0) -> Array:   # cây rừng / cỏ hoang có khung hình quanh chỗ chạm (nới m)
	var tl := tile_of(w)
	var l := int(floor(tl.x))
	var c := int(floor(tl.y))
	var out := []
	var seen := {}
	for s in range(-1, 8):
		for h in 2:
			for p in 2:
				var d = hu_at(l + s + h, c + s + p)
				if d == null or d.hill or seen.has(d.key):
					continue
				seen[d.key] = 1
				var bb: Array = d.bb
				if w.x < float(bb[0]) - m or w.x > float(bb[2]) + m or w.y < float(bb[1]) - m or w.y > float(bb[3]) + m:
					continue
				out.append(d)
	return out

func hu_hit1(d: Dictionary, w: Vector2) -> bool:   # chạm trúng điểm ảnh của cây / cỏ d (chưa có ảnh: khung như cũ)
	var bb: Array = d.bb
	if w.x < float(bb[0]) or w.x > float(bb[2]) or w.y < float(bb[1]) or w.y > float(bb[3]):
		return false
	var px: int = F.main.sc_pick(float(d.k), w) if F.main.has_method("sc_pick") else -1
	if px >= 0:
		return px == 1
	var x: float = (float(bb[2]) - float(bb[0])) * 0.36
	return w.x >= d.sx - x and w.x <= d.sx + x and w.y >= d.sy + (float(bb[1]) - d.sy) * 0.9 and w.y <= d.sy + 10

func hu_hits(w: Vector2) -> Array:   # cây rừng / cỏ hoang trúng điểm ảnh chỗ chạm, đứng trước nhất trước (bản 192)
	var out := hu_near(w, 0.0).filter(func(d): return hu_hit1(d, w))
	out.sort_custom(func(a, b): return a.k > b.k)
	return out

func hu_pick(w: Vector2):   # lM: cây rừng / cỏ hoang bị chạm -> {type: scn|scnlock, o}
	var H := hu_hits(w)
	var f = H[0] if H.size() else null
	var tl := tile_of(w)
	var l := int(floor(tl.x))
	var c := int(floor(tl.y))
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

const XV := {"banana": "ft_chuoi", "wildbanana": "ft_chuoi", "papaya": "ft_dudu", "coconut": "ft_dua", "mango": "ft_xoai", "jackfruit": "ft_mit", "dieu": "ft_dieu",
	"tallgrass": "hc_co", "wildbush": "hc_bui", "reed": "hc_lau", "stump": "goc_cay", "deadwood": "nhanh_kho"}   # tên vật của làng -> món cùng hình

func own_n() -> int:   # số món tính vào giới hạn: không tính vật có sẵn của làng đã gộp vào (f = 1)
	var n := 0
	for o in objs():
		if not o.get("f", 0):
			n += 1
	return n

# MỘT LOẠI ĐỒ (bản 203): mọi vật có sẵn của làng (cây, bụi, nhà tranh, đình, cổng, cầu, sen, rơm...) ở khu đã có thành
# đúng món Xây dựng cùng tên (g.objs, f = 1): dời, bán, xếp, chiếm chỗ, sét đánh, dân ở y như món mình đặt. Khu mới mua thì
# gộp lúc đó. Không còn "vật cảnh có sẵn" riêng.
var _abs_sig := ""
func absorb_so() -> bool:   # true = có gộp thêm
	var sg := str(G.g.get("land")) + "/" + str(G.g.mv.size())
	if sg == _abs_sig:
		return false
	_abs_sig = sg
	var n := 0
	for o in SO:
		if o.wild or o.sk == "" or G.g.mv.has(o.sk) or not so_shown(o):
			continue
		var id: String = XV.get(o.id, o.id)
		if not Pi.has(id):
			continue
		G.g.mv[o.sk] = 1
		objs().append({"id": id, "gx": o.gx, "gy": o.gy, "seed": 0 if String(XV.get(o.id, "")).begins_with("ft_") else o.seed, "f": 1})
		n += 1
	var CX: Dictionary = G.w_all.WL.CX if G.w_all != null else {}
	var now: float = G._now_ms()
	for o in HU:   # khu đất đã mở: cây ăn trái hoang thành cây của mình (sống SONG rồi tự mất), nhà có sẵn thành nhà dân
		var fid: String = XV.get(o.id, o.id)
		var tree: bool = fid.begins_with("ft_")
		if (tree or CX.has(fid)) and Pi.has(fid) and not G.g.clr.has(o.key) and ci(o.pc):
			G.g.clr[o.key] = 1
			var no := {"id": fid, "gx": o.gx, "gy": o.gy, "seed": (int(o.seed) >> 1) if tree else int(o.seed), "f": 1}   # cây: dáng = seed hình / 2
			if tree:
				no["t0"] = now
			objs().append(no)
			n += 1
	for o in SO:
		var fid2: String = XV.get(o.id, "")
		if o.wild and o.sk != "" and fid2.begins_with("ft_") and Pi.has(fid2) and not G.g.mv.has(o.sk) and ci(o.pc):
			G.g.mv[o.sk] = 1
			objs().append({"id": fid2, "gx": o.gx, "gy": o.gy, "seed": int(o.seed) >> 1, "f": 1, "t0": now})
			n += 1
	_abs_sig = str(G.g.get("land")) + "/" + str(G.g.mv.size())
	if n > 0:
		changed()
		if G.w_all != null:   # nhà có sẵn trong khu đất vừa mở: thành nhà dân, có người ở luôn
			G.w_all.WL.uf()
	return n > 0

const SONG := 7.0 * 86400000.0   # cây ăn trái có sẵn của làng (món f): sống 7 ngày (ms, tính từ lúc mở đất) rồi tự mất

func is_decor(o) -> bool:   # đồ có sẵn của làng không có việc gì khác: hoa, đá, cây cảnh, cao su... chỉ Dọn (không dời)
	if not (o is Dictionary) or not int(o.get("f", 0)):
		return false
	var id := String(o.get("id", ""))
	return not C.Ei.has(id) and not (G.w_all != null and G.w_all.WL.CX.has(id))

func is_fixed(o) -> bool:   # đồ có sẵn đứng yên một chỗ: đồ chỉ Dọn + cây ăn trái có sẵn (tưới, hái) — Xây dựng không dời
	return is_decor(o) or (o is Dictionary and int(o.get("f", 0)) == 1 and C.Ei.has(String(o.get("id", ""))))

func days_left(o: Dictionary) -> int:   # cây ăn trái có sẵn: còn mấy ngày thì tự mất
	return maxi(0, int(ceil((float(o.get("t0", G._now_ms())) + SONG - G._now_ms()) / 86400000.0)))

func drop_obj(i: int, pay := true) -> int:   # bỏ món i khỏi làng (Dọn đồ có sẵn / cây hết lần hái): xu như dọn, bụi bay
	var O: Array = objs()
	if i < 0 or i >= O.size():
		return 0
	var o: Dictionary = O[i]
	var t = Pi.get(o.id)
	var e: int = refund(o) if pay and t != null else 0
	var cx: float = float(o.gx) + (float(t.fw) / 2.0 if t != null else 0.5)
	var cy: float = float(o.gy) + (float(t.fd) / 2.0 if t != null else 0.5)
	O.remove_at(i)
	if e > 0:
		G.g.coins = int(G.g.coins) + e
		G.float_text.emit(cx, cy, "+" + G.fmt_n(e) + " xu")
	F.burst(Vector2(en(cx, cy), nn(cx, cy) - 24.0), 10, [Color("#4f8f3a"), Color("#6aa84a"), Color("#a4764d"), Color("#e3d09b")], 90.0, 2.8, 280.0, 2.0, 0.6, 16.0)
	G.vib(10)
	changed()
	return e

# ------------------------------------------------------------------ chiếm chỗ (bản 200, một luật cho mọi món)
# Đặt / dời / xây món gì vào ô nào thì cảnh cũ trên các ô đó (cây cỏ hoang, bụi, cây cảnh nền) bị dọn hẳn, lưu vào save
# (g.clr "t:x,y" + khoá cây hoang), dời món đi chỗ cũ vẫn trống, không mọc lại.
func occupy(gx: int, gy: int, fw: int, fd: int, me = null) -> void:   # me: chính thứ đang đặt (không dọn chính nó)
	# đúng các ô món chiếm: cây cỏ hoang, vật có sẵn của làng (SO, món f) đứng trên đó dọn hẳn. Đồ mình tự đặt không đụng tới.
	var R := Rect2i(gx, gy, fw, fd)
	for y in range(gy, gy + fd):
		for x in range(gx, gx + fw):
			G.g.clr["t:" + str(x) + "," + str(y)] = 1
			var h = hu_at(x, y)
			if h != null:
				G.g.clr[h.key] = 1
			for j in so_at.get(str(x) + "," + str(y), []):
				var o: Dictionary = SO[j]
				if o.sk != "" and not o.ring:
					G.g.mv[o.sk] = 1
	var O: Array = objs()
	for i in range(O.size() - 1, -1, -1):
		var o = O[i]
		if not (o is Dictionary) or not o.get("f", 0) or is_same(o, me):
			continue
		var t = Pi.get(o.id)
		if t != null and R.intersects(Rect2i(int(o.gx), int(o.gy), int(t.fw), int(t.fd))):
			O.remove_at(i)
	ver += 1

# ------------------------------------------------------------------ CHỖ ĐẶT: MỘT DANH SÁCH CHO MỌI THỨ (bản 213)
# Mọi thứ đứng trên làng (món, xưởng, chuồng) đọc / ghi chỗ qua đây. Khoá: "o:<chỉ số món>", "x:<xưởng>", "p:<chuồng>".
# Chỗ lưu trong save giữ như cũ (g.objs, g.fac như bản web) nên save cũ đọc được, nhưng không chỗ nào khác tự đọc / ghi riêng.
func places() -> Array:   # [{k, gx, gy, fw, fd}]
	var out := []
	var O: Array = objs()
	for i in O.size():
		var o = O[i]
		var t = Pi.get(o.id) if o is Dictionary else null
		if t != null and o.id != "pond":
			out.append({"k": "o:" + str(i), "gx": int(o.gx), "gy": int(o.gy), "fw": int(t.fw), "fd": int(t.fd)})
	if G.xw != null:
		for k in G.xw.list_built():
			var e: Dictionary = G.xw.sr[k]
			out.append({"k": "x:" + k, "gx": int(e.gx), "gy": int(e.gy), "fw": int(e.fw), "fd": int(e.fd)})
	for p in C.Di:
		if pen_built(p):
			var q: Vector2i = pen_pos(p)
			out.append({"k": "p:" + p, "gx": q.x, "gy": q.y, "fw": int(C.mo[p].w), "fd": int(C.mo[p].h)})
	return out

func place_set(k: String, x: int, y: int, commit := true) -> void:   # dời thứ có khoá k tới (x, y); commit: chiếm chỗ + dựng lại
	var kind := k.substr(0, 1)
	var id := k.substr(2)
	var fw := 1
	var fd := 1
	if kind == "o":
		var o: Dictionary = objs()[int(id)]
		o.gx = x
		o.gy = y
		var t = Pi.get(o.id)
		if t != null:
			fw = int(t.fw)
			fd = int(t.fd)
	else:
		if not (G.g.get("fac") is Dictionary):
			G.g.fac = {}
		G.g.fac[id] = [x, y]
		if kind == "x" and G.xw != null and G.xw.sr.has(id):
			G.xw.sr[id].gx = x
			G.xw.sr[id].gy = y
			fw = int(G.xw.sr[id].fw)
			fd = int(G.xw.sr[id].fd)
		elif kind == "p":
			fw = int(C.mo[id].w)
			fd = int(C.mo[id].h)
	if commit:
		occupy(x, y, fw, fd, objs()[int(id)] if kind == "o" else null)
		changed()

func occupy_all() -> void:   # mọi thứ đang đứng (save cũ): chiếm chỗ một lần
	var O: Array = objs()
	for e in places():
		var me = O[int(String(e.k).substr(2))] if String(e.k).begins_with("o:") else null
		occupy(int(e.gx), int(e.gy), int(e.fw), int(e.fd), me)

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
	for k in G.g.clr:   # ô đã có món chiếm: cảnh nền đứng đó dọn hẳn
		if String(k).begins_with("t:"):
			var p: PackedStringArray = String(k).substr(2).split(",")
			_hr[k] = [int(p[0]), int(p[1]), 1, 1, ""]
	return _hr
