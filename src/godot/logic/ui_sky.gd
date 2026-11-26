extends "res://logic/ui_kbang.gd"
# TRỜI ĐẤT TRONG LÀNG (RN / Hh bản web, chạm ô giờ - thời tiết góc trái trên): (bản 396) khung Kho + chip chung (ui_kbang.gd), 2 tab:
#  - "Thời tiết": chip đỏ mùa + ngày trong mùa (thanh 7 ngày), chip bây giờ, dự báo 6 buổi (3 × 2), cảnh báo: thiên tai ngày mai,
#    hạn mặn, gió chướng, radio (bản tin ngày mai).
#  - "Lịch làng": hôm nay trong làng theo giờ (chợ nổi, hội chợ sân đình, đám), lễ hội 4 lễ gần nhất + hội đình.
# Bỏ khỏi bảng (bản 396): nhạc đờn ca (bản Godot chưa có nhạc), chỉnh giờ / mùa (Cài đặt có), hụi (đã bỏ, bản 500), rầy nâu (cột việc;
# phun hết thuốc tự mua), tát ao (chạm ao), hội thi làng + nồi cơm trưa (chơi mạng, chưa có). Hình thời tiết: ui/snap/sky.json.

var SK := {}
var cd := "t"

const TK := ["Khuya", "Sáng", "Chiều", "Tối"]
const T8 := ["Mùa xuân", "Mùa hạ", "Mùa thu", "Mùa khô"]
const HQ := {"nang": "Trời đẹp, thỉnh thoảng có mưa rào tưới giùm.",
	"mua": "Ruộng, cây ăn trái tự thấm nước. Có sấm sét, gió quật ngã cây.",
	"rao": "Mưa rào chốc lát, tạnh là ruộng và cây no nước.",
	"han": "Ruộng khô nhanh gấp rưỡi, không mưa rào."}
const HQF := {"nang": "Không có gì đặc biệt. Thỉnh thoảng có mưa rào tưới giùm.",
	"mua": "Mưa rả rích cả buổi, ruộng và cây ăn trái thấm nước dần, khỏi tưới. Có sấm sét, gió quật ngã 1–3 cây; cây đè ruộng thì ruộng ngưng lớn tới khi dọn. Đi chậm 15% nếu không mặc áo mưa.",
	"rao": "Trận mưa rào 5 giây, tạnh là ruộng và cây ăn trái no nước.",
	"han": "Ruộng khô nhanh gấp rưỡi, không có mưa rào. Lu nước, giếng, ao gần ruộng giúp đỡ khô."}

# màu chip riêng bảng Trời đất: thời tiết (nền + viền theo trời), buổi trong ngày (ô giờ), lễ gần / xa
const SKC := {
	"wx_nang": ["rgb(255, 248, 210)", "rgb(255, 242, 190)", "rgb(254, 234, 168)", "rgb(214, 170, 80)"],   # (11-26) thẻ Bây giờ: tông sáng, sạch
	"fc": ["rgb(196, 230, 252)", "rgb(214, 238, 252)", "rgb(232, 246, 254)", "rgb(214, 176, 96)"],
	"wx_han": ["rgb(255, 232, 196)", "rgb(255, 222, 176)", "rgb(254, 210, 156)", "rgb(206, 120, 50)"],
	"wx_rao": ["rgb(224, 242, 254)", "rgb(206, 234, 252)", "rgb(190, 226, 250)", "rgb(90, 160, 210)"],
	"wx_mua": ["rgb(232, 244, 254)", "rgb(214, 236, 252)", "rgb(196, 226, 248)", "rgb(80, 116, 150)"],
	"t_sang": ["rgb(255, 236, 170)", "rgb(255, 242, 192)", "rgb(255, 248, 214)", "rgb(214, 160, 40)"],
	"t_chieu": ["rgb(252, 210, 166)", "rgb(253, 220, 184)", "rgb(254, 230, 204)", "rgb(206, 128, 60)"],
	"t_toi": ["rgb(112, 114, 158)", "rgb(124, 126, 170)", "rgb(138, 140, 182)", "rgb(84, 86, 130)"],
	"le_gan": ["rgb(244, 170, 160)", "rgb(248, 186, 176)", "rgb(250, 202, 192)", "rgb(196, 70, 60)"],
	"le_xa": ["rgb(226, 196, 128)", "rgb(233, 206, 144)", "rgb(240, 218, 165)", "rgb(150, 108, 40)"],
}
func _ck(kind: String) -> Array:
	return SKC[kind] if SKC.has(kind) else super(kind)

