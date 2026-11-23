extends Node2D
# CÂU CÁ BỜ KÊNH: hạt nước bằng CPUParticles2D của Godot (Link 11-22 "làm" sau nước mới):
# - tia nước bắn lên khi phao rơi, cá quẫy, cá phóng, cá lên bờ: giọt tròn + hơi nước mờ, rơi theo trọng lực,
#   tới mặt nước thì tắt (shader cắt theo đường nước của từng chỗ bắn, xa thì nhỏ theo phối cảnh).
# - mưa: vệt mưa xéo rơi cả màn + 3 dải giọt nảy trên mặt nước (xa nhỏ, gần to).
# Toạ độ: css px của game (cha có scale K).

const CLIP_SH := """
shader_type canvas_item;
render_mode blend_mix;
uniform float water_y = 1e9;
uniform float flip = 0.0;   // 1 nếu máy nào FRAGCOORD.y tính từ dưới lên
void fragment(){
 vec4 c = texture(TEXTURE, UV) * COLOR;
 float fy = flip > .5 ? 1.0 / SCREEN_PIXEL_SIZE.y - FRAGCOORD.y : FRAGCOORD.y;
 if (fy > water_y) c.a = 0.0;   // dưới mặt nước: tắt (FRAGCOORD.y tính từ trên xuống)
 COLOR = c;
}
"""

var game
var t_dot: ImageTexture
var t_soft: ImageTexture
var t_streak: ImageTexture
var clip_sh: Shader
var rain: CPUParticles2D
var bands: Array = []     # [CPUParticles2D, z gần, z xa]
var _lit := Color.WHITE

func _init(g) -> void:
	game = g

func _ready() -> void:
	t_dot = _drop(32)   # giọt nét: viền rõ, có chấm sáng (Link 11-22 "bọt làm rõ lên, mờ căm")
	t_soft = _radial(48, 1.0)
	t_streak = _streak()
	clip_sh = Shader.new()
	clip_sh.code = CLIP_SH
	rain = CPUParticles2D.new()
	rain.amount = 320
	rain.texture = t_streak
	rain.lifetime = 1.1
	rain.preprocess = 1.0
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.direction = Vector2(-0.12, 1).normalized()
	rain.spread = 2.0
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 900
	rain.initial_velocity_max = 1300
	rain.particle_flag_align_y = true
	rain.scale_amount_min = 0.7
	rain.scale_amount_max = 1.2
	rain.local_coords = false
	rain.emitting = false
	add_child(rain)
	for b in [[2.0, 6.0, 1.2], [6.0, 13.0, .75], [13.0, 30.0, .42]]:
		var p := CPUParticles2D.new()
		p.amount = 70
		p.texture = t_dot
		p.lifetime = .28
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.direction = Vector2(0, -1)
		p.spread = 35
		p.initial_velocity_min = 25 * b[2]
		p.initial_velocity_max = 60 * b[2]
		p.gravity = Vector2(0, 420 * b[2])
		p.scale_amount_min = .10 * b[2]
		p.scale_amount_max = .18 * b[2]
		p.color_ramp = _ramp(.75)
		p.local_coords = false
		p.emitting = false
		add_child(p)
		bands.append([p, b[0], b[1]])

static func _radial(n: int, pw: float) -> ImageTexture:
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / (n / 2.0)
			var a := clampf(1.0 - d, 0, 1)
			im.set_pixel(x, y, Color(1, 1, 1, pow(a, 1.0 / pw) if pw > 1.0 else a * a))
	return ImageTexture.create_from_image(im)

# giọt nước nét: tròn đặc trắng hơi xanh, viền xanh nhạt rõ 1 điểm ảnh, chấm sáng trắng lệch trên trái
static func _drop(n: int) -> ImageTexture:
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	var R := n * .44
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length()
			var a := clampf(R - d + .5, 0, 1)          # mép khử răng cưa 1 điểm ảnh, không nhòe
			var col := Color(.93, .97, 1.0)
			if d > R - n * .09:
				col = Color(.70, .84, .92)              # viền
			var hd := Vector2(x - c + R * .35, y - c + R * .35).length()
			if hd < R * .28:
				col = Color(1, 1, 1)                    # chấm sáng
			im.set_pixel(x, y, Color(col, a))
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)

