# (11-26) Khung sen chung từ bộ 10 ảnh riêng (art/sen/bo10/*.png, 2000x2000 nền trong) -> ui/img/sen/*.webp + khung.json
# Cỡ ở đây tính bằng css px; ảnh lưu P điểm ảnh / css px (Godot thu đúng cỡ lúc ghép: nét ở mọi zoom).
#   python3 lam_khung.py THU_MUC_ANH OUTDIR
import sys, os, json
import numpy as np
from PIL import Image, ImageDraw

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
P = 6.0          # điểm ảnh lưu / css px
T = 7.0          # tre dày (css px) — đo ảnh mẫu Kho: tre ~19 px / bảng 1112 px = 5,8 css
Q = 141.0 / T    # điểm ảnh ảnh gốc / css px của tre (ống tre ảnh góc dày 141 px)


def load(n):
    return Image.open(os.path.join(SRC, n)).convert('RGBA')


def save(im, name, css_w, css_h):
    w, h = max(1, round(css_w * P)), max(1, round(css_h * P))
    im = im.resize((w, h), Image.LANCZOS)
    im.save(os.path.join(OUT, name + '.webp'), lossless=True, method=6)


def crop_bb(im):
    return im.crop(im.getbbox())


def pale(im):   # tre nhạt như ảnh mẫu Kho (vàng mật nhạt, không cam): giảm bão hoà, sáng lên chút
    a = np.array(im).astype(np.float32)
    rgb = a[:, :, :3]
    g = rgb.mean(2, keepdims=True)
    rgb = g + (rgb - g) * 0.8
    rgb = rgb * 0.92 + np.array([238, 214, 160], np.float32) * 0.08
    a[:, :, :3] = np.clip(rgb, 0, 255)
    return Image.fromarray(a.astype(np.uint8), 'RGBA')


M = {"T": T, "giay": [251, 242, 229]}
# ---- tre: lấy hết từ ảnh góc (cùng độ dày, cùng ánh sáng): góc cong, ống trơn ngang/dọc, mắt tre ngang/dọc
g = pale(load('01_goc_tre_tron.png'))
OX, OY = 100, 116                     # mép ngoài ống ngang (trên) / ống dọc (trái) của ảnh góc
C = 700                               # góc cắt tới trước mắt tre đầu (mắt ở ~600-672)
goc = g.crop((OX, OY, C, C))
save(goc, 'goc', (C - OX) / Q, (C - OY) / Q)
M["goc"] = [(C - OX) / Q, (C - OY) / Q]
ong_n = g.crop((760, OY, 1240, OY + 150)); save(ong_n, 'ong_n', 480 / Q, 150 / Q)
ong_d = g.crop((OX, 760, OX + 160, 1240)); save(ong_d, 'ong_d', 160 / Q, 480 / Q)
mat_n = g.crop((585, OY, 690, OY + 150)); save(mat_n, 'mat_n', 105 / Q, 150 / Q)
mat_d = g.crop((OX, 585, OX + 160, 690)); save(mat_d, 'mat_d', 160 / Q, 105 / Q)
M["ong_n"] = [150 / Q]; M["ong_d"] = [160 / Q]; M["mat_n"] = [105 / Q, 150 / Q]; M["mat_d"] = [160 / Q, 105 / Q]


def put(name, fname, css_w, anchor, cx, cy, cut=None):
    """anchor: [fx, fy] phần của hộp (0 trái/trên, 1 phải/dưới); cx, cy: điểm neo của ảnh (phần 0..1 của ảnh)"""
    im = load(fname)
    if cut:
        im = cut(im)
    im = crop_bb(im)
    w = css_w; h = css_w * im.height / im.width
    save(im, name, w, h)
    M[name] = {"a": anchor, "c": [cx, cy], "s": [w, h]}
    return im


# chóp đỉnh: thanh vàng dưới chân chóp đè đúng giữa ống tre trên
im = crop_bb(load('04_chop_do_dinh.png')); bar_c = (1107 - 797) / im.height
put('dinh', '04_chop_do_dinh.png', 132, [0.5, 0.0], 0.5, bar_c)
M['dinh']['dy'] = T / 2; M['dinh']['fw'] = [0.58, 160, 230]   # ảnh mẫu: dải đỏ 640/1112 = 58% bề ngang
def mid(im):   # chóp đáy: chỉ lấy chóp giữa + khúc vàng ngắn hai bên (ảnh mẫu không có dải đỏ dài dưới đáy)
    im = crop_bb(im); w = im.width
    return im.crop((int(w * 0.365), 0, int(w * 0.635), im.height))
im = mid(load('05_chop_do_day.png')); bar_c = (1069 - 794) / im.height
put('day', '05_chop_do_day.png', 112, [0.5, 1.0], 0.5, bar_c, mid)
M['day']['dy'] = -T / 2; M['day']['fw'] = [0.095, 30, 34]   # ảnh mẫu: chóp đáy ~ 30 css
# hoa sen góc: tràn ra ngoài khung một phần
put('hoa_tt', '06_hoa_sen_goc_tren_trai.png', 86, [0.0, 0.0], 0.14, 0.40)   # ảnh mẫu: lòi trái 12, lên 32 css
put('hoa_dp', '07_hoa_sen_goc_duoi_phai.png', 112, [1.0, 1.0], 0.87, 0.64)   # ảnh mẫu: phần lớn nằm trong góc dưới phải


# nút đóng: vẽ dấu x kem viền nâu lên nút đỏ
def with_x(im):
    im = im.copy(); d = ImageDraw.Draw(im)
    cx, cy, r = 1000, 1000, 330
    for wdt, col in ((210, (122, 24, 26, 255)), (150, (255, 246, 228, 255))):
        d.line((cx - r, cy - r, cx + r, cy + r), fill=col, width=wdt)
        d.line((cx - r, cy + r, cx + r, cy - r), fill=col, width=wdt)
        for (x, y) in ((cx - r, cy - r), (cx + r, cy + r), (cx - r, cy + r), (cx + r, cy - r)):
            d.ellipse((x - wdt / 2, y - wdt / 2, x + wdt / 2, y + wdt / 2), fill=col)
    return im


put('dong', '08_nut_dong_do_khong_X.png', 30, [1.0, 0.0], 0.5, 0.5, with_x)
M['dong']['dx'] = -20; M['dong']['dy'] = -4   # ảnh mẫu: tâm nút trên thanh tre trên, cách mép phải 20
put('tua', '09_day_tua_do.png', 19, [1.0, 0.0], 0.5, 0.0)
M['tua']['dx'] = -8; M['tua']['dy'] = 12
# sóng hồng: lớp giấy, đáy trái (lật ngang cho đáy phải)
w = load('10_song_hong_day_giay.png'); w = crop_bb(w)
a = np.array(w).astype(np.float32)   # mép trong (phải) mờ dần, không cắt ngang
ramp = np.clip((w.width - np.arange(w.width)) / (w.width * 0.28), 0, 1)
a[:, :, 3] *= ramp[None, :]
w = Image.fromarray(a.astype(np.uint8), 'RGBA')
save(w, 'song', 150, 150 * w.height / w.width)
M['song'] = [150, 150 * w.height / w.width]
json.dump(M, open(os.path.join(OUT, 'khung.json'), 'w'), indent=1)
print(json.dumps(M, indent=1))
