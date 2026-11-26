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


# ------------------------------------------------------------------ vật liệu (v2 11-26 Link "toàn 1 mảng màu": loang mảng lớn + thớ + gân + chi tiết nhỏ, không chấm đen)
def fbm(a, b, seed, oct=3):
    s = 0.0; w = 0.5; f = 1.0
    for i in range(oct):
        s = s + w * vnoise(a * f, b * f, seed + i * 7.1); w *= 0.5; f *= 2.1
    return s / (1 - 0.5 ** oct)


def tone(c, k):
    return c * k[:, None]


def m_dua_vo():
    """vỏ dừa xiêm: xanh lá đậm/nhạt loang mảng lớn, thớ dọc mảnh, 3 gờ sáng, bì vàng lốm đốm nhạt quanh tai, đốm bì nhạt li ti"""
    g0, g1, g2, g3, lent = hexc('#47782a'), hexc('#78a63c'), hexc('#b0a44c'), hexc('#5f8f30'), hexc('#c8d488')
    def f(uv, prm, pos, nrm):
        th, rr, z = azi(pos)
        big = fbm(np.cos(th) * 2.2 + z * 0.08, np.sin(th) * 2.2 + z * 0.11, 3.0)
        c = mix(g0, g1, np.clip((big - 0.35) * 1.6, 0, 1))
        st = vnoise(th * 55, z * 0.18, 8.0); st2 = 0.5 + 0.5 * np.sin(th * 140 + vnoise(th * 9, z * 0.2, 2.0) * 4)
        c = tone(c, 0.9 + 0.12 * st + 0.06 * st2)
        rid = np.abs(np.cos(1.5 * (th - 0.3))) ** 18                         # 3 gờ dọc
        c = c * (1 - 0.3 * rid)[:, None] + g1[None] * 1.15 * (0.3 * rid)[:, None]
        top = smooth(R.ZL * 0.78, R.ZL * 0.98, z) * (0.6 + 0.4 * fbm(th * 4, z * 0.4, 5.0))
        c = c * (1 - 0.55 * top)[:, None] + g2[None] * (0.55 * top)[:, None]
        bot = smooth(R.ZL * 0.25, R.ZL * 0.05, z)
        c = c * (1 - 0.3 * bot)[:, None] + g3[None] * (0.3 * bot)[:, None]
        ci = np.floor(th * 30); cz = np.floor(z * 1.1); h = hash1(ci, cz, 4.0)
        fx = th * 30 - ci - 0.5; fz = z * 1.1 - cz - 0.5
        dot = (h > 0.82) & (fx * fx + fz * fz * 3 < 0.05)
        c = np.where(dot[:, None], c * 0.55 + lent[None] * 0.45, c)
        return np.clip(c, 0, 1), nrm
    f.kind = 'son'
    return f


def m_lop(prof, cols, edges, fibre=True):
    """mặt cắt trái: vỏ mỏng -> lớp xơ có sợi toả tia -> lớp cơm, mỗi lớp có vân riêng"""
    cs = [hexc(c) for c in cols]
    def f(uv, prm, pos, nrm):
        th, rr, z = azi(pos)
        fr = rr / np.maximum(prof(th), 1e-6)
        out = np.tile(cs[-1], (len(fr), 1))
        for e, cc in sorted(zip(edges, cs[:-1]), key=lambda t: t[0]):
            out = np.where((fr > e)[:, None], cc[None], out)
        e0, e1 = min(edges), max(edges)
        mid = (fr > e0) & (fr <= e1)
        sợi = 0.5 + 0.5 * np.sin(th * 260 + vnoise(th * 30, fr * 8, 3.0) * 9)
        sợi2 = vnoise(th * 120, fr * 4, 6.0)
        k = np.where(mid, 0.82 + 0.22 * sợi * (0.6 + 0.4 * sợi2), 1.0)
        rim = np.exp(-((fr - e0) / 0.012) ** 2) * 0.25                     # mép cơm ngả vàng nhẹ
        inner = fr <= e0
        ring = 0.5 + 0.5 * np.sin(fr * 90 + vnoise(th * 6, fr * 6, 4.0) * 3)
        k = np.where(inner, 0.94 + 0.05 * ring + 0.03 * vnoise(th * 20, fr * 20, 9.0), k)
        out = tone(out, k) * (1 - rim)[:, None] + hexc('#e8d49a')[None] * rim[:, None]
        sk = fr > max(edges)
        out = np.where(sk[:, None], tone(out, 0.92 + 0.12 * vnoise(th * 80, fr * 10, 2.0)), out)
        return np.clip(out, 0, 1), nrm
    f.kind = 'go'
    return f