# hình thời tiết vẽ lệch trong khung 24 (mây mưa nằm thấp, nhỏ hơn mặt trời): bù [phóng, dời dọc theo cỡ] cho cùng tâm, cùng cỡ
const WIC := {"mua": [1.08, -0.10], "giong": [1.08, -0.125]}
const WPIC := {"nang": "res://ui/img/troi/nang.webp", "han": "res://ui/img/troi/han.webp", "mua": "res://ui/img/troi/mua.webp"}   # (11-26) icon thời tiết mới
static var _wsv := {}
func _wic(cx: float, cy: float, s: float, f: String) -> Dictionary:   # hình thời tiết f, tâm (cx, cy), cỡ s
	if WPIC.has(f):
		if not _wsv.has(f):
			_wsv[f] = Css.img_svg(WPIC[f])
		return _dic(cx - s * 0.5, cy - s * 0.5, s, _wsv[f])
	var w: Array = WIC.get(f, [1.0, 0.0])
	var z := s * float(w[0])
	return _dic(cx - z * 0.5, cy - z * 0.5 + s * float(w[1]), z, String(SK.ic[f]))

# (11-26) hoa văn cuộn vàng góc thẻ "Bây giờ" (svg vẽ tay)
static func _sv_cuon(sz: float, flip: bool) -> String:   # hoa văn cuộn vàng góc dưới (trái; flip = góc phải)
	var S := str(sz)
	var t := " transform='translate(" + S + " 0) scale(-1 1)'" if flip else ""
	return "<svg xmlns='http://www.w3.org/2000/svg' width='" + S + "' height='" + S + "' viewBox='0 0 20 20'><g" + t + " fill='none' stroke-linecap='round'>" \
		+ "<path d='M3 17 C3 11 6 7 12 6 C15 5.6 16.5 7.5 15.5 9.5 C14.6 11.2 12 11 11.6 9.4 C11.3 8.3 12.5 7.6 13.2 8.2' stroke='#b27a24' stroke-width='2.4'/>" \
		+ "<path d='M3 17 C3 11 6 7 12 6 C15 5.6 16.5 7.5 15.5 9.5 C14.6 11.2 12 11 11.6 9.4 C11.3 8.3 12.5 7.6 13.2 8.2' stroke='#f2c860' stroke-width='1.2'/>" \
		+ "<path d='M3 17 C7 17 10 15.5 11 13' stroke='#b27a24' stroke-width='2.2'/><path d='M3 17 C7 17 10 15.5 11 13' stroke='#f2c860' stroke-width='1.1'/>" \
		+ "<circle cx='3.2' cy='16.8' r='1.6' fill='#e6b448' stroke='#b27a24' stroke-width='0.8'/></g></svg>"

