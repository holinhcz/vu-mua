# Rương mở quà kiểu CÂY TRÁI - HOA SEN (Link chọn 11-26): bậc 1 trái dừa, 2 trái bí đỏ, 3 búp sen hồng, 4 sen vàng nở.
# Dựng bằng bộ lưới của ruong_k (kho3d). Phần động (nắp / từng cánh sen) ghi vào R.PARTS -> ruong_tex xuất mỗi phần 1 nút xoay riêng.
import math
import numpy as np
import ruong_k as R
from ruong_k import grid, tb, ell, newmat, hexc, vnoise, hash1, smooth, mat_kl, mat_son, flat, sen_go, sen_logo, M_BAMBOO, M_ROPE, M_RATTAN

TAU = 2 * math.pi


def part(pid, piv, axis, ang, delay=0.0):
    R.PARTS[pid] = dict(piv=tuple(float(v) for v in piv), axis=tuple(float(v) for v in axis), ang=float(ang), delay=float(delay))
    R.PART[0] = pid


def body():
    R.PART[0] = 0


def mix(a, b, t):
    t = np.clip(t, 0, 1)[:, None]
    return a[None] * (1 - t) + b[None] * t


def azi(pos):
    x, y, z = R.loc(pos)
    return np.arctan2(y, x), np.hypot(x, y), z


# ------------------------------------------------------------------ vật liệu
def m_dua_vo():
    """vỏ dừa xiêm xanh: thớ dọc mảnh sáng/tối nhẹ, ngả vàng quanh cuống"""
    g0, g1, g2 = hexc('#4f7f2a'), hexc('#6f9a38'), hexc('#a89a48')
    def f(uv, prm, pos, nrm):
        th, rr, z = azi(pos)
        s = vnoise(th * 26, z * 0.25, 3.0); s2 = vnoise(th * 70, z * 0.6, 8.0)
        c = mix(g0, g1, 0.35 * s + 0.25 * s2)
        top = smooth(R.ZL * 0.82, R.ZL * 1.0, z)
        c = c * (1 - 0.45 * top)[:, None] + g2[None] * (0.45 * top)[:, None]
        return np.clip(c, 0, 1), nrm
    f.kind = 'son'
    return f


def m_lop(prof, cols, edges):
    """mặt cắt ngang trái cây: các lớp theo bán kính tương đối (vỏ ngoài -> cơm/ruột)"""
    cs = [hexc(c) for c in cols]
    def f(uv, prm, pos, nrm):
        th, rr, z = azi(pos)
        fr = rr / np.maximum(prof(th), 1e-6)
        c = np.tile(cs[-1], (len(fr), 1))
        for e, cc in zip(edges, cs):
            c = np.where((fr > e)[:, None], cc[None], c) if False else c
        # từ trong ra ngoài: lớp nào bán kính vượt mốc thì đổi màu
        out = np.tile(cs[-1], (len(fr), 1))
        for e, cc in sorted(zip(edges, cs[:-1]), key=lambda t: t[0]):
            out = np.where((fr > e)[:, None], cc[None], out)
        fib = 0.92 + 0.1 * vnoise(th * 40, fr * 30, 5.0)
        return np.clip(out * fib[:, None], 0, 1), nrm
    f.kind = 'go'
    return f


def m_com(col, col2):
    c, c2 = hexc(col), hexc(col2)
    def f(uv, prm, pos, nrm):
        x, y, z = R.loc(pos)
        g = vnoise(x * 0.7 + z * 0.3, y * 0.7, 4.0)
        return np.clip(mix(c, c2, g * 0.6), 0, 1), nrm
    f.kind = 'son'
    return f


