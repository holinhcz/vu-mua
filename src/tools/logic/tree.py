import json,sys
def walk(n,d=0):
    t=n.get('text','')
    print('  '*d+n.get('tag','')+'.'+n.get('cls','').replace(' ','.')+('#'+n['id'] if n.get('id') else '')+' '+str([round(x) for x in n.get('r',[])])+' '+repr(t[:50]))
    for k in n.get('kids',[]): walk(k,d+1)
for f in sys.argv[1:]:
    d=json.loads(open(f).read())
    if isinstance(d,str): d=json.loads(d)
    print('=====',f,list(d.keys()))
    for k,v in d.items():
        for n in v: walk(n)
