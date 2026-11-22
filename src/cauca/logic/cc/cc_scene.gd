extends Control
# CÂU CÁ BỜ KÊNH: trời, bờ bên kia, mặt nước bằng shader (chép 02_gl.js): mây phồng, mặt trời / trăng / sao,
# bờ đung đưa, sóng, 16 vòng gợn trong không gian thế giới, mưa rơi thành vòng, bóng phản chiếu, lấp lánh,
# bóng cá dưới nước, quầng phao đèn. Vẽ ở độ phân giải riêng (GL.scale của web) trong SubViewport rồi phóng lên.
# Vòng gợn + bóng cá đưa vào bằng một ảnh dữ liệu 24x1 (máy Adreno không chịu mảng uniform), 3 ảnh mẫu tất cả.

const A := preload("res://logic/cc/cc_art.gd")

const SH := """
shader_type canvas_item;
uniform vec2 uRes; uniform float uT; uniform float uHor; uniform float uYw; uniform float uF; uniform float uS;
uniform vec4 uBank;
uniform vec4 uSub = vec4(0.,0.,1.,1.);
uniform vec2 uUV = vec2(1.,1.);
uniform sampler2D uBankTex : filter_linear_mipmap, repeat_disable;
uniform sampler2D uAuxTex : filter_linear, repeat_disable;
uniform sampler2D uData : filter_nearest, repeat_disable;
uniform vec3 uTop; uniform vec3 uHorC; uniform vec3 uSunC; uniform vec3 uTint; uniform vec3 uWater; uniform vec3 uCloudC; uniform vec3 uFog;
uniform vec3 uSun; uniform vec3 uMoon;
uniform float uStar; uniform float uNight; uniform float uRain; uniform float uWind; uniform float uCloud;
uniform vec4 uFlt;
uniform float uOld = 0.;
float h21(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
float vn(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(h21(i),h21(i+vec2(1,0)),f.x),mix(h21(i+vec2(0,1)),h21(i+vec2(1,1)),f.x),f.y);}
vec3 sky(vec2 p, float disc){
 float h=clamp((uYw-p.y)/(uYw+uRes.y*.3),0.,1.);
 vec3 c=mix(uHorC,uTop,pow(h,.62));
 float d=length(p-uSun.xy), R=uRes.y;
 float sv=min(uSun.z,1.)*disc;
 c+=uSunC*exp(-d/(R*.3))*.18*uSun.z;
 c=mix(c,mix(c,uSunC+.15,.35),smoothstep(R*.088,R*.084,d)*sv);
 c=mix(c,mix(c,uSunC+.2,.55),smoothstep(R*.06,R*.057,d)*sv);
 c=mix(c,uSunC*1.1+.2,smoothstep(R*.038,R*.035,d)*sv);
 float cl=0.; vec3 cc=uCloudC;
 for(int i=0;i<7;i++){
  float fi=float(i);
  if(h21(vec2(fi,7.3))>.42+uCloud*.58)continue;
  float cw=min(R,uRes.x*.7)*(.1+.07*h21(vec2(fi,1.7)));
  float span=uRes.x+cw*2.4;
  float cx=mod(h21(vec2(fi,2.9))*span+uT*R*.0035*(.6+h21(vec2(fi,5.1))),span)-cw*1.2;
  float cy=uYw*(.26+.42*h21(vec2(fi,3.3)));
  float base=cy+cw*.13, dc=1e5;
  if(abs(p.x-cx)>cw*1.45||abs(p.y-cy)>cw*.85)continue;
  for(int j=0;j<6;j++){
   float t=float(j)/5.;
   vec2 c2=vec2(cx+(t-.5)*cw*1.7,cy+cw*.06-sin(t*3.1416)*cw*.26*(.7+.6*h21(vec2(fi,float(j)+9.))));
   float r=cw*(.2+.15*sin(t*3.1416)+.05*h21(vec2(float(j),fi+4.)));
   dc=min(dc,length(p-c2)-r);
  }
  dc=max(dc,p.y-base);
  if(dc<1.5){
   float a=smoothstep(1.5,-.5,dc);
   vec3 body=p.y>base-cw*.1?uCloudC*vec3(.84,.9,.98):uCloudC;
   vec3 rim=uCloudC*vec3(.62,.7,.82);
   vec3 col=mix(rim,body,smoothstep(-1.8,-3.2,dc));
   cc=mix(cc,col,a); cl=max(cl,a);
  }
 }
 c=mix(c,cc,cl*smoothstep(.05,.2,h));
 if(uStar>0.){vec2 g=floor(p/(R*.012));float s=h21(g);
  vec2 f=fract(p/(R*.012))-.5;
  float st=step(.985,s)*smoothstep(.12,.0,length(f))*(.6+.4*sin(uT*3.+s*60.));
  c+=st*uStar*(1.-cl)*smoothstep(.1,.5,h);}
 if(uMoon.z>0.){float m=length(p-uMoon.xy);
  c+=vec3(.75,.8,1.)*(exp(-m/(R*.05))*.25)*uMoon.z;
  c=mix(c,vec3(.95,.95,.86),smoothstep(R*.024,R*.021,m)*uMoon.z*(1.-cl*.7)*disc);}
 return c;
}
vec4 bank(vec2 p, float sway){
 vec2 uv=(p-uBank.xy)/uBank.zw;
 if(uv.x<0.||uv.x>1.||uv.y<0.||uv.y>1.)return vec4(0.);
 vec4 a=texture(uAuxTex,uv);
 if(sway>0.){float hf=clamp((uYw-p.y)/(uRes.y*.25),0.,1.);
  uv.x+=a.g*hf*(sin(uT*1.3+uv.x*70.+uv.y*9.)*1.1+sin(uT*2.1+uv.x*170.)*.5)*(0.6+uWind)*uS/uBank.z;}
 vec4 b=texture(uBankTex,clamp((uv-uSub.xy)/uSub.zw,vec2(0.),vec2(1.)));
 vec3 col=b.rgb*uTint+vec3(1.,.72,.38)*a.r*uNight*1.7;
 col=mix(col,uFog,.03);
 col=mix(col,vec3(dot(col,vec3(.3,.5,.2)))*vec3(.9,.95,1.02),uRain*.35);
 return vec4(col,b.a)+vec4(vec3(1.,.66,.3)*a.r*uNight*.35,0.);
}
vec3 scene(vec2 p, float sway){
 vec3 c=sky(p,sway>0.?1.:0.); vec4 b=bank(p,sway);
 return mix(c,b.rgb,clamp(b.a,0.,1.));
}
vec2 dw(vec2 w,vec2 d,float k,float s,float a,float fp){
 float lam=6.2832/k; float fade=clamp(lam/(5.*fp)-1.,0.,1.);
 return d*(a*k*cos(dot(w,d)*k-uT*s))*fade;
}
void fragment(){
 vec2 p=UV*uRes*uUV;
 if(p.y<uYw){COLOR=vec4(scene(p,1.),1.);}
 else if(uOld<.5){COLOR=vec4(uWater,1.);}
 else{
 float dy=max(p.y-uHor,1.);
 float z=uF/dy; float X=(p.x-uRes.x*.5)*z/uF;
 vec2 w=vec2(X,z);
 float fp=z*z/uF;
 vec2 ww=w+.25*vec2(sin(w.y*1.3+uT*.3),sin(w.x*1.1-uT*.2));
 float a=.010*(.55+uWind);
 vec2 g=dw(ww,vec2(.8,.6),3.1,1.2,a,fp)+dw(ww,vec2(-.6,.8),4.9,1.6,a*.7,fp)
  +dw(ww,vec2(.96,-.28),7.6,2.2,a*.45,fp)+dw(ww,vec2(.2,.98),11.,2.8,a*.32,fp)
  +dw(ww,vec2(-.9,.43),17.,3.6,a*.22,fp)+dw(ww,vec2(.5,-.86),26.,4.4,a*.14,fp);
 float ringW=0.;
 for(int i=0;i<16;i++){vec4 r=texelFetch(uData,ivec2(i,0),0); if(r.w<=0.)continue;
  vec2 dv=w-r.xy; float d=length(dv)+1e-4; float age=r.z;
  float Rr=.12+age*.85; float x=d-Rr;
  if(x*x*(18./(1.+age))>12.)continue;
  float k=26.; float lam=6.2832/k; float fade=clamp(lam/(4.*fp)-.5,0.,1.);
  float e=exp(-x*x*(18./(1.+age)))*exp(-age*1.0)*r.w*fade;
  float tail=x<0.?exp(x*2.5):1.;
  g+=dv/d*cos(x*k)*e*tail*.35; ringW+=smoothstep(.75,.95,cos(x*k))*e*tail*1.6;}
 if(uRain>0.){vec2 cw=w*2.2;
  for(int j=0;j<2;j++){vec2 o=vec2(float(j)*.5);
   vec2 cc=floor(cw+o), ff=fract(cw+o);
   vec2 c0=.5+(vec2(h21(cc),h21(cc+7.1))-.5)*.5;
   float ph=fract(uT*.85+h21(cc+3.3)); vec2 dv=ff-c0; float d=length(dv)+1e-4;
   float x=d-ph*.42; float e=exp(-x*x*500.)*(1.-ph)*uRain*clamp(.3/(fp*30.),0.,1.);
   g+=dv/d*cos(x*70.)*e*.15; ringW+=smoothstep(.8,.95,cos(x*70.))*e*1.2;}}
 vec3 n=normalize(vec3(-g.x,1.,-g.y));
 float near=clamp(dy/(uRes.y*.6),0.,1.);
 float fb=clamp((p.y-uYw)/(uRes.y-uYw),0.,1.);
 vec2 rp=vec2(p.x,2.*uYw-p.y)+vec2(n.x*1.6,-n.z*.4)*uRes.y*(.04+.1*near);
 rp.y=min(rp.y,uYw-1.);
 vec3 body=uWater*(.9+.14*smoothstep(.1,1.,fb))+vec3(.015,.04,.03)*fb*(1.-uNight);
 body=mix(body,vec3(dot(body,vec3(.3,.5,.2)))*vec3(.82,.92,.98),uRain*.6);
 float shd=0.;
 for(int i=0;i<4;i++){vec4 s=texelFetch(uData,ivec2(16+i,0),0); if(s.w<=0.)continue; vec4 sd=texelFetch(uData,ivec2(20+i,0),0);
  vec2 dv=w-s.xy; vec2 l=vec2(dot(dv,sd.xy),dot(dv,vec2(-sd.y,sd.x)));
  float e=smoothstep(1.,.8,length(l/vec2(s.z*.5,sd.z)));
  body*=1.-e*s.w*.35; shd+=e*s.w;}
 vec4 rb=bank(rp,0.);
 float ra=(1.-smoothstep(.0,.38,fb))*(1.-clamp(shd,0.,1.));
 vec3 rc=mix(body*.8,rb.rgb,.22+.5*uNight);
 vec3 col=mix(body,rc,clamp(rb.a,0.,1.)*ra*.9);
 vec3 v=normalize(vec3(X,-1.,z));
 vec2 sw=vec2(w.x*1.4,w.y*3.2)+vec2(uT*.05,uT*.12);
 float wn=vn(sw)*.7+vn(sw*2.1+3.)*.3;
 float lw=clamp(fp*5.,.01,.028);
 float stroke=smoothstep(lw,lw*.4,abs(wn-.5))*smoothstep(.7,.72,vn(sw*vec2(1.8,1.)+7.3));
 stroke*=smoothstep(.12,.3,fb)*(1.-smoothstep(.7,1.,fb)*.75)*(1.-uNight*.75);
 col=mix(col,mix(vec3(1.),uWater*2.+vec3(.12,.16,.22),uNight),stroke*.75);
 col=mix(col,vec3(1.),clamp(ringW,0.,1.)*.8);
 vec3 r=reflect(v,n);
 vec3 sd=normalize(vec3((uSun.x-uRes.x*.5)/uF*7.,(uHor-uSun.y)/uF*7.,1.));
 float sq=max(dot(normalize(r*vec3(2.,1.,1.)),sd),0.);
 col+=uSunC*step(.9985,sq)*1.2*uSun.z*smoothstep(-.02,.06,sd.y);
 if(uMoon.z>0.){float mx=(p.x-uMoon.x)/(uRes.x*(.02+.07*fb)); float mb=exp(-mx*mx)*uMoon.z*smoothstep(0.,.04,fb)*(1.-uRain);
  float mn=smoothstep(.52,.6,vn(vec2(w.x*2.6,w.y*10.)+vec2(uT*.15,uT*.4)));
  col+=vec3(.72,.78,.95)*mb*(.12+mn*.5);}
 vec3 md=normalize(vec3((uMoon.x-uRes.x*.5)/uF*7.,(uHor-uMoon.y)/uF*7.,1.));
 float mq=max(dot(normalize(r*vec3(2.5,1.,1.)),md),0.); col+=vec3(.85,.9,1.)*step(.997,mq)*.9*uMoon.z;
 if(uFlt.w>0.){float d=length((w-uFlt.xy)*vec2(1.,.6)); col+=vec3(1.,.75,.35)*exp(-d*9.)*uFlt.w*.5;}
 col*=1.-.22*smoothstep(uYw+uRes.y*.01,uYw,p.y);
 col=mix(col,uFog,.07*smoothstep(uYw+uRes.y*.04,uYw,p.y));
 COLOR=vec4(col,1.);
 }
}
"""

