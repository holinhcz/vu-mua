extends "res://logic/ui_hx.gd"
# 7 NGÀY VỀ LÀNG (XI / iv bản web, nút 7 ngày ở cột sự kiện): hộp khung tre ui_hx.gd
#  - đầu: điểm khai hoang + thanh 5 rương (40/100/160/220/280),
#  - hàng 7 ngày (khóa / đang xem / xong / chấm đỏ còn quà),
#  - thẻ ngày: quà điểm danh, 4 việc +10 điểm, gói tân thủ hôm nay (nạp tiền: bản Godot chưa có cửa hàng).
# Mẫu: ui/snap/tt.json (chụp bản web, tọa độ tính từ đỉnh thân). Luật ở w_ev.gd.

var E          # w_ev.gd
var TT := {}
var P9 := -1   # ngày đang xem

func _init(ui, wev) -> void:
	super(ui)
	E = wev
	TT = Snap.load_snap("tt")
	BMAX = 580.0

func open() -> void:   # XI
	if P9 < 0:
		P9 = E.ev() - 1
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	var e := clampi(P9, 0, 6)
	return JSON.stringify([e, E.ev(), E.V1(), E.RV[e].q.map(func(q): return E.qf(q)), int(Time.get_unix_time_from_system() / 60.0)])

func _day(d: int) -> void:
	P9 = d
	scroll = 0.0

# chữ xuống dòng trong khung rộng W, mỗi dòng cao lh; trả chiều cao
func _wrap(n: Dictionary, s: String, W: float, lh: float, al := "left") -> float:
	var st := _cl(n)
	st.erase("kids")
	var f := _flow([_r(s, st)], float(n.r[0]), float(n.r[1]), W, lh, al)
	n.erase("text")
	n.erase("tr")
	n.kids = f.kids
	n.r = [n.r[0], n.r[1], W, f.h]
	return f.h

# hàng (align-items center): mọi con canh giữa theo chiều dọc, hàng cao = con cao nhất + 2 pad
func _row(n: Dictionary, pad: float) -> void:
	var H := 0.0
	for k in n.kids:
		H = maxf(H, float(k.r[3]))
	H += pad * 2.0
	n.r[3] = H
	for k in n.kids:
		_mv(k, float(k.r[0]), float(n.r[1]) + (H - float(k.r[3])) * 0.5)

func _build() -> void:
	sig = _sig()
	var a: Dictionary = E.V1()
	var n: int = E.ev()
	var e := clampi(P9, 0, 6)
	var r: int = E.XL()
	help = ["7 ngày về làng", "Quà cho người mới · còn " + G.ao(E.left_s()) + " để làm hết"]
	var ov := _cl(TT.ov)
	var by := float(_find(ov, "hxbody").r[1])
	var kids := [_bar(r), _days(a, n, e)]
	var card := _tcard(a, n, e)
	kids.append(card)
	var ch := float(card.r[1]) + float(card.r[3]) + 10.5
	for k in kids:
		Snap._move(k, Vector2(0, by))
	_hx(ov, kids, ch)

# ------------------------------------------------------------------ điểm khai hoang + rương
func _bar(r: int) -> Dictionary:
	var b := _cl(TT.bar)
	_set_txt(b.kids[0].kids[0], str(r), "center")
	var chs: Dictionary = b.kids[1]
	var bar: Dictionary = chs.kids[0]
	bar.kids[0].r[2] = float(bar.r[2]) * minf(1.0, r / 280.0)
	var row: Dictionary = chs.kids[1]
	for j in E.A9.size():
		var p := int(E.A9[j].p)
		var c: Dictionary = row.kids[j]
		var dt := r >= p
		var v: bool = E.ch(p)
		if v or dt:
			var src: Dictionary = TT.ch_got if v else TT.ch_on
			for k in ["opacity", "filter"]:
				c.css[k] = src[k]
			if not v:
				Snap._move(c, Vector2(float(c.r[2]) * 0.5, 0))   # web: hiệu ứng nhấp nháy đè transform, nút lệch nửa bề ngang
		if dt and not v:
			c.act = E.UI.bind(p)
	return b

# ------------------------------------------------------------------ hàng 7 ngày
func _days(a: Dictionary, n: int, e: int) -> Dictionary:
	var D := _cl(TT.days)
	var dx := 0.0
	for d in D.kids.size():
		var b: Dictionary = D.kids[d]
		var v: bool = d >= n
		var Q: Array = E.RV[d].q
		var all := true
		var any := false
		for l in Q.size():
			if not E.cl(d, l):
				all = false
				if E.qf(Q[l]) >= E.L9(Q[l]):
					any = true
		var x: bool = E.ci(d) and all
		var k: bool = not v and (not E.ci(d) or any)
		var sel: bool = d == e
		var cs: Dictionary = (TT.d_lkon if sel else TT.d_lk) if v else (TT.d_on if sel else (TT.d_done if x else TT.d_plain))
		b.css = cs.duplicate()
		b.kids = b.kids.filter(func(z): return z.tag != "em")
		Snap._move(b, Vector2(dx, 0))
		_set_txt(b.kids[0], "🔒" if v else ("✓" if x else String(E.RV[d].ic)), "center")
		if x:   # web: ô xong hẹp lại 2,4 (chữ ✓ hẹp hơn biểu tượng)
			b.r[2] = float(b.r[2]) - 2.4
			for z in b.kids:
				Snap._move(z, Vector2(-1.2, 0))
			dx -= 2.4
		if k:
			var dot := _cl(TT.dot)
			_mv(dot, float(b.r[0]) + 18.5, float(b.r[1]) - 2.0)
			b.kids.append(dot)
		b.act = _day.bind(d)
	return D

