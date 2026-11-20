s=open('index.html').read()
def rep(a,b):
    global s
    assert s.count(a)==1,a;s=s.replace(a,b)
rep("'use strict';","'use strict';window.__T=()=>({state,map:MAP.id,N,raceT:+raceT.toFixed(1),coins:save.coins,daily:save.daily,cups:save.cups,falls:window.__falls||0,drifts:window.__drifts||0,"
  "rs:racers.map(r=>({id:r.ch.id,p:r.ai.pers,prog:r.prog,fin:r.finished,place:r.place,lap:Math.floor(r.prog/N)+1,spd:Math.round(r.spd)}))});"
  "window.__load=id=>{selMap=id;loadMap(id);};window.__save=()=>save;")
rep("if(r.isPlayer&&!r.finished&&!autoRace){","if(r.isPlayer&&!r.finished&&!autoRace&&!window.__auto){")
rep("const WORLD_W=5200, WORLD_H=4200, LAPS=3,","const WORLD_W=5200, WORLD_H=4200, LAPS=(window.__LAPS||3),")
rep("if(state==='menu'||paused)clock+=paused?0:dt;else step(dt);","if(state==='menu'||paused)clock+=paused?0:dt;else for(let k=0;k<(window.__SPEED||1);k++)step(dt);")
rep("function startFall(r){","function startFall(r){window.__falls=(window.__falls||0)+1;")
rep("if(!r.drift&&r.ctlDrift&&Math.abs(r.ctlSteer)>.3&&r.spd>200&&!offroad){","if(!r.drift&&r.ctlDrift&&Math.abs(r.ctlSteer)>.3&&r.spd>200&&!offroad){window.__drifts=(window.__drifts||0)+1;")
open('test.html','w').write(s)
s=open('test.html').read()
def rep2(a,b):
    global s
    assert s.count(a)==1,a;s=s.replace(a,b)
rep2("let AREA=(","let AREA=window.__AREA||(")
rep2("if(++perfN>=90||perfD>=1500){","if((++perfN>=90||perfD>=1500)&&!window.__AREA){(window.__plog=window.__plog||[]).push([+(perfW/perfN).toFixed(1),+(perfD/perfN).toFixed(1),state]);")
_dg="function drawGround(sh){" if "function drawGround(sh){" in s else "function drawGround(){"
rep2(_dg,"window.__pf={g:0,w:0,n:0};"+_dg+"const __t=performance.now();")
rep2("  ctx.drawImage(lo,0,h0,RW,RH-h0,0,h0*K,VW,(RH-h0)*K);\n}","  ctx.drawImage(lo,0,h0,RW,RH-h0,0,h0*K,VW,(RH-h0)*K);window.__pf.g+=performance.now()-__t;\n}")
rep2("function render(){","function render(){const __t0=performance.now();")
rep2("  drawHUD();\n","  drawHUD();window.__pf.w+=performance.now()-__t0;window.__pf.n++;\n")
s=s.replace("window.__save=()=>save;","window.__save=()=>save;window.__artSync=!/nosync/.test(location.search);window.__res=()=>({RW,RH,AREA,LOQ,DPR});window.__pl=()=>player;window.__racers=()=>racers;window.__setLOQ=v=>{LOQ=v};window.__bird=()=>({drawBirdView,CHARS,SHEETC:typeof SHEETC!=='undefined'?SHEETC:{},DUCK_NPC,BI:()=>BI.length,setClock:v=>{clock=v},birdPose:typeof birdPose!=='undefined'?birdPose:null});",1)
open('test.html','w').write(s)
s=open('test.html').read()
rep2("if(!player){// attract mode: glide along the track","if(!player&&window.__camFix){const c=window.__camFix;cam.th=c.th;cam.x=c.x-Math.cos(c.th)*c.d;cam.y=c.y-Math.sin(c.th)*c.d;drawWorld();return;}\n  if(!player){// attract mode: glide along the track")
s=s.replace("window.__save=()=>save;","window.__save=()=>save;window.__models=()=>decor.filter(d=>d.m).map(d=>({t:d.t,x:d.x,y:d.y,rot:d.rot}));",1)
open('test.html','w').write(s)
s=open('test.html').read()
assert s.count("function drawBirdView(")==1
s=s.replace("function drawBirdView(","function drawBirdView(...a){const t=performance.now();__dbv(...a);if(window.__pf)window.__pf.b=(window.__pf.b||0)+performance.now()-t;}\nfunction __dbv(")
open('test.html','w').write(s)
s=open('test.html').read()
if "if(GLG&&GLG.draw(sh))return;" in s:
    s=s.replace("if(GLG&&GLG.draw(sh))return;","if(GLG&&!window.__noGL&&GLG.draw(sh))return;",1)
    s=s.replace("window.__save=()=>save;","window.__save=()=>save;window.__glg=()=>({ex:!!GLG,on:!!(GLG&&GLG.on())});",1)
