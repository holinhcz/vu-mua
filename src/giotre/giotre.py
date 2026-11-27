# Giỏ tre đựng icon món hàng (đơn hàng) - 2 lớp: sau (toàn giỏ) + truoc (miệng/thành trước)
# Dựng 3D bằng mặt tham số + z-buffer splat, tô màu kiểu 2D (mảng phẳng 2-3 tone, viền đậm cùng màu).
# python3 giotre.py OUTDIR TIER [W]
import sys, math, numpy as np
from PIL import Image

A = math.radians(32)                      # góc nhìn xuống
D = np.array([0, math.cos(A), -math.sin(A)])
U = np.array([0, math.sin(A), math.cos(A)])
L = np.array([-0.45, -0.55, 0.70]); L /= np.linalg.norm(L)

def hx(s):
    s = s.lstrip('#'); return np.array([int(s[i:i+2], 16) for i in (0, 2, 4)], float)

# bảng màu tre tươi (sáng, kiểu chuối/tre cũ)
TRE = dict(hi=hx('fce690'), b=hx('f2c85a'), lo=hx('dca63c'), dp=hx('b07a24'))
TRE_IN = dict(hi=hx('f0d070'), b=hx('e0b04a'), lo=hx('c89234'), dp=hx('9c6c22'))
MAY = dict(hi=hx('f4d488'), b=hx('e4b058'), lo=hx('cc9640'), dp=hx('a8742c'))
VANH = dict(hi=hx('f4d88a'), b=hx('dcb460'), lo=hx('bc9040'), dp=hx('8c6424'))


class R:
    def __init__(s, W, H, sc, cx, cy):
        s.W, s.H, s.sc, s.cx, s.cy = W, H, sc, cx, cy
        s.z = np.full(W * H, np.inf); s.c = np.zeros((W * H, 3)); s.id = np.zeros(W * H, np.int16)

    def splat(s, P, C, oid):
        X = (P @ np.array([1, 0, 0])) * s.sc + s.cx
        Y = -(P @ U) * s.sc + s.cy
        d = P @ D
        xi = np.round(X).astype(int); yi = np.round(Y).astype(int)
        ok = (xi >= 0) & (xi < s.W) & (yi >= 0) & (yi < s.H)
        xi, yi, d, C = xi[ok], yi[ok], d[ok], C[ok]
        if np.isscalar(oid) or np.ndim(oid) == 0:
            oid = np.full(len(d), oid)
        else:
            oid = oid[ok]
        k = yi * s.W + xi
        o = np.argsort(-d, kind='stable'); k, d, C, oid = k[o], d[o], C[o], oid[o]
        tz = {}
        uk, first = np.unique(k[::-1], return_index=True)   # gần nhất (cuối mảng)
        j = len(k) - 1 - first
        m = d[j] < s.z[uk]
        uk, j = uk[m], j[m]
        s.z[uk] = d[j]; s.c[uk] = C[j]; s.id[uk] = oid[j]


DENS = 1.0   # mật độ điểm theo độ phân giải (W*SS/1400)
def surf(R_, f, t0, t1, v0, v1, nt, nv, tex, oid, flip=False, chunk=600):
    # f(T,V)->P (N,3); tex(T,V,P,N)->colour
    nt = int(nt * DENS); nv = int(nv * DENS); chunk = max(40, int(chunk / DENS))
    ts = np.linspace(t0, t1, nt)
    for a in range(0, nt, chunk):
        T, V = np.meshgrid(ts[a:a + chunk], np.linspace(v0, v1, nv), indexing='ij')
        T = T.ravel(); V = V.ravel()
        P = f(T, V)
        e = 1e-4
        Pt = (f(T + e, V) - f(T - e, V)); Pv = (f(T, V + e) - f(T, V - e))
        N = np.cross(Pt, Pv); N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-12
        if flip: N = -N
        C = tex(T, V, P, N)
        R_.splat(P, C, oid if not callable(oid) else oid(T, V, P, N))


def lam(N):
    return np.clip(N @ L, -1, 1)


def shade(pal, z, N, k=0.30):
    # z: 0 deep,1 lo,2 base,3 hi (mảng phẳng); bóng nhẹ theo hướng sáng, không tối đen
    cols = np.stack([pal['dp'], pal['lo'], pal['b'], pal['hi']])
    c = cols[np.clip(z, 0, 3)]
    l = lam(N)
    f = 1 - k * (1 - (0.5 + 0.5 * l))
    return c * f[:, None]