def h_lop(prof, edges):
    def h(P, UV, q):
        th, rr, z = azi(P)
        fr = rr / np.maximum(prof(th), 1e-6)
        e0, e1 = min(edges), max(edges)
        mid = (fr > e0) & (fr <= e1)
        return np.where(mid, 0.05 * np.sin(th * 260 + vnoise(th * 30, fr * 8, 3.0) * 9), 0.01 * vnoise(th * 20, fr * 20, 9.0)) - 0.06 * np.exp(-((fr - e0) / 0.01) ** 2)
    return h


def m_com(col, col2):
    """cơm / ruột trái: vân cong theo lòng, loang nhạt"""
    c, c2 = hexc(col), hexc(col2)
    def f(uv, prm, pos, nrm):
        x, y, z = R.loc(pos)
        th = np.arctan2(y, x)
        g = fbm(x * 0.35 + z * 0.2, y * 0.35, 4.0)
        ln = 0.5 + 0.5 * np.sin(z * 4.5 + vnoise(th * 5, z * 0.4, 3.0) * 4)
        return np.clip(tone(mix(c, c2, g * 0.8), 0.95 + 0.06 * ln), 0, 1), nrm
    f.kind = 'son'
    return f


def m_bi():
    """vỏ bí đỏ: sống múi cam vàng sáng, rãnh múi cam nâu (khối thật), sọc dọc mảnh, loang mảng, vệt xanh quanh cuống, chấm tròn vàng nhạt"""
    c0, c1, c2, gr, dot = hexc('#d9701e'), hexc('#f7ac48'), hexc('#a8501a'), hexc('#8a9a3a'), hexc('#f8d08a')
    def f(uv, prm, pos, nrm):
        th, rr, z = azi(pos)
        ph = 5 * (th - math.pi / 2); lobe = np.abs(np.cos(ph))
        c = mix(c2, c0, np.clip(lobe * 2.2, 0, 1))
        c = c * (1 - 0.55 * lobe ** 4)[:, None] + c1[None] * (0.55 * lobe ** 4)[:, None]
        big = fbm(np.cos(th) * 2 + z * 0.1, np.sin(th) * 2, 6.0)
        c = tone(c, 0.88 + 0.22 * big)
        st = 0.5 + 0.5 * np.sin(ph * 9 + vnoise(th * 6, z * 0.25, 2.0) * 3)          # sọc dọc mảnh trên mỗi múi
        c = c * (1 - 0.16 * st ** 3)[:, None] + c1[None] * (0.16 * st ** 3)[:, None]
        top = smooth(R.ZL * 0.72, R.ZL * 1.0, z) * (1 - smooth(0.0, 0.0001, 0 * z)) * (0.5 + 0.5 * fbm(th * 5, z * 0.5, 7.0))
        c = c * (1 - 0.45 * top)[:, None] + gr[None] * (0.45 * top)[:, None]
        ci = np.floor(th * 34); cz = np.floor(z * 1.3); h = hash1(ci, cz, 3.0)
        fx = th * 34 - ci - 0.5; fz = z * 1.3 - cz - 0.5
        sp = (h > 0.8) & (fx * fx + fz * fz < 0.04)
        c = np.where(sp[:, None], c * 0.6 + dot[None] * 0.4, c)
        return np.clip(c, 0, 1), nrm
    f.kind = 'son'
    return f


