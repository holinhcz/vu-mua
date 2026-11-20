extends Control
# XẾP TRÁI: hạt hiệu ứng trên GPU (05_fxgl.js): một shader hạt, hai lớp (mềm: nước trái, bụi, rơm, lá, lông, giấy;
# sáng: lấp lánh, vòng, quầng), và sóng bẻ cong mặt bàn (warp). Mỗi hạt một instance của MultiMesh.

const SH := {"glow": 0, "ring": 1, "star": 2, "drop": 3, "puff": 4, "streak": 5, "shock": 6, "leaf": 7, "feather": 8, "paper": 9, "splat": 10, "wave": 11}
const CAP := 3000

const PART_SHADER := """
shader_type canvas_item;
render_mode MODE;
varying vec2 vU;
varying vec4 vQ;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<4;i++){v+=a*n(p);p=p*2.03+7.1;a*=.5;}return v;}
void vertex(){vU=UV;vQ=INSTANCE_CUSTOM;}
void fragment(){vec2 u=vU;float d=length(u),t=floor(vQ.x+.5),age=vQ.y,sd=vQ.z,w=vQ.w,a=0.;vec3 c=COLOR.rgb;
  if(t<.5){a=exp(-d*d*4.);}
  else if(t<1.5){float r=d-.8;a=exp(-r*r/(w*w));}
  else if(t<2.5){float x=abs(u.x),y=abs(u.y);a=exp(-x*14.)*exp(-y*2.6)+exp(-y*14.)*exp(-x*2.6)+exp(-d*d*12.)*.8;a=min(a,1.);c=mix(c,vec3(1.),exp(-d*d*50.)*.5);}
  else if(t<3.5){a=1.-smoothstep(.78,1.,d);float hl=1.-smoothstep(0.,.32,length(u-vec2(-.3,-.32)));c=mix(c*(.82+.25*(1.-u.y)*.5),vec3(1.),hl*.75);}
  else if(t<4.5){float k=fbm(u*1.8+sd*9.+vec2(age*.6,-age*.8));a=(1.-smoothstep(.3,1.,d+(k-.5)*.7));c*=.85+.3*k;}
  else if(t<5.5){a=exp(-u.x*u.x*2.4-u.y*u.y*14.);c=mix(c,vec3(1.),exp(-u.y*u.y*60.-u.x*u.x*5.)*.5);}
  else if(t<6.5){float r=d-.75;a=exp(-r*r/(w*w))*(.7+.3*n(vec2(atan(u.y,u.x)*4.+sd*20.,age*3.)));}
  else if(t<7.5){float x=u.x,hw=.42*pow(max(0.,1.-x*x),.7),y=u.y/max(hw,.001);a=(1.-smoothstep(.8,1.,abs(y)))*step(abs(x),1.);
    c=mix(c*.75,c*1.1,step(0.,y));c=mix(c,c*.6,exp(-u.y*u.y*500.));}
  else if(t<8.5){float x=u.x,hw=.34*pow(max(0.,1.-x*x),.55),y=abs(u.y)/max(hw,.001);a=(1.-smoothstep(.7,1.,y))*step(abs(x),1.);
    c=mix(c,c*.7,exp(-u.y*u.y*700.)*.9);c*=.9+.12*sin(x*30.+y*6.);}
  else if(t<9.5){a=step(abs(u.x),.95)*step(abs(u.y),.95);c*=.8+.3*(u.y*.5+.5);}
  else if(t<10.5){float k=fbm(u*2.4+sd*13.);float e=d+(k-.5)*.55+.18*sin(atan(u.y,u.x)*6.+sd*30.)*.4;a=1.-smoothstep(.55,.7,e);
    float hl=1.-smoothstep(0.,.35,length(u-vec2(-.25,-.25)));c=mix(c,vec3(1.),hl*.35);}
  else{float r=d-.8;a=exp(-r*r/(w*w))*(.55+.45*sin(atan(u.y,u.x)*3.+age*8.));}
  a*=COLOR.a;
  ALPHA_OUT
}
"""

