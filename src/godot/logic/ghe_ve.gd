extends Node2D
# GHE TRÊN SÔNG (yg bản web): ảnh ghe vẽ sẵn (bản 556: dựng 3D src/tools/cc/moi/ghe3d.py -> src/art/ghe3d -> ui/img/ghe, 6 px mỗi đơn vị làng, cùng 122 tên + ui/snap/ghe.json;
# chợ nổi: đúng góc từng ghe; ghe thương hồ: trục u theo góc sông từng 0,05 rad, trục v), nhấp nhô, lắc nhẹ,
# rồi vẽ thêm phần động: món treo trên đòn gánh của cây sào (offers), bảng tên ghe chợ, câu rao, bảng giờ ghe thương hồ.
# Xuồng qua lại (Eh / jq / HD bản web): tối đa 3 chiếc, 14-30 giây một chiếc, chạy hai chiều trên khúc sông đã mua, mỗi chiều một
# làn (lệch tâm sông ±0,9 ô); ảnh xu_{p|m}{mui}_{góc} vẽ từ yg bản web (pole 0, s ±1; tools/ghe.js).
# Mỗi ghe một node con (Boat) chen vào thứ tự vẽ của làng (farm.sortables).

const Snap = preload("res://ui/snap.gd")
const Css = preload("res://ui/css.gd")
const BongNuoc = preload("res://logic/bong_nuoc.gd")

var farm
var G
var M := {}          # ui/snap/ghe.json: khóa -> [lệch x, lệch y, rộng, cao] (đơn vị làng, tính từ chỗ ghe)
var cho := []        # 4 Boat chợ nổi
var ghe = null       # Boat ghe thương hồ
var xus := []        # xuồng qua lại (Eh bản web): {b, x, y, s, v, lo, hi}
var xu_t := 8.0
var _xu_ms := 0

const C := 1.3       # chiều dài nửa ghe (c của yg)

