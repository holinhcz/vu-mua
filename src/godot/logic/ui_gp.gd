extends "res://logic/ui_bang.gd"
# GIA PHẢ (gpOpen / gpRender bản web, Sổ làng › Gia phả): khung chung với Kho (ui_bang.gd), 3 tab .khseg.gptabs:
# Dòng họ (chip từng họ, cây theo cha con, bung/thu), Quan hệ (vòng quan hệ của nhà đang chọn), Danh bạ (ô tìm + chip lọc).
# Đáy bảng .khdock.gpdock: nhà đang chọn + Ghé chơi / Đi tới nhà / Quan hệ.
# Mẫu: ui/snap/gp.json (khung), gp_tab.json (hàng, chip, ô tìm, đáy). Luật ở w_lang.gd (gp_*).

var W          # w_lang.gd
var tab := "ho"             # GPS.tab
var ho := ""                # GPS.ho
var sel := 0                # GPS.sel
var q := ""                 # GPS.q
var loc := "all"            # GPS.loc
var ex := {}                # GPS.ex: bung / thu
var more := {}              # GPS.more: hiện hết con
var GB := {}
var GT := {}
var qe: LineEdit = null     # ô tìm (Danh bạ) nằm đè lên input.gpq
var _lk := ""               # khóa danh sách: đổi tab / họ / lọc thì cuộn về đầu
const ROW := 39.0           # GPROW 52px
const LOCS := [["all", "Tất cả"], ["mo", "Muốn nói chuyện"], ["nho", "Đang nhờ"], ["than", "Thân nhất"], ["lau", "Lâu chưa ghé"], ["ngay", "Ngày riêng"]]
const GPN := {"cha": "Cha mẹ", "con": "Con cháu", "ae": "Anh em", "sui": "Sui gia", "bc": "Bà con trong họ", "ban": "Bạn làm ăn", "xom": "Hàng xóm"}
const HOMAU := ["#b5653a", "#5f8a3c", "#c4932c", "#4f7896", "#7a5a8c", "#3f8a7a", "#a34d70", "#8a6a2e", "#4a7a4a", "#9a5040"]
const TAGC := {"ng": "rgb(216, 160, 48)"}

func _init(ui, wl) -> void:
	super(ui)
	W = wl
	GB = Snap.load_snap("gp")["#pov"][0]
	GT = Snap.load_snap("gp_tab")

func open(u = null) -> void:   # gpOpen(u)
	var F: Dictionary = W.gp_fam()
	if u != null and F.has(str(u)):
		sel = int(u)
		ho = String(F[str(u)].get("ho", ""))
		tab = "ho"
		var k := int(u)
		while F.has(str(k)) and W._tr(F[str(k)].get("cha")):
			ex[int(F[str(k)].cha)] = 1
			k = int(F[str(k)].cha)
	on = true
	scroll = 0.0
	sig = ""
	_build()

func close() -> void:
	super()
	if qe != null:
		qe.queue_free()
		qe = null

func step(dt: float) -> void:   # gpRender mỗi giây
	if not on:
		return
	if qe != null and box != null:
		_qe_place()
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	return JSON.stringify([tab, ho, sel, q, loc, ex, more, W.gp_fam(), W._vr()])

static func gp_init(n: String) -> String:   # gpInit: chữ đầu tên (bỏ danh xưng)
	var w := n.split(" ")
	var s: String = w[2 if w.size() > 2 else 1] if w.size() > 1 else (w[0] if w.size() else "?")
	return s.substr(0, 1) if s != "" else "?"

static func gp_color(h: String) -> String:   # gpColor
	var k := 0
	for i in h.length():
		k = (k * 31 + h.unicode_at(i)) & 0xffffffff
	return HOMAU[k % HOMAU.size()]

func _sub(k, f: Dictionary) -> String:   # gpSub
	return "Họ " + String(f.get("ho", "")) + " · đời " + str(W._i(f.get("doi")) if W._i(f.get("doi")) else 1) + (" · sui gia của bạn" if W.gp_is_sui_minh(k) else "")

