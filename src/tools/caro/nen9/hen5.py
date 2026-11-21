# GÀ MÁI v5 (vẽ mới): nhìn từ trên xuống, dựng bằng bản đồ độ cao (thân bầu, cánh xếp, cổ lông vàng, đầu mào đỏ, đuôi đen ánh xanh)
# chiếu sáng theo pháp tuyến, lông vảy/sọc cánh/lông cổ là hoạ tiết theo từng điểm ảnh.
import math, numpy as np
import props as P, board2 as B

def hen5(K, s=1.0, seed=0, ang=0.0):
    rg = np.random.default_rng(seed)
    L_ = 60 * s
    n = int(L_ * 2.0 * K) | 1; c = n / 2
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    X = (xx - c) / K / s; Y = (yy - c) / K / s          # đơn vị gà (thân dài ~60)
    ca, sa = math.cos(ang), math.sin(ang)
    U = X * ca + Y * sa; V = -X * sa + Y * ca
    parts = []   # (tên, chiều cao, phủ)
    def ell(cu, cv, ra, rb, hz, rot=0.0, lift=0.0):
        cr, sr = math.cos(rot), math.sin(rot)
        u = (U - cu) * cr + (V - cv) * sr; v = -(U - cu) * sr + (V - cv) * cr
        e2 = (u / ra) ** 2 + (v / rb) ** 2
        h = np.sqrt(np.clip(1 - e2, 0, 1)) * hz + lift
        return np.where(e2 < 1, h, -1.0), e2, u, v
    # thân: bầu dục, đuôi rộng hơn đầu
    rbody = 19.5 * (1 + 0.12 * np.clip(-(U + 2) / 30, -1, 1))
    eb2 = ((U + 2) / 30) ** 2 + (V / rbody) ** 2
    hb = np.where(eb2 < 1, np.sqrt(np.clip(1 - eb2, 0, 1)) * 15, -1.0)
    hw = [ell(-5, sd * 10.5, 22, 9.5, 5, rot=sd * 0.12, lift=10.5) for sd in (-1, 1)]
    hn, en2, nu, nv = ell(19, 0, 10.5, 9.5, 8, lift=8)
    hh, eh2, hu, hv = ell(28.5, 0, 6.8, 5.6, 6, lift=12)
    ht, et2, tu, tv = ell(-35, 0, 13, 4.2, 9, lift=10)
    names = ['body', 'wL', 'wR', 'neck', 'head', 'tail']
    H = np.stack([hb, hw[0][0], hw[1][0], hn, hh, ht])
    top = np.argmax(H, 0); h = np.max(H, 0)
    cover = h > -0.5
    # pháp tuyến từ bản đồ độ cao (mượt)
    hs_ = P.blur(np.where(cover, h, 0).astype(np.float32) / 30.0, 0.8 * K * s) * 30.0 * K * s
    gy, gx = np.gradient(hs_)
    nx = -gx; ny = -gy; nz = np.ones_like(nx) * 1.0
    nl = np.sqrt(nx * nx + ny * ny + nz * nz); nx /= nl; ny /= nl; nz /= nl
    Lv = np.array([-0.5, -0.62, 0.6]); Lv /= np.linalg.norm(Lv)
    lam = np.clip(nx * Lv[0] + ny * Lv[1] + nz * Lv[2], 0, 1)
    shade = 0.38 + 0.85 * lam
    fine = B.fbm(n, n, 0.6 * K * s, 2, rg); mid = B.fbm(n, n, 4 * K * s, 2, rg)
    col = np.zeros((n, n, 3), np.float32)
    # --- thân: lông vảy so le, mép vảy sẫm
    row = np.floor(U / 3.0); off = (row % 2) * 1.6
    du = U - (row + 0.5) * 3.0; dv = (V + off) - np.round((V + off) / 3.2) * 3.2
    dd = np.sqrt((du * 1.15) ** 2 + dv ** 2) / 1.9
    scal = np.clip((dd - 0.72) * 4, 0, 1) * (du < 0.6)
    body = np.array([168, 84, 40], np.float32) * (0.9 + 0.16 * mid)[..., None]
    body = body * (1 - 0.28 * scal)[..., None] * (1 + 0.08 * (1 - dd))[..., None]
    # bụng/hông tối dần ra mép
    body *= (1 - 0.25 * np.clip(eb2 - 0.55, 0, 1))[..., None]
    col = np.where((top == 0)[..., None], body, col)
    # --- cánh: lông che trên + lông bay dài sẫm phía sau, sọc theo chiều dài
    for i, (hp, e2, wu, wv) in enumerate(hw):
        m = top == 1 + i
        rowc = np.sin(wv * 2 * math.pi / 2.1 + wu * 0.08) * 0.5 + 0.5
        prim = np.clip((-wu - 6) / 10, 0, 1)                 # nửa sau cánh = lông bay
        cw = np.array([132, 62, 30], np.float32) * (1 - prim * 0.45)[..., None] + np.array([40, 26, 18], np.float32) * (prim * 0.45)[..., None]
        cw = cw * (0.82 + 0.25 * rowc)[..., None] * (0.92 + 0.12 * fine)[..., None]
        # vảy nhỏ phần vai (trước cánh)
        sc2 = np.clip((np.abs(np.sin(wu * 1.9) * np.sin(wv * 1.7)) - 0.75) * 4, 0, 1) * (1 - prim)
        cw *= (1 - 0.18 * sc2)[..., None]
        col = np.where(m[..., None], cw, col)
    # --- cổ: lông bờm vàng cam toả từ đầu ra
    a = np.arctan2(nv, nu - 9)
    streak = np.sin(a * 22 + np.sqrt((nu - 9) ** 2 + nv ** 2) * 0.6) * 0.5 + 0.5
    cn = np.array([222, 150, 64], np.float32) * (0.8 + 0.3 * streak)[..., None] * (0.92 + 0.12 * fine)[..., None]
    cn *= (1 - 0.3 * np.clip(-(nu) / 9, 0, 1))[..., None]      # gốc cổ sẫm dần vào thân
    col = np.where((top == 3)[..., None], cn, col)
    # --- đầu
    chd = np.array([176, 82, 40], np.float32) * (0.95 + 0.1 * fine)[..., None]
    col = np.where((top == 4)[..., None], chd, col)
    # --- đuôi: đen ánh xanh, gân lông dọc
    tf = np.sin(tv * 2 * math.pi / 1.6) * 0.5 + 0.5
    ct = np.array([30, 40, 36], np.float32) * (0.8 + 0.35 * tf)[..., None]
    col = np.where((top == 5)[..., None], ct, col)
    col = col * shade[..., None]
    # ánh xanh bóng trên đuôi
    spec = lam ** 14 * (top == 5)
    col += np.array([40, 110, 80], np.float32) * spec[..., None]
    alpha = np.clip(h * 0 + 1, 0, 1) * cover
    # viền mềm 1 điểm ảnh
    alpha = P.blur(cover.astype(np.float32), 0.35 * K * s)
    img = np.dstack([col, alpha * 255])
    # --- mào đỏ răng cưa dọc giữa đỉnh đầu
    def blob(mask_f, colr, z=1.0):
        a_ = np.clip(mask_f, 0, 1)
        cc = np.array(colr, np.float32)[None, None, :] * (0.55 + 0.6 * lam)[..., None]
        P.over(img, P.rgba(cc, a_))
    cu = U - 28.5
    cw_ = 1.3 + 0.5 * (np.sin(cu * 3.2) > 0)
    comb = np.clip((cw_ - np.abs(V)) * 2.0 * K * s / 4, 0, 1) * ((cu > -4.5) & (cu < 4.0))
    blob(comb, (214, 44, 38))
    # mỏ vàng nhọn
    bu = U - 34.0
    beak = np.clip((1.8 * (1 - bu / 4.5) - np.abs(V)) * K * s / 2, 0, 1) * ((bu > -1.0) & (bu < 4.5))
    blob(beak, (230, 186, 70))
    # tích đỏ nhỏ dưới mỏ hai bên
    for sd in (-1, 1):
        e = np.hypot((U - 31.5) / 1.6, (V - sd * 2.6) / 1.2)
        blob(np.clip((1 - e) * 4, 0, 1), (200, 46, 40))
    # mắt: tròng vàng + con ngươi đen + chấm sáng
    for sd in (-1, 1):
        e = np.hypot(U - 30.2, V - sd * 4.6)
        P.over(img, P.rgba(np.zeros((n, n, 3)) + np.array([230, 170, 60]), np.clip((1.15 - e) * K * s * 0.8, 0, 1)))
        P.over(img, P.rgba(np.zeros((n, n, 3)) + np.array([14, 10, 8]), np.clip((0.7 - e) * K * s * 0.8, 0, 1)))
        e2 = np.hypot(U - 30.4, V - sd * 4.6 + 0.25)
        P.over(img, P.rgba(np.zeros((n, n, 3)) + 255, np.clip((0.22 - e2) * K * s * 1.2, 0, 1) * 0.9))
    return img
