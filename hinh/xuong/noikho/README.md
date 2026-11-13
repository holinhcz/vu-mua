# Nồi kho (xưởng "kho", 2x2 ô) – ảnh cho Godot

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm (đèn dầu treo cột chái bên trái thắp, độ sáng đêm theo chuẩn kho; lửa bếp chỉ hắt sáng nhỏ quanh 2 miệng lò).

Cảnh: chái lá tre, bếp lò đất đắp 2 miệng (miệng lò khoét thật như cà ràng lò bánh quê: lòng lò bồ hóng, than hồng, lưỡi đất, 2 củi chẻ đút vô mỗi miệng; nồi đất thịt kho trứng + nồi lẩu nhôm: tôm, cà chua), bàn tre ăn lẩu (rổ rau, bông súng,
dĩa bò, dĩa tôm, tô nước chấm, chén, đũa) + 2 ghế đẩu, bàn sơ chế (thớt, ba rọi, dao, rổ trứng vịt, hành ớt), kệ tre 2 tầng hũ mắm /
đường / muối / chai, đống dừa xiêm, lu nước nắp gỗ, đống củi, thau rửa rau. Bàn, ghế, kệ đều bằng ống tre.

| File | Dùng khi |
|---|---|
| `noikho_i_*` | Xưởng nghỉ, nguyên cảnh: bếp nguội, 2 nồi đậy nắp, bàn dọn trống (rổ trống, dĩa chồng, chén úp) |
| `noikho_r_*` | Xưởng chạy, ảnh nền: than hồng trong 2 miệng lò (KHÔNG có ngọn lửa), nồi kho, nồi lẩu, đồ ăn trên bàn. Ảnh này KHÔNG có bọt lẩu, bọt nằm trong khung `f` |
| `noikho_f0..f23_*` | Khung chạy: chỉ chứa phần nhúc nhích (bọt nồi lẩu phồng lên rồi vỡ), còn lại trong suốt. Chu kỳ 2,4 s, 24 khung (10 khung/s), lặp liền |
| `noikho_che_*` | Phần bếp nằm TRƯỚC lửa quanh 2 miệng lò (vành đất, lưỡi, đầu củi chẻ ngoài miệng), chỗ miệng trong suốt. Vẽ đè lên lửa nên lửa chỉ thấy qua miệng lò |
| `noikho_lua.webp` | 1 lưỡi lửa trắng 64x96, Y HỆT lửa lò bánh mì (`lobanhmi_lua.webp`). Godot nhân màu theo color ramp |
| `noikho_hoi.webp` | Cục hơi nước (trắng, mềm, 128x128). KHÔNG vẽ sẵn trong khung |
| `noikho_khoi.webp` | Cục khói củi (trắng, 128x128). KHÔNG vẽ sẵn trong khung |

**Thứ tự vẽ khi chạy:** `noikho_r` → hạt lửa → `noikho_che` → khung `f` hiện tại → hơi → khói.
Lúc nghỉ: chỉ vẽ `noikho_i`, tắt hết hiệu ứng.

Chuẩn chung mọi xưởng: `godot/xuong/DONGBO.md` + `godot/xuong/LUA.md`.

Nền: cao bằng nền nhà (2.4), mặt trên phẳng, bo tròn 4 góc. Đáy nền nằm đúng mặt đất, mọi toạ độ trong atlas đã tính phần nền cao này rồi.

