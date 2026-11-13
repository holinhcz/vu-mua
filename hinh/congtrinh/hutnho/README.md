# Nhà tranh nhỏ (hutnho)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/choi.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (2x2 ô) trên mặt đất. Bản xoay hutnho2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 4 kiểu (seed t & 3): d0..d3 ngày, n0..n3 đêm.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
d0.png | 1258x1135 | -59.89, -94.78 | 139.78 x 126.11
n0.png | 1258x1135 | -59.89, -94.78 | 139.78 x 126.11
d1.png | 1255x1135 | -59.89, -94.78 | 139.44 x 126.11
n1.png | 1255x1135 | -59.89, -94.78 | 139.44 x 126.11
d2.png | 1256x1135 | -60.11, -94.78 | 139.56 x 126.11
n2.png | 1256x1135 | -60.11, -94.78 | 139.56 x 126.11
d3.png | 1258x1135 | -60.0, -94.78 | 139.78 x 126.11
n3.png | 1258x1135 | -60.0, -94.78 | 139.78 x 126.11
