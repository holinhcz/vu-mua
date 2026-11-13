# Icon nông sản, vẽ từng điểm ảnh

File PNG 512x512 nền trong suốt, mỗi loại 1 file (key = key cây trồng trong game): lua, bap, carot, bido, cachua, ot.
- Cùng kiểu với icon trái cây (../traicay/): KHÔNG sáng tối, không bóng; chỉ màu gốc + chi tiết vẽ.
- Vẽ ở 2048 px rồi thu nhỏ còn 512, viền mực mảnh (nửa điểm ảnh ở 512).
- Cỡ đều: cạnh dài nhất của hình = 84% khung (430 px), nằm giữa khung.
- atlas.json: tên, kích thước, bbox. xem/: ảnh xem thử (to + 256/128/64/40).
- Script vẽ gốc: ../../../src/nongsan/ (python3 ns_<tên>.py <file.png>, cần lib.py + parts.py).
