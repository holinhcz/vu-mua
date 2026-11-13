import json,os
from PIL import Image
R='/mnt/project-files/nong-trai-chung/';L='/tmp/claude-0/-home-user/cfdbc2a3-5703-56ed-a42c-fec6fd071eac/scratchpad/'
T=json.load(open(L+'T5.json'));n=0
for src,v in T.items():
    G=v[0][1]
    if src.startswith('k2_'): grp,nm='caytrai',src[3:]
    elif src in('bonggiay','mai','duongxi'): grp,nm='kieng',src
    else: grp,nm='caylang',{'caosu_b':'caosu'}.get(src,src)
    sh=Image.open(R+'img/'+src+'.webp').convert('RGBA'); d=R+'godot/%s/%s/'%(grp,nm); os.makedirs(d,exist_ok=True); a={}
    for fk,f in G.items():
        x,y,w,h=f[:4]; sh.crop((x,y,x+w,y+h)).save(d+fk+'.png',optimize=True); n+=1
        a[fk]={'file':fk+'.png','w':w,'h':h,'ox':f[4],'oy':f[5],'gw':f[6],'gh':f[7]}
    json.dump({'px_per_unit':5,'src':'img/'+src+'.webp','frames':a},open(d+'atlas.json','w'),indent=1)
    open(d+'README.md','w').write(f'# {nm}\nCắt nguyên điểm ảnh từ img/{src}.webp. ẢNH GỐC CHỈ 5 px/đơn vị game (web vẽ cỡ này), không thu nhỏ thêm.\nd = ngày, n = đêm. Cây trái: 2 số = dáng + chín (d<dáng><chín>); chuối dw* = chuối rừng. Cây làng/kiểng: số = dáng/biến thể (cao su theo mùa).\natlas.json: ox,oy = góc trên trái so với neo (tâm ô, đơn vị game), gw,gh = cỡ vẽ (đơn vị game). Godot: offset=(ox,oy), scale=1/5.\n')
print(n)
