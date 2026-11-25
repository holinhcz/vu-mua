# Rương mở quà 4 bậc — MÔ HÌNH 3D THẬT dựng bằng đúng bộ vẽ công trình/xưởng của game (kho3d, như bè nổi)
# Link 11-25 "đổi cách vẽ, chi tiết từng điểm ảnh / đéo dựng 3D lên mà vẽ à": mọi gờ, đai, chạm nổi là khối thật; vật liệu tô từng điểm ảnh.
#   python3 ruong_k.py prev OUT.png TIER [ROT_DEG]
import math, sys, os
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
for d in ('lobanh', 'coixay', 'lobanhmi', 'chuongga', 'benghe', 'kho'):
    sys.path.insert(0, os.path.join(HERE, '..', d))
import lobanh3d as LQ
import coixay3d as CX
import chuongga3d as CG
import kho3d as K
from kho3d import (T, Scene, X3, hexc, smooth, vnoise, hash1, tube, disc, MATS, M_BAMBOO, M_OLDBAMBOO, M_RATTAN, M_WOOD)
from kho3d import weave_tex, bump

M_TRAM, M_TCUT, M_ROPE = CG.M_TRAM, CG.M_TCUT, CG.M_ROPE

K.BB = (-34, -30, 34, 36)
K.OX, K.OY = 0, 0
K.SEED = 4401
K.PXU = int(os.environ.get('RG_PXU', '9'))
K.GS_K, K.FOOT_K = 0.22, 0.16
K.GROUND_SHADOW = True
K.NOSHADOW = set()
K.PATCH = None
K.ZF = 0.0
K.INSIDE_K = 0.3
C0 = 0.5 * T                       # tâm rương (đơn vị game), giữa ô
TIER = 1
ROT = 0.0                          # xoay quanh trục đứng (độ) để xem mô hình nhiều góc


def rot(p):
    p = np.asarray(p, float); a = math.radians(ROT); c, s = math.cos(a), math.sin(a)
    x, y = p[..., 0] - C0, p[..., 1] - C0
    return np.stack([C0 + c * x - s * y, C0 + s * x + c * y, p[..., 2]], -1)


def Pl(x, y, z):                   # toạ độ rương (x dọc thân, y ra trước, z lên) -> thế giới
    return rot(np.array([C0 + x, C0 + y, z], float))


def loc(pos):                      # thế giới -> toạ độ rương
    a = -math.radians(ROT); c, s = math.cos(a), math.sin(a)
    x, y = pos[:, 0] - C0, pos[:, 1] - C0
    return c * x - s * y, s * x + c * y, pos[:, 2]


# ------------------------------------------------------------------ vật liệu
def mat_dan(uv, prm, pos, nrm):
    """tre đan lóng mốt (đúng weave_tex của vách xưởng), toạ độ lấy theo mặt rương: 0 trước/sau, 1 hông, 2 nắp cong"""
    x, y, z = loc(pos); f = prm[:, 0]
    a = np.where(f < 0.5, x, y); b = z
    a = np.where(f > 1.5, x, a)
    b = np.where(f > 1.5, LR * np.arctan2(z - ZL, y) * 1.0, b)
    a = np.where(f > 2.5, np.arctan2(y, x) * 9.0, a)
    col, n = weave_tex(a, b, [1.0], np.array([1.0, 0, 0]), np.array([0, 0, 1.0]), nrm, cell=1.2)
    col = col * (1 + 0.25 * np.clip(1 - b / 6, 0, 1))[:, None]          # weave_tex sẫm chân vách; rương không có đất bắn
    return np.clip(col * TINT[None], 0, 1), n


def mat_go(uv, prm, pos, nrm):
    """gỗ chạm (bảng sen, chốt): thớ gỗ mịn chạy theo trục a, mỗi miếng 1 tông, mép sáng"""
    x, y, z = loc(pos)
    a = x * prm[:, 1] + z * (1 - prm[:, 1])
    g = 0.88 + 0.1 * vnoise(a * 0.5 + prm[:, 0] * 9, (y + x + z) * 3.0, 2.0) + 0.05 * np.sin(a * 0.4 + (z + y) * 7 + vnoise(a * 0.3, z, 4.0) * 5)
    base = hexc(GOC)[None] * g[:, None] * (0.94 + 0.12 * prm[:, 0])[:, None]
    return np.clip(base, 0, 1), nrm


def mat_mo(uv, prm, pos, nrm):
    """mặt gỗ cưa ngang làm bảng đề (vòng tuổi nhạt, không nứt tối)"""
    r = uv[:, 0]; th = uv[:, 1]; sd = prm[:, 0]
    wob = vnoise(th * 5 + sd * 9, sd * 3, 2.0) * 0.05; rr = r + wob
    heart = hexc('#c89058'); sap = hexc('#e8c88e')
    base = heart[None] + (sap - heart)[None] * smooth(0.3, 0.7, rr)[:, None]
    base = base * (0.95 + 0.05 * np.sin(rr * 34))[:, None]
    bark = rr > 0.93
    base = np.where(bark[:, None], hexc('#7a5030')[None] * np.ones_like(base), base)
    return np.clip(base, 0, 1), nrm


M_DAN, M_GO, M_MO = 950, 951, 952
MATS.update({M_DAN: mat_dan, M_GO: mat_go, M_MO: mat_mo})
TINT = np.array([1.0, 1.0, 1.0]); GOC = '#b8783c'; WOODC = '#b8743c'


# ------------------------------------------------------------------ hình khối
def grid(S, F, nu, nv_, mat, prm, close_v=False, flip=True):
    S.grid(lambda U, V: rot(F(U, V) + np.array([C0, C0, 0.0])), nu, nv_, mat, prm, 0.0, uvr=((0, 1), (0, 1)), close_v=close_v, flip=flip)


def tb(S, a, b, r, mat, prm=(0, 0, 0), nr=8, nl=4, cap=False):
    pa, pb = Pl(*a), Pl(*b)
    (CX.ctube if cap else tube)(S, pa, pb, r, mat, prm=prm, nr=nr, nl=nl)


def arc(S, x, R, r, mat, prm=(0, 0, 0), n=18, nr=7, th0=0.0, th1=math.pi):
    pts = [(x, R * math.cos(t), ZL + R * math.sin(t)) for t in np.linspace(th0, th1, n)]
    for p0, p1 in zip(pts, pts[1:]): tb(S, p0, p1, r, mat, prm, nr=nr, nl=2)


def ell(S, c, rx, ry, rz, mat, prm=(0, 0, 0), axes=None, nu=8, nv_=12):
    ax = axes or (np.array([1.0, 0, 0]), np.array([0, 1.0, 0]), np.array([0, 0, 1.0]))
    a = math.radians(ROT); R_ = np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])
    X3.ellipsoid(S, Pl(*c), rx, ry, rz, mat, prm, axes=tuple(R_ @ np.asarray(v, float) for v in ax), nu=nu, nvv=nv_)


