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


def nz_(v):
    v = np.asarray(v, float); return v / np.linalg.norm(v)


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
    g0, g1, g2, g3, lent = hexc('#3c6a24'), hexc('#88b246'), hexc('#b0a44c'), hexc('#5f8f30'), hexc('#c8d488')
    def f(uv, prm, pos, nrm):
        th, rr, z = azi(pos)
        big = fbm(np.cos(th) * 2.2 + z * 0.08, np.sin(th) * 2.2 + z * 0.11, 3.0)
        c = mix(g0, g1, np.clip((big - 0.3) * 2.4, 0, 1))
        st = vnoise(th * 55, z * 0.18, 8.0); st2 = 0.5 + 0.5 * np.sin(th * 140 + vnoise(th * 9, z * 0.2, 2.0) * 4)
        c = tone(c, 0.9 + 0.12 * st + 0.06 * st2)
        rid = np.abs(np.cos(1.5 * (th - 0.3))) ** 18                         # 3 gờ dọc
        c = c * (1 - 0.3 * rid)[:, None] + g1[None] * 1.15 * (0.3 * rid)[:, None]
        top = smooth(R.ZL * 0.78, R.ZL * 0.98, z) * (0.6 + 0.4 * fbm(th * 4, z * 0.4, 5.0))
        c = c * (1 - 0.55 * top)[:, None] + g2[None] * (0.55 * top)[:, None]
        bot = smooth(R.ZL * 0.25, R.ZL * 0.05, z)
        c = c * (1 - 0.3 * bot)[:, None] + g3[None] * (0.3 * bot)[:, None]
        mot = fbm(np.cos(th) * 7 + z * 0.3, np.sin(th) * 7 - z * 0.2, 11.0)      # loang nhạt nhỏ (không chấm)
        c = c * (1 - 0.18 * smooth(0.55, 0.8, mot))[:, None] + lent[None] * (0.18 * smooth(0.55, 0.8, mot))[:, None]
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
        k = np.where(inner, 0.84 + 0.1 * ring + 0.08 * vnoise(th * 14, fr * 14, 9.0) + 0.05 * np.sin(th * 90 + fr * 10), k)
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


def bi_dot(x, y, z, cell=0.8):
    """chấm tròn nhỏ mềm trên vỏ bí (ô 3D, không vệt)"""
    cx, cy, cz = np.floor(x / cell), np.floor(y / cell), np.floor(z / cell)
    h = hash1(cx + cz * 17.3, cy - cz * 5.1, 3.0); h2 = hash1(cx * 3.1 + cy, cz, 8.0); h3 = hash1(cy * 2.3 - cx, cz * 1.7, 9.0)
    ox, oy, oz = x / cell - cx - (0.3 + 0.4 * h2), y / cell - cy - (0.3 + 0.4 * h3), z / cell - cz - 0.5
    d = np.sqrt(ox * ox + oy * oy + oz * oz)
    return (h > 0.86) * smooth(0.16, 0.06, d)


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
        x, y, _ = R.loc(pos); sp = bi_dot(x, y, z)
        c = c * (1 - 0.35 * sp)[:, None] + dot[None] * (0.35 * sp)[:, None]
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


def leaf_veins(U, V, nveins, off=0.0):
    ph = ((V - off) * nveins + 0.04 * np.sin(U * 13 + V * 31) * U) % 1.0; d = np.minimum(ph, 1 - ph) * (U + 0.05) * 6
    v1 = np.exp(-(d / (0.035 + 0.04 * (1 - U))) ** 2) * smooth(0.02, 0.12, U) * (0.75 + 0.25 * vnoise(U * 20, V * 50, 7.0))
    # gân phụ: chẽ xiên từ mỗi gân chính, lặp theo bán kính
    side = np.minimum(ph, 1 - ph) * (U + 0.05) * 6
    v2 = np.exp(-((((U * 14 - side * 2.2) % 1.0) - 0.5) / 0.07) ** 2) * smooth(0.15, 0.3, U) * 0.55
    return v1, v2