def m_bi():
    """vỏ bí đỏ: múi cam, sống múi sáng hơn, rãnh múi cam đậm (khối, không vệt đen), lấm tấm chấm vàng nhạt"""
    c0, c1, c2, dot = hexc('#d9701e'), hexc('#f29a38'), hexc('#c25a18'), hexc('#f6c878')
    def f(uv, prm, pos, nrm):
        th, rr, z = azi(pos)
        lobe = np.abs(np.cos(5 * (th - math.pi / 2)))
        c = mix(c2, c0, lobe ** 0.5)
        c = c * (1 - 0.35 * lobe ** 3)[:, None] + c1[None] * (0.35 * lobe ** 3)[:, None]
        st = vnoise(th * 60, z * 0.4, 6.0)
        c = c * (0.94 + 0.1 * st)[:, None]
        ci = np.floor(th * 40); cz = np.floor(z * 1.6); h = hash1(ci, cz, 3.0)
        sp = (h > 0.975)
        c = np.where(sp[:, None], c * 0.75 + dot[None] * 0.25, c)
        return np.clip(c, 0, 1), nrm
    f.kind = 'son'
    return f


def m_cuong():
    a, b = hexc('#7f8a40'), hexc('#c2ae6e')
    def f(uv, prm, pos, nrm):
        th = uv[:, 1] if uv.shape[1] > 1 else uv[:, 0]
        x, y, z = R.loc(pos)
        g = 0.5 + 0.5 * np.sin(th * TAU * 7)
        tz = smooth(R.ZL + 1.0, R.ZL + 5.5, z)
        c = mix(a, b, 0.55 * tz + 0.2 * g)
        return np.clip(c, 0, 1), nrm
    f.kind = 'go'
    return f


def m_la(col, vein, nveins):
    """lá: màu lá + gân lá toả từ cuống (sáng hơn lá, nổi khối nhẹ)"""
    c, v = hexc(col), hexc(vein)
    def f(uv, prm, pos, nrm):
        U, V = uv[:, 0], uv[:, 1]
        ph = (V * nveins) % 1.0; d = np.minimum(ph, 1 - ph) * (U + 0.05) * 6
        vv = np.exp(-(d / 0.09) ** 2) * smooth(0.02, 0.1, U) * smooth(1.0, 0.85, U)
        g = vnoise(U * 9, V * 40, 2.0)
        cc = mix(c, c * 1.12, g * 0.5)
        cc = cc * (1 - vv)[:, None] + v[None] * vv[:, None]
        cc = cc * (1 + 0.12 * U)[:, None]
        return np.clip(cc, 0, 1), nrm
    f.kind = 'go'
    return f


def m_canh(base, tip, vein, kind='son'):
    """cánh sen: gốc trắng ngà -> hồng ở chót + 2 mép, gân dọc mảnh"""
    b, t, v = hexc(base), hexc(tip), hexc(vein)
    def f(uv, prm, pos, nrm):
        U, V = uv[:, 0], uv[:, 1]
        e = np.abs(V - 0.5) * 2
        k = np.clip(U * 1.15 - 0.2 + e * 0.35 * U, 0, 1) ** 1.3
        c = mix(b, t, k)
        ln = 0.5 + 0.5 * np.cos((V - 0.5) * TAU * 7 * (1.2 - 0.4 * U))
        c = c * (1 - 0.12 * ln ** 4)[:, None] + v[None] * (0.12 * ln ** 4)[:, None]
        return np.clip(c, 0, 1), nrm
    f.kind = kind
    return f


def h_canh(P, UV, q):
    U, V = UV[:, 0], UV[:, 1]
    ln = 0.5 + 0.5 * np.cos((V - 0.5) * TAU * 7 * (1.2 - 0.4 * U))
    return 0.045 * ln ** 3 * np.sin(np.pi * np.clip(U, 0, 1)) + 0.01 * vnoise(U * 30, V * 30, 2.0)


def h_la(nveins):
    def h(P, UV, q):
        U, V = UV[:, 0], UV[:, 1]
        ph = (V * nveins) % 1.0; d = np.minimum(ph, 1 - ph) * (U + 0.05) * 6
        return 0.09 * np.exp(-(d / 0.09) ** 2) * smooth(0.02, 0.1, U) + 0.015 * vnoise(U * 20, V * 60, 4.0)
    return h


