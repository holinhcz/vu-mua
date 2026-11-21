extends "res://logic/ui_kbang.gd"
# BẢNG NHÀ DÂN (a4 bản web, $r.mode === "nha"): chạm vô nhà dân trên làng. (bản 433) làm lại trên khung Kho + chip chung (ui_kbang.gd).
# Đầu bảng (không thẻ): mặt người, tên + chip tính nết, 5 tim (hình) + thanh thân, chip nhà / họ / đang làm, bong bóng câu nói,
# 2 nút chip Trò chuyện (xanh) / Tặng quà (đỏ). 4 tab: Việc nhà · Thuê làm · Mua giống · Sở trường, khối nào cũng là chip nổi.
# Trò chuyện, tặng quà: hộp nổi đè lên bảng (lớp tối + hộp chip), không thay thân bảng.
# Luật (trò chuyện, tặng quà, đưa đồ, thuê làm, học nghề...) ở w_lang.gd.

var W          # w_lang.gd
var WC         # w_cho.gd (giống nhà hàng xóm)

var u := -1
var tab := ""               # $r.tab
var sub := ""               # $r.sub: "" | "chat" | "gift" (hộp nổi)
var cv = null               # $r.cv (trò chuyện)
var pick := ""              # (bản 441) tab Thuê làm: lưới đang mở ("" | "ruong" giống | "xuong" xưởng | "mon" món xưởng), mỗi lúc một lưới

func _pk(k: String) -> void:   # chạm chip Làm ruộng / Làm xưởng: mở lưới của nó (chạm lại thì đóng)
	pick = "" if pick == k else k

func _job0(m: String) -> void:   # Nghỉ / vườn / chuồng: giao ngay, đóng lưới
	pick = ""
	W.n4(u, m)

func _seed(id: String) -> void:   # chọn giống: lúc này mới giao Làm ruộng rồi gieo giống đó
	var f = W._fam_of(u)
	if f == null:
		return
	if f.get("job") != "ruong":
		W.n4(u, "ruong")
		if f.get("job") != "ruong":   # không giao được (thiếu tiền, đủ người): giữ lưới
			return
	W.jq(u, id)
	pick = ""

func _xw_pick(m: String) -> void:   # chọn xưởng: giao việc, rồi mở lưới món của xưởng đó
	W.n4(u, m)
	var f = W._fam_of(u)
	if f != null and f.get("job") == m:
		pick = "mon"

func _mon(id: String) -> void:
	W.set_jr(u, id)
	pick = ""

const HEART := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M12 21s-7.5-4.6-9.6-9.1C.9 8.6 3 5 6.6 5c2.1 0 3.6 1.1 4.4 2.5h2C13.8 6.1 15.3 5 17.4 5 21 5 23.1 8.6 21.6 11.9 19.5 16.4 12 21 12 21z\" fill=\"rgb(226,64,72)\" stroke=\"rgb(170,36,44)\" stroke-width=\"1.2\"/></svg>"
const HEART0 := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M12 21s-7.5-4.6-9.6-9.1C.9 8.6 3 5 6.6 5c2.1 0 3.6 1.1 4.4 2.5h2C13.8 6.1 15.3 5 17.4 5 21 5 23.1 8.6 21.6 11.9 19.5 16.4 12 21 12 21z\" fill=\"rgb(250,236,230)\" stroke=\"rgb(214,150,150)\" stroke-width=\"1.4\"/></svg>"
static func _heartp(p: float) -> String:   # tim đầy p phần (tô đỏ từ trái sang)
	var w := snappedf(clampf(p, 0.0, 1.0) * 24.0, 0.1)
	var path := "M12 21s-7.5-4.6-9.6-9.1C.9 8.6 3 5 6.6 5c2.1 0 3.6 1.1 4.4 2.5h2C13.8 6.1 15.3 5 17.4 5 21 5 23.1 8.6 21.6 11.9 19.5 16.4 12 21 12 21z"
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><defs><clipPath id=\"c\"><rect x=\"0\" y=\"0\" width=\"" + str(w) + "\" height=\"24\"/></clipPath></defs><path d=\"" + path + "\" fill=\"rgb(250,236,230)\" stroke=\"rgb(214,150,150)\" stroke-width=\"1.4\"/><path clip-path=\"url(#c)\" d=\"" + path + "\" fill=\"rgb(226,64,72)\"/><path d=\"" + path + "\" fill=\"none\" stroke=\"rgb(190,80,90)\" stroke-width=\"1.2\"/></svg>"

const LOCK := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M7 10V7.5a5 5 0 0 1 10 0V10\" fill=\"none\" stroke=\"rgb(128,98,58)\" stroke-width=\"2.4\"/><rect x=\"4.5\" y=\"10\" width=\"15\" height=\"11\" rx=\"2.5\" fill=\"rgb(214,170,90)\" stroke=\"rgb(128,98,58)\" stroke-width=\"1.4\"/></svg>"
const QMARK := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><circle cx=\"12\" cy=\"12\" r=\"10\" fill=\"rgb(232,222,200)\" stroke=\"rgb(190,170,130)\" stroke-width=\"1.4\"/><path d=\"M9.2 9.3a2.9 2.9 0 1 1 4.3 2.5c-.9.5-1.5 1.1-1.5 2.2\" fill=\"none\" stroke=\"rgb(150,120,70)\" stroke-width=\"2.2\" stroke-linecap=\"round\"/><circle cx=\"12\" cy=\"17.4\" r=\"1.3\" fill=\"rgb(150,120,70)\"/></svg>"
const TAIL := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 12 10\"><path d=\"M0 0 L12 0 L4 10 Z\" fill=\"rgb(252,247,234)\" stroke=\"rgba(150,112,48,0.55)\" stroke-width=\"0.8\"/></svg>"
const TAILB := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 11 11\"><path d=\"M11 1 L1 10 L11 7 Z\" fill=\"rgb(224,238,250)\"/><path d=\"M10.4 1.4 L1 10 L10.4 7.2\" fill=\"none\" stroke=\"rgb(96,146,196)\" stroke-width=\"1\" stroke-linejoin=\"round\"/></svg>"   # đuôi bong bóng nhà dân, chỉ sang mặt
const TAILG := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 11 11\"><path d=\"M0 1 L10 10 L0 7 Z\" fill=\"rgb(208,238,198)\"/><path d=\"M0.6 1.4 L10 10 L0.6 7.2\" fill=\"none\" stroke=\"rgb(76,160,70)\" stroke-width=\"1\" stroke-linejoin=\"round\"/></svg>"   # đuôi bong bóng mình
const TALIC := {"ruong": "lua", "vuon": "qua_xoai", "chan": "trung", "xuong": "gao"}   # hình sở trường (thay emoji)
const ICS := {"chieu": 1.2, "trung": 1.12, "gao": 1.08}   # hình thưa (dẹt / tròn nhỏ): phóng cho cùng cỡ nhìn
const JOBIC := {"": "chieu", "ruong": "lua", "vuon": "qua_xoai", "chan": "trung"}
# màu chip theo tính nết + màu theo tab: [gradient trên, giữa, dưới, viền]
const VLC := {
	"t_hien": ["rgb(250, 214, 226)", "rgb(252, 224, 234)", "rgb(254, 236, 242)", "rgb(206, 110, 140)"],
	"t_kho": ["rgb(214, 222, 236)", "rgb(224, 230, 242)", "rgb(236, 240, 248)", "rgb(100, 120, 160)"],
	"t_vui": ["rgb(255, 222, 170)", "rgb(255, 230, 190)", "rgb(255, 240, 214)", "rgb(214, 140, 40)"],
	"t_khac": ["rgb(228, 214, 244)", "rgb(234, 222, 248)", "rgb(242, 234, 252)", "rgb(138, 104, 186)"],
	"viec": ["rgb(255, 236, 176)", "rgb(255, 242, 198)", "rgb(255, 248, 220)", "rgb(214, 160, 30)"],
	"thue": ["rgb(190, 228, 160)", "rgb(202, 234, 176)", "rgb(216, 240, 194)", "rgb(60, 140, 40)"],   # đang chọn: xanh đậm hơn nền nhóm
	"j_ruong": ["rgb(232, 246, 220)", "rgb(238, 249, 228)", "rgb(244, 252, 238)", "rgb(150, 196, 120)"],   # (bản 439) nhóm việc thuê: nền nhạt
	"j_vuon": ["rgb(255, 240, 214)", "rgb(255, 244, 224)", "rgb(255, 249, 236)", "rgb(222, 176, 110)"],
	"j_chan": ["rgb(252, 230, 214)", "rgb(253, 236, 224)", "rgb(254, 243, 236)", "rgb(214, 156, 116)"],
	"j_xuong": ["rgb(238, 230, 248)", "rgb(242, 236, 250)", "rgb(247, 243, 252)", "rgb(170, 146, 206)"],
	"giong": ["rgb(226, 242, 206)", "rgb(232, 246, 216)", "rgb(240, 250, 230)", "rgb(120, 170, 80)"],
	"s_ruong": ["rgb(222, 242, 204)", "rgb(230, 246, 216)", "rgb(240, 250, 230)", "rgb(110, 170, 70)"],   # (bản 442) màu khối sở trường theo nghề
	"s_vuon": ["rgb(255, 232, 196)", "rgb(255, 238, 210)", "rgb(255, 246, 228)", "rgb(220, 150, 50)"],
	"s_chan": ["rgb(250, 222, 200)", "rgb(252, 230, 212)", "rgb(254, 240, 228)", "rgb(200, 130, 80)"],
	"s_xuong": ["rgb(232, 220, 246)", "rgb(238, 228, 250)", "rgb(244, 238, 252)", "rgb(138, 104, 186)"],
	"nghe": ["rgb(244, 230, 196)", "rgb(248, 238, 210)", "rgb(252, 246, 228)", "rgb(176, 136, 70)"],
	"tal": ["rgb(232, 220, 246)", "rgb(238, 228, 250)", "rgb(244, 238, 252)", "rgb(138, 104, 186)"],
	"nan": ["rgb(250, 210, 210)", "rgb(252, 222, 222)", "rgb(254, 234, 234)", "rgb(214, 120, 128)"],
}
const GG := 10.0   # khoảng cách đều giữa tiêu đề phần và khối, giữa các khối
const TABC := {"viec": "rgb(214, 160, 30)", "thue": "rgb(76, 150, 48)", "giong": "rgb(110, 160, 70)", "tal": "rgb(132, 96, 190)"}

