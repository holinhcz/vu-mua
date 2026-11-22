extends Node2D
# MẶT TRỜI (11-22, Link "làm mặt trời lại luôn đi, hiệu ứng Godot đâu"): shader Godot vẽ trên màn (không qua SubViewport):
# đĩa nét (mép AA 1 px, lõi trắng -> mép vàng nhạt), viền sáng, quầng sáng thở chậm,
# 2 lớp tia nắng xoay ngược chiều nhau, cộng sáng (premul: alpha 0 = cộng). Chiều tối đỏ cam theo màu nắng của giờ.
# Lóe ống kính: 4 đốm mờ trên đường mặt trời -> giữa màn, vẽ trên bờ. Mưa/đêm thì tắt.
# Mặt nước vẫn soi mặt trời của shader cảnh (SubViewport), trên màn tmat tắt mặt trời cũ (uNoSun).

const SUN_SH := """
shader_type canvas_item;
render_mode blend_premul_alpha;
uniform float uR = 30.;          // bán kính đĩa (px màn)
uniform vec3 uCol = vec3(1.,.95,.8);
uniform float uI = 1.;           // độ sáng (0 = tắt)
uniform float uLow = 0.;         // 1 = sát chân trời (đỏ, to, ít tia)
uniform float uSz = 400.;        // cạnh ô vẽ (px màn)
void fragment(){
 vec2 p=(UV-.5)*uSz;
 float r=length(p), a=atan(p.y,p.x);
 float t=TIME;
 float R=uR*(1.+uLow*.18);
 float d=r/R;
 float disc=clamp(R-r+.5,0.,1.);   // mép tròn nét 1 px
 // đĩa sáng nhất cảnh: lõi trắng, mép vàng nhạt (chiều thì cam đỏ)
 vec3 core=mix(vec3(1.,1.,.97),uCol,.12+uLow*.5);
 vec3 edge=mix(vec3(1.,.95,.7),uCol*vec3(1.,.8,.55),.15+uLow*.75);
 vec3 dc=mix(core,edge,smoothstep(.55,1.,d));
 // quầng + tia (cộng sáng, chỉ ngoài đĩa)
 float pulse=1.+.07*sin(t*1.25)+.03*sin(t*3.1);
 float out1=max(d-1.,0.);
 float halo=exp(-out1*2.2)*.55+exp(-out1*.45)*.22;
 float r1=pow(.5+.5*sin(a*12.+t*.12),5.);
 float r2=pow(.5+.5*sin(a*7.-t*.08+1.7),7.);
 float r3=pow(.5+.5*sin(a*19.+t*.2+.6),9.)*.6;
 float len=.75+.25*sin(a*5.+t*.5);
 float rays=(r1*.55+r2*.45+r3)*smoothstep(1.,1.35,d)*exp(-out1*(.42/len))*(1.-uLow*.6);
 float ring=smoothstep(.18,0.,abs(d-1.12))*.25;
 float add=(halo*pulse+rays*.42+ring)*(1.-disc);
 // tắt dần ở mép ô (khỏi thấy cạnh vuông)
 add*=smoothstep(.5,.36,max(abs(UV.x-.5),abs(UV.y-.5)));
 vec3 ac=mix(uCol,vec3(1.,.97,.85),.4);
 float dv=disc*smoothstep(0.,.25,uI);           // đĩa luôn đặc, sáng nhất; quầng + tia theo độ nắng
 COLOR=vec4(dc*dv+ac*add*uI, dv);
}
"""
const FL_SH := """
shader_type canvas_item;
render_mode blend_add;
uniform vec3 uCol = vec3(1.);
uniform float uA = .1;
uniform float uRing = 0.;
void fragment(){
 float d=length(UV-.5)*2.;
 float m=uRing>.5 ? smoothstep(.15,0.,abs(d-.85))*.8+smoothstep(1.,.0,d)*.15 : smoothstep(1.,.55,d)*(.6+.4*smoothstep(.6,1.,d));
 COLOR=vec4(uCol*m*uA,1.);
}
"""
var game
var scn
var rc: ColorRect
var smat: ShaderMaterial
var fl := []      # [ColorRect, material, vị trí trên đường (0 = mặt trời, 1 = giữa màn, >1 qua bên kia), cỡ, màu]
var flare_node: Node2D

func _init(gm, sc) -> void:
	game = gm
	scn = sc

func _ready() -> void:
	rc = ColorRect.new()
	rc.color = Color.WHITE
	rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SUN_SH
	smat.shader = sh
	rc.material = smat
	add_child(rc)

# lóe ống kính: node riêng, scene đặt nó trên bờ
func make_flare() -> Node2D:
	flare_node = Node2D.new()
	var sh := Shader.new()
	sh.code = FL_SH
	for g in [[.55, .05, Color(1, .9, .6), 0], [.9, .09, Color(.6, .85, 1), 1], [1.25, .035, Color(1, .7, .5), 0], [1.6, .06, Color(.7, 1, .8), 0]]:
		var r := ColorRect.new()
		r.color = Color.WHITE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("uCol", Vector3(g[2].r, g[2].g, g[2].b))
		m.set_shader_parameter("uRing", float(g[3]))
		r.material = m
		flare_node.add_child(r)
		fl.append([r, m, g[0], g[1]])
	return flare_node

func upd(tod: Dictionary, W: Dictionary) -> void:
	var L: Dictionary = game.L
	var on: bool = tod.sunUp
	var I: float = clampf(float(tod.si), 0.0, 1.2) * (1.0 - W.rain * .97) if on else 0.0
	visible = I > 0.01
	if flare_node:
		flare_node.visible = visible
	if not visible:
		return
	var sp: Vector2 = scn.sun_screen(tod)
	var low := clampf(1.0 - float(tod.sunElev) / .35, 0.0, 1.0)
	var R: float = minf(L.H, L.W * 1.2) * .036      # màn dọc hẹp: theo bề ngang
	var sz: float = R * 13.0
	rc.position = sp - Vector2(sz, sz) * .5
	rc.size = Vector2(sz, sz)
	var c: Color = tod.sun
	smat.set_shader_parameter("uR", R)
	smat.set_shader_parameter("uSz", sz)
	smat.set_shader_parameter("uCol", Vector3(c.r, c.g, c.b))
	smat.set_shader_parameter("uI", minf(I, 1.0))
	smat.set_shader_parameter("uLow", low)
	if flare_node:
		var ctr := Vector2(L.W * .5, L.H * .5)
		var fa := .55 * minf(I, 1.0) * (1.0 - low * .5)
		for f in fl:
			var p: Vector2 = sp.lerp(ctr, f[2])
			var s: float = L.H * float(f[3])
			f[0].position = p - Vector2(s, s)
			f[0].size = Vector2(s, s) * 2.0
			f[1].set_shader_parameter("uA", .16 * fa)
