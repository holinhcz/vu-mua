#!/usr/bin/env python3
# VẼ LẠI 7 MỒI CÂU cho Câu cá (Link 11-24 "vẽ lại mấy mồi cho đẹp như mấy con cá"):
# cùng kiểu với cá (tools/cc/ca/ca_ve.py): tô TỪNG ĐIỂM ẢNH bằng numpy, mỗi món là khối cong thật (mặt cao h -> pháp tuyến),
# sáng từ trên-trái (cùng hướng nắng của cá), mờ không bóng loáng, chỗ chồng nhau có bóng tiếp xúc, viền mảnh màu tối
# của chính chỗ đó (không viền đen đều), không bóng đổ dưới đất (cá cũng không có).
# Ra ui/img/cc/ic-<id>.webp (webp lossless, cắt sát + chừa mép) -> tên file giữ như cũ, code nào đọc ic-<id> cũng ăn hình mới.
# python3 moi_ve.py OUTDIR [id ...]      id: trun com tep chua nhai sung cam
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

OUT = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/moi'
IDS = sys.argv[2:] or ['trun', 'com', 'tep', 'chua', 'nhai', 'sung', 'cam']
os.makedirs(OUT, exist_ok=True)
U = 512            # khung vẽ (đơn vị), ảnh ra cỡ này (cắt sát)
SS = 2             # vẽ gấp đôi rồi thu (khử răng cưa)
SC = float(os.environ.get('MOI_SC', '1'))    # phóng to ảnh ra (toạ độ vẽ vẫn là khung 512): ve_ech.py dùng 3
PX = SS * SC       # điểm ảnh lưới vẽ / 1 đơn vị
N = int(round(U * PX))
OW = int(round(U * SC))
LIGHT = np.array([-.45, -.62, .64]); LIGHT /= np.linalg.norm(LIGHT)     # x phải, y XUỐNG, z ra mặt
HALF = LIGHT + np.array([0, 0, 1.0]); HALF /= np.linalg.norm(HALF)
_yy, _xx = np.mgrid[0:N, 0:N].astype(np.float32)
X = (_xx + .5) / PX
Y = (_yy + .5) / PX


def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def noise(scale, seed, octaves=3):
    """nhiễu mềm -1..1 (cộng nhiều tầng lọc gauss)"""
    r = np.random.RandomState(seed)
    out = np.zeros((N, N), np.float32); amp = 1.0; tot = 0
    for o in range(octaves):
        s = scale * PX / (2 ** o)
        f = ndi.gaussian_filter(r.randn(N, N).astype(np.float32), max(.6, s))
        f /= (f.std() + 1e-6)
        out += f * amp; tot += amp; amp *= .5
    return np.clip(out / tot / 2.2, -1, 1)


def aa(sdf):
    """sdf (đơn vị, âm = trong) -> độ phủ mịn"""
    return np.clip(.5 - sdf * PX, 0, 1)


# ------------------------------------------------------------ hình cơ bản: trả (phủ, mặt cao h theo đơn vị)
def ellipse(cx, cy, rx, ry, rot=0.0, hk=1.0, flat=0.0):
    c, s = math.cos(rot), math.sin(rot)
    u = (X - cx) * c + (Y - cy) * s
    v = -(X - cx) * s + (Y - cy) * c
    q = np.sqrt((u / rx) ** 2 + (v / ry) ** 2)
    m = aa((q - 1) * min(rx, ry))
    z = np.sqrt(np.clip(1 - q * q, 0, 1))
    if flat:
        z = np.minimum(1, z / (1 - flat + 1e-6) * (1 - flat) + flat * sstep(0, .5, z))
    return m, z * min(rx, ry) * hk


def poly_mask(pts):
    im = Image.new('L', (N, N), 0)
    ImageDraw.Draw(im).polygon([(x * PX, y * PX) for x, y in pts], fill=255)
    return np.asarray(im).astype(np.float32) / 255


def puff(mask, R, hk=1.0):
    """khối phồng từ 1 mặt nạ: mép bo tròn bán kính R (đơn vị), giữa phẳng"""
    d = ndi.distance_transform_edt(mask > .5) / PX
    t = np.clip(d / R, 0, 1)
    h = np.sqrt(1 - (1 - t) ** 2) * R * hk
    m = ndi.gaussian_filter(mask, .7)
    return m, h


def tube(pts, rads, n=None):
    """ống tròn dọc đường gấp khúc: rads = bán kính tại từng điểm. Trả (phủ, h, s = độ dài dọc ống (đơn vị), side = lệch ngang có dấu -1..1)"""
    P = np.array(pts, np.float32); R = np.array(rads, np.float32)
    best = np.full((N, N), 1e9, np.float32); hh = np.zeros((N, N), np.float32)
    ss = np.zeros((N, N), np.float32); sd = np.zeros((N, N), np.float32)
    acc = 0.0
    for i in range(len(P) - 1):
        a, b = P[i], P[i + 1]; ra, rb = R[i], R[i + 1]
        L = float(np.hypot(*(b - a))) + 1e-6
        rm = max(ra, rb) + 2
        x0 = int(max(0, (min(a[0], b[0]) - rm) * PX)); x1 = int(min(N, (max(a[0], b[0]) + rm) * PX + 1))
        y0 = int(max(0, (min(a[1], b[1]) - rm) * PX)); y1 = int(min(N, (max(a[1], b[1]) + rm) * PX + 1))
        if x1 <= x0 or y1 <= y0:
            acc += L; continue
        xs = X[y0:y1, x0:x1]; ys = Y[y0:y1, x0:x1]
        d = (b - a) / L
        t = np.clip(((xs - a[0]) * d[0] + (ys - a[1]) * d[1]) / L, 0, 1)
        px = a[0] + (b[0] - a[0]) * t; py = a[1] + (b[1] - a[1]) * t
        dist = np.hypot(xs - px, ys - py)
        r = ra + (rb - ra) * t
        sdf = dist - r
        cur = best[y0:y1, x0:x1]
        ok = sdf < cur
        best[y0:y1, x0:x1] = np.where(ok, sdf, cur)
        z = np.sqrt(np.clip(r * r - dist * dist, 0, None))
        hh[y0:y1, x0:x1] = np.where(ok, z, hh[y0:y1, x0:x1])
        ss[y0:y1, x0:x1] = np.where(ok, acc + t * L, ss[y0:y1, x0:x1])
        cr = (xs - a[0]) * d[1] - (ys - a[1]) * d[0]
        sd[y0:y1, x0:x1] = np.where(ok, np.clip(cr / np.maximum(r, 1e-3), -1, 1), sd[y0:y1, x0:x1])
        acc += L
    return aa(best), hh, ss, sd


