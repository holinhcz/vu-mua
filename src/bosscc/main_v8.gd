# Map đấu boss Chúa Cào Cào (thành Tây): ruộng lúa chín quanh 1 sân đất, đường đất dg2 vô sân, chòi canh, rơm, tre dừa.
# Nền = shader nền làng (arena.gdshader, cùng ảnh n2_co/n2_codai/n2_dat/dg2_dat + số màu của ground.gdshader).
# Cây/đồ = ảnh 9px xuất sẵn trong godot/<nhóm>/<tên>/ (Sprite2D offset=(ox,oy)*9, scale 1/9, neo = tâm ô).
# Boss = cảnh 3D godot/boss/caocao/3d (boss.gd) trong SubViewport trong suốt, camera trực giao nghiêng 30° như góc làng.
extends Node2D

const T0 := Vector2i(-12, -12)
const TN := Vector2i(64, 64)
var ZOOM := 3.0
const U := 56.0            # 1 đơn vị 3D = 48 đơn vị game
var kind := {}             # Vector2i -> 0 cỏ sân, 1 ruộng, 2 sân, 3 cỏ dại
var road := {}             # Vector2i -> mask
var ysort: Node2D
var rng := RandomNumberGenerator.new()
var atl := {}
var texc := {}
var boss: Node3D
var boss_vp: SubViewport
var boss_spr: Sprite2D
var boss_sh: Sprite2D
var cam: Camera2D
var shots := []
var board: CanvasLayer
var fight: CanvasLayer
var btn: Button

func tile_pos(s: float, h: float) -> Vector2:   # tâm ô (s, h)
	return Vector2((s - h) * 32.0, (s + h + 1.0) * 16.0)

func _ready() -> void:
	rng.seed = 7
	ZOOM = get_viewport().get_visible_rect().size.y / 1040.0
	_layout()
	_pre_gnaw()
	_ground()
	ysort = Node2D.new(); ysort.y_sort_enabled = true; add_child(ysort)
	_scenery()
	_boss()
	cam = Camera2D.new(); cam.zoom = Vector2(ZOOM, ZOOM); add_child(cam)
	var cp := OS.get_environment("CAMXY")
	cam.position = Vector2(0, 720) if cp == "" else Vector2(float(cp.split(",")[0]), float(cp.split(",")[1]))
	_hud()
	fight.visible = OS.get_environment("BOARD") != ""
	_toggle()
	if OS.get_environment("SHOT") != "":
		_shot(OS.get_environment("SHOT"))

func _shot(path: String) -> void:
	for i in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

# ---------------- bố cục ô (v2: boss ở nửa trên, ruộng chữ V sau lưng boss, nửa dưới toàn sân đất cho người đứng)
# v6 (Link 11-24 "xấu", ok hướng mới): khúc ruộng mới gặt. Nửa trên = ruộng (khối ô s,h <= RA, đỉnh nhọn chĩa xuống giữa màn),
# boss đứng trên ruộng gặt còn gốc rạ, lúa chín chưa gặt bao quanh; nửa dưới = sân phơi lúa đất nện cho người chơi.
const BOSS_Y := 562.0     # chân boss (thế giới); màn: trên 200, giữa 720, dưới 1240
const RA := 23            # ruộng: ô s,h trong [RA-18, RA]; bờ cỏ ở RA+1
var harvested := {}
var gnaw := {}       # ô ruộng đã gặt (màu rạ)
func at(x: float, y: float) -> Vector2:   # toạ độ thế giới -> (s, h) để đặt đồ
	return Vector2((y / 16.0 - 1.0 + x / 32.0) * 0.5, (y / 16.0 - 1.0 - x / 32.0) * 0.5)
