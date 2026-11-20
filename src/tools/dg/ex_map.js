// exports one map of the web game for the Godot port: track + scenery data (JSON), the ground's two data textures,
// and every sprite the scenery uses, painted by the web game's own code. node ex_map.js nongtrai
const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const id=process.argv[2]||'nongtrai';const b=await chromium.launch();const p=await b.newPage({viewport:{width:412,height:915}});
p.on('pageerror',e=>console.log('ERR',e.message));p.on('console',m=>{if(m.type()==='error')console.log('CON',m.text().slice(0,200));});
await p.addInitScript(()=>{window.requestAnimationFrame=()=>0;});
await p.goto('file://'+__dirname+'/test.html');await p.waitForFunction(()=>window.__T&&window.__T().map,null,{timeout:120000});
await p.evaluate(()=>document.fonts.ready);await p.waitForTimeout(800);
const ev=c=>p.evaluate(c=>{try{return window.__ev(c);}catch(e){return {EXC:e.message+' '+e.stack};}},c);
let r=await ev(`(()=>{selMap='${id}';loadMap('${id}');archTex&&(ARCH_TEX=null);return MAP.id+' '+N+' info '+(INFO?INFO.length:0);})()`);console.log(r);
// ---- data ----
const data=await ev(`(()=>{const A=v=>Array.from(v,x=>+(+x).toFixed(3));
  const prim=o=>{const q={};for(const k in o){const v=o[k];if(typeof v==='number')q[k]=+v.toFixed(4);else if(typeof v==='string'||typeof v==='boolean')q[k]=v;}return q;};
  const di=new Map();decor.forEach((d,i)=>di.set(d,i));const pi=new Map();posts.forEach((q,i)=>pi.set(q,i));
  const M={};for(const k in MAP){const v=MAP[k];if(typeof v!=='function')M[k]=v;}
  const models=[];decor.forEach((d,i)=>{if(!d.m)return;models.push({i,f:d.m.f.map(f=>({w:f.w.map(q=>q.map(x=>+x.toFixed(2))),n:f.n.map(x=>+x.toFixed(4)),col:f.col,under:f.under,two:f.two,
     dec:f.dec.map(dc=>({w:dc.w.map(q=>q.map(x=>+x.toFixed(2))),col:dc.col,txt:dc.txt||null,tc:dc.tc||null}))}))});});
  const dec=decor.map((d,i)=>{const q=prim(d);if(d.ref)q.ref=di.get(d.ref);return q;});
  const boxes=[];for(const k of MAP.boxes){const i=cpIdx(k);for(const o of[-.62,-.2,.2,.62])boxes.push([+(PX[i]+NX[i]*o*WD[i]).toFixed(2),+(PY[i]+NY[i]*o*WD[i]).toFixed(2),i]);}
  return JSON.stringify({map:M,WORLD_W,WORLD_H,TSC,TXW,TXH,SP,LAPS:3,N,TOTAL,RAWN,PX:A(PX),PY:A(PY),NX:A(NX),NY:A(NY),TA:A(TA),WD:A(WD),BR:A(BR),FL:A(FL),FR:A(FR),ZN,
    RAMPS:RAMPS.map(prim),PADS:PADS.map(prim),BASKETS:BASKETS.map(prim),STATIC_MUD:STATIC_MUD.map(prim),DUCK_SPOTS,AIM,boxes,
    posts:posts.map(q=>({x:+q.x.toFixed(2),y:+q.y.toFixed(2),prev:q.prev?pi.get(q.prev):-1,bamboo:q.bamboo,wood:q.wood})),
    tufts:TUFTS.map(prim),decor:dec,models,
    sky:{P:SKYP,M:SKYM[MAP.id]||null,L:skyLayout()},SUN_L,RAMP_L,RAMP_H,OFFROAD,CHARS:CHARS.map(prim),PERS,ITEMS});})()`);
if(data.EXC){console.log(data.EXC);process.exit(1);}
fs.writeFileSync(`out/map/${id}.json`,data);console.log('data',data.length);
// ---- ground textures (raw bytes, PIL writes the PNGs: a canvas would premultiply INFO's alpha and lose its RGB) ----
for(const [nm,expr] of[['mac','new Uint8Array(tex.buffer)'],['inf','INFO']]){const n=await ev(`(window.__B=${expr}).length`);const ch=1<<22,parts=[];
  for(let o=0;o<n;o+=ch)parts.push(await ev(`(()=>{const a=window.__B.subarray(${o},${Math.min(n,o+ch)});let s='';for(let i=0;i<a.length;i+=8192)s+=String.fromCharCode.apply(null,a.subarray(i,i+8192));return btoa(s);})()`));
  fs.writeFileSync(`out/map/${id}_${nm}.raw`,Buffer.concat(parts.map(s=>Buffer.from(s,'base64'))));console.log(nm,n);}
