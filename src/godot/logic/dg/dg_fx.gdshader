shader_type canvas_item;
render_mode blend_premul_alpha;
// hiệu ứng skill / món đồ của Đua Gà (bản web: sec_fxgl.js, một shader WebGL2), chép nguyên các hình.
// CUSTOM0 = (1 + hình + 50 viền mực + 100 lớp sáng, tuổi 0..1, hạt ngẫu nhiên, w). CUSTOM0.x = 0: vẽ thường (ảnh, chữ).
varying vec4 vQ;
void vertex(){ vQ = CUSTOM0; }
float h1(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n2(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(h1(i),h1(i+vec2(1,0)),f.x),mix(h1(i+vec2(0,1)),h1(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<4;i++){v+=a*n2(p);p=p*2.03+7.1;a*=.5;}return v;}
vec3 lit(vec3 c,float k){return c+(1.-c)*k;}
vec3 inkOf(vec3 c){return mix(c*.32,vec3(.2,.11,.05),.35);}
float star5(vec2 p,float r,float rf){const vec2 k1=vec2(.809016994,-.587785252),k2=vec2(-.809016994,-.587785252);p.x=abs(p.x);p-=2.*max(dot(k1,p),0.)*k1;p-=2.*max(dot(k2,p),0.)*k2;p.x=abs(p.x);p.y-=r;
  vec2 ba=rf*vec2(-k1.y,k1.x)-vec2(0,1);float h=clamp(dot(p,ba)/dot(ba,ba),0.,r);return length(p-ba*h)*sign(p.y*ba.x-p.x*ba.y);}
float ucap(vec2 p,float r1,float r2,float h){p.x=abs(p.x);float b=(r1-r2)/h,a=sqrt(1.-b*b),k=dot(p,vec2(-b,a));if(k<0.)return length(p)-r1;if(k>a*h)return length(p-vec2(0.,h))-r2;return dot(p,vec2(a,b))-r1;}

void fragment(){
  if (vQ.x < 0.5) { COLOR.rgb *= COLOR.a; }
  else {
  vec4 vC = COLOR;
  float tq = vQ.x - 1.0; float uL = 0.0; if (tq > 99.5) { uL = 1.0; tq -= 100.0; }
  vec2 u=UV;float d=length(u),t=tq,ik=0.;if(t>49.5){ik=1.;t-=50.;}t=floor(t+.5);
float age=vQ.y,sd=vQ.z,w=vQ.w,a=0.,s=1.;vec3 b=vC.rgb,c=b;
  float aa=max(max(fwidth(u.x),fwidth(u.y)),.0005),ew=min(aa*2.2,.28);
  if(t<.5){a=exp(-d*d*4.5);c=lit(b,exp(-d*d*22.)*w*.5);}
  else if(t<1.5){
    vec2 p=vec2(u.x,-u.y)/max(.3,1.-age*.55);float k=fbm(vec2(p.x*2.,p.y*1.5-age*4.)+sd*9.);
    p.x+=(k-.5)*.45*(p.y+.6)+sin(p.y*4.+age*10.+sd*6.)*.06*(p.y+.6);
    s=ucap(p+vec2(0.,.42),.48,.04,1.3)+(k-.5)*.16;
    c=vec3(.88,.22,.05);c=mix(c,vec3(1.,.56,.12),1.-smoothstep(-aa,aa,s+.13));c=mix(c,vec3(1.,.86,.36),1.-smoothstep(-aa,aa,s+.28-.05*p.y));
    c*=b;a=1.-smoothstep(-aa,aa,s);c=mix(c,vec3(.5,.09,.02),ik*smoothstep(-ew-aa,-ew+aa,s));a*=1.-smoothstep(.75,1.,age);}
  else if(t<2.5){
    float k=fbm(u*1.6+sd*9.+vec2(age*.5,-age*.8));
    vec2 o1=vec2(-.3,.12)+.08*vec2(sin(sd*21.),cos(sd*17.)),o2=vec2(.3,.16)+.08*vec2(cos(sd*13.),sin(sd*29.)),o3=vec2(.02,-.24);
    s=min(min(length(u-o1)-.42,length(u-o2)-.38),min(length(u-o3)-.44,length(u-vec2(0.,.2))-.4))+(k-.5)*.12;
    float sh=smoothstep(-.2,.3,u.y+u.x*.2+(k-.5)*.35);
    c=mix(lit(b,.6),b*.9,sh);
    a=(1.-smoothstep(-aa,aa,s))*mix(1.,smoothstep(.2,.6,k+.45-age*.55),smoothstep(.25,.95,age));
    c=mix(c,mix(b*.66,vec3(.42,.3,.18),.35),ik*w*smoothstep(-ew-aa,-ew+aa,s)*smoothstep(-.15,.35,u.y));}
  else if(t<3.5){a=exp(-u.x*u.x*2.2-u.y*u.y*14.);c=lit(b,exp(-u.y*u.y*60.-u.x*u.x*4.)*.4);}
  else if(t<4.5){
    float r=d-.84,hw=w*.5;s=abs(r)-hw;a=1.-smoothstep(-aa,aa,s);
    c=mix(b,lit(b,.45),(1.-smoothstep(-aa,aa,abs(r+hw*.2)-hw*.28))*.85);
    c=mix(c,inkOf(b),ik*.85*smoothstep(-ew*.7-aa,-ew*.7+aa,s));
    a=max(a,exp(-r*r/(w*w*3.))*.28+.09*(1.-smoothstep(0.,.84,d))*(1.-age));}
  else if(t<5.5){
    vec2 p=vec2(u.x,-u.y);s=star5(p,.94,.46);a=1.-smoothstep(-aa,aa,s);
    c=mix(b,lit(b,.5),1.-smoothstep(-aa,aa,star5(p-vec2(-.06,.08),.5,.46)));c=mix(c,inkOf(b),ik*smoothstep(-ew-aa,-ew+aa,s));}
  else if(t<6.5){float x=abs(u.x),y=abs(u.y);a=min(1.,exp(-x*14.)*exp(-y*2.4)+exp(-y*14.)*exp(-x*2.4)+exp(-d*d*9.)*.7);c=lit(b,exp(-d*d*30.)*.45);}
  else if(t<7.5){s=max(abs(u.x),abs(u.y))-.9;
    // w > .5: a clod, an uneven lump with five corners of its own
    if(w>1.5){float f=fract(atan(u.y,u.x)/6.2832+.5)*4.,i=floor(f),zz=abs(fract(f*3.)-.5)*.14;s=d-mix(.5+.35*h1(vec2(i,sd*13.)),.5+.35*h1(vec2(mod(i+1.,4.),sd*13.)),fract(f))+zz;}
    else if(w>.5){float f=fract(atan(u.y,u.x)/6.2832+.5)*5.,i=floor(f);s=d-mix(.62+.3*h1(vec2(i,sd*17.)),.62+.3*h1(vec2(mod(i+1.,5.),sd*17.)),fract(f));}
    a=1.-smoothstep(-aa,aa,s);c=b*(.92-.12*u.y);if(w>1.5)c=mix(lit(b,.35),b*.8,smoothstep(-.3,.6,u.y-u.x*.4));else if(w>.5)c=mix(lit(b,.25),b*.7,clamp(u.x*.35+u.y*.45+.5,0.,1.));c=mix(c,inkOf(b),ik*smoothstep(-ew-aa,-ew+aa,s));}
  else if(t<8.5){
    s=d-.84+(w<.5?.07*sin(atan(u.y,u.x)*5.+sd*20.):0.);a=1.-smoothstep(-aa,aa,s);c=mix(b,b*.72,smoothstep(0.,.8,u.y+u.x*.3)*.7);
    c=mix(c,lit(b,.8),(1.-smoothstep(-aa,aa,length(u-vec2(-.3,-.34))-.2))*w);c=mix(c,inkOf(b),ik*.7*smoothstep(-ew-aa,-ew+aa,s));}
  else if(t<9.5){
    float y=abs(u.y);s=y-.6;a=max(1.-smoothstep(-aa,aa,s),exp(-u.y*u.y*2.)*.3);c=mix(b,lit(b,.45),exp(-u.y*u.y*w));
    c=mix(c,inkOf(b),ik*.75*smoothstep(-ew-aa,-ew+aa,s)*(1.-smoothstep(-aa,aa,s)));}
  else if(t<10.5){
    // a kick's smear: a crescent, fat and solid where the foot is (+x), thinning and fading back along its path,
    // with two speed lines in it
    vec2 q=u-vec2(0.,1.15);float r=length(q)-1.3,k=clamp((u.x+1.)*.5,0.,1.),tp=pow(k,.8)*pow(max(0.,1.-pow(max(0.,u.x-.55)/.45,2.)),.5);
    s=max(r-.2*tp,-r-.05*tp)-.004;a=(1.-smoothstep(-aa,aa,s))*step(abs(u.x),1.)*smoothstep(0.,.55,k);
    c=mix(b,lit(b,.65),1.-smoothstep(-aa,aa,abs(r-.06*tp)-.03*tp));c=mix(c,b*.8,(1.-smoothstep(-aa,aa,abs(r+.01)-.008))*(1.-smoothstep(.5,.9,k))*.8);
    c=mix(c,inkOf(b),ik*smoothstep(-ew*.8-aa,-ew*.8+aa,s)*smoothstep(.2,.6,k));}
  else if(t<11.5||(t>12.5&&t<13.5)){
    float r=d-.8,hw=w*.5*(1.-age*.4),an=abs(atan(u.y,u.x));
    if(t>12.5)hw*=1.-smoothstep(.25,1.05,an)*.75;
    s=abs(r)-hw;a=1.-smoothstep(-aa,aa,s);c=mix(b,lit(b,.5),(1.-smoothstep(-aa,aa,abs(r)-hw*.35))*.7);
    c=mix(c,inkOf(b),ik*.8*smoothstep(-ew*.8-aa,-ew*.8+aa,s));a=max(a,exp(-r*r/(w*w*4.))*.22);
    if(t>12.5)a*=1.-smoothstep(.85,1.1,an);}
  else if(t<12.5){
    // a feather: a bare quill, then a curved vane wider on one side, one split in it, a fluffy base and fine barbs
    // running out towards the tip; w: 0 plain, 1 barred, 2 with a violet sheen
    float x=u.x,bd=(sd>.5?1.:-1.)*.16,dy=u.y-bd*(x*x-.35),v=clamp((x+.6)/1.55,0.,1.),up=step(dy,0.);
    float pf=sqrt(v)*(1.-v*v*v)*1.2,hw=mix(.24,.35,up)*pf;s=abs(dy)-hw;
    s+=.03*sin(x*60.+sd*30.)*(1.-smoothstep(0.,.28,v))*step(.0,v);
    float v0=.36+.3*fract(sd*7.31),sp=abs(v-v0+abs(dy)*.9)-.016;if(abs(dy)>hw*.4&&up>.5)s=max(s,-sp);
    float sq=max(abs(dy)-.03,max(-.97-x,x+.55));s=min(s,sq);
    a=1.-smoothstep(-aa,aa,s);
    c=b*(.94+.06*sin((x-abs(dy)*1.5)*46.+sd*9.));c=mix(c,lit(b,.3),.4*(1.-smoothstep(0.,hw+.001,abs(dy))));
    if(w>.5&&w<1.5)c=mix(c,b*.5,.6*smoothstep(.42,.5,fract(x*2.1-abs(dy)*1.4+sd))*step(.1,v)*step(v,.92));
    if(w>1.5)c=mix(c,vec3(.55,.5,.85),exp(-pow(dy+.08,2.)*90.)*.5);
    c=mix(c,lit(b,.75),(1.-smoothstep(-aa,aa,abs(dy)-.018))*step(-.97,x)*.85);
    c=mix(c,inkOf(b),ik*.7*smoothstep(-ew-aa,-ew+aa,s));}
  else if(t<14.5){
    // a rice leaf: a long blade, blunt at the base, drawn out to a point, bent, a pale midrib
    float x=u.x,y=u.y-.16*(x*x-.3)*(sd>.5?1.:-1.),v=(x+.95)/1.9,hw=.2*pow(max(0.,sin(3.1416*pow(clamp(v,0.,1.),.7))),.8);s=max(abs(y)-hw,abs(x)-.96);
    a=1.-smoothstep(-aa,aa,s);c=mix(lit(b,.22),b*.86,step(0.,y));c=mix(c,lit(b,.5),(1.-smoothstep(-aa,aa,abs(y)-.018))*step(abs(x),.8)*.8);
    c=mix(c,inkOf(b),ik*smoothstep(-ew-aa,-ew+aa,s));}
  else if(t<15.5){
    float an=atan(u.y,u.x)+sd*6.283,r0=.5+.42*pow(abs(cos(an*2.5)),.6);s=(d-r0)*.8;a=1.-smoothstep(-aa,aa,s);
    c=mix(b,b*.86,smoothstep(.25,.9,d/r0));c=mix(c,vec3(.93,.45,.07),1.-smoothstep(-aa,aa,d-.2));c=mix(c,inkOf(b),ik*smoothstep(-ew-aa,-ew+aa,s));}
  else if(t<16.5){
    float r=d-.84;s=abs(r)-.07;a=max(1.-smoothstep(-aa,aa,s),(1.-smoothstep(-aa,aa,d-.84))*.16);
    float g=1.-smoothstep(-aa,aa,length(u-vec2(-.34,-.36))-.15);c=mix(b,lit(b,.85),max(g,(1.-smoothstep(-aa,aa,s))*.3));a=max(a,g);
    a*=1.-smoothstep(.82,1.,age);}
  else if(t>18.5&&t<19.5){
    // a splash of water, mud or milk thrown up off the ground: a sheet flaring out of a puddle into a jagged rim of
    // spikes of uneven height (an even five-point crown read as a king's crown), teardrops flying out of it and
    // falling back; it sinks as it ages. w = gloss
    float g=smoothstep(0.,.22,age),fl=smoothstep(.45,1.,age),Hh=g*(1.-fl*.75),x=u.x;
    float v=clamp((.74-u.y)/.85,0.,1.),hwd=.22+.7*sqrt(v);
    float fx=(x+1.)*3.+fract(sd*3.7),fi=floor(fx),tri=1.-abs(fract(fx)-.5)*2.,hi=.4+.6*h1(vec2(fi,floor(sd*97.)));
    float yt=.74-Hh*(.28+.52*hi*tri*tri+.1*(1.-x*x));
    s=max(max(abs(x)-hwd,yt-u.y),u.y-.78);
    float sr=(length((u-vec2(0.,.74))/vec2(.8,.13))-1.)*.13;s=min(s,sr);
    for(int i=0;i<5;i++){float k=float(i),th=(k-2.)*.55+.3*(h1(vec2(k,sd*7.))-.5),dd=.45+.5*smoothstep(0.,.6,age)+.15*h1(vec2(sd,k));
      vec2 dir=vec2(sin(th),-cos(th)),e=u-(vec2(0.,.6)+dir*dd*g+vec2(0.,.7*fl*fl)),q=vec2(e.x*dir.y-e.y*dir.x,-dot(e,dir));
      s=min(s,ucap(q,.075*g*(1.-fl*.3),.02*g,.16));}
    a=(1.-smoothstep(-aa,aa,s))*(1.-smoothstep(.65,1.,age));
    float inr=smoothstep(.04,-.04,abs(x)-hwd*.7)*smoothstep(yt+.03,yt+.14,u.y)*smoothstep(.76,.6,u.y);
    // shade by multiplying the colour into itself, so white milk goes warm and water goes deeper blue, not grey
    c=mix(lit(b,.45),mix(b*.85,b*b,.5),smoothstep(-.3,.8,u.y));c=mix(c,mix(b*.72,b*b*.9,.5),inr*.65);
    c=mix(c,lit(b,.9),w*(1.-smoothstep(-aa,aa,abs(s+.045)-.016))*step(x,-.05)*.8);
    c=mix(c,inkOf(b),ik*.65*smoothstep(-ew-aa,-ew+aa,s));}
  else if(t>19.5&&t<20.5){
    // a gust of wind: a wavy stroke that curls up at its end, drawing itself on and wiping off from its tail
    float q=-1.;float th=0.;
    float y0=.08*sin((u.x+.95)*3.)+.12,ds=abs(u.y-y0);if(u.x>-.95&&u.x<.4){q=(u.x+.95)/1.35*.55;th=.03+.07*smoothstep(0.,.5,q);s=ds-th;}else s=1000.0;
    vec2 C=vec2(.4,-.14),e=u-C;float an=atan(e.y,e.x),p=fract((1.5708-an)/6.2832);float R=.26*(1.-.45*p),sc=abs(length(e)-R)-(.1*(1.-p*.6));
    if(sc<s){s=sc;q=.55+.45*p;}
    float rv=q<0.?0.:step(q,age*2.4)*step((age-.4)*1.9,q);s=mix(1000.0,s,rv);
    a=1.-smoothstep(-aa,aa,s);c=mix(lit(b,.55),b*.92,smoothstep(-.06,.08,u.y-y0));c=mix(c,inkOf(b),ik*.55*smoothstep(-ew-aa,-ew+aa,s));}
  else if(t>17.5){
    // a lock of fur pulled out of the coat: a round base drawn out into three curved tips (a fluff with hairs all
    // round read as a gear)
    vec2 e=u-vec2(0.,.3);float bd=sd>.5?1.:-1.;e.x+=bd*.4*e.y*e.y;s=1000.0;float st=1000.0;
    for(int i=0;i<3;i++){float k=float(i)-1.,th=k*.7,L=k==0.?.86:.62;vec2 dir=vec2(sin(th),-cos(th)),o=e-vec2(k*.1,0.),q=vec2(o.x*dir.y-o.y*dir.x,dot(o,dir));
      s=min(s,ucap(q,k==0.?.38:.27,.03,L));st=min(st,abs(q.x)+step(q.y,.1)+step(L*.7,q.y));}
    a=1.-smoothstep(-aa,aa,s);c=mix(lit(b,.35),b*.82,clamp(u.y*.5+u.x*.25+.45,0.,1.));
    c=mix(c,b*.62,(1.-smoothstep(.008,.02,st))*.7);c=mix(c,inkOf(b),ik*.65*smoothstep(-ew-aa,-ew+aa,s));}
  else{
    float an=atan(u.y,u.x),f=an/6.2832*9.+sd*7.,i=floor(f),fr=fract(f),L=.74+.26*h1(vec2(i,sd*13.)),tr=abs(fr-.5)*2.;
    float r0=mix(L,.46,tr);s=(d-r0)*.7;a=1.-smoothstep(-aa,aa,s);
    c=mix(b,lit(b,.6),1.-smoothstep(-aa,aa,d-r0*.52));c=mix(c,inkOf(b),ik*smoothstep(-ew-aa,-ew+aa,s));}
  
  a*=vC.a; COLOR=vec4(c*a,a*(1.-uL*.85));
  }
}
