// bakes the hats (đồ đội) as overlays on the player's full-size frames: for every racer, view and frame, the bird is
// drawn with and without the hat; the pixels that differ (the hat, where it is not hidden behind the bird) are kept,
// cropped, with their offset from the feet anchor. node bake_hat.js [ids]
const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:400,height:400}});
p.on('pageerror',e=>console.log('ERR',e.message));
await p.goto('file://'+__dirname+'/test.html');await p.waitForFunction(()=>window.__T&&window.__T().map,null,{timeout:120000});
await p.waitForTimeout(1500);
const ids=process.argv[2]?process.argv[2].split(','):await p.evaluate(()=>window.__bird().CHARS.map(c=>c.id));
const HATS=['khan','nonla','kinh','rom','vuong'];
const S=9.6, PX=4.8;
for(const id of ids){
  const r=await p.evaluate(({id,S,PX,HATS})=>{const B=window.__bird();const ch=B.CHARS.find(c=>c.id===id);
    const W=1100,H=1100,ax=550,ay=820;const mk=()=>{const c=document.createElement('canvas');c.width=W;c.height=H;return c;};
    const c0=mk(),c1=mk(),g0=c0.getContext('2d',{willReadFrequently:true}),g1=c1.getContext('2d',{willReadFrequently:true});
    const out=[],seen={};
    const draw=(g,rel,run,P,hat)=>{g.setTransform(1,0,0,1,0,0);g.clearRect(0,0,W,H);g.setTransform(S,0,0,S,ax,ay);B.setClock(0);B.drawBirdView(g,ch,rel,run,0,hat,.3,PX,P);};
    const one=(rel,run,P,hat)=>{draw(g0,rel,run,P,null);draw(g1,rel,run,P,hat);
      const a=g0.getImageData(0,0,W,H),bb=g1.getImageData(0,0,W,H),d0=a.data,d1=bb.data;let x0=W,y0=H,x1=-1,y1=-1;
      for(let i=0;i<d1.length;i+=4){const df=Math.abs(d0[i]-d1[i])+Math.abs(d0[i+1]-d1[i+1])+Math.abs(d0[i+2]-d1[i+2])+Math.abs(d0[i+3]-d1[i+3]);
        if(df>10&&d1[i+3]>0){const q=i/4,x=q%W,y=(q-x)/W;if(x<x0)x0=x;if(x>x1)x1=x;if(y<y0)y0=y;if(y>y1)y1=y;}else d1[i+3]=0;}
      if(x1<0)return -1;x0=Math.max(0,x0-1);y0=Math.max(0,y0-1);x1=Math.min(W-1,x1+1);y1=Math.min(H-1,y1+1);
      g1.setTransform(1,0,0,1,0,0);g1.putImageData(bb,0,0);
      const c2=document.createElement('canvas');c2.width=x1-x0+1;c2.height=y1-y0+1;c2.getContext('2d').drawImage(c1,-x0,-y0);
      const u=c2.toDataURL('image/png');if(seen[u]!==undefined)return seen[u];
      const k=out.length;out.push({u,ox:x0-ax,oy:y0-ay,w:c2.width,h:c2.height});seen[u]=k;return k;};
    const spd=430*(ch.spd||1),res={};
    for(const hat of HATS){const v=[];
      for(let k=0;k<17;k++){const rel=k*Math.PI/16,run=[],P={spd,av:0,acc:0,lagX:0,lagY:0,sq:0,ruff:0,boost:false,dizzy:false,mud:false};
        for(let f=0;f<8;f++)run.push(one(rel,f*Math.PI*2/8,P,hat));
        const st=one(rel,0,{spd:0,av:0,acc:0,lagX:0,lagY:0,sq:0,ruff:0,boost:false,dizzy:false,mud:false},hat);
        v.push({run,st});}
      res[hat]=v;}
    return{v:res,out};},{id,S,PX,HATS});
  fs.mkdirSync('out/hat/'+id,{recursive:true});
  r.out.forEach((o,i)=>fs.writeFileSync(`out/hat/${id}/${i}.png`,Buffer.from(o.u.split(',')[1],'base64')));
  fs.writeFileSync(`out/hat/${id}/meta.json`,JSON.stringify({S,v:r.v,f:r.out.map(o=>[o.ox,o.oy,o.w,o.h])}));
  console.log(id,r.out.length,'hat frames');
}
await b.close();})();
