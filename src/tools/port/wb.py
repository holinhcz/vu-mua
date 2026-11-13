import re,sys
s=open(sys.argv[1]).read()
def body(i):
    j=s.index('{',i);d=0;k=j
    while True:
        c=s[k]
        if c=='{':d+=1
        elif c=='}':
            d-=1
            if d==0:return s[i:k+1]
        elif c in '"\'`':
            q=c;k+=1
            while s[k]!=q:
                if s[k]=='\\':k+=1
                k+=1
        k+=1
for n in sys.argv[2:]:
    for m in re.finditer(r'function '+re.escape(n)+r'\(',s):
        print(body(m.start()));print('----')
