# Packs the exported village into bundle files for the Godot test.
# usage: python3 pk.py TILEDIR OBJDIR OUTDIR
#  TILEDIR: <x>_<y>.webp, 1024 px per 128 world units (rendered at 8 px/unit, packed at 6 = the game's own sharpest sprite level)
#  OBJDIR : list.json + <j>.webp (8 px/unit) from go.js
# Ground: level l has 6/2^l px per unit, pieces of 384 px (64*2^l units); a bundle holds 8x8 pieces -> d/g<l>_<bx>_<by>.wasm
# Objects: levels 0..4; levels 0,1 bundled per 2048-unit cell (d/o<l>_<cx>_<cy>.wasm), levels 2..4 one bundle each (d/o<l>.wasm)
# Bundle: b"NTB1", u32 n, n x (s16 a, s16 b, u32 off, u32 len), then the webp bytes.
import sys, os, json, struct, io
from multiprocessing import Pool
import numpy as np
from PIL import Image

TD, OD, OUT = sys.argv[1:4]
Q = int(os.environ.get('Q', '85'))
SC = os.path.join(OUT, '_lv')
os.makedirs(os.path.join(OUT, 'd'), exist_ok=True)
os.makedirs(SC, exist_ok=True)
GLEV, OLEV, SUB = 6, 5, 384

names = [f for f in os.listdir(TD) if f.endswith('.webp')]
xy = [tuple(map(int, f[:-5].split('_'))) for f in names]
X0 = min(x for x, y in xy); Y0 = min(y for x, y in xy)

def enc(im):
    """webp bytes, or None if fully transparent; drops alpha when fully opaque"""
    a = np.asarray(im)[..., 3]
    if a.max() == 0:
        return None
    b = io.BytesIO()
    if a.min() == 255:
        im.convert('RGB').save(b, 'WEBP', quality=Q, method=4)
    else:
        im.save(b, 'WEBP', quality=Q, method=4, exact=False)
    return b.getvalue()

def half(im):
    """downscale by 2 in premultiplied space (no dark fringes at transparent edges)"""
    return im.convert('RGBa').reduce(2).convert('RGBA')

def lv0(f):
    p = os.path.join(TD, f)
    rv = os.environ.get('RIV')
    if rv and os.path.exists(f'{rv}/tiles/{f[:-5]}.png'):
        p = f'{rv}/tiles/{f[:-5]}.png'    # river tile: the water cut out (drawn by the shader under it)
    elif os.path.getsize(p) == 0:
        return []
    x, y = map(int, f[:-5].split('_'))
    im = Image.open(p).convert('RGBA')
    assert im.size == (1024, 1024), im.size
    im = im.convert('RGBa').resize((768, 768), Image.LANCZOS).convert('RGBA')
    out = []
    for j in range(2):
        for i in range(2):
            sx = (x - X0) // 64 + i; sy = (y - Y0) // 64 + j
            pc = im.crop((i * SUB, j * SUB, i * SUB + SUB, j * SUB + SUB))
            if np.asarray(pc)[..., 3].max() == 0:
                continue
            pc.save(f'{SC}/0_{sx}_{sy}.png', compress_level=1)
            out.append((sx, sy))
    return out

def lvn(args):
    l, sx, sy = args
    big = Image.new('RGBA', (2 * SUB, 2 * SUB), (0, 0, 0, 0)); any_ = False
    for j in range(2):
        for i in range(2):
            p = f'{SC}/{l-1}_{2*sx+i}_{2*sy+j}.png'
            if os.path.exists(p):
                big.paste(Image.open(p), (i * SUB, j * SUB)); any_ = True
    if not any_:
        return None
    sm = half(big)
    if np.asarray(sm)[..., 3].max() == 0:
        return None
    sm.save(f'{SC}/{l}_{sx}_{sy}.png', compress_level=1)
    return (sx, sy)

def encp(args):
    l, sx, sy = args
    return (l, sx, sy, enc(Image.open(f'{SC}/{l}_{sx}_{sy}.png').convert('RGBA')))

def bundle(path, ents):
    """ents: list of (a, b, bytes)"""
    ents = [e for e in ents if e[2]]
    hdr = b'NTB1' + struct.pack('<I', len(ents))
    off = 8 + 12 * len(ents); body = b''
    for a, b_, d in ents:
        hdr += struct.pack('<hhII', a, b_, off + len(body), len(d)); body += d
    open(path, 'wb').write(hdr + body)
    return len(hdr) + len(body)