# (11-26) icon trái hàng cảnh báo + tiêu đề mục + chip mùa (svg vẽ tay, kiểu ảnh mẫu)
const _SV := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'>"
const IC := {
	"gio": _SV + "<g fill='none' stroke-linecap='round'><path d='M4 12 H18 a4 4 0 1 0 -4 -4' stroke='#2f7fc8' stroke-width='4'/><path d='M4 12 H18 a4 4 0 1 0 -4 -4' stroke='#7cc4f4' stroke-width='2'/><path d='M3 18 H24 a4 4 0 1 1 -4 4' stroke='#2f7fc8' stroke-width='4'/><path d='M3 18 H24 a4 4 0 1 1 -4 4' stroke='#7cc4f4' stroke-width='2'/><path d='M7 24 H13' stroke='#2f7fc8' stroke-width='4'/><path d='M7 24 H13' stroke='#7cc4f4' stroke-width='2'/></g></svg>",
	"canh": _SV + "<path d='M16 3 L30 28 H2 Z' fill='#f6c341' stroke='#c0392b' stroke-width='2.6' stroke-linejoin='round'/><path d='M16 4.5 L28.5 27 H3.5 Z' fill='#fff2c4' opacity='0.5'/><rect x='14' y='10' width='4' height='10' rx='2' fill='#c0392b'/><circle cx='16' cy='24' r='2.2' fill='#c0392b'/></svg>",
	"radio": _SV + "<path d='M8 10 L22 4' stroke='#7a4a1e' stroke-width='1.8' stroke-linecap='round'/><circle cx='22' cy='4' r='1.8' fill='#7a4a1e'/><rect x='2' y='10' width='28' height='19' rx='4' fill='#f0a34a' stroke='#8a4f1a' stroke-width='1.8'/><rect x='4' y='12' width='24' height='3' rx='1.5' fill='#ffd08a' opacity='0.8'/><circle cx='11' cy='20' r='5.6' fill='#7a4a1e'/><circle cx='11' cy='20' r='4' fill='#a8692e'/><g stroke='#7a4a1e' stroke-width='1.8' stroke-linecap='round'><path d='M19 17 H26'/><path d='M19 20.5 H26'/><path d='M19 24 H26'/></g></svg>",
	"nuoc": _SV + "<g fill='none' stroke-linecap='round'><path d='M3 12 q3.25 -4 6.5 0 t6.5 0 t6.5 0 t6.5 0' stroke='#2f7fc8' stroke-width='3.4'/><path d='M3 19 q3.25 -4 6.5 0 t6.5 0 t6.5 0 t6.5 0' stroke='#4aa3e6' stroke-width='3.4'/><path d='M3 26 q3.25 -4 6.5 0 t6.5 0 t6.5 0 t6.5 0' stroke='#7cc4f4' stroke-width='3.4'/></g></svg>",
	"man": _SV + "<path d='M16 3 C10 11 7 15 7 20 a9 9 0 0 0 18 0 C25 15 22 11 16 3Z' fill='#9fd3f5' stroke='#2f7fc8' stroke-width='2'/><g fill='#ffffff' stroke='#8aa' stroke-width='0.6'><rect x='11' y='18' width='4' height='4' transform='rotate(20 13 20)'/><rect x='17' y='20' width='4' height='4' transform='rotate(-15 19 22)'/><rect x='14' y='24' width='3.4' height='3.4'/></g></svg>",
	"cay": _SV + "<rect x='14' y='18' width='4' height='11' rx='1.5' fill='#8a5a2b'/><circle cx='16' cy='12' r='9' fill='#56a83c' stroke='#2f7a28' stroke-width='1.6'/><circle cx='12.5' cy='9.5' r='3' fill='#8ccf5c'/><path d='M4 29 H28' stroke='#8a5a2b' stroke-width='2' stroke-linecap='round'/></svg>",
	"nan": _SV + "<path d='M4 15 L16 5 L28 15' fill='none' stroke='#b0442c' stroke-width='3' stroke-linejoin='round' stroke-linecap='round'/><path d='M7 14 V28 H25 V14 L16 7 Z' fill='#f3d9a8' stroke='#8a5a2b' stroke-width='1.6'/><rect x='13' y='19' width='6' height='9' fill='#a0663a'/><path d='M20 9 l3 5 -4 3 3 5' fill='none' stroke='#c0392b' stroke-width='1.8' stroke-linecap='round'/></svg>",
	"sen": _SV + "<g stroke='#d8507e' stroke-width='1' stroke-linejoin='round'><path d='M16 6 C20 11 20 18 16 24 C12 18 12 11 16 6Z' fill='#f7a8c4'/><path d='M16 24 C10 22 6 17 5 11 C10 12 14 17 16 24Z' fill='#f492b6'/><path d='M16 24 C22 22 26 17 27 11 C22 12 18 17 16 24Z' fill='#f492b6'/><path d='M16 24 C11 25 6 24 2 20 C7 18 12 20 16 24Z' fill='#f7b8cf'/><path d='M16 24 C21 25 26 24 30 20 C25 18 20 20 16 24Z' fill='#f7b8cf'/></g></svg>",
	"loa": _SV + "<path d='M4 13 H10 L22 6 V26 L10 19 H4 Z' fill='#e2473f' stroke='#9c2a24' stroke-width='1.6' stroke-linejoin='round'/><rect x='6' y='19' width='4' height='8' rx='1.5' fill='#9c2a24'/><path d='M4.5 14 H10' stroke='#ff9a90' stroke-width='1.4'/><g fill='none' stroke='#e2473f' stroke-width='2' stroke-linecap='round'><path d='M25 12 q3 4 0 8'/><path d='M27.5 9 q5 7 0 14'/></g></svg>",
	"hoa": _SV + "<g fill='#ffffff' stroke='#f0c0c8' stroke-width='0.8'><circle cx='16' cy='8' r='6'/><circle cx='23.6' cy='13.5' r='6'/><circle cx='20.7' cy='22.5' r='6'/><circle cx='11.3' cy='22.5' r='6'/><circle cx='8.4' cy='13.5' r='6'/></g><circle cx='16' cy='16' r='4.2' fill='#f6c341' stroke='#d89a20' stroke-width='1'/></svg>",
}
const HDI := {"Dự báo": "sen", "Cảnh báo, tin tức": "loa", "Hôm nay trong làng": "sen", "Lễ hội": "sen"}

func _hd(y: float, t: String) -> Array:   # tiêu đề mục có icon trước chữ (ảnh mẫu)
	if not HDI.has(t):
		return super(y, t)
	var L: Array = super(y, t)
	for n in L:
		Snap._move(n, Vector2(22.0, 0))
		if float(n.r[0]) + float(n.r[2]) > X0 + XW:
			n.r[2] = X0 + XW - float(n.r[0])
	L.append(_dic(X0, y - 3.0, 20.0, IC[HDI[t]]))
	return L

static func _wk(f: String) -> String:   # loại chip theo thời tiết
	return "wx_" + (f if f in ["nang", "han", "rao", "mua"] else "nang")

