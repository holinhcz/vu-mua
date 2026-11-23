#!/usr/bin/env python3
# VẼ LẠI CÁ cho Câu cá (Link 11-23 "vẽ lại cá cho đẹp, dựa trên mẫu cá có sẵn, logic hơn").
# Giữ nguyên dáng từng loài của bản cũ (fish_cu.py: đường lưng/bụng, vây, màu, hoa văn) nhưng tô lại TỪNG ĐIỂM ẢNH:
#   - thân là khối tròn dẹt thật: dựng mặt cong từ đường lưng/bụng, tính pháp tuyến, sáng từ trên-trái (cùng hướng nắng
#     cần câu/phao), lưng tối dần -> bụng sáng (đổi màu mềm, không còn 3 dải màu cắt ngang + vệt sáng phẳng)
#   - vảy xếp chồng đúng chiều (vảy phía đầu đè lên vảy phía đuôi, mép tự do quay về đuôi), mỗi vảy hơi phồng, theo hàng
#     cong theo thân; mờ dần về lưng, bụng và đầu
#   - vây sau thân nằm trong bóng thân (tối sát gốc), vây trước trong mờ thấy thân phía sau
#   - mắt: hốc mắt, tròng, con ngươi, 1 đốm sáng mờ phía nắng (không bóng loáng)
#   - viền mảnh màu tối của chính chỗ đó (không viền đen đều)
# python3 ca_ve.py OUTDIR [id ...]
import sys, os, math
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fishkit as K
import fish_cu as F

OUT = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/ca'
IDS = sys.argv[2:]
os.makedirs(OUT, exist_ok=True)
SS = K.SS
RES = 2                       # ảnh to gấp 2 bản cũ (thẻ cá câu được hiện ~460 css px trên màn dpr 3)
LIGHT = np.array([-.45, .62, .64]); LIGHT /= np.linalg.norm(LIGHT)   # (x phải, y lên, z ra mặt)


def col3(h):
    c = K.hexc(h) if isinstance(h, str) else h
    return np.array(c[:3], np.float32)


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def layer(sp, fn, blur=0.0):
    """vẽ 1 hàm cairo (toạ độ cá) -> mảng RGBA float 0..1 ở lưới trong"""
    s, c = sp.surf()
    fn(c)
    im = sp.pil(s)
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur * SS * RES))
    return np.asarray(im).astype(np.float32) / 255


def over(dst_rgb, dst_a, src):
    a = src[..., 3:4]
    rgb = src[..., :3] * a + dst_rgb * (1 - a)
    return rgb, np.maximum(dst_a, src[..., 3])


def curve_fn(pts):
    pl = K.crsample(pts, 600, False)
    xs = np.array([p[0] for p in pl]); ys = np.array([p[1] for p in pl])
    o = np.argsort(xs)
    return xs[o], ys[o]


def eye_layer(X, Y, e, px):
    ex, ey, r = e[0], e[1], e[2] * 1.22
    iris = col3(e[3] if len(e) > 3 else '#c89a2a')
    dx, dy = X - ex, Y - ey
    d = np.hypot(dx, dy) / r
    rgb = np.zeros(X.shape + (3,), np.float32); a = np.zeros(X.shape, np.float32)
    aa = 1.5 / (px * r)        # mép mịn ~1.5 điểm ảnh trong
    # hốc mắt: quầng tối mềm lệch xuống dưới-phải (mắt lồi lên khỏi mặt)
    ds = np.hypot(dx - r * .1, dy + r * .12) / r
    sh = (1 - sstep(1.0, 1.38, ds)) * .8
    rgb += np.array([.08, .06, .04]) * sh[..., None]; a = np.maximum(a, sh)
    m = 1 - sstep(1 - aa, 1 + aa, d)
    # tròng ngoài (vàng nhạt) -> tròng màu (sáng dần về phía dưới, kiểu ánh sáng xuyên giác mạc)
    ring = col3('#efe4c2') * (.78 + .22 * np.clip(.5 + dy / r * .5, 0, 1))[..., None]
    t_ir = 1 - sstep(.74 - aa, .74 + aa, d)
    glow = np.clip(.55 - dy / r * .6, 0, 1)
    irc = iris[None, None, :] * (.62 + .5 * glow)[..., None]
    irc = irc * (1 - .35 * sstep(.45, .74, d))[..., None]
    c = ring * (1 - t_ir[..., None]) + irc * t_ir[..., None]
    # viền tối quanh mắt
    c = c * (1 - .55 * sstep(.86, 1.0, d))[..., None]
    # con ngươi hơi lệch về phía trước (mõm)
    dp = np.hypot(dx - r * .1, dy) / r
    t_p = 1 - sstep(.5 - aa, .5 + aa, dp)
    c = c * (1 - t_p[..., None]) + np.array([.07, .05, .035]) * t_p[..., None]
    # 1 đốm sáng mờ phía nắng + 1 chấm nhỏ đối diện
    h1 = np.exp(-(((dx + r * .26) ** 2 + (dy - r * .28) ** 2) / (2 * (r * .14) ** 2))) * .85
    h2 = np.exp(-(((dx - r * .3) ** 2 + (dy + r * .3) ** 2) / (2 * (r * .06) ** 2))) * .35
    c = c + (1 - c) * (h1 + h2)[..., None] * m[..., None]
    rgb = rgb * (1 - m[..., None]) + c * m[..., None]
    a = np.maximum(a, m)
    return np.dstack([rgb / np.maximum(a[..., None], 1e-4) * (a[..., None] > 0), a])


