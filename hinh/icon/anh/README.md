# Icon ảnh (Link gửi 17-11-2026)

- `goc/`: 5 tấm gốc (6 cột x 3 hàng, tên in trên mỗi hình): traicay1, rau1, nongsan1, rauthom1, traicay2.
- 90 file PNG 512x512 nền trong suốt, tên = tên tiếng Việt bỏ dấu (Bồn bồn = `bonbonrau`, Bòn bon = `bonbon`).
  Cạnh dài nhất của hình = 430 px (84% khung), nằm giữa khung, như icon cũ trong ../traicay.
- `atlas.json`: tên, tấm gốc, bbox. `game_map.json`: mã món trong game <- file ảnh (46 món đang dùng).
- Món nào có trong game thì `ui/svg/kh/<mã>.svg` (bên src/godot) là SVG bọc ảnh WebP 256 px (mọi chỗ trong game
  đọc hình món qua file SVG này nên tự đổi theo). Món chưa có trong game: để sẵn đây, mai mốt thêm món thì dùng.
- Làm lại: `python3 cut.py goc out` rồi `python3 mk_svg.py out ../../../src/godot/ui/svg/kh`.
