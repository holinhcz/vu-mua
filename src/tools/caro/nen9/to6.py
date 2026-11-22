# cảnh caro 9px -> 6px (Link 11-23 "giảm về 6 7px còn nét ko"): Lanczos từ bản gốc không nén, lưu webp q90 alpha 100
import sys,os
from PIL import Image
L='/mnt/project-files/co-caro/nen_lossless/'; G=sys.argv[1]; F=6/9
for f in sorted(os.listdir(G)):
    if not f.endswith('.webp'): continue
    n=f[:-5]
    if n=='tre': im=Image.open(L+'tre.webp').crop((447,810,3330,6394))
    elif n=='mai': im=Image.open(L+'mai.webp.4k')
    elif os.path.exists(L+f): im=Image.open(L+f)
    else: im=Image.open(G+'/'+f)
    im=im.convert('RGBA'); w,h=im.size
    o=im.resize((max(1,round(w*F)),max(1,round(h*F))),Image.LANCZOS)
    o.save(G+'/'+f,quality=90,alpha_quality=100,method=6)
    print(n,(w,h),'->',o.size,round(os.path.getsize(G+'/'+f)/1e6,2))
