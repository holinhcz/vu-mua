# TÌM SỐ: vẽ hình nền (mặt bàn học gỗ sơn cánh gián, tờ giấy vở ô li xé ra, bóng giấy, bút bi xanh/đỏ, cục tẩy)
# Từng điểm ảnh: vân gỗ, lỗ mộc, sơn bóng, sợi giấy, gợn giấy, nếp gấp. Mỗi hình một file.
import numpy as np, math, sys, os
from PIL import Image, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

def noise(w, h, cell, seed, oct=4, pers=0.5):
    r = np.random.default_rng(seed)
    acc = np.zeros((h, w), np.float32); amp = 1.0; tot = 0
    for o in range(oct):
        c = max(1.0, cell / (2 ** o))
        gw, gh = int(w / c) + 3, int(h / c) + 3
        g = (r.random((gh, gw)) * 255).astype(np.uint8)
        im = Image.fromarray(g).resize((int(gw * c), int(gh * c)), Image.BICUBIC)
        a = np.asarray(im, np.float32)[:h, :w] / 255.0
        acc += a * amp; tot += amp; amp *= pers
    return acc / tot

def save(a, name, q=92):
    a = np.clip(a, 0, 255).astype(np.uint8)
    mode = "RGBA" if a.shape[2] == 4 else "RGB"
    im = Image.fromarray(a, mode)
    im.save(os.path.join(OUT, name + ".webp"), quality=q, method=6, lossless=(mode == "RGBA"))
    return im

