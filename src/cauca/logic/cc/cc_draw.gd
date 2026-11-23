extends Control
# CÂU CÁ BỜ KÊNH: lớp vẽ 2D trên mặt nước (chép 04_world drawBird/drawProps, 05_fx, 07_tackle, 10_main render):
# bóng lục bình + ghe dưới nước (lớp riêng có shader pha màu nước), cò bay, lục bình, ghe hàng + mái chèo,
# hạt nước, cá quẫy, dây + phao, chuồn chuồn, bờ bên này, cần câu, cá bay vô, đom đóm (lớp cộng sáng), mưa.

const A := preload("res://logic/cc/cc_art.gd")
const D := preload("res://logic/cc/cc_data.gd")

const REFL_SH := """
shader_type canvas_item;
uniform vec3 tint = vec3(1.0);
uniform vec3 mixc = vec3(0.0);
varying vec4 vc;
void vertex(){ vc = COLOR; }
void fragment(){
 vec4 t = texture(TEXTURE, UV);
 COLOR = vec4(mix(t.rgb * tint, mixc, .55), t.a * vc.a);
}
"""
const GHE_OX := 22.0
const GHE_OY := 51.0

class Lay extends Control:
	var fn: Callable
	var nm := ""
	static var T := {}        # đo: tổng µs vẽ mỗi lớp (đồng hồ đo đọc rồi xoá)
	func _init(f: Callable, n := "") -> void:
		fn = f
		nm = n
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		fn.call(self)
		T[nm] = T.get(nm, 0) + Time.get_ticks_usec() - t0

var game
var l_refl: Lay
var l_main: Lay
var l_fg: Lay        # bờ bên này (ảnh ghép sẵn từ ảnh nông trại, màu đã nhân alpha -> trộn PREMULT)
var l_top: Lay       # cây bông giấy bờ này + cần câu + cá bay vô
var l_add: Lay
var l_rain: Lay
var refl_mat: ShaderMaterial
var pfx   # cc_fx.gd: tia nước + mưa bằng CPUParticles2D
var _glows: Array = []

func _init(gm) -> void:
	game = gm
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	l_refl = Lay.new(_draw_refl, "refl")
	var sh := Shader.new()
	sh.code = REFL_SH
	refl_mat = ShaderMaterial.new()
	refl_mat.shader = sh
	l_refl.material = refl_mat
	add_child(l_refl)
	l_main = Lay.new(_draw_main, "main")
	add_child(l_main)
	l_fg = Lay.new(draw_fg, "fg")
	var pm := CanvasItemMaterial.new()
	pm.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	l_fg.material = pm
	add_child(l_fg)
	l_top = Lay.new(_draw_top, "top")
	add_child(l_top)
	l_add = Lay.new(_draw_add, "add")
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	l_add.material = am
	add_child(l_add)
	pfx = preload("res://logic/cc/cc_fx.gd").new(game)
	add_child(pfx)
	l_rain = Lay.new(_draw_rain, "rain")
	add_child(l_rain)
	for l in [l_refl, l_main, l_fg, l_top, l_add, l_rain]:
		l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func resize() -> void:
	var L: Dictionary = game.L
	for l in [l_refl, l_main, l_fg, l_top, l_add, l_rain]:
		l.position = Vector2.ZERO
		l.size = Vector2(L.W, L.H)
	_fg_build()

func redraw() -> void:
	var tod: Dictionary = game.tod
	var tc: Color = tod.tint
	var wc: Color = (tod.water as Color).lerp(Color.BLACK, .2)
	refl_mat.set_shader_parameter("tint", Vector3(tc.r, tc.g, tc.b))
	refl_mat.set_shader_parameter("mixc", Vector3(wc.r, wc.g, wc.b))
	for l in [l_refl, l_main, l_fg, l_top, l_add, l_rain]:
		l.queue_redraw()

static func lit_of(tod: Dictionary, k: float) -> Color:
	return Color.WHITE.lerp(tod.tint, k)

static func mulc(c: Color, l: Color, a := 1.0) -> Color:
	return Color(c.r * l.r, c.g * l.g, c.b * l.b, a)

# ============================================================ bóng phản chiếu của đồ nổi (lớp có shader)
func _draw_refl(ci: CanvasItem) -> void:
	var W: Dictionary = game.W
	for p in W.props:
		if p.has("sen"):
			_refl(ci, "sen" + str(p.k), p.x, p.z, SEN_W * SEN_K[p.k] * p.s, sin(W.t * .8 + p.ph) * .25, .9)
		else:
			_refl(ci, "lucbinh" + str(p.k), p.x, p.z, .6 * p.s, sin(W.t * 1.3 + p.ph) * .6, .9)
	if W.boat != null:
		_refl(ci, "ghe", W.boat.x, W.boat.z, 5.2, sin(W.boat.ph * 1.4) * 1.2, .78)

func _refl(ci: CanvasItem, name: String, x: float, z: float, ww: float, bob: float, base: float) -> void:
	var L: Dictionary = game.L
	var t: Texture2D = A.img(name)
	if t == null:
		return
	var s: Vector2 = game.proj(x, z)
	var sw := t.get_size().x
	var sh := t.get_size().y
	var w: float = L.F * ww / z
	var h := w * sh / sw
	if s.x + w < -20 or s.x - w > L.W + 20:
		return
	var by := s.y + bob
	var rh := h * base * .75
	var n := maxi(4, mini(18, int(rh / 3)))
	var srch := sh * base / n
	var T: float = game.W.t
	for i in n:
		var tt := float(i) / n
		var dx := sin(T * 2.1 + i * .9 + x) * (1 + tt * 3) * w * .012
		# hàng i của bóng = hàng (sh*base - i*srch) trở lên của hình gốc, lật dọc
		var y0 := sh * base - (i + 1) * srch
		var dy := by + i * rh / n
		var dh := rh / n + .6
		ci.draw_set_transform(Vector2(0, dy * 2 + dh), 0, Vector2(1, -1))
		ci.draw_texture_rect_region(t, Rect2(s.x - w / 2 + dx, dy, w, dh), Rect2(0, y0, sw, srch), Color(1, 1, 1, .32 * (1 - tt * .8)))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# ============================================================ lớp chính
