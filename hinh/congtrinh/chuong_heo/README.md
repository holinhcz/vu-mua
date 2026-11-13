# Chuồng heo (chuong_heo)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/chuongheo.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Chuồng: KHÔNG neo ở tâm. Gốc toạ độ = điểm lưới (gx,gy) của chuồng (đỉnh trên của ô góc), giống en(gx,gy) web (x=(gx-gy)*32, y=(gx+gy)*16). Lớp: g = nền đất (vẽ dưới cùng, cùng lớp đất), b = hàng rào sau + chuồng ngủ (xếp sâu theo gx+gy+1.15), r0/r1 = rào phải từng ô (gx+gy+2.495 / 3.495), f0/f1 = rào trước từng ô (2.495 / 3.495). Thú vẽ xen giữa theo độ sâu. Đuôi d = ngày, n = đêm.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
gd.png | 1227x586 | -64.33, -0.89 | 136.33 x 65.11
bd.png | 1171x644 | -62.89, -20.67 | 130.11 x 71.56
r0d.png | 308x247 | 28.44, 15.56 | 34.22 x 27.44
r1d.png | 309x295 | -2.11, 30.67 | 34.33 x 32.78
f0d.png | 287x266 | -62.89, 15.56 | 31.89 x 29.56
f1d.png | 294x293 | -33.11, 27.67 | 32.67 x 32.56
gn.png | 1227x586 | -64.33, -0.89 | 136.33 x 65.11
bn.png | 1171x644 | -62.89, -20.67 | 130.11 x 71.56
r0n.png | 308x247 | 28.44, 15.56 | 34.22 x 27.44
r1n.png | 309x295 | -2.11, 30.67 | 34.33 x 32.78
f0n.png | 287x266 | -62.89, 15.56 | 31.89 x 29.56
f1n.png | 294x293 | -33.11, 27.67 | 32.67 x 32.56
