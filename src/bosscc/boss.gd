# Boss Chúa Cào Cào 3D: ONE continuous skinned body on a Skeleton3D (skin stretches at every joint, no seams),
# leathery forewings on their own bones + see-through hindwing fans that fold/unfold on 6 fan bones.
# Everything moves in Godot: tripod walk, head/mandibles/antennae, drumstick hind-leg jump, flight.
# Skills: Đá Hậu (jump + hind kick: one board row shaken), Gọi Bầy (swarm eats 6 cells), Bay Lượn (flies a loop and lands).
extends Node3D
const BossLook = preload("res://boss_look.gd")      # shared boss lighting + matte skin (godot/boss/chung)

var ortho_size := 7.6
var look_at_pt := Vector3(0, 1.2, 0)
var auto_play := false
var face_base := 0.0
var J := {}
var root: Node3D
var cam: Camera3D
var t := 0.0
var rig: Dictionary
var mat_body: StandardMaterial3D
var ui: CanvasLayer
var board_cells: Array = []
var dot_tex: Texture2D
var leaf_tex: Texture2D
var shake := 0.0
var glow := 0.0
var walk := 0.0
var walk_ph := 0.0
var walk_speed := 1.0
var head_pitch := 0.0
var pinch := 0.0
var face := 0.0
var crouch := 0.0         # 0 stand, 1 crouched on folded hind legs
var hlp := 0.0            # hind legs: 0 rest (folded), 1 push (straight back-down), 2 trailing (flight)
var tuck := 0.0           # front/mid legs folded under (flight)
var fw_open := 0.0
var hw_open := 0.0
var flap := 0.0
var flap_ph := 0.0
var hover := 0.0
var pitch := 0.0          # body pitch (deg, + nose up)
var skel: Skeleton3D
var BI := {}
var piv := {}
var hw_mi: Array = []
const FACE0 := -PI / 2 + 0.60
const GROUND := 1.10

func _ready() -> void:
	rig = JSON.parse_string(FileAccess.get_file_as_string("res://cc3.json"))
	var sun: DirectionalLight3D = BossLook.setup_scene(self, Color(0.80, 0.87, 0.86))          # shared boss lighting (godot/boss/chung)
	for ch in get_children():
		if ch is WorldEnvironment: ch.environment.background_mode = Environment.BG_CLEAR_COLOR
	cam = Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = ortho_size
	cam.position = Vector3(0, 0, 1) * cos(deg_to_rad(30.0)) * 30.0 + Vector3(0, sin(deg_to_rad(30.0)) * 30.0, 0) + look_at_pt
	add_child(cam); cam.look_at(look_at_pt); cam.current = true; cam.far = 100.0
	_build_boss()
	_build_ui()
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5); gt.width = 32; gt.height = 32; dot_tex = gt
	leaf_tex = _make_bitten_tile()
	var pose := OS.get_environment("POSE")
	if pose != "":                                             # still test: POSE=k:v,k:v  (+ CAM=x,y,z  FACE=deg)
		for kv in pose.split(","):
			var p := kv.split(":"); set(p[0], float(p[1]))
		var cp := OS.get_environment("CAM")
		if cp != "":
			var c := cp.split(","); cam.position = Vector3(float(c[0]), float(c[1]), float(c[2])); cam.look_at(Vector3(0, 1.0 + hover, -0.6))
		ui.visible = false
		return
	ui.visible = false
	if auto_play: _timeline()

func _make_bitten_tile() -> Texture2D:        # a rice leaf with bite marks, drawn once
	var w := 92; var h := 68; var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u: float = (x - w * 0.5) / (w * 0.46); var v: float = (y - h * 0.5) / (h * 0.30)
			var leaf: float = 1.0 - (u * u + v * v * (1.0 + 0.8 * u * u))
			var c := Color(0, 0, 0, 0)
			if leaf > 0.0:
				c = Color(0.42, 0.66, 0.20).lerp(Color(0.68, 0.82, 0.30), clamp(0.5 - v * 0.6, 0.0, 1.0))
				if abs(v) < 0.06: c = c.darkened(0.25)
				for b in [Vector2(0.55, -0.55), Vector2(0.10, -0.75), Vector2(-0.45, 0.60), Vector2(0.75, 0.40)]:
					var d: Vector2 = Vector2(u, v) - b
					if d.length() < 0.30: c = Color(0, 0, 0, 0)
					elif d.length() < 0.36: c = c.lerp(Color(0.55, 0.42, 0.18), 0.8)
			im.set_pixel(x, y, c)
	return ImageTexture.create_from_image(im)

