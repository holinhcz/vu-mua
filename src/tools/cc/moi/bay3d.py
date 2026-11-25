#!/usr/bin/env python3
# LỜ / LỌP / GIĂNG CÂU CẤP 1 dựng KHỐI 3D THẬT (11-24 Link "xấu vler, góc nhìn 3D đâu" -> "dựng 3D lên vẽ đi, 6px thôi").
# Bỏ bản vẽ dẹt ve_bay.py. Ở đây mỗi món là các khối SDF (ống đan, vòng mây, cọc tre có đốt, dây, lưỡi, phao) trong
# toạ độ thế giới của làng (đơn vị làng, z lên trời, mặt nước z = 0), chiếu vuông góc góc nhìn vườn:
# xoay 45 độ, nghiêng 30 độ (ô 32 x 16). Bắn tia từng điểm ảnh -> pháp tuyến thật, bóng đổ mềm, che sáng (AO),
# sáng trên-trái, viền mảnh màu tối của chỗ đó (như cá câu). Ra 6 px / đơn vị (vẽ gấp 4 rồi thu).
#   <id>.webp  : nguyên món (ô / bảng)     <id>_w.webp : đặt trên nước (phần dưới mặt nước mờ, ngả màu nước)
#   meta.json  : chỗ đặt chân (điểm (0,0,0) = giữa món ngay mặt nước) theo điểm ảnh của ảnh ra
#   python3 bay3d.py OUTDIR [lo lop giang lo2 lo3 lo4 lop2 ...]   (số = cấp, không số = cấp 1)     (env PXU = điểm ảnh / đơn vị, mặc định 6; SSA = vẽ gấp, mặc định 4)
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

AZ = math.radians(45); EL = math.radians(float(os.environ.get('EL', '30')))   # EL env: phao trong game nhìn ngang hơn
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
    def __init__(s, C, R, mat, sq=(1, 1, 1), cut=None):
        s.C = V(*C); s.R = R; s.mat = mat; s.sq = V(*sq); s.bound = (s.C, R * float(max(sq)) + 1)
        s.cut = None if cut is None else nz(V(*cut))      # nửa quả: bỏ phía pháp tuyến cut

    def sdf(s, P):
        q = (P - s.C) / s.sq
        d = (np.linalg.norm(q, axis=1) - s.R) * float(min(s.sq))
        if s.cut is not None:
            d = np.maximum(d, (P - s.C) @ s.cut)
        return d


class Box:
    """hộp bo góc: tâm C, 3 trục (đơn vị) ax0..2, nửa cạnh h"""
    def __init__(s, C, axes, h, mat, rr=.05):
        s.C = V(*C); s.A = np.array([nz(V(*a)) for a in axes], F32); s.h = V(*h); s.mat = mat; s.rr = rr
        s.bound = (s.C, float(np.linalg.norm(s.h)) + 1)

    def sdf(s, P):
        q = np.abs((P - s.C) @ s.A.T) - (s.h - s.rr)
        return np.linalg.norm(np.maximum(q, 0), axis=1) + np.minimum(q.max(1), 0) - s.rr


