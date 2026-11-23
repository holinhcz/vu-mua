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

# ============================================================ 4 CẤP CẦN
# trúc (ông nội) -> tre già ám khói -> câu lục 3 khúc sơn mài khâu đồng -> cần ông Năm gỗ mun chỉ vàng. To dần theo cấp.
RODS = [
    dict(name='can0', R0=3.6, R1=1.0, body='truc', grip='gai', cap='cut', guides=0),
    dict(name='can1', R0=3.9, R1=1.1, body='tre', grip='may', cap='cut', guides=0),
    dict(name='can2', R0=4.1, R1=1.05, body='lac', grip='da', cap='brass', guides=5),
    dict(name='can3', R0=4.4, R1=1.15, body='mun', grip='to', cap='brass', guides=6),
]
def band_mask(X, xs, half):
    m = np.zeros_like(X, bool)
    for x in xs:
        m |= np.abs(X - x) < half
    return m

def rod(cf):
    LEN, R0, R1 = 240.0, cf['R0'], cf['R1']
    body = cf['body']
    PADY = 1.6
    W = int(LEN * PX) * SS; H = int((R0 + .5 + PADY) * 2 * PX) * SS
    xs = (np.arange(W) + .5) / SS / PX
    ys = (np.arange(H) + .5) / SS / PX - (R0 + .5 + PADY)
    X, Y = np.meshgrid(xs, ys)
    s = X / LEN
    r = R1 + (R0 - R1) * (1 - np.power(s, .8))
    GRIP = 30.0 if body != 'mun' else 34.0
    rr = r.copy()
    nodes = np.array([])
    if body in ('truc', 'tre'):
        nl = []
        p, seg, gr = (34.0, 15.0, 1.1) if body == 'truc' else (40.0, 22.0, 1.12)
        while p < LEN - 6:
            nl.append(p); seg *= gr; p += seg
        nodes = np.array(nl)
        dn = np.min(np.abs(X[..., None] - nodes[None, None, :]), axis=2)
        sn = np.min(np.where(X[..., None] - nodes[None, None, :] >= 0, X[..., None] - nodes[None, None, :], 99), axis=2)
        bw, bh = (.5, .22) if body == 'truc' else (.75, .36)
        rr = rr + np.exp(-(dn / bw) ** 2) * bh * (r / R0 + .4)
    ferr = [86.0, 163.0] if body == 'lac' else []
    if ferr:
        fm = band_mask(X, ferr, 1.4)
        rr = rr + np.where(fm, .32, 0)
        # mỗi khúc trên nhỏ hơn khúc dưới một nấc
        for f in ferr:
            rr = rr - np.where(X > f + 1.4, .12, 0)
    gu = []
    if cf['guides']:
        gu = list(np.linspace(GRIP + 40, LEN - 12, cf['guides']))
    wrap = X < GRIP
    rr = rr + np.where(wrap, .3, 0)
    capw = {'cut': 0.0, 'brass': 2.2 if body == 'lac' else 2.8}[cf['cap']]
    if capw:
        rr = np.where(X < capw, rr + .2, rr)
    v = Y / rr
    a = np.clip((rr - np.abs(Y)) * PX * SS * .5 + .5, 0, 1)
    a *= np.clip((X - .3) * PX * SS * .5 + .5, 0, 1)
    tipx = LEN - R1 * 1.2
    a *= np.where(X > tipx, np.clip((R1 * 1.2 - np.hypot(X - tipx, Y)) * PX * SS * .5 + .5, 0, 1), 1)
    nz = np.sqrt(np.maximum(0, 1 - np.clip(v, -1, 1) ** 2))
    n = np.dstack([np.zeros_like(v), np.clip(v, -1, 1), nz])
    dif = np.clip(n @ LIGHT, 0, 1)
    fib = rng_noise(H, 3, max(2, SS * 2))[:, None] * .5 + rng_noise(H, 9, SS * 6)[:, None] * .5
    fib = fib * (.7 + .3 * np.sin(X * .37 + Y * 2))
    blot = rng_noise(W, 5, SS * 90)[None, :]
    spec = np.zeros_like(X)
    if body == 'truc':
        base = hexc('#d9b874'); tipc = hexc('#9a6a34'); nodec = hexc('#8a5a2a'); waxc = hexc('#efe2b8')
        t_tip = np.clip((s - .62) / .38, 0, 1) ** 1.5
        col = base * (1 - t_tip[..., None]) + tipc * t_tip[..., None]
        col = col * (1 + fib[..., None] * .07) * (1 + blot[..., None] * .06)
        wax = np.exp(-((sn - 1.1) / .7) ** 2) * (sn < 3)
        col = col * (1 - wax[..., None] * .5) + waxc * wax[..., None] * .5
        node = np.exp(-(dn / .32) ** 2)
        col = col * (1 - node[..., None] * .75) + nodec * node[..., None] * .75
    elif body == 'tre':
        # tre già ám khói: nâu mật, loang khói đậm, vệt cháy xém quanh đốt, đốt to
        base = hexc('#9a6434'); tipc = hexc('#5e3818'); nodec = hexc('#3e220e')
        t_tip = np.clip((s - .55) / .45, 0, 1) ** 1.3
        col = base * (1 - t_tip[..., None]) + tipc * t_tip[..., None]
        smoke = rng_noise(W, 11, SS * 40)[None, :] * .6 + rng_noise(W, 17, SS * 9)[None, :] * .4
        col = col * (1 + fib[..., None] * .09) * (1 + smoke[..., None] * .16)
        scorch = np.exp(-(dn / 2.2) ** 2) * .35
        col = col * (1 - scorch[..., None])
        node = np.exp(-(dn / .45) ** 2)
        col = col * (1 - node[..., None] * .8) + nodec * node[..., None] * .8
        # sẹo mắt tre lác đác
        for kx in nodes[1::2]:
            m = np.hypot((X - kx - 1.6) / 1.1, (Y - rr * .25) / .55) < 1
            col = np.where(m[..., None], col * .62, col)
    elif body == 'lac':
        # sơn mài nâu đỏ, mỗi khúc 1 sắc hơi khác; khâu đồng ở 2 chỗ ráp
        base = hexc('#8a3020')
        seg = (X > ferr[0]).astype(np.float32) + (X > ferr[1]).astype(np.float32)
        col = base * (1 - .06 * seg)[..., None]
        col = col * (1 + fib[..., None] * .025) * (1 + blot[..., None] * .03)
        spec = np.exp(-((v + .45) / .18) ** 2) * .22
        brass = hexc('#c99a42')
        fmv = band_mask(X, ferr, 1.4)
        col = np.where(fmv[..., None], brass, col)
        edge = band_mask(X, [f - 1.25 for f in ferr] + [f + 1.25 for f in ferr], .16)
        col = np.where(edge[..., None], brass * .55, col)
        spec = np.where(fmv, np.exp(-((v + .4) / .25) ** 2) * .5, spec)
        # chỉ quấn mảnh ở chân khâu
        th = band_mask(X, [f - 2.4 for f in ferr] + [f + 2.4 for f in ferr], .45)
        col = np.where(th[..., None], hexc('#e8d090') * (1 - .25 * ((X * 7) % 1 < .4))[..., None], col)
    else:  # mun
        base = hexc('#2e2622')
        grain = np.sin(Y * 5 + rng_noise(W, 23, SS * 30)[None, :] * 3) * .5 + .5
        col = base * (1 + (grain * .22 - .08)[..., None]) * (1 + fib[..., None] * .05)
        spec = np.exp(-((v + .45) / .2) ** 2) * .16
        # chỉ vàng quấn từng đoạn: mỗi đoạn 3 vòng mảnh
        gx = list(np.linspace(GRIP + 14, LEN - 30, 7))
        gold = hexc('#dcb24a')
        for g in gx:
            for o, w in ((-1.0, .28), (0, .55), (1.0, .28)):
                m = np.abs(X - g - o) < w
                col = np.where(m[..., None], gold * (1 - .2 * ((X * 9 + v * 2) % 1 < .35))[..., None], col)
                spec = np.where(m, np.exp(-((v + .4) / .3) ** 2) * .35, spec)
    # cán
    if cf['grip'] == 'gai':
        pitch, cc, gd = .9, hexc('#a06a3c'), .45
    elif cf['grip'] == 'may':
        pitch, cc, gd = 1.7, hexc('#d2a45e'), .5
    elif cf['grip'] == 'da':
        pitch, cc, gd = 0, hexc('#6e3e22'), 0
    else:
        pitch, cc, gd = .7, hexc('#2a1814'), .5
    wrap_s = wrap & (X > max(.8, capw))
    if pitch:
        ph = (X / pitch + np.arcsin(np.clip(v, -1, 1)) / np.pi * 1.4) % 1.0
        groove = np.clip(np.abs(ph - .5) * 2, 0, 1) ** 3
        gc = cc * (1 - .12 * np.sin(X * 1.3)[..., None]) * (1 - gd * groove[..., None])
        if cf['grip'] == 'may':      # mây: nan dẹt bóng nhẹ, mép nan sẫm
            gc = gc * (1 + .1 * np.cos(ph * np.pi * 2)[..., None])
    else:                            # da: mịn, nếp nhăn nhẹ, 2 đường chỉ khâu dọc
        wr = rng_noise(W, 31, SS * 4)[None, :] * rng_noise(H, 37, SS * 3)[:, None]
        gc = cc * (1 + wr[..., None] * .1)
        st = (np.abs(v - .05) < .07) & ((X * 1.4) % 1 < .55)
        gc = np.where(st[..., None], hexc('#e0c890'), gc)
    col = np.where(wrap_s[..., None], gc, col)
    bandc = {'gai': '#5a3a1e', 'may': '#7a4a22', 'da': '#c99a42', 'to': '#dcb24a'}[cf['grip']]
    band = (np.abs(X - GRIP + .6) < .55) | ((np.abs(X - max(1.4, capw + .6)) < .6))
    col = np.where(band[..., None], hexc(bandc) * (1 + .15 * np.sin(Y * 9))[..., None], col)
    if cf['grip'] in ('da', 'to'):
        spec = np.where(band, np.exp(-((v + .4) / .3) ** 2) * .4, spec)
    if capw:
        cm = X < capw
        col = np.where(cm[..., None], hexc('#c99a42'), col)
        spec = np.where(cm, np.exp(-((v + .4) / .25) ** 2) * .5, spec)
        col = np.where((np.abs(X - capw + .15) < .15)[..., None], hexc('#7a5a22'), col)
    else:
        col = np.where((X < 1.0)[..., None], col * .7, col)
    ring = (np.abs(X - (LEN - 2.2)) < .35)
    col = np.where(ring[..., None], hexc('#3a3a3a'), col)
    lightk = (.34 + .82 * dif) * (1 - .18 * np.clip(-v, 0, 1) ** 2)
    out = col * lightk[..., None] + spec[..., None] * 255 * .55
    rpx = rr * PX * SS
    ed = np.clip((np.abs(Y) * PX * SS - (rpx - 1.3 * SS)) / (1.0 * SS), 0, 1)
    out = out * (1 - ed[..., None] * .6)
    # khoen dẫn dây: chân quấn chỉ + vòng thép thò xuống dưới cần
    for g in gu:
        rg = R1 + (R0 - R1) * (1 - (g / LEN) ** .8)
        gr_ = .6 + rg * .1
        cy = rg + .35 + gr_
        ringm = np.abs(np.hypot(X - g, Y - cy) - gr_) < .2
        foot = (np.abs(X - g) < .9) & (np.abs(Y) < rg + .1)
        legs = (np.abs(X - g) < .16) & (Y > rg - .1) & (Y < cy - gr_ + .1)
        mc = hexc('#9aa0a4') * (.7 + .5 * np.clip(-(Y - cy) / gr_, 0, 1))[..., None]
        out = np.where(foot[..., None], (hexc('#e8d090') if body == 'mun' else hexc('#2a1a12')) * lightk[..., None], out)
        out = np.where((ringm | legs)[..., None], mc, out)
        a = np.maximum(a, (ringm | legs).astype(np.float32))
    im = finish(out, a, cf['name'])
    return dict(w=im.width, h=im.height, len=LEN, r0=R0, r1=R1, grip=GRIP)

