# Tán xoài 9px: dựng hình học 1 lần (không phụ thuộc K), rồi vẽ riêng từng nhánh vào khung cắt sẵn.
# Mỗi nhánh = 1 file riêng để Godot lắc bằng shader.
import math
import numpy as np
from PIL import Image
import props as P
import board2 as B
import trees4 as T4

def mango_plan(cx, cy, R, toward, seed=11, ls=1.0, nlayer=4, bounds=(-60, -60, 2000, 1000)):
    rg = np.random.default_rng(seed)
    S = lambda: int(rg.integers(1, 2 ** 31))
    segs, tips = [], []
    def grow(li, x, y, ang, ln, w, depth):
        x1 = x + math.cos(ang) * ln; y1 = y + math.sin(ang) * ln
        pts = [(x, y)]
        for k in range(1, 4):
            f = k / 3
            pts.append((x + (x1 - x) * f + rg.uniform(-0.06, 0.06) * ln, y + (y1 - y) * f + rg.uniform(-0.06, 0.06) * ln))
        for k in range(3):
            segs.append((li, pts[k], pts[k + 1], w * (1 - 0.12 * k), w * (1 - 0.12 * (k + 1)), S()))
        d1 = math.hypot(x1 - cx, y1 - cy)
        if depth >= 4 or w < 2.5 or d1 > R * 0.98:
            tips.append((li, x1, y1)); return
        for b in range(2 if depth < 1 else rg.integers(2, 4)):
            grow(li, x1, y1, ang + rg.uniform(-0.8, 0.8), ln * rg.uniform(0.5, 0.7), w * 0.6, depth + 1)
        if depth >= 1:
            tips.append((li, x1, y1))
    for li in range(nlayer):
        ang = toward + (li - (nlayer - 1) / 2) / nlayer * 2.0 + rg.uniform(-0.15, 0.15)
        grow(li, cx, cy, ang, R * 0.42, 26 * ls, 0)
    masses = [(li, x, y, rg.uniform(40, 62) * ls) for li, x, y in tips]
    clusters = []
    for li, x, y in tips:
        for s in range(rg.integers(6, 10)):
            a = rg.uniform(0, 6.283); r = rg.uniform(0, 50) * ls
            hx = x + math.cos(a) * r; hy = y + math.sin(a) * r
            h = 1 - (math.hypot(hx - cx, hy - cy) / R) ** 2 * 0.5 + rg.uniform(-0.3, 0.3)
            clusters.append((h, li, hx, hy, math.atan2(hy - cy, hx - cx)))
    clusters.sort()
    pal = [[40, 84, 32], [50, 100, 38], [62, 112, 44], [86, 120, 50], [132, 82, 46]]
    probs = np.array([1, 1, 1, 0.6, 0.25]); probs = probs / probs.sum()
    leaves, fruits = [], []
    bx0, by0, bx1, by1 = bounds
    for h, li, x, y, out_a in clusters:
        if x < bx0 or y < by0 or x > bx1 or y > by1:
            continue
        light = 0.55 + 0.45 * float(np.clip(h, 0, 1))
        kind = rg.choice(5, p=probs); young = kind == 4
        a0 = out_a + rg.uniform(-0.6, 0.6)
        for j in range(rg.integers(6, 11)):
            ang = a0 + rg.uniform(-1.3, 1.3)
            ln = rg.uniform(28, 58) * ls * (0.8 if young else 1.0)
            wd = ln * rg.uniform(0.22, 0.3)
            lx = x + math.cos(ang) * ln * 0.42 + rg.normal(0, 5 * ls); ly = y + math.sin(ang) * ln * 0.42 + rg.normal(0, 5 * ls)
            bc = (np.array(pal[kind], np.float32) * rg.uniform(0.88, 1.12)).tolist()
            ty = rg.uniform(0.3, 1.0) if (not young and rg.random() < 0.08) else 0.0
            leaves.append((li, lx, ly, ln, wd, ang, bc, light * rg.uniform(0.9, 1.1), ty, S()))
        if not young and rg.random() < 0.2 and h < 0.95 and len(fruits) < 40:
            fx0 = x + rg.uniform(-10, 10) * ls; fy0 = y + rg.uniform(-10, 10) * ls
            for k in range(rg.integers(1, 3)):
                ang = rg.uniform(0, 6.283)
                fruits.append((li, len(leaves), fx0, fy0, fx0 + math.cos(ang) * 14 * ls * k, fy0 + math.sin(ang) * 14 * ls * k, rg.uniform(0, 6.283), S()))
    return dict(segs=segs, masses=masses, leaves=leaves, fruits=fruits, ls=ls)

