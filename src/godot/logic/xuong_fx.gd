extends RefCounted
# Hiệu ứng hạt của xưởng (lửa, hơi, khói, nước, giọt): số chép từ README từng xưởng trong godot/xuong/<thư mục>/
# và chuẩn chung godot/xuong/LUA.md. Lửa = CPUParticles2D texture <thư mục>_lua (lưỡi lửa trắng), ADD, unshaded,
# vẽ giữa ảnh r và ảnh che; hơi/khói vẽ sau khung chạy. Chỉ bật khi xưởng chạy.

# lửa miệng bếp (lò bánh quê, LUA.md) / kiềng / lò bánh mì gốc
const MIENG := {"life": 0.7, "spread": 10.0, "v": [6.0, 11.5], "g": [0.0, -7.5], "sc": [0.036, 0.063]}
const KIENG := {"life": 0.55, "spread": 22.0, "v": [3.5, 6.5], "g": [0.0, -5.0], "sc": [0.0234, 0.0432]}
const LBM := {"life": 0.7, "spread": 10.0, "v": [4.5, 8.5], "g": [0.0, -6.0], "sc": [0.0216, 0.0413]}
const W := ["#ffffff", "#c8c8d0"]        # màu nhân hơi: ngày, đêm
const K := ["#cecbc6", "#96969c"]        # màu nhân khói củi

static func _f(base: Dictionary, pts: String, amount: int, extra := {}) -> Dictionary:
	var e := base.duplicate()
	e.merge({"kind": "lua", "pts": pts, "amount": amount, "tex": "lua"}, true)
	e.merge(extra, true)
	return e

# hơi/khói: [điểm, texture, amount, lifetime, randomness, spread, v, gravity, scale a -> b, [[t, alpha]...], [màu ngày, đêm]]
static func _s(pts: String, tex: String, amount: int, life: float, rnd: float, spread: float, v: float, g: Array, sc: Array, al: Array, col: Array) -> Dictionary:
	return {"kind": "hoi", "pts": pts, "tex": tex, "amount": amount, "life": life, "rnd": rnd, "spread": spread, "v": [v, v], "g": g,
		"sc": sc, "al": al, "col": col}