def m_cuong():
    """cuống bí: xơ dọc xanh rêu -> nâu vàng khô ở đầu cắt"""
    a, b, c3 = hexc('#6f7f36'), hexc('#c8b06e'), hexc('#a8a058')
    def f(uv, prm, pos, nrm):
        th = uv[:, 1] if uv.shape[1] > 1 else uv[:, 0]
        x, y, z = R.loc(pos)
        g = 0.5 + 0.5 * np.sin(th * TAU * 9 + vnoise(th * 9, z, 3.0) * 2)
        tz = smooth(R.ZL + 1.0, R.ZL + 5.5, z)
        c = mix(a, b, 0.6 * tz)
        c = c * (1 - 0.3 * g)[:, None] + c3[None] * (0.3 * g)[:, None]
        return np.clip(tone(c, 0.9 + 0.15 * vnoise(th * 30, z * 3, 5.0)), 0, 1), nrm
    f.kind = 'go'
    return f


def leaf_veins(U, V, nveins):
    ph = (V * nveins) % 1.0; d = np.minimum(ph, 1 - ph) * (U + 0.05) * 6
    v1 = np.exp(-(d / 0.09) ** 2) * smooth(0.02, 0.12, U)
    # gân phụ: chẽ xiên từ mỗi gân chính, lặp theo bán kính
    side = np.minimum(ph, 1 - ph) * (U + 0.05) * 6
    v2 = np.exp(-((((U * 14 - side * 2.2) % 1.0) - 0.5) / 0.07) ** 2) * smooth(0.15, 0.3, U) * 0.55
    return v1, v2


def m_la(col, vein, nveins, edge='#a8a850'):
    """lá: xanh loang mảng, gân chính + gân phụ sáng, đốm sáng giữa lá, mép ngả vàng"""
    c, v, ed = hexc(col), hexc(vein), hexc(edge)
    def f(uv, prm, pos, nrm):
        U, V = uv[:, 0], uv[:, 1]
        v1, v2 = leaf_veins(U, V, nveins)
        big = fbm(U * 3 * np.cos(V * TAU), U * 3 * np.sin(V * TAU), 2.0)
        cc = tone(c, 0.82 + 0.3 * big)
        cc = cc * (1 + 0.15 * U)[:, None]
        cen = np.exp(-(U / 0.12) ** 2) * 0.6
        cc = cc * (1 - cen)[:, None] + v[None] * cen[:, None]
        vv = np.clip(v1 + v2 * 0.7, 0, 1)
        cc = cc * (1 - 0.75 * vv)[:, None] + v[None] * (0.75 * vv)[:, None]
        e = smooth(0.86, 1.0, U) * (0.5 + 0.5 * vnoise(V * 60, U * 4, 3.0))
        cc = cc * (1 - 0.5 * e)[:, None] + ed[None] * (0.5 * e)[:, None]
        return np.clip(cc, 0, 1), nrm
    f.kind = 'go'
    return f


def h_la(nveins):
    def h(P, UV, q):
        U, V = UV[:, 0], UV[:, 1]
        v1, v2 = leaf_veins(U, V, nveins)
        return 0.1 * v1 + 0.04 * v2 + 0.012 * vnoise(U * 25, V * 70, 4.0)
    return h