open('test.html','w').write(s)
s=open('test.html').read()
s=s.replace("window.__save=()=>save;","window.__save=()=>save;window.__trk=i=>({x:PX[i],y:PY[i],a:TA[i],br:BR[i]});window.__brs=()=>{const o=[];for(let i=0;i<N;i++)if(BR[i])o.push(i);return o;};window.__cd=()=>CDIST;window.__wet=v=>{weather.k=v;};",1)
open('test.html','w').write(s)
s=open('test.html').read()
# props on the track without a race: item boxes, the map's mud, and things dropped by hand
s=s.replace("window.__save=()=>save;","window.__save=()=>save;window.__props=()=>{makeBoxes();traps=STATIC_MUD.map(m=>({...m}));return{boxes:MAP.boxes.map(k=>cpIdx(k)),ramps:RAMPS.map(r=>r.i),baskets:BASKETS.map(b=>b.i),mud:STATIC_MUD.map(m=>m.i),pads:PADS.map(p=>p.i)};};"
  "window.__drop=(k,i,o,h)=>{const x=PX[i]+NX[i]*o*WD[i],y=PY[i]+NY[i]*o*WD[i];if(k==='chuoi')traps.push({kind:'chuoi',x,y,r:18,life:1e9,arm:0});else if(k==='bun')traps.push({kind:'bun',x,y,r:h||40,life:1e9,arm:0});else if(k==='egg')eggs.push({x,y,spin:.4,life:1e9});else if(k==='nut')nuts.push({x,y,bounce:0,rot:.6,life:1e9});};",1)
open('test.html','w').write(s)
s=open('test.html').read()
s=s.replace("window.__save=()=>save;","window.__save=()=>save;window.__icons=()=>{const c=document.createElement('canvas');c.width=7*80*2;c.height=160;const g=c.getContext('2d');g.scale(2,2);g.fillStyle='#fff6e0';g.fillRect(0,0,560,80);['ot','trung','chuoi','dua','bun','rom','may'].forEach((k,i)=>drawItemIcon(g,k,40+i*80,36,40));return c.toDataURL();};",1)
open('test.html','w').write(s)
s=open('test.html').read()
s=s.replace("window.__save=()=>save;","window.__save=()=>save;window.__dw=()=>{const t=performance.now();for(let k=0;k<20;k++)drawWorld();return(performance.now()-t)/20;};",1)
open('test.html','w').write(s)
s=open('test.html').read()
if 'function drawItemBox(' in s:
    s=s.replace("window.__save=()=>save;","window.__save=()=>save;window.__pb=()=>{const o={};const T=(k,f)=>{const t=performance.now();let n=0;for(let r=0;r<30;r++)n=f();o[k]=+((performance.now()-t)/30).toFixed(2)+'ms/'+n;};"
      "T('boxes',()=>{let n=0;for(const b of boxes){const p=proj(b.x,b.y,0);if(p&&p.z<ZFAR){drawItemBox(b,p);n++;}}return n;});"
      "T('ramps',()=>{let n=0;for(const rp of RAMPS){const c=proj(rp.x,rp.y,0);if(c&&c.z<ZFAR){drawRamp(rp,c);n++;}}return n;});"
      "T('sheaves',()=>{let n=0;for(const b of BASKETS){const p=proj(b.x,b.y,0);if(p&&p.z<ZFAR){drawSheaf(p.x,p.gy,p.s,b.i);n++;}}return n;});return o;};",1)
