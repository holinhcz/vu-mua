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
var hen := {}
var roof_nodes: Array = []
var ext := Rect2()        # cả cửa sổ (css thiết kế): nền đất / hiên / mái phủ ra hết, món đồ vẫn nằm trong khung
var hen_chicks: Array = []
var _hrng := RandomNumberGenerator.new()

static var _ur := {}
static func _used(n: String) -> Rect2:
	# vùng có lá thật của ảnh (css thiết kế)
	if not _ur.has(n):
		var t := tex(n); var im := t.get_image()
		var r := im.get_used_rect(); var k := float(t.get_width()) / float(im.get_width()) / PXU
		_ur[n] = Rect2(Vector2(r.position) * k, Vector2(r.size) * k)
	return _ur[n]

static func has_art() -> bool:
	return FileAccess.file_exists(D + "layout.json")

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
	roof_nodes = []
	if not has_art():
		# cảnh 9px chưa tải xong (bản web tải ngầm): nền đất trơn + tấm phản, vào đánh liền
		var bg := ColorRect.new(); bg.color = Color8(158, 136, 108); bg.size = Vector2(W, H); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)
		_board(L, L.bimg, board_tex)
		return
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
	var E: Rect2 = ext if ext.size.x > 0 else Rect2(0, 0, W, H)
	var g := _spr(self, tex("dat"), E.position, false, 0.0, u)
	g.region_enabled = true; g.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	g.region_rect = Rect2(E.position.x / u * PXU, E.position.y / u * PXU, E.size.x / u * PXU, E.size.y / u * PXU)
	var lt: Array = []
	for i in 6: lt.append(tex("la%d" % i))
	var items := []      # [tên, x, y, cỡ, bóng]
	var chicks := []
	var roof_x := -1.0
	var bc := Vector3.ZERO
	var tc := Vector3(-99999, -99999, 0.01)   # bụi tre (tâm màn, cỡ)
	var canopy := {}
	var gl := []
	var cs_ := u
	if not port:
		var rxd: float = float(LJ.roof[0])
		roof_x = maxf(P.call(rxd, 0).x, W - 202.0 * u)
		var shift: float = roof_x - P.call(rxd, 0).x        # mái dạt ra mép phải thì lu đi theo mái
		# màn hẹp hơn bản thiết kế: dải trái bị khuất → dồn VỊ TRÍ các món bên trái vào phần thấy được (cỡ giữ nguyên u)
		var sdx: float = maxf(0.0, dB.x - f.position.x / u)
		var Lx := func(x: float) -> float: return sdx + x * (dB.x - sdx) / dB.x if x < dB.x else x
		for p in LJ.props:
			var q: Vector2 = P.call(Lx.call(float(p[1])), float(p[2]))
			if p[0] == "lu": q.x = minf(q.x + shift, roof_x - 58.0 * u)
			if p[0] in ["ro", "bong"]: q.x = (f.end.x + roof_x) * 0.5          # Link 11-22: nia xoài + chậu bông cân giữa khe phản - mái
			if p[0] == "ga": q = P.call(Lx.call(470.0), 520.0)     # Link 11-22 bỏ nia lúa + nón: gà mẹ ra giữa sân trái
			var sc_: float = u
			if p[0] == "ro" and roof_x - f.end.x > 230.0 * u:
				# Link 11-22 "màn lớn nhất nia xoài trống trải": khe rộng thì nia to hơn, dời sát bụi tre (lá tre phủ 1 góc nia)
				sc_ = 1.3 * u; q = Vector2(roof_x - 60.0 * u, f.position.y + 200.0 * u)
			items.append([p[0], q.x, q.y, sc_, p[4]])
		var hx0: float = float(LJ.props.filter(func(e): return e[0] == "ga")[0][1])
		var hdx: float = Lx.call(470.0) - hx0                 # gà con đi theo gà mẹ
		for c in LJ.chicks:
			var q: Vector2 = P.call(float(c[0]) + hdx, float(c[1]) + 148.0)
			chicks.append(Vector3(q.x, q.y, c[2]))
		var bq: Vector2 = P.call(Lx.call(float(LJ.chuoi[0])), float(LJ.chuoi[1]))
		bc = Vector3(bq.x, bq.y, u)
		# bụi tre (Link 11-22 "bên phải trên mái nhà"): mọc sau nhà, tán đè lên mái lá bên phải
		tc = Vector3(maxf(W, roof_x + 202.0 * u) + 15.0 * u, f.position.y + 280.0 * u, u)   # gốc khuất sau mép màn
		canopy = {"pos": P.call(sdx * 0.6, 0), "sc": u, "flip": false}
		for q in LJ.ground_leaves:
			var v: Vector2 = P.call(Lx.call(float(q[0])), float(q[1]))
			gl.append([v.x, v.y, q[2], q[3]])
		fall_scale = u
	else:
		# màn dọc / gần vuông: món neo vào MÉP MÀN THẬT (đổi ra đơn vị thiết kế), co cùng tỉ lệ bàn cờ
		var sd := Rect2(dB - f.position / u, Vector2(W, H) / u)      # màn thấy được, đơn vị thiết kế
		var bd := Rect2(dB, Vector2(dF, dF * 1.037)).grow(4)   # mép ngoài tấm phản
		var mL := bd.position.x - sd.position.x; var mR := sd.end.x - bd.end.x; var mB := sd.end.y - bd.end.y
		var add := func(nm: String, x: float, y: float, sc: float, sh: Array):
			var q: Vector2 = P.call(x, y); items.append([nm, q.x, q.y, sc * u, sh])
		var bot := sd.end.y
		var D := func(v: Vector2) -> Vector2: return dB + (v - f.position) / u      # màn → thiết kế
		var cardR: float = D.call(L.me.end).x                   # mép phải thẻ "Bạn"
		var band0: float = D.call(Vector2(0, L.tip.end.y)).y + 6  # dải trống dưới dòng luật
		var bandH: float = bot - band0
		var rgap: float = sd.end.x - cardR                      # khe phải bên cạnh thẻ
		var hs := 130.0 / 230.0
		var hp: Vector2
		var short_banana := Rect2()
		# góc dưới phải cạnh thẻ "Bạn": chỗ bụi chuối (mọi màn dọc), lá trên chạm đáy khung phản
		var R := Rect2(Vector2(cardR + 6, bd.end.y + 4), Vector2(sd.end.x - cardR - 6, bot - bd.end.y - 4))
		if bandH >= 70:
			# điện thoại dài: dải đất dưới cùng. Mọi món ĐÚNG CỠ THẬT như màn ngang (cỡ 1 = cùng tỉ lệ với phản),
			# không thu nhỏ; chật thì cho lấn ra mép màn. Nong lúa bên trái, gà mẹ mổ lúa sát mép nong, lu giữa, chuối góc phải.
			var gy: float = band0 + bandH * 0.5
			var nr := 74.0 * 66.0 / 140.0
			var nx: float = sd.position.x + nr * 1.3
			var ny: float = clampf(gy, band0 + nr * 0.75, bot - nr * 0.55)
			add.call("nong", nx, ny, 66.0 / 140.0, [6, 8, 5, 0.42])     # cùng cỡ thật như màn ngang
			hs = 130.0 / 230.0
			hp = Vector2(nx + nr * 0.6, clampf(ny - 8, band0 + 30, bot - 30))     # nia lúa đã bỏ: gà mẹ đứng chỗ nia
			if sd.size.x > 720:
				add.call("lu", nx + nr + 150, clampf(gy + 10, band0 + 30, bot - 26), 50.0 / 92.0, [8, 10, 6, 0.45])
			# Link 11-22 "cây chuối to ra dời vô trong": to hơn, tâm lùi vào trong màn
			# Link 11-22: chuối cùng cỡ mọi điện thoại (= màn 412x915), gốc ló ra ngoài mép phải, thấy chủ yếu lá to
			var bw: float = 458.0; var bz_: float = bw / 437.0
			short_banana = Rect2(Vector2(sd.end.x + 40.0, bd.end.y - 2.0 + 114.0 * bz_), Vector2(bw, 0))
		else:
			hp = Vector2(sd.position.x + maxf(mL, 40) * 0.5, bd.position.y + dF * 0.45)
			hs = clampf(mL / 200.0, 0.25, 0.5)
			if rgap >= 70 and mL < 60:
				# điện thoại ngắn (Link 11-21 "bỏ lu, chuối xuống góc dưới phải, xếp cân đối"): gà mẹ cạnh thẻ "Bạn", chuối ôm góc
				var kk := clampf(minf(R.size.x / 170.0, R.size.y / 170.0), 0.3, 0.75)
				hp = Vector2(R.position.x + 26.0, R.position.y + R.size.y * 0.3)     # chuối to ra: gà mẹ đứng mép trái trên, khỏi bị lá che
				hs = 0.8 * kk
				var bw: float = 458.0; var bz_: float = bw / 437.0          # cùng cỡ chuối màn 412x915 (Link 11-22)
				short_banana = Rect2(Vector2(sd.end.x + 40.0, bd.end.y - 2.0 + 114.0 * bz_), Vector2(bw, 0))
			elif rgap >= 70:
				var k2 := clampf(rgap / 120.0, 0.35, 0.55)
				add.call("lu", sd.end.x - 46 * k2 / 0.55, bot - 50 * k2 / 0.55, 50.0 / 92.0 * k2 / 0.55, [8, 10, 6, 0.45])
		if mR >= 60:
			var rs := clampf(mR / 110.0, 0.35, 1.0)
			add.call("ro", sd.end.x - mR * 0.5, bd.position.y + dF * 0.15, rs * 0.7, [5, 6, 3, 0.42])
			add.call("mam", sd.end.x - mR * 0.5, bd.position.y + dF * 0.45, rs * 0.6, [5, 6, 3, 0.42])
			add.call("bong", sd.end.x - mR * 0.5, bd.position.y + dF * 0.75, rs * 0.65, [6, 7, 4, 0.42])
		elif rgap >= 60 and mL >= 60 and bd.end.y < D.call(Vector2(0, L.me.position.y)).y:
			add.call("mam", sd.end.x - rgap * 0.5, (bd.end.y + band0) * 0.5, clampf(rgap / 150.0, 0.3, 32.0 / 74.0), [5, 6, 3, 0.42])
		if mL >= 60:
			var ns := clampf(mL / 160.0, 0.3, 0.5)
			add.call("non", sd.position.x + maxf(mL * 0.5, 40 * ns + 4), bd.position.y + dF * 0.8, ns, [5, 6, 4, 0.42])
		add.call("ga", hp.x, hp.y, hs, [4, 6, 3, 0.42])
		for c in LJ.chicks:
			var q: Vector2 = P.call(hp.x + (float(c[0]) - 548.0) * hs, hp.y + (float(c[1]) - 372.0) * hs)
			chicks.append(Vector3(q.x, q.y, c[2]))
		cs_ = hs * u
		# màn dọc rộng (2 bên phản còn chỗ): bố cục như màn ngang — xoài góc trên trái chạm mép phản, chuối dưới trái trên thẻ "Bạn"
		var meY: float = D.call(Vector2(0, L.me.position.y)).y
		var bq: Vector2 = P.call(sd.position.x + 20, minf(meY - 10, bot - 20))
		bc = Vector3(bq.x, bq.y, clampf(mL * 1.5 / 437.0, 0.3, 0.85) * u)     # lá chuối không lấn lên khung phản
		canopy = {"pos": P.call(sd.position.x * 0.6, sd.position.y - 40), "sc": u, "flip": false}
		if mL < 60 and mR < 60:
			# 2 bên phản không còn chỗ: tán xoài nằm góc trên trái (dưới thanh menu, cạnh thẻ đối thủ), chuối xuống góc dưới phải
			canopy["top"] = Rect2(0, 0, L.opp.position.x + 30, f.position.y - 6)
			canopy.flip = false
			bc = Vector3(-99999, -99999, 0.01)
			if short_banana.size.x > 0:
				var bp: Vector2 = P.call(short_banana.position.x, short_banana.position.y)
				bc = Vector3(bp.x, bp.y, short_banana.size.x / (3934.0 / PXU) * u)   # 3934 = bề ngang lá chuối thật trong ảnh
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
	# ---- lá tre khô nằm sẵn dưới bụi tre (chỉ màn ngang có tre)
	if tc.x > -9999 and roof_x >= 0:
		var rgt := RandomNumberGenerator.new(); rgt.seed = 77
		for i in 9:
			var v := Vector2(rgt.randf_range(roof_x - 150.0 * u, roof_x - 8.0 * u), rgt.randf_range(20.0 * u, f.position.y + 640.0 * u))
			var lt2 := tex("latre%d" % rgt.randi_range(1, 3)); var rr := rgt.randf_range(0, TAU); var ss := rgt.randf_range(1.1, 1.4) * u
			_shadow(self, lt2, v, Vector2(1.0, 1.4), 0.6, 0.35, rr, ss)
			_spr(self, lt2, v, true, rr, ss)
	# ---- đồ vật + gà (không món nào chạm khung phản: món nào lấn thì đẩy ra ngoài)
	var frm: Rect2 = Rect2(f.position, Vector2(f.size.x, f.size.y * 1.037)).grow(6)
	items = items.filter(func(it): return not (it[0] in ["mam", "non", "nong", "ro", "bong", "lu"]))   # Link 11-21 bỏ ca nước; 11-22 bỏ nón lá, nia lúa, nia xoài, chậu bông, lu
	for it in items:
		var ur := _used(it[0]); var tw: Vector2 = tex(it[0]).get_size() / PXU; var s0: float = it[3]
		var r := Rect2(Vector2(it[1], it[2]) + (ur.position - tw / 2) * s0, ur.size * s0)
		if roof_x >= 0 and r.end.x > roof_x - 6: it[1] -= r.end.x - (roof_x - 6); r.position.x -= r.end.x - (roof_x - 6)
		if not r.intersects(frm): continue
		if it[1] < frm.get_center().x:
			it[1] -= r.end.x - frm.position.x
			var room: float = frm.position.x - 2.0
			if r.size.x > room and room > 20:                 # khe hẹp hơn món: thu món lại cho lọt khe, không lẹm mép màn
				var k: float = room / r.size.x; it[3] = s0 * k
				it[1] = frm.position.x - (ur.end.x - tw.x / 2) * s0 * k
		else:
			it[1] += frm.end.x - r.position.x
			var room2: float = (roof_x - 6.0 if roof_x >= 0 else W - 2.0) - frm.end.x
			if r.size.x > room2 and room2 > 20:
				var k2: float = room2 / r.size.x; it[3] = s0 * k2
				it[1] = frm.end.x - (ur.position.x - tw.x / 2) * s0 * k2
	hen = {}
	for it in items:
		var t := tex(it[0]); var sh: Array = it[4]; var s: float = it[3]
		var sdw := _shadow(self, t, Vector2(it[1], it[2]), Vector2(sh[0], sh[1]), sh[2] * s, sh[3], 0.0, s)
		var spr := _spr(self, t, Vector2(it[1], it[2]), true, 0.0, s)
		if it[0] == "ga":
			# gà mẹ đi lại quanh chỗ của nó, dừng mổ thóc; không bao giờ bước lên khung phản / ra khỏi màn
			var ur := _used("ga")
			var rr: float = maxf(ur.size.x, ur.size.y) * s * 0.5
			hen = {"sp": spr, "sd": sdw, "off": Vector2(sh[0], sh[1]) * s, "home": Vector2(it[1], it[2]), "pos": Vector2(it[1], it[2]),
				"r": rr, "roam": rr * 1.1, "head": 2.6, "tgt": Vector2(it[1], it[2]), "wait": 1.0, "peck": 0.0,
				"frm": Rect2(f.position, Vector2(f.size.x, f.size.y * 1.037)), "scr": Rect2(0, 0, W, H), "sp0": spr.position}
	var ck := tex("gacon")
	hen_chicks = []
	for c in chicks:
		var csd := _shadow(self, ck, Vector2(c.x, c.y), Vector2(2, 3), 1.5, 0.4, c.z, cs_)
		var csp := _spr(self, ck, Vector2(c.x, c.y), true, c.z, cs_)
		if not hen.is_empty():
			hen_chicks.append({"sp": csp, "sd": csd, "off": Vector2(2, 3) * cs_, "rel": Vector2(c.x, c.y) - hen.pos, "pos": Vector2(c.x, c.y), "rot": c.z, "ph": randf() * 6.0})
	# ---- mái lá (màn ngang)
	if roof_x >= 0:
		var band := GradientTexture2D.new(); var gr := Gradient.new()
		# bóng mái phủ luôn xuống dưới tua rơm (tua thưa, mép rơm bắt đầu ~11-28 css sau roof_x): không còn dải đất sáng dưới mép mái
		gr.set_color(0, Color(0.09, 0.11, 0.18, 0.0)); gr.set_color(1, Color(0.09, 0.11, 0.18, 0.47)); gr.add_point(72.0 / 112.0, Color(0.09, 0.11, 0.18, 0.47))
		band.gradient = gr; band.width = 112; band.height = 4
		roof_nodes = []
		var bd := Sprite2D.new(); bd.texture = band; bd.centered = false; bd.position = Vector2(roof_x - 72 * u, E.position.y); bd.scale = Vector2(112.0 * u / 112.0, E.size.y / 4.0); add_child(bd)
		var m := _spr(self, tex("mai"), Vector2(roof_x, E.position.y - 10 * u), false, 0.0, u)
		roof_nodes = [bd, m]
		# mái phủ hết chiều cao màn: lặp soi gương theo chiều dọc (liền mạch, không cắt đáy); cửa sổ rộng hơn khung -> mái lặp ngang ra tới mép
		m.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
		m.region_enabled = true; m.region_rect = Rect2(0, 0, maxf(m.texture.get_width(), (E.end.x - roof_x) / u * PXU), (E.size.y / u + 20) * PXU)
	# ---- hiên gạch tàu
	var gt := tex("gach"); var ph := (100.0 if W < 500.0 else 54.0) if port else 30.0     # điện thoại: hiên gạch dài xuống thêm (Link 11-22)      # (css thiết kế, co theo u)
	var th := gt.get_height() / PXU
	# hiên gạch: phủ từ mép trên cửa sổ xuống tới bậc hiên (cửa sổ cao hơn khung thì hiên dài thêm lên trên)
	var gy0: float = minf(0.0, E.position.y)
	var gs := _spr(self, gt, Vector2(E.position.x, gy0), false, 0.0, u)
	gs.region_enabled = true; gs.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var rw_ := (roof_x + 34.0 * u if roof_x >= 0 else E.end.x) - E.position.x     # hiên lùa vào dưới mái (không hở mép)
	var hh: float = ph - gy0 / u
	gs.region_rect = Rect2(E.position.x / u * PXU, (th - fmod(hh, th)) * PXU, rw_ / u * PXU, hh * PXU)
	var st := ColorRect.new(); st.color = Color8(168, 160, 146); st.position = Vector2(E.position.x, ph * u); st.size = Vector2(rw_, 7 * u); st.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(st)
	var sd := ColorRect.new(); sd.position = Vector2(E.position.x, (ph + 7) * u); sd.size = Vector2(rw_, 10 * u); sd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sd.color = Color(0.12, 0.06, 0.02, 0.25); add_child(sd)
	for rn in roof_nodes: move_child(rn, -1)      # mái đè lên hiên (hiên lùa vào dưới mái)
	_board(L, bimg, board_tex)
	# ---- bóng tán xoài, bụi chuối, lá rơi, chuối, tán
	var M: Dictionary = LJ.mango
	# tán + bóng tán KHÔNG BAO GIỜ đè lên tấm phản (Link): đẩy tán ra xa mép phản, mép trên tán luôn khuất ngoài màn
	var cpos: Vector2 = canopy.pos
	var csc: float = canopy.sc
	# khe bên phản hẹp hơn tán: thu cả cây lại cho ~70% tán lọt vào khe (thấy rõ cây, không đè phản)
	var tx0 := 1e9; var tx1 := -1e9
	for i in 4:
		var w3: Array = LJ.mango_wins[i]; var u3 := _used("xoai%d" % i)
		tx0 = minf(tx0, float(w3[0]) + u3.position.x); tx1 = maxf(tx1, float(w3[0]) + u3.end.x + 46.0)
	var fr: Rect2 = Rect2(f.position, Vector2(f.size.x, f.size.y * 1.037))               # mép ngoài khung gỗ thật (không tính lề trong ảnh)
	var gap: float = (W - fr.end.x) if canopy.flip else fr.position.x
	# khe bên phản hẹp: thu tán cho khoảng nửa cây lọt khe (gốc cây khuất ngoài mép màn), mép trên luôn khuất
	# Link 11-21 "tán xoài chạm lên bàn cờ": cây giữ cỡ thật (không thu bé theo khe), mép lá chạm đúng mép khung phản
	csc = maxf(minf(csc, maxf(gap, 50.0) * 2.0 / (tx1 - tx0)), canopy.sc * 0.8)
	cpos.y = minf(cpos.y, 20.0 * csc)
	if canopy.has("top"):
		var tr: Rect2 = canopy.top                              # vùng góc trên trái (màn), tán nằm gọn trong đó
		var ty1 := 0.0
		for i in 4:
			var w4: Array = LJ.mango_wins[i]; ty1 = maxf(ty1, float(w4[1]) + _used("xoai%d" % i).end.y)
		# nửa trên tán khuất trên mép màn (dưới thanh menu), chỉ phần dưới tán thò xuống, đáy tán + bóng vừa chạm trên khung phản
		# Link 11-21 "cây xoài to ra chạm mép bàn": tán to, mép dưới lá chạm đúng mép trên khung phản (bóng được rơi lên khung)
		# Link 11-22 "dời cây xoài ra gần chính giữa chút cho to": tán to hơn (theo cỡ cảnh u), tâm tán ~38% bề ngang màn
		# Link 11-22 "dời cây xoài ra gần chính giữa chút cho to": tán (vốn là 1/4 tròn ở góc) xoay 45° cho vòm tán rủ xuống giữa dải trên,
		# tâm tán ~45% bề ngang, mép dưới lá chạm mép trên khung phản. Số đo vòm sau khi xoay (css tán): đáy lá 682 dưới tâm.
		csc = maxf(tr.size.y / (230.0 if W < 500.0 else 150.0), 0.5 * u)     # điện thoại: tán nhỏ lại cho thấy dáng vòm (Link 11-22)
		var Rc := Vector2(40, -150).rotated(PI / 4.0)
		# Link 11-22 "tán tròn đâu": vòm tán tròn tự nhiên, xoay ít/không xoay; mỗi khung dọc cố định có số dò sẵn
		# (tools caro/nen9 tan_do.py: không mép cắt ảnh nào lọt vào màn, mép phải lá ~2/3 (điện thoại) / ~1/2 (iPad) bề ngang).
		# [góc độ, cỡ, tâm tán x, tâm tán y] theo (bề ngang khung, cao dải trên)
		var TAN := {"360": [0, 1.5, -120, -802.7], "412_235": [0, 1.5, -90, -801.2], "412_145": [0, 1.1, 15, -613.8],
			"474": [5, 1.1, 75, -635.2], "640": [5, 1.2, 135, -704.2], "768": [10, 1.4, 240, -836.5], "860": [10, 1.5, 270, -905.1]}
		var key := str(int(W)) + ("_" + str(int(round(tr.size.y))) if int(W) == 412 else "")
		if TAN.has(key):
			var tv: Array = TAN[key]
			var ang: float = deg_to_rad(float(tv[0]))
			csc = float(tv[1])
			cpos = Vector2(float(tv[2]), float(tv[3])) - Vector2(40, -150).rotated(ang) * csc
			canopy["rot"] = ang
		else:
			cpos = Vector2(W * 0.45, tr.size.y + 4.0 - 682.0 * csc) - Rc * csc
			canopy["rot"] = PI / 4.0
	canopy.sc = csc
	var fl := -1.0 if canopy.flip else 1.0
	var need := 0.0                                          # dời ngang ít nhất để không lớp lá / bóng nào chạm phản
	var bz: Rect2 = fr.grow(-3)                              # lá chạm mép khung (bóng lá được rơi lên khung)
	for i in 4:
		var w2: Array = LJ.mango_wins[i]
		var ur := _used("xoai%d" % i)
		for off in [Vector2.ZERO]:
			var x0: float = float(w2[0]) + ur.position.x + off.x; var x1: float = float(w2[0]) + ur.end.x + off.x
			var y0: float = cpos.y + (float(w2[1]) + ur.position.y + off.y) * csc; var y1: float = cpos.y + (float(w2[1]) + ur.end.y + off.y) * csc
			if y1 < bz.position.y or y0 > bz.end.y: continue
			if canopy.flip:
				need = maxf(need, bz.end.x - (cpos.x - x1 * csc))       # mép trái lớp phải ≥ mép phải phản
			else:
				need = maxf(need, (cpos.x + x1 * csc) - bz.position.x)  # mép phải lớp phải ≤ mép trái phản
	if not canopy.has("top"):
		cpos.x -= fl * need
	canopy.pos = cpos
	var croot := Node2D.new(); croot.position = canopy.pos
	croot.scale = Vector2(-canopy.sc if canopy.flip else canopy.sc, canopy.sc)
	croot.rotation = canopy.get("rot", 0.0)
	add_child(croot)
	var ph4 := [0.0, 1.7, 3.1, 4.6]; var amps := [5.0, 7.0, 6.0, 8.0]
	var xt: Array = []
	var shoff := Vector2(-46 if canopy.flip else 46, 62)
	if canopy.has("rot"): shoff = shoff.rotated(-float(canopy.rot))     # bóng vẫn đổ đúng hướng nắng khi tán xoay
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
	if tc.x > -9999:
		# bụi tre: không lá nào chạm khung phản (đẩy ra phía mép màn gần nhất)
		# ảnh tre chỉ giữ nửa trái bụi: tâm gốc = (cao/2, cao/2) điểm ảnh
		var tt := tex("tre"); var tur := _used("tre"); var tcp := Vector2(tt.get_height(), tt.get_height()) / 2.0
		var trr := Rect2(Vector2(tc.x, tc.y) + (tur.position - tcp / PXU) * tc.z, tur.size * tc.z)
		var fz: Rect2 = fr.grow(-3)
		if trr.intersects(fz):
			# dời ít nhất theo 1 hướng (trái/phải/lên/xuống) cho lá vừa chạm mép khung
			var mv := [Vector2(fz.position.x - trr.end.x, 0), Vector2(fz.end.x - trr.position.x, 0), Vector2(0, fz.position.y - trr.end.y), Vector2(0, fz.end.y - trr.position.y)]
			var best: Vector2 = mv[0]
			for m in mv:
				if m.length() < best.length(): best = m
			tc.x += best.x; tc.y += best.y
		var t0p := Vector2(tc.x, tc.y) - tcp / PXU * tc.z
		var tsh := _spr(self, tt, t0p + Vector2(30, 40) * tc.z, false, 0.0, tc.z)
		tsh.material = _wmat(tt, tcp, tcp.x, 0.0, 2.0 * PXU, 0.05, 2.3, 0.0, 0.0, 0.45, log(6.0 * PXU) / log(2.0))
		var tn := _spr(self, tt, t0p, false, 0.0, tc.z)
		tn.material = _wmat(tt, tcp, tcp.x, 0.0, 1.6 * PXU, 0.05, 2.3, 0.06, 0.0, 0.0, 0.0)
	for i in 4:
		var w: Array = LJ.mango_wins[i]
		var s := _spr(croot, xt[i], Vector2(w[0], w[1]), false)
		s.material = _wmat(xt[i], (Vector2(M.cx, M.cy) - Vector2(w[0], w[1])) * PXU, float(M.R) * PXU, amps[i] * PXU, 2.0 * PXU, 0.0, ph4[i], 0.1, 0.0, 0.0, 0.0)
	if tc.x > -9999 and roof_x >= 0:
		# lá tre bay rơi từ bụi tre trên mái: chao lượn, gió đẩy về phía sân
		var rgf := RandomNumberGenerator.new(); rgf.seed = 91
		for i in 14:
			var F := {"x0": 0.0, "y0": 0.0, "ph": rgf.randf(), "T": rgf.randf_range(6.5, 11.0), "vx": rgf.randf_range(-110.0, -20.0), "vy": rgf.randf_range(110.0, 190.0),
				"fa": rgf.randf_range(10.0, 30.0), "ff": rgf.randf_range(5.0, 11.0), "spin": rgf.randf_range(-7.0, 7.0), "r0": rgf.randf_range(0, TAU), "v": 0}
			var lt3 := tex("latre%d" % rgf.randi_range(0, 3))
			var o2 := {"F": F, "sd": _shadow(fall, lt3, Vector2.ZERO, Vector2.ZERO, 3.0, 0.3), "sp": _spr(self, lt3, Vector2.ZERO), "k": 2.0 * u}
			o2["ox"] = rgf.randf_range(roof_x - 60.0 * u, W - 10.0 * u); o2["oy"] = rgf.randf_range(-20.0 * u, f.position.y + 420.0 * u)
			leaves.append(o2)
	for F in LJ.falling:
		var o := {"F": F, "sd": _shadow(fall, lt[int(F.v)], Vector2.ZERO, Vector2.ZERO, 3.0, 0.3), "sp": _spr(self, lt[int(F.v)], Vector2.ZERO)}
		# lá rơi từ dưới tán (theo vị trí + cỡ tán)
		var cx: float = canopy.pos.x + (-1.0 if canopy.flip else 1.0) * float(F.x0) * canopy.sc
		o["ox"] = cx - (float(F.vx) * 1.3 * canopy.sc if canopy.flip else 0.0); o["oy"] = canopy.pos.y + float(F.y0) * canopy.sc
		if canopy.has("rot"):
			var wp: Vector2 = croot.transform * Vector2(float(F.x0), float(F.y0)); o["ox"] = wp.x; o["oy"] = wp.y
		leaves.append(o)

