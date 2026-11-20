# Đua Gà → Godot (bản 421, bước 1)

Code: src/godot/logic/dg/
- dg_race.gd: luật đua + AI (newRace, step, aiDrive, respawn, ranks, ô bắp, bùn, dốc rơm, vịt, rơi nước), port 1:1 từ dua-ga/index.html.
- dg_map.gd: dữ liệu đường (PX/PY/NX/NY/TA/WD/BR...), nước, ao.
- dg_res.gd: tải gói l/, giải hình cảnh lúc vào đua, khung con đua giải khi cần (LRU 320, 5 ms/khung).
- dg_view.gd: vẽ trời, mặt đất (shader port sec_glground.js, pad/bùn trong texture 28x1 RGBAF, không mảng uniform), cảnh, gà (painter sort).
- dg_game.gd: gốc Control phóng K: menu chọn con + độ khó, màn tải, HUD (cỡ điện thoại của web), nút cảm ứng, tạm dừng, kết quả.
- logic/ui_dg.gd: mở từ Menu > Giải trí > "Đua gà", xu qua w_duong.dg_end.

Gói hình (l/, tải lười, mã ?v trong logic/lv.json):
- dg_map_nongtrai (5.3 MB): hình cảnh vẽ bằng code web, nền mac/inf (webp lossless exact), dirt/grass/mask; meta {spr, map}.
- dg_r_<id> (nét, con mình chơi) / dg_r_<id>_1 (nửa cỡ, đối thủ): 17 góc x (8 nhịp chạy + 1 đứng), S=9.6 px/đơn vị.
- dg_r_npc_1, dg_card (thẻ menu + meta chars/pers).

Làm lại gói:
1. `node mk_test.py`-style test.html từ /mnt/project-files/dua-ga/index.html (mk_test.py).
2. `node bake_racer.js` (+ `node bake_racer.js npc`) → out/racer; `node ex_map.js nongtrai` → out/map, out/spr.
3. `python3 mk_bundles.py racers map` → lb/; rồi `python3 card_meta.py` (thêm chars vào dg_card).
4. Build: fxp = copy src/godot (import 1 lần), `--export-pack Web new.pck`, rồi
   `python3 hp.py <main> new.pck "<tên trong pck>" <bản> "<lb/a.wasm,lb/b.wasm,...>"` (hp.py = hot_patch.py + chép gói l/, ghi lv.json, files.json).

Test native: dgq/ = project.godot + main.tscn của xt_build + test_main.gd (đổi tên main.gd), symlink logic, ui/font;
`python3 -m http.server 8765` trong thư mục có l/ -> lb/. Lệnh: go, lap1 (1 vòng + tự đua), pause, tap_x,y, shot_X, quit.
CPU (llvmpipe) chạy ~10 fps, đừng tin số fps này.

Bước 2 còn: vật phẩm (thúng ?), kỹ năng, thời tiết, âm thanh. Bước 3: Giải Làng, 2 map còn lại, cho ăn/đồ, nhiệm vụ, lưu.

## Bước 3 (bản 430)
- Map khác: `bash bake_maps.sh` (`node ex_map.js <id>` -> out/spr_<id> qua symlink out/spr, rồi `python3 mk_bundles.py map:<id>` -> lb/dg_map_<id>.wasm).
- Thẻ map + dữ liệu nón/chặng/nhiệm vụ: `node ex_card2.js` -> out/card2/, rồi `python3 add_card2.py` (CHẠY TỪ BẢN SAO lb/dg_card.wasm.b425, đừng chạy 2 lần lên cùng file).
- Nón: `node bake_hat.js <id,...>` (vẽ gà có nón trừ gà không nón = phần nón, out/hat/<id>/), rồi `python3 pk_hat.py` -> lb/dg_h_<id>.wasm.
- Test lệnh mới trong test_main.gd: act_<tên>=<đối số> (vd act_hat=nonla, act_map=choque, act_mode=cup, act_next), my_<y> cuộn menu, unl mở khóa map, sv in save.
