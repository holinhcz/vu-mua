extends "res://logic/ui_bang.gd"
# UY TÍN LÀNG (utOpen / utRender bản web, Sổ làng › Bà con lối xóm › Uy tín làng): khung chung với Kho (ui_bang.gd),
# 4 tab .khseg.lstabs: Uy tín (utTabUt), Lên chức (utTabBau), Việc xóm (utTabViec), Công trình (ctTab).
# Mẫu: ui/snap/ut.json (khung + tab), ut_tab.json (khối mẫu). Luật ở w_lang.gd (ut*, ct*).

var W          # w_lang.gd
var tab := "ut"             # UTV.tab
var UB := {}                # #pov của bảng Uy tín
var UT := {}                # khối mẫu
const TABS := [["ut", "Uy tín"], ["bau", "Lên chức"], ["viec", "Việc xóm"], ["ct", "Công trình"]]

func _init(ui, wl) -> void:
	super(ui)
	W = wl
	UB = Snap.load_snap("ut")["#pov"][0]
	UT = Snap.load_snap("ut_tab")

func open(t := "") -> void:   # utOpen
	if t != "":
		tab = t
	on = true
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:   # utRender mỗi giây
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	var ds: Array = W.ct_s().ds
	var tl := []
	for c in ds:
		if c.st == "xay":
			tl.append(int(maxf(0.0, (W._n(c.te) - W._now()) / 60000.0)))
	return JSON.stringify([tab, W.ut_s(), W.ct_s(), G.g.coins, W._barn("cui"), W._barn("lua"), W._barn("nhang"), W._r0().get("gach"), W._vr(), tl])

# ------------------------------------------------------------------ dựng
func _build() -> void:
	sig = _sig()
	var n := _cl(UB)
	var seg := _find(n, "lstabs")
	var vt := _find(n, "lsbody")
	var o: Dictionary = W.ut_s()
	var dot := {"bau": W.ut_can_len(), "viec": o.get("vx") is Dictionary and o.vx.get("xu") is Dictionary, "ct": W.ct_red()}
	var L := TABS.map(func(x): return [x[0], String(x[1]) + (" •" if dot.get(x[0], false) else ""), false])
	_seg_tabs(seg, L, tab, _tab_go, {})
	var blocks: Array
	match tab:
		"bau":
			blocks = _bau()
		"viec":
			blocks = _viec()
		"ct":
			blocks = _ct()
		_:
			blocks = _ut()
	var top := 6.0 if blocks.size() and String(blocks[0].cls).begins_with("vl-sec") else 3.0
	_show(n, vt, blocks, top)
	U._layout()

func _tab_go(k: String) -> void:   # data-ut="tab"
	if tab != k:
		tab = k
		scroll = 0.0

# ------------------------------------------------------------------ khối dùng chung trong bảng
func _sb() -> Dictionary:   # kiểu chữ small trong .vlcard
	return _tag_kids(UT.card, "small")[0]

func _bb() -> Dictionary:   # kiểu chữ <b> trong small của .vlcard
	return _tag_kids(UT.card, "small")[0].kids[0]

func _sec2(t: String, small := "") -> Dictionary:   # .vl-sec: <b> [+ <small>]
	var c := _cl(UT.sec if small != "" else UT.sec_b)
	var b: Dictionary = c.kids[0]
	var x := float(c.r[0])
	var y := float(c.r[1])
	var W0 := float(c.r[2])
	var hb := _put(b, [_r(t, _cl(b))], "left", W0)
	b.r = [x, y, W0, hb]
	var h := hb
	if small != "":
		var sm: Dictionary = c.kids[1]
		var sy := y + hb + 3.0
		sm.r = [x, sy, W0, 0.0]
		var hs := _put(sm, [_r(small, _cl(sm))], "left", W0)
		sm.r[3] = hs
		h = sy + hs - y
	c.r[3] = h
	return c

