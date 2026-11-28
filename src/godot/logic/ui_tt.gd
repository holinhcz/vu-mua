extends "res://logic/ui_kbang.gd"
# (11-28) 7 NGÀY VỀ LÀNG (XI / iv bản web, nút 7 ngày ở cột sự kiện) trên khung chung (ui_kbang: khung sen, đáy chung),
#   thay hộp khung tre hẹp cũ (số mốc đè hình, chữ ngày dồn, dòng việc gãy dọc).
#   Đầu (cố định): thanh mốc chung _ms "Điểm khai hoang" 5 rương (40 / 100 / 160 / 220 / 280); hàng 7 ô ngày (khóa xám,
#   đang xem viền vàng, xong dấu tích, chấm đỏ còn quà). Thân: tiêu đề ngày, dòng quà điểm danh, 4 việc +10 điểm (thanh +
#   có / cần + Nhận), gói tân thủ hôm nay. Luật ở w_ev.gd.

var E          # w_ev.gd
var P9 := -1   # ngày đang xem
const DH := 36.0   # ô ngày
const RH := 48.0   # dòng việc

func _init(ui, wev) -> void:
	super(ui)
	E = wev

func open() -> void:   # XI
	if P9 < 0:
		P9 = E.ev() - 1
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	var e := clampi(P9, 0, 6)
	return JSON.stringify([e, E.ev(), E.V1(), E.RV[e].q.map(func(q): return E.qf(q)), E.XL(), int(Time.get_unix_time_from_system() / 60.0)])

func _day(d: int) -> void:
	P9 = d
	scroll = 0.0
	_build()

func _build() -> void:
	sig = _sig()
	var n: int = E.ev()
	var e := clampi(P9, 0, 6)
	var r: int = E.XL()
	var sh := _kshell([], "", func(_k): pass)
	var nd: Dictionary = sh[0]
	var vt: Dictionary = sh[1]
	# thanh mốc 5 rương
	var L := []
	for a in E.A9:
		var p := int(a.p)
		L.append([p, String(a.ic), E.ch(p), E.UI.bind(p), String(a.n), "Quà mốc " + str(p) + " điểm khai hoang"])
	var ms := _ms(0.0, "Điểm khai hoang", r, 280, L, 6.0, "img:sen")
	_kfix(nd, vt, ms[0], float(ms[1]), false)
	_kfix(nd, vt, _days(n, e), DH, false)
	var out := []
	var y := 4.0
	var f: Dictionary = E.RV[e]
	var s := e >= n
	out.append_array(_hd(y + 5.0, "Ngày " + str(e + 1) + " · " + String(f.n), "", 0.0, ("mở sau " + str(e + 1 - n) + " ngày") if s else ("còn " + G.ao(E.left_s()))))
	y += 26.0 + 6.0
	out.append_array(_gift(y, e, f, s))
	y += RH + 6.0
	for l in f.q.size():
		out.append_array(_task(y, e, l, f.q[l], s))
		y += RH + 6.0
	if not s and e == n - 1:   # gói tân thủ hôm nay
		y += GG - 6.0
		var P: Dictionary = E.PK[e]
		out.append_array(_hd(y + 5.0, "Gói tân thủ hôm nay"))
		y += 26.0 + 6.0
		var c := _chip(X0, y, XW, RH, "fut")
		var pw := 84.0
		c.kids = [_dick(X0 + 24.0, y + RH * 0.5, 30.0, "gift"),
			_dt(X0 + 46.0, y + 7.0, XW - 46.0 - pw - 8.0, 16.0, _fitw(String(P.t), 12.0, 800, XW - 46.0 - pw - 8.0), 12.0, 800, BROWN, "left"),
			_dt(X0 + 46.0, y + 25.0, XW - 46.0 - pw - 8.0, 14.0, "chỉ bán trong ngày", 10.5, 600, SUB, "left")]
		out.append(c)
		out.append(_btn(X0 + XW - pw - 8.0, y + (RH - 28.0) * 0.5, pw, 28.0, G.fmt_n(int(P.vnd)) + "đ", U.say.bind(U.SOON), "plain"))
		y += RH + 6.0
	_kmount(nd, vt, float(vt.r[1]), out, y - 6.0)

