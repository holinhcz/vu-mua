Ghe sông Vàm 3D (11-25) - thay bộ phẳng src/godot/ui/img/ghe/*.webp, ĐÚNG 122 tên file cũ.
Nguồn: src/tools/cc/moi/ghe3d.py (+ bay3d.py, cho_th.json). Chạy: PXU=6 SSA=1 python3 ghe3d.py OUT <key>...
- 6 px / đơn vị làng (đủ cho zoom tối đa 1.7*s*dpr trên S26 Ultra ~6.5 px/đv). WebP lossless, bản có nước (phần chìm mờ dưới z=0).
- <key>.json = [ox, oy, w, h] theo ĐƠN VỊ (chia 6 ra px): ox, oy = góc trên-trái ảnh so với điểm đặt (0,0,0) của ghe (trục y xuống), w, h = cỡ ảnh.
- Khóa giống ghe_ve.gd: ghe_u_<-23..13>, ghe_v; cho_<song|song_dong|song_tay>_<0..3> (e lẻ s=-1, góc theo cho_th.json, sc .78);
  xu_<p|m><mui 0/1>_<k chẵn -22..12>.
- 4 ghe chợ theo data/cho/ghe_cho_noi.json: 0 cây giống (mái bạt), 1 trái cây, 2 lúa gạo (mái bạt), 3 đồ bếp.
- Cây bẹo: KHÔNG treo hàng sẵn; code vẽ icon đơn hàng ở 2 đầu đòn ngang ±.42 TILE cao 74 và giữa cột cao 48 (như cũ).
- Không vẽ người. Chỗ đứng cầm lái = sạp lái gỗ ngay trước máy đuôi tôm.
- Tổng ~7.9 MB (bộ cũ 5.0 MB).
