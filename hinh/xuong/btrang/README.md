# Lò bánh tráng (xưởng "btrang", 2x2 ô) – ảnh cho Godot

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm (đèn dầu trên cột thắp, độ sáng đêm theo chuẩn kho).

Game: bánh tráng (2 bột gạo), bánh tráng mè (bột gạo + dừa + đường, tức bánh tráng dừa mè), bánh tráng trộn (bánh tráng phơi + trứng muối + tôm khô + ớt).

| File | Dùng khi |
|---|---|
| `btrang_i_*` | Xưởng nghỉ, nguyên cảnh: lò đắp nguội, nắp nón đậy, vỉ phơi trống, mẹt trống, thau còn chút bột |
| `btrang_r_*` | Xưởng chạy, ảnh nền: than trong miệng lò (KHÔNG có ngọn lửa), lớp bột trên vải, vỉ phơi bánh tráng + bánh tráng dừa mè, 2 chồng bánh tráng buộc lạt, mẹt bánh tráng trộn, hũ sa tế. Ảnh này KHÔNG có cần tre + nắp nón, 2 thứ đó nằm trong khung `f` |
| `btrang_f0..f31_*` | Khung chạy: chỉ chứa phần nhúc nhích (cần tre nhấc nắp nón lên, lớp bột láng ra trên vải, nắp hạ xuống), còn lại trong suốt. Chu kỳ 3,2 s, 32 khung (10 khung/s), lặp liền |
| `btrang_che_*` | Phần lò nằm TRƯỚC lửa quanh miệng lò (vách lò, củi chẻ, tro), chỗ miệng lò trong suốt. Vẽ đè lên lửa nên lửa chỉ thấy qua miệng lò |
| `btrang_lua.webp` | 1 lưỡi lửa trắng 64x96, Y HỆT lửa lò bánh mì (`lobanhmi_lua.webp`). Godot nhân màu theo color ramp |
| `btrang_hoi.webp` | Cục hơi nước (trắng, mềm, 128x128). KHÔNG vẽ sẵn trong khung |
| `btrang_khoi.webp` | Cục khói củi (trắng, 128x128). KHÔNG vẽ sẵn trong khung |

**Thứ tự vẽ khi chạy:** `btrang_r` → hạt lửa → `btrang_che` → khung `f` hiện tại → hơi → khói.
Lúc nghỉ: chỉ vẽ `btrang_i`, tắt hết hiệu ứng.

Nền: y hệt hàng chả, cao bằng nền nhà (2.4), mặt trên phẳng, bo tròn 4 góc, thành đất nện chân hơi loe. Đáy nền nằm đúng mặt đất, mọi toạ độ trong atlas đã tính phần nền cao này rồi.

