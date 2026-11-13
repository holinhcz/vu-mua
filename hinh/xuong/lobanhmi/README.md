# Lò bánh mì (xưởng "bakery", 2x2 ô) – ảnh cho Godot

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm (đèn dầu + lò sáng, độ sáng đêm theo chuẩn nhà tranh/kho).

| File | Dùng khi |
|---|---|
| `lobanhmi_i_*` | Xưởng nghỉ, nguyên cảnh (cửa lò đóng, xẻng dựa bên miệng lò) |
| `lobanhmi_r_*` | Xưởng chạy, phần đứng yên (lò, bàn, giàn bánh, nền). KHÔNG có xẻng, KHÔNG có lửa |
| `lobanhmi_lua.webp`, `lobanhmi_che_*` | Lửa trong lò = hiệu ứng hạt, xem mục "Lửa trong lò" |
| `lobanhmi_xeng_*`, `lobanhmi_xengbong_*`, `lobanhmi_xengdo`, `lobanhmi_canhdo`, `lobanhmi_xeng.gdshader` | Xẻng gỗ + ổ bánh trượt vô lò rồi rút ra = 1 ảnh Godot tự trượt, xem mục "Xẻng" |
| `lobanhmi_khoi.webp` | Cục khói (trắng, 128x128) cho hiệu ứng hạt. KHÔNG vẽ sẵn trong ảnh |

Lúc chạy: vẽ `lobanhmi_r` → hạt lửa → `lobanhmi_che` → `lobanhmi_xengbong` → `lobanhmi_xeng` → khói.

Nền: từ 2026-11-11 nền cao bằng nền nhà (2.4), bo tròn 4 góc như nền nhà. Đáy nền nằm đúng mặt đất, mọi toạ độ trong atlas đã tính phần nền cao này rồi, không cần cộng gì thêm.

