import math,random
from PIL import Image,ImageDraw,ImageFilter
K=4; W,H=128*K*2,104*K*2   # vẽ to x8 rồi thu
im=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(im)
cx,cy=W/2,H*0.56
def blob(rx,ry,seed,n=90,amp=0.07):
    random.seed(seed); ph=[random.random()*6.28 for _ in range(3)]
    pts=[]
    for i in range(n):
        a=i/n*2*math.pi
        r=1+amp*(math.sin(3*a+ph[0])+0.6*math.sin(5*a+ph[1])+0.4*math.sin(7*a+ph[2]))
        pts.append((cx+math.cos(a)*rx*r, cy+math.sin(a)*ry*r))
    return pts
# bóng đổ dưới
sh=Image.new('RGBA',(W,H),(0,0,0,0)); ImageDraw.Draw(sh).polygon(blob(W*0.46,H*0.34,1,amp=0.04),fill=(40,60,20,90))
sh=sh.filter(ImageFilter.GaussianBlur(W*0.02)); im.alpha_composite(sh,(0,int(H*0.03)))
# cỏ
d.polygon(blob(W*0.45,H*0.33,2,amp=0.05),fill=(118,178,72,255))
d.polygon(blob(W*0.43,H*0.31,3,amp=0.05),fill=(140,196,86,255))
# bờ đất
d.polygon(blob(W*0.36,H*0.25,4),fill=(150,112,70,255))
d.polygon(blob(W*0.34,H*0.235,5),fill=(118,86,52,255))
# nước: dốc màu từ mép sáng vô giữa đậm
for i in range(40):
    t=i/39
    c=tuple(int(a+(b-a)*t) for a,b in zip((96,170,170),(42,108,118)))
    d.polygon(blob(W*0.32*(1-0.55*t),H*0.215*(1-0.55*t),6,amp=0.07*(1-t)),fill=c+(255,))
# vệt trời phản chiếu + gợn
hl=Image.new('RGBA',(W,H),(0,0,0,0)); hd=ImageDraw.Draw(hl)
hd.ellipse((cx-W*0.2,cy-H*0.15,cx+W*0.02,cy-H*0.08),fill=(200,235,230,90))
for (x,y,r) in [(0.1,0.04,0.07),(-0.12,0.08,0.05)]:
    X,Y=cx+W*x,cy+H*y
    for k in (1,1.6):
        hd.ellipse((X-W*r*k,Y-H*r*0.45*k,X+W*r*k,Y+H*r*0.45*k),outline=(225,245,240,120),width=int(W*0.006))
hl=hl.filter(ImageFilter.GaussianBlur(W*0.004)); im.alpha_composite(hl)
d=ImageDraw.Draw(im)
# lá súng
for (x,y,r,a0) in [(-0.17,0.06,0.06,20),(-0.09,0.12,0.045,200),(0.16,-0.02,0.05,120)]:
    X,Y=cx+W*x,cy+H*y
    bb=(X-W*r,Y-H*r*0.55,X+W*r,Y+H*r*0.55)
    d.pieslice(bb,a0+25,a0+360,fill=(66,140,60,255))
    d.pieslice((bb[0]+W*0.006,bb[1]+H*0.004,bb[2]-W*0.006,bb[3]-H*0.006),a0+25,a0+360,fill=(92,170,74,255))
# hoa súng nhỏ
X,Y=cx-W*0.165,cy+H*0.045
for i in range(8):
    a=i/8*2*math.pi
    d.ellipse((X+math.cos(a)*W*0.018-W*0.012,Y+math.sin(a)*H*0.012-H*0.016-H*0.02,X+math.cos(a)*W*0.018+W*0.012,Y+math.sin(a)*H*0.012+H*0.004-H*0.02),fill=(236,150,190,255))
d.ellipse((X-W*0.01,Y-H*0.03,X+W*0.01,Y-H*0.012),fill=(250,214,90,255))
# lau sậy mép sau
random.seed(9)
for i in range(14):
    x=cx+W*(0.06+0.2*i/13); y=cy-H*0.19+H*0.06*(i/13)
    h=H*(0.16+0.1*random.random()); lean=W*(random.random()-0.3)*0.04
    d.line((x,y,x+lean,y-h),fill=(84,130,52,255),width=int(W*0.007))
    if i%3==0: d.ellipse((x+lean-W*0.008,y-h-H*0.04,x+lean+W*0.008,y-h+H*0.01),fill=(140,98,58,255))
im=im.resize((256,208),Image.LANCZOS)
im.save(__import__('sys').argv[1],quality=92,method=6)
