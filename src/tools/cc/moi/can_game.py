#!/usr/bin/env python3
# Cần câu + ống cước TRONG GAME lúc quăng câu (thay ui/img/cc/can/can0-3 + ongcuoc0-3), dựng 3D cùng kiểu icon do3d.rod:
#   can<i>: dải ngang 1440 px (6 px/đv, dài 240 đv), cán bên trái x=0, ngọn bên phải, trục cần giữa ảnh (game dán dọc đường cong)
#   ongcuoc<i>: ống cước nhìn chính diện, ảnh vuông, tâm giữa ảnh (game xoay), bán kính r đv như can.json cũ
#   EL=0 PXU=6 SSA=2 python3 can_game.py OUTDIR      -> can0-3.webp ongcuoc0-3.webp can.json (cùng khoá bản cũ)
import os, sys, json, math
os.environ.setdefault('EL', '0')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import do3d as D
from do3d import V, nz, hexc, Tube, Torus, Line, Ball, M, Scene, met, GOLD
import numpy as np
from PIL import Image

B = D.B; RT = D.RT; Z = D.Z; HF = D.HF
LEN = 240.0
SPEC = {1: dict(r0=3.6, r1=1.0, grip=30.0, h=68), 2: dict(r0=3.9, r1=1.1, grip=30.0, h=72),
        3: dict(r0=4.1, r1=1.05, grip=30.0, h=74), 4: dict(r0=4.4, r1=1.15, grip=34.0, h=78)}
REEL = {1: dict(r=8.0, w=108), 2: dict(r=8.4, w=112), 3: dict(r=7.2, w=98), 4: dict(r=9.6, w=127)}


