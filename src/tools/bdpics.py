# Xây dựng: món của shop -> khung 9px CÓ SẴN trong godot/<nhóm>/<thư mục>/ (không vẽ lại, không thu nhỏ, lossless đúng từng điểm ảnh).
# Ra: proj/ui/snap/bd_pics.json (món -> gói, khung theo dáng/mùa, lật, lớp, chữ bảng, cờ) + lb/g_<thư mục>.wasm (mỗi khung 1 ảnh + @1..@4 cho lúc zoom xa).
import json,io,struct,os,re,hashlib
from PIL import Image
S='/tmp/claude-0/-home-user/ec30a73d-a632-5817-a52f-4d1a59b285b5/scratchpad'
G='/mnt/project-files/nong-trai-chung/godot/'
C=json.load(open(S+'/proj/ui/snap/bd_cat.json'))
NLEV=4
def seeds(n,f): return {str(s):f(s) for s in range(n)}
P={}   # id -> dict
def put(id_,fold,keys,flip=False,sway=None):
    P[id_]={'b':'g_'+fold.replace('/','_'),'fold':fold,'k':keys,'fx':flip}
    if sway is not None: P[id_]['sw']=sway
one=lambda fr:(lambda s:[fr])
for id_,fold in [('hibiscus','caylang/dambut'),('bougainvillea','kieng/bonggiay'),('areca','caylang/cau'),('bamboo','caylang/tre'),
                 ('hc_bui','caydai/bui_cay'),('hc_co','caydai/bui_co'),('hc_lau','caydai/co_lau')]:
    put(id_,fold,seeds(4,lambda s:['d%d'%(s&3)]),sway=True)
put('duongxi','kieng/duongxi',seeds(2,lambda s:['d%d'%(s&1)]),sway=True)
put('banyan','caylang/da',seeds(4,lambda s:['d%d'%(s&3)]),sway=False)   # web at.plants.banyan sway:0, 4 dáng (seed&3)
put('haystack','caylang/rom',seeds(2,lambda s:['d%d'%(s&1)]),sway=False)
for c in ['cc_bong_trang','cc_lai','cc_huong_duong','cc_luoi_ho','cc_nha_dam','cc_xuong_rong','cc_sa']:
    put(c,'kieng/'+c,seeds(4,lambda s,c=c:['d%s%d'%(c,s&3)]),sway=True)
for f in ['dudu','me','nhan','chomchom','thanhlong','dieu','buoi','mangcut','mit','cam','saurieng','chuoi','man','dua']:
    put('ft_'+f,'caytrai/'+f,seeds(4,lambda s:['d%d%d'%(s>>1,s&1)]),sway=True)
put('ft_xoai','caytrai/xoai',seeds(4,lambda s:['dx%d%d'%(s>>1,s&1)]),sway=True)
# mùa: caosu (t&3)+4*(xi==3?2:xi==2?1:0); mai (t&3)+4*(xi&3)
put('caosu','caylang/caosu',{'%d_%d'%(se,s):['d%d'%(s+4*(2 if se==3 else 1 if se==2 else 0))] for se in range(4) for s in range(4)},sway=True)
put('mai','kieng/mai',{'%d_%d'%(se,s):['d%d'%(s+4*se)] for se in range(4) for s in range(4)},sway=True)
for d in ['da_nui','da_nui_reu','da_nho','da_nho_reu','lunuoc']:
    put(d,'trangtri/'+d,seeds(4,lambda s:['d%d'%(s%3)]),sway=False)
put('goc_cay','caydai/goc_cay',seeds(2,lambda s:['dgoc%d'%(s&1)]),sway=False)
put('nhanh_kho','caydai/nhanh_kho',seeds(2,lambda s:['dnhanh%d'%(s&1)]),sway=False)
put('sung','thuysinh/sung',seeds(4,lambda s:['dsung%d'%(s&3)]),sway=True)
put('rau_muong','thuysinh/rau_muong',seeds(4,lambda s:['drau%d'%(s&3)]),sway=True)
for m in C['LM']:
    if m['id']=='_x': continue
    put('mini_'+m['id'],'hoaco/'+m['id'],seeds(4,lambda s,k=m['id']:['d%s%d'%(k,s&3)]),sway=True)
# nhà: 4 kiểu (t&3), 2 kiểu (t&1), cafe t%3, 1 kiểu bd(+fd); bản số 2 = lật ngang
B={'hutnho':lambda s:['d%d'%(s&3)],'hut':lambda s:['d%d'%(s&3)],'pavilion':lambda s:['d%d'%(s&1)],'choi':lambda s:['d%d'%(s&1)],
   'cafe':lambda s:['d%d'%(s%3)]}
for b in ['hutnho','hut','pavilion','sap','kho','gate','dinh','choi','tramyt','quancom','taphoa','cafe','logach','truong','bagian','chua','well','bridge','causong','shrine']:
    A=json.load(open(G+'congtrinh/'+b+'/atlas.json'))['frames']
    lay=['bd']+(['fd'] if 'fd' in A else [])
    f=B.get(b,lambda s,lay=lay:lay)
    for v,fx in [(b,False),(b+'2',True)]:
        t=next((x for x in C['og'] if x['id']==v),None)
        if t is None: continue
        put(v,'congtrinh/'+b,seeds(max(1,int(t.get('vars',1))),f),flip=fx,sway=False)
