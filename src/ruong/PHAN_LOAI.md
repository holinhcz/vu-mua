# Rương mở quà 5 bậc: phân loại sử dụng (Link OK hình 11-26)

| Bậc | Rương | Lấy từ đâu | Quà bên trong |
|---|---|---|---|
| 0 | Hộp gỗ (d12) | Thu hoạch ruộng ngẫu nhiên, câu cá thường, quà đăng nhập ngày 1-2 | Xu ít, hạt giống thường, mồi câu |
| 1 | Trái dừa (d21) | Quà đăng nhập hằng ngày, lên cấp nhỏ, cá hiếm | Xu vừa, hạt giống, phân bón, mồi tốt |
| 2 | Trái bí (d22) | Xong nhiệm vụ ngày, thắng minigame (cờ gánh, ô ăn quan, cờ caro, tìm số, đua gà) | Xu nhiều, hạt giống quý, đồ câu cấp 1-2 |
| 3 | Búp sen (d23) | Thắng boss nhỏ (Nhím Chúa, Lợn Rừng Chúa...), chuỗi đăng nhập 7 ngày, nhiệm vụ tuần | Xu lớn, ngọc, đồ câu cấp 3, mảnh trang trí |
| 4 | Sen vàng (d24) | Thắng boss đại Chủ Nhật (Bọ Cạp Lửa), top bang chiếm thành, sự kiện lễ | Ngọc nhiều, đồ câu cấp 4, công trình/trang trí hiếm |

Quy tắc chung:
- Càng lên bậc càng hiếm: rớt rương bậc 0 thường xuyên, bậc 4 chỉ từ boss đại/sự kiện.
- Mở rương có hoạt ảnh nắp (bậc 0-2) hoặc hoa nở (bậc 3-4); quà bay ra sau khi mở xong.
- Model GLB: src/ruong/ (ruong_tex.py TIER: 12 = hộp gỗ, 21-24 = dừa/bí/búp sen/sen vàng). Xem: gallery Xem 3D #ruong2.
- Phần nối vào game do bên nối làm, thread vẽ chỉ vẽ.
