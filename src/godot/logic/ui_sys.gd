extends "res://logic/ui_kbang.gd"
# (11-28) HỆ THỐNG (gu("sys") / htRender bản web, Menu › Hệ Thống) trên khung chung (ui_kbang: tab chung, khung sen, đáy chung),
#   thay khung sổ cũ (ui_ls, mẫu sys.json / sys_tab.json: ô tóm tắt bị đè, dòng có nút che chữ phụ).
#   Tab Nhiệm vụ (htTabNv), Nhánh (htTabPt), Cửa hàng (htTabShop + Túi đặc sản DH + Xe hàng BX).
#   Đầu thân: dòng tóm tắt Điểm · Nhánh · Hôm nay. Dòng việc chung _qrow: tên + chữ phụ (xuống dòng, không bị nút che) + nút bên phải.
#   Luật ở w_sys.gd.

var W          # w_sys.gd
var shop_open := false      # Xe hàng đang mở
const SPICO := {"an": "kh:com", "qua": "d:gift", "giong": "kh:lua", "vat": "d:crate"}
const LEAF := "rgb(95, 178, 74)"

func _init(ui, ws) -> void:
	super(ui)
	W = ws
	snapcut = false

func open(t := "") -> void:   # gu("sys")
	if t != "":
		W.HTV.tab = t
	on = true
	scroll = 0.0
	sig = ""
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
	var red: bool = W.htRed() > 0
	var sh := _kshell([["nv", "Nhiệm vụ", red], ["pt", "Nhánh", false], ["shop", "Cửa hàng", false]], W.HTV.tab, _tab_go)
	var out := []
	var y := 4.0
	var sm := _parab(X0, y, XW, _sum_txt(), 12.0, 700, BROWN)
	out.append_array(sm[0])
	y += float(sm[1]) + 6.0
	match W.HTV.tab:
		"pt":
			y = _pt(out, y)
		"shop":
			y = _shop(out, y)
		_:
			y = _nv(out, y)
	_kmount(sh[0], sh[1], sh[2], out, y)

func _tab_go(k: String) -> void:   # data-ht="tab"
	if W.HTV.tab != k:
		W.HTV.tab = k
		scroll = 0.0
	_build()

func _go(cb: Callable) -> void:   # bấm nút: làm việc rồi dựng lại
	cb.call()
	_build()

func _sum_txt() -> String:   # Điểm · Nhánh · Hôm nay (htSum)
	var o: Dictionary = W.htNv()
	var k = o.kh.get("q") if o.get("kh") is Dictionary else null
	var d := 0
	for q in o.nv.l:
		if W._tr(q.get("ok")):
			d += 1
	var tu: Dictionary = o.tu.q
	var c0 = o.get("c0")
	var t: String = "Điểm " + G.fmt_n(float(W.sys().pts)) + " · Nhánh " + (String(W.HTB[c0]) if W._tr(c0) else "chưa chọn") + " · Hôm nay " + str(d) + "/" + str(o.nv.l.size())
	if k is Dictionary and not W._tr(k.get("ok")):
		t += " · khẩn còn " + G.ao(maxf(0.0, (float(k.t1) - G._now_ms()) / 1000.0))
	else:
		t += " · tuần " + str(W.htQCur(tu)) + "/" + _s(tu.m)
	return t

# ------------------------------------------------------------------ khối chung trong bảng
func _intro(out: Array, y: float, t: String) -> float:   # đoạn giải thích (chữ phụ)
	var p := _para(X0, y, XW, t)
	out.append_array(p[0])
	return y + float(p[1]) + GG

func _ssec(out: Array, y: float, t: String, mid := "") -> float:   # tiêu đề mục chung
	out.append_array(_hd(y + 5.0, t, "", 0.0, mid))
	return y + 26.0 + 6.0

