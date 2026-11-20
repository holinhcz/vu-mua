extends "res://logic/ui_kbang.gd"
# SỔ NHIỆM VỤ (bản 410): khung Kho + chip chung (ui_kbang.gd), 4 tab Hằng ngày · Tuần · Thành tựu · Sự kiện.
# Một dạng dòng chung cho cả 4 tab (_row): ô trái (điểm / bậc / mốc), tên + thanh tiến độ cùng bề dài, số "0/10" cuối thanh,
# bên phải: nút xanh "Nhận" khi đủ, dấu ✓ khi xong, không thì chip "Đi làm" (dòng việc nào cũng có, _go đưa tới chỗ làm).
# Đầu tab Hằng ngày / Tuần: thanh điểm có hình quà gắn đúng vị trí mốc trên thanh (_ms), không thẻ kem.
# Chuỗi ngày đủ 100 năng động (nv.gd iY): một khối chữ + 7 chấm, chấm 7 là quà vòng kế tiếp; chạm hiện cách tính.
# Luật ở nv.gd; mẫu kiểu chữ, hình quà: ui/snap/dd.json (ui_kbang).

const TABS := [["ngay", "Hằng ngày"], ["tuan", "Tuần"], ["tt", "Thành tựu"], ["sk", "Sự kiện"]]
const SWAP := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><g fill=\"none\" stroke=\"rgb(128,98,58)\" stroke-width=\"2.4\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M4 9h13l-3.5-3.5\"/><path d=\"M20 15H7l3.5 3.5\"/></g></svg>"
const TRACK := "rgb(242, 222, 172)"   # rãnh thanh: vàng kem ấm
const RH := 42.0      # cao dòng
const BW := 52.0      # chỗ nút bên phải (cố định: thanh mọi dòng dài bằng nhau)
const GAPR := 6.0     # cách dòng

# (bản 411) màu theo nhóm việc (ô trái + thanh), theo bậc thành tựu: [gradient trên, giữa, dưới, viền], màu thanh
const NVC := {
	"g_ruong": ["rgb(206, 234, 178)", "rgb(216, 240, 192)", "rgb(228, 246, 208)", "rgb(96, 160, 60)", "rgb(76, 150, 48)"],
	"g_nuoi": ["rgb(250, 208, 168)", "rgb(252, 218, 184)", "rgb(254, 230, 204)", "rgb(200, 116, 50)", "rgb(214, 120, 44)"],
	"g_xuong": ["rgb(222, 206, 240)", "rgb(230, 216, 246)", "rgb(238, 228, 250)", "rgb(138, 104, 186)", "rgb(132, 96, 190)"],
	"g_song": ["rgb(190, 222, 246)", "rgb(204, 230, 250)", "rgb(220, 238, 252)", "rgb(70, 140, 200)", "rgb(52, 132, 200)"],
	"g_lang": ["rgb(250, 202, 210)", "rgb(252, 214, 222)", "rgb(254, 228, 234)", "rgb(206, 100, 126)", "rgb(214, 92, 124)"],
	"g_cho": ["rgb(255, 230, 150)", "rgb(255, 238, 180)", "rgb(255, 246, 208)", "rgb(214, 160, 30)", "rgb(222, 156, 20)"],
	"fire_l": ["rgb(255, 214, 178)", "rgb(255, 224, 194)", "rgb(255, 234, 212)", "rgb(226, 120, 50)", "rgb(232, 112, 40)"],
	"b0": ["rgb(226, 196, 128)", "rgb(233, 206, 144)", "rgb(240, 218, 165)", "rgb(150, 108, 40)", "rgb(176, 128, 52)"],
	"b1": ["rgb(206, 234, 178)", "rgb(216, 240, 192)", "rgb(228, 246, 208)", "rgb(96, 160, 60)", "rgb(76, 150, 48)"],
	"b2": ["rgb(190, 222, 246)", "rgb(204, 230, 250)", "rgb(220, 238, 252)", "rgb(70, 140, 200)", "rgb(52, 132, 200)"],
	"b3": ["rgb(222, 206, 240)", "rgb(230, 216, 246)", "rgb(238, 228, 250)", "rgb(138, 104, 186)", "rgb(132, 96, 190)"],
	"b4": ["rgb(255, 214, 140)", "rgb(255, 226, 168)", "rgb(255, 238, 196)", "rgb(220, 140, 20)", "rgb(230, 140, 20)"],
}
const GRP := {"harvest": "g_ruong", "plant": "g_ruong", "water": "g_ruong", "kl": "g_ruong", "tharvest": "g_ruong", "scn": "g_ruong",
	"collect": "g_nuoi", "dz": "g_nuoi", "wc": "g_xuong", "xuong": "g_xuong", "fish": "g_song", "bun": "g_song", "lo": "g_song", "dd": "g_song",
	"chat": "g_lang", "gift": "g_lang", "help": "g_lang", "giup": "g_lang", "vg": "g_lang", "com": "g_lang", "gop": "g_lang",
	"deliver": "g_cho", "cho": "g_cho"}
