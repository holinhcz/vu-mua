extends "res://logic/ui_kbang.gd"
# DU LỊCH MIỆT VƯỜN (O6 / e7 bản web, Sổ làng › Du lịch hoặc chạm khách trên làng). (bản 482) làm lại trên khung Kho + chip chung (ui_kbang.gd):
# chip danh tiếng (sao, đón bao nhiêu khách, thu bao nhiêu) + chip đang ở; chưa đón được thì khối đỏ điều kiện có tick;
# "Để khách vui" danh sách điều có tick + thanh; khách đánh giá có mặt, sao, chip xu. Giá phòng cố định (bỏ 3 hạng). Luật ở w_dl.gd.

var WD         # w_dl.gd
const TABC := "rgb(60, 140, 120)"
const NOTE := "Khách Sài Gòn, khách Tây ba lô tới ở homestay nhà dân trong làng (ban ngày từ 7 tới 16 giờ). Khách đi quán ăn cơm, ra sạp mua đặc sản, lên đình, chụp hình chỗ cảnh đẹp, đi xuồng ở bến ghe. Ngủ lại một đêm rồi trả phòng, chấm sao. Danh tiếng càng cao khách tới càng thường. Tiền phòng mỗi người một đêm: "
const KF := {"sg": 2, "tay": 5}   # mặt khách theo loại
const XM := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 12 12\"><circle cx=\"6\" cy=\"6\" r=\"5.5\" fill=\"rgb(226,90,80)\"/><path d=\"M3.8 3.8 L8.2 8.2 M8.2 3.8 L3.8 8.2\" stroke=\"white\" stroke-width=\"1.6\" stroke-linecap=\"round\"/></svg>"

func _init(ui, wdl) -> void:
	super(ui)
	WD = wdl

func open() -> void:   # O6
	on = true
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
	return JSON.stringify([WD.r6(), WD.Jc.map(func(e): return [e.host, e.m.size()]), WD.p_c(), WD.vui()])

func _build() -> void:
	sig = _sig()
	var sh := _kshell([], "", func(_k): pass)
	var r := _body()
	_kmount(sh[0], sh[1], float(sh[2]), r[0], float(r[1]))

func _sq(y: float, t: String, help: String) -> Array:   # tiêu đề phần + nút ? ở mép phải
	var out := _sect(y, t, TABC)
	if help != "":
		var rl: Dictionary = out[2]
		rl.r[2] = maxf(0.0, float(rl.r[2]) - 26.0)
		var q := _chip(X0 + XW - 20.0, y - 1.0, 20.0, 18.0, "info")
		q.kids = [_dt(X0 + XW - 20.0, y - 1.0, 20.0, 18.0, "?", 11.0, 800, "rgb(60, 110, 170)")]
		q.act = func(): U.tre_help(t, help)
		out.append(q)
	return out

func _stars(x: float, y: float, a: float, z: float) -> Array:   # 5 sao hình: đầy tới a
	var out := []
	for n in range(1, 6):
		out.append(_pic(x + (n - 1) * (z + 2.0), y, z, z, "res://ui/img/bong/" + ("sao.png" if a >= n - 0.25 else "sao_xam.png")))
	return out

