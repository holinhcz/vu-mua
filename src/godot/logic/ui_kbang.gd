extends "res://logic/ui_bang.gd"
# BẢNG KHUNG KHO + CHIP (bản 394): bảng nổi dựng trên khung chung của Kho (khung Sổ làng sl.json: #pov .pwin, nút × #pClose,
# hàng tab tre .bk2tabs tùy có), nội dung xếp tay bằng ô chip chung (Snap.chip_look). Điểm danh (ui_dd.gd), Nạp đầu (ui_nap.gd).
# Khối: _dt chữ, _dbx hộp, _chip ô chip theo trạng thái, _onbtn nút chip "on" của Kho (red: tông đỏ), _dick hình quà, _dtick dấu ✓.
# Tọa độ khối: x tuyệt đối (X0..X0+XW), y tính từ đỉnh thân; _kshell dựng khung, _kmount gắn khối.

var D := {}    # dd.json: mẫu kiểu chữ, hình quà
var SB := {}   # #pov khung Sổ làng (khung chung Kho)
var ST := {}   # sl_tab.json: chấm đỏ tab

func _init(ui) -> void:
	super(ui)
	D = Snap.load_snap("dd")
	SB = Snap.load_snap("sl")["#pov"][0]
	ST = Snap.load_snap("sl_tab")

func step(dt: float) -> void:   # dựng lại khi trạng thái đổi
	if not on:
		return
	_fx_step(dt)
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if has_method("_sig") and call("_sig") != sig:
		_build()

# khung Kho: L = [[khóa, chữ, chấm?]] hàng tab (rỗng = không tab, thân lên đỉnh thẻ). Trả [khung, vùng thân, đỉnh thân]; _hb = cao thân
func _kshell(L: Array, cur: String, go: Callable, th := 0.0) -> Array:   # th > 0: (bản 496) chừa dải đầu cao th trên hàng tab (đỉnh dải = phần tử thứ 4 trả về)
	var n := _cl(SB)
	var card := _find(n, "khcard")
	var tabs := _find(n, "bk2tabs")
	var vt := _find(n, "bk2v")
	var th0 := float(_find(n, "bk2top").r[1])
	var ty0 := th0 + th   # bỏ đầu bảng danh hiệu của Sổ làng
	card.kids = card.kids.filter(func(k): return not String(k.get("cls", "")).contains("bk2top") and (L.size() or not String(k.get("cls", "")).contains("bk2tabs")))
	var vy := ty0
	if L.size():
		_mv(tabs, float(tabs.r[0]), ty0)
		vy = ty0 + float(tabs.r[3]) + GG   # (11-27) tab -> thân: khoảng cách phần chung (GG)
		var bd := _cl(ST.ttdot)
		bd.text = ""   # (bản 489) chấm đỏ trơn, không ghi số
		_seg_tabs(tabs, L, cur, go, bd)
	var vb := float(vt.r[1]) + float(vt.r[3])
	vt.r = [vt.r[0], vy, vt.r[2], vb - vy]
	if Sen.ON:   # (11-26) khung sen: đáy dùng được chung mọi bảng, dừng trên chóp đáy + hoa sen góc phải (như tab Thành tựu)
		vt.r = [vt.r[0], vt.r[1], vt.r[2], float(vt.r[3]) - SEN_DAY]
	_hb = float(vt.r[3])
	return [n, vt, vy, th0]

var fit := false   # (bản 492) bảng ngắn (Thư nhà): khung co lại vừa nội dung, đứng giữa màn

func _kfit(n: Dictionary, cut: float, d: float) -> void:   # co khung: khối nằm dưới vạch cut dời lên d, khối vắt qua vạch thì thấp bớt d
	if n.has("r") and not String(n.get("cls", "")).begins_with("pbk") and String(n.get("cls", "")) != "pov":
		var r: Array = n.r
		if float(r[1]) >= cut:
			r[1] = float(r[1]) - d
			if n.has("tr"):
				n.tr[1] = float(n.tr[1]) - d
		elif float(r[1]) + float(r[3]) > cut:
			r[3] = float(r[3]) - d
	for k in n.get("kids", []):
		if k is Dictionary:
			_kfit(k, cut, d)

func _kshift(n: Dictionary, dy: float) -> void:   # dời cả khung (trừ nền tối) xuống dy
	for k in n.get("kids", []):
		if k is Dictionary and not String(k.get("cls", "")).begins_with("pbk"):
			Snap._move(k, Vector2(0, dy))

# (11-27) KHỐI CỐ ĐỊNH (không cuộn) ở đầu / đáy thân: vùng cuộn thu lại, khối gắn vào khung (Kho: đầu sức chứa, dải chi tiết, nút Bán hết)
# blocks: tọa độ y tính từ đỉnh dải (0..h); trả đỉnh dải (tọa độ khung)
func _kfix(n: Dictionary, vt: Dictionary, blocks: Array, h: float, bottom: bool) -> float:
	var card := _find(n, "khcard")
	var y0: float
	if bottom:
		y0 = float(vt.r[1]) + float(vt.r[3]) - h
		vt.r = [vt.r[0], vt.r[1], vt.r[2], float(vt.r[3]) - h - GG]
	else:
		y0 = float(vt.r[1])
		vt.r = [vt.r[0], float(vt.r[1]) + h + GG, vt.r[2], float(vt.r[3]) - h - GG]
	_hb = float(vt.r[3])
	for b in blocks:
		Snap._move(b, Vector2(0, y0))
		card.kids.append(b)
	return y0

func _kmount(n: Dictionary, vt: Dictionary, vy: float, kids: Array, ch: float) -> void:
	if fit and ch + 8.0 < _hb:
		var d := _hb - ch
		_kfit(n, vy + ch, d)
		_kshift(n, d * 0.5)
		vy += d * 0.5
		_hb = ch
	for k in kids:
		Snap._move(k, Vector2(0, vy))
	_mount(n, vt, kids, vy, ch if ch > _hb + 8.0 else minf(ch, _hb), 0.0)   # lố vài đơn vị thì không cho cuộn; dài hẳn thì cuộn
	U._layout()

func _hd(y: float, t: String, ic := "", rw := 0.0, mid := "", mc := "") -> Array:   # (11-26) TIÊU ĐỀ MỤC CHUNG mọi bảng: [icon] chữ đậm + chấm vàng + gạch vàng tới mép phải
	return _hdx(X0, y, XW - rw, t, ic, mid, mc)

# x, w: bề ngang mục; ic: "img:<ảnh ui/img/troi>" / "kh:<món>" / "d:<hình quà>" / "" không icon; mid: chữ phụ nhỏ ngay sau tên (trước gạch)
func _hdx(x: float, y: float, w: float, t: String, ic := "", mid := "", mc := "") -> Array:
	var L := []
	var tx := x + 2.0
	if ic != "":
		L.append(_hic(x, y - 5.0, 25.0, ic))
		tx = x + 29.0
	var x1 := x + w
	var tw: float = minf(Box.text_w(t, 13.0, 800) + 6.0, x1 - tx - 14.0)
	L.append(_dt(tx, y - 1.0, tw + 4.0, 18.0, _fitw(t, 13.0, 800, tw), 13.0, 800, BROWN, "left"))
	var lx := tx + tw
	if mid != "":
		var mw: float = minf(Box.text_w(mid, 10.5, 600) + 4.0, x1 - lx - 2.0)
		L.append(_dt(lx + 2.0, y + 1.0, mw, 14.0, _fitw(mid, 10.5, 600, mw - 4.0), 10.5, 600, mc if mc != "" else SUB, "left"))
		lx += mw + 4.0
	lx += 6.0
	if lx + 14.0 < x1:
		L.append(_dbx(lx, y + 5.5, 5.0, 5.0, "rgb(252, 246, 230)", 3.0, "1px solid rgb(200, 158, 80)"))
		L.append(_dbx(lx + 5.0, y + 7.5, x1 - lx - 5.0, 1.0, "rgb(214, 176, 104)", 0.0))
	return L

var _hics := {}
const LUA_SVG := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 32 32\"><path d=\"M16 2.5c1.2 4.6 7.6 8 9.4 14.2 1.7 6-2.6 12.6-9.4 12.6S4.9 23.6 6.4 17.6c.9-3.6 3.4-5.3 4.4-8 .6 2.5 1.6 3.8 3 4.4-.5-4.6.6-8.4 2.2-11.5z\" fill=\"rgb(232,96,32)\" stroke=\"rgb(176,52,20)\" stroke-width=\"1.2\" stroke-linejoin=\"round\"/><path d=\"M16.2 13.5c.9 3 4.8 4.8 5 8.6.2 3.4-2.3 5.6-5.2 5.6s-5.4-2.1-5-5.3c.3-2.4 2-3.4 2.6-5.2.5 1.3 1.1 1.9 2 2.2-.4-2.1-.1-4.1.6-5.9z\" fill=\"rgb(255,206,72)\"/></svg>"
func _hic(x: float, y: float, s: float, ic: String) -> Dictionary:   # icon tiêu đề mục
	if ic == "lua":   # ngọn lửa (chuỗi ngày): cùng màu chấm lửa
		return _dic(x, y, s, LUA_SVG)
	var k := ic.substr(ic.find(":") + 1)
	if ic.begins_with("d:"):
		return _dick(x + s * 0.5, y + s * 0.5, s * 0.86, k)
	if ic.begins_with("kh:"):
		var n := _dbx(x, y, s, s, "rgba(0, 0, 0, 0)", 0.0)
		n.ic = k
		return n
	if not _hics.has(k):
		_hics[k] = Css.img_svg("res://ui/img/troi/" + k + ".webp")
	return _dic(x, y, s, String(_hics[k]))

