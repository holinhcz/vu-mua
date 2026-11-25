#!/usr/bin/env python3
# ỐC BƯƠU + ỐC GẠO (11-25 Link "vẽ ốc bươu ốc gạo lại theo bộ vẽ của mấy con cá"). v3 vẽ lại từ đầu (Link chê v2 "như con ặc":
# vòng xoắn là cục tròn chồng nhau, miệng như miếng dán). Giờ vỏ là 1 ỐNG XOẮN ỐC THẬT (mô hình Raup: ống tròn cuộn quanh trục,
# to dần W lần mỗi vòng, tụt xuống T), rải điểm dày lên lưới ảnh có z-buffer -> mỗi điểm ảnh biết nó ở vòng nào (θ) và chỗ nào
# quanh ống (φ): vân tăng trưởng chạy theo θ, sọc xoắn theo φ, đường khâu giữa các vòng tự ra (chỗ 2 vòng cắt nhau, có bóng),
# miệng ốc là đầu ống (môi ngoài là mép vỏ), nhìn vào trong thấy lòng vỏ, nắp đậy lùi vào trong miệng.
# Tô cùng kiểu cá/cua: sáng trên-trái (LIGHT của moi_ve), mờ không bóng loáng, viền mảnh màu tối của chỗ đó. Không vẽ thân ốc.
#  oc_buou: tròn bầu, vòng thân rất to, chóp thấp mòn bạc; xanh rêu nâu sọc xoắn tối; lòng miệng tím nâu, môi đen; nắp nâu sẫm
#  oc:      ốc gạo nhỏ, vỏ mỏng vàng ngà, chóp nhọn cao hơn, vòng tròn có khâu sâu, chỉ xoắn nâu mảnh; lòng trắng xanh; nắp nâu hổ phách
# python3 ve_oc.py OUTDIR [oc_buou oc]   (ra OUTDIR/<id>.webp + .png, ảnh gốc cho Kho: art/cc_fish/<id>.webp)
import os, sys, math
os.environ.setdefault('MOI_SC', '3.6')      # 6px chuẩn (như cá RES 3.6)
OUTDIR = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/oc/f'
WHO = sys.argv[2:] or ['oc_buou', 'oc']
sys.argv = [sys.argv[0], OUTDIR]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from moi_ve import *          # noqa
import numpy as np
from scipy import ndimage as ndi

G = N // 2                    # lưới rải điểm = cỡ ảnh ra (N là lưới vẽ x2)
PG = PX / 2


def rot_mat(beta, roll, pitch):
    cb, sb = math.cos(beta), math.sin(beta)
    Rz = np.array([[cb, -sb, 0], [sb, cb, 0], [0, 0, 1]])
    cr, sr = math.cos(roll), math.sin(roll)
    Ry = np.array([[cr, 0, -sr], [0, 1, 0], [sr, 0, cr]])       # chóp (z+) ngả sang trái
    cp, sp = math.cos(pitch), math.sin(pitch)
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])       # nhìn hơi từ trên xuống
    return Rx @ Ry @ Rz


