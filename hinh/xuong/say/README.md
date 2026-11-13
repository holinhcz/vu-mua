# Giàn phơi (xưởng "say", 2x2 ô) – ảnh cho Godot
Đồ đạc đã phóng to cho dễ nhìn ở cỡ game (Link 2026-11-12): giàn nong x1.2, sào lạp xưởng + khô cá dời ra góc trước, mấy món còn lại x1.1 đến x1.2. Không có hiệu ứng hạt nên không có số nào phải đổi.

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm (đèn dầu trên cột thắp, độ sáng đêm theo chuẩn kho).

| File | Dùng khi |
|---|---|
| `say_i_*` | Xưởng nghỉ, nguyên cảnh: nong chồng dưới chái, giàn tre với sào trống, vỉ bánh tráng không có bánh |
| `say_r_*` | Xưởng chạy, nguyên cảnh ở tư thế đứng yên: chuối ép, xoài sấy, mít sấy, tôm khô dưới lưới trên giàn; 3 chùm lạp xưởng + 2 khô cá lóc trên sào; bánh tráng trên 3 vỉ; bàn ép chuối dưới chái |
| `say_f0..f23_*` | Khung chạy: chỉ chứa phần nhúc nhích (lạp xưởng, khô cá đung đưa trong gió, lưới trên nong tôm phập phồng), còn lại trong suốt. Chu kỳ 2,4 s, 24 khung (10 khung/s), lặp liền |

Lúc chạy: vẽ `say_r`, rồi đè khung `f` hiện tại lên trên. Xưởng này không có khói, không có lửa, nên không có hiệu ứng hạt.

Nền: từ 2026-11-11 15:09 nền y hệt hàng chả: cao bằng nền nhà (2.4), bo tròn 4 góc như nền nhà kho, thành đất nện chân hơi loe. Đáy nền nằm đúng mặt đất, mọi toạ độ trong atlas đã tính phần nền cao này rồi, không cần cộng gì thêm.

`atlas.json`: khoá = tên + d/n (vd `f5d`, `id`, `rn`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x2 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.

Đèn trên cột: cây đèn dầu xanh mảnh chai (giống lò bánh mì, lò bánh quê, lò nướng), ngày tắt, đêm thắp.

GIF xem thử: xem/cong-trinh/gian-phoi-gio.gif (zoom sào phơi), xem/cong-trinh/gian-phoi-gio-ca-canh.gif.

Nguồn: src/say/say3d.py (mô hình 3D; SA_STATE=run, SA_MOV=all|none, SA_PH 0..1 = pha gió), src/say/export.py (xuất ảnh).
Muốn xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/say/export.py OUTDIR OUTDIR/atlas.json 3`
(tối đa 3 việc song song). Đổi hình khối thì xoá OUTDIR/raw trước khi xuất lại.
