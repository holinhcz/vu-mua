import sys,os,json,numpy as np
from PIL import Image
S='/tmp/claude-0/-home-user/cfdbc2a3-5703-56ed-a42c-fec6fd071eac/scratchpad/';R='/mnt/project-files/nong-trai-chung/'
kit,key=sys.argv[1],sys.argv[2]
sys.path.insert(0,S+'r9/'+kit);sys.path.insert(0,S+'r9/chuoi');os.chdir(S+'r9/'+kit)
import importlib;M=importlib.import_module(kit)
T=json.load(open(S+'T5.json'))['k2_'+kit][0][1];v=T[key]
t=Image.open(R+'img/k2_%s.webp'%kit).convert('RGBA').crop((v[0],v[1],v[0]+v[2],v[1]+v[3]))
sig=lambda im:np.asarray(im.convert('RGBA').resize((48,48),Image.BILINEAR)).astype(float)/255
def crop(im):
    a=np.array(im)[:,:,3];ys,xs=np.where(a>0);return max(0,xs.min()-2),max(0,ys.min()-2),min(im.width,xs.max()+3),min(im.height,ys.max()+3)
if kit=='dudu':
    G,R_,T_=M.G,M.R_,M.T_
    C=[dict(seed=2,fruit=f,flowers=fl) for f in ([R_]*4,[R_,T_,R_,T_],[T_,R_,T_,R_],[R_,R_,T_,G],[T_]*4,[R_,T_,G,G]) for fl in (6,4)]
else:
    C=[dict(seed=3,fruit=n,ripe_mix=m) for n in (6,5) for m in (0.0,0.1,0.2,0.3)]
best=None
for p in C:
    s,bb=M.render(p,False);im=M.to_image(s);x0,y0,x1,y1=crop(im);c=im.crop((x0,y0,x1,y1))
    e=((sig(c)-sig(t))**2).mean();print(p,round(e,5),flush=True)
    if best is None or e<best[0]: best=(e,p,c,bb[0]+x0/9,bb[1]+y0/9)
e,p,c,ox,oy=best;out=S+'o9/k2_'+kit+'/';c.save(out+key+'.png')
s,bb=M.render(p,True);im=M.to_image(s);x0,y0,x1,y1=crop(im);n=im.crop((x0,y0,x1,y1));nk='n'+key[1:];n.save(out+nk+'.png')
J=json.load(open(out+'cand.json'))
J['atlas'][key]=[0,0,c.width,c.height,round(ox,2),round(oy,2),round(c.width/9,2),round(c.height/9,2)]
J['atlas'][nk]=[0,0,n.width,n.height,round(bb[0]+x0/9,2),round(bb[1]+y0/9,2),round(n.width/9,2),round(n.height/9,2)]
J['map'][key]=str(p);json.dump(J,open(out+'cand.json','w'));print('BEST',p,e)
