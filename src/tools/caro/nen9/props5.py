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
    def ice(cx, cy, rad, cnt, tint, rgx, minsz=0.0):
        # đá viên 3D: mặt trên vuông bo góc, cạnh vát có pháp tuyến -> sáng/tối theo nắng
        placed = []
        for _ in range(cnt * 6):
            if len(placed) >= cnt: break
            a = rgx.uniform(0, 6.283); r = rad * math.sqrt(rgx.uniform(0.05, 0.9))
            ix = cx + math.cos(a) * r; iy = cy + math.sin(a) * r
            sz = max(minsz, rgx.uniform(0.85, 1.15) * rad / 4.2)
            if any(math.hypot(ix - p, iy - q) < (sz + z) * 0.95 for p, q, z in placed): continue
            placed.append((ix, iy, sz))
            rot = rgx.uniform(0, 1.57); cr, sr = math.cos(rot), math.sin(rot)
            u = ((dx - ix) * cr + (dy - iy) * sr) / sz; v = (-(dx - ix) * sr + (dy - iy) * cr) / sz
            d = (np.abs(u) ** 5 + np.abs(v) ** 5) ** 0.2
            m = d < 1
            bw = 0.38
            nu = np.sign(u) * np.clip((np.abs(u) - (1 - bw)) / bw, 0, 1) * 0.8
            nv = np.sign(v) * np.clip((np.abs(v) - (1 - bw)) / bw, 0, 1) * 0.8
            nx = nu * cr - nv * sr; ny = nu * sr + nv * cr
            nz = np.sqrt(np.clip(1 - nx ** 2 - ny ** 2, 0.05, 1))
            sh = P.lam(nx, ny, nz)
            base = np.array(tint, np.float32) * 0.25 + np.array([236, 246, 250], np.float32) * 0.75
            col = base * (0.45 + 0.75 * sh)[..., None]
            spec = np.clip(1 - np.hypot(u + 0.45, v + 0.45) / 0.35, 0, 1) ** 2
            col = col + (spec * 90)[..., None]
            bev = np.clip((d - 0.55) * 2.5, 0, 1)
            # bóng tối mép dưới viên đá trong nước (cảm giác nổi lên)
            sx, sy = ix + 0.35 * sz, iy + 0.35 * sz
            sd = (np.abs((dx - sx) * cr + (dy - sy) * sr) ** 5 + np.abs(-(dx - sx) * sr + (dy - sy) * cr) ** 5) ** 0.2 / sz
            put(np.zeros((n, n, 3)) + np.array(tint, np.float32) * 0.35, soft(sd < 1, 0.5) * 0.35 * (1 - m))
            put(col, soft(m, 0.18) * (0.32 + 0.55 * bev + 0.2 * spec))
    # ---------------- CA NHỰA TRÀ ĐÁ (xanh ngọc, có quai, mỏ rót liền vành)
    px, py, pr = -8.0, -3.0, 14.5
    th = np.arctan2(dy - py, dx - px)
    e0 = np.hypot(dx - px, dy - py)
    R = pr + 3.2 * np.clip(np.cos(th), 0, 1) ** 14      # vành phình nhọn về bên phải = mỏ rót
    e = e0 / R * pr
    # quai: ống nhựa cong bên trái, đổ bóng tròn như ống
    qx = px - pr - 3.6
    qd = np.hypot((dx - qx) / 1.0, (dy - py) / 1.55)
    qr = (qd - 4.4) / 1.35
    qa = (np.abs(qr) < 1) & (dx < px - pr + 2.0)
    qn = np.sqrt(np.clip(1 - qr ** 2, 0, 1))
    qnx = qr * (dx - qx) / np.maximum(qd, 1e-3); qny = qr * (dy - py) / 1.55 / np.maximum(qd, 1e-3)
    qs = P.lam(qnx, qny, qn)
    put(np.array([72, 158, 150], np.float32) * (0.55 + 0.65 * qs)[..., None], soft(qa, 0.25) * 0.97)
    # thân ca: vành nhựa dày
    rw = 2.0
    rim = (e < pr) & (e > pr - rw)
    rn = (e - (pr - rw / 2)) / (rw / 2)
    nxr = rn * (dx - px) / np.maximum(e0, 1e-3); nyr = rn * (dy - py) / np.maximum(e0, 1e-3)
    ls = P.lam(nxr, nyr, np.sqrt(np.clip(1 - np.clip(rn, -1, 1) ** 2, 0, 1)))
    # nước trà: hổ phách, tối dần sát thành (độ sâu), nắng xuyên vệt sáng
    inner = e < pr - rw + 0.3
    t = np.clip(e / (pr - rw), 0, 1)
    tea = np.array([170, 90, 30], np.float32) * (1.08 - 0.45 * t ** 3)[..., None] * (0.93 + 0.1 * fine)[..., None]
    caust = np.clip(1 - np.hypot(dx - px - 3, dy - py - 3) / 8, 0, 1) ** 2
    tea += (caust * 60)[..., None] * np.array([1.0, 0.75, 0.4])
    # bóng thành ca đổ vào nước phía trên-trái (nắng từ trên trái)
    wsh = np.clip(1 - np.hypot(dx - px + 1.6, dy - py + 1.6) / (pr - rw), 0, 1)
    tea *= (0.72 + 0.28 * np.clip(wsh * 6, 0, 1))[..., None]
    put(tea, soft(inner) * 0.98)
    ice(px, py, pr - 4.5, 7, (205, 140, 70), np.random.default_rng(seed + 1))
    # vệt phản sáng mặt nước
    gl = np.clip(1 - np.abs(e0 - (pr - 4.5)) / 0.7, 0, 1) * np.clip(np.cos(th - 2.35) * 3 - 2, 0, 1)
    put(np.zeros((n, n, 3)) + 255, gl * 0.3 * inner)
    put(np.array([96, 192, 182], np.float32) * (0.5 + 0.7 * ls)[..., None], soft(rim, 0.22) * 0.97)
    # mép vành trong (bậc nhựa) mảnh tối
    lip = np.abs(e - (pr - rw)) < 0.3
    put(np.zeros((n, n, 3)) + np.array([40, 96, 92]), soft(lip, 0.2) * 0.6)
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
        ice(cx, cy, cr_ - 2.6, 3, (200, 200, 120), rgk)
        # thành ly trong suốt ngay trên mặt nước: vòng mờ
        wall = np.abs(e - (cr_ - 1.3)) < 0.35
        put(np.zeros((n, n, 3)) + np.array([250, 250, 236]), soft(wall, 0.25) * 0.28)
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
        # giọt nước đọng trên vành ly
        for j in range(5):
            aa = rgk.uniform(0, 6.283); rr = cr_ + rgk.uniform(-0.2, 0.5)
            gx_, gy_ = cx + math.cos(aa) * rr, cy + math.sin(aa) * rr
            gd = np.hypot(dx - gx_, dy - gy_) / rgk.uniform(0.35, 0.55)
            put(np.zeros((n, n, 3)) + 255, soft(gd < 0.45, 0.12) * 0.75)
            put(np.zeros((n, n, 3)) + np.array([150, 160, 160]), soft((gd < 1) & (gd > 0.6), 0.12) * 0.35)
    return img
