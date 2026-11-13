# the tiling wave height map of the river page (same random waves), as a PNG: R,G slope, B height
import sys, math
import numpy as np
from PIL import Image
S=256;r=1
def rnd():
    global r
    r=(r*16807)%2147483647;return r/2147483647
W=[]
for k in range(34):
    a=rnd()*6.283;f=2+math.floor(math.pow(rnd(),1.6)*22);kx=round(math.cos(a)*f);ky=round(math.sin(a)*f)
    if not kx and not ky: kx=1
    W.append((kx,ky,rnd()*6.283,1/math.pow(math.hypot(kx,ky),1.15)))
y,x=np.mgrid[0:S,0:S].astype(np.float64)
h=np.zeros((S,S))
for kx,ky,ph,am in W: h+=am*np.sin(6.2832*(kx*x+ky*y)/S+ph)
mn,mx=h.min(),h.max()
dx=np.roll(h,-1,1)-np.roll(h,1,1);dy=np.roll(h,-1,0)-np.roll(h,1,0);s=2.4/(mx-mn)
o=np.zeros((S,S,4),np.uint8)
# JS Math.round-free: Uint8Array assignment truncates toward zero
o[...,0]=np.trunc(np.clip(128-dx*s*60,0,255));o[...,1]=np.trunc(np.clip(128-dy*s*60,0,255));o[...,2]=np.trunc((h-mn)/(mx-mn)*255);o[...,3]=255
Image.fromarray(o,'RGBA').save(sys.argv[1])
