extends "res://logic/ui_kbang.gd"
# NGƯỜI LÀM THUÊ (ZD / sm bản web, Sổ làng › Làm thuê). (bản 469) làm lại trên khung Kho + chip chung (ui_kbang.gd):
# chip tổng (đang thuê mấy người, tốn mấy xu/phút, Cho nghỉ hết), mỗi nhà một khối (mặt, tên, tim, chip việc + lương, Ghé nhà);
# chạm khối mở lưới thuê làm chung (_hire, như tab Thuê làm bên Nhà dân), mỗi lúc một nhà. Luật ở w_lang.gd (n4, jq, set_jr, lm, vg, yx, om, wage).

var W          # w_lang.gd
var op = null               # nhà đang mở lưới thuê
const HRC := {   # (bản 471) nền khối nhà nhạt theo sở trường: [gradient trên, giữa, dưới, viền]
	"h_ruong": ["rgb(235, 243, 229)", "rgb(241, 247, 237)", "rgb(248, 251, 246)", "rgb(182, 212, 162)"],
	"h_vuon": ["rgb(250, 240, 226)", "rgb(252, 245, 236)", "rgb(253, 250, 245)", "rgb(238, 202, 152)"],
	"h_chan": ["rgb(247, 238, 230)", "rgb(250, 243, 238)", "rgb(252, 249, 246)", "rgb(228, 192, 168)"],
	"h_xuong": ["rgb(239, 234, 245)", "rgb(244, 241, 248)", "rgb(249, 247, 252)", "rgb(196, 180, 220)"],
}
const JK := {"ruong": "j_ruong", "vuon": "j_vuon", "chan": "j_chan"}   # màu chip việc đang làm (xưởng: j_xuong)

func _ck(kind: String) -> Array:
	return HRC[kind] if HRC.has(kind) else super(kind)

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
	var tc := _chip(X0, y, XW, 44.0, "got" if n else "sen")   # (bản 471) chưa thuê ai: đỏ nhạt
	out.append(tc)
	out.append(_dt(X0 + 12.0, y + 6.0, XW - 120.0, 17.0, ("Đang thuê " + str(n) + "/" + str(ks.size()) + " người") if n else "Chưa thuê ai", 12.5, 800, BROWN, "left"))
	if n:
		out.append_array(_rowi(X0 + 12.0, y + 23.0, 15.0, ["Tốn " + str(xu), "c", " mỗi phút · hết tiền thì nghỉ"], 10.5, 600, SUB)[0])
		out.append(_btn(X0 + XW - 104.0, y + 9.0, 94.0, 26.0, "Cho nghỉ hết", func(): W.hr_off(), "red"))
	else:
		out.append(_dt(X0 + 12.0, y + 23.0, XW - 24.0, 15.0, "Chạm nhà nào để giao việc. Càng thân càng rẻ.", 10.5, 600, SUB, "left"))
	y += 44.0 + GG
	# (bản 470) 2 nhóm: Đang làm / Rảnh ở nhà; nhà rảnh thuê rẻ nhất: chip tiền công xanh
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

static func _cap(t: String) -> String:   # chữ đầu viết hoa
	return t.substr(0, 1).to_upper() + t.substr(1)

func _from(s: Dictionary) -> int:   # công rẻ nhất nếu thuê nhà này (ruộng / vườn / chuồng)
	var m := 1 << 30
	for j in ["ruong", "vuon", "chan"]:
		m = mini(m, int(W.om(s, j)))
	return m

