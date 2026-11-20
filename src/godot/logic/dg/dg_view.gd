extends Control
# ĐUA GÀ: vẽ cuộc đua, dịch 1:1 từ drawWorld / drawSky / proj của web. Máy quay kiểu Mode 7 (không ngóc, chân trời cố định
# ở HOR), mọi số đo là css px của web, gốc game phóng to K lần. Lớp: trời (_sky) -> mặt đất (shader, dịch từ
# sec_glground.js) -> cảnh vật + gà xếp theo độ xa (_world) -> viền tối.

const A := preload("res://logic/xt/xt_art.gd")
const ZFAR := 3800.0
const NEAR := 8.0
const LIFE_S := 6.0
const INK := Color("#3b2415")
const RATE := {"cheer": 3.1, "flag": 2.3, "wave": 2.6, "clap": 4.4, "jump": 2.7, "pump": 3.0}
const LOOK_ACT := ["cheer", "flag", "wave", "clap", "jump", "clap", "pump", "clap"]
const LOOK_KID := [false, false, false, false, true, true, false, false]
const BUNT := ["#d8392b", "#f4c53a", "#3c78c8", "#4f9a3a", "#f6f1e4", "#e8702a"]
const STRAW_C := ["#f6dc8a", "#ecc865", "#e0b44e", "#cf9d3a", "#fbe9a8"]

const GROUND_SHADER := """
shader_type canvas_item;
uniform sampler2D uMac : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D uInf : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D uDirt : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D uGrass : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D uMask : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D uPD : filter_nearest, repeat_disable;
uniform vec2 uCam; uniform vec2 uTex; uniform vec4 uRot; uniform vec4 uPrj; uniform vec4 uOrg;
uniform float uT; uniform float uWet; uniform float uZF; uniform float uTSC;
uniform vec3 uHaze; uniform vec3 uSkyH; uniform vec3 uSkyT; uniform vec3 uSun;
uniform vec4 uStart; uniform int uNPad; uniform int uNMud;
const mat2 R1=mat2(vec2(.8,-.6),vec2(.6,.8)), R2=mat2(vec2(.28,.96),vec2(-.96,.28));
vec2 tuv(vec2 w){return (w*uTSC+.5)/uTex;}
vec3 mac(vec2 w){return texture(uMac,tuv(w)).rgb;}
vec3 wav(vec2 w){float ph=6.*texture(uMask,w/420.+uT*.004).b;vec2 g=vec2(0.);float h=0.;
  vec4 D[4]=vec4[4](vec4(.96,.28,.09,1.1),vec4(-.37,.93,.13,.9),vec4(.71,-.71,.21,1.5),vec4(.2,.98,.33,1.9));float A[4]=float[4](1.,.7,.45,.28);
  for(int i=0;i<4;i++){float a=dot(D[i].xy,w)*D[i].z+uT*D[i].w+ph*(1.+float(i)*.4);h+=A[i]*sin(a);g+=A[i]*cos(a)*D[i].z*D[i].xy;}
  return vec3(g,h);}
void fragment(){
  vec2 lo=vec2(uOrg.x+UV.x*uOrg.z, uOrg.y+UV.y*uOrg.w);
  float dy=lo.y-uPrj.z;
  if(dy<=0.){COLOR=vec4(uHaze,1.);}
  else{
  float z=uPrj.x*uPrj.y/dy;
  if(z>uZF){COLOR=vec4(uHaze,1.);}
  else{
  vec2 w=uCam+uRot.xy*z+uRot.zw*((lo.x-uPrj.w*.5)*z/uPrj.y);
  vec4 I=texture(uInf,tuv(w));
  float au=I.r*2.,deck=1.-I.g,keep=1.-I.b,wat=I.a;
  vec2 gr=vec2(texture(uInf,tuv(w+vec2(2.,0.))).r,texture(uInf,tuv(w+vec2(0.,2.))).r)-I.r;
  vec2 nrm=gr/max(length(gr),1e-5);
  float e1=1.-smoothstep(.25,.45,abs(au-1.));
  vec3 roadC=mac(w-nrm*5.*e1),offC=mac(w+nrm*6.*e1),c0=mac(w);
  vec3 V0=normalize(vec3(w-uCam,-uPrj.x));
  float n0=texture(uMask,w/760.).b,n1=texture(uMask,w/170.+.31).b,bl=smoothstep(.35,.65,n1);
  vec2 d1=w/128.,d2=R1*w/181.+.5,g1=w/90.,g2=R2*w/133.+.27;
  vec3 dm=mix(texture(uDirt,d1).rgb,texture(uDirt,d2).rgb,bl)*2.;
  vec3 gm=mix(texture(uGrass,g1).rgb,texture(uGrass,g2).rgb,bl)*2.;
  float gh=mix(texture(uMask,g1).g,texture(uMask,g2).g,bl);
  float grn=offC.g-.5*(offC.r+offC.b),ga=smoothstep(.05,.17,grn);
  vec3 off=mix(offC*mix(vec3(1.),dm,.75),offC*gm,ga)*(.95+.1*n0);
  float ed=(au-1.)*84.,wob=(n1-.5)*10.+(texture(uMask,w/45.).b-.5)*4.;
  float ge=ed+wob+(gh-.45)*1.6,aa=fwidth(ge)*.7+.05,edge=smoothstep(-aa,aa,ge);
  float rw=abs(au-.45)*84.+(texture(uMask,w/40.).b-.5)*2.5,rut=1.-smoothstep(3.6,6.,rw),ridge=smoothstep(4.5,6.5,rw)*(1.-smoothstep(6.5,10.,rw));
  vec3 rd=mix(dm,vec3(mix(1.,dot(dm,vec3(.3333)),.5)),rut*.7);
  vec3 road=roadC*rd*(1.-.13*rut-.06*(1.-smoothstep(0.,3.,rw)))*(1.+.05*ridge)*(.93+.14*n0);
  road*=1.-.24*smoothstep(-4.,0.,ed+wob);
  float pud=uWet*smoothstep(.43,.36,texture(uMask,w/140.+.7).b)*(.3+.7*rut);
  road*=1.-.22*uWet;
  off*=1.-.16*(1.-smoothstep(0.,3.5,ge))*ga;
  vec3 col=mix(road,off,edge);
  col=mix(col,c0*mix(vec3(1.),dm,.22),deck);
  col=mix(col,c0,keep);
  {vec2 d=w-uStart.xy,q=vec2(dot(d,vec2(cos(uStart.z),sin(uStart.z))),dot(d,vec2(-sin(uStart.z),cos(uStart.z))));float cs=uStart.w/5.5;
   vec2 b=abs(q)-vec2(cs,uStart.w);float sd=max(b.x,b.y)+(texture(uMask,w/23.).b-.5)*1.6,m=1.-smoothstep(-fwidth(sd),fwidth(sd),sd);
   if(m>0.){float k=mod(floor(q.x/cs)+floor(q.y/cs),2.);vec3 cc=k>.5?vec3(.97,.94,.86):vec3(.22,.16,.1);
     cc*=mix(vec3(1.),dm,.35);col=mix(col,cc,m*(.9-.25*rut));}}
  for(int i=0;i<12;i++){if(i>=uNPad)break;vec4 P=texelFetch(uPD,ivec2(i,0),0);vec2 d=w-P.xy;vec2 ax=vec2(cos(P.z),sin(P.z)),q=vec2(dot(d,ax),dot(d,vec2(-ax.y,ax.x)));
    vec2 b=abs(q)-vec2(26.,20.);float sd=length(max(b,0.))+min(max(b.x,b.y),0.)-3.,f=fwidth(sd);
    col*=1.-.28*(1.-smoothstep(0.,3.5,sd-1.5))*smoothstep(-1.,1.,sd);
    float m=1.-smoothstep(-f,f,sd);if(m<=0.)continue;
    float sl=fract(q.x/3.6);vec3 mat=mix(vec3(.62,.44,.2),vec3(.86,.68,.36),smoothstep(.06,.2,sl)*smoothstep(.98,.84,sl));
    mat*=.92+.16*texture(uDirt,q/40.).r;
    float rim=smoothstep(-5.,-3.5,sd);mat=mix(mat,vec3(.5,.32,.14)*(.85+.3*step(.5,fract((q.x+q.y)/4.))),rim);
    float ch=1e3;for(int k=0;k<2;k++){float cx=q.x-(k==0?-4.:10.)+abs(q.y)*.8;ch=min(ch,max(abs(cx+3.)-3.,abs(q.y)-14.));}
    float cf=fwidth(ch),cm=(1.-smoothstep(-cf,cf,ch))*(1.-rim);
    float pulse=.5+.5*sin(q.x*.22-uT*8.);
    vec3 corn=mix(vec3(1.,.66,.1),vec3(1.,.92,.5),pulse)*(.9+.2*texture(uMask,q/9.).b);
    mat=mix(mat,corn,cm);mat=mix(mat,mat*.8,(1.-smoothstep(-1.,1.,ch+1.5))*(1.-cm)*(1.-rim));
    col=mix(col,mat,m);}
  for(int i=0;i<16;i++){if(i>=uNMud)break;vec4 M=texelFetch(uPD,ivec2(12+i,0),0);vec2 d=w-M.xy;float r=M.z,dl=length(d);if(dl>r*1.45+10.)continue;
    float fi=float(i),an=atan(d.y,d.x),ph=fi*1.7+M.x*.013;
    float lob=1.+.07*sin(3.*an+ph)+.05*sin(5.*an+2.*ph)+.025*sin(9.*an+ph);
    float sd=dl-r*lob,f=fwidth(sd)+.15,a=M.w;
    vec2 od=d/max(dl,1e-3);
    vec3 ink=vec3(.24,.14,.06),lipC=vec3(.6,.43,.25)*(.9+.2*texture(uDirt,w/18.).r);
    col=mix(col,col*vec3(.8,.72,.64),a*(1.-smoothstep(0.,5.,sd)));
    float gmm=1e3;for(int k=0;k<7;k++){float fk=float(k),gaa=fk*.898+ph*1.3+sin(fk*3.1+ph)*.4,gr2=r*(1.12+.12*fract(sin(fk*7.3+ph)*91.7))+3.;
      vec2 gc=M.xy+vec2(cos(gaa),sin(gaa))*gr2;gmm=min(gmm,length(w-gc)-(1.4+1.6*fract(sin(fk*4.7+ph)*43.1)));}
    float gf=fwidth(gmm)+.1;col=mix(col,mix(ink,lipC,smoothstep(-.2,-1.,gmm)),a*(1.-smoothstep(-gf,gf,gmm)));
    float m=1.-smoothstep(-f,f,sd);if(m<=0.)continue;
    float lw2=max(3.,r*.17),lip=smoothstep(-lw2-f,-lw2+f,sd);
    float edgeInk=smoothstep(-.9-f,-.9+f,sd),crease=(1.-smoothstep(.0,.9+f,abs(sd+lw2)));
    vec3 lc=lipC*(.85+.35*max(0.,dot(-od,uSun.xy)))*(1.-.25*smoothstep(-lw2,-lw2*.4,sd));
    float deep=clamp(-sd/(r*.8),0.,1.);
    vec3 mb=mix(vec3(.36,.22,.11),vec3(.2,.11,.05),deep);
    vec2 q=w*.17;
    float sw=(.5+.5*sin(q.x*1.2+sin(q.y*.8+uT*.25)*2.))*(.5+.5*cos(q.y*1.4+sin(q.x*.5-uT*.2)*1.7));
    float sf=fwidth(sw)+.01,st=smoothstep(.62-sf,.62+sf,sw)*smoothstep(-lw2*1.3,-lw2*2.2,sd);
    vec2 cc=floor(w/8.),hh=fract(sin(vec2(dot(cc,vec2(127.1,311.7)),dot(cc,vec2(269.5,183.3))))*43758.55);
    float bph=fract(uT*.35+hh.x*7.),bon=step(.55,hh.y)*smoothstep(-lw2*1.2,-lw2*2.,sd);
    vec2 bq=w-(cc+.25+.5*hh)*8.;float br=2.4*smoothstep(0.,.8,bph),bd=length(bq),bf=fwidth(bd)+.05;
    float dome=(1.-smoothstep(br-bf,br+bf,bd))*step(bph,.86)*bon;
    float bring=(1.-smoothstep(.0,.35+bf,abs(bd-br)))*step(bph,.86)*bon*step(.3,br);
    float pop=(1.-smoothstep(0.,.45+bf,abs(bd-(bph-.86)*24.)))*step(.86,bph)*(1.-(bph-.86)/.14)*bon;
    float hl=(1.-smoothstep(.3,.3+bf+.3,length(bq+vec2(.35,.45)*br)))*dome;
    vec3 sky=mix(uSkyH,uSkyT,.3)*vec3(1.,.95,.88);
    vec3 wm=mb;
    wm=mix(wm,mix(mb,sky,.42),st);
    wm=mix(wm,mb*1.25,dome);wm=mix(wm,ink,bring*.8);wm=mix(wm,sky*.9,hl);wm=mix(wm,lipC*.8,pop);
    vec3 mc=mix(wm,lc,lip);
    mc=mix(mc,ink,max(edgeInk,crease*.7));
    col=mix(col,mc,m*a);}
  vec3 V=V0;
  float wa=smoothstep(.3,.7,wat+(n1-.5)*.25),pw=max(wa,pud*(1.-edge)*(1.-deck));
  if(pw>.001){
    vec3 wv=wav(w);float h=.5+.18*wv.z,k=wa>pud?.45:.2;
    vec3 N=normalize(vec3(-wv.xy*k,1.));
    vec3 Rf=reflect(V,N);float fr=.03+.97*pow(1.-max(0.,dot(-V,N)),5.);
    vec3 sky=mix(uSkyH,uSkyT,clamp(Rf.z*1.5,0.,1.));
    float sp=pow(max(dot(Rf,uSun),0.),900.)*1.4*(1.-uWet),crest=smoothstep(-.6,1.6,wv.z);
    vec3 base=c0*mix(.84,.96,smoothstep(.6,1.,wat))*(.94+.12*h);
    vec3 wc=base*(1.-.3*fr)+sky*clamp(fr,0.,.6)*(.25+.6*crest)+sp*vec3(1.,.93,.78);
    col=mix(col,wc,wa);
    col=mix(col,mix(col*.55,sky,.55),pud*(1.-edge)*(1.-deck)*(1.-wa)*.85);
  }
  col*=1.-.18*smoothstep(.04,.3,wat)*(1.-wa);
  COLOR=vec4(col,1.);
  }}
}
"""

