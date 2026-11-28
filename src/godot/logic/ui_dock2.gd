extends "res://logic/ui_kbang.gd"
# (11-28) MENU trên khung chung (ui_kbang: khung sen, đáy chung), thay bảng chụp web cũ (snap dock) bị lệch khung.
#   3 mục (tiêu đề mục chung _hd): Làm ăn · Làng xóm · Giải trí; mỗi mục lưới 4 cột ô chip (hình + tên), cách ô 6, mục cách 10.
#   Hình ô lấy từ ui/snap/dock.json (svg của từng ô), việc của ô: U (giống bảng cũ).

const MUC := [
	["Làm ăn", "kh:gio_lb", ["Kho", "Đơn hàng", "Xây dựng", "Nghề", "Lờ lọp"]],
	["Làng xóm", "kh:tra_tac", ["Hợp tác xã", "Sổ làng", "Bản đồ", "Hệ Thống"]],
	["Giải trí", "img:den_long", ["Câu cá", "Cờ gánh", "Ô ăn quan", "Xếp trái", "Đua gà", "Cờ caro", "Tìm số"]]]
const TH := 62.0      # cao ô
const IC := 28.0      # hình ô
const ORB := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 40 40\"><defs><radialGradient id=\"o\" cx=\"0.36\" cy=\"0.32\" r=\"0.7\"><stop offset=\"0\" stop-color=\"rgb(235,248,255)\"/><stop offset=\"0.45\" stop-color=\"rgb(90,170,250)\"/><stop offset=\"1\" stop-color=\"rgb(20,80,200)\"/></radialGradient></defs><circle cx=\"20\" cy=\"20\" r=\"17\" fill=\"url(#o)\"/><ellipse cx=\"14\" cy=\"12\" rx=\"5\" ry=\"3\" fill=\"rgb(255,255,255)\" fill-opacity=\"0.9\"/></svg>"

var _svg := {}   # tên ô -> svg

func _init(ui) -> void:
	super(ui)
	var d: Dictionary = Snap.load_snap("dock")
	for n in d.get("nav.dock", []):
		_grab(n)

func _grab(n: Dictionary) -> void:   # tìm từng nút ô: chữ "lb" + svg trong nút
	if String(n.get("tag", "")) == "button":
		var lb := ""
		var sv := ""
		for k in n.get("kids", []):
			if String(k.get("cls", "")) == "lb":
				lb = String(k.get("text", ""))
			if k.has("svg"):
				sv = String(k.svg)
		if lb != "":
			_svg[lb] = sv
		return
	for k in n.get("kids", []):
		if k is Dictionary:
			_grab(k)

func open() -> void:
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	return "dock"

func _build() -> void:
	sig = _sig()
	var sh := _kshell([], "", func(_k): pass)
	var out := []
	var y := 4.0
	var cw := (XW - 3.0 * 6.0) / 4.0
	for m in MUC:
		out.append_array(_hd(y + 5.0, String(m[0]), String(m[1])))
		y += 26.0 + 6.0
		var L: Array = m[2]
		for i in L.size():
			var x := X0 + (i % 4) * (cw + 6.0)
			var ty := y + (i / 4) * (TH + 6.0)
			out.append(_tile(x, ty, cw, String(L[i])))
		y += ceili(L.size() / 4.0) * (TH + 6.0) - 6.0 + GG
	_kmount(sh[0], sh[1], sh[2], out, y)

func _tile(x: float, y: float, w: float, t: String) -> Dictionary:   # ô chức năng: chip bấm được (viền vàng 3 lớp), hình trên, tên dưới
	var c := _chip(x, y, w, TH, "fut", true)
	var sv: String = ORB if t == "Hệ Thống" else String(_svg.get(t, ""))
	c.kids = []
	if sv != "":
		c.kids.append(_dic(x + (w - IC) * 0.5, y + 8.0, IC, sv))
	c.kids.append(_dt(x, y + 40.0, w, 16.0, _fitw(t, 12.0, 700, w - 4.0), 12.0, 700, BROWN))
	c.act = func(): _go(t)
	return c

func _go(t: String) -> void:
	U.dock_open(false)
	match t:
		"Kho": U.kho_open()
		"Đơn hàng": U.ord_open()
		"Xây dựng": U.bdp.open_shop()
		"Nghề": U.ng_open()
		"Lờ lọp": U.lop_open()
		"Sổ làng": U.sl_open()
		"Câu cá": U.ccp.open()
		"Cờ gánh": U.cgp.open()
		"Ô ăn quan": U.oqp.open()
		"Xếp trái": U.xtp.open()
		"Cờ caro": U.carop.open()
		"Tìm số": U.tsop.open()
		"Đua gà": U.dgp.open()
		"Hệ Thống": U.sys_open()
		_: U.say(U.SOON)
