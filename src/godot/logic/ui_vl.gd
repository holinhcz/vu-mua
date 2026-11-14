extends "res://logic/ui_bang.gd"
# BẢNG NHÀ DÂN (a4 bản web, $r.mode === "nha"): chạm vô nhà dân trên làng.
# Khung chung với Kho (.pwin, khung tre, nút X), đầu bảng (.vlhd: mặt, tên, tim, tính, nhà, họ, đang làm, câu nói,
# Trò chuyện / Tặng quà), hàng tab (.khseg.vltabs: Việc nhà, Thuê làm, Mua giống, Sở trường), thân (.vltab, cuộn được).
# Mọi khối lấy đúng bản chụp của web (ui/snap/vl.json, vl_tab.json), chữ dàn lại theo nội dung rồi dựng một lần bằng Snap.
# Luật (trò chuyện, tặng quà, đưa đồ, thuê làm, học nghề...) nằm ở w_lang.gd.

var W          # w_lang.gd
var WC         # w_cho.gd (giống nhà hàng xóm)

var u := -1
var tab := ""               # $r.tab
var sub := ""               # $r.sub: "" | "chat" | "gift"
var cv = null               # $r.cv (trò chuyện)

func _init(ui, wl, wc) -> void:
	super(ui)
	W = wl
	WC = wc

# ------------------------------------------------------------------ mở / đóng
func open(uu: int) -> void:   # gu("nha", u)
	if W._fam_of(uu) == null or W.r1(uu) == null:
		return
	on = true
	u = uu
	tab = ""
	sub = ""
	cv = null
	scroll = 0.0
	sig = ""
	_build()

func close() -> void:   # i1
	cv = null
	sub = ""
	super()

func step(dt: float) -> void:
	chip_step()
	if not on:
		return
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 0.25
	if W._fam_of(u) == null or W.r1(u) == null:
		close()
		return
	if _sig() != sig:
		_build()

func _sig() -> String:
	var f = W._fam_of(u)
	var t = f.get("tt")
	return JSON.stringify([f, tab, sub, cv, G.g.coins, G.g.barn, W.tg().get("ev"), G.g.get("cuoi"), G.g.get("hn"), G.g.get("nghe"), G.night,
		int(G._now_ms() / 1000.0) if W._tr(t) else 0, W._vr()])

# ------------------------------------------------------------------ dựng
func _build() -> void:
	var f = W._fam_of(u)
	if f == null:
		close()
		return
	sig = _sig()
	var n := _cl(B)
	var hd := _find(n, "vlhd")
	var seg := _find(n, "khseg")
	var vt := _find(n, "vltab")
	var dy := _head(hd, f)
	var tabs := _tabs(f)
	var ky := sub if sub != "" else tab
	_seg(seg, tabs)
	if dy != 0.0:
		Snap._move(seg, Vector2(0, dy))
		vt.r = [vt.r[0], float(vt.r[1]) + dy, vt.r[2], float(vt.r[3]) - dy]
	var blocks: Array = _chat() if ky == "chat" else (_gift() if ky == "gift" else _body(f))
	_show(n, vt, blocks)
	# mặt người (canvas bx của web: hình chụp sẵn theo áo f.lk, ngày / đêm)
	var fc: Control = ids.get(".vl-face")
	if fc != null:
		var lk := clampi(W._i(f.get("lk")), 0, 7)
		fc.pic(Css.image("res://ui/img/vlface/" + str(lk) + ("n" if G.night else "") + ".webp"), Rect2(Vector2.ZERO, fc.r.size))
	U._layout()

# ------------------------------------------------------------------ đầu bảng
func _vs(f: Dictionary) -> String:   # _vS
	var j = f.get("job")
	if j == "ruong":
		return "Đang làm ruộng · " + str(W.ux(u).size()) + " ô"
	if j == "vuon":
		return "Đang làm vườn"
	if j == "chan":
		return "Đang chăm chuồng"
	if W._tr(j):
		return "Đang làm " + String(W.CO.get(j, j)).to_lower() + (" · " + String(W._ae(f.jr).get("name", "")).to_lower() if W._tr(f.get("jr")) else "")
	return "Đang ở nhà"

