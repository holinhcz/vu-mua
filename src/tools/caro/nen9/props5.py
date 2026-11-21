# Món mới cho nền cờ caro: ca trà đá (ca nhựa) + 3 ly nước mía, nhìn từ trên xuống, vẽ từng điểm ảnh.
import math, numpy as np
import props as P, board2 as B

def tra_mia(K, R=37.0, seed=5):
    rg = np.random.default_rng(seed)
    n = int(R * 2.3 * K); c = n / 2
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    dx = (xx - c) / K; dy = (yy - c) / K
    img = np.zeros((n, n, 4), np.float32)
    fine = B.fbm(n, n, 0.5 * K, 2, rg)
    def put(col, a):
        P.over(img, P.rgba(col, a))
    def soft(m, r=0.35):
        return P.blur(m.astype(np.float32), r * K)
    def ice(cx, cy, rad, cnt, tint, rgx):
        # đá viên: khối vuông trong mờ, cạnh sáng
        for _ in range(cnt):
            a = rgx.uniform(0, 6.283); r = rad * math.sqrt(rgx.uniform(0, 0.8))
            ix = cx + math.cos(a) * r; iy = cy + math.sin(a) * r
            sz = rgx.uniform(1.3, 2.1) * rad / 9.0 + 0.6; rot = rgx.uniform(0, 1.57)
            cr, sr = math.cos(rot), math.sin(rot)
            u = (dx - ix) * cr + (dy - iy) * sr; v = -(dx - ix) * sr + (dy - iy) * cr
            d = np.maximum(np.abs(u), np.abs(v)) / sz
            m = d < 1
            edge = np.clip((d - 0.7) * 4, 0, 1)
            lit = np.clip(0.6 - 0.25 * (u + v) / sz, 0, 1)
            col = np.array(tint, np.float32) * 0.6 + np.array([235, 240, 238], np.float32) * 0.4
            col = col * (0.75 + 0.35 * lit)[..., None] + (edge * 40)[..., None]
            put(col, soft(m) * (0.35 + 0.4 * edge))
    # ---------------- CA NHỰA TRÀ ĐÁ (xanh ngọc trong, có quai)
    px, py, pr = -8.0, -3.0, 14.5
    e = np.hypot(dx - px, dy - py)
    # quai: vòng dẹt bên trái
    qa = np.abs(np.hypot((dx - (px - pr - 3.2)) / 1.0, (dy - py) / 1.6) - 4.2) < 1.3
    qa &= dx < px - pr + 1.5
    put(np.zeros((n, n, 3)) + np.array([96, 176, 166]) * (0.75 + 0.3 * np.clip(-(dy - py) / 6, -1, 1))[..., None], soft(qa) * 0.95)
    # vòi (mỏ rót) bên phải: bầu nhọn nhỏ
    sp = np.hypot((dx - (px + pr + 0.5)) / 3.0, (dy - py) / 2.6) < 1
    put(np.zeros((n, n, 3)) + np.array([110, 190, 180]), soft(sp) * 0.9)
    # thành ca: vành nhựa
    rim = (e < pr) & (e > pr - 1.6)
    rn = (e - (pr - 0.8)) / 0.8
    ls = P.lam(rn * (dx - px) / np.maximum(e, 1e-3), rn * (dy - py) / np.maximum(e, 1e-3), np.sqrt(np.clip(1 - np.clip(rn, -1, 1) ** 2, 0, 1)))
    # nước trà bên trong: hổ phách, đậm dần ra mép, ánh sáng xuyên
    inner = e < pr - 1.4
    t = e / (pr - 1.4)
    tea = np.array([168, 92, 34], np.float32) * (1.05 - 0.35 * t ** 2)[..., None] * (0.92 + 0.12 * fine)[..., None]
    caust = np.clip(1 - np.hypot(dx - px + 4, dy - py + 4) / 7, 0, 1) ** 2
    tea += (caust * 70)[..., None] * np.array([1.0, 0.8, 0.45])
    put(tea, soft(inner) * 0.97)
    ice(px, py, pr - 3, 14, (200, 150, 90), np.random.default_rng(seed + 1))
    # mặt nước phản sáng (vệt cong)
    gl = np.clip(1 - np.abs(np.hypot(dx - px - 3, dy - py - 3) - (pr - 4)) / 0.9, 0, 1) * ((dx - px) < -2) * ((dy - py) < -2)
    put(np.zeros((n, n, 3)) + 255, gl * 0.35 * inner)
    put(np.zeros((n, n, 3)) + np.array([120, 200, 190]) * (0.6 + 0.6 * ls)[..., None], soft(rim) * 0.95)
    # ---------------- 3 LY NƯỚC MÍA (ly nhựa trong, nước mía vàng xanh, bọt, ống hút)
    cups = [(13.0, -14.0), (17.5, 4.0), (5.0, 16.5)]
    for k, (cx, cy) in enumerate(cups):
        cr_ = 7.2
        e = np.hypot(dx - cx, dy - cy)
        rgk = np.random.default_rng(seed + 10 + k)
        # thành ly nhựa trong: vòng mảnh, sáng phía nắng
        ring = (e < cr_) & (e > cr_ - 0.9)
        rn = (e - (cr_ - 0.45)) / 0.45
        ls = P.lam(rn * (dx - cx) / np.maximum(e, 1e-3), rn * (dy - cy) / np.maximum(e, 1e-3), np.sqrt(np.clip(1 - np.clip(rn, -1, 1) ** 2, 0, 1)))
        inn = e < cr_ - 0.8
        t = e / (cr_ - 0.8)
        mia = np.array([196, 196, 104], np.float32) * (1.02 - 0.25 * t ** 2)[..., None]
        # bọt nước mía: đốm kem, bọt li ti
        foam = B.fbm(n, n, 0.7 * K, 2, rgk)
        fm = np.clip((foam - 0.42) * 3, 0, 1) * np.clip(1.1 - t, 0, 1)
        mia = mia * (1 - fm[..., None]) + np.array([236, 228, 178], np.float32) * fm[..., None]
        bub = np.clip((B.fbm(n, n, 0.25 * K, 1, rgk) - 0.78) * 6, 0, 1)
        mia += (bub * 30)[..., None]
        put(mia, soft(inn))
        ice(cx, cy, cr_ - 2, 4, (200, 200, 120), rgk)
        # ống hút đỏ trắng: nhìn từ trên = 1 khoanh tròn + thân nghiêng
        ox, oy = cx + 2.0, cy - 2.2
        ang = -0.6 + k * 0.9
        su = (dx - ox) * math.cos(ang) + (dy - oy) * math.sin(ang); sv = -(dx - ox) * math.sin(ang) + (dy - oy) * math.cos(ang)
        st = (su > 0) & (su < 5.0) & (np.abs(sv) < 0.8)
        stripe = (np.floor(su / 1.1) % 2) == 0
        scol = np.where(stripe[..., None], np.array([220, 60, 52], np.float32), np.array([245, 240, 232], np.float32))
        put(scol * (0.85 + 0.2 * np.clip(-sv / 0.8, -1, 1))[..., None], soft(st, 0.25))
        hole = np.hypot(dx - ox - math.cos(ang) * 5, dy - oy - math.sin(ang) * 5)
        put(np.zeros((n, n, 3)) + np.array([200, 50, 44]), soft(hole < 0.95, 0.2))
        put(np.zeros((n, n, 3)) + np.array([90, 30, 26]), soft(hole < 0.45, 0.15))
        put(np.zeros((n, n, 3)) + np.array([225, 235, 232]) * (0.65 + 0.5 * ls)[..., None], soft(ring, 0.25) * 0.85)
    return img
