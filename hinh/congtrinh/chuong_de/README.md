# Chuồng dê (chuong_de)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/chuongde.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Chuồng: KHÔNG neo ở tâm. Gốc toạ độ = điểm lưới (gx,gy) của chuồng (đỉnh trên của ô góc), giống en(gx,gy) web (x=(gx-gy)*32, y=(gx+gy)*16). Lớp: g = nền đất (vẽ dưới cùng, cùng lớp đất), b = hàng rào sau + chuồng ngủ (xếp sâu theo gx+gy+1.15), r0/r1 = rào phải từng ô (gx+gy+2.495 / 3.495), f0/f1 = rào trước từng ô (2.495 / 3.495). Thú vẽ xen giữa theo độ sâu. Đuôi d = ngày, n = đêm.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
gd.png | 1227x579 | -64.33, -0.11 | 136.33 x 64.33
bd.png | 1160x673 | -62.78, -24.44 | 128.89 x 74.78
r0d.png | 282x248 | 31.33, 15.56 | 31.33 x 27.56
r1d.png | 308x295 | -2.0, 30.67 | 34.22 x 32.78
f0d.png | 286x267 | -62.78, 15.56 | 31.78 x 29.67
f1d.png | 294x297 | -33.11, 27.67 | 32.67 x 33.0
gn.png | 1227x579 | -64.33, -0.11 | 136.33 x 64.33
bn.png | 1160x673 | -62.78, -24.44 | 128.89 x 74.78
r0n.png | 282x248 | 31.33, 15.56 | 31.33 x 27.56
r1n.png | 308x295 | -2.0, 30.67 | 34.22 x 32.78
f0n.png | 286x267 | -62.78, 15.56 | 31.78 x 29.67
f1n.png | 294x297 | -33.11, 27.67 | 32.67 x 33.0
