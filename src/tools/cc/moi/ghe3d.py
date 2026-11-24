#!/usr/bin/env python3
# GHE TRÊN SÔNG VÀM dựng 3D (11-24 Link "vẽ thuyền qua lại bên sông vàm, ghe thương hồ, ghe chợ nổi"): cùng bộ bắn tia của
# bay3d.py (góc nhìn vườn xoay 45 nghiêng 30, bóng đổ, AO, viền mảnh). Thay cho hình nét dẹt ui/img/ghe (tools/ghe.js),
# giữ đúng tên + cách đặt của ghe_ve.gd: gốc = giữa ghe ngay mặt nước; trục ghe u theo góc sông th (ô làng: u = (32,16),
# v = (-32,16) đơn vị), mũi về +u khi s = 1; cây bẹo ở u = .58 C (C = 1,3 ô), đòn ngang cao 74, lửng 48 (món treo do code vẽ).
#   python3 ghe3d.py OUTDIR key [key ...]    key: ghe_u_<k> (th = .05k) | ghe_v | cho_<song|song_dong|song_tay>_<0-3> | xu_<p|m><mui>_<k> (th = .05k)
#   ra <key>.webp (đặt trên nước, 6 px / đơn vị) + <key>.json [lệch x, lệch y, rộng, cao] (đơn vị làng) như ui/snap/ghe.json
import os, sys, math, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bay3d as B
from bay3d import V, nz, hexc, sstep, vnoise, Tube, Torus, Line, Ball, Box, M, Scene, F32
import numpy as np

TILE = 45.2548          # 1 ô làng = 45,25 đơn vị thế giới (ô vẽ ra 32 x 16)
CH = 1.3                # nửa dài ghe (ô) như ghe_ve.C
ZK = 1 / .8660254       # cao trên màn (đơn vị) -> z thế giới


# ------------------------------------------------------------ tăng tốc: bỏ qua khối ở xa (cầu bao)
def _fast_sdf(self, P, ids=False):
    """min khoảng cách qua mọi khối, giữ min chạy (không dựng ma trận n x số khối: ghe chợ đầy trái tốn 9 GB)"""
    n = len(P)
    if n > 120000:
        parts = [_fast_sdf(self, P[i:i + 120000], ids) for i in range(0, n, 120000)]
        if ids:
            return np.concatenate([p[0] for p in parts]), np.concatenate([p[1] for p in parts])
        return np.concatenate(parts)
    best = np.full(n, 1e9, F32); arg = np.zeros(n, np.int32)
    for i, o in enumerate(self.objs):
        c, r = o.bound
        db = (np.linalg.norm(P - c, axis=1) - r).astype(F32)
        near = db < 1.0
        d = db
        if near.any():
            d = db.copy()
            d[near] = o.sdf(P[near])
        m = d < best
        best[m] = d[m]; arg[m] = i
    if ids:
        return best, arg
    return best


Scene.sdf = _fast_sdf


class Frame:
    """khung ghe: u dọc ghe (mũi +), v ngang, z lên -> thế giới (theo góc sông th, chiều s, trục u|v)"""
    def __init__(s, th=0.0, sgn=1.0, ax='u'):
        c, si = math.cos(th), math.sin(th)
        # ô: (u, v) -> xoay th -> thế giới x = v*TILE, y = u*TILE (trục u); trục v: lật x màn hình
        fu = V(si, c, 0) * sgn            # hướng mũi trong thế giới (theo 1 đơn vị)
        fv = V(c, -si, 0) * sgn
        if ax == 'v':
            fu = V(fu[1], fu[0], 0); fv = V(fv[1], fv[0], 0)
        s.U = nz(fu); s.Vv = nz(np.cross(V(0, 0, 1), s.U)); s.Z = V(0, 0, 1)

    def w(s, u, v, z):
        return s.U * u + s.Vv * v + s.Z * z

    def loc(s, P):
        return P @ s.U, P @ s.Vv, P[:, 2]


class Hull:
    """thân ghe ván: mặt cắt nửa elip, rộng w(a), mép trên cong vểnh 2 đầu, đáy cong; rỗng, có vách dày t"""
    def __init__(s, fr, L, Wb, D, Hs, rise_b, rise_s, t=.9, mat='ghe', bow_sharp=1.0):
        s.fr = fr; s.L = L; s.Wb = Wb; s.D = D; s.Hs = Hs; s.rb = rise_b; s.rs = rise_s; s.t = t; s.mat = mat; s.bs = bow_sharp
        s.bound = (V(0, 0, Hs * .3), L + 4)

    def prof(s, a):
        aa = np.abs(a)
        w = s.Wb * np.sqrt(np.clip(1 - aa ** (2.0 + .6 * (a > 0) * s.bs), 0, 1))
        zt = s.Hs + np.where(a > 0, s.rb, s.rs) * aa ** 3
        zb = -s.D * (1 - aa ** 3.2) + (s.Hs * .2) * aa ** 6
        return w, zt, zb

    def parts(s, P):
        u, v, z = s.fr.loc(P)
        a = np.clip(u / s.L, -1, 1)
        w, zt, zb = s.prof(a)
        dd = np.maximum(zt - zb, .5)
        k = np.sqrt((v / np.maximum(w, .3)) ** 2 + ((z - zt) / dd) ** 2)
        outer = (k - 1) * np.minimum(np.maximum(w, .3), dd) * .75
        wi = np.maximum(w - s.t, .05); di = np.maximum(dd - s.t, .05)
        ki = np.sqrt((v / wi) ** 2 + ((z - zt) / di) ** 2)
        inner = (ki - 1) * np.minimum(wi, di) * .75
        ends = np.abs(u) - s.L
        return u, v, z, a, w, zt, zb, outer, inner, ends

    def sdf(s, P):
        u, v, z, a, w, zt, zb, outer, inner, ends = s.parts(P)
        d = np.maximum(outer, -inner)                       # vỏ
        d = np.maximum(d, z - zt)                           # hở trên
        d = np.maximum(d, ends)
        # sạp ván lót lòng ghe
        zf = np.maximum(zb + (zt - zb) * .42, .5)
        fl = np.maximum(np.abs(z - zf) - .35, inner)
        fl = np.maximum(fl, ends)
        return np.minimum(d, fl)

    def local(s, P):
        return s.fr.loc(P)


class Cone:
    """nón lá: đỉnh ở trên, tâm đáy C, bán kính đáy r, cao h"""
    def __init__(s, C, r, h, mat='non'):
        s.C = V(*C); s.r = r; s.h = h; s.mat = mat; s.bound = (s.C + V(0, 0, h / 2), max(r, h) + 1)

    def sdf(s, P):
        d = P - s.C
        q = np.hypot(d[:, 0], d[:, 1]); y = d[:, 2]
        # mặt nón mỏng (vỏ) 0..h
        k = s.r / s.h
        surf = (q - k * (s.h - y)) / math.sqrt(1 + k * k)
        shell = np.abs(surf) - .12
        return np.maximum(shell, np.maximum(-y, y - s.h))