func _layout() -> void:
	for s in range(T0.x, T0.x + TN.x):
		for h in range(T0.y, T0.y + TN.y):
			var t := Vector2i(s, h)
			var w0 := tile_pos(s, h)
			var ey := pow(w0.x / 185.0, 2) + pow((w0.y - 1000.0) / 190.0, 2)
			var k := 2 if ey <= 1.0 else 3  # sân phơi giữa, cỏ quanh, cỏ dại xa
			if s <= RA and h <= RA and s >= RA - 18 and h >= RA - 18: k = 1
			elif s <= RA + 2 and h <= RA + 2 and s >= RA - 20 and h >= RA - 20: k = 3   # bờ cỏ quanh ruộng (2 ô, cỏ dại như bờ làng)
			elif s + h < 2 * RA - 30: k = 3
			kind[t] = k
			if k == 1:
				var w := tile_pos(s, h)
				var e := pow(w.x / 200.0, 2) + pow((w.y - BOSS_Y) / 125.0, 2)
				# gặt: quanh boss + dải sát bờ dưới (chừa lối từ sân phơi lên)
				if e <= 0.92 + (fposmod(sin(s * 12.9898 + h * 78.233) * 43758.5453, 1.0) - 0.5) * 0.4 or (s >= RA - 1 or h >= RA - 1) and w.y > 560.0: harvested[t] = true

func _ground() -> void:
	var ik := Image.create(TN.x, TN.y, false, Image.FORMAT_RGBA8)
	var ir := Image.create(TN.x, TN.y, false, Image.FORMAT_RGBA8)
	var pal := [Color8(144, 188, 64), Color8(155, 195, 66), Color8(160, 196, 69), Color8(159, 198, 67), Color8(156, 196, 66), Color8(142, 187, 64), Color8(161, 199, 67), Color8(162, 200, 67)]
	for t in kind:
		var q: Vector2i = t - T0
		var c: Color = pal[rng.randi() % pal.size()]
		var hv: bool = harvested.has(t) or gnaw.has(t)
		if kind[t] == 1 and not hv:     # ô lúa sát chỗ gặt: nền rạ dưới bụi lúa, không lộ bậc thang xanh theo ô
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				if harvested.has(t + d) or gnaw.has(t + d): hv = true; break
		if hv: c = Color8(194, 170, 98)
		c.a = float((4 if hv else kind[t]) * 16) / 255.0
		ik.set_pixelv(q, c)
		if road.has(t):
			ir.set_pixelv(q, Color(4.0 / 255.0, float(road[t]) / 255.0, 4.0 / 255.0, 1.0))
	var mat := ShaderMaterial.new(); mat.shader = load("res://arena.gdshader")
	mat.set_shader_parameter("uK", ImageTexture.create_from_image(ik))
	mat.set_shader_parameter("uRD", ImageTexture.create_from_image(ir))
	mat.set_shader_parameter("uYE", Vector4(0, 1000, 185, 190))
	mat.set_shader_parameter("uLP0", Vector4(26.6, 31.2, 29.0, 33.6))
	mat.set_shader_parameter("uLP1", Vector4(31.2, 26.6, 33.6, 29.0))
	mat.set_shader_parameter("uT0", Vector2(T0)); mat.set_shader_parameter("uTN", Vector2(TN))
	var arr := []
	for f in ["n/dg2_dat.webp", "n/n2_codai.webp", "n/n2_co.webp", "n/n2_dat.webp", "n/dg2_gach.webp"]:
		var im := Image.load_from_file("res://" + f); im.convert(Image.FORMAT_RGB8); im.generate_mipmaps(); arr.append(im)
	var ta := Texture2DArray.new(); ta.create_from_images(arr)
	mat.set_shader_parameter("uRA", ta)
	var poly := Polygon2D.new()
	var a := tile_pos(T0.x, T0.y) + Vector2(0, -16); var n := float(TN.x)
	poly.polygon = PackedVector2Array([a, a + Vector2(32, 16) * n, a + Vector2(0, 32) * n, a + Vector2(-32, 16) * n])
	poly.material = mat; poly.z_index = -10; add_child(poly)