def body_dan(S):
    """thân hộp tre đan: 4 vách + đáy; nắp vòm nửa trụ tre đan, 2 đầu nắp nửa tròn"""
    a, b, h = LA, LB, ZL
    grid(S, lambda U, V: np.stack([-a + 2 * a * U, -b + 2 * b * V, np.full_like(U, 0.6)], -1), 12, 8, M_DAN, (0, 0, 0))
    grid(S, lambda U, V: np.stack([-a + 2 * a * U, np.full_like(U, b), h * V], -1), 30, 14, M_DAN, (0, 0, 0))
    grid(S, lambda U, V: np.stack([np.full_like(U, a), b - 2 * b * U, h * V], -1), 20, 14, M_DAN, (1, 0, 0))
    grid(S, lambda U, V: np.stack([a - 2 * a * U, np.full_like(U, -b), h * V], -1), 30, 14, M_DAN, (0, 0, 0))
    grid(S, lambda U, V: np.stack([np.full_like(U, -a), -b + 2 * b * U, h * V], -1), 20, 14, M_DAN, (1, 0, 0))
    def lid(U, V):
        t = V * math.pi
        return np.stack([-a + 2 * a * U, LR * np.cos(t), ZL + LR * np.sin(t)], -1)
    grid(S, lid, 30, 24, M_DAN, (2, 0, 0))
    for sx in (1, -1):
        def end(U, V, sx=sx):
            t = V * math.pi
            return np.stack([np.full_like(U, sx * a), U * LR * np.cos(t), ZL + U * LR * np.sin(t)], -1)
        grid(S, end, 8, 20, M_DAN, (1, 0, 0), flip=(sx < 0))


def frame_tre(S, rng):
    """khung tre già: 4 cột góc, viền đáy, viền miệng, viền 2 đầu nắp + mép nắp; buộc mây ở mỗi mối"""
    a, b, rb = LA, LB, 1.05
    for sx in (1, -1):
        for sy in (1, -1):
            tb(S, (sx * a, sy * b, -0.2), (sx * a, sy * b, ZL + 0.3), rb, M_OLDBAMBOO, (rng.random(), rng.random(), 0), nl=6, cap=True)
    for z in (rb * 0.9, ZL - 0.2):
        for sy in (1, -1): tb(S, (-a - 1.1, sy * b, z), (a + 1.1, sy * b, z), rb * 0.92, M_BAMBOO, (rng.random(), rng.random(), 0), nl=10, cap=True)
        for sx in (1, -1): tb(S, (sx * a, -b - 1.1, z), (sx * a, b + 1.1, z), rb * 0.92, M_BAMBOO, (rng.random(), rng.random(), 0), nl=8, cap=True)
    tb(S, (-a, 0, ZL - 0.2), (a, 0, ZL - 0.2), 0.01, M_BAMBOO)
    for sx in (1, -1): arc(S, sx * a, LR + 0.2, rb * 0.9, M_BAMBOO, (rng.random(), 0.3, 0), n=20)
    for sy in (1, -1): tb(S, (-a - 0.9, sy * (LR + 0.3), ZL + 1.0), (a + 0.9, sy * (LR + 0.3), ZL + 1.0), rb * 0.8, M_BAMBOO, (rng.random(), 0.6, 0), nl=10, cap=True)
    for th in (0.85, math.pi - 0.85):                               # 2 nẹp dọc lưng nắp
        R = LR + 0.25
        tb(S, (-a, R * math.cos(th), ZL + R * math.sin(th)), (a, R * math.cos(th), ZL + R * math.sin(th)), 0.6, M_BAMBOO, (rng.random(), 0.1, 0), nl=10)
    for sx in (1, -1):                                              # mối buộc mây ở 8 góc
        for sy in (1, -1):
            for z in (rb * 0.9, ZL - 0.2):
                for k in range(3):
                    ell(S, (sx * a, sy * b, z - 0.6 + 0.6 * k), 1.35, 1.35, 0.35, M_ROPE, nu=4, nv_=10)
    # 2 đai mây quấn quanh thân + nắp (mỗi đai 3 sợi bện)
    for x0 in (-a * 0.55, a * 0.55):
        for j in range(3):
            x = x0 + (j - 1) * 0.5
            arc(S, x, LR + 0.45, 0.32, M_RATTAN, n=26, nr=5)
            for sy in (1, -1): tb(S, (x, sy * (b + 0.4), ZL + 0.2), (x, sy * (b + 0.4), 0.3), 0.32, M_RATTAN, nr=5, nl=2)


def sen_go(S, rng, c, s):
    """LOGO SEN chạm gỗ nổi thật: bảng gỗ tròn (mặt cưa), 7 cánh sen khối, 2 lá đế, gương sen; buộc mây vào nắp"""
    cx, cy, cz = c
    disc(S, Pl(cx, cy + 0.9, cz), rotv((0, 1, 0)), s * 1.45, M_MO, (rng.random(), 0, 0), nr=4, na=36)
    tube(S, Pl(cx, cy - 0.1, cz), Pl(cx, cy + 0.9, cz), s * 1.45, M_GO, prm=(0.3, 0, 0), nr=36, nl=2)
    base = np.array([cx, cy + 1.1, cz - s * 0.55])
    for ang, ln_, w in ((0, 1.0, 0.3), (26, 0.92, 0.27), (-26, 0.92, 0.27), (52, 0.78, 0.24), (-52, 0.78, 0.24), (80, 0.58, 0.2), (-80, 0.58, 0.2)):
        t = math.radians(ang); d = np.array([math.sin(t), 0, math.cos(t)]); pp = np.array([math.cos(t), 0, -math.sin(t)])
        cc = base + d * s * ln_ * 0.55 + np.array([0, 0.25 * s * (1 - abs(ang) / 90), 0])
        ell(S, tuple(cc), s * ln_ * 0.55, s * w, s * 0.2, M_GO, (rng.random(), 0, 0), axes=(d, pp, np.array([0, 1.0, 0])))
    for sx in (1, -1):
        d = np.array([sx, 0, 0.25]) / math.hypot(1, 0.25); pp = np.array([-0.25 * sx, 0, 1]) / math.hypot(1, 0.25)
        ell(S, tuple(base + np.array([sx * s * 0.62, 0.15, -s * 0.15])), s * 0.6, s * 0.16, s * 0.16, M_GO, (rng.random(), 1, 0), axes=(d, pp, np.array([0, 1.0, 0])))
    ell(S, tuple(base + np.array([0, 0.5, s * 0.15])), s * 0.22, s * 0.16, s * 0.2, M_GO, (0.9, 0, 0))
    for sz in (1, -1):                                              # mây buộc bảng
        tb(S, (cx, cy + 0.6, cz + sz * s * 1.35), (cx, cy + 0.4, cz + sz * s * 1.8), 0.35, M_RATTAN, nr=5, nl=2)


def rotv(v):
    a = math.radians(ROT); x, y, z = v
    return (math.cos(a) * x - math.sin(a) * y, math.sin(a) * x + math.cos(a) * y, z)


# ================================================================== bộ chung cho bậc 2-4 (v2 11-25 Link "Làm")
def face_ab(pos, f):
    """toạ độ trên mặt (đơn vị game): 0 trước/sau a=x b=z, 1 hông a=y b=z, 2 nắp a=x b=cung"""
    x, y, z = loc(pos)
    a = np.where(f < 0.5, x, y); b = z.copy()
    a = np.where(f > 1.5, x, a)
    b = np.where(f > 1.5, ZL + LR * np.arctan2(z - ZL, np.where(np.abs(y) < 1e-6, 1e-6, y)) * 0 + LR * (math.pi / 2 - np.arctan2(y, np.maximum(z - ZL, 1e-6))) , b)
    return a, b, x, y, z


def mat_van(uv, prm, pos, nrm):
    """ván gỗ tràm ghép ngang: mỗi ván 1 tông, thớ gỗ chạy dọc ván (vân sáng/tối nhẹ, uốn quanh mắt), khe ván"""
    a, b, x, y, z = face_ab(pos, prm[:, 0])
    pw = 2.5; iv = np.floor(b / pw); fv = b / pw - iv
    h = hash1(iv, prm[:, 0] * 3 + 1, 4.0)
    g = vnoise(a * 0.15 + h * 9, b * 2.4, 2.0)
    vein = 0.5 + 0.5 * np.sin(b * 11 + g * 5 + a * 0.08 + h * 6)
    base = hexc(WOODC)[None] * ((0.84 + 0.24 * h) * (0.93 + 0.1 * vein) * (0.95 + 0.06 * vnoise(a * 2.5, b * 9, 7.0)))[:, None]
    gap = smooth(0.0, 0.06, fv) * smooth(1.0, 0.94, fv)
    base = base * (0.55 + 0.45 * gap)[:, None]
    s_ = (fv - 0.5) * 2
    n = bump(nrm, np.array([[0, 0, 1.0]]), -s_, 0.18)
    return np.clip(base, 0, 1), n


