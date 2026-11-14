extends Node2D
const Css = preload("res://ui/css.gd")
const Bong = preload("res://logic/bong.gd")   # bong bóng X0 dùng chung
# Vẽ ruộng + nhân vật lên làng Godot (main.gd của thread nền, không sửa gì bên đó).
# Ô đất nằm sát nền (z -5); cây, bong bóng, nhân vật chen vào obj_root của làng theo độ sâu,
# để nhà cửa cây cối trước sau đúng chỗ. Chạm ô -> việc vào hàng đợi -> nhân vật đi tới làm.

const H := 30.0 * 1.2 * 1.52     # chiều cao nhân vật (bản web: 30 x le x 1,2 x K)
const OU := [8.0, 15.0, 28.0, 40.0]
const ACC := Color(0.96, 0.74, 0.26)
const DIRS := [PI / 2, 2.6779450446, PI, -2.6779450446, -PI / 2, -0.4636476090, 0.0, 0.4636476090]

var G: Node            # game.gd
var P: Node            # pics.gd
var main: Node2D       # làng
var ui: Node           # ui.gd
var soil: Node2D
var fx: Node2D         # chữ bay, vòng chọn (vẽ trên cùng)
var plots := []        # mỗi ô: {soil:[dry, m, wet, pud], lock, crop:Sprite2D, bub:Bubble, key}
var sortables := []    # node của mình trong obj_root: [node, dk, j]
var player: PlayerNode
var floats := []       # [gx, gy, text, t]
var _resort_t := 0.0

# ------------------------------------------------------------------ helpers
static func en(x: float, y: float) -> float:
	return 4268.0 + (x - y) * 32.0

static func nn(x: float, y: float, z: float = 0.0) -> float:
	return 968.0 + (x + y) * 16.0 - z

static func to_tile(w: Vector2) -> Vector2:
	var X := w.x - 4268.0
	var Y := w.y - 968.0
	return Vector2((X / 32.0 + Y / 16.0) / 2.0, (Y / 16.0 - X / 32.0) / 2.0)

func is_night() -> bool:
	if main.has_method("_night_on"):
		return main._night_on()
	return false

func dn() -> String:
	return "n" if G.night else "d"

const PPU := 9.0          # hình cây / ô đất / khóa: 9 px mỗi đơn vị làng (bản 4K gốc)
var fnt: FontFile
var fnt7: FontFile
var _lz := -1
var PC := {}           # khu đất khai hoang của bản web: G0, Hy, x1, Oy, tg, le
var signs := []
var lines: Node2D = null
var sign_off := false   # chỉ để thử: giấu biển
var lang = null         # lang.gd: món đặt trong làng, đường, nền, hoa cỏ nhỏ, chuồng (Xây dựng)
var lang_ve = null      # lang_ve.gd: vẽ những thứ đó

func crop_bundle(c: String) -> String:
	var lv := int(G.crop(c).get("lv", 1))
	return "cay0" if lv <= 5 else "cay1" if lv <= 15 else "cay2" if lv <= 30 else "cay3"

# ------------------------------------------------------------------ build
func setup(game: Node, pics: Node, village: Node2D, u: Node) -> void:
	G = game
	P = pics
	main = village
	ui = u
	G.night = is_night()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # hình đúng mức nét (P.texz), không mipmap làm nhòe
	fnt = FontFile.new()
	fnt.data = FileAccess.get_file_as_bytes("res://ui/font/nunito_800.ttf")
	fnt.multichannel_signed_distance_field = true   # chữ vẽ bằng đường viền: nét ở mọi mức zoom
	fnt.msdf_pixel_range = 16
	fnt.msdf_size = 64
	fnt7 = FontFile.new()
	fnt7.data = FileAccess.get_file_as_bytes("res://ui/font/nunito_700.ttf")
	fnt7.multichannel_signed_distance_field = true
	fnt7.msdf_pixel_range = 16
	fnt7.msdf_size = 64
	soil = Node2D.new()
	soil.z_index = -5
	add_child(soil)
	badges = Node2D.new()
	badges.z_index = -4
	badges.draw.connect(_draw_badges)
	add_child(badges)
	fx = FxNode.new()
	fx.farm = self
	fx.z_index = 50
	add_child(fx)
	for i in G.B0:
		var c: Dictionary = G.cells[i]
		var x := en(c.gx, c.gy + 1) - 1.0
		var y := nn(c.gx, c.gy, G.CO) - 2.0
		var L := []
		for k in 4:
			var s := Sprite2D.new()
			s.centered = false
			s.position = Vector2(x, y)
			s.visible = false
			soil.add_child(s)
			L.append(s)
		var cs := Sprite2D.new()
		cs.centered = false
		cs.visible = false
		cs.position = Vector2(en(c.gx + 0.5, c.gy + 0.5), nn(c.gx + 0.5, c.gy + 0.5, G.CO) + 3.5)
		var rg := RipeRing.new()   # vòng vàng ô chín: nằm dưới cây trồng của ô (vẽ trước cs), bị cây che như bản web
		rg.visible = false
		rg.position = Vector2(en(c.gx + 0.5, c.gy + 0.5), nn(c.gx + 0.5, c.gy + 0.5, G.CO) + 1.0)
		_add_sorted(rg, nn(c.gx + 0.5, c.gy + 0.5) + 13.99)
		_add_sorted(cs, nn(c.gx + 0.5, c.gy + 0.5) + 14.0)
		var rn := RayNode.new()   # rầy nâu bu trên ô (o_): vẽ sau cây của ô
		rn.visible = false
		rn.farm = self
		rn.i = i
		rn.position = Vector2(en(c.gx + 0.5, c.gy + 0.5), nn(c.gx + 0.5, c.gy + 0.5, G.CO))
		_add_sorted(rn, nn(c.gx + 0.5, c.gy + 0.5) + 14.5)
		var b := Bubble.new()
		b.fnt = fnt
		b.farm = self
		b.visible = false
		b.position = Vector2(en(c.gx + 0.5, c.gy + 0.5), nn(c.gx + 0.5, c.gy + 0.5, G.CO))
		b.z_index = 40     # bong bóng vẽ sau cùng, đè mọi thứ
		add_child(b)
		plots.append({"soil": L, "crop": cs, "bub": b, "ring": rg, "ray": rn, "key": ""})
	# biển Khai hoang (XW/JW bản web): vẽ bằng code, chữ vector, thay ảnh chụp
	PC = JSON.parse_string(FileAccess.get_file_as_string("res://ui/snap/parcel_web.json"))
	for id in PC.x1:
		var sg := ParcelSign.new()
		sg.farm = self
		sg.id = id
		var a: Array = PC.G0[id].sign
		sg.position = Vector2(en(a[0] + 0.5, a[1] + 0.5), nn(a[0] + 0.5, a[1] + 0.5, 0.0))
		_add_sorted(sg, nn(a[0] + 0.6, a[1] + 0.6))
		signs.append(sg)
	# viền nét đứt vàng quanh khu kề bên đủ xu (bản web: setLineDash([7,6]) theo TH.lot)
	lines = ParcelLines.new()
	lines.farm = self
	lines.z_index = -4
	add_child(lines)
	G.troi.bao.farm = self
	player = PlayerNode.new()
	player.farm = self
	player.material = main.night_mat
	_add_sorted(player, 0.0)
	lang = load("res://logic/lang.gd").new(G, self)
	G.lang = lang
	lang_ve = load("res://logic/lang_ve.gd").new(self, lang)
	# hình mới giải xong: vẽ lại ruộng một lần mỗi khung hình (không vẽ lại cả ruộng cho từng hình); nhân vật tự vẽ mỗi khung
	P.ready_pic.connect(func(b, _k): if not String(b).begins_with("nv_"): _dirty = true)
	P.bundle_ready.connect(func(b):
		if String(b).begins_with("nv_"):
			P.warm(b)
		else:
			_dirty = true)
	G.changed.connect(refresh)
	G.float_text.connect(func(x, y, m): floats.append([x, y, m, 0.0]))
	# hình nhà làng chụp sẵn có cả ô ruộng cũ: giấu đi, ruộng giờ vẽ sống
	for o in main.objs:
		if o["x"] < -50000:
			o["spr"].visible = false
	for b in ["dat", "nv_walk", "nv_idle", "cay0"]:
		P.load_bundle(b)
	refresh()

func _add_sorted(n: Node2D, dk: float) -> void:
	n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	main.obj_root.add_child(n)
	sortables.append([n, dk, -2])

# ------------------------------------------------------------------ draw state
var badges: Node2D = null
var _bz := false
func _draw_badges() -> void:   # sao ô (n.st > 1, ba.z > .55): tối đa 5 ngôi ở góc dưới ô
	var zz: float = main.zoom / maxf(1.0, main.dpr)
	_bz = zz > 0.55
	if not _bz:
		return
	var fc := Color("#d8b040") if G.night else Color("#f2c63a")
	var lc := Color(90 / 255.0, 60 / 255.0, 0, 0.55)
	for i in G.B0:
		var a: Dictionary = G.p(i)
		if not G.owned(i) or not a.u or int(a.get("st", 1)) <= 1:
			continue
		var c: Dictionary = G.cells[i]
		var n := mini(5, int(a.st) - 1)
		var M := en(c.gx + 1, c.gy + 1) - 4.0
		var T := nn(c.gx + 1, c.gy + 1, G.CO) - 5.0
		for w in n:
			var E := M - w * 5.2
			var C := T - w * 2.6
			var pts := PackedVector2Array()
			for R in 10:
				var N := 1.3 if R % 2 else 3.0
				var z := -PI / 2.0 + R * PI / 5.0
				pts.append(Vector2(E + cos(z) * N, C + sin(z) * N))
			badges.draw_colored_polygon(pts, fc)
			pts.append(pts[0])
			badges.draw_polyline(pts, lc, 0.7, true)

func refresh() -> void:
	var nt := is_night()
	if nt != G.night:
		G.night = nt
	for i in G.B0:
		_plot_view(i)
	if badges != null:
		badges.queue_redraw()
	for sg in signs:
		sg.sync()
	_xw_sync()
	if lang_ve != null:
		lang_ve.sync()
	if lines != null:
		lines.sync()

func _put(s: Sprite2D, b: String, k: String, w: float, h: float, a: float = 1.0) -> void:
	var t: Texture2D = P.texz(b, k, PPU, main.zoom)
	if t == null:
		s.visible = false
		return
	s.texture = t
	s.scale = Vector2(w / t.get_width(), h / t.get_height())
	s.modulate.a = a
	s.visible = a > 0.0

func _plot_view(i: int) -> void:
	var a: Dictionary = G.p(i)
	var v: Dictionary = plots[i]
	var L: Array = v.soil
	var cs: Sprite2D = v.crop
	var bub: Bubble = v.bub
	for s in L:
		s.visible = false
	cs.visible = false
	bub.visible = false
	if not G.owned(i):
		return
	var d := dn()
	if not a.u:
		# ô chưa mở: đất khô mờ + ổ khóa + giá
		_put(L[0], "dat", d + "dry", 66, 42, 0.55 if G.night else 0.5)
		bub.kind = "lock"
		bub.text = str(G.open_cost())
		bub.can = int(G.g.coins) >= G.open_cost() and G.lv_for_more() == 0
		bub.tex = P.texz("dat", d + "khoa", PPU, main.zoom)
		bub.night = G.night
		bub.position.y = nn(G.cells[i].gx + 0.5, G.cells[i].gy + 0.5)
		bub.z_index = -4   # nằm sát đất như bản web (vẽ cùng lượt ô ruộng)
		bub.visible = true
		bub.queue_redraw()
		return
	# gP: -1 trống (khô), 0 có cây đất khô nứt, >0 độ ướt
	var t := -1.0
	if a.c != null:
		t = 0.0 if float(a.w) <= 0.0 else maxf(0.125, round(minf(1.0, float(a.w) / G.water_hold(a)) * 8.0) / 8.0)
	if t < 0.0:
		_put(L[0], "dat", d + "dry", 66, 42)
	elif t == 0.0:
		_put(L[0], "dat", d + "crack", 66, 42)
	else:
		_put(L[0], "dat", d + "drym", 66, 42)
		_put(L[1], "dat", d + "wet", 66, 42, minf(1.0, 0.35 + 0.65 * t))
		if t >= 0.5:
			_put(L[2], "dat", d + "pud", 66, 42, minf(1.0, (t - 0.5) * 2.2))
	if a.c == null:
		return
	var st: int = G.stage(a)
	if st == 0:   # vừa gieo: ảnh 3 hạt (ui/img/bong/hat.png, -10,5..10,5 x -4,5..3,5 quanh tâm ô), nằm đúng lớp của cây
		var ht: Texture2D = Bong.anh("hat", main.zoom)
		if ht != null:
			cs.texture = ht
			var k := Vector2(21.0 / ht.get_width(), 8.0 / ht.get_height())
			cs.scale = k
			v.k = k
			cs.offset = Vector2(-10.5 / k.x, (-4.5 - 3.5) / k.y)   # cs đặt ở tâm ô + 3,5
			cs.visible = true
	else:
		var b := crop_bundle(a.c)
		var key: String = d + str(a.c) + str(st)
		var tx: Texture2D = P.texz(b, key, PPU, main.zoom)
		var m: Dictionary = P.meta(b)
		if tx != null and m.has(key):
			var f: Array = m[key]
			cs.texture = tx
			var k := Vector2(f[2] / tx.get_width(), f[3] / tx.get_height())
			cs.scale = k
			v.k = k
			cs.offset = Vector2(f[0] / k.x, f[1] / k.y)
			cs.visible = true
	# bong bóng: chín -> hình cây, có sâu -> sâu, khô -> giọt nước
	bub.z_index = 40
	var top: float = OU[st] + 12.0
	bub.position.y = nn(G.cells[i].gx + 0.5, G.cells[i].gy + 0.5, G.CO) - top
	bub.can = true
	bub.text = ""
	if G.has_ray(i):
		bub.kind = "ray"
		bub.visible = true
	elif G.ripe(a):
		bub.kind = "ripe"
		bub.id = str(a.c)
		bub.visible = true
	elif a.get("b", 0):
		bub.kind = "sau"
		bub.id = "sau"
		bub.visible = true
	elif float(a.w) <= 0.0:
		bub.kind = "drop"
		bub.visible = true
	bub.queue_redraw()

