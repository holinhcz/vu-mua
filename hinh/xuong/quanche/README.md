# Quán chè (xưởng "quanche", 2x2 ô) – ảnh cho Godot

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm (đèn dầu trên cột trước bên phải thắp, độ sáng đêm theo chuẩn kho).

Game: chè đậu xanh, chè bắp, chè khoai, chè chuối, chè bưởi, chè mè đen, chè ba màu, sâm bổ lượng, sữa đậu nành, sữa bắp, sữa đậu xanh, nước dừa lá dứa.

| File | Dùng khi |
|---|---|
| `quanche_i_*` | Quán nghỉ, nguyên cảnh: bếp nguội, nồi chè đậy nắp, nồi trên quầy đậy nắp, ly úp trên khay, ghế lật úp lên bàn, bàn trống |
| `quanche_r_*` | Quán chạy, ảnh nền: than hồng trong miệng cà ràng (KHÔNG có ngọn lửa), nồi chè đậu xanh mở nắp, 3 nồi chè trên quầy có vá, khay 4 ly chè ba màu, hũ sâm bổ lượng, rổ dừa + trái dừa gọt, ly chè + chén chè trên 2 bàn khách. Ảnh này KHÔNG có cái vá khuấy + bọt chè, 2 thứ đó nằm trong khung `f` |
| `quanche_f0..f31_*` | Khung chạy: chỉ chứa phần nhúc nhích (vá khuấy vòng quanh nồi chè, bọt phồng lên rồi vỡ), còn lại trong suốt. Chu kỳ 3,2 s, 32 khung (10 khung/s), lặp liền |
| `quanche_che_*` | Phần bếp nằm TRƯỚC lửa quanh miệng cà ràng (vách cà ràng, củi chẻ, tro), chỗ miệng trong suốt. Vẽ đè lên lửa nên lửa chỉ thấy qua miệng cà ràng |
| `quanche_lua.webp` | 1 lưỡi lửa trắng 64x96, Y HỆT lửa lò bánh mì (`lobanhmi_lua.webp`). Godot nhân màu theo color ramp |
| `quanche_hoi.webp` | Cục hơi nước (trắng, mềm, 128x128). KHÔNG vẽ sẵn trong khung |
| `quanche_khoi.webp` | Cục khói củi (trắng, 128x128). KHÔNG vẽ sẵn trong khung |

**Thứ tự vẽ khi chạy:** `quanche_r` → hạt lửa → `quanche_che` → khung `f` hiện tại → hơi → khói.
Lúc nghỉ: chỉ vẽ `quanche_i`, tắt hết hiệu ứng.

Nền: y hệt hàng chả, cao bằng nền nhà (2.4), mặt trên phẳng, bo tròn 4 góc. Đáy nền nằm đúng mặt đất, mọi toạ độ trong atlas đã tính phần nền cao này rồi.