def edge_w(pos):
    """độ gần cạnh/góc của thân + nắp (0 giữa mặt, 1 sát cạnh) để làm mòn cạnh"""
    x, y, z = loc(pos)
    dx = LA - np.abs(x); dz0 = z; dzl = np.abs(z - ZL)
    r = np.hypot(y, np.maximum(z - ZL, 0)); dl = np.where(z > ZL, np.abs(r - LR) + np.abs(np.abs(y) - 0) * 0, 9)
    dy = LB - np.abs(y)
    d = np.minimum.reduce([dx + np.where(z > ZL, 0, np.maximum(dy, 0)) * 0 + np.minimum(dx, 9), np.where(z <= ZL, np.minimum(dy, dx) + np.minimum(dz0, dzl) * 0 + 9 * 0, 9) + np.minimum(np.minimum(dz0, dzl), 9) * 0 + 0])
    e1 = np.minimum(dx, dy); e2 = np.minimum(np.minimum(dz0, dzl), np.minimum(dx, dy) + 9 * (z > ZL))
    e = np.minimum(e1 + 9 * (z > ZL), e2)
    e = np.minimum(e, np.where(z > ZL, dx, 9))
    return smooth(1.6, 0.0, e)


def metal_sheen(col, nrm, pos, amt=1.0):
    """kim loại thật: sáng loá ở chỗ quay về đèn, tối sâu ở chỗ quay đi (phản chiếu), không phải màu sơn đều"""
    h = np.clip(nrm @ K.HALF, 0, 1); up = np.clip(nrm[:, 2], -1, 1)
    sp = h ** 18 * 0.9 + h ** 4 * 0.25
    dk = 0.72 + 0.28 * (0.5 + 0.5 * up)
    c = col * dk[:, None] * (1 - 0.15 * amt) + (np.array([1.0, 0.96, 0.86])[None] * sp[:, None]) * amt
    return c


def mat_kl(col, hammer=True, streak=0.05, leaf=False):
    c = hexc(col)
    def f(uv, prm, pos, nrm):
        x, y, z = loc(pos)
        t = 0.95 + streak * np.sin((x + y) * 9 + z * 3) * 0.5
        if hammer:                                   # mặt kim loại rèn: từng vết búa tròn nhỏ (đổi tông nhẹ, không vệt tối)
            cx = np.floor((x + y) / 0.9); cz = np.floor(z / 0.9)
            t = t * (0.94 + 0.12 * hash1(cx, cz, 5.0))
        cc = c[None] * t[:, None]
        if leaf:                                     # vàng thếp: từng lá vàng vuông dán chồng, lá nào hơi lệch tông
            ix = np.floor((x + 0.3 * z) / 1.3); iz = np.floor((z + 0.3 * y) / 1.3)
            hv = hash1(ix, iz, 7.0)
            cc = cc * (0.92 + 0.14 * hv)[:, None] + np.array([0.04, 0.02, -0.03])[None] * (hv[:, None] - 0.5)
        if not EXPORT: cc = metal_sheen(cc, nrm, pos)
        return np.clip(cc, 0, 1), nrm
    f.kind = 'kl'
    return f


def mat_son(col, wood=True):
    """sơn ta cũ trên gỗ: màu sơn xỉn ngả nâu, thớ gỗ nổi dưới sơn, vệt cọ, cạnh hay chạm tay mòn mỏng sáng ra"""
    c = hexc(col); old = c * 0.78 + hexc('#6a4a30') * 0.22
    def f(uv, prm, pos, nrm):
        a, b, x, y, z = face_ab(pos, prm[:, 0])
        iv = np.floor(b / 2.5); hv = hash1(iv, 3.0, 2.0)
        grain = 0.5 + 0.5 * np.sin(b * 13 + vnoise(a * 0.2 + iv, b * 2, 3.0) * 6 + a * 0.05)
        brush = 0.5 + 0.5 * np.sin(a * 2.2 + vnoise(a * 0.5, b * 4, 6.0) * 5)
        br = (0.9 + 0.08 * hv) * (0.95 + 0.07 * grain) * (0.97 + 0.04 * brush)
        cc = old[None] * br[:, None]
        e = edge_w(pos) * (0.55 + 0.45 * vnoise(x * 0.8 + y * 0.8, z * 0.8, 4.0))
        worn = c * 0.6 + hexc('#c8a070') * 0.4                # sơn mòn mỏng: lộ lớp lót vàng nâu nhạt (sáng hơn, không vệt tối)
        cc = cc * (1 - 0.7 * e)[:, None] + worn[None] * (0.7 * e)[:, None]
        return np.clip(cc, 0, 1), nrm
    f.kind = 'son'
    return f


def mat_xacu(col):
    c = hexc(col); pearl = hexc('#f2ece0'); pink = hexc('#f0c6d4'); mint = hexc('#c6e8da')
    base_f = mat_son(col)
    def f(uv, prm, pos, nrm):
        cc, n = base_f(uv, prm, pos, nrm)
        a, b, x, y, z = face_ab(pos, prm[:, 0])
        cu = 6.4; uu = a / cu; vv = b / cu; row = np.floor(vv); uu = uu + 0.5 * (row % 2)
        du = ((uu % 1.0) - 0.5) * cu; dv = ((vv % 1.0) - 0.5) * cu
        pa = np.arctan2(dv, du); pr = np.hypot(du, dv)
        pet = (pr < 1.25 * (0.4 + 0.6 * np.abs(np.cos(pa * 2.5)))) & (pr > 0.32)
        dot = pr < 0.24
        w = 0.5 + 0.5 * np.sin(x * 1.3 + z * 0.9 + y)
        pc = pearl[None] * (1 - 0.3 * w)[:, None] + pink[None] * (0.18 * w)[:, None] + mint[None] * (0.12 * (1 - w))[:, None]
        ins = prm[:, 1] > 0.5
        cc = np.where((pet & ins)[:, None], pc, cc)
        cc = np.where((dot & ins)[:, None], hexc('#e8b444')[None] * np.ones_like(cc), cc)
        return np.clip(cc, 0, 1), n
    f.kind = 'son'
    return f


_MID = [960]
KIND = {M_DAN: 'go', M_GO: 'go', M_MO: 'go'}
EXPORT = False
def newmat(fn, kind=None):
    m = _MID[0]; _MID[0] += 1; MATS[m] = fn
    KIND[m] = kind or getattr(fn, 'kind', 'go'); return m


def obx(S, o, a, b, c, mat, prm=(0, 0, 0)):
    K.obox(S, Pl(*o), rotv(a), rotv(b), rotv(c), mat, prm)


def bar(S, p0, p1, nrm, w, h, mat, prm=(0, 0, 0)):
    """thanh vuông cạnh sắc từ p0 tới p1 (toạ độ rương), nằm trên mặt có pháp tuyến nrm, rộng 2w, nổi h"""
    p0 = np.asarray(p0, float); p1 = np.asarray(p1, float); d = p1 - p0; L = np.linalg.norm(d)
    if L < 1e-6: return
    t = d / L; n = np.asarray(nrm, float); n = n - t * np.dot(n, t); n = n / np.linalg.norm(n); s_ = np.cross(n, t)
    o = p0 - s_ * w - t * w * 0.5
    obx(S, tuple(o), tuple(t * (L + w)), tuple(s_ * 2 * w), tuple(n * h), mat, prm)