func _ck(kind: String) -> Array:
	return VLC[kind] if VLC.has(kind) else super(kind)

func _init(ui, wl, wc) -> void:
	super(ui)
	W = wl
	WC = wc

# ------------------------------------------------------------------ mở / đóng
func open(uu: int) -> void:   # gu("nha", u)
	if W._fam_of(uu) == null or W.r1(uu) == null:
		return
	on = true
	u = uu
	tab = ""
	sub = ""
	pick = ""
	cv = null
	scroll = 0.0
	sig = ""
	_build()

func close() -> void:   # i1
	cv = null
	sub = ""
	super()

func step(dt: float) -> void:
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 0.25
	if W._fam_of(u) == null or W.r1(u) == null:
		close()
		return
	if _sig() != sig:
		_build()

func _sig() -> String:
	var f = W._fam_of(u)
	var t = f.get("tt")
	return JSON.stringify([f, tab, sub, cv, pick, G.g.coins, G.g.barn, W.tg().get("ev"), G.g.get("cuoi"), G.g.get("hn"), G.g.get("nghe"), G.night,
		int(G._now_ms() / 1000.0) if W._tr(t) else 0, W._vr()])

func _tab_go(k: String) -> void:   # data-vt
	if tab != k:
		tab = k
		pick = ""
		scroll = 0.0

# ------------------------------------------------------------------ dựng
func _build() -> void:
	var f = W._fam_of(u)
	if f == null:
		close()
		return
	sig = _sig()
	var L := _tabs(f)
	var sh := _kshell([] if sub != "" else L, tab, _tab_go)   # hộp nổi mở: bỏ hàng tab, hộp che luôn chỗ tab
	var n: Dictionary = sh[0]
	var vt: Dictionary = sh[1]
	var card := _find(n, "khcard")
	var y0 := float(sh[2]) if sub != "" else float(_find(n, "bk2tabs").r[1])
	var hd := _head(f, y0)
	var hh: float = hd[1]
	if sub == "":
		Snap._move(_find(n, "bk2tabs"), Vector2(0, hh))   # đầu bảng chiếm chỗ trên hàng tab
	vt.r = [vt.r[0], float(vt.r[1]) + hh, vt.r[2], float(vt.r[3]) - hh]
	_hb -= hh
	card.kids.append_array(hd[0])
	n["_nt"] = G.night   # mặt người đổi ngày / đêm: dựng lại khung
	var r: Array = _body(f)
	if sub != "":   # hộp nổi trò chuyện / tặng quà: lớp tối + hộp đè lên thân bảng (thân đứng yên, không cuộn)
		scroll = 0.0
		r = [_pop(f, 0.0, _hb, vt), _hb]
	_kmount(n, vt, float(sh[2]) + hh, r[0], float(r[1]))

# ------------------------------------------------------------------ khối chung
func _icn(cx: float, cy: float, s: float, id: String) -> Dictionary:   # hình món Kho (không khung)
	var b := _dbx(cx - s * 0.5, cy - s * 0.5, s, s, "rgba(0, 0, 0, 0)", 0.0)
	b.ic = id
	return b

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

static func _cap(t: String) -> String:   # chữ đầu viết hoa ("đem ra chợ huyện" -> "Đem ra chợ huyện")
	return t.substr(0, 1).to_upper() + t.substr(1)

func _lockc(x: float, y: float, n: int) -> Dictionary:   # chip khóa thân: (bản 452) "Cần N" + hình tim, canh giữa
	var lb := _chip(x, y, 84.0, 26.0, "sen")   # (bản 444) nền hồng hợp hình tim
	var P := ["Cần " + str(n), "h"]
	var w0 := float(_rowi(0.0, 0.0, 26.0, P, 10.5, 700, "")[1])
	lb.kids = _rowi(x + (84.0 - w0) * 0.5, y, 26.0, P, 10.5, 700, "rgb(170, 50, 60)")[0]
	return lb

func _rowi(x: float, y: float, h: float, parts: Array, fs: float, fw: int, col: String) -> Array:   # (bản 452) dòng chữ xen hình: "h" tim, "s" sao, "c" xu; trả [khối, rộng]
	var out := []
	var cx := x
	var z := fs + 3.0
	for pt in parts:
		var t := String(pt)
		if t == "h" or t == "s" or t == "c":
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

# hàng món cần: [[món, cần]] -> chip nhỏ: hình + "có/cần" (xanh đủ, đỏ thiếu); trả [khối, cao, đủ hết]
func _needs(x: float, y: float, w: float, list: Array) -> Array:
	var out := []
	var cx := x
	var cy := y
	var ok := true
	# (bản 451) mỗi chip dài theo tên; không lọt 1 hàng thì thu đều cho vừa (tên dài bóp chữ nhỏ), thu quá nhỏ mới xuống hàng
	var cws := []
	var sm := 0.0
	for it in list:
		var nm0 := String(W._ae(String(it[0])).get("name", it[0]))
		var s0: String = G.fmt_n(mini(W._barn(String(it[0])), 99999)) + "/" + G.fmt_n(int(it[1]))
		var cw0: float = minf(38.0 + maxf(Box.text_w(nm0, 10.0, 700), Box.text_w(s0, 10.5, 800)) + 8.0, w)
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
	for i in list.size():
		var it: Array = list[i]
		var id := String(it[0])
		var q := int(it[1])
		var hv: int = W._barn(id)
		var good := hv >= q
		ok = ok and good
		var s: String = G.fmt_n(mini(hv, 99999)) + "/" + G.fmt_n(q)
		var nm := String(W._ae(id).get("name", id))   # (bản 435) chip 2 dòng: tên món trên, có/cần dưới
		var cw: float = cws[i]
		var tw := cw - 40.0
		var fs := clampf(10.0 * tw / maxf(1.0, Box.text_w(nm, 10.0, 700)), 8.5, 10.0)
		if cx > x and cx + cw > x + w:
			cx = x
			cy += 40.0
		var c := _chip(cx, cy, cw, 34.0, "got" if good else "sen")
		c.kids = [_icn(cx + 18.0, cy + 17.0, 28.0, id), _dt(cx + 36.0, cy + 3.0, tw, 14.0, _fitw(nm, fs, 700, tw), fs, 700, BROWN, "left"),
			_dt(cx + 36.0, cy + 17.0, cw - 40.0, 14.0, s, 10.5, 800, "rgb(46, 120, 50)" if good else "rgb(190, 60, 50)", "left")]
		c.act = _dsay.bind(String(W._ae(id).get("name", id)) + ": kho có " + G.fmt_n(hv) + ", cần " + G.fmt_n(q) + ".")
		out.append(c)
		cx += cw + 5.0
	return [out, cy + 34.0 - y if list.size() else 0.0, ok]

