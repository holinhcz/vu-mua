# v3 11-25 Link "đã nói là không có đồ nhựa": GLB có ẢNH CHẤT LIỆU nướng từng điểm ảnh (màu + pháp tuyến gồ ghề), không tô theo đỉnh.
# Mỗi mặt lưới (grid) của mô hình ruong_k được 1 ô trong atlas; mỗi texel lấy điểm thật trên mặt (nội suy lưới), gọi đúng vật liệu kho3d
# + độ gồ DISP (nan đan, khe ván, mắt tre, vết búa, thớ gỗ) -> ảnh màu + ảnh pháp tuyến (hệ toạ độ vật thể).
#   python3 ruong_tex.py TIER OUT.glb [texel/đơn vị]
import sys, os, math
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, '..', 'nhim3d'))
import ruong_k as R
from glbw import GLB
from pxr_3d import Scene

TIER = int(sys.argv[1]); OUT = sys.argv[2]; D = float(sys.argv[3]) if len(sys.argv) > 3 else 16.0
R.TIER = TIER; R.ROT = 0.0; R.EXPORT = True
SH = []; SPART = []; SMORPH = []
_g = Scene.grid
def grid_rec(self, F, nu, nv_, mat, prm=(0, 0, 0), ao=None, uvr=((0, 1), (0, 1)), close_v=False, flip=False):
    SH.append((F, nu, nv_, uvr, close_v, flip)); SPART.append(R.PART[0])
    nu2 = max(nu, min(120, nu * 2)) if nu > 2 else nu; nv2 = max(nv_, min(120, nv_ * 2)) if nv_ > 2 else nv_
    SH[-1] = (F, nu2, nv2, uvr, close_v, flip)
    mf = getattr(R, 'MORPHF', [None])[0]
    if mf is not None:                                   # hình lúc NỞ của cánh sen (morph target)
        u = np.linspace(uvr[0][0], uvr[0][1], nu2); v = np.linspace(uvr[1][0], uvr[1][1], nv2)
        Uu, Vv = np.meshgrid(u, v, indexing='ij'); Po = mf(Uu, Vv)
        nn = np.cross(np.gradient(Po, axis=0), np.gradient(Po, axis=1)); nn = -nn if flip else nn
        nn = nn / np.maximum(np.linalg.norm(nn, axis=2, keepdims=True), 1e-12)
        SMORPH.append((Po.reshape(-1, 3), nn.reshape(-1, 3)))
    else: SMORPH.append(None)
    return _g(self, F, nu2, nv2, mat, prm, ao, uvr, close_v, flip)
Scene.grid = grid_rec
S, _ = R.build(1, np.random.default_rng(R.K.SEED + 1))

# ---------------- độ gồ (đơn vị game) theo vật liệu
def h_dan(P, UV, q):
    a, b, x, y, z = R.face_ab(P, np.full(len(P), q[0]))
    cell = 1.2; i = np.floor(a / cell); j = np.floor(b / cell); fa = a / cell - i; fb = b / cell - j
    over = ((i + j) % 4) < 2; across = np.where(over, fb, fa); along = np.where(over, fa, fb); k = (i + j) % 4
    dive = np.where(over, np.where(k == 0, 1 - np.clip(along * 2, 0, 1), np.where(k == 1, 1 - np.clip((1 - along) * 2, 0, 1), 0)),
                    np.where(k == 2, 1 - np.clip(along * 2, 0, 1), np.where(k == 3, 1 - np.clip((1 - along) * 2, 0, 1), 0)))
    fib = 0.015 * np.sin(np.where(over, b, a) * 40 + R.vnoise(a * 0.5, b * 0.5, 9.0) * 6)        # thớ nan
    return 0.26 * np.sin(np.pi * np.clip(across, 0, 1)) ** 0.5 - 0.2 * dive + fib
def h_van(P, UV, q):
    a, b, x, y, z = R.face_ab(P, np.full(len(P), q[0]))
    fv = (b / 2.5) % 1.0; g = np.minimum(fv, 1 - fv); iv = np.floor(b / 2.5)
    grain = 0.035 * np.sin(b * 14 + R.vnoise(a * 0.18 + iv * 3, b * 1.5, 3.0) * 7 + a * 0.06) + 0.012 * R.vnoise(a * 3, b * 12, 7.0)
    return -0.3 * np.exp(-(g / 0.045) ** 2) + 0.06 * np.sin(np.pi * fv) + grain
