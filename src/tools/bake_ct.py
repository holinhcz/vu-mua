# (bản 498) nướng sẵn hình công trình cho Sổ làng › Bộ sưu tập: ảnh gốc xuất từ game (lệnh thử ctdump, hình đúng như bảng Xây dựng)
# -> cắt sát phần có hình, đặt giữa khung vuông, thu Lanczos (nhân alpha) còn 128px -> godot/ui/img/ct/<mã>.webp.
# Dùng: python3 bake_ct.py <thư mục png xuất ra>
import sys, os, glob
from PIL import Image
G = os.path.join(os.path.dirname(__file__), '..', 'godot')
out = os.path.join(G, 'ui/img/ct')
os.makedirs(out, exist_ok=True)
Z = 128
n = 0
for f in sorted(glob.glob(os.path.join(sys.argv[1], '*.png'))):
    im = Image.open(f).convert('RGBA')
    bb = im.getbbox()
    if bb:
        im = im.crop(bb)
    w, h = im.size
    s = max(w, h)
    sq = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    sq.paste(im, ((s - w) // 2, (s - h) // 2))
    r = sq.convert('RGBa').resize((Z, Z), Image.LANCZOS).convert('RGBA') if s > Z else sq
    r.save(os.path.join(out, os.path.basename(f)[:-4] + '.webp'), 'WEBP', quality=92, method=4)
    n += 1
print('baked', n)
