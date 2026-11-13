# Chùa làng (cấp 1) (chua)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/chua.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (4x4 ô) trên mặt đất. Bản xoay chua2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 1 kiểu: bd = ngày, bn = đêm.

Cờ Phật giáo: co_d00..11 / co_n00..11, 10 khung/giây. Web còn vẽ: khói nhang ở at.PZ(4,4,1.15)(2,3.55,24) (hiệu ứng riêng), chữ 卍 vẽ nét ở P(4,4)(2.0,1.6,82.5). Cấp 2 chưa có ảnh.

Chữ bảng hiệu do game vẽ (ảnh để trống bảng), font Nunito:
- "CHÙA LÀNG": điểm 3D (u=2.0, v=2.593, z=74.5) theo at.P(4,4), chữ 800 5.6px "Nunito",sans-serif, màu ngày #f2d58a / đêm #c8ae70; nghiêng theo mặt iso transform(1,.5,0,1); khi lật ngang chữ KHÔNG lật.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 2253x2007 | -123.33, -161.22 | 250.33 x 223.0
bn.png | 2253x2007 | -123.33, -161.22 | 250.33 x 223.0
co_d00..co_n11 (24 file) | 315x396 | -82, -91 | 35.0 x 44.0
