# The other two bridges in 3D, same family, materials and light as the cầu khỉ / bến ghe (Link 2026-11-10 03:30 + 03:42
# "thay luôn tiếp đi"). Sơ cấp miền Tây: tre + tràm only, no earth abutments (Link: no bệ đất on the bến).
#  KIND 'song'  Cầu tre qua sông (game id causong 1x5 along v, mirror causong2): a long arched tre bridge over the river,
#     deck of tre laid lengthwise in staggered pieces on tràm bents (pairs of posts + a cross beam, X braces on the tall
#     ones), a tre handrail on both sides, ends easing down onto the banks on short tràm stakes
#  KIND 'ao'    Cầu ao (game id bridge 2x1 along u since 2026-11-10, no mirror): a low flat footbridge over a pond, tre laid across on two
#     tràm stringers like the bến walkway, tràm post pairs, one tre handrail on the far side, short slope at each end
#   python3 cau3d.py song|ao prev OUT.png [n]       python3 cau3d.py song|ao atlas OUTDIR atlas.json
import math, sys, os, json
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'caukhi'))
import caukhi3d as CK                         # brings benghe3d (materials, post, ripple) and kho3d
K, BG = CK.K, CK.BG
from kho3d import W3, T, Scene, X3, hexc, tube, disc
M_TRAM, M_TCUT, M_DECK, M_ROPE = BG.M_TRAM, BG.M_TCUT, BG.M_DECK, BG.M_ROPE
chain, lash = CK.chain, CK.lash
K.WU0, K.WU1, K.WV0, K.WV1 = -9, -9, -9, -9
K.GS_K, K.FOOT_K = 0.22, 0.08
K.GROUND_SHADOW = True
K.NOSHADOW = set()
KIND = 'song'


def setup(kind):
    global KIND
    KIND = kind
    if kind == 'song':
        K.BB = (-130, -104, 130, 76); K.OX, K.OY = 64, -48            # at.P(1,5)
        K.FOOT = (0.3, 0.7, 0.06, 4.94, 0.05); K.SHEET = 'causong.webp'; K.SEED = 9500
    else:
        K.BB = (-58, -48, 58, 34); K.OX, K.OY = -16, -24              # at.P(2,1): cầu ao ngắn 2x1 (Link 04:08 "dài quá")
        K.FOOT = (0.08, 1.92, 0.33, 0.67, 0.05); K.SHEET = 'cauao.webp'; K.SEED = 9600


# ---------------------------------------------------------------- cầu tre qua sông (a across = u, b along = v, 0..5)
SB0, SB1 = 0.06, 4.94
SZE, SZM = 3.0, 20.0
BENTS = (0.72, 1.46, 2.14, 2.86, 3.54, 4.28)
SA0, SA1 = 0.3, 0.7                           # deck edges across
SHR = 12.0


def zs(b):
    t = min(1.0, max(0.0, (b - SB0) / (SB1 - SB0)))
    return SZE + (SZM - SZE) * math.sin(math.pi * t) ** 0.65


def Q(a, b, z): return W3(a, b, z)


