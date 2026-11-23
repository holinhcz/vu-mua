extends Node2D
# TÁN XOÀI góc trái trên (Link 11-22 "lấy tán xoài bên caro gắn vào bên trái như cờ gánh"; chép từ coganh logic/cg/cg_tan.gd): 4 lớp ảnh 9px vẽ sẵn của caro
# (ui/img/oq/xoai/xoai0..3, mỗi lớp 1 file, nạp 1 lần), gió + lá rung bằng wind9.gdshader, bóng mềm (mipmap) đổ xuống phải.
# Toạ độ trong node = css tán của caro (9 điểm ảnh / css); gốc cây khuất ngoài góc trái trên, mép cắt ảnh (x, y = -40) luôn ngoài màn.

const D := "res://ui/img/oq/xoai/"
const PXU := 9.0
const WIND := preload("res://logic/oq/wind9.gdshader")
const M := Vector3(40, -150, 600)                     # gốc lắc + tầm với (css tán), như layout.json của caro
const WINS := [Vector2(40, -40), Vector2(40, -40), Vector2(-40, -40), Vector2(-40, -40)]
const SHOFF := Vector2(46, 62)                        # bóng đổ theo nắng (xuống phải)
const PH4 := [0.0, 1.7, 3.1, 4.6]
const AMPS := [5.0, 7.0, 6.0, 8.0]
# mép phải của lá theo từng dải cao 16 css, bắt đầu y = -40 (dò từ ảnh: tools/cg/tan_prof.py)
const PROF := [706, 701, 703, 681, 679, 671, 609, 575, 575, 570, 582, 590, 590, 588, 578, 563, 557, 565, 561, 557, 557, 558, 508, 505, 499, 471, 445, 293, 279, 286, 290, 255, 239, 209, 188, 125, 88]
const CUT := Vector2(-10, -26)                        # vị trí gốc ảnh / cỡ tán: mép cắt ảnh + mép cắt bóng nằm ngoài màn

static var _tex := {}
static var _q := {}
static var _noise: Texture2D = null

# vùng lá (css game) khi tán cỡ sc: các dải ngang (gộp step dải 16 css làm 1)
static func rects(sc: float, step := 1, sh := Vector2.ZERO) -> Array:
	var pos := CUT * sc + sh
	var out := []
	var i := 0
	while i < PROF.size():
		var n := mini(step, PROF.size() - i)
		var mx := -40
		for j in range(i, i + n):
			mx = maxi(mx, PROF[j])
		if mx > -40:
			out.append(Rect2(pos + Vector2(-40, -40 + 16 * i) * sc, Vector2(mx + 40, 16 * n) * sc))
		i += step
	return out

static func tex(n: String, q: float) -> Texture2D:
	# nạp q điểm ảnh / css (file gốc 9px): màn chỉ cần ~ điểm màn / css tán, khỏi tràn bộ nhớ đồ hoạ (giống caro)
	if _tex.has(n) and float(_q[n]) >= q:
		return _tex[n]
	var im := Image.new()
	im.load_webp_from_buffer(FileAccess.get_file_as_bytes(D + n + ".webp"))
	im.convert(Image.FORMAT_RGBA8)
	var full := im.get_size()
	var k := minf(q / PXU, 8192.0 / maxf(full.x, full.y))
	if k < 0.999:
		var tw := maxi(1, int(full.x * k))
		var th := maxi(1, int(full.y * k))
		while im.get_width() >= tw * 2 and im.get_height() >= th * 2:
			im.shrink_x2()
		im.resize(tw, th, Image.INTERPOLATE_BILINEAR)
	im.generate_mipmaps()
	var t := ImageTexture.create_from_image(im)
	if k < 0.999:
		t.set_size_override(full)
	_tex[n] = t
	_q[n] = q
	return t