func _tags(k, f: Dictionary) -> Array:   # gpTags
	var t := []
	if W._i(f.get("mo")) == 1 and W.chat_left(f) > 0:
		t.append("mo")
	if W._tr(f.get("req")) or W._tr(f.get("pq")):
		t.append("nho")
	if f.get("bk") is Dictionary and W._tr(f.bk.get("d")) and W.is_ngay_rieng(k):
		t.append("ng")
	if W._tr(f.get("job")):
		t.append("lam")
	return t

static func _low(s: String) -> String:   # gpLow: bỏ dấu, chữ thường
	var t := s.to_lower().replace("đ", "d")
	var out := ""
	for ch in t:
		var c := ch.unicode_at(0)
		if c >= 0x300 and c <= 0x36f:
			continue
		out += ch
	return out.strip_edges()

# ------------------------------------------------------------------ hàng của tab đang mở (gpRows)
func _rows() -> Array:
	var F: Dictionary = W.gp_fam()
	var rows := []
	if tab == "ho":
		var mem: Array = W.gp_ho(ho)
		var in_ho := {}
		for k in mem:
			in_ho[int(k)] = 1
		var kids := {}
		for k in mem:
			var c: int = W._i(F[str(k)].get("cha"))
			if c and in_ho.has(c):
				if not kids.has(c):
					kids[c] = []
				kids[c].append(int(k))
		var walk := func(walk_f: Callable, k: int, d: int) -> void:
			var ch: Array = kids.get(k, [])
			var opn: bool = bool(ex[k]) if ex.has(k) else d < 1
			rows.append({"u": k, "d": d, "tg": ("-" if opn else "+") if ch.size() else "", "n": ch.size()})
			if not opn:
				return
			var lim: int = ch.size() if more.has(k) else 5
			for c in ch.slice(0, lim):
				walk_f.call(walk_f, int(c), d + 1)
			if ch.size() > lim:
				rows.append({"mo": k, "d": d + 1, "n": ch.size() - lim})
		for k in mem:
			var c: int = W._i(F[str(k)].get("cha"))
			if not (c and in_ho.has(c)):
				walk.call(walk, int(k), 0)
	elif tab == "qh":
		if not F.has(str(sel)):
			return rows
		var R: Dictionary = W.gp_rel(sel)
		rows.append({"u": sel, "d": 0, "me": 1})
		for t in ["cha", "con", "ae", "sui", "bc", "ban", "xom"]:
			var a: Array = R.get(t, [])
			if a.is_empty():
				continue
			rows.append({"h": GPN[t] + " (" + str(a.size()) + ")"})
			for k in a.slice(0, 12 if t == "bc" else a.size()):
				rows.append({"u": int(k), "d": 0})
			if t == "bc" and a.size() > 12:
				rows.append({"h": "… còn " + str(a.size() - 12) + " nhà, xem ở tab Dòng họ"})
	else:
		var qq := _low(q)
		var d: int = W._vr()
		var ks: Array = W.gp_keys().filter(func(k):
			var f: Dictionary = F[str(k)]
			if qq != "" and _low(String(f.n) + " " + String(f.get("ho", ""))).find(qq) < 0:
				return false
			match loc:
				"mo": return W._i(f.get("mo")) == 1 and W.chat_left(f) > 0
				"nho": return W._tr(f.get("req")) or W._tr(f.get("pq"))
				"than": return W._i(f.get("tim")) >= 1
				"lau": return W._i(f.get("tim")) >= 2 and d - W._i(f.get("lg", d)) >= 3
				"ngay": return f.get("bk") is Dictionary and W._tr(f.bk.get("d")) and W.is_ngay_rieng(k)
			return true)
		if loc == "than":
			ks.sort_custom(func(a, b): return W._n(F[str(a)].get("dp")) > W._n(F[str(b)].get("dp")))
		elif loc == "lau":
			ks.sort_custom(func(a, b): return W._n(F[str(a)].get("lg")) < W._n(F[str(b)].get("lg")))
		else:
			ks.sort_custom(func(a, b): return _low(String(F[str(a)].n)) < _low(String(F[str(b)].n)))
		for k in ks:
			rows.append({"u": int(k), "d": 0})
	return rows