def h_soi(P, UV, q):                  # thớ dọc vỏ (dừa / bí)
    th, rr, z = azi(P)
    return 0.025 * vnoise(th * 90, z * 0.5, 7.0) + 0.012 * np.sin(th * 160 + z * 0.3)


def h_bi(P, UV, q):
    th, rr, z = azi(P)
    ci = np.floor(th * 40); cz = np.floor(z * 1.6); hh = hash1(ci, cz, 3.0)
    return 0.03 * vnoise(th * 60, z * 0.4, 6.0) + 0.03 * (hh > 0.975)


# ------------------------------------------------------------------ hình khối
def shell(S, F, nu, nv_, mat, prm=(0, 0, 0), flip=False):
    grid(S, F, nu, nv_, mat, prm, close_v=True, flip=flip)


def cut_disc(S, z, r_in, r_out, mat, flip=False, n=72):
    """mặt cắt phẳng hình vành (r_in, r_out là hàm của góc)"""
    def F(U, V):
        th = V * TAU; ri = r_in(th); ro = r_out(th); r = ri + (ro - ri) * U
        return np.stack([r * np.cos(th), r * np.sin(th), np.full_like(U, z)], -1)
    grid(S, F, 8, n, mat, (4, 0, 0), close_v=True, flip=flip)


def coins(S, rng, z0, r, n, mat):
    for k in range(n):
        a = rng.random() * TAU; d = math.sqrt(rng.random()) * r
        tilt = (rng.random() - 0.5) * 0.9
        ax = np.array([math.cos(a), math.sin(a), 0.0]); nz = np.array([0, 0, 1.0]) + ax * tilt; nz /= np.linalg.norm(nz)
        a2 = np.cross(nz, ax); a2 /= np.linalg.norm(a2); a1 = np.cross(a2, nz)
        ell(S, (d * math.cos(a), d * math.sin(a), z0 + 0.35 * (k % 4) + rng.random() * 0.3), 1.3, 1.3, 0.28, mat, axes=(a1, a2, nz), nu=5, nv_=16)


def petal(S, base, phi, L, W, a0, a1, mat, cup=0.35, thick=0.28, nu=26, nv_=14):
    """cánh sen cong: gốc ở base, mặt phẳng chứa (hướng ra d, trục đứng z); a0/a1 = góc nghiêng khỏi phương đứng ở gốc/chót"""
    d = np.array([math.cos(phi), math.sin(phi), 0.0]); t = np.array([-math.sin(phi), math.cos(phi), 0.0]); zz = np.array([0, 0, 1.0])
    us = np.linspace(0, 1, 160); th = a0 + (a1 - a0) * us ** 1.15
    dr = np.sin(th) * L / 159; dz = np.cos(th) * L / 159
    sr = np.concatenate([[0], np.cumsum(dr[:-1])]); sz = np.concatenate([[0], np.cumsum(dz[:-1])])
    base = np.asarray(base, float)
    def F(U, V, off=0.0):
        rad = np.interp(U, us, sr); hz = np.interp(U, us, sz); tt = np.interp(U, us, th)
        w = W * (0.3 + 0.7 * np.sin(np.pi * np.clip(U, 0, 1) ** 0.8)) * (1 - U ** 6)
        vv = (V - 0.5) * 2
        o = np.cos(tt)[..., None] * d - np.sin(tt)[..., None] * zz
        p = base + rad[..., None] * d + hz[..., None] * zz + (vv * w)[..., None] * t - o * (cup * w * vv ** 2)[..., None] + o * off
        return p
    grid(S, lambda U, V: F(U, V), nu, nv_, mat, (0, 0, 0), flip=False)
    grid(S, lambda U, V: F(U, V, -thick), nu, nv_, mat, (0, 0, 0), flip=True)
    return d, t


