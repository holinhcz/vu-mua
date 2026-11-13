# bought / unbought land data for the native ground (web NEN2 own()/tv() wild zone, tc() scenery):
#   n/parcel.png  263x263 L8: parcel index per tile (0 = none), names in n/parcel.json
#   n/nz.png      1024x1024 RGB: R = Me() lattice of vn(x/8.5+6.6, y/8.5+15.4), G = lattice of vn(x/23+34.6, y/23+10.2)
#                 (the game's own hash, JS double semantics), B left 255 (filled at run time with the per-tile wild value)
# usage: python3 lotprep.py parcels.json OUTDIR yards.json
import json, sys, math
import numpy as np
from PIL import Image
P = json.load(open(sys.argv[1])); OUT = sys.argv[2]
def i32(v):
    v = int(v) & 0xffffffff
    return v - (1 << 32) if v >= 1 << 31 else v
def Me(t, a):
    n = i32(float(t) * 374761393.0 + float(a) * 668265263.0)
    u = n & 0xffffffff
    n = i32(float(i32(n ^ (u >> 13))) * 1274126177.0)
    u = n & 0xffffffff
    return ((n ^ (u >> 16)) & 0xffffffff) / 4294967295.0
assert abs(Me(3, 5) - Me(3, 5)) == 0
N = P['vc']; F0, vo = P['F0'], P['vo']
a = np.array(P['a'], dtype=np.uint8).reshape(P['Vl'] - vo, N)   # row = h - vo, col = s - F0
Image.fromarray(a, 'L').save(OUT + '/parcel.png')
# yards (NEN2 put()/YD): [gx, gy, fw, fd, ring, front, lot ('' = always)]
YD = {'choi': (0, 0), 'well': (0, 0), 'haystack': (0, 0), 'cayrom': (0, 0)}
Y = json.load(open(sys.argv[3]))
YDL = [[g[1], g[2], g[3], g[4], *YD.get(g[0], (1, 0)), g[5]] for g in Y['so']]
YDL += [[int(k.split(',')[0]), int(k.split(',')[1]), 1, 1, *YD.get(i, (1, 0)), ''] for i, k in Y['hu']]
# lattices
L2 = (-1, 12)    # i0, j0 for the /8.5 lattice (x from -60, y from -20)
L1 = (31, 8)     # i0, j0 for the /23 lattice
L4 = (6, 12)     # i0, j0 for the /8.5 lattice of zones 4-5 (A)
img = np.full((1024, 1024, 4), 255, np.uint8)
for j in range(1024):
    for i in range(1024):
        img[j, i, 0] = round(Me(L2[0] + i, L2[1] + j) * 255)
        img[j, i, 1] = round(Me(L1[0] + i, L1[1] + j) * 255)
        img[j, i, 3] = round(Me(L4[0] + i, L4[1] + j) * 255)
Image.fromarray(img, 'RGBA').save(OUT + '/nz.png')
json.dump({'names': P['names'], 'tg': P['tg'], 'F0': F0, 'vo': vo, 'N': [N, P['Vl'] - vo], 'L2': L2, 'L1': L1,
           'L4': L4,
           'wild': [[w[1], w[2], w[3], w[4], w[5]] for w in P['wild']], 'yd': YDL}, open(OUT + '/parcel.json', 'w'), separators=(',', ':'))
print('ok', a.shape, a.max())