var dbg_skip := {}
const BG_NEAR := [["bg_tim", .07, 332.0 / 645.0, 487.0 / 592.0, 0.0], ["bg_do", .93, 288.0 / 587.0, 448.0 / 563.0, 2.1]]   # tên, x/màn, neo x, neo y, pha
const SEN_K := [1.0, .7, 1.0, .9]     # sen trắng (1) to quá so với chỗ đứng (Link 11-22) -> nhỏ lại
const SEN_W := .85     # bụi sen rộng (đơn vị kênh), lục bình .6
func _draw_main(ci: CanvasItem) -> void:
	var tod: Dictionary = game.tod
	var W: Dictionary = game.W
	_glows = []
	if not dbg_skip.has("bird"):
		for b in W.birds:
			draw_bird(ci, b, tod)
	if not dbg_skip.has("prop"):
		for p in W.props:
			if p.has("sen"):
				draw_floating(ci, "sen" + str(p.k), p.x, p.z, SEN_W * SEN_K[p.k] * p.s, sin(W.t * .8 + p.ph) * .25, tod, .97)
			else:
				draw_floating(ci, "lucbinh" + str(p.k), p.x, p.z, .6 * p.s, sin(W.t * 1.3 + p.ph) * .6, tod, .9)
	if W.boat != null and not dbg_skip.has("boat"):
		draw_boat(ci, W.boat, tod)
	if not dbg_skip.has("fx"): fx_draw(ci, tod)
	draw_leaps(ci)
	if game.started and not dbg_skip.has("tackle"):
		draw_tackle(ci, tod)
	draw_dragonfly(ci, tod)

func _draw_top(ci: CanvasItem) -> void:
	var tod: Dictionary = game.tod
	draw_near_trees(ci, tod)
	if game.started and not dbg_skip.has("rod"):
		draw_rod(ci, tod)
	draw_landing(ci)

# ------------------------------------------------------------ cò trắng bay: cổ gập chữ S, mỏ vàng dài, chân đen thòng
const WING := [[.22, 0], [.34, -.22], [.3, -.45], [.12, -.68], [-.2, -.88], [-.58, -1.0], [-.66, -.95], [-.6, -.9], [-.72, -.86], [-.66, -.8],
	[-.76, -.74], [-.68, -.68], [-.76, -.6], [-.66, -.54], [-.7, -.44], [-.62, -.36], [-.64, -.26], [-.56, -.18], [-.56, -.08], [-.46, 0]]

func draw_bird(ci: CanvasItem, b: Dictionary, tod: Dictionary) -> void:
	var s: float = 13 * b.s
	var f: float = sin(b.ph)
	var d := signf(b.v)
	var lit: Color = Color.WHITE.lerp(tod.tint, .55)
	var Wc := Color(.98 * lit.r, .98 * lit.g, .96 * lit.b)
	var Sh := Color(.74 * lit.r, .78 * lit.g, .84 * lit.b)
	var shade := Color(.82 * lit.r, .86 * lit.g, .92 * lit.b)
	var ink := Color(70 / 255.0, 80 / 255.0, 90 / 255.0, .55)
	var xf := Transform2D(0, Vector2(b.x, b.y + f * s * .12)) * Transform2D(0, Vector2(d, 1), 0, Vector2.ZERO)
	ci.draw_set_transform_matrix(xf)
	var wing := func(far: bool) -> void:
		var sg := signf(f) if f != 0 else 1.0
		var fy: float = (f * .92 + .08 * sg) * (.78 if far else 1.0)
		var bend := sin(b.ph - .9) * .18
		var o := Vector2(-s * .02 if far else -s * .12, -s * .12)
		var P := []
		for q in WING:
			P.append(o + Vector2((q[0] + bend * q[1] * q[1] * signf(fy)) * s * 1.5, q[1] * s * 2.2 * fy))
		var pts := PackedVector2Array([P[0]])
		for i in range(1, 5):
			var a: Vector2 = pts[pts.size() - 1]
			var mid: Vector2 = (P[i] + P[i + 1]) / 2
			var qp := A.quad_pts(a, P[i], mid, 5)
			for k in range(1, qp.size()):
				pts.append(qp[k])
		pts.append(P[5])
		for i in range(6, P.size()):
			pts.append(P[i])
		var under := fy > 0
		var c0: Color = Sh if far else (shade if under else Wc)
		var c1: Color = shade if far else Wc
		if absf(fy) > .06 and not Geometry2D.triangulate_polygon(pts).is_empty():
			A.grad_poly(ci, pts, o, o + Vector2(0, -s * 2.3 * fy), [[0.0, c0], [1.0, c1]])
		var cl := pts.duplicate()
		cl.append(pts[0])
		ci.draw_polyline(cl, ink, .9, true)
		if not far and absf(fy) > .25:
			ci.draw_polyline(A.quad_pts(o + Vector2(-.1 * s * 1.5, -.08 * s * 2.2 * fy), o + Vector2(-.1 * s * 1.5, -.5 * s * 2.2 * fy), o + Vector2(-.5 * s * 1.5, -.82 * s * 2.2 * fy), 8), Color(110 / 255.0, 125 / 255.0, 140 / 255.0, .35), .9, true)
	wing.call(true)
	ci.draw_line(Vector2(-s * .7, s * .1), Vector2(-s * 1.8, s * .2), Color(40 / 255.0, 40 / 255.0, 40 / 255.0, .85), maxf(.8, s * .05), true)
	ci.draw_line(Vector2(-s * 1.78, s * .2), Vector2(-s * 2.0, s * .24), Color("#e8c030"), maxf(.8, s * .06), true)
	var body := A.cubic_pts(Vector2(s * .55, -s * .05), Vector2(s * .4, -s * .38), Vector2(-s * .6, -s * .32), Vector2(-s * 1.05, -s * .02), 10)
	var b2 := A.cubic_pts(Vector2(-s * 1.05, -s * .02), Vector2(-s * .6, s * .3), Vector2(s * .3, s * .32), Vector2(s * .55, -s * .05), 10)
	for i in range(1, b2.size() - 1):
		body.append(b2[i])
	A.grad_poly(ci, body, Vector2(0, -s * .35), Vector2(0, s * .3), [[0.0, Wc], [.6, Wc], [1.0, Sh]])
	var bc := body.duplicate()
	bc.append(body[0])
	ci.draw_polyline(bc, ink, 1, true)
	A.stroke(ci, A.cubic_pts(Vector2(s * .4, -s * .2), Vector2(s * .75, -s * .45), Vector2(s * .55, s * .2), Vector2(s * .95, s * .05), 10), Wc, s * .26, false)
	var hp := A.ell_pts(Vector2(s * 1.05, 0), s * .2, s * .15, 18, -.1)
	ci.draw_colored_polygon(hp, Wc)
	var hc := hp.duplicate()
	hc.append(hp[0])
	ci.draw_polyline(hc, ink, 1, true)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(s * 1.18, -s * .05), Vector2(s * 1.85, s * .04), Vector2(s * 1.18, s * .06)]), Color("#e8b830"))
	ci.draw_circle(Vector2(s * 1.12, -s * .04), maxf(.6, s * .025), Color("#222222"))
	wing.call(false)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# ------------------------------------------------------------ đồ nổi (lục bình, ghe), bóng ở lớp dưới
