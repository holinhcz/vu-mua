import re,json,sys
exec(open('tools/wcall.py').read().split("roots=sys.argv")[0])
F=json.load(open('gd_refs_file.json'))
allref=set(refs)
EQ=set('fr jr Rg Gn Sa xr Ba kn Jt gr pn ta ae Ko Hi Ol g1 a0 _p Rd Eo X1 go yM Ps Vf ws O1 mix'.split())
def isrender(b):
    return any(k in b for k in ['document.','getContext','innerHTML','.fill(','.stroke(','drawImage','createElement','classList','fillRect','requestAnimationFrame','AudioContext','ctx.'])
res={}
for f,roots in F.items():
    for r in roots:
        if len(r)<2: continue
        for c in callees(r):
            if c in allref or c in EQ: continue
            b=body_at(bodies[c][0])
            if isrender(b) or len(b)<25: continue
            res.setdefault(c,set()).add(f+':'+r)
for c,by in sorted(res.items(), key=lambda x:sorted(x[1])[0]):
    i=bodies[c][0]
    print(c,'<-',','.join(sorted(by)[:4]),'|',s[i:i+130].replace('\n',' '))