def h_son(P, UV, q):
    a, b, x, y, z = R.face_ab(P, np.full(len(P), q[0]))
    return 0.012 * np.sin(b * 13 + R.vnoise(a * 0.2, b * 2, 3.0) * 6) + 0.01 * np.sin(a * 2.2 + R.vnoise(a * 0.5, b * 4, 6.0) * 5) + 0.008 * R.vnoise(a * 4, b * 4, 2.0)
def h_kl(P, UV, q):
    x, y, z = R.loc(P)
    c1 = R.vnoise(x * 1.3 + y * 1.3, z * 1.3, 5.0); c2 = R.vnoise(x * 6 + y * 6, z * 6, 8.0)
    return 0.03 * c1 + 0.008 * c2
def h_tre(P, UV, q):
    L = UV[:, 0]; th = UV[:, 1]; sp = 9.0 + 2 * q[0]; ph = (L + q[1] * 5) / sp; f = ph - np.floor(ph)
    return 0.2 * np.exp(-((f - 0.48) / 0.035) ** 2) - 0.05 * np.exp(-((f - 0.54) / 0.03) ** 2) + 0.012 * np.sin(th * 2 * np.pi * 26 + L * 0.3)
def h_may(P, UV, q):
    L = UV[:, 0]; th = UV[:, 1]
    return 0.06 * np.sin((L * 3.2 + th * 2 * np.pi) * 1.0) ** 2
def h_go(P, UV, q):
    x, y, z = R.loc(P)
    return 0.02 * np.sin((x + z) * 9 + R.vnoise(x * 0.4, z * 0.4 + y, 3.0) * 6)
H = {R.M_DAN: h_dan, R.M_BAMBOO: h_tre, R.M_OLDBAMBOO: h_tre, R.M_RATTAN: h_may, R.M_ROPE: h_may, R.M_GO: h_go, R.M_MO: h_go}
for m_, f_ in R.MATS.items():
    if f_ is R.mat_van: H[m_] = h_van
    k_ = R.KIND.get(m_)
    if m_ not in H:
        if k_ == 'kl': H[m_] = h_kl
        elif k_ == 'son': H[m_] = h_son
H.update(R.HFN)
ROUGH = {'vang': 0.45, 'kl': 0.42, 'son': 0.78, 'go': 0.97, 'ngoc': 0.3}

# ---------------- xếp ô atlas
tiles = []
for k in range(len(S.P)):
    F, nu, nv_, uvr, cv, flip = SH[k]
    G3 = S.P[k].reshape(nu, nv_, 3)
    lu = np.linalg.norm(np.diff(G3, axis=0), axis=2).sum(0).max() if nu > 1 else 0.1
    lv = np.linalg.norm(np.diff(G3, axis=1), axis=2).sum(1).max() if nv_ > 1 else 0.1
    if cv: lv += np.linalg.norm(G3[:, 0] - G3[:, -1], axis=1).max()
    tw = int(np.clip(lu * D, 4, 1024)); th = int(np.clip(lv * D, 4, 1024))
    tiles.append([k, tw, th])
PAGE = 4096
order = sorted(range(len(tiles)), key=lambda i: -tiles[i][2])
x = y = rowh = 0; place = {}
for i in order:
    k, tw, th = tiles[i]
    if x + tw + 2 > PAGE: x = 0; y += rowh + 2; rowh = 0
    place[k] = (x + 1, y + 1, tw, th); x += tw + 2; rowh = max(rowh, th)
HH = y + rowh + 2
scale = 1.0
if HH > PAGE: raise SystemExit('atlas đầy: giảm D (cao %d)' % HH)
HH = int(2 ** math.ceil(math.log2(max(HH, 256))))
alb = np.zeros((HH, PAGE, 3), np.float32) + 0.5; nmap = np.zeros((HH, PAGE, 3), np.float32) + 0.5
SC = 0.055
def g_to_gl(v): return np.stack([-v[..., 0], v[..., 2], v[..., 1]], -1)