func _build_ground() -> void:
	var gm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60, 60); gm.mesh = pm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.62, 0.60, 0.50)
	var nt := NoiseTexture2D.new(); var n := FastNoiseLite.new(); n.frequency = 0.05; nt.noise = n; nt.seamless = true; nt.width = 256; nt.height = 256
	var cr := Gradient.new(); cr.set_color(0, Color(0.60, 0.58, 0.48)); cr.set_color(1, Color(0.86, 0.84, 0.74)); nt.color_ramp = cr
	m.albedo_texture = nt; m.uv1_scale = Vector3(12, 12, 1); m.roughness = 1.0
	gm.material_override = m; add_child(gm)

func _arr(buf: PackedByteArray, L: Array, is_int: bool):
	var sub := buf.slice(int(L[0]), int(L[0]) + int(L[1]) * 4)
	return sub.to_int32_array() if is_int else sub.to_float32_array()

func _mesh(buf: PackedByteArray, sec: Dictionary) -> ArrayMesh:
	var P: PackedFloat32Array = _arr(buf, sec.pos, false); var N: PackedFloat32Array = _arr(buf, sec.nor, false); var U: PackedFloat32Array = _arr(buf, sec.uv, false)
	var nv := P.size() / 3
	var pv := PackedVector3Array(); pv.resize(nv); var nn := PackedVector3Array(); nn.resize(nv); var uv := PackedVector2Array(); uv.resize(nv)
	for i in nv:
		pv[i] = Vector3(P[i * 3], P[i * 3 + 1], P[i * 3 + 2]); nn[i] = Vector3(N[i * 3], N[i * 3 + 1], N[i * 3 + 2]); uv[i] = Vector2(U[i * 2], 1.0 - U[i * 2 + 1])
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pv; arrays[Mesh.ARRAY_NORMAL] = nn; arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = _arr(buf, sec.ind, true); arrays[Mesh.ARRAY_BONES] = _arr(buf, sec.bi, true); arrays[Mesh.ARRAY_WEIGHTS] = _arr(buf, sec.bw, false)
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays); return mesh

func _tex(p: String) -> Texture2D:
	return ImageTexture.create_from_image(Image.load_from_file(p))

func _build_boss() -> void:
	var buf := FileAccess.get_file_as_bytes("res://cc3.bin")
	mat_body = BossLook.skin("res://cc_albedo.webp", "res://cc_emission.webp", true)          # shared matte skin
	var mat_fw := StandardMaterial3D.new(); mat_fw.albedo_texture = _tex("res://cc_fw.webp"); mat_fw.albedo_color = Color(0.92, 0.92, 0.86); mat_fw.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_fw.roughness = 0.6; mat_fw.metallic_specular = 0.35
	var mat_hw := StandardMaterial3D.new(); mat_hw.albedo_texture = _tex("res://cc_hw.webp"); mat_hw.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_hw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat_hw.roughness = 0.4; mat_hw.metallic_specular = 0.6
	root = Node3D.new(); root.position = Vector3(0, GROUND, 0); add_child(root)
	var center := Node3D.new(); root.add_child(center); J["center"] = center
	skel = Skeleton3D.new(); center.add_child(skel)
	var skin := Skin.new()
	for bd in rig.bones:
		var i := skel.get_bone_count(); skel.add_bone(bd.name); BI[bd.name] = i
		piv[bd.name] = Vector3(bd.pivot[0], bd.pivot[1], bd.pivot[2])
	for bd in rig.bones:
		var i: int = BI[bd.name]; var pp := Vector3.ZERO
		if bd.parent != null: skel.set_bone_parent(i, BI[bd.parent]); pp = piv[bd.parent]
		skel.set_bone_rest(i, Transform3D(Basis(), piv[bd.name] - pp))
		skin.add_bind(i, Transform3D(Basis(), -piv[bd.name]))
		J[bd.name] = Quaternion()
	skel.reset_bone_poses()
	for sec in rig.sections:
		var mi := MeshInstance3D.new(); mi.mesh = _mesh(buf, sec); skel.add_child(mi); mi.skin = skin; mi.skeleton = NodePath("..")
		if sec.name == "body": mi.material_override = mat_body; mini_meshes.append([mi.mesh, mat_body])
		elif sec.name.begins_with("fw"): mi.material_override = mat_fw; mini_meshes.append([mi.mesh, mat_fw])
		else:
			mi.material_override = mat_hw; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; hw_mi.append(mi)