def M(o, col=None, sp=None, pw=None, emit=None, dk=None):
    """gắn chất liệu riêng cho 1 khối: màu gốc, độ bóng, đèn tự sáng"""
    if col is not None: o.col = hexc(col) if isinstance(col, str) else col
    if dk is not None: o.dk = hexc(dk) if isinstance(dk, str) else dk
    if sp is not None: o.sp = sp
    if pw is not None: o.pw = pw
    if emit is not None: o.emit = emit
    return o


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
        base = getattr(obj, 'col', TRE)
        c = base[None] * (1 + tone + .1 * (vnoise(P, 2.5, 1) - .5))[:, None]
        c = c * (1 - .07 * np.sin(z * 9 + k))[:, None]                          # xơ dọc nan
        c = c * (1 - .35 * sstep(.55, .85, vnoise(P, 1.6, 2)) * .5)[:, None]   # lốm đốm cũ
        c = c * (1 - gap * .55)[:, None] + TOI[None] * (gap * .55)[:, None]
        if m == 'hom':
            c = c * .9
        return c
    if m in ('kem', 'dong'):      # kẽm / đồng thau: kim loại, hơi loang
        base = getattr(obj, 'col', hexc('#9ea4a6') if m == 'kem' else hexc('#c99a3c'))
        return base[None] * (.85 + .3 * vnoise(P, .7, 11))[:, None]
    mc = getattr(obj, 'col', MAY)
    if m == 'may' and not isinstance(obj, Torus):
        return mc[None] * (.85 + .3 * vnoise(P, .5, 9))[:, None]
    if m == 'may':
        z, q, th = obj.local(P)
        tw = .5 + .5 * np.sin(th * 26 + np.arctan2(z, q - obj.R) * 2)        # mây quấn xoắn
        return mc[None] * (.85 + .25 * tw)[:, None]
    if m == 'go':   # gỗ tràm: sớ dọc, vỏ xám nâu, không đốt
        _, sl = obj.seg(P)
        base = getattr(obj, 'col', hexc('#9a8466'))
        v = vnoise(P * V(4, 4, .35), 1, 12)
        c = base[None] * (.78 + .4 * v)[:, None]
        if obj.cut is None:
            return c
        top = (P[:, 2] > obj.P[:, 2].max() - .6)
        return np.where(top[:, None], hexc('#d8bf92')[None], c)
    if m == 'son':  # cọc sơn đỏ có khoanh trắng
        _, sl = obj.seg(P)
        L = obj.cum[-1]
        band = ((sl > L * .55) & (sl < L * .62)) | ((sl > L * .86) & (sl < L * .9))
        c = np.where(band[:, None], hexc('#ece6d6')[None], hexc('#a83a2a')[None])
        return c * (.92 + .16 * vnoise(P, .8, 13))[:, None]
    if m == 'xop':
        return hexc('#f2f0ea')[None] * (.9 + .15 * vnoise(P * 3, 1, 14))[:, None]
    if m == 'nhua':  # phao nhựa nửa đỏ nửa trắng
        return np.where((P[:, 2] > obj.C[2])[:, None], hexc('#d23a2e')[None], hexc('#f0eee8')[None])
    if m == 'gao':   # gáo dừa
        v = vnoise(P * V(5, 5, 5), 1, 15)
        return (hexc('#6a4526')[None] * (.75 + .5 * v)[:, None])
    if m == 'kinh':  # chai đèn
        return np.broadcast_to(hexc('#a9c8a0'), (n, 3)).copy()
    if m == 'lua':
        return np.broadcast_to(hexc('#ffd27a'), (n, 3)).copy()
    if m == 'coc':
        _, sl = obj.seg(P)
        n_ = obj.nodes or 6
        nd = np.exp(-(((sl % n_) - n_ / 2) / .25) ** 2)
        cc = getattr(obj, 'col', COC); cd = getattr(obj, 'dk', COC_D)
        c = cc[None] * (1 + .12 * (vnoise(P * V(3, 3, .25), 1, 4) - .5))[:, None]
        c = c + (cd - cc)[None] * (nd * .6 + .3 * sstep(.6, .9, vnoise(P, 3, 5)))[:, None]
        top = (P[:, 2] > obj.P[:, 2].max() - .6)
        return np.where(top[:, None], hexc('#e3d29c')[None], c)
    if m == 'day':
        dc = getattr(obj, 'col', hexc('#e9e3d0'))
        if hasattr(obj, 'seg'):
            _, sl = obj.seg(P)
            return dc[None] * (1 - .12 * (np.sin(sl * 9) > .3))[:, None]    # dây bện
        return np.broadcast_to(dc, (n, 3)).copy()
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


