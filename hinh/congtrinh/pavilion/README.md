# Chòi nghỉ mát (pavilion)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/choimat.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (2x2 ô) trên mặt đất. Bản xoay pavilion2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 2 kiểu (seed t & 1): d0,d1 ngày, n0,n1 đêm.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
d0.png | 1330x1186 | -65.89, -99.56 | 147.78 x 131.78
n0.png | 1330x1186 | -65.89, -99.56 | 147.78 x 131.78
d1.png | 1325x1184 | -65.78, -99.56 | 147.22 x 131.56
n1.png | 1325x1184 | -65.78, -99.56 | 147.22 x 131.56
