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
# Q = số điểm ảnh/css nạp vào GPU. File gốc vẫn 9px; màn hình chỉ hiện ~dpr điểm/css nên nạp Q = ceil(điểm màn/css cảnh) (tối đa 9)
# để không tràn bộ nhớ đồ hoạ (9px nguyên = ~756 MB). Kích thước báo về vẫn là 9px (size_override) nên toạ độ không đổi.
static var Q := 9.0
static var Q_fixed := false
static var _qr := {}     # texture -> tỉ lệ ảnh thật / 9px (để mức mờ mipmap của bóng đúng)
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
		# thu nhỏ bằng gộp 2x2 (không gợn viền như Lanczos, viền trong suốt giữ sạch), rồi chỉnh đúng cỡ
		var tw := maxi(1, int(full.x * q)); var th := maxi(1, int(full.y * q))
		while im.get_width() >= tw * 2 and im.get_height() >= th * 2:
			im.shrink_x2()
		im.resize(tw, th, Image.INTERPOLATE_BILINEAR)
	im.generate_mipmaps()
	var t := ImageTexture.create_from_image(im)
	if q < 0.999:
		t.set_size_override(full)
	_qr[t] = minf(q, 1.0)
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

# lod tính cho ảnh 9px; ảnh nạp nhỏ hơn (q) thì bớt đi log2(1/q) mức
static func _lod(t: Texture2D, lod: float) -> float:
	return maxf(0.0, lod + log(float(_qr.get(t, 1.0))) / log(2.0)) if lod > 0.0 else 0.0

func _spr(parent: Node, t: Texture2D, pos: Vector2, centered := true, rot := 0.0, sc := 1.0) -> Sprite2D:
	var s := Sprite2D.new(); s.texture = t; s.centered = centered; s.position = pos
	s.scale = Vector2.ONE * sc / PXU; s.rotation = rot
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(s); return s

func _shadow(parent: Node, t: Texture2D, pos: Vector2, off: Vector2, blur: float, a: float, rot := 0.0, sc := 1.0) -> Sprite2D:
	var s := _spr(parent, t, pos + off * sc, true, rot, sc)
	var m := ShaderMaterial.new(); m.shader = SHAD
	m.set_shader_parameter("tex", t); m.set_shader_parameter("lod", _lod(t, log(maxf(1.0, blur * PXU)) / log(2.0))); m.set_shader_parameter("alpha", a)
	s.material = m; return s

func _wmat(t: Texture2D, pivot: Vector2, reach: float, amp: float, flutter: float, bend: float, phase: float, glint: float, fleck: float, shadow: float, lod: float) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = WIND
	var p := {"noise": noise_tex(), "tex": t, "tex_size": t.get_size(), "pivot": pivot, "reach": reach, "amp": amp, "flutter": flutter,
		"bend": bend, "phase": phase, "glint": glint, "fleck": fleck, "shadow": shadow, "lod": _lod(t, lod), "px_scale": PXU}
	for k in p: m.set_shader_parameter(k, p[k])
	return m

