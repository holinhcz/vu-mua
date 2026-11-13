# Lò rang hạt (xưởng "rang", 2x2 ô) – ảnh cho Godot

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm.

Sản phẩm của xưởng (theo game): đậu phộng rang, hạt điều rang, bắp rang, điều rang muối, muối đậu phộng, mè rang, hạt hướng dương rang.

| File | Dùng khi |
|---|---|
| `rang_i_*` | Xưởng nghỉ, nguyên cảnh: bếp tro nguội, chảo gang trống, nồi gang bắp đậy nắp, thúng trống, bàn tre dọn trống (chỉ còn 2 hũ đậy nắp) |
| `rang_r_*` | Xưởng chạy, phần đứng yên: than hồng + củi dưới 2 bếp, chảo đậu phộng đang rang (chưa có sạn), nồi bắp rang đầy (CHƯA có nắp), thúng đậu rang xong, bàn bày đậu phộng / điều rang muối / bắp rang / mè / hướng dương / hũ muối đậu phộng |
| `rang_f0..f23_*` | Cái sạn tre đảo một vòng trong chảo + hạt đậu lăn theo, nắp nồi bắp nảy lên 2 lần (bắp nổ) + vài hạt bắp văng lên miệng nồi. Chu kỳ 2,4 s, 24 khung (10 khung/s), lặp liền. Mỗi khung chỉ chứa phần pixel thay đổi so với `rang_r` (nắp nồi nằm trong khung) |
| `rang_che_*` | Phần cảnh quanh 2 bếp ĐỨNG TRƯỚC lửa (chảo, nồi, ông táo, củi), chỗ thấy lửa thì trong suốt. Vẽ ĐÈ lên lửa |
| `rang_lua.webp` | 1 lưỡi lửa trắng, Y HỆT lửa lò bánh mì. Godot nhân màu theo color ramp |
| `rang_khoi.webp` | Cục khói mềm trắng 128x128, khói rang bốc lên từ chảo (`khoi`) |

Thứ tự vẽ lúc chạy: `rang_r` → lửa (particles) → `rang_che` → khung `f` hiện tại → khói rang (particles).
Lúc nghỉ: chỉ `rang_i`, tắt hết particles.

`atlas.json`: khoá = tên + d/n (vd `f5d`, `ched`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x2 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.
Điểm phát particles (cùng hệ toạ độ):
- `lua`: 42 điểm trải khắp 2 lớp than (mỗi bếp 3 vòng 5/7/9 điểm)
- `khoi`: 15 điểm trên lớp đậu trong chảo

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
- KHÔNG dùng clip_children. Che lửa bằng `rang_che` vẽ đè. Lửa bay lên chạm đáy chảo/nồi thì bị che,
  chỉ thấy lửa giữa 3 ông táo, ở miệng bếp phía trước (chỗ đút củi) và vài lưỡi liếm ra 2 bên hông chảo/nồi.

## Khói rang (ở `khoi`), chỉ bật khi xưởng chạy
1 CPUParticles2D, `emission_shape = POINTS`, vẽ trên khung `f`, không ăn ánh sáng, texture `rang_khoi.webp`:
- amount 14, lifetime 1.8 s, preprocess 1.8 s, randomness 0.3, direction (0, -1), spread 28°, initial velocity 6,
  gravity (-1, -1), scale 1/9 nhân đường cong 0.5 → 2.4, alpha 0 → 0.32 (15%) → 0.18 (50%) → 0, màu ngày #ece6dc, đêm #a8a8b0
- Bếp nằm ngoài chái nên khói không bay xuyên mái lá.

Đèn trên cột: ĐÈN DẦU (thủy tinh xanh chai, như các xưởng khác). Ảnh riêng của đèn: `godot/xuong/dendau/`.
Nền: cao bằng nền nhà (2.4), bo tròn 4 góc, mặt phẳng. Toạ độ atlas đã tính phần nền cao.
Vật liệu sơ cấp: bệ + ông táo đất, chảo + nồi gang, ghế/bàn/thúng/mẹt tre, bao bố đay, lu da lươn đậy nắp gỗ.
Ghế tre đặt chính giữa trước bệ, giữa 2 miệng lò (chỗ người rang ngồi); trước bếp không để gì khác.

GIF xem thử vẽ đúng các số trên từ đúng các file này: xem/cong-trinh/lo-rang-hat-chay-{d,n}.gif (cả cảnh),
xem/cong-trinh/lo-rang-hat-chay-can-{d,n}.gif (zoom 2 bếp).

Nguồn: src/rang/rang3d.py (mô hình 3D), src/rang/export.py (xuất ảnh), src/rang/gif.py (GIF xem thử, lửa qua src/lobanhmi/luafx.py `simulate`).
Xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/rang/export.py OUTDIR 3` (xoá OUTDIR/raw trước nếu đổi hình), ~30 phút.
GIF xem thử: `python3 src/rang/gif.py godot/xuong/rang OUT [crop]`.
