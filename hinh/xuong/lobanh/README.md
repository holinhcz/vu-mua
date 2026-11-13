# Lò bánh quê (xưởng "lobanh", 2x2 ô) – ảnh cho Godot

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm (đèn dầu trên cột thắp, 2 miệng lò hắt sáng, độ sáng đêm theo chuẩn kho/lò bánh mì).

| File | Dùng khi |
|---|---|
| `lobanh_i_*` | Xưởng nghỉ, nguyên cảnh (nắp đất đậy khuôn khọt, lò tắt) |
| `lobanh_r_*` | Xưởng chạy, phần đứng yên (nền): than hồng trong 2 miệng cà ràng (KHÔNG có ngọn lửa), nắp đất dựng nghiêng bên hông cà ràng |
| `lobanh_f0..f23_*` | Khung chạy: bánh khọt sôi viền trong khuôn, nắp nón xửng hấp bị hơi đẩy nhấc lên 2 lần mỗi chu kỳ (khung f0-f3 và f12-f15). Chu kỳ 2,4 s, 24 khung (10 khung/s) |
| `lobanh_che_*` | Phần cà ràng nằm TRƯỚC lửa quanh 2 miệng bếp (vách, lưỡi, củi), chỗ miệng bếp trong suốt. Vẽ đè lên lửa nên lửa chỉ thấy qua miệng bếp |
| `lobanh_lua.webp` | 1 lưỡi lửa trắng 64x96, Y HỆT lửa lò bánh mì. Godot nhân màu theo color ramp |
| `lobanh_khoi.webp` | Cục khói củi (trắng, 128x128) cho hiệu ứng hạt. KHÔNG vẽ sẵn trong khung |
| `lobanh_hoi.webp` | Cục hơi nước (trắng, mềm hơn, 128x128) cho hiệu ứng hạt. KHÔNG vẽ sẵn trong khung |

**Thứ tự vẽ khi chạy:** `lobanh_r` → hạt lửa → `lobanh_che` → khung `f` hiện tại (chỉ chứa phần thay đổi, nền trong suốt) → hơi → 2 khói.

Nền: từ 2026-11-11 15:09 nền y hệt hàng chả: cao bằng nền nhà (2.4), bo tròn 4 góc như nền nhà kho, thành đất nện chân hơi loe. Đáy nền nằm đúng mặt đất, mọi toạ độ trong atlas đã tính phần nền cao này rồi, không cần cộng gì thêm.

