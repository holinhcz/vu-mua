# Hoa cỏ 1/4 ô (the build menu's Hoa cỏ minis), v756 (2026-11-07)

v757 (Link "Fix", "vẽ to chiếm trọn 1/4 ô, loại nào cao vẽ cao"): KU x2.0, lau 0.62-0.76 m, sao nhái 0.55-0.72, hoa tím 0.5-0.62; fixed the 10-point critique (xem/hoaco-nhan-xet.jpg): grey egg straw mushrooms, bigger pebbles with blades behind, drooping beige plumes, cúc vàng rows of petals, mười giờ fleshy rosettes, cockscomb fan facing the viewer, ngũ sắc floret rings, more dừa cạn flowers, smaller shadows. REV hc2. Picture xem/hoaco-v757.jpg.

Link: "Vẽ lại hết hoa cỏ trong xây dựng, trừ bụi cây cỏ dại lau sậy, kích thước 1/4 ô như cũ".
Kit `hoaco.py` (../chuoi camera/sun/night/SOFT edge, ../co blades + atlas helpers, ../dambut hull), hibiscus/mai
greens, KU x1.25 so each mini is about the old size (18-20 game units). 14 kinds x 4 seeds, frames d/n + id + seed:
c_xanh, c_lau, bui_la, da_cuoi, nam, h_cuc_vang, h_cuc_trang, h_muoi_gio, h_sao_nhai, h_dua_can, h_tim, h_ngu_sac,
h_mong_ga, h_van_tho (see the header of hoaco.py for the real plant behind each).

Commands: `python3 grid.py all [n] out.png` (preview grid), `python3 hoaco.py atlas OUTDIR OUTDIR/hoaco.json`,
`python3 patch_hoaco.py index.html atlas.json out.html`.
The patch replaces the iq[id] drawers (called already scaled by Jy=1.75, for the village and the menu preview), so the
old LM list, prices and quarter-tile placement stay. Minis are baked into the ground pieces: on sheet load it redraws
the pieces holding minis once per REV (localStorage nt-hoaco) or if any old drawing was used before the sheet loaded.
Bump REV in patch_hoaco.py when the sheet changes. Picture ../../xem/hoaco-moi.jpg.

v758 (Link): đá cuội and nấm rơm removed (REMOVE in patch_hoaco.py, GONE in hoaco.py; placed ones dropped by the game's clean-up, their pieces redrawn via window.__hcGone). REV hc3.