func _fitw(s: String, fs: float, fw: int, w: float) -> String:   # cắt chữ thêm "…" cho vừa bề ngang
	if Box.text_w(s, fs, fw) <= w:
		return s
	while s.length() > 1 and Box.text_w(s + "…", fs, fw) > w:
		s = s.substr(0, s.length() - 1)
	return s.strip_edges() + "…"

# ------------------------------------------------------------------ khối dựng tay (bản 386): tọa độ cuối (khung Kho), y tính từ đỉnh thân
const SEN_DAY := Sen.DAY   # đáy chung khung sen (ui/sen.gd)
const X0 := 16.5      # mép trái nội dung (như thẻ trong Kho / Sổ làng)
const XW := 305.0     # rộng nội dung
const BROWN := "rgb(74, 52, 20)"
const SUB := "rgb(128, 98, 58)"
const GOLD := "rgb(222, 160, 40)"
const GG := 10.0   # khoảng cách đều giữa tiêu đề phần và khối, giữa các khối
const GREEN := "rgb(46, 150, 80)"
var _hb := 455.0      # cao thân (tính ở _build theo khung Kho)

func _dz() -> float:
	return float(D.cal.kids[0].get("z", 0.75))

func _cpx(v: float) -> String:   # đơn vị số đo -> px css của mẫu (nhân z lúc vẽ)
	return str(snappedf(v / _dz(), 0.01)) + "px"

func _dt(x: float, y: float, w: float, h: float, s: String, fs := 11.0, fw := 700, col := BROWN, al := "center") -> Dictionary:
	var n: Dictionary = D.cal.kids[0].duplicate(false)   # (bản 475) chép nông
	n.erase("tr")
	n.kids = []
	n.r = [x, y, w, h]
	n.text = s
	n.css = n.css.duplicate()
	n.css["font-size"] = _cpx(fs)
	n.css["font-weight"] = str(fw)
	n.css["color"] = col
	n.css["text-align"] = al
	n.css["line-height"] = _cpx(h)
	n.css["white-space"] = "nowrap"
	for k in ["padding-top", "padding-bottom", "padding-left", "padding-right"]:
		n.css[k] = "0px"
	return n

func _dcard(x: float, y: float, w: float, h: float) -> Dictionary:   # thẻ kem như các thẻ trong Kho
	var n := _cl(D.ddsum)
	n.erase("text")
	n.erase("tr")
	n.kids = []
	n.r = [x, y, w, h]
	return n

func _dbx(x: float, y: float, w: float, h: float, bg: String, rad := 8.0, bd := "", sh := "none") -> Dictionary:
	var n: Dictionary = D.cell.fut.duplicate(false)   # (bản 475) chép nông, bỏ con: không chép sâu cả cây mẫu
	n.kids = []
	n.r = [x, y, w, h]
	n.css = n.css.duplicate()
	n.css["background-color"] = bg
	n.css["background-image"] = "none"
	n.css["opacity"] = "1"   # mẫu ô .ddc.fut của web mờ sẵn: bỏ
	n.css["border-radius"] = _cpx(rad)
	n.css["box-shadow"] = sh
	for sd in ["top", "right", "bottom", "left"]:
		n.css["border-" + sd] = bd if bd != "" else "0px none rgb(0, 0, 0)"
	return n

# ô chip nổi như thẻ Sổ làng / chip Kho (viền trong 1px + vệt sáng + quầng trong + bóng): nền VÀ viền cùng tông theo trạng thái
const CHIPK := {   # [gradient trên, giữa, dưới, viền]
	"thue": ["rgb(190, 228, 160)", "rgb(202, 234, 176)", "rgb(216, 240, 194)", "rgb(60, 140, 40)"],   # đang chọn: xanh đậm hơn nền nhóm
	"j_ruong": ["rgb(232, 246, 220)", "rgb(238, 249, 228)", "rgb(244, 252, 238)", "rgb(150, 196, 120)"],   # (bản 439) nhóm việc thuê: nền nhạt
	"j_vuon": ["rgb(255, 240, 214)", "rgb(255, 244, 224)", "rgb(255, 249, 236)", "rgb(222, 176, 110)"],
	"j_chan": ["rgb(252, 230, 214)", "rgb(253, 236, 224)", "rgb(254, 243, 236)", "rgb(214, 156, 116)"],
	"j_xuong": ["rgb(238, 230, 248)", "rgb(242, 236, 250)", "rgb(247, 243, 252)", "rgb(170, 146, 206)"],
	"t_hien": ["rgb(250, 214, 226)", "rgb(252, 224, 234)", "rgb(254, 236, 242)", "rgb(206, 110, 140)"],
	"t_kho": ["rgb(214, 222, 236)", "rgb(224, 230, 242)", "rgb(236, 240, 248)", "rgb(100, 120, 160)"],
	"t_vui": ["rgb(255, 222, 170)", "rgb(255, 230, 190)", "rgb(255, 240, 214)", "rgb(214, 140, 40)"],
	"t_khac": ["rgb(228, 214, 244)", "rgb(234, 222, 248)", "rgb(242, 234, 252)", "rgb(138, 104, 186)"],
	"s_ruong": ["rgb(222, 242, 204)", "rgb(230, 246, 216)", "rgb(240, 250, 230)", "rgb(110, 170, 70)"],   # (bản 442) màu khối sở trường theo nghề
	"s_vuon": ["rgb(255, 232, 196)", "rgb(255, 238, 210)", "rgb(255, 246, 228)", "rgb(220, 150, 50)"],
	"s_chan": ["rgb(250, 222, 200)", "rgb(252, 230, 212)", "rgb(254, 240, 228)", "rgb(200, 130, 80)"],
	"s_xuong": ["rgb(232, 220, 246)", "rgb(238, 228, 250)", "rgb(244, 238, 252)", "rgb(138, 104, 186)"],
	"fut": ["rgb(255, 250, 238)", "rgb(253, 246, 230)", "rgb(250, 240, 220)", "rgb(216, 180, 110)"],   # (11-26) bộ sen: kem, viền vàng
	"sel": ["rgb(214, 240, 200)", "rgb(224, 244, 212)", "rgb(234, 248, 226)", "rgb(52, 140, 52)"],   # (11-27) đang chọn / đủ món
	"got": ["rgb(196, 232, 184)", "rgb(208, 238, 198)", "rgb(222, 244, 214)", "rgb(76, 160, 70)"],
	"now": ["rgb(255, 226, 140)", "rgb(255, 236, 170)", "rgb(255, 245, 205)", "rgb(214, 150, 20)"],
	"miss": ["rgb(200, 196, 186)", "rgb(208, 204, 195)", "rgb(218, 215, 207)", "rgb(145, 137, 123)"],
	"tre": ["rgb(226, 196, 128)", "rgb(233, 206, 144)", "rgb(240, 218, 165)", "rgb(150, 108, 40)"],   # dải thứ: nâu vàng
	"sen": ["rgb(250, 210, 210)", "rgb(252, 222, 222)", "rgb(254, 234, 234)", "rgb(214, 120, 128)"],
	"fire_l": ["rgb(255, 214, 178)", "rgb(255, 224, 194)", "rgb(255, 234, 212)", "rgb(226, 120, 50)", "rgb(232, 112, 40)"],   # (bản 460) cam lửa: Sổ nhiệm vụ (Chuỗi, quà mốc cuối), nghề chính
	"info": ["rgb(214, 232, 248)", "rgb(224, 238, 250)", "rgb(236, 244, 252)", "rgb(96, 146, 196)"],   # (bản 434) chip thông tin, thời gian (xanh dương nhạt)
}
func _ck(kind: String) -> Array:   # màu chip theo loại; bảng con thêm loại riêng thì ghi đè hàm này
	return CHIPK[kind]

