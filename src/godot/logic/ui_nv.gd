extends RefCounted
# Bảng Sổ nhiệm vụ chép từ bản web (18_bang_so_nhiem_vu_khung.js): Hằng ngày · Tuần · Thành tựu · Sự kiện.
# Khung, tab, hàng, nút, rương... lấy đúng số đo bản web (res://ui/snap/nv_*.json, chụp ở nhiều trạng thái);
# nội dung xếp dọc như flex của .lsbody: cách 8px, trước tiêu đề mục 16px, sau tiêu đề 6px, hàng cách 5px (x .75).

const Snap = preload("res://ui/snap.gd")
const Box = preload("res://ui/box.gd")
const Css = preload("res://ui/css.gd")

const TABS := ["ngay", "tuan", "tt", "sk"]
const RX := 315.5        # mép phải nội dung trong hàng .lsrow (16,5 + 305 - padding 6)
const GAP := 6.0         # gap 8px của hàng
const G_BLK := 6.0       # .lsbody > * + *
const G_SEC := 12.0      # trước .vl-sec
const G_AFT := 4.5       # sau .vl-sec
const G_ROW := 3.75      # .lslist gap 5px
const PAD_B := 9.0       # .lsbody padding-bottom 12px
const EVC := {"hoi": "rgb(246, 200, 168)", "cho": "rgb(242, 220, 160)", "ngoc": "rgb(216, 196, 236)", "giup": "rgb(200, 232, 192)", "bt": "rgb(207, 230, 160)"}
const TICK := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M5 12.8l4.4 4.4L19.2 7.4\" fill=\"none\" stroke=\"rgb(63,154,58)\" stroke-width=\"3.2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>"

var U        # ui.gd
var G        # game.gd
var N        # nv.gd
var on := false
var tab := "ngay"
var T := {}
var shell := {}
var box: Control = null
var ids := {}
var body: Control = null
var body_r := Rect2()
var cont: Control = null
var sig := ""
var shsig := ""
var scroll := 0.0
var hmax := 0.0
var drag = null
var wig := []            # rương đang sáng: lắc như nggb
var _t := 0.0
var _clock := 0.0
var bdg: Control = null
var bdg_n := -1

func _init(ui) -> void:
	U = ui
	G = ui.G
	N = ui.G.nv
	_tpl()

static func _L(nm: String) -> Dictionary:
	return Snap.load_snap("nv_" + nm)["#pov"][0]

static func _kids(nm: String) -> Array:
	return Snap.find(_L(nm), "lsbody").kids

static func _has(n: Dictionary, c: String) -> bool:
	return String(n.get("cls", "")).split(" ").has(c)

static func _all(n: Dictionary, c: String, out: Array) -> Array:
	if _has(n, c):
		out.append(n)
	for k in n.get("kids", []):
		_all(k, c, out)
	return out

func _tpl() -> void:
	for t in TABS:
		var n: Dictionary = _L(t).duplicate(true)
		Snap.find(n, "lsbody").kids = []
		shell[t] = n
	var k0 := _kids("ngay")
	T.ap = k0[0]
	T.st = k0[1]
	T.sec = k0[2]
	T.list = k0[3].duplicate(true)
	T.list.kids = []
	T.row = k0[3].kids[0]
	T.btn = Snap.find(k0[3].kids[2], "btn")
	var k2 := _kids("ngay2")
	for r in k2[3].kids:
		if _has(r, "me"):
			T.row_me = r
			break
	for c in _all(k2[0], "nvrb", []):
		if _has(c, "got"):
			T.ch_got = c
		elif _has(c, "on"):
			T.ch_on = c
	T.ch_off = _all(k0[0], "nvrb", [])[0]
	var d0: Array = Snap.find(k0[1], "nvdots").kids
	T.dot = d0[0]
	T.dot_big = d0[6]
	for s in Snap.find(k2[1], "nvdots").kids:
		if _has(s, "on"):
			T.dot_on = s
			break
	var k3 := _kids("ngay3")
	T.dot_bigon = Snap.find(k3[1], "nvdots").kids[6]
	T.st_span = Snap.find(k3[1], "nvsh").kids[1]
	T.wk = _kids("tuan")[0]
	var kt := _kids("tt")
	T.row_nb = kt[1].kids[0]
	T.btn_d = Snap.find(kt[3].kids[0], "btn")
	var kt2 := _kids("tt2")
	for r in kt2[1].kids:
		if _has(r, "me"):
			T.row_nb_me = r
			break
	for b in _all({"kids": kt2}, "btn", []):
		if _has(b, "primary"):
			T.btn_p = b
			break
	var ks := _kids("sk")
	T.cal = ks[0]
	T.ev = ks[1]
	for k in ks:
		if _has(k, "lssum"):
			T.sum = k
	var kh := _kids("sk_hoi")
	for k in kh:
		if _has(k, "nvstg"):
			T.stg = k
		if _has(k, "vl-sec") and k.kids.size() == 1:
			T.sec1 = k
	var kc := _kids("sk_cho")
	T.shop = kc[3].kids

