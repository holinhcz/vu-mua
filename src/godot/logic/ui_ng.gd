extends "res://logic/ui_bang.gd"
# BẢNG NGHỀ THỦ CÔNG (ngcOpen / ngcRender bản web, nút "Nghề" trong Menu): khung chung với Kho (ui_bang.gd),
# 5 tab .khseg.lstabs: Nghề (ngcTabNghe), Đơn làng (ngcTabDon), Đặt thợ (ngcTabDat), Chợ (ngcTabCho), Thợ giỏi (ngcTabTho).
# Đặt thợ, hàng bạn bè, thợ giỏi bạn bè cần chơi online (bản Godot chưa có bạn bè): hiện như web lúc không online.
# Mẫu: ui/snap/ng.json (khung + tab), ng_tab.json (thân từng tab). Luật ở w_lang.gd.

var W          # w_lang.gd
var tab := "nghe"           # NGCV.tab
var arm := ""               # NGCV.arm: nút đang chờ bấm lần nữa
var rk := ""                # NGCV.rk: nghề đang xem ở Thợ giỏi
var NB := {}                # #pov của bảng Nghề
var NT := {}                # thân mẫu từng tab
const TABS := [["nghe", "Nghề"], ["don", "Đơn làng"], ["dat", "Đặt thợ"], ["cho", "Chợ"], ["tho", "Thợ giỏi"]]
const ONLINE := "Phần này cần chơi online: mở game từ đường link chia sẻ, đăng nhập Claude là thấy bạn bè."

func _init(ui, wl) -> void:
	super(ui)
	W = wl
	NB = Snap.load_snap("ng")["#pov"][0]
	NT = Snap.load_snap("ng_tab")

func open(t := "") -> void:   # ngcOpen
	if t != "":
		tab = t
	on = true
	arm = ""
	scroll = 0.0
	sig = ""
	_build()

func step(dt: float) -> void:   # ngcRender mỗi giây
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 0.5
	if _sig() != sig:
		_build()

func _sig() -> String:
	return JSON.stringify([tab, arm, rk, G.g.coins, G.g.barn, G.g.get("nghe"), G.g.get("ngs"), G.g.get("ndn"), G.g.get("ndt"), G.g.get("hn"), G.g.get("hnk"), W.ng_lock(), W._vr()])

# ------------------------------------------------------------------ dựng
func _build() -> void:
	sig = _sig()
	var n := _cl(NB)
	var seg := _find(n, "lstabs")
	var vt := _find(n, "lsbody")
	var red: bool = W.ng_red() > 0
	var L := TABS.map(func(x): return [x[0], String(x[1]) + (" •" if x[0] == "don" and red else ""), false])
	_seg_tabs(seg, L, tab, _tab_go, {})
	var blocks: Array
	match tab:
		"don":
			blocks = _don()
		"dat":
			blocks = [_sum([_r(ONLINE, _sp())])]
		"cho":
			blocks = _cho()
		"tho":
			blocks = _tho()
		_:
			blocks = _nghe()
	_show(n, vt, blocks)
	U._layout()

func _tab_go(k: String) -> void:   # data-ngc="tab"
	if tab != k:
		tab = k
		scroll = 0.0
		arm = ""

# ------------------------------------------------------------------ khối của bảng Nghề
func _sp() -> Dictionary:   # kiểu chữ p.lssum
	return NT.don.kids[0]

func _sum(runs: Array) -> Dictionary:   # p.lssum
	var n := _cl(NT.don.kids[0])
	var h := _put(n, runs)
	n.r[3] = _px(n, "padding-top") + h + _px(n, "padding-bottom")
	return n

func _lock(s: String) -> Dictionary:   # p.note.lockline
	var n := _cl(NT.lock.kids[0])
	var h := _put(n, [_r(s, n)])
	n.r[3] = _px(n, "padding-top") + h + _px(n, "padding-bottom")
	return n