class Cut:
    """khối bị cắt bởi mặt phẳng (bỏ phía pháp tuyến)"""
    def __init__(s, o, P0, n):
        s.o = o; s.P0 = V(*P0); s.n = nz(V(*n)); s.mat = o.mat; s.bound = o.bound
        for k in ('col', 'dk', 'sp', 'pw', 'emit', 'wv', 'A', 'ax', 'shell'):
            if hasattr(o, k): setattr(s, k, getattr(o, k))

    def sdf(s, P):
        return np.maximum(s.o.sdf(P), (P - s.P0) @ s.n)

    def local(s, P):
        return s.o.local(P)


# ------------------------------------------------------------ màu thêm cho ghe
_alb0 = B.albedo


def albedo(obj, P):
    m = obj.mat
    n = len(P)
    if m == 'ghe':
        u, v, z, a, w, zt, zb, outer, inner, ends = obj.parts(P)
        out = (np.abs(outer) < np.abs(inner))
        dz = zt - z                                             # sâu dưới mép ghe
        L = obj.L
        nz_ = vnoise(P * V(.25, .25, 1.5), 1, 21) - .5
        seam = np.exp(-(((dz / 1.05) % 1.0 - .5) / .08) ** 2)  # đường ván dọc thân
        bw = obj.bw
        band = getattr(obj, 'band', None)
        if band is None:     # xuồng gỗ mộc: ván dầu chai
            wood = hexc('#9a6a3c')[None] * (1 + .14 * nz_)[:, None]
            c_o = np.where((dz < .4)[:, None], hexc('#5e3a20')[None], wood)
        else:
            tar = hexc('#3d281a')[None] * (1 + .12 * nz_)[:, None]
            c_o = np.where((dz < bw + .4)[:, None], hexc(obj.line)[None], tar)
            c_o = np.where((dz < bw)[:, None], band[None] * (1 + .08 * nz_)[:, None], c_o)
            c_o = np.where((dz < .5)[:, None], hexc(obj.trim)[None], c_o)
            # mũi sơn đỏ + mắt ghe
            bow = (u > L * .84)
            c_o = np.where((bow & (dz < bw + .4))[:, None], hexc('#b8382a')[None], c_o)
            eu = L * .7; ec = bw * .55
            ex = (u - eu) / (bw * 1.25); ey = (dz - ec) / (bw * .42)
            al = np.abs(ex) ** 1.6 + ey ** 2 * (1 + .6 * np.abs(ex))     # mắt hình hạnh
            pu = np.hypot(ex - .12, ey * .9)
            eye = out & (al < 1.0)
            c_o = np.where((out & (al < 1.35) & (dz < bw))[:, None], hexc('#b8382a')[None], c_o)
            c_o = np.where(eye[:, None], hexc('#f4efe2')[None], c_o)
            c_o = np.where((eye & (pu < .42))[:, None], hexc('#1a1412')[None], c_o)
            c_o = np.where((eye & (np.hypot(ex - .0, ey + .1) < .12))[:, None], hexc('#f4efe2')[None], c_o)
        c_o = c_o * (1 - .22 * seam * (dz > .5))[:, None]
        # lòng ghe gỗ, sườn ngang
        rib = np.exp(-((((u / 5.0) % 1.0) - .5) / .07) ** 2)
        c_i = hexc('#9c6c40')[None] * (1 + .12 * nz_ - .3 * rib)[:, None]
        if band is not None:   # lòng mép trên sơn cùng màu thân, nẹp viền
            c_i = np.where((dz < bw * .55)[:, None], band[None] * (.9 + .08 * nz_)[:, None], c_i)
            c_i = np.where((dz < .5)[:, None], hexc(obj.trim)[None], c_i)
        c = np.where(out[:, None], c_o, c_i)
        zf = np.maximum(zb + (zt - zb) * .42, .5)
        onfl = (np.abs(z - zf) < .5) & ~out
        plank = np.exp(-((((v / 1.5) % 1.0) - .5) / .08) ** 2)
        cf = hexc('#b0814f')[None] * (1 - .3 * plank)[:, None] * (1 + .12 * nz_)[:, None]
        return np.where(onfl[:, None], cf, c)
    if m == 'van':   # vách nhà ghe: ván ngang sơn, cửa sổ
        q = (P - obj.C) @ obj.A.T
        h = obj.h
        col = getattr(obj, 'col', hexc('#a9cdd0'))
        ln = np.exp(-((((q[:, 2] + h[2]) / .9) % 1.0 - .5) / .1) ** 2)
        c = col[None] * (1 - .18 * ln + .08 * (vnoise(P, 1.5, 31) - .5))[:, None]
        side = np.abs(np.abs(q[:, 1]) - h[1]) < .3
        endf = np.abs(np.abs(q[:, 0]) - h[0]) < .3
        sp_ = obj.win
        fx = ((q[:, 0] + h[0]) / sp_) % 1.0
        inner_ = (q[:, 0] > -h[0] + sp_ * .3) & (q[:, 0] < h[0] - sp_ * .3)
        wy = (q[:, 2] > -h[2] * .05) & (q[:, 2] < h[2] * .55)
        fr_ = side & inner_ & wy & (np.abs(fx - .5) < .26)
        gl = side & inner_ & (q[:, 2] > h[2] * .02) & (q[:, 2] < h[2] * .48) & (np.abs(fx - .5) < .2)
        c = np.where(fr_[:, None], hexc('#f0e6c8')[None], c)
        c = np.where(gl[:, None], hexc('#2c3438')[None], c)
        sh = side & inner_ & wy & (np.abs(np.abs(fx - .5) - .32) < .055)     # cánh cửa sổ mở
        c = np.where(sh[:, None], hexc(getattr(obj, 'sh', '#b8452e'))[None], c)
        door = endf & (np.abs(q[:, 1]) < h[1] * .26) & (q[:, 2] < h[2] * .6)
        dfr = endf & (np.abs(q[:, 1]) < h[1] * .33) & (q[:, 2] < h[2] * .7) & ~door
        c = np.where(dfr[:, None], hexc('#f0e6c8')[None], c)
        c = np.where(door[:, None], hexc('#7a3a24')[None] * (1 - .25 * (np.abs(q[:, 1]) < .12))[:, None], c)
        fw = endf & (q[:, 0] > 0) & (np.abs(np.abs(q[:, 1]) - h[1] * .66) < h[1] * .14) & (q[:, 2] > 0) & (q[:, 2] < h[2] * .5)
        c = np.where(fw[:, None], hexc('#2c3438')[None], c)
        return c
    if m == 'ton':   # mái tôn sóng
        u, v, z = obj.fr.loc(P)
        rg = .5 + .5 * np.cos(u * 2 * np.pi / 1.1)
        col = getattr(obj, 'col', hexc('#9a4b34'))
        return col[None] * (.8 + .25 * rg + .1 * (vnoise(P, .8, 32) - .5))[:, None]
    if m == 'bat':   # bạt sọc
        u, v, z = obj.fr.loc(P)
        st = (np.floor(u / 2.4) % 2) == 0
        c1 = getattr(obj, 'col', hexc('#3f74b5')); c2 = getattr(obj, 'col2', hexc('#e8e2d0'))
        c = np.where(st[:, None], c1[None], c2[None])
        return c * (.9 + .12 * (vnoise(P, .6, 33) - .5))[:, None]
    if m == 'dco':   # máy đuôi tôm sơn
        col = getattr(obj, 'col', hexc('#c23b2b'))
        return col[None] * (.92 + .1 * (vnoise(P, 2, 34) - .5))[:, None]
    if m == 'thung':   # thùng gỗ ván thưa, nẹp góc sẫm
        q = (P - obj.C) @ obj.A.T
        h = obj.h
        col = getattr(obj, 'col', hexc('#b8875a'))
        ln = np.exp(-((((q[:, 2] + h[2]) / 1.0) % 1.0 - .5) / .07) ** 2)
        edge = (((np.abs(q) > (h - .45)[None]).sum(1)) >= 2)
        c = col[None] * (1 - .35 * ln + .14 * (vnoise(P * V(1, 1, 3), 1, 36) - .5))[:, None]
        c = np.where(edge[:, None], (col * .62)[None], c)
        # chữ đóng dấu trên hông thùng
        stamp = (np.abs(q[:, 2]) < h[2] * .25) & (np.abs(q[:, 0]) < h[0] * .4) & (np.abs(np.abs(q[:, 1]) - h[1]) < .2)
        return np.where(stamp[:, None], (col * .55)[None], c)
    if m == 'baog':    # bao gạo dệt trắng, sọc màu
        q = (P - obj.C) @ obj.A.T
        g = .5 + .5 * np.sin((P[:, 0] + P[:, 1]) * 7) * np.sin((P[:, 0] - P[:, 1] + P[:, 2]) * 7)
        c = obj.col[None] * (.8 + .16 * g + .1 * (vnoise(P, .8, 37) - .5))[:, None]
        st = np.abs(np.abs(q[:, 0]) - obj.h[0] * .55) < .3
        return np.where(st[:, None], obj.stripe[None], c)
    if m == 'cui':     # củi chẻ
        col = getattr(obj, 'col', hexc('#8a6a44'))
        return col[None] * (.8 + .35 * vnoise(P * V(.6, .6, 3), 1, 38))[:, None]
    if m in ('muoi', 'nuoc'):
        col = getattr(obj, 'col', hexc('#f2f0ea'))
        return col[None] * (.9 + .16 * (vnoise(P, 3, 39) - .5))[:, None]
    if m == 'chau':  # chậu đất
        return hexc('#b0603a')[None] * (.9 + .15 * (vnoise(P, 2, 35) - .5))[:, None]
    if m == 'go2':   # đòn, ván gỗ
        base = getattr(obj, 'col', hexc('#7a4e2c'))
        base = hexc(base) if isinstance(base, str) else base
        return base[None] * (.85 + .3 * vnoise(P * V(1, 1, 3), 1, 23))[:, None]
    if m == 'la':    # lá xanh ngọn cây bẹo
        return hexc('#5f9a3a')[None] * (.75 + .5 * vnoise(P, .8, 24))[:, None]
    if m == 'non':
        d = P - obj.C
        y = d[:, 2]
        ring = np.exp(-(((y / .55) % 1.0 - .5) / .12) ** 2)
        return hexc('#e6d6a2')[None] * (1 - .18 * ring)[:, None]
    if m in ('ao', 'quan', 'da', 'toc'):
        c = {'ao': '#5b95c4', 'quan': '#2a2626', 'da': '#e2b48c', 'toc': '#221a14'}[m]
        base = getattr(obj, 'col', hexc(c))
        return base[None] * (.9 + .15 * vnoise(P, .6, 25))[:, None]
    if m in ('dua', 'bi', 'bao', 'chuoi', 'khom', 'dua2', 'chum', 'cam'):
        if m == 'dua':   # dưa hấu sọc
            d = P - obj.C
            th = np.arctan2(d[:, 1], d[:, 0]) + d[:, 2] * .2
            st = (np.sin(th * 8) > .2)
            return np.where(st[:, None], hexc('#2e5e22')[None], hexc('#5e9a3e')[None])
        if m == 'bi':    # bí đỏ múi
            d = P - obj.C
            th = np.arctan2(d[:, 1], d[:, 0])
            return hexc('#e0802a')[None] * (.8 + .25 * np.abs(np.cos(th * 5)))[:, None]
        if m == 'bao':   # bao bố đan
            d = obj.local(P) if hasattr(obj, 'local') else P
            g = np.exp(-((((P[:, 0] + P[:, 1]) * 1.8) % 1.0 - .5) / .2) ** 2) * .5 + np.exp(-((((P[:, 0] - P[:, 1]) * 1.8) % 1.0 - .5) / .2) ** 2) * .5
            return hexc('#a8895a')[None] * (.82 + .18 * g + .12 * vnoise(P, .7, 27))[:, None]
        if m == 'khom':
            g = np.sin((P[:, 0] + P[:, 2]) * 3.2) * np.sin((P[:, 1] - P[:, 2]) * 3.2)
            return hexc('#c8922e')[None] * (.8 + .3 * (g > .25))[:, None]
        c = {'bao': '#e8e0cc', 'chuoi': '#e8c838', 'khom': '#c89a3a', 'dua2': '#7a9a3a', 'chum': '#5a3424', 'cam': '#e89a2a'}[m]
        base = getattr(obj, 'col', hexc(c))
        return base[None] * (.85 + .25 * vnoise(P, .7, 26))[:, None]
    return _alb0(obj, P)


