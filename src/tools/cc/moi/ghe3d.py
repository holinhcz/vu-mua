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
def _groups(self):
    if getattr(self, '_gr', None) is None:
        gs = {}
        for i, o in enumerate(self.objs):
            gs.setdefault(getattr(o, 'grp', -1 - i), []).append(i)
        out = []
        for k, ids in gs.items():
            if len(ids) == 1:
                c, r = self.objs[ids[0]].bound
                out.append((V(*c), float(r), ids))
                continue
            cs = np.array([self.objs[i].bound[0] for i in ids], F32); rr = np.array([self.objs[i].bound[1] for i in ids], F32)
            lo = (cs - rr[:, None]).min(0); hi = (cs + rr[:, None]).max(0)
            c = (lo + hi) / 2
            r = float((np.linalg.norm(cs - c, axis=1) + rr).max())
            out.append((c, r, ids))
        self._gr = out
    return self._gr


def _fast_sdf(self, P, ids=False):
    """min khoảng cách qua mọi khối, giữ min chạy; cầu bao theo nhóm món (trái, chậu cây) rồi từng khối"""
    n = len(P)
    if n > 120000:
        parts = [_fast_sdf(self, P[i:i + 120000], ids) for i in range(0, n, 120000)]
        if ids:
            return np.concatenate([p[0] for p in parts]), np.concatenate([p[1] for p in parts])
        return np.concatenate(parts)
    best = np.full(n, 1e9, F32); arg = np.zeros(n, np.int32)
    for c, r, idl in _groups(self):
        dg = (np.linalg.norm(P - c, axis=1) - r).astype(F32)
        far = dg >= 1.0
        m = far & (dg < best)
        best[m] = dg[m]; arg[m] = idl[0]
        ng = np.nonzero(~far)[0]
        if len(ng) == 0:
            continue
        Pn = P[ng]
        bb = best[ng]; aa = arg[ng]
        for i in idl:
            o = self.objs[i]
            if len(idl) > 1:
                oc, orr = o.bound
                db = (np.linalg.norm(Pn - oc, axis=1) - orr).astype(F32)
                near = db < 1.0
                d = db
                if near.any():
                    d = db.copy()
                    d[near] = o.sdf(Pn[near])
            else:
                d = o.sdf(Pn)
            mm = d < bb
            bb[mm] = d[mm]; aa[mm] = i
        best[ng] = bb; arg[ng] = aa
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
            be = min(bw, 3.6); eu = L * .7; ec = be * .55
            ex = (u - eu) / (be * 1.25); ey = (dz - ec) / (be * .42)
            al = np.abs(ex) ** 1.6 + ey ** 2 * (1 + .6 * np.abs(ex))     # mắt hình hạnh
            pu = np.hypot(ex - .12, ey * .9)
            eye = out & (al < 1.0)
            c_o = np.where((out & (al < 1.35) & (dz < bw))[:, None], hexc('#b8382a')[None], c_o)
            c_o = np.where(eye[:, None], hexc('#f4efe2')[None], c_o)
            c_o = np.where((eye & (pu < .42))[:, None], hexc('#1a1412')[None], c_o)
            c_o = np.where((eye & (np.hypot(ex - .0, ey + .1) < .12))[:, None], hexc('#f4efe2')[None], c_o)
        butt = np.exp(-((((u + 7 * np.floor(dz / 1.05)) / 14.0) % 1.0 - .5) / .012) ** 2)   # mối nối ván so le
        nail = (np.abs(((u / 1.4) % 1.0) - .5) < .07) & (np.abs(((dz / 1.05) % 1.0) - .5) < .09)
        c_o = c_o * (1 - .22 * seam * (dz > .5) - .2 * butt * (dz > .5))[:, None]
        c_o = np.where((nail & (dz > .6) & out)[:, None], c_o * .6, c_o)
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
        bar = gl & (np.abs(((fx - .5) / .1) % 1.0 - .5) < .12)      # song cửa sổ
        c = np.where(bar[:, None], hexc('#d8ccb0')[None], c)
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
    if m == 'leaf':   # lá: gân giữa sáng, mép sẫm, gốc -> ngọn chuyển màu, mỗi lá 1 sắc
        q = obj.local(P)
        x = q[:, 0] / obj.R[0]; y = q[:, 1] / obj.R[1]
        col = obj.col
        hj = (B.hsh(np.array([obj.C[0] * 3.1 + obj.C[1] * 7.3])) - .5)[0]
        c = col[None] * (1 + .18 * hj + .14 * x[:, None] * np.array([[.3, .6, .1]], F32))
        wy = np.sqrt(np.clip(1 - x ** 2, 0, 1)) + 1e-3
        rib = np.exp(-(y / .09) ** 2)
        vein = np.exp(-((((x * 3.5 + np.abs(y) * 2.2) % 1.0) - .5) / .08) ** 2) * (np.abs(y) / wy > .15)
        edge = sstep(.7, .98, np.abs(y) / wy)
        c = c * (1.08 + .3 * rib - .1 * vein - .18 * edge)[:, None]
        under = q[:, 2] < 0
        return np.where(under[:, None], c * .78, c)
    if m == 'dua':    # dưa hấu: sọc rằn dọc trục dài, mép sọc gợn, đốm vàng dưới
        q = obj.local(P) / obj.R
        th = np.arctan2(q[:, 2], q[:, 1])
        wob = .35 * np.sin(q[:, 0] * 9 + th * 3) + .25 * (vnoise(P, 1.6, 41) - .5)
        st = np.sin(th * 7 + wob * 2) > -.05
        c = np.where(st[:, None], hexc('#2a5a22')[None], hexc('#78a84a')[None])
        c = c * (.9 + .15 * (vnoise(P, 3, 42) - .5))[:, None]
        spot = sstep(-.55, -.85, q[:, 2])
        return c * (1 - spot[:, None]) + hexc('#d8c870')[None] * spot[:, None]
    if m == 'bi':     # bí đỏ: rãnh múi sẫm, đốm sáng, đáy ngả xanh
        q = obj.local(P)
        th = np.arctan2(q[:, 1], q[:, 0])
        gro = np.abs(np.sin(th * 5)) ** .5
        c = hexc('#e07a26')[None] * (.62 + .45 * gro)[:, None]
        sp = vnoise(P, 4, 43) > .78
        c = np.where(sp[:, None], c * 1.15, c)
        zz = q[:, 2] / obj.R[2]
        return c * (1 - .3 * sstep(-.2, -.9, zz))[:, None] + hexc('#6a7a2a')[None] * (.3 * sstep(-.2, -.9, zz))[:, None]
    if m == 'khom':   # mắt dứa: ô thoi, viền nâu, chấm gai; xanh dưới -> vàng cam trên
        q = obj.local(P)
        zz = q[:, 2] / obj.R[2]
        th = np.arctan2(q[:, 1], q[:, 0])
        a1 = th * 4.5 + zz * 6; a2 = th * 4.5 - zz * 6
        cell = np.minimum(np.abs((a1 / np.pi) % 1.0 - .5), np.abs((a2 / np.pi) % 1.0 - .5))
        base = hexc('#6a8a3a') * (1 - sstep(-.6, .6, zz))[:, None] + hexc('#d89a30') * sstep(-.6, .6, zz)[:, None]
        c = base * (.75 + .5 * sstep(.05, .25, cell))[:, None]
        dot = cell > .4
        return np.where(dot[:, None], hexc('#5a3a1e')[None], c)
    if m == 'dua2':   # dừa xiêm: xanh bóng, gân xơ dọc, đỉnh ngả vàng nâu
        q = obj.local(P) / obj.R
        th = np.arctan2(q[:, 1], q[:, 0])
        fib = .5 + .5 * np.sin(th * 26 + 3 * vnoise(P, 1, 44))
        c = hexc('#5a8a32')[None] * (.85 + .15 * fib)[:, None]
        tp = sstep(.55, .95, q[:, 2])
        return c * (1 - tp[:, None]) + hexc('#a08a40')[None] * tp[:, None]
    if m == 'xoai':   # xoài cát: xanh -> vàng, má hồng gần cuống, chấm li ti
        q = obj.local(P) / obj.R
        g = sstep(-1, 1, q[:, 0] + .3 * q[:, 2])
        c = hexc('#8aa83a')[None] * (1 - g)[:, None] + hexc('#f0c840')[None] * g[:, None]
        bl = sstep(.2, .9, -q[:, 0] + q[:, 2] * .5)
        c = c * (1 - .5 * bl[:, None]) + hexc('#e0603a')[None] * (.5 * bl)[:, None]
        dot = vnoise(P, 6, 45) > .82
        return np.where(dot[:, None], c * .85, c)
    if m == 'cam2':   # cam sành: vỏ sần lỗ tinh dầu, xanh pha cam
        q = obj.local(P) / obj.R
        pore = vnoise(P, 8, 46)
        g = sstep(-.8, .8, q[:, 2] + .4 * (vnoise(P, .8, 47) - .5))
        c = hexc('#e88a26')[None] * (1 - g)[:, None] + hexc('#8aa83a')[None] * g[:, None]
        return c * (.88 + .2 * pore)[:, None]
    if m == 'khoai':
        return hexc('#9a4250')[None] * (.85 + .25 * vnoise(P, 2.5, 48))[:, None]
    if m == 'lua':    # hạt lúa vàng
        g = vnoise(P, 9, 49)
        return hexc('#d8b048')[None] * (.75 + .4 * g)[:, None]
    if m == 'chuoi2':  # trái chuối: vàng, cạnh múi, đầu xanh, núm nâu
        d, sl = obj.seg(P)
        tt = sl / max(float(obj.cum[-1]), 1e-3)
        c = hexc('#f0cc38')[None] * np.ones((len(P), 1), F32)
        c = np.where((tt < .18)[:, None], hexc('#8aa83a')[None], c)
        c = np.where((tt > .95)[:, None], hexc('#4a3420')[None], c)
        spk = vnoise(P, 7, 50) > .85
        return np.where((spk & (tt > .2))[:, None], c * .75, c)
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