`atlas.json`: khoá = tên + d/n (vd `f5d`, `id`, `rn`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x2 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.
Điểm phát hiệu ứng, cùng hệ toạ độ, dạng [x, y]:
- `khoi1`: mép sau miệng cà ràng 1 (khuôn bánh khọt), khói lách ra khe giữa khuôn và miệng lò
- `khoi2`: mép trái miệng cà ràng 2 (nồi hấp)
- `hoi`: đỉnh nắp nón xửng hấp
- `lua`: 36 điểm phát lửa, 18 điểm trên lớp than trong mỗi miệng cà ràng (3 hàng mỗi miệng, hàng ngoài sát miệng)

## Lửa trong 2 miệng bếp (hiệu ứng riêng, Godot tự sinh, chỉ bật khi xưởng chạy)
Từ 2026-11-11 15:08 ảnh KHÔNG còn vẽ ngọn lửa (bỏ lửa vẽ sẵn cũ). Lửa lấy y hệt lò bánh mì (`godot/xuong/lobanhmi/README.md`, mục "Lửa trong lò"), chỉ đổi 2 số cho vừa 2 miệng cà ràng nhỏ: amount 30 và scale nhỏ hơn. Link 2026-11-12: bếp phóng to x1.15 cho dễ nhìn trong game, nên mọi số lửa/hơi/khói bên dưới đã nhân 1.15 (amount 34). Link 2026-11-12 17:10: lửa to trong lò, không lan ra ngoài -> **amount 90, scale lớn hơn, tốc độ 6 → 11.5, gravity -7.5**; thêm 1 hàng điểm phát sát miệng (`lua` giờ 18 điểm mỗi cà ràng).

**CPUParticles2D** đặt ở tâm nền, `emission_shape = POINTS`, `emission_points` = khoá `lua`. Material là CanvasItemMaterial `blend_mode = ADD`, `light_mode = UNSHADED`:
- amount 90, lifetime 0.7 s, preprocess 0.7 s, explosiveness 0, randomness 0.5, local_coords = false
- direction (0, -1), spread 10°, initial_velocity 6 → 11.5 đơn vị/s, gravity (0, -7.5)
- angle -14° → 14°, angular_velocity -45 → 45 °/s
- scale_amount 0.036 → 0.063 (lưỡi lửa rộng 2.3 → 4 đơn vị, nếu 1 đơn vị = 1 px; scale ảnh xưởng 1/9 thì nhân thêm 9)
- split_scale = true. scale_curve_x: 0 → 0.75, 0.2 → 1.0, 0.6 → 0.7, 1 → 0.3. scale_curve_y: 0 → 0.45, 0.2 → 1.0, 0.7 → 1.2, 1 → 0.9
- color_ramp (màu, alpha): 0 #ff6418 0 · 0.1 #f25616 0.42 · 0.35 #d83e0e 0.38 · 0.65 #a2260a 0.26 · 1 #3c0802 0
- Ban ngày và ban đêm dùng chung số này. KHÔNG dùng clip_children: che lửa bằng ảnh `lobanh_che` vẽ đè lên.

## Khói (2 cái, ở `khoi1` và `khoi2`, chỉ bật khi xưởng chạy)
CPUParticles2D (hoặc GPUParticles2D), vẽ trên sprite lò (z cao hơn), không ăn ánh sáng:
- texture `lobanh_khoi.webp`, amount 10, lifetime 2.4 s, preprocess 2.4 s, randomness 0.2
- direction (0, -1), spread 6°, initial velocity 13.8 đơn vị/s, gravity (-4, 0) (khói bay lên rồi dạt sang trái, ra xa mái lá)
- scale: 1/9 nhân đường cong 0.17 → 1.84 theo tuổi hạt
- color ramp alpha: 0 → 0.30 (8%) → 0.18 (50%) → 0 (100%) (khói bếp củi nhẹ, mỏng hơn khói lò bánh mì)
- màu nhân: ngày #cecbc6, đêm #96969c

## Hơi nước (1 cái, ở `hoi`, chỉ bật khi xưởng chạy)
- texture `lobanh_hoi.webp`, amount 12, lifetime 1.6 s, preprocess 1.6 s, randomness 0.3
- direction (0, -1), spread 20°, initial velocity 11.5 đơn vị/s, gravity (-2.3, 0)
- scale: 1/9 nhân đường cong 0.29 → 1.61 theo tuổi hạt
- color ramp alpha: 0 → 0.5 (10%) → 0.28 (45%) → 0 (100%)
- màu nhân: ngày #ffffff, đêm #c8c8d0
- (tuỳ chọn) lúc nắp nhấc (khung f0-f3, f12-f15) cho emitting thêm 1 đợt 4 hạt (one_shot, explosiveness 0.8) cho phì hơi

GIF xem thử (xem/cong-trinh/lo-banh-que-chay-anim-{d,n}.gif) vẽ lửa, khói, hơi đúng theo các số này (src/lobanh/gif.py, lửa qua src/lobanhmi/luafx.py `simulate`).

Nguồn: src/lobanh/lobanh3d.py (mô hình 3D), src/lobanh/export.py (xuất ảnh + ảnh che + texture lửa, khói, hơi), src/lobanh/gif.py (GIF xem thử).

Muốn xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/lobanh/export.py OUTDIR OUTDIR/atlas.json 3` (tối đa 3 việc song song, 4 việc là hết RAM). Đổi hình khối thì xoá OUTDIR/raw trước khi xuất lại.

Đèn trên cột: cây đèn dầu xanh mảnh chai treo gọng dây sắt (Link 10:00), dùng chung code với lò bánh mì (src/lobanhmi/lobanhmi3d.py dendau_hang), ngày tắt, đêm thắp.