def m_la(col, vein, nveins, edge='#a8a850', off=0.0, bloom=None):
    """lá: xanh loang mảng, gân chính + gân phụ sáng, đốm sáng giữa lá, mép ngả vàng"""
    c, v, ed = hexc(col), hexc(vein), hexc(edge)
    def f(uv, prm, pos, nrm):
        U, V = uv[:, 0], uv[:, 1]
        v1, v2 = leaf_veins(U, V, nveins, off)
        big = fbm(U * 3 * np.cos(V * TAU), U * 3 * np.sin(V * TAU), 2.0)
        cc = tone(c, 0.82 + 0.3 * big)
        if bloom is not None:                                              # phấn trắng mặt lá sen
            bl = fbm(U * 6 * np.cos(V * TAU) + 3, U * 6 * np.sin(V * TAU), 12.0)
            cc = cc * (1 - 0.3 * bl)[:, None] + hexc(bloom)[None] * (0.3 * bl)[:, None]
        cc = cc * (1 + 0.15 * U)[:, None]
        cen = np.exp(-(U / 0.12) ** 2) * 0.6
        cc = cc * (1 - cen)[:, None] + v[None] * cen[:, None]
        vv = np.clip(v1 + v2 * 0.45, 0, 1)
        cc = cc * (1 - 0.45 * vv)[:, None] + v[None] * (0.45 * vv)[:, None]
        e = smooth(0.86, 1.0, U) * (0.5 + 0.5 * vnoise(V * 60, U * 4, 3.0))
        cc = cc * (1 - 0.5 * e)[:, None] + ed[None] * (0.5 * e)[:, None]
        return np.clip(cc, 0, 1), nrm
    f.kind = 'go'
    return f


def h_la(nveins, off=0.0):
    def h(P, UV, q):
        U, V = UV[:, 0], UV[:, 1]
        v1, v2 = leaf_veins(U, V, nveins, off)
        return 0.1 * v1 + 0.04 * v2 + 0.012 * vnoise(U * 25, V * 70, 4.0)
    return h


def m_canh(base, tip, vein, kind='son', foot='#e8e6a0', tipexp=1.0, vk=0.2):
    """cánh sen: gốc vàng xanh nhạt -> trắng ngà -> hồng đậm ở chót, mép sáng, gân dọc chẽ nhánh rõ, loang nhẹ"""
    b, t, v, ft = hexc(base), hexc(tip), hexc(vein), hexc(foot)
    def f(uv, prm, pos, nrm):
        U, V = uv[:, 0], uv[:, 1]
        e = np.abs(V - 0.5) * 2
        k = np.clip(U * 1.25 - 0.3 + e * 0.45 * U, 0, 1) ** (1.2 * tipexp)
        c = mix(b, t, k)
        c = c * (1 - 0.5 * smooth(0.18, 0.0, U))[:, None] + ft[None] * (0.5 * smooth(0.18, 0.0, U))[:, None]
        ln = 0.5 + 0.5 * np.cos((V - 0.5) * TAU * (9 + 4 * vnoise(V * 3, 1.0, 4.0)) * (1.25 - 0.45 * U) + vnoise(U * 4, V * 3, 2.0) * 2.5)
        vl = ln ** 5 * smooth(0.05, 0.25, U) * (0.6 + 0.4 * vnoise(U * 8, V * 20, 5.0))
        c = c * (1 - vk * vl)[:, None] + v[None] * (vk * vl)[:, None]
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


def m_tai():
    """tai dừa khô: nâu đậm giữa -> nâu vàng mép, gân dọc khô"""
    a, b = hexc('#6a4a2a'), hexc('#c0a06a')
    def f(uv, prm, pos, nrm):
        x, y, z = R.loc(pos); r = np.hypot(x, y); th = np.arctan2(y, x)
        k = smooth(0.8, 4.2, r)
        c = mix(a, b, k * 0.85 + 0.15 * vnoise(th * 30, r * 3, 2.0))
        c = tone(c, 0.9 + 0.14 * (0.5 + 0.5 * np.sin(th * 70 + r * 2)))
        return np.clip(c, 0, 1), nrm
    f.kind = 'go'
    return f


def h_tai(P, UV, q):
    x, y, z = R.loc(P); r = np.hypot(x, y); th = np.arctan2(y, x)
    return 0.05 * np.sin(th * 70 + r * 2) + 0.02 * vnoise(th * 30, r * 6, 3.0)


def m_ngoc(col, col2):
    c, c2 = hexc(col), hexc(col2)
    def f(uv, prm, pos, nrm):
        x, y, z = R.loc(pos)
        g = fbm(x * 0.9 + z * 0.4, y * 0.9, 13.0)
        vein = smooth(0.46, 0.5, g) * smooth(0.54, 0.5, g)
        cc = mix(c, c2, g) * (1 - 0.3 * vein)[:, None] + hexc('#e8f4e8')[None] * (0.3 * vein)[:, None]
        return np.clip(cc, 0, 1), nrm
    f.kind = 'ngoc'
    return f


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
    x, y, _ = R.loc(P)
    return 0.035 * st ** 3 + 0.02 * vnoise(th * 60, z * 0.4, 6.0) + 0.04 * bi_dot(x, y, z)


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


