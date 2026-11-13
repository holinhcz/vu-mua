# cut the web game's 9 px/unit plant sheets into one PNG per frame (pixel-exact, lossless) for Godot
import json,os,re
from PIL import Image
R='/mnt/project-files/nong-trai-chung/';O=R+'godot/'
G=json.load(open('/tmp/claude-0/-home-user/cfdbc2a3-5703-56ed-a42c-fec6fd071eac/scratchpad/G.json'))
F=json.load(open(R+'src/tachanh/frames.json'))
jobs=[]  # (group, name, sheetfile, key, rect)
for k,v in G.items():
    nm=v[8]; grp='caytrai' if nm=='xoai' else 'nongsan'
    jobs.append((grp,nm,R+'img/cay/'+nm+'.webp',k,v))
for g,grp in [('caycanh','caycanh'),('hc','hoaco'),('ts','thuysinh'),('nn','thuysinh')]:
    for k,v in F[g].items():
        nm=v[8].split('/')[1]; jobs.append((grp,nm,R+'img/'+v[8]+'.webp',k,v))
sheets={};atl={}
for grp,nm,sf,k,v in jobs:
    if sf not in sheets: sheets[sf]=Image.open(sf).convert('RGBA')
    x,y,w,h=v[:4]
    im=sheets[sf].crop((x,y,x+w,y+h))
    d=O+grp+'/'+nm+'/';os.makedirs(d,exist_ok=True)
    fn=k+'.png'; im.save(d+fn,optimize=True)
    a=atl.setdefault((grp,nm),{})
    a[k]={'file':fn,'w':w,'h':h,'ox':v[4],'oy':v[5],'gw':v[6],'gh':v[7]}
for (grp,nm),a in atl.items():
    d=O+grp+'/'+nm+'/'
    json.dump({'px_per_unit':9,'frames':a},open(d+'atlas.json','w'),indent=1,ensure_ascii=False)
    open(d+'README.md','w').write(f'''# {nm}
Cắt nguyên điểm ảnh (không thu nhỏ, không nén mất) từ ảnh gốc 9 px/đơn vị của game web, mỗi khung 1 file PNG.
Tên file: chữ đầu d = ngày, n = đêm; số cuối = giai đoạn / dáng (theo khoá gốc của game).
atlas.json: w,h = cỡ ảnh (px); ox,oy = góc trên trái của ảnh so với điểm neo (đơn vị game, neo = tâm ô đất);
gw,gh = cỡ vẽ trong game (đơn vị game) = w/9, h/9. Godot: Sprite2D centered=false, offset=(ox,oy), scale=1/9 nếu 1 đơn vị game = 1 px.
''')
print(len(jobs),'frames',len(atl),'items')
