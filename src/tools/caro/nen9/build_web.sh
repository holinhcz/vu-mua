cd /home/user/src/src/tools && python3 - <<'PY'
import os
from merge_logic import read_pck, write_pck, _rank
hdr, L = read_pck(open('/home/user/cocaro.pck','rb').read()); F=dict(L)
root='/home/user/cocaro/'; N={}
for d in ['ui/img','ui/font']:
    for dp, dn, fn in os.walk(root+d):
        for f in fn:
            if f=='.gdignore' or f.endswith('.import'): continue
            p=os.path.join(dp,f); k=os.path.relpath(p,root)
            (N if k.startswith('ui/img/caro/nen/') else F)[k]=open(p,'rb').read()
open('/home/user/cocaro_full.pck','wb').write(write_pck(hdr, sorted(F.items(), key=lambda e:(_rank(e[0]),e[0]))))
open('/home/user/nen.pck','wb').write(write_pck(hdr, sorted(N.items(), key=lambda e:(_rank(e[0]),e[0]))))
PY
cd /home/user/vu-mua/cocaro && cp /home/user/cocaro_full.pck caro.pck && cp /home/user/nen.pck nen.pck && O=$(grep -o "PCK=[0-9]*" index.html|cut -d= -f2) && OB=$(grep -o "B='[0-9a-f]*'" index.html) && S=$(stat -c %s caro.pck) && sed -i "s/$O/$S/g; s/$OB/B='$(md5sum caro.pck|cut -c1-8)'/; s/window.NENV='[0-9a-f]*'/window.NENV='$(md5sum nen.pck|cut -c1-8)'/" index.html && ls -la caro.pck nen.pck
