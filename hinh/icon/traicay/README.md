# Icon trái cây (Xếp Trái), vẽ từng điểm ảnh

18 file PNG 512x512 nền trong suốt, mỗi trái 1 file: xoai, quyt, chomchom, mangcut, buoi, dua, saurieng, thanhlong, duahau, nhan, man, dudu, mit, cam, chuoi, dieu, me, dautay.
- Kiểu icon: KHÔNG sáng tối, không bóng, không đốm sáng; chỉ màu gốc + chi tiết vẽ (vân, chấm, gân, lông, xơ).
- Vẽ ở 2048 px (tô từng điểm ảnh: khối, vân vỏ, lỗ dầu, lông chôm, xơ dừa, gân lá), thu nhỏ còn 512 nên đủ nét cho màn 4K khi làm icon.
- Viền mực mảnh (nửa điểm ảnh ở 512).
- Cỡ đều: mọi trái được canh để cạnh dài nhất của hình = 84% khung 512 (430 px), nằm giữa khung.
- atlas.json: tên, kích thước, bbox (vùng có hình trong ảnh 512).
- xem/: ảnh xem thử (to + cỡ 256/128/64/40).
- Script vẽ gốc: ../../../src/traicay/ (python3 <tên>.py <file.png>).