def arc_bar(S, x, w, h, mat, prm=(0, 0, 0), n=20, R=None):
    R = R or LR
    ts = np.linspace(0, math.pi, n)
    for t0, t1 in zip(ts, ts[1:]):
        p0 = np.array([x, R * math.cos(t0), ZL + R * math.sin(t0)]); p1 = np.array([x, R * math.cos(t1), ZL + R * math.sin(t1)])
        tm = (t0 + t1) / 2
        bar(S, p0, p1, (0, math.cos(tm), math.sin(tm)), w, h, mat, prm)


def box_body(S, mat_wall, lidmat=None, prm1=0.0):
    a, b, h = LA, LB, ZL
    lm = lidmat or mat_wall
    grid(S, lambda U, V: np.stack([-a + 2 * a * U, -b + 2 * b * V, np.full_like(U, 0.6)], -1), 12, 8, mat_wall, (0, 0, 0))
    grid(S, lambda U, V: np.stack([-a + 2 * a * U, np.full_like(U, b), h * V], -1), 30, 16, mat_wall, (0, prm1, 0))
    grid(S, lambda U, V: np.stack([np.full_like(U, a), b - 2 * b * U, h * V], -1), 20, 16, mat_wall, (1, prm1, 0))
    grid(S, lambda U, V: np.stack([a - 2 * a * U, np.full_like(U, -b), h * V], -1), 30, 16, mat_wall, (0, prm1, 0))
    grid(S, lambda U, V: np.stack([np.full_like(U, -a), -b + 2 * b * U, h * V], -1), 20, 16, mat_wall, (1, prm1, 0))
    grid(S, lambda U, V: np.stack([-a + 2 * a * U, LR * np.cos(V * math.pi), ZL + LR * np.sin(V * math.pi)], -1), 30, 28, lm, (2, prm1, 0))
    for sx in (1, -1):
        def end(U, V, sx=sx):
            t = V * math.pi
            return np.stack([np.full_like(U, sx * a), U * LR * np.cos(t), ZL + U * LR * np.sin(t)], -1)
        grid(S, end, 8, 22, lm, (1, prm1, 0), flip=(sx < 0))


def rim_ring(S, z0, z1, e, mat, w=1.4):
    """gờ miệng rỗng giữa (4 thanh), để mở nắp thấy lòng rương"""
    a, b = LA + e, LB + e
    obx(S, (-a, b - w, z0), (2 * a, 0, 0), (0, w, 0), (0, 0, z1 - z0), mat)
    obx(S, (-a, -b, z0), (2 * a, 0, 0), (0, w, 0), (0, 0, z1 - z0), mat)
    obx(S, (a - w, -b + w, z0), (w, 0, 0), (0, 2 * b - 2 * w, 0), (0, 0, z1 - z0), mat)
    obx(S, (-a, -b + w, z0), (w, 0, 0), (0, 2 * b - 2 * w, 0), (0, 0, z1 - z0), mat)


def sen_logo(S, rng, c, s, mpet, mplate=None, mring=None, mgem=None, plate_r=None):
    """LOGO SEN khối nổi hướng ra trước (+y): đĩa nền + vành, 7 cánh, 2 lá đế, gương sen, hột"""
    cx, cy, cz = c
    if mplate is not None:
        pr = plate_r or s * 1.5
        disc(S, Pl(cx, cy + 0.5, cz), rotv((0, 1, 0)), pr, mplate, (0, 0, 0), nr=4, na=40)
        tube(S, Pl(cx, cy - 0.1, cz), Pl(cx, cy + 0.5, cz), pr, mplate, nr=40, nl=2)
        if mring is not None:
            for k in range(40):
                t0, t1 = 2 * math.pi * k / 40, 2 * math.pi * (k + 1.05) / 40
                bar(S, (cx + pr * math.cos(t0), cy + 0.5, cz + pr * math.sin(t0)), (cx + pr * math.cos(t1), cy + 0.5, cz + pr * math.sin(t1)), (0, 1, 0), 0.32, 0.45, mring)
    base = np.array([cx, cy + 0.8, cz - s * 0.6])
    for ang, ln_, w in ((0, 1.05, 0.32), (25, 0.95, 0.29), (-25, 0.95, 0.29), (50, 0.8, 0.26), (-50, 0.8, 0.26), (77, 0.6, 0.22), (-77, 0.6, 0.22)):
        t = math.radians(ang); d = np.array([math.sin(t), 0, math.cos(t)]); pp = np.array([math.cos(t), 0, -math.sin(t)])
        cc = base + d * s * ln_ * 0.55 + np.array([0, 0.35 * s * (1 - abs(ang) / 90), 0])
        ell(S, tuple(cc), s * ln_ * 0.56, s * w, s * 0.22, mpet, (rng.random(), 0, 0), axes=(d, pp, np.array([0, 1.0, 0])))
    for sx in (1, -1):
        d = np.array([sx, 0, 0.3]) / math.hypot(1, 0.3); pp = np.array([-0.3 * sx, 0, 1]) / math.hypot(1, 0.3)
        ell(S, tuple(base + np.array([sx * s * 0.66, 0.2, -s * 0.12])), s * 0.62, s * 0.17, s * 0.18, mpet, (rng.random(), 1, 0), axes=(d, pp, np.array([0, 1.0, 0])))
    if mgem is not None:
        ell(S, tuple(base + np.array([0, 0.75 * s, s * 0.5])), s * 0.24, s * 0.22, s * 0.24, mgem)



def on_lid(x, t, lift=0.0):
    R = LR + lift
    return np.array([x, R * math.cos(t), ZL + R * math.sin(t)]), np.array([0, math.cos(t), math.sin(t)]), np.array([0, -math.sin(t), math.cos(t)])


def frond(S, rng, x0, x1, t0, t1, mat):
    """tàu lá dừa nước chạm nổi trên nắp: sống lá cong + lá chét xiên 2 bên, nhỏ dần về ngọn"""
    n = 16; pts = []
    for i in range(n):
        f = i / (n - 1); x = x0 + (x1 - x0) * f; t = t0 + (t1 - t0) * f + 0.12 * math.sin(math.pi * f)
        p, nr, tv = on_lid(x, t, 0.25); pts.append((p, nr, tv))
    for (p0, _, _), (p1, _, _) in zip(pts, pts[1:]): tb(S, tuple(p0), tuple(p1), 0.28, mat, nr=6, nl=2)
    for i in range(1, n - 1):
        p, nr, tv = pts[i]; d = pts[i + 1][0] - p; d = d / np.linalg.norm(d); f = i / (n - 1); ln_ = 1.9 * (1 - 0.55 * f)
        for sg in (1, -1):
            dd = d * 0.55 + tv * sg * 0.83; dd = dd / np.linalg.norm(dd); pp = np.cross(nr, dd)
            ell(S, tuple(p + dd * ln_ * 0.55 + nr * 0.15), ln_ * 0.55, 0.26, 0.17, mat, (rng.random(), 0, 0), axes=(dd, pp, nr), nu=6, nv_=8)


# ------------------------------------------------------------------ chạm nổi khối thật trên mặt (bậc 3-4)
def Ffront(u, v, lift=0.0):
    return np.array([u, LB + lift, v]), np.array([1.0, 0, 0]), np.array([0, 0, 1.0]), np.array([0, 1.0, 0])


def Flid(u, v, lift=0.0):              # v = góc trên cung nắp (0 = mép trước, pi/2 = đỉnh)
    p, n, tv = on_lid(u, v, lift)
    return p, np.array([1.0, 0, 0]), tv, n


