# re-cut the sharp object bundles (levels 0, 1: d/o<l>_<cx>_<cy>.wasm) so that each lot's own things sit in bundles of their
# own (an unbought lot is never downloaded) and no file passes 13 MB (host limit 15 MB per file). No picture is re-encoded.
# usage: python3 resplit.py SITEDIR
import sys, os, json, struct, zlib, glob
GD = sys.argv[1]; LIM = 13e6
info = json.load(open(GD + '/info.json')); objs = info['objs']
def read(p):
    b = open(p, 'rb').read(); n = struct.unpack('<I', b[4:8])[0]; out = {}
    for k in range(n):
        a, b_, off, ln = struct.unpack('<hhII', b[8 + 12 * k:20 + 12 * k]); out[(a, b_)] = b[off:off + ln]
    return out
def write(p, ents):
    hdr = b'NTB1' + struct.pack('<I', len(ents)); off = 8 + 12 * len(ents); body = b''
    for (a, b_), d in ents:
        hdr += struct.pack('<hhII', a, b_, off + len(body), len(d)); body += d
    open(p, 'wb').write(hdr + body)
data = {0: {}, 1: {}}
for l in (0, 1):
    for p in glob.glob(f'{GD}/d/o{l}_*_*.wasm'):
        for k, d in read(p).items(): data[l][k] = d
        os.remove(p)
lots = sorted({o[7] for o in objs if len(o) > 7})
cell = {}; size = {}
for j, o in enumerate(objs):
    cx, cy = o[4], o[5] % 100 if o[5] >= 0 else o[5]
    base = cy + (100 * (lots.index(o[7]) + 1) if len(o) > 7 else 0)
    d0 = data[0].get((j, 0), b'')
    part = 0
    while size.get((cx, base + 5000 * part), 0) + len(d0) > LIM and size.get((cx, base + 5000 * part), 0) > 0:
        part += 1
    c = (cx, base + 5000 * part); size[c] = size.get(c, 0) + len(d0); o[5] = c[1]; cell[j] = c
names = [n for n in info['bundles'] if not (n.startswith('o0_') or n.startswith('o1_'))]
for l in (0, 1):
    G = {}
    for (j, z), d in data[l].items():
        G.setdefault(cell[j], []).append(((j, z), d))
    for (cx, cy), ents in G.items():
        nm = f'o{l}_{cx}_{cy}'; write(f'{GD}/d/{nm}.wasm', sorted(ents)); names.append(nm)
info['bundles'] = sorted(names)
info['bh'] = {nm: format(zlib.crc32(open(f'{GD}/d/{nm}.wasm', 'rb').read()), '08x') for nm in info['bundles']}
json.dump(info, open(GD + '/info.json', 'w'), separators=(',', ':'))
big = max(os.path.getsize(f'{GD}/d/{n}.wasm') for n in info['bundles'])
print('bundles', len(info['bundles']), 'lots', len(lots), 'largest MB', round(big / 1e6, 1))