func draw_floating(ci: CanvasItem, name: String, x: float, z: float, ww: float, bob: float, tod: Dictionary, base := .9) -> void:
	var L: Dictionary = game.L
	var t: Texture2D = A.img(name)
	if t == null:
		return
	var s: Vector2 = game.proj(x, z)
	var sw := t.get_size().x
	var sh := t.get_size().y
	var w: float = L.F * ww / z
	var h := w * sh / sw
	if s.x + w < -20 or s.x - w > L.W + 20:
		return
	var by := s.y + bob
	var tc: Color = tod.tint
	ci.draw_texture_rect_region(t, Rect2(s.x - w / 2, by - h * base, w, h * base), Rect2(0, 0, sw, sh * base), Color(tc.r, tc.g, tc.b, 1))
	# bóng tiếp xúc mềm trên mặt nước
	var wc: Color = tod.water
	ci.draw_set_transform(Vector2(s.x, by), 0, Vector2(1, .12))
	A.radial(ci, Vector2.ZERO, w * .5, [[0.0, Color(wc.lerp(Color.BLACK, .4), .35)], [1.0, Color(wc, 0)]], 20)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

func draw_boat(ci: CanvasItem, b: Dictionary, tod: Dictionary) -> void:
	var L: Dictionary = game.L
	var bob := sin(b.ph * 1.4) * 1.2
	draw_floating(ci, "ghe", b.x, b.z, 5.2, bob, tod, .78)
	var t: Texture2D = A.img("ghe")
	if t == null:
		return
	var s: Vector2 = game.proj(b.x, b.z)
	var w: float = L.F * 5.2 / b.z
	var k := w / t.get_size().x
	var top: float = s.y + bob - t.get_size().y * k * .78
	var gx: float = s.x - w / 2 + (552 - GHE_OX) * k
	var gy: float = top + (142 - GHE_OY) * k
	var swv: float = sin(b.ph * .8) * .15 if b.mode == "stay" else sin(b.ph * 2.6) * .5
	var ex := gx - cos(.9 + swv) * w * .32
	var ey: float = s.y + bob + w * .02
	var oc := Color(.42, .28, .14).lerp(tod.tint, .3)
	A.stroke(ci, PackedVector2Array([Vector2(gx + w * .03, gy - w * .03), Vector2(ex, ey)]), oc, maxf(1.5, w * .012))
	if b.mode == "stay":
		game.ui.boat_badge(s.x, top - 8)

# ------------------------------------------------------------ hạt nước
func fx_draw(ci: CanvasItem, tod: Dictionary) -> void:
	var L: Dictionary = game.L
	var lit: Color = Color.WHITE.lerp(tod.tint, .5)
	for p in game.FX.p:
		var s: Vector2 = game.proj(p.x, p.z)
		var k := minf(2.2, L.F / p.z / 160)
		var t: float = p.age / p.life
		match p.k:
			"drop":
				var y: float = s.y - p.y * L.F / p.z
				ci.draw_circle(Vector2(s.x, y), maxf(.8, 1.6 * k * p.s), Color(lit, .85 * (1 - t * .5)))
			"crown":
				var r: float = (12 + t * 30) * k * p.s
				var h: float = (1 - t) * 26 * k * p.s
				var pts := PackedVector2Array()
				for i in 17:
					var a := PI + PI * i / 16.0
					pts.append(Vector2(s.x + cos(a) * r, s.y - h * .3 + sin(a) * r * .28))
				ci.draw_polyline(pts, Color(lit, .6 * (1 - t)), maxf(1, 3 * k), true)
			"mist":
				var r: float = (20 + t * 40) * k * p.s
				A.radial(ci, Vector2(s.x, s.y - r * .4), r, [[0.0, Color(lit, .35 * (1 - t))], [1.0, Color(lit, 0)]], 18)
			"bub":
				var r: float = maxf(1, 1.5 * k * p.s * (1 - t * .5))
				var c := Vector2(s.x + sin(p.age * 7) * k, s.y)
				var e := A.ell_pts(c, r, r * .7, 12)
				e.append(e[0])
				ci.draw_polyline(e, Color(lit, .7 * (1 - t)), 1, true)
				ci.draw_rect(Rect2(c.x - r * .3, c.y - r * .5, maxf(1, r * .4), maxf(1, r * .3)), Color(1, 1, 1, .5 * (1 - t)))
			"foam":   # bọt nét: vòng bọt đứt khúc + vài bong bóng nhỏ, không loang mờ
				var r: float = (10 + t * 18) * k * p.s
				var fa := .75 * (1 - t)
				var seed_: int = int(p.x * 97 + p.z * 31)
				for j in 7:
					var a0 := TAU * j / 7.0 + float(seed_ % 7) * .3
					var arc := A.ell_pts(s, r, r * .24, 40).slice(int(a0 / TAU * 40) % 40, int(a0 / TAU * 40) % 40 + 3)
					if arc.size() >= 2:
						ci.draw_polyline(arc, Color(lit, fa), maxf(1.2, 1.6 * k), true)
				for j in 5:
					var a1 := TAU * (j + .5) / 5.0 + float(seed_ % 5)
					var bp := s + Vector2(cos(a1) * r * .75, sin(a1) * r * .2)
					ci.draw_circle(bp, maxf(1.0, 1.4 * k * (1 - t * .5)), Color(lit, fa * .9))