const WARP_SHADER := """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear;
uniform vec2 vp;
uniform float K;
uniform vec4 A0; uniform vec4 B0; uniform vec4 A1; uniform vec4 B1; uniform vec4 A2; uniform vec4 B2; uniform vec4 A3; uniform vec4 B3;
uniform vec4 A4; uniform vec4 B4; uniform vec4 A5; uniform vec4 B5; uniform vec4 A6; uniform vec4 B6; uniform vec4 A7; uniform vec4 B7;
void one(vec4 A, vec4 B, vec2 P, inout vec2 off, inout float lit){
  if(B.x==0.) return;
  vec2 d=P-A.xy;float r=length(d)+.001;vec2 nn=d/r;float x=(r-A.z)/A.w,f;
  if(B.y<.5){f=exp(-x*x)*x*-1.6;}else{f=sin(x*B.z)*exp(-x*x*.18);}
  off+=nn*f*B.x;lit+=f*B.w;
}
void fragment(){
  vec2 P=SCREEN_UV*vp/K;vec2 off=vec2(0.);float lit=0.;
  one(A0,B0,P,off,lit);one(A1,B1,P,off,lit);one(A2,B2,P,off,lit);one(A3,B3,P,off,lit);
  one(A4,B4,P,off,lit);one(A5,B5,P,off,lit);one(A6,B6,P,off,lit);one(A7,B7,P,off,lit);
  vec4 c=texture(scr,SCREEN_UV-off*K/vp);
  c.rgb*=1.+clamp(lit,-.12,.12);
  COLOR=vec4(c.rgb,1.);
}
"""

var game
var P: Array = []
var Wv: Array = []      # sóng đang chạy
var _mm: Array = []     # [soft, light]
var _buf: Array = []
var warp_rect: ColorRect = null
var _warp_mat: ShaderMaterial = null
var top_mode := false

func _init(gm) -> void:
	game = gm
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	warp_rect = ColorRect.new()
	warp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warp_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ws := Shader.new()
	ws.code = WARP_SHADER
	_warp_mat = ShaderMaterial.new()
	_warp_mat.shader = ws
	warp_rect.material = _warp_mat
	warp_rect.visible = false
	add_child(warp_rect)
	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	for light in [false, true]:
		var sh := Shader.new()
		var code: String = PART_SHADER.replace("MODE", "blend_premul_alpha")
		if light:
			# màn hình (screen) gần đúng: alpha = độ sáng, giữ màu thay vì cộng ra trắng
			code = code.replace("ALPHA_OUT", "vec3 cc=c*a;COLOR=vec4(cc,max(cc.r,max(cc.g,cc.b))*.85);")
		else:
			code = code.replace("ALPHA_OUT", "COLOR=vec4(c*a,a);")
		sh.code = code
		var mat := ShaderMaterial.new()
		mat.shader = sh
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = CAP
		mm.visible_instance_count = 0
		var mi := MultiMeshInstance2D.new()
		mi.multimesh = mm
		mi.material = mat
		add_child(mi)
		_mm.append(mi)
		var b := PackedFloat32Array()
		b.resize(CAP * 16)
		_buf.append(b)

func set_top(on: bool) -> void:
	top_mode = on
	z_index = 60 if on else 0

static func col4(s, a := -1.0) -> Color:
	var c: Color = s if s is Color else Color(s)
	if a >= 0:
		c.a = a
	return c

