# (bản 497) nướng sẵn hình món: ui/svg/kh/*.svg bọc ảnh webp 512px -> ui/img/kh/<mã>.webp 128px và <mã>_64.webp 64px (thu Lanczos có nhân alpha).
# Godot giải ảnh 512 + thu nhỏ mỗi hình ~15ms trên web (mở Bộ sưu tập / Kho lần đầu giựt); ảnh 128 giải ~1ms. Chạy lại khi đổi hình món.
import re, base64, io, glob, os, sys
from PIL import Image
G = os.path.join(os.path.dirname(__file__), '..', 'godot')
out = os.path.join(G, 'ui/img/kh')
os.makedirs(out, exist_ok=True)
n = 0
for f in sorted(glob.glob(os.path.join(G, 'ui/svg/kh/*.svg'))):
    s = open(f).read()
    m = re.search(r'data:image/(\w+);base64,([^"]+)"', s)
    if not m:
        continue
    org = os.path.join(G, '..', 'art', 'kh_512', os.path.basename(f)[:-4] + '.' + m.group(1))   # (bản 533) gốc 512 để ngoài gói, svg chỉ còn 256
    im = Image.open(org if os.path.exists(org) else io.BytesIO(base64.b64decode(m.group(2)))).convert('RGBA')
    pm = im.convert('RGBa')
    for z, suf in ((128, ''), (64, '_64')):
        pm.resize((z, z), Image.LANCZOS).convert('RGBA').save(os.path.join(out, os.path.basename(f)[:-4] + suf + '.webp'), 'WEBP', quality=92, method=4)
    n += 1
print('baked', n)
