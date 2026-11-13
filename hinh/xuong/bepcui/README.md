# Bếp củi (xưởng "bepcui", 2x2 ô) – ảnh cho Godot

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm.

| File | Dùng khi |
|---|---|
| `bepcui_i_*` | Xưởng nghỉ, nguyên cảnh: bếp tro nguội, nồi canh đậy nắp đất, chảo trống, bàn món + bàn sơ chế dọn trống (chỉ còn chồng chén) |
| `bepcui_r_*` | Xưởng chạy, phần đứng yên: than hồng + củi dưới 2 bếp, nồi canh chua (chưa có bọt), chảo rau muống xào bò (chưa có sạn), 4 món trên bàn, thớt ba rọi + dao, bó rau muống, rổ cà chua |
| `bepcui_f0..f15_*` | Cái sạn tre đảo một vòng trong chảo + bọt canh phồng lên rồi vỡ. Chu kỳ 1,6 s, 16 khung (10 khung/s), lặp liền. Mỗi khung chỉ chứa phần pixel thay đổi so với `bepcui_r` |
| `bepcui_che_*` | Phần cảnh quanh 2 bếp ĐỨNG TRƯỚC lửa (nồi, chảo, ông táo, củi), chỗ thấy lửa thì trong suốt. Vẽ ĐÈ lên lửa |
| `bepcui_lua.webp` | 1 lưỡi lửa trắng, Y HỆT lửa lò bánh mì. Godot nhân màu theo color ramp |
| `bepcui_hoi.webp` | Cục hơi mềm trắng 128x128, dùng cho cả hơi nồi canh (`hoi`) và khói xào bốc lên từ chảo (`khoi`) |

Thứ tự vẽ lúc chạy: `bepcui_r` → lửa (particles) → `bepcui_che` → khung `f` hiện tại → hơi + khói xào (particles).
Lúc nghỉ: chỉ `bepcui_i`, tắt hết particles.

`atlas.json`: khoá = tên + d/n (vd `f5d`, `ched`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x2 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.
Điểm phát particles (cùng hệ toạ độ):
- `lua`: 42 điểm trải khắp 2 lớp than (mỗi bếp 3 vòng 5/7/9 điểm)
- `hoi`: 15 điểm trên mặt nồi canh chua
- `khoi`: 12 điểm trên đồ xào trong chảo

## Lửa dưới 2 bếp (Godot tự sinh, chỉ bật khi xưởng chạy)
Lấy lửa lò bánh mì (`godot/xuong/lobanhmi/README.md`, mục "Lửa trong lò"): texture, blend, màu, góc, đường cong scale GIỐNG HỆT.
Một CPUParticles2D cho cả 2 bếp, đặt ở tâm nền, `emission_shape = POINTS`, `emission_points` = khoá `lua`.
Material CanvasItemMaterial `blend_mode = ADD`, `light_mode = UNSHADED`:
- amount 110, lifetime 0.55 s, preprocess 0.55 s, explosiveness 0, randomness 0.5, local_coords = false
- direction (0, -1), spread 22°, initial_velocity 3.5 → 6.5 đơn vị/s, gravity (0, -5)
- angle -14° → 14°, angular_velocity -45 → 45 °/s
- scale_amount 0.0234 → 0.0432 (lưỡi lửa rộng 1.45 → 2.7 đơn vị nếu 1 đơn vị = 1 px; scale ảnh xưởng 1/9 thì nhân thêm 9)
- split_scale = true. scale_curve_x: 0 → 0.75, 0.2 → 1.0, 0.6 → 0.7, 1 → 0.3. scale_curve_y: 0 → 0.45, 0.2 → 1.0, 0.7 → 1.2, 1 → 0.9
- color_ramp (màu, alpha): 0 #ff6418 0 · 0.1 #f25616 0.42 · 0.35 #d83e0e 0.38 · 0.65 #a2260a 0.26 · 1 #3c0802 0 (đỏ cam, không vàng)
- Ngày và đêm dùng chung số này.
- KHÔNG dùng clip_children. Che lửa bằng `bepcui_che` vẽ đè. Lửa bay lên chạm đáy nồi/chảo thì bị che,
  chỉ thấy lửa giữa 3 ông táo, ở miệng bếp phía trước (chỗ đút củi) và vài lưỡi liếm ra 2 bên hông nồi/chảo.

## Hơi nồi canh (ở `hoi`) và khói xào (ở `khoi`), chỉ bật khi xưởng chạy
2 CPUParticles2D, `emission_shape = POINTS`, vẽ trên khung `f`, không ăn ánh sáng, cùng texture `bepcui_hoi.webp`:
- Hơi canh: amount 16, lifetime 2.0 s, preprocess 2.0 s, randomness 0.3, direction (0, -1), spread 25°, initial velocity 6,
  gravity (-1.5, -1), scale 1/9 nhân đường cong 0.4 → 1.8, alpha 0 → 0.42 (12%) → 0.24 (50%) → 0, màu ngày #ffffff, đêm #c8c8d0
- Khói xào: amount 16, lifetime 1.5 s, preprocess 1.5 s, randomness 0.3, direction (0, -1), spread 30°, initial velocity 6.5,
  gravity (-1, -1), scale 1/9 nhân 0.4 → 2.0, alpha 0 → 0.45 (15%) → 0.26 (50%) → 0, màu ngày #e4e0da, đêm #a8a8b0

Đèn trên cột: ĐÈN DẦU (thủy tinh xanh chai, như các xưởng khác). Ảnh riêng của đèn: `godot/xuong/dendau/`.
Nền: cao bằng nền nhà (2.4), bo tròn 4 góc, mặt phẳng. Toạ độ atlas đã tính phần nền cao.
Vật liệu sơ cấp: bệ + ông táo đất, nồi đất, chén dĩa sành, kệ/bàn/ghế tre, lu da lươn đậy nắp gỗ.
Đồ trong xưởng vẽ to cho dễ nhìn ở cỡ game (bếp x1.45, bàn x1.3–1.4).

GIF xem thử vẽ đúng các số trên từ đúng các file này: xem/cong-trinh/bep-cui-chay-{ngay,dem}.gif (cả cảnh),
xem/cong-trinh/bep-cui-chay-can{,-dem}.gif (zoom 2 bếp).

Nguồn: src/bepcui/bepcui3d.py (mô hình 3D), src/bepcui/export.py (xuất ảnh), src/bepcui/gif.py (GIF xem thử, lửa qua src/lobanhmi/luafx.py `simulate`).
Xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/bepcui/export.py OUTDIR 3` (xoá OUTDIR/raw trước nếu đổi hình), ~30 phút.
GIF xem thử: `python3 src/bepcui/gif.py godot/xuong/bepcui OUT [crop]`.
