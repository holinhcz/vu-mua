# GÀ MÁI v5 (vẽ mới): nhìn từ trên xuống. Thân bầu (độ cao mượt, không vằn), phủ TỪNG CHIẾC LÔNG xếp ngói:
# đuôi xoè đen ánh xanh -> lông lưng -> cánh (lông bay, lông thứ, lông phủ) -> bờm cổ vàng -> đầu, mào, mỏ, mắt.
# Mỗi lông có pháp tuyến riêng (cong ngang), mép sẫm, cọng sáng, đổ bóng xuống lớp dưới (nắng trái-trên).
import math, numpy as np
import props as P, board2 as B

Lv = P.L

def fblur(a, r):
    """làm mờ float (3 lần box) - không vằn như blur uint8"""
    r = int(max(1, round(r)))
    out = a.astype(np.float32)
    for ax in (0, 1):
        for _ in range(3):
            pad = [(0, 0), (0, 0)]; pad[ax] = (r + 1, r)
            c = np.cumsum(np.pad(out, pad, mode='edge'), axis=ax)
            if ax == 0: out = (c[2 * r + 1:] - c[:-2 * r - 1]) / (2 * r + 1)
            else: out = (c[:, 2 * r + 1:] - c[:, :-2 * r - 1]) / (2 * r + 1)
    return out