# một hạt; vị trí css px; s0/s1 = bán kính lúc sinh/lúc tắt
func gp(o: Dictionary) -> void:
	if P.size() >= CAP:
		P = P.slice(P.size() - CAP + 1)
	var p := {"sh": 0, "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "g": 0.0, "drag": 0.0, "t": 0.0, "life": 0.5, "s0": 10.0, "s1": 10.0,
		"light": false, "rot": 0.0, "vr": 0.0, "asp": 1.0, "str": 0.0, "w": 0.15, "sd": randf(), "flip": 0.0}
	p.merge(o, true)
	var c0: Color = col4(p.get("c0", Color.WHITE))
	p.c0 = c0
	var c1 = p.get("c1", null)
	if c1 is String and c1 == "keep":
		p.c1 = Color(c0.r, c0.g, c0.b, 0.55)
	elif c1 != null:
		p.c1 = col4(c1)
	else:
		p.c1 = Color(c0.r, c0.g, c0.b, 0)
	if p.flip:
		p.fl = 0.0
	P.append(p)

func warp(x: float, y: float, o: Dictionary) -> void:
	if Wv.size() >= 8:
		Wv.pop_front()
	var w := {"x": x, "y": y, "t": 0.0, "life": 0.5, "r0": 0.0, "r1": 100.0, "w": 20.0, "amp": 8.0, "kind": "shock", "freq": 2.2, "lit": 0.05}
	w.merge(o, true)
	Wv.append(w)

func step(dt: float) -> void:
	for i in range(Wv.size() - 1, -1, -1):
		var w: Dictionary = Wv[i]
		w.t += dt
		if w.t >= w.life:
			Wv.remove_at(i)
	var i2 := P.size() - 1
	while i2 >= 0:
		var p: Dictionary = P[i2]
		p.t += dt
		if p.t >= p.life:
			P.remove_at(i2)
		elif p.t >= 0:
			var dr := maxf(0.0, 1 - p.drag * dt)
			p.vx *= dr
			p.vy *= dr
			p.vy += p.g * dt
			p.x += p.vx * dt
			p.y += p.vy * dt
			p.rot += p.vr * dt
			if p.flip:
				p.fl += p.flip * dt
		i2 -= 1

func render() -> void:
	var S: float = game.LAY.S
	var sxa: float = game.fx.shake_v * S * 0.12
	var ox := randf_range(-sxa, sxa) * 0.5 if sxa > 0 else 0.0
	var oy := randf_range(-sxa, sxa) * 0.5 if sxa > 0 else 0.0
	for li in 2:
		var light := li == 1
		var B: PackedFloat32Array = _buf[li]
		var n := 0
		for p in P:
			if p.light != light or p.t < 0:
				continue
			var k: float = p.t / p.life
			var s: float = p.s0 + (p.s1 - p.s0) * k
			var c0: Color = p.c0
			var c1: Color = p.c1
			var ang: float = p.rot
			var hx: float = s * p.asp
			var hy := s
			if p.str:
				var sp := Vector2(p.vx, p.vy).length()
				ang = atan2(p.vy, p.vx)
				hx = s + sp * p.str
			if p.has("fl"):
				hy *= maxf(0.08, absf(cos(p.fl)))
			var cs := cos(ang)
			var sn := sin(ang)
			var o := n * 16
			B[o] = hx * cs
			B[o + 1] = -hy * sn
			B[o + 2] = 0
			B[o + 3] = p.x + ox
			B[o + 4] = hx * sn
			B[o + 5] = hy * cs
			B[o + 6] = 0
			B[o + 7] = p.y + oy
			B[o + 8] = lerpf(c0.r, c1.r, k)
			B[o + 9] = lerpf(c0.g, c1.g, k)
			B[o + 10] = lerpf(c0.b, c1.b, k)
			B[o + 11] = lerpf(c0.a, c1.a, k)
			B[o + 12] = p.sh
			B[o + 13] = k
			B[o + 14] = p.sd
			B[o + 15] = p.w
			n += 1
			if n >= CAP:
				break
		var mm: MultiMesh = _mm[li].multimesh
		if n > 0:
			mm.buffer = B
		mm.visible_instance_count = n
	# sóng
	var live := false
	for w in Wv:
		if w.t >= 0:
			live = true
	warp_rect.visible = live
	if live:
		_warp_mat.set_shader_parameter("vp", get_viewport_rect().size)
		_warp_mat.set_shader_parameter("K", game.K)
		for i in 8:
			var A := Vector4.ZERO
			var Bv := Vector4.ZERO
			if i < Wv.size() and Wv[i].t >= 0:
				var w: Dictionary = Wv[i]
				var k: float = w.t / w.life
				var e := 1 - pow(1 - k, 2.2)
				var fade := (1 - k) * (1 - k) * minf(1.0, k * 8)
				A = Vector4(w.x, w.y, w.r0 + (w.r1 - w.r0) * e, w.w * (1 + k * 0.6))
				var amp: float = w.amp * fade
				Bv = Vector4(amp if amp != 0 else 1e-6, 1.0 if w.kind == "ripple" else 0.0, w.freq, w.lit * fade)
			_warp_mat.set_shader_parameter("A" + str(i), A)
			_warp_mat.set_shader_parameter("B" + str(i), Bv)