`atlas.json`: khoá = tên + d/n (vd `id`, `rn`, `xengd`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x2 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.
Khoá `khoi` = [x, y] miệng ống khói (điểm phát khói), khoá `lua` = các điểm phát lửa, cùng hệ toạ độ.

## Khói (hiệu ứng riêng, chỉ bật khi xưởng chạy)
CPUParticles2D (hoặc GPUParticles2D) đặt ở `khoi`, vẽ trên sprite lò (z cao hơn), không ăn ánh sáng:
- texture `lobanhmi_khoi.webp`, amount 16, lifetime 2.4 s, preprocess 2.4 s, randomness 0.2
- direction (0, -1), spread 4°, initial velocity 14 đơn vị/s, gravity (-3.5, 0) (khói bay lên rồi dạt sang trái)
- scale: 1/9 nhân đường cong 0.2 → 2.0 theo tuổi hạt (đầu ~3 đơn vị, cuối ~28 đơn vị)
- color ramp alpha: 0 → 0.42 (8%) → 0.25 (50%) → 0 (100%)
- màu nhân: ngày #cecbc6, đêm #96969c
GIF xem thử (xem/cong-trinh/lo-banh-mi-chay-anim-{d,n}.gif) vẽ khói đúng theo các số này.

Nguồn: src/lobanhmi/lobanhmi3d.py (mô hình 3D), src/lobanhmi/export.py (xuất ảnh + cục khói + lưỡi lửa + ảnh che), src/lobanhmi/luafx.py (bộ số lửa, mặt nạ miệng lò, giả lập), src/lobanhmi/xengfx.py (ảnh xẻng + độ sâu).

Muốn xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/lobanhmi/export.py OUTDIR OUTDIR/atlas.json 3` (3 việc song song, 4 việc là hết RAM).

## Đèn trên cột
Từ 2026-11-11 10:05 cây đèn treo trên cột là ĐÈN DẦU (thủy tinh xanh chai) trong gọng dây sắt, thay cho đèn bão. Ảnh riêng của đèn dầu: `godot/xuong/dendau/` (512 + 4k/). Thư mục `den/` (đèn bão 512) giữ lại để dùng chỗ khác.

## Lửa trong lò (hiệu ứng riêng, Godot tự sinh, chỉ bật khi xưởng chạy)
Từ 2026-11-11 ảnh KHÔNG còn vẽ ngọn lửa. Ảnh lò chỉ giữ phần đứng yên: than hồng, khúc củi cháy dở, vách lò sáng.
Ngọn lửa là hạt do Godot tự sinh, giống khói:

| File / khoá | Là gì |
|---|---|
| `lobanhmi_lua.webp` | 1 lưỡi lửa trắng 64x96 (gốc tròn, ngọn nhọn hơi cong). Godot nhân màu theo color ramp |
| `lobanhmi_che_d/_n.webp` + khoá `ched`/`chen` | Phần lò nằm TRƯỚC lửa quanh miệng lò (mặt vòm, bậu, cột), chỗ miệng lò trong suốt. Vẽ đè lên lửa nên lửa không thò ra ngoài vòm |
| khoá `lua` | 24 điểm phát [x, y] trên lớp than (2 hàng so le), cùng hệ toạ độ với các ảnh |

**Thứ tự vẽ khi chạy:** `lobanhmi_r` → hạt lửa → `lobanhmi_che` → xẻng (bóng rồi xẻng) → khói.

**CPUParticles2D** đặt ở tâm nền, `emission_shape = POINTS`, `emission_points` = khoá `lua`. Material là CanvasItemMaterial `blend_mode = ADD`, `light_mode = UNSHADED`:
- amount 54, lifetime 0.7 s, preprocess 0.7 s, explosiveness 0, randomness 0.5, local_coords = false
- direction (0, -1), spread 10°, initial_velocity 4.5 → 8.5 đơn vị/s, gravity (0, -6) (khí nóng bốc nhanh dần)
- angle -14° → 14°, angular_velocity -45 → 45 °/s (lưỡi lửa nghiêng và đung đưa)
- scale_amount 0.0216 → 0.0413 (lưỡi lửa rộng 1.4 → 2.6 đơn vị, nếu 1 đơn vị = 1 px; scale ảnh lò 1/9 thì nhân thêm 9)
- split_scale = true. scale_curve_x: 0 → 0.75, 0.2 → 1.0, 0.6 → 0.7, 1 → 0.3. scale_curve_y: 0 → 0.45, 0.2 → 1.0, 0.7 → 1.2, 1 → 0.9 (lưỡi lửa vươn cao rồi thon lại)
- color_ramp (màu, alpha): 0 #ff6418 0 · 0.1 #f25616 0.42 · 0.35 #d83e0e 0.38 · 0.65 #a2260a 0.26 · 1 #3c0802 0
  Cộng sáng nên chỗ nhiều hạt chồng lên (sát than) tự ngả vàng cam, ngọn đỏ thẫm. Lửa đỏ cam, không vàng (Link 10:47).
- Ban ngày và ban đêm dùng chung số này.

GIF xem thử `xem/cong-trinh/lo-banh-mi-lua-hieu-ung.gif` giả lập đúng các số này (src/lobanhmi/luafx.py `simulate`).

### Cách làm lửa hạt cho lò khác (lò nướng, lò bánh quê, bếp củi...)
1. Trong file 3D, cho biến tắt ngọn lửa (như `LB_LUA=no`). Than, củi, vách sáng vẫn vẽ trong ảnh. Xuất mọi ảnh với lửa tắt.
2. `luafx.lua_tex()` cho ảnh lưỡi lửa, `LUA_P` cho bộ số (chỉnh amount/velocity/scale theo cỡ đám lửa).
3. Điểm phát = các điểm trên lớp than đổi qua toạ độ màn hình (`luafx.emit_pts`).
4. Mặt nạ miệng lò: `luafx.mieng_mask` đặt 1 tấm "cửa sổ" vô hình ngay trong miệng lò rồi render cả cảnh, chỗ nào thấy tấm đó là chỗ thấy lửa. Lấy ảnh lò trừ chỗ đó ra = ảnh `che`, vẽ đè lên lửa.
5. Giả lập bằng `luafx.simulate` ra GIF cho Link xem trước khi xuất.

## Xẻng (1 ảnh, Godot tự trượt, chỉ bật khi xưởng chạy)
Từ 2026-11-11 bỏ 48 khung `f` cũ. Xẻng là vật cứng chỉ trượt thẳng, nên Godot dời 1 ảnh, còn chỗ nào bị vòm lò, vách trong miệng lò hay cây cột che thì shader tự ẩn bằng phép so độ sâu.

| File / khoá | Là gì |
|---|---|
| `lobanhmi_xeng_d/_n.webp` + khoá `xengd`/`xengn` | Xẻng + ổ bánh ở chỗ rút ra hết (ins = 0), đủ mọi pixel kể cả phần sẽ chui vô lò |
| `lobanhmi_xengdo.webp` | Độ sâu của từng pixel xẻng (16 bit: R*256+G, A = có pixel). Cùng khung với `xengd` |
| `lobanhmi_canhdo.webp` + khoá `canhdo` | Độ sâu của cảnh (lò, bậu, cột) quanh đường xẻng đi |
| `lobanhmi_xengbong_d/_n.webp` + khoá `xengbongd`/`xengbongn` | Bóng xẻng đổ trên bậu lò. Màu đen, độ đậm ở A, độ sâu ở R,G |
| khoá `xeng_move` | `ins` (đi sâu nhất 6.5), `period` 2.4 s, `step` (đơn vị màn hình dời cho mỗi 1 ins), `dk`, `d0`, `dr` (giải mã độ sâu) |
| `lobanhmi_xeng.gdshader` | Shader dùng chung cho xẻng và bóng |

**Import trong Godot:** `lobanhmi_xengdo`, `lobanhmi_canhdo`, `lobanhmi_xengbong_*` để Compress = Lossless, tắt mipmaps, texture_filter = Nearest (chúng chứa số độ sâu, nén hay lọc là sai). `lobanhmi_xeng_*` import bình thường.

**Dựng node:** 2 Sprite2D, `centered = false`, cùng material ShaderMaterial(`lobanhmi_xeng.gdshader`):
- Bóng: texture `lobanhmi_xengbong_<d|n>`, `is_shade = true`, `rest_rect` = khoá `xengbong<d|n>`.
- Xẻng: texture `lobanhmi_xeng_<d|n>`, `is_shade = false`, `rest_rect` = khoá `xeng<d|n>`, `xeng_do` = `lobanhmi_xengdo`.
- Cả 2: `canh_do` = `lobanhmi_canhdo`, `canh_rect` = khoá `canhdo`, `step`, `dk`, `d0`, `dr` lấy từ `xeng_move`.

**Mỗi khung hình:** `ins = xeng_move.ins * (0.5 - 0.5 * cos(TAU * t / xeng_move.period))`. Đặt uniform `ins` cho cả 2 sprite, và `position = tâm nền + rest_rect.xy + step * ins` (nhân scale nếu 1 đơn vị khác 1 px). Xẻng đẩy vô êm, dừng sâu nhất ở giữa chu kỳ, rồi rút ra.

GIF xem thử `xem/cong-trinh/lo-banh-mi-chay-anim-{d,n}.gif` dựng lại từ chính các file xuất ra theo đúng cách trên (lửa + che + bóng + xẻng + khói).

### Cách làm vật trượt cho xưởng khác
Vật cứng chỉ trượt thẳng (xẻng, khay, nắp...) thì làm như trên: `kho3d.KEEP_POS = True` để lấy toạ độ 3D từng pixel, render vật một mình (cảnh ẩn) ra ảnh + độ sâu, render cảnh không có vật ra độ sâu quanh đường đi, rồi dùng lại `lobanhmi_xeng.gdshader`. Xem `src/lobanhmi/xengfx.py`.