B.albedo = albedo


def _bbox(self):
    pts = []
    for o in self.objs:
        c, r = o.bound
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    pts.append(c + V(sx, sy, sz) * r)
    return np.array(pts, np.float32)


Scene.bbox = _bbox
SPEC_EXTRA = {'chum': (.5, 40), 'dua': (.25, 30)}


# ------------------------------------------------------------ dựng các món trên ghe (11-24 v2: Link "tự vẽ lại cho đẹp, đéo cần vẽ người")
def zt_at(h, a):
    _, zt, _ = h.prof(np.array([a]))
    return float(zt[0])


def w_at(h, a):
    w, _, _ = h.prof(np.array([a]))
    return float(w[0])


def paint(h, band, bw, trim='#b8382a', line='#eadfbf'):
    h.band = None if band is None else hexc(band); h.bw = bw; h.trim = trim; h.line = line
    return h


def bamboo(a, b, r=.45, col='#c9a868'):
    return M(Line([tuple(a), tuple(b)], r, 'go2'), col=hexc(col))


def beo(fr, u, zf, zbar=74 * ZK):
    """cây bẹo: sào tre cao, đòn ngang trên ngọn (2 đầu đòn để code treo món đơn hàng), chùm lá ngọn, treo 2 món hàng mẫu giữa sào"""
    o = [B.stake(*fr.w(u, 0, zf)[:2], zf, zbar + 6, .75, nodes=8.0)]
    lat = .42 * TILE
    a = fr.w(u, -lat, zbar); b = fr.w(u, lat, zbar)
    o.append(M(Line([tuple(a), tuple(b)], .55, 'go2'), col=hexc('#9a7444')))
    for e in (a, b):   # móc treo ở 2 đầu đòn
        o.append(M(Torus(tuple(e + V(0, 0, -.9)), tuple(fr.U), .55, .14, 'thep'), col=hexc('#6a6a6a')))
    o += [M(Torus(tuple(fr.w(u, 0, zbar)), (0, 0, 1), .85, .26, 'may'), col=hexc('#6a4424'))]
    o.append(M(Torus(tuple(fr.w(u, 0, 48 * ZK)), (0, 0, 1), .85, .26, 'may'), col=hexc('#6a4424')))   # nút buộc móc giữa sào
    # đầu sào: quấn dây mây 3 vòng (không chùm lá, nhìn ra cây dừa)
    for k in range(3):
        o.append(M(Torus(tuple(fr.w(u, 0, zbar + 2.0 + k * .7)), (0, 0, 1), .8, .22, 'may'), col=hexc('#6a4424')))
    # món treo: code ghe_ve vẽ món đơn hàng ở 2 đầu đòn + giữa sào cao 48 -> không nướng sẵn trái treo
    return o