func _init(ui) -> void:
	super(ui)
	SK = Snap.load_snap("sky")

func open() -> void:   # RN
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	return JSON.stringify([cd, _now_w(), G.day(), int(G.nv.hour() * 4.0), G.ray_n(), G.g.get("hc"), G.cfg.s])

func _now_w() -> String:   # ti.cur || Wd()
	return G.troi.cur if G.troi.cur != "" else G.nv.Wd()

func _tab_go(k: String) -> void:
	if cd != k:
		cd = k
		scroll = 0.0

func _go(f: Callable) -> Callable:   # đóng bảng rồi mở bảng khác
	return func(): close(); f.call()

func _build() -> void:
	sig = _sig()
	var W = G.w_all
	var o: int = G.day()
	var lehot := false
	for r in 3:
		if W.WH.mm(o + r) != null:
			lehot = true
	var tn_mai: bool = W.WL.tn_ok() and W.WL.tn_on(o + 1) != null
	var sh := _kshell([["t", "Thời tiết", tn_mai], ["l", "Lịch làng", lehot]], cd, _tab_go)
	var r: Array = _tabt() if cd == "t" else _tabl()
	_kmount(sh[0], sh[1], sh[2], r[0], float(r[1]))

# ------------------------------------------------------------------ một hàng chip: [ô trái nhỏ], tên đậm + 1 dòng, nút chip xanh phải
func _cap(t: String) -> String:   # chữ đầu viết hoa (ô giờ: Sáng, Tối, Còn)
	return t.substr(0, 1).to_upper() + t.substr(1)

func _row(y: float, h: float, kind: String, lt, title: String, sub: String, full: String, btn = null) -> Array:
	var out := []
	var c := _chip(X0, y, XW, h, kind)
	var x := X0 + 10.0
	var ks := []
	if lt is String:   # icon trái không ô (ảnh mẫu)
		ks.append(_dic(X0 + 10.0, y + (h - 30.0) * 0.5, 30.0, IC[lt]))
		x = X0 + 50.0
	elif lt != null:   # ô trái: [dòng 1, dòng 2] hoặc [svg]
		var lw := 50.0
		var L: Array = lt
		var lk: String = String(L[2]) if L.size() > 2 else "fut"
		var lc := _chip(X0 + 6.0, y + 5.0, lw, h - 10.0, lk)
		var dk := lk == "t_toi"
		if L.size() == 1:
			lc.kids = [_dic(X0 + 6.0 + (lw - 24.0) * 0.5, y + (h - 24.0) * 0.5, 24.0, String(L[0]))]
		else:
			lc.kids = [_dt(X0 + 6.0, y + h * 0.5 - 13.0, lw, 12.0, _cap(String(L[0])), 9.5, 600, "rgb(220, 222, 240)" if dk else SUB), _dt(X0 + 6.0, y + h * 0.5, lw, 13.0, String(L[1]), 11.0, 800, "rgb(255, 255, 255)" if dk else BROWN)]
		ks.append(lc)
		x = X0 + lw + 14.0
	var bw := 0.0
	if btn != null:
		bw = Box.text_w(String(btn[0]), 11.0, 800) + 22.0
	var tw := X0 + XW - x - (bw + 14.0 if bw > 0.0 else 8.0)
	var L2 := _wrap2(sub, 10.0, 600, tw) if h >= 54.0 else [_fitw(sub, 10.0, 600, tw)]
	var ty := y + (h - (16.0 + L2.size() * 13.0)) * 0.5
	ks.append(_dt(x, ty, tw, 15.0, _fitw(title, 13.0, 800, tw), 13.0, 800, BROWN, "left"))
	for i in L2.size():
		ks.append(_dt(x, ty + 17.0 + i * 13.0, tw, 13.0, String(L2[i]), 10.0, 600, SUB, "left"))
	c.kids = ks
	c.act = _dsay.bind(full)
	out.append(c)
	if btn != null:   # nút đặt ngoài chip (bấm nút không bấm luôn hàng)
		var b := _onbtn(X0 + XW - bw - 8.0, y + (h - 26.0) * 0.5, bw, 26.0, String(btn[0]), btn[1])
		b.kids[0].css["font-size"] = _cpx(11.0)
		out.append(b)
	return out

func _wrap2(s: String, fs: float, fw: int, w: float) -> Array:   # ngắt tối đa 2 dòng theo chữ, dòng 2 cắt "…"
	if Box.text_w(s, fs, fw) <= w:
		return [s]
	var ws := s.split(" ")
	var a := ""
	var i := 0
	while i < ws.size() and Box.text_w((a + " " + ws[i]).strip_edges(), fs, fw) <= w:
		a = (a + " " + ws[i]).strip_edges()
		i += 1
	return [a, _fitw(" ".join(ws.slice(i)), fs, fw, w)]