# ------------------------------------------------------------------ đầu bảng
func _vs(f: Dictionary) -> String:   # _vS
	var j = f.get("job")
	if j == "ruong":
		return "Đang làm ruộng · " + str(W.ux(u).size()) + " ô"
	if j == "vuon":
		return "Đang làm vườn"
	if j == "chan":
		return "Đang chăm chuồng"
	if W._tr(j):
		return "Đang làm " + String(W.CO.get(j, j)).to_lower() + (" · " + String(W._ae(f.jr).get("name", "")).to_lower() if W._tr(f.get("jr")) else "")
	return "Đang ở nhà"

func _yd() -> Dictionary:   # yD: tên loại nhà
	if not has_meta("yd"):
		set_meta("yd", G._j("xay_dung/ten_nha_o") if G._j("xay_dung/ten_nha_o") is Dictionary else {})
	return get_meta("yd")

func _head(f: Dictionary, y0: float) -> Array:   # [khối, cao]
	var out := []
	var fs := 52.0
	var fc := _chip(X0, y0, fs, fs, "fut")
	var lk := clampi(W._i(f.get("lk")), 0, 7)
	fc.kids = [_pic(X0 + 3.0, y0 + 3.0, fs - 6.0, fs - 6.0, "res://ui/img/vlface/" + str(lk) + ("n" if G.night else "") + ".webp")]
	out.append(fc)
	var x := X0 + fs + 10.0
	var xr := X0 + XW
	# tên + tính nết
	var TT: Dictionary = W.tinh_of(f)
	var tk := String(f.get("tp", ""))
	var nm := String(f.n)
	# (bản 438) hàng tên: tên + chip tính nết + chip họ (chạm mở Gia phả)
	var ho := ("Họ " + String(f.ho) + " ›") if W._tr(f.get("ho")) else ""
	var tcw: float = Box.text_w(String(TT.n), 10.0, 700) + 14.0
	var hcw: float = (Box.text_w(ho, 10.0, 700) + 14.0) if ho != "" else 0.0
	var nw: float = minf(Box.text_w(nm, 14.0, 800) + 2.0, xr - x - tcw - hcw - 16.0)
	out.append(_dt(x, y0, nw, 20.0, _fitw(nm, 14.0, 800, nw), 14.0, 800, BROWN, "left"))
	var tc := _tchip(x + nw + 8.0, y0 + 1.0, String(TT.n), "t_" + tk if VLC.has("t_" + tk) else "t_khac", BROWN, _dsay.bind(String(TT.n) + ": " + String(TT.d)))
	out.append(tc[0])
	if ho != "":
		out.append(_tchip(x + nw + 8.0 + float(tc[1]) + 5.0, y0 + 1.0, ho, "info", "rgb(52, 92, 140)", U.gp_open.bind(u))[0])
	# tim + thân
	var tim: int = W._i(f.get("tim"))
	# (bản 444) bỏ thanh thân: tim đang lên đầy dần từ trái sang theo thân (như thanh cũ), giữ chữ "Thân N/5"
	var hy := y0 + 21.0   # (bản 449) tim to 20 cho thấy rõ tim đang đầy dở
	var p := 1.0 if tim >= 5 else fmod(W._n(f.get("dp")), 100.0) / 100.0
	for i in 5:
		out.append(_dic(x + i * 22.0, hy, 20.0, HEART if i < tim else (_heartp(p) if i == tim and p > 0.0 else HEART0)))
	out.append(_dt(x + 5 * 22.0 + 6.0, hy + 1.0, 70.0, 18.0, "Thân " + str(tim) + "/5", 11.0, 700, "rgb(190, 60, 70)", "left"))
	# nhà · đang làm: chữ trơn (không chip)
	var r = W.r1(u)
	var rid := String(r.r.id)
	var cy := y0 + 44.0
	var hs := String(_yd().get(rid.trim_suffix("2"), "Nhà")) + " · " + str(int(W.CX.get(rid, 0))) + " người"
	var jb := _vs(f)
	var hsw: float = minf(Box.text_w(hs, 10.0, 700) + 2.0, xr - x)
	out.append(_dt(x, cy, hsw, 16.0, _fitw(hs, 10.0, 700, hsw), 10.0, 700, SUB, "left"))
	var jx := x + hsw + 4.0
	if jx + 30.0 < xr:
		out.append(_dt(jx, cy, xr - jx, 16.0, _fitw("· " + jb, 10.0, 700, xr - jx), 10.0, 700, "rgb(46, 120, 50)" if jb == "Đang ở nhà" else "rgb(176, 110, 20)", "left"))
	var y := maxf(y0 + fs, cy + 16.0) + 8.0
	# câu nói: chữ nghiêng, không khung
	var q: String = "“" + W.talk_line(f) + "”"
	var qL := _wrap(q, 11.0, 600, XW - 8.0)
	for i in qL.size():
		var qt := _dt(X0 + 4.0, y + i * 15.0, XW - 8.0, 15.0, qL[i], 11.0, 600, "rgb(120, 88, 50)", "left")
		qt.css["font-style"] = "italic"
		out.append(qt)
	y += qL.size() * 15.0 + 8.0
	# 2 nút
	var nl: int = W.chat_left(f)
	var gq: bool = W._i(f.get("gq", -1)) == W._vr()
	var hw := (XW - 8.0) * 0.5
	if sub == "chat":
		out.append(_btn(X0, y, hw, 28.0, "Đóng trò chuyện", _chat_go, "go"))
	else:
		out.append(_btn(X0, y, hw, 28.0, "Trò chuyện · còn " + str(nl) if nl else "Mai trò chuyện tiếp", _chat_go, "go" if nl else "off"))
	var x2 := "Tặng quà · ngày riêng x2" if W.is_ngay_rieng(u) and f.get("bk") is Dictionary and W._tr(f.bk.get("d")) else "Tặng quà · 1 món/ngày"
	out.append(_btn(X0 + hw + 8.0, y, hw, 28.0, "Đóng tặng quà" if sub == "gift" else ("Hôm nay tặng rồi" if gq else x2), _gift_go, "red" if sub == "gift" else ("off" if gq else "red")))
	y += 28.0 + 10.0
	return [out, y - y0]

func _chat_go() -> void:   # data-chat; bấm lại lúc đang mở: đóng hộp
	if sub == "chat":
		sub = ""
		cv = null
		return
	sub = ""
	var c = W.chat_start(u)
	if c != null:
		cv = c
		sub = "chat"

func _gift_go() -> void:   # data-gift -> giftOpen; bấm lại lúc đang mở: đóng hộp
	if sub == "gift":
		sub = ""
		return
	sub = ""
	cv = null
	var f = W._fam_of(u)
	if W._i(f.get("gq", -1)) == W._vr():
		G.toast.emit("Hôm nay tặng " + String(f.n) + " rồi, mai tặng tiếp nha.")
		return
	sub = "gift"

# ------------------------------------------------------------------ tab
func _tabs(f: Dictionary) -> Array:   # _vB: [khóa, chữ, chấm !]
	var pq_ok: bool = W._tr(f.get("pq")) and f.pq.it.all(func(o): return W._barn(o[0]) >= W._i(o[1]))
	var L := [["viec", "Việc nhà", (W._tr(f.get("req")) and W.r_ok(f.req)) or pq_ok], ["thue", "Thuê làm", false]]
	if WC != null and WC.bZ(u).size():
		L.append(["giong", "Mua giống", false])
	L.append(["tal", "Sở trường", false])
	var ks := L.map(func(z): return z[0])
	if not ks.has(tab):
		tab = L[0][0]
	return L

func _body(f: Dictionary) -> Array:   # [khối, cao]
	match tab:
		"thue":
			return _thue(f)
		"giong":
			return _giong(f)
		"tal":
			return _tal(f)
	return _viec(f)