# (11-27) VIỀN 3 TẦNG (khung chung):
#   khối nội dung (thẻ, ô, hàng thông tin): _chip mặc định = viền mảnh 1 lớp cùng tông nền;
#   bấm được / đang chọn (tab, chip lọc, nút): _chip(..., true), _onbtn có việc bấm = gờ vàng 3 lớp (Snap.SEN_VIEN);
#   bên trong khối (dòng món, nhãn số, ô hình): _dbx nền phẳng, không viền.
const VIEN_MONG := "rgba(255, 255, 255, 0.55) 0px 1px 0px 0px inset"   # vệt sáng trên (chip mảnh)
func _chip(x: float, y: float, w: float, h: float, kind: String, bold := false) -> Dictionary:
	# góc bo, viền trong, vệt sáng, bóng: lấy nguyên chip chung (Snap.chip_look); chỉ thay nền + màu viền theo trạng thái
	var C: Array = _ck(kind)
	var n := _dbx(x, y, w, h, "rgba(0, 0, 0, 0)")
	n.cls = "ddchip"
	var ck := ",".join(PackedStringArray(C)) + ("|now" if kind == "now" else "") + ("|b" if bold else "")
	if _CKC.has(ck):   # (bản 475) nhớ kiểu chip theo màu: bớt xử lý chuỗi khi dựng bảng nhiều chip (Làm thuê 40 nhà)
		n.css = (_CKC[ck] as Dictionary).duplicate()
		return n
	Snap.chip_look(n, "ddchip", true)
	n.css["background-color"] = String(C[1])
	n.css["background-image"] = "linear-gradient(" + String(C[0]) + " 0%, " + String(C[1]) + " 50%, " + String(C[2]) + " 100%)"
	var sh := String(n.css["box-shadow"])
	# (11-26) bộ sen: mọi chip viền vàng kép như ảnh mẫu: vàng đậm 2px, chỉ kem, chỉ vàng nhạt bên trong
	if kind == "sel":   # đang chọn / đủ để làm (thẻ món đang chọn, đơn đủ món): viền xanh đậm 2 lớp, nổi hẳn
		n.css["box-shadow"] = "rgb(52, 140, 52) 0px 0px 0px 1.6px inset, rgba(255, 255, 255, 0.7) 0px 0px 0px 2.6px inset, " + VIEN_MONG
		n.css["border-radius"] = _cpx(12.0)
		_CKC[ck] = n.css.duplicate()
		return n
	if not bold:   # khối nội dung: viền mảnh 1 lớp, sậm hơn tông nền (không chìm vào giấy), vệt sáng trên
		var bc := Css.color(String(C[3])).darkened(0.18)
		n.css["box-shadow"] = "rgb(%d, %d, %d) 0px 0px 0px 1.2px inset, " % [bc.r8, bc.g8, bc.b8] + VIEN_MONG
		n.css["border-radius"] = _cpx(12.0)
		_CKC[ck] = n.css.duplicate()
		return n
	sh = SEN_BD + sh.substr(sh.find(")") + 1)
	# viền vàng kim như ảnh mẫu: nét nâu vàng ngoài 1px, dải vàng 3px sáng phía trên, sậm phía dưới
	sh = sh.replace("0px 0px 0px 1px inset", "0px 0px 0px 0.8px inset, rgb(250, 214, 110) 0px 0px 0px 1.6px inset, rgb(236, 184, 70) 0px 0px 0px 2.2px inset, rgba(150, 100, 30, 0.35) 0px 0px 0px 2.7px inset")   # (11-26) mảnh lại   # dải vàng đều 4 cạnh
	var L := sh.split(") 0px 1px 2px 0px")   # bỏ lớp bóng đổ mờ dưới chip (lớp cuối, không inset)
	if L.size() > 1:
		sh = L[0].substr(0, L[0].rfind(", "))
	n.css["box-shadow"] = sh
	n.css["border-radius"] = _cpx(12.0)   # bo tròn như ảnh mẫu
	_CKC[ck] = n.css.duplicate()
	return n

const SEN_BD := "rgb(170, 112, 36)"   # viền vàng chip (bộ sen)
static var _CKC := {}   # kiểu chip đã tính, theo bộ màu
static var _ON := {}
func _onbtn(x: float, y: float, w: float, h: float, t: String, cb, red := false) -> Dictionary:   # nút = chip "on" (xanh) của Kho; red: cùng dáng, tông đỏ
	if _ON.is_empty():
		var ch: Dictionary = Snap.find(Snap.load_snap("kho")["#pov"][0], "khchips")
		for k in ch.kids:
			if String(k.cls).split(" ").has("on"):
				_ON = k.css
				break
	var n := _dbx(x, y, w, h, "rgba(0, 0, 0, 0)", 10.0)
	for key in ["background-color", "background-image", "border-radius", "box-shadow"]:
		n.css[key] = _ON.get(key, n.css.get(key))
	# (11-26) bộ sen: nút xanh / đỏ gờ vàng như nút Bán hết, chip lọc đang chọn
	n.css["background-image"] = Snap.SEN_DO if red else Snap.SEN_XANH
	n.css["box-shadow"] = Snap.SEN_VIEN if cb is Callable else NHAN_VIEN   # nút bấm: gờ vàng; nhãn (không bấm): viền mảnh
	n.kids = [_dt(x, y, w, h, t, 12.5, 800, "rgb(255, 255, 255)")]
	if cb is Callable:
		n.act = cb
	return n

# (11-26) chip mùa: xuân hồng đào, hạ cam nắng, thu xanh nước, khô vàng (Trời đất, Điểm danh)
const MUA_C := ["linear-gradient(rgb(242, 138, 168) 0%, rgb(230, 108, 146) 50%, rgb(217, 85, 126) 100%)",
	"linear-gradient(rgb(247, 181, 71) 0%, rgb(236, 158, 48) 50%, rgb(224, 138, 30) 100%)",
	"linear-gradient(rgb(91, 179, 224) 0%, rgb(68, 156, 208) 50%, rgb(46, 134, 193) 100%)",
	"linear-gradient(rgb(242, 198, 75) 0%, rgb(228, 176, 50) 50%, rgb(212, 154, 30) 100%)"]
func _mua_chip(b: Dictionary) -> Dictionary:   # nút _onbtn -> chip màu mùa hiện tại, gờ vàng
	b.css["background-image"] = MUA_C[G.season()]
	b.css["box-shadow"] = NHAN_VIEN   # nhãn mùa: không gờ vàng
	return b

const NHAN_VIEN := "rgba(90, 40, 10, 0.28) 0px 0px 0px 1px inset, rgba(255, 255, 255, 0.35) 0px 1px 0px 0px inset"   # nhãn màu (không bấm): viền mảnh sậm

# hình quà vẽ trong khung 64 mà độ đầy khác nhau (đồng xu nhỏ, hộp quà to): phóng theo loại cho cùng cỡ nhìn
const ICK := {"coin": 1.35, "pearl": 1.08, "crate": 1.0, "bua": 1.0, "che": 0.9, "gift": 0.8}
func _dick(cx: float, cy: float, s: float, ic: String, op := 1.0) -> Dictionary:   # hình quà loại ic, tâm (cx, cy)
	var svg: String = D.ic[ic] if D.ic.has(ic) else String(D.ddms.kids[1].kids[3].kids[0].svg)
	var z := s * float(ICK.get(ic, 1.0))
	return _dic(cx - z * 0.5, cy - z * 0.5, z, svg, op)

func _dsvg(x: float, y: float, w: float, h: float, svg: String) -> Dictionary:   # hình svg chữ nhật w x h (svg viewBox đúng w h)
	var n := _dic(x, y, w, svg)
	n.r = [x, y, w, h]
	return n

func _dic(x: float, y: float, s: float, svg: String, op := 1.0) -> Dictionary:
	var n: Dictionary = D.cell.fut.kids[1].duplicate(false)   # (bản 475) chép nông
	n.kids = []
	n.r = [x, y, s, s]
	n.svg = svg
	n.css = n.css.duplicate()
	n.css["opacity"] = str(op)
	return n

# (11-26) MỐC ĐỦ CHỜ NHẬN (chung: Năng động, Điểm tuần, mốc Điểm danh): ô lắc (fx "lac"), tia sáng vàng xoay sau ô (fx "tia"), nhãn đỏ "Nhận"
const TIA := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\"><defs><radialGradient id=\"g\" cx=\"50\" cy=\"50\" r=\"50\" gradientUnits=\"userSpaceOnUse\"><stop offset=\"0.3\" stop-color=\"rgb(238,104,28)\" stop-opacity=\"1\"/><stop offset=\"1\" stop-color=\"rgb(238,104,28)\" stop-opacity=\"0\"/></radialGradient><radialGradient id=\"h\" cx=\"50\" cy=\"50\" r=\"34\" gradientUnits=\"userSpaceOnUse\"><stop offset=\"0.4\" stop-color=\"rgb(255,214,90)\" stop-opacity=\"0.9\"/><stop offset=\"1\" stop-color=\"rgb(255,214,90)\" stop-opacity=\"0\"/></radialGradient></defs><path d=\"M50 50L99.7 44.8L99.7 55.2ZM50 50L95.7 70.3L90.5 79.4ZM50 50L79.4 90.5L70.3 95.7ZM50 50L55.2 99.7L44.8 99.7ZM50 50L29.7 95.7L20.6 90.5ZM50 50L9.5 79.4L4.3 70.3ZM50 50L0.3 55.2L0.3 44.8ZM50 50L4.3 29.7L9.5 20.6ZM50 50L20.6 9.5L29.7 4.3ZM50 50L44.8 0.3L55.2 0.3ZM50 50L70.3 4.3L79.4 9.5ZM50 50L90.5 20.6L95.7 29.7Z\" fill=\"url(#g)\"/><circle cx=\"50\" cy=\"50\" r=\"34\" fill=\"url(#h)\"/></svg>"
func _fx_tia(cx: float, cy: float, s: float) -> Dictionary:   # tia sáng sau ô mốc (thêm vào trước ô: nằm dưới)
	var n := _dic(cx - s * 0.5, cy - s * 0.5, s, TIA)
	n.fx = "tia"
	return n

