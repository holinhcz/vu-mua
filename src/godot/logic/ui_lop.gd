extends "res://logic/ui_kbang.gd"
# (bản 547) BẢNG LỜ LỌP (Menu › Làm ăn › Lờ lọp, hoặc nút viên "N lờ có cá") trên khung Kho chung, như tab Đồ nghề của Câu cá:
#  - dòng đầu: đang đặt bao nhiêu cái, mấy cái có cá + nút "Thăm hết" (nhân vật đi gỡ một lượt);
#  - thẻ món đang chọn: hình, "Lờ tre · bậc 2", đang đặt n/tối đa, luật bậc này (chờ, mỗi mẻ, xài được, mồi), bậc kế cần gì
#    (chip xu + vật liệu nâng cấp có/cần), nút Đặt (đóng bảng, chạm ô nước tô xanh) và Nâng bậc;
#  - lưới 3 ô: Lờ tre, Lọp lươn, Giăng câu (bậc, đặt n/tối đa, dấu ✓ khi có cái có cá).
# Luật ở w_ca.gd (lo_lv, nst, lo_next, lo_up, lo_place, ready_keys); cái đã đặt vẽ ở song_ve, chạm -> rm_don (Thăm / Gỡ).

const IMG := "res://ui/img/lo/"
const GRN := "rgb(40, 110, 50)"
var sel := "lo"

func _init(ui) -> void:
	super(ui)
	fit = true

func _W():
	return G.w_all.WCA

func open() -> void:
	on = true
	scroll = 0.0
	sig = ""
	_build()

func _sig() -> String:
	var W = _W()
	var L := []
	for t in W.FS:
		L.append([W.lo_lv(t), W.qk(t), W.jd(t), W.lo_up_ok(t)])
	return JSON.stringify([sel, L, W.ready_keys().size(), G.g.coins, G.lv()])

func _redo() -> void:
	sig = ""
	_build()

func _build() -> void:
	sig = _sig()
	var out := _body()
	var sh := _kshell([], "", func(_k): pass, 0.0)
	_kmount(sh[0], sh[1], float(sh[2]), out[0], float(out[1]))

func _lock(t: String) -> String:   # "" = đặt được
	var W = _W()
	var q: int = W._qf("lo")
	if q > 0:
		return "Lên cấp " + str(q) + " mới mở lờ lọp"
	if t == "giang" and W._o0() <= 0:
		return "Mở một khúc sông Vàm trước đã"
	return ""

