# packs the Godot port's pictures into lazy bundles l/<name>.wasm (format of logic/pics.gd):
# [u32 json length][json {i:{name:[offset,length]}, m:{...}}][webp bytes], every picture lossless webp
import json, os, io, struct, sys, numpy as np
from PIL import Image
from multiprocessing import Pool
OUT = 'lb'
def webp(im, exact=False):
    b = io.BytesIO(); im.save(b, 'WEBP', lossless=True, quality=100, method=4, exact=exact); return b.getvalue()
def pack(name, items, meta):
    idx = {}; body = bytearray()
    for k, data in items:
        idx[k] = [len(body), len(data)]; body += data
    j = json.dumps({'i': idx, 'm': meta}, separators=(',', ':'), ensure_ascii=False).encode()
    open(f'{OUT}/{name}.wasm', 'wb').write(struct.pack('<I', len(j)) + j + bytes(body))
    print(name, len(items), round((4 + len(j) + len(body)) / 1e6, 2), 'MB')
def half(im):
    w, h = im.size
    # premultiplied downscale so the transparent rim does not bleed dark
    a = np.asarray(im.convert('RGBA')).astype(np.float32) / 255
    a[..., :3] *= a[..., 3:4]
    p = Image.fromarray((a * 255 + .5).astype(np.uint8), 'RGBA')
    p = p.resize((max(1, (w + 1) // 2), max(1, (h + 1) // 2)), Image.LANCZOS)
    b = np.asarray(p).astype(np.float32) / 255
    al = b[..., 3:4]; b[..., :3] = np.where(al > 0, b[..., :3] / np.maximum(al, 1e-6), 0)
    return Image.fromarray((np.clip(b, 0, 1) * 255 + .5).astype(np.uint8), 'RGBA')
def racer(id):
    meta = json.load(open('out/racer/meta_all.json')) if id != 'npc' else json.load(open('out/racer/meta_npc.json'))
    m = meta[id]; d = f'out/racer/{id}'; n = len(m['f'])
    full, hal = [], []; fh = []
    for i in range(n):
        im = Image.open(f'{d}/{i}.png').convert('RGBA')
        if id != 'npc': full.append(('f%d' % i, webp(im)))
        h = half(im); hal.append(('f%d' % i, webp(h)))
        ox, oy, w, hh = m['f'][i]; fh.append([ox / 2, oy / 2, h.size[0], h.size[1]])
    if id != 'npc': pack('dg_r_' + id, full, {'S': meta['S'], 'size': m['size'], 'v': m['v'], 'f': m['f']})
    pack('dg_r_' + id + '_1', hal, {'S': meta['S'] / 2, 'size': m['size'], 'v': m['v'], 'f': fh})
    # menu card: standing, three quarters from the front
    st = m['v'][12]['st']; im = half(Image.open(f'{d}/{st}.png').convert('RGBA'))
    return id, webp(im), [m['f'][st][0] / 2, m['f'][st][1] / 2, im.size[0], im.size[1]]
if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    what = sys.argv[1:] or ['racers', 'map']
    if 'racers' in what:
        ids = [k for k in json.load(open('out/racer/meta_all.json')) if k not in ('S', 'views', 'run')] + ['npc']
        with Pool(8) as pl: res = pl.map(racer, ids)
        pack('dg_card', [(i, w) for i, w, _ in res if i != 'npc'], {'f': {i: f for i, _, f in res}, 'S': 4.8})
    if 'map' in what:
        mid = 'nongtrai'
        sm = json.load(open('out/spr/meta.json')); items = []
        for k in sm:
            items.append((k, webp(Image.open(f'out/spr/{k}.png').convert('RGBA'))))
        D = json.load(open(f'out/map/{mid}.json'))
        for nm in ['mac', 'inf']:
            raw = np.fromfile(f'out/map/{mid}_{nm}.raw', np.uint8).reshape(D['TXH'], D['TXW'], 4)
            items.append((nm, webp(Image.fromarray(raw, 'RGBA'), exact=True)))
        for nm in ['dirt', 'grass', 'mask']:
            items.append((nm, open(f'/mnt/project-files/dua-ga/src/ground/{nm}.webp', 'rb').read()))
        pack('dg_map_' + mid, items, {'spr': sm, 'map': D})