const FIRE := "rgb(232, 112, 40)"
func _ck(kind: String) -> Array:
	if kind.begins_with("l_") and NVC.has(kind.substr(2)):   # nền dòng ngả màu nhóm thật nhạt
		var g := Color.html(_hex(String(NVC[kind.substr(2)][4])))
		return [_rgb(g.lerp(Color.WHITE, 0.82)), _rgb(g.lerp(Color.WHITE, 0.87)), _rgb(g.lerp(Color.WHITE, 0.92)), _rgb(g.lerp(Color.WHITE, 0.45))]
	return NVC[kind] if NVC.has(kind) else super(kind)

static func _hex(rgb: String) -> String:   # "rgb(a, b, c)" -> "#rrggbb"
	var p := rgb.replace("rgb(", "").replace(")", "").split(",")
	return "#%02x%02x%02x" % [int(p[0]), int(p[1]), int(p[2])]

static func _rgb(c: Color) -> String:
	return "rgb(%d, %d, %d)" % [int(c.r8), int(c.g8), int(c.b8)]

func _trk(lk: String) -> String:   # rãnh thanh theo nhóm: đậm hơn nền dòng một chút
	if not NVC.has(lk):
		return TRACK
	return _rgb(Color.html(_hex(String(NVC[lk][4]))).lerp(Color.WHITE, 0.72))

# hình của việc (hình món Kho)
const TIC := {"harvest": "lua", "plant": "pc_cuoc", "water": "pc_binh", "kl": "bido", "tharvest": "qua_xoai", "scn": "cui",
	"collect": "trung", "dz": "pc_non", "wc": "gao", "xuong": "banh_tet", "fish": "ca_loc", "bun": "ca_keo", "lo": "tep", "dd": "dien_dien",
	"chat": "tra_tac", "gift": "banh_pia", "help": "chieu", "giup": "chieu", "vg": "long_den", "com": "com_tam", "gop": "gao",
	"deliver": "pc_gui", "cho": "qua_chuoi", "ruong": "lua", "chuong": "trung", "kho": "pc_xe", "sap": "qua_chuoi"}
static func _ti(id: String) -> String:
	return "kh:" + String(TIC.get(id, "lua"))

static func _gk(id: String) -> String:   # nhóm màu của việc
	return String(GRP.get(id, "tre"))

var N        # nv.gd
var tab := "ngay"
var bdg: Control = null
var bdg_n := -1
var _bt := 0.0

func _init(ui) -> void:
	super(ui)
	N = ui.G.nv

func open(t := "") -> void:
	if t != "":
		tab = t
	U.close_all()
	U.kho_close()
	on = true
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:
	_bt -= dt
	if _bt <= 0.0:
		_bt = 0.5
		badge(U.hid.get("#nvBtn"))
	super(dt)

func _sig() -> String:
	return JSON.stringify([tab, N.Pl(), N.r5(), N.WP(), N.streak_now(), G.g.get("delivered", 0), G.g.sys.get("stats", {}), int(N._nowd() * 1440.0)])

func _tab_go(k: String) -> void:
	if tab != k:
		tab = k
		scroll = 0.0

func _build() -> void:
	sig = _sig()
	var R: Dictionary = N.ready_n()
	var L := []
	for t in TABS:
		L.append([t[0], t[1], int(R.get(t[0], 0)) > 0])
	var sh := _kshell(L, tab, _tab_go)
	var r: Array = _week() if tab == "tuan" else (_ach() if tab == "tt" else (_event() if tab == "sk" else _day()))
	_kmount(sh[0], sh[1], sh[2], r[0], float(r[1]))

# ------------------------------------------------------------------ khối chung
func _icn(cx: float, cy: float, sz: float, ic: String) -> Dictionary:   # hình việc không khung: "kh:<món>" hình món Kho, "d:<loại>" hình quà
	if ic.begins_with("d:"):
		return _dick(cx, cy, sz, ic.substr(2))
	var n := _dbx(cx - sz * 0.5, cy - sz * 0.5, sz, sz, "rgba(0, 0, 0, 0)", 0.0)
	n.ic = ic.substr(3)
	return n

func _bar(x: float, y: float, w: float, f: float, h := 5.0, trk := TRACK) -> Array:   # thanh tiến độ: màu chạy từ đỏ (mới bắt đầu) qua vàng tới xanh (đủ)
	var out := [_dbx(x, y, w, h, trk, h * 0.5)]
	if f > 0.0:
		out.append(_dbx(x, y, maxf(h, w * clampf(f, 0.0, 1.0)), h, _fcol(f), h * 0.5))
	return out

static func _fcol(f: float) -> String:
	var a := Color8(214, 72, 52)
	var b := Color8(230, 170, 30)
	var c := Color8(46, 150, 80)
	f = clampf(f, 0.0, 1.0)
	var k := a.lerp(b, f * 2.0) if f < 0.5 else b.lerp(c, (f - 0.5) * 2.0)
	return "rgb(%d, %d, %d)" % [int(k.r8), int(k.g8), int(k.b8)]

func _offbtn(x: float, y: float, w: float, h: float, t: String) -> Dictionary:   # nút chưa bấm được
	var c := _chip(x, y, w, h, "miss")
	c.kids = [_dt(x, y, w, h, t, 10.5, 700, "rgb(110, 104, 92)")]
	return c

