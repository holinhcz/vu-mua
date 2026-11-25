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
TINT = np.array([1.0, 1.0, 1.0]); GOC = '#b8783c'


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


def build(level, rng, with_props=True):
    global LA, LB, ZL, LR
    S = Scene(); K.LIGHTS2.clear(); K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
    if TIER == 1:
        LA, LB, ZL = 14.0, 9.0, 13.0; LR = LB
        K.FOOT = ((C0 - 15) / T, (C0 + 15) / T, (C0 - 10) / T, (C0 + 10) / T, 0.05)
        body_dan(S); frame_tre(S, rng)
        sen_go(S, rng, (0, LB + 0.6, 5.8), 3.5)
        tb(S, (-2.4, LB + 1.9, ZL + 1.6), (2.4, LB + 1.9, ZL + 1.6), 0.75, M_TRAM, (0.4, 0, 0), cap=True)      # chốt gỗ ngang mép nắp
        for sx in (1, -1):                                          # quai mây 2 hông
            pts = [(sx * (LA + 1.0 + 2.0 * math.sin(t)), 3.0 * math.cos(t), ZL * 0.62 + 1.0 * math.sin(t)) for t in np.linspace(0, math.pi, 12)]
            for p0, p1 in zip(pts, pts[1:]): tb(S, p0, p1, 0.55, M_RATTAN, nr=6, nl=2)
    return S, (S.ns, S.ns)


K.build = build

if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        TIER = int(sys.argv[3]); ROT = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0
        im = K.render(1, False, 'b', ss=int(os.environ.get('RG_SS', '2')))
        im.crop(im.getbbox()).save(sys.argv[2])
