extends RefCounted
# Bảng XƯỞNG khi chạm một xưởng (module "xuongf" bản web: Vp -> We, st/ut/It/Y/Hn).
# Vòng ô hàng đợi quanh ô giữa (món đang làm + giờ + "xong ngay"), nút sao, nút thu; khay món ở dưới;
# thẻ món (tên, giờ, giá bán, nguyên liệu, nút Làm) ngay trên khay. Camera đưa xưởng vào giữa (.32 s).
# Số đo + css lấy từ chính bản web: ui/snap/xf_run, xf_thu, xf2_pd, xf2_four, xf2_full, xf_sel, xf_ask*.

const Snap = preload("res://ui/snap.gd")
const Box = preload("res://ui/box.gd")
const Css = preload("res://ui/css.gd")

const W := 60.0     # ô vòng
const K := 72.0     # ô giữa
const FT := 80.0    # bán kính vòng
const GT := 96.0    # gt: chừa thanh trên
const A6 := 6.0     # A
const AT := 10.0    # At

var U
var G
var k := ""
var sel := ""
var sig := ""
var bsig := ""
var tsig := ""
var ch := 0.0
var rb := 220.0
var T := {}
var top: Control = null
var card: Control = null
var bar: Control = null
var bar_in: Control = null
var tipb: Control = null
var tip_k := ""
var tip_s := ""
var tip_t := 0.0
var tip_at := {}           # data-ti -> Box
var bar_h := 70.0
var bar_sc := 0.0
var bar_max := 0.0
var drag = null
var dragged := false
var ask: Control = null
var ask_cb = null
var _fit := {}
var _gray: ShaderMaterial = null

func _init(ui) -> void:
	U = ui
	G = ui.G
	var run: Dictionary = Snap.load_snap("xf_run")[".xf"][0]
	var thu: Dictionary = Snap.load_snap("xf_thu")[".xf"][0]
	var pd: Dictionary = Snap.load_snap("xf2_pd")[".xf"][0]
	var four: Dictionary = Snap.load_snap("xf2_four")[".xf"][0]
	var full: Dictionary = Snap.load_snap("xf2_full")[".xf"][0]
	var one: Dictionary = Snap.load_snap("xf_sel")[".xf"][0]
	T.xtop = _shell(Snap.find(run, "xtop"))
	T.xrow = _shell(Snap.find(run, "xrow"))
	for s in Snap.find(run, "xrow").kids:
		var c: String = s.kids[0].cls
		match c:
			"xt stb": T.stb = s
			"xt": T.it = s
			"xt em": T.em = s
			"xt lk nx": T.lknx = s
			"xt lk": T.lk = s
			"xt cur": T.cur = s
	for s in Snap.find(thu, "xrow").kids:
		if s.kids[0].cls == "xt thu":
			T.thu = s
	for s in Snap.find(four, "xrow").kids:
		if s.kids[0].cls == "xt cur em":
			T.cur_em = s
	for s in Snap.find(pd, "xrow").kids:
		if s.kids[0].cls == "xt pd cur":
			T.cur_pd = s
	# khay
	T.xbar = _shell(Snap.find(pd, "xbar"))
	for b in Snap.find(run, "xbar").kids + Snap.find(pd, "xbar").kids + Snap.find(four, "xbar").kids:
		var key: String = String(b.cls).replace(" ", "_")
		if not T.has(key):
			T[key] = b
		var cn := Snap.find(b, "xcnt")
		if not cn.is_empty():
			T.xcnt = cn
			var b2: Dictionary = b.duplicate(true)
			b2.kids = b2.kids.filter(func(q): return q.cls != "xcnt")
			T[key] = b2
	# thẻ món
	var cd := Snap.find(four, "xcard")
	T.xcard = _shell(cd)
	T.xch = Snap.find(four, "xch")
	T.go_c = Snap.find(four, "xgo")
	T.go_g = Snap.find(pd, "xgo")
	T.go_full = Snap.find(full, "xgo")
	T.xins = _shell(Snap.find(four, "xins"))
	T.xins_one = _shell(Snap.find(one, "xins"))
	var ins: Array = Snap.find(four, "xins").kids
	T.xin_ok = ins[0]
	T.xin_no = ins[1]
	T.xin_one = Snap.find(one, "xins").kids[0]
	# hộp hỏi "Tốn N [sen]" (dd)
	var ak = Snap.load_snap("xf_ask")
	T.ask = ak[".u2ask"][0] if ak != null and ak.has(".u2ask") else {}
	var ak2 = Snap.load_snap("xf_ask2")
	T.ask2 = ak2[".u2ask"][0] if ak2 != null and ak2.has(".u2ask") else {}
	for key in T:
		if T[key] is Dictionary:
			_pearl(T[key], key.begins_with("ask"))
	_gray = ShaderMaterial.new()
	var sh := Shader.new()
	# .xbar .xr.no .xfi: filter grayscale(.85) brightness(1.05)
	sh.code = "shader_type canvas_item;\nvoid fragment(){ vec4 c = COLOR; float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722)); c.rgb = mix(c.rgb, vec3(l), 0.85) * 1.05; COLOR = c; }"
	_gray.shader = sh

static func _pearl(n: Dictionary, on: bool) -> void:
	# img sen đỏ (sh()) trong ô khoá, nút xong ngay, nút "Làm · N", hộp hỏi: hình ngọc, không phải xu
	var c := String(n.get("cls", ""))
	var here := on or c.find("xpc") >= 0 or c.find("xsp") >= 0 or c.begins_with("xgo")
	if n.get("tag", "") == "img" and here:
		n.src = "pearl"
	for q in n.get("kids", []):
		_pearl(q, here)

