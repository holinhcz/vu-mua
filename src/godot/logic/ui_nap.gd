extends "res://logic/ui_hx.gd"
# QUÀ NẠP ĐẦU (o9(0) bản web, nút Nạp đầu ở cột sự kiện): khung tre .ngfirst, 6 thẻ quà trong .lvgifts cuộn dọc,
# nút "Nạp ngay" (cửa hàng sen đỏ / thanh toán chưa có ở bản Godot) và dòng "Chỉ một lần cho mỗi tài khoản".
# Mẫu: ui/snap/nap.json (chụp nguyên bảng bản web).

var N := {}

func _init(ui) -> void:
	super(ui)
	N = Snap.load_snap("nap")[".lvov"][0]

func open() -> void:
	help = ["Quà nạp đầu", "Nạp lần đầu gói bất kỳ, nhận ngay cả rương quà trị giá gấp 10 lần. Chỉ một lần cho mỗi tài khoản."]
	on = true
	scroll = 0.0
	_build()

func _build() -> void:
	var n := _cl(N)
	var fr := _find(n, "ngfirst")
	var vt := _find(fr, "lvgifts")
	var kids: Array = vt.kids
	var bot := 0.0
	for k in kids:
		bot = maxf(bot, float(k.r[1]) + float(k.r[3]))
	_tre_box(fr)
	_find(fr, "lvbtn").act = U.say.bind(U.SOON)
	_mount(_ovl(n), vt, kids, float(vt.r[1]), bot - float(vt.r[1]) + 6.0)
	_wire_ov(".ngfirst")
