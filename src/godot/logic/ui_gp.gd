extends "res://logic/ui_kbang.gd"
# GIA PHẢ (gpOpen / gpRender bản web, Sổ làng › Gia phả). (bản 493) làm lại trên khung Kho + chip chung (ui_kbang.gd), 3 tab:
#  - Dòng họ: chip từng họ (màu riêng mỗi họ, gói xuống hàng), cây cha con thụt lề theo đời có đường nối, nút +/− bung thu;
#  - Quan hệ: nhà đang chọn trên đầu, rồi nhóm Gia đình (cha mẹ, con cháu, anh em) / Bà con (sui gia, bà con trong họ) /
#    Hàng xóm (bạn làm ăn, hàng xóm), mỗi nhà có chip vai;
#  - Danh bạ: ô tìm chung (_qbox, gõ không dấu) + chip lọc gói xuống hàng.
# Mỗi nhà: chip nền nhạt theo màu họ, mặt tròn (vlface/m*.webp), tên, dòng phụ (đời / họ · tính), dấu việc (muốn nói chuyện,
# đang nhờ, ngày riêng, đang làm thuê), 1 tim + số. Đáy cố định: nhà đang chọn + Ghé chơi / Đi tới nhà / Quan hệ.
# Luật ở w_lang.gd (gp_*).

var W          # w_lang.gd
var tab := "ho"             # GPS.tab
var ho := ""                # GPS.ho
var sel := 0                # GPS.sel
var q := ""                 # GPS.q
var loc := "all"            # GPS.loc
var ex := {}                # GPS.ex: bung / thu
var more := {}              # GPS.more: hiện hết con
var _lk := ""               # khóa danh sách: đổi tab / họ / lọc thì cuộn về đầu
const LOCS := [["all", "Tất cả"], ["mo", "Muốn nói chuyện"], ["nho", "Đang nhờ"], ["than", "Thân nhất"], ["lau", "Lâu chưa ghé"], ["ngay", "Ngày riêng"]]
const GPN := {"cha": "Cha mẹ", "con": "Con cháu", "ae": "Anh em", "sui": "Sui gia", "bc": "Bà con", "ban": "Bạn làm ăn", "xom": "Hàng xóm"}
const QHG := [["Gia đình", ["cha", "con", "ae"], "rgb(214, 140, 40)"], ["Bà con", ["sui", "bc"], "rgb(76, 150, 48)"], ["Hàng xóm", ["ban", "xom"], "rgb(70, 120, 180)"]]
const HOMAU := ["#c0552e", "#3f8a3c", "#3f72b0", "#c4932c", "#8a55a8", "#2f9a90", "#c0457a", "#7a6a2e", "#5a6a8a", "#9a7040"]   # (bản 494) 10 màu cách xa nhau
const CHAT := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M4 4h16a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-9l-5 4v-4H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z\" fill=\"rgb(76,160,70)\" stroke=\"rgb(40,110,40)\" stroke-width=\"1.2\"/><circle cx=\"7.5\" cy=\"10.5\" r=\"1.6\" fill=\"#fff\"/><circle cx=\"12\" cy=\"10.5\" r=\"1.6\" fill=\"#fff\"/><circle cx=\"16.5\" cy=\"10.5\" r=\"1.6\" fill=\"#fff\"/></svg>"   # (bản 495) muốn nói chuyện: bong bóng chat xanh
const TAGI := {"mo": "svg:CHAT", "nho": "pic:res://ui/img/bong/gap.png", "ng": "pic:res://ui/img/bong/sao.png", "lam": "pic:res://ui/img/xt/b_cuoc.webp"}
const TAGS := {"mo": "Muốn nói chuyện", "nho": "Đang nhờ việc", "ng": "Hôm nay ngày riêng", "lam": "Đang làm thuê cho bạn"}
const DOCK := 86.0          # cao đáy cố định

func _init(ui, wl) -> void:
	super(ui)
	W = wl

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

func step(dt: float) -> void:   # gpRender mỗi giây
	if not on:
		return
	_qe_place()
	_sig_t -= dt
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	if _sig() != sig:
		_build()

func _sig() -> String:
	return JSON.stringify([tab, ho, sel, q, loc, ex, more, W.gp_fam(), W._vr()])

var _hoc := {}   # họ -> màu (bản 494: mỗi họ một màu riêng, không trùng)
func gp_color(h: String) -> String:
	return String(_hoc.get(h, HOMAU[0]))