FRUITM = {'dua', 'bi', 'khom', 'dua2', 'xoai', 'cam2', 'chuoi2', 'leaf', 'khoai'}


def albedo_lit(obj, P):
    c = albedo(obj, P)
    return c * 1.15 if obj.mat in FRUITM else c


B.albedo = albedo_lit


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


# ------------------------------------------------------------ trái cây + lá cây chi tiết (11-24 Link "cây đéo ra cây, trái đéo ra trái, vẽ gì cũng 1 mảng màu")
_GID = [0]


def grp(objs):
    """gom các khối của 1 món vào 1 nhóm: cầu bao chung để bỏ qua nhanh khi bắn tia"""
    _GID[0] += 1
    for o in objs:
        o.grp = _GID[0]
    return objs


class Ell:
    """elip xoay tuỳ ý: tâm C, 3 trục (đơn vị) A, bán trục R; bend: cong theo trục 0 (lá, xoài, chuối)"""
    def __init__(s, C, axes, R, mat, bend=0.0, rib=None):
        s.C = V(*C); s.A = np.array([nz(V(*a)) for a in axes], F32); s.R = V(*R); s.mat = mat; s.bend = bend; s.rib = rib
        s.bound = (s.C, float(s.R.max()) + abs(bend) * float(s.R[0]) ** 2 + 1)

    def local(s, P):
        q = (P - s.C) @ s.A.T
        if s.bend:
            q[:, 2] = q[:, 2] - s.bend * q[:, 0] ** 2
        return q

    def sdf(s, P):
        q = s.local(P)
        R = np.broadcast_to(s.R, q.shape).copy()
        if s.rib is not None:   # múi (bí): bán kính ngang thắt theo góc quanh trục 2
            n, k = s.rib
            th = np.arctan2(q[:, 1], q[:, 0])
            f = 1 - k * np.abs(np.sin(th * n / 2)) ** .6
            R[:, 0] *= f; R[:, 1] *= f
        qq = q / R
        k0 = np.linalg.norm(qq, axis=1)
        return ((k0 - 1) * float(s.R.min()) * .9).astype(F32)


def _frame(d):
    d = nz(V(*d))
    t = nz(np.cross(d, V(0, 0, 1))) if abs(d[2]) < .95 else nz(np.cross(d, V(1, 0, 0)))
    return d, t, nz(np.cross(d, t))


def leaf(base, d, ln, wd, col='#4f8a36', bend=.12, tilt=0.0):
    """1 chiếc lá: gốc base, hướng d, dài ln, rộng wd; mặt lá ngửa lên"""
    d = nz(V(*d))
    side = nz(np.cross(V(0, 0, 1), d)) if abs(d[2]) < .97 else V(1, 0, 0)
    nrm = nz(np.cross(d, side))
    if tilt:
        side, nrm = nz(side * math.cos(tilt) + nrm * math.sin(tilt)), nz(nrm * math.cos(tilt) - side * math.sin(tilt))
    c = V(*base) + d * ln * .5
    e = Ell(tuple(c), (d, side, nrm), (ln * .5, wd * .5, .13), 'leaf', bend=-bend / max(ln, .5))
    e.col = hexc(col) if isinstance(col, str) else col
    return e


