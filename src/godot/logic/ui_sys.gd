extends "res://logic/ui_ls.gd"
# HỆ THỐNG (gu("sys") / htRender bản web, Menu › Hệ Thống): khung bảng chung (ui_bang.gd) như Kho; trên đầu 3 ô tóm tắt làm tab
# (#htSum .htc: Điểm, Nhánh, Hôm nay), thanh tre ngang (.htrod), thân cuộn (.lsbody) dùng khối chung của ui_ls.gd.
# Tab Nhiệm vụ (htTabNv), Nhánh (htTabPt), Cửa hàng (htTabShop + Túi đặc sản DH + Xe hàng BX).
# Mẫu: ui/snap/sys.json (khung), sys_tab.json (ô tóm tắt, hàng nút .vl-jobs, túi đặc sản, Xe hàng). Luật ở w_sys.gd.

var W          # w_sys.gd
var SB := {}                # khung
var ST := {}                # khối mẫu
var shop_open := false      # details#sysShop đang mở
const SPICO := {"an": "🍜", "qua": "🎁", "giong": "🌱", "vat": "🧰"}
const LEAF := "rgb(95, 178, 74)"   # .pips i.on: var(--leaf)

func _init(ui, ws) -> void:
	super(ui)
	W = ws
	SB = Snap.load_snap("sys")["#pov"][0]
	ST = Snap.load_snap("sys_tab")

func open(t := "") -> void:   # gu("sys")
	if t != "":
		W.HTV.tab = t
	on = true
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:   # htRender mỗi giây (đếm giờ nhiệm vụ khẩn, bùa)
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	var o: Dictionary = W.htNv()
	var k = o.kh.get("q") if o.get("kh") is Dictionary else null
	var t := ""
	if k is Dictionary and not W._tr(k.get("ok")):
		t = G.ao(maxf(0.0, (float(k.t1) - G._now_ms()) / 1000.0))
	var n: Dictionary = W.d3()
	return JSON.stringify([W.HTV.tab, W.HTV.br, W.HTV.get("pick"), W.sys(), W.htS(), o, t, W.jr(), shop_open, G.g.get("sen"),
		G.ao((float(n.get("boost", 0)) - G._now_ms()) / 1000.0) if float(n.get("boost", 0)) > G._now_ms() else ""])

func _build() -> void:
	sig = _sig()
	if W.HTV.tab != "pt" and W.HTV.tab != "shop":
		W.HTV.tab = "nv"
	var n := _cl(SB)
	var hs := _find(n, "htsum")
	hs.kids = _sum_cells()
	var blocks: Array
	match W.HTV.tab:
		"pt":
			blocks = _pt()
		"shop":
			blocks = _shop()
		_:
			blocks = _nv()
	_show(n, _find(n, "lsbody"), blocks, 3.0)
	U._layout()

func _tab_go(k: String) -> void:   # data-ht="tab"
	if W.HTV.tab != k:
		W.HTV.tab = k
		scroll = 0.0