var mini_meshes: Array = []
func _mini() -> Node3D:
	var n := Node3D.new()
	for mm in mini_meshes:
		var mi := MeshInstance3D.new(); mi.mesh = mm[0]; mi.material_override = mm[1]; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; n.add_child(mi)
	return n

func _build_ui() -> void:
	ui = CanvasLayer.new(); add_child(ui)
	var cols := [Color("#e8584a"), Color("#f2c037"), Color("#5cb85c"), Color("#4a90d9"), Color("#a066c9")]
	var bg := ColorRect.new(); bg.size = Vector2(460, 135); bg.position = Vector2(255, 400); bg.color = Color(0.30, 0.22, 0.14, 0.85); ui.add_child(bg)
	for r in 3:
		for c in 9:
			var cell := ColorRect.new(); cell.size = Vector2(46, 34); cell.position = Vector2(262 + c * 50, 410 + r * 40)
			cell.pivot_offset = cell.size * 0.5
			cell.color = cols[(c * 2 + r * 3 + (c * r) % 2) % 5]; ui.add_child(cell); board_cells.append(cell)

func q(x: float, y: float, z: float) -> Quaternion:            # degrees, applied Z then Y then X in the parent frame
	return Quaternion(Vector3.RIGHT, deg_to_rad(x)) * Quaternion(Vector3.UP, deg_to_rad(y)) * Quaternion(Vector3.BACK, deg_to_rad(z))

func _lerp3(a: float, b: float, c: float, k: float) -> float:
	return lerp(a, b, clamp(k, 0.0, 1.0)) if k < 1.0 else lerp(b, c, clamp(k - 1.0, 0.0, 1.0))

