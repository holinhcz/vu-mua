extends "res://logic/ui_pop.gd"
# HỤI LÀNG (x6 / x4 bản web, Sổ làng › Hụi làng): hộp nổi khung tre (ui_pop.gd).
# Chưa chơi: mức góp mỗi kỳ (3 nút) + chọn chủ hụi (.tt mỗi nhà, nút Vô hụi). Đang chơi: dây hụi (.tt.got) + Hốt hụi.
# Mãn / bể: kết quả + Chơi dây mới. Cuối là Sổ hụi (ul.kh-gb). Luật ở w_htx.gd (y6, vk, u_n, jk, mk, hui_new), w_lang.gd (k_s).

var WH         # w_htx.gd
var w_s := 1                # wS: mức góp đang chọn
const NOTE := "Dây hụi 6 phần: bạn và 5 nhà trong xóm. Cứ 12 tiếng là một kỳ, ai cũng góp một phần. Mỗi kỳ được bỏ thăm hốt một lần: hốt sớm có tiền xài liền mà chịu lãi, hốt chót được lời. Chủ hụi càng thân (♥) càng ít sợ bể hụi."

func _init(ui, wh) -> void:
	super(ui)
	WH = wh

func open() -> void:   # x6
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
	var L = G.g.get("lang")
	return JSON.stringify([w_s, note_open, G.g.get("hui"), L.get("fam") if L is Dictionary else null, G.g.coins, int(WH._d0() * 60.0)])

func _build() -> void:
	sig = _sig()
	_pop(_body())

func _body() -> Array:   # x4
	var W = WH.WL
	var out := [_note_p(NOTE)]
	var a = G.g.get("hui")
	var D: int = WH._D
	if WH._tr(a) and not WH._tr(a.get("done")):
		var e: int = WH.y6()
		var r: float = WH._vr() * 24 + WH._d0()
		var o: float = (float(a.k0) + float(a.paid)) * WH.VN - r
		var l: int = WH.vk(maxi(1, e), float(a.c))
		var c := float(a.c)
		var no: float = WH._n(a.get("no"))
		out.append(_tt_p(true, [["Hụi của " + String(a.n) + " · mỗi phần " + WH._sa(c) + " xu", false]],
			"Kỳ " + str(e) + "/" + str(D) + " · đã góp " + WH._sa(float(a.paid) * c) + " xu" + (" · nợ " + WH._sa(no) if no else "") + " · kỳ tới sau " +
			str(maxi(0, int(floor(o)))) + " giờ " + str(maxi(0, WH._rnd(fmod(o, 1.0) * 60))) + " phút · nguy cơ bể hụi " + WH._ns(WH._rnd(float(W.k_s(a.u)) * 1e3) / 10.0) + "% mỗi kỳ"))
		if WH._tr(a.get("hot")):
			out.append(_note_full("Bạn đã hốt kỳ " + str(a.hot) + ", nhận " + WH._sa(a.got) + " xu. Tiếp tục góp tới mãn hụi nha."))
		else:
			out.append(_tt_p(false, [["Hốt hụi kỳ này: " + WH._sa(l - no) + " xu", false]], "Hốt chót (kỳ 6) được " + WH._sa(WH.vk(D, c)) + " xu. Tổng góp cả dây: " + WH._sa(D * c) + " xu.",
				["Hốt hụi", true, true, WH.jk]))
	elif WH._tr(a) and WH._tr(a.get("done")):
		var pd := float(a.paid) * float(a.c)
		var gt: float = WH._n(a.get("got"))
		var be: bool = WH._tr(a.get("be"))
		out.append(_tt_p(not be, [[("Dây hụi " + String(a.n) + " đã bể") if be else ("Dây hụi " + String(a.n) + " đã mãn"), false]],
			"Góp " + WH._sa(pd) + " xu, nhận " + WH._sa(gt) + " xu (" + ("lời " if gt - pd >= 0 else "lỗ ") + WH._sa(absf(gt - pd)) + " xu).", ["Chơi dây mới", false, true, WH.hui_new]))
	else:
		var c = G.g.get("lang")
		var f: Array = WH._okeys(c.fam) if c is Dictionary and c.get("fam") is Dictionary else []
		if f.size() < 1:
			out.append(_note_full("Xóm chưa có ai ở để rủ chơi hụi. Xây nhà cho dân về ở trước đã."))
		else:
			var s: Array = WH.u_n()
			out.append(_g(_sec_p("Mức góp mỗi kỳ"), 4.5))
			var j := _cl(PT.jobs3)
			for p in mini(3, s.size()):
				var b: Dictionary = j.kids[p]
				var tw := _tw(b, WH._sa(s[p]) + " xu")
				b.text = WH._sa(s[p]) + " xu"
				b.tr = [float(b.r[0]) + (float(b.r[2]) - tw) * 0.5, b.tr[1], tw, b.tr[3]]
				b.act = _pick_c.bind(p)
				if w_s == p:   # aria-pressed
					b.css["border-top"] = "1.33333px solid rgb(78, 155, 68)"
			out.append(_g(j, 7.5))
			out.append(_g(_sec_p("Chọn chủ hụi", "Thân càng nhiều ♥ càng đáng tin."), 4.5))
			WH._stable_sort(f, func(h, p): return int(WH._n(c.fam[p].get("tim")) - WH._n(c.fam[h].get("tim"))))
			var first := true
			for h in f:
				var p: Dictionary = c.fam[h]
				out.append(_g(_tt_p(false, [[String(p.n) + " ", false], [W.e_t(W._i(p.get("tim"))), true]], "Nguy cơ bể hụi " + WH._ns(WH._rnd(float(W.k_s(h)) * 1e3) / 10.0) + "% mỗi kỳ",
					["Vô hụi", true, true, _vo.bind(h)]), 7.5 if first else 6.0))
				first = false
	if WH._tr(a) and a.get("log") is Array and a.log.size():
		out.append(_g(_sec_p("Sổ hụi"), 4.5))
		out.append(_g(_ul_p(a.log), 7.5))
	for i in range(1, out.size()):
		if not out[i].has("gap"):
			out[i].gap = 7.5 if String(out[i].cls).begins_with("tt") else 6.0
	return out

static func _g(b: Dictionary, g: float) -> Dictionary:
	b.gap = g
	return b

func _note_full(s: String) -> Dictionary:   # p.note không gấp
	var p := _cl(PT.note)
	p.erase("::after")
	var st := _cl(p)
	var h := _put(p, [_r(s, st)])
	p.r[3] = h
	return p

func _pick_c(p: int) -> void:   # data-huic
	w_s = p

func _vo(h) -> void:   # data-huiu
	WH.mk(h, int(WH.u_n()[w_s]))
