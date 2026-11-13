# Quán cơm (quancom)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/quancom.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (3x2 ô) trên mặt đất. Bản xoay quancom2 = lật ngang (scale x -1) cùng khung.

2 lớp: b = bếp + sân + băng ghế sau, khách ngồi phía sau vẽ giữa, f = bàn + ghế trước + đồ, rồi khách phía trước.

Chữ bảng hiệu do game vẽ (ảnh để trống bảng), font Nunito:
- "QUÁN CƠM": điểm 3D (u=1.5, v=1.01, z=52.5) theo at.P(3,2), chữ 800 7px "Nunito",sans-serif, màu ngày #fff2c8 / đêm #d8c898; nghiêng theo mặt iso transform(1,.5,0,1); khi lật ngang chữ KHÔNG lật.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 1555x1212 | -77.33, -96.11 | 172.78 x 134.67
bn.png | 1555x1212 | -77.33, -96.11 | 172.78 x 134.67
fd.png | 1064x590 | -77.89, -32.67 | 118.22 x 65.56
fn.png | 1064x590 | -77.89, -32.67 | 118.22 x 65.56