# cá cong mình quẫy: cắt dọc 14 dải, đuôi lắc nhiều nhất (đầu bên phải). clip_y: chỉ vẽ phần trên đường đó (toạ độ khung)
func draw_bent(ci: CanvasItem, t: Texture2D, w: float, hh: float, ph: float, amp: float, mod := Color.WHITE, clip_y := INF) -> void:
	var n := 14
	var tw := t.get_size().x
	var th := t.get_size().y
	var sw := tw / n
	var dw := w / n
	for i in n:
		var u := float(i) / (n - 1)
		var k := pow(1 - u, 1.6)
		var dy := sin(ph - u * 2.4) * amp * hh * 2.2 * k
		var top := -hh / 2 + dy
		var vis := hh
		if clip_y < INF:
			if top >= clip_y:
				continue
			vis = minf(hh, clip_y - top)
		var srcw := minf(sw + .8, tw - i * sw)
		ci.draw_texture_rect_region(t, Rect2(-w / 2 + i * dw, top, dw + .8, vis), Rect2(i * sw, 0, srcw, th * vis / hh), mod)

func draw_leaps(ci: CanvasItem) -> void:
	var L: Dictionary = game.L
	for l in game.FX.leaps:
		var t := clampf(l.age / l.dur, 0, 1)
		var h: float = sin(t * PI) * l.h
		var s: Vector2 = game.proj(l.x, l.z)
		var u: float = L.F / l.z
		var tex: Texture2D = A.img(l.id)
		if tex == null:
			continue
		var w: float = l.len * u * 1.5
		var hh := w * tex.get_size().y / tex.get_size().x
		var y := s.y - h * u
		var xf := Transform2D(l.dir * (-.9 + t * 1.8) * .8, Vector2(s.x, y)) * Transform2D(0, Vector2(l.dir, 1), 0, Vector2.ZERO)
		ci.draw_set_transform_matrix(xf)
		draw_bent(ci, tex, w, hh, l.age * 18, .1 * (1 - t * .5), Color(1, 1, 1, clampf((h * u) / (hh * .3), .25, 1)))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# ------------------------------------------------------------ dây, phao
static func dim(c: Color, tod: Dictionary) -> Color:
	return c.lerp(c.lerp(tod.tint, .8), .6)

# 4 cấp dây (Link 11-23 "dây đổi theo nâng cấp"): cước 0.2 trong mảnh -> 0.35 -> 0.5 xanh lá to -> dây dù bện nâu có vân
const LINE_W := [.55, .7, .85, 1.1]     # css px (điện thoại x3.5 = 2-4 điểm ảnh): dây mảnh, chỉ to hơn chút theo cấp
const LINE_C := [Color(.95, .95, .9), Color(.88, .94, .97), Color(.72, .9, .74), Color(.52, .36, .2)]
const LINE_A := [1.0, 1.05, 1.15, 1.5]
func _li() -> int:
	return clampi(int(game.S.line), 0, 3)
func line_color(tod: Dictionary, a := .6) -> Color:
	var i := _li()
	return Color((LINE_C[i] as Color).lerp(tod.tint, .35), minf(1.0, a * LINE_A[i]))
func line_w() -> float:
	return LINE_W[_li()]

func draw_line_q(ci: CanvasItem, p0: Vector2, p1: Vector2, sag: float, tod: Dictionary, a: float) -> void:
	var i := _li()
	var pts := A.quad_pts(p0, Vector2((p0.x + p1.x) / 2, maxf(p0.y, p1.y) + sag), p1, 16 if i < 3 else 40)
	var c := line_color(tod, a)
	var w := line_w()
	ci.draw_polyline(pts, c, w, true)
	if i == 3:
		# vân bện: đốm sáng xéo xen kẽ dọc dây
		var lc := Color(Color(.86, .7, .46).lerp(tod.tint, .35), c.a)
		var seg := PackedVector2Array()
		for k in range(0, pts.size() - 1, 2):
			var d := (pts[k + 1] - pts[k])
			var n := Vector2(-d.y, d.x).normalized() * w * .3
			seg.append(pts[k] + n); seg.append(pts[k] + d * .6 - n)
		ci.draw_multiline(seg, lc, w * .45)


# hình phao ở (x,y) = điểm mặt nước, h = phần nổi; chìm sink, nghiêng tilt. Phần dưới nước mờ .22 (cắt theo mặt nước)
# phao = ảnh 6px (ui/img/cc/can/phao0-2): cọng lông trên mặt nước, thân bấc dưới nước (mờ như thấy qua nước)
var _can_meta := {}
func _can_m() -> Dictionary:
	if _can_meta.is_empty():
		var j = JSON.parse_string(FileAccess.get_file_as_string(A.DIR + "can/can.json"))
		_can_meta = j if typeof(j) == TYPE_DICTIONARY else {"x": 1}
	return _can_meta
