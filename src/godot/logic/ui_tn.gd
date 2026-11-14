extends "res://logic/ui_ls.gd"
# THIÊN TAI, HOẠN NẠN (tnOpen / tnRender bản web, Sổ làng › Bà con lối xóm): bảng sổ có tab chung (ui_ls.gd),
# 3 tab: Phòng chống (tin báo, việc phòng, công trình đỡ), Gặp nạn (lo cho bà con, nhà gặp nạn + Giúp), Sổ thiên tai.
# Luật ở w_duong.gd (tn_prep, tn_help, tn_have, tn_scale, tn_busy, tn_tick), w_lang.gd (tn_s, tn_ok, tn_on, tn_sea).

var W          # w_lang.gd
var WD         # w_duong.gd
var tab := "phong"          # TNV.tab
const TABS := [["phong", "Phòng chống"], ["nan", "Gặp nạn"], ["so", "Sổ thiên tai"]]

func _init(ui, wl, wd) -> void:
	super(ui)
	W = wl
	WD = wd

func open(t := "") -> void:   # tnOpen
	if t != "":
		tab = t
	on = true
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:   # tnRender mỗi giây
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	return JSON.stringify([tab, W.tn_s(), G.g.coins, G.g.barn, W._r0().get("gach"), W._vr(), W.tn_ok()])

func _build() -> void:
	sig = _sig()
	var o: Dictionary = W.tn_s()
	var ev = W.tn_on(W._vr() + 1) if W.tn_ok() else null
	var nan := false
	for uu in o.nan:
		if not W._tr(o.nan[uu].get("x")):
			nan = true
	var dot := {"phong": ev != null and WD.tn_red() > 0, "nan": nan}
	var L := TABS.map(func(x): return [x[0], String(x[1]) + (" •" if dot.get(x[0], false) else ""), false])
	var blocks: Array
	match tab:
		"nan":
			blocks = _nan()
		"so":
			blocks = _so()
		_:
			blocks = _phong()
	_ls_build(L, tab, _tab_go, blocks)

func _tab_go(k: String) -> void:   # data-tn="tab"
	if tab != k:
		tab = k
		scroll = 0.0

func _res(q: Dictionary) -> String:   # "400 xu, 15 củi"
	var a := []
	for k in q:
		a.append(W._sa(q[k]) + " " + String(WD.TNRES.get(k, k)))
	return ", ".join(PackedStringArray(a))

# công trình đỡ thiên tai: [tên, tác dụng, có chưa]
func _ct() -> Array:
	var WR = W.WR
	return [["Giếng làng, lu nước, ao", "Hạn: ruộng trong vòng 4 ô không khô chết.", WR.tn_waters().size() > 0],
		["Giếng làng", "Hạn: bớt 1 nhà mất mùa.", WR.tn_has("well")],
		["Trạm y tế", "Dịch: bớt 1 nhà đau ốm, tiền thuốc còn nửa.", WR.tn_has("tramyt")],
		["Cầu ván qua sông", "Lũ: ruộng ngập hư còn nửa.", WR.tn_has("causong")],
		["Bến ghe", "Lũ: ghe chở đồ cứu trợ, nhà ngập cần nửa đồ.", WR.tn_has("ben")],
		["Đình làng hay trường làng", "Bão, lũ, cháy: nhà gặp nạn ở tạm, vẫn đi làm thuê được.", WD.tn_shelter()],
		["Chùa làng", "Phát cơm cứu đói: đồ giúp bớt 30%, nhà gặp nạn gượng dậy sớm 2 ngày.", WR.tn_has("chua")]]

