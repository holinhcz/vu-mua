// bakes the HUD / effect pictures the race uses beyond the map: item icons, the basket face, the storm cloud, dust puffs
const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:412,height:915}});
p.on('pageerror',e=>console.log('ERR',e.message));
await p.addInitScript(()=>{window.requestAnimationFrame=()=>0;});
await p.goto('file://'+__dirname+'/test.html');await p.waitForFunction(()=>window.__T&&window.__T().map,null,{timeout:120000});
await p.evaluate(()=>document.fonts.ready);await p.waitForTimeout(800);
const r=await p.evaluate(()=>window.__ev(`(()=>{const out={};const cv=(W,H,f)=>{const c=document.createElement('canvas');c.width=W;c.height=H;f(c.getContext('2d'));return c.toDataURL('image/png');};
  for(const k of Object.keys(ITEMS))out['ic_'+k]=cv(160,160,g=>drawItemIcon(g,k,80,80,80));
  out.basket=cv(160,160,g=>g.drawImage(basketFace(160),0,0));
  out.cloud=cv(FX.cloud.width,FX.cloud.height,g=>g.drawImage(FX.cloud,0,0));
  FX.puff.forEach((c,i)=>out['puff'+i]=cv(c.width,c.height,g=>g.drawImage(c,0,0)));
  return JSON.stringify(out);})()`));
const S=JSON.parse(r);fs.mkdirSync('out/fx',{recursive:true});for(const k in S)fs.writeFileSync('out/fx/'+k+'.png',Buffer.from(S[k].split(',')[1],'base64'));
console.log(Object.keys(S));await b.close();})();
