# Xuất rương 3D (cùng mô hình ruong_k.py) ra GLB cho trang Xem 3D: lưới dày hơn, màu từng đỉnh lấy từ đúng vật liệu kho3d,
# kim loại / sơn / gỗ tách vật liệu PBR riêng, NẮP là node riêng xoay quanh bản lề sau + hoạt ảnh 'mo_nap'.
#   python3 ruong_glb.py TIER OUT.glb [DENS]
import sys, os, math
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, '..', 'nhim3d'))
import ruong_k as R
from glbw import GLB
from pxr_3d import Scene

TIER = int(sys.argv[1]); OUT = sys.argv[2]; DENS = float(sys.argv[3]) if len(sys.argv) > 3 else 2.5
R.TIER = TIER; R.ROT = 0.0; R.EXPORT = True
_g = Scene.grid
def grid_dense(self, F, nu, nv_, mat, prm=(0, 0, 0), ao=None, uvr=((0, 1), (0, 1)), close_v=False, flip=False):
    k = DENS
    nu2 = max(nu, min(400, int(round(nu * k)))) if nu > 2 else nu
    nv2 = max(nv_, min(400, int(round(nv_ * k)))) if nv_ > 2 else nv_
    SHAPES.append((nu2, nv2, close_v))
    return _g(self, F, nu2, nv2, mat, prm, ao, uvr, close_v, flip)
SHAPES = []
Scene.grid = grid_dense


# ---- v2 11-25 Link "như đồ nhựa": vân bề mặt thành KHỐI thật (dời đỉnh theo pháp tuyến), không chỉ tô màu
def d_dan(P, UV, q):
    a, b, x, y, z = R.face_ab(P, np.full(len(P), q[0]))
    cell = 1.2; i = np.floor(a / cell); j = np.floor(b / cell); fa = a / cell - i; fb = b / cell - j
    over = ((i + j) % 4) < 2; across = np.where(over, fb, fa); along = np.where(over, fa, fb)
    k = (i + j) % 4
    dive = np.where(over, np.where(k == 0, 1 - np.clip(along * 2, 0, 1), np.where(k == 1, 1 - np.clip((1 - along) * 2, 0, 1), 0)),
                    np.where(k == 2, 1 - np.clip(along * 2, 0, 1), np.where(k == 3, 1 - np.clip((1 - along) * 2, 0, 1), 0)))
    return 0.28 * np.sin(np.pi * np.clip(across, 0, 1)) ** 0.6 - 0.22 * dive
def d_van(P, UV, q):
    a, b, x, y, z = R.face_ab(P, np.full(len(P), q[0]))
    fv = (b / 2.5) % 1.0
    g = np.minimum(fv, 1 - fv)
    return -0.32 * np.exp(-(g / 0.05) ** 2) + 0.05 * np.sin(np.pi * fv) + 0.03 * np.sin(b * 11 + a * 0.08)
def d_tre(P, UV, q):
    L = UV[:, 0]; sp = 9.0 + 2 * q[0]; ph = (L + q[1] * 5) / sp; f = ph - np.floor(ph)
    return 0.22 * np.exp(-((f - 0.48) / 0.035) ** 2) - 0.06 * np.exp(-((f - 0.54) / 0.03) ** 2)
DISP = {R.M_DAN: d_dan, R.M_BAMBOO: d_tre, R.M_OLDBAMBOO: d_tre}
for m_, f_ in R.MATS.items():
    if f_ is R.mat_van: DISP[m_] = d_van


S, _ = R.build(1, np.random.default_rng(R.K.SEED + 1))
SC = 0.055
def srgb2lin(c): return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)

groups = {}                         # (lid?, kind) -> lists
for k in range(len(S.P)):
    P = S.P[k]; N = S.N[k]; UV = S.UV[k]; T = S.T[k] - sum(len(x) for x in S.P[:k])
    m = int(S.M[k][0]); q = S.Q[k][0]
    fn = R.MATS[m]
    col, nrm = fn(UV, np.tile(q, (len(P), 1)), P, N)
    nu2, nv2, cv = SHAPES[k] if k < len(SHAPES) else (0, 0, False)
    if m in DISP and nu2 * nv2 == len(P):
        P = P + N * DISP[m](P, UV, q)[:, None]
        G3 = P.reshape(nu2, nv2, 3)
        du = np.gradient(G3, axis=0); dv = (np.roll(G3, -1, 1) - np.roll(G3, 1, 1)) / 2 if cv else np.gradient(G3, axis=1)
        nn = np.cross(du, dv).reshape(-1, 3); nn = nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-9)
        sg = np.sign((nn * N).sum(1).mean()) or 1.0
        nrm = nn * sg
    kind = getattr(fn, 'kind', None) or R.KIND.get(m, 'go')
    cz = P[T].mean(1)[:, 2]
    lid = cz > (R.LIDZ if R.LIDZ is not None else R.ZL + 0.02)
    for flag in (False, True):
        sel = lid == flag
        if not sel.any(): continue
        g = groups.setdefault((flag, kind), dict(P=[], N=[], C=[], T=[], n=0))
        tt = T[sel]; used = np.unique(tt); remap = -np.ones(len(P), np.int64); remap[used] = np.arange(len(used))
        g['P'].append(P[used]); g['N'].append(nrm[used] if nrm is not None else N[used]); g['C'].append(col[used]); g['T'].append(remap[tt] + g['n']); g['n'] += len(used)

hx, hy, hz = R.C0, R.C0 - R.LB, R.ZL           # bản lề: mép sau nắp
def to_gl(P, piv):
    q = (P - np.array(piv)) * SC
    return np.stack([-q[:, 0], q[:, 2], q[:, 1]], -1)
def n_gl(N):
    N = N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    return np.stack([-N[:, 0], N[:, 2], N[:, 1]], -1)

G = GLB(); ROUGH = {'kl': 0.35, 'son': 0.5, 'go': 0.85, 'ngoc': 0.2}
mats = {k: G.material(k, rough=ROUGH[k]) for k in ROUGH}
base_piv = (R.C0, R.C0, 0.0)
def prims(flag, piv):
    out = []
    for (f, kind), g in groups.items():
        if f != flag: continue
        P = np.concatenate(g['P']); out.append(dict(pos=to_gl(P, piv), nrm=n_gl(np.concatenate(g['N'])), col=srgb2lin(np.clip(np.concatenate(g['C']), 0, 1)),
                                                 idx=np.concatenate(g['T']), mat=mats[kind]))
    return out
root = G.node('ruong_goc', (0, 0, 0))
body = G.node('than', (0, 0, 0), mesh=G.mesh('than', prims(False, base_piv)), parent=root)
hp = np.array([-(hx - R.C0), hz - 0.0, (hy - R.C0)]) * SC
lid = G.node('nap', tuple(hp), mesh=G.mesh('nap', prims(True, (hx, hy, hz))), parent=root)
ang = np.radians([0, 0, 108, 100, 104])
tm = [0, 0.15, 0.55, 0.75, 0.9]
q = [[-math.sin(a / 2), 0, 0, math.cos(a / 2)] for a in ang]
G.animation('mo_nap', [(lid, 'rotation', tm, q)])
G.save(OUT)
nv = sum(g['n'] for g in groups.values()); print(OUT, os.path.getsize(OUT) // 1024, 'KB', nv, 'verts')
