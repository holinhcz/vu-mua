# mk_thu.py: bảng Thư nhà (vl shell gu("thu")) từ bản chụp web w/thu/*.json -> ui/snap/thu.json
import json,copy,os
D=os.environ['S']+'/w/thu/'
def L(n): return json.load(open(D+n+'.json'))['#pov'][0]
def F(n,c,tag=None):
    if (c=='' or c in (n.get('cls') or '').split()) and (tag is None or n['tag']==tag) and (c!='' or tag): return n
    for k in n.get('kids',[]):
        r=F(k,c,tag)
        if r: return r
def I(n,i):
    if n.get('id')==i: return n
    for k in n.get('kids',[]):
        r=I(k,i)
        if r: return r
nho=L('nho'); nho2=L('nho2'); tien=L('tien'); rq=L('rq')
O={}
O['talk']=copy.deepcopy(F(nho,'vl-talk'))
O['rec']=copy.deepcopy(F(nho,'ws-rec'))
O['ok']=copy.deepcopy(F(F(nho2,'ws-rec'),'primary'))
O['jobs_p']=copy.deepcopy(F(tien,'vl-jobs'))
O['jobs']=copy.deepcopy(F(nho,'vl-jobs'))
O['note']=copy.deepcopy(F(rq,'note'))
p=copy.deepcopy(nho); I(p,'vlBody')['kids']=[]; I(p,'vlBody')['cls']='vlBody'
O['#pov']=[p]
json.dump(O,open('/home/claude/vu-mua-src/src/godot/ui/snap/thu.json','w'),ensure_ascii=False,separators=(',',':'))
print({k:len(json.dumps(v)) for k,v in O.items()})
b=O['rec']['kids'][0]['kids'][2]; print(b['css'].get('opacity'),b['css'].get('filter'), O['ok']['css'].get('opacity'))
print(O['talk']['css'].get('padding-top'),O['talk']['kids'][0]['css'].get('font-style'),O['talk']['kids'][0]['css'].get('line-height'))
