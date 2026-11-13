# Giếng làng (game id well 1x1) as a real 3D model in the kho kit, same family as the lò gạch / miếu (Link 2026-11-09
# "giờ tới công trình con đi", đợt 1). Sơ cấp, miền Tây:
#  - sơ cấp (Link 17:19: no brick, that is for cấp 2/3): a giếng đất, thành = a ring of tràm stakes bound with two tre
#    hoops, earth heaped round its foot; dark water deep inside
#  - a cần vọt: a forked tràm post, a long tre pole on it with a stone counterweight tied at the back end, a rope and a
#    wooden gàu hanging over the mouth (the same spot as the old drawing: post left-front, pole over the well)
#  - no pad, no lu (Link 17:29); the gàu hangs full of water
#   python3 gieng3d.py prev OUT.png [n]        python3 gieng3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'kho'))
import kho3d as K
from kho3d import (W3, T, nv, UP, Scene, X3, hexc, smooth, vnoise, hash1, plane, tube, disc, lathe, extrude, rrect, rrect_top,
                   box, mat_flat, MATS, GLOSS, M_EARTHSIDE, M_OLDBAMBOO, M_RATTAN, M_FLOOR, M_WOOD, M_BARK, M_WATER, M_GLAZE,
                   M_COCO, M_PLANK, M_STONE, M_BAMBOO)

K.BB = (-60, -96, 48, 30)
K.OX, K.OY = 0, -16                          # at.P(1,1)
ZF = 0.0                                     # Link 17:29: no earth pad, the well stands on the ground
K.ZF = ZF
K.WU0, K.WU1, K.WV0, K.WV1 = -9, -9, -9, -9   # nothing is under a roof
K.FOOT = (0.06, 0.94, 0.06, 0.94, 0.08)
K.SHEET = 'gieng.webp'
K.SEED = 9100
K.GROUND_SHADOW = False
K.NOSHADOW = set()
GC = (0.5, 0.5)                              # well centre
RO, RI, ZR = 12.0, 9.6, ZF + 9.5             # thành: stake ring radius / inner earth wall, stake tops
PIV = (0.17, 0.83, 40.0)                     # cần vọt pivot on the forked post
TIP = (0.64, 0.36, 50.0)                     # the long end, past the well
ROPE = 0.51                                  # the rope hangs from the pole at this u (over the water)


def mat_mound(uv, prm, pos, nrm):
    """đất đắp quanh thành giếng: packed earth, a little darker and damp at the foot"""
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    base = hexc('#9a7a54')[None] * (0.9 + 0.1 * vnoise(x * 0.8, y * 0.8, 3.0) + 0.05 * vnoise(x * 3, y * 3, 6.0))[:, None]
    damp = 1 - smooth(ZF, ZF + 2.0, z)
    base = base * (1 - 0.18 * damp)[:, None]
    return np.clip(base, 0, 1), nrm


def mat_inner(uv, prm, pos, nrm):
    """the earth wall inside: dark and wet low down, green slime near the water, roots"""
    z = pos[:, 2]; a = uv[:, 1]
    # Link 2026-11-10: the far side inside must be lit, not black; no slime/moss
    k = smooth(ZF + 0.5, ZR + 1.0, z) ** 1.2
    base = hexc('#6a5442')[None] * (1 - k[:, None]) + hexc('#9a7c5e')[None] * k[:, None]
    wet = 1 - smooth(ZF + 0.5, ZF + 3.0, z)                                          # just a damp band at the water
    base = base * (1 - 0.25 * wet)[:, None]
    return np.clip(base * (0.88 + 0.16 * vnoise(a * 2, z, 3.0))[:, None], 0, 1), nrm


def mat_stake(uv, prm, pos, nrm):
    """old tràm stake: bark gone grey, a little darker and damp at the foot (no moss: Link 2026-11-10)"""
    col, n = MATS[M_BARK](uv, prm, pos, nrm)
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    col = col * 0.75 + hexc('#6e6658')[None] * 0.25                                 # weathered grey
    damp = 1 - smooth(ZF, ZF + 3.5, z + 1.5 * vnoise(x * 0.5, y * 0.5, 2.0))
    col = col * (1 - 0.3 * damp)[:, None]
    return np.clip(col, 0, 1), n


def mat_stop(uv, prm, pos, nrm):
    """stake tops: cut long ago, grey and cracked"""
    x, y = pos[:, 0], pos[:, 1]
    base = hexc('#7a7062')[None] * (0.8 + 0.25 * vnoise(x * 3, y * 3, 4.0))[:, None]
    crack = vnoise(x * 6, y * 6, 8.0) > 0.78
    return np.clip(np.where(crack[:, None], base * 0.55, base), 0, 1), nrm


def mat_deep(uv, prm, pos, nrm):
    r = uv[:, 0]; th = uv[:, 1] * 2 * math.pi
    # Link 2026-11-10: the river's own water colour (song.js cols(): mid #6e937c, deep toward #2a4a38), darker at the rim
    base = hexc('#547e72')[None] * (1 - 0.3 * smooth(0.55, 1.0, r))[:, None]
    gl = np.exp(-(((r - 0.5) / 0.28) ** 2 + ((th - 3.9) / 0.8) ** 2)) * 0.2      # the sky in the water, far side
    base = base + hexc('#dcebe0')[None] * gl[:, None] * 0.5
    return np.clip(base, 0, 1), nrm


