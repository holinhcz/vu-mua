# Đồ câu 3D 6px (11-25) — bên gắn đọc cái này

Đã ĐÈ ảnh cũ trong src/cauca/ui/img/cc/ (cùng tên, cùng định dạng), code chưa đụng:
- ic-line0-3, ic-flo0-2, ic-cage0-2, ic-rod0-3 + ic-line/ic-flo/ic-cage/ic-rod (= bậc 1): icon 3D 6px, khung chung từng loại (cc_art.fit giữ tỉ lệ).
- can/can0-3 (1440 x 68/72/74/78, cán x=0, trục giữa ảnh), can/ongcuoc0-3 (ảnh vuông, tâm giữa, lỗ thủng thật), can/phao0-2: dựng 3D, can.json cập nhật (cùng khoá w h len r0 r1 grip / r / wl hs hb ws).

MỚI, game chưa có dữ liệu (cần thêm ở cc_data.gd + clamp trong cc_draw.draw_float_shape đang clampi(flo,0,2)):
- Phao bậc 4 "Phao sơn mài khảm xà cừ" (đầu đèn vàng): ic-flo3 + can/phao3.
- Rọ bậc 4 "Rọ mây sơn dầu, đai đồng, nắp gỗ": ic-cage3.
- Lưỡi câu 4 bậc (món mới, chưa có trong game): ic-luoi0-3 = sắt rèn buộc chỉ đỏ / thép có ngạnh + chì / lưỡi đôi đồng + khoá xoay / lưỡi chùm 3 mạ vàng.
  (đặt tên luoi vì khoá "hook" đã là icon nút "Đang dùng")
- Dây dù bện (LINE bậc 4) cuộn màu nâu khớp LINE_C[3] trong cc_draw.

Nhớ đổi CC_V / ccver.txt (cache ảnh câu cá) khi đóng gói lại.
Công cụ: do3d.py (icon), can_game.py (cần + ống cước trong game, EL=0 PXU=6), phao_game.py (phao trên nước, EL=10 PXU=14 cho cọng nét như phao cũ).
