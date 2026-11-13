# Nông Trại Chung: Cổng làng (game id gate 3x1 on a road, mirror gate2, one level) as a real 3D model (kho kit, đình roof kit).
# Link 2026-11-09 05:36 "tiếp đến cổng làng"; sơ cấp = tre + lá, simple (Link 03:58).
#  - two tre posts, each a bundle of 3 tre gai buried in an earth mound and lashed with mây
#  - a double tre beam on top, chống chéo braces, a short hip lá roof with curled ends and a ridge roll
#  - a dark plank board hung under the lower beam (the game paints LÀNG on it), two đèn bão that light up at night
#  - bông giấy climbing the left post up onto the beam
#   python3 cong3d.py prev OUT.png [n]        python3 cong3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'dinh'))
import dinh3d as D
from dinh3d import (K, W3, T, nv, UP, Scene, hexc, vnoise, tube, disc, lathe, box, mat_flat, MATS,
                    M_BAMBOO, M_RATTAN, M_OLDBAMBOO, M_EARTHSIDE, M_SOOT, M_STONE, bam, ell, hiproof, biglamp)

K.OX, K.OY = -32, -32                        # at.P(3,1)
K.BB = (-96, -122, 96, 52)
ZF = 0.0
PU = (0.28, 2.72); PV = 0.5                  # post bundles
BZ0, BZ1 = 54.0, 58.0                        # tie beam (đà) and the twin top beams
E, EZ = (0.08, 2.92, 0.27, 0.73), 62.0       # roof eaves box: a slim cap over the posts, not a shed roof (critique 1, 10)
R = (0.8, 2.2, 0.5, 77.0)                    # ridge
SG = (0.98, 2.02, 0.53, 0.56, 34.5, 46.0)    # sign board u0,u1,v0,v1,z0,z1 (game text at (1.5, .575, 40.25)); Link 06:02: midway, cords showing; clear of the eave
LAMPS = ((0.8, 0.5, 41.0), (2.2, 0.5, 41.0))   # clear of the posts (critique 6, 7)
K.ZW, K.ZF = 58.0, ZF
K.RZ, K.EZ = R[3], EZ
K.WU0, K.WU1, K.WV0, K.WV1 = -9.0, -8.9, -9.0, -8.9     # no inside
K.FOOT = (-60.0, -59.9, -60.0, -59.9, 0.01)            # it stands on the road: no pad shade
K.SHEET = 'cong.webp'
K.SEED = 7600
K.RIDGE_R, K.BATTEN_R, K.POLE_R, K.TIE_R = 1.25, 0.45, 0.38, 0.17
K.GROUND_SHADOW = False                      # no baked ground shadow: the game casts real sun shadows later (critique 10)
K.GROUND_GLOW[:] = [(0.8, 0.5, 34.0, 0.45), (2.2, 0.5, 34.0, 0.45)]   # night: lamp light on the road (critique 11)
K.NIGHT_EMIT.clear()

M_SIGNB, M_BGLEAF, M_BGLEAF2, M_BGFLOWER, M_BGFLOWER2, M_LEAF_G, M_RIDGE_G = 240, 241, 242, 243, 244, 245, 246


def mat_signb(uv, prm, pos, nrm):
    """3 sawn planks of old sao wood, stained dark, with grain, knots and worn lighter edges (cream words painted by the game)"""
    a, b = pos[:, 0], pos[:, 2]
    k = (b - SG[4]) / ((SG[5] - SG[4]) / 3); pl = np.floor(k); f = k - pl
    g = (0.82 + 0.1 * vnoise(a * 0.35 + pl * 7, f * 3, 2.0) + 0.09 * np.sin(a * 0.9 + 6 * vnoise(a * 0.08, f + pl * 3, 5.0))
         + 0.05 * vnoise(a * 2.5, f * 8 + pl, 9.0))
    knot = np.exp(-((a - (12 + pl * 9) % 30 - 3) ** 2 + ((f - 0.5) * 3.7) ** 2) / 1.2)
    g = g * (1 - 0.35 * knot)
    edge = np.clip(1 - np.minimum(f, 1 - f) / 0.12, 0, 1)
    base = hexc('#5e3c22')[None] * g[:, None] + hexc('#8a6440')[None] * (0.35 * edge)[:, None]
    gap = np.minimum(f, 1 - f) < 0.035
    base = np.where(gap[:, None], hexc('#2a180b')[None], base)
    return np.clip(base, 0, 1), nrm


