# v3 đồ trang trí: nong lúa có hạt thật, chậu bông giấy có cành, lu nước mới (cùng ánh sáng), mái lá loang màu
import math
import numpy as np
from PIL import Image, ImageDraw
import props as P
import board2 as B
from trees import stamp
from trees4 import leaf_patch

def _height_light(h, K, k=1.0):
    gy, gx = np.gradient(h * K * k)
    nx, ny = -gx, -gy
    nz = np.ones_like(h)
    l = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    return P.lam(nx / l, ny / l, nz / l)

def nong3(K, R=150.0, seed=1):
    rg = np.random.default_rng(seed)
    img = P.nong(K, R, seed)
    n = img.shape[0]; c = n / 2
    xx, yy = P.grid(n)
    dx = (xx - c) / K; dy = (yy - c) / K
    d = np.hypot(dx, dy)
    # mặt lúa: đống dày giữa, mỏng ra mép; vài đường cào cong không đều, có chỗ đứt
    warp = (B.fbm(n, n, 40 * K, 2, rg) - 0.5) * 7
    ph = (dy + warp + dx * 0.05 + 0.0009 * dx ** 2) / (R * 0.08)
    amp = np.clip((B.fbm(n, n, 30 * K, 2, rg) - 0.15) * 1.8, 0.35, 1)
    furrow = (0.5 + 0.5 * np.cos(ph * math.pi * 2)) ** 3 * amp
    heap = np.clip((R * 0.8 - d) / (R * 0.35), 0, 1) ** 0.7
    hgt = heap * (1.0 - 0.45 * furrow) * (0.85 + 0.3 * B.fbm(n, n, 12 * K, 2, rg))
    hgt = P.blur(hgt, 0.8 * K)
    sh = _height_light(hgt, K, R * 0.06)
    # hạt lúa: vẽ từng hạt thóc thuôn, xoay ngẫu nhiên, có viền sáng/tối
    g = Image.new('RGB', (n, n), (0, 0, 0)); gd = ImageDraw.Draw(g)
    gm = Image.new('L', (n, n), 0); gmd = ImageDraw.Draw(gm)
    N = int(R * R * 1.7)
    pts = rg.random((N, 2)) * n
    for (x, y) in pts:
        dd = math.hypot(x / K - c / K, y / K - c / K)
        local = heap_at = max(0.0, min(1.0, (R * 0.8 - dd) / (R * 0.35)))
        if rg.random() > local * 1.15 + 0.03:
            continue
        a = rg.uniform(0, math.pi); L = 1.6 * K; Wd = 0.62 * K
        ca, sa = math.cos(a), math.sin(a)
        poly = [(x + ca * L * math.cos(t) - sa * Wd * math.sin(t), y + sa * L * math.cos(t) + ca * Wd * math.sin(t)) for t in np.linspace(0, 6.283, 8)]
        v = int(rg.uniform(150, 255))
        gd.polygon(poly, fill=(v, int(v * rg.uniform(0.82, 0.9)), int(v * rg.uniform(0.48, 0.6))))
        gmd.polygon(poly, fill=255)
    gr = np.asarray(g, np.float32) / 255
    gmk = np.asarray(gm, np.float32) / 255
    gap = 1 - gmk * 0.0
    base = np.array([204, 170, 104], np.float32)
    rice = base * (0.45 + 0.65 * sh)[..., None] * (0.55 + 0.6 * gr * gmk[..., None] + 0.25 * (1 - gmk)[..., None])
    rice *= (1 - 0.18 * (1 - gmk))[..., None]                        # kẽ hạt tối
    cov = np.clip(hgt * 3, 0, 1)
    cov = np.maximum(cov, gmk * (d < R * 0.86))                         # hạt vãi lác đác ra mép
    cov *= (d < R * 0.87)
    # bóng cạp nong đổ vào
    img[..., :3] = img[..., :3] * (1 - cov[..., None]) + rice * cov[..., None]
    rim0 = R * 0.9
    shin = np.clip(1 - (rim0 - d) / 7.0, 0, 1) * np.clip((dx * P.L[0] + dy * P.L[1]) / np.maximum(d, 1e-3) + 0.3, 0, 1) * (d < rim0)
    img[..., :3] *= (1 - 0.4 * shin)[..., None]
    return img

