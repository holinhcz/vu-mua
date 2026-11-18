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

## Hình món chưa có trong game (bản 309) — làm món thì lấy dùng
Cắt từ tấm ảnh người dùng (src/tools/cut_mon.py), 512 nền trong, cỡ chuẩn 430. Gắn vào game: bọc WebP thành ui/svg/kh/<mã món>.svg.
| File | Món |
|---|---|
| lau_cua_dong.png | Lẩu cua đồng |
| lau_vit_chao.png | Lẩu vịt nấu chao |
| lau_ga_la_giang.png | Lẩu gà lá giang |
| lau_ga_ot_hiem.png | Lẩu gà ớt hiểm |
| lau_ca_hu.png | Lẩu cá hú măng chua |
| lau_luon.png | Lẩu lươn chua cay |
| lau_ech.png | Lẩu ếch măng cay |
| lau_nam.png | Lẩu nấm thập cẩm |
| banh_khoai_mi.png | Bánh khoai mì |
| banh_chuoi_nuong.png | Bánh chuối nướng (game đang có Bánh chuối hấp, khác món) |