put('caukhi','congtrinh/caukhi',{'0':['cd']},False,False); put('caukhi2','congtrinh/caukhi',{'0':['cd']},True,False)
put('caukhid','congtrinh/caukhi',{'0':['ld']},False,False); put('caukhid2','congtrinh/caukhi',{'0':['ld']},True,False)
put('ben','congtrinh/ben',{'0':['0d']},False,False); put('ben2','congtrinh/ben',{'0':['0d']},True,False)
put('ben3','congtrinh/ben',{'0':['1d']},False,False); put('ben4','congtrinh/ben',{'0':['1d']},True,False)
# chữ bảng hiệu (README từng nhà), cờ 10 khung/giây
PM=[[0,0],[9,9],[80,68],[130,110]]
def pmz(z):
    for (a0,b0),(a1,b1) in zip(PM,PM[1:]):
        if z<=a1: return b0+(z-a0)*(b1-b0)/(a1-a0)
    return z
for b in ['cafe','chua','gate','kho','quancom','sap','taphoa','tramyt','truong']:
    txt=open(G+'congtrinh/'+b+'/README.md').read();sg=[]
    for m in re.finditer(r'- "([^"]+)": điểm 3D \(u=([\d.]+), v=([^,]+), z=([\d.]+)\) theo (at\.P\((\d),(\d)\)|EP\(\)), chữ (italic )?(\d+) ([\d.]+)px[^,]*, màu ngày (#[0-9a-f]+|rgba\([^)]*\))',txt):
        t,u,v,z,_,fw,fd,it,wt,px,col=m.groups()
        u=float(u);v=float(v.replace('Yr','2.05')) if 'Yr' not in v else 2.05+float(v.split('+')[1])
        z=float(z)
        if fw is None: fw,fd=3,3;z=pmz(z)
        fw=int(fw);fd=int(fd)
        x=(u-v)*32-(fw-fd)*16;y=(u+v)*16-(fw+fd)*8-z
        sg.append({'t':t,'x':round(x,3),'y':round(y,3),'px':float(px),'w':int(wt),'it':bool(it),'c':col})
    for v in [b,b+'2']:
        if v in P: P[v]['sign']=sg
for b in ['dinh','chua','tramyt']:
    for v in [b,b+'2']:
        if v in P: P[v]['flag']={'b':'g_congtrinh_'+b,'n':12}
for v in ['truong','truong2']:
    P[v]['flag']={'b':'g_congtrinh_dinh','n':12,'tint':'#d6cbbd','dx':24,'dy':16.96}
# gói theo thư mục: chỉ khung ngày (đêm = night_mat như cả làng)
def raw(im):
    b=io.BytesIO();im.save(b,'WEBP',lossless=True,quality=100,method=4,exact=True);return b.getvalue()
os.makedirs(S+'/lb',exist_ok=True)
need={}
for id_,p in P.items():
    s=need.setdefault(p['fold'],set())
    for L in p['k'].values(): s.update(L)
    if 'flag' in p: need.setdefault(p['flag']['b'][2:].replace('congtrinh_','congtrinh/'),set()).update('co_d%02d'%i for i in range(12))
for x in ['ga','cuu','bo','heo','de']: need['congtrinh/chuong_'+x]={'gd','bd','r0d','r1d','f0d','f1d'}
ONLY=os.environ.get('ONLY')
def one(a):
    fold,fr=a
    name='g_'+fold.replace('/','_')
    if os.path.exists(S+'/lb/'+name+'.wasm') and not os.environ.get('FORCE'): return os.path.getsize(S+'/lb/'+name+'.wasm')
    AA=json.load(open(G+fold+'/atlas.json'));A=dict(AA['frames']);A.update(AA.get('flag',{}).get('frames',{}));items=[];meta={};idx={};blob=b'';seen={}
    for k in sorted(fr):
        f=A[k];im=Image.open(G+fold+'/'+f['file']).convert('RGBA')
        meta[k]=[f['ox'],f['oy'],f['gw'],f['gh']]
        items.append((k,raw(im)))
        for l in range(1,NLEV+1):
            w,h=max(1,round(im.width/2**l)),max(1,round(im.height/2**l))
            items.append((k+'@%d'%l,raw(im.resize((w,h),Image.LANCZOS))))
    for k,v in items:
        h=hashlib.md5(v).hexdigest()
        if h not in seen: seen[h]=[len(blob),len(v)];blob+=v
        idx[k]=seen[h]
    hd=json.dumps({'i':idx,'m':meta},separators=(',',':')).encode()
    open(S+'/lb/'+name+'.wasm.tmp','wb').write(struct.pack('<I',len(hd))+hd+blob)
    os.rename(S+'/lb/'+name+'.wasm.tmp',S+'/lb/'+name+'.wasm')
    return len(hd)+len(blob)
from multiprocessing import Pool
jobs=[(f,r) for f,r in sorted(need.items()) if not ONLY or f in ONLY.split(',')]
with Pool(os.cpu_count()) as pool: tot=sum(pool.map(one,jobs,chunksize=1))
for p in P.values(): p.pop('fold')
json.dump(P,open(S+'/proj/ui/snap/bd_pics.json','w'),ensure_ascii=False,separators=(',',':'))
miss=[t['id'] for t in C['og'] if t['id'] not in P and t['id']!='pond']
print('tong',round(tot/2**20,1),'MB; mon co hinh',len(P),'; chua co hinh 9px:',miss)
