Lờ / lọp / giăng câu 4 cấp, dựng 3D (tools/cc/moi/bay3d.py -> art/bay -> tools/cc/moi/bake_bay.py). CHƯA GẮN vô vườn.
Tên: <d|n><món><cấp>.webp   d = ngày, n = đêm nướng sẵn; món = lo / lop / giang; cấp 1 không số, cấp 2-4 có số (lo2, lop3, giang4).
Hình đã là bản "đặt trên nước" (phần dưới mặt nước mờ). 6 px / đơn vị làng.
atlas.json frames: w h (px), ox oy = góc trên-trái so với chỗ đặt chân (giữa món ngay mặt nước, = gốc LoNode trong song_ve.gd), gw gh = cỡ theo đơn vị.
Vẽ: draw_texture_rect(tex, Rect2(ox, oy, gw, gh), false).
Cấp 1 tre mộc + mây. 2 tre già ám khói, mây đôi (lờ hom 2 lớp, lọp nắp gáo dừa, giăng dây dù + phao xốp, 6 lưỡi).
3 dầu chai + kẽm (lờ phao đánh dấu, lọp nắp gỗ chốt, giăng cọc tràm + phao nhựa + lục lạc, 8 lưỡi).
4 tre đen bóng + đồng thau (lờ cửa sập đồng, lọp nắp đồng, giăng cọc sơn + phao đồng + đèn chai, 10 lưỡi).
Bản nguyên món (không nước, cho ô / bảng): art/bay/<món><cấp>.webp
