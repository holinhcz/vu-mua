extends "res://logic/ui_kbang.gd"
# (11-28) BẢNG XẾP HẠNG LÀNG (Qk / S4 bản web, Sổ làng › Xếp hạng) trên khung chung (ui_kbang: tab chung, khung sen, đáy chung),
#   thay hộp nổi khung tre cũ (X đỏ riêng, tab bị cắt). 5 tab: Làng đẹp, Giàu có, Cấp độ, Quán ngon, Chuyên cần.
#   (11-28) Thân: thẻ Làng mình (chỉ số tab đang xem) + cách lên hạng + mục Làng bạn bè (chưa chơi online: lời nhắc mở link bạn gửi).

var cat := "dep"            # yl.cat
const CATS := [["dep", "Làng đẹp"], ["xu", "Giàu có"], ["lv", "Cấp độ"], ["sao", "Quán"], ["sk", "Siêng"]]   # 5 tab vừa trước dây tua
const CUP := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 40 40\"><path d=\"M12 7h16v8a8 8 0 0 1-16 0z\" fill=\"rgb(244,184,44)\" stroke=\"rgb(150,96,14)\" stroke-width=\"1.6\"/><path d=\"M12 10H7.5a4.5 4.5 0 0 0 4.8 6.6M28 10h4.5a4.5 4.5 0 0 1-4.8 6.6\" fill=\"none\" stroke=\"rgb(150,96,14)\" stroke-width=\"1.8\"/><rect x=\"18\" y=\"22\" width=\"4\" height=\"6\" fill=\"rgb(214,150,30)\"/><rect x=\"12.5\" y=\"28\" width=\"15\" height=\"5\" rx=\"1.5\" fill=\"rgb(176,110,30)\" stroke=\"rgb(120,74,14)\" stroke-width=\"1.2\"/><path d=\"M15.5 9.5v5\" stroke=\"rgb(255,238,170)\" stroke-width=\"1.8\" stroke-linecap=\"round\"/></svg>"

func open() -> void:   # Qk
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	return cat

func _cat_go(k: String) -> void:   # data-rkc
	cat = k
	scroll = 0.0
	_build()

func _build() -> void:
	sig = _sig()
	var L := []
	for c in CATS:
		L.append([c[0], c[1], false])
	var sh := _kshell(L, cat, _cat_go)
	var out := []
	var y := 0.0
	# (11-28) thẻ làng mình: chỉ số của tab đang xem (luôn có, bảng không trống trơn)
	var V: Array = _val()
	var ch := 64.0
	out.append(_chip(X0, y, XW, ch, "now"))
	out.append(_dic(X0 + 12.0, y + 12.0, 40.0, CUP))
	out.append(_dt(X0 + 62.0, y + 13.0, 150.0, 20.0, "Làng mình", 14.0, 800, BROWN, "left"))
	out.append(_dt(X0 + 62.0, y + 33.0, 150.0, 16.0, String(V[1]), 10.5, 600, SUB, "left"))
	out.append(_dt(X0 + XW - 132.0, y + 18.0, 120.0, 26.0, String(V[0]), 17.0, 800, "rgb(150, 90, 10)", "right"))
	y += ch + GG
	# cách lên hạng
	out.append_array(_hd(y, "Cách lên hạng"))
	y += 18.0 + GG
	for t in TIP[cat]:
		var P := _para(X0 + 26.0, y + 8.0, XW - 36.0, String(t), 10.5, 600, BROWN)
		var bh := float(P[1]) + 16.0
		out.append(_chip(X0, y, XW, bh, "fut"))
		out.append(_dbx(X0 + 12.0, y + bh * 0.5 - 3.0, 6.0, 6.0, GOLD, 3.0))
		out.append_array(P[0])
		y += bh + 6.0
	y += GG - 6.0
	# làng bạn bè: chưa chơi online
	out.append_array(_hd(y, "Làng bạn bè"))
	y += 18.0 + GG
	var P2 := _para(X0 + 12.0, y + 10.0, XW - 24.0, "Mở game từ đường link bạn bè gửi để so làng mình với làng bạn bè.", 10.5, 600, SUB)
	var bh2 := float(P2[1]) + 20.0
	out.append(_chip(X0, y, XW, bh2, "info"))
	out.append_array(P2[0])
	y += bh2 + GG
	_kmount(sh[0], sh[1], sh[2], out, y)

const TIP := {
	"dep": ["Xây nhà, đặt đồ trang trí quanh làng.", "Trồng cây, làm vườn hoa cho làng xanh."],
	"xu": ["Giao đơn hàng, bán hàng ở Chợ nổi.", "Mở quán, cho khách ghé đều."],
	"lv": ["Thu hoạch, giao đơn, làm nhiệm vụ để lên cấp."],
	"sao": ["Giao món đúng hẹn cho khách quán cơm.", "Nâng sao căn quán để khách chờ lâu hơn."],
	"sk": ["Vào làng mỗi ngày, làm việc hôm nay để giữ chuỗi ngày."],
}

func _val() -> Array:   # [số hiện bên phải, dòng phụ] theo tab
	match cat:
		"dep":
			return [str(U.F.lang.beauty()) + " điểm", "Điểm làng đẹp"]
		"xu":
			return [G.fmt_n(int(G.g.get("coins", 0))) + " xu", "Xu đang có"]
		"lv":
			return ["Cấp " + str(G.lv()), "Cấp độ làng"]
		"sao":
			var WQ = G.w_all.WQ
			if not WQ.built("quancom"):
				return ["Chưa có", "Xây Quán cơm để lên hạng"]
			return [str(snappedf(float(WQ.st("quancom").sao), 0.1)) + " ★", "Sao danh tiếng Quán cơm"]
	return [str(G.nv.streak_now()) + " ngày", "Chuỗi ngày liên tục"]

