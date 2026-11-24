# Map đấu boss Chúa Cào Cào (trang riêng /vu-mua/bosscc/)
Godot 4.5.1 gl_compatibility, dùng chung engine Nông Trại (../engine.wasm). Gói riêng bcc.pck.
- main.gd: map. Nền arena.gdshader = phần cỏ/sân/ruộng/đường của ground.gdshader làng; cây/đồ = ảnh 9px từ hinh/ (đổi qua webp không mất).
  Bố cục v2 (Link 11-24): boss ở nửa trên trước ruộng chữ V, nửa dưới toàn sân cho người đứng; nút "Vô đánh" bật bảng ghép hình giả phủ nửa dưới. main_v1.gd = bố cục cũ.
- boss.gd: boss 3D Cào Cào (hinh godot/boss/caocao/3d) trong SubViewport trong suốt, camera trực giao 30°.
- Ảnh/phông nạp thẳng (importer="keep" trong .import) để Image.load_from_file chạy trong bản web.
- Xuất: `godot --headless --path . --export-pack Web out/bcc.pck`, rồi index.html/ver.txt từ timso/index.html (đổi tên gói, PCK, B=crc32).
- Chụp thử: SHOT=a.png BOARD=1 xvfb-run godot --path . --resolution 1440x3120
