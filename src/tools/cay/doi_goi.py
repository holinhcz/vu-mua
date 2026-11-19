# chuyển khung hình cây giữa các gói l/cayN.wasm khi đổi cấp mở (farm.crop_bundle: <=5 cay0, <=15 cay1, <=30 cay2, còn lại cay3)
# usage: python3 doi_goi.py L_DIR ID SRC_BUNDLE DST_BUNDLE
import sys, json, struct
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from them_tam import rd, wr
L, cid, sb, db = sys.argv[1:5]
sj, sd = rd(f'{L}/{sb}.wasm'); dj, dd = rd(f'{L}/{db}.wasm')
n = 0
for k in list(sd):
    base = k.split('@')[0]
    if base[0] in 'dn' and base[1:].rstrip('0123456789') == cid:
        dd[k] = sd.pop(k); n += 1
        if base in sj.get('m', {}): dj.setdefault('m', {})[base] = sj['m'].pop(base)
wr(f'{L}/{sb}.wasm', sj, sd); wr(f'{L}/{db}.wasm', dj, dd); print(cid, sb, '->', db, n, 'khung')
