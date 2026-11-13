import re,json,sys
s=open('web_all.js').read()
refs=set(json.load(open('gd_refs.json')))
def body_at(i):
    j=s.index('{',i);d=0;k=j
    while True:
        c=s[k]
        if c=='{':d+=1
        elif c=='}':
            d-=1
            if d==0:return s[j:k+1]
        elif c in '"\'':
            q=c;k+=1
            while s[k]!=q:
                if s[k]=='\\':k+=1
                k+=1
        k+=1
bodies={}
for m in re.finditer(r'function ([A-Za-z_$][\w$]*)\(',s):
    bodies.setdefault(m.group(1),[]).append(m.start())
for m in re.finditer(r'(?<![\w$.])([A-Za-z_$][\w$]{0,3})\s*=\s*function\s*\(',s):
    bodies.setdefault(m.group(1),[]).append(m.start())
defs=set(bodies)
def callees(n):
    out=set()
    for i in bodies.get(n,[]):
        try:b=body_at(i)
        except Exception:continue
        for w in re.findall(r'(?<![\w$.])([A-Za-z_$][\w$]*)\(',b):
            if w in defs and w!=n and len(w)<=3: out.add(w)
    return out
roots=sys.argv[1].split(',');depth=int(sys.argv[2])
seen={};fr=roots
for d in range(depth+1):
    nx=[]
    for n in fr:
        if n in seen:continue
        seen[n]=d
        if d<depth: nx+=list(callees(n))
    fr=nx
miss=[n for n in seen if n not in refs]
print('total',len(seen),'missing',len(miss))
for n in sorted(miss,key=lambda x:seen[x]):
    i=bodies.get(n,[0])[0]
    print(seen[n],n,len(bodies.get(n,[])),s[i:i+110].replace('\n',' '))
