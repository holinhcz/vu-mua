import json,os
from PIL import Image
R='/mnt/project-files/nong-trai-chung/';O=R+'godot/caydai/';L='/tmp/claude-0/-home-user/cfdbc2a3-5703-56ed-a42c-fec6fd071eac/scratchpad/'
W=json.load(open(L+'W.json'))
NM={'tallgrass':'bui_co','wildbush':'bui_cay','reed':'co_lau','goc':'goc_cay','nhanh':'nhanh_kho'}
for k,(src,fr) in W.items():
    p=R+src if os.path.exists(R+src) else L+'live/'+src
    sh=Image.open(p).convert('RGBA'); nm=NM[k]; d=O+nm+'/'; os.makedirs(d,exist_ok=True); a={}
    for fk,v in fr.items():
        x,y,w,h=v[:4]; sh.crop((x,y,x+w,y+h)).save(d+fk+'.png',optimize=True)
        a[fk]={'file':fk+'.png','w':w,'h':h,'ox':v[4],'oy':v[5],'gw':v[6],'gh':v[7]}
    json.dump({'px_per_unit':9,'game_kind':k,'src':src,'frames':a},open(d+'atlas.json','w'),indent=1)
    open(d+'README.md','w').write(f'# {nm} (game: {k})\nCắt nguyên điểm ảnh từ {src} (9 px/đơn vị), mỗi khung 1 PNG. d = ngày, n = đêm, số = dáng.\natlas.json: ox,oy = góc trên trái so với neo (tâm ô, đơn vị game), gw,gh = cỡ vẽ (đơn vị game). Godot: offset=(ox,oy), scale=1/9.\n')
    print(nm,len(fr))
