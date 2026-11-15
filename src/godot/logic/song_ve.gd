extends RefCounted
# SÔNG VÀM SỐNG ĐỘNG (bản 176): vẽ + chạm cho các thứ trên sông / mặt nước, bằng bộ ảnh 9 px ui/img/ts (hinh/thuysinh):
#   - bụi ven sông mùa nước nổi (w_cho.Vb): điên điển, kèo nèo, súng ma ở mép nước hai bờ; chạm đi tới hái
#   - lục bình + bèo trôi chung từng cụm (to nhỏ khác nhau), rau muống trôi riêng, luôn xuôi dòng (nước lớn trôi chậm, nước nổi
#     trôi nhanh); chạm vớt (khúc sông đã mua); trôi tới cuối sông thì mờ đi, cụm mới trôi vô từ đầu trên
#   - bãi bùn lúc nước ròng (w_xuong.v6): mảng bùn ở mép nước, có món để mò; chạm đi tới mò
#   - cá búng mặt nước: sông, kênh, ao trên màn thỉnh thoảng có cá búng lên, nước bắn, vòng gợn loang (mưa nhiều, đêm ít)

var F          # farm.gd
var G
var fx: Node2D = null       # cá búng + bãi bùn (lớp mặt nước)

func _init(farm) -> void:
	F = farm
	G = farm.G

# ------------------------------------------------------------------ ảnh 9 px (atlas.json: w, h, ox, oy theo đơn vị làng)
static var _at := {}
static var _tx := {}
static func atlas(kind: String) -> Dictionary:
	if not _at.has(kind):
		var j = JSON.parse_string(FileAccess.get_file_as_string("res://ui/img/ts/" + kind + "/atlas.json"))
		_at[kind] = j.frames if j is Dictionary else {}
	return _at[kind]

static func tex(kind: String, fr: String) -> Texture2D:
	var key := kind + "/" + fr
	if not _tx.has(key):
		var im := Image.new()
		var ok := im.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://ui/img/ts/" + kind + "/" + fr + ".webp")) == OK
		if ok:
			im.generate_mipmaps()
		_tx[key] = ImageTexture.create_from_image(im) if ok else null
	return _tx[key]

func _spr(kind: String, fr: String) -> Sprite2D:   # hình đặt chân ở gốc node (đơn vị làng, 9 px / đơn vị)
	var a: Dictionary = atlas(kind).get(fr, {})
	var s := Sprite2D.new()
	s.centered = false
	s.texture = tex(kind, fr)
	s.scale = Vector2.ONE / 9.0
	s.offset = Vector2(float(a.get("ox", 0.0)), float(a.get("oy", 0.0))) * 9.0
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s

func _dn() -> String:
	return "n" if G.night else "d"

func _sorted(n: Node2D) -> Array:   # thêm vô thứ tự vẽ của làng, trả về dòng xếp lớp để đổi độ sâu khi trôi
	F._add_sorted(n, n.position.y)
	n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return F.sortables[F.sortables.size() - 1]

func _unsort(n: Node2D) -> void:
	for e in F.sortables:
		if e[0] == n:
			F.sortables.erase(e)
			break
	if is_instance_valid(n):
		n.queue_free()

func _owned_at(tl: Vector2) -> bool:
	var L = G.lang
	return L != null and L.ci(String(L.fo(int(floor(tl.x)), int(floor(tl.y)))))

# ------------------------------------------------------------------ mỗi khung
var _t1 := 0.0
func step(dt: float) -> void:
	if G.w_all == null or G.lang == null:
		return
	if fx == null:
		fx = FxNode.new()
		fx.sv = self
		fx.z_index = -6   # trên mặt nước, dưới cây cối trên bờ
		F.add_child(fx)
	_t1 -= dt
	if _t1 <= 0.0:
		_t1 = 1.0
		_bush_sync()
	_float_step(dt)
	fx.step(dt)