# ---------------- hình giỏ ----------------
class Gio:
    def __init__(s, rx=1.0, ry=0.62, h=0.60, fb=0.80, n=2.0, th=0.035):
        s.rx, s.ry, s.h, s.fb, s.n, s.th = rx, ry, h, fb, n, th

    def ring(s, T, k):
        # siêu elip dạng cực (mượt mọi chỗ, không có mối nối)
        c, si = np.cos(T), np.sin(T)
        rr = (np.abs(c) ** s.n + np.abs(si) ** s.n) ** (-1.0 / s.n)
        return c * rr * s.rx * k, si * rr * s.ry * k

    def kz(s, V):
        # V 0..1 theo chiều cao, phình nhẹ ở giữa (giỏ đan bầu)
        return s.fb + (1 - s.fb) * V + 0.06 * np.sin(np.pi * V)

    def outer(s, T, V):
        x, y = s.ring(T, s.kz(V)); return np.stack([x, y, V * s.h], 1)

    def inner(s, T, V):
        k = s.kz(V) - s.th / s.ry * 0.9
        x, y = s.ring(T, k); return np.stack([x, y, V * s.h + 0.0], 1)

    def floor(s, T, V):
        k = (s.fb - s.th / s.ry) * V
        x, y = s.ring(T, k); return np.stack([x, y, np.full_like(T, 0.03 * s.h) + 0.0 * V], 1)

    def rim(s, T, V, rr=0.05, k0=None):
        k = (s.kz(np.ones_like(T)) - 0.5 * s.th / s.ry) if k0 is None else k0
        x, y = s.ring(T, k)
        # pháp tuyến ngang của vòng
        e = 1e-3
        x2, y2 = s.ring(T + e, k); tx, ty = x2 - x, y2 - y; ln = np.hypot(tx, ty) + 1e-12
        nx, ny = ty / ln, -tx / ln
        ph = V
        return np.stack([x + rr * np.cos(ph) * nx, y + rr * np.cos(ph) * ny, s.h + rr * np.sin(ph)], 1)

    def arclen(s, T, k=1.0):
        # độ dài cung xấp xỉ theo T (để nan đều)
        ts = np.linspace(0, 2 * np.pi, 4001)
        x, y = s.ring(ts, k); dl = np.hypot(np.diff(x), np.diff(y)); cl = np.concatenate([[0], np.cumsum(dl)])
        return np.interp(np.mod(T, 2 * np.pi), ts, cl), cl[-1]