# ------------------------------------------------------------------ tab Việc nhà
# khối việc: chip màu, tiêu đề, dòng phụ, hàng món cần, xu thưởng, nút
func _job(y: float, kind: String, t: String, s: String, list: Array, xu: int, lb: String, act, force := false) -> Array:
	var out := []
	var c := _chip(X0, y, XW, 10.0, kind)
	out.append(c)
	var x := X0 + 10.0
	var w := XW - 20.0
	var yy := y + 10.0   # (bản 446) cách đều: mép trên 10 · tiêu đề · 10 · hàng chip · 10 mép dưới
	var rt := ""
	if xu > 0:
		rt = "+" + W._sa(xu)
	var rw: float = (Box.text_w(rt, 11.5, 800) + 22.0) if rt != "" else 0.0
	var by0 := X0 + XW - 10.0 - 66.0   # mép trái nút
	var tw0: float = (w - 76.0) if lb != "" and list.size() else (w - rw)
	out.append(_dt(x, yy, tw0, 16.0, _fitw(t, 12.0, 800, tw0), 12.0, 800, BROWN, "left"))
	var xu_row := rt != "" and not (lb != "" and list.size())   # có nút + chip món: số xu nằm ngay trên nút, canh giữa nút (vẽ ở dưới)
	if xu_row:
		out.append(_dick(x + w - 8.0, yy + 8.0, 17.0, "coin"))
		out.append(_dt(x + w - rw, yy - 1.0, rw - 19.0, 18.0, rt, 12.5, 800, "rgb(40, 130, 50)", "right"))   # (bản 446) số xu thưởng: xanh lá đậm
	yy += 16.0 + (10.0 if list.size() and s == "" else 4.0)
	if s != "":
		var pp := _para(x, yy, w, s, 10.5, 600, SUB, 14.0)
		out.append_array(pp[0])
		yy += float(pp[1]) + (10.0 if list.size() else 6.0)
	var ok := true
	var ny := yy   # hàng chip món đầu: nút canh giữa hàng này
	if list.size():
		var nd := _needs(x, yy, w - 74.0 if lb != "" else w, list)
		out.append_array(nd[0])
		ok = nd[2]
		yy += float(nd[1]) + 10.0
	if lb != "":
		var by: float = ny + 4.0 if list.size() else yy
		if rt != "" and not xu_row:   # (bản 448) số xu ngay trên nút, canh giữa nút
			var xw0: float = Box.text_w(rt, 12.5, 800) + 4.0 + 16.0
			var xx := by0 + (66.0 - xw0) * 0.5
			out.append(_dt(xx, by - 20.0, xw0 - 18.0, 18.0, rt, 12.5, 800, "rgb(40, 130, 50)", "right"))
			out.append(_dick(xx + xw0 - 8.0, by - 11.0, 15.0, "coin"))
		out.append(_btn(X0 + XW - 10.0 - 66.0, by, 66.0, 26.0, lb, act, "go" if (ok or force) and act != null else "off"))
		if not list.size():
			yy += 32.0
	c.r[3] = yy - y
	return [out, yy - y]

func _viec(f: Dictionary) -> Array:   # _vT.viec; (bản 435) cách đều: tiêu đề -> khối GG, khối -> tiêu đề sau GG
	var out := []
	var y := 6.0
	var col: String = TABC.viec
	for b in _nan(y):
		out.append_array(b[0])
		y += float(b[1]) + GG
	if W._tr(f.get("pq")):
		out.append_array(_sect(y, "Việc riêng", col))
		y += 16.0 + GG
		var r := _job(y, "viec", String(f.pq.t), "", f.pq.it, int(f.pq.xu), "Giao", func(): W.iv(u))
		out.append_array(r[0])
		y += float(r[1]) + GG
	if W._tr(f.get("req")):
		var c: Dictionary = f.req
		out.append_array(_sect(y, "Nhà đang cần", col))
		y += 16.0 + GG
		var r := _job(y, "viec", _cap(String(c.why)), "", W._r_it(c), int(c.xu), "Đưa", func(): W.gb(u))
		out.append_array(r[0])
		y += float(r[1]) + GG
	else:
		var r := _idle(y, f)
		out.append_array(r[0])
		y += float(r[1]) + GG
	var ex := _dam(y + 16.0 + GG)
	if ex.size():
		out.append_array(_sect(y, "Đám tiệc", col))
		out.append_array(ex[0])
		y += 16.0 + GG + float(ex[1]) + GG
	ex = _cuoi(y + 16.0 + GG, f)
	if ex.size():
		out.append_array(_sect(y, "Cưới hỏi", col))
		out.append_array(ex[0])
		y += 16.0 + GG + float(ex[1]) + GG
	return [out, y]

func _idle(y: float, f: Dictionary) -> Array:   # nhà chưa cần gì: gợi ý món thích để tặng
	var Li: Dictionary = W.fam_likes(u)
	var k: Dictionary = f.get("bk") if f.get("bk") is Dictionary else {}
	var out := []
	var c := _chip(X0, y, XW, 10.0, "fut")
	out.append(c)
	var pp := _para(X0 + 10.0, y + 8.0, XW - 20.0, String(f.n) + " chưa cần gì. Lát nữa thế nào cũng nhờ bạn chuyện này chuyện kia.", 10.5, 600, BROWN)
	out.append_array(pp[0])
	var yy := y + 8.0 + float(pp[1]) + 6.0
	out.append(_dt(X0 + 10.0, yy, 110.0, 24.0, "Tặng quà họ thích:", 10.0, 700, SUB, "left"))
	var ix := X0 + 118.0
	for i in 2:
		var kn: bool = W._tr(k.get("b" if i else "a"))
		var id := String(Li.th[i])
		if kn:
			out.append(_icn(ix + 12.0, yy + 12.0, 22.0, id))
			out.append(_dt(ix + 26.0, yy, 70.0, 24.0, _fitw(String(W._ae(id).get("name", id)), 10.0, 700, 70.0), 10.0, 700, BROWN, "left"))
		else:
			out.append(_dic(ix + 2.0, yy + 2.0, 20.0, QMARK))
			out.append(_dt(ix + 26.0, yy, 70.0, 24.0, "chưa biết", 10.0, 600, SUB, "left"))
		ix += 92.0
	yy += 28.0
	c.r[3] = yy - y
	return [out, yy - y]

func _dam(y: float) -> Array:   # aU: đám tiệc nhà này
	var a = W.tg().get("ev")
	if not (a is Dictionary) or W._i(a.get("u")) != u:
		return []
	var nm: String = W.qm(a)
	if W._tr(a.get("done")):
		return _job(y, "fut", nm, "Bạn đã dự " + nm.to_lower() + ". Gia chủ cảm ơn lắm.", [], 0, "", null)
	if not W._tr(W.sg()):
		var e := int(floor(fmod(float(a.t0), 24.0)))
		var j0 := _job(y, "fut", nm, "Bắt đầu lúc " + ("0" if e < 10 else "") + str(e) + ":00. Tới giờ ghé lại dự nha.", [], 0, "", null)
		var lh := fposmod(fmod(float(a.t0), 24.0) - float(G.nv.hour()), 24.0)   # giờ làng còn tới đám
		var lt: String = "còn " + (str(int(lh)) + " giờ " if int(lh) else "") + str(int(fmod(lh, 1.0) * 60.0)) + " phút"
		var lw: float = Box.text_w(lt, 10.0, 700) + 14.0
		var lc := _chip(X0 + XW - 10.0 - lw, y + 7.0, lw, 20.0, "info")   # đếm ngược: chip xanh dương như Sổ nhiệm vụ
		lc.kids = [_dt(X0 + XW - 10.0 - lw, y + 7.0, lw, 20.0, lt, 10.0, 700, "rgb(52, 92, 140)")]
		j0[0].append(lc)
		return j0
	var r: int = W._v1()
	var out := []
	var j := _job(y, "viec", nm + " đang đãi khách", "Ngồi ăn đám thì phải có phong bì hay chút quà. Vắng mặt gia chủ sẽ trách.", [], 0, "", null)
	out.append_array(j[0])
	var yy := y + float(j[1]) - 2.0
	var bw := (XW - 20.0 - 8.0) / 3.0
	var L := [["Bì " + W._sa(W._rnd(100 * (1 + r))) + " xu", "nho", "go"], ["Bì " + W._sa(W._rnd(300 * (1 + r))) + " xu", "lon", "red"], ["Quà trong kho", "qua", "go"]]
	for i in 3:
		var t := String(L[i][1])
		out.append(_btn(X0 + 10.0 + i * (bw + 4.0), yy, bw, 26.0, String(L[i][0]), func(): W.yk(t), String(L[i][2])))
	yy += 34.0
	j[0][0].r[3] = yy - y
	return [out, yy - y]