class Lay extends Control:
	var fn: Callable
	func _init(f: Callable) -> void:
		fn = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		fn.call(self)

var R   # dg_race
var M   # dg_map
var RS  # dg_res
var VW := 412.0
var VH := 915.0
var F := 300.0
var HOR := 80.0
var CH := 70.0
var CDIST := 220.0
var fx := 1.0
var fy := 0.0
var rx := 0.0
var ry := 1.0
var cx := 0.0
var cy := 0.0
var clock := 0.0
var sky_l: Lay
var ground: ColorRect
var world: Lay
var mat: ShaderMaterial
var pd_img: Image
var pd_tex: ImageTexture
var SKY := {}
var tags: Array = []
var _shadow_pts := PackedVector2Array()

static var _cssc := {}
# màu kiểu css của web: #hex, rgb(), rgba()
static func css(t: String) -> Color:
	if _cssc.has(t):
		return _cssc[t]
	var c := Color.BLACK
	if t.begins_with("rgb"):
		var a := t.substr(t.find("(") + 1).trim_suffix(")").split(",")
		c = Color(float(a[0]) / 255.0, float(a[1]) / 255.0, float(a[2]) / 255.0, float(a[3]) if a.size() > 3 else 1.0)
	else:
		c = Color(t)
	_cssc[t] = c
	return c

func setup(race, map, res) -> void:
	R = race
	M = map
	RS = res

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sky_l = Lay.new(_sky)
	add_child(sky_l)
	ground = ColorRect.new()
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GROUND_SHADER
	mat.shader = sh
	ground.material = mat
	add_child(ground)
	world = Lay.new(_world)
	add_child(world)
	pd_img = Image.create(28, 1, false, Image.FORMAT_RGBAF)
	pd_tex = ImageTexture.create_from_image(pd_img)
	for k in ["mac", "inf", "dirt", "grass", "mask"]:
		mat.set_shader_parameter("u" + k.capitalize(), RS.gtex.get(k))
	mat.set_shader_parameter("uPD", pd_tex)
	mat.set_shader_parameter("uTex", Vector2(M.TXW, M.TXH))
	mat.set_shader_parameter("uTSC", M.TSC)
	mat.set_shader_parameter("uZF", ZFAR)
	SKY = M.sky.P.get(String(M.map.tod), M.sky.P.day)
	_sky_sun(String(M.map.tod))

# resize() của web, tính thẳng bằng css px
func layout(w: float, h: float) -> void:
	VW = w
	VH = h
	size = Vector2(w, h)
	var land := VW >= VH
	F = maxf(VW, VH * 1.15) * 0.8
	HOR = VH * (0.34 if land else 0.36)
	var dy := VH * 0.8 - HOR
	CH = 36.0 * dy / ((0.24 if land else 0.2) * VH)
	CDIST = CH * F / dy
	R.CH0 = CH
	R.CH = CH
	R.CDIST = CDIST
	for c in [sky_l, world]:
		c.position = Vector2.ZERO
		c.size = size
	ground.position = Vector2(0, HOR)
	ground.size = Vector2(VW, VH - HOR)

func proj(wx: float, wy: float, h := 0.0) -> Array:
	var dx := wx - cx
	var dy := wy - cy
	var z := dx * fx + dy * fy
	if z < NEAR:
		return []
	var l := dx * rx + dy * ry
	var sc := F / z
	return [VW / 2 + l * sc, HOR + (CH - h) * sc, HOR + CH * sc, sc, z, l]   # x, y, gy, s, z, l

func redraw() -> void:
	clock = R.clock
	CH = R.CH
	cx = R.cam.x
	cy = R.cam.y
	var th: float = R.cam.th
	fx = cos(th)
	fy = sin(th)
	rx = -fy
	ry = fx
	_ground_uniforms()
	sky_l.queue_redraw()
	world.queue_redraw()

# ------------------------------------------------------------------ mặt đất
func _ground_uniforms() -> void:
	mat.set_shader_parameter("uCam", Vector2(cx, cy))
	mat.set_shader_parameter("uRot", Vector4(fx, fy, rx, ry))
	mat.set_shader_parameter("uPrj", Vector4(CH, F, HOR, VW))
	mat.set_shader_parameter("uOrg", Vector4(0, HOR, VW, VH - HOR))
	mat.set_shader_parameter("uT", clock)
	mat.set_shader_parameter("uWet", 0.0)
	var hz: Array = M.map.haze
	mat.set_shader_parameter("uHaze", Vector3(hz[0], hz[1], hz[2]) / 255.0)
	var P: Dictionary = SKY
	mat.set_shader_parameter("uSkyH", Vector3(P.hor[0], P.hor[1], P.hor[2]) / 255.0)
	mat.set_shader_parameter("uSkyT", Vector3(P.zen[0], P.zen[1], P.zen[2]) / 255.0)
	var el := {"morning": 0.22, "day": 0.95, "sunset": 0.12}.get(String(M.map.tod), 0.5) as float
	var sb: float = M.map.sun
	mat.set_shader_parameter("uSun", Vector3(cos(sb) * cos(el), sin(sb) * cos(el), sin(el)))
	mat.set_shader_parameter("uStart", Vector4(M.PX[0], M.PY[0], M.TA[0], M.WD[0]))
	var np := mini(12, M.PADS.size())
	for i in np:
		var p: Dictionary = M.PADS[i]
		pd_img.set_pixel(i, 0, Color(p.x, p.y, M.TA[p.i], 0))
	var md := []
	for t in R.traps:
		if t.get("kind", "") != "bun" or t.get("dead", false):
			continue
		var dx: float = t.x - cx
		var dy: float = t.y - cy
		var still: bool = t.get("still", false)
		md.append([dx * dx + dy * dy, t.x, t.y, float(t.r), 1.0 if still else clampf(float(t.life) / 1.5, 0, 1)])
	md.sort_custom(func(a, b): return a[0] < b[0])
	var nm := mini(16, md.size())
	for i in nm:
		pd_img.set_pixel(12 + i, 0, Color(md[i][1], md[i][2], md[i][3], md[i][4]))
	pd_tex.update(pd_img)
	mat.set_shader_parameter("uNPad", np)
	mat.set_shader_parameter("uNMud", nm)

# ------------------------------------------------------------------ trời (drawSky)
static func _rgb(a: Array, al := 1.0) -> Color:
	return Color(float(a[0]) / 255.0, float(a[1]) / 255.0, float(a[2]) / 255.0, al)

static func _mix(a: Array, b: Array, t: float) -> Array:
	return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]

func _sky_sun(tk: String) -> void:
	var el: float = SKY.el
	var b: float = M.map.sun
	M.SUN_L = [cos(b) * cos(el), sin(b) * cos(el), sin(el)]

func _vgrad(ci: CanvasItem, x0: float, y0: float, x1: float, y1: float, stops: Array) -> void:
	# dải màu dọc: stops = [[t, Color], ...]
	for i in stops.size() - 1:
		var a: Array = stops[i]
		var b: Array = stops[i + 1]
		var ya: float = y0 + (y1 - y0) * a[0]
		var yb: float = y0 + (y1 - y0) * b[0]
		ci.draw_polygon(PackedVector2Array([Vector2(x0, ya), Vector2(x1, ya), Vector2(x1, yb), Vector2(x0, yb)]), PackedColorArray([a[1], a[1], b[1], b[1]]))

