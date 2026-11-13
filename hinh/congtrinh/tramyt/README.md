# Trạm y tế (cấp 1) (tramyt)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/tramyt.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (3x3 ô) trên mặt đất. Bản xoay tramyt2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 1 kiểu: bd = ngày, bn = đêm.

Cờ chữ thập đỏ: co_d00..11 / co_n00..11, 10 khung/giây. Cấp 2 chưa có ảnh.

Chữ bảng hiệu do game vẽ (ảnh để trống bảng), font Nunito:
- "TRẠM Y TẾ": điểm 3D (u=1.02, v=2.836, z=18.25) theo at.P(3,3), chữ 800 5.2px "Nunito",sans-serif, màu ngày #c42a20 / đêm #8a2a20; nghiêng theo mặt iso transform(1,.5,0,1); khi lật ngang chữ KHÔNG lật.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 1651x1375 | -91.33, -107.0 | 183.44 x 152.78
bn.png | 1651x1375 | -91.33, -107.0 | 183.44 x 152.78
co_d00..co_n11 (24 file) | 279x351 | -78, -111 | 31.0 x 39.0