# NƯỚC MỚI (Link 11-22 "vẽ nước lại bằng hiệu ứng godot"): mặt nước riêng vẽ sau trời + bờ, đọc lại khung đó bằng
# hint_screen_texture để soi bóng trời, mây, mặt trời, bờ; sóng = 2 NoiseTexture2D (normal map, liền mép, có mipmap
# nên xa tự mịn) trôi 2 hướng trong không gian thế giới; Fresnel: xa soi nhiều, gần thấy màu nước; lấp lánh theo pháp tuyến.
const WSH := """
shader_type canvas_item;
uniform sampler2D SCR : hint_screen_texture, filter_linear;
uniform sampler2D uN1 : filter_linear_mipmap, repeat_enable;
uniform sampler2D uN2 : filter_linear_mipmap, repeat_enable;
uniform sampler2D uData : filter_nearest, repeat_disable;
uniform vec2 uRes; uniform float uT; uniform float uHor; uniform float uYw; uniform float uF;
uniform vec3 uSunC; uniform vec3 uWater; uniform vec3 uFog; uniform vec3 uTint;
uniform vec3 uSun; uniform vec3 uMoon;
uniform float uNight; uniform float uRain; uniform float uWind;
uniform vec4 uFlt;
uniform float uFlipY = 0.;
float h21(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
vec3 scr(vec2 q){vec2 u=q/uRes; if(uFlipY>.5)u.y=1.-u.y; return texture(SCR,u).rgb;}
void fragment(){
 vec2 p=vec2(UV.x*uRes.x, uYw+UV.y*(uRes.y-uYw));
 float dy=max(p.y-uHor,1.);
 float z=uF/dy; float X=(p.x-uRes.x*.5)*z/uF;
 vec2 w=vec2(X,z);
 float fp=z*z/uF;
 float fb=clamp((p.y-uYw)/(uRes.y-uYw),0.,1.);
 float near=clamp(dy/(uRes.y*.6),0.,1.);
 // sóng: 2 lớp noise normal map, lớp lớn trôi chéo, lớp nhỏ trôi ngược
 vec2 u1=vec2(w.x*.22,w.y*.40)+vec2(.010,.034)*uT;
 vec2 u2=vec2(w.x*.55+w.y*.10,w.y*1.25-w.x*.10)+vec2(-.030,.030)*uT;
 vec2 u3=vec2(w.x*1.3,w.y*3.0)+vec2(.05,-.09)*uT;
 vec3 a1=texture(uN1,u1).rgb*2.-1.; vec3 a2=texture(uN2,u2).rgb*2.-1.; vec3 a3=texture(uN2,u3+.37).rgb*2.-1.;
 float gust=.75+.5*texture(uN1,w*.045+vec2(.004,.008)*uT).b;
 float k=(.9+.8*uWind)*gust*(1.+uRain*.6)*mix(1.,.62,near);
 vec2 g=(a1.xy*.55+a2.xy*.35+a3.xy*.25*(1.-smoothstep(.0,.5,1.-near)*.0))*k;
 // vòng gợn (phao, cá, nước rơi) + mưa: như cũ, ảnh dữ liệu 24x1
 float ringW=0.;
 for(int i=0;i<16;i++){vec4 r=texelFetch(uData,ivec2(i,0),0); if(r.w<=0.)continue;
  vec2 dv=w-r.xy; float d=length(dv)+1e-4; float age=r.z;
  float Rr=.12+age*.85; float x=d-Rr;
  if(x*x*(18./(1.+age))>12.)continue;
  float kk=26.; float lam=6.2832/kk; float fade=clamp(lam/(4.*fp)-.5,0.,1.);
  float e=exp(-x*x*(18./(1.+age)))*exp(-age*1.0)*r.w*fade;
  float tail=x<0.?exp(x*2.5):1.;
  g+=dv/d*cos(x*kk)*e*tail*.55; ringW+=smoothstep(.75,.95,cos(x*kk))*e*tail*1.2;}
 if(uRain>0.){vec2 cw=w*2.2;
  for(int j=0;j<2;j++){vec2 o=vec2(float(j)*.5);
   vec2 cc=floor(cw+o), ff=fract(cw+o);
   vec2 c0=.5+(vec2(h21(cc),h21(cc+7.1))-.5)*.5;
   float ph=fract(uT*.85+h21(cc+3.3)); vec2 dv=ff-c0; float d=length(dv)+1e-4;
   float x=d-ph*.42; float e=exp(-x*x*500.)*(1.-ph)*uRain*clamp(.3/(fp*30.),0.,1.);
   g+=dv/d*cos(x*70.)*e*.3; ringW+=smoothstep(.8,.95,cos(x*70.))*e*1.;}}
 vec3 n=normalize(vec3(-g.x,1.,-g.y));
 vec3 v=normalize(vec3(X,-1.,z));
 // soi bóng: lật quanh mép nước, lệch theo sóng (gần lệch nhiều, xa ít)
 vec2 off=vec2(n.x*uRes.y*(.05+.18*near), -abs(n.z)*uRes.y*(.03+.16*near));
 vec2 rp=vec2(p.x,2.*uYw-p.y)+off;
 rp.y=clamp(rp.y,1.,uYw-1.);
 vec3 rc=(scr(rp)*.6+scr(rp+vec2(0.,-uRes.y*.006))*.4);
 rc=min(rc,vec3(.86))*(1.-.25*near);
 // màu thân nước: trong, xanh, gần chân lên sáng hơn, dưới ngọn sóng sáng
 vec3 body=uWater*(.86+.22*smoothstep(.05,1.,fb))+vec3(.01,.035,.03)*fb*(1.-uNight);
 float facet=clamp(1.+(-n.z*1.1+n.x*.35)*1.3,.76,1.25);
 body*=facet;
 body+=uWater*max(g.y,0.)*.30*(1.-uNight*.6);
 body=mix(body,vec3(dot(body,vec3(.3,.5,.2)))*vec3(.82,.92,.98),uRain*.6);
 float shd=0.;
 for(int i=0;i<4;i++){vec4 s=texelFetch(uData,ivec2(16+i,0),0); if(s.w<=0.)continue; vec4 sd=texelFetch(uData,ivec2(20+i,0),0);
  vec2 dv=w-s.xy; vec2 l=vec2(dot(dv,sd.xy),dot(dv,vec2(-sd.y,sd.x)));
  float e=smoothstep(1.,.8,length(l/vec2(s.z*.5,sd.z)));
  body*=1.-e*s.w*.35; shd+=e*s.w;}
 float ct=clamp(dot(-v,n),0.,1.);
 float fr=.04+.96*pow(1.-ct,5.);
 float rfade=1.-smoothstep(.0,.6,fb)*.55;
 fr=clamp(fr*1.1,.08,.55)*rfade*(1.-clamp(shd,0.,1.)*.6);
 vec3 col=mix(body,rc*mix(vec3(1.),uWater*1.7,.38),fr);
 // lấp lánh mặt trời + vệt nắng
 vec3 r=reflect(v,n);
 vec3 sd=normalize(vec3((uSun.x-uRes.x*.5)/uF*7.,(uHor-uSun.y)/uF*7.,1.));
 float sq=max(dot(normalize(r*vec3(2.,1.,1.)),sd),0.);
 float sv=uSun.z*smoothstep(-.02,.06,sd.y);
 col+=uSunC*(smoothstep(.9982,.9996,sq)*.9+pow(sq,60.)*.08)*sv;
 // trăng
 if(uMoon.z>0.){vec3 md=normalize(vec3((uMoon.x-uRes.x*.5)/uF*7.,(uHor-uMoon.y)/uF*7.,1.));
  float mq=max(dot(normalize(r*vec3(2.5,1.,1.)),md),0.);
  col+=vec3(.85,.9,1.)*(smoothstep(.994,.999,mq)*.9+pow(mq,40.)*.08)*uMoon.z*(1.-uRain);}
 col=mix(col,vec3(1.),clamp(ringW,0.,1.)*.6);
 if(uFlt.w>0.){float d=length((w-uFlt.xy)*vec2(1.,.6)); col+=vec3(1.,.75,.35)*exp(-d*9.)*uFlt.w*.5;}
 // mép nước bờ xa: vệt sáng vỗ bờ + tối dưới chân bờ, sương xa
 float e0=(p.y-uYw)/uRes.y;
 float lap=smoothstep(.0035,.0,e0-.0012*(a1.x+1.))*smoothstep(0.,.0015,e0)*(1.-uNight*.6);
 col*=1.-.20*smoothstep(uRes.y*.012,0.,p.y-uYw);
 col=mix(col,mix(vec3(1.),uWater*1.6+.1,.35),lap*.55);
 col=mix(col,uFog,.08*smoothstep(uYw+uRes.y*.05,uYw,p.y));
 COLOR=vec4(col,1.);
}
"""

