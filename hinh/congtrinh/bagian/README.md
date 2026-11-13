# Nhà ba gian cổ (cấp 1) (bagian)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/bagian.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (3x3 ô) trên mặt đất. Bản xoay bagian2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 1 kiểu: bd = ngày, bn = đêm.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 1768x1474 | -92.44, -117.22 | 196.44 x 163.78
bn.png | 1768x1474 | -92.44, -117.22 | 196.44 x 163.78