func _cuoi(y: float, a: Dictionary) -> Array:   # AU: dạm hỏi
	var c = G.g.get("cuoi")
	if W._tr(c):
		if W._n(c.get("u")) == float(u):
			return _job(y, "t_hien", "Nhà sui gia", String(c.n) + " về làm " + ("vợ" if c.get("g") == "nu" else "chồng") + " bạn rồi.", [], 0, "", null)
		return []
	var n: Dictionary = W.n_r(u)
	if W._n(a.get("tim")) < 5:
		if W._n(a.get("tim")) >= 3:
			return _job(y, "fut", "Dạm hỏi " + String(n.n), "Nhà " + String(a.n) + " có " + String(n.n) + " chưa có gia đình. Thân đủ 5 tim thì có thể dạm hỏi.", [], 0, "", null)
		return []
	var e: Dictionary = W.b_s()
	return _job(y, "t_hien", "Dạm hỏi " + String(n.n), "Bưng mâm quả qua: đu đủ, trứng, 2 bánh phu thê và " + W._sa(e.xu) + " xu tiền dẫn cưới.",
		e.it.map(func(o): return [o[0], o[1]]), 0, "Xin cưới", func(): W.sk(u), false)

func _nan(y: float) -> Array:   # aU bọc: nhà đang gặp nạn (thiên tai) -> [[khối, cao]]
	var tn = G.g.get("tn")
	var nn = tn.nan.get(str(u)) if tn is Dictionary and tn.get("nan") is Dictionary else null
	if not (nn is Dictionary) or W._tr(nn.get("x")):
		return []
	var WD = W.WD
	var ch := []
	var tx := []
	for k in nn.need:
		if k == "xu" or k == "gach":
			var hv: int = WD._tn_hv(k)
			tx.append(W._sa(hv) + "/" + W._sa(nn.need[k]) + " " + String(WD.TNRES[k]))
		else:
			ch.append([String(k), int(nn.need[k])])
	var s: String = "Còn " + str(int(nn.d) + 3 - W._vr()) + " ngày. Giúp thì +60 thân, +8 uy tín." + (" Cần " + ", ".join(PackedStringArray(tx)) + "." if tx.size() else "")
	return [_job(y, "nan", "Gặp nạn: " + String(W.TNNAN.get(nn.k, "")).to_lower() + " sau " + String(WD.TNK[nn.k].n).to_lower(), s, ch, 0, "Giúp", func(): WD.tn_help(u), true)]

# ------------------------------------------------------------------ tab Thuê làm
# lưới chip: [{b, s, st: on/off/dis, act, ic}], cols cột; trả [khối, cao]
func _grid(y: float, bt: Array, cols: int, kind_on: String) -> Array:
	var out := []
	var g := 6.0
	var bw := (XW - (cols - 1) * g) / cols
	var bh := 44.0 if cols == 2 else 40.0
	for i in bt.size():
		var o: Dictionary = bt[i]
		var x := X0 + (i % cols) * (bw + g)
		var yy := y + floorf(i / float(cols)) * (bh + g)
		var st := String(o.st)
		var c := _chip(x, yy, bw, bh, kind_on if st == "on" else ("miss" if st == "dis" or st == "hint" else String(o.get("k", "fut"))))
		var ks := []
		var tx := x + 8.0
		if String(o.get("ic", "")) != "":   # (bản 447) hình cách đều 2 bên 8: tâm 21, cỡ 26 (phóng theo độ đầy hình), chữ từ 42
			ks.append(_icn(x + 21.0, yy + bh * 0.5, 26.0 * float(ICS.get(String(o.ic), 1.0)), String(o.ic)))
			tx = x + 42.0
		var tw := x + bw - 6.0 - tx
		var dim := st == "dis" or st == "hint"
		ks.append(_dt(tx, yy + 6.0, tw, 15.0, _fitw(String(o.b), 11.5, 800, tw), 11.5, 800, "rgb(120, 112, 98)" if dim else BROWN, "left"))
		if String(o.get("s", "")) != "":
			ks.append(_dt(tx, yy + 22.0, tw, 13.0, _fitw(String(o.s), 10.5, 600, tw), 10.5, 600, "rgb(130, 124, 112)" if dim else SUB, "left"))
		if st == "on":   # đang chọn: dấu tick góc phải
			ks.append(_dtick(x + bw - 17.0, yy + 5.0, 12.0))
		c.kids = ks
		if st != "dis" and o.has("act"):
			c.act = o.act
		out.append(c)
	var rows := int(ceil(bt.size() / float(cols)))
	return [out, rows * bh + maxf(0, rows - 1) * g]

func _thue(e: Dictionary) -> Array:   # _vT.thue
	var out := []
	var col: String = TABC.thue
	var y := 6.0
	out.append_array(_sect(y, "Thuê làm phụ", col))
	out.append(_dt(X0 + 2.0, y + 18.0, XW - 4.0, 13.0, "Trả công mỗi phút, càng thân càng rẻ, hết tiền thì nghỉ.", 10.0, 600, SUB, "left"))
	y += 38.0
	var s: Array = W.lm()
	var hh := maxi(1, int(ceil(W._gg().size() / 12.0)))
	var p: bool = e.get("job") == "ruong" or s.size() < hh
	var bt := []
	bt.append({"b": "Nghỉ ở nhà", "s": "Không tốn công", "ic": JOBIC[""], "st": "on" if not W._tr(e.get("job")) else "off", "act": _job0.bind("")})
	var cr := String(e.get("crop", ""))
	var rs: String = (("Gieo " + String(G.D.crops[cr].name).to_lower() if cr != "" and G.D.crops.has(cr) else "Giữ giống cũ") + " · " + str(W.om(e, "ruong")) + " xu/phút") if e.get("job") == "ruong" else ("Chọn giống · " + str(W.om(e, "ruong")) + " xu" if p else "Đủ người rồi")
	bt.append({"b": "Làm ruộng", "s": rs, "ic": JOBIC.ruong, "k": "j_ruong", "st": "on" if e.get("job") == "ruong" else ("off" if p else "dis"), "act": _pk.bind("ruong")})
	for M in ["vuon", "chan"]:
		var t: String = W.vg(M)
		var w: bool = e.get("job") == M
		var E := t != "" and not w
		var C: bool = W.yx(M)
		bt.append({"b": "Làm vườn" if M == "vuon" else "Chăm chuồng", "k": "j_" + M, "s": t + " đang làm" if E else (str(W.om(e, M)) + " xu/phút" if C else ("Chưa có cây" if M == "vuon" else "Chưa có con")),
			"ic": JOBIC[M], "st": "on" if w else ("dis" if E or (not C and not w) else "off"), "act": _job0.bind(M)})
	var o: Array = G.xw.N0.filter(func(k): return G.xw.built(k)).map(func(k): return W.jx(String(k)))   # mã việc thuê (Ruộng muối = "x_ruong")
	var xj: bool = o.has(e.get("job"))   # (bản 439) các xưởng gom 1 chip "Làm xưởng", chạm mở lưới chọn xưởng
	if o.size():
		var xs: String = (String(W.CO.get(e.job, e.job)) + (" · " + String(W._ae(e.jr).get("name", "")).to_lower() if W._tr(e.get("jr")) else "") + " · " + str(W.om(e, e.job)) + " xu/phút") if xj else (str(o.size()) + " xưởng · chọn xưởng")
		var xr: Array = G.xw.sr[W.xj(e.job)].rec if xj else []
		bt.append({"b": "Làm xưởng", "s": xs, "ic": String(xr[0]) if xr.size() else "gao", "k": "j_xuong", "st": "on" if xj else "off", "act": _pk.bind("xuong")})
	if o.is_empty():   # (bản 444) chưa có xưởng: chip mờ trong lưới, chạm hiện cách xây
		bt.append({"b": "Xưởng", "s": "Chưa xây", "ic": "gao", "st": "hint", "act": _dsay.bind("Xây xưởng (Xây dựng › Xưởng) rồi thuê người làm: xưởng tự thu hàng và làm tiếp món bạn chọn.")})
	var gr := _grid(y, bt, 2, "thue")
	out.append_array(gr[0])
	y += float(gr[1]) + 10.0
	if pick == "xuong" and o.size():   # lưới chọn xưởng
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
				"st": "on" if w else ("dis" if E else "off"), "act": _xw_pick.bind(mm)})
		var gx := _grid(y, xk, 2, "thue")
		out.append_array(gx[0])
		y += float(gx[1]) + 10.0
	if pick == "ruong":   # lưới chọn giống: chọn xong mới giao Làm ruộng
		out.append_array(_sect(y, "Gieo cây gì?", col))
		y += 22.0
		var pk := []
		for M in W.xq(e):
			var P: PackedStringArray = String(M.t).split(" · ")
			var id: String = M.id
			pk.append({"b": P[0], "s": " · ".join(P.slice(1)), "ic": id, "k": "j_ruong", "st": "on" if e.get("job") == "ruong" and String(e.get("crop", "")) == id else "off", "act": _seed.bind(id)})
		var g2 := _grid(y, pk, 2, "thue")
		out.append_array(g2[0])
		y += float(g2[1]) + 10.0
	if pick == "mon" and W._tr(e.get("job")) and e.job != "ruong" and G.xw.sr.has(W.xj(e.job)):   # món của xưởng vừa chọn
		var d: Dictionary = G.xw.sr[W.xj(e.job)]
		out.append_array(_sect(y, "Làm món gì?", col))
		y += 22.0
		var rk := []
		for M in d.rec:
			var id := String(M)
			rk.append({"b": String(W._ae(id).get("name", id)), "s": "" if G.xw.has_in(id) else "thiếu đồ", "ic": id, "k": "j_xuong", "st": "on" if e.get("jr") == id else "off", "act": _mon.bind(id)})
		var g3 := _grid(y, rk, 2, "thue")
		out.append_array(g3[0])
		y += float(g3[1]) + 10.0
	return [out, y]

