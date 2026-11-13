# Lò nướng (xưởng "nuong", 2x2 ô) – ảnh cho Godot

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm (đèn dầu trên cột thắp, than + lửa rơm hắt sáng, độ sáng đêm theo chuẩn kho).

| File | Dùng khi |
|---|---|
| `nuong_i_*` | Xưởng nghỉ, nguyên cảnh (lò nguội, vỉ trống, cá lóc sống cắm trong đống rơm, bó rơm để bên) |
| `nuong_r_*` | Xưởng chạy, ảnh nền: gà, bò lụi, sườn, tôm trên vỉ, than hồng, rơm cháy thành tro, cá lóc cháy da. KHÔNG có ngọn lửa |
| `nuong_tren_*` | Lớp đè TRƯỚC lửa: nan vỉ, đồ nướng, con cá lóc + cây xiên (đúng từng điểm ảnh của `nuong_r`, còn lại trong suốt) |
| `nuong_lua.webp` | 1 lưỡi lửa trắng 64x96, Y HỆT lửa lò bánh mì (`lobanhmi_lua.webp`). Godot nhân màu theo color ramp |
| `nuong_tialua.webp` | Tia lửa (chấm trắng mềm 16x16) |
| `nuong_khoi.webp` | Cục khói (trắng, 128x128) cho hiệu ứng hạt. KHÔNG vẽ sẵn trong khung |

Thứ tự vẽ lúc chạy (z tăng dần):
1. `nuong_r`
2. hạt lửa vỉ (`luavi`) + hạt lửa rơm phía sau cá (`luarom_sau`)
3. `nuong_tren` (nan vỉ, đồ nướng, cá lóc đè lên lửa nên lửa bốc lên từ dưới vỉ, sau con cá)
4. hạt lửa rơm phía trước cá (`luarom_truoc`) + tia lửa
5. 3 hiệu ứng khói

## Lửa = hạt Godot tự sinh, Y HỆT lửa lò bánh mì (Link 15:25), chỉ bật khi xưởng chạy
Từ 2026-11-11 15:25 bỏ cục lửa có màu sẵn + quầng sáng cũ. Lửa lấy đúng texture, blend, màu, góc, đường cong của lò bánh mì
(`godot/xuong/lobanhmi/README.md`, mục "Lửa trong lò"), chỉ đổi amount / scale / velocity cho vừa từng đám lửa. Link 2026-11-12: lò phóng to x1.25, cá lóc + rơm x1.2 cho dễ nhìn trong game, nên số lửa/khói bên dưới đã nhân theo (lò x1.25, rơm x1.2).

Chung cho cả 3 đám lửa: CPUParticles2D đặt ở tâm nền, `emission_shape = POINTS`, `emission_points` = danh sách điểm trong atlas,
local_coords = false. Material CanvasItemMaterial `blend_mode = ADD`, `light_mode = UNSHADED`:
- lifetime 0.7 s, preprocess 0.7 s, explosiveness 0, randomness 0.5
- direction (0, -1), spread 10°, gravity (0, -7.5) cho lửa vỉ, (0, -7.2) cho lửa rơm
- angle -14° → 14°, angular_velocity -45 → 45 °/s
- split_scale = true. scale_curve_x: 0 → 0.75, 0.2 → 1.0, 0.6 → 0.7, 1 → 0.3. scale_curve_y: 0 → 0.45, 0.2 → 1.0, 0.7 → 1.2, 1 → 0.9
- color_ramp (màu, alpha): 0 #ff6418 0 · 0.1 #f25616 0.42 · 0.35 #d83e0e 0.38 · 0.65 #a2260a 0.26 · 1 #3c0802 0
- Ban ngày và ban đêm dùng chung số này.

| Đám lửa | Điểm phát | amount | initial_velocity | scale_amount (nếu 1 đơn vị = 1 px; ảnh scale 1/9 thì nhân thêm 9) |
|---|---|---|---|---|
| Lửa mỡ trên vỉ | `luavi` (12 điểm dưới đồ nướng), node dời lên (0, -2) cho lửa bắt đầu ngay nan vỉ (sau phóng to: (0, -2.5)) | 10 | 5.6 → 10.6 | 0.0248 → 0.0428 (lưỡi rộng 1.6 → 2.75 đơn vị) |
| Lửa rơm sau cá | `luarom_sau` (16 điểm quanh chân xiên) | 22 | 4.2 → 7.8 | 0.0302 → 0.0518 (lưỡi rộng 1.9 → 3.4 đơn vị) |
| Lửa rơm trước cá | `luarom_truoc` (16 điểm quanh chân xiên) | 22 | 4.2 → 7.8 | 0.0302 → 0.0518 |

