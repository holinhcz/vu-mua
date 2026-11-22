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
	func _init(f: Callable) -> void:
		fn = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		fn.call(self)

var game
var l_refl: Lay
var l_main: Lay
var l_add: Lay
var l_rain: Lay
var refl_mat: ShaderMaterial
var _glows: Array = []

func _init(gm) -> void:
	game = gm
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	l_refl = Lay.new(_draw_refl)
	var sh := Shader.new()
	sh.code = REFL_SH
	refl_mat = ShaderMaterial.new()
	refl_mat.shader = sh
	l_refl.material = refl_mat
	add_child(l_refl)
	l_main = Lay.new(_draw_main)
	add_child(l_main)
	l_add = Lay.new(_draw_add)
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	l_add.material = am
	add_child(l_add)
	l_rain = Lay.new(_draw_rain)
	add_child(l_rain)
	for l in [l_refl, l_main, l_add, l_rain]:
		l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func resize() -> void:
	var L: Dictionary = game.L
	for l in [l_refl, l_main, l_add, l_rain]:
		l.position = Vector2.ZERO
		l.size = Vector2(L.W, L.H)

func redraw() -> void:
	var tod: Dictionary = game.tod
	var tc: Color = tod.tint
	var wc: Color = (tod.water as Color).lerp(Color.BLACK, .2)
	refl_mat.set_shader_parameter("tint", Vector3(tc.r, tc.g, tc.b))
	refl_mat.set_shader_parameter("mixc", Vector3(wc.r, wc.g, wc.b))
	for l in [l_refl, l_main, l_add, l_rain]:
		l.queue_redraw()

static func lit_of(tod: Dictionary, k: float) -> Color:
	return Color.WHITE.lerp(tod.tint, k)

static func mulc(c: Color, l: Color, a := 1.0) -> Color:
	return Color(c.r * l.r, c.g * l.g, c.b * l.b, a)

# ============================================================ bóng phản chiếu của đồ nổi (lớp có shader)
func _draw_refl(ci: CanvasItem) -> void:
	var W: Dictionary = game.W
	for p in W.props:
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
func _draw_main(ci: CanvasItem) -> void:
	var tod: Dictionary = game.tod
	var W: Dictionary = game.W
	_glows = []
	for b in W.birds:
		draw_bird(ci, b, tod)
	for p in W.props:
		draw_floating(ci, "lucbinh" + str(p.k), p.x, p.z, .6 * p.s, sin(W.t * 1.3 + p.ph) * .6, tod, .9)
	if W.boat != null:
		draw_boat(ci, W.boat, tod)
	fx_draw(ci, tod)
	draw_leaps(ci)
	if game.started:
		draw_tackle(ci, tod)
	draw_dragonfly(ci, tod)
	draw_fg(ci, tod)
	if game.started:
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
			"foam":
				var r: float = (10 + t * 18) * k * p.s
				A.ell(ci, s, r, r * .22, Color(lit, .25 * (1 - t)))

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

func line_color(tod: Dictionary, a := .6) -> Color:
	return Color(Color(.95, .95, .9).lerp(tod.tint, .35), a)

func draw_line_q(ci: CanvasItem, p0: Vector2, p1: Vector2, sag: float, tod: Dictionary, a: float) -> void:
	ci.draw_polyline(A.quad_pts(p0, Vector2((p0.x + p1.x) / 2, maxf(p0.y, p1.y) + sag), p1, 16), line_color(tod, a), 1, true)

const BANDS0 := ["#f2efe6", "#2a2a2a", "#f2efe6", "#e8402a", "#ff6a2a"]
const BANDS1 := ["#2a7a5a", "#e8e0c8", "#2a4aa0", "#e84a2a", "#f8d040"]