func clear_all() -> void:
	P.clear()
	Wv.clear()

# ---------- mẫu hiệu ứng (FXG của web)
static func R_(a: float, b: float) -> float:
	return a + randf() * (b - a)

func juice(X: float, Y: float, k: int, S: float, big: bool) -> void:
	var j: Array = game.D.FRUITS[k].juice
	var c := mini(game.B.cascade, 4)
	gp({"sh": SH.splat, "x": X, "y": Y + S * 0.05, "life": 0.3, "s0": S * 0.24, "s1": S * 0.4, "c0": col4(j[0], 0.36), "rot": R_(0, TAU)})
	gp({"sh": SH.glow, "light": true, "x": X, "y": Y, "life": 0.14, "s0": S * 0.3, "s1": S * 0.6, "c0": col4(j[0], 0.3)})
	var m := 9 if big else 7
	for i in m:
		var a := float(i) / m * TAU + R_(-0.2, 0.2)
		var v := R_(S * 3.2, S * 4.6)
		gp({"sh": SH.streak, "x": X + cos(a) * S * 0.2, "y": Y + sin(a) * S * 0.2, "vx": cos(a) * v, "vy": sin(a) * v, "drag": 7, "life": R_(0.16, 0.22), "s0": S * 0.07, "s1": S * 0.02, "str": 0.03, "c0": col4(j[i % 2], 1)})
	var n := (13 if big else 10) + c * 2
	for i in n:
		var a := R_(0, TAU)
		var v := R_(S * 1.6, S * 4.4)
		gp({"sh": SH.drop, "x": X + cos(a) * S * 0.15, "y": Y + sin(a) * S * 0.15, "vx": cos(a) * v, "vy": sin(a) * v - S * 1.9, "g": S * 12, "drag": 1.1, "life": R_(0.38, 0.64), "s0": R_(S * 0.075, S * 0.14), "s1": S * 0.03, "str": 0.012, "c0": col4(j.pick_random(), 0.75 if k == 5 else 1.0)})
	for i in 3:
		var a := R_(0, TAU)
		var v := R_(S * 0.8, S * 2)
		gp({"sh": SH.drop, "x": X, "y": Y, "vx": cos(a) * v, "vy": sin(a) * v - S * 0.6, "g": S * 3, "drag": 2.5, "life": R_(0.3, 0.45), "s0": S * 0.035, "s1": S * 0.015, "c0": col4(j[2], 0.9)})
	var st := (3 if big else 0) + (2 if c >= 2 else 0)
	for i in st:
		gp({"sh": SH.star, "light": true, "x": X + R_(-S * 0.35, S * 0.35), "y": Y + R_(-S * 0.35, S * 0.35), "vy": -S * 0.6, "life": 0.4, "t": -i * 0.05, "s0": S * 0.3, "s1": S * 0.05, "c0": col4(j[2], 0.85)})