func draw_float_shape(ci: CanvasItem, x: float, y: float, h: float, sink: float, tilt: float, tod: Dictionary, flying: bool) -> void:
	var kind: int = clampi(game.S.flo, 0, 2)
	var nm := "phao%d" % kind
	var m: Dictionary = _can_m().get(nm, {})
	var tx: Texture2D = A.img("can/" + nm)
	if tx == null or m.is_empty():
		return
	var night: float = tod.night
	var f: float = h / float(m.hs)                 # css mỗi điểm ảnh của ảnh
	var iw: float = m.w; var ih: float = m.h; var wl: float = m.wl
	var dc := dim(Color.WHITE, tod)
	var fx := maxf(1.0, 3.0 / (float(m.ws) * f))      # phao xa nhỏ: giữ cọng ít nhất 3 css cho dễ thấy (như bản cũ)
	ci.draw_set_transform_matrix(Transform2D(tilt, Vector2(x, y + sink * h)) * Transform2D(0, Vector2(fx, 1), 0, Vector2.ZERO))
	if flying:
		ci.draw_texture_rect(tx, Rect2(-iw * .5 * f, -wl * f, iw * f, ih * f), false, dc)
	else:
		# cắt ngang ở mặt nước: trên rõ, dưới mờ
		var cut := clampf(wl - sink * h / f, 0.0, ih)
		if cut > 0:
			ci.draw_texture_rect_region(tx, Rect2(-iw * .5 * f, -wl * f, iw * f, cut * f), Rect2(0, 0, iw, cut), dc)
		if cut < ih:
			var uc := Color(Color.WHITE.lerp(tod.water, .5), .3)
			ci.draw_texture_rect_region(tx, Rect2(-iw * .5 * f, (cut - wl) * f, iw * f, (ih - cut) * f), Rect2(0, cut, iw, ih - cut), uc)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if not flying:
		var w := float(m.ws) * f * fx
		if sink < 1.1:
			var e := A.ell_pts(Vector2(x, y), w * 2.4, w * .75, 20)
			e.append(e[0])
			ci.draw_polyline(e, Color(Color.WHITE.lerp(tod.tint, .4), .55), 1, true)
		if kind == 2 and night > .2 and sink < 1.2:
			_glows.append([Vector2(x + sin(tilt) * h, y + sink * h - cos(tilt) * h), h * .9, .8 * night])

static func _rect_pts(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])

# con cá đang dính câu trồi lưng lên mặt nước, bọt quanh
func draw_surfacing(ci: CanvasItem, fx: float, fy: float, tod: Dictionary) -> void:
	var G: Dictionary = game.G
	var L: Dictionary = game.L
	var h = G.hook
	if h == null or h.f.has("junk"):
		return
	var T: float = game.W.t
	var tgt := 0.0
	if h.beh == "jump":
		tgt = 0.0
	elif h.beh == "run":
		tgt = .75
	elif G.dist < 3.5:
		tgt = .9
	elif sin(T * 1.7 + h.size * 9) > .55:
		tgt = .55
	h.surf = lerpf(h.surf, tgt, minf(1, G.dt * 3))
	if h.surf < .04:
		return
	var t: Texture2D = A.img(h.f.id)
	if t == null:
		return
	var w: float = L.F * h.f.vis * h.size / G.fl.z * 1.1
	var hh := w * t.get_size().y / t.get_size().x
	var dir := 1.0 if h.vx >= 0 else -1.0
	var bob := sin(T * 6) * .06
	var show: float = (.22 + .16 * h.surf + bob * h.surf) * hh
	var cx := fx - dir * w * .38
	var wy := fy + 1
	var oy := wy + hh * .5 - show
	var clip := wy - oy
	ci.draw_set_transform_matrix(Transform2D(0, Vector2(cx, oy)) * Transform2D(0, Vector2(dir, 1), 0, Vector2.ZERO))
	draw_bent(ci, t, w, hh, T * 14, .05 + .04 * h.surf, Color(1, 1, 1, minf(1, h.surf * 1.6)), clip)
	# ánh ướt nhòa vô nước ở mép nước
	var wc: Color = tod.water
	var y0 := clip - 4
	var gp := _rect_pts(-w, y0, w * 2, clip - y0)
	ci.draw_polygon(gp, PackedColorArray([Color(wc, 0), Color(wc, 0), Color(wc, .57), Color(wc, .57)]))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	var fc := Color.WHITE.lerp(tod.tint, .3)
	var e1 := A.ell_pts(Vector2(cx, wy), w * .55, w * .07, 24)
	e1.append(e1[0])
	ci.draw_polyline(e1, Color(fc, .35 * h.surf), maxf(1, w * .02), true)
	var e2 := A.ell_pts(Vector2(cx - dir * w * .2, wy + 1), w * .8, w * .1, 24)
	e2.append(e2[0])
	ci.draw_polyline(e2, Color(fc, .14 * h.surf), maxf(1, w * .02), true)
	if randf() < G.dt * 2.5 * h.surf:   # Link 11-22: bọt ít lại (8 -> 2.5 lần/giây)
		game.ripple(G.fl.x - dir * .3, G.fl.z, .2)
		game.fx_splash(G.fl.x - dir * .2, G.fl.z, .25)

func draw_tackle(ci: CanvasItem, tod: Dictionary) -> void:
	var G: Dictionary = game.G
	var L: Dictionary = game.L
	var T: float = game.W.t
	var tip: Vector2 = rod_geom()[2]
	var st: String = G.state
	if st == "idle" or st == "card" or st == "land":
		if st == "idle":
			var sw: float = sin(T * 1.4) * 3 + G.rodV * 2
			var fp := Vector2(tip.x + sw, tip.y + 46)
			draw_line_q(ci, tip, fp - Vector2(0, 2), 0, tod, .5)
			draw_float_shape(ci, fp.x, fp.y, game.float_h(10) * .8, 0, sw * .02, tod, true)
		return
	if st == "cast":
		var u := clampf(G.t / G.flight.dur, 0, 1)
		var e: Vector2 = game.proj(G.fl.x, G.fl.z)
		var p := Vector2(lerpf(tip.x, e.x, u), lerpf(tip.y, e.y, u) - sin(u * PI) * L.H * (.08 + G.fl.z * .006))
		draw_line_q(ci, tip, p, 10 * (1 - u), tod, .5)
		draw_float_shape(ci, p.x, p.y, lerpf(game.float_h(8), game.float_h(G.fl.z), u), 0, u * 9, tod, true)
		return
	if st == "snap":
		var u := clampf(G.t / .5, 0, 1)
		var pts := PackedVector2Array([tip])
		for i in range(1, 9):
			pts.append(Vector2(tip.x - i * 14 * (1 + u * 2) + sin(i * 1.7 + G.t * 30) * 8, tip.y + i * 10 * (1 - u * .5)))
		ci.draw_polyline(pts, line_color(tod, .5 * (1 - u)), line_w(), true)
		return
	if st == "fight":
		var f: Vector2 = game.proj(G.fl.x, G.fl.z)
		draw_surfacing(ci, f.x, f.y, tod)
		var sag := maxf(0, 1 - G.ten * 1.4) * 40
		draw_line_q(ci, tip, f, sag, tod, .75)
		return
	var b: Vector2 = game.float_base()
	var h: float = game.float_h(G.fl.z)
	var tilt: float = G.fl.tilt * 1.35 * (1.0 if G.fl.x >= 0 else -1.0)
	var a := Vector2(b.x + sin(tilt) * h, b.y + G.fl.sink * h - cos(tilt) * h)
	draw_line_q(ci, tip, a, 26 + sin(T) * 3, tod, .55)
	draw_float_shape(ci, b.x, b.y, h, G.fl.sink, tilt, tod, false)

