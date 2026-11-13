# Xưởng – những thứ phải làm GIỐNG NHAU (đọc trước khi vẽ / sửa / xuất bất kỳ xưởng nào)

Link 2026-11-12: "đéo note lại làm đồng bộ à". Mọi thread vẽ xưởng đọc file này + `LUA.md` trước khi làm.
Link sửa chi tiết chung nào ở 1 xưởng thì GHI NGAY vào đây (kèm file mẫu), rồi mới làm tiếp.

## 1. Nền + khung
- Nền 2x2 cao 2.4 (bằng nền nhà), mặt trên phẳng, bo tròn 4 góc như nền hàng chả. Code: `src/xenuocep/ep3d.py` `ground()`.
  Ngoại lệ: ruộng muối không có nền.
- Ảnh xuất 9 px / đơn vị; khung ảnh `r` của xưởng 2x2 = khoảng 143 x 100 đơn vị (quán chè, bếp củi, lò rang, nồi kho đều vậy).
  Mở `godot/xuong/<xưởng>/atlas.json` khoá `rd` để so.
- Chái lá + cột tràm tròn: `CX.chai` (`src/coixay/coixay3d.py`), cột ở u .1 / 1.86, v .08 / .92. Không đồ nào đụng cột / mái.

## 2. Cỡ đồ (phải thấy được ở cỡ game)
- Ít đồ, đồ TO. Mỗi lần gửi hình phải kèm dải cỡ game 1x/2x/3x đặt cạnh 1 xưởng đã xong (vd `quanche_r_d.webp`).
- Nồi / chảo nấu chính: bán kính miệng khoảng 7.5 đến 8 đơn vị = nồi chè quán chè (`src/quanche/qc3d.py` NR 6.2 phóng x1.3).
  Nồi kho / nồi lẩu nồi kho: `src/noikho/noikho3d.py` G = 1.55 (R 7.75). Bếp củi: nhóm bếp phóng x1.45 (`src/bepcui/bepcui3d.py` GROUP).
- Đồ trên bàn phóng x1.35 (như bàn quán chè).
- Nồi nằm GỌN trong vành bếp, không lòi ra ngoài vành (Link 11-12 21:19 nồi kho).
- Cách phóng to cả nhóm đồ: `src/phongto/phongto.py` (grow / gxf).

## 3. Bếp, lò, củi
- Miệng lò phải là LỖ THẬT, không phải tấm tối dán lên mặt bếp (Link 11-12 21:36 nồi kho). Làm như cà ràng lò bánh quê
  (`src/lobanh/lobanh3d.py` `ca_rang`): khoét lòng lò (vách + vòm + vách sau bằng `M_LONG` bồ hóng đen, nền tro `M_ASH`),
  lớp than hồng `M_EMBER` nằm trong lòng lò + vài cục rơi trên lưỡi, 1 cái LƯỠI đất phẳng thò ra trước miệng có 2 gờ thấp 2 bên.
  Bếp đất đắp dài (nhiều miệng): `src/noikho/noikho3d.py` `bep()` (khoét rãnh vào đường viền rồi dựng vách).
- Củi đút lò = kiểu lò bánh quê (`src/lobanh/lobanh3d.py` `cui_lo`): 2 thanh củi CHẺ mỗi miệng, gác trên lưỡi, 1 thanh mỗi bên,
  đầu trong thấp, cháy đen, THẤY ĐƯỢC nằm trong lòng lò; đầu ngoài nhô ra ngắn, hơi nhấc lên; giữa miệng để trống cho lửa + than hồng.
  KHÔNG dùng khúc gỗ tròn to, KHÔNG chất 3 khúc lấp kín miệng (Link 11-12 21:31 nồi kho). Mẫu thứ 2: `src/noikho/noikho3d.py` `bep()`.
