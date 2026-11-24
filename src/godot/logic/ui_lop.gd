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
	# dòng đầu
	var on_n := 0
	for t in W.FS:
		on_n += int(W.qk(t))
	var rd: int = W.ready_keys().size()
	var txt := ("Đang đặt " + str(on_n) + " cái" + (" · " + str(rd) + " cái có cá" if rd > 0 else " · chưa cái nào có cá")) if on_n > 0 else "Chưa đặt cái nào."
	var bw := 84.0
	out.append(_dt(X0 + 4.0, y + 4.0, XW - bw - 12.0, 18.0, _fitw(txt, 11.5, 700, XW - bw - 12.0), 11.5, 700, SUB, "left"))
	if rd > 0:
		out.append(_dbtn(X0 + XW - bw, y, bw, 26.0, "Thăm hết", _visit_all))
	y += 32.0
	# thẻ món đang chọn
	var t := sel
	var e: Dictionary = W.ns[t]
	var s: Dictionary = W.nst(t)
	var v: int = W.lo_lv(t)
	var lk := _lock(t)
	var desc := _rule(s)
	var nx: Dictionary = W.lo_next(t)
	var extra := []
	var btns := []
	if lk != "":
		desc = lk + ". " + desc
	else:
		var full: bool = W.qk(t) >= int(s.max)
		var free: bool = W.lo_free(t)
		btns.append(["Đặt" + ("" if free else " · " + G.fmt_n(int(e.xu)) + " xu"), _lo_put.bind(t), "off" if full else "go"])
	if not nx.is_empty():
		var nl := [["xu", "Xu", int(G.g.coins), int(nx.xu)]]
		for m in nx.m:
			nl.append([String(m[0]), G.item_name(String(m[0])), G.mat_n(String(m[0])), int(m[1])])
		var N: Array = _nchips(0.0, 0.0, XW - 20.0, nl)
		for n in N[0]:
			Snap._move(n, Vector2(X0 + 10.0, 0))
		var HP: Array = _para(X0 + 10.0, 0.0, XW - 20.0, "Lên bậc " + str(v + 1) + ": " + _rule(_merge(e, nx)), 10.5, 700, BROWN, 14.0)
		var hh: float = float(HP[1]) + 5.0
		for n in N[0]:
			Snap._move(n, Vector2(0, hh))
		extra = [HP[0] + N[0], hh + float(N[1]) + 6.0]
		if lk == "":
			btns.append(["Nâng bậc " + str(v + 1), _up.bind(t), "gold" if W.lo_up_ok(t) else "off"])
	var C := _scard(y, IMG + t + ".webp", String(e.n) + " · bậc " + str(v) + ("" if not nx.is_empty() else " (cao nhất)"),
		"Đang đặt " + str(W.qk(t)) + "/" + str(int(s.max)) + ("" if W.jd(t) <= W.qk(t) else " · cất " + str(W.jd(t) - W.qk(t)) + " cái"), desc, btns, extra)
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

func _merge(e: Dictionary, u: Dictionary) -> Dictionary:
	var o := e.duplicate()
	o.merge(u, true)
	return o

func _rule(s: Dictionary) -> String:   # "Chờ 13 phút, mỗi mẻ 4–7 con, xài 10 lần, mồi 2 ốc gạo."
	var b = s.get("bait")
	return "Chờ " + str(int(round(float(s.ms) / 6e4))) + " phút, mỗi mẻ " + str(int(s.q[0])) + "–" + str(int(s.q[1])) + " con, " + ("không mục" if int(s.use) <= 0 else "xài " + str(int(s.use)) + " lần") + (", mồi " + str(int(b[1])) + " " + G.item_name(String(b[0])).to_lower() if b != null else ", không cần mồi") + ", đặt tối đa " + str(int(s.max)) + " cái" + ((", " + ", ".join(s.get("rare", []).map(func(r): return G.item_name(String(r)).to_lower())) + " dễ vô ×" + str(snappedf(float(s.k), 0.1)).replace(".", ",")) if float(s.get("k", 1.0)) > 1.0 else "") + "."

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
