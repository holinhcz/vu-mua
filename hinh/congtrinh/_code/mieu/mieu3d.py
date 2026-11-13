# Miếu nhỏ (game id shrine 1x1, mirror shrine2) as a real 3D model in the kho kit, built from the đình's miễu Thần Nông
# (dinh3d.mieu: tre legs, vách on three sides, hip lá roof) so the two read as one family. Link 2026-11-09 "giờ tới công
# trình con đi" (đợt 1). Sơ cấp: tre, lá, đất only:
#  - a low earth mound; 4 tre legs carry a plank floor at chest height; vách on the back and both sides, the front open (+v)
#  - inside: a red bài vị, a lư hương with 3 nhang, a đèn dầu (lit at night), a dĩa trái cây
#  - a hip lá roof with a ridge roll; a strip of red cloth along the front eave
#  - on the ground in front: a lon nhang (3 sticks, glowing tips) stuck in the mound
#   python3 mieu3d.py prev OUT.png [n]        python3 mieu3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'dinh'))
import dinh3d as D
from dinh3d import (K, W3, T, nv, UP, Scene, X3, hexc, plane, tube, disc, lathe, box, rrect, rrect_top, extrude, bam, ell,
                    wall_u, wall_v, oillamp, hiproof, M_CLOTH, M_INCENSE, M_ORANGE, M_REDFRUIT, M_GOLD)
from kho3d import M_RATTAN as M_RATTANX, merge_all, M_EARTHSIDE, M_FLOOR, M_PLANK, M_OLDBAMBOO, M_TIN, M_EMBER, M_POT, M_BARK, mat_flat, MATS

K.BB = (-48, -104, 48, 30)
K.OX, K.OY = 0, -16                          # at.P(1,1)
ZF = 2.4
K.ZF = ZF
MU, MV, H = 0.48, 0.48, 0.22                  # miếu centre, half size (tiles)
Z0 = ZF + 14.0                                # floor top (low: a miếu, not a chòi canh)
ZT = Z0 + 15.5                                # wall top (tall enough to see the bài vị under the eave)
K.WU0, K.WU1, K.WV0, K.WV1 = MU - H + 0.02, MU + H, MV - H + 0.02, MV + H   # Link 13:15: only the room is dim, the outer vách gets full daylight
K.ZW = ZT
K.INSIDE_K = 0.3                             # Link 14:07: every building lit like the đình (was)
K.FOOT = (0.08, 0.92, 0.08, 0.92, 0.08)
K.SHEET = 'mieu.webp'
K.SEED = 8100
K.WEATHER = True
K.PATCH = None
K.NOSHADOW = set()
K.GROUND_SHADOW = False
K.NORECV = {M_FLOOR, M_EARTHSIDE}   # Link 12:57: no shadow under the miếu                       # like the lò gạch: no baked ground shadow
K.RIDGE_R, K.BATTEN_R, K.POLE_R, K.TIE_R = 1.1, 0.4, 0.35, 0.2
OILL = (0.0, 0.14, Z0 + 10.0)   # đèn dầu hung just inside the door lintel: lights the room and throws the door's shape onto the ground in front
DW = 0.1                                    # half width of the doorway (tiles)                  # đèn dầu (local)
LON = (0.5, 0.8)                              # lon nhang on the mound in front
M_STICK, M_ASHT, M_ROCK = 150, 151, 152
MATS[M_STICK] = mat_flat('#a8321f'); MATS[M_ASHT] = mat_flat('#9a9088'); MATS[M_ROCK] = mat_flat('#7a746a')
M_TIMBERX = K.M_TIMBER


C45, S45 = 1.0, 0.0                           # Link 12:48: square to the grid like the old miếu (no 45° turn)


def wpt(u, v, z):
    """local (u, v around 0, tiles) -> world point"""
    x, y = u * T, v * T
    return np.array([x * C45 - y * S45 + MU * T, x * S45 + y * C45 + MV * T, z])


def turn(Sub):
    R = np.array([[C45, -S45, 0], [S45, C45, 0], [0, 0, 1.0]])
    for k in range(len(Sub.P)):
        Sub.P[k] = Sub.P[k] @ R.T + np.array([MU * T, MV * T, 0]); Sub.N[k] = Sub.N[k] @ R.T
    return Sub


