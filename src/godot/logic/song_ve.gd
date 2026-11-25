extends RefCounted
# SÔNG VÀM SỐNG ĐỘNG (bản 176): vẽ + chạm cho các thứ trên sông / mặt nước, bằng bộ ảnh 9 px ui/img/ts (hinh/thuysinh):
#   - bụi ven sông mùa nước nổi (w_cho.Vb): điên điển, kèo nèo, súng ma ở mép nước hai bờ; chạm đi tới hái
#   - lục bình + bèo trôi chung từng cụm (to nhỏ khác nhau), rau muống trôi riêng, theo lòng sông (sgeo), luôn xuôi dòng (nước
#     lớn trôi chậm, nước nổi trôi nhanh); chạm vớt (khúc sông đã mua); tới cuối sông thì mờ đi, cụm mới trôi vô từ đầu trên
#   - bãi bùn lúc nước ròng (w_xuong.v6): mảng bùn ở mép nước, có món để mò; chạm đi tới mò
#   - (bản 541) lờ tre / lọp lươn / giăng câu đang đặt (g.lo.set, w_ca): vẽ nét ở ô nước; có cá thì gợn nước + chấm vàng;
#     (bản 546) chạm -> vòng nút Thăm / Gỡ (rm_don); đàn vịt bơi trong vùng nước, chạm -> ra bờ cho ăn / lấy trứng;
#     đang chọn chỗ đặt lờ / thả vịt (w_ca.yf) thì tô xanh ô đặt được; mèo mướp ngồi trước Kho; diều đang thả bay trên đầu
#   - cá búng mặt nước: sông, kênh, ao trên màn thỉnh thoảng có cá búng lên, nước bắn, vòng gợn loang (mưa nhiều, đêm ít)

const BongNuoc = preload("res://logic/bong_nuoc.gd")

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
		_lo_sync()
		_vit_sync()
		_meo_sync()
		_sbub_sync()
	if meo != null and is_instance_valid(meo):
		meo.hap = float(G.w_all.WCA.qi_hap)
	_kite_step()
	_sbub_step()
	_pick_sync()
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

# ------------------------------------------------------------------ (bản 541) lờ, lọp, giăng câu đang đặt
var lo := {}   # key -> LoNode
func _lo_sync() -> void:
	var W = G.w_all.WCA
	var keep := {}
	for a in W.t1()["set"]:
		var k: String = W.bk(a)
		keep[k] = 1
		var n = lo.get(k)
		if n == null or not is_instance_valid(n):
			n = LoNode.new()
			n.seed = float(int(a.gx) * 13 + int(a.gy) * 7)
			n.position = Vector2(F.en(float(a.gx) + 0.5, float(a.gy) + 0.5), F.nn(float(a.gx) + 0.5, float(a.gy) + 0.5))
			_sorted(n)
			lo[k] = n
		var lv: int = W.lo_lv(String(a.t))
		var fr: String = ("n" if G.night else "d") + String(a.t) + (str(lv) if lv > 1 else "")
		if n.fr != fr:   # đổi cấp / ngày đêm thì đổi hình
			var A: Dictionary = atlas("bay").get(fr, {})
			n.fr = fr
			n.tx = tex("bay", fr) if not A.is_empty() else null
			n.rc = Rect2(float(A.get("ox", 0)), float(A.get("oy", 0)), float(A.get("gw", 0)), float(A.get("gh", 0)))
	for k in lo.keys():
		if not keep.has(k):
			_unsort(lo[k])
			lo.erase(k)

const LO_K := 1.8   # (bản 554) lờ / lọp / giăng trên nước phóng to 1,8 (cỡ gốc atlas nhỏ quá so với cây cối)
class LoNode extends Node2D:   # (bản 553) hình 3D dựng sẵn ui/img/ts/bay (4 cấp, ngày / đêm), gốc = chỗ đặt chân giữa món ngay mặt nước
	var tx: Texture2D = null
	var rc := Rect2()
	var fr := ""
	var seed := 0.0
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		if tx != null:
			draw_texture_rect(tx, Rect2(rc.position * LO_K + Vector2(0, sin(t * 1.6 + seed) * .5), rc.size * LO_K), false)

