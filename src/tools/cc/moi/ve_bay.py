#!/usr/bin/env python3
# LỜ / LỌP / GIĂNG CÂU CẤP 1 (11-24 Link "vẽ giăng - lờ - lợp cấp 1 đi, tự vẽ đi vườn chưa có"): đồ bắt cá đặt dưới nước
# trong vườn, cùng kiểu vẽ với cá câu (tô từng điểm ảnh, sáng trên-trái, viền mảnh màu tối của chỗ đó). Cấp 1 = đồ tre mộc.
#   lờ   : ống tre đan bụng phình nằm ngang, miệng có hom (phễu nan chĩa vô), đuôi túm buộc mây, 2 cọc tre giữ
#   lọp  : ống lọp lươn đan mảnh, cắm xiên: miệng hom dưới nước, đầu trên nhú khỏi nước bịt nùi bẹ chuối, buộc cọc nhỏ
#   giăng: 2 cọc tre có đốt, dây giăng chùng giữa, 4 thẻo dây thòng xuống, phao khúc trúc đầu sơn đỏ
# Mỗi món ra 2 ảnh: <id>.webp (nguyên món, cho ô / bảng) và <id>_w.webp (đặt trên nước: phần chìm mờ + ngả màu nước).
#   python3 ve_bay.py OUTDIR [lo lop giang]
import os, sys, math
os.environ.setdefault('MOI_SC', '2')
OUTDIR = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/bay'
BIDS = sys.argv[2:] or ['lo', 'lop', 'giang']
sys.argv = [sys.argv[0], OUTDIR]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from moi_ve import *          # noqa
import numpy as np
from scipy import ndimage as ndi

TRE = hexc('#cfae72'); TRE_D = hexc('#8f6c3c'); TRE_L = hexc('#ead2a0')     # nan tre phơi khô
MAY = hexc('#7a5230'); MAY_D = hexc('#4e321c')                                # dây mây buộc
COC = hexc('#b8a45c'); COC_D = hexc('#7d6c32')                                # cọc tre già
TOI = hexc('#3a2a18')                                                         # lòng ống tối
WATER = hexc('#5f8f8a')


def arclen(pts):
    d = np.hypot(*np.diff(np.array(pts), axis=0).T)
    return np.concatenate([[0], np.cumsum(d)])


def axis_coords(A, ax, pts, rad):
    """ống trục thẳng: s (dọc trục) + sd (lệch ngang / bán kính) tính thẳng từ trục, khỏi nhảy giữa các đoạn của tube
    (bán kính đổi nhiều thì tube chọn đoạn theo khoảng cách mặt ống -> s nhảy, đai mây bị đứt khúc)"""
    cum = arclen(pts)
    sp = (X - A[0]) * ax[0] + (Y - A[1]) * ax[1]
    s = np.clip(sp, 0, cum[-1])
    r = np.interp(s, cum, rad)
    cr = (X - A[0]) * ax[1] - (Y - A[1]) * ax[0]
    return s, np.clip(cr / np.maximum(r, 1e-3), -1, 1)


def smooth_prof(A, B, prof, n=40):
    """trục thẳng A->B, bán kính nội suy mượt (khỏi gãy khúc ở chỗ nối các đoạn)"""
    ts = np.linspace(0, 1, n); tk = [t for t, _ in prof]; rk = [r for _, r in prof]
    from scipy.interpolate import PchipInterpolator
    r = PchipInterpolator(tk, rk)(ts)
    return [tuple(A + (B - A) * t) for t in ts], list(r)


def cut(m, A, ax):
    """bỏ phần ống thò ra trước mặt phẳng miệng (đầu tròn của tube): thân dừng đúng ở vành miệng"""
    return m * np.clip(((X - A[0]) * ax[0] + (Y - A[1]) * ax[1]) * PX + .5, 0, 1)