def spine(r0, L, a0, a1, z0):
    us = np.linspace(0, 1, 200); th = a0 + (a1 - a0) * us ** 1.15
    dr = np.sin(th) * L / 199; dz = np.cos(th) * L / 199
    R_ = r0 + np.concatenate([[0], np.cumsum(dr[:-1])]); Z = z0 + np.concatenate([[0], np.cumsum(dz[:-1])])
    return dict(us=us, R=R_, Z=Z, th=th)


def wprof(U, W):
    return W * (0.3 + 0.7 * np.sin(np.pi * np.clip(U, 0, 1) ** 0.8)) * (1 - U ** 6)


def ring_fit(rings, z0, cup, thick):
    """xếp các vòng cánh sen cho búp khép KHÔNG đâm xuyên: cánh cùng vòng giáp mép (rộng <= R*tan(pi/n)),
    vòng trong luôn nằm lọt trong mặt trong của vòng ngoài và chót thấp hơn"""
    out = []; prev = None
    for (n, r0, L, W, a0, a1, ang, ph0, dl) in rings:
        Ls, f = L, 1.0
        for it in range(30):
            sp = spine(r0, Ls, a0, a1, z0)
            if prev is None: break
            pw = np.minimum(wprof(prev['us'], prev['W']), 1.35 * prev['R'] * math.tan(math.pi / prev['n']))
            B = prev['R'] - 0.55 * cup * pw - thick - 0.4
            zt = prev['Z'][-1] - 1.2
            if sp['Z'][-1] > zt:
                Ls = Ls * (zt - z0) / (sp['Z'][-1] - z0) * 0.995; continue
            Bi = np.interp(sp['Z'], prev['Z'], B)
            k = np.min(Bi / np.maximum(sp['R'] * f, 1e-3))
            if k >= 0.999: break
            f *= max(k, 0.3) * 0.995
        sp['R'] = sp['R'] * f; print('ring', n, 'f %.2f L %.1f->%.1f' % (f, L, Ls))
        sp.update(n=n, W=W, ang=ang, ph0=ph0, dl=dl)
        out.append(sp); prev = sp
    return out


def petal(S, sp, phi, mat, cup=0.35, thick=0.28, nu=28, nv_=16, dr=0.0, wk=1.35):
    """cánh sen theo xương sp (R,Z,th theo u), góc phi; rộng tối đa giáp cánh bên"""
    d = np.array([math.cos(phi), math.sin(phi), 0.0]); t = np.array([-math.sin(phi), math.cos(phi), 0.0]); zz = np.array([0, 0, 1.0])
    us, Rr, Zz, th = sp['us'], sp['R'], sp['Z'], sp['th']; n, W = sp['n'], sp['W']
    def F(U, V, off=0.0):
        rad = np.interp(U, us, Rr) + dr * np.sin(np.pi * np.clip(U, 0, 1)) ** 0.5; hz = np.interp(U, us, Zz); tt = np.interp(U, us, th)
        w = np.minimum(wprof(U, W), wk * rad * math.tan(math.pi / n))
        vv = (V - 0.5) * 2
        o = np.cos(tt)[..., None] * d - np.sin(tt)[..., None] * zz
        return rad[..., None] * d + hz[..., None] * zz + (vv * w)[..., None] * t - o * (cup * w * vv ** 2)[..., None] + o * off
    grid(S, lambda U, V: F(U, V), nu, nv_, mat, (0, 0, 0), flip=False)
    grid(S, lambda U, V: F(U, V, -thick), nu, nv_, mat, (0, 0, 0), flip=True)
    return (Rr[0] * d[0], Rr[0] * d[1], Zz[0]), tuple(t)


