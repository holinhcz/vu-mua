extends "res://logic/ui_ls.gd"
# HỘI ĐÌNH (hdnOpen / hdnRender bản web, Sổ làng › Bà con lối xóm): bảng sổ có tab chung (ui_ls.gd), 3 tab:
# Mở hội (định ngày, lễ vật bà con góp, việc mình lo, hoãn), Giải thi (đá dế, đố vui), Sổ hội.
# Luật ở w_htx.gd (hdn_*).

var WH         # w_htx.gd
var tab := "mo"             # HDNV.tab
const TABS := [["mo", "Mở hội"], ["giai", "Giải thi"], ["so", "Sổ hội"]]

func _init(ui, wh) -> void:
	super(ui)
	WH = wh

func open(t := "") -> void:   # hdnOpen
	if t != "":
		tab = t
	on = true
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:   # hdnRender mỗi giây
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	return JSON.stringify([tab, WH.hdn_s(), G.g.coins, G.g.barn, WH._vr(), WH.WL.ut_s().get("c")])

func _build() -> void:
	sig = _sig()
	var dot := {"mo": not WH._tr(WH.hdn_s().get("cur")) and WH.hdn_why() == "", "giai": WH.hdn_red() > 0 and WH.hdn_today()}
	var L := TABS.map(func(x): return [x[0], String(x[1]) + (" •" if dot.get(x[0], false) else ""), false])
	var blocks: Array
	match tab:
		"giai":
			blocks = _giai()
		"so":
			blocks = _so()
		_:
			blocks = _mo()
	_ls_build(L, tab, _tab_go, blocks)

func _tab_go(k: String) -> void:   # data-hdn="tab"
	if tab != k:
		tab = k
		scroll = 0.0

func _ten(cu: Dictionary) -> String:   # "đá dế, đố vui"
	return ", ".join(PackedStringArray(cu.giai.map(func(id): return String(WH.HDNG[id]).replace("Giải ", ""))))

# ------------------------------------------------------------------ tab Mở hội (hdnTabMo)
func _mo() -> Array:
	var o: Dictionary = WH.hdn_s()
	var cu = o.get("cur")
	var day: int = WH._vr()
	var out := []
	if not WH._tr(cu):
		var why: String = WH.hdn_why()
		var big: bool = WH.hdn_big()
		var mon := str(WH.hdn_mon(WH.hdn_day_pick()))
		out.append(_card_nv(UT.card, ("Hội lớn" if big else "Hội nhỏ") + " · đá dế, đố vui", [["tháng này ", false], [str(WH._i(o.m.get(mon))), true], ["/" + str(WH.hdn_max()), false]], null,
			[["Định ngày rồi 3 ngày sau mở hội ở sân đình. Bà con góp lễ, mình dựng cổng treo cờ. Hội đông được +20 tới +50 uy tín, đoạt giải được thêm." + ("" if big else " Lên Trưởng ấp thì mở được hội lớn."), false]]))
		out.append(_big(why if why != "" else "Định ngày mở hội", "primary", why == "", WH.hdn_open_hoi))
		return out
	var left := int(cu.d) - day
	var runs := []
	if left > 0:
		runs = [["Bà con góp lễ mỗi ngày. Góp đủ, dựng cổng, treo cờ thì hội đông.", false]]
	elif WH._tr(cu.get("att")):
		runs = [[str(cu.att.size()), true], ["/" + WH._sa(cu.tot) + " nhà tới dự. Trò chuyện với nhà đi dự được thân gấp đôi. Tối có hội chợ ở sân đình.", false]]
	out.append(_card_nv(UT.card, ("Hội lớn" if WH._tr(cu.big) else "Hội nhỏ") + " · " + _ten(cu), [["còn ", false], [str(left), true], [" ngày", false]] if left > 0 else [["hôm nay", true]], null, runs))
	if left > 0:
		out.append(_sec2("Lễ vật", "Mình góp tối đa nửa mỗi món, nửa kia bà con góp."))
		var rows := []
		for r in WH.HDNRES:
			var k := String(r[0])
			var gt: float = WH._n(cu.got[k])
			var nd: float = WH._n(cu.need[k])
			var full := gt >= nd
			var mm: int = WH.hdn_me(cu, k)
			rows.append({"b": String(WH.HDNMON[k]) + ": " + WH._sa(gt) + "/" + WH._sa(nd), "bar": gt / maxf(1.0, nd),
				"s": "" if full else ("Mình góp được thêm " + WH._sa(mm) + " " + String(r[1]) if mm else "Đủ phần mình, chờ bà con góp"),
				"right": "done" if full else ["Góp", false, mm > 0, WH.hdn_give.bind(k)], "me": full})
		out.append(_rows(rows))
	if left >= 0:
		out.append(_sec2("Việc mình lo", "Mỗi việc +2 uy tín, hội đông hơn."))
		var rows := []
		for k in WH.HDNVIEC:
			var V: Array = WH.HDNVIEC[k]
			var q: Dictionary = WH.hdn_scale(V[2])
			var done: bool = WH._tr(cu.v.get(k))
			var cost := []
			for kk in q:
				cost.append(WH._sa(q[kk]) + " " + String(WH.WL.WD.TNRES.get(kk, kk)))
			rows.append({"b": V[0], "s": "" if done else "Tốn " + ", ".join(PackedStringArray(cost)),
				"right": "done" if done else ["Làm", WH.WL.WD.tn_have(q), true, WH.hdn_viec.bind(k)], "me": done})
		out.append(_rows(rows))
	if left > 0:
		out.append(_big("Hoãn hội (−10 uy tín)", "plain", true, WH.hdn_huy))
	return out