# ------------------------------------------------------------------ mở, đóng
func open(t := "") -> void:
	if t != "":
		tab = t
	U.close_all()
	U.kho_close()
	on = true
	shsig = ""
	sig = ""
	scroll = 0.0
	sync()

func close() -> void:
	on = false
	wig = []
	if box != null:
		U.anchors.erase(U._anchor_of(box))
		box.queue_free()
		box = null
	cont = null
	body = null

func _shell() -> void:
	if box != null:
		U.anchors.erase(U._anchor_of(box))
		box.queue_free()
	cont = null
	wig = []
	ids = {}
	var n: Dictionary = shell[tab]
	box = U._build(n, ids)
	U.root.add_child(box)
	U.anchors.append([box, 0.5, 0.5])
	body = ids.get(".lsbody")
	var bn := Snap.find(n, "lsbody")
	body_r = Rect2(bn.r[0], bn.r[1], bn.r[2], bn.r[3])
	body._kids.clip_contents = true
	U._stop(body)
	U._click(ids.get("#pClose"), close, "scale")
	var bk = ids.get(".pbk")
	if bk != null:
		U._stop(bk)
		bk.gui_input.connect(func(e): if U._is_tap_down(e): close())
	var win = ids.get(".pwin")
	if win != null:
		U._stop(win)
	var seg = ids.get(".lstabs")
	if seg != null:
		var j := 0
		for b in U._buttons(seg, []):
			var tt: String = TABS[j]
			U._click(b, func(): _tab(tt))
			j += 1
	U._layout()

func _tab(tt: String) -> void:
	if tt == tab:
		return
	tab = tt
	scroll = 0.0
	sync()

# ------------------------------------------------------------------ chữ
static func _fs(n: Dictionary) -> float:
	return Css.px(n.css.get("font-size", "15px")) * float(n.get("z", 1.0))

static func _fw(n: Dictionary) -> int:
	return int(n.css.get("font-weight", "400"))

static func _tw(n: Dictionary, s: String) -> float:
	return Box.text_w(s, _fs(n), _fw(n))

static func _lh(n: Dictionary) -> float:
	var v: String = n.css.get("line-height", "normal")
	return Css.px(v) * float(n.get("z", 1.0)) if v.ends_with("px") else _fs(n) * 1.2

static func _st(n: Dictionary, s: String, x: float, w := -1.0) -> void:
	n.text = s
	var tr: Array = n.get("tr", n.r)
	n.tr = [x, float(tr[1]), _tw(n, s) + 0.5 if w < 0.0 else w, float(tr[3])]

static func _setw(n: Dictionary, w: float) -> void:
	n.r = [n.r[0], n.r[1], w, n.r[3]]

static func _seth(n: Dictionary, h: float) -> void:
	n.r = [n.r[0], n.r[1], n.r[2], h]

static func _ell(n: Dictionary, s: String, w: float) -> String:
	# text-overflow: ellipsis
	if _tw(n, s) <= w:
		return s
	var t := s
	while t.length() > 1 and _tw(n, t + "…") > w:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"

static func _right(n: Dictionary, s: String, rx: float) -> void:
	var w := _tw(n, s)
	_st(n, s, rx - w, w + 0.5)
	n.r = [rx - w, n.r[1], w, n.r[3]]