# dòng chung (bản 413): lt = [hình, chữ bên phải (điểm "+15" / bậc "2/5" / mốc), nhóm màu]; vạch màu nhóm ở mép trái,
# hình việc không khung, tên + thanh dày 6, nút nhỏ. f < 0: không thanh; cnt: chữ cuối thanh; st: "go" / "claim" / "done" / "off" / ""
# act: việc của nút; sw: việc nút đổi (null = không); tip: chạm dòng hiện chữ
func _row(y: float, lt: Array, title: String, sub: String, f: float, cnt: String, st: String, act, btxt := "", sw = null, tip := "") -> Array:
	var lk: String = String(lt[2]) if lt.size() > 2 else "tre"
	var kind := "got" if st == "done" else ("now" if st == "claim" else ("l_" + lk if NVC.has(lk) else "fut"))
	var c := _chip(X0, y, XW, RH, kind)
	if tip != "":
		c.act = _dsay.bind(tip)
	var out := [c]
	var gc: String = String(NVC[lk][4]) if NVC.has(lk) else "rgb(176, 128, 52)"
	out.append(_dbx(X0 + 1.5, y + 8.0, 3.0, RH - 16.0, gc, 1.5))   # vạch màu nhóm
	if String(lt[0]) != "":
		out.append(_icn(X0 + 25.0, y + RH * 0.5, 28.0, String(lt[0])))
	var x := X0 + 46.0
	var bx := X0 + XW - BW - 6.0
	var tag := String(lt[1])
	var gw := 34.0   # chỗ chữ điểm / bậc: cố định cho thanh mọi dòng dài bằng nhau
	var tw := bx - 6.0 - gw - x
	if tag != "":
		out.append(_dt(bx - 4.0 - gw, y, gw, RH, tag, 12.0, 800, gc, "right"))
	var tt := tw - (26.0 if sw != null else 0.0)
	out.append(_dt(x, y + 6.0, tt, 16.0, _fitw(title, 12.0, 800, tt), 12.0, 800, BROWN, "left"))
	if sw != null:   # nút đổi việc: hình nhỏ cuối dòng tên
		var s := _chip(x + tw - 22.0, y + 4.0, 22.0, 18.0, "fut")
		s.kids = [_dic(x + tw - 18.0, y + 5.0, 16.0, SWAP)]
		s.act = sw
		out.append(s)
	if f >= 0.0:
		var cw: float = Box.text_w(cnt, 10.0, 700) + 6.0
		out.append_array(_bar(x, y + 27.0, tw - cw, f, 6.0, _trk(lk)))
		out.append(_dt(x + tw - cw, y + 23.0, cw, 14.0, cnt, 10.0, 700, SUB, "right"))
	else:
		out.append(_dt(x, y + 23.0, tw, 14.0, _fitw(sub, 10.0, 600, tw), 10.0, 600, SUB, "left"))
	var bh := 22.0
	var by := y + (RH - bh) * 0.5
	match st:
		"done":
			out.append(_dtick(bx + (BW - 20.0) * 0.5, y + (RH - 20.0) * 0.5, 20.0))
		"claim":
			out.append(_sbtn(_onbtn(bx, by, BW, bh, btxt if btxt != "" else "Nhận", act, true)))   # nhận: chip đỏ, khác "Đi làm" xanh
		"go":
			out.append(_sbtn(_onbtn(bx, by, BW, bh, btxt if btxt != "" else "Đi làm", act)))
		"off":
			out.append(_offbtn(bx, by, BW, bh, btxt))
	return out

func _sbtn(b: Dictionary) -> Dictionary:   # nút chip Kho cỡ nhỏ: chữ 11
	var t: Dictionary = b.kids[0]
	t.css["font-size"] = _cpx(11.0)
	return b

func _sub(y: float, t: String) -> Dictionary:   # dòng chữ nhỏ dưới tiêu đề phần
	return _dt(X0 + 2.0, y, XW - 4.0, 13.0, _fitw(t, 10.0, 600, XW - 4.0), 10.0, 600, SUB, "left")

