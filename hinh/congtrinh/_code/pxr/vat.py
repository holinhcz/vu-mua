# Materials for pxr: each takes per-pixel (u, v, prm, back, pos, nrm) and gives albedo, gloss, shininess, translucency.
# prm = (p0 style / colour index, p1 per-surface random 0..1, p2 free)
import numpy as np
from pxr import hexc, ramp, smooth, hash1, vnoise

LEAF, PETAL, SANS, ALOE, CACT, DISC, STEM, BLADE, WHITE, FRUIT, INNER, SPIKE = range(1, 13)

# leaf styles: dark, mid, light, gloss, shininess, vein strength, under colour, translucency
LEAVES = {
    0: (('#245a28', '#3a7f36', '#5c9e48'), 0.25, 30, 0.10, '#8aa87a', 0.45),   # generic
    1: (('#1d4a22', '#2f6c2e', '#4a8a3a'), 0.55, 55, 0.08, '#6f8f5a', 0.30),   # bông trang: dark, leathery, very glossy
    2: (('#1d4a22', '#2f6a2e', '#4d8a3c'), 0.50, 50, 0.12, '#7a9a66', 0.35),   # lài: dark glossy, sunken veins
    3: (('#2e6a26', '#4a9036', '#6fb24c'), 0.45, 40, 0.16, '#8fb878', 0.45),   # húng quế: bright glossy, puckered
    4: (('#3a6e2e', '#538a3c', '#73a452'), 0.06, 12, 0.08, '#92aa78', 0.40),   # dạ yến thảo: soft, dull, hairy
    5: (('#2e6a2c', '#468a3a', '#68a64c'), 0.40, 40, 0.10, '#8db27a', 0.55),   # mai địa thảo / móng tay: fleshy
    6: (('#1f4c22', '#336a2e', '#4f863e'), 0.10, 15, 0.20, '#7d9a6a', 0.35),   # cúc lá nho: rough, deep veins
    7: (('#35662a', '#4e8436', '#6a9e46'), 0.08, 14, 0.18, '#8aa874', 0.40),   # hướng dương: rough sandpaper leaf
    8: (('#1f4e22', '#2f6a2c', '#4a8838'), 0.40, 45, 0.06, '#7a9a66', 0.35),   # ớt kiểng: dark narrow
}


def m_leaf(u, v, prm, back, pos, nrm):
    st = prm[:, 0].astype(int); r = prm[:, 1]
    n = len(u)
    alb = np.zeros((n, 3)); g = np.zeros(n); sh = np.zeros(n); tr = np.zeros(n)
    for k, (cols, gl, shn, vs, under, trs) in LEAVES.items():
        s = st == k
        if not s.any(): continue
        uu, vv, rr = u[s], v[s], r[s]
        t = 0.45 + 0.35 * (rr - 0.5) + 0.12 * uu - 0.1 * np.abs(vv)
        a = ramp(cols, t)
        # midrib and side veins (sunken on lài / cúc: darker; raised elsewhere: lighter)
        mid = 1 - smooth(0.03, 0.09, np.abs(vv))
        ph = (uu - np.abs(vv) * 0.45) * 7.0
        side = (1 - smooth(0.0, 0.12, np.abs(ph - np.round(ph)))) * smooth(0.08, 0.2, np.abs(vv)) * (1 - smooth(0.75, 0.95, np.abs(vv)))
        vein_c = hexc('#c8dc8a') if k not in (2, 6) else hexc('#16381a')
        a = a + (vein_c - a) * (mid * 0.45 + side * vs * 2.0)[:, None] * (0.6 if k not in (2, 6) else 0.5)
        # mottling inside the blade and a paler rim
        a = a * (0.94 + 0.12 * vnoise(uu * 9, vv * 3, rr * 50))[:, None]
        if k == 3:   # húng quế: puckered, light bumps between veins
            a = a * (0.92 + 0.16 * vnoise(uu * 14, vv * 6, 3.0))[:, None]
        if k == 4:   # hairy: a soft pale sheen
            a = a + (hexc('#b8c8a0') - a) * 0.12
        bk = back[s]
        a[bk] = a[bk] + (hexc(under) - a[bk]) * 0.55
        alb[s] = a; g[s] = np.where(bk, 0.04, gl); sh[s] = shn; tr[s] = trs
    return alb, g, sh, tr


