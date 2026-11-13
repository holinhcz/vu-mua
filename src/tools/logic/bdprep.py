# dữ liệu Xây dựng từ bản web: danh mục (og, LM, Yz, Kz, chuồng, hạng làng...) + bản đồ ô làng mới (fo/Il/Uz/fM/p0/yc/hu) + So/hu
import json
S='/tmp/claude-0/-home-user/ec30a73d-a632-5817-a52f-4d1a59b285b5/scratchpad/'
O=S+'proj/ui/snap/'
L=lambda f: json.loads(json.loads(open(S+f).read()))
cat=L('cat.json'); mp=L('map.json'); hu=L('hu.json')
del cat['kinds']
json.dump(cat,open(O+'bd_cat.json','w'),ensure_ascii=False,separators=(',',':'))
B=mp['B']; T=mp['T']
P=[];IL=[''];RD=['']
def ix(a,v):
    if v not in a: a.append(v)
    return a.index(v)
rows=[];yc={};hum={}
for y in range(B[2],B[3]):
    r=[]
    for x in range(B[0],B[1]):
        t=T.get('%d,%d'%(x,y))
        if not t or not t['p']: r.append(0); continue
        v=(ix(P,t['p'])+1)|(ix(IL,t['il'])<<8)|(ix(RD,t['rd'])<<12)|(t['n2']<<15)|(t['fm']<<16)|(t['p0']<<17)
        r.append(v)
        if t.get('yc'): yc['%d,%d'%(x,y)]=t['yc']
    rows.append(r)
# hu: ô -> chỉ số trong H (theo key)
H=hu['L']; kix={o['key']:i for i,o in enumerate(H)}
for k,t in T.items():
    if 'hu' in t:
        pass
# web hu map: mỗi ô của vật đều trỏ về vật; dựng lại từ footprint
for i,o in enumerate(H):
    for a in range(o['fw']):
        for b in range(o['fd']):
            hum['%d,%d'%(o['gx']+a,o['gy']+b)]=i
SS=[[o['sk'],o['id'],o['kind'][0],o['gx'],o['gy'],o['fw'],o['fd'],o['seed'],o['wild'],o['ring'],o['pc'],round(o['k'],3),o['sx'],o['sy'],o['bb']] for o in mp['S']]
HH=[[o['key'],o['id'],o['kind'][0],o['gx'],o['gy'],o['fw'],o['fd'],o['seed'],o['hill'],o['pc'],round(o['k'],3),o['sx'],o['sy'],o['bb'],o['scn'],o['gr']] for o in H]
json.dump({'B':B,'P':P,'IL':IL,'RD':RD,'rows':rows,'yc':yc,'hu':hum,'S':SS,'H':HH,'X8':mp['X8']},open(O+'bd_map.json','w'),ensure_ascii=False,separators=(',',':'))
import os;print(os.path.getsize(O+'bd_map.json')//1024,'KB', P, IL, RD)