func _glow(ci: CanvasItem, c: Vector2, r0: float, r1: float, col: Color, sy := 1.0) -> void:
	# quầng tròn tỏa ra (radial gradient), vẽ bằng vòng tam giác
	var n := 40
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var ca := col
	var cb := Color(col.r, col.g, col.b, 0)
	for i in n + 1:
		var a := TAU * i / n
		var d := Vector2(cos(a), sin(a) * sy)
		pts.append(c + d * r0)
		pts.append(c + d * r1)
	for i in n:
		var q := PackedVector2Array([pts[i * 2], pts[i * 2 + 1], pts[i * 2 + 3], pts[i * 2 + 2]])
		ci.draw_polygon(q, PackedColorArray([ca, cb, cb, ca]))
	if r0 > 0:
		ci.draw_colored_polygon(A.ell_pts(c, r0, r0 * sy, 32), ca)

func _sky(ci: CanvasItem) -> void:
	if R == null:
		return
	var hy := HOR
	var P: Dictionary = SKY
	var tk := String(M.map.tod)
	_vgrad(ci, 0, 0, VW, hy + 2, [[0.0, _rgb(P.zen)], [0.55, _rgb(P.mid)], [1.0, _rgb(P.hor)]])
	var pxPerRad := F
	var off: float = R.cam.th * pxPerRad
	var th: float = R.cam.th
	var gl: Array = String(P.glow).split(",")
	var glc := Color(float(gl[0]) / 255, float(gl[1]) / 255, float(gl[2]) / 255)
	var sunY: float = {"morning": 0.52, "day": 0.14, "sunset": 0.8}.get(tk, 0.14)
	var sunX: float = VW / 2 + R.wrapA(float(M.map.sun) - th) * pxPerRad
	var sr: float = (15.0 if tk == "day" else (17.0 if tk == "sunset" else 15.0)) * 1.6
	if sunX > -VW and sunX < VW * 2:
		var sy := hy * sunY
		if tk != "day":
			_glow(ci, Vector2(sunX, hy), 0, VW * 0.6, Color(glc, 0.42), 0.35)
		_glow(ci, Vector2(sunX, sy), sr * 0.6, sr * 7, Color(glc, 0.6))
		ci.draw_colored_polygon(A.ell_pts(Vector2(sunX, sy), sr * 1.12, sr * 1.12, 40), Color(glc, 0.35))
		ci.draw_colored_polygon(A.ell_pts(Vector2(sunX, sy), sr, sr, 40), _rgb(P.sun))
	# mây, lớp xa trước
	var L: Dictionary = M.sky.L
	var U := VH / 720.0
	for lay in ["hi", "md", "lo"]:
		for q in L.c:
			if q.lay != lay:
				continue
			var name = "CLOUD." + lay + "." + str(int(q.v))
			var tex = RS.spr(name)
			if tex == null:
				continue
			var w: float = (210.0 if lay == "hi" else (150.0 if lay == "md" else 105.0)) * U * float(q.s)
			var h: float = w * tex.get_height() / tex.get_width()
			var x: float = VW / 2 + R.wrapA(float(q.b) + clock * float(q.sp) - th) * pxPerRad
			if x < -w or x > VW + w:
				continue
			var y: float = hy * float(q.e) - h * 0.86
			if (x < sunX) != (float(P.lx) > 0):
				ci.draw_texture_rect(tex, Rect2(x + w / 2, y, -w, h), false)
			else:
				ci.draw_texture_rect(tex, Rect2(x - w / 2, y, w, h), false)
	# chim bay
	var bc := css(String(P.bird))
	bc.a = 0.85
	for b in L.birds:
		var x: float = VW / 2 + R.wrapA(float(b.b) + clock * (0.012 + 0.004 * float(b.f)) - th) * pxPerRad
		if x < -20 or x > VW + 20:
			continue
		var y: float = hy * float(b.e) + sin(clock * 0.7 + float(b.ph)) * 3 * U
		var s: float = (5.5 - float(b.f) * 1.2) * U
		var fl := sin(clock * (9.0 if tk == "sunset" else 5.0) + float(b.ph))
		var pts := PackedVector2Array()
		for t in 9:
			var u := t / 8.0
			pts.append(_qb(Vector2(x - s, y - fl * s * 0.6), Vector2(x - s * 0.45, y - s * 0.3 - fl * s * 0.2), Vector2(x, y), u))
		for t in range(1, 9):
			var u := t / 8.0
			pts.append(_qb(Vector2(x, y), Vector2(x + s * 0.45, y - s * 0.3 - fl * s * 0.2), Vector2(x + s, y - fl * s * 0.6), u))
		ci.draw_polyline(pts, bc, maxf(1, 1.3 * U), true)
	# núi xa: mỗi dãy mờ vào sương ở chân
	var hz: Array = M.map.haze
	var hor: Array = P.hor
	var hzc := _mix(hz, hor, 0.5)
	var mtn: Array = P.mtn
	var cool := _mix(P.mid, hzc, 0.3)
	var fog: float = M.map.fog
	var MR = M.sky.M
	if MR == null:
		MR = [{"d": 0.35, "a": M.map.mount[1], "b": M.map.mount[2], "f": 2, "p": 0.4}]
	for Rg in MR:
		var col := _mix(cool, mtn, float(Rg.d))
		var top: float = hy - (float(Rg.b) + float(Rg.a))
		var c0 := _rgb(col)
		var c1 := _rgb(_mix(col, hzc, 0.55))
		var line := PackedVector2Array()
		var x := -4.0
		while x <= VW + 8:
			var w := (x + off) / pxPerRad
			var h: float = float(Rg.b) + float(Rg.a) * (absf(sin(w * Rg.f + Rg.p)) * 0.58 + absf(sin(w * Rg.f * 2.3 + Rg.p * 1.7)) * 0.28 + absf(sin(w * Rg.f * 5.9 + Rg.p * 0.6)) * 0.1 + 0.04 * sin(w * Rg.f * 13 + Rg.p))
			line.append(Vector2(x, hy - h))
			x += 5.0
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			var ta := (a.y - top) / maxf(1.0, hy - top)
			var tb := (b.y - top) / maxf(1.0, hy - top)
			ci.draw_polygon(PackedVector2Array([a, b, Vector2(b.x, hy + 2), Vector2(a.x, hy + 2)]), PackedColorArray([c0.lerp(c1, ta), c0.lerp(c1, tb), c1, c1]))
		var lc := _rgb(_mix(col, [255, 255, 255], 0.25), 0.5)
		ci.draw_polyline(line, lc, maxf(1, 0.9), true)
		var mh: float = float(Rg.b) + float(Rg.a) * 0.45
		_vgrad(ci, 0, hy - mh, VW, hy + 2, [[0.0, _rgb(hzc, 0)], [1.0, _rgb(hzc, 0.2 + 0.3 * fog)]])
	# đồi xanh và hàng cây xa
	var hills: Array = M.map.hills
	for k in hills.size():
		var hl: Array = hills[k]
		var colh := _rgb(_hex(String(hl[0])))
		var amp: float = hl[1]
		var base: float = hl[2]
		var f1 := 3.0 + k * 2
		var f2 := 7.0 + k * 4
		var ph := 1.0 + k
		var pts := PackedVector2Array([Vector2(0, hy + 2)])
		var x2 := 0.0
		while x2 <= VW + 8:
			var w := (x2 + off) / pxPerRad
			pts.append(Vector2(x2, hy - (base + amp * (0.5 + 0.5 * sin(w * f1 + ph)) + amp * 0.5 * sin(w * f2 + ph * 2))))
			x2 += 8.0
		pts.append(Vector2(VW + 8, hy + 2))
		_fill_strip(ci, pts, colh)
	var span := TAU * pxPerRad
	var tc := css(String(M.map.trees))
	for i in 48:
		var x3 := fposmod(i * span / 48 - off, span)
		if x3 < VW + 20:
			var s := 6.0 + (i * 13) % 7
			ci.draw_colored_polygon(A.ell_pts(Vector2(x3, hy - s * 0.6), s + 1, s + 1, 20), Color(20 / 255.0, 50 / 255.0, 20 / 255.0, 0.35))
			ci.draw_colored_polygon(A.ell_pts(Vector2(x3, hy - s * 0.6), s, s, 20), tc)
			ci.draw_colored_polygon(A.ell_pts(Vector2(x3 - s * 0.3, hy - s * 0.95), s * 0.4, s * 0.3, 12), Color(1, 1, 1, 0.15))

static func _qb(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)

static func _hex(s: String) -> Array:
	var c := Color(s)
	return [c.r * 255, c.g * 255, c.b * 255]

func _fill_strip(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	# một dải đồi: cột dọc từ đường viền xuống chân trời (đa giác lõm, chia thành tứ giác)
	var base := pts[0].y
	var P := PackedVector2Array()
	var I := PackedInt32Array()
	for i in range(1, pts.size() - 1):
		P.append(pts[i])
		P.append(Vector2(pts[i].x, base))
	for i in range(0, P.size() / 2 - 1):
		var q := i * 2
		I.append_array([q, q + 2, q + 1, q + 1, q + 2, q + 3])
	if I.size():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), I, P, PackedColorArray([col]))

# ------------------------------------------------------------------ cảnh + gà (drawWorld)
var _keys := PackedFloat64Array()
var _items: Array = []

func _push(z: float, item: Array) -> void:
	var i := _items.size()
	_items.append(item)
	_keys.append(floor(-z * 64.0) * 8192.0 + i)