# petal colours: (base, mid, tip, eye, eye size, vein)
PETALS = {
    0: ('#c8320f', '#e2481a', '#f2642c', '#f6c24a', 0.12, 0.10),     # bông trang đỏ cam
    1: ('#a8101e', '#cc1e28', '#e2383a', '#f4c050', 0.12, 0.10),     # bông trang đỏ
    2: ('#d87a0c', '#eea01a', '#f8b834', '#fff0a0', 0.12, 0.08),     # bông trang cam vàng
    3: ('#c83a72', '#e25a90', '#f27eaa', '#fff2c8', 0.12, 0.10),     # bông trang hồng
    4: ('#e4e6dc', '#f8f8f4', '#ffffff', '#e8eccc', 0.15, 0.04),     # lài trắng
    5: ('#f0a808', '#ffc414', '#ffd636', '#a86a10', 0.0, 0.18),      # hướng dương
    6: ('#5a2078', '#7c34a0', '#9a4cbc', '#2a0a3a', 0.3, 0.30),      # dạ yến thảo tím
    7: ('#c0286a', '#e0488a', '#f06ea6', '#6a0e3a', 0.3, 0.30),      # dạ yến thảo hồng
    8: ('#e8e4ea', '#f8f6f8', '#ffffff', '#f0dc70', 0.22, 0.18),     # dạ yến thảo trắng
    9: ('#b81a3e', '#d42e56', '#e8507a', '#5a0a24', 0.3, 0.30),      # dạ yến thảo đỏ hồng
    10: ('#d63a6c', '#ee5a8a', '#fa86aa', '#ffffff', 0.12, 0.06),    # mai địa thảo hồng
    11: ('#d2262a', '#ea4038', '#f6604e', '#ffffff', 0.12, 0.06),    # mai địa thảo đỏ
    12: ('#e8681a', '#f6862a', '#ffa44a', '#ffffff', 0.12, 0.06),    # mai địa thảo cam
    13: ('#ece6ee', '#faf6fa', '#ffffff', '#f6c8d8', 0.14, 0.04),    # mai địa thảo trắng
    14: ('#b8286e', '#d84a8c', '#f272aa', '#8a1a50', 0.1, 0.12),     # móng tay hồng tím
    15: ('#b0182c', '#d02c40', '#ea4e5c', '#7a0a1a', 0.1, 0.12),     # móng tay đỏ
    16: ('#6e2e96', '#8c46b2', '#aa66cc', '#4a1a6a', 0.1, 0.12),     # móng tay tím
    17: ('#e4dce6', '#f6f2f6', '#ffffff', '#f0c8d8', 0.1, 0.05),     # móng tay trắng
    18: ('#c43210', '#e2501c', '#f87230', '#e8a018', 0.0, 0.14),     # cúc lá nho
    19: ('#b0162a', '#d42a36', '#f04a46', '#f2d24a', 0.18, 0.10),    # xương rồng hoa đỏ
    20: ('#c07808', '#e09a12', '#f6c024', '#a86a08', 0.25, 0.10),    # cúc vàng
    21: ('#d8dae2', '#eeeff4', '#ffffff', '#e8eccc', 0.1, 0.05),     # cúc trắng
    22: ('#c8327a', '#ea5896', '#ff8ab8', '#f8d24a', 0.18, 0.10),    # mười giờ hồng
    23: ('#b8201e', '#e2302a', '#f45a46', '#f8d24a', 0.18, 0.10),    # mười giờ đỏ
    24: ('#d4701a', '#f48a2a', '#ffb048', '#f8d24a', 0.18, 0.10),    # mười giờ cam
    25: ('#d4a820', '#f6cc30', '#ffe46a', '#e8a018', 0.18, 0.10),    # mười giờ vàng
    26: ('#d8d2cc', '#f2eeea', '#ffffff', '#f8d24a', 0.18, 0.06),    # mười giờ trắng
    27: ('#d0581a', '#f07a1e', '#ff9a36', '#e8a020', 0.1, 0.16),     # sao nhái cam
    28: ('#b83c74', '#de5a96', '#f27ab0', '#f2c22a', 0.1, 0.16),     # sao nhái hồng
    29: ('#c8508a', '#e470a6', '#f694c0', '#c01e48', 0.14, 0.06),    # dừa cạn hồng
    30: ('#dcd8e0', '#f2f0f4', '#ffffff', '#c8204a', 0.14, 0.04),    # dừa cạn trắng mắt đỏ
    31: ('#4e2488', '#6e3cae', '#9460d2', '#f0eaff', 0.2, 0.15),     # hoa tím
    32: ('#d8581a', '#f27a24', '#ffa040', '#c84a10', 0.15, 0.06),    # ngũ sắc cam
    33: ('#c03276', '#e45894', '#f884b6', '#a82060', 0.15, 0.06),    # ngũ sắc hồng
    34: ('#b8201e', '#e0362c', '#f45a46', '#9a1818', 0.15, 0.06),    # ngũ sắc đỏ
    35: ('#e8dcb8', '#f8f0d8', '#ffffff', '#e0c890', 0.15, 0.04),    # ngũ sắc kem
    36: ('#d8a018', '#f2c224', '#ffdc50', '#c08010', 0.15, 0.06),    # ngũ sắc giữa vàng
    37: ('#c45008', '#e87214', '#ff9424', '#a84006', 0.0, 0.25),     # vạn thọ cam
    38: ('#c8900a', '#eab414', '#ffd02a', '#b07a08', 0.0, 0.25),     # vạn thọ vàng
    39: ('#6a0812', '#a8141e', '#d42a32', '#f05a54', 0.0, 0.45),     # mồng gà đỏ
    40: ('#5a0838', '#94185c', '#c43488', '#e464a8', 0.0, 0.45),     # mồng gà tím
}


