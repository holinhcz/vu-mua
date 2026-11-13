import re,json,collections,glob
s=open('web_all.js').read()
refs=set(json.load(open('gd_refs.json')))
gd=' '.join(open(f).read() for f in glob.glob('proj/logic/*.gd'))
def body(i):
    j=s.index('{',i);d=0;k=j
    while True:
        c=s[k]
        if c=='{':d+=1
        elif c=='}':
            d-=1
            if d==0:return s[j:k+1]
        elif c in '"\'`':
            q=c;k+=1
            while k<len(s) and s[k]!=q:
                if s[k]=='\\':k+=1
                k+=1
        k+=1
K=collections.defaultdict(lambda:[0,0,[]])
for m in re.finditer(r'function ([A-Za-z_$][\w$]*)\(',s):
    n=m.group(1)
    try:b=body(m.start())
    except Exception:continue
    if len(b)>20000:continue
    ks=collections.Counter(re.findall(r'(?<![\w$.])g\.([a-zA-Z_$][\w$]*)',b))
    if not ks:continue
    k=ks.most_common(1)[0][0]
    K[k][0]+=1
    if n in refs:K[k][1]+=1
    else:K[k][2].append(n)
for k,(t,o,miss) in sorted(K.items(),key=lambda x:-x[1][0]):
    has=('g.'+k in gd) or ('"'+k+'"' in gd)
    print(f'{k:10} {o:3}/{t:<3} godot_state={"có" if has else "KHÔNG"}  thiếu: {" ".join(miss)[:110]}')