# ------------------------------------------------------------------ frame
var _dirty := false
var _cfg_sig := ""
# NTCHK (bản 81): ?chk trên địa chỉ -> mỗi 4 giây soi các món cảnh (nhà, cây, miếu...) mà logic coi là đang có ở gần giữa
# màn, tìm hình bên nền, món nào không hiện thì ghi lý do lên dòng chữ trên cùng màn hình (để Link chụp gửi).
var _chk := -1
var _chk_t := 0.0
var _chk_lb: Label = null
func _chk_step(dt: float) -> void:
	if _chk < 0:
		_chk = 1 if (main.has_method("_tflag") and main._tflag("__chk")) else 0
	if _chk != 1 or lang == null:
		return
	_chk_t -= dt
	if _chk_t > 0.0:
		return
	_chk_t = 4.0
	if _chk_lb == null:
		var cl := CanvasLayer.new()
		cl.layer = 120
		add_child(cl)
		_chk_lb = Label.new()
		_chk_lb.position = Vector2(8, 260)
		_chk_lb.add_theme_font_size_override("font_size", int(13 * maxf(1.0, main.dpr)))
		_chk_lb.add_theme_color_override("font_color", Color(1, 1, 0.3))
		_chk_lb.add_theme_color_override("font_outline_color", Color.BLACK)
		_chk_lb.add_theme_constant_override("outline_size", 6)
		_chk_lb.autowrap_mode = TextServer.AUTOWRAP_WORD
		_chk_lb.size = Vector2(get_viewport().get_visible_rect().size.x - 16, 0)
		cl.add_child(_chk_lb)
	var vs: Vector2 = get_viewport().get_visible_rect().size / main.zoom
	var vc: Vector2 = main.cam + vs * 0.5
	var R: float = maxf(vs.x, vs.y) * 0.6
	var n_ok := 0
	var bad := []
	var V: Array = main.sc_data.get("v", []) if "sc_data" in main else []
	for o in lang.SO:
		if o.wild or not lang.so_shown(o):
			continue
		var f := Vector2(float(o.sx), float(o.sy))
		if f.distance_to(vc) > R:
			continue
		var best = null
		var bd := 36.0
		var what := ""
		var OL: Array = main.info.get("objs", [])
		for qi in main.objs.size():
			var q: Dictionary = main.objs[qi]
			if qi < OL.size() and str(OL[qi][6]) != String(o.id):
				continue
			var ft: Vector2 = q["piv"] if q.has("piv") else Vector2(q["x"] + q["w"] * 0.5, q["y"] + q["h"] * 0.88)
			var d := ft.distance_to(f) * 0.5
			if d < bd:
				bd = d
				best = q
				what = "o"
		for j in main.sc_spr.size():
			if j >= V.size() or V[j] == null:
				continue
			for sp in main.sc_spr[j]:
				var ft2: Vector2 = sp.position if sp.has_meta("sw") else sp.position - Vector2(float(V[j][0]), float(V[j][1]))
				var d2 := ft2.distance_to(f)
				if d2 < bd:
					bd = d2
					best = sp
					what = "s"
		if best == null:
			bad.append(String(o.id) + "@" + String(o.pc) + ": nền không có hình")
			continue
		var sp3: Sprite2D = best["spr"] if what == "o" else best
		var vis := sp3.visible and sp3.texture != null and sp3.is_visible_in_tree()
		if vis:
			n_ok += 1
			continue
		var why := []
		var pcm: String = (String(best.get("pc", "")) if what == "o" else String(sp3.get_meta("pc", "")))
		if pcm != "":
			why.append("pc " + pcm + (" mua" if main._owned(pcm) else " CHƯA mua"))
		if (best.get("xg", false) if what == "o" else sp3.get_meta("xg", false)):
			why.append("xg")
		if (best.get("cay", false) if what == "o" else sp3.get_meta("cay", false)):
			why.append("cay")
		if sp3.texture == null:
			why.append("không ảnh")
		if what == "s" and sp3.has_meta("pco"):
			why.append("pco")
		if not sp3.visible:
			why.append("tự ẩn")
		elif not sp3.is_visible_in_tree():
			why.append("cha ẩn")
		if what == "o":
			why.append("lev " + str(best.get("lev", "")) + (" sst" if best.has("sst") else "") + (" op " + str(best["op"][0]) if best["op"] != null else " op null"))
		bad.append(String(o.id) + "@" + String(o.pc) + "[" + what + "]: " + ",".join(why))
	var lo := 0
	for s0 in lang_ve.nodes:
		if is_instance_valid(s0) and s0 is Sprite2D and (not s0.visible or s0.texture == null or not s0.is_visible_in_tree()):
			lo += 1
	var t := "KIỂM: cảnh hiện %d, mất %d · đồ mình đặt mất %d/%d (đất %s)" % [n_ok, bad.size(), lo, lang_ve.nodes.size(), ",".join(PackedStringArray(G.g.land.keys()))]
	for k in mini(10, bad.size()):
		t += "\n" + String(bad[k])
	_chk_lb.text = t

var _land_sig := "?"
func _land_sync() -> void:   # NTLAND (bản 82): báo nền đất đã mua mỗi khi đổi, kể cả lúc mới tải save (nền tìm /root/G không thấy)
	var L = G.g.get("land")
	if not (L is Dictionary):
		return
	var ks: Array = L.keys()
	ks.sort()
	var sg := ",".join(PackedStringArray(ks))
	if sg != _land_sig and main.has_method("land_changed") and "lot_info" in main and not main.lot_info.is_empty():
		_land_sig = sg
		main.land_changed(L)

# NTWEB (bản 83): cảnh bên nền phải khớp đúng dữ liệu web (lang.SO vật cảnh + lang.HU cây rừng/cỏ hoang). Hình cảnh nào
# của nền không ứng với món nào của web (món Link đã xoá khỏi web, như đá hoang) thì giấu luôn, cả bóng dưới nước.
var _pruned := false
func _web_prune() -> void:
	if _pruned or lang == null or not ("sc_spr" in main) or main.sc_spr.is_empty() or main.sc_data.is_empty():
		return
	_pruned = true
	var grid := {}
	var addp := func(x: float, y: float) -> void:
		var k := Vector2i(int(floor(x / 32.0)), int(floor(y / 32.0)))
		if not grid.has(k):
			grid[k] = []
		grid[k].append(Vector2(x, y))
	for o in lang.SO:
		addp.call(float(o.sx), float(o.sy))
	for o in lang.HU:
		addp.call(float(o.sx), float(o.sy))
	var V: Array = main.sc_data["v"]
	var n := 0
	for j in main.sc_spr.size():
		if j == 16 or j >= V.size() or V[j] == null:
			continue
		for sp in main.sc_spr[j]:
			var f: Vector2 = sp.position if sp.has_meta("sw") else sp.position - Vector2(float(V[j][0]), float(V[j][1]))
			var c := Vector2i(int(floor(f.x / 32.0)), int(floor(f.y / 32.0)))
			var hit := false
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					for q in grid.get(c + Vector2i(dx, dy), []):
						if q.distance_to(f) < 12.0:
							hit = true
			if hit:
				continue
			sp.set_meta("cay", true)   # main._lot_vis: "cay" = giấu luôn
			sp.visible = false
			n += 1
			for rs in main.sc_rall.get(j, []):
				if is_instance_valid(rs) and absf(rs.position.x - sp.position.x) < 0.5:
					rs.set_meta("cay", true)
					rs.visible = false
	print("web_prune: giấu ", n, " hình cảnh không có trong web")

func _process(dt: float) -> void:
	_web_prune()
	_land_sync()
	_chk_step(dt)
	# Cài đặt: Chất lượng hình (0 Tiết kiệm, 1 Cân bằng, 2 Nét) và Chuyển động (true = đứng yên) cho bên nền
	var cfs := str(G.cfg.q) + str(G.motion_off())
	if cfs != _cfg_sig:
		_cfg_sig = cfs
		if main.has_method("set_quality"):
			main.set_quality(int(G.cfg.q))
		if main.has_method("set_motion"):
			main.set_motion(G.motion_off())
	# trời (troi.gd): bên nền đọc trạng thái để vẽ màu trời, nắng, mưa, chớp
	if main.has_method("troi_set") and G.troi != null and not G.troi.st.is_empty():
		main.troi_set(G.troi.st)
	if _dirty:
		_dirty = false
		refresh()
	var tt := Time.get_ticks_msec() / 1000.0
	var zz: float = main.zoom / maxf(1.0, main.dpr)
	if lang_ve != null:
		lang_ve.step()
	_lp_step()
	if (zz > 0.55) != _bz and badges != null:
		badges.queue_redraw()
	var lz: int = P.level(PPU, main.zoom)
	if lz != _lz:
		_lz = lz
		refresh()
	for i in G.B0:
		var v: Dictionary = plots[i]
		var cs: Sprite2D = v.crop
		if cs.visible:
			# gió lay nhẹ (pP): +-0,05 rad, đứng yên khi xa
			cs.rotation = sin(tt * 1.7 + G.cells[i].gx * 1.7 + G.cells[i].gy) * 0.05 if zz >= 0.6 and G.stage(G.p(i)) > 0 else 0.0
			# chín: nhún lên (W = -|sin(3t + gx)| x 2); vừa gieo: nảy từ 0,25 lên (easeOutBack); vừa tưới/thu: lắc
			var gc: Dictionary = G.cells[i]
			var W := -absf(sin(tt * 3.0 + gc.gx)) * 2.0 if G.ripe(G.p(i)) else 0.0
			cs.position.y = nn(gc.gx + 0.5, gc.gy + 0.5, G.CO) + 3.5 + W
			var ft := 1.0
			var K = dy.get(i)
			if K != null:
				var sk: float = (_now() - float(K.t)) / 1000.0
				if sk > 0.5:
					dy.erase(i)
				elif K.k == "plant":
					var ut := minf(1.0, sk / 0.4) - 1.0
					ft = 0.25 + 0.75 * (1.0 + 2.70158 * ut * ut * ut + 1.70158 * ut * ut)
				else:
					cs.rotation += sin(sk * 34.0) * (1.0 - sk / 0.5) * 0.09
			if not v.has("k"):
				v.k = cs.scale
			cs.scale = v.k * ft
		var rg: RipeRing = v.ring
		var a0: Dictionary = G.p(i)
		rg.visible = G.owned(i) and a0.u and G.ripe(a0)
		if rg.visible:
			rg.modulate.a = 0.55 + 0.4 * sin(tt * 4.0 + G.cells[i].gx)
			rg.zoom_to(main.zoom)
		var rn: RayNode = v.ray
		rn.visible = G.owned(i) and G.has_ray(i)
		if rn.visible:
			rn.tt = tt
			rn.queue_redraw()
		var b: Bubble = v.bub
		if b.visible and b.kind != "lock":
			# X0: phập phồng 1 + .08 sin(5t + x), nhân le (làng nhỏ lại thì to lên cho dễ đọc)
			b.k = (1.0 + 0.08 * sin(tt * 5.0 + b.position.x)) * sign_le()
			b.zoom = main.zoom
			b.queue_redraw()
	_fell_sync(tt, zz)
	_vn_sync(dt)
	_crit_sync()
	_dan_sync(tt)
	_tree_bub_sync(tt)
	_parts_step(dt)
	_jobs(dt)
	player.step(dt)
	G.ppos = Vector2(player.x, player.y)
	for f in floats:
		f[3] += dt
	floats = floats.filter(func(f): return f[3] < 1.6)
	fx.queue_redraw()
	_resort_t -= dt
	if _resort_t <= 0.0:
		_resort_t = 0.1
		_resort()

func _resort() -> void:
	# chen node của mình vào thứ tự vẽ của làng: trước vật đầu tiên có đáy thấp hơn mình
	var O: Array = main.objs
	sortables[sortables.size() - 1][1] = player.base_y()
	var ch := false
	for s in sortables:
		var j := O.size()
		for k in O.size():
			var o: Dictionary = O[k]
			if o["x"] < -50000:
				continue
			if float(o["y"]) + float(o["h"]) > s[1]:
				j = k
				break
		if j != s[2]:
			s[2] = j
			ch = true
	if not ch:
		return
	var L := sortables.duplicate()
	L.sort_custom(func(a, b): return a[1] < b[1])
	var root: Node2D = main.obj_root
	for s in L:
		var n: Node2D = s[0]
		if s[2] >= O.size():
			root.move_child(n, root.get_child_count() - 1)
		else:
			var ref: Node2D = O[s[2]]["spr"]
			var ti := ref.get_index()
			var ci := n.get_index()
			root.move_child(n, ti if ci > ti else ti - 1)

# ------------------------------------------------------------------ chạm / vuốt (pointerdown/move/up + click của bản web)
# Chạm xuống ô có việc (gieo/tưới/gặt/bắt sâu): giữ 220 ms rồi kéo = vuốt làm cả loạt (không kéo làng);
# kéo trước 220 ms = kéo làng như thường. Nhấc tay không kéo = click: sâu -> bắt sâu, còn lại c2 (mở bảng).
var _press := {}       # index -> {p: vị trí đầu, moved}
var sw = null          # Q0 bản web: {id, mode, done, pend, first, arm, lw, acts, poor, p0}
var i7 := 0.0          # click vào ô bị bỏ qua tới lúc này (ms)
var n2 := 0.0          # vừa kéo làng xong: bỏ click

func _now() -> float:
	return float(Time.get_ticks_msec())

func _css(d: float) -> float:
	return d / maxf(1.0, main.dpr)

func plot_mode(i: int) -> String:   # ZX
	var a: Dictionary = G.p(i)
	if a.get("b", 0) or a.get("oc", 0):
		return "bug"
	if not a.u:
		return "unlock"
	if a.c == null:
		return "plant"
	if G.ripe(a):
		return "harvest"
	if float(a.w) < G.water_hold(a) - 0.5:
		return "water"
	return "pan"

func _swipe_act(mode: String, i: int) -> bool:   # uH
	var a: Dictionary = G.p(i)
	if mode == "plant":
		if not a.u or a.c != null:
			return false
		var e: String = str(G.g.sel) if G.g.sel != null else ""
		if e == "" or int(G.g.barn.get(e, 0)) <= seeds_queued(e):
			if not sw.poor:
				sw.poor = true
				if e != "":
					G.toast.emit("Hết giống " + String(G.crop(e).name).to_lower() + ". Mua ở Chợ phiên, chợ nổi sáng sớm hoặc nhà hàng xóm.")
			return false
		return queue_job(i, "plant", e)
	if mode == "harvest":
		return G.ripe(a) and queue_job(i, "harvest")
	if mode == "water":
		return a.c != null and queue_job(i, "water")
	if mode == "bug":
		return (a.get("b", 0) or a.get("oc", 0)) and queue_job(i, "bug")
	return false

func _down(id: int, pos: Vector2) -> void:
	_press[id] = {"p": pos, "moved": false}
	if _press.size() >= 2:
		sw = null
		return
	if ui.bdp != null and ui.bdp.active():   # đang Xây dựng: chạm làng thuộc bảng xây (xj)
		ui.bdp.world_down(screen_to_world(pos))
		return
	ui.world_down()
	var w := screen_to_world(pos)
	_lp = {"id": id, "w": w, "t": _now() + 450.0}
	var i := plot_at(w)
	if i < 0:
		return
	var f := plot_mode(i)
	i7 = 0.0
	if f == "pan" or f == "unlock":
		return   # cây đang lớn đã tưới / ô chưa mở: kéo làng; chạm thì mở bảng (đo trên bản web)
	sw = {"id": id, "mode": f, "done": {i: true}, "pend": true, "first": i, "arm": _now() + 220.0, "lw": w, "acts": 0, "poor": false}