# hình phao ở (x,y) = điểm mặt nước, h = phần nổi; chìm sink, nghiêng tilt. Phần dưới nước mờ .22 (cắt theo mặt nước)
func draw_float_shape(ci: CanvasItem, x: float, y: float, h: float, sink: float, tilt: float, tod: Dictionary, flying: bool) -> void:
	var kind: int = game.S.flo
	var w := maxf(3, h * .15) * (1.3 if kind == 1 else 1.0)
	var night: float = tod.night
	var xf := Transform2D(tilt, Vector2(x, y + sink * h))
	var bands: Array = BANDS1 if kind == 1 else BANDS0
	var n := bands.size()
	var shapes := []   # [poly local, colour]
	for i in n:
		var y0 := -h * i / n
		var y1 := -h * (i + 1) / n
		shapes.append([_rect_pts(-w / 2, y1, w, y0 - y1 + .5), dim(Color(bands[i]), tod)])
	shapes.append([_rect_pts(-w / 2, -h, w * .3, h), Color(1, 1, 1, .4)])
	var outline := _rect_pts(-w / 2, -h, w, h)
	if kind == 2:
		shapes.append([A.ell_pts(Vector2(0, -h), w * .9, w * 1.6, 16), Color("#d8ff7a") if night > .3 else dim(Color("#9adc4a"), tod)])
	var body := A.quad_pts(Vector2(0, h * .05), Vector2(w * 2.4, h * .45), Vector2(0, h * .95), 8)
	var b2 := A.quad_pts(Vector2(0, h * .95), Vector2(-w * 2.4, h * .45), Vector2(0, h * .05), 8)
	for i in range(1, b2.size() - 1):
		body.append(b2[i])
	var ow := maxf(1, w * .22)
	var oc := Color(30 / 255.0, 20 / 255.0, 12 / 255.0, .85)
	if flying:
		ci.draw_set_transform_matrix(xf)
		for sp in shapes:
			ci.draw_colored_polygon(sp[0], sp[1])
		var oc2 := outline.duplicate()
		oc2.append(outline[0])
		ci.draw_polyline(oc2, oc, ow, true)
		var bs := PackedVector2Array()
		for p in body:
			bs.append(Vector2(p.x * .45, p.y * .5))
		ci.draw_colored_polygon(bs, dim(Color("#c8b080"), tod))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	var up := _rect_pts(x - h * 2, y - h * 3, h * 4, h * 3)
	var dn := _rect_pts(x - h * 2, y, h * 4, h * 3)
	for half in [[up, 1.0, dim(Color("#c8b080"), tod)], [dn, .22, Color("#c8b080")]]:
		var al: float = half[1]
		for sp in shapes:
			_clip_fill(ci, xf * (sp[0] as PackedVector2Array), half[0], Color(sp[1], (sp[1] as Color).a * al))
		_clip_fill(ci, xf * body, half[0], Color(half[2], al))
		var ol := xf * outline
		ol.append(ol[0])
		for seg in Geometry2D.intersect_polyline_with_polygon(ol, half[0]):
			ci.draw_polyline(seg, Color(oc, oc.a * al), ow, true)
	if sink < 1.1:
		var m := A.ell_pts(Vector2(x, y), w * 2.2, w * .7, 20)
		m.append(m[0])
		ci.draw_polyline(m, Color(Color.WHITE.lerp(tod.tint, .4), .55), 1, true)
	if kind == 2 and night > .2 and sink < 1.2:
		_glows.append([Vector2(x + sin(tilt) * h, y + sink * h - cos(tilt) * h), h * .9, .8 * night])

static func _rect_pts(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])

static func _clip_fill(ci: CanvasItem, poly: PackedVector2Array, clip: PackedVector2Array, col: Color) -> void:
	for p in Geometry2D.intersect_polygons(poly, clip):
		if p.size() >= 3 and not Geometry2D.triangulate_polygon(p).is_empty():
			ci.draw_colored_polygon(p, col)

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
	ci.draw_polyline(e1, Color(fc, .7 * h.surf), maxf(1, w * .02), true)
	var e2 := A.ell_pts(Vector2(cx - dir * w * .2, wy + 1), w * .8, w * .1, 24)
	e2.append(e2[0])
	ci.draw_polyline(e2, Color(fc, .35 * h.surf), maxf(1, w * .02), true)
	if randf() < G.dt * 8 * h.surf:
		game.ripple(G.fl.x - dir * .3, G.fl.z, .35)
		game.fx_splash(G.fl.x - dir * .2, G.fl.z, .25)

func draw_tackle(ci: CanvasItem, tod: Dictionary) -> void:
	var G: Dictionary = game.G
	var L: Dictionary = game.L
	var T: float = game.W.t
	var tip: Vector2 = game.rod_tip_pos()
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
		ci.draw_polyline(pts, line_color(tod, .5 * (1 - u)), 1, true)
		return
	if st == "fight":
		var f: Vector2 = game.proj(G.fl.x, G.fl.z)
		draw_surfacing(ci, f.x, f.y, tod)
		var sag := maxf(0, 1 - G.ten * 1.4) * 40
		draw_line_q(ci, tip, f, sag, tod, .75)
		var k: float = L.F / G.fl.z / 60
		var d := -1.0 if G.hook.vx >= 0 else 1.0
		ci.draw_polyline(PackedVector2Array([Vector2(f.x + d * 18 * k, f.y - 3 * k), f, Vector2(f.x + d * 18 * k, f.y + 3 * k)]), Color(Color.WHITE.lerp(tod.tint, .4), .5), 1.2, true)
		return
	var b: Vector2 = game.float_base()
	var h: float = game.float_h(G.fl.z)
	var tilt: float = G.fl.tilt * 1.35 * (1.0 if G.fl.x >= 0 else -1.0)
	var a := Vector2(b.x + sin(tilt) * h, b.y + G.fl.sink * h - cos(tilt) * h)
	draw_line_q(ci, tip, a, 26 + sin(T) * 3, tod, .55)
	draw_float_shape(ci, b.x, b.y, h, G.fl.sink, tilt, tod, false)