static func _shell(n: Dictionary) -> Dictionary:
	var d: Dictionary = n.duplicate(true)
	d.kids = []
	return d

static func _at(n: Dictionary, p: Vector2) -> Dictionary:
	# bản sao của nút mẫu n, góc trên trái tới p
	return Snap.moved(n, p - Vector2(float(n.r[0]), float(n.r[1])))

static func _tx(n: Dictionary, s: String, x = null) -> void:
	# đổi chữ của một phần tử đã chụp, giữ cỡ chữ; x: mép trái mới (chữ co theo nội dung)
	var c: Dictionary = n.css
	var w: float = Box.text_w(s, Css.px(c.get("font-size", "14px")), int(c.get("font-weight", "400")))
	n.text = s
	if x != null:
		var pl := Css.px(c.get("padding-left", "0px"))
		var pr := Css.px(c.get("padding-right", "0px"))
		n.r = [float(x), n.r[1], w + pl + pr, n.r[3]]
	if n.has("tr"):
		var tx: float = float(n.r[0]) + Css.px(c.get("padding-left", "0px")) if x != null else float(n.tr[0])
		n.tr = [tx, n.tr[1], w, n.tr[3]]

# ------------------------------------------------------------------ hình món
func _svg(id: String, sc: float, bottom: bool) -> String:
	# o() / l() bản web: viewBox ôm hình (getBBox) x sc; o() đặt sát đáy, l() giữ tâm
	var key := id + str(sc) + str(bottom)
	if _fit.has(key):
		return _fit[key]
	var sv: String = FileAccess.get_file_as_string("res://ui/svg/kh/" + id + ".svg")
	var out := sv
	var m := RegEx.create_from_string("viewBox=\"([^\"]*)\"").search(sv)
	if m != null:
		var v := m.get_string(1).split(" ", false)
		var img := Image.new()
		if v.size() == 4 and img.load_svg_from_string(sv, 8.0 * 64.0 / float(v[2])) == OK:
			var u := img.get_used_rect()
			if u.size.x > 0:
				var q: float = float(v[2]) / img.get_width()
				var bw := u.size.x * q
				var bh := u.size.y * q
				var bx: float = float(v[0]) + u.position.x * q
				var by: float = float(v[1]) + u.position.y * q
				var s := maxf(bw, bh) * sc
				var cx := bx + bw * 0.5
				var y0 := (by + bh + s * 0.03 - s) if bottom else (by + bh * 0.5 - s * 0.5)
				out = sv.replace(m.get_string(0), "viewBox=\"%.1f %.1f %.1f %.1f\" data-fit=\"1\"" % [cx - s * 0.5, y0, s, s])
	_fit[key] = out
	return out

func _ic(n: Dictionary, id: String, bottom := false) -> void:
	# thay hình trong .xfi của nút mẫu bằng hình món id
	var fi := Snap.find(n, "xfi")
	if fi.is_empty():
		return
	for q in fi.get("kids", []):
		if q.tag == "svg":
			q.svg = _svg(id, 1.06 if bottom else 1.1, bottom)

# ------------------------------------------------------------------ mở / đóng
func open(key: String) -> void:   # We
	U.close_all()
	U._cam_open()
	k = key
	sel = ""
	ch = 0.0
	sig = ""
	bsig = ""
	tsig = ""
	tip_k = ""
	bar_sc = 0.0
	U._set_focus(true)
	_sync()
	_cam()

func close() -> void:   # Pe
	if k == "":
		return
	_ask_close()
	_tip_off()
	k = ""
	sel = ""
	for b in [top, card, bar, tipb]:
		if b != null and is_instance_valid(b):
			b.queue_free()
	top = null
	card = null
	bar = null
	bar_in = null
	tipb = null
	U._set_focus(false)
	U._cam_close()

func is_open() -> bool:
	return k != ""

# ------------------------------------------------------------------ hàng đợi (Xa = q + món đang đi tới làm)
func _pend() -> Array:   # k(ya): món của việc "làm" đang chờ đi tới
	var out := []
	var F = U.F
	for j in ([F.cur] if F.cur != null else []) + F.q:
		if j.kind == "work" and j.get("i_k", "") == k:
			out.append(String(j.get("seed", "")))
	return out

func _collecting() -> bool:   # M(ya)
	var F = U.F
	for j in ([F.cur] if F.cur != null else []) + F.q:
		if j.get("key", "") == "wkc" + k:
			return true
	return false

func _ok(rid: String) -> bool:   # t1
	return G.xw.has_in(rid)

func _rec() -> Array:   # w(ya): món làm được trước, giữ thứ tự gốc
	var L: Array = G.xw.sr[k].rec
	var a := []
	var b := []
	for r in L:
		(a if _ok(r) else b).append(r)
	return a + b

# ------------------------------------------------------------------ dựng
func _sync() -> void:   # Wn
	if k == "":
		return
	var w: Dictionary = G.xw.w(k)
	if int(w.get("b", 0)) != 1:
		close()
		return
	var pend := _pend()
	var s := JSON.stringify([sel, w.q, w.r, G.xw.ks(k), G.xw.nc(k), pend, int(G.g.ngoc), _collecting()])
	var av := ""
	for r in G.xw.sr[k].rec:
		for a in G.xw.R[r].in:
			av += str(mini(int(G.g.barn.get(a[0], 0)), int(a[1]))) + ","
		av += ";"
	var tl := _timer()
	if s + av + tl != sig:
		var first := sig == ""
		var s_top := s + tl
		if s_top != tsig:
			tsig = s_top
			_build_top(w, pend)
		var bk := av + sel + str(_barn_sig())
		if first or bk != bsig:
			bsig = bk
			_build_bar()
		_build_card(w, pend)
		sig = s + av + tl
		for b in [tipb, ask]:   # tên món, hộp hỏi luôn nằm trên vòng / thẻ vừa dựng lại
			if b != null and is_instance_valid(b):
				U.root.move_child(b, -1)
	_pos()