# ------------------------------------------------------------------ 3 ô tóm tắt (htSum)
func _sum_cells() -> Array:
	var o: Dictionary = W.htNv()
	var k = o.kh.get("q") if o.get("kh") is Dictionary else null
	var d := 0
	for q in o.nv.l:
		if W._tr(q.get("ok")):
			d += 1
	var tu: Dictionary = o.tu.q
	var c0 = o.get("c0")
	var lv: int = W.jr()
	var C := [["shop", "Điểm", G.fmt_n(float(W.sys().pts)), "+5 mỗi cấp"],
		["pt", "Nhánh", String(W.HTB[c0]) if W._tr(c0) else "Chưa chọn",
			("Phụ: " + String(W.HTB[o.p0])) if W._tr(c0) else ("Chọn ngay" if lv >= int(W.HTLV[1]) else "Cấp " + _s(W.HTLV[1]) + " mở")],
		["nv", "Hôm nay", str(d) + "/" + str(o.nv.l.size()),
			("Khẩn còn " + G.ao(maxf(0.0, (float(k.t1) - G._now_ms()) / 1000.0))) if k is Dictionary and not W._tr(k.get("ok")) else ("Tuần " + str(W.htQCur(tu)) + "/" + _s(tu.m))]]
	var X := [[16.5, 91.06], [112.06, 113.86], [230.42, 91.06]]
	var red: bool = W.htRed() > 0
	var out := []
	for i in 3:
		var a: bool = W.HTV.tab == C[i][0]
		var c := _cl(ST.htc_on if i == 0 else ST.htc2)
		var sty: Dictionary = ST.htc_on if a else ST.htc
		c.cls = sty.cls
		c.css = sty.css.duplicate(true)
		for pe in ["::before", "::after"]:
			c.erase(pe)
			if sty.has(pe):
				c[pe] = sty[pe].duplicate(true)
		var dx := float(X[i][0]) - float(c.r[0])
		Snap._move(c, Vector2(dx, 0.0))
		c.r[2] = X[i][1]
		var sm: Dictionary = c.kids[0]
		var sp: Dictionary = c.kids[1]
		var em: Dictionary = c.kids[2]
		_txt(sm, String(C[i][1]))
		_txt(em, String(C[i][3]))
		var b: Dictionary = sp.kids[sp.kids.size() - 1]
		_txt(b, String(C[i][2]))
		sp.r[2] = float(b.r[0]) + float(b.r[2]) - float(sp.r[0])
		if C[i][0] == "nv" and red:
			var dt := _cl(ST.htdot)
			_mv(dt, float(X[i][0]) + float(X[i][1]) - 11.25, float(c.r[1]) + 5.25)
			c.kids = [dt] + c.kids
		c.act = _tab_go.bind(String(C[i][0]))
		out.append(c)
	return out

func _txt(n: Dictionary, s: String) -> void:   # chữ một dòng, hộp co theo chữ
	var tw := _tw(n, s)
	n.text = s
	n.r[2] = tw
	if n.has("tr"):
		n.tr = [n.r[0], n.tr[1], tw, n.tr[3]]

# ------------------------------------------------------------------ hàng nút .vl-jobs (nút co theo chữ rồi giãn đều cho đủ hàng)
func _jobs(btns: Array) -> Dictionary:   # btns: [chữ, chính?, act]
	var j := _cl(ST.jobs)
	var x := float(j.r[0])
	var ws := []
	var sum := (btns.size() - 1) * 4.5
	for bb in btns:
		var t: Dictionary = j.kids[1] if bb[1] else j.kids[0]
		var w := _tw(t, String(bb[0])) + 15.0
		ws.append(w)
		sum += w
	var ex := maxf(0.0, (float(j.r[2]) - sum) / btns.size())
	var out := []
	for i in btns.size():
		var bb: Array = btns[i]
		var c := _cl(j.kids[1] if bb[1] else j.kids[0])
		var w: float = float(ws[i]) + ex
		_mv(c, x, float(j.r[1]))
		c.r[2] = w
		var tw := _tw(c, String(bb[0]))
		c.text = bb[0]
		c.tr = [x + (w - tw) * 0.5, c.tr[1], tw, c.tr[3]]
		c.act = bb[2]
		out.append(c)
		x += w + 4.5
	j.kids = out
	return j

# ------------------------------------------------------------------ tab Nhiệm vụ (htTabNv)
func _q_row(q: Dictionary, i: int, kind: String, o: Dictionary) -> Dictionary:   # row(q, i, kind)
	var cur: int = W.htQCur(q)
	var ok: bool = W.htQOk(q)
	var rt = ""
	if W._tr(q.get("ok")):
		rt = ["note", "Đã nhận"]
	elif ok:
		rt = ["Nhận " + _s(q.pts), true, true, _nhan.bind(kind, i)]
	elif kind == "nv" and not W._tr(o.nv.get("doi")):
		rt = ["Đổi", false, true, W.htDoi.bind(i)]
	var sm := str(cur) + "/" + _s(q.m) + " · " + _s(q.pts) + " điểm"
	if kind == "kh":
		sm += " · còn " + G.ao(maxf(0.0, (float(q.t1) - G._now_ms()) / 1000.0))
	return {"b": q.t, "s": sm, "right": rt, "me": not W._tr(q.get("ok")) and ok}