# hình vịt / mèo vẽ bằng nét (chưa có ảnh) cho thẻ Xây dựng: c = giữa ô, s = tỉ lệ
static func gear(ci: CanvasItem, kind: String, c0: Vector2, s: float, t := 0.0, _seed := 0.0, night := false) -> void:
	match kind:
		"meo":   # thẻ Xây dựng
			cat(ci, c0 + Vector2(0, 6) * s, s * 1.5, 0.0, night)
		"vit":   # 3 con vịt cho thẻ
			for q in [[Vector2(-8, 2), 1.0], [Vector2(6, -2), -1.0], [Vector2(9, 5), 1.0]]:
				duck(ci, c0 + q[0] * s, s, q[1], t + q[0].x, night)

static func duck(ci: CanvasItem, p: Vector2, s: float, dir: float, t := 0.0, night := false) -> void:   # vịt bơi: thân trắng, đầu, mỏ cam, gợn nước
	var dk := 0.62 if night else 1.0
	var w := Color(.97 * dk, .96 * dk, .92 * dk)
	var sh := Color(.78 * dk, .76 * dk, .7 * dk)
	var bob := sin(t * 2.4) * .4 * s
	ci.draw_arc(p + Vector2(0, 1.2 * s), 5.5 * s, 0, TAU, 18, Color(1, 1, 1, .3 * dk), .7 * s, true)
	var B := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		B.append(p + Vector2(cos(a) * 4.2 * s, sin(a) * 2.2 * s + bob - 1.0 * s))
	ci.draw_colored_polygon(B, sh)
	var B2 := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		B2.append(p + Vector2(cos(a) * 3.8 * s, sin(a) * 1.8 * s + bob - 1.4 * s))
	ci.draw_colored_polygon(B2, w)
	ci.draw_line(p + Vector2(-3.6 * dir, -1.6) * s + Vector2(0, bob), p + Vector2(-5.0 * dir, -3.0) * s + Vector2(0, bob), w, 1.2 * s, true)   # đuôi
	var h := p + Vector2(3.0 * dir, -4.4) * s + Vector2(0, bob)
	ci.draw_line(p + Vector2(2.4 * dir, -2.0) * s + Vector2(0, bob), h, w, 1.8 * s, true)   # cổ
	ci.draw_circle(h, 1.6 * s, w)
	ci.draw_line(h + Vector2(1.2 * dir, .2) * s, h + Vector2(3.0 * dir, .5) * s, Color(.95 * dk, .55 * dk, .1 * dk), 1.0 * s, true)   # mỏ
	ci.draw_circle(h + Vector2(.5 * dir, -.4) * s, .35 * s, Color(.1, .1, .1))

# ------------------------------------------------------------------ (bản 546) đàn vịt thả nước (g.pet.vit, w_ca: w2 vùng nước, xx chạm)
var vit: VitNode = null
func _vit_sync() -> void:
	var W = G.w_all.WCA
	var v: Dictionary = W.cc().vit
	var z = W.w2("vit") if int(v.n) > 0 else null
	if z == null:
		if vit != null:
			_unsort(vit)
			vit = null
		return
	if vit == null or not is_instance_valid(vit):
		vit = VitNode.new()
		vit.F = F
		vit.df = Callable(get_script(), "duck")
		_sorted(vit)
	vit.zone = z
	vit.n = mini(8, int(v.n))
	vit.egg = int(v.e)
	vit.night = G.night
	var c: Vector2 = Vector2(F.en(float(z.c[0]), float(z.c[1])), F.nn(float(z.c[0]), float(z.c[1])))
	if vit.position != c:
		vit.position = c

class VitNode extends Node2D:   # gốc = tâm vùng nước; vịt bơi lòng vòng trong các ô của vùng
	var F
	var zone := {}
	var n := 0
	var egg := 0
	var night := false
	var t := 0.0
	var D := []   # {p (đơn vị ô), to, dir}
	var df := Callable()   # song_ve.duck
	func _tile_pt() -> Vector2:
		var T: Array = zone.get("t", [])
		if T.is_empty():
			return Vector2(zone.c[0], zone.c[1])
		var q: Array = T[randi() % T.size()]
		return Vector2(float(q[0]) + randf_range(.25, .75), float(q[1]) + randf_range(.25, .75))
	func _process(dt: float) -> void:
		t += dt
		while D.size() < n:
			var p := _tile_pt()
			D.append({"p": p, "to": _tile_pt(), "dir": 1.0})
		while D.size() > n:
			D.pop_back()
		for d in D:
			var v: Vector2 = d.to - d.p
			if v.length() < .05:
				d.to = _tile_pt()
			else:
				var m := v.normalized() * minf(v.length(), dt * .18)
				d.p += m
				var sx: float = m.x - m.y   # en(x, y) tăng theo x - y
				if absf(sx) > .001:
					d.dir = signf(sx)
		queue_redraw()
	func pts() -> Array:   # chỗ từng con (toạ độ làng)
		var o := []
		for d in D:
			o.append(Vector2(F.en(d.p.x, d.p.y), F.nn(d.p.x, d.p.y)))
		return o
	func _draw() -> void:
		var i := 0
		for q in pts():
			df.call(self, q - position, 1.4, float(D[i].dir), t + i * 1.7, night)
			i += 1