func _nvsh(n: Dictionary, left: String, right: Array, x: float, y: float, W0: float) -> float:   # .nvsh: <b>trái</b><span>phải (có <b>)</span>
	var b: Dictionary = n.kids[0]
	var sp: Dictionary = n.kids[1]
	var sb: Dictionary = sp.kids[0] if sp.get("kids", []).size() else b
	var rr := right.map(func(z): return _r(String(z[0]), sb if z[1] else sp))
	var rw := 0.0
	for z in rr:
		rw += _dw(z[1], String(z[0]))
	var fr := _flow(rr, x + W0 - rw, y, rw + 1.0, maxf(_lh(sp), 16.2))
	sp.r = [x + W0 - rw, y, rw, fr.h]
	sp.erase("text")
	sp.erase("tr")
	sp.kids = fr.kids
	var fl := _flow([_r(left, b)], x, y, W0 - rw - 6.0, _lh(b) * 0.75)
	b.r = [x, y, W0 - rw - 6.0, fl.h]
	b.erase("text")
	b.erase("tr")
	b.kids = fl.kids
	var h := maxf(fl.h, fr.h)
	n.r = [x, y, W0, h]
	return h

func _jobs(tpl: Dictionary, bt: Array, x: float, y: float, W0: float) -> Dictionary:   # .vl-jobs: nút xếp hàng, giãn đều cho kín dòng
	# bt: [chữ, kiểu ("primary" | "plain"), bật, act]
	var g := _cl(tpl)
	var K: Array = tpl.kids
	var tp: Dictionary = K[0]
	var tn: Dictionary = K[K.size() - 1]
	var rows := [[]]
	var rw := [0.0]
	for o in bt:
		var t: Dictionary = tp if o[1] == "primary" else tn
		var w := _tw(t, String(o[0])) + _px(t, "padding-left") + _px(t, "padding-right") + 2.0
		if rows[-1].size() and rw[-1] + 4.5 + w > W0 + 0.5:
			rows.append([])
			rw.append(0.0)
		rw[-1] += (4.5 if rows[-1].size() else 0.0) + w
		rows[-1].append([o, t, w])
	var out := []
	var yy := y
	for i in rows.size():
		var R: Array = rows[i]
		var ex: float = (W0 - float(rw[i])) / maxf(1.0, R.size())
		var xx := x
		for e in R:
			var o: Array = e[0]
			var c := _cl(e[1])
			var w: float = e[2] + ex
			_mv(c, xx, yy)
			c.r[2] = w
			var tw := _tw(c, String(o[0]))
			c.text = o[0]
			c.tr = [xx + (w - tw) * 0.5, c.tr[1], tw, c.tr[3]]
			c.kids = []
			_act(c, o[3], o[2])
			out.append(c)
			xx += w + 4.5
		yy += 25.5 + 4.5
	g.kids = out
	g.r = [x, y, W0, yy - 4.5 - y]
	return g

func _list(rows: Array, tpl: Dictionary, tbtn = null) -> Dictionary:   # .lslist: [đậm, nhỏ, nút [chữ, bật, act] | null, "me"?]
	var ls := _cl(NT.nghe.kids[3])
	var y := float(ls.r[1])
	var out := []
	for R in rows:
		var c := _cl(tpl)
		if R.size() > 3 and R[3] == "me":
			c = _cl(_find(NT.tho, "me"))
		_mv(c, float(ls.r[0]), y)
		var nm := _find(c, "lsrn")
		var bb: Dictionary = nm.kids[0]
		var sm: Dictionary = nm.kids[1]
		var pad := float(nm.r[0]) - float(c.r[0])
		var bw := float(c.r[2]) - pad * 2.0
		var kids := []
		var btn = null
		if R[2] != null and tbtn != null:
			btn = _cl(tbtn)
			var tw := _tw(btn, String(R[2][0]))
			var w := tw + _px(btn, "padding-left") + _px(btn, "padding-right") + 2.0
			btn.r[2] = w
			bw -= w + 6.0
		var hb := _put(bb, [_r(String(R[0]), bb)], "left", bw)
		bb.r = [nm.r[0], float(c.r[1]) + pad, bw, hb]
		_mv(bb, float(nm.r[0]), float(c.r[1]) + pad)
		var sy := float(c.r[1]) + pad + hb + 1.5
		_mv(sm, float(nm.r[0]), sy)
		var hs := _put(sm, [_r(String(R[1]), sm)], "left", bw)
		sm.r = [nm.r[0], sy, bw, hs]
		_mv(sm, float(nm.r[0]), sy)
		nm.kids = [bb, sm]
		nm.r = [nm.r[0], float(c.r[1]) + pad, bw, hb + 1.5 + hs]
		var h := maxf(pad * 2.0 + hb + 1.5 + hs, 36.0 if btn != null else 0.0)
		kids.append(nm)
		if btn != null:
			var bx := float(c.r[0]) + float(c.r[2]) - pad - float(btn.r[2])
			_mv(btn, bx, y + (h - float(btn.r[3])) * 0.5)
			var tw2 := _tw(btn, String(R[2][0]))
			btn.text = R[2][0]
			btn.tr = [bx + (float(btn.r[2]) - tw2) * 0.5, btn.tr[1], tw2, btn.tr[3]]
			_act(btn, R[2][2], R[2][1])
			kids.append(btn)
		c.kids = kids
		c.r[3] = h
		out.append(c)
		y += h + 3.6
	ls.kids = out
	ls.r[3] = y - 3.6 - float(ls.r[1])
	return ls