func _hoc_set(hl: Array) -> void:   # (bản 495) màu họ lưu trong bản lưu (g làng .hoc: họ -> số màu): họ cũ giữ màu, họ mới lấy màu còn trống
	var L0: Dictionary = W._r0()
	if not (L0.get("hoc") is Dictionary):
		L0.hoc = {}
	var M: Dictionary = L0.hoc
	var used := {}
	for h in M:
		used[int(M[h])] = 1
	var nl := hl.duplicate()
	nl.sort()
	for h in nl:
		if not M.has(h):
			var i := 0
			while used.has(i) and i < HOMAU.size():
				i += 1
			if i >= HOMAU.size():   # hết màu: dùng lại theo vòng
				i = M.size() % HOMAU.size()
			M[h] = i
			used[i] = 1
			G.mark()
	_hoc = {}
	for h in M:
		_hoc[String(h)] = HOMAU[int(M[h]) % HOMAU.size()]

func _ck(kind: String) -> Array:   # "ho:<#màu>": nền nhạt theo màu họ; "hoon:<#màu>": họ đang chọn (đậm hơn)
	if kind.begins_with("ho:") or kind.begins_with("hoon:"):
		var on_ := kind.begins_with("hoon:")
		var c := Color(kind.substr(kind.find(":") + 1))
		var w := Color.WHITE
		var f := func(t: float) -> String:
			var m := c.lerp(w, t)
			return "rgb(%d, %d, %d)" % [int(m.r8), int(m.g8), int(m.b8)]
		return [f.call(0.62 if on_ else 0.80), f.call(0.70 if on_ else 0.86), f.call(0.78 if on_ else 0.92), f.call(0.0 if on_ else 0.45)]
	return super(kind)

func _face(f: Dictionary) -> String:
	return "pic:res://ui/img/vlface/m" + str(clampi(W._i(f.get("lk")), 0, 7) % 8) + ".webp"

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

func _doi(f: Dictionary) -> int:
	return W._i(f.get("doi")) if W._i(f.get("doi")) else 1

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
		var walk := func(walk_f: Callable, k: int, d: int, p: int) -> void:
			var ch: Array = kids.get(k, [])
			var opn: bool = bool(ex[k]) if ex.has(k) else d < 1
			rows.append({"u": k, "d": d, "tg": ("-" if opn else "+") if ch.size() else "", "n": ch.size(), "p": p})
			if not opn:
				return
			var lim: int = ch.size() if more.has(k) else 5
			for c in ch.slice(0, lim):
				walk_f.call(walk_f, int(c), d + 1, k)
			if ch.size() > lim:
				rows.append({"mo": k, "d": d + 1, "n": ch.size() - lim, "p": k})
		for k in mem:
			var c: int = W._i(F[str(k)].get("cha"))
			if not (c and in_ho.has(c)):
				walk.call(walk, int(k), 0, 0)
	elif tab == "qh":
		if not F.has(str(sel)):
			return rows
		var R: Dictionary = W.gp_rel(sel)
		rows.append({"u": sel, "d": 0, "me": 1})
		for g in QHG:
			var n := 0
			for t in g[1]:
				n += (R.get(t, []) as Array).size()
			if n == 0:
				continue
			rows.append({"h": String(g[0]) + " (" + str(n) + ")", "c": g[2]})
			for t in g[1]:
				var a: Array = R.get(t, [])
				for k in a.slice(0, 12 if t == "bc" else a.size()):
					rows.append({"u": int(k), "d": 0, "vai": GPN[t]})
				if t == "bc" and a.size() > 12:
					rows.append({"note": "… còn " + str(a.size() - 12) + " nhà bà con, xem ở tab Dòng họ"})
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
	_hoc_set(hl)
	var key := tab + "|" + ho + "|" + loc
	if key != _lk:
		_lk = key
		scroll = 0.0
	var out := []
	var y := 6.0
	if tab == "ho":   # chip họ, gói xuống hàng
		var C := _wrapchips(y, hl.map(func(h): return [h, String(h) + " · " + str(hos[h]), h == ho, gp_color(String(h))]), _ho_go)
		out.append_array(C[0])
		y = float(C[1]) + GG
	elif tab == "db":
		out.append(_qbox(y, "gpq"))
		y += 30.0 + 8.0
		var C2 := _wrapchips(y, LOCS.map(func(x): return [x[0], x[1], x[0] == loc, ""]), _loc_go)
		out.append_array(C2[0])
		y = float(C2[1]) + GG
	var R := _rows()
	var nr := 0
	var yb := {}   # nhà -> đáy hàng (đường nối cây)
	for r in R:
		var b := _row(y, r, F)
		if r.has("p") and yb.has(int(r.p)):
			out.append_array(_elbow(float(yb[int(r.p)]), y, int(r.d), float(b[1]) * 0.5))
		out.append_array(b[0])
		if r.has("u"):
			yb[int(r.u)] = y + float(b[1])
		y += float(b[1]) + 5.0
		nr += 1
	if nr == 0:
		out.append(_dt(X0 + 2.0, y, XW, 16.0, "Không có nhà nào hợp." if tab == "db" else "Chưa có nhà nào.", 11.0, 700, SUB, "left"))
		y += 16.0 + 5.0
	y += GG - 5.0
	var sh := _kshell([["ho", "Dòng họ", false], ["qh", "Quan hệ", false], ["db", "Danh bạ", false]], tab, _tab_go)
	var vt: Dictionary = sh[1]
	vt.r[3] = float(vt.r[3]) - DOCK - 6.0   # chừa đáy cố định
	_hb = float(vt.r[3])
	_find(sh[0], "khcard").kids.append_array(_dock(float(vt.r[1]) + float(vt.r[3]) + 6.0, F))
	_kmount(sh[0], vt, float(sh[2]), out, y)
	if tab == "db":
		_qe_make(".gpq", "Tìm tên, họ…", q, _q_changed)
	else:
		_qe_drop()