func _head(hd: Dictionary, f: Dictionary) -> float:
	var vlp := _find(hd, "vlp")
	var pi := _find(vlp, "vlpi")
	var K: Array = pi.kids
	var r = W.r1(u)
	var rid := String(r.r.id)
	var nha := String(_yd().get(rid.trim_suffix("2"), "Nhà"))
	var jb := String(_vs(f))
	var p := 100.0 if W._i(f.get("tim")) >= 5 else fmod(W._n(f.get("dp")), 100.0)
	# [mẫu, chữ mới | null]
	var items := [[K[0], String(f.n)], [K[1], W.e_t(W._i(f.get("tim")))], [K[2], null], [K[3], String(W.tinh_of(f).n)],
		[K[4], nha + " · " + str(int(W.CX.get(rid, 0))) + " người"]]
	if W._tr(f.get("ho")):
		items.append([K[5], "Họ " + String(f.ho) + " · đời " + str(W._i(f.get("doi")) if W._i(f.get("doi")) else 1) + " ›"])
	var st: Dictionary = K[6]
	if W._tr(f.get("job")):
		st = _cl(_find(T.ruong_hd, "vlst"))
	items.append([st, jb])
	var dyk := [0.0, 2.0, 6.1, 1.7, 1.3, 2.3, 0.0]   # chỗ đứng của từng món trong dòng (flex-wrap, thẳng hàng chữ)
	var x0 := 64.5
	var xr := x0 + 257.0
	var x := x0
	var row := 0
	var out := []
	var rw := []      # dòng của từng món
	var rh := [0.0]   # cao từng dòng
	for i in items.size():
		var it: Array = items[i]
		var c := _cl(it[0])
		if it[1] != null:
			var s: String = it[1]
			var dw := _tw(c, s) - _tw(c, String(c.get("text", "")))
			c.r[2] = float(c.r[2]) + dw
			c.tr = [c.tr[0], c.tr[1], float(c.tr[2]) + dw, c.tr[3]]
			c.text = s
		if c.cls == "vlbar":
			c.kids[0].r[2] = 39.0 * p / 100.0
		if x > x0 and x + float(c.r[2]) > xr + 0.5:
			row += 1
			x = x0
			rh.append(0.0)
		var di: float = dyk[mini(i, 6)] if i < 5 else (dyk[5] if c.cls == "vlho" else 0.0)
		_mv(c, x, di)
		rh[row] = maxf(rh[row], di + float(c.r[3]))
		rw.append(row)
		x += float(c.r[2]) + 6.0
		out.append(c)
	var H := -1.5
	var tops := []
	for h in rh:
		tops.append(H + 1.5)
		H += h + 1.5
	var top := 106.4 + maxf(0.0, (39.0 - H) * 0.5)
	for i in out.size():
		Snap._move(out[i], Vector2(0, top + tops[rw[i]]))
	pi.kids = out
	var dy := maxf(39.0, H) - 39.0
	vlp.r[3] = maxf(39.0, H)
	var fc := _find(vlp, "vl-face")
	_mv(fc, float(fc.r[0]), 106.4 + dy * 0.5)
	# câu nói + 2 nút
	var tk := _find(hd, "vl-talk")
	if dy != 0.0:
		Snap._move(tk, Vector2(0, dy))
	var qb: Dictionary = tk.kids[0]
	var h0 := float(qb.r[3])
	var h := _put(qb, [_r("“" + W.talk_line(f) + "”", qb)])
	qb.r[3] = h
	var jbx: Dictionary = tk.kids[1]
	var d2 := h - h0
	if d2 != 0.0:
		Snap._move(jbx, Vector2(0, d2))
		dy += d2
	var n: int = W.chat_left(f)
	var gq: bool = W._i(f.get("gq", -1)) == W._vr()
	var bt: Array = jbx.kids
	_btn2(bt[0], "Trò chuyện", "Còn " + str(n) + " lần hôm nay" if n else "Mai ghé tiếp")
	_act(bt[0], _chat_go, n > 0)
	_btn2(bt[1], "Tặng quà", "Hôm nay tặng rồi" if gq else ("Ngày riêng: quý gấp đôi" if W.is_ngay_rieng(u) and f.get("bk") is Dictionary and W._tr(f.bk.get("d")) else "Mỗi ngày 1 món"))
	_act(bt[1], _gift_go, not gq)
	hd.r[3] = float(hd.r[3]) + dy
	return dy

func _yd() -> Dictionary:   # yD: tên loại nhà
	if not has_meta("yd"):
		set_meta("yd", G._j("xay_dung/ten_nha_o") if G._j("xay_dung/ten_nha_o") is Dictionary else {})
	return get_meta("yd")

func _btn2(b: Dictionary, t: String, s: String) -> void:   # nút <b>chữ</b><small>chữ nhỏ</small>: chữ giữa nút
	var kb: Array = b.kids
	for j in kb.size():
		var c: Dictionary = kb[j]
		var tx := t if j == 0 else s
		var w := _tw(c, tx)
		var cx := float(b.r[0]) + float(b.r[2]) * 0.5
		c.r = [cx - w * 0.5, c.r[1], w, c.r[3]]
		c.tr = [cx - w * 0.5, c.tr[1], w, c.tr[3]]
		c.text = tx

func _chat_go() -> void:   # data-chat
	if sub != "":
		return
	var c = W.chat_start(u)
	if c != null:
		cv = c
		sub = "chat"

func _gift_go() -> void:   # data-gift -> giftOpen
	if sub != "":
		return
	var f = W._fam_of(u)
	if W._i(f.get("gq", -1)) == W._vr():
		G.toast.emit("Hôm nay tặng " + String(f.n) + " rồi, mai tặng tiếp nha.")
		return
	sub = "gift"

# ------------------------------------------------------------------ tab
func _tabs(f: Dictionary) -> Array:   # _vB: [khóa, chữ, chấm !]
	var pq_ok: bool = W._tr(f.get("pq")) and f.pq.it.all(func(o): return W._barn(o[0]) >= W._i(o[1]))
	var L := [["viec", "Việc nhà", (W._tr(f.get("req")) and W.r_ok(f.req)) or pq_ok], ["thue", "Thuê làm", false]]
	if WC != null and WC.bZ(u).size():
		L.append(["giong", "Mua giống", false])
	L.append(["tal", "Sở trường", false])
	var ks := L.map(func(z): return z[0])
	if not ks.has(tab):
		tab = L[0][0]
	return L

func _seg(seg: Dictionary, L: Array) -> void:
	_seg_tabs(seg, L, tab, _tab_go, _find(T.req_seg, "vlbd"))

# ------------------------------------------------------------------ khối
func _grid(bt: Array, cols: int, tpl: String) -> Dictionary:
	var g := _cl(T.thue.kids[1] if tpl == "jobs" else T.ruong.kids[4])
	var K: Array = g.kids
	var ton: Dictionary = K[0]
	var toff: Dictionary = K[1]
	var tdis: Dictionary = K[2] if tpl == "jobs" else K[1]
	var bw := (305.0 - (cols - 1) * 4.5) / cols
	var x0 := float(g.r[0])
	var y := float(g.r[1])
	var out := []
	var row := []
	var rh := 0.0
	for i in bt.size():
		var o: Dictionary = bt[i]
		var tp: Dictionary = ton if o.st == "on" else (tdis if o.st == "dis" else toff)
		var c := _cl(tp)
		var col := i % cols
		if col == 0 and i > 0:
			_flush(row, rh, out)
			row = []
			y += rh + 4.5
			rh = 0.0
		_mv(c, x0 + col * (bw + 4.5), y)
		c.r[2] = bw
		var kb: Dictionary = _cl(tp.kids[0])
		var ks: Dictionary = _cl(_find(toff, "", "small") if _find(tp, "", "small").is_empty() else _find(tp, "", "small"))
		var pt := 6.1
		var iw := bw - 2.0 * 6.0
		var cyy := y + pt
		var fb := _flow([_r(String(o.b), kb)], x0 + col * (bw + 4.5) + 6.0, cyy, iw, 12.05, "center")
		var kids: Array = fb.kids
		cyy += fb.h
		if String(o.get("s", "")) != "":
			cyy += 2.2
			var fs := _flow([_r(String(o.s), ks)], x0 + col * (bw + 4.5) + 6.0, cyy, iw, 9.5, "center")
			kids.append_array(fs.kids)
			cyy += fs.h
		c.kids = kids
		c.erase("text")
		c.r[3] = maxf(36.0 if tpl == "jobs" else 30.0, cyy + 6.1 - y)
		rh = maxf(rh, float(c.r[3]))
		if o.st != "dis" and o.has("act"):
			c.act = o.act
		row.append(c)
	_flush(row, rh, out)
	g.kids = out
	g.r[3] = y + rh - float(g.r[1])
	return g

