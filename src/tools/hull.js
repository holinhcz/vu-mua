// thân ghe (thay __SV.hull bản web: ảnh img/songvat.webp không có): vẽ theo đúng phép chiếu x(u, v, z) của yg
window.__SV=window.__SV||{};
window.__SV.hull=function(cx,s,x,n){
  var c=1.3,N=28;
  function col(d,nn){return n?nn:d}
  function zr(u){var L=Math.abs(u)/c;return 6+(u>0?9:6)*L*L*L}
  function wr(u){var L=Math.min(1,Math.abs(u)/c);return .34*Math.pow(Math.max(0,1-Math.pow(L,2.4)),.5)}
  function wb(u){var L=Math.min(1,Math.abs(u)/(c*.94));return .22*Math.pow(Math.max(0,1-Math.pow(L,1.8)),.6)}
  function U(i){return -c+2*c*i/N}
  function P(pts){cx.beginPath();pts.forEach(function(p,i){i?cx.lineTo(p[0],p[1]):cx.moveTo(p[0],p[1])});cx.closePath()}
  var rimN=[],rimF=[],watN=[],watF=[],i,u;
  for(i=0;i<=N;i++){u=U(i);rimN.push(x(u,wr(u),zr(u)));rimF.push(x(u,-wr(u),zr(u)));watN.push(x(u,wb(u),0));watF.push(x(u,-wb(u),0))}
  // mạn xa
  P(rimF.concat(watF.slice().reverse()));cx.fillStyle=col("#3b2312","#1e120a");cx.fill();
  // lòng ghe
  P(rimN.concat(rimF.slice().reverse()));cx.fillStyle=col("#2e1c10","#160c06");cx.fill();
  cx.save();P(rimN.concat(rimF.slice().reverse()));cx.clip();
  cx.strokeStyle=col("rgba(150,100,55,.55)","rgba(80,55,30,.55)");cx.lineWidth=.9;
  for(var k=-2;k<=2;k++){cx.beginPath();for(i=2;i<=N-2;i++){u=U(i);var q=x(u,k*.06,Math.min(zr(u),6)-3.2);i>2?cx.lineTo(q[0],q[1]):cx.moveTo(q[0],q[1])}cx.stroke()}
  cx.strokeStyle=col("rgba(110,70,35,.8)","rgba(60,40,20,.8)");cx.lineWidth=1.1;
  [-.75,-.35,.1,.5,.85].forEach(function(t){var a=x(t,-wr(t)*.95,zr(t)-1),b=x(t,wr(t)*.95,zr(t)-1);cx.beginPath();cx.moveTo(a[0],a[1]);cx.lineTo(b[0],b[1]);cx.stroke()});
  cx.restore();
  // mạn gần
  P(rimN.concat(watN.slice().reverse()));
  var g=cx.createLinearGradient(0,-14,0,4);g.addColorStop(0,col("#7a4a24","#3e2612"));g.addColorStop(1,col("#4a2a14","#24140a"));cx.fillStyle=g;cx.fill();
  cx.save();P(rimN.concat(watN.slice().reverse()));cx.clip();
  cx.strokeStyle=col("rgba(40,22,10,.55)","rgba(20,10,5,.55)");cx.lineWidth=.8;
  [.33,.62].forEach(function(f){cx.beginPath();for(i=0;i<=N;i++){u=U(i);var w=wb(u)+(wr(u)-wb(u))*f,q=x(u,w,zr(u)*f);i?cx.lineTo(q[0],q[1]):cx.moveTo(q[0],q[1])}cx.stroke()});
  // vệt nước ướt sát mặt nước
  cx.strokeStyle=col("rgba(20,40,40,.45)","rgba(10,20,20,.45)");cx.lineWidth=2.2;cx.beginPath();watN.forEach(function(q,i){i?cx.lineTo(q[0],q[1]-1):cx.moveTo(q[0],q[1]-1)});cx.stroke();
  cx.restore();
  // mắt ghe ở mũi
  var e=x(c*.78,wr(c*.78)*.55+wb(c*.78)*.45,zr(c*.78)*.55);
  cx.fillStyle=col("#c8322a","#6a1a16");cx.beginPath();cx.ellipse(e[0],e[1],2.9,1.9,-.35*s,0,6.3);cx.fill();
  cx.fillStyle=col("#f4ead4","#8a8478");cx.beginPath();cx.ellipse(e[0],e[1],2.1,1.3,-.35*s,0,6.3);cx.fill();
  cx.fillStyle="#140a04";cx.beginPath();cx.arc(e[0]+.3*s,e[1],.75,0,6.3);cx.fill();
  // be mạn (gỗ sáng)
  cx.lineJoin="round";cx.lineCap="round";
  cx.strokeStyle=col("#a8743c","#5a3e20");cx.lineWidth=1.7;
  cx.beginPath();rimF.forEach(function(q,i){i?cx.lineTo(q[0],q[1]):cx.moveTo(q[0],q[1])});cx.stroke();
  cx.strokeStyle=col("#c8904e","#6a4a28");cx.lineWidth=1.9;
  cx.beginPath();rimN.forEach(function(q,i){i?cx.lineTo(q[0],q[1]):cx.moveTo(q[0],q[1])});cx.stroke();
  cx.strokeStyle=col("rgba(255,230,180,.35)","rgba(150,120,90,.3)");cx.lineWidth=.6;
  cx.beginPath();rimN.forEach(function(q,i){i?cx.lineTo(q[0],q[1]-.6):cx.moveTo(q[0],q[1]-.6)});cx.stroke();
};