func _tab_go(k: String) -> void:   # data-gt
	tab = k

func _ho_go(h: String) -> void:   # data-gho
	ho = h

func _loc_go(k: String) -> void:   # data-gl
	loc = k

func _wrapchips(y: float, L: Array, go: Callable) -> Array:   # chip chữ gói xuống hàng: [[khóa, chữ, đang chọn, màu họ ("" = xanh chung)]]
	var out := []
	var x := X0
	var h := 26.0
	for o in L:
		var t := String(o[1])
		var w: float = Box.text_w(t, 10.5, 700) + 18.0
		if x > X0 and x + w > X0 + XW:
			x = X0
			y += h + 6.0
		var mc := String(o[3])
		var kd := ("hoon:" + mc if o[2] else "ho:" + mc) if mc != "" else ("thue" if o[2] else "fut")
		var c := _chip(x, y, w, h, kd)
		c.kids = [_dt(x, y, w, h, t, 10.5, 800 if o[2] else 700, BROWN)]
		c.act = go.bind(o[0])
		out.append(c)
		x += w + 6.0
	return [out, y + h]

# một hàng: tiêu đề nhóm, ghi chú, "+n nhà nữa", hoặc một nhà
func _row(y: float, r: Dictionary, F: Dictionary) -> Array:
	if r.has("h"):
		return [_sect(y + 4.0, String(r.h), String(r.c)), 20.0]
	if r.has("note"):
		return [[_dt(X0 + 2.0, y, XW, 14.0, String(r.note), 10.0, 600, SUB, "left")], 14.0]
	var d := int(r.get("d", 0))
	var ind := d * 16.0
	if r.has("mo"):
		var w0 := XW - ind
		var m := _chip(X0 + ind, y, w0, 24.0, "fut")
		m.kids = [_dt(X0 + ind, y, w0, 24.0, "+" + str(r.n) + " nhà nữa", 10.5, 700, SUB)]
		m.act = func(): more[int(r.mo)] = 1
		return [[m], 24.0]
	var u := int(r.u)
	if not F.has(str(u)):
		return [[], -5.0]
	var f: Dictionary = F[str(u)]
	var out := []
	var x := X0 + ind
	var w := XW - ind
	var h := 42.0
	var mc := gp_color(String(f.get("ho", "")))
	var c := _chip(x, y, w, h, "now" if u == sel and not r.has("me") else ("hoon:" + mc if r.has("me") else "ho:" + mc))
	c.act = _pick.bind(u)
	out.append(c)
	var ax := x + 6.0
	if String(r.get("tg", "")) != "":   # nút bung / thu
		var g := _chip(ax, y + 11.0, 20.0, 20.0, "fut")
		g.kids = [_dt(ax, y + 11.0, 20.0, 20.0, "−" if r.tg == "-" else "+", 13.0, 800, BROWN)]
		g.act = _tog.bind(u, r.tg == "+")
		out.append(g)
		ax += 24.0
	out.append(_icx(ax + 15.0, y + h * 0.5, 30.0, _face(f)))
	var nx := ax + 36.0
	# phải: tim + số, dấu việc
	var tim: int = W._i(f.get("tim"))
	var rx := x + w - 8.0
	var tw: float = Box.text_w(str(tim), 11.0, 800)
	out.append(_dt(rx - tw, y, tw + 2.0, h, str(tim), 11.0, 800, "rgb(190, 50, 60)" if tim > 0 else SUB, "left"))
	out.append(_dic(rx - tw - 17.0, y + h * 0.5 - 7.0, 14.0, HEART if tim > 0 else HEART0))
	rx -= tw + 22.0
	for t in _tags(u, f):
		rx -= 18.0
		var ti := _dic(rx, y + h * 0.5 - 8.5, 17.0, CHAT) if t == "mo" else _icx(rx + 8.0, y + h * 0.5, 17.0, String(TAGI[t]))
		out.append(ti)
		var hit := _dbx(rx - 1.0, y + 8.0, 18.0, h - 16.0, "rgba(0, 0, 0, 0)", 0.0)
		hit.act = _dsay.bind(String(f.n) + ": " + String(TAGS[t]) + ".")
		out.append(hit)
	var nw := rx - 6.0 - nx
	out.append(_dt(nx, y + 5.0, nw, 16.0, _fitw(String(f.n), 11.5, 800, nw), 11.5, 800, BROWN, "left"))
	var sub := ""
	if tab == "ho":
		sub = "Đời " + str(_doi(f)) + " · " + String(W.tinh_of(f).n)
	elif r.has("me"):
		sub = "Họ " + String(f.get("ho", "")) + " · đời " + str(_doi(f)) + " · nhà đang xem"
	else:
		sub = "Họ " + String(f.get("ho", "")) + " · " + String(W.tinh_of(f).n)
	if W.gp_is_sui_minh(u):
		sub += " · sui gia của bạn"
	var sx := nx
	if r.has("vai"):   # chip vai (tab Quan hệ)
		var V := _tchip(sx, y + 23.0, String(r.vai), "info", "rgb(50, 90, 140)", null, 15.0, 9.0)
		out.append(V[0])
		sx += float(V[1]) + 5.0
	out.append(_dt(sx, y + 23.0, nx + nw - sx, 15.0, _fitw(sub, 9.5, 600, nx + nw - sx), 9.5, 600, SUB, "left"))
	return [out, h]

