# ghép: mỗi hình món của web (bdx, chỉ dùng để dò) -> khung 9px có sẵn trong godot/<nhóm>/<thư mục> giống nhất.
import json,os,glob,re,sys
import numpy as np
from PIL import Image
S='/tmp/claude-0/-home-user/ec30a73d-a632-5817-a52f-4d1a59b285b5/scratchpad'
G='/mnt/project-files/nong-trai-chung/godot/'
FOLD={'hibiscus':'caylang/dambut','duongxi':'kieng/duongxi','hc_bui':'caydai/bui_cay','hc_co':'caydai/bui_co','hc_lau':'caydai/co_lau',
 'banana':'caytrai/chuoi','papaya':'caytrai/dudu','bougainvillea':'kieng/bonggiay','areca':'caylang/cau','bamboo':'caylang/tre',
 'coconut':'caytrai/dua','mango':'caytrai/xoai','caosu':'caylang/caosu','dieu':'caytrai/dieu','mai':'kieng/mai','dao':'kieng/mai','jackfruit':'caytrai/mit',
 'haystack':'caylang/rom','goc_cay':'caydai/goc_cay','nhanh_kho':'caydai/nhanh_kho','sung':'thuysinh/sung','rau_muong':'thuysinh/rau_muong','lotus':'thuysinh/sung',
 'shrine':'congtrinh/shrine','shrine2':'congtrinh/shrine'}
for c in ['cc_bong_trang','cc_lai','cc_huong_duong','cc_luoi_ho','cc_nha_dam','cc_xuong_rong','cc_sa']: FOLD[c]='kieng/'+c
for f in ['dudu','me','nhan','chomchom','thanhlong','dieu','buoi','mangcut','mit','cam','saurieng','chuoi','man','xoai','dua']: FOLD['ft_'+f]='caytrai/'+f
for b in ['hutnho','hut','pavilion','sap','kho','gate','dinh','choi','tramyt','quancom','taphoa','cafe','logach','truong','bagian','chua','well','bridge','causong','ben','caukhi']:
    FOLD[b]='congtrinh/'+b; FOLD[b+'2']='congtrinh/'+b
FOLD.update({'caukhid':'congtrinh/caukhi','caukhid2':'congtrinh/caukhi','ben3':'congtrinh/ben','ben4':'congtrinh/ben'})
for m in glob.glob(S+'/bdx/mini_*'):
    k=os.path.basename(m)[5:]; FOLD['mini_'+k]='hoaco/'+k
M=json.load(open(S+'/bdx/meta.json'))
PX=2.0; X0,X1,Y0,Y1=-160,160,-270,90
def place(im,x,y,w,h,flip=False):
    W,H=int((X1-X0)*PX),int((Y1-Y0)*PX)
    c=Image.new('RGBA',(W,H))
    if flip: im=im.transpose(Image.FLIP_LEFT_RIGHT); x=-(x+w)
    s=im.resize((max(1,round(w*PX)),max(1,round(h*PX))),Image.BOX)
    c.alpha_composite(s,(int(round((x-X0)*PX)),int(round((y-Y0)*PX)))) if x-X0>=0 and y-Y0>=0 else c.paste(s,(int(round((x-X0)*PX)),int(round((y-Y0)*PX))),s)
    return np.asarray(c).astype(np.float32)/255
cache={}
def frames(fd):
    if fd in cache: return cache[fd]
    a=json.load(open(G+fd+'/atlas.json'));F=a.get('frames',a);ppu=a.get('px_per_unit',9)
    L=[]
    for k,f in F.items():
        if not (k.startswith('d') or k.endswith('d')) or k.startswith('co_'): continue
        if k.endswith('n') and not k.startswith('d'): continue
        im=Image.open(G+fd+'/'+f['file']).convert('RGBA')
        L.append((k,f,im))
    cache[fd]=L;return L
def score(A,B):
    a=A[...,3];b=B[...,3];u=np.maximum(a,b).sum()+1e-6
    iou=np.minimum(a,b).sum()/u
    m=(a>.5)&(b>.5);cd=np.abs(A[...,:3]-B[...,:3])[m].mean() if m.any() else 1
    return iou-cd
out={};rep=[]
for key,e in sorted(M.items()):
    id_,fn=key.split('/');
    if not fn.startswith('d') or id_ not in FOLD: continue
    if e.get('e'): continue
    web=place(Image.open(S+'/bdx/'+key).convert('RGBA'),e['x'],e['y'],e['w'],e['h'])
    best=None
    flip_opts=[False,True] if FOLD[id_].startswith('congtrinh') else [False]
    for k,f,im in frames(FOLD[id_]):
        for fl in flip_opts:
            sc=score(web,place(im,f['ox'],f['oy'],f['gw'],f['gh'],fl))
            if best is None or sc>best[0]: best=(sc,k,fl)
    out[key]={'fold':FOLD[id_],'k':best[1],'flip':best[2],'s':round(float(best[0]),3)}
    rep.append((best[0],key,best[1],best[2]))
json.dump(out,open(S+'/bdmatch.json','w'),indent=0)
for r in sorted(rep)[:40]: print('%.3f %s -> %s %s'%r)
print('n',len(out),'none',sorted(set(k.split('/')[0] for k in M if k.split('/')[0] not in FOLD)))
