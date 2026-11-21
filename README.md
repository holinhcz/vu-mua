# Vụ Mùa: mã nguồn Godot

Nhánh này chỉ chứa mã nguồn. Bản đang chạy (GitHub Pages) nằm ở nhánh `main`, không liên quan.

- `src/godot/`: dự án Godot 4.5.1 (gl_compatibility). Phần nền, làng, cảnh, trời, đêm gồm `main.gd`, `*.gdshader`, `songgen.gd`, `pondgen.gd`. Phần logic và giao diện gồm `logic/*.gd`, `ui/*` (dữ liệu, hình UI, font). `logic_project.godot` là project.godot của phần logic (autoload Boot).
- `src/tools/`: script đóng gói và xuất. `pack.py` cắt pck, `merge_logic.py` gộp gói logic vào pck nền, `mkfiles.py` tạo files.json, `tools/*.py` xuất hình đêm, lô đất, cảnh.
- `src/shell/index.html`: trang vỏ của bản web (tải pck nhiều mảnh, Firebase, giftcode).
- `hinh/`: hình gốc 9px/đơn vị (cây, công trình, xưởng, icon...) do các thread vẽ xuất ra.

Dữ liệu đã đóng gói mà game tải lúc chạy (n/, d/, l/) nằm ở nhánh `main`.

## VIỆC CHỜ LÀM (ghi 21/11/2026)

- **Đám đặt món:** nhà có đám giỗ / cưới / tiệc thì đặt món mình làm (món xưởng, món quán đã làm được), đặt trước 5 ngày, đơn lớn 2–4 món.
  Cần chốt đám trước 5 ngày (hiện thiệp mời chỉ báo trước vài giờ, g.dam.nt). Nút Nhận đặt / Từ chối khéo (từ chối không trừ gì).
  Giao đủ trước giờ đám: xu ~1,5–2 lần giá bán, uy tín +5..+10, thân +30..+60. Còn chốt: nhận mà không giao có trừ không, giao thiếu có thưởng phần không, 1 hay 2 đơn cùng lúc.
- **Công trình (Sổ nhiệm vụ › Thành tựu):** Xưởng, Chuồng luôn 0 (step_f "zero"); Sạp kẹt bước nâng sạp (bản Godot chưa nâng sạp). Đề xuất thêm chuỗi Quán, Vườn, Làng.
- **Hái điên điển:** song_ve.gd gọi WC.wx() không có -> chưa hái được bụi ven sông; xong thì thêm lại việc ngày "dd".
- **Thiên tai › chạm đồ thiếu (ui_tn.gd SRC):** câu chỉ chỗ kiếm củi ("chặt cây, dọn bụi trên ruộng") và gạch ("thư bạn bè gửi, hợp tác xã chia") là đoán từ code (farm.gd bong bóng củi, w_thu.gd / w_htx.gd cộng gạch). Rảnh lục lại logic thật rồi sửa câu cho đúng.
- **Thiên tai › đồ giúp nhà gặp nạn (w_duong.gd tn_need_of, data/thien_tai/do_giup.json):** một nhà cần tới 4 món (vd sập nhà: 540 xu, 10 củi, 4 gạch, 1 chiếu), mới chơi gần như không giúp nổi. Rảnh coi lại mức đồ theo cấp / loại nạn, cân nhắc giảm.