def m_petal(u, v, prm, back, pos, nrm):
    st = prm[:, 0].astype(int)
    n = len(u); alb = np.zeros((n, 3))
    for k, (c0, c1, c2, ce, es, vs) in PETALS.items():
        s = st == k
        if not s.any(): continue
        uu, vv = u[s], v[s]
        a = ramp((c0, c1, c2), 0.15 + 0.85 * smooth(0.0, 0.9, uu))
        if es > 0:
            a = a + (hexc(ce) - a) * (1 - smooth(es * 0.6, es * 1.3, uu))[:, None]
        ph = vv * 4.5
        vein = 1 - smooth(0.0, 0.18, np.abs(ph - np.round(ph)))
        a = a * (1 - vs * vein * smooth(0.05, 0.4, uu) * (1 - smooth(0.7, 1.0, uu)))[:, None]
        a = a * (0.95 + 0.08 * vnoise(uu * 6, vv * 5, k))[:, None]
        a[back[s]] *= 0.86
        alb[s] = a
    g = np.full(n, 0.12); sh = np.full(n, 18.0); tr = np.full(n, 0.6)
    return alb, g, sh, tr


STEMS = {0: ('#3e6a2a', '#5a8a38'), 1: ('#5e4a36', '#8a7258'), 2: ('#5a3a5a', '#7e5a7a'), 3: ('#8a6a7a', '#c8c8a0'),
         4: ('#8aa85a', '#b4c886'), 5: ('#3a5a2a', '#567a3a')}


def m_stem(u, v, prm, back, pos, nrm):
    st = prm[:, 0].astype(int); n = len(u); alb = np.zeros((n, 3))
    for k, (c0, c1) in STEMS.items():
        s = st == k
        if not s.any(): continue
        t = 0.5 + 0.3 * (vnoise(u[s] * 30, v[s] * 6, k) - 0.5)
        if k == 3: t = smooth(0.0, 1.0, u[s]) * 0.8 + 0.1     # lemongrass sheath: purple foot, pale up
        alb[s] = ramp((c0, c1), t)
    return alb, np.full(n, 0.15), np.full(n, 20.0), np.full(n, 0.1)


def m_sans(u, v, prm, back, pos, nrm):
    """lưỡi hổ Laurentii: dark green with paler grey-green wavy cross bands, broad golden margins"""
    n = len(u); r = prm[:, 1]
    base = ramp(('#21401e', '#2e5428', '#3c6632'), 0.4 + 0.4 * r)
    w = np.sin((u * 26 + 1.6 * np.sin(v * 3.0 + u * 8 + r * 10) + vnoise(u * 18, v * 3, r * 9) * 2.2) * np.pi)
    band = smooth(0.25, 0.75, w) * (0.8 + 0.2 * vnoise(u * 40, v * 9, 1.0))
    a = base + (hexc('#7f9c6e') - base) * band[:, None] * 0.75
    marg = smooth(0.7, 0.86, np.abs(v)) * smooth(0.0, 0.08, u)
    a = a + (ramp(('#c9b23a', '#e2cc56'), vnoise(u * 12, v, 2.0)) - a) * marg[:, None]
    return a, np.full(n, 0.42), np.full(n, 45.0), np.full(n, 0.15)