def scale_field(X, Q, sx, sy):
    """vảy chồng nhau: trả (d 0..1 trong vảy, ox, oy lệch tâm chuẩn hoá, id vảy)"""
    r = sx * .62
    j0 = np.floor(Q / sy).astype(int)
    best_cx = np.full(X.shape, -1e9); bd = np.ones(X.shape); box = np.zeros(X.shape); boy = np.zeros(X.shape)
    bid = np.zeros(X.shape)
    for dj in (-1, 0, 1, 2):
        j = j0 + dj
        off = (j % 2) * sx * .5
        i0 = np.floor((X - off) / sx).astype(int)
        for di in (-1, 0, 1, 2):
            i = i0 + di
            cx = i * sx + off; cy = j * sy
            ddx = (X - cx) / r; ddy = (Q - cy) / r
            dd = np.hypot(ddx, ddy)
            ok = (dd < 1) & (cx > best_cx)
            best_cx = np.where(ok, cx, best_cx); bd = np.where(ok, dd, bd)
            box = np.where(ok, ddx, box); boy = np.where(ok, ddy, boy); bid = np.where(ok, i * 7919 + j * 104729, bid)
    return bd, box, boy, bid


# chỉnh thêm theo loài (bản cũ không có): cá ánh bạc có lớp sáng mờ, cá thân tròn (lươn, chình, trê, lóc) dày hơn cá dẹt
EXTRA = {
    'linh': dict(sheen=.28), 'mevinh': dict(sheen=.25), 'he': dict(sheen=.22), 'ho': dict(sheen=.18),
    'tradau': dict(sheen=.25, thick=.7), 'thatlat': dict(sheen=.25, thick=.45),
    'luon': dict(thick=.9), 'chinh': dict(thick=.9), 'tre': dict(thick=.8), 'loc': dict(thick=.75),
    'locbong': dict(thick=.75), 'bong': dict(thick=.75), 'chot': dict(thick=.7),
}