func _flow(n: Dictionary, runs: Array, bn) -> float:
	# chữ thường + <b> xuống dòng như trình duyệt (tách ở dấu cách), thay chữ và con <b> của n; trả về cao mới
	var z := float(n.get("z", 1.0))
	var sty := [n, bn if bn != null else n]
	var lh := _lh(n)
	var x0 := float(n.r[0])
	var y0 := float(n.r[1])
	var W := float(n.r[2])
	# chữ theo từng ký tự kèm kiểu, gom thành từ
	var words := []   # [[[s, st], ...], ...]
	var cur := []
	for r in runs:
		var s: String = r[0]
		var st: int = 1 if r[1] else 0
		for ch in s:
			if ch == " ":
				if not cur.is_empty():
					words.append(cur)
					cur = []
				continue
			if not cur.is_empty() and cur[-1][1] == st:
				cur[-1][0] += ch
			else:
				cur.append([ch, st])
	if not cur.is_empty():
		words.append(cur)
	var sp := Box.text_w("a a", _fs(n), _fw(n)) - Box.text_w("aa", _fs(n), _fw(n))
	# xuống dòng theo bề rộng từng từ, rồi mỗi dòng gom thành đoạn cùng kiểu; vị trí đoạn = bề rộng đo cả đoạn trước
	var lines := [[]]
	var x := 0.0
	for wd in words:
		var ww := 0.0
		for c in wd:
			ww += _tw(sty[c[1]], c[0])
		if x > 0.0 and x + sp + ww > W + 2.0:
			lines.append([])
			x = 0.0
		elif x > 0.0:
			x += sp
		lines[-1].append(wd)
		x += ww
	var spans := []   # [line, x, s, st]
	var line := 0
	for li in lines.size():
		var segs := []   # [s, st]
		for wi in lines[li].size():
			var wd: Array = lines[li][wi]
			for ci in wd.size():
				var c: Array = wd[ci]
				var pre := " " if wi > 0 and ci == 0 else ""
				if not segs.is_empty() and segs[-1][1] == c[1]:
					segs[-1][0] += pre + c[0]
				else:
					if pre != "" and not segs.is_empty():
						segs[-1][0] += pre
					segs.append([c[0], c[1]])
		var sx := 0.0
		for sg in segs:
			spans.append([li, sx, sg[0], sg[1]])
			sx += _tw(sty[sg[1]], sg[0])
		line = li
	var kids := []
	for s in spans:
		var src: Dictionary = sty[s[3]]
		var css: Dictionary = src.css.duplicate()
		css["white-space"] = "nowrap"
		css["text-align"] = "start"
		css["background-color"] = "rgba(0, 0, 0, 0)"
		for p in ["padding-left", "padding-right"]:
			css[p] = "0px"
		var w: float = _tw(src, s[2])
		var y: float = y0 + s[0] * lh
		kids.append({"tag": "span", "id": "", "cls": "", "z": z, "css": css, "kids": [], "text": s[2],
			"r": [x0 + s[1], y, w, lh], "tr": [x0 + s[1], y, w + 0.5, lh]})
	n.erase("text")
	n.erase("tr")
	n.kids = kids
	var h := (line + 1) * lh
	_seth(n, h)
	return h

# ------------------------------------------------------------------ mảnh ghép
static func _at(n: Dictionary, y: float) -> Dictionary:
	Snap._move(n, Vector2(0, y - float(n.r[1])))
	return n

func _btn(s: String, kind: String, act: String) -> Dictionary:
	var b: Dictionary = (T.btn_p if kind == "p" else T.btn_d if kind == "d" else T.btn).duplicate(true)
	var pad := Css.px(b.css.get("padding-left", "10px")) * float(b.get("z", 1.0))
	var tw := _tw(b, s)
	_setw(b, tw + 2.0 * pad)
	_st(b, s, float(b.r[0]) + pad, tw + 0.5)
	b.erase("::before")
	b.erase("::after")
	if kind != "d":
		b["act"] = act
	return b

func _tick(n: Dictionary) -> void:
	n.erase("text")
	n.erase("tr")
	var r: Array = n.r
	var w := minf(float(r[2]), 16.0)
	n.kids = [{"tag": "svg", "id": "", "cls": "", "z": n.get("z", 1.0), "css": {}, "kids": [], "svg": TICK,
		"r": [float(r[0]) + (float(r[2]) - w) * 0.5, float(r[1]) + (float(r[3]) - w) * 0.5, w, w]}]

func _row(pt: String, name: String, sub: String, frac: float, btns: Array, done: bool) -> Dictionary:
	# nvRow: điểm, tên, tiến độ (frac < 0: không thanh), nút bên phải hoặc dấu xong
	var bar := frac >= 0.0
	var nd: Dictionary = ((T.row_me if done else T.row) if bar else (T.row_nb_me if done else T.row_nb)).duplicate(true)
	var y := float(nd.r[1])
	var ps := Snap.find(nd, "lspos")
	var pw := _tw(ps, pt)
	_st(ps, pt, float(ps.r[0]) + (float(ps.r[2]) - pw) * 0.5, pw + 0.5)
	var right := RX + GAP
	var keep := []
	for k in nd.kids:
		if _has(k, "nvdone"):
			_tick(k)
			right = float(k.r[0])
		if not _has(k, "btn"):
			keep.append(k)
	nd.kids = keep
	if not done:
		for i in range(btns.size() - 1, -1, -1):
			var b := _btn(btns[i][0], btns[i][1], btns[i][2])
			var x := (RX if right > RX else right - GAP) - float(b.r[2])
			Snap._move(b, Vector2(x - float(b.r[0]), y + (float(nd.r[3]) - float(b.r[3])) * 0.5 - float(b.r[1])))
			nd.kids.append(b)
			right = x
	var rn := Snap.find(nd, "lsrn")
	var w := right - GAP - float(rn.r[0])
	_setw(rn, w)
	for k in rn.kids:
		_setw(k, w)
		if k.tag == "b":
			_st(k, _ell(k, name, w), float(k.r[0]))
		elif k.tag == "small":
			_st(k, sub, float(k.r[0]))
		elif _has(k, "combar"):
			for q in k.kids:
				_setw(q, w * clampf(frac, 0.0, 1.0))
	return nd

func _list(rows: Array) -> Dictionary:
	var L: Dictionary = T.list.duplicate(true)
	var y := float(L.r[1])
	for r in rows:
		_at(r, y)
		y += float(r.r[3]) + G_ROW
	L.kids = rows
	_seth(L, maxf(0.0, y - G_ROW - float(L.r[1])))
	return L