func _fx_nhan(cx: float, y: float) -> Dictionary:   # nhãn đỏ chữ trắng "Nhận" dưới ô mốc
	var p := _onbtn(cx - 20.0, y, 40.0, 16.0, "Nhận", null, true)
	p.kids[0].css["font-size"] = _cpx(10.0)
	return p

func _dtick(x: float, y: float, s := 11.0) -> Dictionary:   # dấu ✓ = ảnh tick chung (Snap)
	var n := _cl(D.cell.got.kids[2])
	n.erase("tr")
	n.r = [x, y, s, s]
	return n

func _dbtn(x: float, y: float, w: float, h: float, s: String, cb: Callable) -> Dictionary:   # nút vàng (mẫu Nhận)
	var n := _cl(D.i7)
	n.erase("tr")
	n.r = [x, y, w, h]
	n.text = s
	n.css = n.css.duplicate()
	n.css["line-height"] = _cpx(h)
	n.css["font-size"] = _cpx(11.5)
	n.css["padding-left"] = "0px"
	n.css["padding-right"] = "0px"
	n.act = cb
	return n

func _dsay(s: String) -> void:   # (bản 504) chạm xem: bong bóng tại chỗ chạm (không dùng toast chung)
	_dtip(s)

const TIPW := 230.0   # rộng tối đa; bong bóng rộng theo chữ, tối thiểu 120
static var _TIPN := {}   # (bản 507) nền bong bóng = nhãn ô ruộng (gv.json .gvlab): kem sáng, viền nâu, bo 10 (bỏ mũi nhọn ::after)
func _dtip(body: String, ic := "", ttl := "") -> void:   # bong bóng: [hình] tên đậm + chữ; ic "gift:<loại>" hình quà, "<svg…" hình svg, còn lại mã _icx
	if _TIPN.is_empty():
		var G0: Dictionary = Snap.load_snap("gv")
		for sel in G0:
			var f: Dictionary = Snap.find(G0[sel][0], "gvlab")
			if not f.is_empty():
				_TIPN = f.duplicate(false)
				break
		_TIPN.kids = []
		_TIPN.erase("::after")
		_TIPN.erase("text")
		_TIPN.css = _TIPN.css.duplicate()   # (bản 508) bỏ bóng đen mờ dưới nhãn: chỉ giữ các lớp inset (viền, vệt sáng)
		var keep := []
		for part in String(_TIPN.css.get("box-shadow", "none")).replace(", rgb", "|rgb").split("|"):
			if String(part).contains("inset"):
				keep.append(String(part))
		_TIPN.css["box-shadow"] = ", ".join(PackedStringArray(keep)) if keep.size() else "none"
	var iw := 38.0 if ic != "" else 0.0
	var TW := TIPW
	var tw0 := TW - 20.0 - iw
	var L := _wrap(body, 10.5, 600, tw0)
	var big := L.size() > 6   # (bản 509) giải thích dài: khung rộng 300, đặt giữa thân bảng
	if big:
		TW = 300.0
		tw0 = TW - 24.0 - iw
		L = _wrap(body, 10.5, 600, tw0)
	var lw := 0.0
	for ln in L:
		lw = maxf(lw, Box.text_w(String(ln), 10.5, 600))
	if ttl != "":
		lw = maxf(lw, Box.text_w(ttl, 11.5, 800))
	var tw := minf(tw0, lw + 4.0)
	var W0 := clampf(tw + 20.0 + iw, 120.0, TW)
	var h := 10.0 + (17.0 if ttl != "" else 0.0) + L.size() * 15.0 + 10.0
	if ic != "":
		h = maxf(h, 50.0)
	# chỗ đặt: theo ô vừa bấm (U.last_btn), không theo điểm ngón tay; không vượt khung bảng
	var vs: Vector2 = U.vsize()
	var a := Rect2(U.last_tap / Css.K, Vector2.ZERO)
	if Time.get_ticks_msec() - U.tap_anchor_ms < 1000 and U.last_btn == null:
		a = U.tap_anchor
	elif U.last_btn != null and is_instance_valid(U.last_btn) and U.last_btn.is_visible_in_tree() and Time.get_ticks_msec() - U.last_btn_ms < 1000:
		var gr: Rect2 = U.last_btn.get_global_rect()
		a = Rect2(gr.position / Css.K, gr.size / Css.K)
	var B: Rect2 = U.panel_rect()
	if B.size == Vector2.ZERO:
		B = Rect2(Vector2.ZERO, vs)
	B = B.grow(-8.0)
	var x := clampf(a.position.x + a.size.x * 0.5 - W0 * 0.5, B.position.x, B.end.x - W0)
	var y := a.position.y - h - 6.0
	if y < B.position.y:   # trên ô hết chỗ: xuống dưới ô
		y = a.end.y + 6.0
	y = clampf(y, B.position.y, B.end.y - h)
	if big:
		x = B.position.x + (B.size.x - W0) * 0.5
		y = maxf(B.position.y, B.position.y + (B.size.y - h) * 0.4)
	var c := _cl(_TIPN)
	c.r = [x, y, W0, h]
	c.erase("tr")
	var ks := []
	var tx := x + 10.0
	if ic != "":
		if ic.begins_with("<svg"):
			ks.append(_dic(x + 10.0, y + h * 0.5 - 15.0, 30.0, ic))
		else:
			ks.append(_dick(x + 25.0, y + h * 0.5, 30.0, ic.substr(5)) if ic.begins_with("gift:") else _icx(x + 25.0, y + h * 0.5, 30.0, ic))
		tx += iw
	var ty := y + 10.0
	if ttl != "":
		ks.append(_dt(tx, ty, tw + 2.0, 17.0, ttl, 11.5, 900, "rgb(58, 42, 16)", "left"))
		ty += 17.0
	for i in L.size():
		ks.append(_dt(tx, ty + i * 15.0, tw + 2.0, 15.0, String(L[i]), 10.5, 600, "rgb(63, 138, 52)" if ic != "" else "rgb(90, 66, 34)", "left"))   # dòng quà (có hình) xanh lá như "Hợp mùa"; chữ giải thích nâu
	c.kids = ks
	var wrap := {"z": 1.0, "tag": "div", "id": "", "cls": "", "r": [0.0, 0.0, vs.x, vs.y], "css": {"display": "block", "position": "absolute"}, "kids": [c]}
	var b: Control = U._build(wrap, {})
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	U.tip_show(b, clampf(2.0 + (body.length() + ttl.length()) / 22.0, 3.5, 14.0))   # đọc lâu theo độ dài chữ; chạm chỗ khác là tắt

# ------------------------------------------------------------------ (bản 453) khối chung dời từ Nhà dân sang (Nhà dân, Nghề dùng chung)
const HEART := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M12 21s-7.5-4.6-9.6-9.1C.9 8.6 3 5 6.6 5c2.1 0 3.6 1.1 4.4 2.5h2C13.8 6.1 15.3 5 17.4 5 21 5 23.1 8.6 21.6 11.9 19.5 16.4 12 21 12 21z\" fill=\"rgb(226,64,72)\" stroke=\"rgb(170,36,44)\" stroke-width=\"1.2\"/></svg>"

func _icn(cx: float, cy: float, s: float, id: String) -> Dictionary:   # hình món Kho (không khung)
	var b := _dbx(cx - s * 0.5, cy - s * 0.5, s, s, "rgba(0, 0, 0, 0)", 0.0)
	b.ic = id
	return b

# (bản 470) tim tô dần, hình sở trường: dời từ Nhà dân sang (Nhà dân, Làm thuê dùng chung)
const HEART0 := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M12 21s-7.5-4.6-9.6-9.1C.9 8.6 3 5 6.6 5c2.1 0 3.6 1.1 4.4 2.5h2C13.8 6.1 15.3 5 17.4 5 21 5 23.1 8.6 21.6 11.9 19.5 16.4 12 21 12 21z\" fill=\"rgb(250,236,230)\" stroke=\"rgb(214,150,150)\" stroke-width=\"1.4\"/></svg>"
static func _heartp(p: float) -> String:   # tim đầy p phần (tô đỏ từ trái sang)
	var w := snappedf(clampf(p, 0.0, 1.0) * 24.0, 0.1)
	var path := "M12 21s-7.5-4.6-9.6-9.1C.9 8.6 3 5 6.6 5c2.1 0 3.6 1.1 4.4 2.5h2C13.8 6.1 15.3 5 17.4 5 21 5 23.1 8.6 21.6 11.9 19.5 16.4 12 21 12 21z"
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><defs><clipPath id=\"c\"><rect x=\"0\" y=\"0\" width=\"" + str(w) + "\" height=\"24\"/></clipPath></defs><path d=\"" + path + "\" fill=\"rgb(250,236,230)\" stroke=\"rgb(214,150,150)\" stroke-width=\"1.4\"/><path clip-path=\"url(#c)\" d=\"" + path + "\" fill=\"rgb(226,64,72)\"/><path d=\"" + path + "\" fill=\"none\" stroke=\"rgb(190,80,90)\" stroke-width=\"1.2\"/></svg>"