def chau_bong3(K, R=60.0, seed=5):
    """chậu bông giấy: chậu sành, cành gỗ cong toả ra, lá tim xanh, chùm lá bắc hồng tím 3 cánh"""
    rg = np.random.default_rng(seed)
    from trees4 import capsule
    n = int(R * 2.6 * K); c = n / 2
    xx, yy = P.grid(n)
    dx = (xx - c) / K; dy = (yy - c) / K
    d = np.hypot(dx, dy)
    img = np.zeros((n, n, 4), np.float32)
    pr = R * 0.42
    t = (d - pr * 0.8) / (pr * 0.2)
    rm = (t >= 0) & (t <= 1)
    rn = np.clip((t - 0.5) * 1.8, -1, 1)
    sr = P.lam(rn * dx / np.maximum(d, 1e-3), rn * dy / np.maximum(d, 1e-3), np.sqrt(1 - rn ** 2))
    pot = np.array([160, 86, 52], np.float32) * (0.5 + 0.7 * sr)[..., None] * (0.9 + 0.15 * B.fbm(n, n, 2 * K, 2, rg))[..., None]
    dirt = d < pr * 0.8
    col = np.where(dirt[..., None], np.array([66, 46, 30]) * (0.75 + 0.4 * B.fbm(n, n, 0.8 * K, 2, rg))[..., None], pot)
    P.over(img, P.rgba(col, P.blur((d <= pr).astype(np.float32), 0.3 * K)))
    C = c / K
    ends = []
    for i in range(7):
        a = i / 7 * 6.283 + rg.uniform(-0.3, 0.3)
        x, y = C + math.cos(a) * 3, C + math.sin(a) * 3
        w = 3.2
        for s in range(4):
            a += rg.uniform(-0.35, 0.35)
            ln = R * rg.uniform(0.18, 0.26)
            x1, y1 = x + math.cos(a) * ln, y + math.sin(a) * ln
            capsule(img, K, x, y, x1, y1, w, w * 0.8, (112, 86, 62), rg)
            ends.append((x1, y1, a, s))
            x, y, w = x1, y1, w * 0.8
    # lá + bông dọc cành, nhiều ở ngoài
    items = []
    for x, y, a, s in ends:
        for k in range(10 + s * 5):
            items.append((rg.random(), x + rg.normal(0, 7), y + rg.normal(0, 7), a))
    items.sort()
    for h, x, y, a in items:
        light = 0.7 + 0.4 * h
        if rg.random() < 0.55:
            ln = rg.uniform(11, 15)
            p, r = leaf_patch(K, ln, ln * 0.6, a + rg.normal(0, 1.0), [62, 118, 44], light, rg)
            stamp(img, p, x * K, y * K)
        else:
            a0 = rg.uniform(0, 6.283); col = np.array([206, 46, 122]) * rg.uniform(0.85, 1.1)
            for b in range(3):
                ab = a0 + b * 2.094
                ln = rg.uniform(8, 11)
                p, r = leaf_patch(K, ln, ln * 0.72, ab, col, light, rg)
                stamp(img, p, (x + math.cos(ab) * ln * 0.42) * K, (y + math.sin(ab) * ln * 0.42) * K)
            # nhuỵ trắng kem
            e = np.hypot(dx - (x - C), dy - (y - C))
            m = (e < 1.3).astype(np.float32)
            img[..., :3] = img[..., :3] * (1 - m[..., None]) + np.array([246, 236, 200]) * m[..., None]
    return img