`atlas.json`: khoá = tên + d/n (vd `f5d`, `id`, `rn`, `ched`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x2 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.
Điểm phát hiệu ứng, cùng hệ toạ độ:
- `lua`: 18 điểm trên lớp than trong miệng lò (3 hàng x 6, hàng ngoài sát miệng, như lò bánh quê), dạng [[x, y], ...]
- `hoivanh`: 12 điểm quanh vành nắp nón lúc đậy (hơi xì ra mép nắp, và bốc lên từ vải lúc nắp nhấc)
- `hoi`: núm nắp lúc đậy (1 điểm, [x, y])
- `khoi`: miệng ống khói đất sau lưng lò ([x, y])

## Lửa trong lò (hiệu ứng riêng, Godot tự sinh, chỉ bật khi xưởng chạy)
Lấy lửa của lò bánh mì: texture, blend, màu, tốc độ, góc, đường cong scale GIỐNG HỆT README lò bánh mì
(`godot/xuong/lobanhmi/README.md`, mục "Lửa trong lò"). Chỉ đổi cho vừa miệng lò: **amount 36**, **scale 0.6 → 1.14**, tốc độ và trọng lực x1,2. **Link 2026-11-12 22:21 đồng bộ: số lửa giờ theo chuẩn chung `godot/xuong/LUA.md` (= lò bánh quê "lửa to trong lò"): amount 45 cho 1 miệng, tốc độ 6 → 11.5, gravity -7.5, scale 1.0 → 1.75, 3 hàng điểm phát.**
Từ 2026-11-12 lò, nồi, cần nắp vẽ to ra 1,2 lần cho dễ thấy trong game, nên lửa, hơi, khói dưới đây cũng to ra 1,2 lần.

**CPUParticles2D** đặt ở tâm nền, `emission_shape = POINTS`, `emission_points` = khoá `lua`. Material là CanvasItemMaterial `blend_mode = ADD`, `light_mode = UNSHADED`:
- amount 45, lifetime 0.7 s, preprocess 0.7 s, explosiveness 0, randomness 0.5, local_coords = false
- direction (0, -1), spread 10°, initial_velocity 6 → 11.5 đơn vị/s, gravity (0, -7.5)
- angle -14° → 14°, angular_velocity -45 → 45 °/s
- scale_amount 0.036 → 0.063 (lưỡi lửa rộng 2.3 → 4 đơn vị, nếu 1 đơn vị = 1 px; scale ảnh xưởng 1/9 thì nhân thêm 9)
- split_scale = true. scale_curve_x: 0 → 0.75, 0.2 → 1.0, 0.6 → 0.7, 1 → 0.3. scale_curve_y: 0 → 0.45, 0.2 → 1.0, 0.7 → 1.2, 1 → 0.9
- color_ramp (màu, alpha): 0 #ff6418 0 · 0.1 #f25616 0.42 · 0.35 #d83e0e 0.38 · 0.65 #a2260a 0.26 · 1 #3c0802 0
- Ban ngày và ban đêm dùng chung số này.
- KHÔNG dùng clip_children. Che lửa bằng ảnh `btrang_che` vẽ đè lên như trên.

## Hơi nước (ở `hoivanh`, chỉ bật khi xưởng chạy)
CPUParticles2D, `emission_shape = POINTS`, `emission_points` = khoá `hoivanh`, vẽ trên khung `f`, không ăn ánh sáng:
- texture `btrang_hoi.webp`, amount 22, lifetime 1.5 s, preprocess 1.5 s, randomness 0.3
- direction (0, -1), spread 30°, initial velocity 7.2 đơn vị/s, gravity (-2.4, -1.2) (hơi bốc lên rồi dạt nhẹ sang trái)
- scale: 1/9 nhân đường cong 0.3 → 1.8 theo tuổi hạt
- color ramp alpha: 0 → 0.72 (10%) → 0.42 (45%) → 0 (100%)
- màu nhân: ngày #ffffff, đêm #c8c8d0

## Khói (ở `khoi`, miệng ống khói, chỉ bật khi xưởng chạy)
- texture `btrang_khoi.webp`, amount 10, lifetime 2.4 s, preprocess 2.4 s, randomness 0.2
- direction (0, -1), spread 6°, initial velocity 14.4 đơn vị/s, gravity (-4.2, 0)
- scale: 1/9 nhân đường cong 0.18 → 1.92 theo tuổi hạt
- color ramp alpha: 0 → 0.40 (8%) → 0.24 (50%) → 0 (100%) (khói bếp củi mỏng)
- màu nhân: ngày #cecbc6, đêm #96969c

GIF xem thử vẽ đúng các số trên, từ đúng các file trong thư mục này: xem/cong-trinh/lo-banh-trang-chay-gan-{d,n}.gif (cận lò),
xem/cong-trinh/lo-banh-trang-ca-canh-{d,n}.gif (cả cảnh). Trình giả lập: src/btrang/gif.py (lửa qua src/lobanhmi/luafx.py `simulate`).

Đèn trên cột: cây đèn dầu xanh mảnh chai (giống lò bánh mì, lò nướng, hàng chả), ngày tắt, đêm thắp.

Nguồn: src/btrang/btrang3d.py (mô hình 3D; BT_STATE=run|idle, BT_MOV=all|none, BT_PH 0..1 = pha nắp), src/btrang/export.py (xuất ảnh + ảnh che + texture hạt), src/btrang/gif.py (GIF xem thử).
Muốn xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/btrang/export.py OUTDIR OUTDIR/atlas.json 3`
(tối đa 3 việc song song). Đổi hình khối thì xoá OUTDIR/raw trước khi xuất lại.
