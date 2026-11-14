extends "res://logic/ui_pop.gd"
# DU LỊCH MIỆT VƯỜN (O6 / e7 bản web, Sổ làng › Du lịch hoặc chạm khách trên làng): hộp nổi khung tre (ui_pop.gd).
# Đầu hộp .qhead (sao danh tiếng, đón bao nhiêu khách, đang ở), lời giải thích gấp 2 dòng, giá phòng (hàng tab tre .btabs.qlv),
# "Để khách vui" (nút ?), Khách đánh giá (ul.kh-gb). Mẫu: dl_tab.json. Luật ở w_dl.gd.

var D          # w_dl.gd
var DT := {}
const NOTE := "Khách Sài Gòn, khách Tây ba lô tới ở homestay nhà dân trong làng (ban ngày từ 7 tới 16 giờ). Khách đi quán ăn cơm, ra sạp mua đặc sản, lên đình, chụp hình chỗ cảnh đẹp, đi xuồng ở bến ghe, ra cù lao. Ngủ lại một đêm rồi trả phòng, chấm sao. Danh tiếng càng cao khách tới càng thường."
const NOK := "Chưa đón khách được. Cần ít nhất một nhà dân (xây nhà tranh, nhà ngói…) và một quán cơm hoặc sạp bán hàng."

func _init(ui, wdl) -> void:
	super(ui)
	D = wdl
	DT = Snap.load_snap("dl_tab")

func open() -> void:   # O6
	on = true
	note_open = false
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	return JSON.stringify([note_open, D.r6(), D.Jc.map(func(e): return [e.host, e.m.size()]), D.p_c()])

func _build() -> void:
	sig = _sig()
	_pop(_body())

func _body() -> Array:   # e7
	var t: Dictionary = D.r6()
	var a: float = D.z_r()
	var out := [_qhead(t, a)]
	out[0].gap = 0.0
	if not D.p_c():
		var nk := _note_p(NOK)
		nk.gap = 0.0
		out.append(nk)
	var nt := _note_p(NOTE)
	nt.gap = 0.0
	out.append(nt)
	var s1 := _sec_p("Giá phòng mỗi người một đêm", "Rẻ thì khách dễ chấm sao cao, đắt thì lời nhiều.")
	s1.gap = 4.5
	out.append(s1)
	var bt := _tabs(int(t.lv))
	bt.gap = -4.5
	bt.ddx = -9.0
	out.append(bt)
	var s2 := _sec_p("Để khách vui", "Quán cơm nhiều món · sạp có đặc sản · độ đẹp làng cao · có bến ghe để đi xuồng · mở cù lao (bắc cầu qua) · tránh mùa mưa.")
	s2.gap = 4.5
	out.append(s2)
	if t.rv.size():
		var s3 := _cl(DT.sec_b)
		var b3: Dictionary = s3.kids[0]
		b3.text = "Khách đánh giá"
		s3.gap = 4.5
		out.append(s3)
		var ul := _reviews(t.rv.slice(0, 8))
		ul.gap = 7.5
		out.append(ul)
	return out

func _qhead(t: Dictionary, a: float) -> Dictionary:   # .qhead: YS(a) + danh tiếng | đang ở
	var q := _cl(DT.qhead)
	var L: Dictionary = q.kids[0]
	var R: Dictionary = q.kids[1]
	var st: Dictionary = L.kids[0]
	var on_i: Dictionary = st.kids[0]
	var off_i: Dictionary = st.kids[4]
	var ks := []
	for n in range(1, 6):
		var c := _cl(on_i if a >= n - 0.25 else off_i)
		_mv(c, float(on_i.r[0]) + (n - 1) * 12.53, float(on_i.r[1]))
		ks.append(c)
	st.kids = ks
	_txt1(L.kids[1], "Danh tiếng " + String.num(a, 1) + " sao")
	_txt1(L.kids[2], "Đón " + G.fmt_n(float(t.n)) + " khách · thu " + G.fmt_n(float(t.xu)) + " xu")
	_txt1(R.kids[1], str(D.n_khach()) + " khách")
	var hs: Array = D.Jc.map(func(e):
		var f = D.WL._r0().fam.get(str(e.host))
		return "nhà " + (String(f.n) if f != null else "?"))
	var sm: Dictionary = R.kids[2]
	_txt1(sm, ", ".join(PackedStringArray(hs)))
	if hs.size():
		sm.r[3] = 11.2
	return q

