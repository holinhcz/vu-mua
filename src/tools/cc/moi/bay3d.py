#!/usr/bin/env python3
# LỜ / LỌP / GIĂNG CÂU CẤP 1 dựng KHỐI 3D THẬT (11-24 Link "xấu vler, góc nhìn 3D đâu" -> "dựng 3D lên vẽ đi, 6px thôi").
# Bỏ bản vẽ dẹt ve_bay.py. Ở đây mỗi món là các khối SDF (ống đan, vòng mây, cọc tre có đốt, dây, lưỡi, phao) trong
# toạ độ thế giới của làng (đơn vị làng, z lên trời, mặt nước z = 0), chiếu vuông góc góc nhìn vườn:
# xoay 45 độ, nghiêng 30 độ (ô 32 x 16). Bắn tia từng điểm ảnh -> pháp tuyến thật, bóng đổ mềm, che sáng (AO),
# sáng trên-trái, viền mảnh màu tối của chỗ đó (như cá câu). Ra 6 px / đơn vị (vẽ gấp 4 rồi thu).
#   <id>.webp  : nguyên món (ô / bảng)     <id>_w.webp : đặt trên nước (phần dưới mặt nước mờ, ngả màu nước)
#   meta.json  : chỗ đặt chân (điểm (0,0,0) = giữa món ngay mặt nước) theo điểm ảnh của ảnh ra
#   python3 bay3d.py OUTDIR [lo lop giang]     (env PXU = điểm ảnh / đơn vị, mặc định 6; SSA = vẽ gấp, mặc định 4)
import os, sys, math, json
import numpy as np
from scipy import ndimage as ndi
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/bay3d'
IDS = sys.argv[2:] or ['lo', 'lop', 'giang']
PXU = float(os.environ.get('PXU', '6'))
SSA = int(os.environ.get('SSA', '4'))
F32 = np.float32


def V(*a):
    return np.array(a, F32)


def nz(v):
    return v / np.linalg.norm(v)


# ------------------------------------------------------------ camera: góc nhìn vườn (xoay 45, nghiêng 30)
AZ = math.radians(45); EL = math.radians(30)
FWD = nz(V(-math.cos(EL) * math.cos(AZ), -math.cos(EL) * math.sin(AZ), -math.sin(EL)))   # camera nhìn theo hướng này
RT = nz(np.cross(FWD, V(0, 0, 1)))
UP = np.cross(RT, FWD)
LIGHT = nz(-.62 * RT + .55 * UP - .35 * FWD + V(0, 0, .35))     # sáng trên-trái màn hình, từ phía camera


