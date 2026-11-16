extends RefCounted
# Vẽ đồ Xây dựng trong làng: món đặt (g.objs), hoa cỏ nhỏ (g.minis), chuồng đã xây, đường + nền tô (g.road, g.gt).
# Hình: khung 9 px CÓ SẴN trong godot/<nhóm>/<thư mục>/ (không vẽ lại, không thu nhỏ). Mỗi thư mục = 1 gói l/g_<nhóm>_<thư mục>.wasm,
# mỗi khung 1 ảnh, tải 1 lần, mọi chỗ đặt dùng chung. Bảng ui/snap/bd_pics.json: món -> gói, khung theo "<dáng>" hoặc
# "<mùa>_<dáng>" (cao su, mai), fx = bản xoay lật ngang, lớp (bd rồi fd), chữ bảng hiệu, cờ. Meta khung: [ox, oy, gw, gh]
# (đơn vị game so với tâm chân móng). Ban ngày; đêm dùng màu đêm night_mat của làng như mọi vật khác.
# Chuồng: gói g_congtrinh_chuong_<loại> (g nền, b sau, r0/r1/f0/f1 rào), neo ở điểm lưới.

const L = preload("res://logic/lang.gd")
const BongNuoc = preload("res://logic/bong_nuoc.gd")
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
	tiles.material = ShaderMaterial.new()   # nen.gdshader: nền lát loang vào nhau theo từng điểm ảnh
	tiles.material.shader = load("res://nen.gdshader")
	F.main._nm(tiles.material)
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
		s.modulate = Color(1, 1, F.sway_ph(foot), 254.0 / 255.0)   # sprite_sway: cây đung đưa quanh chân, pha cố định ở kênh xanh dương
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
	var fr: Array = frames_for(id, seed)
	if fr.is_empty() or not _op_has(b, String(fr[0])):   # làng có sẵn khung (n/op) thì khỏi tải gói l/ (không có thì 404, chiếm lượt tải)
		F.P.load_bundle(b)
	var fx: bool = p.get("fx", false)
	var sw: bool = p.get("sw", false)
	var wat: bool = str(LG.Pi.get(id, {}).get("water", "")) != ""   # sen, súng, thuyền, cầu, bến: có bóng dưới nước
	var i := 0
	for k in fr:
		var s := _spr(b, String(k), foot, sw, fx)
		if into_ghost:
			s.position = Vector2.ZERO
			ghost.add_child(s)
		else:
			_add(s, dk + 0.01 * i)
			if wat:
				BongNuoc.add(F.main, s, foot)
		i += 1
	if p.has("flag"):
		var fl: Dictionary = p.flag
		if not _op_has(String(fl.b), "co_d00"):
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

var cache := {}          # khóa món -> [[node của món] ...] lần dựng trước
var obj_nodes := {}      # chỉ số món (g.objs) -> các node đang vẽ món đó (ui_bd nhấc lên khi dời)

func _reuse(old: Dictionary, key: String) -> bool:   # còn node của khóa này từ lần trước thì lấy lại
	var L = old.get(key)
	if L == null or L.is_empty():
		return false
	var grp: Array = L.pop_back()
	if L.is_empty():
		old.erase(key)
	nodes.append_array(grp)
	_keep(key, grp)
	return true

func _keep(key: String, grp: Array) -> void:
	if not cache.has(key):
		cache[key] = []
	cache[key].append(grp)

func _item(old: Dictionary, id: String, seed: int, foot: Vector2, dk: float, sea: String, fp := Rect2()) -> void:
	var key := id + "|" + str(seed) + "|" + str(foot) + "|" + str(dk) + "|" + sea
	if _reuse(old, key):
		return
	var n0 := nodes.size()
	_obj(id, seed, foot, dk)
	var grp := nodes.slice(n0)
	if fp.size.x * fp.size.y > 1.0:   # món nhiều ô: ô chiếm (main.zorder xếp đồ quanh nó theo ô, không theo tâm)
		for s in grp:
			s.set_meta("fp", fp)
	_keep(key, grp)