Tia lửa (giữ như cũ): `luarom_truoc`, texture `nuong_tialua.webp`, amount 3, lifetime 0.9 s, velocity 12, spread 35°, gravity (0, -4.8),
scale (x 1/9) 0.12 → 0.036, color ramp `#ffe090 a1 → #ffa040 a0.9 (50%) → #ff6020 a0`, blend Mix.
Lửa vỉ ít và nhỏ, chỉ lâu lâu liếm lên giữa mấy miếng thịt khi mỡ nhỏ xuống (Link 23:46: nướng chứ không phải đốt). Lửa rơm to hơn lò bánh mì một chút cho thấy rõ trên nền sáng. Lửa rơm cố ý nhỏ và thưa, chừa tro với rơm cháy đen lộ ra (Link 11:45 và 11:59: không phải đống lửa bùng).
Than hồng và ánh hắt sáng đã nằm sẵn trong `nuong_r` (đứng yên), không cần hạt.

Nền: từ 2026-11-11 15:09 nền y hệt hàng chả: cao bằng nền nhà (2.4), bo tròn 4 góc như nền nhà kho, thành đất nện chân hơi loe. Đáy nền nằm đúng mặt đất, mọi toạ độ trong atlas đã tính phần nền cao này rồi, không cần cộng gì thêm.

`atlas.json`: khoá = tên + d/n (vd `trend`, `id`, `rn`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x2 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.
Điểm phát khói, cùng hệ toạ độ, dạng [x, y] (điểm phát lửa là danh sách [[x, y], ...]):
- `khoi1`: trên vỉ, nửa trái lò (chỗ gà kẹp + bò lụi)
- `khoi2`: trên vỉ, nửa phải lò (sườn + tôm)
- `khoi3`: trên đống rơm cháy quanh cá lóc

## Khói vỉ nướng (2 cái, ở `khoi1` và `khoi2`, chỉ bật khi xưởng chạy)
CPUParticles2D (hoặc GPUParticles2D), vẽ trên sprite lò (z cao hơn), không ăn ánh sáng:
- texture `nuong_khoi.webp`, amount 14, lifetime 2.6 s, preprocess 2.6 s, randomness 0.2
- direction (0, -1), spread 10°, initial velocity 12.5 đơn vị/s, gravity (-3.75, 0) (khói bốc lên rồi dạt sang trái)
- scale: 1/9 nhân đường cong 0.25 → 2.38 theo tuổi hạt
- color ramp alpha: 0 → 0.38 (8%) → 0.22 (50%) → 0 (100%) (khói mỡ nướng dày hơn khói bếp củi)
- màu nhân: ngày #d6d3cd, đêm #9a9aa0

## Khói rơm (1 cái, ở `khoi3`, chỉ bật khi xưởng chạy)
- texture `nuong_khoi.webp`, amount 12, lifetime 2.2 s, preprocess 2.2 s, randomness 0.25
- direction (0, -1), spread 8°, initial velocity 16.8 đơn vị/s, gravity (-4.2, 0)
- scale: 1/9 nhân đường cong 0.22 → 2.04 theo tuổi hạt
- color ramp alpha: 0 → 0.35 (8%) → 0.2 (50%) → 0 (100%)
- màu nhân: ngày #d2ccbf (hơi ngả vàng của rơm), đêm #96949a

GIF xem thử (xem/cong-trinh/lo-nuong-lua-hat-{d,n}.gif) vẽ lửa + khói đúng theo các số này và đúng thứ tự vẽ ở trên (src/nuong/gif.py).

Nguồn: src/nuong/nuong3d.py (mô hình 3D, điểm phát fire_points/emitters), src/nuong/tren.py (lớp đè trước lửa), src/nuong/export.py (xuất ảnh + cục lửa, tia lửa, khói), src/nuong/gif.py (GIF xem thử).
Than hồng tự phát sáng nhờ móc K.EMIT trong src/kho/kho3d.py.

Muốn xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/nuong/export.py OUTDIR OUTDIR/atlas.json 3` (tối đa 3 việc song song, 4 việc là hết RAM). Đổi hình khối thì xoá OUTDIR/raw trước khi xuất lại.

Đèn trên cột: cây đèn dầu xanh mảnh chai treo gọng dây sắt (Link 10:00), dùng chung code với lò bánh mì (src/lobanhmi/lobanhmi3d.py dendau_hang), ngày tắt, đêm thắp.
