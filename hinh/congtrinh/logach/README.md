# Lò gạch (cấp 1) (logach)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/logach.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (2x2 ô) trên mặt đất. Bản xoay logach2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 1 kiểu: bd = ngày, bn = đêm.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 1076x857 | -59.56, -65.44 | 119.56 x 95.22
bn.png | 1076x857 | -59.56, -65.44 | 119.56 x 95.22
