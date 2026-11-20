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
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if has_method("_sig") and call("_sig") != sig:
		_build()

# khung Kho: L = [[khóa, chữ, chấm?]] hàng tab (rỗng = không tab, thân lên đỉnh thẻ). Trả [khung, vùng thân, đỉnh thân]; _hb = cao thân
func _kshell(L: Array, cur: String, go: Callable) -> Array:
	var n := _cl(SB)
	var card := _find(n, "khcard")
	var tabs := _find(n, "bk2tabs")
	var vt := _find(n, "bk2v")
	var ty0 := float(_find(n, "bk2top").r[1])   # bỏ đầu bảng danh hiệu của Sổ làng
	card.kids = card.kids.filter(func(k): return not String(k.get("cls", "")).contains("bk2top") and (L.size() or not String(k.get("cls", "")).contains("bk2tabs")))
	var vy := ty0
	if L.size():
		_mv(tabs, float(tabs.r[0]), ty0)
		vy = ty0 + float(tabs.r[3]) + 6.0
		var bd := _cl(ST.ttdot)
		bd.text = "1"
		_seg_tabs(tabs, L, cur, go, bd)
	var vb := float(vt.r[1]) + float(vt.r[3])
	vt.r = [vt.r[0], vy, vt.r[2], vb - vy]
	_hb = float(vt.r[3])
	return [n, vt, vy]

func _kmount(n: Dictionary, vt: Dictionary, vy: float, kids: Array, ch: float) -> void:
	for k in kids:
		Snap._move(k, Vector2(0, vy))
	_mount(n, vt, kids, vy, minf(ch, _hb), 0.0)   # nội dung xếp vừa thân: không cho cuộn lố vài đơn vị
	U._layout()

func _hd(y: float, t: String) -> Array:   # tiêu đề phần kiểu Sổ làng: chữ đậm + gạch ngang tới mép phải
	var tw: float = Box.text_w(t, 12.0, 800) + 6.0
	return [_dt(X0 + 2.0, y, tw, 16.0, t, 12.0, 800, BROWN, "left"), _dbx(X0 + 2.0 + tw + 6.0, y + 8.0, XW - tw - 12.0, 1.0, "rgb(222, 204, 164)", 0.0)]

func _fitw(s: String, fs: float, fw: int, w: float) -> String:   # cắt chữ thêm "…" cho vừa bề ngang
	if Box.text_w(s, fs, fw) <= w:
		return s
	while s.length() > 1 and Box.text_w(s + "…", fs, fw) > w:
		s = s.substr(0, s.length() - 1)
	return s.strip_edges() + "…"

# ------------------------------------------------------------------ khối dựng tay (bản 386): tọa độ cuối (khung Kho), y tính từ đỉnh thân
const X0 := 16.5      # mép trái nội dung (như thẻ trong Kho / Sổ làng)
const XW := 305.0     # rộng nội dung
const BROWN := "rgb(74, 52, 20)"
const SUB := "rgb(128, 98, 58)"
const GOLD := "rgb(222, 160, 40)"
const GREEN := "rgb(46, 150, 80)"
var _hb := 455.0      # cao thân (tính ở _build theo khung Kho)

func _dz() -> float:
	return float(D.cal.kids[0].get("z", 0.75))

func _cpx(v: float) -> String:   # đơn vị số đo -> px css của mẫu (nhân z lúc vẽ)
	return str(snappedf(v / _dz(), 0.01)) + "px"