def tslope2(S, rng, e, su, n_out, LB, ax, Lu, c0, c1, th=1.4, course=2.6):
    """dinh3d.tslope for a little roof: the leaves stop at the hip lines (no ragged tips sticking out sideways)"""
    def lo(b): return c0 * np.clip(b, 0, LB) / LB
    def hi(b): return Lu - c1 * np.clip(b, 0, LB) / LB
    def Fu(U, V):
        b = V * LB; x = lo(b) + U * (hi(b) - lo(b))
        return e[None, None] + ax[None, None] * x[..., None] + su[None, None] * b[..., None] - n_out[None, None] * th
    S.grid(Fu, 12, 10, K.M_THEND, (0, 0, 0), 0.0)
    nC = int(LB / course) + 2
    for i in range(nC):
        b0 = i * course * rng.uniform(0.96, 1.04) - 1.0
        bm = b0 + course * 1.0
        xl, xh = lo(bm), hi(bm)
        if xh - xl < 1.2: continue
        a = xl - 0.2
        while a < xh - 0.9:
            w = rng.uniform(1.0, 1.4); Lf = course * rng.uniform(1.9, 2.2); tip = b0 - rng.uniform(0.0, 0.6) - (0.6 if i == 0 else 0)
            tone = rng.integers(5); seed = rng.random(); lift = 1.1 + rng.uniform(-0.2, 0.2); sk = rng.uniform(-0.15, 0.15)
            tq = rng.uniform(0.62, 0.9)
            def F(U, V, aa=a, w=w, Lf=Lf, tip=tip, lift=lift, sk=sk, tq=tq):
                q = U / Lf
                width = w * 0.5 * np.where(q < tq, 1.0, np.clip((1 - q) / (1 - tq), 0, 1) ** 0.8)
                bb = np.minimum(tip + Lf * (1 - q), LB - 0.4)
                x = aa + w * 0.5 + V * width + sk * q
                nn = lift * q + 0.1 + 0.15 * (1 - V ** 2)
                return e[None, None] + ax[None, None] * x[..., None] + su[None, None] * bb[..., None] + n_out[None, None] * nn[..., None]
            S.grid(F, 6, 3, D.LEAFMAT[0], (tone, Lf, seed), 0.0, uvr=((0, Lf), (-1, 1)))
            a += w * rng.uniform(0.62, 0.8)


def pyramid(S, rng, E, EZ, AZ):
    """a little 4-sided lá roof (eaves square half size E tiles round local 0,0, apex at AZ): hip rolls + a tied lá knot on top"""
    X = np.array([1.0, 0, 0]); Y = np.array([0, 1.0, 0]); L = 2 * E * T
    for ev in (E, -E):
        e = W3(-E, ev, EZ); su, n, LB = D.face(e, W3(-E, 0, AZ), X)
        tslope2(S, rng, e, su, n, LB, X, L, E * T, E * T)
    for eu in (E, -E):
        e = W3(eu, -E, EZ)
        up = W3(0, -E, AZ) - W3(eu, -E, EZ); up[1] = 0; LB = np.linalg.norm(up); su = up / LB
        n = nv(np.cross(Y, su)); n = -n if n[2] < 0 else n
        tslope2(S, rng, e, su, n, LB, Y, L, E * T, E * T)
    top = W3(0, 0, AZ + 0.6)
    for (cu, cv) in ((E, E), (E, -E), (-E, E), (-E, -E)):
        p_e = W3(cu, cv, EZ + 0.4)
        D.roll(S, rng, top, p_e + (top - p_e) * 0.03, R=0.55, tie=False)
    lathe(S, top - np.array([0, 0, 0.8]), [(0, 1.6), (1.2, 1.4), (2.4, 0.7), (3.4, 0.0)], K.M_THEND, na=16)
    for z in (0.2, 1.3):
        lathe(S, top + np.array([0, 0, z - 0.8]), [(0, 1.62 - z * 0.45), (0.35, 1.66 - z * 0.45), (0.7, 1.6 - z * 0.45)], M_RATTANX, na=16)


def minilamp(S, c):
    """a small đèn dầu (the đình's, 60%)"""
    b = c - np.array([0, 0, 2.6])
    lathe(S, b, [(0, 0.8), (0.25, 0.9), (0.85, 1.0), (1.45, 0.6), (1.6, 0.35)], K.M_LAMPGLASS, na=14)
    lathe(S, b + np.array([0, 0, 1.55]), [(0, 0.45), (0.45, 0.45), (0.5, 0.3)], M_TIN, na=10)
    ell(S, c, 0.2, 0.2, 0.5, K.M_FLAME, nu=6, nvv=8)


