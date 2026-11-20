# packs out/hat/<id>/ (bake_hat.js) into lazy bundles lb/dg_h_<id>.wasm: items f<i>, meta {S, v, f}
import json, sys
from PIL import Image
from multiprocessing import Pool
from mk_bundles import pack, webp
def one(id):
    m = json.load(open(f'out/hat/{id}/meta.json'))
    items = [('f%d' % i, webp(Image.open(f'out/hat/{id}/{i}.png').convert('RGBA'))) for i in range(len(m['f']))]
    pack('dg_h_' + id, items, m)
if __name__ == '__main__':
    import os
    ids = sys.argv[1:] or sorted(os.listdir('out/hat'))
    with Pool(8) as p: p.map(one, ids)
