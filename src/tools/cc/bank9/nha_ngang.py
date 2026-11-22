# Nhà tranh cho bờ kênh câu cá: dùng NGUYÊN mô hình 3D của Nông trại (src/nhatranh/nha3d.py = nhà lớn,
# src/choi/choi3d.py = nhà nhỏ), chỉ đổi máy quay: nhìn ngang từ trước mặt hơi cao (bờ kênh nhìn ngang, nông trại nhìn xéo
# từ trên), bỏ bóng dưới đất. Vẽ từng điểm ảnh như bên nông trại, 9 px / đơn vị game, ngày + đêm.
#   python3 nha_ngang.py OUT   -> OUT/nha_lon_d.webp, nha_lon_n.webp, nha_nho_d.webp, nha_nho_n.webp, nha.json (neo = chân giữa)
import sys, os, json, math, importlib
import numpy as np
from PIL import Image
SRC = '/mnt/project-files/nong-trai-chung/src/'
for d in ('pxr', 'choi', 'nhatranh', 'chuoi'):
    sys.path.insert(0, SRC + d)

EL = 0.18          # máy quay ngẩng lên ~10 độ: thấy mái, thấy vách
PX = 9
SS = 2

def ngang(mod):
    V = mod.nv([0.0, 1.0, EL])
    mod.TOCAM = V
    mod.HALF = mod.nv(mod.LIGHT + V)
    RT = mod.nv(np.array([1.0, 0.0, 0.0]))
    UPs = mod.nv(mod.UP - (mod.UP @ V) * V)
    # nền đất đắp giữ nguyên (là sàn nhà; thấp, mép cỏ bờ che)
    class R(mod.R3):
        def __init__(self, px, P):
            self.px = px
            x = P @ RT; y = -(P @ UPs)
            self.x0, self.y0 = x.min() - 3, y.min() - 3
            self.W = int((x.max() + 3 - self.x0) * px); self.H = int((y.max() + 3 - self.y0) * px)
        def proj(self, P):
            return (P @ RT - self.x0) * self.px, (-(P @ UPs) - self.y0) * self.px, P @ V
    return R, RT, UPs

def render(mod, R, RT, UPs, t, night):
    mod.VARIANT = t
    rng = np.random.default_rng(5000 + t * 7)
    S = mod.build(t, rng)
    P = S.arrays()[0]
    r = R(PX * SS, P)
    img = r.run(S, night)
    img[..., 3] = (img[..., 3] > 0.999).astype(float)     # bỏ bóng dưới đất (chỉ giữ điểm của nhà)
    img[..., :3] *= img[..., 3:4]
    a = np.clip(img, 0, 1); h, w = a.shape[:2]
    im = Image.frombuffer('RGBa', (w, h), (a * 255 + 0.5).astype(np.uint8).tobytes(), 'raw', 'RGBa', 0, 1)
    im = im.resize((w // SS, h // SS), Image.LANCZOS).convert('RGBA')
    # neo = giữa chân nhà (z = 0) ở mặt trước tường
    T = mod.T
    foot = np.array([[(mod.U0 + mod.U1) / 2 * T, mod.V1 * T, 0.0]])
    ax = float(((foot @ RT) - r.x0)[0] * PX); ay = float((-(foot @ UPs) - r.y0)[0] * PX)
    return im, ax, ay

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    meta = {}
    for name, modname in (('nha_lon', 'nha3d'), ('nha_nho', 'choi3d')):
        mod = importlib.import_module(modname)
        R, RT, UPs = ngang(mod)
        ims = {}
        for n in (0, 1):
            im, ax, ay = render(mod, R, RT, UPs, 0, bool(n))
            ims[n] = im
        bb = ims[0].getbbox()
        for n in (0, 1):
            ims[n].crop(bb).save(os.path.join(out, '%s_%s.webp' % (name, 'n' if n else 'd')), lossless=True, quality=100, method=4)
        meta[name] = dict(w=bb[2] - bb[0], h=bb[3] - bb[1], ax=round(ax - bb[0], 1), ay=round(ay - bb[1], 1), ppu=PX)
        print(name, meta[name], flush=True)
    json.dump(meta, open(os.path.join(out, 'nha.json'), 'w'))
