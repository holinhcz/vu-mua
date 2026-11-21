extends Node2D
# NỀN CỜ CARO 9px: sân đất, hiên gạch tàu, mái lá, đồ vật, gà, tán xoài 4 nhánh + bụi chuối có gió (shader),
# bóng mềm (mipmap), lá rụng nằm sẵn + lá rơi (script). Mỗi món 1 file trong ui/img/caro/nen/, nạp 1 lần.
# Toạ độ trong node này là css (điểm giao diện); ảnh 9 điểm ảnh / css.

const D := "res://ui/img/caro/nen/"
const PXU := 9.0
const WIND := preload("res://logic/caro/wind9.gdshader")
const SHAD := preload("res://logic/caro/shadow9.gdshader")
static var _tex := {}
static var _noise: Texture2D = null
# Q = số điểm ảnh/css nạp vào GPU. File gốc vẫn 9px; màn hình chỉ hiện ~dpr điểm/css nên nạp Q = ceil(dpr) (tối đa 9)
# để không tràn bộ nhớ đồ hoạ (9px nguyên = ~756 MB). Kích thước báo về vẫn là 9px (size_override) nên toạ độ không đổi.
static var Q := 9.0
var LJ: Dictionary
var leaves: Array = []
var t0 := 0.0
var fall_scale := 1.0

static func tex(n: String) -> Texture2D:
	if _tex.has(n):
		return _tex[n]
	var im := Image.new()
	im.load_webp_from_buffer(FileAccess.get_file_as_bytes(D + n + ".webp"))
	im.convert(Image.FORMAT_RGBA8)
	var full := im.get_size()
	var q := minf(Q / PXU, 8192.0 / maxf(full.x, full.y))
	if q < 0.999:
		im.resize(maxi(1, int(full.x * q)), maxi(1, int(full.y * q)), Image.INTERPOLATE_LANCZOS)
	im.generate_mipmaps()
	var t := ImageTexture.create_from_image(im)
	if q < 0.999:
		t.set_size_override(full)
	_tex[n] = t
	return t

static func noise_tex() -> Texture2D:
	if _noise != null:
		return _noise
	var nz := FastNoiseLite.new(); nz.frequency = 0.012; nz.fractal_octaves = 3; nz.seed = 7
	var a := nz.get_seamless_image(256, 256)
	nz.seed = 19; var b := nz.get_seamless_image(256, 256)
	nz.seed = 31; var c := nz.get_seamless_image(256, 256)
	var im := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			im.set_pixel(x, y, Color(a.get_pixel(x, y).r, b.get_pixel(x, y).r, c.get_pixel(x, y).r))
	_noise = ImageTexture.create_from_image(im)
	return _noise

func _spr(parent: Node, t: Texture2D, pos: Vector2, centered := true, rot := 0.0, sc := 1.0) -> Sprite2D:
	var s := Sprite2D.new(); s.texture = t; s.centered = centered; s.position = pos
	s.scale = Vector2.ONE * sc / PXU; s.rotation = rot
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(s); return s

func _shadow(parent: Node, t: Texture2D, pos: Vector2, off: Vector2, blur: float, a: float, rot := 0.0, sc := 1.0) -> Sprite2D:
	var s := _spr(parent, t, pos + off * sc, true, rot, sc)
	var m := ShaderMaterial.new(); m.shader = SHAD
	m.set_shader_parameter("tex", t); m.set_shader_parameter("lod", log(maxf(1.0, blur * PXU)) / log(2.0)); m.set_shader_parameter("alpha", a)
	s.material = m; return s

func _wmat(t: Texture2D, pivot: Vector2, reach: float, amp: float, flutter: float, bend: float, phase: float, glint: float, fleck: float, shadow: float, lod: float) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = WIND
	var p := {"noise": noise_tex(), "tex": t, "tex_size": t.get_size(), "pivot": pivot, "reach": reach, "amp": amp, "flutter": flutter,
		"bend": bend, "phase": phase, "glint": glint, "fleck": fleck, "shadow": shadow, "lod": lod, "px_scale": PXU}
	for k in p: m.set_shader_parameter(k, p[k])
	return m

