# Gộp phần logic game (ruộng, nhân vật, HUD/Kho...) vào một bản build làng Godot đã xong.
# Chạy SAU khi thread làng build xong thư mục site (index.html + pck_<n>.wasm + info.json), TRƯỚC khi đăng:
#     python3 merge_logic.py <site_dir> [pkg_dir]
# pkg_dir mặc định = thư mục pkg/ cạnh file này (logic.pck + l/*.wasm, do build.py của thread logic làm ra).
# Sửa tại chỗ trong site_dir:
#   1) pck: thêm mọi file trong pkg/logic.pck (logic/, ui/, data/, icons/); project.binary của làng giữ nguyên,
#      chỉ thêm autoload Boot = *res://logic/boot.gd. Cắt lại pck_<n>.wasm (14 MB mỗi mảnh) như pack.py.
#   2) index.html: cập nhật fileSizes index.pck, NP, PCK, B (crc pck). Không đổi gì khác của shell.
#   3) info.json: object có kind "plot:*" và "parcel:*" (biển Khai hoang) bị dời ra ngoài bản đồ: logic vẽ sống bằng code.
#   4) chép pkg/l/*.wasm vào site_dir/l/ (gói hình cây/ô đất/nhân vật, tải lười, ?v riêng từng gói).
# Chạy lại nhiều lần trên cùng site_dir vẫn đúng (file logic cũ bị thay, autoload không thêm trùng).
import sys, os, re, json, struct, hashlib, zlib, shutil, glob

HERE = os.path.dirname(os.path.abspath(__file__))
CHUNK = 14 * 1024 * 1024

def read_pck(b):
    assert b[:4] == b'GDPC', 'không phải pck Godot'
    ver, ma, mi, pa, flags, fbase = struct.unpack_from('<IIIIIQ', b, 4)
    off = 32
    diro, = struct.unpack_from('<Q', b, off)
    off = diro
    n, = struct.unpack_from('<I', b, off); off += 4
    out = []
    for _ in range(n):
        l, = struct.unpack_from('<I', b, off); off += 4
        p = b[off:off + l].rstrip(b'\0').decode(); off += l
        o, s = struct.unpack_from('<QQ', b, off); off += 16
        off += 16
        fl, = struct.unpack_from('<I', b, off); off += 4
        assert fl == 0, 'pck có file mã hoá/flag lạ: ' + p
        out.append((p, b[fbase + o:fbase + o + s]))
    return (ver, ma, mi, pa), out

def write_pck(hdr, files):
    ver, ma, mi, pa = hdr
    A = 16; fb = 112; blob = bytearray(); ents = []
    for p, d in files:
        while len(blob) % A: blob += b'\0'
        ents.append((p, len(blob), len(d), hashlib.md5(d).digest())); blob += d
    while (fb + len(blob)) % A: blob += b'\0'
    diro = fb + len(blob)
    dr = struct.pack('<I', len(ents))
    for p, o, s, m in ents:
        pb = p.encode(); pl = len(pb) + 1
        while pl % 4: pl += 1
        dr += struct.pack('<I', pl) + pb + b'\0' * (pl - len(pb)) + struct.pack('<QQ', o, s) + m + struct.pack('<I', 0)
    hd = b'GDPC' + struct.pack('<IIIIIQQ', ver, ma, mi, pa, 2, fb, diro) + b'\0' * 64
    hd += b'\0' * (fb - len(hd))
    return bytes(hd) + bytes(blob) + dr

def add_autoload(pb):
    # project.binary (ECFG): thêm autoload/Boot nếu chưa có
    assert pb[:4] == b'ECFG'
    n, = struct.unpack_from('<I', pb, 4); o = 8; ents = []
    for _ in range(n):
        kl, = struct.unpack_from('<I', pb, o); k = pb[o + 4:o + 4 + kl]; o += 4 + kl
        vl, = struct.unpack_from('<I', pb, o); v = pb[o + 4:o + 4 + vl]; o += 4 + vl
        ents.append((k, v))
    ents = [(k, v) for k, v in ents if k != b'autoload/Boot']
    sv = b'*res://logic/boot.gd'
    v = struct.pack('<II', 4, len(sv)) + sv
    while len(v) % 4: v += b'\0'
    ents.append((b'autoload/Boot', v))
    out = b'ECFG' + struct.pack('<I', len(ents))
    for k, v in ents:
        out += struct.pack('<I', len(k)) + k + struct.pack('<I', len(v)) + v
    return out

def main():
    site = sys.argv[1]
    pkg = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, 'pkg')
    html_p = os.path.join(site, 'index.html')
    h = open(html_p, encoding='utf8').read()
    np_ = int(re.search(r'\bNP=(\d+)', h).group(1))
    pck = b''.join(open(os.path.join(site, 'pck_%d.wasm' % k), 'rb').read() for k in range(np_))
    hdr, base = read_pck(pck)
    _, mine = read_pck(open(os.path.join(pkg, 'logic.pck'), 'rb').read())
    F = dict(base)
    for p in list(F):
        if p.startswith(('logic/', 'ui/', 'data/', 'icons/')):
            del F[p]           # bản gộp trước: bỏ hết rồi thêm lại
    F.update(dict(mine))
    F['project.binary'] = add_autoload(F['project.binary'])
    pk = write_pck(hdr, sorted(F.items()))
    for f in glob.glob(os.path.join(site, 'pck_*.wasm')):
        os.remove(f)
    n = 0
    for i in range(0, len(pk), CHUNK):
        open(os.path.join(site, 'pck_%d.wasm' % n), 'wb').write(pk[i:i + CHUNK]); n += 1
    B = '%08x' % (zlib.crc32(pk) & 0xffffffff)
    h2 = re.sub(r'"index\.pck": \d+', '"index.pck": %d' % len(pk), h)
    h2 = re.sub(r'\bNP=\d+', 'NP=%d' % n, h2)
    h2 = re.sub(r'\bPCK=\d+', 'PCK=%d' % len(pk), h2)
    h2 = re.sub(r"\bB='[0-9a-f]+'", "B='%s'" % B, h2)
    open(html_p, 'w', encoding='utf8').write(h2)
    # info.json: giấu ô ruộng chụp sẵn
    ip = os.path.join(site, 'info.json')
    info = json.load(open(ip))
    hid = 0
    for o in info['objs']:
        if any(isinstance(x, str) and x.startswith(('plot:', 'parcel:')) for x in o):
            o[0] = -100000; o[1] = -100000; hid += 1
    json.dump(info, open(ip, 'w'), separators=(',', ':'))
    # gói hình
    os.makedirs(os.path.join(site, 'l'), exist_ok=True)
    for f in glob.glob(os.path.join(pkg, 'l', '*.wasm')):
        shutil.copy(f, os.path.join(site, 'l', os.path.basename(f)))
    print('merge_logic: pck %d byte, %d mảnh, B %s, %d file logic, giấu %d object plot:*/parcel:*, %d gói l/'
          % (len(pk), n, B, len(mine), hid, len(glob.glob(os.path.join(pkg, 'l', '*.wasm')))))

if __name__ == '__main__':
    main()
