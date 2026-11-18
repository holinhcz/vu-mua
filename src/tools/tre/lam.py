# Vẽ khung tre chung (bản 294): cạnh (lặp) + góc cong, 9 mảnh, cùng một mặt cắt cây tre nên nối liền.
# Đơn vị css: T dày tre, S bóng đổ vào trong, R bo góc ngoài, L dài một đốt (có một mắt tre giữa đốt). P điểm ảnh / css px.
import math, sys
from PIL import Image
import numpy as np
T, S, R, L, P, SS = 7.0, 3.0, 16.0, 48.0, 6, 3   # SS: vẽ phóng SS lần rồi thu nhỏ cho mép mượt
OUT = sys.argv[1]
STOPS = [(0.00, (96, 68, 22)), (0.10, (150, 116, 50)), (0.22, (196, 164, 96)), (0.33, (226, 204, 146)),
         (0.42, (214, 188, 124)), (0.62, (182, 148, 82)), (0.84, (146, 112, 48)), (1.00, (98, 70, 22))]
def prof(f):  # màu theo vị trí trong bề dày (0 = mép ngoài, 1 = mép trong)
    f = min(max(f, 0.0), 1.0)
    for (a, ca), (b, cb) in zip(STOPS, STOPS[1:]):
        if f <= b:
            t = (f - a) / (b - a)
            return [ca[i] + (cb[i] - ca[i]) * t for i in range(3)]
    return list(STOPS[-1][1])
import random
random.seed(7)
FIB = [random.uniform(-1, 1) for _ in range(400)]          # thớ dọc: mỗi lớp trong bề dày một độ sáng (không đổi dọc thân)
SPK = {}                                                      # đốm li ti trong một đốt (đốt nào cũng y nhau: nối liền)
for _ in range(60):
    SPK[(random.randrange(int(L * 4)), random.randrange(int(T * 4)))] = random.uniform(0.86, 0.95)
def fib(d):
    i = d * 40.0
    a = int(i) % 399
    t = i - int(i)
    return FIB[a] * (1 - t) + FIB[a + 1] * t
def px(d, along, node):  # d: css px từ mép ngoài vào trong; along: css px dọc thân (lặp chu kỳ L); trả RGBA
    if d < 0:
        return (0, 0, 0, 0)
    if d < T:
        c = prof(d / T)
        # thớ tre dọc thân: sọc mảnh theo bề dày (không đổi dọc thân nên nối liền)
        c = [v * (1.0 + 0.05 * fib(d)) for v in c]
        if node:
            x = (along % L) - L / 2
            # thân hơi tối dần về phía mắt (chỗ phồng), sáng ở giữa đốt
            c = [v * (1.0 - 0.10 * math.exp(-(x / 4.0) ** 2) + 0.03 * math.cos(2 * math.pi * along / L)) for v in c]
            k = SPK.get((int((along % L) * 4), int(d * 4)))
            if k:
                c = [v * k for v in c]
            # mắt tre: rãnh tối, gờ sáng, rãnh tối mảnh
            if -1.4 <= x < -0.1:
                c = [v * (0.58 + 0.12 * abs(x + 0.75)) for v in c]
            elif -0.1 <= x < 1.1:
                c = [min(255, v * 1.16 + 14) for v in c]
            elif 1.1 <= x < 1.8:
                c = [v * 0.78 for v in c]
        return (*[int(max(0, min(255, v))) for v in c], 255)
    if d < T + S:  # bóng đổ vào lòng bảng
        a = (1.0 - (d - T) / S) ** 2 * 0.30
        return (60, 40, 10, int(a * 255))
    return (0, 0, 0, 0)
def render(w, h, fn):
    W, H = int(w * P * SS), int(h * P * SS)
    a = np.zeros((H, W, 4), np.float64)
    for j in range(H):
        for i in range(W):
            a[j, i] = fn((i + 0.5) / (P * SS), (j + 0.5) / (P * SS))
    # thu nhỏ có tiền nhân alpha (mép không viền sáng / tối)
    al = a[..., 3:4] / 255.0
    pre = np.concatenate([a[..., :3] * al, al * 255.0], -1)
    pre = pre.reshape(int(h * P), SS, int(w * P), SS, 4).mean((1, 3))
    out = pre.copy()
    m = pre[..., 3:4] > 0
    out[..., :3] = np.where(m, pre[..., :3] / np.maximum(pre[..., 3:4] / 255.0, 1e-6), 0)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
# cạnh trên: mép ngoài ở trên, dài 1 đốt
top = render(L, T + S, lambda x, y: px(y, x, True))
# góc trên trái: tâm cung ở (R, R), khoảng cách từ mép ngoài = R - r
def corner(x, y):
    r = math.hypot(R - x, R - y)
    if x >= R or y >= R:
        return (0, 0, 0, 0)
    return px(R - r, 0.0, False)
tl = render(R, R, corner)
top.save(OUT + "/canh_tren.png")
top.transpose(Image.FLIP_TOP_BOTTOM).save(OUT + "/canh_duoi.png")
top.transpose(Image.TRANSPOSE).save(OUT + "/canh_trai.png")
top.transpose(Image.TRANSPOSE).transpose(Image.FLIP_LEFT_RIGHT).save(OUT + "/canh_phai.png")
tl.save(OUT + "/goc_tt.png")
tl.transpose(Image.FLIP_LEFT_RIGHT).save(OUT + "/goc_tp.png")
tl.transpose(Image.FLIP_TOP_BOTTOM).save(OUT + "/goc_dt.png")
tl.transpose(Image.ROTATE_180).save(OUT + "/goc_dp.png")
print("ok", top.size, tl.size)
