# Cây bông giấy tím + đỏ cho bờ bên này (câu cá): dùng NGUYÊN bộ vẽ bông giấy của Nông trại
# (godot/code_ve_cay/bonggiay/bonggiay.py, 9 px/đơn vị), chỉ thêm 2 bộ màu lá bắc: tím, đỏ (bông giấy thật có 2 màu này).
#   python3 bonggiay_mau.py OUT   -> OUT/bg_tim_d/n.webp, bg_do_d/n.webp, bg.json (neo = gốc cây)
import sys, os, json
import numpy as np
sys.path.insert(0, '/mnt/project-files/nong-trai-chung/godot/code_ve_cay/bonggiay')
import bonggiay as B
B.BRACT += [['#4a1e78', '#6a2fa0', '#8a4ec4', '#b07fe0'],      # 4 tím
            ['#8e0c16', '#bd1a24', '#de3434', '#f2675c']]      # 5 đỏ
B.VEIN += ['#3a145e', '#7a0a12']
out = sys.argv[1]; os.makedirs(out, exist_ok=True)
meta = {}
for name, seed, col in (('bg_tim', 0, 4), ('bg_do', 2, 5)):
    ims = {}
    for n in (0, 1):
        surf, bb = B.render(dict(seed=seed, col=col), bool(n))
        ims[n] = B.to_image(surf)
    a = np.array(ims[0])[:, :, 3]; ys, xs = np.where(a > 0)
    x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(ims[0].width, xs.max() + 3), min(ims[0].height, ys.max() + 3)
    ax0, ay0 = -bb[0] * B.RS, -bb[1] * B.RS
    for n in (0, 1):      # bỏ bóng tròn dưới gốc (nông trại nhìn từ trên; bờ kênh nhìn ngang) như farm_pick.unshadow
        a = np.array(ims[n]).copy()
        al = a[..., 3].astype(int); lum = a[..., :3].astype(int).max(-1)
        yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
        near = ((xx - ax0) / (ims[n].width * .4)) ** 2 + ((yy - ay0) / (ims[n].height * .18)) ** 2 < 1.0
        a[(al < 140) & (lum < 60) & near, 3] = 0
        ims[n] = B.Image.fromarray(a, 'RGBA')
    a = np.array(ims[0])[:, :, 3]; ys, xs = np.where(a > 0)
    x0, y0, x1, y1 = max(0, xs.min() - 2), max(0, ys.min() - 2), min(ims[0].width, xs.max() + 3), min(ims[0].height, ys.max() + 3)
    for n in (0, 1):
        ims[n].crop((x0, y0, x1, y1)).save(os.path.join(out, '%s_%s.webp' % (name, 'n' if n else 'd')), lossless=True, quality=100, method=4)
    meta[name] = dict(w=int(x1 - x0), h=int(y1 - y0), ax=round(float(-bb[0] * B.RS - x0), 1), ay=round(float(-bb[1] * B.RS - y0), 1), ppu=B.RS)
    print(name, meta[name], flush=True)
json.dump(meta, open(os.path.join(out, 'bg.json'), 'w'))
