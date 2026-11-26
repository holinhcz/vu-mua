# (11-26) Khung sen chung từ bộ 10 ảnh riêng (art/sen/bo10/*.png, 2000x2000 nền trong) -> ui/img/sen/*.webp + khung.json
# Cỡ ở đây tính bằng css px; ảnh lưu P điểm ảnh / css px (Godot thu đúng cỡ lúc ghép: nét ở mọi zoom).
#   python3 lam_khung.py THU_MUC_ANH OUTDIR
import sys, os, json
import numpy as np
from PIL import Image, ImageDraw

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
P = 6.0          # điểm ảnh lưu / css px
T = 7.0          # tre dày (css px)
Q = 141.0 / T    # điểm ảnh ảnh gốc / css px của tre (ống tre ảnh góc dày 141 px)


def load(n):
    return Image.open(os.path.join(SRC, n)).convert('RGBA')


def save(im, name, css_w, css_h):
    w, h = max(1, round(css_w * P)), max(1, round(css_h * P))
    im = im.resize((w, h), Image.LANCZOS)
    im.save(os.path.join(OUT, name + '.webp'), lossless=True, method=6)


def crop_bb(im):
    return im.crop(im.getbbox())


M = {"T": T, "giay": [251, 242, 229]}
# ---- tre: lấy hết từ ảnh góc (cùng độ dày, cùng ánh sáng): góc cong, ống trơn ngang/dọc, mắt tre ngang/dọc
g = load('01_goc_tre_tron.png')   # giữ màu vàng gốc: cùng màu thanh vàng của chóp
OX, OY = 100, 116                     # mép ngoài ống ngang (trên) / ống dọc (trái) của ảnh góc
C = 700                               # góc cắt tới trước mắt tre đầu (mắt ở ~600-672)
goc = g.crop((OX, OY, C, C))
save(goc, 'goc', (C - OX) / Q, (C - OY) / Q)
M["goc"] = [(C - OX) / Q, (C - OY) / Q]
ga = np.array(goc)[:, :, 3] > 100
H_, W_ = ga.shape; half = 141 // 2
ex = np.array([np.argmax(ga[y]) if ga[y].any() else 0 for y in range(H_)])
ey = np.array([np.argmax(ga[:, x]) if ga[:, x].any() else 0 for x in range(W_)])
yy, xx = np.mgrid[0:H_, 0:W_]
mk = (xx >= ex[:, None] + half) & (yy >= ey[None, :] + half)
Image.fromarray((mk * 255).astype(np.uint8), 'L').convert('RGBA').save(os.path.join(OUT, 'goc_mask.png'))
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


DINH_W = 254.0   # chóp đỉnh rộng (css): như bản 596 (~54% bề ngang màn)


def chop(fname, y0, y1, css_w, top0):
    im = crop_bb(load(fname))
    a, b = y0 - top0, y1 - top0                       # hàng thanh trong ảnh đã cắt
    k = T / ((b - a) * css_w / im.width)               # tỉ lệ nén thanh
    nb = max(1, round((b - a) * k))
    up = im.crop((0, 0, im.width, a)); bar = im.crop((0, a, im.width, b)).resize((im.width, nb), Image.LANCZOS)
    lo = im.crop((0, b, im.width, im.height))
    out = Image.new('RGBA', (im.width, a + nb + lo.height), (0, 0, 0, 0))
    out.alpha_composite(up, (0, 0)); out.alpha_composite(bar, (0, a)); out.alpha_composite(lo, (0, a + nb))
    return out, (a + nb / 2.0) / out.height


im, c = chop('04_chop_do_dinh.png', 1067, 1157, DINH_W, 797)   # thanh vàng chóp đỉnh = ống tre trên: cùng dày, tâm trùng tâm ống
save(im, 'dinh', DINH_W, DINH_W * im.height / im.width)
M['dinh'] = {"a": [0.5, 0.0], "c": [0.5, c], "s": [DINH_W, DINH_W * im.height / im.width], "dy": T / 2, "fw": [0.81, 170, DINH_W]}
im = crop_bb(load('05_chop_do_day.png')); bar_c = (1069 - 794) / im.height   # chóp đáy như bản 598: nguyên hình, thanh 70 px = T
def side_fade(im):   # hai cánh chóp đáy trong dần ra hai đầu, hoà vào ống tre
    a = np.array(im).astype(np.float32); w = a.shape[1]
    x = np.arange(w); r = np.clip(np.minimum(x, w - 1 - x) / (w * 0.3), 0, 1) ** 1.3
    a[:, :, 3] *= r[None, :]
    return Image.fromarray(a.astype(np.uint8), 'RGBA')
put('day', '05_chop_do_day.png', im.width * T / 70.0, [0.5, 1.0], 0.5, bar_c, lambda im: side_fade(crop_bb(im)))
M['day']['dy'] = -T / 2
# hoa sen góc: tràn ra ngoài khung một phần
put('hoa_tt', '06_hoa_sen_goc_tren_trai.png', 86, [0.0, 0.0], 0.14, 0.40)   # tư thế như ảnh mẫu (không xoay)
put('hoa_dp', '07_hoa_sen_goc_duoi_phai.png', 92, [1.0, 1.0], 0.87, 0.76)   # cân với góc trên trái, nhích lên


# nút đóng: vẽ dấu x kem viền nâu lên nút đỏ
def with_x(im):
    # ảnh gốc bị cụt đáy vòng vàng (hết ở hàng 1895, tròn phải tới 1932): vá đáy bằng cung trên lật xuống, tối đi chút
    a = np.array(im).astype(np.float32)
    for r_ in range(1896, 1933):
        src = a[110 + (1932 - r_)].copy()
        src[:, :3] *= 0.82
        a[r_] = src
    im = Image.fromarray(a.astype(np.uint8), 'RGBA'); d = ImageDraw.Draw(im)
    cx, cy, r = 1002, 1021, 330
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