func _sec(b: String, small = null) -> Dictionary:
	var n: Dictionary = (T.sec if small != null else T.sec1).duplicate(true)
	var bb: Dictionary = n.kids[0]
	_st(bb, b, float(bb.r[0]))
	if small != null:
		var sm: Dictionary = n.kids[1]
		var h0 := float(sm.r[3])
		var h := _flow(sm, [[small, false]], null)
		_seth(n, float(n.r[3]) + h - h0)
	return n

func _chests(card: Dictionary, list: Array, pts: int, cl: Dictionary, act: String) -> void:
	var rw := Snap.find(card, "nvrw")
	for i in rw.kids.size():
		var c: Dictionary = rw.kids[i]
		var p := int(list[i].p)
		var o := pts >= p
		var got := cl.has(str(p))
		var src: Dictionary = T.ch_got if got else (T.ch_on if o else T.ch_off)
		c.css = src.css.duplicate()
		c.cls = src.cls
		if got:
			_grayify(c)
		elif o:
			c["act"] = act + ":" + str(p)
			c["wig"] = 1

static func _gray_c(s: String) -> String:
	# css filter grayscale(1)
	var re := RegEx.create_from_string("rgba?\\(\\s*([0-9.]+),\\s*([0-9.]+),\\s*([0-9.]+)")
	var out := s
	for m in re.search_all(s):
		var l := int(round(0.2126 * float(m.get_string(1)) + 0.7152 * float(m.get_string(2)) + 0.0722 * float(m.get_string(3))))
		var head := m.get_string(0)
		out = out.replace(head, head.substr(0, head.find("(") + 1) + str(l) + ", " + str(l) + ", " + str(l))
	return out

func _grayify(n: Dictionary) -> void:
	var css: Dictionary = n.css.duplicate()
	for k in css.keys():
		if String(css[k]).find("rgb") >= 0:
			css[k] = _gray_c(css[k])
	n.css = css
	if n.has("svg"):
		n.svg = _gray_c(n.svg)
		n["gray"] = 1
	for k in n.get("kids", []):
		_grayify(k)

func _num_span(span: Dictionary, num: String, rest: String, rx: float) -> void:
	# "<b>40</b>/100" canh phải
	var b: Dictionary = span.kids[0]
	var bw := _tw(b, num)
	var sw := _tw(span, rest)
	var x0 := rx - bw - sw
	span.r = [x0, span.r[1], bw + sw, span.r[3]]
	_st(b, num, x0, bw + 0.5)
	b.r = [x0, b.r[1], bw, b.r[3]]
	_st(span, rest, x0 + bw, sw + 0.5)

static func _rx(n: Dictionary) -> float:
	return float(n.r[0]) + float(n.r[2])

func _grow_small(card: Dictionary, sm: Dictionary, runs: Array) -> void:
	var h0 := float(sm.r[3])
	var bn = sm.kids[0] if sm.get("kids", []).size() > 0 else null
	var h := _flow(sm, runs, bn)
	_seth(card, float(card.r[3]) + h - h0)

# ------------------------------------------------------------------ 4 tab
func _day() -> Array:
	var n: Dictionary = N.Pl()
	var ap: int = N.r5()
	var s: Dictionary = N.SI()
	var d: int = N.d4()
	var c: int = N.streak_now()
	var today: bool = int(s.last) == d
	var pos := c % 7
	var bn: int = N.bonus(c)
	if today and pos == 0 and c > 0:
		pos = 7
	var k := int(floor(float(c - 1 if today else c) / 7.0)) + 1
	var rest := "đã dùng" if int(s.rw) == N.week() else "còn"
	var out := []
	# Năng động
	var a: Dictionary = T.ap.duplicate(true)
	var sh := Snap.find(a, "nvsh")
	_num_span(sh.kids[1], str(ap), "/100", _rx(sh))
	Snap.find(a, "combar").kids[0].r[2] = float(Snap.find(a, "combar").r[2]) * ap / 100.0
	_chests(a, N.E8, ap, n.cl, "ch")
	out.append(a)
	# chuỗi ngày
	var st: Dictionary = T.st.duplicate(true)
	var sh2 := Snap.find(st, "nvsh")
	var tb: Dictionary = sh2.kids[0]
	_st(tb, "Chuỗi " + str(c) + " ngày" + (" · hôm nay xong" if today else ""), float(tb.r[0]))
	tb.r[2] = tb.tr[2]
	if bn:
		var sp: Dictionary = T.st_span.duplicate(true)
		Snap._move(sp, Vector2(0, float(sh2.r[1]) - float(Snap.find(_kids("ngay3")[1], "nvsh").r[1])))
		_right(sp, "xu rương +" + str(bn) + "%", _rx(sh2))
		sh2.kids[1] = sp
	var dots := Snap.find(st, "nvdots")
	for i in 7:
		var dd: Dictionary = dots.kids[i]
		var src: Dictionary = (T.dot_bigon if i < pos else T.dot_big) if i == 6 else (T.dot_on if i < pos else T.dot)
		dd.css = src.css.duplicate()
		dd.cls = src.cls
	var sm: Dictionary = st.kids[st.kids.size() - 1]
	var runs := [["Đủ 7 ngày: ", false], [N.round_n(k), true], [" · Ngày nghỉ tuần này: " + rest, false]]
	var tt: String = N.sk_title()
	if tt != "":
		runs += [[" · Danh hiệu: ", false], [tt, true]]
	_grow_small(st, sm, runs)
	out.append(st)
	out.append(_sec("Việc hôm nay", "Làm mới lúc 0 giờ." + ("" if n.sw else " Được đổi 1 việc chưa ưng.")))
	var rows := []
	for t in N.MI():
		var c2: int = N.task_f(t)
		var dn: bool = N.done(t)
		var bt := []
		if t.get("vg", 0):
			bt.append(["Giao", "p" if c2 >= int(t.m) else "d", "vg"])
		elif t.get("go", 0):
			bt.append(["Đi làm", "n", "go:" + String(t.id)])
		if not dn and not t.get("vg", 0) and not n.sw and not N.is_base(t):
			bt.append(["Đổi", "n", "sw:" + String(t.id)])
		rows.append(_row("+" + str(N.pt(t)), String(t.n), G.fmt_n(mini(c2, int(t.m))) + "/" + G.fmt_n(int(t.m)), float(c2) / float(t.m), bt, dn))
	out.append(_list(rows))
	return out

