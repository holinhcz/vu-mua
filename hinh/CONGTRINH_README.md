# Công trình / nhà cửa cho Godot (xuất 11-12)

Mỗi khung 1 file PNG, cắt NGUYÊN điểm ảnh từ ảnh 3D gốc của game web (không vẽ lại, không thu nhỏ, không mất chi tiết). Mỗi thư mục có atlas.json + README (cách chọn khung, lớp trước/sau, chữ bảng hiệu, cờ).
Toạ độ đơn vị game web (1 ô = 64x32). Nhà: neo = tâm chân móng. Chuồng: neo = điểm lưới (gx,gy). Godot: offset=(ox,oy), scale=1/px_per_unit. d/bd = ngày, n/bn = đêm.

thư mục | tên | ảnh web | điểm ảnh/đơn vị | số file | khung lớn nhất
---|---|---|---|---|---
congtrinh/hutnho | Nhà tranh nhỏ | img/choi.webp | 9 | 8 | 1258x1135
congtrinh/hut | Nhà tranh | img/nha.webp | 9 | 8 | 1488x1320
congtrinh/pavilion | Chòi nghỉ mát | img/choimat.webp | 9 | 4 | 1330x1186
congtrinh/choi | Chòi canh ruộng | img/choicanh.webp | 9 | 4 | 701x722
congtrinh/kho | Kho hàng (cấp 1) | img/kho.webp | 9 | 4 | 1756x1462
congtrinh/sap | Sạp bán hàng | img/sap.webp | 9 | 4 | 1811x1390
congtrinh/quancom | Quán cơm | img/quancom.webp | 9 | 4 | 1555x1212
congtrinh/taphoa | Tạp hóa đầu ngõ (cấp 1) | img/taphoa.webp | 9 | 2 | 1196x1016
congtrinh/cafe | Quán cà phê võng | img/cafe.webp | 9 | 6 | 1485x1193
congtrinh/bagian | Nhà ba gian cổ (cấp 1) | img/bagian.webp | 9 | 2 | 1768x1474
congtrinh/dinh | Đình làng (cấp 1) | img/dinh.webp | 9 | 26 | 2049x1933
congtrinh/gate | Cổng làng | img/cong.webp | 9 | 2 | 1177x1122
congtrinh/truong | Trường làng (cấp 1) | img/truong.webp | 9 | 2 | 2226x1696
congtrinh/chua | Chùa làng (cấp 1) | img/chua.webp | 9 | 26 | 2253x2007
congtrinh/tramyt | Trạm y tế (cấp 1) | img/tramyt.webp | 9 | 26 | 1651x1375
congtrinh/shrine | Miếu nhỏ (cấp 1) | img/mieu.webp | 18 | 2 | 900x1070
congtrinh/logach | Lò gạch (cấp 1) | img/logach.webp | 9 | 2 | 1076x857
congtrinh/well | Giếng làng | img/gieng.webp | 9 | 2 | 529x540
congtrinh/ben | Bến ghe | img/benghe.webp | 9 | 4 | 1125x754
congtrinh/caukhi | Cầu khỉ ngắn/dài | img/caukhi.webp | 9 | 6 | 1273x773
congtrinh/causong | Cầu tre qua sông | img/causong.webp | 9 | 2 | 1597x932
congtrinh/bridge | Cầu ao | img/cauao.webp | 9 | 2 | 700x470
congtrinh/chuong_ga | Chuồng gà | img/chuongga.webp | 9 | 12 | 1106x717
congtrinh/chuong_heo | Chuồng heo | img/chuongheo.webp | 9 | 12 | 1171x644
congtrinh/chuong_bo | Chuồng bò | img/chuongbo.webp | 9 | 12 | 1162x644
congtrinh/chuong_cuu | Chuồng cừu | img/chuongcuu.webp | 9 | 12 | 1108x756
congtrinh/chuong_de | Chuồng dê | img/chuongde.webp | 9 | 12 | 1160x673

Chưa có ảnh (web vẫn vẽ bằng code canvas cũ, chưa dựng 3D): các bản cấp 2 (kho_l2, taphoa_l2, bagian_l2, dinh_l2, chua_l2, truong_l2, tramyt_l2, shrine_l2, logach_l2, gate_l2), Nhà ngói (house, đang ẩn), đèn lồng, bù nhìn, rào tre, cổng ngõ... Không vẽ lại khi Link chưa kêu.
Xưởng chế biến (cối xay, ruộng muối, lò...) nằm ở godot/xuong/ (thread khác lo).
Code 3D dựng từng nhà: congtrinh/_code/ (README trong đó). Xem trước: xem/godot-congtrinh-xuat-mau.png. Script cắt: src/godot/xuat/congtrinh/ (parse.py đọc bảng G trong index.html, exp.py cắt).