func _house(y: float, u, s: Dictionary, cheap: bool) -> Array:   # khối 1 nhà, 2 hàng: mặt + tên + tim (Ghé nhà); chip sở trường, tính nết, việc / lương, nhờ việc
	var job := String(s.get("job")) if W._tr(s.get("job")) else ""
	var opn: bool = op != null and str(op) == str(u)
	var out := []
	var r := String(W.x9(u, s))
	var c := _chip(X0, y, XW, 10.0, "now" if opn else ("h_" + r if HRC.has("h_" + r) else "fut"))   # (bản 471) nền nhạt theo sở trường; đang mở lưới: vàng
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
	var tw := w - 48.0
	# (bản 472) hàng 1: tên, tim tô dần, nút Ghé nhà
	var gb := _btn(x + w - 74.0, yy - 1.0, 74.0, 20.0, "Ghé nhà ›", _go.bind(u), "go")
	out.append(gb)
	var tim: int = W._i(s.get("tim"))
	var nm := String(s.n)
	var nw: float = minf(Box.text_w(nm, 12.0, 800) + 2.0, tw - 74.0 - 82.0)
	out.append(_dt(tx, yy, nw, 18.0, _fitw(nm, 12.0, 800, nw), 12.0, 800, BROWN, "left"))
	var hx := tx + nw + 6.0
	var pp := 1.0 if tim >= 5 else fmod(W._n(s.get("dp")), 100.0) / 100.0
	for i in 5:
		out.append(_dic(hx + i * 14.0, yy + 3.0, 12.0, HEART if i < tim else (_heartp(pp) if i == tim and pp > 0.0 else HEART0)))
	# hàng 2: sở trường (hình + sao), tính nết
	var cy := yy + 22.0
	var cx := tx
	var o: int = W._i(s.get("ts"))
	if W.W3.has(r):
		var tn := String(W.W3[r].n)
		var sw: float = Box.text_w(tn, 10.0, 700) + 30.0 + 5 * 11.0 + 4.0
		var sc := _chip(cx, cy, sw, 20.0, "s_" + r if CHIPK.has("s_" + r) else "fut")
		var ks := [_icn(cx + 10.0, cy + 10.0, 15.0, String(TALIC.get(r, "lua"))), _dt(cx + 19.0, cy, sw - 22.0, 20.0, tn, 10.0, 700, BROWN, "left")]
		var sx: float = cx + 21.0 + Box.text_w(tn, 10.0, 700) + 2.0
		for i in 5:
			ks.append(_pic(sx + i * 11.0, cy + 5.0, 10.0, 10.0, "res://ui/img/bong/" + ("sao.png" if i < o else "sao_xam.png")))
		sc.kids = ks
		sc.act = _dsay.bind(nm + ": " + tn + " " + str(o) + " sao. Thuê đúng nghề thì công rẻ, làm được nhiều hơn.")
		out.append(sc)
		cx += sw + 5.0
	var TT: Dictionary = W.tinh_of(s)
	var tk := String(s.get("tp", ""))
	var tt := _tchip(cx, cy, String(TT.n), "t_" + tk if CHIPK.has("t_" + tk) else "t_khac", BROWN, _dsay.bind(String(TT.n) + ": " + String(TT.d)), 20.0, 10.0)
	out.append(tt[0])
	# hàng 3: tiền công (rẻ nhất: xanh), nhờ việc
	cy += 24.0
	cx = tx
	var P := ([_co(job) + " · " + str(W.wage(s)), "c", "/phút"]) if job != "" else (["Từ " + str(_from(s)), "c", "/phút"])
	var pw := float(_rowi(0.0, 0.0, 20.0, P, 10.0, 700, "")[1]) + 12.0
	var gr: bool = cheap and job == ""
	var wc := _chip(cx, cy, pw, 20.0, String(JK.get(job, "j_xuong")) if job != "" else ("got" if gr else "fut"))
	wc.kids = _rowi(cx + 6.0, cy, 20.0, P, 10.0, 700, "rgb(46, 120, 50)" if gr else BROWN)[0]
	if gr:
		wc.act = _dsay.bind(nm + " thuê rẻ nhất trong số nhà đang rảnh.")
	out.append(wc)
	cx += pw + 5.0
	if gr:
		var rc0 := _tchip(cx, cy, "Rẻ nhất", "got", "rgb(46, 120, 50)", null, 20.0, 10.0)
		out.append(rc0[0])
		cx += float(rc0[1]) + 5.0
	if W._tr(s.get("req")):
		var rc := _tchip(cx, cy, "Nhờ việc ›", "sen", "rgb(170, 50, 60)", _go.bind(u), 20.0, 10.0)
		out.append(rc[0])
	# hàng 4: thông số sở trường (như tab Sở trường bên Nhà dân)
	cy += 24.0
	if W.W3.has(r):
		var l: Dictionary = W.W3[r]
		var b2 := ("Xưởng nhanh " + str(4 * o) + "%") if r == "xuong" else (_cap(String(l.d).replace(" 1", "")) + " " + str(W.b_l(o)) + "%")
		out.append(_dt(tx, cy, tw, 14.0, _fitw("Công rẻ " + str(W.q_l(o)) + "% · " + b2 + (" · đang đúng nghề" if W.k9(s) else ""), 10.0, 700, tw), 10.0, 700, "rgb(46, 120, 50)", "left"))
		cy += 14.0
	yy = maxf(cy, yy + 40.0) + 9.0
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
