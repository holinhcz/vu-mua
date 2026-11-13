extends RefCounted
# Vẽ đồ Xây dựng trong làng: món đặt (g.objs), hoa cỏ nhỏ (g.minis), chuồng đã xây, đường + nền tô (g.road, g.gt).
# Hình: khung 9 px CÓ SẴN trong godot/<nhóm>/<thư mục>/ (không vẽ lại, không thu nhỏ). Mỗi thư mục = 1 gói l/g_<nhóm>_<thư mục>.wasm,
# mỗi khung 1 ảnh, tải 1 lần, mọi chỗ đặt dùng chung. Bảng ui/snap/bd_pics.json: món -> gói, khung theo "<dáng>" hoặc
# "<mùa>_<dáng>" (cao su, mai), fx = bản xoay lật ngang, lớp (bd rồi fd), chữ bảng hiệu, cờ. Meta khung: [ox, oy, gw, gh]
# (đơn vị game so với tâm chân móng). Ban ngày; đêm dùng màu đêm night_mat của làng như mọi vật khác.
# Chuồng: gói g_congtrinh_chuong_<loại> (g nền, b sau, r0/r1/f0/f1 rào), neo ở điểm lưới.

const L = preload("res://logic/lang.gd")
const PXU := 9.0

var F                    # farm.gd
var LG                   # lang.gd
var PICS := {}           # bd_pics.json
var nodes := []          # [Node2D ...] của món + hoa cỏ nhỏ + chuồng
var flags := []          # [Sprite2D cờ]
var _sig := ""
var tiles: Node2D = null
var ghost: Node2D = null

func _init(farm, lang) -> void:
	F = farm
	LG = lang
	PICS = JSON.parse_string(FileAccess.get_file_as_string("res://ui/snap/bd_pics.json"))
	tiles = TileLayer.new()
	tiles.v = self
	tiles.z_index = -6
	tiles.material = F.main.night_mat
	F.add_child(tiles)
	ghost = Node2D.new()
	ghost.visible = false
	ghost.z_index = 44
	F.add_child(ghost)

func has_pic(id: String) -> bool:
	return PICS.has(id)

func bundle(id: String) -> String:
	var p = PICS.get(id)
	return "" if p == null else String(p.b)

func frames_for(id: String, seed: int) -> Array:   # khung (các lớp) của món theo dáng + mùa
	var p = PICS.get(id)
	if p == null:
		return []
	var K: Dictionary = p.k
	var se := str(F.G.season()) + "_" + str(seed)
	if K.has(se):
		return K[se]
	if K.has(str(seed)):
		return K[str(seed)]
	return K[K.keys()[0]]

func key_for(id: String, seed: int) -> String:
	var f := frames_for(id, seed)
	return "" if f.is_empty() else String(f[0])

func ft_seed(o: Dictionary) -> int:   # cây ăn trái: (đã có trái ? 1 : 0) + 2 * (dáng & 1)
	var e = LG.C.Ei.get(o.id)
	if e == null:
		return int(o.get("seed", 0))
	var ripe := float(o.get("fp", 0.0)) >= float(e.time)
	return (1 if ripe else 0) + 2 * (int(o.get("seed", 0)) & 1)