def fruit(fr, k, c, cs=1.0, seed=0, yaw=None):
    rs = np.random.RandomState(abs(int(seed * 7919 + c[0] * 13 + c[1] * 31)) % (2 ** 31))
    c = V(*c)
    yaw = rs.uniform(0, 2 * np.pi) if yaw is None else yaw
    ax0 = V(math.cos(yaw), math.sin(yaw), 0); ax1 = V(-math.sin(yaw), math.cos(yaw), 0)
    if k == 'dua':   # dưa hấu: dài, sọc rằn xanh đậm, đốm vàng chỗ nằm
        e = Ell(tuple(c), (ax0, ax1, (0, 0, 1)), (2.7 * cs, 2.0 * cs, 1.9 * cs), 'dua')
        return grp([e, M(Line([tuple(c + ax0 * 2.7 * cs), tuple(c + ax0 * 3.1 * cs + V(0, 0, .3 * cs))], .16 * cs, 'go2'), col=hexc('#6a6a2a'))])
    if k == 'bi':    # bí đỏ: múi sâu, cuống xanh nâu
        e = Ell(tuple(c), (ax0, ax1, (0, 0, 1)), (2.1 * cs, 2.1 * cs, 1.55 * cs), 'bi', rib=(10, .09))
        st = M(Line([tuple(c + V(0, 0, 1.2 * cs)), tuple(c + V(0, 0, 1.9 * cs)), tuple(c + ax0 * .5 * cs + V(0, 0, 2.3 * cs))], [.34 * cs, .26 * cs, .2 * cs], 'go2'), col=hexc('#6a6a34'))
        return grp([e, st])
    if k == 'khom':  # khóm: mắt dứa, xanh dưới vàng trên, chùm lá gai
        e = Ell(tuple(c), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (1.35 * cs, 1.35 * cs, 1.8 * cs), 'khom')
        o = [e]
        top = c + V(0, 0, 1.6 * cs)
        for q in range(9):
            ang = q / 9 * 2 * np.pi + rs.uniform(0, .3)
            up = .55 + .4 * (q % 3) / 2
            d = V(math.cos(ang) * (1 - up), math.sin(ang) * (1 - up), up)
            o.append(leaf(top, d, (1.6 + .6 * (q % 2)) * cs, .45 * cs, '#4a7a52', bend=.25))
        return grp(o)
    if k == 'dua2':  # dừa xiêm xanh: hơi tam giác, núm nâu
        e = Ell(tuple(c), (ax0, ax1, (0, 0, 1)), (1.7 * cs, 1.55 * cs, 1.6 * cs), 'dua2')
        return grp([e, M(Ball(tuple(c + V(0, 0, 1.45 * cs)), .45 * cs, 'go2', sq=(1, 1, .5)), col=hexc('#6a5a30'))])
    if k == 'xoai':  # xoài: cong, xanh -> vàng -> má hồng
        e = Ell(tuple(c), (ax0, ax1, (0, 0, 1)), (1.7 * cs, 1.1 * cs, 1.0 * cs), 'xoai', bend=.07)
        return grp([e])
    if k == 'cam':   # cam sành: vỏ sần, xanh vàng, cuống + 1 lá
        e = Ell(tuple(c), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (1.05 * cs, 1.05 * cs, .95 * cs), 'cam2')
        o = [e, M(Ball(tuple(c + V(0, 0, .95 * cs)), .18 * cs, 'go2'), col=hexc('#5a5a2a'))]
        if rs.rand() < .5:
            o.append(leaf(c + V(0, 0, .95 * cs), ax0 + V(0, 0, .3), 1.4 * cs, .6 * cs, '#3f7a32', bend=.1))
        return grp(o)
    if k == 'khoai':
        e = Ell(tuple(c), (ax0, ax1, (0, 0, 1)), (1.6 * cs, .85 * cs, .8 * cs), 'khoai', bend=.08)
        return grp([e])
    if k == 'lua':   # lúa vàng đầy thúng
        return [M(Ball(tuple(c + V(0, 0, -.6)), 2.0 * cs, 'lua', sq=(1, 1, .35)), col=hexc('#d8b048'))]
    if k == 'bao':
        return [Box(tuple(c + V(0, 0, -.5 * cs)), (fr.U, fr.Vv, (0, 0, 1)), (2.6 * cs, 1.7 * cs, 1.1 * cs), 'bao', rr=1.0 * cs)]
    if k == 'chuoi':  # nải chuối: 2 hàng trái cong chụm về cuống, vàng đầu xanh, núm nâu
        o = []
        crown = c + ax0 * -1.6 * cs + V(0, 0, .3 * cs)
        o.append(M(Line([tuple(crown + V(0, 0, -.3 * cs)), tuple(crown - ax0 * .9 * cs + V(0, 0, .6 * cs))], .45 * cs, 'go2'), col=hexc('#7a7a3a')))
        for row in (0, 1):   # nải nằm: trái xoè ngang, đầu cong vểnh lên
            nq = 6 - row
            for q in range(nq):
                sp = (q - (nq - 1) / 2) * .62 * cs
                b = crown + ax1 * sp * .25 + V(0, 0, row * .7 * cs)
                m1 = b + ax0 * 1.5 * cs + ax1 * sp * 1.1 + V(0, 0, .1 * cs)
                e_ = b + ax0 * (2.8 - .3 * row) * cs + ax1 * sp * 1.5 + V(0, 0, .8 * cs)
                o.append(M(Line([tuple(b), tuple(m1), tuple(e_)], [.3 * cs, .42 * cs, .22 * cs], 'chuoi2'), col=None))
        return grp(o)
    return []