func _nhan(kind: String, i: int) -> void:   # data-ht="nhan"
	var o: Dictionary = W.htNv()
	if kind == "nv":
		W.htNhan(o.nv.l[i])
	elif kind == "tu":
		W.htNhan(o.tu.q)
	else:
		W.htNhan(o.kh.get("q") if o.get("kh") is Dictionary else null)

func _nv() -> Array:
	var o: Dictionary = W.htNv()
	var k: Dictionary = W.htKh()
	var c0 = o.get("c0")
	var out := []
	if W._tr(c0):
		out.append(_sum2([["Nhiệm vụ ngày theo nhánh chính ", false], [String(W.HTB[c0]), true], [". Mỗi ngày đổi được 1 nhiệm vụ. Lên mỗi cấp cũng được 5 điểm.", false]]))
	else:
		out.append(_sum2([["Chưa chọn nhánh, nhiệm vụ ngẫu nhiên. Mỗi ngày đổi được 1 nhiệm vụ. Lên mỗi cấp cũng được 5 điểm.", false]]))
	if k.get("q") is Dictionary:
		out.append(_sec2("Nhiệm vụ khẩn"))
		out.append(_rows([_q_row(k.q, -1, "kh", o)]))
	out.append(_sec2("Hôm nay"))
	var rows := []
	for i in o.nv.l.size():
		rows.append(_q_row(o.nv.l[i], i, "nv", o))
	out.append(_rows(rows))
	out.append(_sec2("Tuần này"))
	out.append(_rows([_q_row(o.tu.q, -1, "tu", o)]))
	var T: Array = W.HTTD.filter(func(t): return not W._tr(o.td.get(t[0])))
	if T.size():
		out.append(_sec2("Thành tựu", "Làm lần đầu được thưởng một lần."))
		out.append(_rows(T.map(func(t):
			var ok: bool = W.htTdOk(t)
			return {"b": t[1], "s": _s(t[2]) + " điểm", "right": ["Nhận " + _s(t[2]), true, true, W.htTdNhan.bind(String(t[0]))] if ok else "", "me": ok})))
	return out

# ------------------------------------------------------------------ tab Nhánh (htTabPt)
func _br(k: String) -> void:   # data-ht="br"
	W.HTV.br = k