# ------------------------------------------------------------------ bụi ven sông (nước nổi)
const BUSH := {"dd": ["dien_dien", "dd"], "kn": ["keo_neo", "kn"], "sm": ["sung_ma", "sm"]}
var bush := {}   # key -> Node2D
func _bush_sync() -> void:
	var WC = G.w_all.WC
	var L: Array = WC.Vb()
	var keep := {}
	for o in L:
		keep[o.key] = 1
		var n = bush.get(o.key)
		if n != null and is_instance_valid(n) and n.get_meta("dn", "") != _dn():
			_unsort(n)
			n = null
		if n == null or not is_instance_valid(n):
			var b: Array = BUSH.get(o.kd, BUSH.dd)
			var h: float = G.nv.Me(int(o.gx) * 7 + int(o.gy), 811)
			var fr: String = _dn() + String(b[1]) + str(int(h * 3.0) % 3) + ("a" if h * 6.0 - floor(h * 6.0) < 0.5 else "b")
			n = Node2D.new()
			n.set_meta("dn", _dn())
			n.position = Vector2(F.en(float(o.gx) + 0.5, float(o.gy) + 0.5), F.nn(float(o.gx) + 0.5, float(o.gy) + 0.5))
			n.add_child(_spr(String(b[0]), fr))
			_sorted(n)
			bush[o.key] = n
		n.modulate.a = 0.35 if WC.cT(o) else 1.0
	for k in bush.keys():
		if not keep.has(k):
			_unsort(bush[k])
			bush.erase(k)

# ------------------------------------------------------------------ lục bình + bèo trôi, rau muống trôi riêng
const N_LB := 12
const N_RAU := 3
var fl := []        # {n, e (dòng xếp lớp), s, off, kind, a, ph}
var _fl_dn := ""
func _clump(kind: String) -> Node2D:
	var n := Node2D.new()
	if kind == "lb":   # cụm nhỏ 3-4 cây, vừa 5-7, to 8-12 (1/3 mỗi loại); bèo trải quanh, cụm to thì bè rộng
		var r := randf()
		var c := (3 + randi() % 2) if r < 0.34 else ((5 + randi() % 3) if r < 0.67 else (8 + randi() % 5))
		var rx := 8.0 + c * 2.8   # bề ngang cụm (đơn vị làng)
		var ry := rx * 0.4
		var P := []
		for i in c:   # lục bình chen nhau, cây sau (cao hơn trên màn) vẽ trước
			var a := randf() * TAU
			var d := sqrt(randf())
			P.append(Vector2(cos(a) * rx * d, sin(a) * ry * d))
		P.sort_custom(func(a, b): return a.y < b.y)
		for i in c:   # 1/4 cụm có cây trổ bông tím
			var fr := _dn() + ("lbf" + str(randi() % 3) if i == c / 2 and randf() < 0.3 else "lb" + str(randi() % 6))
			var s := _spr("luc_binh", fr)
			s.position = P[i]
			s.scale *= randf_range(1.6, 2.0)
			n.add_child(s)
		for i in 2 + c / 2:   # bèo trải quanh cụm
			var s := _spr("beo", _dn() + "beo" + str(randi() % 4))
			var a := randf() * TAU
			s.position = Vector2(cos(a) * rx * randf_range(0.6, 1.25), sin(a) * ry * randf_range(0.6, 1.25) + 1.0)
			s.scale *= randf_range(0.9, 1.25)
			n.add_child(s)
			n.move_child(s, 0)
	else:
		var s := _spr("rau_muong", _dn() + "rau" + str(randi() % 4))
		s.scale *= randf_range(1.1, 1.4)
		n.add_child(s)
	return n