def mat_rock(uv, prm, pos, nrm):
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    base = hexc('#5c574f')[None] * (0.75 + 0.35 * vnoise(x * 1.4, y * 1.4 + z, 4.0))[:, None]
    return np.clip(base, 0, 1), nrm


M_MOUND, M_INNER, M_ROCK, M_GAU, M_DEEP, M_STAKE, M_STOP, M_POLE = range(160, 168)


def mat_pole(uv, prm, pos, nrm):
    """cần vọt: the house-post tre, but old and sun-bleached: greyer and darker"""
    col, n = MATS[M_BAMBOO](uv, prm, pos, nrm)
    g = col.mean(axis=1, keepdims=True)
    col = (col * 0.55 + g * 0.45) * 0.7 + hexc('#5e5a50')[None] * 0.08
    return np.clip(col, 0, 1), n
MATS.update({M_POLE: mat_pole, M_STAKE: mat_stake, M_STOP: mat_stop, M_DEEP: mat_deep, M_MOUND: mat_mound, M_INNER: mat_inner, M_ROCK: mat_rock, M_GAU: mat_flat('#6e4a2c')})


def lathe2(S, c, prof, mat, prm=(0, 0, 0), na=40, flip=True):
    zs = np.array([p[0] for p in prof], float); rs = np.array([p[1] for p in prof], float); c = np.asarray(c, float)
    sl = np.concatenate([[0], np.cumsum(np.hypot(np.diff(zs), np.diff(rs)))]); C = 2 * math.pi * rs.max()
    def F(U, V):
        z = np.interp(U, sl, zs); r = np.interp(U, sl, rs); th = V / C * 2 * math.pi
        return np.stack([c[0] + r * np.cos(th), c[1] + r * np.sin(th), c[2] + z], -1)
    S.grid(F, max(len(prof) * 3, int(sl[-1] / 0.7) + 2), na, mat, prm, 0.0, uvr=((0, sl[-1]), (0, C)), close_v=True, flip=flip)


def bam(S, rng, a, b, r, nl=6, mat=M_OLDBAMBOO):
    tube(S, a, b, r, mat, prm=(rng.random(), rng.random(), 0), nr=8, nl=nl)


