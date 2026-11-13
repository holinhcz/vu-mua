# (b49) season pictures for the native village, straight from the split exports in godot/ (no re-cut from the web):
#   cao su (godot/caylang/caosu, 9 px/unit): scenery kinds 31-34 = seed 0-3; frame = seed + 4*look, look by season [0,0,1,2]
#   mai (godot/kieng/mai, 9 px/unit): objects 104 (seed 2) and 141 (seed 0); frame = seed + 4*season
# out: n/ss.wasm  container [u32 json len][json {name:[off,len]}][lossless webp...] (main._fetch_in)
#      n/ss.json  {"cs": {"j": {kind: seed}, "f": {frame: [ox,oy,gw,gh]}}, "mai": {"o": {obj: [seed, ax, ay]}, "f": {...}}}
# usage: python3 ssprep.py SITE/n SITE/info.json
import json, sys, io, struct
from PIL import Image
G = '/mnt/project-files/nong-trai-chung/godot/'
OUT, INFO = sys.argv[1], sys.argv[2]
I = json.load(open(INFO))
names = {}; data = bytearray()
def put(nm, path):
    im = Image.open(path).convert('RGBA'); b = io.BytesIO()
    im.save(b, 'WEBP', lossless=True, quality=100, method=6, exact=True); v = b.getvalue()
    names[nm] = [len(data), len(v)]; data.extend(v)
def fr(d, k):
    a = json.load(open(G + d + '/atlas.json'))['frames']['d%d' % k]; return [a['ox'], a['oy'], a['w'] / 9.0, a['h'] / 9.0]
CS = {31: 0, 32: 1, 33: 2, 34: 3}
csf = {}
for s in CS.values():
    for look in (1, 2):   # look 0 (xuân, hạ) = the scenery picture the village already has (n/sc/<kind>.webp)
        k = s + 4 * look; put('cs%d' % k, G + 'caylang/caosu/d%d.png' % k); csf[k] = fr('caylang/caosu', k)
# mai objects: anchor from the summer frame the object was made from (content boxes matched, see notes)
MO = {104: (2, 6), 141: (0, 4)}
mo = {}; mf = {}
dpk = {}
for j, (seed, f0) in MO.items():
    o = I['objs'][j]
    ob = Image.open(sys.argv[3] + '/mai_obj_%d.png' % j).convert('RGBA').getbbox() if len(sys.argv) > 3 else None
    fb = Image.open(G + 'kieng/mai/d%d.png' % f0).convert('RGBA').getbbox()
    ox, oy = fr('kieng/mai', f0)[:2]
    ax = o[0] + ob[0] / 9.0 - ox - fb[0] / 9.0; ay = o[1] + ob[1] / 9.0 - oy - fb[1] / 9.0
    mo[j] = [seed, round(ax, 3), round(ay, 3)]
    for se in (0, 2, 3):   # hạ (1) = the object picture the village already has
        k = seed + 4 * se; put('mai%d' % k, G + 'kieng/mai/d%d.png' % k); mf[k] = fr('kieng/mai', k)
j = json.dumps(names, separators=(',', ':')).encode()
open(OUT + '/ss.wasm', 'wb').write(struct.pack('<I', len(j)) + j + bytes(data))
json.dump({'cs': {'j': CS, 'f': csf}, 'mai': {'o': mo, 'f': mf}}, open(OUT + '/ss.json', 'w'), separators=(',', ':'))
print('pictures', len(names), 'bytes', len(data) + len(j) + 4, mo)
