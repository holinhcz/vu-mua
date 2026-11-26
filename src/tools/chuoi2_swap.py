# thay cây chuối làng bằng chuoi2 (hinh/caytrai/chuoi2): ảnh n/op + hộp opb/opn + chỗ đặt op (giữ chân cây)
import sys, json
from PIL import Image
SITE = sys.argv[1]; SRC = '/home/claude/vu-mua-src/hinh/caytrai/chuoi2/'
A = json.load(open(SRC + 'atlas.json'))['frames']
I = json.load(open(SITE + '/info.json'))
nb = {}
for k, f in A.items():
    im = Image.open(SRC + f['file']).convert('RGBA'); bb = im.getbbox(); im = im.crop(bb)
    im.save(SITE + '/n/op/caytrai-chuoi-' + k + '.webp', lossless=True, method=6)
    nb[k] = [round(f['ox'] + bb[0] / 9, 3), round(f['oy'] + bb[1] / 9, 3), round(im.width / 9, 3), round(im.height / 9, 3)]
n = 0
for k in ['d00', 'd01', 'd10', 'd11']:
    nm = 'caytrai-chuoi-' + k
    o = I['opb'][nm]; b = nb[k]
    for e in I['op']:
        if e and e[0] == nm:
            e[1] = round(e[1] - o[0] + b[0], 3); e[2] = round(e[2] - o[1] + b[1], 3); e[3] = b[2]; e[4] = b[3]; n += 1
    I['opb'][nm] = b
    nn = nb['n' + k[1:]]
    I['opn'][nm] = [nm.replace('-d', '-n'), round(nn[0] - b[0], 3), round(nn[1] - b[1], 3), nn[2], nn[3], nn[2]]
json.dump(I, open(SITE + '/info.json', 'w'), ensure_ascii=False, separators=(',', ':'))
print('placements', n, nb)