# ---------------- ảnh 9px
func _atlas(p: String) -> Dictionary:
	if not atl.has(p): atl[p] = JSON.parse_string(FileAccess.get_file_as_string("res://img/" + p + "/atlas.json"))
	return atl[p]

func _tex(f: String) -> Texture2D:
	if not texc.has(f):
		var im := Image.load_from_file(f); im.generate_mipmaps(); texc[f] = ImageTexture.create_from_image(im)
	return texc[f]

func put(p: String, fr: String, pos: Vector2, flip := false, parent: Node = null) -> Sprite2D:
	var e: Dictionary = _atlas(p)["frames"][fr]
	var sp := Sprite2D.new(); sp.texture = _tex("res://img/" + p + "/" + String(e["file"]).replace(".png", ".webp")); sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.offset = Vector2(e["ox"], e["oy"]) * 9.0; sp.scale = Vector2(-1.0 if flip else 1.0, 1.0) / 9.0
	if flip: sp.offset.x = -e["w"] - e["ox"] * 9.0
	sp.position = pos
	(parent if parent else ysort).add_child(sp)
	return sp

func _pre_gnaw() -> void:     # ô lúa mép chỗ gặt bị gặm: quyết trước để nền tô màu rạ
	var r3 := RandomNumberGenerator.new(); r3.seed = 11
	for t in kind.keys():
		if kind[t] != 1 or harvested.has(t): continue
		var n := 0
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if kind.get(t + d, 0) == 1 and not harvested.has(t + d): n += 1
		if n <= 1: harvested[t] = true
	for t in kind:
		if kind[t] != 1 or harvested.has(t): continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if harvested.has(t + d):
				if r3.randf() < 0.55: gnaw[t] = true
				break
	var g1 := gnaw.duplicate()
	for t in kind:     # vòng thứ 2: gặm lấn sâu chỗ có chỗ không, mép không còn thẳng theo ô
		if kind[t] != 1 or harvested.has(t) or gnaw.has(t): continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if g1.has(t + d):
				if r3.randf() < 0.35: gnaw[t] = true
				break