func _process(dt: float) -> void:
	t += dt
	walk_ph += dt * TAU * walk_speed * walk
	flap_ph += dt * TAU * 7.0 * flap
	# front + mid legs: tripod gait (A = front R, mid L ; hind legs step with their own rhythm)
	for k in 2:
		for sd in ["R", "L"]:
			var grpA: bool = (k == 0) == (sd == "R")
			var ph := walk_ph + (0.0 if grpA else PI)
			var sw := sin(ph) * 14.0 * walk
			var lift: float = max(0.0, cos(ph)) * 18.0 * walk
			var sgn := -1.0 if sd == "R" else 1.0
			J["leg%d%s_fem" % [k, sd]] = q(-sgn * (lift - crouch * 10.0 + tuck * 35.0), sgn * (sw - tuck * (25.0 if k == 0 else -10.0)), 0)
			J["leg%d%s_tib" % [k, sd]] = q(sgn * (lift * 0.8 + tuck * 40.0 + crouch * 12.0), 0, 0)
			J["leg%d%s_tar" % [k, sd]] = q(sgn * tuck * 20.0, 0, 0)
	# hind legs: femur swings in the side plane (rest folded -> push -> trail), tibia folds/extends at the knee
	for sd in ["R", "L"]:
		var ph := walk_ph + (PI if sd == "R" else 0.0)
		var fa: float = _lerp3(0.0, 27.4, 16.7, hlp) - crouch * 6.0 + sin(ph) * 6.0 * walk
		var ta: float = _lerp3(0.0, -97.4, -116.0, hlp) + crouch * 8.0 - max(0.0, cos(ph)) * 8.0 * walk
		J["leg2%s_fem" % sd] = q(0, 0, fa); J["leg2%s_tib" % sd] = q(0, 0, ta)
		J["leg2%s_tar" % sd] = q(0, 0, _lerp3(0.0, -10.0, -25.0, hlp))
	J["head"] = q(0, 3.0 * sin(t * 0.9), 10.0 + head_pitch + 2.0 * sin(t * 1.7))
	var po: float = 3.0 + 20.0 * pinch + 4.0 * max(0.0, sin(t * 4.2))
	J["mandR"] = q(0, po, 0); J["mandL"] = q(0, -po, 0)
	for sd in ["R", "L"]:
		var s := 1.0 if sd == "R" else -1.0
		var sw := 4.0 * sin(t * 2.1 + s) + 10.0 * fw_open
		J["ant%s0" % sd] = q(s * 2.0 * sin(t * 1.3), s * sw * 0.4, -fw_open * 18.0)
		J["ant%s1" % sd] = q(0, s * 5.0 * sin(t * 2.6 + 0.7 * s), -6.0 * sin(t * 1.9) - fw_open * 12.0)
		J["ant%s2" % sd] = q(0, s * 7.0 * sin(t * 3.1 + 1.3 * s), -8.0 * sin(t * 2.3 + 0.5) - fw_open * 10.0)
	J["abd0"] = q(0, 2.0 * sin(t * 1.1), 3.0 * sin(t * 1.6) * 0.5 - 8.0 * fw_open)
	J["abd1"] = q(0, 2.5 * sin(t * 1.1 - 0.6), 2.0 * sin(t * 1.6 - 0.5) - 6.0 * fw_open)
	# forewings: lift out of the roof, swing out-back, small beat ; hindwings: fan unfolds under them and beats
	var fs := fw_open * (8.0 + 16.0 * sin(flap_ph + 0.5) * flap)
	for sd in ["R", "L"]:
		var s := 1.0 if sd == "R" else -1.0
		J["fw" + sd] = Quaternion(Vector3.RIGHT, deg_to_rad(s * fs)) * Quaternion(Vector3.UP, deg_to_rad(-s * 68.0 * fw_open)) * Quaternion(Vector3.RIGHT, deg_to_rad(s * 30.0 * fw_open))
		var beta: float = (-4.0 + 26.0 * sin(flap_ph) * flap) * hw_open + (fs - 12.0) * (1.0 - hw_open)
		beta = min(beta, fs - 6.0) if fw_open > 0.05 else beta
		J["hw" + sd] = q(s * beta, 0, 0)
		var phi: Array = rig.hw_phi[sd]; var fold: float = rig.hw_fold[sd]
		for i in 6:
			J["hw%s_f%d" % [sd, i]] = q(0, s * rad_to_deg(fold - float(phi[i])) * (1.0 - hw_open), 0)
	for mi in hw_mi: mi.visible = hw_open > 0.10
	J["center"].position.y = (0.03 * abs(sin(walk_ph))) * walk - 0.22 * crouch
	J["center"].rotation.z = deg_to_rad(pitch + 1.2 * sin(walk_ph * 2.0) * walk)
	J["center"].rotation.x = deg_to_rad(2.0 * sin(walk_ph) * walk)
	root.position.y = GROUND + hover + 0.06 * sin(t * 6.0) * flap
	root.rotation.y = FACE0 + face + face_base
	mat_body.emission_energy_multiplier = BossLook.EMISSION + 2.5 * glow
	for nm in BI:
		if nm == "body": continue
		skel.set_bone_pose_rotation(BI[nm], J[nm])
	if shake > 0:
		shake = max(0.0, shake - dt * 2.5)
		cam.h_offset = randf_range(-1, 1) * 0.15 * shake; cam.v_offset = randf_range(-1, 1) * 0.15 * shake

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func tw(obj: Object, prop: String, val, dur: float, tr := Tween.TRANS_SINE) -> Tween:
	var tw_ := create_tween(); tw_.tween_property(obj, prop, val, dur).set_trans(tr); return tw_

func fwd_dir() -> Vector3:
	return root.global_transform.basis.x.normalized()

func _timeline() -> void:
	await wait(1.0)
	var only := OS.get_environment("SKILL")
	if only != "":
		while true:
			await call(only); await wait(0.5)
	while true:
		await _stroll()
		await _skill_da_hau()
		await wait(1.0)
		await _skill_goi_bay()
		await wait(1.0)
		await _skill_bay_luon()
		await wait(1.2)

