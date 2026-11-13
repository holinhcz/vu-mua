# extract named functions from the minified web game and break lines for reading
import sys,re
s=open(sys.argv[1],encoding='utf-8').read()
def fn(name,start=0):
    i=s.find('function '+name+'(',start)
    if i<0: return ''
    j=s.find('{',i);d=0;k=j;q=None
    while k<len(s):
        c=s[k]
        if q:
            if c=='\\': k+=1
            elif c==q: q=None
        elif c in '"\'': q=c
        elif c=='{':d+=1
        elif c=='}':
            d-=1
            if d==0:break
        k+=1
    return s[i:k+1]
for n in sys.argv[3:]:
    t=fn(n)
    print('//// '+n+' ('+str(len(t))+')')
    print(re.sub(r';(?=[^"\']*$)',';\n',t) if False else t.replace(';',';\n'))