def petal(S, rng, F, u, v, ang, ln_, w, th, mat, lift=0.2, dv_scale=1.0):
    p, tu, tv, n = F(u, v, lift)
    d = tu * math.cos(ang) + tv * math.sin(ang); pp = np.cross(n, d)
    ell(S, tuple(p + d * ln_ * 0.5 + n * th * 0.3), ln_ * 0.52, w, th, mat, (rng.random(), 0, 0), axes=(d, pp, n), nu=6, nv_=9)


def flower(S, rng, F, u, v, sc, mpet, mmid, dv=1.0):
    """bông sen nở 2 tầng cánh + gương sen"""
    for ang, l, w in ((90, 1.3, .4), (58, 1.15, .37), (122, 1.15, .37), (25, .95, .33), (155, .95, .33)):
        petal(S, rng, F, u, v, math.radians(ang), l * sc, w * sc, .24 * sc, mpet, lift=0.15)
    for ang in (75, 105):
        petal(S, rng, F, u, v + 0.0, math.radians(ang), .8 * sc, .28 * sc, .34 * sc, mpet, lift=0.35)
    p, tu, tv, n = F(u, v, 0.3)
    ell(S, tuple(p + tv * 0.2 * sc + n * 0.2 * sc), .38 * sc, .28 * sc, .3 * sc, mmid, axes=(tu, tv, n), nu=5, nv_=8)


def pad(S, rng, F, u, v, r, mat):
    """lá sen: đĩa dẹt + mép cuộn + gân toả"""
    p, tu, tv, n = F(u, v, 0.15)
    ell(S, tuple(p), r, r * 0.8, 0.22, mat, axes=(tu, tv, n), nu=4, nv_=16)
    for k in range(9):
        a = 2 * math.pi * k / 9 + 0.3
        q = F(u + r * 0.9 * math.cos(a), v + r * 0.72 * math.sin(a) / (LR if F is Flid else 1.0), 0.3)[0]
        tube(S, Pl(*(p + n * 0.15)), Pl(*q), 0.13, mat, nr=4, nl=2)
    rim = [F(u + r * math.cos(a), v + r * 0.8 * math.sin(a) / (LR if F is Flid else 1.0), 0.32)[0] for a in np.linspace(0.4, 2 * math.pi - 0.4, 18)]
    for q0, q1 in zip(rim, rim[1:]): tube(S, Pl(*q0), Pl(*q1), 0.2, mat, nr=4, nl=2)


def stem(S, F, pts, r, mat, lift=0.25):
    q = [F(u, v, lift)[0] for (u, v) in pts]
    for a, b in zip(q, q[1:]): tube(S, Pl(*a), Pl(*b), r, mat, nr=5, nl=2)


def fish(S, rng, u, v, d, sc, mat, meye):
    """cá lóc chạm nổi trên nắp: đầu bẹt to, thân tròn thon dần, vây lưng + vây hậu môn là màng dài liền, đuôi quạt tròn, nắp mang, mắt"""
    F = Flid
    def P_(du, dv, lift=0.3):
        return F(u + d * du * sc, v + dv * sc / LR, lift)
    p, tu, tv, n = P_(0, 0); t = tu * d; b = np.cross(n, t)
    def blob(du, dv, rx, ry, rz, lift=0.3, m=mat):
        q = P_(du, dv, lift)[0]
        ell(S, tuple(q + n * rz * 0.45), rx * sc, ry * sc, rz * sc, m, (rng.random(), 0, 0), axes=(t, b, n), nu=7, nv_=12)
    blob(1.9, 0, 0.95, 0.66, 0.42)                 # đầu bẹt
    blob(0.8, 0, 1.25, 0.7, 0.6)                   # thân trước
    blob(-0.6, 0, 1.3, 0.6, 0.52)                  # thân giữa
    blob(-1.8, 0, 0.9, 0.42, 0.38)                 # cuống đuôi
    blob(0.0, 0.72, 2.2, 0.2, 0.14)                # vây lưng màng dài
    blob(-1.0, -0.6, 1.1, 0.16, 0.12)              # vây hậu môn
    q = P_(-2.9, 0)[0]                             # đuôi quạt tròn
    ell(S, tuple(q + n * 0.08), 0.75 * sc, 0.72 * sc, 0.12 * sc, mat, axes=(t, b, n), nu=5, nv_=14)
    for a_ in np.linspace(-0.8, 0.8, 5):           # tia đuôi nổi
        q2 = P_(-2.6 - 0.85 * math.cos(a_), 0.75 * math.sin(a_), 0.45)[0]
        tube(S, Pl(*P_(-2.4, 0, 0.45)[0]), Pl(*q2), 0.08 * sc, mat, nr=4, nl=2)
    gill = [P_(1.35 + 0.15 * math.cos(a_), 0.55 * math.sin(a_), 0.3 + 0.55 * sc * math.cos(a_ * 0.8))[0] for a_ in np.linspace(-1.2, 1.2, 7)]
    for g0, g1 in zip(gill, gill[1:]): tube(S, Pl(*g0), Pl(*g1), 0.09 * sc, mat, nr=4, nl=2)
    pe = P_(2.25, 0.3, 0.3 + 0.62 * sc)[0]
    ell(S, tuple(pe), 0.15 * sc, 0.15 * sc, 0.1 * sc, meye, nu=4, nv_=8)
    pf = P_(1.0, -0.6, 0.55)[0]                    # vây ngực
    dd = -t * 0.6 - b * 0.8; dd = dd / np.linalg.norm(dd)
    ell(S, tuple(pf + dd * 0.35 * sc), 0.5 * sc, 0.22 * sc, 0.1 * sc, mat, axes=(dd, np.cross(n, dd), n), nu=4, nv_=8)


def waves(S, u0, u1, v, sc, mat):
    w = 2.4 * sc; u = u0
    while u + w <= u1 + 0.01:
        stem(S, Flid, [(u + w * f, v + 0.9 * sc * math.sin(math.pi * f) / LR) for f in np.linspace(0, 1, 9)], 0.22 * sc, mat, 0.25)
        cx, cy = u + w * 0.6, v + 0.85 * sc / LR
        stem(S, Flid, [(cx + 0.55 * sc * (1 - a / 7) * math.cos(a), cy + 0.55 * sc * (1 - a / 7) * math.sin(a) / LR) for a in np.linspace(0, 5.5, 10)], 0.15 * sc, mat, 0.3)
        u += w