func _stroll() -> void:
	for d in [1.0, -1.0]:
		var yaw: float = -FACE0 + (0.0 if d > 0 else PI)
		walk_speed = 1.5; tw(self, "walk", 1.0, 0.3)
		await tw(self, "face", yaw, 0.6).finished
		await tw(root, "position:x", root.position.x + 0.5 * d, 1.2, Tween.TRANS_LINEAR).finished
	await tw(self, "face", 0.0, 0.6).finished
	await tw(self, "walk", 0.0, 0.3).finished
	walk_speed = 1.0

func _label(txt: String, col: Color) -> void:
	var lb := Label.new(); lb.text = txt; lb.add_theme_font_size_override("font_size", 34)
	lb.add_theme_color_override("font_color", col); lb.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0))
	lb.add_theme_constant_override("outline_size", 8); lb.position = Vector2(390, 30); ui.add_child(lb)
	lb.pivot_offset = Vector2(90, 20); lb.scale = Vector2(0.3, 0.3)
	var t_ := create_tween(); t_.tween_property(lb, "scale", Vector2(1, 1), 0.25).set_trans(Tween.TRANS_BACK)
	t_.tween_interval(1.0); t_.tween_property(lb, "modulate:a", 0.0, 0.4); t_.tween_callback(lb.queue_free)

func _burst3(p: Vector3, a: Color, b: Color, n: int, spd: float, life := 0.6, size := 0.14, up := Vector3(0, 1, 0), spread := 180.0, grav := -2.5) -> void:
	var ps := CPUParticles3D.new(); ps.position = p; ps.one_shot = true; ps.explosiveness = 0.95; ps.amount = n; ps.lifetime = life
	ps.direction = up; ps.spread = spread; ps.initial_velocity_min = spd * 0.4; ps.initial_velocity_max = spd; ps.gravity = Vector3(0, grav, 0)
	ps.damping_min = 1; ps.damping_max = 3; ps.scale_amount_min = 0.6; ps.scale_amount_max = 1.6
	var qm := QuadMesh.new(); qm.size = Vector2(size, size); var m := StandardMaterial3D.new(); m.albedo_texture = dot_tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true; qm.material = m; ps.mesh = qm
	var g := Gradient.new(); g.set_color(0, a); g.set_color(1, Color(b, 0)); ps.color_ramp = g
	add_child(ps); ps.emitting = true; get_tree().create_timer(life + 0.4).timeout.connect(ps.queue_free)

func _dust(p: Vector3, n := 30, spd := 2.0) -> void:
	_burst3(p, Color(0.88, 0.80, 0.62, 0.85), Color(0.78, 0.70, 0.52), n, spd, 0.9, 0.45, Vector3(0, 1, 0), 70.0, -0.6)

func _feet() -> Vector3:
	return Vector3(root.position.x, 0.05, root.position.z)

