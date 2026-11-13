# Tạp hóa đầu ngõ (cấp 1) (taphoa)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/taphoa.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (2x2 ô) trên mặt đất. Bản xoay taphoa2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 1 kiểu: bd = ngày, bn = đêm.

Chữ bảng hiệu do game vẽ (ảnh để trống bảng), font Nunito:
- "TẠP HÓA": điểm 3D (u=1, v=1.39, z=47) theo at.P(2,2), chữ 800 7px "Nunito",sans-serif, màu ngày #fff4d6 / đêm #d8cca8; nghiêng theo mặt iso transform(1,.5,0,1); khi lật ngang chữ KHÔNG lật.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 1196x1016 | -60.89, -82.33 | 132.89 x 112.89
bn.png | 1196x1016 | -60.89, -82.33 | 132.89 x 112.89
