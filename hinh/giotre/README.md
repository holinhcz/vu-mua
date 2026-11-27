# Giỏ tre đựng icon món hàng (đơn hàng) – 4 cấp, 9px

Mỗi cấp 2 lớp, cùng khung 616x336 (cùng kích thước, cùng vị trí):
- `gioN_sau.png`: cả giỏ (vẽ trước)
- icon món hàng vẽ giữa
- `gioN_truoc.png`: thành + vành phía trước (vẽ sau, che chân icon)

Đế: `de.png` 616x455 (gỗ tràm, 4 chân), cùng góc trên trái + bề ngang với giỏ. Thứ tự vẽ tại cùng toạ độ: `de.png` -> `gioN_sau` -> icon -> `gioN_truoc`.

Cấp: 1 tre tươi · 2 tre hun nâu hoa thoi, quai mây · 3 cói kiểu chiếu + cột/vành gỗ tràm, quai gỗ · 4 mây sơn son, đai đồng, đĩa sen xà cừ, quai đồng.
Code: `src/giotre/giotre.py` (`python3 giotre.py OUTDIR TIER 700`), đế `src/giotre/de.py` (`python3 de.py OUTDIR 700`).
