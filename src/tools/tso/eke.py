import sys, numpy as np
sys.path.insert(0,'/tmp/claude-0/ts')
import art
from art import noise
from PIL import Image, ImageDraw, ImageFont
# thước tam giác (ê ke 45°) nhựa trong ngả xanh lá: lỗ tam giác giữa, vạch cm/mm 2 cạnh góc vuông, mép vát sáng, trầy xước
S=1100; P=24
y,x=np.mgrid[0:S,0:S].astype(np.float32)
def tri(px,py,a,b,c):
    # sdf tam giác (âm bên trong)
    def seg(p,q):
        e=(q[0]-p[0],q[1]-p[1]); w=(px-p[0],py-p[1])
        t=np.clip((w[0]*e[0]+w[1]*e[1])/(e[0]**2+e[1]**2),0,1)
        return np.hypot(w[0]-e[0]*t,w[1]-e[1]*t), e[0]*w[1]-e[1]*w[0]
    d1,s1=seg(a,b); d2,s2=seg(b,c); d3,s3=seg(c,a)
    d=np.minimum(np.minimum(d1,d2),d3)
    inside=(s1>=0)&(s2>=0)&(s3>=0) | (s1<=0)&(s2<=0)&(s3<=0)
    return np.where(inside,-d,d)
A=(P,P); B=(P,S-P); C=(S-P,S-P)   # góc vuông dưới trái
r=10
d=tri(x,y,A,B,C)+r*0     # bo góc nhẹ bằng cách co rồi giãn
d=tri(x,y,(P+r*2.4,P+r*5.8),(P+r*2.4,S-P-r*2.4),(S-P-r*5.8,S-P-r*2.4))-r*2.4
I0=(P+150,P+370); I1=(P+150,S-P-150); I2=(S-P-370,S-P-150)
ri=14
di=tri(x,y,(I0[0]+ri*2.4,I0[1]+ri*5.8),(I0[0]+ri*2.4,I1[1]-ri*2.4),(I2[0]-ri*5.8,I1[1]-ri*2.4))-ri*2.4
body=np.clip(-d,0,1)*np.clip(di,0,1)
dist=np.minimum(-d,di)          # khoảng cách tới mép gần nhất (trong nhựa)
base=np.array([150,214,190],np.float32)
col=np.zeros((S,S,3),np.float32)+base
al=np.full((S,S),0.42,np.float32)
edge=np.clip(1-dist/12,0,1)
col=col*(1-edge[...,None]*0.4)+np.array([255,255,255])*np.clip(1-np.abs(dist-3.5)/2.2,0,1)[...,None]*0.75
al+=edge*0.55
# mép vát trong lỗ: dải sáng phía trên-trái (nắng), tối dưới-phải
bev=np.clip(1-np.abs(di-16)/12,0,1)*np.clip(-d,0,1)
col+=bev[...,None]*40; al+=bev*0.15
n=noise(S,S,2,71,1); n2=noise(S,S,120,72,3)
al+=(n-0.5)*0.05+(n2-0.5)*0.06
rr=np.random.default_rng(73); scr=np.zeros((S,S),np.float32)
for i in range(120):
    x0,y0=rr.random()*S,rr.random()*S; an=rr.normal(0.4,0.5); L=int(rr.random()*110+10)
    xs=(x0+np.cos(an)*np.arange(L)).astype(int); ys=(y0+np.sin(an)*np.arange(L)).astype(int)
    m=(xs>=0)&(xs<S)&(ys>=0)&(ys<S); scr[ys[m],xs[m]]=0.5
al+=scr*0.25; col+=scr[...,None]*70
# vạch: cạnh dưới (B->C) từ góc vuông sang phải, cạnh trái (B->A) từ góc vuông lên trên
CM=76.0
im=Image.new('L',(S,S),0); dr=ImageDraw.Draw(im)
f=ImageFont.truetype("/home/user/vu-mua/src/godot/ui/font/baloo2.ttf",30)
x0=P+48; yb=S-P-8
for i in range(0,121):
    xi=x0+i*CM/10
    if xi>S-P-130: break
    L=46 if i%10==0 else (32 if i%5==0 else 20)
    dr.line([(xi,yb),(xi,yb-L)],fill=255,width=3)
    if i%10==0 and i>0:
        t=str(i//10); tw=dr.textlength(t,font=f); dr.text((xi-tw/2,yb-L-38),t,fill=255,font=f)
xl=P+8; y0=S-P-48
for i in range(0,121):
    yi=y0-i*CM/10
    if yi<P+130: break
    L=46 if i%10==0 else (32 if i%5==0 else 20)
    dr.line([(xl,yi),(xl+L,yi)],fill=255,width=3)
    if i%10==0 and i>0:
        t=str(i//10); dr.text((xl+L+8,yi-22),t,fill=255,font=f)
# chữ in nổi nhỏ giữa
f2=ImageFont.truetype("/home/user/vu-mua/src/godot/ui/font/baloo2.ttf",28)
dr.text((P+70,S-P-120),"45°",fill=150,font=f2)
ink=np.asarray(im,np.float32)/255*(0.85+0.15*n)
col=col*(1-ink[...,None])+np.array([30,58,48])[None,None]*ink[...,None]
al=np.maximum(al,ink*0.95)
al=np.clip(al,0,1)*body
art.save(np.concatenate([col,(al*255)[...,None]],2),"eke")
