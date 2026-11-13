# Cây cối / hoa / nông sản cho Godot (xuất 11-12)
TẤT CẢ 9 px/đơn vị game. Mỗi khung 1 file PNG, không thu nhỏ, không nén mất. Mỗi thư mục có atlas.json (w,h px; ox,oy,gw,gh theo đơn vị game như bảng G web, neo = tâm ô) + README. Godot: offset=(ox,oy), scale=1/9.
d = ngày, n = đêm. Cây trồng: số cuối = giai đoạn 1-3. Cây trái: d<dáng><chín>. Chuối dw* = chuối rừng. Cao su 12 khung theo mùa.
Cây mà web chỉ có 5 px được xuất lại từ chính code gốc src/<cây>/ ở 9 px: cùng mô hình, cùng tên khung, màu khớp bản game (so ảnh xem/godot-cay-9px-truoc-sau.png).

thư mục | px/đơn vị | số khung | khung lớn nhất (px) | cách lấy
---|---|---|---|---
caytrong/bap | 9 | 6 | 559x468 | cắt từ ảnh gốc
caytrong/bau | 9 | 6 | 377x354 | cắt từ ảnh gốc
caytrong/bi_dao | 9 | 6 | 392x346 | cắt từ ảnh gốc
caytrong/bido | 9 | 6 | 516x283 | cắt từ ảnh gốc
caytrong/bong_vai | 9 | 6 | 370x301 | cắt từ ảnh gốc
caytrong/cachua | 9 | 6 | 444x403 | cắt từ ảnh gốc
caytrong/cai | 9 | 6 | 478x306 | cắt từ ảnh gốc
caytrong/carot | 9 | 6 | 455x392 | cắt từ ảnh gốc
caytrong/catim | 9 | 6 | 389x303 | cắt từ ảnh gốc
caytrong/cham | 9 | 6 | 351x304 | cắt từ ảnh gốc
caytrong/dau | 9 | 6 | 465x348 | cắt từ ảnh gốc
caytrong/dau_bap | 9 | 6 | 383x321 | cắt từ ảnh gốc
caytrong/dau_den | 9 | 6 | 480x316 | cắt từ ảnh gốc
caytrong/dau_nanh | 9 | 6 | 467x297 | cắt từ ảnh gốc
caytrong/dau_rong | 9 | 6 | 417x335 | cắt từ ảnh gốc
caytrong/dau_xanh | 9 | 6 | 452x297 | cắt từ ảnh gốc
caytrong/dauphong | 9 | 6 | 410x321 | cắt từ ảnh gốc
caytrong/dua_leo | 9 | 6 | 419x471 | cắt từ ảnh gốc
caytrong/duahau | 9 | 6 | 521x284 | cắt từ ảnh gốc
caytrong/gung | 9 | 6 | 348x323 | cắt từ ảnh gốc
caytrong/hanh | 9 | 6 | 429x317 | cắt từ ảnh gốc
caytrong/hanh_tay | 9 | 6 | 442x326 | cắt từ ảnh gốc
caytrong/huong_duong | 9 | 6 | 400x455 | cắt từ ảnh gốc
caytrong/kho_qua | 9 | 6 | 410x336 | cắt từ ảnh gốc
caytrong/khoai | 9 | 6 | 463x368 | cắt từ ảnh gốc
caytrong/khoai_mon | 9 | 6 | 414x324 | cắt từ ảnh gốc
caytrong/la_dua | 9 | 6 | 507x294 | cắt từ ảnh gốc
caytrong/lua | 9 | 6 | 515x398 | cắt từ ảnh gốc
caytrong/me | 9 | 6 | 378x311 | cắt từ ảnh gốc
caytrong/mia | 9 | 6 | 563x475 | cắt từ ảnh gốc
caytrong/muop | 9 | 6 | 415x332 | cắt từ ảnh gốc
caytrong/nep | 9 | 6 | 548x427 | cắt từ ảnh gốc
caytrong/nghe | 9 | 6 | 385x325 | cắt từ ảnh gốc
caytrong/ot | 9 | 6 | 462x352 | cắt từ ảnh gốc
caytrong/rau_muong | 9 | 6 | 375x309 | cắt từ ảnh gốc
caytrong/rau_ram | 9 | 6 | 446x320 | cắt từ ảnh gốc
caytrong/sa | 9 | 6 | 507x333 | cắt từ ảnh gốc
caytrong/xa_lach | 9 | 6 | 438x227 | cắt từ ảnh gốc
caytrai/buoi | 9 | 8 | 818x740 | xuất lại từ code gốc
caytrai/cam | 9 | 8 | 840x660 | xuất lại từ code gốc
caytrai/chomchom | 9 | 8 | 823x801 | xuất lại từ code gốc
caytrai/chuoi | 9 | 16 | 959x991 | xuất lại từ code gốc
caytrai/dieu | 9 | 8 | 837x828 | xuất lại từ code gốc
caytrai/dua | 9 | 8 | 1113x1447 | xuất lại từ code gốc
caytrai/dudu | 9 | 8 | 819x995 | xuất lại từ code gốc
caytrai/man | 9 | 8 | 799x800 | xuất lại từ code gốc
caytrai/mangcut | 9 | 8 | 766x881 | xuất lại từ code gốc
caytrai/me | 9 | 8 | 880x775 | xuất lại từ code gốc
caytrai/mit | 9 | 8 | 809x816 | xuất lại từ code gốc
caytrai/nhan | 9 | 8 | 866x741 | xuất lại từ code gốc
caytrai/saurieng | 9 | 8 | 854x1023 | xuất lại từ code gốc
caytrai/thanhlong | 9 | 8 | 678x666 | xuất lại từ code gốc
caytrai/xoai | 9 | 8 | 830x725 | cắt từ ảnh gốc
caylang/caosu | 9 | 24 | 811x1207 | xuất lại từ code gốc
caylang/cau | 9 | 8 | 954x1591 | xuất lại từ code gốc
caylang/dambut | 9 | 8 | 735x538 | xuất lại từ code gốc
caylang/duanuoc | 9 | 8 | 1266x871 | xuất lại từ code gốc
caylang/rom | 9 | 8 | 570x789 | xuất lại từ code gốc
caylang/tre | 9 | 8 | 1307x1300 | xuất lại từ code gốc
kieng/bonggiay | 9 | 8 | 649x599 | xuất lại từ code gốc
kieng/cc_bong_trang | 9 | 8 | 824x606 | cắt từ ảnh gốc
kieng/cc_huong_duong | 9 | 8 | 321x705 | cắt từ ảnh gốc
kieng/cc_lai | 9 | 8 | 721x521 | cắt từ ảnh gốc
kieng/cc_luoi_ho | 9 | 8 | 440x681 | cắt từ ảnh gốc
kieng/cc_nha_dam | 9 | 8 | 605x397 | cắt từ ảnh gốc
kieng/cc_sa | 9 | 8 | 631x471 | cắt từ ảnh gốc
kieng/cc_xuong_rong | 9 | 8 | 449x504 | cắt từ ảnh gốc
kieng/duongxi | 9 | 4 | 660x449 | xuất lại từ code gốc
kieng/mai | 9 | 32 | 935x907 | xuất lại từ code gốc
hoaco/bui_la | 9 | 8 | 219x194 | cắt từ ảnh gốc
hoaco/c_lau | 9 | 8 | 396x543 | cắt từ ảnh gốc
hoaco/c_xanh | 9 | 8 | 388x282 | cắt từ ảnh gốc
hoaco/h_cuc_la_nho | 9 | 8 | 211x248 | cắt từ ảnh gốc
hoaco/h_cuc_trang | 9 | 8 | 203x231 | cắt từ ảnh gốc
hoaco/h_cuc_vang | 9 | 8 | 218x272 | cắt từ ảnh gốc
hoaco/h_da_yen | 9 | 8 | 214x158 | cắt từ ảnh gốc
hoaco/h_dua_can | 9 | 8 | 215x184 | cắt từ ảnh gốc
hoaco/h_mai_dia | 9 | 8 | 190x145 | cắt từ ảnh gốc
hoaco/h_mong_ga | 9 | 8 | 218x328 | cắt từ ảnh gốc
hoaco/h_mong_tay | 9 | 8 | 156x238 | cắt từ ảnh gốc
hoaco/h_muoi_gio | 9 | 8 | 279x155 | cắt từ ảnh gốc
hoaco/h_ngu_sac | 9 | 8 | 215x173 | cắt từ ảnh gốc
hoaco/h_sao_nhai | 9 | 8 | 234x363 | cắt từ ảnh gốc
hoaco/h_tim | 9 | 8 | 166x318 | cắt từ ảnh gốc
hoaco/h_van_tho | 9 | 8 | 184x236 | cắt từ ảnh gốc
hoaco/k_hung_que | 9 | 8 | 171x193 | cắt từ ảnh gốc
hoaco/k_lan_chi | 9 | 8 | 310x165 | cắt từ ảnh gốc
hoaco/k_ot | 9 | 8 | 161x154 | cắt từ ảnh gốc
thuysinh/beo | 9 | 8 | 355x105 | cắt từ ảnh gốc
thuysinh/dien_dien | 9 | 12 | 601x587 | cắt từ ảnh gốc
thuysinh/keo_neo | 9 | 12 | 362x372 | cắt từ ảnh gốc
thuysinh/luc_binh | 9 | 18 | 127x174 | cắt từ ảnh gốc
thuysinh/rau_muong | 9 | 8 | 515x242 | cắt từ ảnh gốc
thuysinh/sung | 9 | 8 | 526x254 | cắt từ ảnh gốc
thuysinh/sung_ma | 9 | 12 | 451x257 | cắt từ ảnh gốc
caydai/bui_cay | 9 | 8 | 634x408 | cắt từ ảnh gốc
caydai/bui_co | 9 | 8 | 522x508 | cắt từ ảnh gốc
caydai/co_lau | 9 | 8 | 621x804 | cắt từ ảnh gốc
caydai/goc_cay | 9 | 4 | 359x259 | cắt từ ảnh gốc
caydai/nhanh_kho | 9 | 4 | 380x177 | cắt từ ảnh gốc

