extends "res://logic/ui_kbang.gd"
# (11-28) BẢNG XẾP HẠNG LÀNG (Qk / S4 bản web, Sổ làng › Xếp hạng) trên khung chung (ui_kbang: tab chung, khung sen, đáy chung),
#   thay hộp nổi khung tre cũ (X đỏ riêng, tab bị cắt). 5 tab: Làng đẹp, Giàu có, Cấp độ, Quán ngon, Chuyên cần.
#   So với làng bạn bè cần chơi online: bản Godot chưa có, thân hiện như web lúc chưa đăng nhập (u2empty).

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
	var y := 30.0
	var cs := 56.0
	out.append(_chip(X0 + (XW - cs) * 0.5, y, cs, cs, "now"))
	out.append(_dic(X0 + (XW - 40.0) * 0.5, y + 8.0, 40.0, CUP))
	y += cs + 14.0
	out.append(_dt(X0, y, XW, 18.0, "Cần mở game từ đường link chia sẻ", 14.0, 800, BROWN))
	y += 24.0
	for t in ["Cần đăng nhập Claude và mở game từ đường link", "được chia sẻ để so với làng bạn bè."]:
		out.append(_dt(X0, y, XW, 16.0, t, 12.0, 600, SUB))
		y += 18.0
	_kmount(sh[0], sh[1], sh[2], out, y)