var game
var vp: SubViewport
var rect: ColorRect
var view: TextureRect
var mat: ShaderMaterial
var trect: ColorRect      # trời + bờ vẽ đúng độ phân giải màn hình (nét), đè lên phần trên mặt nước
var tmat: ShaderMaterial
var _bank_key := ""
var _bank_sub := Vector4(0, 0, 1, 1)
var wrect: ColorRect
var wmat: ShaderMaterial
static var old_water := false   # true = nước cũ (chép 02_gl.js), để so
var data_img: Image
var data_tex: ImageTexture
var scale_s := 1.0
var _ft := 16.0
var _fn := 0
var fixed_scale := -1.0

func _init(gm) -> void:
	game = gm
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	vp = SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	rect = ColorRect.new()
	rect.color = Color.WHITE
	var sh := Shader.new()
	sh.code = SH
	mat = ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	vp.add_child(rect)
	wrect = ColorRect.new()
	wrect.color = Color.WHITE
	var wsh := Shader.new()
	wsh.code = WSH
	wmat = ShaderMaterial.new()
	wmat.shader = wsh
	wrect.material = wmat
	vp.add_child(wrect)
	wmat.set_shader_parameter("uN1", _noise(512, 7.0, 0.011, 4, 101))
	wmat.set_shader_parameter("uN2", _noise(512, 5.0, 0.019, 3, 202))
	view = TextureRect.new()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.texture = vp.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	trect = ColorRect.new()
	trect.color = Color.WHITE
	tmat = ShaderMaterial.new()
	tmat.shader = sh
	trect.material = tmat
	trect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(trect)
	data_img = Image.create(24, 1, false, Image.FORMAT_RGBAF)
	data_tex = ImageTexture.create_from_image(data_img)
	mat.set_shader_parameter("uData", data_tex)
	wmat.set_shader_parameter("uData", data_tex)
	for m in [mat, tmat]:
		m.set_shader_parameter("uAuxTex", A.img("bank_aux"))
		m.set_shader_parameter("uData", data_tex)
	scale_s = fixed_scale if fixed_scale > 0 else minf(game.K, 1.25)