def fruit(fr, k, c, cs=1.0):
    c = V(*c)
    if k == 'dua':
        return [Ball(tuple(c), 2.2 * cs, 'dua', sq=(1.25, 1, .95))]
    if k == 'bi':
        return [Ball(tuple(c), 1.9 * cs, 'bi', sq=(1.1, 1.1, .8)), M(Line([tuple(c + V(0, 0, 1.3 * cs)), tuple(c + V(0, 0, 2.0 * cs))], .25 * cs, 'go2'), col=hexc('#5a6a2a'))]
    if k == 'khom':   # trái khóm: thân mắt dứa + chùm lá nhọn
        o = [Ball(tuple(c), 1.35 * cs, 'khom', sq=(1, 1, 1.3))]
        top = c + V(0, 0, 1.5 * cs)
        for q in range(6):
            ang = q / 6 * 2 * np.pi
            d = V(math.cos(ang), math.sin(ang), 0)
            o.append(M(Line([tuple(top), tuple(top + d * .9 * cs + V(0, 0, 1.6 * cs))], [.32 * cs, .08 * cs], 'la'), col=hexc('#4f8a3a')))
        o.append(M(Line([tuple(top), tuple(top + V(0, 0, 2.0 * cs))], [.3 * cs, .08 * cs], 'la'), col=hexc('#4f8a3a')))
        return o
    if k == 'dua2':
        return [Ball(tuple(c), 1.5 * cs, 'dua2')]
    if k == 'xoai':
        return [M(Ball(tuple(c), 1.2 * cs, 'cam', sq=(1.45, 1, .9)), col=hexc('#e8c048'))]
    if k == 'lua':   # lúa vàng đầy thúng
        return [M(Ball(tuple(c + V(0, 0, -.6)), 2.0 * cs, 'muoi', sq=(1, 1, .35)), col=hexc('#d8b048'))]
    if k == 'cam':
        return [Ball(tuple(c), 1.0 * cs, 'cam')]
    if k == 'bao':   # bao bố gối: hộp bo tròn
        return [Box(tuple(c + V(0, 0, -.5 * cs)), (fr.U, fr.Vv, (0, 0, 1)), (2.6 * cs, 1.7 * cs, 1.1 * cs), 'bao', rr=1.0 * cs)]
    if k == 'khoai':
        return [M(Ball(tuple(c), 1.0 * cs, 'bi', sq=(1.7, 1, .9)), col=hexc('#8a3e4a'))]
    if k == 'chuoi':   # buồng chuối
        o = []
        for q in range(5):
            ang = q / 5 * 2 * np.pi
            d = fr.U * math.cos(ang) + fr.Vv * math.sin(ang)
            o.append(Line([tuple(c + d * .6 * cs + V(0, 0, 1.2 * cs)), tuple(c + d * 1.9 * cs + V(0, 0, -.4 * cs)), tuple(c + d * 1.6 * cs + V(0, 0, -1.6 * cs))], [.55 * cs, .6 * cs, .35 * cs], 'chuoi'))
        o.append(M(Line([tuple(c + V(0, 0, -1.4 * cs)), tuple(c + V(0, 0, 2.2 * cs))], .4 * cs, 'go2'), col=hexc('#6a7a3a')))
        return o
    return []


def heap(fr, kinds, u0, u1, zf, wd, seed=1, cs=1.4, layers=3, sf=1.0):
    """đống hàng chất mô giữa ghe: lớp dưới rộng, lên trên hẹp dần"""
    rs = np.random.RandomState(seed)
    o = []
    step = 3.6 * cs * sf
    for ly in range(layers):
        sh = ly * step * .5
        uu = u0 + sh + step / 2
        k_i = 0
        while uu < u1 - sh - step / 2 + 1e-3:
            nj = max(1, int((wd * 2 - ly * step) / step))
            for j in range(nj):
                v = (j - (nj - 1) / 2) * step + rs.uniform(-.4, .4)
                k = kinds[(k_i + j + ly) % len(kinds)]
                o += fruit(fr, k, fr.w(uu + rs.uniform(-.5, .5), v, zf + (2.0 * sf + ly * 2.9 * sf) * cs), cs)
            uu += step
            k_i += 1
    return o


def thung(fr, u, v, zf, r, kind, seed=0):
    """thúng tre đựng trái"""
    base = fr.w(u, v, zf)
    t = Tube(tuple(base), (0, 0, 1), 2.0, [(0, r * .8), (1, r)], 'dan', shell=.3, open1=True, wv=(26, .08))
    o = [M(t, col=hexc('#c7a466'))]
    rs = np.random.RandomState(seed)
    for k in range(6):
        ang = k / 6 * 2 * np.pi + rs.uniform(0, .5)
        rr = r * .55 if k else 0
        c = base + V(math.cos(ang) * rr, math.sin(ang) * rr, 2.0 + (.9 if k == 0 else 0))
        o += fruit(fr, kind, c, .75 if kind not in ('cam',) else 1.0)
    return o


