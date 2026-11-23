#!/usr/bin/env python3
# CẦN CÂU + ỐNG CƯỚC + PHAO cho Câu cá (Link 11-23 "vẽ lại cần câu phao câu ảnh 6px"): tô từng điểm ảnh kiểu khối 3D
# (trụ tròn, sáng từ trên-trái, mờ không bóng loáng, viền mảnh tối hơn màu vật), 6 px mỗi đơn vị.
#   can0.webp   cần trúc nằm ngang: x = cán (0) -> ngọn (phải), y = bề ngang; mép TRÊN ảnh là phía được nắng.
#               Godot dán ảnh dọc theo đường cong của cần (dải tam giác có UV) nên cần vẫn uốn khi kéo cá.
#   ongcuoc.webp ống cước gỗ nhìn thẳng, tâm ở giữa ảnh, Godot xoay cả ảnh.
#   phao0-2.webp phao đứng: cọng lông (trên mặt nước) + thân bấc (dưới nước); can.json ghi dòng mặt nước.
# python3 can_phao.py OUTDIR
import sys, os, json
import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/can'
os.makedirs(OUT, exist_ok=True)
PX = 6.0
SS = 3                      # lấy mẫu dày 3x3 rồi gộp -> mép mịn
LIGHT = np.array([-.45, -.62, .64]); LIGHT /= np.linalg.norm(LIGHT)   # (ngang ảnh, dọc ảnh, ra mặt)

def hexc(h):
    h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)

def rng_noise(n, seed, smooth):
    r = np.random.default_rng(seed).standard_normal(n + smooth * 4)
    k = np.ones(smooth) / smooth
    for _ in range(3):
        r = np.convolve(r, k, 'same')
    r = r[smooth * 2: smooth * 2 + n]
    return r / (np.abs(r).max() + 1e-6)

def shade_cyl(v, side_sign=1.0):
    """v = vị trí ngang trên mặt trụ (-1..1). Trả (sáng khuếch tán, nhẹ phản chiếu)."""
    v = np.clip(v, -1, 1)
    nz = np.sqrt(np.maximum(0, 1 - v * v))
    return nz, v

def finish(col, a, name, edge=None):
    """col (H,W,3) float 0..255 ở lưới SS, a (H,W) 0..1 -> gộp SS, lưu webp lossless + png."""
    H, W = a.shape
    h, w = H // SS, W // SS
    a = a[:h * SS, :w * SS]; col = col[:h * SS, :w * SS]
    pa = (col * a[..., None]).reshape(h, SS, w, SS, 3).mean((1, 3))
    aa = a.reshape(h, SS, w, SS).mean((1, 3))
    c = pa / np.maximum(aa[..., None], 1e-4)
    im = Image.fromarray(np.dstack([np.clip(c, 0, 255), aa * 255]).astype(np.uint8), 'RGBA')
    im.save(os.path.join(OUT, name + '.webp'), lossless=True, quality=100, method=6)
    im.save(os.path.join(OUT, name + '.png'))
    return im