# dòng việc: tên (12 đậm) + chữ phụ xuống dòng trong phần trái nút; B = [[chữ, bấm được?, việc]] (nút xếp từ phải sang)
func _qrow(out: Array, y: float, b: String, sub: String, B: Array, me := false, ic := "") -> float:
	var bw := []
	var bsum := 0.0
	for bb in B:
		var w: float = maxf(54.0, Box.text_w(String(bb[0]), 11.0, 800) + 18.0)
		bw.append(w)
		bsum += w + 6.0
	var ix := 30.0 if ic != "" else 0.0
	var tx := X0 + 10.0 + ix
	var tw := XW - 20.0 - ix - bsum
	var pl := _para(tx, 0.0, tw, sub, 10.5, 600, SUB, 13.0) if sub != "" else [[], 0.0]
	var h := maxf(40.0, 8.0 + 16.0 + float(pl[1]) + 7.0)
	var c := _chip(X0, y, XW, h, "now" if me else "fut")
	c.kids = []
	if ic != "":
		c.kids.append(_hic(X0 + 8.0, y + (h - 24.0) * 0.5, 24.0, ic))
	c.kids.append(_dt(tx, y + 7.0, tw, 16.0, _fitw(b, 12.0, 800, tw), 12.0, 800, BROWN, "left"))
	for k in pl[0]:
		Snap._move(k, Vector2(0.0, y + 24.0))
		c.kids.append(k)
	out.append(c)
	var bx := X0 + XW - 8.0
	for i in B.size():
		var bb: Array = B[i]
		bx -= float(bw[i])
		var cb = _go.bind(bb[2]) if bb[1] and bb[2] is Callable else null
		out.append(_btn(bx, y + (h - 26.0) * 0.5, bw[i], 26.0, String(bb[0]), cb, "go" if bb[1] else "off"))
		bx -= 6.0
	return y + h + 6.0

func _btns(out: Array, y: float, B: Array) -> float:   # hàng nút chia đều bề ngang: [[chữ, đang chọn?, việc]]
	var w := (XW - 6.0 * (B.size() - 1)) / B.size()
	for i in B.size():
		var bb: Array = B[i]
		out.append(_btn(X0 + i * (w + 6.0), y, w, 28.0, String(bb[0]), _go.bind(bb[2]), "go" if bb[1] else "plain"))
	return y + 28.0 + 6.0

# ------------------------------------------------------------------ tab Nhiệm vụ (htTabNv)
func _q(out: Array, y: float, q: Dictionary, i: int, kind: String, o: Dictionary) -> float:   # row(q, i, kind)
	var cur: int = W.htQCur(q)
	var ok: bool = W.htQOk(q)
	var B := []
	var done: bool = W._tr(q.get("ok"))
	if done:
		B = [["Đã nhận", false, null]]
	elif ok:
		B = [["Nhận " + _s(q.pts), true, _nhan.bind(kind, i)]]
	elif kind == "nv" and not W._tr(o.nv.get("doi")):
		B = [["Đổi", true, W.htDoi.bind(i)]]
	var sm := str(cur) + "/" + _s(q.m) + " · " + _s(q.pts) + " điểm"
	if kind == "kh":
		sm += " · còn " + G.ao(maxf(0.0, (float(q.t1) - G._now_ms()) / 1000.0))
	return _qrow(out, y, String(q.t), sm, B, not done and ok)

func _nhan(kind: String, i: int) -> void:   # data-ht="nhan"
	var o: Dictionary = W.htNv()
	if kind == "nv":
		W.htNhan(o.nv.l[i])
	elif kind == "tu":
		W.htNhan(o.tu.q)
	else:
		W.htNhan(o.kh.get("q") if o.get("kh") is Dictionary else null)

func _nv(out: Array, y: float) -> float:
	var o: Dictionary = W.htNv()
	var k: Dictionary = W.htKh()
	var c0 = o.get("c0")
	if W._tr(c0):
		y = _intro(out, y, "Nhiệm vụ ngày theo nhánh chính " + String(W.HTB[c0]) + ". Mỗi ngày đổi được 1 nhiệm vụ. Lên mỗi cấp cũng được 5 điểm.")
	else:
		y = _intro(out, y, "Chưa chọn nhánh, nhiệm vụ ngẫu nhiên. Mỗi ngày đổi được 1 nhiệm vụ. Lên mỗi cấp cũng được 5 điểm.")
	if k.get("q") is Dictionary:
		y = _ssec(out, y, "Nhiệm vụ khẩn")
		y = _q(out, y, k.q, -1, "kh", o) + GG - 6.0
	y = _ssec(out, y, "Hôm nay")
	for i in o.nv.l.size():
		y = _q(out, y, o.nv.l[i], i, "nv", o)
	y += GG - 6.0
	y = _ssec(out, y, "Tuần này")
	y = _q(out, y, o.tu.q, -1, "tu", o) + GG - 6.0
	var T: Array = W.HTTD.filter(func(t): return not W._tr(o.td.get(t[0])))
	if T.size():
		y = _ssec(out, y, "Thành tựu", "làm lần đầu được thưởng một lần")
		for t in T:
			var ok: bool = W.htTdOk(t)
			y = _qrow(out, y, String(t[1]), _s(t[2]) + " điểm", [["Nhận " + _s(t[2]), true, W.htTdNhan.bind(String(t[0]))]] if ok else [], ok)
	return y - 6.0

