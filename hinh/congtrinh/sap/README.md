# Sạp bán hàng (sap)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/sap.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (4x2 ô) trên mặt đất. Bản xoay sap2 = lật ngang (scale x -1) cùng khung.

2 lớp: b = sạp phía sau (vẽ trước), hàng hóa của người chơi vẽ giữa, f = cột, mái, bảng (vẽ sau) + chữ.

Chữ bảng hiệu do game vẽ (ảnh để trống bảng), font Nunito:
- "SẠP QUÊ": điểm 3D (u=2, v=2.045, z=89.5) theo at.P(4,2), chữ 800 8.5px "Nunito",sans-serif, màu ngày #5a2a10 / đêm #3a2414; nghiêng theo mặt iso transform(1,.5,0,1); khi lật ngang chữ KHÔNG lật.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 1772x1342 | -92.89, -102.56 | 196.89 x 149.11
bn.png | 1772x1342 | -92.89, -102.56 | 196.89 x 149.11
fd.png | 1811x1390 | -97.22, -108.22 | 201.22 x 154.44
fn.png | 1811x1390 | -97.22, -108.22 | 201.22 x 154.44