func _body() -> Array:
	var W = _W()
	var out := []
	var y := 6.0
	# dòng đầu: dải chip như Kho (hình lờ + số đang đặt / có cá, nút Thăm hết)
	var on_n := 0
	for t0 in W.FS:
		on_n += int(W.qk(t0))
	var rd: int = W.ready_keys().size()
	var bw := 84.0
	var top := _chip(X0, y, XW, 34.0, "now" if rd > 0 else "fut")
	out.append(top)
	out.append(_icx(X0 + 18.0, y + 17.0, 24.0, "pic:" + IMG + "lo.webp"))
	var txt := ("Đang đặt " + str(on_n) + " cái · " + (str(rd) + " cái có cá" if rd > 0 else "chưa có cá")) if on_n > 0 else "Chưa đặt cái nào"
	out.append(_dt(X0 + 34.0, y + 8.0, XW - bw - 44.0, 18.0, _fitw(txt, 11.5, 800, XW - bw - 44.0), 11.5, 800, "rgb(150, 80, 10)" if rd > 0 else BROWN, "left"))
	if rd > 0:
		out.append(_dbtn(X0 + XW - bw - 4.0, y + 4.0, bw, 26.0, "Thăm hết", _visit_all))
	y += 34.0 + GG
	# thẻ món đang chọn: bảng so sánh bậc này -> bậc kế
	var t := sel
	var e: Dictionary = W.ns[t]
	var s: Dictionary = W.nst(t)
	var v: int = W.lo_lv(t)
	var lk := _lock(t)
	var nx: Dictionary = W.lo_next(t)
	var s2: Dictionary = _merge(e, nx) if not nx.is_empty() else {}
	var blk := []
	var yy := 0.0
	for r in _rows(s, s2):
		blk.append(_dt(X0 + 10.0, yy, 92.0, 16.0, _fitw(String(r[0]), 10.5, 700, 92.0), 10.5, 700, SUB, "left"))
		blk.append(_dt(X0 + 104.0, yy, 82.0, 16.0, String(r[1]), 10.5, 800, BROWN, "left"))
		if r.size() > 2:
			blk.append(_dt(X0 + 186.0, yy, 16.0, 16.0, "→", 10.5, 800, SUB))
			blk.append(_dt(X0 + 204.0, yy, XW - 214.0, 16.0, String(r[2]), 10.5, 800, GRN if r[3] else BROWN, "left"))
		yy += 17.0
	yy += 4.0
	var btns := []
	if lk == "":
		var full: bool = W.qk(t) >= int(s.max)
		var free: bool = W.lo_free(t)
		btns.append(["Đặt" + ("" if free else " · " + G.fmt_n(int(e.xu)) + " xu"), _lo_put.bind(t), "off" if full else "go"])
	if not nx.is_empty():
		var nl := [["xu", "Xu", int(G.g.coins), int(nx.xu)]]
		var nm := []
		for m in nx.m:
			nl.append([_mat_ic(String(m[0])), G.item_name(String(m[0])), G.mat_n(String(m[0])), int(m[1])])
			nm.append(String(m[0]))
		var N: Array = _nchips(0.0, 0.0, XW - 20.0, nl)
		for n in N[0]:
			Snap._move(n, Vector2(X0 + 10.0, yy))
		blk.append_array(N[0])
		yy += float(N[1]) + 4.0
		var HP: Array = _para(X0 + 10.0, yy, XW - 20.0, _where(nm), 10.0, 600, SUB, 13.0)
		blk.append_array(HP[0])
		yy += float(HP[1]) + 6.0
		if lk == "":
			btns.append(["Nâng bậc " + str(v + 1), _up.bind(t), "gold" if W.lo_up_ok(t) else "off"])
	var sub := "Đang đặt " + str(W.qk(t)) + "/" + str(int(s.max)) + ("" if W.jd(t) <= W.qk(t) else " · cất " + str(W.jd(t) - W.qk(t)) + " cái")
	var bt = s.get("bait")
	if bt != null:
		var have: int = int(G.g.barn.get(String(bt[0]), 0))
		sub += " · " + G.item_name(String(bt[0])).to_lower() + " " + str(have) + ("" if have >= int(bt[1]) else " (hết mồi, ít cá hơn)")
	var C := _scard(y, IMG + t + ".webp", String(e.n) + " · bậc " + str(v) + ("" if not nx.is_empty() else " (cao nhất)"), sub, lk, btns, [blk, yy])
	out.append_array(C[0])
	y += float(C[1]) + GG
	# lưới 3 ô
	var cw := (XW - 12.0) / 3.0
	var R: Array = W.ready_keys()
	for i in W.FS.size():
		var k: String = W.FS[i]
		var x: float = X0 + i * (cw + 6.0)
		var c := _chip(x, y, cw, 84.0, "got" if k == sel else "fut")
		c.act = func(): sel = k; _redo()
		out.append(c)
		out.append(_icx(x + cw * 0.5, y + 24.0, 38.0, "pic:" + IMG + k + ".webp"))
		out.append(_dt(x + 3.0, y + 46.0, cw - 6.0, 14.0, String(W.ns[k].n), 10.5, 800, BROWN))
		var has := false
		for key in R:
			if String(key).begins_with(k + "@"):
				has = true
		var low := _lock(k)
		low = ("Bậc " + str(W.lo_lv(k)) + " · " + str(W.qk(k)) + "/" + str(int(W.nst(k).max))) if low == "" else "Chưa mở"
		out.append(_dt(x + 3.0, y + 64.0, cw - 6.0, 14.0, _fitw(low, 9.5, 700, cw - 6.0), 9.5, 700, GRN if has else SUB))
		if has:
			out.append(_dtick(x + cw - 17.0, y + 5.0, 13.0))
	return [out, y + 84.0 + 6.0]