def m_aloe(u, v, prm, back, pos, nrm):
    """nha đam: thick grey-green leaves, pale oval spots (young plants), a pinkish tip, pale teeth along the edge"""
    n = len(u); r = prm[:, 1]
    a = ramp(('#4c7650', '#62905e', '#7aa874'), 0.45 + 0.25 * (r - 0.5) + 0.2 * u)
    # spots on a staggered grid along the leaf
    gu = u * 16; row = np.floor(gu); gv = v * 2.2 + 0.5 * (row % 2)
    du = gu - row - 0.5; dv = gv - np.round(gv)
    spot = (1 - smooth(0.12, 0.2, np.sqrt((du * 0.9) ** 2 + (dv * 1.4) ** 2))) * smooth(0.05, 0.2, u) * (1 - smooth(0.75, 0.95, u))
    spot *= (hash1(row, np.round(gv), r) > 0.25)
    a = a + (hexc('#d2e2c8') - a) * (spot * 0.8)[:, None]
    a = a + (hexc('#a8786a') - a) * (smooth(0.86, 1.0, u) * 0.45)[:, None]
    a = a * (0.95 + 0.08 * vnoise(u * 20, v * 4, 5.0))[:, None]
    return a, np.full(n, 0.35), np.full(n, 35.0), np.full(n, 0.35)


def m_cact(u, v, prm, back, pos, nrm):
    """xương rồng tai thỏ: matt green pads, rows of white-gold glochid tufts (areoles) in a diamond pattern"""
    n = len(u); r = prm[:, 1]
    a = ramp(('#3e7436', '#56904a', '#6ea85a'), 0.5 + 0.3 * (r - 0.5))
    a = a * (0.94 + 0.1 * vnoise(u * 8, v * 16, r * 7))[:, None]
    gu = u * 8; row = np.floor(gu); gv = v * 16 + 0.5 * (row % 2)
    du = gu - row - 0.5; dv = gv - np.round(gv)
    d = np.sqrt((du * 1.0) ** 2 + (dv * 0.7) ** 2)
    ring = 1 - smooth(0.09, 0.16, d)
    core = 1 - smooth(0.03, 0.06, d)
    lim = smooth(0.06, 0.16, u) * (1 - smooth(0.9, 0.98, u))
    a = a + (hexc('#efe2a2') - a) * (ring * lim * 0.9)[:, None]
    a = a + (hexc('#c49a42') - a) * (core * lim * 0.7)[:, None]
    return a, np.full(n, 0.06), np.full(n, 12.0), np.full(n, 0.05)


def m_disc(u, v, prm, back, pos, nrm):
    """hướng dương: the seed head - spiralling florets, green-brown middle, a ring of open yellow florets"""
    n = len(u)
    lr = np.log(u + 0.06) * 3.2
    s1 = np.sin(2 * np.pi * (21 * v + lr * 2.1)); s2 = np.sin(2 * np.pi * (-34 * v + lr * 3.4))
    dots = smooth(-0.2, 0.6, s1 * s2)
    a = ramp(('#2a1808', '#4a2c10', '#6a4418'), 0.3 + 0.5 * dots)
    mid = 1 - smooth(0.1, 0.32, u)
    a = a + (hexc('#566a22') - a) * (mid * 0.7)[:, None]
    ring = smooth(0.72, 0.86, u)
    a = a + (ramp(('#b07a10', '#e0a820'), dots) - a) * (ring * 0.85)[:, None]
    return a, np.full(n, 0.05), np.full(n, 10.0), np.zeros(n)


BLADES = {0: (('#4f8a5c', '#6aa676', '#8cc496'), '#d8d4b0', 0.2),     # sả: blue-green, pale foot
          1: (('#2e6a2a', '#4a8a3a', '#6aa84c'), '#f0ecc8', 0.25),    # lan chi: green with a cream stripe
          2: (('#3a6a28', '#5a8e36', '#7aac4a'), '#c8c08a', 0.15),     # grass
          3: (('#8a7a3a', '#ab9850', '#c8b46a'), '#b0a070', 0.1)}       # dry grass    # grass