func _scenery() -> void:
	# lúa chín chưa gặt trên ô ruộng chưa gặt; mép giáp chỗ gặt bị bầy cào cào gặm (ô trống / còn gốc)
	for t in kind:
		if kind[t] != 1 or harvested.has(t): continue
		var w := tile_pos(t.x, t.y)
		if w.y < 150 or w.y > 800 or abs(w.x) > 300: continue
		var jit := Vector2(rng.randf_range(-3, 3), rng.randf_range(-1.5, 1.5))
		if gnaw.has(t):
			if rng.randf() < 0.5: put("caytrong/lua", "dlua1", w + jit, rng.randf() < 0.5)
			continue
		var sp3 := put("caytrong/lua", "dlua3", w + jit + Vector2(0, rng.randf_range(-2, 2)), rng.randf() < 0.5)
		sp3.scale *= rng.randf_range(0.82, 1.12)
	# mép chỗ gặt lởm chởm: bụi lúa chín lấn ra ô gặt, cao thấp lệch nhau
	for t in harvested:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n2: Vector2i = t + d
			if kind.get(n2, 0) == 1 and not harvested.has(n2) and not gnaw.has(n2) and rng.randf() < 0.55:
				var w2 := tile_pos(t.x + d.x * 0.32 + rng.randf_range(-0.3, 0.3), t.y + d.y * 0.32 + rng.randf_range(-0.3, 0.3))
				if abs(w2.x) < 140 and abs(w2.y - BOSS_Y) < 70: continue
				var s4 := put("caytrong/lua", "dlua3" if rng.randf() < 0.7 else "dlua2", w2, rng.randf() < 0.5)
				s4.scale *= rng.randf_range(0.7, 0.95)
	# vài bụi lúa sót lẻ loi trên ruộng gặt (không đứng sát chân boss)
	for t in harvested:
		var w := tile_pos(t.x, t.y)
		if abs(w.x) < 150 and abs(w.y - BOSS_Y) < 75: continue
		if rng.randf() < 0.10: put("caytrong/lua", "dlua1", w + Vector2(rng.randf_range(-8, 8), rng.randf_range(-4, 4)), rng.randf() < 0.5)
	# bờ cỏ 2 ô: lau, bụi cỏ, bụi lá mọc thưa lệch nhau 2 hàng; hoa từng cặp khóm cách đều (không lẻ loi)
	var HOA := ["h_cuc_vang", "h_mong_ga", "h_da_yen", "h_mai_dia", "h_van_tho", "h_cuc_trang"]
	var hi := 0
	for sd in [0, 1]:
		for i in 26:
			var f := (i + rng.randf_range(0.1, 0.9)) / 26.0 * 21.0
			var row := RA + 1.15 + (0.9 if i % 2 == 1 else 0.0) + rng.randf_range(-0.2, 0.2)
			var tp := tile_pos(row, RA - 20 + f) if sd == 0 else tile_pos(RA - 20 + f, row)
			if abs(tp.x) > 255 or tp.y < 540: continue
			if abs(tp.x) < 36: continue
			var r := rng.randf()
			if r < 0.3: put("hoaco/c_lau", "dc_lau%d" % rng.randi_range(0, 3), tp, rng.randf() < 0.5)
			elif r < 0.6: put("caydai/bui_co", "d%d" % rng.randi_range(0, 3), tp, rng.randf() < 0.5)
			elif r < 0.8: put("hoaco/c_xanh", "dc_xanh%d" % rng.randi_range(0, 3), tp, rng.randf() < 0.5)
			else: put("hoaco/bui_la", "dbui_la%d" % rng.randi_range(0, 3), tp, rng.randf() < 0.5)
		for j in 3:
			var f2 := 21.0 - (j * 3.2 + 3.0)
			var tp2 := tile_pos(RA + 1.9, RA - 20 + f2) if sd == 0 else tile_pos(RA - 20 + f2, RA + 1.9)
			if abs(tp2.x) > 240: continue
			var nm: String = HOA[hi % HOA.size()]; hi += 1
			for k2 in 3: put("hoaco/" + nm, "d%s%d" % [nm, rng.randi_range(0, 3)], tp2 + Vector2(rng.randf_range(-12, 12), rng.randf_range(-5, 5)), rng.randf() < 0.5)
	# sân phơi: đụn rơm + chòi canh dạt 2 bên, đá nhỏ, bụi lau ở mép màn; giữa sân chừa trống cho người chơi
	put("caylang/rom", "d0", Vector2(-205, 875))
	put("caylang/rom", "d2", Vector2(-176, 900), true)
	put("caylang/rom", "d3", Vector2(208, 880), true)
	put("congtrinh/choi", "d1", Vector2(192, 660), true)      # chòi canh đứng trên bờ ruộng
	put("trangtri/da_nho_reu", "d1", Vector2(182, 912), true)
	for p2 in [Vector2(-232, 1060), Vector2(-226, 1190), Vector2(236, 1130), Vector2(230, 1225), Vector2(-150, 1225), Vector2(120, 1236), Vector2(-240, 800), Vector2(242, 780)]:
		var r := rng.randf()
		if r < 0.5: put("hoaco/c_lau", "dc_lau%d" % rng.randi_range(0, 3), p2, rng.randf() < 0.5)
		else: put("caydai/bui_co", "d%d" % rng.randi_range(0, 3), p2, rng.randf() < 0.5)

