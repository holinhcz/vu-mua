# Code 3D dựng công trình (bản đang xài, chép từ src/ ngày 12-11)

Mỗi nhà là 1 file Python dựng mô hình 3D (từng lá, ống tre, cột tràm...) rồi render ra ảnh. Giữ nguyên cấu trúc thư mục vì các file import nhau qua ../<thư mục>.
Bản sao lưu cũ (_v1, _pre_...) và file patch_*.py (chỉ để nhét vô game web) không chép.

Cài: `pip install numpy pillow numba scipy`
Chạy: `python3 <file> prev OUT.png [kiểu] [n]` = xem trước 1 khung (n = đêm); `python3 <file> atlas OUTDIR atlas.json` = xuất đủ khung. Muốn nét hơn: biến PXU (mặc định 9 điểm/ô; chuồng có CG_PXU=18).
Thư viện chung: pxr/pxr_3d.py (máy render 3D), kho/kho3d.py (vật liệu, mái, hình khối), dinh/dinh3d.py, bagian/bagian3d.py, sap/sap3d.py, benghe/benghe3d.py, den/den.py (đèn ban đêm), choi/choi.py.

thư mục ảnh godot/congtrinh | file code
---|---
hutnho | choi/choi3d.py
hut | nhatranh/nha3d.py
pavilion | choimat/pav3d.py
choi | choicanh/canh3d.py
kho | kho/kho3d.py
sap | sap/sap3d.py
quancom | quancom/quancom3d.py
taphoa | taphoa/taphoa3d.py
cafe | cafe/cafe3d.py
bagian | bagian/bagian3d.py
dinh | dinh/dinh3d.py (cờ: lệnh flag)
gate | cong/cong3d.py
truong | truong/truong3d.py
chua | chua/chua3d.py (cờ: `chua3d.py flag DIR`)
tramyt | tramyt/tramyt3d.py
shrine | mieu/mieu3d.py
logach | logach/logach3d.py
well | gieng/gieng3d.py
ben | benghe/benghe3d.py
caukhi | caukhi/caukhi3d.py
causong, bridge | cau/cau3d.py
chuong_ga/heo/bo/cuu/de | chuongga/chuong<ga|heo|bo|cuu|de>3d.py
