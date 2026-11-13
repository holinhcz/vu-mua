# River for the Godot test, in world space (port of song/proc.py, which worked on one 3 px/unit capture).
# usage: python3 riv.py T8 TMAG TGRN WMAG OUT POLY
#  T8   : ground tiles <x>_<y>.webp (1024 px / 128 units), normal water
#  TMAG/TGRN: the river tiles rendered with the river filled #ff00ff / #00ff00 (window.__KEY)
#  WMAG : whole map at 0.5 px/unit with the river in magenta (for land colours)
#  POLY : whole map at 0.5 px/unit, the river's own outline filled white (g/gwp.js): the bank is where this ends,
#         so branches, flowers, stakes, ropes and boats standing in the river never make a shore of their own
# writes OUT/tiles/<x>_<y>.png  (river tiles: water cut out, straight alpha; what stands over the water kept)
#        OUT/mapA.png (R up/1020, G dist/255, B fo, A sn), OUT/mapB.png (R,G flow, B refw, A unused 255)
#        OUT/riv.json (map origin/size in world units, px per unit, colours)
# Units: the shader works in "capture pixels" = 3 per world unit (the v5 page); maps are 0.5 px/unit, so F = 6.
import sys, os, json
from multiprocessing import Pool
import numpy as np
from PIL import Image
from scipy import ndimage as nd
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from crisp import crisp

T8, TM, TG, WM, OUT, POLY = sys.argv[1:7]
os.makedirs(f'{OUT}/tiles', exist_ok=True)
K1 = np.array([255, 0, 255], np.float32); K2 = np.array([0, 255, 0], np.float32)
info = json.load(open(f'{T8}/info.json'))
ub, hb, DW, VW = info['ub'], info['hb'], info['DW'], info['VW']
names = sorted(f for f in os.listdir(TM) if f.endswith('.webp') and os.path.getsize(f'{TM}/{f}') > 0)

def load(d, f):
    return np.asarray(Image.open(f'{d}/{f}').convert('RGB')).astype(np.float32)

def matte(f):
    c1, c2 = load(TM, f), load(TG, f)
    # off the map edge nothing is painted (clear): that is neither water nor something standing on it
    A1 = np.asarray(Image.open(f'{TM}/{f}').convert('RGBA'))[..., 3].astype(np.float32) / 255
    oa = np.clip(((c1 - c2) @ np.array([1, -1, 1], np.float32)) / (3 * 255), 0, 1)
    bad = np.abs((c1 - c2) - oa[..., None] * (K1 - K2)).max(2) > 30
    nk = (np.abs(c1 - K1).max(2) < 70) | (np.abs(c2 - K2).max(2) < 70)
    oa[bad & nk] = 1; oa[bad & ~nk] = 0
    pm = np.clip(c1 - oa[..., None] * K1, 0, 255)
    pm[bad & ~nk] = c1[bad & ~nk]
    return oa, pm, A1

def stats(f):
    oa, pm, A1 = matte(f)
    a = 1 - oa; cand = (a > .2) & (a < .8) & (A1 > .99)
    return a[cand][::7], pm[cand][::7]

def cut(args):
    f, ao, Po = args
    oa, pm, A1 = matte(f)
    a = 1 - oa
    aobj = np.clip(1 - (1 - a) / (1 - ao), 0, 1)
    pobj = np.clip(pm - Po[None, None, :] * (1 - aobj[..., None]), 0, 255)
    a = aobj; pm = np.minimum(pobj, a[..., None] * 255)
    solid = a > .995
    old = load(T8, f)
    pm[solid] = old[solid]; a[solid] = 1
    # tiny specks of see-through left on open water: drop
    lab, n = nd.label(a > .03)
    if n:
        sz = nd.sum(np.ones_like(a), lab, range(1, n + 1)); am = nd.maximum(a, lab, range(1, n + 1))
        drop = np.zeros(n + 1, bool); drop[1:] = (sz < 60) & (am < .9)
        dz = drop[lab]; a[dz] = 0; pm[dz] = 0
    rgb = np.where(a[..., None] > 1e-3, pm / np.maximum(a[..., None], 1e-3), 0)
    a = crisp(np.clip(rgb, 0, 255).astype(np.float32), a)   # see-through bands along the bank: solid or water
    wat = (1 - a) * A1          # water only where something was painted
    a = a * A1
    im = np.dstack([np.clip(rgb, 0, 255), a * 255]).round().astype(np.uint8)
    Image.fromarray(im, 'RGBA').save(f'{OUT}/tiles/{f[:-5]}.png', compress_level=1)
    # water fraction at 0.5 px/unit (16x16 blocks)
    w = wat.reshape(64, 16, 64, 16).mean((1, 3))
    return f, w