func _week() -> Array:
	var w: Dictionary = N.Pl().wk
	var wpt: int = N.WP()
	var dd: int = N.wk_days()
	var left: float = N.week_left()
	var top: int = int(N.NVWCH[N.NVWCH.size() - 1].p)
	var out := []
	var a: Dictionary = T.wk.duplicate(true)
	var sh := Snap.find(a, "nvsh")
	_num_span(sh.kids[1], str(wpt), "/" + str(top), _rx(sh))
	Snap.find(a, "combar").kids[0].r[2] = float(Snap.find(a, "combar").r[2]) * minf(1.0, float(wpt) / top)
	_chests(a, N.NVWCH, wpt, w.cl, "wch")
	var sm: Dictionary = a.kids[a.kids.size() - 1]
	_grow_small(a, sm, [["Quà mốc cuối tuần này: ", false], [N.deco_of(N.week())[1], true],
		[" + 5 sen đỏ · còn " + (str(int(floor(left / 86400.0))) + " ngày" if left >= 86400.0 else N.ao(left)), false]])
	out.append(a)
	out.append(_sec("Việc tuần này", "Làm mới 0 giờ thứ Hai. Mỗi ngày đủ 100 năng động được thêm " + str(N.NVDAYPT) + " điểm tuần."))
	var rows := [_row("+" + str(N.NVDAYPT), "Ngày đủ 100 năng động (mỗi ngày)", str(dd) + "/7", dd / 7.0, [], dd >= 7)]
	for t in N.wk_list():
		var c: int = N.nvW(t.id)
		var bt := [["Đi làm", "n", "go:" + String(t.id)]] if t.get("go", 0) else []
		rows.append(_row("+" + str(t.pt), String(t.n), G.fmt_n(mini(c, int(t.m))) + "/" + G.fmt_n(int(t.m)), float(c) / float(t.m), bt, c >= int(t.m)))
	out.append(_list(rows))
	return out

func _ach() -> Array:
	var s: Dictionary = N.SI()
	var out := []
	out.append(_sec("Danh hiệu chuỗi ngày", "Dài nhất " + str(s.best) + " ngày. Danh hiệu hiện ở hồ sơ và bảng xếp hạng làng."))
	var rows := []
	for x in N.NVSK:
		var ok: bool = int(s.best) >= int(x[0])
		rows.append(_row(str(x[0]), x[1], "Đã đạt" if ok else "Chuỗi " + str(x[0]) + " ngày", -1.0, [], ok))
	out.append(_list(rows))
	var t9 := []
	for x in N.T9:
		t9.append(x)
	out.append(_sec("Thành tựu", "Mỗi thành tựu 5 bậc: " + ", ".join(t9).to_lower() + "."))
	rows = []
	for A in N.L8:
		var t: int = N.A8(A)
		var v: int = N.ach_f(A)
		if t >= 5:
			rows.append(_row("5", String(A.n) + " · " + N.T9[4], G.fmt_n(v) + " " + String(A.d), -1.0, [], true))
			continue
		var need: int = N.S9(A, t)
		var R: Dictionary = N.ach_rw(t)
		var ok: bool = v >= need
		rows.append(_row(str(t), String(A.n) + (" · " + N.T9[t - 1] if t else ""), G.fmt_n(mini(v, need)) + "/" + G.fmt_n(need), float(v) / need,
			[[str(R.ng) + " sen · " + G.fmt_n(R.xu) + " xu", "p" if ok else "d", "ach:" + String(A.k)]], false))
	out.append(_list(rows))
	out.append(_sec("Công trình", "Mỗi công trình một chuỗi việc, xong việc này hiện việc tiếp theo."))
	rows = []
	for L in N.w9():
		var i: int = N.M9(L)
		if i >= L.steps.size():
			rows.append(_row(str(L.steps.size()), String(L.n), "Đã xong cả chuỗi", -1.0, [], true))
			continue
		var st: Dictionary = L.steps[i]
		var c: int = N.step_f(st)
		var R: Dictionary = N.AI(i)
		var ok: bool = c >= int(st.m)
		rows.append(_row(str(i + 1), String(L.n) + ": " + String(st.t), G.fmt_n(mini(c, int(st.m))) + "/" + G.fmt_n(int(st.m)), float(c) / float(st.m),
			[[G.fmt_n(R.xu) + " xu", "p" if ok else "d", "ln:" + String(L.k)]], false))
	out.append(_list(rows))
	return out