def lu3(K, R=70.0, seed=7):
    """lu nước da lươn nhìn từ trên: thân cầu men nâu nhám, miệng tròn, nước trong xanh, gáo dừa"""
    rg = np.random.default_rng(seed)
    n = int(R * 2.3 * K); c = n / 2
    xx, yy = P.grid(n)
    dx = (xx - c) / K; dy = (yy - c) / K
    d = np.hypot(dx, dy)
    e = d / R
    nz = np.sqrt(np.clip(1 - e ** 2, 0, 1))
    s = P.lam(dx / R, dy / R, nz)
    glaze = B.fbm(n, n, 4 * K, 3, rg)
    drip = 0.5 + 0.5 * np.sin(np.arctan2(dy, dx) * 26 + B.fbm(n, n, 8 * K, 2, rg) * 4)
    col = np.array([142, 86, 46], np.float32) * (0.36 + 0.82 * s)[..., None] * (0.85 + 0.2 * glaze + 0.08 * drip * (e > 0.6))[..., None]
    col += (np.clip(s - 0.93, 0, 1) * 600)[..., None] * 0.25          # men lì, bóng mờ nhỏ
    # vòng gờ vai (đường chỉ nổi) ở 0.72R
    ang_ = np.arctan2(dy, dx)
    band = np.exp(-((e - 0.72) / 0.015) ** 2) + 0.8 * np.exp(-((e - 0.86 - 0.025 * np.sin(ang_ * 14)) / 0.02) ** 2)
    col *= (1 + 0.18 * band * (s - 0.5))[..., None]
    img = P.rgba(col, P.blur((e <= 1).astype(np.float32), 0.35 * K))
    # miệng lu
    mr = R * 0.5
    t = (d - mr) / (R * 0.09)
    rim = (t >= -1) & (t <= 1)
    rs = P.lam(t * dx / np.maximum(d, 1e-3) * 0.9, t * dy / np.maximum(d, 1e-3) * 0.9, np.sqrt(np.clip(1 - t ** 2 * 0.81, 0, 1)))
    rc = np.array([132, 80, 44], np.float32) * (0.4 + 0.8 * rs)[..., None]
    img[..., :3] = np.where(rim[..., None], rc, img[..., :3])
    # nước: trong, xanh, thấy đáy tối, phản chiếu trời + tán lá; bóng miệng lu đổ vào
    w = d < mr - R * 0.09
    depth = np.clip(d / (mr - R * 0.09), 0, 1)
    water = np.array([60, 118, 140], np.float32) * (0.5 + 0.4 * depth)[..., None]
    sky = np.exp(-(((dx + mr * 0.35) / (mr * 0.35)) ** 2 + ((dy + mr * 0.3) / (mr * 0.25)) ** 2))
    water = water * (1 - 0.5 * sky[..., None]) + np.array([214, 236, 246]) * 0.5 * sky[..., None]
    rip = B.fbm(n, n, 6 * K, 2, rg)
    water *= (0.92 + 0.12 * rip)[..., None]
    inner_sh = np.clip(((dx * -P.L[0] + dy * -P.L[1]) / np.maximum(d, 1e-3) * -1 + 0.2) * np.clip((d - (mr - R * 0.3)) / (R * 0.2), 0, 1), 0, 1)
    water *= (1 - 0.45 * inner_sh)[..., None]
    img[..., :3] = np.where(w[..., None], water, img[..., :3])
    # gáo dừa nổi: nửa vỏ dừa nâu + cán tre gác lên miệng
    gx, gy = mr * 0.25, mr * 0.2
    from trees4 import capsule
    ge = np.hypot(dx - gx, dy - gy) / (R * 0.22)
    gm = ge <= 1
    gs = P.lam(-(dx - gx) / (R * 0.22), -(dy - gy) / (R * 0.22), np.sqrt(np.clip(1 - ge ** 2, 0, 1)))   # lòng gáo lõm
    fib = 0.85 + 0.2 * B.fbm(n, n, 1.0 * K, 2, rg)
    gcol = np.where((ge > 0.84)[..., None], np.array([150, 104, 60]) * (0.7 + 0.5 * P.lam((dx - gx) / (R * 0.22), (dy - gy) / (R * 0.22), np.sqrt(np.clip(1 - ge ** 2, 0, 1))))[..., None], np.array([120, 78, 44]) * (0.5 + 0.6 * gs)[..., None] * fib[..., None])
    img[..., :3] = np.where(gm[..., None], gcol, img[..., :3])
    capsule(img, K, c / K + gx + R * 0.13, c / K + gy + R * 0.09, c / K + gx + R * 0.5, c / K + gy + R * 0.36, 4.5, 4.0, (176, 146, 92), rg)
    return img

