# Bè nổi (nhà bè trên sông, 2x2 ô)

Link OK bản v3 ngày 2026-11-25. Chỉ là ẢNH, CHƯA gắn vào game: bên nào làm công trình trên nước thì lấy xài.

Dựng 3D bằng đúng bộ vẽ công trình/xưởng (cùng máy vẽ với bến ghe, nhà tranh, xưởng): phao 4 bó tre gai buộc mây nửa chìm,
đà tràm, sàn ống tre tròn, chòi lá (cột tràm, vách phên tre đan, mái lá), đèn dầu treo cột, lu nước nắp gỗ + gáo,
chõng tre + nón lá, giỏ cá, ô lồng cá (lỗ trống giữa sàn để nước của game lộ ra), 2 cọc tràm neo, thang tre xuống nước.

9 điểm ảnh / đơn vị game, PNG không mất chi tiết, mỗi khung 1 file. Nền trong suốt: KHÔNG vẽ nước, game tự vẽ nước bên dưới
(mặt nước của ảnh ở z = 0; phao, cọc, thang đã có vệt gợn nước nhạt quanh chân).

atlas.json: frames{file,w,h,ox,oy,gw,gh}. ox,oy,gw,gh = đơn vị game (1 ô = 64x32). Godot: Sprite2D centered=false,
offset=(ox,oy)*k, scale=1/px_per_unit*k.

Gốc toạ độ = TÂM chân bè (2x2 ô) trên mặt nước. Hướng còn lại = lật ngang (scale x -1) cùng khung.

Khung | w x h px | ox, oy | gw x gh
---|---|---|---
0d.png (ngày) | 1258x949 | -65.78, -73.22 | 139.78 x 105.44
0n.png (đêm, đèn dầu sáng) | 1258x949 | -65.78, -73.22 | 139.78 x 105.44

Đèn dầu: điểm sáng ban đêm đã vẽ sẵn trong 0n.png. Nếu muốn lửa động thì thêm hạt lửa Godot nhỏ ở ngọn đèn (xem godot/xuong/LUA.md).

Code: nong-trai-chung/src/benoi/benoi3d.py (bản chép trong repo: src/tools/cc/moi/benoi3d.py).
Chạy: `python3 benoi3d.py prev OUT.png [n]` = xem 1 khung (n = đêm); `python3 benoi3d.py atlas OUTDIR` = xuất 0d/0n + atlas.json.
Cần các bộ src/lobanh, coixay, lobanhmi, chuongga, benghe, kho, dendau, ruongmuoi, pxr, choi, den nằm cạnh thư mục benoi.
