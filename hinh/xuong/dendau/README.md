# Đèn dầu Hoa Kỳ – ảnh lẻ, nền trong suốt

- `dendau_tat.webp` 512x512: đèn tắt (ban ngày).
- `dendau_sang.webp` 512x512: đèn thắp (ban đêm): ngọn lửa trên bấc, thau + dầu sáng lên, bóng khói ấm quanh ngọn lửa. KHÔNG có quầng sáng ra ngoài không khí: quầng sáng làm hiệu ứng riêng trong Godot (PointLight2D / sprite glow màu `#ff9645`).
- `4k/dendau_tat.webp` + `4k/dendau_sang.webp` 4096x4096: cùng 2 ảnh ở cỡ 4K (vẽ thẳng từ cảnh 3D ở 4096, không phóng to từ 512).
- Đèn cao ~504 px trong ảnh 512, nằm giữa theo chiều ngang, đáy cách mép dưới 4 px. Nguồn 3D: src/dendau/dendau3d.py, siêu lấy mẫu x3, cùng độ sáng với lò bánh mì / đèn bão.
- Thủy tinh xanh chai (Link 09:27), dầu hỏa vàng rơm nhạt, bộ đốt thau có vành lỗ thông hơi, 4 ngàm giữ bóng, núm vặn bấc.

Xuất lại: `cd src/dendau && python3 dendau3d.py <thư_mục> 512` (đổi 512 thành cỡ khác). 4K: `DD_SS=1 DD_ONLY=dendau_tat python3 dendau3d.py <thư_mục> 4096` rồi `DD_ONLY=dendau_sang`, mỗi ảnh ~12 phút, chạy từng ảnh một (chạy chung với việc khác bị tràn RAM).
