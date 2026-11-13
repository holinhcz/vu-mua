# Icon món ăn chế biến, dựng 3D

PNG 512x512 nền trong suốt, mỗi món 1 file.
- Dựng khối 3D (SDF, tia quét từng điểm ảnh) ở 2048 px rồi thu về 512, ánh sáng mờ dịu, không đốm bóng.
- Cỡ đều: cạnh dài nhất của hình = 84% khung 512 (430 px), nằm giữa khung.
- atlas.json: tên, kích thước, bbox (vùng có hình trong ảnh 512).
- xem/: ảnh xem thử (to, phóng 3x, cỡ 48/64/96/128).
- Script gốc: ../../../src/monan3d/ (python3 <tên>.py <file.png>; NQ=768 để xem nhanh).

| File | Món | Xưởng |
|---|---|---|
| banhmi.png | Bánh mì | lò bánh mì |
