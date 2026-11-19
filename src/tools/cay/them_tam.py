# hình cây tạm cho cây mới chưa có hình riêng: chép khung (mọi mức nét @1..@4 + meta) của cây có sẵn sang khoá mới
# usage: python3 them_tam.py L_DIR SRC_BUNDLE SRC_ID DST_BUNDLE DST_ID
import sys, json, struct
def rd(p):
    b = open(p, 'rb').read(); n = struct.unpack('<I', b[:4])[0]; j = json.loads(b[4:4 + n]); o = 4 + n
    return j, {k: b[o + v[0]:o + v[0] + v[1]] for k, v in j['i'].items()}
def wr(p, j, d):
    I = {}; body = bytearray()
    for k in sorted(d): I[k] = [len(body), len(d[k])]; body += d[k]
    j['i'] = I; h = json.dumps(j, separators=(',', ':')).encode()
    open(p, 'wb').write(struct.pack('<I', len(h)) + h + bytes(body))
if __name__ == '__main__':
    L, sb, si, db, di = sys.argv[1:6]
    sj, sd = rd(f'{L}/{sb}.wasm'); dj, dd = rd(f'{L}/{db}.wasm')
    n = 0
    for k, v in sd.items():
        base = k.split('@')[0]
        if base[1:].rstrip('0123456789') != si or base[0] not in 'dn': continue
        nk = k[0] + di + k[1 + len(si):]; dd[nk] = v; n += 1
        if base in sj.get('m', {}): dj.setdefault('m', {})[nk.split('@')[0]] = sj['m'][base]
    wr(f'{L}/{db}.wasm', dj, dd); print(db, '+', n, 'khung', di, '<-', si)