# ---------------- vân đan ----------------
def weave(u, v, sw, sh, pal_h, pal_v, N, gap=0.16, twill=1):
    """đan nong: nan ngang (sh) đè/luồn nan dọc (sw). trả màu phẳng 2-3 vùng + khe sâu."""
    i = np.floor(u / sw).astype(int); j = np.floor(v / sh).astype(int)
    fu = u / sw - i; fv = v / sh - j
    hor = ((i // twill + j) % 2 == 0)
    z = np.full(len(u), 2)
    # nan ngang: vạt sáng mép trên, sẫm mép dưới, khe giữa 2 nan ngang
    fz = np.where(hor, fv, fu)
    z = np.where(fz > 0.70, 3, z)
    z = np.where(fz < 0.26, 1, z)
    # đầu nan chui xuống (cuối ô theo chiều đi) sẫm 1 bậc
    fl = np.where(hor, fu, fv)
    z = np.where((fl < 0.10) | (fl > 0.90), np.minimum(z, 1), z)
    gp = (fz < gap * 0.5) | (fz > 1 - gap * 0.5)
    z = np.where(gp, 0, z)
    ch = shade(pal_h, z, N); cv = shade(pal_v, z, N)
    # mỗi nan 1 tone hơi khác (tay đan), phẳng theo cả sợi
    rh = np.sin(j * 12.9898 + 3.1) * 43758.5453; rh = (rh - np.floor(rh)) - 0.5
    rv = np.sin(i * 78.233 + 1.7) * 43758.5453; rv = (rv - np.floor(rv)) - 0.5
    ch = ch * (1 + 0.07 * rh)[:, None]; cv = cv * (1 + 0.07 * rv)[:, None]
    return np.where(hor[:, None], ch, cv), hor


# ---------------- bảng màu thêm ----------------
HUN = dict(hi=hx('d89a5a'), b=hx('bc7a3c'), lo=hx('9c5e2a'), dp=hx('74401c'))       # nan hun khói nâu
HUN_IN = dict(hi=hx('c88a4c'), b=hx('a86a34'), lo=hx('8c5226'), dp=hx('663818'))
TRAM = dict(hi=hx('f6c88a'), b=hx('e0a660'), lo=hx('c48448'), dp=hx('985e30'))     # gỗ tràm
MAY2 = dict(hi=hx('f8d890'), b=hx('eab860'), lo=hx('d09a44'), dp=hx('a8742c'))     # mây vàng mật
MAY2_IN = dict(hi=hx('ecc878'), b=hx('dca850'), lo=hx('c08a3a'), dp=hx('946426'))
SON = dict(hi=hx('f0604a'), b=hx('dc4030'), lo=hx('bc3024'), dp=hx('8c2018'))       # sơn son
VANG = dict(hi=hx('fff0a0'), b=hx('f8cc48'), lo=hx('dca430'), dp=hx('b07c20'))
DONG = dict(hi=hx('fce08c'), b=hx('eab450'), lo=hx('c88c34'), dp=hx('9c6624'))      # đồng thau
NGOC = dict(hi=hx('f8fcf8'), b=hx('e4f0ec'), lo=hx('c8dcd8'), dp=hx('98b4b4'))      # xà cừ
SEN = dict(hi=hx('ffd0dc'), b=hx('f8a8bc'), lo=hx('e8849c'), dp=hx('c05c78'))


def rnd(k, s=0.0):
    r = np.sin(k * 12.9898 + s * 78.233 + 1.3) * 43758.5453
    return r - np.floor(r)


def weave2(u, v, sw, sh, pick, N, gap=0.15, twill=1, inside=False):
    """pick(i,j,hor)->pal index array; pals list. thớ tre: vạt sáng mép trên, sẫm mép dưới, sợi thớ mảnh, đầu nan chui sẫm."""
    i = np.floor(u / sw).astype(int); j = np.floor(v / sh).astype(int)
    fu = u / sw - i; fv = v / sh - j
    hor = (((i // twill) + j) % 2 == 0)
    fz = np.where(hor, fv, fu)          # ngang qua sợi
    fl = np.where(hor, fu, fv)          # dọc theo sợi
    k = np.where(hor, j, i)
    z = np.full(len(u), 2)
    z = np.where(fz > 0.68, 3, z)
    z = np.where(fz < 0.28, 1, z)
    # sợi thớ: 2 đường mảnh / sợi, vị trí lệch theo sợi
    t1 = 0.40 + 0.12 * rnd(k, 1); t2 = 0.56 + 0.08 * rnd(k, 2)
    z = np.where((np.abs(fz - t1) < 0.025) | (np.abs(fz - t2) < 0.02), np.minimum(z, 1), z)
    # đầu nan chui xuống: sẫm, bo góc
    end = np.minimum(fl, 1 - fl)
    z = np.where(end < 0.09, np.minimum(z, 1), z)
    cor = (end < 0.14) & ((fz < 0.2) | (fz > 0.8))
    z = np.where(cor, 0, z)
    z = np.where((fz < gap * 0.5) | (fz > 1 - gap * 0.5), 0, z)
    return z, i, j, hor, k


def pals_shade(pals, pi, z, N, tone):
    out = np.zeros((len(z), 3))
    for n, p in enumerate(pals):
        m = pi == n
        if m.any():
            out[m] = shade(p, z[m], N[m])
    return out * (1 + 0.06 * (tone - 0.5))[:, None]


COI = dict(hi=hx('fcf0b8'), b=hx('f0dc90'), lo=hx('d8c070'), dp=hx('a89048'))      # cói/lác phơi trắng
COI_DO = dict(hi=hx('f87060'), b=hx('e04838'), lo=hx('c03428'), dp=hx('902418'))   # cói nhuộm đỏ
COI_XA = dict(hi=hx('90d070'), b=hx('5cb048'), lo=hx('409034'), dp=hx('2c6c24'))   # cói nhuộm xanh
COI_IN = dict(hi=hx('f0e0a0'), b=hx('e0c87c'), lo=hx('c8ac60'), dp=hx('98803c'))
HUN2 = dict(hi=hx('c88850'), b=hx('a86836'), lo=hx('8a5028'), dp=hx('663a1c'))
HUN2_IN = dict(hi=hx('b87a46'), b=hx('985c30'), lo=hx('7c4624'), dp=hx('5a3218'))
MAYT = dict(hi=hx('fff4d0'), b=hx('f4e0a8'), lo=hx('dcc488'), dp=hx('b09a60'))     # mây trắng
G_ALL = dict(rx=1.06, ry=0.63, h=0.70, fb=0.78, th=0.045)
CFG = {
    1: dict(g=dict(G_ALL, n=2.0), ns=62, nr=8, twill=1,
            pal=[TRE], pal_in=[TRE_IN], pat=None, rim='tre', foot='tre', handle=None),
    2: dict(g=dict(G_ALL, n=2.0), ns=72, nr=10, twill=2,
            pal=[HUN2, TRE], pal_in=[HUN2_IN, TRE_IN], pat='zigzag', rim='hun', foot='hun', handle='may'),
    3: dict(g=dict(G_ALL, n=2.6), ns=112, nr=14, twill=1,
            pal=[COI, COI_DO, COI_XA], pal_in=[COI_IN, COI_DO, COI_XA], pat='chieu', rim='go', foot='go', handle='go', posts=8),
    4: dict(g=dict(G_ALL, n=2.6), ns=84, nr=12, twill=1,
            pal=[MAY2], pal_in=[MAY2_IN], pat=None, rim='son', foot='son', handle='dong', band=0.22, logo=True, straps=4),
}


def pick_pat(pat, i, j, hor, nr):
    pi = np.zeros(len(i), int)
    if pat == 'zigzag':
        # chuỗi hình thoi to nan tre vàng trên nền hun: viền thoi dày 2 ô + nhân giữa
        dm = np.abs(j - 4.5) / 4.2 + np.abs(np.mod(i, 16) - 8) / 8.0
        pi = np.where((dm < 1.0) & (dm > 0.70), 1, pi)
        pi = np.where((dm < 0.26), 1, pi)
    elif pat == 'chieu':
        # kiểu chiếu cói: 2 sọc xanh-đỏ trên dưới + hàng thoi đỏ nhân xanh giữa thân
        pi = np.where(hor & ((j == 1) | (j == 12)), 2, pi)
        pi = np.where(hor & ((j == 2) | (j == 11)), 1, pi)
        dm = np.abs(j - 6.5) / 3.4 + np.abs(np.mod(i, 14) - 7) / 7.0
        pi = np.where((dm < 1.0) & (dm > 0.68), 1, pi)
        pi = np.where((dm < 0.30), 2, pi)
    elif pat == 'band':
        pi = np.where(hor & ((j % 3) == 1), 1, pi)
        pi = np.where(~hor & (np.mod(i, 10) == 0), 1, pi)
    return pi


def build(tier, W=1400):
    C = CFG[tier]
    g = Gio(**C['g'])
    sc = W / 2.85
    Hh = int(W * 0.80)
    r = R(W, Hh, sc, W / 2, Hh * 0.58)
    _, CL = g.arclen(np.zeros(1))
    SW = CL / C['ns']
    band = C.get('band', 0.0)
    v0w = band                                  # vân đan từ trên band
    SH = g.h * (0.94 - v0w) / C['nr']

    def u_of(T): return g.arclen(T)[0]
    up = np.array([0, 0, 1.0])

    def front_id(P, a, b): return np.where(P[:, 1] < 0, b, a)

    # ---- thân: nan đan có khối thật (nan phồng, luồn lên xuống, khe lõm)
    AMP = 0.011
    def nrm_out(P):
        n = np.stack([P[:, 0] / g.rx ** 2, P[:, 1] / g.ry ** 2, np.zeros(len(P))], 1)
        return n / (np.linalg.norm(n, axis=1, keepdims=True) + 1e-9)
    def wdisp(T, V, inside):
        u = u_of(T) * (0.96 if inside else 1.0); vv = V * g.h - v0w * g.h
        i = np.floor(u / SW); j = np.floor(vv / SH)
        fu = u / SW - i; fv = vv / SH - j
        hor = (((i.astype(int) // C['twill']) + j.astype(int)) % 2 == 0)
        fz = np.where(hor, fv, fu); fl = np.where(hor, fu, fv)
        d = AMP * np.sqrt(np.clip(np.sin(np.pi * fz), 0, 1)) * (0.45 + 0.55 * np.sin(np.pi * fl))
        if band > 0:
            d = np.where(V < band, 0.0, d)
        if C.get('logo') and not inside:
            cx = ((T + np.pi / 2 + np.pi) % (2 * np.pi) - np.pi) * g.rx * 0.98
            rr_ = np.hypot(cx / 0.36, (V - 0.55) * g.h / 0.235)
            d = np.where(rr_ < 1.0, 0.016 * np.clip((1.0 - rr_) / 0.08, 0, 1) ** 0.5 + 0.004, d)
        return d
    def outer_d(T, V):
        P = g.outer(T, V); return P + nrm_out(P) * wdisp(T, V, False)[:, None]
    def inner_d(T, V):
        P = g.inner(T, V); return P - nrm_out(P) * wdisp(T, V, True)[:, None]

    def wall_tex(inside):
        pal = C['pal_in'] if inside else C['pal']
        def t(T, V, P, N):
            u = u_of(T) * (0.96 if inside else 1.0); vv = V * g.h - v0w * g.h
            z, i, j, hor, k = weave2(u, vv, SW, SH, None, N, twill=C['twill'])
            pi = pick_pat(C['pat'], i, j, hor, C['nr'])
            col = pals_shade(pal, pi, z, N, rnd(k, 7))
            if inside:
                col = col * np.array([0.95, 0.92, 0.88])
            if band > 0:
                bm = V < band
                col[bm] = band_tex(tier, u[bm], V[bm] * g.h, N[bm], inside, T[bm])
            if C.get('logo') and not inside:
                col = logo(col, T, V, u, N)
            return col
        return t

    def band_tex(tier, u, v, N, inside, T):
        if tier == 3:
            # ván gỗ tràm dựng đứng, thớ dọc, mép ván sẫm; chạm lá dừa nước ở mặt trước
            pw = 0.16; i = np.floor(u / pw); f = u / pw - i
            z = np.full(len(u), 2)
            gr = np.mod(f * 5.3 + 0.35 * np.sin(v * 31 + i * 2.1) + rnd(i, 3), 1.0)
            z = np.where(gr < 0.12, 1, z); z = np.where(gr > 0.82, 3, z)
            z = np.where((f < 0.05) | (f > 0.95), 0, z)
            z = np.where(v > band * g.h - 0.018, np.where(v > band * g.h - 0.008, 3, 1), z)   # nẹp mép trên
            z = np.where(v < 0.02, 1, z)
            pal = TRAM
            if not inside:
                # lá dừa nước chạm nổi: 3 tàu lá nằm ngang, gân giữa + lá chét xiên
                cx = (T + np.pi / 2 + np.pi) % (2 * np.pi) - np.pi
                for c0, fl in ((-0.62, 1), (0.0, -1), (0.62, 1)):
                    du = (cx - c0) * g.rx * fl; dv = v - 0.115
                    L0 = 0.26
                    w = 0.072 * np.sqrt(np.clip(1 - (du / L0) ** 2, 0, 1)) * np.clip((du + L0) / (0.6 * L0), 0, 1)
                    inl = (np.abs(du) < L0) & (np.abs(dv) < w)
                    q = np.mod((du + np.abs(dv) * 0.9) / 0.034, 1.0)
                    leaf = inl & (q < 0.62)
                    zl = np.where(dv > 0, np.where(q < 0.18, 2, 3), np.where(q < 0.18, 1, 2))
                    z = np.where(leaf, zl, np.where(inl, 0, z))
                    rib = (np.abs(dv) < 0.0045) & (du > -L0) & (du < L0 * 1.05)
                    z = np.where(rib, 1, z)
            return shade(pal, z, N) * (1 + 0.05 * (rnd(i, 9) - 0.5))[:, None]
        else:
            # sơn son, 2 chỉ vàng, hoa văn triện
            z = np.full(len(u), 2)
            hb = band * g.h
            col = shade(SON, z, N)
            gl = (np.abs(v - (hb - 0.02)) < 0.007) | (np.abs(v - 0.025) < 0.006)
            mv = (v > 0.04) & (v < hb - 0.035)
            q = np.mod(u, 0.12) / 0.12
            ch = mv & (np.abs(np.abs(q - 0.5) * 2 - (v - 0.04) / (hb - 0.075)) < 0.08)   # chữ V liên hoàn
            zz = np.where(v > hb - 0.012, 3, 2)
            col = shade(SON, zz, N)
            col[gl | ch] = shade(VANG, np.full((gl | ch).sum(), 2), N[gl | ch])
            return col

    def logo(col, T, V, u, N):
        # mặt trước: đĩa sơn son viền vàng, bông sen khảm xà cừ
        cx = ((T + np.pi / 2 + np.pi) % (2 * np.pi) - np.pi) * g.rx * 0.98
        cy = (V - 0.55) * g.h
        ex, ey = cx / 0.36, cy / 0.235
        rr = np.hypot(ex, ey)
        m = rr < 1.0
        if not m.any(): return col
        out = col.copy()
        out[m] = shade(SON, np.where(rr[m] > 0.8, 1, 2), N[m])
        ring = m & (rr > 0.86)
        out[ring] = shade(VANG, np.where(rr[ring] > 0.95, 1, 3), N[ring])
        x, y = ex, ey + 0.05
        def petal(px, py, ang, a, b):
            ca, sa = np.cos(ang), np.sin(ang)
            qx = (x - px) * ca + (y - py) * sa; qy = -(x - px) * sa + (y - py) * ca
            # giọt cánh sen: nhọn đầu
            t = np.clip(qy / b, -1, 1)
            wid = a * np.sqrt(np.clip(1 - t ** 2, 0, 1)) * (1 - 0.85 * np.clip(t, 0, 1) ** 1.5)
            return (np.abs(qx) < wid) & (np.abs(qy) < b), qx, qy
        lay = [(-0.34, -0.06, 0.66, 0.16, 0.42), (0.34, -0.06, -0.66, 0.16, 0.42),
               (-0.16, 0.04, 0.30, 0.17, 0.52), (0.16, 0.04, -0.30, 0.17, 0.52), (0.0, 0.10, 0.0, 0.19, 0.60)]
        for px, py, ang, a, b in lay:
            pm, qx, qy = petal(px, py, -ang, a, b)
            pm &= m & (rr < 0.84)
            zp = np.where(np.abs(qx) < 0.025, 1, np.where(qy > 0.12, 3, 2))
            edge = pm & ~petal(px, py, -ang, a - 0.03, b - 0.03)[0]
            c = shade(NGOC, zp[pm], N[pm]) * 0.35 + shade(SEN, zp[pm], N[pm]) * 0.65
            out[pm] = c
            out[edge] = shade(SEN, np.zeros(edge.sum(), int) + 1, N[edge])
        # đài sen vàng + mặt nước 2 lằn
        core = m & (np.hypot((x) / 2.2, y + 0.33) < 0.075)
        out[core] = shade(VANG, np.full(core.sum(), 3), N[core])
        wv = m & (rr < 0.84) & (np.abs(y + 0.46 + 0.04 * np.sin(x * 14)) < 0.025)
        out[wv] = shade(NGOC, np.full(wv.sum(), 2), N[wv])
        return out

    NT = 7200
    def t_floor(T, V, P, N):
        if tier == 4 or tier == 3:
            a = P[:, 0] / 0.09; b = P[:, 1] / 0.09
            z = np.where(np.mod(a, 1) < 0.08, 0, np.where(np.mod(a, 1) > 0.75, 3, 2))
            return shade(C['pal_in'][0] if tier == 4 else TRAM, z, np.tile(up, (len(a), 1))) * 0.94
        a = (P[:, 0] + P[:, 1]) / 0.07; b = (P[:, 0] - P[:, 1]) / 0.07
        z, i, j, hor, k = weave2(a, b, 1.0, 1.0, None, np.tile(up, (len(a), 1)), gap=0.12, twill=2)
        return pals_shade(C['pal_in'][:1], np.zeros(len(a), int), z, np.tile(up, (len(a), 1)), rnd(k, 5))

    surf(r, g.floor, 0, 2 * np.pi, 0, 1, NT, 260, t_floor, 1)
    surf(r, inner_d, 0, 2 * np.pi, 0.02, 0.93, NT, 700, wall_tex(True), 2, flip=True)
    surf(r, outer_d, 0, 2 * np.pi, 0, 0.94, int(NT * 1.4), 760, wall_tex(False), lambda T, V, P, N: front_id(P, 3, 4))

    # ---- cột gỗ tràm dựng đứng quanh thân (cấp 3)
    if C.get('posts'):
        npo = C['posts']
        for q in range(npo):
            t0 = 2 * np.pi * (q + 0.5) / npo
            def pf(T, V):
                P = g.outer(T, V); n = P.copy(); n[:, 2] = 0
                n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-9
                bulge = 0.026 * np.sqrt(np.clip(1 - ((T - t0) / 0.05) ** 2, 0, 1))
                P = P + n * (0.016 + bulge)[:, None]
                P[:, 2] = np.maximum(P[:, 2], -0.06)
                return P
            def t_post(T, V, P, N):
                f = (T - t0) / 0.05
                gr = np.mod(f * 2.2 + 0.25 * np.sin(V * 23 + q), 1.0)
                z = np.where(f < -0.45, 1, np.where(f > 0.25, 3, 2))
                z = np.where((gr < 0.10) & (np.abs(f) < 0.8), np.minimum(z, 1), z)
                z = np.where(np.abs(f) > 0.88, 0, z)
                # chốt tre đóng xuyên cột vào vành + đế
                pg = ((np.abs(V - 0.86) < 0.025) | (np.abs(V - 0.06) < 0.025)) & (np.abs(f) < 0.32)
                z = np.where(pg, 1, z)
                return shade(TRAM, z, N) * (1 + 0.05 * (rnd(q, 4) - 0.5))
            surf(r, pf, t0 - 0.05, t0 + 0.05, -0.09, 0.97, 200, 700, t_post, lambda T, V, P, N: front_id(P, 9, 10))

    # ---- đai đồng dựng đứng + đinh tán (cấp 4)
    if C.get('straps'):
        for q, t0 in enumerate((np.pi * 0.25, np.pi * 0.75, np.pi * 1.25, np.pi * 1.75)):
            t0 = t0 + 0.0
            def sf(T, V, t0=t0):
                P = g.outer(T, V); n = nrm_out(P)
                return P + n * 0.017
            def t_s(T, V, P, N, t0=t0):
                f = (T - t0) / 0.035
                z = np.where(f < -0.5, 1, np.where(f > 0.35, 3, 2))
                z = np.where(np.abs(f) > 0.86, 0, z)
                rv = (np.abs(np.mod(V * g.h, 0.09) - 0.045) < 0.012) & (np.abs(f) < 0.3)
                c = shade(DONG, z, N); c[rv] = shade(VANG, np.full(rv.sum(), 3), N[rv]); return c
            surf(r, sf, t0 - 0.035, t0 + 0.035, 0.18, 0.95, 160, 600, t_s, lambda T, V, P, N: front_id(P, 9, 10))

    # ---- vành
    RR = {'tre': 0.058, 'hun': 0.06, 'go': 0.066, 'son': 0.062}[C['rim']]
    def rim_tex(kind, off=0.0):
        def t(T, V, P, N):
            u = u_of(T)
            z = np.where(np.cos(V) > 0.3, 3, 2); z = np.where(np.sin(V) < -0.5, 1, z)
            if kind in ('tre', 'hun'):
                nd = np.mod(u + 0.2 + off, 0.62)
                z = np.where(nd < 0.012, 1, np.where(nd < 0.022, 3, z))
                cb = shade(VANH if kind == 'tre' else HUN2, z, N)
                grp = np.mod(u + off * 0.5, 0.36) < 0.13
                q = np.mod(u / 0.0325 + V / (2 * np.pi) * 0.6, 1.0)
                bind = grp & (q < 0.80)
                zq = np.where(q < 0.22, 1, np.where(q > 0.55, 3, 2))
                cm = shade(MAY, zq, N)
                return np.where(bind[:, None], cm, cb)
            if kind == 'go':
                gr = np.mod(u * 9 + 0.3 * np.sin(u * 40), 1.0)
                z = np.where(gr < 0.1, np.minimum(z, 1), z)
                cb = shade(TRAM, z, N)
                grp = np.mod(u, 0.5) < 0.10
                q = np.mod(u / 0.03 + V / (2 * np.pi) * 0.6, 1.0)
                bind = grp & (q < 0.8)
                cm = shade(MAY2, np.where(q < 0.22, 1, np.where(q > 0.55, 3, 2)), N)
                return np.where(bind[:, None], cm, cb)
            # sơn son + chỉ vàng trên đỉnh + hạt đồng
            cb = shade(SON, z, N)
            gold = np.abs(np.sin(V) - 0.98) < 0.03
            cb[gold] = shade(VANG, np.full(gold.sum(), 3), N[gold])
            st = (np.mod(u, 0.22) < 0.022) & (np.cos(V) > 0.55)
            cb[st] = shade(DONG, np.full(st.sum(), 3), N[st])
            return cb
        return t

    def rid(T, V, P, N): return front_id(P, 5, 6)
    if C['rim'] == 'tre2':
        surf(r, lambda T, V: g.rim(T, V, rr=RR), 0, 2 * np.pi, 0, 2 * np.pi, NT * 2, 420, rim_tex('tre'), rid)
        kk = g.kz(np.ones(1))[0] - 0.5 * g.th / g.ry
        def rim2(T, V):
            P = g.rim(T, V, rr=RR * 0.8, k0=kk + 0.09); P[:, 2] -= 0.075; return P
        surf(r, rim2, 0, 2 * np.pi, 0, 2 * np.pi, NT * 2, 360, rim_tex('tre2', 0.18), rid)
    elif C['rim'] in ('go', 'son'):
        def rimf(T, V):
            u = u_of(T)
            bind = (np.mod(u, 0.5) < 0.10) if C['rim'] == 'go' else np.zeros(len(u), bool)
            P = g.rim(T, V, rr=RR + 0.007 * bind); P[:, 2] = g.h + (P[:, 2] - g.h) * 0.8; return P
        surf(r, rimf, 0, 2 * np.pi, 0, 2 * np.pi, NT * 2, 420, rim_tex(C['rim']), rid)
    else:
        def rimb(T, V):
            u = u_of(T)
            bind = np.mod(u, 0.36) < 0.13
            return g.rim(T, V, rr=RR + 0.007 * bind)
        surf(r, rimb, 0, 2 * np.pi, 0, 2 * np.pi, NT * 2, 420, rim_tex(C['rim']), rid)

    # ---- đế
    fpal = {'tre': VANH, 'hun': HUN2, 'go': TRAM, 'son': SON}[C['foot']]
    def footf(T, V):
        k = g.fb + 0.01
        x, y = g.ring(T, k)
        return np.stack([x * (1 + 0.05 * np.cos(V) / g.rx), y * (1 + 0.05 * np.cos(V) / g.ry * 0.6), 0.03 + 0.042 * np.sin(V)], 1)
    def t_foot(T, V, P, N):
        z = np.where(np.cos(V) > 0.5, 2, np.where(np.sin(V) < -0.3, 0, 1))
        z = np.where(np.sin(V) > 0.75, 3, z)
        u = u_of(T)
        if C['foot'] in ('tre', 'hun'):
            q = np.mod(u, 0.30) < 0.05                       # mây buộc đế
            c = shade(fpal, z, N); c[q] = shade(MAY, np.clip(z[q] + 1, 0, 3), N[q]); return c
        if C['foot'] == 'go':
            gr = np.mod(u * 7 + 0.4 * np.sin(u * 23), 1.0) < 0.1
            z = np.where(gr, np.maximum(z - 1, 0), z)
        if C['foot'] == 'son':
            gl = np.abs(np.sin(V) - 0.2) < 0.12
            c = shade(fpal, z, N); c[gl] = shade(VANG, np.full(gl.sum(), 2), N[gl]); return c
        return shade(fpal, z, N)
    surf(r, footf, 0, 2 * np.pi, 0, 2 * np.pi, NT, 240, t_foot, lambda T, V, P, N: front_id(P, 3, 4))
    if tier == 4:
        # 4 chân quỳ sơn son bịt đồng
        for th0 in (np.pi * 0.25, np.pi * 0.75, np.pi * 1.25, np.pi * 1.75):
            x0, y0 = g.ring(np.array([th0]), g.fb * 0.92)
            def leg(T, V, x0=x0[0], y0=y0[0]):
                rr = 0.05 * (1 - 0.35 * V)
                return np.stack([x0 + rr * np.cos(T), y0 + rr * np.sin(T) * 0.9, -0.07 * V + 0.02], 1)
            def t_leg(T, V, P, N):
                z = np.where(np.cos(T + 2.3) > 0.3, 3, 2)
                c = shade(SON, z, N)
                b = V > 0.7
                c[b] = shade(DONG, z[b], N[b])
                return c
            surf(r, leg, 0, 2 * np.pi, 0, 1, 600, 120, t_leg, lambda T, V, P, N: front_id(P, 3, 4))

    # ---- quai 2 bên (chỉ lớp sau)
    if C['handle']:
        hp = {'may': MAY2, 'go': TRAM, 'dong': DONG}[C['handle']]
        for side in (0.0, np.pi):
            xr, yr = g.ring(np.array([side]), g.kz(np.ones(1))[0])
            sx = np.sign(np.cos(side))
            def hdl(T, V, xr=xr[0], sx=sx):
                # T: góc vòng quai (0..pi), V: góc ống
                R0 = {'may': 0.17, 'go': 0.17, 'dong': 0.16}[C['handle']]
                rr = {'may': 0.034, 'go': 0.04, 'dong': 0.03}[C['handle']]
                end = (T < 0.42) | (T > np.pi - 0.42)
                rr = rr + 0.008 * end
                if False:
                    cx = xr + sx * (R0 + 0.012); cz = g.h - 0.24
                    a = T * 2
                    px = cx + R0 * np.cos(a); pz = cz + R0 * np.sin(a)
                    nx, nz = np.cos(a), np.sin(a)
                    return np.stack([px + rr * np.cos(V) * nx, rr * np.sin(V) + 0.0 * px, pz + rr * np.cos(V) * nz], 1)
                cx = xr - sx * 0.01; cz = g.h - 0.12
                px = cx + sx * R0 * np.sin(T) - sx * 0.05 * (1 - np.cos(T)) / 2; pz = cz + R0 * np.cos(T) * 0.8
                nx, nz = sx * np.sin(T), np.cos(T)
                return np.stack([px + rr * np.cos(V) * nx, rr * np.sin(V) + 0.0 * px, pz + rr * np.cos(V) * nz], 1)
            def t_h(T, V, P, N):
                z = np.where(np.cos(V) > 0.3, 3, np.where(np.cos(V) < -0.5, 1, 2))
                end = (T < 0.42) | (T > np.pi - 0.42)
                if C['handle'] == 'may':
                    q = np.mod(T * 30 + V / (2 * np.pi), 1.0)
                    z = np.where(q < 0.2, 1, z)
                if C['handle'] == 'go':
                    gr = np.mod(T * 8 + 0.3 * np.sin(V), 1.0) < 0.1
                    z = np.where(gr, np.minimum(z, 1), z)
                c = shade(hp, z, N)
                q2 = np.mod(T * 70 + V / (2 * np.pi), 1.0)
                zb = np.where(q2 < 0.25, 1, np.where(q2 > 0.6, 3, 2))
                bp = DONG if C['handle'] == 'dong' else MAY
                if C['handle'] == 'dong':
                    zb = np.where(np.abs(T - 0.21) < 0.04, 1, np.where(np.cos(V) > 0.3, 3, 2))
                    zb = np.where(np.abs(T - (np.pi - 0.21)) < 0.04, 1, zb)
                    bp = VANG
                c[end] = shade(bp, zb[end], N[end])
                return c
            tmax = np.pi if C['handle'] == 'dong' else np.pi
            surf(r, hdl, 0, tmax, 0, 2 * np.pi, 1500, 160, t_h, 7)
            if False:
                # tai đồng gắn quai
                R0e = 0.10
                def ear(T, V, xr=xr[0], sx=sx, R0e=R0e):
                    return np.stack([np.full_like(T, xr + sx * 0.008), 0.05 * np.cos(T) * V, g.h - 0.24 + R0e + 0.05 * np.sin(T) * V], 1)
                surf(r, ear, 0, 2 * np.pi, 0, 1, 400, 60, lambda T, V, P, N: shade(DONG, np.where(V > 0.8, 1, np.where(np.sin(T) > 0.3, 3, 2)), N * 0 + np.array([sx, 0, 0.3]) / 1.044), 7)
    return r


def finish(r, ss):
    W, H = r.W, r.H
    a = np.isfinite(r.z).reshape(H, W)
    c = r.c.reshape(H, W, 3); oid = r.id.reshape(H, W)
    # viền: mép bóng + mép giữa vật khác nhau (đậm cùng màu)
    def edge(mask_in, step):
        e = np.zeros_like(mask_in)
        for dy in range(-step, step + 1):
            for dx in range(-step, step + 1):
                if dx * dx + dy * dy > step * step: continue
                e |= ~np.roll(np.roll(mask_in, dy, 0), dx, 1)
        return e & mask_in
    K = W / 1400.0
    ol = edge(a, max(1, int(round(4 * K))))
    zz = r.z.reshape(H, W)
    dz = np.zeros_like(a)
    for sh in ((0, 1), (1, 0)):
        z2 = np.roll(np.roll(zz, sh[0], 0), sh[1], 1); o2 = np.roll(np.roll(oid, sh[0], 0), sh[1], 1)
        brk = (np.abs(zz - z2) > 0.06) & np.isfinite(zz) & np.isfinite(z2)
        dz |= brk | ((o2 != oid) & np.isfinite(z2) & ((o2 // 2) != (oid // 2)))
    # bỏ chấm lẻ (vết z lẻ tẻ) trước khi nở viền
    nb = sum(np.roll(np.roll(dz.astype(np.int8), dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
    dz &= nb >= 2
    nb = sum(np.roll(np.roll(dz.astype(np.int8), dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
    dz &= nb >= 2
    # nở viền trong 1*ss
    dz2 = dz.copy()
    for k in range(max(1, int(round(2 * K)))):
        dz2 |= np.roll(dz2, 1, 0) | np.roll(dz2, 1, 1)
    out = c.copy()
    deep = c * np.array([0.62, 0.52, 0.40])     # cùng hue nâu-vàng đậm
    out[ol | (dz2 & a)] = deep[ol | (dz2 & a)]
    rgba = np.dstack([np.clip(out, 0, 255), a * 255.0])
    return rgba, oid


def save(rgba, oid, mask, path, ss):
    im = rgba.copy(); im[~mask, 3] = 0
    img = Image.fromarray(im.astype(np.uint8), 'RGBA')
    if ss > 1:
        img = img.resize((img.width // ss, img.height // ss), Image.LANCZOS)
    bb = img.getbbox(); return img, bb


if __name__ == '__main__':
    out, tier = sys.argv[1], int(sys.argv[2])
    W = int(sys.argv[3]) if len(sys.argv) > 3 else 700
    import os
    SS = int(os.environ.get('GT_SS', '2'))
    DENS = W * SS / 1400.0
    r = build(tier, W * SS)
    rgba, oid = finish(r, SS)
    a = rgba[..., 3] > 0
    front = a & (oid % 2 == 0) & (oid >= 4)
    import os; os.makedirs(out, exist_ok=True)
    full, bb = save(rgba, oid, a, None, SS)
    fr, _ = save(rgba, oid, front, None, SS)
    # khung cố định chung 4 cấp (cùng kích thước, cùng vị trí)
    bb = (int(W * 0.06), int(W * 0.10), int(W * 0.94), int(W * 0.58))
    full.crop(bb).save(f'{out}/gio{tier}_sau.png'); fr.crop(bb).save(f'{out}/gio{tier}_truoc.png')
    print('ok', bb)
