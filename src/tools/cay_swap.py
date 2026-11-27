# thay ảnh một loại cây làng bằng bộ vẽ mới (hinh/caytrai/<moi>): ảnh n/op + hộp opb/opn + chỗ đặt op (giữ gốc cây)
#   python3 cay_swap.py SITE TEN_CU THU_MUC_MOI [HAU_TO]   vd: cay_swap.py site xoai xoai2 x  (tên cũ caytrai-xoai-dx00)
import sys, json
from PIL import Image
SITE, TEN, MOI = sys.argv[1], sys.argv[2], sys.argv[3]
X = sys.argv[4] if len(sys.argv) > 4 else ''
SRC = '/home/claude/vu-mua-src/hinh/caytrai/' + MOI + '/'
A = json.load(open(SRC + 'atlas.json'))['frames']
I = json.load(open(SITE + '/info.json'))
nb = {}
for k, f in A.items():
    im = Image.open(SRC + f['file']).convert('RGBA'); bb = im.getbbox(); im = im.crop(bb)
    im.save(SITE + '/n/op/caytrai-' + TEN + '-' + k[0] + X + k[1:] + '.webp', lossless=True, method=6)
    nb[k] = [round(f['ox'] + bb[0] / 9, 3), round(f['oy'] + bb[1] / 9, 3), round(im.width / 9, 3), round(im.height / 9, 3)]
n = 0
for k in [k for k in A if k[0] == 'd']:
    nm = 'caytrai-' + TEN + '-d' + X + k[1:]
    o = I['opb'][nm]; b = nb[k]
    for e in I['op']:
        if e and e[0] == nm:
            e[1] = round(e[1] - o[0] + b[0], 3); e[2] = round(e[2] - o[1] + b[1], 3); e[3] = b[2]; e[4] = b[3]; n += 1
    I['opb'][nm] = b
    nn = nb['n' + k[1:]]
    I['opn'][nm] = ['caytrai-' + TEN + '-n' + X + k[1:], round(nn[0] - b[0], 3), round(nn[1] - b[1], 3), nn[2], nn[3], nn[2]]
json.dump(I, open(SITE + '/info.json', 'w'), ensure_ascii=False, separators=(',', ':'))
print(TEN, 'placements', n)