# hộp việc (.vlod): t tiêu đề, list [[món, số]], xu, nhãn nút, act
func _vlod(t: String, list: Array, xu: int, lb: String, act: Callable) -> Dictionary:
	var n := _cl(T.req.kids[1])
	var hh: Dictionary = n.kids[0]
	var hb: Dictionary = hh.kids[0]
	hb.text = t
	var od: Dictionary = n.kids[1]
	var ok_t: Dictionary = od.kids[0]
	var no_t: Dictionary = _find(T.reqno, "no")
	var odr: Dictionary = _find(od, "odr")
	var bt: Dictionary = _find(od, "vlgo")
	var ok := true
	var items := []
	var y := float(od.r[1])
	for x in list:
		var hv: int = W._barn(x[0])
		var q := int(x[1])
		var good := hv >= q
		ok = ok and good
		var c := _cl(ok_t if good else (no_t if not no_t.is_empty() else ok_t))
		_mv(c, float(od.r[0]), y)
		var ic := _find(c, "odic")
		_ic(ic, String(x[0]))
		var tx := _find(c, "odtx")
		var oq := _find(tx, "odq")
		var nm: Dictionary = _tag_kids(tx, "small")[0]
		nm.text = String(W._ae(x[0]).get("name", x[0]))
		var bq: Dictionary = oq.kids[0]
		var s1 := str(mini(hv, q))
		var s2 := "/" + str(q)
		var w1 := _tw(bq, s1)
		var w2 := _tw(oq, s2)
		var rgt := float(c.r[0]) + 181.3
		oq.r = [rgt - w1 - w2, oq.r[1], w1 + w2, oq.r[3]]
		oq.tr = [rgt - w2, oq.tr[1], w2, oq.tr[3]]
		oq.text = s2
		bq.r = [rgt - w1 - w2, bq.r[1], w1, bq.r[3]]
		bq.tr = [rgt - w1 - w2, bq.tr[1], w1, bq.tr[3]]
		bq.text = s1
		if not good:
			c.kids = c.kids.filter(func(k): return k.cls != "odck")
		items.append(c)
		y += 30.0 + 3.8
	var ih: float = items.size() * 30.0 + maxf(0, items.size() - 1) * 3.8
	var oh := maxf(ih, 60.8)
	# xu
	var rb: Dictionary = odr.kids[0]
	var img: Dictionary = rb.kids[0]
	var st: String = "+" + W._sa(xu)
	var w0 := _tw(rb, String(rb.text))
	var w := _tw(rb, st)
	rb.text = st
	img.r[0] = float(img.r[0]) + (w - w0)
	rb.tr = [rb.tr[0], rb.tr[1], w, rb.tr[3]]
	_mv(odr, float(odr.r[0]), float(od.r[1]) + 8.3)
	var b2 := _cl(bt) if ok else _cl(_find(T.reqno, "vlgo"))
	_mv(b2, float(bt.r[0]), float(od.r[1]) + (35.3 if items.size() > 1 else 33.8))
	var bw := _tw(b2, lb)
	b2.text = lb
	b2.tr = [float(b2.r[0]) + (float(b2.r[2]) - bw) * 0.5, b2.tr[1], bw, b2.tr[3]]
	if ok:
		b2.act = act
	od.kids = items + [odr, b2]
	od.r[3] = oh
	n.r[3] = float(od.r[1]) + oh + 7.5 - float(n.r[1])
	return n

# thẻ .vlcard (_vCH): sub (runs), chips [[món, có, cần]], nút [[chữ, primary, bật, act]]
# ------------------------------------------------------------------ thân theo tab
func _body(f: Dictionary) -> Array:
	match tab:
		"thue":
			return _thue(f)
		"giong":
			return _giong(f)
		"tal":
			return _tal(f)
	return _viec(f)

func _viec(f: Dictionary) -> Array:   # _vT.viec
	var L := _nan()
	if W._tr(f.get("pq")):
		L.append(_sec("Việc riêng"))
		L.append(_vlod(String(f.pq.t), f.pq.it, int(f.pq.xu), "Giao", func(): W.iv(u)))
	if W._tr(f.get("req")):
		var c: Dictionary = f.req
		L.append(_sec("Nhà đang cần"))
		L.append(_vlod("Để " + String(c.why), W._r_it(c), int(c.xu), "Đưa", func(): W.gb(u)))
	else:
		L.append(_note([_r(String(f.n) + " chưa cần gì. Lát nữa thế nào cũng nhờ bạn chuyện này chuyện kia.", _np())]))
	L.append_array(_dam())
	L.append_array(_cuoi(f))
	return L