func _sum2(runs: Array) -> Dictionary:   # p.lssum: [[chữ, đậm?]]
	var p := _cl(UT.sum)
	var sp := _cl(p)
	sp.erase("kids")
	var sb: Dictionary = p.kids[0]
	var h := _put(p, runs.map(func(z): return _r(String(z[0]), sb if z[1] else sp)))
	p.r[3] = h
	return p

func _bar(tpl: Dictionary, f: float, x: float, y: float, w: float) -> Dictionary:   # .combar.nvbar > i (width %)
	var b := _cl(tpl)
	_mv(b, x, y)
	b.r[2] = w
	b.kids[0].r[2] = w * clampf(f, 0.0, 1.0)
	return b

# .lslist: mỗi dòng {b, s, bar (0..1 | null), right: "done" | "fail" | "" | ["lsg", chữ, âm?] | [nút: chữ, chính?, bật, act], me}
func _rows(rows: Array) -> Dictionary:
	var ls := _cl(UT.list)
	var x := float(ls.r[0])
	var y := float(ls.r[1])
	var W0 := float(ls.r[2])
	var out := []
	for R in rows:
		var c := _cl(UT.row_me if R.get("me", false) else UT.row)
		var nm: Dictionary = c.kids[0]
		var bb: Dictionary = _cl(nm.kids[0])
		var sm: Dictionary = _cl(nm.kids[1])
		var pl := 4.5
		var pr := 6.0
		var rt = R.get("right", "")
		var rn = null      # nút / dấu / số bên phải
		var rw := 0.0
		if rt is Array and rt[0] == "lsg":
			rn = _cl(UT.lsg_neg if rt[2] else UT.lsg)
			rw = _tw(rn, String(rt[1]))
			rn.text = rt[1]
		elif rt is Array:
			rn = _cl(UT.btnp if rt[1] and rt[2] else UT.btn)
			rw = _tw(rn, String(rt[0])) + _px(rn, "padding-left") + _px(rn, "padding-right") + 2.0
			rn.text = rt[0]
			_act(rn, rt[3], rt[2])
		elif rt == "done" or rt == "fail" or rt == "none":
			rn = _cl(UT.done if rt != "fail" else UT.fail)
			rw = 22.5
			if rt == "none":
				rn.text = ""
		var bw := W0 - pl - pr - ((rw + 6.0) if rn != null else 0.0)
		var hb := _put(bb, [_r(String(R.b), _cl(bb))], "left", bw)
		var ch := hb
		var kids := [bb]
		var bar = null
		if R.get("bar") != null:
			bar = _bar(UT.bar, float(R.bar), x + pl, 0.0, bw)
			ch += 1.4 + 6.0
			kids.append(bar)
		var hs := 0.0
		if String(R.get("s", "")) != "":
			hs = _put(sm, [_r(String(R.s), _cl(sm))], "left", bw)
			ch += 1.5 + hs
			kids.append(sm)
		var h := maxf(33.0, ch + 9.0)
		if rn is Dictionary and rt is Array and rt[0] != "lsg":
			h = maxf(h, 36.0)
		var cy := y + (h - ch) * 0.5
		_mv(c, x, y)
		c.r[2] = W0
		c.r[3] = h
		bb.r = [x + pl, cy, bw, hb]
		_flow_at(bb, x + pl, cy)
		var yy := cy + hb
		if bar != null:
			_mv(bar, x + pl, yy + 1.4)
			yy += 1.4 + 6.0
		if hs > 0.0:
			sm.r = [x + pl, yy + 1.5, bw, hs]
			_flow_at(sm, x + pl, yy + 1.5)
		nm.r = [x + pl, cy, bw, ch]
		nm.kids = kids
		nm.erase("text")
		nm.erase("tr")
		var ck := [nm]
		if rn != null:
			var rh := float(rn.r[3])
			var rx := x + W0 - pr - rw
			_mv(rn, rx, y + (h - rh) * 0.5)
			rn.r[2] = rw
			if rn.has("tr"):
				var tw := _tw(rn, String(rn.text))
				rn.tr = [rx + (rw - tw) * 0.5, float(rn.r[1]) + (rh - float(rn.tr[3])) * 0.5, tw, rn.tr[3]]
			ck.append(rn)
		c.kids = ck
		out.append(c)
		y += h + 3.75
	ls.kids = out
	ls.r[3] = maxf(0.0, y - 3.75 - float(ls.r[1]))
	return ls

