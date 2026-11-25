#!/usr/bin/env python3
# THUYỀN NAN (công trình "boat", 2x1 ô, chỉ đặt trên nước) dựng 3D, thay godot/congtrinh/ghe/d0-d3 (web at.builds.boat.draw).
# Kích thước theo logic cũ (at.P(2,1): ô 64x32, z web = .866 z thế giới, mặt nước web z 2.4):
#   thân dài 1.84 ô, nửa bề ngang .21 ô, mép giữa cao 6 -> 2 đầu 16, đáy -1.5; mui nan giữa u .5..1.5, cao tới 19;
#   sào cắm mũi u 1.72 -> 1.84 cao 44 (xuống nước -6); cọc buộc đuôi (-.06, .84) cao 13, dây lên thuyền (.3, .6).
# Thân đan nan tre trét chai (ngoài nâu đen, lòng nan mộc), sơn 1 dải dưới mép: chẵn đỏ, lẻ xanh (như t%2 bản cũ).
#   PXU=9 SSA=2 python3 nan3d.py OUTDIR [0 1 2 3]  -> d<k>.png + atlas.json (px_per_unit, frames w h ox oy gw gh như bản cũ)
import os, sys, math, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ghe3d as G
B = G.B
from bay3d import V, nz, hexc, sstep, vnoise, Tube, Torus, Line, Ball, Box, M, Scene, F32
from ghe3d import Frame, Hull, Cut, Cone, TILE, ZK, zt_at, w_at, rails, oars, rope, thwarts
import numpy as np

WZ = 2.4                      # mặt nước web (z px)
def wz(z_web):                # z web -> z thế giới (mặt nước = 0)
    return (z_web - WZ) * ZK

_prev = B.albedo


def albedo_nan(obj, P):
    if obj.mat == 'nan':      # thân đan nan chéo: ngoài trét chai nâu đen, lòng nan mộc; dải sơn dưới mép
        u, v, z, a, w, zt, zb, outer, inner, ends = obj.parts(P)
        out = (np.abs(outer) < np.abs(inner))
        dz = zt - z
        W0 = 1.5
        p = (u + dz * 1.0) / W0; q = (u - dz * 1.0) / W0
        ip = np.floor(p); iq = np.floor(q); fp = p - ip; fq = q - iq
        top = ((ip + iq) % 2) == 0                       # nan nào nằm trên
        f = np.where(top, fp, fq); k = np.where(top, ip, iq)
        edge = np.exp(-((f - .5) / .36) ** 8)            # giữa nan sáng, mép nan tối
        tone = (B.hsh(k * 3.1 + top * 7) - .5) * .18
        nz_ = vnoise(P, 1.2, 31) - .5
        tar = hexc('#5c4230')[None] * (.78 + .3 * edge[:, None] + tone[:, None] + .1 * nz_[:, None])
        band = obj.band[None] * (.82 + .22 * edge[:, None] + tone[:, None] * .5)
        c_o = np.where((dz < obj.bw)[:, None], band, tar)
        c_o = np.where(((dz > obj.bw) & (dz < obj.bw + .45))[:, None], hexc('#e8dcb8')[None] * (.9 + .1 * edge[:, None]), c_o)
        bam = hexc('#c89a5c')[None] * (.74 + .32 * edge[:, None] + tone[:, None] + .08 * nz_[:, None])
        rib = np.exp(-((((u / 4.6) % 1.0) - .5) / .06) ** 2)
        c_i = bam * (1 - .28 * rib)[:, None]
        c = np.where(out[:, None], c_o, c_i)
        zf = np.maximum(zb + (zt - zb) * .42, .5)
        onfl = (np.abs(z - zf) < .5) & ~out
        plank = np.exp(-((((v / 1.6) % 1.0) - .5) / .08) ** 2)
        cf = hexc('#b48450')[None] * (1 - .3 * plank)[:, None] * (1 + .12 * nz_)[:, None]
        return np.where(onfl[:, None], cf, c)
    return _prev(obj, P)