def seedling(fr, c, sz=1.0, kind=0, seed=0):
    """chậu cây giống: chậu đất có vành + cây con thật (0 bưởi con, 1 kiểng lá dài, 2 mai vàng, 3 cau con, 4 cam con có trái)"""
    rs = np.random.RandomState(abs(int(seed * 131 + c[0] * 17 + c[1] * 7)) % (2 ** 31))
    C = V(*c)
    o = [Tube(tuple(C), (0, 0, 1), 1.8 * sz, [(0, .8 * sz), (.85, 1.1 * sz), (1, 1.25 * sz)], 'chau', shell=.25, open1=True),
         M(Ball(tuple(C + V(0, 0, 1.45 * sz)), 1.0 * sz, 'muoi', sq=(1, 1, .15)), col=hexc('#5a3e28'))]
    top = C + V(0, 0, 1.5 * sz)
    if kind in (0, 4):   # cây ăn trái con: thân, 3 cành, chùm lá thật
        h_ = 3.2 * sz
        o.append(M(Line([tuple(top), tuple(top + V(.2 * sz, 0, h_))], [.24 * sz, .16 * sz], 'go2'), col=hexc('#6a4a2a')))
        for b in range(3):
            ang = b * 2.1 + rs.uniform(0, .6)
            p0 = top + V(0, 0, h_ * (.5 + .2 * b))
            p1 = p0 + V(math.cos(ang) * 1.3 * sz, math.sin(ang) * 1.3 * sz, .8 * sz)
            o.append(M(Line([tuple(p0), tuple(p1)], .1 * sz, 'go2'), col=hexc('#6a4a2a')))
            for l in range(3):
                a2 = ang + (l - 1) * .9
                o.append(leaf(p1 + V(0, 0, rs.uniform(-.3, .3) * sz), V(math.cos(a2), math.sin(a2), rs.uniform(-.1, .5)), 1.4 * sz, .7 * sz,
                              ['#7cc052', '#8ad060', '#6ab84a'][l % 3], bend=.15))
        for l in range(3):
            a2 = l * 1.6
            o.append(leaf(top + V(0, 0, h_), V(math.cos(a2), math.sin(a2), .5), 1.3 * sz, .65 * sz, '#6aaa44', bend=.15))
        if kind == 4:
            for q in range(4):
                ang = q * 1.7 + .5
                o.append(M(Ell(tuple(top + V(math.cos(ang) * 1.0 * sz, math.sin(ang) * 1.0 * sz, h_ * .75)), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (.38 * sz, .38 * sz, .36 * sz), 'cam2'), col=None))
    elif kind == 1:      # kiểng lá dài (phát tài): lá dải cong rủ
        for q in range(8):
            ang = q / 8 * 2 * np.pi + rs.uniform(0, .4)
            up = .9 if q % 2 else .6
            o.append(leaf(top + V(0, 0, .2 * sz), V(math.cos(ang) * (1 - up * .7), math.sin(ang) * (1 - up * .7), up), 3.0 * sz, .55 * sz,
                          ['#6ab848', '#58a83e', '#7cc455'][q % 3], bend=.5))
    elif kind == 2:      # mai vàng: cành nâu khẳng khiu, bông 5 cánh vàng, nụ
        for b in range(5):
            ang = b * 1.3 + rs.uniform(0, .4)
            p1 = top + V(math.cos(ang) * 1.5 * sz, math.sin(ang) * 1.5 * sz, (2.6 + .4 * (b % 3)) * sz)
            mid = (top + p1) / 2 + V(math.cos(ang + 1) * .3 * sz, math.sin(ang + 1) * .3 * sz, 0)
            o.append(M(Line([tuple(top), tuple(mid), tuple(p1)], [.2 * sz, .13 * sz, .08 * sz], 'go2'), col=hexc('#4a3020')))
            for fpos in (p1, mid + V(0, 0, .25 * sz)):
                for pt in range(5):
                    pa = pt / 5 * 2 * np.pi
                    o.append(M(Ball(tuple(fpos + V(math.cos(pa) * .32 * sz, math.sin(pa) * .32 * sz, .12 * sz)), .24 * sz, 'cam', sq=(1, 1, .45)), col=hexc('#f6c418')))
                o.append(M(Ball(tuple(fpos + V(0, 0, .18 * sz)), .14 * sz, 'cam'), col=hexc('#c86a10')))
    else:                # cau con: thân có khoanh, tàu lá kép
        tip = top + V(0, 0, 3.6 * sz)
        o.append(M(Line([tuple(top), tuple(tip)], [.28 * sz, .18 * sz], 'go2', nodes=.7 * sz), col=hexc('#7a8a4a')))
        for k in range(5):
            ang = k / 5 * 2 * np.pi + rs.uniform(0, .3)
            d = V(math.cos(ang), math.sin(ang), 0)
            pa = tip; pb = tip + d * 1.4 * sz + V(0, 0, .5 * sz); pc = tip + d * 2.6 * sz + V(0, 0, -.5 * sz)
            o.append(M(Line([tuple(pa), tuple(pb), tuple(pc)], [.1 * sz, .08 * sz, .05 * sz], 'go2'), col=hexc('#5a7a3a')))
            sd = nz(np.cross(V(0, 0, 1), d))
            for j in range(4):
                t = .25 + j * .22
                p = pa + (pb - pa) * min(1, t * 2) if t < .5 else pb + (pc - pb) * (t - .5) * 2
                for e in (-1, 1):
                    o.append(leaf(p, sd * e + d * .5 + V(0, 0, -.2), 1.1 * sz, .25 * sz, '#62ae44', bend=.2))
    return grp(o)


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


def mui(fr, u0, u1, R, zt, col='#cfae72'):
    """mui xuồng: vòm tre đan khum trên mép"""
    A = fr.w(u0, 0, zt)
    t = Tube(tuple(A), tuple(fr.U), u1 - u0, [(0, R), (1, R * .96)], 'dan', shell=.45, open0=True, open1=True, wv=(30, .12))
    M(t, col=hexc(col), sp=.06)
    return Cut(t, tuple(A), (0, 0, -1))


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


def cabin(fr, h, u0, u1, walk, Hw, wall='#a9cdd0', roof='#9a4b34', shut='#b8452e'):
    """nhà ghe: vách ván sơn có cửa sổ, mái tôn khum, chậu kiểng trên mái.
    bề ngang = chỗ hẹp nhất của thân trong đoạn nhà trừ lối đi 2 bên (walk); mái nhô vừa phủ lối đi, không ra ngoài mạn"""
    L = h.L
    wmin = min(w_at(h, a) for a in np.linspace((u0 - 1.4) / L, (u1 + 1.4) / L, 12))
    hw = wmin - walk
    zd = min(zt_at(h, u0 / L), zt_at(h, u1 / L)) - .6
    uc = (u0 + u1) / 2; hl = (u1 - u0) / 2
    wall_b = Box(tuple(fr.w(uc, 0, zd + Hw / 2)), (fr.U, fr.Vv, (0, 0, 1)), (hl, hw, Hw / 2), 'van', rr=.25)
    wall_b.col = hexc(wall); wall_b.win = 5.2; wall_b.sh = shut
    o = [wall_b]
    R = (wmin - .5) / .79          # nửa bề ngang mái tại mép = wmin - .5 (lọt trong mạn)
    zc = zd + Hw - R * .62
    t = Tube(tuple(fr.w(u0 - 1.2, 0, zc)), tuple(fr.U), (u1 - u0) + 2.4, [(0, R), (1, R)], 'ton', shell=.35, open0=True, open1=True)
    t.fr = fr; t.col = hexc(roof)
    o.append(Cut(t, tuple(fr.w(0, 0, zd + Hw - .25)), (0, 0, -1)))
    o[-1].fr = fr
    # chậu kiểng đặt mép mái phía trước
    ztop = zc + R
    # lối đi ván 2 bên nhà (người đi lại, đứng chống sào)
    for sd in (-1, 1):
        o.append(M(Box(tuple(fr.w(uc, sd * (hw + walk * .5), zd + .1)), (fr.U, fr.Vv, (0, 0, 1)), (hl + 1.0, walk * .5 - .1, .25), 'go2', rr=.1), col=hexc('#9a6a3e')))
    o.append(M(Box(tuple(fr.w(uc, 0, zd + Hw + .1)), (fr.U, fr.Vv, (0, 0, 1)), (hl + .6, .25, .25), 'go2', rr=.1), col=hexc('#7a4a2a')))   # đòn nóc
    return o, zd


