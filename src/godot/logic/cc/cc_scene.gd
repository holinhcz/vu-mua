extends Control
# CÂU CÁ BỜ KÊNH: trời, bờ bên kia, mặt nước bằng shader (chép 02_gl.js): mây phồng, mặt trời / trăng / sao,
# bờ đung đưa, sóng, 16 vòng gợn trong không gian thế giới, mưa rơi thành vòng, bóng phản chiếu, lấp lánh,
# bóng cá dưới nước, quầng phao đèn. Vẽ ở độ phân giải riêng (GL.scale của web) trong SubViewport rồi phóng lên.
# Vòng gợn + bóng cá đưa vào bằng một ảnh dữ liệu 24x1 (máy Adreno không chịu mảng uniform), 3 ảnh mẫu tất cả.

const A := preload("res://logic/cc/cc_art.gd")
const MAY := preload("res://logic/cc/cc_may.gd")
const SUN := preload("res://logic/cc/cc_sun.gd")

const SH := """
shader_type canvas_item;
uniform vec2 uRes; uniform float uT; uniform float uHor; uniform float uYw; uniform float uF; uniform float uS;
uniform vec4 uBank; uniform float uExact = 0.; uniform float uNoBank = 0.; uniform float uNoSun = 0.;
uniform vec4 uSub = vec4(0.,0.,1.,1.);
uniform vec2 uUV = vec2(1.,1.);
uniform sampler2D uBankTex : filter_linear_mipmap, repeat_disable;
uniform sampler2D uBankN : filter_linear_mipmap, repeat_disable;
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
 if(uNoSun<.5){   // trên màn: mặt trời = cc_sun.gd
 c=mix(c,mix(c,uSunC+.15,.35),smoothstep(R*.088,R*.084,d)*sv);
 c=mix(c,mix(c,uSunC+.2,.55),smoothstep(R*.06,R*.057,d)*sv);
 c=mix(c,uSunC*1.1+.2,smoothstep(R*.038,R*.035,d)*sv);}
 // mây = ảnh vẽ sẵn (cc_may.gd), không vẽ trong shader nữa
 float cl=0.;

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
 vec2 buv=clamp((uv-uSub.xy)/uSub.zw,vec2(0.),vec2(1.));
 if(uNoBank>.5)return vec4(0.);
 vec2 TS=vec2(textureSize(uBankTex,0));
 // bờ ghép trong SubViewport: màu đã nhân alpha -> chia lại. uBankN = chỉ phần đèn (bank9/den.py), cộng vào ban đêm
 vec4 b; vec4 bn;
 if(uExact>.5){ivec2 ip=ivec2(min(buv*TS,TS-1.)); b=texelFetch(uBankTex,ip,0); bn=texelFetch(uBankN,ip,0);}
 else{b=texture(uBankTex,buv); bn=texture(uBankN,buv);}
 b.rgb/=max(b.a,1e-3); bn.rgb/=max(bn.a,1e-3);
 vec3 lit=bn.rgb;
 // ban ngày giữ đúng màu ảnh nông trại (màu giờ chỉ tác dụng lúc chiều tối / đêm)
 float mx=max(uTint.r,max(uTint.g,uTint.b));
 vec3 tt=mix(uTint,vec3(1.),smoothstep(.85,.95,mx));
 vec3 col=b.rgb*tt+lit*uNight*1.6;
 col=mix(col,vec3(dot(col,vec3(.3,.5,.2)))*vec3(.9,.95,1.02),uRain*.35);
 return vec4(col,b.a);
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
var bnode: Node2D = null          # bờ vẽ trực tiếp: mỗi món 1 Sprite2D, chung 1 atlas (ít lệnh vẽ), cây nghiêng quanh gốc như nông trại
var bmat: ShaderMaterial = null
var may_s = null    # mây trên màn (sau bờ)
var sun = null      # mặt trời trên màn (shader Godot)
var may_v = null    # mây trong SubViewport (để nước soi)
const LIVE_SH := """
shader_type canvas_item;
// Bờ bên kia vẽ trực tiếp lên màn (không qua SubViewport). Ngày = TEXTURE, đèn đêm = uN (atlas nửa cỡ, cùng UV).
// Cây (alpha đánh dấu 254/255) nghiêng quanh gốc: sin(t*1.1 + pha)*.017 rad, pha theo chỗ đứng = y như nông trại.
uniform sampler2D uN : filter_linear;
uniform vec3 uTint = vec3(1.); uniform float uNight = 0.; uniform float uRain = 0.; uniform float uSway = 1.;
varying float vm;
void vertex(){
 vm = 0.;
 if(COLOR.a>0.993&&COLOR.a<0.998){
  vm = 1.;
  if(uSway>0.){
   vec2 wo=MODEL_MATRIX[3].xy;
   float ph=fract(sin(dot(floor(wo),vec2(12.9898,78.233)))*43758.5453)*6.2832;
   float a=sin(TIME*1.1+ph)*.017;
   float c=cos(a), s=sin(a);
   VERTEX=vec2(c*VERTEX.x-s*VERTEX.y, s*VERTEX.x+c*VERTEX.y);}}
}
void fragment(){
 vec4 d=texture(TEXTURE,UV); vec4 n=texture(uN,UV);
 float mx=max(uTint.r,max(uTint.g,uTint.b));
 vec3 tt=mix(uTint,vec3(1.),smoothstep(.85,.95,mx));
 vec3 lit=n.rgb;          // atlas đèn (nửa độ phân giải, cùng UV)
 vec3 col=d.rgb*tt+lit*uNight*1.6;
 col=mix(col,vec3(dot(col,vec3(.3,.5,.2)))*vec3(.9,.95,1.02),uRain*.35);
 COLOR=vec4(col,d.a);
}
"""
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
	may_v = MAY.new(game)
	vp.add_child(may_v)
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
	tmat.set_shader_parameter("uNoBank", 1.0)
	tmat.set_shader_parameter("uNoSun", 1.0)
	sun = SUN.new(game, self)
	add_child(sun)
	may_s = MAY.new(game)
	add_child(may_s)
	bnode = Node2D.new()
	bnode.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(bnode)
	bmat = ShaderMaterial.new()
	var bsh := Shader.new()
	bsh.code = LIVE_SH
	bmat.shader = bsh
	data_img = Image.create(24, 1, false, Image.FORMAT_RGBAF)
	data_tex = ImageTexture.create_from_image(data_img)
	mat.set_shader_parameter("uData", data_tex)
	wmat.set_shader_parameter("uData", data_tex)
	for m in [mat, tmat]:
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
	may_s.rebuild(1.0, game.K)
	may_v.rebuild(scale_s, scale_s, L.yw - L.bankH * 872.0 / 900.0)
	_bank_build()

# BỜ BÊN KIA = ghép ảnh 9px có sẵn của Nông trại (ui/img/cc/bo/, mỗi khung 1 file, bo.json = chỗ đứng từng món,
# toạ độ bờ cũ 5400x900). Chỉ ghép đoạn thấy trên màn, đúng số điểm ảnh máy, 1 lần trong SubViewport
# (ngày, đêm, mặt nạ đung đưa) rồi chép ra 3 ảnh tĩnh. Bờ đất + mép cỏ vẽ bằng code với ảnh nền n2_co / dg2_dat.
const BO := "res://ui/img/cc/bo/"
const SPR_SH := """
shader_type canvas_item;
uniform float fol = 0.; uniform float ph = 0.; uniform float foot = 0.;
// chỉ dùng cho mặt nạ đung đưa. SubViewport (gl_compatibility) đổi màu shader tự viết sRGB -> tuyến tính, nên ghi pow(1/2.2)
void fragment(){ float a=texture(TEXTURE,UV).a*COLOR.a; COLOR=vec4(pow(vec3(ph,fol,foot),vec3(1./2.2)),a); }
"""
var _bo := {}
var _opim := {}         # (bản 530) hình vườn dùng chung: tên -> bytes webp đã tải (bo.json "op", tools/cc/op_share.py)
var _spr_sh: Shader
var _mats := {}

func _bo_load() -> bool:
	if not _bo.is_empty():
		return true
	var t := FileAccess.get_file_as_string(BO + "bo.json")
	var j = JSON.parse_string(t)
	if typeof(j) != TYPE_DICTIONARY:
		return false
	_bo = j
	_spr_sh = Shader.new()
	_spr_sh.code = SPR_SH
	return true

func _mat(hz: float, fol: float, mode: int, ph := 0.0, foot := 0.0) -> ShaderMaterial:
	# ngày / đêm: KHÔNG dùng shader riêng. Godot 4.5 (gl_compatibility) vẽ shader canvas tự viết trong SubViewport bị đổi
	# sRGB -> tuyến tính: màu tối hẳn đi (80,150,40 -> 25,88,6) = cây "xanh lè" (Link 11-22). Chỉ lớp mặt nạ đung đưa dùng.
	if mode != 2:
		return null
	var k := "%d_%.3f_%.3f" % [int(fol), ph, foot]
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = _spr_sh
		m.set_shader_parameter("fol", fol)
		m.set_shader_parameter("ph", ph)
		m.set_shader_parameter("foot", foot)
		_mats[k] = m
	return _mats[k]

func _bo_img(name: String) -> Image:
	if _opim.has(name):   # hình vườn dùng chung: giải nén lúc cần (giữ bytes nén cho nhẹ RAM), xoá bóng + cắt lề
		return _op_img(name)
	var b := FileAccess.get_file_as_bytes(BO + name + ".webp")
	var im := Image.new()
	if b.is_empty() or im.load_webp_from_buffer(b) != OK:
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im

# (bản 530) tải hình vườn: n/op/<tên>.webp (vườn: base_url của vườn; bản chơi riêng nằm ở <vườn>/cauca/ nên "../")
func _op_base() -> String:
	if game.host != null and game.host.has("base"):
		return str(game.host.base.call())
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("new URL('..', location.href).href"))
	return OS.get_environment("NT_BASE")

func _op_prep(names: Array) -> void:
	var op: Dictionary = _bo.get("op", {})
	var q := []
	for nm in names:
		if op.has(nm) and not _opim.has(nm) and not q.has(nm):
			q.append(nm)
	if q.is_empty():
		return
	var base := _op_base()
	print("QK op0 ", base, " ", q.size())
	var got := {}
	var live := [0]
	var i := 0
	while got.size() < q.size():
		while live[0] < 8 and i < q.size():   # 8 file một lúc
			var nm: String = q[i]
			i += 1
			live[0] += 1
			var h := HTTPRequest.new()
			h.download_chunk_size = 1 << 20
			add_child(h)
			h.request_completed.connect(func(res, code, _hd, body: PackedByteArray):
				live[0] -= 1
				got[nm] = body if res == HTTPRequest.RESULT_SUCCESS and code == 200 else PackedByteArray()
				h.queue_free())
			if h.request(base + String(op[nm].f)) != OK:
				live[0] -= 1
				got[nm] = PackedByteArray()
				h.queue_free()
		await get_tree().process_frame
	for nm in q:
		if not (got[nm] as PackedByteArray).is_empty():
			_opim[nm] = got[nm]
	print("QK op ", base, " ", q.size(), " ", _opim.size(), " ", q[0])

func _op_img(nm: String) -> Image:
	var im := Image.new()
	if im.load_webp_from_buffer(_opim[nm]) != OK:
		return null
	im.convert(Image.FORMAT_RGBA8)
	var e: Dictionary = _bo.op[nm]
	var rr: Array = e.get("r", [])
	var k := 0
	while k + 2 < rr.size():   # xoá bóng tròn dưới gốc (vườn nhìn từ trên xuống)
		im.fill_rect(Rect2i(int(rr[k + 1]), int(rr[k]), int(rr[k + 2]), 1), Color(0, 0, 0, 0))
		k += 3
	if e.has("cr"):
		var c: Array = e.cr
		im = im.get_region(Rect2i(int(c[0]), int(c[1]), int(c[2]), int(c[3])))
	return im

func _ground(x: float) -> float:
	var g: Array = _bo.ground
	var fi := (x - float(_bo.gx0)) / float(_bo.gdx)
	var i := clampi(int(floor(fi)), 0, g.size() - 2)
	var t := clampf(fi - i, 0.0, 1.0)
	return lerpf(float(g[i]), float(g[i + 1]), t)

func _bank_build() -> void:
	var L: Dictionary = game.L
	var K: float = game.K
	if not _bo_load():
		return
	var c0: float = clampf(-L.bankX - 8.0, 0.0, L.bankW)
	var c1: float = clampf(L.W - L.bankX + 8.0, 0.0, L.bankW)
	var f: float = minf(9.0, L.bankH * K / 900.0)        # điểm ảnh máy / đơn vị bờ
	var u0: float = c0 / L.bankW * 5400.0
	var u1: float = c1 / L.bankW * 5400.0
	var tw := maxi(8, int(ceil((u1 - u0) * f)))
	var th := maxi(8, int(round(900.0 * f)))
	var key := "%d_%d_%d" % [int(u0), int(u1), th]
	if key == _bank_key:
		return
	print("QK build ", key)
	_bank_key = key
	var sub := Vector4(c0 / L.bankW, 0, (c1 - c0) / L.bankW, 1)
	if _bank_cached(key, sub):
		return
	_compose(key, u0, u1, f, tw, th, sub)

# ảnh bờ đã dựng lần trước (cùng cỡ màn, xem A.cache_get): 2 ảnh cho nước soi + 2 atlas + chỗ từng món
func _bank_ck(key: String) -> String:
	return "bank_%s_%.3f_%.3f" % [key, scale_s, K_of()]

func _bank_cached(key: String, sub: Vector4) -> bool:
	var ck := _bank_ck(key)
	var spr = A.cache_get_v(ck + "_m")
	if not (spr is Array):
		return false
	var im := []
	for n in ["_w0", "_w1", "_a0", "_a1"]:
		var x: Image = A.cache_get(ck + n)
		if x == null:
			return false
		im.append(x)
	for m in [mat, tmat]:
		m.set_shader_parameter("uBankTex", ImageTexture.create_from_image(im[0]))
		m.set_shader_parameter("uBankN", ImageTexture.create_from_image(im[1]))
		m.set_shader_parameter("uSub", sub)
	_live_apply(im[2], im[3], spr)
	return true

func _compose(key: String, u0: float, u1: float, f: float, tw: int, th: int, sub: Vector4) -> void:
	var items: Dictionary = _bo.items
	var hzs: Array = [0, 0, 0, 0, 0]      # không phủ màu trời lên cây sau (Link 11-22)
	# món nào thấy được + cần thu nhỏ bao nhiêu
	var need := {}
	var vis := []
	for p in _bo.place:
		if p[1] == "#bo":
			vis.append(p)
			continue
		var it: Dictionary = items[p[1]]
		var sc: float = absf(float(p[4]))
		var x: float = p[2]
		if x + it.w * sc < u0 - 20 or x - it.w * sc > u1 + 20:
			continue
		vis.append(p)
		need[p[1]] = maxf(need.get(p[1], 0.0), sc * f)
	# hình vườn dùng chung: tải file của Nông trại trước (song song, trình duyệt giữ sẵn nếu vườn đã hiện)
	var want := ["n2_co", "dg2_dat"]
	for nm in need:
		want.append(nm + "_d")
	await _op_prep(want)
	if key != _bank_key:
		return
	# mỗi chỗ đặt = 1 ảnh thu đúng cỡ trên màn (Lanczos 1 lần từ ảnh trung gian), vẽ 1:1 ở điểm ảnh nguyên -> nét
	var mid := [{}, {}]
	for nm in need:
		for m in 2:
			var im := _bo_img(nm + ("_d" if m == 0 else "_n"))
			if im == null:
				continue
			var r: float = minf(1.0, need[nm] * 2.0)
			if r < 0.95:
				im.resize(maxi(1, int(round(im.get_width() * r))), maxi(1, int(round(im.get_height() * r))), Image.INTERPOLATE_LANCZOS)
			mid[m][nm] = im
	var tex := [{}, {}]
	var imgs := [{}, {}]
	for p in vis:
		if p[1] == "#bo" or not mid[0].has(p[1]):
			continue
		var it: Dictionary = items[p[1]]
		var sc: float = absf(float(p[4])) * f
		var w := maxi(1, int(round(float(it.w) * sc)))
		var h := maxi(1, int(round(float(it.h) * sc)))
		var fl: bool = float(p[4]) < 0
		var ck := "%s_%d_%d_%d" % [p[1], w, h, int(fl)]
		for m in 2:
			if imgs[m].has(ck):
				continue
			var src: Image = mid[m].get(p[1], mid[0][p[1]])
			var im := src.duplicate() as Image
			if im.get_width() != w or im.get_height() != h:
				im.resize(w, h, Image.INTERPOLATE_LANCZOS)
			if fl:
				im.flip_x()
			imgs[m][ck] = im
		p.resize(6)
		p.append(ck)
	print("QK mid ", mid[0].size(), " need ", need.size())
	var grass := _bo_img("n2_co")
	var dirt := _bo_img("dg2_dat")
	var tg: Texture2D = null
	var td: Texture2D = null
	if grass:
		grass.generate_mipmaps(); tg = ImageTexture.create_from_image(grass)
	if dirt:
		dirt.generate_mipmaps(); td = ImageTexture.create_from_image(dirt)
	# 0/1 = ảnh ghép ngày/đêm cho bóng dưới nước; 2/3 = hàng cây xa, 4/5 = bờ đất+cỏ (ngày/đêm) cho lớp vẽ trực tiếp.
	# (Link 11-22 "bung ra tới 170MB"): dựng TỪNG SubViewport một rồi bỏ ngay (trước: 6 cái cùng lúc ~40 MB ở máy 4K),
	# và ảnh ghép 0/1 chỉ để nước soi -> thu về cỡ nước (scale_s px/css) thay vì giữ đủ điểm ảnh máy (~18 MB).
	var out := []
	var outi := []
	var parts := [{}, {}]
	var wr: float = minf(1.0, scale_s / maxf(K_of(), 0.01))
	for mode in 6:
		var v := SubViewport.new()
		v.size = Vector2i(tw, th)
		v.transparent_bg = true
		v.disable_3d = true
		v.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(v)
		var root := Node2D.new()
		root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		root.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		v.add_child(root)
		if mode < 2:
			# ảnh từng món lên GPU chỉ cho đúng lượt này (ngày rồi mới tới đêm), xong bỏ
			for ck in imgs[mode]:
				tex[mode][ck] = ImageTexture.create_from_image(imgs[mode][ck])
			_fill(root, mode, vis, tex[mode], hzs, u0, u1, f, tg, td)
		else:
			_fill_part(root, mode % 2, "far" if mode < 4 else "bo", u0, u1, f, tg, td)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if key != _bank_key:
			v.queue_free()
			return
		var im: Image = v.get_texture().get_image()
		v.queue_free()
		if mode < 2:
			tex[mode] = {}              # ảnh từng món trên GPU chỉ cần cho ảnh ghép này -> bỏ ngay
			if wr < 0.95:
				im.resize(maxi(8, int(round(tw * wr))), maxi(8, int(round(th * wr))), Image.INTERPOLATE_LANCZOS)
			im.generate_mipmaps()
			outi.append(im)
			out.append(ImageTexture.create_from_image(im))
		else:
			# (đa giác không khử răng cưa: alpha chỉ 0/255, khỏi chia lại alpha)
			var nm := "#far" if mode < 4 else "#bo"
			if mode % 2 == 0:
				parts[0][nm + "_r"] = im.get_used_rect()
			var rr: Rect2i = parts[0][nm + "_r"]
			parts[mode % 2][nm] = im.get_region(rr)
	for m in [mat, tmat]:
		m.set_shader_parameter("uBankTex", out[0])
		m.set_shader_parameter("uBankN", out[1])
		m.set_shader_parameter("uSub", sub)
	var lv: Array = _live_build(vis, imgs, parts, u0, f)
	var ck := _bank_ck(key)
	A.cache_put(ck + "_w0", outi[0])
	A.cache_put(ck + "_w1", outi[1])
	A.cache_put(ck + "_a0", lv[0])
	A.cache_put(ck + "_a1", lv[1])
	A.cache_put_v(ck + "_m", lv[2])     # ghi sau cùng: thiếu file này = chưa lưu đủ, dựng lại

func K_of() -> float:
	return float(game.K)

static func _unpremul(im: Image) -> void:
	var b := im.get_data()
	for i in range(0, b.size(), 4):
		var a := b[i + 3]
		if a > 0 and a < 255:
			b[i] = mini(255, b[i] * 255 / a); b[i + 1] = mini(255, b[i + 1] * 255 / a); b[i + 2] = mini(255, b[i + 2] * 255 / a)
	im.set_data(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8, b)

# lớp bờ vẽ trực tiếp: xếp mọi ảnh vào 1 atlas ngày + 1 atlas đêm (cùng chỗ), mỗi món 1 Sprite2D vùng atlas, đúng thứ tự cũ
func _live_build(vis: Array, imgs: Array, parts: Array, u0: float, f: float) -> Array:
	var keys := []
	var seen := {}
	for nm in ["#far", "#bo"]:
		if parts[0].has(nm):
			keys.append(nm); seen[nm] = true
	for p in vis:
		if p.size() >= 7 and not seen.has(p[6]) and imgs[0].has(p[6]):
			keys.append(p[6]); seen[p[6]] = true
	var AW := 4096
	var pos := {}
	var x := 0; var y := 0; var rh := 0
	var srt := keys.duplicate()
	srt.sort_custom(func(a, b): return _li(imgs, parts, a, 0).get_height() > _li(imgs, parts, b, 0).get_height())
	for k in srt:
		var im: Image = _li(imgs, parts, k, 0)
		var w := im.get_width() + 2; var h := im.get_height() + 2
		if x + w > AW:
			x = 0; y += rh; rh = 0
		pos[k] = Vector2i(x + 1, y + 1)
		x += w; rh = maxi(rh, h)
	var AH := y + rh
	var atl := [Image.create(AW, maxi(AH, 4), false, Image.FORMAT_RGBA8), Image.create(AW, maxi(AH, 4), false, Image.FORMAT_RGBA8)]
	for m in 2:
		for k in keys:
			var im: Image = _li(imgs, parts, k, m)
			atl[m].blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), pos[k])
	# đèn đêm = quầng mềm -> giữ nửa độ phân giải (bớt ~13 MB ở máy 4K), cùng UV với atlas ngày
	atl[1].resize(maxi(2, AW / 2), maxi(2, atl[1].get_height() / 2), Image.INTERPOLATE_BILINEAR)
	print("bank atlas ", AW, "x", AH, " items ", keys.size())
	var items: Dictionary = _bo.items
	var spr := []      # [vùng atlas, chân, góc trên trái, đung đưa]
	var mk := func(k: String, tl: Vector2, foot: Vector2, sway: bool) -> void:
		var im: Image = _li(imgs, parts, k, 0)
		spr.append([Rect2(Vector2(pos[k]), Vector2(im.get_size())), foot, tl, sway])
	if parts[0].has("#far"):
		var r: Rect2i = parts[0]["#far_r"]
		mk.call("#far", Vector2(r.position) + Vector2(round(u0 * f), 0), Vector2(r.position) + Vector2(round(u0 * f), 0), false)
	for p in vis:
		if p[1] == "#bo":
			if parts[0].has("#bo"):
				var r: Rect2i = parts[0]["#bo_r"]
				mk.call("#bo", Vector2(r.position) + Vector2(round(u0 * f), 0), Vector2(r.position) + Vector2(round(u0 * f), 0), false)
			continue
		if p.size() < 7 or not pos.has(p[6]):
			continue
		var it: Dictionary = items[p[1]]
		var sc: float = absf(float(p[4])) * f
		var im: Image = imgs[0][p[6]]
		var ax: float = float(it.ax) * sc
		if float(p[4]) < 0:
			ax = im.get_width() - ax
		var ay: float = float(it.ay) * sc
		var tl := Vector2(round(float(p[2]) * f - ax), round(float(p[3]) * f - ay))
		var foot := tl + Vector2(round(ax), round(ay))
		mk.call(p[6], tl, foot, float(p[5]) > 0.5)
	print("QK done")
	_live_apply(atl[0], atl[1], spr)
	return [atl[0], atl[1], spr]

func _live_apply(a0: Image, a1: Image, spr: Array) -> void:
	var L: Dictionary = game.L
	var K: float = game.K
	for ch in bnode.get_children():
		ch.queue_free()
	var td := ImageTexture.create_from_image(a0)
	bmat.set_shader_parameter("uN", ImageTexture.create_from_image(a1))
	var btop: float = L.yw - L.bankH * 872.0 / 900.0
	bnode.position = Vector2(round(L.bankX * K), round(btop * K)) / K
	bnode.scale = Vector2.ONE / K
	for e in spr:
		var s := Sprite2D.new()
		s.texture = td
		s.centered = false
		s.region_enabled = true
		s.region_rect = e[0]
		s.position = e[1]
		s.offset = e[2] - e[1]
		s.material = bmat
		if e[3]:
			s.self_modulate = Color(1, 1, 1, 254.0 / 255.0)
		bnode.add_child(s)

func _li(imgs: Array, parts: Array, k: String, m: int) -> Image:
	if k.begins_with("#"):
		return parts[m][k]
	return imgs[m].get(k, imgs[0][k])

func _fill_part(root: Node2D, mode: int, what: String, u0: float, u1: float, f: float, tg: Texture2D, td: Texture2D) -> void:
	var nc := Color.BLACK if mode == 1 else Color.WHITE     # ảnh đêm = chỉ phần đèn: đất/cỏ/hàng cây xa không có đèn
	if what == "far":
		var far := Polygon2D.new()
		var pts := PackedVector2Array(); var cols := PackedColorArray()
		for q in _bo.far:
			pts.append(Vector2((float(q[0]) - u0) * f, float(q[1]) * f))
			var t := clampf((float(q[1]) - (872.0 - 190.0)) / 150.0, 0.0, 1.0)
			cols.append(Color("#8cc86a").lerp(Color("#4e8a4a"), t) * nc)
		far.polygon = pts
		far.vertex_colors = cols
		root.add_child(far)
	else:
		var bo := Node2D.new()
		bo.draw.connect(_draw_bo.bind(bo, mode, u0, u1, f, tg, td))
		root.add_child(bo)

func _fill(root: Node2D, mode: int, vis: Array, tx: Dictionary, hzs: Array, u0: float, u1: float, f: float, tg: Texture2D, td: Texture2D) -> void:
	var items: Dictionary = _bo.items
	var nc := Color.BLACK if mode == 1 else Color.WHITE     # ảnh đêm = chỉ phần đèn: đất/cỏ/hàng cây xa không có đèn
	# hàng cây xa (lớp 0): đa giác tô dọc
	var far := Polygon2D.new()
	var pts := PackedVector2Array(); var cols := PackedColorArray()
	for q in _bo.far:
		pts.append(Vector2((float(q[0]) - u0) * f, float(q[1]) * f))
		var t := clampf((float(q[1]) - (872.0 - 190.0)) / 150.0, 0.0, 1.0)
		cols.append(Color("#8cc86a").lerp(Color("#4e8a4a"), t) * nc)
	far.polygon = pts
	far.vertex_colors = cols
	far.material = _mat(float(hzs[0]), 1.0, mode)
	root.add_child(far)
	for p in vis:
		var Lr: int = int(p[0])
		if p[1] == "#bo":
			var bo := Node2D.new()
			bo.material = _mat(0.0, 0.0, mode)
			bo.draw.connect(_draw_bo.bind(bo, mode, u0, u1, f, tg, td))
			root.add_child(bo)
			continue
		if p.size() < 7 or not tx.has(p[6]):
			continue
		var it: Dictionary = items[p[1]]
		var t: Texture2D = tx[p[6]]
		var sc: float = absf(float(p[4])) * f
		var ax: float = float(it.ax) * sc
		if float(p[4]) < 0:
			ax = t.get_width() - ax
		var pos := Vector2(round((float(p[2]) - u0) * f - ax), round(float(p[3]) * f - float(it.ay) * sc))
		var ph := fposmod(float(p[2]) * 0.6180339 + float(p[3]) * 0.137, 1.0)
		var m := _mat(0.0, float(p[5]), mode, ph, clampf(float(p[3]) / 900.0, 0.0, 1.0))
		# mặt nạ đung đưa nới rộng 2 bên (cây nghiêng ra ngoài bóng cũ vẫn có mặt nạ để kéo theo)
		var offs := [0.0]
		if mode == 2 and float(p[5]) > 0.5:
			var dd := ceilf(float(it.ay) * sc * 0.024)
			offs = [-dd, dd, 0.0]
		for o in offs:
			var s := Sprite2D.new()
			s.texture = t
			s.centered = false
			s.position = pos + Vector2(o, 0)
			s.material = m
			root.add_child(s)

func _draw_bo(n: Node2D, mode: int, u0: float, u1: float, f: float, tg: Texture2D, td: Texture2D) -> void:
	var nc := Color.BLACK if mode == 1 else Color.WHITE     # ảnh đêm = chỉ phần đèn: đất/cỏ/hàng cây xa không có đèn
	var WL := 872.0
	var x := floorf((u0 - 40.0) / 10.0) * 10.0
	while x < u1 + 40.0:
		var x2 := x + 10.0
		var g1 := _ground(x); var g2 := _ground(x2)
		var X1 := (x - u0) * f; var X2 := (x2 - u0) * f
		# vách đất: sáng trên, tối dần xuống mép nước
		for band in [[g1, g2, WL - 16.0, Color(1.0, .94, .86), Color(.80, .68, .56)], [WL - 16.0, WL - 16.0, WL + 6.0, Color(.80, .68, .56), Color(.42, .33, .26)]]:
			var ya1: float = band[0]; var ya2: float = band[1]; var yb: float = band[2]
			var ca: Color = band[3]; var cb: Color = band[4]
			var P := PackedVector2Array([Vector2(X1, ya1 * f), Vector2(X2, ya2 * f), Vector2(X2, yb * f), Vector2(X1, yb * f)])
			var UV := PackedVector2Array([Vector2(x / 420.0, ya1 / 420.0), Vector2(x2 / 420.0, ya2 / 420.0), Vector2(x2 / 420.0, yb / 420.0), Vector2(x / 420.0, yb / 420.0)])
			n.draw_polygon(P, PackedColorArray([ca * nc, ca * nc, cb * nc, cb * nc]), UV, td)
		# mép cỏ: dải cỏ phủ lên đầu vách, sáng ở trên
		var e1 := g1 + 12.0 + 3.0 * sin(x / 37.0); var e2 := g2 + 12.0 + 3.0 * sin(x2 / 37.0)
		var Pg := PackedVector2Array([Vector2(X1, (g1 - 3.0) * f), Vector2(X2, (g2 - 3.0) * f), Vector2(X2, e2 * f), Vector2(X1, e1 * f)])
		var UVg := PackedVector2Array([Vector2(x / 300.0, g1 / 300.0), Vector2(x2 / 300.0, g2 / 300.0), Vector2(x2 / 300.0, e2 / 300.0), Vector2(x / 300.0, e1 / 300.0)])
		var ct := Color(1.35, 1.4, 1.1) * nc; var cbt := Color(.8, .85, .7) * nc
		n.draw_polygon(Pg, PackedColorArray([ct, ct, cbt, cbt]), UVg, tg)
		x = x2

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

# đặt thông số shader chỉ khi giá trị đổi (đa số đứng yên: cỡ màn, bờ, màu trời đổi rất chậm) -> bớt việc mỗi khung
var _uc := {}
func _su(m: ShaderMaterial, k: String, v) -> void:
	var d: Dictionary = _uc.get(m, {})
	if d.is_empty():
		_uc[m] = d
	var o = d.get(k)
	if o != null and typeof(o) == typeof(v) and o == v:
		return
	d[k] = v
	m.set_shader_parameter(k, v)

func _scene_u(m: ShaderMaterial, s: float, res: Vector2, t: float, tod: Dictionary, W: Dictionary) -> void:
	var L: Dictionary = game.L
	_su(m, "uRes", res)
	_su(m, "uT", fmod(t, 1000.0))
	_su(m, "uHor", L.hor * s)
	_su(m, "uYw", L.yw * s)
	_su(m, "uF", L.F * s)
	_su(m, "uS", s)
	var btop: float = L.yw - L.bankH * 872.0 / 900.0
	_su(m, "uBank", Vector4(L.bankX * s, btop * s, L.bankW * s, L.bankH * s))
	for k in [["uTop", "top"], ["uHorC", "hor"], ["uSunC", "sun"], ["uTint", "tint"], ["uWater", "water"], ["uCloudC", "cloud"], ["uFog", "fog"]]:
		var c: Color = tod[k[1]]
		_su(m, k[0], Vector3(c.r, c.g, c.b))
	var sp := sun_screen(tod)
	_su(m, "uSun", Vector3(sp.x * s, sp.y * s, tod.si * (1 - W.rain * .97) if tod.sunUp else 0.0))
	_su(m, "uMoon", Vector3(tod.sunX * L.W * s, (L.yw - (L.yw - L.H * .08) * tod.sunElev) * s, tod.moon * (1 - W.rain)))
	_su(m, "uStar", tod.star * (1 - W.rain))
	_su(m, "uNight", tod.night)
	_su(m, "uRain", W.rain)
	_su(m, "uWind", W.wind)
	_su(m, "uCloud", W.cloud)
	var fg: Array = W.floatGlow
	_su(m, "uFlt", Vector4(fg[0], fg[1], 0, fg[2]))
	_su(m, "uOld", 1.0 if old_water else 0.0)

func render(t: float, tod: Dictionary, W: Dictionary, rips: PackedFloat32Array, shs: PackedFloat32Array) -> void:
	var L: Dictionary = game.L
	_scene_u(mat, scale_s, Vector2(vp.size), t, tod, W)
	_scene_u(tmat, game.K, Vector2(L.W, L.H) * game.K, t, tod, W)
	_su(tmat, "uExact", 1.0)
	may_s.upd(t, tod, W)
	sun.upd(tod, W)
	may_v.upd(t, tod, W)
	if bmat:
		var tc: Color = tod.tint
		_su(bmat, "uTint", Vector3(tc.r, tc.g, tc.b))
		_su(bmat, "uNight", tod.night)
		_su(bmat, "uRain", W.rain)
	var ywc := floorf(L.yw * scale_s) / scale_s
	_su(tmat, "uUV", Vector2(1.0, ywc / L.H))
	var m := mat
	var s := scale_s
	wrect.visible = not old_water
	if not old_water:
		var wm := wmat
		var ywp := floorf(L.yw * s)
		_su(wm, "uRes", Vector2(vp.size))
		_su(wm, "uT", fmod(t, 1000.0))
		_su(wm, "uHor", L.hor * s)
		_su(wm, "uYw", ywp)
		_su(wm, "uF", L.F * s)
		for k in [["uSunC", "sun"], ["uTint", "tint"], ["uWater", "water"], ["uFog", "fog"]]:
			var c: Color = tod[k[1]]
			_su(wm, k[0], Vector3(c.r, c.g, c.b))
		for k in ["uSun", "uMoon", "uNight", "uRain", "uWind", "uFlt"]:
			_su(wm, k, m.get_shader_parameter(k))
	for i in 16:
		data_img.set_pixel(i, 0, Color(rips[i * 4], rips[i * 4 + 1], rips[i * 4 + 2], rips[i * 4 + 3]))
	for i in 8:
		data_img.set_pixel(16 + i, 0, Color(shs[i * 4], shs[i * 4 + 1], shs[i * 4 + 2], shs[i * 4 + 3]))
	data_tex.update(data_img)