def bez(p0, p1, p2, p3, n=40):
    out = []
    for i in range(n + 1):
        t = i / n; u = 1 - t
        out.append((u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                    u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]))
    return out


def cr_path(pts, n=12):
    """catmull-rom qua các điểm"""
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = [np.array(p, np.float32) for p in P[i - 1:i + 3]]
        for k in range(n):
            t = k / n
            out.append(tuple(.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)))
    out.append(tuple(pts[-1]))
    return out


# ------------------------------------------------------------ tô
class Pic:
    def __init__(self):
        self.rgb = np.zeros((N, N, 3), np.float32)
        self.a = np.zeros((N, N), np.float32)
        self.edge = np.zeros((N, N, 3), np.float32)    # màu viền theo chỗ

    def shade(self, h, base, amb=.42, dif=.78, spec=.06, sp_pow=18, rim=0.0, ao=None):
        gy, gx = np.gradient(h * PX)
        nx, ny, nz = -gx, -gy, np.ones_like(h)
        ln = np.sqrt(nx * nx + ny * ny + nz * nz)
        nx, ny, nz = nx / ln, ny / ln, nz / ln
        d = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
        hs = np.clip(nx * HALF[0] + ny * HALF[1] + nz * HALF[2], 0, 1) ** sp_pow
        lum = amb + dif * d
        if ao is not None:
            lum = lum * (1 - ao)
        col = base * lum[..., None] + spec * hs[..., None]
        if rim:
            col = col + rim * ((1 - nz) ** 2)[..., None] * base
        return np.clip(col, 0, 1), (nx, ny, nz)

    def put(self, m, col, edge=None, line=.55, lw=1.3, contact=.38, cblur=7.0):
        """đặt 1 lớp: bóng tiếp xúc lên lớp dưới, rồi tô, rồi nét mép mảnh (màu tối của chính lớp)"""
        if contact and self.a.max() > 0:
            sh = ndi.gaussian_filter(m, cblur * PX)
            sh = np.roll(np.roll(sh, int(2.5 * PX), 0), int(1.5 * PX), 1)
            k = 1 - contact * sh * (1 - m)
            self.rgb *= k[..., None]
        ec = (col * .38) if edge is None else (np.broadcast_to(edge, col.shape))
        if line:
            er = ndi.grey_erosion(m, size=(int(lw * 2 * PX) | 1, int(lw * 2 * PX) | 1))
            ring = np.clip(m - er, 0, 1) * line
            col = col * (1 - ring[..., None]) + ec * ring[..., None]
        self.rgb = self.rgb * (1 - m[..., None]) + col * m[..., None]
        self.edge = self.edge * (1 - m[..., None]) + ec * m[..., None]
        self.a = np.maximum(self.a, m)

    def paint(self, col, m):   # tô thêm màu lên chỗ đã có (vân, đốm), không đổi phủ
        self.rgb = self.rgb * (1 - m[..., None]) + col * m[..., None]

    def mul(self, k):
        self.rgb *= np.clip(k, 0, 2)[..., None]

    def save(self, name, ow=2.6):
        # viền ngoài mảnh: màu tối của chỗ sát mép (như cá), không đen đều
        a = self.a
        w = ow * PX
        dil = ndi.grey_dilation(a, size=(int(w * 2) | 1, int(w * 2) | 1))
        dil = ndi.gaussian_filter(dil, .6 * PX)
        ring = np.clip(dil - a, 0, 1)
        num = ndi.gaussian_filter(self.edge * a[..., None], (3 * PX, 3 * PX, 0))
        den = ndi.gaussian_filter(a, 3 * PX)[..., None] + 1e-4
        ec = np.clip(num / den * .8, 0, 1)
        rgb = self.rgb * a[..., None] + ec * ring[..., None]
        al = np.clip(a + ring, 0, 1)
        rgb = rgb / np.maximum(al[..., None], 1e-4)
        im = Image.fromarray(np.dstack([np.clip(rgb, 0, 1) * 255, al * 255]).astype(np.uint8), 'RGBA')
        im = im.resize((OW, OW), Image.LANCZOS)
        bb = im.getchannel('A').point(lambda v: 255 if v > 3 else 0).getbbox()
        pad = int(6 * SC)
        im = im.crop((max(0, bb[0] - pad), max(0, bb[1] - pad), min(OW, bb[2] + pad), min(OW, bb[3] + pad)))
        p = os.path.join(OUT, 'ic-%s.webp' % name)
        im.save(p, 'WEBP', lossless=True, quality=100, method=6)
        print(name, im.size, os.path.getsize(p))
        return im