const TALIC := {"ruong": "lua", "vuon": "qua_xoai", "chan": "trung", "xuong": "gao"}   # hình sở trường (thay emoji)

func _icx(cx: float, cy: float, s: float, id: String) -> Dictionary:   # (bản 462) hình theo mã: "xu" đồng xu, "svg:<đường dẫn>" hình svg, "pic:<đường dẫn>" ảnh, còn lại hình món Kho
	if id == "xu":
		return _dick(cx, cy, s * 0.8, "coin")
	if id == "pearl":   # sen đỏ
		return _dick(cx, cy, s, "pearl")
	if id.begins_with("svg:"):
		return _dic(cx - s * 0.5, cy - s * 0.5, s, FileAccess.get_file_as_string(id.substr(4)))
	if id.begins_with("pic:"):   # ảnh chữ nhật: giữ tỉ lệ, vừa khung s
		var t: Texture2D = Css.image(id.substr(4))
		var a := (float(t.get_width()) / maxf(1.0, float(t.get_height()))) if t != null else 1.0
		var w := s * (1.15 if a > 1.0 else a)
		var h := w / a
		return _pic(cx - w * 0.5, cy - h * 0.5, w, h, id.substr(4))
	return _icn(cx, cy, s, id)

func _pic(x: float, y: float, w: float, h: float, path: String) -> Dictionary:   # ảnh res://ui/img/...
	var b := _dbx(x, y, w, h, "rgba(0, 0, 0, 0)", 0.0)
	b.pic = path
	return b

func _tchip(x: float, y: float, t: String, kind: String, col := BROWN, cb = null, h := 18.0, fs := 10.0) -> Array:   # chip chữ nhỏ; trả [khối, rộng]
	var w: float = Box.text_w(t, fs, 700) + 14.0
	var c := _chip(x, y, w, h, kind)
	c.kids = [_dt(x, y, w, h, t, fs, 700, col)]
	if cb is Callable:
		c.act = cb
	return [c, w]

func _btn(x: float, y: float, w: float, h: float, t: String, cb, kind := "go") -> Dictionary:   # go: chip xanh Kho, red: đỏ, gold: vàng, off: xám, plain: kem bấm được (bản 552)
	if kind == "plain":
		var p := _chip(x, y, w, h, "fut", true)
		p.kids = [_dt(x, y, w, h, t, 11.0, 800, BROWN)]
		p.act = cb
		return p
	if kind == "off":
		var c := _chip(x, y, w, h, "miss")
		c.kids = [_dt(x, y, w, h, t, 10.5, 700, "rgb(110, 104, 92)")]
		return c
	var b := _onbtn(x, y, w, h, t, cb, kind == "red")
	b.kids[0].css["font-size"] = _cpx(11.0)
	if kind == "gold":   # (11-28) nút vàng: tặng, nhận quà (đỏ chỉ để huỷ / cảnh báo)
		b.css["background-image"] = "linear-gradient(rgb(255, 222, 120) 0%, rgb(244, 178, 52) 100%)"
		b.kids[0].css["color"] = "rgb(106, 58, 8)"
	return b

func _rowi(x: float, y: float, h: float, parts: Array, fs: float, fw: int, col: String) -> Array:   # (bản 452) dòng chữ xen hình: "h" tim, "s" sao, "c" xu, "i:<mã>" hình bất kỳ; trả [khối, rộng]
	var out := []
	var cx := x
	var z := fs + 3.0
	for pt in parts:
		var t := String(pt)
		if t.begins_with("i:"):   # (bản 467) "i:<mã>": hình bất kỳ theo _icx (món Kho, svg:, pic:, xu)
			cx += 2.0
			out.append(_icx(cx + z * 0.5, y + h * 0.5, z, t.substr(2)))
			cx += z + 2.0
		elif t == "h" or t == "s" or t == "c":
			cx += 2.0
			if t == "h":
				out.append(_dic(cx, y + (h - z) * 0.5, z, HEART))
			elif t == "s":
				out.append(_pic(cx, y + (h - z) * 0.5, z, z, "res://ui/img/bong/sao.png"))
			else:
				out.append(_dick(cx + z * 0.5, y + h * 0.5, z, "coin"))
			cx += z + 2.0
		else:
			var tw: float = Box.text_w(t, fs, fw) + 1.0
			out.append(_dt(cx, y, tw, h, t, fs, fw, col, "left"))
			cx += tw
	return [out, cx - x]

func _wrap(t: String, fs: float, fw: int, w: float) -> Array:
	var L := []
	var cur := ""
	for wd in t.split(" ", false):
		var tr := (cur + " " + wd) if cur != "" else wd
		if cur != "" and Box.text_w(tr, fs, fw) > w:
			L.append(cur)
			cur = wd
		else:
			cur = tr
	if cur != "":
		L.append(cur)
	return L

func _para(x: float, y: float, w: float, t: String, fs := 10.5, fw := 600, col := SUB, lh := 14.0) -> Array:   # đoạn chữ xuống dòng: [khối, cao]
	var out := []
	var L := _wrap(t, fs, fw, w)
	for i in L.size():
		out.append(_dt(x, y + i * lh, w, lh, L[i], fs, fw, col, "left"))
	return [out, L.size() * lh]

const _NUMB := "[+−-]?\\d+(?:[.,]\\d+)*(?:[–-]\\d+)?(?:%|★| ?♥| ?(?:phút|giờ|tiếng|xu|ngày|lần|bó|viên|sức|câu|hạt|ô|món)(?![\\p{L}]))?"
func _parab(x: float, y: float, w: float, t: String, fs := 10.5, fw := 600, col := SUB, lh := 14.0, bcol := "rgb(150, 70, 20)") -> Array:   # (bản 488) đoạn chữ, số liệu (2 phút, +10%, 3 ♥) tô đậm: [khối, cao]
	var segs := []   # [chữ, đậm?]
	var re := RegEx.create_from_string(_NUMB)
	var p0 := 0
	for m in re.search_all(t):
		if m.get_start() > p0:
			segs.append([t.substr(p0, m.get_start() - p0), false])
		segs.append([m.get_string(), true])
		p0 = m.get_end()
	if p0 < t.length():
		segs.append([t.substr(p0), false])
	# xếp từng chữ (đo bằng Box.text_w như _wrap): mỗi dòng là các mẩu [chữ, đậm, x]
	var sw: float = Box.text_w("a a", fs, fw) - Box.text_w("aa", fs, fw)
	var out := []
	var cx := 0.0
	var ln := 0
	var sp := false   # có khoảng trắng chờ trước chữ kế
	for sg in segs:
		var b: bool = sg[1]
		var s0: String = sg[0]
		var ws := s0.split(" ")
		for k in ws.size():
			if k > 0:
				sp = true
			var wd: String = ws[k]
			if wd == "":
				continue
			var ww: float = Box.text_w(wd, fs, 800 if b else fw)
			var gx := (sw if sp and cx > 0.0 else 0.0)
			if cx > 0.0 and cx + gx + ww > w + 0.5:
				ln += 1
				cx = 0.0
				gx = 0.0
			out.append(_dt(x + cx + gx, y + ln * lh, ww + 2.0, lh, wd, fs, 800 if b else fw, bcol if b else col, "left"))
			cx += gx + ww
			sp = false
	return [out, (ln + 1) * lh if out.size() else 0.0]

const LUP := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><circle cx=\"10\" cy=\"10\" r=\"6.5\" fill=\"none\" stroke=\"rgb(150,112,60)\" stroke-width=\"2.2\"/><path d=\"M15 15 L21 21\" stroke=\"rgb(150,112,60)\" stroke-width=\"2.6\" stroke-linecap=\"round\"/></svg>"
func _qbox(y: float, cls: String) -> Dictionary:   # (bản 493, chung) ô tìm: nền trắng, kính lúp, đang gõ viền xanh; LineEdit đặt đè bằng _qe_make("." + cls)
	var sb := _dbx(X0, y, XW, 30.0, "rgb(255, 255, 255)", 15.0, "", "rgba(76, 150, 48, 0.95) 0px 0px 0px 2px inset" if qe_on() else "rgba(150, 112, 48, 0.55) 0px 0px 0px 1px inset")
	sb.cls = cls
	sb.kids = [_dic(X0 + XW - 26.0, y + 7.0, 16.0, LUP)]
	return sb

const HDG := 26.0   # (11-26) đỉnh tiêu đề mục -> khối dưới (icon tiêu đề không dính khối)

