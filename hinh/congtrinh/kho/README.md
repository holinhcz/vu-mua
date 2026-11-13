# Kho hàng (cấp 1) (kho)

Cắt NGUYÊN điểm ảnh từ ảnh gốc web img/kho.webp (9 điểm ảnh / đơn vị game), không thu nhỏ, PNG không mất chi tiết. Mỗi khung 1 file.

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false, offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân móng (3x3 ô) trên mặt đất. Bản xoay kho2 = lật ngang (scale x -1) cùng khung.

2 lớp: b = nhà (vẽ trước), f = đồ phía trước (bao lúa, cân, xe rùa...; vẽ sau). Web vẽ: b, chữ bảng hiệu, icon hàng trong cửa, rồi f. Cấp 2 (kho_l2) vẫn là code canvas cũ, chưa có ảnh.

Chữ bảng hiệu do game vẽ (ảnh để trống bảng), font Nunito:
- "KHO HÀNG": điểm 3D (u=1.5, v=Yr+.09, z=67) theo EP(), chữ 800 5px "Nunito",sans-serif, màu ngày #f1e6c8 / đêm #cfc2a0; nghiêng theo mặt iso transform(1,.5,0,1); khi lật ngang chữ KHÔNG lật.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
bd.png | 1756x1462 | -91.11, -116.33 | 195.11 x 162.44
bn.png | 1756x1462 | -91.11, -116.33 | 195.11 x 162.44
fd.png | 894x471 | -84.33, -18.22 | 99.33 x 52.33
fn.png | 894x470 | -84.33, -18.22 | 99.33 x 52.22
