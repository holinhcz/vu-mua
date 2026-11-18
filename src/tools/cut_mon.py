# Cắt tấm món ăn (bản 308): mỗi hình lớn một món, theo thứ tự hàng trên trái -> phải; bỏ chữ tên bên dưới, bỏ quầng
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage as nd
src, outdir, names = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
bands = [tuple(map(int, b.split('-'))) for b in sys.argv[4].split(',')] if len(sys.argv) > 4 else []   # dải chữ dính vào hình: xoá
im = Image.open(src)
a = np.array(im.convert('RGBA')).astype(np.float32)
rgb = a[..., :3]; al = a[..., 3] / 255.0
if im.mode == 'RGB' or al.min() > 0.99:   # nền trắng: nền = vùng gần trắng nối mép
    d = np.sqrt(((rgb - 255.0) ** 2).sum(-1))
    cand = d < 14
    lab, n = nd.label(cand)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    al = np.where(bg, 0.0, 1.0)
    edge = nd.binary_dilation(bg, iterations=2) & ~bg
    al[edge] = np.clip((d[edge] - 6.0) / 30.0, 0, 1)
    rgb = np.clip((rgb - 255.0 * (1 - al[..., None])) / np.maximum(al, 1e-3)[..., None], 0, 255)
else:
    al = np.where(al < 0.5, 0.0, al)   # quầng mờ quanh hình / chữ
    rgb = np.clip(rgb / np.maximum(al, 1e-3)[..., None], 0, 255)
for y0b, y1b in bands:
    al[y0b:y1b] = 0.0
m = al > 0.5
lab, n = nd.label(m, structure=np.ones((3, 3)))
sz = nd.sum(m, lab, range(1, n + 1))
big = [i + 1 for i, v in enumerate(sz) if v > 30000]
objs = nd.find_objects(lab)
cs = []
for i in big:
    sl = objs[i - 1]
    cs.append((i, sl, (sl[0].start + sl[0].stop) / 2, (sl[1].start + sl[1].stop) / 2))
cs.sort(key=lambda c: (round(c[2] / 300), c[3]))
assert len(cs) == len(names), (len(cs), len(names))
for (i, sl, _, _), name in zip(cs, names):
    y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
    mk = lab == i
    # mẩu nhỏ nằm trong khung hình chính (ớt, lá rời): giữ
    for j in range(1, n + 1):
        if j in big:
            continue
        s2 = objs[j - 1]
        cy2 = (s2[0].start + s2[0].stop) / 2   # tâm mẩu nhỏ nằm trong 95% trên của hình (mẩu chữ sát đáy: bỏ)
        if s2[0].start >= y0 - 4 and cy2 <= y0 + (y1 - y0) * 0.95 and s2[1].start >= x0 - 4 and s2[1].stop <= x1 + 4:
            mk |= lab == j
    keep = nd.binary_dilation(mk, iterations=2)
    out = np.dstack([rgb, np.where(keep, al, 0.0) * 255])[y0 - 3:y1 + 3, x0 - 3:x1 + 3].clip(0, 255).astype(np.uint8)
    c = Image.fromarray(out, 'RGBA'); c = c.crop(c.getbbox())
    s = 430.0 / max(c.size)
    c = c.resize((round(c.size[0] * s), round(c.size[1] * s)), Image.LANCZOS)
    can = Image.new('RGBA', (512, 512), (0, 0, 0, 0)); can.paste(c, ((512 - c.size[0]) // 2, (512 - c.size[1]) // 2), c)
    can.save(os.path.join(outdir, name + '.png'))
    print(name, c.size)