# ------------------------------------------------------------------ tab Nghề (ngcTabNghe)
func _nghe() -> Array:
	var n: Dictionary = W.t6()
	var H: Dictionary = W.hn_s()
	var S: Dictionary = W.ng_s()
	var K: Dictionary = G.g.hnk.get("d", {}) if G.g.get("hnk") is Dictionary and G.g.hnk.get("d") is Dictionary else {}
	var Lk: int = W.ng_lock()
	var nl: int = W.hn_learned()
	var hc: int = W.ng_hoc_cho()
	var out := []
	if Lk:
		out.append(_lock("🔒 Nghề thủ công mở ở cấp " + str(Lk) + ". Giờ xem trước được, tới cấp mới học, mới làm."))
	# thẻ đầu
	var c0 := _cl(NT.nghe.kids[0])
	var x := float(c0.r[0]) + _px(c0, "padding-left")
	var W0 := float(c0.r[2]) - _px(c0, "padding-left") - _px(c0, "padding-right")
	var y := float(c0.r[1]) + _px(c0, "padding-top")
	var hd: Dictionary = c0.kids[0]
	var sm: Dictionary = c0.kids[1]
	y += _nvsh(hd, "Nghề chính " + str(S.chinh.size()) + "/" + str(W.NGCHINH), [["đã học ", false], [str(nl), true], ["/" + str(W.M6.size()), false]], x, y, W0) + 6.0
	_mv(sm, x, y)
	var h := _put(sm, [_r("Học ở nhà thầy (tab Sở trường), cả dòng họ chung một nghề. Mỗi món làm ra +1 điểm tay nghề, tối đa " + str(W.ht_ngay()) +
		" điểm một ngày mỗi nghề. Đủ điểm, đủ hàng đã làm thì qua thầy thi lên sao. Chỉ " + str(W.NGCHINH) + " nghề chính lên được 4★, 5★." +
		((" Nghề kế tiền học " + W._sa(W.hn_hp()) + " xu" + (", " + str(hc) + " ngày nữa mới theo học nghề mới" if hc else "") + ".") if nl < W.M6.size() else ""), sm)], "left", W0)
	sm.r[3] = h
	y += h
	c0.r[3] = y + _px(c0, "padding-bottom") - float(c0.r[1])
	out.append(c0)
	var own: Array = W.M6.filter(func(gx): return W._tr(n.get(gx.id)) and W.ng_base(gx.id) != "")
	var rest: Array = W.M6.filter(func(gx): return not W._tr(n.get(gx.id)) and W.ng_base(gx.id) != "")
	for gx in own:
		out.append(_nghe_card(gx, S, K, Lk))
	if rest.size():
		out.append(_sec("Nghề chưa học"))
		var rows := []
		for gx in rest:
			var p = H.p.get(gx.id)
			var who: Array = W.nghe_who(gx.id)
			var hu: int = W._i(K[gx.id].get("h")) if K.get(gx.id) is Dictionary else 0
			var s := ""
			if p is Dictionary:
				var pf = W._fam_of(p.get("u"))
				s = ("Đang học" if H.a == gx.id else "Đang gác") + " ở bước " + str(p.st) + "/4" + (" · nhà " + String(pf.n) if pf != null else "")
			else:
				s = ("Học ở nhà " + ", ".join(PackedStringArray(who)) if who.size() else "Làng chưa có dòng họ nào giữ nghề này") + ". " + String(gx.d)
			rows.append([gx.n, s + (" · làm thử hư " + str(hu) + " lần" if hu else ""), null])
		out.append(_list(rows, NT.nghe.kids[3].kids[0]))
	return out