func make(X: float, Y: float, S: float, sp: String) -> void:
	var col: String = {"h": "#ffe58a", "v": "#ffe58a", "bomb": "#9fd86a", "duck": "#cfeaff", "rooster": "#ffd84a"}.get(sp, "#fff2b0")
	gp({"sh": SH.ring, "light": true, "x": X, "y": Y, "life": 0.5, "s0": S * 1.1, "s1": S * 0.35, "c0": col4(col, 0.9), "w": 0.09})
	gp({"sh": SH.glow, "light": true, "x": X, "y": Y, "life": 0.45, "s0": S * 0.3, "s1": S * 0.9, "c0": col4(col, 0.55)})
	for i in 12:
		var a := i / 12.0 * TAU
		var r := S * 0.95
		gp({"sh": SH.star, "light": true, "x": X + cos(a) * r, "y": Y + sin(a) * r, "vx": -cos(a + 0.6) * S * 2.2, "vy": -sin(a + 0.6) * S * 2.2, "drag": 2, "life": 0.45, "s0": S * 0.26, "s1": S * 0.05, "c0": col4(col, 1)})

func dust(X: float, Y: float, S: float, n := 3, col := "#e9d6aa") -> void:
	for i in n:
		gp({"sh": SH.puff, "x": X + R_(-S * 0.2, S * 0.2), "y": Y + R_(-S * 0.1, S * 0.1), "vx": R_(-S * 0.6, S * 0.6), "vy": -R_(S * 0.2, S * 0.8), "drag": 2, "life": R_(0.45, 0.8), "s0": S * R_(0.15, 0.25), "s1": S * R_(0.4, 0.6), "c0": col4(col, 0.7)})

func straw(X: float, Y: float, S: float) -> void:
	for i in 16:
		var a := R_(0, TAU)
		gp({"sh": SH.paper, "x": X + R_(-S * 0.3, S * 0.3), "y": Y + R_(-S * 0.3, S * 0.3), "vx": cos(a) * S * 3, "vy": -S * R_(1.5, 4.5), "g": S * 9, "drag": 1, "life": R_(0.6, 0.9), "s0": S * 0.05, "s1": S * 0.04, "asp": R_(3, 5), "rot": R_(0, TAU), "vr": R_(-10, 10), "c0": col4(["#f6d36a", "#e2b04a", "#fff0b0"].pick_random(), 1)})
	dust(X, Y, S, 3, "#f3e2b0")

func mud(X: float, Y: float, S: float) -> void:
	gp({"sh": SH.splat, "x": X, "y": Y, "life": 0.5, "s0": S * 0.35, "s1": S * 0.55, "c0": col4("#7a5232", 0.7), "rot": R_(0, TAU)})
	for i in 10:
		var a := R_(0, TAU)
		gp({"sh": SH.drop, "x": X, "y": Y, "vx": cos(a) * S * 2.6, "vy": -S * R_(1.5, 3.8), "g": S * 10, "life": R_(0.4, 0.6), "s0": S * R_(0.07, 0.12), "s1": S * 0.03, "str": 0.01, "c0": col4(["#8a6038", "#6a4426", "#a87a4a"].pick_random(), 1)})

func leaves(X: float, Y: float, S: float, n := 8, cols := ["#6fae3e", "#4f8f36", "#8ccf5a"]) -> void:
	for i in n:
		var a := R_(0, TAU)
		gp({"sh": SH.leaf, "x": X, "y": Y, "vx": cos(a) * S * 2.4, "vy": -S * R_(1, 3), "g": S * 4, "drag": 1.5, "life": R_(0.7, 1.1), "s0": S * 0.16, "s1": S * 0.14, "asp": 1.8, "rot": R_(0, TAU), "vr": R_(-7, 7), "flip": R_(4, 9), "c0": col4(cols.pick_random(), 1)})

func feathers(X: float, Y: float, S: float, n := 3) -> void:
	for i in n:
		gp({"sh": SH.feather, "x": X + R_(-S * 0.2, S * 0.2), "y": Y + R_(-S * 0.2, S * 0.2), "vx": R_(-S * 0.6, S * 0.6), "vy": R_(-S * 0.2, S * 0.5), "g": S * 0.6, "drag": 1.5, "life": R_(0.8, 1.3), "s0": S * 0.16, "s1": S * 0.14, "asp": 2.2, "rot": R_(0, TAU), "vr": R_(-3, 3), "flip": R_(3, 6), "c0": Color.WHITE})

