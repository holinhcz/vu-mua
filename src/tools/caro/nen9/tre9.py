# Bụi tre nhìn từ trên xuống, vẽ từng điểm ảnh (9px/đơn vị css). Thân tre ngả ra ngoài, đốt, cành nhỏ, chùm lá tre hẹp nhọn.
import math, numpy as np
import props as P, board2 as B

def _win(dst, K, x0, y0, x1, y1, pad):
    H, W = dst.shape[:2]
    bx0 = max(int((min(x0, x1) - pad) * K), 0); by0 = max(int((min(y0, y1) - pad) * K), 0)
    bx1 = min(int((max(x0, x1) + pad) * K) + 1, W); by1 = min(int((max(y0, y1) + pad) * K) + 1, H)
    if bx1 <= bx0 or by1 <= by0: return None
    yy, xx = np.mgrid[by0:by1, bx0:bx1].astype(np.float32)
    return bx0, by0, xx / K, yy / K

def _put(dst, bx0, by0, col, a, shadow=0.0, sdx=0, sdy=0, sblur=1.0):
    h, w = a.shape
    if shadow > 0:
        sh = P.blur(a, sblur)
        sub = dst[by0:by0 + h, bx0:bx0 + w]
        sh = np.roll(np.roll(sh, sdy, 0), sdx, 1)
        sub[..., :3] *= (1 - shadow * sh * (sub[..., 3] > 0) * (1 - a))[..., None]
    P.over(dst, P.rgba(col, a), bx0, by0)

def culm(dst, K, x0, y0, x1, y1, w0, w1, base, rg, node=9.0):
    r = _win(dst, K, x0, y0, x1, y1, max(w0, w1) + 1)
    if r is None: return
    bx0, by0, X, Y = r
    dx, dy = x1 - x0, y1 - y0; ln = max(math.hypot(dx, dy), 1e-3); ux, uy = dx / ln, dy / ln
    along = (X - x0) * ux + (Y - y0) * uy
    t = np.clip(along / ln, 0, 1)
    v = (X - (x0 + t * dx)) * (-uy) + (Y - (y0 + t * dy)) * ux
    hw = (w0 + (w1 - w0) * t) / 2
    s = v / np.maximum(hw, 1e-3)
    m = (np.abs(s) <= 1) & (along >= 0) & (along <= ln)
    if not m.any(): return
    nz = np.sqrt(np.clip(1 - s ** 2, 0, 1))
    lam = P.lam(-uy * s, ux * s, nz)
    ph = rg.uniform(0, node)
    q = np.mod(along + ph, node)
    ring = np.exp(-((q - 0.35) / 0.32) ** 2)                     # đốt tre: vòng sẫm + gờ sáng
    ridge = np.exp(-((q - 0.85) / 0.25) ** 2)
    grain = 0.5 + 0.5 * np.sin(s * 9 + along * 0.15)
    tone = 0.92 + 0.12 * np.clip(t, 0, 1)
    col = np.array(base, np.float32) * (0.32 + 0.85 * lam)[..., None] * (0.94 + 0.08 * grain)[..., None] * tone[..., None]
    col = col * (1 - 0.42 * ring[..., None]) + np.array([235, 232, 170]) * 0.28 * ridge[..., None] * lam[..., None]
    a = np.clip((1 - np.abs(s)) * hw * K * 0.9, 0, 1) * m * np.clip(along * K * 0.5, 0, 1)
    _put(dst, bx0, by0, col, a, 0.35, int(2.5 * K), int(3 * K), 1.2 * K)

