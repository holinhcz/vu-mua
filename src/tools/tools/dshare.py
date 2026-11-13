# (b49) object bundles d/<name>.wasm ("NTB1", u32 n, n x (s16 a, s16 b, u32 off, u32 len), bytes): byte-identical pictures inside
# one bundle stored once, every entry points at that copy (main._decode_some reads by offset, nothing else changes); info.json bh
# (crc32 of the file = the ?v= phones cache by) is updated for the rewritten bundles.
# usage: python3 dshare.py SITE name1 name2 ...   (writes SITE/d/<name>.wasm as a real file, rewrites SITE/info.json)
import sys, os, json, struct, hashlib, zlib
SITE = sys.argv[1]; I = json.load(open(SITE + '/info.json')); tot = 0
for nm in sys.argv[2:]:
    p = SITE + '/d/' + nm + '.wasm'; b = open(p, 'rb').read(); n = struct.unpack('<I', b[4:8])[0]
    E = [struct.unpack('<hhII', b[8 + k * 12:20 + k * 12]) for k in range(n)]
    seen = {}; out = bytearray(); hdr = bytearray(b[:8]); base = 8 + 12 * n
    for a, c, o, l in E:
        blob = b[o:o + l]; h = hashlib.md5(blob).digest()
        if h not in seen: seen[h] = base + len(out); out += blob
        hdr += struct.pack('<hhII', a, c, seen[h], l)
    nb = bytes(hdr) + bytes(out)
    if os.path.islink(p): os.remove(p)
    open(p, 'wb').write(nb); I['bh'][nm] = '%08x' % zlib.crc32(nb); tot += len(b) - len(nb)
    print(nm, len(b) - len(nb))
json.dump(I, open(SITE + '/info.json', 'w'), separators=(',', ':'), ensure_ascii=False)
print('saved', tot)
