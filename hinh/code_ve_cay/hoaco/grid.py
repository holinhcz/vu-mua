# python3 grid.py ids|all [n] out.png : rows = kinds, 4 seeds each, on game ground
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hoaco as H, co
from PIL import Image
ids = H.IDS if sys.argv[1] == 'all' else sys.argv[1].split(',')
night = len(sys.argv) > 2 and sys.argv[2] == 'n'
rows = []
for k in ids:
    ims = [co.to_image(co.render(H.Frame, dict(kind=k, seed=s), H.BB, night)) for s in range(4)]
    rows.append(ims)
w, h = rows[0][0].size
cols = 4 if len(ids) <= 4 else 8
nr = (len(ids) * 4 + cols - 1) // cols
o = Image.new('RGBA', (w * cols, h * nr), (40, 58, 52, 255) if night else (176, 168, 112, 255))
i = 0
for ims in rows:
    for im in ims:
        o.alpha_composite(im, ((i % cols) * w, (i // cols) * h)); i += 1
o.save(sys.argv[3] if len(sys.argv) > 3 else '/tmp/claude-0/g/hoaco_grid.png'); print(o.size)