def vine(S, rng, F, pts, r, mstem, mleaf, every=2):
    q = []
    for i in range(len(pts) - 1):
        (ua, va), (ub, vb) = pts[i], pts[i + 1]
        for f in np.linspace(0, 1, 6)[:-1]: q.append((ua + (ub - ua) * f, va + (vb - va) * f))
    q.append(pts[-1]); stem(S, F, q, r, mstem)
    for i in range(1, len(q) - 1, every):
        (ua, va), (ub, vb) = q[i], q[i + 1]
        pa = F(ua, va)[0]; pb = F(ub, vb)[0]; d = pb - pa; L = np.linalg.norm(d)
        if L < 1e-6: continue
        d = d / L; p, tu, tv, n = F(ua, va, 0.2); sg = 1 if (i // every) % 2 else -1
        dd = d * 0.5 + np.cross(n, d) * sg * 0.87; dd = dd / np.linalg.norm(dd)
        ell(S, tuple(p + dd * 0.8 + n * 0.1), 0.85, 0.32, 0.2, mleaf, (rng.random(), 0, 0), axes=(dd, np.cross(n, dd), n), nu=5, nv_=8)


def frames_panel(S, xr, zr, w, h, mat):
    """khung nổi quanh các ô mặt trước/sau + hông + ô nắp"""
    for sy in (1, -1):
        for (u0, u1) in xr:
            y = sy * LB; pts = [(u0, y, zr[0]), (u1, y, zr[0]), (u1, y, zr[1]), (u0, y, zr[1]), (u0, y, zr[0])]
            for a, b in zip(pts, pts[1:]): bar(S, a, b, (0, sy, 0), w, h, mat)
    for sx in (1, -1):
        x = sx * LA; y0 = LB - 1.4; pts = [(x, -y0, zr[0]), (x, y0, zr[0]), (x, y0, zr[1]), (x, -y0, zr[1]), (x, -y0, zr[0])]
        for a, b in zip(pts, pts[1:]): bar(S, a, b, (sx, 0, 0), w, h, mat)
    for (u0, u1) in xr:
        for t in (0.35, math.pi - 0.35):
            p0 = on_lid(u0, t)[0]; p1 = on_lid(u1, t)[0]; bar(S, p0, p1, on_lid(0, t)[1], w, h, mat)
        for uu in (u0, u1):
            ts = np.linspace(0.35, math.pi - 0.35, 16)
            for t0, t1 in zip(ts, ts[1:]):
                bar(S, on_lid(uu, t0)[0], on_lid(uu, t1)[0], on_lid(0, (t0 + t1) / 2)[1], w, h, mat)


def flat(col):
    c = hexc(col)
    return newmat(lambda uv, prm, pos, nrm: (np.tile(c, (len(uv), 1)), nrm), kind='ngoc')


def paint(col):
    """sơn tay trên khối chạm: đậm nhạt theo mảng, chỗ sơn mỏng sáng hơn (không vệt tối)"""
    c = hexc(col); c = c * 0.85 + hexc('#8a7458') * 0.15; lt = c * 0.7 + 0.3
    def f(uv, prm, pos, nrm):
        g = vnoise(pos[:, 0] * 0.6, pos[:, 1] * 0.6 + pos[:, 2] * 0.6, 3.0)
        m = np.clip((g - 0.45) * 1.8, 0, 1) * 0.4
        return np.clip(c[None] * (1 - m)[:, None] + lt[None] * m[:, None], 0, 1), nrm
    return newmat(f, kind='son')


def tier_rich(S, rng, t):
    global LA, LB, ZL, LR
    if t == 3:
        LA, LB, ZL = 16.0, 10.0, 14.0
        BODY, LEDGE = '#228a76', '#196a5c'; GF, GB = '#b88a34', '#e2b24a'
    else:
        LA, LB, ZL = 16.6, 10.4, 14.4
        BODY, LEDGE = '#b8302a', '#8a2420'; GF, GB = '#c0903a', '#eabe52'
    LR = LB
    K.FOOT = ((C0 - LA - 1.5) / T, (C0 + LA + 1.5) / T, (C0 - LB - 1.5) / T, (C0 + LB + 1.5) / T, 0.05)
    MB = newmat(mat_son(BODY) if t == 3 else mat_xacu(BODY)); ML = newmat(mat_son(LEDGE))
    VF = newmat(mat_kl(GF, hammer=False, streak=0.02, leaf=True)); VB = newmat(mat_kl(GB, hammer=False, streak=0.02, leaf=True))
    box_body(S, MB, prm1=1.0)
    for z0, z1, e in ((0.0, 1.0, 0.9), (1.0, 2.0, 0.5)):
        obx(S, (-LA - e, -LB - e, z0), (2 * (LA + e), 0, 0), (0, 2 * (LB + e), 0), (0, 0, z1 - z0), ML)
    rim_ring(S, ZL - 1.4, ZL, 0.6, ML)
    for z in (1.0, 2.0, ZL - 1.4, ZL):                              # chỉ vàng viền gờ
        for sy in (1, -1):
            e = 0.95 if z <= 1.0 else (0.55 if z <= 2.0 else 0.65)
            bar(S, (-LA - e, sy * (LB + e), z), (LA + e, sy * (LB + e), z), (0, sy, 0), 0.18, 0.12, VF)
        for sx in (1, -1):
            e = 0.95 if z <= 1.0 else (0.55 if z <= 2.0 else 0.65)
            bar(S, (sx * (LA + e), -LB - e, z), (sx * (LA + e), LB + e, z), (sx, 0, 0), 0.18, 0.12, VF)
    xs = LA * (0.6 if t == 3 else 0.5)
    xr = [(-xs + 1.4, xs - 1.4), (xs + 1.4, LA - 1.3), (-LA + 1.3, -xs - 1.4)]
    frames_panel(S, xr, (3.0, ZL - 2.4), 0.3, 0.35, VF)
    for x in (-xs, xs):                                             # đai vàng vuông
        for sy in (1, -1):
            obx(S, (x - 1.0, LB if sy > 0 else -LB - 0.45, 2.0), (2.0, 0, 0), (0, 0.45, 0), (0, 0, ZL - 3.4), VF)
        arc_bar(S, x, 1.0, 0.45, VF, n=24)
    for sx in (1, -1):                                              # viền 2 đầu nắp + bọc góc + chân
        arc_bar(S, sx * (LA - 0.6), 0.6, 0.4, VF, n=24)
        for sy in (1, -1):
            for z0 in (2.0, ZL - 4.6):
                obx(S, (sx * LA - (3.2 if sx > 0 else 0), LB if sy > 0 else -LB - 0.4, z0), (3.2, 0, 0), (0, 0.4, 0), (0, 0, 3.2), VF)
                obx(S, (sx * LA if sx > 0 else -LA - 0.4, sy * LB - (3.2 if sy > 0 else 0), z0), (0.4, 0, 0), (0, 3.2, 0), (0, 0, 3.2), VF)
            ell(S, (sx * (LA - 1.6), sy * (LB - 1.6), -0.1), 1.6, 1.6, 1.1, VB)
    for sy in (1, -1): bar(S, (-LA, sy * LB, ZL + 0.3), (LA, sy * LB, ZL + 0.3), (0, sy, 0), 0.45, 0.4, VF)
    for sx in (1, -1):                                              # quai vàng 2 hông: đĩa hoa thị + vòng
        for k in range(8):
            a = 2 * math.pi * k / 8
            ell(S, (sx * (LA + 0.3), 1.3 * math.cos(a), ZL * 0.62 + 1.3 * math.sin(a)), 0.3, 0.5, 0.5, VB)
        ell(S, (sx * (LA + 0.3), 0, ZL * 0.62), 0.35, 1.1, 1.1, VF)
        pts = [(sx * (LA + 0.9), 1.4 * math.cos(q), ZL * 0.62 - 2.2 * math.sin(q)) for q in np.linspace(0, math.pi, 14)]
        for p0, p1 in zip(pts, pts[1:]): tb(S, p0, p1, 0.34, VB, nr=6, nl=2)
    # LOGO SEN to trên đĩa
    if t == 3:
        sen_logo(S, rng, (0, LB + 0.9, ZL - 2.6), 2.8, VB, mplate=newmat(mat_son('#8e1c18')), mring=VB, mgem=flat('#e0302a'), plate_r=4.0)
    else:
        sen_logo(S, rng, (0, LB + 0.9, ZL - 2.8), 3.1, VB, mplate=newmat(mat_son('#12352c')), mring=VB, mgem=flat('#d81c3a'), plate_r=4.5)
        PEARL = flat('#f2eee6')
        for k in range(18):
            a = 2 * math.pi * k / 18
            ell(S, (5.05 * math.cos(a), LB + 1.5, ZL - 2.8 + 5.05 * math.sin(a)), 0.32, 0.32, 0.32, PEARL)
        JADE = flat('#22a070')
        for sx in (1, -1):
            for zc in (3.6, ZL - 3.6): ell(S, (sx * (LA - 1.6), LB + 0.5, zc), 0.6, 0.5, 0.6, JADE)
        top = (0, 0, ZL + LR + 0.2)                                     # núm búp sen trên đỉnh
        tb(S, top, (0, 0, ZL + LR + 1.0), 1.3, VF, nr=14, nl=2, cap=True)
        ell(S, (0, 0, ZL + LR + 2.6), 0.8, 0.8, 1.9, VB)
        for k in range(6):
            a = 2 * math.pi * k / 6; d = np.array([math.cos(a), math.sin(a), 0.0])
            ax_ = np.array([0, 0, 1.0]) + d * 0.4; ax_ = ax_ / np.linalg.norm(ax_)
            ell(S, tuple(np.array([0, 0, ZL + LR + 2.1]) + d * 0.75), 1.5, 0.6, 0.3, VB, axes=(ax_, np.cross(ax_, d), d))
    ob = (-1.2, LB + 0.3, ZL - 0.5)                                 # tai khoá
    obx(S, ob, (2.4, 0, 0), (0, 0.6, 0), (0, 0, 2.6), VF)
    # CHẠM NỔI miền Tây, sơn tay nhiều màu
    if t == 3:
        PK, LF, SG, WV = paint('#de7c96'), paint('#58a04c'), paint('#3e7c38'), paint('#ece6d2')
        EYE = flat('#201810')
        for sx in (1, -1):
            uc = sx * (xs + LA) / 2
            stem(S, Ffront, [(uc, 4.0), (uc + 0.6, 6.5), (uc, 9.0)], 0.3, SG)
            pad(S, rng, Ffront, uc, 4.6, 2.0, LF)
            flower(S, rng, Ffront, uc, 9.4, 1.5, PK, VB)
        waves(S, -xs + 1.6, xs - 1.6, 0.45, 1.6, WV)
        fish(S, rng, -0.6, 1.12, 1, 2.0, VB, EYE)
        for sx in (1, -1):
            uc = sx * (xs + LA) / 2
            stem(S, Flid, [(uc, 0.6), (uc - 0.5, 0.95), (uc, 1.35)], 0.28, SG)
            pad(S, rng, Flid, uc, 0.65, 1.9, LF); flower(S, rng, Flid, uc, 1.4, 1.3, PK, VB)
    else:
        PK, JD = paint('#eeacbc'), paint('#2e9c70')
        for sx in (1, -1):
            uc = sx * (xs + LA) / 2
            vine(S, rng, Ffront, [(uc, 3.6), (uc - sx * 0.9, 6.0), (uc, 8.6)], 0.25, VB, JD)
            pad(S, rng, Ffront, uc, 4.4, 1.7, JD)
            flower(S, rng, Ffront, uc, 9.5, 1.4, PK, VB)
        vine(S, rng, Flid, [(xx, 0.92 + 0.22 * math.sin(xx * 0.75)) for xx in np.linspace(-xs + 1.8, xs - 1.8, 9)], 0.3, VB, JD)
        for (uu, vv) in ((-4.2, 1.45), (4.2, 1.45)): flower(S, rng, Flid, uu, vv, 1.45, PK, VB)
        pad(S, rng, Flid, 0, 1.25, 1.6, JD)
        for sx in (1, -1):
            uc = sx * (xs + LA) / 2
            pad(S, rng, Flid, uc, 0.65, 1.6, JD); flower(S, rng, Flid, uc, 1.35, 1.2, PK, VB)
            vine(S, rng, Flid, [(uc, 0.7), (uc - sx * 0.6, 1.0), (uc, 1.3)], 0.22, VB, JD, every=3)


def gio_tre(S, rng):
    """BẬC 1 kiểu đồ cổ Nam Bộ: giỏ tre đan tròn có nắp chụp, miệng + đáy niềng tre bện mây, quai mây 2 bên, núm nắp bằng gáo dừa, thẻ gỗ khắc sen"""
    global LA, LB, ZL, LR
    R0, H = 10.5, 15.5; LA = LB = R0; ZL = H; LR = R0
    K.FOOT = ((C0 - 12) / T, (C0 + 12) / T, (C0 - 12) / T, (C0 + 12) / T, 0.5)
    def prof(zf):                                   # thân phình giữa, thót đáy
        return R0 * (0.84 + 0.2 * np.sin(np.pi * (0.15 + 0.75 * zf)))
    def body(U, V):
        th = V * 2 * math.pi; zf = U; r = prof(zf)
        return np.stack([r * np.cos(th), r * np.sin(th), 0.4 + zf * (H - 0.4)], -1)
    grid(S, body, 40, 120, M_DAN, (3, 0, 0), close_v=True, flip=False)
    def lid(U, V):                                  # nắp chụp: vành đứng ngắn + chỏm cong
        th = V * 2 * math.pi; rr = prof(1.0) + 0.7
        r = np.where(U < 0.25, rr, rr * np.cos((U - 0.25) / 0.75 * 1.25))
        z = np.where(U < 0.25, H - 1.2 + U / 0.25 * 1.8, H + 0.6 + rr * 0.3 * np.sin((U - 0.25) / 0.75 * 1.25) / np.sin(1.25))
        return np.stack([r * np.cos(th), r * np.sin(th), z], -1)
    grid(S, lid, 40, 120, M_DAN, (3, 0, 0), close_v=True, flip=False)
    def ring(z, r, rt, mat, prm=(0.4, 0.2, 0), n=48):
        pts = [(r * math.cos(t), r * math.sin(t), z) for t in np.linspace(0, 2 * math.pi, n + 1)]
        for p0, p1 in zip(pts, pts[1:]): tb(S, p0, p1, rt, mat, prm, nr=7, nl=2)
    ring(0.7, prof(0.02) + 0.3, 0.95, M_OLDBAMBOO)            # niềng đáy tre già
    ring(H - 1.1, prof(1.0) + 1.0, 0.8, M_BAMBOO)              # niềng mép nắp
    ring(H + 0.6, prof(1.0) + 0.95, 0.7, M_BAMBOO)
    ring(H * 0.5, prof(0.5) + 0.25, 0.4, M_RATTAN)             # đai mây giữa thân
    for k in range(10):                                       # mây quấn niềng (từng nút)
        t = 2 * math.pi * k / 10
        for zz, rr in ((0.7, prof(0.02) + 0.3), (H - 1.1, prof(1.0) + 1.0)):
            ell(S, (rr * math.cos(t), rr * math.sin(t), zz), 0.7, 0.7, 1.25, M_ROPE, axes=(np.array([-math.sin(t), math.cos(t), 0]), np.array([math.cos(t), math.sin(t), 0]), np.array([0, 0, 1.0])), nu=5, nv_=10)
    for k in range(8):                                        # nan cốt dọc nổi trên thân (tre chẻ)
        t = 2 * math.pi * (k + 0.5) / 8
        pts = [((prof(zf) + 0.15) * math.cos(t), (prof(zf) + 0.15) * math.sin(t), 0.9 + zf * (H - 2.6)) for zf in np.linspace(0, 1, 10)]
        for p0, p1 in zip(pts, pts[1:]): tb(S, p0, p1, 0.32, M_BAMBOO, (0.6, k * 0.1, 0), nr=5, nl=2)
    top = H + 0.6 + (prof(1.0) + 0.7) * 0.3                  # núm nắp: nửa gáo dừa úp + cọng mây
    X3.ellipsoid(S, Pl(0, 0, top + 0.3), 2.3, 2.3, 1.5, K.M_COCO if hasattr(K, 'M_COCO') else M_TRAM, nu=6, nvv=16, zmin=0.5)
    for sx in (1, -1):                                        # quai mây 2 bên
        pts = [(sx * (prof(0.75) + 0.6 + 1.6 * math.sin(t)), 2.6 * math.cos(t), H - 3.6 + 1.2 * math.sin(t)) for t in np.linspace(0, math.pi, 14)]
        for p0, p1 in zip(pts, pts[1:]): tb(S, p0, p1, 0.55, M_RATTAN, nr=6, nl=2)
    sen_go(S, rng, (0, prof(0.5) + 0.2, 7.2), 3.0)            # thẻ gỗ khắc sen buộc mây trước giỏ


def build(level, rng, with_props=True):
    global LA, LB, ZL, LR, WOODC
    S = Scene(); K.LIGHTS2.clear(); K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
    if TIER == 11:
        gio_tre(S, rng)
    elif TIER == 1:
        LA, LB, ZL = 14.0, 9.0, 13.0; LR = LB
        K.FOOT = ((C0 - 15) / T, (C0 + 15) / T, (C0 - 10) / T, (C0 + 10) / T, 0.05)
        body_dan(S); frame_tre(S, rng)
        sen_go(S, rng, (0, LB + 0.6, 5.9), 4.2)
        tb(S, (-2.4, LB + 1.9, ZL + 1.6), (2.4, LB + 1.9, ZL + 1.6), 0.75, M_TRAM, (0.4, 0, 0), cap=True)      # chốt gỗ ngang mép nắp
        for sx in (1, -1):                                          # quai mây 2 hông
            pts = [(sx * (LA + 1.0 + 2.0 * math.sin(t)), 3.0 * math.cos(t), ZL * 0.62 + 1.0 * math.sin(t)) for t in np.linspace(0, math.pi, 12)]
            for p0, p1 in zip(pts, pts[1:]): tb(S, p0, p1, 0.55, M_RATTAN, nr=6, nl=2)

    elif TIER == 2:                 # gỗ tràm ván ghép, đế + gờ miệng, đai sắt rèn, bọc góc sắt, đinh đồng, KHOÁ KHIÊN ĐỒNG có SEN nổi, khoá móc
        WOODC = '#9c6a42'
        LA, LB, ZL = 15.0, 9.6, 13.5; LR = LB
        K.FOOT = ((C0 - 16.5) / T, (C0 + 16.5) / T, (C0 - 11) / T, (C0 + 11) / T, 0.05)
        MV = newmat(mat_van); SAT = newmat(mat_kl('#5c6068')); SAT2 = newmat(mat_kl('#4a4e56'))
        DONG = newmat(mat_kl('#d4a046', hammer=False)); DONG2 = newmat(mat_kl('#b88430', hammer=False))
        GOV = newmat(mat_kl('#9a5a2a', hammer=False, streak=0.1))
        box_body(S, MV)
        obx(S, (-LA - 0.7, -LB - 0.7, 0.0), (2 * (LA + 0.7), 0, 0), (0, 2 * (LB + 0.7), 0), (0, 0, 1.4), MV, (0, 0, 0))   # đế
        rim_ring(S, ZL - 1.3, ZL, 0.55, MV)                                                                                 # gờ miệng
        xs = LA * 0.6
        for x in (-xs, xs):                                              # 2 đai sắt rèn: ôm thân trước/sau + vòng qua nắp
            for sy in (1, -1):
                obx(S, (x - 0.95, LB if sy > 0 else -LB - 0.35, 1.4), (1.9, 0, 0), (0, 0.35, 0), (0, 0, ZL - 2.7), SAT)
            arc_bar(S, x, 0.95, 0.35, SAT, n=22)
            for zz in (1.9, ZL * 0.5, ZL - 2.1):                         # đinh đồng tán trên đai
                ell(S, (x, LB + 0.4, zz), 0.42, 0.3, 0.42, DONG)
            for t in (0.5, 1.1, math.pi / 2, math.pi - 1.1):
                ell(S, (x, (LR + 0.4) * math.cos(t), ZL + (LR + 0.4) * math.sin(t)), 0.4, 0.4, 0.4, DONG)
        for sx in (1, -1):                                               # bọc góc sắt chữ L + viền 2 đầu nắp
            for sy in (1, -1):
                for z0 in (0.0, ZL - 3.2):
                    obx(S, (sx * LA - (2.6 if sx > 0 else 0) + (0 if sx > 0 else 0), sy * LB - (0.3 if sy < 0 else 0), z0), (2.6 * (1 if sx > 0 else -1) if False else 2.6, 0, 0), (0, 0.3, 0), (0, 0, 3.2), SAT2)
                    obx(S, (sx * LA - (0.3 if sx < 0 else 0), sy * LB - (2.6 if sy > 0 else 0), z0), (0.3, 0, 0), (0, 2.6, 0), (0, 0, 3.2), SAT2)
            arc_bar(S, sx * (LA - 0.5), 0.55, 0.35, SAT2, n=22)
        for sy in (1, -1): bar(S, (-LA, sy * LB, ZL + 0.25), (LA, sy * LB, ZL + 0.25), (0, sy, 0), 0.4, 0.4, SAT2)
        # khoá khiên đồng + sen nổi + khoá móc sắt
        c = (0, LB + 0.35, ZL - 1.6)
        obx(S, (-2.9, LB + 0.55, ZL - 5.4), (5.8, 0, 0), (0, 0.45, 0), (0, 0, 6.2), DONG2)
        for k in range(28):
            t0, t1 = 2 * math.pi * k / 28, 2 * math.pi * (k + 1.05) / 28
            bar(S, (2.5 * math.cos(t0), LB + 1.0, ZL - 2.2 + 2.5 * math.sin(t0)), (2.5 * math.cos(t1), LB + 1.0, ZL - 2.2 + 2.5 * math.sin(t1)), (0, 1, 0), 0.25, 0.3, DONG)
        sen_logo(S, rng, (0, LB + 0.9, ZL - 1.9), 2.5, DONG)
        for sx in (1, -1):
            for zz in (ZL - 4.9, ZL + 0.3):
                ell(S, (sx * 2.4, LB + 1.05, zz), 0.35, 0.25, 0.35, DONG)
        obx(S, (-0.9, LB + 0.05, ZL - 0.3), (1.8, 0, 0), (0, 0.5, 0), (0, 0, 2.4), DONG2)      # tai khoá trên nắp
        pts = [(1.05 * math.cos(t), LB + 1.3, ZL - 6.0 + 1.3 * math.sin(t) + 0.4) for t in np.linspace(0, math.pi, 10)]
        for p0, p1 in zip(pts, pts[1:]): tb(S, p0, p1, 0.32, SAT, nr=6, nl=2)                 # quai khoá móc
        obx(S, (-1.5, LB + 1.1, ZL - 8.6), (3.0, 0, 0), (0, 1.1, 0), (0, 0, 2.7), SAT2)
        ell(S, (0, LB + 2.25, ZL - 7.5), 0.22, 0.1, 0.22, newmat(lambda uv, prm, pos, nrm: (np.tile(hexc('#2a2220'), (len(uv), 1)), nrm)))
        for sx in (1, -1):                                              # quai sắt 2 hông
            ell(S, (sx * (LA + 0.2), 0, ZL * 0.62), 0.35, 1.6, 1.6, SAT2)
            pts = [(sx * (LA + 0.75), 1.6 * math.cos(t), ZL * 0.62 - 2.4 * math.sin(t)) for t in np.linspace(0, math.pi, 12)]
            for p0, p1 in zip(pts, pts[1:]): tb(S, p0, p1, 0.32, SAT, nr=6, nl=2)
        # chạm nổi gỗ trên nắp: tàu lá dừa nước 2 bên khoá
        for sx in (1, -1):
            frond(S, rng, sx * 3.6, sx * (LA - 1.5), 0.55, 1.15, GOV)
    else:
        tier_rich(S, rng, TIER)
    return S, (S.ns, S.ns)


K.build = build

if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        TIER = int(sys.argv[3]); ROT = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0
        im = K.render(1, False, 'b', ss=int(os.environ.get('RG_SS', '2')))
        im.crop(im.getbbox()).save(sys.argv[2])