func _flow_at(n: Dictionary, x: float, y: float) -> void:   # dời mẩu chữ đã xếp trong n về (x, y)
	var k: Array = n.get("kids", [])
	if k.is_empty():
		return
	var dx := x - float(k[0].r[0])
	var dy := y - float(k[0].r[1])
	for p in k:
		p.r[0] = float(p.r[0]) + dx
		p.r[1] = float(p.r[1]) + dy
		if p.has("tr"):
			p.tr[0] = float(p.tr[0]) + dx
			p.tr[1] = float(p.tr[1]) + dy

func _big(t: String, kind: String, ok: bool, cb: Callable) -> Dictionary:   # button.btn.utbig (kind: "primary" | "plain")
	var b := _cl(UT.bigp if kind == "primary" and ok else UT.big)
	var tw := _tw(b, t)
	b.text = t
	b.tr = [float(b.r[0]) + (float(b.r[2]) - tw) * 0.5, b.tr[1], tw, b.tr[3]]
	return _act(b, cb, ok)

func _card_nv(tpl: Dictionary, left: String, right: Array, bar, runs: Array) -> Dictionary:   # .vlcard: .nvsh [+ thanh] + small (chữ có <b>)
	var c := _cl(tpl)
	var x := float(c.r[0]) + _px(c, "padding-left")
	var W0 := float(c.r[2]) - _px(c, "padding-left") - _px(c, "padding-right")
	var y := float(c.r[1]) + _px(c, "padding-top")
	var hd: Dictionary = c.kids[0]
	y += _nvsh(hd, left, right, x, y, W0) + 6.0
	var kids := [hd]
	if bar != null:
		var b := _bar(UT.bar, float(bar), x, y, W0)
		kids.append(b)
		y += 6.0 + 6.0
	var sm: Dictionary = _cl(_sb())
	var sp := _cl(sm)
	sp.erase("kids")
	var sb := _bb()
	sm.r = [x, y, W0, 0.0]
	var h := _put(sm, runs.map(func(z): return _r(String(z[0]), sb if z[1] else sp)), "left", W0)
	sm.r[3] = h
	kids.append(sm)
	y += h
	c.kids = kids
	c.r[3] = y + _px(c, "padding-bottom") - float(c.r[1])
	return c