func _fl_put(f: Dictionary, path: Array) -> void:   # đặt node theo vị trí trên dòng sông
	var m := path.size()
	var s := clampf(float(f.s), 0.0, float(m - 1))
	var i := int(floor(s))
	var j := mini(i + 1, m - 1)
	var u := s - i
	var p: Vector2 = Vector2(path[i][0]).lerp(Vector2(path[j][0]), u)
	var w: float = lerpf(float(path[i][1]), float(path[j][1]), u)
	var R: Dictionary = G.w_all.WC.river()
	var tl: Vector2 = p + Vector2(R.nx) * float(f.off) * w * 0.65
	f.tl = tl
	var bob := sin(float(f.ph)) * 0.6
	f.n.position = Vector2(F.en(tl.x, tl.y), F.nn(tl.x, tl.y) + bob)
	f.e[1] = f.n.position.y
	var edge := minf(s, float(m - 1) - s)   # tới đầu sông thì mờ đi
	f.n.modulate.a = clampf(edge / 2.0, 0.0, 1.0) * clampf(float(f.a), 0.0, 1.0)

func _fl_new(kind: String, path: Array, s: float) -> Dictionary:
	var n := _clump(kind)
	n.position = Vector2(0, -99999)
	var f := {"n": n, "e": _sorted(n), "s": s, "off": randf_range(-1.0, 1.0), "kind": kind, "a": 0.0, "ph": randf() * TAU,
		"v": randf_range(0.18, 0.3) * (0.7 if kind == "rau" else 1.0), "key": "fl" + str(randi())}
	_fl_put(f, path)
	return f

func _float_step(dt: float) -> void:
	var R: Dictionary = G.w_all.WC.river()
	if R.is_empty() or R.path.size() < 4:
		return
	var path: Array = R.path
	var m := float(path.size() - 1)
	if _fl_dn != _dn():   # ngày / đêm: dựng lại cụm bằng ảnh đúng buổi
		_fl_dn = _dn()
		for f in fl:
			_unsort(f.n)
		fl = []
	while fl.size() < N_LB + N_RAU:
		var f := _fl_new("lb" if fl.size() < N_LB else "rau", path, randf() * m)
		f.a = 1.0
		fl.append(f)
	# luôn trôi xuôi dòng (về phía +trục sông); nước lớn thì nước dồn lên nên trôi chậm gần như đứng, nước nổi trôi nhanh
	var dir := 1.0
	var sk := 1.3 if G.w_all.WR.qs() else (0.25 if G.w_all.WX.FN() else 1.0)
	for i in fl.size():
		var f: Dictionary = fl[i]
		f.ph = float(f.ph) + dt * 1.3
		f.a = minf(1.0, float(f.a) + dt * 0.5)
		f.s = float(f.s) + dir * sk * float(f.v) * dt / 3.0   # path cách nhau 3 ô
		if f.s < 0.0 or f.s > m:   # trôi khỏi sông: cụm mới từ đầu kia
			_unsort(f.n)
			fl[i] = _fl_new(String(f.kind), path, m if dir < 0.0 else 0.0)
			continue
		_fl_put(f, path)

# ------------------------------------------------------------------ chạm: thêm vô danh sách chạm của farm, rồi đi tới làm
func pick_add(L: Array) -> void:
	if G.w_all == null:
		return
	var WC = G.w_all.WC
	for o in WC.Vb():   # bụi ven sông
		if WC.cT(o):
			continue
		var nf := Vector2(F.en(float(o.gx) + 0.5, float(o.gy) + 0.5), F.nn(float(o.gx) + 0.5, float(o.gy) + 0.5))
		F._pk_add(L, {"type": "nn", "k": o.key, "gx": o.gx, "gy": o.gy}, 6, nf.y, func(p: Vector2) -> bool: return absf(p.x - nf.x) < 16.0 and p.y > nf.y - 40.0 and p.y < nf.y + 6.0)
	for f in fl:   # cụm trôi
		var q: Vector2 = f.n.position
		if f.n.modulate.a < 0.5:
			continue
		F._pk_add(L, {"type": "fl", "k": f.key}, 6, q.y, func(p: Vector2) -> bool: return absf(p.x - q.x) < 15.0 and p.y > q.y - 14.0 and p.y < q.y + 6.0)
	var WX = G.w_all.WX
	for o in WX.v6():   # bãi bùn
		if WX.bS(o):
			continue
		var nb := Vector2(F.en(float(o.x), float(o.y)), F.nn(float(o.x), float(o.y)))
		F._pk_add(L, {"type": "bun", "k": o.key, "gx": o.gx, "gy": o.gy}, 6, nb.y, func(p: Vector2) -> bool: return absf(p.x - nb.x) < 16.0 and absf(p.y - nb.y) < 10.0)