def build_song(S, rng):
    # bents: two round tràm posts in the water, a tràm cross beam under the deck, X braces where they stand tall
    for b in BENTS:
        zt = zs(b) - 1.1
        for a in (SA0 - 0.02, SA1 + 0.02):
            BG.post(S, rng, a, b, zt - 0.4, r=1.15)
        tube(S, Q(SA0 - 0.08, b, zt - 0.2), Q(SA1 + 0.08, b, zt - 0.2), 0.8, M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=4)
        if zt > 9:
            tube(S, Q(SA0 - 0.02, b, 1.6), Q(SA1 + 0.02, b, zt - 2.2), 0.45, M_TRAM, prm=(rng.random(), 0, 0), nr=5, nl=4)
            tube(S, Q(SA1 + 0.02, b, 1.6), Q(SA0 - 0.02, b, zt - 2.2), 0.45, M_TRAM, prm=(rng.random(), 0, 0), nr=5, nl=4)
        for a in (SA0 - 0.02, SA1 + 0.02):
            lash(S, Q(a, b, zt - 0.2), 0.8)
    for b in (SB0 + 0.07, SB1 - 0.07):                                       # end stakes on the banks
        for a in (SA0 + 0.02, SA1 - 0.02):
            BG.post(S, rng, a, b, zs(b) - 0.6, r=0.95, ring=False)
        tube(S, Q(SA0 - 0.04, b, zs(b) - 0.9), Q(SA1 + 0.04, b, zs(b) - 0.9), 0.7, M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=3)
    # deck: six tre lengthwise, each in pieces joined over a bent, the joints staggered from one tre to the next
    stops = [SB0 + 0.07] + list(BENTS) + [SB1 - 0.07]
    NP = 6
    for j in range(NP):
        a = SA0 + 0.035 + (SA1 - SA0 - 0.07) * j / (NP - 1)
        joints = [stops[0] - 0.05] + [stops[k] for k in range(1 + j % 2, len(stops) - 1, 2)] + [stops[-1] + 0.05]
        for k in range(len(joints) - 1):
            b0 = joints[k] - (0.06 if k else 0); b1 = joints[k + 1]
            n = max(3, int((b1 - b0) * 7))
            pts = [Q(a + 0.004 * math.sin(i + j), b0 + (b1 - b0) * i / n, zs(b0 + (b1 - b0) * i / n) + 0.1 * (j % 2)) for i in range(n + 1)]
            chain(S, rng, pts, 0.95, M_DECK, prm=(rng.random(), 0.5, 0))
            d = pts[0] - pts[1]; disc(S, pts[0], d / np.linalg.norm(d), 0.85, M_TCUT, nr=2, na=10)
    for b in np.arange(SB0 + 0.35, SB1 - 0.2, 0.55):                         # tre cleats across the deck, tied down
        tube(S, Q(SA0 + 0.01, b, zs(b) + 1.05), Q(SA1 - 0.01, b, zs(b) + 1.05), 0.42, M_DECK, prm=(rng.random(), 0.5, 0), nr=5, nl=3)
    # handrails both sides: tre uprights at every bent and the ends, a tre rail on top sagging a little
    ups = [SB0 + 0.07] + list(BENTS) + [SB1 - 0.07]
    for a in (SA0 - 0.03, SA1 + 0.03):
        tops = []
        for b in ups:
            zb = zs(b) - 1.5
            tp = Q(a, b, zs(b) + SHR)
            tube(S, Q(a, b, zb), tp + np.array([0, 0, 1.2]), 0.55, M_DECK, prm=(rng.random(), 0.5, 0), nr=6, nl=5)
            disc(S, tp + np.array([0, 0, 1.2]), (0, 0, 1), 0.5, M_TCUT, nr=2, na=8)
            lash(S, Q(a, b, zs(b) + 0.6), 0.6)
            tops.append(tp)
        for k in range(len(tops) - 1):
            p0, p1 = tops[k], tops[k + 1]
            chain(S, rng, [p0 + (p1 - p0) * i / 6 for i in range(7)], 0.55, M_DECK, sag=0.7, prm=(rng.random(), 0.5, 0))
            lash(S, p0, 0.7)
        lash(S, tops[-1], 0.7)


# ---------------------------------------------------------------- cầu ao (a along = u 0..2, b across = v)
# Short (2x1, Link 2026-11-10 04:08): a flat tre platform on tràm posts, like the cầu ao of a miền Tây house. Either end
# can sit on the bank or over the pond, so it is level end to end and every post stands the same (no ripple rings).
AU0, AU1 = 0.06, 1.94
AZ = 6.0                                      # deck top
AB0, AB1 = 0.33, 0.67
APOST = (0.12, 0.7, 1.3, 1.88)
AHR = 10.0
AR = 0.36                                     # handrail side (far side)


def za(u):
    return AZ