def lerpc(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return a * (1 - t) + b * t


def specks(seed, n, x0, y0, x1, y1, r0, r1, inside=None):
    """đốm nhỏ ngẫu nhiên: trả mặt nạ"""
    rs = np.random.RandomState(seed)
    m = np.zeros((N, N), np.float32)
    for _ in range(n):
        x = rs.uniform(x0, x1); y = rs.uniform(y0, y1); r = rs.uniform(r0, r1)
        if inside is not None:
            iy, ix = int(y * PX), int(x * PX)
            if not (0 <= iy < N and 0 <= ix < N) or inside[iy, ix] < .9:
                continue
        e, _ = ellipse(x, y, r * rs.uniform(.7, 1.3), r * rs.uniform(.7, 1.3), rs.uniform(0, 3.14))
        m = np.maximum(m, e)
    return m


# ============================================================ 1. TRÙN ĐẤT
def trun():
    P = Pic()
    # vụn đất phía dưới (sau con trùn)
    rs = np.random.RandomState(3)
    for i in range(9):
        x = rs.uniform(110, 420); y = rs.uniform(392, 428); r = rs.uniform(9, 19)
        m, h = ellipse(x, y, r * 1.25, r * .8, rs.uniform(-.4, .4))
        h = h + noise(2.5, 30 + i) * 2.2 * m
        c, _ = P.shade(h, hexc('#6b4528') * (1 + .18 * noise(3, 50 + i))[..., None], amb=.4, dif=.7, spec=.02)
        P.put(m, c, contact=.2)
    sp = cr_path([(52, 318), (96, 236), (160, 180), (226, 196), (262, 270), (300, 352), (360, 378), (418, 330), (446, 262), (462, 214)], 14)
    n = len(sp)
    L = sum(math.hypot(sp[i + 1][0] - sp[i][0], sp[i + 1][1] - sp[i][1]) for i in range(n - 1))
    rads = []
    acc = 0
    for i in range(n):
        if i:
            acc += math.hypot(sp[i][0] - sp[i - 1][0], sp[i][1] - sp[i - 1][1])
        t = acc / L
        r = 30 - 10 * t                                   # đầu (trái) to, đuôi thon
        r *= min(1, .55 + t * 9) * min(1, .5 + (1 - t) * 12)     # 2 đầu bo tròn nhọn dần
        if .2 < t < .31:
            r += 4.5 * math.sin((t - .2) / .11 * math.pi)  # đai sinh dục (khoanh to, nhạt màu)
        rads.append(r)
    m, h, s, sd = tube(sp, rads)
    t = s / L
    ring = .5 + .5 * np.cos(s / 9.0 * 2 * math.pi)       # khoanh đốt
    ring = ring ** 6
    h = h * (1 - .06 * ring)                              # rãnh giữa đốt lõm nhẹ
    top = hexc('#9c3a48'); mid = hexc('#cf6f73'); bel = hexc('#e9a7a1')
    # lưng (phía trên đường ống) sẫm, bụng hồng nhạt
    base = lerpc(top, mid, sstep(-.9, .2, -sd * np.sign(1)))
    base = lerpc(base, bel, sstep(.3, 1.0, sd))
    cl = sstep(.19, .22, t) * (1 - sstep(.3, .33, t))
    base = lerpc(base, hexc('#e3917e'), cl * .85)
    base = base * (1 - .16 * ring)[..., None]
    base = base * (1 + .06 * noise(2, 7))[..., None]
    c, _ = P.shade(h, base, amb=.42, dif=.72, spec=.14, sp_pow=26)
    P.put(m, c, contact=.3)
    return P.save('trun')


# ============================================================ 2. CƠM VO CÁM (nắm cơm lăn cám, để trên miếng lá chuối)
def com():
    P = Pic()
    # lá chuối: thuôn dài, hơi cong, gân giữa + gân song song chéo
    up = bez((34, 376), (150, 300), (330, 300), (482, 338), 60)
    dn = bez((482, 338), (360, 420), (170, 446), (34, 376), 60)
    lm = poly_mask(up + dn[1:])
    m, h = puff(lm, 14, .5)
    # trục lá ~ đường giữa
    ax = np.array(bez((34, 376), (160, 372), (330, 360), (482, 338), 80), np.float32)
    mm, _, s_ax, sd = tube([tuple(p) for p in ax], [60] * len(ax))
    vein = .5 + .5 * np.cos((s_ax * .96 + np.abs(sd) * 36) / 7.0 * 2 * math.pi)
    vein = vein ** 8
    h = h - 1.2 * vein * m + 2.5 * (1 - sstep(0, .06, np.abs(sd))) * m
    g1 = hexc('#3f8a34'); g2 = hexc('#6fb44a')
    base = lerpc(g1, g2, .5 + .5 * sd) * (1 - .12 * vein)[..., None]
    base = lerpc(base, hexc('#b9d98a'), (1 - sstep(.015, .05, np.abs(sd))) * .8)        # gân giữa nhạt
    base = lerpc(base, hexc('#8a7a3a'), sstep(.88, 1.0, np.abs(sd)) * .5)               # mép lá úa
    c, _ = P.shade(h, base, amb=.45, dif=.7, spec=.05)
    P.put(m, c, contact=0)
    # nắm cơm: tròn hơi dẹt đáy, mặt lổn nhổn hạt gạo
    cx, cy, R = 252, 236, 150
    bm, bh = ellipse(cx, cy, R, R * .92)
    flat = sstep(cy + R * .55, cy + R * .92, Y)
    bm = bm * (1 - flat * sstep(.0, .2, (Y - (cy + R * .78)) / 30))
    rs = np.random.RandomState(11)
    gr = np.zeros((N, N), np.float32); gh = np.zeros((N, N), np.float32); gid = np.ones((N, N), np.float32)
    for i in range(330):
        a = rs.uniform(0, 2 * math.pi); rr = R * math.sqrt(rs.uniform(0, 1.0))
        x = cx + math.cos(a) * rr; y = cy + math.sin(a) * rr * .92
        # hạt gần mép nghiêng theo mặt cầu (thấy đầu hạt) -> ngắn lại
        k = 1 - .6 * (rr / R) ** 2
        e, eh = ellipse(x, y, 21 * (k * .65 + .35), 8.5, rs.uniform(0, math.pi), hk=.6)
        sel = eh > gh                                                   # hạt nổi cao nhất ở trên (không cộng dồn)
        gr = np.where(sel, e, gr); gh = np.where(sel, eh, gh); gid = np.where(sel & (e > .3), rs.uniform(.95, 1.04), gid)
    bh = bh + gh * .55
    gaps = 1 - sstep(.0, .5, gr)                                         # khe giữa hạt
    rice = hexc('#fbf8f1') * gid[..., None]
    base = lerpc(rice, hexc('#dccdab'), gaps * .7)
    # hạt gạo trong mờ: tâm hạt hơi ngà
    base = lerpc(base, hexc('#f1e6cc'), sstep(.4, 1, gh / 5.1) * .35)
    # cám: bụi vàng ngà mỏng bám từng mảng + vụn cám dẹt (mảnh vỏ lụa)
    dust = sstep(.1, .8, noise(4, 21))
    base = lerpc(base, hexc('#e3c58c'), dust * .42)
    rs2 = np.random.RandomState(31)
    fl = np.zeros((N, N), np.float32); fc = np.zeros((N, N, 3), np.float32)
    for i in range(150):
        a = rs2.uniform(0, 2 * math.pi); rr = R * math.sqrt(rs2.uniform(0, .97))
        x = cx + math.cos(a) * rr; y = cy + math.sin(a) * rr * .92
        e, _ = ellipse(x, y, rs2.uniform(2.2, 5.5), rs2.uniform(1.0, 2.2), rs2.uniform(0, math.pi))
        e = e * rs2.uniform(.55, .95)
        col = hexc('#b98a4c') if rs2.rand() < .6 else hexc('#8a5c2e')
        fc = fc * (1 - e[..., None]) + col * e[..., None]; fl = np.maximum(fl, e)
    base = base * (1 - fl[..., None]) + fc * fl[..., None] / np.maximum(fl[..., None], 1e-4) * fl[..., None]
    c, _ = P.shade(bh, base, amb=.5, dif=.6, spec=.04, sp_pow=12, ao=gaps * .05)
    P.put(bm, c, edge=hexc('#6a5434'), contact=.45, cblur=9)
    return P.save('com')


# ============================================================ 3. TÉP SỐNG (tép đồng cong mình)
def tep():
    P = Pic()
    cx, cy, R = 262, 262, 118
    # sống lưng là cung tròn: đầu ở trên-trái, đuôi cong xuống dưới-trái
    a0, a1 = math.radians(-160), math.radians(118)
    def at(t, r=R):
        a = a0 + (a1 - a0) * t
        return (cx + math.cos(a) * r, cy + math.sin(a) * r), a
    tint = lambda k: hexc('#eaa184') * k
    # râu dài (sau cùng): 2 sợi vắt qua lưng ra sau
    (hx, hy), ha = at(0)
    for j, (dx, dy, c2) in enumerate([(-40, -70, (420, 40)), (-60, -30, (470, 120))]):
        pts = bez((hx - 30, hy - 8), (hx + dx, hy + dy), (c2[0] - 160, c2[1] - 60), c2, 60)
        m, h, _, _ = tube(pts, [2.6 - 1.4 * i / 60 for i in range(61)])
        c, _ = P.shade(h, hexc('#a25b46'), amb=.45, dif=.6)
        P.put(m, c, line=0, contact=0)
    # chân bơi dưới bụng + chân bò dưới đầu
    for k in range(5):
        t = .32 + k * .12
        (x, y), a = at(t, R - 40)
        nx, ny = math.cos(a), math.sin(a)
        p2 = (x - nx * 24 + math.cos(a + 1.6) * 12, y - ny * 24 + math.sin(a + 1.6) * 12)
        pm = (x - nx * 14, y - ny * 14)
        m, h, _, _ = tube([(x, y), pm, p2], [3.6, 2.8, 1.6])
        c, _ = P.shade(h, tint(.9), amb=.45, dif=.6)
        P.put(m, c, line=.4, lw=1, contact=.15)
    for k in range(4):
        (x, y), a = at(.06 + k * .045, R - 44)
        m, h, _, _ = tube([(x, y), (x - 6 - k * 4, y + 34), (x - 22 - k * 6, y + 60)], [3.6, 3, 2.2])
        c, _ = P.shade(h, tint(.92), amb=.45, dif=.6)
        P.put(m, c, line=.4, lw=1, contact=.15)
    # đuôi quạt (3 lá) ở cuối
    (tx, ty), ta = at(1.0)
    tang = ta + math.pi / 2
    for k, off in enumerate([-.55, .55, 0]):
        ang = tang + off
        ex, ey = tx + math.cos(ang) * 34, ty + math.sin(ang) * 34
        m, h = ellipse(ex, ey, 38, 15, ang, hk=.5)
        hh = h + 1.2 * np.cos(((X - ex) * math.sin(ang) - (Y - ey) * math.cos(ang)) / 3.2) * m
        c, _ = P.shade(hh, tint(1.02), amb=.48, dif=.62)
        c = lerpc(c, hexc('#c8603e'), sstep(.6, 1, np.hypot((X - ex) / 38, (Y - ey) / 38)) * .5 * m)
        P.put(m, c, contact=.25)
    # 6 đốt bụng: vẽ từ đuôi lên đầu, đốt trước đè đốt sau
    segs = 6
    for k in reversed(range(segs)):
        t0 = .2 + k * .125; t1 = t0 + .16
        rr0 = 52 - k * 4.2; rr1 = rr0 - 5
        pts = []; rads = []
        for i in range(9):
            t = t0 + (t1 - t0) * i / 8
            (x, y), a = at(t)
            pts.append((x, y)); rads.append(rr0 + (rr1 - rr0) * i / 8)
        m, h, s, sd = tube(pts, rads)
        # mảnh vỏ: mép sau sẫm, giữa sáng; vệt cam ngang đốt
        L = sum(math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]) for i in range(8))
        u = s / L
        base = tint(1.0)
        base = lerpc(base, hexc('#f6d0bc'), sstep(.1, 1, -sd) * .55 * (1 - sstep(.7, 1, -sd)))   # bụng trong mờ
        base = lerpc(base, hexc('#c4573a'), sstep(.62, .92, u) * .55)                             # mép đốt
        base = base * (1 + .05 * noise(1.5, 70 + k))[..., None]
        c, _ = P.shade(h * .9, base, amb=.45, dif=.7, spec=.12, sp_pow=22)
        dots = specks(80 + k, 7, min(p[0] for p in pts) - 40, min(p[1] for p in pts) - 40,
                      max(p[0] for p in pts) + 40, max(p[1] for p in pts) + 40, 1.6, 3, inside=m)
        c = lerpc(c, hexc('#7a3424'), dots * .7)
        P.put(m, c, edge=hexc('#8a3c26'), contact=.3, cblur=5)
    # giáp đầu + chủy răng cưa + mắt
    (x0, y0), a = at(.06)
    (x1, y1), _ = at(.2)
    hx, hy = (x0 + x1) / 2 - 6, (y0 + y1) / 2 + 6
    ang = math.atan2(y1 - y0, x1 - x0)
    # chủy: hướng ra trước-trên
    fx, fy = math.cos(ang + math.pi), math.sin(ang + math.pi)
    tipx, tipy = hx + fx * 118 - 12, hy + fy * 118 - 30
    ros = [(hx + fx * 40, hy + fy * 40 - 20), (tipx, tipy), (hx + fx * 40, hy + fy * 40 - 4)]
    rm = poly_mask(ros)
    for k in range(5):
        tt = .25 + k * .14
        bx = ros[0][0] + (ros[1][0] - ros[0][0]) * tt; by = ros[0][1] + (ros[1][1] - ros[0][1]) * tt
        rm = np.maximum(rm, poly_mask([(bx - 5, by + 1), (bx + 2, by - 10), (bx + 6, by + 2)]))
    m, h = puff(rm, 3, .8)
    c, _ = P.shade(h, tint(.95), amb=.45, dif=.65)
    P.put(m, c, contact=.1)
    m, h = ellipse(hx, hy, 72, 50, ang, hk=.9)
    base = lerpc(tint(1.03), hexc('#f3c8b4'), sstep(.0, 1, (Y - hy) / 50) * .6)
    groove = np.exp(-(((X - hx) * math.sin(ang) - (Y - hy) * math.cos(ang) + 8) / 2.2) ** 2) * m
    base = base * (1 - .22 * groove)[..., None]
    # cơ quan trong (dạ dày sẫm thấy qua vỏ)
    gm, _ = ellipse(hx + 8, hy - 14, 26, 15, ang)
    base = lerpc(base, hexc('#8c4a30'), ndi.gaussian_filter(gm, 5 * PX) * .45)
    c, _ = P.shade(h, base, amb=.45, dif=.72, spec=.14, sp_pow=22)
    P.put(m, c, edge=hexc('#8a3c26'), contact=.3)
    ex, ey = hx + fx * 46, hy + fy * 46 - 4
    m, h = ellipse(ex, ey, 9, 8)
    c, _ = P.shade(h, hexc('#8a4a36'), amb=.5, dif=.5)
    P.put(m, c, line=0)
    m, h = ellipse(ex - 3, ey - 6, 11, 11)
    c, _ = P.shade(h, hexc('#1c1410'), amb=.6, dif=.4, spec=.35, sp_pow=30)
    P.put(m, c, edge=hexc('#0e0a08'))
    return P.save('tep')


