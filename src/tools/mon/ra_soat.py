# rà soát món chế biến: python3 ra_soat.py <thư mục src/godot>
import json, os, re, sys, hashlib
from collections import defaultdict
G = sys.argv[1] if len(sys.argv) > 1 else '.'
def J(p): return json.load(open(f'{G}/data/{p}.json'))
c = J('che_bien/cong_thuc'); v = J('che_bien/vat_pham'); x = J('che_bien/xuong'); cr = J('nong_trai/cay_trong')
mo = J('nong_trai/cay_mo_cap'); ei = J('nong_trai/cay_an_trai'); an = J('vat_nuoi/vat_nuoi'); cm = J('vat_nuoi/chuong_mo_cap')
issues = defaultdict(list)
name = lambda i: (v.get(i) or cr.get(i) or {}).get('name', i)
def sell(i): return v[i]['sell'] if i in v else cr[i]['sell']
# cấp có được nguyên liệu gốc
LV = {}
for k in cr: LV[k] = mo.get(k, cr[k].get('lv', 1))
for f, e in ei.items(): LV[e['p']] = min(LV.get(e['p'], 999), e['lv'])
for a, e in an.items():
    for m in [e.get('make'), e.get('make2')]:
        if m: LV[m] = min(LV.get(m, 999), cm.get(a, 1))
for k, e in v.items():
    if e.get('from') in ('fish', 'bun', 'song', 'ao', 'bao', 'ong', 'dog', 'nghe', 'vit') and k not in LV: LV[k] = 1   # câu/bắt/khác: coi như sẵn
# xưởng <-> công thức
for w, e in x.items():
    for r in e['rec']:
        if r not in c: issues['Xưởng có món không có công thức'].append(f"{e['name']}: {r}")
        elif c[r]['w'] != w: issues['Món nằm sai xưởng'].append(f"{name(r)}: rec ở {e['name']}, công thức ghi {c[r]['w']}")
    g = [a for a, b in e.get('nhom', [])]
    for r in e['rec']:
        if r in c and g and c[r].get('nhom', g[0]) not in g: issues['Nhóm tab sai'].append(f"{e['name']}: {name(r)} nhom={c[r].get('nhom')}")
    if len(e['rec']) != len(set(e['rec'])): issues['Trùng món trong xưởng'].append(e['name'])
inrec = {r for e in x.values() for r in e['rec']}
for k, r in c.items():
    if r['w'] not in x: issues['Công thức của xưởng không tồn tại'].append(f'{k} -> {r["w"]}')
    elif k not in inrec: issues['Công thức không nằm trong danh sách xưởng (không làm được)'].append(f"{name(k)} ({x[r['w']]['name']})")
    if k not in v: issues['Công thức không có vật phẩm'].append(k)
    for i, q in r['in']:
        if i not in v and i not in cr: issues['Nguyên liệu không tồn tại'].append(f'{name(k)}: {i}')
        elif i == k: issues['Món tự dùng chính nó'].append(k)
# cấp làm được (đệ quy)
memo = {}
def lv(i, st=()):
    if i in memo: return memo[i]
    if i in st: issues['Vòng lặp nguyên liệu'].append(' -> '.join(st + (i,))); return 999
    if i in c and i in inrec:
        r = c[i]; L = max([x[r['w']]['lv']] + [lv(a, st + (i,)) for a, q in r['in']])
    elif i in LV: L = LV[i]
    else: L = 999
    memo[i] = L; return L
for k, r in c.items():
    if k not in inrec: continue
    L = lv(k); W = x[r['w']]['lv']
    if L >= 999: issues['Món không làm được (thiếu nguồn nguyên liệu)'].append(f"{name(k)}: " + ', '.join(name(a) for a, q in r['in'] if lv(a) >= 999))
    elif L > W: issues[f'Xưởng mở trước nguyên liệu (món phải chờ tới cấp cao hơn)'].append(f"{name(k)} ({x[r['w']]['name']} cấp {W}) -> làm được từ cấp {L}: " + ', '.join(f'{name(a)} cấp {lv(a)}' for a, q in r['in'] if lv(a) > W))
# giá theo công thức
for k, r in c.items():
    if k in v and k in inrec:
        f = sum(sell(i) * q for i, q in r['in']) + r['time'] // 60
        if v[k]['sell'] != f: issues['Giá lệch công thức (tổng nguyên liệu + phút)'].append(f"{name(k)}: {v[k]['sell']} (công thức {f})")
# vật phẩm chế biến không còn công thức (đồ bỏ)
WS = set(x)
for k, e in v.items():
    if e.get('from') in WS and (k not in c or k not in inrec): issues['Vật phẩm đã bỏ (còn để bán)'].append(f"{e['name']} ({k})")
# hình
KH = f'{G}/ui/svg/kh/'
hs = defaultdict(list)
for k in list(c) + [i for r in c.values() for i, q in r['in']]:
    p = KH + k + '.svg'
    if not os.path.exists(p): issues['Thiếu icon'].append(name(k)); continue
    s = open(p).read()
    if '<image' not in s: issues['Icon vẽ code (chưa có hình)'].append(name(k))
    hs[hashlib.md5(s.encode()).hexdigest()].append(k)
for h, ks in hs.items():
    ks = sorted(set(ks))
    if len(ks) > 1: issues['Icon giống hệt nhau (hình tạm)'].append(' = '.join(name(k) for k in ks))
# chỗ khác nhắc món
dead = {k for k, e in v.items() if e.get('from') in WS and (k not in c or k not in inrec)}
def walk(o, path, f):
    if isinstance(o, str):
        if o in dead: issues['Data khác còn nhắc món đã bỏ'].append(f'{f}: {o}')
    elif isinstance(o, dict):
        for a, b in o.items():
            if a in dead: issues['Data khác còn nhắc món đã bỏ'].append(f'{f}: {a}')
            walk(b, path, f)
    elif isinstance(o, list):
        for b in o: walk(b, path, f)
for root, ds, fs in os.walk(f'{G}/data'):
    for fn in fs:
        p = os.path.join(root, fn); rel = os.path.relpath(p, f'{G}/data')
        if rel.startswith('che_bien/vat_pham') or rel.startswith('che_bien/thu_tu_hang') or rel.startswith('che_bien/cong_thuc_thoi_gian_goc') or not fn.endswith('.json'): continue
        walk(json.load(open(p)), '', rel)
for fn in os.listdir(f'{G}/logic'):
    if fn.endswith('.gd'):
        s = open(f'{G}/logic/{fn}').read()
        for d in dead:
            if re.search(r'"' + d + r'"', s): issues['Code còn nhắc món đã bỏ'].append(f'{fn}: {d}')
for k, l in issues.items():
    print(f'\n## {k} ({len(l)})')
    for a in sorted(set(l)): print(' -', a)