static func noise_tex() -> Texture2D:
	if _noise != null:
		return _noise
	var nz := FastNoiseLite.new()
	nz.frequency = 0.012
	nz.fractal_octaves = 3
	var ch := []
	for sd in [7, 19, 31]:
		nz.seed = sd
		ch.append(nz.get_seamless_image(256, 256))
	var im := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			im.set_pixel(x, y, Color(ch[0].get_pixel(x, y).r, ch[1].get_pixel(x, y).r, ch[2].get_pixel(x, y).r))
	_noise = ImageTexture.create_from_image(im)
	return _noise

func _wmat(t: Texture2D, q: float, i: int, amp: float, flutter: float, glint: float, fleck: float, shadow: float, blur: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WIND
	# lod tính theo ảnh 9px; ảnh nạp nhỏ hơn thì bớt log2(9/q) mức
	var lod := maxf(0.0, log(blur * PXU) / log(2.0) + log(minf(q / PXU, 1.0)) / log(2.0)) if blur > 0.0 else 0.0
	var p := {"noise": noise_tex(), "tex": t, "tex_size": t.get_size(), "pivot": (Vector2(M.x, M.y) - WINS[i]) * PXU, "reach": M.z * PXU,
		"amp": amp * PXU, "flutter": flutter * PXU, "bend": 0.0, "phase": PH4[i], "glint": glint, "fleck": fleck, "shadow": shadow, "lod": lod, "px_scale": PXU}
	for key in p:
		m.set_shader_parameter(key, p[key])
	return m

func _spr(t: Texture2D, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.position = pos
	s.scale = Vector2.ONE / PXU
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(s)
	return s

# các chỗ đặt tán (cỡ sc, độ dời sh) mà lá không chạm vùng cấm (bàn cờ), xếp theo phần lá thấy được (dưới thanh công cụ) nhiều nhất.
# tán to được đẩy lùi ra ngoài mép trái/trên tối đa 30% (gốc cây khuất xa hơn).
static func choices(ban: Rect2, vis: Rect2) -> Array:
	return choices_in([ban], vis)

# như choices, nhiều vùng cấm (ô ăn quan: bàn + 2 rổ + thẻ mình)
static func choices_in(bans: Array, vis: Rect2, more := false) -> Array:
	# more: điện thoại dọc hẹp (Link 11-23 nhận xét 2) -> cho đẩy tán ra ngoài mép xa hơn để tán to hơn
	var out := []
	var sc := 1.2
	while sc > 0.299:
		for dy in ([0.0, 0.1, 0.2, 0.3, 0.4, 0.5] if more else [0.0, 0.1, 0.2, 0.3]):
			for dx in ([0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6] if more else [0.0, 0.1, 0.2, 0.3]):
				var sh := -Vector2(dx * 746.0, dy * 592.0) * sc
				var ok := true
				var area := 0.0
				for r in rects(sc, 1, sh):
					var q: Rect2 = r
					for ban in bans:
						if q.intersects(ban):
							ok = false
							break
					if not ok:
						break
					area += q.intersection(vis).get_area()
				if ok:
					out.append({"sc": sc, "sh": sh, "a": area * (1.0 + 0.15 * sc)})
		sc -= 0.05
	out.sort_custom(func(x, y): return x.a > y.a)
	return out

# sc = cỡ tán (css game / css tán), sh = độ dời, K = điểm ảnh màn / css game, sha = độ đậm bóng
func build(sc: float, sh: Vector2, K: float, sha: float) -> void:
	for c in get_children():
		c.queue_free()
	position = (CUT * sc + sh) * K
	scale = Vector2.ONE * sc * K
	var q := clampf(ceilf(sc * K), 2.0, 9.0)
	var xt := []
	for i in 4:
		var t := tex("xoai%d" % i, q)
		xt.append(t)
		var s := _spr(t, WINS[i] + SHOFF)
		s.material = _wmat(t, q, i, AMPS[i] * 1.5, 3.0, 0.0, 0.3, sha, 10.0)
	for i in 4:
		var s := _spr(xt[i], WINS[i])
		s.material = _wmat(xt[i], q, i, AMPS[i], 2.0, 0.1, 0.0, 0.0, 0.0)