# ============================================================ 4. MỒI CHUA (hũ sành mồi ủ chua)
def chua():
    P = Pic()
    cx = 256
    prof = [(150, 92), (166, 96), (205, 124), (250, 146), (300, 150), (350, 138), (400, 118), (430, 104)]
    ys = np.array([p[0] for p in prof], np.float32); ws = np.array([p[1] for p in prof], np.float32)
    w = np.interp(Y, ys, ws)
    w = np.where((Y >= 150) & (Y <= 430), w, 0)
    # đáy hơi bo: thân là mặt xoay (tiện)
    q = np.abs(X - cx) / np.maximum(w, 1e-3)
    bot = 430 - 8 * np.sqrt(np.clip(1 - q * q, 0, 1))
    m = aa((q - 1) * 40) * aa(150 - Y) * aa(Y - bot)
    h = w * np.sqrt(np.clip(1 - q * q, 0, 1)) * .9
    clay = hexc('#b8653a'); dark = hexc('#7e3b21')
    base = lerpc(clay, dark, sstep(330, 430, Y) * .55)
    base = base * (1 + .08 * noise(1.2, 41) + .025 * noise(6, 42))[..., None]          # đất nung lấm tấm
    # 2 đường vạch quanh vai (cong theo mặt xoay, nhìn hơi từ trên xuống)
    for y0 in (214, 230):
        yr = y0 + 9 * np.sqrt(np.clip(1 - q * q, 0, 1))
        g = np.exp(-((Y - yr) / 1.6) ** 2) * m
        h = h - 1.8 * g
        base = base * (1 - .3 * g)[..., None]
    # men nâu chảy từ vai xuống (vệt)
    gl = sstep(-.1, .4, noise(9, 43)) * (1 - sstep(240, 330, Y)) * sstep(160, 200, Y)
    base = lerpc(base, hexc('#6d3b1d'), gl * .3)
    c, _ = P.shade(h, base, amb=.4, dif=.75, spec=.05)
    P.put(m, c, contact=0)
    # vành miệng: vòng dày
    mm, mh = ellipse(cx, 150, 104, 28)
    im_, _ = ellipse(cx, 148, 84, 19)
    ringm = np.clip(mm - im_, 0, 1)
    rh = np.clip(mh - 8, 0, None) * 1.6
    c, _ = P.shade(rh, lerpc(clay, hexc('#d08458'), .35), amb=.42, dif=.75)
    P.put(ringm, c, contact=.2)
    # mồi chua trong miệng hũ: đống lổn nhổn vàng nâu nhô lên khỏi vành
    pm, ph = ellipse(cx, 140, 86, 44)
    pm = pm * aa(Y - 158)
    lump = np.zeros((N, N), np.float32)
    rs = np.random.RandomState(9)
    for i in range(46):
        x = cx + rs.uniform(-78, 78); y = rs.uniform(112, 158)
        e, eh = ellipse(x, y, rs.uniform(7, 15), rs.uniform(5, 10), rs.uniform(0, 3))
        lump = np.maximum(lump, eh)
    ph = ph * .8 + lump * .9
    base = lerpc(hexc('#c79a48'), hexc('#8c6a2a'), sstep(-.2, .6, noise(2, 44)))
    base = lerpc(base, hexc('#e3c77a'), specks(45, 40, cx - 80, 100, cx + 80, 160, 1.5, 3.2, inside=pm) * .9)
    c, _ = P.shade(ph, base, amb=.45, dif=.7, spec=.08, sp_pow=16)
    P.put(pm * (1 - im_ * 0) , c, contact=.3)
    # bốc mùi: 3 làn hơi mảnh xanh xám, mờ dần lên trên
    for k, x0 in enumerate([206, 256, 306]):
        pts = [(x0 + 10 * math.sin(i / 6 + k), 100 - i * 3.2) for i in range(26)]
        m, hh, s, _ = tube(pts, [4.2 - 2.4 * i / 25 for i in range(26)])
        fade = 1 - sstep(10, 80, s)
        c, _ = P.shade(hh, hexc('#8fae66'), amb=.6, dif=.5)
        P.put(m * (.85 * fade + .15) * .9, c, line=.25, contact=0)
    return P.save('chua')