class Boat extends Node2D:
	var v                # ghe_ve
	var key := ""
	var p := Vector2.ZERO
	var al := 1.0
	var sc := 1.0
	var s := 1.0
	var th := 0.0
	var offers := []     # [{id, done}]
	var tag := ""        # bảng tên (chợ) khi zoom >= .75
	var say := ""
	var say_al := 0.0
	var lbl := ""        # bảng giờ ghe thương hồ
	var lbl_red := false
	var piv: Node2D
	var bubs := []       # bong bóng chung của làng (farm Bubble) treo món đơn hàng
	var spr: Sprite2D
	var top: Node2D
	var tt := 0.0
	func _init(vv) -> void:
		v = vv
		piv = Node2D.new()   # nhấp nhô, lắc quanh chỗ ghe
		add_child(piv)
		spr = Sprite2D.new()
		spr.centered = false
		spr.material = vv.farm.main.night_mat
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		piv.add_child(spr)
		top = Node2D.new()
		top.draw.connect(_top_draw)
		add_child(top)
	func set_key(k: String) -> void:
		if k == key:
			return
		key = k
		var m = v.M.get(k)
		var tex: Texture2D = Css.image("res://ui/img/ghe/" + k + ".webp") if m != null else null
		spr.texture = tex
		if m != null:
			spr.position = Vector2(float(m[0]), float(m[1]))
			spr.scale = Vector2(float(m[2]), float(m[3])) / Vector2(maxf(1, tex.get_width()), maxf(1, tex.get_height())) if tex != null else Vector2.ONE
	func _process(dt: float) -> void:
		tt += dt
		var mo: bool = v.G.motion_off()
		var o := 0.0 if mo else sin(tt * 1.4) * 1.2
		var l := 0.0 if mo else sin(tt * 0.9) * 0.015
		position = Vector2(v.farm.en(p.x, p.y), v.farm.nn(p.x, p.y))
		scale = Vector2(sc, sc)
		spr.modulate.a = al   # modulate: bóng dưới nước mờ theo
		piv.position = Vector2(0, o)
		piv.rotation = l
		top.position = Vector2(0, o)
		top.queue_redraw()
		bub_sync()
	func _x(Y: float, Lt: float, Ft: float) -> Vector2:   # x(): toạ độ trên ghe -> màn hình (hướng, góc sông)
		var u9 := s * Y
		var v9 := Lt
		if th != 0.0:
			var c9 := cos(th)
			var s9 := sin(th)
			var w9 := u9 * c9 - v9 * s9
			v9 = u9 * s9 + v9 * c9
			u9 = w9
		return Vector2((u9 - v9) * 32.0, (u9 + v9) * 16.0 - Ft)
	func _hang(i: int) -> Array:   # món i: [móc, đầu dây] (toạ độ top) — 2 đầu đòn ngang cây bẹo + nút giữa sào
		var F: Vector2 = [_x(C * 0.58, -0.42, 73), _x(C * 0.58, 0.42, 73), _x(C * 0.58, 0, 48)][i % 3]
		var ln := 4.0 if i % 3 == 2 else 6.0
		var fa := 0.0 if v.G.motion_off() else sin(tt * 1.6 + i * 1.3) * 0.12
		return [F, F + Vector2(sin(fa) * ln, cos(fa) * ln)]
	func bub_sync() -> void:   # bong bóng chung (như sbubs song_ve): kind ripe, id món; đã mua thì mờ
		var Fm = v.farm
		while bubs.size() > offers.size():
			bubs.pop_back().queue_free()
		while bubs.size() < offers.size():
			var b = Fm.get_script().Bubble.new()
			b.fnt = Fm.fnt
			b.farm = Fm
			b.z_index = 40
			Fm.add_child(b)
			bubs.append(b)
		var tt0 := Time.get_ticks_msec() / 1000.0
		for i in bubs.size():
			var b = bubs[i]
			b.kind = "ripe"
			b.id = String(offers[i].id)
			b.text = ""
			b.can = true
			b.visible = al > 0.0
			b.modulate.a = al * (0.3 if int(offers[i].get("done", 0)) else 1.0)
			Fm._bub_sig(b)
			b.global_position = top.to_global(_hang(i)[1] + Vector2(0, 10.0 * float(b.k) / sc))
			if not v.G.motion_off():
				Fm._bub_set(b, tt0)
	func _exit_tree() -> void:
		for b in bubs:
			b.queue_free()
		bubs = []
	func _top_draw() -> void:
		var mo: bool = v.G.motion_off()
		for i in mini(offers.size(), bubs.size()):   # dây mảnh từ móc tới bong bóng
			var e: Array = _hang(i)
			top.draw_line(e[0], e[1], Color8(0x6e, 0x52, 0x30, int(200 * al)), 0.3 / sc, true)
		var le: float = v.farm.sign_le()
		var f: Font = v.farm.fnt
		if tag != "":   # Lh: bảng tên trên ghe
			_pill(Vector2(0, -92.0), tag, 9.0, Color(1, 1, 1, 0.88), Color8(0x4a, 0x34, 0x20), le, f, 10.0, 14.0, 7.0)
		if say != "" and say_al > 0.0:   # câu rao
			_pill(Vector2(0, -110.0), say, 10.0, Color(1, 1, 1, 0.95 * say_al), Color(0x2a / 255.0, 0x4a / 255.0, 0x3a / 255.0, say_al), le, f, 14.0, 18.0, 9.0)
		if lbl != "":   # bảng giờ ghe thương hồ
			_pill(Vector2(0, -96.0), lbl, 11.0, Color(200 / 255.0, 60 / 255.0, 40 / 255.0, 0.95) if lbl_red else Color(40 / 255.0, 90 / 255.0, 60 / 255.0, 0.92), Color.WHITE, le, f, 16.0, 20.0, 10.0)
	func _pill(at: Vector2, s0: String, fs: float, bg: Color, fg: Color, le: float, f: Font, pad: float, h: float, r: float) -> void:
		if f == null:
			return
		var k := le / sc
		var tw := f.get_string_size(s0, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
		var w := tw + pad
		top.draw_set_transform(at, 0.0, Vector2(k, k))
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(int(r))
		sb.anti_aliasing = true
		top.draw_style_box(sb, Rect2(-w / 2.0, -h / 2.0, w, h))
		top.draw_string(f, Vector2(-tw / 2.0, fs * 0.36), s0, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), fg)
		top.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _init(f) -> void:
	farm = f
	G = f.G
	M = Snap.load_snap("ghe")

func _boat() -> Boat:
	var b := Boat.new(self)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	farm.main.obj_root.add_child(b)
	BongNuoc.add(farm.main, b.spr, "r", 0.0, b)   # bóng ghe dưới nước, soi quanh chỗ ghe
	farm.sortables.insert(farm.sortables.size() - 1, [b, 0.0, -2])   # nhân vật luôn ở cuối danh sách
	return b

func _free(b: Boat) -> void:
	for e in farm.sortables:
		if e[0] == b:
			farm.sortables.erase(e)
			break
	b.queue_free()

func _sort_y(b: Boat) -> void:   # đáy ghe để chen thứ tự vẽ
	farm.sort_set(b, farm.nn(b.p.x, b.p.y) + 2.0)

func step() -> void:
	var W = G.w_all
	if W == null:
		return
	_cho(W)
	_ghe(W)
	var now := Time.get_ticks_msec()
	_xus(W, clampf((now - _xu_ms) / 1000.0, 0.0, 0.25) if _xu_ms > 0 else 0.0)
	_xu_ms = now

func _xu_range(W):   # nT: các cột sông đã mua (ô giữa dòng là nước, khúc sông của mình) -> [đầu, cuối] hoặc null
	var L = G.lang
	if L == null or L.M.is_empty() or W.WSG == null:
		return null
	var B: Array = L.M.B
	var lo := 1e9
	var hi := -1e9
	for n in range(int(B[0]), int(B[1])):
		var y: float = W.WSG.c(float(n))
		if W.WSG.w(float(n), y) and L.ci(String(L.fo(n, int(floor(y))))):
			lo = minf(lo, n)
			hi = maxf(hi, n)
	return [lo, hi] if lo <= hi else null