func _event() -> Array:
	var x: Dictionary = N.wp()
	var EL: Array = N.jL(x.c)
	var EN: Array = N.jL(x.c + 1)
	var ev: Dictionary = N.ff()
	var s = N.ev()
	if ev.id == "cho":
		N.DL()
	var out := []
	var cal: Dictionary = T.cal.duplicate(true)
	var now_css := ""
	for q in T.cal.kids:
		if _has(q, "now"):
			now_css = q.css.get("box-shadow", "none")
	for d in 14:
		var sp: Dictionary = cal.kids[d]
		var e = null
		for q in EL:
			if d >= int(q.d0) and d < int(q.d1):
				e = q
		sp.css = sp.css.duplicate()
		sp.css["background-color"] = EVC.get(e.id, "rgb(239, 227, 196)") if e != null else "rgb(239, 227, 196)"
		sp.css["opacity"] = "0.45" if d < int(x.d) else "1"
		sp.css["box-shadow"] = now_css if d == int(x.d) else "none"
		var t: String = e.ic if e != null and d == int(e.d0) else ""
		if t == "":
			sp.erase("text")
			sp.erase("tr")
		else:
			var w := _tw(sp, t)
			sp.text = t
			sp.tr = [float(sp.r[0]) + (float(sp.r[2]) - w) * 0.5, float(sp.r[1]) + (float(sp.r[3]) - 13.0) * 0.5, w + 0.5, 13.0]
	out.append(cal)
	if ev.id != "":
		var cd: Dictionary = T.ev.duplicate(true)
		var sh := Snap.find(cd, "nvsh")
		_st(sh.kids[0], String(ev.ic) + " " + String(ev.n), float(sh.kids[0].r[0]))
		sh.kids[0].r[2] = sh.kids[0].tr[2]
		_right(sh.kids[1], "còn " + N.vY(int(ev.d1)), _rx(sh))
		_grow_small(cd, cd.kids[cd.kids.size() - 1], [[String(ev.d), false]])
		out.append(cd)
		if ev.id == "hoi":
			var st: Dictionary = N.FL[int(x.d)]
			var dp := int(s.day.get(str(x.d), 0))
			var stg: Dictionary = T.stg.duplicate(true)
			var src: Array = T.stg.kids   # chụp ở chặng 2: [0] đã qua, [1] đang, [2..] chưa tới
			for i in 5:
				var q: Dictionary = stg.kids[i]
				var f: Dictionary = src[1] if i == int(x.d) else (src[0] if i < int(x.d) else src[2])
				q.css = f.css.duplicate()
				q.cls = f.cls
				if q.kids.size() > 0 and f.kids.size() > 0:
					q.kids[0].css = f.kids[0].css.duplicate()
			out.append(stg)
			out.append(_sec("Hôm nay: " + String(st.n), String(st.d)))
			var rows := []
			var nm := ["Túi xu", "2 vật liệu", "1 sen đỏ"]
			for i in 3:
				var ok: bool = dp >= N.GL[i]
				var got: bool = s.cl.has("d:" + str(x.d) + ":" + str(i))
				rows.append(_row(str(i + 1), nm[i], G.fmt_n(mini(dp, N.GL[i])) + "/" + G.fmt_n(N.GL[i]), float(dp) / N.GL[i],
					[["Đã nhận" if got else "Nhận", "p" if ok and not got else "d", "hd:" + str(i)]], false))
			out.append(_list(rows))
			out.append(_sec("Cộng dồn 5 ngày"))
			rows = []
			nm = ["Túi xu lớn", "3 sen đỏ, 6 vật liệu kho", "8 sen đỏ, bùa +50% EXP"]
			for i in 3:
				var ok: bool = int(s.p) >= N.WL[i]
				var got: bool = s.cl.has("t:" + str(i))
				rows.append(_row(str(i + 1), nm[i], G.fmt_n(mini(int(s.p), N.WL[i])) + "/" + G.fmt_n(N.WL[i]), float(s.p) / N.WL[i],
					[["Đã nhận" if got else "Nhận", "p" if ok and not got else "d", "ht:" + str(i)]], false))
			out.append(_list(rows))
			out.append(_sec("Bảng vàng hội làng", "Vào hợp tác xã chơi online để so điểm với bà con."))
		elif ev.id == "cho":
			out.append(_sec("Vé chợ: " + str(s.ve), "10 điểm năng động = 1 vé · mỗi đơn giao = 2 vé"))
			var rows := []
			for i in N.HI.size():
				var it: Dictionary = N.HI[i]
				var r: Dictionary = T.shop[i].duplicate(true)
				var lim: bool = it.has("max") and int(s.buy.get(it.id, 0)) >= int(it.max)
				var ok: bool = int(s.ve) >= int(it.c) and not lim
				var rn := Snap.find(r, "lsrn")
				var sm := Snap.find(rn, "", "small")
				_st(sm, String(it.d) + (" · còn " + str(int(it.max) - int(s.buy.get(it.id, 0))) if it.has("max") else ""), float(sm.r[0]))
				var keep := []
				var bx := 0.0
				for k in r.kids:
					if _has(k, "btn"):
						var b := _btn(str(it.c) + " vé", "p" if ok else "d", "shop:" + String(it.id))
						Snap._move(b, Vector2(RX - float(b.r[2]) - float(b.r[0]), float(k.r[1]) - float(b.r[1])))
						bx = float(b.r[0])
						keep.append(b)
					else:
						keep.append(k)
				r.kids = keep
				var w := bx - GAP - float(rn.r[0])
				_setw(rn, w)
				for k in rn.kids:
					_setw(k, w)
				rows.append(r)
			out.append(_list(rows))
		elif ev.id == "ngoc":
			out.append(_sec("Đã tiêu " + str(s.sp) + " sen đỏ", "Làm chín ngay, bù thiếu, đổi sen đỏ… đều tính"))
			var rows := []
			for i in N.VL.size():
				var M: Dictionary = N.VL[i]
				var ok: bool = int(s.sp) >= int(M.p)
				var got: bool = s.cl.has("n" + str(i))
				rows.append(_row(str(i + 1), String(M.n), G.fmt_n(mini(int(s.sp), int(M.p))) + "/" + G.fmt_n(int(M.p)), float(s.sp) / float(M.p),
					[["Đã nhận" if got else "Nhận", "p" if ok and not got else "d", "ng:" + str(i)]], false))
			out.append(_list(rows))
	var nx = null
	for e in EL:
		if int(e.d0) > int(x.d):
			nx = {"id": e.id, "n": e.n, "ic": e.ic, "d0": int(e.d0)}
			break
	if nx == null and EN.size() > 0:
		nx = {"id": EN[0].id, "n": EN[0].n, "ic": EN[0].ic, "d0": int(EN[0].d0) + 14}
	if nx != null:
		var p: Dictionary = T.sum.duplicate(true)
		var h0 := float(p.r[3])
		var h := _flow(p, [["Sắp tới: " + String(nx.ic) + " ", false], [String(nx.n), true],
			[" sau " + str(int(nx.d0) - int(x.d)) + " ngày" + (" · nhớ để dành sen đỏ" if nx.id == "ngoc" else "") + ".", false]], p.kids[0] if p.kids.size() > 0 else null)
		_seth(p, h0 + h - h0)
		out.append(p)
	return out