# ------------------------------------------------------------------ (bản 546) mèo mướp (g.pet.meo, w_ca: gq chạm, wq quà sáng): ngồi trước Kho
var meo: MeoNode = null
func _meo_pos() -> Variant:   # trước hiên Kho hàng (món "kho" trong làng), không có thì trước cửa nhà
	var L = G.lang
	for o in L.objs():
		if String(o.id) == "kho" or String(o.id) == "kho2":
			var tp: Dictionary = L.Pi[o.id]
			return Vector2(float(o.gx) + float(tp.fw) * .5 + .9, float(o.gy) + float(tp.fd) + .35)
	return Vector2(5.0, 6.7)   # không có Kho hàng: trước cửa nhà (chỗ về ngủ 4,6)
func _meo_sync() -> void:
	var m: Dictionary = G.w_all.WCA.cc().meo
	var p = _meo_pos() if G.w_all.WCA._tr(m.get("has")) else null
	if p == null:
		if meo != null:
			_unsort(meo)
			meo = null
		return
	if meo == null or not is_instance_valid(meo):
		meo = MeoNode.new()
		meo.cf = Callable(get_script(), "cat")
		_sorted(meo)
	var q := Vector2(F.en(p.x, p.y), F.nn(p.x, p.y))
	if meo.position != q:
		meo.position = q
	meo.tl = p
	meo.hungry = int(m.get("fd", -1)) != int(G.w_all.WCA._vr())
	meo.night = G.night
	meo.hap = float(G.w_all.WCA.qi_hap)

class MeoNode extends Node2D:   # mèo mướp ngồi, đuôi ve vẩy; đói thì kêu (bong bóng cá), vui thì tim
	var tl := Vector2.ZERO
	var hungry := false
	var night := false
	var hap := 0.0
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	var cf := Callable()   # song_ve.cat
	func _draw() -> void:
		cf.call(self, Vector2.ZERO, 1.6, t, night, hap)

static func cat(ci: CanvasItem, p0: Vector2, s: float, t := 0.0, night := false, hap := 0.0) -> void:   # mèo ngồi (gốc = chân)
	ci.draw_set_transform(p0, 0.0, Vector2(s, s))
	var dk := 0.62 if night else 1.0
	var o := Color(.92 * dk, .6 * dk, .26 * dk)
	var o2 := Color(.74 * dk, .42 * dk, .14 * dk)
	var w := Color(.98 * dk, .94 * dk, .86 * dk)
	var B := PackedVector2Array()   # bóng
	for i in 14:
		var a := TAU * i / 14.0
		B.append(Vector2(cos(a) * 6.0, sin(a) * 2.2 + .5))
	ci.draw_colored_polygon(B, Color(0, 0, 0, .18))
	var sw := sin(t * 2.2) * .5   # đuôi
	ci.draw_polyline(PackedVector2Array([Vector2(3.5, -1.5), Vector2(7.0, -3.0 + sw), Vector2(8.0 + sw, -7.0 + sw * 2.0)]), o2, 1.6, true)
	var Bd := PackedVector2Array()   # thân ngồi
	for i in 16:
		var a := TAU * i / 16.0
		Bd.append(Vector2(cos(a) * 4.4, sin(a) * 4.6 - 4.4))
	ci.draw_colored_polygon(Bd, o)
	for k in 3:   # vằn
		ci.draw_line(Vector2(-3.4 + k * 0.4, -6.5 + k * 2.0), Vector2(-1.2 + k * 0.4, -6.0 + k * 2.0), o2, .8, true)
	ci.draw_circle(Vector2(-.6, -3.0), 2.2, w)   # ức trắng
	var h := Vector2(-1.0, -10.2 + sin(t * 1.3) * .15)   # đầu + tai
	ci.draw_colored_polygon(PackedVector2Array([h + Vector2(-3.2, -1.0), h + Vector2(-2.6, -4.6), h + Vector2(-.6, -2.4)]), o2)
	ci.draw_colored_polygon(PackedVector2Array([h + Vector2(3.2, -1.0), h + Vector2(2.6, -4.6), h + Vector2(.6, -2.4)]), o2)
	ci.draw_circle(h, 3.3, o)
	var blink := fmod(t, 3.7) < .15
	for ex in [-1.2, 1.2]:
		if blink:
			ci.draw_line(h + Vector2(ex - .6, -.3), h + Vector2(ex + .6, -.3), Color(.2, .15, .1), .6, true)
		else:
			ci.draw_circle(h + Vector2(ex, -.4), .55, Color(.15, .3, .1))
	ci.draw_circle(h + Vector2(0, .9), .35, Color(.9, .45, .45))
	if hap > 0.0:   # vừa cho ăn / vuốt ve: tim bay lên
		var hy := -18.0 - (3.0 - hap) * 4.0
		ci.draw_circle(Vector2(-1.2, hy), 1.6, Color(.95, .35, .4, minf(1.0, hap)))
		ci.draw_circle(Vector2(1.2, hy), 1.6, Color(.95, .35, .4, minf(1.0, hap)))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-2.7, hy + .4), Vector2(2.7, hy + .4), Vector2(0, hy + 3.4)]), Color(.95, .35, .4, minf(1.0, hap)))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ------------------------------------------------------------------ (bản 546) diều đang thả (g.dieu.on): bay trên đầu nhân vật, dây xuống tay
