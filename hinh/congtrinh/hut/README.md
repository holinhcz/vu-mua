# Nhà tranh (hut)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/nha.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (3x2 ô) trên mặt đất. Bản xoay hut2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 4 kiểu (seed t & 3): d0..d3 ngày, n0..n3 đêm.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
d0.png | 1483x1320 | -77.44, -106.78 | 164.78 x 146.67
n0.png | 1483x1320 | -77.44, -106.78 | 164.78 x 146.67
d1.png | 1488x1320 | -77.44, -106.78 | 165.33 x 146.67
n1.png | 1488x1320 | -77.44, -106.78 | 165.33 x 146.67
d2.png | 1486x1320 | -77.44, -106.78 | 165.11 x 146.67
n2.png | 1486x1320 | -77.44, -106.78 | 165.11 x 146.67
d3.png | 1483x1320 | -77.44, -106.78 | 164.78 x 146.67
n3.png | 1483x1320 | -77.44, -106.78 | 164.78 x 146.67
