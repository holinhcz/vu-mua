# pond detail textures for the native ground: the game's bm_* (all grey) packed into two RGBA pictures, plus the
# glint streak mask the game draws in code (BTX streak(): 1100 thin lens-shaped streaks, same random sequence)
import sys, numpy as np
from PIL import Image, ImageDraw
S = sys.argv[1]; src = S + '/g/img/'; out = S + '/gn/n/'
def g(k): return np.asarray(Image.open(src + 'bm_' + k + '.webp').convert('RGBA')).astype(np.float32)
co, va, bu, da, ri, ra, lo = [g(k) for k in ['co', 'vach', 'bun', 'dat', 'ria', 'rach', 'loang']]
L = lambda a: a[..., :3].mean(2)
t1 = np.stack([L(co), L(va), L(bu), L(da)], 2)
t2 = np.stack([L(ri), ri[..., 3], ra[..., 3], lo[..., 3]], 2)
Image.fromarray(np.clip(t1 + .5, 0, 255).astype(np.uint8), 'RGBA').save(out + 'pt1.webp', lossless=True, quality=100, method=6)
Image.fromarray(np.clip(t2 + .5, 0, 255).astype(np.uint8), 'RGBA').save(out + 'pt2.webp', lossless=True, quality=100, method=6)
# streaks, drawn at 4x and box-filtered down; canvas source-over alpha accumulation
N = 1024; U = 4; acc = np.zeros((N * U, N * U), np.float32)
r = 821
def rnd():
    global r
    r = (r * 16807) % 2147483647
    return r / 2147483647
for k in range(1100):
    px = rnd() * N; py = rnd() * N; Ln = 5 + rnd() ** 1.7 * 64; h = .7 + rnd() * 1.3; al = .4 + rnd() * .6
    for o in (-N, 0, N):
        pts = []
        for i in range(17):
            t = i / 16; x = px + o - Ln / 2 + Ln * t; pts.append((x, py - h * 2 * t * (1 - t)))
        for i in range(15, 0, -1):
            t = i / 16; x = px + o - Ln / 2 + Ln * t; pts.append((x, py + h * .5 * 2 * t * (1 - t)))
        xs = [p[0] for p in pts]
        if max(xs) < 0 or min(xs) > N: continue
        m = Image.new('L', (N * U, N * U), 0)
        x0 = int(max(0, min(xs) * U - 2)); x1 = int(min(N * U, max(xs) * U + 2))
        y0 = int(max(0, (py - h) * U - 2)); y1 = int(min(N * U, (py + h) * U + 2))
        if x1 <= x0 or y1 <= y0: continue
        m = Image.new('L', (x1 - x0, y1 - y0), 0)
        ImageDraw.Draw(m).polygon([(p[0] * U - x0, p[1] * U - y0) for p in pts], fill=255)
        a = np.asarray(m).astype(np.float32) / 255 * al
        sl = acc[y0:y1, x0:x1]; acc[y0:y1, x0:x1] = sl + a * (1 - sl)
st = acc.reshape(N, U, N, U).mean((1, 3))
Image.fromarray((st * 255 + .5).astype(np.uint8), 'L').save(out + 'pt3.png', optimize=True)
print('ok')
