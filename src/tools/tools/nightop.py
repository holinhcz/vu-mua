# (b54, Link 11-13 "bản đêm ... cây cối đổi màu, nhà công trình đéo có đèn sáng") every village/shop picture n/op/<grp>-<dir>-<dayframe>
# gets its NIGHT frame from the same godot/ export folder (d0->n0, dx01->nx01, bd->bn, 0d->0n, dh_tim0->nh_tim0): lamps lit,
# night colours painted by the export itself, like the web. info.opn[day] = [night, dx, dy, w, h] in game units:
# night picture top-left relative to the day picture's top-left (unflipped), and its size.
# usage: python3 nightop.py SITE
import sys, os, json, io
from multiprocessing import Pool
from PIL import Image
SITE = sys.argv[1]; G = '/mnt/project-files/nong-trai-chung/godot/'
I = json.load(open(SITE + '/info.json')); opn = {}; miss = []; jobs = []
def enc(j):
    src, nb, fn = j; ni = Image.open(src).convert('RGBA').crop(nb); bio = io.BytesIO()
    ni.save(bio, 'WEBP', lossless=True, quality=100, method=4, exact=False); open(fn + '.tmp', 'wb').write(bio.getvalue()); os.replace(fn + '.tmp', fn)
def nkey(k):
    if k.endswith('d'): return k[:-1] + 'n'
    if '_d' in k: return k.replace('_d', '_n', 1)
    if k.startswith('d'): return 'n' + k[1:]
    return None
for nm in sorted(I.get('opb', {})):
    p = nm.split('-'); fd = p[0] + '/' + p[1]; fk = '-'.join(p[2:]); nk = nkey(fk)
    A = json.load(open(G + fd + '/atlas.json')); F = A['frames']; ppu = A.get('px_per_unit', 9)
    if not nk or nk not in F: miss.append(nm); continue
    d, n = F[fk], F[nk]
    di = Image.open(G + fd + '/' + d['file']).convert('RGBA'); db = di.getbbox()
    ni = Image.open(G + fd + '/' + n['file']).convert('RGBA'); nb = ni.getbbox()
    nn = '%s-%s-%s' % (p[0], p[1], nk); fn = '%s/n/op/%s.webp' % (SITE, nn)
    if not os.path.exists(fn): jobs.append((G + fd + '/' + n['file'], nb, fn))
    dx = (n['ox'] + nb[0] / ppu) - (d['ox'] + db[0] / ppu); dy = (n['oy'] + nb[1] / ppu) - (d['oy'] + db[1] / ppu)
    opn[nm] = [nn, round(dx, 3), round(dy, 3), round((nb[2] - nb[0]) / ppu, 3), round((nb[3] - nb[1]) / ppu, 3), round((db[2] - db[0]) / ppu, 3)]
if __name__ == '__main__':
    with Pool(os.cpu_count()) as P: P.map(enc, jobs, chunksize=1)
I['opn'] = opn
json.dump(I, open(SITE + '/info.json', 'w'), separators=(',', ':'), ensure_ascii=False)
print('night', len(opn), 'no night frame', len(miss), miss[:20])