# ============================================================ 5. NHÁI CON (ngồi, nhìn thẳng)
def nhai():
    P = Pic()
    g_back = hexc('#5f9e34'); g_dark = hexc('#3a6d22'); g_lite = hexc('#9cc957'); belly = hexc('#e9e2a6')
    def skin(h, m, base, seed, spots=True):
        b = base * (1 + .07 * noise(2, seed))[..., None]
        if spots:
            s = sstep(.35, .55, noise(10, seed + 1, 2)) * m
            b = lerpc(b, g_dark, s * .75)
        c, _ = P.shade(h, b, amb=.42, dif=.72, spec=.1, sp_pow=20)
        return c
    # chân sau gập 2 bên (sau thân)
    for sx in (-1, 1):
        m, h = ellipse(256 + sx * 128, 352, 74, 52, sx * -.35, hk=.9)
        P.put(m, skin(h, m, g_back, 10 + sx), contact=0)
        # bàn chân sau xoè ngón trên đất
        fx = 256 + sx * 150
        for k in range(4):
            ang = math.radians(90 + sx * (-10 - k * 22))
            p1 = (fx + sx * 4, 412); p2 = (fx + math.cos(ang) * 46 * sx * -1 + sx * 10, 412 + math.sin(ang) * 22 + 10)
            m, h, _, _ = tube([p1, p2], [8, 5.5])
            P.put(m, skin(h, m, g_lite, 20 + k, False), contact=.2)
            m, h = ellipse(p2[0], p2[1], 7.5, 6.5)
            P.put(m, skin(h, m, hexc('#b3d670'), 30 + k, False), contact=.1)
    # thân
    m, h = ellipse(256, 300, 140, 108, hk=.85)
    b = lerpc(g_back, g_lite, sstep(-1, 1, (X - 256) / 140) * 0)
    # bụng vàng kem lộ ở giữa dưới
    bm, _ = ellipse(256, 338, 82, 66)
    bm = ndi.gaussian_filter(bm, 6 * PX)
    c = skin(h, m, g_back, 40)
    cb, _ = P.shade(h, belly * (1 + .05 * noise(1.5, 41))[..., None], amb=.5, dif=.6)
    c = lerpc(c, cb, bm)
    P.put(m, c, contact=.3)
    # tay trước
    for sx in (-1, 1):
        x0 = 256 + sx * 56
        m, h, _, _ = tube([(x0 + sx * 10, 330), (x0 + sx * 2, 380), (x0 - sx * 4, 412)], [17, 13, 11])
        P.put(m, skin(h, m, g_back, 50 + sx, False), contact=.35)
        for k in range(3):
            ang = math.radians(90 + (k - 1) * 34)
            p2 = (x0 - sx * 4 + math.cos(ang) * 22 * (1 if k != 1 else 0) * (k - 1), 418 + math.sin(ang) * 6)
            m, h, _, _ = tube([(x0 - sx * 4, 410), p2], [6, 4.5])
            P.put(m, skin(h, m, g_lite, 60 + k, False), contact=.15)
            m, h = ellipse(p2[0], p2[1], 6.5, 5.5)
            P.put(m, skin(h, m, hexc('#b3d670'), 70 + k, False), contact=.1)
    # đầu rộng
    m, h = ellipse(256, 214, 138, 84, hk=.8)
    c = skin(h, m, g_back, 80)
    # sọc sáng 2 bên lưng + họng sáng
    th, _ = ellipse(256, 268, 92, 26)
    c = lerpc(c, lerpc(c, belly, .7), ndi.gaussian_filter(th, 4 * PX) * .8)
    # miệng: đường cong rộng
    my = 248 + 14 * (1 - ((X - 256) / 120) ** 2)
    mouth = np.exp(-((Y - my) / 1.5) ** 2) * (np.abs(X - 256) < 118) * m
    c = c * (1 - .55 * mouth)[..., None]
    for sx in (-1, 1):
        nm, _ = ellipse(256 + sx * 20, 196, 4, 3)
        c = c * (1 - .6 * nm)[..., None]
    P.put(m, c, contact=.3)
    # mắt lồi
    for sx in (-1, 1):
        ex, ey = 256 + sx * 82, 150
        m, h = ellipse(ex, ey + 6, 50, 46, hk=.9)
        P.put(m, skin(h, m, g_back, 90 + sx, False), contact=.3)
        m, h = ellipse(ex + sx * 2, ey, 37, 35)
        d = np.hypot(X - ex - sx * 2, Y - ey) / 37
        iris = lerpc(hexc('#e8c45a'), hexc('#9a6a24'), sstep(.45, 1, d))
        iris = iris * (1 + .12 * noise(.8, 95 + sx))[..., None]
        pm, _ = ellipse(ex + sx * 2, ey + 1, 17, 7.5)
        iris = lerpc(iris, hexc('#120c08'), pm)
        c, _ = P.shade(h, iris, amb=.55, dif=.55, spec=.3, sp_pow=34)
        P.put(m, c, edge=hexc('#2a2410'), line=.8, lw=1.6)
        lid = np.exp(-(((np.hypot(X - ex - sx * 2, (Y - ey + 3) * 1.1) - 38) / 2.5) ** 2)) * (Y < ey - 6)
        P.paint(hexc('#3a6d22'), lid * .0)
    return P.save('nhai')


