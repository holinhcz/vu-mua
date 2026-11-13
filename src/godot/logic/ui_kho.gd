extends RefCounted
# KHO bản web: nút sức chứa .khst trong bảng Kho (số món/sức chứa, sao), hộp "Nâng sao kho" (m$, Re.pop u2gold),
# hộp "Kho đầy rồi!" (lL .kfov, thêm nút nâng kho), hộp "Nâng sớm" bằng sen đỏ (zF .nglkov).
# Số đo lấy từ chính bản web, mỗi trạng thái một bản chụp:
#   kup_ok (2★ đủ cấp, đủ đồ), k2_no (2★ đủ cấp, thiếu), kup_lock (2★ chưa đủ cấp, nâng sớm được),
#   k3_ok / k3_no / kup_no (từ 3★: 4 ô giá), k_hard (thiếu quá 8 cấp: 🔒), kup_max (10★)
#   kfov (có nút Nâng kho), kfov3 (💎 Nâng kho sớm), kfov2 (không nút nâng), kns_ok / kns_poor (nâng sớm).

const Snap = preload("res://ui/snap.gd")
const Box = preload("res://ui/box.gd")
const Css = preload("res://ui/css.gd")

var U
var G
var T := {}
var pop: Control = null      # hộp Nâng sao kho
var pop_sig := ""
var kf: Control = null       # hộp Kho đầy
var ns: Control = null       # hộp Nâng sớm
var mat_svg := {}            # then/bao/ton -> svg (chụp từ ô giá của web)
var star_on := ""
var star_off := ""
var chip_css := {}           # "ok"/"no" (vật liệu), "xok"/"xno" (xu): css ô + css chữ b
var bar_col := {"": "rgb(255, 204, 51)", "warn": "rgb(246, 111, 39)", "full": "rgb(240, 62, 50)"}

func _init(ui) -> void:
	U = ui
	G = ui.G
	for k in ["kup_lock", "kup_ok", "kup_no", "kup_max", "k3_ok", "k3_no", "k2_no", "k_hard"]:
		T[k] = Snap.load_snap(k)[".u2pop"][0]
	for k in ["kfov", "kfov2", "kfov3"]:
		var n: Dictionary = Snap.load_snap(k)[".kfov"][0].duplicate(true)
		_unscale(n, "kfbox")
		T[k] = n
	T.kns_ok = Snap.load_snap("kns_ok")[".nglkov"][0]
	# kns_poor chụp lúc hộp đang hiện dần (mờ, thu 0,4): lấy chỗ đứng của kns_ok, chỉ lấy kiểu nút "poor"
	T.poor_btn = Snap.find(Snap.load_snap("kns_poor")[".nglkov"][0], "ngbuy")
	# hình vật liệu: ô giá thứ 2..4 của k3_ok là then, bao, ton
	var ch: Array = Snap.find(T.k3_ok, "need").kids
	var ids := ["then", "bao", "ton"]
	for j in 3:
		mat_svg[ids[j]] = Snap.find(ch[j + 1], "", "svg").get("svg", "")
	var st: Array = Snap.find(T.kup_max, "stars").kids
	star_on = st[0].svg
	star_off = Snap.find(T.kup_lock, "stars").kids[9].svg
	var lk: Array = Snap.find(T.kup_lock, "need").kids
	chip_css.ok = lk[1]
	chip_css.no = lk[2]
	chip_css.xok = lk[0]
	chip_css.xno = Snap.find(T.k3_no, "need").kids[0]

func _unscale(n: Dictionary, cls: String) -> void:
	# hộp chụp lúc đang phóng to (animation): đưa về cỡ thật quanh tâm
	var bx := Snap.find(n, cls)
	var m := RegEx.create_from_string("matrix\\(([0-9.]+)").search(String(bx.css.get("transform", "")))
	if m != null:
		var k := float(m.get_string(1))
		var c := Vector2(float(bx.r[0]) + float(bx.r[2]) * 0.5, float(bx.r[1]) + float(bx.r[3]) * 0.5)
		U._od_unscale(bx, c, k)
		bx.css["transform"] = "none"