# ------------------------------------------------------------------ dựng, cuộn
func _content() -> Dictionary:
	var L: Array = _week() if tab == "tuan" else (_ach() if tab == "tt" else (_event() if tab == "sk" else _day()))
	var y := body_r.position.y + 3.0
	for i in L.size():
		var n: Dictionary = L[i]
		if i > 0:
			if _has(n, "vl-sec"):
				y += G_SEC
			elif _has(L[i - 1], "vl-sec"):
				y += G_AFT
			else:
				y += G_BLK
		_at(n, y)
		y += float(n.r[3])
	var top := body_r.position.y
	return {"tag": "div", "id": "", "cls": "", "z": 0.75, "css": {}, "kids": L,
		"r": [body_r.position.x, top, body_r.size.x, y + PAD_B - top]}

func sync() -> void:
	if not on:
		return
	if shsig != tab:
		shsig = tab
		sig = ""
		_shell()
	var c := _content()
	hmax = maxf(0.0, float(c.r[3]) - body_r.size.y)
	scroll = clampf(scroll, 0.0, hmax)
	var s := JSON.stringify(c)
	if s != sig or cont == null:
		sig = s
		if cont != null:
			cont.queue_free()
		wig = []
		cont = U._build(c, {}, body_r.position)
		body.add(cont)
		_hook(cont)
	U._move(cont, Vector2(0, -scroll))