func _xus(W, dt: float) -> void:   # jq + HD: xuồng chở hàng qua lại hai chiều trên khúc sông đã mua, mỗi chiều một làn
	for i in range(xus.size() - 1, -1, -1):
		var a: Dictionary = xus[i]
		a.x = float(a.x) + float(a.s) * float(a.v) * dt
		var b: Boat = a.b
		b.al = minf(1.0, b.al + dt * 0.6)
		if (float(a.s) > 0.0 and float(a.x) > float(a.hi) + 1.0) or (float(a.s) < 0.0 and float(a.x) < float(a.lo) - 1.0):
			_free(b)
			xus.remove_at(i)
			continue
		b.p = Vector2(float(a.x), W.WSG.c(float(a.x)) + float(a.y))
		b.th = atan(W.WSG.sl(float(a.x)))
		b.set_key("xu_" + ("p" if float(a.s) > 0.0 else "m") + str(a.mui) + "_" + str(clampi(int(round(b.th / 0.1)) * 2, -22, 12)))   # ảnh mỗi 0,1 rad
		_sort_y(b)
	if xus.size() >= 3:
		return
	xu_t -= dt
	if xu_t > 0.0:
		return
	xu_t = randf_range(14.0, 30.0)
	var e = _xu_range(W)
	if e == null:
		return
	var r := 1.0 if randf() < 0.5 else -1.0
	var b := _boat()
	b.al = 0.0
	b.s = r
	b.sc = randf_range(0.8, 0.9)
	var a := {"b": b, "x": float(e[0]) if r > 0.0 else float(e[1]), "y": (0.9 if r > 0.0 else -0.9) + randf_range(-0.25, 0.25), "s": r,
		"v": randf_range(0.45, 0.7), "lo": float(e[0]), "hi": float(e[1]), "mui": 1 if randf() < 0.3 else 0}
	xus.append(a)

func _cho(W) -> void:   # tN: 4 ghe chợ nổi
	var U = W.WC.Ui
	var pos = U.pos
	var t = W.WC.u4()
	if float(U.al) <= 0.0 or pos == null or t == null:
		for b in cho:
			_free(b)
		cho = []
		return
	var jd: Array = W.WC.jd()
	var ztag: bool = farm.main.zoom / maxf(1.0, farm.main.dpr) >= 0.75 and W.WC._mode() == "off"
	for e in 4:
		if cho.size() <= e:
			cho.append(_boat())
		var b: Boat = cho[e]
		var n: Array = pos[e]
		var r := (1.0 - float(U.al)) * 6.0 * (-1.0 if e % 2 == 0 else 1.0)
		var x := float(n[0]) + r
		var y: float = float(n[1]) + (W.WSG.c(x) - W.WSG.c(float(n[0])) if W.WSG != null else 0.0)
		b.p = Vector2(x, y)
		b.al = float(U.al)
		b.sc = 1.25   # 1,6 lần bản cũ: ghe chợ to hơn xuồng rõ
		b.s = -1.0 if e % 2 else 1.0
		b.th = atan(W.WSG.sl(float(n[0]))) if W.WSG != null else 0.0
		b.set_key("cho_" + String(t) + "_" + str(e))
		var of := []
		var L: Array = jd[e]
		for c in L:
			if (c.k == "item" or c.k == "cg") and of.size() < 3:
				of.append({"id": String(G.lang.C.Ei[c.id].p) if c.k == "cg" and G.lang.C.Ei.has(c.id) else String(c.id), "done": 1 if W.WC.Wx(e, L.find(c)) else 0})
		b.offers = of
		b.tag = String(W.WC.s4[e].n) if ztag else ""
		b.say = String(U.say) if int(U.sb) == e and float(U.sayT) > 0 else ""
		b.say_al = minf(1.0, float(U.sayT) * 2.0) * float(U.al)
		_sort_y(b)

func _ghe(W) -> void:   # yg() mặc định: ghe thương hồ
	var A = W.WGH.Ae if W.WGH != null else null
	if A == null or int(A.st) == 0:
		if ghe != null:
			_free(ghe)
			ghe = null
		return
	if ghe == null:
		ghe = _boat()
	var b: Boat = ghe
	var q: Array = W.WGH.vx()
	b.p = Vector2(float(q[0]), float(q[1]))
	b.al = float(A.al)
	b.sc = 1.6   # ghe thương hồ (ghe thu hàng) to hơn ghe chợ (1,25)
	b.s = 1.0
	b.th = W.WGH.th()
	b.set_key("ghe_u_" + str(clampi(int(round(b.th / 0.05)), -23, 13)))   # ghe luôn dọc sông
	b.offers = W.WGH.shown_offers()
	var left := maxf(0.0, ceil(float(A.left)))
	b.lbl = "Ghe thương hồ · " + W.WGH.cm(left) if int(A.st) == 2 and W.WC._mode() == "off" else ""
	b.lbl_red = left < 30
	_sort_y(b)
