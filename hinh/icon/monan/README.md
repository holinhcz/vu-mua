# Icon món ăn chế biến, dựng 3D

PNG 512x512 nền trong suốt, mỗi món 1 file.
- Dựng khối 3D (SDF, tia quét từng điểm ảnh) ở 2048 px rồi thu về 512, ánh sáng mờ dịu, không đốm bóng.
- Cỡ đều: cạnh dài nhất của hình = 84% khung 512 (430 px), nằm giữa khung.
- atlas.json: tên, kích thước, bbox (vùng có hình trong ảnh 512).
- xem/: ảnh xem thử (to, phóng 3x, cỡ 48/64/96/128).
- Script gốc: ../../../src/monan3d/ (python3 <tên>.py <file.png>; NQ=768 để xem nhanh).

| File | Món | Xưởng |
|---|---|---|
| banhmi.png | Bánh mì | lò bánh mì |

## Đã gắn vào Bếp củi (bản 327)
lau_cua_dong, lau_ga_ot_hiem, lau_luon, lau_ech, lau_ga_la_e, lau_hai_san, lau_de, lau_bo, lau_ca_linh, lau_ca_keo (cùng mã), com_chien_hai_san -> com_chien_hs, muc_xao, rau_muong_xao, hu_tieu_nam_vang -> hu_tieu.

## Hình món chưa có trong game (bản 309) — làm món thì lấy dùng
Cắt từ tấm ảnh người dùng (src/tools/cut_mon.py), 512 nền trong, cỡ chuẩn 430. Gắn vào game: bọc WebP thành ui/svg/kh/<mã món>.svg.
| File | Món |
|---|---|
| lau_vit_chao.png | Lẩu vịt nấu chao |
| lau_ga_la_giang.png | Lẩu gà lá giang |
| lau_ca_hu.png | Lẩu cá hú măng chua |
| lau_nam.png | Lẩu nấm thập cẩm |
| lau_thai.png | Lẩu thái chua cay (bản 310) |
| lau_bo_giam.png | Lẩu bò nhúng giấm |
| lau_ca_chep.png | Lẩu cá chép om dưa |
| lau_rieu_cua.png | Lẩu riêu cua bắp bò |
| lau_ca_loc.png | Lẩu cá lóc chua cay |
| lau_thac_lac.png | Lẩu cá thác lác khổ qua |

## Hình tạm (bản 327) — chờ hình thật thì thay ui/svg/kh/<mã>.svg
pho_bo (tạm hình hu_tieu_bv), banh_canh_cl (canh_chua), ech_xao (ga_xao).
Cây tạm: toi (hình cây hanh, src/tools/cay/them_tam.py), la_e (hình cây rau_ram); icon toi / la_e lấy từ hinh/icon/anh (toi.png, lae.png).
Nguyên liệu muc / cua / ech chưa có hình.

## Xe nước mía (bản 329)
Gắn hình thật: nuoc_cam_carot, nuoc_thom, tra_tac, st_sapoche, st_bo_sr. Icon khom, qua_sapoche lấy từ hinh/icon/anh.
Hình tạm: nuoc_dua (qua_dua), nuoc_buoi (nuoc_cam), st_saurieng / st_dau / st_dudu / st_mangcut (sinh_to), qua_tac (traicay/quyt.png), qua_bo (qua_xoai).
Cây tạm: khom trên ruộng = hình cây la_dua; cây ăn trái ft_tac, ft_sapoche, ft_bo = hình cây xoài (ui/snap/bd_pics.json).

## Quán chè (bản 330) — hình tạm
che_ba_ba, che_khoai_mon (tạm che_khoai), che_dau_den (che_me_den), che_thai (che_ba_mau), tau_hu (sua_dau_nanh), che_bi_do (che_bap).

## Lò bánh quê (bản 331) — hình tạm
xoi_la_dua, xoi_xeo (tạm xoi), banh_xeo, banh_can (banh_khot), banh_gio (banh_beo), banh_hoi (banh_cuon), banh_chung (banh_tet).

## Nồi kho (bản 332) — hình tạm
thit_kho (Thịt kho tiêu, vẫn hình thịt kho trứng cũ), ca_keo_kho (ca_ro_kho), mam_kho (thit_kho_nd), ca_chep_kho (ca_kho), ech_kho (luon_um), cua_rang_me, thit_rim_tom (tom_rim).

## Lò nướng (bản 333)
banh_chuoi_nuong gắn hình thật (làm ở Lò bánh mì). Hình tạm: nem_nuong, catim_mo_hanh (bachi_nuong), muc_nuong, cua_nuong (tom_nuong), ca_keo_nuong (ca_loc_trui), bap_nuong (ga_nuong_sa), khoai_nuong (oc_nuong).

## Hàng chả (bản 334) — hình tạm
cha_muc (cha_ca), cha_cua (cha_tom), xiu_mai (bo_vien).

## Lò bánh nướng (bản 335)
banh_mi_cha_ca gắn hình thật. Hình tạm: banh_mi_xm (banh_mi_cha), banh_mi_op (banh), su_kem (bong_lan), banh_dua (banh_bido).

## Vại muối dưa (bản 336) — hình tạm
mam_ca_linh (dua_mon), nuoc_mam, mam_tom (tuong_ot). sua_chua_de chưa có hình.

## Giàn phơi (bản 337) — hình tạm
kho_muc, kho_ca_ro, bo_kho_say, kho_ga (kho_ca), me_say (xoai_say).

## Lò bánh tráng (bản 338) — hình tạm
bt_nuong (bt_chabong), bt_muoi_tom (bt_tron), bt_me_chua (bt_me).

## Lò rang hạt + cà phê (bản 339) — hình tạm
muoi_me (muoi_dp), caphe_den (nuoc_mia), caphe_sua (sinh_to), qua_caphe (icon đậu phộng / mè), cây ft_caphe = hình cây xoài.

## Lò đường (bản 340) — hình tạm
mut_khoai (mut_chomchom), mut_tac (mut_mangcut), keo_chuoi (keo_dua).

## Cối xay + khoai mì (bản 341)
banh_khoai_mi (Lò bánh nướng), banh_tam_khoai_mi (Lò bánh quê) gắn hình thật. Cây khoai_mi: icon hinh/icon/anh/khoaimi.png, hình cây trên ruộng tạm = cây khoai lang.

## Ruộng muối (bản 342) — hình tạm
muoi_ot, muoi_tom, muoi_tieu (icon muối hột vẽ code).

## Bản 363 — hình thật
bun_bo_hue, mi_quang, bun_cha gắn vào game. cao_lau.png (Cao lầu) lưu sẵn, chưa có món trong game.

## Bản 364 — hình thật
xoi_thit, com_det, thinh, caphe_rang.

## Bản 365 — hình thật
gao, bot_nep, bot (bột mì), bot_gao.