func _txt1(n: Dictionary, s: String) -> void:   # chữ một dòng (dài quá thì cắt …)
	var W0 := float(n.r[2])
	var x := s
	if _tw(n, x) > W0:
		while x.length() > 1 and _tw(n, x + "…") > W0:
			x = x.substr(0, x.length() - 1)
		x += "…"
	n.text = x
	n.tr = [n.r[0], n.tr[1] if n.has("tr") else n.r[1], _tw(n, x), n.tr[3] if n.has("tr") else n.r[3]]

func _tabs(lv: int) -> Dictionary:   # .btabs.qlv: 3 giá phòng
	var b := _cl(DT.btabs)
	var off_t: Dictionary = b.kids[0]
	var on_t: Dictionary = b.kids[1]
	var out := []
	for r in D.PR.size():
		var e: Dictionary = D.PR[r]
		var c := _cl(on_t if r == lv else off_t)
		var x: float = float(off_t.r[0]) + r * 86.5
		var w: float = float(c.r[2])
		_mv(c, x, float(c.r[1]))
		var s := String(e.n) + " · " + str(int(e.xu))
		var tw := _tw(c, s)
		c.text = s
		c.tr = [x + (w - tw) * 0.5, c.tr[1], tw, c.tr[3]]
		c.act = _lv.bind(r)
		out.append(c)
	b.kids = out
	return b

func _lv(r: int) -> void:   # data-dlv
	D.r6().lv = r
	G.mark()

static func _dp(ms: float) -> String:   # dp: "hôm nay 20:44" / "21:44 ngày 12/11"
	var tz: int = int(Time.get_time_zone_from_system().bias) * 60
	var a := Time.get_datetime_dict_from_unix_time(int(ms / 1000.0) + tz)
	var n := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + tz)
	var e := "%02d:%02d" % [a.hour, a.minute]
	if a.year == n.year and a.month == n.month and a.day == n.day:
		return "hôm nay " + e
	return e + " ngày " + str(a.day) + "/" + str(a.month)

func _reviews(L: Array) -> Dictionary:   # ul.kh-gb > li: <b>sao + loại khách</b> <small>lúc</small> <span>“lời” · +xu</span>
	var u := _cl(DT.ul)
	var tpl: Dictionary = u.kids[0]
	var x := float(u.r[0])
	var y := float(u.r[1])
	var out := []
	for e in L:
		var li := _cl(tpl)
		_mv(li, x, y)
		var b: Dictionary = li.kids[0]
		var sm: Dictionary = li.kids[1]
		var sp: Dictionary = li.kids[2]
		var s := int(e.s)
		_txt1(b, "★★★★★".substr(0, s) + "☆☆☆☆☆".substr(s) + " " + String(D.A7[e.k].n))
		b.r[2] = _tw(b, String(b.text))
		var sx := float(b.r[0]) + float(b.r[2]) + 4.0
		Snap._move(sm, Vector2(sx - float(sm.r[0]), 0))
		_txt1(sm, _dp(float(e.at)))
		sm.r[2] = _tw(sm, String(sm.text))
		var st := _cl(sp)
		st.erase("kids")
		var h := _put(sp, [_r("“" + String(e.t) + "” · +" + G.fmt_n(float(e.xu)) + " xu", st)])
		sp.r[3] = h
		li.r[3] = float(sp.r[1]) - float(li.r[1]) + h + 5.25
		out.append(li)
		y += float(li.r[3]) + 4.5
	u.kids = out
	u.r[3] = y - 4.5 - float(u.r[1])
	return u