def weave(s, sd, m, nslat, ring_step, ring_w=4.0, gap=.14, seed=0, ring0=0.0, ring_end=None, persp=None):
    """vân đan trên 1 ống (từ tube): nan dọc theo góc quanh ống + đai mây ngang.
    trả (h thêm, màu, mặt nạ khe)"""
    th = np.arcsin(np.clip(sd, -1, 1))                 # góc quanh ống: nan dồn khít ở 2 mép như thật
    u = (th / math.pi + .5) * nslat
    k = np.floor(u); f = u - k
    q = np.clip((f - .5) / (.5 - gap), -1, 1)
    slat = np.sqrt(np.clip(1 - q * q, 0, 1))           # mỗi nan bo tròn
    gapm = sstep(.75, 1.0, np.abs(q)) * m              # khe giữa 2 nan
    rs = np.random.RandomState(seed)
    tone = rs.uniform(-.09, .09, 512)[(k.astype(int) % 512)]   # mỗi nan đậm nhạt khác
    col = TRE * (1 + tone + .06 * noise(1.2, seed + 1))[..., None]
    col = lerpc(col, TRE_D, sstep(.3, .9, noise(5, seed + 2, 2)) * .35)
    col = lerpc(col, TRE_L, sstep(.55, .9, slat) * .25)
    # sợi dọc nan (xơ tre)
    col = col * (1 - .06 * np.sin(u * 37 + noise(.6, seed + 3) * 3))[..., None]
    h = slat * 2.2
    # đai mây ngang
    if persp is not None:
        # (11-24 Link "đầu tròn xoay éo ăn khớp"): nhìn xiên vô miệng (vành = elip tỉ lệ k) thì mỗi đai tròn quanh ống
        # cũng hiện thành cung elip cùng tỉ lệ: giữa ống (mặt gần) lồi về phía miệng, 2 mép lùi lại
        k, cum, rad = persp
        rl = np.interp(s, cum, rad)
        s = s + k * rl * np.sqrt(np.clip(1 - sd * sd, 0, 1))
    sr = (s - ring0) / ring_step
    d = (sr - np.round(sr)) * ring_step
    ring = np.exp(-(d / (ring_w * .55)) ** 4) * m
    if ring_end is not None:
        ring = ring * (s < ring_end)
    rcol = MAY * (1 + .1 * np.sin(s * 2.4 + th * 9))[..., None]        # mây quấn xoắn
    col = lerpc(col, rcol, ring)
    h = h * (1 - ring) + ring * (3.4 + .6 * np.sin(s * 2.4 + th * 9))
    gapm = gapm * (1 - ring)
    col = lerpc(col, TOI, gapm * .7)
    h = h - gapm * 1.5
    return h, col, gapm


def bamboo(P, x0, y0, x1, y1, r, seed, node=70.0, contact=.3, col=COC):
    """cọc tre: ống thẳng có đốt, đầu trên vạt xéo"""
    m, h, s, sd = tube([(x0, y0), (x1, y1)], [r, r * .94])
    L = math.hypot(x1 - x0, y1 - y0)
    nd = (s / node) - np.round(s / node)
    ndm = np.exp(-(nd * node / 2.2) ** 2) * (s > 8) * (s < L - 8)
    h = h + ndm * 1.6
    b = col * (1 + .07 * noise(1.5, seed))[..., None]
    b = lerpc(b, COC_D, sstep(.4, .9, noise(6, seed + 1, 2)) * .3)
    b = b * (1 - .05 * np.sin(sd * 40 + noise(.5, seed + 2) * 4))[..., None]      # sớ dọc
    b = lerpc(b, COC_D * .8, ndm * .55)
    c, _ = P.shade(h, b, amb=.45, dif=.7, spec=.12, sp_pow=26)
    P.put(m, c, contact=contact)
    # mặt vạt đầu cọc
    ang = math.atan2(y1 - y0, x1 - x0)
    tm, th_ = ellipse(x0, y0, r * .95, r * .42, ang + math.pi / 2)
    cc_, _ = P.shade(th_ * .2, hexc('#e2cf98'), amb=.7, dif=.3)
    P.put(tm, cc_, line=.5, contact=0)
    return m