# ------------------------------------------------------------ cần trúc
func draw_rod(ci: CanvasItem, tod: Dictionary) -> void:
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
	var k: float = L.H / 900.0 * (.9 if L.portrait else 1.0)
	var lit: Color = Color.WHITE.lerp(tod.tint, .7)
	var N := 30
	var P := []
	for i in N + 1:
		var tt := float(i) / N
		var u := 1 - tt
		P.append([b * u * u + c * 2 * u * tt + t * tt * tt, lerpf(16, 3, pow(tt, .8)) * k, tt])
	var shc := func(r: float, g: float, bl: float) -> Color: return Color(r * lit.r, g * lit.g, bl * lit.b)
	var pass_ := func(m: float, a: float, col, from: int) -> void:
		for i in range(maxi(1, from), N + 1):
			var cc: Color = col.call(P[i][2]) if col is Callable else col
			var wd: float = P[i][1] * m + a
			ci.draw_line(P[i - 1][0], P[i][0], cc, wd, true)
			ci.draw_circle(P[i][0], wd * .5, cc)
	pass_.call(1.0, 4 * k + 1.5, shc.call(.16, .1, .05), 0)
	var c_dark: Color = shc.call(.42, .24, .12)
	var c_light: Color = shc.call(.86, .72, .38)
	pass_.call(1.0, 0.0, func(tt): return c_dark if tt < .18 else c_light, 0)
	pass_.call(.28, 0.0, shc.call(1, .94, .7), 7)
	var nc: Color = shc.call(.4, .28, .1)
	var i2 := 8
	while i2 < N:
		var p: Vector2 = P[i2][0]
		var p2: Vector2 = P[i2 + 1][0]
		var wd: float = P[i2][1]
		var dv := p2 - p
		var dd := dv.length()
		if dd == 0:
			dd = 1
		var nrm := Vector2(-dv.y, dv.x) / dd * wd * .55
		ci.draw_line(p - nrm, p + nrm, nc, maxf(1.2, 2.2 * k), true)
		i2 += 4
	# ống cước gỗ gần cán, quay khi kéo
	var tt := .2
	var u := 1 - tt
	var rp := b * u * u + c * 2 * u * tt + t * tt * tt
	var R := 17 * k
	var rc := rp + Vector2(-R * .4, -R * .9)
	ci.draw_circle(rc, R, Color(.45, .3, .16).lerp(tod.tint, .4))
	var rim := Color(.25, .16, .08).lerp(tod.tint, .4)
	ci.draw_arc(rc, R, 0, TAU, 32, rim, 2.5 * k, true)
	var hold_run: bool = G.state == "fight" and not G.hold and G.hook != null and G.hook.beh == "run"
	G.reelA += (.35 if G.hold and G.state == "fight" else 0.0) - (.2 if hold_run else 0.0)
	for i in 4:
		var a: float = G.reelA + i * PI / 2
		ci.draw_line(rc, rc + Vector2(cos(a), sin(a)) * R * .85, rim, 2.5 * k, true)
	ci.draw_circle(rc + Vector2(cos(G.reelA), sin(G.reelA)) * R * .7, 3 * k, Color(.85, .75, .5).lerp(tod.tint, .4))
	ci.draw_circle(t, 2.4 * k, Color(.9 * lit.r, .3 * lit.g, .2 * lit.b))

# ------------------------------------------------------------ bờ bên này
func draw_fg(ci: CanvasItem, tod: Dictionary) -> void:
	var L: Dictionary = game.L
	var t: Texture2D = A.img("fg")
	if t == null:
		return
	var ar := t.get_size().x / t.get_size().y
	var w := maxf(L.W * 1.04, L.fgH * ar)
	var h := w / ar
	var tc: Color = (tod.tint as Color).lerp(Color.BLACK, .12)
	ci.draw_texture_rect(t, Rect2((L.W - w) / 2, L.H - h + 2, w, h), false, Color(tc.r, tc.g, tc.b, 1))

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
