# hot patch: swap given entries of new.pck into the live pck of a (sparse) main checkout, re-slice, fix index.html + files.json
import sys, os, re, json, zlib, glob, shutil
sys.path.insert(0, '/home/claude/vu-src/src/tools')
from merge_logic import read_pck, write_pck, _rank, FB, SLICE
site, newp = sys.argv[1], sys.argv[2]; names = sys.argv[3].split(',')
hp = os.path.join(site, 'index.html'); h = open(hp, encoding='utf8').read()
np_ = int(re.search(r'\bNP=(\d+)', h).group(1))
pck = b''.join(open(os.path.join(site, 'pck_%d.wasm' % k), 'rb').read() for k in range(np_))
hdr, L = read_pck(pck); F = dict(L)
_, M = read_pck(open(newp, 'rb').read()); M = dict(M)
for n in names: F[n] = M[n] if n in M else open("/home/claude/vu-src/src/godot/" + n, "rb").read()
if len(sys.argv) > 4: F['logic/build.txt'] = sys.argv[4].encode()
# gói l/ mới hoặc đổi: ghi mã crc vào logic/lv.json (máy tải lại đúng gói đó)
if len(sys.argv) > 5:
    lv = json.loads(F['logic/lv.json'])
    for f in sys.argv[5].split(','):
        nm = os.path.basename(f)[:-5]
        lv[nm] = '%08x' % (zlib.crc32(open(f, 'rb').read()) & 0xffffffff)
        shutil.copy(f, os.path.join(site, 'l', nm + '.wasm'))
    F['logic/lv.json'] = json.dumps(lv).encode()
pk = write_pck(hdr, sorted(F.items(), key=lambda e: (_rank(e[0]), e[0])))
for f in glob.glob(os.path.join(site, 'pck_*.wasm')): os.remove(f)
open(os.path.join(site, 'pck_0.wasm'), 'wb').write(pk[:FB]); n = 1
for i in range(FB, len(pk), SLICE):
    open(os.path.join(site, 'pck_%d.wasm' % n), 'wb').write(pk[i:i + SLICE]); n += 1
B = '%08x' % (zlib.crc32(pk) & 0xffffffff)
h = re.sub(r'"index\.pck": \d+', '"index.pck": %d' % len(pk), h); h = re.sub(r'\bNP=\d+', 'NP=%d' % n, h)
h = re.sub(r'\bPCK=\d+', 'PCK=%d' % len(pk), h); h = re.sub(r"\bB='[0-9a-f]+'", "B='%s'" % B, h)
open(hp, 'w', encoding='utf8').write(h)
fj = os.path.join(site, 'files.json'); MF = json.load(open(fj))
for k in [k for k in MF if re.fullmatch(r'pck_\d+\.wasm', k)]: del MF[k]
crc = lambda p: '%08x' % (zlib.crc32(open(os.path.join(site, p), 'rb').read()) & 0xffffffff)
for k in range(n): MF['pck_%d.wasm' % k] = crc('pck_%d.wasm' % k)
if len(sys.argv) > 5:
    for f in sys.argv[5].split(','):
        MF['l/' + os.path.basename(f)] = crc('l/' + os.path.basename(f))
if os.path.exists(os.path.join(site, 'coganh/index.html')): MF['coganh/index.html'] = crc('coganh/index.html')
json.dump(MF, open(fj, 'w'), separators=(',', ':'))
print('pck', len(pk), 'slices', n, 'B', B, 'was NP', np_)