def rope_band(P, cx, cy, w, hgt, rot, seed):
    """mấy vòng dây buộc quanh cọc / ống"""
    for i in range(3):
        o = (i - 1) * hgt * .36
        ox, oy = -math.sin(rot) * o, math.cos(rot) * o
        m, h = ellipse(cx + ox, cy + oy, w, hgt * .22, rot)
        c, _ = P.shade(h, MAY * (1.05 - .08 * i), amb=.45, dif=.7, spec=.08)
        P.put(m, c, line=.6, lw=1, contact=.2)


def save2(P, name, wl, anchor):
    """lưu bản nguyên + bản đặt trên nước <name>_w (wl: độ chìm 0..1 từng điểm). anchor = chỗ đặt chân (khung 512,
    giữa món ngay mặt nước) -> meta.json: toạ độ anchor tính bằng điểm ảnh của ảnh ra (bake_bay.py dùng)"""
    import json
    ys, xs = np.nonzero(P.a > .01)
    left = xs.min() / PX - 2.0 - 6; top = ys.min() / PX - 2.0 - 6      # như P.save: viền ow 2 + lề 6
    mp = os.path.join(OUTDIR, 'meta.json')
    meta = json.load(open(mp)) if os.path.exists(mp) else {}
    meta[name] = {"ax": round((anchor[0] - max(0, left)) * SC, 1), "ay": round((anchor[1] - max(0, top)) * SC, 1)}
    json.dump(meta, open(mp, 'w'), indent=1)
    im = P.save(name, ow=2.0)
    os.replace(os.path.join(OUTDIR, 'ic-%s.webp' % name), os.path.join(OUTDIR, name + '.webp'))
    sub = np.clip(wl, 0, 1)
    rgb0, a0 = P.rgb.copy(), P.a.copy()
    wcol = WATER * (.8 + .2 * noise(3, 99))[..., None]
    P.rgb = lerpc(P.rgb, wcol, sub * .55)
    P.a = P.a * (1 - .55 * sub)
    P.edge = lerpc(P.edge, wcol * .6, sub)
    # vệt sáng mặt nước sát chỗ cắt
    line = sstep(0, .08, wl) * (1 - sstep(.12, .4, wl)) * (a0 > .5)
    P.rgb = lerpc(P.rgb, hexc('#e8f2ee'), line * .5)
    im2 = P.save(name + '_w', ow=2.0)
    os.replace(os.path.join(OUTDIR, 'ic-%s_w.webp' % name), os.path.join(OUTDIR, name + '_w.webp'))
    P.rgb, P.a = rgb0, a0
    return im, im2