# thông số sáng (tool khác giữ mặc định; ghe3d chỉnh riêng)
LT = dict(amb=.34, sky=.16, dif=.78, shmin=0.0, aop=1.0, expo=1.0, inner=.66, spec=1.0, tone=0.0)


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
    dz = B @ FWD; t0 = 200 + float(dz.min()) - 2; t1 = 200 + float(dz.max()) + 2
    t = np.full(n, t0, F32); hit = np.zeros(n, bool); act = np.arange(n)
    for it in range(260):
        P = O[act] + FWD * t[act, None]
        d = scene.sdf(P)
        t[act] += d
        h = d < .004
        hit[act[h]] = True
        keep = (~h) & (t[act] < t1)
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
    spk = np.full(len(P), .1, F32); pwk = np.full(len(P), 24., F32); emk = np.zeros(len(P), F32)
    DEF_SP = {'kem': (.55, 30), 'dong': (.75, 36), 'nhua': (.4, 40), 'kinh': (.8, 60), 'thep': (.5, 40)}
    for i, o in enumerate(scene.objs):
        m = oid == i
        if m.any():
            d0 = DEF_SP.get(o.mat, (.1, 24))
            spk[m] = getattr(o, 'sp', d0[0]); pwk[m] = getattr(o, 'pw', d0[1]); emk[m] = getattr(o, 'emit', 0)
    lam = np.clip(N @ LIGHT, 0, 1)
    H_ = nz(LIGHT - FWD)
    spec = np.clip(N @ H_, 0, 1) ** pwk * spk * LT['spec']
    sky = .5 + .5 * N[:, 2]
    shl = LT['shmin'] + (1 - LT['shmin']) * sh          # bóng đổ không đen kịt (mặc định 0 = như cũ)
    aol = ao ** LT['aop']
    lum = (LT['amb'] + LT['sky'] * sky) * aol + LT['dif'] * lam * shl * (.55 + .45 * aol)
    lum = lum * (1 - LT['inner'] * inner) * LT['expo']
    col = alb * lum[:, None] + spec[:, None] * sh[:, None] * (1 - inner)[:, None]
    col = col * (1 - emk[:, None]) + alb * emk[:, None]        # đèn: tự sáng
    if LT['tone']:   # nén sáng mềm: nâng chỗ tối, chỗ sáng không cháy trắng
        col = col * (1 + LT['tone']) / (1 + col * LT['tone'])
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
def stake(x, y, z0, z1, r, nodes=5.5, lean=(0, 0), mat='coc', col=None, dk=None):
    top = (x + lean[0], y + lean[1], z1)
    o = Line([(x, y, z0), top], [r, r * .95], mat, nodes=nodes if mat == 'coc' else None,
             cut_top=((top[0], top[1], z1 - .3), (.5, .2, 1)))
    return M(o, col=col, dk=dk)


def ties(C, ax, R, n=3, gap=.34, r=.17, mat='may', col=None):
    a = nz(V(*ax))
    return [M(Torus(V(*C) + a * (i - (n - 1) / 2) * gap, ax, R, r, mat), col=col) for i in range(n)]


# ------------------------------------------------------------ 4 cấp (11-24 Link "cấp 2 cấp 3 cấp 4 là gì" -> vẽ thôi, bên kia gắn)
#  1 tre mộc, mây          2 tre già ám khói, mây đôi      3 dầu chai bóng nâu + kẽm      4 tre đen bóng như mun + đồng thau
TIER = {
    1: dict(tre='#cfae72', sp=.1, pw=24, ring='may', ringc='#7a5230', coc=('#d8c886', '#9a8a4c'), cmat='coc'),
    2: dict(tre='#a7844f', sp=.14, pw=24, ring='may', ringc='#5a3a20', coc=('#b3a067', '#6f5f2c'), cmat='coc'),
    3: dict(tre='#94602e', sp=.38, pw=30, ring='kem', ringc='#9ea4a6', coc=('#a07a46', '#6a4c26'), cmat='coc'),
    4: dict(tre='#40302a', sp=.55, pw=40, ring='dong', ringc='#c99a3c', coc=('#4a3626', '#2a1e16'), cmat='go'),
}


