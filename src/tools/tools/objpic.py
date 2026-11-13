# (b51) Link 11-13 "mỗi vật 1 ảnh riêng ... code đặt ở đâu thì xài đúng ảnh": every object placement points at ONE picture
# file per thing (n/op/<name>.webp), loaded once and shared by every placement; no more per-placement copies in d/ bundles.
#   a thing with a split export in godot/ (matched by content size +-3 px and alpha-weighted colour < 15) uses that export file
#   as is (cropped to its content): name = its godot path, e.g. caylang-dambut-d0
#   a thing without an export keeps its one picture from the village (identical ones stored once): name = kind-<md5 8>
# info.json "op"[j] = [name, x, y, w, h]: world box of the picture's content (top-left at the old picture's content corner)
# usage: python3 objpic.py SITE AUD_OBJ.json OBJPICDIR(level-0 pictures o<j>.webp)
import sys, os, json, hashlib, io
from PIL import Image
SITE, AUD, OD = sys.argv[1:4]
G = '/mnt/project-files/nong-trai-chung/godot/'
I = json.load(open(SITE + '/info.json'))
R = {j: (r[0] if r else None) for k, j, sz, *r in json.load(open(AUD))}
os.makedirs(SITE + '/n/op', exist_ok=True)
op = []; files = {}
for j, o in enumerate(I['objs']):
    p = '%s/o%d.webp' % (OD, j)
    if not os.path.exists(p): op.append(None); continue
    im = Image.open(p).convert('RGBA'); ob = im.getbbox()
    if not ob: op.append(None); continue
    b = R.get(j)
    if b and b[1] < 15:
        name = b[0][:-4].replace('/', '-'); e = Image.open(G + b[0]).convert('RGBA'); pic = e.crop(e.getbbox())
    else:
        pic = im.crop(ob); name = (str(o[6]).split(':')[0] or 'vat') + '-' + hashlib.md5(pic.tobytes()).hexdigest()[:8]
    if name not in files:
        bio = io.BytesIO(); pic.save(bio, 'WEBP', lossless=True, quality=100, method=6, exact=False)
        open('%s/n/op/%s.webp' % (SITE, name), 'wb').write(bio.getvalue()); files[name] = len(bio.getvalue())
    x0 = o[0] if o[0] > -50000 else None
    op.append([name, round(o[0] + ob[0] / 9.0, 3), round(o[1] + ob[1] / 9.0, 3), round(pic.width / 9.0, 3), round(pic.height / 9.0, 3)])
I['op'] = op
I['bundles'] = []; I['bh'] = {}
json.dump(I, open(SITE + '/info.json', 'w'), separators=(',', ':'), ensure_ascii=False)
print('objects', len(op), 'picture files', len(files), 'MB', round(sum(files.values()) / 1e6, 1))