func shock(X: float, Y: float, r: float, col := Color("#fff0d8")) -> void:
	gp({"sh": SH.shock, "x": X, "y": Y, "life": 0.42, "s0": r * 0.25, "s1": r, "c0": col4(col, 0.55), "w": 0.1})
	gp({"sh": SH.ring, "light": true, "x": X, "y": Y, "life": 0.32, "s0": r * 0.2, "s1": r * 0.8, "c0": col4(col, 0.45), "w": 0.06})

func plough(X: float, Y: float, S: float, dir: float) -> void:
	dust(X, Y, S, 2, ["#e9d6aa", "#d8bf8a", "#f3e6c6"].pick_random())
	if randf() < 0.5:
		gp({"sh": SH.drop, "x": X, "y": Y, "vx": R_(-S, S) - dir * S * 2, "vy": -S * R_(1, 3), "g": S * 10, "life": 0.5, "s0": S * 0.07, "s1": S * 0.03, "c0": col4("#8a6a3a", 1)})

func crow(X: float, Y: float, S: float) -> void:
	for i in 4:
		gp({"sh": SH.wave, "light": true, "x": X, "y": Y, "t": -i * 0.16, "life": 0.7, "s0": S * 0.5, "s1": S * 3.4, "c0": col4("#ffd84a", 0.8), "w": 0.06})
	gp({"sh": SH.glow, "light": true, "x": X, "y": Y - S * 0.6, "life": 0.5, "s0": S * 0.5, "s1": S * 1.5, "c0": col4("#ffe8a0", 0.22)})

func trail(X: float, Y: float, S: float, col := "#ffe58a") -> void:
	gp({"sh": SH.star, "light": true, "x": X, "y": Y, "vx": R_(-S * 0.3, S * 0.3), "vy": R_(-S * 0.3, S * 0.3), "drag": 2, "life": R_(0.25, 0.45), "s0": S * R_(0.16, 0.28), "s1": S * 0.04, "c0": col4(col, 0.95)})

func snort(X: float, Y: float, S: float, dir: float) -> void:
	for i in 5:
		gp({"sh": SH.puff, "x": X, "y": Y, "t": -i * 0.03, "vx": dir * S * R_(1.2, 2.2), "vy": -S * R_(0.2, 0.6), "drag": 3, "life": R_(0.45, 0.6), "s0": S * 0.08, "s1": S * R_(0.28, 0.4), "c0": col4("#ffffff", 0.55)})

func clods(X: float, Y: float, S: float, dx: float, dy: float) -> void:
	for i in 3:
		gp({"sh": SH.drop, "x": X + R_(-S * 0.2, S * 0.2), "y": Y, "vx": -dx * S * R_(1, 2.6) + R_(-S * 0.8, S * 0.8), "vy": -S * R_(2, 4) - dy * S * 1.5, "g": S * 12, "drag": 0.6, "life": R_(0.45, 0.65), "s0": S * R_(0.06, 0.1), "s1": S * 0.05, "c0": col4(["#7a5232", "#5e3d22", "#9a6a3e"].pick_random(), 1)})
	if randf() < 0.6:
		gp({"sh": SH.paper, "x": X, "y": Y, "vx": -dx * S * R_(1, 2) + R_(-S, S), "vy": -S * R_(2, 3.5), "g": S * 8, "drag": 1, "life": R_(0.5, 0.7), "s0": S * 0.05, "s1": S * 0.04, "asp": R_(3, 5), "rot": R_(0, TAU), "vr": R_(-12, 12), "c0": col4(["#6fae3e", "#8ccf5a", "#4f8f36"].pick_random(), 1)})