def hexc(h):
    h = h.lstrip('#')
    return V(*[int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def hsh(x):   # băm ra 0..1 cho từng số nguyên (mỗi nan một tông)
    return (np.sin(x * 12.9898 + 78.233) * 43758.5453) % 1.0


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def vnoise(p, sc, seed=0):
    """value noise 3D mượt (đủ cho vân tre, rêu)"""
    q = p / sc + seed * 17.3
    i = np.floor(q); f = q - i
    f = f * f * (3 - 2 * f)
    def h(dx, dy, dz):
        n = (i[:, 0] + dx) * 157 + (i[:, 1] + dy) * 113 + (i[:, 2] + dz) * 271
        return hsh(n)
    x00 = h(0, 0, 0) * (1 - f[:, 0]) + h(1, 0, 0) * f[:, 0]
    x10 = h(0, 1, 0) * (1 - f[:, 0]) + h(1, 1, 0) * f[:, 0]
    x01 = h(0, 0, 1) * (1 - f[:, 0]) + h(1, 0, 1) * f[:, 0]
    x11 = h(0, 1, 1) * (1 - f[:, 0]) + h(1, 1, 1) * f[:, 0]
    y0 = x00 * (1 - f[:, 1]) + x10 * f[:, 1]
    y1 = x01 * (1 - f[:, 1]) + x11 * f[:, 1]
    return y0 * (1 - f[:, 2]) + y1 * f[:, 2]


def frame(ax):
    a = nz(ax)
    t = V(0, 0, 1) if abs(a[2]) < .9 else V(1, 0, 0)
    e1 = nz(np.cross(a, t)); e2 = np.cross(a, e1)
    return a, e1, e2


# ------------------------------------------------------------ khối SDF (P: (n,3)) -> khoảng cách + toạ độ để tô vân
class Tube:
    """ống trục thẳng A -> A+ax*L, bán kính r(s) theo bảng; shell = độ dày vỏ (đan) hay 0 (đặc);
    open0/open1: hở đầu; wv = (số nan, biên độ) -> nan dọc nổi trên mặt"""
    def __init__(s, A, ax, L, prof, mat, shell=0.0, open0=False, open1=False, wv=None, rings=()):
        s.A = V(*A); s.ax, s.e1, s.e2 = frame(V(*ax)); s.L = L
        s.ps = np.array([p[0] for p in prof], F32) * L; s.pr = np.array([p[1] for p in prof], F32)
        s.mat = mat; s.shell = shell; s.o0 = open0; s.o1 = open1; s.wv = wv
        s.bound = (s.A + s.ax * L / 2, L / 2 + float(s.pr.max()) + 2)

    def local(s, P):
        d = P - s.A
        z = d @ s.ax
        x = d @ s.e1; y = d @ s.e2
        return z, np.hypot(x, y), np.arctan2(y, x)

    def sdf(s, P):
        z, q, th = s.local(P)
        r = np.interp(np.clip(z, 0, s.L), s.ps, s.pr)
        if s.wv is not None:
            n, amp = s.wv
            f = (th / (2 * np.pi) * n) % 1.0
            sl = np.sqrt(np.clip(1 - ((f - .5) / .42) ** 2, 0, 1))
            r = r + amp * (sl - .55)
        dr = q - r
        if s.shell:
            dr = np.abs(dr + s.shell * .5) - s.shell * .5
        lo = -z if not s.o0 else np.full_like(z, -1e9)
        hi = z - s.L if not s.o1 else np.full_like(z, -1e9)
        if s.shell:
            dz = np.maximum(-z, z - s.L)     # cắt phẳng 2 đầu (đầu kín thì có nắp riêng)
            d = np.maximum(dr, dz)
            if not s.o0:
                cap = np.maximum(q - r, np.abs(z - s.shell * .5) - s.shell * .5)
                d = np.minimum(d, cap)
            if not s.o1:
                cap = np.maximum(q - r, np.abs(z - s.L + s.shell * .5) - s.shell * .5)
                d = np.minimum(d, cap)
            return d * .7
        dz = np.maximum(lo, hi)
        o = np.hypot(np.maximum(dr, 0), np.maximum(dz, 0)) + np.minimum(np.maximum(dr, dz), 0)
        return o * .7


class Torus:
    def __init__(s, C, ax, R, r, mat):
        s.C = V(*C); s.ax, s.e1, s.e2 = frame(V(*ax)); s.R = R; s.r = r; s.mat = mat
        s.bound = (s.C, R + r + 1)

    def local(s, P):
        d = P - s.C
        z = d @ s.ax; x = d @ s.e1; y = d @ s.e2
        return z, np.hypot(x, y), np.arctan2(y, x)

    def sdf(s, P):
        z, q, th = s.local(P)
        return np.hypot(q - s.R, z) - s.r


class Line:
    """dây / cọc / lưỡi: chuỗi đoạn bo tròn, bán kính r(k) từng điểm"""
    def __init__(s, pts, r, mat, nodes=None, cut_top=None):
        s.P = np.array(pts, F32); s.r = np.broadcast_to(np.array(r, F32), (len(pts),)).copy(); s.mat = mat
        s.nodes = nodes; s.cut = cut_top
        lo = s.P.min(0); hi = s.P.max(0)
        s.bound = ((lo + hi) / 2, float(np.linalg.norm(hi - lo)) / 2 + float(s.r.max()) + 1)
        s.cum = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(s.P, axis=0), axis=1))]).astype(F32)

    def seg(s, P):
        best = np.full(len(P), 1e9, F32); sl = np.zeros(len(P), F32); side = np.zeros((len(P), 3), F32)
        for i in range(len(s.P) - 1):
            a, b = s.P[i], s.P[i + 1]; ab = b - a; L2 = float(ab @ ab) + 1e-9
            t = np.clip(((P - a) @ ab) / L2, 0, 1)
            c = a + t[:, None] * ab
            r = s.r[i] + (s.r[i + 1] - s.r[i]) * t
            d = np.linalg.norm(P - c, axis=1) - r
            ok = d < best
            best = np.where(ok, d, best); sl = np.where(ok, s.cum[i] + t * (s.cum[i + 1] - s.cum[i]), sl)
        return best, sl

    def sdf(s, P):
        d, sl = s.seg(P)
        if s.nodes:   # đốt tre: gờ nổi
            n = s.nodes
            g = np.exp(-(((sl % n) - n / 2) / .18) ** 2)
            d = d - g * .14
        if s.cut is not None:   # đầu cọc vạt xéo
            c, nrm = s.cut
            d = np.maximum(d, (P - V(*c)) @ nz(V(*nrm)))
        return d


