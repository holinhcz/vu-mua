# print the IIFE module of the web game that contains a given text, lines broken at ; for reading
import sys,re
s=open(sys.argv[1],encoding='utf-8').read()
key=sys.argv[2]; o=s.find(key)
assert o>=0,'not found'
def end(j):
    d=0;k=j;q=None
    while k<len(s):
        c=s[k]
        if q:
            if c=='\\': k+=1
            elif c==q: q=None
        elif c in '"\'`': q=c
        elif c=='{': d+=1
        elif c=='}':
            d-=1
            if d==0: return k
        k+=1
    return k
st=o
while True:
    st=s.rfind('(function(){',0,st)
    if st<0: break
    e=end(st+len('(function()'))
    if e>o:
        break
print('// module',st,e-st, file=sys.stderr)
t=s[st:e+1]
print(t.replace(';',';\n'))
