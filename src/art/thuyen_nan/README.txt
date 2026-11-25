Thuyền nan 3D (công trình "boat", Thuyền nan) — 11-25, dựng bằng src/tools/cc/moi/nan3d.py, 6 px/đơn vị, webp không mất nét, chỉ ngày.
Kích thước + neo theo logic cũ at.builds.boat (2x1 ô, mặt nước web z 2.4, sào mũi, cọc buộc đuôi, bóng nước).
Tên <màu>_<hướng>:  do = sơn dải đỏ (chèo + cuộn dây) | xanh = sơn dải xanh (thêm giỏ cá)
  hướng 0: mũi +r, chiếm 2x1 (fw 2 fd 1) = hướng bản cũ
  hướng 1: mũi +o, chiếm 1x2 (fw 1 fd 2)
  hướng 2: mũi -r, 2x1
  hướng 3: mũi -o, 1x2
atlas.json: px_per_unit 6; mỗi frame w h (px), fw fd (ô), ox oy = góc trên trái so với neo (tâm vùng ô chiếm, z 0), gw gh (đơn vị game).
Godot: offset = (ox, oy), scale = 1/6 (bản cũ godot/congtrinh/ghe là 9 px nên scale 1/9 — đổi theo px_per_unit).
Chưa gắn: cong_trinh.json "boat" chưa có rot / vars màu — bên gắn thêm boat2..4 (như ben -> ben2..4) và chọn màu theo vars 2.
