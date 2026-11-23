# Gói hình Câu cá cho Nông Trại: l/cc.wasm = pck Godot chỉ chứa ui/img/cc/** (lấy từ src/cauca/ui/img/cc).
# Farm KHÔNG để hình câu cá trong pck chính (đỡ ~25 MB lúc mở vườn): ui_cc.gd tải gói này lần đầu bấm "Câu cá",
# lưu user://cc_<crc>.pck, ProjectSettings.load_resource_pack() rồi code cc đọc res://ui/img/cc/... như thường.
# python3 mk_ccpack.py <main checkout> [ui_cc.gd, mặc định src/godot/logic/ui_cc.gd] -> ghi <main>/l/cc_<i>.wasm (miếng 8 MB), điền CC_V/CC_N/CC_SIZE vào ui_cc.gd
import sys, os, zlib
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from merge_logic import write_pck
site = sys.argv[1]
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'cauca', 'ui', 'img', 'cc')
files = []
for root, _, fs in os.walk(SRC):
    for f in fs:
        p = os.path.join(root, f)
        files.append(('ui/img/cc/' + os.path.relpath(p, SRC).replace(os.sep, '/'), open(p, 'rb').read()))
files.sort()
pk = write_pck((3, 4, 5, 1), files)
os.makedirs(os.path.join(site, 'l'), exist_ok=True)
import glob, re
for f in glob.glob(os.path.join(site, 'l', 'cc_*.wasm')): os.remove(f)
SL = 8 << 20
n = 0
for i in range(0, len(pk), SL):
    open(os.path.join(site, 'l', 'cc_%d.wasm' % n), 'wb').write(pk[i:i + SL]); n += 1
crc = '%08x' % (zlib.crc32(pk) & 0xffffffff)
UC = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'godot', 'logic', 'ui_cc.gd')   # mặc định điền thẳng vô ui_cc.gd, khỏi quên
if os.path.exists(UC):
    u = open(UC, encoding='utf8').read()
    u = re.sub(r'const CC_V := "[^"]*"', 'const CC_V := "%s"' % crc, u)
    u = re.sub(r'const CC_N := \S+', 'const CC_N := %d' % n, u)
    u = re.sub(r'const CC_SIZE := \S+', 'const CC_SIZE := %d' % len(pk), u)
    open(UC, 'w', encoding='utf8').write(u)
print('files', len(files), 'bytes', len(pk), 'slices', n, 'crc', crc)