func _days(n: int, e: int) -> Array:   # hàng 7 ô ngày
	var out := []
	var cw := (XW - 6.0 * 6.0) / 7.0
	for d in 7:
		var x := X0 + d * (cw + 6.0)
		var lk: bool = d >= n
		var Q: Array = E.RV[d].q
		var all := true
		var any := false
		for l in Q.size():
			if not E.cl(d, l):
				all = false
				if E.qf(Q[l]) >= E.L9(Q[l]):
					any = true
		var done: bool = E.ci(d) and all
		var red: bool = not lk and (not E.ci(d) or any)
		var c := _chip(x, 0.0, cw, DH, "miss" if lk else ("sel" if done else "fut"), d == e)
		c.kids = [_dt(x, 0.0, cw, DH, str(d + 1), 17.0, 800, SUB if lk else (GREEN if done else BROWN))]   # (11-28) chỉ số ngày (chữ "Ngày" đã có ở tiêu đề thân): ô thoáng
		if done:
			c.kids.append(_dtick(x + cw - 13.0, DH - 14.0, 11.0))
		c.act = _day.bind(d)
		out.append(c)
		if red:
			out.append(_dbx(x + cw - 8.0, -2.0, 9.0, 9.0, "rgb(214, 69, 65)", 4.5, _cpx(1.0) + " solid rgb(255, 255, 255)"))
	return out

func _gift(y: float, e: int, f: Dictionary, s: bool) -> Array:   # dòng quà điểm danh ngày e
	var got: bool = E.ci(e)
	var c := _chip(X0, y, XW, RH, "got" if got else ("miss" if s else "now"))
	var bw := 74.0
	var tw := XW - 50.0 - bw - 10.0
	c.kids = [_dick(X0 + 24.0, y + RH * 0.5, 30.0, String(f.gift.ic), 0.5 if got else 1.0),
		_dt(X0 + 46.0, y + 7.0, tw, 16.0, "Quà điểm danh", 12.0, 800, BROWN, "left"),
		_dt(X0 + 46.0, y + 25.0, tw, 14.0, _fitw(String(f.gift.t), 10.5, 600, tw), 10.5, 600, SUB, "left")]
	var out := [c]
	var bx := X0 + XW - bw - 8.0
	var by := y + (RH - 28.0) * 0.5
	if got:
		out.append(_btn(bx, by, bw, 28.0, "Đã nhận", null, "off"))
	elif s:
		out.append(_btn(bx, by, bw, 28.0, "Chưa mở", null, "off"))
	else:
		out.append(_btn(bx, by, bw, 28.0, "Nhận", func():
			E.QI(e)
			_build()))
	return out

func _task(y: float, e: int, l: int, q: Dictionary, s: bool) -> Array:   # một việc +10 điểm
	var v: int = E.L9(q)
	var xq := clampi(E.qf(q), 0, v)
	var k: bool = E.cl(e, l)
	var M: bool = not s and xq >= v and not k
	var c := _chip(X0, y, XW, RH, "got" if k else ("miss" if s else ("now" if M else "fut")))
	var bw := 64.0
	var tx := X0 + 46.0
	var tw := XW - 46.0 - bw - 10.0
	c.kids = [_dt(X0 + 4.0, y, 38.0, RH, "+10", 14.0, 800, GREEN if not s else SUB),
		_dt(tx, y + 6.0, tw, 16.0, _fitw(E.CY(q), 12.0, 700, tw), 12.0, 700, BROWN, "left")]
	if not s:   # (11-28) ngày chưa mở: không thanh, không số (nút "Chưa mở" đã nói), trước chữ "Chưa mở" đè đuôi thanh
		c.kids.append_array(_bar(tx, y + 27.0, tw - 44.0, float(xq) / maxf(1.0, v), 6.0))
		c.kids.append(_dt(tx + tw - 40.0, y + 22.0, 40.0, 16.0, G.fmt_n(xq) + "/" + G.fmt_n(v), 10.5, 700, SUB, "right"))
	else:
		c.kids[1].r[1] = y + (RH - 16.0) * 0.5
	var out := [c]
	var bx := X0 + XW - bw - 8.0
	var by := y + (RH - 28.0) * 0.5
	if k:
		out.append(_dtick(bx + bw * 0.5 - 9.0, y + RH * 0.5 - 9.0, 18.0))
	elif M:
		out.append(_btn(bx, by, bw, 28.0, "Nhận", func():
			E.KI(e, l)
			_build()))
	else:
		out.append(_btn(bx, by, bw, 28.0, "Chưa mở" if s else "Nhận", null, "off"))
	return out