func tap(h: Dictionary) -> void:
	var k := String(h.k)
	if F.has_job(k):
		return
	if h.type == "fl":
		for f in fl:
			if f.key == k:
				if not _owned_at(f.tl):
					G.toast.emit("Khúc sông này chưa mua, chưa vớt được.")
					return
				F.q.append({"key": k, "kind": "fl", "i": -1, "seed": k, "pos": Vector2(f.tl)})
		return
	F.q.append({"key": k, "kind": String(h.type), "i": -1, "seed": k, "pos": Vector2(float(h.gx) + 0.5, float(h.gy) + 1.2)})

func job(j: Dictionary) -> bool:   # tới nơi: hái / vớt / mò
	match String(j.kind):
		"nn":
			return G.w_all.WC.wx(String(j.seed))
		"bun":
			return G.w_all.WX.gk(String(j.seed))
		"fl":
			for i in fl.size():
				var f: Dictionary = fl[i]
				if f.key == j.seed:
					if not G.kho_fit(1):
						return false
					var it := "luc_binh" if f.kind == "lb" else "rau_muong"
					var c := 2 + (1 if randf() < 0.4 else 0)
					G.g.barn[it] = int(G.g.barn.get(it, 0)) + c
					G.float_text.emit(float(f.tl.x), float(f.tl.y), "+" + str(c) + " " + G.item_name(it))
					G.vib(8)
					G.mark()
					_unsort(f.n)   # vớt rồi: cụm mới trôi vô từ đầu sông
					var R: Dictionary = G.w_all.WC.river()
					fl[i] = _fl_new(String(f.kind), R.path, 0.0)   # trôi xuôi: vô từ đầu trên
					return true
	return false