class Ball:
    def __init__(s, C, R, mat, sq=(1, 1, 1)):
        s.C = V(*C); s.R = R; s.mat = mat; s.sq = V(*sq); s.bound = (s.C, R * float(max(sq)) + 1)

    def sdf(s, P):
        q = (P - s.C) / s.sq
        return (np.linalg.norm(q, axis=1) - s.R) * float(min(s.sq))


# ------------------------------------------------------------ tô màu theo chất liệu
TRE = hexc('#cfae72'); TRE_D = hexc('#8f6c3c'); TRE_L = hexc('#e8d3a4')
MAY = hexc('#7a5230'); COC = hexc('#d8c886'); COC_D = hexc('#9a8a4c')
TOI = hexc('#2e2214')


def albedo(obj, P):
    m = obj.mat
    n = len(P)
    if m in ('dan', 'hom'):
        z, q, th = obj.local(P)
        N_ = obj.wv[0] if obj.wv else 30
        u = th / (2 * np.pi) * N_
        k = np.floor(u); f = u % 1.0
        gap = sstep(.38, .48, np.abs(f - .5))
        tone = (hsh(k + (3 if m == 'hom' else 0)) - .5) * .2
        c = TRE[None] * (1 + tone + .1 * (vnoise(P, 2.5, 1) - .5))[:, None]
        c = c * (1 - .07 * np.sin(z * 9 + k))[:, None]                          # xơ dọc nan
        c = c * (1 - .35 * sstep(.55, .85, vnoise(P, 1.6, 2)) * .5)[:, None]   # lốm đốm cũ
        c = c * (1 - gap * .55)[:, None] + TOI[None] * (gap * .55)[:, None]
        if m == 'hom':
            c = c * .9
        return c
    if m == 'may' and not isinstance(obj, Torus):
        return MAY[None] * (.85 + .3 * vnoise(P, .5, 9))[:, None]
    if m == 'may':
        z, q, th = obj.local(P)
        tw = .5 + .5 * np.sin(th * 26 + np.arctan2(z, q - obj.R) * 2)        # mây quấn xoắn
        return MAY[None] * (.85 + .25 * tw)[:, None]
    if m == 'coc':
        _, sl = obj.seg(P)
        n_ = obj.nodes or 6
        nd = np.exp(-(((sl % n_) - n_ / 2) / .25) ** 2)
        c = COC[None] * (1 + .12 * (vnoise(P * V(3, 3, .25), 1, 4) - .5))[:, None]
        c = c + (COC_D - COC)[None] * (nd * .6 + .3 * sstep(.6, .9, vnoise(P, 3, 5)))[:, None]
        top = (P[:, 2] > obj.P[:, 2].max() - .6)
        return np.where(top[:, None], hexc('#e3d29c')[None], c)
    if m == 'day':
        return np.broadcast_to(hexc('#e9e3d0'), (n, 3)).copy()
    if m == 'thep':
        return np.broadcast_to(hexc('#9aa3aa'), (n, 3)).copy()
    if m == 'moi':
        return np.broadcast_to(hexc('#e0b49c'), (n, 3)).copy()
    if m == 'phao':
        _, sl = obj.seg(P)
        L = obj.cum[-1]
        c = np.where((sl > L * .72)[:, None], hexc('#c8342a')[None], hexc('#d8c27c')[None])
        nd = np.exp(-((sl - L * .4) / .12) ** 2)
        return c * (1 - .35 * nd)[:, None]
    if m == 'be':   # nùi bẹ chuối khô
        _, sl = obj.seg(P)
        v = vnoise(P * V(4, 4, 4), 1, 7)
        c = hexc('#a88b55')[None] + (hexc('#6e5634') - hexc('#a88b55'))[None] * sstep(.35, .8, v)[:, None]
        return c * (1 - .12 * np.sin(sl * 14 + v * 6))[:, None]
    if m == 'toi':
        return np.broadcast_to(TOI * .7, (n, 3)).copy()
    return np.broadcast_to(V(.8, .8, .8), (n, 3)).copy()


