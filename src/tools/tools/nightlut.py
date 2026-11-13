import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
D=[];N=[]
for k in range(4):
    d=np.asarray(Image.open(f'gd_{k}.png').convert('RGB')).astype(float)
    n=np.asarray(Image.open(f'gn_{k}.png').convert('RGB')).astype(float)
    m=np.ones(d.shape[:2],bool)
    m[:70,:]=0; m[:,1120:]=0; m[620:,:]=0; m[:,:20]=0; m[200:500,430:770]=0; m[320:375,0:300]=0
    D.append(d[m]);N.append(n[m])
D=np.concatenate(D);N=np.concatenate(N)
M=np.load('M.npy')
def mat(x): return np.c_[x/255,np.ones(len(x))]@M*255
R=N-mat(D)
B=32
q=np.clip((D/255*(B-1)).round().astype(int),0,B-1)
S=np.zeros((B,B,B,3)); C=np.zeros((B,B,B))
np.add.at(C,(q[:,0],q[:,1],q[:,2]),1)
for c in range(3): np.add.at(S[...,c],(q[:,0],q[:,1],q[:,2]),R[:,c])
sg=1.2
Cs=gaussian_filter(C,sg); Ss=np.stack([gaussian_filter(S[...,c],sg) for c in range(3)],-1)
w=Cs/(Cs+3.0)   # few samples -> fall back to the matrix
res=Ss/np.maximum(Cs,1e-9)[...,None]*w[...,None]
# 17^3 grid
G=17; g=np.linspace(0,255,G)
gr,gg,gb=np.meshgrid(g,g,g,indexing='ij'); P=np.stack([gr,gg,gb],-1).reshape(-1,3)
qi=np.clip((P/255*(B-1)).round().astype(int),0,B-1)
out=mat(P)+res[qi[:,0],qi[:,1],qi[:,2]]
out=np.clip(out,0,255).reshape(G,G,G,3)
# evaluate with trilinear
def apply(x):
    f=x/255*(G-1); i=np.clip(np.floor(f).astype(int),0,G-2); t=f-i
    o=0
    for dr in (0,1):
        for dg in (0,1):
            for db in (0,1):
                wt=(t[:,0] if dr else 1-t[:,0])*(t[:,1] if dg else 1-t[:,1])*(t[:,2] if db else 1-t[:,2])
                o=o+out[i[:,0]+dr,i[:,1]+dg,i[:,2]+db]*wt[:,None]
    return o
e=np.abs(apply(D)-N); print('lut err mean',e.mean(0),'median',np.median(e,0))
# texture: width G*G, height G : x = b*G + r? use x = r + b*G, y = g
img=np.zeros((G,G*G,3),np.uint8)
for b in range(G):
    img[:,b*G:(b+1)*G,:]=out[:,:,b,:].transpose(1,0,2).round().astype(np.uint8)  # [g][r]
Image.fromarray(img).save('night_lut.png')
# preview: apply to day images
for k in range(4):
    d=np.asarray(Image.open(f'gd_{k}.png').convert('RGB')).astype(float)
    o=apply(d.reshape(-1,3)).reshape(d.shape)
    Image.fromarray(np.clip(o,0,255).astype(np.uint8)).save(f'lutd_{k}.png')