def m_canh(base, tip, vein, kind='son', foot='#e8e6a0'):
    """cánh sen: gốc vàng xanh nhạt -> trắng ngà -> hồng đậm ở chót, mép sáng, gân dọc chẽ nhánh rõ, loang nhẹ"""
    b, t, v, ft = hexc(base), hexc(tip), hexc(vein), hexc(foot)
    def f(uv, prm, pos, nrm):
        U, V = uv[:, 0], uv[:, 1]
        e = np.abs(V - 0.5) * 2
        k = np.clip(U * 1.25 - 0.3 + e * 0.45 * U, 0, 1) ** 1.2
        c = mix(b, t, k)
        c = c * (1 - 0.5 * smooth(0.18, 0.0, U))[:, None] + ft[None] * (0.5 * smooth(0.18, 0.0, U))[:, None]
        ln = 0.5 + 0.5 * np.cos((V - 0.5) * TAU * 11 * (1.25 - 0.45 * U) + vnoise(U * 4, V * 3, 2.0) * 1.5)
        vl = ln ** 6 * smooth(0.05, 0.2, U)
        c = c * (1 - 0.35 * vl)[:, None] + v[None] * (0.35 * vl)[:, None]
        c = tone(c, 0.93 + 0.1 * fbm(U * 5, V * 4, 6.0))
        rim = smooth(0.82, 0.98, e) * 0.25
        c = c * (1 - rim)[:, None] + (t * 0.6 + 0.4)[None] * rim[:, None]
        return np.clip(c, 0, 1), nrm
    f.kind = kind
    return f


def h_canh(P, UV, q):
    U, V = UV[:, 0], UV[:, 1]
    ln = 0.5 + 0.5 * np.cos((V - 0.5) * TAU * 11 * (1.25 - 0.45 * U) + vnoise(U * 4, V * 3, 2.0) * 1.5)
    return 0.05 * ln ** 4 * np.sin(np.pi * np.clip(U, 0, 1)) + 0.012 * vnoise(U * 30, V * 30, 2.0)


def m_guong(col, col2):
    """gương sen: mặt trên vàng xanh có vòng lõm quanh lỗ hột, thân có gờ dọc"""
    c, c2 = hexc(col), hexc(col2)
    def f(uv, prm, pos, nrm):
        x, y, z = R.loc(pos)
        th = np.arctan2(y, x)
        rib = 0.5 + 0.5 * np.cos(th * 16)
        g = fbm(x * 0.8, y * 0.8 + z * 0.5, 3.0)
        cc = tone(mix(c, c2, g), 0.88 + 0.16 * rib)
        return np.clip(cc, 0, 1), nrm
    f.kind = 'son'
    return f


def h_guong(P, UV, q):
    x, y, z = R.loc(P); th = np.arctan2(y, x)
    return 0.07 * np.cos(th * 16) + 0.01 * vnoise(x * 5, y * 5 + z * 5, 3.0)


def h_soi(P, UV, q):                  # thớ dọc vỏ dừa + 3 gờ
    th, rr, z = azi(P)
    return 0.03 * vnoise(th * 90, z * 0.5, 7.0) + 0.015 * np.sin(th * 140 + vnoise(th * 9, z * 0.2, 2.0) * 4) + 0.08 * np.abs(np.cos(1.5 * (th - 0.3))) ** 18