# thanh điểm + hình quà gắn đúng mốc: L = [[điểm mốc, hình, đã nhận, việc nhận]]; trả [khối, cao]
func _ms(y: float, name: String, cur: int, top: int, L: Array, g := 8.0) -> Array:   # g: chip tên -> hàng hình
	var out := []
	var mw: float = Box.text_w(name, 12.5, 800) + 24.0
	out.append(_onbtn(X0, y, mw, 26.0, name, null, true))   # tên khối trong chip đỏ (như chip mùa của Trời đất)
	var vs := str(cur)
	var tw: float = Box.text_w("/" + str(top), 11.0, 700)
	var vw: float = Box.text_w(vs, 14.0, 800)
	out.append(_dt(X0 + XW - 2.0 - tw - vw, y + 4.0, vw, 18.0, vs, 14.0, 800, GREEN, "left"))
	out.append(_dt(X0 + XW - 2.0 - tw, y + 6.0, tw, 16.0, "/" + str(top), 11.0, 700, SUB, "left"))
	var cs := 34.0
	var iy := y + 26.0 + g
	var bxl := X0 + cs * 0.5
	var bxw := XW - cs
	var by := iy + cs + 6.0
	out.append_array(_bar(X0 + 2.0, by, XW - 4.0, float(cur) / float(maxi(1, top)), 7.0))
	for m in L:
		var p := int(m[0])
		var cx := bxl + bxw * float(p) / float(maxi(1, top))
		var got: bool = m[2]
		var ok := cur >= p
		var c := _chip(cx - cs * 0.5, iy, cs, cs, "got" if got else ("now" if ok else "fut"))
		var ks := [_dick(cx, iy + cs * 0.5, 24.0, String(m[1]), 0.5 if got else 1.0)]
		if got:
			ks.append(_dtick(cx + cs * 0.5 - 13.0, iy + cs - 13.0, 11.0))
		c.kids = ks
		if ok and not got:
			c.act = m[3]
		out.append(c)
		out.append(_dbx(cx - 1.0, by - 1.0, 2.0, 9.0, "rgb(190, 160, 100)" if not ok else "rgb(32, 112, 58)", 1.0))
		out.append(_dt(cx - 20.0, by + 11.0, 40.0, 12.0, str(p), 9.5, 700, SUB))
	return [out, by + 11.0 + 12.0 - y]

# ------------------------------------------------------------------ tab Hằng ngày
func _day() -> Array:
	var n: Dictionary = N.Pl()
	var ap: int = N.r5()
	var out := []
	# cách đều: g = chip tên -> nội dung, 2g = giữa hai khối; giãn sao cho đáy khung vừa đúng 4 dòng việc
	var fix := 8.0 + (89.0 + 60.0 + 26.0 + 4.0 * RH + 3.0 * GAPR) + 4.0
	var g := clampf((_hb - fix) / 7.0, 6.0, 14.0)
	var y := 8.0
	var L := []
	for c in N.E8:
		L.append([int(c.p), String(c.ic), n.cl.has(str(c.p)), N.IL.bind(int(c.p))])
	var ms := _ms(y, "Năng động", ap, 100, L, g)
	out.append_array(ms[0])
	y += float(ms[1]) + 2.0 * g
	# chuỗi ngày đủ 100 năng động
	var s: Dictionary = N.SI()
	var d: int = N.d4()
	var c: int = N.streak_now()
	var today: bool = int(s.last) == d
	var pos := c % 7
	if today and pos == 0 and c > 0:
		pos = 7
	var k := int(floor(float(c - 1 if today else c) / 7.0)) + 1
	var bn: int = N.bonus(c)
	var rest_ok: bool = int(s.rw) != N.week()
	var tip := "Ngày nào đủ 100 năng động thì chuỗi thêm 1 ngày (+xu). Mỗi tuần được nghỉ 1 ngày không đứt chuỗi; bỏ quá thì chuỗi lùi về mốc 7 gần nhất. Tròn 7 ngày được quà vòng. Chuỗi dài: xu rương +5% (7 ngày) tới +50% (100 ngày)."
	var t1 := "Chuỗi " + str(c) + " ngày"
	var w1: float = Box.text_w(t1, 12.5, 800)
	var hit := _dbx(X0, y - 2.0, XW, 64.0 + g, "rgba(0, 0, 0, 0)", 0.0)
	hit.act = _dsay.bind(tip)
	out.append(hit)
	var cw1 := w1 + 24.0
	var cc := _chip(X0, y, cw1, 26.0, "fire_l")   # tên khối trong chip cam nhạt (màu lửa của chấm)
	cc.kids = [_dt(X0, y, cw1, 26.0, t1, 12.5, 800, "rgb(150, 66, 16)")]
	out.append(cc)
	var t2 := (("đã đủ" if today else "chưa đủ") + " · rương +" + str(bn) + "%") if bn else ("hôm nay đã đủ 100" if today else "hôm nay chưa đủ 100")
	var rt := "Nghỉ còn 1" if rest_ok else "Nghỉ hết"
	var rw: float = Box.text_w(rt, 10.0, 700) + 14.0
	var t2w := XW - cw1 - 8.0 - rw - 6.0
	out.append(_dt(X0 + cw1 + 8.0, y + 5.0, t2w, 16.0, _fitw(t2, 10.5, 600, t2w), 10.5, 600, GREEN if today else SUB, "left"))
	var rc := _chip(X0 + XW - rw, y + 4.0, rw, 18.0, "fut" if rest_ok else "miss")
	rc.kids = [_dt(X0 + XW - rw, y + 4.0, rw, 18.0, rt, 10.0, 700, SUB)]
	out.append(rc)
	var dy := y + 26.0 + g
	var ds := 19.0
	var gx := 5.0
	for i in 6:
		var dx := X0 + 4.0 + i * (ds + gx)
		var on_d := i < pos
		out.append(_dbx(dx, dy + 7.5, ds, ds, FIRE if on_d else "rgb(255, 250, 238)", ds * 0.5, _cpx(1.0) + " solid " + ("rgb(196, 86, 24)" if on_d else "rgb(236, 168, 116)")))
		out.append(_dt(dx, dy + 7.5, ds, ds, str(i + 1), 10.0, 800, "rgb(255, 255, 255)" if on_d else "rgb(200, 110, 50)"))
	var gxp := X0 + 4.0 + 6.0 * (ds + gx)
	var gc := _chip(gxp, dy, 34.0, 34.0, "got" if pos >= 7 else "sen")
	gc.kids = [_dick(gxp + 17.0, dy + 17.0, 24.0, "gift")]
	out.append(gc)
	var tx := gxp + 42.0
	out.append(_dt(tx, dy + 2.0, X0 + XW - tx, 14.0, "Đủ 7 ngày được:", 10.0, 600, SUB, "left"))
	out.append(_dt(tx, dy + 17.0, X0 + XW - tx, 16.0, _fitw(N.round_n(k), 11.5, 800, X0 + XW - tx), 11.5, 800, BROWN, "left"))
	y = dy + 34.0 + 2.0 * g
	# việc hôm nay
	out.append_array(_shd(y, "Việc hôm nay", "làm mới sau " + N.ao((1.0 - fposmod(N._nowd(), 1.0)) * 86400.0)))
	y += 26.0 + g
	var TL: Array = N.MI()
	TL = TL.filter(func(t): return not N.done(t)) + TL.filter(func(t): return N.done(t))   # việc xong xuống cuối, giữ thứ tự
	for t in TL:
		var c2: int = N.task_f(t)
		var m := int(t.m)
		var dn: bool = N.done(t)
		var sw = null
		if not dn and not n.sw and not N.is_base(t):
			sw = _swap.bind(String(t.id))
		out.append_array(_row(y, [_ti(String(t.id)), "+" + str(N.pt(t)), _gk(String(t.id))], String(t.n), "", float(c2) / float(m), G.fmt_n(mini(c2, m)) + "/" + G.fmt_n(m),
			"done" if dn else "go", _go.bind(String(t.id)), "", sw))
		y += RH + GAPR
	return [out, y + 4.0]

