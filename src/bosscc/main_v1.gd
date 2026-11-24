# Map đấu boss Chúa Cào Cào (thành Tây): ruộng lúa chín quanh 1 sân đất, đường đất dg2 vô sân, chòi canh, rơm, tre dừa.
# Nền = shader nền làng (arena.gdshader, cùng ảnh n2_co/n2_codai/n2_dat/dg2_dat + số màu của ground.gdshader).
# Cây/đồ = ảnh 9px xuất sẵn trong godot/<nhóm>/<tên>/ (Sprite2D offset=(ox,oy)*9, scale 1/9, neo = tâm ô).
# Boss = cảnh 3D godot/boss/caocao/3d (boss.gd) trong SubViewport trong suốt, camera trực giao nghiêng 30° như góc làng.
extends Node2D

const T0 := Vector2i(-12, -12)
const TN := Vector2i(64, 64)
const PAD0 := 9            # ruộng: ô 9..27
const PAD1 := 33
const Y0 := 15             # sân: ô 15..20
const Y1 := 21
var ZOOM := 3.0
const U := 44.0            # 1 đơn vị 3D = 48 đơn vị game
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

func tile_pos(s: float, h: float) -> Vector2:   # tâm ô (s, h)
	return Vector2((s - h) * 32.0, (s + h + 1.0) * 16.0)

func _ready() -> void:
	rng.seed = 7
	ZOOM = get_viewport().get_visible_rect().size.y / 1040.0
	_layout()
	_ground()
	ysort = Node2D.new(); ysort.y_sort_enabled = true; add_child(ysort)
	_scenery()
	_boss()
	cam = Camera2D.new(); cam.zoom = Vector2(ZOOM, ZOOM); add_child(cam)
	var cp := OS.get_environment("CAMXY")
	cam.position = Vector2(0, 680) if cp == "" else Vector2(float(cp.split(",")[0]), float(cp.split(",")[1]))
	if OS.get_environment("SHOT") != "":
		_shot(OS.get_environment("SHOT"))

func _shot(path: String) -> void:
	for i in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

# ---------------- bố cục ô
func _layout() -> void:
	for s in range(T0.x, T0.x + TN.x):
		for h in range(T0.y, T0.y + TN.y):
			var k := 3
			if s >= PAD0 - 1 and s <= PAD1 + 1 and h >= PAD0 - 1 and h <= PAD1 + 1: k = 0    # bờ cỏ quanh ruộng
			if s >= PAD0 and s <= PAD1 and h >= PAD0 and h <= PAD1: k = 1
			if s >= Y0 and s <= Y1 and h >= Y0 and h <= Y1: k = 2
			elif s >= Y0 - 1 and s <= Y1 + 1 and h >= Y0 - 1 and h <= Y1 + 1: k = 0   # bờ cỏ quanh sân
			kind[Vector2i(s, h)] = k
	# đường đất dg2 từ góc trái-dưới vô giữa cạnh sân (theo trục h, cột s = 17)
	for i in range(Y1 + 1, T0.y + TN.y):
		road[Vector2i(18, i)] = 4 | 8
		road[Vector2i(i, 18)] = 1 | 2
		for j in [17, 18, 19]:   # bờ cỏ 2 bên đường xuyên ruộng
			for t in [Vector2i(j, i), Vector2i(i, j)]:
				if kind[t] == 1: kind[t] = 0

func _ground() -> void:
	var ik := Image.create(TN.x, TN.y, false, Image.FORMAT_RGBA8)
	var ir := Image.create(TN.x, TN.y, false, Image.FORMAT_RGBA8)
	var pal := [Color8(144, 188, 64), Color8(155, 195, 66), Color8(160, 196, 69), Color8(159, 198, 67), Color8(156, 196, 66), Color8(142, 187, 64), Color8(161, 199, 67), Color8(162, 200, 67)]
	for t in kind:
		var q: Vector2i = t - T0
		var c: Color = pal[rng.randi() % pal.size()]
		c.a = float(kind[t] * 16) / 255.0
		ik.set_pixelv(q, c)
		if road.has(t):
			ir.set_pixelv(q, Color(4.0 / 255.0, float(road[t]) / 255.0, 0.0, 1.0))
	var mat := ShaderMaterial.new(); mat.shader = load("res://arena.gdshader")
	mat.set_shader_parameter("uK", ImageTexture.create_from_image(ik))
	mat.set_shader_parameter("uRD", ImageTexture.create_from_image(ir))
	mat.set_shader_parameter("uT0", Vector2(T0)); mat.set_shader_parameter("uTN", Vector2(TN))
	var arr := []
	for f in ["n/dg2_dat.webp", "n/n2_codai.webp", "n/n2_co.webp", "n/n2_dat.webp"]:
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
	var sp := Sprite2D.new(); sp.texture = _tex("res://img/" + p + "/" + e["file"]); sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.offset = Vector2(e["ox"], e["oy"]) * 9.0; sp.scale = Vector2(-1.0 if flip else 1.0, 1.0) / 9.0
	if flip: sp.offset.x = -e["w"] - e["ox"] * 9.0
	sp.position = pos
	(parent if parent else ysort).add_child(sp)
	return sp

