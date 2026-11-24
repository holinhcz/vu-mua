# Map đấu boss Chúa Cào Cào (thành Tây): ruộng lúa chín quanh 1 sân đất, đường đất dg2 vô sân, chòi canh, rơm, tre dừa.
# Nền = shader nền làng (arena.gdshader, cùng ảnh n2_co/n2_codai/n2_dat/dg2_dat + số màu của ground.gdshader).
# Cây/đồ = ảnh 9px xuất sẵn trong godot/<nhóm>/<tên>/ (Sprite2D offset=(ox,oy)*9, scale 1/9, neo = tâm ô).
# Boss = cảnh 3D godot/boss/caocao/3d (boss.gd) trong SubViewport trong suốt, camera trực giao nghiêng 30° như góc làng.
extends Node2D

const T0 := Vector2i(-12, -12)
const TN := Vector2i(64, 64)
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
var board: CanvasLayer
var btn: Button

func _button() -> void:          # bật/tắt bảng ghép hình (giả) để coi boss còn lộ ở nửa trên không
	var vs := get_viewport().get_visible_rect().size
	var k := vs.y / 735.0                      # 1 px css (S26 Ultra = 735 css cao)
	var ui := CanvasLayer.new(); ui.layer = 5; add_child(ui)
	btn = Button.new(); btn.text = "Vô đánh"
	var f := FontFile.new(); f.data = FileAccess.get_file_as_bytes("res://font/nunito_800.ttf")
	btn.add_theme_font_override("font", f); btn.add_theme_font_size_override("font_size", int(20 * k))
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new(); sb.bg_color = Color("#6a9a3a") if st != "pressed" else Color("#557d2e")
		sb.set_corner_radius_all(int(14 * k)); sb.border_color = Color("#fff6e2"); sb.set_border_width_all(int(2 * k))
		sb.shadow_color = Color(0, 0, 0, 0.25); sb.shadow_size = int(4 * k); sb.shadow_offset = Vector2(0, 2 * k)
		btn.add_theme_stylebox_override(st, sb)
	btn.add_theme_color_override("font_color", Color("#fff6e2")); btn.add_theme_color_override("font_pressed_color", Color("#fff6e2"))
	btn.add_theme_color_override("font_hover_color", Color("#fff6e2")); btn.add_theme_color_override("font_focus_color", Color("#fff6e2"))
	btn.size = Vector2(130 * k, 44 * k); btn.position = Vector2(vs.x - btn.size.x - 12 * k, 12 * k)
	btn.pressed.connect(func():
		board.visible = not board.visible
		btn.text = "Thoát bảng" if board.visible else "Vô đánh")
	ui.add_child(btn)
	if board.visible: btn.text = "Thoát bảng"


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
	cam.position = Vector2(0, 720) if cp == "" else Vector2(float(cp.split(",")[0]), float(cp.split(",")[1]))
	_board()
	board.visible = OS.get_environment("BOARD") != ""
	_button()
	if OS.get_environment("SHOT") != "":
		_shot(OS.get_environment("SHOT"))

func _shot(path: String) -> void:
	for i in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

# ---------------- bố cục ô (v2: boss ở nửa trên, ruộng chữ V sau lưng boss, nửa dưới toàn sân đất cho người đứng)
const F0 := 18             # đỉnh chữ V ruộng ~ ô 15, sân từ ô 17
func _layout() -> void:
	for s in range(T0.x, T0.x + TN.x):
		for h in range(T0.y, T0.y + TN.y):
			var k := 3
			var m: int = min(s, h)
			if m >= F0 - 1: k = 2                        # sân
			elif m == F0 - 2: k = 0                      # bờ cỏ giữa ruộng và sân
			elif m >= F0 - 11 and max(s, h) <= 46: k = 1 # ruộng
			elif m == F0 - 12: k = 0
			kind[Vector2i(s, h)] = k

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
	var sp := Sprite2D.new(); sp.texture = _tex("res://img/" + p + "/" + String(e["file"]).replace(".png", ".webp")); sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.offset = Vector2(e["ox"], e["oy"]) * 9.0; sp.scale = Vector2(-1.0 if flip else 1.0, 1.0) / 9.0
	if flip: sp.offset.x = -e["w"] - e["ox"] * 9.0
	sp.position = pos
	(parent if parent else ysort).add_child(sp)
	return sp

