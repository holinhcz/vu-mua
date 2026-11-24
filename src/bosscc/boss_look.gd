# BOSS LOOK: ONE shared standard for every 3D boss (Link 11-22: "fix tận gốc", no per-boss tweaks).
# Every boss project copies this exact file and calls it; never set light/material numbers in a boss main.gd.
#   BossLook.setup_scene(self, bg_color)          -> WorldEnvironment + sun (shadow) + fill, same for all bosses
#   BossLook.skin(albedo_png, emission_png, two_sided) -> matte skin material (same roughness/specular for all)
# Skin textures must come from the shared bake (src/boss/chung/boss_bake.py) so they read alike.
# loaded with: const BossLook = preload("res://boss_look.gd")   (no class_name, works without an editor import)

const AMBIENT_COLOR := Color(0.92, 0.92, 0.90)
const AMBIENT_ENERGY := 0.55
const SUN_ROT := Vector3(-52, 32, 0)
const SUN_COLOR := Color(1.0, 0.96, 0.86)
const SUN_ENERGY := 1.10
const FILL_ROT := Vector3(-15, 210, 0)
const FILL_COLOR := Color(0.75, 0.85, 1.0)
const FILL_ENERGY := 0.35
const ROUGHNESS := 0.8          # matte (11-23 Link "vẫn bóng": 0.6 -> 0.8, spec 0.3 -> 0.2), no wet streak
const SPECULAR := 0.2
const EMISSION := 1.3           # eyes / glowing bits only (emission map is black elsewhere)

static func setup_scene(parent: Node, bg: Color) -> DirectionalLight3D:
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = AMBIENT_COLOR; e.ambient_light_energy = AMBIENT_ENERGY
	env.environment = e; parent.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = SUN_ROT; sun.light_energy = SUN_ENERGY; sun.light_color = SUN_COLOR
	sun.shadow_enabled = true; sun.directional_shadow_max_distance = 30.0; parent.add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = FILL_ROT; fill.light_energy = FILL_ENERGY; fill.light_color = FILL_COLOR; parent.add_child(fill)
	return sun

static func skin(albedo_png: String, emission_png: String, two_sided := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(albedo_png))
	m.emission_enabled = true; m.emission_texture = ImageTexture.create_from_image(Image.load_from_file(emission_png))
	m.emission = Color(1, 1, 1); m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY; m.emission_energy_multiplier = EMISSION
	m.roughness = ROUGHNESS; m.metallic_specular = SPECULAR; m.rim_enabled = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED if two_sided else BaseMaterial3D.CULL_BACK
	return m
