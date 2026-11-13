# xưởng chế biến: ảnh godot/xuong/<tên>/ vào gói lười l/x_<tên>.wasm (mỗi ảnh 1 file webp, mức 0 = đúng byte file gốc,
# không giải mã/không nén lại; mức @1..@4 = Lanczos 1/2^l lossless cho lúc thu nhỏ, như các gói khác). meta = atlas.json.
import json,io,struct,sys,os,glob
from PIL import Image
S='/tmp/claude-0/-home-user/ec30a73d-a632-5817-a52f-4d1a59b285b5/scratchpad'
X='/mnt/project-files/nong-trai-chung/godot/xuong/'
NLEV=4
def raw(im):
    b=io.BytesIO();im.save(b,'WEBP',lossless=True,quality=60,method=4);return b.getvalue()
def pack(name,items,meta):
    idx={};blob=b''
    for k,v in items:
        idx[k]=[len(blob),len(v)];blob+=v
    h=json.dumps({'i':idx,'m':meta},separators=(',',':'),ensure_ascii=False).encode()
    open(S+'/lb/'+name+'.wasm','wb').write(struct.pack('<I',len(h))+h+blob)
    print(name,len(items),(len(h)+len(blob))//1024,'KB')
names=sys.argv[1:] or [d for d in sorted(os.listdir(X)) if os.path.isfile(X+d+'/atlas.json')]
for d in names:
    items=[]
    for f in sorted(glob.glob(X+d+'/*.webp')):
        k=os.path.basename(f)[:-5]
        k=k[len(d)+1:] if k.startswith(d+'_') else k
        data=open(f,'rb').read()
        items.append((k,data))
        if k.endswith(('_d','_n')):   # ảnh cảnh: thêm mức thu nhỏ
            im=Image.open(f).convert('RGBA')
            for l in range(1,NLEV+1):
                w,h=max(1,round(im.width/2**l)),max(1,round(im.height/2**l))
                items.append((k+'@%d'%l,raw(im.resize((w,h),Image.LANCZOS))))
    pack('x_'+d,items,json.load(open(X+d+'/atlas.json')))