# ============================================================ CẦN TRÚC
def rod():
    LEN, R0, R1 = 240.0, 3.6, 1.0           # dài, bán kính cán, bán kính ngọn (đơn vị)
    PADY = 1.0
    W = int(LEN * PX) * SS; H = int((R0 + .5 + PADY) * 2 * PX) * SS
    xs = (np.arange(W) + .5) / SS / PX      # đơn vị
    ys = (np.arange(H) + .5) / SS / PX - (R0 + .5 + PADY)
    X, Y = np.meshgrid(xs, ys)
    s = X / LEN
    r = R1 + (R0 - R1) * (1 - np.power(s, .8))
    # đốt trúc: khoảng cách đốt dài dần về ngọn
    nodes = []; p = 34.0; seg = 15.0
    while p < LEN - 6:
        nodes.append(p); seg *= 1.1; p += seg
    nodes = np.array(nodes)
    dn = np.min(np.abs(X[..., None] - nodes[None, None, :]), axis=2)       # khoảng tới đốt gần nhất
    sn = np.min(np.where(X[..., None] - nodes[None, None, :] >= 0, X[..., None] - nodes[None, None, :], 99), axis=2)  # sau đốt (phía ngọn)
    bump = np.exp(-(dn / .5) ** 2) * .22 * (r / R0 + .4)
    GRIP = 30.0
    wrap = X < GRIP
    rr = r + bump + np.where(wrap, .28, 0)
    v = Y / rr
    a = np.clip((rr - np.abs(Y)) * PX * SS * .5 + .5, 0, 1)   # mép AA
    # đầu cán cắt bằng, ngọn bo tròn
    a *= np.clip((X - .3) * PX * SS * .5 + .5, 0, 1)
    tipx = LEN - R1 * 1.2
    a *= np.where(X > tipx, np.clip((R1 * 1.2 - np.hypot(X - tipx, Y) * 1.0) * PX * SS * .5 + .5, 0, 1), 1)
    nz, vv = shade_cyl(v)
    n = np.dstack([np.zeros_like(v), vv, nz])
    dif = np.clip(n @ LIGHT, 0, 1)
    # màu trúc khô: vàng rơm, sẫm dần về ngọn (hơ lửa), đốt nâu, vòng phấn trắng ngay dưới đốt
    base = hexc('#d9b874'); tipc = hexc('#9a6a34'); nodec = hexc('#8a5a2a'); waxc = hexc('#efe2b8')
    t_tip = np.clip((s - .62) / .38, 0, 1) ** 1.5
    col = base * (1 - t_tip[..., None]) + tipc * t_tip[..., None]
    # thớ dọc mảnh
    fib = rng_noise(H, 3, max(2, SS * 2))[:, None] * .5 + rng_noise(H, 9, SS * 6)[:, None] * .5
    fib = fib * (.7 + .3 * np.sin(X * .37 + Y * 2))
    col = col * (1 + fib[..., None] * .07)
    # loang nhẹ theo chiều dài (vết khói, nắng)
    blot = rng_noise(W, 5, SS * 90)[None, :]
    col = col * (1 + blot[..., None] * .06)
    wax = np.exp(-((sn - 1.1) / .7) ** 2) * (sn < 3)
    col = col * (1 - wax[..., None] * .5) + waxc * wax[..., None] * .5
    node = np.exp(-(dn / .32) ** 2)
    col = col * (1 - node[..., None] * .75) + nodec * node[..., None] * .75
    # cán quấn dây gai: từng vòng dây xéo, rãnh giữa các vòng tối
    pitch = .9
    ph = (X / pitch + np.arcsin(np.clip(v, -1, 1)) / np.pi * 1.4) % 1.0
    groove = np.clip(np.abs(ph - .5) * 2, 0, 1) ** 3
    cord = hexc('#a06a3c') * (1 - .12 * np.sin(X * 1.3)[..., None])
    cordc = cord * (1 - .45 * groove[..., None])
    wrap_s = wrap & (X > .8)
    col = np.where(wrap_s[..., None], cordc, col)
    # 2 vòng buộc chặn ở 2 đầu cán quấn
    band = (np.abs(X - GRIP + .6) < .55) | (np.abs(X - 1.4) < .6)
    col = np.where(band[..., None], hexc('#5a3a1e') * (1 + .15 * np.sin(Y * 9))[..., None], col)
    # đầu cán: mặt cắt gỗ tối
    col = np.where((X < 1.0)[..., None], col * .7, col)
    # khoen ngọn (dây thép nhỏ)
    ring = (np.abs(X - (LEN - 2.2)) < .35)
    col = np.where(ring[..., None], hexc('#3a3a3a'), col)
    lightk = .34 + .82 * dif
    lightk = lightk * (1 - .18 * np.clip(-v, 0, 1) ** 2)         # phía khuất tối hơn
    out = col * lightk[..., None]
    # viền mảnh = màu vật tối hơn
    rpx = rr * PX * SS
    ed = np.clip((np.abs(Y) * PX * SS - (rpx - 1.3 * SS)) / (1.0 * SS), 0, 1)
    out = out * (1 - ed[..., None] * .6)
    im = finish(out, a, 'can0')
    return dict(w=im.width, h=im.height, len=LEN, r0=R0, r1=R1, grip=GRIP)