func _swap(tid: String) -> void:
	N.swap(tid)
	if N.Pl().sw:
		_dsay("Đã đổi việc. Mỗi ngày đổi được 1 việc.")

func _shd(y: float, t: String, right: String) -> Array:   # tên phần trong chip nâu vàng + chữ phụ bên phải (như khối Chuỗi)
	var w: float = Box.text_w(t, 12.5, 800) + 24.0
	var c := _chip(X0, y, w, 26.0, "tre")
	c.kids = [_dt(X0, y, w, 26.0, t, 12.5, 800, BROWN)]
	return [c, _dt(X0 + w + 8.0, y + 5.0, XW - w - 8.0, 16.0, right, 10.5, 600, SUB, "left")]


# ------------------------------------------------------------------ tab Tuần
func _week() -> Array:
	var w: Dictionary = N.Pl().wk
	var wpt: int = N.WP()
	var top: int = N.wk_top()
	var left: float = N.week_left()
	var out := []
	var y := 8.0
	var L := []
	for i in N.NVWCH.size():
		L.append([N.wk_p(i), String(N.NVWCH[i].ic), w.cl.has("m" + str(i)), N.wk_chest.bind(i)])
	var fix := 8.0 + (89.0 + 17.0 + 26.0 + 4.0 * RH + 3.0 * GAPR) + 4.0
	var g := clampf((_hb - fix) / 4.0, 6.0, 14.0)
	var ms := _ms(y, "Điểm tuần", wpt, top, L, g)
	out.append_array(ms[0])
	y += float(ms[1]) + 4.0
	var lt: String = (str(int(floor(left / 86400.0))) + " ngày" if left >= 86400.0 else N.ao(left))
	out.append(_sub(y, "Mốc cuối: " + String(N.deco_of(N.week())[1]) + " + 5 sen đỏ · còn " + lt))
	y += 13.0 + 2.0 * g
	out.append_array(_shd(y, "Việc tuần này", "làm mới sau " + N.ao(left)))
	y += 26.0 + g
	var WL: Array = N.wk_list()
	var wd := func(t) -> bool: return N.nvW(t.id) >= int(t.m)
	WL = WL.filter(func(t): return not wd.call(t)) + WL.filter(func(t): return wd.call(t))   # việc xong xuống cuối
	for t in WL:
		var c: int = N.nvW(t.id)
		var m := int(t.m)
		out.append_array(_row(y, [_ti(String(t.id)), "+" + str(t.pt), _gk(String(t.id))], String(t.n), "", float(c) / float(m), G.fmt_n(mini(c, m)) + "/" + G.fmt_n(m),
			"done" if c >= m else "go", _go.bind(String(t.id))))
		y += RH + GAPR
	return [out, y + 4.0]

