import json, numpy as np; from PIL import Image
L=json.load(open('layout.json')); Wn=L['mango_wins']
S=2; pts=[]; edge=[]
for i,w in enumerate(Wn):
  im=Image.open('xoai%d.webp'%i); a=np.array(im.split()[-1].resize((im.width*S//9, im.height*S//9)))>40
  ys,xs=np.nonzero(a); P=np.stack([xs/S+w[0], ys/S+w[1]],1); pts.append(P)
  e=(xs<=1)|(ys<=1)|(xs>=a.shape[1]-2)|(ys>=a.shape[0]-2); edge.append(P[e])
P=np.concatenate(pts); E=np.concatenate(edge); c=np.array([40,-150])
import sys
W=float(sys.argv[1]); th=float(sys.argv[2])
best=[]
for deg in range(0,60,5):
  t=np.radians(deg); R=np.array([[np.cos(t),-np.sin(t)],[np.sin(t),np.cos(t)]])
  Q=(P-c)@R.T; QE=(E-c)@R.T; ymax=Q[:,1].max()
  for csc in np.arange(0.6,3.01,0.1):
    sy=th+4-ymax*csc
    Y=Q[:,1]*csc+sy; vis=(Y>0)
    for cx in np.arange(-900,600,15):
      X=Q[:,0]*csc+cx
      v=vis&(X>0)&(X<W)
      if v.sum()<50: continue
      right=X[(Y>0)&(Y<th)].max(); left=X[(Y>0)&(Y<th)].min()
      XE=QE[:,0]*csc+cx; YE=QE[:,1]*csc+sy
      bad=((XE>-2)&(XE<W+2)&(YE>-2)&(YE<th+6)).sum()
      if bad==0 and abs(right-float(sys.argv[3])*W)<20 and left<0:
        cov=v.sum()*csc*csc
        best.append((round(cov),deg,round(csc,2),int(cx),round(sy,1)))
best.sort(reverse=True); print(best[:6])