# ------------------------------------------------------------------ tab Uy tín (utTabUt)
func _ut() -> Array:
	var o: Dictionary = W.ut_s()
	var p: float = W._n(o.p)
	var c := int(o.c)
	var nx = null
	for m in W.UTM:
		if float(m[0]) > p:
			nx = m
			break
	var out := [_card_nv(UT.card, W.ut_rank(), [[W._sv(o.p), true], ["/1000", false]], p / 1000.0,
		[["Còn ", false], [str(int(nx[0] - p)), true], [" điểm nữa tới mốc \"" + String(nx[1]) + "\".", false]] if nx != null else [["Cả làng kính rồi.", false]])]
	var cs := "Chưa có chức. Đủ điều kiện thì ra họp ở tab Lên chức."
	if c:
		cs = "Đang làm " + String(W.UTCHUC[c]) + ". Thuê dân làm rẻ " + str(W.UTGIAM[c]) + "%." + \
			(" Được đứng ra kêu gọi xây trạm y tế." if c == 1 else (" Được đứng ra kêu gọi xây công trình " + ("bậc ấp" if c == 2 else "bậc ấp, bậc làng") + "." if c > 1 and c < 4 else "")) + \
			(" Làm đủ việc tuần thì tuần sau bà con đem quà tới biếu." if c == 4 else " Mỗi tuần có việc xóm, bỏ việc bị trừ uy tín.")
	out.append(_sec2("Chức trong làng", cs))
	var rows := []
	for i in range(1, W.UTCHUC.size()):
		rows.append({"b": W.UTCHUC[i], "s": "Uy tín " + W._sv(W.UTP[i]) + " · cấp " + W._sv(W.UTLV[i]) + " · làng " + W._sv(W.UTLANG[i][0]) + " nhà", "right": "done" if c >= i else "none", "me": c >= i})
	out.append(_rows(rows))
	if c and c < 4 and p < float(W.UTP[c]):
		out.append(_sum2([["Uy tín đang dưới mốc ", false], [W._sv(W.UTP[c]), true], [" của " + String(W.UTCHUC[c]) + ". Qua ", false], [str(2 - W._i(o.get("low"))), true], [" tuần nữa mà chưa lên lại là làng bầu người khác.", false]]))
	out.append(_sec2("Mới đây", "Việc nào làm lên, làm xuống uy tín."))
	if o.lg.size():
		out.append(_rows(o.lg.map(func(l): return {"b": l[1], "right": ["lsg", ("+" if float(l[0]) > 0 else "") + W._sv(l[0]), float(l[0]) < 0]})))
	else:
		out.append(_sum2([["Chưa có gì. Giúp bà con, đi đám, góp hợp tác xã là lên uy tín.", false]]))
	return out

# ------------------------------------------------------------------ tab Lên chức (utTabBau)
func _bau() -> Array:
	var o: Dictionary = W.ut_s()
	var out := []
	if int(o.c) < 4:
		var c := int(o.c) + 1
		var ok: bool = W.ut_can_len()
		out.append(_sec2("Lên " + String(W.UTCHUC[c]), ("Đủ điều kiện thì các bô lão tới nhà mời lên đình, không cần bầu." if c == 4 else ("Họp tổ với 5 nhà gần nhà mình nhất, quá nửa gật là đậu." if c == 1 else "Họp cả làng, quá nửa số nhà gật mới đậu.")) + (" Rớt thì mai họp lại." if c < 4 else "")))
		out.append(_rows(W.ut_cond(c).map(func(x): return {"b": x[1], "s": x[2] if x.size() > 2 else "", "right": "done" if x[0] else "none", "me": bool(x[0])})))
		var t := "Bữa nay họp rồi, mai họp lại" if W._n(o.get("bd", -1)) == float(W._vr()) else ("Nhận lời làng mời" if c == 4 else ("Họp tổ bầu Tổ trưởng" if c == 1 else "Họp làng bầu " + String(W.UTCHUC[c])))
		out.append(_big(t, "primary", ok, W.ut_bau))
	else:
		out.append(_sum2([["Bạn là ", false], ["Hương cả", true], [", bậc cao nhất trong làng.", false]]))
	if o.get("vr") is Dictionary:
		var v: Dictionary = o.vr
		out.append(_sec2("Lễ rước Hương cả" if int(v.c) == 4 else "Lần bầu " + String(W.UTCHUC[int(v.c)]) + " gần nhất: " + W._sv(v.yes) + "/" + W._sv(v.n) + " nhà gật · " + ("đắc cử" if W._tr(v.won) else "rớt")))
		out.append(_rows(v.ln.map(func(l): return {"b": l[1], "s": l[2], "right": "done" if W._tr(l[0]) else "fail", "me": W._tr(l[0])})))
	return out