func _noise(sz: int, bump: float, freq: float, oct: int, seed_: int) -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = freq
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = oct
	fn.seed = seed_
	var t := NoiseTexture2D.new()
	t.width = sz
	t.height = sz
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = bump
	t.generate_mipmaps = true
	t.noise = fn
	return t

func resize() -> void:
	var L: Dictionary = game.L
	var w := maxi(16, int(ceil(L.W * scale_s)))
	var h := maxi(16, int(ceil(L.H * scale_s)))
	vp.size = Vector2i(w, h)
	rect.position = Vector2.ZERO
	rect.size = Vector2(w, h)
	var ywp := int(floor(game.L.yw * scale_s))
	wrect.position = Vector2(0, ywp)
	wrect.size = Vector2(w, h - ywp)
	view.position = Vector2.ZERO
	view.size = Vector2(L.W, L.H)
	trect.position = Vector2.ZERO
	trect.size = Vector2(L.W, ywp / scale_s)
	_bank_build()

# bờ 9px: 6 mảnh 2700x2700 (+ lề 48) của ảnh 16200x2700; chỉ lấy đoạn thấy trên màn hình, thu về đúng số điểm ảnh máy
const BT_N := 6
const BT_W := 2700
const BT_M := 48
const BT_H := 2700
func _bank_build() -> void:
	var L: Dictionary = game.L
	var K: float = game.K
	var c0: float = clampf(-L.bankX - 8.0, 0.0, L.bankW)
	var c1: float = clampf(L.W - L.bankX + 8.0, 0.0, L.bankW)
	var f: float = minf(1.0, L.bankH * K / BT_H)
	var th := maxi(8, int(round(BT_H * f)))
	var sx0: float = c0 / L.bankW * BT_W * BT_N
	var sx1: float = c1 / L.bankW * BT_W * BT_N
	var key := "%d_%d_%d" % [int(sx0), int(sx1), th]
	if key == _bank_key:
		return
	var tw := maxi(8, int(ceil((sx1 - sx0) * f)))
	var out: Image = null
	for i in BT_N:
		var a := maxf(sx0, i * BT_W)
		var b := minf(sx1, (i + 1) * BT_W)
		if b <= a:
			continue
		var im := Image.new()
		var bytes := FileAccess.get_file_as_bytes(A.DIR + "bank9_%d.webp" % i)
		if bytes.is_empty() or im.load_webp_from_buffer(bytes) != OK:
			out = null
			break
		if out == null:
			out = Image.create(tw, th, false, Image.FORMAT_RGBA8)
		im.convert(Image.FORMAT_RGBA8)
		var fx0 := i * BT_W - BT_M
		im.resize(maxi(1, int(round(im.get_width() * f))), th, Image.INTERPOLATE_LANCZOS)
		var dx := int(round((a - sx0) * f))
		var dw := mini(tw, int(round((b - sx0) * f))) - dx
		var sx := int(round((a - fx0) * f))
		if dw > 0:
			out.blit_rect(im, Rect2i(sx, 0, mini(dw, im.get_width() - sx), th), Vector2i(dx, 0))
	var tex: Texture2D
	if out != null:
		out.fix_alpha_edges()
		out.generate_mipmaps()
		tex = ImageTexture.create_from_image(out)
		_bank_sub = Vector4(c0 / L.bankW, 0, (c1 - c0) / L.bankW, 1)
	else:
		tex = A.img("bank")      # không có ảnh 9px: dùng ảnh cũ
		_bank_sub = Vector4(0, 0, 1, 1)
	_bank_key = key
	for m in [mat, tmat]:
		m.set_shader_parameter("uBankTex", tex)
		m.set_shader_parameter("uSub", _bank_sub)