def cabin(fr, h, u0, u1, hw, Hw, wall='#a9cdd0', roof='#9a4b34', shut='#b8452e'):
    """nhà ghe: vách ván sơn có cửa sổ, mái tôn khum, chậu kiểng trên mái"""
    L = h.L
    zd = min(zt_at(h, u0 / L), zt_at(h, u1 / L)) - .6
    uc = (u0 + u1) / 2; hl = (u1 - u0) / 2
    wall_b = Box(tuple(fr.w(uc, 0, zd + Hw / 2)), (fr.U, fr.Vv, (0, 0, 1)), (hl, hw, Hw / 2), 'van', rr=.25)
    wall_b.col = hexc(wall); wall_b.win = 5.2; wall_b.sh = shut
    o = [wall_b]
    R = hw * 1.35
    zc = zd + Hw - R * .62
    t = Tube(tuple(fr.w(u0 - 1.6, 0, zc)), tuple(fr.U), (u1 - u0) + 3.2, [(0, R), (1, R)], 'ton', shell=.35, open0=True, open1=True)
    t.fr = fr; t.col = hexc(roof)
    o.append(Cut(t, tuple(fr.w(0, 0, zd + Hw - .25)), (0, 0, -1)))
    o[-1].fr = fr
    # chậu kiểng đặt mép mái phía trước
    ztop = zc + R
    for i, vv in enumerate((-hw * .35, hw * .3)):
        pc = fr.w(u1 - 2.8 - i * 4.5, vv, ztop - .3)
        o += seedling(fr, pc, 1.7, 2 + i)
    return o, zd


def engine(fr, h, col='#c23b2b'):
    """máy đuôi tôm ở lái: thân máy, cần lái, cây láp dài thò xuống nước"""
    L = h.L
    zs = zt_at(h, -.9) - .3
    c = fr.w(-L * .9, 0, zs + 1.0)
    o = [M(Box(tuple(c), (fr.U, fr.Vv, (0, 0, 1)), (1.4, 1.0, 1.0), 'dco', rr=.35), col=hexc(col), sp=.35, pw=30)]
    o.append(M(Box(tuple(c + V(0, 0, 1.1)), (fr.U, fr.Vv, (0, 0, 1)), (1.0, .8, .25), 'dco', rr=.2), col=hexc('#3a3a3a')))
    a = c - fr.U * 1.2
    b = fr.w(-L * 1.0 - 9, 0, -5.0)
    o.append(M(Line([tuple(a), tuple(b)], .28, 'thep'), col=hexc('#8a8a86')))
    o.append(M(Ball(tuple(b), .9, 'thep', sq=(.4, 1.2, 1.2)), col=hexc('#b0a060')))
    o.append(M(Line([tuple(c + fr.U * 1.2 + V(0, 0, .4)), tuple(c + fr.U * 6.0 + fr.Vv * 1.0 + V(0, 0, 1.6))], .22, 'thep'), col=hexc('#4a4a4a')))
    return o


def deck(fr, h, a0, a1, col=None):
    """sàn ván mũi / lái ngang mép ghe"""
    L = h.L
    am = (a0 + a1) / 2
    z = zt_at(h, am) - .55
    ae = max(abs(a0), abs(a1))
    c = col if col is not None else (h.band * .92 if getattr(h, 'band', None) is not None else hexc('#8a5a32'))
    return [M(Box(tuple(fr.w(am * L, 0, z)), (fr.U, fr.Vv, (0, 0, 1)), (abs(a1 - a0) * L / 2, max(w_at(h, ae) - .4, .5), .3), 'go2', rr=.15), col=c)]


def thwarts(fr, h, list_a, col='#6a4024'):
    L = h.L
    o = []
    for uu in list_a:
        o.append(M(Box(tuple(fr.w(uu * L, 0, zt_at(h, uu) - .5)), (fr.U, fr.Vv, (0, 0, 1)), (.7, w_at(h, uu) - .3, .3), 'go2', rr=.15), col=hexc(col)))
    return o


def awning(fr, h, u0, u1, zf, col, col2):
    """mui bạt sọc trên khung tre (ghe chợ)"""
    L = h.L
    zt0 = zt_at(h, 0)
    hw = w_at(h, (u0 + u1) / 2 / L)
    R = hw * 1.05
    zc = zt0 + 4.0
    o = []
    for uu in (u0 + 1, u1 - 1):
        for vv in (-hw + 1, hw - 1):
            o.append(bamboo(fr.w(uu, vv, zt0 - .5), fr.w(uu, vv * .95, zc + .6), .32))
    t = Tube(tuple(fr.w(u0, 0, zc)), tuple(fr.U), u1 - u0, [(0, R), (1, R)], 'bat', shell=.22, open0=True, open1=True)
    t.fr = fr; t.col = hexc(col); t.col2 = hexc(col2)
    c = Cut(t, tuple(fr.w(0, 0, zc + .3)), (0, 0, -1)); c.fr = fr; c.col2 = t.col2
    o.append(c)
    return o


def oars(fr, h, side=1.0):
    """2 cây chèo gác ngang xuồng, cán gác mép, lưỡi chìa ra nước"""
    L = h.L
    o = []
    for i, uu in enumerate((-.25, .15)):
        z = zt_at(h, uu) + .3
        a = fr.w(uu * L - 2, -side * (w_at(h, uu) - 1.0), z)
        b = fr.w(uu * L + 3 + i, side * (w_at(h, uu) + 9.0), z - 1.2)
        o.append(M(Line([tuple(a), tuple(b)], .28, 'go2'), col=hexc('#b08a52')))
        d = nz(b - a)
        o.append(M(Box(tuple(b - d * 1.2), (d, nz(np.cross(V(0, 0, 1), d)), (0, 0, 1)), (2.2, .9, .12), 'go2', rr=.1), col=hexc('#b08a52')))
    return o


def rope(fr, h, a):
    L = h.L
    return [M(Torus(tuple(fr.w(a * L, 0, zt_at(h, a) - .2)), (0, 0, 1), 1.3, .38, 'day'), col=hexc('#c8b07a'))]


def crate(fr, u, v, z0, hx, hy, hz, col='#b8875a', rot=0.0):
    """thùng gỗ ván thưa có nẹp góc"""
    c_, s_ = math.cos(rot), math.sin(rot)
    a0 = fr.U * c_ + fr.Vv * s_; a1 = nz(np.cross(V(0, 0, 1), a0))
    b = Box(tuple(fr.w(u, v, z0 + hz)), (a0, a1, (0, 0, 1)), (hx, hy, hz), 'thung', rr=.18)
    b.col = hexc(col)
    o = [b]
    C = V(*fr.w(u, v, z0 + hz * 2 + .12))
    for e in (-.5, .5):   # dây chằng ngang nắp thùng
        o.append(M(Line([tuple(C + a0 * e * hx - a1 * hy), tuple(C + a0 * e * hx + a1 * hy)], .16, 'day'), col=hexc('#c8b07a')))
    return o