def leaf(dst, K, x, y, ang, ln, wd, gcol, light, rg):
    ca, sa = math.cos(ang), math.sin(ang)
    r = _win(dst, K, x, y, x + ca * ln, y + sa * ln, wd + 2)
    if r is None: return
    bx0, by0, X, Y = r
    u = (X - x) * ca + (Y - y) * sa; v = -(X - x) * sa + (Y - y) * ca
    bend = rg.uniform(-0.012, 0.012) * u ** 2 / max(ln / 14, 0.5)
    v2 = v - bend
    t = u / ln
    prof = np.where(t < 0.12, (np.clip(t, 0, 1) / 0.12) ** 0.6, np.clip((1 - t) / 0.88, 0, 1) ** 0.75)  # gốc tròn, ngọn nhọn dài
    half = wd / 2 * prof
    m = (t >= 0) & (t <= 1) & (np.abs(v2) <= half)
    if not m.any(): return
    s = np.where(half > 0, v2 / np.maximum(half, 1e-3), 0)
    droop = np.clip(t - 0.4, 0, 1) * 0.7
    fold = s * 0.45                                             # lá gập nhẹ theo gân giữa
    nx = -sa * fold + ca * droop; ny = ca * fold + sa * droop
    nz = np.sqrt(np.clip(1 - nx ** 2 - ny ** 2, 0, 1))
    lam = P.lam(nx, ny, nz)
    vein = np.exp(-(v2 / 0.28) ** 2) * (t > 0.05)
    par = 0.5 + 0.5 * np.sin(v2 / max(wd, 0.5) * 22)             # gân song song
    col = np.array(gcol, np.float32) * (0.42 + 0.72 * lam)[..., None] * light * (0.95 + 0.06 * par)[..., None]
    col = col * (1 - 0.3 * vein[..., None]) + np.array([214, 222, 150]) * 0.3 * vein[..., None] * lam[..., None]
    edge = np.clip((np.abs(s) - 0.78) * 4.5, 0, 1)               # viền mảnh cùng màu lá (đậm hơn ~0.8)
    col = col * (1 - 0.2 * edge[..., None])
    dry = np.clip((t - 0.9) * 10, 0, 1) * rg.uniform(0, 0.6)     # chót lá hơi khô
    col = col * (1 - dry[..., None]) + np.array([170, 150, 80]) * (0.5 + 0.6 * lam)[..., None] * dry[..., None]
    a = np.clip((half - np.abs(v2)) * K * 1.1, 0, 1) * m
    _put(dst, bx0, by0, col, a, 0.33, int(2.2 * K), int(2.8 * K), 0.9 * K)

def twig(dst, K, x0, y0, x1, y1, w, rg):
    culm(dst, K, x0, y0, x1, y1, w, w * 0.6, (128, 128, 62), rg, node=6.0)