# đo khung hình: chậm quá thì hạ độ phân giải mặt nước (như web: sau 120 khung, trung bình > 26 ms)
func perf(dt: float) -> void:
	if fixed_scale > 0:
		return
	_ft = _ft * 0.97 + dt * 1000 * 0.03
	_fn += 1
	if _fn > 120 and _ft > 26 and scale_s > 0.55:
		scale_s = maxf(0.55, scale_s * 0.82)
		resize()
		_fn = 0

func sun_screen(tod: Dictionary) -> Vector2:
	var L: Dictionary = game.L
	return Vector2(tod.sunX * L.W, L.yw - (L.yw - L.H * .05) * tod.sunElev * (0.9 if L.portrait else 1.0) + L.H * .02)

func _scene_u(m: ShaderMaterial, s: float, res: Vector2, t: float, tod: Dictionary, W: Dictionary) -> void:
	var L: Dictionary = game.L
	m.set_shader_parameter("uRes", res)
	m.set_shader_parameter("uT", fmod(t, 1000.0))
	m.set_shader_parameter("uHor", L.hor * s)
	m.set_shader_parameter("uYw", L.yw * s)
	m.set_shader_parameter("uF", L.F * s)
	m.set_shader_parameter("uS", s)
	var btop: float = L.yw - L.bankH * 872.0 / 900.0
	m.set_shader_parameter("uBank", Vector4(L.bankX * s, btop * s, L.bankW * s, L.bankH * s))
	for k in [["uTop", "top"], ["uHorC", "hor"], ["uSunC", "sun"], ["uTint", "tint"], ["uWater", "water"], ["uCloudC", "cloud"], ["uFog", "fog"]]:
		var c: Color = tod[k[1]]
		m.set_shader_parameter(k[0], Vector3(c.r, c.g, c.b))
	var sp := sun_screen(tod)
	m.set_shader_parameter("uSun", Vector3(sp.x * s, sp.y * s, tod.si * (1 - W.rain * .97) if tod.sunUp else 0.0))
	m.set_shader_parameter("uMoon", Vector3(tod.sunX * L.W * s, (L.yw - (L.yw - L.H * .08) * tod.sunElev) * s, tod.moon * (1 - W.rain)))
	m.set_shader_parameter("uStar", tod.star * (1 - W.rain))
	m.set_shader_parameter("uNight", tod.night)
	m.set_shader_parameter("uRain", W.rain)
	m.set_shader_parameter("uWind", W.wind)
	m.set_shader_parameter("uCloud", W.cloud)
	var fg: Array = W.floatGlow
	m.set_shader_parameter("uFlt", Vector4(fg[0], fg[1], 0, fg[2]))
	m.set_shader_parameter("uOld", 1.0 if old_water else 0.0)

