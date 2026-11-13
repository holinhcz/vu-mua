import struct,sys,os
def read(p):
    b=open(p,'rb').read()
    assert b[:4]==b'GDPC',b[:4]
    ver,ma,mi,pa,flags,fbase=struct.unpack_from('<IIIIIQ',b,4)
    off=4+20+8
    if ver>=3:
        diro,=struct.unpack_from('<Q',b,off);off+=8
    off+=64
    if ver>=3: off=diro
    n,=struct.unpack_from('<I',b,off);off+=4
    fs=[]
    for i in range(n):
        l,=struct.unpack_from('<I',b,off);off+=4
        path=b[off:off+l].rstrip(b'\0').decode();off+=l
        o,s=struct.unpack_from('<QQ',b,off);off+=16
        md5=b[off:off+16];off+=16
        fl,=struct.unpack_from('<I',b,off);off+=4
        fs.append((path,fbase+o,s,fl))
    return ver,(ma,mi,pa),flags,fs,b
if __name__=='__main__':
    ver,ev,flags,fs,b=read(sys.argv[1]);print(ver,ev,flags)
    out=sys.argv[2] if len(sys.argv)>2 else None
    for p,o,s,fl in fs:
        print(p,s,fl)
        if out:
            q=os.path.join(out,p.replace('res://',''));os.makedirs(os.path.dirname(q),exist_ok=True);open(q,'wb').write(b[o:o+s])
