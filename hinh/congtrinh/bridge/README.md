# Cầu ao (bridge)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/cauao.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (2x1 ô) trên mặt đất. Bản xoay bridge2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 1 kiểu: bd = ngày, bn = đêm.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 700x470 | -37.22, -33.33 | 77.78 x 52.22
bn.png | 700x470 | -37.22, -33.33 | 77.78 x 52.22