# ============================================================ LỜ TRE
def lo():
    P = Pic()
    A = np.array([92., 262.]); B = np.array([420., 300.])
    ax = (B - A) / np.linalg.norm(B - A); nrm = np.array([-ax[1], ax[0]])
    prof = [(0, 78), (.08, 82), (.3, 92), (.55, 84), (.78, 56), (.92, 30), (1, 24)]
    pts, rad = smooth_prof(A, B, prof)
    # cọc sau (khuất sau lờ)
    bamboo(P, 176, 112, 172, 420, 9.5, 3, contact=0)
    # thân lờ (cắt phẳng ở miệng cho khớp vành)
    m, h, s, sd = tube(pts, rad)
    m = cut(m, A, ax)
    s, sd = axis_coords(A, ax, pts, rad)
    hw, col, gm = weave(s, sd, m, 22, 40, 4.5, gap=.1, seed=5, ring0=12 + .42 * rad[0], persp=(.42, arclen(pts), rad))
    hh = h + hw
    c, _ = P.shade(hh, np.ones(3, np.float32), amb=.4, dif=.75, spec=.08, sp_pow=20)
    c = c * col
    # lòng ống thấy qua khe: phía dưới tối hơn
    c = c * (1 - .25 * sstep(-.2, 1, sd) * gm)[..., None]
    P.put(m, np.clip(c, 0, 1), edge=TRE_D * .45, line=.5, contact=.3)
    # đuôi túm: bó nan buộc mây + núm
    L = np.linalg.norm(B - A)
    tail = B + ax * 14
    mt, ht, st, sdt = tube([tuple(B - ax * 6), tuple(tail)], [24, 14])
    hw2, col2, _ = weave(st, sdt, mt, 10, 5, 3.5, seed=8)
    ct, _ = P.shade(ht + hw2 * .5, np.ones(3, np.float32), amb=.42, dif=.72)
    P.put(mt, np.clip(ct * lerpc(col2, MAY, .55 * mt), 0, 1), contact=.2)
    mk, hk = ellipse(*(tail + ax * 6), 10, 9)
    ck, _ = P.shade(hk, MAY * 1.1, amb=.45, dif=.7, spec=.1)
    P.put(mk, ck, contact=.2)
    # miệng lờ: vành tròn nhìn xiên + hom phễu nan chĩa vô
    ang = math.atan2(ax[1], ax[0]) + math.pi / 2
    R = rad[0]          # vành = đúng cỡ thân ở miệng, tâm ngay mặt cắt
    mo, ho = ellipse(*A, R, R * .42, ang)
    u = (X - A[0]) * math.cos(ang) + (Y - A[1]) * math.sin(ang)
    v = -(X - A[0]) * math.sin(ang) + (Y - A[1]) * math.cos(ang)
    rr = np.sqrt((u / R) ** 2 + (v / (R * .42)) ** 2)
    an = np.arctan2(v / .42, u)
    inner = lerpc(TOI * 1.4, TOI * .45, sstep(.0, .9, 1 - rr))
    # nan hom: tia từ vành vô tâm (tâm lệch vô trong ống)
    spoke = .5 + .5 * np.cos(an * 18)
    hom = sstep(.55, .9, spoke) * sstep(.12, .45, rr)
    hcol = lerpc(TRE_D * .8, TRE, sstep(.2, 1, rr))
    inner = lerpc(inner, hcol, hom * .9)
    hole, _ = ellipse(*(A + ax * 6), 13, 7, ang)
    inner = lerpc(inner, hexc('#120c06'), hole)
    ci, _ = P.shade(-ho * .3 + hom * 1.2, np.ones(3, np.float32), amb=.6, dif=.45)
    P.put(mo, np.clip(ci * inner, 0, 1), edge=MAY_D, line=0, contact=.15)
    # vành miệng: ống mây tròn
    ring = []
    for i in range(49):
        t = i / 48 * 2 * math.pi
        x = math.cos(t) * R; y = math.sin(t) * R * .42
        ring.append((A[0] + x * math.cos(ang) - y * math.sin(ang), A[1] + x * math.sin(ang) + y * math.cos(ang)))
    mr, hr, sr, sdr = tube(ring, [6.5] * len(ring))
    cr_ = MAY * (1 + .12 * np.sin(sr * 1.6))[..., None]
    c, _ = P.shade(hr, cr_, amb=.45, dif=.72, spec=.12, sp_pow=24)
    P.put(mr, c, line=.6, lw=1, contact=.25)
    # cọc trước + dây buộc ngang thân
    bamboo(P, 352, 100, 356, 440, 10, 4, contact=.35)
    rope_band(P, 354, 296, 13, 30, 0.0, 41)
    # mực nước: ngang thân hơi dưới trục
    yw = 296 + (X - 256) * .06
    wl = sstep(yw - 2, yw + 18, Y)
    return save2(P, 'lo', wl, (256, 296))