def bamboo(K, R=170.0, seed=3, ncul=22, dens=1.0, crop=None, base=1.0):
    """bụi tre gai nhìn từ trên: gốc ở giữa, thân ngả toả ra, ngọn rủ lá dày"""
    rg = np.random.default_rng(seed)
    n = int(R * (2.0 if crop is not None else 2.3) * K); c = n / 2 / K
    nw = n if crop is None else int((c + crop * R) * K)          # crop: chỉ giữ nửa trái (nửa phải luôn khuất ngoài màn)
    xmax = nw / K + 25
    out = np.zeros((n, nw, 4), np.float32)
    # gốc bụi: đất sẫm + bẹ mo khô
    yy, xx = np.mgrid[0:n, 0:nw].astype(np.float32)
    d = np.hypot(xx / K - c, yy / K - c) / (R * 0.2 * base)
    nz = B.fbm(n, nw, 1.5 * K, 2, rg)
    gm = np.clip((1.2 - d + 0.3 * (nz - 0.5)) * 9, 0, 1)
    P.over(out, P.rgba(np.array([70, 58, 36], np.float32) * (0.55 + 0.5 * nz)[..., None], gm * 0.9))
    del xx, yy, d
    for i in range(int(70 * (R * base / 170) ** 2)):                                         # lá tre khô rụng quanh gốc
        a_ = rg.uniform(0, 6.283); r_ = R * 0.24 * base * math.sqrt(rg.uniform(0, 1))
        dc = (np.array([176, 148, 92], np.float32) * rg.uniform(0.7, 1.1)).tolist()
        leaf(out, K, c + math.cos(a_) * r_, c + math.sin(a_) * r_, rg.uniform(0, 6.283), rg.uniform(9, 14), rg.uniform(1.8, 2.4), dc, rg.uniform(0.75, 0.95), rg)
    cul = []
    a0 = rg.uniform(0, 6.283)
    for i in range(ncul):
        ang = a0 + i / ncul * 6.283 + rg.uniform(-0.12, 0.12)
        r0 = R * base * rg.uniform(0.05, 0.17)
        aa = ang + rg.uniform(-0.9, 0.9); bx = c + math.cos(aa) * r0; by = c + math.sin(aa) * r0
        L = R * rg.uniform(0.55, 0.85)
        bend = rg.uniform(-0.35, 0.35)
        pts = [(bx, by)]
        for k in range(1, 7):
            a_ = ang + bend * k / 6
            px, py = pts[-1]; seg = L / 6 * (1.15 - 0.05 * k)
            pts.append((px + math.cos(a_) * seg, py + math.sin(a_) * seg))
        cul.append((ang, bend, pts, rg.uniform(3.4, 4.4) * (R / 170) ** 0.3))
    for ang, bend, pts, w in cul:
        for k in range(5):
            (x0, y0), (x1, y1) = pts[k], pts[k + 1]
            culm(out, K, x0, y0, x1, y1, w * (1 - 0.13 * k), w * (1 - 0.13 * (k + 1)), [150, 158, 72], rg)
        x0, y0 = pts[0]                                         # gốc thân đứng: nhìn từ trên thành khoanh tròn
        rr = w * 0.62; r = _win(out, K, x0, y0, x0, y0, rr + 1)
        if r is not None:
            bx0, by0, X, Y = r
            q = np.hypot(X - x0, Y - y0) / rr
            nx_ = (X - x0) / rr; ny_ = (Y - y0) / rr; nz_ = np.sqrt(np.clip(1 - q ** 2, 0, 1))
            lam = P.lam(nx_ * 0.8, ny_ * 0.8, nz_)
            col = np.array([128, 136, 62], np.float32) * (0.35 + 0.8 * lam)[..., None]
            col = col * (1 - 0.35 * np.exp(-((q - 0.72) / 0.12) ** 2))[..., None]
            _put(out, bx0, by0, col, np.clip((1 - q) * rr * K, 0, 1), 0.35, int(2 * K), int(2.5 * K), 1.0 * K)
    pal = [[84, 134, 48], [100, 148, 54], [118, 160, 60], [72, 118, 44], [140, 166, 66], [170, 156, 66]]
    pp = np.array([1, 1, 0.8, 0.7, 0.3, 0.08]); pp = pp / pp.sum()
    # chùm lá dọc thân (từ 28% ra ngọn) + chùm lấp khe giữa các thân
    cl = []
    for ang, bend, pts, w in cul:
        for j in range(int(rg.integers(22, 30) * dens * R / 170)):
            f = rg.uniform(0.2, 1.04) ** 0.8
            kk = min(int(f * 6), 5); ft = f * 6 - kk
            (x0, y0), (x1, y1) = pts[kk], pts[kk + 1]
            sx = x0 + (x1 - x0) * ft; sy = y0 + (y1 - y0) * ft
            ca = ang + bend * f + rg.choice([-1, 1]) * rg.uniform(0.35, 1.3)
            cl.append((sx, sy, ca, f))
    for i in range(int(ncul * 8 * dens * (R / 170) ** 2)):
        a_ = rg.uniform(0, 6.283); r_ = R * rg.uniform(0.17, 0.8) ** 0.9
        cl.append((c + math.cos(a_) * r_, c + math.sin(a_) * r_, a_ + rg.uniform(-0.8, 0.8), r_ / R))
    items = []
    for sx, sy, ca, f in cl:
        r = math.hypot(sx - c, sy - c) / R
        h = float(np.clip(1 - (abs(r - 0.38) / 0.55) ** 1.6 + rg.uniform(-0.35, 0.35), 0, 1))  # vòm tán: cao ở giữa, rủ ra mép
        items.append((h, sx, sy, ca, f))
    items.sort()
    for h, sx, sy, ca, f in items:
        if sx > xmax: continue
        light = 0.48 + 0.64 * h
        tl = rg.uniform(4, 9)
        ex = sx + math.cos(ca) * tl; ey = sy + math.sin(ca) * tl
        twig(out, K, sx, sy, ex, ey, 0.8, rg)
        kind = rg.choice(6, p=pp); gcol = (np.array(pal[kind], np.float32) * rg.uniform(0.9, 1.1)).tolist()
        for q in range(rg.integers(5, 9)):
            la = ca + rg.uniform(-1.0, 1.0)
            leaf(out, K, ex + rg.normal(0, 1.4), ey + rg.normal(0, 1.4), la, rg.uniform(11, 17), rg.uniform(2.0, 2.8), gcol, light * rg.uniform(0.92, 1.08), rg)
    # măng non nhú gần gốc
    for i in range(3):
        a_ = rg.uniform(0, 6.283); r_ = R * base * rg.uniform(0.12, 0.2)
        mx = c + math.cos(a_) * r_; my = c + math.sin(a_) * r_
        culm(out, K, mx, my, mx + math.cos(a_) * 5, my + math.sin(a_) * 5, 4.2, 1.2, (150, 120, 64), rg, node=2.2)
    return out

if __name__ == '__main__':
    import sys
    K = float(sys.argv[1]) if len(sys.argv) > 1 else 4
    a = bamboo(K)
    P.to_img(a).save(sys.argv[2] if len(sys.argv) > 2 else '/tmp/claude-0/tre_prev.png')