# dáng cần trong khung này (cán, điểm uốn, ngọn) tính 1 lần: dây (lớp dưới) và cần (lớp trên) dùng chung đúng 1 ngọn,
# kể cả lúc kéo cá cần cong + rung -> dây luôn dính đúng khoen ngọn (Link 11-23 "dây dù bị lệch không dính đầu cần")
var _rg_f := -1
var _rg := []
func rod_geom() -> Array:
	var fr := Engine.get_process_frames()
	if fr == _rg_f and not _rg.is_empty():
		return _rg
	_rg_f = fr
	var G: Dictionary = game.G
	var L: Dictionary = game.L
	var b: Vector2 = L.rodButt
	var t: Vector2 = game.rod_tip_pos()
	var sk: float = G.shake * 3
	t += Vector2(randf_range(-sk, sk), randf_range(-sk, sk))
	var c := b + (t - b) * .55
	var ln := (t - b).length()
	c.y -= ln * .16
	c.x += ln * .05
	if G.state == "fight":
		var f: Vector2 = game.proj(G.fl.x, G.fl.z)
		var dv := f - t
		var dd := dv.length()
		if dd == 0:
			dd = 1
		var bb: float = (.08 + .3 * minf(1.3, G.ten)) * ln
		c = b + (t - b) * .62
		c.y -= ln * .04
		t += dv / dd * bb
	G.tipNow = t
	_rg = [b, c, t]
	return _rg

# ------------------------------------------------------------ cần trúc
func draw_rod(ci: CanvasItem, tod: Dictionary) -> void:
	var G: Dictionary = game.G
	var L: Dictionary = game.L
	var rg := rod_geom()
	var b: Vector2 = rg[0]
	var c: Vector2 = rg[1]
	var t: Vector2 = rg[2]
	var k: float = L.H / 900.0 * (.9 if L.portrait else 1.0)
	var lit: Color = Color.WHITE.lerp(tod.tint, .7)
	var mc := Color(lit.r, lit.g, lit.b, 1)
	# cần = ảnh 6px (ui/img/cc/can/can0, tools/cc/bank9/can_phao.py) dán dọc đường cong: cần vẫn uốn khi kéo cá
	const N := 30
	var P := PackedVector2Array()
	P.resize(N + 1)
	var S := 0.0
	for i in N + 1:
		var tt := float(i) / N
		var u := 1 - tt
		P[i] = b * u * u + c * 2 * u * tt + t * tt * tt
		if i > 0:
			S += P[i].distance_to(P[i - 1])
	var ri: int = clampi(int(game.S.rod), 0, 3)       # 4 cấp cần: trúc, tre già, câu lục, ông Năm
	var tx := _rod_tex(S, ri)
	if tx != null:
		var hw := S * _rod_ar * .5
		var pts := PackedVector2Array()
		pts.resize((N + 1) * 2)
		var uvs := PackedVector2Array()
		uvs.resize((N + 1) * 2)
		var cs := PackedColorArray()
		cs.resize((N + 1) * 2)
		var idx := PackedInt32Array()
		idx.resize(N * 6)
		var acc := 0.0
		for i in N + 1:
			if i > 0:
				acc += P[i].distance_to(P[i - 1])
			var d := P[mini(i + 1, N)] - P[maxi(i - 1, 0)]
			d = d.normalized()
			var nr := Vector2(-d.y, d.x) * hw
			var u := acc / S
			pts[i * 2] = P[i] + nr; uvs[i * 2] = Vector2(u, 0)
			pts[i * 2 + 1] = P[i] - nr; uvs[i * 2 + 1] = Vector2(u, 1)
			cs[i * 2] = mc; cs[i * 2 + 1] = mc
			if i < N:
				var q := i * 6
				idx[q] = i * 2; idx[q + 1] = i * 2 + 1; idx[q + 2] = i * 2 + 2
				idx[q + 3] = i * 2 + 1; idx[q + 4] = i * 2 + 3; idx[q + 5] = i * 2 + 2
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cs, uvs, PackedInt32Array(), PackedFloat32Array(), tx.get_rid())
	# ống cước gỗ gần cán, quay khi kéo (1 ảnh, Godot xoay)
	var tt := .2
	var u := 1 - tt
	var rp := b * u * u + c * 2 * u * tt + t * tt * tt
	var R := 17 * k
	var rc := rp + Vector2(-R * .4, -R * .9)
	var hold_run: bool = G.state == "fight" and not G.hold and G.hook != null and G.hook.beh == "run"
	G.reelA += (.35 if G.hold and G.state == "fight" else 0.0) - (.2 if hold_run else 0.0)
	var rt: Texture2D = A.img("can/ongcuoc%d" % ri)
	if rt != null:
		var rm: Dictionary = _can_m().get("ongcuoc%d" % ri, {"r": 8.0, "w": 108})
		var rs := R * (float(rm.w) / 12.0) / 8.0      # ảnh: 6 px/đơn vị, nửa cạnh = w/2/6; ống cước 0 bán kính 8 = R
		ci.draw_set_transform(rc, G.reelA)
		ci.draw_texture_rect(rt, Rect2(-rs, -rs, rs * 2, rs * 2), false, mc)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# ảnh cần thu đúng số điểm ảnh máy theo độ dài trên màn (Lanczos 1 lần mỗi nấc 3%), vẽ 1:1 cho nét