func sync() -> void:
	var O: Array = LG.objs()
	var fell: Dictionary = _fell()
	var sig := str(LG.ver) + "|" + str(F.G.season()) + "|" + str(O.size()) + "|" + str(LG.G.g.mv.size()) + "|" + str(LG.G.g.get("land")) + "|" + str(fell.keys())
	for o in O:
		if LG.C.Ei.has(o.id):
			sig += str(ft_seed(o))
	if sig == _sig:
		return
	_sig = sig
	# dựng lại theo khóa từng món (id, dáng, chỗ, lớp vẽ, mùa): món không đổi giữ nguyên node, chỉ món đổi (cây chín / hái
	# trái, đặt, dời, bỏ) mới tạo lại. Gỡ hết rồi tạo lại cả làng mỗi lần hái trái / tưới cây làm cả làng khựng một cái.
	var old := cache
	cache = {}
	nodes = []
	var sea := str(F.G.season())
	obj_nodes = {}
	for n in O.size():   # đang dời cũng vẽ như thường: ui_bd nhấc chính các node này lên, như xưởng / chuồng
		var o: Dictionary = O[n]
		var t = LG.Pi.get(o.id)
		if t == null or o.id == "pond" or (o.has("bk") and fell.has("o" + str(o.bk))):   # cây mình đang cháy / ngã / mọc lại: FellNode vẽ thay
			continue
		var cx: float = float(o.gx) + float(t.fw) / 2.0
		var cy: float = float(o.gy) + float(t.fd) / 2.0
		var n0 := nodes.size()
		_item(old, String(o.id), ft_seed(o), Vector2(L.en(cx, cy), L.nn(cx, cy)), L.nn(cx, cy) + 0.032 * float(o.gy), sea, Rect2(float(o.gx), float(o.gy), float(t.fw), float(t.fd)))
		obj_nodes[n] = nodes.slice(n0)
	# vật cảnh có sẵn (lang.SO, trừ cây cỏ hoang): vẽ như đồ đặt, không dùng ảnh chụp của nền, nên dời đi là chỗ cũ trống luôn
	for o in LG.SO:
		var sid: String = LG.XV.get(o.id, o.id)
		if o.wild or not PICS.has(sid) or fell.has(o.sk) or not LG.so_shown(o):
			continue
		var cx: float = float(o.gx) + float(o.fw) / 2.0
		var cy: float = float(o.gy) + float(o.fd) / 2.0
		_item(old, sid, ft_seed(o), Vector2(L.en(cx, cy), L.nn(cx, cy)), L.nn(cx, cy) + 0.032 * float(o.gy), sea, Rect2(float(o.gx), float(o.gy), float(o.fw), float(o.fd)))
	for k in LG.G.g.minis:
		var p: PackedStringArray = String(k).split(",")
		var c := int(p[0])
		var f := int(p[1])
		var h := c / 2.0 + 0.25
		var q := f / 2.0 + 0.25
		_item(old, "mini_" + String(LG.G.g.minis[k]), int(floor(F.main.me_hash(c + 7, f + 3) * 4.0)), Vector2(L.en(h, q), L.nn(h, q)), L.nn(h, q), sea)
	for p in LG.C.Di:
		if not LG.pen_built(p) and F.ui.bdp.fmv != p:
			continue
		var g = LG.pen_pos(p)
		var key: String = "pen|" + String(p) + "|" + str(g)
		if _reuse(old, key):
			continue
		var n0 := nodes.size()
		var b: String = "g_congtrinh_chuong_" + p
		if not _op_has(b, "gd"):
			F.P.load_bundle(b)
		var base := Vector2(L.en(g.x, g.y), L.nn(g.x, g.y))
		for e in [["g", -100.0], ["b", 1.15], ["r0", 2.495], ["f0", 2.495], ["r1", 3.495], ["f1", 3.495]]:
			var s := _spr(b, String(e[0]) + "d", base, false)
			if e[0] == "g":
				s.z_index = -5
				F.add_child(s)
				nodes.append(s)
			else:
				s.set_meta("fp", Rect2(g.x, g.y, float(LG.C.mo[p].w), float(LG.C.mo[p].h)))
				_add(s, 968.0 + (g.x + g.y + float(e[1])) * 16.0)
		_keep(key, nodes.slice(n0))
	# món không còn: gỡ khỏi danh sách xếp lớp một lượt rồi bỏ
	var gone := {}
	for key in old:
		for grp in old[key]:
			for s in grp:
				gone[s] = 1
	if not gone.is_empty():
		var keep := []
		for e in F.sortables:
			if not gone.has(e[0]):
				keep.append(e)
		F.sortables.assign(keep)
		for s in gone:
			if is_instance_valid(s):
				s.queue_free()
	flags = nodes.filter(func(s): return s.has_meta("flag"))
	tiles.queue_redraw()
	_pond_sync(O)