open('test.html','w').write(s)
s=open('test.html').read()
# put the racers at a track index (the player first, the rest spread behind and beside it), keep their progress true
s=s.replace("window.__save=()=>save;","window.__save=()=>save;window.__tp=(i,all,spd)=>{const L=all?racers:[player];L.forEach((r,k)=>{const j=((r.isPlayer?i:i+[3,-2,5,1,-4,7,2,-1][k%8])%N+N)%N;let d=j-r.idx;if(d>N/2)d-=N;if(d<-N/2)d+=N;r.prog+=d;r.idx=j;"
  "const o=r.isPlayer?0:[-.5,.45,-.15,.6,-.6,.2,.35,-.3][k%8]*WD[j];r.x=PX[j]+NX[j]*o;r.y=PY[j]+NY[j]*o;r.a=r.md=TA[j];r.off=o;r.spd=spd||r.spd;});};window.__rain=v=>{weather.on=!!v;weather.k=v?1:0;weather.next=1e9;};",1)
open('test.html','w').write(s)
s=open('test.html').read()
s=s.replace("window.__save=()=>save;","window.__save=()=>save;window.__spots=()=>({box:cpIdx(MAP.boxes[0]),ramp:RAMPS[0].i,bale:BASKETS[0].i,mud:STATIC_MUD[0].i});",1)
open('test.html','w').write(s)
s=open('test.html').read()
# one racer right behind the player, between it and the camera (k=0 the player)
s=s.replace("window.__save=()=>save;","window.__save=()=>save;window.__behind=(back,o)=>{const r=racers.find(q=>!q.isPlayer),j=((player.idx-back)%N+N)%N;let d=j-r.idx;if(d>N/2)d-=N;if(d<-N/2)d+=N;r.prog+=d;r.idx=j;const off=(o||0)*WD[j];r.x=PX[j]+NX[j]*off;r.y=PY[j]+NY[j]*off;r.a=r.md=TA[j];r.off=off;r.spd=player.spd;return r.ch.id;};",1)
open('test.html','w').write(s)
s=open('test.html').read()
s=s.replace("window.__save=()=>save;","window.__save=()=>save;window.__ev=c=>eval(c);",1)
open('test.html','w').write(s)
s=open('test.html').read()
# frozen race for effect stills: window.__frz=dt advances only the clock (and particles with __fstep), the camera
# sits behind the player; window.__place(k,ahead,off) puts racer k (0 = player) on the track relative to the player
s=s.replace("const t0=performance.now();\n  if(state==='menu'||paused)","const t0=performance.now();\n  if(window.__frz&&player){clock+=window.__frz;cam.th=player.a;cam.x=player.x-Math.cos(cam.th)*CDIST;cam.y=player.y-Math.sin(cam.th)*CDIST;render();return;}\n  if(state==='menu'||paused)",1)
s=s.replace("window.__save=()=>save;","window.__save=()=>save;window.__place=(k,i,ah,o,h)=>{const r=k===0?player:racers.filter(q=>!q.isPlayer)[k-1];const j=((i+ah)%N+N)%N;r.idx=j;r.x=PX[j]+NX[j]*o;r.y=PY[j]+NY[j]*o;r.a=r.md=TA[j];r.off=o;r.spd=0;r.z=h||0;r.hopT=0;r.fallT=0;r.spinT=0;r.shieldT=0;r.kickT=0;r.boostT=0;r.mudT=0;r.drift=0;};"
  "window.__fstep=(n,dt)=>{for(let k=0;k<n;k++){fxStep(dt);for(const q of parts){q.x+=q.vx*dt;q.y+=q.vy*dt;q.vx*=.95;q.vy*=.95;q.h=Math.max(0,q.h+q.vh*dt);q.vh-=(q.feather?60:160)*dt;q.life-=dt;if(q.rot!==undefined)q.rot+=dt*4;}parts=parts.filter(q=>q.life>0);for(const g of rings)g.t+=dt;rings=rings.filter(g=>g.t<.6);for(const b of bolts)b.life-=dt;bolts=bolts.filter(b=>b.life>0);clock+=dt;}};",1)
assert "window.__frz&&player" in s and "window.__place=" in s
open('test.html','w').write(s)