var _rod_src := {}
var _rod_ar := .034
var _rod_t: Texture2D = null
var _rod_k := ""
func _rod_tex(S: float, ri: int) -> Texture2D:
	var nm := "can%d" % ri
	if not _rod_src.has(nm):
		var bb := FileAccess.get_file_as_bytes(A.DIR + "can/" + nm + ".webp")
		var im := Image.new()
		if bb.is_empty() or im.load_webp_from_buffer(bb) != OK:
			return null
		im.convert(Image.FORMAT_RGBA8)
		im.fix_alpha_edges()
		_rod_src[nm] = im
	var src: Image = _rod_src[nm]
	_rod_ar = float(src.get_height()) / float(src.get_width())
	var K: float = game.K
	var want := S * K
	var q := int(round(log(maxf(want, 16.0)) / log(1.03)))
	var key := "%s_%d" % [nm, q]
	if key != _rod_k:
		_rod_k = key
		var w := maxi(16, int(round(pow(1.03, q))))
		var h := maxi(4, int(round(w * _rod_ar)))
		var im: Image = src.duplicate()
		while im.get_width() > w * 2:
			im.resize(im.get_width() / 2, im.get_height() / 2, Image.INTERPOLATE_CUBIC)
		im.resize(w, h, Image.INTERPOLATE_LANCZOS)
		_rod_t = ImageTexture.create_from_image(im)
	return _rod_t

# ------------------------------------------------------------ bờ bên này
# Ghép 1 lần (mỗi lần đổi cỡ màn) từ ảnh 9px của nông trại theo gan.json (tools/cc/bank9/gan_pick.py): nền cỏ n2_co mép
# trên cong, hàng bụi cỏ dọc mép, cụm hoa trên bãi cỏ. Mỗi món thu đúng cỡ trên màn (Lanczos) rồi vẽ 1:1 -> nét.
const GAN := "res://ui/img/cc/gan/"
var _gan := {}
var _fg_tex: Texture2D = null
var _fg_key := ""
var _fg_rect := Rect2()

func _gan_img(nm: String) -> Image:
	var b := FileAccess.get_file_as_bytes(GAN + nm + ".webp")
	var im := Image.new()
	if b.is_empty() or im.load_webp_from_buffer(b) != OK:
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im

func _fg_geom() -> Rect2:
	var L: Dictionary = game.L
	var ar := 2800.0 / 420.0
	var w := maxf(L.W * 1.04, L.fgH * ar)
	var h := w / ar
	return Rect2((L.W - w) / 2, L.H - h + 2, w, h)