# ---------------- màn đánh (bố cục theo ảnh Link gửi 11-24): thanh lượt trên cùng, sân đánh (người chơi trái, boss phải),
# nửa trên chỉ có boss (Link 11-24), hàng ô kỹ năng giữa màn, bảng ghép hình 7 cột dưới. Kỹ năng / bảng = chỗ giữ.
var font: FontFile
var K := 1.0            # 1 px css
func _lb(t: String, sz: int, col := Color("#fff6e2")) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", int(sz * K))
	l.add_theme_color_override("font_color", col); l.add_theme_color_override("font_outline_color", Color("#3a2412"))
	l.add_theme_constant_override("outline_size", int(4 * K)); return l
func _box(p: Vector2, sz: Vector2, bg: Color, r: float, bd := Color(0, 0, 0, 0), bw := 0.0) -> Panel:
	var pn := Panel.new(); var sb := StyleBoxFlat.new(); sb.bg_color = bg; sb.set_corner_radius_all(int(r * K))
	sb.border_color = bd; sb.set_border_width_all(int(bw * K)); pn.add_theme_stylebox_override("panel", sb)
	pn.position = p * K; pn.size = sz * K; return pn
func _bar(p: Vector2, w: float, f: float, col: Color) -> Control:     # thanh máu (css px)
	var c := Control.new()
	c.add_child(_box(p, Vector2(w, 8), Color(0.15, 0.08, 0.04, 0.85), 4))
	c.add_child(_box(p + Vector2(1.5, 1.5), Vector2((w - 3) * f, 5), col, 3))
	return c
func _toggle() -> void:        # nút bật/tắt màn đánh (tắt = thấy sân người chơi ở nửa dưới)
	var W := get_viewport().get_visible_rect().size.x / K
	var b := Button.new()
	b.add_theme_font_override("font", font); b.add_theme_font_size_override("font_size", int(14 * K))
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new(); sb.bg_color = Color("#6a9a3a"); sb.set_corner_radius_all(int(12 * K))
		sb.border_color = Color("#fff6e2"); sb.set_border_width_all(int(2 * K)); b.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(c, Color("#fff6e2"))
	b.size = Vector2(86, 30) * K; b.position = Vector2(W - 98, 62) * K
	b.text = "Thoát" if fight.visible else "Vô đánh"
	b.pressed.connect(func():
		fight.visible = not fight.visible
		b.text = "Thoát" if fight.visible else "Vô đánh")
	board.add_child(b)