# ============================================================ ỐNG CƯỚC GỖ (nhìn thẳng)
def reel():
    R = 8.0
    N = int((R + 1) * 2 * PX) * SS
    c = (np.arange(N) + .5) / SS / PX - (R + 1)
    X, Y = np.meshgrid(c, c)
    rad = np.hypot(X, Y); ang = np.arctan2(Y, X)
    a = np.clip((R - rad) * PX * SS * .5 + .5, 0, 1)
    # 4 lỗ hình hạt đậu giữa 4 nan
    hole = np.zeros_like(rad)
    for k in range(4):
        aa = ang - (k * np.pi / 2 + np.pi / 4)
        aa = (aa + np.pi) % (2 * np.pi) - np.pi
        hd = np.maximum(np.abs(rad - R * .56) - R * .16, np.abs(aa) * rad - R * .2)
        hole = np.maximum(hole, np.clip(-hd * PX * SS * .5 + .5, 0, 1))
    a = a * (1 - hole)
    wood = hexc('#9a6436'); wood2 = hexc('#6e4222')
    grain = np.sin(rad * 5.5 + np.sin(ang * 3) * .6) * .5 + .5
    col = wood * (1 - grain[..., None] * .25) + wood2 * (grain[..., None] * .25)
    # vành nổi + bậc lõm vào trong; trục đồng ở giữa
    rim = np.clip((rad - R * .86) / (R * .14), 0, 1)
    nzr = np.where(rad > R * .86, np.cos(rim * np.pi / 2 * .9), 1)
    nx = np.where(rad > R * .86, X / np.maximum(rad, 1e-3) * np.sin(rim * np.pi / 2 * .9), 0)
    ny = np.where(rad > R * .86, Y / np.maximum(rad, 1e-3) * np.sin(rim * np.pi / 2 * .9), 0)
    # thành lỗ: sáng/tối theo hướng
    hed = np.clip(hole * (1 - hole) * 4, 0, 1)
    dif = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nzr * LIGHT[2], 0, 1)
    lk = .5 + .62 * dif
    inner = (rad < R * .84) & (rad > R * .8)
    lk = np.where(inner, lk * .72, lk)
    hub = rad < R * .2
    hubc = hexc('#c9a24a') * (.8 + .4 * np.clip(-(X + Y) / (R * .2) * .7 + .3, 0, 1))[..., None]
    col = np.where(hub[..., None], hubc, col)
    hubr = np.abs(rad - R * .2) < .25
    col = np.where(hubr[..., None], wood2 * .7, col)
    # núm quay (góc 0, 0.7R)
    kx, ky, kr = R * .7, 0.0, R * .17
    kd = np.hypot(X - kx, Y - ky)
    knob = kd < kr
    kn = np.sqrt(np.clip(1 - (kd / kr) ** 2, 0, 1))
    kdif = np.clip(((X - kx) / kr * LIGHT[0] + (Y - ky) / kr * LIGHT[1] + kn * LIGHT[2]), 0, 1)
    col = np.where(knob[..., None], hexc('#5a361a') * (.55 + .8 * kdif)[..., None], col)
    lk = np.where(knob, 1.0, lk)
    out = col * lk[..., None]
    # bóng đổ của núm xuống dưới-phải
    ksh = (np.hypot(X - kx - .5, Y - ky - .6) < kr) & ~knob
    out = np.where(ksh[..., None], out * .7, out)
    # mép lỗ + mép ngoài viền tối
    ed = np.clip((rad * PX * SS - (R * PX * SS - 1.3 * SS)) / SS, 0, 1)
    out = out * (1 - ed[..., None] * .45)
    hedge = (hole > .02) & (hole < .98)
    out = np.where(hedge[..., None], out * .6, out)
    im = finish(out, a, 'ongcuoc')
    return dict(w=im.width, h=im.height, r=R)