# (11-26) giãn khối cho kín thân: chỗ dư (tới đáy chung) chia đều vào các khối cs (theo thứ tự trên xuống), nội dung trong khối dời giữa; trả cao mới
func _fill(out: Array, h: float, cs: Array) -> float:
	var d := _hb - 2.0 - h
	if cs.is_empty() or absf(d) <= 1.0:
		return h
	var B := []
	for c in cs:
		B.append([float(c.r[1]), float(c.r[1]) + float(c.r[3])])
	if d < 0.0:   # lố đáy chút (vd hiện thêm hàng thích / ghét): bớt đều khoảng cách giữa các khối, tiêu đề vẫn nằm giữa; lố nhiều thì để cuộn
		if cs.size() < 2:
			return h
		var gq := maxf(d / (cs.size() - 1), -14.0)
		for k in out:
			if not (k is Dictionary and k.has("r")):
				continue
			var t := float(k.r[1])
			var dy := 0.0
			for i in range(cs.size() - 1, 0, -1):
				if is_same(k, cs[i]) or t >= B[i][0] - 0.5:
					dy = gq * i
					break
				if t >= B[i - 1][1] - 0.5:
					dy = gq * (i - 0.5)
					break
			if dy != 0.0:
				Snap._move(k, Vector2(0, dy))
		return h + gq * (cs.size() - 1)
	var e := d / cs.size()
	for k in out:
		if not (k is Dictionary and k.has("r")):
			continue
		var t := float(k.r[1])
		var dy := 0.0
		for i in cs.size():
			if is_same(k, cs[i]):
				dy = e * i
				break
			if t >= B[i][1] - 0.5:
				dy = e * (i + 1)
			elif t >= B[i][0] - 0.5:
				dy = e * i + e * 0.5
				break
			else:
				break
		if dy != 0.0:
			Snap._move(k, Vector2(0, dy))
	for c in cs:
		c.r[3] = float(c.r[3]) + e
	return h + d

func _sect(y: float, t: String, _col := "", ic := "") -> Array:   # (11-26) tiêu đề phần = tiêu đề mục chung (_hd)
	return _hd(maxf(y, 5.0) if ic != "" else y + 1.0, t, ic)   # có icon: icon cách khối trên (GG - 5) bằng cách khối dưới (HDG - 20)

# hàng chip món cần: [[hình, tên, có, cần, (việc khi thiếu)]] -> chip 2 dòng (tên / có-cần, xanh đủ đỏ thiếu); trả [khối, cao, đủ hết]
func _nchips(x: float, y: float, w: float, list: Array) -> Array:
	var out := []
	var cx := x
	var cy := y
	var ok := true
	# (bản 451) mỗi chip dài theo tên; không lọt 1 hàng thì thu đều cho vừa (tên dài bóp chữ nhỏ), thu quá nhỏ mới xuống hàng
	var cws := []
	var sm := 0.0
	for it in list:
		var s0: String = G.fmt_n(int(it[3])) if String(it[0]) == "xu" else G.fmt_n(mini(int(it[2]), 99999)) + "/" + G.fmt_n(int(it[3]))   # (bản 551) xu: chỉ ghi số cần, đủ xanh thiếu đỏ
		var cw0: float = minf(38.0 + maxf(Box.text_w(String(it[1]), 10.0, 700), Box.text_w(s0, 10.5, 800)) + 8.0, w)
		cws.append(cw0)
		sm += cw0
	var gs := 5.0 * maxf(0.0, list.size() - 1.0)
	if list.size() > 1 and sm + gs > w:
		var k := (w - gs) / sm
		var mn := 1e9
		for cw0 in cws:
			mn = minf(mn, float(cw0) * k)
		if mn >= 84.0:
			for i in cws.size():
				cws[i] = floorf(float(cws[i]) * k)
		else:   # (bản 456) không lọt 1 hàng: lưới 2 cột rộng bằng nhau cho đều
			for i in cws.size():
				cws[i] = floorf((w - 5.0) * 0.5)
	elif list.size() > 0 and sm + gs < w:   # (bản 551) lọt 1 hàng: giãn đều cho kín bề ngang, cách đều 2 mép
		var ex := (w - sm - gs) / list.size()
		for i in cws.size():
			cws[i] = floorf(float(cws[i]) + ex)
	for i in list.size():
		var it: Array = list[i]
		var id := String(it[0])
		var nm := String(it[1])
		var hv := int(it[2])
		var q := int(it[3])
		var good := hv >= q
		ok = ok and good
		var s: String = G.fmt_n(q) if id == "xu" else G.fmt_n(mini(hv, 99999)) + "/" + G.fmt_n(q)
		var cw: float = cws[i]
		var tw := cw - 40.0
		var fs := clampf(10.0 * tw / maxf(1.0, Box.text_w(nm, 10.0, 700)), 8.5, 10.0)
		if cx > x and cx + cw > x + w:
			cx = x
			cy += 40.0
		var c := _chip(cx, cy, cw, 34.0, "got" if good else "sen")
		c.kids = [_icx(cx + 18.0, cy + 17.0, 28.0, id), _dt(cx + 36.0, cy + 3.0, tw, 14.0, _fitw(nm, fs, 700, tw), fs, 700, BROWN, "left"),
			_dt(cx + 36.0, cy + 17.0, cw - 40.0, 14.0, s, 10.5, 800, "rgb(46, 120, 50)" if good else "rgb(190, 60, 50)", "left")]
		c.act = it[4] if it.size() > 4 and it[4] is Callable and not good else _dsay.bind(nm + ": kho có " + G.fmt_n(hv) + ", cần " + G.fmt_n(q) + ".")   # it[4]: việc khi chạm món còn thiếu
		out.append(c)
		cx += cw + 5.0
	return [out, cy + 34.0 - y if list.size() else 0.0, ok]

const ICS := {"chieu": 1.2, "trung": 1.12, "gao": 1.08}   # hình thưa (dẹt / tròn nhỏ): phóng cho cùng cỡ nhìn
# lưới chip: [{b tên, s dòng phụ, ic hình, st "on"|"dis"|"hint"|"", k loại chip, act}] cols cột
func _grid(y: float, bt: Array, cols: int, kind_on: String, bh0 := 0.0) -> Array:   # bh0 > 0: (bản 454) chip cao bh0 (giãn kín thân), chữ canh giữa dọc, có dòng 3 "s2" (tối đa 2 dòng)
	var out := []
	var g := 6.0
	var bw := (XW - (cols - 1) * g) / cols
	var bh: float = bh0 if bh0 > 0.0 else (44.0 if cols == 2 else 40.0)
	var big := bh >= 56.0
	for i in bt.size():
		var o: Dictionary = bt[i]
		var x := X0 + (i % cols) * (bw + g)
		var yy := y + floorf(i / float(cols)) * (bh + g)
		var st := String(o.st)
		var c := _chip(x, yy, bw, bh, kind_on if st == "on" else ("miss" if st == "dis" or st == "hint" else String(o.get("k", "fut"))))
		var ks := []
		var tx := x + 8.0
		if String(o.get("ic", "")) != "":   # (bản 447) hình cách đều 2 bên 8: tâm 21, cỡ 26 (phóng theo độ đầy hình), chữ từ 42
			var z := 34.0 if big else 26.0
			ks.append(_icx(x + (24.0 if big else 21.0), yy + bh * 0.5, z * float(ICS.get(String(o.ic), 1.0)), String(o.ic)))
			tx = x + (48.0 if big else 42.0)
		var tw := x + bw - (22.0 if st == "on" else 6.0) - tx   # (bản 462) chừa chỗ dấu tick
		var dim := st == "dis" or st == "hint"
		var L2: Array = _wrap(String(o.get("s2", "")), 10.0, 600, tw) if big and String(o.get("s2", "")) != "" else []
		if L2.size() > 2:
			L2 = [L2[0], _fitw(String(L2[1]) + " " + " ".join(PackedStringArray(L2.slice(2))), 10.0, 600, tw)]
		var TL: Array = [String(o.b)]   # (11-28) chip to: tên dài xuống 2 dòng (không cắt "…"), bớt dòng mô tả
		if big and Box.text_w(String(o.b), 11.5, 800) > tw:
			TL = _wrap(String(o.b), 11.5, 800, tw)
			if TL.size() > 2:
				TL = [TL[0], _fitw(" ".join(PackedStringArray(TL.slice(1))), 11.5, 800, tw)]
		var th0 := 15.0 * TL.size() + (16.0 if String(o.get("s", "")) != "" else 0.0)
		while L2.size() and th0 + L2.size() * 13.0 + 3.0 > bh - 10.0:   # chip thấp: bớt dòng 3, dòng cuối cắt "…"
			var last: String = String(L2[L2.size() - 1])
			L2.pop_back()
			if L2.size():
				L2[L2.size() - 1] = _fitw(String(L2[L2.size() - 1]) + " " + last, 10.0, 600, tw)
		var th := th0 + L2.size() * 13.0 + (3.0 if L2.size() else 0.0)
		var ty := yy + 6.0 if not big else yy + (bh - th) * 0.5
		for tl in TL:
			ks.append(_dt(tx, ty, tw, 15.0, _fitw(String(tl), 11.5, 800, tw), 11.5, 800, "rgb(120, 112, 98)" if dim else BROWN, "left"))
			ty += 15.0
		ty += 1.0
		if String(o.get("s", "")) != "":
			ks.append(_dt(tx, ty, tw, 13.0, _fitw(String(o.s), 10.5, 600, tw), 10.5, 600, "rgb(130, 124, 112)" if dim else SUB, "left"))
			ty += 16.0
		for ln in L2:
			ks.append(_dt(tx, ty, tw, 13.0, String(ln), 10.0, 600, "rgb(150, 128, 96)", "left"))
			ty += 13.0
		if st == "on":   # đang chọn: dấu tick góc phải
			ks.append(_dtick(x + bw - 17.0, yy + 5.0, 12.0))
		c.kids = ks
		if st != "dis" and o.has("act"):
			c.act = o.act
		out.append(c)
	var rows := int(ceil(bt.size() / float(cols)))
	return [out, rows * bh + maxf(0, rows - 1) * g]

