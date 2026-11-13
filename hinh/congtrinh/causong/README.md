# Cầu tre qua sông (causong)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/causong.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (1x5 ô) trên mặt đất. Bản xoay causong2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 1 kiểu: bd = ngày, bn = đêm.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 1597x932 | -84.78, -60.67 | 177.44 x 103.56
bn.png | 1597x932 | -84.78, -60.67 | 177.44 x 103.56