# ------------------------------------------------------------ mặt bàn gỗ (ván ngang), 1600 x 2800
def desk(W=1600, H=2800):
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    PL = 330.0                                    # bề rộng một tấm ván
    plank = np.floor(y / PL)
    py = y - plank * PL
    off = (plank * 977.0) % 1300
    def anis(cx, cy, seed, oct=3):   # nhiễu kéo dài theo chiều ngang (sợi gỗ)
        r = np.random.default_rng(seed); acc = np.zeros((H, W), np.float32); amp = 1; tot = 0
        for o in range(oct):
            gw, gh = int(W / cx) + 3, int(H / cy) + 3
            g = (r.random((gh, gw)) * 255).astype(np.uint8)
            im = np.asarray(Image.fromarray(g).resize((int(gw * cx), int(gh * cy)), Image.BICUBIC), np.float32)[:H, :W] / 255
            acc += im * amp; tot += amp; amp *= 0.5; cx /= 2; cy /= 2
        return acc / tot
    xx = x + off
    big = anis(700, 90, 11, 3)
    # vòng tuổi = đường đồng mức của một trường cong (có chỗ vòm kiểu "núi" khi xẻ ván)
    arch = np.zeros_like(x)
    for k in range(int(plank.max()) + 1):
        c0 = 300 + ((k * 613) % 1000)
        arch += (plank == k) * (-np.exp(-((xx - c0 - k * 977 % 1300) / 520.0) ** 2) * 60)
    field = (py + arch + big * 120) / 26.0 + plank * 1.7
    fr = field - np.floor(field)
    ring = np.clip((fr - 0.55) / 0.45, 0, 1) ** 1.6 * 0.8 + np.clip(1 - fr / 0.08, 0, 1) * 0.6   # gỗ muộn sậm, ranh giới rõ
    band = anis(900, 200, 12, 2)
    streak = anis(160, 2.2, 14, 3)                 # sợi mảnh
    fine = noise(W, H, 2, 13, 1)
    pore = (anis(14, 1.0, 15, 1) > 0.86).astype(np.float32) * 0.8
    t = 1 - (0.5 * ring + 0.2 * (1 - band) + 0.22 * streak + 0.08 * fine)
    light = np.array([142, 68, 32], np.float32)
    dark = np.array([58, 22, 9], np.float32)
    col = dark[None, None] + (light - dark)[None, None] * t[..., None]
    col *= (1.0 - 0.35 * pore[..., None])
    # khe ván + mép vát
    d0 = py; d1 = PL - py
    seam = np.exp(-(d0 ** 2) / 8.0) * 0.75 + np.exp(-((d1 - 1) ** 2) / 6.0) * 0.6
    bevel_hi = np.exp(-((d0 - 4) ** 2) / 10.0) * 0.18
    col *= (1 - seam[..., None])
    col += bevel_hi[..., None] * 255 * np.array([1.0, 0.8, 0.6])
    # sơn bóng: vệt sáng mềm chéo từ trái trên, trầy xước nhỏ
    sheen = np.exp(-(((x * 0.55 + y * 0.35) - 900) ** 2) / (2 * 420.0 ** 2)) * 0.22
    col = col * (1 + sheen[..., None]) + sheen[..., None] * 40
    scr = np.zeros((H, W), np.float32)
    for i in range(260):
        x0, y0 = rng.random() * W, rng.random() * H
        a = rng.normal(0, 0.5); L = rng.random() * 120 + 20
        n = int(L)
        xs = (x0 + np.cos(a) * np.arange(n)).astype(int); ys = (y0 + np.sin(a) * np.arange(n)).astype(int)
        m = (xs >= 0) & (xs < W) & (ys >= 0) & (ys < H)
        scr[ys[m], xs[m]] += rng.random() * 0.5 + 0.2
    scr = np.asarray(Image.fromarray((np.clip(scr, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255
    col += scr[..., None] * 38
    # tối dần ra mép màn hình (ánh đèn bàn ở giữa)
    cx, cy = W * 0.45, H * 0.42
    vg = 1 - 0.32 * np.clip(((x - cx) / W) ** 2 * 2.2 + ((y - cy) / H) ** 2 * 1.6, 0, 1)
    col *= vg[..., None]
    col += (rng.random((H, W, 1)) - 0.5) * 6
    return save(col, "ban", 90)

# ------------------------------------------------------------ tờ giấy vở ô li (dọc), 1400 x 1900, mép trái xé
def paper(W=1400, H=1900, name="giay", seed=21):
    r = np.random.default_rng(seed)
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    base = np.array([247, 243, 231], np.float32)
    fib = noise(W, H, 3, seed + 1, 2) - 0.5
    blot = noise(W, H, 180, seed + 2, 4) - 0.5
    col = base[None, None] * (1 + fib[..., None] * 0.05 + blot[..., None] * 0.04)
    # sợi giấy: nét ngắn sáng/tối
    sf = np.zeros((H, W), np.float32)
    for i in range(9000):
        x0, y0 = r.random() * W, r.random() * H
        a = r.random() * math.pi; n = int(r.random() * 14 + 4)
        xs = (x0 + np.cos(a) * np.arange(n)).astype(int); ys = (y0 + np.sin(a) * np.arange(n)).astype(int)
        m = (xs >= 0) & (xs < W) & (ys >= 0) & (ys < H)
        sf[ys[m], xs[m]] += (r.random() - 0.5) * 0.6
    sf = np.asarray(Image.fromarray(((np.clip(sf, -1, 1) + 1) * 127.5).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.5)), np.float32) / 127.5 - 1
    col *= (1 + sf[..., None] * 0.035)
    # ô li: ô to 56 px (8 mm), 4 dòng kẻ ngang mảnh mỗi ô, kẻ dọc mỗi ô to
    S = 56.0; ox = 150.0; oy = 120.0
    def line(d, w):  # d = khoảng cách tới đường, w = độ dày
        return np.clip(1.0 - np.abs(d) / w, 0, 1)
    fy = np.mod(y - oy, S / 4); dy = np.minimum(fy, S / 4 - fy)
    Fy = np.mod(y - oy, S); Dy = np.minimum(Fy, S - Fy)
    Fx = np.mod(x - ox, S); Dx = np.minimum(Fx, S - Fx)
    wob = (noise(W, H, 40, seed + 3, 2) - 0.5) * 0.8
    thin = line(dy + wob, 1.1) * 0.55
    thick = np.maximum(line(Dy + wob, 1.7), line(Dx + wob, 1.5))
    lil = np.array([150, 128, 196], np.float32)
    ink = np.clip(np.maximum(thin, thick) * (0.85 + 0.3 * (noise(W, H, 2, seed + 4, 1))), 0, 1)
    col = col * (1 - ink[..., None] * 0.55) + lil[None, None] * ink[..., None] * 0.55
    # lề đỏ
    mx = ox + S * 1.0 - 18
    red = line(x - mx + wob * 2, 2.0)
    col = col * (1 - red[..., None] * 0.6) + np.array([214, 70, 80])[None, None] * red[..., None] * 0.6
    # gợn giấy + nếp gấp ngang giữa (giấy từng gấp đôi)
    bump = noise(W, H, 260, seed + 5, 3)
    gy, gx = np.gradient(bump * 60)
    shade = 1 + (-gx * 0.7 - gy * 0.7) * 0.06
    fold = H * 0.52 + (noise(W, 1, 300, seed + 6, 2)[0] - 0.5) * 18
    fd = y - fold[None, :]
    shade += np.where(fd < 0, -0.05 * np.exp(-(fd ** 2) / 300), 0.035 * np.exp(-(fd ** 2) / 900))
    shade -= np.exp(-(fd ** 2) / 3) * 0.05
    # góc trên phải hơi cong lên: sáng hơn, góc dưới trái tối nhẹ
    shade += 0.05 * np.clip(1 - np.hypot(W - x, y) / 500, 0, 1)
    shade -= 0.04 * np.clip(1 - np.hypot(x, H - y) / 600, 0, 1)
    col *= shade[..., None]
    # mép trái xé (răng cưa + sợi lởm chởm), các mép khác thẳng nhưng hơi sờn
    edge = 26 + (noise(1, H, 40, seed + 7, 4)[:, 0] - 0.5) * 34 + (r.random(H) - 0.5) * 5
    a = np.clip((x - edge[:, None]) / 1.6, 0, 1)
    tornband = np.clip(1 - (x - edge[:, None]) / 9, 0, 1) * a
    col = col * (1 - tornband[..., None] * 0.06) + 255 * tornband[..., None] * 0.04   # sợi xé trắng hơn
    m = 6.0
    a *= np.clip((W - m - x) / 1.4 + 1, 0, 1) * np.clip((y - m) / 1.4 + 1, 0, 1) * np.clip((H - m - y) / 1.4 + 1, 0, 1)
    edged = np.clip(1 - np.minimum.reduce([W - m - x, y - m, H - m - y]) / 5, 0, 1) * 0.07
    col *= (1 - edged[..., None])
    col += (r.random((H, W, 1)) - 0.5) * 4
    rgba = np.concatenate([col, (a * 255)[..., None]], 2)
    im = save(rgba, name)
    # bóng giấy trên bàn (file riêng)
    al = Image.fromarray((a * 255).astype(np.uint8))
    pad = 60
    big = Image.new("L", (W + pad * 2, H + pad * 2), 0); big.paste(al, (pad, pad))
    sh = np.asarray(big.filter(ImageFilter.GaussianBlur(16)), np.float32)
    shc = np.zeros((H + pad * 2, W + pad * 2, 4), np.float32); shc[..., :3] = [28, 12, 4]; shc[..., 3] = sh * 0.75
    save(shc, name + "_bong")
    return im

# ------------------------------------------------------------ hình trụ (bút): profile r(x) theo chiều dài
def cyl(L, R, prof, colf, name, spec=0.5):
    H = int(R * 2 + 8)
    y, x = np.mgrid[0:H, 0:L].astype(np.float32)
    rr = np.array([prof(i / L) for i in range(L)], np.float32) * R
    cy = H / 2
    v = (y - cy) / np.maximum(rr[None, :], 0.01)
    inside = np.abs(v) <= 1
    nz = np.sqrt(np.clip(1 - v ** 2, 0, 1))
    Lt = np.array([-0.35, -0.65, 0.68]); Lt /= np.linalg.norm(Lt)
    ny = v; nx = np.zeros_like(v)
    lam = np.clip(nx * Lt[0] + ny * Lt[1] + nz * Lt[2], 0, 1)
    hvec = Lt + np.array([0, 0, 1.0]); hvec /= np.linalg.norm(hvec)
    sp = np.clip(nx * hvec[0] + ny * hvec[1] + nz * hvec[2], 0, 1) ** 40
    base = np.zeros((H, L, 3), np.float32)
    for i in range(L):
        base[:, i] = colf(i / L)
    col = base * (0.35 + 0.75 * lam[..., None]) + sp[..., None] * 255 * spec
    col += (rng.random((H, L, 1)) - 0.5) * 6
    aa = np.clip((1 - np.abs(v)) * rr[None, :] * 1.2, 0, 1) * inside
    rgba = np.concatenate([col, (aa * 255)[..., None]], 2)
    return save(rgba, name)

def pen(cap, capd, name):
    # 0..0.06 đầu bi (kim loại), 0.06..0.18 đầu côn nhựa, 0.18..0.74 thân trắng mờ, 0.74..1 nắp màu + kẹp
    def prof(t):
        if t < 0.025: return 0.12
        if t < 0.07: return 0.12 + (t - 0.025) / 0.045 * 0.25
        if t < 0.2: return 0.37 + (t - 0.07) / 0.13 * 0.5
        if t < 0.72: return 0.87
        if t < 0.735: return 0.96
        if t < 0.985: return 1.0
        return 0.8
    def colf(t):
        if t < 0.07: return np.array([180, 182, 186])
        if t < 0.2: return np.array([235, 233, 226]) if t > 0.12 else np.array(capd)
        if t < 0.72:
            k = math.sin(t * 160) * 0.015
            return np.array([238, 236, 230]) * (1 + k)
        return np.array(cap)
    cyl(900, 40, prof, colf, name, 0.55)

def eraser():
    W, H = 300, 170
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    # khối cao su trắng bo góc, mặt trên + cạnh dưới, nửa trái bọc giấy xanh
    rad = 22
    def sdf(px, py, w, h, r):
        qx = np.abs(px - w / 2) - (w / 2 - r); qy = np.abs(py - h / 2) - (h / 2 - r)
        return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r
    d = sdf(x - 10, y - 10, 280, 120, rad)
    d2 = sdf(x - 10, y - 30, 280, 130, rad)
    top = d <= 0
    side = (d2 <= 0) & ~top
    col = np.zeros((H, W, 3), np.float32)
    n = noise(W, H, 3, 41, 2)
    rubber = np.array([246, 238, 232])
    sleeve = np.array([52, 118, 196])
    isS = x < 150
    c = np.where(isS[..., None], sleeve, rubber)
    t = np.clip(-d / 18, 0, 1)
    col = c * (0.82 + 0.18 * t[..., None]) * (0.96 + 0.08 * n[..., None])
    col = np.where(side[..., None], c * 0.62 * (0.95 + 0.1 * n[..., None]), col)
    # vết tẩy đen xám ở đầu cao su
    smudge = np.clip(1 - np.hypot((x - 270) / 30, (y - 70) / 60), 0, 1) * (n > 0.45)
    col *= (1 - smudge[..., None] * 0.25)
    a = np.clip(-np.minimum(d, d2) * 1.2, 0, 1)
    save(np.concatenate([col, (a * 255)[..., None]], 2), "tay")


# ------------------------------------------------------------ thước kẻ nhựa trong 20 cm (1 cm = 76 px), 1640 x 190
def ruler():
    CM = 76.0; W = int(CM * 21 + 40); H = 190
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    r = 18
    def sdf(px, py, w, h, rr):
        qx = np.abs(px - w / 2) - (w / 2 - rr); qy = np.abs(py - h / 2) - (h / 2 - rr)
        return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - rr
    d = sdf(x - 4, y - 4, W - 8, H - 8, r)
    a = np.clip(-d, 0, 1)
    # nhựa trong hơi xanh: nền mờ (alpha thấp) + mép dày sáng/tối (khúc xạ), vạch in trắng đục
    base = np.array([196, 226, 238], np.float32)
    col = np.zeros((H, W, 3), np.float32) + base
    al = np.full((H, W), 0.30, np.float32)
    edge = np.clip(1 - (-d) / 10, 0, 1)
    col = col * (1 - edge[..., None] * 0.35) + np.array([255, 255, 255]) * np.clip(1 - np.abs(-d - 3) / 2, 0, 1)[..., None] * 0.7
    al = al + edge * 0.45
    # vát mép dưới (cạnh thước nghiêng): dải sáng
    bev = np.clip(1 - np.abs(y - (H - 40)) / 18, 0, 1) * 0.25
    col += bev[..., None] * 60; al += bev * 0.3
    # trầy xước + bụi trên nhựa
    n = noise(W, H, 2, 51, 1)
    scr = np.zeros((H, W), np.float32)
    rr_ = np.random.default_rng(52)
    for i in range(90):
        x0, y0 = rr_.random() * W, rr_.random() * H; an = rr_.normal(0, 0.3); L = int(rr_.random() * 90 + 10)
        xs = (x0 + np.cos(an) * np.arange(L)).astype(int); ys = (y0 + np.sin(an) * np.arange(L)).astype(int)
        m = (xs >= 0) & (xs < W) & (ys >= 0) & (ys < H); scr[ys[m], xs[m]] = 0.5
    al += scr * 0.25 + (n - 0.5) * 0.06
    col += scr[..., None] * 80
    # vạch chia: mm, 5 mm, cm (từ mép trên)
    ink = np.zeros((H, W), np.float32)
    x0 = 20 + CM * 0.5
    for i in range(0, 201):
        xi = x0 + i * CM / 10
        L = 52 if i % 10 == 0 else (36 if i % 5 == 0 else 24)
        m = (np.abs(x - xi) < 1.3) & (y > 6) & (y < 6 + L)
        ink[m] = 1
    im = Image.fromarray((ink * 255).astype(np.uint8))
    from PIL import ImageDraw, ImageFont
    dr = ImageDraw.Draw(im)
    f = ImageFont.truetype("/home/user/vu-mua/src/godot/ui/font/baloo2.ttf", 34)
    for c in range(0, 21):
        t = str(c); tw = dr.textlength(t, font=f)
        dr.text((x0 + c * CM - tw / 2, 60), t, fill=255, font=f)
    ink = np.asarray(im, np.float32) / 255
    ink = ink * (0.85 + 0.15 * n)
    col = col * (1 - ink[..., None]) + np.array([40, 52, 96])[None, None] * ink[..., None]
    al = np.maximum(al, ink * 0.95)
    al = np.clip(al, 0, 1) * a
    save(np.concatenate([col, (al * 255)[..., None]], 2), "thuoc")

# ------------------------------------------------------------ cuốn tập (vở học sinh) đóng: bìa xanh, nhãn trắng kẻ dòng, gáy ghim, mép giấy
def notebook(name="tap", cov=(86, 150, 206), seed=61):
    W, H = 900, 1240
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    rr_ = np.random.default_rng(seed)
    # chồng ruột giấy lòi ra mép phải + dưới (dày ~14 px), bìa nằm trên
    def rect(px, py, x0, y0, x1, y1, rad):
        qx = np.maximum(np.maximum(x0 + rad - px, px - (x1 - rad)), 0); qy = np.maximum(np.maximum(y0 + rad - py, py - (y1 - rad)), 0)
        return np.hypot(qx, qy) - rad
    dp = rect(x, y, 8, 8, W - 6, H - 6, 10)
    dc = rect(x, y, 2, 2, W - 22, H - 20, 12)
    col = np.zeros((H, W, 3), np.float32)
    # ruột: nhiều tờ, sọc mảnh song song mép
    lines = 0.5 + 0.5 * np.sin(np.maximum(x - (W - 22), y - (H - 20)) * 2.6)
    pg = np.array([238, 232, 216], np.float32) * (0.86 + 0.1 * lines[..., None])
    col[:] = pg
    # bìa: vải giấy sần, gradient sáng góc trên trái, mép bìa bo tối
    n1 = noise(W, H, 2, seed + 1, 2); n2 = noise(W, H, 90, seed + 2, 3)
    c = np.array(cov, np.float32)
    shade = 0.92 + 0.12 * (1 - (x / W * 0.5 + y / H * 0.5))[..., None] + (n2[..., None] - 0.5) * 0.08 + (n1[..., None] - 0.5) * 0.16 + (noise(W, H, 8, seed + 3, 2)[..., None] - 0.5) * 0.08
    cov_c = c * shade
    ed = np.clip(1 + dc / 6, 0, 1)
    cov_c *= (1 - ed[..., None] * 0.25)
    # mép bìa sờn trắng (lòi lớp giấy bìa), góc mòn nhiều hơn, vết gấp chéo góc dưới phải, vết nhăn mềm
    wear = np.clip(1 + dc / 9, 0, 1) * (noise(W, H, 5, seed + 4, 2) > 0.52)
    cx_ = np.minimum(x, W - 22 - x); cy_ = np.minimum(y, H - 20 - y)
    corner = np.clip(1 - np.hypot(np.minimum(cx_, 80), np.minimum(cy_, 80)) / 70, 0, 1)
    cov_c = cov_c * (1 - (wear * 0.5 + corner * 0.25)[..., None]) + np.array([245, 240, 228]) * (wear * 0.5 + corner * 0.25)[..., None]
    fold = (x - (W - 22)) + (y - (H - 20)) + 150
    cov_c *= (1 + np.where(fold > 0, 0.07, -0.05 * np.exp(-fold ** 2 / 200)))[..., None]
    wr = noise(W, H, 140, seed + 5, 3)
    gy_, gx_ = np.gradient(wr * 50)
    cov_c *= (1 + (-gx_ - gy_) * 0.05)[..., None]
    inC = dc <= 0
    col = np.where(inC[..., None], cov_c, col)
    # sọc trang trí mảnh trên bìa (đường lượn sóng nhạt) + gáy đậm hơn bên trái + 2 ghim bấm
    wave = np.clip(1 - np.abs(np.sin(x / 70 + np.sin(y / 160) * 1.5) * 40 - (y % 120 - 60)) / 3, 0, 1) * 0.12
    col = np.where(inC[..., None], col * (1 + wave[..., None]), col)
    sp = np.clip(1 - (x - 2) / 46, 0, 1)
    col = np.where(inC[..., None], col * (1 - sp[..., None] * 0.28), col)
    for sy in (H * 0.26, H * 0.72):
        m = (np.abs(x - 20) < 3) & (np.abs(y - sy) < 40)
        col[m] = [196, 198, 204]; col[m & (x < 20)] = [150, 152, 160]
    # nhãn trắng: khung bo, 3 dòng chấm "Họ tên / Lớp / Trường" (không chữ thương hiệu)
    lx0, ly0, lx1, ly1 = 150, 440, 770, 860
    dl = rect(x, y, lx0, ly0, lx1, ly1, 26)
    lab = dl <= 0
    col = np.where(lab[..., None], np.array([250, 248, 240]) * (0.96 + 0.06 * n1[..., None]), col)
    ring = np.clip(1 - np.abs(dl + 10) / 2.5, 0, 1)
    col = col * (1 - ring[..., None] * 0.5) + np.array(cov) * 0.6 * ring[..., None] * 0.5
    for i, ly in enumerate((650, 730, 810)):
        m = lab & (np.abs(y - ly) < 1.6) & (x > 330) & (x < 740) & (np.mod(x, 14) < 7)
        col[m] = [120, 120, 140]
    from PIL import ImageDraw, ImageFont
    im = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8))
    dr = ImageDraw.Draw(im)
    f = ImageFont.truetype("/home/user/vu-mua/src/godot/ui/font/baloo2.ttf", 40)
    fb = ImageFont.truetype("/home/user/vu-mua/src/godot/ui/font/baloo2.ttf", 64)
    dr.text((W / 2 - 10 - dr.textlength("TẬP HỌC SINH", font=fb) / 2, 462), "TẬP HỌC SINH", fill=tuple(int(v * 0.6) for v in cov), font=fb)
    for t, ly in (("Tên:", 650), ("Lớp:", 730), ("Trường:", 810)):
        dr.text((200, ly - 34), t, fill=(90, 90, 110), font=f)
    col = np.asarray(im, np.float32)
    # nét bút chì nguệch ngoạc trên dòng Tên (chữ ký con nít)
    for k in range(260):
        tt = k / 260; px_ = int(350 + tt * 280); py_ = int(632 + math.sin(tt * 40) * 9 + math.sin(tt * 7) * 5)
        col[py_ - 1:py_ + 2, px_ - 1:px_ + 2] = col[py_ - 1:py_ + 2, px_ - 1:px_ + 2] * 0.5 + np.array([70, 70, 80]) * 0.5
    al = np.clip(-dp, 0, 1)
    save(np.concatenate([col + (rr_.random((H, W, 1)) - 0.5) * 5, (al * 255)[..., None]], 2), name)

# ------------------------------------------------------------ bút chì gỗ lục giác vàng, đầu gọt, gôm hồng + khâu nhôm, 1100 x 76
def pencil():
    L, R = 1100, 34
    H = R * 2 + 8
    y, x = np.mgrid[0:H, 0:L].astype(np.float32)
    t = x / L; cy = H / 2
    rr = np.where(t < 0.12, np.clip((t - 0.005) / 0.115, 0.02, 1), 1.0) * R
    v = (y - cy) / np.maximum(rr, 0.01)
    inside = np.abs(v) <= 1
    # lục giác: 3 mặt thấy được, bậc sáng theo mặt
    face = np.clip(np.floor((v + 1) / 2 * 3), 0, 2)
    lam = np.array([1.05, 0.88, 0.62])[face.astype(int)]
    body = np.array([238, 186, 38], np.float32)
    wood = np.array([226, 182, 132], np.float32)
    lead = np.array([58, 58, 64], np.float32)
    alu = np.array([196, 198, 204], np.float32)
    pink = np.array([232, 132, 140], np.float32)
    col = np.zeros((H, L, 3), np.float32) + body
    n = noise(L, H, 2, 71, 1)
    col = np.where((t < 0.12)[..., None], wood * (0.85 + 0.25 * n[..., None]), col)
    col = np.where((t < 0.035)[..., None], lead, col)
    col = np.where(((t > 0.885) & (t < 0.95))[..., None], alu * (0.8 + 0.2 * np.sin(x * 0.9)[..., None] ** 2), col)
    col = np.where((t >= 0.95)[..., None], pink * (0.9 + 0.1 * n[..., None]), col)
    nz = np.sqrt(np.clip(1 - v ** 2, 0, 1))
    sh = np.where(t < 0.12, 0.45 + 0.6 * np.clip(-v * 0.6 + nz * 0.7, 0, 1), lam)
    sh = np.where(t >= 0.885, 0.45 + 0.6 * np.clip(-v * 0.6 + nz * 0.7, 0, 1), sh)
    col = col * sh[..., None]
    # đường gọt răng cưa giữa sơn và gỗ, chữ in vàng nhũ nhỏ
    scal = (np.abs(t - (0.12 + 0.008 * np.sin(v * 9))) < 0.003)
    col[scal & inside] *= 0.7
    col += (n[..., None] - 0.5) * 8
    aa = np.clip((1 - np.abs(v)) * rr * 1.2, 0, 1) * inside
    save(np.concatenate([col, (aa * 255)[..., None]], 2), "butchi")

# ------------------------------------------------------------ gọt bút chì nhôm + vỏ bào chì (2 file)
def sharpener():
    W, H = 240, 160
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    def rect(px, py, x0, y0, x1, y1, rad):
        qx = np.maximum(np.maximum(x0 + rad - px, px - (x1 - rad)), 0); qy = np.maximum(np.maximum(y0 + rad - py, py - (y1 - rad)), 0)
        return np.hypot(qx, qy) - rad
    d = rect(x, y, 10, 14, 230, 150, 14)
    n = noise(W, H, 2, 81, 1)
    # nhôm chải xước ngang
    brush = noise(W, H, 1, 82, 1)
    brush = np.asarray(Image.fromarray((brush * 255).astype(np.uint8)).resize((W // 40 + 1, H)).resize((W, H), Image.BILINEAR), np.float32) / 255
    col = np.array([186, 190, 198], np.float32) * (0.85 + 0.25 * brush[..., None]) * (1.05 - 0.2 * (y / H))[..., None]
    # lỗ côn tối + lưỡi dao thép bắt vít
    hole = np.hypot((x - 70) / 34, (y - 82) / 34)
    col = np.where((hole < 1)[..., None], np.array([40, 40, 46]) * (0.6 + 0.6 * hole[..., None]), col)
    blade = (x > 104) & (x < 214) & (y > 40) & (y < 92)
    col = np.where(blade[..., None], np.array([150, 156, 168]) * (0.9 + 0.2 * n[..., None]) * (1.1 - (y - 40) / 52 * 0.25)[..., None], col)
    sc = np.hypot(x - 180, y - 66) < 11
    col = np.where(sc[..., None], np.array([110, 112, 120]) * (1.1 - np.hypot(x - 176, y - 62)[..., None] / 20), col)
    col = np.where((sc & (np.abs(x - 180) < 1.5))[..., None], [60, 60, 66], col)
    ed = np.clip(1 + d / 4, 0, 1)
    col *= (1 - ed[..., None] * 0.3)
    a = np.clip(-d, 0, 1)
    save(np.concatenate([col, (a * 255)[..., None]], 2), "gotchi")
    # vỏ bào: vòng xoắn gỗ, viền sơn vàng răng cưa
    W2 = 200; y, x = np.mgrid[0:W2, 0:W2].astype(np.float32)
    ang = np.arctan2(y - 100, x - 100); rad = np.hypot(x - 100, y - 100)
    rr = 20 + (ang + math.pi) / (2 * math.pi) * 70
    band = (rad < rr) & (rad > rr * 0.35)
    tt = np.clip((rad - rr * 0.35) / (rr * 0.65), 0, 1)
    col = np.array([224, 186, 140], np.float32) * (0.75 + 0.35 * tt[..., None]) * (0.9 + 0.2 * noise(W2, W2, 2, 83, 1)[..., None])
    rim = band & (rad > rr - 6)
    col = np.where(rim[..., None], np.array([234, 176, 34]) * (0.85 + 0.25 * (np.sin(ang * 6)[..., None] > 0)), col)
    tip = band & (rad > rr - 9) & (rad <= rr - 6)
    col = np.where(tip[..., None], [70, 70, 76], col)
    a = band.astype(np.float32)
    a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)), np.float32) / 255
    save(np.concatenate([col, (a * 255)[..., None]], 2), "vobao")

if __name__ == "__main__":
    which = sys.argv[2:] or ["desk", "paper", "pen", "eraser", "ruler", "notebook", "pencil", "sharpener"]
    if "desk" in which: desk()
    if "paper" in which:
        paper(1400, 3400, "giay", 21)
        paper(3400, 1400, "giay_ngang", 22)
    if "pen" in which:
        pen([40, 92, 200], [30, 70, 170], "but_xanh")
        pen([214, 46, 52], [170, 30, 36], "but_do")
    if "eraser" in which: eraser()
    if "ruler" in which: ruler()
    if "notebook" in which:
        notebook("tap", (86, 150, 206), 61)
        notebook("tap_hong", (226, 128, 150), 62)
    if "pencil" in which: pencil()
    if "sharpener" in which: sharpener()
    print("ok")
