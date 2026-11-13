# (b47) logic bundles l/<name>.wasm ([u32 json len][json {i:{name:[off,len]},m}][bytes]): pictures that are byte-identical
# inside one bundle are stored once and every name points at that one copy (pics.gd reads by offset, nothing else changes).
# usage: python3 lshare.py SITE/l/x_hangcha.wasm ...   (rewrites in place, prints bytes saved)
import json, sys, struct, hashlib
for p in sys.argv[1:]:
    b = open(p, 'rb').read(); n = struct.unpack('<I', b[:4])[0]; J = json.loads(b[4:4 + n]); D = b[4 + n:]
    seen = {}; out = bytearray(); I = {}
    for k, (o, l) in sorted(J['i'].items(), key=lambda e: e[1][0]):
        blob = D[o:o + l]; h = hashlib.md5(blob).hexdigest()
        if h not in seen: seen[h] = [len(out), l]; out += blob
        I[k] = seen[h]
    if len(out) == len(D): print(p, 'no change'); continue
    J['i'] = I; j = json.dumps(J, separators=(',', ':'), ensure_ascii=False).encode()
    nb = struct.pack('<I', len(j)) + j + bytes(out); open(p, 'wb').write(nb); print(p, len(b) - len(nb))