def mai_la3(K, W_, H_, seed=4, side='right'):
    """mái lá v3: nẹp tre võng, màu loang theo mảng (lá cũ xám, lá mới vàng), sáng tối theo dốc"""
    rg = np.random.default_rng(seed + 100)
    img = P.mai_la(K, W_, H_, seed, side)
    h, w = img.shape[:2]
    big = B.fbm(h, w, 90 * K, 2, rg)
    mid = B.fbm(h, w, 25 * K, 2, rg)
    grey = np.clip((big - 0.5) * 3.5, 0, 1)
    new = np.clip((0.42 - mid) * 4, 0, 1)
    col = img[..., :3]
    lum = col.mean(axis=2, keepdims=True)
    col = col * (1 - 0.7 * grey[..., None]) + (lum * np.array([0.92, 0.9, 0.86])) * 0.7 * grey[..., None]
    col = col * (1 + 0.28 * new[..., None] * np.array([1.0, 0.95, 0.5]))
    X = np.arange(w, dtype=np.float32)[None, :] / K
    if side == 'right':
        X = W_ - X
    slope = 0.86 + 0.24 * np.clip(X / W_, 0, 1)
    col *= slope[..., None] if slope.ndim == 2 else slope
    img[..., :3] = col
    # mép mái lởm chởm: ngọn lá dài ngắn không đều, có chỗ xơ tưa
    yy = np.arange(h, dtype=np.float32) / K
    jag = 4 + 22 * B.fbm(1, h, 30 * K, 3, rg)[0] + 14 * np.abs(np.sin(yy * 0.55 + 4 * B.fbm(1, h, 8 * K, 1, rg)[0])) ** 4 + 4 * B.fbm(1, h, 0.8 * K, 1, rg)[0]
    xe = (W_ - np.arange(w, dtype=np.float32) / K) if side == 'left' else (np.arange(w, dtype=np.float32) / K)
    cut = xe[None, :] < jag[:, None]
    img[..., 3] = np.where(cut, 0, img[..., 3])
    edge = np.clip(1 - (xe[None, :] - jag[:, None]) / 6, 0, 1) * (~cut)
    img[..., :3] *= (1 - 0.25 * edge)[..., None]
    return img