# ------------------------------------------------------------------ tab Thành tựu
func _ach() -> Array:
	var s: Dictionary = N.SI()
	var out := []
	var y := 8.0
	# danh hiệu chuỗi ngày: một dòng, danh hiệu kế tiếp + tiến độ chuỗi dài nhất
	var best := int(s.best)
	var nx = null
	var cur := ""
	for x in N.NVSK:
		if best >= int(x[0]):
			cur = x[1]
		elif nx == null:
			nx = x
	var all := []
	for x in N.NVSK:
		all.append(String(x[1]) + " (" + str(x[0]) + " ngày)")
	var tip := "Danh hiệu theo chuỗi dài nhất đủ 100 năng động: " + ", ".join(all) + "."
	out.append_array(_hd(y, "Danh hiệu chuỗi ngày"))
	y += 22.0
	if nx == null:
		out.append_array(_row(y, ["d:gift", "", "b4"], cur, "Đã đạt đủ 5 danh hiệu", -1.0, "", "done", null, "", null, tip))
	else:
		out.append_array(_row(y, ["d:gift", "", "b0"], String(nx[1]), "", float(best) / float(nx[0]), str(best) + "/" + str(nx[0]),
			"", null, "", null, tip))
		var ct := cur if cur != "" else "Chưa có"
		var cc := _chip(X0 + XW - BW - 6.0, y + 10.0, BW, RH - 20.0, "b4" if cur != "" else "miss")
		cc.kids = [_dt(X0 + XW - BW - 6.0, y + 10.0, BW, RH - 20.0, _fitw(ct, 9.5, 700, BW - 4.0), 9.5, 700, BROWN if cur != "" else "rgb(110, 104, 92)")]
		out.append(cc)
	y += RH + 14.0
	out.append_array(_hd(y, "Thành tựu"))
	out.append(_sub(y + 18.0, "Mỗi thành tựu 5 bậc: " + ", ".join(N.T9).to_lower() + "."))
	y += 36.0
	for A in N.L8:
		var t: int = N.A8(A)
		var v: int = N.ach_f(A)
		var lt: Array = [_ti(String(A.k)), str(t) + "/5", "b" + str(mini(t, 4))]
		if t >= 5:
			out.append_array(_row(y, lt, String(A.n) + " · " + N.T9[4], G.fmt_n(v) + " " + String(A.d), -1.0, "", "done", null))
		else:
			var need: int = N.S9(A, t)
			var R: Dictionary = N.ach_rw(t)
			var ok: bool = v >= need
			var rw: String = str(R.ng) + " sen đỏ, " + G.fmt_n(R.xu) + " xu"
			out.append_array(_row(y, lt, String(A.n) + " · " + N.T9[t], "", float(v) / need, G.fmt_n(mini(v, need)) + "/" + G.fmt_n(need),
				"claim" if ok else "go", N.BI.bind(String(A.k)) if ok else _go.bind(String(A.k)), "", null, "Bậc " + N.T9[t].to_lower() + ": " + rw + "."))
		y += RH + GAPR
	y += 8.0
	out.append_array(_hd(y, "Công trình"))
	out.append(_sub(y + 18.0, "Xong việc này hiện việc tiếp theo."))
	y += 36.0
	for L in N.w9():
		var i: int = N.M9(L)
		if i >= L.steps.size():
			out.append_array(_row(y, [_ti(String(L.k)), "", "tre"], String(L.n), "Đã xong cả chuỗi", -1.0, "", "done", null))
		else:
			var st: Dictionary = L.steps[i]
			var c: int = N.step_f(st)
			var R: Dictionary = N.AI(i)
			var ok: bool = c >= int(st.m)
			out.append_array(_row(y, [_ti(String(L.k)), str(i + 1) + "/" + str(L.steps.size()), {"ruong": "g_ruong", "xuong": "g_xuong", "chuong": "g_nuoi", "sap": "g_cho"}.get(String(L.k), "tre")], String(L.n) + ": " + String(st.t), "", float(c) / float(st.m),
				G.fmt_n(mini(c, int(st.m))) + "/" + G.fmt_n(int(st.m)), "claim" if ok else "go", N.zI.bind(String(L.k)) if ok else _go.bind("ln_" + String(L.k)),
				"", null, "Thưởng " + G.fmt_n(R.xu) + " xu, " + str(R.m) + " vật liệu " + String(L.n).to_lower() + "."))
		y += RH + GAPR
	return [out, y + 4.0]