func _process(dt: float) -> void:
	t0 += dt
	_hen_step(dt)
	for o in leaves:
		var k: float = o.get("k", fall_scale)
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

func _hen_ok(p: Vector2) -> bool:
	var r: float = hen.r
	var fr: Rect2 = hen.frm.grow(r * 0.85)
	if fr.has_point(p): return false
	var sc: Rect2 = hen.scr.grow(-r * 0.6)
	return sc.has_point(p)

func _hen_step(dt: float) -> void:
	if hen.is_empty(): return
	var pos: Vector2 = hen.pos
	var spd: float = hen.r * 0.55                      # bước gà: ~nửa thân mỗi giây
	if hen.wait > 0.0:
		hen.wait -= dt
		hen.peck += dt
		if hen.wait <= 0.0:
			for i in 12:                                  # chọn chỗ mới quanh nhà, không đụng phản / mép màn
				var a := _hrng.randf() * TAU; var d := _hrng.randf_range(0.3, 1.0) * float(hen.roam)
				var q: Vector2 = hen.home + Vector2(cos(a), sin(a)) * d
				if _hen_ok(q):
					hen.tgt = q; break
	else:
		var to: Vector2 = hen.tgt - pos
		if to.length() < 2.0:
			hen.wait = _hrng.randf_range(1.2, 3.2); hen.peck = 0.0
		else:
			var want := to.angle()
			hen.head = rotate_toward(float(hen.head), want, dt * 3.0)
			if absf(angle_difference(float(hen.head), want)) < 0.6:
				var np := pos + Vector2(cos(hen.head), sin(hen.head)) * minf(spd * dt, to.length())
				if _hen_ok(np): pos = np
				else: hen.wait = 0.5
	hen.pos = pos
	# mổ thóc khi đứng: đầu chúi tới-lui; đi: nhún nhẹ theo bước
	var fwd := Vector2(cos(hen.head), sin(hen.head))
	var bob := 0.0
	if hen.wait > 0.0:
		bob = maxf(0.0, sin(float(hen.peck) * 9.0)) * float(hen.r) * 0.06
	else:
		bob = absf(sin(t0 * 7.0)) * float(hen.r) * 0.02
	var sp: Sprite2D = hen.sp; var sd: Sprite2D = hen.sd
	sp.position = pos + fwd * bob
	sp.rotation = float(hen.head) - 2.6
	sd.position = pos + hen.off; sd.rotation = sp.rotation
	# gà con chạy lon ton theo mẹ, mỗi con một chỗ quanh mẹ
	for c in hen_chicks:
		var rel: Vector2 = c.rel
		var tgt: Vector2 = pos + rel.rotated(float(hen.head) - 2.6) + Vector2(sin(t0 * 0.7 + c.ph), cos(t0 * 0.9 + c.ph)) * float(hen.r) * 0.15
		var d: Vector2 = tgt - c.pos
		if d.length() > 1.0:
			var step := minf(d.length(), spd * 1.6 * dt)
			c.pos += d.normalized() * step
			c.rot = rotate_toward(float(c.rot), d.angle(), dt * 6.0)
		var cs: Sprite2D = c.sp; var cd: Sprite2D = c.sd
		cs.position = c.pos; cs.rotation = c.rot
		cd.position = c.pos + c.off; cd.rotation = c.rot

# tấm phản + đường phấn nét (dùng cả khi cảnh chưa tải xong)
func _board(L: Dictionary, bimg: Rect2, board_tex: Texture2D) -> void:
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
