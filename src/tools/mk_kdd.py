# mk_kdd.py: Kho › Đồ dùng (bản web u2vw): lưới thẻ + khung chi tiết -> ui/snap/kdd.json
import json,copy
def L(f): return json.load(open(f))['#pov'][0]
A=L('/tmp/dda.json'); B=L('/tmp/ddb.json')
def F(n,cls):
    if cls in n.get('cls','').split(' '): return n
    for k in n.get('kids',[]):
        r=F(k,cls)
        if r: return r
def FA(n,cls,o=None):
    o=[] if o is None else o
    if cls in n.get('cls','').split(' '): o.append(n)
    for k in n.get('kids',[]): FA(k,cls,o)
    return o
O={}
vw=copy.deepcopy(F(A,'u2vw')); g=F(vw,'u2vg'); li=g['kids']
O['vw']=dict(vw,kids=[dict(g,kids=[]),])
O['li']=li[1]                      # thẻ thường, không giờ
O['sel_css']=F(li[0],'u2vt')['css']  # thẻ đang chọn
O['em']=F(li[0],'u2vr')            # ⏱ giờ còn (thẻ 0)
O['li0']=li[0]
O['ic_bua']=F(li[0],'u2vi')['kids'][0]['svg'] if F(li[0],'u2vi').get('kids') else None
O['ic_com']=F(li[2],'u2vi')['kids'][0]['svg'] if F(li[2],'u2vi').get('kids') else None
O['det']=F(A,'u2vd'); O['det0']=F(B,'u2vd')
json.dump(O,open('/home/claude/vu-mua-src/src/godot/ui/snap/kdd.json','w'),ensure_ascii=False,separators=(',',':'))
print({k:(len(json.dumps(v))) for k,v in O.items()}, O['det0']['r'], O['det']['r'])
print([ (k['tag'],k.get('cls'),[round(x,1) for x in k['r']]) for k in O['li0']['kids'][0]['kids']])
print(json.dumps(F(li[0],'u2vi'))[:300])
D=json.load(open(__import__('os').environ['S']+'/w/dd/dda.json'))['body'][0]
ch=F(D,'ddchips'); O['chips']=ch
json.dump(O,open('/home/claude/vu-mua-src/src/godot/ui/snap/kdd.json','w'),ensure_ascii=False,separators=(',',':'))
def w(n,i=0):
  print(' '*i,n['tag'],n.get('cls'),[round(x,1) for x in n['r']],repr(n.get('text','')),n['css'].get('font-size'),n['css'].get('background-color'))
  for k in n.get('kids',[]): w(k,i+1)
w(ch)