# ------------------------------------------------------------------ tab Sự kiện
func _event() -> Array:
	var x: Dictionary = N.wp()
	var EL: Array = N.jL(x.c)
	var EN: Array = N.jL(x.c + 1)
	var ev: Dictionary = N.ff()
	var s = N.ev()
	if ev.id == "cho":
		N.DL()
	var out := []
	var y := 8.0
	if ev.id == "":
		out.append(_dt(X0 + 2.0, y, XW, 16.0, "Hôm nay không có sự kiện", 12.5, 800, BROWN, "left"))
		y += 22.0
	else:
		out.append(_dt(X0 + 2.0, y, XW - 110.0, 16.0, String(ev.n), 12.5, 800, BROWN, "left"))
		out.append(_dt(X0 + XW - 110.0, y, 108.0, 16.0, "còn " + N.vY(int(ev.d1)), 10.5, 700, SUB, "right"))
		var dl := _wrap(String(ev.d), 10.0, 600, XW - 4.0)
		for i in dl.size():
			out.append(_dt(X0 + 2.0, y + 20.0 + i * 13.0, XW - 4.0, 13.0, dl[i], 10.0, 600, SUB, "left"))
		y += 20.0 + dl.size() * 13.0 + 10.0
	if ev.id == "hoi":
		var dp := int(s.day.get(str(x.d), 0))
		var g := 5.0
		var cw := (XW - g * 4.0) / 5.0
		for i in 5:
			var cx := X0 + i * (cw + g)
			var kd := "miss" if i < int(x.d) else _gk(String(N.FL[i].k))
			var c := _chip(cx, y, cw, 36.0, kd)
			if i == int(x.d):   # chặng hôm nay: viền đậm
				c.css["box-shadow"] = String(c.css["box-shadow"]).replace("0px 0px 0px 1px inset", "0px 0px 0px 2px inset")
			c.kids = [_dt(cx, y + 4.0, cw, 12.0, "Chặng " + str(i + 1), 9.0, 600, SUB), _dt(cx, y + 17.0, cw, 15.0, _cap1(String(N.FL[i].n).replace("Ngày ", "")), 10.5, 800, BROWN)]
			c.act = _dsay.bind(String(N.FL[i].n) + ": " + String(N.FL[i].d) + ".")
			out.append(c)
		y += 36.0 + 14.0
		var st: Dictionary = N.FL[int(x.d)]
		out.append_array(_hd(y, "Hôm nay: " + String(st.n)))
		out.append(_sub(y + 18.0, String(st.d)))
		y += 36.0
		var nm := ["Túi xu", "2 vật liệu", "1 sen đỏ"]
		for i in 3:
			var ok: bool = dp >= N.GL[i]
			var got: bool = s.cl.has("d:" + str(x.d) + ":" + str(i))
			out.append_array(_row(y, ["d:" + ["coin", "crate", "pearl"][i], "", _gk(String(st.k))], nm[i], "", float(dp) / N.GL[i], G.fmt_n(mini(dp, N.GL[i])) + "/" + G.fmt_n(N.GL[i]),
				"done" if got else ("claim" if ok else "go"), N.FI.bind("d", i) if ok else _go.bind(String(st.k))))
			y += RH + GAPR
		y += 8.0
		out.append_array(_hd(y, "Cộng dồn 5 ngày"))
		y += 22.0
		nm = ["Túi xu lớn", "3 sen đỏ, 6 vật liệu kho", "8 sen đỏ, bùa +50% EXP"]
		for i in 3:
			var ok: bool = int(s.p) >= N.WL[i]
			var got: bool = s.cl.has("t:" + str(i))
			out.append_array(_row(y, ["d:" + ["coin", "crate", "pearl"][i], "", _gk(String(st.k))], nm[i], "", float(s.p) / N.WL[i], G.fmt_n(mini(int(s.p), N.WL[i])) + "/" + G.fmt_n(N.WL[i]),
				"done" if got else ("claim" if ok else "go"), N.FI.bind("t", i) if ok else _go.bind(String(st.k))))
			y += RH + GAPR
	elif ev.id == "cho":
		out.append_array(_hd(y, "Vé chợ: " + str(s.ve)))
		out.append(_sub(y + 18.0, "10 điểm năng động = 1 vé · mỗi đơn giao = 2 vé"))
		y += 36.0
		for it in N.HI:
			var lim: bool = it.has("max") and int(s.buy.get(it.id, 0)) >= int(it.max)
			var ok: bool = int(s.ve) >= int(it.c) and not lim
			var sb := String(it.d) + (" · còn " + str(int(it.max) - int(s.buy.get(it.id, 0))) if it.has("max") else "")
			out.append_array(_row(y, ["d:" + String(it.get("ic", "coin")), str(it.c) + " vé", "g_cho"], String(it.n), sb, -1.0, "", "claim" if ok else "off", N.sY.bind(String(it.id)), "Đổi" if ok else ("Hết lượt" if lim else "Thiếu vé")))
			y += RH + GAPR
	elif ev.id == "ngoc":
		out.append_array(_hd(y, "Đã tiêu " + str(s.sp) + " sen đỏ"))
		out.append(_sub(y + 18.0, "Làm chín ngay, bù thiếu, đổi sen đỏ… đều tính"))
		y += 36.0
		for i in N.VL.size():
			var M: Dictionary = N.VL[i]
			var ok: bool = int(s.sp) >= int(M.p)
			var got: bool = s.cl.has("n" + str(i))
			out.append_array(_row(y, ["d:" + ["coin", "crate", "bua", "pearl"][i], "", "g_lang"], String(M.n), "", float(s.sp) / float(M.p), G.fmt_n(mini(int(s.sp), int(M.p))) + "/" + G.fmt_n(int(M.p)),
				"done" if got else ("claim" if ok else "off"), N.hY.bind(i), "Chưa đủ"))
			y += RH + GAPR
	# sự kiện kế tiếp
	var nx = null
	for e in EL:
		if int(e.d0) > int(x.d):
			nx = {"id": e.id, "n": e.n, "d0": int(e.d0)}
			break
	if nx == null and EN.size() > 0:
		nx = {"id": EN[0].id, "n": EN[0].n, "d0": int(EN[0].d0) + 14}
	if nx != null:
		y += 6.0
		out.append_array(_hd(y, "Sắp tới"))
		y += 22.0
		var dn := int(nx.d0) - int(x.d)
		out.append_array(_row(y, ["d:gift", "", "tre"], String(nx.n), "Nhớ để dành sen đỏ" if nx.id == "ngoc" else "Bắt đầu sau " + str(dn) + " ngày", -1.0, "", "", null))
		y += RH + GAPR
	return [out, y + 4.0]