# ============================================================ 6. TRÁI SUNG CHÍN (chùm 3 trái + lá)
def sung():
    P = Pic()
    # lá sung phía sau
    lp = bez((248, 74), (170, 20), (60, 70), (96, 186), 40) + bez((96, 186), (140, 236), (220, 190), (248, 74), 40)[1:]
    lm = poly_mask(lp)
    m, h = puff(lm, 12, .5)
    ang = math.atan2(186 - 74, 96 - 248)
    u = (X - 248) * math.cos(ang) + (Y - 74) * math.sin(ang)
    v = -(X - 248) * math.sin(ang) + (Y - 74) * math.cos(ang)
    mid = np.exp(-(v / 2.2) ** 2)
    side = np.exp(-(((np.abs(v) - (u * .38 % 22) * 0) - np.abs(v)) ** 2))
    veins = np.exp(-((((u - np.abs(v) * .8) % 26) - 13) / 1.8) ** 2) * (np.abs(v) > 3)
    base = lerpc(hexc('#3f7f2e'), hexc('#5c9c3c'), sstep(-60, 60, v))
    base = lerpc(base, hexc('#a9cf78'), (mid + veins * .6) * .7)
    h = h + 1.5 * mid - 1.0 * veins
    c, _ = P.shade(h, base, amb=.45, dif=.7, spec=.05)
    P.put(m, c, contact=0)
    # cành nhỏ
    m, h, _, _ = tube([(300, 70), (268, 112), (236, 150), (210, 182)], [11, 10, 9, 8])
    c, _ = P.shade(h, hexc('#7a5a3a') * (1 + .12 * noise(1.5, 3))[..., None], amb=.42, dif=.7)
    P.put(m, c, contact=.3)
    figs = [(176, 278, 92, 12), (338, 238, 84, 14), (262, 336, 108, 16)]     # sau -> trước
    stems = {0: (214, 176), 1: (262, 128), 2: (238, 162)}
    for i, (fx, fy, r, seed) in enumerate(figs):
        sx, sy = stems[i]
        m, h, _, _ = tube([(sx, sy), ((sx + fx) / 2, (sy + fy - r) / 2 + 6), (fx, fy - r * .82)], [6.5, 6, 8])
        c, _ = P.shade(h, hexc('#8a8a3e'), amb=.42, dif=.7)
        P.put(m, c, contact=.25)
        # trái: hơi hình lê (đầu cuống thon)
        dy = (Y - fy) / r
        k = 1 - .14 * sstep(-1, -.2, dy)
        q = np.sqrt(((X - fx) / (r * k)) ** 2 + dy ** 2)
        m = aa((q - 1) * r)
        z = np.sqrt(np.clip(1 - q * q, 0, 1)) * r * .95
        # gờ dọc mờ từ cuống xuống
        ang = np.arctan2(X - fx, -(Y - fy + r * 1.1))
        z = z * (1 + .025 * np.cos(ang * 14))
        t = sstep(-.95, .9, dy)
        base = lerpc(hexc('#b7ac4a'), hexc('#e0682e'), sstep(-1, -.45, dy))      # gần cuống vàng xanh
        base = lerpc(base, hexc('#c13a26'), sstep(-.3, .9, dy) * .9)
        base = lerpc(base, hexc('#8e2418'), sstep(.6, 1.1, q) * .4)
        base = base * (1 + .06 * noise(3, seed))[..., None]
        dots = specks(seed + 100, 120, fx - r, fy - r, fx + r, fy + r, 1.4, 3.2, inside=m)
        base = lerpc(base, hexc('#f3c79a'), dots * .75)
        c, _ = P.shade(z, base, amb=.42, dif=.74, spec=.08, sp_pow=18)
        # rốn trái (lỗ ở đáy, hơi hướng ra trước)
        nm, nh = ellipse(fx + r * .08, fy + r * .62, r * .1, r * .07)
        c = lerpc(c, hexc('#5a1a10'), nm * .75)
        P.put(m, c, edge=hexc('#6e1c12'), contact=.42, cblur=8)
    return P.save('sung')