func _rows(s: Dictionary, n: Dictionary) -> Array:   # [nhãn, bậc này, (bậc kế, tốt hơn?)]
	var f := func(d: Dictionary, k: String) -> String:
		match k:
			"ms": return str(int(round(float(d.ms) / 6e4))) + " phút"
			"q": return str(int(d.q[0])) + "–" + str(int(d.q[1])) + " con"
			"use": return "không mục" if int(d.use) <= 0 else str(int(d.use)) + " lần"
			"max": return str(int(d.max)) + " cái"
			"k": return "×" + str(snappedf(float(d.get("k", 1.0)), 0.1)).replace(".", ",")
			"bait":
				var b = d.get("bait")
				return "không cần" if b == null else str(int(b[1])) + " " + G.item_name(String(b[0])).to_lower()
		return ""
	var nm: String = ", ".join(s.get("rare", []).map(func(r): return G.item_name(String(r)).to_lower()))
	var L := [["Chờ", "ms", true], ["Mỗi mẻ", "q", false], ["Xài được", "use", false], ["Đặt tối đa", "max", false], [(nm.substr(0, 1).to_upper() + nm.substr(1) + " dễ vô") if nm != "" else "Con quý", "k", false], ["Mồi", "bait", true]]
	var out := []
	for r in L:
		var a: String = f.call(s, r[1])
		if n.is_empty():
			out.append([r[0], a])
		else:
			var b: String = f.call(n, r[1])
			if a != b:   # (bản 550) hai bậc như nhau (vd mồi "không cần") thì khỏi ghi
				out.append([r[0], a, b, true])
	return out

const ROI := {"harvest": "thu hoạch", "rice": "gặt lúa", "collect": "thu chuồng", "work": "làm xưởng", "chop": "chặt cây", "clear": "dọn cây cỏ",
	"lo": "thăm lờ lọp", "deliver": "giao đơn", "sap": "bán sạp", "help": "giúp làng", "trip": "đi chuyến", "fish": "câu cá"}
func _where(ms: Array) -> String:   # "Cây tre, dây mây rơi khi dọn cây cỏ, chặt cây, thu chuồng, thăm lờ lọp."
	var w := []
	for k in G.D.drop:
		for c in G.D.drop[k]:
			if ms.has(String(c[0])) and ROI.has(k) and not w.has(ROI[k]):
				w.append(ROI[k])
	var nm: String = ", ".join(ms.map(func(m): return G.item_name(String(m)).to_lower()))
	return (nm.substr(0, 1).to_upper() + nm.substr(1)) + " rơi khi " + ", ".join(w) + "."

func _merge(e: Dictionary, u: Dictionary) -> Dictionary:
	var o := e.duplicate()
	o.merge(u, true)
	return o

func _lo_put(t: String) -> void:
	var W = _W()
	if _lock(t) != "":
		_dsay(_lock(t) + ".")
		return
	if W.qk(t) >= int(W.nst(t).max):
		_dsay("Đặt đủ " + str(int(W.nst(t).max)) + " cái rồi. Gỡ bớt cái cũ hoặc nâng bậc.")
		return
	close()
	W.lo_place(t)

func _up(t: String) -> void:
	if _W().lo_up(t):
		_dsay(String(_W().ns[t].n) + " lên bậc " + str(_W().lo_lv(t)) + "!")
	else:
		_dsay("Chưa đủ xu hoặc vật liệu.")
	_redo()

func _visit_all() -> void:
	var ns = G.w_all.WCAU.ext.get("Ns")
	close()
	if not (ns is Callable and ns.is_valid()):
		return
	for k in _W().ready_keys():
		ns.call({"type": "lo", "key": k})
