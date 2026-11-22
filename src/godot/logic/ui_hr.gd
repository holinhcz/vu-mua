extends "res://logic/ui_kbang.gd"
# NGƯỜI LÀM THUÊ (ZD / sm bản web, Sổ làng › Làm thuê). (bản 469) làm lại trên khung Kho + chip chung (ui_kbang.gd):
# chip tổng (đang thuê mấy người, tốn mấy xu/phút, Cho nghỉ hết), mỗi nhà một khối (mặt, tên, tim, chip việc + lương, Ghé nhà);
# chạm khối mở lưới thuê làm chung (_hire, như tab Thuê làm bên Nhà dân), mỗi lúc một nhà. Luật ở w_lang.gd (n4, jq, set_jr, lm, vg, yx, om, wage).

var W          # w_lang.gd
var op = null               # nhà đang mở lưới thuê
const JK := {"ruong": "j_ruong", "vuon": "j_vuon", "chan": "j_chan"}   # màu chip việc đang làm (xưởng: j_xuong)

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
	# (bản 470) 2 nhóm: Đang làm / Rảnh ở nhà; nhà rảnh thuê rẻ nhất có chip "Rẻ nhất"
	var bz := []
	var ra := []
	var mn := 1 << 30
	for u in ks:
		if W._tr(F[u].get("job")):
			bz.append(u)
		else:
			ra.append(u)
			mn = mini(mn, _from(F[u]))
	for g in [["Đang làm", bz], ["Rảnh ở nhà", ra]]:
		if g[1].is_empty():
			continue
		out.append_array(_sect(y, String(g[0]) + " · " + str(g[1].size()), "rgb(76, 150, 48)" if g[0] == "Đang làm" else "rgb(150, 112, 60)"))
		y += 16.0 + GG
		for u in g[1]:
			var r := _house(y, u, F[u], g[0] == "Rảnh ở nhà" and ra.size() > 1 and _from(F[u]) == mn)
			out.append_array(r[0])
			y += float(r[1]) + GG
	return [out, y]

func _from(s: Dictionary) -> int:   # công rẻ nhất nếu thuê nhà này (ruộng / vườn / chuồng)
	var m := 1 << 30
	for j in ["ruong", "vuon", "chan"]:
		m = mini(m, int(W.om(s, j)))
	return m

func _house(y: float, u, s: Dictionary, cheap: bool) -> Array:   # khối 1 nhà, 2 hàng: mặt + tên + tim (Ghé nhà); chip sở trường, tính nết, việc / lương, nhờ việc
	var job := String(s.get("job")) if W._tr(s.get("job")) else ""
	var opn: bool = op != null and str(op) == str(u)
	var out := []
	var c := _chip(X0, y, XW, 10.0, "now" if opn else "fut")   # đang mở lưới: vàng
	out.append(c)
	var x := X0 + 10.0
	var w := XW - 20.0
	var yy := y + 9.0
	var lk: int = clampi(W._i(s.get("lk")), 0, 7)
	var fc := _chip(x, yy, 40.0, 40.0, "fut")
	fc.kids = [_pic(x + 3.0, yy + 3.0, 34.0, 34.0, "res://ui/img/vlface/" + str(lk) + ("n" if G.night else "") + ".webp")]
	fc.act = _go.bind(u)
	out.append(fc)
	var tx := x + 48.0
	# hàng 1: tên, tim tô dần + Thân N/5, Ghé nhà
	var gc := _tchip(x, yy - 1.0, "Ghé nhà ›", "fut", SUB, _go.bind(u), 20.0, 10.0)
	Snap._move(gc[0], Vector2(w - float(gc[1]), 0))
	out.append(gc[0])
	var tim: int = W._i(s.get("tim"))
	var nm := String(s.n)
	var nw: float = minf(Box.text_w(nm, 12.0, 800) + 2.0, w - 48.0 - float(gc[1]) - 96.0)
	out.append(_dt(tx, yy, nw, 18.0, _fitw(nm, 12.0, 800, nw), 12.0, 800, BROWN, "left"))
	var hx := tx + nw + 8.0
	var pp := 1.0 if tim >= 5 else fmod(W._n(s.get("dp")), 100.0) / 100.0
	for i in 5:
		out.append(_dic(hx + i * 15.0, yy + 3.0, 13.0, HEART if i < tim else (_heartp(pp) if i == tim and pp > 0.0 else HEART0)))
	# hàng 2: chip sở trường (hình + tên, màu theo nghề), tính nết, việc đang làm / lương, nhờ việc
	var cy := yy + 21.0
	var cx := tx
	var r := String(W.x9(u, s))
	if W.W3.has(r):
		var tn := String(W.W3[r].n)
		var sw: float = Box.text_w(tn, 9.5, 700) + 30.0
		var sc := _chip(cx, cy, sw, 19.0, "s_" + r if CHIPK.has("s_" + r) else "fut")
		sc.kids = [_icn(cx + 10.0, cy + 9.5, 15.0, String(TALIC.get(r, "lua"))), _dt(cx + 19.0, cy, sw - 22.0, 19.0, tn, 9.5, 700, BROWN, "left")]
		sc.act = _dsay.bind(nm + ": " + tn + " " + str(W._i(s.get("ts"))) + " sao, thuê đúng nghề thì làm nhanh, công rẻ hơn.")
		out.append(sc)
		cx += sw + 4.0
	var TT: Dictionary = W.tinh_of(s)
	var tk := String(s.get("tp", ""))
	var tt := _tchip(cx, cy, String(TT.n), "t_" + tk if CHIPK.has("t_" + tk) else "t_khac", BROWN, _dsay.bind(String(TT.n) + ": " + String(TT.d)), 19.0, 9.5)
	out.append(tt[0])
	cx += float(tt[1]) + 4.0
	var P := ([_co(job) + " · " + str(W.wage(s)), "c", "/phút"]) if job != "" else (["Từ " + str(_from(s)), "c", "/phút"])
	var pw := float(_rowi(0.0, 0.0, 19.0, P, 9.5, 700, "")[1]) + 12.0
	if cx + pw > x + w - 18.0:
		cx = tx
		cy += 23.0
	var wc := _chip(cx, cy, pw, 19.0, String(JK.get(job, "j_xuong")) if job != "" else ("got" if cheap else "fut"))
	wc.kids = _rowi(cx + 6.0, cy, 19.0, P, 9.5, 700, BROWN)[0]
	out.append(wc)
	cx += pw + 4.0
	var yb := cy + 19.0   # đáy hàng chip cuối
	var ex := []   # chip dòng 3 (nếu có): Rẻ nhất, Nhờ việc
	if cheap:
		ex.append(["Rẻ nhất", "got", "rgb(46, 120, 50)", null])
	if W._tr(s.get("req")):
		ex.append(["Nhờ việc ›", "sen", "rgb(170, 50, 60)", _go.bind(u)])
	for e in ex:
		var ew: float = Box.text_w(String(e[0]), 9.5, 700) + 14.0
		if cx + ew > x + w - 16.0:
			cx = tx
			cy += 23.0
			yb = cy + 19.0
		var ec := _tchip(cx, cy, String(e[0]), String(e[1]), String(e[2]), e[3], 19.0, 9.5)
		out.append(ec[0])
		cx += float(ec[1]) + 4.0
	yy = maxf(yb, yy + 40.0) + 9.0
	out.append(_dic(x + w - 12.0, yy - 21.0, 11.0, CHU if opn else CHD))   # mũi tên mở / đóng lưới: góc phải dưới
	c.act = _op.bind(u)
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
