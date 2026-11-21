import os
# Cờ caro v2: phản gỗ tràm có khung viền mộng góc, đinh sắt, ván lòng, kẻ phấn 15x15. Nướng 1 lần.
#   python3 board2.py K out.png
import sys, math, json
import numpy as np
from PIL import Image, ImageFilter

N = 15

def _rs(a, W, H):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), np.float32) / 255

def vnoise(H, W, cx, cy, rg):
    gh = max(3, int(H / cy) + 3); gw = max(3, int(W / cx) + 3)
    a = rg.random((gh, gw)).astype(np.float32)
    big = _rs(a, int(gw * cx), int(gh * cy))
    return big[:H, :W]

def fbm(H, W, c, octv, rg, ay=1.0):
    acc = np.zeros((H, W), np.float32); amp = 1; tot = 0
    for o in range(octv):
        cc = max(1.2, c / 2 ** o)
        acc += vnoise(H, W, cc, cc * ay, rg) * amp; tot += amp; amp *= 0.55
    return acc / tot

def wood_field(H, W, K, rg):
    """thớ gỗ chạy dọc (theo trục y). Trả (giá trị 0..1, độ rỗ)"""
    warp = (fbm(H, W, 60 * K, 2, rg) - 0.5) * 7 * K
    st = fbm(H, W, 2.4 * K, 4, rg, ay=30)            # vệt dài
    fine = fbm(H, W, 0.7 * K, 2, rg, ay=16)
    xx = np.arange(W, dtype=np.float32)[None, :] + 0 * np.zeros((H, 1), np.float32)
    rings = np.sin((xx + warp + st * 9 * K) / (3.0 * K) * math.pi + rg.uniform(0, 6))
    late = np.clip(rings, 0, 1) ** 3                   # vân muộn sậm, mảnh
    v = 0.45 * st + 0.25 * fine + 0.30 * (1 - late)
    pores = (fbm(H, W, 0.6 * K, 1, rg, ay=5) > 0.78).astype(np.float32)
    return v, late, pores

def colorize(v, late, pores, tone):
    c0 = np.array([54, 36, 25]); c1 = np.array([101, 70, 47]); c2 = np.array([146, 110, 76])
    t = np.clip(v + tone, 0, 1)[..., None]
    col = np.where(t < 0.5, c0 + (c1 - c0) * (t / 0.5), c1 + (c2 - c1) * ((t - 0.5) / 0.5))
    col = col * (1 - 0.30 * late[..., None]) + np.array([40, 24, 15]) * 0.30 * late[..., None]
    col *= (1 - 0.12 * pores[..., None])
    return col.astype(np.float32)