func _world(ci: CanvasItem) -> void:
	if R == null:
		return
	var sh: float = (randf() - 0.5) * R.shake * 14 if R.shake > 0 else 0.0
	ci.draw_set_transform(Vector2(sh, 0))
	# sương chân trời phủ lên đầu mặt đất
	var hz: Array = M.map.haze
	var fog: float = M.map.fog
	var fogH := VH * (0.12 + 0.3 * fog)
	var hzc := _rgb(hz)
	if fog > 0:
		_vgrad(ci, 0, HOR, VW, HOR + fogH, [[0.0, hzc], [0.45, _rgb(hz, fog * 0.55)], [1.0, _rgb(hz, 0)]])
	else:
		_vgrad(ci, 0, HOR, VW, HOR + fogH, [[0.0, hzc], [1.0, _rgb(hz, 0)]])
	_items = []
	_keys = PackedFloat64Array()
	var halfW := VW / 2 / F
	var fz := 2800.0 - 1500.0 * fog
	tags = []
	_life_step()
	# cảnh vật
	var ds: Array = M.decor
	for di in ds.size():
		var d: Dictionary = ds[di]
		var p := proj(d.x, d.y, 0)
		if p.is_empty() or p[4] >= ZFAR or absf(p[5]) >= p[4] * halfW + float(d.get("w", 20)) * 2 + 40:
			continue
		var a := minf(1.0 - (p[4] - fz) / 1000.0 if p[4] > fz else 1.0, clampf((p[4] - 50) / 150.0, 0, 1))
		if a <= 0:
			continue
		_push(p[4] + float(d.get("zb", 0)), [0, di, p, a])
	# cỏ ven đường
	var tf: Array = M.tufts
	for ti in tf.size():
		var t: Dictionary = tf[ti]
		var p := proj(t.x, t.y, 0)
		if p.is_empty() or p[4] > 1000 or p[4] < CDIST * 0.45 or absf(p[5]) > p[4] * halfW + 30:
			continue
		_push(p[4], [1, ti, p])
	# cọc rào
	var ps: Array = M.posts
	for qi in ps.size():
		var q: Dictionary = ps[qi]
		var p := proj(q.x, q.y, 0)
		if p.is_empty() or p[4] >= ZFAR or absf(p[5]) >= p[4] * halfW + 50 or p[4] > 2200:
			continue
		_push(p[4], [2, qi, p])
	# dốc rơm
	for rp in M.RAMPS:
		var c := proj(rp.x, rp.y, 0)
		if c.is_empty() or c[4] >= ZFAR or absf(c[5]) >= c[4] * halfW + 120:
			continue
		_push(c[4] + 10, [3, rp, c])
	# bó rơm chắn đường
	for b in M.BASKETS:
		var p := proj(b.x, b.y, 0)
		if p.is_empty() or p[4] >= ZFAR or absf(p[5]) >= p[4] * halfW + 70:
			continue
		var al := clampf((p[4] - CDIST * 0.24) / (CDIST * 0.1), 0, 1)
		if al <= 0.04:
			continue
		_push(p[4], [4, b, p, al])
	# vịt qua đường
	for d in R.ducks:
		var p := proj(d.x, d.y, d.h)
		if p.is_empty() or p[4] >= ZFAR or absf(p[5]) >= p[4] * halfW + 60:
			continue
		_push(p[4], [5, d, p])
	# gà
	for r in R.racers:
		var p := proj(r.fallX if r.fallT > 0 else r.x, r.fallY if r.fallT > 0 else r.y, 0)
		if p.is_empty() or p[4] >= ZFAR or absf(p[5]) >= p[4] * halfW + 70:
			continue
		var al := 1.0 if r.isPlayer else clampf((p[4] - CDIST * 0.24) / (CDIST * 0.1), 0, 1)
		if not r.isPlayer:
			r.occA = r.occA + (al - r.occA) * minf(1.0, 0.016 * 9)
			al = r.occA
		if al <= 0.04:
			continue
		_push(p[4], [6, r, p, al])
	# bụi
	for q in R.parts:
		var p := proj(q.x, q.y, q.h)
		if p.is_empty() or p[4] >= ZFAR or absf(p[5]) >= p[4] * halfW + 45 or p[4] < CDIST * 0.4:
			continue
		_push(p[4], [7, q, p])
	_arch()
	_keys.sort()
	for k in _keys:
		var it: Array = _items[int(fposmod(k, 8192.0))]
		match int(it[0]):
			0: _decor(ci, M.decor[it[1]], it[2], it[3])
			1: _tuft(ci, M.tufts[it[1]], it[2])
			2: _post(ci, M.posts[it[1]], it[2])
			3: _ramp(ci, it[1], it[2])
			4: _sheaf(ci, it[1], it[2], it[3])
			5: _duck(ci, it[1], it[2])
			6: _racer(ci, it[1], it[2], it[3])
			7: _part(ci, it[1], it[2])
			8: it[1].call(ci)
	_tags(ci)
	ci.draw_set_transform(Vector2.ZERO)
	# viền tối kéo mắt vào giữa đường
	_vignette(ci)

func _vignette(ci: CanvasItem) -> void:
	var c := Vector2(VW / 2, VH * 0.52)
	var r0 := minf(VW, VH) * 0.38
	var r1 := Vector2(VW, VH).length() * 0.62
	var n := 48
	var a0 := Color(30 / 255.0, 18 / 255.0, 8 / 255.0, 0)
	var a1 := Color(30 / 255.0, 18 / 255.0, 8 / 255.0, 0.3)
	for i in n:
		var t0 := TAU * i / n
		var t1 := TAU * (i + 1) / n
		var d0 := Vector2(cos(t0), sin(t0))
		var d1 := Vector2(cos(t1), sin(t1))
		ci.draw_polygon(PackedVector2Array([c + d0 * r0, c + d1 * r0, c + d1 * r1, c + d0 * r1]), PackedColorArray([a0, a0, a1, a1]))
		# ngoài vòng r1: tô đặc tới góc màn hình
		ci.draw_colored_polygon(PackedVector2Array([c + d0 * r1, c + d1 * r1, c + d1 * r1 * 2.0, c + d0 * r1 * 2.0]), a1)

func _shadow(ci: CanvasItem, x: float, y: float, rx_: float, ry_: float, col: Color) -> void:
	ci.draw_colored_polygon(A.ell_pts(Vector2(x, y), maxf(0.1, rx_), maxf(0.1, ry_), 20), col)

func gsq(p: Array) -> float:
	return minf(0.6, CH / p[4])

# hình cảnh: chân ở (x,y), k = css px trên 1 px của hình, fl lật ngang, sw nghiêng (lắc theo gió), al độ đục
func _img(ci: CanvasItem, name: String, x: float, y: float, k: float, fl := false, sw := 0.0, al := 1.0) -> void:
	var t = RS.spr(name)
	if t == null:
		return
	var m = RS.sm(name)
	var w: float = float(m.get("w", t.get_width())) * k
	var h: float = float(m.get("h", t.get_height())) * k
	var ax: float = float(m.get("ax", 0)) * k
	var ay: float = float(m.get("ay", 0)) * k
	var xf := Transform2D(Vector2(1, 0), Vector2(sw, 1), Vector2(x, y))
	if fl:
		xf = xf * Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2.ZERO)
	ci.draw_set_transform_matrix(xf)
	ci.draw_texture_rect(t, Rect2(-ax, -ay, w, h), false, Color(1, 1, 1, al))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

func _right(hd: float) -> bool:
	return cos(hd) * rx + sin(hd) * ry >= 0

func _sway(d: Dictionary, amp: float) -> float:
	return sin(clock * 1.3 + float(d.x) * 0.013 + float(d.get("ph", 0))) * amp + sin(clock * 2.9 + float(d.y) * 0.02) * amp * 0.3

func _life_shadow(ci: CanvasItem, p: Array, r: float, a := 0.22, al := 1.0) -> void:
	_shadow(ci, p[0], p[2], r * p[3], r * p[3] * gsq(p), Color(30 / 255.0, 40 / 255.0, 10 / 255.0, a * al))

func _decor(ci: CanvasItem, d: Dictionary, p: Array, a: float) -> void:
	var t: String = d.t
	var s: float = p[3]
	var k: float = float(d.get("k", 1))
	var v: float = float(d.get("v", 0.5))
	var fl: bool = d.get("fl", false)
	var ph: float = float(d.get("ph", 0))
	match t:
		"barn", "coop", "hut", "house", "stall", "stilt", "gate":
			_model(ci, d, a, s)
		"crowd":
			var iv := int(v)
			var hot := 1.35 if R.player != null and Vector2(R.player.x - d.x, R.player.y - d.y).length() < 420 else 1.0
			var f := 0 if fposmod(clock * RATE[LOOK_ACT[iv]] * hot + ph, 1.0) < 0.5 else 1
			_life_shadow(ci, p, 6.0 if LOOK_KID[iv] else 8.5, 0.22, a)
			_img(ci, "LIFE.people.%d.%d" % [iv, f], p[0], p[2], s * k / LIFE_S, fl, 0, a)
		"dog":
			_life_shadow(ci, p, 9, 0.22, a)
			_img(ci, "LIFE.dog.%d" % (0 if fposmod(clock * 5 + ph, 1.0) < 0.5 else 1), p[0], p[2], s / LIFE_S, fl, 0, a)
		"hen":
			_life_shadow(ci, p, 6, 0.22, a)
			_img(ci, "LIFE.hen.%d" % (1 if fposmod(clock * 0.8 + ph, 1.0) < 0.4 else 0), p[0], p[2], s / LIFE_S, fl, 0, a)
		"chick":
			_life_shadow(ci, p, 3, 0.22, a)
			_img(ci, "LIFE.chick.%d" % (1 if fposmod(clock * 1.3 + ph, 1.0) < 0.4 else 0), p[0], p[2], s / LIFE_S, fl, 0, a)
		"buffalo":
			var up := fposmod(clock / 9.0 + ph, 1.0) < 0.3
			var f2 := not _right(float(d.hd))
			var sc := s * k
			_life_shadow(ci, p, 30, 0.2, a)
			_img(ci, "LIFE.buffalo.%d" % (1 if up else 0), p[0], p[2], sc / LIFE_S, f2, 0, a)
			if p[4] < 1100:
				var dir := -1.0 if f2 else 1.0
				for n in 2:
					var u := fposmod(clock * 0.42 + n * 0.5 + ph, 1.0)
					var na := (1 - u) * minf(1.0, u * 5)
					if na < 0.05:
						continue
					_img(ci, "LIFE.note.%d" % n, p[0] + dir * (6.4 + u * 7 + sin(u * 9 + n) * 2) * sc, p[2] - (43 + u * 20) * sc, sc * 0.9 / LIFE_S, false, 0, a * na)
		"egret":
			if float(d.get("fly", -1)) >= 0:
				var q := proj(d.x, d.y, float(d.get("h", 0)))
				if q.is_empty():
					return
				var g := clampf(1.0 - float(d.get("h", 0)) / 160.0, 0, 1)
				if g > 0.05:
					_life_shadow(ci, p, 6 * g, 0.18 * g, a)
				_img(ci, "LIFE.egretFly.%d" % [0, 1, 2, 1][int(floor(clock * 8 + ph)) % 4], q[0], q[1], q[3] * k / LIFE_S, not _right(float(d.hd)), 0, a)
				return
			_life_shadow(ci, p, 5, 0.22, a)
			_img(ci, "LIFE.egret.%d" % (1 if fposmod(clock * 0.45 + ph, 1.0) < 0.28 else 0), p[0], p[2], s * k / LIFE_S, not _right(float(d.hd)), 0, a)
		"planter":
			_img(ci, "LIFE.planter.%d" % (0 if fposmod(clock * 0.55 + ph, 1.0) < 0.5 else 1), p[0], p[2], s * k / LIFE_S, not _right(float(d.hd)), 0, a)
		"fire":
			_smoke(ci, d, 0, 26, true, a)
			_life_shadow(ci, p, 22, 0.15, a)
			_img(ci, "LIFE.fire.%d" % (int(floor(clock * 9 + ph)) % 3), p[0], p[2], s * 1.7 / LIFE_S, false, 0, a)
		"banana", "cau", "nipa":
			var u0: float = float(RS.sm("LIFE.%s.0" % t).get("u", LIFE_S))
			if t == "banana":
				_life_shadow(ci, p, 14 * k, 0.16, a)
			elif t == "cau":
				_life_shadow(ci, p, 5, 0.16, a)
			_img(ci, "LIFE.%s.%d" % [t, int(v)], p[0], p[2], s * k / maxf(0.01, u0), fl, _sway(d, 0.03 if t == "cau" else 0.035), a)
		"lotus":
			_img(ci, "LIFE.lotus.%d" % int(v), p[0], p[2], s * k / LIFE_S, fl, _sway(d, 0.02), a)
		"ducks":
			_ducks_draw(ci, d, a)
		"tree":
			var vi := 0 if v < 0.5 else (1 if v <= 0.7 else 2)
			_img(ci, "D.tree.%d" % vi, p[0], p[1], s * k / 6.0, false, sin(clock * 1.3 + float(d.x) * 0.011) * 0.03 * 0.7, a)
		"palm":
			_img(ci, "D.palm.%d" % clampi(int(round(v * 8)), 0, 8), p[0], p[1], s * k / 6.0, false, sin(clock * 1.1 + float(d.x) * 0.013) * 3.0 / 130.0, a)
		"bamboo":
			_img(ci, "D.bamboo.%d" % clampi(int(round(v * 10)), 0, 9), p[0], p[1], s * k / 6.0, false, sin(clock * 1.5 + float(d.x) * 0.017) * 0.03, a)
		"pine":
			_img(ci, "D.pine.%d" % (0 if v < 0.5 else 1), p[0], p[1], s * k / 6.0, false, sin(clock * 1.2 + float(d.x) * 0.009) * 0.015, a)
		_:
			var nm := "D.%s.0" % t
			if RS.spr(nm) != null:
				_img(ci, nm, p[0], p[1], s * k / 6.0, false, 0, a)