# ------------------------------------------------------------------ tab Nhánh (htTabPt)
func _br(k: String) -> void:   # data-ht="br"
	W.HTV.br = k

func _pt(out: Array, y: float) -> float:
	var o: Dictionary = W.htS()
	var b: String = W.HTV.br
	var P: Dictionary = W.HTV.pick if W.HTV.get("pick") is Dictionary else {}
	var c0 = o.get("c0")
	var lv: int = W.jr()
	if not W._tr(c0):
		if lv < int(W.HTLV[1]):
			y = _intro(out, y, "Lên cấp " + _s(W.HTLV[1]) + " thì chọn 1 nhánh chính (lên tới tầng 5) và 1 nhánh phụ (tới tầng 3). Giờ mỗi nhánh chỉ mở tầng 1. Bấm từng nhánh để xem trước.")
		else:
			y = _intro(out, y, "Chưa chọn nhánh. Bấm từng nhánh để xem, rồi chọn 1 nhánh chính (lên tới tầng 5) và 1 nhánh phụ (tới tầng 3). Chọn xong bấm Xác nhận mới chốt.")
			if W._tr(P.get("c")):
				var r := []
				r.append(["Chọn lại", true, W.htChon.bind("lai", "")])
				if W._tr(P.get("p")):
					r.append(["Xác nhận", true, W.htChon.bind("ok", "")])
				y = _qrow(out, y, "Chính: " + String(W.HTB[P.c]), ("Phụ: " + String(W.HTB[P.p]) + ". Chốt rồi muốn đổi phải tẩy điểm.") if W._tr(P.get("p")) else "Giờ chọn nhánh phụ.", r, true) + GG - 6.0
	var bs := []
	for kk in W.HTB:
		var k: String = kk
		var lb := ""
		if c0 == k or (not W._tr(c0) and P.get("c") == k):
			lb = " · chính"
		elif o.get("p0") == k or (not W._tr(c0) and P.get("p") == k):
			lb = " · phụ"
		bs.append([String(W.HTB[k]) + lb, b == k, _br.bind(k)])
	y = _btns(out, y, bs)
	if not W._tr(c0) and lv >= int(W.HTLV[1]):
		if not W._tr(P.get("c")) or P.get("c") == b:
			if P.get("c") != b:
				y = _btns(out, y, [["Chọn " + String(W.HTB[b]) + " làm nhánh chính", true, W.htChon.bind("c", b)]])
		elif P.get("p") != b:
			y = _btns(out, y, [["Chọn " + String(W.HTB[b]) + " làm nhánh phụ", true, W.htChon.bind("p", b)]])
	y += GG - 6.0
	for t in range(1, 6):
		var L: Array = W.HTN.filter(func(x): return x.b == b and int(x.t) == t)
		y = _ssec(out, y, "Tầng " + str(t) + (" · tuyệt kỹ" if t == 5 else ""), "cấp " + _s(W.HTLV[t - 1]) + " · " + _s(W.HTGIA[t - 1]) + " điểm/bậc" + (" · không lên tới" if W._tr(c0) and t > W.htCap(b) else ""))
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
			var B := []
			if not (w == "Tối đa" or (k and mx == 1)):
				B = [[w if w != "" else (("Nâng" if k else "Mở") + " · " + _s(W.HTGIA[t - 1])), w == "", W.htBuy.bind(String(x.id))]]
			y = _qrow(out, y, String(x.n) + ((" · " + str(k) + "/" + str(mx)) if mx > 1 else (" · đã có" if k else "")), sm, B, k > 0)
		y += GG - 6.0
	var s: int = W.htSpent()
	if s or W._tr(c0):
		y = _ssec(out, y, "Tẩy điểm")
		y = _qrow(out, y, "Hoàn lại " + str(s) + " điểm", "Chọn lại nhánh. Tốn " + _s(W.HTTAY) + " sen đỏ, 7 ngày một lần.", [["Tẩy · " + _s(W.HTTAY) + " sen", true, W.htReset]])
	return y - 6.0