def board(K):
    S = 392.0          # cạnh mặt phản (css)
    FR = 15.0          # bề rộng khung viền
    TH = 12.0          # bề dày mép trước
    M = 18.0           # lề bóng
    W = int((S + 2 * M) * K); H = int((S + TH + 2 * M + 8) * K)
    ox, oy = int(M * K), int(M * K)
    s = int(S * K); fr = FR * K; th = int(TH * K)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    u = xx - ox; v = yy - oy
    rgbuf = np.random.default_rng(20261120)
    # ---------- bóng đổ xuống sân (nắng trái trên -> bóng phải dưới)
    sh = np.zeros((H, W), np.float32)
    sh[int(oy + 9 * K):int(oy + s + th + 7 * K), int(ox + 6 * K):int(ox + s + 8 * K)] = 1
    sh = np.asarray(Image.fromarray((sh * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(8 * K)), np.float32) / 255 * 0.55
    c2 = np.zeros((H, W), np.float32)
    c2[int(oy + s + th - 3 * K):int(oy + s + th + 3 * K), int(ox + 1 * K):int(ox + s + 1 * K)] = 1
    c2 = np.asarray(Image.fromarray((c2 * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.8 * K)), np.float32) / 255 * 0.6
    alpha_sh = np.clip(sh + c2, 0, 0.85)
    # ---------- vùng
    rc = 5 * K
    cu = np.clip(u, rc, s - rc); cv = np.clip(v, rc, s + th - rc)
    inside = (u >= 0) & (u < s) & (v >= 0) & (v < s + th) & (np.hypot(u - cu, v - cv) <= rc)
    top = inside & (v < s)
    front = inside & (v >= s)
    # khung: 4 thanh, mộng xéo ở góc
    dl, dr_, dt, db = u, s - u, v, s - v
    infr = top & (np.minimum.reduce([dl, dr_, dt, db]) < fr)
    # thanh nào: so khoảng cách nhỏ nhất (góc 45 độ -> mộng xéo)
    which = np.argmin(np.stack([dl, dr_, dt, db]), axis=0)   # 0 trái 1 phải 2 trên 3 dưới
    # ---------- gỗ
    col = np.zeros((H, W, 3), np.float32)
    # ván lòng: 6 tấm dọc
    planks = 6
    li = fr; lw = s - 2 * fr
    pw = lw / planks
    pid = np.clip(((u - li) / pw).astype(int), 0, planks - 1)
    for p in range(planks):
        rg = np.random.default_rng(300 + p)
        vf, late, pores = wood_field(H, W, K, rg)
        cc = colorize(vf, late, pores, rg.uniform(-0.07, 0.07))
        m = top & ~infr & (pid == p)
        col[m] = cc[m]
    # khung: thanh trái/phải thớ dọc, trên/dưới thớ ngang
    rgv = np.random.default_rng(401)
    vf, late, pores = wood_field(H, W, K, rgv)
    cv_ = colorize(vf, late, pores, 0.02)
    rgh = np.random.default_rng(402)
    vfh, lateh, poresh = wood_field(W, H, K, rgh)
    ch_ = colorize(vfh.T, lateh.T, poresh.T, 0.0)
    m = infr & (which <= 1); col[m] = cv_[m] * 0.96
    m = infr & (which >= 2); col[m] = ch_[m]
    # ---------- khối: khung cao hơn lòng ván -> bóng trong, gờ sáng ngoài
    dmin = np.minimum.reduce([dl, dr_, dt, db])
    # gờ ngoài bo tròn: trái/trên sáng, phải/dưới tối
    rim = np.exp(-(dmin / (2.0 * K)) ** 2) * top
    lightdir = np.where(which == 0, 1.0, np.where(which == 2, 0.85, np.where(which == 1, -0.55, -0.45)))
    col += (rim * 40 * lightdir)[..., None]
    # mép trong khung (cạnh vát xuống lòng): sáng ở thanh dưới/phải (hướng về nắng), tối ở trên/trái
    din = fr - dmin
    bev = np.exp(-(din / (1.3 * K)) ** 2) * infr
    bdir = np.where(which == 3, 0.9, np.where(which == 1, 0.7, np.where(which == 0, -0.6, -0.7)))
    col += (bev * 38 * bdir)[..., None]
    # bóng khung đổ vào lòng ván (phía trên & trái)
    inner = top & ~infr
    dti = (v - fr); dli = (u - fr)
    shin = (np.exp(-(np.maximum(dti, 0) / (3.0 * K))) * 0.38 + np.exp(-(np.maximum(dli, 0) / (3.0 * K))) * 0.30) * inner
    col *= (1 - shin)[..., None]
    # đường mộng xéo ở 4 góc
    for (cx0, cy0, sx, sy) in [(0, 0, 1, 1), (s, 0, -1, 1), (0, s, 1, -1), (s, s, -1, -1)]:
        a = (u - cx0) * sx; b = (v - cy0) * sy
        dd = np.abs(a - b) / math.sqrt(2)
        mm = (a < fr) & (b < fr) & (a > 0) & (b > 0) & top
        col *= (1 - 0.6 * np.exp(-(dd / (0.5 * K)) ** 2) * mm)[..., None]
    # khe giữa các ván lòng
    fu = ((u - li) / pw); near = np.round(fu)
    du = (fu - near) * pw / K
    seam = inner & (near >= 1) & (near <= planks - 1)
    col *= (1 - 0.7 * np.exp(-(du / 0.45) ** 2) * seam)[..., None]
    col += (np.exp(-((du - 0.8) / 0.45) ** 2) * seam * 16)[..., None]
    # ---------- mép trước: thớ ngang, sậm, viền sáng trên, tối dần xuống
    fy = np.clip((v - s) / max(th, 1), 0, 1)
    fcol = ch_ * (0.62 - 0.22 * fy)[..., None]
    fcol += (np.exp(-((v - s) / (0.9 * K)) ** 2) * 50)[..., None]
    col[front] = fcol[front]
    # khung chia mép trước chỗ mộng (khe đứng ở 2 đầu)
    # ---------- đinh sắt: 2 cây mỗi đầu ván trên thanh trên/dưới, 3 cây mỗi thanh hông
    nails = []
    for p in range(planks):
        cxn = li + (p + 0.5) * pw
        nails += [(cxn, fr * 0.5), (cxn, s - fr * 0.5)]
    for t in (0.2, 0.5, 0.8):
        nails += [(fr * 0.5, s * t), (s - fr * 0.5, s * t)]
    rgn = np.random.default_rng(55)
    for (nx, ny) in nails:
        nx += rgn.uniform(-1, 1) * K; ny += rgn.uniform(-0.6, 0.6) * K
        r = 1.9 * K
        dx = u - nx; dy = v - ny; d = np.hypot(dx, dy)
        m = d < r * 3.2
        # vệt gỉ loang quanh đinh
        rust = np.exp(-(d / (r * 1.8)) ** 2) * 0.45 * m
        col = col * (1 - rust[..., None]) + np.array([92, 48, 22]) * rust[..., None]
        # bóng đinh
        ds = np.hypot(dx - 0.5 * K, dy - 0.6 * K)
        col *= (1 - 0.45 * np.exp(-(ds / r) ** 4))[..., None]
        head = d < r
        nz = np.sqrt(np.clip(1 - (d / r) ** 2, 0, 1))
        lam = np.clip((-dx / r * 0.5 - dy / r * 0.6 + nz * 0.65), 0, 1)
        grain = rgn.random((H, W)).astype(np.float32) if False else 0
        hc = np.array([58, 52, 48]) + np.array([120, 108, 96]) * lam[..., None]
        hc = hc * 0.7 + np.array([110, 60, 30]) * 0.3
        col[head] = hc[head]
    # ---------- mòn, bụi phấn, lau phấn cũ
    cx, cy = ox + s / 2, oy + s / 2
    wear = np.exp(-(((xx - cx) / (0.5 * s)) ** 2 + ((yy - cy) / (0.5 * s)) ** 2))
    col *= (0.88 + 0.16 * wear)[..., None]
    rgd = np.random.default_rng(9)
    smear = np.clip((fbm(H, W, 50 * K, 3, rgd) - 0.52) * 3, 0, 1)
    dust = fbm(H, W, 1.0 * K, 2, rgd)
    a = ((0.04 + 0.11 * smear) * (0.5 + dust))[..., None] * inner[..., None]
    col = col * (1 - a) + np.array([222, 218, 206]) * a
    # vết xước nhỏ
    for i in range(70):
        x0 = rgd.uniform(fr, s - fr); y0 = rgd.uniform(fr, s - fr)
        ang = rgd.uniform(0, math.pi); ln = rgd.uniform(3, 12) * K
        ex, ey = math.cos(ang), math.sin(ang)
        px = u - x0; py = v - y0
        t = np.clip(px * ex + py * ey, 0, ln)
        dd = np.hypot(px - t * ex, py - t * ey)
        mk = (dd < 0.5 * K) & inner & (np.abs(px) < ln + 2) & (np.abs(py) < ln + 2)
        col[mk] = col[mk] * 1.12 + 6
    # ---------- lưới phấn 15x15 trong lòng ván
    pad = 5.0 * K
    gx0 = ox + fr + pad; gy0 = oy + fr + pad
    cs = (s - 2 * fr - 2 * pad) / N
    rgc = np.random.default_rng(11)
    chalkn = fbm(H, W, 0.8 * K, 2, rgc)
    wob = (fbm(H, W, 34 * K, 2, rgc) - 0.5) * 1.1 * K
    g = np.zeros((H, W), np.float32)
    lwid = 0.6 * K
    # GRID=0: không vẽ lưới (Godot kẻ lưới nét theo điểm ảnh màn)
    for i in range(N + 1 if os.environ.get("GRID", "1") != "0" else 0):
        lx = gx0 + i * cs
        g = np.maximum(g, np.exp(-((xx + wob - lx) / lwid) ** 2) * ((yy > gy0 - 1.5 * K) & (yy < gy0 + N * cs + 1.5 * K)))
        ly = gy0 + i * cs
        g = np.maximum(g, np.exp(-((yy + wob - ly) / lwid) ** 2) * ((xx > gx0 - 1.5 * K) & (xx < gx0 + N * cs + 1.5 * K)))
    bite = np.clip(0.30 + 1.0 * chalkn, 0, 1)
    ga = np.clip(g * bite * 0.70, 0, 1)[..., None] * inner[..., None]
    col = col * (1 - ga) + np.array([234, 230, 218]) * ga
    # 5 chấm sao (như bàn cờ) ở tâm và 4 góc trong
    for (r_, c_) in [(7, 7), (3, 3), (3, 11), (11, 3), (11, 11)]:
        px = gx0 + c_ * cs + cs / 2; py = gy0 + r_ * cs + cs / 2
        d = np.hypot(xx - px, yy - py)
        dm = np.exp(-(d / (1.1 * K)) ** 4) * (0.35 + 0.5 * chalkn) * 0.55
        col = col * (1 - dm[..., None]) + np.array([234, 230, 218]) * dm[..., None]
    # ---------- ghép
    out = np.zeros((H, W, 4), np.float32)
    out[..., :3] = np.where(inside[..., None], np.clip(col, 0, 255), 0)
    out[..., 3] = np.where(inside, 1.0, alpha_sh)
    meta = dict(K=K, S=S, FR=FR, TH=TH, M=M, cs=cs / K, gx0=gx0 / K, gy0=gy0 / K, w=W / K, h=H / K)
    return out, meta

if __name__ == '__main__':
    K = float(sys.argv[1]); o = sys.argv[2]
    a, meta = board(K)
    Image.fromarray(np.dstack([a[..., :3], a[..., 3] * 255]).astype(np.uint8), 'RGBA').save(o)
    print(json.dumps(meta))
