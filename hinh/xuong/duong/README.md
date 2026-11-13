# Lò đường (xưởng "duong", 2x2 ô) – ảnh cho Godot

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm.

Sản phẩm của xưởng (theo game): mật mía, đường thẻ, nước màu, kẹo dừa, kẹo đậu phộng.

| File | Dùng khi |
|---|---|
| `duong_i_*` | Xưởng nghỉ, nguyên cảnh: lò tro nguội, 2 chảo gang trống sạch, bàn chỉ còn khuôn trống + 2 mẹt chồng, lu mật đậy nắp gỗ |
| `duong_r_*` | Xưởng chạy, phần đứng yên: than hồng + củi dưới 2 chảo, chảo nước mía có lớp bọt (CHƯA có bong bóng sôi), chảo mật đặc (CHƯA có cây khuấy), bàn bày khuôn đường thẻ / đường thẻ gỡ khuôn / kẹo đậu phộng / kẹo dừa / chai nước màu / rổ đậu phộng, lu mật mở có gáo |
| `duong_f0..f23_*` | Bong bóng sôi phồng rồi vỡ trên 2 chảo (nước mía 3 lượt, mật 1 lượt mỗi vòng) + cây khuấy tre quấy một vòng trong chảo mật. Chu kỳ 2,4 s, 24 khung (10 khung/s), lặp liền. Mỗi khung chỉ chứa phần pixel thay đổi so với `duong_r` |
| `duong_che_*` | Phần cảnh quanh 2 bếp ĐỨNG TRƯỚC lửa (chảo, ông táo, củi), chỗ thấy lửa thì trong suốt. Vẽ ĐÈ lên lửa |
| `duong_lua.webp` | 1 lưỡi lửa trắng, Y HỆT lửa lò bánh mì. Godot nhân màu theo color ramp |
| `duong_hoi.webp` | Cục hơi mềm trắng 128x128, dùng cho hơi chảo nước mía (`hoi`) và hơi chảo mật (`hoi2`) |

Thứ tự vẽ lúc chạy: `duong_r` → lửa (particles) → `duong_che` → khung `f` hiện tại → hơi (particles).
Lúc nghỉ: chỉ `duong_i`, tắt hết particles.

`atlas.json`: khoá = tên + d/n (vd `f5d`, `ched`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x2 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.
Điểm phát particles (cùng hệ toạ độ):
- `lua`: 42 điểm trải khắp 2 lớp than (mỗi bếp 3 vòng 5/7/9 điểm)
- `hoi`: 15 điểm trên mặt chảo nước mía
- `hoi2`: 15 điểm trên mặt chảo mật

## Lửa dưới 2 bếp (Godot tự sinh, chỉ bật khi xưởng chạy)
Lấy lửa lò bánh mì (`godot/xuong/lobanhmi/README.md`, mục "Lửa trong lò"): texture, blend, màu, góc, đường cong scale GIỐNG HỆT.
Bếp to cỡ bếp củi nên số giống bếp củi (`godot/xuong/bepcui/README.md`).
Một CPUParticles2D cho cả 2 bếp, đặt ở tâm nền, `emission_shape = POINTS`, `emission_points` = khoá `lua`.
Material CanvasItemMaterial `blend_mode = ADD`, `light_mode = UNSHADED`:
- amount 110, lifetime 0.55 s, preprocess 0.55 s, explosiveness 0, randomness 0.5, local_coords = false
- direction (0, -1), spread 22°, initial_velocity 3.5 → 6.5 đơn vị/s, gravity (0, -5)
- angle -14° → 14°, angular_velocity -45 → 45 °/s
- scale_amount 0.0234 → 0.0432 (lưỡi lửa rộng 1.45 → 2.7 đơn vị nếu 1 đơn vị = 1 px; scale ảnh xưởng 1/9 thì nhân thêm 9)
- split_scale = true. scale_curve_x: 0 → 0.75, 0.2 → 1.0, 0.6 → 0.7, 1 → 0.3. scale_curve_y: 0 → 0.45, 0.2 → 1.0, 0.7 → 1.2, 1 → 0.9
- color_ramp (màu, alpha): 0 #ff6418 0 · 0.1 #f25616 0.42 · 0.35 #d83e0e 0.38 · 0.65 #a2260a 0.26 · 1 #3c0802 0 (đỏ cam, không vàng)
- Ngày và đêm dùng chung số này.
- KHÔNG dùng clip_children. Che lửa bằng `duong_che` vẽ đè. Lửa bay lên chạm đáy chảo thì bị che,
  chỉ thấy lửa giữa 3 ông táo, ở miệng bếp phía trước (chỗ đút củi) và vài lưỡi liếm ra 2 bên hông chảo.

## Hơi 2 chảo (ở `hoi` và `hoi2`), chỉ bật khi xưởng chạy
2 CPUParticles2D, `emission_shape = POINTS`, vẽ trên khung `f`, không ăn ánh sáng, cùng texture `duong_hoi.webp`:
- Hơi nước mía (`hoi`): amount 18, lifetime 2.2 s, preprocess 2.2 s, randomness 0.3, direction (0, -1), spread 26°, initial velocity 6,
  gravity (-1.2, -1), scale 1/9 nhân đường cong 0.6 → 2.8, alpha 0 → 0.40 (12%) → 0.22 (50%) → 0, màu ngày #ffffff, đêm #c8c8d0
- Hơi mật (`hoi2`): amount 10, lifetime 2.0 s, preprocess 2.0 s, randomness 0.3, direction (0, -1), spread 24°, initial velocity 5,
  gravity (-1, -1), scale 1/9 nhân 0.5 → 2.2, alpha 0 → 0.28 (15%) → 0.16 (50%) → 0, màu ngày #f2ece4, đêm #b0b0b8
- Lò nằm ngoài chái nên hơi không bay xuyên mái lá.

Đèn trên cột: ĐÈN DẦU (thủy tinh xanh chai, như các xưởng khác). Ảnh riêng của đèn: `godot/xuong/dendau/`.
Nền: cao bằng nền nhà (2.4), bo tròn 4 góc, mặt phẳng. Toạ độ atlas đã tính phần nền cao.
Vật liệu sơ cấp: bệ + ông táo đất, 2 chảo gang, ghế/bàn/thúng/mẹt/khuôn tre, cây gác tràm, 1 lu sành mật mía.
Ghế tre đặt chính giữa trước bệ, giữa 2 miệng lò; trước lò không để gì khác. Mía tím chất dưới chái, bã mía khô sau 2 chảo.

GIF xem thử vẽ đúng các số trên từ đúng các file này: xem/cong-trinh/lo-duong-chay-{d,n}.gif (cả cảnh),
xem/cong-trinh/lo-duong-chay-can-{d,n}.gif (zoom 2 bếp).

Nguồn: src/duong/duong3d.py (mô hình 3D), src/duong/export.py (xuất ảnh), src/duong/gif.py (GIF xem thử, lửa qua src/lobanhmi/luafx.py `simulate`).
Xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/duong/export.py OUTDIR 3` (xoá OUTDIR/raw trước nếu đổi hình), ~30 phút.
GIF xem thử: `python3 src/duong/gif.py godot/xuong/duong OUT [crop]`.