`atlas.json`: khoá = tên + d/n (vd `f5d`, `id`, `rn`, `ched`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x2 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.
Điểm phát hiệu ứng, cùng hệ toạ độ:
- `lua`: 18 điểm trên lớp than trong miệng cà ràng (3 hàng x 6, hàng ngoài sát miệng, như lò bánh quê), dạng [[x, y], ...]
- `hoivanh`: 7 điểm trên mặt nồi chè (1 ở giữa + 6 quanh), hơi bốc khắp mặt nồi
- `hoi`: giữa mặt nồi chè (1 điểm, [x, y])
- `khoi`: khe giữa đáy nồi và vành cà ràng phía sau bên trái ([x, y])

## Lửa trong cà ràng (hiệu ứng riêng, Godot tự sinh, chỉ bật khi quán chạy)
Lấy lửa của lò bánh mì: texture, blend, màu, góc, đường cong scale GIỐNG HỆT README lò bánh mì
(`godot/xuong/lobanhmi/README.md`, mục "Lửa trong lò"). Bếp quán chè vẽ to 1,3 lần cho dễ thấy trong game, nên lửa cũng to 1,3 lần: **Link 2026-11-12 22:21 đồng bộ: số lửa giờ theo chuẩn chung `godot/xuong/LUA.md` (= lò bánh quê "lửa to trong lò"): amount 45 cho 1 miệng, tốc độ 6 → 11.5, gravity -7.5, scale 1.0 → 1.75, 3 hàng điểm phát.**

**CPUParticles2D** đặt ở tâm nền, `emission_shape = POINTS`, `emission_points` = khoá `lua`. Material là CanvasItemMaterial `blend_mode = ADD`, `light_mode = UNSHADED`:
- amount 45, lifetime 0.7 s, preprocess 0.7 s, explosiveness 0, randomness 0.5, local_coords = false
- direction (0, -1), spread 10°, initial_velocity 6 → 11.5 đơn vị/s, gravity (0, -7.5)
- angle -14° → 14°, angular_velocity -45 → 45 °/s
- scale_amount 0.036 → 0.063 (lưỡi lửa rộng 2.3 → 4 đơn vị, nếu 1 đơn vị = 1 px; scale ảnh xưởng 1/9 thì nhân thêm 9)
- split_scale = true. scale_curve_x: 0 → 0.75, 0.2 → 1.0, 0.6 → 0.7, 1 → 0.3. scale_curve_y: 0 → 0.45, 0.2 → 1.0, 0.7 → 1.2, 1 → 0.9
- color_ramp (màu, alpha): 0 #ff6418 0 · 0.1 #f25616 0.42 · 0.35 #d83e0e 0.38 · 0.65 #a2260a 0.26 · 1 #3c0802 0
- Ban ngày và ban đêm dùng chung số này.
- KHÔNG dùng clip_children. Che lửa bằng ảnh `quanche_che` vẽ đè lên như trên.

## Hơi nước (ở `hoivanh`, mặt nồi chè, chỉ bật khi quán chạy)
CPUParticles2D, `emission_shape = POINTS`, `emission_points` = khoá `hoivanh`, vẽ trên khung `f`, không ăn ánh sáng:
- texture `quanche_hoi.webp`, amount 30, lifetime 1.7 s, preprocess 1.7 s, randomness 0.2
- direction (0, -1), spread 30°, initial velocity 6.0 đơn vị/s, gravity (-2.0, -1.0) (hơi bốc lên rồi dạt nhẹ sang trái)
- scale: 1/9 nhân đường cong 0.25 → 1.5 theo tuổi hạt
- color ramp alpha: 0 → 0.72 (10%) → 0.42 (45%) → 0 (100%)
- màu nhân: ngày #ffffff, đêm #c8c8d0

## Khói (ở `khoi`, khe nồi / cà ràng, chỉ bật khi quán chạy)
- texture `quanche_khoi.webp`, amount 10, lifetime 2.4 s, preprocess 2.4 s, randomness 0.2
- direction (0, -1), spread 6°, initial velocity 12.0 đơn vị/s, gravity (-3.5, 0)
- scale: 1/9 nhân đường cong 0.15 → 1.6 theo tuổi hạt
- color ramp alpha: 0 → 0.40 (8%) → 0.24 (50%) → 0 (100%) (khói củi mỏng)
- màu nhân: ngày #cecbc6, đêm #96969c

GIF xem thử vẽ đúng các số trên, từ đúng các file trong thư mục này: xem/cong-trinh/quan-che-chay-gan-{d,n}.gif (cận bếp),
xem/cong-trinh/quan-che-chay-ca-canh-{d,n}.gif (cả quán). Trình giả lập: src/quanche/gif.py (lửa qua src/lobanhmi/luafx.py `simulate`).

Đèn trên cột: cây đèn dầu xanh mảnh chai (giống lò bánh mì, hàng chả), treo ở cột trước bên phải, ngày tắt, đêm thắp. Lửa bếp ban đêm chỉ hắt sáng nhỏ quanh miệng cà ràng.

Nguồn: src/quanche/qc3d.py (mô hình 3D; QC_STATE=run|idle, QC_MOV=all|none, QC_PH 0..1 = pha vá + bọt), src/quanche/export.py (xuất ảnh + ảnh che + texture hạt), src/quanche/gif.py (GIF xem thử).
Muốn xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/quanche/export.py OUTDIR OUTDIR/atlas.json 3`
(tối đa 3 việc song song). Đổi hình khối thì xoá OUTDIR/raw trước khi xuất lại.
