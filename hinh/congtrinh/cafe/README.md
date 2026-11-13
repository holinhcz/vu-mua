# Quán cà phê võng (cafe)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/cafe.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (3x2 ô) trên mặt đất. Bản xoay cafe2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 3 kiểu (seed t % 3): d0..d2 ngày, n0..n2 đêm.

Chữ bảng hiệu do game vẽ (ảnh để trống bảng), font Nunito:
- "CÀ PHÊ VÕNG": điểm 3D (u=1.08, v=.64, z=63.8) theo at.P(3,2), chữ 800 6.2px "Nunito",sans-serif, màu ngày #fff4d6 / đêm #d8cca8; nghiêng theo mặt iso transform(1,.5,0,1); khi lật ngang chữ KHÔNG lật.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
d0.png | 1485x1193 | -77.33, -94.0 | 165.0 x 132.56
n0.png | 1485x1193 | -77.33, -94.0 | 165.0 x 132.56
d1.png | 1485x1193 | -77.33, -94.0 | 165.0 x 132.56
n1.png | 1485x1193 | -77.33, -94.0 | 165.0 x 132.56
d2.png | 1485x1193 | -77.33, -94.0 | 165.0 x 132.56
n2.png | 1485x1193 | -77.33, -94.0 | 165.0 x 132.56