def strip(t):
    sp = SPEC[t]; r0, r1, G = sp['r0'], sp['r1'], sp['grip']
    o = []
    p = lambda s, off=0.0: RT * s + Z * off
    S0 = G - 1.0
    ss = np.linspace(S0, LEN, 13)
    rad = lambda s: r0 * .78 - (r0 * .78 - r1) * ((s - S0) / (LEN - S0)) ** .9
    LL = LEN - S0
    tt = lambda s: (s - S0) / LL
    if t == 1:
        col, nodes = '#dcc480', 26.0
        bands = [(tt(S0 + nodes * (k + .5)) - .0015, tt(S0 + nodes * (k + .5)) + .0015, '#a88a4a') for k in range(8)] + [(.992, 1, '#4a3420')]
    elif t == 2:
        col, nodes = '#a86a3a', 23.0
        bands = [(tt(S0 + nodes * (k + .5)) - .003, tt(S0 + nodes * (k + .5)) + .003, '#4e2c16') for k in range(9)] + [(.992, 1, '#2e1e14')]
    elif t == 3:
        col, nodes = '#c03a2a', None
        bands = [(.992, 1, '#2a1a16')]
    else:
        col, nodes = '#30241f', None
        bands = [(.992, 1, '#d8a838')]
    guides = {1: [], 2: [], 3: [.18, .36, .54, .72, .88], 4: [.14, .29, .44, .59, .74, .88]}[t]
    for g in guides:
        if t == 3:
            bands.append((g - .004, g + .004, '#2a1a16'))
        else:
            bands += [(g - .008, g - .004, '#e0b040'), (g + .004, g + .008, '#e0b040')]
    if t == 4:   # chỉ vàng quấn từng đoạn giữa khoen
        for g in np.linspace(.07, .95, 12):
            bands.append((g - .0015, g + .0015, '#e0b040'))
    b = M(Line([tuple(p(s)) for s in ss], [rad(s) for s in ss], 'band', nodes=nodes), col=col, sp=.25 if t < 3 else .4, pw=40)
    b.bands = bands
    o.append(b)
    gc = hexc('#c4ccd2') if t == 3 else hexc('#d8a838')
    for g in guides:
        s = S0 + g * LL; rg = 1.25 - .45 * g
        c = p(s, -(rad(s) + .6 + rg))
        o.append(met(Line([tuple(p(s, -rad(s) * .6)), tuple(c + Z * rg)], .28, 'met'), gc, sp=.5, pw=50))
        o.append(met(Torus(tuple(c), tuple(HF), rg, .26, 'met'), gc, sp=.5, pw=50))
    for g in {1: [], 2: [], 3: [.27, .63], 4: [.37, .67]}[t]:
        s = S0 + g * LL
        o.append(met(Tube(tuple(p(s - 2.2)), tuple(RT), 4.4, [(0, rad(s) + .35), (1, rad(s) + .28)], 'met'), hexc('#d8a838'), sp=.5, pw=40))
    gcol, gmat, gk = {1: ('#6e4a2a', 'cuon', .9), 2: ('#d8b070', 'cuon', .45), 3: ('#6e3420', 'met', 0), 4: ('#2e2220', 'cuon', .9)}[t]
    g0 = 1.6 if t > 2 else .8
    gr = M(Tube(tuple(p(g0)), tuple(RT), G - g0, [(0, r0 * .96), (.5, r0), (1, r0 * .86)], gmat), col=hexc(gcol), sp=.15, pw=20)
    if gk:
        gr.k = gk
    else:
        gr.ns = .6
    o.append(gr)
    if t == 3:   # cán da: chỉ khâu
        st = M(Line([tuple(p(s, r0 * .97)) for s in np.linspace(g0 + 1.5, G - 1.5, 2)], .22, 'band'), col='#6e3420')
        st.bands = [(k / 30, (k + .55) / 30, '#f0e6cc') for k in range(30)]
        o.append(st)
    if t == 4:
        for s in (5.0, 6.4, G - 5.5, G - 4.1):
            o.append(met(Torus(tuple(p(s)), tuple(RT), r0 * 1.0, .3, 'met'), GOLD, sp=.5, pw=40))
    if t < 3:
        o.append(M(Ball(tuple(p(r0 * .9)), r0 * 1.05, 'gox', sq=(1, 1, 1)), col=hexc('#7a4e2c' if t == 1 else '#5a3820')))
    else:
        o.append(met(Tube(tuple(p(0)), tuple(RT), 3.2, [(0, r0 * 1.02), (.3, r0 * 1.08), (1, r0 * 1.06)], 'met'), hexc('#d8a838'), sp=.5, pw=40))
    for s in ((G,) if t < 3 else (3.2, G)):
        o.append(met(Torus(tuple(p(s)), tuple(RT), r0 * .9, .35, 'met'), hexc('#d8a838') if t > 2 else hexc('#3a2618'), sp=.4, pw=40))
    return Scene(o)