func _spr(b: String, k: String, foot: Vector2, sway: bool, fx := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.material = F.main.night_mat
	s.position = foot
	s.flip_h = fx
	s.set_meta("b", b)
	s.set_meta("k", k)
	if sway:
		s.modulate = Color(1, 1, 1, 254.0 / 255.0)   # sprite_night: cây đung đưa quanh chân
	return s

func _add(s: Node2D, dk: float) -> void:
	F._add_sorted(s, dk)
	nodes.append(s)

# 1 món = các lớp ảnh (+ chữ bảng hiệu, cờ) quanh chân; lớp fd vẽ sau bd
func _obj(id: String, seed: int, foot: Vector2, dk: float, into_ghost := false) -> void:
	var p = PICS.get(id)
	if p == null:
		return
	var b := String(p.b)
	F.P.load_bundle(b)
	var fx: bool = p.get("fx", false)
	var sw: bool = p.get("sw", false)
	var i := 0
	for k in frames_for(id, seed):
		var s := _spr(b, String(k), foot, sw, fx)
		if into_ghost:
			s.position = Vector2.ZERO
			ghost.add_child(s)
		else:
			_add(s, dk + 0.01 * i)
		i += 1
	if p.has("flag"):
		var fl: Dictionary = p.flag
		F.P.load_bundle(String(fl.b))
		var s := _spr(String(fl.b), "co_d00", foot, false, fx)
		s.set_meta("flag", int(fl.n))
		if fl.has("tint"):
			s.self_modulate = Color(String(fl.tint))
		if fl.has("dx"):
			s.set_meta("fd", Vector2(float(fl.dx) * (-1.0 if fx else 1.0), float(fl.dy)))
		if into_ghost:
			s.position = Vector2.ZERO
			ghost.add_child(s)
		else:
			_add(s, dk + 0.02 * i)
			flags.append(s)
	if p.has("sign"):
		var sg := SignNode.new()
		sg.fnt = F.fnt
		sg.L = p.sign
		sg.fx = fx
		sg.material = F.main.night_mat
		sg.position = Vector2.ZERO if into_ghost else foot
		if into_ghost:
			ghost.add_child(sg)
		else:
			_add(sg, dk + 0.005)

func sync() -> void:
	var O: Array = LG.objs()
	var sig := str(LG.ver) + "|" + str(F.G.season()) + "|" + str(O.size())
	for o in O:
		if LG.C.Ei.has(o.id):
			sig += str(ft_seed(o))
	if sig == _sig:
		return
	_sig = sig
	for s in nodes:
		for e in F.sortables:
			if e[0] == s:
				F.sortables.erase(e)
				break
		s.queue_free()
	nodes = []
	flags = []
	var moving: int = F.ui.bdp.move_idx if F.ui.bdp != null else -1
	for n in O.size():
		if n == moving:
			continue   # đang dời: vẽ bằng hình ma theo chỗ đang chọn
		var o: Dictionary = O[n]
		var t = LG.Pi.get(o.id)
		if t == null or o.id == "pond":
			continue
		var cx: float = float(o.gx) + float(t.fw) / 2.0
		var cy: float = float(o.gy) + float(t.fd) / 2.0
		_obj(String(o.id), ft_seed(o), Vector2(L.en(cx, cy), L.nn(cx, cy)), L.nn(cx, cy) + 0.032 * float(o.gy))
	for k in LG.G.g.minis:
		var p: PackedStringArray = String(k).split(",")
		var c := int(p[0])
		var f := int(p[1])
		var h := c / 2.0 + 0.25
		var q := f / 2.0 + 0.25
		_obj("mini_" + String(LG.G.g.minis[k]), int(floor(F.main.me_hash(c + 7, f + 3) * 4.0)), Vector2(L.en(h, q), L.nn(h, q)), L.nn(h, q))
	for p in LG.C.Di:
		if not LG.pen_built(p) and F.ui.bdp.fmv != p:
			continue
		var g = LG.pen_pos(p)
		var b: String = "g_congtrinh_chuong_" + p
		F.P.load_bundle(b)
		var base := Vector2(L.en(g.x, g.y), L.nn(g.x, g.y))
		for e in [["g", -100.0], ["b", 1.15], ["r0", 2.495], ["f0", 2.495], ["r1", 3.495], ["f1", 3.495]]:
			var s := _spr(b, String(e[0]) + "d", base, false)
			if e[0] == "g":
				s.z_index = -5
				F.add_child(s)
				nodes.append(s)
			else:
				_add(s, 968.0 + (g.x + g.y + float(e[1])) * 16.0)
	tiles.queue_redraw()

func step() -> void:   # mỗi khung: lấy ảnh đúng mức zoom (P.texz), như xưởng; cờ 10 khung/giây
	var scr: float = F.main.zoom * F.main.dpr if "dpr" in F.main else F.main.zoom
	var fi := int(Time.get_ticks_msec() / 100) % 12
	for s in flags:
		if is_instance_valid(s):
			s.set_meta("k", "co_d%02d" % fi)
	for s in nodes:
		if is_instance_valid(s) and s is Sprite2D:
			_tex(s, scr)
	if ghost.visible:
		for s in ghost.get_children():
			if s is Sprite2D:
				if s.has_meta("flag"):
					s.set_meta("k", "co_d%02d" % fi)
				_tex(s, scr)

static func op_name(b: String, k: String) -> String:   # g_caytrai_xoai + dx01 -> caytrai-xoai-dx01 (tên file n/op của làng)
	var p := b.substr(2).split("_", true, 1)
	return p[0] + "-" + p[1] + "-" + k

func _op(s: Sprite2D) -> bool:   # khung làng đã có (n/op): dùng chung đúng file đó, mipmap do làng tạo
	if not F.main.has_method("op_pic"):
		return false
	var nm := op_name(String(s.get_meta("b")), String(s.get_meta("k")))
	var a = F.main.op_box(nm)
	if not (a is Array) or a.size() < 4:   # [] = làng không có khung này
		return false
	if s.get_meta("tk", "") == "op:" + nm and s.texture != null:
		return true
	var tx: Texture2D = F.main.op_pic(nm)
	if tx == null:
		return true
	var sc := float(a[2]) / float(tx.get_width())
	var ox := float(a[0])
	if s.flip_h:
		ox = -(ox + float(a[2]))
	var off := Vector2(ox, float(a[1]))
	if s.has_meta("fd"):
		off += s.get_meta("fd")
	s.texture = tx
	s.scale = Vector2(sc, sc)
	s.offset = off / sc
	s.set_meta("tk", "op:" + nm)
	return true

func _tex(s: Sprite2D, scr: float) -> void:
	if _op(s):
		return
	var b: String = s.get_meta("b")
	var k: String = s.get_meta("k")
	var lv: int = F.P.level(PXU, scr)
	var tk := k + ("" if lv == 0 else "@" + str(lv))
	if s.get_meta("tk", "") == tk and s.texture != null:
		return
	var tx: Texture2D = F.P.texz(b, k, PXU, scr)
	if tx == null:
		return
	var m: Dictionary = F.P.meta(b)
	var a = m.get(k)
	if a == null:
		return
	var sc := float(a[2]) / float(tx.get_width())
	var ox := float(a[0])
	if s.flip_h:
		ox = -(ox + float(a[2]))   # bản xoay: lật ngang quanh tâm chân móng
	var off := Vector2(ox, float(a[1]))
	if s.has_meta("fd"):
		off += s.get_meta("fd")
	s.texture = tx
	s.scale = Vector2(sc, sc)
	s.offset = off / sc
	s.set_meta("tk", tk if tx == F.P.tex(b, tk) else "")

func show_ghost(id: String, seed: int, gx: int, gy: int, bad: bool) -> void:   # kj: món đang đặt (mờ .84, sai chỗ .5)
	var t = LG.Pi.get(id)
	if t == null or id == "pond" or not PICS.has(id):
		ghost.visible = false
		return
	var cx: float = gx + float(t.fw) / 2.0
	var cy: float = gy + float(t.fd) / 2.0
	var sig := id + "/" + str(seed)
	if ghost.get_meta("sig", "") != sig:
		for c in ghost.get_children():
			c.queue_free()
		_obj(id, seed, Vector2.ZERO, 0.0, true)
		ghost.set_meta("sig", sig)
	ghost.position = Vector2(L.en(cx, cy), L.nn(cx, cy))
	ghost.modulate = Color(1, 1, 1, 0.5 if bad else 0.84)
	ghost.visible = true

func hide_ghost() -> void:
	ghost.visible = false

func top_of(o: Dictionary) -> float:   # đỉnh hình món o (tính từ chân, âm là trên chân)
	var p = PICS.get(o.id)
	if p == null:
		return -60.0
	var b := String(p.b)
	var m: Dictionary = F.P.meta(b)
	var top := 0.0
	for k in frames_for(String(o.id), ft_seed(o)):
		var a = m.get(k)
		if a == null and F.main.has_method("op_box"):
			a = F.main.op_box(op_name(b, String(k)))
		if a is Array and a.size() >= 4:
			top = minf(top, float(a[1]))
	return top if top < 0.0 else -60.0

func pick_obj(n: int, w: Vector2) -> bool:   # chạm trúng điểm ảnh của món n (alpha > 40)
	var o: Dictionary = LG.objs()[n]
	var t = LG.Pi.get(o.id)
	if t == null:
		return false
	var cx: float = float(o.gx) + float(t.fw) / 2.0
	var cy: float = float(o.gy) + float(t.fd) / 2.0
	return _hit_id(String(o.id), ft_seed(o), Vector2(L.en(cx, cy), L.nn(cx, cy)), w)

func pick_so(o: Dictionary, w: Vector2) -> bool:   # vật cảnh có sẵn: hình cùng loại
	var id: String = L.XV.get(o.id, o.id)
	return _hit_id(id, 0 if L.XV.has(o.id) else int(o.seed), Vector2(o.sx, o.sy), w)

func _hit_id(id: String, seed: int, foot: Vector2, w: Vector2) -> bool:
	var p = PICS.get(id)
	if p == null:
		return false
	for k in frames_for(id, seed):
		if _hit(String(p.b), String(k), foot, w, p.get("fx", false)):
			return true
	return false

func _hit(b: String, k: String, foot: Vector2, w: Vector2, fx: bool) -> bool:
	var m: Dictionary = F.P.meta(b)
	var a = m.get(k)
	if a == null and F.main.has_method("op_box"):
		a = F.main.op_box(op_name(b, k))   # khung của làng: chỉ xét khung chữ nhật
		if a is Array and a.size() >= 4:
			var ox0 := -(float(a[0]) + float(a[2])) if fx else float(a[0])
			return Rect2(foot.x + ox0, foot.y + float(a[1]), float(a[2]), float(a[3])).grow(-float(a[2]) * 0.15).has_point(w)
		a = null
	if a == null:
		return false
	var ox := float(a[0])
	if fx:
		ox = -(ox + float(a[2]))
	var r := Rect2(foot.x + ox, foot.y + float(a[1]), float(a[2]), float(a[3]))
	if not r.has_point(w):
		return false
	var im: Image = F.P.img(b, k)
	if im == null:
		return true
	var u := (w.x - r.position.x) / r.size.x
	if fx:
		u = 1.0 - u
	var px := int(u * im.get_width())
	var py := int((w.y - r.position.y) / r.size.y * im.get_height())
	if px < 0 or py < 0 or px >= im.get_width() or py >= im.get_height():
		return false
	return im.get_pixel(px, py).a * 255.0 > 40.0

# chữ bảng hiệu (P5 bản web): Nunito, nghiêng theo mặt iso transform(1,.5,0,1); bản lật: chỗ chữ lật, chữ không lật
class SignNode extends Node2D:
	var fnt: Font
	var L: Array = []
	var fx := false
	func _draw() -> void:
		for e in L:
			var x: float = float(e.x) * (-1.0 if fx else 1.0)
			var sk := -0.5 if fx else 0.5
			draw_set_transform_matrix(Transform2D(Vector2(1, sk), Vector2(0, 1), Vector2(x, float(e.y))))
			var px: float = e.px
			var col := Color(String(e.c)) if String(e.c).begins_with("#") else _rgba(String(e.c))
			var w := fnt.get_string_size(String(e.t), HORIZONTAL_ALIGNMENT_LEFT, -1, int(ceil(px * 8.0))).x / 8.0
			draw_set_transform_matrix(Transform2D(Vector2(1, sk), Vector2(-0.2 if e.it else 0.0, 1), Vector2(x, float(e.y))).scaled_local(Vector2(0.125, 0.125)))
			draw_string(fnt, Vector2(-w * 4.0, px * 8.0 * 0.35), String(e.t), HORIZONTAL_ALIGNMENT_LEFT, -1, int(ceil(px * 8.0)), col)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	static func _rgba(s: String) -> Color:
		var p := s.replace("rgba(", "").replace(")", "").split(",")
		return Color(float(p[0]) / 255.0, float(p[1]) / 255.0, float(p[2]) / 255.0, float(p[3]))

# ------------------------------------------------------------------ đường + nền tô (Zz / aq / fj bản web)
class TileLayer extends Node2D:
	var v
	const ROADC := {"do": ["#c96f40", "#bd6538"], "cat": ["#efdfaa", "#e7d69e"], "soi": ["#bdb7a9", "#b3ad9f"],
		"da": ["#a8a49b", "#9f9b92"], "gach": ["#bd5f3f", "#b45838"]}
	const PATH := "#e3d09b"   # Le.path (mG ngày)
	const GRASS := ["#99cc56", "#92c752"]   # Le.grassA, grassB
	var cv: CanvasItem = null   # TileIcon vẽ nhờ lên Control của nó

	func _cv() -> CanvasItem:
		return cv if cv != null else self

	static func i0(c: Color, a: float) -> Color:   # pha trắng (a > 0) hoặc đen (a < 0)
		return c.lerp(Color(0, 0, 0) if a < 0.0 else Color(1, 1, 1), absf(a))

	func me(t: int, a: int) -> float:
		return v.F.main.me_hash(t, a)

	func dia(a: float, n: float, c: Color) -> void:   # xe([a,n-.6,a+32.8,n+16,a,n+32.6,a-32.8,n+16])
		_cv().draw_colored_polygon(PackedVector2Array([Vector2(a, n - 0.6), Vector2(a + 32.8, n + 16), Vector2(a, n + 32.6), Vector2(a - 32.8, n + 16)]), c)

	func ell(x: float, y: float, rx: float, ry: float, c: Color, rot := 0.0) -> void:
		var P := PackedVector2Array()
		for i in 16:
			var q := i / 16.0 * TAU
			var p := Vector2(cos(q) * rx, sin(q) * ry).rotated(rot)
			P.append(Vector2(x, y) + p)
		_cv().draw_colored_polygon(P, c)

	static func k1(a: float, n: float, x: float, y: float) -> Vector2:
		return Vector2(a + (x - y) * 32.0, n + (x + y) * 16.0)

	func tb(x: float, y: float, s: float, c: Color) -> void:   # Tb: khóm cỏ 3 nét
		_cv().draw_line(Vector2(x, y), Vector2(x - 2.2 * s, y - 4 * s), c, 1.2, true)
		_cv().draw_line(Vector2(x, y), Vector2(x + 0.3 * s, y - 5.2 * s), c, 1.2, true)
		_cv().draw_line(Vector2(x, y), Vector2(x + 2.4 * s, y - 3.8 * s), c, 1.2, true)

	func _draw() -> void:
		var LG = v.LG
		var g: Dictionary = LG.G.g
		var M = v.F.main
		if M.has_method("road_set"):   # đường người chơi: bên nền vẽ bằng DUONG (ảnh dg2 9 px + viền + cỏ mép) như web
			var sig := JSON.stringify([g.road, g.unroad])
			if sig != _road_sig:
				_road_sig = sig
				M.road_set(g.road.duplicate(), g.unroad.keys())
		else:
			_draw_roads(g)
		for k in g.gt:
			var p: PackedStringArray = String(k).split(",")
			_nen(String(g.gt[k]), int(p[0]), int(p[1]))

	var _road_sig := ""
	func _draw_roads(g: Dictionary) -> void:   # dự phòng (Zz web) khi bản nền chưa có road_set
		for k in g.unroad:   # đường gốc đã gỡ: trả cỏ
			var p: PackedStringArray = String(k).split(",")
			var x := int(p[0])
			var y := int(p[1])
			if g.road.has(k):
				continue
			dia(4268.0 + (x - y) * 32.0, 968.0 + (x + y) * 16.0, Color(GRASS[(x + y) & 1]))
		for k in g.road:
			var p: PackedStringArray = String(k).split(",")
			var x := int(p[0])
			var y := int(p[1])
			_road(String(g.road[k]), 4268.0 + (x - y) * 32.0, 968.0 + (x + y) * 16.0, x + 40, y + 40)

	func _road(t: String, a: float, n: float, e: int, r: int) -> void:   # Zz
		var o: Array = ROADC.get(t, [PATH, PATH])
		var c := Color(o[0]) if me(e, r) > 0.5 else Color(o[1])
		if t == "dat":
			var pc := Color(PATH)
			c = pc if me(e, r) > 0.5 else pc.lerp(Color(0, 0, 0), 0.05)
		dia(a, n, c)
		var p := i0(c, -0.16)
		var d := i0(c, 0.12)
		if t == "da":
			for f in 9:
				var s := (f % 3) / 3.0 + 0.17
				var h := floorf(f / 3.0) / 3.0 + 0.17
				var vx := a + (s - h) * 32.0
				var vy := n + (s + h) * 16.0
				ell(vx, vy, 7.2, 3.6, p)
				ell(vx - 0.6, vy - 0.8, 6.2, 3.0, d)
		elif t == "gach":
			var lc := i0(c, -0.28)
			for f in range(1, 4):
				_cv().draw_line(k1(a, n, 0, f / 4.0), k1(a, n, 1, f / 4.0), lc, 1.0, true)
			for f in 4:
				for T in 3:
					var w := (T + (0.5 if f % 2 else 0.0)) / 2.5 + 0.1
					if w < 0.98:
						_cv().draw_line(k1(a, n, w, f / 4.0), k1(a, n, w, (f + 1) / 4.0), lc, 1.0, true)
		elif t == "soi":
			for f in 14:
				var s := me(e * 5 + f, r * 3 + 1)
				var h := me(r * 7 + f, e * 2 + 3)
				ell(a + (s - h) * 30.0, n + 16.0 + (s + h - 1.0) * 14.0, 1.6, 1.0, p if f % 2 else d)
		elif t == "cat":
			for f in 6:
				var s := me(e * 3 + f, r * 5 + 2)
				var h := me(r * 3 + f, e * 7 + 1)
				ell(a + (s - 0.5) * 36.0, n + 10.0 + h * 12.0, 2.2, 0.8, p)
		else:
			for f in 3:
				var s := me(e * 3 + f, r * 5)
				var h := me(r * 3 + f, e * 7)
				ell(a + (s - 0.5) * 34.0, n + 10.0 + h * 12.0, 2.0 + s * 2.0, 1.0, p)

	func _nen(t: String, e: int, r: int) -> void:   # aq (nét viền chỗ giáp nền khác)
		_nen_at(t, 4268.0 + (e - r) * 32.0, 968.0 + (e + r) * 16.0, e, r, true)

	func _nen_at(t: String, a: float, n: float, e: int, r: int, edges: bool) -> void:
		var LG = v.LG
		var u = LG.ug.get(t)
		if u == null:
			return
		var c := Color(u.c[0]) if (e + r) & 1 else Color(u.c[1])
		dia(a, n, c)
		var vv := i0(c, -0.17)
		var x := i0(c, -0.28)
		var kk := i0(c, 0.13)
		var M := func(W: int, N: int) -> float: return me(e * 7 + W * 3 + N, r * 5 + W * 11 + N * 2)
		if t in ["co_xanh", "co_non", "co_vang"]:
			var T := 6 if t == "co_vang" else 5
			for f in T:
				var s := k1(a, n, 0.12 + M.call(f, 1) * 0.76, 0.12 + M.call(f, 2) * 0.76)
				tb(s.x, s.y + 1, 0.8 + M.call(f, 3) * 0.5, vv if f % 2 else x)
			for f in 3:
				var s := k1(a, n, 0.15 + M.call(f, 4) * 0.7, 0.15 + M.call(f, 5) * 0.7)
				tb(s.x, s.y + 1, 0.7, kk)
			if t == "co_vang":
				for f in 4:
					var s := k1(a, n, 0.2 + M.call(f, 6) * 0.6, 0.2 + M.call(f, 7) * 0.6)
					_cv().draw_line(s - Vector2(3, 0), s + Vector2(3, -1), i0(c, 0.2), 1.2, true)
		elif t == "co_hoa":
			for f in 4:
				var s := k1(a, n, 0.12 + M.call(f, 1) * 0.76, 0.12 + M.call(f, 2) * 0.76)
				tb(s.x, s.y + 1, 0.9, vv)
			var w := ["#ffffff", "#ffd84a", "#f58ab8", "#a77ae0"]
			for f in 9:
				var s := k1(a, n, 0.1 + M.call(f, 8) * 0.8, 0.1 + M.call(f, 9) * 0.8)
				ell(s.x, s.y, 1.5, 1.0, Color(w[int(floor(M.call(f, 10) * 4.0)) % 4]))
				if f % 3 == 0:
					ell(s.x, s.y, 0.6, 0.4, Color("#f2a43a"))
		elif t == "la_kho":
			var E := ["#d98a32", "#c9a640", "#a8642c", "#e6b84a"]
			for f in 3:
				var s := k1(a, n, 0.15 + M.call(f, 1) * 0.7, 0.15 + M.call(f, 2) * 0.7)
				tb(s.x, s.y + 1, 0.8, vv)
			for f in 8:
				var s := k1(a, n, 0.1 + M.call(f, 3) * 0.8, 0.1 + M.call(f, 4) * 0.8)
				var d: float = M.call(f, 5) * 3.1
				var P := PackedVector2Array()
				for i in 9:
					var q := -3.4 + 6.8 * i / 8.0
					P.append(Vector2(q, -2.4 * 0.55 * (1.0 - pow(q / 3.4, 2)) * 0.9))
				for i in 9:
					var q := 3.4 - 6.8 * i / 8.0
					P.append(Vector2(q, 2.4 * 0.55 * (1.0 - pow(q / 3.4, 2)) * 0.9))
				var T2 := Transform2D(d, s)
				_cv().draw_colored_polygon(T2 * P, Color(E[f % E.size()]))
				_cv().draw_line(T2 * Vector2(-3, 0), T2 * Vector2(3, 0), Color(80 / 255.0, 50 / 255.0, 20 / 255.0, 0.35), 0.7, true)
		elif t == "dat_do" or t == "dat_nau":
			for f in 6:
				var s := k1(a, n, 0.12 + M.call(f, 1) * 0.76, 0.12 + M.call(f, 2) * 0.76)
				var d: float = 1.6 + M.call(f, 3) * 1.8
				ell(s.x, s.y + 0.6, d, d * 0.5, x)
				ell(s.x - 0.3, s.y - 0.2, d * 0.85, d * 0.42, vv if f % 2 else kk)
			for f in 5:
				var s := k1(a, n, 0.1 + M.call(f, 6) * 0.8, 0.1 + M.call(f, 7) * 0.8)
				ell(s.x, s.y, 0.9, 0.55, i0(c, 0.24))
			if M.call(0, 9) > 0.55:
				var s := k1(a, n, 0.2 + M.call(1, 9) * 0.6, 0.2 + M.call(2, 9) * 0.6)
				tb(s.x, s.y + 1, 0.8, Color("#5d9a3a"))
		elif t == "phu_sa":
			for f in 3:
				var s := k1(a, n, 0.2 + M.call(f, 1) * 0.6, 0.2 + M.call(f, 2) * 0.6)
				var C: float = M.call(f, 3) * 6.28
				for R in 3:
					C += M.call(f, 4 + R) - 0.5
					var s2 := s + Vector2(cos(C) * 4.0, sin(C) * 2.0)
					_cv().draw_line(s, s2, vv, 0.9, true)
					s = s2
			for f in 5:
				var s := k1(a, n, 0.1 + M.call(f, 8) * 0.8, 0.1 + M.call(f, 9) * 0.8)
				ell(s.x, s.y, 1.3, 0.7, kk if f % 2 else vv)
		elif t == "dat_cat":
			for f in range(1, 4):
				var N2: float = f / 4.0 + (M.call(f, 1) - 0.5) * 0.08
				var z := k1(a, n, 0.08, N2)
				var rt := k1(a, n, 0.5, N2 - 0.04) - Vector2(0, 1.5)
				var dt := k1(a, n, 0.92, N2)
				var P := PackedVector2Array()
				for i in 9:
					var q := i / 8.0
					P.append(z.lerp(rt, q).lerp(rt.lerp(dt, q), q))
				_cv().draw_polyline(P, i0(c, -0.1), 1.0, true)
			for f in range(1, 4):
				var W2 := f / 4.0 + 0.05
				_cv().draw_line(k1(a, n, 0.12, W2), k1(a, n, 0.88, W2), i0(c, 0.16), 1.0, true)
			for f in 4:
				var s := k1(a, n, 0.12 + M.call(f, 5) * 0.76, 0.12 + M.call(f, 6) * 0.76)
				ell(s.x, s.y, 1.0, 0.6, Color("#fff6dc") if f % 2 else vv)
		# viền chỗ giáp ô nền khác loại (globalAlpha .55)
		if not edges:
			return
		var j := [[e, r - 1, 0, 1, 0, 0], [e + 1, r, 0, 0, 1, 0], [e, r + 1, 1, 0, 1, 1], [e - 1, r, 0, 1, 1, 1]]
		var lc := i0(c, -0.12)
		lc.a = 0.55
		for st in j:
			if String(LG.G.g.gt.get(str(st[0]) + "," + str(st[1]), "")) != t:
				var ut := k1(a, n, st[2], st[3])
				var it := k1(a, n, st[4], st[5])
				var D := Vector2(a, n + 16)
				_cv().draw_line(ut + (D - ut) * 0.04, it + (D - it) * 0.04, lc, 1.6, true)
