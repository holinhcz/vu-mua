# Chòi canh ruộng (choi)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/choicanh.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (1x1 ô) trên mặt đất. Bản xoay choi2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 2 kiểu (seed t & 1): d0,d1 ngày, n0,n1 đêm.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
d0.png | 701x722 | -30.89, -64.0 | 77.89 x 80.22
n0.png | 701x722 | -30.89, -64.0 | 77.89 x 80.22
d1.png | 697x722 | -30.89, -64.0 | 77.44 x 80.22
n1.png | 697x722 | -30.89, -64.0 | 77.44 x 80.22