def mat_leaf_g(uv, prm, pos, nrm):
    """the gate's lá: a few seasons old, sun-bleached on top, greyed and loang in patches (not the võ ca's fresh yellow)"""
    col, n = K.mat_leaf(uv, prm, pos, nrm)
    w = vnoise(pos[:, 0] * 0.07, pos[:, 1] * 0.07 + pos[:, 2] * 0.05, 31.0)
    old = np.clip((w - 0.45) * 3.0, 0, 1)[:, None]
    c = col * 0.72 + hexc('#9a8458')[None] * 0.2
    c = c * (1 - 0.3 * old) + hexc('#6f6248')[None] * 0.22 * old
    return np.clip(c, 0, 1), n


def mat_ridge_g(uv, prm, pos, nrm):
    col, n = MATS[D.M_RIDGE](uv, prm, pos, nrm)
    return np.clip(col * 0.7 + hexc('#8a7550')[None] * 0.2, 0, 1), n


MATS.update({M_SIGNB: mat_signb, M_BGLEAF: mat_flat('#2e4f21'), M_BGLEAF2: mat_flat('#3d6228'),
             M_BGFLOWER: mat_flat('#b01f5c'), M_BGFLOWER2: mat_flat('#cf3678'), M_LEAF_G: mat_leaf_g, M_RIDGE_G: mat_ridge_g})


def lash(S, c, r, n=9):
    """a mây lashing round a post bundle at c"""
    for dz in (0.0, 0.5, 1.0):
        pts = [c + np.array([math.cos(a) * r, math.sin(a) * r, dz + 0.25 * math.sin(a)]) for a in np.linspace(0, 2 * math.pi, 13)]
        for i in range(12): tube(S, pts[i], pts[i + 1], K.TIE_R, M_RATTAN, nr=4, nl=2)


def postbundle(S, rng, u):
    """3 tre gai of different ages: one thick, one thinner, one old grey; slightly out of plumb (critique 4)"""
    c = W3(u, PV, ZF)
    offs = ((-1.6, -1.2, 1.6, M_BAMBOO), (1.5, -1.4, 1.25, M_BAMBOO), (0.1, 1.6, 1.15, M_OLDBAMBOO))
    for k, (dx, dy, r, mt) in enumerate(offs):
        top = BZ1 + 1.0 + rng.uniform(0.0, 3.0) + (1.5 if k == 2 else 0)
        lean = rng.normal(0, 0.25, 2)
        q = c + np.array([dx * 0.9 + lean[0], dy * 0.9 + lean[1], top])
        tube(S, c + np.array([dx, dy, -1.0]), q, r, mt, prm=(rng.random(), rng.random(), 0), nr=10, nl=16, taper=0.9)
        disc(S, q, (0, 0, 1), r * 0.85, M_OLDBAMBOO, nr=2, na=12)
    for z in (11.0, BZ0 - 5.0):
        lash(S, c + np.array([0, 0, z]), 3.3)
    for (dx, dy, rx, ry, rz) in ((0, 0, 5.2, 4.6, 2.0), (2.2, 1.4, 3.4, 2.8, 1.5), (-2.4, 1.0, 3.0, 2.6, 1.3), (0.8, -2.6, 3.2, 2.4, 1.2)):
        ell(S, c + np.array([dx, dy, 0.1]), rx * rng.uniform(0.9, 1.1), ry * rng.uniform(0.9, 1.1), rz, K.M_MOUND, nu=10, nvv=12)   # lumpy đất đắp (critique 8)
    for k in range(3):
        a = rng.uniform(0, 2 * math.pi); rr = rng.uniform(4.5, 6.0)
        ell(S, c + np.array([math.cos(a) * rr, math.sin(a) * rr, 0.4]), rng.uniform(0.9, 1.4), rng.uniform(0.7, 1.1), 0.7, D.M_TANG, nu=6, nvv=8)
    for k in range(16):                                                             # a few cỏ blades round the mound
        a = rng.uniform(0, 2 * math.pi); rr = rng.uniform(4.5, 7.0)
        b = c + np.array([math.cos(a) * rr, math.sin(a) * rr, 0.0]); d = nv(np.array([rng.normal(0, 0.35), rng.normal(0, 0.35), 1.0]))
        tube(S, b, b + d * rng.uniform(2.0, 3.4), 0.22, M_BGLEAF2 if k % 2 else M_BGLEAF, nr=3, nl=2, taper=0.2)