func rush(X: float, Y: float, S: float, dx: float, dy: float) -> void:
	gp({"sh": SH.streak, "x": X - dx * S * 0.5 + R_(-S * 0.15, S * 0.15) * dy, "y": Y - dy * S * 0.5 + R_(-S * 0.35, S * 0.1) * (1 - absf(dy)), "vx": -dx * S * 3, "vy": -dy * S * 3, "drag": 4, "life": 0.22, "s0": S * 0.06, "s1": S * 0.02, "str": 0.035, "c0": col4("#fff6dc", 0.8)})

func slam(X: float, Y: float, S: float, R: float) -> void:
	var big := R > 2
	warp(X, Y, {"r0": S * 0.3, "r1": S * (R + 2), "w": S * 0.55, "amp": S * (0.42 if big else 0.32), "life": 0.6, "lit": 0.03})
	warp(X, Y, {"t": -0.1, "r0": S * 0.2, "r1": S * (R + 1), "w": S * 0.35, "amp": S * 0.18, "life": 0.45, "lit": 0.05})
	gp({"sh": SH.ring, "light": true, "x": X, "y": Y, "life": 0.4, "s0": S * 0.5, "s1": S * (R + 1.6), "c0": col4("#ffd27a", 0.75), "w": 0.05})
	for i in 16:
		var a := i / 16.0 * TAU
		gp({"sh": SH.puff, "x": X + cos(a) * S * (R * 0.5 + 0.4), "y": Y + S * 0.15 + sin(a) * S * (R * 0.35 + 0.2), "vx": cos(a) * S * R_(2.6, 3.6), "vy": sin(a) * S * R_(1.2, 1.8), "drag": 3.4, "life": R_(0.45, 0.65), "s0": S * 0.14, "s1": S * R_(0.32, 0.42), "c0": col4(["#f6ead0", "#ecdcb8"].pick_random(), 0.5)})
	for i in 10:
		var a := R_(0, TAU)
		gp({"sh": SH.star, "light": true, "x": X + cos(a) * S * 0.6, "y": Y - S * 0.3 + sin(a) * S * 0.3, "vx": cos(a) * S * 3, "vy": sin(a) * S * 2 - S * 2, "g": S * 6, "drag": 2, "life": R_(0.4, 0.6), "s0": S * 0.22, "s1": S * 0.05, "c0": col4(["#ffd84a", "#ffb0a0", "#fff0b0"].pick_random(), 0.9)})

func drip(X: float, Y: float, S: float) -> void:
	gp({"sh": SH.drop, "x": X + R_(-S * 0.2, S * 0.2), "y": Y + S * 0.1, "vx": R_(-S * 0.4, S * 0.4), "vy": S * R_(0, 0.6), "g": S * 9, "life": R_(0.35, 0.5), "s0": S * R_(0.04, 0.07), "s1": S * 0.03, "str": 0.01, "c0": col4(["#9fd8f0", "#c8ecf8", "#6fbfe0"].pick_random(), 1)})

func splash(X: float, Y: float, S: float) -> void:
	for i in 18:
		var a := -PI * R_(0.1, 0.9)
		var v := S * R_(2.2, 4.4)
		gp({"sh": SH.drop, "x": X + R_(-S * 0.3, S * 0.3), "y": Y, "vx": cos(a) * v, "vy": sin(a) * v, "g": S * 12, "drag": 0.6, "life": R_(0.45, 0.7), "s0": S * R_(0.05, 0.1), "s1": S * 0.03, "str": 0.012, "c0": col4(["#9fd8f0", "#c8ecf8", "#6fbfe0", "#ffffff"].pick_random(), 1)})
	for i in 2:
		gp({"sh": SH.wave, "x": X, "y": Y, "t": -i * 0.12, "life": 0.55, "s0": S * 0.3, "s1": S * 1.3, "c0": col4("#bfe6f6", 0.85), "w": 0.06})
	feathers(X, Y, S, 4)

