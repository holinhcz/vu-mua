# Xuất nền cờ caro 9px: mỗi món 1 file riêng (webp lossless) + layout.json (toạ độ css). Godot ghép + bóng + gió.
#   python3 export9.py OUT JOB   (JOB: xoai0..3 chuoi mai nong non ro mam bong lu ga gacon la dat gach)
import sys, os, json, math
import numpy as np
from PIL import Image
sys.path.insert(0, '/home/user/caro/art')
import props as P, props4 as Q, trees4 as T4, trees9 as T9, board2 as B
from scene4 import layout

K = 9.0
W, H = 1920, 920
OUT = sys.argv[1]; JOB = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
fx, fy, face = layout(W, H, False)
rx = fx + face + 175; roofw = W - rx
sx = fx + face + 90
MANGO = dict(cx=40, cy=-150, R=600)

def save(arr, name):
    im = arr if isinstance(arr, Image.Image) else P.to_img(arr)
    im.save(os.path.join(OUT, name + '.webp'), lossless=True, quality=100, method=4)
    print(name, im.size, flush=True)

LAYOUT = {
    'W': W, 'H': H, 'K': K, 'board': [fx, fy, face], 'roof': [rx, -10, roofw, H + 20],
    'props': [  # tên file, tâm x, tâm y (css), xoay độ, bóng (dx, dy, mờ css, đậm)
        ['ro', sx - 4, H * 0.15, 0, [8, 10, 5, 0.42]],
        ['mam', sx - 2, H * 0.41, 0, [8, 10, 5, 0.42]],
        ['bong', sx, H * 0.65, 0, [10, 12, 6, 0.42]],
        ['lu', rx - 10, H * 0.88, 0, [14, 18, 9, 0.45]],
        ['nong', 430, 600, 0, [8, 10, 6, 0.42]],
        ['non', 548, 838, 0, [6, 8, 5, 0.42]],
        ['ga', 548, 372, 0, [4, 6, 3, 0.42]],
    ],
    'chicks': [[548 + ox * 230, 372 + oy * 230 * 0.8, a] for ox, oy, a in [(-0.45, -0.05, 2.9), (-0.35, 0.3, 2.2), (0.05, 0.42, 1.6), (0.3, -0.35, -2.4), (-0.15, -0.38, 3.5)]],
    'chuoi': [120, 800, 230],
    'mango': MANGO,
    'porch': 30,
}

if JOB == 'layout':
    rg = np.random.default_rng(3)
    gl = []
    avoid = [(p[1], p[2], 110) for p in LAYOUT['props']] + [(120, 800, 150)]
    while len(gl) < 18:
        x = rg.uniform(10, rx - 10); y = rg.uniform(50, H - 10)
        if fx - 14 < x < fx + face + 14 and fy - 14 < y < fy + face + 14:
            continue
        if any(math.hypot(x - a, y - b) < r for a, b, r in avoid):
            continue
        gl.append([x, y, rg.uniform(0, 360), int(rg.integers(0, 6))])
    LAYOUT['ground_leaves'] = gl
    LAYOUT['falling'] = [dict(x0=rg.uniform(80, 760), y0=rg.uniform(30, 420), ph=rg.uniform(0, 1), T=rg.uniform(7, 11),
                              vx=rg.uniform(-40, 170), vy=rg.uniform(110, 230), fa=rg.uniform(10, 34), ff=rg.uniform(5, 11),
                              spin=rg.uniform(-9, 9), r0=rg.uniform(0, 6.28), v=int(rg.integers(0, 6))) for _ in range(7)]
    plan = T9.mango_plan(MANGO['cx'], MANGO['cy'], MANGO['R'], math.atan2(410 + 150, 490 - 40))
    wins = []
    for li in range(4):
        e = T9.leaf_extent(plan, li)
        wins.append([max(e[0], -40), max(e[1], -40), min(e[2], W + 40), min(e[3], H + 40)])
    LAYOUT['mango_wins'] = wins
    json.dump(LAYOUT, open(os.path.join(OUT, 'layout.json'), 'w'), indent=1)
elif JOB.startswith('xoai'):
    li = int(JOB[4:])
    L = json.load(open(os.path.join(OUT, 'layout.json')))
    plan = T9.mango_plan(MANGO['cx'], MANGO['cy'], MANGO['R'], math.atan2(410 + 150, 490 - 40))
    save(T9.render_layer(plan, li, K, L['mango_wins'][li]), JOB)
elif JOB == 'chuoi':
    save(T4.banana3(K, 230), 'chuoi')
elif JOB == 'mai':
    save(Q.mai_la3(K, roofw, H + 20, side='right'), 'mai')
elif JOB == 'nong':
    save(Q.nong3(K, 140), 'nong')
elif JOB == 'non':
    save(Q.non4(K, 80), 'non')
elif JOB == 'ro':
    save(Q.ro_xoai(K, 64), 'ro')
elif JOB == 'mam':
    import props5
    save(props5.tra_mia(K * 2.6, 29.5), 'mam')     # ca trà đá + 3 ly nước mía (thay mâm trà)
elif JOB == 'bong':
    save(Q.chau_bong3(K, 76), 'bong')
elif JOB == 'lu':
    save(Q.lu3(K, 92), 'lu')
elif JOB == 'ga':
    import hen5
    save(hen5.hen5(K, 1.2 * 230 / 120.0, seed=4, ang=2.6), 'ga')