func _barn_sig() -> String:
	var o := ""
	for r in G.xw.sr[k].rec:
		o += str(int(G.g.barn.get(r, 0))) + ","
	return o

func _timer() -> String:   # Rn: giờ còn lại + sen xong ngay
	var w: Dictionary = G.xw.w(k)
	if w.q.is_empty():
		return ""
	return _fmt(G.xw.left(k)) + "|" + str(G.xw.fin_cost(k))

static func _fmt(t: float) -> String:   # n(ya): 1g 5p / 2p 39s / 40s
	var s := int(maxf(0.0, ceil(t)))
	var h := s / 3600
	var m := (s % 3600) / 60
	var e := s % 60
	if h:
		return str(h) + "g " + str(m) + "p"
	if m:
		return str(m) + "p " + str(e) + "s"
	return str(e) + "s"

func _build_top(w: Dictionary, pend: Array) -> void:   # st()
	var o := Vector2(float(T.xtop.r[0]), float(T.xtop.r[1]))
	var nc: int = G.xw.nc(k)
	var Xa: Array = w.q + pend
	var jn: int = w.q.size()
	var B := maxi(maxi(nc, w.q.size()), Xa.size())
	var qt: int = 3 + G.xw.GS.size()
	var slots := []          # [mẫu đã sửa, data-ti, món tip, nút]
	for e in range(1, maxi(qt, B)):
		var has := e < Xa.size()
		if has and e >= jn:
			slots.append([_pd_slot(String(Xa[e])), "q" + str(e), String(Xa[e]), ""])
		elif e < nc or has:
			if has:
				var n: Dictionary = T.it.duplicate(true)
				_ic(n, String(Xa[e]))
				slots.append([n, "q" + str(e), String(Xa[e]), ""])
			else:
				slots.append([T.em.duplicate(true), "", "", ""])
		else:
			var n: Dictionary = (T.lknx if e == nc else T.lk).duplicate(true)
			var pc := Snap.find(n, "xpc")
			for q in pc.get("kids", []):
				if q.tag == "b":
					q.text = str(G.xw.GS[e - 3])
			slots.append([n, "", "", "q" + str(e)])
	var ii: int = G.xw.df(k)
	var vr := [[T.stb.duplicate(true), "", "", "star"]]
	if ii > 0:
		var best := ""
		var bn := -1
		for id in w.r:
			if int(w.r[id]) > bn:
				bn = int(w.r[id])
				best = id
		var n: Dictionary = T.thu.duplicate(true)
		_ic(n, best)
		var tn := Snap.find(n, "xthn")
		var txt := "×" + str(ii)
		var tw: float = Box.text_w(txt, 14.0, 800)
		var bw := maxf(24.0, tw + 10.0)
		var right: float = float(n.r[0]) + W + 4.0
		tn.text = txt
		tn.r = [right - bw, tn.r[1], bw, tn.r[3]]
		if tn.has("tr"):
			tn.tr = [right - bw + (bw - tw) * 0.5, tn.tr[1], tw, tn.tr[3]]
		var busy := _collecting()
		if busy:
			n.kids[0].cls += " pd"
			n.kids[0].css["opacity"] = "0.55"
		vr.append([n, "", "", "" if busy else "collect"])
	var vn: int = slots.size() + vr.size()
	var zn := 360.0 / vn
	var r0 := 90.0 + zn / 2.0 if vr.size() == 2 else 90.0
	var fi := [vr[0]] + slots
	if vr.size() > 1:
		fi.append(vr[1])
	var e0 := (2.0 * FT + W) / 2.0
	rb = e0 + K / 2.0 + 12.0
	var nd: Dictionary = T.xtop.duplicate(true)
	var row: Dictionary = T.xrow.duplicate(true)
	nd.kids = [row]
	var acts := []
	for j in fi.size():
		var ang := deg_to_rad(fmod(r0 + j * zn, 360.0))
		rb = maxf(rb, e0 + FT * sin(ang) + W / 2.0)
		var p := o + Vector2(e0 + FT * cos(ang) - W / 2.0, e0 + FT * sin(ang) - W / 2.0)
		row.kids.append(_at(fi[j][0], p))
		acts.append(fi[j])
	# ô giữa
	var qn: String = String(Xa[0]) if Xa.size() > 0 else ""
	var cen: Dictionary
	var cti := ""
	if Xa.size() > 0 and jn == 0:
		cen = T.cur_pd.duplicate(true)
		_ic(cen, qn)
		cti = "c"
	elif qn != "":
		cen = T.cur.duplicate(true)
		_ic(cen, qn)
		cti = "c"
		var cx: float = float(cen.r[0]) + K / 2.0
		var tm := Snap.find(cen, "xtm")
		var tl := Snap.find(cen, "xtl")
		var s := _fmt(G.xw.left(k))
		var tw: float = Box.text_w(s, 12.0, 800)
		var tmw := 4.0 + 16.0 + 4.0 + tw + 9.0
		var x0 := cx - tmw / 2.0
		var dx: float = x0 - float(tm.r[0])
		Snap._move(tm, Vector2(dx, 0))
		tm.r = [x0, tm.r[1], tmw, tm.r[3]]
		_tx(tl, s, x0 + 24.0)
		var sp := Snap.find(cen, "xsp")
		var cn := Snap.find(cen, "xcn")
		var cs := str(G.xw.fin_cost(k))
		var cw: float = Box.text_w(cs, 14.0, 800)
		var spw := 8.0 + 15.0 + 4.0 + cw + 8.0
		var sx := cx - spw / 2.0
		Snap._move(sp, Vector2(sx - float(sp.r[0]), 0))
		sp.r = [sx, sp.r[1], spw, sp.r[3]]
		_tx(cn, cs, sx + 27.0)
	else:
		cen = T.cur_em.duplicate(true)
	row.kids.append(_at(cen, o + Vector2(e0 - K / 2.0, e0 - K / 2.0)))
	var ids := {}
	var old := top
	top = U._build(nd, ids, o)
	U.root.add_child(top)
	if old != null and is_instance_valid(old):
		top.position = old.position
		old.queue_free()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_at = {}
	# nút + ô có tên (data-tip): bấm hiện tên món
	var sl: Array = ids.get(".xslot*", [])
	for j in sl.size():
		var b: Control = sl[j]
		var xt: Control = b.kids()[0] if b.kids().size() > 0 else null
		if xt == null:
			continue
		if j < acts.size():
			var a: Array = acts[j]
			if a[3] != "":
				var act: String = a[3]
				U._click(xt, func(): _do(act), "down")
			elif a[2] != "":
				var ti: String = a[1]
				var nm: String = G.item_name(a[2])
				tip_at[ti] = xt
				U._click(xt, func(): _tip(ti, nm), "none")
			else:
				U._click(xt, func(): _tip_off(), "none")
		else:
			if cti != "":
				var nm2: String = G.item_name(qn)
				tip_at["c"] = xt
				U._click(xt, func(): _tip("c", nm2), "none")
			else:
				U._click(xt, func(): _tip_off(), "none")
	var spb = ids.get(".xsp")
	if spb != null:
		U._click(spb, func(): _do("fin"), "down")

