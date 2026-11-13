# Hàng chả (xưởng "hangcha", 2x2 ô) – ảnh cho Godot

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm (đèn dầu trên cột thắp, độ sáng đêm theo chuẩn kho).

| File | Dùng khi |
|---|---|
| `hangcha_i_*` | Xưởng nghỉ, nguyên cảnh: cối đá trống, bếp nguội, bàn gói chỉ còn xấp lá + bó lạt, sào trống |
| `hangcha_r_*` | Xưởng chạy, nguyên cảnh ở tư thế đứng yên: than hồng trong cà ràng (KHÔNG có ngọn lửa), nồi hấp + 2 tầng xửng, giò sống trong cối, bàn gói đầy (giò lụa, nem chua, chả giò, thịt), sào lạp xưởng. Ảnh này không có cần + chày, cần và chày nằm trong khung `f` |
| `hangcha_f0..f23_*` | Khung chạy: chỉ chứa phần nhúc nhích (cần đạp + chày nện xuống cối 2 lần mỗi chu kỳ, nắp nón xửng nhấp lên theo hơi), còn lại trong suốt. Chu kỳ 2,4 s, 24 khung (10 khung/s), lặp liền |
| `hangcha_che_*` | Phần cà ràng nằm TRƯỚC lửa quanh miệng bếp (vách cà ràng, lưỡi, 2 khúc củi), chỗ miệng bếp trong suốt. Vẽ đè lên lửa nên lửa chỉ thấy qua miệng bếp, không thò ra ngoài vách |
| `hangcha_lua.webp` | 1 lưỡi lửa trắng 64x96, Y HỆT lửa lò bánh mì (`lobanhmi_lua.webp`). Godot nhân màu theo color ramp |
| `hangcha_hoi.webp` | Cục hơi nước (trắng, mềm, 128x128). KHÔNG vẽ sẵn trong khung |
| `hangcha_khoi.webp` | Cục khói củi (trắng, 128x128). KHÔNG vẽ sẵn trong khung |

**Thứ tự vẽ khi chạy:** `hangcha_r` → hạt lửa → `hangcha_che` → khung `f` hiện tại → hơi → khói.
Lúc nghỉ: chỉ vẽ `hangcha_i`, tắt hết hiệu ứng.

Nền: cao bằng nền nhà (2.4), mặt trên phẳng (không gợn, không bậc), bo tròn 4 góc như nền nhà kho. Đáy nền nằm đúng mặt đất, mọi toạ độ trong atlas đã tính phần nền cao này rồi.

