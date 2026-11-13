# Code vẽ cây cối / hoa / nông sản (bản cho Godot)

Code Python gốc đã vẽ mọi hình trong godot/caytrong, caytrai, caylang, kieng, hoaco, thuysinh, caydai.
Mỗi thư mục = 1 bộ vẽ (kit). Các kit gọi lẫn nhau qua `../<tên>`, nên giữ nguyên cả thư mục `code_ve_cay/`.
Cần: `pip install pycairo numpy pillow scipy`.

## Cây 23 loại (ĐÃ chỉnh sẵn 9 px/đơn vị: RS, SS = 9, 2)
chuoi (build.py), dua, dieu, mit, saurieng, buoi, chomchom (chom.py), mangcut, dudu, cam, man, me, nhan,
thanhlong, tre, cau, caosu, dambut, duanuoc, rom, bonggiay, mai, duongxi (+ xoai, da là thư viện dùng chung).

    cd buoi && python3 buoi.py atlas OUTDIR OUTDIR/atlas.json      # OUTDIR phải có sẵn
    cd caosu && NOSH=1 python3 caosu.py atlas OUTDIR OUTDIR/atlas.json   # bản game không bóng
    cd thanhlong && CO_RS=9 python3 thanhlong.py atlas OUTDIR OUTDIR/atlas.json   # rom, duongxi cũng vậy (CO_RS)

Ra 1 sheet + bảng khung, rồi `_xuat/final9.py` cắt từng khung ra PNG + atlas.json (đã kiểm: chạy lại ra y từng điểm ảnh).
Chuối, dừa, điều, đu đủ: bảng khung game (k2) chọn tham số riêng -> `_xuat/cand.py <kit>` và `_xuat/fix2.py` tìm đúng tham số.
Màu "sâu lá" cho chuối, dừa, thanh long, tre, cau: `src/nen/sau_la.py` k=0.2 (final9.py tự làm).

## Cây trồng 39 loại + xoài: `caysen/`
    cd caysen && CO_RS=9 python3 caysen.py one <khung> DIR      # vd lua1, bap3 ... (ra d/n png + json offset)
Lưu ý: hình trong game của vài cây (lúa, nếp, xoài...) đã chỉnh màu thêm bằng pixel sau khi vẽ (trộn sáng/tối, tăng vàng hạt lúa),
nên chạy lại code ra cùng hình dáng, cùng cỡ, nhưng màu lệch chút. Ảnh chuẩn để dùng là godot/caytrong/.

## Hoa cỏ, kiểng 1 ô, thủy sinh, nước nổi, cỏ dại
- hoaco/ (19 hoa mini): `CO_RS=9 python3 hoaco.py atlas OUT OUT/a.json`
- caycanh/ (7 kiểng 1 ô), thuysinh/ + sen/ (lục bình, bèo, súng, rau muống), nuocnoi/ (điên điển, súng ma, kèo nèo),
  co/ (bụi cỏ), buicay/, lau/, gocay/ (gốc cây, nhánh khô): đều chạy với `CO_RS=9`, lệnh `atlas OUT OUT/atlas.json`.

## _xuat/
Script cắt + bảng khung lấy từ game web (G.json cây trồng, T5.json cây 5 px cũ, W.json cỏ dại), exp1-3.py, run9.sh, final9.py.