def bong_sen(S, z0, N, mats, r0=3.4, Rb=5.4, L=20.0, A0=0.8, open_out=68, open_in=12, smin=0.6, cup=0.32):
    """BÔNG SEN THẬT (v5 11-26): N cánh xếp xoắn góc vàng 137.5°, mỗi cánh rộng ~90° nên chỗ nào cũng chồng 3 lớp.
    Búp khép: cánh trong là bản vị tự thu nhỏ của cánh ngoài -> mặt cánh lồng nhau, không đâm xuyên.
    Lúc NỞ mỗi cánh BIẾN HÌNH (morph) sang dáng cánh sen nở thật: muỗng bầu khum lòng, xoè ra từ gốc, chót hơi vểnh lên (không móc)."""
    GA = math.radians(137.508)
    _u = np.linspace(0, 1, 2001); _b = 0.05 + (r0 - 0.05) * (1 - _u) ** 1.2 + Rb * np.sin(np.pi * _u ** 0.85) * (1 - 0.25 * _u)
    UM = float(_u[_b.argmax()]); RM = float(_b.max()) - 0.05
    for i in range(N):
        sc = 1.0 - (1.0 - smin) * i / max(N - 1, 1)
        phi = i * GA; k = i / max(N - 1, 1)
        d = np.array([math.cos(phi), math.sin(phi), 0.0]); t = np.array([-math.sin(phi), math.cos(phi), 0.0]); zz = np.array([0, 0, 1.0])
        def Rc(U, sc=sc):                                                 # dáng búp: bụng bầu, nửa trên là VÒM TRÒN (siêu elip) -> đỉnh búp tròn, không nhọn
            U = np.asarray(U, dtype=float)
            base = 0.05 + (r0 - 0.05) * (1 - U) ** 1.2 + Rb * np.sin(np.pi * U ** 0.85) * (1 - 0.25 * U)
            s_ = np.clip((U - UM) / (1 - UM), 0, 1)
            dome = RM * np.clip(1 - s_ ** 1.08, 0, 1) ** 0.52 + 0.05       # giọt nước: thon dần lên, chót tròn nhỏ (không kim, không trứng)
            return np.where(U < UM, base, dome) * sc
        def Aw(U): return A0 * (0.45 + 0.55 * np.sin(np.pi / 2 * np.clip(U / 0.55, 0, 1))) * (1 - 0.15 * U ** 4) + 0.01        # búp khép: cánh rộng tới chót -> đỉnh búp kín
        def F(U, V, sc=sc, phi=phi):
            U = 1 - (1 - np.asarray(U, dtype=float)) ** 1.7                # dồn hàng lưới về phía đỉnh vòm -> đỉnh tròn mịn, không gãy khúc
            vb = (V - 0.5) * 2; Rr = Rc(U) * (1 + 0.06 * (1 - vb ** 2) * np.sin(np.pi * U) ** 0.7);   scz = 1 - (1 - sc) * 0.1; Zz = z0 + L * U * scz + 0.6 * np.sin(np.pi * U) * scz   # cánh trong cao gần bằng cánh ngoài -> đỉnh búp liền một vòm, không lòi mép
            a = phi + (V - 0.5) * 2 * Aw(U)
            return np.stack([Rr * np.cos(a), Rr * np.sin(a), Zz], -1)
        al = math.radians(open_out + (open_in - open_out) * k ** 0.8); be = 0.45 * al
        us = np.linspace(0, 1, 200); th = al - be * us ** 1.3; Ls = 16.0 * sc * (1.08 - 0.16 * (1 - k))
        sr = r0 * sc + np.concatenate([[0], np.cumsum(np.sin(th) * Ls / 199)[:-1]]); sz = z0 + np.concatenate([[0], np.cumsum(np.cos(th) * Ls / 199)[:-1]])
        uu_ = np.linspace(0, 1, 200); Wm = 1.08 * float(np.max(Rc(uu_) * Aw(uu_)))
        def Fo(U, V, sc=sc, Wm=Wm, k=k, d=d, t=t, sr=sr, sz=sz, th=th, us=us):
            rad = np.interp(U, us, sr); hz = np.interp(U, us, sz); tt = np.interp(U, us, th)
            ex = 5.0 + 2.0 * (1 - k)                              # cánh ngoài chót tròn bầu hơn, cánh trong giữ dáng thuôn
            w = Wm * (1 + 0.15 * (1 - k)) * (0.52 + 0.48 * np.sin(np.pi * np.clip(U, 0, 1) ** (0.65 + 0.35 * (1 - k)))) * np.sqrt(np.clip(1 - U ** ex, 0, 1)) + 0.04   # cánh sen nở: bầu dục, chót tròn (chỉ nhú mũi nhỏ)
            vv = (V - 0.5) * 2
            o = np.cos(tt)[..., None] * d - np.sin(tt)[..., None] * zz
            return rad[..., None] * d + hz[..., None] * zz + (vv * w)[..., None] * t - o * (cup * (1 - 0.6 * np.clip(U, 0, 1) ** 3) * w * vv ** 2 + 0.25 * np.sin(np.pi * U) * w * 0)[..., None]
        b = (r0 * sc * math.cos(phi), r0 * sc * math.sin(phi), z0)
        part(100 + i, b, (-math.sin(phi), math.cos(phi), 0.0), 0.0, delay=0.32 * k)
        R.MORPHF[0] = (lambda U, V, Fo=Fo: R.rot(Fo(U, V) + np.array([R.C0, R.C0, 0.0])))
        grid(S, F, 40, 18, mats[min(int(k * len(mats)), len(mats) - 1)], (0, 0, 0), flip=False)
        R.MORPHF[0] = None
    body()


