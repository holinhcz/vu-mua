# Miếu nhỏ (cấp 1) (shrine)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/mieu.webp (18 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (1x1 ô) trên mặt đất. Bản xoay shrine2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 1 kiểu: bd = ngày, bn = đêm.

Ảnh gốc 18 điểm/ô (nét gấp đôi). Cấp 2 chưa có ảnh.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 900x1070 | -25.0, -46.89 | 50.0 x 59.44
bn.png | 900x1070 | -25.0, -46.89 | 50.0 x 59.44