var kite: KiteNode = null
func _kite_step() -> void:
	var W = G.w_all.WCA
	var t: Dictionary = W.fh()
	if not (W._tr(t.get("on")) and W._tr(t.get("cur"))):
		if kite != null:
			kite.queue_free()
			kite = null
		return
	if kite == null or not is_instance_valid(kite):
		kite = KiteNode.new()
		kite.z_index = 50   # trên cây cối
		F.add_child(kite)
	for e in W.k4:
		if e.id == t.cur:
			kite.c1 = Color(String(e.c1))
			kite.c2 = Color(String(e.c2))
			kite.kind = String(e.id)
	var pp := Vector2(F.en(G.ppos.x, G.ppos.y), F.nn(G.ppos.x, G.ppos.y))
	kite.position = pp
	kite.night = G.night

class KiteNode extends Node2D:   # gốc = chân nhân vật
	var c1 := Color.RED
	var c2 := Color.YELLOW
	var kind := "sao"
	var night := false
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		var hand := Vector2(3, -16)
		var k := Vector2(-70 + sin(t * .7) * 8.0, -150 + sin(t * 1.1) * 6.0)
		var M := PackedVector2Array()   # dây võng
		for i in 13:
			var f := i / 12.0
			M.append(hand.lerp(k, f) + Vector2(0, sin(f * PI) * 10.0))
		draw_polyline(M, Color(1, 1, 1, .7), .8, true)
		var r := sin(t * 1.3) * .12
		var X := Transform2D(r, k)
		var dk := .7 if night else 1.0
		var A := c1 * dk
		var B := c2 * dk
		A.a = 1.0
		B.a = 1.0
		if kind == "en":   # cánh én
			draw_colored_polygon(PackedVector2Array([X * Vector2(0, -6), X * Vector2(-18, 2), X * Vector2(-6, 2), X * Vector2(0, 10), X * Vector2(6, 2), X * Vector2(18, 2)]), A)
			draw_colored_polygon(PackedVector2Array([X * Vector2(0, -6), X * Vector2(-4, 2), X * Vector2(0, 8), X * Vector2(4, 2)]), B)
		elif kind == "ca":   # cá chép: thân bầu + đuôi dài
			var P := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				P.append(X * Vector2(cos(a) * 7.0, sin(a) * 11.0))
			draw_colored_polygon(P, A)
			draw_circle(X * Vector2(-2.5, -5), 1.5, B)
			for i in 3:
				draw_line(X * Vector2(-3 + i * 3, 9), X * Vector2(-6 + i * 3 + sin(t * 3 + i) * 3, 24 + i * 2), B, 1.6, true)
		else:   # diều sáo: hình thoi, 2 màu, ống sáo ngang
			draw_colored_polygon(PackedVector2Array([X * Vector2(0, -14), X * Vector2(-10, 0), X * Vector2(0, 16)]), A)
			draw_colored_polygon(PackedVector2Array([X * Vector2(0, -14), X * Vector2(10, 0), X * Vector2(0, 16)]), B)
			draw_line(X * Vector2(-12, -2), X * Vector2(12, -2), Color(.55, .4, .2), 1.2, true)
		var T := PackedVector2Array()   # đuôi
		for i in 10:
			T.append(X * Vector2(sin(t * 3.0 + i * .7) * 3.0, 16 + i * 3.0))
		draw_polyline(T, B, 1.2, true)

