# fallen leaves + footpaths for the native ground (web NEN2 v777 leaves() / v787 tracks()), from the game's own data
# (g/pnz.js on the v997 page: every leaf-dropping tree with each leaf's place, hash and flip; every footpath tile list).
#   n/lf.wasm   leaves, binary: 'LF1' u8 ver, u32 trees; per tree u8 kind, u8 n[4] (count per season, web cnt()), u16 leaves;
#               per leaf f32 x, f32 y (world), u8 j (order: a season shows the leaves with j < n), u8 piece (bits 0-3 =
#               floor(h4*8), 4-6 = floor(h4*4), 7 = mirrored)
#   n/ls<se>.wasm  the season's leaf pieces, each its own lossless webp: u32 json length, json [[w,h,ax,ay,off,len] per
#               kind in ORDER, 8 each], then the webp bytes (singles.py at 8 px/unit = its own paint size, nothing shrunk)
#   n/tr.json   footpaths as world polylines (web quadratic curves sampled), the end on a road cut back to the tile edge
# usage: python3 lfprep.py nz5.json ls8/out SITE/n
import json, sys, struct, io
from PIL import Image
from lotprep_me import Me
D = json.load(open(sys.argv[1])); LS = sys.argv[2]; OUT = sys.argv[3]
KINDS = ["da", "xoai", "mit", "dieu", "tram", "tre", "chuoi", "dua", "cau", "dudu", "dambut", "bonggiay", "dao", "mai", "caosu",
         "me", "nhan", "chomchom", "buoi", "cam", "mangcut", "saurieng", "man", "thanhlong"]
ki, hi = 4268.0, 968.0
def en(s, h): return ki + (s - h) * 32.0
def nn(s, h): return hi + (s + h) * 16.0
# ---- leaves
b = bytearray(b'LF1'); b.append(1); b += struct.pack('<I', len(D['lt']))
nl = 0
for t in D['lt']:
    b.append(KINDS.index(t['k'])); b += bytes(min(255, x) for x in t['n']); b += struct.pack('<H', len(t['L']))
    for j, x, y, h4, fl in t['L']:
        pc = min(7, int(h4 * 8)) | (min(3, int(h4 * 4)) << 4) | (128 if fl else 0)
        b += struct.pack('<ffBB', x, y, j, pc); nl += 1
open(OUT + '/lf.wasm', 'wb').write(bytes(b))
# ---- leaf pieces per season
R = json.load(open(LS + '/ls.json')); sheet = Image.open(LS + '/ls.png').convert('RGBA')
for se in range(4):
    idx = []; data = bytearray()
    for k in KINDS:
        for (x, y, w, h, ax, ay) in R[se][k]:
            bio = io.BytesIO(); sheet.crop((x, y, x + w, y + h)).save(bio, 'WEBP', lossless=True, quality=100, method=6, exact=False)
            v = bio.getvalue(); idx.append([w, h, ax, ay, len(data), len(v)]); data += v
    j = json.dumps(idx, separators=(',', ':')).encode()
    open(OUT + '/ls%d.wasm' % se, 'wb').write(struct.pack('<I', len(j)) + j + bytes(data))
# ---- footpaths
road = Image.open(OUT + '/road.png').convert('RGBA'); RW, RH = road.size; F0, VO = -89, -90
def onroad(s, h):
    x, y = s - F0, h - VO
    return 0 <= x < RW and 0 <= y < RH and road.getpixel((x, y))[0] > 0
TRK = []
for tr in D['tr']:
    q = tr['p']
    pts = []
    for a, (s, h) in enumerate(q):
        x, y = en(s + .5, h + .5), nn(s + .5, h + .5)
        if 0 < a < len(q) - 1:
            x += (Me(s * 3 + 1, h * 5 + 2) - .5) * 14; y += (Me(s * 7 + 3, h * 2 + 9) - .5) * 7
        pts.append((x, y))
    # web: moveTo p0, quadraticCurveTo(p[a], mid(p[a], p[a+1])) for the inner points, lineTo the last
    P = [pts[0]]; cur = pts[0]
    for a in range(1, len(pts) - 1):
        c = pts[a]; e = ((pts[a][0] + pts[a + 1][0]) / 2, (pts[a][1] + pts[a + 1][1]) / 2)
        for k in range(1, 9):
            t = k / 8
            P.append(((1 - t) ** 2 * cur[0] + 2 * (1 - t) * t * c[0] + t * t * e[0], (1 - t) ** 2 * cur[1] + 2 * (1 - t) * t * c[1] + t * t * e[1]))
        cur = e
    P.append(pts[-1])
    # the road is drawn after the tracks in the web (it covers the track's end); here the track stops at the road's edge
    def cut(P, p0, p1):   # drop what lies inside the road tile p0, start at the tile edge (half way to p1)
        m = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2); r = ((m[0] - p0[0]) ** 2 + (m[1] - p0[1]) ** 2) ** .5
        while len(P) > 2 and ((P[1][0] - p0[0]) ** 2 + (P[1][1] - p0[1]) ** 2) ** .5 < r: P.pop(0)
        P[0] = m; return P
    if len(pts) > 1 and onroad(*q[-1]): P = cut(P[::-1], pts[-1], pts[-2])[::-1]
    if len(pts) > 1 and onroad(*q[0]): P = cut(P, pts[0], pts[1])
    TRK.append([round(v, 2) for p in P for v in p])
json.dump(TRK, open(OUT + '/tr.json', 'w'), separators=(',', ':'))
print('trees', len(D['lt']), 'leaves', nl, 'lf bytes', len(b), 'tracks', len(TRK))