def hen5(K, s=1.0, seed=0, ang=0.0):
    rg = np.random.default_rng(seed)
    L_ = 60 * s
    n = int(L_ * 2.0 * K) | 1; c = n / 2
    ks = K * s                                     # điểm ảnh / đơn vị gà
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    X = (xx - c) / ks; Y = (yy - c) / ks
    ca, sa = math.cos(ang), math.sin(ang)
    U = X * ca + Y * sa; V = -X * sa + Y * ca
    fine = B.fbm(n, n, 0.5 * ks, 2, rg)
    col = np.zeros((n, n, 3), np.float32); A = np.zeros((n, n), np.float32)

    def to_px(u, v):
        x = u * ca - v * sa; y = u * sa + v * ca
        return c + x * ks, c + y * ks

    # ---- thân nền: bầu dục, đuôi rộng, hợp mượt với cổ + đầu
    rb = 15.0 * (1 + 0.1 * np.clip(-(U + 2) / 28, -1, 1))
    hb = np.sqrt(np.clip(1 - ((U + 1) / 25) ** 2 - (V / rb) ** 2, 0, 1)) * 16
    hn = np.sqrt(np.clip(1 - ((U - 18) / 9) ** 2 - (V / 8) ** 2, 0, 1)) * 10 + 7
    hn = np.where(hn > 7.01, hn, 0)
    hh = np.sqrt(np.clip(1 - ((U - 28) / 6.6) ** 2 - (V / 5.6) ** 2, 0, 1)) * 6 + 12
    hh = np.where(hh > 12.01, hh, 0)
    H = np.maximum(np.maximum(hb, hn), hh)
    cov = (H > 0).astype(np.float32)
    Hs = fblur(H, 0.9 * ks)
    gy, gx = np.gradient(Hs * ks / 3.0 / ks)
    nx, ny, nz = -gx, -gy, np.ones_like(gx)
    nl = np.sqrt(nx * nx + ny * ny + nz * nz); nx /= nl; ny /= nl; nz /= nl
    lamb = P.lam(nx, ny, nz)
    base = np.array([150, 72, 34], np.float32) * (0.9 + 0.15 * fine)[..., None]
    col[:] = base * (0.4 + 0.8 * lamb)[..., None]
    A[:] = np.clip((fblur(cov, 1.6 * ks) - 0.62) * 6, 0, 1)   # nền thân co vào trong, mép do lông tạo

    gsh = 0.5 + 0.75 * lamb
    sx, sy = 0.55 * ks, 0.62 * ks                  # hướng bóng đổ (px / đơn vị cao)

    def feather(u0, v0, fa, ln, wd, cl, edge=0.22, shaft=0.15, lift=1.0, sheen=None, tipc=None, sh=0.32, rootf=0.35):
        # u0,v0: gốc lông; fa: góc (đơn vị gà) từ gốc ra ngọn; ln dài, wd nửa rộng
        fa = fa + rg.uniform(-0.12, 0.12)
        du, dv = math.cos(fa), math.sin(fa)
        cu, cv = u0 + du * ln * 0.5, v0 + dv * ln * 0.5
        px_, py_ = to_px(cu, cv)
        R = int((ln * 0.55 + wd + 2) * ks) + 2
        x0, x1 = max(0, int(px_) - R), min(n, int(px_) + R + int(lift * sx) + 2)
        y0, y1 = max(0, int(py_) - R), min(n, int(py_) + R + int(lift * sy) + 2)
        if x1 <= x0 or y1 <= y0: return
        uu = U[y0:y1, x0:x1] - u0; vv = V[y0:y1, x0:x1] - v0
        s_ = uu * du + vv * dv; t_ = -uu * dv + vv * du
        hl = ln * 0.5
        q = ((s_ - hl) / hl) ** 2 + (t_ / wd) ** 2
        # đầu lông tròn, gốc thon
        q = q + 0.35 * np.clip(1 - s_ / ln * 2, 0, 1) * (t_ / wd) ** 2
        q = q + 0.9 * np.clip((s_ - hl) / hl, 0, 1) ** 2 * (t_ / wd) ** 2   # ngọn hơi nhọn
        m = np.clip((1 - q) * wd * ks * 0.9, 0, 1)
        m = m * np.clip(s_ / (rootf * ln), 0, 1) ** 1.5   # gốc lông chìm dưới lớp trên, chỉ thấy ngọn
        # bóng đổ xuống lớp dưới
        shx, shy = lift * sx, lift * sy
        Uw = U[y0:y1, x0:x1]; Vw = V[y0:y1, x0:x1]
        # mặt nạ lệch theo px: dùng toạ độ lệch
        Xo = (xx[y0:y1, x0:x1] - shx - c) / ks; Yo = (yy[y0:y1, x0:x1] - shy - c) / ks
        uo = Xo * ca + Yo * sa - u0; vo = -Xo * sa + Yo * ca - v0
        so = uo * du + vo * dv; to = -uo * dv + vo * du
        qo = ((so - hl) / hl) ** 2 + (to / wd) ** 2
        ms = np.clip((1 - qo) * 2.2, 0, 1) * np.clip(so / (rootf * ln), 0, 1)
        col[y0:y1, x0:x1] *= (1 - sh * ms * (1 - m))[..., None]
        # pháp tuyến: cong ngang (trụ) + vồng dọc nhẹ
        tn = np.clip(t_ / wd, -1, 1) * 0.4
        sn = np.clip((s_ - hl) / hl, -1, 1) * 0.3
        nu_ = du * sn - dv * tn; nv_ = dv * sn + du * tn
        nxw = nu_ * ca - nv_ * sa; nyw = nu_ * sa + nv_ * ca
        nzw = np.sqrt(np.clip(1 - nxw ** 2 - nyw ** 2, 0.05, 1))
        lm = P.lam(nxw, nyw, nzw)
        cc = np.array(cl, np.float32)
        if tipc is not None:
            tw = np.clip((s_ / ln - 0.55) * 2.2, 0, 1)[..., None]
            cc = cc * (1 - tw) + np.array(tipc, np.float32) * tw
        f = cc * (0.7 + 0.4 * lm)[..., None] * gsh[y0:y1, x0:x1][..., None] * (0.94 + 0.1 * fine[y0:y1, x0:x1])[..., None]
        # mép lông sẫm + cọng giữa sáng
        rim = np.clip((q - (1 - edge)) / edge, 0, 1)
        f *= (1 - 0.3 * rim)[..., None]
        sf = np.clip(1 - np.abs(t_) / (shaft * wd + 0.12), 0, 1) * (s_ < ln * 0.85)
        f += (sf * 22)[..., None]
        barb = np.sin((np.abs(t_) * 1.0 - s_ * 0.55) * 2 * math.pi / 0.85) * 0.5 + 0.5
        f *= (0.93 + 0.1 * barb)[..., None]
        if sheen is not None:
            sp = lm ** 10
            f += np.array(sheen, np.float32) * sp[..., None]
        col[y0:y1, x0:x1] = col[y0:y1, x0:x1] * (1 - m[..., None]) + f * m[..., None]
        A[y0:y1, x0:x1] = np.maximum(A[y0:y1, x0:x1], m)

    J = lambda a: a * rg.uniform(0.9, 1.1)
    brown = (184, 100, 46); dark = (92, 44, 22)
    # ---- ĐUÔI: 9 lông xoè, đen ánh xanh, gốc dưới lông lưng
    for i in range(9):
        t = (i - 4) / 4.0
        fa = math.pi + t * 0.42
        feather(-20, t * 3.0, fa, J(23 - abs(t) * 5), J(2.6), (30, 38, 34), lift=1.6, sheen=(40, 120, 90), sh=0.4)
    # ---- LÔNG SƯỜN: vòng lông quanh mép thân (cho mép gà rõ, không lộ nền mờ)
    for sd in (-1, 1):
        for ph in np.linspace(0.75, 2.75, 9)[::-1]:
            u0 = -1 + 23 * math.cos(ph); v0 = sd * 13.5 * math.sin(ph)
            fa = math.atan2(sd * math.sin(ph) * 0.5, -1.0)
            feather(u0 + 3, v0, fa, J(9), J(3.4), (150, 70, 32), tipc=(110, 50, 24), lift=0.4, sh=0.12, edge=0.14)
    # ---- LÔNG LƯNG (yên): vảy lớn xếp ngói giữa hai cánh, từ sau ra trước
    for k_, ru in enumerate(np.arange(-20, 12, 3.6)):
        wv = 8 * math.sqrt(max(0.0, 1 - ((ru + 4) / 20) ** 2)) + 2
        for vv in np.arange(-wv, wv + 0.01, 4.2):
            v_ = vv + (2.1 if k_ % 2 else 0) + rg.uniform(-0.3, 0.3)
            if abs(v_) > wv + 0.5: continue
            feather(ru + 3.5 + rg.uniform(-0.6, 0.6), v_, math.pi - v_ * 0.04, J(9), J(3.1), brown, tipc=(140, 66, 30), lift=0.4, sh=0.14, edge=0.14)
    # ---- CÁNH (2 bên): lông bay dài -> lông thứ -> lông phủ 3 hàng (vai)
    for sd in (-1, 1):
        for i in range(6):                         # lông bay (ngoài cùng, dưới cùng)
            u0 = 2 - i * 1.6; v0 = sd * (13.5 - i * 0.5)
            feather(u0, v0, math.pi - sd * (0.06 + i * 0.015), J(24 - i * 0.8), J(2.8), (70, 36, 20), tipc=(40, 24, 16), lift=1.2)
        for i in range(7):                         # lông thứ
            u0 = 5 - i * 1.4; v0 = sd * (12.5 - i * 0.9)
            feather(u0, v0, math.pi - sd * (0.1 + i * 0.02), J(17), J(3.1), (116, 52, 24), tipc=(56, 28, 16), lift=1.2, sh=0.36)
        for r, (ru, ln, wd, cnt) in enumerate([(0.0, 12, 3.6, 4), (4.5, 10, 3.4, 4), (9.0, 8, 3.2, 3)]):
            for i in range(cnt):                   # lông phủ vai: vảy lớn nâu đỏ
                v0 = sd * (7.0 + i * 2.3 + r * 0.4)
                feather(ru - i * 0.8, v0, math.pi - sd * 0.1, J(ln), J(wd), (150, 64, 30), tipc=(96, 42, 20), lift=0.8, sh=0.3, edge=0.16)
    # ---- BỜM CỔ: lông dài nhọn vàng cam toả về sau phủ vai, sọc sẫm giữa
    for row, (ru, ln, spr, cnt) in enumerate([(26.0, 17.0, 0.85, 15), (27.0, 13.5, 0.8, 13), (27.5, 10.0, 0.7, 11)]):
        for i in range(cnt):
            t = (i / (cnt - 1)) * 2 - 1
            fa = math.pi + t * spr
            feather(ru + rg.uniform(-0.4, 0.4), t * (3.0 - row * 0.5), fa, J(ln), J(1.45), (224, 150, 60), tipc=(206, 120, 44),
                    edge=0.3, shaft=0.4, lift=0.7, sh=0.22, rootf=0.15)
    # ---- ĐẦU (lông ngắn nâu đỏ, tròn)
    e = ((U - 28.8) / 6.2) ** 2 + (V / 5.2) ** 2
    mh = np.clip((1 - e) * 5.2 * ks * 0.5, 0, 1)
    hz = np.sqrt(np.clip(1 - e, 0, 1))
    hnx = np.clip((U - 28.8) / 6.2, -1, 1) * 0.8; hnv = np.clip(V / 5.2, -1, 1) * 0.8
    hxw = hnx * ca - hnv * sa; hyw = hnx * sa + hnv * ca
    hl_ = P.lam(hxw, hyw, np.sqrt(np.clip(1 - hxw ** 2 - hyw ** 2, 0.05, 1)))
    ch = np.array([178, 84, 40], np.float32) * (0.45 + 0.75 * hl_)[..., None] * (0.95 + 0.1 * fine)[..., None]
    col[:] = col * (1 - mh[..., None]) + ch * mh[..., None]; A[:] = np.maximum(A, mh)
    img = np.dstack([col, np.clip(A, 0, 1) * 255]).astype(np.float32)

    def blob(a_, colr, lit=True):
        cc = np.array(colr, np.float32)[None, None, :] * ((0.55 + 0.6 * hl_)[..., None] if lit else 1)
        P.over(img, P.rgba(cc * np.ones((n, n, 1), np.float32), np.clip(a_, 0, 1)))
    # mào đỏ răng cưa dọc giữa đỉnh đầu (5 răng tròn)
    for i in range(5):                             # mào: 5 thuỳ tròn nổi, mỗi thuỳ tự chiếu sáng
        cu_ = 25.4 + i * 1.55
        r_ = 1.25 + 0.5 * math.sin(i / 4 * math.pi)
        lu = (U - cu_) / r_; lv = V / (r_ * 0.95)
        ee = lu ** 2 + lv ** 2
        mz = np.sqrt(np.clip(1 - ee, 0, 1))
        xw = lu * ca - lv * sa; yw = lu * sa + lv * ca
        ll = P.lam(xw * 0.8, yw * 0.8, np.maximum(mz, 0.2))
        a_ = np.clip((1 - ee) * r_ * ks * 0.7, 0, 1)
        sp = np.clip(1 - np.hypot(lu + 0.35, lv + 0.35) / 0.35, 0, 1) ** 2
        cc = np.array([222, 44, 38], np.float32) * (0.45 + 0.7 * ll)[..., None] + (sp * 70)[..., None]
        # bóng thuỳ đổ lên đầu
        P.over(img, P.rgba(np.zeros((n, n, 3)) + np.array([70, 24, 14]), np.clip((1 - ((U - cu_ + 0.4) / r_) ** 2 - ((V - 0.5) / r_) ** 2) * 3, 0, 1) * 0.35))
        P.over(img, P.rgba(cc, a_))
    # mỏ vàng nhọn
    bu = U - 34.0
    beak = np.clip((1.7 * (1 - bu / 4.2) - np.abs(V)) * ks / 2, 0, 1) * ((bu > -1.2) & (bu < 4.2))
    blob(beak, (232, 186, 74))
    blob(np.clip((0.25 - np.abs(V)) * ks, 0, 1) * ((bu > 0) & (bu < 3.6)) * 0.4, (150, 110, 40), lit=False)
    # tích đỏ hai bên mỏ
    for sd in (-1, 1):
        blob(np.clip((1 - np.hypot((U - 31.6) / 1.4, (V - sd * 2.3) / 1.0)) * 4, 0, 1), (204, 44, 40))
    # mắt hai bên đầu
    for sd in (-1, 1):
        e = np.hypot(U - 30.6, V - sd * 4.3)
        P.over(img, P.rgba(np.zeros((n, n, 3)) + np.array([230, 170, 60]), np.clip((1.05 - e) * ks * 0.8, 0, 1)))
        P.over(img, P.rgba(np.zeros((n, n, 3)) + np.array([14, 10, 8]), np.clip((0.62 - e) * ks * 0.8, 0, 1)))
        e2 = np.hypot(U - 30.85, V - sd * 4.3 + 0.22)
        P.over(img, P.rgba(np.zeros((n, n, 3)) + 255, np.clip((0.2 - e2) * ks * 1.2, 0, 1) * 0.9))
    return img