func _dam() -> Array:   # aU: đám tiệc nhà này
	var a = W.tg().get("ev")
	if not (a is Dictionary) or W._i(a.get("u")) != u:
		return []
	var nm: String = W.qm(a)
	if W._tr(a.get("done")):
		return [_note([_r("Bạn đã dự " + nm.to_lower() + ". Gia chủ cảm ơn lắm.", _np())])]
	if not W._tr(W.sg()):
		var e := int(floor(fmod(float(a.t0), 24.0)))
		return [_note([_r(nm, _nb()), _r(" bắt đầu lúc " + ("0" if e < 10 else "") + str(e) + ":00. Tới giờ ghé lại dự nha.", _np())])]
	var r: int = W._v1()
	return [_sec(nm + " đang đãi khách"), _card([_r("Ngồi ăn đám thì phải có phong bì hay chút quà. Vắng mặt gia chủ sẽ trách.", _csm())], [],
		[["Phong bì " + W._sa(W._rnd(100 * (1 + r))) + " xu (+1 ♥)", false, true, func(): W.yk("nho")],
		["Phong bì " + W._sa(W._rnd(300 * (1 + r))) + " xu (+2 ♥)", true, true, func(): W.yk("lon")],
		["Đem quà trong kho (+2 ♥)", false, true, func(): W.yk("qua")]])]

func _cuoi(a: Dictionary) -> Array:   # AU: dạm hỏi
	var c = G.g.get("cuoi")
	if W._tr(c):
		if W._n(c.get("u")) == float(u):
			return [_note([_r("Nhà sui gia! " + String(c.n) + " về làm " + ("vợ" if c.get("g") == "nu" else "chồng") + " bạn rồi.", _np())])]
		return []
	var n: Dictionary = W.n_r(u)
	if W._n(a.get("tim")) < 5:
		if W._n(a.get("tim")) >= 3:
			return [_note([_r("Nhà " + String(a.n) + " có " + String(n.n) + " chưa có gia đình. Thân đủ 5 ♥ thì có thể dạm hỏi.", _np())])]
		return []
	var e: Dictionary = W.b_s()
	return [_sec("Dạm hỏi " + String(n.n)), _card([_r("Bưng mâm quả qua: đu đủ, trứng, 2 bánh phu thê và " + W._sa(e.xu) + " xu tiền dẫn cưới.", _csm())],
		e.it.map(func(o): return [o[0], o[1]]), [["Xin cưới · " + W._sa(e.xu) + " xu", true, W.n_s(), func(): W.sk(u)]])]

func _nan() -> Array:   # aU bọc: nhà đang gặp nạn (thiên tai)
	var tn = G.g.get("tn")
	var nn = tn.nan.get(str(u)) if tn is Dictionary and tn.get("nan") is Dictionary else null
	if not (nn is Dictionary) or W._tr(nn.get("x")):
		return []
	var WD = W.WD
	var ch := []
	var tx := []
	for k in nn.need:
		if k == "xu" or k == "gach":
			var hv: int = WD._tn_hv(k)
			tx.append(W._sa(mini(hv, int(nn.need[k]))) + "/" + W._sa(nn.need[k]) + " " + String(WD.TNRES[k]))
		else:
			ch.append([String(k), int(nn.need[k])])
	return [_sec("Gặp nạn: " + String(W.TNNAN.get(nn.k, "")).to_lower() + " sau " + String(WD.TNK[nn.k].n).to_lower(), "Còn " + str(int(nn.d) + 3 - W._vr()) + " ngày. Giúp thì +60 thân, +8 uy tín."),
		_card([_r("Cần " + ", ".join(PackedStringArray(tx)) + ".", _csm())] if tx.size() else [], ch, [["Giúp nhà này", true, true, func(): WD.tn_help(u)]])]

func _thue(e: Dictionary) -> Array:   # _vT.thue
	var L := [_sec("Thuê làm phụ", "Trả công mỗi phút. Càng thân thiết công càng rẻ. Hết tiền thì họ nghỉ. Xem hết mọi người ở Sổ làng › Người làm thuê.")]
	var s: Array = W.lm()
	var hh := maxi(1, int(ceil(W._gg().size() / 12.0)))
	var p: bool = e.get("job") == "ruong" or s.size() < hh
	var bt := []
	bt.append({"b": "Nghỉ ở nhà", "s": "Không tốn công", "st": "on" if not W._tr(e.get("job")) else "off", "act": func(): W.n4(u, "")})
	bt.append({"b": "Làm ruộng", "s": str(W.om(e, "ruong")) + " xu/phút" if p else "Đủ người rồi", "st": "on" if e.get("job") == "ruong" else ("off" if p else "dis"), "act": func(): W.n4(u, "ruong")})
	for M in ["vuon", "chan"]:
		var t: String = W.vg(M)
		var w: bool = e.get("job") == M
		var E := t != "" and not w
		var C: bool = W.yx(M)
		bt.append({"b": "Làm vườn" if M == "vuon" else "Chăm chuồng", "s": t + " đang làm" if E else (str(W.om(e, M)) + " xu/phút" if C else ("Chưa có cây" if M == "vuon" else "Chưa có con")),
			"st": "on" if w else ("dis" if E or (not C and not w) else "off"), "act": func(): W.n4(u, M)})
	var o: Array = G.xw.N0.filter(func(k): return G.xw.built(k))
	for M in o:
		var t: String = W.vg(M)
		var w: bool = e.get("job") == M
		var E := t != "" and not w
		bt.append({"b": String(W.CO.get(M, M)), "s": t + " đang làm" if E else str(W.om(e, M)) + " xu/phút", "st": "on" if w else ("dis" if E else "off"), "act": func(): W.n4(u, M)})
	L.append(_grid(bt, 2, "jobs"))
	if o.is_empty():
		L.append(_note([_r("Xây xưởng (Xây dựng › Xưởng) rồi thuê người làm, xưởng sẽ tự thu hàng và làm tiếp món bạn chọn.", _np())]))
	if e.get("job") == "ruong":
		L.append(_sec("Gieo cây gì?", "Ô gặt xong hay ô trống đều gieo giống này. Chọn Giữ giống cũ thì ô nào gieo lại cây đang trồng ở ô đó."))
		var pk := []
		for M in W.xq(e):
			var P: PackedStringArray = String(M.t).split(" · ")
			var id: String = M.id
			pk.append({"b": P[0], "s": " · ".join(P.slice(1)), "st": "on" if String(e.get("crop", "")) == id else "off", "act": func(): W.jq(u, id)})
		L.append(_grid(pk, 3, "pick"))
	if W._tr(e.get("job")) and e.job != "ruong" and G.xw.sr.has(e.job):
		var d: Dictionary = G.xw.sr[e.job]
		L.append(_sec("Làm món gì?", "Hết nguyên liệu thì đợi, có hàng xong thì tự cất vào kho."))
		var rk := []
		for M in d.rec:
			var id := String(M)
			rk.append({"b": String(W._ae(id).get("name", id)), "s": "" if G.xw.has_in(id) else "thiếu đồ", "st": "on" if e.get("jr") == id else "off", "act": func(): W.set_jr(u, id)})
		L.append(_grid(rk, 3, "pick"))
	return L