# ------------------------------------------------------------------ chữ lẫn hình (chữ, <i> hình, chữ)
static func _plain_css(c: Dictionary) -> Dictionary:
	var o := c.duplicate()
	o["background-color"] = "rgba(0, 0, 0, 0)"
	o["background-image"] = "none"
	o["box-shadow"] = "none"
	o["border-radius"] = "0px"
	for s in ["top", "right", "bottom", "left"]:
		o["border-" + s] = "0px none rgb(0, 0, 0)"
		o["padding-" + s] = "0px"
	o["filter"] = "none"
	o["position"] = "static"
	o["display"] = "inline"
	return o

func _mix(n: Dictionary, old_l: String, new_l: String, new_r: String, cx: float) -> void:
	# n: chữ = trái + phải, kid[0] = hình ở giữa. Đo khoảng hở hai bên hình từ bản chụp, xếp lại giữa cx.
	var ic: Dictionary = n.kids[0]
	var tr: Array = n.get("tr", n.r)
	var old_r: String = String(n.text).substr(old_l.length())
	var gl: float = float(ic.r[0]) - float(tr[0]) - U._tw(n, old_l)
	var gr: float = float(tr[0]) + float(tr[2]) - float(ic.r[0]) - float(ic.r[2]) - (U._tw(n, old_r) if old_r != "" else 0.0)
	if old_r == "":
		gr = gl
	var wl: float = U._tw(n, new_l)
	var wr: float = U._tw(n, new_r) if new_r != "" else 0.0
	var iw: float = float(ic.r[2])
	var tot: float = wl + gl + iw + (gr + wr if new_r != "" else 0.0)
	var x := cx - tot * 0.5
	n.text = new_l
	n.tr = [x, float(tr[1]), wl + 0.5, float(tr[3])]
	Snap._move(ic, Vector2(x + wl + gl - float(ic.r[0]), 0))
	var kids := [ic]
	if new_r != "":
		var sp := {"tag": "span", "id": "", "cls": "", "z": n.get("z", 1.0), "css": _plain_css(n.css), "kids": [],
			"text": new_r, "r": [x + wl + gl + iw + gr, float(tr[1]), wr + 0.5, float(tr[3])]}
		sp.tr = sp.r.duplicate()
		kids.append(sp)
	n.kids = kids

static func _kid(n: Dictionary, tag: String) -> Dictionary:
	for k in n.get("kids", []):
		if k.tag == tag:
			return k
	return {}

func _ctext(n: Dictionary, s: String) -> void:
	var cx: float = float(n.r[0]) + float(n.r[2]) * 0.5
	U._set_t(n, s, cx - U._tw(n, s) * 0.5)

func _chip(c: Dictionary, kind: String, ok: bool, have: int, need: int, svg: String) -> Dictionary:
	# Q4/pJ: ô xu "[xu] 1.500", ô vật liệu "[hình] có/cần" (có đỏ khi thiếu)
	var src: Dictionary = chip_css[("x" if kind == "xu" else "") + ("ok" if ok else "no")]
	var o: Dictionary = c.duplicate(true)
	o.cls = src.cls
	o.css = src.css
	var sb := Snap.find(src, "", "b")
	var b := Snap.find(o, "", "b")
	b.css = sb.css
	if kind == "xu":
		var s: String = G.fmt_n(need)
		var x0: float = float(b.r[0])
		b.text = s
		b.r = [x0, b.r[1], U._tw(b, s) + 0.5, b.r[3]]
		b.tr = [x0, b.get("tr", b.r)[1], U._tw(b, s) + 0.5, b.get("tr", b.r)[3]]
		# hình + số giữa ô
		var im: Dictionary = o.kids[0]
		var w: float = float(im.r[2]) + (x0 - float(im.r[0]) - float(im.r[2])) + float(b.r[2])
		var cx: float = float(o.r[0]) + float(o.r[2]) * 0.5
		var d: float = cx - w * 0.5 - float(im.r[0])
		Snap._move(im, Vector2(d, 0))
		Snap._move(_kid(o, "span"), Vector2(d, 0))
		return o
	var sv := Snap.find(o, "", "svg")
	sv.svg = svg
	var sp: Dictionary = _kid(o, "span")
	var bs := str(mini(have, need))
	var rs := "/" + str(need)
	var wb: float = U._tw(b, bs)
	var wr: float = U._tw(sp, rs)
	# [hình][gap][b][/cần] giữa ô
	var gap: float = float(sp.r[0]) - float(sv.r[0]) - float(sv.r[2])
	var w2: float = float(sv.r[2]) + gap + wb + wr
	var x: float = float(o.r[0]) + float(o.r[2]) * 0.5 - w2 * 0.5
	Snap._move(sv, Vector2(x - float(sv.r[0]), 0))
	var bx: float = x + float(sv.r[2]) + gap
	b.text = bs
	b.r = [bx, b.r[1], wb + 0.5, b.r[3]]
	b.tr = b.r.duplicate()
	sp.text = rs
	sp.r = [bx, sp.r[1], wb + wr + 0.5, sp.r[3]]
	sp.tr = [bx + wb, sp.get("tr", sp.r)[1], wr + 0.5, sp.get("tr", sp.r)[3]]
	return o