# ---------------- skill 1: Đá Hậu (crouch on the drumstick legs, leaps, lands hard: one board row jolts and reshuffles) ----------------
func _skill_da_hau() -> void:
	_label("Đá Hậu!", Color("#ff7a2a"))
	tw(self, "glow", 1.0, 0.4)
	var t1 := create_tween(); t1.tween_property(self, "crouch", 1.0, 0.55); t1.parallel().tween_property(self, "head_pitch", -6.0, 0.55)
	t1.parallel().tween_property(self, "pinch", 1.0, 0.55)
	await t1.finished
	await wait(0.25)
	var home := root.position
	var t2 := create_tween()                                   # kick: hind legs snap straight, body launches
	t2.tween_property(self, "hlp", 1.0, 0.10).set_trans(Tween.TRANS_EXPO); t2.parallel().tween_property(self, "crouch", -0.3, 0.10)
	t2.parallel().tween_property(self, "pitch", 14.0, 0.12)
	await t2.finished
	_dust(_feet() - fwd_dir() * 1.4, 30, 2.4); shake = 0.4
	tw(self, "fw_open", 0.7, 0.2); tw(self, "hw_open", 1.0, 0.25); tw(self, "flap", 1.0, 0.2)
	var t3 := create_tween()                                   # hop arc toward the player
	t3.tween_property(self, "hover", 1.7, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t3.parallel().tween_property(root, "position:z", home.z + 1.0, 0.84)
	t3.parallel().tween_property(self, "hlp", 2.0, 0.4)
	t3.parallel().tween_property(self, "tuck", 0.6, 0.3)
	t3.tween_property(self, "hover", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t3.parallel().tween_property(self, "pitch", -8.0, 0.42)
	t3.parallel().tween_property(self, "tuck", 0.0, 0.3)
	t3.parallel().tween_property(self, "hlp", 0.0, 0.42)
	t3.parallel().tween_property(self, "fw_open", 0.0, 0.42); t3.parallel().tween_property(self, "flap", 0.0, 0.3)
	t3.parallel().tween_property(self, "hw_open", 0.0, 0.30)
	await t3.finished
	shake = 1.0; _dust(_feet(), 50, 3.0)
	var t4 := create_tween(); t4.tween_property(self, "crouch", 0.7, 0.10); t4.tween_property(self, "crouch", 0.0, 0.35)
	t4.parallel().tween_property(self, "pitch", 0.0, 0.35); t4.parallel().tween_property(self, "pinch", 0.0, 0.35)
	var row := randi() % 3
	var cols := [Color("#e8584a"), Color("#f2c037"), Color("#5cb85c"), Color("#4a90d9"), Color("#a066c9")]
	for c in 9:
		var cell: ColorRect = board_cells[row * 9 + c]; var y0 := cell.position.y
		var tt := create_tween(); tt.tween_interval(0.025 * c)
		tt.tween_property(cell, "position:y", y0 - 26, 0.10).set_trans(Tween.TRANS_QUAD)
		tt.parallel().tween_property(cell, "rotation", randf_range(-0.5, 0.5), 0.10)
		tt.tween_callback(func(): cell.color = cols[randi() % 5])
		tt.tween_property(cell, "position:y", y0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tt.parallel().tween_property(cell, "rotation", 0.0, 0.25)
	await t4.finished
	await wait(0.4)
	tw(self, "glow", 0.0, 0.4)
	walk_speed = 1.3; walk = 0.7
	await tw(root, "position:z", home.z, 1.4).finished
	walk = 0.0; walk_speed = 1.0

# ---------------- skill 2: Gọi Bầy (rears up, rattles its wings, a swarm of small cào cào flies onto the board and eats 6 cells) ----------------
func _skill_goi_bay() -> void:
	_label("Gọi Bầy!", Color("#9ad13a"))
	tw(self, "glow", 0.8, 0.4)
	var t1 := create_tween(); t1.tween_property(self, "pitch", 10.0, 0.5); t1.parallel().tween_property(self, "head_pitch", 12.0, 0.5)
	t1.parallel().tween_property(self, "fw_open", 0.35, 0.4); t1.parallel().tween_property(self, "pinch", 1.0, 0.4)
	await t1.finished
	tw(self, "flap", 0.6, 0.2)                                 # wing rattle (stridulation)
	var hp: Vector3 = skel.to_global(skel.get_bone_global_pose(BI["head"]).origin)
	for i in 4:
		_burst3(hp + Vector3(0, 0.6, 0), Color(0.55, 0.80, 0.25), Color(0.35, 0.55, 0.15), 14, 3.0, 0.9, 0.16, Vector3(0, 1, 0.4), 60.0, -0.5)
		await wait(0.22)
	var picks: Array = []
	while picks.size() < 6:
		var k := randi() % 27
		if not picks.has(k): picks.append(k)
	var bugs: Array = []
	var minis: Array = []
	for k in picks:                                            # little cào cào soldiers (same model, tiny) hop out of the boss onto the cells
		var cell: ColorRect = board_cells[k]
		var mini := _mini(); add_child(mini); minis.append(mini)
		var p1 := cam.project_position(cell.position + cell.size * 0.5, 6.0)
		var p0 := hp + Vector3(randf_range(-0.6, 0.6), 0.8, randf_range(-0.3, 0.3))
		mini.position = p0; mini.scale = Vector3.ONE * 0.02
		var dl := randf_range(0.0, 0.35)
		var tt := create_tween(); tt.tween_interval(dl); tt.tween_property(mini, "scale", Vector3.ONE * 0.16, 0.2).set_trans(Tween.TRANS_BACK)
		var arc := func(k_: float): mini.position = p0.lerp(p1, k_) + Vector3(0, sin(k_ * PI) * 1.6, 0); mini.rotation = Vector3(0.3 * sin(k_ * 20.0), atan2(p0.z - p1.z, p1.x - p0.x), 0.4 * sin(k_ * PI))
		tt.tween_method(arc, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	await wait(1.5)
	for m in minis: m.queue_free()
	for i in picks.size():
		var cell: ColorRect = board_cells[picks[i]]; cell.set_meta("old", cell.color)
		tw(cell, "color", Color("#7a6a3a"), 0.2)
		var tile := Sprite2D.new(); tile.texture = leaf_tex; tile.position = cell.position + cell.size * 0.5
		var full := cell.size / Vector2(leaf_tex.get_width(), leaf_tex.get_height()); tile.scale = full * 0.2; ui.add_child(tile); bugs.append(tile)
		var t4 := create_tween(); t4.tween_property(tile, "scale", full, 0.25).set_trans(Tween.TRANS_BACK)
	shake = 0.4
	var t2 := create_tween(); t2.tween_property(self, "pitch", 0.0, 0.5); t2.parallel().tween_property(self, "head_pitch", 0.0, 0.5)
	t2.parallel().tween_property(self, "fw_open", 0.0, 0.4); t2.parallel().tween_property(self, "flap", 0.0, 0.3); t2.parallel().tween_property(self, "pinch", 0.0, 0.4)
	t2.parallel().tween_property(self, "glow", 0.0, 0.5)
	await wait(2.0)
	for k in picks:
		var cell: ColorRect = board_cells[k]; tw(cell, "color", cell.get_meta("old"), 0.3)
	for b in bugs: b.queue_free()

# ---------------- skill 3: Bay Lượn (spreads both wing pairs, takes off, circles over the board, lands) ----------------
func _skill_bay_luon() -> void:
	_label("Bay Lượn!", Color("#ffd23a"))
	tw(self, "glow", 0.6, 0.4)
	await tw(self, "crouch", 0.6, 0.35).finished
	var t1 := create_tween(); t1.tween_property(self, "fw_open", 1.0, 0.30).set_trans(Tween.TRANS_BACK)
	t1.tween_property(self, "hw_open", 1.0, 0.35).set_trans(Tween.TRANS_BACK)
	t1.parallel().tween_property(self, "flap", 1.0, 0.3)
	await t1.finished
	var t2 := create_tween(); t2.tween_property(self, "hlp", 1.0, 0.10).set_trans(Tween.TRANS_EXPO); t2.parallel().tween_property(self, "crouch", 0.0, 0.1)
	await t2.finished
	_dust(_feet(), 40, 2.6)
	var t3 := create_tween(); t3.tween_property(self, "hover", 1.7, 0.9).set_trans(Tween.TRANS_SINE)
	t3.parallel().tween_property(self, "hlp", 2.0, 0.6); t3.parallel().tween_property(self, "tuck", 1.0, 0.6)
	t3.parallel().tween_property(self, "pitch", 6.0, 0.6)
	await t3.finished
	var home := root.position; var tt := 0.0; var dur := 3.2
	while tt < dur:                                            # one loop over the yard, banking into the turn
		var dt := get_process_delta_time(); tt += dt; var a := tt / dur * TAU
		root.position.x = home.x + sin(a) * 1.6; root.position.z = home.z + (1.0 - cos(a)) * 0.7
		face = -FACE0 + atan2(-(cos(a) * 2.0), (sin(a) * 0.9)) * 0.0 + (-a)
		J["center"].rotation.x = deg_to_rad(12.0 * sin(a))
		await get_tree().process_frame
	root.position.x = home.x; root.position.z = home.z
	await tw(self, "face", 0.0, 0.5).finished
	var t4 := create_tween(); t4.tween_property(self, "hover", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t4.parallel().tween_property(self, "tuck", 0.0, 0.6); t4.parallel().tween_property(self, "hlp", 0.0, 0.8); t4.parallel().tween_property(self, "pitch", 0.0, 0.6)
	await t4.finished
	_dust(_feet(), 30, 2.0); shake = 0.5
	var t5 := create_tween(); t5.tween_property(self, "crouch", 0.5, 0.1); t5.tween_property(self, "crouch", 0.0, 0.3)
	t5.parallel().tween_property(self, "flap", 0.0, 0.3); t5.parallel().tween_property(self, "hw_open", 0.0, 0.35)
	await t5.finished
	await tw(self, "fw_open", 0.0, 0.3).finished
	tw(self, "glow", 0.0, 0.4)