`atlas.json`: khoá = tên + d/n (vd `f5d`, `id`, `rn`, `ched`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x2 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.
Điểm phát hiệu ứng, cùng hệ toạ độ:
- `lua`: 36 điểm trên lớp than trong 2 miệng lò (mỗi miệng 3 hàng x 6, trên lớp than trong lòng lò, hàng ngoài sát miệng, giống lò bánh quê), dạng [[x, y], ...]
- `hoi`: 2 điểm, mặt nồi kho và mặt nồi lẩu, dạng [[x, y], [x, y]]
- `khoi`: 2 điểm, khe giữa nồi và vành lỗ bếp phía sau, dạng [[x, y], [x, y]]

## Lửa trong 2 miệng lò (hiệu ứng riêng, Godot tự sinh, chỉ bật khi xưởng chạy)
Theo chuẩn chung `godot/xuong/LUA.md`: lửa lò bánh mì (texture, blend, màu, góc, đường cong scale y hệt `godot/xuong/lobanhmi/README.md`),
số lượng / cỡ / tốc độ y hệt lò bánh quê (Link 2026-11-12 17:10 "lửa to trong lò": lửa đầy miệng, không lan ra ngoài).

**CPUParticles2D** đặt ở tâm nền, `emission_shape = POINTS`, `emission_points` = khoá `lua`. Material là CanvasItemMaterial `blend_mode = ADD`, `light_mode = UNSHADED`:
- amount 90, lifetime 0.7 s, preprocess 0.7 s, explosiveness 0, randomness 0.5, local_coords = false
- direction (0, -1), spread 10°, initial_velocity 6 → 11.5 đơn vị/s, gravity (0, -7.5)
- angle -14° → 14°, angular_velocity -45 → 45 °/s
- scale_amount 0.036 → 0.063 (lưỡi lửa rộng 2.3 → 4 đơn vị, nếu 1 đơn vị = 1 px; scale ảnh xưởng 1/9 thì nhân thêm 9)
- split_scale = true. scale_curve_x: 0 → 0.75, 0.2 → 1.0, 0.6 → 0.7, 1 → 0.3. scale_curve_y: 0 → 0.45, 0.2 → 1.0, 0.7 → 1.2, 1 → 0.9
- color_ramp (màu, alpha): 0 #ff6418 0 · 0.1 #f25616 0.42 · 0.35 #d83e0e 0.38 · 0.65 #a2260a 0.26 · 1 #3c0802 0
- Ban ngày và ban đêm dùng chung số này.
- KHÔNG dùng clip_children. Che lửa bằng ảnh `noikho_che` vẽ đè lên như trên.
- Miệng lò trong ảnh `r` tối như lò bánh mì (bồ hóng trên vòm, đỏ sẫm sát than), lửa hạt cộng sáng lên mới ra màu.

## Hơi nước (ở `hoi`, mặt 2 nồi, chỉ bật khi xưởng chạy)
CPUParticles2D, `emission_shape = POINTS`, `emission_points` = khoá `hoi`, vẽ trên khung `f`, không ăn ánh sáng:
- texture `noikho_hoi.webp`, amount 30, lifetime 1.7 s, preprocess 1.7 s, randomness 0.2
- direction (0, -1), spread 30°, initial velocity 6.0 đơn vị/s, gravity (-2.0, -1.0) (hơi bốc lên rồi dạt nhẹ sang trái)
- scale: 1/9 nhân đường cong 0.25 → 1.5 theo tuổi hạt
- color ramp alpha: 0 → 0.72 (10%) → 0.42 (45%) → 0 (100%)
- màu nhân: ngày #ffffff, đêm #c8c8d0

## Khói (ở `khoi`, khe nồi / lỗ bếp, chỉ bật khi xưởng chạy)
- texture `noikho_khoi.webp`, amount 12, lifetime 2.6 s, preprocess 2.6 s, randomness 0.2
- direction (0, -1), spread 22°, initial velocity 8.0 đơn vị/s, gravity (-5.0, 0) (khói tỏa rộng, dạt sang trái, không thành cột)
- scale: 1/9 nhân đường cong 0.35 → 2.4 theo tuổi hạt
- color ramp alpha: 0 → 0.26 (12%) → 0.16 (50%) → 0 (100%) (khói củi mỏng)
- màu nhân: ngày #cecbc6, đêm #96969c

GIF xem thử vẽ đúng các số trên, từ đúng các file trong thư mục này: xem/cong-trinh/noi-kho-chay-gan-{d,n}.gif (cận bếp),
xem/cong-trinh/noi-kho-chay-ca-canh-{d,n}.gif (cả xưởng). Trình giả lập: src/noikho/gif.py (lửa qua src/lobanhmi/luafx.py `simulate`).

Nguồn: src/noikho/noikho3d.py (mô hình 3D; NK_STATE=run|idle, NK_MOV=all|none, NK_PH 0..1 = pha bọt lẩu), src/noikho/export.py (xuất ảnh + ảnh che + texture hạt), src/noikho/gif.py (GIF xem thử).
Muốn xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/noikho/export.py OUTDIR OUTDIR/atlas.json 3`
(tối đa 3 việc song song). Đổi hình khối thì xoá OUTDIR/raw trước khi xuất lại.