def leaf_disc(S, z0, Rl, mat_top, mat_bot, waves=9, bowl=1.6, lobes=None, n=96):
    def F(U, V, off=0.0):
        th = V * TAU
        r = Rl * U * (1 + 0.04 * np.sin(7 * th + 1.0))
        z = z0 + bowl * U ** 2 + 0.55 * U ** 3 * np.sin(waves * th) + off
        return np.stack([r * np.cos(th), r * np.sin(th), z], -1)
    grid(S, lambda U, V: F(U, V), 26, n, mat_top, (0, 0, 0), close_v=True, flip=False)
    grid(S, lambda U, V: F(U, V, -0.35), 26, n, mat_bot, (0, 0, 0), close_v=True, flip=True)


# ================================================================== BẬC 1 · TRÁI DỪA
def trai_dua(S, rng):
    Rd, Hd = 11.0, 21.0; SC_ = 0.8
    R.LA = R.LB = Rd; R.ZL = Hd; R.LR = Rd
    VO = newmat(m_dua_vo()); R.HFN[VO] = h_soi
    def rad(s, th): return Rd * np.sin(np.pi * np.clip(s, 0, 1)) ** 0.6 * (1 - 0.08 * s) * (1 + 0.035 * np.cos(3 * th))
    zc = Hd * SC_
    def prof_c(th): return rad(SC_, th)
    CAT = newmat(m_lop(prof_c, ['#7aa03e', '#d2ad70', '#f6f3ea'], [0.955, 0.80]))
    COM = newmat(m_com('#f3efe2', '#e6e2cc'))
    VANG = newmat(mat_kl('#e8b84a', hammer=False, streak=0.02, leaf=True))
    body()
    shell(S, lambda U, V: np.stack([rad(U * SC_, V * TAU) * np.cos(V * TAU), rad(U * SC_, V * TAU) * np.sin(V * TAU), U * SC_ * Hd], -1), 40, 96, VO)
    cut_disc(S, zc, lambda th: 0.78 * prof_c(th), lambda th: prof_c(th), CAT, flip=True)
    zb = Hd * 0.42
    def cav(U, V):                                   # lòng dừa: cơm trắng
        th = V * TAU; r = 0.78 * prof_c(th) * np.sin(np.pi / 2 * U) ** 0.55; z = zb + (zc - zb) * U ** 1.4
        return np.stack([r * np.cos(th), r * np.sin(th), z], -1)
    shell(S, cav, 20, 72, COM, flip=True)
    coins(S, rng, zb + 1.6, 2.8, 14, VANG)
    ell(S, (0.5, 0.3, zb + 3.4), 1.1, 1.1, 1.3, flat('#d81c3a'))
    # vòng tre lót đáy + dây mây buộc + thẻ gỗ sen
    pts = [(5.6 * math.cos(t), 5.6 * math.sin(t), 1.5) for t in np.linspace(0, TAU, 33)]
    for p0, p1 in zip(pts, pts[1:]): tb(S, p0, p1, 0.9, M_BAMBOO, (0.4, 0.2, 0), nr=7, nl=2)
    zr = Hd * 0.47; rr = Rd * math.sin(math.pi * 0.47) ** 0.6 * (1 - 0.08 * 0.47) + 0.15
    pts = [(rr * math.cos(t), rr * math.sin(t), zr) for t in np.linspace(0, TAU, 49)]
    for p0, p1 in zip(pts, pts[1:]): tb(S, p0, p1, 0.45, M_ROPE, nr=6, nl=2)
    sen_go(S, rng, (0, rr - 0.6, zr - 0.2), 2.8)
    # NẮP: chỏm dừa vạt ngang (bản lề sau)
    part(1, (0, -prof_c(-math.pi / 2), zc), (1, 0, 0), 112)
    shell(S, lambda U, V: np.stack([rad(SC_ + U * (1 - SC_) * 0.995, V * TAU) * np.cos(V * TAU), rad(SC_ + U * (1 - SC_) * 0.995, V * TAU) * np.sin(V * TAU), (SC_ + U * (1 - SC_)) * Hd], -1), 24, 96, VO)
    cut_disc(S, zc, lambda th: 0.0 * th, lambda th: prof_c(th), CAT, flip=False)
    CU = newmat(m_cuong())
    for k in range(4):                                # tai dừa (đài) + cuống
        a = k * TAU / 4 + 0.4; d = np.array([math.cos(a), math.sin(a), 0.0]); n = np.array([0, 0, 1.0]) + d * 0.35; n /= np.linalg.norm(n)
        ell(S, tuple(d * 1.9 + np.array([0, 0, Hd - 0.25])), 2.2, 1.3, 0.38, CU, axes=(np.cross(np.cross(n, d), n) * -1 if False else d, np.cross(n, d), n), nu=6, nv_=14)
    tb(S, (0, 0, Hd - 0.3), (0.3, 0.2, Hd + 1.6), 0.6, CU, nr=8, nl=3, cap=True)
    body()