elif JOB == 'gacon':
    save(Q.chick4(K, 30 / 36.0, seed=1, ang=0.0), 'gacon')
elif JOB == 'la':
    for i in range(6):
        save(T4.fall_leaf3(K, 300 + i, 56), 'la%d' % i)
elif JOB == 'dat':
    # nền sân đất nện, ô lặp liền mép 256 css
    T = 256; n = int(T * K)
    rg = np.random.default_rng(31)
    def seamless(f):
        w = np.sin(np.linspace(0, math.pi, n, endpoint=False)) ** 2
        f2 = np.roll(np.roll(f, n // 2, 0), n // 2, 1)
        wx = w[None, :] * w[:, None]
        return f * wx + f2 * (1 - wx)
    big = seamless(B.fbm(n, n, 70 * K, 3, rg)); mid = seamless(B.fbm(n, n, 14 * K, 2, rg))
    grit = B.fbm(n, n, 0.3 * K, 1, rg); grit2 = B.fbm(n, n, 1.1 * K, 2, rg); clump = B.fbm(n, n, 3.5 * K, 2, rg)
    base = np.array([158, 136, 108], np.float32)
    col = base * (0.86 + 0.18 * big + 0.08 * mid)[..., None] * (0.88 + 0.16 * grit + 0.1 * grit2)[..., None]
    col *= (1 - 0.08 * np.clip((clump - 0.62) * 6, 0, 1) + 0.05 * np.clip((0.35 - clump) * 6, 0, 1))[..., None]
    # vệt chổi quét cong
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / K
    sw = 0.5 + 0.5 * np.sin((xx * 0.9 + 18 * np.sin(yy / T * 2 * math.pi) + 10 * np.sin(xx / T * 4 * math.pi)) * 2 * math.pi / 3.2)
    col *= (1 - 0.035 * sw * (mid > 0.45))[..., None]
    img = np.dstack([col, np.full((n, n), 255, np.float32)])
    # sỏi nhỏ có bóng
    for i in range(28):
        x = rg.uniform(0, T); y = rg.uniform(0, T); r = rg.uniform(0.5, 1.8) * (2.2 if rg.random() < 0.15 else 1)
        g = rg.uniform(0.75, 1.1); c = np.array([158, 136, 108]) * g * rg.uniform(0.9, 1.1, 3)
        for ox in (-T, 0, T):
            for oy in (-T, 0, T):
                cxp, cyp = (x + ox) * K, (y + oy) * K
                if -r * 3 * K < cxp < n + r * 3 * K and -r * 3 * K < cyp < n + r * 3 * K:
                    m = int(r * 2.5 * K) + 2
                    a0, b0 = int(cyp) - m, int(cxp) - m
                    ya, yb, xa, xb = max(0, a0), min(n, a0 + 2 * m), max(0, b0), min(n, b0 + 2 * m)
                    if yb <= ya or xb <= xa: continue
                    YY, XX = np.mgrid[ya:yb, xa:xb].astype(np.float32)
                    e = np.hypot(XX - cxp, YY - cyp) / (r * K)
                    es = np.hypot(XX - cxp - 0.5 * r * K, YY - cyp - 0.6 * r * K) / (r * K * 1.1)
                    sub = img[ya:yb, xa:xb]
                    sub[..., :3] *= (1 - 0.35 * np.clip(1 - es, 0, 1) * (e > 1))[..., None]
                    nz = np.sqrt(np.clip(1 - e ** 2, 0, 1))
                    lm = P.lam((XX - cxp) / (r * K), (YY - cyp) / (r * K), nz)
                    pc = c * (0.5 + 0.7 * lm)[..., None]
                    aa = np.clip((1 - e) * r * K * 0.8, 0, 1)[..., None]
                    sub[..., :3] = sub[..., :3] * (1 - aa) + pc * aa
    save(img, 'dat')
elif JOB == 'gach':
    # gạch tàu 1 hàng, 4 viên, lặp ngang
    S_ = 34.0; G = 2.6; nw = int(4 * (S_ + G) * K); nh = int((S_ + G) * K)
    rg = np.random.default_rng(41)
    yy, xx = np.mgrid[0:nh, 0:nw].astype(np.float32) / K
    col = np.zeros((nh, nw, 3), np.float32) + np.array([168, 158, 140])
    for i in range(4):
        x0 = i * (S_ + G) + G / 2; y0 = G / 2
        u = (xx - x0) / S_; v = (yy - y0) / S_
        m = (u >= 0) & (u <= 1) & (v >= 0) & (v <= 1)
        tone = np.array([182, 92, 58]) * rg.uniform(0.88, 1.08)
        bev = np.clip(np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v)) * S_ / 1.2, 0, 1)
        lit = 1 + 0.12 * (1 - bev) * np.sign((0.5 - u) + (0.5 - v))
        sp = B.fbm(nh, nw, 0.6 * K, 2, rg); wear = B.fbm(nh, nw, 8 * K, 2, rg)
        c = tone * (0.85 + 0.2 * sp)[..., None] * (0.9 + 0.15 * wear)[..., None] * lit[..., None]
        c = c * (1 - 0.15 * (sp > 0.8))[..., None]
        col = np.where(m[..., None], c, col)
    save(np.dstack([col, np.full((nh, nw), 255, np.float32)]), 'gach')