func _wrap(t: String, fs: float, fw: int, w: float) -> Array:   # xuống dòng theo bề ngang
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

# ------------------------------------------------------------------ Đi làm: đóng sổ, đưa tới chỗ làm việc đó
const HINT := {"tharvest": "Ra vườn hái trái chín.", "scn": "Chạm bụi cây, gốc cây trên làng để dọn.", "dd": "Ra ven sông hái bụi điên điển.",
	"bun": "Ra ruộng bắt cá kèo, mò ốc.", "lo": "Ra mé sông thăm lờ, lọp.", "help": "Vào hợp tác xã giúp bà con trong xã.", "giup": "Vào hợp tác xã giúp bà con trong xã.",
	"com": "Trưa 12:00–12:30 góp nồi cơm ở sân đình.", "gop": "Vào hợp tác xã góp hàng.", "dz": "Ra sân đá dế.", "kl": "Trồng ruộng, gặt có lúc ra trái khủng.",
	"ln_ruong": "Chạm ô ruộng khóa để mở thêm, nâng sao ô ruộng.", "ln_xuong": "Xây và nâng xưởng ở Xây dựng.", "ln_chuong": "Xây chuồng, mua con vật ở Xây dựng.",
	"ln_kho": "Chạm kho để nâng sao.", "ln_sap": "Giao đơn hàng, nâng sạp ở chợ."}

func _go(tid: String) -> void:
	close()
	match tid:
		"deliver", "ln_sap":
			U.ord_open()
			return
		"fish":
			U.pcp.open("cau")
			return
		"cho":
			G.w_all.WCU._pill_go()
			return
		"harvest", "kl":
			if _plot(func(i): return G.ripe(G.p(i)), "Chưa có ô ruộng nào chín."):
				return
		"plant":
			if _plot(func(i): return G.p(i).c == null, "Không còn ô ruộng trống."):
				return
		"water":
			if _plot(func(i): var a: Dictionary = G.p(i); return a.c != null and not G.ripe(a) and float(a.w) < G.water_hold(a) - 0.5, "Ruộng đang đủ nước."):
				return
		"collect", "ln_chuong":
			for t in ["ga", "cuu", "bo", "heo", "de"]:
				if G.vn.ok(t):
					var p: Vector2i = G.lang.pen_pos(t)
					_cam(p.x + 1.0, p.y + 1.0)
					return
		"wc", "xuong":
			var L: Array = G.xw.list_built()
			if L.size():
				U.xf_open(String(L[0]))
				return
		"chat", "gift", "vg":
			var H: Array = G.w_all.WL.bl()
			if H.size():
				U.vl_open(int(H[0].u))
				return
	G.toast.emit(String(HINT.get(tid, "Ra làng làm việc này nhé.")))

func _plot(ok: Callable, none: String) -> bool:   # đưa máy quay tới ô ruộng đầu tiên hợp việc
	for i in G.cells.size():
		if G.owned(i) and ok.call(i):
			_cam(float(G.cells[i].gx) + 0.5, float(G.cells[i].gy) + 0.5)
			return true
	G.toast.emit(none)
	return true

func _cam(x: float, y: float) -> void:
	var f = G.w_all.WCU.ext.get("camTo")
	if f is Callable:
		f.call(x, y, 0.0)

# ------------------------------------------------------------------ chấm đỏ nút Nhiệm vụ (mY)
func badge(btn: Control) -> void:
	if btn == null:
		return
	var R: Dictionary = N.ready_n()
	var n: int = int(R.ngay) + int(R.tuan) + int(R.tt) + int(R.sk)
	if n == bdg_n:
		return
	bdg_n = n
	if bdg != null:
		bdg.queue_free()
		bdg = null
	if n <= 0:
		return
	var src: Dictionary = Snap.find(Snap.load_snap("nv_bdg")["#nvBtn"][0], "bdg").duplicate(true)
	var s := str(n)
	var w := maxf(float(src.r[2]), _tw(src, s) + 6.0)
	var rx := float(src.r[0]) + float(src.r[2])
	src.r = [rx - w, src.r[1], w, src.r[3]]
	var tw := _tw(src, s)
	src.text = s
	src.tr = [rx - w + (w - tw) * 0.5, float(src.get("tr", src.r)[1]), tw + 0.5, float(src.get("tr", src.r)[3])]
	var bn: Dictionary = btn.get_meta("snap", {})
	var bo: Vector2 = Vector2(float(bn.r[0]), float(bn.r[1])) if bn.has("r") else btn.r.position
	bdg = U._build(src, {}, bo)
	btn.add(bdg)

static func _cap1(t: String) -> String:   # chữ đầu viết hoa
	return t.substr(0, 1).to_upper() + t.substr(1)
