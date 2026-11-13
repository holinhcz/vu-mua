# Vụ Mùa: mã nguồn Godot

Nhánh này chỉ chứa mã nguồn. Bản đang chạy (GitHub Pages) nằm ở nhánh `main`, không liên quan.

- `src/godot/`: dự án Godot 4.5.1 (gl_compatibility). Phần nền, làng, cảnh, trời, đêm gồm `main.gd`, `*.gdshader`, `songgen.gd`, `pondgen.gd`. Phần logic và giao diện gồm `logic/*.gd`, `ui/*` (dữ liệu, hình UI, font). `logic_project.godot` là project.godot của phần logic (autoload Boot).
- `src/tools/`: script đóng gói và xuất. `pack.py` cắt pck, `merge_logic.py` gộp gói logic vào pck nền, `mkfiles.py` tạo files.json, `tools/*.py` xuất hình đêm, lô đất, cảnh.
- `src/shell/index.html`: trang vỏ của bản web (tải pck nhiều mảnh, Firebase, giftcode).
- `hinh/`: hình gốc 9px/đơn vị (cây, công trình, xưởng, icon...) do các thread vẽ xuất ra.

Dữ liệu đã đóng gói mà game tải lúc chạy (n/, d/, l/) nằm ở nhánh `main`.
