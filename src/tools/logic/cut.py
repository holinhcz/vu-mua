# cut the web game's sheets into separate pictures and pack them into lazy bundles (l/<name>.wasm):
# [u32 json length][json {name:[offset,length]}][webp bytes...]; every picture is its own webp
import json,io,struct,sys,os
from PIL import Image
S='/tmp/claude-0/-home-user/ec30a73d-a632-5817-a52f-4d1a59b285b5/scratchpad'
IMG='/mnt/project-files/nong-trai-chung/img/'
D='/mnt/project-files/nong-trai-chung/godot-logic/data/'
def enc(im,q=100):
    b=io.BytesIO();im.save(b,'WEBP',quality=q,method=4,alpha_quality=100);return b.getvalue()
def raw(im):
    # level 0: lossless, pixel for pixel the original picture
    b=io.BytesIO();im.save(b,'WEBP',lossless=True,quality=60,method=4);return b.getvalue()
NLEV=4
def lv(k,im,q=100):
    # level 0 = the original picture (lossless); level l = Lanczos 1/2^l (premultiplied alpha) so Godot draws picture px >= screen px
    # with plain linear filtering, like the village ground (no mipmap blur)
    out=[(k,raw(im))]
    for l in range(1,NLEV+1):
        w,h=max(1,round(im.width/2**l)),max(1,round(im.height/2**l))
        out.append((k+'@%d'%l,raw(im.resize((w,h),Image.LANCZOS))))   # every level lossless too (Link: no lossy pictures)
    return out
def pack(name,items,meta):
    idx={};blob=b''
    for k,v in items:
        idx[k]=[len(blob),len(v)];blob+=v
    h=json.dumps({'i':idx,'m':meta},separators=(',',':')).encode()
    out=struct.pack('<I',len(h))+h+blob
    open(S+'/lb/'+name+'.wasm','wb').write(out);print(name,len(items),len(out)//1024,'KB')
G=json.load(open(S+'/cropG.json'))
crops=json.load(open(D+'nong_trai/cay_trong.json'))
grp=lambda lv: 0 if lv<=5 else 1 if lv<=15 else 2 if lv<=30 else 3
sheets={};B=[[],[],[],[]];M=[{},{},{},{}]
for k,f in G.items():
    nm=f[8]
    if nm not in crops: print('skip',k);continue
    if nm not in sheets: sheets[nm]=Image.open(IMG+'cay/'+nm+'.webp').convert('RGBA')
    im=sheets[nm].crop((f[0],f[1],f[0]+f[2],f[1]+f[3]))
    g=grp(crops[nm].get('lv',1))
    B[g]+=lv(k,im);M[g][k]=f[4:8]
for g in range(4): pack('cay%d'%g,B[g],M[g])
# plot soil
od=Image.open(IMG+'odat.webp').convert('RGBA')
F={"ddry":[0,0,594,378],"ndry":[0,378,594,378],"ddrym":[594,0,594,378],"ndrym":[594,378,594,378],"dcrack":[1188,0,594,378],"ncrack":[1188,378,594,378],"dwet":[1782,0,594,378],"nwet":[1782,378,594,378],"dpud":[2376,0,594,378],"npud":[2376,378,594,378]}
items=[x for k,r in F.items() for x in lv(k,od.crop((r[0],r[1],r[0]+r[2],r[1]+r[3])))]
kh=Image.open(IMG+'khoa.webp').convert('RGBA');hw=kh.width//2
items+=lv('dkhoa',kh.crop((0,0,hw,kh.height)))+lv('nkhoa',kh.crop((hw,0,kh.width,kh.height)))
pack('dat',items,{})
# player (nga): the web's own sheet files, byte for byte (no cutting, no re-encoding); Godot draws each frame from it like the web's drawImage
sp=json.load(open(D+'hinh_anh/sprite_nga.json'))
for an in ['walk','idle','run']:
    a=sp[an]
    meta={k:v for k,v in a.items() if k!='fc'}
    pack('nv_'+an,[('sheet',open(IMG+'nga_%s.webp'%an,'rb').read())],meta)