func _nghe_card(gx: Dictionary, S: Dictionary, K: Dictionary, Lk: int) -> Dictionary:
	var b := String(gx.id)
	var s: int = W.ng_sao(b)
	var q: Array = S.hq.get(b, [0, 0])
	var R: Array = W.ng_rate(b)
	var mx: int = W.ng_max(b)
	var ok: bool = not Lk and W.q_s(gx)
	var C: Array = W.ng_thi_cond(b)
	var rd: bool = W.ng_thi_ready(b)
	var ch: bool = W.ng_chinh(b)
	var hu: int = W._i(K[b].get("h")) if K.get(b) is Dictionary else 0
	var c := _cl(NT.nghe.kids[1])
	var T0: Array = c.kids
	var x := float(c.r[0]) + _px(c, "padding-left")
	var W0 := float(c.r[2]) - _px(c, "padding-left") - _px(c, "padding-right")
	var y := float(c.r[1]) + _px(c, "padding-top")
	var kids := []
	var hd: Dictionary = T0[0]
	y += _nvsh(hd, String(gx.n) + " " + W.ng_stars(s), [["nghề chính", true]] if ch else [["tối đa 3★", false]], x, y, W0) + 6.0
	kids.append(hd)
	var sm: Dictionary = T0[1]
	_mv(sm, x, y)
	var h := _put(sm, [_r("Đã làm " + str(W._i(S.mk.get(b))) + " món · khéo " + str(q[0]) + " · tinh xảo " + str(q[1]) + " · hôm nay +" + str(W.ng_diem_nay(b)) + "/" + str(W.ht_ngay()) +
		" điểm · ra khéo " + str(W._rnd(float(R[0]) * 100.0)) + "%" + (", tinh xảo " + str(W._rnd(float(R[1]) * 100.0)) + "%" if float(R[1]) else "") + " · chợ trả " + W._sa(W.ng_kho(b)) + " xu" +
		(" · làm thử hư " + str(hu) + " lần" if hu else ""), sm)], "left", W0)
	sm.r[3] = h
	kids.append(sm)
	y += h + 6.0
	var nd := _chips(_find(NT.don, "need"), gx["in"].map(func(z): return [z[0], z[1]]), x, y, _find(NT.nghe.kids[1], "ok"))
	kids.append(nd)
	y += float(nd.r[3]) + 9.0
	var sec: Dictionary = T0[3]
	if s < mx and C.size():
		var sb: Dictionary = sec.kids[0]
		var ss: Dictionary = sec.kids[1]
		_mv(sec, x, y)
		var hb := _put(sb, [_r("Thi lên " + str(s + 1) + "★", sb)], "left", W0)
		sb.r = [x, y, W0, hb]
		var yy := y + hb + 0.75
		var lines := []
		for cc in C:
			var ln := _cl(ss)
			_mv(ln, x, yy)
			var lh := _put(ln, [_r(("✓ " if cc[0] else "✗ ") + String(cc[1]), ss)], "left", W0)
			ln.r = [x, yy, W0, lh]
			lines.append(ln)
			yy += lh
		sec.kids = [sb] + lines
		sec.r = [x, y, W0, yy - y]
		kids.append(sec)
		y = yy + 6.0
	else:
		var tn := _cl(sm)
		_mv(tn, x, y)
		var th := _put(tn, [_r("Thợ cả, tay nghề cao nhất." if s >= 5 else "Tới 3★ rồi. Chọn làm nghề chính mới lên tiếp được.", sm)], "left", W0)
		tn.r = [x, y, W0, th]
		kids.append(tn)
		y += th + 6.0
	var bt := [["Làm", "primary" if ok else "plain", ok, _lam.bind(b)]]
	if s < mx:
		bt.append(["Thi lên " + str(s + 1) + "★", "primary" if rd else "plain", rd, _thi.bind(b)])
	if ch:
		bt.append(["Bấm lần nữa: tụt về 3★" if arm == b else "Bỏ nghề chính", "plain", true, _chinh.bind(b)])
	elif S.chinh.size() < W.NGCHINH:
		bt.append(["Chọn nghề chính", "plain", true, _chinh.bind(b)])
	var jb := _jobs(T0[4], bt, x, y, W0)
	kids.append(jb)
	y += float(jb.r[3])
	c.kids = kids
	c.r[3] = y + _px(c, "padding-bottom") - float(c.r[1])
	return c

func _lam(b: String) -> void:   # data-ngc="lam": đóng bảng, nhân vật về nhà làm
	close()
	W.tk(b)

func _thi(b: String) -> void:
	W.ng_thi(b)