`atlas.json`: khoá = tên + d/n (vd `f5d`, `id`, `rn`, `ched`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x2 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.
Điểm phát hiệu ứng, cùng hệ toạ độ, dạng [x, y]:
- `lua`: 18 điểm trên lớp than trong miệng cà ràng (3 hàng x 6, hàng ngoài sát miệng, như lò bánh quê)
- `hoivanh`: 15 điểm, 12 điểm quanh vành nắp xửng (hơi phì ra khe nắp) + 3 lần điểm núm nắp (núm phì nhiều hơn)
- `hoi`: núm nắp xửng (1 điểm, nếu muốn dùng 1 điểm thay cho `hoivanh`)
- `khoi`: mép cà ràng bên trái, khói lách ra khe giữa nồi và miệng cà ràng

## Lửa trong bếp (hiệu ứng riêng, Godot tự sinh, chỉ bật khi xưởng chạy)
Link 2026-11-11 14:56: lấy lửa của lò bánh mì. Texture, blend, màu, tốc độ, góc, đường cong scale GIỐNG HỆT README lò bánh mì
(`godot/xuong/lobanhmi/README.md`, mục "Lửa trong lò"). Chỉ đổi 2 số cho vừa miệng cà ràng nhỏ hơn: amount 30 và scale 0.5 → 0.95. Link 2026-11-12: bếp phóng to x1.2 cho dễ nhìn trong game, nên mọi số lửa/hơi/khói bên dưới đã nhân 1.2: **amount 36, scale 0.6 → 1.14, tốc độ 5.4 → 10.2, gravity -7.2**. **Link 2026-11-12 22:21 đồng bộ: số lửa giờ theo chuẩn chung `godot/xuong/LUA.md` (= lò bánh quê "lửa to trong lò"): amount 45 cho 1 miệng, tốc độ 6 → 11.5, gravity -7.5, scale 1.0 → 1.75, 3 hàng điểm phát.**

**CPUParticles2D** đặt ở tâm nền, `emission_shape = POINTS`, `emission_points` = khoá `lua`. Material là CanvasItemMaterial `blend_mode = ADD`, `light_mode = UNSHADED`:
- amount 45, lifetime 0.7 s, preprocess 0.7 s, explosiveness 0, randomness 0.5, local_coords = false
- direction (0, -1), spread 10°, initial_velocity 6 → 11.5 đơn vị/s, gravity (0, -7.5)
- angle -14° → 14°, angular_velocity -45 → 45 °/s
- scale_amount 0.036 → 0.063 (lưỡi lửa rộng 2.3 → 4 đơn vị, nếu 1 đơn vị = 1 px; scale ảnh xưởng 1/9 thì nhân thêm 9).
- split_scale = true. scale_curve_x: 0 → 0.75, 0.2 → 1.0, 0.6 → 0.7, 1 → 0.3. scale_curve_y: 0 → 0.45, 0.2 → 1.0, 0.7 → 1.2, 1 → 0.9
- color_ramp (màu, alpha): 0 #ff6418 0 · 0.1 #f25616 0.42 · 0.35 #d83e0e 0.38 · 0.65 #a2260a 0.26 · 1 #3c0802 0
  Cộng sáng nên chỗ nhiều hạt chồng lên (sát than) tự ngả cam, ngọn đỏ thẫm. Lửa đỏ cam, không vàng.
- Ban ngày và ban đêm dùng chung số này.
- KHÔNG dùng clip_children (blend Add trong vùng clip không ổn định). Che lửa bằng ảnh `hangcha_che` vẽ đè lên như trên.

## Hơi nước (ở `hoivanh`, chỉ bật khi xưởng chạy)
CPUParticles2D, `emission_shape = POINTS`, `emission_points` = khoá `hoivanh`, vẽ trên khung `f`, không ăn ánh sáng:
- texture `hangcha_hoi.webp`, amount 22, lifetime 1.5 s, preprocess 1.5 s, randomness 0.3
- direction (0, -1), spread 30°, initial velocity 7.2 đơn vị/s, gravity (-2.4, -1.2) (hơi bốc lên rồi dạt nhẹ sang trái)
- scale: 1/9 nhân đường cong 0.3 → 1.8 theo tuổi hạt
- color ramp alpha: 0 → 0.72 (10%) → 0.42 (45%) → 0 (100%)
- màu nhân: ngày #ffffff, đêm #c8c8d0

## Khói (ở `khoi`, chỉ bật khi xưởng chạy)
- texture `hangcha_khoi.webp`, amount 10, lifetime 2.4 s, preprocess 2.4 s, randomness 0.2
- direction (0, -1), spread 6°, initial velocity 14.4 đơn vị/s, gravity (-4.2, 0)
- scale: 1/9 nhân đường cong 0.18 → 1.92 theo tuổi hạt
- color ramp alpha: 0 → 0.40 (8%) → 0.24 (50%) → 0 (100%) (khói bếp củi mỏng)
- màu nhân: ngày #cecbc6, đêm #96969c

GIF xem thử vẽ đúng các số trên, từ đúng các file trong thư mục này: xem/cong-trinh/hang-cha-gia-cha-{d,n}.gif (zoom cối + bếp),
xem/cong-trinh/hang-cha-ca-canh-{d,n}.gif (cả cảnh). Trình giả lập: src/hangcha/gif.py (lửa qua src/lobanhmi/luafx.py `simulate`).

Đèn trên cột: cây đèn dầu xanh mảnh chai (giống lò bánh mì, lò nướng, giàn phơi), ngày tắt, đêm thắp.

Nguồn: src/hangcha/hangcha3d.py (mô hình 3D; HC_STATE=run|idle, HC_MOV=all|none, HC_PH 0..1 = pha chày), src/hangcha/export.py (xuất ảnh + ảnh che + texture hạt), src/hangcha/gif.py (GIF xem thử).
Muốn xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/hangcha/export.py OUTDIR OUTDIR/atlas.json 3`
(tối đa 3 việc song song). Đổi hình khối thì xoá OUTDIR/raw trước khi xuất lại.