def build_ao(S, rng):
    for u in APOST:                                                           # tràm post pairs with a cross beam
        for b in (AB0 + 0.02, AB1 - 0.02):
            BG.post(S, rng, u, b, AZ - 1.6, r=1.15, ring=False)
        tube(S, W3(u, AB0 - 0.05, AZ - 1.9), W3(u, AB1 + 0.05, AZ - 1.9), 0.75, M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=4)
    for b in (AB0 + 0.04, AB1 - 0.04):                                        # two tràm stringers along u, following the deck
        pts = [W3(AU0 + (AU1 - AU0) * i / 16, b, za(AU0 + (AU1 - AU0) * i / 16) - 1.05) for i in range(17)]
        chain(S, rng, pts, 0.72, M_TRAM, prm=(rng.random(), 0, 0))
    # deck: round tre across, one after another, each a little different (as on the bến walkway)
    step = 1.3 / T
    u = AU0
    while u < AU1:
        L0 = AB0 - 0.01 - rng.random() * 0.03; L1 = AB1 + 0.01 + rng.random() * 0.03
        r = 0.6 + 0.08 * rng.random(); z = za(u) - 0.3 + 0.12 * rng.random()
        tube(S, W3(u, L0, z), W3(u + (rng.random() - 0.5) * 0.01, L1, z), r, M_DECK, prm=(rng.random(), 0.5, 0), nr=6, nl=3)
        u += step * (0.95 + 0.1 * rng.random())
    for u in np.arange(AU0 + 0.2, AU1, 0.45):                                 # mây ties on the stringers
        for b in (AB0 + 0.04, AB1 - 0.04):
            lash(S, W3(u, b, za(u) + 0.2), 0.55)
    # one tre handrail on the far side, on short tràm uprights
    ups = (AU0 + 0.1, 1.0, AU1 - 0.1)
    tops = []
    for u in ups:
        tp = W3(u, AR, za(u) + AHR)
        tube(S, W3(u, AR, za(u) - 1.2), tp + np.array([0, 0, 1.0]), 0.6, M_TRAM, prm=(rng.random(), 0, 0), nr=6, nl=5)
        disc(S, tp + np.array([0, 0, 1.0]), (0, 0, 1), 0.52, M_TCUT, nr=2, na=8)
        tops.append(tp)
    for k in range(len(tops) - 1):
        p0, p1 = tops[k], tops[k + 1]
        chain(S, rng, [p0 + (p1 - p0) * i / 4 for i in range(5)], 0.55, M_DECK, sag=0.4, prm=(rng.random(), 0.5, 0))
        lash(S, p0, 0.65)
    lash(S, tops[-1], 0.65)


def build(level, rng, with_props=True):
    S = Scene(); K.LIGHTS2.clear(); K.GLOWS[:] = []; K.GROUND_GLOW[:] = []
    (build_song if KIND == 'song' else build_ao)(S, rng)
    return S, (S.ns, S.ns)


K.build = build

if __name__ == '__main__':
    setup(sys.argv[1])
    if sys.argv[2] == 'prev':
        K.render(1, 'n' in sys.argv[4:], 'b').save(sys.argv[3])
    elif sys.argv[2] == 'atlas':
        out, tab = sys.argv[3], sys.argv[4]
        G = {}; sc = float(K.PXU); BB = K.BB; frames = []
        for n in (0, 1):
            im = K.render(1, bool(n), 'b'); bb = im.getbbox(); frames.append(('n' if n else 'd', im.crop(bb), bb))
        Wd = sum(f[1].width + 2 for f in frames); Hh = max(f[1].height for f in frames)
        sheet = Image.new('RGBA', (Wd, Hh), (0, 0, 0, 0)); x = 0
        for k, im, bb in frames:
            sheet.paste(im, (x, 0))
            G['b' + k] = [x, 0, im.width, im.height, round(BB[0] + bb[0] / sc, 2), round(BB[1] + bb[1] / sc, 2), round(im.width / sc, 2), round(im.height / sc, 2)]
            x += im.width + 2
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, K.SHEET), 'WEBP', quality=92, method=6); json.dump(G, open(tab, 'w'))
        print('sheet', sheet.size)
