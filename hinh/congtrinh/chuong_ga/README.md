# Chuồng gà (chuong_ga)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/chuongga.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Chuồng: KHÔNG neo ở tâm. Gốc toạ độ = điểm lưới (gx,gy) của chuồng (đỉnh trên của ô góc), giống en(gx,gy) web (x=(gx-gy)*32, y=(gx+gy)*16). Lớp: g = nền đất (vẽ dưới cùng, cùng lớp đất), b = hàng rào sau + chuồng ngủ (xếp sâu theo gx+gy+1.15), r0/r1 = rào phải từng ô (gx+gy+2.495 / 3.495), f0/f1 = rào trước từng ô (2.495 / 3.495). Thú vẽ xen giữa theo độ sâu. Đuôi d = ngày, n = đêm.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
gd.png | 1197x579 | -63.89, -0.11 | 133.0 x 64.33
bd.png | 1106x717 | -62.44, -33.33 | 122.89 x 79.67
r0d.png | 280x262 | 31.11, 16.89 | 31.11 x 29.11
r1d.png | 300x276 | -1.44, 32.11 | 33.33 x 30.67
f0d.png | 282x267 | -62.33, 16.89 | 31.33 x 29.67
f1d.png | 293x267 | -32.89, 32.11 | 32.56 x 29.67
gn.png | 1197x579 | -63.89, -0.11 | 133.0 x 64.33
bn.png | 1106x717 | -62.44, -33.33 | 122.89 x 79.67
r0n.png | 280x262 | 31.11, 16.89 | 31.11 x 29.11
r1n.png | 300x276 | -1.44, 32.11 | 33.33 x 30.67
f0n.png | 282x267 | -62.33, 16.89 | 31.33 x 29.67
f1n.png | 293x267 | -32.89, 32.11 | 32.56 x 29.67
