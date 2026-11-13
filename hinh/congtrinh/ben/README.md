# Bến ghe (ben)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/benghe.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (2x3 ô) trên mặt đất. Bản xoay ben2, ben4 = lật ngang (scale x -1) cùng khung.

Khung 0d/0n = ben (ben2 = lật ngang). Khung 1d/1n = ben3 (ben4 = lật ngang).

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
0d.png | 1095x749 | -66.44, -49.56 | 121.67 x 83.22
0n.png | 1095x749 | -66.44, -49.56 | 121.67 x 83.22
1d.png | 1125x754 | -50.44, -58.33 | 125.0 x 83.78
1n.png | 1125x754 | -50.44, -58.33 | 125.0 x 83.78
