# hill picture (sc/16): erase the baked cartoon rings / waterline / stepped shadow in the plunge pool, and cut the
# pool rocks out into n/fallrock.webp, drawn over the fall's foam (main._build_fall). Source: bak_n9/sc16_orig.webp
import sys
from PIL import Image; import numpy as np
from scipy import ndimage
S=sys.argv[1]
im=np.array(Image.open(S+'/godot/bak_n9/sc16_orig.webp').convert('RGBA')).astype(int)
H,W=im.shape[:2];A=im[...,3];rgb=im[...,:3];mn=rgb.min(-1);mx=rgb.max(-1)
X0,Y0=450,1550
yy,xx=np.mgrid[0:H,0:W]
zone=(yy>Y0)&(xx>X0)&(xx<X0+1000)
op=A>235
lab,n=ndimage.label(op)
main=lab==lab[1000,1000]
white=ndimage.binary_dilation((mn>165)&(mx-mn<60)&(A>60),iterations=1)
sep=op&zone&~main
sz=ndimage.sum(np.ones_like(A),lab,index=np.arange(n+1))
sep&=sz[lab]>200
# the big rock leaning on the cliff right of the foot: its outline by hand (crop coords), bottom along the old ring
from PIL import ImageDraw
PL=[(670,396),(680,378),(700,374),(718,370),(722,354),(740,340),(752,322),(758,318),(768,320),(800,330),(812,352),(818,366),
 (820,378),(822,392),(820,404),(832,404),(842,408),(846,430),(840,442),(832,430),(826,418),(815,426),(790,434),(760,437),
 (730,435),(700,428),(680,414),(668,412)]
mk=Image.new('L',(W,H),0);ImageDraw.Draw(mk).polygon([(X0+x,Y0+y) for x,y in PL],fill=255)
att=op&(np.array(mk)>0)
ra=ndimage.binary_opening(att&~white,iterations=1)
rs=ndimage.binary_opening(sep&~white,iterations=2)
rock=ra|rs
# the cartoon waterline dashes: light grey pixels in a band along the cliff's lower edge
edge=main&~ndimage.binary_erosion(main,iterations=10)&(yy>Y0+200)&zone&(mn>145)&(mx-mn<45)
erase=zone&(((~op)&(yy>Y0+200)&~main)|(white&(yy>Y0+330)&~main))
near=ndimage.binary_dilation(main&~att,iterations=3)&~att
erase&=~(near&~white)
erase|=(att&~ra)|edge|(sep&~rs)
band=ndimage.binary_dilation(main,iterations=4)&~ndimage.binary_erosion(main,iterations=12)
erase|=band&zone&(yy>Y0+200)&(xx>X0+300)&(mn>118)&(mx-mn<25)&(A>0)
out=im.copy();out[erase,3]=0
# leftover crumbs in the pool
lv=(out[...,3]>0)&zone&(yy>Y0+330)
l2,n2=ndimage.label(lv);s2=ndimage.sum(np.ones_like(A),l2,index=np.arange(n2+1))
crumbs=lv&(s2[l2]<400)
out[crumbs,3]=0;rock&=~crumbs
Image.fromarray(out.astype(np.uint8)).save(S+'/gn/n/sc/16.webp','WEBP',lossless=True,quality=100,method=6,exact=False)
rk=np.zeros_like(im);rk[rock]=im[rock]
# soft 1px edge
ys,xs=np.nonzero(rock);x0,x1,y0,y1=xs.min(),xs.max()+1,ys.min(),ys.max()+1
Image.fromarray(rk[y0:y1,x0:x1].astype(np.uint8)).save(S+'/gn/n/fallrock.webp','WEBP',lossless=True,quality=100,method=6)
print('rock box',x0,y0,x1,y1)
v=np.zeros((H-Y0,1000,3),np.uint8);r=out[Y0:,X0:X0+1000];v[...,0]=r[...,3];v[...,1]=np.where(rock[Y0:,X0:X0+1000],255,0);v[...,2]=np.where(erase[Y0:,X0:X0+1000],255,0)
Image.fromarray(v).save(S+'/ao/hillB.png')
bg=Image.new('RGBA',(1000,H-Y0),(40,120,130,255));bg.alpha_composite(Image.fromarray(out[Y0:,X0:X0+1000].astype(np.uint8)));bg.convert('RGB').save(S+'/ao/hillC.jpg')
# the hill's flat lime top (one flat colour + a darker rim band in the picture) and the two flat grey stones of the
# notch -> mask for hilltop.gdshader (n/hilltop.webp: R top, G rim band, B distance in from the edge (top) or the
# stone's own lightness (notch), A cover)
T=im[0:600,560:1460].astype(float)
def near(c,r=34.0): return np.clip(1.0-np.sqrt(((T[...,:3]-np.array(c))**2).sum(-1))/r,0,1)*(T[...,3]/255.0)
tp=near((145,203,86));rm=near((130,181,77))
cov=np.clip(tp+rm,0,1)
lb,nl=ndimage.label(cov>0.5);big=lb==np.argmax(np.bincount(lb.ravel())[1:])+1
keep=ndimage.binary_dilation(big,iterations=3);tp*=keep;rm*=keep;cov*=keep
# edge pixels half lime, half something else: cover them fully (else a lime hairline shows round the top)
edge=ndimage.binary_dilation(cov>0.12,iterations=1)&keep&~(cov>0.95)
w=np.maximum(tp+rm,1e-3);tpn=tp/w;rmn=rm/w
tpn[edge&(tp+rm<0.02)]=0;rmn[edge&(tp+rm<0.02)]=1
cov[edge]=1.0
# notch stones: flat greys inside the notch box under the top's front edge
nb=np.zeros(cov.shape,bool);nb[380:600,150:580]=True
gs=np.zeros(cov.shape)
for c in [(75,78,75),(179,174,165),(120,116,108)]: gs=np.maximum(gs,near(c,22.0))
ns=(gs>0.5)&nb&(cov<0.5)
ns=ndimage.binary_opening(ns,iterations=1)
lum=(T[...,:3]@np.array([.3,.59,.11]))/255.0
dt=ndimage.distance_transform_edt(cov>0.5)
o2=np.zeros(T.shape,np.uint8)
o2[...,0]=np.where(ns,0,tpn*255).clip(0,255);o2[...,1]=np.where(ns,0,rmn*255).clip(0,255)
o2[...,2]=np.where(ns,lum*255,np.clip(dt/40.0,0,1)*255);o2[...,3]=np.where(ns,255,cov*255)
ys,xs=np.nonzero(o2[...,3]>0);bx0,by0,bx1,by1=xs.min(),ys.min(),xs.max()+1,ys.max()+1
Image.fromarray(o2[by0:by1,bx0:bx1]).save(S+'/gn/n/hilltop.webp',lossless=True)
print('hilltop box',560+bx0,by0,560+bx1,by1, 'notch px',ns.sum())
