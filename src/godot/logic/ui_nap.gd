extends "res://logic/ui_kbang.gd"
# QUÀ NẠP ĐẦU (o9(0) bản web, nút Nạp đầu ở cột sự kiện): (bản 394) khung Kho + chip chung (ui_kbang.gd), không tab.
# Đầu bảng chip đỏ "Quà nạp đầu" + dòng giải thích; 2 chip to món độc quyền (Ghe hoa, Bà ba hồng sen); 4 chip nhỏ
# (sen đỏ x2, xu, rương vật liệu, bùa EXP), chạm chip hiện mô tả; nút chip xanh "Nạp ngay" (thanh toán chưa có ở bản Godot).
# Hình quà lấy từ ui/snap/nap.json (bản chụp web).

var N := {}
var IC := []   # svg hình 6 món theo thứ tự mẫu: sen, xu, rương, ghe hoa, bà ba, bùa

# BIG: [hình, tên, dòng phụ, mô tả khi chạm]; SMALL: [hình, các dòng tên, mô tả khi chạm]
const BIG := [[3, "Ghe hoa", "Đồ trang trí", "Ghe hoa: đồ trang trí độc quyền, chỉ có ở quà nạp đầu."],
	[4, "Bà ba hồng sen", "Trang phục", "Bà ba hồng sen: trang phục độc quyền, chỉ có ở quà nạp đầu."]]
const SMALL := [[0, ["Sen đỏ x2"], "Gấp đôi sen đỏ của gói nạp đầu."], [1, ["1.000 xu"], "1.000 xu."],
	[2, ["Rương", "vật liệu"], "Rương vật liệu: 5 vật liệu kho mỗi loại, 2 mỗi loại khác."], [5, ["Bùa EXP", "3 ngày"], "Bùa +50% kinh nghiệm 3 ngày, cất trong Kho."]]

func _init(ui) -> void:
	super(ui)
	N = Snap.load_snap("nap")[".lvov"][0]
	var g := _find(N, "lvgifts")
	for c in g.kids:
		IC.append(String(c.kids[0].svg))

func open() -> void:
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	return "nap"

func _build() -> void:
	sig = _sig()
	var sh := _kshell([], "", Callable())
	var out := []
	# đầu bảng
	var y := 12.0
	var mt := "Quà nạp đầu"
	var mw: float = Box.text_w(mt, 12.5, 800) + 24.0
	out.append(_onbtn(X0, y, mw, 26.0, mt, null, true))
	out.append(_dt(X0 + mw + 10.0, y - 1.0, XW - mw - 10.0, 14.0, "Nạp gói bất kỳ lần đầu", 11.0, 700, BROWN, "left"))
	out.append(_dt(X0 + mw + 10.0, y + 13.0, XW - mw - 10.0, 14.0, "nhận trọn bộ quà · trị giá gấp 10", 10.5, 600, SUB, "left"))
	# chừa đáy: nút + dòng chú thích
	var foot := 70.0
	var g := 8.0
	var top := y + 40.0
	var avail := _hb - top - foot
	var bh := avail * 0.58
	var shh := avail - bh - g
	# 2 chip to: món độc quyền
	var bw := (XW - g) * 0.5
	for i in BIG.size():
		var b: Array = BIG[i]
		var x := X0 + i * (bw + g)
		var c := _chip(x, top, bw, bh, "now")
		var ks := [_dt(x, top + 8.0, bw, 14.0, "ĐỘC QUYỀN", 10.0, 800, "rgb(176, 110, 10)")]
		var s := minf(bw - 30.0, bh - 76.0)
		ks.append(_dic(x + (bw - s) * 0.5, top + 26.0, s, IC[int(b[0])]))
		ks.append(_dt(x, top + bh - 42.0, bw, 18.0, String(b[1]), 13.5, 800, BROWN))
		ks.append(_dt(x, top + bh - 23.0, bw, 14.0, String(b[2]), 10.5, 600, SUB))
		c.kids = ks
		c.act = _dsay.bind(String(b[3]))
		out.append(c)
	# 4 chip nhỏ
	var sy := top + bh + g
	var sw := (XW - g * 3.0) / 4.0
	for i in SMALL.size():
		var m: Array = SMALL[i]
		var x := X0 + i * (sw + g)
		var c := _chip(x, sy, sw, shh, "fut")
		var nl: Array = m[1]
		var th := nl.size() * 14.0
		var s := minf(sw - 14.0, shh - th - 22.0)
		var by := sy + (shh - (s + 8.0 + th)) * 0.5   # hình + tên đặt giữa chip
		var ks := [_dic(x + (sw - s) * 0.5, by, s, IC[int(m[0])])]
		for li in nl.size():
			ks.append(_dt(x + 2.0, by + s + 8.0 + li * 14.0, sw - 4.0, 14.0, String(nl[li]), 10.5, 800, BROWN))
		c.kids = ks
		c.act = _dsay.bind(String(m[2]))
		out.append(c)
	# nút + chú thích
	var fy := _hb - foot + 10.0
	out.append(_onbtn(X0 + (XW - 220.0) * 0.5, fy, 220.0, 32.0, "Nạp ngay từ 20.000đ", U.say.bind(U.SOON)))
	out.append(_dt(X0, fy + 38.0, XW, 14.0, "Chỉ một lần cho mỗi tài khoản", 10.5, 600, SUB))
	_kmount(sh[0], sh[1], sh[2], out, _hb)
