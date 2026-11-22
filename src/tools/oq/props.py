# Đồ trang trí sân cờ caro, nhìn thẳng từ trên xuống, nắng trái-trên (bóng đổ phải-dưới như Cờ gánh).
# Mỗi món trả RGBA numpy (float 0..255) ở K điểm ảnh / css. Mỗi món 1 file khi nướng.
import math
import numpy as np
from PIL import Image, ImageFilter, ImageDraw
import board2 as B

L = np.array([-0.55, -0.62, 0.56]); L = L / np.linalg.norm(L)

def grid(n):
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    return xx, yy

def lam(nx, ny, nz):
    return np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)

def blur(a, r):
    return np.asarray(Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255

def rgba(col, al):
    return np.dstack([np.clip(col, 0, 255), np.clip(al, 0, 1) * 255]).astype(np.float32)

def over(dst, src, x0=0, y0=0):
    """src lên dst (cả hai RGBA float)"""
    h, w = src.shape[:2]
    d = dst[y0:y0 + h, x0:x0 + w]
    a = src[..., 3:4] / 255
    da = d[..., 3:4] / 255
    oa = a + da * (1 - a)
    d[..., :3] = np.where(oa > 0, (src[..., :3] * a + d[..., :3] * da * (1 - a)) / np.maximum(oa, 1e-6), 0)
    d[..., 3:4] = oa * 255

# ------------------------------------------------------------ cái nong phơi lúa
def nong(K, R=74.0, seed=1):
    rg = np.random.default_rng(seed)
    n = int(R * 2.2 * K); c = n / 2
    xx, yy = grid(n)
    dx = (xx - c) / K; dy = (yy - c) / K
    d = np.hypot(dx, dy)
    out = np.zeros((n, n, 4), np.float32)
    # đáy đan lóng mốt (2 lên 2 xuống), nan tre 2.2 cm
    u = (dx + dy) / math.sqrt(2); v = (dx - dy) / math.sqrt(2)
    w = 2.6
    iu = np.floor(u / w); iv = np.floor(v / w)
    fu = u / w - iu; fv = v / w - iv
    top = ((iu.astype(int) + iv.astype(int) // 2) % 2) == 0          # nan nào nằm trên
    f = np.where(top, fv, fu)                                          # bề ngang nan
    ndir = (f - 0.5) * 1.6
    nz = np.sqrt(np.clip(1 - ndir ** 2, 0, 1))
    nx = np.where(top, ndir / math.sqrt(2), ndir / math.sqrt(2))
    ny = np.where(top, -ndir / math.sqrt(2), ndir / math.sqrt(2))
    sh = lam(nx, ny, nz)
    base = np.array([196, 160, 104], np.float32)
    tone = B.fbm(n, n, 6 * K, 2, rg)
    col = base * (0.62 + 0.5 * sh)[..., None] * (0.88 + 0.2 * tone)[..., None]
    gap = np.minimum(np.minimum(fu, 1 - fu), np.minimum(fv, 1 - fv))
    col *= (0.55 + 0.45 * np.clip(gap * 12, 0, 1))[..., None]
    # lúa phơi: lớp hạt vàng dày ở giữa, mỏng dần ra mép, có vệt cào
    rake = 0.5 + 0.5 * np.sin(dy / 3.2 + np.sin(dx / 18) * 1.4)
    cover = np.clip((R * 0.82 - d) / (R * 0.25), 0, 1) * (0.75 + 0.25 * rake)
    # lớp lúa: luống cào cong, gờ sáng / rãnh tối, hạt li ti
    ph = dy / 3.0 + np.sin(dx / 16) * 1.6
    ridge = np.sin(ph)
    slope = np.cos(ph)
    nyr = slope * 0.55
    sl = lam(np.zeros_like(nyr), nyr, np.sqrt(1 - nyr ** 2))
    grain = B.fbm(n, n, 0.55 * K, 2, rg)
    grain2 = B.fbm(n, n, 1.4 * K, 2, rg)
    rice = np.array([204, 160, 72], np.float32) * (0.55 + 0.55 * sl)[..., None] * (0.78 + 0.3 * grain + 0.12 * grain2)[..., None]
    rice += (np.clip(grain - 0.72, 0, 1) * 160)[..., None] * np.array([1.0, 0.9, 0.6])
    cov = np.clip(cover * 1.4 - 0.15 * (1 - ridge) * (cover < 0.9), 0, 1)
    edge_g = (grain2 * 0.6 + 0.4) < cov
    gm = blur(edge_g.astype(np.float32), 0.3 * K) * (d < R * 0.88)
    col *= (1 - 0.3 * np.clip(blur(gm, 1.0 * K) - gm, 0, 1))[..., None]
    col = col * (1 - gm[..., None]) + rice * gm[..., None]
    # vành nong: cạp tre tròn 2 lớp, dây mây quấn
    rim0 = R * 0.9; rimw = R * 0.1
    t = (d - rim0) / rimw
    rimm = (t >= 0) & (t <= 1)
    rn = (t - 0.5) * 1.8
    nzr = np.sqrt(np.clip(1 - rn ** 2, 0, 1))
    nxr = rn * dx / np.maximum(d, 1e-3); nyr = rn * dy / np.maximum(d, 1e-3)
    sr = lam(nxr, nyr, nzr)
    ang = np.arctan2(dy, dx)
    wrap = (np.sin(ang * R * 0.9 + t * 2.0) > 0.55)
    rc = np.array([176, 132, 74], np.float32) * (0.5 + 0.65 * sr)[..., None]
    rc = np.where(wrap[..., None], rc * 0.72 + np.array([60, 40, 20]) * 0.1, rc)
    col = np.where(rimm[..., None], rc, col)
    # bóng vành đổ vào lòng nong
    inner = (d < rim0)
    shin = np.clip(1 - (rim0 - d) / 5.0, 0, 1) * np.clip(-(dx * L[0] + dy * L[1]) / np.maximum(d, 1e-3) * -1 + 0.2, 0, 1)
    col *= (1 - 0.35 * shin * inner)[..., None]
    al = (d <= R).astype(np.float32)
    al = blur(al, 0.35 * K)
    return rgba(col, al)

# ------------------------------------------------------------ mâm trà (khay gỗ tròn, bình trà, chén)
def mam_tra(K, R=30.0, seed=2):
    rg = np.random.default_rng(seed)
    q = R / 30.0
    n = int(R * 2.3 * K); c = n / 2
    xx, yy = grid(n)
    dx = (xx - c) / K; dy = (yy - c) / K
    d = np.hypot(dx, dy)
    # khay gỗ: mặt phẳng thớ ngang + gờ tròn
    vf, late, pores = B.wood_field(n, n, K, rg)
    wood = B.colorize(vf.T, late.T, pores.T, 0.12)
    col = wood * 1.0
    t = (d - R * 0.88) / (R * 0.12)
    rm = (t >= 0) & (t <= 1)
    rn = (t - 0.5) * 1.8
    sr = lam(rn * dx / np.maximum(d, 1e-3), rn * dy / np.maximum(d, 1e-3), np.sqrt(np.clip(1 - rn ** 2, 0, 1)))
    col = np.where(rm[..., None], wood * (0.55 + 0.7 * sr)[..., None], col)
    al = blur((d <= R).astype(np.float32), 0.3 * K)
    img = rgba(col, al)

    def shadow_disc(cx, cy, r, ox=1.2, oy=1.5, s=0.55, b=1.4):
        m = ((np.hypot(dx - cx - ox, dy - cy - oy) < r)).astype(np.float32)
        m = blur(m, b * K)
        img[..., :3] *= (1 - s * m)[..., None]

    def sphere(cx, cy, r, base, gloss=0.25):
        ex = (dx - cx) / r; ey = (dy - cy) / r; e = np.hypot(ex, ey)
        m = e <= 1
        nz = np.sqrt(np.clip(1 - e ** 2, 0, 1))
        s = lam(ex, ey, nz)
        cc = np.array(base, np.float32) * (0.35 + 0.8 * s)[..., None]
        spec = np.clip(s - 0.9, 0, 1) * 10 * gloss
        cc += (spec * 255)[..., None] * 0.4
        aa = blur(m.astype(np.float32), 0.3 * K)
        img[..., :3] = img[..., :3] * (1 - aa[..., None]) + cc * aa[..., None]
        return m

    # bình trà đất nung (nhìn từ trên: thân tròn, nắp, núm, vòi, quai)
    tx, ty = -6.0 * q, -4.0 * q
    shadow_disc(tx, ty, 11.0 * q, 3.0 * q, 3.5 * q, 0.5, 2.0 * q)
    # vòi
    for k in range(10):
        f = k / 9
        sx = tx + (9 + f * 7) * q; sy = ty + (3 + f * 4) * q
        sphere(sx, sy, (2.2 - f * 0.7) * q, (150, 74, 46))
    # quai (vòng tròn bên trái)
    qa = (np.abs(np.hypot(dx - (tx - 10.5 * q), dy - (ty - 1 * q)) - 3.4 * q) < 1.0 * q)
    qn = blur(qa.astype(np.float32), 0.4 * K)
    img[..., :3] = img[..., :3] * (1 - qn[..., None]) + np.array([132, 64, 40]) * qn[..., None]
    sphere(tx, ty, 10.0 * q, (160, 80, 50))
    sphere(tx, ty, 5.2 * q, (150, 74, 46))
    sphere(tx - 0.3 * q, ty - 0.3 * q, 1.6 * q, (120, 60, 36))
    # 3 chén: miệng tròn trắng men ngà, nước trà trong
    for (cx, cy) in [(10.5 * q, -9.5 * q), (13.5 * q, 4.5 * q), (2.0 * q, 13.0 * q)]:
        shadow_disc(cx, cy, 4.6 * q, 1.6 * q, 2.0 * q, 0.45, 1.0 * q)
        e = np.hypot(dx - cx, dy - cy)
        e = e / q
        rimm2 = (e <= 4.4)
        ring = (e > 3.4) & rimm2
        rn2 = (e - 3.9) / 0.5
        s2 = lam(rn2 * (dx - cx) / np.maximum(e, 1e-3), rn2 * (dy - cy) / np.maximum(e, 1e-3), np.sqrt(np.clip(1 - np.clip(rn2, -1, 1) ** 2, 0, 1)))
        cup = np.array([238, 230, 210], np.float32) * (0.6 + 0.5 * s2)[..., None]
        tea = np.array([156, 104, 34], np.float32) * (0.75 + 0.35 * np.clip(((dx - cx) / q + 2) / 6, 0, 1))[..., None]
        tea += (np.exp(-(((dx - cx) / q + 1.3) ** 2 + ((dy - cy) / q + 1.3) ** 2) / 0.8) * 120)[..., None]
        inside = e <= 3.4
        a1 = blur(rimm2.astype(np.float32), 0.25 * K)
        cc = np.where(inside[..., None], tea, cup)
        img[..., :3] = img[..., :3] * (1 - a1[..., None]) + cc * a1[..., None]
    return img

# ------------------------------------------------------------ cột tràm (nhìn từ trên: mặt cắt tròn đầu cột dưới mái, chỉ thấy chân + bóng)
def cot_tram(K, r=7.0, seed=3):
    rg = np.random.default_rng(seed)
    n = int(r * 3 * K); c = n / 2
    xx, yy = grid(n)
    dx = (xx - c) / K; dy = (yy - c) / K
    e = np.hypot(dx, dy) / r
    m = e <= 1
    nz = np.sqrt(np.clip(1 - e ** 2, 0, 1))
    s = lam(dx / r, dy / r, nz)
    ang = np.arctan2(dy, dx)
    bark = B.fbm(n, n, 1.0 * K, 2, rg) * 0.5 + 0.5 * (0.5 + 0.5 * np.sin(ang * 23 + B.fbm(n, n, 4 * K, 2, rg) * 6))
    col = np.array([150, 128, 104], np.float32) * (0.45 + 0.7 * s)[..., None] * (0.75 + 0.35 * bark)[..., None]
    # đầu cột cưa: vòng tuổi
    core = e < 0.72
    ring = 0.5 + 0.5 * np.sin(e * 40 + B.fbm(n, n, 3 * K, 2, rg) * 3)
    cc = np.array([196, 160, 112], np.float32) * (0.82 + 0.22 * ring)[..., None]
    col = np.where(core[..., None], cc, col)
    al = blur(m.astype(np.float32), 0.3 * K)
    return rgba(col, al)

# ------------------------------------------------------------ mép mái lá (lá dừa nước) đổ xuống, nhìn từ trên
def mai_la(K, W_, H_, seed=4, side='left'):
    """dải mái lá cao H_ css, rộng W_ css; mép tự do ở phía trong (phải nếu side left)"""
    rg = np.random.default_rng(seed)
    w = int(W_ * K); h = int(H_ * K)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    X = xx / K; Y = yy / K
    if side == 'right':
        X = W_ - X
    col = np.zeros((h, w, 3), np.float32)
    al = np.zeros((h, w), np.float32)
    # các hàng lá chằm: hàng trong (gần nóc) đè lên hàng ngoài, mép mỗi hàng là ngọn lá lởm chởm, đổ bóng sang hàng dưới
    P = 10.0
    rows = int(W_ / P) + 2
    eave = W_ - 4 - 3 * B.fbm(h, w, 7 * K, 2, rg)
    for k in range(rows - 1, -1, -1):
        x0 = (k - 1) * P
        tips = 2.2 * np.abs(np.sin(Y * 1.9 + k * 2.3)) + 1.6 * B.fbm(h, w, 0.9 * K, 2, rg) + 0.8 * np.sin(Y * 0.37 + k)
        x1 = x0 + P + tips
        if k == rows - 1:
            x1 = np.minimum(x1, eave)
        band = (X >= x0) & (X < x1) & (X < eave + 1)
        fr = np.clip((X - x0) / (P + 3), 0, 1)
        vein = B.fbm(w, h, 0.8 * K, 3, rg, ay=22).T
        fine = B.fbm(w, h, 0.45 * K, 1, rg, ay=10).T
        base = np.array([150, 124, 78], np.float32) * (1.0 + 0.05 * math.sin(k * 2.1))
        cc = base * (0.50 + 0.45 * vein + 0.18 * fine)[..., None] * (0.80 + 0.32 * fr)[..., None]
        # bóng ngọn lá hàng trên đổ lên (phía phải của mép, nắng từ trái)
        sd = np.clip(1 - (X - x0 + 0.0 - (tips_prev if k < rows - 1 else 0)) / 3.5, 0, 1) if False else 0
        col = np.where(band[..., None], cc, col)
        al = np.where(band, 1.0, al)
        # bóng của hàng này đổ lên hàng ngoài (vẽ trước rồi) ngay sau mép ngọn
        shb = (X >= x1) & (X < x1 + 3.0) & (al > 0)
        sf = np.clip(1 - (X - x1) / 3.0, 0, 1) * shb
        col *= (1 - 0.45 * sf)[..., None]
    # nẹp tre ngang giữ lá (mỗi 110 css)
    for y0 in np.arange(40, H_, 110):
        tilt = rg.uniform(-0.04, 0.04); sag = rg.uniform(1.5, 4.0)
        e = (Y - y0 - 1.2 * np.sin(X / 23 + y0) - tilt * X - sag * np.sin(np.clip(X / max(W_, 1), 0, 1) * math.pi) - 0.8 * np.sin(X / 7.3 + y0 * 0.3)) / 1.6
        m2 = (np.abs(e) <= 1) & (al > 0) & (X < eave - 2)
        nz = np.sqrt(np.clip(1 - e ** 2, 0, 1))
        sv = lam(np.zeros_like(e), e, nz)
        col = np.where(m2[..., None], np.array([168, 150, 96]) * (0.5 + 0.7 * sv)[..., None], col)
        shm = (e > 1) & (e < 2.6) & (al > 0)
        col *= (1 - 0.35 * shm)[..., None]
    # sợi lá khô thò ra mép
    m = Image.new('L', (w, h), 0); md = ImageDraw.Draw(m)
    for i in range(int(H_ / 2.2)):
        y = rg.uniform(0, H_); ex = W_ - 5 + rg.uniform(-2, 2)
        ln = rg.uniform(4, 11); a = rg.uniform(-0.25, 0.25)
        x0, x1 = ex, ex + ln * math.cos(a)
        if side == 'right':
            x0, x1 = W_ - x0, W_ - x1
        md.line([(x0 * K, y * K), (x1 * K, (y + ln * math.sin(a)) * K)], fill=255, width=max(1, int(0.9 * K)))
    sm = np.asarray(m, np.float32) / 255
    col = col * (1 - sm[..., None]) + np.array([176, 146, 92]) * sm[..., None]
    al = np.maximum(al, sm)
    al = blur(al, 0.3 * K)
    return rgba(col, al)

# ------------------------------------------------------------ chậu bông giấy
def chau_bong(K, R=26.0, seed=5):
    rg = np.random.default_rng(seed)
    n = int(R * 2.6 * K); c = n / 2
    xx, yy = grid(n)
    dx = (xx - c) / K; dy = (yy - c) / K
    d = np.hypot(dx, dy)
    img = np.zeros((n, n, 4), np.float32)
    # miệng chậu sành
    t = (d - R * 0.62) / (R * 0.12)
    rm = (t >= 0) & (t <= 1)
    rn = np.clip((t - 0.5) * 1.8, -1, 1)
    sr = lam(rn * dx / np.maximum(d, 1e-3), rn * dy / np.maximum(d, 1e-3), np.sqrt(1 - rn ** 2))
    pot = np.array([150, 82, 50], np.float32) * (0.5 + 0.7 * sr)[..., None]
    img[..., :3] = np.where(rm[..., None], pot, img[..., :3]); img[..., 3] = np.where(rm, 255, 0)
    dirt = d < R * 0.62
    img[..., :3] = np.where(dirt[..., None], np.array([70, 48, 32]) * (0.8 + 0.3 * B.fbm(n, n, 1 * K, 2, rg))[..., None], img[..., :3])
    img[..., 3] = np.where(dirt, 255, img[..., 3])
    # tán lá + chùm bông: nhiều cụm lá bầu dục tô bóng, bông hồng tím
    for i in range(int(260 * min(2.2, (R / 26.0) ** 1.2))):
        a = rg.uniform(0, 6.283); rr = R * 0.95 * math.sqrt(rg.random())
        cx = math.cos(a) * rr; cy = math.sin(a) * rr
        flower = rg.random() < 0.55
        r0 = (rg.uniform(1.6, 2.6) if flower else rg.uniform(2.2, 3.4)) * R / 26.0
        ang = rg.uniform(0, math.pi)
        ex = ((dx - cx) * math.cos(ang) + (dy - cy) * math.sin(ang)) / r0
        ey = (-(dx - cx) * math.sin(ang) + (dy - cy) * math.cos(ang)) / (r0 * (0.8 if flower else 0.55))
        e = np.hypot(ex, ey)
        m = e <= 1
        if not m.any():
            continue
        nz = np.sqrt(np.clip(1 - e ** 2, 0, 1))
        s = lam((dx - cx) / r0 * 0.7, (dy - cy) / r0 * 0.7, nz)
        if flower:
            base = np.array([214, 52, 128], np.float32) * rg.uniform(0.9, 1.08)
        else:
            base = np.array([58, 112, 40], np.float32) * rg.uniform(0.85, 1.1)
        cc = base * (0.45 + 0.75 * s)[..., None]
        # bóng cụm trước đổ lên cụm sau
        img[..., :3] = np.where(m[..., None], cc, img[..., :3])
        img[..., 3] = np.where(m, 255, img[..., 3])
    a = blur(img[..., 3] / 255, 0.3 * K)
    img[..., 3] = a * 255
    return img

def to_img(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')