Không có ảnh (web vẽ bằng code): tràm, đá, bến, thuyền. Icon trái cây ở icon/traicay.

Code vẽ: code_ve_cay/ (README trong đó, đủ kit chạy được, cây 23 loại đã chỉnh sẵn 9 px).


## Muốn sửa cây nào -> mở file nào
hình | code vẽ
---|---
caytrong/bap | code_ve_cay/caysen/caysen.py (hàm _bap, khung bap1-3)
caytrong/bau | code_ve_cay/caysen/caysen.py (hàm _bau, khung bau1-3)
caytrong/bi_dao | code_ve_cay/caysen/caysen.py (hàm _bi_dao, khung bi_dao1-3)
caytrong/bido | code_ve_cay/caysen/caysen.py (hàm _bido, khung bido1-3)
caytrong/bong_vai | code_ve_cay/caysen/caysen.py (hàm _bong_vai, khung bong_vai1-3)
caytrong/cachua | code_ve_cay/caysen/caysen.py (hàm _cachua, khung cachua1-3)
caytrong/cai | code_ve_cay/caysen/caysen.py (hàm _cai, khung cai1-3)
caytrong/carot | code_ve_cay/caysen/caysen.py (hàm _carot, khung carot1-3)
caytrong/catim | code_ve_cay/caysen/caysen.py (hàm _catim, khung catim1-3)
caytrong/cham | code_ve_cay/caysen/caysen.py (hàm _cham, khung cham1-3)
caytrong/dau | code_ve_cay/caysen/caysen.py (hàm _dau, khung dau1-3)
caytrong/dau_bap | code_ve_cay/caysen/caysen.py (hàm _dau_bap, khung dau_bap1-3)
caytrong/dau_den | code_ve_cay/caysen/caysen.py (hàm _dau_den, khung dau_den1-3)
caytrong/dau_nanh | code_ve_cay/caysen/caysen.py (hàm _dau_nanh, khung dau_nanh1-3)
caytrong/dau_rong | code_ve_cay/caysen/caysen.py (hàm _dau_rong, khung dau_rong1-3)
caytrong/dau_xanh | code_ve_cay/caysen/caysen.py (hàm _dau_xanh, khung dau_xanh1-3)
caytrong/dauphong | code_ve_cay/caysen/caysen.py (hàm _dauphong, khung dauphong1-3)
caytrong/dua_leo | code_ve_cay/caysen/caysen.py (hàm _dua_leo, khung dua_leo1-3)
caytrong/duahau | code_ve_cay/caysen/caysen.py (hàm _duahau, khung duahau1-3)
caytrong/gung | code_ve_cay/caysen/caysen.py (hàm _gung, khung gung1-3)
caytrong/hanh | code_ve_cay/caysen/caysen.py (hàm _hanh, khung hanh1-3)
caytrong/hanh_tay | code_ve_cay/caysen/caysen.py (hàm _hanh_tay, khung hanh_tay1-3)
caytrong/huong_duong | code_ve_cay/caysen/caysen.py (hàm _huong_duong, khung huong_duong1-3)
caytrong/kho_qua | code_ve_cay/caysen/caysen.py (hàm _kho_qua, khung kho_qua1-3)
caytrong/khoai | code_ve_cay/caysen/caysen.py (hàm _khoai, khung khoai1-3)
caytrong/khoai_mon | code_ve_cay/caysen/caysen.py (hàm _khoai_mon, khung khoai_mon1-3)
caytrong/la_dua | code_ve_cay/caysen/caysen.py (hàm _la_dua, khung la_dua1-3)
caytrong/lua | code_ve_cay/caysen/caysen.py (hàm _lua, khung lua1-3)
caytrong/me | code_ve_cay/caysen/caysen.py (hàm _me, khung me1-3)
caytrong/mia | code_ve_cay/caysen/caysen.py (hàm _mia, khung mia1-3)
caytrong/muop | code_ve_cay/caysen/caysen.py (hàm _muop, khung muop1-3)
caytrong/nep | code_ve_cay/caysen/caysen.py (hàm _nep, khung nep1-3)
caytrong/nghe | code_ve_cay/caysen/caysen.py (hàm _nghe, khung nghe1-3)
caytrong/ot | code_ve_cay/caysen/caysen.py (hàm _ot, khung ot1-3)
caytrong/rau_muong | code_ve_cay/caysen/caysen.py (hàm _rau_muong, khung rau_muong1-3)
caytrong/rau_ram | code_ve_cay/caysen/caysen.py (hàm _rau_ram, khung rau_ram1-3)
caytrong/sa | code_ve_cay/caysen/caysen.py (hàm _sa, khung sa1-3)
caytrong/xa_lach | code_ve_cay/caysen/caysen.py (hàm _xa_lach, khung xa_lach1-3)
caytrai/buoi | code_ve_cay/buoi/buoi.py
caytrai/cam | code_ve_cay/cam/cam.py
caytrai/chomchom | code_ve_cay/chomchom/chom.py
caytrai/chuoi | code_ve_cay/chuoi/build.py + chuoi/chuoi.py
caytrai/dieu | code_ve_cay/dieu/dieu.py
caytrai/dua | code_ve_cay/dua/dua.py
caytrai/dudu | code_ve_cay/dudu/dudu.py
caytrai/man | code_ve_cay/man/man.py
caytrai/mangcut | code_ve_cay/mangcut/mangcut.py
caytrai/me | code_ve_cay/me/me.py
caytrai/mit | code_ve_cay/mit/mit.py
caytrai/nhan | code_ve_cay/nhan/nhan.py
caytrai/saurieng | code_ve_cay/saurieng/saurieng.py
caytrai/thanhlong | code_ve_cay/thanhlong/thanhlong.py
caytrai/xoai | code_ve_cay/caysen/caysen.py (khung x00..x11)
caylang/caosu | code_ve_cay/caosu/caosu.py (NOSH=1)
caylang/cau | code_ve_cay/cau/cau.py
caylang/dambut | code_ve_cay/dambut/dambut.py
caylang/duanuoc | code_ve_cay/duanuoc/duanuoc.py
caylang/rom | code_ve_cay/rom/rom.py
caylang/tre | code_ve_cay/tre/tre.py
kieng/bonggiay | code_ve_cay/bonggiay/bonggiay.py
kieng/cc_bong_trang | code_ve_cay/caycanh/caycanh.py (bong_trang)
kieng/cc_huong_duong | code_ve_cay/caycanh/caycanh.py (huong_duong)
kieng/cc_lai | code_ve_cay/caycanh/caycanh.py (lai)
kieng/cc_luoi_ho | code_ve_cay/caycanh/caycanh.py (luoi_ho)
kieng/cc_nha_dam | code_ve_cay/caycanh/caycanh.py (nha_dam)
kieng/cc_sa | code_ve_cay/caycanh/caycanh.py (sa)
kieng/cc_xuong_rong | code_ve_cay/caycanh/caycanh.py (xuong_rong)
kieng/duongxi | code_ve_cay/duongxi/duongxi.py
kieng/mai | code_ve_cay/mai/mai.py
hoaco/bui_la | code_ve_cay/hoaco/hoaco.py (mini bui_la)
hoaco/c_lau | code_ve_cay/hoaco/hoaco.py (mini c_lau)
hoaco/c_xanh | code_ve_cay/hoaco/hoaco.py (mini c_xanh)
hoaco/h_cuc_la_nho | code_ve_cay/hoaco/hoaco.py (mini h_cuc_la_nho)
hoaco/h_cuc_trang | code_ve_cay/hoaco/hoaco.py (mini h_cuc_trang)
hoaco/h_cuc_vang | code_ve_cay/hoaco/hoaco.py (mini h_cuc_vang)
hoaco/h_da_yen | code_ve_cay/hoaco/hoaco.py (mini h_da_yen)
hoaco/h_dua_can | code_ve_cay/hoaco/hoaco.py (mini h_dua_can)
hoaco/h_mai_dia | code_ve_cay/hoaco/hoaco.py (mini h_mai_dia)
hoaco/h_mong_ga | code_ve_cay/hoaco/hoaco.py (mini h_mong_ga)
hoaco/h_mong_tay | code_ve_cay/hoaco/hoaco.py (mini h_mong_tay)
hoaco/h_muoi_gio | code_ve_cay/hoaco/hoaco.py (mini h_muoi_gio)
hoaco/h_ngu_sac | code_ve_cay/hoaco/hoaco.py (mini h_ngu_sac)
hoaco/h_sao_nhai | code_ve_cay/hoaco/hoaco.py (mini h_sao_nhai)
hoaco/h_tim | code_ve_cay/hoaco/hoaco.py (mini h_tim)
hoaco/h_van_tho | code_ve_cay/hoaco/hoaco.py (mini h_van_tho)
hoaco/k_hung_que | code_ve_cay/hoaco/hoaco.py (mini k_hung_que)
hoaco/k_lan_chi | code_ve_cay/hoaco/hoaco.py (mini k_lan_chi)
hoaco/k_ot | code_ve_cay/hoaco/hoaco.py (mini k_ot)
thuysinh/beo | code_ve_cay/thuysinh/thuysinh.py
thuysinh/dien_dien | code_ve_cay/nuocnoi/nuocnoi.py
thuysinh/keo_neo | code_ve_cay/nuocnoi/nuocnoi.py
thuysinh/luc_binh | code_ve_cay/thuysinh/thuysinh.py
thuysinh/rau_muong | code_ve_cay/thuysinh/thuysinh.py
thuysinh/sung | code_ve_cay/thuysinh/thuysinh.py
thuysinh/sung_ma | code_ve_cay/nuocnoi/nuocnoi.py
caydai/bui_cay | code_ve_cay/buicay/
caydai/bui_co | code_ve_cay/co/co.py
caydai/co_lau | code_ve_cay/lau/
caydai/goc_cay | code_ve_cay/gocay/gocay.py
caydai/nhanh_kho | code_ve_cay/gocay/gocay.py

Sửa xong: chạy lệnh trong code_ve_cay/README.md, rồi _xuat/final9.py (cây) hoặc exp1.py (cây trồng/hoa) cắt ra lại đúng thư mục hình.