func _chinh(b: String) -> void:
	if W.ng_chinh(b) and W.ng_sao(b) > 3 and arm != b:
		arm = b
	else:
		arm = ""
		W.ng_chon_chinh(b)

# ------------------------------------------------------------------ tab Đơn làng (ngcTabDon)
func _don() -> Array:
	var o: Dictionary = W.ng_d()
	var day: int = W._vr()
	if not W.ng_on():
		var Lk: int = W.ng_lock()
		return [_sum([_r("Lên ", _sp()), _r("cấp " + str(Lk), _nbs()), _r(" thì bà con mới đặt đồ nghề.", _sp())] if Lk else [_r("Có hàng xóm thì bà con mới đặt đồ nghề.", _sp())])]
	var out := [_sum([_r("Bà con đặt đồ nghề cho đám cưới, hội đình, nhà gặp nạn, công trình, lễ Tết. Giao đủ được gần gấp đôi giá chợ, thêm thân và uy tín. Quá hạn không giao thì mất thân, mất uy tín; không kịp thì từ chối sớm (trước hạn từ 1 ngày) chỉ bị nửa phạt.", _sp())])]
	var xau: int = W.ng_xau()
	if xau:
		out.append(_card_txt("Đang mang tiếng hứa rồi bỏ", [["còn ", false], [str(xau), true], [" ngày", false]], "Bỏ hoặc từ chối 3 đơn trong 7 ngày nên bà con chưa đặt hàng mới, đơn đang có chỉ trả 80%."))
	if o.l.is_empty():
		out.append(_sum([_r("Chưa có đơn nào" + ("." if xau else ", mỗi ngày có đơn mới."), _sp())]))
		return out
	for d in o.l:
		out.append(_don_card(d, day))
	return out

func _nbs() -> Dictionary:   # chữ đậm trong p.lssum
	var b := _cl(_sp())
	b.css["font-weight"] = "800"
	return b

func _card_txt(left: String, right: Array, s: String) -> Dictionary:   # .vlcard: .nvsh + small
	var c := _cl(NT.don.kids[1])
	var x := float(c.r[0]) + _px(c, "padding-left")
	var W0 := float(c.r[2]) - _px(c, "padding-left") - _px(c, "padding-right")
	var y := float(c.r[1]) + _px(c, "padding-top")
	var hd: Dictionary = c.kids[0]
	y += _nvsh(hd, left, right, x, y, W0) + 6.0
	var sm: Dictionary = _tag_kids(c, "small")[0]
	_mv(sm, x, y)
	var h := _put(sm, [_r(s, sm)], "left", W0)
	sm.r[3] = h
	y += h
	c.kids = [hd, sm]
	c.r[3] = y + _px(c, "padding-bottom") - float(c.r[1])
	return c

func _don_card(d: Dictionary, day: int) -> Dictionary:
	var left := int(d.dl) - day
	var ok: bool = W.ng_don_ok(d)
	var f = W._fam_of(d.u) if W._tr(d.get("u")) else null
	var P: Dictionary = W.NGPHAT.get(String(d.get("src", "")), {})
	var pt := []
	if W._tr(P.get("th")) and f != null:
		pt.append(W._sv(P.th) + " thân")
	if W._tr(P.get("ut")):
		pt.append(W._sv(P.ut) + " uy tín")
	var c := _cl(NT.don.kids[1])
	var T0: Array = c.kids
	var x := float(c.r[0]) + _px(c, "padding-left")
	var W0 := float(c.r[2]) - _px(c, "padding-left") - _px(c, "padding-right")
	var y := float(c.r[1]) + _px(c, "padding-top")
	var kids := []
	var hd: Dictionary = T0[0]
	y += _nvsh(hd, String(d.t), [["còn ", false], [str(left), true], [" ngày", false]] if left > 0 else [["hạn hôm nay", true]], x, y, W0) + 6.0
	kids.append(hd)
	var ch := []
	for z in d.it:
		var id: String = W.ng_id(String(z[0]), int(z[2]))
		ch.append([id, mini(W.ng_has(String(z[0]), int(z[2])), int(z[1])), int(z[1]), String(G.item(id).get("name", id)) + (" trở lên" if int(z[2]) == 1 else "")])
	var nd := _chips(T0[1], ch, x, y, _find(NT.nghe.kids[1], "ok"))
	kids.append(nd)
	y += float(nd.r[3]) + 6.0
	var sm: Dictionary = T0[2]
	_mv(sm, x, y)
	var h := _put(sm, [_r("Trả " + W._sa(d.xu) + " xu" + (" · +" + W._sv(d.ut) + " uy tín" if W._tr(d.get("ut")) else "") + (" · thêm thân nhà " + String(f.n) if W._tr(d.get("th")) and f != null else "") +
		(" · bỏ thì −" + ", −".join(PackedStringArray(pt)) if pt.size() else ""), sm)], "left", W0)
	sm.r[3] = h
	kids.append(sm)
	y += h + 6.0
	var id0 := String(d.id)
	var bt := [["Giao hàng", "primary" if ok else "plain", ok, func(): W.ng_giao(id0)]]
	if not ok:
		bt.append(["Thương lái", "plain", true, _tab_go.bind("cho")])
		bt.append(["Đặt thợ", "plain", true, _tab_go.bind("dat")])
	bt.append(["Bấm lần nữa để từ chối" if arm == "tu" + id0 else "Từ chối", "plain", true, _tu.bind(id0)])
	var jb := _jobs(_find(NT.nghe.kids[1], "vl-jobs"), bt, x, y, W0)
	kids.append(jb)
	y += float(jb.r[3])
	c.kids = kids
	c.r[3] = y + _px(c, "padding-bottom") - float(c.r[1])
	return c

