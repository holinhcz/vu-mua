# Đế gỗ tràm đặt giỏ đơn hàng - cùng camera/khung với giotre.py (cùng góc trái trên, cùng bề ngang 616),
# cao hơn để lộ chân đế. Thứ tự vẽ: de.png -> gioN_sau -> icon -> gioN_truoc (cùng toạ độ 0,0).
# python3 de.py OUTDIR [W]
import sys, os, numpy as np
from PIL import Image
import giotre as G
from giotre import R, surf, shade, TRAM, VANG, hx, rnd

GODAM = dict(hi=hx('e8b070'), b=hx('cc8c50'), lo=hx('aa6c3a'), dp=hx('7c4a26'))   # mép/chân gỗ tràm sẫm 1 bậc


def build_de(W):
    g = G.Gio(**dict(G.G_ALL, n=2.3))
    sc = W / 2.85
    Hh = int(W * 1.0)
    r = R(W, Hh, sc, W / 2, int(W * 0.80) * 0.58)
    RX, RY = 1.14, 0.69          # mặt đế (giỏ đáy ~0.83x0.49 nằm giữa)
    T0, T1 = -0.004, -0.19      # mặt trên, mặt dưới
    BV = 0.022                   # vát mép

    def ring(T, k):
        c, si = np.cos(T), np.sin(T)
        n = 2.3
        rr = (np.abs(c) ** n + np.abs(si) ** n) ** (-1.0 / n)
        return c * rr * RX * k, si * rr * RY * k

    # mặt trên: ván ghép chạy ngang
    def top(T, V):
        x, y = ring(T, V * (1 - BV / RY))
        return np.stack([x, y, np.full_like(x, T0)], 1)

    def t_top(T, V, P, N):
        x, y = P[:, 0], P[:, 1]
        pw = 0.20
        j = np.floor((y + 1.1) / pw); f = (y + 1.1) / pw - j
        gr = np.mod(x * 3.1 + 0.18 * np.sin(x * 9 + j * 2.3) + rnd(j, 1) + f * 0.4, 0.33) / 0.33
        z = np.full(len(x), 2)
        z = np.where(gr < 0.10, 1, z)
        z = np.where((gr > 0.55) & (gr < 0.62), 3, z)
        z = np.where(f > 0.80, 3, z)
        z = np.where((f < 0.05) | (f > 0.96), 0, z)        # khe ván
        # mắt gỗ
        kx = (np.mod(x + rnd(j, 3) * 2, 0.9) - 0.45)
        knot = np.hypot(kx / 0.05, (f - 0.5) / 0.22) < 1.0
        # 2 thanh nẹp đóng đinh ngang qua ván (chốt tre)
        peg = (np.abs(np.abs(x) - 0.62) < 0.02) & (np.mod(f, 1.0) > 0.35) & (np.mod(f, 1.0) < 0.65)
        z = np.where(peg, 0, z)
        c = shade(TRAM, z, np.tile([0, 0, 1.0], (len(x), 1)))
        return c * (1 + 0.06 * (rnd(j, 5) - 0.5))[:, None]

    # vát mép + hông đế
    def side(T, V):
        # V 0..1: 0 = mép trên (đã vát), 1 = đáy
        k0 = 1 - BV / RY
        kk = np.where(V < 0.25, k0 + (1 - k0) * (V / 0.25), 1.0 - 0.02 * (V - 0.25))
        z = np.where(V < 0.25, T0 - (V / 0.25) * BV * 0.8, T0 - BV * 0.8 + (T1 - T0 + BV * 0.8) * (V - 0.25) / 0.75)
        x, y = ring(T, kk)
        return np.stack([x, y, z], 1)

    def t_side(T, V, P, N):
        z = np.where(V < 0.25, 3, 2)
        gr = np.mod(V * 3 + 0.25 * np.sin(T * 30), 1.0)
        z = np.where((V >= 0.25) & (gr < 0.08), 1, z)
        ln = (np.abs(V - 0.33) < 0.03) | (np.abs(V - 0.93) < 0.03)
        z = np.where(ln, 0, z)
        # sóng nước chạm nổi: dải sóng cuộn, mặt trên sáng, mép dưới sẫm
        ph = T * 34
        cy = 0.63 + 0.13 * np.sin(ph)
        dv = V - cy
        band = (V > 0.40) & (V < 0.87)
        z = np.where(band & (np.abs(dv) < 0.05), 3, z)
        z = np.where(band & (dv < -0.05) & (dv > -0.095), 0, z)
        return shade(GODAM, z, N)

    def oid_side(T, V, P, N): return np.where(P[:, 1] < 0, 4, 3)

    NT = int(7200 * G.DENS)
    surf(r, top, 0, 2 * np.pi, 0, 1, 7200, 1100, t_top, 1)
    surf(r, side, 0, 2 * np.pi, 0, 1, 7200, 180, t_side, oid_side)

    # 4 chân quỳ cong ra ngoài
    for th0 in (np.pi * 0.20, np.pi * 0.80, np.pi * 1.20, np.pi * 1.80):
        x0, y0 = ring(np.array([th0]), 0.93)
        dx, dy = np.cos(th0), np.sin(th0)
        def leg(T, V, x0=x0[0], y0=y0[0], dx=dx, dy=dy):
            rr = 0.06 * (1 - 0.30 * V)
            out = 0.04 * V ** 2
            return np.stack([x0 + dx * out + rr * np.cos(T), y0 + dy * out * 0.6 + rr * np.sin(T) * 0.9,
                             T1 + 0.01 - 0.11 * V], 1)
        def t_leg(T, V, P, N):
            z = np.where(np.cos(T + 2.2) > 0.3, 3, 2)
            z = np.where(np.abs(V - 0.25) < 0.05, 0, z)      # khấc tiện
            z = np.where(V > 0.88, 1, z)
            return shade(GODAM, z, N)
        surf(r, leg, 0, 2 * np.pi, 0, 1, 700, 140, t_leg, lambda T, V, P, N: np.where(P[:, 1] < 0, 6, 5))
    return r


if __name__ == '__main__':
    out = sys.argv[1]; W = int(sys.argv[2]) if len(sys.argv) > 2 else 700
    SS = 2
    G.DENS = W * SS / 1400.0
    r = build_de(W * SS)
    rgba, oid = G.finish(r, SS)
    a = rgba[..., 3] > 0
    img, _ = G.save(rgba, oid, a, None, SS)
    bb = (int(W * 0.06), int(W * 0.10), int(W * 0.94), int(W * 0.75))
    os.makedirs(out, exist_ok=True)
    img.crop(bb).save(f'{out}/de.png'); print('ok', img.crop(bb).size)
