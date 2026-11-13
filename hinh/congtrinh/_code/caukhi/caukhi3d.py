# Cầu khỉ (game id caukhi 3x1 along u, mirror caukhi2) as a real 3D model in the kho kit, same family and same light as
# the bến ghe / giếng (Link 2026-11-10 03:30: "check cầu khỉ, cầu tre qua sông, cầu ao, vẽ lại cho logic đồng nhất với
# công trình"). Sơ cấp, miền Tây: tre + tràm only, materials shared with src/benghe/benghe3d.py.
#  - the lối đi: two round tre laid side by side, in pieces that overlap on the supports, arching up over the water so a
#    xuồng passes under, both ends resting on the bank on short tràm stakes
#  - chân chống: crossed pairs of round tràm (an X) standing in the water, the lối đi sitting in the crotch, ripple rings
#  - tay vịn: one long tre on tall tre uprights lashed to each X, on the far side, sagging a little between uprights
#  - mây lashings at every joint
#   python3 caukhi3d.py prev OUT.png [n] [k|l]     (k: the short canal decor bridge, l: cầu khỉ dài 4x1)          python3 caukhi3d.py atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'benghe'))
import benghe3d as BG                         # also imports kho3d and registers the bến materials (M_TRAM, M_DECK ...)
K = BG.K
from kho3d import W3, T, Scene, X3, hexc, tube, disc

BG.D = 0                                      # BG.P(a, b, z) == W3(a, b, z): a = u along the bridge, b = v across
K.rrect = BG._rrect                           # the bến's deck-outline hook is not ours
K.BB = (-84, -76, 84, 44)
K.OX, K.OY = -32, -32                         # at.P(3,1)
K.WU0, K.WU1, K.WV0, K.WV1 = -9, -9, -9, -9
K.FOOT = (0.08, 2.92, 0.42, 0.58, 0.05)       # contact shade: only the strip under the lối đi
K.SHEET = 'caukhi.webp'
K.SEED = 9400
K.GS_K, K.FOOT_K = 0.22, 0.08
K.GROUND_SHADOW = True
K.NOSHADOW = set()
M_TRAM, M_TCUT, M_DECK, M_ROPE = BG.M_TRAM, BG.M_TCUT, BG.M_DECK, BG.M_ROPE
P = BG.P
U0, U1 = 0.06, 2.94                           # lối đi ends, on the banks
ZE, ZM = 2.2, 15.0                            # lối đi top at the ends and at the middle
SUP = (0.62, 1.5, 2.38)                       # the three X supports


def span(L, fw=3):
    """bridge length L on a fw x 1 item, centred on u fw/2: 2.88 on 3x1 (game cầu khỉ ngắn, 1 ô nước), 3.88 on 4x1
    (cầu khỉ dài, 2 ô nước), 1.69 on 3x1 for the canal decor bridge (src/ao bdraw)"""
    global U0, U1, ZM, SUP
    c = fw / 2
    U0, U1 = c - L / 2, c + L / 2
    if fw == 4: ZM, SUP = 17.0, (0.68, 1.56, 2.44, 3.32)
    elif L > 2.5: ZM, SUP = 15.0, (0.62, 1.5, 2.38)
    else: ZM, SUP = 12.0, (1.5,)
    K.OX, K.OY = -(fw - 1) * 16, -(fw + 1) * 8          # at.P(fw,1)
    K.BB = (-84, -76, 84, 44) if fw == 3 else (-104, -86, 104, 50)
    K.FOOT = (0.08, fw - 0.08, 0.42, 0.58, 0.05)


VW = 0.5                                      # centre line of the lối đi
VR = 0.36                                     # tay vịn side (far side, never covers the lối đi)
HR = 14.0                                     # tay vịn height above the lối đi (chest high on a villager)


def zw(u):
    """top of the lối đi along u: a soft arch, flat-ish over the water, easing down onto the banks"""
    t = min(1.0, max(0.0, (u - U0) / (U1 - U0)))
    return ZE + (ZM - ZE) * math.sin(math.pi * t) ** 0.7


def chain(S, rng, pts, r, mat, sag=0.0, prm=None):
    """a tre following a list of points, as short straight pieces (with an optional sag between the ends)"""
    n = len(pts) - 1
    for k in range(n):
        a, b = np.array(pts[k], float), np.array(pts[k + 1], float)
        if sag:
            a = a - np.array([0, 0, sag * math.sin(math.pi * k / n)]); b = b - np.array([0, 0, sag * math.sin(math.pi * (k + 1) / n)])
        tube(S, a, b, r, mat, prm=prm if prm is not None else (rng.random(), 0.5, 0), nr=7, nl=3)


