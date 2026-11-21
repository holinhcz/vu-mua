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
	# BỐ CỤC CẢNH: tấm phản (to nhất có thể, chính giữa) do caro_game đặt. Cảnh chỉ lấp phần trống quanh phản:
	# mỗi món co theo khoảng trống của nó, không bao giờ đè lên phản, không méo.
	var u := 1.0
	if _tex.is_empty() and not Q_fixed:
		Q = clampf(ceilf(scale.x), 2.0, 9.0)   # = điểm ảnh màn / css cảnh
	var f: Rect2 = L.face
	var bimg: Rect2 = L.bimg
	var fm := f.size.x * 0.046 + 4                 # khung gỗ + bóng ngoài lòng phản
	var bo := f.grow(fm)                           # mép ngoài tấm phản
	var wL := bo.position.x; var wR := W - bo.end.x; var hB := H - bo.end.y
	# ---- sân đất (lặp)
	var g := _spr(self, tex("dat"), Vector2.ZERO, false)
	g.region_enabled = true; g.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	g.region_rect = Rect2(0, 0, W * PXU, H * PXU)
	var lt: Array = []
	for i in 6: lt.append(tex("la%d" % i))
	var items := []      # [tên, x, y, cỡ, bóng]
	var chicks := []
	var roof_x := -1.0
	var bc := Vector3.ZERO
	var canopy := {}
	var gl := []
	var cs_ := 1.0
	var sh_of := {}
	for p in LJ.props: sh_of[p[0]] = p[4]
	var side := minf(wL, wR) >= 70.0 or not port
	if side:
		# ---- 2 dải trái / phải (màn ngang, màn gần vuông). Bản thiết kế 1920x920: dải trái 606, dải phải 336.
		var hy := H / 920.0
		var sL := clampf(minf(wL / 606.0, hy), 0.3, 1.6)
		var sR := clampf(minf(wR / 336.0, hy), 0.3, 1.6)
		var colx := (bo.end.x + W) / 2.0
		if wR >= 300.0:
			roof_x = W - 202.0
			colx = (bo.end.x + roof_x) / 2.0
			sR = clampf(minf((roof_x - bo.end.x) / 150.0, hy), 0.3, 1.6)
		var put := func(nm: String, x: float, y: float, sc: float, half: float, lo: float, hi: float):
			var sz := minf(sc, (hi - lo) / (2.0 * half))       # vẫn nhét vừa dải
			x = clampf(x, lo + half * sz, hi - half * sz)
			items.append([nm, x, y, sz, sh_of[nm]])
			return sz
		put.call("ro", colx, H * 0.15, sR, 34, bo.end.x + 4, roof_x if roof_x >= 0 else W)
		put.call("mam", colx, H * 0.41, sR, 40, bo.end.x + 4, roof_x if roof_x >= 0 else W)
		put.call("bong", colx, H * 0.65, sR, 42, bo.end.x + 4, roof_x if roof_x >= 0 else W)
		put.call("lu", (roof_x - 10) if roof_x >= 0 else colx, H * 0.88, sR, 48, bo.end.x + 4, W)
		# dải trái (dưới thẻ người chơi): gà + gà con, nong lúa, nón; chuối ở góc dưới trái
		var gx := wL * 0.62
		var hs: float = put.call("ga", gx, H * 0.40, sL, 70, 0, wL)
		var hp: Vector2 = Vector2(items[-1][1], items[-1][2])
		for c in LJ.chicks:
			chicks.append(Vector3(hp.x + (float(c[0]) - 548.0) * hs, hp.y + (float(c[1]) - 372.0) * hs, c[2]))
		cs_ = hs
		put.call("nong", wL * 0.6, H * 0.65, sL, 72, 0, wL)
		put.call("non", wL * 0.75, H * 0.91, sL, 42, 0, wL)
		bc = Vector3(minf(120.0 * sL, wL * 0.25), H - 120.0 * sL, sL)
		var cv := clampf(minf(wL / 606.0, hy), 0.4, 1.4)
		canopy = {"pos": Vector2.ZERO, "sc": cv, "flip": false}
		fall_scale = cv
	else:
		# ---- màn dọc hẹp: đồ ở dải dưới tấm phản, tán xoài góc trên phải
		var ps := clampf(minf(W / 412.0, (hB - 140.0) / 120.0 + 0.2), 0.35, 1.4)
		items.append(["nong", W * 0.53, H - 42 * ps, 66.0 / 140.0 * ps, [6, 8, 5, 0.42]])
		items.append(["lu", W - 46 * ps, H - 64 * ps, 50.0 / 92.0 * ps, [8, 10, 6, 0.45]])
		items.append(["mam", W - 52 * ps, clampf(bo.end.y + 40 * ps, bo.end.y, H - 120 * ps), 32.0 / 74.0 * ps, [5, 6, 3, 0.42]])
		var hs := 130.0 / 230.0 * ps
		var hp := Vector2(W * 0.68, maxf(H - 178 * ps, bo.end.y + 40 * ps))
		items.append(["ga", hp.x, hp.y, hs, [4, 6, 3, 0.42]])
		for c in LJ.chicks:
			chicks.append(Vector3(hp.x + (float(c[0]) - 548.0) * hs, hp.y + (float(c[1]) - 372.0) * hs, c[2]))
		cs_ = hs
		bc = Vector3(52 * ps, H - 70 * ps, 120.0 / 230.0 * ps)
		canopy = {"pos": Vector2(W + 60 * ps, -200 * ps), "sc": 0.5 * ps, "flip": true}
		fall_scale = 0.55 * ps
	# lá rụng nằm sẵn: rải ngẫu nhiên ngoài tấm phản
	var rg := RandomNumberGenerator.new(); rg.seed = 5
	var want := int(clampf((W * H - bo.get_area()) / 30000.0, 6, 22)); var tries := 0
	while gl.size() < want and tries < 400:
		tries += 1
		var x := rg.randf_range(10, W - 10); var y := rg.randf_range(70, H - 10)
		if bo.grow(10).has_point(Vector2(x, y)) or (roof_x >= 0 and x > roof_x - 10): continue
		gl.append([x, y, rg.randf_range(0, 360), rg.randi_range(0, 5)])
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
	var bi: Rect2 = bimg
	# ảnh phản đã thu đúng số điểm màn: đặt thẳng hàng điểm ảnh, lọc thường (không mipmap) cho nét
	b.position = (bi.position * scale.x).round() / scale.x; b.scale = Vector2.ONE / scale.x; b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(b)
	# ---- đường phấn NÉT: kẻ lại 16x16 đường bằng hình chữ nhật khớp điểm ảnh màn, đè lên vệt phấn vẽ sẵn
	var sc := scale.x
	var lw: float = maxf(2.0, roundf(1.6 * sc / u))      # độ dày (điểm màn)
	var gx0: float = L.gx * sc / u; var gy0: float = L.gy * sc / u; var cpx: float = L.cs * sc / u
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