def engine(fr, h, col='#c23b2b'):
    """máy đuôi tôm gắn trên cọc xoay ngay đuôi lái: thân máy + nắp xi lanh + bình xăng + dây giật;
    cần lái dài chìa tới trước cho người đứng trên sạp lái cầm; cây láp dài chéo ra sau, quạt sát mặt nước"""
    L = h.L
    zs = zt_at(h, -.93) - .3
    piv = V(*fr.w(-L * .95, 0, zs))
    o = [M(Line([tuple(piv + V(0, 0, -1.5)), tuple(piv + V(0, 0, 1.4))], .45, 'thep'), col=hexc('#3a3a38'))]   # cọc xoay
    k = 1.45                                # máy to rõ nhìn từ xa
    c = piv + V(0, 0, 2.6 * k)
    ax = (fr.U, fr.Vv, (0, 0, 1))
    o.append(M(Line([tuple(piv + V(0, 0, 1.2)), tuple(c - V(0, 0, 1.0 * k))], .5, 'thep'), col=hexc('#4a4a48')))   # chân đế
    o.append(M(Box(tuple(c), ax, (1.8 * k, 1.3 * k, 1.2 * k), 'dco', rr=.4 * k), col=hexc(col) * 1.12, sp=.4, pw=34))                    # thân máy
    o.append(M(Box(tuple(c + V(0, 0, 1.35 * k) - fr.U * .3 * k), ax, (1.2 * k, 1.0 * k, .35 * k), 'dco', rr=.2 * k), col=hexc('#5a5a58'), sp=.3, pw=30))   # nắp xi lanh
    for e in (-.5, 0, .5):   # cánh tản nhiệt
        o.append(M(Box(tuple(c + V(0, 0, 1.75 * k) - fr.U * (.3 - e) * k), ax, (.08 * k, .9 * k, .12 * k), 'thep'), col=hexc('#8a8a86')))
    o.append(M(Ell(tuple(c + V(0, 0, 2.1 * k) + fr.U * .5 * k), ax, (1.1 * k, .75 * k, .5 * k), 'dco'), col=hexc('#f0c430'), sp=.45, pw=40))          # bình xăng
    o.append(M(Torus(tuple(c + fr.Vv * 1.35 * k), tuple(fr.Vv), .7 * k, .18 * k, 'dco'), col=hexc('#3a3a3a')))                                 # bánh dây giật
    o.append(M(Line([tuple(c - fr.U * 1.6 * k + V(0, 0, .6 * k)), tuple(c - fr.U * 2.6 * k + V(0, 0, 1.4 * k))], .3, 'thep'), col=hexc('#6a6a68')))   # ống pô
    # cần lái: từ máy chìa tới trước, tay nắm cao ngang hông người đứng
    g0 = c + fr.U * 1.6 * k + V(0, 0, .3)
    g1 = c + fr.U * 8.5 + fr.Vv * .9 + V(0, 0, 1.0)
    o.append(M(Line([tuple(g0), tuple(g1)], .32, 'thep'), col=hexc('#8a8a86')))
    o.append(M(Line([tuple(g1), tuple(g1 + nz(g1 - g0) * 1.6)], .38, 'dco'), col=hexc('#1e1e1e')))               # tay nắm cao su
    # cây láp dài ra sau, chéo xuống, quạt 3 cánh sát mặt nước
    s0 = c - fr.U * 1.6 * k - V(0, 0, .4)
    tip = V(*fr.w(-L * .95 - 13, 0, -.6))
    o.append(M(Line([tuple(s0), tuple(tip)], .3, 'thep'), col=hexc('#9a9a94')))
    d = nz(tip - s0)
    o.append(M(Box(tuple(s0 + (tip - s0) * .55 + V(0, 0, .45)), (d, fr.Vv, nz(np.cross(d, fr.Vv))), (2.4, .35, .1), 'thep', rr=.06), col=hexc('#7a7a74')))   # chắn láp
    hub = tip + d * .5
    for k in range(3):
        ang = k / 3 * 2 * np.pi + .4
        bd = nz(fr.Vv * math.cos(ang) + nz(np.cross(d, fr.Vv)) * math.sin(ang))
        o.append(M(Ell(tuple(hub + bd * .9), (bd, d, nz(np.cross(bd, d))), (.95, .5, .08), 'dco'), col=hexc('#c8b060'), sp=.6, pw=50))
    o.append(M(Ball(tuple(hub), .35, 'thep'), col=hexc('#b0a060')))
    return grp(o)


def stand_mat(fr, h, a):
    """chỗ đứng cầm lái: tấm ván lót + vạch mòn ngay trước máy"""
    L = h.L
    z = zt_at(h, a) - .2
    o = [M(Box(tuple(fr.w(a * L, 0, z)), (fr.U, fr.Vv, (0, 0, 1)), (3.0, 2.6, .14), 'go2', rr=.1), col=hexc('#c8a870'))]   # chiếu đệm sáng màu
    for e in (-1.8, 0, 1.8):   # nẹp lót chiếu
        o.append(M(Box(tuple(fr.w(a * L + e, 0, z + .12)), (fr.U, fr.Vv, (0, 0, 1)), (.12, 2.5, .05), 'go2'), col=hexc('#8a6a40')))
    return o


def deck(fr, h, a0, a1, col=None):
    """sàn ván mũi / lái ngang mép ghe: chia khúc ăn theo bề ngang thân (không lòi ra mạn)"""
    L = h.L
    c = col if col is not None else (h.band * .92 if getattr(h, 'band', None) is not None else hexc('#8a5a32'))
    lo, hi = min(a0, a1), max(a0, a1)
    n = max(1, int(math.ceil((hi - lo) / .07)))
    o = []
    for i in range(n):
        b0 = lo + (hi - lo) * i / n; b1 = lo + (hi - lo) * (i + 1) / n
        am = (b0 + b1) / 2
        ae = max(abs(b0), abs(b1))
        z = zt_at(h, am) - .55
        o.append(M(Box(tuple(fr.w(am * L, 0, z)), (fr.U, fr.Vv, (0, 0, 1)), ((b1 - b0) * L / 2 + .05, max(w_at(h, ae) - .4, .5), .3), 'go2', rr=.12), col=c))
    return o


