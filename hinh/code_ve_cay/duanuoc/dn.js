// dừa nước clumps (img/duanuoc.webp, drawn by duanuoc.py): the plant the river's banks are lined with. Defined before
// the decor is laid out; draws nothing until the sheet has loaded, then the cached sprites are dropped
(function(){var IM=new Image(),ok=0,G={{TABLE}},RE=/pduanuoc\d/;
function inv(){var re=RE,k;for(k in {{FU}})re.test(k)&&delete {{FU}}[k];for(k in {{SU}})re.test(k)&&delete {{SU}}[k];try{if({{H0}}&&{{H0}}.SIL)for(k in {{H0}}.SIL)re.test(k)&&delete {{H0}}.SIL[k]}catch(e){}try{{{WF}}=1}catch(e){}}
IM.onload=function(){ok=1;inv()};IM.src="img/duanuoc.webp";
{{AT}}.plants.duanuoc={fw:1,fd:1,bb:{{BB}},sway:1,draw:function(t){t=t|0;var f=ok&&G[({{XN}}?"n":"d")+(t&3)];if(!f)return;var c={{CX}},q=c.imageSmoothingQuality,e=c.imageSmoothingEnabled;
c.imageSmoothingEnabled=!0;c.imageSmoothingQuality="high";c.drawImage(IM,f[0],f[1],f[2],f[3],f[4],f[5],f[6],f[7]);c.imageSmoothingQuality=q;c.imageSmoothingEnabled=e}}})();
