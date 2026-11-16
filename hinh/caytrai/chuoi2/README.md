# chuoi2
Cây chuối vẽ lại 2026-11-16: GIỮ ĐÚNG DÁNG cây chuối đang có trong game (caytrai/chuoi, code cũ code_ve_cay/chuoi/build.py),
chỉ đổi cách tô sang kiểu dừa nước (bộ vẽ caysen, sáng tối từng điểm ảnh, xanh dừa nước, không bóng, viền mỏng cùng màu lá).
Chuối chín và bắp chuối giữ màu bản 2D cũ. Code: code_ve_cay/chuoi3/chuoi3.py.
Khung: d = ngày, n = đêm; d<dáng><chín>: dáng 0 = d0x cũ, dáng 1 = d1x cũ; chín 0 = xanh, 1 = chín. 8 ảnh: d00 d01 d10 d11 n00 n01 n10 n11.
9 px/đơn vị game. atlas.json: ox,oy = góc trên trái so với neo (gốc cây, đơn vị game), gw,gh = cỡ vẽ. Godot: offset=(ox,oy), scale=1/9.
Chưa gắn vào game (game vẫn dùng caytrai/chuoi).