if __name__ == '__main__':
    pool = Pool(int(os.environ.get('NP', '3')))
    if os.environ.get('AO') is not None:
        # renders made without the game's dull wash (window.__NODULL): nothing to take off
        ao = float(os.environ['AO']); Po = np.zeros(3, np.float32); A = []
    else:
        st = pool.map(stats, names[::3])
        A = np.concatenate([s[0] for s in st]); P = np.concatenate([s[1] for s in st])
        ao = float(np.median(A)); Po = np.median(P, 0)
    print('wash', ao, Po, len(A), flush=True)
    res = pool.map(cut, [(f, ao, Po) for f in names], chunksize=4)
    # ---- maps at 0.5 px/unit over the whole map
    S = 0.5; F = 6.0
    MW, MH = int(np.ceil((DW - ub) * S)), int(np.ceil((VW - hb) * S))
    wf = np.zeros((MH, MW), np.float32)
    for f, w in res:
        x, y = map(int, f[:-5].split('_'))
        X, Y = int(round((x - ub) * S)), int(round((y - hb) * S))
        x0, y0, x1, y1 = max(X, 0), max(Y, 0), min(X + 64, MW), min(Y + 64, MH)
        if x1 > x0 and y1 > y0:
            wf[y0:y1, x0:x1] = np.maximum(wf[y0:y1, x0:x1], w[y0 - Y:y1 - Y, x0 - X:x1 - X])
    c1 = np.asarray(Image.open(WM).convert('RGB')).astype(np.float32)[:MH, :MW]
    H, W = wf.shape
    water = wf > .25            # slightly generous: the real edge comes from the 6 px/unit pieces
    water = nd.binary_opening(water, iterations=1)
    lab, n = nd.label(water)
    sz = nd.sum(water, lab, range(1, n + 1)); keep = np.zeros(n + 1, bool); keep[1:] = sz > 120
    water = keep[lab]
    # the river's outline from the game: outside it is the bank. Inside it, whatever stands in the water counts as
    # water (the shader draws under it, the pieces above hide it), except within KB px of the outline, where bank
    # grass and the plants at the water's edge make the real waterline.
    P = np.asarray(Image.open(POLY).convert('L')).astype(np.float32)[:MH, :MW] / 255 > .5
    P &= np.asarray(Image.open(WM).convert('RGBA'))[..., 3][:MH, :MW] > 127   # off the painted map: no river
    KB = int(os.environ.get('KB', '2'))
    nearOut = nd.binary_dilation(~P, iterations=KB)
    water = P & (water | ~nearOut)
    lab, n = nd.label(water)
    sz = nd.sum(water, lab, range(1, n + 1)); keep = np.zeros(n + 1, bool); keep[1:] = sz > 120
    water = keep[lab]
    waterE = water
    rows = np.arange(H)[:, None].repeat(W, 1)
    edge = np.maximum.accumulate(np.where(~waterE, rows, -1), 0)
    edge = nd.median_filter(edge, size=(1, 3))
    up = np.where(water, rows - edge, 0).astype(np.float32) * F
    up[(edge < 0) | (up < 0)] = 0
    dist, (niy, nix) = nd.distance_transform_edt(waterE, return_indices=True)
    dist = dist.astype(np.float32) * F
    refw = nd.gaussian_filter((water & (edge >= 0)).astype(np.float32), [.5, 1])
    wf2 = water.astype(np.float32)
    up = nd.gaussian_filter1d(up * wf2, 8 / F, axis=1) / np.maximum(nd.gaussian_filter1d(wf2, 8 / F, axis=1), 1e-3) * wf2
    landE = ~waterE
    earth = landE & (c1[..., 0] > c1[..., 1] * .95)
    lf = landE.astype(np.float32)
    earthS = nd.gaussian_filter(earth.astype(np.float32), .5) / np.maximum(nd.gaussian_filter(lf, .5), 1e-3)
    fo = np.where(waterE, earthS[niy, nix], 0).astype(np.float32)
    fo = nd.gaussian_filter(np.clip((fo - .25) / .5, 0, 1), 5 / F) * waterE
    del niy, nix
    nextl = np.minimum.accumulate(np.where(landE, rows, 10 * H)[::-1], 0)[::-1]
    sn = np.exp(-np.clip(nextl - rows, 0, 2000) * F / 70.) * water
    sn = nd.gaussian_filter(sn.astype(np.float32), [2 / F, 1])
    ds = nd.gaussian_filter(np.minimum(dist, 120), 10 / F)
    gy, gx = np.gradient(ds)
    tx, ty = -gy, gx
    R = np.array([2, 1], np.float32) / np.sqrt(5)
    s = np.sign(tx * R[0] + ty * R[1]); s[s == 0] = 1
    tx, ty = tx * s, ty * s
    m = np.hypot(tx, ty) + 1e-6
    tx, ty = tx / m, ty / m
    wgt = np.clip(m * 8 * F, 0, 1)
    tx = tx * wgt + R[0] * (1 - wgt); ty = ty * wgt + R[1] * (1 - wgt)
    tx = nd.gaussian_filter(tx, 12 / F); ty = nd.gaussian_filter(ty, 12 / F)
    m = np.hypot(tx, ty) + 1e-6; tx, ty = tx / m, ty / m
    # crop to the river (plus the far-bank reach above it)
    ys, xs = np.nonzero(waterE)
    cx0, cx1 = max(xs.min() - 8, 0), min(xs.max() + 9, W)
    cy0, cy1 = max(ys.min() - 8, 0), min(ys.max() + 9, H)
    sl = (slice(cy0, cy1), slice(cx0, cx1))
    A = np.stack([np.clip(up / 4, 0, 255), np.clip(dist, 0, 255), fo * 255, sn * 255], 2)[sl]
    B = np.stack([tx * 127 + 128, ty * 127 + 128, refw * 255, np.full_like(tx, 255)], 2)[sl]
    Image.fromarray(np.round(A).astype(np.uint8), 'RGBA').save(f'{OUT}/mapA.png', optimize=True)
    Image.fromarray(np.round(B).astype(np.uint8), 'RGBA').save(f'{OUT}/mapB.png', optimize=True)
    # river colour from the game's own water (old tiles, mid-river)
    mids = []
    for f, w in res[::4]:
        old = load(T8, f)[::16, ::16]
        x, y = map(int, f[:-5].split('_'))
        X, Y = int(round((x - ub) * S)), int(round((y - hb) * S))
        if X < 0 or Y < 0 or X + 64 > W or Y + 64 > H:
            continue
        dd = dist[Y:Y + 64, X:X + 64]
        mids.append(old[dd > 60])
    game = np.median(np.concatenate(mids), 0)
    if os.environ.get('RIVCOL'):
        game = np.array([float(v) for v in os.environ['RIVCOL'].split(',')])   # keep the colour already approved
    deep = np.clip(game * np.array([.92, .98, .98]), 0, 255); shal = np.clip(game * np.array([1.10, 1.10, 1.03]), 0, 255)
    rj = dict(x=ub + cx0 / S, y=hb + cy0 / S, w=(cx1 - cx0) / S, h=(cy1 - cy0) / S, S=S,
              game=[float(v) for v in game], deep=[float(v) for v in deep], shal=[float(v) for v in shal], ao=ao)
    json.dump(rj, open(f'{OUT}/riv.json', 'w'))
    print(rj, A.shape)