func _move_to(id: int, pos: Vector2) -> bool:
	# true = sự kiện thuộc về vuốt, làng không kéo
	if not _press.has(id):
		return false
	var pr: Dictionary = _press[id]
	if ui.bdp != null and ui.bdp.gdrag != null and _press.size() == 1:
		return ui.bdp.world_drag(screen_to_world(pos), _css(pos.distance_to(pr.p)))
	if sw != null and sw.id == id:
		var d := _css(pos.distance_to(pr.p))
		if sw.arm > 0.0:
			if d >= 6.0 and _now() < sw.arm:
				sw = null
			elif _now() >= sw.arm:
				sw.arm = 0.0
			else:
				return true
		if sw != null:
			var w := screen_to_world(pos)
			var dd: Vector2 = w - sw.lw
			var n := maxi(1, int(ceil(dd.length() / 8.0)))
			var did := false
			for k in range(1, n + 1):
				var j := plot_at(sw.lw + dd * float(k) / float(n))
				if j >= 0 and not sw.done.has(j):
					if sw.pend:
						sw.pend = false
						ui.close_all()
						if _swipe_act(sw.mode, sw.first):
							sw.acts += 1
							did = true
					sw.done[j] = true
					if _swipe_act(sw.mode, j):
						sw.acts += 1
						did = true
			sw.lw = w
			if did:
				G.mark()
			return true
	if not pr.moved and _css(pos.distance_to(pr.p)) >= 6.0:
		pr.moved = true
	return false

var _lp := {}            # nhấn giữ đang chờ (XX bản web)
func _lp_step() -> void:
	if _lp.is_empty() or _lp.get("fired", false):
		return
	if not _press.has(_lp.id) or _press.size() != 1 or _press[_lp.id].moved or sw != null and not sw.pend:
		_lp = {}
		return
	if _now() >= float(_lp.t):
		if ui.bdp != null and ui.bdp.open_at(_lp.w):
			_lp.fired = true
			sw = null
		else:
			_lp = {}

func _up(id: int, pos: Vector2) -> void:
	if not _press.has(id):
		return
	if not _lp.is_empty() and _lp.id == id:
		var fired: bool = _lp.get("fired", false)
		_lp = {}
		if fired:
			_press.erase(id)
			n2 = _now() + 250.0
			return
	var pr: Dictionary = _press[id]
	var multi := _press.size() > 1
	_press.erase(id)
	if ui.bdp != null and ui.bdp.world_up():
		n2 = _now() + 250.0
		return
	if sw != null and sw.id == id:
		var nm: String = {"plant": "gieo", "water": "tưới", "harvest": "thu hoạch"}.get(sw.mode, "")
		if nm != "" and sw.acts >= 2:
			G.toast.emit("Đã xếp " + str(sw.acts) + " ô để " + nm + ", nhân vật sẽ làm lần lượt.")
		i7 = 0.0 if sw.pend else _now() + 450.0
		var was_swipe: bool = not sw.pend
		sw = null
		if was_swipe:
			return
	if pr.moved:
		n2 = _now() + 250.0
		return
	if multi or _now() < n2:
		return
	tap(pos)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_down(e.index, e.position)
		else:
			_up(e.index, e.position)
	elif e is InputEventScreenDrag:
		if _move_to(e.index, e.position):
			get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down(-1, e.position)
		else:
			_up(-1, e.position)
	elif e is InputEventMouseMotion and _press.has(-1):
		if _move_to(-1, e.position):
			get_viewport().set_input_as_handled()

func screen_to_world(p: Vector2) -> Vector2:
	return main.cam + p / main.zoom

func world_to_screen(w: Vector2) -> Vector2:
	return (w - main.cam) * main.zoom

func plot_at(w: Vector2) -> int:
	# mặt ô (nổi CO đơn vị) rồi thân cây cao
	var t := to_tile(Vector2(w.x, w.y + G.CO))
	for i in G.B0:
		var c: Dictionary = G.cells[i]
		if G.owned(i) and t.x >= c.gx and t.x < c.gx + 1 and t.y >= c.gy and t.y < c.gy + 1:
			return i
	for i in G.B0:
		var cs: Sprite2D = plots[i].crop
		if cs.visible and absf(w.x - cs.position.x) < 14.0 and w.y > cs.position.y - 40.0 and w.y < cs.position.y:
			return i
	return -1

func _on_player(w: Vector2) -> bool:   # xV
	var p := Vector2(en(player.x, player.y), nn(player.x, player.y))
	return absf(w.x - p.x) < 10.0 * 1.52 and w.y > p.y - 38.0 * 1.52 and w.y < p.y + 4.0

var _tap0 := {"t": -1e9, "p": Vector2.ZERO}

func goto(p: Vector2) -> void:   # FR: bỏ việc "goto" cũ, đi tới ô (x, y)
	q = q.filter(func(j): return j.key != "goto")
	if cur != null and cur.key == "goto":
		cur = null
		st = 0
	q.append({"key": "goto", "kind": "walk", "i": -1, "seed": "", "pos": p})

func tap(sp: Vector2) -> void:
	var w := screen_to_world(sp)
	if ui.bdp != null and ui.bdp.active():
		ui.bdp.world_tap(w)
		return
	if _on_player(w) and (cur != null or q.size() > 0):
		ui.close_all()
		stop_jobs()
		return
	var h := pick(w)
	if ui.vlp != null and String(h.get("type", "")) != "sonha":
		ui.vlp.chip_close()
	match String(h.get("type", "")):
		"fall":
			ui.close_all()
			var fk := String(h.k)
			if G.troi.bao.state(fk) == "burn":
				G.troi.bao.chop(fk)   # chỉ báo "đang cháy âm ỉ"
				return
			if not has_job("fall" + fk):
				q.append({"key": "fall" + fk, "kind": "fall", "i": -1, "seed": fk, "pos": G.troi.bao.stand(fk)})
		"birds":
			ui.close_all()
			G.w_all.WR.ib_bay("Xùy xùy!")
		"gavit":
			ui.close_all()
			G.w_all.WR.dx("Xùy xùy!")
		"work":
			ui.close_all()
			xw_tap(String(h.k))
		"animal", "pen":
			ui.close_all()
			ui.vn_open({"t": h.k, "j": int(h.get("j", -1))}, w)
		"tree":
			ui.rm_tree(int(h.i))
		"hive":
			ui.close_all()
			G.w_all.WR.sx(int(h.i))
		"khohang":
			ui.close_all()
			ui.kho_open()
		"nha":
			ui.close_all()
			ui.vl_open(int(h.u))
		"sonha":
			ui.vl_chip(h.o)
		"dan":   # chạm người dân: mở bảng nhà
			ui.close_all()
			ui.vl_open(int(h.u))
		"parcel":
			ui.pc_open(String(h.id), w)
		"scnlock":
			ui.close_all()
			var a = PC.G0.get(h.id)
			if a != null:
				G.toast.emit("Khai hoang " + String(a.name).to_lower() + " trước đã (" + G.fmt_n(int(a.cost)) + " xu).")
		"scn", "paddy":
			ui.close_all()
			var key := ("scn" + String(h.o.key)) if h.type == "scn" else ("paddy" + str(h.gx) + "," + str(h.gy))
			if not has_job(key):
				var sp2: Vector2 = Vector2(h.o.gx + h.o.fw / 2.0, h.o.gy + h.o.fd + 0.3) if h.type == "scn" else Vector2(h.gx + 0.5, h.gy + 1.3)
				q.append({"key": key, "kind": h.type, "i": -1, "seed": "", "h": h, "pos": sp2})
		"ray":   # QS: đi tới ô phun thuốc
			ui.close_all()
			queue_job(int(h.i), "spray")
		"plot":
			if _now() < i7:
				return
			var i := int(h.i)
			var a: Dictionary = G.p(i)
			if a.get("b", 0) or a.get("oc", 0):
				ui.close_all()
				queue_job(i, "bug")
				return
			ui.tap_plot(i)
		_:
			ui.close_all()
			# chạm 2 lần nhanh lên nền trống: nhân vật đi tới chỗ đó (FR bản web: việc "goto")
			var t := _now()
			if t - float(_tap0.t) < 350.0 and _css(sp.distance_to(_tap0.p)) < 24.0:
				goto(to_tile(w))
				_tap0 = {"t": -1e9, "p": Vector2.ZERO}
			else:
				_tap0 = {"t": t, "p": sp}

# ------------------------------------------------------------------ chọn vật bị chạm như bản web (cH + RE / vbHit)
# 1. Bong bóng đang hiện (Su.bubs): chạm trong vòng bong bóng thì chọn đúng thứ có bong bóng đó.
# 2. Ứng viên có cờ bub (bong bóng xưởng, bong bóng con vật): ord nhỏ nhất.
# 3. Trúng hình ngay dưới ngón tay: thứ nằm trên cùng (đứng trước, chân thấp hơn) thắng; bằng nhau thì ord nhỏ hơn.
# 4. Đồ đang đi (mv: chim, gà vịt, con vật) lố tay tới 12 px css: gần nhất. 5. Chạm trong nền (gr > 2): gr lớn, ord nhỏ.
# 6. Gần hình trong 8 px css: gần nhất. 7. Còn lại: ruộng lúa (gr 1).
# ord như web: xưởng 2, chim 3, gà vịt 5, cây ngã 7, biển khai hoang 41, con vật 42, chuồng 43, ô ruộng 44, cây ăn trái 45,
# kho 46, thùng ong 49, cây rừng / cỏ hoang 51, ruộng lúa 52.
const PK_R := 12.0    # t.R: px css cho đồ đang đi
const PK_RS := 8.0    # t.RS: px css gần hình

func _pk_near(f: Callable, w: Vector2, maxpx: float) -> float:   # px css tới chỗ trúng hình gần nhất (0 = trúng ngay, 99 = không)
	if f.call(w):
		return 0.0
	var z: float = ui.cz()
	for r in [3.0, 6.0, 9.0, 12.0]:
		if r > maxpx:
			break
		for k in 8:
			var a: float = k * TAU / 8.0
			if f.call(w + Vector2(cos(a), sin(a)) * r / z):
				return r
	return 99.0

func _pk_bubs(w: Vector2):   # Su.bubs: bong bóng đang hiện -> thứ có bong bóng
	var z: float = ui.cz()
	for i in G.B0:   # ô ruộng
		var b: Bubble = plots[i].bub
		if b.visible and b.kind != "lock" and b.position.distance_to(w) <= 10.0 * b.k + 3.0 / z:
			return {"type": "ray", "i": i} if G.has_ray(i) else {"type": "plot", "i": i}   # bong bóng của ô: rầy (ord 10) trước ô (44)
	for i in tbubs:   # cây ăn trái / thùng ong
		var b: Bubble = tbubs[i]
		if b.visible and b.position.distance_to(w) <= 10.0 * b.k + 3.0 / z:
			var o: Dictionary = lang.objs()[i]
			if b.kind == "chat" or (G.w_all != null and G.w_all.WL.CX.has(o.id)):   # bong bóng nhà dân (FD): mở bảng nhà
				return {"type": "nha", "u": int(o.get("u", 0))}
			return {"type": "hive" if o.id == "thungong" else "tree", "i": i}
	var le := sign_le()
	for k in anodes:   # con vật
		var n = anodes[k]
		if n.has_bub() and n.bub_at().distance_to(w) <= 10.0 * le + 3.0 / z:
			return {"type": "animal", "k": n.t, "j": n.j}
	for k in G.xw.list_built():   # xưởng có hàng xong
		if G.xw.df(k) > 0:
			var e: Dictionary = G.xw.sr[k]
			var cx: float = e.gx + e.fw / 2.0
			var cy: float = e.gy + e.fd / 2.0
			var bh: float = float(load("res://logic/xuong_ve.gd").BH.get(e.type, 40 + e.fd * 30))
			if Vector2(en(cx, cy), nn(cx, cy, bh)).distance_to(w) <= 16.0:
				return {"type": "work", "k": k}
	return null

func _pk_add(L: Array, h: Dictionary, ord: float, dep: float, hit, opt := {}) -> void:   # M(A, h, ord, keys, {gr, mv, bub})
	L.append({"h": h, "ord": ord, "dep": dep, "hit": hit, "gr": int(opt.get("gr", 0)), "mv": bool(opt.get("mv", false)), "bub": bool(opt.get("bub", false))})