func _hud() -> void:
	var vs := get_viewport().get_visible_rect().size
	K = vs.y / 735.0
	var W := vs.x / K; var H := 735.0
	font = FontFile.new(); font.data = FileAccess.get_file_as_bytes("res://font/nunito_800.ttf")
	var cl := CanvasLayer.new(); cl.layer = 5; add_child(cl); board = cl
	# thanh trên: nút về, lượt còn lại, nút tuỳ chọn
	cl.add_child(_box(Vector2(12, 14), Vector2(40, 40), Color(0.32, 0.22, 0.12, 0.85), 20, Color("#e2c08a"), 2))
	var bk := _lb("‹", 20); bk.position = Vector2(26, 20) * K; cl.add_child(bk)
	cl.add_child(_box(Vector2(W * 0.5 - 26, 12), Vector2(52, 52), Color("#6a9a3a"), 26, Color("#fff6e2"), 3))
	var tn := _lb("4", 20); tn.position = Vector2(W * 0.5 - 7, 24) * K; cl.add_child(tn)
	var tl := _lb("lượt", 14); tl.position = Vector2(W * 0.5 - 14, 64) * K; cl.add_child(tl)
	cl.add_child(_box(Vector2(W - 52, 14), Vector2(40, 40), Color(0.32, 0.22, 0.12, 0.85), 20, Color("#e2c08a"), 2))
	var mo := _lb("…", 20); mo.position = Vector2(W - 42, 18) * K; cl.add_child(mo)
	# máu boss trên đầu boss
	var bx := W * 0.5
	cl.add_child(_bar(Vector2(bx - 60, 112), 120, 0.72, Color("#a066c9")))
	var bn := _lb("Chúa Cào Cào", 14); bn.position = Vector2(bx - 46, 90) * K; cl.add_child(bn)
	var fl3 := CanvasLayer.new(); fl3.layer = 6; add_child(fl3); fight = fl3; cl = fl3
	# hàng ô kỹ năng
	var cy := H * 0.505
	for i in 4:
		var x := W * 0.5 - 2 * 62 + 4 + i * 62
		cl.add_child(_box(Vector2(x, cy), Vector2(56, 56), Color(0.32, 0.22, 0.12, 0.88), 12, Color("#e2c08a") if i != 3 else Color("#9ad13a"), 3))
		var c := _lb(["0/12", "12/12", "2/12", "12/12"][i], 14); c.position = Vector2(x + 10, cy - 20) * K; cl.add_child(c)
	# bảng ghép hình 7 cột
	var top := H * 0.60; var mg := 14.0
	var cs := (W - 2 * mg - 16) / 7.0; var rows := int(floor((H - top - 22) / cs))
	cl.add_child(_box(Vector2(mg, top), Vector2(W - 2 * mg, rows * cs + 16), Color(0.32, 0.22, 0.12, 0.94), 16, Color("#e2c08a"), 3))
	var fr := []
	for i in 6:
		var im := Image.load_from_file("res://xt/f%d.webp" % i); im.generate_mipmaps(); fr.append(ImageTexture.create_from_image(im))
	var r2 := RandomNumberGenerator.new(); r2.seed = 3
	for y in rows:
		for x in 7:
			var q := Vector2(mg + 8 + x * cs, top + 8 + y * cs)
			cl.add_child(_box(q + Vector2(1, 1), Vector2(cs - 2, cs - 2), Color(1, 0.95, 0.85, 0.10 if (x + y) % 2 == 0 else 0.05), 6))
			var tr := TextureRect.new(); tr.texture = fr[r2.randi() % 6]; tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			tr.position = (q - Vector2(cs, cs) * 0.12) * K; tr.size = Vector2(cs, cs) * 1.24 * K; cl.add_child(tr)

# ---------------- boss 3D
func _boss() -> void:
	var px := int(600 * ZOOM)
	boss_vp = SubViewport.new(); boss_vp.size = Vector2i(px, px); boss_vp.transparent_bg = true; boss_vp.own_world_3d = true
	boss_vp.msaa_3d = Viewport.MSAA_4X
	add_child(boss_vp)
	boss = Node3D.new(); boss.set_script(load("res://boss.gd"))
	boss.ortho_size = float(px) / (U * ZOOM)
	boss.face_base = float(OS.get_environment("FACEB")) if OS.get_environment("FACEB") != "" else 0.0
	boss.auto_play = OS.get_environment("SHOT") == ""
	boss_vp.add_child(boss)
	var fp := at(0, BOSS_Y); var feet := tile_pos(fp.x, fp.y)
	# bóng mềm dưới bụng (như bóng tròn của ảnh cây trong làng)
	var g := Gradient.new(); g.set_color(0, Color(0.12, 0.08, 0.02, 0.62)); g.set_color(1, Color(0, 0, 0, 0))
	g.add_point(0.5, Color(0.12, 0.08, 0.02, 0.42))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5); gt.width = 256; gt.height = 256
	boss_sh = Sprite2D.new(); boss_sh.texture = gt; boss_sh.scale = Vector2(225.0, 74.0) / 256.0
	boss_sh.position = feet + Vector2(-4, 0); boss_sh.z_index = -5; add_child(boss_sh)
	boss_spr = Sprite2D.new(); boss_spr.texture = boss_vp.get_texture(); boss_spr.centered = false
	boss_spr.scale = Vector2.ONE / ZOOM; boss_spr.position = feet
	ysort.add_child(boss_spr)
	await get_tree().process_frame
	var o: Vector2 = boss.cam.unproject_position(Vector3.ZERO)
	boss_spr.offset = -o