def bilerp(G, uu, vv, cv):
    nu, nv_ = G.shape[:2]
    fu = uu * (nu - 1); i0 = np.clip(np.floor(fu).astype(int), 0, nu - 2) if nu > 1 else np.zeros_like(fu, int); tu = fu - i0
    if cv:
        fv = vv * nv_; j0 = np.floor(fv).astype(int) % nv_; j1 = (j0 + 1) % nv_; tv = fv - np.floor(fv)
    else:
        fv = vv * (nv_ - 1); j0 = np.clip(np.floor(fv).astype(int), 0, nv_ - 2); j1 = j0 + 1; tv = fv - j0
    i1 = np.minimum(i0 + 1, nu - 1)
    a = G[i0, j0] * (1 - tu)[..., None] + G[i1, j0] * tu[..., None]
    b = G[i0, j1] * (1 - tu)[..., None] + G[i1, j1] * tu[..., None]
    return a * (1 - tv)[..., None] + b * tv[..., None]

vert_uv = []
for k in range(len(S.P)):
    F, nu, nv_, uvr, cv, flip = SH[k]
    px, py, tw, th = place[k]
    m = int(S.M[k][0]); q = S.Q[k][0]; fn = R.MATS[m]
    G3 = S.P[k].reshape(nu, nv_, 3); N3 = S.N[k].reshape(nu, nv_, 3); UV3 = S.UV[k].reshape(nu, nv_, 2)
    # texel centres -> (u,v) in 0..1 of the grid
    uu = (np.arange(tw) + 0.5) / tw; vv = (np.arange(th) + 0.5) / th
    UU, VV = np.meshgrid(uu, vv, indexing='xy')         # shape th x tw
    P = bilerp(G3, UU, VV, cv).reshape(-1, 3); N = bilerp(N3, UU, VV, cv).reshape(-1, 3); UVt = bilerp(UV3, UU, VV, cv).reshape(-1, 2)
    N = N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    col, nrm = fn(UVt, np.tile(q, (len(P), 1)), P, N)
    nrm = N if nrm is None else nrm
    if m in H:                                         # pháp tuyến từ độ gồ: dời điểm theo pháp tuyến rồi lấy sai phân trong ô
        h = H[m](P, UVt, q).reshape(th, tw)
        Pd = P.reshape(th, tw, 3) + N.reshape(th, tw, 3) * h[..., None]
        du = np.gradient(Pd, axis=1); dv = np.gradient(Pd, axis=0)
        nn = np.cross(du, dv); nn = nn / np.maximum(np.linalg.norm(nn, axis=2, keepdims=True), 1e-9)
        sg = np.sign((nn.reshape(-1, 3) * N).sum(1))[:, None]; sg[sg == 0] = 1
        nrm = nn.reshape(-1, 3) * sg
        ok = np.linalg.norm(np.cross(du, dv), axis=2).reshape(-1) > 1e-10
        nrm = np.where(ok[:, None], nrm, N)
        nrm = nrm * 0.6 + nrm / np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9) * 0.4
    nrm = nrm / np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9)
    alb[py:py + th, px:px + tw] = np.clip(col, 0, 1).reshape(th, tw, 3)
    nmap[py:py + th, px:px + tw] = (g_to_gl(nrm) * 0.5 + 0.5).reshape(th, tw, 3)
    # viền 1 texel (tránh lộ mép)
    alb[py - 1, px:px + tw] = alb[py, px:px + tw]; alb[py + th, px:px + tw] = alb[py + th - 1, px:px + tw]
    alb[py - 1:py + th + 1, px - 1] = alb[py - 1:py + th + 1, px]; alb[py - 1:py + th + 1, px + tw] = alb[py - 1:py + th + 1, px + tw - 1]
    nmap[py - 1, px:px + tw] = nmap[py, px:px + tw]; nmap[py + th, px:px + tw] = nmap[py + th - 1, px:px + tw]
    nmap[py - 1:py + th + 1, px - 1] = nmap[py - 1:py + th + 1, px]; nmap[py - 1:py + th + 1, px + tw] = nmap[py - 1:py + th + 1, px + tw - 1]
    # uv đỉnh
    iu = np.linspace(0, 1, nu); jv = np.linspace(0, 1, nv_, endpoint=not cv)
    U, V = np.meshgrid(iu, jv, indexing='ij')
    tu_ = (px + 0.5 + U * (tw - 1)) / PAGE; tv_ = (py + 0.5 + V * (th - 1)) / HH
    vert_uv.append(np.stack([tu_, tv_], -1).reshape(-1, 2))

