import re,json,sys
exec(open('tools/wcall.py').read().split("roots=sys.argv")[0])
F=json.load(open('gd_refs_file.json'))
allref=set(refs)
for f,roots in F.items():
    miss={}
    for r in roots:
        for c in callees(r):
            if c not in allref: miss.setdefault(c,[]).append(r)
    if not miss: continue
    print('=====',f,len(miss))
    for c,by in sorted(miss.items()):
        i=bodies[c][0]
        print(' ',c,'<-',','.join(by[:4]),'|',s[i:i+90].replace('\n',' '))
