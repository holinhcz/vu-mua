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
	_mount(n, vt, kids, vy, ch if ch > _hb + 8.0 else minf(ch, _hb), 0.0)   # lố vài đơn vị thì không cho cuộn; dài hẳn thì cuộn
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
	"fut": ["rgb(250, 242, 222)", "rgb(252, 247, 234)", "rgb(255, 252, 245)", "rgba(150, 112, 48, 0.55)"],
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

func _chip(x: float, y: float, w: float, h: float, kind: String) -> Dictionary:
	# góc bo, viền trong, vệt sáng, bóng: lấy nguyên chip chung (Snap.chip_look); chỉ thay nền + màu viền theo trạng thái
	var C: Array = _ck(kind)
	var n := _dbx(x, y, w, h, "rgba(0, 0, 0, 0)")
	n.cls = "ddchip"
	var ck := ",".join(PackedStringArray(C)) + ("|now" if kind == "now" else "")
	if _CKC.has(ck):   # (bản 475) nhớ kiểu chip theo màu: bớt xử lý chuỗi khi dựng bảng nhiều chip (Làm thuê 40 nhà)
		n.css = (_CKC[ck] as Dictionary).duplicate()
		return n
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
	_CKC[ck] = n.css.duplicate()
	return n

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
	var n: Dictionary = D.cell.fut.kids[1].duplicate(false)   # (bản 475) chép nông
	n.kids = []
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

func _btn(x: float, y: float, w: float, h: float, t: String, cb, kind := "go") -> Dictionary:   # go: chip xanh Kho, red: đỏ, off: xám
	if kind == "off":
		var c := _chip(x, y, w, h, "miss")
		c.kids = [_dt(x, y, w, h, t, 10.5, 700, "rgb(110, 104, 92)")]
		return c
	var b := _onbtn(x, y, w, h, t, cb, kind == "red")
	b.kids[0].css["font-size"] = _cpx(11.0)
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

func _sect(y: float, t: String, col: String) -> Array:   # tiêu đề phần: vạch màu tab + chữ đậm
	var tw: float = Box.text_w(t, 12.0, 800) + 6.0
	return [_dbx(X0, y + 2.0, 3.0, 13.0, col, 1.5), _dt(X0 + 8.0, y, tw, 16.0, t, 12.0, 800, BROWN, "left"),
		_dbx(X0 + 8.0 + tw + 6.0, y + 8.0, XW - tw - 20.0, 1.0, "rgb(222, 204, 164)", 0.0)]

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
		var s0: String = G.fmt_n(mini(int(it[2]), 99999)) + "/" + G.fmt_n(int(it[3]))
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
	for i in list.size():
		var it: Array = list[i]
		var id := String(it[0])
		var nm := String(it[1])
		var hv := int(it[2])
		var q := int(it[3])
		var good := hv >= q
		ok = ok and good
		var s: String = G.fmt_n(mini(hv, 99999)) + "/" + G.fmt_n(q)
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
		var th0 := 15.0 + (16.0 if String(o.get("s", "")) != "" else 0.0)
		while L2.size() and th0 + L2.size() * 13.0 + 3.0 > bh - 10.0:   # chip thấp: bớt dòng 3, dòng cuối cắt "…"
			var last: String = String(L2[L2.size() - 1])
			L2.pop_back()
			if L2.size():
				L2[L2.size() - 1] = _fitw(String(L2[L2.size() - 1]) + " " + last, 10.0, 600, tw)
		var th := th0 + L2.size() * 13.0 + (3.0 if L2.size() else 0.0)
		var ty := yy + 6.0 if not big else yy + (bh - th) * 0.5
		ks.append(_dt(tx, ty, tw, 15.0, _fitw(String(o.b), 11.5, 800, tw), 11.5, 800, "rgb(120, 112, 98)" if dim else BROWN, "left"))
		ty += 16.0
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
func _bar(x: float, y: float, w: float, f: float, h := 5.0, trk := TRACK) -> Array:   # thanh tiến độ: màu chạy từ đỏ (mới bắt đầu) qua vàng tới xanh (đủ)
	var out := [_dbx(x, y, w, h, trk, h * 0.5)]
	out.append(_dbx(x, y, maxf(h, w * clampf(f, 0.0, 1.0)), h, _fcol(f), h * 0.5))   # (bản 481) lúc 0 vẫn có chấm đỏ đầu thanh
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
		var xs: String = (String(W.CO.get(e.job, e.job)) + (" · " + String(W._ae(e.jr).get("name", "")).to_lower() if W._tr(e.get("jr")) else "") + " · " + str(W.om(e, e.job)) + " xu/phút") if xj else (str(o.size()) + " xưởng · chọn xưởng")
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
