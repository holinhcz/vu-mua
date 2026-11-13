# Ruộng muối (xưởng "ruong", 3x3 ô) – ảnh cho Godot

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm (đèn dầu treo cột trước của chòi thắp, độ sáng đêm theo chuẩn kho).

Game: muối hột (`muoi_hot`).

KHÔNG có nền: ruộng nằm sát mặt đất, bờ đất bao quanh và chia ô (Link 16:12).
Bố cục: hồ chứa nước biển phía sau, chòi muối ở góc phải, 3 ô phía trước theo vòng làm muối:
ô trái nước mới bơm vô, ô giữa nước đang kết tinh muối, ô trước (góc gần người xem nhất) muối đã cào thành 3 đụn.

| File | Dùng khi |
|---|---|
| `ruongmuoi_i_*` | Ruộng nghỉ, nguyên cảnh: 3 ô chỉ có nước, cối xay gió đứng yên, máng khô, cống đóng, thúng trống úp chồng, cào dựng ở cột chòi |
| `ruongmuoi_r_*` | Ruộng chạy, ảnh nền: ô giữa đang kết tinh, ô trước muối + 3 đụn + cây cào, gánh 2 thúng muối trong chòi, cống mở, máng có nước. Ảnh này KHÔNG có cánh quạt (cánh nằm trong khung `f`) |
| `ruongmuoi_f0..f11_*` | Khung chạy: chỉ chứa phần nhúc nhích (4 cánh quạt quay + tay quay, cần bơm), còn lại trong suốt. 12 khung, mỗi khung 0,1 s, 1 vòng = cánh quay 1/4 vòng (cánh 4 cái nên lặp liền không thấy giật) |
| `ruongmuoi_nuoc.webp` | Giọt nước (trắng, 64x64). Godot nhân màu. KHÔNG vẽ sẵn trong khung |

**Thứ tự vẽ khi chạy:** `ruongmuoi_r` → khung `f` hiện tại → nước chảy từ máng.
Lúc nghỉ: chỉ vẽ `ruongmuoi_i`, tắt hiệu ứng nước.

Muốn muối "lớn dần" theo tiến độ thì vẽ `ruongmuoi_i` dưới cùng rồi vẽ `ruongmuoi_r` + khung `f` lên với alpha = tiến độ
(nếu muốn). Không bắt buộc.

`atlas.json`: khoá = tên + d/n (vd `f5d`, `id`, `rn`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 3x3 ô
(tâm = điểm giữa của hình thoi 3x3). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.
`pxu` = 9, `nf` = 12. Điểm, cùng hệ toạ độ:
- `nuoc`: miệng máng tre đổ nước vô ô trái ([x, y])
- `quat`: tâm cánh quạt ([x, y]) (nếu muốn thêm gì quanh cánh)

## Nước chảy từ máng (ở `nuoc`, chỉ bật khi ruộng chạy)
CPUParticles2D đặt ở tâm nền, `emission_shape = POINT` tại `nuoc`, vẽ trên khung `f`, không ăn ánh sáng, local_coords = false:
- texture `ruongmuoi_nuoc.webp`, amount 30, lifetime 0.4 s, preprocess 0.4 s, randomness 0.25
- direction (-8, 2) (chảy xuống phía ô trái), spread 14°, initial velocity 8.25 đơn vị/s (±25%), gravity (0, 45)
- scale: 1/9 nhân đường cong 0.38 → 0.22 theo tuổi hạt
- color ramp alpha: 0.9 giữ gần hết đời, tắt nhanh ở cuối (0 → 0.9 · 0.6 → 0.7 · 1 → 0)
- màu nhân: ngày #9fd3d6, đêm #5f8c96

GIF xem thử vẽ đúng các số trên, từ đúng các file trong thư mục này: xem/cong-trinh/ruong-muoi-chay-gan-{d,n}.gif (cận cối gió),
xem/cong-trinh/ruong-muoi-chay-ca-canh-{d,n}.gif (cả ruộng). Trình giả lập: src/ruongmuoi/gif.py.

Vật liệu sơ cấp: bờ đất, tre (cối gió, máng, cống, cào, đòn gánh), tràm (cột chòi), lá (mái chòi, thấp sau cao trước), bao bố. Nước = màu ao trong game.

Nguồn: src/ruongmuoi/ruong3d.py (mô hình 3D; RM_STATE=run|idle, RM_MOV=all|none, RM_PH 0..1 = góc cánh quạt),
src/ruongmuoi/export.py (xuất ảnh + texture giọt nước), src/ruongmuoi/gif.py (GIF xem thử).
(src/ruongmuoi/ruongmuoi3d.py là bản cũ, chỉ còn để cối xay + vật dụng dùng chung hàm, KHÔNG dùng để xuất.)
Muốn xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/ruongmuoi/export.py OUTDIR OUTDIR/atlas.json 2`
(tối đa 2 việc song song). Đổi hình khối thì xoá OUTDIR/raw trước khi xuất lại.