def thwarts(fr, h, list_a, col='#6a4024'):
    L = h.L
    o = []
    for uu in list_a:
        o.append(M(Box(tuple(fr.w(uu * L, 0, zt_at(h, uu) - .5)), (fr.U, fr.Vv, (0, 0, 1)), (.7, w_at(h, uu) - .3, .3), 'go2', rr=.15), col=hexc(col)))
    return o


def awning(fr, h, u0, u1, zf, col, col2, head=13.5):
    """mái bạt ghe chợ: cao ngang đầu người đứng (head trên sạp), 6 cột tre + đòn ngang + đòn nóc,
    bạt căng hơi khum phía trên, 2 bên trống để người đứng bán / cầm lái"""
    L = h.L
    hw = min(w_at(h, a) for a in np.linspace(u0 / L, u1 / L, 10)) - .6
    zdeck = zt_at(h, (u0 + u1) / 2 / L) - .5
    zr = zdeck + head                      # mép bạt
    sag = 2.0                              # độ khum bạt
    R = (hw * hw / sag + sag) / 2
    o = []
    for uu in (u0 + .8, (u0 + u1) / 2, u1 - .8):
        for sd in (-1, 1):
            a_ = uu / L
            o.append(bamboo(fr.w(uu, sd * (w_at(h, a_) - .9), zt_at(h, a_) - .3), fr.w(uu, sd * (hw - .3), zr - .2), .34))
        o.append(bamboo(fr.w(uu, -hw, zr - .1), fr.w(uu, hw, zr - .1), .3))   # đòn ngang đầu cột
    o.append(bamboo(fr.w(u0 - .4, 0, zr + sag - .1), fr.w(u1 + .4, 0, zr + sag - .1), .32))   # đòn nóc
    t = Tube(tuple(fr.w(u0 - .6, 0, zr + sag - R)), tuple(fr.U), u1 - u0 + 1.2, [(0, R), (1, R)], 'bat', shell=.22, open0=True, open1=True)
    t.fr = fr; t.col = hexc(col); t.col2 = hexc(col2)
    c = Cut(t, tuple(fr.w(0, 0, zr)), (0, 0, -1)); c.fr = fr; c.col2 = t.col2
    o.append(c)
    # diềm bạt rủ 2 bên mép
    for sd in (-1, 1):
        o.append(M(Box(tuple(fr.w((u0 + u1) / 2, sd * (hw + .05), zr - .5)), (fr.U, fr.Vv, (0, 0, 1)), ((u1 - u0) / 2 + .6, .08, .6), 'cam', rr=.05), col=hexc(col)))
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
    cols = ['#c8975e', '#b88a52', '#d4a86e', '#ac7e4c']
    uu = u0
    while uu < u1 - 4:
        a = uu / L
        wd = w_at(h, min(abs(a) + .06, .99)) - 2.8
        hx = rs.uniform(2.3, 2.9)
        n = 2 if wd > 7 else 1
        for j in range(n):
            hy = (wd / n) - .25
            v = (j - (n - 1) / 2) * (wd * 2 / n)
            hz1 = rs.uniform(2.6, 3.0)
            o += crate(fr, uu + hx, v, zf, hx, hy * .96, hz1, cols[rs.randint(4)], rs.uniform(-.04, .04))
            # tầng 2 luôn có, nhỏ hơn chút
            o += crate(fr, uu + hx + rs.uniform(-.3, .3), v + rs.uniform(-.3, .3), zf + hz1 * 2 + .15, hx * .88, hy * .84, rs.uniform(2.0, 2.4), cols[rs.randint(4)], rs.uniform(-.06, .06))
        uu += hx * 2 + .35
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
        o.append(M(Line([tuple(a), tuple(b)], .44, 'cui'), col=hexc(['#b08a5a', '#9a7648', '#c49c68'][k % 3])))
    for e in (-.3, .3):
        o.append(M(Torus(tuple(fr.w(u + e * ln, v, z0 + r)), tuple(fr.U), r * .9, .18, 'may'), col=hexc('#5a3a1e')))
    return o