# ------------------------------------------------------------------ tab Thời tiết
func _tabt() -> Array:
	var W = G.w_all
	var out := []
	var o: int = G.day()
	var sea: int = G.season()
	var auto: bool = G.cfg.s == "auto"
	var dd: int = posmod(o, 28) % 7 + 1
	# mùa + ngày trong mùa
	var y := 10.0
	var mt: String = T8[sea]
	var mw: float = Box.text_w(mt, 13.0, 800) + 52.0
	var mb := _onbtn(X0, y - 2.0, mw, 30.0, mt, null, true)
	mb.kids[0].css["font-size"] = _cpx(13.0)
	mb.kids[0].r = [X0 + 22.0, y - 2.0, mw - 26.0, 30.0]
	mb.kids.append(_dic(X0 + 9.0, y + 4.0, 18.0, IC.hoa))
	out.append(mb)
	var st := ("Ngày " + str(dd) + "/7 · " + ("còn " + str(7 - dd) + " ngày sang " + String(T8[(sea + 1) % 4]).to_lower() if dd < 7 else "mai sang " + String(T8[(sea + 1) % 4]).to_lower())) if auto else "Mùa chỉnh tay trong Cài đặt"
	out.append(_dt(X0 + mw + 10.0, y - 3.0 if auto else y, XW - mw - 10.0, 20.0 if auto else 26.0, st, 11.5, 700, BROWN, "left"))
	if auto:   # thanh 7 ngày
		var bx := X0 + mw + 10.0
		var bw := XW - mw - 14.0
		var sw := (bw - 6.0 * 3.0) / 7.0
		for i in 7:
			out.append(_dbx(bx + i * (sw + 3.0), y + 20.0, sw, 5.0, "rgb(35, 160, 74)" if i < dd else "rgb(230, 214, 174)", 3.0))
	# bây giờ
	var a := _now_w()
	var WN := _warns()
	var nwarn := WN.size()
	# (bản 402) cả bảng giãn / co cùng một tỉ lệ k cho vừa khung: chip bây giờ 72, dự báo 68, hàng cảnh báo 44 (x k)
	var gaps := 10.0 + 40.0 + 12.0 + 22.0 + 12.0 + 22.0 + maxf(0.0, nwarn - 1) * 6.0 + 8.0
	var k := clampf((_hb - gaps) / (72.0 + 68.0 + nwarn * 44.0), 0.75, 1.6)
	_rh = 44.0 * k
	var ny := y + 40.0
	var nh := minf(72.0 * k, 84.0)
	var nc := _chip(X0, ny, XW, nh, _wk(a))
	var nis := minf(nh - 14.0, 66.0)
	var tx0 := X0 + 16.0 + nis + 20.0
	var tw0 := XW - (tx0 - X0) - 12.0
	var hl := _wrap2(HQ[a], 10.5, 600, tw0)   # hiệu ứng tối đa 2 dòng
	var bh := 12.0 + 20.0 + hl.size() * 13.0
	var lg := maxf(2.0, (nh - bh) / 4.0)   # khoảng đều: trên, giữa các dòng, dưới
	var ty0 := ny + lg
	nc.kids = [_wic(X0 + 16.0 + nis * 0.5, ny + nh * 0.5, nis, a), _dbx(tx0 - 10.0, ny + 10.0, 1.0, nh - 20.0, "rgb(226, 190, 110)", 0.0),
		_dt(tx0, ty0, tw0, 12.0, "Bây giờ · " + String(TK[int(floor(G.nv.hour() / 6.0))]).to_lower(), 10.0, 600, SUB, "left"),
		_dt(tx0, ty0 + 12.0 + lg, tw0, 20.0, String(G.troi.TEN[a]), 17.0, 800, BROWN, "left")]
	for li in hl.size():
		nc.kids.append(_dt(tx0, ty0 + 32.0 + lg * 2.0 + li * 13.0, tw0, 13.0, String(hl[li]), 10.5, 600, SUB, "left"))
	nc.kids.append(_dsvg(X0 + 4.0, ny + nh - 22.0, 18.0, 18.0, _sv_cuon(18.0, false)))
	nc.kids.append(_dsvg(X0 + XW - 22.0, ny + nh - 22.0, 18.0, 18.0, _sv_cuon(18.0, true)))
	nc.act = _dsay.bind(HQF[a])
	out.append(nc)
	# dự báo 3 buổi kế tiếp (bỏ khuya)
	var fy := ny + nh + 12.0
	out.append_array(_hd(fy, "Dự báo"))
	var e: int = o * 4 + int(floor(G.nv.hour() / 6.0))
	var g := 6.0
	var cw := (XW - g * 2.0) / 3.0
	var ch := minf(68.0 * k, cw / 1.15)   # ô dự báo dẹt ngang như ảnh mẫu
	var isz := clampf(ch - 12.0 - 15.0 - 24.0, 20.0, 44.0)   # lề trên / dưới 7, khe chữ - hình 3
	var fg := (ch - 12.0 - isz - 18.0) / 3.0   # lề trên = lề dưới   # khoảng đều: trên, giữa chữ - hình, hình - chữ, dưới
	var gy := fy + 22.0
	var bs := []
	var c0: int = e + 1
	while bs.size() < 3:
		if posmod(c0, 4) != 0:
			bs.append(c0)
		c0 += 1
	for i in 3:
		var c: int = bs[i]
		var f: String = G.nv.Hx(c)
		var s: int = int(floor(c / 4.0)) - o
		var x := X0 + i * (cw + g)
		var yy := gy
		var cc := _chip(x, yy, cw, ch, "fc")
		var bgn := _dic(x + 3.0, yy + 3.0, cw - 6.0, "")   # nền trời + cỏ (ảnh), góc bo sẵn, phủ sát dải vàng viền
		bgn.erase("svg")
		bgn.r = [x + 3.0, yy + 3.0, cw - 6.0, ch - 6.0]
		bgn["pic"] = "res://ui/img/troi/nen_du_bao.webp"
		cc.kids = [bgn, _dt(x, yy + fg, cw, 13.0, TK[posmod(c, 4)] + " " + ("nay" if s == 0 else ("mai" if s == 1 else "mốt")), 11.0, 800, BROWN),
			_wic(x + cw * 0.5, yy + fg + 15.0 + isz * 0.5, isz, f),
			_dt(x + 2.0, yy + fg + 18.0 + isz, cw - 4.0, 15.0, _fitw(String(G.troi.TEN[f]), 12.5, 800, cw - 4.0), 12.5, 800, BROWN)]
		cc.act = _dsay.bind(TK[posmod(c, 4)] + " " + ("hôm nay" if s == 0 else ("mai" if s == 1 else "mốt")) + ": " + String(G.troi.TEN[f]) + ". " + HQF[f])
		out.append(cc)
	# cảnh báo + radio
	var ky := gy + ch + 12.0
	out.append_array(_hd(ky, "Cảnh báo, tin tức"))
	var ry := ky + 22.0
	var rh := _rh
	for i in WN.size():
		var q: Array = WN[i]
		out.append_array(_row(ry, rh, String(q[0]), q[6] if q.size() > 6 else null, String(q[1]), String(q[2]), String(q[3]), q[4]))
		ry += rh + (g if i < WN.size() - 1 else 0.0)
	return [out, ry + 8.0]