func _body() -> Array:   # e7
	var t: Dictionary = WD.r6()
	var a: float = WD.z_r()
	var out := []
	var y := 6.0
	# chip danh tiếng (trái) + đang ở (phải)
	var lw := XW * 0.62
	var hc := _chip(X0, y, lw, 62.0, "now")
	out.append(hc)
	out.append_array(_stars(X0 + 10.0, y + 8.0, a, 16.0))
	out.append(_dt(X0 + 10.0 + 5 * 18.0 + 4.0, y + 8.0, lw - 110.0, 16.0, String.num(a, 1), 12.5, 800, "rgb(150, 100, 20)", "left"))
	out.append(_dt(X0 + 10.0, y + 27.0, lw - 20.0, 15.0, "Danh tiếng làng", 11.0, 800, BROWN, "left"))
	out.append_array(_rowi(X0 + 10.0, y + 43.0, 14.0, ["Đón " + G.fmt_n(float(t.n)) + " khách · thu " + G.fmt_n(float(t.xu)), "c"], 10.0, 600, SUB)[0])
	var rx := X0 + lw + 6.0
	var rw := XW - lw - 6.0
	var nk: int = WD.n_khach()
	var oc := _chip(rx, y, rw, 62.0, "got" if nk else "fut")
	out.append(oc)
	out.append(_dt(rx + 8.0, y + 8.0, rw - 16.0, 14.0, "Đang ở", 10.0, 600, SUB, "left"))
	out.append(_dt(rx + 8.0, y + 22.0, rw - 16.0, 20.0, str(nk) + " khách", 14.0, 800, "rgb(46, 120, 50)" if nk else BROWN, "left"))
	var hs: Array = WD.Jc.map(func(e):
		var f = WD.WL._r0().fam.get(str(e.host))
		return String(f.n) if f != null else "?")
	if hs.size():
		out.append(_dt(rx + 8.0, y + 43.0, rw - 16.0, 14.0, _fitw("Nhà " + ", ".join(PackedStringArray(hs)), 9.5, 600, rw - 16.0), 9.5, 600, SUB, "left"))
	y += 62.0 + GG
	# chưa đón được: khối đỏ điều kiện
	if not WD.p_c():
		var C := [[WD.WL.bl().size() > 0, "Có nhà dân trong làng (nhà tranh, nhà ngói…)"], [WD._quan() or WD._saps().size() > 0, "Có quán cơm hoặc sạp bán hàng"]]
		var cc := _chip(X0, y, XW, 16.0 + 18.0 + C.size() * 18.0, "sen")
		out.append(cc)
		out.append(_dt(X0 + 10.0, y + 8.0, XW - 20.0, 16.0, "Cần để đón khách", 11.5, 800, "rgb(170, 50, 60)", "left"))
		var yy := y + 28.0
		for e in C:
			out.append(_dtick(X0 + 10.0, yy + 2.0, 11.0) if e[0] else _dic(X0 + 10.0, yy + 2.0, 11.0, XM))
			out.append(_dt(X0 + 26.0, yy, XW - 36.0, 15.0, _fitw(String(e[1]), 10.5, 700, XW - 36.0), 10.5, 700, BROWN, "left"))
			yy += 18.0
		y += float(cc.r[3]) + GG
	# để khách vui
	var V: Array = WD.vui()
	var nv := 0
	for e in V:
		nv += 1 if e[0] else 0
	out.append_array(_sq(y, "Để khách vui", NOTE + str(WD.ROOM) + " xu. Khách vui thì chấm sao cao, danh tiếng lên, khách tới nhiều hơn."))
	y += 16.0 + GG
	var vc := _chip(X0, y, XW, 10.0, "got" if nv == V.size() else "fut")
	out.append(vc)
	out.append(_dt(X0 + 10.0, y + 8.0, XW - 100.0, 16.0, "Đạt " + str(nv) + "/" + str(V.size()) + " điều", 11.5, 800, BROWN, "left"))
	out.append_array(_bar(X0 + 110.0, y + 14.0, XW - 120.0, float(nv) / maxf(1.0, V.size()), 5.0))
	var yy2 := y + 30.0
	var cw := (XW - 20.0 - 6.0) * 0.5
	for i in V.size():
		var e: Array = V[i]
		var cx := X0 + 10.0 + (i % 2) * (cw + 6.0)
		var cy := yy2 + floorf(i / 2.0) * 18.0
		out.append(_dtick(cx, cy + 2.0, 11.0) if e[0] else _dic(cx, cy + 2.0, 11.0, XM))
		out.append(_dt(cx + 15.0, cy, cw - 15.0, 15.0, _fitw(String(e[1]).split(" (")[0], 10.0, 700, cw - 15.0), 10.0, 700, BROWN if e[0] else SUB, "left"))
	yy2 += ceil(V.size() / 2.0) * 18.0 + 6.0
	vc.r[3] = yy2 - y
	y = yy2 + GG
	# khách đánh giá
	if t.rv.size():
		out.append_array(_sq(y, "Khách đánh giá", ""))
		y += 16.0 + GG
		for e in t.rv.slice(0, 8):
			var s := int(e.s)
			var L := _wrap("“" + String(e.t) + "”", 10.5, 600, XW - 56.0)
			var h := 10.0 + 16.0 + L.size() * 14.0 + 8.0
			var c := _chip(X0, y, XW, h, "got" if s >= 4 else ("sen" if s <= 2 else "fut"))
			out.append(c)
			var fk := _chip(X0 + 8.0, y + 8.0, 30.0, 30.0, "fut")
			fk.kids = [_pic(X0 + 10.0, y + 10.0, 26.0, 26.0, "res://ui/img/vlface/" + str(KF.get(String(e.k), 0)) + ".webp")]
			out.append(fk)
			out.append_array(_stars(X0 + 46.0, y + 9.0, float(s), 12.0))
			var kn := (String(WD.A7[e.k].n) if WD.A7.has(e.k) else "").replace("Khách ", "")
			var P := ["+" + G.fmt_n(float(e.xu)), "c"]
			var pw := float(_rowi(0.0, 0.0, 18.0, P, 10.0, 800, "")[1]) + 12.0
			var mw := XW - 46.0 - 5 * 14.0 - 4.0 - pw - 14.0
			out.append(_dt(X0 + 46.0 + 5 * 14.0 + 4.0, y + 8.0, mw, 14.0, _fitw(kn + " · " + _dp(float(e.at)).replace("hôm nay ", ""), 9.5, 600, mw), 9.5, 600, SUB, "left"))
			var pc := _chip(X0 + XW - 8.0 - pw, y + 6.0, pw, 18.0, "now")
			pc.kids = _rowi(X0 + XW - 8.0 - pw + 6.0, y + 6.0, 18.0, P, 10.0, 800, BROWN)[0]
			out.append(pc)
			for j in L.size():
				out.append(_dt(X0 + 46.0, y + 26.0 + j * 14.0, XW - 56.0, 14.0, String(L[j]), 10.5, 600, BROWN, "left"))
			y += h + 5.0
		y += GG - 5.0
	return [out, y]

static func _dp(ms: float) -> String:   # dp: "hôm nay 20:44" / "21:44 ngày 12/11"
	var tz: int = int(Time.get_time_zone_from_system().bias) * 60
	var a := Time.get_datetime_dict_from_unix_time(int(ms / 1000.0) + tz)
	var n := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + tz)
	var e := "%02d:%02d" % [a.hour, a.minute]
	if a.year == n.year and a.month == n.month and a.day == n.day:
		return "hôm nay " + e
	return e + " ngày " + str(a.day) + "/" + str(a.month)
