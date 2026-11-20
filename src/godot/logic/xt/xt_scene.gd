extends Control
# XẾP TRÁI: cảnh miệt vườn phía sau (04_scene.js): trời có mây trôi, cò bay, sông soi bóng bờ bên kia, xuồng chở trái,
# bờ xa, bờ mình, cây khung hai bên đung đưa; và bốn con thú đứng trên bờ (trâu, heo, gà trống, vịt) reo khi phụ.

const A := preload("res://logic/xt/xt_art.gd")
const D := preload("res://logic/xt/xt_data.gd")

const COMMON := """
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<5;i++){v+=a*n(p);p=p*2.02+3.7;a*=.5;}return v;}
"""
const SKY := """
shader_type canvas_item;
uniform vec4 uK; uniform vec4 rc; uniform float uT;
COMMON
void fragment(){vec2 p=rc.xy+UV*rc.zw;float hz=uK.x,s=uK.w;float y=clamp(p.y/hz,0.,1.);
  vec3 top=vec3(.36,.68,.86),mid=vec3(.62,.83,.9),low=vec3(.99,.92,.78);
  vec3 c=mix(top,mid,smoothstep(0.,.6,y));c=mix(c,low,smoothstep(.55,1.,y));
  float d=length((p-uK.yz)/s);c+=vec3(1.,.93,.75)*(exp(-d*d*2.2)*.25+exp(-d*d*.25)*.12);
  c=mix(c,vec3(1.,.98,.9),smoothstep(.16,.13,d));
  vec2 q=vec2(p.x/s*1.4+uT*.012,p.y/s*3.2);float band=smoothstep(.0,.25,y)*(1.-smoothstep(.62,.9,y));
  float cl=fbm(q*1.2+vec2(0.,uT*.004))*band;float cl2=fbm(q*1.2+vec2(.02,-.06)+vec2(0.,uT*.004))*band;
  float m=smoothstep(.42,.47,cl);vec3 cc=mix(vec3(.86,.86,.9),vec3(1.,.99,.95),smoothstep(.0,.08,cl-cl2+.03));
  c=mix(c,cc,m*.92);COLOR=vec4(c,1.);}
"""
const WATER := """
shader_type canvas_item;
uniform vec4 uK; uniform vec4 rc; uniform float uT;
uniform sampler2D uFar : repeat_enable, filter_linear_mipmap;
COMMON
void fragment(){vec2 p=rc.xy+UV*rc.zw;float top=uK.x,bot=uK.y,ft=uK.z,fw=uK.w;
  float k=(p.y-top)/(bot-top);
  vec3 deep=vec3(.33,.58,.56),shal=vec3(.72,.86,.82);vec3 c=mix(shal,deep,smoothstep(0.,1.,k));
  float wob=sin(p.y*.35-uT*1.6)*1.6+(n(vec2(p.x*.02,p.y*.15-uT*.6))-.5)*6.*(.3+k);
  float ry=top-(p.y-top)*1.15+wob*.3;float fh=top-ft;
  vec2 uv=vec2((p.x+wob)/fw,(ry-ft)/fh);vec4 r=texture(uFar,vec2(fract(uv.x),clamp(uv.y,0.,1.)));
  c=mix(c,mix(r.rgb*.82,deep,.25),r.a*(.72-k*.35)*step(0.,uv.y));
  float gl=n(vec2(p.x*.05+uT*.15,p.y*.6))*n(vec2(p.x*.013-uT*.05,p.y*.9));c+=vec3(1.,.98,.9)*smoothstep(.55,.75,gl)*.55;
  c=mix(c,vec3(.95,.97,.92),smoothstep(3.,0.,p.y-top)*.6);
  COLOR=vec4(c,1.);}
"""
# hình có phủ sương (uK.rgb, uK.a) và đung đưa phần trên (sway px)
const TEX := """
shader_type canvas_item;
render_mode blend_mix;
uniform vec4 uK; uniform float sway; uniform float ph; uniform float alpha = 1.0;
void vertex(){
  if(sway>0.){float fx=UV.x,fy=UV.y,k=pow(1.-fy,2.)*sway;
    VERTEX.x+=k*(sin((TIME+ph)*1.3+fx*2.2)*.6+sin((TIME+ph)*2.7+fy*3.)*.25);}
}
void fragment(){vec4 t=texture(TEXTURE,UV)*COLOR;t.rgb=mix(t.rgb,uK.rgb,uK.a);t.a*=alpha;COLOR=t;}
"""

