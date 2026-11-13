# Trường làng (cấp 1) (truong)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/truong.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (4x4 ô) trên mặt đất. Bản xoay truong2 = lật ngang (scale x -1) cùng khung.

Chọn khung: 1 kiểu: bd = ngày, bn = đêm.

Cờ trường dùng khung cờ của đình (dinh/co_*.png) nhuộm multiply #d6cbbd, lệch +24,+16.96 đơn vị so với box cờ đình.

Chữ bảng hiệu do game vẽ (ảnh để trống bảng), font Nunito:
- "TRƯỜNG LÀNG": điểm 3D (u=1.8, v=2.243, z=57.0) theo at.P(4,4), chữ 800 5.8px "Nunito",sans-serif, màu ngày #f4ead0 / đêm #c8bc98; nghiêng theo mặt iso transform(1,.5,0,1); khi lật ngang chữ KHÔNG lật.
- "a  ă  b  c": điểm 3D (u=2.0, v=1.63, z=22.4) theo at.P(4,4), chữ italic 600 3.3px "Nunito",sans-serif, màu ngày rgba(236,234,224,.9) / đêm rgba(200,198,186,.8); nghiêng theo mặt iso transform(1,.5,0,1); khi lật ngang chữ KHÔNG lật.
- "1 + 2 = 3": điểm 3D (u=2.02, v=1.63, z=17.6) theo at.P(4,4), chữ italic 600 3.3px "Nunito",sans-serif, màu ngày rgba(236,234,224,.9) / đêm rgba(200,198,186,.8); nghiêng theo mặt iso transform(1,.5,0,1); khi lật ngang chữ KHÔNG lật.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 2226x1696 | -123.33, -126.67 | 247.33 x 188.44
bn.png | 2226x1696 | -123.33, -126.67 | 247.33 x 188.44