# ------------------------------------------------------------------ (bản 548) BONG BÓNG CHUNG (farm.Bubble, như ruộng chín): lờ có cá
# (hình con chủ lực: lờ cá rô, lọp lươn, giăng cá lóc), vịt có trứng (trứng vịt), mèo đói (cá rô). Chạm bong bóng = làm liền.
const BUB_ID := {"lo": "ca_ro", "lop": "luon", "giang": "ca_loc"}
var sbubs := {}   # khoá -> [Bubble, chỗ gốc, việc {type, k}]
func _sbub_sync() -> void:
	var W = G.w_all.WCA
	var want := {}
	var off: bool = F.ui.bdp == null or String(F.ui.bdp.mode) == "off"
	if off:
		for a in W.t1()["set"]:
			if W.w4(a):
				var k: String = W.bk(a)
				want["l:" + k] = [String(BUB_ID.get(String(a.t), "ca_ro")), Vector2(F.en(float(a.gx) + .5, float(a.gy) + .5), F.nn(float(a.gx) + .5, float(a.gy) + .5) - 50.0), {"type": "lob", "k": k}]
		if vit != null and is_instance_valid(vit) and vit.egg > 0:
			want["vit"] = ["trung_vit", vit.position + Vector2(0, -30), {"type": "vit", "k": "vit"}]
		if meo != null and is_instance_valid(meo) and meo.hungry:
			want["meo"] = ["ca_ro", meo.position + Vector2(0, -38), {"type": "meo", "k": "meo"}]
		if G.lang != null:   # (11-25) lò gạch có gạch chín: bong bóng viên gạch, chạm là ra lấy
			for o in G.lang.objs():
				if o is Dictionary and (o.get("id") == "logach" or o.get("id") == "logach2"):
					var gk: String = G.w_all.WX.lg_key(o)
					if G.w_all.WX.lg_left(gk) == 0.0:
						var cx: float = float(o.gx) + float(o.get("fw", 2)) / 2.0
						var cy: float = float(o.gy) + float(o.get("fd", 2)) / 2.0
						want["g:" + gk] = ["gach", Vector2(F.en(cx, cy), F.nn(cx, cy) - 92.0), {"type": "lgb", "k": gk, "x": cx, "y": float(o.gy) + float(o.get("fd", 2)) + 0.3}]
	for k in sbubs.keys():
		if not want.has(k):
			sbubs[k][0].queue_free()
			sbubs.erase(k)
	for k in want:
		var e = sbubs.get(k)
		if e == null:
			var b = F.get_script().Bubble.new()
			b.fnt = F.fnt
			b.farm = F
			b.z_index = 40
			F.add_child(b)
			e = [b, Vector2.ZERO, {}]
			sbubs[k] = e
		var bb = e[0]
		bb.kind = "ripe"
		bb.id = want[k][0]
		bb.text = ""
		bb.can = true
		bb.visible = true
		e[1] = want[k][1]
		e[2] = want[k][2]
		F._bub_sig(bb)

func _sbub_step() -> void:
	var tt := Time.get_ticks_msec() / 1000.0
	var still: bool = G.motion_off()
	for k in sbubs:
		var e: Array = sbubs[k]
		var b = e[0]
		b.position = e[1] if still else e[1] + Vector2(0.0, sin(tt * 3.0 + e[1].x) * 1.2)
		if not still:
			F._bub_set(b, tt)

func bub_pick(w: Vector2, z: float):   # farm._pk_bubs: chạm trúng bong bóng -> việc
	for k in sbubs:
		var b = sbubs[k][0]
		if b.visible and b.position.distance_to(w) <= 10.0 * b.k + 3.0 / z:
			return sbubs[k][2]
	return null

