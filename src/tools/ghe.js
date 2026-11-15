(function(){
var S=9,W=1600,H=2200,OX=800,OY=1350,out={},meta={};
var oi=i,ohe=he,oXn=Xn;
function draw(key,p,th,s,mui,pole,sc,ax){
  var cv=document.createElement('canvas');cv.width=W;cv.height=H;var cx=cv.getContext('2d');
  i=cx; he=1; Xn=false;
  var e=en(p[0],p[1]),r=nn(p[0],p[1],0);
  cx.setTransform(S,0,0,S,OX-e*S,OY-r*S);
  try{yg({p:p,ax:ax||"u",al:1,offers:[],sc:sc||1,s:s,pole:pole,mui:mui,label:0,th:th});}catch(err){out[key+'_err']=String(err)}
  i=oi;he=ohe;Xn=oXn;
  out[key]=cv.toDataURL('image/png');
}
// chợ nổi: 3 khúc sông x 4 ghe (vị trí YB)
[["song",8],["song_dong",33],["song_tay",-30]].forEach(function(q){
  [[.6,-.95],[2.4,.95],[4.4,-.95],[6.2,.95]].forEach(function(d,k){
    var x=q[1]+d[0],y=SGEO.c(x)+d[1];
    draw('cho_'+q[0]+'_'+k,[x,y],Math.atan(SGEO.sl(x)),k%2?-1:1,s4[k].mui,1,1);
    meta['cho_'+q[0]+'_'+k]={x:x,y:y,th:Math.atan(SGEO.sl(x))};
  });
});
// ghe thương hồ: trục u theo từng góc, trục v
for(var a=-23;a<=13;a++){var th=a*.05;draw('ghe_u_'+a,[10,30],th,1,1,1,1,'u');}
draw('ghe_v',[10,30],0,1,1,1,1,'v');
out.meta=JSON.stringify(meta);
out.chk=JSON.stringify([SGEO.c(8.6),SGEO.c(-29.4),SGEO.top(10),SGEO.top(-30),SGEO.hw(10),SGEO.c2(100)]);
return JSON.stringify(out);
})()
