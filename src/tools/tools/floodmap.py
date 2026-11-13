# Flood map for the Godot river (nước nổi), on the river map's grid (w/riv.json, mapA.png): RGBA8
#  R = signed distance to the flood's outer edge (song.json FX = the game's fext beyond each bank, only where the bank is
#      "on"), roads cut out: 128 + 4 * world px, > 128 inside the flood
#  G = how far out across the flood band (0 at the bank .. 255 at the flood's edge), 0 inside the river
#  B = signed distance to the nearest road tile (dry): 128 + 4 * world px, > 128 off the roads
# usage: python3 floodmap.py song.json riv.json road.png info.json out.png
import sys, json
import numpy as np
from PIL import Image
T = json.load(open(sys.argv[1])); R = json.load(open(sys.argv[2])); I = json.load(open(sys.argv[4]))
RD = np.array(Image.open(sys.argv[3]))[..., 0]
ki, hi = I["ki"], I["hi"]; N = I["N"]
A = Image.open(sys.argv[2].replace("riv.json", "mapA.png")); W, H = A.size
X0, ST, NJ = T["X0"], T["ST"], T["NJ"]
wx = R["x"] + (np.arange(W) + .5) * R["w"] / W
wy = R["y"] + (np.arange(H) + .5) * R["h"] / H
WX, WY = np.meshgrid(wx, wy)
u = (WX - ki) / 32.0; v = (WY - hi) / 16.0
gx = (u + v) * .5; gy = (v - u) * .5
PX = 35.78   # world px per grid unit across a bank (|(-32,16)|)
def lerp(arr, x):
    a = np.asarray(arr, dtype=np.float64); uu = (x - X0) / ST
    j = np.clip(np.floor(uu).astype(int), 0, NJ - 2); f = np.clip(uu - j, 0, 1)
    return a[j] * (1 - f) + a[j + 1] * f
def near(arr, x):
    a = np.asarray(arr, dtype=np.float64); j = np.clip(np.rint((x - X0) / ST).astype(int), 0, NJ - 1); return a[j]
sd = np.full(gx.shape, -1e9); uu = np.zeros(gx.shape)
for arm in T["arm"]:
    xa, xb = max(arm["xa"], X0), min(arm["xb"], X0 + (NJ - 1) * ST)
    inr = (gx >= xa) & (gx <= xb)
    c = lerp(arm["c"], gx); k = lerp(arm["k"], gx); s = (gy - c) / k
    for side in (0, 1):   # 0: + side (nb false), 1: - side
        E = near(arm["E"][side], gx); FX = lerp(arm["FX"][side], gx); on = near(arm["BP"][side], gx) > .02
        o = s if side == 0 else -s
        d = (E + FX - o) * k * PX   # > 0 inside
        ok = inr & on & (o > -E - 1e-6)
        d2 = np.where(ok, d, -1e9)
        # the river itself between the banks counts as inside too
        sd = np.maximum(sd, d2)
        uband = np.clip((o - E) / np.maximum(FX, 1e-3), 0, 1)
        uu = np.where(ok & (d2 >= sd - 1e-9) & (o > E), uband, uu)
# roads: signed distance to the nearest road tile edge (4-neighbour edges only)
tu = np.floor(gx).astype(int); tv = np.floor(gy).astype(int); fu = gx - tu; fv = gy - tv
def road(tx, ty):
    i = tx - N[0]; j = ty - N[2]
    okk = (i >= 0) & (j >= 0) & (i < RD.shape[1]) & (j < RD.shape[0])
    out = np.zeros(tx.shape, bool)
    out[okk] = RD[j[okk], i[okk]] > 0
    return out
K = 28.62   # world px per tile unit across a tile edge
me = road(tu, tv)
big = 1e3
dist = np.full(gx.shape, big)
for (dx, dy, f) in ((1, 0, 1 - fu), (-1, 0, fu), (0, 1, 1 - fv), (0, -1, fv)):
    nb = road(tu + dx, tv + dy)
    dist = np.where(nb != me, np.minimum(dist, f * K), dist)
rsd = np.where(me, -dist, dist)   # > 0 off the roads
fin = np.minimum(sd, rsd)
enc = lambda d: np.clip(np.rint(128 + 4 * d), 0, 255).astype(np.uint8)
out = np.dstack([enc(fin), np.rint(uu * 255).astype(np.uint8), enc(rsd), np.full(gx.shape, 255, np.uint8)])
Image.fromarray(out, "RGBA").save(sys.argv[5], optimize=True)
print("flood map", W, H, "inside px", int((fin > 0).sum()), "road px", int(me.sum()))