def lo(t=1):
    T = TIER[t]
    # lờ nằm ngang mặt nước (camera ở phía +x +y: hướng 135 độ = phải màn hình, 315 = trái)
    ax = nz(V(math.cos(math.radians(342)), math.sin(math.radians(342)), 0))   # từ đuôi về miệng: miệng chĩa trái màn hình, hơi về phía người xem
    L = 19.0 + (t - 1) * .7
    tail = -ax * L * .5 + V(0, 0, .4)
    A = tail + ax * L                      # miệng
    dirm = -ax                             # trục từ miệng vô đuôi
    prof = [(0, 4.2), (.08, 4.45), (.32, 4.9), (.58, 4.5), (.8, 3.1), (.94, 1.7), (1, 1.3)]
    body = M(Tube(A, dirm, L, prof, 'dan', shell=.32, open0=True, open1=True, wv=(46 + (t - 1) * 6, .09)), col=T['tre'], sp=T['sp'], pw=T['pw'])
    hom = M(Tube(A + dirm * .05, dirm, 6.5, [(0, 4.0), (.75, 1.25), (1, 1.0)], 'hom', shell=.22, open0=True, open1=True, wv=(26, .08)), col=T['tre'], sp=T['sp'], pw=T['pw'])
    objs = [body, hom]
    if t >= 2:   # hom 2 lớp: hom trong nữa, cá vô khó ra
        objs.append(M(Tube(A + dirm * 6.0, dirm, 4.5, [(0, 3.9), (1, .9)], 'hom', shell=.2, open0=True, open1=True, wv=(22, .08)), col=T['tre'], sp=T['sp'], pw=T['pw']))
    ps = np.array([p[0] for p in prof]) * L; pr = np.array([p[1] for p in prof])
    for j, s_ in enumerate([.25, 3.2, 6.4, 9.6, 12.6, 15.2]):
        s_ = s_ * L / 19.0
        R = float(np.interp(s_, ps, pr)) + .06
        rm = T['ring'] if (t < 3 or j % 2 == 0 or t == 4) else 'may'          # cấp 3: kẽm xen mây
        rc = T['ringc'] if rm == T['ring'] else '#6a4426'
        offs = [-.22, .22] if t == 2 else [0]                                  # cấp 2: đai đôi
        for o_ in offs:
            objs.append(M(Torus(A + dirm * (s_ + o_), dirm, R, .17 if rm == 'may' else .15, rm), col=rc))
    objs.append(M(Torus(A + dirm * .1, dirm, 4.2, .32 if t < 4 else .36, T['ring'] if t >= 3 else 'may'), col=T['ringc']))     # vành miệng
    for k in range(3):
        objs.append(M(Torus(A + dirm * (L - .4 - k * .36), dirm, 1.35 + k * .07, .19, T['ring'] if t == 4 else 'may'), col=T['ringc'] if t == 4 else '#6a4426'))
    objs.append(M(Ball(A + dirm * (L + .5), .75, 'dong' if t == 4 else 'may'), col='#c99a3c' if t == 4 else '#6a4426'))
    side = nz(np.cross(V(0, 0, 1), ax))
    stk = []
    for s_, sd, h in [(5.0, 1, 7.0), (13.5, -1, 6.2)]:
        s_ = s_ * L / 19.0
        c = A + dirm * s_
        R = float(np.interp(s_, ps, pr))
        p = c + side * sd * (R + .55)
        objs.append(stake(float(p[0]), float(p[1]), -7, h, .42, mat=T['cmat'], col=T['coc'][0], dk=T['coc'][1]))
        objs += ties((float(p[0]), float(p[1]), 3.2), (0, 0, 1), .5, 3, .3, .14, mat=T['ring'] if t == 4 else 'may', col=T['ringc'] if t == 4 else None)
        q0 = p + V(0, 0, 3.2); q1 = c + V(0, 0, R + .12)
        mid = (q0 + q1) / 2 + V(0, 0, .5)
        objs.append(M(Line([tuple(q0), tuple(mid), tuple(q1)], .14, 'may'), col='#6a4426' if t > 1 else None))
        stk.append((p, h))
    if t >= 3:   # phao đánh dấu buộc dây từ đầu cọc, nổi cạnh lờ
        p, h = stk[1]
        cam = nz(V(1, 1, 0))                       # phía người xem: phao nổi trước mặt lờ cho thấy
        fp = A + dirm * (L * .62) + cam * 7.0
        fp[2] = .25
        objs.append(M(Ball(fp, .8, 'nhua' if t == 3 else 'dong'), col='#c99a3c' if t == 4 else None))
        top_ = p + V(0, 0, h - 1.0)
        objs.append(M(Line([tuple(top_), tuple((top_ + fp) / 2 + V(0, 0, -.6)), tuple(fp + V(0, 0, .7))], .06, 'day'), col='#d9e6e8'))
    if t == 4:   # cửa sập đồng trên lưng để trút cá + bản lề
        s_ = 11.0 * L / 19.0
        R = float(np.interp(s_, ps, pr))
        up = V(0, 0, 1)
        C = A + dirm * s_ + up * (R + .05)
        objs.append(Box(C, (dirm, side, up), (1.5, 1.25, .1), 'dong', rr=.06))
        objs.append(Line([tuple(C + side * 1.25 - dirm * 1.3 + up * .1), tuple(C + side * 1.25 + dirm * 1.3 + up * .1)], .12, 'dong'))
        objs.append(Ball(C - side * .8 + up * .22, .2, 'dong'))     # núm kéo
    return Scene(objs)