func _smoke(ci: CanvasItem, d: Dictionary, h0: float, h1: float, dark: bool, al: float) -> void:
	var wx := cos(float(M.map.sun) + 1.9)
	var wy := sin(float(M.map.sun) + 1.9)
	var n := 7
	for k in n:
		var u := fposmod(clock * 0.1 + float(k) / n + float(d.get("ph", 0)), 1.0)
		var h := h0 + h1 + u * 150
		var dr := u * u * 70
		var q := proj(float(d.x) + wx * dr, float(d.y) + wy * dr, h)
		if q.is_empty():
			continue
		var a := (1 - u) * minf(1.0, u * 7) * (0.7 if dark else 0.5)
		if a < 0.02:
			continue
		var nm := ("LIFE.puffD.%d" if dark else "LIFE.puff.%d") % (k % 3)
		var w: float = float(RS.sm(nm).get("w", 40))
		var r = (5 + u * 22) * q[3]
		_img(ci, nm, q[0], q[1], r * 2 / (w * 0.7), k % 2 == 0, 0, a * al)

# vịt bơi + cò bay (lifeStep của web)
var _life_t := -1.0
func _life_step() -> void:
	var dt := clampf(clock - _life_t, 0, 0.1) if _life_t >= 0 else 0.0
	_life_t = clock
	for d in M.decor:
		if not d.get("mv", false):
			continue
		if d.t == "ducks":
			if not d.has("list"):
				var rg := _rng(int(d.seed))
				var L := []
				for m in int(d.n):
					L.append({"m": m, "ph": rg.call(), "j": (rg.call() - 0.5) * 7, "b": m * 8 + (rg.call() - 0.5) * 3, "x": 0.0, "y": 0.0, "hd": 0.0})
				d.list = L
			if d.get("pond", false) and M.POND != null:
				var P = M.POND
				for q in d.list:
					var thq: float = float(d.s0) + clock * float(d.v) - q.b / (float(P.rx) * 0.55)
					q.x = float(P.x) + cos(thq) * float(P.rx) * 0.55 * (1 + q.j / 60.0)
					q.y = float(P.y) + sin(thq) * float(P.ry) * 0.55 * (1 + q.j / 60.0)
					q.hd = thq + PI / 2
			else:
				var w: Dictionary = M.WATER[int(d.wi)]
				var len_: float = float(d.b) - float(d.a)
				var u := fposmod(float(d.s0) + clock * float(d.v), 2 * len_)
				var fw := u < len_
				var s := float(d.a) + u if fw else float(d.b) - (u - len_)
				for q in d.list:
					var ss: float = s + (-q.b if fw else q.b)
					var wa := _w_at(w, clampf(ss, float(d.a) - 30, float(d.b) + 30))
					var o: float = float(d.o) + q.j
					q.x = wa[0] - wa[3] * o
					q.y = wa[1] + wa[2] * o
					q.hd = atan2(wa[3], wa[2]) + (0.0 if fw else PI)
			d.x = d.list[0].x
			d.y = d.list[0].y
		elif d.t == "egret":
			if float(d.fly) < 0:
				if dt > 0 and R.state != "menu":
					for r in R.racers:
						var dx: float = float(d.hx) - r.x
						var dy: float = float(d.hy) - r.y
						var l := sqrt(dx * dx + dy * dy)
						if l < 190:
							d.fly = 0.0
							d.ax = dx / maxf(l, 0.001)
							d.ay = dy / maxf(l, 0.001)
							d.T = randf_range(4.0, 6.5)
							d.side = -1.0 if randf() < 0.5 else 1.0
							break
			else:
				d.fly = float(d.fly) + dt
				var u2: float = float(d.fly) / float(d.T)
				if u2 >= 1:
					d.fly = -1.0
					d.x = d.hx
					d.y = d.hy
					d.h = 0.0
					continue
				var sn := sin(PI * u2)
				var out := 260.0 * sn
				var lat: float = float(d.side) * 150 * (1 - cos(TAU * u2)) * 0.5
				var x: float = float(d.hx) + float(d.ax) * out - float(d.ay) * lat
				var y: float = float(d.hy) + float(d.ay) * out + float(d.ax) * lat
				d.hd = atan2(y - float(d.y), x - float(d.x))
				d.x = x
				d.y = y
				d.h = pow(sn, 0.6) * 110

func _w_at(w: Dictionary, s: float) -> Array:
	var c: Array = w._c
	s = clampf(s, 0, float(w._L))
	var i := 1
	while i < c.size() - 1 and float(c[i]) < s:
		i += 1
	var p: Array = w.pts[i - 1]
	var q: Array = w.pts[i]
	var l := maxf(0.001, float(c[i]) - float(c[i - 1]))
	var u := (s - float(c[i - 1])) / l
	var tx := (float(q[0]) - float(p[0])) / l
	var ty := (float(q[1]) - float(p[1])) / l
	return [lerpf(p[0], q[0], u), lerpf(p[1], q[1], u), tx, ty]

static func _rng(seed: int) -> Callable:
	# mulberry32 của web (rng), cho đàn vịt giống hệt
	var st := [seed]
	return func() -> float:
		var s: int = (st[0] + 0x6D2B79F5) & 0xffffffff
		st[0] = s
		var t: int = _imul(s ^ (s >> 15), 1 | s)
		t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xffffffff) ^ t
		return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

static func _imul(a: int, b: int) -> int:
	return ((a & 0xffffffff) * (b & 0xffffffff)) & 0xffffffff

func _ducks_draw(ci: CanvasItem, d: Dictionary, al: float) -> void:
	if not d.has("list"):
		return
	var L := []
	for q in d.list:
		var r := proj(q.x, q.y, 0)
		if not r.is_empty():
			L.append([r, q])
	L.sort_custom(func(a, b): return a[0][4] > b[0][4])
	for e in L:
		var r: Array = e[0]
		var q: Dictionary = e[1]
		_wake(ci, q, 9, 3.6, al)
		_img(ci, "LIFE.duck.%d" % (1 if fposmod(clock * 0.7 + q.ph, 1.0) < 0.2 else 0), r[0], r[2] + sin(clock * 3 + q.ph * 9) * 0.3 * r[3], r[3] / LIFE_S, not _right(q.hd), 0, al)

func _wake(ci: CanvasItem, q: Dictionary, len_: float, wd: float, al: float) -> void:
	var c := cos(float(q.hd))
	var s := sin(float(q.hd))
	for k in 3:
		var u := fposmod(clock * 0.8 + k / 3.0 + float(q.get("ph", 0)), 1.0)
		var b := len_ * (0.2 + u)
		var o := wd * (0.5 + u * 1.4)
		var Ap := proj(q.x - c * len_ * 0.2, q.y - s * len_ * 0.2, 0)
		var Bp := proj(q.x - c * b - s * o, q.y - s * b + c * o, 0)
		var Cp := proj(q.x - c * b + s * o, q.y - s * b - c * o, 0)
		if Ap.is_empty() or Bp.is_empty() or Cp.is_empty():
			continue
		ci.draw_polyline(PackedVector2Array([Vector2(Bp[0], Bp[2]), Vector2(Ap[0], Ap[2]), Vector2(Cp[0], Cp[2])]), Color(235 / 255.0, 248 / 255.0, 252 / 255.0, 0.75 * (1 - u) * 0.8 * al), maxf(0.6, 0.5 * Ap[3]), true)