var _pbase = null
func _pond_sync(O: Array) -> void:   # ao tự đào -> bên nền dựng nước ao, nối với ao, kênh, suối có sẵn (main.pond_dig)
	if not F.main.has_method("pond_dig"):
		return
	var dug := []
	for o in O:
		if o.id == "pond":
			dug.append([int(o.gx), int(o.gy)])
	if _pbase == null:   # ô nước có sẵn (trừ sông Vàm), ô ruộng: không đổi
		_pbase = {}
		var B: Array = LG.M.B
		var W5: Dictionary = F.G.w_all.WC.W5 if F.G.w_all != null else {}
		for y in range(int(B[2]), int(B[3])):
			for x in range(int(B[0]), int(B[1])):
				if LG.fm(x, y) and not W5.has(LG.fo(x, y)):
					_pbase[str(x) + "," + str(y)] = 1
	var plots := []
	for c in F.G.cells:
		plots.append([int(c.gx), int(c.gy)])
	F.main.pond_dig(dug, _pbase, plots)

func _fell() -> Dictionary:   # cây ngã / cháy sau bão (bao.gd): vật cảnh ở đó thôi vẽ, FellNode vẽ thay
	var tr = LG.G.troi
	if tr == null or tr.get("bao") == null:
		return {}
	var f = tr.bao.wx().get("fell")
	return f if f is Dictionary else {}

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

func _op_has(b: String, k: String) -> bool:   # làng có khung này trong n/op
	if not F.main.has_method("op_box"):
		return false
	var a = F.main.op_box(op_name(b, k))
	return a is Array and a.size() >= 4

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
	# ban đêm: ảnh ĐÊM của chính khung đó (info.opn: tên ảnh đêm + chỗ lệch so với ảnh ngày), vẽ không qua công thức đêm
	var nn = F.main.info.get("opn", {}).get(nm) if F.main.night_cur == 1 else null
	var tk := ("opn:" if nn != null else "op:") + nm
	if s.get_meta("tk", "") == tk and s.texture != null:
		return true
	var tx: Texture2D = F.main.op_pic(String(nn[0]) if nn != null else nm)
	if tx == null:
		return true
	var bx := [float(a[0]), float(a[1]), float(a[2]), float(a[3])]
	if nn != null:
		bx = [float(a[0]) + float(nn[1]), float(a[1]) + float(nn[2]), float(nn[3]), float(nn[4])]
	var sc := float(bx[2]) / float(tx.get_width())
	var ox := float(bx[0])
	if s.flip_h:
		ox = -(ox + float(bx[2]))
	var off := Vector2(ox, float(bx[1]))
	if s.has_meta("fd"):
		off += s.get_meta("fd")
	s.texture = tx
	s.scale = Vector2(sc, sc)
	s.offset = off / sc
	s.material = F.main.night_raw if nn != null else F.main.night_mat
	s.set_meta("tk", tk)
	return true

func _tex(s: Sprite2D, scr: float) -> void:
	if _op(s):
		return
	var b: String = s.get_meta("b")
	var k: String = s.get_meta("k")
	var night := false
	if F.main.night_cur == 1 and k.begins_with("d") and F.P.meta(b).has("n" + k.substr(1)):   # ban đêm: ảnh đêm của gói
		k = "n" + k.substr(1)
		night = true
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
	s.material = F.main.night_raw if night else F.main.night_mat
	s.set_meta("tk", tk if tx == F.P.tex(b, tk) else "")