if __name__ == '__main__':
    pool = Pool(int(os.environ.get('NP', '4')))
    levels = {}
    r = pool.map(lv0, names, chunksize=8)
    levels[0] = sorted(set(t for a in r for t in a))
    print('level 0 pieces', len(levels[0]), flush=True)
    for l in range(1, GLEV):
        cand = sorted(set((sx >> 1, sy >> 1) for sx, sy in levels[l - 1]))
        r = pool.map(lvn, [(l, sx, sy) for sx, sy in cand], chunksize=8)
        levels[l] = [t for t in r if t]
        print('level', l, 'pieces', len(levels[l]), flush=True)
    jobs = [(l, sx, sy) for l in range(GLEV) for sx, sy in levels[l]]
    enc_all = pool.map(encp, jobs, chunksize=4)
    groups = {}
    for l, sx, sy, d in enc_all:
        if d:
            groups.setdefault(f'g{l}_{sx >> 3}_{sy >> 3}', []).append((sx, sy, d))
    sizes = {}
    for nm, ents in groups.items():
        sizes[nm] = bundle(f'{OUT}/d/{nm}.wasm', ents)
    print('ground bundles', len(groups), 'MB', round(sum(sizes.values()) / 1e6, 1), 'biggest', max(sizes.values()) / 1e6, flush=True)

    # objects
    L = json.load(open(f'{OD}/list.json'))
    objs = []; og = {}
    for r_ in L:
        if r_.get('e'):
            continue
        j = len(objs)
        im = Image.open(f'{OD}/{r_["f"]}').convert('RGBA')
        im = im.convert('RGBa').resize((max(1, round(im.size[0] * .75)), max(1, round(im.size[1] * .75))), Image.LANCZOS).convert('RGBA')
        cx = int((r_['x'] + r_['w'] / 2 - X0) // 2048); cy = int((r_['y'] + r_['h'] / 2 - Y0) // 2048)
        objs.append([r_['x'], r_['y'], r_['w'], r_['h'], cx, cy, r_.get('kind', '')])
        for l in range(OLEV):
            if l:
                im = half(im) if min(im.size) >= 2 else im
            nm = f'o{l}_{cx}_{cy}' if l < 2 else f'o{l}'
            og.setdefault(nm, []).append((j, 0, enc(im)))
    osz = {nm: bundle(f'{OUT}/d/{nm}.wasm', e) for nm, e in og.items()}
    print('objects', len(objs), 'bundles', len(og), 'MB', round(sum(osz.values()) / 1e6, 1), 'biggest', max(osz.values()) / 1e6)
    gi = json.load(open(f'{TD}/info.json'))
    # the whole map small (level 4, 0.375 px/unit) in one picture: what the far bank mirrors in the river
    l4 = levels[4]; mx_ = max(a for a, b in l4) + 1; my_ = max(b for a, b in l4) + 1
    mos = Image.new('RGBA', (mx_ * SUB, my_ * SUB), (0, 0, 0, 0))
    for a, b in l4:
        mos.paste(Image.open(f'{SC}/4_{a}_{b}.png'), (a * SUB, b * SUB))
    os.makedirs(f'{OUT}/w', exist_ok=True)
    mos.save(f'{OUT}/w/refl.webp', quality=90, method=4, exact=False)
    U4 = SUB / (6 / 16)
    # start view: middle of the village (grid 0,0) a little down
    info = dict(X0=X0, Y0=Y0, ub=gi['ub'], hb=gi['hb'], DW=gi['DW'], VW=gi['VW'], ki=gi['ki'], hi=gi['hi'],
                start=[gi['ki'], gi['hi'] + 600], refl=[X0, Y0, mx_ * U4, my_ * U4], river=bool(os.environ.get('RIV')), bundles=sorted(list(groups) + list(og)), objs=objs)
    import zlib
    info['bh'] = {nm: format(zlib.crc32(open(f'{OUT}/d/{nm}.wasm', 'rb').read()), '08x') for nm in info['bundles']}
    json.dump(info, open(f'{OUT}/info.json', 'w'))
    print('files', len(groups) + len(og), 'total MB', round((sum(sizes.values()) + sum(osz.values())) / 1e6, 1))