def nhuy(S, z0, r_in, r_out, n, mstem, manth):
    """vòng nhụy vàng quanh gương sen: sợi chỉ mảnh cong ra, bao phấn ở đầu"""
    for k in range(n):
        a = k * TAU / n + 0.13 * math.sin(k * 7.3)
        L_ = 2.4 + 0.5 * math.sin(k * 3.1)
        p0 = (r_in * math.cos(a), r_in * math.sin(a), z0)
        p1 = ((r_out + 0.3 * math.sin(k * 5)) * math.cos(a), (r_out + 0.3 * math.sin(k * 5)) * math.sin(a), z0 + L_)
        pm = tuple((np.array(p0) + np.array(p1)) / 2 + np.array([0, 0, 0.3]))
        tb(S, p0, pm, 0.09, mstem, nr=4, nl=2); tb(S, pm, p1, 0.08, mstem, nr=4, nl=2)
        dd = np.array(p1) - np.array(pm); dd /= np.linalg.norm(dd)
        ell(S, tuple(np.array(p1) + dd * 0.35), 0.16, 0.16, 0.45, manth, axes=(nz_(np.cross(dd, [0, 0, 1.0]) + 1e-6), nz_(np.cross(dd, np.cross(dd, [0, 0, 1.0])) + 1e-6), dd), nu=4, nv_=8)


def torus(S, z, Rr, r, mat, n=96):
    grid(S, lambda U, V: np.stack([(Rr + r * np.cos(U * TAU)) * np.cos(V * TAU), (Rr + r * np.cos(U * TAU)) * np.sin(V * TAU), z + r * np.sin(U * TAU)], -1), 10, n, mat, (0, 0, 0), close_v=True, flip=False)


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
    ED = [0.955, 0.70, 0.645]                      # vỏ xanh | cơm xơ trắng ngà | gáo nâu | cơm dừa
    CAT = newmat(m_lop(prof_c, ['#5f8f30', '#e0cfa4', '#7a5230', '#e2dac2'], ED)); R.HFN[CAT] = h_lop(prof_c, ED)
    COM = newmat(m_com('#f6f3ea', '#e8e4d2'))
    VANG = newmat(mat_kl('#e0a538', hammer=False, streak=0.02, leaf=True)); R.KIND[VANG] = 'vang'
    body()
    shell(S, lambda U, V: np.stack([rad(U * SC_, V * TAU) * np.cos(V * TAU), rad(U * SC_, V * TAU) * np.sin(V * TAU), U * SC_ * Hd], -1), 40, 96, VO)
    cut_disc(S, zc, lambda th: 0.62 * prof_c(th), lambda th: prof_c(th), CAT, flip=True)
    zb = Hd * 0.46
    def cav(U, V):                                   # lòng dừa: cơm trắng
        th = V * TAU; r = 0.62 * prof_c(th) * np.sin(np.pi / 2 * U) ** 0.55; z = zb + (zc - zb) * U ** 1.4
        return np.stack([r * np.cos(th), r * np.sin(th), z], -1)
    shell(S, cav, 20, 72, COM, flip=True)
    coins(S, rng, zb + 1.5, 2.0, 12, VANG)
    ell(S, (0.4, 0.3, zb + 3.2), 1.1, 1.1, 1.3, flat('#d81c3a'))
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
    TAI = newmat(m_tai()); R.HFN[TAI] = h_tai; CU = TAI
    for k in range(3):                                # tai dừa: 3 cánh lớn + 3 cánh nhỏ xen, nâu khô xếp hình sao
        for big in (1, 0):
            a = k * TAU / 3 + 0.4 + (0 if big else TAU / 6); d = np.array([math.cos(a), math.sin(a), 0.0])
            ln, wd, lift = (3.6, 2.3, 0.3) if big else (2.4, 1.5, 0.5)
            n = np.array([0, 0, 1.0]) + d * 0.45; n /= np.linalg.norm(n)
            ell(S, tuple(d * ln * 0.62 + np.array([0, 0, Hd - 0.55 + lift])), ln, wd, 0.45, TAI, axes=(nz_(d - n * (n @ d)), nz_(np.cross(n, d)), n), nu=6, nv_=18)
    tb(S, (0, 0, Hd - 0.2), (0.25, 0.15, Hd + 1.4), 0.75, CU, nr=10, nl=3, cap=True)
    body()