# ------------------------------------------------------------------ tab Mua giống
func _giong(a: Dictionary) -> Array:   # jR: giống nhà hàng xóm để dư
	var out := []
	var y := 6.0
	out.append_array(_sect(y, "Giống nhà " + String(a.n) + " để dư", TABC.giong))
	out.append(_dt(X0 + 2.0, y + 18.0, XW - 4.0, 13.0, "Mỗi ngày mỗi thứ chỉ có chừng 6 hạt.", 10.0, 600, SUB, "left"))
	y += 38.0
	for e in WC.bZ(u):
		var id := String(e)
		var r := "h" + str(u) + "_" + id
		var o: int = WC.G6(r, 6)
		var l: int = WC.F6(id)
		var c := _chip(X0, y, XW, 48.0, "giong")
		var ks := [_icn(X0 + 24.0, y + 24.0, 30.0, id)]
		var tw := XW - 46.0 - 132.0
		ks.append(_dt(X0 + 46.0, y + 7.0, tw, 16.0, _fitw("Giống " + String(G.crop(id).name).to_lower(), 12.0, 800, tw), 12.0, 800, BROWN, "left"))
		ks.append(_dt(X0 + 46.0, y + 25.0, tw, 13.0, _fitw(W._sa(l) + " xu/hạt · còn " + str(o) + " · kho " + str(W._barn(id)), 10.5, 600, tw), 10.5, 600, SUB, "left"))
		c.kids = ks
		out.append(c)
		var ok1: bool = o > 0 and W._n(G.g.coins) >= l
		var ok3: bool = o >= 3 and W._n(G.g.coins) >= l * 3
		var k1 := r + "|" + id + "|1|" + str(l) + "|6"
		var k3 := r + "|" + id + "|3|" + str(l) + "|6"
		out.append(_btn(X0 + XW - 128.0, y + 11.0, 58.0, 26.0, "Mua 1", func(): WC.Um(k1), "go" if ok1 else "off"))
		out.append(_btn(X0 + XW - 64.0, y + 11.0, 58.0, 26.0, "Mua 3", func(): WC.Um(k3), "go" if ok3 else "off"))
		y += 48.0 + 6.0
	return [out, y]

# ------------------------------------------------------------------ tab Sở trường
func _tal(f: Dictionary) -> Array:   # tinhHtml + TALH + SU
	var out := []
	var col: String = TABC.tal
	var y := 4.0
	# tính nết: (bản 442) tiêu đề ghi tên tính, khối chỉ câu giải thích; thích / ghét / ngày riêng chưa biết gộp 1 dòng
	var TT: Dictionary = W.tinh_of(f)
	var tk := String(f.get("tp", ""))
	var Li: Dictionary = W.fam_likes(u)
	var k: Dictionary = f.get("bk") if f.get("bk") is Dictionary else {}
	out.append_array(_sect(y, "Tính nết: " + String(TT.n), col))
	y += 22.0
	var c := _chip(X0, y, XW, 10.0, "t_" + tk if VLC.has("t_" + tk) else "t_khac")
	out.append(c)
	var pp := _para(X0 + 10.0, y + 6.0, XW - 20.0, String(TT.d), 10.5, 600, BROWN, 15.0)   # (bản 452) mọi dòng cách đều 15
	out.append_array(pp[0])
	var yy := y + 6.0 + float(pp[1])
	var L := [["Thích", Li.th[0], k.get("a")], ["", Li.th[1], k.get("b")], ["Ghét", Li.gh, k.get("x")]]
	var any := false
	for it in L:
		any = any or W._tr(it[2])
	var nd: bool = W._tr(k.get("d"))
	if not any and not nd:
		out.append(_dt(X0 + 10.0, yy, XW - 20.0, 15.0, "Thích, ghét, ngày riêng: chưa biết.", 10.0, 600, SUB, "left"))
		out.append(_dt(X0 + 10.0, yy + 15.0, XW - 20.0, 15.0, _fitw("Trò chuyện, tặng quà để làm thân với " + String(f.n) + " nha.", 10.0, 600, XW - 20.0), 10.0, 600, SUB, "left"))
		yy += 36.0   # 2 dòng 15 + lề dưới 6 (bằng lề trên)
	else:
		if any:
			var ix := X0 + 10.0
			for it in L:
				if not W._tr(it[2]):
					continue
				if String(it[0]) != "" or ix == X0 + 10.0:
					var lb := (String(it[0]) if String(it[0]) != "" else "Thích") + ":"
					var lw: float = Box.text_w(lb, 10.0, 700) + 4.0
					out.append(_dt(ix, yy, lw, 24.0, lb, 10.0, 700, SUB, "left"))
					ix += lw
				var id := String(it[1])
				out.append(_icn(ix + 11.0, yy + 12.0, 22.0, id))
				var nm := String(W._ae(id).get("name", id))
				var nw: float = minf(Box.text_w(nm, 10.0, 700) + 2.0, 62.0)
				out.append(_dt(ix + 24.0, yy, nw, 24.0, _fitw(nm, 10.0, 700, nw), 10.0, 700, BROWN, "left"))
				ix += 24.0 + nw + 10.0
			yy += 28.0
		var nr := ("Ngày riêng: ngày " + str(Li.ngay) + " mỗi mùa (" + String(Li.ly) + ")") if nd else "Ngày riêng: chưa biết"
		out.append(_dt(X0 + 10.0, yy, XW - 20.0, 14.0, _fitw(nr, 10.0, 600, XW - 20.0), 10.0, 600, SUB, "left"))
		yy += 20.0
	c.r[3] = yy - y
	y = yy + GG
	# sở trường làm thuê
	var r := String(W.x9(u, f))
	var o: int = W._i(f.ts)
	var l: Dictionary = W.W3[r]
	out.append_array(_sect(y, "Sở trường: " + String(l.n), col))
	y += 22.0
	var c2 := _chip(X0, y, XW, 10.0, "s_" + r if VLC.has("s_" + r) else "tal")   # màu theo nghề
	out.append(c2)
	out.append(_icn(X0 + 24.0, y + 26.0, 30.0, String(TALIC.get(r, "lua"))))
	for i in 5:
		out.append(_pic(X0 + 46.0 + i * 16.0, y + 8.0, 14.0, 14.0, "res://ui/img/bong/" + ("sao.png" if i < o else "sao_xam.png")))
	if W.k9(f):
		out.append(_dt(X0 + 46.0 + 5 * 16.0 + 6.0, y + 7.0, 110.0, 16.0, "· đang đúng nghề", 10.0, 700, "rgb(46, 120, 50)", "left"))
	# (bản 442) bảng so sánh: hiện tại -> sao kế (xanh)
	var rows := [["Công rẻ", str(W.q_l(o)) + "%", str(W.q_l(o + 1)) + "%"]]
	if r == "xuong":
		rows.append(["Xưởng nhanh", str(4 * o) + "%", str(4 * (o + 1)) + "%"])
	else:
		rows.append([_cap(String(l.d).replace(" 1", "")), str(W.b_l(o)) + "%", str(W.b_l(o + 1)) + "%"])
	yy = y + 26.0
	for rw in rows:
		out.append(_dt(X0 + 46.0, yy, 90.0, 16.0, String(rw[0]), 10.5, 600, SUB, "left"))
		out.append(_dt(X0 + 138.0, yy, 40.0, 16.0, String(rw[1]), 11.0, 800, BROWN, "left"))
		if o < 5:
			out.append(_dt(X0 + 172.0, yy, 20.0, 16.0, "→", 11.0, 700, SUB))
			out.append(_dt(X0 + 194.0, yy, 44.0, 16.0, String(rw[2]), 11.0, 800, "rgb(46, 130, 50)", "left"))
		yy += 17.0
	yy += 4.0
	if W._tr(f.get("tt")):
		var cs := maxf(0.0, (W._n(f.tt) - G._now_ms()) / 1000.0)
		var p2 := _para(X0 + 10.0, yy + 3.0, XW - 100.0, "Đang đi học nghề lên " + str(o + 1) + " sao, còn " + G.ao(cs) + ".", 10.0, 700, BROWN, 13.0)
		out.append_array(p2[0])
		out.append(_btn(X0 + XW - 84.0, yy, 74.0, 26.0, "Về ngay", func(): W.e_y(u), "go"))
		yy += maxf(26.0, float(p2[1])) + 10.0
	elif o < 5:
		var fz: int = W.m_i(o)
		var lk: bool = W._i(f.get("tim")) < o
		out.append_array(_rowi(X0 + 10.0, yy + 5.0, 15.0, ["Lên " + str(o + 1), "s", ": " + W._sa(fz), "c", " · học " + G.ao(W.n_l(o))], 10.0, 700, BROWN)[0])   # (bản 452) sao, xu bằng hình
		if lk:
			out.append(_lockc(X0 + XW - 94.0, yy, o))
		else:
			out.append(_btn(X0 + XW - 94.0, yy, 84.0, 26.0, "Gửi đi học", func(): W.b_i(u), "go"))
		yy += 26.0 + 8.0
	else:
		out.append(_dt(X0 + 10.0, yy, XW - 20.0, 16.0, "Đã thành thợ cả 5 sao", 11.0, 800, BROWN, "left"))
		yy += 22.0
	c2.r[3] = yy - y
	y = yy + GG
	# nghề gia truyền
	var su := _su(y, f)
	out.append_array(su[0])
	y += float(su[1]) + 8.0
	return [out, y]

