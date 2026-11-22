# Cờ gánh 9px: quân (sỏi trắng, miểng gạch tàu) và rổ tre, nhìn thẳng từ trên, nắng trái-trên như sân caro.
# Mỗi món 1 file. K = điểm ảnh / css.
import math, sys, os
import numpy as np
from PIL import Image
import props as P
import board2 as B

K = 9.0
CELL = 560            # ô quân (px): quân chiếm 82% ô như code cg (D = r*2/0.82)


def _outline(n, rg, R, sq, lump, ax, ang):
    """mặt nạ khoảng cách chuẩn hoá e (e<=1 là trong quân): siêu elip + méo tần số thấp"""
    c = n / 2
    xx, yy = P.grid(n)
    x = (xx - c); y = (yy - c)
    ca, sa = math.cos(ang), math.sin(ang)
    u = (x * ca + y * sa) / (R * ax); v = (-x * sa + y * ca) / (R / ax)
    th = np.arctan2(v, u)
    wob = np.zeros_like(th)
    for k in range(2, 6):
        wob += rg.uniform(-1, 1) * lump / k * np.cos(k * th + rg.uniform(0, 6.28))
    e = (np.abs(u) ** sq + np.abs(v) ** sq) ** (1 / sq) / (1 + wob)
    return e, x, y


def _shade(h):
    gy, gx = np.gradient(h)
    nz = np.ones_like(h)
    l = np.sqrt(gx ** 2 + gy ** 2 + 1)
    return P.lam(-gx / l, -gy / l, nz / l), -gx / l, -gy / l, nz / l


def soi(seed):
    """sỏi trắng suối: tròn dẹt, mặt mịn mờ (không bóng loáng), hạt khoáng li ti, đôi viên có vân thạch anh"""
    rg = np.random.default_rng(100 + seed)
    n = CELL
    R = n * 0.41 * rg.uniform(0.9, 0.98)
    e, x, y = _outline(n, rg, R, rg.uniform(2.0, 2.4), 0.07, rg.uniform(1.0, 1.16), rg.uniform(0, 3.14))
    ins = np.clip(1 - e, 0, 1)
    dome = np.sqrt(np.clip(1 - e ** 2, 0, 1))
    h = (dome ** 0.65) * R * 0.40                                           # dẹt
    h += (B.fbm(n, n, 120, 2, rg) - 0.5) * R * 0.018 * dome                 # mặt gợn rất nhẹ
    s, nx, ny, nz = _shade(h)
    base = np.array([234, 231, 220], np.float32) * rg.uniform(0.96, 1.02)
    tint = np.array([1.0, 0.99, 0.96]) + (rg.random(3) - 0.5) * 0.03
    tone = B.fbm(n, n, 90, 3, rg)
    hl = np.clip(0.5 + 0.5 * (nx * P.L[0] + ny * P.L[1] + nz * P.L[2]), 0, 1)   # nửa-lambert: đỉnh sáng, không cháy trắng
    col = base * tint * (0.28 + 0.76 * hl)[..., None] * (0.93 + 0.1 * tone)[..., None]
    # hạt khoáng: chấm xám / nâu nhỏ thưa
    g1 = B.fbm(n, n, 2.2, 2, rg)
    g2 = B.fbm(n, n, 4.0, 1, rg)
    dots = np.clip((g1 - 0.8) * 9, 0, 1) * 0.45 + np.clip((g2 - 0.84) * 8, 0, 1) * 0.3
    col *= (1 - 0.35 * dots)[..., None]
    col += (np.clip(B.fbm(n, n, 1.6, 1, rg) - 0.82, 0, 1) * 220)[..., None]   # tinh thể sáng lấp lánh nhỏ
    # vân thạch anh (1 trong 3 viên)
    if seed % 3 == 0:
        a = rg.uniform(0, 3.14)
        dd = (x * math.cos(a) + y * math.sin(a)) / R + 0.12 * np.sin(-x * math.sin(a) / R * 3 + y * math.cos(a) / R * 3 + rg.uniform(0, 6))
        vein = np.exp(-((dd - rg.uniform(-0.3, 0.3)) / 0.028) ** 2)
        col = col * (1 - 0.5 * vein[..., None]) + np.array([248, 246, 240]) * (0.5 * vein * (0.6 + 0.5 * s))[..., None]
    # tối dần sát mép (quanh đáy) + phản sáng đất ở mép dưới-phải
    rimd = np.clip((e - 0.82) / 0.18, 0, 1)
    col *= (1 - 0.22 * rimd ** 1.5)[..., None]
    bounce = rimd * np.clip((x + y) / R / 1.4, 0, 1)
    col += (bounce * 18)[..., None] * np.array([1.0, 0.85, 0.6])
    # bóng mờ rộng (đá mài nước, không loáng)
    spec = np.clip(nx * -0.5 + ny * -0.58 + nz * 0.64, 0, 1) ** 24
    col += (spec * 34)[..., None]
    al = P.blur((e <= 1).astype(np.float32), 1.1)
    return P.rgba(col, al)


