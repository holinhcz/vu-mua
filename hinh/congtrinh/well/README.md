# Giếng làng (well)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/gieng.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (1x1 ô) trên mặt đất. Bản xoay well2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 1 kiểu: bd = ngày, bn = đêm.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 529x540 | -42.11, -51.33 | 58.78 x 60.0
bn.png | 529x540 | -42.11, -51.33 | 58.78 x 60.0