# ------------------------------------------------------------------ nút sức chứa trong bảng Kho
func sync_panel(ids: Dictionary, n: int, cap: int) -> void:
	var l := mini(100, int(round(float(n) / maxf(1.0, cap) * 100.0)))
	var c := "full" if n >= cap else ("warn" if l >= 85 else "")
	var bar = ids.get(".kcbar")
	if bar != null and bar.kids().size() > 0:
		var fi: Control = bar.kids()[0]
		fi.place(Rect2(fi.r.position, Vector2(bar.r.size.x * l / 100.0, fi.r.size.y)))
		var sn: Dictionary = fi.get_meta("snap", {})
		if not sn.is_empty() and fi.get_meta("kc", "?") != c:
			fi.set_meta("kc", c)
			var cs: Dictionary = sn.css.duplicate()
			cs["background-color"] = bar_col[c]
			fi.style(Snap.css_of({"css": cs}), fi.z)
			fi.place(fi.r)
	var st = ids.get(".khst")
	if st == null:
		return
	var cp: Control = U._q(st, "khcap")
	var sn2: Control = U._q(st, "khsn")
	var s1: String = G.fmt_n(n) + "/" + str(cap)
	var s2 := str(G.kho_star())
	if st.get_meta("ks", "") == s1 + "|" + s2:
		return
	st.set_meta("ks", s1 + "|" + s2)
	# nút canh phải (flex): chữ dài/ngắn hơn thì nút nở sang trái, các phần sau chữ đó dời theo
	var d_cap := 0.0
	var d_sn := 0.0
	if cp != null and not cp.texts.is_empty():
		var t0: Dictionary = cp.texts[0]
		d_cap = Box.text_w(s1, t0.size, t0.w) - Box.text_w(t0.s, t0.size, t0.w)
		U._txt(cp, s1)
	if sn2 != null and not sn2.texts.is_empty():
		var t1: Dictionary = sn2.texts[0]
		d_sn = Box.text_w(s2, t1.size, t1.w) - Box.text_w(t1.s, t1.size, t1.w)
		U._txt(sn2, s2)
	var dw := d_cap + d_sn
	if absf(dw) < 0.01:
		return
	st.place(Rect2(st.r.position - Vector2(dw, 0), st.r.size + Vector2(dw, 0)))
	# trong nút: số/sức chứa nở, sao + số sao dời phải theo phần nở của số/sức chứa
	for k in st.kids():
		var kn: Dictionary = k.get_meta("snap", {})
		var kc := String(kn.get("cls", ""))
		if kc.find("khcap") >= 0:
			k.place(Rect2(k.r.position, k.r.size + Vector2(d_cap, 0)))
		elif kc.find("khsn") >= 0:
			k.place(Rect2(k.r.position + Vector2(d_cap, 0), k.r.size + Vector2(d_sn, 0)))
		else:
			k.place(Rect2(k.r.position + Vector2(d_cap, 0), k.r.size))