var _rh := 44.0   # cao hàng cảnh báo (thiếu chỗ thì thấp lại, tính ở _tabt)

# cảnh báo, tin tức: [loại chip, tên, dòng phụ, mô tả chạm, nút?]
func _warns() -> Array:
	var W = G.w_all
	var o: int = G.day()
	var sea: int = G.season()
	var L := []
	# thiên tai: báo trước 2 ngày (hiện loại), xa hơn chỉ báo còn mấy ngày; đang có nạn thì nút giúp
	if W.WL.tn_ok():
		var nx := -1
		var ev = null
		for r in range(1, 40):
			ev = W.WL.tn_on(o + r)
			if ev != null:
				nx = r
				break
		if nx >= 1 and nx <= 2:
			var K: Dictionary = W.WL.TNK[String(ev.k)]
			var t := ("Ngày mai: " if nx == 1 else "Ngày mốt: ") + String(K.n)
			L.append(["sen", t, String(K.d), String(K.w) + ". " + String(K.d), ["Phòng chống", _go(U.tn_open.bind("phong"))], 1, "canh"])
		elif nx > 2 and nx <= 7:   # còn xa hơn 7 ngày thì chưa báo
			L.append(["fut", "Thiên tai kế tiếp · còn " + str(nx) + " ngày", "Báo loại thiên tai trước 2 ngày để kịp phòng chống.", "Mỗi tháng 2 trận thiên tai. Trận tới còn " + str(nx) + " ngày, trước 2 ngày sẽ báo là bão, lũ, hạn, dịch hay cháy.", null, 7, "canh"])
		var tp: Array = W.WD.tn_pill_txt()
		if tp.size() and not bool(tp[1]):
			L.append(["sen", String(tp[0]).split(" · ")[0], "Bà con cần giúp sửa nhà, góp đồ.", String(tp[0]), ["Giúp", _go(U.tn_open.bind("nan"))], 2, "nan"])
	# nước nổi: mùa thu ngày 2..6
	var dd: int = posmod(o, 28) % 7 + 1
	if W.WR.qs():
		var fs := "Phù sa bồi, cây lớn nhanh 4%. Cá linh về, ven sông có điên điển, bông súng, kèo nèo."
		L.append(["wx_rao", "Nước nổi về sông Vàm", fs, fs, null, 4, "nuoc"])
	elif G.cfg.s == "auto":
		var to := posmod(2 * 7 + 1 - (posmod(o, 28)), 28)   # tới ngày 2 mùa thu
		if to >= 1 and to <= 7:
			L.append(["fut", "Nước nổi · còn " + str(to) + " ngày", "Mùa thu nước sông lên, cá linh về.", "Còn " + str(to) + " ngày nữa nước nổi về sông Vàm (mùa thu, ngày 2–6).", null, 4, "nuoc"])
	# hạn mặn
	var n4: bool = W.WR.n4()
	var ac: int = W.WR.ac()
	if n4 or (ac >= 0 and ac <= 4):
		var ms := "Nước mặn đang lấn vô sông, ruộng chậm lớn." if n4 else "Chừng " + str(ac) + " ngày nữa mặn lấn vô sông Vàm. Trữ nước ngọt sẵn."
		L.append(["sen" if n4 else "fut", "Hạn mặn", ms, ms, ["Xem", _go(W.WRU.open_man)], 4, "man"])
	# gió chướng
	if sea == 3 or sea == 0:
		var cg: bool = W.WCA.cg()
		var gs := "Đang có gió, ra đồng thả diều (bảng nhân vật › Diều)." if cg else "Mùa này chiều 14–18 giờ có gió thả diều."
		L.append(["got" if cg else "fut", "Gió chướng", gs, gs, null, 6, "gio"])
	var rs := "Bản tin thời tiết ngày mai, giá cả, cải lương."
	L.append(["fut", "Radio", rs, rs, ["Mở radio", _go(W.WCU.open_rd)], 8, "radio"])
	# cây ngã đè ruộng (mưa dầm, giông)
	var fl: Dictionary = G.troi.bao.wx().fell
	var nf := 0
	var fk := ""
	for k in fl:
		if String(fl[k].s) == "down":
			nf += 1
			if fk == "" or int(fl[k].p) >= 0:
				fk = String(k)
	if nf:
		var fd := "Cây ngã đè ruộng thì ruộng ngưng lớn tới khi dọn. Chạm cây ngã để dọn."
		L.append(["sen", str(nf) + " cây ngã sau giông", "Đè ruộng thì ruộng ngưng lớn, dọn sớm.", fd, ["Tới dọn", _cam_to.bind(fk)], 3, "cay"])
	L.sort_custom(func(a, b): return int(a[5]) < int(b[5]))
	return L.slice(0, 4)   # tối đa 4 dòng, bỏ bớt dòng ít gấp