static func list(dir: String) -> Array:
	var A1 := [[0.0, 0.0], [0.1, 0.72], [0.45, 0.42], [1.0, 0.0]]
	match dir:
		"bepcui":
			return [_f(KIENG, "lua", 110),
				_s("hoi", "hoi", 16, 2.0, 0.3, 25, 6.0, [-1.5, -1.0], [0.4, 1.8], [[0, 0], [0.12, 0.42], [0.5, 0.24], [1, 0]], W),
				_s("khoi", "hoi", 16, 1.5, 0.3, 30, 6.5, [-1.0, -1.0], [0.4, 2.0], [[0, 0], [0.15, 0.45], [0.5, 0.26], [1, 0]], ["#e4e0da", "#a8a8b0"])]
		"btrang", "hangcha":
			return [_f(MIENG, "lua", 45),
				_s("hoivanh", "hoi", 22, 1.5, 0.3, 30, 7.2, [-2.4, -1.2], [0.3, 1.8], A1, W),
				_s("khoi", "khoi", 10, 2.4, 0.2, 6, 14.4, [-4.2, 0.0], [0.18, 1.92], [[0, 0], [0.08, 0.40], [0.5, 0.24], [1, 0]], K)]
		"duong":
			return [_f(KIENG, "lua", 110),
				_s("hoi", "hoi", 18, 2.2, 0.3, 26, 6.0, [-1.2, -1.0], [0.6, 2.8], [[0, 0], [0.12, 0.40], [0.5, 0.22], [1, 0]], W),
				_s("hoi2", "hoi", 10, 2.0, 0.3, 24, 5.0, [-1.0, -1.0], [0.5, 2.2], [[0, 0], [0.15, 0.28], [0.5, 0.16], [1, 0]], ["#f2ece4", "#b0b0b8"])]
		"lobanh":
			var kh := [[0, 0], [0.08, 0.30], [0.5, 0.18], [1, 0]]
			return [_f(MIENG, "lua", 90),
				_s("khoi1", "khoi", 10, 2.4, 0.2, 6, 13.8, [-4.0, 0.0], [0.17, 1.84], kh, K),
				_s("khoi2", "khoi", 10, 2.4, 0.2, 6, 13.8, [-4.0, 0.0], [0.17, 1.84], kh, K),
				_s("hoi", "hoi", 12, 1.6, 0.3, 20, 11.5, [-2.3, 0.0], [0.29, 1.61], [[0, 0], [0.1, 0.5], [0.45, 0.28], [1, 0]], W)]
		"lobanhmi":
			return [_f(LBM, "lua", 54),
				_s("khoi", "khoi", 16, 2.4, 0.2, 4, 14.0, [-3.5, 0.0], [0.2, 2.0], [[0, 0], [0.08, 0.42], [0.5, 0.25], [1, 0]], K)]
		"muoi":
			return [_f(KIENG, "lua", 55),
				_s("hoi", "hoi", 22, 1.8, 0.3, 25, 7.0, [-1.5, -1.0], [0.42, 2.24], [[0, 0], [0.12, 0.60], [0.5, 0.34], [1, 0]], W)]
		"noikho":
			return [_f(MIENG, "lua", 90),
				_s("hoi", "hoi", 30, 1.7, 0.2, 30, 6.0, [-2.0, -1.0], [0.25, 1.5], A1, W),
				_s("khoi", "khoi", 12, 2.6, 0.2, 22, 8.0, [-5.0, 0.0], [0.35, 2.4], [[0, 0], [0.12, 0.26], [0.5, 0.16], [1, 0]], K)]
		"quanche":
			return [_f(MIENG, "lua", 45),
				_s("hoivanh", "hoi", 30, 1.7, 0.2, 30, 6.0, [-2.0, -1.0], [0.25, 1.5], A1, W),
				_s("khoi", "khoi", 10, 2.4, 0.2, 6, 12.0, [-3.5, 0.0], [0.15, 1.6], [[0, 0], [0.08, 0.40], [0.5, 0.24], [1, 0]], K)]
		"rang":
			return [_f(KIENG, "lua", 110),
				_s("khoi", "khoi", 14, 1.8, 0.3, 28, 6.0, [-1.0, -1.0], [0.5, 2.4], [[0, 0], [0.15, 0.32], [0.5, 0.18], [1, 0]], ["#ece6dc", "#a8a8b0"])]
		"nuong":
			var kv := [[0, 0], [0.08, 0.38], [0.5, 0.22], [1, 0]]
			var base := {"life": 0.7, "spread": 10.0}
			return [_f(base, "luavi", 10, {"v": [5.6, 10.6], "g": [0.0, -7.5], "sc": [0.0248, 0.0428], "off": [0.0, -2.5]}),
				_f(base, "luarom_sau", 22, {"v": [4.2, 7.8], "g": [0.0, -7.2], "sc": [0.0302, 0.0518]}),
				_f(base, "luarom_truoc", 22, {"v": [4.2, 7.8], "g": [0.0, -7.2], "sc": [0.0302, 0.0518]}),
				{"kind": "tia", "pts": "luarom_truoc", "tex": "tialua", "amount": 3, "life": 0.9, "rnd": 0.0, "spread": 35.0, "v": [12.0, 12.0],
					"g": [0.0, -4.8], "sc": [0.12, 0.036], "ramp": [[0.0, "#ffe090", 1.0], [0.5, "#ffa040", 0.9], [1.0, "#ff6020", 0.0]]},
				_s("khoi1", "khoi", 14, 2.6, 0.2, 10, 12.5, [-3.75, 0.0], [0.25, 2.38], kv, ["#d6d3cd", "#9a9aa0"]),
				_s("khoi2", "khoi", 14, 2.6, 0.2, 10, 12.5, [-3.75, 0.0], [0.25, 2.38], kv, ["#d6d3cd", "#9a9aa0"]),
				_s("khoi3", "khoi", 12, 2.2, 0.25, 8, 16.8, [-4.2, 0.0], [0.22, 2.04], [[0, 0], [0.08, 0.35], [0.5, 0.2], [1, 0]], ["#d2ccbf", "#96949a"])]
		"ruongmuoi":
			var e := _s("nuoc", "nuoc", 30, 0.4, 0.25, 14, 8.25, [0.0, 45.0], [0.38, 0.22], [[0, 0.9], [0.6, 0.7], [1, 0]], ["#9fd3d6", "#5f8c96"])
			e.dir = [-8.0, 2.0]
			e.v = [8.25 * 0.75, 8.25 * 1.25]
			return [e]
		"ep":
			# giọt cốt dừa: rơi từ cot tới mặt thau cot_day rồi tắt (alpha 1 tới 0,065 đời hạt)
			return [{"kind": "giot", "pts": "cot", "tex": "giot", "amount": 5, "life": 2.4, "rnd": 0.0, "spread": 0.0, "v": [0.0, 0.0],
				"g": [0.0, 210.0], "sc": [1.0, 1.0], "al": [[0, 1], [0.064, 1], [0.065, 0], [1, 0]], "col": ["#fffcf2", "#c7bfb8"], "ext": [0.28, 0.0]}]
	return []