# L: bố cục của caro_game (css). board_tex + bimg: tấm phản vẽ ở đây cho đúng lớp (dưới tán cây).
func build(L: Dictionary, W: float, H: float, board_tex: Texture2D) -> void:
	for c in get_children():
		c.queue_free()
	leaves.clear()
	LJ = JSON.parse_string(FileAccess.get_file_as_string(D + "layout.json"))
	var port: bool = L.port
	var f: Rect2 = L.face
	# ---- sân đất (lặp)
	var g := _spr(self, tex("dat"), Vector2.ZERO, false)
	g.region_enabled = true; g.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	g.region_rect = Rect2(0, 0, W * PXU, H * PXU)
	var lt: Array = []
	for i in 6: lt.append(tex("la%d" % i))
	# ---- vị trí đồ (màn ngang: như bản thiết kế 1920x920, co theo khổ; màn dọc: đặt riêng)
	var items := []      # [tên, x, y, cỡ, bóng]
	var chicks := []
	var hen := Vector3.ZERO
	var roof_x := -1.0
	var bc := Vector3.ZERO
	var canopy := {}
	var gl := []
	if not port:
		var sl := clampf(f.position.x / 647.0, 0.55, 1.4)
		var sy := H / 920.0
		var bx := f.end.x
		roof_x = maxf(bx + 175, W - 202)
		var sx := (bx + roof_x) / 2.0 + 2
		for p in LJ.props:
			var nm: String = p[0]
			var x: float; var y: float = float(p[2]) * sy
			if nm in ["ro", "mam", "bong"]:
				x = sx + (float(p[1]) - 1633.0)
			elif nm == "lu":
				x = roof_x - 10
			else:
				x = float(p[1]) * sl
			items.append([nm, x, y, 1.0, p[4]])
		for c in LJ.chicks:
			chicks.append(Vector3(float(c[0]) * sl, float(c[1]) * sy, c[2]))
		bc = Vector3(float(LJ.chuoi[0]) * sl, float(LJ.chuoi[1]) * sy, 1.0)
		canopy = {"pos": Vector2.ZERO, "sc": 1.0, "flip": false}
		for q in LJ.ground_leaves:
			var x := float(q[0]) * sl
			if x > f.position.x - 14: continue
			gl.append([x, float(q[1]) * sy, q[2], q[3]])
		fall_scale = 1.0
	else:
		var y0 := f.end.y + 100
		items.append(["nong", W * 0.53, H - 42, 66.0 / 140.0, [6, 8, 5, 0.42]])
		items.append(["lu", W - 46, H - 64, 50.0 / 92.0, [8, 10, 6, 0.45]])
		items.append(["mam", W - 52, minf(f.end.y + 72, H - 170), 32.0 / 74.0, [5, 6, 3, 0.42]])
		var hs := 130.0 / 230.0
		var hp := Vector2(W * 0.68, H - 178)
		items.append(["ga", hp.x, hp.y, hs, [4, 6, 3, 0.42]])
		for c in LJ.chicks:
			chicks.append(Vector3(hp.x + (float(c[0]) - 548.0) * hs, hp.y + (float(c[1]) - 372.0) * hs, c[2]))
		bc = Vector3(52, H - 70, 120.0 / 230.0)
		canopy = {"pos": Vector2(W + 60, -200), "sc": 0.5, "flip": true}
		var rg := RandomNumberGenerator.new(); rg.seed = 5
		while gl.size() < 9:
			var x := rg.randf_range(10, W - 10); var y := rg.randf_range(70, H - 10)
			if Rect2(f.position - Vector2(14, 14), f.size + Vector2(28, 28)).has_point(Vector2(x, y)): continue
			gl.append([x, y, rg.randf_range(0, 360), rg.randi_range(0, 5)])
		fall_scale = 0.55
	# ---- lá rụng nằm sẵn (dưới đồ vật)
	for q in gl:
		var s := fall_scale
		_shadow(self, lt[int(q[3])], Vector2(q[0], q[1]), Vector2(1.2, 1.6), 0.8, 0.35, deg_to_rad(q[2]), s)
		_spr(self, lt[int(q[3])], Vector2(q[0], q[1]), true, deg_to_rad(q[2]), s)
	# ---- đồ vật + gà
	for it in items:
		var t := tex(it[0]); var sh: Array = it[4]; var s: float = it[3]
		_shadow(self, t, Vector2(it[1], it[2]), Vector2(sh[0], sh[1]), sh[2] * s, sh[3], 0.0, s)
		_spr(self, t, Vector2(it[1], it[2]), true, 0.0, s)
	var ck := tex("gacon")
	var cs_: float = 1.0 if not port else 130.0 / 230.0
	for c in chicks:
		_shadow(self, ck, Vector2(c.x, c.y), Vector2(2, 3), 1.5, 0.4, c.z, cs_)
		_spr(self, ck, Vector2(c.x, c.y), true, c.z, cs_)
	# ---- mái lá (màn ngang)
	if roof_x >= 0:
		var band := GradientTexture2D.new(); var gr := Gradient.new()
		gr.set_color(0, Color(0.09, 0.11, 0.18, 0.0)); gr.set_color(1, Color(0.09, 0.11, 0.18, 0.47)); band.gradient = gr; band.width = 64; band.height = 4
		var bd := Sprite2D.new(); bd.texture = band; bd.centered = false; bd.position = Vector2(roof_x - 72, 0); bd.scale = Vector2(80.0 / 64.0, H / 4.0); add_child(bd)
		var m := _spr(self, tex("mai"), Vector2(roof_x, -10), false)
		m.region_enabled = true; m.region_rect = Rect2(0, 0, m.texture.get_width(), minf(m.texture.get_height(), (H + 20) * PXU))
	# ---- hiên gạch tàu
	var gt := tex("gach"); var ph := 54.0 if port else 30.0
	var th := gt.get_height() / PXU
	var gs := _spr(self, gt, Vector2.ZERO, false)
	gs.region_enabled = true; gs.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	gs.region_rect = Rect2(0, (th - fmod(ph, th)) * PXU, ((roof_x if roof_x >= 0 else W)) * PXU, ph * PXU)
	var st := ColorRect.new(); st.color = Color8(168, 160, 146); st.position = Vector2(0, ph); st.size = Vector2(roof_x if roof_x >= 0 else W, 7); st.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(st)
	var sd := ColorRect.new(); sd.position = Vector2(0, ph + 7); sd.size = Vector2(roof_x if roof_x >= 0 else W, 10); sd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sd.color = Color(0.12, 0.06, 0.02, 0.25); add_child(sd)
	# ---- tấm phản
	var b := Sprite2D.new(); b.texture = board_tex; b.centered = false
	var bi: Rect2 = L.bimg
	b.position = bi.position; b.scale = bi.size / board_tex.get_size(); b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(b)
	# ---- bóng tán xoài, bụi chuối, lá rơi, chuối, tán
	var M: Dictionary = LJ.mango
	var croot := Node2D.new(); croot.position = canopy.pos
	croot.scale = Vector2(-canopy.sc if canopy.flip else canopy.sc, canopy.sc)
	add_child(croot)
	var ph4 := [0.0, 1.7, 3.1, 4.6]; var amps := [5.0, 7.0, 6.0, 8.0]
	var xt: Array = []
	var shoff := Vector2(-46 if canopy.flip else 46, 62)
	for i in 4:
		var w: Array = LJ.mango_wins[i]
		var t := tex("xoai%d" % i); xt.append(t)
		var s := _spr(croot, t, Vector2(w[0], w[1]) + shoff, false)
		s.material = _wmat(t, (Vector2(M.cx, M.cy) - Vector2(w[0], w[1])) * PXU, float(M.R) * PXU, amps[i] * 1.5 * PXU, 3.0 * PXU, 0.0, ph4[i], 0.0, 0.3, 0.5, log(7.0 * PXU) / log(2.0))
	var bt := tex("chuoi")
	var bsh := _spr(self, bt, Vector2(bc.x, bc.y) + Vector2(34, 44) * bc.z, true, 0.0, bc.z)
	bsh.material = _wmat(bt, bt.get_size() / 2, bt.get_size().x / 2, 0.0, 1.5 * PXU, 0.035, 0.9, 0.0, 0.0, 0.45, log(6.0 * PXU) / log(2.0))
	var fall := Node2D.new(); add_child(fall)
	var bn := _spr(self, bt, Vector2(bc.x, bc.y), true, 0.0, bc.z)
	bn.material = _wmat(bt, bt.get_size() / 2, bt.get_size().x / 2, 0.0, 1.2 * PXU, 0.035, 0.9, 0.06, 0.0, 0.0, 0.0)
	for i in 4:
		var w: Array = LJ.mango_wins[i]
		var s := _spr(croot, xt[i], Vector2(w[0], w[1]), false)
		s.material = _wmat(xt[i], (Vector2(M.cx, M.cy) - Vector2(w[0], w[1])) * PXU, float(M.R) * PXU, amps[i] * PXU, 2.0 * PXU, 0.0, ph4[i], 0.1, 0.0, 0.0, 0.0)
	for F in LJ.falling:
		var o := {"F": F, "sd": _shadow(fall, lt[int(F.v)], Vector2.ZERO, Vector2.ZERO, 3.0, 0.3), "sp": _spr(self, lt[int(F.v)], Vector2.ZERO)}
		if port:
			o["ox"] = W - 30 - float(F.x0) * 0.55 - 40; o["oy"] = float(F.y0) * 0.4
		else:
			o["ox"] = float(F.x0); o["oy"] = float(F.y0)
		leaves.append(o)

func _process(dt: float) -> void:
	t0 += dt
	var k := fall_scale
	for o in leaves:
		var F: Dictionary = o.F
		var u: float = fmod(t0 / float(F.T) + float(F.ph), 1.0)
		var hgt := 1.0 - u
		var x: float = o.ox + (u * float(F.vx) * 1.3 + sin(u * float(F.ff) + float(F.r0)) * float(F.fa)) * k
		var y: float = o.oy + u * float(F.vy) * 1.3 * k
		var sx: float = absf(cos(u * float(F.ff) * 0.8 + float(F.r0))) * 0.65 + 0.35
		var s := (1.0 + 0.45 * hgt) * k / PXU
		o.sp.position = Vector2(x, y); o.sp.rotation = float(F.r0) + u * float(F.spin) + sin(u * float(F.ff)) * 0.6
		o.sp.scale = Vector2(s * sx, s)
		var fade: float = minf(1.0, minf(u / 0.08, (1.0 - u) / 0.06))
		o.sp.modulate.a = fade
		o.sd.position = Vector2(x + 38 * hgt * k, y + 52 * hgt * k); o.sd.rotation = o.sp.rotation; o.sd.scale = o.sp.scale
		o.sd.modulate.a = (1.0 - 0.5 * hgt) * fade