def salt_jar(fr, c, r=1.8):
    """lu muối hột: lu sành nâu, muối trắng đầy miệng"""
    c = V(*c)
    return [M(Ball(tuple(c + V(0, 0, r * 1.1)), r, 'chum', sq=(1, 1, 1.15)), sp=.5, pw=40),
            M(Torus(tuple(c + V(0, 0, r * 2.12)), (0, 0, 1), r * .6, r * .13, 'chum'), sp=.5, pw=40),   # vành miệng lu
            M(Ball(tuple(c + V(0, 0, r * 2.2)), r * .6, 'muoi', sq=(1, 1, .55)), col=hexc('#fafaf4'))]   # muối hột vun


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
        uu = -L * .33; i = 0
        rows = [2, 0, 1, 4, 3, 2]          # mỗi hàng 1 loại: mai / bưởi con / phát tài / cam con / cau con
        while uu < L * .14:
            wd = w_at(h, uu / L) - 2.8
            n = max(2, int(wd * 2 / 5.0) + 1)
            for j, vv in enumerate(np.linspace(-wd, wd, n)):
                o += seedling(fr, fr.w(uu + rs.uniform(-.2, .2), vv, zf), 1.3 + rs.uniform(-.05, .1), rows[i % 6], seed + i * 7 + j)
            uu += 5.2; i += 1
        wd = w_at(h, .28) - 3.6
        o += tub(fr, fr.w(L * .28, -wd * .55, zf), 3.0) + tub(fr, fr.w(L * .28, wd * .55, zf), 3.0, '#d04a3a')
        wd = w_at(h, .44) - 3.2
        o += duck_cage(fr, fr.w(L * .44, -wd * .5, zf), 2.7) + duck_cage(fr, fr.w(L * .44, wd * .5, zf), 2.7)
    elif kind == 'trai':  # mô trái cây miệt vườn chất cao + buồng chuối
        kinds = ['dua', 'xoai', 'khom', 'bi', 'dua2', 'cam', 'xoai', 'dua', 'bi', 'cam']
        cs = 1.25; step = 3.6 * cs; ki = 0
        for ly in range(4):                  # mô trái: lớp dưới kín khoang, mỗi lớp hụt vào 2 bên + 2 đầu
            sh = ly * step * .6
            uu = -L * .46 + sh + step / 2 + (step * .5 if ly % 2 else 0)
            while uu < L * .44 - sh - step / 2:
                wdl = min(w_at(h, uu / L) - 2.2, Wb * .66) - ly * step * .55
                nj = max(1, int(wdl * 2 / step) + (0 if ly else 1))
                for j in range(nj):
                    vv = (j - (nj - 1) / 2) * step * (.92 if ly == 0 else 1) + rs.uniform(-.3, .3)
                    o += fruit(fr, kinds[(ki + j * 3 + ly) % len(kinds)], fr.w(uu + rs.uniform(-.4, .4), vv, zf + (2.0 + ly * 2.9) * cs), cs, seed + ki)
                uu += step; ki += 1
        # nải chuối xếp nằm gọn dưới sàn khoang, giữa sạp lái và mô trái, cuống quay về lái
        yw = math.atan2(fr.U[1], fr.U[0])
        for vv, dz_ in ((-2.3, 0), (2.3, 0), (0, 1.3)):
            o += fruit(fr, 'chuoi', fr.w(-L * .55, vv, zf + .3 + dz_), 1.15, seed, yaw=yw)
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
        o += thung(fr, L * .67, -3.6, zf, 2.7, 'lua', seed + 1) + thung(fr, L * .67, 3.6, zf, 2.7, 'lua', seed + 2)
    else:                 # đồ bếp: củi chất đống phía lái, lu muối hột giữa, nồi đất + bao muối phía mũi
        rb = 1.35                            # bó củi chẻ buộc mây, chất kim tự tháp 3 tầng, 2 dãy dọc khoang
        for pc in (-L * .4, -L * .26):
            wd = w_at(h, pc / L) - 1.6
            for ly in range(3):
                n = int(wd * 2 / (rb * 2.1)) - ly
                if n < 1: break
                for jj in range(n):
                    vv = (jj - (n - 1) / 2) * rb * 2.1
                    o += firewood(fr, pc + rs.uniform(-.4, .4), vv, zf + ly * rb * 1.8, 7.0, rb, seed * 13 + ly * 5 + jj)
        uu = -L * .06
        while uu < L * .34:
            wd = w_at(h, uu / L) - 3.4
            for vv in (-wd * .5, wd * .5):
                o += salt_jar(fr, fr.w(uu + rs.uniform(-.2, .2), vv, zf), 2.9)
            uu += 6.6
        for vv in (-4.0, 0, 4.0):
            o += clay_pot(fr, fr.w(L * .44, vv, zf), 1.9)
            o += clay_pot(fr, fr.w(L * .44 + .3, vv * .5, zf + 2.6), 1.6) if vv else []
        o += sack(fr, L * .7, -3.4, zf, .9, col='#f2f0ea', stripe='#3a8a4a') + sack(fr, L * .7, 3.4, zf, .9, col='#f2f0ea', stripe='#3a8a4a', rot=.1)
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
        objs += rails(fr, h, .3, hexc('#5e3a20')) + stem(fr, h, '#7a4e2c', .6)
        return Scene(objs)
    if kind == 'ghe':    # ghe thương hồ: nhà ghe ván sơn xanh, mái tôn, máy đuôi tôm, khoang trước chất thùng gỗ
        Wb = 13.0
        h = paint(Hull(fr, L, Wb, 6.5, 5.6, 9.0, 6.0, t=.8), '#2f7f88', 4.6)
        objs.append(h)
        zf = max(float(h.prof(np.array([0.0]))[2][0] + (zt_at(h, 0) - h.prof(np.array([0.0]))[2][0]) * .42), .5)
        co, zd = cabin(fr, h, -L * .6, -L * .1, 2.6, 9.5)
        objs += co
        objs += deck(fr, h, .76, .9) + deck(fr, h, -.93, -.63, hexc('#a87a4a'))   # sạp lái rộng: chỗ đứng cầm lái
        objs += crates(fr, h, -L * .02, L * .5, zf, seed + 3)   # dừng trước cây bẹo .58L
        objs += beo(fr, .58 * CH * TILE, zf)
        objs += engine(fr, h) + stand_mat(fr, h, -.8)
        objs += rope(fr, h, .84)
        objs += rails(fr, h) + stem(fr, h, aft=False) + tires(fr, h, (-.5, -.2, .2, .45)) + anchor(fr, h)
        objs += laundry(fr, fr.w(-L * .1 + .6, Wb * .45, zd + 11.0), fr.w(.58 * CH * TILE - .8, .4, 26), 4, seed)
        objs += flag(fr, h, -L * .93, zt_at(h, -.93) - .3)
        objs += deck_props(fr, h, -L * .66, zt_at(h, -.66) - .3)
        return Scene(objs)
    # ghe chợ nổi (4 loại theo data)
    cs_ = CHO_SET[seed % 4]
    Wb = 11.0
    h = paint(Hull(fr, L, Wb, 5.6, 4.9, 8.0, 5.0, t=.8), cs_['band'], 3.9, trim=cs_['trim'])
    objs.append(h)
    zf = max(float(h.prof(np.array([0.0]))[2][0] + (zt_at(h, 0) - h.prof(np.array([0.0]))[2][0]) * .42), .5)
    objs += deck(fr, h, .78, .9) + deck(fr, h, -.93, -.6, hexc('#a87a4a'))   # sạp lái: chỗ đứng bán hàng / cầm lái
    if mui_on and cs_['tarp']:
        objs += awning(fr, h, -L * .5, -L * .26, zf, *cs_['tarp'])   # bạt che chỗ người đứng cầm lái / bán
    objs += cho_load(fr, h, cs_['id'], zf, Wb, seed + 5)
    objs += beo(fr, .58 * CH * TILE, zf)
    objs += engine(fr, h, ['#d0402e', '#e07a26', '#d0402e', '#e07a26'][seed % 4]) + stand_mat(fr, h, -.8)
    objs += rails(fr, h) + stem(fr, h, aft=False) + tires(fr, h, (-.35, .3)) + anchor(fr, h)
    return Scene(objs)




# ------------------------------------------------------------ chi tiết thân ghe (11-24 Link "vẽ cho chi tiết lại")
def rails(fr, h, r=.45, col=None, n=26, amax=.96):
    """nẹp mạn 2 bên chạy theo mép ghe + nẹp hông thấp hơn (gờ chắn va)"""
    L = h.L
    col = col if col is not None else hexc(getattr(h, 'trim', '#5e3a20'))
    o = []
    aa = np.linspace(-amax, amax, n)
    for sd in (-1, 1):
        pts = [tuple(fr.w(a * L, sd * (w_at(h, a) - .05), zt_at(h, a) + .05)) for a in aa]
        o.append(M(Line(pts, r, 'go2'), col=col))
        if getattr(h, 'band', None) is not None:   # gờ hông dưới dải sơn
            pts2 = []
            for a in aa[2:-2]:
                w, zt, zb = h.prof(np.array([a]))
                z = float(zt[0]) - h.bw - .2
                k = np.sqrt(np.clip(1 - ((z - float(zt[0])) / max(float(zt[0] - zb[0]), .5)) ** 2, 0, 1))
                pts2.append(tuple(fr.w(a * L, sd * (float(w[0]) * k + .05), z)))
            o.append(M(Line(pts2, r * .7, 'go2'), col=hexc(h.line) * .9))
    return o