func _giong(a: Dictionary) -> Array:   # jR: giống nhà hàng xóm để dư
	var L := [_sec("Giống nhà " + String(a.n) + " để dư", "Mua lại giống của hàng xóm. Mỗi ngày mỗi thứ chỉ có chừng 6 hạt.")]
	var ul := _cl(T.giong.kids[1])
	var tpl: Dictionary = ul.kids[0]
	var y := float(ul.r[1])
	var out := []
	for e in WC.bZ(u):
		var id := String(e)
		var r := "h" + str(u) + "_" + id
		var o: int = WC.G6(r, 6)
		var l: int = WC.F6(id)
		var c := _cl(tpl)
		_mv(c, float(c.r[0]), y)
		var K: Array = c.kids
		_ic(K[0], id)
		var tx: Dictionary = K[1]
		var nb: Dictionary = tx.kids[0]
		var ns: Dictionary = tx.kids[1]
		nb.text = "Giống " + String(G.crop(id).name).to_lower()
		nb.r[2] = _tw(nb, nb.text)
		nb.tr = [nb.r[0], nb.tr[1], nb.r[2], nb.tr[3]]
		var hs := _put(ns, [_r(W._sa(l) + " xu một hạt · còn " + str(o) + " hạt · kho có " + str(W._barn(id)), ns)])
		ns.r[3] = hs
		var ok1: bool = o > 0 and W._n(G.g.coins) >= l
		var b1: Dictionary = K[2]
		var b3: Dictionary = K[3]
		var k1 := r + "|" + id + "|1|" + str(l) + "|6"
		var k3 := r + "|" + id + "|3|" + str(l) + "|6"
		var bl := [_act(b1 if ok1 else _plain(b1, b3), func(): WC.Um(k1), ok1)]
		if o >= 3:
			bl.append(_act(b3, func(): WC.Um(k3), W._n(G.g.coins) >= l * 3))
		c.kids = [K[0], tx] + bl
		out.append(c)
		y += float(c.r[3]) + 6.0
	ul.kids = out
	ul.r[3] = y - 6.0 - float(ul.r[1])
	L.append(ul)
	return L

func _plain(b1: Dictionary, b3: Dictionary) -> Dictionary:   # nút Mua 1 khi không mua được: kiểu nút thường
	var c := _cl(b3)
	c.r = b1.r.duplicate()
	c.tr = b1.tr.duplicate()
	c.text = b1.text
	return c

func _tal(f: Dictionary) -> Array:   # tinhHtml + TALH + SU
	var L := [_sec("Tính nết")]
	var TT: Dictionary = W.tinh_of(f)
	var Li: Dictionary = W.fam_likes(u)
	var k: Dictionary = f.get("bk") if f.get("bk") is Dictionary else {}
	var nm := func(id, kn) -> String: return String(W._ae(id).get("name", "")) if W._tr(kn) else "???"
	var card := _cl(T.tal.kids[1])
	var cl := _find(card, "vlcl")
	var sm: Dictionary = _tag_kids(cl, "small")[0]
	var sb: Dictionary = sm.kids[0]
	var rows := [[_r(String(TT.n) + ".", sb), _r(" " + String(TT.d), sm)],
		[_r("Thích: ", sm), _r(nm.call(Li.th[0], k.get("a")), sb), _r(", ", sm), _r(nm.call(Li.th[1], k.get("b")), sb), _r(" · Ghét: ", sm), _r(nm.call(Li.gh, k.get("x")), sb)],
		[_r("Ngày riêng: ", sm), _r("ngày " + str(Li.ngay) + " mỗi mùa (" + String(Li.ly) + ")" if W._tr(k.get("d")) else "???", sb)],
		[_r("Trò chuyện, tặng quà để biết thêm.", sm)]]
	var y := float(cl.r[1])
	var kids := []
	for rw in rows:
		var c := _cl(sm)
		_mv(c, float(cl.r[0]), y)
		var h := _put(c, rw)
		c.r[3] = h
		kids.append(c)
		y += h + 3.0
	cl.kids = kids
	cl.r[3] = y - 3.0 - float(cl.r[1])
	card.r[3] = y - 3.0 + 7.5 - float(card.r[1])
	L.append(card)
	L.append(_talbox(f))
	L.append_array(_su(f))
	return L