- Lòng lò tối (bồ hóng), chỉ than hồng sáng; không tô miệng lò đỏ chét. Lò bánh mì: `src/lobanhmi/lobanhmi3d.py` `em_holelit`.
- Lửa = hạt Godot, số theo `LUA.md`. Ảnh không vẽ ngọn lửa, chỉ than hồng.
- Đống củi dự trữ KHÔNG chất chắn trước miệng lò. Trước bếp không để đồ vô lý; ghế tre thì đặt giữa trước bếp (lò rang).
- Kiềng ông táo: nồi / chảo ĐẶT TRÊN 3 đầu ông táo, không lún, không lòi đầu ông táo (`src/bepcui/bepcui3d.py` CZ).

## 4. Đồ dùng chung
- Lu nước: có nắp gỗ + thanh gác + gáo, y lò bánh quê (`src/lobanh/lobanh3d.py` `lu_nuoc`). Mỗi xưởng tối đa 1 đến 2 lu / khạp.
- Bàn, ghế, kệ: TRE. Mặt bàn / ghế / kệ làm bằng ống tre tròn xếp liền (`src/noikho/noikho3d.py` `mat_ongtre`). Gỗ chỉ cho cấp 2.
- Đèn: đèn dầu treo cột (`godot/xuong/dendau/`, `CX.LAMP`), đêm sáng theo chuẩn kho: LIGHTS2 '#ff9645' 15 / 2.1 'out', GLOWS 0.2.
  Lửa bếp ban đêm chỉ hắt sáng nhỏ quanh miệng lò.
- Đồ ăn phải ra đúng món thật (không như đồ chơi), đúng sản phẩm của xưởng (xem danh sách trong game), không thêm món lạc đề.
- Lúc nghỉ: dọn đồ đang làm, nồi đậy nắp, bếp nguội.

## 5. Hiệu ứng + xuất
- Khói / hơi / lửa: hạt Godot, không vẽ vào khung. Khói mỏng, tỏa rộng, không thành cột trắng, không xuyên mái lá.
- Phần chuyển động cứng (xẻng...): 1 ảnh cho Godot di chuyển, không vẽ nhiều khung.
- Mỗi ảnh 1 file webp riêng + `atlas.json` + README tiếng Việt (file, thứ tự vẽ, số hạt), zip `godot/xuong/<xưởng>.zip`.
- Trình tự: gửi ảnh tĩnh xem trước + tự chấm thật thà, chờ Link OK rồi mới xuất.

## 6. Ghi thêm từ lò rang hạt + lò đường (2026-11-12, kiềng ông táo)
- Đồ đựng trong nồi / chảo (hạt, nước, mật) nằm GỌN trong lòng: mặt đồ đựng ở độ cao z thì bán kính = bán kính lòng chảo tại z
  trừ chút ít, không xuyên thủng thành chảo (Link 12:21 lò rang "chảo bị lỗi"). Mẫu: `src/duong/duong3d.py` LZ / LR, `src/rang/rang3d.py` CB_Z / CB_R.
- Chảo trống lúc nghỉ phải soi kỹ: đầu ông táo không được lòi qua đáy (lò rang CZ = BH + OT_H + 0.75).
- Bọt / bong bóng sôi cùng tông màu với chất đang nấu, mịn tròn (nu >= 6), không trắng lốm đốm như đồng xu / vỏ sò (lò đường mật).
- Cán sạn / cây khuấy chĩa về phía ghế người nấu, không chĩa qua bàn hay nồi / chảo khác.
- Kiềng ông táo: 3 thanh củi chẻ mỗi bếp xòe ra 2 bên (bếp trái xòe trái, bếp phải xòe phải), chừa giữa cho ghế.
- Xưởng chỉ 1 lu (Link 14:12 lò đường "lắm lu vcl"); thay hũ / lu thừa bằng nguyên liệu thật của xưởng (thúng dừa, rổ đậu phộng).
- Lúc nghỉ không để hũ / chai trên bàn: chỉ khuôn trống, mẹt chồng.
- NGOẠI LỆ đã chốt (Link 11-12 22:25 VN "xong rồi khỏi fix"): lò rang hạt + lò đường giữ chảo r ~10, mặt bàn nan tre chẻ, sạn / cây khuấy vẽ 24 khung. Xưởng MỚI vẫn theo chuẩn ở trên.