func _pt() -> Array:
	var o: Dictionary = W.htS()
	var b: String = W.HTV.br
	var P: Dictionary = W.HTV.pick if W.HTV.get("pick") is Dictionary else {}
	var c0 = o.get("c0")
	var lv: int = W.jr()
	var out := []
	if not W._tr(c0):
		if lv < int(W.HTLV[1]):
			out.append(_sum2([["Lên cấp " + _s(W.HTLV[1]) + " thì chọn 1 nhánh chính (lên tới tầng 5) và 1 nhánh phụ (tới tầng 3). Giờ mỗi nhánh chỉ mở tầng 1. Bấm từng nhánh để xem trước.", false]]))
		else:
			out.append(_sum2([["Chưa chọn nhánh. Bấm từng nhánh để xem, rồi chọn 1 nhánh chính (lên tới tầng 5) và 1 nhánh phụ (tới tầng 3). Chọn xong bấm Xác nhận mới chốt.", false]]))
			if W._tr(P.get("c")):
				var r := []
				if W._tr(P.get("p")):
					r.append(["Xác nhận", true, true, W.htChon.bind("ok", "")])
				r.append(["Chọn lại", false, true, W.htChon.bind("lai", "")])
				out.append(_rows([{"b": "Chính: " + String(W.HTB[P.c]), "s": ("Phụ: " + String(W.HTB[P.p]) + ". Chốt rồi muốn đổi phải tẩy điểm.") if W._tr(P.get("p")) else "Giờ chọn nhánh phụ.", "right": r, "me": true}]))
	var bs := []
	for kk in W.HTB:
		var k: String = kk
		var lb := ""
		if c0 == k or (not W._tr(c0) and P.get("c") == k):
			lb = " · chính"
		elif o.get("p0") == k or (not W._tr(c0) and P.get("p") == k):
			lb = " · phụ"
		bs.append([String(W.HTB[k]) + lb, b == k, _br.bind(k)])
	out.append(_jobs(bs))
	if not W._tr(c0) and lv >= int(W.HTLV[1]):
		if not W._tr(P.get("c")) or P.get("c") == b:
			if P.get("c") != b:
				out.append(_jobs([["Chọn " + String(W.HTB[b]) + " làm nhánh chính", true, W.htChon.bind("c", b)]]))
		elif P.get("p") != b:
			out.append(_jobs([["Chọn " + String(W.HTB[b]) + " làm nhánh phụ", true, W.htChon.bind("p", b)]]))
	for t in range(1, 6):
		var L: Array = W.HTN.filter(func(x): return x.b == b and int(x.t) == t)
		out.append(_sec2("Tầng " + str(t) + (" · tuyệt kỹ" if t == 5 else ""),
			"Mở ở cấp " + _s(W.HTLV[t - 1]) + " · " + _s(W.HTGIA[t - 1]) + " điểm mỗi bậc" + (" · nhánh này không lên tới" if W._tr(c0) and t > W.htCap(b) else "")))
		var rows := []
		for x in L:
			var k := int(o.n.get(x.id, 0))
			var w: String = W.htWhy(x)
			var mx: int = x.v.size()
			var sm := ""
			if W._tr(x.get("soon")):
				sm = W.ht_d(x, 0)
			elif k:
				sm = W.ht_d(x, k - 1) + ((" → " + W.ht_d(x, k)) if k < mx else "")
			else:
				sm = W.ht_d(x, 0)
			var rt = ""
			if not (w == "Tối đa" or (k and mx == 1)):
				rt = [w if w != "" else (("Nâng" if k else "Mở") + " · " + _s(W.HTGIA[t - 1])), w == "", w == "", W.htBuy.bind(String(x.id))]
			rows.append({"b": String(x.n) + ((" · " + str(k) + "/" + str(mx)) if mx > 1 else (" · đã có" if k else "")), "s": sm, "right": rt, "me": k > 0})
		out.append(_rows(rows))
	var s: int = W.htSpent()
	if s or W._tr(c0):
		out.append(_sec2("Tẩy điểm", "Hoàn lại " + str(s) + " điểm đã dùng, chọn lại nhánh. Tốn " + _s(W.HTTAY) + " sen đỏ, 7 ngày một lần."))
		out.append(_jobs([["Tẩy điểm · " + _s(W.HTTAY) + " sen đỏ", false, W.htReset]]))
	return out

# ------------------------------------------------------------------ tab Cửa hàng (htTabShop) + Túi đặc sản (DH) + Xe hàng (BX)
func _shop() -> Array:
	var n: Dictionary = W.d3()
	var e: float = G._now_ms()
	var lv: int = W.jr()
	var out := [_sum2([["Đồ dùng mua bằng điểm Hệ Thống, có món giới hạn mỗi ngày.", false]])]
	var rows := []
	for f in W.WH:
		var lim := int(f.get("lim", 0))
		var s := (lim - int(n.buy.get(f.id, 0))) if lim else 1
		var ok: bool = int(n.pts) >= int(f.c) and s > 0 and W.wh_ok(f) and (not W._tr(f.get("lv")) or lv >= int(f.lv))
		var sm := String(f.d)
		if f.id == "boost" and float(n.get("boost", 0)) > e:
			sm += " Đang có hiệu lực, còn " + G.ao((float(n.boost) - e) / 1000.0) + "."
		if f.id == "bgl" and W._tr(W.htS().get("bgl")):
			sm += " Đang cất " + _s(W.htS().bgl) + " lá."
		rows.append({"b": String(f.n) + ((" · còn " + str(maxi(0, s)) + "/" + str(lim)) if lim else ""), "s": sm,
			"right": [("Cấp " + _s(f.lv)) if W._tr(f.get("lv")) and lv < int(f.lv) else (_s(f.c) + " điểm"), ok, ok, W.kJ.bind(String(f.id))]})
	out.append(_rows(rows))
	out.append(_dh())
	out.append(_bx())
	return out