def crates(fr, h, u0, u1, zf, seed=3):
    """khoang hàng trước của ghe thương hồ: 2 tầng thùng gỗ, bao bố chặn, dây chằng"""
    L = h.L
    rs = np.random.RandomState(seed)
    o = []
    cols = ['#b8875a', '#a87a4e', '#c49766', '#9c6e44']
    uu = u0
    while uu < u1 - 4:
        a = uu / L
        wd = w_at(h, min(abs(a) + .06, .99)) - 1.2
        hx = rs.uniform(2.3, 2.9)
        n = 2 if wd > 7 else 1
        for j in range(n):
            hy = (wd / n) - .25
            v = (j - (n - 1) / 2) * (wd * 2 / n)
            o += crate(fr, uu + hx, v, zf, hx, hy * .96, rs.uniform(1.9, 2.3), cols[rs.randint(4)], rs.uniform(-.04, .04))
            if rs.rand() < .7:   # tầng 2 nhỏ hơn
                o += crate(fr, uu + hx + rs.uniform(-.3, .3), v + rs.uniform(-.4, .4), zf + 4.3, hx * .85, hy * .8, rs.uniform(1.6, 2.0), cols[rs.randint(4)], rs.uniform(-.08, .08))
        uu += hx * 2 + .35
    return o


def seedling(fr, c, sz=1.0, kind=0):
    """chậu cây giống: chậu đất + cây con (0 cây ăn trái lá sẫm, 1 kiểng lá dài, 2 mai vàng, 3 cau con, 4 cam con có trái)"""
    o = [Tube(tuple(c), (0, 0, 1), 1.8 * sz, [(0, .85 * sz), (1, 1.2 * sz)], 'chau', shell=.25, open1=True)]
    top = V(*c) + V(0, 0, 1.6 * sz)
    if kind in (0, 4):
        o.append(M(Line([tuple(top), tuple(top + V(0, 0, 2.4 * sz))], .22 * sz, 'go2'), col=hexc('#6a4a2a')))
        for k in range(4):
            ang = k * 1.6
            o.append(M(Ball(tuple(top + V(math.cos(ang) * .75 * sz, math.sin(ang) * .75 * sz, 2.6 * sz + .45 * sz * (k % 2))), .8 * sz, 'la', sq=(1, 1, .7)), col=hexc('#3f7a32' if kind == 0 else '#4f8a36')))
        if kind == 4:
            for k in range(3):
                ang = k * 2.1 + .5
                o.append(Ball(tuple(top + V(math.cos(ang) * 1.2 * sz, math.sin(ang) * 1.2 * sz, 2.2 * sz)), .32 * sz, 'cam'))
    elif kind == 1:
        for k in range(5):
            ang = k / 5 * 2 * np.pi
            d = V(math.cos(ang), math.sin(ang), 0)
            o.append(M(Line([tuple(top), tuple(top + d * 1.3 * sz + V(0, 0, 2.4 * sz))], [.35 * sz, .1 * sz], 'la'), col=hexc('#5aa03a')))
    elif kind == 2:   # mai vàng: cành nâu, bông vàng
        for k in range(4):
            ang = k * 1.7 + .3
            e = top + V(math.cos(ang) * 1.2 * sz, math.sin(ang) * 1.2 * sz, 2.6 * sz + .3 * k * sz)
            o.append(M(Line([tuple(top), tuple(e)], .14 * sz, 'go2'), col=hexc('#5a3a22')))
            o.append(M(Ball(tuple(e), .5 * sz, 'cam'), col=hexc('#f0c020')))
            o.append(M(Ball(tuple((top + e) / 2 + V(0, 0, .3 * sz)), .4 * sz, 'cam'), col=hexc('#f0c020')))
    else:             # cau con: thân mảnh, tàu lá xoè
        tip = top + V(0, 0, 3.2 * sz)
        o.append(M(Line([tuple(top), tuple(tip)], [.25 * sz, .16 * sz], 'go2'), col=hexc('#7a8a4a')))
        for k in range(5):
            ang = k / 5 * 2 * np.pi
            d = V(math.cos(ang), math.sin(ang), 0)
            o.append(M(Line([tuple(tip), tuple(tip + d * 1.0 * sz + V(0, 0, .6 * sz)), tuple(tip + d * 2.0 * sz + V(0, 0, -.4 * sz))], [.3 * sz, .25 * sz, .08 * sz], 'la'), col=hexc('#5a9a3a')))
    return o


def tub(fr, c, r, col='#3a72b8'):
    """thau nhựa đựng cá giống: thau + mặt nước"""
    t = M(Tube(tuple(c), (0, 0, 1), 1.8, [(0, r * .8), (1, r)], 'dco', shell=.25, open1=True), col=hexc(col), sp=.4, pw=40)
    w = M(Ball(tuple(V(*c) + V(0, 0, 1.45)), r * .9, 'nuoc', sq=(1, 1, .08)), col=hexc('#5aa0b0'), sp=.6, pw=50)
    o = [t, w]
    for k in range(3):   # cá giống lấp ló
        ang = k * 2.1 + .4
        o.append(M(Ball(tuple(V(*c) + V(math.cos(ang) * r * .45, math.sin(ang) * r * .45, 1.55)), .3, 'cam', sq=(2.2, 1, .6)), col=hexc('#e8a040')))
    return o


def duck_cage(fr, c, r=2.6):
    """lồng tre đựng vịt con"""
    o = [M(Tube(tuple(c), (0, 0, 1), 2.4, [(0, r), (.8, r), (1, r * .7)], 'dan', shell=.22, open1=True, wv=(18, .1)), col=hexc('#c7a466'))]
    for k in range(5):
        ang = k * 1.3
        rr = r * .5 if k else 0
        b = V(*c) + V(math.cos(ang) * rr, math.sin(ang) * rr, 2.3)
        o.append(M(Ball(tuple(b), .75, 'cam', sq=(1.2, 1, .9)), col=hexc('#f0d040')))
        o.append(M(Ball(tuple(b + V(.5 * math.cos(ang + .5), .5 * math.sin(ang + .5), .7)), .45, 'cam'), col=hexc('#f0d040')))
    return o