# ------------------------------------------------------------------ tab Phòng chống (tnTabPhong)
func _phong() -> Array:
	if not W.tn_ok():
		return [_sum2([["Lên ", false], ["cấp " + str(W.TNLV), true], [" mới gặp thiên tai. Tới lúc đó trước mỗi trận 1 ngày sẽ có tin báo.", false]])]
	var o: Dictionary = W.tn_s()
	var day: int = W._vr()
	var ev = W.tn_on(day + 1)
	var out := []
	if ev != null:
		var P: Array = WD.TNPREP[ev.k]
		var ok: Dictionary = o.p if W._num(o.p.get("d")) and int(o.p.d) == int(ev.d) else {}
		var K: Dictionary = WD.TNK[ev.k]
		out.append(_card_nv(UT.card2, String(K.w), [], null, [[String(K.d) + " Hôm nay lo phòng trước thì đỡ hẳn.", false]]))
		out.append(_sec2("Phòng trước", "Chỉ làm được trong hôm nay. Giữ làng xong +3 uy tín."))
		var rows := []
		for j in 2:
			var p = P[j]
			if p == null:
				continue
			var wh := "a" if j == 0 else "b"
			var q: Dictionary = WD.tn_scale(p[2])
			var done: bool = W._tr(ok.get(wh))
			rows.append({"b": ("Giữ làng: " if j else "Giữ ruộng: ") + String(p[0]), "s": String(p[1]) + ("" if done else " Tốn " + _res(q) + "."),
				"right": "done" if done else ["Làm", WD.tn_have(q), true, WD.tn_prep.bind(wh)], "me": done})
		out.append(_rows(rows))
	else:
		var sea: int = W.tn_sea(day)
		var W0: Array = W.TNW[sea] if sea >= 0 and sea < W.TNW.size() else []
		out.append(_sum2([["Chưa có tin thiên tai. Trước mỗi trận 1 ngày sẽ có tin báo, mỗi tháng chừng 2 trận. Mùa " + String(G.SEA_N[sea]).to_lower() + " hay có: ", false],
			[", ".join(PackedStringArray(W0.map(func(w): return String(WD.TNK[w[0]].n).to_lower()))), true], [".", false]]))
	out.append(_sec2("Công trình đỡ thiên tai", "Làng có công trình nào thì trận nào cũng được đỡ."))
	out.append(_rows(_ct().map(func(c): return {"b": c[0], "s": c[1], "right": "done" if c[2] else "none", "me": bool(c[2])})))
	return out

# ------------------------------------------------------------------ tab Gặp nạn (tnTabNan)
func _nan() -> Array:
	var o: Dictionary = W.tn_s()
	var F: Dictionary = W._r0().fam
	var day: int = W._vr()
	var out := []
	if W._tr(o.get("lo")):
		var lo: Dictionary = o.lo
		var n := maxi(1, lo.u.size())
		out.append(_card_nv(UT.card, "Lo cho bà con sau " + String(WD.TNK[lo.k].n).to_lower(), [[W._sv(lo.hp), true], ["/" + str(lo.u.size()), false]], W._n(lo.hp) / n,
			[["Việc của người có chức. Còn " + str(int(lo.d) + 3 - day) + " ngày, giúp được nửa số nhà thì +15 uy tín, bỏ mặc hết thì −15.", false]]))
	if o.nan.is_empty():
		out.append(_sum2([["Xóm bình yên, không nhà nào gặp nạn.", false]]))
		return out
	out.append(_sec2("Nhà gặp nạn", "Giúp trong 3 ngày: +60 thân, +8 uy tín. Quá hạn thì nhà đó buồn (−20 thân) rồi tự gượng dậy."))
	var rows := []
	for uu in o.nan:
		var nn: Dictionary = o.nan[uu]
		var ff = F.get(uu)
		if ff == null:
			continue
		var x: bool = W._tr(nn.get("x"))
		var can: bool = not x and WD.tn_have(nn.need)
		rows.append({"b": String(ff.n) + " · " + String(W.TNNAN.get(nn.k, "")), "s": ("Quá hạn, đang tự gượng dậy." if x else "Còn " + str(int(nn.d) + 3 - day) + " ngày · cần " + _res(nn.need)) + (" · nghỉ làm thuê" if WD.tn_busy(String(uu)) else ""),
			"right": "" if x else ["Giúp", can, true, WD.tn_help.bind(uu)], "me": not x})
	out.append(_rows(rows))
	return out

# ------------------------------------------------------------------ tab Sổ thiên tai (tnTabSo)
func _so() -> Array:
	var o: Dictionary = W.tn_s()
	var day: int = W._vr()
	if o.log.is_empty():
		return [_sum2([["Làng chưa gặp trận thiên tai nào.", false]])]
	var rows := []
	for r in o.log:
		var ago := day - int(r.d)
		var ph := []
		if W._tr(r.get("pa")):
			ph.append("đã giữ ruộng")
		if W._tr(r.get("pb")):
			ph.append("đã giữ làng")
		var p := []
		if W._tr(r.get("cay")):
			p.append("Hư " + W._sv(r.cay) + " ô ruộng")
		if W._tr(r.get("con")):
			p.append(W._sv(r.con) + " con vật bệnh")
		if r.get("nha", []).size():
			p.append("Nạn: " + ", ".join(PackedStringArray(r.nha)))
		var s := " · ".join(PackedStringArray(p))
		rows.append({"b": String(WD.TNK[r.k].n) + " · " + ("hôm nay" if ago <= 0 else str(ago) + " ngày trước"), "s": (s if s != "" else "Không hư hại gì") + (" · " + ", ".join(PackedStringArray(ph)) if ph.size() else "")})
	return [_rows(rows)]