def lop(t=1):
    T = TIER[t]
    # ống lọp mảnh cắm xiên: miệng dưới nước (z -3), đầu trên nhú khỏi nước có nắp
    d = nz(V(math.cos(math.radians(150)) * .62, math.sin(math.radians(150)) * .62, .78))
    L = 20.0
    A = -d * L * .3                       # miệng
    body = M(Tube(A, d, L, [(0, 1.75), (.05, 1.85), (.5, 1.8), (1, 1.65)], 'dan', shell=.22, open0=True, open1=True, wv=(26 + (t - 1) * 3, .07)), col=T['tre'], sp=T['sp'], pw=T['pw'])
    hom = M(Tube(A + d * .04, d, 3.5, [(0, 1.62), (1, .45)], 'hom', shell=.16, open0=True, open1=True, wv=(14, .06)), col=T['tre'], sp=T['sp'], pw=T['pw'])
    objs = [body, hom]
    for j, s_ in enumerate(np.arange(.2, L, 1.35)):
        rm = T['ring'] if (t == 2 or j % 3 == 0 or t == 1) else 'may'
        if t == 1: rm = 'may'
        rc = T['ringc'] if rm == T['ring'] else '#6a4426'
        objs.append(M(Torus(A + d * float(s_), d, 1.86, .1 if rm == 'may' else .11, rm), col=rc))
    objs.append(M(Torus(A + d * .08, d, 1.75, .2, T['ring'] if t >= 3 else 'may'), col=T['ringc']))
    top = A + d * L
    _, e1, e2 = frame(d)
    if t == 1:   # nùi bẹ chuối nhét đầu trên
        rs = np.random.RandomState(3)
        for k in range(8):
            o = e1 * rs.uniform(-.9, .9) + e2 * rs.uniform(-.9, .9)
            p0 = top - d * 1.2 + o
            p1 = top + d * rs.uniform(1.0, 2.3) + o * 1.3 + e1 * rs.uniform(-.4, .4)
            objs.append(Line([tuple(p0), tuple(p1)], [rs.uniform(.45, .6), .22], 'be'))
    elif t == 2:   # nắp gáo dừa úp đầu ống
        objs.append(Ball(top + d * .1, 2.05, 'gao', sq=(1, 1, 1), cut=-d))
        objs.append(M(Torus(top - d * .05, d, 2.0, .16, 'may'), col='#5a3a20'))
    elif t == 3:   # nắp gỗ có chốt ngang
        objs.append(M(Line([tuple(top - d * .3), tuple(top + d * .5)], 1.95, 'go'), col='#8a6a44'))
        objs.append(M(Line([tuple(top + d * .1 - e1 * 2.6), tuple(top + d * .1 + e1 * 2.6)], .22, 'go'), col='#6a4e30'))
    else:          # nắp đồng có núm
        objs.append(M(Line([tuple(top - d * .3), tuple(top + d * .45)], 1.95, 'dong'), sp=.8))
        objs.append(Ball(top + d * 2.55, .45, 'dong'))
        objs.append(M(Line([tuple(top + d * 2.2), tuple(top + d * 2.6)], .25, 'dong'), sp=.8))
    if t == 1:
        objs += [Torus(top - d * (.25 + i * .34), d, 1.72, .16, 'may') for i in range(3)]
    side = nz(np.cross(V(0, 0, 1), d))
    sp = A + d * 11.0
    c = sp + side * 2.6
    objs.append(stake(float(c[0]), float(c[1]), -6, sp[2] + 4.5, .32, nodes=4.8, mat=T['cmat'], col=T['coc'][0], dk=T['coc'][1]))
    objs += ties((float(c[0]), float(c[1]), sp[2] + .5), (0, 0, 1), .38, 3, .26, .11, mat=T['ring'] if t == 4 else 'may', col=T['ringc'] if t == 4 else None)
    q0 = c + V(0, 0, sp[2] - c[2] + .5); q1 = sp + V(0, 0, 1.9)
    if t >= 3:   # dây cước
        objs.append(M(Line([tuple(q0), tuple((q0 + q1) / 2 + V(0, 0, .25)), tuple(q1)], .07, 'day'), col='#d9e6e8'))
    else:
        objs.append(M(Line([tuple(q0), tuple((q0 + q1) / 2 + V(0, 0, .25)), tuple(q1)], .11, 'may'), col='#6a4426' if t > 1 else None))
    return Scene(objs)