func _cam_to(sk: String) -> void:   # đóng bảng, đưa máy quay tới cây ngã
	var B = G.troi.bao
	if not B.by.has(sk):
		return
	var t: Dictionary = B.by[sk]
	var M = U.main
	var cx := float(t.gx) + float(t.fw) / 2.0
	var cy := float(t.gy) + float(t.fd) / 2.0
	M.cam = Vector2(U.F.en(cx, cy), U.F.nn(cx, cy)) - U.get_viewport().get_visible_rect().size / M.zoom * 0.5
	if M.has_method("_clamp_cam"):
		M._clamp_cam()
	close()

# ------------------------------------------------------------------ tab Lịch làng
func _tabl() -> Array:   # (bản 404) dựng danh sách trước, rồi cả tab giãn / co cùng một tỉ lệ cho kín khung
	var W = G.w_all
	var o: int = G.day()
	var T := []   # hôm nay trong làng: [loại, ô trái, tên, dòng phụ, mô tả chạm, nút]
	if W.WC.u4() != null:
		var v: bool = W.WC.b2()
		var lk: int = W.WC._qf("cho")
		var hr: float = W.WC._hour()
		var st := "Đang họp" if v else ("Cấp " + str(lk) + " mới mở" if lk > 0 else ("Chưa họp · 5g mở" if hr < float(W.WC.JB) else "Đã tan · mai 5g"))
		var cs := "Họp từ 5 giờ tới " + str(W.WC.wm()) + " giờ sáng mỗi ngày. " + st + "."
		T.append(["got" if v else "fut", ["sáng", "5–" + str(W.WC.wm()) + "g", "t_sang"], "Chợ nổi sông Vàm", st, cs, ["Đi chợ", _go(W.WCU._pill_go)] if v else null])
	else:
		T.append(["fut", ["sáng", "5–" + str(W.WC.wm()) + "g", "t_sang"], "Chợ nổi sông Vàm", "Mở khúc sông Vàm để có chợ", "Mở khúc sông Vàm (khai hoang phía nam) để có chợ nổi.", null])
	var a2 := 0
	while a2 < 4 and not W.WH.c_r(o + a2):
		a2 += 1
	var n2: bool = W.WH.e_r()
	var l2: bool = W.WH.l2()
	var hs := "Đang mở! Ra sân đình chơi ném vòng, đập niêu, lô tô." if l2 else ("Tối nay 18g30–22g30 có hội chợ." if n2 else "Hội chợ kế tiếp " + ("tối mai" if a2 == 1 else "sau " + str(a2) + " ngày") + ". Bỏ 2.000 xu tổ chức tối nay thì chơi liền.")
	T.append(["got" if l2 else "fut", ["tối", "18g30", "t_toi"], "Hội chợ sân đình", "Đang mở" if l2 else ("Tối nay có hội" if n2 else "Tối nay không có"), hs, null if n2 else ["Tổ chức · 2.000", W.WH.b_]])
	var ev = W.WL.tg().get("ev")
	if _tr(ev):
		var a := int(floor(fmod(float(ev.t0), 24.0)))
		var on_d: bool = W.WL.sg() != null
		var es := "Đã dự." if _tr(ev.get("done")) else ("Đang đãi khách, ghé dự liền!" if on_d else "Lúc " + ("0" if a < 10 else "") + str(a) + ":00.")
		T.append(["got" if on_d else "fut", ["giờ", str(a) + "g", "t_sang" if a < 11 else ("t_chieu" if a < 17 else "t_toi")], String(W.WL.qm(ev)), es, String(W.WL.qm(ev)) + ": " + es, null])
	# lễ hội: lễ gần nhất + hội đình, xếp theo ngày, tối đa 4
	var LE := []   # [còn r ngày, dòng]
	var seen := {}
	for r in 56:
		if LE.size() >= 4:
			break
		var d = W.WH.mm(o + r)
		if d != null and not seen.has(d.id):
			seen[d.id] = 1
			var when := String(G.SEA_N[int(d.sea)]) + " ngày " + str(int(d.day))
			LE.append([r, ["fut", ["", "Hôm nay", "le_gan"] if r == 0 else (["còn", str(r) + " ngày", "le_gan"] if r <= 2 else ["Mùa " + String(G.SEA_N[int(d.sea)]).to_lower(), "ngày " + str(int(d.day)), "le_xa"]), String(d.n), String(d.d), String(d.n) + " (" + when + "): " + String(d.d), null]])
	var tx = W.WH.hdn_pill_txt()
	if tx != null:
		var cu: Dictionary = W.WH.hdn_s().cur
		var today: bool = int(tx[1]) == 1
		var rr: int = 0 if today else int(cu.d) - o
		var hd := ("Hôm nay mở hội ở sân đình.") if today else "Còn " + str(rr) + " ngày tới hội. Bà con đang góp lễ."
		LE.append([rr, ["fut", ["", "Hôm nay", "le_gan"] if today else (["còn", str(rr) + " ngày", "le_gan"] if rr <= 2 else ["Mùa " + String(G.SEA_N[int(floor(posmod(int(cu.d), 28) / 7.0))]).to_lower(), "ngày " + str(posmod(int(cu.d), 28) % 7 + 1), "le_xa"]), "Hội đình làng", hd, hd, ["Vào thi" if today else "Chuẩn bị", _go(U.hdn_open.bind("giai" if today else "mo"))]]])
	LE.sort_custom(func(x, z): return int(x[0]) < int(z[0]))
	LE = LE.slice(0, 4)
	if LE.size():
		LE[0][1][0] = "sen"   # lễ gần nhất nổi lên
	# xếp: cùng tỉ lệ k
	var g := 6.0
	var nT := T.size()
	var nL := LE.size()
	var gaps := 10.0 + 22.0 + maxf(0.0, nT - 1) * g + 12.0 + 22.0 + maxf(0.0, nL - 1) * g + 8.0
	var k := clampf((_hb - gaps) / (nT * 46.0 + nL * 58.0), 0.85, 1.5)
	var out := []
	var y := 10.0
	out.append_array(_hd(y, "Hôm nay trong làng"))
	y += 22.0
	for i in nT:
		var q: Array = T[i]
		out.append_array(_row(y, 46.0 * k, String(q[0]), q[1], String(q[2]), String(q[3]), String(q[4]), q[5]))
		y += 46.0 * k + (g if i < nT - 1 else 0.0)
	y += 12.0
	out.append_array(_hd(y, "Lễ hội"))
	y += 22.0
	for i in nL:
		var q: Array = LE[i][1]
		out.append_array(_row(y, 58.0 * k, String(q[0]), q[1], String(q[2]), String(q[3]), String(q[4]), q[5]))
		y += 58.0 * k + (g if i < nL - 1 else 0.0)
	return [out, y + 8.0]

static func _tr(v) -> bool:
	return not (v == null or v is bool and not v or (v is float or v is int) and v == 0 or v is String and v == "")
