# Đèn bão (cây đèn của lò bánh mì) – ảnh lẻ 512x512

- `den_tat.webp`: đèn tắt (ban ngày).
- `den_sang.webp`: đèn thắp (ban đêm), có ngọn lửa và kính sáng bên trong. Ảnh KHÔNG có quầng sáng ra ngoài không khí: quầng sáng làm bằng hiệu ứng riêng trong Godot (PointLight2D hoặc sprite glow cộng màu `#ff9645`).
- Nền trong suốt, đáy đèn cách mép dưới 4 px, đèn nằm giữa theo chiều ngang. Cao khoảng 495 px.
- Vẽ 3D (src/lobanhmi/lobanhmi3d.py), siêu lấy mẫu x3, cùng độ sáng/ánh sáng với lò bánh mì.

Xuất lại: `cd src/lobanhmi && python3 lobanhmi3d.py den <thư_mục> 512` (đổi 512 thành cỡ khác nếu cần).