B.albedo = albedo_nan


class Mui:
    """mui nan ÔM THEO MẠN: mặt cắt nửa elip, chân vòm chạy theo mép cong (thân thon + vểnh 2 đầu), nóc ngang bằng.
    ở mỗi u: nửa rộng = rộng thân - lùi vào (nằm trong nẹp mép), chân = mép thân, cao tới nóc htop"""
    def __init__(s, fr, h, u0, u1, htop, inset=.75, th=.45, mat='mui2'):
        s.fr = fr; s.h = h; s.u0 = u0; s.u1 = u1; s.ht = htop; s.ins = inset; s.th = th; s.mat = mat
        s.bound = (fr.w((u0 + u1) / 2, 0, htop * .6), (u1 - u0) / 2 + 14)

    def geo(s, P):
        u, v, z = s.fr.loc(P)
        a = np.clip(u / s.h.L, -1, 1)
        w, zt, zb = s.h.prof(a)
        wi = np.maximum(w - s.ins, .5); zb_ = zt - .15
        hh = np.maximum(s.ht - zb_, 1.0)
        x = v / wi; y = (z - zb_) / hh
        k = np.sqrt(x * x + y * y)
        return u, v, z, wi, zb_, hh, x, y, k

    def sdf(s, P):
        u, v, z, wi, zb_, hh, x, y, k = s.geo(P)
        d = np.abs(k - 1) * np.minimum(wi, hh) * .8 - s.th / 2
        d = np.maximum(d, zb_ - z)
        d = np.maximum(d, np.maximum(s.u0 - u, u - s.u1))
        return d

    def local(s, P):
        u, v, z, wi, zb_, hh, x, y, k = s.geo(P)
        return u, np.arctan2(np.maximum(y, 0), x), k


_prev2 = B.albedo


def albedo_mui(obj, P):
    if obj.mat == 'mui2':     # tấm nan đan mắt cáo (chéo 2 chiều), viền tre ở 2 đầu mui + chân mui
        u, ang, k = obj.local(P)
        sarc = ang * 9.0
        W0 = 1.25
        p = (u + sarc) / W0; q = (u - sarc) / W0
        ip = np.floor(p); iq = np.floor(q); fp = p - ip; fq = q - iq
        top = ((ip + iq) % 2) == 0
        f = np.where(top, fp, fq); kk = np.where(top, ip, iq)
        edge = np.exp(-((f - .5) / .36) ** 8)
        tone = (B.hsh(kk * 2.3 + top * 5) - .5) * .2
        c = hexc('#d4ae6c')[None] * (.74 + .32 * edge[:, None] + tone[:, None] + .08 * (vnoise(P, 1.5, 41) - .5)[:, None])
        rim = (np.minimum(u - obj.u0, obj.u1 - u) < .9) | (ang < .09) | (ang > np.pi - .09)
        c = np.where(rim[:, None], hexc('#8a6234')[None] * (.9 + .15 * edge[:, None]), c)
        inside = k < 1.0
        return np.where(inside[:, None], c * .82, c)
    return _prev2(obj, P)


B.albedo = albedo_mui