func _elbow(y0: float, y: float, d: int, my: float) -> Array:   # đường nối cha con: vạch dọc từ đáy hàng cha (y0) xuống giữa hàng con + gạch ngang vào hàng
	var lx := X0 + (d - 1) * 16.0 + 8.0
	var col := "rgba(150, 112, 48, 0.5)"
	return [_dbx(lx, y0, 1.5, y + my - y0, col, 0.0), _dbx(lx, y + my, 8.0, 1.5, col, 0.0)]

func _tog(u: int, opn: bool) -> void:   # data-gx
	ex[u] = 1 if opn else 0

func _pick(u: int) -> void:   # data-gu
	sel = u

# đáy cố định: nhà đang chọn + nút (giữ như bản cũ: Ghé chơi / Đi tới nhà / Quan hệ, tab Quan hệ bỏ nút Quan hệ)
func _dock(y: float, F: Dictionary) -> Array:
	var out := []
	var f = F.get(str(sel))
	out.append(_dbx(X0, y - 4.0, XW, 1.0, "rgb(222, 204, 164)", 0.0))
	if not (f is Dictionary):
		out.append(_dt(X0, y, XW, 40.0, "Chưa có nhà nào trong làng.", 11.0, 700, SUB, "left"))
		return out
	out.append(_icx(X0 + 18.0, y + 20.0, 34.0, _face(f)))
	var nm := String(f.n)
	var nw: float = minf(Box.text_w(nm, 12.0, 800) + 2.0, XW - 110.0)
	out.append(_dt(X0 + 42.0, y + 2.0, nw, 18.0, _fitw(nm, 12.0, 800, nw), 12.0, 800, BROWN, "left"))
	var tim: int = W._i(f.get("tim"))
	var hx := X0 + 42.0 + nw + 8.0
	out.append(_dic(hx, y + 4.0, 14.0, HEART if tim > 0 else HEART0))
	out.append(_dt(hx + 17.0, y + 2.0, 30.0, 18.0, str(tim), 11.0, 800, "rgb(190, 50, 60)" if tim > 0 else SUB, "left"))
	var sm := "Họ " + String(f.get("ho", "")) + " · đời " + str(_doi(f)) + " · " + String(W.tinh_of(f).n)
	out.append(_dt(X0 + 42.0, y + 21.0, XW - 46.0, 14.0, _fitw(sm, 10.0, 600, XW - 46.0), 10.0, 600, SUB, "left"))
	var by := y + 46.0
	var g := 6.0
	var n := 2 if tab == "qh" else 3
	var bw := floorf((XW - g * (n - 1)) / n)
	out.append(_btn(X0, by, bw, 32.0, "Ghé chơi", _ghe, "go"))
	out.append(_btn(X0 + bw + g, by, bw, 32.0, "Đi tới nhà", _toi, "plain"))   # (11-28) nút bấm được: gờ vàng như mọi nút (trước chip nội dung viền mảnh)
	if n == 3:
		out.append(_btn(X0 + (bw + g) * 2.0, by, XW - (bw + g) * 2.0, 32.0, "Quan hệ", _tab_go.bind("qh"), "plain"))
	return out

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
func _q_changed(t: String) -> void:   # input .gpq
	q = t
	_redo()