def non4(K, R=80.0, seed=8, quai=False):   # Link 11-21: bỏ quai (nhìn từ trên ra vệt đỏ khó hiểu)
    """nón lá nhìn từ trên: chóp nón, 16 vòng nan, lá xếp theo tia, đường khâu chỉ, quai lụa"""
    rg = np.random.default_rng(seed)
    n = int(R * 2.4 * K); c = n / 2
    xx, yy = P.grid(n)
    dx = (xx - c) / K; dy = (yy - c) / K
    d = np.hypot(dx, dy); e = d / R
    ang = np.arctan2(dy, dx)
    k = 0.75                                       # độ dốc nón
    nx = dx / np.maximum(d, 1e-3) * k; ny = dy / np.maximum(d, 1e-3) * k
    nz = np.ones_like(d); l = np.sqrt(nx ** 2 + ny ** 2 + 1)
    lam = P.lam(nx / l, ny / l, nz / l)
    strips = 0.5 + 0.5 * np.cos(ang * 64 + B.fbm(n, n, 8 * K, 2, rg) * 1.5)
    rings = (np.abs(((e * 16) % 1.0) - 0.5) < 0.05) & (e > 0.08)
    stitch = rings & (np.sin(ang * 140) > 0.3)
    fib = B.fbm(n, n, 0.5 * K, 2, rg, ay=4)
    base = np.array([236, 226, 190], np.float32)
    col = base * (0.5 + 0.6 * lam)[..., None] * (0.92 + 0.06 * strips + 0.06 * fib)[..., None]
    col *= (1 - 0.18 * rings)[..., None]
    col = np.where(stitch[..., None], np.array([250, 248, 236]) * (0.7 + 0.4 * lam)[..., None], col)
    age = np.clip((B.fbm(n, n, 25 * K, 2, rg) - 0.55) * 2, 0, 1) * 0.25
    col = col * (1 - age[..., None]) + np.array([196, 170, 120]) * age[..., None]
    # vành nón
    rimm = (e > 0.96)
    col = np.where(rimm[..., None], np.array([214, 196, 150]) * (0.6 + 0.5 * lam)[..., None], col)
    tip = np.exp(-(d / 2.5) ** 2)
    col = col * (1 - 0.3 * tip[..., None])
    img = P.rgba(col, P.blur((e <= 1).astype(np.float32), 0.3 * K))
    if not quai:
        return img
    # quai lụa hồng vắt qua
    from trees4 import capsule
    C = c / K
    pts = [(C - R * 0.98, C + R * 0.1)] + [(C - R * 0.98 + R * 1.96 * f, C + R * 0.1 + R * 0.55 * math.sin(f * math.pi)) for f in np.linspace(0.02, 1, 40)]
    for a_, b_ in zip(pts[:-1], pts[1:]):
        capsule(img, K, a_[0], a_[1], b_[0], b_[1], 3.2, 3.2, (226, 120, 140), rg, bark=False)
    return img

def chick4(K, s=1.0, seed=0, ang=0.0):
    """gà con lông tơ vàng nhìn từ trên: thân tròn bông, đầu nhỏ, mỏ cam, mắt đen, cánh nhú"""
    rg = np.random.default_rng(seed)
    R = 11 * s
    n = int(R * 3.2 * K) | 1; c = n / 2
    xx, yy = P.grid(n)
    X = (xx - c) / K; Y = (yy - c) / K
    ca, sa = math.cos(ang), math.sin(ang)
    u = X * ca + Y * sa; v = -X * sa + Y * ca
    img = np.zeros((n, n, 4), np.float32)
    fuzz = B.fbm(n, n, 0.6 * K, 2, rg)
    def blob(cu, cv_, ra, rb, colr, edge_f=0.18):
        e = np.hypot((u - cu) / ra, (v - cv_) / rb)
        aa = np.arctan2(v - cv_, u - cu)
        ee = e - edge_f * (fuzz - 0.5) - edge_f * 0.6 * np.abs(np.sin(aa * 23 + fuzz * 6))
        nz = np.sqrt(np.clip(1 - e ** 2, 0, 1))
        nxr = (u - cu) / ra; nyr = (v - cv_) / rb
        lam = P.lam(nxr * ca - nyr * sa, nxr * sa + nyr * ca, nz)
        col = np.array(colr, np.float32) * (0.5 + 0.65 * lam)[..., None] * (0.9 + 0.2 * fuzz)[..., None]
        P.over(img, P.rgba(col, np.clip((1 - ee) * 6, 0, 1)))
    blob(-2 * s, 0, R, R * 0.85, (240, 206, 90))
    blob(-3 * s, -6.5 * s, 4 * s, 3 * s, (226, 186, 74)); blob(-3 * s, 6.5 * s, 4 * s, 3 * s, (226, 186, 74))
    blob(R * 0.85, 0, R * 0.55, R * 0.52, (246, 214, 100))
    blob(R * 1.42, 0, 2.6 * s, 1.5 * s, (232, 130, 40), 0)
    blob(R * 0.95, -3.4 * s, 1.1 * s, 1.1 * s, (20, 16, 12), 0); blob(R * 0.95, 3.4 * s, 1.1 * s, 1.1 * s, (20, 16, 12), 0)
    return img

