extends "res://logic/ui_kbang.gd"
# NGƯỜI LÀM THUÊ (ZD / sm bản web, Sổ làng › Làm thuê). (bản 469) làm lại trên khung Kho + chip chung (ui_kbang.gd):
# chip tổng (đang thuê mấy người, tốn mấy xu/phút, Cho nghỉ hết), mỗi nhà một khối (mặt, tên, tim, chip việc + lương, Ghé nhà);
# chạm khối mở lưới thuê làm chung (_hire, như tab Thuê làm bên Nhà dân), mỗi lúc một nhà. Luật ở w_lang.gd (n4, jq, set_jr, lm, vg, yx, om, wage).

var W          # w_lang.gd
var op = null               # nhà đang mở lưới thuê
const JK := {"ruong": "j_ruong", "vuon": "j_vuon", "chan": "j_chan"}   # màu chip việc đang làm (xưởng: j_xuong)
const HEART0 := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M12 21s-7.5-4.6-9.6-9.1C.9 8.6 3 5 6.6 5c2.1 0 3.6 1.1 4.4 2.5h2C13.8 6.1 15.3 5 17.4 5 21 5 23.1 8.6 21.6 11.9 19.5 16.4 12 21 12 21z\" fill=\"rgb(250,236,230)\" stroke=\"rgb(214,150,150)\" stroke-width=\"1.4\"/></svg>"

func _init(ui, wl) -> void:
	super(ui)
	W = wl

func open() -> void:   # ZD
	on = true
	op = null
	hpick = ""
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:   # sm khi đổi
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	var L = G.g.get("lang")
	return JSON.stringify([op, hpick, L.get("fam") if L is Dictionary else null, G.g.coins, W.ut_s().c, W._vr(), G.night])

func _build() -> void:
	sig = _sig()
	var sh := _kshell([], "", func(_k): pass)
	var r := _body()
	_kmount(sh[0], sh[1], float(sh[2]), r[0], float(r[1]))

func _co(f: String) -> String:   # c(f): tên chỗ làm
	return "Làm ruộng" if f == "ruong" else String(W.CO.get(f, f))

func _body() -> Array:   # sm
	var out := []
	var y := 6.0
	var L = G.g.get("lang")
	if not (L is Dictionary):
		return [out, y]
	var F: Dictionary = W._r0().fam
	var ks: Array = W._okeys(F)
	var n := 0
	var xu := 0
	for u in ks:
		if W._tr(F[u].get("job")):
			n += 1
			xu += int(W.wage(F[u]))
	# chip tổng
	var tc := _chip(X0, y, XW, 44.0, "got" if n else "fut")
	out.append(tc)
	out.append(_dt(X0 + 12.0, y + 6.0, XW - 120.0, 17.0, ("Đang thuê " + str(n) + "/" + str(ks.size()) + " người") if n else "Chưa thuê ai", 12.5, 800, BROWN, "left"))
	if n:
		out.append_array(_rowi(X0 + 12.0, y + 23.0, 15.0, ["Tốn " + str(xu), "c", " mỗi phút · hết tiền thì nghỉ"], 10.5, 600, SUB)[0])
		out.append(_btn(X0 + XW - 104.0, y + 9.0, 94.0, 26.0, "Cho nghỉ hết", func(): W.hr_off(), "red"))
	else:
		out.append(_dt(X0 + 12.0, y + 23.0, XW - 24.0, 15.0, "Chạm nhà nào để giao việc. Càng thân càng rẻ.", 10.5, 600, SUB, "left"))
	y += 44.0 + GG
	# nhà đang làm lên trước, nhà rảnh sau
	var sk := ks.duplicate()
	sk.sort_custom(func(a, b): return (1 if W._tr(F[a].get("job")) else 0) > (1 if W._tr(F[b].get("job")) else 0) if W._tr(F[a].get("job")) != W._tr(F[b].get("job")) else ks.find(a) < ks.find(b))
	for u in sk:
		var r := _house(y, u, F[u])
		out.append_array(r[0])
		y += float(r[1]) + GG
	return [out, y]

func _house(y: float, u, s: Dictionary) -> Array:   # khối 1 nhà: mặt, tên, tim, chip việc + lương, Ghé nhà; đang mở thì lưới thuê bên dưới
	var job := String(s.get("job")) if W._tr(s.get("job")) else ""
	var opn: bool = op != null and str(op) == str(u)
	var out := []
	var c := _chip(X0, y, XW, 10.0, "now" if opn else "fut")   # đang mở lưới: vàng
	out.append(c)
	var x := X0 + 10.0
	var w := XW - 20.0
	var yy := y + 10.0
	# mặt (chạm: ghé nhà)
	var lk: int = clampi(W._i(s.get("lk")), 0, 7)
	var fc := _chip(x, yy, 40.0, 40.0, "fut")
	fc.kids = [_pic(x + 3.0, yy + 3.0, 34.0, 34.0, "res://ui/img/vlface/" + str(lk) + ("n" if G.night else "") + ".webp")]
	fc.act = _go.bind(u)
	out.append(fc)
	var tx := x + 48.0
	# Ghé nhà: chip nhỏ góc phải
	var gc := _tchip(x, yy, "Ghé nhà ›", "fut", SUB, _go.bind(u), 20.0, 10.0)
	Snap._move(gc[0], Vector2(w - float(gc[1]), 0))
	out.append(gc[0])
	var nw := w - 48.0 - float(gc[1]) - 6.0
	out.append(_dt(tx, yy, nw, 16.0, _fitw(String(s.n), 12.0, 800, nw), 12.0, 800, BROWN, "left"))
	if W._tr(s.get("req")):   # đang nhờ việc: chấm đỏ cạnh tên
		out.append(_dbx(tx + minf(Box.text_w(String(s.n), 12.0, 800), nw) + 4.0, yy + 3.0, 7.0, 7.0, "rgb(226, 70, 60)", 3.5))
	# tim bằng hình
	var tim: int = W._i(s.get("tim"))
	for i in 5:
		out.append(_dic(tx + i * 14.0, yy + 18.0, 12.0, HEART if i < tim else HEART0))
	# chip việc + lương
	var jt := ("Đang ở nhà" if job == "" else _co(job)) + ("" if job == "" else " · " + str(W.wage(s)) + " xu/phút")
	var jc := _tchip(tx + 74.0, yy + 15.0, jt, "got" if job == "" else String(JK.get(job, "j_xuong")), "rgb(46, 120, 50)" if job == "" else BROWN, null, 18.0, 9.5)
	out.append(jc[0])
	yy += 40.0
	if W._tr(s.get("req")):
		out.append(_dt(x + 48.0, yy - 2.0, w - 48.0, 14.0, _fitw("Đang nhờ " + W._r_tx(s.req), 10.0, 600, w - 48.0), 10.0, 600, "rgb(170, 60, 50)", "left"))
		yy += 14.0
	c.act = _op.bind(u)
	yy += 10.0
	c.r[3] = yy - y
	if opn:   # lưới thuê nằm ngay dưới khối (không lồng trong khối)
		yy += GG
		var hr := _hire(yy, u, s, "rgb(76, 150, 48)", W)
		out.append_array(hr[0])
		yy += float(hr[1]) - 10.0
	return [out, yy - y]

func _op(u) -> void:   # chạm khối nhà: mở / đóng lưới thuê, mỗi lúc một nhà
	if op != null and str(op) == str(u):
		op = null
	else:
		op = u
	hpick = ""

func _go(u) -> void:   # Ghé nhà: đóng, về nhà đó
	close()
	U.vl_open(int(u))
