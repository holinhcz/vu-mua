# Bến ghe + miếu cho bờ kênh câu cá: dùng NGUYÊN mô hình 3D của Nông trại (src/benghe/benghe3d.py, src/mieu/mieu3d.py,
# bộ kho3d), chỉ đổi máy quay sang nhìn ngang hơi cao như nha_ngang.py, bỏ bóng dưới đất. 9 px / đơn vị game, ngày + đêm.
#   python3 ct_ngang.py OUT   -> OUT/ben_ngang_d/n.webp, mieu_ngang_d/n.webp, ct.json (neo: bến = đầu bờ mặt nước, miếu = tâm chân)
import sys, os, json, importlib
import numpy as np
from PIL import Image
SRC = '/mnt/project-files/nong-trai-chung/src/'
for d in ('kho', 'dinh', 'benghe', 'mieu', 'pxr'):
    sys.path.insert(0, SRC + d)
PX = 9
SS = 2
EL = 0.18

def go(modname, yaw, foot_uvz, out, name):
    mod = importlib.import_module(modname)
    K = mod.K
    V = K.nv([yaw, 1.0, EL])
    K.TOCAM = V
    K.HALF = K.nv(K.LIGHT + V)
    K.GROUND_SHADOW = False
    RT = K.nv(np.cross(np.array([0.0, 0.0, 1.0]), V) * -1)       # màn phải = (V x lên) đổi dấu -> trục ngang màn
    RT = K.nv(np.array([V[1], -V[0], 0.0]))
    UPs = K.nv(K.UP - (K.UP @ V) * V)
    class R(K.R3):
        def __init__(self, px, P):
            self.px = px
            x = P @ RT; y = -(P @ UPs)
            self.x0, self.y0 = x.min() - 3, y.min() - 3
            self.W = int((x.max() + 3 - self.x0) * px); self.H = int((y.max() + 3 - self.y0) * px)
        def proj(self, P):
            return (P @ RT - self.x0) * self.px, (-(P @ UPs) - self.y0) * self.px, P @ V
    ims = {}
    for n in (0, 1):
        K.VARIANT = 0
        S, _ = K.build(1, np.random.default_rng(K.SEED + 1), with_props=True)
        P = S.arrays()[0]
        r = R(PX * SS, P)
        img = r.run(S, bool(n), target=0.42 if n else K.TARGET_DAY)
        img[..., 3] = (img[..., 3] > 0.999).astype(float)
        img[..., :3] *= img[..., 3:4]
        a = np.clip(img, 0, 1); h, w = a.shape[:2]
        im = Image.frombuffer('RGBa', (w, h), (a * 255 + 0.5).astype(np.uint8).tobytes(), 'raw', 'RGBa', 0, 1)
        ims[n] = im.resize((w // SS, h // SS), Image.LANCZOS).convert('RGBA')
    foot = np.array([[foot_uvz[0] * K.T, foot_uvz[1] * K.T, foot_uvz[2]]])
    ax = float(((foot @ RT) - r.x0)[0] * PX); ay = float((-(foot @ UPs) - r.y0)[0] * PX)
    bb = ims[0].getbbox()
    for n in (0, 1):
        ims[n].crop(bb).save(os.path.join(out, '%s_%s.webp' % (name, 'n' if n else 'd')), lossless=True, quality=100, method=4)
    return dict(w=bb[2] - bb[0], h=bb[3] - bb[1], ax=round(ax - bb[0], 1), ay=round(ay - bb[1], 1), ppu=PX)

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    what = sys.argv[2:] or ['ben', 'mieu']
    meta = json.load(open(os.path.join(out, 'ct.json'))) if os.path.exists(os.path.join(out, 'ct.json')) else {}
    if 'ben' in what:
        meta['ben_ngang'] = go('benghe3d', 0.55, (1.0, 0.0, 0.0), out, 'ben_ngang'); print(meta['ben_ngang'], flush=True)
    if 'mieu' in what:
        meta['mieu_ngang'] = go('mieu3d', 0.0, (0.5, 0.5, 0.0), out, 'mieu_ngang'); print(meta['mieu_ngang'], flush=True)
    json.dump(meta, open(os.path.join(out, 'ct.json'), 'w'))