func _pk_list(w: Vector2) -> Array:   # C(x, y): mọi thứ quanh chỗ chạm
	var L := []
	var tl := to_tile(w)
	var WR = G.w_all.WR if G.w_all != null else null
	# xưởng: bong bóng (bub), nền (gr 3), thân
	for k in G.xw.list_built():
		var e: Dictionary = G.xw.sr[k]
		var cx: float = e.gx + e.fw / 2.0
		var cy: float = e.gy + e.fd / 2.0
		var c := en(cx, cy)
		var f := nn(cx, cy)
		var bh: float = float(load("res://logic/xuong_ve.gd").BH.get(e.type, 40 + e.fd * 30))
		var inside: bool = tl.x >= e.gx - 0.1 and tl.x < e.gx + e.fw + 0.1 and tl.y >= e.gy - 0.1 and tl.y < e.gy + e.fd + 0.1
		var body := func(p: Vector2) -> bool: return absf(p.x - c) < (e.fw + e.fd) * 13 and p.y >= f - bh + 6 and p.y <= f
		if inside or body.call(w):
			_pk_add(L, {"type": "work", "k": k}, 2, f, body, {"gr": 3 if inside else 0})
	if WR != null:   # chim sáo, gà vịt sổng
		var fl = WR.flock
		if fl != null and not fl.fled:
			_pk_add(L, {"type": "birds"}, 3, nn(float(fl.birds[0].x), float(fl.birds[0].y)), func(p: Vector2) -> bool: return WR.zp(p.x, p.y), {"mv": true})
		var ga = WR.Y0.a
		if ga != null:
			_pk_add(L, {"type": "gavit"}, 5, nn(float(ga.x), float(ga.y)), func(p: Vector2) -> bool: return WR.iq(p.x, p.y), {"mv": true})
	var B = G.troi.bao   # cây ngã / cháy
	var fk: String = B.hit(w)
	if fk != "" and B.by.has(fk):
		var t: Dictionary = B.by[fk]
		_pk_add(L, {"type": "fall", "k": fk}, 7, nn(float(t.gx) + float(t.fw) / 2.0, float(t.gy) + float(t.fd) / 2.0), func(p: Vector2) -> bool: return B.hit(p) == fk)
	for t in PC.x1:   # biển khai hoang
		if pc_own(t) or (PC.G0[t].get("riv", false) and not pc_next(t)):
			continue
		var a: Array = PC.G0[t].sign
		var sgn: String = t
		var hs := func(p: Vector2) -> bool: return sign_at(p) == sgn
		if Vector2(en(a[0] + 0.5, a[1] + 0.5), nn(a[0] + 0.5, a[1] + 0.5) - 30.0).distance_to(w) < 140.0:
			_pk_add(L, {"type": "parcel", "id": t}, 41, nn(a[0] + 0.5, a[1] + 0.5), hs)
	var V = G.vn   # con vật: bong bóng (bub) + thân (mv); chuồng: nền (gr 3) + khung
	if V != null and lang != null:
		var le := sign_le()
		for k in anodes:
			var n = anodes[k]
			var ft: Vector2 = n.foot()
			if n.has_bub() and n.bub_at().distance_to(w) <= 12.0 * le:
				_pk_add(L, {"type": "animal", "k": n.t, "j": n.j}, 42, ft.y, func(_p: Vector2) -> bool: return true, {"bub": true})
			var hh: float = float(n.H5[n.t]) * n.scale_f()
			var hb := func(p: Vector2) -> bool: return absf(p.x - ft.x) < 14.0 and p.y <= ft.y + 3.0 and p.y >= ft.y - hh
			if Rect2(ft.x - 14.0, ft.y - hh, 28.0, hh + 3.0).grow(PK_R / ui.cz()).has_point(w):
				_pk_add(L, {"type": "animal", "k": n.t, "j": n.j}, 42, ft.y, hb, {"mv": true})
		for t in V.DI:
			if not lang.pen_built(t):
				continue
			var pp: Vector2i = lang.pen_pos(t)
			var m: Dictionary = lang.C.mo[t]
			var pw := float(m.w)
			var ph := float(m.h)
			var inside: bool = tl.x >= pp.x and tl.x < pp.x + pw and tl.y >= pp.y and tl.y < pp.y + ph
			var x0 := en(pp.x, pp.y + ph) - 6.0
			var x1 := en(pp.x + pw, pp.y) + 6.0
			var y0 := nn(pp.x, pp.y, 60.0)
			var y1 := nn(pp.x + pw, pp.y + ph) + 6.0
			if inside or (w.x >= x0 and w.x <= x1 and w.y >= y0 and w.y <= y1):
				_pk_add(L, {"type": "pen", "k": t, "j": -1}, 43, nn(pp.x + pw / 2.0, pp.y + ph / 2.0), null, {"gr": 3 if inside else 0})
	# rầy nâu trên ô (r_, mô-đun "ray" ord 10): trong hình thoi (gr 4) hoặc thân cây
	for i in G.B0:
		if not G.owned(i) or not G.has_ray(i):
			continue
		var c: Dictionary = G.cells[i]
		var l := en(c.gx + 0.5, c.gy + 0.5)
		var cc := nn(c.gx + 0.5, c.gy + 0.5, G.CO)
		var dia: bool = absf(w.x - l) / 32.0 + absf(w.y - cc) / 16.0 <= 1.0
		var rh := func(p: Vector2) -> bool: return absf(p.x - l) < 14.0 and p.y > cc - 40.0 and p.y < cc
		if dia or rh.call(w):
			_pk_add(L, {"type": "ray", "i": i}, 10, nn(c.gx + 0.5, c.gy + 0.5) + 14.5, rh, {"gr": 4 if dia else 0})
	# ô ruộng: trong hình thoi mặt ô (gr 4), cây trên ô (hình)
	for i in G.B0:
		if not G.owned(i):
			continue
		var c: Dictionary = G.cells[i]
		var ue := en(c.gx + 0.5, c.gy + 0.5)
		var ce := nn(c.gx + 0.5, c.gy + 0.5, G.CO)
		if absf(w.x - ue) > 32.0 + 12.0 or w.y > ce + 16.0 + 12.0 or w.y < ce - 120.0:
			continue
		var dia: bool = absf(w.x - ue) / 32.0 + absf(w.y - ce) / 16.0 <= 1.0
		var ii: int = i
		var cr := func(p: Vector2) -> bool: return _crop_hit(ii, p)
		_pk_add(L, {"type": "plot", "i": i}, 44, nn(c.gx + 0.5, c.gy + 0.5) + 14.0, cr, {"gr": 4 if dia else 0})
	if not dans.is_empty():   # dân làng (DD, ord 48): trong khung người
		var le := sign_le()
		for x in dans:
			var fx := en(float(x.x), float(x.y))
			var fy := nn(float(x.x), float(x.y))
			var hb := func(p: Vector2) -> bool: return absf(p.x - fx) < 10.0 * le and p.y > fy - 34.0 * le and p.y < fy + 4.0
			_pk_add(L, {"type": "dan", "u": int(x.u)}, 48, fy, hb, {"mv": true})
	if lang != null:   # cây ăn trái (hình), kho (hình + nền), thùng ong
		var O: Array = lang.objs()
		if G.w_all != null:
			G.w_all.WL.uf()   # Uf: số nhà u cho nhà mới đặt
		for idx in O.size():
			var o = O[idx]
			if not (o is Dictionary):
				continue
			var tp = lang.Pi.get(o.id)
			var fw: float = float(tp.fw) if tp != null else 1.0
			var fd: float = float(tp.fd) if tp != null else 1.0
			var cx: float = float(o.gx) + fw / 2.0
			var cy: float = float(o.gy) + fd / 2.0
			var sx := en(cx, cy)
			var sy := nn(cx, cy)
			if absf(w.x - sx) > 140.0 or w.y > sy + 40.0 or w.y < sy - 260.0:
				continue
			var ix: int = idx
			var px := func(p: Vector2) -> bool: return lang_ve.pick_obj(ix, p)
			var isk: bool = o.id == "kho" or o.id == "kho2"
			if lang.C.Ei.has(o.id) or isk:
				var near: bool = lang_ve.obj_rect(idx).grow(PK_RS / ui.cz()).has_point(w)   # loại nhanh theo khung hình
				if lang.C.Ei.has(o.id):
					if near and WR != null and WR.ql(idx) != null:
						_pk_add(L, {"type": "tree", "i": idx}, 45, sy, px)
				else:
					var inside: bool = tl.x >= o.gx and tl.x < o.gx + fw and tl.y >= o.gy and tl.y < o.gy + fd
					if inside or near:
						_pk_add(L, {"type": "khohang", "i": idx}, 46, sy, px, {"gr": 3 if inside else 0})
			elif G.w_all != null and G.w_all.WL.CX.has(o.id) and int(o.get("u", 0)) > 0:   # nhà dân (ord 50)
				var inside2: bool = tl.x >= o.gx and tl.x < o.gx + fw and tl.y >= o.gy and tl.y < o.gy + fd
				if inside2 or lang_ve.obj_rect(idx).grow(PK_RS / ui.cz()).has_point(w):
					_pk_add(L, {"type": "nha", "u": int(o.u)}, 50, sy, px, {"gr": 3 if inside2 else 0})
			elif o.id == "thungong":
				var hb := func(p: Vector2) -> bool: return absf(p.x - sx) < 24.0 and p.y >= sy - 86.0 and p.y <= sy + 8.0
				if hb.call(w):
					_pk_add(L, {"type": "hive", "i": idx}, 49, sy, hb)
		if G.w_all != null:   # nhà có sẵn trên làng (vật cảnh, chưa phải nhà ở): chip "Dọn vào ở"
			for so in lang.SO:
				if not G.w_all.WL.CX.has(so.id) or so.wild or so.ring or not lang.so_shown(so) or not lang.ci(so.pc):
					continue
				var bb: Array = so.bb
				if w.x < float(bb[0]) - 8.0 or w.x > float(bb[2]) + 8.0 or w.y < float(bb[1]) - 8.0 or w.y > float(bb[3]) + 8.0:
					continue
				var ins: bool = tl.x >= so.gx and tl.x < so.gx + so.fw and tl.y >= so.gy and tl.y < so.gy + so.fd
				var oo: Dictionary = so
				_pk_add(L, {"type": "sonha", "o": so}, 50, float(so.sy), func(p: Vector2) -> bool: return lang_ve.pick_so(oo, p), {"gr": 3 if ins else 0})
		var hu = lang.hu_pick(w)   # cây rừng / cỏ hoang (51), ruộng lúa (52, nền gr 1)
		if hu != null:
			if hu.type == "paddy" or (hu.type == "scnlock" and not hu.has("o")):
				_pk_add(L, hu, 52, w.y, null, {"gr": 1})
			else:
				_pk_add(L, hu, 51, float(hu.o.sy), func(_p: Vector2) -> bool: return true)
	return L

func _crop_hit(i: int, w: Vector2) -> bool:   # chạm trúng hình cây trên ô (khung ảnh thu 15% như khung làng)
	var cs: Sprite2D = plots[i].crop
	if not cs.visible or cs.texture == null:
		return false
	var r := Rect2(cs.position + cs.offset * cs.scale, cs.texture.get_size() * cs.scale)
	return r.grow(-r.size.x * 0.15).has_point(w)

func pick(w: Vector2) -> Dictionary:   # RE: thứ bị chạm ({} = nền trống)
	var bb = _pk_bubs(w)
	if bb != null:
		return bb
	var L := _pk_list(w)
	if L.is_empty():
		return {}
	var best = null
	for c in L:   # bong bóng xưởng / con vật
		if c.bub and (best == null or c.ord < best.ord):
			best = c
	if best != null:
		return best.h
	var px = null    # De: trúng hình, trên cùng
	var mv = null    # we: đồ đang đi, gần nhất
	var nr = null    # En: gần hình
	var gd = null    # He: nền
	for c in L:   # lượt 1: chỉ thử đúng điểm chạm (rẻ)
		if c.hit is Callable and c.hit.call(w):
			if px == null or c.dep > px.dep or (c.dep == px.dep and c.ord < px.ord):
				px = c
		if c.gr and (gd == null or c.gr > gd.gr or (c.gr == gd.gr and c.ord < gd.ord)):
			gd = c
	if px != null:
		return px.h
	for c in L:   # lượt 2: đồ đang đi lố tay 12 px
		if c.mv and c.hit is Callable:
			var d := _pk_near(c.hit, w, PK_R)
			if d <= PK_R and (mv == null or d < mv.d):
				mv = {"c": c, "d": d}
	if mv != null:
		return mv.c.h
	if gd != null and gd.gr > 2:
		return gd.h
	for c in L:   # lượt 3: gần hình 8 px
		if not c.mv and c.hit is Callable:
			var d := _pk_near(c.hit, w, PK_RS)
			if d <= PK_RS and (nr == null or d < nr.d):
				nr = {"c": c, "d": d}
	if nr != null:
		return nr.c.h
	if gd != null:
		return gd.h
	return {}

# ------------------------------------------------------------------ jobs (aa.q bản web)
var q := []
var cur = null
var st := 0
var wt := 0.0

func has_job(key: String) -> bool:
	if cur != null and cur.key == key:
		return true
	for j in q:
		if j.key == key:
			return true
	return false

func seeds_queued(s: String) -> int:
	var n := 0
	for j in ([cur] if cur != null else []) + q:
		if j.kind == "plant" and j.seed == s:
			n += 1
	return n

func queue_job(i: int, kind: String, seed: String = "") -> bool:
	var key := "p" + str(i) + kind
	if has_job(key):
		return false
	if q.size() >= 30:
		G.toast.emit("Nhân vật đang có quá nhiều việc rồi.")
		return false
	if kind == "plant":
		var why: String = G.can_plant(i, seed)
		if why == "" and G.sd_n(seed) <= seeds_queued(seed):   # NTWEB sdN (giống lai)
			why = "Hết giống " + G.crop(seed).name.to_lower() + "."
		if why != "":
			G.toast.emit(why)
			return false
	var c: Dictionary = G.cells[i]
	q.append({"key": key, "kind": kind, "i": i, "seed": seed, "pos": Vector2(c.gx + 0.5, c.gy + 1.04)})
	return true

func ext_job(key: String, pos: Vector2, dur: float, run: Callable) -> bool:   # NTWEB Gl / Ns / Px: việc của mô-đun web (đi tới pos rồi chạy run)
	if has_job(key):
		return false
	if q.size() >= 30:
		G.toast.emit("Nhân vật đang có quá nhiều việc rồi.")
		return false
	q.append({"key": key, "kind": "ext", "i": -1, "seed": "", "pos": pos, "dur": dur, "run": run})
	return true

func sleep_go() -> void:   # TV: về nhà (yT 6,3; 4,6) ngủ 12 giây, dậy đầy sức
	if has_job("sleep"):
		return
	if q.size() >= 30:
		G.toast.emit("Nhân vật đang có quá nhiều việc rồi.")
		return
	q.append({"key": "sleep", "kind": "sleep", "i": -1, "seed": "", "pos": Vector2(6.3, 4.6)})
	G.toast.emit("Nhân vật về nhà ngủ một giấc.")

func cook_go(t: String) -> void:   # Ux: về bếp nhà (_T 6,25; 4,35) nấu a.t giây
	var a: Array = G.kg(t)
	if a.is_empty():
		return
	if not G.cook_ok(a):
		G.toast.emit("Hết củi rồi. Mua củi ở bếp, chợ nổi, hoặc dọn cây đổ sau giông." if int(G.g.barn.get("cui", 0)) < 1 else "Kho chưa đủ nguyên liệu.")
		return
	if has_job("cook"):
		G.toast.emit("Đang nấu rồi.")
		return
	if q.size() >= 30:
		G.toast.emit("Nhân vật đang có quá nhiều việc rồi.")
		return
	q.append({"key": "cook", "kind": "cook", "i": -1, "seed": t, "pos": Vector2(6.25, 4.35), "dur": float(a[6])})
	G.toast.emit("Nhân vật về nhà nhóm bếp nấu " + String(a[1]).to_lower() + ".")

func stop_jobs() -> void:
	q.clear()
	cur = null
	st = 0
	G.toast.emit("Đã bỏ hết việc đang chờ.")

func _jobs(dt: float) -> void:
	if cur == null and q.size() > 0:
		cur = q.pop_front()
		st = 1
	if cur == null:
		player.target = Vector2.INF
		return
	if st == 1:
		player.target = cur.pos
		if player.arrived():
			st = 2
			if cur.kind == "walk":
				wt = 0.05
			else:
				wt = (float(cur.dur) if cur.has("dur") else 12.0 if cur.kind == "sleep" else 0.6 if cur.kind == "scn" or cur.kind == "paddy" else 0.35) * (2.0 if G.tired() else 1.0) * ((1.0 - 0.15 * G.fd("liem")) if cur.kind == "harvest" else 1.0)
				player.work = true
		return
	if st == 2:
		wt -= dt
		if wt > 0.0:
			return
		player.work = false
		var j: Dictionary = cur
		cur = null
		st = 0
		var ok := false
		match j.kind:
			"plant":
				ok = G.plant(j.i, j.seed)
				if ok:
					ts(j.i, "plant")
					G.after_plant(j.i, j.seed)   # LV
			"water":
				ok = G.water(j.i)
				if ok:
					ts(j.i, "water")
					G.after_water(j.i)   # CV
			"harvest":
				var c = G.p(j.i).c
				ok = G.harvest(j.i)
				if ok:
					ts(j.i, "harvest", String(c))
					G.after_harvest(j.i, String(c))   # EV
					G.add_xp(int(G.crop(c).get("xp", 1)), "harvest")
			"bug": ok = G.catch_bug(j.i)
			"spray":   # QS: phun thuốc rầy (sạch luôn ô kề), sương thuốc bay lên
				ok = G.spray(j.i)
				if ok:
					var sc: Dictionary = G.cells[j.i]
					burst(Vector2(en(sc.gx + 0.5, sc.gy + 0.5), nn(sc.gx + 0.5, sc.gy + 0.5, G.CO + 10.0)), 14, ["#e8f2f4", "#cfe6ea", "#ffffff"], 60.0, 3.0, 40.0, 2.4, 0.9, 30.0)
			"cook": ok = G.cook_done(j.seed)
			"sleep":
				G.g.pc.en = G.en_max()
				G.toast.emit("Ngủ một giấc dậy khỏe re, sức đầy lại.")
				G.mark()
				ok = true
			"fall": ok = G.troi.bao.chop(j.seed)
			"scn":
				if not G.g.clr.has(j.h.o.key):
					lang.clear_hu(j.h.o)
					ok = true
			"paddy":
				var pk := str(j.h.gx) + "," + str(j.h.gy)
				if not G.g.clr.has(pk):
					lang.clear_paddy(j.h.gx, j.h.gy)
					ok = true
			"work": ok = G.xw.make(j.i_k, j.seed)   # Wh "make": tới xưởng rồi mới xếp món
			"workc": ok = G.xw.collect(j.i_k)
			"animal": ok = vn_do(j.va, j.seed)
			"ext":   # NTWEB: run tự tính sức / kinh nghiệm như bản web
				var rr = j.run.call()
				if rr is bool and rr:
					G.mark()
		if ok:
			var kx: String = "work" if j.kind == "workc" else j.kind
			G.use_en(float(G.D.suc.get(kx, 0)))
			if j.kind != "harvest":
				G.add_xp(int(G.D.xp.get(kx, 1)), kx)
			G.mark()