# ---- nhà mô hình 3D (drawModel): mặt xa trước, viền mực mờ, decal, chữ trên tường
func _model(ci: CanvasItem, d: Dictionary, alpha: float, s: float) -> void:
	var mm = d.get("_m")
	if mm == null:
		for m in M.models:
			if int(m.i) == M.decor.find(d):
				mm = m
				break
		d["_m"] = mm if mm != null else {}
	if mm == null or mm.is_empty():
		return
	var vis := []
	for f in mm.f:
		var pr := PackedVector2Array()
		var zs := 0.0
		var ok := true
		for q in f.w:
			var p := proj(q[0], q[1], q[2])
			if p.is_empty():
				ok = false
				break
			pr.append(Vector2(p[0], p[1]))
			zs += p[4]
		if not ok:
			continue
		var q0: Array = f.w[0]
		var n: Array = f.n
		var front: bool = (cx - q0[0]) * n[0] + (cy - q0[1]) * n[1] + (CH - q0[2]) * n[2] > 0
		if not front and not f.two:
			continue
		vis.append([zs / pr.size(), pr, f, front])
	vis.sort_custom(func(a, b): return a[0] > b[0])
	var ink := Color(40 / 255.0, 25 / 255.0, 10 / 255.0, 0.38 * alpha)
	var lw := maxf(0.6, 1.1 * s)
	for v in vis:
		var f: Dictionary = v[2]
		var col := css(String(f.col) if v[3] else String(f.under if f.under != null else f.col))
		col.a = alpha
		ci.draw_colored_polygon(v[1], col)
		var cl: PackedVector2Array = v[1].duplicate()
		cl.append(cl[0])
		ci.draw_polyline(cl, ink, lw, true)
		if v[3]:
			for dc in f.dec:
				var pr2 := PackedVector2Array()
				var ok2 := true
				for q in dc.w:
					var p := proj(q[0], q[1], q[2])
					if p.is_empty():
						ok2 = false
						break
					pr2.append(Vector2(p[0], p[1]))
				if not ok2:
					continue
				var c2 := css(String(dc.col))
				c2.a = alpha
				ci.draw_colored_polygon(pr2, c2)
				if dc.txt != null:
					var a2 := pr2[0]
					var b2 := pr2[1]
					var d2 := pr2[3]
					if (b2.x - a2.x) * (d2.y - a2.y) - (b2.y - a2.y) * (d2.x - a2.x) < 0:
						a2 = pr2[1]
						b2 = pr2[0]
						d2 = pr2[2]
					var xf := Transform2D((b2 - a2) / 100.0, (d2 - a2) / 26.0, a2)
					var tc := css(String(dc.tc))
					tc.a = alpha
					_text_xf(ci, String(dc.txt), 50, 14, 19, tc, xf)