# khép kín vòng (close_v): tam giác nối cột cuối -> cột đầu bị kéo ngược uv; nhân đôi cột đầu cho các lưới đó
groups = {}
off = 0
for k in range(len(S.P)):
    F, nu, nv_, uvr, cv, flip = SH[k]
    P = S.P[k]; N = S.N[k]; UVv = vert_uv[k]; T = S.T[k] - off; off += len(P)
    if cv:
        G3 = P.reshape(nu, nv_, 3); N3 = N.reshape(nu, nv_, 3); U3 = UVv.reshape(nu, nv_, 2)
        P = np.concatenate([G3, G3[:, :1]], 1).reshape(-1, 3); N = np.concatenate([N3, N3[:, :1]], 1).reshape(-1, 3)
        px, py, tw, th = place[k]
        extra = U3[:, :1].copy(); extra[..., 1] = (py + 0.5 + (th - 1) * 1.0) / HH
        U3b = U3.copy(); U3b[..., 1] = (py + 0.5 + np.linspace(0, 1, nv_, endpoint=False)[None, :] * (th - 1) * (nv_ / nv_)) / HH
        UVv = np.concatenate([U3b, extra], 1).reshape(-1, 2)
        T = T // nv_ * (nv_ + 1) + T % nv_
        # tam giác cuối vòng: j0 = nv_-1 -> j1 phải = nv_ (cột nhân đôi) chứ không phải 0
        Tij = T.copy(); rows = Tij // (nv_ + 1); cols = Tij % (nv_ + 1)
        for t_ in range(len(Tij)):
            c = cols[t_]
            if c.max() == nv_ - 1 and c.min() == 0:
                cols[t_] = np.where(c == 0, nv_, c)
        T = rows * (nv_ + 1) + cols
    m = int(S.M[k][0]); kind = R.KIND.get(m, 'go')
    Po, No = (SMORPH[k] if SMORPH[k] is not None else (P, N))
    if SMORPH[k] is not None: kind = kind + '_m'
    if R.PARTS:
        lid = np.full(len(T), SPART[k])
    else:
        cz = P[T].mean(1)[:, 2]
        lid = (cz > (R.LIDZ if R.LIDZ is not None else R.ZL + 0.02)).astype(int)
    for flag in np.unique(lid):
        sel = lid == flag
        if not sel.any(): continue
        g = groups.setdefault((flag, kind), dict(P=[], N=[], U=[], T=[], n=0, Po=[], No=[]))
        tt = T[sel]; used = np.unique(tt); remap = -np.ones(len(P), np.int64); remap[used] = np.arange(len(used))
        g['P'].append(P[used]); g['N'].append(N[used]); g['U'].append(UVv[used]); g['T'].append(remap[tt] + g['n']); g['n'] += len(used); g['Po'].append(Po[used]); g['No'].append(No[used])

hx, hy, hz = R.C0, R.C0 - R.LB, (R.LIDZ if R.LIDZ is not None else R.ZL)
def to_gl(P, piv): return g_to_gl((P - np.array(piv)) * SC)
def n_gl(N): N = N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9); return g_to_gl(N)
Gb = GLB()
ta = Gb.texture(Image.fromarray((np.clip(alb, 0, 1) ** 1.0 * 255 + 0.5).astype(np.uint8)))
tn = Gb.texture(Image.fromarray((np.clip(nmap, 0, 1) * 255 + 0.5).astype(np.uint8)))
mats = {}
for kind, r in ROUGH.items():
    mi = Gb.material(kind, tex=ta, rough=r); Gb.j['materials'][mi]['normalTexture'] = {'index': tn}
    if kind == 'kl': Gb.j['materials'][mi]['pbrMetallicRoughness']['metallicFactor'] = 0.9
    if kind == 'vang': Gb.j['materials'][mi]['pbrMetallicRoughness']['metallicFactor'] = 0.3
    mats[kind] = mi
    mm = Gb.material(kind + '_m', tex=ta, rough=r)                 # cánh sen biến hình: pháp tuyến đỉnh, không ảnh pháp tuyến
    if kind == 'vang': Gb.j['materials'][mm]['pbrMetallicRoughness']['metallicFactor'] = 0.3
    mats[kind + '_m'] = mm