func _tu(id: String) -> void:   # data-ngc="tu": bấm 2 lần
	if arm != "tu" + id:
		arm = "tu" + id
	else:
		arm = ""
		W.ng_tu_choi(id)

# ------------------------------------------------------------------ tab Chợ (ngcTabBan + ngcTabLai)
func _cho() -> Array:
	var out := [_sec("Hàng bạn bè"), _sum([_r(ONLINE, _sp())]), _sec("Thương lái"),
		_sum([_r("Chở hàng nghề từ chợ huyện: chỉ có hàng thường, giá gấp 3, mỗi món 1 cái một ngày. Mua của thợ bạn bè rẻ và tốt hơn.", _sp())])]
	var L: Dictionary = W.ng_lai()
	var rows := []
	for x in W.M6:
		if W.ng_base(x.id) == "":
			continue
		var id := String(x.id)
		var p: int = W._ai(id) * 3
		var n: int = 1 + int(W.htv("t_lai")) - W._i(L.n.get(id))
		var ok: bool = n > 0 and W._n(G.g.coins) >= p
		rows.append([String(G.item(id).get("name", id)) + " · " + W._sa(p) + " xu", ("Còn " + str(n) + " cái hôm nay" if n > 0 else "Hết, mai ghé lại") + " · kho có " + str(_barn(id)),
			["Mua", ok, func(): W.ng_lai_mua(id)]])
	var ls := _list(rows, NT.cho.kids[4].kids[0], NT.cho.kids[4].kids[0].kids[1])
	out.append(ls)
	return out

# ------------------------------------------------------------------ tab Thợ giỏi (ngcTabTho, phần không cần mạng)
func _tho() -> Array:
	var ks: Array = W.M6.filter(func(x): return W.ng_base(x.id) != "")
	if rk == "" or not ks.any(func(x): return x.id == rk):
		rk = String(ks[0].id)
	var bt := []
	for x in ks:
		var id := String(x.id)
		bt.append([String(G.item(id).get("name", id)), "primary" if id == rk else "plain", true, _rk.bind(id)])
	var jb := _jobs(NT.tho.kids[0], bt, 16.5, 0.0, 305.0)
	jb.cls = "vl-jobs"
	var S: Dictionary = W.ng_s()
	var out := [jb, _sum([_r("Thợ " + String(G.item(rk).get("name", rk)).to_lower() + " trong đám bạn bè, xếp theo tay nghề rồi số món làm ra.", _sp())]), _sum([_r(ONLINE, _sp())])]
	if W._tr(W.t6().get(rk)):
		var nm := String(G.g.pc.get("name", "")) if G.g.get("pc") is Dictionary else ""
		nm = (nm if nm != "" else "Bạn").substr(0, 16)   # Os()
		out.append(_list([["1. " + nm + " (mình)", W.ng_stars(W.ng_sao(rk)) + " · " + W._sa(W._i(S.mk.get(rk))) + " món đã làm", null, "me"]], NT.tho.kids[3].kids[0]))
	else:
		out.append(_sum([_r("Chưa ai học nghề này.", _sp())]))
	return out

func _rk(id: String) -> void:   # data-ngc="rk"
	rk = id