func _pd_slot(id: String) -> Dictionary:   # ne(): món đang chờ nhân vật đi tới, mờ + "…"
	var n: Dictionary = T.it.duplicate(true)
	n.kids[0].cls = "xt pd"
	_ic(n, id)
	var fi := Snap.find(n, "xfi")
	fi.css["opacity"] = "0.45"
	var pdn: Dictionary = Snap.find(T.cur_pd, "xpd").duplicate(true)
	var x: float = float(n.r[0]) + W + 4.0 - float(pdn.r[2])
	var y: float = float(n.r[1]) + W + 4.0 - float(pdn.r[3])
	n.kids[0].kids.append(_at(pdn, Vector2(x, y)))
	return n

func _build_bar() -> void:   # ut()
	var o := Vector2(float(T.xbar.r[0]), float(T.xbar.r[1]))
	var L := _rec()
	var rows := int(ceil(L.size() / 5.0))
	var h := minf(202.0, 16.0 + rows * 54.0 + maxf(0, rows - 1) * 6.0)
	bar_max = maxf(0.0, 16.0 + rows * 54.0 + maxf(0, rows - 1) * 6.0 - h)
	bar_sc = clampf(bar_sc, 0.0, bar_max)
	var nd: Dictionary = T.xbar.duplicate(true)
	nd.r = [nd.r[0], nd.r[1], nd.r[2], h]
	var ids := {}
	var old := bar
	bar = U._build(nd, ids, o)
	U.root.add_child(bar)
	if old != null and is_instance_valid(old):
		bar.position = old.position
		old.queue_free()
	U._stop(bar)
	bar._kids.clip_contents = true
	bar_in = Control.new()
	bar_in.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar._kids.add_child(bar_in)
	bar_h = h
	for j in L.size():
		var rid: String = L[j]
		var ok := _ok(rid)
		var key := "xr_" + ("ok" if ok else "no") + ("_sel" if sel == rid else "")
		var tp: Dictionary = T.get(key, T["xr_ok"])
		var p := o + Vector2(10.0 + (j % 5) * 60.0, 8.0 + int(j / 5) * 60.0)
		var n := _at(tp, p)
		_ic(n, rid, true)
		var cnt := int(G.g.barn.get(rid, 0))
		if cnt > 0 and T.has("xcnt"):
			var c: Dictionary = T.xcnt.duplicate(true)
			var s: String = G.fmt_k(cnt)
			var tw: float = Box.text_w(s, 14.0, 800)
			var right: float = p.x + 54.0 - 2.0
			c = _at(c, Vector2(right - tw, p.y + 54.0 - 14.0))
			c.r = [right - tw, c.r[1], tw, c.r[3]]
			c.text = s
			if c.has("tr"):
				c.tr = [right - tw, c.tr[1], tw, c.tr[3]]
			n.kids.append(c)
		var b: Control = U._build(n, {}, o)
		bar_in.add_child(b)
		if not ok:
			var fi: Control = U._q(b, "xfi")
			if fi != null:
				_mat(fi)
		U._click(b, func(): if not dragged: _pick(rid), "scale")
	bar_in.position = Vector2(0, -bar_sc) * Css.K

func _mat(b: Control) -> void:
	b.material = _gray
	for q in b.get_children():
		if q is CanvasItem:
			_mat_ci(q)

func _mat_ci(c: CanvasItem) -> void:
	c.use_parent_material = true
	for q in c.get_children():
		if q is CanvasItem:
			_mat_ci(q)