func _dt(x: float, y: float, w: float, h: float, s: String, fs := 11.0, fw := 700, col := BROWN, al := "center") -> Dictionary:
	var n := _cl(D.cal.kids[0])
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
	var n := _cl(D.cell.fut)
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
	"fut": ["rgb(250, 242, 222)", "rgb(252, 247, 234)", "rgb(255, 252, 245)", "rgba(150, 112, 48, 0.55)"],
	"got": ["rgb(196, 232, 184)", "rgb(208, 238, 198)", "rgb(222, 244, 214)", "rgb(76, 160, 70)"],
	"now": ["rgb(255, 226, 140)", "rgb(255, 236, 170)", "rgb(255, 245, 205)", "rgb(214, 150, 20)"],
	"miss": ["rgb(200, 196, 186)", "rgb(208, 204, 195)", "rgb(218, 215, 207)", "rgb(145, 137, 123)"],
	"tre": ["rgb(226, 196, 128)", "rgb(233, 206, 144)", "rgb(240, 218, 165)", "rgb(150, 108, 40)"],   # dải thứ: nâu vàng
	"sen": ["rgb(250, 210, 210)", "rgb(252, 222, 222)", "rgb(254, 234, 234)", "rgb(214, 120, 128)"],
}
func _chip(x: float, y: float, w: float, h: float, kind: String) -> Dictionary:
	# góc bo, viền trong, vệt sáng, bóng: lấy nguyên chip chung (Snap.chip_look); chỉ thay nền + màu viền theo trạng thái
	var C: Array = CHIPK[kind]
	var n := _dbx(x, y, w, h, "rgba(0, 0, 0, 0)")
	n.cls = "ddchip"
	Snap.chip_look(n, "ddchip", true)
	n.css["background-color"] = String(C[1])
	n.css["background-image"] = "linear-gradient(" + String(C[0]) + " 0%, " + String(C[1]) + " 50%, " + String(C[2]) + " 100%)"
	var sh := String(n.css["box-shadow"])
	sh = String(C[3]) + sh.substr(sh.find(")") + 1)   # màu viền trong (lớp bóng đầu)
	if kind == "now":
		sh = sh.replace("0px 0px 0px 1px inset", "0px 0px 0px 1.5px inset")
	var L := sh.split(") 0px 1px 2px 0px")   # bỏ lớp bóng đổ mờ dưới chip (lớp cuối, không inset)
	if L.size() > 1:
		sh = L[0].substr(0, L[0].rfind(", "))
	n.css["box-shadow"] = sh
	return n

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
	if red:
		n.css["background-image"] = "linear-gradient(rgb(196, 62, 48) 0%, rgb(204, 68, 52) 50%, rgb(216, 82, 62) 100%)"
		n.css["box-shadow"] = String(n.css["box-shadow"]).replace("rgb(63, 116, 41)", "rgb(140, 38, 28)").replace("rgba(150, 215, 130, 0.45)", "rgba(255, 170, 150, 0.45)").replace("rgba(10, 55, 10, 0.2)", "rgba(80, 10, 5, 0.2)").replace("rgba(30, 70, 20, 0.32)", "rgba(80, 20, 10, 0.32)")
	n.kids = [_dt(x, y, w, h, t, 12.5, 800, "rgb(255, 255, 255)")]
	if cb is Callable:
		n.act = cb
	return n

# hình quà vẽ trong khung 64 mà độ đầy khác nhau (đồng xu nhỏ, hộp quà to): phóng theo loại cho cùng cỡ nhìn
const ICK := {"coin": 1.35, "pearl": 1.08, "crate": 1.0, "bua": 1.0, "che": 0.9, "gift": 0.8}
func _dick(cx: float, cy: float, s: float, ic: String, op := 1.0) -> Dictionary:   # hình quà loại ic, tâm (cx, cy)
	var svg: String = D.ic[ic] if D.ic.has(ic) else String(D.ddms.kids[1].kids[3].kids[0].svg)
	var z := s * float(ICK.get(ic, 1.0))
	return _dic(cx - z * 0.5, cy - z * 0.5, z, svg, op)

func _dic(x: float, y: float, s: float, svg: String, op := 1.0) -> Dictionary:
	var n := _cl(D.cell.fut.kids[1])
	n.r = [x, y, s, s]
	n.svg = svg
	n.css = n.css.duplicate()
	n.css["opacity"] = str(op)
	return n

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

func _dsay(s: String) -> void:
	G.toast.emit(s)