func _talbox(n: Dictionary) -> Dictionary:   # TALH: sở trường làm thuê
	var r := String(W.x9(u, n))
	var o: int = W._i(n.ts)
	var l: Dictionary = W.W3[r]
	var bx := _cl(T.x_su.kids[2])
	var th := _find(bx, "talh")
	var ic := _find(th, "talic")
	ic.text = String(l.ic)
	var dv: Dictionary = th.kids[1]
	var hb: Dictionary = dv.kids[0]
	var st: Dictionary = hb.kids[0]
	var hs: Dictionary = dv.kids[1]
	var t1 := "Sở trường: " + String(l.n) + " "
	var w1 := _tw(hb, t1)
	hb.text = t1
	hb.tr = [hb.tr[0], hb.tr[1], w1, hb.tr[3]]
	st.text = W.n_y(o)
	_mv(st, float(hb.r[0]) + w1, float(st.r[1]))
	var h := _put(hs, [_r(W.v_i(r, o) + (" · đang đúng nghề" if W.k9(n) else ""), hs)])
	hs.r[3] = h
	var tr := _find(bx, "talrow")
	var tsm: Dictionary = tr.kids[0]
	var tb: Dictionary = tr.kids[1]
	var y := float(tr.r[1])
	if W._tr(n.get("tt")):
		var c := maxf(0.0, (W._n(n.tt) - G._now_ms()) / 1000.0)
		_row(tr, tsm, tb, "Đang đi học nghề lên " + str(o + 1) + "★, còn " + G.ao(c), "Về ngay", true, func(): W.e_y(u))
	elif o < 5:
		var fz: int = W.m_i(o)
		var s: bool = W._i(n.get("tim")) < o
		var tbb: Dictionary = tb if not s else _cl(_find(T.tal.kids[2], "btn"))
		_row(tr, tsm, tbb, "Lên " + str(o + 1) + "★: " + W.v_i(r, o + 1).split(": ", true, 1)[-1] + ". Cần thân " + str(o) + " ♥, " + W._sa(fz) + " xu, học " + G.ao(W.n_l(o)) + ".",
			"🔒 Cần " + str(o) + " ♥" if s else "Gửi đi học nghề", not s, func(): W.b_i(u))
	else:
		tsm.text = "Đã thành thợ cả 5★"
		tsm.r[3] = _lh(tsm)
		tsm.tr = [tsm.r[0], tsm.r[1], _tw(tsm, tsm.text), tsm.r[3]]
		tr.kids = [tsm]
		tr.r[3] = tsm.r[3]
	bx.r[3] = float(tr.r[1]) + float(tr.r[3]) + 9.0 - float(bx.r[1])
	return bx

func _row(tr: Dictionary, sm: Dictionary, b: Dictionary, s: String, lb: String, ok: bool, act: Callable) -> void:   # .talrow: chữ + nút bên phải
	var c := _cl(b)
	var tw := _tw(c, lb)
	var bw := tw + _px(c, "padding-left") + _px(c, "padding-right")
	var x1 := float(tr.r[0]) + float(tr.r[2])
	var sw := float(tr.r[2]) - bw - 6.0
	sm.r[2] = sw
	var h := _put(sm, [_r(s, sm)], "left", sw)
	sm.r[3] = h
	var rh := maxf(30.0, h)
	_mv(sm, float(tr.r[0]), float(tr.r[1]) + (rh - h) * 0.5)
	_mv(c, x1 - bw, float(tr.r[1]) + (rh - 30.0) * 0.5)
	c.r[2] = bw
	c.text = lb
	c.tr = [x1 - bw + (bw - tw) * 0.5, float(c.r[1]) + (30.0 - float(c.tr[3])) * 0.5, tw, c.tr[3]]
	_act(c, act, ok)
	tr.kids = [sm, c]
	tr.r[3] = rh

func _su(f: Dictionary) -> Array:   # SU: nghề gia truyền nhà này
	var x: Dictionary = W.a_r(u)
	var H: Dictionary = W.hn_s()
	var p = W.hn_of(u)
	var T0 := "Nghề gia truyền: " + String(x.n)
	var now: float = G._now_ms()
	var cs := _csm()
	var go0 := func(): W.mk(u)
	var gosk := func(): W.mk(u, "skip")
	if W.t6().has(x.id):
		return [_note([_r("Bạn đã học nghề " + String(x.n).to_lower() + ". Mở bảng Nghề (nhóm Làm ăn) để làm.", _np())])]
	if W._i(f.get("tim")) < 3:
		return [_note([_r("Nhà " + String(f.n) + " có nghề ", _np()), _r(String(x.n).to_lower(), _nb()), _r(" gia truyền. Thân 3 ♥ thì họ mới nhận dạy.", _np())])]
	if not W._tr(p):
		var nd: Array = W.hn_in1(u, f)
		var ot = W.nghe_by_id(H.a) if W._tr(H.get("a")) and H.a != x.id else null
		var hc: int = W.ng_hoc_cho()
		return [_sec(T0), _card([_r("Bước 1/4 · Xin theo học. " + String(x.d) + " Đem đồ qua xin " + String(f.n) + " nhận dạy. Học xong trả " + W._sa(W.hn_hp(x)) + " xu tiền học." +
			(" Đang theo học " + String(ot.n).to_lower() + ", xin học nghề này thì tạm gác nghề kia, tiến độ vẫn giữ." if ot != null else "") +
			(" Mới học xong nghề trước, " + str(hc) + " ngày nữa mới theo học nghề mới được." if hc else ""), cs)], nd, [["Xin theo học", true, W.hn_have(nd) and not hc, go0]])]
	if H.get("a") != x.id:
		return [_sec(T0), _card([_r("Đang gác lại ở bước " + str(p.st) + "/4. Quay lại học thì tạm gác nghề đang theo, tiến độ vẫn giữ.", cs)], [], [["Học tiếp", true, true, go0]])]
	if int(p.st) == 2:
		var need: int = W.hn_days(f)
		return [_sec(T0), _card([_r("Bước 2/4 · Ngồi coi làm. Trò chuyện với " + String(f.n) + " mỗi ngày một buổi để coi thầy làm (" + str(W._i(p.get("n"))) + "/" + str(need) + " buổi)." +
			(" Bữa nay chỉ rồi, mai ghé tiếp." if W._i(p.get("dl", -1)) == W._vr() else ""), cs)], [], [])]
	if int(p.st) == 3 and not W._tr(p.get("te")):
		var i3: Array = W.hn_in3(x)
		return [_sec(T0), _card([_r("Bước 3/4 · Làm thử. Đưa nguyên liệu 2 mẻ, " + str(x.tt) + " phút sau coi kết quả. Tỉ lệ hư " + str(W._rnd(W.hn_miss() * 100.0)) + "%" +
			(" (càng biết nhiều nghề càng khó học thêm)" if W.hn_learned() else "") + "." + (" Đã hư " + str(p.fl) + " lần." if W._tr(p.get("fl")) else ""), cs)], i3, [["Làm thử", true, W.hn_have(i3), go0]])]
	if int(p.st) == 3 and W._n(p.te) > now:
		var l: float = (W._n(p.te) - now) / 1000.0
		return [_sec(T0), _card([_r("Bước 3/4 · Đang làm thử, còn " + G.ao(l) + ".", cs)], [], [["Xong ngay", true, true, gosk]])]
	if int(p.st) == 3:
		return [_sec(T0), _card([_r("Bước 3/4 · Làm thử xong rồi, coi coi được hông.", cs)], [], [["Coi kết quả", true, true, go0]])]
	var hp: int = W.hn_hp(x)
	var le: Array = W.hn_le(u, f)
	var Li: Dictionary = W.fam_likes(u)
	var kw: Dictionary = f.get("bk") if f.get("bk") is Dictionary else {}
	var s: String = "Bước 4/4 · Ra mắt thầy. Đem món làm thử, " + W._sa(hp) + " xu tiền học và lễ là " + ("đủ 2 món" if f.get("tp") == "sd" else "1 món") + " " + String(f.n) + " thích."
	if f.get("tp") != "sd":
		le = Li.th.map(func(id): return [id, maxi(1, W._rnd(60.0 / W._sell(id)))])
	var ch := []
	for j in le.size():
		if W._tr(kw.get("b" if j else "a")):
			ch.append(le[j])
	if not (W._tr(kw.get("a")) and W._tr(kw.get("b"))):
		s += " Chưa biết nhà này thích gì thì trò chuyện, tặng quà để dò."
	return [_sec(T0), _card([_r(s, cs)], ch, [["Ra mắt thầy · " + W._sa(hp) + " xu", true, W._n(G.g.coins) >= hp and W.hn_le_ok(u, f), go0]])]