# lớp tối là một lớp riêng phủ kín màn thật (U._cover), hộp nằm giữa (như ui_set.help)
func _show(n: Dictionary, box_cls: String, ids: Dictionary, on_close: Callable) -> Control:
	var bx := Snap.find(n, box_cls)
	var bk: Dictionary = n.duplicate()
	bk.kids = []
	bk.css = bk.css.duplicate()
	bk.css["z-index"] = "auto"
	bk.css["position"] = "absolute"
	var keep := []
	for k in n.kids:
		if k == bx or not Snap.find(k, box_cls).is_empty():
			keep.append(k)
	for k in keep:
		k.css = k.css.duplicate()
		k.css["position"] = "relative"
	var top := {"tag": "div", "id": "", "cls": "", "z": n.get("z", 1.0), "css": {}, "r": n.r, "kids": [bk] + keep}
	var b: Control = U._build(top, ids)
	U.root.add_child(b)
	U.anchors.append([b, 0.5, 0.5])
	var first: Control = b.kids()[0] if b.kids().size() > 0 else null
	if first != null:
		U._stop(first)
		first.gui_input.connect(func(e): if U._is_tap_down(e): on_close.call())
	var bb = ids.get("." + box_cls)
	if bb != null:
		U._stop(bb)
	return b

# ------------------------------------------------------------------ hộp Nâng sao kho (m$)
func open() -> void:
	G.g.kbOpen = false
	pop_sig = ""
	_draw()

func close() -> void:
	if pop != null:
		U.anchors.erase(U._anchor_of(pop))
		pop.queue_free()
		pop = null

func _sig() -> String:
	return "|".join([G.kho_star(), int(G.g.coins / 50), G.mat_n("then"), G.mat_n("bao"), G.mat_n("ton"), G.lv(), int(G.g.get("ngoc", 0)), int(G.g.get("khoB", 0))])

func step() -> void:
	if pop != null and ns == null and _sig() != pop_sig:
		_draw()

func _draw() -> void:
	pop_sig = _sig()
	var a: int = G.kho_star()
	var n: Dictionary
	var nd := {}
	var lock := false
	var can := false
	var early := false
	if a >= 10:
		n = T.kup_max.duplicate(true)
	else:
		nd = G.kho_need(a + 1)
		lock = G.lv() < int(nd.lv)
		can = G.can_pay(nd)
		early = lock and G.early_ok(int(nd.lv))
		var big := a + 1 >= 3
		var key := ""
		if lock:
			key = ("kup_no" if big else "kup_lock") if early else "k_hard"
		else:
			key = ("k3_ok" if big else "kup_ok") if can else ("k3_no" if big else "k2_no")
		n = T[key].duplicate(true)
	var sv := Snap.find(n, "u2sv")
	var cx: float = float(sv.r[0]) + float(sv.r[2]) * 0.5
	var stars: Array = Snap.find(sv, "stars").kids
	for j in stars.size():
		stars[j].svg = star_on if j < a else star_off
	var sm: Array = []
	for k in sv.kids:
		if k.tag == "small":
			sm.append(k)
	_ctext(sm[0], "Đang chứa tối đa " + str(G.kho_cap()) + " món")
	if a < 10:
		var sn: Dictionary = sm[1]
		var tl := String(sn.text)
		var old_l := tl.substr(0, tl.find(":"))
		_mix(sn, old_l, "Lên " + str(a + 1), ": chứa " + str(G.KHO_VP[a + 1] + int(G.g.get("khoB", 0))) + " món", cx)
		var need := Snap.find(sv, "need")
		var ch: Array = need.kids
		var out := [_chip(ch[0], "xu", int(G.g.coins) >= int(nd.xu), int(G.g.coins), int(nd.xu), "")]
		for j in nd.m.size():
			var m: Array = nd.m[j]
			var hv: int = G.mat_n(m[0])
			out.append(_chip(ch[j + 1], m[0], hv >= int(m[1]), hv, int(m[1]), mat_svg.get(m[0], "")))
		need.kids = out
		if lock:
			var lk := Snap.find(sv, "u2lk")
			var s: String = "Cần cấp " + str(nd.lv) + " · Bạn cấp " + str(G.lv())
			if early:
				_mix(lk, String(lk.text), s + " · nâng sớm bằng", "", cx)
			else:
				_ctext(lk, s)
		var bt := Snap.find(sv, "", "button")
		if early:
			var bt_l := String(bt.text)
			var dot := bt_l.find("·")
			_mix(bt, bt_l.substr(0, dot + 1), "Nâng sớm ·", str(G.kho_early_cost(nd)), cx)
		elif lock:
			_ctext(bt, "🔒 Cấp " + str(nd.lv))
		else:
			_ctext(bt, "Nâng kho lên " + str(a + 1) + "★")
	var keep_open := pop != null
	close()
	var ids := {}
	pop = _show(n, "u2pc", ids, close)
	if a < 10:
		var bb: Control = U._q(pop, "btn")
		if bb != null and (lock == false or early):
			U._click(bb, up, "scale")
	U._layout()
	if not keep_open:
		G.vib(0)