func render(t: float, tod: Dictionary, W: Dictionary, rips: PackedFloat32Array, shs: PackedFloat32Array) -> void:
	var L: Dictionary = game.L
	_scene_u(mat, scale_s, Vector2(vp.size), t, tod, W)
	_scene_u(tmat, game.K, Vector2(L.W, L.H) * game.K, t, tod, W)
	var ywc := floorf(L.yw * scale_s) / scale_s
	tmat.set_shader_parameter("uUV", Vector2(1.0, ywc / L.H))
	var m := mat
	var s := scale_s
	wrect.visible = not old_water
	if not old_water:
		var wm := wmat
		var ywp := floorf(L.yw * s)
		wm.set_shader_parameter("uRes", Vector2(vp.size))
		wm.set_shader_parameter("uT", fmod(t, 1000.0))
		wm.set_shader_parameter("uHor", L.hor * s)
		wm.set_shader_parameter("uYw", ywp)
		wm.set_shader_parameter("uF", L.F * s)
		for k in [["uSunC", "sun"], ["uTint", "tint"], ["uWater", "water"], ["uFog", "fog"]]:
			var c: Color = tod[k[1]]
			wm.set_shader_parameter(k[0], Vector3(c.r, c.g, c.b))
		for k in ["uSun", "uMoon", "uNight", "uRain", "uWind", "uFlt"]:
			wm.set_shader_parameter(k, m.get_shader_parameter(k))
	for i in 16:
		data_img.set_pixel(i, 0, Color(rips[i * 4], rips[i * 4 + 1], rips[i * 4 + 2], rips[i * 4 + 3]))
	for i in 8:
		data_img.set_pixel(16 + i, 0, Color(shs[i * 4], shs[i * 4 + 1], shs[i * 4 + 2], shs[i * 4 + 3]))
	data_tex.update(data_img)