func _fg_build() -> void:
	if _gan.is_empty():
		var j = JSON.parse_string(FileAccess.get_file_as_string(GAN + "gan.json"))
		if typeof(j) != TYPE_DICTIONARY:
			return
		_gan = j
	var K: float = game.K
	var r := _fg_geom()
	var pw := int(round(r.size.x * K))
	var ph := int(round(r.size.y * K)) + 4
	var key := "%d_%d" % [pw, ph]
	if key == _fg_key:
		return
	_fg_key = key
	var s: float = float(pw) / float(_gan.W)        # điểm ảnh máy / đơn vị khung
	var v := SubViewport.new()
	v.size = Vector2i(pw, ph)
	v.transparent_bg = true
	v.disable_3d = true
	v.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(v)
	var root := Node2D.new()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	v.add_child(root)
	var gi := _gan_img("n2_co")
	var gt: Texture2D = null
	if gi:
		gi.generate_mipmaps()
		gt = ImageTexture.create_from_image(gi)
	var gnd := Node2D.new()
	gnd.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	gnd.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	gnd.draw.connect(_draw_gan_ground.bind(gnd, s, float(ph), gt))
	root.add_child(gnd)
	var cache := {}
	var items: Dictionary = _gan.items
	for p in _gan.place:
		var it: Dictionary = items[p[0]]
		var sc: float = absf(float(p[3])) * s
		var w := maxi(1, int(round(float(it.w) * sc)))
		var h := maxi(1, int(round(float(it.h) * sc)))
		var fl: bool = float(p[3]) < 0
		var ck := "%s_%d_%d_%d" % [p[0], w, h, int(fl)]
		if not cache.has(ck):
			var im := _gan_img(p[0])
			if im == null:
				continue
			im.resize(w, h, Image.INTERPOLATE_LANCZOS)
			if fl:
				im.flip_x()
			cache[ck] = ImageTexture.create_from_image(im)
		var ax: float = float(it.ax) * sc
		if fl:
			ax = w - ax
		var sp := Sprite2D.new()
		sp.texture = cache[ck]
		sp.centered = false
		sp.position = Vector2(round(float(p[1]) * s - ax), round(float(p[2]) * s - float(it.ay) * sc))
		root.add_child(sp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if key != _fg_key:
		v.queue_free()
		return
	var out: Image = v.get_texture().get_image()
	v.queue_free()
	out.generate_mipmaps()
	_fg_tex = ImageTexture.create_from_image(out)
	_fg_rect = Rect2(r.position, Vector2(r.size.x, float(ph) / K))
	l_fg.queue_redraw()

func _draw_gan_ground(n: Node2D, s: float, ph: float, gt: Texture2D) -> void:
	var E: Array = _gan.edge
	var dx: float = float(_gan.edx)
	var tile := 260.0 * s                       # 1 ô ảnh cỏ = 260 đơn vị khung
	var top := Color(1.56, 1.62, 1.7); var bot := Color(1.1, 1.18, 1.2)
	var sh := Color(.62, .7, .55)                # vệt tối sát mép (bóng mép bờ trên nước)
	for i in E.size() - 1:
		var x0 := i * dx * s; var x1 := (i + 1) * dx * s
		var y0: float = float(E[i]) * s; var y1: float = float(E[i + 1]) * s
		var P := PackedVector2Array([Vector2(x0, y0), Vector2(x1, y1), Vector2(x1, ph), Vector2(x0, ph)])
		var UV := PackedVector2Array([P[0] / tile, P[1] / tile, P[2] / tile, P[3] / tile])
		n.draw_polygon(P, PackedColorArray([top, top, bot, bot]), UV, gt)
		var e := 5.0 * s
		var Q := PackedVector2Array([Vector2(x0, y0 - 1), Vector2(x1, y1 - 1), Vector2(x1, y1 + e), Vector2(x0, y0 + e)])
		n.draw_polygon(Q, PackedColorArray([sh, sh, Color(sh, 0), Color(sh, 0)]), UV, gt)

func draw_fg(ci: CanvasItem) -> void:
	if _fg_tex == null or dbg_skip.has("fg"):
		return
	var tc: Color = (game.tod.tint as Color).lerp(Color.BLACK, .12)
	ci.draw_texture_rect(_fg_tex, _fg_rect, false, Color(tc.r, tc.g, tc.b, 1))

# cây bờ bên này: bông giấy tím trái; phải = bông giấy đỏ (màn ngang) / bụi vạn thọ thấp cạnh cột nút (màn dọc)
func draw_near_trees(ci: CanvasItem, tod: Dictionary) -> void:
	var L: Dictionary = game.L
	var tc: Color = (tod.tint as Color).lerp(Color.BLACK, .12)
	var T: float = game.W.t
	var list: Array = BG_NEAR.duplicate()
	if L.portrait:
		list.pop_back()
		for i in 3:
			var nm := "gan/h_van_tho_dh_van_tho%d" % i
			var it = _gan.get("items", {}).get("h_van_tho_dh_van_tho%d" % i)
			if it != null:
				list.append([nm, .69 + i * .055, float(it.ax) / float(it.w), float(it.ay) / float(it.h), i * 1.7, .78 - (i % 2) * .12, i == 1])
	for q in list:
		var bt: Texture2D = A.img(q[0])
		if bt == null:
			continue
		var bh: float = L.fgH * (float(q[5]) if q.size() > 5 else 1.55)
		var bw: float = bh * bt.get_size().x / bt.get_size().y
		var foot := Vector2(L.W * float(q[1]), L.H - L.fgH * .5)
		var ang := sin(T * 1.1 + float(q[4])) * .017
		ci.draw_set_transform(foot, ang, Vector2(-1 if (q.size() > 6 and q[6]) else 1, 1))
		ci.draw_texture_rect(bt, Rect2(-float(q[2]) * bw, -float(q[3]) * bh, bw, bh), false, Color(tc.r, tc.g, tc.b, 1))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# ------------------------------------------------------------ chuồn chuồn
func draw_dragonfly(ci: CanvasItem, tod: Dictionary) -> void:
	var d = game.G.df
	if d == null:
		return
	var fl: float = (sin(d.ph) if sin(d.t * 2) > .7 else .2) if d.mode == "sit" else sin(d.ph)
	var rot := 0.0 if d.mode == "sit" else sin(d.t * 4) * .2
	ci.draw_set_transform_matrix(Transform2D(rot, Vector2(.9, .9), 0, Vector2(d.x, d.y)))
	var c := Color(.85, .25, .12).lerp(tod.tint, .4)
	for q in [[-1, 1], [-1, -1], [2, 1], [2, -1]]:
		var ox: float = q[0]
		var sy: float = q[1]
		var e := A.ell_pts(Vector2(ox, -1.5 * sy * (1 + fl * .4) - sy * 3), 2.2, 8, 16, -.4 * sy if ox < 0 else .4 * sy)
		ci.draw_colored_polygon(e, Color(230 / 255.0, 240 / 255.0, 1, .45))
		e.append(e[0])
		ci.draw_polyline(e, Color(80 / 255.0, 90 / 255.0, 110 / 255.0, .5), .6, true)
	A.stroke(ci, PackedVector2Array([Vector2(-4, 0), Vector2(-17, 1)]), c, 2.2)
	A.ell(ci, Vector2.ZERO, 4, 2.4, c)
	ci.draw_circle(Vector2(4.5, -.3), 2.2, c)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# ------------------------------------------------------------ cá bay vô người câu
func draw_landing(ci: CanvasItem) -> void:
	var G: Dictionary = game.G
	var L: Dictionary = game.L
	if G.state != "land" or G.landing == null:
		return
	var l: Dictionary = G.landing
	var h: Dictionary = l.h
	var u := clampf(l.t / .75, 0, 1)
	var e := 1 - pow(1 - u, 3)
	var s: Vector2 = game.proj(h.x, L.zEdge + .4)
	var t: Texture2D = A.img(h.f.id)
	if t == null:
		return
	var w0: float = L.F * h.f.vis * h.size / (L.zEdge + .4) * 1.2
	var w1 := minf(L.W * .7, 460)
	var w := lerpf(w0, w1, e)
	var hh := w * t.get_size().y / t.get_size().x
	var x := lerpf(s.x, L.W / 2, e)
	var y: float = lerpf(s.y, L.H * .5, e) - sin(u * PI) * L.H * .12
	ci.draw_set_transform_matrix(Transform2D(sin(l.t * 11) * .12 * (1 - u), Vector2(x, y)))
	draw_bent(ci, t, w, hh, l.t * 26, .12 * (1 - u * .6), Color(1, 1, 1, 1 - D.smooth(.85, 1, u) * .9))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# ============================================================ lớp cộng sáng: đom đóm + đầu phao đèn
func _draw_add(ci: CanvasItem) -> void:
	for f in game.W.flies:
		var a: float = .5 + .5 * sin(f.ph * 3.1 + f.x * .01)
		if a < .15:
			continue
		A.radial(ci, Vector2(f.x, f.y), 9, [[0.0, Color(230 / 255.0, 1, 140 / 255.0, a)], [.3, Color(180 / 255.0, 1, 90 / 255.0, a * .35)], [1.0, Color(120 / 255.0, 200 / 255.0, 60 / 255.0, 0)]], 14)
	for g in _glows:
		A.radial(ci, g[0], g[1], [[0.0, Color(210 / 255.0, 1, 120 / 255.0, g[2])], [1.0, Color(120 / 255.0, 200 / 255.0, 60 / 255.0, 0)]], 18)

# ============================================================ mưa
func _draw_rain(ci: CanvasItem) -> void:
	var L: Dictionary = game.L
	var W: Dictionary = game.W
	var rd: Array = game.FX.rain
	if rd.size():
		var pts := PackedVector2Array()
		for d in rd:
			pts.append(Vector2(d.x, d.y))
			pts.append(Vector2(d.x + d.l * .12, d.y - d.l))
		ci.draw_multiline(pts, Color(220 / 255.0, 230 / 255.0, 240 / 255.0, .35), 1)
	if W.rain > .05:
		ci.draw_rect(Rect2(0, 0, L.W, L.H), Color(60 / 255.0, 70 / 255.0, 80 / 255.0, W.rain * .18))
