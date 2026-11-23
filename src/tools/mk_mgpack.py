# (bản 533) Gói hình mini game cho Nông Trại: l/mg_<i>.wasm = pck Godot chỉ chứa ui/img/{caro,cg,oq,tso}/** (lấy từ src/godot/ui/img).
# Vườn KHÔNG để mấy hình này trong pck chính (mybuild bỏ ra, đỡ ~16 MB lúc mở làng): logic/mg_pack.gd tải gói này lần đầu
# bấm vào Cờ caro / Cờ gánh / Ô ăn quan / Tìm số, lưu user://mg_<crc>.pck, load_resource_pack() rồi đọc res://ui/img/... như thường.
# python3 mk_mgpack.py <main checkout> -> ghi <main>/l/mg_<i>.wasm (miếng 8 MB), điền MG_V/MG_N/MG_SIZE vào logic/mg_pack.gd
import sys, os, zlib, glob, re
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from merge_logic import write_pck
DIRS = ['caro', 'cg', 'oq', 'tso']
site = sys.argv[1]
G = os.path.join(HERE, '..', 'godot')
files = []
for d in DIRS:
    for root, _, fs in os.walk(os.path.join(G, 'ui', 'img', d)):
        for f in fs:
            if f == '.gdignore' or f.endswith('.import'):
                continue
            p = os.path.join(root, f)
            files.append(('ui/' + os.path.relpath(p, os.path.join(G, 'ui')).replace(os.sep, '/'), open(p, 'rb').read()))
files.sort()
pk = write_pck((3, 4, 5, 1), files)
os.makedirs(os.path.join(site, 'l'), exist_ok=True)
for f in glob.glob(os.path.join(site, 'l', 'mg_*.wasm')):
    os.remove(f)
SL = 8 << 20
n = 0
for i in range(0, len(pk), SL):
    open(os.path.join(site, 'l', 'mg_%d.wasm' % n), 'wb').write(pk[i:i + SL]); n += 1
crc = '%08x' % (zlib.crc32(pk) & 0xffffffff)
U = os.path.join(G, 'logic', 'mg_pack.gd')
u = open(U, encoding='utf8').read()
u = re.sub(r'const MG_V := "[^"]*"', 'const MG_V := "%s"' % crc, u)
u = re.sub(r'const MG_N := \d+', 'const MG_N := %d' % n, u)
u = re.sub(r'const MG_SIZE := \d+', 'const MG_SIZE := %d' % len(pk), u)
open(U, 'w', encoding='utf8').write(u)
print('files', len(files), 'bytes', len(pk), 'slices', n, 'crc', crc)