def sack(fr, u, v, z0, cs=1.0, col='#ddd0b0', stripe='#c03a2a', rot=0.0):
    """bao gạo dệt màu ngà có sọc, túm buộc 2 đầu"""
    c_, s_ = math.cos(rot), math.sin(rot)
    a0 = fr.U * c_ + fr.Vv * s_; a1 = nz(np.cross(V(0, 0, 1), a0))
    C = fr.w(u, v, z0 + 1.1 * cs)
    b = Box(tuple(C), (a0, a1, (0, 0, 1)), (2.4 * cs, 1.7 * cs, 1.05 * cs), 'baog', rr=.9 * cs)
    b.col = hexc(col); b.stripe = hexc(stripe)
    o = [b]
    for e in (-1, 1):
        t = M(Ball(tuple(C + a0 * e * 2.55 * cs + V(0, 0, .25 * cs)), .5 * cs, 'baog', sq=(1, .7, .7)), col=hexc(col))
        t.stripe = hexc(col); t.A = np.array([a0, a1, V(0, 0, 1)], F32); t.h = V(.5, .5, .5)
        o.append(t)
    return o


def firewood(fr, u, v, z0, ln=5.0, r=1.5, seed=0):
    """bó củi chẻ buộc dây mây"""
    rs = np.random.RandomState(seed)
    o = []
    for k in range(7):
        ang = k / 7 * 2 * np.pi
        rr = r * .55 if k else 0
        off = fr.Vv * math.cos(ang) * rr + V(0, 0, math.sin(ang) * rr + r)
        a = fr.w(u - ln / 2 + rs.uniform(-.3, .3), v, z0) + off
        b = fr.w(u + ln / 2 + rs.uniform(-.3, .3), v, z0) + off
        o.append(M(Line([tuple(a), tuple(b)], .42, 'cui'), col=hexc(['#8a6a44', '#7a5a38', '#9a7a50'][k % 3])))
    for e in (-.3, .3):
        o.append(M(Torus(tuple(fr.w(u + e * ln, v, z0 + r)), tuple(fr.U), r * .9, .18, 'may'), col=hexc('#5a3a1e')))
    return o


def salt_jar(fr, c, r=1.8):
    """lu muối hột: lu sành nâu, muối trắng đầy miệng"""
    c = V(*c)
    return [M(Ball(tuple(c + V(0, 0, r * 1.1)), r, 'chum', sq=(1, 1, 1.15)), sp=.5, pw=40),
            M(Ball(tuple(c + V(0, 0, r * 2.15)), r * .62, 'muoi', sq=(1, 1, .45)), col=hexc('#f2f0ea'))]


def clay_pot(fr, c, r=1.3):
    c = V(*c)
    return [M(Ball(tuple(c + V(0, 0, r * .8)), r, 'chau', sq=(1, 1, .75))),
            M(Torus(tuple(c + V(0, 0, r * 1.45)), (0, 0, 1), r * .62, .2, 'chau'), col=hexc('#9a5030'))]


# 4 ghe chợ nổi = data/cho/ghe_cho_noi.json (thứ tự e = 0..3): giống / trái / lúa gạo / đồ bếp; màu thân theo màu áo (ao) từng ghe
CHO_SET = [
    dict(id='giong', band='#2f7a4a', trim='#eadfbf', tarp=('#2f7a4a', '#eef0e0')),
    dict(id='trai', band='#d86a3a', trim='#2e5a8a', tarp=None),
    dict(id='nong', band='#3a6a8a', trim='#d8b040', tarp=('#3a6a8a', '#f0e8d0')),
    dict(id='bep', band='#7a3a8c', trim='#e8c060', tarp=None),
]


def cho_load(fr, h, kind, zf, Wb, seed):
    """hàng trên ghe chợ theo loại ghe"""
    L = h.L
    o = []
    rs = np.random.RandomState(seed)
    if kind == 'giong':   # chậu cây giống nhiều loại, thau cá giống, lồng vịt con (chừa chỗ cây bẹo ở .58L)
        uu = -L * .34; i = 0
        while uu < L * .14:
            wd = w_at(h, uu / L) - 2.6
            n = max(2, int(wd * 2 / 4.2) + 1)
            for j, vv in enumerate(np.linspace(-wd, wd, n)):
                o += seedling(fr, fr.w(uu + rs.uniform(-.3, .3), vv + rs.uniform(-.2, .2), zf), 1.45 + rs.uniform(-.1, .2), (i * 2 + j * 3) % 5)
            uu += 4.2; i += 1
        wd = w_at(h, .28) - 3.6
        o += tub(fr, fr.w(L * .28, -wd * .55, zf), 3.0) + tub(fr, fr.w(L * .28, wd * .55, zf), 3.0, '#d04a3a')
        wd = w_at(h, .44) - 3.2
        o += duck_cage(fr, fr.w(L * .44, -wd * .5, zf), 2.7) + duck_cage(fr, fr.w(L * .44, wd * .5, zf), 2.7)
    elif kind == 'trai':  # mô trái cây miệt vườn chất cao + buồng chuối
        o += heap(fr, ['dua', 'dua2', 'khom', 'xoai', 'bi', 'dua', 'cam', 'dua2'], -L * .62, L * .46, zf, Wb * .62, seed, cs=1.25, layers=3)
        for uu in (-L * .4, -L * .1, L * .2):   # buồng chuối nằm trên đỉnh đống
            o += fruit(fr, 'chuoi', fr.w(uu, rs.uniform(-1, 1), zf + (2.0 + 2 * 2.9) * 1.25 + 1.0), 1.25)
    elif kind == 'nong':  # bao gạo chất 3 tầng kín khoang, thúng lúa mũi
        cs = 1.45
        uu = -L * .32 + 2.6 * cs; k = 0
        while uu < L * .44:
            wd = w_at(h, uu / L) - 1.2
            nv = 2 if wd > 1.9 * cs * 2 else 1
            for ly in range(3 if abs(uu) < L * .3 else 2):
                nn = max(1, nv - (1 if ly == 2 else 0))
                for jj in range(nn):
                    vv = (jj - (nn - 1) / 2) * 1.75 * cs * 2
                    o += sack(fr, uu + (ly % 2) * 1.2 + rs.uniform(-.3, .3), vv + rs.uniform(-.3, .3), zf + ly * 2.05 * cs, cs, stripe=['#c03a2a', '#2e6aa0'][(k + ly + jj) % 2], rot=rs.uniform(-.08, .08))
            uu += 2.6 * cs * 2 + .2; k += 1
        o += thung(fr, L * .6, -3.0, zf, 3.0, 'lua', seed + 1) + thung(fr, L * .62, 3.2, zf, 2.8, 'lua', seed + 2)
    else:                 # đồ bếp: củi chất đống phía lái, lu muối hột giữa, nồi đất + bao muối phía mũi
        for pc, ln in ((-L * .52, 13.0), (-L * .24, 13.0)):   # 2 đống củi chẻ chất dọc khoang, thanh dài xếp lớp
            wd = w_at(h, pc / L) - 1.3
            for ly in range(5):
                hw_ = wd - ly * .9
                if hw_ < 1.0: break
                n = int(hw_ * 2 / .95)
                for jj in range(n):
                    vv = -hw_ + (jj + .5) * (hw_ * 2 / n) + rs.uniform(-.15, .15)
                    du = rs.uniform(-.8, .8)
                    zz = zf + .5 + ly * .82 + rs.uniform(-.08, .08)
                    a_ = fr.w(pc - ln / 2 + du, vv, zz); b_ = fr.w(pc + ln / 2 + du + rs.uniform(-.6, .6), vv + rs.uniform(-.2, .2), zz + rs.uniform(-.1, .1))
                    o.append(M(Line([tuple(a_), tuple(b_)], .44 + rs.uniform(-.06, .08), 'cui'), col=hexc(['#8a6a44', '#7a5a38', '#9a7a50', '#a88a5e'][rs.randint(4)])))
        uu = -L * .06
        while uu < L * .34:
            wd = w_at(h, uu / L) - 3.0
            for vv in (-wd * .55, wd * .55):
                o += salt_jar(fr, fr.w(uu + rs.uniform(-.3, .3), vv, zf), 2.5)
            uu += 5.6
        for vv in (-4.0, 0, 4.0):
            o += clay_pot(fr, fr.w(L * .44, vv, zf), 1.9)
            o += clay_pot(fr, fr.w(L * .44 + .3, vv * .5, zf + 2.6), 1.6) if vv else []
        o += sack(fr, L * .62, -1.8, zf, 1.2, col='#f2f0ea', stripe='#3a8a4a') + sack(fr, L * .62, 2.2, zf, 1.1, col='#f2f0ea', stripe='#3a8a4a', rot=.1)
    return o