# ============================================================ 4 ỐNG CƯỚC (nhìn thẳng)
REELS = [
    dict(name='ongcuoc0', R=8.0, mat='wood', c1='#9a6436', c2='#6e4222', holes=4, knob='#5a361a', hub='#c9a24a'),
    dict(name='ongcuoc1', R=8.4, mat='wood', c1='#6c4220', c2='#40240e', holes=4, knob='#2e1a0c', hub='#b08a3a'),
    dict(name='ongcuoc2', R=7.2, mat='metal', c1='#b4b8ba', c2='#7c8286', holes=6, knob='#3a2a22', hub='#c9a24a'),
    dict(name='ongcuoc3', R=9.6, mat='brass', c1='#d0a448', c2='#94702a', holes=5, knob='#33241a', hub='#e8dcc0'),
]
def reel(cf):
    R = cf['R']
    N = int((R + 1) * 2 * PX) * SS
    c = (np.arange(N) + .5) / SS / PX - (R + 1)
    X, Y = np.meshgrid(c, c)
    rad = np.hypot(X, Y); ang = np.arctan2(Y, X)
    a = np.clip((R - rad) * PX * SS * .5 + .5, 0, 1)
    nh = cf['holes']
    hole = np.zeros_like(rad)
    for k in range(nh):
        aa = ang - (k * 2 * np.pi / nh + np.pi / nh)
        aa = (aa + np.pi) % (2 * np.pi) - np.pi
        if cf['mat'] == 'brass':      # lỗ tròn
            hd = np.hypot(rad - R * .56, aa * rad) - R * .15
        else:
            hw_ = R * (.2 if nh == 4 else .13)
            hd = np.maximum(np.abs(rad - R * .56) - R * .16, np.abs(aa) * rad - hw_)
        hole = np.maximum(hole, np.clip(-hd * PX * SS * .5 + .5, 0, 1))
    a = a * (1 - hole)
    c1 = hexc(cf['c1']); c2 = hexc(cf['c2'])
    if cf['mat'] == 'wood':
        grain = np.sin(rad * 5.5 + np.sin(ang * 3) * .6) * .5 + .5
        col = c1 * (1 - grain[..., None] * .25) + c2 * (grain[..., None] * .25)
    else:                         # kim loại: vân xoay mảnh quanh tâm
        brush = np.sin(rad * 22) * .5 + .5
        col = c1 * (1 - .08 * brush[..., None])
    rim = np.clip((rad - R * .86) / (R * .14), 0, 1)
    sr = np.sin(rim * np.pi / 2 * .9)
    nzr = np.where(rad > R * .86, np.cos(rim * np.pi / 2 * .9), 1)
    nx = np.where(rad > R * .86, X / np.maximum(rad, 1e-3) * sr, 0)
    ny = np.where(rad > R * .86, Y / np.maximum(rad, 1e-3) * sr, 0)
    dif = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nzr * LIGHT[2], 0, 1)
    lk = .5 + .62 * dif
    inner = (rad < R * .84) & (rad > R * .8)
    lk = np.where(inner, lk * .72, lk)
    spec = np.zeros_like(rad)
    if cf['mat'] != 'wood':
        # ánh mờ chéo trên mặt kim loại
        spec = np.clip(np.cos((ang + 2.3) * 2), 0, 1) ** 6 * .25 * (rad < R * .84) + np.where(rad > R * .86, np.clip(-(nx + ny), 0, 1) * .35, 0)
    hr = R * .2
    hub = rad < hr
    hubc = hexc(cf['hub']) * (.8 + .4 * np.clip(-(X + Y) / hr * .7 + .3, 0, 1))[..., None]
    col = np.where(hub[..., None], hubc, col)
    col = np.where((np.abs(rad - hr) < .25)[..., None], c2 * .7, col)
    if cf['mat'] == 'brass':     # 5 đinh tán quanh trục
        for k in range(5):
            q = k * 2 * np.pi / 5
            m = np.hypot(X - np.cos(q) * R * .32, Y - np.sin(q) * R * .32) < .45
            col = np.where(m[..., None], c2 * 1.25, col)
    kx, ky, kr = R * .7, 0.0, R * .17
    kd = np.hypot(X - kx, Y - ky)
    knob = kd < kr
    kn = np.sqrt(np.clip(1 - (kd / kr) ** 2, 0, 1))
    kdif = np.clip(((X - kx) / kr * LIGHT[0] + (Y - ky) / kr * LIGHT[1] + kn * LIGHT[2]), 0, 1)
    kc = hexc(cf['knob'])
    if cf['mat'] == 'brass':      # núm sừng: vệt sáng hơn chạy dọc
        kc = kc * (1 + .5 * np.clip(np.sin((X - kx) * 3.0 + (Y - ky) * 1.2), 0, 1))[..., None]
    col = np.where(knob[..., None], kc * (.55 + .8 * kdif)[..., None], col)
    lk = np.where(knob, 1.0, lk)
    spec = np.where(knob, 0, spec)
    out = col * lk[..., None] + spec[..., None] * 255
    ksh = (np.hypot(X - kx - .5, Y - ky - .6) < kr) & ~knob
    out = np.where(ksh[..., None], out * .7, out)
    ed = np.clip((rad * PX * SS - (R * PX * SS - 1.3 * SS)) / SS, 0, 1)
    out = out * (1 - ed[..., None] * .45)
    hedge = (hole > .02) & (hole < .98)
    out = np.where(hedge[..., None], out * .6, out)
    im = finish(out, a, cf['name'])
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

meta = {'px': PX}
for cf in RODS:
    meta[cf['name']] = rod(cf)
for cf in REELS:
    meta[cf['name']] = reel(cf)
for nm, bands, bulb in FLOATS:
    meta[nm] = float_img(nm, bands, bulb)
json.dump(meta, open(os.path.join(OUT, 'can.json'), 'w'), indent=1)
print(meta)