func show_ghost(id: String, seed: int, gx: int, gy: int, bad: bool) -> void:   # kj: món đang đặt (sai chỗ ửng đỏ)
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
	ghost.set_meta("p0", ghost.position)   # chỗ chân; ui_bd nhấc món lên từ đây
	ghost.modulate = Color(1, 0.55, 0.5, 0.75) if bad else Color(1, 1, 1, 0.92)   # sai chỗ: ửng đỏ
	ghost.visible = true

func hide_ghost() -> void:
	ghost.visible = false

func top_of(o: Dictionary) -> float:   # Jo(...).y: đỉnh hình món o tính từ chân (âm là phía trên)
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

func obj_rect(n: int) -> Rect2:   # khung hình món n (toạ độ làng, gộp mọi lớp) để loại nhanh trước khi xét điểm ảnh
	var o: Dictionary = LG.objs()[n]
	var t = LG.Pi.get(o.id)
	var p = PICS.get(o.id)
	if t == null or p == null:
		return Rect2()
	var cx: float = float(o.gx) + float(t.fw) / 2.0
	var cy: float = float(o.gy) + float(t.fd) / 2.0
	var foot := Vector2(L.en(cx, cy), L.nn(cx, cy))
	var b := String(p.b)
	var m: Dictionary = F.P.meta(b)
	var r := Rect2()
	for k in frames_for(String(o.id), ft_seed(o)):
		var a = m.get(k)
		if a == null and F.main.has_method("op_box"):
			a = F.main.op_box(op_name(b, String(k)))
		if a is Array and a.size() >= 4:
			var ox := float(a[0])
			if p.get("fx", false):
				ox = -(ox + float(a[2]))
			var q := Rect2(foot.x + ox, foot.y + float(a[1]), float(a[2]), float(a[3]))
			r = q if r.size == Vector2.ZERO else r.merge(q)
	return r