func _su(y: float, f: Dictionary) -> Array:   # SU: nghề gia truyền nhà này
	var x: Dictionary = W.a_r(u)
	var H: Dictionary = W.hn_s()
	var p = W.hn_of(u)
	var T0 := "Nghề gia truyền: " + String(x.n)
	var now: float = G._now_ms()
	var go0 := func(): W.mk(u)
	var gosk := func(): W.mk(u, "skip")
	var out := _sect(y, T0, TABC.tal)
	y += 22.0
	var r: Array
	if W.t6().has(x.id):
		r = _job(y, "nghe", "Đã học nghề " + String(x.n).to_lower(), "Mở bảng Nghề (nhóm Làm ăn) để làm.", [], 0, "", null)
	elif W._i(f.get("tim")) < 3:
		var lc := _chip(X0, y, XW, 48.0, "nghe")   # (bản 442) chưa đủ thân: hình món làm ra + 1 câu + khóa tim
		var pid: String = String(x.id) if not W._ae(x.id).is_empty() else String(x["in"][0][0])
		var lw := XW - 150.0
		r = [[lc, _icn(X0 + 24.0, y + 24.0, 30.0, pid), _dt(X0 + 46.0, y + 6.0, lw, 18.0, _fitw(String(W._ae(pid).get("name", x.n)), 11.5, 800, lw), 11.5, 800, BROWN, "left"),
			_lockc(X0 + XW - 94.0, y + 11.0, 3)] + _rowi(X0 + 46.0, y + 25.0, 14.0, ["Thân 3", "h", " họ mới nhận dạy"], 10.5, 600, SUB)[0], 48.0]
	elif not W._tr(p):
		var nd: Array = W.hn_in1(u, f)
		var ot = W.nghe_by_id(H.a) if W._tr(H.get("a")) and H.a != x.id else null
		var hc: int = W.ng_hoc_cho()
		r = _job(y, "nghe", "Bước 1/4 · Xin theo học", String(x.d) + " Đem đồ qua xin " + String(f.n) + " nhận dạy. Học xong trả " + W._sa(W.hn_hp(x)) + " xu tiền học." +
			(" Đang theo học " + String(ot.n).to_lower() + ", học nghề này thì tạm gác nghề kia." if ot != null else "") +
			(" Mới học xong nghề trước, " + str(hc) + " ngày nữa mới học nghề mới được." if hc else ""), nd, 0, "Xin học", go0 if not hc else null)
	elif H.get("a") != x.id:
		r = _job(y, "nghe", "Đang gác lại ở bước " + str(p.st) + "/4", "Quay lại học thì tạm gác nghề đang theo, tiến độ vẫn giữ.", [], 0, "Học tiếp", go0)
	elif int(p.st) == 2:
		var need: int = W.hn_days(f)
		r = _job(y, "nghe", "Bước 2/4 · Ngồi coi làm", "Trò chuyện với " + String(f.n) + " mỗi ngày một buổi để coi thầy làm (" + str(W._i(p.get("n"))) + "/" + str(need) + " buổi)." +
			(" Bữa nay chỉ rồi, mai ghé tiếp." if W._i(p.get("dl", -1)) == W._vr() else ""), [], 0, "", null)
	elif int(p.st) == 3 and not W._tr(p.get("te")):
		var i3: Array = W.hn_in3(x)
		r = _job(y, "nghe", "Bước 3/4 · Làm thử", "Đưa nguyên liệu 2 mẻ, " + str(x.tt) + " phút sau coi kết quả. Tỉ lệ hư " + str(W._rnd(W.hn_miss() * 100.0)) + "%." +
			(" Đã hư " + str(p.fl) + " lần." if W._tr(p.get("fl")) else ""), i3, 0, "Làm thử", go0)
	elif int(p.st) == 3 and W._n(p.te) > now:
		r = _job(y, "nghe", "Bước 3/4 · Đang làm thử", "Còn " + G.ao((W._n(p.te) - now) / 1000.0) + ".", [], 0, "Xong ngay", gosk)
	elif int(p.st) == 3:
		r = _job(y, "nghe", "Bước 3/4 · Làm thử xong rồi", "Coi coi được hông.", [], 0, "Coi", go0)
	else:
		var hp: int = W.hn_hp(x)
		var le: Array = W.hn_le(u, f)
		var Li: Dictionary = W.fam_likes(u)
		var kw: Dictionary = f.get("bk") if f.get("bk") is Dictionary else {}
		if f.get("tp") != "sd":
			le = Li.th.map(func(id): return [id, maxi(1, W._rnd(60.0 / W._sell(id)))])
		var ch := []
		for j in le.size():
			if W._tr(kw.get("b" if j else "a")):
				ch.append(le[j])
		var s: String = "Đem món làm thử, " + W._sa(hp) + " xu tiền học và lễ là " + ("đủ 2 món" if f.get("tp") == "sd" else "1 món") + " " + String(f.n) + " thích." + \
			("" if W._tr(kw.get("a")) and W._tr(kw.get("b")) else " Chưa biết nhà này thích gì thì trò chuyện, tặng quà để dò.")
		r = _job(y, "nghe", "Bước 4/4 · Ra mắt thầy", s, ch, 0, "Ra mắt", go0 if W._n(G.g.coins) >= hp and W.hn_le_ok(u, f) else null)
	out.append_array(r[0])
	return [out, 22.0 + float(r[1])]

# ------------------------------------------------------------------ hộp nổi: trò chuyện, tặng quà
func _pop(f: Dictionary, y0: float, y1: float, vt: Dictionary) -> Array:   # hộp chip phủ kín thân bảng, sát mép khung tre
	var box := _chip(float(vt.r[0]), y0, float(vt.r[2]), y1 - y0, "fut")
	box.css["border-radius"] = _cpx(4.0)
	var out := [box]
	var r: Array = _chat(f, y0, y1) if sub == "chat" else _gift(f, y0, y1)
	out.append_array(r)
	return out