def render(fid):
    spec = dict(F.FISH[fid]); spec.update(EXTRA.get(fid, {}))
    sp = K.Sprite(scale=spec.get('scale', .86), cx=spec.get('cx', .07), cy=spec.get('cy', .5), w=K.W * RES, h=K.H * RES)
    Hh, Ww = sp.h, sp.w
    px = sp.L                                   # điểm ảnh trong / 1 đơn vị cá
    cols = (np.arange(Ww) + .5); rows = (np.arange(Hh) + .5)
    X, Y = np.meshgrid((cols - sp.ox) / px, -(rows - sp.oy) / px)
    pts = K.body_pts(spec['top'], spec['bot'])
    Mb = np.asarray(sp.mask(lambda c: (K.crpath(c, pts, True), c.fill()))).astype(np.float32) / 255
    C = {k: col3(v) for k, v in spec['col'].items()}

    # ---- mặt cong của thân
    tx, ty = curve_fn(spec['top']); bx, by = curve_fn(spec['bot'])
    yt = np.interp(X, tx, ty); yb = np.interp(X, bx, by)
    cc = (yt + yb) * .5; hw = np.maximum((yt - yb) * .5, 1e-3)
    v = np.clip((Y - cc) / hw, -1, 1)
    thick = spec.get('thick', .55)
    Z = hw * thick * np.sqrt(np.clip(1 - v * v, 0, 1)) * (Mb > 0)
    Z = ndi.gaussian_filter(Z, 1.2 * RES)
    gy, gx = np.gradient(Z)
    nx = -gx * px; ny = gy * px                 # hàng ảnh đi xuống = y cá đi lên ngược
    # ---- vảy (bướu nhỏ trên mặt + mép tối)
    sc = spec.get('scales')
    vis_sc = np.zeros(X.shape, np.float32); rim = np.zeros(X.shape, np.float32); tint = np.zeros(X.shape, np.float32)
    if sc:
        sx, sy, x0, x1 = sc[:4]
        sca = sc[4] if len(sc) > 4 else .22
        hmid = float(np.interp(.55, tx, ty) - np.interp(.55, bx, by)) * .5
        Q = v * hmid                              # hàng vảy chạy cong theo thân, chụm lại về đuôi
        d, ox, oy, sid = scale_field(X, Q, sx, sy)
        t = (1 - v) * .5                          # 0 lưng .. 1 bụng
        hx = spec.get('headx', .8)
        fade = sstep(0.0, .16, t) * (1 - sstep(.72, .95, t)) * (1 - sstep(hx - .07, hx, X)) * sstep(x0 - .02, x0 + .05, X)
        vis_sc = fade * Mb
        bump = np.sqrt(np.clip(1 - d * d, 0, 1))
        k = .4 * vis_sc
        nx = nx + ox * k * .9; ny = ny - oy * k * .9
        nz_extra = bump
        free = (ox < .15).astype(np.float32)                # mép tự do (phía đuôi) mới lộ ra
        rim = sstep(.8, .97, d) * free * vis_sc * (sca / .22)
        rnd = np.sin(sid * 12.9898) * 43758.5453
        tint = (rnd - np.floor(rnd) - .5) * .08 * vis_sc
    n = np.dstack([nx, ny, np.ones(X.shape)])
    n /= np.linalg.norm(n, axis=-1, keepdims=True)

    # ---- màu nền: lưng -> hông -> bụng chuyển mềm theo mặt cong (cá nào cũng lưng sẫm bụng nhạt)
    t = (1 - v) * .5
    m1 = spec.get('mid', .42) * .7 + .03; m2 = spec.get('bel', .78) * .9 + .02
    w1 = sstep(m1 - .1, m1 + .1, t)[..., None]; w2 = sstep(m2 - .09, m2 + .09, t)[..., None]
    base = C['back'] * (1 - w1) + C['flank'] * w1
    base = base * (1 - w2) + C['belly'] * w2
    rgb = base.copy(); a = Mb.copy()
    # hoa văn cũ (đốm, sọc...) vẽ lên da, sau đó mới tô sáng tối -> hoa văn cũng tròn theo thân
    for key, bl in (('soft', min(.5, spec.get('softblur', 3) * .2)), ('pattern', spec.get('patblur', .6))):
        if spec.get(key):
            L = layer(sp, spec[key], bl)
            L[..., 3] *= Mb
            rgb, _ = over(rgb, a, L)
    rgb = rgb * (1 + tint[..., None])
    # ---- tô sáng tối (mờ, không bóng loáng)
    dif = np.clip((n * LIGHT).sum(-1), 0, 1)
    sky = np.clip(n[..., 1] * .5 + .5, 0, 1)
    ao = 1 - .16 * sstep(.6, 1.0, -v) - .1 * sstep(.8, 1.0, v)        # bụng quay xuống nước + mép lưng
    tailk = (1 - .18 * (1 - sstep(.18, .42, X))) * (.72 + .28 * sstep(float(tx.min()), float(tx.min()) + .1, X))   # cuống đuôi xoay vào trong, tối dần sát vây đuôi
    lit = (.52 + .62 * dif + .1 * sky + .22 * w2[..., 0]) * ao * tailk
    rgb = rgb * lit[..., None]
    gr = rgb.mean(-1, keepdims=True); rgb = gr + (rgb - gr) * 1.15      # đậm màu lại 1 chút sau khi tô bóng
    # mép vảy tối mảnh + ánh nhẹ ngay trong mép
    rgb = rgb * (1 - .32 * rim[..., None])
    # cá ánh bạc: lớp sáng mờ rộng theo hông (không phải vệt bóng)
    sh = spec.get('sheen', 0)
    if sh:
        sp_ = np.clip((n * (LIGHT + np.array([0, 0, 1])) / np.linalg.norm(LIGHT + np.array([0, 0, 1]))).sum(-1), 0, 1) ** 6
        rgb = rgb + (1 - rgb) * (sp_ * sh * Mb)[..., None]
    # đường bên (cá có vảy)
    if sc:
        ll = np.exp(-((v - spec.get('lat', .28)) * hw * px / (1.1 * RES * SS)) ** 2) * sstep(.25, .35, X) * (1 - sstep(spec.get('headx', .8) - .06, spec.get('headx', .8), X)) * Mb
        rgb = rgb * (1 - .22 * ll[..., None])
    # nắp mang + miệng (nét cũ) vẽ đè, mờ nhẹ
    if spec.get('head'):
        L = layer(sp, spec['head'], .35)
        L[..., 3] *= np.clip(Mb * 1.5, 0, 1)
        rgb, a = over(rgb, a, L)
    # cuống đuôi tan dần vào vây đuôi (không còn đầu thân tròn như khúc xúc xích)
    xe = float(tx.min())
    a = a * sstep(xe - .005, xe + .05, X)
    body_rgb, body_a = rgb, a

    # ---- vây: sau thân (trong bóng, tối sát gốc) và trước thân (trong mờ)
    dist_out = ndi.distance_transform_edt(Mb < .5) / px          # khoảng cách tới thân (đơn vị cá)
    def fins(lay):
        out = np.zeros((Hh, Ww, 4), np.float32)
        for fs in spec.get('fins', []):
            if fs.get('layer', 'back') != lay:
                continue
            one = dict(spec); one['fins'] = [fs]
            def fdraw(c, fs=fs):
                col = K.hexc(fs.get('col', spec['col']['fin']), fs.get('a', .92))
                edge = K.hexc(fs.get('edge', spec['col'].get('finedge', '#3a2a14')), fs.get('ea', .55))
                fade = K.hexc(fs['fade'], fs.get('fa', .75)) if fs.get('fade') else None   # mép vây trong, nhạt hơn bản cũ
                K.fin(c, fs['b0'], fs['b1'], fs['o'], col, edge, fs.get('rays', 0),
                      K.hexc(fs.get('raycol', spec['col'].get('ray', '#3a2a14')), fs.get('ra', .35)),
                      fs.get('spiny', 0), fs.get('rw', .0028) * .8, fs.get('ew', .003) * .7, fade)
            Lf = layer(sp, fdraw, .25)
            if lay == 'back':
                # màng vây: sát gốc tối (bóng thân), ra mép sáng + trong hơn
                g = sstep(0, .06, dist_out)
                Lf[..., :3] *= (.9 + .2 * g)[..., None]
                Lf[..., 3] = np.clip(Lf[..., 3] * (1.3 - .12 * g), 0, 1)
            else:
                Lf[..., :3] = Lf[..., :3] * 1.02 + .06
                Lf[..., 3] = np.clip(Lf[..., 3] * 1.05, 0, 1)
            rr, aa = over(out[..., :3], out[..., 3], Lf)
            out = np.dstack([rr, aa])
        return out
    back = fins('back')
    # ghép: vây sau -> thân -> vây trước -> râu/đồ thêm -> mắt
    rgb = back[..., :3] * back[..., 3:4]; a = back[..., 3].copy()
    rgb = body_rgb * body_a[..., None] + rgb * (1 - body_a[..., None]); a = np.maximum(a, body_a)
    rgb = rgb / np.maximum(a[..., None], 1e-4)
    # bóng thân đổ nhẹ lên vây sau (cách mép thân 1 chút phía dưới)
    rgb, a = over(rgb, a, fins('front'))
    if spec.get('front'):
        rgb, a = over(rgb, a, layer(sp, spec['front'], .3))
    rgb, a = over(rgb, a, eye_layer(X, Y, spec['eye'], px))
    # ---- viền mảnh: màu tối của chính chỗ đó
    am = (a > .15).astype(np.float32)
    k = int(round(1.6 * RES * SS))
    dil = ndi.grey_dilation(am, size=(2 * k + 1, 2 * k + 1))
    dil = ndi.gaussian_filter(dil, .6 * SS * RES)
    src = ndi.gaussian_filter(rgb * am[..., None], (3 * SS, 3 * SS, 0)) / np.maximum(ndi.gaussian_filter(am, 3 * SS)[..., None], 1e-3)
    oc = np.clip(src * .32, 0, 1) * .8 + col3(spec.get('outline', '#24170b')) * .2
    fa = dil * (1 - ndi.gaussian_filter(am, .2 * SS * RES))     # viền chỉ ở NGOÀI hình, không lấp vào chỗ vây trong
    out_rgb = rgb * a[..., None] + oc * (fa * (1 - a))[..., None]
    out_a = a + fa * (1 - a)
    out_rgb = out_rgb / np.maximum(out_a[..., None], 1e-4)
    im = Image.fromarray(np.dstack([np.clip(out_rgb * 255, 0, 255), np.clip(out_a * 255, 0, 255)]).astype(np.uint8), 'RGBA')
    if spec.get('bend'):
        im = K.bend_warp(im, *spec['bend'])
    im = im.resize((Ww // SS, Hh // SS), Image.LANCZOS)
    bb = im.getchannel('A').point(lambda q: 255 if q > 6 else 0).getbbox()
    p = 3 * RES
    im = im.crop((max(0, bb[0] - p), max(0, bb[1] - p), min(im.width, bb[2] + p), min(im.height, bb[3] + p)))
    return im


if __name__ == '__main__':
    ids = IDS or list(F.FISH)
    for fid in ids:
        im = render(fid)
        im.save(os.path.join(OUT, fid + '.webp'), lossless=True, quality=100, method=6)
        im.save(os.path.join(OUT, fid + '.png'))
        print('ok', fid, im.size)