# L: bố cục của caro_game (css). board_tex + bimg: tấm phản vẽ ở đây cho đúng lớp (dưới tán cây).
func build(L: Dictionary, W: float, H: float, board_tex: Texture2D) -> void:
	for c in get_children():
		c.queue_free()
	leaves.clear()
	LJ = JSON.parse_string(FileAccess.get_file_as_string(D + "layout.json"))
	var port: bool = L.port
	# BỐ CỤC CẢNH = 1 KHỐI co giãn cùng tấm phản (Link): bản thiết kế (ngang 1920x920, dọc 412x891) đặt mọi món
	# quanh tấm phản; trên màn thật cả khối được co theo đúng tỉ lệ tấm phản (u) và neo vào tấm phản.
	if _tex.is_empty() and not Q_fixed:
		Q = clampf(ceilf(scale.x), 2.0, 9.0)   # = điểm ảnh màn / css cảnh
	var f: Rect2 = L.face
	var bimg: Rect2 = L.bimg
	var dB: Vector2; var dF: float
	if port:
		dB = Vector2(9, 171); dF = 394.0
	else:
		dB = Vector2(float(LJ.board[0]), float(LJ.board[1])); dF = float(LJ.board[2])
	var u: float = f.size.x / dF
	var P := func(x: float, y: float) -> Vector2: return f.position + (Vector2(x, y) - dB) * u
	# ---- sân đất (lặp)
	var g := _spr(self, tex("dat"), Vector2.ZERO, false, 0.0, u)
	g.region_enabled = true; g.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	g.region_rect = Rect2(0, 0, W / u * PXU, H / u * PXU)
	var lt: Array = []
	for i in 6: lt.append(tex("la%d" % i))
	var items := []      # [tên, x, y, cỡ, bóng]
	var chicks := []
	var roof_x := -1.0
	var bc := Vector3.ZERO
	var canopy := {}
	var gl := []
	var cs_ := u
	if not port:
		var rxd: float = float(LJ.roof[0])
		roof_x = maxf(P.call(rxd, 0).x, W - 202.0 * u)
		var shift: float = roof_x - P.call(rxd, 0).x        # mái dạt ra mép phải thì lu đi theo mái
		for p in LJ.props:
			var q: Vector2 = P.call(float(p[1]), float(p[2]))
			if p[0] == "lu": q.x += shift
			items.append([p[0], q.x, q.y, u, p[4]])
		for c in LJ.chicks:
			var q: Vector2 = P.call(float(c[0]), float(c[1]))
			chicks.append(Vector3(q.x, q.y, c[2]))
		var bq: Vector2 = P.call(float(LJ.chuoi[0]), float(LJ.chuoi[1]))
		bc = Vector3(bq.x, bq.y, u)
		canopy = {"pos": P.call(0, 0), "sc": u, "flip": false}
		for q in LJ.ground_leaves:
			var v: Vector2 = P.call(float(q[0]), float(q[1]))
			gl.append([v.x, v.y, q[2], q[3]])
		fall_scale = u
	else:
		# màn dọc / gần vuông: món neo vào MÉP MÀN THẬT (đổi ra đơn vị thiết kế), co cùng tỉ lệ bàn cờ
		var sd := Rect2(dB - f.position / u, Vector2(W, H) / u)      # màn thấy được, đơn vị thiết kế
		var bd := Rect2(dB, Vector2(dF, dF)).grow(dF * 0.046 + 6)   # mép ngoài tấm phản
		var mL := bd.position.x - sd.position.x; var mR := sd.end.x - bd.end.x; var mB := sd.end.y - bd.end.y
		var add := func(nm: String, x: float, y: float, sc: float, sh: Array):
			var q: Vector2 = P.call(x, y); items.append([nm, q.x, q.y, sc * u, sh])
		var bot := sd.end.y
		add.call("nong", sd.position.x + sd.size.x * 0.53, bot - 42, 66.0 / 140.0, [6, 8, 5, 0.42])
		add.call("lu", sd.end.x - 46, bot - 64, 50.0 / 92.0, [8, 10, 6, 0.45])
		var hs := 130.0 / 230.0
		var hp := Vector2(sd.position.x + sd.size.x * 0.68, maxf(bot - 178, bd.end.y + 40))
		if mB < 150 and maxf(mL, mR) >= 60:       # dưới phản hết chỗ → gà ra lề trái
			hs = clampf(mL / 150.0, 0.3, 130.0 / 230.0)
			hp = Vector2(sd.position.x + mL * 0.5, bd.position.y + dF * 0.45)
		if mR >= 60:
			var rs := clampf(mR / 110.0, 0.35, 1.0)
			add.call("ro", sd.end.x - mR * 0.5, bd.position.y + dF * 0.15, rs * 0.7, [5, 6, 3, 0.42])
			add.call("mam", sd.end.x - mR * 0.5, bd.position.y + dF * 0.45, rs * 0.6, [5, 6, 3, 0.42])
			add.call("bong", sd.end.x - mR * 0.5, bd.position.y + dF * 0.75, rs * 0.65, [6, 7, 4, 0.42])
		else:
			add.call("mam", sd.end.x - 52, minf(bd.end.y + 50, bot - 140), 32.0 / 74.0, [5, 6, 3, 0.42])
		if mL >= 60:
			add.call("non", sd.position.x + mL * 0.5, bd.position.y + dF * 0.8, clampf(mL / 160.0, 0.3, 0.5), [5, 6, 4, 0.42])
		add.call("ga", hp.x, hp.y, hs, [4, 6, 3, 0.42])
		for c in LJ.chicks:
			var q: Vector2 = P.call(hp.x + (float(c[0]) - 548.0) * hs, hp.y + (float(c[1]) - 372.0) * hs)
			chicks.append(Vector3(q.x, q.y, c[2]))
		cs_ = hs * u
		var bq: Vector2 = P.call(sd.position.x + 52, bot - 70)
		bc = Vector3(bq.x, bq.y, 120.0 / 230.0 * u)
		canopy = {"pos": P.call(sd.end.x + 60, sd.position.y - 200), "sc": 0.5 * u, "flip": true}
		var rg := RandomNumberGenerator.new(); rg.seed = 5
		var tries := 0
		while gl.size() < 10 and tries < 300:
			tries += 1
			var x := rg.randf_range(sd.position.x + 10, sd.end.x - 10); var y := rg.randf_range(sd.position.y + 70, sd.end.y - 10)
			if bd.grow(8).has_point(Vector2(x, y)): continue
			var v: Vector2 = P.call(x, y)
			gl.append([v.x, v.y, rg.randf_range(0, 360), rg.randi_range(0, 5)])
		fall_scale = 0.55 * u
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
	for c in chicks:
		_shadow(self, ck, Vector2(c.x, c.y), Vector2(2, 3), 1.5, 0.4, c.z, cs_)
		_spr(self, ck, Vector2(c.x, c.y), true, c.z, cs_)
	# ---- mái lá (màn ngang)
	if roof_x >= 0:
		var band := GradientTexture2D.new(); var gr := Gradient.new()
		gr.set_color(0, Color(0.09, 0.11, 0.18, 0.0)); gr.set_color(1, Color(0.09, 0.11, 0.18, 0.47)); band.gradient = gr; band.width = 64; band.height = 4
		var bd := Sprite2D.new(); bd.texture = band; bd.centered = false; bd.position = Vector2(roof_x - 72 * u, 0); bd.scale = Vector2(80.0 * u / 64.0, H / 4.0); add_child(bd)
		var m := _spr(self, tex("mai"), Vector2(roof_x, -10 * u), false, 0.0, u)
		m.region_enabled = true; m.region_rect = Rect2(0, 0, m.texture.get_width(), minf(m.texture.get_height(), (H / u + 20) * PXU))
	# ---- hiên gạch tàu
	var gt := tex("gach"); var ph := 54.0 if port else 30.0      # (css thiết kế, co theo u)
	var th := gt.get_height() / PXU
	var gs := _spr(self, gt, Vector2.ZERO, false, 0.0, u)
	gs.region_enabled = true; gs.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var rw_ := (roof_x if roof_x >= 0 else W)
	gs.region_rect = Rect2(0, (th - fmod(ph, th)) * PXU, rw_ / u * PXU, ph * PXU)
	var st := ColorRect.new(); st.color = Color8(168, 160, 146); st.position = Vector2(0, ph * u); st.size = Vector2(rw_, 7 * u); st.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(st)
	var sd := ColorRect.new(); sd.position = Vector2(0, (ph + 7) * u); sd.size = Vector2(rw_, 10 * u); sd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sd.color = Color(0.12, 0.06, 0.02, 0.25); add_child(sd)
	# ---- tấm phản
	var b := Sprite2D.new(); b.texture = board_tex; b.centered = false
	var bi: Rect2 = bimg
	# ảnh phản đã thu đúng số điểm màn: đặt thẳng hàng điểm ảnh, lọc thường (không mipmap) cho nét
	b.position = (bi.position * scale.x).round() / scale.x; b.scale = Vector2.ONE / scale.x; b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(b)
	# ---- đường phấn NÉT: kẻ lại 16x16 đường bằng hình chữ nhật khớp điểm ảnh màn, đè lên vệt phấn vẽ sẵn
	var sc := scale.x
	var lw: float = maxf(2.0, roundf(1.6 * sc))      # độ dày (điểm màn)
	var gx0: float = L.gx * sc; var gy0: float = L.gy * sc; var cpx: float = L.cs * sc
	var span := cpx * 15
	for k in 16:
		for vert in [true, false]:
			var r := ColorRect.new(); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.color = Color(0.96, 0.94, 0.89, 0.9)
			var p0 := roundf((gx0 if vert else gy0) + k * cpx - lw / 2)
			if vert:
				r.position = Vector2(p0, roundf(gy0 - lw / 2)) / sc; r.size = Vector2(lw, roundf(span + lw)) / sc
			else:
				r.position = Vector2(roundf(gx0 - lw / 2), p0) / sc; r.size = Vector2(roundf(span + lw), lw) / sc
			add_child(r)
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
		# lá rơi từ dưới tán (theo vị trí + cỡ tán)
		var cx: float = canopy.pos.x + (-1.0 if canopy.flip else 1.0) * float(F.x0) * canopy.sc
		o["ox"] = cx - (float(F.vx) * 1.3 * canopy.sc if canopy.flip else 0.0); o["oy"] = canopy.pos.y + float(F.y0) * canopy.sc
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