# ------------------------------------------------------------------ tab Việc xóm (utTabViec)
func _viec() -> Array:
	var o: Dictionary = W.ut_s()
	if not W._tr(o.c) or not (o.get("vx") is Dictionary):
		return [_sum2([["Làm ", false], ["Tổ trưởng", true], [" trở lên mới có việc xóm. Ra họp ở tab Lên chức.", false]])]
	var out := [_sec2("Việc tuần này", "Xong mỗi việc +10 uy tín, qua tuần còn bỏ việc nào thì bị trừ 15.")]
	var rows := []
	for t in o.vx.t:
		var sub: String = String(t.d) + (" (" + str(o.vx.hop.size()) + "/" + W._sv(t.need) + ")" if t.k == "hop" else (" (" + str(W._i(t.get("n2"))) + "/" + W._sv(t.need) + ")" if t.k == "xu" else ""))
		var rt = ""
		if W._tr(t.get("ok")):
			rt = "done"
		elif t.k == "gop" or t.k == "don":
			rt = ["Góp" if t.k == "gop" else "Đem qua", true, W.ut_give_ok(t), W.ut_give.bind(String(t.k))]
		elif t.k == "xu" and not (o.vx.get("xu") is Dictionary):
			rt = ["Nghe chuyện", true, true, _xu_new]
		rows.append({"b": t.n, "s": sub, "right": rt, "me": W._tr(t.get("ok"))})
	out.append(_rows(rows))
	var x = o.vx.get("xu")
	if x is Dictionary:
		var cs: Dictionary = W.UTXU[int(x.i)]
		out.append(_sec2("Bà con nhờ phân xử" + (" · chuyện khó" if W._tr(cs.get("kho")) else "")))
		out.append(_xu_card(x, cs))
	return out

func _xu_new() -> void:   # data-ut="xu"
	if W.ut_xu_new() == null:
		U.say("Xóm chưa đủ 2 nhà để có chuyện mà xử.")

func _xu_card(x: Dictionary, cs: Dictionary) -> Dictionary:   # .vlcard: chuyện + 3 nút .utop
	var c := _cl(UT.card3)
	var x0 := float(c.r[0]) + _px(c, "padding-left")
	var W0 := float(c.r[2]) - _px(c, "padding-left") - _px(c, "padding-right")
	var y := float(c.r[1]) + _px(c, "padding-top")
	var sm: Dictionary = _tag_kids(c, "small")[0]
	sm.r = [x0, y, W0, 0.0]
	var h := _put(sm, [_r(W.ut_xu_txt(x, String(cs.t)), _cl(sm))], "left", W0)
	sm.r[3] = h
	y += h
	var kids := [sm]
	for j in x.op.size():
		var b := _cl(UT.op)
		var st := _cl(b)
		st.erase("kids")
		_mv(b, x0, y + 6.0)
		b.r[2] = W0
		var pt := _px(b, "padding-top")
		var bh := _put(b, [_r(W.ut_xu_txt(x, String(cs[x.op[j]])), st)], "left", W0 - _px(b, "padding-left") - _px(b, "padding-right"))
		b.r[3] = bh + pt * 2.0
		b.act = W.ut_xu_pick.bind(j)
		kids.append(b)
		y += 6.0 + float(b.r[3])
	c.kids = kids
	c.r[3] = y + _px(c, "padding-bottom") - float(c.r[1])
	return c