class Shell:
    """ống xoắn: θ ≤ 0 (0 = miệng), ψ = -θ (xoắn phải), rc = W^(θ/2π), bán kính ống a = ar·rc (môi loe ra ở cuối)"""
    def __init__(s, W, T, ar, e, turns, beta, roll, pitch, flare=.1, lid=.16, obl=0.0, obl0=math.pi):
        s.W, s.T, s.ar, s.e, s.turns, s.flare, s.lid = W, T, ar, e, turns, flare, lid
        s.obl, s.obl0 = obl, obl0          # miệng xiên: môi trong (áp vào vòng trước) dừng sớm hơn môi ngoài obl rad
        s.R = rot_mat(beta, roll, pitch)
        s.lnW = math.log(W)

    def a_of(s, th):
        rc = s.W ** (th / (2 * math.pi))
        fl = 1 + s.flare * np.clip((th + .09) / .09, 0, 1) ** 2 if not s.obl else 1.0
        return rc, s.ar * rc * fl

    def pts(s, th, ph):
        rc, a = s.a_of(th)
        ps = -th
        cph, sph = np.cos(ph), np.sin(ph)
        rr = rc + a * cph
        P = np.stack([rr * np.cos(ps), rr * np.sin(ps), -s.T * rc + a * s.e * sph], -1)
        rcd = rc * s.lnW / (2 * math.pi)
        ad = s.ar * rcd                                   # (bỏ qua đạo hàm của môi loe)
        dth = np.stack([(rcd + ad * cph) * np.cos(ps) + rr * np.sin(ps),
                        (rcd + ad * cph) * np.sin(ps) - rr * np.cos(ps),
                        -s.T * rcd + ad * s.e * sph], -1)
        dph = np.stack([-a * sph * np.cos(ps), -a * sph * np.sin(ps), a * s.e * cph], -1)
        n = np.cross(dph, dth)
        return P, n

    def lid_pts(s, t, ph):
        th = -s.lid
        rc, a = s.a_of(th); rc = float(rc); a = float(np.asarray(a))
        ps = -th
        c = np.array([rc * math.cos(ps), rc * math.sin(ps), -s.T * rc])
        rad = np.array([math.cos(ps), math.sin(ps), 0.0]); up = np.array([0, 0, 1.0])
        k = .985 * a
        P = c + (k * t * np.cos(ph))[..., None] * rad + (k * s.e * t * np.sin(ph))[..., None] * up
        rcd = rc * s.lnW / (2 * math.pi)
        tang = np.array([rcd * math.cos(ps) + rc * math.sin(ps), rcd * math.sin(ps) - rc * math.cos(ps), -s.T * rcd])
        tang /= np.linalg.norm(tang)
        dome = .25 * t                                   # nắp hơi phồng
        P = P + (dome * k * .0)[..., None] * tang
        n = np.broadcast_to(tang, P.shape) + (t * np.cos(ph) * .3)[..., None] * rad + (t * np.sin(ph) * .3)[..., None] * up
        return P, n

    def render(s, cx, cy, height, width=440):
        # cỡ + chỗ đặt: lấy khung bao từ mẫu thưa
        th = np.linspace(-2 * math.pi * s.turns, 0, 600)[:, None]; ph = np.linspace(-math.pi, math.pi, 80)[None, :]
        P, _ = s.pts(th, ph)
        Q = P.reshape(-1, 3) @ s.R.T
        sx, sy = Q[:, 0], -Q[:, 2]
        sc = min(height / (sy.max() - sy.min()), width / (sx.max() - sx.min()))
        ox = cx - sc * (sx.max() + sx.min()) / 2; oy = cy - sc * (sy.max() + sy.min()) / 2
        zb = np.full(G * G, np.inf, np.float32)
        att = np.zeros((G * G, 6), np.float32)          # θ, φ, nx, ny, nz (màn hình, z ra mặt), loại (0 vỏ, 1 nắp; θ=t ở nắp)

        def splat(P, n, a0, a1, kind):
            Q = P.reshape(-1, 3) @ s.R.T
            nn = n.reshape(-1, 3) @ s.R.T
            nn /= np.linalg.norm(nn, axis=1, keepdims=True) + 1e-9
            px = (ox + sc * Q[:, 0]) * PG; py = (oy - sc * Q[:, 2]) * PG
            d = Q[:, 1]
            ix = px.astype(np.int32); iy = py.astype(np.int32)
            ok = (ix >= 0) & (ix < G) & (iy >= 0) & (iy < G)
            idx = (iy * G + ix)[ok]; d = d[ok]
            o = np.lexsort((d, idx)); idx = idx[o]; d = d[o]
            u, first = np.unique(idx, return_index=True)
            dd = d[first]
            better = dd < zb[u]
            u = u[better]; sel = np.nonzero(ok)[0][o][first][better]
            zb[u] = dd[better]
            att[u, 0] = a0.reshape(-1)[sel]; att[u, 1] = a1.reshape(-1)[sel]
            att[u, 2] = nn[sel, 0]; att[u, 3] = -nn[sel, 2]; att[u, 4] = -nn[sel, 1]; att[u, 5] = kind

        # rải dày: bước θ theo bán kính ngoài (điểm ảnh), bước φ theo bán kính ống
        step = .7
        th0 = 0.0
        ths = []
        while th0 > -2 * math.pi * s.turns:
            ths.append(th0)
            rc, a = s.a_of(th0)
            th0 -= step / max(1.0, (rc + a) * sc * PG * 1.15)
        ths = np.array(ths, np.float32)
        for i in range(0, len(ths), 400):
            tc = ths[i:i + 400]
            rc, a = s.a_of(tc[0])
            nph = int(max(24, 2 * math.pi * a * max(1, s.e) * sc * PG / step * 1.1))
            ph = np.linspace(-math.pi, math.pi, nph, endpoint=False, dtype=np.float32)
            TT, PP = np.meshgrid(tc, ph, indexing='ij')
            P, n = s.pts(TT, PP)
            if s.obl and tc[0] > -s.obl - .01:
                ok = TT <= -s.obl * ((1 + np.cos(PP - s.obl0)) / 2) ** 1.5
                P, n, TT, PP = P[ok], n[ok], TT[ok], PP[ok]
            splat(P, n, TT, PP, 0)
        # nắp
        rc, a = s.a_of(-s.lid)
        nr = int(a * sc * PG / step * 1.2) + 2
        t = np.linspace(0, 1, nr, dtype=np.float32)
        TT, PP = np.meshgrid(t, np.linspace(-math.pi, math.pi, int(2 * math.pi * a * s.e * sc * PG / step * 1.2), endpoint=False, dtype=np.float32), indexing='ij')
        P, n = s.lid_pts(TT, PP)
        splat(P, n, TT, PP, 1)
        # vá lỗ (điểm ảnh không trúng điểm nào bên trong hình)
        hit = (zb < np.inf).reshape(G, G)
        cov = ndi.binary_closing(hit, iterations=2) | hit
        cov = ndi.binary_fill_holes(cov) & ndi.binary_closing(hit, iterations=3)
        _, (iy, ix) = ndi.distance_transform_edt(~hit, return_indices=True)
        A = att.reshape(G, G, 6)[iy, ix]
        Z = zb.reshape(G, G)[iy, ix]
        Z = np.where(cov, Z, np.nan)
        s.sc = sc
        return cov.astype(np.float32), A, Z


