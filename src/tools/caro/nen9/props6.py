# Đèn dầu hột vịt cho cảnh đêm cờ caro, nhìn từ trên xuống, vẽ từng điểm ảnh.
#   den_dau(K)  : thân đèn (bầu thuỷ tinh có dầu, cổ đồng, núm vặn tim, bóng thuỷ tinh) — không có lửa
#   den_lua(K)  : ngọn lửa + quầng (Godot cộng sáng, lập lòe)
import math, numpy as np
import props as P, board2 as B

def _grid(R, K):
    n = int(R * 2.2 * K); c = n / 2
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    return n, (xx - c) / K, (yy - c) / K

def den_dau(K, seed=7):
    rg = np.random.default_rng(seed)
    n, dx, dy = _grid(17.0, K)
    img = np.zeros((n, n, 4), np.float32)
    put = lambda col, a: P.over(img, P.rgba(col, a))
    soft = lambda m, r=0.3: P.blur(m.astype(np.float32), r * K)
    Z = np.zeros((n, n, 3), np.float32)
    e = np.hypot(dx, dy); th = np.arctan2(dy, dx)
    fine = B.fbm(n, n, 0.6 * K, 2, rg)
    # bầu thuỷ tinh: đáy dầu hôi vàng hổ phách, sâu tối dần ra mép, thành trong suốt
    RB = 13.0
    t = np.clip(e / RB, 0, 1)
    oil = np.array([226, 176, 96], np.float32) * (1.05 - 0.5 * t ** 2.5)[..., None] * (0.94 + 0.1 * fine)[..., None]
    caus = np.clip(1 - np.hypot(dx + 4, dy + 4) / 6, 0, 1) ** 2
    oil += (caus * 70)[..., None] * np.array([1, 0.85, 0.5])
    put(oil, soft(e < RB - 0.6) * 0.62)
    # thành bầu: vòng sáng phía nắng (trên trái), mép tối dưới phải
    rn = np.clip((e - (RB - 1.1)) / 1.1, -1, 1)
    nx = rn * dx / np.maximum(e, 1e-3); ny = rn * dy / np.maximum(e, 1e-3)
    ls = P.lam(nx, ny, np.sqrt(np.clip(1 - rn ** 2, 0, 1)))
    put(Z + np.array([230, 222, 196]) * (0.55 + 0.6 * ls)[..., None], soft((e < RB) & (e > RB - 2.2), 0.25) * (0.35 + 0.45 * np.abs(rn)))
    gl = np.clip(1 - np.abs(e - (RB - 2.6)) / 0.6, 0, 1) * np.clip(np.cos(th + 2.3) * 3 - 1.8, 0, 1)
    put(Z + 255, gl * 0.7)
    # cổ đồng: vòng kim loại có vân khía, sáng tối theo pháp tuyến
    R0, R1 = 5.6, 8.4
    m = (e > R0) & (e < R1)
    rn = (e - (R0 + R1) / 2) / ((R1 - R0) / 2)
    nx = rn * dx / np.maximum(e, 1e-3); ny = rn * dy / np.maximum(e, 1e-3)
    sh = P.lam(nx, ny, np.sqrt(np.clip(1 - np.clip(rn, -1, 1) ** 2, 0.05, 1)))
    knurl = 0.9 + 0.12 * np.sin(th * 46)
    brass = np.array([182, 126, 46], np.float32) * (0.35 + 0.95 * sh * knurl)[..., None]
    brass += (np.clip(sh - 0.85, 0, 1) * 500)[..., None] * np.array([1, 0.9, 0.6])
    put(np.minimum(brass, 255), soft(m, 0.2))
    put(Z + np.array([70, 48, 18]), soft(np.abs(e - R1) < 0.25, 0.15) * 0.7)
    # núm vặn tim: trục + bánh khía nhô ra bên phải
    ax = (dx > R1 - 0.5) & (dx < R1 + 3.2) & (np.abs(dy) < 0.75)
    put(Z + np.array([170, 128, 52]) * (0.8 + 0.3 * np.clip(-dy / 0.75, -1, 1))[..., None], soft(ax, 0.2))
    ke = np.hypot((dx - (R1 + 3.9)) / 0.9, dy / 2.4)
    kn = (ke < 1)
    ks = 0.7 + 0.35 * np.clip(-dy / 2.4, -1, 1) + 0.12 * np.sin(dy * 9)
    put(Z + np.array([186, 140, 58]) * ks[..., None], soft(kn, 0.2))
    # bóng đèn thuỷ tinh (ống khói): phình ra rồi miệng trên, nhìn xuống thấy 2 vòng trong
    put(Z + np.array([210, 226, 230]), soft(np.abs(e - 7.0) < 0.9, 0.5) * 0.22)
    rim = np.abs(e - 4.6) < 0.45
    put(Z + np.array([236, 244, 246]) * (0.7 + 0.4 * P.lam(dx / 4.6, dy / 4.6, np.full_like(dx, 0.5)))[..., None], soft(rim, 0.2) * 0.75)
    # muội đèn ám trong miệng ống
    soot = np.clip(1 - np.abs(e - 3.6) / 1.2, 0, 1) * (0.6 + 0.4 * fine)
    put(Z + np.array([46, 38, 30]), soot * 0.45 * (e < 4.4))
    # tim đèn: khe vải dẹt
    wk = (np.abs(dx) < 2.0) & (np.abs(dy) < 0.45)
    put(Z + np.array([60, 44, 30]), soft(wk, 0.15) * 0.9)
    put(Z + 255, soft(np.hypot(dx + 2.6, dy + 2.6) < 0.7, 0.3) * 0.6)
    return img

def den_lua(K):
    # ngọn lửa nhìn xiên từ trên: lõi trắng vàng, viền cam, quầng đỏ cam mờ; nền trong suốt (Godot cộng sáng)
    n, dx, dy = _grid(16.0, K)
    img = np.zeros((n, n, 4), np.float32)
    e = np.hypot(dx / 0.75, (dy + 0.6) / 1.15)
    core = np.clip(1 - e / 1.3, 0, 1) ** 0.8
    mid = np.clip(1 - e / 2.6, 0, 1) ** 1.4
    halo = np.clip(1 - np.hypot(dx, dy) / 15.5, 0, 1) ** 2.6
    col = (np.array([255, 150, 50], np.float32) * halo[..., None] * 0.55
           + np.array([255, 190, 80], np.float32) * mid[..., None]
           + np.array([255, 250, 225], np.float32) * core[..., None])
    a = np.clip(halo * 0.55 + mid + core, 0, 1)
    img[..., :3] = np.minimum(col / np.maximum(a, 1e-3)[..., None], 255); img[..., 3] = a * 255
    return img