def beams(S, rng):
    u0, u1 = 0.02, 2.98
    for v in (0.38, 0.62):                                                          # twin top beams under the eaves
        bam(S, rng, W3(u0, v, BZ1), W3(u1, v, BZ1 + 0.3), 1.25, nl=20)
    bam(S, rng, W3(PU[0] - 0.08, PV, BZ0), W3(PU[1] + 0.08, PV, BZ0 - 0.2), 1.15, nl=20)  # tie beam (đà)
    for u in PU:                                                                    # lashed cross joints
        for v in (0.38, 0.62):
            c = W3(u, v, BZ1)
            for dz in (-0.6, 0.6):
                tube(S, c + np.array([-2.0, 0, dz]), c + np.array([2.0, 0, dz]), K.TIE_R, M_RATTAN, nr=5, nl=2)
    for (u, s) in ((PU[0], 1), (PU[1], -1)):                                        # chống chéo
        a = W3(u + s * 0.07, PV, 34.0); b = W3(u + s * 0.42, PV, BZ0 - 0.6)
        bam(S, rng, a, b, 0.75, nl=8)
    for u in np.linspace(0.12, 2.88, 9):                                            # rafters peeking out at the beam ends
        bam(S, rng, W3(u, 0.2, EZ + 1.2), W3(u, 0.8, EZ + 1.2), 0.45, nl=4, mat=M_OLDBAMBOO)


def sign(S, rng):
    u0, u1, v0, v1, z0, z1 = SG
    box(S, W3(u0, v0, z0), W3(u1, v1, z1), M_SIGNB)
    for (a, b) in ((W3(u0, v1 + 0.004, z0), W3(u1, v1 + 0.004, z0)), (W3(u0, v1 + 0.004, z1), W3(u1, v1 + 0.004, z1)),
                   (W3(u0, v1 + 0.004, z0), W3(u0, v1 + 0.004, z1)), (W3(u1, v1 + 0.004, z0), W3(u1, v1 + 0.004, z1))):
        tube(S, a, b, 0.75, M_BAMBOO, prm=(rng.random(), 0.3, 0), nr=8, nl=4)
    for u in (u0 + 0.12, u1 - 0.12):                                                # hung from the đà on mây cords
        tube(S, W3(u, PV + 0.04, BZ0 - 1.0), W3(u, (v0 + v1) / 2, z1 + 0.2), 0.22, M_RATTAN, nr=4, nl=3)


def lamp135(S, c, k=1.35):
    """dinh3d.biglamp at k times the size"""
    lb = c - np.array([0, 0, 2.6 * k])
    lathe(S, lb, [(0, 1.5 * k), (0.3 * k, 1.7 * k), (1.2 * k, 1.6 * k), (1.5 * k, 0.9 * k)], M_SOOT)
    lathe(S, lb + np.array([0, 0, 1.5 * k]), [(0, 0.9 * k), (0.8 * k, 1.35 * k), (2.0 * k, 1.45 * k), (3.2 * k, 1.2 * k), (3.9 * k, 0.8 * k)], K.M_LAMPGLASS)
    lathe(S, lb + np.array([0, 0, 5.3 * k]), [(0, 1.2 * k), (0.6 * k, 1.25 * k), (1.2 * k, 0.6 * k), (1.8 * k, 0.3 * k)], M_SOOT)
    for sg in (-1, 1):
        tube(S, lb + np.array([1.55 * k * sg, 0, 0.6 * k]), lb + np.array([1.2 * k * sg, 0, 6.6 * k]), 0.2, M_SOOT, nr=4, nl=2)
    ell(S, c, 0.45, 0.45, 1.05, K.M_FLAME, nu=6, nvv=8)


def lamps(S):
    """bigger đèn bão (1.35x) on a hook under the đà"""
    for p in LAMPS:
        c = W3(*p)
        tube(S, W3(p[0], p[1], BZ0 - 1.0), c + np.array([0, 0, 5.6]), 0.2, M_SOOT, nr=4, nl=2)
        lamp135(S, c)