def hen4(K, s=1.0, seed=0, ang=0.0):
    """gà mái ta nhìn từ trên: thân bầu, lông vảy nâu đỏ viền sẫm, cánh xếp, đuôi đen ánh xanh, đầu mào đỏ"""
    rg = np.random.default_rng(seed)
    L_ = 60 * s
    n = int(L_ * 2.0 * K) | 1; c = n / 2
    xx, yy = P.grid(n)
    X = (xx - c) / K; Y = (yy - c) / K
    ca, sa = math.cos(ang), math.sin(ang)
    U = X * ca + Y * sa; V = -X * sa + Y * ca
    img = np.zeros((n, n, 4), np.float32)
    def rot(du, dv):
        return du * ca - dv * sa, du * sa + dv * ca
    def feather(cu, cv_, fa, ln, wd, colr, light=1.0, dark_edge=0.4):
        fu = math.cos(fa); fv = math.sin(fa)
        u = (U - cu) * fu + (V - cv_) * fv; v = -(U - cu) * fv + (V - cv_) * fu
        t = u / (ln / 2)
        half = wd / 2 * np.clip(1 - t ** 2, 0, 1) ** 0.5 * (1 + 0.25 * t)
        m = (np.abs(t) <= 1) & (np.abs(v) <= half)
        if not m.any():
            return
        sv = np.where(half > 0, v / np.maximum(half, 1e-3), 0)
        nxl, nyl = rot(fu * 0.35 * t, fv * 0.35 * t + sv * 0.3)
        lam = P.lam(nxl, nyl, np.sqrt(np.clip(1 - nxl ** 2 - nyl ** 2, 0, 1)))
        lam = 0.55 + 0.45 * lam
        edge = np.clip((np.maximum(np.abs(sv), t) - 0.6) * 2.5, 0, 1)
        rach = np.exp(-(v / (0.06 * wd + 0.2)) ** 2)
        col = np.array(colr, np.float32) * (0.45 + 0.7 * lam)[..., None] * light * (1 - dark_edge * edge)[..., None] * (1 + 0.15 * rach)[..., None]
        P.over(img, P.rgba(col, P.blur(m.astype(np.float32), 0.25 * K)))
    # đuôi (phía sau, -u), lông đen ánh xanh
    for i in range(11):
        fa = math.pi + (i - 5) * 0.11 + rg.uniform(-0.05, 0.05)
        feather(-33 * s + rg.uniform(-2, 2) * s, (i - 5) * 1.3 * s, fa, rg.uniform(22, 30) * s, 6.5 * s, (40, 52, 46) if i % 3 else (54, 74, 60), 1.0, 0.2)
    # nền thân bầu dục (để lông không lổn nhổn)
    eb = np.hypot((U + 2 * s) / (31 * s), V / (21 * s))
    nxl, nyl = rot((U + 2 * s) / (31 * s), V / (21 * s))
    lb = P.lam(nxl, nyl, np.sqrt(np.clip(1 - eb ** 2, 0, 1)))
    P.over(img, P.rgba(np.array([150, 74, 38], np.float32) * (0.45 + 0.7 * lb)[..., None], np.clip((1 - eb) * 8, 0, 1)))
    # thân: lớp lông vảy nhỏ từ sau ra trước
    for row in range(12):
        uu = -26 * s + row * 4.4 * s
        wdh = 19 * s * math.sqrt(max(0.05, 1 - ((uu + 2 * s) / (30 * s)) ** 2))
        cnt = int(wdh / (2.6 * s)) + 2
        for j in range(cnt):
            vv = -wdh + 2 * wdh * j / max(1, cnt - 1) + rg.uniform(-1, 1) * s
            base = (150, 70, 36) if abs(vv) > wdh * 0.55 else (176, 92, 44)
            feather(uu, vv, math.pi + vv / (wdh + 1e-3) * 0.6, 10 * s, 6 * s, np.array(base) * rg.uniform(0.93, 1.05), 1.0, 0.1)
    # cánh xếp hai bên: lông dài sẫm
    for sd in (-1, 1):
        for i in range(6):
            feather(-6 * s + i * 2.5 * s, sd * (14 - i * 0.6) * s, math.pi + sd * 0.12, 24 * s, 5.5 * s, (128, 62, 32), 1.0, 0.3)
    # cổ lông vàng nâu
    for i in range(14):
        a = rg.uniform(-1.3, 1.3)
        feather(20 * s + math.cos(a) * 4 * s, math.sin(a) * 6 * s, math.pi + a * 0.4, 12 * s, 5 * s, (214, 150, 70), 1.05, 0.3)
    # đầu, mào, mỏ, mắt
    def ell(cu, cv_, ra, rb, colr):
        e = np.hypot((U - cu) / ra, (V - cv_) / rb)
        nxl, nyl = rot((U - cu) / ra, (V - cv_) / rb)
        lam = P.lam(nxl, nyl, np.sqrt(np.clip(1 - e ** 2, 0, 1)))
        P.over(img, P.rgba(np.array(colr, np.float32) * (0.45 + 0.7 * lam)[..., None], np.clip((1 - e) * 5, 0, 1)))
    # làm mềm lông thân: trộn với bản mờ
    from PIL import ImageFilter
    rgbim = Image.fromarray(np.clip(img[..., :3], 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2 * K))
    img[..., :3] = img[..., :3] * 0.75 + np.asarray(rgbim, np.float32) * 0.25
    barb = B.fbm(n, n, 0.25 * K, 1, rg, ay=4)
    img[..., :3] *= (0.94 + 0.12 * barb)[..., None]
    ell(29 * s, 0, 6.5 * s, 5.4 * s, (200, 126, 60))
    for i in range(4):
        ell(26.5 * s + i * 2.2 * s, 0, 1.5 * s, (0.9 + 0.35 * (i % 2)) * s, (220, 44, 38))
    ell(36.5 * s, 0, 3.2 * s, 1.5 * s, (226, 170, 60))
    ell(31.5 * s, -3.3 * s, 0.95 * s, 0.95 * s, (226, 150, 40)); ell(31.5 * s, 3.3 * s, 0.95 * s, 0.95 * s, (226, 150, 40))
    ell(31.7 * s, -3.4 * s, 0.5 * s, 0.5 * s, (10, 8, 6)); ell(31.7 * s, 3.4 * s, 0.5 * s, 0.5 * s, (10, 8, 6))
    return img

def ro_xoai(K, R=60.0, seed=9):
    """rổ tre đựng xoài chín hái từ cây"""
    rg = np.random.default_rng(seed)
    img = P.nong(K, R, seed)
    n = img.shape[0]; c = n / 2
    xx, yy = P.grid(n)
    dx = (xx - c) / K; dy = (yy - c) / K
    d = np.hypot(dx, dy)
    inner = np.clip(1 - d / (R * 0.88), 0, 1)
    img[..., :3] *= (0.6 + 0.4 * (1 - inner ** 0.5) * 0 + 0.4 * np.clip(d / (R * 0.88), 0, 1))[..., None]
    from trees4 import mango_fruit
    pos = []
    for i in range(int(R / 7)):
        for _ in range(30):
            a = rg.uniform(0, 6.283); r = R * 0.62 * math.sqrt(rg.random())
            x, y = math.cos(a) * r, math.sin(a) * r
            if all(math.hypot(x - px, y - py) > R * 0.27 for px, py in pos):
                pos.append((x, y)); break
    for x, y in pos:
        mango_fruit(img, K, c / K + x, c / K + y, R * 0.26, R * 0.17, rg.uniform(0, 6.283), rg, ripe=rg.uniform(0.6, 1.0))
    return img

