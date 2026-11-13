# Thread logic: làm gói logic (pkg/logic.pck + pkg/l/*.wasm), rồi gộp vào bản làng bằng merge_logic.py.
#   python3 build.py [ground_dir]   ground_dir có index.html + pck_<n>.wasm (+ info.json) của thread làng
# Kết quả: S/site (các file khác của làng: engine.wasm, index.js, d/, n/, w/ đã có sẵn trong site/).
import sys,os,json,hashlib,shutil,subprocess,glob
sys.path.insert(0,os.path.dirname(__file__))
import merge_logic as ML
S='/tmp/claude-0/-home-user/ec30a73d-a632-5817-a52f-4d1a59b285b5/scratchpad'
GL='/mnt/project-files/nong-trai-chung/godot-logic/'
GROUND=sys.argv[1] if len(sys.argv)>1 else '/mnt/project-files/nong-trai-chung/src/godot/nen/ban28'
ICONS=['sau','rom','phan','voi','bao','xp','cui']
PKG=S+'/pkg'
PROJ=os.environ.get('PROJ',S+'/proj')
r=subprocess.run([S+'/gd/godot','--headless','--path',PROJ,'--export-pack','Web',S+'/out/logic.pck'],capture_output=True,text=True)
if 'ERROR' in r.stdout+r.stderr: print(r.stdout[-3000:],r.stderr[-3000:]);sys.exit(1)
_,mine=ML.read_pck(open(S+'/out/logic.pck','rb').read())
F={p:d for p,d in mine if p.startswith(('logic/','ui/'))}
UI=PROJ+'/ui/'
for d in ['svg','emo','font','snap','img']:
    for dp,dn,fn in os.walk(UI+d):
        for f in fn:
            if f=='.gdignore': continue
            full=os.path.join(dp,f); F['ui/'+os.path.relpath(full,UI)]=open(full,'rb').read()
for dp,dn,fn in os.walk(GL+'data'):
    for f in fn:
        if f.endswith('.json'):
            full=os.path.join(dp,f);rel='data/'+os.path.relpath(full,GL+'data')
            F[rel]=json.dumps(json.load(open(full)),ensure_ascii=False,separators=(',',':')).encode()
for k in ICONS:
    F['icons/'+k+'.svg']=open(GL+'icons/'+k+'.svg','rb').read()
shutil.rmtree(PKG+'/l',ignore_errors=True); os.makedirs(PKG+'/l',exist_ok=True)
lv={}
for f in sorted(glob.glob(S+'/lb/*.wasm')):
    n=os.path.basename(f)[:-5]
    if os.environ.get('NOG') and n.startswith('g_') and n not in ('g_caylang_da',): continue   # cây đa: n/op của làng chỉ có d0, cần đủ 4 dáng   # hình shop: artifact phụ (n/op), không vào bản chính
    lv[n]=hashlib.md5(open(f,'rb').read()).hexdigest()[:8]
    shutil.copy(f,PKG+'/l/'+n+'.wasm')
F['logic/lv.json']=json.dumps(lv).encode()
if os.environ.get('BN'): F['logic/build.txt']=os.environ['BN'].encode()
open(PKG+'/logic.pck','wb').write(ML.write_pck((3,4,5,1),sorted(F.items())))
# bản làng -> site
SITE=S+'/site'
for f in glob.glob(SITE+'/pck_*.wasm'): os.remove(f)
for f in os.listdir(GROUND):
    if f=='index.html' or (f.startswith('pck_') and f.endswith('.wasm')) or f=='info.json':
        shutil.copy(os.path.join(GROUND,f),SITE+'/'+f)
if not os.path.exists(os.path.join(GROUND,'info.json')):
    shutil.copy(S+'/pub0/info.json',SITE+'/info.json')
sys.argv=['merge_logic.py',SITE,PKG]
ML.main()