# ------------------------------------------------------------------ (bản 546) chọn chỗ đặt lờ / thả vịt: tô ô xanh
var pk: PickNode = null
func _pick_sync() -> void:
	var W = G.w_all.WCA
	var y = W.yf
	var want := y != null and (String(y.get("lo", "")) != "" or String(y.k) == "vit")
	if not want:
		if pk != null:
			pk.queue_free()
			pk = null
		return
	var key := str(y.get("lo", "")) + "|" + str(y.k) + "|" + str(int(G.ppos.x)) + "," + str(int(G.ppos.y)) + "|" + str(W._ver())
	if pk != null and pk.key == key:
		return
	if pk == null:
		pk = PickNode.new()
		pk.z_index = -5
		F.add_child(pk)
	pk.key = key
	var T := []
	var lo := String(y.get("lo", ""))
	var cx := int(G.ppos.x)
	var cy := int(G.ppos.y)
	for x in range(cx - 22, cx + 23):
		for yy in range(cy - 22, cy + 23):
			if not W._p0(x, yy) or not W._ci(W._fo(x, yy)):
				continue
			if lo != "" and W.lo_why(lo, x, yy) != "":
				continue
			var Q := PackedVector2Array()
			for c in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				Q.append(Vector2(F.en(x + c[0], yy + c[1]), F.nn(x + c[0], yy + c[1])))
			T.append(Q)
	pk.T = T
	pk.queue_redraw()

class PickNode extends Node2D:
	var key := ""
	var T := []
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		modulate.a = .75 + sin(t * 3.0) * .2
	func _draw() -> void:
		for Q in T:
			draw_colored_polygon(Q, Color(.45, .9, .35, .32))
			var L: PackedVector2Array = Q.duplicate()
			L.append(Q[0])
			draw_polyline(L, Color(.9, 1, .6, .85), 1.0, true)

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
			BongNuoc.add(F.main, s, "r", 10.0)   # gốc cây chạm nước: 10 px ảnh dưới điểm neo
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

# Dòng sông lấy từ hình học sông Vàm (sgeo: tâm c(x), nửa bề ngang trên hw·k1, dưới hs·k1): cụm trôi theo x, nằm trong lòng sông,
# không cắt lên bờ. Khúc sông x0..x1: các cột có tâm sông là nước, trong làng.
var _xr := []
func _x_range() -> Array:
	if not _xr.is_empty():
		return _xr
	var L = G.lang
	var S = G.w_all.WSG
	if L == null or L.M.is_empty() or S == null:
		return []
	var B: Array = L.M.B
	var lo := 1e9
	var hi := -1e9
	for n in range(int(B[0]), int(B[1])):
		if S.w(float(n), S.c(float(n))):
			lo = minf(lo, n)
			hi = maxf(hi, n)
	if lo < hi:
		_xr = [lo, hi]
	return _xr

func _fl_put(f: Dictionary) -> void:   # đặt node theo vị trí trên dòng sông
	var S = G.w_all.WSG
	var x: float = f.x
	var o: float = f.off
	var y: float = S.c(x) + (o * S.hw(x) if o < 0.0 else o * S.hs(x)) * S.k1(x) * 0.6
	if not S.w(x, y):   # chỗ hẹp / cù lao: vô gần giữa dòng
		y = S.c(x) + (y - S.c(x)) * 0.3
	var tl := Vector2(x, y)
	f.tl = tl
	var bob := sin(float(f.ph)) * 0.6
	f.n.position = Vector2(F.en(tl.x, tl.y), F.nn(tl.x, tl.y) + bob)
	f.e[1] = f.n.position.y
	var R := _x_range()
	var edge := minf(x - float(R[0]), float(R[1]) - x)   # tới đầu sông thì mờ đi
	f.n.modulate.a = clampf(edge / 4.0, 0.0, 1.0) * clampf(float(f.a), 0.0, 1.0)

func _fl_new(kind: String, x: float) -> Dictionary:
	var n := _clump(kind)
	n.position = Vector2(0, -99999)
	var f := {"n": n, "e": _sorted(n), "x": x, "off": randf_range(-1.0, 1.0), "kind": kind, "a": 0.0, "ph": randf() * TAU,
		"v": randf_range(0.18, 0.3) * (0.7 if kind == "rau" else 1.0), "key": "fl" + str(randi())}
	_fl_put(f)
	return f