def lash(S, c, r=0.75):
    X3.ellipsoid(S, c, r, r, r * 0.8, M_ROPE, nu=4, nvv=5)            # dây mây/dây dừa, dull, not orange dots


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear(); K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
    # --- chân chống: X of two round tràm per support, feet in the water, crossing just under the lối đi
    for u in SUP:
        zc = zw(u) - 1.6
        for s in (-1, 1):
            f = P(u + 0.02 * s, VW + 0.3 * s, 0.0)
            top = P(u - 0.01 * s, VW - 0.14 * s, zc + 6.5)          # past the crossing, the tips stick up
            tube(S, f, top, 1.05, M_TRAM, prm=(rng.random(), 0, 0), nr=8, nl=8, taper=0.9)
            disc(S, top, (0, 0, 1), 0.9, M_TCUT, nr=2, na=10)
            BG.ripple(S, f, 2.0)
        lash(S, P(u, VW, zc), 1.0)
        tube(S, P(u, VW - 0.12, zc - 0.6), P(u, VW + 0.12, zc - 0.6), 0.7, M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=3)  # gác ngang
    # --- end stakes on the banks: a short tràm pair each end, the lối đi lashed to them
    for u in (U0 + 0.05, U1 - 0.05):
        for s in (-1, 1):
            BG.post(S, rng, u, VW + 0.1 * s, zw(u) + 1.6, r=0.95, ring=False)
        lash(S, P(u, VW, zw(u) - 0.4), 0.9)
    # --- lối đi: two tre side by side, three pieces each, overlapping on the supports (a real cầu khỉ is pieced)
    cuts = [U0 - 0.02] + [s + 0.06 for s in SUP] + [U1 + 0.02]
    for j, dv in enumerate((-0.035, 0.035)):
        for k in range(len(cuts) - 1):
            a0 = cuts[k] - (0.1 if k else 0); a1 = cuts[k + 1] + (0.0 if k == len(cuts) - 2 else 0.02)
            n = 8
            pts = [P(a0 + (a1 - a0) * i / n, VW + dv + 0.006 * math.sin(i + k + j), zw(a0 + (a1 - a0) * i / n) - 1.0 + 0.15 * j)
                   for i in range(n + 1)]
            chain(S, rng, pts, 1.05 - 0.08 * j, M_DECK, prm=(rng.random(), 0.5, 0))
            disc(S, pts[0], (P(a0, 0, 0) - P(a1, 0, 0)) / np.linalg.norm(P(a0, 0, 0) - P(a1, 0, 0)), 0.95, M_TCUT, nr=2, na=10)
    for u in np.arange(U0 + 0.25, U1 - 0.1, 0.42):                # mây ties binding the two tre together
        lash(S, P(u, VW, zw(u) - 0.6), 0.95)
    # --- tay vịn: tre uprights lashed to each X on the far side, one long tre on top sagging between them
    ups = (U0 + 0.05,) + tuple(SUP) + (U1 - 0.05,)
    tops = []
    for u in ups:
        zb = zw(u) - 3.0 if u in SUP else 0.0
        tp = P(u, VR, zw(u) + HR)
        tube(S, P(u, VR, zb), tp + np.array([0, 0, 1.4]), 0.62, M_DECK, prm=(rng.random(), 0.5, 0), nr=6, nl=6)
        disc(S, tp + np.array([0, 0, 1.4]), (0, 0, 1), 0.55, M_TCUT, nr=2, na=8)
        lash(S, P(u, VR, zw(u)), 0.7)
        tops.append(tp)
    for k in range(len(tops) - 1):
        a, b = tops[k], tops[k + 1]
        pts = [a + (b - a) * i / 6 for i in range(7)]
        chain(S, rng, pts, 0.6, M_DECK, sag=0.9, prm=(rng.random(), 0.5, 0))
        lash(S, a, 0.75)
    lash(S, tops[-1], 0.75)
    return S, (S.ns, S.ns)


K.build = build

if __name__ == '__main__':
    if sys.argv[1] == 'prev':
        n = 'n' in sys.argv[3:]
        span(*((1.69, 3) if 'k' in sys.argv[3:] else (3.88, 4) if 'l' in sys.argv[3:] else (2.88, 3)))
        K.render(1, n, 'b').save(sys.argv[2])
    elif sys.argv[1] == 'atlas':
        out, tab = sys.argv[2], sys.argv[3]
        G = {}; sc = float(K.PXU); BB = K.BB; frames = []
        for pre, L, fw in (('c', 2.88, 3), ('k', 1.69, 3), ('l', 3.88, 4)):   # c: cầu khỉ ngắn, k: canal decor, l: cầu khỉ dài
            span(L, fw); sc = float(K.PXU); BB = K.BB
            for n in (0, 1):
                im = K.render(1, bool(n), 'b'); bb = im.getbbox(); frames.append((pre + ('n' if n else 'd'), im.crop(bb), bb, BB))
        Wd = sum(f[1].width + 2 for f in frames); Hh = max(f[1].height for f in frames)
        sheet = Image.new('RGBA', (Wd, Hh), (0, 0, 0, 0)); x = 0
        for k, im, bb, BB in frames:
            sheet.paste(im, (x, 0))
            G[k] = [x, 0, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
            x += im.width + 2
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, K.SHEET), 'WEBP', quality=92, method=6); json.dump(G, open(tab, 'w'))
        print('sheet', sheet.size)
