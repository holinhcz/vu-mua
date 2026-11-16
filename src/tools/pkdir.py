# Gói 1 thư mục ảnh 9 px (hinh/<nhóm>/<tên>, khung d* (ngày) + n* (đêm)) thành l/<tên gói>.wasm cho Godot: python3 pkdir.py <thư mục> <ra> <tên gói>
import json,io,struct,hashlib,sys
from PIL import Image
src,out,name=sys.argv[1],sys.argv[2],sys.argv[3]
AA=json.load(open(src+'/atlas.json'))['frames']
def raw(im):
    b=io.BytesIO();im.save(b,'WEBP',lossless=True,quality=100,method=4,exact=True);return b.getvalue()
items=[];meta={};idx={};blob=b'';seen={}
for k in sorted(AA):
    if not (k.startswith('d') or k.startswith('n')): continue   # ngày + đêm
    f=AA[k];im=Image.open(src+'/'+f['file']).convert('RGBA')
    meta[k]=[f['ox'],f['oy'],f['gw'],f['gh']]
    items.append((k,raw(im)))
    for l in range(1,5):
        items.append((k+'@%d'%l,raw(im.resize((max(1,round(im.width/2**l)),max(1,round(im.height/2**l))),Image.LANCZOS))))
for k,v in items:
    h=hashlib.md5(v).hexdigest()
    if h not in seen: seen[h]=[len(blob),len(v)];blob+=v
    idx[k]=seen[h]
hd=json.dumps({'i':idx,'m':meta},separators=(',',':')).encode()
open(out+'/'+name+'.wasm','wb').write(struct.pack('<I',len(hd))+hd+blob)
print(name,len(blob)//1024,'KB',list(meta))