class Lay extends Control:
	var fn: Callable
	func _init(f: Callable = Callable()) -> void:
		fn = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)

var game
var sky: ColorRect
var water: ColorRect
var eg_l: Lay
var boat_l: Lay
var far_l: Lay
var near_l: Lay
var frl: Lay
var frr: Lay
var _sky_m: ShaderMaterial
var _wat_m: ShaderMaterial
var egrets: Array = []
var boat := {}
var helpers: Array = []
var horizon := 0.0
var bank := 0.0
var GEO := {}

func _init(gm) -> void:
	game = gm
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func _mat(code: String) -> ShaderMaterial:
	var s := Shader.new()
	s.code = code.replace("COMMON", COMMON)
	var m := ShaderMaterial.new()
	m.shader = s
	return m

func _ready() -> void:
	sky = ColorRect.new()
	_sky_m = _mat(SKY)
	sky.material = _sky_m
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	eg_l = Lay.new(_draw_egrets)
	var em := _mat(TEX)
	em.set_shader_parameter("uK", Vector4(0.8, 0.88, 0.86, 0.15))
	eg_l.material = em
	add_child(eg_l)
	water = ColorRect.new()
	_wat_m = _mat(WATER)
	_wat_m.set_shader_parameter("uFar", A.img("bg_far"))
	water.material = _wat_m
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(water)
	boat_l = Lay.new(_draw_boat)
	add_child(boat_l)
	far_l = Lay.new(_draw_far)
	far_l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(far_l)
	near_l = Lay.new(_draw_near)
	near_l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(near_l)
	for side in ["L", "R"]:
		var l := Lay.new(_draw_frame.bind(side))
		var m := _mat(TEX)
		m.set_shader_parameter("uK", Vector4(0.1, 0.22, 0.12, 0.12))
		m.set_shader_parameter("ph", 2.0 if side == "R" else 0.0)
		l.material = m
		l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(l)
		if side == "L":
			frl = l
		else:
			frr = l

func geo() -> Dictionary:
	var L: Dictionary = game.LAY
	var W: float = L.W
	var H: float = L.H
	var hz := horizon
	var farH := clampf(H * (0.2 if L.portrait else 0.24), 110, 260)
	var farW := farH * 4
	var nearTop := bank
	var nearH0: float = (L.pathY - bank) / 0.15
	var nearH := maxf(nearH0, (H - bank) * 1.02)
	var nearW := maxf(W, nearH * 2)
	var frH: float = minf(H * 0.42, W * 0.95) if L.portrait else minf(H * 0.95, W * 0.5)
	var frW := frH * (1024.0 / 1536.0)
	return {"W": W, "H": H, "hz": hz, "farH": farH, "farW": farW, "farTop": hz - farH, "nearTop": nearTop - nearH * 0.05, "nearH": nearH, "nearW": nearW, "nearX": (W - nearW) / 2, "frH": frH, "frW": frW}