def m_blade(u, v, prm, back, pos, nrm):
    st = prm[:, 0].astype(int); n = len(u); alb = np.zeros((n, 3)); r = prm[:, 1]
    for k, (cols, foot, gl) in BLADES.items():
        s = st == k
        if not s.any(): continue
        uu, vv = u[s], v[s]
        a = ramp(cols, 0.4 + 0.4 * (r[s] - 0.5) + 0.25 * uu)
        if k == 1:
            stripe = 1 - smooth(0.32, 0.42, np.abs(vv))
            a = a + (hexc(foot) - a) * stripe[:, None] * 0.95
        else:
            mid = 1 - smooth(0.05, 0.14, np.abs(vv))
            a = a + (hexc('#c4d8a8') - a) * (mid * 0.4)[:, None]
            a = a + (hexc(foot) - a) * (1 - smooth(0.0, 0.18, uu))[:, None] * 0.8
        streak = vnoise(uu * 3, vv * 12, k) - 0.5
        a = a * (1 + 0.1 * streak)[:, None]
        if k == 0:   # the odd dry tip
            a = a + (hexc('#b49a5a') - a) * (smooth(0.88, 1.0, uu) * (r[s] > 0.8))[:, None] * 0.8
        a[back[s]] *= 0.92
        alb[s] = a
    return alb, np.full(n, 0.2), np.full(n, 30.0), np.full(n, 0.55)


FRUITS = {0: ('#9a0e14', '#d41e1e', '#f24030'), 1: ('#c08a06', '#eab818', '#ffd84a'), 2: ('#3a1046', '#5a1e6a', '#7e3a8a'),
          3: ('#c85410', '#ee7418', '#ff963a'), 4: ('#d8d2b0', '#f0ead0', '#fffaf0'),
          5: ('#4a2a68', '#6a3a8a', '#8c5aaa'),     # húng quế flower spike
          6: ('#2e5a24', '#40782e', '#58923e')}     # green bud


def m_fruit(u, v, prm, back, pos, nrm):
    st = prm[:, 0].astype(int); n = len(u); alb = np.zeros((n, 3))
    for k, cols in FRUITS.items():
        s = st == k
        if not s.any(): continue
        alb[s] = ramp(cols, 0.5 + 0.2 * (vnoise(u[s] * 5, v[s] * 7, k) - 0.5))
    g = np.where(st == 5, 0.05, 0.75); shn = np.where(st == 5, 10.0, 70.0)
    return alb, g, shn, np.full(n, 0.1)


def m_inner(u, v, prm, back, pos, nrm):
    """the dark inside of a shrub: a mass of shadowed leaves (leaf-sized noise, never a flat plate)"""
    n = len(u)
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    t = vnoise(x * 34 + y * 11, z * 34 - y * 13, 4.0) * 0.55 + vnoise(x * 85 - z * 20, z * 85 + y * 40, 8.0) * 0.45
    a = ramp(('#0e2a12', '#1a4019', '#2a5a24'), smooth(0.25, 0.8, t))
    return a, np.full(n, 0.05), np.full(n, 10.0), np.zeros(n)


def m_white(u, v, prm, back, pos, nrm):
    n = len(u)
    a = ramp(('#dcdcd2', '#f4f4ee', '#ffffff'), 0.3 + 0.7 * u)
    a = a + (hexc('#cfe0a0') - a) * (1 - smooth(0.0, 0.25, u))[:, None] * 0.6
    return a, np.full(n, 0.15), np.full(n, 20.0), np.full(n, 0.6)


PLUME = 13


def m_plume(u, v, prm, back, pos, nrm):
    """cỏ lau: a silky silver-buff plume, fine strands along it, paler toward the tip"""
    n = len(u)
    st = 0.5 + 0.5 * np.sin(v * 40 + vnoise(u * 8, v * 6, 2.0) * 6)
    a = ramp(('#8a7a6a', '#b8a690', '#d8c8b0', '#eee2cc'), 0.3 + 0.35 * u + 0.25 * st)
    return a, np.full(n, 0.2), np.full(n, 12.0), np.full(n, 0.8)


MATS = {LEAF: m_leaf, PETAL: m_petal, SANS: m_sans, ALOE: m_aloe, CACT: m_cact, DISC: m_disc, STEM: m_stem,
        BLADE: m_blade, WHITE: m_white, FRUIT: m_fruit, INNER: m_inner, SPIKE: m_fruit, PLUME: m_plume}