func _fillh(y: float, n: int, cols := 2) -> float:   # (bản 454) cao chip để n ô (cols cột) kín phần thân còn lại từ y, chừa GG đáy; 0 = không giãn
	var rows := int(ceil(n / float(cols)))
	if rows < 1:
		return 0.0
	var h := (_hb - y - GG - (rows - 1) * 6.0) / rows
	return clampf(floorf(h), 44.0, 84.0) if h > 44.0 else 0.0
const CHD := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 10 10\"><path d=\"M2 3.5 L5 6.5 L8 3.5\" fill=\"none\" stroke=\"rgb(128,98,58)\" stroke-width=\"1.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>"   # (bản 464) mũi tên mở (khung chung)
const CHU := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 10 10\"><path d=\"M2 6.5 L5 3.5 L8 6.5\" fill=\"none\" stroke=\"rgb(128,98,58)\" stroke-width=\"1.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>"   # mũi tên đóng
const TRACK := "rgb(242, 222, 172)"   # rãnh thanh: vàng kem ấm
func _bar(x: float, y: float, w: float, f: float, h := 5.0, trk := TRACK, fc := "") -> Array:   # thanh tiến độ: màu chạy từ đỏ (mới bắt đầu) qua vàng tới xanh (đủ); fc: màu chạy cố định (vd màu nhóm việc)
	var out := [_dbx(x, y, w, h, trk, h * 0.5)]
	out.append(_dbx(x, y, maxf(h, w * clampf(f, 0.0, 1.0)), h, fc if fc != "" else _fcol(f), h * 0.5))   # (bản 481) lúc 0 vẫn có chấm đỏ đầu thanh
	return out

static func _fcol(f: float) -> String:
	var a := Color8(214, 72, 52)
	var b := Color8(230, 170, 30)
	var c := Color8(46, 150, 80)
	f = clampf(f, 0.0, 1.0)
	var k := a.lerp(b, f * 2.0) if f < 0.5 else b.lerp(c, (f - 0.5) * 2.0)
	return "rgb(%d, %d, %d)" % [int(k.r8), int(k.g8), int(k.b8)]

# ------------------------------------------------------------------ (bản 469) lưới thuê làm chung: tab Thuê làm (Nhà dân) và bảng Làm thuê dùng chung
const JOBIC := {"": "chieu", "ruong": "lua", "vuon": "qua_xoai", "chan": "trung"}
var hpick := ""             # lưới con đang mở ("" | "ruong" giống | "xuong" xưởng | "mon" món xưởng), mỗi lúc một lưới
var hu = null               # nhà đang mở lưới
var _hW                     # w_lang.gd (bảng gọi truyền vào)

func _hire(y0: float, uu, e: Dictionary, col: String, W) -> Array:   # lưới việc thuê của 1 nhà + lưới con (giống / xưởng / món); trả [khối, cao]
	_hW = W
	if hu != uu:
		hu = uu
		hpick = ""
	var out := []
	var y := y0
	var s: Array = W.lm()
	var hh := maxi(1, int(ceil(W._gg().size() / 12.0)))
	var p: bool = e.get("job") == "ruong" or s.size() < hh
	var bt := []
	bt.append({"b": "Nghỉ ở nhà", "s": "Không tốn công", "ic": JOBIC[""], "st": "on" if not W._tr(e.get("job")) else "off", "act": _hjob0.bind("")})
	var cr := String(e.get("crop", ""))
	var rs: String = (("Gieo " + String(G.D.crops[cr].name).to_lower() if cr != "" and G.D.crops.has(cr) else "Giữ giống cũ") + " · " + str(W.om(e, "ruong")) + " xu/phút") if e.get("job") == "ruong" else ("Chọn giống · " + str(W.om(e, "ruong")) + " xu" if p else "Đủ người rồi")
	bt.append({"b": "Làm ruộng", "s": rs, "ic": JOBIC.ruong, "k": "j_ruong", "st": "on" if e.get("job") == "ruong" else ("off" if p else "dis"), "act": _hpk.bind("ruong")})
	for M in ["vuon", "chan"]:
		var t: String = W.vg(M)
		var w: bool = e.get("job") == M
		var E := t != "" and not w
		var C: bool = W.yx(M)
		bt.append({"b": "Làm vườn" if M == "vuon" else "Chăm chuồng", "k": "j_" + M, "s": t + " đang làm" if E else (str(W.om(e, M)) + " xu/phút" if C else ("Chưa có cây" if M == "vuon" else "Chưa có con")),
			"ic": JOBIC[M], "st": "on" if w else ("dis" if E or (not C and not w) else "off"), "act": _hjob0.bind(M)})
	var o: Array = G.xw.N0.filter(func(k): return G.xw.built(k)).map(func(k): return W.jx(String(k)))   # mã việc thuê (Ruộng muối = "x_ruong")
	var xj: bool = o.has(e.get("job"))   # (bản 439) các xưởng gom 1 chip "Làm xưởng", chạm mở lưới chọn xưởng
	if o.size():
		var xs: String = (String(W.CO.get(e.job, e.job)) + (" · " + String(W._ae(e.jr).get("name", "")).to_lower() if W._tr(e.get("jr")) else "") + " · " + str(W.om(e, e.job)) + " xu/phút") if xj else ("Chọn xưởng · " + str(o.size()))
		var xr: Array = G.xw.sr[W.xj(e.job)].rec if xj else []
		bt.append({"b": "Làm xưởng", "s": xs, "ic": String(xr[0]) if xr.size() else "gao", "k": "j_xuong", "st": "on" if xj else "off", "act": _hpk.bind("xuong")})
	if o.is_empty():   # (bản 444) chưa có xưởng: chip mờ trong lưới, chạm hiện cách xây
		bt.append({"b": "Xưởng", "s": "Chưa xây", "ic": "gao", "st": "hint", "act": _dsay.bind("Xây xưởng (Xây dựng › Xưởng) rồi thuê người làm: xưởng tự thu hàng và làm tiếp món bạn chọn.")})
	var gr := _grid(y, bt, 2, "thue")
	out.append_array(gr[0])
	y += float(gr[1]) + 10.0
	if hpick == "xuong" and o.size():   # lưới chọn xưởng
		out.append_array(_sect(y, "Làm xưởng nào?", col))
		y += 22.0
		var xk := []
		for M in o:
			var t: String = W.vg(M)
			var w: bool = e.get("job") == M
			var E := t != "" and not w
			var rec: Array = G.xw.sr[W.xj(M)].rec
			var mm: String = M
			xk.append({"b": String(W.CO.get(M, M)), "s": t + " đang làm" if E else str(W.om(e, M)) + " xu/phút", "ic": String(rec[0]) if rec.size() else "gao", "k": "j_xuong",
				"st": "on" if w else ("dis" if E else "off"), "act": _hxw.bind(mm)})
		var gx := _grid(y, xk, 2, "thue")
		out.append_array(gx[0])
		y += float(gx[1]) + 10.0
	if hpick == "ruong":   # lưới chọn giống: chọn xong mới giao Làm ruộng
		out.append_array(_sect(y, "Gieo cây gì?", col))
		y += 22.0
		var pk := []
		for M in W.xq(e):
			var P: PackedStringArray = String(M.t).split(" · ")
			var id: String = M.id
			pk.append({"b": P[0], "s": " · ".join(P.slice(1)), "ic": id, "k": "j_ruong", "st": "on" if e.get("job") == "ruong" and String(e.get("crop", "")) == id else "off", "act": _hseed.bind(id)})
		var g2 := _grid(y, pk, 2, "thue")
		out.append_array(g2[0])
		y += float(g2[1]) + 10.0
	if hpick == "mon" and W._tr(e.get("job")) and e.job != "ruong" and G.xw.sr.has(W.xj(e.job)):   # món của xưởng vừa chọn
		var d: Dictionary = G.xw.sr[W.xj(e.job)]
		out.append_array(_sect(y, "Làm món gì?", col))
		y += 22.0
		var rk := []
		for M in d.rec:
			var id := String(M)
			rk.append({"b": String(W._ae(id).get("name", id)), "s": "" if G.xw.has_in(id) else "thiếu đồ", "ic": id, "k": "j_xuong", "st": "on" if e.get("jr") == id else "off", "act": _hmon.bind(id)})
		var g3 := _grid(y, rk, 2, "thue")
		out.append_array(g3[0])
		y += float(g3[1]) + 10.0
	return [out, y - y0]


func _hpk(k: String) -> void:   # chạm chip Làm ruộng / Làm xưởng: mở lưới của nó (chạm lại thì đóng)
	hpick = "" if hpick == k else k

func _hjob0(m: String) -> void:   # Nghỉ / vườn / chuồng: giao ngay, đóng lưới
	hpick = ""
	_hW.n4(hu, m)

