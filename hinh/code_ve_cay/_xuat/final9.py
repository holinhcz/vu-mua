import json,os,glob,sys,shutil,numpy as np
from PIL import Image
S='/tmp/claude-0/-home-user/cfdbc2a3-5703-56ed-a42c-fec6fd071eac/scratchpad/';R='/mnt/project-files/nong-trai-chung/'
sys.path.insert(0,R+'src/nen');from sau_la import deepen
T5=json.load(open(S+'T5.json'))
KITS={'chuoi':'k2','dua':'k2','dieu':'k2','dudu':'k2','buoi':'k2_buoi','chomchom':'k2_chomchom','mangcut':'k2_mangcut','cam':'k2_cam','man':'k2_man','me':'k2_me','nhan':'k2_nhan','saurieng':'k2_saurieng','mit':'k2_mit','thanhlong':'k2_thanhlong',
 'tre':'tre','cau':'cau','caosu':'caosu_b','dambut':'dambut','duanuoc':'duanuoc','rom':'rom','bonggiay':'bonggiay','mai':'mai','duongxi':'duongxi'}
def dp(im,k):
    a=np.asarray(im).astype(np.float64)/255; a[...,:3]=deepen(a[...,:3],k); return Image.fromarray((a*255+.5).astype(np.uint8),'RGBA')
rep=[]
for kit,src in KITS.items():
    if src=='k2':
        src='k2_'+kit; J=json.load(open(S+'o9/k2_%s/cand.json'%kit))['atlas']
        frames={k:(Image.open(S+'o9/k2_%s/%s.png'%(kit,k)).convert('RGBA'),v) for k,v in J.items()}
    else:
        J=json.load(open(S+'o9/%s/atlas.json'%kit)); sh=Image.open(glob.glob(S+'o9/%s/*.webp'%kit)[0]).convert('RGBA')
        frames={k:(sh.crop((v[0],v[1],v[0]+v[2],v[1]+v[3])),v) for k,v in J.items()}
    T=T5[src][0][1]; live=Image.open(R+'img/%s.webp'%src).convert('RGBA')
    assert sorted(T)==sorted(frames),(kit,sorted(T),sorted(frames))
    # fit the sau_la deepen amount against the live sheet (day frames; night uses .45 of it like sau_la)
    best=None
    for k in (0,.1,.15,.2,.25,.3,.4):
        e=0
        for fk,(im,v) in frames.items():
            if fk[0]!='d': continue
            t=T[fk];a=np.asarray(live.crop((t[0],t[1],t[0]+t[2],t[1]+t[3]))).astype(float)
            b=np.asarray((dp(im,k) if k else im).resize((t[2],t[3]),Image.LANCZOS)).astype(float)
            m=(a[...,3]>200)&(b[...,3]>200); e+=np.abs(a[...,:3]-b[...,:3])[m].mean()
        if best is None or e<best[0]: best=(e,k)
    k=best[1]
    grp='caytrai' if src.startswith('k2_') else 'kieng' if kit in('bonggiay','mai','duongxi') else 'caylang'
    d=R+'godot/%s/%s/'%(grp,kit); shutil.rmtree(d,ignore_errors=True); os.makedirs(d)
    A={}
    for fk,(im,v) in frames.items():
        kk=k*(.45 if fk[0]=='n' else 1); out=dp(im,kk) if kk else im
        out.save(d+fk+'.png',optimize=True)
        A[fk]={'file':fk+'.png','w':im.width,'h':im.height,'ox':v[4],'oy':v[5],'gw':v[6],'gh':v[7]}
    json.dump({'px_per_unit':9,'src_code':'src/%s/'%kit,'replaces':'img/%s.webp (5 px)'%src,'frames':A},open(d+'atlas.json','w'),indent=1)
    open(d+'README.md','w').write(f'# {kit}\nXuất LẠI từ code gốc src/{kit}/ ở 9 px/đơn vị game (bản web img/{src}.webp chỉ 5 px). Cùng mô hình, cùng khung, cùng tên khung với bản game; không vẽ lại.\nMàu: chỉnh "sâu lá" (src/nen/sau_la.py) k={k} cho khớp bản game.\nd = ngày, n = đêm. Cây trái: d<dáng><chín>; chuối dw* = chuối rừng.\natlas.json: ox,oy = góc trên trái so với neo (tâm ô, đơn vị game), gw,gh = cỡ vẽ (đơn vị game). Godot: offset=(ox,oy), scale=1/9.\n')
    rep.append((grp,kit,len(A),k,round(best[0]/max(1,sum(1 for f in frames if f[0]=='d')),1)));print(rep[-1],flush=True)
json.dump(rep,open(S+'o9/final.json','w'))