# ================================================================== BẬC 2 · TRÁI BÍ ĐỎ
def trai_bi(S, rng):
    Rb, Hb = 14.0, 15.0; AC = 0.74 * math.pi
    R.LA = R.LB = Rb; R.ZL = Hb; R.LR = Rb
    VO = newmat(m_bi()); R.HFN[VO] = h_bi
    def lob(th): return 0.89 + 0.11 * np.abs(np.cos(5 * (th - math.pi / 2))) ** 0.6
    def surf(a, th):
        r = Rb * np.sin(a) * lob(th)
        z = Hb / 2 * (1 - np.cos(a)) + 1.6 * np.exp(-(a / 0.4) ** 2) - 2.0 * np.exp(-((math.pi - a) / 0.5) ** 2)
        return r, z
    rc0, zc = surf(AC, 0.0); rc0 = Rb * math.sin(AC)
    def prof_c(th): return Rb * math.sin(AC) * lob(th)
    CAT = newmat(m_lop(prof_c, ['#d9701e', '#f4b04a', '#f8c862'], [0.95, 0.82]))
    RUOT = newmat(m_com('#f0a43c', '#e4902c'))
    VANG = newmat(mat_kl('#e8b84a', hammer=False, streak=0.02, leaf=True))
    body()
    def outer(U, V, a0, a1):
        th = V * TAU; a = a0 + (a1 - a0) * U; r, z = surf(a, th)
        return np.stack([r * np.cos(th), r * np.sin(th), z], -1)
    shell(S, lambda U, V: outer(U, V, 0.0, AC), 44, 120, VO)
    cut_disc(S, zc, lambda th: 0.8 * prof_c(th), lambda th: prof_c(th), CAT, flip=True)
    zb = 3.2
    def cav(U, V):
        th = V * TAU; r = 0.8 * prof_c(th) * np.sin(np.pi / 2 * U) ** 0.5; z = zb + (zc - zb) * U ** 1.6
        return np.stack([r * np.cos(th), r * np.sin(th), z], -1)
    shell(S, cav, 20, 80, RUOT, flip=True)
    HAT = newmat(m_com('#f4e6c0', '#e8d6a6'))
    for k in range(18):                               # hột bí trong lòng
        a = rng.random() * TAU; d = 2 + rng.random() * 5
        ell(S, (d * math.cos(a), d * math.sin(a), zb + 0.6 + rng.random() * 1.2), 0.9, 0.55, 0.22, HAT, axes=(np.array([math.cos(a + 1), math.sin(a + 1), 0]), np.array([-math.sin(a + 1), math.cos(a + 1), 0]), np.array([0, 0, 1.0])), nu=4, nv_=10)
    coins(S, rng, zb + 1.2, 5.5, 18, VANG)
    ell(S, (-1.0, 0.6, zb + 3.2), 1.2, 1.2, 1.4, flat('#2fae6a'))
    # logo sen vàng trên đĩa sơn son trước bụng bí
    zm = Hb * 0.42
    sen_logo(S, rng, (0, Rb * 0.995 - 0.75, zm), 2.6, VANG, mplate=newmat(mat_son('#8e2418')), mring=VANG, mgem=flat('#e0302a'), plate_r=3.7)
    # NẮP: chỏm bí + cuống + tua + lá bí
    part(1, (0, -prof_c(-math.pi / 2), zc), (1, 0, 0), 108)
    shell(S, lambda U, V: outer(U, V, AC, math.pi * 0.999), 24, 120, VO)
    cut_disc(S, zc, lambda th: 0.0 * th, lambda th: prof_c(th), CAT, flip=False)
    CU = newmat(m_cuong())
    ztop = surf(math.pi * 0.999, 0)[1]
    pts = [(0.25 * math.sin(k * 0.6) + 0.12 * k, 0.1 * k, ztop - 0.6 + 1.05 * k) for k in range(6)]
    for i, (p0, p1) in enumerate(zip(pts, pts[1:])): tb(S, p0, p1, 1.5 - 0.12 * i, CU, nr=10, nl=3, cap=(i == 4))
    for k in range(5):                                # gân cuống loe ra mặt bí
        a = k * TAU / 5 + 0.3
        tb(S, (0, 0, ztop + 0.2), (2.4 * math.cos(a), 2.4 * math.sin(a), ztop - 0.3), 0.55, CU, nr=6, nl=2)
    hp = [(1.2 + 1.3 * math.cos(t * 2.2), -1.0 + 1.3 * math.sin(t * 2.2), ztop + 2.6 + t * 0.9) for t in np.linspace(0, 4.5, 40)]
    for p0, p1 in zip(hp, hp[1:]): tb(S, p0, p1, 0.18, CU, nr=5, nl=2)
    LA_ = newmat(m_la('#4e8a30', '#9cc860', 5)); R.HFN[LA_] = h_la(5)
    def leaf(U, V, off=0.0):                           # lá bí 5 thuỳ nằm nghiêng trên nắp
        th = (V - 0.5) * TAU * 0.92; rr = 7.5 * U * (0.62 + 0.38 * np.abs(np.cos(2.5 * th)) ** 0.7)
        lx = rr * np.cos(th); ly = rr * np.sin(th)
        p = np.stack([lx, ly, 0.6 * np.sin(U * np.pi) * 0.8 + 0.3 * np.cos(th * 5) * U + off], -1)
        c, s = math.cos(-0.7), math.sin(-0.7); M = np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
        tl = math.radians(-18); Mt = np.array([[1, 0, 0], [0, math.cos(tl), -math.sin(tl)], [0, math.sin(tl), math.cos(tl)]])
        return (p @ (Mt @ M).T) + np.array([1.5, -1.2, ztop + 0.4])
    grid(S, lambda U, V: leaf(U, V), 18, 60, LA_, (0, 0, 0), flip=False)
    grid(S, lambda U, V: leaf(U, V, -0.25), 18, 60, LA_, (0, 0, 0), flip=True)
    body()