# ------------------------------------------------------------------ dựng
func _build() -> void:
	sig = _sig()
	var F: Dictionary = W.gp_fam()
	var ks: Array = W.gp_keys()
	if not F.has(str(sel)):
		sel = int(ks[0]) if ks.size() else 0
	var hos := {}
	for k in ks:
		var h := String(F[str(k)].get("ho", ""))
		if h != "":
			hos[h] = int(hos.get(h, 0)) + 1
	var hl: Array = hos.keys()
	hl.sort_custom(func(a, b): return hos[a] > hos[b])
	if not hos.has(ho):
		ho = String(hl[0]) if hl.size() else ""
	var n := _cl(GB)
	_seg_tabs(_find(n, "gptabs"), [["ho", "Dòng họ", false], ["qh", "Quan hệ", false], ["db", "Danh bạ", false]], tab, _tab_go, {})
	var tl := _find(n, "gptools")
	var vt := _find(n, "gplist")
	var y_list := 148.4
	tl.kids = []
	if tab == "ho":
		var row := _cl(GT.chips_c)
		_chip_row(row, hl.map(func(h): return [h, String(h) + " " + str(hos[h]), h == ho]), _ho_go, true)
		tl.kids = [row]
		y_list = 194.2
	elif tab == "db":
		var inp := _cl(GT.q)
		var row := _cl(GT.chips)
		_chip_row(row, LOCS.map(func(x): return [x[0], x[1], x[0] == loc]), _loc_go, false)
		tl.kids = [inp, row]
		y_list = 230.2
	var key := tab + "|" + ho + "|" + loc
	if key != _lk:
		_lk = key
		scroll = 0.0
	vt.r[3] = 522.9 - y_list
	vt.r[1] = y_list
	vt.cls = "gplist"
	var blocks := []
	var R := _rows()
	for i in R.size():
		var b := _row(R[i], F)
		if b.is_empty():
			continue
		b.gap = 4.5
		blocks.append(b)
	if blocks.is_empty():
		var e := _cl(GT.gph)
		e.kids[0].text = "Không có nhà nào hợp." if tab == "db" else "Chưa có nhà nào."
		blocks.append(e)
	_dock(n, F)
	_show(n, vt, blocks, 3.0)
	var cr = ids.get(".khchips")
	if cr != null:
		cr._kids.clip_contents = true
	if tab == "db":
		_qe_make()
	elif qe != null:
		qe.queue_free()
		qe = null
	U._layout()

func _tab_go(k: String) -> void:   # data-gt
	tab = k
	chx = 0.0

func _ho_go(h: String) -> void:   # data-gho
	ho = h

func _loc_go(k: String) -> void:   # data-gl
	loc = k

# .khchips: [[khóa, chữ, đang chọn]]; giữa: căn giữa khi vừa (tab Dòng họ), không thì cuộn ngang
func _chip_row(row: Dictionary, L: Array, go: Callable, center: bool) -> void:
	var x := float(row.r[0])
	var out := []
	var onr := [0.0, 0.0]
	for o in L:
		var c := _cl(GT.chip_on if o[2] else GT.chip)
		var sp: Dictionary = c.kids[0]
		var tw := _dw(sp, String(o[1]))
		var w := tw + 18.0
		_mv(c, x, float(row.r[1]) + 0.7)
		c.r[2] = w
		sp.text = o[1]
		sp.r = [x + 9.0, float(c.r[1]) + 8.8, tw, sp.r[3]]
		sp.tr = sp.r.duplicate()
		c.act = go.bind(o[0])
		if o[2]:
			onr = [x, x + w]
		out.append(c)
		x += w + 4.5
	var tot := x - 4.5 - float(row.r[0])
	if center and tot < 305.0:
		var dx := (305.0 - tot) * 0.5
		for c in out:
			Snap._move(c, Vector2(dx, 0))
	else:
		_chips_keep(out, onr, x - 4.5)
	row.r = [16.5, row.r[1], 305.0, row.r[3]]
	row.kids = out