def gnoise(scale, seed, octaves=3):
    """nhiễu mềm -1..1 trên lưới G"""
    r = np.random.RandomState(seed)
    out = np.zeros((G, G), np.float32); amp = 1.0; tot = 0
    for o in range(octaves):
        sg = scale * PG / (2 ** o)
        f = ndi.gaussian_filter(r.randn(G, G).astype(np.float32), max(.6, sg))
        f /= (f.std() + 1e-6)
        out += f * amp; tot += amp; amp *= .5
    return np.clip(out / tot / 2.2, -1, 1)


def line1d(x, seed, n=4000, lo=-1, hi=1, sm=3):
    r = np.random.RandomState(seed)
    g = ndi.gaussian_filter1d(r.randn(n), sm); g /= g.std() + 1e-6
    return np.interp(x, np.linspace(lo, hi, n), g)


def lerpg(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return a * (1 - t) + b * t


def finish(sh, cov, col, edge, name, ow=1.6):
    """đưa màu lưới G lên lưới vẽ N rồi đặt vào Pic như các mồi khác"""
    P = Pic()
    m = ndi.zoom(ndi.gaussian_filter(cov, .5), 2, order=1)[:N, :N]
    m = np.clip(m, 0, 1)
    c = np.dstack([ndi.zoom(col[..., k], 2, order=1)[:N, :N] for k in range(3)])
    P.put(m, np.clip(c, 0, 1), edge=edge, line=.35, lw=1.0, contact=0)
    im = P.save(name + '_tmp', ow=ow)
    os.replace(os.path.join(OUTDIR, 'ic-%s_tmp.webp' % name), os.path.join(OUTDIR, '%s.webp' % name))
    im.save(os.path.join(OUTDIR, '%s.png' % name))


def paint(sh, cov, A, Z, C, seed):
    th, ph, nx, ny, nz, kind = [A[..., k] for k in range(6)]
    lid = kind > .5
    back = (nz < 0) & ~lid                               # nhìn vào lòng vỏ qua miệng
    nxs, nys, nzs = np.where(back, -nx, nx), np.where(back, -ny, ny), np.where(back, -nz, nz)
    # bóng khuất theo độ sâu (đường khâu, lòng miệng)
    Zf = np.nan_to_num(Z, nan=np.nanmax(Z))
    zs = Zf * sh.sc                                      # đơn vị khung
    # ánh sáng giữ như v3; chỗ tối bớt tối bằng MÀU SƠN sáng hơn, không đổi ánh sáng (Link 11-25)
    ao = np.clip((zs - ndi.gaussian_filter(zs, 5 * PG)) / 9, 0, 1) * .55 + np.clip((zs - ndi.gaussian_filter(zs, 14 * PG)) / 30, 0, 1) * .35
    dif = np.clip(nxs * LIGHT[0] + nys * LIGHT[1] + nzs * LIGHT[2], 0, 1)
    hs = np.clip(nxs * HALF[0] + nys * HALF[1] + nzs * HALF[2], 0, 1) ** 16
    turns = th / (2 * math.pi)
    rc = sh.W ** turns
    S = rc / sh.lnW                                     # độ dài cung dọc chu vi (tỉ lệ rc)
    # --- vỏ ngoài
    mott = gnoise(16, seed + 1, 2)
    base = lerpg(C['base'], C['base2'], np.clip(.5 + mott, 0, 1))
    for (p0, w0, k0) in C['bands']:                      # sọc xoắn đậm (theo φ)
        base = lerpg(base, C['band'], np.exp(-((ph - p0) / w0) ** 2) * k0 * (1 + .25 * line1d(S, seed + 2, sm=8)))
    thr = (.5 + .5 * np.cos(ph * C['threads'])) ** 8   # chỉ xoắn mảnh
    base = base * (1 - C['thread_k'] * thr)[..., None]
    for p0 in C['lines']:
        base = lerpg(base, C['line'], np.exp(-((ph - p0) / .03) ** 2) * .6)
    lam = C['lam']                                       # vân tăng trưởng (theo θ): mảnh dày, lệch không đều, vài gờ đậm
    gph = 2 * math.pi * S / lam + 3.0 * line1d(S, seed + 3, lo=0, hi=1 / sh.lnW, sm=20)
    gr = (.5 + .5 * np.cos(gph)) ** 5
    gk = np.clip(line1d(S, seed + 4, lo=0, hi=1 / sh.lnW, sm=6) - 1.3, 0, 1)
    base = base * (1 - C.get('gr_k', .1) * gr - C.get('gk_k', .18) * gk)[..., None]
    base = lerpg(base, C['base'] * 1.1, np.clip((th + .5) / .5, 0, 1) * .45)       # mép mới mọc sáng hơn
    if C.get('apex') is not None:                        # chóp mòn bạc, sần
        wear = np.clip((-turns - (sh.turns - C['apex_t'])) / .6, 0, 1)
        base = lerpg(base, C['apex'], wear * (.75 + .25 * gnoise(2, seed + 5)))
    base = base * (1 + .05 * gnoise(1.2, seed + 6))[..., None]
    th_end = -sh.obl * ((1 + np.cos(ph - sh.obl0)) / 2) ** 1.5
    lipm = np.clip((th - th_end + C.get('lipw', .03)) / .012, 0, 1)               # môi ngoài
    base = lerpg(base, C['lip'], lipm)
    # chai môi trong (phủ trụ ốc dưới miệng): láng, không vân
    cal = np.clip((np.cos(ph - math.pi) - .2) / .4, 0, 1) * np.clip((th + 1.4) / .5, 0, 1)
    base = lerpg(base, C.get('cal', C['lip']), cal * .85)
    gr = gr * (1 - cal)
    lum = .44 + .74 * dif - .1 * gr * (1 - lipm)
    col = base * lum[..., None] + .06 * hs[..., None]
    # --- lòng vỏ
    dep = np.clip(-(th - th_end) / .9, 0, 1)
    inn = lerpg(C['in'], C['in_deep'], dep)
    inn = lerpg(inn, C['lip'], lipm)
    ci = inn * (.5 + .5 * dif)[..., None]
    col = np.where(back[..., None], ci, col)
    # --- nắp: vân vòng đồng tâm quanh nhân lệch về phía trục
    t = th
    ux, uy = t * np.cos(ph), t * np.sin(ph)
    rr = np.hypot(ux + .35, (uy + .3) * .95)
    ring = (.5 + .5 * np.cos(rr * 2 * math.pi * C['lid_rings'] + 1.5 * gnoise(3, seed + 7, 2))) ** 3
    lb = lerpg(C['lid'], C['lid2'], np.clip(rr / 1.2, 0, 1))
    lb = lb * (1 - .07 * ring)[..., None] * (1 + .05 * gnoise(1, seed + 8))[..., None]
    lb = lerpg(lb, C['lid2'] * .9, np.clip((t - .9) / .1, 0, 1))
    cl = lb * (.5 + .7 * dif)[..., None] + .08 * hs[..., None]
    col = np.where(lid[..., None], cl, col)
    col = col * (1 - ao * np.where(lid, .35, 1))[..., None]
    return col


CB = dict(base=hexc('#a08c52'), base2=hexc('#8a8a4e'), band=hexc('#6e5c38'), line=hexc('#5a4a2e'),
         bands=[(.95, .1, .35), (.35, .14, .3), (-.3, .12, .35), (-.95, .1, .28)], threads=40, thread_k=.06,
         lines=[], lam=.045, apex=hexc('#c8c0ac'), apex_t=1.6,
         lip=hexc('#6e543a'), cal=hexc('#8a7250'), **{'in': hexc('#b89aa8')}, in_deep=hexc('#8a6a7c'),
         lid=hexc('#cca674'), lid2=hexc('#aa865a'), lid_rings=9)
CG = dict(base=hexc('#e2c98e'), base2=hexc('#d2c286'), band=hexc('#b8955e'), line=hexc('#9a7448'),
         bands=[(.1, .4, .18)], threads=56, thread_k=.04,
         lines=[-.9, -.4, .15, .6, 1.1], lam=.03, gr_k=.04, gk_k=.0, apex=hexc('#9c7650'), apex_t=1.0,
         lip=hexc('#efe4c8'), cal=hexc('#e2d4ae'), **{'in': hexc('#e6e2d8')}, in_deep=hexc('#b8b2a6'),
         lid=hexc('#dcaa6a'), lid2=hexc('#bc8a52'), lid_rings=11)


def oc_buou():
    sh = Shell(W=3.0, T=2.2, ar=.95, e=1.35, turns=4.0, beta=.45, roll=.18, pitch=.22, flare=.06, lid=.2, obl=.5)
    cov, A, Z = sh.render(256, 256, 400)
    C = CB
    col = paint(sh, cov, A, Z, C, 300)
    finish(sh, cov, col, hexc('#2e2416'), 'oc_buou')


def oc():
    sh = Shell(W=1.85, T=2.8, ar=.85, e=1.25, turns=5.5, beta=.5, roll=.2, pitch=.2, flare=.05, lid=.2, obl=.5)
    cov, A, Z = sh.render(256, 256, 400)
    C = CG
    col = paint(sh, cov, A, Z, C, 700)
    finish(sh, cov, col, hexc('#4e3a22'), 'oc')


if __name__ == '__main__':
    os.makedirs(OUTDIR, exist_ok=True)
    for w in WHO:
        globals()[w]()
