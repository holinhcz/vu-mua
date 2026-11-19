# cắt tấm nền trong (alpha): tách món dính nhau bằng lõi co + watershed; giữ thành phần lớn nhất
import sys, numpy as np
from PIL import Image
from scipy import ndimage as nd
from skimage.segmentation import watershed
src, out, names = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
a = np.array(Image.open(src).convert('RGBA')).astype(np.float32); al = a[..., 3]; m = al > 128
for it in (4, 12, 25, 40, 60):
    core = nd.binary_erosion(m, iterations=it)
    lab, n = nd.label(core); sz = nd.sum(core, lab, range(1, n + 1))
    big = [i + 1 for i, v in enumerate(sz) if v > 20000]
    if len(big) == len(names): break
assert len(big) == len(names), (len(big), len(names))
L = watershed(-nd.distance_transform_edt(m), markers=np.isin(lab, big) * lab, mask=m)
objs = []
for i in big:
    ys, xs = np.nonzero(L == i); objs.append((i, ys.mean(), xs.mean(), ys.max() - ys.min()))
h = np.median([o[3] for o in objs])
objs.sort(key=lambda o: (round(o[1] / (h * 0.8)), o[2]))
for (i, _, _, _), name in zip(objs, names):
    reg = L == i
    lb, k = nd.label(reg); s = nd.sum(reg, lb, range(1, k + 1)); reg = lb == (np.argmax(s) + 1)
    mk = nd.binary_dilation(reg, iterations=2) & (al > 0)
    o = np.dstack([a[..., :3], np.where(mk, al, 0)]).astype(np.uint8)
    c = Image.fromarray(o, 'RGBA'); c = c.crop(c.getbbox())
    s = 430 / max(c.size); c = c.resize((round(c.size[0] * s), round(c.size[1] * s)), Image.LANCZOS)
    can = Image.new('RGBA', (512, 512), (0, 0, 0, 0)); can.paste(c, ((512 - c.size[0]) // 2, (512 - c.size[1]) // 2))
    can.save(out + '/' + name + '.png'); print(name, c.size)
