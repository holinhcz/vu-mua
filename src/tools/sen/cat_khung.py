# (11-25) Cắt khung sen (ảnh mẫu 3000x3000 nền trong của Link, "8458") thành mảnh cho khung chung ui/sen.gd:
#   lớp KHUNG (vẽ trên nội dung): 4 góc (hoa sen, nút đóng + dây tua), chóp đỉnh, chóp đáy, 4 đốt tre lặp theo cạnh;
#   lớp GIẤY (vẽ dưới nội dung): hoa sen nét chìm, sóng hồng, lá sen nổi ở các góc nền (tách khỏi màu giấy kem).
# Toạ độ mảnh tính theo mép NGOÀI vòng tre của ảnh mẫu; chia SRC (điểm ảnh / css px) ra css. Ghi ui/img/sen/*.webp + khung.json.
#   python3 cat_khung.py ANH.png OUTDIR
import sys, os, json
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = 9.0                                   # điểm ảnh ảnh mẫu / css px (tre ảnh mẫu dày ~80 px = 9 css px)
src = Image.open(sys.argv[1]).convert('RGBA')
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
A = np.array(src).astype(np.float32)
OX0, OY0, OX1, OY1 = 318, 266, 2695, 2876     # mép ngoài vòng tre
IX0, IY0, IX1, IY1 = 400, 345, 2603, 2800     # mép trong (giấy)
BASE = np.array([250, 239, 227], np.float32)   # màu giấy

# điểm ảnh "giấy": trong lòng khung, nhạt và ít màu (kể cả nét hoa chìm, lá nổi nhạt); nối liền với giữa giấy
rgb = A[:, :, :3]
light = rgb.mean(2) > 200
sat = rgb.max(2) - rgb.min(2)
paperish = light & (sat < 70)
inner = np.zeros(paperish.shape, bool); inner[IY0 - 6:IY1 + 6, IX0 - 6:IX1 + 6] = True
lab, _ = ndimage.label(paperish & inner)
paper = paperish & inner
# trong vùng hoa sen góc (trên trái, dưới phải) chỉ lấy giấy nối liền giữa giấy: chỗ sáng trong cánh hoa không bị khoét
for (x0, y0, x1, y1) in [(150, 30, 1010, 740), (1960, 2300, 2880, 3000)]:
    sub = paper[y0:y1, x0:x1]; sub &= (lab[y0:y1, x0:x1] == lab[1500, 1500])
# sóng hồng đáy giấy (đậm màu nhưng thuộc nền): vùng hồng trong dải đáy, ngoài chỗ hoa sen góc dưới phải và chóp đáy
pinkw = (rgb[:, :, 0] - rgb[:, :, 1] > 24) & (rgb[:, :, 0] > 200) & (rgb[:, :, 1] > 85) & (rgb[:, :, 2] > 105)
waves = np.zeros_like(paper); waves[2560:IY1 + 4, IX0 - 4:2080] = True
raw = ndimage.binary_opening(pinkw & waves, iterations=2)
pinkw = np.zeros_like(raw)
for x in range(raw.shape[1]):   # sóng: từ đỉnh sóng mỗi cột xuống tới mép tre đều là sóng (vạch trắng trong sóng giữ màu)
    ys = np.where(raw[:, x])[0]
    if ys.size:
        pinkw[ys.min():IY1 + 4, x] = True
pinkw[:, 1080:1940] = False    # dưới chóp đáy: để nguyên cho chóp
paper |= pinkw & inner
paper = ndimage.binary_closing(paper, iterations=2) & inner