# ============================================================ LỌP LƯƠN
def lop():
    P = Pic()
    A = np.array([118., 404.]); B = np.array([382., 132.])          # A miệng (dưới nước), B đầu trên
    ax = (B - A) / np.linalg.norm(B - A)
    ang = math.atan2(ax[1], ax[0])
    # cọc nhỏ phía sau
    bamboo(P, 300, 70, 292, 440, 7, 6, node=60, contact=0)
    prof = [(0, 36), (.06, 37), (.5, 36), (.9, 33), (1, 31)]
    pts, rad = smooth_prof(A, B, prof)
    m, h, s, sd = tube(pts, rad)
    m = cut(m, A, ax)
    s, sd = axis_coords(A, ax, pts, rad)
    hw, col, gm = weave(s, sd, m, 13, 26, 3.6, gap=.16, seed=11, ring0=10 + .45 * rad[0], persp=(.45, arclen(pts), rad))
    c, _ = P.shade(h + hw * .8, np.ones(3, np.float32), amb=.4, dif=.76, spec=.08, sp_pow=20)
    P.put(m, np.clip(c * col, 0, 1), edge=TRE_D * .45, line=.5, contact=.3)
    # miệng dưới: vành + hom
    pa = math.atan2(ax[1], ax[0]) + math.pi / 2
    R = rad[0]
    cA = A
    mo, ho = ellipse(*cA, R, R * .45, pa)
    u = (X - cA[0]) * math.cos(pa) + (Y - cA[1]) * math.sin(pa)
    v = -(X - cA[0]) * math.sin(pa) + (Y - cA[1]) * math.cos(pa)
    rr = np.sqrt((u / R) ** 2 + (v / (R * .45)) ** 2); an = np.arctan2(v / .45, u)
    inner = lerpc(TOI * 1.3, TOI * .4, sstep(0, .9, 1 - rr))
    hom = sstep(.55, .9, .5 + .5 * np.cos(an * 12)) * sstep(.15, .5, rr)
    inner = lerpc(inner, lerpc(TRE_D * .8, TRE, rr), hom * .9)
    ci, _ = P.shade(hom * 1.0, np.ones(3, np.float32), amb=.6, dif=.45)
    P.put(mo, np.clip(ci * inner, 0, 1), line=0, contact=.1)
    ring = []
    for i in range(41):
        t = i / 40 * 2 * math.pi
        x = math.cos(t) * R; y = math.sin(t) * R * .45
        ring.append((cA[0] + x * math.cos(pa) - y * math.sin(pa), cA[1] + x * math.sin(pa) + y * math.cos(pa)))
    mr, hr, sr, _ = tube(ring, [4.5] * len(ring))
    c, _ = P.shade(hr, MAY * (1 + .12 * np.sin(sr * 2))[..., None], amb=.45, dif=.72, spec=.12)
    P.put(mr, c, line=.6, lw=1, contact=.2)
    # đầu trên: nùi bẹ chuối khô nhét bịt, buộc dây
    cB = B + ax * 10
    plug = []
    rs = np.random.RandomState(4)
    mp = np.zeros_like(X); hp = np.zeros_like(X)
    for i in range(9):
        o = rs.uniform(-.8, .8); l = rs.uniform(22, 38)
        p0 = cB - ax * 8 + np.array([-ax[1], ax[0]]) * o * 26
        p1 = p0 + ax * l + np.array([-ax[1], ax[0]]) * rs.uniform(-10, 10)
        mm, hh, ss_, _ = tube([tuple(p0), tuple(p1)], [rs.uniform(7, 10), 4])
        hp = np.where(mm > mp, hh, hp); mp = np.maximum(mp, mm)
    pc = lerpc(hexc('#a88b55'), hexc('#6e5634'), sstep(.3, .8, noise(2, 7, 2)))
    pc = pc * (1 - .1 * np.sin((X * ax[1] - Y * ax[0]) * 1.3 + noise(.4, 8) * 5))[..., None]     # sớ bẹ
    c, _ = P.shade(hp, pc, amb=.42, dif=.74, spec=.05)
    P.put(mp, c, contact=.3)
    for i in range(2):
        p = B - ax * (4 + i * 9)
        rope_band(P, p[0], p[1], 6, 74, ang, 50 + i)
    # dây buộc lọp vô cọc
    mt, ht, _, _ = tube([(296, 236), (318, 226), (335, 222)], [2.4, 2.2, 2.2])
    c, _ = P.shade(ht, MAY, amb=.5, dif=.6)
    P.put(mt, c, line=.5, lw=.8, contact=.1)
    # mực nước ngang
    yw = 336 + (X - 256) * .04
    wl = sstep(yw - 2, yw + 18, Y)
    return save2(P, 'lop', wl, (230, 336))