# ------------------------------------------------------------------ khu đất (ci / e2 / hs bản web)
func pc_own(t: String) -> bool:   # ci
	if t == "nha":
		return true
	var land: Dictionary = G.g.get("land", {})
	var a: String = PC.tg.get(t, t)
	if land.has(a):
		return true
	for n in PC.tg:
		if PC.tg[n] == a and land.has(n):
			return true
	return false

func pc_next(t: String) -> bool:   # e2: kề khu đã có
	if pc_own(t):
		return false
	for a in PC.Oy.get(t, {}):
		if pc_own(a):
			return true
	return false

func sign_le() -> float:
	# le = max(1, min(1,55, 0,9·Wi.s/ba.z))
	return clampf(0.9 * float(ui.kh.s) / maxf(0.05, main.zoom / maxf(1.0, main.dpr)), 1.0, 1.55)

func sign_at(w: Vector2) -> String:   # xz: trong bảng/cọc biển (-42..42, -64..2 x le)
	var le := sign_le()
	for t in PC.x1:
		if pc_own(t) or (PC.G0[t].get("riv", false) and not pc_next(t)):
			continue
		var a: Array = PC.G0[t].sign
		var r := (w.x - en(a[0] + 0.5, a[1] + 0.5)) / le
		var o := (w.y - nn(a[0] + 0.5, a[1] + 0.5, 0.0)) / le
		if r >= -42.0 and r <= 42.0 and o >= -64.0 and o <= 2.0:
			return t
	return ""

func pc_buy(t: String) -> bool:   # pb
	var a: Dictionary = PC.G0.get(t, {})
	if a.is_empty() or pc_own(t):
		return false
	if not pc_next(t):
		G.toast.emit("Hãy khai hoang khu đất bên cạnh trước.")
		return false
	var r := pc_lv(t)
	if r > 0:
		G.toast.emit("Lên cấp " + str(r) + " mới khai hoang được " + String(a.name).to_lower() + ".")
		return false
	if int(G.g.coins) < int(a.cost):
		G.toast.emit("Cần " + G.fmt_n(int(a.cost)) + " xu để khai hoang " + String(a.name).to_lower() + ".")
		return false
	G.g.coins = int(G.g.coins) - int(a.cost)
	if not G.g.has("land"):
		G.g.land = {}
	G.g.land[t] = 1
	_pc_fx(t)
	G.toast.emit(("Đã mở " if a.get("riv", false) else "Đã khai hoang ") + String(a.name).to_lower() + ". " + String(a.desc))
	G.mark()
	if main.has_method("land_changed"):
		main.land_changed(G.g.land)
	return true

func _pc_fx(t: String) -> void:
	# YW: bụi đất + sao vàng bung ở giữa khu vừa mở
	var c: Array = PC.G0[t].c
	var p := Vector2(en(c[0], c[1]), nn(c[0], c[1], 10.0))
	var e := CPUParticles2D.new()
	e.position = p
	e.z_index = 45
	e.amount = 26
	e.one_shot = true
	e.explosiveness = 1.0
	e.lifetime = 0.9
	e.direction = Vector2(0, -1)
	e.spread = 180.0
	e.initial_velocity_min = 40.0
	e.initial_velocity_max = 130.0
	e.gravity = Vector2(0, 300)
	e.scale_amount_min = 2.0
	e.scale_amount_max = 5.2
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color("#fff3b0"), Color("#dba013"), Color("#a4764d"), Color(0.89, 0.82, 0.61, 0.0)])
	gr.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	e.color_ramp = gr
	add_child(e)
	e.emitting = true
	get_tree().create_timer(1.5).timeout.connect(e.queue_free)

func pc_lv(t: String) -> int:   # hs: cấp còn thiếu (0 = đủ cấp)
	if pc_own(t):
		return 0
	var a := int(PC.Hy.get(t, 1))
	return a if G.lv() < a else 0

# ------------------------------------------------------------------ nodes
# ------------------------------------------------------------------ xưởng chế biến (xuong.gd, vẽ ở xuong_ve.gd)
var xnodes := {}       # khoá xưởng -> node
var _xw_sig := ""
func _xw_sync() -> void:
	var L: Array = G.xw.list_built()
	var gh: String = ui.bdp.fmv if ui.bdp != null else ""
	if gh != "" and not L.has(gh):   # đang chọn chỗ xây: vẽ xưởng ở chỗ đang đặt (web I5)
		L.append(gh)
	var sig := ""
	for k in L:
		var s: Dictionary = G.xw.sr[k]
		sig += k + str(s.gx) + "," + str(s.gy) + ";"
	if lang != null:
		sig += "|" + str(lang.ver)
	if sig == _xw_sig:
		return
	_xw_sig = sig
	for k in xnodes.keys():   # bỏ xây / hủy: gỡ hình
		if not L.has(k):
			var n0: Node2D = xnodes[k]
			for e in sortables:
				if e[0] == n0:
					sortables.erase(e)
					break
			n0.queue_free()
			xnodes.erase(k)
	var rects := {}
	for k in L:
		var s: Dictionary = G.xw.sr[k]
		rects[k] = [s.gx, s.gy, s.fw, s.fd, s.type]
		var dk := nn(s.gx + s.fw / 2.0, s.gy + s.fd / 2.0) - 3.2   # $p(gx+gy+(fw+fd)/2-.2)
		if not xnodes.has(k):
			var n := Node2D.new()
			n.set_script(load("res://logic/xuong_ve.gd"))
			n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			main.obj_root.add_child(n)
			n.setup(self, k)
			sortables.insert(sortables.size() - 1, [n, dk, -2])
			xnodes[k] = n
		else:
			for e in sortables:
				if e[0] == xnodes[k]:
					e[1] = dk
					e[2] = -2
	_resort()
	# bên nền dọn cây cảnh / đồ trang trí nằm trên chỗ xưởng (web jz: g.mv dời đi)
	if lang != null:   # chuồng đã xây + vật cảnh đã nhận / cây cỏ đã dọn
		rects.merge(lang.hidden_rects())
		for p in lang.CO:
			if lang.pen_built(p) or (ui.bdp != null and ui.bdp.fmv == p):
				var pp = lang.pen_pos(p)
				rects["pen" + p] = [pp.x, pp.y, int(lang.C.mo[p].w), int(lang.C.mo[p].h), p]
	if main.has_method("xuong_set"):
		main.xuong_set(rects)

func xw_at(w: Vector2) -> String:   # lz bản web: chạm trúng nền, thân xưởng hoặc bong bóng
	var tl := to_tile(w)
	for k in G.xw.list_built():
		var e: Dictionary = G.xw.sr[k]
		var cx: float = e.gx + e.fw / 2.0
		var cy: float = e.gy + e.fd / 2.0
		var c := en(cx, cy)
		var f := nn(cx, cy)
		var bh: float = float(load("res://logic/xuong_ve.gd").BH.get(e.type, 40 + e.fd * 30))
		if (tl.x >= e.gx - 0.1 and tl.x < e.gx + e.fw + 0.1 and tl.y >= e.gy - 0.1 and tl.y < e.gy + e.fd + 0.1) or (absf(w.x - c) < (e.fw + e.fd) * 13 and w.y >= f - bh + 6 and w.y <= f):
			return k
		if G.xw.df(k) > 0 and absf(w.x - c) < 16 and absf(w.y - nn(cx, cy, bh)) < 16:
			return k
	return ""

func xw_job(k: String, kind: String, rid := "") -> void:   # Wh: nhân vật đi tới GR rồi làm (0,35 s)
	var key := ("wk" + k + ":" + str(Time.get_ticks_usec())) if kind == "work" else ("wkc" + k)
	if has_job(key):
		return
	q.append({"key": key, "kind": kind, "i": -1, "i_k": k, "seed": rid, "pos": G.xw.stand(k)})

func xw_queued(k: String) -> int:   # v(): số việc "làm món" đang chờ đi tới xưởng này
	var n := 0
	for j in ([cur] if cur != null else []) + q:
		if j.kind == "work" and j.get("i_k", "") == k:
			n += 1
	return n

func xw_tap(k: String) -> void:   # sG: xong thì thu luôn, chưa thì mở bảng xưởng
	if G.xw.df(k) > 0:
		G.xw.collect(k)
		return
	ui.xf_open(k)

# ------------------------------------------------------------------ vật nuôi (mc / az / kW / EW bản web)
const XW := {"ga": 0.55, "cuu": 0.34, "bo": 0.26, "heo": 0.3, "de": 0.4}   # tốc độ đi trong chuồng (ô/giây)
var anodes := {}       # "loại:j" -> node vẽ con vật (vatnuoi_ve.gd)

func _pen_rand(t: String, m: Dictionary) -> void:   # chỗ ngẫu nhiên trong chuồng (gà chừa máng phía sau)
	var a: Dictionary = lang.C.mo[t]
	var p: Vector2i = lang.pen_pos(t)
	var g := t == "ga"
	m.tx = p.x + 0.4 + randf() * (float(a.w) - 0.8)
	m.ty = p.y + (0.8 if g else 0.4) + randf() * (float(a.h) - (1.2 if g else 0.8))

func _vn_sync(dt: float) -> void:
	var V = G.vn
	if V == null or lang == null:
		return
	var still: bool = G.motion_off()
	var want := {}
	for t in V.DI:
		if not lang.pen_built(t) or not V.ok(t):
			V.mc[t] = []
			continue
		var n: int = V.list(t).size()
		var L: Array = V.mc.get(t, [])
		while L.size() > n:
			L.pop_back()
		while L.size() < n:   # az: con mới đứng chỗ ngẫu nhiên
			var m := {"wait": randf() * 2.0, "dir": 1 if randf() < 0.5 else -1, "ph": randf() * 6.0, "mv": false}
			_pen_rand(t, m)
			m.x = m.tx
			m.y = m.ty
			L.append(m)
		V.mc[t] = L
		var sp: float = XW[t] * dt
		for j in n:
			var m: Dictionary = L[j]
			want[t + ":" + str(j)] = [t, j]
			if still:   # kW: tắt chuyển động thì đứng yên
				m.mv = false
				continue
			if float(m.wait) > 0.0:
				m.wait = float(m.wait) - dt
				m.mv = false
				if float(m.wait) <= 0.0:
					_pen_rand(t, m)
				continue
			var dx: float = float(m.tx) - float(m.x)
			var dy2: float = float(m.ty) - float(m.y)
			var l := sqrt(dx * dx + dy2 * dy2)
			if l <= sp:
				m.x = m.tx
				m.y = m.ty
				m.wait = 0.8 + randf() * 3.2
				m.mv = false
				continue
			m.x = float(m.x) + dx / l * sp
			m.y = float(m.y) + dy2 / l * sp
			m.mv = true
			m.ph = float(m.ph) + dt * (13.0 if t == "ga" else 9.0)
			var f := dx - dy2
			if absf(f) > 0.001:
				m.dir = 1 if f > 0.0 else -1
	for k in anodes.keys():   # bán / hết chuồng: gỡ hình
		if not want.has(k):
			var n0: Node2D = anodes[k]
			for e in sortables:
				if e[0] == n0:
					sortables.erase(e)
					break
			n0.queue_free()
			anodes.erase(k)
	for k in want:
		var t: String = want[k][0]
		var j: int = want[k][1]
		var m: Dictionary = V.mc[t][j]
		var dk := nn(float(m.x), float(m.y))
		if not anodes.has(k):
			var n := Node2D.new()
			n.set_script(load("res://logic/vatnuoi_ve.gd"))
			n.farm = self
			n.t = t
			n.j = j
			n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			main.obj_root.add_child(n)
			sortables.insert(sortables.size() - 1, [n, dk, -2])
			anodes[k] = n
		else:
			for e in sortables:
				if e[0] == anodes[k]:
					e[1] = dk
					break

# ------------------------------------------------------------------ con vật đi lạc (gà vịt sổng, chim sáo): luật ở w_ruong.gd
var cnodes := []   # [con vật (Dictionary của luật), node thu_ve]

func _crit_sync() -> void:
	var L: Array = G.w_all.WR.critters() if G.w_all != null and G.w_all.WR != null else []
	for k in range(cnodes.size() - 1, -1, -1):
		var c: Array = cnodes[k]
		if L.any(func(x): return is_same(x, c[0])):
			continue
		for e in sortables:
			if e[0] == c[1]:
				sortables.erase(e)
				break
		c[1].queue_free()
		cnodes.remove_at(k)
	var WR = G.w_all.WR if G.w_all != null else null
	for x in L:
		var dk := nn(float(x.x), float(x.y))
		# đang đậu / bới trong ô ruộng: vẽ trước cây lúa của ô (Cy: k = gx + gy + 1,06 của ô)
		var pl := -1
		if WR.flock != null and int(x.get("st", -1)) == 1:
			pl = int(WR.flock.plot)
		elif is_same(x, WR.Y0.a) and int(WR.Y0.st) == 1:
			pl = int(WR.Y0.plot)
		if pl >= 0:
			dk = nn(G.cells[pl].gx + 0.5, G.cells[pl].gy + 0.5) + 15.0
		var n: Node2D = null
		for c in cnodes:
			if is_same(c[0], x):
				n = c[1]
				break
		if n == null:
			n = Node2D.new()
			n.set_script(load("res://logic/thu_ve.gd"))
			n.farm = self
			n.a = x
			main.obj_root.add_child(n)
			sortables.insert(sortables.size() - 1, [n, dk, -2])
			cnodes.append([x, n])
			continue
		for e in sortables:
			if e[0] == n:
				e[1] = dk
				break

# ------------------------------------------------------------------ dân làng trên làng (ID: người làm thuê đi làm, FD: người đứng trước nhà)
var dnodes := {}   # khóa -> node dan_ve
var dans := []     # [{key, u, x, y, lk, mv, ph, face, wave, carry, bob}] khung này