func resize() -> void:
	var L: Dictionary = game.LAY
	GEO = geo()
	var G0 := GEO
	var W: float = L.W
	var S := minf(W, L.H)
	sky.position = Vector2.ZERO
	sky.size = Vector2(W, G0.hz + 2)
	_sky_m.set_shader_parameter("rc", Vector4(0, 0, W, G0.hz + 2))
	_sky_m.set_shader_parameter("uK", Vector4(G0.hz, W * 0.76, G0.hz * 0.34, S))
	water.position = Vector2(0, G0.hz - 1)
	water.size = Vector2(W, bank - G0.hz + 30)
	_wat_m.set_shader_parameter("rc", Vector4(0, G0.hz - 1, W, bank - G0.hz + 30))
	_wat_m.set_shader_parameter("uK", Vector4(G0.hz, bank + 20, G0.farTop, G0.farW))
	for l in [eg_l, boat_l, far_l, near_l, frl, frr]:
		l.position = Vector2.ZERO
		l.size = Vector2(W, L.H)
	frl.material.set_shader_parameter("sway", G0.frW * 0.03)
	frr.material.set_shader_parameter("sway", G0.frW * 0.03)
	for l in [far_l, near_l, frl, frr]:
		l.queue_redraw()
	place_helpers()
	var R := D.SRand.new(3)
	egrets = []
	for i in 3:
		var e := {"x": R.r() * W, "y": horizon * (0.25 + R.r() * 0.45), "v": (18 + R.r() * 16) * (-1.0 if R.r() < 0.5 else 1.0), "ph": R.r() * 6, "s": clampf(L.H * 0.035, 18, 34)}
		egrets.append(e)
	boat = {"x": W * 0.2, "v": 11.0}

func place_helpers() -> void:
	var L: Dictionary = game.LAY
	var names := ["trau", "heo", "trong", "vit"]
	var W: float = L.W
	var y: float = L.pathY
	var xs := []
	if L.portrait:
		var span := minf(W * 0.9, 560)
		for i in 4:
			xs.append(W / 2 - span / 2 + span * (i + 0.5) / 4)
	else:
		var Lx: float = L.bx + L.bw + 20
		var Rr: float = W - 16
		for i in 4:
			xs.append(Lx + (Rr - Lx) * (i + 0.5) / 4 if Rr - Lx > 200 else L.col * 0.12 + i * L.col * 0.25)
	var old := helpers
	helpers = []
	for i in 4:
		var h := {"n": names[i], "x": xs[i], "y": y, "jump": 0.0, "ph": i * 1.3, "flip": (i >= 2) if L.portrait else true, "cheer": 0.0}
		if i < old.size():
			h.jump = old[i].jump
		helpers.append(h)

func cheer(n: String) -> void:
	for h in helpers:
		if h.n == n and h.jump <= 0:
			h.jump = 1.0
			h.cheer = 1.6

func update(dt: float) -> void:
	var W: float = game.LAY.W
	for e in egrets:
		e.x += e.v * dt
		if e.x > W + 60:
			e.x = -60.0
		if e.x < -60:
			e.x = W + 60
	if boat.size():
		boat.x += boat.v * dt
		if boat.x > W + 90:
			boat.x = -90.0
	for h in helpers:
		if h.jump > 0:
			h.jump = maxf(0.0, h.jump - dt * 1.8)
		if h.cheer > 0:
			h.cheer -= dt
	var t: float = game.clock
	_sky_m.set_shader_parameter("uT", t)
	_wat_m.set_shader_parameter("uT", t)
	eg_l.queue_redraw()
	boat_l.queue_redraw()

func _draw_egrets(ci: CanvasItem) -> void:
	var t: float = game.clock
	for e in egrets:
		var f := "bg_egret0" if sin(t * 7 + e.ph) > 0 else "bg_egret1"
		var flip: bool = e.v < 0
		var w: float = e.s * 1.5
		var y: float = e.y + sin(t * 1.2 + e.ph) * 4
		if flip:
			ci.draw_set_transform(Vector2(e.x + w, y), 0, Vector2(-1, 1))
			ci.draw_texture_rect(A.img(f), Rect2(0, 0, w, e.s), false)
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			ci.draw_texture_rect(A.img(f), Rect2(e.x, y, w, e.s), false)

func _draw_boat(ci: CanvasItem) -> void:
	if boat.is_empty():
		return
	var G0 := GEO
	var L: Dictionary = game.LAY
	var t: float = game.clock
	var S := minf(L.W, L.H)
	var bw := clampf(S * 0.16, 60, 130)
	var bh := bw * 160 / 256
	var by: float = G0.hz + (bank - G0.hz) * 0.55
	var tex := A.img("bg_boat")
	# bóng dưới nước: lật dọc, mờ
	ci.draw_set_transform(Vector2(boat.x - bw / 2, by + bh * 0.4), 0, Vector2(1, -1))
	ci.draw_texture_rect(tex, Rect2(0, 0, bw, bh * 0.7), false, Color(1, 1, 1, 0.28))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	ci.draw_texture_rect(tex, Rect2(boat.x - bw / 2, by - bh * 0.72 + sin(t * 1.6) * 1.5, bw, bh), false)