# một hàng .gprow: tiêu đề (.gph), "+n nhà nữa", hoặc một nhà (.gpn)
func _row(r: Dictionary, F: Dictionary) -> Dictionary:
	if r.has("h"):
		var hh := _cl(GT.gph)
		hh.kids[0].text = r.h
		return hh
	if r.has("mo"):
		var m := _cl(GT.gph)
		var d0 := int(r.d)
		_mv(m, 16.5 + d0 * 13.5, float(m.r[1]))
		m.r[2] = 305.0 - d0 * 13.5
		m.kids[0].text = "+" + str(r.n) + " nhà nữa"
		m.act = func(): more[int(r.mo)] = 1
		m.dx = d0 * 13.5
		return m
	var u := int(r.u)
	if not F.has(str(u)):
		return {}
	var f: Dictionary = F[str(u)]
	var d := int(r.get("d", 0))
	var on_: bool = u == sel
	var c := _cl(GT.row_me if r.has("me") else (GT.row_on if on_ else (GT.row_c if d > 0 else GT.row)))
	var x := 16.5 + d * 13.5
	var w := 305.0 - d * 13.5
	_mv(c, x, float(c.r[1]))
	c.r[2] = w
	c.dx = d * 13.5
	var y := float(c.r[1])
	var K: Array = c.kids
	var gx = null
	var av: Dictionary = {}
	var nm: Dictionary = {}
	var hr: Dictionary = {}
	for k in K:
		var cl := String(k.cls)
		if cl == "gpx": gx = k
		elif cl == "gpav": av = k
		elif cl == "gpnm": nm = k
		elif cl == "gphr": hr = k
	var kids := []
	var ax := x + 4.5
	if String(r.get("tg", "")) != "":
		var g: Dictionary = _cl(gx if gx != null else GT.row_on.kids[0])
		_mv(g, x + 4.5, y + 8.2)
		g.text = "+" if r.tg == "+" else "−"
		g.act = _tog.bind(u, r.tg == "+")
		kids.append(g)
		ax += 24.0
	_mv(av, ax, y + 5.25)
	av.text = gp_init(String(f.n))
	av.css["background-color"] = gp_color(String(f.get("ho", "")))
	kids.append(av)
	var tg := _tags(u, f)
	var right := x + w - 6.0
	var tx := right - 13.5 * tg.size() - 1.5 * maxf(0.0, tg.size() - 1.0)
	for i in tg.size():
		var t := _cl(GT.get("t_" + tg[i], GT.t_nho))
		if tg[i] == "ng":
			t.text = "★"
			t.css["background-color"] = TAGC.ng
		_mv(t, tx + i * 15.0, y + 10.5)
		kids.append(t)
	hr.text = W.e_t(W._i(f.get("tim")))
	var hw := float(hr.r[2])
	var hx := (tx - 6.0 if tg.size() else right) - hw
	_mv(hr, hx, y + 11.0)
	kids.append(hr)
	var nx := ax + 30.0
	_mv(nm, nx, y + 5.2)
	nm.r[2] = hx - 6.0 - nx
	var nb: Dictionary = nm.kids[0]
	var ns: Dictionary = nm.kids[1]
	nb.text = _fit(nb, String(f.n), nm.r[2])
	nb.r[2] = nm.r[2]
	nb.tr = [nb.r[0], nb.tr[1], _tw(nb, nb.text), nb.tr[3]]
	ns.text = _fit(ns, _sub(u, f), nm.r[2])
	ns.r[2] = nm.r[2]
	ns.tr = [ns.r[0], ns.tr[1], _tw(ns, ns.text), ns.tr[3]]
	kids.append(nm)
	c.kids = kids
	c.act = _pick.bind(u)
	return c

func _fit(n: Dictionary, s: String, w: float) -> String:   # text-overflow: ellipsis
	if _tw(n, s) <= w:
		return s
	while s.length() > 1 and _tw(n, s + "…") > w:
		s = s.substr(0, s.length() - 1)
	return s.strip_edges() + "…"

