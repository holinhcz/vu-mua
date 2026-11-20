// map cards for the menu (drawMapPreview of the web) + the map list, for the dg_card bundle. node ex_card2.js
const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:412,height:915}});
p.on('pageerror',e=>console.log('ERR',e.message));
await p.addInitScript(()=>{window.requestAnimationFrame=()=>0;});
await p.goto('file://'+__dirname+'/test.html');await p.waitForFunction(()=>window.__T&&window.__T().map,null,{timeout:120000});
await p.waitForTimeout(800);
const r=await p.evaluate(()=>window.__ev(`(()=>{const out={maps:[],img:{}};for(const d of MAPS){const c=document.createElement('canvas');c.width=300;c.height=180;drawMapPreview(c,d);out.img['mp_'+d.id]=c.toDataURL('image/png');
  out.maps.push({id:d.id,name:d.name,sub:d.sub,banner:d.banner,tod:d.tod,music:d.music,unlock:d.unlock||null,fall:d.fall});}
  out.hats=HATS;out.stages=STAGES;out.missions=MISSION_POOL.map(m=>({k:m.k,ns:m.ns,rw:m.rw,t:m.t('{n}')}));return JSON.stringify(out);})()`));
const S=JSON.parse(r);fs.mkdirSync('out/card2',{recursive:true});for(const k in S.img)fs.writeFileSync('out/card2/'+k+'.png',Buffer.from(S.img[k].split(',')[1],'base64'));
delete S.img;fs.writeFileSync('out/card2/meta.json',JSON.stringify(S));console.log(JSON.stringify(S).slice(0,1500));await b.close();})();
