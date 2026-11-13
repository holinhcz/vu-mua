# Cối xay (xưởng "mill", 2x1 ô) – ảnh cho Godot

Mỗi ảnh là 1 file riêng, vẽ 9 px cho mỗi đơn vị màn hình của game (1 ô = 64x32 đơn vị, nên 1 ô = 576x288 px).
Hậu tố `_d` là ban ngày, `_n` là ban đêm.

| File | Dùng khi |
|---|---|
| `coixay_i_*` | Xưởng nghỉ, nguyên cảnh |
| `coixay_r_*` | Xưởng chạy, phần đứng yên (nền) |
| `coixay_x0..x23_*` | Cối xay quay: giàng, tai cối, gạo chảy theo máng xuống thúng. Chu kỳ 2,4 s, 24 khung (10 khung/s) |
| `coixay_g0..g11_*` | Cối giã: cần nhấc lên rồi dập, gạo văng. Chu kỳ 1,5 s, 12 khung (8 khung/s) |

Lúc chạy: vẽ `coixay_r`, rồi đè khung `x` hiện tại, rồi khung `g` hiện tại (khung đè chỉ chứa phần thay đổi, nền trong suốt).

`atlas.json`: khoá = tên + d/n (vd `x5d`), giá trị = [x, y, rộng, cao] theo đơn vị màn hình game, tính từ tâm nền 2x1 ô
(tâm = điểm giữa của hình thoi nền). Trong Godot: vị trí sprite = tâm ô * 1 + [x, y], scale = 1/9 nếu 1 đơn vị = 1 px.

Đèn trên cột: từ 2026-11-11 là ĐÈN DẦU (thủy tinh xanh chai, như lò bánh mì và các xưởng khác), không còn đèn bão. Ảnh riêng của đèn: `godot/xuong/dendau/`.

Nền: từ 2026-11-11 nền cao bằng nền nhà (2.4), bo tròn 4 góc như hàng chả, mặt phẳng. Đáy nền nằm đúng mặt đất, mọi toạ độ trong atlas đã tính phần nền cao này rồi.

Nguồn: src/coixay/coixay3d.py (mô hình 3D), src/coixay/export2.py (xuất ảnh).

Muốn xuất lại nét hơn (vd 18 px/đơn vị): `EXP_PXU=18 EXP_SS=1 python3 src/coixay/export2.py OUTDIR OUTDIR/atlas.json 4` (~15 phút).