# ------------------------------------------------------------------ tab Công trình (ctTab)
func _ct() -> Array:
	var o: Dictionary = W.ct_s()
	var cb: Dictionary = W.WR.ct_built() if W.WR != null else {1: 0, 2: 0, 3: 0}
	var F: Dictionary = W._r0().fam
	var P: Dictionary = W._pi()
	var out := [_card_nv(UT.card2, "Công trình chung", [["xóm ", false], [str(cb[1]), true], [" · ấp ", false], [str(cb[2]), true], [" · làng ", false], [str(cb[3]), true]], null,
		[["Bậc xóm tự mua trong Xây dựng. Bậc ấp, bậc làng phải đứng ra kêu gọi bà con góp xây.", false]])]
	var tk: Array = o.tok.keys().filter(func(b): return W._i(o.tok[b]) > 0)
	if tk.size():
		out.append(_sum2([["Đã khánh thành, chờ đặt: ", false], [", ".join(PackedStringArray(tk.map(func(b): return String(P[b].n) + (" ×" + W._sv(o.tok[b]) if W._i(o.tok[b]) > 1 else "")))), true], [". Vào Xây dựng đặt miễn phí.", false]]))
	for i in o.ds.size():
		var c: Dictionary = o.ds[i]
		var D: Dictionary = P[c.id]
		out.append(_sec2("Đang góp xây: " + String(D.n), "Đang dựng, còn " + G.ao(maxf(0.0, (W._n(c.te) - W._now()) / 1000.0)) + " nữa khánh thành." if c.st == "xay" else "Mỗi ngày bà con góp một ít. Mình góp tối đa nửa mỗi món, nửa kia chờ bà con."))
		var rows := []
		for r in W.CTRES:
			var k: String = r[0]
			var g: float = W._n(c.got[k])
			var nn: float = W._n(c.need[k])
			var ok: bool = g >= nn
			var m: int = W.ct_me(c, k)
			var rt = "done" if ok else ""
			if c.st == "gop" and not ok:
				rt = ["Thuê thợ" if k == "cong" else "Góp", false, m > 0, W.ct_give.bind(i, k)]
			var sub := ""
			if not ok:
				sub = ("Mình góp được thêm " + W._sa(m) + (", 100 xu một công" if k == "cong" else (", đang có " + str(W._i(W._r0().get("gach"))) + " gạch" if k == "gach" else ""))) if m else "Đủ phần mình, chờ bà con góp"
			rows.append({"b": String(r[1]) + ": " + W._sa(g) + "/" + W._sa(nn), "bar": g / maxf(1.0, nn), "s": sub, "right": rt, "me": ok})
		out.append(_rows(rows))
		var by: Array = c.by.keys()
		by.sort_custom(func(a, b): return W._n(c.by[a]) > W._n(c.by[b]))
		by = by.slice(0, 5)
		if by.size():
			out.append(_sec2("Góp nhiều nhất"))
			out.append(_rows(by.map(func(k): return {"b": "Bạn" if k == "me" else (String(F[k].n) if F.has(k) else "Nhà cũ"), "right": ["lsg", W._sa(c.by[k]), false], "me": k == "me"})))
		if c.st == "gop":
			out.append(_big("Khởi công · dựng " + str(W.CTGIO[int(W.CTB[c.id])]) + " tiếng", "primary", W.ct_full(c), W.ct_go.bind(i)))
			out.append(_big("Thôi không xây", "plain", true, W.ct_quit.bind(i)))
	if o.ds.size() < W.CTMAX and int(W.ut_s().c) > 1:
		out.append(_sum2([["Còn góp song song được ", false], [str(W.CTMAX - o.ds.size()), true], [" công trình nữa.", false]]))
	for bac in [2, 3]:
		out.append(_sec2("Công trình " + String(W.CTBN[bac]), "Trưởng xóm trở lên đứng ra kêu gọi. Khánh thành +30 uy tín." if bac == 2 else "Trưởng ấp trở lên đứng ra kêu gọi. Khánh thành +60 uy tín."))
		var rows := []
		for k in W.CTB:
			if int(W.CTB[k]) != bac or not P.has(k):
				continue
			var nd: Dictionary = W.ct_need(k)
			var why: String = W.ct_can_start(k)
			rows.append({"b": P[k].n, "s": W._sa(nd.xu) + " xu · " + str(nd.cui) + " củi · " + str(nd.gach) + " gạch · " + str(nd.cong) + " công" +
				((" · " + String(W.UTCHUC[int(W.CTCHUC[k])]) + " kêu gọi được") if W.CTCHUC.has(k) else "") + ((" · Bia: " + ", ".join(PackedStringArray(o.bia[k].slice(0, 2)))) if o.bia.has(k) else ""),
				"right": ["Kêu gọi", true, why == "", W.ct_start.bind(String(k))]})
		out.append(_rows(rows))
	return out
