# tram
Cây tràm: bản web vẽ bằng code (at.plants.tram.draw, không có ảnh). Xuất từ chính hàm đó ở 9 px/đơn vị game.
Tên khung: d|n (ngày / đêm) + mùa xi (0..3; 1 = trổ bông, 3 = lá khô) + dáng t (0..3).
atlas.json: ox,oy = góc trên trái so với neo (tâm ô, đơn vị game), gw,gh = cỡ vẽ. Godot: offset=(ox,oy), scale=1/9.
