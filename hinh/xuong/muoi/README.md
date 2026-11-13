# Vại muối dưa (xưởng "muoi", 2x2 ô) – ảnh cho Godot

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm.

| File | Dùng khi |
|---|---|
| `muoi_i_*` | Xưởng nghỉ, nguyên cảnh: đồ đang làm dọn hết (nia trống, bao muối cột miệng, không cải tươi/cà/cá), vại dưa đậy mo cau, bếp tro nguội, nồi đậy nắp |
| `muoi_r_*` | Xưởng chạy, phần đứng yên: than hồng + 4 thanh củi dưới bếp kiềng, nắp nồi để dưới đất, nước muối trong nồi (chưa có bọt), cải phơi, cà, cá, trứng muối... |
| `muoi_f0..f11_*` | Nước muối sôi: bọt nước tròn phồng lên rồi vỡ + hạt bọt chạy quanh thành nồi. Chu kỳ 1,2 s, 12 khung (10 khung/s), lặp liền |
| `muoi_che_*` | Phần cảnh quanh bếp ĐỨNG TRƯỚC lửa (nồi, vòng kiềng, chân kiềng, củi), chỗ thấy lửa thì trong suốt. Vẽ ĐÈ lên lửa |
| `muoi_lua.webp` | 1 lưỡi lửa trắng 64x96, Y HỆT lửa lò bánh mì. Godot nhân màu theo color ramp |
| `muoi_hoi.webp` | Cục hơi nước (trắng, mềm, 128x128). KHÔNG vẽ sẵn trong khung |

Thứ tự vẽ lúc chạy: `muoi_r` → lửa (particles) → `muoi_che` → khung `f` hiện tại → hơi (particles).
Lúc nghỉ: chỉ `muoi_i`, tắt hết particles.

`atlas.json`: khoá = tên + d/n (vd `f5d`, `ched`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x2 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.
Điểm phát particles (cùng hệ toạ độ):
- `lua`: 24 điểm trải khắp lớp than dưới nồi (3 vòng 6/8/10 điểm)
- `hoi`: 15 điểm trên mặt nước muối trong nồi

## Lửa dưới bếp kiềng (Godot tự sinh, chỉ bật khi xưởng chạy)
Lấy lửa lò bánh mì (`godot/xuong/lobanhmi/README.md`, mục "Lửa trong lò"): texture, blend, màu, góc, đường cong scale GIỐNG HỆT.
Đổi cho vừa khoảng trống thấp dưới đáy nồi: lửa ngắn hơn, dày hơn, xoè rộng hơn (liếm đáy nồi).
Từ 2026-11-12 bếp + nồi vẽ to ra 1,4 lần cho dễ thấy trong game, nên lửa và hơi dưới đây cũng to ra 1,4 lần. **Link 2026-11-12 22:31 đồng bộ: số lửa giờ theo chuẩn kiềng trong `godot/xuong/LUA.md` (= bếp củi, lò rang, lò đường: 55 hạt mỗi bếp, lifetime 0.55, tốc độ 3.5 → 6.5, gravity -5, scale 0.65 → 1.2).**

**CPUParticles2D** đặt ở tâm nền, `emission_shape = POINTS`, `emission_points` = khoá `lua`. Material CanvasItemMaterial `blend_mode = ADD`, `light_mode = UNSHADED`:
- amount 55, lifetime 0.55 s, preprocess 0.55 s, explosiveness 0, randomness 0.5, local_coords = false
- direction (0, -1), spread 22°, initial_velocity 3.5 → 6.5 đơn vị/s, gravity (0, -5)
- angle -14° → 14°, angular_velocity -45 → 45 °/s
- scale_amount 0.0234 → 0.0432 (lưỡi lửa rộng 1.45 → 2.7 đơn vị nếu 1 đơn vị = 1 px; scale ảnh xưởng 1/9 thì nhân thêm 9)
- split_scale = true. scale_curve_x: 0 → 0.75, 0.2 → 1.0, 0.6 → 0.7, 1 → 0.3. scale_curve_y: 0 → 0.45, 0.2 → 1.0, 0.7 → 1.2, 1 → 0.9
- color_ramp (màu, alpha): 0 #ff6418 0 · 0.1 #f25616 0.42 · 0.35 #d83e0e 0.38 · 0.65 #a2260a 0.26 · 1 #3c0802 0 (đỏ cam, không vàng)
- Ngày và đêm dùng chung số này.
- KHÔNG dùng clip_children. Che lửa bằng `muoi_che` vẽ đè (như lò bánh mì, hàng chả). Lửa bay lên chạm đáy nồi thì bị nồi che,
  chỉ thấy lửa giữa 3 chân kiềng dưới đáy nồi và vài lưỡi liếm ra 2 bên hông nồi.

## Hơi nước (ở `hoi`, chỉ bật khi xưởng chạy)
CPUParticles2D, `emission_shape = POINTS`, `emission_points` = khoá `hoi`, vẽ trên khung `f`, không ăn ánh sáng:
- texture `muoi_hoi.webp`, amount 22, lifetime 1.8 s, preprocess 1.8 s, randomness 0.3
- direction (0, -1), spread 25°, initial velocity 7 đơn vị/s, gravity (-1.5, -1) (bốc lên rồi dạt nhẹ sang trái)
- scale: 1/9 nhân đường cong 0.42 → 2.24 theo tuổi hạt
- color ramp alpha: 0 → 0.60 (12%) → 0.34 (50%) → 0 (100%)
- màu nhân: ngày #ffffff, đêm #c8c8d0

Đèn trên cột: ĐÈN DẦU (thủy tinh xanh chai, như các xưởng khác). Ảnh riêng của đèn: `godot/xuong/dendau/`.
Nền: cao bằng nền nhà (2.4), bo tròn 4 góc, mặt phẳng. Toạ độ atlas đã tính phần nền cao.
Vật liệu sơ cấp: kệ, giàn nia, ghế bằng tre; vại, lu, khạp bằng sành; nồi nhôm trên bếp kiềng sắt.

GIF xem thử vẽ đúng các số trên từ đúng các file này: xem/cong-trinh/vai-muoi-dua-chay-{ngay,dem}.gif (cả cảnh),
xem/cong-trinh/vai-muoi-dua-chay-can{,-dem}.gif (zoom bếp + nồi).

Nguồn: src/muoi/muoi3d.py (mô hình 3D), src/muoi/export.py (xuất ảnh), src/muoi/gif.py (GIF xem thử, lửa qua src/lobanhmi/luafx.py `simulate`).
Xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/muoi/export.py OUTDIR 3` (xoá OUTDIR/raw trước nếu đổi hình), ~20 phút.
GIF xem thử: `python3 src/muoi/gif.py godot/xuong/muoi OUT [crop]`.
