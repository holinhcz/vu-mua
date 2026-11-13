# Cầu khỉ ngắn/dài (caukhi)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/caukhi.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (3x1 ô) trên mặt đất. Bản xoay caukhi2, caukhid2 = lật ngang (scale x -1) cùng khung.

c = Cầu khỉ ngắn (caukhi 3x1), l = Cầu khỉ dài (caukhid 4x1), k = mảnh cầu khỉ bắc qua sông của cảnh làng (web CKDR vẽ với scale(-1,±1)).

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
cd.png | 986x629 | -50.78, -44.44 | 109.56 x 69.89
cn.png | 986x629 | -50.78, -44.44 | 109.56 x 69.89
kd.png | 866x538 | -48.11, -35.11 | 96.22 x 59.78
kn.png | 866x538 | -48.11, -35.11 | 96.22 x 59.78
ld.png | 1273x773 | -66.78, -52.33 | 141.44 x 85.89
ln.png | 1273x773 | -66.78, -52.33 | 141.44 x 85.89
