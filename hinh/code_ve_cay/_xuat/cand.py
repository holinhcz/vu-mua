# render candidate frames at 9 px for kits whose live k2 sheet was made elsewhere (chuoi, dua), match each k2 frame
import sys,os,json,numpy as np
from PIL import Image
S='/tmp/claude-0/-home-user/cfdbc2a3-5703-56ed-a42c-fec6fd071eac/scratchpad/';R='/mnt/project-files/nong-trai-chung/'
kit=sys.argv[1]; sys.path.insert(0,S+'r9/'+kit); sys.path.insert(0,S+'r9/chuoi'); os.chdir(S+'r9/'+kit)
out=S+'o9/k2_'+kit+'/'; os.makedirs(out,exist_ok=True)
def crop(im):
    a=np.array(im)[:,:,3];ys,xs=np.where(a>0)
    return max(0,xs.min()-2),max(0,ys.min()-2),min(im.width,xs.max()+3),min(im.height,ys.max()+3)
if kit=='chuoi':
    import build as M
    C=[('ft%d_%d'%(s,r),('ft',s,r)) for s in range(8) for r in (0,1)]+[('b%d_%s'%(s,r),('banana',s,r)) for s in range(6) for r in (None,0,1)]+[('w%d'%s,('wild',s,None)) for s in range(4)]
    def rend(p,night): s,bb=M.render(p[0],p[1],night,p[2]); return M.to_image(s),bb
else:
    import importlib; M=importlib.import_module(kit)
    C=[];seen=set()
    for s_ in range(4):
        for i,f in enumerate(M.FRAMES):
            g=dict(f); g['seed']=s_; key=json.dumps(g,sort_keys=True,default=str)
            if key in seen: continue
            seen.add(key); C.append(('s%d_f%d'%(s_,i),g))
        if kit=='dua':
            g=dict(M.FRAMES[0]); g['seed']=s_; g['nuts']=0; C.append(('s%d_n0'%s_,g))
    def rend(p,night): s,bb=M.render(p,night); return M.to_image(s),bb
T=json.load(open(S+'T5.json'))['k2_'+kit][0][1]
sh=Image.open(R+'img/k2_%s.webp'%kit).convert('RGBA')
def sig(im): return np.asarray(im.convert('RGBA').resize((48,48),Image.BILINEAR)).astype(float)/255
day={}
for nm,p in C:
    im,bb=rend(p,False);x0,y0,x1,y1=crop(im);day[nm]=(im.crop((x0,y0,x1,y1)),bb[0]+x0/9,bb[1]+y0/9,p)
res={}
for k,v in T.items():
    if k[0]!='d': continue
    t=sh.crop((v[0],v[1],v[0]+v[2],v[1]+v[3]));s=sig(t)
    sc=sorted((((sig(c[0])-s)**2).mean()+0.002*abs(c[0].width/9-v[6]),nm) for nm,c in day.items())
    res[k]=sc[0][1];print(k,sc[:3],flush=True)
fr={}
for k,nm in res.items():
    im,ox,oy,p=day[nm]; fr[k]=(im,ox,oy)
    imn,bb=rend(p,True);x0,y0,x1,y1=crop(imn);fr['n'+k[1:]]=(imn.crop((x0,y0,x1,y1)),bb[0]+x0/9,bb[1]+y0/9)
A={}
for k,(im,ox,oy) in fr.items():
    im.save(out+k+'.png');A[k]=[0,0,im.width,im.height,round(ox,2),round(oy,2),round(im.width/9,2),round(im.height/9,2)]
json.dump({'map':res,'atlas':A},open(out+'cand.json','w'))