# ------------------------------------------------------------------ tab Cửa hàng (htTabShop) + Túi đặc sản (DH) + Xe hàng (BX)
func _shop(out: Array, y: float) -> float:
	var n: Dictionary = W.d3()
	var e: float = G._now_ms()
	var lv: int = W.jr()
	y = _intro(out, y, "Đồ dùng mua bằng điểm Hệ Thống, có món giới hạn mỗi ngày.")
	for f in W.WH:
		var lim := int(f.get("lim", 0))
		var s := (lim - int(n.buy.get(f.id, 0))) if lim else 1
		var ok: bool = int(n.pts) >= int(f.c) and s > 0 and W.wh_ok(f) and (not W._tr(f.get("lv")) or lv >= int(f.lv))
		var sm := String(f.d)
		if f.id == "boost" and float(n.get("boost", 0)) > e:
			sm += " Đang có hiệu lực, còn " + G.ao((float(n.boost) - e) / 1000.0) + "."
		if f.id == "bgl" and W._tr(W.htS().get("bgl")):
			sm += " Đang cất " + _s(W.htS().bgl) + " lá."
		y = _qrow(out, y, String(f.n) + ((" · còn " + str(maxi(0, s)) + "/" + str(lim)) if lim else ""), sm,
			[[("Cấp " + _s(f.lv)) if W._tr(f.get("lv")) and lv < int(f.lv) else (_s(f.c) + " điểm"), ok, W.kJ.bind(String(f.id))]])
	y += GG - 6.0
	# Túi đặc sản
	var spec: Dictionary = W.sys().spec
	var c: Array = W.cc.filter(func(f): return int(spec.get(f.id, 0)) > 0)
	y = _ssec(out, y, "Túi đặc sản")
	if c.is_empty():
		y = _intro(out, y, "Đi du lịch hoặc chở hàng tới đâu cũng mang về đặc sản nơi đó.") - GG + 6.0
	for f in c:
		var use: String = String(f.get("use", "")) if W._tr(f.get("use")) else "an"
		var sp := use.split(":")
		var s0: String = sp[0]
		var hh: String = sp[1] if sp.size() > 1 else ""
		var sm := ""
		if s0 == "an":
			sm = "Ăn hồi 30 sức" + ((", " + String(G.BUFFS[hh].n) + " 20 phút") if hh != "" and G.BUFFS.has(hh) else "")
		elif s0 == "qua":
			sm = "Biếu nhà ít thân nhất, +1 ♥"
		elif s0 == "giong":
			sm = "Đổi 1 cây giống cam" if f.id == "na" else "5 hạt giống + 1 hạt quý"
		else:
			sm = "Đổi 2 vật liệu nâng sao"
		y = _qrow(out, y, String(f.spec) + " ×" + _s(spec[f.id]), sm, [[String(W.IH.get(s0, "Dùng")), true, W.FH.bind(String(f.id))]], false, String(SPICO.get(s0, "d:gift")))
	y += GG - 6.0
	# Xe hàng (gập / mở)
	y = _ssec(out, y, "Xe hàng")
	if not shop_open:
		return _btns(out, y, [["Xem nâng cấp xe hàng ›", false, _shop_tog]]) - 6.0
	for o in W.XO:
		var l: Dictionary = W.r8[o]
		var cc := int(W.sys().shop.get(o, 0))
		var mx: bool = cc >= int(l.max)
		y = _qrow(out, y, String(l.name) + " · " + str(cc) + "/" + str(int(l.max)), W.r8_fx(cc) + ". " + ("Đã đạt cấp tối đa." if mx else "Cấp tiếp: " + W.r8_fx(cc + 1)),
			[["Tối đa" if mx else _s(W.TE(o)) + " điểm", not mx and int(W.sys().pts) >= W.TE(o), W.AX.bind(String(o))]])
	return _btns(out, y, [["Thu gọn", false, _shop_tog]]) - 6.0

func _shop_tog() -> void:
	shop_open = not shop_open

static func _s(v) -> String:   # số như JS (không có ".0")
	return str(int(v)) if v is float and v == floor(v) else str(v)