def giang(t=1):
    # dây giăng giữa 2 cọc, thẻo thòng xuống: phao nổi, lưỡi + mồi tép dưới nước. Cấp càng cao càng nhiều lưỡi
    nh = [4, 6, 8, 10][t - 1]
    dirl = nz(V(math.cos(math.radians(118)), math.sin(math.radians(118)), 0))
    Lw = 24.0 + (t - 1) * 2.5
    P0 = -dirl * Lw / 2; P1 = dirl * Lw / 2
    cm, cc = [('coc', ('#d8c886', '#9a8a4c')), ('coc', ('#b3a067', '#6f5f2c')), ('go', ('#9a8466', None)), ('son', (None, None))][t - 1]
    objs = [stake(float(P0[0]), float(P0[1]), -7, 10.5, .48, nodes=5.6, mat=cm, col=cc[0], dk=cc[1]),
            stake(float(P1[0]), float(P1[1]), -7, 9.6, .45, nodes=5.4, mat=cm, col=cc[0], dk=cc[1])]
    h0, h1 = 7.6, 7.0
    rmat = 'dong' if t == 4 else 'may'
    objs += ties((float(P0[0]), float(P0[1]), h0), (0, 0, 1), .56, 3, .3, .15, mat=rmat, col='#c99a3c' if t == 4 else ('#5a3a20' if t > 1 else None))
    objs += ties((float(P1[0]), float(P1[1]), h1), (0, 0, 1), .53, 3, .3, .15, mat=rmat, col='#c99a3c' if t == 4 else ('#5a3a20' if t > 1 else None))
    pts = []
    for k in range(31):
        u = k / 30
        p = P0 + (P1 - P0) * u
        pts.append((float(p[0]), float(p[1]), h0 + (h1 - h0) * u - 2.6 * 4 * u * (1 - u)))
    lc, lr = [('#e9e3d0', .1), ('#b8743a', .13), ('#d9e6e8', .07), ('#e8e2c8', .09)][t - 1]   # dây gai / dây dù / cước / cước bện
    objs.append(M(Line(pts, lr, 'day'), col=lc))
    side = nz(np.cross(V(0, 0, 1), dirl))
    for i in range(nh):
        u = (i + 1) / (nh + 1)
        k = int(round(u * 30)); top = V(*pts[k])
        f = top.copy(); f[2] = .55
        f = f + side * (.25 if i % 2 else -.15)
        objs.append(M(Line([tuple(top), tuple(f + V(0, 0, .5))], .07, 'day'), col=lc))
        fa = nz(dirl + side * (.3 if i % 2 else -.25))
        if t == 1:     # phao khúc trúc đầu đỏ
            objs.append(Line([tuple(f - fa * 1.0), tuple(f + fa * 1.0)], .42, 'phao'))
        elif t == 2:   # phao xốp trắng
            objs.append(Box(f + V(0, 0, .05), (fa, np.cross(V(0, 0, 1), fa), (0, 0, 1)), (.75, .5, .4), 'xop', rr=.12))
        else:          # phao nhựa đỏ trắng / phao đồng
            objs.append(M(Ball(f + V(0, 0, .1), .55, 'nhua' if t == 3 else 'dong'), sp=.5 if t == 3 else None))
        hk = f + V(0, 0, -4.2)
        objs.append(M(Line([tuple(f), tuple(hk + V(0, 0, .6))], .06, 'day'), col=lc))
        J = [hk + V(0, 0, .6), hk, hk + side * .2 + V(0, 0, -.45), hk + side * .55 + V(0, 0, -.35), hk + side * .62 + V(0, 0, .05)]
        objs.append(Line([tuple(p) for p in J], .07, 'thep'))
        objs.append(Line([tuple(hk + side * .5 + V(0, 0, -.2)), tuple(hk + side * .85 + V(0, 0, .45)), tuple(hk + side * 1.0 + V(0, 0, .95))], [.22, .2, .1], 'moi'))
    if t >= 3:   # lục lạc đồng treo đầu cọc trái: cá giựt là reo
        b0 = P0 + V(0, 0, 10.2) + side * .55
        objs.append(M(Line([tuple(P0 + V(0, 0, 10.2)), tuple(b0), tuple(b0 + V(0, 0, -.9))], .05, 'day'), col='#5a3a20'))
        objs.append(Ball(b0 + V(0, 0, -1.35), .48, 'dong'))
        objs.append(Torus(b0 + V(0, 0, -1.6), (0, 0, 1), .3, .1, 'dong'))
    if t == 4:   # đèn chai trên đầu cọc phải: câu đêm
        b = P1 + V(0, 0, 9.6)
        objs.append(M(Line([tuple(b), tuple(b + V(0, 0, 1.3))], .5, 'kinh'), sp=.8, pw=60))
        objs.append(M(Line([tuple(b + V(0, 0, 1.3)), tuple(b + V(0, 0, 1.9))], .18, 'kinh'), sp=.8))
        objs.append(M(Ball(b + V(0, 0, 2.3), .26, 'lua', sq=(1, 1, 1.7)), emit=1.0))
    return Scene(objs)


if __name__ == '__main__':
    # 11-25 Link "lờ lọp hơi tối, chỗ khuất sáng lên tí": cùng mức sáng với ghe sông Vàm (ghe3d), lòng đan bớt đen
    LT.update(amb=.5, sky=.2, shmin=.45, aop=.6, expo=1.25, inner=.45)
    os.makedirs(OUT, exist_ok=True)
    mp = os.path.join(OUT, 'meta.json')
    meta = json.load(open(mp)) if os.path.exists(mp) else {}
    for k in IDS:
        base = k.rstrip('1234'); tier = int(k[len(base):] or 1)     # lo, lo2, lo3, lo4 ...
        sc = {'lo': lo, 'lop': lop, 'giang': giang}[base](tier)
        (im, imw), anc = render(sc, k)
        im.save(os.path.join(OUT, k + '.webp'), lossless=True, quality=100, method=6)
        imw.save(os.path.join(OUT, k + '_w.webp'), lossless=True, quality=100, method=6)
        meta[k] = {"ax": anc[0], "ay": anc[1], "px_per_unit": PXU}
        print(k, im.size, anc, flush=True)
    json.dump(meta, open(mp, 'w'), indent=1)
