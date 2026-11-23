extends Node2D
# MẶT TRỜI (11-22, Link "làm mặt trời lại luôn đi, hiệu ứng Godot đâu", rồi "bớt sáng loá lại, làm nhẹ thôi"):
# shader Godot vẽ trên màn (không qua SubViewport): đĩa nét (mép AA 1 px, lõi trắng -> mép vàng nhạt), quầng nhỏ thở
# rất chậm, tia nắng ngắn mờ xoay chậm, cộng sáng (premul: alpha 0 = cộng). Chiều tối đỏ cam theo màu nắng của giờ.
# Mưa / đêm thì tắt. Mặt nước vẫn soi mặt trời của shader cảnh (SubViewport); trên màn tmat tắt mặt trời cũ (uNoSun).
# Vẽ bằng Node2D + draw_texture_rect, KHÔNG dùng ColorRect: Control bị làm tròn vị trí theo px (snap_controls_to_pixels)
# nên mặt trời trôi giật từng nấc 1 px css (Link: "trôi cà giựt cà giựt").

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
 vec3 core=mix(vec3(1.,1.,.97),uCol,.12+uLow*.5);
 vec3 edge=mix(vec3(1.,.95,.7),uCol*vec3(1.,.8,.55),.15+uLow*.75);
 vec3 dc=mix(core,edge,smoothstep(.55,1.,d));
 // quầng nhỏ + tia ngắn mờ (cộng sáng, chỉ ngoài đĩa)
 float pulse=1.+.04*sin(t*.8);
 float out1=max(d-1.,0.);
 float halo=exp(-out1*3.)*.28+exp(-out1*.9)*.07;
 float r1=pow(.5+.5*sin(a*12.+t*.1),5.);
 float r2=pow(.5+.5*sin(a*7.-t*.07+1.7),7.);
 float len=.75+.25*sin(a*5.+t*.4);
 float rays=(r1*.6+r2*.4)*smoothstep(1.,1.3,d)*exp(-out1*(1.1/len))*(1.-uLow*.6);
 float add=(halo*pulse+rays*.16)*(1.-disc);
 add*=smoothstep(.5,.36,max(abs(UV.x-.5),abs(UV.y-.5)));   // tắt dần ở mép ô
 vec3 ac=mix(uCol,vec3(1.,.97,.85),.4);
 float dv=disc*smoothstep(0.,.25,uI);
 COLOR=vec4(dc*dv+ac*add*uI, dv);
}
"""
var game
var scn
var rc: Node2D
var smat: ShaderMaterial
var _sz := 400.0
var _white: ImageTexture

func _init(gm, sc) -> void:
	game = gm
	scn = sc

func _ready() -> void:
	var im := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	im.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(im)
	rc = Node2D.new()
	smat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SUN_SH
	smat.shader = sh
	rc.material = smat
	rc.draw.connect(_draw_quad)
	add_child(rc)

func _draw_quad() -> void:
	rc.draw_texture_rect(_white, Rect2(Vector2(-_sz, -_sz) * .5, Vector2(_sz, _sz)), false)

func upd(tod: Dictionary, W: Dictionary) -> void:
	var L: Dictionary = game.L
	var I: float = clampf(float(tod.si), 0.0, 1.2) * (1.0 - W.rain * .97) if tod.sunUp else 0.0
	visible = I > 0.01
	if not visible:
		return
	var sp: Vector2 = scn.sun_screen(tod)
	var low := clampf(1.0 - float(tod.sunElev) / .35, 0.0, 1.0)
	var R: float = minf(L.H, L.W * 1.2) * .036      # màn dọc hẹp: theo bề ngang
	var sz: float = R * 9.0
	rc.position = sp
	if absf(sz - _sz) > .01:
		_sz = sz
		rc.queue_redraw()
	var c: Color = tod.sun
	smat.set_shader_parameter("uR", R)
	smat.set_shader_parameter("uSz", sz)
	smat.set_shader_parameter("uCol", Vector3(c.r, c.g, c.b))
	smat.set_shader_parameter("uI", minf(I, 1.0))
	smat.set_shader_parameter("uLow", low)
