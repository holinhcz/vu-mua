# Ô ăn quan 9px (Link 11-22 "vẽ lại sỏi 4k 9px"): 40 viên sỏi dân (10 màu x 4 dáng, giữ màu bản cũ) + 2 viên quan.
# Nhìn thẳng từ trên, nắng trái-trên như sân caro / cờ gánh. Mỗi viên 1 file, viên chiếm 80% khung (code: D = r*2/0.8).
# Dùng: python3 oq9.py <thư mục ra>   (props.py, board2.py chép từ /mnt/project-files/co-caro/src)
import math, sys, os
import numpy as np
import props as P
import board2 as B

PEB = 448      # khung sỏi dân: D lớn nhất ~52 css x 9
QUAN = 1152    # khung quan: D lớn nhất ~126 css x 9
# màu nền + có vân thạch anh + độ mịn, theo 10 cột của atlas cũ
PAL = [
    ((168, 166, 158), 0.0, 'xam'),     # xám tro
    ((176, 172, 160), 0.6, 'xam'),     # xám nhạt có vân
    ((122, 108, 92), 0.0, 'nau'),      # nâu xám
    ((206, 202, 190), 0.6, 'trang'),   # trắng đục có vân
    ((178, 136, 94), 0.0, 'nau'),      # nâu cam
    ((78, 82, 90), 0.8, 'den'),        # đen xanh có vân
    ((206, 180, 140), 0.0, 'nau'),     # vàng kem
    ((128, 140, 126), 0.0, 'xam'),     # xanh rêu xám
    ((222, 220, 214), 0.5, 'trang'),   # trắng sữa
    ((104, 72, 54), 0.0, 'nau'),       # nâu socola
]


def outline(n, rg, R, sq, lump, ax, ang):
    c = n / 2
    xx, yy = P.grid(n)
    x = xx - c; y = yy - c
    ca, sa = math.cos(ang), math.sin(ang)
    u = (x * ca + y * sa) / (R * ax); v = (-x * sa + y * ca) / (R / ax)
    th = np.arctan2(v, u)
    wob = np.zeros_like(th)
    for k in range(2, 6):
        wob += rg.uniform(-1, 1) * lump / k * np.cos(k * th + rg.uniform(0, 6.28))
    e = (np.abs(u) ** sq + np.abs(v) ** sq) ** (1 / sq) / (1 + wob)
    return e, x, y