func _build_card(w: Dictionary, pend: Array) -> void:   # It()
	if card != null and is_instance_valid(card):
		card.queue_free()
	card = null
	if sel == "":
		_ch(0.0)
		return
	var o := Vector2(float(T.xcard.r[0]), float(T.xcard.r[1]))
	var e: Dictionary = G.xw.R[sel]
	var ok := _ok(sel)
	var full: bool = w.q.size() + pend.size() >= G.xw.nc(k)
	var x0 := o.x + 10.0
	var y0 := o.y + 10.0
	var right := o.x + float(T.xcard.r[2]) - 10.0
	# nút: Hàng đợi đầy / Làm / Làm · N [sen]
	var go: Dictionary
	var act := ""
	if full:
		go = T.go_full.duplicate(true)
	elif ok:
		go = T.go_g.duplicate(true)
		act = "make"
	else:
		go = T.go_c.duplicate(true)
		act = "make"
		var xs := Snap.find(go, "xs")
		var cs := str(G.lack_cost(G.missing(e.in)))
		var cw: float = Box.text_w(cs, 14.0, 800)
		var lw: float = Box.text_w("Làm ·", 14.0, 700)
		var bw := 12.0 + lw + 5.0 + cw + 5.0 + 15.0 + 12.0
		var bx := right - bw
		Snap._move(go, Vector2(bx - float(go.r[0]), 0))
		go.r = [bx, go.r[1], bw, go.r[3]]
		go.tr = [bx + 12.0, go.tr[1], lw, go.tr[3]]
		xs.text = cs
		xs.r = [bx + 12.0 + lw + 5.0, xs.r[1], cw, xs.r[3]]
		if xs.has("tr"):
			xs.tr = [xs.r[0], xs.tr[1], cw, xs.tr[3]]
		for q in go.kids:
			if q.tag == "img":
				q.r = [bx + bw - 12.0 - 15.0, q.r[1], 15.0, 15.0]
	go = _at(go, Vector2(right - float(go.r[2]), y0 + 2.84))
	# đầu thẻ: hình, tên, "giờ · bán N [xu]"
	var hd: Dictionary = _at(T.xch, Vector2(x0, y0))
	_ic(hd, sel)
	var ct := Snap.find(hd, "xct")
	ct.r = [ct.r[0], ct.r[1], float(go.r[0]) - 8.0 - float(ct.r[0]), ct.r[3]]
	var nb: Dictionary = ct.kids[0]
	_tx(nb, G.item_name(sel))
	nb.r = [nb.r[0], nb.r[1], ct.r[2], nb.r[3]]
	var sm: Dictionary = ct.kids[1]
	var st: String = _fmt(float(e.time)) + " · bán " + G.fmt_n(int(G.item(sel).get("sell", 0)))
	var stw: float = Box.text_w(st, 14.0, 600)
	sm.text = st
	sm.tr = [sm.r[0], sm.tr[1], stw, sm.tr[3]]
	sm.r = [sm.r[0], sm.r[1], stw + 4.0 + 14.0, sm.r[3]]
	for q in sm.kids:
		if q.tag == "img":
			q.r = [float(sm.r[0]) + stw + 4.0, q.r[1], 14.0, 14.0]
	hd.kids = hd.kids.filter(func(q): return not String(q.cls).begins_with("xgo"))
	hd.kids.append(go)
	# nguyên liệu: 1 món cả hàng, nhiều món 2 cột
	var L: Array = e.in
	var one := L.size() == 1
	var iy := y0 + float(T.xch.r[3]) + 8.0
	var rows := 1 if one else int(ceil(L.size() / 2.0))
	var ih := rows * 32.0 + maxf(0, rows - 1) * 6.0
	var ins: Dictionary = (T.xins_one if one else T.xins).duplicate(true)
	ins = _at(ins, Vector2(x0, iy))
	ins.r = [x0, iy, right - x0, ih]
	ins.kids = []
	for j in L.size():
		var a: Array = L[j]
		var have := mini(int(G.g.barn.get(a[0], 0)), int(a[1]))
		var full_in := have >= int(a[1])
		var tp: Dictionary = (T.xin_ok if full_in else T.xin_no).duplicate(true)
		if one:
			if full_in:
				tp = T.xin_one.duplicate(true)
			else:
				_widen(tp, right - x0)
		var cw2 := (right - x0) if one else 144.0
		var p := Vector2(x0 + (0.0 if one else (j % 2) * 150.0), iy + int(j / 2) * 38.0)
		var n := _at(tp, p)
		_ic(n, String(a[0]))
		var nm: Dictionary = {}
		var em: Dictionary = {}
		for q in n.kids:
			if q.tag == "span" and q.cls == "":
				nm = q
			elif q.tag == "em":
				em = q
		_tx(nm, G.item_name(a[0]))
		var bb: Dictionary = em.kids[0]
		var hs := str(have)
		var ns := "/" + str(int(a[1]))
		var hw: float = Box.text_w(hs, 14.0, 800)
		var nw: float = Box.text_w(ns, 14.0, 600)
		var ex := p.x + cw2 - 8.0 - hw - nw
		em.r = [ex, em.r[1], hw + nw, em.r[3]]
		em.text = ns
		em.tr = [ex + hw, em.tr[1], nw, em.tr[3]]
		bb.text = hs
		bb.r = [ex, bb.r[1], hw, bb.r[3]]
		bb.tr = [ex, bb.tr[1], hw, bb.tr[3]]
		nm.r = [nm.r[0], nm.r[1], ex - 6.0 - float(nm.r[0]), nm.r[3]]
		ins.kids.append(n)
	var nd: Dictionary = T.xcard.duplicate(true)
	var hgt := 10.0 + float(T.xch.r[3]) + 8.0 + ih + 10.0
	nd.r = [o.x, o.y, nd.r[2], hgt]
	nd.css["opacity"] = "1"
	nd.kids = [hd, ins]
	var ids := {}
	card = U._build(nd, ids, o)
	U.root.add_child(card)
	U._stop(card)
	var gb = ids.get(".xgo")
	if gb != null and act != "":
		U._click(gb, func(): _do(act, gb), "down")
	_ch(hgt + 8.0)