def stem(fr, h, col='#b8382a', big=1.0, aft=True):
    """cột mũi cong vểnh + cột lái"""
    L = h.L
    z1 = zt_at(h, .99)
    o = [M(Line([tuple(fr.w(L * .985, 0, z1 - 2.5 * big)), tuple(fr.w(L * 1.01, 0, z1 + .5)), tuple(fr.w(L * 1.0, 0, z1 + 2.6 * big)), tuple(fr.w(L * .975, 0, z1 + 3.4 * big))],
                [.7 * big, .65 * big, .55 * big, .45 * big], 'go2'), col=hexc(col))]
    if not aft:
        return o
    z0 = zt_at(h, -.99)
    o.append(M(Line([tuple(fr.w(-L * .985, 0, z0 - 2 * big)), tuple(fr.w(-L * 1.005, 0, z0 + .4)), tuple(fr.w(-L * .99, 0, z0 + 1.8 * big))], [.6 * big, .55 * big, .45 * big], 'go2'), col=hexc(col)))
    return o


def tires(fr, h, us=(-.3, .05, .4), side=(-1, 1)):
    """vỏ xe cũ treo mạn làm đệm chống va"""
    L = h.L
    o = []
    for a in us:
        for sd in side:
            w = w_at(h, a); z = zt_at(h, a)
            c = fr.w(a * L, sd * (w + .55), z - 1.9)
            o.append(M(Torus(tuple(c), tuple(fr.Vv * sd), 1.35, .5, 'dco'), col=hexc('#26241f'), sp=.15, pw=20))
            o.append(M(Line([tuple(fr.w(a * L, sd * (w - .1), z + .2)), tuple(c + V(0, 0, 1.3))], .12, 'day'), col=hexc('#c8b07a')))
    return o


def rudder(fr, h):
    """bánh lái ván sau lái + cần lái"""
    L = h.L
    z0 = zt_at(h, -.97)
    o = [M(Box(tuple(fr.w(-L - 1.6, 0, -1.0)), (fr.U, fr.Vv, (0, 0, 1)), (1.7, .22, 3.0), 'go2', rr=.15), col=hexc('#5a3a22'))]
    o.append(M(Line([tuple(fr.w(-L - 1.2, 0, 1.6)), tuple(fr.w(-L - 1.0, 0, z0 + 1.2)), tuple(fr.w(-L + 4.5, .8, z0 + 2.0))], .25, 'go2'), col=hexc('#7a5230')))
    return o


def anchor(fr, h):
    """mỏ neo sắt trên sạp mũi + cuộn xích"""
    L = h.L
    z = zt_at(h, .84) - .2
    c = V(*fr.w(L * .84, -1.4, z))
    o = [M(Line([tuple(c - fr.U * 1.6), tuple(c + fr.U * 1.6)], .28, 'thep'), col=hexc('#4a4a48'))]
    for e in (-1, 1):
        o.append(M(Line([tuple(c + fr.U * 1.6), tuple(c + fr.U * 1.1 + fr.Vv * e * 1.2)], .24, 'thep'), col=hexc('#4a4a48')))
    o.append(M(Torus(tuple(c - fr.U * 1.9), (0, 0, 1), .5, .16, 'thep'), col=hexc('#4a4a48')))
    return o


def laundry(fr, a, b, n=4, seed=0):
    """dây phơi đồ: dây chùng + áo quần phơi"""
    a = V(*a); b = V(*b)
    rs = np.random.RandomState(seed)
    mid = (a + b) / 2 + V(0, 0, -.8)
    o = [M(Line([tuple(a), tuple(mid), tuple(b)], .1, 'day'), col=hexc('#d8d0b8'))]
    d = nz(b - a); sd = nz(np.cross(V(0, 0, 1), d))
    cols = ['#d84a3a', '#3a6ab8', '#f0e8d0', '#e8b030', '#4a8a4a']
    for k in range(n):
        t = (k + .7) / (n + .4)
        p = a + (b - a) * t + V(0, 0, -.8 * (1 - (2 * t - 1) ** 2) - 1.3)
        hz = rs.uniform(1.0, 1.6)
        o.append(M(Box(tuple(p + V(0, 0, -hz + 1.2)), (d, sd, (0, 0, 1)), (rs.uniform(.9, 1.3), .08, hz), 'cam', rr=.06), col=hexc(cols[(k + seed) % 5])))
    return o


def flag(fr, h, u, z0, ht=11.0):
    """cột cờ nhỏ sau lái, cờ đỏ"""
    top = fr.w(u, 0, z0 + ht)
    o = [M(Line([tuple(fr.w(u, 0, z0)), tuple(top)], .2, 'go2'), col=hexc('#d8c89a'))]
    c = top + fr.U * -1.6 + V(0, 0, -1.0)
    o.append(M(Box(tuple(c), (fr.U, fr.Vv, (0, 0, 1)), (1.5, .06, 1.0), 'cam', rr=.04), col=hexc('#d42a20')))
    o.append(M(Ball(tuple(c + fr.Vv * .1), .42, 'cam', sq=(1, .2, 1)), col=hexc('#f6d020')))
    o.append(M(Ball(tuple(c - fr.Vv * .1), .42, 'cam', sq=(1, .2, 1)), col=hexc('#f6d020')))
    return o


def deck_props(fr, h, u, zd):
    """đồ sinh hoạt trên sạp: lu nước, bình gas đỏ, thau, can nhựa"""
    o = []
    o += [M(Ball(tuple(fr.w(u, -2.6, zd + 2.0)), 1.8, 'chum', sq=(1, 1, 1.15)), sp=.5, pw=40),
          M(Torus(tuple(fr.w(u, -2.6, zd + 4.0)), (0, 0, 1), 1.05, .3, 'chum'), sp=.5, pw=40)]
    o.append(M(Tube(tuple(fr.w(u + .4, 2.4, zd)), (0, 0, 1), 2.6, [(0, 1.0), (.8, 1.0), (1, .55)], 'dco', shell=0.0), col=hexc('#c83a2a'), sp=.35, pw=30))
    o.append(M(Tube(tuple(fr.w(u - 2.4, 3.0, zd)), (0, 0, 1), .8, [(0, 1.1), (1, 1.5)], 'dco', shell=.2, open1=True), col=hexc('#3a8ac8'), sp=.3, pw=30))
    return o


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