func _tog(u: int, opn: bool) -> void:   # data-gx
	ex[u] = 1 if opn else 0

func _pick(u: int) -> void:   # data-gu
	sel = u

# .khdock.gpdock: nhà đang chọn + nút
func _dock(n: Dictionary, F: Dictionary) -> void:
	var dk := _find(n, "gpdock")
	var src: Dictionary = GT.dock2 if tab == "qh" else GT.dock
	var d := _cl(src)
	var f = F.get(str(sel))
	if f == null:
		var sl := _find(d, "gpsel")
		sl.kids = []
		var ac := _find(d, "gpacts")
		ac.kids = []
		dk.kids = d.kids
		return
	var gs := _find(d, "gpsel")
	var av: Dictionary = gs.kids[0]
	var nm: Dictionary = gs.kids[1]
	av.text = gp_init(String(f.n))
	av.css["background-color"] = gp_color(String(f.get("ho", "")))
	var b: Dictionary = nm.kids[0]
	var hs: Dictionary = b.kids[0]
	b.text = String(f.n)
	var bw := _tw(b, b.text + " ")
	b.tr = [b.r[0], b.tr[1], _tw(b, b.text), b.tr[3]]
	hs.text = W.e_t(W._i(f.get("tim")))
	_mv(hs, float(b.r[0]) + bw, float(hs.r[1]))
	var sm: Dictionary = nm.kids[1]
	sm.text = _sub(sel, f) + " · " + String(W.tinh_of(f).n)
	var sw := _tw(sm, sm.text)
	sm.tr = [sm.r[0], sm.tr[1], sw, sm.tr[3]]
	sm.r[2] = sw
	var acts := _find(d, "gpacts")
	var bt: Array = acts.kids
	bt[0].act = _ghe
	bt[1].act = _toi
	if bt.size() > 2:
		bt[2].act = _tab_go.bind("qh")
	dk.kids = d.kids

func _ghe() -> void:   # data-ga="ghe"
	U.vl_open(sel)

func _toi() -> void:   # data-ga="toi": gpGo
	var h = W.r1(sel)
	if h == null:
		return
	var x := float(h.o.gx) + float(h.o.fw) / 2.0
	var y := float(h.o.gy) + float(h.o.fd) / 2.0
	var F = U.F
	close()
	var vp: Vector2 = U.get_viewport().get_visible_rect().size
	U.main.cam = Vector2(F.en(x, y), F.nn(x, y) - 40.0) - Vector2(vp.x * 0.5, vp.y * 0.45) / U.main.zoom
	G.float_text.emit(x, y, "Nhà " + String(W.gp_fam()[str(sel)].n))

# ------------------------------------------------------------------ ô tìm (input.gpq)
func _qe_make() -> void:
	if qe == null:
		qe = LineEdit.new()
		qe.placeholder_text = "Tìm tên, họ…"
		qe.flat = true
		qe.text = q
		qe.add_theme_font_override("font", Css.font(500))
		qe.add_theme_font_size_override("font_size", int(round(12.0 * 0.75 * Css.K)))
		qe.add_theme_color_override("font_color", Color8(58, 42, 16))
		qe.add_theme_color_override("font_placeholder_color", Color8(138, 120, 96))
		var sb := StyleBoxEmpty.new()
		for s in ["normal", "focus", "read_only"]:
			qe.add_theme_stylebox_override(s, sb)
		qe.text_changed.connect(_q_changed)
		U.root.add_child(qe)
	_qe_place()

func _qe_place() -> void:
	var inp = ids.get(".gpq")
	if inp == null or qe == null:
		return
	var r: Rect2 = inp.get_global_rect()
	var pad := 9.0 * Css.K
	qe.position = r.position + Vector2(pad, 0)
	qe.size = Vector2(r.size.x - pad * 2.0, r.size.y)
	qe.move_to_front()

func _q_changed(t: String) -> void:   # input .gpq
	q = t
	_redo()
	if qe != null:
		qe.grab_focus()

func input(e: InputEvent) -> bool:
	if on and tab != "qh" and _chips_drag(e):
		return true
	return super(e)