static func _widen(n: Dictionary, w: float) -> void:
	# ô nguyên liệu 2 cột (144) -> cả hàng: đẩy số sang mép phải
	var d: float = w - float(n.r[2])
	n.r = [n.r[0], n.r[1], w, n.r[3]]
	for q in n.kids:
		if q.tag == "em":
			Snap._move(q, Vector2(d, 0))

func _ch(v: float) -> void:   # D(): thẻ đổi cao -> tính lại camera
	if absf(v - ch) > 2.0:
		ch = v
		if k != "":
			_cam()

# ------------------------------------------------------------------ vị trí (Y, Gt, zt)
func _scr(wx: float, wy: float, z := 0.0) -> Vector2:
	var F = U.F
	return (Vector2(F.en(wx, wy), F.nn(wx, wy, z)) - U.main.cam) * U.main.zoom / Css.K

func _nt() -> float:   # Nt: đỉnh hình xưởng so với tâm nền (đơn vị làng, âm)
	var n = U.F.xnodes.get(k)
	if n != null and n.A.has("id"):
		return float(n.A["id"][1])
	var s: Dictionary = G.xw.sr[k]
	return -float(load("res://logic/xuong_ve.gd").BH.get(s.type, 40 + s.fd * 30))

func _gt() -> Dictionary:
	var s: Dictionary = G.xw.sr[k]
	var c := _scr(s.gx + s.fw / 2.0, s.gy + s.fd / 2.0)
	var b := _scr(s.gx + s.fw, s.gy + s.fd)
	return {"x": c.x, "cy": c.y, "top": c.y + _nt() * U.cz(), "bot": b.y + 4.0 * U.cz()}

func _pos() -> void:   # Y()
	if top == null or bar == null:
		return
	var g := _gt()
	var vw: float = U.vw
	var vh: float = U.vh
	var bt := 2.0 * FT + W
	var ia := bar_h
	var jn := clampf(g.x, bt / 2.0 + 8.0, vw - bt / 2.0 - 8.0)
	var qn := maxf(GT - 20.0, minf(vh - bt - ia - 20.0, g.top + AT - rb))
	U._move(top, Vector2(round(jn) - bt / 2.0, round(qn)))
	var by := maxf(maxf(qn + rb + 6.0 + ch, qn + rb + A6), minf(vh - ia - 8.0, g.bot + A6))
	var bx := (vw - float(T.xbar.r[2])) * 0.5
	U._move(bar, Vector2(bx, round(by)))
	if card != null:
		U._move(card, Vector2(bx, round(by - card.r.size.y - 8.0)))
	_dim(g)
	_tip_pos()

func _dim(g: Dictionary) -> void:   # zt(): tối nhẹ quanh xưởng
	var s: Dictionary = G.xw.sr[k]
	var xs := []
	for p in [[s.gx, s.gy], [s.gx + s.fw, s.gy], [s.gx + s.fw, s.gy + s.fd], [s.gx, s.gy + s.fd]]:
		xs.append(_scr(p[0], p[1]).x)
	var mn: float = xs.min()
	var mx: float = xs.max()
	var c := Vector2((mn + mx) / 2.0, (g.top + g.bot) / 2.0) * Css.K
	var r := Vector2(round((mx - mn) / 2.0 * 1.3 + 16.0), round((g.bot - g.top) / 2.0 * 1.3 + 16.0)) * Css.K
	U.dim_mat.set_shader_parameter("c", c)
	U.dim_mat.set_shader_parameter("r", r)

# ------------------------------------------------------------------ camera (Hn / ue)
func _cam() -> void:
	var s: Dictionary = G.xw.sr[k]
	var F = U.F
	var bx: float = s.gx + s.fw / 2.0
	var bty: float = s.gy + s.fd / 2.0
	var ia: float = F.en(bx, bty)
	var xa: float = F.nn(bx, bty)
	var jn := xa + _nt()
	var qn: float = F.nn(s.gx + s.fw, s.gy + s.fd) + 4.0
	var ne := rb
	var qt := bar_h
	var jj: float = U.vh - GT - 12.0
	var ee := minf(1.6 / U.U, maxf(0.5 / U.U, (jj - ne + AT - 2.0 * A6 - qt) / maxf(1.0, qn - jn)))
	ee = clampf(ee, U.main.zmin / U.dpr_v / U.U, U.main.zmax / U.dpr_v / U.U)
	var wn := maxf(ne - AT + (qn - jn) * ee + A6, ne + 6.0 + ch) + qt
	var qe := GT + maxf(0.0, (jj - wn) / 2.0)
	var sr := qe + ne - AT + (xa - jn) * ee
	var sc := Vector2(U.vw * 0.5, sr)
	var w0: Vector2 = U.main.cam + sc * Css.K / U.main.zoom
	U.cam_tw = {"z0": U.main.zoom, "z1": ee * Css.K, "w0": w0, "w1": Vector2(ia, xa), "s": sc * Css.K, "t": 0.0}

# ------------------------------------------------------------------ bấm (fe)
func _pick(rid: String) -> void:
	sel = "" if sel == rid else rid
	sig = ""
	_sync()