def boat(seed=0):
    fr = Frame(0.0, 1.0, 'u')                      # u = trục 2 ô (thế giới +y, màn hình xuống phải), mũi +u
    L = .92 * TILE                                   # nửa dài thân
    h = Hull(fr, L, .21 * TILE, wz(-1.5) * -1, wz(6), 10 * ZK, 10 * ZK, t=.55, mat='nan')
    h.band = hexc('#d9402f' if seed % 2 == 0 else '#2f7fb5'); h.bw = 2.6; h.line = '#8a5a32'; h.trim = '#8a5a32'
    o = [h]
    zf = float(h.prof(np.array([0.0]))[2][0]); zt0 = zt_at(h, 0)
    zf = max(zf + (zt0 - zf) * .42, .5)
    o += rails(fr, h, .5, hexc('#b88a50'))
    for aa in np.linspace(-.86, .86, 15):           # nẹp mây buộc mép
        for sd in (-1, 1):
            o.append(M(Torus(tuple(fr.w(aa * L, sd * (w_at(h, aa) - .1), zt_at(h, aa) - .15)), tuple(fr.U), .55, .17, 'may'), col=hexc('#7a5230')))
    o += thwarts(fr, h, (-.62, .62), '#8a5a32')
    # mui nan ôm mạn: chân vòm ngồi trong nẹp mép, theo mép cong; nóc ngang
    u0, u1 = -.5 * TILE, .5 * TILE
    htop = zt0 + 12.0
    o.append(Mui(fr, h, u0, u1, htop))
    for k in range(7):                               # vành tre ôm vòm, chân vành buộc vào mép
        uu = u0 + .45 + (u1 - u0 - .9) * k / 6
        o.append(M(Mui(fr, h, uu - .32, uu + .32, htop + .3, inset=.55, th=.7, mat='go2'), col=hexc('#8a6234')))
        aa = uu / L
        for sd in (-1, 1):
            o.append(M(Torus(tuple(fr.w(uu, sd * (w_at(h, aa) - .45), zt_at(h, aa) - .05)), tuple(fr.U), .55, .2, 'may'), col=hexc('#6a4424')))
    o.append(M(Mui(fr, h, u0 - .3, u0 + .4, htop + .25, inset=.6, th=.65, mat='go2'), col=hexc('#7a5230')))   # vành mép mui 2 đầu
    o.append(M(Mui(fr, h, u1 - .4, u1 + .3, htop + .25, inset=.6, th=.65, mat='go2'), col=hexc('#7a5230')))
    # sào cắm mũi (xuống nước), đầu sào tre
    ap = .74; vp = w_at(h, ap) + .95                  # sào cắm sát mạn mũi (phía xa, không che thuyền), buộc vào nẹp mép
    a0 = fr.w(ap * L, vp, wz(-6) - 2); a1 = fr.w(ap * L + 4.0, vp + .6, wz(44))
    o.append(M(Line([tuple(a0), tuple(a1)], [.75, .62], 'coc', nodes=7.0), col=hexc('#d3bf6a'), dk=hexc('#8a7c44')))
    zr = zt_at(h, ap)
    pr = a0 + (a1 - a0) * ((zr - a0[2]) / (a1[2] - a0[2]))
    o.append(M(Torus(tuple(pr), (0, 0, 1), .95, .26, 'day'), col=hexc('#c8a466')))
    o.append(M(Line([tuple(pr), tuple(fr.w(ap * L, w_at(h, ap) - .2, zr))], .22, 'day'), col=hexc('#c8a466')))
    o += G.stem(fr, h, '#8a5a32', .8)
    # cọc buộc đuôi + dây lên thuyền
    sx, sy = fr.w(-1.06 * TILE, -.34 * TILE, 0)[:2]      # trục o của ô = -Vv
    o.append(B.stake(sx, sy, wz(-4) - 3, wz(13), .8, nodes=5.5))
    r1 = fr.w(-1.06 * TILE, -.34 * TILE, wz(11.5)); r2 = fr.w(-.7 * TILE, -.1 * TILE, zt_at(h, -.7 / .92) - .3)
    pts = [tuple(r1 + (r2 - r1) * s + V(0, 0, -2.2 * math.sin(math.pi * s))) for s in np.linspace(0, 1, 10)]
    o.append(M(Line(pts, .22, 'day'), col=hexc('#c8a466')))
    o.append(M(Torus(tuple(r1), (0, 0, 1), .9, .25, 'day'), col=hexc('#c8a466')))
    # đồ trên thuyền theo kiểu (không người): chèo, cuộn dây, giỏ cá, nón lá
    o += oars(fr, h, 1.0 if seed % 2 == 0 else -1.0)
    o += rope(fr, h, .78)
    if seed in (1, 3):
        gb = fr.w(-.74 * L, -1.6, zf)
        o.append(M(Tube(tuple(gb), (0, 0, 1), 3.2, [(0, 1.8), (.6, 2.2), (.85, 1.3), (1, 1.5)], 'dan', shell=.25, open1=True, wv=(22, .08)), col=hexc('#c7a466')))
        o.append(M(Torus(tuple(gb + V(0, 0, 3.2)), (0, 0, 1), 1.5, .22, 'may'), col=hexc('#7a5230')))
    if seed in (2, 3):
        o.append(Cone(tuple(fr.w(.74 * L, 1.4 if seed == 2 else -1.4, zf)), 3.3, 2.5))
    return Scene(o)