func _text_xf(ci: CanvasItem, s: String, x: float, y: float, fs: float, col: Color, xf: Transform2D) -> void:
	# chữ đặt trong một hình bình hành (bảng tên trên tường): đo ở cỡ thật rồi kéo vào khung
	var f := A.font(800)
	var px := 38
	var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var asc := f.get_ascent(px)
	var des := f.get_descent(px)
	var k := fs / px
	ci.draw_set_transform_matrix(xf * Transform2D(0, Vector2(k, k), 0, Vector2(x, y)))
	ci.draw_string(f, Vector2(-sw / 2, (asc - des) * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

func _tuft(ci: CanvasItem, t: Dictionary, p: Array) -> void:
	var c: float = t.c
	var nm := ""
	var tt := int(t.t)
	if tt == 2:
		nm = "T.2.0"
	elif tt == 1:
		nm = "T.1.%d" % clampi(int(floor(c * 4)), 0, 3)
	else:
		nm = "T.0.%d" % (0 if c < 0.5 else 1)
	var sw := sin(clock * 2 + float(t.ph)) * 2.0 / (30.0 if tt == 2 else 12.0) * 0.5
	_img(ci, nm, p[0], p[2], p[3] * float(t.s) / 6.0, false, sw)

func _post(ci: CanvasItem, q: Dictionary, p: Array) -> void:
	var wood: bool = q.wood
	var bam: bool = q.bamboo
	var s: float = p[3]
	var pw := (1.8 if bam else 2.6) * s
	var ph := (30.0 if bam else (26.0 if wood else 24.0)) * s
	var col := Color("#b8b04a") if bam else (Color("#5a3618") if wood else Color("#7a5028"))
	var dk := Color("#7f7a2a") if bam else (Color("#3a220c") if wood else Color("#4e3016"))
	var x: float = p[0]
	var y: float = p[1]
	ci.draw_rect(Rect2(x - pw, y - ph, pw * 2, ph), col)
	ci.draw_rect(Rect2(x + pw * 0.15, y - ph, pw * 0.85, ph), dk)
	ci.draw_colored_polygon(A.ell_pts(Vector2(x, y - ph), pw, pw * 0.45, 12), Color("#d8d070") if bam else Color("#a77a46"))
	if bam:
		for f in [0.35, 0.7]:
			ci.draw_rect(Rect2(x - pw, y - ph * f - 0.6 * s, pw * 2, 1.2 * s), dk)
	var pi: int = int(q.prev)
	if pi >= 0:
		var pq: Dictionary = M.posts[pi]
		var pp := proj(pq.x, pq.y, 0)
		if not pp.is_empty():
			var hs := [27.0] if bam else ([11.0, 23.0] if wood else [9.0, 19.0])
			for h in hs:
				var rc := Color("#a8a03a") if bam else (Color("#6b4423") if wood else Color("#8e6034"))
				ci.draw_line(Vector2(x, y - h * s), Vector2(pp[0], pp[1] - h * pp[3]), rc, maxf(1, (3.5 if wood else 2.6) * s), true)
				ci.draw_line(Vector2(x, y - (h + 0.9) * s), Vector2(pp[0], pp[1] - (h + 0.9) * pp[3]), Color(1, 230 / 255.0, 170 / 255.0, 0.35), maxf(0.5, 0.8 * s), true)

func _sheaf(ci: CanvasItem, b: Dictionary, p: Array, al: float) -> void:
	_shadow(ci, p[0], p[2], 24 * p[3], 24 * p[3] * gsq(p), Color(30 / 255.0, 40 / 255.0, 10 / 255.0, 0.3 * al))
	var t = RS.spr("PROP.sheaves.%d" % (int(b.i) % 3))
	if t == null:
		return
	var k: float = p[3] / 8.0
	ci.draw_texture_rect(t, Rect2(p[0] - 180 * k, p[2] - 348 * k, 360 * k, 384 * k), false, Color(1, 1, 1, al))

func _duck(ci: CanvasItem, d: Dictionary, p: Array) -> void:
	if not d.fly:
		_shadow(ci, p[0], p[2], 10 * p[3], 10 * p[3] * gsq(p), Color(30 / 255.0, 40 / 255.0, 10 / 255.0, 0.25))
	var head := atan2(M.NY[d.i] * d.dir, M.NX[d.i] * d.dir)
	_bird(ci, "npc", R.wrapA(head - R.cam.th), d.run, d.spd if d.has("spd") else 200.0, p[0], p[1], p[3] * 0.62, 1.0, 0.0)

# ---- dốc rơm (drawRamp): bóng, mặt trước, mặt dốc theo dải, hai hàng bó rơm hai bên, cờ đỏ
func _sun_on(n: Array) -> float:
	return 0.58 + 0.42 * maxf(0, n[0] * M.SUN_L[0] + n[1] * M.SUN_L[1] + n[2] * M.SUN_L[2])

func _cam_facing(px: float, py: float, ph: float, nx: float, ny: float, nz: float) -> bool:
	return nx * (cx - px) + ny * (cy - py) + nz * (CH - ph) > 0

func _tex_quad(ci: CanvasItem, tex: Texture2D, sx: float, sy: float, sw: float, sh: float, P: Array, al := 1.0) -> void:
	# hình phủ lên tứ giác [a, b, e, d] (trái trên, phải trên, phải dưới, trái dưới), chia lưới cho đúng phối cảnh gần đúng
	if tex == null:
		return
	var W := float(tex.get_width())
	var H := float(tex.get_height())
	var a := Vector2(P[0][0], P[0][1])
	var b := Vector2(P[1][0], P[1][1])
	var e := Vector2(P[2][0], P[2][1])
	var d := Vector2(P[3][0], P[3][1])
	var n := 4
	for j in n:
		for i in n:
			var u0 := float(i) / n
			var u1 := float(i + 1) / n
			var v0 := float(j) / n
			var v1 := float(j + 1) / n
			var q := PackedVector2Array([_bil(a, b, e, d, u0, v0), _bil(a, b, e, d, u1, v0), _bil(a, b, e, d, u1, v1), _bil(a, b, e, d, u0, v1)])
			var uv := PackedVector2Array([Vector2((sx + sw * u0) / W, (sy + sh * v0) / H), Vector2((sx + sw * u1) / W, (sy + sh * v0) / H), Vector2((sx + sw * u1) / W, (sy + sh * v1) / H), Vector2((sx + sw * u0) / W, (sy + sh * v1) / H)])
			ci.draw_polygon(q, PackedColorArray([Color(1, 1, 1, al), Color(1, 1, 1, al), Color(1, 1, 1, al), Color(1, 1, 1, al)]), uv, tex)

static func _bil(a: Vector2, b: Vector2, e: Vector2, d: Vector2, u: float, v: float) -> Vector2:
	return a.lerp(b, u).lerp(d.lerp(e, u), v)

func _poly_of(P: Array) -> PackedVector2Array:
	var o := PackedVector2Array()
	for q in P:
		o.append(Vector2(q[0], q[1]))
	return o

func _ramp(ci: CanvasItem, rp: Dictionary, c: Array) -> void:
	var i: int = rp.i
	var w: float = M.WD[i]
	var tx := cos(M.TA[i])
	var ty := sin(M.TA[i])
	var L := 28.0
	var H := 24.0
	var RH := 7.0
	var rw := minf(0.12, 9.0 / w)
	var o0: float = rp.o0
	var o1: float = rp.o1
	var s0 := o0 + rw
	var s1 := o1 - rw
	var cs: float = c[3]
	var lw := maxf(0.6, 0.16 * cs)
	var ink := Color(90 / 255.0, 58 / 255.0, 20 / 255.0, 0.75)
	var Wf := func(al: float, o: float) -> Vector2: return Vector2(M.PX[i] + tx * al + M.NX[i] * o * w, M.PY[i] + ty * al + M.NY[i] * o * w)
	var pt := func(al: float, o: float, h: float) -> Array:
		var q: Vector2 = Wf.call(al, o)
		return proj(q.x, q.y, h)
	var ccx: float = M.PX[i] + M.NX[i] * (o0 + o1) / 2 * w
	var ccy: float = M.PY[i] + M.NY[i] * (o0 + o1) / 2 * w
	# bóng
	var k := (H + RH) / float(M.SUN_L[2])
	var sx := -float(M.SUN_L[0]) * k
	var sy := -float(M.SUN_L[1]) * k
	var G := [Wf.call(-L, o0), Wf.call(-L, o1), Wf.call(L, o0), Wf.call(L, o1)]
	for o in [o0, o1]:
		var a: Vector2 = Wf.call(L, o)
		var b: Vector2 = Wf.call(-L, o)
		var kb := RH / (H + RH)
		G.append(a + Vector2(sx, sy))
		G.append(b + Vector2(sx * kb, sy * kb))
	var hull := Geometry2D.convex_hull(PackedVector2Array(G))
	var S := PackedVector2Array()
	var ok := true
	for q in hull:
		var p := proj(q.x, q.y, 0)
		if p.is_empty():
			ok = false
			break
		S.append(Vector2(p[0], p[1]))
	if ok and S.size() > 2:
		ci.draw_colored_polygon(S, Color(30 / 255.0, 40 / 255.0, 10 / 255.0, 0.3))
	var face := func(P: Array, img: String, fsx: float, fsy: float, fsw: float, fsh: float, n: Array, dark: float) -> void:
		for q in P:
			if q.is_empty():
				return
		var t = RS.spr(img)
		_tex_quad(ci, t, fsx, fsy, fsw, fsh, P)
		var lit := _sun_on(n) * dark
		var poly := _poly_of(P)
		if lit < 0.99:
			ci.draw_colored_polygon(poly, Color(40 / 255.0, 22 / 255.0, 6 / 255.0, (1 - lit) * 0.85))
		var cl := poly.duplicate()
		cl.append(cl[0])
		ci.draw_polyline(cl, ink, lw, true)
	var sl := sqrt(4 * L * L + H * H)
	var sn := [-tx * H / sl, -ty * H / sl, 2 * L / sl]
	if _cam_facing(ccx + tx * L, ccy + ty * L, H / 2, tx, ty, 0):
		face.call([pt.call(L, o0, H + RH), pt.call(L, o1, H + RH), pt.call(L, o1, 0), pt.call(L, o0, 0)], "PROP.baleEnd", 0, 0, 256, 256, [tx, ty, 0], 0.9)
	if _cam_facing(ccx, ccy, H / 2, sn[0], sn[1], sn[2]):
		var a0: Array = pt.call(-L, s0, 0)
		var b0: Array = pt.call(L, s0, H)
		if not a0.is_empty() and not b0.is_empty():
			var n := maxi(2, mini(8, int(round(absf(a0[1] - b0[1]) / 16.0))))
			var lit := _sun_on(sn)
			var st = RS.spr("PROP.straw")
			for kk in n:
				var al0 := -L + 2 * L * kk / n
				var al1 := -L + 2 * L * (kk + 1) / n
				var P := [pt.call(al1, s0, H * (kk + 1) / n), pt.call(al1, s1, H * (kk + 1) / n), pt.call(al0, s1, H * kk / n), pt.call(al0, s0, H * kk / n)]
				var bad := false
				for q in P:
					if q.is_empty():
						bad = true
				if bad:
					continue
				_tex_quad(ci, st, 0, 512.0 * (n - kk - 1) / n, 256, 512.0 / n, P)
				if lit < 0.99:
					ci.draw_colored_polygon(_poly_of(P), Color(40 / 255.0, 22 / 255.0, 6 / 255.0, (1 - lit) * 0.85))
			var rg := _rng(i * 7 + 3)
			for kk in 16:
				var o: float = s0 + (s1 - s0) * (kk + rg.call()) / 16.0
				var q0: Array = pt.call(-L + 3 + rg.call() * 4, o, (3 + rg.call() * 4) * H / (2 * L))
				var q1: Array = pt.call(-L - 3 - rg.call() * 6, o + (rg.call() - 0.5) * 0.06, 0)
				var lwr: float = maxf(0.6, (0.5 + rg.call() * 0.5) * cs)
				if q0.is_empty() or q1.is_empty():
					continue
				ci.draw_line(Vector2(q0[0], q0[1]), Vector2(q1[0], q1[1]), Color(STRAW_C[kk % STRAW_C.size()]), lwr, true)
			var l0: Array = pt.call(L, s0, H)
			var l1: Array = pt.call(L, s1, H)
			if not l0.is_empty() and not l1.is_empty():
				ci.draw_line(Vector2(l0[0], l0[1]), Vector2(l1[0], l1[1]), Color(1, 236 / 255.0, 170 / 255.0, 0.75), maxf(0.6, 0.35 * cs), true)
	# hai hàng bó rơm, hàng xa trước
	var rails := []
	for r in [[o0, s0, -1.0], [s1, o1, 1.0]]:
		var m: Vector2 = Wf.call(0, (r[0] + r[1]) / 2)
		rails.append([r[0], r[1], r[2], Vector2(m.x - cx, m.y - cy).length()])
	rails.sort_custom(func(a, b): return a[3] > b[3])
	for rr in rails:
		var a: float = rr[0]
		var b: float = rr[1]
		var sg: float = rr[2]
		var mo := (a + b) / 2
		var mx: float = M.PX[i] + M.NX[i] * mo * w
		var my: float = M.PY[i] + M.NY[i] * mo * w
		var out := a if sg < 0 else b
		var inn := b if sg < 0 else a
		var nO := [M.NX[i] * sg, M.NY[i] * sg, 0.0]
		var nI := [-M.NX[i] * sg, -M.NY[i] * sg, 0.0]
		if _cam_facing(mx - tx * L, my - ty * L, RH / 2, -tx, -ty, 0):
			face.call([pt.call(-L, a, RH), pt.call(-L, b, RH), pt.call(-L, b, 0), pt.call(-L, a, 0)], "PROP.cutEnd", 0, 0, 128, 128, [-tx, -ty, 0], 0.95)
		if _cam_facing(M.PX[i] + M.NX[i] * out * w, M.PY[i] + M.NY[i] * out * w, (H + RH) / 2, nO[0], nO[1], nO[2]):
			face.call([pt.call(-L, out, RH), pt.call(-L, out, 0), pt.call(L, out, 0), pt.call(L, out, H + RH)], "PROP.baleSide", 0, 0, 256, 512, nO, 1.0)
		if _cam_facing(M.PX[i] + M.NX[i] * inn * w, M.PY[i] + M.NY[i] * inn * w, H / 2 + RH, nI[0], nI[1], nI[2]):
			face.call([pt.call(-L, inn, RH), pt.call(-L, inn, 0), pt.call(L, inn, H), pt.call(L, inn, H + RH)], "PROP.baleSide", 0, 0, 256, 512, nI, 0.92)
		if _cam_facing(mx, my, H / 2 + RH, sn[0], sn[1], sn[2]):
			var P := [pt.call(-L, a, RH), pt.call(-L, b, RH), pt.call(L, b, H + RH), pt.call(L, a, H + RH)]
			face.call(P, "PROP.baleSide", 0, 0, 256, 512, sn, 1.05)
			var bad := false
			for q in P:
				if q.is_empty():
					bad = true
			if not bad:
				ci.draw_line(Vector2(P[1][0], P[1][1]), Vector2(P[2][0], P[2][1]), Color(1, 236 / 255.0, 170 / 255.0, 0.6), maxf(0.5, 0.3 * cs), true)
	# cọc tre cờ đỏ để thấy dốc từ xa
	for o in [(o0 + s0) / 2, (s1 + o1) / 2]:
		var a: Array = pt.call(L - 3, o, H + RH)
		var t: Array = pt.call(L - 3, o, H + RH + 24)
		if a.is_empty() or t.is_empty():
			continue
		ci.draw_line(Vector2(a[0], a[1]), Vector2(t[0], t[1]), Color("#8a7a2a"), maxf(1, 1.3 * a[3]), true)
		var fl := sin(clock * 6 + o * 9) * 0.3
		var tip := Vector2(t[0] + (8 + fl * 3) * a[3], t[1] + (3 + fl) * a[3])
		var mid := Vector2(t[0], t[1] + 6 * a[3])
		ci.draw_colored_polygon(PackedVector2Array([Vector2(t[0], t[1]), tip, mid]), Color("#d8392b"))

# ---- cổng xuất phát và dây cờ (drawArch)
func _pole(i: int, o: float, H: float, thick: float, dress: bool) -> Array:
	var x: float = M.PX[i] + M.NX[i] * o
	var y: float = M.PY[i] + M.NY[i] * o
	var b := proj(x, y, 0)
	if b.is_empty() or b[4] > 2600:
		return []
	_push(b[4], [8, func(ci: CanvasItem) -> void:
		var t := proj(x, y, H)
		if t.is_empty():
			return
		var w: float = thick * b[3]
		ci.draw_line(Vector2(b[0], b[1]), Vector2(t[0], t[1]), INK, w + maxf(1.2, 0.7 * b[3]), true)
		ci.draw_line(Vector2(b[0], b[1]), Vector2(t[0], t[1]), Color("#c9b25a"), w, true)
		ci.draw_line(Vector2(b[0] - w * 0.2, b[1]), Vector2(t[0] - w * 0.2, t[1]), Color("#e4d27e"), w * 0.35, true)
		if dress:
			var h := 8.0
			while h < H - 4:
				var q := proj(x, y, h)
				if not q.is_empty():
					var r: float = thick * 0.75 * q[3]
					var a1 := Vector2(q[0] - r, q[1] + r * 0.4)
					var a2 := Vector2(q[0] + r, q[1] - r * 0.5)
					ci.draw_line(a1, a2, INK, maxf(1, 2.6 * q[3]), true)
					ci.draw_line(a1, a2, Color("#6fae3e") if int(h / 7) % 2 else Color("#8cc24e"), maxf(0.6, 1.7 * q[3]), true)
				h += 7.0
		else:
			var h2 := 14.0
			while h2 < H:
				var q := proj(x, y, h2)
				if not q.is_empty():
					ci.draw_line(Vector2(q[0] - w / 2, q[1]), Vector2(q[0] + w / 2, q[1]), Color(90 / 255.0, 70 / 255.0, 20 / 255.0, 0.6), maxf(0.6, 0.5 * q[3]), true)
				h2 += 14.0])
	return b

func _fan(ci: CanvasItem, q: Array, angs: Array, sc: float) -> void:
	for av in angs:
		var nm := "LIFE.archFrond.%d" % int(av[1])
		var t = RS.spr(nm)
		if t == null:
			continue
		var m = RS.sm(nm)
		var k: float = q[3] * sc / float(m.get("u", 6))
		ci.draw_set_transform_matrix(Transform2D(float(av[0]), Vector2(q[0], q[1])))
		ci.draw_texture_rect(t, Rect2(-float(m.ax) * k, -float(m.ay) * k, float(m.w) * k, float(m.h) * k), false)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)

func _arch() -> void:
	var N: int = M.N
	var T := Vector2(cos(M.TA[0]), sin(M.TA[0]))
	var front: bool = (cx - M.PX[0]) * T.x + (cy - M.PY[0]) * T.y > 0
	var w: float = M.WD[0] + 16
	var H := 116.0
	var pa := _pole(0, -w, H, 7, true)
	var pb := _pole(0, w, H, 7, true)
	if not pa.is_empty() and not pb.is_empty():
		var z: float = (pa[4] + pb[4]) / 2 - 1
		_push(z, [8, func(ci: CanvasItem) -> void:
			var P := func(o: float, h: float) -> Array: return proj(M.PX[0] + M.NX[0] * o, M.PY[0] + M.NY[0] * o, h)
			var wl := -w + 4
			var wr := w - 4
			var Aq: Array = P.call(-w, H - 8)
			var Bq: Array = P.call(w, H - 8)
			if not Aq.is_empty() and not Bq.is_empty():
				ci.draw_line(Vector2(Aq[0], Aq[1]), Vector2(Bq[0], Bq[1]), INK, 7 * Aq[3] + 1.4, true)
				ci.draw_line(Vector2(Aq[0], Aq[1]), Vector2(Bq[0], Bq[1]), Color("#c9b25a"), 7 * Aq[3], true)
			var Q := [P.call(wl, H - 12), P.call(wr, H - 12), P.call(wr, H - 40), P.call(wl, H - 40)]
			for q in Q:
				if q.is_empty():
					return
			if front:
				Q = [Q[1], Q[0], Q[3], Q[2]]
			var tex = RS.spr("ARCH")
			if tex != null:
				_tex_quad(ci, tex, 0, 0, tex.get_width(), tex.get_height(), Q)
			var cl := _poly_of(Q)
			cl.append(cl[0])
			ci.draw_polyline(cl, INK, maxf(1, 0.6 * Q[0][3]), true)
			for k in 9:
				var o := -w + k * w / 4
				var q: Array = P.call(o, H - 6)
				if not q.is_empty():
					_fan(ci, q, [[-PI / 2 + (0.5 if k % 2 else -0.5), k % 2]], 0.75)
			var ta: Array = P.call(-w, H)
			var tb: Array = P.call(w, H)
			for qs in [[ta, -1.0], [tb, 1.0]]:
				var q: Array = qs[0]
				var s: float = qs[1]
				if not q.is_empty():
					_fan(ci, q, [[-PI / 2 - s * 1.25, 0], [-PI / 2 - s * 0.75, 1], [-PI / 2 - s * 0.2, 0], [-PI / 2 + s * 0.35, 1], [-PI / 2 - s * 1.75, 1]], 1.05)])
	for di in [-30, -15, 15, 30]:
		var i = (di + N) % N
		if M.BR[i]:
			continue
		var ww: float = M.fen(i) + 8
		var HB := 124.0
		var a := _pole(i, -ww, HB, 3.4, false)
		var b := _pole(i, ww, HB, 3.4, false)
		if a.is_empty() or b.is_empty():
			continue
		_push((a[4] + b[4]) / 2 - 1, [8, func(ci: CanvasItem) -> void:
			var n := 18
			var pts := []
			for k in n + 1:
				var t := float(k) / n
				var o := -ww + 2 * ww * t
				var h := HB - 2 - 16 * 4 * t * (1 - t)
				var q := proj(M.PX[i] + M.NX[i] * o, M.PY[i] + M.NY[i] * o, h)
				if q.is_empty():
					return
				pts.append([o, h, q])
			var line := PackedVector2Array()
			for q in pts:
				line.append(Vector2(q[2][0], q[2][1]))
			ci.draw_polyline(line, Color("#5a4028"), maxf(0.8, 0.5 * pts[0][2][3]), true)
			var tx := cos(M.TA[i])
			var ty := sin(M.TA[i])
			for k in n:
				var p0: Array = pts[k][2]
				var p1: Array = pts[k + 1][2]
				var om: float = (pts[k][0] + pts[k + 1][0]) / 2
				var fl := sin(clock * 5 + k * 1.7 + di) * 4
				var tip := proj(M.PX[i] + M.NX[i] * om + tx * fl, M.PY[i] + M.NY[i] * om + ty * fl, (pts[k][1] + pts[k + 1][1]) / 2 - 9)
				if tip.is_empty():
					continue
				var tri := PackedVector2Array([Vector2(p0[0], p0[1]), Vector2(p1[0], p1[1]), Vector2(tip[0], tip[1])])
				ci.draw_colored_polygon(tri, Color(BUNT[(k + (2 if di > 0 else 0)) % BUNT.size()]))
				tri.append(tri[0])
				ci.draw_polyline(tri, INK, maxf(0.5, 0.32 * p0[3]), true)])

# ---- con đua (birdDraw): bóng, chọn góc vẽ + nhịp chạy, lật ngang phía bên kia
func _racer(ci: CanvasItem, r, p: Array, al: float) -> void:
	var hz: float = r.z if r.z > 0 else r.rampH
	var sink: float = (1.3 - r.fallT) * 30 if r.fallT > 0 else 0.0
	if r.fallT <= 0:
		var k := 1 - hz / 200.0
		_shadow(ci, p[0], p[2], 15 * p[3] * k, 15 * p[3] * minf(0.5, CH / p[4]) * k + 1, Color(30 / 255.0, 40 / 255.0, 10 / 255.0, 0.3 * al))
	var rot := 0.0
	if r.spinT > 0:
		rot += sin(r.spinVis * 0.7) * 0.25
	if r.drift:
		rot += r.drift * 0.05
	var BP: Dictionary = R.bird_pose(r)
	var rel: float = R.wrapA(float(BP.va) + r.spinVis - R.cam.th)
	var y: float = p[2] - hz * p[3] + sink * p[3]
	if sink > 0:
		# rớt nước: cắt phần chìm (khung giới hạn dưới mặt nước)
		pass
	_bird(ci, r.id, rel, r.run, r.spd, p[0], y, p[3], al, rot, r.trickRot if (r.trick and r.z > 0) else 0.0, sink * p[3])
	if r.fallT > 0:
		var pts := A.ell_pts(Vector2(p[0], p[2]), (10 + sink) * p[3], (10 + sink) * p[3] * minf(0.5, CH / p[4]), 24)
		pts.append(pts[0])
		ci.draw_polyline(pts, Color(220 / 255.0, 240 / 255.0, 250 / 255.0, 0.8), 2, true)
	var top: float = p[2] - (hz + 48 * float(r.ch.get("size", 1)) + 5) * p[3]
	if r.isPlayer:
		if R.state == "count":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(p[0] - 8, top - 14), Vector2(p[0] + 8, top - 14), Vector2(p[0], top - 4)]), Color("#b8322a"))
	elif p[4] < 900 and al > 0.5:
		tags.append({"x": p[0], "y": top, "z": p[4], "name": String(r.ch.name), "col": Color(String(R.PERS.get(r.ai.pers, {}).get("col", "#888888"))), "fs": roundf(clampf(6 * p[3], 9, 13))})