func pick_obj(n: int, w: Vector2) -> bool:   # chạm trúng món n: điểm ảnh của chính các hình đang vẽ món đó (main.node_hit)
	var h: int = F.main.nodes_hit(obj_nodes.get(n, []), w)
	if h >= 0:
		return h == 1
	var r := obj_rect(n)   # hình chưa tải xong: khung thu 15%
	return r.grow(-r.size.x * 0.15).has_point(w)

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
	# nền đất người chơi lát (g.gt) + hình thẻ đường / nền của Xây dựng: vẽ bằng ĐÚNG ảnh mặt đường của làng (n/dg2_*, main.road_tex),
	# cùng cỡ lặp như đường trên nền (dg2 1024 px = 112 đơn vị, sỏi 96): ô nền giáp nhau liền một mặt, không vẽ bằng code
	var v
	const GRASS := ["#99cc56", "#92c752"]   # Le.grassA, grassB (ô "trả cỏ" của thẻ)
	var cv: CanvasItem = null   # TileIcon vẽ nhờ lên Control của nó

	func _cv() -> CanvasItem:
		return cv if cv != null else self

	func dia(a: float, n: float, c: Color) -> void:   # xe([a,n-.6,a+32.8,n+16,a,n+32.6,a-32.8,n+16])
		_cv().draw_colored_polygon(PackedVector2Array([Vector2(a, n - 0.6), Vector2(a + 32.8, n + 16), Vector2(a, n + 32.6), Vector2(a - 32.8, n + 16)]), c)

	func tex_dia(tx: String, a: float, n: float) -> void:   # một ô bằng ảnh mặt đường tx (dat / do / cat / soi / da / gach)
		var t: Texture2D = v.F.main.road_tex.get(tx)
		var P := PackedVector2Array([Vector2(a, n - 0.6), Vector2(a + 32.8, n + 16), Vector2(a, n + 32.6), Vector2(a - 32.8, n + 16)])
		if t == null:   # ảnh chưa về
			_cv().draw_colored_polygon(P, Color("#b8a27a"))
			return
		var sc := 96.0 if tx == "soi" else 112.0
		var U := PackedVector2Array()
		for q in P:
			U.append(q / sc)
		_cv().texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_cv().draw_colored_polygon(P, Color.WHITE, U, t)

	func _draw() -> void:
		var LG = v.LG
		var g: Dictionary = LG.G.g
		var M = v.F.main
		# đường người chơi: bên nền vẽ bằng DUONG (ảnh dg2 9 px + viền + cỏ mép) như web
		var dead: Dictionary = LG.dead_roads()
		var sig := JSON.stringify([g.road, g.unroad, dead])
		if sig != _road_sig:
			_road_sig = sig
			var rm := []   # đường gốc bỏ (gỡ, đường cụt nhà đã dời): trừ ô người chơi đặt đường lại lên
			for k in g.unroad.keys() + dead.keys():
				if not g.road.has(k):
					rm.append(k)
			M.road_set(g.road.duplicate(), rm)
		_nen_all(g.gt)

	var _road_sig := ""
	func _road(t: String, a: float, n: float, _e: int, _r: int) -> void:   # hình thẻ đường: ô bằng ảnh mặt đường đó
		tex_dia(t, a, n)

	# NỀN LÁT (bản 225): cả vùng nền vẽ một lần bằng nen.gdshader: bản đồ ô (ảnh nhỏ, mỗi điểm = một ô: lớp ảnh + 1) + ảnh mặt
	# đường của nền làng (uRA); độ loang tính theo từng điểm ảnh nên giáp loại khác / giáp cỏ / góc ngã tư đều mềm như nhau.
	const LAYER := {"dat": 1, "do": 2, "cat": 3, "soi": 4}
	var _map_sig := ""
	var _poly := PackedVector2Array()

	func _nen_all(gt: Dictionary) -> void:
		var mat: ShaderMaterial = material
		if mat.get_shader_parameter("uRA") == null:
			var gm = v.F.main.ground.material if v.F.main.ground != null else null
			var ra = gm.get_shader_parameter("uRA") if gm != null else null
			if ra == null:   # ảnh mặt đường chưa về: vẽ lại sau
				get_tree().create_timer(0.5).timeout.connect(queue_redraw)
				return
			mat.set_shader_parameter("uRA", ra)
		if gt.is_empty():
			return
		var sig := str(gt.size()) + str(gt.hash())
		if sig != _map_sig:
			_map_sig = sig
			var x0 := 1 << 20
			var y0 := 1 << 20
			var x1 := -(1 << 20)
			var y1 := -(1 << 20)
			for k in gt:
				var p: PackedStringArray = String(k).split(",")
				x0 = mini(x0, int(p[0]))
				y0 = mini(y0, int(p[1]))
				x1 = maxi(x1, int(p[0]))
				y1 = maxi(y1, int(p[1]))
			var im := Image.create(x1 - x0 + 1, y1 - y0 + 1, false, Image.FORMAT_R8)
			for k in gt:
				var p: PackedStringArray = String(k).split(",")
				var u = v.LG.ug.get(String(gt[k]))
				var l: int = LAYER.get(String(u.get("tx", "")), 0) if u != null else 0
				im.set_pixel(int(p[0]) - x0, int(p[1]) - y0, Color8(l, 0, 0))
			mat.set_shader_parameter("uMap", ImageTexture.create_from_image(im))
			mat.set_shader_parameter("uBox", Vector4(x0, y0, x1 - x0 + 1, y1 - y0 + 1))
			var c := func(x: float, y: float) -> Vector2: return Vector2(4268.0 + (x - y) * 32.0, 968.0 + (x + y) * 16.0)
			_poly = PackedVector2Array([c.call(x0 - 1, y0 - 1), c.call(x1 + 2, y0 - 1), c.call(x1 + 2, y1 + 2), c.call(x0 - 1, y1 + 2)])
		draw_colored_polygon(_poly, Color.WHITE)

	func _nen_at(t: String, a: float, n: float, _e: int, _r: int, _edges: bool) -> void:   # ô nền loại t (bd_cat Yz, ảnh mặt đường .tx)
		var u = v.LG.ug.get(t)
		if u == null or not u.has("tx"):
			return
		tex_dia(String(u.tx), a, n)