func _dan_list(tt: float) -> Array:
	var out := []
	if G.w_all == null or G.g.get("lang") == null:
		return out
	var WL = G.w_all.WL
	var fam: Dictionary = WL._r0().fam
	for n in WL.ac:
		if WL.tu(n) or not fam.has(n):
			continue
		var r: Dictionary = WL.ac[n]
		out.append({"key": "a" + str(n), "u": int(r.u), "n": String(fam[n].n), "x": r.x, "y": r.y, "lk": int(fam[n].get("lk", 0)), "mv": int(r.st) == 1 or int(r.st) == 2,
			"ph": r.ph, "face": r.face, "carry": r.carry, "bob": int(r.st) == 2})
	if not G.night and not (ui.bdp != null and ui.bdp.mode == "place"):
		for h in WL.bl():
			var f = fam.get(str(h.u))
			if f == null or WL._tr(f.get("job")) or WL.zk(h.u):
				continue
			var p: Vector2 = WL._home(h.u)
			out.append({"key": "h" + str(h.u), "u": int(h.u), "n": String(f.n), "x": p.x, "y": p.y, "lk": int(f.get("lk", 0)), "mv": false, "ph": 0.0,
				"face": 1 if String(h.r.id).ends_with("2") else -1, "wave": WL._tr(f.get("req")) and sin(tt * 0.8 + float(h.u)) > 0.6, "carry": null, "bob": false})
	return out

func _dan_sync(tt: float) -> void:
	dans = _dan_list(tt)
	var seen := {}
	for x in dans:
		seen[x.key] = 1
		var n = dnodes.get(x.key)
		var dk := nn(float(x.x), float(x.y))
		if n == null:
			n = Node2D.new()
			n.set_script(load("res://logic/dan_ve.gd"))
			n.farm = self
			n.d = x
			main.obj_root.add_child(n)
			sortables.insert(sortables.size() - 1, [n, dk, -2])
			dnodes[x.key] = n
			continue
		n.d = x
		for e in sortables:
			if e[0] == n:
				e[1] = dk
				break
	for k in dnodes.keys():
		if seen.has(k):
			continue
		var n: Node2D = dnodes[k]
		for e in sortables:
			if e[0] == n:
				sortables.erase(e)
				break
		n.queue_free()
		dnodes.erase(k)

# ------------------------------------------------------------------ bong bóng trên cây ăn trái (Ij) và thùng ong (Aq)
var tbubs := {}    # idx g.objs -> Bubble (dùng chung bong bóng ô ruộng)

func _tree_bub_sync(tt: float) -> void:
	var want := {}
	var WR = G.w_all.WR if G.w_all != null else null
	var off: bool = ui.bdp == null or ui.bdp.mode == "off"
	if WR != null and lang != null and off:
		var O: Array = lang.objs()
		for i in O.size():
			var o = O[i]
			if not (o is Dictionary):
				continue
			if lang.C.Ei.has(o.id):
				var t = WR.ql(i)
				if t == null:
					continue
				if WR.wc(t):
					want[i] = ["ripe", String(lang.C.Ei[o.id].p)]
				elif float(t.fw) <= 0.0:
					want[i] = ["drop", ""]
			elif o.id == "thungong" and WR.hive_h(i) > 0:
				want[i] = ["ripe", "mat_ong"]
			elif G.w_all.WL.CX.has(o.id) and int(o.get("u", 0)) > 0:   # FD: nhà đang cần đồ (hình món) / mời trò chuyện (...)
				var f = G.w_all.WL._fam_of(int(o.u))
				if f != null and G.w_all.WL._tr(f.get("req")):
					want[i] = ["ripe", String(f.req.id)]
				elif f != null and int(f.get("mo", 0)) == 1 and G.w_all.WL.chat_left(f) > 0:
					want[i] = ["chat", ""]
	for i in tbubs.keys():
		if not want.has(i):
			tbubs[i].queue_free()
			tbubs.erase(i)
	var still: bool = G.motion_off()
	for i in want:
		var b: Bubble = tbubs.get(i)
		if b == null:
			b = Bubble.new()
			b.fnt = fnt
			b.farm = self
			b.z_index = 40
			add_child(b)
			tbubs[i] = b
		var o: Dictionary = lang.objs()[i]
		var tp = lang.Pi.get(o.id)
		var cx: float = float(o.gx) + (float(tp.fw) if tp != null else 1.0) / 2.0
		var cy: float = float(o.gy) + (float(tp.fd) if tp != null else 1.0) / 2.0
		var bob := 0.0 if still else sin(tt * 3.0 + i) * 1.2
		var top: float = (lang_ve.top_of(o) + 2.0) if o.id != "thungong" else -74.0   # Ij: đỉnh hình + 8 - 6; Aq: sy - 74
		if G.w_all.WL.CX.has(o.id):
			top = lang_ve.top_of(o) + 18.0   # FD: sy + Jo().y + 18
		b.position = Vector2(en(cx, cy), nn(cx, cy) + top + bob)
		b.kind = want[i][0]
		b.id = want[i][1]
		b.text = ""
		b.can = true
		b.visible = true
		b.k = (1.0 + 0.08 * sin(tt * 5.0 + b.position.x)) * sign_le()
		b.zoom = main.zoom
		b.queue_redraw()

func vn_job(t: String, j: int, act: String) -> bool:   # Ns: nhân vật đi tới con vật rồi làm (0,35 s; vuốt ve 0,8 s)
	var key := "animal:" + t + ":" + str(j) + ":" + act
	if has_job(key):
		return false
	if q.size() >= 30:
		G.toast.emit("Nhân vật đang có quá nhiều việc rồi.")
		return false
	var m: Vector2 = G.vn.spot(t, j)
	q.append({"key": key, "kind": "animal", "i": -1, "va": [t, j], "seed": act, "pos": Vector2(m.x, m.y + 0.3), "dur": 0.8 if act == "pet" else 0.35})
	return true

func vn_do(va: Array, act: String) -> bool:   # lG / kZ khi nhân vật tới nơi
	var V = G.vn
	var t: String = va[0]
	var j: int = va[1]
	var e = V.a(t, j)
	if e == null:
		return false
	match act:
		"pet": return V.pet(t, j)
		"collect":
			var m: String = V.collect(t, j)
			if m != "":
				var f: Vector2 = anodes[t + ":" + str(j)].foot() if anodes.has(t + ":" + str(j)) else Vector2.ZERO
				burst(f + Vector2(0, -20), 10, ["#fff3b0", "#ffffff", PY.get(m, "#fff3b0")], 100.0, 2.6, 300.0, 2.4, 0.7, 6.0, true)
			return m != ""
		"feed": return V.feed(t, j)
	return false

# ------------------------------------------------------------------ cây ngã sau giông (bao.gd): vẽ bằng code như zK bản web
var fells := {}        # sk -> FellNode
var _fell_v := -1
func _fell_sync(tt: float, zz: float) -> void:
	var B = G.troi.bao
	var f: Dictionary = B.wx().fell
	if B.ver != _fell_v:
		_fell_v = B.ver
		var hide := {}
		for k in f:
			if not B.by.has(k):
				continue
			var t: Dictionary = B.by[k]
			hide[k] = [t.gx, t.gy, t.fw, t.fd, t.id]
			if not fells.has(k):
				var n := FellNode.new()
				n.farm = self
				n.t = t
				var cx := float(t.gx) + float(t.fw) / 2.0
				var cy := float(t.gy) + float(t.fd) / 2.0
				n.position = Vector2(en(cx, cy), nn(cx, cy))
				n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				main.obj_root.add_child(n)
				sortables.insert(sortables.size() - 1, [n, nn(cx, cy), -2])   # nhân vật luôn ở cuối danh sách
				fells[k] = n
		# bên nền giấu cây gốc (d6 bản web thay hình cây bằng cây ngã / cháy / cây con)
		if main.has_method("cay_an"):
			main.cay_an(hide)
	for k in fells:
		var n: FellNode = fells[k]
		n.st = f.get(k, {})
		n.visible = not n.st.is_empty()
		if n.visible:
			n.tt = tt
			n.zz = zz
			n.queue_redraw()

func onscreen(gx: float, gy: float, m: float) -> bool:   # Wr: điểm ô (gx, gy) trong màn hình, nới m px
	var p := world_to_screen(Vector2(en(gx, gy), nn(gx, gy)))
	var v := get_viewport_rect().size
	var k: float = m * maxf(1.0, main.dpr)
	return p.x > -k and p.y > -k and p.x < v.x + k and p.y < v.y + k

var parts := []        # L5 bản web: hạt văng (vụn củi, lá)
func burst(p: Vector2, n: int, cols: Array, v: float, spread: float, g: float, r: float, life: float, w: float, star := false) -> void:   # ro
	for o in n:
		var l := -1.5708 + (randf() - 0.5) * spread
		var c := v * (0.45 + randf() * 0.75)
		parts.append({"x": p.x + (randf() - 0.5) * w, "y": p.y, "vx": cos(l) * c, "vy": sin(l) * c, "g": g, "age": 0.0,
			"life": life * (0.7 + randf() * 0.6), "r": r * (0.7 + randf() * 0.8), "col": Color(cols[o % cols.size()]), "star": star and o % 2 == 0})
	if parts.size() > 260:
		parts = parts.slice(parts.size() - 260)

var rings := []        # hy bản web: vòng sáng loang (ph)
func ph(p: Vector2, col: String, rx: float, life: float) -> void:
	rings.append({"x": p.x, "y": p.y, "col": Color(col), "rx": rx, "age": 0.0, "life": life})

const PY := {"lua": "#e6b93c", "carot": "#ef8c2b", "cachua": "#dc3b2f", "dau": "#df3550", "bap": "#f2c63a"}
var dy := {}           # dy bản web: ô vừa gieo (nảy lên) / vừa tưới, thu (lắc)
func ts(i: int, kind: String, c := "") -> void:   # Ts: hiệu ứng khi gieo / tưới / thu / mở ô
	var cl: Dictionary = G.cells[i]
	var e := Vector2(en(cl.gx + 0.5, cl.gy + 0.5), nn(cl.gx + 0.5, cl.gy + 0.5, G.CO))
	var pal = G.troi.st.get("pal", {}) if G.troi != null else {}
	var r := String(pal.get("accent", "#dba013"))
	match kind:
		"plant":
			burst(e + Vector2(0, -2), 7, ["#7a5236", "#a4764d", "#5e3d29"], 62.0, 2.2, 320.0, 2.0, 0.55, 10.0)
			dy[i] = {"k": "plant", "t": _now()}
		"water":
			burst(e + Vector2(0, -10), 10, ["#7cc6f4", "#bfe6fb", "#4aa8ee"], 50.0, 2.8, 340.0, 1.9, 0.6, 18.0)
			ph(e, "#a9dcf6", 22.0, 0.5)
			dy[i] = {"k": "water", "t": _now()}
		"harvest":
			var o := String(PY.get(c, "#fff3b0"))
			burst(e + Vector2(0, -12), 13, [o, "#fff3b0", o, String(pal.get("leaf2", "#7bbf53"))], 130.0, 2.6, 340.0, 2.6, 0.8, 10.0, true)
			ph(e, r, 26.0, 0.55)
			G.vib(12)
		"unlock":
			burst(e, 12, ["#e3d09b", "#fff3b0", "#a4764d"], 90.0, 2.6, 300.0, 2.4, 0.7, 24.0, true)
			ph(e, r, 30.0, 0.6)
			G.vib(18)

func _parts_step(dt: float) -> void:
	for a in rings:
		a.age += dt
	rings = rings.filter(func(a): return a.age < a.life)
	for a in parts:
		a.age += dt
		a.vy += a.g * dt
		a.x += a.vx * dt
		a.y += a.vy * dt
	parts = parts.filter(func(a): return a.age < a.life)

class FellNode extends Node2D:
	var farm
	var t := {}
	var st := {}
	var tt := 0.0
	var zz := 1.0
	func m(d: String, n: String) -> Color:
		return Color(n) if farm.G.night else Color(d)
	func na(c: Color) -> Color:   # na(c, -.5): trộn đen 50%
		return c.lerp(Color.BLACK, 0.5)
	func L(x: float, y: float, rx: float, ry: float, col: Color, rot := 0.0) -> void:
		var pts := PackedVector2Array()
		for a in 24:
			var u := a / 24.0 * TAU
			pts.append(Vector2(x, y) + Vector2(cos(u) * rx, sin(u) * ry).rotated(rot))
		draw_colored_polygon(pts, col)
	func Dt(x0: float, y0: float, x1: float, y1: float, col: Color, w: float) -> void:   # nét bo tròn hai đầu
		draw_line(Vector2(x0, y0), Vector2(x1, y1), col, w, true)
		draw_circle(Vector2(x0, y0), w / 2.0, col, true, -1.0, true)
		draw_circle(Vector2(x1, y1), w / 2.0, col, true, -1.0, true)
	func N() -> Array:   # IN
		match t.id:
			"banana": return ["#5fae3e", "#7cc24a", "#4a8e30"]
			"coconut", "areca": return ["#4e9a3a", "#6cb84a", "#3a7a2e"]
			"bamboo": return ["#7ab84a", "#9ad05a", "#5a9a3a"]
		return ["#3e7a2e", "#5aa83a", "#4d9a34"]
	func leaf(i: int) -> Color:
		var c := Color(N()[i % 3])
		return na(c) if farm.G.night else c
	func _draw() -> void:
		if st.is_empty():
			return
		var gx := float(t.gx)
		var gy := float(t.gy)
		if st.s == "grow":
			var f := minf(1.0, (farm.G.troi.bao.now() - float(st.at)) / farm.G.troi.bao.ON)
			var s := 8.0 + f * 30.0
			L(0, 1, 6 + f * 8, 2 + f * 3, Color(0, 0, 0, 0.15))
			L(-4, 0, 4, 2, m("#7a5a36", "#3e2e1c"))
			Dt(0, 0, 0, -s, m("#6a4a2a", "#3a2818"), 1.4 + f * 2.4)
			for c in 5 + int(floor(f * 6.0)):
				var h := -PI / 2.0 + (c - 3) * 0.55
				L(cos(h) * (4 + f * 10), -s + sin(h) * (3 + f * 5), 3 + f * 5, 1.8 + f * 2.4, leaf(c), h)
			return
		if st.s == "burn":
			var p := 0.5 + 0.5 * sin(tt * 11.0 + gx)
			var dk := m("#2a1a10", "#120a06")
			L(0, 1, 14, 4, Color(0, 0, 0, 0.25))
			draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(-3, -34), Vector2(1, -42), Vector2(4, -30), Vector2(5, 0)]), dk)
			Dt(-1, -26, -12, -38, dk, 2)
			Dt(2, -32, 12, -44, dk, 1.6)
			L(1, -40, 3 + p * 2, 4 + p * 3, Color(1, 140 / 255.0, 40 / 255.0, 0.6 * p))
			for c in 4:
				var d := fmod(tt * 10.0 + c * 9.0, 40.0)
				L(sin(tt + c) * 4, -44 - d, 4 + d * 0.15, 3 + d * 0.12, Color(0x55 / 255.0, 0x55 / 255.0, 0x55 / 255.0, 0.35))
			_bub(0, -70)
			return
		var v: Array = st.get("d", [1, 0])
		var x := maxf(0.0001, Vector2(v[0], v[1]).length())
		var k := float(v[0]) / x
		var M := float(v[1]) / x
		var T := 1.6 if t.id == "coconut" or t.id == "areca" else 1.2
		var C := (k * T - M * T) * 32.0
		var R := (k * T + M * T) * 16.0
		L(C / 2.0, R / 2.0 + 2, 32, 9, Color(0, 0, 0, 0.16))
		L(0, -5, 7, 8, m("#6a4a2a", "#3a2818"))
		L(0, -5, 4.4, 5.2, m("#9a7448", "#56402a"))
		var rc := m("#5a3e22", "#2e2014")
		for c in 6:
			var rt := c * 1.05
			draw_line(Vector2(cos(rt) * 5, -5 + sin(rt) * 6), Vector2(cos(rt) * 10, -5 + sin(rt) * 11), rc, 1.3, true)
		var dt: Color
		if t.id == "coconut" or t.id == "areca":
			dt = m("#8a7458", "#4a3a2a")
		elif t.id == "banana":
			dt = m("#7a9a4a", "#3a4a24")
		else:
			dt = m("#6a4a2a", "#3a2818")
		Dt(0, -5, C, R - 4, m("#4a3420", "#241810"), 11 if t.id == "banana" else 8)
		Dt(0, -6, C, R - 5, dt, 9 if t.id == "banana" else 6)
		if t.id == "coconut" or t.id == "areca":
			for c in 9:
				var W := c * 0.7 + 0.3
				L(C + cos(W) * 13, R - 5 + sin(W) * 13, 13, 2.6, leaf(c), W)
			if t.id == "coconut":
				L(C - 3, R - 2, 3, 3, m("#5a8a2a", "#2e4a1a"))
				L(C + 3, R - 1, 3, 3, m("#6a9a2a", "#344e1a"))
		elif t.id == "banana":
			for c in 6:
				var K := c * 1.05
				L(C + cos(K) * 12, R - 6 + sin(K) * 12, 12, 4.4, leaf(c), K)
				var o := Vector2(C, R - 6)
				draw_line(o, o + Vector2(cos(K), sin(K)) * 22, m("#c9d88a", "#5a6a3a"), 0.6, true)
		else:
			for c in 16:
				var ft: float = farm.G.nv.Me(c, int(gx) * 3 + int(gy))
				var j: float = farm.G.nv.Me(c * 3 + 1, int(gy) * 7 + int(gx))
				L(C + (ft - 0.5) * 30, R - 4 - j * 16, 6 + ft * 4, 4.2 + j * 2, leaf(c))
		_bub(C / 2.0, minf(0.0, R) - 28 + sin(tt * 3.0 + gx) * 1.2)
	func _bub(x: float, y: float) -> void:   # X0(x, y, "cui", true): bong bóng củi, chỉ khi zoom >= 0,6
		if zz < 0.6:
			return
		var s: float = (1.0 + 0.08 * sin(tt * 5.0 + x)) * farm.sign_le()
		Bong.ve(self, Vector2(x, y), s, farm.ui.icon("cui", 17.0 * s * farm.main.zoom), false, 17.0)

