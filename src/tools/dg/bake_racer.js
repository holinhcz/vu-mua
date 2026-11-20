// bakes every racer's frames from the web game's own drawing code: 17 views (0 = from behind .. 16 = from the front),
// 8 run frames + 1 standing frame, cropped, with the feet anchor. node bake_racer.js [ids]
const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:400,height:400}});
p.on('pageerror',e=>console.log('ERR',e.message));
await p.goto('file://'+__dirname+'/test.html');await p.waitForFunction(()=>window.__T&&window.__T().map,null,{timeout:120000});
await p.waitForTimeout(1500);
const ids=process.argv[2]?process.argv[2].split(','):await p.evaluate(()=>window.__bird().CHARS.map(c=>c.id));
const S=9.6, PX=4.8;
const meta={S,views:17,run:8};
for(const id of ids){
  const r=await p.evaluate(({id,S,PX})=>{const B=window.__bird();const ch=B.CHARS.find(c=>c.id===id)||B.DUCK_NPC;
    const W=1100,H=1100,ax=550,ay=820;const cv=document.createElement('canvas');cv.width=W;cv.height=H;const g=cv.getContext('2d');
    const out=[],seen={};
    const one=(rel,run,P)=>{g.setTransform(1,0,0,1,0,0);g.clearRect(0,0,W,H);g.setTransform(S,0,0,S,ax,ay);B.setClock(0);
      B.drawBirdView(g,ch,rel,run,0,null,.3,PX,P);
      const d=g.getImageData(0,0,W,H).data;let x0=W,y0=H,x1=-1,y1=-1;
      for(let y=0;y<H;y++)for(let x=0;x<W;x++)if(d[(y*W+x)*4+3]>2){if(x<x0)x0=x;if(x>x1)x1=x;if(y<y0)y0=y;if(y>y1)y1=y;}
      if(x1<0)return null;x0=Math.max(0,x0-2);y0=Math.max(0,y0-2);x1=Math.min(W-1,x1+2);y1=Math.min(H-1,y1+2);
      const c2=document.createElement('canvas');c2.width=x1-x0+1;c2.height=y1-y0+1;c2.getContext('2d').drawImage(cv,-x0,-y0);
      const u=c2.toDataURL('image/png');if(seen[u]!==undefined)return seen[u];
      const k=out.length;out.push({u,ox:x0-ax,oy:y0-ay,w:c2.width,h:c2.height});seen[u]=k;return k;};
    const spd=430*(ch.spd||1),v=[];
    for(let k=0;k<17;k++){const rel=k*Math.PI/16,run=[],P={spd,av:0,acc:0,lagX:0,lagY:0,sq:0,ruff:0,boost:false,dizzy:false,mud:false};
      for(let f=0;f<8;f++)run.push(one(rel,f*Math.PI*2/8,P));
      const st=one(rel,0,{spd:0,av:0,acc:0,lagX:0,lagY:0,sq:0,ruff:0,boost:false,dizzy:false,mud:false});
      v.push({run,st});}
    return{v,out:out.map(o=>({...o})),size:ch.size||1};},{id,S,PX});
  fs.mkdirSync('out/racer/'+id,{recursive:true});
  r.out.forEach((o,i)=>fs.writeFileSync(`out/racer/${id}/${i}.png`,Buffer.from(o.u.split(',')[1],'base64')));
  meta[id]={size:r.size,v:r.v,f:r.out.map(o=>[o.ox,o.oy,o.w,o.h])};
  console.log(id,r.out.length,'frames');
}
fs.writeFileSync('out/racer/meta_'+(process.argv[2]||'all').replace(/,/g,'_')+'.json',JSON.stringify(meta));
await b.close();})();