# ============================================================ 7. CÁM RÊU THƠM (nắm rêu trộn cám, xiên que tre)
def cam():
    P = Pic()
    # que tre xiên qua, ló ra dưới-phải
    m, h, s, sd = tube([(196, 186), (330, 330), (452, 456)], [12, 12, 11])
    grain = np.exp(-((sd * 3.5 % 1 - .5) / .12) ** 2) * .15
    base = lerpc(hexc('#c9a265'), hexc('#a07a44'), sstep(-1, 1, sd)) * (1 - grain)[..., None]
    c, _ = P.shade(h, base, amb=.42, dif=.72)
    P.put(m, c, contact=0)
    # nắm rêu: bờ lởm chởm theo nhiễu, mặt đầy cụm rêu nhỏ
    cx, cy, R = 238, 236, 150
    ang = np.arctan2(Y - cy, X - cx)
    rr = np.hypot(X - cx, Y - cy)
    edge = R * (1 + .02 * np.sin(ang * 7 + 1) + .015 * np.sin(ang * 13 + 2) + .02 * noise(4, 5))
    q = rr / edge
    m = aa((q - 1) * R)
    z = np.sqrt(np.clip(1 - q * q, 0, 1)) * R * .9
    # cụm rêu: nhiều chỏm tròn nhỏ
    rs = np.random.RandomState(17)
    tuft = np.zeros((N, N), np.float32); tid = np.zeros((N, N), np.float32)
    for i in range(620):
        a = rs.uniform(0, 2 * math.pi); r0 = R * math.sqrt(rs.uniform(0, 1.05))
        x = cx + math.cos(a) * r0; y = cy + math.sin(a) * r0
        rad = rs.uniform(8, 14) * (1 - .4 * (r0 / R) ** 2)
        e, eh = ellipse(x, y, rad, rad * rs.uniform(.8, 1))
        sel = eh > tuft
        tuft = np.where(sel, eh, tuft); tid = np.where(sel, rs.uniform(0, 1), tid)
    fine = noise(.6, 18, 2)
    z = z + tuft * .3 + fine * 1.4
    crev = 1 - sstep(.5, 4, tuft)                                      # khe giữa cụm tối
    g = lerpc(hexc('#4f8229'), hexc('#8fbb4a'), tid * .5 + sstep(3, 11, tuft) * .4)
    g = lerpc(g, hexc('#9c8650'), sstep(.1, .5, noise(5, 23)) * .55)     # mảng cám trộn
    g = lerpc(g, hexc('#a6c95c'), sstep(.25, .7, fine) * .5)          # ngọn rêu sáng
    g = lerpc(g, hexc('#2e5219'), crev * .4)
    # cám vàng nâu rắc trên mặt
    br = specks(19, 300, cx - R, cy - R, cx + R, cy + R, 1.8, 4.6, inside=m)
    g = lerpc(g, hexc('#e8d391'), br * .85)
    br2 = specks(20, 120, cx - R, cy - R, cx + R, cy + R, 1.2, 2.4, inside=m)
    g = lerpc(g, hexc('#7a5a30'), br2 * .7)
    c, _ = P.shade(z, g, amb=.42, dif=.75, spec=.03, ao=crev * .15)
    P.put(m, c, edge=hexc('#24401a'), contact=.45, cblur=9)
    # đầu que ló ra trên-trái (que xuyên qua nắm)
    m, h, s, sd = tube([(150, 140), (176, 166)], [11, 12])
    base = lerpc(hexc('#c9a265'), hexc('#a07a44'), sstep(-1, 1, sd))
    c, _ = P.shade(h, base, amb=.42, dif=.72)
    cut, ch = ellipse(150, 140, 10, 10)
    c = lerpc(c, hexc('#e2c48a'), cut * .8)
    P.put(m, c, contact=.2)
    return P.save('cam')


if __name__ == '__main__':
    for k in IDS:
        globals()[k]()
