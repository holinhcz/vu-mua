# Xe nước ép (xưởng "ep", 2x2 ô) – ảnh cho Godot

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm.

| File | Dùng khi |
|---|---|
| `ep_i_*` | Xưởng nghỉ, nguyên cảnh (máng khô, không có mía, ly úp) |
| `ep_r_*` | Xưởng chạy, phần đứng yên: mía trong trục, bã mía, nước trong ca, ly nước mía / sinh tố xoài / cốt dừa / mía sầu riêng |
| `ep_f0..f23_*` | Phần quay: bánh đà, tay quay, 3 bánh răng ăn khớp. Chu kỳ 2,4 s cho 1 vòng, 24 khung (10 khung/s), lặp liền |
| `ep_giot.webp`, `ep_gon.webp` | Giọt nước cốt dừa và gợn trên mặt thau (trắng, Godot tô màu) cho particles |

Lúc chạy: vẽ `ep_r`, rồi đè khung `f` hiện tại (khung đè chỉ chứa phần thay đổi, nền trong suốt), rồi particles giọt cốt dừa.

`atlas.json`: khoá = tên + d/n (vd `f5d`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x2 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.

## Giọt nước cốt dừa (CPUParticles2D)

(2026-11-12: đồ trong xưởng phóng to cho dễ nhìn ở cỡ game, xe ép x1.3, giá vắt x1.1 dời ra phía trước cạnh thùng đá cho thấy giọt rơi; số dưới đây đã tính theo cỡ mới.)

Túi vải trên giá tre vắt nước cốt nhỏ giọt xuống thau nhôm. Điểm phát = `cot` [x, y] (đáy túi), mặt nước cốt = `cot_day` (chỉ dùng y, thấp hơn ~2,5 đơn vị).
- Giọt: texture `ep_giot.webp` (trắng), rộng ~0,6 đơn vị, cao ~0,9 (kéo dài thêm 60% lúc rơi). amount 5, lifetime 2,4 s,
  explosiveness 0 (1 giọt mỗi 0,48 s), initial velocity 0, gravity (0, 210), lệch ngang ±0,28.
  Giọt rơi tới mặt nước sau sqrt(2*(cot_day.y - cot.y)/210) ≈ 0,15 s: color_ramp alpha = 1 tới 0,065 rồi = 0 (tắt khi chạm nước).
- Gợn: `ep_gon.webp` (vòng tròn dẹt trắng) tại [cot.x, cot_day.y], hiện khi giọt chạm nước, rộng 0,45 → 2,9 đơn vị trong 0,45 s, alpha 0,75 → 0, màu x0,8.
- Màu ngày #fffcf2, đêm #c7bfb8.
- Nước mía từ vòi khay chảy vào ca nhôm nằm sau khung ép, bị khung che hết nên không có particles.

Đèn trên cột: ĐÈN DẦU (thủy tinh xanh chai, như các xưởng khác). Ảnh riêng của đèn: `godot/xuong/dendau/`.

Nền: cao bằng nền nhà (2.4), bo tròn 4 góc như hàng chả, mặt phẳng. Đáy nền nằm đúng mặt đất, toạ độ atlas đã tính phần nền cao.
Vật liệu sơ cấp: xe, bàn, ghế, ghế nạo dừa bằng tre (xe sơn xanh ngọc cũ, tróc lòi màu tre).

Nguồn: src/xenuocep/ep3d.py (mô hình 3D), src/xenuocep/export.py (xuất ảnh), src/xenuocep/gif.py (GIF xem thử, ráp đúng như Godot).

Muốn xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/xenuocep/export.py OUTDIR 3` (xoá OUTDIR/raw trước nếu đổi hình), ~30 phút.
GIF xem thử: `python3 src/xenuocep/gif.py godot/xuong/ep OUT [crop]`.