func _draw_far(ci: CanvasItem) -> void:
	var G0 := GEO
	if G0.is_empty():
		return
	var tex := A.img("bg_far")
	var W: float = G0.W
	# lặp ngang bằng nhiều tấm (không bật repeat: repeat dọc làm hiện vạch ở mép trên)
	var fw: float = G0.farW
	var x := 0.0
	while x < W:
		var w := minf(fw, W - x)
		ci.draw_texture_rect_region(tex, Rect2(x, G0.farTop, w, G0.farH), Rect2(0, 0, w / fw * tex.get_width(), tex.get_height()))
		x += fw

func _draw_near(ci: CanvasItem) -> void:
	var G0 := GEO
	if G0.is_empty():
		return
	ci.draw_texture_rect(A.img("bg_near"), Rect2(G0.nearX, G0.nearTop, G0.nearW, G0.nearH), false)

func _draw_frame(ci: CanvasItem, side: String) -> void:
	var G0 := GEO
	if G0.is_empty():
		return
	var tex := A.img("bg_frame" + side)
	var x: float = -G0.frW * 0.18 if side == "L" else G0.W - G0.frW * 0.82
	var y: float = G0.H - G0.frH
	# lưới 6x6 cho phần trên đung đưa
	var N := 6
	for j in N:
		for i in N:
			var u0 := float(i) / N
			var u1 := float(i + 1) / N
			var v0 := float(j) / N
			var v1 := float(j + 1) / N
			var pts := PackedVector2Array([Vector2(x + u0 * G0.frW, y + v0 * G0.frH), Vector2(x + u1 * G0.frW, y + v0 * G0.frH), Vector2(x + u1 * G0.frW, y + v1 * G0.frH), Vector2(x + u0 * G0.frW, y + v1 * G0.frH)])
			var uvs := PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])
			ci.draw_polygon(pts, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, tex)

# thú trên bờ (vẽ trong lớp bàn, dưới bàn)
func draw_helpers(ci: CanvasItem) -> void:
	var L: Dictionary = game.LAY
	var t: float = game.clock
	var hh: float = clampf((L.pathY - bank) * 0.7, 38, 70) if L.portrait else clampf(L.H * 0.1, 48, 80)
	for h in helpers:
		var j: float = sin(h.jump * PI) * hh * 0.55 if h.jump > 0 else 0.0
		A.ell(ci, Vector2(h.x, h.y), hh * 0.42 * (1 - j / hh * 0.4), hh * 0.1, Color(50 / 255.0, 40 / 255.0, 20 / 255.0, 0.3))
		var fr := int(floor(t * 6 + h.ph * 3))
		var sz: float = {"trau": 1.2, "heo": 1.0, "trong": 1.05, "vit": 0.82}[h.n]
		A.anim(ci, h.n, "idle", "6", fr, h.x, h.y - j, hh * sz, h.flip)
		if h.cheer > 0:
			var a := clampf(h.cheer, 0, 1)
			var fs: float = round(clampf(hh * 0.24, 13, 18))
			var word: String = D.CHEER_WORD[h.n]
			var tw := A.tw(word, fs, 800) + 16
			var by := maxf(fs, h.y - hh * sz - j - fs * 0.6)
			var r := Rect2(h.x - tw / 2, by - fs * 0.75, tw, fs * 1.45)
			A.box(ci, r.grow(1), Color(0.169, 0.129, 0.094, a), fs * 0.72 + 1)
			A.box(ci, r.grow(-1), Color(1, 0.973, 0.902, a), fs * 0.72 - 1)
			A.text(ci, word, h.x, by, fs, Color(0.169, 0.129, 0.094, a))