# ============================================================ PHAO
# cọng lông (trên nước) chia khúc màu từ dưới lên; thân bấc hình thoi dưới nước; chân lông có khoen buộc dây
FLOATS = [
    ['phao0', ['#f2efe6', '#2a2a2a', '#f2efe6', '#2a2a2a', '#e8402a', '#ff6a2a'], None],     # lông nhím: trắng đen, đầu đỏ
    ['phao1', ['#2a7a5a', '#e8e0c8', '#2a4aa0', '#e8e0c8', '#e84a2a', '#f8d040'], None],     # lông công
    ['phao2', ['#f2efe6', '#2a2a2a', '#f2efe6', '#2a2a2a', '#e8402a', '#ff6a2a'], '#9adc4a'],  # đèn đêm: bầu sáng xanh trên đỉnh
]
def float_img(name, bands, bulb):
    HS, HB, HT = 26.0, 22.0, 4.0            # cọng trên nước, thân bấc, đuôi dưới thân
    WS, WB = 3.2, 6.4                        # bề ngang cọng (gốc), thân
    top_pad = 3.0 if bulb else 1.0
    Wd = int((WB + 2) * PX) * SS
    Ht = int((HS + HB + HT + top_pad + 1) * PX) * SS
    xs = (np.arange(Wd) + .5) / SS / PX - (WB + 2) / 2
    ys = (np.arange(Ht) + .5) / SS / PX - (HS + top_pad)    # 0 = mặt nước, âm = lên
    X, Y = np.meshgrid(xs, ys)
    # cọng: thon dần lên đỉnh, đỉnh bo tròn
    u = np.clip(-Y / HS, 0, 1)
    rs = (WS / 2) * (1 - .45 * u)
    rb = (WB / 2) * np.sqrt(np.clip(1 - ((Y - HB * .5) / (HB * .5)) ** 2, 0, 1)) ** 1.3 * (1 - .15 * (Y > HB * .5))
    rt = (WS / 2) * .7 * np.clip(1 - (Y - HB) / HT, 0, 1)
    r = np.where(Y < 0, rs, np.maximum(np.where((Y >= 0) & (Y <= HB), rb, 0), np.where(Y >= -0.01, np.where(Y > HB, rt, rs * .9), 0)))
    a = np.clip((r - np.abs(X)) * PX * SS * .5 + .5, 0, 1)
    a *= np.clip((-Y - (-HS)) * 0 + 1, 0, 1)
    tip = np.hypot(X, (Y + HS) * 1.0)
    a = np.where(Y < -HS, np.clip((rs * 1.0 - tip) * PX * SS * .5 + .5, 0, 1), a)
    a = np.where(Y > HB + HT, 0, a)
    v = X / np.maximum(r, 1e-3)
    nz = np.sqrt(np.clip(1 - v * v, 0, 1))
    dif = np.clip(v * LIGHT[0] + nz * LIGHT[2] * 1.0 + .0, 0, 1)
    # màu từng khúc
    nb = len(bands)
    bi = np.clip((u * nb).astype(int), 0, nb - 1)
    pal = np.stack([hexc(b) for b in bands])
    col = pal[bi]
    # vạch phân khúc mảnh
    fr = (u * nb) % 1
    sep = (np.minimum(fr, 1 - fr) < .035) & (Y < 0)
    col = np.where(sep[..., None], col * .72, col)
    # thân bấc: nâu vàng, lỗ rỗ li ti
    cork = hexc('#c8a070')
    pores = (np.random.default_rng(4).random(X.shape) > .985).astype(np.float32)
    corkc = cork * (1 - .25 * pores[..., None]) * (1 + .05 * np.sin(Y * 3.1)[..., None])
    inb = (Y >= 0) & (Y <= HB) & (np.abs(X) < rb + .02)
    col = np.where(inb[..., None], corkc, col)
    # dây buộc ở cổ thân + đuôi lông
    neck = (np.abs(Y - .4) < .35) | (np.abs(Y - HB + .3) < .3)
    col = np.where((neck & (np.abs(X) < rb + .3))[..., None], hexc('#6a3e20'), col)
    tailc = (Y > HB)
    col = np.where(tailc[..., None], hexc('#3a3a3a'), col)
    lk = .45 + .68 * dif
    out = col * lk[..., None]
    # khoen buộc dây ở đuôi
    ey = HB + HT - .6
    ed_ = np.abs(np.hypot(X, Y - ey) - .55) < .2
    out = np.where(ed_[..., None], hexc('#4a4a4a') * .9, out)
    a = np.maximum(a, ed_.astype(np.float32))
    if bulb is not None:
        br = 1.5
        bd = np.hypot(X, (Y + HS + .6) / 1.25)
        bm = bd < br
        bn = np.sqrt(np.clip(1 - (bd / br) ** 2, 0, 1))
        bdif = np.clip(X / br * LIGHT[0] + (Y + HS + .6) / br * LIGHT[1] + bn * LIGHT[2], 0, 1)
        bc = hexc(bulb) * (.6 + .6 * bdif)[..., None]
        out = np.where(bm[..., None], bc, out)
        a = np.maximum(a, np.clip((br - bd) * PX * SS * .5 + .5, 0, 1))
    rpx = r * PX * SS
    edg = np.clip((np.abs(X) * PX * SS - (rpx - 1.2 * SS)) / SS, 0, 1) * (r > 0)
    out = out * (1 - edg[..., None] * .4)
    im = finish(out, a, name)
    return dict(w=im.width, h=im.height, wl=round((HS + top_pad) * PX, 1), hs=HS * PX, hb=HB * PX, ws=WS * PX)

meta = {'px': PX, 'can0': rod(), 'ongcuoc': reel()}
for nm, bands, bulb in FLOATS:
    meta[nm] = float_img(nm, bands, bulb)
json.dump(meta, open(os.path.join(OUT, 'can.json'), 'w'), indent=1)
print(meta)