def h_bi(P, UV, q):
    th, rr, z = azi(P)
    ph = 5 * (th - math.pi / 2)
    st = 0.5 + 0.5 * np.sin(ph * 9 + vnoise(th * 6, z * 0.25, 2.0) * 3)
    ci = np.floor(th * 34); cz = np.floor(z * 1.3); hh = hash1(ci, cz, 3.0)
    fx = th * 34 - ci - 0.5; fz = z * 1.3 - cz - 0.5
    return 0.035 * st ** 3 + 0.02 * vnoise(th * 60, z * 0.4, 6.0) + 0.03 * ((hh > 0.8) & (fx * fx + fz * fz < 0.04))


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
    CAT = newmat(m_lop(prof_c, ['#5f8f30', '#d8b57a', '#f6f3ea'], [0.955, 0.80])); R.HFN[CAT] = h_lop(prof_c, [0.955, 0.80])
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
        ell(S, tuple(d * 2.4 + np.array([0, 0, Hd - 0.45])), 2.9, 1.8, 0.42, CU, axes=(d, np.cross(n, d), n), nu=6, nv_=16)
        a2 = a + TAU / 8; d2 = np.array([math.cos(a2), math.sin(a2), 0.0]); n2 = np.array([0, 0, 1.0]) + d2 * 0.3; n2 /= np.linalg.norm(n2)
        ell(S, tuple(d2 * 1.6 + np.array([0, 0, Hd - 0.05])), 2.0, 1.3, 0.36, CU, axes=(d2, np.cross(n2, d2), n2), nu=6, nv_=14)
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
        z = Hb / 2 * (1 - np.cos(a)) + 1.6 * np.exp(-(a / 0.4) ** 2) - 1.1 * np.exp(-((math.pi - a) / 0.5) ** 2)
        return r, z
    rc0, zc = surf(AC, 0.0); rc0 = Rb * math.sin(AC)
    def prof_c(th): return Rb * math.sin(AC) * lob(th)
    CAT = newmat(m_lop(prof_c, ['#c8601c', '#f4b04a', '#f8c862'], [0.95, 0.82])); R.HFN[CAT] = h_lop(prof_c, [0.95, 0.82])
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
        tb(S, (0, 0, ztop + 0.5), (2.4 * math.cos(a), 2.4 * math.sin(a), ztop + 0.25), 0.5, CU, nr=6, nl=2)
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
        ell(S, (x, y, z0 + 1.62), r * 0.24, r * 0.24, r * 0.05, mpod, nu=4, nv_=14)
        ell(S, (x, y, z0 + 1.7), r * 0.16, r * 0.16, r * 0.11, mseed, nu=5, nv_=12)


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
        CAN = newmat(m_canh('#f8cc56', '#e8a42c', '#c08020', kind='vang', foot='#fae08a')); POD = newmat(mat_kl('#d8a83a', hammer=False)); R.HFN[POD] = h_guong
        PT = newmat(mat_kl('#f0cf6a', hammer=False)); SEED = flat('#e0302a')
        rings = [(8, 3.6, 13.5, 4.6, 0.30, -0.62, 74, 0.0, 0.0), (8, 2.8, 11.8, 4.0, 0.16, -0.70, 58, math.pi / 8, 0.12), (8, 2.0, 9.6, 3.2, 0.05, -0.72, 36, 0.0, 0.24)]
    else:
        z0 = 0.6
        LT = newmat(m_la('#4a8c34', '#8cc45c', 22)); LB_ = newmat(m_la('#7aa856', '#a8cc80', 22))
        CAN = newmat(m_canh('#fbf2e6', '#e8689a', '#d8507e')); POD = newmat(m_guong('#9cb244', '#c8cc66')); R.HFN[POD] = h_guong
        PT = newmat(m_guong('#d6d06a', '#c0c454')); SEED = newmat(m_com('#6f8e34', '#58782a'))
        rings = [(6, 3.4, 13.0, 4.8, 0.32, -0.60, 58, 0.0, 0.0), (6, 2.6, 11.4, 4.1, 0.18, -0.68, 40, math.pi / 6, 0.12), (5, 1.8, 9.2, 3.3, 0.06, -0.74, 22, 0.3, 0.24)]
    R.HFN[LT] = h_la(22); R.HFN[LB_] = h_la(22); R.HFN[CAN] = h_canh
    leaf_disc(S, z0, Rl, LT, LB_)
    GIOT = newmat(lambda uv, prm, pos, nrm: (np.tile(hexc('#e4f2f0'), (len(uv), 1)), nrm), kind='ngoc')
    for (U, th, rd) in ((0.62, 0.5, 0.75), (0.7, 0.62, 0.45), (0.55, 2.4, 0.6), (0.78, 3.9, 0.85), (0.66, 4.05, 0.4), (0.5, 5.3, 0.55)):
        rr = Rl * U * (1 + 0.04 * math.sin(7 * th + 1.0)); zz = z0 + 1.6 * U ** 2 + 0.55 * U ** 3 * math.sin(9 * th)
        ell(S, (rr * math.cos(th), rr * math.sin(th), zz + rd * 0.3), rd, rd, rd * 0.55, GIOT, nu=5, nv_=12)
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
            part(pid, b, t, ang, delay=dl)
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
