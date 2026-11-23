# (bản 530) Bờ bên kia của Câu cá DÙNG CHUNG hình vườn: cây, hoa, bụi lấy thẳng file n/op/<tên>.webp của Nông trại (+ nền n2_co,
# dg2_dat), không chép vào gói hình câu cá nữa (bớt ~12 MB tải lần đầu).
# Hình vườn nhìn từ trên xuống có bóng tròn dưới gốc, bờ kênh nhìn ngang thì bỏ: công cụ này đọc đúng file vườn đang chạy, tính
# những đoạn điểm ảnh bóng (alpha < 120, gần đen, trong bầu dục quanh gốc, như farm_pick.unshadow) + khung cắt lề, ghi vào
# bo.json mục "op". Lúc chơi cc_scene tải file vườn, xoá đúng mấy đoạn đó (Image.fill_rect), cắt khung -> y như ảnh cũ.
# Ảnh đêm (chỉ phần đèn, ~1,6 MB) vẫn ở trong gói. Hình vườn đổi thì chạy lại công cụ này (rồi mk_ccpack).
#   python3 op_share.py [main checkout = /home/claude/vu-mua] [--rm]   (--rm: xoá ảnh đã dùng chung khỏi src/cauca/ui/img/cc/bo)
import sys, os, json
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MAIN = next((a for a in sys.argv[1:] if not a.startswith('--')), '/home/claude/vu-mua')
RM = '--rm' in sys.argv
BO = os.path.join(HERE, '..', '..', 'cauca', 'ui', 'img', 'cc', 'bo')
info = json.load(open(os.path.join(MAIN, 'info.json')))
opb, opn = info['opb'], info.get('opn', {})
bo = json.load(open(os.path.join(BO, 'bo.json')))
items = bo['items']

# tên món câu cá (xoai_dx01) -> tên khung vườn (caytrai-xoai-dx01)
by = {}
for k in opb:
    p = k.split('-', 1)
    if len(p) == 2:
        by[p[1].replace('-', '_')] = k

def load(nm):
    return np.asarray(Image.open(os.path.join(MAIN, 'n', 'op', nm + '.webp')).convert('RGBA'))

def shadow(a, ax, ay, rx, ry):
    al = a[..., 3].astype(np.int32)
    lum = a[..., :3].astype(np.int32).max(-1)
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    near = ((xx - ax) / rx) ** 2 + ((yy - ay) / ry) ** 2 < 1.0
    return (al < 120) & (lum < 48) & near & (al > 0)

def runs(m):   # [y, x0, dài, ...]
    out = []
    for y in range(m.shape[0]):
        r = m[y]
        if not r.any():
            continue
        d = np.diff(np.concatenate([[0], r.astype(np.int8), [0]]))
        s, e = np.nonzero(d == 1)[0], np.nonzero(d == -1)[0]
        for a, b in zip(s, e):
            out += [int(y), int(a), int(b - a)]
    return out

OP = {}
shared = []
for nm, it in items.items():
    k = by.get(nm)
    if k is None or 'gw' not in it:
        continue
    b = opb[k]
    d = load(k)
    ppu = d.shape[1] / float(b[2])
    if abs(ppu - float(it['ppu'])) > 0.15:
        print('bỏ qua (khác cỡ)', nm, ppu)
        continue
    ax, ay = -float(b[0]) * ppu, -float(b[1]) * ppu
    rx, ry = float(it['gw']) * ppu * .62, float(it['gw']) * ppu * .33
    md = shadow(d, ax, ay, rx, ry)
    d2 = d.copy(); d2[md, 3] = 0
    al = d2[..., 3] > 0
    H, W = al.shape
    ys_, xs_ = np.nonzero(al)
    x0, x1, y0, y1 = max(0, xs_.min() - 2), min(W, xs_.max() + 3), max(0, ys_.min() - 2), min(H, ys_.max() + 3)
    cw, chh = int(x1 - x0), int(y1 - y0)
    OP[nm + '_d'] = {'f': 'n/op/' + k + '.webp', 'r': runs(md), 'cr': [int(x0), int(y0), cw, chh]}
    # ảnh đêm câu cá = CHỈ PHẦN ĐÈN (den.py, nhẹ, khác ảnh đêm vườn) -> vẫn nằm trong gói, chỉ dời về khung cắt mới
    fn = os.path.join(BO, nm + '_n.webp')
    if os.path.exists(fn):
        n = np.asarray(Image.open(fn).convert('RGBA'))
        ox, oy = int(round((ax - x0) - float(it['ax']))), int(round((ay - y0) - float(it['ay'])))
        o = np.zeros((chh, cw, 4), np.uint8)
        nh, nw = n.shape[:2]
        sx, sy, dx, dy = max(0, -ox), max(0, -oy), max(0, ox), max(0, oy)
        w_, h_ = min(nw - sx, cw - dx), min(nh - sy, chh - dy)
        if w_ > 0 and h_ > 0:
            o[dy:dy + h_, dx:dx + w_] = n[sy:sy + h_, sx:sx + w_]
        if (ox, oy, nw, nh) != (0, 0, cw, chh):
            Image.fromarray(o, 'RGBA').save(fn, lossless=True, quality=100, method=4)
    # chỗ gốc mới trong khung cắt; tỉ lệ đặt (place p[4] = k / ppu) đổi theo ppu thật
    f = float(it['ppu']) / ppu
    it.update(w=cw, h=chh, ax=round(ax - x0, 1), ay=round(ay - y0, 1), ppu=round(ppu, 4))
    for p in bo['place']:
        if p[1] == nm:
            p[4] = round(float(p[4]) * f, 4)
    shared.append(nm)
for g in ['n2_co', 'dg2_dat']:
    if os.path.exists(os.path.join(MAIN, 'n', g + '.webp')):
        OP[g] = {'f': 'n/' + g + '.webp'}
        shared.append(g)
bo['op'] = OP
json.dump(bo, open(os.path.join(BO, 'bo.json'), 'w'), ensure_ascii=False, separators=(',', ':'))
by_sz = 0
for nm in shared:
    for s in (['_d'] if nm not in ('n2_co', 'dg2_dat') else ['']):
        p = os.path.join(BO, nm + s + '.webp')
        if os.path.exists(p):
            by_sz += os.path.getsize(p)
            if RM:
                os.remove(p)
print('dùng chung', len(shared), 'món,', by_sz // 1024, 'KB', '(đã xoá)' if RM else '(chưa xoá, thêm --rm)')
