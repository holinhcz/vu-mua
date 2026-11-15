# mk_ghe.py: ảnh ghe vẽ từ yg bản web (tools/ghe.js, 9 px/đơn vị) -> ui/img/ghe/*.webp + ui/snap/ghe.json (lệch, cỡ theo đơn vị làng)
import sys,glob,os,json
from PIL import Image
src=sys.argv[1]; S=9; OX=800; OY=1350
D='/home/claude/vu-mua-src/src/godot/ui/img/ghe'; os.makedirs(D,exist_ok=True)
M={}
for f in sorted(glob.glob(src+'/*.png')):
    k=os.path.basename(f)[:-4]
    im=Image.open(f).convert('RGBA'); b=im.getbbox()
    if not b: continue
    b=(max(0,b[0]-2),max(0,b[1]-2),min(im.width,b[2]+2),min(im.height,b[3]+2))
    c=im.crop(b); c.save(D+'/'+k+'.webp',quality=92,method=6)
    M[k]=[round((b[0]-OX)/S,3),round((b[1]-OY)/S,3),round(c.width/S,3),round(c.height/S,3)]
json.dump(M,open('/home/claude/vu-mua-src/src/godot/ui/snap/ghe.json','w'),separators=(',',':'))
print(len(M), sum(os.path.getsize(D+'/'+k+'.webp') for k in M)//1024,'KB')