func _do(act: String, b = null) -> void:
	var key := k
	if key == "":
		return
	var w: Dictionary = G.xw.w(key)
	match act:
		"make":
			if sel == "":
				return
			var rid := sel
			if not _ok(rid):
				var miss: Array = G.missing(G.xw.R[rid].in)
				var cost: int = G.lack_cost(miss)
				var parts := []
				for m in miss:
					parts.append(G.item_name(m[0]).to_lower() + " ×" + str(m[1]))
				_ask(b, cost, "Bù thiếu rồi làm?", "Thiếu " + ", ".join(parts), func():
					if k != key:
						return
					if int(G.g.ngoc) < cost:
						U.say("Còn thiếu " + str(cost - int(G.g.ngoc)) + " sen đỏ.")
						return
					G.g.ngoc = int(G.g.ngoc) - cost
					G.nv.spent(cost)
					for m in miss:
						G.g.barn[m[0]] = int(G.g.barn.get(m[0], 0)) + int(m[1])
					G.mark()
					_wh(key, rid))
				return
			_wh(key, rid)
		"fin":
			if w.q.is_empty():
				return
			_ask(b if b != null else top, G.xw.fin_cost(key), "Xong ngay " + G.item_name(w.q[0]).to_lower() + "?", "", func(): G.xw.finish_now(key); sig = "")
		"star":
			U.say("Nâng sao " + String(G.xw.sr[key].name).to_lower() + ": phần này đang chuyển qua bản Godot.")
		"collect":
			U.F.xw_job(key, "workc")
			sig = ""
		_:
			if act.begins_with("q"):
				var a := int(G.xw.qx().get(key, 0))
				if a >= G.xw.GS.size():
					return
				var ne := int(act.substr(1))
				if ne and ne != G.xw.nc(key):
					U.say("Mở ô trước đã.")
					return
				_ask(b, int(G.xw.GS[a]), "Mở thêm ô hàng đợi?", "", func(): G.xw.buy_slot(key); sig = "")
	_sync()

func _wh(key: String, rid: String) -> void:   # Wh "make": nhân vật đi tới xưởng rồi mới xếp món
	var w: Dictionary = G.xw.w(key)
	if w.q.size() + U.F.xw_queued(key) >= G.xw.nc(key):
		U.say("Hàng đợi đã đầy (" + str(G.xw.nc(key)) + " việc).")
		return
	if not _ok(rid):
		U.say("Kho chưa đủ nguyên liệu để làm " + G.item_name(rid).to_lower() + ".")
		return
	U.F.xw_job(key, "work", rid)
	U.say("Nhân vật đi tới " + String(G.xw.sr[key].name).to_lower() + " làm " + G.item_name(rid).to_lower() + ".")
	sig = ""

# ------------------------------------------------------------------ hộp hỏi "Tốn N sen" (dd)
func _ask(at, cost: int, title: String, sub: String, cb: Callable) -> void:
	_ask_close()
	var tp: Dictionary = T.ask if sub != "" else T.ask2
	if tp.is_empty():
		tp = T.ask if not T.ask.is_empty() else T.ask2
	if tp.is_empty():
		cb.call()
		return
	var n: Dictionary = tp.duplicate(true)
	var ax = _ask_lay(n, title, sub, str(cost))
	var ids := {}
	var o := Vector2(float(n.r[0]), float(n.r[1]))
	ask = U._build(n, ids, o)
	U.root.add_child(ask)
	U._stop(ask)
	var r: Rect2 = at.get_global_rect() if at is Control else Rect2(Vector2(U.vw, U.vh) * 0.5 * Css.K, Vector2.ZERO)
	r = Rect2(r.position / Css.K, r.size / Css.K)
	var w: float = float(n.r[2])
	var h: float = float(n.r[3])
	var x := maxf(8.0, minf(U.vw - w - 8.0, r.position.x + r.size.x / 2.0 - w / 2.0))
	var y := r.position.y - h - 10.0
	if y < 8.0:
		y = r.end.y + 10.0
	var rp: Vector2 = U.root.global_position / Css.K
	U._move(ask, Vector2(round(x), round(y)) - rp)
	# mũi nhọn chỉ vào nút (--ax), màu đáy hộp #f5f9ee
	if y < r.position.y:
		ask.set_meta("arrow", {"x": r.position.x + r.size.x / 2.0 - round(x), "y": h, "w": 7.0, "c": Color8(245, 249, 238)})
		ask.redraw()
	ask_cb = cb
	for b in U._buttons(ask, []):
		var lb: String = U._label_of(b)
		if lb.find("Hủy") >= 0:
			U._click(b, func(): _ask_close(), "down")
		else:
			U._click(b, func():
				var f = ask_cb
				_ask_close()
				if f != null:
					f.call()
				_sync(), "down")

static func _ask_lay(n: Dictionary, title: String, sub: String, cost: String):
	# .u2ask: cột giữa, gap 6, đệm 10/12, rộng tối thiểu 150 (chữ tối đa 230)
	var tw: float = minf(230.0, Box.text_w(title, 14.0, 700))
	var sw: float = minf(230.0, Box.text_w(sub, 14.0, 500)) if sub != "" else 0.0
	var t0: float = Box.text_w("Tốn", 14.0, 500)
	var cw: float = Box.text_w(cost, 14.0, 700)
	var spw := t0 + 3.0 + cw + 3.0 + 15.0
	var bw := 144.8
	for q in n.kids:
		if q.tag == "div":
			bw = float(q.r[2])
	var w := maxf(150.0, maxf(maxf(tw, sw), maxf(spw, bw)) + 24.0)
	var x0: float = float(n.r[0])
	var dw: float = w - float(n.r[2])
	n.r = [x0, n.r[1], w, n.r[3]]
	for q in n.kids:
		var qw: float = float(q.r[2])
		if q.tag == "b":
			q.text = title
			qw = tw
		elif q.tag == "small":
			q.text = sub
			qw = sw
		elif q.tag == "span":
			qw = spw
		var nx := x0 + (w - qw) / 2.0
		var d: float = nx - float(q.r[0])
		if q.tag == "span":
			q.r = [nx, q.r[1], qw, q.r[3]]
			if q.has("tr"):
				q.tr = [nx, q.tr[1], t0, q.tr[3]]
			for e in q.kids:
				if e.tag == "em":
					e.text = cost
					e.r = [nx + t0 + 3.0, e.r[1], cw, e.r[3]]
					if e.has("tr"):
						e.tr = [nx + t0 + 3.0, e.tr[1], cw, e.tr[3]]
				elif e.tag == "img":
					e.r = [nx + t0 + 3.0 + cw + 3.0, e.r[1], 15.0, 15.0]
		else:
			Snap._move(q, Vector2(d, 0))
			if q.tag != "div":
				q.r = [nx, q.r[1], qw, q.r[3]]
				if q.has("tr"):
					q.tr = [nx, q.tr[1], qw, q.tr[3]]
	n.erase("::after")
	return dw

