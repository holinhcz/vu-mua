import os,sys,zlib,json
root=sys.argv[1];M={}
for d,ds,fs in os.walk(root):
  if '.git' in d.split(os.sep): continue
  for f in fs:
    p=os.path.relpath(os.path.join(d,f),root).replace(os.sep,'/')
    if p in('index.html','files.json','.nojekyll') or p.startswith('.git'): continue
    M[p]='%08x'%(zlib.crc32(open(os.path.join(d,f),'rb').read())&0xffffffff)
json.dump(M,open(os.path.join(root,'files.json'),'w'),separators=(',',':'))
print(len(M))