func _phd(x: float, y: float, w: float, t: String, col: String) -> Array:   # (bản 450) tiêu đề hộp nổi: vạch màu + chữ đậm + gạch mảnh
	var tw: float = minf(Box.text_w(t, 12.5, 800) + 4.0, w - 20.0)
	return [_dbx(x, y + 2.0, 3.0, 14.0, col, 1.5), _dt(x + 8.0, y, tw, 18.0, _fitw(t, 12.5, 800, tw), 12.5, 800, BROWN, "left"),
		_dbx(x + 8.0 + tw + 8.0, y + 9.0, maxf(0.0, w - tw - 16.0), 1.0, "rgb(222, 204, 164)", 0.0)]

func _chat(f: Dictionary, y0: float, y1: float) -> Array:   # chatHtml (hộp nổi); (bản 450) mặt + bong bóng có đuôi, câu trả lời chip kem đánh số
	if cv == null:
		sub = ""
		return []
	var out := []
	var x0 := X0 + 10.0
	var w0 := XW - 20.0
	out.append_array(_phd(x0, y0 + 10.0, w0, "Trò chuyện với " + String(f.n), "rgb(70, 130, 190)"))
	# câu trả lời ở đáy hộp
	var opts: Array = cv.opts
	var oh := []
	for o in opts:
		oh.append(_wrap(String(o.t), 11.0, 700, w0 - 40.0).size() * 14.0 + 14.0)
	var oy := y1 - 10.0
	for h in oh:
		oy -= float(h) + 6.0
	oy += 6.0
	var yy := oy
	for i in opts.size():
		var o: Dictionary = opts[i]
		var h := float(oh[i])
		var pr: bool = o.get("k") == "nhan"
		var b := _chip(x0, yy, w0, h, "got" if pr else "fut")
		var lines := _wrap(String(o.t), 11.0, 700, w0 - 40.0)
		var cc := _dbx(x0 + 8.0, yy + (h - 18.0) * 0.5, 18.0, 18.0, "rgb(196, 160, 100)", 9.0)
		cc.kids = [_dt(x0 + 8.0, yy + (h - 18.0) * 0.5, 18.0, 18.0, str(i + 1), 10.0, 800, "rgb(255, 255, 255)")]   # số là con của tròn (pool dời nút cũ xuống cuối → số bị che)
		var ks := [cc]
		for j in lines.size():
			ks.append(_dt(x0 + 32.0, yy + 7.0 + j * 14.0, w0 - 40.0, 14.0, lines[j], 11.0, 700, BROWN, "left"))
		b.kids = ks
		b.act = _pick.bind(i)
		out.append(b)
		yy += h + 6.0
	# các câu: đo từ cuối lên, câu cũ không vừa thì bỏ; xếp từ trên xuống
	var top := y0 + 10.0 + 18.0 + 10.0
	var bot := oy - 10.0
	var bl := []
	var y := bot
	var lk := clampi(W._i(f.get("lk")), 0, 7)
	var face := "res://ui/img/vlface/" + str(lk) + ("n" if G.night else "") + ".webp"
	for li in range(cv.lines.size() - 1, -1, -1):
		var ln: Array = cv.lines[li]
		var k: String = ln[0]
		var s: String = ln[1]
		if k == "s":
			var L := _wrap(s, 10.5, 600, w0)
			var h := L.size() * 14.0
			if y - h < top:
				break
			y -= h
			for j in L.size():
				var st := _dt(x0, y + j * 14.0, w0, 14.0, L[j], 10.5, 600, SUB)
				st.css["font-style"] = "italic"
				bl.append(st)
			y -= 8.0
			continue
		var nb := k == "n"
		var mw := w0 - 60.0
		var L2 := _wrap(s, 10.5, 600, mw - 18.0)
		var tw := 0.0
		for t in L2:
			tw = maxf(tw, Box.text_w(t, 10.5, 600))
		var bw := minf(tw + 18.0, mw)
		var bh := L2.size() * 14.0 + 10.0
		if y - bh < top:
			break
		y -= bh
		var bx := x0 + 30.0 if nb else x0 + w0 - bw - 4.0
		var c := _chip(bx, y, bw, bh, "info" if nb else "got")
		var ks := []
		for j in L2.size():
			ks.append(_dt(bx + 9.0, y + 5.0 + j * 14.0, bw - 18.0, 14.0, L2[j], 10.5, 600, BROWN, "left"))
		c.kids = ks
		bl.append(c)
		if nb:   # mặt nhỏ + đuôi chỉ vào mặt
			bl.append(_pic(x0, y + bh - 24.0, 24.0, 24.0, face))
			bl.append(_dic(bx - 9.0, y + bh - 18.0, 11.0, TAILB))
		else:
			bl.append(_dic(bx + bw - 2.0, y + bh - 18.0, 11.0, TAILG))
		y -= 8.0
	var dy := top - (y + 8.0)
	for b in bl:
		Snap._move(b, Vector2(0, dy))
	out.append_array(bl)
	return out

func _pick(i: int) -> void:   # data-cv
	if cv == null:
		return
	var done: bool = W.chat_pick(cv, i)
	if done:
		cv = null
		sub = ""
		tab = "viec"

func _gift(f: Dictionary, y0: float, y1: float) -> Array:   # giftHtml (hộp nổi); (bản 450) lưới 2 cột kiểu Thuê làm, thích trước ghét sau, bỏ nút Thôi
	var out := []
	var x0 := X0 + 10.0
	var w0 := XW - 20.0
	var k: Dictionary = f.get("bk") if f.get("bk") is Dictionary else {}
	var x2: bool = W.is_ngay_rieng(u) and W._tr(k.get("d"))
	out.append_array(_phd(x0, y0 + 10.0, w0, "Tặng " + String(f.n) + " 1 món", "rgb(200, 70, 60)"))
	out.append(_dt(x0, y0 + 32.0, w0, 14.0, _fitw(("Ngày riêng: quý gấp đôi · " if x2 else "") + "Món thích +thân nhiều · món ghét bị trừ", 10.5, 600, w0), 10.5, 600, SUB, "left"))
	var ids: Array = W.gift_ids(u)
	var y := y0 + 56.0
	if ids.is_empty():
		out.append(_dt(x0, y, w0, 16.0, "Kho chưa có món gì để tặng.", 11.0, 700, BROWN, "left"))
		return out
	var g := 6.0
	var bw := (w0 - g) * 0.5
	var bh := 44.0
	var rows := int(floor((y1 - 10.0 - 18.0 - y + g) / (bh + g)))
	var nmax := mini(ids.size(), rows * 2)
	for i in nmax:
		var id: String = ids[i][0]
		var tg: int = ids[i][1]
		var cx := x0 + (i % 2) * (bw + g)
		var cy := y + floorf(i / 2.0) * (bh + g)
		var c := _chip(cx, cy, bw, bh, "got" if tg > 0 else ("sen" if tg < 0 else "fut"))
		var tx := cx + 42.0
		var tw := cx + bw - 6.0 - tx
		var ks := [_icn(cx + 21.0, cy + bh * 0.5, 26.0, id), _dt(tx, cy + 6.0, tw, 15.0, _fitw(String(W._ae(id).name), 11.5, 800, tw), 11.5, 800, BROWN, "left")]
		var st: String = "Có " + str(W._barn(id))
		if tg > 0:
			ks.append(_dt(tx, cy + 23.0, 40.0, 14.0, st + " ·", 10.5, 600, SUB, "left"))
			var sw: float = Box.text_w(st + " ·", 10.5, 600) + 4.0
			ks.append(_dic(tx + sw, cy + 25.0, 11.0, HEART))
			ks.append(_dt(tx + sw + 13.0, cy + 23.0, 40.0, 14.0, "Thích", 10.5, 700, "rgb(46, 120, 50)", "left"))
		else:
			ks.append(_dt(tx, cy + 23.0, tw, 14.0, st + (" · Ghét" if tg < 0 else ""), 10.5, 600 if tg == 0 else 700, "rgb(190, 60, 50)" if tg < 0 else SUB, "left"))
		c.kids = ks
		c.act = _give.bind(id)
		out.append(c)
	if ids.size() > nmax:
		out.append(_dt(x0, y1 - 26.0, w0, 14.0, "Còn " + str(ids.size() - nmax) + " món khác trong kho", 10.5, 600, SUB))
	return out

func _give(id: String) -> void:   # data-gv
	W.gift_give(u, id)
	sub = ""