def gach(seed):
    """miểng gạch tàu: mảnh vỡ dày, mặt trên phẳng hơi lượn, cạnh vỡ vát tròn, đất nung đỏ cam có lỗ rỗ, hạt cát"""
    rg = np.random.default_rng(200 + seed)
    n = CELL
    R = n * 0.35 * rg.uniform(0.94, 1.0)
    e, x, y = _outline(n, rg, R, rg.uniform(3.0, 3.8), 0.08, rg.uniform(1.0, 1.14), rg.uniform(0, 1.57))
    # mẻ cạnh: vài chỗ vỡ lẹm vào theo góc (mép vẫn vát)
    th = np.arctan2(y, x)
    for _ in range(int(rg.integers(1, 3))):
        a = rg.uniform(-3.14, 3.14); w = rg.uniform(0.18, 0.32)
        da = np.angle(np.exp(1j * (th - a)))
        e = e * (1 + rg.uniform(0.06, 0.11) * np.exp(-(da / w) ** 4))
    bev = 0.13
    t = np.clip((1 - e) / bev, 0, 1)                   # 0 ở mép, 1 vào mặt phẳng
    h = R * 0.20 * np.sin(t * math.pi / 2) ** 0.7
    h += (B.fbm(n, n, 70, 2, rg) - 0.5) * R * 0.03      # mặt hơi lượn
    pits = B.fbm(n, n, 2.2, 2, rg)
    hole = np.clip((0.2 - pits) * 9, 0, 1) * (0.4 + 0.6 * np.clip(B.fbm(n, n, 80, 2, rg) * 1.6 - 0.4, 0, 1))   # lỗ rỗ, chỗ nhiều chỗ ít
    h -= hole * R * 0.012
    s, nx, ny, nz = _shade(h)
    tone = B.fbm(n, n, 110, 3, rg)
    warm = rg.uniform(-0.05, 0.05)
    base = np.array([186 + 20 * warm * 10, 86, 52], np.float32) * rg.uniform(0.94, 1.04)
    col = base * (0.40 + 0.72 * s)[..., None] * (0.86 + 0.22 * tone)[..., None]
    # mặt trên mòn: loang sáng hơi vàng, cạnh vỡ đỏ sậm hơn (lõi gạch)
    top = np.clip((t - 0.85) / 0.15, 0, 1)
    wear = np.clip(B.fbm(n, n, 45, 2, rg) - 0.45, 0, 1) * 1.6 * top
    col = col * (1 - 0.22 * wear[..., None]) + np.array([214, 140, 96]) * (0.22 * wear * (0.5 + 0.6 * s))[..., None]
    side = 1 - top
    col *= (1 - 0.12 * side)[..., None] * np.array([1.0, 0.92, 0.9])[None, None, :] ** side[..., None]
    # hạt cát + lỗ rỗ tối
    sand = B.fbm(n, n, 1.8, 1, rg)
    col += (np.clip(sand - 0.8, 0, 1) * 160)[..., None] * np.array([1.0, 0.85, 0.65])
    col *= (1 - 0.45 * hole)[..., None]
    grit = B.fbm(n, n, 1.3, 1, rg)
    col *= (0.94 + 0.1 * grit)[..., None]
    # phản sáng đất ở cạnh dưới-phải
    bounce = side * np.clip((x + y) / R / 1.4, 0, 1)
    col += (bounce * 14)[..., None] * np.array([1.0, 0.8, 0.55])
    al = P.blur((e <= 1).astype(np.float32), 1.0)
    return P.rgba(col, al)