func _hook(b: Control) -> void:
	for k in b.kids():
		var n: Dictionary = k.get_meta("snap", {})
		if n.has("act"):
			var a: String = n.act
			U._click(k, func(): if not _dragged(): _do(a), "down" if _has(n, "btn") else "scale94")
		if n.has("wig"):
			wig.append(k)
		if n.has("gray"):
			for p in k.pics:
				p.tex = _gray_tex(p.tex)
			k.redraw()
		_hook(k)

var _grays := {}
func _gray_tex(t: Texture2D) -> Texture2D:
	if t == null:
		return t
	var key := t.get_rid().get_id()
	if _grays.has(key):
		return _grays[key]
	var img := t.get_image()
	if img == null:
		return t
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			img.set_pixel(x, y, Color(l, l, l, c.a))
	var g := ImageTexture.create_from_image(img)
	_grays[key] = g
	return g

func _do(a: String) -> void:
	var p := a.split(":")
	var k := p[0]
	var v := p[1] if p.size() > 1 else ""
	match k:
		"ch": N.IL(int(v))
		"wch": N.wk_chest(int(v))
		"vg": pass
		"sw": N.swap(v)
		"ln": N.zI(v)
		"ach": N.BI(v)
		"hd": N.FI("d", int(v))
		"ht": N.FI("t", int(v))
		"shop": N.sY(v)
		"ng": N.hY(int(v))
		"go": _go(v)
	G.mark()
	sync()

func _go(tid: String) -> void:
	# nvGo: đóng sổ rồi mở việc đó
	close()
	if tid == "deliver":
		U.ord_open()
	else:
		U.say("Phần này đang chuyển qua bản Godot.")

func _dragged() -> bool:
	return drag != null and drag.moved

func input(e: InputEvent) -> void:
	if not on or body == null:
		return
	var pos := Vector2.ZERO
	if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		scroll = clampf(scroll + (-40.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 40.0), 0.0, hmax)
		U._move(cont, Vector2(0, -scroll))
		return
	if e is InputEventScreenTouch or e is InputEventMouseButton:
		if e is InputEventMouseButton and e.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = e.position / Css.K
		if e.pressed:
			var gr := Rect2(body.get_global_rect().position / Css.K, body.r.size)
			drag = {"y0": pos.y, "s0": scroll, "moved": false} if gr.has_point(pos) else null
		elif drag != null:
			var dd = drag
			U.get_tree().create_timer(0.05).timeout.connect(func(): if drag == dd: drag = null)
	elif (e is InputEventScreenDrag or e is InputEventMouseMotion) and drag != null:
		pos = e.position / Css.K
		var d: float = pos.y - drag.y0
		if absf(d) > 6.0:
			drag.moved = true
		if drag.moved and cont != null:
			scroll = clampf(drag.s0 - d, 0.0, hmax)
			U._move(cont, Vector2(0, -scroll))

# ------------------------------------------------------------------ chấm đỏ nút Nhiệm vụ (mY)
func badge(btn: Control) -> void:
	if btn == null:
		return
	var R: Dictionary = N.ready_n()
	var n: int = int(R.ngay) + int(R.tuan) + int(R.tt) + int(R.sk)
	if n == bdg_n:
		return
	bdg_n = n
	if bdg != null:
		bdg.queue_free()
		bdg = null
	if n <= 0:
		return
	var src: Dictionary = Snap.find(Snap.load_snap("nv_bdg")["#nvBtn"][0], "bdg").duplicate(true)
	var s := str(n)
	var w := maxf(float(src.r[2]), _tw(src, s) + 6.0)
	var rx := _rx(src)
	src.r = [rx - w, src.r[1], w, src.r[3]]
	var tw := _tw(src, s)
	_st(src, s, rx - w + (w - tw) * 0.5, tw + 0.5)
	var bn: Dictionary = btn.get_meta("snap")
	bdg = U._build(src, {}, Vector2(float(bn.r[0]), float(bn.r[1])))
	btn.add(bdg)

func step(dt: float) -> void:
	if on and not wig.is_empty():
		# nggb 1,6 s: đứng yên tới 80%, lắc -10° rồi +10° (phóng 1,06)
		_clock = fmod(_clock + dt, 1.6)
		var p := _clock / 1.6
		var ang := 0.0
		var sc := 1.0
		if p > 0.8 and p <= 0.86:
			var f := (p - 0.8) / 0.06
			ang = -10.0 * f
			sc = 1.0 + 0.06 * f
		elif p > 0.86 and p <= 0.92:
			var f := (p - 0.86) / 0.06
			ang = -10.0 + 20.0 * f
			sc = 1.06
		elif p > 0.92:
			var f := (p - 0.92) / 0.08
			ang = 10.0 * (1.0 - f)
			sc = 1.06 - 0.06 * f
		for b in wig:
			if is_instance_valid(b):
				b.pivot_offset = b.size * 0.5
				b.rotation_degrees = ang
				b.scale = Vector2(sc, sc)
	_t -= dt
	if _t <= 0.0:
		_t = 0.5
		badge(U.hid.get("#nvBtn"))
		if on:
			sync()