def bonggiay(S, rng, pu, sd):
    """bông giấy: a bush at the left post's foot, climbing in a thick rope and spilling off the đà (critique 5)"""
    c = W3(pu, PV, ZF)
    pts = []
    for k in range(64):                                                             # up the post
        z = 3.0 + k * 0.82; a = k * 0.5 + rng.normal(0, 0.2)
        pts.append(c + np.array([math.cos(a) * 3.5, math.sin(a) * 3.3, z]))
    for k in range(len(pts) - 1): tube(S, pts[k], pts[k + 1], 0.38, K.M_BARK, nr=4, nl=2)
    def tuft(q, n, rf, sp=2.6):
        for j in range(n):
            d = nv(rng.normal(0, 1, 3)); p = q + d * rng.uniform(0.3, sp)
            a1 = nv(rng.normal(0, 1, 3)); a2 = nv(np.cross(a1, nv(rng.normal(0, 1, 3)))); a3 = np.cross(a1, a2)
            if rng.random() < rf:
                for b in range(5):                                                   # a bract cluster: 5 papery bracts
                    pb = p + nv(rng.normal(0, 1, 3)) * 0.6
                    ell(S, pb, rng.uniform(0.45, 0.65), rng.uniform(0.35, 0.5), 0.15, M_BGFLOWER if rng.random() < 0.6 else M_BGFLOWER2,
                        axes=(a1, a2, a3), nu=5, nvv=6)
            else:
                ell(S, p, rng.uniform(0.7, 1.0), rng.uniform(0.4, 0.55), 0.18, M_BGLEAF if rng.random() < 0.6 else M_BGLEAF2,
                    axes=(a1, a2, a3), nu=5, nvv=6)
    for k in range(9):                                                              # the bush round the foot
        a = k * 0.8 + rng.uniform(-0.3, 0.3); rr = rng.uniform(3.0, 5.0)
        tuft(c + np.array([math.cos(a) * rr, math.sin(a) * rr, rng.uniform(2.0, 7.0)]), 16, 0.3, 3.2)
    for k in range(3, len(pts), 2):
        tuft(pts[k], 14, 0.15 + 0.45 * (k / len(pts)) ** 1.5)
    for k in range(12):                                                             # spilling off the đà, in front of the eave line
        u = pu + sd * (0.08 + k * 0.045 + rng.uniform(-0.02, 0.02))
        q = W3(u, PV + rng.uniform(-0.04, 0.06), BZ0 + rng.uniform(-0.5, 1.0)); tuft(q, 12, 0.6)
        if k < 9:
            for h in range(2 + (k % 3 == 0) + (k < 4)):
                tuft(q + np.array([0, 1.2, -2.4 - h * 2.4]), 8, 0.65, 2.0)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear()
    for p in LAMPS:
        K.LIGHTS2.append((W3(*p), hexc('#ff9645'), 18.0, 2.2, 'all'))
    K.GLOWS[:] = [(W3(*p), 0.22, 0.85) for p in LAMPS]
    for u in PU: postbundle(S, rng, u)
    beams(S, rng)
    D.LEAFMAT[0], D.RIDGEMAT[0] = M_LEAF_G, M_RIDGE_G
    hiproof(S, rng, E, EZ, R, battens=True, rr=0.85)       # slim hip rolls (critique 3)
    sign(S, rng)
    lamps(S)
    bonggiay(S, rng, PU[0], 1)
    bonggiay(S, rng, PU[1], -1)                   # Link 05:59: both posts alike
    return S, (S.ns, S.ns)


K.build = build


def render(n):
    return K.render(1, n, 'b')


if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        n = len(sys.argv) > 3 and sys.argv[3] == 'n'
        render(n).save(sys.argv[2])
    elif sys.argv[1] == 'atlas':
        out, tab = sys.argv[2], sys.argv[3]
        frames = {}
        for n in (0, 1):
            im = render(bool(n)); bb = im.getbbox(); frames['b' + ('n' if n else 'd')] = (im.crop(bb), bb)
        keys = ['bd', 'bn']
        x = 0; Gt = {}; sc = float(K.PXU); H = max(f[0].height for f in frames.values()); BB = K.BB
        sheet = Image.new('RGBA', (sum(frames[k][0].width + 2 for k in keys), H), (0, 0, 0, 0))
        for k in keys:
            im, bb = frames[k]; sheet.paste(im, (x, 0))
            Gt[k] = [x, 0, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
            x += im.width + 2
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, K.SHEET), 'WEBP', quality=92, method=6); json.dump(Gt, open(tab, 'w'))
        print('sheet', sheet.size)