# ------------------------------------------------------------------ trò chuyện, tặng quà
func _chat() -> Array:   # chatHtml
	var f = W._fam_of(u)
	if cv == null or f == null:
		sub = ""
		return _body(f)
	var t: Dictionary = T.x_chat
	var vc := _cl(t.kids[0])
	var npc: Dictionary = vc.kids[0]
	var me: Dictionary = vc.kids[1]
	var ms: Dictionary = vc.kids[2]
	var y := float(vc.r[1])
	var x0 := float(vc.r[0])
	var W0 := float(vc.r[2])
	var mx := 262.3
	var out := []
	for ln in cv.lines:
		var k: String = ln[0]
		var s: String = ln[1]
		var c: Dictionary
		if k == "s":
			c = _cl(ms)
			var w := _dw(c, s)
			c.r = [x0 + (W0 - w) * 0.5, y, w, c.r[3]]
			c.tr = [x0 + (W0 - w) * 0.5, y, w, c.r[3]]
			c.text = s
		else:
			c = _cl(npc if k == "n" else me)
			var pl := _px(c, "padding-left")
			var pr := _px(c, "padding-right")
			var pt := _px(c, "padding-top")
			var nmh := 0.0
			var kids := []
			var tw := _dw(c, s)
			if k == "n":
				var sm: Dictionary = c.kids[0]
				sm.text = String(f.n)
				var nw := _dw(sm, sm.text)
				sm.r[2] = nw
				sm.tr = [sm.tr[0], sm.tr[1], nw, sm.tr[3]]
				tw = maxf(tw, nw)
				nmh = float(sm.r[1]) - float(c.r[1]) + float(sm.r[3]) - pt + 1.5
				kids.append(sm)
			var iw := minf(tw + 1.0, mx - pl - pr)
			var bw := iw + pl + pr
			var bx := x0 if k == "n" else x0 + W0 - bw
			_mv(c, bx, y)
			c.r[2] = bw
			var fl := _flow([_r(s, c)], bx + pl, y + pt + nmh, iw, _lh(c))
			if k == "n":
				kids[0] = _mv(kids[0], bx + pl, y + pt)
			c.kids = kids + fl.kids
			c.erase("text")
			c.erase("tr")
			c.r[3] = pt + nmh + fl.h + _px(c, "padding-bottom")
		out.append(c)
		y += float(c.r[3]) + 6.0
	vc.kids = out
	vc.r[3] = y - 6.0 - float(vc.r[1])
	var ops := _ops(cv.opts.map(func(o): return [o.t, o.get("k") == "nhan"]))
	return [vc, _gap(ops, 3.0)]

func _pick(i: int) -> void:   # data-cv
	if cv == null:
		return
	var done: bool = W.chat_pick(cv, i)
	if done:
		cv = null
		sub = ""
		tab = "viec"

func _ops(opts: Array) -> Dictionary:   # .vlops: nút trả lời [chữ, primary]
	var t: Dictionary = T.x_chat
	var n := _cl(t.kids[1])
	var tp: Dictionary = n.kids[0]
	var tn: Dictionary = n.kids[1]
	var y := float(n.r[1])
	var out := []
	for i in opts.size():
		var c := _cl(tp if opts[i][1] else tn)
		_mv(c, float(n.r[0]), y)
		var h := _put(c, [_r(String(opts[i][0]), c)])
		c.r[3] = maxf(30.0, _px(c, "padding-top") + h + _px(c, "padding-bottom"))
		c.act = _pick.bind(i)
		out.append(c)
		y += float(c.r[3]) + 4.5
	n.kids = out
	n.r[3] = y - 4.5 - float(n.r[1])
	return n