static func _hex(s: String) -> Color:
	return Color(s)

static func make(e: Dictionary, A: Dictionary) -> CPUParticles2D:
	var raw = A.get(e.pts)
	if raw == null:
		return null
	var pts := PackedVector2Array()
	if raw is Array and raw.size() > 0 and raw[0] is Array:
		for q in raw:
			pts.append(Vector2(float(q[0]), float(q[1])))
	elif raw is Array and raw.size() >= 2:
		pts.append(Vector2(float(raw[0]), float(raw[1])))
	if pts.is_empty():
		return null
	var off: Array = e.get("off", [0.0, 0.0])
	for i in pts.size():
		pts[i] += Vector2(off[0], off[1])
	var p := CPUParticles2D.new()
	p.emitting = false
	p.local_coords = false
	p.amount = int(e.amount)
	p.lifetime = float(e.life)
	p.preprocess = float(e.life)
	p.explosiveness = 0.0
	p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if e.has("ext"):
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(e.ext[0], 0.01)
		p.position = pts[0]
	else:
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
		p.emission_points = pts
	var d: Array = e.get("dir", [0.0, -1.0])
	p.direction = Vector2(d[0], d[1])
	p.spread = float(e.spread)
	p.initial_velocity_min = float(e.v[0])
	p.initial_velocity_max = float(e.v[1])
	p.gravity = Vector2(e.g[0], e.g[1])
	if e.kind == "lua":
		p.randomness = 0.5
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		p.material = m
		p.angle_min = -14.0
		p.angle_max = 14.0
		p.angular_velocity_min = -45.0
		p.angular_velocity_max = 45.0
		p.scale_amount_min = float(e.sc[0])
		p.scale_amount_max = float(e.sc[1])
		p.split_scale = true
		p.scale_curve_x = _curve([[0, 0.75], [0.2, 1.0], [0.6, 0.7], [1, 0.3]])
		p.scale_curve_y = _curve([[0, 0.45], [0.2, 1.0], [0.7, 1.2], [1, 0.9]])
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.1, 0.35, 0.65, 1.0])
		gr.colors = PackedColorArray([Color("#ff6418", 0.0), Color("#f25616", 0.42), Color("#d83e0e", 0.38), Color("#a2260a", 0.26), Color("#3c0802", 0.0)])
		p.color_ramp = gr
		return p
	var m2 := CanvasItemMaterial.new()
	m2.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = m2
	p.randomness = float(e.get("rnd", 0.0))
	if e.kind == "tia":
		# tia lửa: scale (x 1/9) 0.12 -> 0.036, blend Mix
		p.scale_amount_min = 1.0 / 9.0
		p.scale_amount_max = 1.0 / 9.0
		p.scale_amount_curve = _curve([[0, e.sc[0]], [1, e.sc[1]]], 1.0)
		var g2 := Gradient.new()
		var offs := PackedFloat32Array()
		var cols := PackedColorArray()
		for r in e.ramp:
			offs.append(float(r[0]))
			cols.append(Color(String(r[1]), float(r[2])))
		g2.offsets = offs
		g2.colors = cols
		p.color_ramp = g2
		return p
	if e.kind == "giot":
		# giọt rộng ~0,6 đơn vị (ảnh 64x96), kéo dài thêm 60% lúc rơi
		p.scale_amount_min = 0.6 / 64.0
		p.scale_amount_max = 0.6 / 64.0
		p.split_scale = true
		p.scale_curve_x = _curve([[0, 1.0], [1, 1.0]])
		p.scale_curve_y = _curve([[0, 1.0], [0.065, 1.6], [1, 1.6]], 1.6)
	else:
		# 1/9 nhân đường cong a -> b theo tuổi hạt
		p.scale_amount_min = 1.0 / 9.0
		p.scale_amount_max = 1.0 / 9.0
		p.scale_amount_curve = _curve([[0, e.sc[0]], [1, e.sc[1]]], maxf(e.sc[0], e.sc[1]))
	var g3 := Gradient.new()
	var o3 := PackedFloat32Array()
	var c3 := PackedColorArray()
	for a in e.al:
		o3.append(float(a[0]))
		c3.append(Color(1, 1, 1, float(a[1])))
	g3.offsets = o3
	g3.colors = c3
	p.color_ramp = g3
	return p

static func _curve(pts: Array, mx := 1.2) -> Curve:
	var c := Curve.new()
	c.max_value = maxf(mx, 1.2)
	for q in pts:
		c.add_point(Vector2(float(q[0]), float(q[1])))
	for i in c.point_count:
		c.set_point_left_mode(i, Curve.TANGENT_LINEAR)
		c.set_point_right_mode(i, Curve.TANGENT_LINEAR)
	return c