func up() -> void:   # mp (bản web có lớp bọc: thiếu cấp thì mở hộp nâng sớm)
	var a: int = G.kho_star()
	if a >= 10:
		return
	var nd: Dictionary = G.kho_need(a + 1)
	if G.lv() < int(nd.lv):
		if G.early_ok(int(nd.lv)):
			ns_open()
		else:
			U.say("Cần cấp " + str(nd.lv) + ". Chỉ nâng sớm được khi thiếu tối đa " + str(G.KHO_SA) + " cấp.")
		return
	if not G.can_pay(nd):   # vá L1 cho mp: đủ cấp mà thiếu đồ -> "Nâng sao còn thiếu:" bù bằng sen đỏ
		var mats := []
		for m in nd.m:
			var d: int = int(m[1]) - G.mat_n(m[0])
			if d > 0:
				mats.append([m[0], d])
		U._lack_open([], "Nâng sao còn thiếu:", func():
			G.kho_up()
			pop_sig = ""
			if pop != null:
				_draw(), maxi(0, int(nd.xu) - int(G.g.coins)), mats)
		return
	G.kho_up()
	pop_sig = ""
	if pop != null:
		_draw()

# ------------------------------------------------------------------ hộp Nâng sớm (zF)
var ns_hid: Control = null    # hộp đang ẩn sau hộp Nâng sớm (web: vẽ lại khi xong)

func ns_close() -> void:
	if ns != null:
		U.anchors.erase(U._anchor_of(ns))
		ns.queue_free()
		ns = null
	if ns_hid != null and is_instance_valid(ns_hid):
		ns_hid.visible = true
	ns_hid = null

func ns_open() -> void:   # mp bọc: zF({t: "kho lên N★", nd, fee: V9(CA[N], lv), extra, go: mp})
	var a: int = G.kho_star()
	var nd: Dictionary = G.kho_need(a + 1)
	ns_show({"t": "kho lên " + str(a + 1) + "★", "nd": nd, "fee": G.KHO_CA[a + 1] * G.early_lv(int(nd.lv)),
		"extra": " Kho chứa được " + str(G.KHO_VP[a + 1] + int(G.g.get("khoB", 0))) + " món.",
		"go": G.kho_up, "hide": pop, "done": func():
			pop_sig = ""
			if pop != null:
				_draw()})

