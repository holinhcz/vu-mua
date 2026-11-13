import json,sys,glob,os
from PIL import Image
R='/mnt/project-files/nong-trai-chung/';T5=json.load(open('T5.json'))
items=[a.split(':') for a in sys.argv[2:]]  # kit:src:key
ims=[]
for kit,src,k in items:
  v=T5[src][0][1][k];a=Image.open(R+'img/%s.webp'%src).convert('RGBA').crop((v[0],v[1],v[0]+v[2],v[1]+v[3]))
  a=a.resize((round(v[2]*9/5),round(v[3]*9/5)),Image.BICUBIC)
  w=glob.glob('o9/%s/*.webp'%kit)[0];u=json.load(open('o9/%s/atlas.json'%kit))[k]
  b=Image.open(w).convert('RGBA').crop((u[0],u[1],u[0]+u[2],u[1]+u[3]));ims+=[a,b]
W=sum(i.width for i in ims)+10*len(ims);H=max(i.height for i in ims)
o=Image.new('RGB',(W,H),(150,172,118));x=0
for i in ims:o.paste(i,(x,H-i.height),i);x+=i.width+10
o.save(sys.argv[1]);print(o.size)