# ------------------------------------------------------------------ cá búng + bãi bùn (vẽ bằng nét: giọt nước, vòng gợn, mảng bùn)
class FxNode extends Node2D:
	var sv
	var ev := []          # cá búng đang diễn: {p, t, d, dir}
	var cd := 2.0
	var _vs := ""
	func step(dt: float) -> void:
		var G = sv.G
		var F = sv.F
		cd -= dt
		if cd <= 0.0:
			var k := 1.0
			if G.troi != null and G.troi.rainy():
				k *= 0.45
			if G.night:
				k *= 2.5
			cd = randf_range(1.2, 3.5) * k
			_spawn(F, G)
		for e in ev:
			e.t = float(e.t) + dt
		ev = ev.filter(func(e): return float(e.t) < float(e.d))
		var v6: Array = G.w_all.WX.v6() if G.w_all != null else []
		var vs := str(v6.size()) + str(G.g.get("td", {}).get("p", {}).size() if G.g.get("td") is Dictionary else 0)
		if not ev.is_empty() or vs != _vs:
			_vs = vs
			queue_redraw()
	func _spawn(F, G) -> void:
		var L = G.lang
		var vp: Vector2 = F.get_viewport().get_visible_rect().size / F.main.zoom
		for tr in 20:   # tìm một ô nước trên màn
			var w: Vector2 = F.main.cam + Vector2(randf() * vp.x, randf() * vp.y)
			var tl: Vector2 = F.to_tile(w)
			var x := int(floor(tl.x))
			var y := int(floor(tl.y))
			if L.fm(x, y) or L.zv(x, y, -1) == "water":
				ev.append({"p": w, "t": 0.0, "d": 1.6, "dir": 1.0 if randf() < 0.5 else -1.0, "s": randf_range(0.8, 1.2)})
				return
	func _draw() -> void:
		var G = sv.G
		# bãi bùn
		var WX = G.w_all.WX if G.w_all != null else null
		if WX != null:
			for o in WX.v6():
				var c := Vector2(sv.F.en(float(o.x), float(o.y)), sv.F.nn(float(o.x), float(o.y)))
				var done: bool = WX.bS(o)
				draw_set_transform(c, 0.0, Vector2(1.0, 0.5))
				draw_circle(Vector2.ZERO, 22.0, Color(0.36, 0.27, 0.17, 0.55 if done else 0.85))
				draw_circle(Vector2(-4, -3), 15.0, Color(0.45, 0.35, 0.23, 0.5 if done else 0.8))
				draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color(0.25, 0.19, 0.12, 0.6), 1.2, true)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				if not done:
					var ic: Texture2D = sv.F.ui.item_ic(String(o.k), 32.0)
					if ic != null:
						draw_texture_rect(ic, Rect2(c + Vector2(-6, -10), Vector2(12, 12)), false)
		# cá búng: cá vọt lên theo đường cong rồi lặn, nước bắn ở chỗ lên và chỗ xuống, vòng gợn loang ra
		for e in ev:
			var u: float = float(e.t) / float(e.d)
			var p: Vector2 = e.p
			var dir: float = e.dir
			var sc: float = e.s
			var j := u / 0.4
			var p1 := p + Vector2(10.0 * dir * sc, 0)
			for r in [[p, 0.0], [p1, 0.38]]:   # vòng gợn ở chỗ lên, chỗ xuống
				var ru: float = (u - float(r[1])) / 0.6
				if ru > 0.0 and ru < 1.0:
					for q in 2:
						var rr := (3.0 + ru * 12.0 + q * 4.0) * sc
						draw_set_transform(r[0], 0.0, Vector2(1.0, 0.42))
						draw_arc(Vector2.ZERO, rr, 0.0, TAU, 28, Color(0.9, 0.96, 1.0, 0.55 * (1.0 - ru) * (1.0 - q * 0.4)), 1.0, true)
						draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if j < 1.0:   # thân cá
				var x := lerpf(0.0, 10.0 * dir * sc, j)
				var y := -sin(j * PI) * 9.0 * sc
				var ang := atan2(-cos(j * PI) * 9.0 * PI, 10.0 * dir)
				draw_set_transform(p + Vector2(x, y), ang, Vector2(sc, sc))
				draw_colored_polygon(PackedVector2Array([Vector2(-4.5, 0), Vector2(-1.5, -1.6), Vector2(3.0, -1.2), Vector2(4.8, 0), Vector2(3.0, 1.2), Vector2(-1.5, 1.6)]), Color(0.78, 0.83, 0.88))
				draw_colored_polygon(PackedVector2Array([Vector2(-4.2, 0), Vector2(-7.0, -2.2), Vector2(-6.3, 0), Vector2(-7.0, 2.2)]), Color(0.62, 0.68, 0.74))
				draw_line(Vector2(-1.5, -1.2), Vector2(3.0, -0.9), Color(0.45, 0.52, 0.6), 0.8, true)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for b in [[p, 0.0], [p1, 0.4]]:   # giọt nước bắn
				var bu: float = (u - float(b[1])) / 0.25
				if bu > 0.0 and bu < 1.0:
					for q in 5:
						var a := -PI * (0.2 + 0.6 * q / 4.0)
						var d := Vector2(cos(a), sin(a)) * (2.0 + bu * 7.0) * sc
						d.y += bu * bu * 6.0 * sc
						draw_circle(b[0] + d, 0.9 * sc, Color(0.92, 0.97, 1.0, 0.8 * (1.0 - bu)))