def boat(kind, th=0.0, sgn=1.0, ax='u', mui_on=1, seed=0):
    fr = Frame(th, sgn, ax)
    L = CH * TILE
    objs = []
    if kind == 'xu':     # xuồng ba lá: thon, thấp, gỗ mộc
        L = L * .62
        h = paint(Hull(fr, L, 6.0, 3.0, 2.4, 4.0, 3.2, t=.5, bow_sharp=1.4), None, 0)
        objs.append(h)
        zf = max(float(h.prof(np.array([0.0]))[2][0] + (zt_at(h, 0) - h.prof(np.array([0.0]))[2][0]) * .42), .5)
        objs += thwarts(fr, h, (-.55, .5), '#7a4e2c')
        if mui_on:
            objs.append(mui(fr, -L * .3, L * .18, 6.4, zt_at(h, 0) - .2, '#cfae72'))
            objs += oars(fr, h, 1.0)
            objs += thung(fr, L * .38, 0, zf, 2.4, 'cam', seed + 2)
        else:
            objs += thung(fr, -L * .2, -1.2, zf, 2.6, 'dua2', seed + 3)
            objs += thung(fr, L * .22, 1.0, zf, 2.6, 'cam', seed + 4)
            objs += oars(fr, h, -1.0)
        objs += rope(fr, h, -.78)
        return Scene(objs)
    if kind == 'ghe':    # ghe thương hồ: nhà ghe ván sơn xanh, mái tôn, máy đuôi tôm, khoang trước chất thùng gỗ
        Wb = 13.0
        h = paint(Hull(fr, L, Wb, 6.5, 5.6, 9.0, 6.0, t=.8), '#2f7f88', 3.6)
        objs.append(h)
        zf = max(float(h.prof(np.array([0.0]))[2][0] + (zt_at(h, 0) - h.prof(np.array([0.0]))[2][0]) * .42), .5)
        co, zd = cabin(fr, h, -L * .74, -L * .12, Wb * .74, 9.5)
        objs += co
        objs += deck(fr, h, .76, .9) + deck(fr, h, -.9, -.8)
        objs += crates(fr, h, -L * .08, L * .66, zf, seed + 3)
        objs += beo(fr, .58 * CH * TILE, zf)
        objs += engine(fr, h)
        objs += rope(fr, h, .84)
        return Scene(objs)
    # ghe chợ nổi (4 loại theo data)
    cs_ = CHO_SET[seed % 4]
    Wb = 11.0
    h = paint(Hull(fr, L, Wb, 5.6, 4.9, 8.0, 5.0, t=.8), cs_['band'], 3.1, trim=cs_['trim'])
    objs.append(h)
    zf = max(float(h.prof(np.array([0.0]))[2][0] + (zt_at(h, 0) - h.prof(np.array([0.0]))[2][0]) * .42), .5)
    objs += deck(fr, h, .78, .9) + deck(fr, h, -.9, -.78)
    if mui_on and cs_['tarp']:
        objs += awning(fr, h, -L * .78, -L * .38, zf, *cs_['tarp'])
    objs += cho_load(fr, h, cs_['id'], zf, Wb, seed + 5)
    objs += beo(fr, .58 * CH * TILE, zf)
    objs += engine(fr, h, ['#c23b2b', '#2e5a8a', '#c23b2b', '#3a6a3a'][seed % 4])
    return Scene(objs)


def parse(key):
    if key.startswith('ghe_u_'):
        return dict(kind='ghe', th=int(key[6:]) * .05)
    if key == 'ghe_v':
        return dict(kind='ghe', th=0.0, ax='v')
    if key.startswith('cho_'):
        loc, e = key[4:].rsplit('_', 1)
        e = int(e)
        th = CHO_TH.get(key, 0.0)
        return dict(kind='cho', th=th, sgn=-1.0 if e % 2 else 1.0, seed=e, mui_on=CHO_MUI[e])
    if key.startswith('xu_'):
        pm = key[3]; mu = int(key[4]); k = int(key.split('_')[2])
        return dict(kind='xu', th=k * .05, sgn=1.0 if pm == 'p' else -1.0, mui_on=mu)
    raise ValueError(key)


CHO_TH = {}       # góc sông tại từng ghe chợ (ghe.js meta), điền từ cho_th.json nếu có
CHO_MUI = [1, 0, 1, 0]   # data/cho/ghe_cho_noi.json mui: giống 1, trái 0, lúa gạo 1, đồ bếp 0
_ct = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cho_th.json')
if os.path.exists(_ct):
    CHO_TH = json.load(open(_ct))


if __name__ == '__main__':
    OUT = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    for key in sys.argv[2:]:
        p = parse(key)
        sc = boat(p.pop('kind'), **p)
        (im, imw), anc = B.render(sc, key)
        imw.save(os.path.join(OUT, key + '.webp'), lossless=True, quality=100, method=6)
        pu = B.PXU
        m = [round(-anc[0] / pu, 3), round(-anc[1] / pu, 3), round(imw.width / pu, 3), round(imw.height / pu, 3)]
        json.dump(m, open(os.path.join(OUT, key + '.json'), 'w'))
        print(key, imw.size, m, flush=True)