def shadow(im, anc, pu):
    """bóng mềm thân thuyền trên mặt nước (như bản cũ: elip 40 x 9.5 nghiêng .46 dưới tâm), nới khung cho đủ"""
    from PIL import Image, ImageDraw, ImageFilter
    ax, ay = anc[0], anc[1] + WZ * pu                 # neo game (px)
    cx, cy = ax - 1 * pu, ay + 2.5 * pu
    rx, ry, rot = 40 * pu, 9.5 * pu, .46
    ex = math.hypot(rx * math.cos(rot), ry * math.sin(rot)); ey = math.hypot(rx * math.sin(rot), ry * math.cos(rot))
    pad = int(3 * pu)
    x0 = int(min(0, cx - ex - pad)); y0 = int(min(0, cy - ey - pad))
    x1 = int(max(im.width, cx + ex + pad)); y1 = int(max(im.height, cy + ey + pad))
    W, H = x1 - x0, y1 - y0
    sh = Image.new('L', (W * 2, H * 2), 0); d = ImageDraw.Draw(sh)
    pts = [((cx - x0 + rx * math.cos(t) * math.cos(rot) - ry * math.sin(t) * math.sin(rot)) * 2,
            (cy - y0 + rx * math.cos(t) * math.sin(rot) + ry * math.sin(t) * math.cos(rot)) * 2) for t in np.linspace(0, 2 * math.pi, 96)]
    d.polygon(pts, fill=70)
    sh = sh.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(pu * 1.6))
    cv = Image.new('RGBA', (W, H), (24, 46, 48, 0)); cv.putalpha(sh)
    cv.alpha_composite(im.convert('RGBA'), (-x0, -y0))
    bb = cv.getbbox(); cv = cv.crop(bb)
    return cv, (anc[0] - x0 - bb[0], anc[1] - y0 - bb[1])


if __name__ == '__main__':
    OUT = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    pu = B.PXU
    meta = {"px_per_unit": pu, "frames": {}}
    ap = os.path.join(OUT, 'atlas.json')
    if os.path.exists(ap):
        meta = json.load(open(ap)); meta["px_per_unit"] = pu
    for sd in [int(a) for a in (sys.argv[2:] or '0123')]:
        (im, imw), anc = B.render(boat(sd), 'd%d' % sd)
        imw, anc = shadow(imw, anc, pu)
        imw.save(os.path.join(OUT, 'd%d.png' % sd))
        ay = anc[1] + WZ * pu                         # neo game = tâm 2 ô ở z web 0 (dưới mặt nước 2.4)
        meta["frames"]['d%d' % sd] = {"file": 'd%d.png' % sd, "w": imw.width, "h": imw.height,
                                     "ox": round(-anc[0] / pu, 2), "oy": round(-ay / pu, 2), "gw": round(imw.width / pu, 2), "gh": round(imw.height / pu, 2)}
        print(sd, meta["frames"]['d%d' % sd], flush=True)
        json.dump(meta, open(ap, 'w'), indent=1)