# một khung con đua: chân ở (x,y), s css px / đơn vị thế giới; spd chọn chạy hay đứng
func _bird(ci: CanvasItem, id: String, rel: float, run: float, spd: float, x: float, y: float, s: float, al: float, rot: float, trick := 0.0, clip := 0.0) -> void:
	var m: Dictionary = RS.rmeta(id)
	if m.is_empty():
		return
	rel = fposmod(rel, TAU)
	var mir := rel > PI
	var ra := TAU - rel if mir else rel
	var k := clampi(int(round(ra / (PI / 16.0))), 0, 16)
	var v: Dictionary = m.v[k]
	var g := clampf(absf(spd) / 140.0, 0, 1)
	var fi: int
	if g < 0.12:
		fi = int(v.st)
	else:
		var n: int = v.run.size()
		fi = int(v.run[int(floor(fposmod(run / TAU, 1.0) * n)) % n])
	var t = RS.rframe(id, fi)
	if t == null:
		# chưa giải xong: lấy khung gần nhất đã có của góc này / góc kế
		for kk in [k, k - 1, k + 1, k - 2, k + 2]:
			if kk < 0 or kk > 16:
				continue
			var vv: Dictionary = m.v[kk]
			for f2 in [vv.st] + Array(vv.run):
				var tt = RS.RT.get(RS.RB[id] + "/f" + str(int(f2)))
				if tt != null:
					t = tt
					fi = int(f2)
					break
			if t != null:
				break
	if t == null:
		return
	var fr: Array = m.f[fi]
	var S: float = m.S
	var sz: float = float(m.get("size", 1))
	var kk2 := s / S * sz * 1.0
	# khung nướng ở S px / đơn vị (đã có cỡ con đua bên trong); vẽ ở s css px / đơn vị
	kk2 = s / S
	var xf := Transform2D(rot, Vector2(x, y))
	if trick != 0.0:
		xf = xf * Transform2D(0, Vector2(0, -18 * s)) * Transform2D(trick, Vector2.ZERO) * Transform2D(0, Vector2(0, 18 * s))
	if mir:
		xf = xf * Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2.ZERO)
	ci.draw_set_transform_matrix(xf)
	var rect := Rect2(float(fr[0]) * kk2, float(fr[1]) * kk2, float(fr[2]) * kk2, float(fr[3]) * kk2)
	if clip > 0:
		# phần chìm dưới nước không vẽ: cắt đáy khung
		var cut := clip
		var vis_h := maxf(0.0, rect.size.y - maxf(0.0, rect.end.y - (0.0 - 0.0)) - 0.0)
		var bottom := rect.end.y - cut
		if bottom <= rect.position.y:
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
			return
		var frac := (bottom - rect.position.y) / rect.size.y
		ci.draw_texture_rect_region(t, Rect2(rect.position, Vector2(rect.size.x, rect.size.y * frac)), Rect2(0, 0, t.get_width(), t.get_height() * frac), Color(1, 1, 1, al))
	else:
		ci.draw_texture_rect(t, rect, false, Color(1, 1, 1, al))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

func _part(ci: CanvasItem, q: Dictionary, p: Array) -> void:
	var U := maxf(0.6, VH / 720.0)
	var f := clampf(q.life / q.max, 0, 1)
	var nr := clampf((p[4] - CDIST * 0.4) / (CDIST * 0.25), 0, 1)
	var a := minf(1.0, f * 1.5) * nr
	var c: Color = q.c
	if q.has("feather"):
		var rr := maxf(1.0, minf(6 * U, 5 * p[3]))
		ci.draw_set_transform_matrix(Transform2D(float(q.get("rot", 0)), Vector2(p[0], p[1])))
		ci.draw_colored_polygon(A.ell_pts(Vector2.ZERO, rr, rr * 0.35, 10), Color(c, c.a * a))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	var r := maxf(0.5, minf(6 * U, float(q.s) * p[3] * (0.5 + 0.5 * f)))
	ci.draw_colored_polygon(A.ell_pts(Vector2(p[0], p[1]), r, r, 12), Color(c, c.a * a))

func _tags(ci: CanvasItem) -> void:
	tags.sort_custom(func(a, b): return a.z < b.z)
	var placed := []
	for t in tags:
		var tw := A.tw(t.name, t.fs, 700)
		var w: float = tw + t.fs * 1.4
		var h: float = t.fs * 1.25
		var y: float = t.y
		var ok := false
		for k in 3:
			ok = true
			for q in placed:
				if absf(q.x - t.x) < (q.w + w) / 2 and absf(q.y - y) < (q.h + h) / 2:
					ok = false
					break
			if ok:
				break
			y -= h
		if not ok:
			continue
		placed.append({"x": t.x, "y": y, "w": w, "h": h})
		A.text(ci, t.name, t.x, y - t.fs * 0.35, t.fs, Color("#2e1f0f"), 1, 700, 1.5, Color(1, 246 / 255.0, 224 / 255.0, 0.8))
		ci.draw_colored_polygon(A.ell_pts(Vector2(t.x - tw / 2 - t.fs * 0.6, y - t.fs * 0.35), t.fs * 0.32, t.fs * 0.32, 12), t.col)