func _scenery() -> void:
	var cy := Vector2((Y0 + Y1) * 0.5, (Y0 + Y1) * 0.5)
	# lúa chín: 1 bụi mỗi ô; quanh sân bị bầy cào cào ăn trụi (ô trống, rải lúa non sót lại)
	for t in kind:
		if kind[t] != 1: continue
		var d: float = max(max(Y0 - t.x, t.x - Y1), max(Y0 - t.y, t.y - Y1))
		var eaten := 0.0
		if d <= 2: eaten = 0.9
		elif d <= 3: eaten = 0.55
		elif d <= 4: eaten = 0.2
		else: eaten = 0.05
		var blk := Vector2i(int(floor((t.x) / 3.0)), int(floor((t.y - 1) / 3.0)))
		var green := posmod(blk.x * 7 + blk.y * 13 + (blk.x * blk.y) % 5, 9) == 0
		var jit := Vector2(rng.randf_range(-3, 3), rng.randf_range(-1.5, 1.5))
		if rng.randf() < eaten:
			if rng.randf() < 0.35: put("caytrong/lua", "dlua1", tile_pos(t.x, t.y) + jit, rng.randf() < 0.5)
			continue
		put("caytrong/lua", "dlua2" if green else "dlua3", tile_pos(t.x, t.y) + jit, rng.randf() < 0.5)
	# chòi canh ruộng trên bờ cỏ góc trái trên
	put("congtrinh/choi", "d0", tile_pos(PAD0 - 1, 14))
	# rơm 2 góc sân sau
	put("caylang/rom", "d0", tile_pos(Y0, Y1 - 0.2))
	put("caylang/rom", "d2", tile_pos(Y0 + 0.6, Y1 + 0.1), true)
	put("caylang/rom", "d1", tile_pos(Y1 - 0.1, Y0 + 0.2), true)
	put("trangtri/da_nho", "d1", tile_pos(Y1 - 0.2, Y0 + 2.4))
	put("trangtri/da_nho_reu", "d0", tile_pos(Y0 + 0.4, Y0 + 0.3))
	# lũy tre + dừa phía sau (trên màn), bụi thấp phía trước (không che ruộng)
	var taken := []
	var tries := 0
	while tries < 4000:
		tries += 1
		var s := rng.randf_range(T0.x, T0.x + TN.x); var h := rng.randf_range(T0.y, T0.y + TN.y)
		var t := Vector2i(int(floor(s)), int(floor(h)))
		if kind.get(t, 3) != 3: continue
		var p := tile_pos(s - 0.5, h - 0.5)
		if abs(p.x) > 330 or p.y < -20 or p.y > 1250: continue
		var back := s + h < PAD0 * 2 + 2
		var gap := 70.0 if back else 46.0
		var ok := true
		for q in taken:
			if q.distance_to(p) < gap: ok = false; break
		if not ok: continue
		taken.append(p)
		var fl := rng.randf() < 0.5
		if back:
			var r := rng.randf()
			if r < 0.45: put("caylang/tre", "d%d" % rng.randi_range(0, 3), p, fl)
			elif r < 0.75: put("caytrai/dua", ["d00", "d01", "d10", "d11"][rng.randi() % 4], p, fl)
			elif r < 0.9: put("caylang/duanuoc", "d%d" % rng.randi_range(0, 3), p, fl)
			else: put("caydai/bui_co", "d%d" % rng.randi_range(0, 3), p, fl)
		else:
			var r := rng.randf()
			if r < 0.35: put("caydai/bui_co", "d%d" % rng.randi_range(0, 3), p, fl)
			elif r < 0.55: put("hoaco/c_lau", "dc_lau%d" % rng.randi_range(0, 3), p, fl)
			elif r < 0.75: put("hoaco/bui_la", "dbui_la%d" % rng.randi_range(0, 3), p, fl)
			elif r < 0.9: put("hoaco/c_xanh", "dc_xanh%d" % rng.randi_range(0, 3), p, fl)
			else: put("trangtri/da_nho", "d%d" % rng.randi_range(0, 2), p, fl)

# ---------------- boss 3D
func _boss() -> void:
	var px := int(400 * ZOOM)
	boss_vp = SubViewport.new(); boss_vp.size = Vector2i(px, px); boss_vp.transparent_bg = true; boss_vp.own_world_3d = true
	boss_vp.msaa_3d = Viewport.MSAA_4X
	add_child(boss_vp)
	boss = Node3D.new(); boss.set_script(load("res://boss.gd"))
	boss.ortho_size = float(px) / (U * ZOOM)
	boss_vp.add_child(boss)
	var feet := tile_pos((Y0 + Y1) * 0.5, (Y0 + Y1) * 0.5)
	# bóng mềm dưới bụng (như bóng tròn của ảnh cây trong làng)
	var g := Gradient.new(); g.set_color(0, Color(0, 0, 0, 0.42)); g.set_color(1, Color(0, 0, 0, 0))
	g.add_point(0.55, Color(0, 0, 0, 0.30))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5); gt.width = 256; gt.height = 256
	boss_sh = Sprite2D.new(); boss_sh.texture = gt; boss_sh.scale = Vector2(175.0, 58.0) / 256.0
	boss_sh.position = feet + Vector2(-4, 0); boss_sh.z_index = -5; add_child(boss_sh)
	boss_spr = Sprite2D.new(); boss_spr.texture = boss_vp.get_texture(); boss_spr.centered = false
	boss_spr.scale = Vector2.ONE / ZOOM; boss_spr.position = feet
	ysort.add_child(boss_spr)
	await get_tree().process_frame
	var o: Vector2 = boss.cam.unproject_position(Vector3.ZERO)
	boss_spr.offset = -o
