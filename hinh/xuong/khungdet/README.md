# Khung dệt vải (xưởng "det", 2x2 ô) – ảnh cho Godot

Khung cửi dệt vải miền Tây dưới chái lá (Link 2026-11-12: xưởng dệt làm vải, khăn rằn, sợi bông, sợi len, vải nhuộm chàm, áo bà ba, không phải chiếu).
Khung tre: trục sợi phía sau, 32 sợi dọc trắng, 2 go nhấc treo trên đòn ngang + 2 bàn đạp, go đập (lược) treo từ trục trên, con thoi chạy trên thanh go đập,
tấm vải dệt xong cuộn vào trục vải phía trước, ghế ngồi dệt. Phía trước: sào tre phơi khăn rằn đen trắng, áo bà ba hồng, tấm vải vàng nghệ;
kệ tre 2 cuộn vải (trắng viền đỏ, đỏ điều); lu nhuộm chàm có tấm vải chàm vắt miệng lu; thúng sợi bông + 3 cuộn len (đỏ, vàng, xanh lá).
Đồ đạc đã phóng to cho dễ nhìn ở cỡ game (2026-11-12).

Mỗi ảnh là 1 file riêng, 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm (đêm chỉ có đèn dầu trên cột sáng, giống các công trình khác).

| File | Dùng khi |
|---|---|
| `khungdet_i_*` | Xưởng nghỉ, nguyên cảnh (miệng sợi khép, con thoi nằm trên tấm vải) |
| `khungdet_r_*` | Xưởng chạy, phần đứng yên (khung, sợi dọc khép, go nhấc + go đập ở vị trí nghỉ, không có thoi) |
| `khungdet_f0..f23_*` | Khung chạy: mỗi chu kỳ dệt 2 đường sợi ngang. Mỗi đường: 2 go nhấc đổi miệng sợi (1 go lên, 1 go xuống, bàn đạp theo), con thoi chạy ngang qua miệng sợi kéo sợi ngang, go đập đập sợi vô mép vải rồi lùi lại; đường thứ 2 thoi chạy ngược lại. Chu kỳ 2,4 s, 24 khung (10 khung/s) |

Lúc chạy: vẽ `khungdet_r`, rồi đè khung `f` hiện tại (khung đè chỉ chứa phần thay đổi, nền trong suốt).
Không có hiệu ứng riêng (không khói, không lửa).

Nền: từ 2026-11-11 15:09 nền y hệt hàng chả: cao bằng nền nhà (2.4), bo tròn 4 góc như nền nhà kho, thành đất nện chân hơi loe. Đáy nền nằm đúng mặt đất, mọi toạ độ trong atlas đã tính phần nền cao này rồi, không cần cộng gì thêm.

`atlas.json`: khoá = tên + d/n (vd `f5d`, `id`, `rn`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x2 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.

Nguồn: src/khungdet/khungdet3d.py (mô hình 3D, bản chiếu cũ: khungdet3d_v4_chieu.py), src/khungdet/export.py (xuất ảnh), src/khungdet/gif.py (GIF xem thử).

Muốn xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/khungdet/export.py OUTDIR OUTDIR/atlas.json 3`
(3 việc song song; cần `pip install numba pycairo`).

Đèn trên cột: cây đèn dầu xanh mảnh chai (giống lò bánh mì, lò bánh quê, lò nướng, giàn phơi, hàng chả). Ngày tắt, đêm thắp.
