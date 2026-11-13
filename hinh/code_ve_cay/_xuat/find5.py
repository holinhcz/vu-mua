import re,json
s=open('index.html').read()
def obj(j):
    d=0
    for k in range(j,len(s)):
        d+= s[k]=='{'; d-= s[k]=='}'
        if d==0: return s[j:k+1]
names=['k2_chuoi','k2_dua','k2_dieu','k2_mit','k2_saurieng','k2_buoi','k2_chomchom','k2_mangcut','k2_dudu','k2_cam','k2_man','k2_me','k2_nhan','k2_thanhlong','tre','cau','caosu_b','caosu','dambut','duanuoc','rom','chuoi','dua','dudu','dieu','bonggiay','mai','duongxi','xoai']
out={}
for n in names:
    src='img/%s.webp'%n
    for m in re.finditer(re.escape('"'+src),s):
        p=m.start(); ctx=s[p-40:p]
        if 'w("' in ctx and s[p+len(src)+1:p+len(src)+3]==',{':
            o=obj(p+len(src)+2)
        elif 'src:' in ctx:
            q=s.find('G:{',p,p+600); o=obj(q+2) if q>0 else None
        elif '.src=' in ctx:
            q=max(s.rfind('G={',p-30000,p),s.rfind('G:{',p-30000,p)); o=obj(q+2) if q>0 else None
        else: continue
        try: G=json.loads(o)
        except Exception as e: print(n,'parse fail',ctx); continue
        out.setdefault(n,[]).append((ctx[-20:],G))
for n in names: print(n, [(c,len(g),list(g)[:4]) for c,g in out.get(n,[])])
json.dump(out,open('/tmp/claude-0/-home-user/cfdbc2a3-5703-56ed-a42c-fec6fd071eac/scratchpad/T5.json','w'))