class ParcelLines extends Node2D:
	# đường biên khu (TH.lot bản web, chép sẵn ra parcel_lot.json): nét đứt 7/6, dày 2,4, màu accent
	var farm
	var paths := {}   # id -> [PackedVector2Array, ...] (mỗi đoạn moveTo một mảng; Z thì nối về điểm đầu)
	var on := []
	var sig := ""
	func _ready() -> void:
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://ui/snap/parcel_lot.json"))
		for id in d.p:
			var L := []
			var cur := PackedVector2Array()
			for op in d.p[id]:
				match String(op[0]):
					"M":
						if cur.size() > 1:
							L.append(cur)
						cur = PackedVector2Array([Vector2(op[1], op[2])])
					"L":
						cur.append(Vector2(op[1], op[2]))
					"Z":
						if cur.size() > 1:
							cur.append(cur[0])
							L.append(cur)
						cur = PackedVector2Array()
			if cur.size() > 1:
				L.append(cur)
			paths[id] = L
	func sync() -> void:
		var G = farm.G
		var L := []
		for id in farm.PC.x1:
			if farm.pc_next(id) and int(G.g.coins) >= int(farm.PC.G0[id].cost):
				L.append(id)
		var s := str(G.night) + ",".join(L)
		if s != sig:
			sig = s
			on = L
			queue_redraw()
	var seg := PackedVector2Array()   # NTBAKE: mọi nét đứt gom vào 1 lệnh draw_multiline
	func _draw() -> void:
		var c := Color("#f0bd3d") if farm.G.night else Color("#dba013")
		seg = PackedVector2Array()
		for id in on:
			for pl in paths.get(id, []):
				_dash(pl, c)
		if seg.size() > 1:
			draw_multiline(seg, c, 2.4, true)
	func _dash(pl: PackedVector2Array, c: Color) -> void:
		# canvas: mẫu 7 nét / 6 hở chạy liền qua các góc, bắt đầu lại ở mỗi moveTo
		var pen := true
		var left := 7.0
		var run := PackedVector2Array()
		for i in pl.size() - 1:
			var a: Vector2 = pl[i]
			var b: Vector2 = pl[i + 1]
			var n := a.distance_to(b)
			var t := 0.0
			while t < n:
				var st := minf(left, n - t)
				var p0 := a.lerp(b, t / n)
				var p1 := a.lerp(b, (t + st) / n)
				if pen:
					if run.is_empty():
						run.append(p0)
					run.append(p1)
				t += st
				left -= st
				if left <= 0.0001:
					if pen and run.size() > 1:
						_put(run)
					run = PackedVector2Array()
					pen = not pen
					left = 7.0 if pen else 6.0
		if pen and run.size() > 1:
			_put(run)
	func _put(run: PackedVector2Array) -> void:
		for i in run.size() - 1:
			seg.append(run[i])
			seg.append(run[i + 1])

class ParcelSign extends Node2D:
	# JW: cọc gỗ + bảng bo góc 80x30, "Khai hoang"/"Mở khúc sông", dòng 2: "🔒 Cấp N" / "N xu" / ổ khóa
	# NTBAKE (bản 76): biển là đồ tĩnh -> vẽ MỘT lần vào SubViewport (UPDATE_ONCE) rồi hiện bằng Sprite2D (1 lệnh vẽ).
	# Chỉ vẽ lại khi đổi ngày/đêm, khóa, cấp, đủ xu. Viền nhấp nháy = ảnh viền riêng, chỉ đổi độ mờ. Phóng to = đổi scale.
	const K := 3.0                       # điểm ảnh mỗi đơn vị biển
	const BOX := Rect2(-44, -66, 88, 75)  # khung biển + bóng + viền sáng
	var farm
	var id := ""
	var sig := ""
	var pulse := false
	var hold: Node2D
	var vp: SubViewport
	var vg: SubViewport
	var body: Sprite2D
	var glow: Sprite2D
	func _ready() -> void:
		hold = Node2D.new()
		add_child(hold)
		vp = _mk_vp(false)
		vg = _mk_vp(true)
		body = _mk_sp(vp)
		glow = _mk_sp(vg)
		glow.visible = false
	func _mk_vp(g: bool) -> SubViewport:
		var v := SubViewport.new()
		v.size = Vector2i(int(BOX.size.x * K), int(BOX.size.y * K))
		v.transparent_bg = true
		v.disable_3d = true
		v.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var a := SignArt.new()
		a.sg = self
		a.glow = g
		v.add_child(a)
		add_child(v)
		return v
	func _mk_sp(v: SubViewport) -> Sprite2D:
		var sp := Sprite2D.new()
		sp.centered = false
		sp.texture = v.get_texture()
		sp.position = BOX.position
		sp.scale = Vector2.ONE / K
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		hold.add_child(sp)
		return sp
	func sync() -> void:
		var G = farm.G
		var own: bool = farm.pc_own(id)
		visible = not own and not farm.sign_off and not (farm.PC.G0[id].get("riv", false) and not farm.pc_next(id))
		var o: bool = farm.pc_next(id)
		var r: int = farm.pc_lv(id)
		var l: bool = o and r == 0 and int(G.g.coins) >= int(farm.PC.G0[id].cost)
		pulse = l
		var s := str(G.night) + str(o) + str(r) + str(l)
		if s != sig and visible and vp != null:
			sig = s
			vp.get_child(0).queue_redraw()
			vg.get_child(0).queue_redraw()
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			vg.render_target_update_mode = SubViewport.UPDATE_ONCE
	var _le := 0.0
	func _process(_dt: float) -> void:
		if not visible or hold == null:
			return
		if sig == "":
			sync()
		var le: float = farm.sign_le()
		if absf(le - _le) > 0.002:
			_le = le
			hold.scale = Vector2(le, le)
		glow.visible = pulse
		if pulse:
			glow.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)