# ------------------------------------------------------------------ tab Giải thi (hdnTabGiai)
func _giai() -> Array:
	var cu = WH.hdn_s().get("cur")
	if not WH._tr(cu):
		return [_sum2([["Chưa định ngày mở hội. Qua tab Mở hội để định ngày.", false]])]
	var today: bool = WH._vr() == int(cu.d)
	var out := []
	if today:
		out.append(_sum2([["Hôm nay thi. Mỗi giải thi 1 lần, bỏ ngang tính thua. Nhất ", false], ["+10", true], [" uy tín, nhì ", false], ["+6", true], [", ba ", false], ["+3", true], [", kèm xu.", false]]))
	else:
		out.append(_sum2([["Tới ngày hội mới thi, còn ", false], [str(int(cu.d) - WH._vr()), true], [" ngày.", false]]))
	var rows := []
	for id in cu.giai:
		var gg = cu.g.get(id)
		if not (gg is Dictionary):
			gg = {"rd": 0, "st": "chua"}
		var xong: bool = gg.st == "xong"
		var sub := ""
		if xong:
			sub = "Đoạt giải " + WH.HDNHANG[int(gg.rank)] if WH._tr(gg.get("rank")) else "Chưa vào giải"
		elif id == "de":
			var rd: int = WH._i(gg.rd)
			sub = WH.HDNVONG[rd] + ": gặp nhà " + String(WH.hdn_names(cu, id, 3)[rd]) + " (dế cấp " + str(WH.hdn_de_lv(rd)) + ")"
		else:
			sub = "10 câu, thi với nhà " + ", ".join(PackedStringArray(WH.hdn_names(cu, "do", 4)))
		var rt = ("done" if WH._tr(gg.get("rank")) else "none") if xong else ["Vào thi", today, today, WH.hdn_play.bind(String(id))]
		rows.append({"b": WH.HDNG[id], "s": sub, "right": rt, "me": xong and WH._tr(gg.get("rank"))})
	out.append(_rows(rows))
	return out

# ------------------------------------------------------------------ tab Sổ hội (hdnTabSo)
func _so() -> Array:
	var o: Dictionary = WH.hdn_s()
	var day: int = WH._vr()
	if o.log.is_empty():
		return [_sum2([["Chưa mở hội đình nào.", false]])]
	var rows := []
	for r in o.log:
		var ago := day - int(r.d)
		var gs := []
		for id in r.g:
			gs.append(String(WH.HDNG.get(id, id)).replace("Giải ", "") + ": " + ("giải " + WH.HDNHANG[int(r.g[id])] if WH._tr(r.g[id]) else "không giải"))
		rows.append({"b": ("Hội lớn" if WH._tr(r.big) else "Hội nhỏ") + " · " + ("hôm qua" if ago <= 1 else str(ago) + " ngày trước"),
			"s": WH._sa(r.att) + "/" + WH._sa(r.tot) + " nhà dự" + (" · " + " · ".join(PackedStringArray(gs)) if gs.size() else "")})
	return [_rows(rows)]