// ---- sprites: every canvas in LIFE and PROP, the clouds, the arch banner ----
const spr=await ev(`(()=>{const out={};const walk=(o,path,d)=>{if(!o||d>4)return;if(o instanceof HTMLCanvasElement||o instanceof HTMLImageElement){if(!o.width)return;
     let u;try{const c=document.createElement('canvas');c.width=o.width;c.height=o.height;c.getContext('2d').drawImage(o,0,0);u=c.toDataURL('image/png');}catch(e){return;}
     out[path]={u,w:o.width,h:o.height,ax:o.ax||0,ay:o.ay||0,su:o.u||0};return;}
   if(Array.isArray(o)){o.forEach((x,i)=>walk(x,path+'.'+i,d+1));return;}if(typeof o==='object')for(const k in o)walk(o[k],path+'.'+k,d+1);};
  walk(LIFE,'LIFE',0);walk(PROP,'PROP',0);walk(skyClouds('day'),'CLOUD',0);walk(archTex(),'ARCH',0);return JSON.stringify(out);})()`);
const S=JSON.parse(spr);const meta={};
for(const k in S){const o=S[k];fs.writeFileSync(`out/spr/${k}.png`,Buffer.from(o.u.split(',')[1],'base64'));meta[k]={w:o.w,h:o.h,ax:o.ax,ay:o.ay,u:o.su};}
// ---- the plain decor drawings (drawDecor) and grass tufts, painted at 6 px per world unit, clock 0 ----
const bk=await ev(`(()=>{const out={};const PXU=6;clock=0;
  const one=(name,fn)=>{const W=1600,H=1400,ax=800,ay=1200;cv.width=W;cv.height=H;ctx.setTransform(1,0,0,1,0,0);ctx.clearRect(0,0,W,H);ctx.globalAlpha=1;fn(ax,ay);ctx.setTransform(1,0,0,1,0,0);
    const d=ctx.getImageData(0,0,W,H).data;let x0=W,y0=H,x1=-1,y1=-1;for(let y=0;y<H;y++)for(let x=0;x<W;x++)if(d[(y*W+x)*4+3]>1){if(x<x0)x0=x;if(x>x1)x1=x;if(y<y0)y0=y;if(y>y1)y1=y;}
    if(x1<0)return;x0=Math.max(0,x0-2);y0=Math.max(0,y0-2);x1=Math.min(W-1,x1+2);y1=Math.min(H-1,y1+2);const c=document.createElement('canvas');c.width=x1-x0+1;c.height=y1-y0+1;c.getContext('2d').drawImage(cv,-x0,-y0);
    out[name]={u:c.toDataURL('image/png'),w:c.width,h:c.height,ax:ax-x0,ay:ay-y0,u2:PXU};};
  const V={tree:[.25,.6,.85],palm:[0,.125,.25,.375,.5,.625,.75,.875,1],bamboo:[0,.1,.2,.3,.4,.5,.6,.7,.8,.9],hay:[.5],rock:[.5],scare:[.5],flower:[.5],pine:[.25,.75],picker:[.25,.75],stilt:[.25,.75],banyan:[.5],gate:[.5],house:[.25,.75],stall:[0,.3,.55,.8],boat:[.3,.8]};
  for(const t in V)V[t].forEach((v,j)=>one('D.'+t+'.'+j,(ax,ay)=>drawDecor({t,x:0,y:0,k:1,v},ax,ay,PXU)));
  const TC=['#ffcc1f','#ff6f91','#ffffff','#b388ff'];
  for(const [n,t,c] of[['T.0.0',0,.2],['T.0.1',0,.7],['T.1.0',1,.1],['T.1.1',1,.35],['T.1.2',1,.6],['T.1.3',1,.85],['T.2.0',2,.5]])one(n,(ax,ay)=>drawTuft({t,c,s:1,ph:-Math.PI/2*0,x:0,y:0},{x:ax,gy:ay,s:PXU}));
  return JSON.stringify(out);})()`);
if(bk.EXC){console.log(bk.EXC);process.exit(1);}
const B=JSON.parse(bk);for(const k in B){const o=B[k];fs.writeFileSync(`out/spr/${k}.png`,Buffer.from(o.u.split(',')[1],'base64'));meta[k]={w:o.w,h:o.h,ax:o.ax,ay:o.ay,u:o.u2};}
fs.writeFileSync('out/spr/meta.json',JSON.stringify(meta));console.log('sprites',Object.keys(meta).length);
await b.close();})();
