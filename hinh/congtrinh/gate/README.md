# Cổng làng (gate)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/cong.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (3x1 ô) trên mặt đất. Bản xoay gate2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 1 kiểu: bd = ngày, bn = đêm.

Chữ bảng hiệu do game vẽ (ảnh để trống bảng), font Nunito:
- "LÀNG": điểm 3D (u=1.5, v=.575, z=40.25) theo at.P(3,1), chữ 800 7.6px "Nunito",sans-serif, màu ngày #fff4d6 / đêm #d8cca8; nghiêng theo mặt iso transform(1,.5,0,1); khi lật ngang chữ KHÔNG lật.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 1004x1045 | -55.89, -91.89 | 111.56 x 116.11
bn.png | 1177x1122 | -65.33, -91.89 | 130.78 x 124.67