def stone(n, rg, R, base, vein_p, kind, flat, gloss, ax, lump):
    e, x, y = outline(n, rg, R, rg.uniform(2.0, 2.35), lump, ax, rg.uniform(0, 3.14))
    dome = np.sqrt(np.clip(1 - e ** 2, 0, 1))
    h = (dome ** 0.95) * R * flat
    h += (B.fbm(n, n, n * 0.25, 2, rg) - 0.5) * R * 0.03 * dome
    h += (B.fbm(n, n, max(1.5, n / 160), 2, rg) - 0.5) * R * (0.006 if n < 600 else 0.0025) * dome        # rỗ li ti mặt đá          # mặt gợn rất nhẹ
    gy, gx = np.gradient(h)
    l = np.sqrt(gx ** 2 + gy ** 2 + 1)
    nx, ny, nz = -gx / l, -gy / l, 1 / l
    hl = np.clip(0.5 + 0.5 * (nx * P.L[0] + ny * P.L[1] + nz * P.L[2]), 0, 1)   # nửa-lambert: đỉnh sáng không cháy trắng
    base = np.array(base, np.float32) * rg.uniform(0.95, 1.04)
    tint = np.array([1.0, 1.0, 1.0]) + (rg.random(3) - 0.5) * 0.04
    tone = B.fbm(n, n, n * 0.2, 3, rg)
    col = base * tint * (0.12 + 1.0 * hl ** 1.25)[..., None] * (0.92 + 0.12 * tone)[..., None]
    # loang màu (sỏi suối không đều màu)
    blot = B.fbm(n, n, n * 0.12, 2, rg)
    col *= (0.94 + 0.1 * blot)[..., None]
    # hạt khoáng li ti: chấm tối + đốm sáng thưa
    g1 = B.fbm(n, n, max(1.6, n / 200), 2, rg)
    g2 = B.fbm(n, n, max(2.4, n / 110), 1, rg)
    dk = 0.3 if kind == 'den' else 0.4
    dots = np.clip((g1 - 0.8) * 9, 0, 1) * dk + np.clip((g2 - 0.84) * 8, 0, 1) * 0.25
    col *= (1 - 0.35 * dots)[..., None]
    col += (np.clip(B.fbm(n, n, max(1.3, n / 280), 1, rg) - 0.83, 0, 1) * (260 if kind == 'den' else 180))[..., None]
    # vân thạch anh: 1 đường trắng cong (có khi 2), mờ ở rìa
    if rg.random() < vein_p:
        for _ in range(1 + int(rg.random() < 0.1)):
            a = rg.uniform(0, 3.14)
            dd = (x * math.cos(a) + y * math.sin(a)) / R + 0.1 * np.sin((-x * math.sin(a) + y * math.cos(a)) / R * 2.6 + rg.uniform(0, 6))
            wv = rg.uniform(0.018, 0.034)
            vein = np.exp(-((dd - rg.uniform(-0.35, 0.35)) / wv) ** 2) * (0.75 + 0.25 * B.fbm(n, n, n * 0.05, 2, rg))
            col = col * (1 - 0.8 * vein[..., None]) + np.array([240, 238, 230]) * (0.8 * vein * (0.55 + 0.5 * hl))[..., None]
    # mép tối dần + ánh dội nền đất ở mép phải-dưới
    rimd = np.clip((e - 0.8) / 0.2, 0, 1)
    col *= (1 - 0.10 * rimd ** 2)[..., None]
    bounce = rimd * np.clip((x + y) / R / 1.4, 0, 1)
    col += (bounce * 16)[..., None] * np.array([1.0, 0.85, 0.6])
    # ánh nắng: đốm mờ rộng (mặt mờ) + chút bóng nhỏ khi láng
    r = np.array([P.L[0], P.L[1], 1 + P.L[2]]); r = r / np.linalg.norm(r)     # nửa đường nắng-mắt
    hv = np.clip(nx * r[0] + ny * r[1] + nz * r[2], 0, 1)
    col += (hv ** 14 * 26 * gloss)[..., None] + (hv ** 60 * 60 * gloss)[..., None]
    al = P.blur((e <= 1).astype(np.float32), n / 400)
    return P.rgba(np.clip(col, 0, 255), al)


def peb(i):
    pal = PAL[i % 10]; var = i // 10
    rg = np.random.default_rng(3000 + i * 7)
    R = PEB * 0.4 * rg.uniform(0.86, 0.97)
    return stone(PEB, rg, R, pal[0], pal[1], pal[2], rg.uniform(0.62, 0.78), 0.6 if pal[2] != 'den' else 0.9,
                 rg.uniform(1.0, 1.28), 0.08)


def quan(i):
    rg = np.random.default_rng(9100 + i)
    R = QUAN * 0.4 * 0.97
    if i == 0:   # quan đen xám có vân trắng
        return stone(QUAN, rg, R, (70, 72, 78), 1.0, 'den', 0.6, 1.2, 1.12, 0.05)
    return stone(QUAN, rg, R, (158, 86, 56), 1.0, 'nau', 0.72, 1.2, 1.06, 0.05)   # quan nâu đỏ có vân


if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(os.path.join(out, 'peb'), exist_ok=True)
    jobs = sys.argv[2:] or ['peb', 'quan']
    if 'peb' in jobs:
        for i in range(40):
            P.to_img(peb(i)).save(os.path.join(out, 'peb', 'p%d.webp' % i), lossless=True, method=4)
            print('peb', i, flush=True)
    if 'quan' in jobs:
        for i in range(2):
            P.to_img(quan(i)).save(os.path.join(out, 'peb', 'q%d.webp' % i), lossless=True, method=4)
            print('quan', i, flush=True)
