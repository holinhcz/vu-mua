# tấm ảnh có quầng sáng màu quanh hình (alpha < ~245): bỏ quầng, giữ hình (alpha mép mịn 242..252), cắt theo ô
import sys, json, os
import numpy as np
from PIL import Image
from scipy import ndimage as nd
src, outdir = sys.argv[1], sys.argv[2]
cells = [('me', 0, 0, 512, 512), ('ladua', 512, 0, 1024, 512), ('nep', 1024, 0, 1536, 512),
         ('cachua', 0, 512, 768, 1024), ('tieu', 768, 512, 1536, 1024)]
a = np.array(Image.open(src).convert('RGBA')).astype(float)
al = np.clip((a[..., 3] - 242.0) / 10.0, 0.0, 1.0)
rgb = a[..., :3]
for name, x0, y0, x1, y1 in cells:
    sub = al[y0:y1, x0:x1].copy()
    m = sub > 0.2
    lab, n = nd.label(m, structure=np.ones((3, 3)))
    sz = nd.sum(m, lab, range(1, n + 1))
    big = sz.max()
    keep = np.isin(lab, [i + 1 for i, v in enumerate(sz) if v >= 0.01 * big])
    keep = nd.binary_dilation(keep, iterations=2)
    sub = np.where(keep, sub, 0.0)
    out = np.dstack([rgb[y0:y1, x0:x1], sub * 255]).astype(np.uint8)
    im = Image.fromarray(out, 'RGBA'); im = im.crop(im.getbbox())
    s = 430.0 / max(im.size)
    im = im.resize((round(im.size[0] * s), round(im.size[1] * s)), Image.LANCZOS)
    c = Image.new('RGBA', (512, 512), (0, 0, 0, 0)); c.paste(im, ((512 - im.size[0]) // 2, (512 - im.size[1]) // 2), im)
    c.save(os.path.join(outdir, name + '.png'))
    print(name, im.size)