def prims(flag, piv):
    out = []
    for (f, kind), g in groups.items():
        if f != flag: continue
        P = np.concatenate(g['P']); nvx = len(P)
        out.append(dict(pos=to_gl(P, piv), nrm=n_gl(np.concatenate(g['N'])), col=np.ones((nvx, 3)), uv=np.concatenate(g['U']), idx=np.concatenate(g['T']), mat=mats[kind], extras={'osn': 1}))
        if kind.endswith('_m'):
            Po = np.concatenate(g['Po']); No = np.concatenate(g['No'])
            out[-1]['morph'] = (to_gl(Po, piv) - out[-1]['pos'], n_gl(No) - out[-1]['nrm'])
    return out
root = Gb.node('ruong_goc', (0, 0, 0))
Gb.node('than', (0, 0, 0), mesh=Gb.mesh('than', prims(0, (R.C0, R.C0, 0.0))), parent=root)
PARTS = R.PARTS or {1: dict(piv=(hx - R.C0, hy - R.C0, hz), axis=(1, 0, 0), ang=108.0, delay=0.0)}
tracks = []; wtracks = []
for pid, pp in PARTS.items():
    if not any(f == pid for (f, kd) in groups): continue
    pv = np.array(pp['piv']) + np.array([R.C0, R.C0, 0.0])
    pr = prims(pid, tuple(pv)); mi_ = Gb.mesh('p%d' % pid, pr); hasm = False
    for j, p_ in enumerate(pr):
        if 'morph' in p_:
            dp, dn = p_['morph']; hasm = True
            Gb.j['meshes'][mi_]['primitives'][j]['targets'] = [{'POSITION': Gb.acc(dp.astype(np.float32), 'VEC3', minmax=True), 'NORMAL': Gb.acc(dn.astype(np.float32), 'VEC3')}]
    if hasm:
        for j, p_ in enumerate(pr):
            if 'morph' not in p_:
                z3 = np.zeros((len(p_['pos']), 3), np.float32)
                Gb.j['meshes'][mi_]['primitives'][j]['targets'] = [{'POSITION': Gb.acc(z3, 'VEC3', minmax=True), 'NORMAL': Gb.acc(z3, 'VEC3')}]
        Gb.j['meshes'][mi_]['weights'] = [0.0]
    nd = Gb.node('nap' if pid == 1 and not R.PARTS else 'p%d' % pid, tuple(g_to_gl((pv - np.array([R.C0, R.C0, 0])) * SC)), mesh=mi_, parent=root)
    ax = g_to_gl(np.array(pp['axis'], float)); ax = ax / np.linalg.norm(ax); A = pp['ang']; dl = pp['delay']
    tm = np.linspace(0, 1.4, 43); x = np.clip((tm - 0.1 - dl) / 0.85, 0, 1)
    c1 = 1.2; c3 = c1 + 1; e = 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2      # easeOutBack: mở êm, nảy nhẹ rồi đứng
    ang = np.radians(A * e); tm = list(tm)
    if hasm: wtracks.append((nd, tm, e))
    tracks.append((nd, 'rotation', tm, [[ax[0] * math.sin(a / 2), ax[1] * math.sin(a / 2), ax[2] * math.sin(a / 2), math.cos(a / 2)] for a in ang]))
Gb.animation('mo_nap', tracks)
an = Gb.j['animations'][-1]
for nd, tm, e in wtracks:
    ia = Gb.acc(np.asarray(tm, np.float32), 'SCALAR', target=None, minmax=True)
    io_ = Gb.acc(np.asarray(e, np.float32), 'SCALAR', target=None)
    an['samplers'].append({'input': ia, 'output': io_, 'interpolation': 'LINEAR'})
    an['channels'].append({'sampler': len(an['samplers']) - 1, 'target': {'node': nd, 'path': 'weights'}})
Gb.save(OUT)
print(OUT, os.path.getsize(OUT) // 1024, 'KB', sum(g['n'] for g in groups.values()), 'verts, atlas', PAGE, HH)
Image.fromarray((np.clip(alb, 0, 1) * 255).astype(np.uint8)).resize((PAGE // 4, HH // 4)).save('/tmp/claude-0/ruong/atlas_prev.png')