def ro(R=100.0, seed=3):
    """rổ tre tròn sâu, nhìn từ trên: đáy đan lóng mốt, thành rổ nan dọc xiên vào, cạp tre 2 lớp quấn mây"""
    rg = np.random.default_rng(seed)
    n = int(R * 2.08 * K); c = n / 2
    xx, yy = P.grid(n)
    dx = (xx - c) / K; dy = (yy - c) / K
    d = np.hypot(dx, dy); ang = np.arctan2(dy, dx)
    r_bot = R * 0.66; r_rim = R * 0.86
    # --- đáy: lóng mốt (2 lên 2 xuống) nan 2.4 css, xéo 45
    u = (dx + dy) / math.sqrt(2); v = (dx - dy) / math.sqrt(2)
    w = 2.4
    iu = np.floor(u / w); iv = np.floor(v / w)
    fu = u / w - iu; fv = v / w - iv
    top = ((iu.astype(int) + iv.astype(int) // 2) % 2) == 0
    f = np.where(top, fv, fu)
    # nan cong lên ở giữa đoạn nổi, chìm xuống ở chỗ luồn
    along = np.where(top, fu, fv)
    seg = ((np.where(top, iu, iv).astype(int)) % 2 + along) / 2
    lift = np.sin(seg * math.pi)
    ndir = (f - 0.5) * 1.7
    nz = np.sqrt(np.clip(1 - ndir ** 2, 0, 1))
    nxb = np.where(top, ndir, ndir) / math.sqrt(2)
    nyb = np.where(top, -ndir, ndir) / math.sqrt(2)
    sb = P.lam(nxb, nyb, nz)
    strip = rg.random((int(n / (w * K)) * 3 + 50,)).astype(np.float32)
    sid = (np.where(top, iv, iu).astype(int) % (strip.size)).astype(int)
    stv = strip[sid]                                   # mỗi nan 1 tông (cật / ruột tre)
    bam = np.array([200, 166, 108], np.float32) * (0.86 + 0.22 * stv)[..., None]
    fib = B.fbm(n, n, 2.5, 2, rg)
    col_b = bam * (0.55 + 0.55 * sb)[..., None] * (0.9 + 0.14 * fib)[..., None] * (0.82 + 0.18 * lift)[..., None]
    gap = np.minimum(np.minimum(fu, 1 - fu), np.minimum(fv, 1 - fv))
    col_b *= (0.45 + 0.55 * np.clip(gap * 10, 0, 1))[..., None]
    # đáy rổ tối hơn ở giữa (sâu) + bóng thành rổ đổ xuống phía nắng
    deep = 1 - 0.16 * np.clip(1 - d / r_bot, 0, 1)
    col_b *= deep[..., None]
    # --- thành: nan dọc (theo bán kính) đan nan ngang tròn, nghiêng vào trong
    tw = np.clip((d - r_bot) / (r_rim - r_bot), 0, 1)
    nst = int(2 * math.pi * R / 3.2)
    a_st = ang / (2 * math.pi) * nst
    fa = a_st - np.floor(a_st)
    rings = (d - r_bot) / 2.6
    fr = rings - np.floor(rings)
    over_v = ((np.floor(a_st).astype(int) + np.floor(rings).astype(int)) % 2) == 0
    # pháp tuyến thành: hướng vào tâm + nghiêng lên
    wnx = -dx / np.maximum(d, 1e-3) * 0.62; wny = -dy / np.maximum(d, 1e-3) * 0.62; wnz = 0.78
    sw = P.lam(wnx, wny, wnz)
    bump = np.where(over_v, np.sin(fa * math.pi), np.sin(fr * math.pi))
    col_w = np.array([176, 146, 98], np.float32) * (0.9 + 0.2 * strip[(np.floor(a_st).astype(int)) % strip.size])[..., None] * (0.38 + 0.75 * sw)[..., None] * (0.78 + 0.26 * bump)[..., None]
    col_w *= (0.88 + 0.16 * fib)[..., None]
    wgap = np.minimum(np.minimum(fa, 1 - fa) * 3.2 / 2.6, np.minimum(fr, 1 - fr))
    col_w *= (0.5 + 0.5 * np.clip(wgap * 9, 0, 1))[..., None]
    col_w *= (0.72 + 0.28 * tw)[..., None]                                     # sâu thì tối
    col = np.where((d > r_bot)[..., None], col_w, col_b)
    # bóng cạp đổ vào lòng rổ (phía nắng chiếu tới = trái trên là phía bị che)
    facing = np.clip((dx * P.L[0] + dy * P.L[1]) / np.maximum(d, 1e-3), -1, 1)
    shin = np.clip((d - (r_rim - R * 0.30)) / (R * 0.30), 0, 1) * np.clip(facing + 0.25, 0, 1)
    col *= (1 - 0.42 * shin * (d < r_rim))[..., None]
    # --- cạp: 2 vòng tre tròn + mây quấn chéo
    t = (d - r_rim) / (R - r_rim)
    rimm = (t >= 0) & (t <= 1)
    two = np.where(t < 0.5, t / 0.5, (t - 0.5) / 0.5)
    rn = (two - 0.5) * 1.8
    nzr = np.sqrt(np.clip(1 - rn ** 2, 0, 1))
    sr = P.lam(rn * dx / np.maximum(d, 1e-3), rn * dy / np.maximum(d, 1e-3), nzr)
    rc = np.array([186, 142, 82], np.float32) * (0.42 + 0.72 * sr)[..., None] * (0.9 + 0.12 * fib)[..., None]
    nw = int(2 * math.pi * R / 4.2)
    wr = np.sin(ang * nw + t * 3.4)
    wrap = wr > 0.35
    mc = np.array([128, 88, 46], np.float32)
    rc = np.where(wrap[..., None], mc * (0.75 + 0.35 * np.clip(wr, 0, 1))[..., None] * (0.55 + 0.55 * sr)[..., None], rc)
    col = np.where(rimm[..., None], rc, col)
    al = P.blur((d <= R).astype(np.float32), 0.4 * K)
    return P.rgba(col, al)


def nia(R=100.0, seed=3):
    """nia tre cạn (như bản web cũ): đáy đan lóng mốt phủ gần tới mép, 1 vòng cạp tre tròn to, mây buộc thưa"""
    rg = np.random.default_rng(seed)
    n = int(R * 2.08 * K); c = n / 2
    xx, yy = P.grid(n)
    dx = (xx - c) / K; dy = (yy - c) / K
    d = np.hypot(dx, dy); ang = np.arctan2(dy, dx)
    r_rim = R * 0.88
    # đáy: lóng mốt nan rộng 4.4 css, xéo 45, mỗi nan 1 tông, nổi lên ở đoạn nằm trên
    u = (dx + dy) / math.sqrt(2); v = (dx - dy) / math.sqrt(2)
    w = 4.4
    iu = np.floor(u / w); iv = np.floor(v / w)
    fu = u / w - iu; fv = v / w - iv
    top = ((iu.astype(int) + iv.astype(int) // 2) % 2) == 0
    f = np.where(top, fv, fu)
    along = np.where(top, fu, fv)
    seg = ((np.where(top, iu, iv).astype(int)) % 2 + along) / 2
    lift = np.sin(seg * math.pi)
    ndir = (f - 0.5) * 1.5
    nz = np.sqrt(np.clip(1 - ndir ** 2, 0, 1))
    # nghiêng theo chiều dọc nan ở chỗ luồn xuống (đầu nan chúi xuống) cho có khối
    tilt = np.cos(seg * math.pi) * 0.35
    nxb = np.where(top, ndir / math.sqrt(2) + tilt / math.sqrt(2), ndir / math.sqrt(2) + tilt / math.sqrt(2))
    nyb = np.where(top, -ndir / math.sqrt(2) + tilt / math.sqrt(2), ndir / math.sqrt(2) - tilt / math.sqrt(2))
    sb = P.lam(nxb, nyb, nz)
    strip = rg.random((4000,)).astype(np.float32)
    sid = (np.where(top, iv, iu).astype(int) + 2000) % strip.size
    stv = strip[sid]
    bam = np.array([196, 168, 118], np.float32) * (0.84 + 0.24 * stv)[..., None]
    fib = B.fbm(n, n, 3.0, 2, rg)
    stain = B.fbm(n, n, 160, 3, rg)                    # loang màu tre cũ
    col = bam * (0.5 + 0.6 * sb)[..., None] * (0.9 + 0.14 * fib)[..., None] * (0.8 + 0.2 * lift)[..., None]
    col *= (0.76 + 0.38 * stain)[..., None]
    gap = np.minimum(np.minimum(fu, 1 - fu), np.minimum(fv, 1 - fv))
    col *= (0.5 + 0.5 * np.clip(gap * 14, 0, 1))[..., None]
    # cạn: chỉ hơi tối sát cạp phía bị che nắng
    facing = np.clip((dx * P.L[0] + dy * P.L[1]) / np.maximum(d, 1e-3), -1, 1)
    shin = np.clip((d - (r_rim - R * 0.12)) / (R * 0.12), 0, 1) * np.clip(facing + 0.3, 0, 1)
    col *= (1 - 0.32 * shin * (d < r_rim))[..., None]
    # cạp: 1 vòng tre tròn to
    t = (d - r_rim) / (R - r_rim)
    rimm = (t >= 0) & (t <= 1)
    rn = (t - 0.5) * 1.9
    nzr = np.sqrt(np.clip(1 - rn ** 2, 0, 1))
    sr = P.lam(rn * dx / np.maximum(d, 1e-3), rn * dy / np.maximum(d, 1e-3), nzr)
    rc = np.array([178, 142, 86], np.float32) * (0.42 + 0.7 * sr)[..., None] * (0.92 + 0.12 * fib)[..., None]
    # mây buộc thưa (6 chỗ), mỗi chỗ vài vòng quấn
    for k in range(6):
        a0 = k / 6 * 2 * math.pi + rg.uniform(-0.2, 0.2)
        da = np.angle(np.exp(1j * (ang - a0))) * R
        band = (np.abs(da) < 4.0) & (np.sin(da * 2.3 + t * 2.0) > -0.2)
        rc = np.where((band & rimm)[..., None], rc * 0.78 * np.array([0.92, 0.86, 0.8]), rc)
    col = np.where(rimm[..., None], rc, col)
    al = P.blur((d <= R).astype(np.float32), 0.4 * K)
    return P.rgba(col, al)


if __name__ == '__main__':
    out = sys.argv[1]; job = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    if job == 'quan':
        for i in range(int(sys.argv[3]) if len(sys.argv) > 3 else 8):
            P.to_img(soi(i)).save(os.path.join(out, 's%d.webp' % i), lossless=True, method=4)
            P.to_img(gach(i)).save(os.path.join(out, 'g%d.webp' % i), lossless=True, method=4)
            print('quan', i, flush=True)
    elif job == 'ro':
        P.to_img(nia()).save(os.path.join(out, 'ro.webp'), lossless=True, method=4)
        print('ro', flush=True)