# ============================================================ GIĂNG CÂU
def giang():
    P = Pic()
    L0 = (64, 150); L1 = (448, 168)           # chỗ buộc dây trên 2 cọc
    # dây giăng chùng: parabol
    def line_y(x):
        t = (x - L0[0]) / (L1[0] - L0[0])
        return L0[1] + (L1[1] - L0[1]) * t + 34 * 4 * t * (1 - t)
    # thẻo dây: lưỡi dưới nước
    drops = [140, 218, 296, 374]
    yw0 = 330
    for i, x in enumerate(drops):
        y0 = line_y(x)
        xf = x + 3 + i % 2 * 2
        mt, ht, _, _ = tube([(x, y0), (xf, yw0 - 14)], [1.3, 1.3])
        c, _ = P.shade(ht, hexc('#ded8c8'), amb=.6, dif=.45)
        P.put(mt, c, line=.4, lw=.7, contact=0)
        mt, ht, _, _ = tube([(xf, yw0 + 4), (xf + 1, yw0 + 70)], [1.2, 1.2])
        c, _ = P.shade(ht, hexc('#ded8c8'), amb=.6, dif=.45)
        P.put(mt, c, line=.4, lw=.7, contact=0)
        # lưỡi câu + mồi tép (chìm)
        hk = []
        for k in range(17):
            a = math.pi * (k / 16) * 1.25 - .2
            hk.append((xf + 1 + 5 - math.cos(a) * 5, yw0 + 70 + math.sin(a) * 6.5))
        mh, hh, _, _ = tube(hk, [1.6] * len(hk))
        c, _ = P.shade(hh, hexc('#9aa0a6'), amb=.5, dif=.6, spec=.4, sp_pow=30)
        P.put(mh, c, line=.5, lw=.7, contact=0)
        mb, hb, sb, _ = tube([(xf + 7, yw0 + 74), (xf + 16, yw0 + 64), (xf + 21, yw0 + 53)], [4.5, 4, 2.5])
        cb, _ = P.shade(hb, hexc('#d9b49a') * (1 - .15 * (np.sin(sb * 1.6) > .6))[..., None], amb=.5, dif=.6, spec=.15)
        P.put(mb, cb, line=.5, lw=.8, contact=0)
        # phao: khúc trúc nằm ngang nổi trên nước, đầu sơn đỏ
        fy = yw0 - 6 + (i % 2) * 3
        mf, hf, sf, _ = tube([(xf - 15, fy + 1), (xf + 15, fy - 1)], [6.5, 6.5])
        fc = lerpc(hexc('#d6c07a'), hexc('#c8342a'), (sf > 22).astype(np.float32))
        fc = lerpc(fc, hexc('#8a7a40'), np.exp(-((sf - 13) / 1.6) ** 2) * .6)       # đốt trúc
        c, _ = P.shade(hf, fc, amb=.45, dif=.72, spec=.18, sp_pow=26)
        P.put(mf, c, line=.6, lw=1, contact=.15)
    # dây giăng chính
    xs = np.linspace(L0[0], L1[0], 40)
    pts = [(x, line_y(x)) for x in xs]
    ml, hl, sl, _ = tube(pts, [1.8] * len(pts))
    c, _ = P.shade(hl, hexc('#e6e0cc') * (1 - .12 * np.sin(sl * 1.7))[..., None], amb=.55, dif=.55, spec=.1)    # dây bện
    P.put(ml, c, line=.45, lw=.8, contact=0)
    # 2 cọc tre (cọc phải xa hơn chút: nhỏ hơn)
    bamboo(P, 62, 74, 58, 452, 10.5, 21, node=74, contact=.3)
    bamboo(P, 448, 96, 452, 446, 9.5, 22, node=70, contact=.3)
    rope_band(P, 61, 150, 13, 26, 0.0, 60)
    rope_band(P, 449, 168, 12, 24, 0.0, 61)
    wl = sstep(yw0 - 1, yw0 + 12, Y)
    return save2(P, 'giang', wl, (256, 330))


if __name__ == '__main__':
    os.makedirs(OUTDIR, exist_ok=True)
    for k in BIDS:
        {'lo': lo, 'lop': lop, 'giang': giang}[k]()