def reel(t):
    R = REEL[t]['r']; o = []
    C = V(0, 0, 0)
    rc_ = {1: '#b0743e', 2: '#6e4426', 3: '#c8d0d6', 4: '#d8a838'}[t]
    th = 1.6
    if t < 3:
        o.append(M(Tube(tuple(C - HF * th / 2), tuple(HF), th, [(0, R), (1, R)], 'gox'), col=hexc(rc_)))
        o.append(M(Torus(tuple(C + HF * th / 2), tuple(HF), R - .55, .5, 'gox'), col=hexc(rc_) * .8))
    else:
        o.append(met(Tube(tuple(C - HF * th / 2), tuple(HF), th, [(0, R), (1, R)], 'met'), hexc(rc_), sp=.45, pw=40))
        o.append(met(Torus(tuple(C + HF * th / 2), tuple(HF), R - .55, .5, 'met'), hexc(rc_) * .85, sp=.45, pw=40))
    nh = {1: 4, 2: 4, 3: 6, 4: 5}[t]; hr = {1: .21, 2: .21, 3: .14, 4: .17}[t] * R
    for k in range(nh):
        a = k / nh * 2 * math.pi + .4
        hc = C + HF * (th / 2 + .02) + (RT * math.cos(a) + Z * math.sin(a)) * R * .55
        o.append(M(Tube(tuple(hc - HF * .05), tuple(HF), .1, [(0, hr), (1, hr)], 'met'), col=hexc('#3a2a1e'), sp=0, pw=10))
    o.append(met(Tube(tuple(C + HF * th / 2), tuple(HF), .9, [(0, R * .24), (1, R * .2)], 'met'), hexc('#e0b448' if t != 3 else '#e8c060'), sp=.5, pw=40))
    if t == 3:   # bạc: vân tiện tròn
        for rr in (R * .35, R * .8):
            o.append(met(Torus(tuple(C + HF * th / 2), tuple(HF), rr, .12, 'met'), hexc('#a8b0b8'), sp=.4, pw=40))
    kc = C + HF * th / 2 + (RT * math.cos(-.5) + Z * math.sin(-.5)) * R * .8
    o.append(M(Line([tuple(kc), tuple(kc + HF * 1.6)], .45, 'met'), col=hexc('#3a2a1e')))
    o.append(M(Ball(tuple(kc + HF * 2.1), 1.25, 'gox'), col=hexc('#4a2e1c' if t < 4 else '#2a1e16')))
    return Scene(o)


def cut_holes(im, t, px):
    """lỗ ống cước thủng thật (nhìn xuyên qua), mép lỗ sẫm"""
    a = np.array(im).astype(np.float32)
    R = REEL[t]['r']; nh = {1: 4, 2: 4, 3: 6, 4: 5}[t]; hr = {1: .21, 2: .21, 3: .14, 4: .17}[t] * R * px
    h, w = a.shape[:2]; yy, xx = np.mgrid[0:h, 0:w] + .5
    for k in range(nh):
        ang = k / nh * 2 * math.pi + .4
        cx = w / 2 + math.cos(ang) * R * .55 * px; cy = h / 2 - math.sin(ang) * R * .55 * px
        d = np.hypot(xx - cx, yy - cy)
        a[..., 3] *= np.clip(d - hr, 0, 1)
        rim = (d >= hr) & (d < hr + 1.8)
        a[rim, :3] *= .55
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def place(im, anc, W, H, ox, oy):
    """dán ảnh render lên khung W x H sao cho gốc toạ độ (0,0,0) nằm ở (ox, oy)"""
    cv = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cv.alpha_composite(im.convert('RGBA'), (int(round(ox - anc[0])), int(round(oy - anc[1]))))
    return cv


if __name__ == '__main__':
    OUT = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    px = B.PXU
    meta = {"px": px}
    for t in (int(a) for a in (sys.argv[2:] or '1234')):
        sp = SPEC[t]
        outs, anc = B.render(strip(t), 'can%d' % t, water=False)
        W = int(LEN * px); H = sp['h']
        place(outs[0], anc, W, H, 0, H / 2).save(os.path.join(OUT, 'can%d.webp' % (t - 1)), lossless=True, quality=100, method=6)
        meta['can%d' % (t - 1)] = {"w": W, "h": H, "len": LEN, "r0": sp['r0'], "r1": sp['r1'], "grip": sp['grip']}
        rl = REEL[t]
        outs, anc = B.render(reel(t), 'ongcuoc%d' % t, water=False)
        cut_holes(place(outs[0], anc, rl['w'], rl['w'], rl['w'] / 2, rl['w'] / 2), t, px).save(os.path.join(OUT, 'ongcuoc%d.webp' % (t - 1)), lossless=True, quality=100, method=6)
        meta['ongcuoc%d' % (t - 1)] = {"w": rl['w'], "h": rl['w'], "r": rl['r']}
        print(t, flush=True)
    json.dump(meta, open(os.path.join(OUT, 'can_rod.json'), 'w'), indent=1)
