# gói dg_fx: hình HUD / hiệu ứng (icon 7 vật phẩm, mặt thúng, mây giông, bụi)
import glob, os
from PIL import Image
from mk_bundles import pack, webp
items = []; meta = {}
for f in sorted(glob.glob('out/fx/*.png')):
    k = os.path.basename(f)[:-4]; im = Image.open(f).convert('RGBA'); items.append((k, webp(im))); meta[k] = list(im.size)
pack('dg_fx', items, {'sz': meta})