# ================================================================== BẬC 2 · TRÁI BÍ ĐỎ
def trai_bi(S, rng):
    Rb, Hb = 14.0, 15.0; AC = 0.74 * math.pi
    R.LA = R.LB = Rb; R.ZL = Hb; R.LR = Rb
    VO = newmat(m_bi()); R.HFN[VO] = h_bi
    def lob(th): return 0.89 + 0.11 * np.abs(np.cos(5 * (th - math.pi / 2))) ** 0.6
    def surf(a, th):
        r = Rb * np.sin(a) * lob(th) * (1 - 0.035 * np.exp(-((a - AC) / 0.035) ** 2))     # vết khoét nắp: rãnh lõm quanh đường cắt
        z = Hb / 2 * (1 - np.cos(a)) + 1.6 * np.exp(-(a / 0.4) ** 2) - 1.1 * np.exp(-((math.pi - a) / 0.5) ** 2)
        return r, z
    rc0, zc = surf(AC, 0.0); rc0 = Rb * math.sin(AC)
    def prof_c(th): return Rb * math.sin(AC) * lob(th) * 0.965
    CAT = newmat(m_lop(prof_c, ['#c8601c', '#f4b04a', '#eea040'], [0.95, 0.82])); R.HFN[CAT] = h_lop(prof_c, [0.95, 0.82])
    RUOT = newmat(m_com('#f0a43c', '#e4902c'))
    VANG = newmat(mat_kl('#e0a538', hammer=False, streak=0.02, leaf=True)); R.KIND[VANG] = 'vang'
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
    CU = newmat(m_cuong()); R.HFN[CU] = lambda P, UV, q: 0.06 * np.cos(UV[:, 1] * TAU * 5) + 0.015 * np.sin(UV[:, 1] * TAU * 40)
    ztop = surf(math.pi * 0.999, 0)[1]
    aa = np.linspace(AC, math.pi, 400); rr_ = Rb * np.sin(aa); zz_ = Hb / 2 * (1 - np.cos(aa)) - 1.1 * np.exp(-((math.pi - aa) / 0.5) ** 2)
    def zon(r): return float(np.interp(r, rr_[::-1], zz_[::-1]))      # cao độ mặt nắp theo bán kính
    # CUỐNG: 5 khía, loe gốc mọc liền từ đỉnh trái (chân chìm vào thịt bí), cong nhẹ, đầu cắt khô
    def stem(U, V):
        s_ = U; th = V * TAU
        cx = 0.9 * s_ ** 2; cy = 0.35 * s_ ** 2; cz = ztop - 1.2 + 6.0 * s_
        r = 1.05 * (1 + 1.6 * np.exp(-s_ / 0.1)) * (1 + 0.13 * np.cos(5 * th)) * (1 - 0.12 * s_)
        return np.stack([cx + r * np.cos(th), cy + r * np.sin(th), cz], -1)
    grid(S, stem, 30, 40, CU, (0, 0, 0), close_v=True, flip=False)
    from kho3d import disc
    DRY = newmat(m_com('#b8a070', '#a08858'))
    disc(S, R.Pl(0.9, 0.35, ztop + 4.8), (0.12, 0.05, 1), 1.02 * 0.88, DRY, nr=4, na=24)
    # DÂY BÍ: bò từ gốc cuống ra trên mặt nắp, có đốt; cuống lá dựng lên nối vào giữa lá; tua cuốn mọc ở đốt
    VI = newmat(m_cuong()); R.HFN[VI] = R.HFN[CU]
    fv = -0.75
    vp = []
    for t_ in np.linspace(0, 1, 24):
        r = 1.6 + 6.6 * t_; ph = fv + 0.5 * t_
        vp.append((r * math.cos(ph), r * math.sin(ph), zon(r) + 0.45 + 0.35 * math.sin(t_ * math.pi)))
    for i, (p0, p1) in enumerate(zip(vp, vp[1:])): tb(S, p0, p1, 0.62 - 0.012 * i, VI, nr=8, nl=2)
    for j in (8, 16):                                  # đốt dây
        ell(S, vp[j], 0.85, 0.85, 0.7, VI, nu=5, nv_=12)
    node = np.array(vp[10]); lc = node + np.array([-1.6, -1.2, 4.2])
    pts = [node + (lc - node) * t_ + np.array([0, 0, 1.0 * math.sin(t_ * math.pi)]) for t_ in np.linspace(0, 1, 9)]
    for p0, p1 in zip(pts, pts[1:]): tb(S, tuple(p0), tuple(p1), 0.38, VI, nr=7, nl=2)
    n2 = np.array(vp[16]); hp = [tuple(n2 + np.array([0.5 * math.cos(t_ * 2.4) * (1 - t_ / 9) + 0.25 * t_, 0.5 * math.sin(t_ * 2.4) * (1 - t_ / 9), 0.42 * t_])) for t_ in np.linspace(0, 7, 46)]
    for p0, p1 in zip(hp, hp[1:]): tb(S, p0, p1, 0.16, VI, nr=5, nl=2)
    # LÁ BÍ: 5 thuỳ răng cưa, gân chân vịt toả từ chỗ cuống lá đính, mặt lá gợn, nghiêng đón nắng
    LA_ = newmat(m_la('#4a8a2e', '#a8d070', 4.6, edge='#8a9a40', off=0.5)); R.HFN[LA_] = h_la(4.6, 0.5)
    tl = math.radians(24); M = np.array([[1, 0, 0], [0, math.cos(tl), -math.sin(tl)], [0, math.sin(tl), math.cos(tl)]])
    cz_, sz_ = math.cos(-2.3), math.sin(-2.3); Mz = np.array([[cz_, -sz_, 0], [sz_, cz_, 0], [0, 0, 1]])
    def leaf(U, V, off=0.0):
        th = (V - 0.5) * TAU * 0.92
        lobe = 0.6 + 0.4 * np.abs(np.cos(2.5 * th)) ** 0.8
        ser = 1 + 0.04 * np.sin(th * 46) * U ** 4
        rr = 7.4 * U * lobe * ser
        z = 0.9 * np.sin(np.pi * U) * 0.7 + 0.35 * np.cos(th * 5) * U ** 2 - 0.5 * U ** 2 + off
        p = np.stack([rr * np.sin(th), -rr * np.cos(th) * 0 + rr * np.cos(th), z], -1)
        return p @ (Mz @ M).T + lc
    grid(S, lambda U, V: leaf(U, V), 22, 72, LA_, (0, 0, 0), flip=False)
    LB2 = newmat(m_la('#6a9a48', '#b8d090', 4.6, edge='#9aa858', off=0.5))
    grid(S, lambda U, V: leaf(U, V, -0.22), 22, 72, LB2, (0, 0, 0), flip=True)
    # mặt dưới nắp: ruột xơ + hột dính
    for k in range(9):
        a = rng.random() * TAU; d = 1.5 + rng.random() * 4.5
        ax = np.array([math.cos(a + 1.2), math.sin(a + 1.2), 0])
        ell(S, (d * math.cos(a), d * math.sin(a), zc - 0.2), 0.95, 0.58, 0.22, HAT, axes=(ax, np.array([-ax[1], ax[0], 0]), np.array([0, 0, 1.0])), nu=4, nv_=10)
    XO = newmat(m_com('#e8962e', '#d8822a'))
    for k in range(7):
        a = rng.random() * TAU; d = 1 + rng.random() * 5
        ell(S, (d * math.cos(a), d * math.sin(a), zc - 0.35), 0.4, 0.4, 0.9, XO, nu=4, nv_=8)
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
        for z, rr in ((0.35, 12.9), (2.0, 12.9)): torus(S, z, rr, 0.45, VB)
        for k in range(12):
            a = k * TAU / 12; ell(S, (12.6 * math.cos(a), 12.6 * math.sin(a), 1.2), 0.7, 0.7, 0.7, flat('#2fae6a') if k % 2 else flat('#d81c3a'))
        z0 = 2.4
        LT = newmat(m_la('#2a8058', '#d8b850', 22, edge='#c8a040', bloom='#6cb090')); LB_ = newmat(m_la('#4a9a6a', '#d8d080', 22))
        CANS = [newmat(m_canh('#f6c64a', '#d85870', '#b07418', kind='vang', foot='#fae08a', tipexp=4.5)),
                newmat(m_canh('#f8d060', '#e8a02c', '#b88020', kind='vang', foot='#fae6a0')),
                newmat(m_canh('#fae4a0', '#e8708a', '#c89040', kind='vang', foot='#fff0c0', tipexp=1.6))]
        POD = newmat(m_ngoc('#2f8f62', '#5cc090')); R.HFN[POD] = h_guong
        PT = newmat(m_ngoc('#48a874', '#8ad8a8')); SEED = newmat(lambda uv, prm, pos, nrm: (np.tile(hexc('#d81c3a'), (len(uv), 1)), nrm), kind='ngoc')
        rings = [(8, 3.6, 13.5, 4.6, 0.32, -0.72, 74, 0.0, 0.0), (8, 3.1, 11.4, 4.0, 0.24, -0.80, 58, math.pi / 8, 0.12), (8, 2.7, 9.0, 3.2, 0.16, -0.9, 36, 0.0, 0.24)]
    else:
        z0 = 0.6
        LT = newmat(m_la('#35703c', '#8eb486', 22, edge='#8a7a40', bloom='#9cb8aa')); LB_ = newmat(m_la('#6a9a5a', '#b0cc98', 22, edge='#9a8a50'))
        CAN = newmat(m_canh('#fbe8ee', '#e45890', '#d04a7a', tipexp=0.55)); CANS = [CAN, CAN, CAN]; POD = newmat(m_guong('#9cb244', '#c8cc66')); R.HFN[POD] = h_guong
        PT = newmat(m_guong('#d6d06a', '#c0c454')); SEED = newmat(m_com('#6f8e34', '#58782a'))
        rings = [(6, 3.4, 13.0, 4.8, 0.34, -0.72, 58, 0.0, 0.0), (6, 2.9, 11.0, 4.1, 0.24, -0.80, 40, math.pi / 6, 0.12), (6, 2.5, 8.6, 3.3, 0.16, -0.9, 22, 0.0, 0.24)]
    R.HFN[LT] = h_la(22); R.HFN[LB_] = h_la(22)
    for c_ in CANS: R.HFN[c_] = h_canh
    leaf_disc(S, z0, Rl, LT, LB_)
    GIOT = newmat(lambda uv, prm, pos, nrm: (np.tile(hexc('#e8f6f2'), (len(uv), 1)), nrm), kind='ngoc')
    for (U, th, rd) in ((0.62, 0.5, 0.55), (0.68, 0.6, 0.3), (0.55, 2.4, 0.45), (0.78, 3.9, 0.6), (0.5, 5.3, 0.4)):
        rr = Rl * U * (1 + 0.04 * math.sin(7 * th + 1.0)); zz = z0 + 1.6 * U ** 2 + 0.55 * U ** 3 * math.sin(9 * th)
        ell(S, (rr * math.cos(th), rr * math.sin(th), zz + rd * 0.2), rd, rd * 0.92, rd * 0.62, GIOT, nu=7, nv_=14)
    VANG = newmat(mat_kl('#e0a538', hammer=False, streak=0.02, leaf=True)); R.KIND[VANG] = 'vang'
    guongsen(S, rng, z0 + 4.6, 2.7, POD, PT, SEED)
    NH = newmat(m_com('#f2c838', '#e8b020')); BP = newmat(m_com('#fae27a', '#f4d050'))
    nhuy(S, z0 + 5.3, 2.2, 3.3, 44, NH, BP)
    if not gold:
        ell(S, (0, 0, z0 + 7.0), 0.9, 0.9, 0.9, VANG)
    bong_sen(S, z0 + 0.8, 24 if gold else 18, CANS, open_out=70 if gold else 62, open_in=16 if gold else 10)
    if gold:
        ell(S, (0, 0, z0 + 7.1), 0.9, 0.9, 1.0, flat('#d81c3a'))
    body()


def build(S, rng, tier):
    if tier == 21: trai_dua(S, rng)
    elif tier == 22: trai_bi(S, rng)
    elif tier == 23: sen(S, rng, False)
    elif tier == 24: sen(S, rng, True)