func _scenery() -> void:
	for t in kind:
		if kind[t] != 1: continue
		var m: int = min(t.x, t.y)
		var front: bool = m >= F0 - 4 and abs(t.x - t.y) <= 8       # mép ruộng sát boss: bị bầy cào cào ăn
		var jit := Vector2(rng.randf_range(-3, 3), rng.randf_range(-1.5, 1.5))
		if front and rng.randf() < (0.75 if m >= F0 - 3 else 0.4):
			if rng.randf() < 0.4: put("caytrong/lua", "dlua1", tile_pos(t.x, t.y) + jit, rng.randf() < 0.5)
			continue
		var blk := Vector2i(int(floor(t.x / 3.0)), int(floor((t.y - 1) / 3.0)))
		var green := posmod(blk.x * 7 + blk.y * 13 + (blk.x * blk.y) % 5, 9) == 0
		put("caytrong/lua", "dlua2" if green else "dlua3", tile_pos(t.x, t.y) + jit, rng.randf() < 0.5)
	# 2 bên sân, sát mép màn (không chiếm chỗ đứng giữa): chòi canh trái, rơm phải, đá
	put("congtrinh/choi", "d0", tile_pos(F0 - 1.6, F0 + 5.2))
	put("caylang/rom", "d0", tile_pos(F0 + 4.6, F0 - 1.6), true)
	put("caylang/rom", "d2", tile_pos(F0 + 5.6, F0 - 1.3))
	put("trangtri/da_nho_reu", "d0", tile_pos(F0 + 6.2, F0 - 0.4))
	put("trangtri/da_nho", "d1", tile_pos(F0 - 0.3, F0 + 6.4), true)
	# lũy tre, dừa, dừa nước sau ruộng (trên màn)
	var taken := []
	var tries := 0
	while tries < 5000:
		tries += 1
		var s := rng.randf_range(T0.x, T0.x + TN.x); var h := rng.randf_range(T0.y, T0.y + TN.y)
		var t := Vector2i(int(floor(s)), int(floor(h)))
		if kind.get(t, 0) != 3: continue
		var p := tile_pos(s - 0.5, h - 0.5)
		if abs(p.x) > 340 or p.y < -60 or p.y > 700: continue
		var ok := true
		for q in taken:
			if q.distance_to(p) < 62.0: ok = false; break
		if not ok: continue
		taken.append(p)
		var fl := rng.randf() < 0.5
		var r := rng.randf()
		if r < 0.45: put("caylang/tre", "d%d" % rng.randi_range(0, 3), p, fl)
		elif r < 0.72: put("caytrai/dua", ["d00", "d01", "d10", "d11"][rng.randi() % 4], p, fl)
		elif r < 0.88: put("caylang/duanuoc", "d%d" % rng.randi_range(0, 3), p, fl)
		else: put("caydai/bui_co", "d%d" % rng.randi_range(0, 3), p, fl)

# ---------------- bảng ghép hình (giả, chỉ để xem chỗ): phủ nửa dưới màn hình
func _board() -> void:
	var vs := get_viewport().get_visible_rect().size
	var cl := CanvasLayer.new(); add_child(cl); board = cl
	var pn := Panel.new(); var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.32, 0.22, 0.12, 0.92); sb.set_corner_radius_all(int(vs.x * 0.04)); sb.border_color = Color(0.85, 0.68, 0.40)
	sb.set_border_width_all(int(vs.x * 0.008)); pn.add_theme_stylebox_override("panel", sb)
	var mg := vs.x * 0.03
	pn.position = Vector2(mg, vs.y * 0.5); pn.size = Vector2(vs.x - 2 * mg, vs.y * 0.5 - mg); cl.add_child(pn)
	var n := 8; var cs := (pn.size.x - 2 * mg) / n
	var oy := (pn.size.y - cs * n) * 0.5
	var fr := []
	for i in 6:
		var im := Image.load_from_file("res://xt/f%d.webp" % i); im.generate_mipmaps(); fr.append(ImageTexture.create_from_image(im))
	var r2 := RandomNumberGenerator.new(); r2.seed = 3
	for y in n:
		for x in n:
			var cell := ColorRect.new(); cell.color = Color(1, 0.95, 0.85, 0.10 if (x + y) % 2 == 0 else 0.05)
			cell.position = pn.position + Vector2(mg + x * cs, oy + y * cs); cell.size = Vector2(cs, cs); cl.add_child(cell)
			var tr := TextureRect.new(); tr.texture = fr[r2.randi() % 6]; tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			tr.position = cell.position + Vector2(cs, cs) * 0.06; tr.size = Vector2(cs, cs) * 0.88; cl.add_child(tr)

# ---------------- boss 3D
func _boss() -> void:
	var px := int(400 * ZOOM)
	boss_vp = SubViewport.new(); boss_vp.size = Vector2i(px, px); boss_vp.transparent_bg = true; boss_vp.own_world_3d = true
	boss_vp.msaa_3d = Viewport.MSAA_4X
	add_child(boss_vp)
	boss = Node3D.new(); boss.set_script(load("res://boss.gd"))
	boss.ortho_size = float(px) / (U * ZOOM)
	boss.auto_play = OS.get_environment("SHOT") == ""
	boss_vp.add_child(boss)
	var feet := tile_pos(F0 + 1.0, F0 + 1.0)
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