func _float_step(dt: float) -> void:
	var R := _x_range()
	if R.is_empty():
		return
	if _fl_dn != _dn():   # ngày / đêm: dựng lại cụm bằng ảnh đúng buổi
		_fl_dn = _dn()
		for f in fl:
			_unsort(f.n)
		fl = []
	while fl.size() < N_LB + N_RAU:
		var f := _fl_new("lb" if fl.size() < N_LB else "rau", randf_range(float(R[0]), float(R[1])))
		f.a = 1.0
		fl.append(f)
	# luôn trôi xuôi dòng (về phía +x); nước lớn thì nước dồn lên nên trôi chậm gần như đứng, nước nổi trôi nhanh
	var sk := 1.3 if G.w_all.WR.qs() else (0.25 if G.w_all.WX.FN() else 1.0)
	for i in fl.size():
		var f: Dictionary = fl[i]
		f.ph = float(f.ph) + dt * 1.3
		f.a = minf(1.0, float(f.a) + dt * 0.5)
		f.x = float(f.x) + sk * float(f.v) * dt
		if f.x > float(R[1]):   # trôi khỏi sông: cụm mới từ đầu trên
			_unsort(f.n)
			fl[i] = _fl_new(String(f.kind), float(R[0]))
			continue
		_fl_put(f)

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
	if meo != null and is_instance_valid(meo):   # (bản 546) mèo
		var qm: Vector2 = meo.position
		F._pk_add(L, {"type": "meo", "k": "meo"}, 6, qm.y, func(p: Vector2) -> bool: return absf(p.x - qm.x) < 13.0 and p.y > qm.y - 26.0 and p.y < qm.y + 5.0)
	if vit != null and is_instance_valid(vit):   # (bản 546) đàn vịt
		for q in vit.pts():
			var qv: Vector2 = q
			F._pk_add(L, {"type": "vit", "k": "vit"}, 6, qv.y, func(p: Vector2) -> bool: return absf(p.x - qv.x) < 11.0 and p.y > qv.y - 14.0 and p.y < qv.y + 5.0)
	for k in lo:   # (bản 541) lờ / lọp / giăng
		var nl: Node2D = lo[k]
		if not is_instance_valid(nl):
			continue
		var ql := nl.position
		var kk: String = k
		F._pk_add(L, {"type": "lo", "k": kk}, 6, ql.y, func(p: Vector2) -> bool: return absf(p.x - ql.x) < 30.0 and p.y > ql.y - 40.0 and p.y < ql.y + 14.0)
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
	if h.type == "lob":   # (bản 548) chạm bong bóng có cá: ra thăm liền
		var ns = G.w_all.WCAU.ext.get("Ns")
		if ns is Callable and ns.is_valid():
			ns.call({"type": "lo", "key": k})
		return
	if h.type == "lgb":   # (11-25) chạm bong bóng gạch chín: ra lò lấy gạch
		var gk := String(h.k)
		G.w_all._job("lgx" + gk, [float(h.x), float(h.y)], 0.5, func() -> bool: return G.w_all.WX.lg_take(gk))
		return
	if h.type == "lo":   # (bản 546) vòng nút Thăm / Gỡ (rm_don)
		F.ui.dn_open({"lo": k})
		return
	if h.type == "meo":   # (bản 546) tới cho mèo ăn / vuốt ve (w_ca.gq)
		if meo != null and is_instance_valid(meo):
			var mp: Vector2 = meo.tl + Vector2(.5, .3)
			G.w_all._job("meox", [mp.x, mp.y], 0.5, func() -> bool: return G.w_all.WCA.gq())
		return
	if h.type == "vit":   # (bản 546) ra bờ cho vịt ăn / lấy trứng (w_ca.xx)
		var z = G.w_all.WCA.w2("vit")
		var p = z.bank[0] if z != null and z.bank.size() else null
		if p != null:
			var best: Array = z.bank[0]
			for b in z.bank:
				if Vector2(float(b[0]) - G.ppos.x, float(b[1]) - G.ppos.y).length() < Vector2(float(best[0]) - G.ppos.x, float(best[1]) - G.ppos.y).length():
					best = b
			G.w_all._job("vitx", best, 0.35, func() -> bool: return G.w_all.WCA.xx())
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
					fl[i] = _fl_new(String(f.kind), float(_x_range()[0]))   # trôi xuôi: vô từ đầu trên
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