func _ask_close() -> void:
	if ask != null and is_instance_valid(ask):
		ask.queue_free()
	ask = null
	ask_cb = null

# ------------------------------------------------------------------ tên món khi bấm (Ft / Ea)
func _tip(ti: String, s: String) -> void:
	tip_k = ti
	tip_s = s
	tip_t = 3.0
	if tipb != null and is_instance_valid(tipb):
		tipb.queue_free()
	var tw: float = Box.text_w(s, 14.0, 700)
	var w := tw + 22.0
	var h := 28.0
	var n := {"z": 1, "tag": "div", "id": "", "cls": "xftip", "r": [0, 0, w, h], "text": s, "tr": [11, 4.5, tw, 19],
		"css": {"background-image": "linear-gradient(rgb(244, 236, 217) 0%, rgb(248, 241, 226) 50%, rgb(251, 246, 234) 100%)",
			"border-radius": "10px", "box-shadow": "rgba(120, 82, 22, 0.5) 0px 0px 0px 1px inset, rgba(255, 255, 255, 0.75) 0px 1.5px 0px 0px inset, rgba(120, 85, 25, 0.13) 0px 0px 6px 2px inset, rgba(0, 0, 0, 0.32) 0px 3px 4px 0px",
			"color": "rgb(58, 42, 16)", "font-size": "14px", "font-weight": "700", "text-align": "left", "white-space": "nowrap", "position": "fixed", "z-index": "5"},
		"kids": [{"z": 1, "tag": "svg", "id": "", "cls": "xfta", "r": [w / 2.0 - 6.0, h - 0.5, 12, 7], "css": {"filter": "drop-shadow(rgba(120, 82, 22, 0.5) 0px 1px 0px)"},
			"svg": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 12 7\"><path d=\"M0 0H12L6 6.5z\" fill=\"#fbf6ea\"/></svg>", "kids": []}]}
	tipb = U._build(n, {})
	tipb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	U.root.add_child(tipb)
	_tip_pos()

func _tip_off() -> void:   # fa
	tip_k = ""
	if tipb != null and is_instance_valid(tipb):
		tipb.queue_free()
	tipb = null

func _tip_pos() -> void:
	if tip_k == "" or tipb == null:
		return
	var el = tip_at.get(tip_k)
	if el == null or not is_instance_valid(el):
		_tip_off()
		return
	var rp: Vector2 = U.root.global_position / Css.K
	var r: Rect2 = el.get_global_rect()
	r = Rect2(r.position / Css.K - rp, r.size / Css.K)
	var t0 := r.position.y
	var tm: Control = U._q(el, "xtm")
	if tm != null:
		t0 = tm.get_global_rect().position.y / Css.K - rp.y
	var w: float = tipb.r.size.x
	var h: float = tipb.r.size.y
	var cx := r.position.x + r.size.x / 2.0
	var jn := clampf(cx, w / 2.0 + 8.0, U.vw - w / 2.0 - 8.0)
	U._move(tipb, Vector2(round(jn - w / 2.0), round(t0 - 8.0 - h - 6.0)))
	var ar: Control = tipb.kids()[0] if tipb.kids().size() > 0 else null
	if ar != null:
		U._move(ar, Vector2(w / 2.0 + cx - jn - 6.0, h - 0.5))

# ------------------------------------------------------------------ khung hình
func step(dt: float) -> void:
	if k == "":
		return
	if tip_k != "":
		tip_t -= dt
		if tip_t <= 0.0:
			_tip_off()
	_sync()

func input(e: InputEvent) -> void:
	# kéo khay món khi nhiều hơn 3 hàng
	if k == "" or bar == null or bar_max <= 0.0:
		return
	var p = null
	if e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		if e.pressed and bar.get_global_rect().has_point(e.position):
			drag = [e.position.y, bar_sc]
			dragged = false
		elif not e.pressed:
			drag = null
			if dragged:
				(func(): dragged = false).call_deferred()
	elif (e is InputEventScreenDrag or e is InputEventMouseMotion) and drag != null:
		var dy: float = (e.position.y - drag[0]) / Css.K
		if absf(dy) > 6.0:
			dragged = true
		bar_sc = clampf(drag[1] - dy, 0.0, bar_max)
		if bar_in != null:
			bar_in.position = Vector2(0, -bar_sc) * Css.K
	elif e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_DOWN or e.button_index == MOUSE_BUTTON_WHEEL_UP):
		if bar.get_global_rect().has_point(e.position):
			bar_sc = clampf(bar_sc + (40.0 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -40.0), 0.0, bar_max)
			if bar_in != null:
				bar_in.position = Vector2(0, -bar_sc) * Css.K