# ------------------------------------------------------------ bắn tia
class Scene:
    def __init__(s, objs):
        s.objs = objs

    def sdf(s, P, ids=False):
        D = np.stack([o.sdf(P) for o in s.objs], 1)
        if ids:
            return D.min(1), D.argmin(1)
        return D.min(1)

    def normal(s, P, e=.02):
        dx = V(e, 0, 0); dy = V(0, e, 0); dz = V(0, 0, e)
        n = np.stack([s.sdf(P + dx) - s.sdf(P - dx), s.sdf(P + dy) - s.sdf(P - dy), s.sdf(P + dz) - s.sdf(P - dz)], 1)
        return n / (np.linalg.norm(n, axis=1, keepdims=True) + 1e-9)

    def bbox(s):
        pts = []
        for o in s.objs:
            c, r = o.bound
            for sx in (-1, 1):
                for sy in (-1, 1):
                    for sz in (-1, 1):
                        pts.append(c + V(sx, sy, sz) * r * .75)
        return np.array(pts, F32)


def render(scene, name, water=True):
    ppu = PXU * SSA
    B = scene.bbox()
    sx = B @ RT; sy = B @ UP
    x0, x1 = sx.min() - 1, sx.max() + 1; y0, y1 = sy.min() - 1, sy.max() + 1
    W = int((x1 - x0) * ppu); H = int((y1 - y0) * ppu)
    xs = x0 + (np.arange(W) + .5) / ppu; ys = y1 - (np.arange(H) + .5) / ppu
    GX, GY = np.meshgrid(xs, ys)
    O = GX.reshape(-1, 1) * RT + GY.reshape(-1, 1) * UP - FWD * 200
    n = len(O)
    t = np.full(n, 150, F32); hit = np.zeros(n, bool); act = np.arange(n)
    for it in range(260):
        P = O[act] + FWD * t[act, None]
        d = scene.sdf(P)
        t[act] += d
        h = d < .004
        hit[act[h]] = True
        keep = (~h) & (t[act] < 260)
        act = act[keep]
        if len(act) == 0:
            break
    idx = np.nonzero(hit)[0]
    P = O[idx] + FWD * t[idx, None]
    _, oid = scene.sdf(P, ids=True)
    N = scene.normal(P)
    # bóng đổ mềm về phía đèn
    sh = np.ones(len(P), F32); tt = np.full(len(P), .08, F32)
    Q0 = P + N * .03
    for it in range(48):
        d = scene.sdf(Q0 + LIGHT * tt[:, None])
        sh = np.minimum(sh, np.clip(9 * d / tt, 0, 1))
        tt += np.clip(d, .04, .8)
    sh = np.clip(sh, 0, 1)
    # che sáng (AO)
    ao = np.zeros(len(P), F32)
    for k in range(1, 6):
        dk = k * .18
        ao += (dk - scene.sdf(P + N * dk)) / (2 ** k)
    ao = np.clip(1 - ao * 2.2, 0, 1)
    alb = np.zeros((len(P), 3), F32)
    for i, o in enumerate(scene.objs):
        m = oid == i
        if m.any():
            alb[m] = albedo(o, P[m])
    # mặt trong ống đan (pháp tuyến quay vô trục): lòng tối
    inner = np.zeros(len(P), F32)
    for i, o in enumerate(scene.objs):
        if isinstance(o, Tube) and o.shell:
            m = oid == i
            if m.any():
                d = P[m] - o.A
                rad = d - (d @ o.ax)[:, None] * o.ax
                rad /= np.linalg.norm(rad, axis=1, keepdims=True) + 1e-6
                inner[m] = sstep(.0, .4, -(N[m] * rad).sum(1))
    lam = np.clip(N @ LIGHT, 0, 1)
    H_ = nz(LIGHT - FWD)
    spec = np.clip(N @ H_, 0, 1) ** 24 * .1
    sky = .5 + .5 * N[:, 2]
    lum = (.34 + .16 * sky) * ao + .78 * lam * sh * (.55 + .45 * ao)
    lum = lum * (1 - .66 * inner)
    col = alb * lum[:, None] + spec[:, None] * sh[:, None] * (1 - inner)[:, None]
    col = np.clip(col, 0, 1)
    rgb = np.zeros((n, 3), F32); a = np.zeros(n, F32); z = np.zeros(n, F32); dep = np.full(n, 1e3, F32)
    rgb[idx] = col; a[idx] = 1; z[idx] = P[:, 2]; dep[idx] = t[idx]
    oidm = np.full(n, -1); oidm[idx] = oid
    rgb = rgb.reshape(H, W, 3); a = a.reshape(H, W); z = z.reshape(H, W); dep = dep.reshape(H, W); oidm = oidm.reshape(H, W)
    # nét mảnh trong: chỗ sâu nhảy (khối này đè khối kia)
    # chỉ tô bên khối nằm XA hơn (như bóng tiếp xúc), dây mảnh phía trước giữ màu
    gd = np.zeros_like(dep)
    for sh_ in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
        nb = np.roll(dep, sh_, (0, 1))
        gd = np.maximum(gd, dep - nb)
    ln = (gd > .6) & (a > 0)
    ln = ndi.binary_dilation(ln, iterations=max(1, SSA // 3))
    rgb = np.where(ln[..., None], rgb * .55, rgb)
    outs = []
    for wv in ([False, True] if water else [False]):
        r2 = rgb.copy(); a2 = a.copy()
        if wv:
            under = np.clip(-z, 0, None) * (a > 0)
            k = 1 - np.exp(-under / 1.0)
            wc = hexc('#365f5c')
            r2 = r2 * (1 - k[..., None] * .75) + wc * (k[..., None] * .75)
            a2 = a2 * (1 - .62 * k)
            wl = (np.abs(z) < .12) & (a > 0)
            r2 = np.where(wl[..., None], r2 * .5 + .5 * hexc('#eef5f1'), r2)
        im = outline(r2, a2, a2)   # viền theo độ hiện: phần chìm viền mờ theo
        sm = im.resize((max(1, W // SSA), max(1, H // SSA)), Image.LANCZOS)
        outs.append(sm)
    # cắt sát (cùng 1 khung cho 2 bản), chỗ đặt chân: điểm (0,0,0)
    bb = outs[0].getchannel('A').point(lambda v: 255 if v > 2 else 0).getbbox()
    bb = (max(0, bb[0] - 2), max(0, bb[1] - 2), min(outs[0].width, bb[2] + 2), min(outs[0].height, bb[3] + 2))
    outs = [o.crop(bb) for o in outs]
    ax_ = (0 - x0) * PXU - bb[0]; ay_ = (y1 - 0) * PXU - bb[1]
    return outs, (round(float(ax_), 2), round(float(ay_), 2))


def outline(rgb, a, a_full):
    """viền ngoài mảnh màu tối của chỗ sát mép (như cá câu)"""
    w = int(SSA * 1.0) | 1
    dil = ndi.grey_dilation(a_full, size=(w * 2 + 1, w * 2 + 1)).astype(F32)
    dil = ndi.gaussian_filter(dil, SSA * .35)
    ring = np.clip(dil - a_full, 0, 1)
    num = ndi.gaussian_filter(rgb * a_full[..., None], (SSA * 2, SSA * 2, 0))
    den = ndi.gaussian_filter(a_full, SSA * 2)[..., None] + 1e-4
    ec = np.clip(num / den * .42, 0, 1)
    al = np.clip(a + ring * (a_full.max() and 1), 0, 1)
    al = np.maximum(a, ring * .95)
    out = rgb * a[..., None] + ec * (ring * .95)[..., None] * (1 - a[..., None])
    out = out / np.maximum(al[..., None], 1e-4)
    return Image.fromarray(np.dstack([np.clip(out, 0, 1) * 255, np.clip(al, 0, 1) * 255]).astype(np.uint8), 'RGBA')


# ============================================================ các món (đơn vị làng: 1 ô = cạnh ~22.6)
def stake(x, y, z0, z1, r, nodes=5.5, lean=(0, 0)):
    top = (x + lean[0], y + lean[1], z1)
    return Line([(x, y, z0), top], [r, r * .95], 'coc', nodes=nodes,
                cut_top=((top[0], top[1], z1 - .3), (.5, .2, 1)))


def ties(C, ax, R, n=3, gap=.34, r=.17):
    a = nz(V(*ax))
    return [Torus(V(*C) + a * (i - (n - 1) / 2) * gap, ax, R, r, 'may') for i in range(n)]


def lo():
    # lờ nằm ngang mặt nước (camera ở phía +x +y: hướng 135 độ = phải màn hình, 315 = trái)
    ax = nz(V(math.cos(math.radians(342)), math.sin(math.radians(342)), 0))   # từ đuôi về miệng: miệng chĩa trái màn hình, hơi về phía người xem
    L = 19.0
    tail = -ax * L * .5 + V(0, 0, .4)
    A = tail + ax * L                      # miệng
    dirm = -ax                             # trục từ miệng vô đuôi
    prof = [(0, 4.2), (.08, 4.45), (.32, 4.9), (.58, 4.5), (.8, 3.1), (.94, 1.7), (1, 1.3)]
    body = Tube(A, dirm, L, prof, 'dan', shell=.32, open0=True, open1=True, wv=(46, .09))
    hom = Tube(A + dirm * .05, dirm, 6.5, [(0, 4.0), (.75, 1.25), (1, 1.0)], 'hom', shell=.22, open0=True, open1=True, wv=(26, .08))
    objs = [body, hom]
    # đai mây: vòng quanh thân theo bảng bán kính
    ps = np.array([p[0] for p in prof]) * L; pr = np.array([p[1] for p in prof])
    for s_ in [.25, 3.2, 6.4, 9.6, 12.6, 15.2]:
        R = float(np.interp(s_, ps, pr)) + .06
        objs.append(Torus(A + dirm * s_, dirm, R, .17, 'may'))
    objs.append(Torus(A + dirm * .1, dirm, 4.2, .32, 'may'))     # vành miệng to
    # đuôi túm buộc mây + núm
    for k in range(3):
        objs.append(Torus(A + dirm * (L - .4 - k * .36), dirm, 1.35 + k * .07, .19, 'may'))
    objs.append(Ball(A + dirm * (L + .5), .75, 'may'))
    # 2 cọc tre cắm 2 bên giữ lờ (đóng xuống bùn), dây buộc vắt qua lưng
    side = nz(np.cross(V(0, 0, 1), ax))
    for s_, sd, h in [(5.0, 1, 7.0), (13.5, -1, 6.2)]:
        c = A + dirm * s_
        R = float(np.interp(s_, ps, pr))
        p = c + side * sd * (R + .55)
        objs.append(stake(float(p[0]), float(p[1]), -7, h, .42))
        objs += ties((float(p[0]), float(p[1]), 3.2), (0, 0, 1), .5, 3, .3, .14)
        # dây mây vắt từ cọc qua lưng lờ
        q0 = p + V(0, 0, 3.2); q1 = c + V(0, 0, R + .12)
        mid = (q0 + q1) / 2 + V(0, 0, .5)
        objs.append(Line([tuple(q0), tuple(mid), tuple(q1)], .14, 'may'))
    return Scene(objs)


def lop():
    # ống lọp mảnh cắm xiên: miệng dưới nước (z -3), đầu trên nhú khỏi nước bịt nùi bẹ chuối
    d = nz(V(math.cos(math.radians(150)) * .62, math.sin(math.radians(150)) * .62, .78))
    L = 20.0
    A = -d * L * .3                       # miệng
    body = Tube(A, d, L, [(0, 1.75), (.05, 1.85), (.5, 1.8), (1, 1.65)], 'dan', shell=.22, open0=True, open1=True, wv=(26, .07))
    hom = Tube(A + d * .04, d, 3.5, [(0, 1.62), (1, .45)], 'hom', shell=.16, open0=True, open1=True, wv=(14, .06))
    objs = [body, hom]
    for s_ in np.arange(.2, L, 1.35):
        objs.append(Torus(A + d * float(s_), d, 1.86, .1, 'may'))
    objs.append(Torus(A + d * .08, d, 1.75, .2, 'may'))
    # nùi bẹ chuối nhét đầu trên
    top = A + d * L
    rs = np.random.RandomState(3)
    _, e1, e2 = frame(d)
    for k in range(8):
        o = e1 * rs.uniform(-.9, .9) + e2 * rs.uniform(-.9, .9)
        p0 = top - d * 1.2 + o
        p1 = top + d * rs.uniform(1.0, 2.3) + o * 1.3 + e1 * rs.uniform(-.4, .4)
        objs.append(Line([tuple(p0), tuple(p1)], [rs.uniform(.45, .6), .22], 'be'))
    objs += [Torus(top - d * (.25 + i * .34), d, 1.72, .16, 'may') for i in range(3)]
    # cọc nhỏ cắm cạnh, dây buộc ống vô cọc
    side = nz(np.cross(V(0, 0, 1), d))
    sp = A + d * 11.0
    c = sp + side * 2.6
    objs.append(stake(float(c[0]), float(c[1]), -6, sp[2] + 4.5, .32, nodes=4.8))
    objs += ties((float(c[0]), float(c[1]), sp[2] + .5), (0, 0, 1), .38, 3, .26, .11)
    q0 = c + V(0, 0, sp[2] - c[2] + .5); q1 = sp + V(0, 0, 1.9)
    objs.append(Line([tuple(q0), tuple((q0 + q1) / 2 + V(0, 0, .25)), tuple(q1)], .11, 'may'))
    return Scene(objs)


def giang():
    # dây giăng giữa 2 cọc, 4 thẻo thòng xuống: phao khúc trúc nổi, lưỡi + mồi tép dưới nước
    dirl = nz(V(math.cos(math.radians(118)), math.sin(math.radians(118)), 0))
    Lw = 24.0
    P0 = -dirl * Lw / 2; P1 = dirl * Lw / 2
    objs = [stake(float(P0[0]), float(P0[1]), -7, 10.5, .48, nodes=5.6), stake(float(P1[0]), float(P1[1]), -7, 9.6, .45, nodes=5.4)]
    h0, h1 = 7.6, 7.0
    objs += ties((float(P0[0]), float(P0[1]), h0), (0, 0, 1), .56, 3, .3, .15)
    objs += ties((float(P1[0]), float(P1[1]), h1), (0, 0, 1), .53, 3, .3, .15)
    pts = []
    for k in range(25):
        t = k / 24
        p = P0 + (P1 - P0) * t
        pts.append((float(p[0]), float(p[1]), h0 + (h1 - h0) * t - 2.6 * 4 * t * (1 - t)))
    objs.append(Line(pts, .1, 'day'))
    side = nz(np.cross(V(0, 0, 1), dirl))
    for i, t in enumerate([.2, .4, .6, .8]):
        k = int(round(t * 24)); top = V(*pts[k])
        fz = .55
        f = top.copy(); f[2] = fz
        f = f + side * (.25 if i % 2 else -.15)
        objs.append(Line([tuple(top), tuple(f + V(0, 0, .5))], .07, 'day'))
        # phao: khúc trúc nằm ngang nổi trên nước, đầu sơn đỏ
        fa = nz(dirl + side * (.3 if i % 2 else -.25))
        objs.append(Line([tuple(f - fa * 1.0), tuple(f + fa * 1.0)], .42, 'phao'))
        hk = f + V(0, 0, -4.2)
        objs.append(Line([tuple(f), tuple(hk + V(0, 0, .6))], .06, 'day'))
        # lưỡi chữ J + mồi tép
        J = [hk + V(0, 0, .6), hk, hk + side * .2 + V(0, 0, -.45), hk + side * .55 + V(0, 0, -.35), hk + side * .62 + V(0, 0, .05)]
        objs.append(Line([tuple(p) for p in J], .07, 'thep'))
        objs.append(Line([tuple(hk + side * .5 + V(0, 0, -.2)), tuple(hk + side * .85 + V(0, 0, .45)), tuple(hk + side * 1.0 + V(0, 0, .95))], [.22, .2, .1], 'moi'))
    return Scene(objs)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    mp = os.path.join(OUT, 'meta.json')
    meta = json.load(open(mp)) if os.path.exists(mp) else {}
    for k in IDS:
        sc = {'lo': lo, 'lop': lop, 'giang': giang}[k]()
        (im, imw), anc = render(sc, k)
        im.save(os.path.join(OUT, k + '.webp'), lossless=True, quality=100, method=6)
        imw.save(os.path.join(OUT, k + '_w.webp'), lossless=True, quality=100, method=6)
        meta[k] = {"ax": anc[0], "ay": anc[1], "px_per_unit": PXU}
        print(k, im.size, anc, flush=True)
    json.dump(meta, open(mp, 'w'), indent=1)