# ================================================================== BẬC 3-4 · SEN
def guongsen(S, rng, z0, r, mpod, mtop, mseed, nseed=7):
    tb(S, (0, 0, z0 - 3.2), (0, 0, z0), r * 0.6, mpod, nr=16, nl=4)
    from kho3d import tube, disc
    tube(S, R.Pl(0, 0, z0 - 0.01), R.Pl(0, 0, z0 + 1.6), r * 0.62, mpod, nr=24, nl=3, taper=1 / 0.62)
    disc(S, R.Pl(0, 0, z0 + 1.6), (0, 0, 1), r, mtop, nr=6, na=32, dome=0.08)
    for k in range(nseed):
        if k == 0: x = y = 0.0
        else:
            a = (k - 1) * TAU / (nseed - 1); x, y = 0.6 * r * math.cos(a), 0.6 * r * math.sin(a)
        ell(S, (x, y, z0 + 1.75), r * 0.17, r * 0.17, r * 0.12, mseed, nu=5, nv_=12)


def sen(S, rng, gold):
    Rl = 17.0
    R.LA = R.LB = 12.0; R.ZL = 20.0; R.LR = 12.0
    body()
    if gold:
        SON = newmat(mat_son('#a8261e')); VB = newmat(mat_kl('#f0c24e', hammer=False, streak=0.02, leaf=True))
        from kho3d import tube, disc
        tube(S, R.Pl(0, 0, 0), R.Pl(0, 0, 2.2), 12.5, SON, nr=64, nl=3); disc(S, R.Pl(0, 0, 2.2), (0, 0, 1), 12.5, SON, nr=6, na=64)
        for z, rr in ((0.35, 12.9), (2.0, 12.9)):
            pts = [(rr * math.cos(t), rr * math.sin(t), z) for t in np.linspace(0, TAU, 49)]
            for p0, p1 in zip(pts, pts[1:]): tb(S, p0, p1, 0.45, VB, nr=6, nl=2)
        for k in range(12):
            a = k * TAU / 12; ell(S, (12.6 * math.cos(a), 12.6 * math.sin(a), 1.2), 0.7, 0.7, 0.7, flat('#2fae6a') if k % 2 else flat('#d81c3a'))
        z0 = 2.4
        LT = newmat(m_la('#3f8a3a', '#e8c25a', 22)); LB_ = newmat(m_la('#6aa04a', '#c8d880', 22))
        CAN = newmat(m_canh('#f6d266', '#e0a02c', '#b87e1c', kind='kl')); POD = newmat(mat_kl('#d8a83a', hammer=False))
        PT = newmat(mat_kl('#f0cf6a', hammer=False)); SEED = flat('#e0302a')
        rings = [(8, 3.6, 13.5, 4.6, 0.30, -0.62, 74, 0.0, 0.0), (8, 2.8, 11.8, 4.0, 0.16, -0.70, 58, math.pi / 8, 0.08), (8, 2.0, 9.6, 3.2, 0.05, -0.72, 36, 0.0, 0.16)]
    else:
        z0 = 0.6
        LT = newmat(m_la('#4a8c34', '#8cc45c', 22)); LB_ = newmat(m_la('#7aa856', '#a8cc80', 22))
        CAN = newmat(m_canh('#fbf2e6', '#e8689a', '#d8507e')); POD = newmat(m_com('#a8b84a', '#c8cc66'))
        PT = newmat(m_com('#d6d06a', '#c0c454')); SEED = newmat(m_com('#6f8e34', '#58782a'))
        rings = [(6, 3.4, 13.0, 4.8, 0.32, -0.60, 58, 0.0, 0.0), (6, 2.6, 11.4, 4.1, 0.18, -0.68, 40, math.pi / 6, 0.08), (5, 1.8, 9.2, 3.3, 0.06, -0.74, 22, 0.3, 0.16)]
    R.HFN[LT] = h_la(22); R.HFN[LB_] = h_la(22); R.HFN[CAN] = h_canh
    leaf_disc(S, z0, Rl, LT, LB_)
    VANG = newmat(mat_kl('#e8b84a', hammer=False, streak=0.02, leaf=True))
    coins(S, rng, z0 + 0.9, 3.0, 8, VANG)
    guongsen(S, rng, z0 + 5.6, 3.7, POD, PT, SEED)
    if not gold:
        ell(S, (0, 0, z0 + 8.2), 1.1, 1.1, 1.1, VANG)
    pid = 1
    for (n, r0, L, W, a0, a1, ang, ph0, dl) in rings:
        for k in range(n):
            phi = ph0 + k * TAU / n
            b = (1.3 * r0 * math.cos(phi), 1.3 * r0 * math.sin(phi), z0 + 1.0 + 0.15 * (k % 2))
            t = (-math.sin(phi), math.cos(phi), 0.0)
            part(pid, b, t, ang, delay=dl + 0.02 * k)
            petal(S, b, phi, L * 1.3, W * 1.3, a0, a1, CAN, cup=0.42)
            pid += 1
        body()
    if gold:
        ell(S, (0, 0, z0 + 8.4), 1.2, 1.2, 1.4, flat('#d81c3a'))
    body()


def build(S, rng, tier):
    if tier == 21: trai_dua(S, rng)
    elif tier == 22: trai_bi(S, rng)
    elif tier == 23: sen(S, rng, False)
    elif tier == 24: sen(S, rng, True)