def shrine(S, rng):
    u, v, h = 0.0, 0.0, H
    # one tràm trunk (Link 12:48: "gỗ tràm như làm công trình", like every building's posts) on a stone, 4 tràm braces
    # and 2 tràm cross beams under the floor; thin tre corner posts only from the floor up carry the vách and the roof
    X3.ellipsoid(S, W3(u, v, ZF - 0.2), 3.6, 3.6, 1.6, M_ROCK, nu=6, nvv=14)
    tube(S, W3(u, v, ZF - 0.5), W3(u, v, Z0 - 1.0), 1.75, M_BARK, prm=(0.3, 0, 0), nr=12, nl=10, taper=0.88)
    for (du, dv) in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        a = W3(u, v, Z0 - 5.0) + np.array([du * 1.4, dv * 1.4, 0]); b = W3(u + du * (h - 0.04), v + dv * (h - 0.04), Z0 - 2.4)
        tube(S, a, b, 0.65, M_BARK, prm=(0.6, 0, 0), nr=8, nl=3)
    tube(S, W3(u - h, v, Z0 - 1.8), W3(u + h, v, Z0 - 1.8), 0.85, M_BARK, prm=(0.1, 0, 0), nr=8, nl=6)
    tube(S, W3(u, v - h, Z0 - 1.8), W3(u, v + h, Z0 - 1.8), 0.85, M_BARK, prm=(0.4, 0, 0), nr=8, nl=6)
    for (du, dv) in ((-h, -h), (h, -h), (-h, h), (h, h)):
        bam(S, rng, W3(u + du, v + dv, Z0 - 0.5), W3(u + du, v + dv, ZT + 0.6), 0.6, nl=6, mat=M_OLDBAMBOO)
    box(S, W3(u - h - 0.03, v - h - 0.03, Z0 - 1.0), W3(u + h + 0.03, v + h + 0.04, Z0), M_PLANK)
    # sàn trước cửa (Link 13:14): the door light falls on this upper floor, not on the earth below
    box(S, W3(u - h - 0.03, v + h + 0.04, Z0 - 1.0), W3(u + h + 0.03, v + h + 0.15, Z0), M_PLANK)
    tube(S, W3(u - h - 0.03, v + h + 0.15, Z0 - 1.6), W3(u + h + 0.03, v + h + 0.15, Z0 - 1.6), 0.8, M_BARK, prm=(0.7, 0, 0), nr=8, nl=6)
    for du in (-0.1, 0.1):
        tube(S, W3(u, v, Z0 - 6.0) + np.array([du * T * 0.1, 1.2, 0]), W3(u + du, v + h + 0.13, Z0 - 2.0), 0.6, M_BARK, prm=(0.8 + du, 0, 0), nr=8, nl=3)
    # vách on 4 sides like the old miếu, a doorway in the front (+v) wall with a red cloth over it
    wall_u(S, u - h, u + h, Z0, ZT, v - h)
    wall_v(S, v - h, v + h, Z0, ZT, u - h); wall_v(S, v - h, v + h, Z0, ZT, u + h)
    wall_u(S, u - h, u - DW, Z0, ZT, v + h); wall_u(S, u + DW, u + h, Z0, ZT, v + h); wall_u(S, u - DW, u + DW, ZT - 4.0, ZT, v + h)
    for du in (-DW, DW):
        tube(S, W3(u + du, v + h + 0.01, Z0), W3(u + du, v + h + 0.01, ZT - 4.0), 0.45, M_OLDBAMBOO, nr=6, nl=4)
    tube(S, W3(u - DW - 0.02, v + h + 0.01, ZT - 4.0), W3(u + DW + 0.02, v + h + 0.01, ZT - 4.0), 0.45, M_OLDBAMBOO, nr=6, nl=4)
    tube(S, W3(u - h, v + h, ZT - 0.3), W3(u + h, v + h, ZT - 0.3), 0.55, M_OLDBAMBOO, nr=6, nl=6)
    # the view through the doorway runs to the left (-u) wall, so the bài vị hangs there facing the door line,
    # lư hương on that line, đèn dầu + dĩa trái cây beside it: all of it shows through the door
    box(S, W3(u - h + 0.01, v - 0.075, Z0), W3(u - h + 0.035, v + 0.075, Z0 + 10.0), M_CLOTH)
    box(S, W3(u - h + 0.036, v - 0.055, Z0 + 1.4), W3(u - h + 0.04, v + 0.055, Z0 + 8.6), M_GOLD)
    c = W3(u - 0.1, v + 0.1, Z0)
    lathe(S, c, [(0, 1.0), (0.4, 1.3), (1.4, 1.45), (1.8, 1.3)], M_INCENSE, na=14)
    for k in range(3):
        pp = c + np.array([(k - 1) * 0.4, 0, 1.6])
        tube(S, pp, pp + np.array([(k - 1) * 0.25, 0, 4.0]), 0.12, M_STICK, nr=3, nl=2)
    minilamp(S, W3(*OILL))
    tube(S, W3(*OILL) + np.array([0, 0, -1.0]), W3(OILL[0], OILL[1], ZT + 2.0), 0.1, M_STICK, nr=3, nl=3)   # the hanging cord
    c = W3(u - 0.15, v + 0.11, Z0)
    disc(S, c + np.array([0, 0, 0.3]), (0, 0, 1), 1.9, M_TIN, nr=2, na=16, dome=0.1)
    for k, (dx, dy, mm) in enumerate(((-0.6, 0.0, M_ORANGE), (0.7, 0.2, M_ORANGE), (0.0, 0.5, M_REDFRUIT), (0.1, -0.1, M_ORANGE))):
        ell(S, c + np.array([dx, dy, 1.3 + (0.9 if k == 3 else 0)]), 0.9, 0.9, 0.85, mm, nu=6, nvv=8)
    # hip lá roof + a red cloth strip on the front eave
    e = h + 0.04
    pyramid(S, rng, e, ZT + 0.6, ZT + 11.0)
    plane(S, W3(u - h + 0.01, v + h + 0.012, ZT - 0.4), W3(u + h - 0.01, 0, 0) - W3(u - h + 0.01, 0, 0), np.array([0, 0, -2.6]), 8, 3, M_CLOTH)
    # lư đất with 3 nhang (glowing tips) on the sàn in front of the door
    c = W3(0.0, h + 0.09, Z0)   # on the sàn, centred in front of the door (Link 13:22), where people light incense
    lathe(S, c, [(0, 1.2), (0.8, 1.9), (2.0, 2.1), (2.8, 1.7), (3.1, 1.9)], M_POT, na=16)
    disc(S, c + np.array([0, 0, 2.7]), (0, 0, 1), 1.75, M_ASHT, nr=2, na=14)
    for k in range(3):
        pp = c + np.array([(k - 1) * 0.5, 0, 2.7]); tp = pp + np.array([(k - 1) * 0.6, -0.2, 7.5 + (k == 1) * 1.2])
        tube(S, pp, tp, 0.16, M_STICK, nr=3, nl=2)
        ell(S, tp, 0.3, 0.3, 0.4, M_EMBER, nu=4, nvv=6)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear()
    oil = wpt(*OILL[:2], OILL[2])
    DOOR = ((MV + H) * T, (MU - DW) * T, (MU + DW) * T, Z0, ZT - 4.0)
    K.LIGHTS2.append((oil, hexc('#ff9645'), 16.0, 3.2, ('box', (MU - H) * T + 0.6, (MU + H) * T - 0.6, (MV - H) * T + 0.6, (MV + H) * T - 0.6, Z0 - 0.5, ZT, DOOR)))
    K.GLOWS[:] = []   # the lamp hangs inside the lintel: no halo over the roof
    # Link 13:03 "hắt ra nền trước cửa như nhà tranh": the lamp lights the room, and outside only through the door
    # (same logic as the nhà tranh), so the door's shape is thrown onto the ground in front
    K.GROUND_GLOW[:] = []
    K.GROUND_SPILL[:] = []   # Link 13:14: nothing on the earth below
    rrect_top(S, 0.08, 0.92, 0.08, 0.92, 0.16, ZF, M_FLOOR)
    extrude(S, rrect(0.08, 0.92, 0.08, 0.92, 0.16), 0.0, ZF, M_EARTHSIDE, flare=0.8)
    Sm = Scene(); shrine(Sm, rng)
    merge_all(S, turn(Sm))
    return S, (S.ns, S.ns)


K.build = build

if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        n = len(sys.argv) > 3 and sys.argv[3] == 'n'
        K.render(1, n, 'b').save(sys.argv[2])
    elif sys.argv[1] == 'atlas':
        out, tab = sys.argv[2], sys.argv[3]
        G = {}; frames = {}
        for n in (0, 1):
            im = K.render(1, bool(n), 'b'); bb = im.getbbox(); frames['b' + ('n' if n else 'd')] = (im.crop(bb), bb)
        keys = ['bd', 'bn']; x = 0; sc = float(K.PXU); Hh = max(f[0].height for f in frames.values()); BB = K.BB
        sheet = Image.new('RGBA', (sum(frames[k][0].width + 2 for k in keys), Hh), (0, 0, 0, 0))
        for k in keys:
            im, bb = frames[k]; sheet.paste(im, (x, 0))
            G[k] = [x, 0, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
            x += im.width + 2
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, K.SHEET), 'WEBP', quality=92, method=6); json.dump(G, open(tab, 'w'))
        print('sheet', sheet.size)
