import json,sys,numpy as np
from PIL import Image
R='/mnt/project-files/nong-trai-chung/'
def frames(sheet,tab):
    sh=Image.open(sheet).convert('RGBA');return {k:(sh.crop((v[0],v[1],v[0]+v[2],v[1]+v[3])),v) for k,v in tab.items()}
def sig(im): return np.asarray(im.resize((48,48),Image.BILINEAR)).astype(float)/255
def match(k2name,sheet9,tab9):
    T=json.load(open('T5.json'))[k2name][0][1]
    A=frames(R+'img/%s.webp'%k2name,T); B=frames(sheet9,json.load(open(tab9)))
    res={}
    for k,(im,v) in A.items():
        s=sig(im);best=None
        for kb,(ib,vb) in B.items():
            if kb[0]!=k[0]: continue
            e=((sig(ib)-s)**2).mean()+ 0.01*abs(vb[6]-v[6])
            if best is None or e<best[0]: best=(e,kb,vb)
        res[k]=best[1];print(k,'->',best[1],round(best[0],4),'gw',v[6],best[2][6],'ox',v[4],best[2][4])
    return res
if __name__=='__main__':
    r=match(sys.argv[1],sys.argv[2],sys.argv[3]);json.dump(r,open(sys.argv[4],'w'))