func _dh() -> Dictionary:   # DH: Túi đặc sản (.sysx)
	var spec: Dictionary = W.sys().spec
	var c: Array = W.cc.filter(func(f): return int(spec.get(f.id, 0)) > 0)
	if c.is_empty():   # p.note thu vào nút ? cạnh tiêu đề
		var q := _cl(ST.sysx_q)
		q.kids[0].kids[0].act = U.say.bind("Đi du lịch hoặc chở hàng tới đâu cũng mang về đặc sản nơi đó.")
		return q
	var x := _cl(ST.sysx)
	var ul: Dictionary = x.kids[1]
	var li0: Dictionary = ul.kids[0]
	var y := float(li0.r[1])
	var lis := []
	for f in c:
		var use: String = String(f.get("use", "")) if W._tr(f.get("use")) else "an"
		var sp := use.split(":")
		var s: String = sp[0]
		var hh: String = sp[1] if sp.size() > 1 else ""
		var sm := ""
		if s == "an":
			sm = "Ăn hồi 30 sức" + ((", " + String(W.Sf[hh].n) + " 20 phút") if hh != "" and W.Sf.has(hh) else "")
		elif s == "qua":
			sm = "Biếu nhà ít thân nhất, +1 ♥"
		elif s == "giong":
			sm = "Đổi 1 cây giống cam" if f.id == "na" else "5 hạt giống + 1 hạt quý"
		else:
			sm = "Đổi 2 vật liệu nâng sao"
		var li := _cl(li0)
		_mv(li, float(li0.r[0]), y)
		var ic: Dictionary = li.kids[0]
		var dv: Dictionary = li.kids[1]
		var bt: Dictionary = li.kids[2]
		ic.text = SPICO.get(s, "🎁")
		var lb := String(W.IH.get(s, ""))
		var bw := _tw(bt, lb) + _px(bt, "padding-left") + _px(bt, "padding-right") + 2.0
		var bx := float(li.r[0]) + float(li.r[2]) - bw
		bt.r[0] = bx
		bt.r[2] = bw
		var tw := _tw(bt, lb)
		bt.text = lb
		bt.tr = [bx + (bw - tw) * 0.5, bt.tr[1], tw, bt.tr[3]]
		bt.act = W.FH.bind(String(f.id))
		dv.r[2] = bx - 6.0 - float(dv.r[0])
		_txt(dv.kids[0], String(f.spec) + " ×" + _s(spec[f.id]))
		_txt(dv.kids[1], sm)
		lis.append(li)
		y += float(li.r[3]) + 6.0
	ul.kids = lis
	ul.r[3] = y - 6.0 - float(ul.r[1])
	x.r[3] = y - 6.0 - float(x.r[1])
	return x

func _shop_tog() -> void:   # summary: mở / gập Xe hàng
	shop_open = not shop_open

func _bx() -> Dictionary:   # #sysShop "Xe hàng" (BX phần XO)
	if not shop_open:
		var d := _cl(ST.shop)
		d.kids[0].act = _shop_tog
		return d
	var d := _cl(ST.shop_open)
	d.kids[0].act = _shop_tog
	var ul: Dictionary = d.kids[1]
	var li0: Dictionary = ul.kids[0]
	var y := float(li0.r[1])
	var lis := []
	for o in W.XO:
		var l: Dictionary = W.r8[o]
		var c := int(W.sys().shop.get(o, 0))
		var mx: bool = c >= int(l.max)
		var li := _cl(li0)
		_mv(li, float(li0.r[0]), y)
		var dv: Dictionary = li.kids[0]
		_txt(dv.kids[0], String(l.name))
		dv.kids[1].text = W.r8_fx(c)
		dv.kids[2].text = "Đã đạt cấp tối đa" if mx else "Cấp tiếp: " + W.r8_fx(c + 1)
		for i in 5:
			if i < c:
				dv.kids[3].kids[i].css["background-color"] = LEAF
		var bt: Dictionary = li.kids[1]
		var lb := "Tối đa" if mx else _s(W.TE(o)) + " điểm"
		var tw := _tw(bt, lb)
		bt.text = lb
		bt.tr = [float(bt.r[0]) + (float(bt.r[2]) - tw) * 0.5, bt.tr[1], tw, bt.tr[3]]
		_act(bt, W.AX.bind(String(o)), not mx and int(W.sys().pts) >= W.TE(o))
		lis.append(li)
		y += float(li.r[3])
	ul.kids = lis
	ul.r[3] = y - float(ul.r[1])
	d.r[3] = y - float(d.r[1])
	return d

static func _s(v) -> String:   # số như JS (không có ".0")
	return str(int(v)) if v is float and v == floor(v) else str(v)