func ns_show(sp: Dictionary) -> void:   # zF
	ns_close()
	var nd: Dictionary = sp.nd
	var fee: int = int(sp.fee)
	var r: int = G.early_cost(nd, fee)
	var lack := []
	for m in nd.m:
		var d: int = int(m[1]) - G.mat_n(m[0])
		if d > 0:
			lack.append([m[0], d])
	var xe := maxi(0, int(nd.xu) - int(G.g.coins))
	var have := int(G.g.get("ngoc", 0))
	var rich := have >= r
	var n: Dictionary = T.kns_ok.duplicate(true)
	var bx := Snap.find(n, "nglk")
	if not rich:
		var nb := Snap.find(bx, "ngbuy")
		nb.cls = T.poor_btn.cls
		nb.css = T.poor_btn.css
		var pc: Dictionary = Snap.find(T.poor_btn, "ngcost")
		var oc := Snap.find(nb, "ngcost")
		oc.css = pc.css
		# chữ nút dài hơn: "Nạp thêm sen đỏ"
		var lbl := "Nạp thêm sen đỏ"
		var d: float = U._tw(nb, lbl) - U._tw(nb, String(nb.text))
		nb.text = lbl
		nb.r = [float(nb.r[0]) - d * 0.5, nb.r[1], float(nb.r[2]) + d, nb.r[3]]
		if nb.has("tr"):
			nb.tr = [float(nb.tr[0]) - d * 0.5, nb.tr[1], float(nb.tr[2]) + d, nb.tr[3]]
		Snap._move(oc, Vector2(d * 0.5, 0))
	var cx: float = float(bx.r[0]) + float(bx.r[2]) * 0.5
	var tb: Dictionary = {}
	var p: Dictionary = {}
	for k in bx.kids:
		if k.tag == "b" and tb.is_empty():
			tb = k
		if k.tag == "p":
			p = k
	_ctext(tb, "Nâng sớm: " + String(sp.t))
	var ps := "Bạn đang cấp " + str(G.lv()) + ", mức này cần cấp " + str(nd.lv) + "." + String(sp.get("extra", "")) + " Dùng sen đỏ để mở khóa ngay" + (", bù luôn phần còn thiếu" if not lack.is_empty() or xe > 0 else "") + ":"
	# đoạn chữ xuống dòng: dời phần dưới theo số dòng mới
	var lh := Css.px(p.css.get("line-height", "19px"))
	var fs: float = U._fsz(p)
	var fw := int(p.css.get("font-weight", "400"))
	var l0 := int(round(float(p.r[3]) / lh))
	var l1: int = U._nlines(ps, fs, fw, float(p.r[2]))
	p.text = ps
	p.erase("tr")
	var dy := (l1 - l0) * lh
	p.r = [p.r[0], p.r[1], p.r[2], float(p.r[3]) + dy]
	var below := false
	for k in bx.kids:
		if k == p:
			below = true
			continue
		if below:
			Snap._move(k, Vector2(0, dy))
	bx.r = [bx.r[0], float(bx.r[1]) - dy * 0.5, bx.r[2], float(bx.r[3]) + dy]
	for k in bx.kids:
		Snap._move(k, Vector2(0, -dy * 0.5))
	# ô: [cấp + "Mở khóa sớm E cấp · F sen đỏ"] [vật liệu thiếu ×n] [xu ×n], rộng 78 cách 8, giữa hộp
	var cs := Snap.find(bx, "nglcs")
	var c0: Dictionary = cs.kids[0]
	var cm: Dictionary = cs.kids[1]
	var cxu: Dictionary = cs.kids[2]
	var lv_b := Snap.find(c0, "nslv")
	_ctext(lv_b, str(nd.lv))
	var lsm := Snap.find(c0, "", "small")
	lsm.text = "Mở khóa sớm " + str(G.early_lv(int(nd.lv))) + " cấp · " + str(fee) + " sen đỏ"
	lsm.erase("tr")
	var L := [c0]
	for q in lack:
		var o: Dictionary = cm.duplicate(true)
		Snap.find(o, "", "svg").svg = mat_svg.get(q[0], "")
		_xn(Snap.find(o, "", "b"), "×" + str(q[1]))
		_ctext(Snap.find(o, "", "small"), G.item_name(q[0]))
		L.append(o)
	if xe > 0:
		var o2: Dictionary = cxu.duplicate(true)
		_xn(Snap.find(o2, "", "b"), "×" + G.fmt_n(xe))
		L.append(o2)
	# rộng 78 cách 8; không đủ chỗ trong hộp thì thu hẹp đều (flex)
	var inner: float = float(bx.r[2]) - 32.0
	var cw := minf(78.0, (inner - 8.0 * (L.size() - 1)) / L.size())
	var W := cw * L.size() + 8.0 * (L.size() - 1)
	var x := cx - W * 0.5
	var out := []
	for o in L:
		var q: Dictionary = Snap.moved(o, Vector2(x - float(o.r[0]) - (78.0 - cw) * 0.5, 0))
		var qc: float = x + cw * 0.5
		q.r = [x, q.r[1], cw, q.r[3]]
		for kk in q.kids:
			if kk.tag == "small":
				kk.r = [x + 2.0, kk.r[1], cw - 4.0, kk.r[3]]
				if kk.has("tr"):
					_ctext(kk, String(kk.text))
			elif kk.tag == "b" and kk.has("tr"):
				Snap._move(kk, Vector2(-(78.0 - cw) * 0.5, 0))
		out.append(q)
		x += cw + 8.0
	cs.kids = out
	# nút "Nâng ngay [sen r]" / "Nạp thêm sen đỏ [sen r]"
	var bt := Snap.find(bx, "ngbuy")
	var cost := Snap.find(bt, "ngcost")
	var cb: Dictionary = Snap.find(cost, "", "b")
	var dcw: float = U._tw(cb, str(r)) - float(cb.r[2])
	cb.text = str(r)
	cb.r = [cb.r[0], cb.r[1], float(cb.r[2]) + dcw, cb.r[3]]
	cb.tr = cb.r.duplicate()
	cost.r = [cost.r[0], cost.r[1], float(cost.r[2]) + dcw, cost.r[3]]
	var bw: float = float(bt.r[2]) + dcw
	var sh: float = cx - bw * 0.5 - float(bt.r[0])
	bt.r = [cx - bw * 0.5, bt.r[1], bw, bt.r[3]]
	if bt.has("tr"):
		bt.tr = [float(bt.tr[0]) + sh, bt.tr[1], bt.tr[2], bt.tr[3]]
	Snap._move(cost, Vector2(sh, 0))
	var hv := Snap.find(bx, "nghave")
	_ctext(hv, "Đang có " + G.fmt_n(have) + " sen đỏ" + ("" if rich else " · còn thiếu " + str(r - have)))
	ns_hid = sp.get("hide")
	if ns_hid != null:
		ns_hid.visible = false   # web: hộp nâng sao ẩn khi hộp nâng sớm mở, vẽ lại khi xong
	var ids := {}
	ns = _show(n, "nglk", ids, ns_close)
	U._click(ids.get(".ngx"), ns_close, "scale")
	var go: Callable = sp.go
	var done: Callable = sp.get("done", func(): pass)
	U._click(ids.get(".ngbuy"), func():
		ns_close()
		G.early_go(nd, fee, go)
		done.call(), "down")
	U._layout()