def leaf_extent(plan, li):
    xs, ys = [], []
    for s in plan['segs']:
        if s[0] == li:
            for p in (s[1], s[2]):
                xs.append(p[0]); ys.append(p[1])
    for m in plan['masses']:
        if m[0] == li:
            xs += [m[1] - m[3], m[1] + m[3]]; ys += [m[2] - m[3], m[2] + m[3]]
    for l in plan['leaves']:
        if l[0] == li:
            xs += [l[1] - l[3], l[1] + l[3]]; ys += [l[2] - l[3], l[2] + l[3]]
    return min(xs), min(ys), max(xs), max(ys)

def render_layer(plan, li, K, win):
    """vẽ nhánh li vào khung win=(x0,y0,x1,y1) toạ độ cảnh (css); trả RGBA float"""
    x0, y0, x1, y1 = win
    Ww, Hh = int((x1 - x0) * K), int((y1 - y0) * K)
    out = np.zeros((Hh, Ww, 4), np.float32)
    ls = plan['ls']
    for l_, a, b, w0, w1, sd in plan['segs']:
        if l_ == li:
            T4.capsule(out, K, a[0] - x0, a[1] - y0, b[0] - x0, b[1] - y0, w0, w1, (110, 84, 62), np.random.default_rng(sd))
    # khối lá tối trong lòng tán
    m = np.zeros((Hh, Ww), np.float32)
    for l_, x, y, rr in plan['masses']:
        if l_ != li:
            continue
        xa, xb = int(max(0, (x - rr - x0) * K)), int(min(Ww, (x + rr - x0) * K))
        ya, yb = int(max(0, (y - rr - y0) * K)), int(min(Hh, (y + rr - y0) * K))
        if xb <= xa or yb <= ya:
            continue
        yy, xx = np.mgrid[ya:yb, xa:xb].astype(np.float32)
        d = np.hypot(xx / K + x0 - x, yy / K + y0 - y) / rr
        m[ya:yb, xa:xb] = np.maximum(m[ya:yb, xa:xb], np.clip((1 - d) * 3, 0, 1))
    nzf = B.fbm(Hh, Ww, 9 * K, 3, np.random.default_rng(77 + li))
    m = P.blur(m, 3 * K) * ((nzf > 0.3) | ('clumps' in plan))
    P.over(out, P.rgba(np.array([24, 52, 22], np.float32) * (0.7 + 0.6 * nzf)[..., None], P.blur(m, 1.5 * K)))
    del nzf, m
    fr = [f for f in plan['fruits'] if f[0] == li]
    fi = 0
    for idx, (l_, lx, ly, ln, wd, ang, bc, light, ty, sd) in enumerate(plan['leaves']):
        if l_ != li:
            continue
        p, r = T4.leaf_patch(K, ln, wd, ang, bc, light, np.random.default_rng(sd), tip_yellow=ty)
        hh, ww = p.shape[:2]
        xs = int((lx - x0) * K - ww // 2 + 4 * ls * K); ys = int((ly - y0) * K - hh // 2 + 5 * ls * K)
        if 0 <= xs and 0 <= ys and xs + ww < Ww and ys + hh < Hh:
            sub = out[ys:ys + hh, xs:xs + ww]
            sa_ = P.blur(p[..., 3] / 255, 1.6 * K)[..., None]
            sub[..., :3] *= (1 - 0.32 * sa_ * (sub[..., 3:4] > 0))
        T4.stamp(out, p, (lx - x0) * K, (ly - y0) * K)
    if 'clumps' in plan:
        # khối chùm: mỗi chùm là 1 vòm tròn → sáng phía nắng (trên trái), tối ở rìa và khe giữa các chùm
        q = 3.0; hw, hh = max(1, int(Ww / K * q)), max(1, int(Hh / K * q))
        yy, xx = np.mgrid[0:hh, 0:ww].astype(np.float32) / q
        xx += x0; yy += y0
        zt = np.full((hh, ww), -1e9, np.float32); sh = np.ones((hh, ww), np.float32)
        Lv = np.array([-0.5, -0.62, 0.6]); Lv = Lv / np.linalg.norm(Lv)
        for l_, cx_, cy_, cr_, h_ in plan['clumps']:
            if l_ != li: continue
            dx = (xx - cx_) / cr_; dy = (yy - cy_) / cr_; d2 = dx * dx + dy * dy
            m = d2 < 1.0
            if not m.any(): continue
            nz = np.sqrt(np.clip(1 - d2, 0, 1))
            z = h_ * 400 + nz * cr_ * 0.6
            top = m & (z > zt)
            lam = np.clip(dx * Lv[0] + dy * Lv[1] + nz * Lv[2], 0, 1)
            val = np.maximum(0.52, (0.34 + 0.88 * lam) * (0.45 + 0.55 * np.clip(nz * 1.6, 0, 1)))
            zt = np.where(top, z, zt); sh = np.where(top, val, sh)
        sh = P.blur(sh, 2.0 * q)
        shI = np.array(Image.fromarray((np.clip(sh, 0, 2) * 120).astype(np.uint8)).resize((Ww, Hh), Image.BILINEAR), np.float32) / 120.0
        out[..., :3] *= shI[..., None]
    while fi < len(fr):
        _, _, fx0, fy0, fx, fy, fa, fsd = fr[fi]; fi += 1
        rgf = np.random.default_rng(fsd)
        T4.capsule(out, K, fx0 - x0, fy0 - y0, fx - x0, fy - y0, 2.6 * ls, 2.0 * ls, (96, 108, 52), rgf, bark=False)
        T4.mango_fruit(out, K, fx - x0, fy - y0, 20 * ls, 13 * ls, fa, rgf)
    return out

def mango_plan2(cx, cy, R, seed=21, nlayer=4, bounds=(-60, -60, 2000, 1000)):
    """TÁN XOÀI v2 (vẽ mới): nhìn từ trên xuống = 1 vòm đầy gồm nhiều chùm lá tròn xếp chồng,
    chùm giữa cao (sáng, đè lên), chùm rìa thấp (tối hơn); khe giữa chùm lộ cành + trái. 4 nhánh gió chia theo góc."""
    rg = np.random.default_rng(seed)
    S = lambda: int(rg.integers(1, 2 ** 31))
    bx0, by0, bx1, by1 = bounds
    a_lo, a_hi = -0.35, 2.05                      # góc phần tán lộ ra màn (quanh gốc ở góc trên trái)
    def layer_of(x, y):
        a = math.atan2(y - cy, x - cx)
        return int(np.clip((a - a_lo) / (a_hi - a_lo) * nlayer, 0, nlayer - 1))
    # chùm lá: rải đều (poisson thô) trong vòng tán
    clumps = []
    for _ in range(6000):
        if len(clumps) > 80: break
        a = rg.uniform(a_lo, a_hi); r = R * math.sqrt(rg.uniform(0.02, 0.95)) * (1.0 + 0.08 * math.sin(a * 7.0 + 1.3))
        x = cx + math.cos(a) * r; y = cy + math.sin(a) * r
        if x < bx0 - 80 or y < by0 - 80 or x > bx1 or y > by1: continue
        cr = rg.uniform(85, 130) * (1.0 - 0.2 * r / R)
        if any(math.hypot(x - q[0], y - q[1]) < (cr + q[2]) * 0.48 for q in clumps): continue
        h = 1 - (r / R) ** 2 * 0.7 + rg.uniform(-0.12, 0.12)
        clumps.append((x, y, cr, h))
    clumps.sort(key=lambda q: q[3])               # thấp trước, cao sau
    cl_out = [(layer_of(q[0], q[1]),) + q for q in clumps]
    segs = []
    # cành chính: từ gốc toả ra, phần lớn bị lá che, chỉ lộ ở khe
    for k in range(6):
        a = a_lo + (k + 0.5) / 6 * (a_hi - a_lo) + rg.uniform(-0.12, 0.12)
        x, y, w = cx, cy, 30.0; ln = R * 0.2
        for d in range(4):
            a += rg.uniform(-0.3, 0.3)
            x1 = x + math.cos(a) * ln; y1 = y + math.sin(a) * ln
            segs.append((layer_of(x1, y1), (x, y), (x1, y1), w, w * 0.72, S()))
            x, y, w, ln = x1, y1, w * 0.72, ln * 0.85
    pal = [[38, 80, 30], [48, 96, 36], [60, 110, 42], [84, 118, 48], [130, 84, 46]]
    probs = np.array([1, 1.2, 1, 0.5, 0.12]); probs = probs / probs.sum()
    masses, leaves, fruits = [], [], []
    L = np.array([-0.6, -0.8])
    for (x, y, cr, h) in clumps:
        li = layer_of(x, y)
        masses.append((li, x, y, cr * 1.04))
        n = int(math.pi * cr * cr / 300)
        pts = []
        for j in range(n):
            rr = cr * math.sqrt(rg.uniform(0, 1)) * 0.95; aa = rg.uniform(0, 6.283)
            pts.append((rr, aa))
        pts.sort(key=lambda p: -p[0])             # rìa chùm trước, tâm chùm sau (đè lên) → khối tròn có độ phồng
        young_clump = rg.random() < 0.07
        for rr, aa in pts:
            lx = x + math.cos(aa) * rr; ly = y + math.sin(aa) * rr
            ang = aa + rg.uniform(-1.0, 1.0) if rr > cr * 0.3 else rg.uniform(0, 6.283)
            ln = rg.uniform(34, 54) * (0.85 if young_clump else 1.0)
            wd = ln * rg.uniform(0.23, 0.29)
            ofs = np.array([math.cos(aa), math.sin(aa)]) * rr / cr
            lit = 0.5 + 0.55 * (1 - (rr / cr) ** 1.6) + 0.28 * float(ofs @ L)      # mặt chùm hướng nắng sáng hơn, tâm phồng sáng
            light = float(np.clip(lit * (0.55 + 0.5 * np.clip(h, 0, 1)), 0.3, 1.3))
            kind = 4 if young_clump and rg.random() < 0.8 else rg.choice(5, p=probs)
            bc = (np.array(pal[kind], np.float32) * rg.uniform(0.9, 1.1)).tolist()
            ty = rg.uniform(0.3, 1.0) if (kind != 4 and rg.random() < 0.05) else 0.0
            leaves.append((li, lx, ly, ln, wd, ang, bc, light * rg.uniform(0.93, 1.07), ty, S()))
        # trái xoài thòng ở rìa dưới phải của chùm (khe bóng)
        if rg.random() < 0.3 and len(fruits) < 22:
            aa = rg.uniform(0.2, 1.4); fx0 = x + math.cos(aa) * cr * 0.7; fy0 = y + math.sin(aa) * cr * 0.7
            for k in range(rg.integers(1, 4)):
                ang = rg.uniform(0, 6.283)
                fruits.append((li, len(leaves), fx0, fy0, fx0 + math.cos(ang) * 13 * k, fy0 + math.sin(ang) * 13 * k, rg.uniform(0, 6.283), S()))
    return dict(segs=segs, masses=masses, leaves=leaves, fruits=fruits, ls=1.0, clumps=cl_out)