func plumes(X: float, Y: float, S: float) -> void:
	for i in 9:
		var a := R_(0, TAU)
		gp({"sh": SH.feather, "x": X, "y": Y, "vx": cos(a) * S * R_(1.5, 3), "vy": sin(a) * S * R_(1, 2.4) - S * 0.8, "g": S * 1.6, "drag": 1.8, "life": R_(0.9, 1.3), "s0": S * 0.2, "s1": S * 0.18, "asp": 2.4, "rot": R_(0, TAU), "vr": R_(-4, 4), "flip": R_(3, 6), "c0": col4(["#d8401c", "#f08a24", "#2f6a3a", "#1e2a3a", "#f4c430"].pick_random(), 1)})

func peck(X: float, Y: float, S: float) -> void:
	gp({"sh": SH.ring, "light": true, "x": X, "y": Y, "life": 0.28, "s0": S * 0.15, "s1": S * 0.55, "c0": col4("#ffd84a", 0.8), "w": 0.1})
	for i in 5:
		var a := R_(0, TAU)
		gp({"sh": SH.star, "light": true, "x": X, "y": Y, "vx": cos(a) * S * 2, "vy": sin(a) * S * 2, "drag": 4, "life": 0.3, "s0": S * 0.18, "s1": S * 0.04, "c0": col4("#ffe27a", 0.9)})

func chop(X: float, Y: float, S: float) -> void:
	warp(X, Y, {"r0": S * 0.2, "r1": S * 1.8, "w": S * 0.35, "amp": S * 0.25, "life": 0.4})
	for i in 12:
		var a := -PI * R_(0.05, 0.95)
		gp({"sh": SH.drop, "x": X, "y": Y + S * 0.2, "vx": cos(a) * S * R_(1.5, 3.5), "vy": sin(a) * S * R_(2, 4), "g": S * 12, "life": R_(0.4, 0.6), "s0": S * R_(0.06, 0.11), "s1": S * 0.04, "c0": col4(["#7a5232", "#5e3d22", "#9a6a3e"].pick_random(), 1)})
	for i in 5:
		var a := -PI * R_(0.2, 0.8)
		gp({"sh": SH.streak, "light": true, "x": X, "y": Y, "vx": cos(a) * S * 5, "vy": sin(a) * S * 5, "drag": 6, "life": 0.18, "s0": S * 0.05, "s1": S * 0.02, "str": 0.03, "c0": col4("#ffe8a0", 0.9)})
	dust(X, Y + S * 0.3, S, 5, "#e9d6aa")

func confetti(W: float, H: float) -> void:
	for i in 180:
		gp({"sh": SH.paper if randf() < 0.7 else SH.leaf, "x": R_(0, W), "y": -R_(10, H * 0.5), "vx": R_(-40, 40), "vy": R_(60, 160), "g": 40, "drag": 0.4, "life": R_(2.4, 3.6), "s0": R_(5, 8), "s1": R_(5, 8), "asp": R_(1, 1.6), "rot": R_(0, TAU), "vr": R_(-6, 6), "flip": R_(5, 12),
			"c0": col4(["#f7b820", "#f57a1c", "#e02f38", "#8a2f7c", "#5fae36", "#f4c430", "#2f8fd0"].pick_random(), 1), "c1": "keep"})

func firework(X: float, Y: float, S: float, col: String) -> void:
	var c := Color(col)
	gp({"sh": SH.glow, "light": true, "x": X, "y": Y, "life": 0.4, "s0": S * 0.4, "s1": S * 1.4, "c0": Color(c.r, c.g, c.b, 0.6)})
	for i in 26:
		var a := i / 26.0 * TAU
		var v := R_(S * 3, S * 4.5)
		gp({"sh": SH.streak, "light": true, "x": X, "y": Y, "vx": cos(a) * v, "vy": sin(a) * v, "g": S * 1.2, "drag": 1.6, "life": R_(0.7, 1.0), "s0": S * 0.1, "s1": S * 0.03, "str": 0.02, "c0": Color(c.r, c.g, c.b, 1), "c1": Color(c.r, c.g * 0.8, c.b * 0.6, 0)})