func _hseed(id: String) -> void:   # chọn giống: lúc này mới giao Làm ruộng rồi gieo giống đó
	var f = _hW._fam_of(hu)
	if f == null:
		return
	if f.get("job") != "ruong":
		_hW.n4(hu, "ruong")
		if f.get("job") != "ruong":   # không giao được (thiếu tiền, đủ người): giữ lưới
			return
	_hW.jq(hu, id)
	hpick = ""

func _hxw(m: String) -> void:   # chọn xưởng: giao việc, rồi mở lưới món của xưởng đó
	_hW.n4(hu, m)
	var f = _hW._fam_of(hu)
	if f != null and f.get("job") == m:
		hpick = "mon"

func _hmon(id: String) -> void:
	_hW.set_jr(hu, id)
	hpick = ""

# (bản 547) thẻ chọn món trên lưới, dùng chung (Câu cá ui_ccp, Lờ lọp ui_lop): hình + tên + dòng phụ + đoạn tả + chip thêm + nút
func _scard(y: float, pic: String, ttl: String, sub: String, desc: String, btns: Array, extra := []) -> Array:   # btns: [[chữ, việc, kiểu]]
	var out := []
	var P: Array = _para(X0 + 10.0, y + 46.0, XW - 20.0, desc, 10.5, 600, SUB, 14.0) if desc != "" else [[], 0.0]
	var h: float = 46.0 + float(P[1]) + (6.0 if desc != "" else 0.0) + (extra[1] if extra.size() else 0.0) + 34.0
	var c := _chip(X0, y, XW, h, "fut")
	out.append(c)
	if pic != "":
		out.append(_icx(X0 + 26.0, y + 23.0, 34.0, "pic:" + pic))
	out.append(_dt(X0 + 48.0, y + 7.0, XW - 56.0, 17.0, _fitw(ttl, 12.5, 800, XW - 56.0), 12.5, 800, BROWN, "left"))
	if sub != "":
		out.append(_dt(X0 + 48.0, y + 25.0, XW - 56.0, 15.0, _fitw(sub, 10.5, 700, XW - 56.0), 10.5, 700, SUB, "left"))
	out.append_array(P[0])
	var yy: float = y + 46.0 + float(P[1]) + (6.0 if desc != "" else 0.0)
	if extra.size():
		for k in extra[0]:
			Snap._move(k, Vector2(0, yy))
		out.append_array(extra[0])
		yy += extra[1]
	var bx := X0 + XW - 8.0
	for i in range(btns.size() - 1, -1, -1):
		var b: Array = btns[i]
		var bw: float = Box.text_w(String(b[0]), 11.0, 800) + 26.0
		bx -= bw
		if String(b[2]) == "gold":
			out.append(_dbtn(bx, yy, bw, 26.0, String(b[0]), b[1]))
		else:
			out.append(_btn(bx, yy, bw, 26.0, String(b[0]), b[1], String(b[2])))
		bx -= 6.0
	return [out, h]

func _mat_ic(id: String) -> String:   # (bản 549) mã hình vật liệu nâng cấp cho _icx: ảnh ui/img/vl (đồ câu), svg ui/svg/mat, không có thì hình món
	if FileAccess.file_exists("res://ui/img/vl/" + id + ".webp"):
		return "pic:res://ui/img/vl/" + id + ".webp"
	if FileAccess.file_exists("res://ui/svg/mat/" + id + ".svg"):
		return "svg:res://ui/svg/mat/" + id + ".svg"
	return id

# (11-28) THANH MỐC QUÀ CHUNG (Nhiệm vụ năng động, 7 ngày về làng): tiêu đề + số / tổng, hàng ô quà theo mốc, thanh, số mốc
# L: [[mốc, hình quà, đã nhận?, nhận(), tên?, mô tả?]]; trả [khối, cao]
func _ms(y: float, name: String, cur: int, top: int, L: Array, g := 8.0, ic := "") -> Array:   # g: tiêu đề -> hàng hình
	var out := []
	var vs := str(cur)
	var tw: float = Box.text_w("/" + str(top), 11.0, 700)
	var vw: float = Box.text_w(vs, 14.0, 800)
	out.append_array(_hd(y + 5.0, name, ic, tw + vw + 10.0))   # (11-26) tiêu đề mục chung, số điểm bên phải
	out.append(_dt(X0 + XW - 2.0 - tw - vw, y + 4.0, vw, 18.0, vs, 14.0, 800, GREEN, "left"))
	out.append(_dt(X0 + XW - 2.0 - tw, y + 5.25, tw, 16.0, "/" + str(top), 11.0, 700, SUB, "left"))   # chân chữ "/100" ngang chân số lớn
	var cs := 34.0
	var iy := y + 26.0 + g + 4.0   # chip tên -> hàng quà: rộng hơn g một chút (quà nổi, dễ dính chip tên)
	var bxl := X0 + cs * 0.5
	var bxw := XW - cs
	var by := iy + cs + 6.0
	out.append_array(_bar(X0 + 2.0, by, XW - 4.0, float(cur) / float(maxi(1, top)), 7.0))
	for m in L:
		var p := int(m[0])
		var cx := bxl + bxw * float(p) / float(maxi(1, top))
		var got: bool = m[2]
		var ok := cur >= p
		if ok and not got:   # (11-26) đủ mốc chờ nhận: tia sáng sau ô
			out.append(_fx_tia(cx, iy + cs * 0.5, cs * 1.9))
		var c := _chip(cx - cs * 0.5, iy, cs, cs, "got" if got else ("now" if ok else "fut"))
		var ks := [_dick(cx, iy + cs * 0.5, 24.0, String(m[1]), 0.5 if got else 1.0)]
		c.kids = ks
		if ok and not got:
			c.act = m[3]
			c.fx = "lac"
		elif m.size() > 4:   # (bản 504) chạm quà chưa nhận / đã nhận: bong bóng hình, tên, quà bên trong
			c.act = _dtip.bind(String(m[5]), "gift:" + String(m[1]), String(m[4]) + " · mốc " + str(p) + (" · đã nhận" if got else ""))
		out.append(c)
		out.append(_dbx(cx - 1.0, by - 1.0, 2.0, 9.0, "rgb(190, 160, 100)" if not ok else "rgb(32, 112, 58)", 1.0))
		out.append(_fx_nhan(cx, by + 9.0) if ok and not got else _dt(cx - 20.0, by + 11.0, 40.0, 12.0, str(p), 9.5, 700, SUB))
	return [out, by + 11.0 + 12.0 - y]

# (11-28) HÀNG CHIP LỌC CHUNG (Kỷ lục, Làm thuê...): F = [[khóa, chữ, món hình | ""]], chip rộng theo chữ (+ hình), phần dư chia đều;
#   không đủ chỗ mới thu đều và cắt "…". Trả [khối, cao].
func _flex_w(cs: Array, total: float, gap: float) -> Array:   # cs: bề ngang cần của từng chip
	var sum := 0.0
	for c in cs:
		sum += float(c)
	var room := total - gap * (cs.size() - 1)
	var ex := (room - sum) / maxf(1.0, cs.size())
	var k := 1.0 if ex >= 0.0 else room / maxf(1.0, sum)
	return cs.map(func(c): return float(c) + ex if ex >= 0.0 else float(c) * k)

func _fchips(y: float, F: Array, cur: String, cb: Callable, _on_kind := "") -> Array:   # (11-28) cùng kiểu chip lọc Kho: đang chọn = nút xanh gờ vàng, còn lại chip kem gờ vàng, chữ 11 đậm; "?" = chip tre
	var out := []
	var need := []
	for f in F:
		need.append(Box.text_w(String(f[1]), 11.0, 800) + 14.0 + (19.0 if String(f[2]) != "" else 0.0))
	var eq := (XW - 6.0 * (F.size() - 1)) / F.size()   # rộng đều như Kho nếu chữ nào cũng vừa
	var fitall := true
	for c in need:
		fitall = fitall and float(c) <= eq
	var W: Array = []
	for i in F.size():
		W.append(eq)
	if not fitall:
		W = _flex_w(need, XW, 6.0)
	var cx := X0
	for i in F.size():
		var f: Array = F[i]
		var cw: float = W[i]
		var k := String(f[0])
		var on := cur == k
		var hi := String(f[2]) != ""
		var tw: float = Box.text_w(String(f[1]), 11.0, 800) + 1.0
		var gx := cx + (cw - tw - (19.0 if hi else 0.0)) * 0.5
		var kk := []
		if hi:
			kk.append(_icn(maxf(cx + 11.0, gx + 8.0), y + 12.0, 15.0, String(f[2])))
			gx = maxf(cx + 19.0, gx + 19.0)
		var aw := cx + cw - 3.0 - gx
		var col := "rgb(255, 255, 255)" if on else BROWN
		kk.append(_dt(gx, y, aw, 24.0, _fitw(String(f[1]), 11.0, 800, aw), 11.0, 800, col, "left"))
		var fc: Dictionary
		if on:
			fc = _onbtn(cx, y, cw, 24.0, "", null)
		else:
			fc = _chip(cx, y, cw, 24.0, "tre" if k == "?" else "fut", true)
			fc.act = cb.bind(k)
		fc.kids = kk
		out.append(fc)
		cx += cw + 6.0
	return [out, 24.0]