func _gift() -> Array:   # giftHtml
	var f = W._fam_of(u)
	var k: Dictionary = f.get("bk") if f.get("bk") is Dictionary else {}
	var x2: bool = W.is_ngay_rieng(u)
	var L := [_sec("Tặng " + String(f.n) + " 1 món", "Món thích được thân nhiều, món ghét bị trừ." + (" Hôm nay ngày riêng nhà này: quý gấp đôi." if x2 and W._tr(k.get("d")) else ""))]
	var ids: Array = W.gift_ids(u)
	var g := _cl(T.x_gift.kids[1])
	var tth: Dictionary = g.kids[0]
	var tno: Dictionary = g.kids[1]
	var tgh: Dictionary = g.kids[3]
	if ids.is_empty():
		L.append(_note([_r("Kho chưa có món gì để tặng.", _np())]))
	else:
		var out := []
		var bw := 98.7
		for i in ids.size():
			var id: String = ids[i][0]
			var tg: int = ids[i][1]
			var c := _cl(tth if tg > 0 else (tgh if tg < 0 else tno))
			_mv(c, float(g.r[0]) + (i % 3) * (bw + 4.5), float(g.r[1]) + floorf(i / 3.0) * (56.3 + 4.5))
			var K: Array = c.kids
			_ic(K[0], id)
			var nb: Dictionary = K[1]
			var ns: Dictionary = K[2]
			var cx := float(c.r[0]) + bw * 0.5
			for pr in [[nb, String(W._ae(id).name)], [ns, "♥ Thích" if tg > 0 else ("Ghét" if tg < 0 else "Có " + str(W._barn(id)))]]:
				var nn: Dictionary = pr[0]
				var w := minf(_tw(nn, pr[1]), bw - 4.0)
				nn.r = [cx - w * 0.5, nn.r[1], w, nn.r[3]]
				nn.tr = [cx - w * 0.5, nn.tr[1], w, nn.tr[3]]
				nn.text = pr[1]
			c.act = _give.bind(id)
			out.append(c)
		g.kids = out
		var rows := int(ceil(ids.size() / 3.0))
		g.r[3] = rows * 56.3 + (rows - 1) * 4.5
		L.append(g)
	var back := _cl(T.x_gift.kids[2])
	back.kids[0].act = _back
	L.append(_gap(back, 3.0))
	return L

func _tab_go(k: String) -> void:   # data-vt
	if tab != k:
		tab = k
		scroll = 0.0

func _give(id: String) -> void:   # data-gv
	W.gift_give(u, id)
	sub = ""

func _back() -> void:   # data-back
	sub = ""
	cv = null

# ------------------------------------------------------------------ nhà có sẵn trên làng: chip "Dọn vào ở" (nửa giá shop)
var chip: Control = null
var chip_o = null           # vật cảnh có sẵn (lang.SO)

func _cost(o: Dictionary) -> int:
	return int(floor(float(G.lang.Pi[o.id].get("cost", 0)) / 2.0))

func chip_open(o: Dictionary) -> void:
	chip_close()
	close()
	chip_o = o
	var n := _cl(Snap.find(Snap.load_snap("kho")["#pov"][0], "khchip"))   # dáng chip lọc của kho, tô đỏ cho nổi trên cỏ
	n.erase("::before")
	n.css["background-image"] = "linear-gradient(rgb(239, 106, 82) 0%, rgb(226, 69, 58) 50%, rgb(201, 53, 44) 100%)"
	n.css["box-shadow"] = "rgb(158, 42, 32) 0px 0px 0px 1px inset, rgba(255, 200, 190, 0.55) 0px 2px 0px 0px inset, rgba(90, 20, 0, 0.35) 0px 1px 2px 0px"
	var sp: Dictionary = n.kids[0]
	sp.css["color"] = "rgb(255, 255, 255)"
	sp.css["text-shadow"] = "rgba(120, 20, 10, 0.5) 0px 1px 0px"

	var t: String = "Dọn vào ở · " + G.fmt_n(_cost(o))
	var z := _z(n)
	var pl := _px(n, "padding-left")
	var tw := _tw(sp, t)
	var cw := 11.25
	var w := pl + tw + 4.0 + cw + pl
	var h := float(n.r[3])
	n.r = [0.0, 0.0, w, h]
	sp.r = [pl, (h - float(sp.r[3])) * 0.5, tw, sp.r[3]]
	sp.tr = [pl, (h - float(sp.tr[3])) * 0.5, tw, sp.tr[3]]
	sp.text = t
	var img := {"z": z, "tag": "img", "id": "", "cls": "xui", "src": "|xui", "r": [pl + tw + 4.0, (h - cw) * 0.5, cw, cw], "css": {"display": "inline-block", "position": "static"}}
	n.kids = [sp, img]
	var ids2 := {}
	chip = U._build(n, ids2)
	U.root.add_child(chip)
	U._click(chip, _chip_go, "scale94")
	chip_step()

func chip_close() -> void:
	if chip != null:
		chip.queue_free()
		chip = null
	chip_o = null

func chip_step() -> void:   # chip đứng trên nóc nhà, theo camera
	if chip == null:
		return
	var o: Dictionary = chip_o
	if not G.lang.so_shown(o):
		chip_close()
		return
	var m = U.main
	var ra: Vector2 = (Vector2(float(o.sx), float(o.sy)) - m.cam) * m.zoom / Css.K
	var top := float(o.bb[1]) - float(o.sy)
	var w: float = chip.r.size.x
	var h: float = chip.r.size.y
	var x := clampf(ra.x - w * 0.5, 8.0, U.vw - w - 8.0)
	var y := clampf(ra.y + (top - 6.0) * U.cz() - h, 8.0, U.vh - h - 8.0)
	U._move(chip, Vector2(round(x), round(y)))

func _chip_go() -> void:   # trả nửa giá shop: nhà có sẵn thành nhà ở (Hz), sinh gia đình, mở bảng nhà
	var o: Dictionary = chip_o
	var c := _cost(o)
	if W._n(G.g.coins) < c:
		G.toast.emit("Cần " + G.fmt_n(c) + " xu để dọn vào ở.")
		return
	var n: int = G.lang.take_so(o)
	if n < 0:
		return
	G.g.coins = W._n(G.g.coins) - c
	U.F._xw_sig = ""
	U.F._xw_sync()
	chip_close()
	W.uf()
	var r: Dictionary = G.lang.objs()[n]
	var f = W._fam_of(W._i(r.get("u")))
	if f != null:
		G.toast.emit("Nhà " + String(f.n) + " dọn vào ở rồi.")
	G.mark()
	U.vl_open(W._i(r.get("u")))

