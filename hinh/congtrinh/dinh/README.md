# Đình làng (cấp 1) (dinh)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/dinh.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (4x3 ô) trên mặt đất. Bản xoay dinh2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 1 kiểu: bd = ngày, bn = đêm.

Cờ đỏ sao vàng: co_d00..co_d11 ngày, co_n00..co_n11 đêm, 10 khung/giây, vẽ sau nhà, cùng gốc toạ độ. Cấp 2 chưa có ảnh.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 2049x1933 | -109.22, -160.22 | 227.67 x 214.78
bn.png | 2049x1933 | -109.22, -160.22 | 227.67 x 214.78
co_d00..co_n11 (24 file) | 324x405 | -100, -125 | 36.0 x 45.0