def piece(name, box, layer):
    x0, y0, x1, y1 = box
    a = A[y0:y1, x0:x1].copy()
    pm = paper[y0:y1, x0:x1]
    if layer == 'khung':          # bỏ giấy: chỉ giữ tre, hoa, lá, chóp
        al = a[:, :, 3].copy()
        al[pm] = 0
        # mép mịn: giấy sát mép tre / cánh hoa mờ dần 1–2 px
        soft = ndimage.distance_transform_edt(~pm)
        al = np.where(pm, 0, al * np.clip(soft / 2.0, 0, 1))
        a[:, :, 3] = al
    else:                         # giấy: tách nét/sóng khỏi màu kem -> lớp trong suốt phủ lên nền kem
        loc = np.stack([ndimage.median_filter(a[:, :, c], size=61) for c in range(3)], 2)
        d = np.sqrt(((a[:, :, :3] - loc) ** 2).sum(2))
        al = np.clip((d - 5.0) / 32.0, 0, 1)
        wv = pinkw[y0:y1, x0:x1]
        gx = np.arange(x0, x1)[None, :].repeat(y1 - y0, 0)
        fade = np.clip(np.minimum((1080 - gx) / 140.0, 1.0), 0, 1)       # sóng trái mờ dần về phía chóp
        fade = np.where(gx >= 1940, np.clip((gx - 1940) / 120.0, 0, 1), fade)   # sóng phải hiện dần
        al[wv] = fade[wv]                   # sóng hồng giữ nguyên màu
        loc[wv] = a[:, :, :3][wv]
        al[~pm] = 0
        h, w = al.shape; yy, xx = np.mgrid[0:h, 0:w]
        BIG = 10 ** 6   # cạnh nào chạm mép trong khung thì không mờ (giấy liền tre)
        edge = np.minimum.reduce([xx + (BIG if x0 <= IX0 else 0), yy + (BIG if y0 <= IY0 else 0),
                                  w - 1 - xx + (BIG if x1 >= IX1 else 0), h - 1 - yy + (BIG if y1 >= IY1 else 0)]).astype(np.float32)
        al *= np.clip(edge / 60.0, 0, 1)
        col = (a[:, :, :3] - BASE * (1 - al[:, :, None])) / np.maximum(al[:, :, None], 1e-3)
        a[:, :, :3] = np.clip(col, 0, 255)
        a[:, :, 3] = al * 255
    if name == 'k_tt':
        r_ = a[:, :, 0]; g_ = a[:, :, 1]; b_ = a[:, :, 2]
        red = (r_ > 150) & (g_ < 90) & (b_ < 100)
        yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
        a[red & (xx > 560 - x0) & (yy < 330 - y0), 3] = 0
    im = Image.fromarray(a.astype(np.uint8), 'RGBA')
    bb = im.getbbox()
    if bb is None:
        return None
    im = im.crop(bb)
    im.save(os.path.join(OUT, name + '.webp'), lossless=True, method=6)
    return [round((x0 + bb[0]) / SRC, 3), round((y0 + bb[1]) / SRC, 3), round(im.width / SRC, 3), round(im.height / SRC, 3)]

M = {"src": SRC, "outer": [OX0 / SRC, OY0 / SRC, OX1 / SRC, OY1 / SRC], "inner": [IX0 / SRC, IY0 / SRC, IX1 / SRC, IY1 / SRC], "giay": BASE.astype(int).tolist()}
K = {}
# góc: neo theo góc ngoài tương ứng (toạ độ css so với góc đó)
for name, box, ax, ay in [("k_tt", (150, 30, 905, 740), OX0, OY0), ("k_tp", (2380, 80, 2800, 900), OX1, OY0),
                          ("k_dt", (300, 2560, 760, 2900), OX0, OY1), ("k_dp", (1960, 2300, 2880, 3000), OX1, OY1)]:
    r = piece(name, box, 'khung')
    K[name] = [r[0] - ax / SRC, r[1] - ay / SRC, r[2], r[3]]
# chóp: neo giữa cạnh trên / dưới
cx = (OX0 + OX1) / 2.0
for name, box, ay in [("k_dinh", (860, 0, 2160, 380), OY0), ("k_day", (1050, 2560, 1960, 2990), OY1)]:
    r = piece(name, box, 'khung')
    K[name] = [r[0] - cx / SRC, r[1] - ay / SRC, r[2], r[3]]
# đốt tre lặp: cắt giữa hai mắt tre (nối đốt nào cũng khớp); cạnh trên/dưới neo theo mép ngoài trên/dưới, trái/phải theo mép ngoài trái/phải
for name, box, ax, ay in [("e_tren", (2008, 240, 2250, 352), None, OY0), ("e_duoi", (550, 2794, 795, 2905), None, OY1),
                          ("e_trai", (300, 1005, 408, 1278), OX0, None), ("e_phai", (2595, 1005, 2712, 1276), OX1, None)]:
    x0, y0, x1, y1 = box
    a = A[y0:y1, x0:x1].copy(); pm = paper[y0:y1, x0:x1]; a[pm, 3] = 0
    Image.fromarray(a.astype(np.uint8), 'RGBA').save(os.path.join(OUT, name + '.webp'), lossless=True, method=6)
    K[name] = [(x0 - ax) / SRC if ax is not None else 0, (y0 - ay) / SRC if ay is not None else 0, (x1 - x0) / SRC, (y1 - y0) / SRC]
# giấy: các mảng hoa chìm ở góc nền, neo theo góc trong
G = {}
for name, box, ax, ay in [("g_tt", (IX0, IY0, 1420, 1120), IX0, IY0), ("g_tp", (1840, IY0, IX1, 1120), IX1, IY0),
                          ("g_dt", (IX0, 1680, 1250, IY1), IX0, IY1), ("g_dp", (1700, 1420, IX1, IY1), IX1, IY1)]:
    r = piece(name, box, 'giay')
    if r: G[name] = [r[0] - ax / SRC, r[1] - ay / SRC, r[2], r[3]]
r = piece("g_day", (1250, 2250, 1700, IY1), 'giay')
if r: G["g_day"] = [r[0] - (IX0 + IX1) / 2 / SRC, r[1] - IY1 / SRC, r[2], r[3]]
# nút đóng (chỗ bấm) so với góc ngoài trên phải
M["dong"] = [(2426 - OX1) / SRC, (96 - OY0) / SRC, 280 / SRC, 280 / SRC]
M["khung"] = K; M["giay_m"] = G
json.dump(M, open(os.path.join(OUT, 'khung.json'), 'w'), indent=1)
print(json.dumps(M, indent=1))
