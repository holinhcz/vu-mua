# n/<pack>.wasm container: u32 json length, json {name: [offset, length]}, then every file's bytes unchanged
import sys, os, json, struct
d, out = sys.argv[1], sys.argv[2]
I = {}; data = bytearray()
for f in sorted(os.listdir(d)):
    if not f.endswith('.webp'): continue
    b = open(os.path.join(d, f), 'rb').read(); I[f[:-5]] = [len(data), len(b)]; data += b
j = json.dumps(I, separators=(',', ':')).encode()
open(out, 'wb').write(struct.pack('<I', len(j)) + j + bytes(data)); print(out, len(I), len(data))