def arc(S, c, R, z, a0, a1, r, mat, n=24, prm=(0.4, 0.5, 0)):
    """a tre hoop piece: tube segments along a circle from angle a0 to a1"""
    for k in range(n):
        t0 = a0 + (a1 - a0) * k / n; t1 = a0 + (a1 - a0) * (k + 1) / n
        p0 = c + np.array([R * math.cos(t0), R * math.sin(t0), z]); p1 = c + np.array([R * math.cos(t1), R * math.sin(t1), z])
        tube(S, p0, p1, r, mat, prm=prm, nr=6, nl=2)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear(); K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
    c0 = W3(GC[0], GC[1], ZF)
    # a low collar of trodden earth only at the foot of the stakes (no pad: Link 17:29)
    lathe2(S, c0, [(-0.2, RO + 0.9), (0.0, RO + 0.8), (0.6, RO + 0.3), (0.9, RO - 0.4)], M_MOUND, na=56)
    # thành: a ring of old tràm stakes, a few leaning, two broken short, one gone; two tre hoops, the upper one snapped
    N = 30; miss = 22
    for k in range(N):
        if k == miss: continue
        th = 2 * math.pi * (k + 0.3 * rng.random()) / N
        r = RO - 0.9 + 0.2 * rng.random(); zt = ZR - 0.6 + 1.2 * rng.random()
        if k in (7, 16): zt = ZR - 4.5 - 1.5 * rng.random()                              # rotted off
        lean = 0.5 * (rng.random() - 0.5) + (0.9 if k in (3, 25) else 0.0)
        q = c0 + np.array([r * math.cos(th), r * math.sin(th), 0.0])
        top = np.array([q[0] + lean * math.cos(th), q[1] + lean * math.sin(th), zt])
        tube(S, q + np.array([0, 0, 0.6]), top, 0.95 + 0.15 * rng.random(), M_STAKE, prm=(rng.random(), 0, 0), nr=7, nl=5)
        disc(S, top, (0, 0, 1), 0.9, M_STOP, nr=2, na=8)
    zl, zu = ZF + 3.6, ZR - 1.8
    arc(S, c0, RO + 0.3, zl, 0, 2 * math.pi, 0.42, M_OLDBAMBOO, n=40)
    arc(S, c0, RO + 0.3, zu, 1.15, 1.15 + 2 * math.pi - 1.0, 0.42, M_OLDBAMBOO, n=36)    # snapped: a gap at the front-left
    e = c0 + np.array([(RO + 0.3) * math.cos(1.15), (RO + 0.3) * math.sin(1.15), zu])
    tube(S, e, e + np.array([1.2, -2.0, -2.6]), 0.4, M_OLDBAMBOO, prm=(0.3, 0.5, 0), nr=6, nl=3)   # broken end hanging down
    for zh in (zl, zu):
        for k in range(8):
            th = 2 * math.pi * (k + 0.5) / 8
            if zh == zu and 1.15 - 1.0 + 2 * math.pi - 2 * math.pi < th < 1.15: continue
            q = c0 + np.array([(RO + 0.6) * math.cos(th), (RO + 0.6) * math.sin(th), zh])
            X3.ellipsoid(S, q, 0.4, 0.4, 0.75, M_RATTAN, nu=4, nvv=6)
    lathe2(S, c0, [(ZR - ZF - 1.0, RO - 1.7), (0.4, RI)], M_INNER, na=48, flip=False)
    disc(S, c0 + np.array([0, 0, 0.6]), (0, 0, 1), RI - 0.2, M_DEEP, nr=4, na=36)       # deep water: dark, a sky glint
    # cần vọt: a forked tràm post, a tre pole like the house posts, a real stone tied in a rope cradle, rope + gàu with water
    p = W3(PIV[0], PIV[1], ZF - 0.5)
    pv = W3(*PIV); tp = W3(*TIP); dirn = tp - pv
    fork = W3(PIV[0], PIV[1], PIV[2] - 3.4)                    # the crotch, just under the pole
    tube(S, p, fork, 1.5, M_STAKE, prm=(0.2, 0, 0), nr=10, nl=10, taper=0.85)
    perp = nv(np.cross(nv(dirn), UP)); along = nv(np.array([dirn[0], dirn[1], 0.0]))
    side = nv(perp * math.cos(0.7) + along * math.sin(0.7))   # V opens across the pole, turned 40° so the camera sees both prongs
    for sg in (1, -1):
        top = fork + side * sg * 3.8 / math.cos(0.7) + np.array([0, 0, 6.0])
        tube(S, fork + np.array([0, 0, -0.6]), top, 1.05, M_STAKE, prm=(0.2, 0, 0), nr=8, nl=6, taper=0.75)
        disc(S, top, nv(top - fork), 0.8, M_STOP, nr=2, na=10)
    back = pv - dirn * 0.55
    tube(S, back, tp, 1.25, M_POLE, prm=(0.4, 0.3, 0), nr=10, nl=30, taper=0.75)         # house-post tre, aged grey
    tube(S, pv - side * 5.6 + np.array([0, 0, 0.4]), pv + side * 5.6 + np.array([0, 0, 0.4]), 0.32, M_WOOD, nr=6, nl=2)   # peg through both prongs
    st = back + np.array([0, 0, -4.2])                         # counterweight: a rough stone in a rope cradle
    X3.ellipsoid(S, st, 3.2, 2.5, 2.2, M_ROCK, nu=8, nvv=12)
    X3.ellipsoid(S, st + np.array([0.9, -0.6, 0.9]), 2.0, 1.8, 1.6, M_ROCK, nu=6, nvv=10)
    X3.ellipsoid(S, st + np.array([-1.0, 0.7, -0.4]), 1.8, 1.6, 1.5, M_ROCK, nu=6, nvv=10)
    for k in range(4):
        th = math.pi / 4 + k * math.pi / 2
        lo = st + np.array([2.9 * math.cos(th), 2.4 * math.sin(th), -1.4])
        tube(S, back + nv(dirn) * 0.6 * (1 if k % 2 else -1), lo + np.array([0, 0, 2.6]), 0.24, M_RATTAN, nr=4, nl=2)
        tube(S, lo + np.array([0, 0, 2.6]), lo, 0.24, M_RATTAN, nr=4, nl=2)
    lathe(S, st + np.array([0, 0, -0.6]), [(0, 3.3), (0.35, 3.35)], M_RATTAN, na=20)
    t = (ROPE - PIV[0]) / (TIP[0] - PIV[0]); rp = pv + dirn * t
    gz = ZR + 7.5
    tube(S, rp, np.array([rp[0], rp[1], gz + 3.8]), 0.22, M_RATTAN, nr=4, nl=4)
    gc = np.array([rp[0], rp[1], gz])
    lathe(S, gc, [(0, 1.7), (0.3, 2.0), (3.4, 2.4), (3.6, 2.5)], M_GAU, na=18)
    disc(S, gc + np.array([0, 0, 2.9]), (0, 0, 1), 2.2, M_WATER, nr=3, na=18)            # the gàu is full
    for k in (0.8, 2.6):
        lathe(S, gc + np.array([0, 0, k]), [(0, 2.08 + k * 0.12), (0.4, 2.12 + k * 0.12)], M_RATTAN, na=18)
    tube(S, gc + np.array([-2.4, 0, 3.4]), gc + np.array([0, 0, 3.8 + 1.8]), 0.18, M_RATTAN, nr=4, nl=2)
    tube(S, gc + np.array([2.4, 0, 3.4]), gc + np.array([0, 0, 3.8 + 1.8]), 0.18, M_RATTAN, nr=4, nl=2)
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