func _xn(b: Dictionary, s: String) -> void:
	# "×n" đỏ ở góc phải trên ô
	var br: float = float(b.r[0]) + float(b.r[2])
	b.erase("::before")
	var w: float = U._tw(b, s)
	b.text = s
	b.r = [br - w, b.r[1], w + 0.5, b.r[3]]
	b.tr = [br - w, b.get("tr", b.r)[1], w + 0.5, b.get("tr", b.r)[3]]

# ------------------------------------------------------------------ hộp Kho đầy (lL)
func full(cnt: int, cap: int) -> void:
	if kf != null or (U.bdp != null and U.bdp.mode != "off"):
		return
	G.g.kfpop = G._now_ms()
	var a: int = G.kho_star()
	var key := "kfov2"
	var lbl := ""
	if a < 10:
		var nd: Dictionary = G.kho_need(a + 1)
		var lock: bool = G.lv() < int(nd.lv)
		if not lock:
			key = "kfov"
			lbl = "Nâng kho lên " + str(a + 1) + "★"
		elif G.early_ok(int(nd.lv)):
			key = "kfov3"
			lbl = "💎 Nâng kho sớm lên " + str(a + 1) + "★"
	var n: Dictionary = T[key].duplicate(true)
	var bx := Snap.find(n, "kfbox")
	var p := Snap.find(bx, "", "p")
	p.text = "Đang chứa " + G.fmt_n(cnt) + "/" + str(cap) + " món. Bán bớt hàng hoặc nâng kho để chứa thêm."
	p.erase("tr")
	if lbl != "":
		_ctext(Snap.find(bx, "nskf"), lbl)
	var ids := {}
	kf = _show(n, "kfbox", ids, kf_close)
	for bt in U._qall(kf, "btn", []):
		var t: String = bt.texts[0].s if not bt.texts.is_empty() else ""
		if t == "Mở kho":
			U._click(bt, func():
				kf_close()
				U.kho_open(), "down")
		elif t == "Để sau":
			U._click(bt, kf_close, "down")
		else:
			U._click(bt, func():
				kf_close()
				up(), "down")
	U._layout()

func kf_close() -> void:
	if kf != null:
		U.anchors.erase(U._anchor_of(kf))
		kf.queue_free()
		kf = null