class SignArt extends Node2D:   # nét vẽ biển Khai hoang (như cũ), vẽ trong SubViewport của ParcelSign
	var sg
	var glow := false
	static func _rr(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
		var p := PackedVector2Array()
		var cs := [[x + w - r, y + r, -PI / 2], [x + w - r, y + h - r, 0.0], [x + r, y + h - r, PI / 2], [x + r, y + r, PI]]
		for c in cs:
			for k in 9:
				var t: float = c[2] + PI / 2 * k / 8.0
				p.append(Vector2(c[0] + cos(t) * r, c[1] + sin(t) * r))
		return p
	func _txt(f: Font, s: String, y: float, fs: float, col: Color) -> void:
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(-w / 2.0, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	func _draw() -> void:
		var farm = sg.farm
		var G = farm.G
		var id: String = sg.id
		var n: Dictionary = farm.PC.G0[id]
		var nt: bool = G.night
		var o: bool = farm.pc_next(id)
		var r: int = farm.pc_lv(id)
		var l: bool = o and r == 0 and int(G.g.coins) >= int(n.cost)
		var wood := Color("#8d6b45") if nt else Color("#d1a468")
		var wood_d := Color("#6a4d30") if nt else Color("#a97c46")
		var acc := Color("#f0bd3d") if nt else Color("#dba013")
		draw_set_transform(-sg.BOX.position * sg.K, 0.0, Vector2(sg.K, sg.K))
		var b := _rr(-40, -62, 80, 30, 6)
		var bl := b.duplicate()
		bl.append(b[0])
		if glow:   # viền sáng nhấp nháy (độ mờ do ParcelSign đổi mỗi khung)
			if l:
				draw_polyline(bl, acc, 3.2, true)
			return
		# qv(2,1,8): bóng dưới chân cọc
		var sh := PackedVector2Array()
		for k in 24:
			var t := TAU * k / 24.0
			sh.append(Vector2(2.0 + cos(t) * 8.0, 1.0 + sin(t) * 8.0 * 0.42))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.24))
		# Dt(0,0,0,-36,woodD,3): cọc, đầu tròn
		draw_line(Vector2(0, 0), Vector2(0, -36), wood_d, 3.0, true)
		draw_circle(Vector2(0, 0), 1.5, wood_d)
		draw_circle(Vector2(0, -36), 1.5, wood_d)
		draw_colored_polygon(b, wood)
		draw_polyline(bl, acc if l else wood_d, 1.8 if l else 1.4, true)
		_txt(farm.fnt7, "Mở khúc sông" if n.get("riv", false) else "Khai hoang", -49.0, 10.0, Color("#3b2a08") if o else Color("#6b5a45"))
		if o and r > 0:
			# "🔒 Cấp N" 800 11.5px: hình ổ khóa emoji + chữ, cả cụm ở giữa
			var fs := 11.5
			var s := " Cấp " + str(r)
			var f: Font = farm.fnt
			var em := fs * 1.245
			var w := em + f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var x := -w / 2.0
			var tx: Texture2D = Css.emoji(0x1f512)
			if tx != null:
				draw_texture_rect(tx, Rect2(x + (em - fs * 1.17) / 2.0, -36.0 - fs * 0.94, fs * 1.17, fs * 1.17), false)
			draw_string(f, Vector2(x + em, -36.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#6b5a45"))
		elif o:
			_txt(farm.fnt, G.fmt_n(int(n.cost)) + " xu", -36.0, 12.0, Color("#2b1d00") if l else Color("#7a2f22"))
		else:
			var c := Color("#6b5a45")
			draw_rect(Rect2(-4, -43, 8, 6.4), c)
			draw_arc(Vector2(0, -43), 3.0, PI, TAU, 20, c, 1.6, true)

class Bubble extends Node2D:
	var farm
	var kind := ""
	var id := ""
	var k := 1.0
	var zoom := 1.0
	var tex: Texture2D = null
	var text := ""
	var can := true
	var night := false
	var fnt: Font
	var bob := 0.0
	func _draw() -> void:
		if kind == "lock":
			# ổ khóa + giá mở ô (gh bản web)
			if tex != null:
				draw_texture_rect(tex, Rect2(Vector2(-33, -41), Vector2(66, 60)), false)
			var lc: Color
			var tc: Color
			if can:
				lc = Color("#f0bd3d") if night else Color("#dba013")
				tc = Color("#ffe9a8") if night else Color("#4a3006")
			else:
				lc = Color(150 / 255.0, 135 / 255.0, 110 / 255.0, 0.85) if night else Color(70 / 255.0, 55 / 255.0, 40 / 255.0, 0.6)
				tc = Color(225 / 255.0, 210 / 255.0, 185 / 255.0, 0.8) if night else Color(55 / 255.0, 40 / 255.0, 25 / 255.0, 0.75)
			var dy := -6.5
			draw_rect(Rect2(-10.2, dy - 1.6, 6, 4.8), lc)
			draw_arc(Vector2(-7.2, dy - 1.6), 2.0, PI, TAU, 24, lc, 1.3, true)
			var fs := 8.5
			var w := fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var by := dy + 0.6 + (fnt.get_ascent(fs) - fnt.get_descent(fs)) / 2.0
			draw_string(fnt, Vector2(3.0 - w / 2.0, by), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
			return
		# X0: khung ảnh dùng chung (bong.gd), xanh = thường, đỏ = sâu / rầy
		var px := 13.6 * k * zoom
		var hinh: Texture2D = null
		var red := false
		match kind:
			"drop":
				hinh = Bong.anh("nuoc", k * zoom)
			"ray":
				hinh = Bong.anh("gap", k * zoom)
				red = true
			"chat":
				hinh = Bong.anh("chat", k * zoom)
			"sau":
				hinh = farm.ui.icon("sau", px)
				red = true
			_:
				hinh = farm.ui.item_ic(id, px)
		Bong.ve(self, Vector2.ZERO, k, hinh, red)

class FxNode extends Node2D:
	var farm
	func _draw() -> void:
		var G = farm.G
		var f: Font = farm.fnt
		# ô chín: 3 sao lấp lánh bay lên (vòng vàng dưới gốc là RipeRing, nằm dưới cây)
		var tt := Time.get_ticks_msec() / 1000.0
		for i in G.B0:
			var a: Dictionary = G.p(i)
			if G.owned(i) and a.u and G.ripe(a):
				var c: Dictionary = G.cells[i]
				var p := Vector2(farm.en(c.gx + 0.5, c.gy + 0.5), farm.nn(c.gx + 0.5, c.gy + 0.5, G.CO) + 1.0)
				var f0: float = p.y - 1.0
				for x in 3:
					var It := fmod(tt * 0.7 + x / 3.0, 1.0)
					_star4(Vector2(p.x + (x - 1) * 13.0, f0 - 8.0 - It * 28.0), 3.2, Color(1.0, 243.0 / 255.0, 176.0 / 255.0, sin(It * 3.14)))
		# ô đang mở khay giống (module "gieo" bản web): khung vàng nét đứt, nhấp nháy, chạy viền
		var gi: int = farm.ui.gv_i if farm.ui != null else -1
		if gi >= 0:
			var c: Dictionary = G.cells[gi]
			var e := 0.06
			var pts := PackedVector2Array()
			for qd in [[-e, -e], [1.0 + e, -e], [1.0 + e, 1.0 + e], [-e, 1.0 + e]]:
				pts.append(Vector2(farm.en(c.gx + qd[0], c.gy + qd[1]), farm.nn(c.gx + qd[0], c.gy + qd[1], G.CO)))
			var it := 0.55 + 0.25 * sin(tt * 4.0)
			draw_colored_polygon(pts, Color(1.0, 236.0 / 255.0, 150.0 / 255.0, 0.22 * it))
			_dash(pts, 6.0, 5.0, fmod(tt * 16.0, 11.0), Color(1.0, 250.0 / 255.0, 215.0 / 255.0, 0.9 * it), 2.4)
		# chữ bay
		for fl in farm.floats:
			var p := Vector2(farm.en(fl[0], fl[1]), farm.nn(fl[0], fl[1], 18.0 + fl[3] * 14.0))
			var al := clampf(1.6 - fl[3], 0.0, 1.0)
			draw_string_outline(f, p + Vector2(-60, 0), fl[2], HORIZONTAL_ALIGNMENT_CENTER, 120, 8, 3, Color(0.2, 0.14, 0.05, 0.8 * al))
			draw_string(f, p + Vector2(-60, 0), fl[2], HORIZONTAL_ALIGNMENT_CENTER, 120, 8, Color(1, 0.96, 0.82, al))
		# hạt văng (L5)
		for a in farm.parts:
			var e: float = a.age / a.life
			var c: Color = a.col
			c.a = minf(1.0, (1.0 - e) * 1.6)
			if a.get("star", false):
				var r: float = a.r * 1.8 * (1.0 - e * 0.4)
				_star4(Vector2(a.x, a.y), r, c)
			else:
				draw_circle(Vector2(a.x, a.y), a.r * (1.0 - e * 0.3), c, true, -1.0, true)
		# vòng sáng loang (xG / hy)
		for a in farm.rings:
			var e: float = a.age / a.life
			var r: float = a.rx * (0.35 + 0.9 * e)
			var c: Color = a.col
			c.a = (1.0 - e) * 0.9
			_ring(Vector2(a.x, a.y), r, r * 0.5, c, 2.4 * (1.0 - e) + 0.6)
		# tia sét đánh cây (ti.bolt, sQ bản web): từ mép trên màn hình xuống gốc cây
		var bo = G.troi.bao.bolt if G.troi != null else null
		if bo != null:
			var z: float = farm.main.zoom / maxf(1.0, farm.main.dpr)   # px màn hình css -> đơn vị làng
			var top: float = farm.main.cam.y
			var pts := PackedVector2Array()
			pts.append(Vector2(bo.x + randf_range(-30.0, 30.0) / z, top))
			for k in bo.pts:
				pts.append(Vector2(bo.x + k[0] * (1.0 - k[1]) / z, top + (bo.y - top) * k[1]))
			pts.append(Vector2(bo.x, bo.y))
			draw_polyline(pts, Color(1, 1, 240 / 255.0, minf(1.0, bo.t * 2.0)), 3.0 / z, true)
			draw_polyline(pts, Color(180 / 255.0, 200 / 255.0, 1, 0.9), 1.2 / z, true)
			for r in range(12, 0, -1):
				var u := r / 12.0
				draw_circle(Vector2(bo.x, bo.y), (2.0 + 58.0 * u) / z, Color(1, 1, 220 / 255.0, minf(0.8, bo.t) * (1.0 - u) / 6.0), true, -1.0, true)
	func _dash(pts: PackedVector2Array, on: float, off: float, ofs: float, col: Color, w: float) -> void:
		# canvas setLineDash([on, off]) + lineDashOffset = -ofs, quanh đa giác kín
		var per := on + off
		var g := 0.0                         # quãng đường đã đi trên viền
		for k in pts.size():
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[(k + 1) % pts.size()]
			var L := a.distance_to(b)
			var d := (b - a) / maxf(L, 1e-4)
			var ph := fposmod(g - ofs, per)    # vị trí trong mẫu ở đầu cạnh
			var t := -ph                       # đầu nét đứt đầu tiên (có thể trước cạnh)
			while t < L:
				var t0 := maxf(t, 0.0)
				var t1 := minf(t + on, L)
				if t1 > t0:
					draw_line(a + d * t0, a + d * t1, col, w, true)
				t += per
			g += L
	func _star4(c: Vector2, r: float, col: Color) -> void:   # sao 4 cánh (xe 8 điểm, eo .3)
		var q := [0, -1, 0.3, -0.3, 1, 0, 0.3, 0.3, 0, 1, -0.3, 0.3, -1, 0, -0.3, -0.3]
		var pts := PackedVector2Array()
		for j in range(0, 16, 2):
			pts.append(c + Vector2(q[j], q[j + 1]) * r)
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, col, 0.4, true)
	func _ring(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
		var pts := PackedVector2Array()
		for a in 41:
			var t := a / 40.0 * TAU
			pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
		draw_polyline(pts, col, w, true)

class RayNode extends Node2D:   # o_: nền nâu mờ trên ô + 9 con rầy nhảy (ảnh ui/img/bong/raynen, raycon; bản đêm _dem)
	var farm
	var i := 0
	var tt := 0.0
	func _draw() -> void:
		var G = farm.G
		var z: float = farm.main.zoom
		var dem: String = "_dem" if G.night else ""
		var nen: Texture2D = Bong.anh("raynen" + dem, z)
		if nen != null:
			draw_texture_rect(nen, Rect2(-30.0, -15.0, 60.0, 30.0), false)
		var con: Texture2D = Bong.anh("raycon" + dem, z)
		if con == null:
			return
		var still: bool = G.motion_off()
		for s in 9:
			var h: float = G.nv.Me(i * 7 + s, s * 3) * 6.28
			var p: float = 4.0 + G.nv.Me(s, i) * 18.0
			var d := 0.0 if still else maxf(0.0, sin(tt * 6.0 + s * 1.7)) * 5.0
			draw_texture_rect(con, Rect2(cos(h) * p - 2.0, sin(h) * p * 0.5 - d - 3.0 - 1.5, 4.0, 3.0), false)

class RipeRing extends Node2D:   # ô chín: vòng vàng tươi (ảnh ui/img/bong/vong.png, elip 21 x 10,5), vẽ ngay trước cây của ô
	var ppu := 0.0   # px màn mỗi đơn vị lúc vẽ: đổi nấc ảnh thì vẽ lại, còn nhấp nháy chỉ đổi modulate
	func zoom_to(z: float) -> void:
		if absf(z - ppu) > 0.001:
			ppu = z
			queue_redraw()
	func _draw() -> void:
		var t: Texture2D = Bong.anh("vong", ppu)
		if t != null:
			draw_texture_rect(t, Rect2(-24.0, -13.0, 48.0, 26.0), false)

class TagNode extends Node2D:
	var pl
	var top := 0.0
	var _pill := PlayerNode._mk_pill()
	func _draw() -> void:
		# tên · cấp trên đầu (Lh, khi zoom >= 0,8) và chữ LÊN CẤP! bay lên 2,5 giây (aa.lvT)
		var le: float = pl.farm.sign_le()
		var zz: float = pl.farm.main.zoom / maxf(1.0, pl.farm.main.dpr)
		if zz >= 0.8:
			var nm: String = String(pl.farm.G.g.pc.get("name", ""))
			var j := (nm if nm != "" else "Bạn") + " · cấp " + str(pl.farm.G.lv())
			draw_set_transform(Vector2(0, top - 3.0 * le), 0.0, Vector2(le, le))
			var fw: Font = pl.farm.fnt7
			var w := fw.get_string_size(j, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 10.0
			draw_style_box(_pill, Rect2(-w / 2.0, -7, w, 14))
			draw_string(fw, Vector2(-w / 2.0, 0.5 + (fw.get_ascent(9) - fw.get_descent(9)) / 2.0), j, HORIZONTAL_ALIGNMENT_CENTER, w, 9, Color("#4a3420"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var lt: float = pl.farm.ui.lvp.lvT if pl.farm.ui != null and pl.farm.ui.lvp != null else 0.0
		if lt > 0.0:
			var a := minf(1.0, lt)
			var fs := 13.0 * le
			var f: Font = pl.farm.fnt
			var y := top - 16.0 * le - (2.5 - lt) * 10.0
			var tw := f.get_string_size("LÊN CẤP!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
			draw_string_outline(f, Vector2(-tw / 2.0, y), "LÊN CẤP!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), 3, Color(0x5a / 255.0, 0x3a / 255.0, 0x08 / 255.0, a))
			draw_string(f, Vector2(-tw / 2.0, y), "LÊN CẤP!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), Color(1, 0xd2 / 255.0, 0x3a / 255.0, a))


class PlayerNode extends Node2D:
	var tag: Node2D = null
	# nhân vật nga: walk khi đi, idle khi đứng/làm; khung theo 8 hướng (bản web IB/UV/BT)
	var farm
	var x := 6.3
	var y := 4.6
	var target := Vector2.INF
	var dir := 0
	var ph := 0.0
	var mv := 0.0
	var work := false
	var it0 := 0.0
	var _arr := false
	var _last := []
	func base_y() -> float:
		return farm.nn(x, y) + 6.0
	func arrived() -> bool:
		return _arr
	func step(dt: float) -> void:
		var G = farm.G
		_arr = false
		var moving := false
		if target != Vector2.INF:
			var d := Vector2(target.x - x, target.y - y)
			var l := d.length()
			if l < 0.05:
				x = target.x
				y = target.y
				_arr = true
			else:
				var s: float = minf(l, G.speed(l) * dt)
				x += d.x / l * s
				y += d.y / l * s
				moving = true
				# hướng theo màn hình
				var sx := (d.x - d.y) * 32.0
				var sy := (d.x + d.y) * 16.0
				var r := atan2(sy, sx)
				var best := 0
				var bd := 9.0
				for c in 8:
					var q: float = absf(fposmod(r - farm.DIRS[c] + PI, TAU) - PI)
					if q < bd:
						bd = q
						best = c
				dir = best
				var m: Dictionary = farm.P.meta("nv_walk")
				if not m.is_empty():
					var cyc: float = float(m["strides"][dir]) * farm.H / 45.25
					# NB() bản web (có bộ chạy): tối đa (2,3 + 0,3·clamp(ba.z − 1,4, 0, 1)) bước mỗi giây
					var bz: float = farm.main.zoom / maxf(1.0, farm.main.dpr)
					ph += minf(s / cyc, (2.3 + 0.3 * clampf(bz - 1.4, 0.0, 1.0)) * dt)
		if moving:
			mv = 0.18
			it0 = 0.0
		else:
			mv = maxf(0.0, mv - dt)
		position = Vector2(farm.en(x, y), farm.nn(x, y))
		queue_redraw()
	func _draw() -> void:
		var P = farm.P
		var an := "nv_walk" if mv > 0.0 else "nv_idle"
		var m: Dictionary = P.meta(an)
		if m.is_empty():
			m = P.meta("nv_walk")
			an = "nv_walk"
			if m.is_empty():
				return
		var n := int(m["n"])
		var fr := 0
		if an == "nv_walk":
			if mv > 0.0:
				fr = mini(n - 1, int(floor(fposmod(ph, 1.0) * n)))
			else:
				fr = int(m["stand"][dir])
		else:
			if it0 == 0.0:
				it0 = Time.get_ticks_msec() / 1000.0
			fr = int(floor((Time.get_ticks_msec() / 1000.0 - it0) / float(m["fd"]))) % n
		# ảnh gốc của web (cả tấm, không cắt, không nén lại); khung j = hướng·n + i, xếp theo hàng như web
		var tx: Texture2D = P.tex(an, "sheet")
		if tx == null and an == "nv_idle":
			an = "nv_walk"
			m = P.meta(an)
			if m.is_empty():
				return
			n = int(m["n"])
			fr = int(m["stand"][dir])
			tx = P.tex(an, "sheet")
		var src := Rect2()
		if tx != null:
			var fw0 := float(m["fw"])
			var fh0 := float(m["fh"])
			var per := maxi(1, int(tx.get_width() / fw0))
			var j := dir * n + fr
			src = Rect2((j % per) * fw0, (j / per) * fh0, fw0, fh0)
			_last = [tx, src, m, an]
		elif not _last.is_empty():
			tx = _last[0]   # chưa giải xong: giữ khung trước, không nháy
			src = _last[1]
			m = _last[2]
			an = _last[3]
		# bóng dưới chân + vòng vàng đánh dấu nhân vật
		var kk := 1.2 * 1.52 / 2.52
		_ell(Vector2.ZERO, 8.5 * kk, 3.6 * kk, Color(0.16, 0.12, 0.04, 0.16))
		_ell(Vector2.ZERO, 5.0 * kk, 2.2 * kk, Color(0.16, 0.12, 0.04, 0.5))
		var pts := PackedVector2Array()
		for a in 33:
			var t := a / 32.0 * TAU
			pts.append(Vector2(cos(t) * 7.5 * 1.2 * 1.52 / 2.0, sin(t) * 2.9 * 1.2 * 1.52 / 2.0))
		draw_polyline(pts, Color(1, 0.84, 0.35, 0.85), 1.6, true)
		if tx == null:
			return
		var c: float = farm.H * float(m.get("fhs", 1.0))
		var kv := 1.0
		if an == "nv_idle" and m.has("kv"):
			kv = float(m["kv"][dir])
		var s: float = c * float(m["fw"]) / float(m["fh"]) * kv
		var h := c * kv
		var bob := 0.0 if mv > 0.0 or work else 0.0
		draw_texture_rect_region(tx, Rect2(-s * float(m["cx"][dir]), -h * float(m["feet"][dir]) + bob, s, h), src)
		# tên · cấp + LÊN CẤP! vẽ ở lớp riêng (không qua lớp đêm, nằm trên biển/khóa ô): TagNode
		if tag == null:
			tag = TagNode.new()
			tag.pl = self
			tag.z_as_relative = false
			tag.z_index = 40
			add_child(tag)
		tag.top = -h * float(m["feet"][dir])
		tag.queue_redraw()
	var _pill := _mk_pill()
	static func _mk_pill() -> StyleBoxFlat:
		var b := StyleBoxFlat.new()
		b.bg_color = Color(1, 1, 1, 0.88)
		b.set_corner_radius_all(7)
		b.anti_aliasing = true
		return b
	func _ppu(m: Dictionary) -> float:
		# hình nhân vật: px gốc mỗi đơn vị làng (cao khung fh vẽ thành farm.H * fhs)
		return float(m["fh"]) / (farm.H * float(m.get("fhs", 1.0)))
	func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for a in 16:
			var t := a / 16.0 * TAU
			pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
		draw_colored_polygon(pts, col)