# ------------------------------------------------------------------ thẻ ngày
func _tcard(a: Dictionary, n: int, e: int) -> Dictionary:
	var f: Dictionary = E.RV[e]
	var s := e >= n
	var card := _cl(TT.card)
	var y := float(card.r[1]) + 8.5
	var out := []
	# đầu thẻ
	var h := _cl(TT.ch_lk if s else TT.ch)
	_mv(h, float(h.r[0]), y)
	_set_txt(h.kids[0], "Ngày " + str(e + 1) + " · " + String(f.n))
	if s:
		_set_txt(h.kids[1], "Mở sau " + str(e + 1 - n) + " ngày nữa, nhớ quay lại nha!")
	out.append(h)
	y += float(h.r[3]) + 6.0
	# quà điểm danh
	var got: bool = E.ci(e)
	var g := _cl(TT.g_got if got else (TT.g_lk if s else TT.g_ok))
	_mv(g, float(g.r[0]), y)
	var gi: Dictionary = g.kids[0]
	var ic := _cl(TT.gi[String(f.gift.ic)])
	_mv(ic, float(gi.r[0]) + (float(gi.r[2]) - float(ic.r[2])) * 0.5, float(gi.r[1]) + (float(gi.r[3]) - float(ic.r[3])) * 0.5)
	gi.kids = [ic]
	var tx: Dictionary = g.kids[1]
	var sm: Dictionary = tx.kids[1]
	_mv(sm, float(sm.r[0]), float(tx.kids[0].r[1]) + float(tx.kids[0].r[3]) + 1.0)
	var sh := _wrap(sm, String(f.gift.t), float(tx.r[2]), 12.55)
	tx.r[3] = float(sm.r[1]) + sh - float(tx.r[1])
	if not got and not s:
		g.kids[2].act = E.QI.bind(e)
	_row(g, 7.0)
	out.append(g)
	y += float(g.r[3]) + 6.0
	# 4 việc
	var lst := _cl(TT.nvlist)
	_mv(lst, float(lst.r[0]), y)
	var y0 := y
	var rows := []
	for l in f.q.size():
		var q: Dictionary = f.q[l]
		var v: int = E.L9(q)
		var xq := clampi(E.qf(q), 0, v)
		var k: bool = E.cl(e, l)
		var M := not s and xq >= v and not k
		var rw := _cl(TT.q_done if k else (TT.q_lk if s else (TT.q_ok if M else TT.q_no)))
		_mv(rw, float(rw.r[0]), y)
		var dv: Dictionary = rw.kids[1]
		var bb: Dictionary = dv.kids[0]
		_mv(bb, float(bb.r[0]), float(dv.r[1]))
		var bh := _wrap(bb, E.CY(q), float(dv.r[2]), 12.0)
		var bar: Dictionary = dv.kids[1]
		_mv(bar, float(bar.r[0]), float(bb.r[1]) + bh + 3.0)
		bar.kids[0].r[2] = float(bar.r[2]) * (0.0 if s else minf(1.0, float(xq) / maxf(1.0, v)))
		var sl: Dictionary = dv.kids[2]
		_mv(sl, float(sl.r[0]), float(bar.r[1]) + float(bar.r[3]) + 1.5)
		_set_txt(sl, "Chưa mở" if s else G.fmt_n(xq) + "/" + G.fmt_n(v))
		dv.r[3] = float(sl.r[1]) + float(sl.r[3]) - float(dv.r[1])
		if M:
			rw.kids[2].act = E.KI.bind(e, l)
		_row(rw, 6.0)
		rows.append(rw)
		y += float(rw.r[3]) + 4.5
	lst.kids = rows
	y -= 4.5
	lst.r[3] = y - y0
	out.append(lst)
	# gói tân thủ hôm nay
	if not s and e == n - 1:
		y += 7.5
		var pk := _cl(TT.pk)
		_mv(pk, float(pk.r[0]), y)
		var P: Dictionary = E.PK[e]
		var pd: Dictionary = pk.kids[1]
		var pb: Dictionary = pd.kids[0]
		var ps: Dictionary = pd.kids[1]
		var ph := _wrap(ps, String(P.t) + " · chỉ bán trong ngày", float(pd.r[2]), 13.44)
		pd.r[3] = float(ps.r[1]) + ph - float(pb.r[1])
		var pr: Dictionary = pk.kids[2]
		_set_txt(pr, G.fmt_n(int(P.vnd)) + "đ", "center")
		pr.act = U.say.bind(U.SOON)
		_row(pk, 7.0)
		out.append(pk)
		y += float(pk.r[3])
	card.kids = out
	card.r[3] = y + 8.5 - float(card.r[1])
	return card
