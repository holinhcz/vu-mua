# adds the menu map cards (mp_<id>) and the map / hat / stage / mission lists to the dg_card bundle
import json, struct, glob, os
from PIL import Image
from mk_bundles import webp
b = open('lb/dg_card.wasm', 'rb').read(); n = struct.unpack('<I', b[:4])[0]; j = json.loads(b[4:4 + n]); body = bytearray(b[4 + n:])
for f in sorted(glob.glob('out/card2/mp_*.png')):
    k = os.path.basename(f)[:-4]; d = webp(Image.open(f).convert('RGBA'))
    j['i'][k] = [len(body), len(d)]; body += d
j['m'].update(json.load(open('out/card2/meta.json')))
js = json.dumps(j, ensure_ascii=False, separators=(',', ':')).encode()
open('lb/dg_card.wasm', 'wb').write(struct.pack('<I', len(js)) + js + bytes(body)); print('dg_card', len(body))