static func _streak() -> ImageTexture:
	var im := Image.create(3, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		var a := (y / 31.0) * .9
		for x in 3:
			im.set_pixel(x, y, Color(1, 1, 1, a * (1.0 if x == 1 else .35)))
	return ImageTexture.create_from_image(im)

static func _ramp(a0: float) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, a0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(.7, Color(1, 1, 1, a0 * .8))
	return g

# tia nước: giống fx_splash của web (10 + 22*sz giọt, bay lên 0.8..2.2*sqrt(sz), trọng lực 3.2) + hơi nước
func splash(x: float, z: float, sz := 1.0) -> void:
	var L: Dictionary = game.L
	if L.is_empty() or z <= 0.1:
		return
	var p: Vector2 = game.proj(x, z)
	if p.x < -60 or p.x > L.W + 60:
		return
	var u: float = L.F / z          # px cho 1 đơn vị thế giới ở chỗ này
	var k := minf(2.2, u / 160.0)
	var rs := sqrt(sz)
	var d := _emitter(p, t_dot, int(10 + sz * 22), .95 * rs, 0)
	d.direction = Vector2(0, -1)
	d.spread = 16
	d.initial_velocity_min = .8 * rs * u * .4
	d.initial_velocity_max = 2.2 * rs * u * .4
	d.gravity = Vector2(0, 3.2 * u * .9)
	d.scale_amount_min = .035 * k * 2.2 * rs
	d.scale_amount_max = .075 * k * 2.2 * rs
	d.emission_sphere_radius = .04 * u
	d.color_ramp = _ramp(.92)
	if false:   # bỏ hơi nước mờ (Link 11-22: bọt mờ căm)
		var m := _emitter(p, t_soft, 5, .9, 0)
		m.direction = Vector2(0, -1)
		m.spread = 40
		m.initial_velocity_min = .15 * u * rs
		m.initial_velocity_max = .35 * u * rs
		m.gravity = Vector2.ZERO
		m.damping_min = .2 * u
		m.damping_max = .3 * u
		m.scale_amount_min = .4 * k * 2.2 * rs
		m.scale_amount_max = .65 * k * 2.2 * rs
		m.emission_sphere_radius = .1 * u
		m.color_ramp = _ramp(.32)
	# giọt rơi lại làm gợn nhỏ (thay cho giọt vẽ tay của web)
	if sz > .5:
		for i in 3:
			var a := randf() * TAU
			var r := randf_range(.2, .6) * rs
			game.later(randf_range(.35, .8) * rs, game.ripple.bind(x + cos(a) * r * .6, z + sin(a) * r * .4, .18))

func _emitter(p: Vector2, tex: Texture2D, n: int, life: float, _h: float) -> CPUParticles2D:
	var c := CPUParticles2D.new()
	c.position = p
	c.texture = tex
	c.amount = maxi(1, n)
	c.lifetime = life
	c.one_shot = true
	c.explosiveness = .92
	c.randomness = .5
	c.lifetime_randomness = .35
	c.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	c.local_coords = true
	c.color = _lit
	var mt := ShaderMaterial.new()
	mt.shader = clip_sh
	c.material = mt
	c.finished.connect(c.queue_free)
	add_child(c)
	# đường nước của chỗ bắn, theo toạ độ màn hình thật (cha có scale K)
	mt.set_shader_parameter("water_y", (get_global_transform() * (p + Vector2(0, 1.5))).y)
	c.emitting = true
	return c

func step(_dt: float) -> void:
	var L: Dictionary = game.L
	if L.is_empty():
		return
	var tod: Dictionary = game.tod
	var W: Dictionary = game.W
	_lit = Color.WHITE.lerp(tod.tint, .5)
	var r: float = W.rain
	rain.emitting = r > .03
	_set_amount(rain, int(320 * clampf(r, 0, 1) / 32) * 32)
	rain.position = Vector2(L.W * .5 + 60, -40)
	rain.emission_rect_extents = Vector2(L.W * .5 + 120, 10)
	rain.lifetime = (L.H + 80) / 1000.0
	rain.color = Color(225 / 255.0, 235 / 255.0, 245 / 255.0, .6).lerp(Color(.55, .6, .7, .3), tod.night)
	for b in bands:
		var p: CPUParticles2D = b[0]
		var y0: float = game.proj(0, b[2]).y
		var y1: float = minf(game.proj(0, b[1]).y, L.H - L.fgH * .45)
		p.emitting = r > .15
		_set_amount(p, int(70 * clampf(r, 0, 1) / 10) * 10)
		p.position = Vector2(L.W * .5, (y0 + y1) * .5)
		p.emission_rect_extents = Vector2(L.W * .5, maxf(1.0, (y1 - y0) * .5))
		p.color = _lit

# CPUParticles2D không có amount_ratio: đổi số hạt theo nấc (đổi là chạy lại, nên chỉ đổi khi qua nấc)
static func _set_amount(p: CPUParticles2D, n: int) -> void:
	n = maxi(1, n)
	if p.amount != n:
		p.amount = n
